#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions

// Procedure is filling the payment details.
//
Procedure FillPaymentDetails() Export
	
	ParentCompany = DriveServer.GetCompany(Company);
	
	If VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then
		DefaultVATRate = InformationRegisters.AccountingPolicy.GetDefaultVATRate(Date, Company);
	ElsIf VATTaxation = Enums.VATTaxationTypes.NotSubjectToVAT Then
		DefaultVATRate = Catalogs.VATRates.Exempt;
	Else
		DefaultVATRate = Catalogs.VATRates.ZeroRate;
	EndIf;
	
	StructureByCurrency = InformationRegisters.ExchangeRates.GetLast(Date, New Structure("Currency", CashCurrency));
	
	ExchangeRateCurrenciesDC = ?(
		StructureByCurrency.ExchangeRate = 0,
		1,
		StructureByCurrency.ExchangeRate
	);
	CurrencyUnitConversionFactor = ?(
		StructureByCurrency.ExchangeRate = 0,
		1,
		StructureByCurrency.Multiplicity
	);
	
	// Filling default payment details.
	Query = New Query;
	Query.Text = 
	"SELECT
	|	ExchangeRatesSliceLast.Currency AS Currency,
	|	ExchangeRatesSliceLast.ExchangeRate AS ExchangeRate,
	|	ExchangeRatesSliceLast.Multiplicity AS Multiplicity
	|INTO ExchangeRatesOnPeriod
	|FROM
	|	InformationRegister.ExchangeRates.SliceLast(&Period, ) AS ExchangeRatesSliceLast
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccountsReceivableBalances.Company AS Company,
	|	AccountsReceivableBalances.Counterparty AS Counterparty,
	|	AccountsReceivableBalances.Contract AS Contract,
	|	AccountsReceivableBalances.Document AS Document,
	|	AccountsReceivableBalances.Order AS Order,
	|	AccountsReceivableBalances.SettlementsType AS SettlementsType,
	|	AccountsReceivableBalances.AmountCurBalance AS AmountCurBalance
	|INTO AccountsReceivableTable
	|FROM
	|	AccumulationRegister.AccountsReceivable.Balance(
	|			,
	|			Company = &Company
	|				AND Counterparty = &Counterparty
	|				AND SettlementsType = VALUE(Enum.SettlementsTypes.Debt)) AS AccountsReceivableBalances
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentAccountsReceivable.Company,
	|	DocumentAccountsReceivable.Counterparty,
	|	DocumentAccountsReceivable.Contract,
	|	DocumentAccountsReceivable.Document,
	|	DocumentAccountsReceivable.Order,
	|	DocumentAccountsReceivable.SettlementsType,
	|	CASE
	|		WHEN DocumentAccountsReceivable.RecordType = VALUE(AccumulationRecordType.Receipt)
	|			THEN -DocumentAccountsReceivable.AmountCur
	|		ELSE DocumentAccountsReceivable.AmountCur
	|	END
	|FROM
	|	AccumulationRegister.AccountsReceivable AS DocumentAccountsReceivable
	|WHERE
	|	DocumentAccountsReceivable.Recorder = &Ref
	|	AND DocumentAccountsReceivable.Period <= &Period
	|	AND DocumentAccountsReceivable.Company = &Company
	|	AND DocumentAccountsReceivable.Counterparty = &Counterparty
	|	AND DocumentAccountsReceivable.SettlementsType = VALUE(Enum.SettlementsTypes.Debt)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccountsReceivableTable.Counterparty AS Counterparty,
	|	AccountsReceivableTable.Contract AS Contract,
	|	AccountsReceivableTable.Document AS Document,
	|	AccountsReceivableTable.Order AS Order,
	|	SUM(AccountsReceivableTable.AmountCurBalance) AS AmountCurBalance
	|INTO AccountsReceivableGrouped
	|FROM
	|	AccountsReceivableTable AS AccountsReceivableTable
	|WHERE
	|	AccountsReceivableTable.AmountCurBalance > 0
	|
	|GROUP BY
	|	AccountsReceivableTable.Counterparty,
	|	AccountsReceivableTable.Contract,
	|	AccountsReceivableTable.Document,
	|	AccountsReceivableTable.Order
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccountsReceivableGrouped.Counterparty AS Counterparty,
	|	AccountsReceivableGrouped.Contract AS Contract,
	|	CASE
	|		WHEN Counterparties.DoOperationsByDocuments
	|			THEN AccountsReceivableGrouped.Document
	|		ELSE UNDEFINED
	|	END AS Document,
	|	CASE
	|		WHEN Counterparties.DoOperationsByOrders
	|			THEN AccountsReceivableGrouped.Order
	|		ELSE VALUE(Document.SalesOrder.EmptyRef)
	|	END AS Order,
	|	AccountsReceivableGrouped.AmountCurBalance AS AmountCurBalance,
	|	CounterpartyContracts.SettlementsCurrency AS SettlementsCurrency
	|INTO AccountsReceivableContract
	|FROM
	|	AccountsReceivableGrouped AS AccountsReceivableGrouped
	|		INNER JOIN Catalog.Counterparties AS Counterparties
	|		ON AccountsReceivableGrouped.Counterparty = Counterparties.Ref
	|		INNER JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
	|		ON AccountsReceivableGrouped.Contract = CounterpartyContracts.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	AccountsReceivableContract.Document AS Document
	|INTO DocumentTable
	|FROM
	|	AccountsReceivableContract AS AccountsReceivableContract
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SalesInvoiceEarlyPaymentDiscounts.DueDate AS DueDate,
	|	SalesInvoiceEarlyPaymentDiscounts.DiscountAmount AS DiscountAmount,
	|	SalesInvoiceEarlyPaymentDiscounts.Ref AS SalesInvoice
	|INTO EarlePaymentDiscounts
	|FROM
	|	Document.SalesInvoice.EarlyPaymentDiscounts AS SalesInvoiceEarlyPaymentDiscounts
	|		INNER JOIN DocumentTable AS DocumentTable
	|		ON SalesInvoiceEarlyPaymentDiscounts.Ref = DocumentTable.Document
	|WHERE
	|	ENDOFPERIOD(SalesInvoiceEarlyPaymentDiscounts.DueDate, DAY) >= &Period
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(EarlePaymentDiscounts.DueDate) AS DueDate,
	|	EarlePaymentDiscounts.SalesInvoice AS SalesInvoice
	|INTO EarlyPaymentMinDueDate
	|FROM
	|	EarlePaymentDiscounts AS EarlePaymentDiscounts
	|
	|GROUP BY
	|	EarlePaymentDiscounts.SalesInvoice
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TRUE AS ExistsEPD,
	|	EarlePaymentDiscounts.DiscountAmount AS DiscountAmount,
	|	EarlePaymentDiscounts.SalesInvoice AS SalesInvoice
	|INTO EarlyPaymentMaxDiscountAmount
	|FROM
	|	EarlePaymentDiscounts AS EarlePaymentDiscounts
	|		INNER JOIN EarlyPaymentMinDueDate AS EarlyPaymentMinDueDate
	|		ON EarlePaymentDiscounts.SalesInvoice = EarlyPaymentMinDueDate.SalesInvoice
	|			AND EarlePaymentDiscounts.DueDate = EarlyPaymentMinDueDate.DueDate
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	AccountingJournalEntries.Recorder AS Recorder,
	|	AccountingJournalEntries.Period AS Period
	|INTO EntriesRecorderPeriod
	|FROM
	|	AccountingRegister.AccountingJournalEntries AS AccountingJournalEntries
	|		INNER JOIN DocumentTable AS DocumentTable
	|		ON AccountingJournalEntries.Recorder = DocumentTable.Document
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccountsReceivableContract.Contract AS Contract,
	|	AccountsReceivableContract.Document AS Document,
	|	ISNULL(EntriesRecorderPeriod.Period, DATETIME(1, 1, 1)) AS DocumentDate,
	|	AccountsReceivableContract.Order AS Order,
	|	ExchangeRatesOfDocument.ExchangeRate AS CashAssetsRate,
	|	ExchangeRatesOfDocument.Multiplicity AS CashMultiplicity,
	|	SettlementsExchangeRates.ExchangeRate AS ExchangeRate,
	|	SettlementsExchangeRates.Multiplicity AS Multiplicity,
	|	AccountsReceivableContract.AmountCurBalance AS AmountCur,
	|	CAST(AccountsReceivableContract.AmountCurBalance * SettlementsExchangeRates.ExchangeRate * ExchangeRatesOfDocument.Multiplicity / (ExchangeRatesOfDocument.ExchangeRate * SettlementsExchangeRates.Multiplicity) AS NUMBER(15, 2)) AS AmountCurDocument,
	|	ISNULL(EarlyPaymentMaxDiscountAmount.DiscountAmount, 0) AS DiscountAmountCur,
	|	CAST(ISNULL(EarlyPaymentMaxDiscountAmount.DiscountAmount, 0) * SettlementsExchangeRates.ExchangeRate * ExchangeRatesOfDocument.Multiplicity / (ExchangeRatesOfDocument.ExchangeRate * SettlementsExchangeRates.Multiplicity) AS NUMBER(15, 2)) AS DiscountAmountCurDocument,
	|	ISNULL(EarlyPaymentMaxDiscountAmount.ExistsEPD, FALSE) AS ExistsEPD
	|INTO AccountsReceivableWithDiscount
	|FROM
	|	AccountsReceivableContract AS AccountsReceivableContract
	|		LEFT JOIN ExchangeRatesOnPeriod AS ExchangeRatesOfDocument
	|		ON (ExchangeRatesOfDocument.Currency = &Currency)
	|		LEFT JOIN ExchangeRatesOnPeriod AS SettlementsExchangeRates
	|		ON AccountsReceivableContract.SettlementsCurrency = SettlementsExchangeRates.Currency
	|		LEFT JOIN EarlyPaymentMaxDiscountAmount AS EarlyPaymentMaxDiscountAmount
	|		ON AccountsReceivableContract.Document = EarlyPaymentMaxDiscountAmount.SalesInvoice
	|		LEFT JOIN EntriesRecorderPeriod AS EntriesRecorderPeriod
	|		ON AccountsReceivableContract.Document = EntriesRecorderPeriod.Recorder
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccountsReceivableWithDiscount.Contract AS Contract,
	|	AccountsReceivableWithDiscount.Document AS Document,
	|	AccountsReceivableWithDiscount.DocumentDate AS DocumentDate,
	|	AccountsReceivableWithDiscount.Order AS Order,
	|	AccountsReceivableWithDiscount.CashAssetsRate AS CashAssetsRate,
	|	AccountsReceivableWithDiscount.CashMultiplicity AS CashMultiplicity,
	|	AccountsReceivableWithDiscount.ExchangeRate AS ExchangeRate,
	|	AccountsReceivableWithDiscount.Multiplicity AS Multiplicity,
	|	AccountsReceivableWithDiscount.AmountCur AS AmountCur,
	|	AccountsReceivableWithDiscount.AmountCurDocument AS AmountCurDocument,
	|	AccountsReceivableWithDiscount.DiscountAmountCur AS DiscountAmountCur,
	|	AccountsReceivableWithDiscount.DiscountAmountCurDocument AS DiscountAmountCurDocument,
	|	AccountsReceivableWithDiscount.ExistsEPD AS ExistsEPD
	|FROM
	|	AccountsReceivableWithDiscount AS AccountsReceivableWithDiscount
	|
	|ORDER BY
	|	DocumentDate
	|TOTALS
	|	SUM(AmountCurDocument),
	|	MAX(DiscountAmountCur),
	|	MAX(DiscountAmountCurDocument)
	|BY
	|	Document";
	
	Query.SetParameter("Company", ParentCompany);
	Query.SetParameter("Counterparty", Counterparty);
	Query.SetParameter("Period", Date);
	Query.SetParameter("Currency", CashCurrency);
	Query.SetParameter("Ref", Ref);
	
	ContractTypesList = Catalogs.CounterpartyContracts.GetContractKindsListForDocument(Ref, OperationKind);
	ContractByDefault = Catalogs.CounterpartyContracts.GetDefaultContractByCompanyContractKind(
		Counterparty,
		Company,
		ContractTypesList);
	
	StructureContractCurrencyRateByDefault = InformationRegisters.ExchangeRates.GetLast(
		Date,
		New Structure("Currency", ContractByDefault.SettlementsCurrency));
	
	PaymentDetails.Clear();
	
	AmountLeftToDistribute = DocumentAmount;
	
	ByGroupsSelection = Query.Execute().Select(QueryResultIteration.ByGroups);
	
	While ByGroupsSelection.Next() AND AmountLeftToDistribute > 0 Do
		
		If ByGroupsSelection.AmountCurDocument - ByGroupsSelection.DiscountAmountCurDocument <= AmountLeftToDistribute Then
			EPD				= ByGroupsSelection.DiscountAmountCurDocument;
			SettlementEPD	= ByGroupsSelection.DiscountAmountCur;
		Else
			EPD				= 0;
			SettlementEPD	= 0;
		EndIf;
		
		SelectionOfQueryResult = ByGroupsSelection.Select();
		
		While SelectionOfQueryResult.Next() AND AmountLeftToDistribute > 0 Do
			
			NewRow = PaymentDetails.Add();
			
			FillPropertyValues(NewRow, SelectionOfQueryResult);
			
			If SelectionOfQueryResult.AmountCurDocument >= EPD Then
				
				AmountCurDocument	= SelectionOfQueryResult.AmountCurDocument - EPD;
				AmountCur			= SelectionOfQueryResult.AmountCur - SettlementEPD;
				EPDAmountDocument	= EPD;
				EPDAmount			= SettlementEPD;
				EPD					= 0;
				SettlementEPD		= 0;
			Else
				
				AmountCurDocument	= 0;
				AmountCur			= 0;
				EPDAmountDocument	= SelectionOfQueryResult.AmountCurDocument;
				EPDAmount			= SelectionOfQueryResult.AmountCur;
				EPD					= EPD - SelectionOfQueryResult.AmountCurDocument;
				SettlementEPD		= SettlementEPD - SelectionOfQueryResult.AmountCur;
				
			EndIf;
			
			If AmountCurDocument <= AmountLeftToDistribute Then
				
				NewRow.SettlementsAmount	= AmountCur;
				NewRow.PaymentAmount		= AmountCurDocument;
				NewRow.EPDAmount			= EPDAmountDocument;
				NewRow.SettlementsEPDAmount	= EPDAmount;
				NewRow.VATRate				= DefaultVATRate;
				NewRow.VATAmount			= NewRow.PaymentAmount - (NewRow.PaymentAmount) / ((DefaultVATRate.Rate + 100) / 100);
				AmountLeftToDistribute		= AmountLeftToDistribute - AmountCurDocument;
				
			Else
				
				NewRow.SettlementsAmount = DriveServer.RecalculateFromCurrencyToCurrency(
					AmountLeftToDistribute,
					SelectionOfQueryResult.CashAssetsRate,
					SelectionOfQueryResult.ExchangeRate,
					SelectionOfQueryResult.CashMultiplicity,
					SelectionOfQueryResult.Multiplicity);
				
				NewRow.PaymentAmount		= AmountLeftToDistribute;
				NewRow.EPDAmount			= 0;
				NewRow.SettlementsEPDAmount	= 0;
				NewRow.VATRate				= DefaultVATRate;
				NewRow.VATAmount			= NewRow.PaymentAmount - (NewRow.PaymentAmount) / ((DefaultVATRate.Rate + 100) / 100);
				AmountLeftToDistribute		= 0;
				
			EndIf;
		EndDo;
	EndDo;
	
	If AmountLeftToDistribute > 0 Then
		
		NewRow = PaymentDetails.Add();
		
		NewRow.Contract = ContractByDefault;
		NewRow.ExchangeRate = ?(
			StructureContractCurrencyRateByDefault.ExchangeRate = 0,
			1,
			StructureContractCurrencyRateByDefault.ExchangeRate);
			
		NewRow.Multiplicity = ?(
			StructureContractCurrencyRateByDefault.Multiplicity = 0,
			1,
			StructureContractCurrencyRateByDefault.Multiplicity);
			
		NewRow.SettlementsAmount = DriveServer.RecalculateFromCurrencyToCurrency(
			AmountLeftToDistribute,
			ExchangeRateCurrenciesDC,
			NewRow.ExchangeRate,
			CurrencyUnitConversionFactor,
			NewRow.Multiplicity);
			
		NewRow.AdvanceFlag			= True;
		NewRow.PaymentAmount		= AmountLeftToDistribute;
		NewRow.EPDAmount			= 0;
		NewRow.SettlementsEPDAmount	= 0;
		NewRow.VATRate				= DefaultVATRate;
		NewRow.VATAmount			= NewRow.PaymentAmount - (NewRow.PaymentAmount) / ((DefaultVATRate.Rate + 100) / 100);
		
	EndIf;
	
	If PaymentDetails.Count() = 0 Then
		PaymentDetails.Add();
		PaymentDetails[0].PaymentAmount = DocumentAmount;
	EndIf;
	
	PaymentAmount = PaymentDetails.Total("PaymentAmount");
	
EndProcedure

// The procedure fills in counterparty bank account when entering on the basis
//
Procedure FillCounterpartyBankAcc()
	
	If Not ValueIsFilled(Counterparty) Then
		
		Return;
		
	EndIf;
	
	// 1. Counterparty bank account exists in the basis document and it is completed
	If ValueIsFilled(BasisDocument) Then
		
		If DriveServer.IsDocumentAttribute("CounterpartyBankAcc", BasisDocument.Metadata()) Then
			
			CounterpartyAccount = BasisDocument.CounterpartyBankAcc;
			
		EndIf;
		
	EndIf;
	
	// 2. Counterparty bank account is filled in based on currency of the document (taken from bank account
	//    of the organization) with the main bank account of the counterparty taken into account.
	If ValueIsFilled(CashCurrency) Then
		
		Query = New Query(
		"SELECT
		|	BankAccounts.Ref AS CounterpartyAccount,
		|	CASE
		|		WHEN BankAccounts.Owner.BankAccountByDefault = BankAccounts.Ref
		|			THEN TRUE
		|		ELSE FALSE
		|	END AS ThisIsMainBankAccount
		|FROM
		|	Catalog.BankAccounts AS BankAccounts
		|WHERE
		|	BankAccounts.Owner = &Owner
		|	AND BankAccounts.CashCurrency = &CashCurrency
		|
		|ORDER BY
		|	ThisIsMainBankAccount DESC");
		
		Query.SetParameter("Owner", Counterparty);
		Query.SetParameter("CashCurrency", CashCurrency);
		
		QueryResult = Query.Execute();
		
		If Not QueryResult.IsEmpty() Then
		
			Selection = QueryResult.Select();
			Selection.Next(); 
			
			CounterpartyAccount = Selection.CounterpartyAccount;
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Procedure of filling the document on the basis.
//
// Parameters:
// FillingData - Structure - Data on filling the document.
//	
Procedure FillByCashInflowForecast(BasisDocument, Amount = Undefined)
	
	Query = New Query;
	Query.SetParameter("Ref",	BasisDocument);
	Query.SetParameter("Date",	?(ValueIsFilled(Date), Date, CurrentDate()));
	
	If Amount <> Undefined Then
		
		Query.SetParameter("Amount", Amount);
		Query.Text =
		"SELECT
		|	VALUE(Enum.OperationTypesPaymentReceipt.FromCustomer) AS OperationKind,
		|	&Ref AS BasisDocument,
		|	DocumentTable.Company AS Company,
		|	DocumentTable.CashFlowItem AS Item,
		|	CASE
		|		WHEN DocumentTable.BankAccount <> VALUE(Catalog.BankAccounts.EmptyRef)
		|			THEN DocumentTable.BankAccount
		|		WHEN DocumentTable.Company.BankAccountByDefault.CashCurrency = DocumentTable.Contract.SettlementsCurrency
		|			THEN DocumentTable.Company.BankAccountByDefault
		|		ELSE NestedSelect.BankAccount
		|	END AS BankAccount,
		|	DocumentTable.DocumentCurrency AS CashCurrency,
		|	DocumentTable.Counterparty AS Counterparty,
		|	DocumentTable.Contract AS Contract,
		|	&Amount AS DocumentAmount,
		|	&Amount AS PaymentAmount,
		|	AccountingPolicySliceLast.DefaultVATRate AS VATRate,
		|	ISNULL(SettlementsExchangeRates.ExchangeRate, 1) AS ExchangeRate,
		|	ISNULL(SettlementsExchangeRates.Multiplicity, 1) AS Multiplicity,
		|	CAST(&Amount * CASE
		|			WHEN DocumentTable.DocumentCurrency <> DocumentTable.Contract.SettlementsCurrency
		|					AND SettlementsExchangeRates.ExchangeRate <> 0
		|					AND ExchangeRatesOfDocument.Multiplicity <> 0
		|				THEN ExchangeRatesOfDocument.ExchangeRate * SettlementsExchangeRates.Multiplicity / (ISNULL(SettlementsExchangeRates.ExchangeRate, 1) * ISNULL(ExchangeRatesOfDocument.Multiplicity, 1))
		|			ELSE 1
		|		END AS NUMBER(15, 2)) AS SettlementsAmount,
		|	CAST(&Amount * (1 - 1 / ((ISNULL(AccountingPolicySliceLast.DefaultVATRate.Rate, 0) + 100) / 100)) AS NUMBER(15, 2)) AS VATAmount
		|FROM
		|	Document.CashInflowForecast AS DocumentTable
		|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&Date, ) AS SettlementsExchangeRates
		|		ON DocumentTable.Contract.SettlementsCurrency = SettlementsExchangeRates.Currency
		|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&Date, ) AS ExchangeRatesOfDocument
		|		ON DocumentTable.DocumentCurrency = ExchangeRatesOfDocument.Currency
		|		LEFT JOIN InformationRegister.AccountingPolicy.SliceLast(&Date, ) AS AccountingPolicySliceLast
		|		ON DocumentTable.Company = AccountingPolicySliceLast.Company
		|		LEFT JOIN (SELECT TOP 1
		|			BankAccounts.Ref AS BankAccount,
		|			BankAccounts.Owner AS Owner,
		|			BankAccounts.CashCurrency AS CashCurrency
		|		FROM
		|			Document.CashInflowForecast AS DocumentTable
		|				LEFT JOIN Catalog.BankAccounts AS BankAccounts
		|				ON DocumentTable.Company = BankAccounts.Owner
		|					AND DocumentTable.DocumentCurrency = BankAccounts.CashCurrency
		|		WHERE
		|			DocumentTable.Ref = &Ref
		|			AND BankAccounts.DeletionMark = FALSE) AS NestedSelect
		|		ON DocumentTable.DocumentCurrency = NestedSelect.CashCurrency
		|			AND DocumentTable.Company = NestedSelect.Owner
		|WHERE
		|	DocumentTable.Ref = &Ref";
		
	Else
		
		Query.Text =
		"SELECT
		|	VALUE(Enum.OperationTypesPaymentReceipt.FromCustomer) AS OperationKind,
		|	&Ref AS BasisDocument,
		|	DocumentTable.Company AS Company,
		|	DocumentTable.CashFlowItem AS Item,
		|	CASE
		|		WHEN DocumentTable.BankAccount <> VALUE(Catalog.BankAccounts.EmptyRef)
		|			THEN DocumentTable.BankAccount
		|		WHEN DocumentTable.Company.BankAccountByDefault.CashCurrency = DocumentTable.Contract.SettlementsCurrency
		|			THEN DocumentTable.Company.BankAccountByDefault
		|		ELSE NestedSelect.BankAccount
		|	END AS BankAccount,
		|	DocumentTable.DocumentCurrency AS CashCurrency,
		|	DocumentTable.Counterparty AS Counterparty,
		|	DocumentTable.Contract AS Contract,
		|	DocumentTable.DocumentAmount AS DocumentAmount,
		|	DocumentTable.DocumentAmount AS PaymentAmount,
		|	AccountingPolicySliceLast.DefaultVATRate AS VATRate,
		|	ISNULL(SettlementsExchangeRates.ExchangeRate, 1) AS ExchangeRate,
		|	ISNULL(SettlementsExchangeRates.Multiplicity, 1) AS Multiplicity,
		|	CAST(DocumentTable.DocumentAmount * CASE
		|			WHEN DocumentTable.DocumentCurrency <> DocumentTable.Contract.SettlementsCurrency
		|					AND SettlementsExchangeRates.ExchangeRate <> 0
		|					AND ExchangeRatesOfDocument.Multiplicity <> 0
		|				THEN ExchangeRatesOfDocument.ExchangeRate * SettlementsExchangeRates.Multiplicity / (ISNULL(SettlementsExchangeRates.ExchangeRate, 1) * ISNULL(ExchangeRatesOfDocument.Multiplicity, 1))
		|			ELSE 1
		|		END AS NUMBER(15, 2)) AS SettlementsAmount,
		|	CAST(DocumentTable.DocumentAmount * (1 - 1 / ((ISNULL(AccountingPolicySliceLast.DefaultVATRate.Rate, 0) + 100) / 100)) AS NUMBER(15, 2)) AS VATAmount
		|FROM
		|	Document.CashInflowForecast AS DocumentTable
		|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&Date, ) AS SettlementsExchangeRates
		|		ON DocumentTable.Contract.SettlementsCurrency = SettlementsExchangeRates.Currency
		|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&Date, ) AS ExchangeRatesOfDocument
		|		ON DocumentTable.DocumentCurrency = ExchangeRatesOfDocument.Currency
		|		LEFT JOIN InformationRegister.AccountingPolicy.SliceLast(&Date, ) AS AccountingPolicySliceLast
		|		ON DocumentTable.Company = AccountingPolicySliceLast.Company
		|		LEFT JOIN (SELECT TOP 1
		|			BankAccounts.Ref AS BankAccount,
		|			BankAccounts.Owner AS Owner,
		|			BankAccounts.CashCurrency AS CashCurrency
		|		FROM
		|			Document.CashInflowForecast AS DocumentTable
		|				LEFT JOIN Catalog.BankAccounts AS BankAccounts
		|				ON DocumentTable.Company = BankAccounts.Owner
		|					AND DocumentTable.DocumentCurrency = BankAccounts.CashCurrency
		|		WHERE
		|			DocumentTable.Ref = &Ref
		|			AND BankAccounts.DeletionMark = FALSE) AS NestedSelect
		|		ON DocumentTable.DocumentCurrency = NestedSelect.CashCurrency
		|			AND DocumentTable.Company = NestedSelect.Owner
		|WHERE
		|	DocumentTable.Ref = &Ref";
		
	EndIf;
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		
		Selection = QueryResult.Select();
		Selection.Next();
		FillPropertyValues(ThisObject, Selection);
		
		VATTaxation = DriveServer.VATTaxation(Company, Date);
		
		PaymentDetails.Clear();
		NewRow = PaymentDetails.Add();
		FillPropertyValues(NewRow, Selection);
		NewRow.AdvanceFlag = True;
		NewRow.PlanningDocument = BasisDocument;
		
		If ValueIsFilled(BasisDocument.BasisDocument)
			AND TypeOf(BasisDocument.BasisDocument) = Type("DocumentRef.SalesOrder")
			AND Counterparty.DoOperationsByOrders Then
			
			NewRow.Order = BasisDocument.BasisDocument;
			
		EndIf;
		
	EndIf;
	
	FillCounterpartyBankAcc();
	
EndProcedure

// Procedure of filling the document on the basis.
//
// Parameters:
// FillingData - Structure - Data on filling the document.
//	
Procedure FillByCashTransferPlan(BasisDocument, Amount = Undefined)
	
	If BasisDocument.PaymentConfirmationStatus = Enums.PaymentApprovalStatuses.NotApproved Then
		Raise NStr("en = 'Please select an approved cash transfer plan.'");
	EndIf;
	
	Query = New Query;
	Query.SetParameter("Ref", BasisDocument);
	
	// Fill document header data.
	Query.Text =
	"SELECT
	|	VALUE(Enum.OperationTypesPaymentReceipt.Other) AS OperationKind,
	|	&Ref AS BasisDocument,
	|	DocumentTable.Company AS Company,
	|	VALUE(Enum.VATTaxationTypes.SubjectToVAT) AS VATTaxation,
	|	DocumentTable.CashFlowItem AS Item,
	|	DocumentTable.BankAccountPayee AS BankAccount,
	|	DocumentTable.BankAccountPayee.CashCurrency AS CashCurrency,
	|	DocumentTable.DocumentAmount AS DocumentAmount,
	|	DocumentTable.DocumentAmount AS PaymentAmount
	|FROM
	|	Document.CashTransferPlan AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref";
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		
		Selection = QueryResult.Select();
		Selection.Next();
		FillPropertyValues(ThisObject, Selection);
		VATTaxation = DriveServer.VATTaxation(Company, Date);
		If Amount <> Undefined Then
			DocumentAmount = Amount;
		EndIf;
		PaymentDetails.Clear();
		NewRow = PaymentDetails.Add();
		FillPropertyValues(NewRow, Selection);
		NewRow.PlanningDocument = BasisDocument;
		
	EndIf;
	
EndProcedure

// Procedure of filling the document on the basis.
//
// Parameters:
// FillingData - Structure - Data on filling the document.
//	
Procedure FillByQuote(FillingData, LineNumber = Undefined, Amount = Undefined)
	
	Query = New Query();
	
	If Amount <> Undefined Then
		
		Query.SetParameter("Ref", FillingData);
		Query.SetParameter("Date", ?(ValueIsFilled(Date), Date, CurrentDate()));
		Query.SetParameter("Amount", Amount);
		
		// Fill data of the document tabular sections.
		Query.Text =
		"SELECT
		|	VALUE(Enum.OperationTypesPaymentReceipt.FromCustomer) AS OperationKind,
		|	&Ref AS BasisDocument,
		|	DocumentHeader.Company AS Company,
		|	DocumentHeader.VATTaxation AS VATTaxation,
		|	NestedSelect.CashCurrency AS CashCurrency,
		|	NestedSelect.BankAccount AS BankAccount,
		|	DocumentHeader.Counterparty AS Counterparty,
		|	DocumentHeader.Contract AS Contract,
		|	DocumentHeader.DocumentCurrency AS DocumentCurrency,
		|	TRUE AS AdvanceFlag,
		|	UNDEFINED AS Document,
		|	VALUE(Document.SalesOrder.EmptyRef) AS Order,
		|	VALUE(Document.Quote.EmptyRef) AS Quote,
		|	DocumentTable.VATRate AS VATRate,
		|	SettlementsExchangeRates.ExchangeRate AS ExchangeRate,
		|	SettlementsExchangeRates.Multiplicity AS Multiplicity,
		|	CAST(&Amount * CASE
		|			WHEN DocumentHeader.DocumentCurrency <> DocumentHeader.Contract.SettlementsCurrency
		|					AND SettlementsExchangeRates.ExchangeRate <> 0
		|					AND ExchangeRatesOfDocument.Multiplicity <> 0
		|				THEN ExchangeRatesOfDocument.ExchangeRate * SettlementsExchangeRates.Multiplicity / (ISNULL(SettlementsExchangeRates.ExchangeRate, 1) * ISNULL(ExchangeRatesOfDocument.Multiplicity, 1))
		|			ELSE 1
		|		END AS NUMBER(15, 2)) AS SettlementsAmount,
		|	CAST(&Amount * CASE
		|			WHEN DocumentHeader.DocumentCurrency <> NestedSelect.CashCurrency
		|					AND ExchangeRatesOfDocument.Multiplicity <> 0
		|					AND BankAcountExchangeRates.ExchangeRate <> 0
		|				THEN ExchangeRatesOfDocument.ExchangeRate * BankAcountExchangeRates.Multiplicity / (ISNULL(BankAcountExchangeRates.ExchangeRate, 1) * ISNULL(ExchangeRatesOfDocument.Multiplicity, 1))
		|			ELSE 1
		|		END AS NUMBER(15, 2)) AS PaymentAmount,
		|	CAST(&Amount * (1 - 1 / ((ISNULL(DocumentTable.VATRate.Rate, 0) + 100) / 100)) * CASE
		|			WHEN DocumentHeader.DocumentCurrency <> NestedSelect.CashCurrency
		|					AND ExchangeRatesOfDocument.Multiplicity <> 0
		|					AND BankAcountExchangeRates.ExchangeRate <> 0
		|				THEN ExchangeRatesOfDocument.ExchangeRate * BankAcountExchangeRates.Multiplicity / (ISNULL(BankAcountExchangeRates.ExchangeRate, 1) * ISNULL(ExchangeRatesOfDocument.Multiplicity, 1))
		|			ELSE 1
		|		END AS NUMBER(15, 2)) AS VATAmount,
		|	CAST(&Amount * CASE
		|			WHEN DocumentHeader.DocumentCurrency <> NestedSelect.CashCurrency
		|					AND ExchangeRatesOfDocument.Multiplicity <> 0
		|					AND BankAcountExchangeRates.ExchangeRate <> 0
		|				THEN ExchangeRatesOfDocument.ExchangeRate * BankAcountExchangeRates.Multiplicity / (ISNULL(BankAcountExchangeRates.ExchangeRate, 1) * ISNULL(ExchangeRatesOfDocument.Multiplicity, 1))
		|			ELSE 1
		|		END AS NUMBER(15, 2)) AS DocumentAmount
		|FROM
		|	Document.Quote AS DocumentHeader
		|		LEFT JOIN Document.Quote.Inventory AS DocumentTable
		|		ON DocumentHeader.Ref = DocumentTable.Ref
		|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&Date, ) AS SettlementsExchangeRates
		|		ON DocumentHeader.Contract.SettlementsCurrency = SettlementsExchangeRates.Currency
		|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&Date, ) AS ExchangeRatesOfDocument
		|		ON DocumentHeader.DocumentCurrency = ExchangeRatesOfDocument.Currency
		|		LEFT JOIN (SELECT TOP 1
		|			CASE
		|				WHEN DocumentTable.BankAccount <> VALUE(Catalog.BankAccounts.EmptyRef)
		|					THEN DocumentTable.BankAccount
		|				WHEN DocumentTable.Company.BankAccountByDefault.CashCurrency = DocumentTable.Contract.SettlementsCurrency
		|					THEN DocumentTable.Company.BankAccountByDefault
		|				WHEN ISNULL(BankAccounts.Ref, VALUE(Catalog.BankAccounts.EmptyRef)) <> VALUE(Catalog.BankAccounts.EmptyRef)
		|					THEN BankAccounts.Ref
		|				ELSE DocumentTable.Company.BankAccountByDefault
		|			END AS BankAccount,
		|			CASE
		|				WHEN DocumentTable.BankAccount <> VALUE(Catalog.BankAccounts.EmptyRef)
		|					THEN DocumentTable.BankAccount.CashCurrency
		|				WHEN DocumentTable.Company.BankAccountByDefault.CashCurrency = DocumentTable.Contract.SettlementsCurrency
		|					THEN DocumentTable.Company.BankAccountByDefault.CashCurrency
		|				WHEN ISNULL(BankAccounts.Ref, VALUE(Catalog.BankAccounts.EmptyRef)) <> VALUE(Catalog.BankAccounts.EmptyRef)
		|					THEN BankAccounts.CashCurrency
		|				ELSE DocumentTable.Company.BankAccountByDefault.CashCurrency
		|			END AS CashCurrency,
		|			CASE
		|				WHEN DocumentTable.BankAccount <> VALUE(Catalog.BankAccounts.EmptyRef)
		|					THEN DocumentTable.BankAccount.Owner
		|				WHEN DocumentTable.Company.BankAccountByDefault.CashCurrency = DocumentTable.Contract.SettlementsCurrency
		|					THEN DocumentTable.Company.BankAccountByDefault.Owner
		|				WHEN ISNULL(BankAccounts.Ref, VALUE(Catalog.BankAccounts.EmptyRef)) <> VALUE(Catalog.BankAccounts.EmptyRef)
		|					THEN BankAccounts.Ref.Owner
		|				ELSE DocumentTable.Company.BankAccountByDefault.Owner
		|			END AS Owner
		|		FROM
		|			Document.Quote AS DocumentTable
		|				LEFT JOIN Catalog.BankAccounts AS BankAccounts
		|				ON DocumentTable.Company = BankAccounts.Owner
		|					AND DocumentTable.DocumentCurrency = BankAccounts.CashCurrency
		|					AND (BankAccounts.DeletionMark = FALSE)
		|		WHERE
		|			DocumentTable.Ref = &Ref) AS NestedSelect
		|			LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&Date, ) AS BankAcountExchangeRates
		|			ON NestedSelect.CashCurrency = BankAcountExchangeRates.Currency
		|		ON DocumentHeader.Company = NestedSelect.Owner
		|WHERE
		|	DocumentHeader.Ref = &Ref
		|	AND ISNULL(DocumentTable.LineNumber, 1) = 1";
		
	ElsIf LineNumber = Undefined Then
		
		Query.SetParameter("Ref", FillingData);
		Query.SetParameter("Date", ?(ValueIsFilled(Date), Date, CurrentDate()));
		
		// Fill data of the document tabular sections.
		Query.Text =
		"SELECT
		|	VALUE(Enum.OperationTypesPaymentReceipt.FromCustomer) AS OperationKind,
		|	&Ref AS BasisDocument,
		|	DocumentHeader.Company AS Company,
		|	DocumentHeader.VATTaxation AS VATTaxation,
		|	NestedSelect.CashCurrency AS CashCurrency,
		|	NestedSelect.BankAccount AS BankAccount,
		|	DocumentHeader.Counterparty AS Counterparty,
		|	DocumentHeader.Contract AS Contract,
		|	DocumentHeader.DocumentCurrency AS DocumentCurrency,
		|	TRUE AS AdvanceFlag,
		|	UNDEFINED AS Document,
		|	VALUE(Document.SalesOrder.EmptyRef) AS Order,
		|	VALUE(Document.Quote.EmptyRef) AS Quote,
		|	DocumentTable.VATRate AS VATRate,
		|	SettlementsExchangeRates.ExchangeRate AS ExchangeRate,
		|	SettlementsExchangeRates.Multiplicity AS Multiplicity,
		|	SUM(CAST(DocumentTable.Total * CASE
		|				WHEN DocumentHeader.DocumentCurrency <> DocumentHeader.Contract.SettlementsCurrency
		|						AND SettlementsExchangeRates.ExchangeRate <> 0
		|						AND ExchangeRatesOfDocument.Multiplicity <> 0
		|					THEN ExchangeRatesOfDocument.ExchangeRate * SettlementsExchangeRates.Multiplicity / (ISNULL(SettlementsExchangeRates.ExchangeRate, 1) * ISNULL(ExchangeRatesOfDocument.Multiplicity, 1))
		|				ELSE 1
		|			END AS NUMBER(15, 2))) AS SettlementsAmount,
		|	SUM(CAST(DocumentTable.Total * CASE
		|				WHEN DocumentHeader.DocumentCurrency <> NestedSelect.CashCurrency
		|						AND ExchangeRatesOfDocument.Multiplicity <> 0
		|						AND BankAcountExchangeRates.ExchangeRate <> 0
		|					THEN ExchangeRatesOfDocument.ExchangeRate * BankAcountExchangeRates.Multiplicity / (ISNULL(BankAcountExchangeRates.ExchangeRate, 1) * ISNULL(ExchangeRatesOfDocument.Multiplicity, 1))
		|				ELSE 1
		|			END AS NUMBER(15, 2))) AS PaymentAmount,
		|	SUM(CAST(DocumentTable.VATAmount * CASE
		|				WHEN DocumentHeader.DocumentCurrency <> NestedSelect.CashCurrency
		|						AND ExchangeRatesOfDocument.Multiplicity <> 0
		|						AND BankAcountExchangeRates.ExchangeRate <> 0
		|					THEN ExchangeRatesOfDocument.ExchangeRate * BankAcountExchangeRates.Multiplicity / (ISNULL(BankAcountExchangeRates.ExchangeRate, 1) * ISNULL(ExchangeRatesOfDocument.Multiplicity, 1))
		|				ELSE 1
		|			END AS NUMBER(15, 2))) AS VATAmount,
		|	SUM(CAST(DocumentTable.Total * CASE
		|				WHEN DocumentHeader.DocumentCurrency <> NestedSelect.CashCurrency
		|						AND ExchangeRatesOfDocument.Multiplicity <> 0
		|						AND BankAcountExchangeRates.ExchangeRate <> 0
		|					THEN ExchangeRatesOfDocument.ExchangeRate * BankAcountExchangeRates.Multiplicity / (ISNULL(BankAcountExchangeRates.ExchangeRate, 1) * ISNULL(ExchangeRatesOfDocument.Multiplicity, 1))
		|				ELSE 1
		|			END AS NUMBER(15, 2))) AS DocumentAmount
		|FROM
		|	Document.Quote AS DocumentHeader
		|		LEFT JOIN Document.Quote.Inventory AS DocumentTable
		|		ON DocumentHeader.Ref = DocumentTable.Ref
		|		And DocumentHeader.PreferredVariant = DocumentTable.Variant
		|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&Date, ) AS SettlementsExchangeRates
		|		ON DocumentHeader.Contract.SettlementsCurrency = SettlementsExchangeRates.Currency
		|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&Date, ) AS ExchangeRatesOfDocument
		|		ON DocumentHeader.DocumentCurrency = ExchangeRatesOfDocument.Currency
		|		LEFT JOIN (SELECT TOP 1
		|			CASE
		|				WHEN DocumentTable.BankAccount <> VALUE(Catalog.BankAccounts.EmptyRef)
		|					THEN DocumentTable.BankAccount
		|				WHEN DocumentTable.Company.BankAccountByDefault.CashCurrency = DocumentTable.Contract.SettlementsCurrency
		|					THEN DocumentTable.Company.BankAccountByDefault
		|				WHEN ISNULL(BankAccounts.Ref, VALUE(Catalog.BankAccounts.EmptyRef)) <> VALUE(Catalog.BankAccounts.EmptyRef)
		|					THEN BankAccounts.Ref
		|				ELSE DocumentTable.Company.BankAccountByDefault
		|			END AS BankAccount,
		|			CASE
		|				WHEN DocumentTable.BankAccount <> VALUE(Catalog.BankAccounts.EmptyRef)
		|					THEN DocumentTable.BankAccount.CashCurrency
		|				WHEN DocumentTable.Company.BankAccountByDefault.CashCurrency = DocumentTable.Contract.SettlementsCurrency
		|					THEN DocumentTable.Company.BankAccountByDefault.CashCurrency
		|				WHEN ISNULL(BankAccounts.Ref, VALUE(Catalog.BankAccounts.EmptyRef)) <> VALUE(Catalog.BankAccounts.EmptyRef)
		|					THEN BankAccounts.CashCurrency
		|				ELSE DocumentTable.Company.BankAccountByDefault.CashCurrency
		|			END AS CashCurrency,
		|			CASE
		|				WHEN DocumentTable.BankAccount <> VALUE(Catalog.BankAccounts.EmptyRef)
		|					THEN DocumentTable.BankAccount.Owner
		|				WHEN DocumentTable.Company.BankAccountByDefault.CashCurrency = DocumentTable.Contract.SettlementsCurrency
		|					THEN DocumentTable.Company.BankAccountByDefault.Owner
		|				WHEN ISNULL(BankAccounts.Ref, VALUE(Catalog.BankAccounts.EmptyRef)) <> VALUE(Catalog.BankAccounts.EmptyRef)
		|					THEN BankAccounts.Ref.Owner
		|				ELSE DocumentTable.Company.BankAccountByDefault.Owner
		|			END AS Owner
		|		FROM
		|			Document.Quote AS DocumentTable
		|				LEFT JOIN Catalog.BankAccounts AS BankAccounts
		|				ON DocumentTable.Company = BankAccounts.Owner
		|					AND DocumentTable.DocumentCurrency = BankAccounts.CashCurrency
		|					AND (BankAccounts.DeletionMark = FALSE)
		|		WHERE
		|			DocumentTable.Ref = &Ref) AS NestedSelect
		|			LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&Date, ) AS BankAcountExchangeRates
		|			ON NestedSelect.CashCurrency = BankAcountExchangeRates.Currency
		|		ON DocumentHeader.Company = NestedSelect.Owner
		|WHERE
		|	DocumentHeader.Ref = &Ref
		|
		|GROUP BY
		|	DocumentHeader.Company,
		|	DocumentHeader.VATTaxation,
		|	DocumentHeader.DocumentCurrency,
		|	DocumentHeader.Counterparty,
		|	DocumentHeader.Contract,
		|	NestedSelect.CashCurrency,
		|	NestedSelect.BankAccount,
		|	DocumentTable.VATRate,
		|	SettlementsExchangeRates.ExchangeRate,
		|	SettlementsExchangeRates.Multiplicity,
		|	TRUE,
		|	VALUE(Document.SalesOrder.EmptyRef),
		|	VALUE(Document.Quote.EmptyRef),
		|	CASE
		|		WHEN DocumentHeader.BankAccount <> VALUE(Catalog.BankAccounts.EmptyRef)
		|			THEN DocumentHeader.BankAccount
		|		WHEN DocumentHeader.Company.BankAccountByDefault.CashCurrency = DocumentHeader.Contract.SettlementsCurrency
		|			THEN DocumentHeader.Company.BankAccountByDefault
		|		ELSE NestedSelect.BankAccount
		|	END,
		|	UNDEFINED";
		
	Else
	
		Query.SetParameter("Ref", FillingData.Basis);
		Query.SetParameter("LineNumber", LineNumber);
		Query.SetParameter("Date", ?(ValueIsFilled(Date), Date, CurrentDate()));
		
		// Fill document header data.
		Query.Text =
		"SELECT
		|	VALUE(Enum.OperationTypesPaymentReceipt.FromCustomer) AS OperationKind,
		|	&Ref AS BasisDocument,
		|	DocumentTable.Ref.Company AS Company,
		|	DocumentTable.Ref.VATTaxation AS VATTaxation,
		|	NestedSelect.CashCurrency AS CashCurrency,
		|	NestedSelect.BankAccount AS BankAccount,
		|	DocumentTable.Ref.Counterparty AS Counterparty,
		|	DocumentTable.Ref.Contract AS Contract,
		|	DocumentTable.Ref.DocumentCurrency AS DocumentCurrency,
		|	TRUE AS AdvanceFlag,
		|	UNDEFINED AS Document,
		|	VALUE(Document.SalesOrder.EmptyRef) AS Order,
		|	VALUE(Document.Quote.EmptyRef) AS Quote,
		|	ISNULL(VATRatesDocumentsTable.VATRate, VATRates.VATRate) AS VATRate,
		|	SettlementsExchangeRates.ExchangeRate AS ExchangeRate,
		|	SettlementsExchangeRates.Multiplicity AS Multiplicity,
		|	CAST((DocumentTable.PaymentAmount + DocumentTable.PaymentVATAmount) * CASE
		|			WHEN DocumentTable.Ref.DocumentCurrency <> DocumentTable.Ref.Contract.SettlementsCurrency
		|					AND SettlementsExchangeRates.ExchangeRate <> 0
		|					AND ExchangeRatesOfDocument.Multiplicity <> 0
		|				THEN ExchangeRatesOfDocument.ExchangeRate * SettlementsExchangeRates.Multiplicity / (ISNULL(SettlementsExchangeRates.ExchangeRate, 1) * ISNULL(ExchangeRatesOfDocument.Multiplicity, 1))
		|			ELSE 1
		|		END AS NUMBER(15, 2)) AS SettlementsAmount,
		|	CAST((DocumentTable.PaymentAmount + DocumentTable.PaymentVATAmount) * CASE
		|			WHEN DocumentTable.Ref.DocumentCurrency <> NestedSelect.CashCurrency
		|					AND ExchangeRatesOfDocument.Multiplicity <> 0
		|					AND BankAcountExchangeRates.ExchangeRate <> 0
		|				THEN ExchangeRatesOfDocument.ExchangeRate * BankAcountExchangeRates.Multiplicity / (ISNULL(BankAcountExchangeRates.ExchangeRate, 1) * ISNULL(ExchangeRatesOfDocument.Multiplicity, 1))
		|			ELSE 1
		|		END AS NUMBER(15, 2)) AS PaymentAmount,
		|	CAST(DocumentTable.PaymentVATAmount * CASE
		|			WHEN DocumentTable.Ref.DocumentCurrency <> NestedSelect.CashCurrency
		|					AND ExchangeRatesOfDocument.Multiplicity <> 0
		|					AND BankAcountExchangeRates.ExchangeRate <> 0
		|				THEN ExchangeRatesOfDocument.ExchangeRate * BankAcountExchangeRates.Multiplicity / (ISNULL(BankAcountExchangeRates.ExchangeRate, 1) * ISNULL(ExchangeRatesOfDocument.Multiplicity, 1))
		|			ELSE 1
		|		END AS NUMBER(15, 2)) AS VATAmount,
		|	CAST((DocumentTable.PaymentAmount + DocumentTable.PaymentVATAmount) * CASE
		|			WHEN DocumentTable.Ref.DocumentCurrency <> NestedSelect.CashCurrency
		|					AND ExchangeRatesOfDocument.Multiplicity <> 0
		|					AND BankAcountExchangeRates.ExchangeRate <> 0
		|				THEN ExchangeRatesOfDocument.ExchangeRate * BankAcountExchangeRates.Multiplicity / (ISNULL(BankAcountExchangeRates.ExchangeRate, 1) * ISNULL(ExchangeRatesOfDocument.Multiplicity, 1))
		|			ELSE 1
		|		END AS NUMBER(15, 2)) AS DocumentAmount
		|FROM
		|	Document.Quote.PaymentCalendar AS DocumentTable
		|		LEFT JOIN (SELECT TOP 1
		|			VATRates.Ref AS VATRate
		|		FROM
		|			Catalog.VATRates AS VATRates
		|		WHERE
		|			VATRates.Rate = 18
		|			AND VATRates.DeletionMark = FALSE
		|			AND VATRates.Calculated = FALSE) AS VATRates
		|		ON (TRUE)
		|		LEFT JOIN (SELECT TOP 1
		|			DocumentTable.Ref AS Ref,
		|			DocumentTable.VATRate AS VATRate
		|		FROM
		|			Document.Quote.Inventory AS DocumentTable
		|		WHERE
		|			DocumentTable.Ref = &Ref) AS VATRatesDocumentsTable
		|		ON DocumentTable.Ref = VATRatesDocumentsTable.Ref
		|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&Date, ) AS SettlementsExchangeRates
		|		ON DocumentTable.Ref.Contract.SettlementsCurrency = SettlementsExchangeRates.Currency
		|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&Date, ) AS ExchangeRatesOfDocument
		|		ON DocumentTable.Ref.DocumentCurrency = ExchangeRatesOfDocument.Currency
		|		LEFT JOIN (SELECT TOP 1
		|			CASE
		|				WHEN DocumentTable.BankAccount <> VALUE(Catalog.BankAccounts.EmptyRef)
		|					THEN DocumentTable.BankAccount
		|				WHEN DocumentTable.Company.BankAccountByDefault.CashCurrency = DocumentTable.Contract.SettlementsCurrency
		|					THEN DocumentTable.Company.BankAccountByDefault
		|				WHEN ISNULL(BankAccounts.Ref, VALUE(Catalog.BankAccounts.EmptyRef)) <> VALUE(Catalog.BankAccounts.EmptyRef)
		|					THEN BankAccounts.Ref
		|				ELSE DocumentTable.Company.BankAccountByDefault
		|			END AS BankAccount,
		|			CASE
		|				WHEN DocumentTable.BankAccount <> VALUE(Catalog.BankAccounts.EmptyRef)
		|					THEN DocumentTable.BankAccount.CashCurrency
		|				WHEN DocumentTable.Company.BankAccountByDefault.CashCurrency = DocumentTable.Contract.SettlementsCurrency
		|					THEN DocumentTable.Company.BankAccountByDefault.CashCurrency
		|				WHEN ISNULL(BankAccounts.Ref, VALUE(Catalog.BankAccounts.EmptyRef)) <> VALUE(Catalog.BankAccounts.EmptyRef)
		|					THEN BankAccounts.CashCurrency
		|				ELSE DocumentTable.Company.BankAccountByDefault.CashCurrency
		|			END AS CashCurrency,
		|			CASE
		|				WHEN DocumentTable.BankAccount <> VALUE(Catalog.BankAccounts.EmptyRef)
		|					THEN DocumentTable.BankAccount.Owner
		|				WHEN DocumentTable.Company.BankAccountByDefault.CashCurrency = DocumentTable.Contract.SettlementsCurrency
		|					THEN DocumentTable.Company.BankAccountByDefault.Owner
		|				WHEN ISNULL(BankAccounts.Ref, VALUE(Catalog.BankAccounts.EmptyRef)) <> VALUE(Catalog.BankAccounts.EmptyRef)
		|					THEN BankAccounts.Ref.Owner
		|				ELSE DocumentTable.Company.BankAccountByDefault.Owner
		|			END AS Owner
		|		FROM
		|			Document.Quote AS DocumentTable
		|				LEFT JOIN Catalog.BankAccounts AS BankAccounts
		|				ON DocumentTable.Company = BankAccounts.Owner
		|					AND DocumentTable.DocumentCurrency = BankAccounts.CashCurrency
		|					AND (BankAccounts.DeletionMark = FALSE)
		|		WHERE
		|			DocumentTable.Ref = &Ref) AS NestedSelect
		|			LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&Date, ) AS BankAcountExchangeRates
		|			ON NestedSelect.CashCurrency = BankAcountExchangeRates.Currency
		|		ON DocumentTable.Ref.Company = NestedSelect.Owner
		|WHERE
		|	DocumentTable.Ref = &Ref
		|	AND DocumentTable.LineNumber = &LineNumber";
		
	EndIf;
	
	Selection = Query.Execute().Select();
	PaymentDetails.Clear();
	
	While Selection.Next() Do
		
		FillPropertyValues(ThisObject, Selection);
		If Not ValueIsFilled(CashCurrency) Then
			CashCurrency = Selection.DocumentCurrency;
		EndIf;
		NewRow = PaymentDetails.Add();
		FillPropertyValues(NewRow, Selection);
		If Not VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then
			FillVATRateByVATTaxation(NewRow);
		EndIf;
		
	EndDo;
	
	DocumentAmount = PaymentDetails.Total("PaymentAmount");
	
	FillCounterpartyBankAcc();
	
EndProcedure

// Procedure of filling the document on the basis.
//
// Parameters:
// FillingData - Structure - Data on filling the document.
//	
Procedure FillBySalesOrder(FillingData, LineNumber = Undefined, Amount = Undefined)
	
	Query = New Query();
	
	If Amount <> Undefined Then
		
		Query.SetParameter("Ref", FillingData);
		Query.SetParameter("Date", ?(ValueIsFilled(Date), Date, CurrentDate()));
		Query.SetParameter("Amount", Amount);
		
		// Fill data of the document tabular sections.
		Query.Text =
		"SELECT
		|	VALUE(Enum.OperationTypesPaymentReceipt.FromCustomer) AS OperationKind,
		|	&Ref AS BasisDocument,
		|	DocumentHeader.Company AS Company,
		|	DocumentHeader.VATTaxation AS VATTaxation,
		|	NestedSelect.CashCurrency AS CashCurrency,
		|	NestedSelect.BankAccount AS BankAccount,
		|	DocumentHeader.Counterparty AS Counterparty,
		|	DocumentHeader.Contract AS Contract,
		|	DocumentHeader.DocumentCurrency AS DocumentCurrency,
		|	TRUE AS AdvanceFlag,
		|	UNDEFINED AS Document,
		|	CASE
		|		WHEN DocumentHeader.Counterparty.DoOperationsByOrders
		|			THEN &Ref
		|		ELSE VALUE(Document.SalesOrder.EmptyRef)
		|	END AS Order,
		|	DocumentTable.VATRate AS VATRate,
		|	SettlementsExchangeRates.ExchangeRate AS ExchangeRate,
		|	SettlementsExchangeRates.Multiplicity AS Multiplicity,
		|	CAST(&Amount * CASE
		|			WHEN DocumentHeader.DocumentCurrency <> DocumentHeader.Contract.SettlementsCurrency
		|					AND SettlementsExchangeRates.ExchangeRate <> 0
		|					AND ExchangeRatesOfDocument.Multiplicity <> 0
		|				THEN ExchangeRatesOfDocument.ExchangeRate * SettlementsExchangeRates.Multiplicity / (ISNULL(SettlementsExchangeRates.ExchangeRate, 1) * ISNULL(ExchangeRatesOfDocument.Multiplicity, 1))
		|			ELSE 1
		|		END AS NUMBER(15, 2)) AS SettlementsAmount,
		|	CAST(&Amount * CASE
		|			WHEN DocumentHeader.DocumentCurrency <> NestedSelect.CashCurrency
		|					AND ExchangeRatesOfDocument.Multiplicity <> 0
		|					AND BankAcountExchangeRates.ExchangeRate <> 0
		|				THEN ExchangeRatesOfDocument.ExchangeRate * BankAcountExchangeRates.Multiplicity / (ISNULL(BankAcountExchangeRates.ExchangeRate, 1) * ISNULL(ExchangeRatesOfDocument.Multiplicity, 1))
		|			ELSE 1
		|		END AS NUMBER(15, 2)) AS PaymentAmount,
		|	CAST(&Amount * (1 - 1 / ((ISNULL(DocumentTable.VATRate.Rate, 0) + 100) / 100)) * CASE
		|			WHEN DocumentHeader.DocumentCurrency <> NestedSelect.CashCurrency
		|					AND ExchangeRatesOfDocument.Multiplicity <> 0
		|					AND BankAcountExchangeRates.ExchangeRate <> 0
		|				THEN ExchangeRatesOfDocument.ExchangeRate * BankAcountExchangeRates.Multiplicity / (ISNULL(BankAcountExchangeRates.ExchangeRate, 1) * ISNULL(ExchangeRatesOfDocument.Multiplicity, 1))
		|			ELSE 1
		|		END AS NUMBER(15, 2)) AS VATAmount,
		|	CAST(&Amount * CASE
		|			WHEN DocumentHeader.DocumentCurrency <> NestedSelect.CashCurrency
		|					AND ExchangeRatesOfDocument.Multiplicity <> 0
		|					AND BankAcountExchangeRates.ExchangeRate <> 0
		|				THEN ExchangeRatesOfDocument.ExchangeRate * BankAcountExchangeRates.Multiplicity / (ISNULL(BankAcountExchangeRates.ExchangeRate, 1) * ISNULL(ExchangeRatesOfDocument.Multiplicity, 1))
		|			ELSE 1
		|		END AS NUMBER(15, 2)) AS DocumentAmount
		|FROM
		|	Document.SalesOrder AS DocumentHeader
		|		LEFT JOIN Document.SalesOrder.Inventory AS DocumentTable
		|		ON DocumentHeader.Ref = DocumentTable.Ref
		|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&Date, ) AS SettlementsExchangeRates
		|		ON DocumentHeader.Contract.SettlementsCurrency = SettlementsExchangeRates.Currency
		|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&Date, ) AS ExchangeRatesOfDocument
		|		ON DocumentHeader.DocumentCurrency = ExchangeRatesOfDocument.Currency
		|		LEFT JOIN (SELECT TOP 1
		|			CASE
		|				WHEN DocumentTable.BankAccount <> VALUE(Catalog.BankAccounts.EmptyRef)
		|					THEN DocumentTable.BankAccount
		|				WHEN DocumentTable.Company.BankAccountByDefault.CashCurrency = DocumentTable.Contract.SettlementsCurrency
		|					THEN DocumentTable.Company.BankAccountByDefault
		|				WHEN ISNULL(BankAccounts.Ref, VALUE(Catalog.BankAccounts.EmptyRef)) <> VALUE(Catalog.BankAccounts.EmptyRef)
		|					THEN BankAccounts.Ref
		|				ELSE DocumentTable.Company.BankAccountByDefault
		|			END AS BankAccount,
		|			CASE
		|				WHEN DocumentTable.BankAccount <> VALUE(Catalog.BankAccounts.EmptyRef)
		|					THEN DocumentTable.BankAccount.CashCurrency
		|				WHEN DocumentTable.Company.BankAccountByDefault.CashCurrency = DocumentTable.Contract.SettlementsCurrency
		|					THEN DocumentTable.Company.BankAccountByDefault.CashCurrency
		|				WHEN ISNULL(BankAccounts.Ref, VALUE(Catalog.BankAccounts.EmptyRef)) <> VALUE(Catalog.BankAccounts.EmptyRef)
		|					THEN BankAccounts.CashCurrency
		|				ELSE DocumentTable.Company.BankAccountByDefault.CashCurrency
		|			END AS CashCurrency,
		|			CASE
		|				WHEN DocumentTable.BankAccount <> VALUE(Catalog.BankAccounts.EmptyRef)
		|					THEN DocumentTable.BankAccount.Owner
		|				WHEN DocumentTable.Company.BankAccountByDefault.CashCurrency = DocumentTable.Contract.SettlementsCurrency
		|					THEN DocumentTable.Company.BankAccountByDefault.Owner
		|				WHEN ISNULL(BankAccounts.Ref, VALUE(Catalog.BankAccounts.EmptyRef)) <> VALUE(Catalog.BankAccounts.EmptyRef)
		|					THEN BankAccounts.Ref.Owner
		|				ELSE DocumentTable.Company.BankAccountByDefault.Owner
		|			END AS Owner
		|		FROM
		|			Document.SalesOrder AS DocumentTable
		|				LEFT JOIN Catalog.BankAccounts AS BankAccounts
		|				ON DocumentTable.Company = BankAccounts.Owner
		|					AND DocumentTable.DocumentCurrency = BankAccounts.CashCurrency
		|					AND (BankAccounts.DeletionMark = FALSE)
		|		WHERE
		|			DocumentTable.Ref = &Ref) AS NestedSelect
		|			LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&Date, ) AS BankAcountExchangeRates
		|			ON NestedSelect.CashCurrency = BankAcountExchangeRates.Currency
		|		ON DocumentHeader.Company = NestedSelect.Owner
		|WHERE
		|	DocumentHeader.Ref = &Ref
		|	AND ISNULL(DocumentTable.LineNumber, 1) = 1";
		
	ElsIf LineNumber = Undefined Then
		
		Query.SetParameter("Ref", FillingData);
		Query.SetParameter("Date", ?(ValueIsFilled(Date), Date, CurrentDate()));
		
		// Fill data of the document tabular sections.
		Query.Text =
		"SELECT
		|	VALUE(Enum.OperationTypesPaymentReceipt.FromCustomer) AS OperationKind,
		|	&Ref AS BasisDocument,
		|	DocumentHeader.Company AS Company,
		|	DocumentHeader.VATTaxation AS VATTaxation,
		|	BankAccountsNestedSelect.CashCurrency AS CashCurrency,
		|	BankAccountsNestedSelect.BankAccount AS BankAccount,
		|	DocumentHeader.Counterparty AS Counterparty,
		|	DocumentHeader.Contract AS Contract,
		|	DocumentHeader.DocumentCurrency AS DocumentCurrency,
		|	TRUE AS AdvanceFlag,
		|	&Ref AS Quote,
		|	NestedSelect.VATRate AS VATRate,
		|	SettlementsExchangeRates.ExchangeRate AS ExchangeRate,
		|	SettlementsExchangeRates.Multiplicity AS Multiplicity,
		|	SUM(CAST(NestedSelect.Total * CASE
		|				WHEN DocumentHeader.DocumentCurrency <> DocumentHeader.Contract.SettlementsCurrency
		|						AND SettlementsExchangeRates.ExchangeRate <> 0
		|						AND ExchangeRatesOfDocument.Multiplicity <> 0
		|					THEN ExchangeRatesOfDocument.ExchangeRate * SettlementsExchangeRates.Multiplicity / (ISNULL(SettlementsExchangeRates.ExchangeRate, 1) * ISNULL(ExchangeRatesOfDocument.Multiplicity, 1))
		|				ELSE 1
		|			END AS NUMBER(15, 2))) AS SettlementsAmount,
		|	SUM(CAST(NestedSelect.Total * CASE
		|				WHEN DocumentHeader.DocumentCurrency <> BankAccountsNestedSelect.CashCurrency
		|						AND ExchangeRatesOfDocument.Multiplicity <> 0
		|						AND BankAcountExchangeRates.ExchangeRate <> 0
		|					THEN ExchangeRatesOfDocument.ExchangeRate * BankAcountExchangeRates.Multiplicity / (ISNULL(BankAcountExchangeRates.ExchangeRate, 1) * ISNULL(ExchangeRatesOfDocument.Multiplicity, 1))
		|				ELSE 1
		|			END AS NUMBER(15, 2))) AS PaymentAmount,
		|	SUM(CAST(NestedSelect.VATAmount * CASE
		|				WHEN DocumentHeader.DocumentCurrency <> BankAccountsNestedSelect.CashCurrency
		|						AND ExchangeRatesOfDocument.Multiplicity <> 0
		|						AND BankAcountExchangeRates.ExchangeRate <> 0
		|					THEN ExchangeRatesOfDocument.ExchangeRate * BankAcountExchangeRates.Multiplicity / (ISNULL(BankAcountExchangeRates.ExchangeRate, 1) * ISNULL(ExchangeRatesOfDocument.Multiplicity, 1))
		|				ELSE 1
		|			END AS NUMBER(15, 2))) AS VATAmount,
		|	SUM(CAST(NestedSelect.Total * CASE
		|				WHEN DocumentHeader.DocumentCurrency <> BankAccountsNestedSelect.CashCurrency
		|						AND ExchangeRatesOfDocument.Multiplicity <> 0
		|						AND BankAcountExchangeRates.ExchangeRate <> 0
		|					THEN ExchangeRatesOfDocument.ExchangeRate * BankAcountExchangeRates.Multiplicity / (ISNULL(BankAcountExchangeRates.ExchangeRate, 1) * ISNULL(ExchangeRatesOfDocument.Multiplicity, 1))
		|				ELSE 1
		|			END AS NUMBER(15, 2))) AS DocumentAmount,
		|	CASE
		|		WHEN DocumentHeader.Counterparty.DoOperationsByOrders
		|			THEN &Ref
		|		ELSE VALUE(Document.SalesOrder.EmptyRef)
		|	END AS Order,
		|	UNDEFINED AS Document
		|FROM
		|	Document.SalesOrder AS DocumentHeader
		|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&Date, ) AS SettlementsExchangeRates
		|		ON DocumentHeader.Contract.SettlementsCurrency = SettlementsExchangeRates.Currency
		|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&Date, ) AS ExchangeRatesOfDocument
		|		ON DocumentHeader.DocumentCurrency = ExchangeRatesOfDocument.Currency
		|		LEFT JOIN (SELECT
		|			&Ref AS BasisDocument,
		|			DocumentTable.VATRate AS VATRate,
		|			DocumentTable.Total AS Total,
		|			DocumentTable.VATAmount AS VATAmount
		|		FROM
		|			Document.SalesOrder.Inventory AS DocumentTable
		|				LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&Date, ) AS SettlementsExchangeRates
		|				ON DocumentTable.Ref.Contract.SettlementsCurrency = SettlementsExchangeRates.Currency
		|				LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&Date, ) AS ExchangeRatesOfDocument
		|				ON DocumentTable.Ref.DocumentCurrency = ExchangeRatesOfDocument.Currency
		|		WHERE
		|			DocumentTable.Ref = &Ref
		|		
		|		UNION ALL
		|		
		|		SELECT
		|			&Ref,
		|			DocumentTable.VATRate,
		|			DocumentTable.Total,
		|			DocumentTable.VATAmount
		|		FROM
		|			Document.SalesOrder.Works AS DocumentTable
		|		WHERE
		|			DocumentTable.Ref = &Ref) AS NestedSelect
		|		ON DocumentHeader.Ref = NestedSelect.BasisDocument
		|		LEFT JOIN (SELECT TOP 1
		|			CASE
		|				WHEN DocumentTable.BankAccount <> VALUE(Catalog.BankAccounts.EmptyRef)
		|					THEN DocumentTable.BankAccount
		|				WHEN DocumentTable.Company.BankAccountByDefault.CashCurrency = DocumentTable.Contract.SettlementsCurrency
		|					THEN DocumentTable.Company.BankAccountByDefault
		|				WHEN ISNULL(BankAccounts.Ref, VALUE(Catalog.BankAccounts.EmptyRef)) <> VALUE(Catalog.BankAccounts.EmptyRef)
		|					THEN BankAccounts.Ref
		|				ELSE DocumentTable.Company.BankAccountByDefault
		|			END AS BankAccount,
		|			CASE
		|				WHEN DocumentTable.BankAccount <> VALUE(Catalog.BankAccounts.EmptyRef)
		|					THEN DocumentTable.BankAccount.CashCurrency
		|				WHEN DocumentTable.Company.BankAccountByDefault.CashCurrency = DocumentTable.Contract.SettlementsCurrency
		|					THEN DocumentTable.Company.BankAccountByDefault.CashCurrency
		|				WHEN ISNULL(BankAccounts.Ref, VALUE(Catalog.BankAccounts.EmptyRef)) <> VALUE(Catalog.BankAccounts.EmptyRef)
		|					THEN BankAccounts.CashCurrency
		|				ELSE DocumentTable.Company.BankAccountByDefault.CashCurrency
		|			END AS CashCurrency,
		|			CASE
		|				WHEN DocumentTable.BankAccount <> VALUE(Catalog.BankAccounts.EmptyRef)
		|					THEN DocumentTable.BankAccount.Owner
		|				WHEN DocumentTable.Company.BankAccountByDefault.CashCurrency = DocumentTable.Contract.SettlementsCurrency
		|					THEN DocumentTable.Company.BankAccountByDefault.Owner
		|				WHEN ISNULL(BankAccounts.Ref, VALUE(Catalog.BankAccounts.EmptyRef)) <> VALUE(Catalog.BankAccounts.EmptyRef)
		|					THEN BankAccounts.Ref.Owner
		|				ELSE DocumentTable.Company.BankAccountByDefault.Owner
		|			END AS Owner
		|		FROM
		|			Document.SalesOrder AS DocumentTable
		|				LEFT JOIN Catalog.BankAccounts AS BankAccounts
		|				ON DocumentTable.Company = BankAccounts.Owner
		|					AND DocumentTable.DocumentCurrency = BankAccounts.CashCurrency
		|					AND (BankAccounts.DeletionMark = FALSE)
		|		WHERE
		|			DocumentTable.Ref = &Ref) AS BankAccountsNestedSelect
		|			LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&Date, ) AS BankAcountExchangeRates
		|			ON BankAccountsNestedSelect.CashCurrency = BankAcountExchangeRates.Currency
		|		ON DocumentHeader.Company = BankAccountsNestedSelect.Owner
		|WHERE
		|	DocumentHeader.Ref = &Ref
		|
		|GROUP BY
		|	DocumentHeader.Company,
		|	DocumentHeader.VATTaxation,
		|	DocumentHeader.DocumentCurrency,
		|	DocumentHeader.Counterparty,
		|	DocumentHeader.Contract,
		|	NestedSelect.VATRate,
		|	SettlementsExchangeRates.ExchangeRate,
		|	SettlementsExchangeRates.Multiplicity,
		|	BankAccountsNestedSelect.CashCurrency,
		|	BankAccountsNestedSelect.BankAccount,
		|	CASE
		|		WHEN DocumentHeader.Counterparty.DoOperationsByOrders
		|			THEN &Ref
		|		ELSE VALUE(Document.SalesOrder.EmptyRef)
		|	END,
		|	CASE
		|		WHEN DocumentHeader.BankAccount <> VALUE(Catalog.BankAccounts.EmptyRef)
		|			THEN DocumentHeader.BankAccount
		|		WHEN DocumentHeader.Company.BankAccountByDefault.CashCurrency = DocumentHeader.Contract.SettlementsCurrency
		|			THEN DocumentHeader.Company.BankAccountByDefault
		|		ELSE BankAccountsNestedSelect.BankAccount
		|	END";
		
	Else
	
		Query.SetParameter("Ref", FillingData.Basis);
		Query.SetParameter("LineNumber", LineNumber);
		Query.SetParameter("Date", ?(ValueIsFilled(Date), Date, CurrentDate()));
		
		// Fill document header data.
		Query.Text =
		"SELECT
		|	VALUE(Enum.OperationTypesPaymentReceipt.FromCustomer) AS OperationKind,
		|	&Ref AS BasisDocument,
		|	DocumentTable.Ref.Company AS Company,
		|	DocumentTable.Ref.VATTaxation AS VATTaxation,
		|	NestedSelect.CashCurrency AS CashCurrency,
		|	NestedSelect.BankAccount AS BankAccount,
		|	DocumentTable.Ref.Counterparty AS Counterparty,
		|	DocumentTable.Ref.Contract AS Contract,
		|	DocumentTable.Ref.DocumentCurrency AS DocumentCurrency,
		|	TRUE AS AdvanceFlag,
		|	DocumentTable.Ref AS Quote,
		|	ISNULL(VATRatesDocumentsTable.VATRate, VATRates.VATRate) AS VATRate,
		|	SettlementsExchangeRates.ExchangeRate AS ExchangeRate,
		|	SettlementsExchangeRates.Multiplicity AS Multiplicity,
		|	CAST(DocumentTable.PaymentAmount * CASE
		|			WHEN DocumentTable.Ref.DocumentCurrency <> DocumentTable.Ref.Contract.SettlementsCurrency
		|					AND SettlementsExchangeRates.ExchangeRate <> 0
		|					AND ExchangeRatesOfDocument.Multiplicity <> 0
		|				THEN ExchangeRatesOfDocument.ExchangeRate * SettlementsExchangeRates.Multiplicity / (ISNULL(SettlementsExchangeRates.ExchangeRate, 1) * ISNULL(ExchangeRatesOfDocument.Multiplicity, 1))
		|			ELSE 1
		|		END AS NUMBER(15, 2)) AS SettlementsAmount,
		|	CAST(DocumentTable.PaymentAmount * CASE
		|			WHEN DocumentTable.Ref.DocumentCurrency <> NestedSelect.CashCurrency
		|					AND ExchangeRatesOfDocument.Multiplicity <> 0
		|					AND BankAcountExchangeRates.ExchangeRate <> 0
		|				THEN ExchangeRatesOfDocument.ExchangeRate * BankAcountExchangeRates.Multiplicity / (ISNULL(BankAcountExchangeRates.ExchangeRate, 1) * ISNULL(ExchangeRatesOfDocument.Multiplicity, 1))
		|			ELSE 1
		|		END AS NUMBER(15, 2)) AS PaymentAmount,
		|	CAST(DocumentTable.PaymentVATAmount * CASE
		|			WHEN DocumentTable.Ref.DocumentCurrency <> NestedSelect.CashCurrency
		|					AND ExchangeRatesOfDocument.Multiplicity <> 0
		|					AND BankAcountExchangeRates.ExchangeRate <> 0
		|				THEN ExchangeRatesOfDocument.ExchangeRate * BankAcountExchangeRates.Multiplicity / (ISNULL(BankAcountExchangeRates.ExchangeRate, 1) * ISNULL(ExchangeRatesOfDocument.Multiplicity, 1))
		|			ELSE 1
		|		END AS NUMBER(15, 2)) AS VATAmount,
		|	CAST(DocumentTable.PaymentAmount * CASE
		|			WHEN DocumentTable.Ref.DocumentCurrency <> NestedSelect.CashCurrency
		|					AND ExchangeRatesOfDocument.Multiplicity <> 0
		|					AND BankAcountExchangeRates.ExchangeRate <> 0
		|				THEN ExchangeRatesOfDocument.ExchangeRate * BankAcountExchangeRates.Multiplicity / (ISNULL(BankAcountExchangeRates.ExchangeRate, 1) * ISNULL(ExchangeRatesOfDocument.Multiplicity, 1))
		|			ELSE 1
		|		END AS NUMBER(15, 2)) AS DocumentAmount,
		|	CASE
		|		WHEN DocumentTable.Ref.Counterparty.DoOperationsByOrders
		|			THEN &Ref
		|		ELSE VALUE(Document.SalesOrder.EmptyRef)
		|	END AS Order,
		|	UNDEFINED AS Document
		|FROM
		|	Document.SalesOrder.PaymentCalendar AS DocumentTable
		|		LEFT JOIN (SELECT TOP 1
		|			VATRates.Ref AS VATRate
		|		FROM
		|			Catalog.VATRates AS VATRates
		|		WHERE
		|			VATRates.Rate = 18
		|			AND VATRates.DeletionMark = FALSE
		|			AND VATRates.Calculated = FALSE) AS VATRates
		|		ON (TRUE)
		|		LEFT JOIN (SELECT TOP 1
		|			VATRatesDocumentsTable.Ref AS Ref,
		|			VATRatesDocumentsTable.VATRate AS VATRate
		|		FROM
		|			(SELECT TOP 1
		|				DocumentTable.Ref AS Ref,
		|				DocumentTable.VATRate AS VATRate
		|			FROM
		|				Document.SalesOrder.Inventory AS DocumentTable
		|			WHERE
		|				DocumentTable.Ref = &Ref
			
		|			UNION ALL
			
		|			SELECT TOP 1
		|				DocumentTable.Ref,
		|				DocumentTable.VATRate
		|			FROM
		|				Document.SalesOrder.Works AS DocumentTable
		|			WHERE
		|				DocumentTable.Ref = &Ref) AS VATRatesDocumentsTable) AS VATRatesDocumentsTable
		|		ON DocumentTable.Ref = VATRatesDocumentsTable.Ref
		|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&Date, ) AS SettlementsExchangeRates
		|		ON DocumentTable.Ref.Contract.SettlementsCurrency = SettlementsExchangeRates.Currency
		|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&Date, ) AS ExchangeRatesOfDocument
		|		ON DocumentTable.Ref.DocumentCurrency = ExchangeRatesOfDocument.Currency
		|		LEFT JOIN (SELECT TOP 1
		|			CASE
		|				WHEN DocumentTable.BankAccount <> VALUE(Catalog.BankAccounts.EmptyRef)
		|					THEN DocumentTable.BankAccount
		|				WHEN DocumentTable.Company.BankAccountByDefault.CashCurrency = DocumentTable.Contract.SettlementsCurrency
		|					THEN DocumentTable.Company.BankAccountByDefault
		|				WHEN ISNULL(BankAccounts.Ref, VALUE(Catalog.BankAccounts.EmptyRef)) <> VALUE(Catalog.BankAccounts.EmptyRef)
		|					THEN BankAccounts.Ref
		|				ELSE DocumentTable.Company.BankAccountByDefault
		|			END AS BankAccount,
		|			CASE
		|				WHEN DocumentTable.BankAccount <> VALUE(Catalog.BankAccounts.EmptyRef)
		|					THEN DocumentTable.BankAccount.CashCurrency
		|				WHEN DocumentTable.Company.BankAccountByDefault.CashCurrency = DocumentTable.Contract.SettlementsCurrency
		|					THEN DocumentTable.Company.BankAccountByDefault.CashCurrency
		|				WHEN ISNULL(BankAccounts.Ref, VALUE(Catalog.BankAccounts.EmptyRef)) <> VALUE(Catalog.BankAccounts.EmptyRef)
		|					THEN BankAccounts.CashCurrency
		|				ELSE DocumentTable.Company.BankAccountByDefault.CashCurrency
		|			END AS CashCurrency,
		|			CASE
		|				WHEN DocumentTable.BankAccount <> VALUE(Catalog.BankAccounts.EmptyRef)
		|					THEN DocumentTable.BankAccount.Owner
		|				WHEN DocumentTable.Company.BankAccountByDefault.CashCurrency = DocumentTable.Contract.SettlementsCurrency
		|					THEN DocumentTable.Company.BankAccountByDefault.Owner
		|				WHEN ISNULL(BankAccounts.Ref, VALUE(Catalog.BankAccounts.EmptyRef)) <> VALUE(Catalog.BankAccounts.EmptyRef)
		|					THEN BankAccounts.Ref.Owner
		|				ELSE DocumentTable.Company.BankAccountByDefault.Owner
		|			END AS Owner
		|		FROM
		|			Document.SalesOrder AS DocumentTable
		|				LEFT JOIN Catalog.BankAccounts AS BankAccounts
		|				ON DocumentTable.Company = BankAccounts.Owner
		|					AND DocumentTable.DocumentCurrency = BankAccounts.CashCurrency
		|					AND (BankAccounts.DeletionMark = FALSE)
		|		WHERE
		|			DocumentTable.Ref = &Ref) AS NestedSelect
		|			LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&Date, ) AS BankAcountExchangeRates
		|			ON NestedSelect.CashCurrency = BankAcountExchangeRates.Currency
		|		ON DocumentTable.Ref.Company = NestedSelect.Owner
		|WHERE
		|	DocumentTable.Ref = &Ref
		|	AND DocumentTable.LineNumber = &LineNumber";
		
	EndIf;
	
	Selection = Query.Execute().Select();
	PaymentDetails.Clear();
	
	While Selection.Next() Do
		
		FillPropertyValues(ThisObject, Selection);
		If Not ValueIsFilled(CashCurrency) Then
			CashCurrency = Selection.DocumentCurrency;
		EndIf;
		NewRow = PaymentDetails.Add();
		FillPropertyValues(NewRow, Selection);
		If Not VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then
			FillVATRateByVATTaxation(NewRow);
		EndIf;
		
	EndDo;
	
	DocumentAmount = PaymentDetails.Total("PaymentAmount");
	
	FillCounterpartyBankAcc();
	
EndProcedure

// Procedure of filling the document on the basis.
//
// Parameters:
// FillingData - Structure - Data on filling the document.
//	
Procedure FillByWorkOrder(FillingData, LineNumber = Undefined, Amount = Undefined)
	
	Query = New Query();
	
	If Amount <> Undefined Then
		
		Query.SetParameter("Ref", FillingData);
		Query.SetParameter("Date", ?(ValueIsFilled(Date), Date, CurrentSessionDate()));
		Query.SetParameter("Amount", Amount);
		
		// Fill data of the document tabular sections.
		Query.Text =
		"SELECT
		|	WorkOrder.Ref AS Ref,
		|	WorkOrder.Company AS Company,
		|	WorkOrder.VATTaxation AS VATTaxation,
		|	WorkOrder.BankAccount AS BankAccount,
		|	WorkOrder.Counterparty AS Counterparty,
		|	WorkOrder.Contract AS Contract,
		|	WorkOrder.DocumentCurrency AS DocumentCurrency,
		|	WorkOrder.OrderState AS OrderState
		|INTO WorkOrderTable
		|FROM
		|	Document.WorkOrder AS WorkOrder
		|WHERE
		|	WorkOrder.Ref = &Ref
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	WorkOrder.Ref AS Ref,
		|	WorkOrder.Company AS Company,
		|	WorkOrder.VATTaxation AS VATTaxation,
		|	WorkOrder.BankAccount AS BankAccount,
		|	WorkOrder.DocumentCurrency AS DocumentCurrency,
		|	WorkOrder.Counterparty AS Counterparty,
		|	WorkOrder.Contract AS Contract,
		|	ISNULL(WorkOrderStatuses.OrderStatus, VALUE(Enum.OrderStatuses.EmptyRef)) AS OrderStatus,
		|	Counterparties.DoOperationsByDocuments AS DoOperationsByDocuments,
		|	CounterpartyContracts.SettlementsCurrency AS SettlementsCurrency,
		|	Companies.BankAccountByDefault AS BankAccountByDefault
		|INTO WorkOrderWithStatus
		|FROM
		|	WorkOrderTable AS WorkOrder
		|		INNER JOIN Catalog.Counterparties AS Counterparties
		|		ON WorkOrder.Counterparty = Counterparties.Ref
		|		INNER JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
		|		ON WorkOrder.Contract = CounterpartyContracts.Ref
		|		INNER JOIN Catalog.Companies AS Companies
		|		ON WorkOrder.Company = Companies.Ref
		|		LEFT JOIN Catalog.WorkOrderStatuses AS WorkOrderStatuses
		|		ON WorkOrder.OrderState = WorkOrderStatuses.Ref
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT TOP 1
		|	CASE
		|		WHEN WorkOrder.BankAccount <> VALUE(Catalog.BankAccounts.EmptyRef)
		|			THEN WorkOrder.BankAccount
		|		WHEN CompanyBankAccounts.CashCurrency = WorkOrder.SettlementsCurrency
		|			THEN CompanyBankAccounts.Ref
		|		WHEN ISNULL(BankAccounts.Ref, VALUE(Catalog.BankAccounts.EmptyRef)) <> VALUE(Catalog.BankAccounts.EmptyRef)
		|			THEN BankAccounts.Ref
		|		ELSE CompanyBankAccounts.Ref
		|	END AS BankAccount,
		|	CASE
		|		WHEN WorkOrder.BankAccount <> VALUE(Catalog.BankAccounts.EmptyRef)
		|			THEN WorkOrderBankAccount.CashCurrency
		|		WHEN CompanyBankAccounts.CashCurrency = WorkOrder.SettlementsCurrency
		|			THEN CompanyBankAccounts.CashCurrency
		|		WHEN ISNULL(BankAccounts.Ref, VALUE(Catalog.BankAccounts.EmptyRef)) <> VALUE(Catalog.BankAccounts.EmptyRef)
		|			THEN BankAccounts.CashCurrency
		|		ELSE CompanyBankAccounts.CashCurrency
		|	END AS CashCurrency,
		|	CASE
		|		WHEN WorkOrder.BankAccount <> VALUE(Catalog.BankAccounts.EmptyRef)
		|			THEN WorkOrderBankAccount.Owner
		|		WHEN CompanyBankAccounts.CashCurrency = WorkOrder.SettlementsCurrency
		|			THEN CompanyBankAccounts.Owner
		|		WHEN ISNULL(BankAccounts.Ref, VALUE(Catalog.BankAccounts.EmptyRef)) <> VALUE(Catalog.BankAccounts.EmptyRef)
		|			THEN BankAccounts.Owner
		|		ELSE CompanyBankAccounts.Owner
		|	END AS Owner
		|INTO WorkOrderBankAccount
		|FROM
		|	WorkOrderWithStatus AS WorkOrder
		|		LEFT JOIN Catalog.BankAccounts AS BankAccounts
		|		ON WorkOrder.Company = BankAccounts.Owner
		|			AND WorkOrder.DocumentCurrency = BankAccounts.CashCurrency
		|			AND (NOT BankAccounts.DeletionMark)
		|		LEFT JOIN Catalog.BankAccounts AS CompanyBankAccounts
		|		ON WorkOrder.BankAccountByDefault = CompanyBankAccounts.Ref
		|		LEFT JOIN Catalog.BankAccounts AS WorkOrderBankAccount
		|		ON WorkOrder.BankAccount = WorkOrderBankAccount.Ref
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	VALUE(Enum.OperationTypesPaymentReceipt.FromCustomer) AS OperationKind,
		|	WorkOrderWithStatus.Ref AS BasisDocument,
		|	WorkOrderWithStatus.Company AS Company,
		|	WorkOrderWithStatus.VATTaxation AS VATTaxation,
		|	WorkOrderBankAccount.CashCurrency AS CashCurrency,
		|	WorkOrderBankAccount.BankAccount AS BankAccount,
		|	WorkOrderWithStatus.Counterparty AS Counterparty,
		|	WorkOrderWithStatus.Contract AS Contract,
		|	WorkOrderWithStatus.DocumentCurrency AS DocumentCurrency,
		|	VALUE(Document.SalesOrder.EmptyRef) AS Order,
		|	WorkOrderInventory.VATRate AS VATRate,
		|	SettlementsExchangeRates.ExchangeRate AS ExchangeRate,
		|	SettlementsExchangeRates.Multiplicity AS Multiplicity,
		|	CAST(&Amount * CASE
		|			WHEN WorkOrderWithStatus.DocumentCurrency <> WorkOrderWithStatus.SettlementsCurrency
		|					AND SettlementsExchangeRates.ExchangeRate <> 0
		|					AND ExchangeRatesOfDocument.Multiplicity <> 0
		|				THEN ExchangeRatesOfDocument.ExchangeRate * SettlementsExchangeRates.Multiplicity / (ISNULL(SettlementsExchangeRates.ExchangeRate, 1) * ISNULL(ExchangeRatesOfDocument.Multiplicity, 1))
		|			ELSE 1
		|		END AS NUMBER(15, 2)) AS SettlementsAmount,
		|	CAST(&Amount * CASE
		|			WHEN WorkOrderWithStatus.DocumentCurrency <> WorkOrderBankAccount.CashCurrency
		|					AND ExchangeRatesOfDocument.Multiplicity <> 0
		|					AND BankAcountExchangeRates.ExchangeRate <> 0
		|				THEN ExchangeRatesOfDocument.ExchangeRate * BankAcountExchangeRates.Multiplicity / (ISNULL(BankAcountExchangeRates.ExchangeRate, 1) * ISNULL(ExchangeRatesOfDocument.Multiplicity, 1))
		|			ELSE 1
		|		END AS NUMBER(15, 2)) AS PaymentAmount,
		|	CAST(&Amount * (1 - 1 / ((ISNULL(WorkOrderInventory.VATRate.Rate, 0) + 100) / 100)) * CASE
		|			WHEN WorkOrderWithStatus.DocumentCurrency <> WorkOrderBankAccount.CashCurrency
		|					AND ExchangeRatesOfDocument.Multiplicity <> 0
		|					AND BankAcountExchangeRates.ExchangeRate <> 0
		|				THEN ExchangeRatesOfDocument.ExchangeRate * BankAcountExchangeRates.Multiplicity / (ISNULL(BankAcountExchangeRates.ExchangeRate, 1) * ISNULL(ExchangeRatesOfDocument.Multiplicity, 1))
		|			ELSE 1
		|		END AS NUMBER(15, 2)) AS VATAmount,
		|	CAST(&Amount * CASE
		|			WHEN WorkOrderWithStatus.DocumentCurrency <> WorkOrderBankAccount.CashCurrency
		|					AND ExchangeRatesOfDocument.Multiplicity <> 0
		|					AND BankAcountExchangeRates.ExchangeRate <> 0
		|				THEN ExchangeRatesOfDocument.ExchangeRate * BankAcountExchangeRates.Multiplicity / (ISNULL(BankAcountExchangeRates.ExchangeRate, 1) * ISNULL(ExchangeRatesOfDocument.Multiplicity, 1))
		|			ELSE 1
		|		END AS NUMBER(15, 2)) AS DocumentAmount,
		|	CASE
		|		WHEN WorkOrderWithStatus.OrderStatus = VALUE(Enum.OrderStatuses.Completed)
		|			THEN FALSE
		|		ELSE TRUE
		|	END AS AdvanceFlag,
		|	CASE
		|		WHEN WorkOrderWithStatus.OrderStatus = VALUE(Enum.OrderStatuses.Completed)
		|				AND WorkOrderWithStatus.DoOperationsByDocuments
		|			THEN WorkOrderWithStatus.Ref
		|		ELSE UNDEFINED
		|	END AS Document
		|FROM
		|	WorkOrderWithStatus AS WorkOrderWithStatus
		|		LEFT JOIN Document.WorkOrder.Inventory AS WorkOrderInventory
		|		ON WorkOrderWithStatus.Ref = WorkOrderInventory.Ref
		|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&Date, ) AS SettlementsExchangeRates
		|		ON WorkOrderWithStatus.SettlementsCurrency = SettlementsExchangeRates.Currency
		|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&Date, ) AS ExchangeRatesOfDocument
		|		ON WorkOrderWithStatus.DocumentCurrency = ExchangeRatesOfDocument.Currency
		|		LEFT JOIN WorkOrderBankAccount AS WorkOrderBankAccount
		|		ON WorkOrderWithStatus.Company = WorkOrderBankAccount.Owner
		|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&Date, ) AS BankAcountExchangeRates
		|		ON (WorkOrderBankAccount.CashCurrency = BankAcountExchangeRates.Currency)
		|WHERE
		|	ISNULL(WorkOrderInventory.LineNumber, 1) = 1";
		
	ElsIf LineNumber = Undefined Then
		
		Query.SetParameter("Ref", FillingData);
		Query.SetParameter("Date", ?(ValueIsFilled(Date), Date, CurrentSessionDate()));
		
		// Fill data of the document tabular sections.
		Query.Text =
		"SELECT
		|	WorkOrder.Ref AS Ref,
		|	WorkOrder.Company AS Company,
		|	WorkOrder.VATTaxation AS VATTaxation,
		|	WorkOrder.BankAccount AS BankAccount,
		|	WorkOrder.Counterparty AS Counterparty,
		|	WorkOrder.Contract AS Contract,
		|	WorkOrder.DocumentCurrency AS DocumentCurrency,
		|	WorkOrder.OrderState AS OrderState
		|INTO WorkOrderTable
		|FROM
		|	Document.WorkOrder AS WorkOrder
		|WHERE
		|	WorkOrder.Ref = &Ref
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	WorkOrder.Ref AS Ref,
		|	WorkOrder.Company AS Company,
		|	WorkOrder.VATTaxation AS VATTaxation,
		|	WorkOrder.BankAccount AS BankAccount,
		|	WorkOrder.DocumentCurrency AS DocumentCurrency,
		|	WorkOrder.Counterparty AS Counterparty,
		|	WorkOrder.Contract AS Contract,
		|	ISNULL(WorkOrderStatuses.OrderStatus, VALUE(Enum.OrderStatuses.EmptyRef)) AS OrderStatus,
		|	Counterparties.DoOperationsByDocuments AS DoOperationsByDocuments,
		|	CounterpartyContracts.SettlementsCurrency AS SettlementsCurrency,
		|	Companies.BankAccountByDefault AS BankAccountByDefault
		|INTO WorkOrderWithStatus
		|FROM
		|	WorkOrderTable AS WorkOrder
		|		INNER JOIN Catalog.Counterparties AS Counterparties
		|		ON WorkOrder.Counterparty = Counterparties.Ref
		|		INNER JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
		|		ON WorkOrder.Contract = CounterpartyContracts.Ref
		|		INNER JOIN Catalog.Companies AS Companies
		|		ON WorkOrder.Company = Companies.Ref
		|		LEFT JOIN Catalog.WorkOrderStatuses AS WorkOrderStatuses
		|		ON WorkOrder.OrderState = WorkOrderStatuses.Ref
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT TOP 1
		|	CASE
		|		WHEN WorkOrder.BankAccount <> VALUE(Catalog.BankAccounts.EmptyRef)
		|			THEN WorkOrder.BankAccount
		|		WHEN CompanyBankAccounts.CashCurrency = WorkOrder.SettlementsCurrency
		|			THEN CompanyBankAccounts.Ref
		|		WHEN ISNULL(BankAccounts.Ref, VALUE(Catalog.BankAccounts.EmptyRef)) <> VALUE(Catalog.BankAccounts.EmptyRef)
		|			THEN BankAccounts.Ref
		|		ELSE CompanyBankAccounts.Ref
		|	END AS BankAccount,
		|	CASE
		|		WHEN WorkOrder.BankAccount <> VALUE(Catalog.BankAccounts.EmptyRef)
		|			THEN WorkOrderBankAccount.CashCurrency
		|		WHEN CompanyBankAccounts.CashCurrency = WorkOrder.SettlementsCurrency
		|			THEN CompanyBankAccounts.CashCurrency
		|		WHEN ISNULL(BankAccounts.Ref, VALUE(Catalog.BankAccounts.EmptyRef)) <> VALUE(Catalog.BankAccounts.EmptyRef)
		|			THEN BankAccounts.CashCurrency
		|		ELSE CompanyBankAccounts.CashCurrency
		|	END AS CashCurrency,
		|	CASE
		|		WHEN WorkOrder.BankAccount <> VALUE(Catalog.BankAccounts.EmptyRef)
		|			THEN WorkOrderBankAccount.Owner
		|		WHEN CompanyBankAccounts.CashCurrency = WorkOrder.SettlementsCurrency
		|			THEN CompanyBankAccounts.Owner
		|		WHEN ISNULL(BankAccounts.Ref, VALUE(Catalog.BankAccounts.EmptyRef)) <> VALUE(Catalog.BankAccounts.EmptyRef)
		|			THEN BankAccounts.Owner
		|		ELSE CompanyBankAccounts.Owner
		|	END AS Owner
		|INTO WorkOrderBankAccount
		|FROM
		|	WorkOrderWithStatus AS WorkOrder
		|		LEFT JOIN Catalog.BankAccounts AS BankAccounts
		|		ON WorkOrder.Company = BankAccounts.Owner
		|			AND WorkOrder.DocumentCurrency = BankAccounts.CashCurrency
		|			AND (NOT BankAccounts.DeletionMark)
		|		LEFT JOIN Catalog.BankAccounts AS CompanyBankAccounts
		|		ON WorkOrder.BankAccountByDefault = CompanyBankAccounts.Ref
		|		LEFT JOIN Catalog.BankAccounts AS WorkOrderBankAccount
		|		ON WorkOrder.BankAccount = WorkOrderBankAccount.Ref
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	WorkOrderInventory.Ref AS Ref,
		|	WorkOrderInventory.VATRate AS VATRate,
		|	WorkOrderInventory.Total AS Total,
		|	WorkOrderInventory.VATAmount AS VATAmount
		|INTO WorkOrderInventoryWorks
		|FROM
		|	Document.WorkOrder.Inventory AS WorkOrderInventory
		|		INNER JOIN WorkOrderTable AS WorkOrderTable
		|		ON (WorkOrderTable.Ref = WorkOrderInventory.Ref)
		|
		|UNION ALL
		|
		|SELECT
		|	WorkOrderWorks.Ref,
		|	WorkOrderWorks.VATRate,
		|	WorkOrderWorks.Total,
		|	WorkOrderWorks.VATAmount
		|FROM
		|	Document.WorkOrder.Works AS WorkOrderWorks
		|		INNER JOIN WorkOrderTable AS WorkOrderTable
		|		ON (WorkOrderTable.Ref = WorkOrderWorks.Ref)
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	VALUE(Enum.OperationTypesPaymentReceipt.FromCustomer) AS OperationKind,
		|	WorkOrderWithStatus.Ref AS BasisDocument,
		|	WorkOrderWithStatus.Company AS Company,
		|	WorkOrderWithStatus.VATTaxation AS VATTaxation,
		|	WorkOrderBankAccount.CashCurrency AS CashCurrency,
		|	WorkOrderBankAccount.BankAccount AS BankAccount,
		|	WorkOrderWithStatus.Counterparty AS Counterparty,
		|	WorkOrderWithStatus.Contract AS Contract,
		|	WorkOrderWithStatus.DocumentCurrency AS DocumentCurrency,
		|	WorkOrderInventoryWorks.VATRate AS VATRate,
		|	SettlementsExchangeRates.ExchangeRate AS ExchangeRate,
		|	SettlementsExchangeRates.Multiplicity AS Multiplicity,
		|	SUM(CAST(WorkOrderInventoryWorks.Total * CASE
		|				WHEN WorkOrderWithStatus.DocumentCurrency <> WorkOrderWithStatus.SettlementsCurrency
		|						AND SettlementsExchangeRates.ExchangeRate <> 0
		|						AND ExchangeRatesOfDocument.Multiplicity <> 0
		|					THEN ExchangeRatesOfDocument.ExchangeRate * SettlementsExchangeRates.Multiplicity / (ISNULL(SettlementsExchangeRates.ExchangeRate, 1) * ISNULL(ExchangeRatesOfDocument.Multiplicity, 1))
		|				ELSE 1
		|			END AS NUMBER(15, 2))) AS SettlementsAmount,
		|	SUM(CAST(WorkOrderInventoryWorks.Total * CASE
		|				WHEN WorkOrderWithStatus.DocumentCurrency <> WorkOrderBankAccount.CashCurrency
		|						AND ExchangeRatesOfDocument.Multiplicity <> 0
		|						AND BankAcountExchangeRates.ExchangeRate <> 0
		|					THEN ExchangeRatesOfDocument.ExchangeRate * BankAcountExchangeRates.Multiplicity / (ISNULL(BankAcountExchangeRates.ExchangeRate, 1) * ISNULL(ExchangeRatesOfDocument.Multiplicity, 1))
		|				ELSE 1
		|			END AS NUMBER(15, 2))) AS PaymentAmount,
		|	SUM(CAST(WorkOrderInventoryWorks.VATAmount * CASE
		|				WHEN WorkOrderWithStatus.DocumentCurrency <> WorkOrderBankAccount.CashCurrency
		|						AND ExchangeRatesOfDocument.Multiplicity <> 0
		|						AND BankAcountExchangeRates.ExchangeRate <> 0
		|					THEN ExchangeRatesOfDocument.ExchangeRate * BankAcountExchangeRates.Multiplicity / (ISNULL(BankAcountExchangeRates.ExchangeRate, 1) * ISNULL(ExchangeRatesOfDocument.Multiplicity, 1))
		|				ELSE 1
		|			END AS NUMBER(15, 2))) AS VATAmount,
		|	SUM(CAST(WorkOrderInventoryWorks.Total * CASE
		|				WHEN WorkOrderWithStatus.DocumentCurrency <> WorkOrderBankAccount.CashCurrency
		|						AND ExchangeRatesOfDocument.Multiplicity <> 0
		|						AND BankAcountExchangeRates.ExchangeRate <> 0
		|					THEN ExchangeRatesOfDocument.ExchangeRate * BankAcountExchangeRates.Multiplicity / (ISNULL(BankAcountExchangeRates.ExchangeRate, 1) * ISNULL(ExchangeRatesOfDocument.Multiplicity, 1))
		|				ELSE 1
		|			END AS NUMBER(15, 2))) AS DocumentAmount,
		|	VALUE(Document.SalesOrder.EmptyRef) AS Order,
		|	CASE
		|		WHEN WorkOrderWithStatus.OrderStatus = VALUE(Enum.OrderStatuses.Completed)
		|			THEN FALSE
		|		ELSE TRUE
		|	END AS AdvanceFlag,
		|	CASE
		|		WHEN WorkOrderWithStatus.OrderStatus = VALUE(Enum.OrderStatuses.Completed)
		|				AND WorkOrderWithStatus.DoOperationsByDocuments
		|			THEN WorkOrderWithStatus.Ref
		|		ELSE UNDEFINED
		|	END AS Document
		|FROM
		|	WorkOrderWithStatus AS WorkOrderWithStatus
		|		LEFT JOIN WorkOrderInventoryWorks AS WorkOrderInventoryWorks
		|		ON WorkOrderWithStatus.Ref = WorkOrderInventoryWorks.Ref
		|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&Date, ) AS SettlementsExchangeRates
		|		ON WorkOrderWithStatus.SettlementsCurrency = SettlementsExchangeRates.Currency
		|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&Date, ) AS ExchangeRatesOfDocument
		|		ON WorkOrderWithStatus.DocumentCurrency = ExchangeRatesOfDocument.Currency
		|		LEFT JOIN WorkOrderBankAccount AS WorkOrderBankAccount
		|		ON WorkOrderWithStatus.Company = WorkOrderBankAccount.Owner
		|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&Date, ) AS BankAcountExchangeRates
		|		ON (WorkOrderBankAccount.CashCurrency = BankAcountExchangeRates.Currency)
		|
		|GROUP BY
		|	WorkOrderWithStatus.Ref,
		|	WorkOrderWithStatus.Company,
		|	WorkOrderWithStatus.VATTaxation,
		|	WorkOrderWithStatus.DocumentCurrency,
		|	WorkOrderWithStatus.Counterparty,
		|	WorkOrderWithStatus.Contract,
		|	WorkOrderInventoryWorks.VATRate,
		|	SettlementsExchangeRates.ExchangeRate,
		|	SettlementsExchangeRates.Multiplicity,
		|	WorkOrderBankAccount.CashCurrency,
		|	WorkOrderBankAccount.BankAccount,
		|	CASE
		|		WHEN WorkOrderWithStatus.OrderStatus = VALUE(Enum.OrderStatuses.Completed)
		|			THEN FALSE
		|		ELSE TRUE
		|	END,
		|	CASE
		|		WHEN WorkOrderWithStatus.OrderStatus = VALUE(Enum.OrderStatuses.Completed)
		|				AND WorkOrderWithStatus.DoOperationsByDocuments
		|			THEN WorkOrderWithStatus.Ref
		|		ELSE UNDEFINED
		|	END";
		
	Else
		
		DefaultVATRate = InformationRegisters.AccountingPolicy.GetDefaultVATRate(Date, Company);
		
		Query.SetParameter("Ref", FillingData.Basis);
		Query.SetParameter("LineNumber", LineNumber);
		Query.SetParameter("Date", ?(ValueIsFilled(Date), Date, CurrentSessionDate()));
		Query.SetParameter("VATRate", DefaultVATRate);
		
		// Fill document header data.
		Query.Text =
		"SELECT
		|	WorkOrder.Ref AS Ref,
		|	WorkOrder.Company AS Company,
		|	WorkOrder.VATTaxation AS VATTaxation,
		|	WorkOrder.BankAccount AS BankAccount,
		|	WorkOrder.Counterparty AS Counterparty,
		|	WorkOrder.Contract AS Contract,
		|	WorkOrder.DocumentCurrency AS DocumentCurrency,
		|	WorkOrder.OrderState AS OrderState
		|INTO WorkOrderTable
		|FROM
		|	Document.WorkOrder AS WorkOrder
		|WHERE
		|	WorkOrder.Ref = &Ref
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	WorkOrder.Ref AS Ref,
		|	WorkOrder.Company AS Company,
		|	WorkOrder.VATTaxation AS VATTaxation,
		|	WorkOrder.BankAccount AS BankAccount,
		|	WorkOrder.DocumentCurrency AS DocumentCurrency,
		|	WorkOrder.Counterparty AS Counterparty,
		|	WorkOrder.Contract AS Contract,
		|	ISNULL(WorkOrderStatuses.OrderStatus, VALUE(Enum.OrderStatuses.EmptyRef)) AS OrderStatus,
		|	Counterparties.DoOperationsByDocuments AS DoOperationsByDocuments,
		|	CounterpartyContracts.SettlementsCurrency AS SettlementsCurrency,
		|	Companies.BankAccountByDefault AS BankAccountByDefault
		|INTO WorkOrderWithStatus
		|FROM
		|	WorkOrderTable AS WorkOrder
		|		INNER JOIN Catalog.Counterparties AS Counterparties
		|		ON WorkOrder.Counterparty = Counterparties.Ref
		|		INNER JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
		|		ON WorkOrder.Contract = CounterpartyContracts.Ref
		|		INNER JOIN Catalog.Companies AS Companies
		|		ON WorkOrder.Company = Companies.Ref
		|		LEFT JOIN Catalog.WorkOrderStatuses AS WorkOrderStatuses
		|		ON WorkOrder.OrderState = WorkOrderStatuses.Ref
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	WorkOrderInventory.Ref AS Ref,
		|	WorkOrderInventory.VATRate AS VATRate
		|INTO WorkOrderVATRate
		|FROM
		|	Document.WorkOrder.Inventory AS WorkOrderInventory
		|		INNER JOIN WorkOrderTable AS WorkOrderTable
		|		ON WorkOrderInventory.Ref = WorkOrderTable.Ref
		|
		|UNION ALL
		|
		|SELECT
		|	WorkOrderWorks.Ref,
		|	WorkOrderWorks.VATRate
		|FROM
		|	Document.WorkOrder.Works AS WorkOrderWorks
		|		INNER JOIN WorkOrderTable AS WorkOrderTable
		|		ON WorkOrderWorks.Ref = WorkOrderTable.Ref
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT TOP 1
		|	WorkOrderVATRate.Ref AS Ref,
		|	WorkOrderVATRate.VATRate AS VATRate
		|INTO WorkOrderFirstVATRate
		|FROM
		|	WorkOrderVATRate AS WorkOrderVATRate
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	WorkOrderWithStatus.Ref AS Ref,
		|	WorkOrderWithStatus.Company AS Company,
		|	WorkOrderWithStatus.VATTaxation AS VATTaxation,
		|	WorkOrderWithStatus.DocumentCurrency AS DocumentCurrency,
		|	WorkOrderWithStatus.BankAccount AS BankAccount,
		|	WorkOrderWithStatus.Counterparty AS Counterparty,
		|	WorkOrderWithStatus.Contract AS Contract,
		|	WorkOrderWithStatus.DoOperationsByDocuments AS DoOperationsByDocuments,
		|	WorkOrderWithStatus.SettlementsCurrency AS SettlementsCurrency,
		|	WorkOrderWithStatus.OrderStatus AS OrderStatus,
		|	ISNULL(WorkOrderFirstVATRate.VATRate, &VATRate) AS VATRate,
		|	WorkOrderWithStatus.BankAccountByDefault AS BankAccountByDefault
		|INTO WorkOrderTableWithVAT
		|FROM
		|	WorkOrderWithStatus AS WorkOrderWithStatus
		|		LEFT JOIN WorkOrderFirstVATRate AS WorkOrderFirstVATRate
		|		ON WorkOrderWithStatus.Ref = WorkOrderFirstVATRate.Ref
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT TOP 1
		|	CASE
		|		WHEN WorkOrder.BankAccount <> VALUE(Catalog.BankAccounts.EmptyRef)
		|			THEN WorkOrder.BankAccount
		|		WHEN CompanyBankAccounts.CashCurrency = WorkOrder.SettlementsCurrency
		|			THEN CompanyBankAccounts.Ref
		|		WHEN ISNULL(BankAccounts.Ref, VALUE(Catalog.BankAccounts.EmptyRef)) <> VALUE(Catalog.BankAccounts.EmptyRef)
		|			THEN BankAccounts.Ref
		|		ELSE CompanyBankAccounts.Ref
		|	END AS BankAccount,
		|	CASE
		|		WHEN WorkOrder.BankAccount <> VALUE(Catalog.BankAccounts.EmptyRef)
		|			THEN WorkOrderBankAccount.CashCurrency
		|		WHEN CompanyBankAccounts.CashCurrency = WorkOrder.SettlementsCurrency
		|			THEN CompanyBankAccounts.CashCurrency
		|		WHEN ISNULL(BankAccounts.Ref, VALUE(Catalog.BankAccounts.EmptyRef)) <> VALUE(Catalog.BankAccounts.EmptyRef)
		|			THEN BankAccounts.CashCurrency
		|		ELSE CompanyBankAccounts.CashCurrency
		|	END AS CashCurrency,
		|	CASE
		|		WHEN WorkOrder.BankAccount <> VALUE(Catalog.BankAccounts.EmptyRef)
		|			THEN WorkOrderBankAccount.Owner
		|		WHEN CompanyBankAccounts.CashCurrency = WorkOrder.SettlementsCurrency
		|			THEN CompanyBankAccounts.Owner
		|		WHEN ISNULL(BankAccounts.Ref, VALUE(Catalog.BankAccounts.EmptyRef)) <> VALUE(Catalog.BankAccounts.EmptyRef)
		|			THEN BankAccounts.Owner
		|		ELSE CompanyBankAccounts.Owner
		|	END AS Owner
		|INTO WorkOrderBankAccount
		|FROM
		|	WorkOrderWithStatus AS WorkOrder
		|		LEFT JOIN Catalog.BankAccounts AS BankAccounts
		|		ON WorkOrder.Company = BankAccounts.Owner
		|			AND WorkOrder.DocumentCurrency = BankAccounts.CashCurrency
		|			AND (NOT BankAccounts.DeletionMark)
		|		LEFT JOIN Catalog.BankAccounts AS CompanyBankAccounts
		|		ON WorkOrder.BankAccountByDefault = CompanyBankAccounts.Ref
		|		LEFT JOIN Catalog.BankAccounts AS WorkOrderBankAccount
		|		ON WorkOrder.BankAccount = WorkOrderBankAccount.Ref
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	VALUE(Enum.OperationTypesPaymentReceipt.FromCustomer) AS OperationKind,
		|	WorkOrderTableWithVAT.Ref AS BasisDocument,
		|	WorkOrderTableWithVAT.Company AS Company,
		|	WorkOrderTableWithVAT.VATTaxation AS VATTaxation,
		|	WorkOrderBankAccount.CashCurrency AS CashCurrency,
		|	WorkOrderBankAccount.BankAccount AS BankAccount,
		|	WorkOrderTableWithVAT.Counterparty AS Counterparty,
		|	WorkOrderTableWithVAT.Contract AS Contract,
		|	WorkOrderTableWithVAT.DocumentCurrency AS DocumentCurrency,
		|	WorkOrderTableWithVAT.VATRate AS VATRate,
		|	SettlementsExchangeRates.ExchangeRate AS ExchangeRate,
		|	SettlementsExchangeRates.Multiplicity AS Multiplicity,
		|	CAST(WorkOrderPaymentCalendar.PaymentAmount * CASE
		|			WHEN WorkOrderTableWithVAT.DocumentCurrency <> WorkOrderTableWithVAT.SettlementsCurrency
		|					AND SettlementsExchangeRates.ExchangeRate <> 0
		|					AND ExchangeRatesOfDocument.Multiplicity <> 0
		|				THEN ExchangeRatesOfDocument.ExchangeRate * SettlementsExchangeRates.Multiplicity / (ISNULL(SettlementsExchangeRates.ExchangeRate, 1) * ISNULL(ExchangeRatesOfDocument.Multiplicity, 1))
		|			ELSE 1
		|		END AS NUMBER(15, 2)) AS SettlementsAmount,
		|	CAST(WorkOrderPaymentCalendar.PaymentAmount * CASE
		|			WHEN WorkOrderTableWithVAT.DocumentCurrency <> WorkOrderBankAccount.CashCurrency
		|					AND ExchangeRatesOfDocument.Multiplicity <> 0
		|					AND BankAcountExchangeRates.ExchangeRate <> 0
		|				THEN ExchangeRatesOfDocument.ExchangeRate * BankAcountExchangeRates.Multiplicity / (ISNULL(BankAcountExchangeRates.ExchangeRate, 1) * ISNULL(ExchangeRatesOfDocument.Multiplicity, 1))
		|			ELSE 1
		|		END AS NUMBER(15, 2)) AS PaymentAmount,
		|	CAST(WorkOrderPaymentCalendar.PaymentVATAmount * CASE
		|			WHEN WorkOrderTableWithVAT.DocumentCurrency <> WorkOrderBankAccount.CashCurrency
		|					AND ExchangeRatesOfDocument.Multiplicity <> 0
		|					AND BankAcountExchangeRates.ExchangeRate <> 0
		|				THEN ExchangeRatesOfDocument.ExchangeRate * BankAcountExchangeRates.Multiplicity / (ISNULL(BankAcountExchangeRates.ExchangeRate, 1) * ISNULL(ExchangeRatesOfDocument.Multiplicity, 1))
		|			ELSE 1
		|		END AS NUMBER(15, 2)) AS VATAmount,
		|	CAST(WorkOrderPaymentCalendar.PaymentAmount * CASE
		|			WHEN WorkOrderTableWithVAT.DocumentCurrency <> WorkOrderBankAccount.CashCurrency
		|					AND ExchangeRatesOfDocument.Multiplicity <> 0
		|					AND BankAcountExchangeRates.ExchangeRate <> 0
		|				THEN ExchangeRatesOfDocument.ExchangeRate * BankAcountExchangeRates.Multiplicity / (ISNULL(BankAcountExchangeRates.ExchangeRate, 1) * ISNULL(ExchangeRatesOfDocument.Multiplicity, 1))
		|			ELSE 1
		|		END AS NUMBER(15, 2)) AS DocumentAmount,
		|	VALUE(Document.SalesOrder.EmptyRef) AS Order,
		|	CASE
		|		WHEN WorkOrderTableWithVAT.OrderStatus = VALUE(Enum.OrderStatuses.Completed)
		|			THEN FALSE
		|		ELSE TRUE
		|	END AS AdvanceFlag,
		|	CASE
		|		WHEN WorkOrderTableWithVAT.OrderStatus = VALUE(Enum.OrderStatuses.Completed)
		|				AND WorkOrderTableWithVAT.DoOperationsByDocuments
		|			THEN WorkOrderTableWithVAT.Ref
		|		ELSE UNDEFINED
		|	END AS Document
		|FROM
		|	Document.WorkOrder.PaymentCalendar AS WorkOrderPaymentCalendar
		|		INNER JOIN WorkOrderTableWithVAT AS WorkOrderTableWithVAT
		|		ON WorkOrderPaymentCalendar.Ref = WorkOrderTableWithVAT.Ref
		|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&Date, ) AS SettlementsExchangeRates
		|		ON (WorkOrderTableWithVAT.SettlementsCurrency = SettlementsExchangeRates.Currency)
		|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&Date, ) AS ExchangeRatesOfDocument
		|		ON (WorkOrderTableWithVAT.DocumentCurrency = ExchangeRatesOfDocument.Currency)
		|		LEFT JOIN WorkOrderBankAccount AS WorkOrderBankAccount
		|		ON (WorkOrderTableWithVAT.Company = WorkOrderBankAccount.Owner)
		|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&Date, ) AS BankAcountExchangeRates
		|		ON (WorkOrderBankAccount.CashCurrency = BankAcountExchangeRates.Currency)
		|WHERE
		|	WorkOrderPaymentCalendar.LineNumber = &LineNumber";
		
	EndIf;
	
	Selection = Query.Execute().Select();
	PaymentDetails.Clear();
	
	While Selection.Next() Do
		
		FillPropertyValues(ThisObject, Selection);
		If Not ValueIsFilled(CashCurrency) Then
			CashCurrency = Selection.DocumentCurrency;
		EndIf;
		NewRow = PaymentDetails.Add();
		FillPropertyValues(NewRow, Selection);
		If Not VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then
			FillVATRateByVATTaxation(NewRow);
		EndIf;
		
	EndDo;
	
	DocumentAmount = PaymentDetails.Total("PaymentAmount");
	
	FillCounterpartyBankAcc();
	
EndProcedure

// Procedure of filling the document on the basis.
//
// Parameters:
// FillingData - Structure - Data on filling the document.
//
Procedure FillBySalesOrderDependOnBalanceForPayment(FillingData)
	
	Query = New Query();
	
	Query.SetParameter("Ref", FillingData);
	Query.SetParameter("Date", CurrentDate());
	
	// Fill data of the document tabular sections.
	Query.Text =
	"SELECT
	|	VALUE(Enum.OperationTypesPaymentReceipt.FromCustomer) AS OperationKind,
	|	&Date AS Date,
	|	&Ref AS BasisDocument,
	|	DocumentHeader.Company AS Company,
	|	DocumentHeader.VATTaxation AS VATTaxation,
	|	BankAccountsNestedSelect.CashCurrency AS CashCurrency,
	|	BankAccountsNestedSelect.BankAccount AS BankAccount,
	|	DocumentHeader.Counterparty AS Counterparty,
	|	DocumentHeader.Contract AS Contract,
	|	DocumentHeader.DocumentCurrency AS DocumentCurrency,
	|	TRUE AS AdvanceFlag,
	|	&Ref AS Quote,
	|	NestedSelect.VATRate AS VATRate,
	|	ISNULL(SettlementsExchangeRates.ExchangeRate, 1) AS ExchangeRate,
	|	ISNULL(ExchangeRatesOfDocument.Multiplicity, 1) AS Multiplicity,
	|	InvoicesAndOrdersPaymentTurnovers.AmountTurnover - InvoicesAndOrdersPaymentTurnovers.PaymentAmountTurnover - InvoicesAndOrdersPaymentTurnovers.AdvanceAmountTurnover AS Total,
	|	DocumentHeader.DocumentCurrency AS DocumentCur1,
	|	BankAccountsNestedSelect.CashCurrency AS CashCurrency1,
	|	ExchangeRatesOfDocument.ExchangeRate AS ExchangeRate1,
	|	SettlementsExchangeRates.ExchangeRate AS ExchangeRate2,
	|	BankAcountExchangeRates.ExchangeRate AS ExchangeRate3,
	|	CAST((InvoicesAndOrdersPaymentTurnovers.AmountTurnover - InvoicesAndOrdersPaymentTurnovers.PaymentAmountTurnover - InvoicesAndOrdersPaymentTurnovers.AdvanceAmountTurnover) * CASE
	|			WHEN DocumentHeader.DocumentCurrency <> DocumentHeader.Contract.SettlementsCurrency
	|					AND SettlementsExchangeRates.ExchangeRate <> 0
	|					AND ExchangeRatesOfDocument.Multiplicity <> 0
	|				THEN ExchangeRatesOfDocument.ExchangeRate * SettlementsExchangeRates.Multiplicity / (ISNULL(SettlementsExchangeRates.ExchangeRate, 1) * ISNULL(ExchangeRatesOfDocument.Multiplicity, 1))
	|			ELSE 1
	|		END AS NUMBER(15, 2)) AS SettlementsAmount,
	|	CAST((InvoicesAndOrdersPaymentTurnovers.AmountTurnover - InvoicesAndOrdersPaymentTurnovers.PaymentAmountTurnover - InvoicesAndOrdersPaymentTurnovers.AdvanceAmountTurnover) * CASE
	|			WHEN DocumentHeader.DocumentCurrency <> BankAccountsNestedSelect.CashCurrency
	|					AND ExchangeRatesOfDocument.Multiplicity <> 0
	|					AND BankAcountExchangeRates.ExchangeRate <> 0
	|				THEN ExchangeRatesOfDocument.ExchangeRate * BankAcountExchangeRates.Multiplicity / (ISNULL(BankAcountExchangeRates.ExchangeRate, 1) * ISNULL(ExchangeRatesOfDocument.Multiplicity, 1))
	|			ELSE 1
	|		END AS NUMBER(15, 2)) AS PaymentAmount,
	|	CAST((InvoicesAndOrdersPaymentTurnovers.AmountTurnover - InvoicesAndOrdersPaymentTurnovers.PaymentAmountTurnover - InvoicesAndOrdersPaymentTurnovers.AdvanceAmountTurnover) * (1 - 1 / ((ISNULL(NestedSelect.VATRate.Rate, 0) + 100) / 100)) * CASE
	|			WHEN DocumentHeader.DocumentCurrency <> BankAccountsNestedSelect.CashCurrency
	|					AND ExchangeRatesOfDocument.Multiplicity <> 0
	|					AND BankAcountExchangeRates.ExchangeRate <> 0
	|				THEN ExchangeRatesOfDocument.ExchangeRate * BankAcountExchangeRates.Multiplicity / (ISNULL(BankAcountExchangeRates.ExchangeRate, 1) * ISNULL(ExchangeRatesOfDocument.Multiplicity, 1))
	|			ELSE 1
	|		END AS NUMBER(15, 2)) AS VATAmount,
	|	CAST((InvoicesAndOrdersPaymentTurnovers.AmountTurnover - InvoicesAndOrdersPaymentTurnovers.PaymentAmountTurnover - InvoicesAndOrdersPaymentTurnovers.AdvanceAmountTurnover) * CASE
	|			WHEN DocumentHeader.DocumentCurrency <> BankAccountsNestedSelect.CashCurrency
	|					AND ExchangeRatesOfDocument.Multiplicity <> 0
	|					AND BankAcountExchangeRates.ExchangeRate <> 0
	|				THEN ExchangeRatesOfDocument.ExchangeRate * BankAcountExchangeRates.Multiplicity / (ISNULL(BankAcountExchangeRates.ExchangeRate, 1) * ISNULL(ExchangeRatesOfDocument.Multiplicity, 1))
	|			ELSE 1
	|		END AS NUMBER(15, 2)) AS DocumentAmount,
	|	CASE
	|		WHEN DocumentHeader.Counterparty.DoOperationsByOrders
	|			THEN &Ref
	|		ELSE VALUE(Document.SalesOrder.EmptyRef)
	|	END AS Order,
	|	UNDEFINED AS Document
	|FROM
	|	Document.SalesOrder AS DocumentHeader
	|		LEFT JOIN (SELECT TOP 1
	|			VATRatesDocumentsTable.Ref AS Ref,
	|			VATRatesDocumentsTable.VATRate AS VATRate
	|		FROM
	|			(SELECT TOP 1
	|				&Ref AS Ref,
	|				DocumentTable.VATRate AS VATRate
	|			FROM
	|				Document.SalesOrder.Inventory AS DocumentTable
	|			WHERE
	|				DocumentTable.Ref = &Ref
			
	|			UNION ALL
			
	|			SELECT TOP 1
	|				DocumentTable.Ref,
	|				DocumentTable.VATRate
	|			FROM
	|				Document.SalesOrder.Works AS DocumentTable
	|			WHERE
	|				DocumentTable.Ref = &Ref) AS VATRatesDocumentsTable) AS NestedSelect
	|		ON DocumentHeader.Ref = NestedSelect.Ref
	|		LEFT JOIN AccumulationRegister.InvoicesAndOrdersPayment.Turnovers AS InvoicesAndOrdersPaymentTurnovers
	|		ON DocumentHeader.Ref = InvoicesAndOrdersPaymentTurnovers.Quote
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&Date, ) AS SettlementsExchangeRates
	|		ON DocumentHeader.Contract.SettlementsCurrency = SettlementsExchangeRates.Currency
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&Date, ) AS ExchangeRatesOfDocument
	|		ON DocumentHeader.DocumentCurrency = ExchangeRatesOfDocument.Currency
	|		LEFT JOIN (SELECT TOP 1
	|			CASE
	|				WHEN DocumentTable.BankAccount <> VALUE(Catalog.BankAccounts.EmptyRef)
	|					THEN DocumentTable.BankAccount
	|				WHEN DocumentTable.Company.BankAccountByDefault.CashCurrency = DocumentTable.Contract.SettlementsCurrency
	|					THEN DocumentTable.Company.BankAccountByDefault
	|				WHEN ISNULL(BankAccounts.Ref, VALUE(Catalog.BankAccounts.EmptyRef)) <> VALUE(Catalog.BankAccounts.EmptyRef)
	|					THEN BankAccounts.Ref
	|				ELSE DocumentTable.Company.BankAccountByDefault
	|			END AS BankAccount,
	|			CASE
	|				WHEN DocumentTable.BankAccount <> VALUE(Catalog.BankAccounts.EmptyRef)
	|					THEN DocumentTable.BankAccount.CashCurrency
	|				WHEN DocumentTable.Company.BankAccountByDefault.CashCurrency = DocumentTable.Contract.SettlementsCurrency
	|					THEN DocumentTable.Company.BankAccountByDefault.CashCurrency
	|				WHEN ISNULL(BankAccounts.Ref, VALUE(Catalog.BankAccounts.EmptyRef)) <> VALUE(Catalog.BankAccounts.EmptyRef)
	|					THEN BankAccounts.CashCurrency
	|				ELSE DocumentTable.Company.BankAccountByDefault.CashCurrency
	|			END AS CashCurrency,
	|			CASE
	|				WHEN DocumentTable.BankAccount <> VALUE(Catalog.BankAccounts.EmptyRef)
	|					THEN DocumentTable.BankAccount.Owner
	|				WHEN DocumentTable.Company.BankAccountByDefault.CashCurrency = DocumentTable.Contract.SettlementsCurrency
	|					THEN DocumentTable.Company.BankAccountByDefault.Owner
	|				WHEN ISNULL(BankAccounts.Ref, VALUE(Catalog.BankAccounts.EmptyRef)) <> VALUE(Catalog.BankAccounts.EmptyRef)
	|					THEN BankAccounts.Ref.Owner
	|				ELSE DocumentTable.Company.BankAccountByDefault.Owner
	|			END AS Owner
	|		FROM
	|			Document.SalesOrder AS DocumentTable
	|				LEFT JOIN Catalog.BankAccounts AS BankAccounts
	|				ON DocumentTable.Company = BankAccounts.Owner
	|					AND DocumentTable.DocumentCurrency = BankAccounts.CashCurrency
	|					AND (BankAccounts.DeletionMark = FALSE)
	|		WHERE
	|			DocumentTable.Ref = &Ref) AS BankAccountsNestedSelect
	|			LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&Date, ) AS BankAcountExchangeRates
	|			ON BankAccountsNestedSelect.CashCurrency = BankAcountExchangeRates.Currency
	|		ON DocumentHeader.Company = BankAccountsNestedSelect.Owner
	|WHERE
	|	DocumentHeader.Ref = &Ref";
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		FillPropertyValues(ThisObject, Selection);
		If Not ValueIsFilled(CashCurrency) Then
			CashCurrency = Selection.DocumentCurrency;
		EndIf;
		NewRow = PaymentDetails.Add();
		FillPropertyValues(NewRow, Selection);
		If Not VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then
			FillVATRateByVATTaxation(NewRow);
		EndIf;
		
	EndDo;
	
	DocumentAmount = PaymentDetails.Total("PaymentAmount");
	
	FillCounterpartyBankAcc();
	
EndProcedure

// Procedure of filling the document on the basis of tax Earning.
//
// Parameters:
// BasisDocument - DocumentRef.CashInflowForecast - Scheduled
// payment FillingData - Structure - Data on filling the document.
//	
Procedure FillByTaxAccrual(BasisDocument)
	
	If BasisDocument.OperationKind <> Enums.OperationTypesTaxAccrual.Reimbursement Then
		Raise NStr("en = 'Please select a tax accrual with ""Compensation"" operation.'");
	EndIf;
	
	Query = New Query;
	Query.SetParameter("Ref",							BasisDocument);
	Query.SetParameter("Date",							?(ValueIsFilled(Date), Date, CurrentDate()));
	Query.SetParameter("ConstantNationalCurrency",		Constants.FunctionalCurrency.Get());
	Query.SetParameter("ConstantAccountingCurrency",	Constants.PresentationCurrency.Get());
	
	Query.Text =
	"SELECT
	|	VALUE(Enum.OperationTypesPaymentReceipt.Taxes) AS OperationKind,
	|	VALUE(Catalog.CashFlowItems.Other) AS Item,
	|	&Ref AS BasisDocument,
	|	DocumentTable.Company AS Company,
	|	CASE
	|		WHEN DocumentTable.Company.BankAccountByDefault.CashCurrency = &ConstantNationalCurrency
	|			THEN DocumentTable.Company.BankAccountByDefault
	|		ELSE NestedSelect.BankAccount
	|	END AS BankAccount,
	|	&ConstantNationalCurrency AS CashCurrency,
	|	AccountingPolicySliceLast.DefaultVATRate AS VATRate,
	|	1 AS ExchangeRate,
	|	1 AS Multiplicity,
	|	CAST(DocumentTable.DocumentAmount * AccountingExchangeRates.ExchangeRate * 1 / (1 * ISNULL(AccountingExchangeRates.Multiplicity, 1)) AS NUMBER(15, 2)) AS DocumentAmount,
	|	DocumentTableTaxes.TaxKind AS TaxKind,
	|	DocumentTableTaxes.BusinessLine AS BusinessLine
	|FROM
	|	Document.TaxAccrual AS DocumentTable
	|		LEFT JOIN (SELECT TOP 1
	|			DocumentTable.Ref AS Ref,
	|			DocumentTable.TaxKind AS TaxKind,
	|			DocumentTable.BusinessLine AS BusinessLine
	|		FROM
	|			Document.TaxAccrual.Taxes AS DocumentTable
	|		WHERE
	|			DocumentTable.Ref = &Ref) AS DocumentTableTaxes
	|		ON DocumentTable.Ref = DocumentTableTaxes.Ref
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&Date, Currency = &ConstantAccountingCurrency) AS AccountingExchangeRates
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.AccountingPolicy.SliceLast(&Date, ) AS AccountingPolicySliceLast
	|		ON DocumentTable.Company = AccountingPolicySliceLast.Company
	|		LEFT JOIN (SELECT TOP 1
	|			BankAccounts.Ref AS BankAccount,
	|			BankAccounts.Owner AS Owner,
	|			BankAccounts.CashCurrency AS CashCurrency
	|		FROM
	|			Document.TaxAccrual AS DocumentTable
	|				LEFT JOIN Catalog.BankAccounts AS BankAccounts
	|				ON DocumentTable.Company = BankAccounts.Owner
	|					AND (BankAccounts.CashCurrency = &ConstantNationalCurrency)
	|		WHERE
	|			DocumentTable.Ref = &Ref
	|			AND BankAccounts.DeletionMark = FALSE) AS NestedSelect
	|		ON DocumentTable.Company = NestedSelect.Owner
	|WHERE
	|	DocumentTable.Ref = &Ref";
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		
		Selection = QueryResult.Select();
		Selection.Next();
		FillPropertyValues(ThisObject, Selection);
		VATTaxation = DriveServer.VATTaxation(Company, Date);
		PaymentDetails.Clear();
		
	EndIf;
	
EndProcedure

// Procedure of filling the document on the basis.
//
// Parameters:
// FillingData - Structure - Data on filling the document.
//	
Procedure FillBySalesInvoice(BasisDocument)
	
	Query = New Query;
	
	Query.SetParameter("Ref", BasisDocument);
	Query.SetParameter("Date", ?(ValueIsFilled(Date), Date, CurrentDate()));
	
	Query.Text =
	"SELECT
	|	VALUE(Enum.OperationTypesPaymentReceipt.FromCustomer) AS OperationKind,
	|	VALUE(Catalog.CashFlowItems.PaymentFromCustomers) AS Item,
	|	&Ref AS BasisDocument,
	|	CASE
	|		WHEN DocumentHeader.Company.BankAccountByDefault.CashCurrency = DocumentHeader.Contract.SettlementsCurrency
	|			THEN DocumentHeader.Company.BankAccountByDefault
	|		ELSE NestedSelect.BankAccount
	|	END AS BankAccount,
	|	DocumentHeader.Company AS Company,
	|	DocumentHeader.VATTaxation AS VATTaxation,
	|	REFPRESENTATION(&Ref) AS Basis,
	|	DocumentHeader.Counterparty AS Counterparty,
	|	DocumentHeader.DocumentCurrency AS CashCurrency,
	|	CASE
	|		WHEN DocumentHeader.Counterparty.DoOperationsByOrders
	|				AND DocumentTable.Order REFS Document.SalesOrder
	|			THEN DocumentTable.Order
	|		ELSE VALUE(Document.SalesOrder.EmptyRef)
	|	END AS Order,
	|	DocumentHeader.Contract AS Contract,
	|	FALSE AS AdvanceFlag,
	|	CASE
	|		WHEN DocumentHeader.Counterparty.DoOperationsByDocuments
	|			THEN &Ref
	|		ELSE UNDEFINED
	|	END AS Document,
	|	SUM(ISNULL(CAST(DocumentTable.Total * CASE
	|					WHEN DocumentHeader.DocumentCurrency = ConstantNationalCurrency.Value
	|						THEN RegCurrenciesRates.ExchangeRate * DocumentHeader.Multiplicity / (DocumentHeader.ExchangeRate * ISNULL(RegCurrenciesRates.Multiplicity, 1))
	|					ELSE 1
	|				END AS NUMBER(15, 2)), 0)) AS SettlementsAmount,
	|	CASE
	|		WHEN DocumentHeader.DocumentCurrency = ConstantNationalCurrency.Value
	|			THEN DocumentHeader.ExchangeRate
	|		ELSE SettlementsExchangeRatesSliceLast.ExchangeRate
	|	END AS ExchangeRate,
	|	CASE
	|		WHEN DocumentHeader.DocumentCurrency = ConstantNationalCurrency.Value
	|			THEN DocumentHeader.Multiplicity
	|		ELSE SettlementsExchangeRatesSliceLast.Multiplicity
	|	END AS Multiplicity,
	|	SUM(ISNULL(DocumentTable.Total, 0)) AS PaymentAmount,
	|	DocumentTable.VATRate AS VATRate,
	|	SUM(ISNULL(DocumentTable.VATAmount, 0)) AS VATAmount
	|FROM
	|	Document.SalesInvoice AS DocumentHeader
	|		LEFT JOIN Document.SalesInvoice.Inventory AS DocumentTable
	|		ON DocumentHeader.Ref = DocumentTable.Ref
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(
	|				&Date,
	|				Currency IN
	|					(SELECT
	|						ConstantNationalCurrency.Value
	|					FROM
	|						Constant.FunctionalCurrency AS ConstantNationalCurrency)) AS RegCurrenciesRates
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&Date, ) AS SettlementsExchangeRatesSliceLast
	|		ON DocumentHeader.Contract.SettlementsCurrency = SettlementsExchangeRatesSliceLast.Currency
	|		LEFT JOIN (SELECT TOP 1
	|			BankAccounts.Ref AS BankAccount,
	|			BankAccounts.Owner AS Owner,
	|			BankAccounts.CashCurrency AS CashCurrency
	|		FROM
	|			Document.SalesInvoice AS DocumentTable
	|				LEFT JOIN Catalog.BankAccounts AS BankAccounts
	|				ON DocumentTable.Company = BankAccounts.Owner
	|					AND DocumentTable.DocumentCurrency = BankAccounts.CashCurrency
	|		WHERE
	|			DocumentTable.Ref = &Ref
	|			AND BankAccounts.DeletionMark = FALSE) AS NestedSelect
	|		ON DocumentHeader.DocumentCurrency = NestedSelect.CashCurrency
	|			AND DocumentHeader.Company = NestedSelect.Owner,
	|	Constant.FunctionalCurrency AS ConstantNationalCurrency
	|WHERE
	|	DocumentHeader.Ref = &Ref
	|
	|GROUP BY
	|	DocumentHeader.Company,
	|	DocumentHeader.VATTaxation,
	|	DocumentHeader.Counterparty,
	|	DocumentHeader.DocumentCurrency,
	|	CASE
	|		WHEN DocumentHeader.Counterparty.DoOperationsByOrders
	|				AND DocumentTable.Order REFS Document.SalesOrder
	|			THEN DocumentTable.Order
	|		ELSE VALUE(Document.SalesOrder.EmptyRef)
	|	END,
	|	DocumentHeader.Contract,
	|	DocumentTable.VATRate,
	|	CASE
	|		WHEN DocumentHeader.Company.BankAccountByDefault.CashCurrency = DocumentHeader.Contract.SettlementsCurrency
	|			THEN DocumentHeader.Company.BankAccountByDefault
	|		ELSE NestedSelect.BankAccount
	|	END,
	|	CASE
	|		WHEN DocumentHeader.DocumentCurrency = ConstantNationalCurrency.Value
	|			THEN DocumentHeader.ExchangeRate
	|		ELSE SettlementsExchangeRatesSliceLast.ExchangeRate
	|	END,
	|	CASE
	|		WHEN DocumentHeader.DocumentCurrency = ConstantNationalCurrency.Value
	|			THEN DocumentHeader.Multiplicity
	|		ELSE SettlementsExchangeRatesSliceLast.Multiplicity
	|	END,
	|	CASE
	|		WHEN DocumentHeader.Counterparty.DoOperationsByDocuments
	|			THEN &Ref
	|		ELSE UNDEFINED
	|	END";
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		
		Selection = QueryResult.Select();
		Selection.Next();
		FillPropertyValues(ThisObject, Selection);
		PaymentDetails.Clear();
		NewRow = PaymentDetails.Add();
		FillPropertyValues(NewRow, Selection);
		DocumentAmount = Selection.PaymentAmount;
		
		While Selection.Next() Do
			NewRow = PaymentDetails.Add();
			FillPropertyValues(NewRow, Selection);
			DocumentAmount = DocumentAmount + Selection.PaymentAmount;
		EndDo;
		
		DefinePaymentDetailsExistsEPD();
		
	EndIf;
	
	FillCounterpartyBankAcc();
	
EndProcedure

// Procedure of filling the document on the basis.
//
// Parameters:
// FillingData - Structure - Data on filling the document.
//	
Procedure FillByFixedAssetSale(BasisDocument)
	
	Query = New Query;
	
	Query.SetParameter("Ref", BasisDocument);
	Query.SetParameter("Date", ?(ValueIsFilled(Date), Date, CurrentDate()));
	
	Query.Text =
	"SELECT
	|	VALUE(Enum.OperationTypesPaymentReceipt.FromCustomer) AS OperationKind,
	|	&Ref AS BasisDocument,
	|	DocumentHeader.Company AS Company,
	|	CASE
	|		WHEN DocumentHeader.Company.BankAccountByDefault.CashCurrency = DocumentHeader.Contract.SettlementsCurrency
	|			THEN DocumentHeader.Company.BankAccountByDefault
	|		ELSE NestedSelect.BankAccount
	|	END AS BankAccount,
	|	DocumentHeader.VATTaxation AS VATTaxation,
	|	REFPRESENTATION(&Ref) AS Basis,
	|	DocumentHeader.Counterparty AS Counterparty,
	|	DocumentHeader.DocumentCurrency AS CashCurrency,
	|	DocumentHeader.Contract AS Contract,
	|	FALSE AS AdvanceFlag,
	|	CASE
	|		WHEN DocumentHeader.Counterparty.DoOperationsByDocuments
	|			THEN &Ref
	|		ELSE UNDEFINED
	|	END AS Document,
	|	SUM(ISNULL(CAST(DocumentTable.Total * CASE
	|					WHEN DocumentHeader.DocumentCurrency = ConstantNationalCurrency.Value
	|						THEN RegCurrenciesRates.ExchangeRate * DocumentHeader.Multiplicity / (DocumentHeader.ExchangeRate * ISNULL(RegCurrenciesRates.Multiplicity, 1))
	|					ELSE 1
	|				END AS NUMBER(15, 2)), 0)) AS SettlementsAmount,
	|	CASE
	|		WHEN DocumentHeader.DocumentCurrency = ConstantNationalCurrency.Value
	|			THEN DocumentHeader.ExchangeRate
	|		ELSE SettlementsExchangeRatesSliceLast.ExchangeRate
	|	END AS ExchangeRate,
	|	CASE
	|		WHEN DocumentHeader.DocumentCurrency = ConstantNationalCurrency.Value
	|			THEN DocumentHeader.Multiplicity
	|		ELSE SettlementsExchangeRatesSliceLast.Multiplicity
	|	END AS Multiplicity,
	|	SUM(ISNULL(DocumentTable.Total, 0)) AS PaymentAmount,
	|	DocumentTable.VATRate AS VATRate,
	|	SUM(ISNULL(DocumentTable.VATAmount, 0)) AS VATAmount
	|FROM
	|	Document.FixedAssetSale AS DocumentHeader
	|		LEFT JOIN Document.FixedAssetSale.FixedAssets AS DocumentTable
	|		ON DocumentHeader.Ref = DocumentTable.Ref
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(
	|				&Date,
	|				Currency In
	|					(SELECT
	|						ConstantNationalCurrency.Value
	|					FROM
	|						Constant.FunctionalCurrency AS ConstantNationalCurrency)) AS RegCurrenciesRates
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&Date, ) AS SettlementsExchangeRatesSliceLast
	|		ON DocumentHeader.Contract.SettlementsCurrency = SettlementsExchangeRatesSliceLast.Currency
	|		LEFT JOIN (SELECT TOP 1
	|			BankAccounts.Ref AS BankAccount,
	|			BankAccounts.Owner AS Owner,
	|			BankAccounts.CashCurrency AS CashCurrency
	|		FROM
	|			Document.FixedAssetSale AS DocumentTable
	|				LEFT JOIN Catalog.BankAccounts AS BankAccounts
	|				ON DocumentTable.Company = BankAccounts.Owner
	|					AND DocumentTable.DocumentCurrency = BankAccounts.CashCurrency
	|		WHERE
	|			DocumentTable.Ref = &Ref
	|			AND BankAccounts.DeletionMark = FALSE) AS NestedSelect
	|		ON DocumentHeader.DocumentCurrency = NestedSelect.CashCurrency
	|			AND DocumentHeader.Company = NestedSelect.Owner,
	|	Constant.FunctionalCurrency AS ConstantNationalCurrency
	|WHERE
	|	DocumentHeader.Ref = &Ref
	|
	|GROUP BY
	|	DocumentHeader.Company,
	|	DocumentHeader.VATTaxation,
	|	DocumentHeader.Counterparty,
	|	DocumentHeader.DocumentCurrency,
	|	DocumentHeader.Contract,
	|	DocumentTable.VATRate,
	|	CASE
	|		WHEN DocumentHeader.Company.BankAccountByDefault.CashCurrency = DocumentHeader.Contract.SettlementsCurrency
	|			THEN DocumentHeader.Company.BankAccountByDefault
	|		ELSE NestedSelect.BankAccount
	|	END,
	|	CASE
	|		WHEN DocumentHeader.DocumentCurrency = ConstantNationalCurrency.Value
	|			THEN DocumentHeader.ExchangeRate
	|		ELSE SettlementsExchangeRatesSliceLast.ExchangeRate
	|	END,
	|	CASE
	|		WHEN DocumentHeader.DocumentCurrency = ConstantNationalCurrency.Value
	|			THEN DocumentHeader.Multiplicity
	|		ELSE SettlementsExchangeRatesSliceLast.Multiplicity
	|	END,
	|	CASE
	|		WHEN DocumentHeader.Counterparty.DoOperationsByDocuments
	|			THEN &Ref
	|		ELSE UNDEFINED
	|	END";
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		
		Selection = QueryResult.Select();
		Selection.Next();
		FillPropertyValues(ThisObject, Selection);
		PaymentDetails.Clear();
		NewRow = PaymentDetails.Add();
		FillPropertyValues(NewRow, Selection);
		DocumentAmount = Selection.PaymentAmount;
		
		While Selection.Next() Do
			NewRow = PaymentDetails.Add();
			FillPropertyValues(NewRow, Selection);
			DocumentAmount = DocumentAmount + Selection.PaymentAmount;
		EndDo;
		
	EndIf;
	
EndProcedure

// Procedure fills the VAT rate in the tabular section according to the taxation system.
// 
Procedure FillVATRateByVATTaxation(TabularSectionRow)
	
	If VATTaxation = Enums.VATTaxationTypes.NotSubjectToVAT Then	
		TabularSectionRow.VATRate = Catalogs.VATRates.Exempt;
		TabularSectionRow.VATAmount = 0;
	ElsIf VATTaxation = Enums.VATTaxationTypes.ForExport Then	
		TabularSectionRow.VATRate = Catalogs.VATRates.ZeroRate;
		TabularSectionRow.VATAmount = 0;
	EndIf;
	
EndProcedure

// Defines field ExistsEPD in PaymentDetails tabular section
//
Procedure DefinePaymentDetailsExistsEPD() Export
	
	If OperationKind = Enums.OperationTypesPaymentReceipt.FromCustomer AND PaymentDetails.Count() > 0 Then
		
		DocumentArray			= PaymentDetails.UnloadColumn("Document");
		CheckDate				= ?(ValueIsFilled(Date), Date, CurrentSessionDate());
		DocumentArrayWithEPD	= Documents.SalesInvoice.GetSalesInvoiceArrayWithEPD(DocumentArray, CheckDate);
		
		For Each TabularSectionRow In PaymentDetails Do
			
			If TypeOf(TabularSectionRow.Document) = Type("DocumentRef.SalesInvoice") Then
				If DocumentArrayWithEPD.Find(TabularSectionRow.Document) = Undefined Then
					TabularSectionRow.ExistsEPD = False;
				Else
					TabularSectionRow.ExistsEPD = True;
				EndIf;
			Else
				TabularSectionRow.ExistsEPD = False;
			EndIf;
			
		EndDo;
		
	EndIf;
	
EndProcedure

#Region BankCharges

Procedure BringDataToConsistentState()
	
	If Not UseBankCharges Then
	
		BankCharge			= Catalogs.BankCharges.EmptyRef();
		BankChargeItem		= Catalogs.CashFlowItems.EmptyRef();
		BankChargeAmount	= 0;
	
	EndIf;
	
EndProcedure

#EndRegion

#Region OtherSettlements

Procedure FillByLoanContract(DocRefLoanContract, Amount = Undefined) Export
	      
	Query = New Query;
	Query.SetParameter("Ref",	DocRefLoanContract);
	Query.SetParameter("Date",	?(ValueIsFilled(Date), Date, CurrentDate()));
	
	If Amount <> Undefined Then
		
		Query.SetParameter("Amount", Amount);
		Query.Text =
		"SELECT
		|	REFPRESENTATION(&Ref) AS Basis,
		|	CASE
		|		WHEN DocumentTable.LoanKind = VALUE(Enum.LoanContractTypes.Borrowed)
		|			THEN VALUE(Enum.OperationTypesPaymentReceipt.LoanSettlements)
		|		ELSE VALUE(Enum.OperationTypesPaymentReceipt.LoanRepaymentByEmployee)
		|	END AS OperationKind,
		|	&Ref AS BasisDocument,
		|	DocumentTable.Company AS Company,
		|	DocumentTable.SettlementsCurrency AS CashCurrency,
		|	DocumentTable.Employee AS AdvanceHolder,
		|	DocumentTable.Counterparty AS Counterparty,
		|	&Ref AS LoanContract,
		|	&Amount AS DocumentAmount,
		|	&Amount AS PaymentAmount,
		|	AccountingPolicySliceLast.DefaultVATRate AS VATRate,
		|	ISNULL(ExchangeRates.ExchangeRate, 1) AS ExchangeRate,
		|	ISNULL(ExchangeRates.Multiplicity, 1) AS Multiplicity,
		|	CAST(&Amount AS NUMBER(15, 2)) AS SettlementsAmount,
		|	CAST(&Amount * (1 - 1 / ((ISNULL(AccountingPolicySliceLast.DefaultVATRate.Rate, 0) + 100) / 100)) AS NUMBER(15, 2)) AS VATAmount
		|FROM
		|	Document.LoanContract AS DocumentTable
		|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&Date, ) AS ExchangeRates
		|		ON DocumentTable.SettlementsCurrency = ExchangeRates.Currency
		|		LEFT JOIN InformationRegister.AccountingPolicy.SliceLast(&Date, ) AS AccountingPolicySliceLast
		|		ON DocumentTable.Company = AccountingPolicySliceLast.Company
		|WHERE
		|	DocumentTable.Ref = &Ref";
		
	Else
		
		Query.Text =
		"SELECT
		|	REFPRESENTATION(&Ref) AS Basis,
		|	CASE
		|		WHEN DocumentTable.LoanKind = VALUE(Enum.LoanContractTypes.Borrowed)
		|			THEN VALUE(Enum.OperationTypesPaymentReceipt.LoanSettlements)
		|		ELSE VALUE(Enum.OperationTypesPaymentReceipt.LoanRepaymentByEmployee)
		|	END AS OperationKind,
		|	&Ref AS BasisDocument,
		|	DocumentTable.Company AS Company,
		|	DocumentTable.SettlementsCurrency AS CashCurrency,
		|	DocumentTable.Employee AS AdvanceHolder,
		|	DocumentTable.Counterparty AS Counterparty,
		|	&Ref AS LoanContract,
		|	DocumentTable.Total AS DocumentAmount,
		|	DocumentTable.Total AS PaymentAmount,
		|	AccountingPolicySliceLast.DefaultVATRate AS VATRate,
		|	ISNULL(ExchangeRates.ExchangeRate, 1) AS ExchangeRate,
		|	ISNULL(ExchangeRates.Multiplicity, 1) AS Multiplicity,
		|	CAST(DocumentTable.Total AS NUMBER(15, 2)) AS SettlementsAmount,
		|	CAST(DocumentTable.Total * (1 - 1 / ((ISNULL(AccountingPolicySliceLast.DefaultVATRate.Rate, 0) + 100) / 100)) AS NUMBER(15, 2)) AS VATAmount
		|FROM
		|	Document.LoanContract AS DocumentTable
		|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&Date, ) AS ExchangeRates
		|		ON DocumentTable.SettlementsCurrency = ExchangeRates.Currency
		|		LEFT JOIN InformationRegister.AccountingPolicy.SliceLast(&Date, ) AS AccountingPolicySliceLast
		|		ON DocumentTable.Company = AccountingPolicySliceLast.Company
		|WHERE
		|	DocumentTable.Ref = &Ref";
		
	EndIf;
	
	QueryResult = Query.Execute();
	
	If NOT QueryResult.IsEmpty() Then
		
		Selection = QueryResult.Select();
		Selection.Next();
		FillPropertyValues(ThisObject, Selection);
		
		VATTaxation = Enums.VATTaxationTypes.NotSubjectToVAT;
		
		PaymentDetails.Clear();
		If DocRefLoanContract.LoanKind = Enums.LoanContractTypes.Borrowed Then
			NewRow = PaymentDetails.Add();
			FillPropertyValues(NewRow, Selection);
		Else
			DocumentAmount = 0;
		EndIf;
		
		PettyCash = Catalogs.CashAccounts.GetPettyCashByDefault(Company);
		
	EndIf;
	
EndProcedure

Procedure FillByAccrualsForLoans(FillingData) Export
	
	Query = New Query;
	
	If TypeOf(FillingData) = Type("Structure") Then
		
		Query.SetParameter("Ref",					FillingData.Document);
		Query.SetParameter("Employee",				FillingData.Employee);
		Query.SetParameter("Counterparty",			FillingData.Lender);
		Query.SetParameter("LoanContract",			FillingData.LoanContract);
		Query.SetParameter("Currency",				FillingData.SettlementsCurrency);
		
	ElsIf FillingData.Accruals.Count() > 0 Then
		
		Query.SetParameter("Ref",					FillingData);
		Query.SetParameter("Employee",				FillingData.Accruals[0].Employee);
		Query.SetParameter("Counterparty",			FillingData.Accruals[0].Lender);
		Query.SetParameter("LoanContract",			FillingData.Accruals[0].LoanContract);
		Query.SetParameter("Currency",				FillingData.Accruals[0].SettlementsCurrency);
		
	Else
		Return;
	EndIf;
	
	Query.SetParameter("Date", ?(ValueIsFilled(Date), Date, CurrentDate()));
	
	Query.Text =
	"SELECT
	|	REFPRESENTATION(&Ref) AS Basis,
	|	VALUE(Enum.OperationTypesPaymentReceipt.LoanRepaymentByEmployee) AS OperationKind,
	|	&Ref AS BasisDocument,
	|	DocumentTable.Ref.Company AS Company,
	|	DocumentTable.SettlementsCurrency AS CashCurrency,
	|	DocumentTable.Employee AS AdvanceHolder,
	|	DocumentTable.LoanContract AS LoanContract,
	|	DocumentTable.AmountType AS TypeOfAmount,
	|	DocumentTable.Total AS PaymentAmount,
	|	AccountingPolicySliceLast.DefaultVATRate AS VATRate,
	|	ISNULL(ExchangeRates.ExchangeRate, 1) AS ExchangeRate,
	|	ISNULL(ExchangeRates.Multiplicity, 1) AS Multiplicity,
	|	CAST(DocumentTable.Total AS NUMBER(15, 2)) AS SettlementsAmount,
	|	CAST(DocumentTable.Total * (1 - 1 / ((ISNULL(AccountingPolicySliceLast.DefaultVATRate.Rate, 0) + 100) / 100)) AS NUMBER(15, 2)) AS VATAmount
	|FROM
	|	Document.LoanInterestCommissionAccruals.Accruals AS DocumentTable
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&Date, ) AS ExchangeRates
	|		ON DocumentTable.SettlementsCurrency = ExchangeRates.Currency
	|		LEFT JOIN InformationRegister.AccountingPolicy.SliceLast(&Date, ) AS AccountingPolicySliceLast
	|		ON DocumentTable.Ref.Company = AccountingPolicySliceLast.Company
	|WHERE
	|	DocumentTable.Ref = &Ref
	|	AND DocumentTable.LoanContract = &LoanContract
	|	AND DocumentTable.SettlementsCurrency = &Currency
	|	AND DocumentTable.Lender = &Counterparty
	|	AND DocumentTable.Employee = &Employee";
	
	QueryResult = Query.Execute();
	
	If NOT QueryResult.IsEmpty() Then
		
		Selection = QueryResult.Select();
		Selection.Next();
		FillPropertyValues(ThisObject, Selection);
		
		VATTaxation = Enums.VATTaxationTypes.NotSubjectToVAT;
		
		PaymentDetails.Clear();
		
		NewRow = PaymentDetails.Add();
		FillPropertyValues(NewRow, Selection);
		
		While Selection.Next() Do
			NewRow = PaymentDetails.Add();
			FillPropertyValues(NewRow, Selection);
		EndDo;
		
		PettyCash = Catalogs.CashAccounts.GetPettyCashByDefault(Company);
		DocumentAmount = PaymentDetails.Total("PaymentAmount");
		
	EndIf;
EndProcedure

#EndRegion

#EndRegion

#Region EventHandlers

// Procedure - event handler BeforeWrite object.
//
Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	AdditionalProperties.Insert("WriteMode", WriteMode);
	
	For Each TSRow In PaymentDetails Do
		If ValueIsFilled(Counterparty)
		AND Not Counterparty.DoOperationsByContracts
		AND Not ValueIsFilled(TSRow.Contract) Then
			TSRow.Contract = Counterparty.ContractByDefault;
		EndIf;
		
		If (OperationKind = Enums.OperationTypesPaymentReceipt.OtherSettlements)
			AND TSRow.VATRate.IsEmpty() Then
			TSRow.VATRate	= Catalogs.VATRates.Exempt;
			TSRow.VATAmount	= 0;
		EndIf;
	EndDo;
	
	// Bank charges
	BringDataToConsistentState();
	// End Bank charges
	
EndProcedure

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	// Subordinate tax invoice
	If Not Cancel And AdditionalProperties.WriteMode = DocumentWriteMode.Write Then
		WorkWithVAT.SubordinatedTaxInvoiceControl(AdditionalProperties.WriteMode, Ref, DeletionMark);
	EndIf;
	
EndProcedure

// Procedure - handler of the FillingProcessor event.
//
Procedure Filling(FillingData, StandardProcessing)
	
	If TypeOf(FillingData) = Type("DocumentRef.CashInflowForecast") Then
		FillByCashInflowForecast(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.CashTransferPlan") Then
		FillByCashTransferPlan(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.SalesInvoice") Then
		FillBySalesInvoice(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.FixedAssetSale") Then
		FillByFixedAssetSale(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.Quote") Then
		FillByQuote(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.SalesOrder") Then
		FillBySalesOrder(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.WorkOrder") Then
		FillByWorkOrder(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.TaxAccrual") Then
		FillByTaxAccrual(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.LoanContract") Then
		FillByLoanContract(FillingData);
	ElsIf TypeOf(FillingData) = Type("Structure")
		AND FillingData.Property("Basis") Then
		
		If FillingData.Property("ConsiderBalances") 
			AND TypeOf(FillingData.Basis) = Type("DocumentRef.SalesOrder") Then
			
			FillBySalesOrderDependOnBalanceForPayment(FillingData.Basis);
		ElsIf TypeOf(FillingData.Basis) = Type("DocumentRef.Quote") Then
			FillByQuote(FillingData, FillingData.LineNumber);
		ElsIf TypeOf(FillingData.Basis) = Type("DocumentRef.SalesOrder") Then
			FillBySalesOrder(FillingData, FillingData.LineNumber);
		ElsIf TypeOf(FillingData.Basis) = Type("DocumentRef.WorkOrder") Then
			FillByWorkOrder(FillingData, FillingData.LineNumber);
		EndIf;
		
	ElsIf TypeOf(FillingData) = Type("Structure")
		AND FillingData.Property("Document") Then
		
		If TypeOf(FillingData.Document) = Type("DocumentRef.Quote") Then
			FillByQuote(FillingData.Document, Undefined, FillingData.Amount);
		ElsIf TypeOf(FillingData.Document) = Type("DocumentRef.SalesOrder") Then
			FillBySalesOrder(FillingData.Document, Undefined, FillingData.Amount);
		ElsIf TypeOf(FillingData.Document) = Type("DocumentRef.WorkOrder") Then
			FillByWorkOrder(FillingData.Document, Undefined, FillingData.Amount);
		ElsIf TypeOf(FillingData.Document) = Type("DocumentRef.CashInflowForecast") Then
			FillByCashInflowForecast(FillingData.Document, FillingData.Amount);
		ElsIf TypeOf(FillingData.Document) = Type("DocumentRef.CashTransferPlan") Then
			FillByCashTransferPlan(FillingData.Document, FillingData.Amount);
		ElsIf TypeOf(FillingData.Document) = Type("DocumentRef.LoanInterestCommissionAccruals") Then
			FillByAccrualsForLoans(FillingData);	
		EndIf;
		
	EndIf;
	
EndProcedure

// Procedure - event handler FillCheckProcessing object.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	// Deletion of verifiable attributes from the structure depending
	// on the operation type.
	If OperationKind = Enums.OperationTypesPaymentReceipt.FromVendor
	 OR OperationKind = Enums.OperationTypesPaymentReceipt.FromCustomer Then
	 
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "AdvanceHolder");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Correspondence");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Document");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "AccountingAmount");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "ExchangeRate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Multiplicity");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "TaxKind");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "LoanContract");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.TypeOfAmount");
		
		If Counterparty.DoOperationsByDocuments Then
			For Each RowPaymentDetails In PaymentDetails Do
				If Not ValueIsFilled(RowPaymentDetails.Document)
					AND (OperationKind = Enums.OperationTypesPaymentReceipt.FromVendor
				   OR (OperationKind = Enums.OperationTypesPaymentReceipt.FromCustomer
				   AND Not RowPaymentDetails.AdvanceFlag)) Then
					If PaymentDetails.Count() = 1 Then
						If OperationKind = Enums.OperationTypesPaymentReceipt.FromCustomer Then
							MessageText = NStr("en = 'Please specify the shipment document or select the ""Advance payment"" check box.'");
						Else
							MessageText = NStr("en = 'Please specify a billing document.'");
						EndIf;
					Else
						If OperationKind = Enums.OperationTypesPaymentReceipt.FromCustomer Then
							MessageText = NStr("en = 'Please specify the shipment document or payment flag in line #%LineNumber% of the payment details.'");
						Else
							MessageText = NStr("en = 'Please specify a billing document in line #%LineNumber% of the payment details.'");
						EndIf;
						MessageText = StrReplace(MessageText, "%LineNumber%", String(RowPaymentDetails.LineNumber));
					EndIf;
					DriveServer.ShowMessageAboutError(
						ThisObject,
						MessageText,
						"PaymentDetails",
						RowPaymentDetails.LineNumber,
						"Document",
						Cancel
					);
				EndIf;
			EndDo;
		EndIf;
		
		PaymentAmount = PaymentDetails.Total("PaymentAmount");
		If PaymentAmount <> DocumentAmount Then
			MessageText = NStr("en = 'The document amount (%DocumentAmount% %CashCurrency%) is not equal to the sum of payment amounts in the payment details (%PaymentAmount% %CashCurrency%).'");
			MessageText = StrReplace(MessageText, "%DocumentAmount%", String(DocumentAmount));
			MessageText = StrReplace(MessageText, "%PaymentAmount%", String(PaymentAmount));
			MessageText = StrReplace(MessageText, "%CashCurrency%", TrimAll(String(CashCurrency)));
			DriveServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				,
				,
				"DocumentAmount",
				Cancel
			);
		EndIf;
		
		If Not Counterparty.DoOperationsByContracts Then
			DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Contract");
		EndIf;
		
	ElsIf OperationKind = Enums.OperationTypesPaymentReceipt.FromAdvanceHolder Then
		
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Counterparty");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Correspondence");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "AccountingAmount");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "ExchangeRate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Multiplicity");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Contract");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.AdvanceFlag");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.SettlementsAmount");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.ExchangeRate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Multiplicity");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.VATRate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "TaxKind");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "LoanContract");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.TypeOfAmount");
		
	ElsIf OperationKind = Enums.OperationTypesPaymentReceipt.Other Then
		
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "AdvanceHolder");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Counterparty");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Document");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "AccountingAmount");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "ExchangeRate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Multiplicity");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Contract");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.AdvanceFlag");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.SettlementsAmount");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.ExchangeRate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Multiplicity");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.VATRate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "TaxKind");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "LoanContract");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.TypeOfAmount");
		
	ElsIf OperationKind = Enums.OperationTypesPaymentReceipt.CurrencyPurchase Then
		
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "AdvanceHolder");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Counterparty");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Document");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Contract");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.AdvanceFlag");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.SettlementsAmount");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.ExchangeRate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Multiplicity");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.VATRate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "TaxKind");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "LoanContract");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.TypeOfAmount");
		
	ElsIf OperationKind = Enums.OperationTypesPaymentReceipt.OtherSettlements Then
		
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "AdvanceHolder");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Counterparty");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Document");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "BusinessLine");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "AccountingAmount");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "ExchangeRate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Multiplicity");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Contract");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.AdvanceFlag");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.SettlementsAmount");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.ExchangeRate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Multiplicity");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.VATRate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "TaxKind");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "LoanContract");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.TypeOfAmount");
		
		PaymentAmount = PaymentDetails.Total("PaymentAmount");
		If PaymentAmount <> DocumentAmount Then
			MessageText = NStr("en = 'The document amount (%DocumentAmount% %CashCurrency%) is not equal to the sum of payment amounts in the payment details (%PaymentAmount% %CashCurrency%).'");
			MessageText = StrReplace(MessageText, "%DocumentAmount%", String(DocumentAmount));
			MessageText = StrReplace(MessageText, "%PaymentAmount%", String(PaymentAmount));
			MessageText = StrReplace(MessageText, "%CashCurrency%", String(Строка(CashCurrency)));
			DriveServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				,
				,
				"DocumentAmount",
				Cancel
			);
		EndIf;
	ElsIf OperationKind = Enums.OperationTypesPaymentReceipt.LoanRepaymentByEmployee Then
		
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Correspondence");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Counterparty");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Document");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "BusinessLine");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "AccountingAmount");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "ExchangeRate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Multiplicity");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Contract");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.AdvanceFlag");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.VATRate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "TaxKind");
				
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "AdvanceHolder");
		If AdvanceHolder.IsEmpty() Then
			MessageText = НСтр("en = 'The ""Employee"" field is required'");
			DriveServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				,
				,
				"AdvanceHolder",
				Cancel
			);
		EndIf;
		
		PaymentAmount = PaymentDetails.Total("PaymentAmount");
		If PaymentAmount <> DocumentAmount Then
			MessageText = NStr("en = 'The document amount (%DocumentAmount% %CashCurrency%) is not equal to the sum of payment amounts in the payment details (%PaymentAmount% %CashCurrency%).'");
			MessageText = StrReplace(MessageText, "%DocumentAmount%", String(DocumentAmount));
			MessageText = StrReplace(MessageText, "%PaymentAmount%", String(PaymentAmount));
			MessageText = StrReplace(MessageText, "%CashCurrency%", String(Строка(CashCurrency)));
			DriveServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				,
				,
				"DocumentAmount",
				Cancel
			);
		EndIf;
		
	ElsIf OperationKind = Enums.OperationTypesPaymentReceipt.LoanSettlements Then
		
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "AdvanceHolder");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Correspondence");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Document");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "BusinessLine");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "AccountingAmount");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "ExchangeRate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Multiplicity");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Contract");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.AdvanceFlag");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.SettlementsAmount");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.ExchangeRate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Multiplicity");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.VATRate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.TypeOfAmount");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "TaxKind");
	Else
		
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "AdvanceHolder");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Counterparty");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Document");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "AccountingAmount");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "ExchangeRate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Multiplicity");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Correspondence");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Contract");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.AdvanceFlag");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.SettlementsAmount");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.ExchangeRate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Multiplicity");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.VATRate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "LoanContract");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.TypeOfAmount");
		
	EndIf;
	
	// Bank charges
	If Not UseBankCharges Then
	
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "BankCharge");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "BankChargeItem");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "BankChargeAmount");
	
	EndIf;
	// End Bank charges
	
EndProcedure

// Procedure - event handler Posting object.
//
Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Initialization of document data
	Documents.PaymentReceipt.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Preparation of record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Registering in accounting sections
	DriveServer.ReflectCashAssets(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAdvanceHolders(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountsReceivable(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountsPayable(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectPaymentCalendar(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectInvoicesAndOrdersPayment(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectIncomeAndExpenses(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectTaxesSettlements(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectIncomeAndExpensesCashMethod(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectUnallocatedExpenses(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectIncomeAndExpensesRetained(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingJournalEntries(AdditionalProperties, RegisterRecords, Cancel);
	// Bank charges
	DriveServer.ReflectBankCharges(AdditionalProperties, RegisterRecords, Cancel);
	// End Bank charges
	DriveServer.ReflectMiscellaneousPayable(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectLoanSettlements(AdditionalProperties, RegisterRecords, Cancel);
	
	//VAT
	DriveServer.ReflectVATOutput(AdditionalProperties, RegisterRecords, Cancel);
	
	// Writing of record sets
	DriveServer.WriteRecordSets(ThisObject);
	
	If Not Cancel Then
		WorkWithVAT.SubordinatedTaxInvoiceControl(DocumentWriteMode.Posting, Ref, DeletionMark);
	EndIf;
	
	// Control of occurrence of a negative balance.
	Documents.PaymentReceipt.RunControl(Ref, AdditionalProperties, Cancel);
	
	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
EndProcedure

// Procedure - event handler UndoPosting object.
//
Procedure UndoPosting(Cancel)
	
	// Initialization of additional properties to undo document posting
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Preparation of record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Writing of record sets
	DriveServer.WriteRecordSets(ThisObject);
	
	If Not Cancel Then
		WorkWithVAT.SubordinatedTaxInvoiceControl(DocumentWriteMode.UndoPosting, Ref, DeletionMark);
	EndIf;
	
	// Control of occurrence of a negative balance.
	Documents.PaymentReceipt.RunControl(Ref, AdditionalProperties, Cancel, True);
	
EndProcedure

#EndRegion

#EndIf
