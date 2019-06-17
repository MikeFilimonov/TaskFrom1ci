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
		|	REFPRESENTATION(&Ref) AS Basis,
		|	VALUE(Enum.OperationTypesCashReceipt.FromCustomer) AS OperationKind,
		|	&Ref AS BasisDocument,
		|	DocumentTable.Company AS Company,
		|	DocumentTable.CashFlowItem AS Item,
		|	DocumentTable.PettyCash AS PettyCash,
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
		|WHERE
		|	DocumentTable.Ref = &Ref";
		
	Else
		
		Query.Text =
		"SELECT
		|	REFPRESENTATION(&Ref) AS Basis,
		|	VALUE(Enum.OperationTypesCashReceipt.FromCustomer) AS OperationKind,
		|	&Ref AS BasisDocument,
		|	DocumentTable.Company AS Company,
		|	DocumentTable.CashFlowItem AS Item,
		|	DocumentTable.PettyCash AS PettyCash,
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
	Query.SetParameter("Date", ?(ValueIsFilled(Date), Date, CurrentDate()));
	
	// Fill document header data.
	Query.Text = 
	"SELECT
	|	REFPRESENTATION(&Ref) AS Basis,
	|	VALUE(Enum.OperationTypesCashReceipt.Other) AS OperationKind,
	|	&Ref AS BasisDocument,
	|	DocumentTable.Company AS Company,
	|	VALUE(Enum.VATTaxationTypes.SubjectToVAT) AS VATTaxation,
	|	DocumentTable.CashFlowItem AS Item,
	|	DocumentTable.DocumentCurrency AS CashCurrency,
	|	DocumentTable.PettyCashPayee AS PettyCash,
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
		|	REFPRESENTATION(&Ref) AS Basis,
		|	VALUE(Enum.OperationTypesPaymentReceipt.FromCustomer) AS OperationKind,
		|	&Ref AS BasisDocument,
		|	DocumentHeader.Company AS Company,
		|	DocumentHeader.VATTaxation AS VATTaxation,
		|	DocumentHeader.DocumentCurrency AS CashCurrency,
		|	DocumentHeader.PettyCash AS PettyCash,
		|	DocumentHeader.Counterparty AS Counterparty,
		|	DocumentHeader.Contract AS Contract,
		|	TRUE AS AdvanceFlag,
		|	UNDEFINED AS Document,
		|	VALUE(Document.SalesOrder.EmptyRef) AS Order,
		|	VALUE(Document.Quote.EmptyRef) AS Quote,
		|	DocumentTable.VATRate AS VATRate,
		|	SettlementsExchangeRates.ExchangeRate AS ExchangeRate,
		|	SettlementsExchangeRates.Multiplicity AS Multiplicity,
		|	&Amount AS DocumentAmount,
		|	&Amount AS PaymentAmount,
		|	CAST(&Amount * CASE
		|			WHEN DocumentHeader.DocumentCurrency <> DocumentHeader.Contract.SettlementsCurrency
		|					AND SettlementsExchangeRates.ExchangeRate <> 0
		|					AND ExchangeRatesOfDocument.Multiplicity <> 0
		|				THEN ExchangeRatesOfDocument.ExchangeRate * SettlementsExchangeRates.Multiplicity / (ISNULL(SettlementsExchangeRates.ExchangeRate, 1) * ISNULL(ExchangeRatesOfDocument.Multiplicity, 1))
		|			ELSE 1
		|		END AS NUMBER(15, 2)) AS SettlementsAmount,
		|	CAST(&Amount * (1 - 1 / ((ISNULL(DocumentTable.VATRate.Rate, 0) + 100) / 100)) AS NUMBER(15, 2)) AS VATAmount
		|FROM
		|	Document.Quote AS DocumentHeader
		|		LEFT JOIN Document.Quote.Inventory AS DocumentTable
		|		ON DocumentHeader.Ref = DocumentTable.Ref
		|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&Date, ) AS SettlementsExchangeRates
		|		ON DocumentHeader.Contract.SettlementsCurrency = SettlementsExchangeRates.Currency
		|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&Date, ) AS ExchangeRatesOfDocument
		|		ON DocumentHeader.DocumentCurrency = ExchangeRatesOfDocument.Currency
		|WHERE
		|	DocumentHeader.Ref = &Ref
		|	AND ISNULL(DocumentTable.LineNumber, 1) = 1";
		
	ElsIf LineNumber = Undefined Then
		
		Query.SetParameter("Ref", FillingData);
		Query.SetParameter("Date", ?(ValueIsFilled(Date), Date, CurrentDate()));
		
		// Fill data of the document tabular sections.
		Query.Text =
		"SELECT
		|	REFPRESENTATION(&Ref) AS Basis,
		|	VALUE(Enum.OperationTypesCashReceipt.FromCustomer) AS OperationKind,
		|	&Ref AS BasisDocument,
		|	DocumentHeader.Company AS Company,
		|	DocumentHeader.VATTaxation AS VATTaxation,
		|	DocumentHeader.DocumentCurrency AS CashCurrency,
		|	DocumentHeader.PettyCash AS PettyCash,
		|	DocumentHeader.Counterparty AS Counterparty,
		|	DocumentHeader.Contract AS Contract,
		|	TRUE AS AdvanceFlag,
		|	UNDEFINED AS Document,
		|	VALUE(Document.SalesOrder.EmptyRef) AS Order,
		|	VALUE(Document.Quote.EmptyRef) AS Quote,
		|	DocumentTable.VATRate AS VATRate,
		|	SettlementsExchangeRates.ExchangeRate AS ExchangeRate,
		|	SettlementsExchangeRates.Multiplicity AS Multiplicity,
		|	SUM(DocumentTable.Total) AS DocumentAmount,
		|	SUM(DocumentTable.Total) AS PaymentAmount,
		|	SUM(CAST(DocumentTable.Total * CASE
		|				WHEN DocumentHeader.DocumentCurrency <> DocumentHeader.Contract.SettlementsCurrency
		|						AND SettlementsExchangeRates.ExchangeRate <> 0
		|						AND ExchangeRatesOfDocument.Multiplicity <> 0
		|					THEN ExchangeRatesOfDocument.ExchangeRate * SettlementsExchangeRates.Multiplicity / (ISNULL(SettlementsExchangeRates.ExchangeRate, 1) * ISNULL(ExchangeRatesOfDocument.Multiplicity, 1))
		|				ELSE 1
		|			END AS NUMBER(15, 2))) AS SettlementsAmount,
		|	SUM(CAST(DocumentTable.Total * (1 - 1 / ((ISNULL(DocumentTable.VATRate.Rate, 0) + 100) / 100)) AS NUMBER(15, 2))) AS VATAmount
		|FROM
		|	Document.Quote AS DocumentHeader
		|		LEFT JOIN Document.Quote.Inventory AS DocumentTable
		|		ON DocumentHeader.Ref = DocumentTable.Ref
		|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&Date, ) AS SettlementsExchangeRates
		|		ON DocumentHeader.Contract.SettlementsCurrency = SettlementsExchangeRates.Currency
		|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&Date, ) AS ExchangeRatesOfDocument
		|		ON DocumentHeader.DocumentCurrency = ExchangeRatesOfDocument.Currency
		|WHERE
		|	DocumentHeader.Ref = &Ref
		|
		|GROUP BY
		|	DocumentHeader.Company,
		|	DocumentHeader.VATTaxation,
		|	DocumentHeader.DocumentCurrency,
		|	DocumentHeader.PettyCash,
		|	DocumentHeader.Counterparty,
		|	DocumentHeader.Contract,
		|	DocumentTable.VATRate,
		|	SettlementsExchangeRates.ExchangeRate,
		|	SettlementsExchangeRates.Multiplicity";
		
	Else
	
		Query.SetParameter("Ref", FillingData.Basis);
		Query.SetParameter("LineNumber", LineNumber);
		Query.SetParameter("Date", ?(ValueIsFilled(Date), Date, CurrentDate()));
		
		// Fill document header data.
		Query.Text =
		"SELECT
		|	REFPRESENTATION(&Ref) AS Basis,
		|	VALUE(Enum.OperationTypesCashReceipt.FromCustomer) AS OperationKind,
		|	&Ref AS BasisDocument,
		|	DocumentTable.Ref.Company AS Company,
		|	DocumentTable.Ref.VATTaxation AS VATTaxation,
		|	DocumentTable.Ref.DocumentCurrency AS CashCurrency,
		|	DocumentTable.Ref.PettyCash AS PettyCash,
		|	DocumentTable.Ref.Counterparty AS Counterparty,
		|	DocumentTable.Ref.Contract AS Contract,
		|	TRUE AS AdvanceFlag,
		|	UNDEFINED AS Document,
		|	VALUE(Document.SalesOrder.EmptyRef) AS Order,
		|	VALUE(Document.Quote.EmptyRef) AS Quote,
		|	ISNULL(VATRatesDocumentsTable.VATRate, VATRates.VATRate) AS VATRate,
		|	SettlementsExchangeRates.ExchangeRate AS ExchangeRate,
		|	SettlementsExchangeRates.Multiplicity AS Multiplicity,
		|	DocumentTable.PaymentAmount + DocumentTable.PaymentVATAmount AS DocumentAmount,
		|	DocumentTable.PaymentAmount + DocumentTable.PaymentVATAmount AS PaymentAmount,
		|	CAST((DocumentTable.PaymentAmount + DocumentTable.PaymentVATAmount) * CASE
		|			WHEN DocumentTable.Ref.DocumentCurrency <> DocumentTable.Ref.Contract.SettlementsCurrency
		|					AND SettlementsExchangeRates.ExchangeRate <> 0
		|					AND ExchangeRatesOfDocument.Multiplicity <> 0
		|				THEN ExchangeRatesOfDocument.ExchangeRate * SettlementsExchangeRates.Multiplicity / (ISNULL(SettlementsExchangeRates.ExchangeRate, 1) * ISNULL(ExchangeRatesOfDocument.Multiplicity, 1))
		|			ELSE 1
		|		END AS NUMBER(15, 2)) AS SettlementsAmount,
		|	DocumentTable.PaymentVATAmount AS VATAmount
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
		|WHERE
		|	DocumentTable.Ref = &Ref
		|	AND DocumentTable.LineNumber = &LineNumber";
		
	EndIf;
	
	Selection = Query.Execute().Select();
	PaymentDetails.Clear();
	
	While Selection.Next() Do
		
		FillPropertyValues(ThisObject, Selection);
		NewRow = PaymentDetails.Add();
		FillPropertyValues(NewRow, Selection);
		
		If Not VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then
			FillVATRateByVATTaxation(NewRow);
		EndIf;
		
	EndDo;
	
	DocumentAmount = PaymentDetails.Total("PaymentAmount");
	
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
		|	REFPRESENTATION(&Ref) AS Basis,
		|	VALUE(Enum.OperationTypesPaymentReceipt.FromCustomer) AS OperationKind,
		|	&Ref AS BasisDocument,
		|	DocumentHeader.Company AS Company,
		|	DocumentHeader.VATTaxation AS VATTaxation,
		|	DocumentHeader.DocumentCurrency AS CashCurrency,
		|	DocumentHeader.PettyCash AS PettyCash,
		|	DocumentHeader.Counterparty AS Counterparty,
		|	DocumentHeader.Contract AS Contract,
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
		|	&Amount AS DocumentAmount,
		|	&Amount AS PaymentAmount,
		|	CAST(&Amount * CASE
		|			WHEN DocumentHeader.DocumentCurrency <> DocumentHeader.Contract.SettlementsCurrency
		|					AND SettlementsExchangeRates.ExchangeRate <> 0
		|					AND ExchangeRatesOfDocument.Multiplicity <> 0
		|				THEN ExchangeRatesOfDocument.ExchangeRate * SettlementsExchangeRates.Multiplicity / (ISNULL(SettlementsExchangeRates.ExchangeRate, 1) * ISNULL(ExchangeRatesOfDocument.Multiplicity, 1))
		|			ELSE 1
		|		END AS NUMBER(15, 2)) AS SettlementsAmount,
		|	CAST(&Amount * (1 - 1 / ((ISNULL(DocumentTable.VATRate.Rate, 0) + 100) / 100)) AS NUMBER(15, 2)) AS VATAmount
		|FROM
		|	Document.SalesOrder AS DocumentHeader
		|		LEFT JOIN Document.SalesOrder.Inventory AS DocumentTable
		|		ON DocumentHeader.Ref = DocumentTable.Ref
		|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&Date, ) AS SettlementsExchangeRates
		|		ON DocumentHeader.Contract.SettlementsCurrency = SettlementsExchangeRates.Currency
		|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&Date, ) AS ExchangeRatesOfDocument
		|		ON DocumentHeader.DocumentCurrency = ExchangeRatesOfDocument.Currency
		|WHERE
		|	DocumentHeader.Ref = &Ref
		|	AND ISNULL(DocumentTable.LineNumber, 1) = 1";
		
	ElsIf LineNumber = Undefined Then
		
		Query.SetParameter("Ref", FillingData);
		Query.SetParameter("Date", ?(ValueIsFilled(Date), Date, CurrentDate()));
		
		// Fill data of the document tabular sections.
		Query.Text =
		"SELECT
		|	REFPRESENTATION(&Ref) AS Basis,
		|	VALUE(Enum.OperationTypesCashReceipt.FromCustomer) AS OperationKind,
		|	&Ref AS BasisDocument,
		|	DocumentHeader.Company AS Company,
		|	DocumentHeader.VATTaxation AS VATTaxation,
		|	DocumentHeader.DocumentCurrency AS CashCurrency,
		|	DocumentHeader.PettyCash AS PettyCash,
		|	DocumentHeader.Counterparty AS Counterparty,
		|	DocumentHeader.Contract AS Contract,
		|	TRUE AS AdvanceFlag,
		|	CASE
		|		WHEN DocumentHeader.Counterparty.DoOperationsByOrders
		|			THEN &Ref
		|		ELSE VALUE(Document.SalesOrder.EmptyRef)
		|	END AS Order,
		|	NestedSelect.VATRate AS VATRate,
		|	ISNULL(NestedSelect.ExchangeRate, 1) AS ExchangeRate,
		|	ISNULL(NestedSelect.Multiplicity, 1) AS Multiplicity,
		|	SUM(NestedSelect.DocumentAmount) AS DocumentAmount,
		|	SUM(NestedSelect.PaymentAmount) AS PaymentAmount,
		|	SUM(NestedSelect.SettlementsAmount) AS SettlementsAmount,
		|	SUM(NestedSelect.VATAmount) AS VATAmount,
		|	UNDEFINED AS Document
		|FROM
		|	Document.SalesOrder AS DocumentHeader
		|		LEFT JOIN (SELECT
		|			&Ref AS BasisDocument,
		|			DocumentTable.VATRate AS VATRate,
		|			SettlementsExchangeRates.ExchangeRate AS ExchangeRate,
		|			SettlementsExchangeRates.Multiplicity AS Multiplicity,
		|			DocumentTable.Total AS DocumentAmount,
		|			DocumentTable.Total AS PaymentAmount,
		|			CAST(DocumentTable.Total * CASE
		|					WHEN DocumentTable.Ref.DocumentCurrency <> DocumentTable.Ref.Contract.SettlementsCurrency
		|							AND SettlementsExchangeRates.ExchangeRate <> 0
		|							AND ExchangeRatesOfDocument.Multiplicity <> 0
		|						THEN ExchangeRatesOfDocument.ExchangeRate * SettlementsExchangeRates.Multiplicity / (ISNULL(SettlementsExchangeRates.ExchangeRate, 1) * ISNULL(ExchangeRatesOfDocument.Multiplicity, 1))
		|					ELSE 1
		|				END AS NUMBER(15, 2)) AS SettlementsAmount,
		|			CAST(DocumentTable.Total * (1 - 1 / ((ISNULL(DocumentTable.VATRate.Rate, 0) + 100) / 100)) AS NUMBER(15, 2)) AS VATAmount
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
		|			SettlementsExchangeRates.ExchangeRate,
		|			SettlementsExchangeRates.Multiplicity,
		|			DocumentTable.Total,
		|			DocumentTable.Total,
		|			CAST(DocumentTable.Total * CASE
		|					WHEN DocumentTable.Ref.DocumentCurrency <> DocumentTable.Ref.Contract.SettlementsCurrency
		|							AND SettlementsExchangeRates.ExchangeRate <> 0
		|							AND ExchangeRatesOfDocument.Multiplicity <> 0
		|						THEN ExchangeRatesOfDocument.ExchangeRate * SettlementsExchangeRates.Multiplicity / (ISNULL(SettlementsExchangeRates.ExchangeRate, 1) * ISNULL(ExchangeRatesOfDocument.Multiplicity, 1))
		|					ELSE 1
		|				END AS NUMBER(15, 2)),
		|			CAST(DocumentTable.Total * (1 - 1 / ((ISNULL(DocumentTable.VATRate.Rate, 0) + 100) / 100)) AS NUMBER(15, 2))
		|		FROM
		|			Document.SalesOrder.Works AS DocumentTable
		|				LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&Date, ) AS SettlementsExchangeRates
		|				ON DocumentTable.Ref.Contract.SettlementsCurrency = SettlementsExchangeRates.Currency
		|				LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&Date, ) AS ExchangeRatesOfDocument
		|				ON DocumentTable.Ref.DocumentCurrency = ExchangeRatesOfDocument.Currency
		|		WHERE
		|			DocumentTable.Ref = &Ref) AS NestedSelect
		|		ON DocumentHeader.Ref = NestedSelect.BasisDocument
		|WHERE
		|	DocumentHeader.Ref = &Ref
		|
		|GROUP BY
		|	DocumentHeader.Company,
		|	DocumentHeader.VATTaxation,
		|	DocumentHeader.DocumentCurrency,
		|	DocumentHeader.PettyCash,
		|	DocumentHeader.Counterparty,
		|	DocumentHeader.Contract,
		|	NestedSelect.VATRate,
		|	NestedSelect.ExchangeRate,
		|	NestedSelect.Multiplicity,
		|	CASE
		|		WHEN DocumentHeader.Counterparty.DoOperationsByOrders
		|			THEN &Ref
		|		ELSE VALUE(Document.SalesOrder.EmptyRef)
		|	END";
		
	Else
	
		Query.SetParameter("Ref", FillingData.Basis);
		Query.SetParameter("LineNumber", LineNumber);
		Query.SetParameter("Date", ?(ValueIsFilled(Date), Date, CurrentDate()));
		
		// Fill document header data.
		Query.Text =
		"SELECT
		|	REFPRESENTATION(&Ref) AS Basis,
		|	VALUE(Enum.OperationTypesCashReceipt.FromCustomer) AS OperationKind,
		|	&Ref AS BasisDocument,
		|	DocumentTable.Ref.Company AS Company,
		|	DocumentTable.Ref.VATTaxation AS VATTaxation,
		|	DocumentTable.Ref.DocumentCurrency AS CashCurrency,
		|	DocumentTable.Ref.PettyCash AS PettyCash,
		|	DocumentTable.Ref.Counterparty AS Counterparty,
		|	DocumentTable.Ref.Contract AS Contract,
		|	TRUE AS AdvanceFlag,
		|	ISNULL(VATRatesDocumentsTable.VATRate, VATRates.VATRate) AS VATRate,
		|	SettlementsExchangeRates.ExchangeRate AS ExchangeRate,
		|	SettlementsExchangeRates.Multiplicity AS Multiplicity,
		|	DocumentTable.PaymentAmount AS DocumentAmount,
		|	DocumentTable.PaymentAmount AS PaymentAmount,
		|	CAST(DocumentTable.PaymentAmount * CASE
		|			WHEN DocumentTable.Ref.DocumentCurrency <> DocumentTable.Ref.Contract.SettlementsCurrency
		|					AND SettlementsExchangeRates.ExchangeRate <> 0
		|					AND ExchangeRatesOfDocument.Multiplicity <> 0
		|				THEN ExchangeRatesOfDocument.ExchangeRate * SettlementsExchangeRates.Multiplicity / (ISNULL(SettlementsExchangeRates.ExchangeRate, 1) * ISNULL(ExchangeRatesOfDocument.Multiplicity, 1))
		|			ELSE 1
		|		END AS NUMBER(15, 2)) AS SettlementsAmount,
		|	CAST(DocumentTable.PaymentAmount * (1 - 1 / ((ISNULL(VATRates.VATRate.Rate, 0) + 100) / 100)) AS NUMBER(15, 2)) AS VATAmount,
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
		|WHERE
		|	DocumentTable.Ref = &Ref
		|	AND DocumentTable.LineNumber = &LineNumber";
		
	EndIf;
	
	Selection = Query.Execute().Select();
	PaymentDetails.Clear();
	
	While Selection.Next() Do
		
		FillPropertyValues(ThisObject, Selection);
		NewRow = PaymentDetails.Add();
		FillPropertyValues(NewRow, Selection);
		
		If Not VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then
			FillVATRateByVATTaxation(NewRow);
		EndIf;
		
	EndDo;
	
	DocumentAmount = PaymentDetails.Total("PaymentAmount");
	
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
		|	WorkOrder.DocumentCurrency AS DocumentCurrency,
		|	WorkOrder.PettyCash AS PettyCash,
		|	WorkOrder.Counterparty AS Counterparty,
		|	WorkOrder.Contract AS Contract,
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
		|	REFPRESENTATION(WorkOrder.Ref) AS Basis,
		|	WorkOrder.Ref AS Ref,
		|	WorkOrder.Company AS Company,
		|	WorkOrder.VATTaxation AS VATTaxation,
		|	WorkOrder.DocumentCurrency AS DocumentCurrency,
		|	WorkOrder.PettyCash AS PettyCash,
		|	WorkOrder.Counterparty AS Counterparty,
		|	WorkOrder.Contract AS Contract,
		|	ISNULL(WorkOrderStatuses.OrderStatus, VALUE(Enum.OrderStatuses.EmptyRef)) AS OrderStatus,
		|	Counterparties.DoOperationsByDocuments AS DoOperationsByDocuments,
		|	CounterpartyContracts.SettlementsCurrency AS SettlementsCurrency
		|INTO WorkOrderWithStatus
		|FROM
		|	WorkOrderTable AS WorkOrder
		|		INNER JOIN Catalog.Counterparties AS Counterparties
		|		ON WorkOrder.Counterparty = Counterparties.Ref
		|		INNER JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
		|		ON WorkOrder.Contract = CounterpartyContracts.Ref
		|		LEFT JOIN Catalog.WorkOrderStatuses AS WorkOrderStatuses
		|		ON WorkOrder.OrderState = WorkOrderStatuses.Ref
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	WorkOrder.Basis AS Basis,
		|	VALUE(Enum.OperationTypesCashReceipt.FromCustomer) AS OperationKind,
		|	WorkOrder.Ref AS BasisDocument,
		|	WorkOrder.Company AS Company,
		|	WorkOrder.VATTaxation AS VATTaxation,
		|	WorkOrder.DocumentCurrency AS CashCurrency,
		|	WorkOrder.PettyCash AS PettyCash,
		|	WorkOrder.Counterparty AS Counterparty,
		|	WorkOrder.Contract AS Contract,
		|	CASE
		|		WHEN WorkOrder.OrderStatus = VALUE(Enum.OrderStatuses.Completed)
		|			THEN FALSE
		|		ELSE TRUE
		|	END AS AdvanceFlag,
		|	CASE
		|		WHEN WorkOrder.OrderStatus = VALUE(Enum.OrderStatuses.Completed)
		|				AND WorkOrder.DoOperationsByDocuments
		|			THEN WorkOrder.Ref
		|		ELSE UNDEFINED
		|	END AS Document,
		|	VALUE(Document.SalesOrder.EmptyRef) AS Order,
		|	WorkOrderInventory.VATRate AS VATRate,
		|	SettlementsExchangeRates.ExchangeRate AS ExchangeRate,
		|	SettlementsExchangeRates.Multiplicity AS Multiplicity,
		|	&Amount AS DocumentAmount,
		|	&Amount AS PaymentAmount,
		|	CAST(&Amount * CASE
		|			WHEN WorkOrder.DocumentCurrency <> WorkOrder.SettlementsCurrency
		|					AND SettlementsExchangeRates.ExchangeRate <> 0
		|					AND ExchangeRatesOfDocument.Multiplicity <> 0
		|				THEN ExchangeRatesOfDocument.ExchangeRate * SettlementsExchangeRates.Multiplicity / (ISNULL(SettlementsExchangeRates.ExchangeRate, 1) * ISNULL(ExchangeRatesOfDocument.Multiplicity, 1))
		|			ELSE 1
		|		END AS NUMBER(15, 2)) AS SettlementsAmount,
		|	CAST(&Amount * (1 - 1 / ((ISNULL(WorkOrderInventory.VATRate.Rate, 0) + 100) / 100)) AS NUMBER(15, 2)) AS VATAmount
		|FROM
		|	WorkOrderWithStatus AS WorkOrder
		|		LEFT JOIN Document.WorkOrder.Inventory AS WorkOrderInventory
		|		ON WorkOrder.Ref = WorkOrderInventory.Ref
		|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&Date, ) AS SettlementsExchangeRates
		|		ON WorkOrder.SettlementsCurrency = SettlementsExchangeRates.Currency
		|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&Date, ) AS ExchangeRatesOfDocument
		|		ON WorkOrder.DocumentCurrency = ExchangeRatesOfDocument.Currency
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
		|	WorkOrder.DocumentCurrency AS DocumentCurrency,
		|	WorkOrder.PettyCash AS PettyCash,
		|	WorkOrder.Counterparty AS Counterparty,
		|	WorkOrder.Contract AS Contract,
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
		|	WorkOrderTable.Ref AS Ref,
		|	WorkOrderTable.Company AS Company,
		|	WorkOrderTable.VATTaxation AS VATTaxation,
		|	WorkOrderTable.DocumentCurrency AS DocumentCurrency,
		|	WorkOrderTable.PettyCash AS PettyCash,
		|	WorkOrderTable.Counterparty AS Counterparty,
		|	WorkOrderTable.Contract AS Contract,
		|	Counterparties.DoOperationsByDocuments AS DoOperationsByDocuments,
		|	CounterpartyContracts.SettlementsCurrency AS SettlementsCurrency,
		|	ISNULL(WorkOrderStatuses.OrderStatus, VALUE(Enum.OrderStatuses.EmptyRef)) AS OrderStatus
		|INTO WorkOrderWithStatus
		|FROM
		|	WorkOrderTable AS WorkOrderTable
		|		INNER JOIN Catalog.Counterparties AS Counterparties
		|		ON WorkOrderTable.Counterparty = Counterparties.Ref
		|		INNER JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
		|		ON WorkOrderTable.Contract = CounterpartyContracts.Ref
		|		LEFT JOIN Catalog.WorkOrderStatuses AS WorkOrderStatuses
		|		ON WorkOrderTable.OrderState = WorkOrderStatuses.Ref
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	WorkOrder.Ref AS Ref,
		|	WorkOrder.Company AS Company,
		|	WorkOrder.VATTaxation AS VATTaxation,
		|	WorkOrder.DocumentCurrency AS DocumentCurrency,
		|	WorkOrder.PettyCash AS PettyCash,
		|	WorkOrder.Counterparty AS Counterparty,
		|	WorkOrder.Contract AS Contract,
		|	WorkOrderInventory.VATRate AS VATRate,
		|	WorkOrderInventory.Total AS DocumentAmount,
		|	WorkOrderInventory.Total AS PaymentAmount,
		|	CAST(WorkOrderInventory.Total * (1 - 1 / ((ISNULL(WorkOrderInventory.VATRate.Rate, 0) + 100) / 100)) AS NUMBER(15, 2)) AS VATAmount,
		|	CASE
		|		WHEN WorkOrder.OrderStatus = VALUE(Enum.OrderStatuses.Completed)
		|			THEN FALSE
		|		ELSE TRUE
		|	END AS AdvanceFlag,
		|	CASE
		|		WHEN WorkOrder.OrderStatus = VALUE(Enum.OrderStatuses.Completed)
		|				AND WorkOrder.DoOperationsByDocuments
		|			THEN WorkOrder.Ref
		|		ELSE UNDEFINED
		|	END AS Document,
		|	WorkOrder.SettlementsCurrency AS SettlementsCurrency
		|INTO WorkOrderWithAmounts
		|FROM
		|	Document.WorkOrder.Inventory AS WorkOrderInventory
		|		INNER JOIN WorkOrderWithStatus AS WorkOrder
		|		ON WorkOrderInventory.Ref = WorkOrder.Ref
		|
		|UNION ALL
		|
		|SELECT
		|	WorkOrder.Ref,
		|	WorkOrder.Company,
		|	WorkOrder.VATTaxation,
		|	WorkOrder.DocumentCurrency,
		|	WorkOrder.PettyCash,
		|	WorkOrder.Counterparty,
		|	WorkOrder.Contract,
		|	WorkOrderWorks.VATRate,
		|	WorkOrderWorks.Total,
		|	WorkOrderWorks.Total,
		|	CAST(WorkOrderWorks.Total * (1 - 1 / ((ISNULL(WorkOrderWorks.VATRate.Rate, 0) + 100) / 100)) AS NUMBER(15, 2)),
		|	CASE
		|		WHEN WorkOrder.OrderStatus = VALUE(Enum.OrderStatuses.Completed)
		|			THEN FALSE
		|		ELSE TRUE
		|	END,
		|	CASE
		|		WHEN WorkOrder.OrderStatus = VALUE(Enum.OrderStatuses.Completed)
		|				AND WorkOrder.DoOperationsByDocuments
		|			THEN WorkOrder.Ref
		|		ELSE UNDEFINED
		|	END,
		|	WorkOrder.SettlementsCurrency
		|FROM
		|	Document.WorkOrder.Works AS WorkOrderWorks
		|		INNER JOIN WorkOrderWithStatus AS WorkOrder
		|		ON WorkOrderWorks.Ref = WorkOrder.Ref
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	REFPRESENTATION(WorkOrderWithAmounts.Ref) AS Basis,
		|	VALUE(Enum.OperationTypesCashReceipt.FromCustomer) AS OperationKind,
		|	WorkOrderWithAmounts.Ref AS BasisDocument,
		|	WorkOrderWithAmounts.Company AS Company,
		|	WorkOrderWithAmounts.VATTaxation AS VATTaxation,
		|	WorkOrderWithAmounts.DocumentCurrency AS CashCurrency,
		|	WorkOrderWithAmounts.PettyCash AS PettyCash,
		|	WorkOrderWithAmounts.Counterparty AS Counterparty,
		|	WorkOrderWithAmounts.Contract AS Contract,
		|	VALUE(Document.SalesOrder.EmptyRef) AS Order,
		|	WorkOrderWithAmounts.VATRate AS VATRate,
		|	MAX(ISNULL(SettlementsExchangeRates.ExchangeRate, 1)) AS ExchangeRate,
		|	MAX(ISNULL(SettlementsExchangeRates.Multiplicity, 1)) AS Multiplicity,
		|	SUM(WorkOrderWithAmounts.DocumentAmount) AS DocumentAmount,
		|	SUM(WorkOrderWithAmounts.PaymentAmount) AS PaymentAmount,
		|	SUM(CAST(WorkOrderWithAmounts.DocumentAmount * CASE
		|				WHEN WorkOrderWithAmounts.DocumentCurrency <> WorkOrderWithAmounts.SettlementsCurrency
		|						AND ISNULL(SettlementsExchangeRates.ExchangeRate, 1) <> 0
		|						AND ISNULL(ExchangeRatesOfDocument.Multiplicity, 1) <> 0
		|					THEN ISNULL(ExchangeRatesOfDocument.ExchangeRate, 1) * ISNULL(SettlementsExchangeRates.Multiplicity, 1) / (ISNULL(SettlementsExchangeRates.ExchangeRate, 1) * ISNULL(ExchangeRatesOfDocument.Multiplicity, 1))
		|				ELSE 1
		|			END AS NUMBER(15, 2))) AS SettlementsAmount,
		|	SUM(WorkOrderWithAmounts.VATAmount) AS VATAmount,
		|	WorkOrderWithAmounts.AdvanceFlag AS AdvanceFlag,
		|	WorkOrderWithAmounts.Document AS Document
		|FROM
		|	WorkOrderWithAmounts AS WorkOrderWithAmounts
		|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&Date, ) AS SettlementsExchangeRates
		|		ON WorkOrderWithAmounts.SettlementsCurrency = SettlementsExchangeRates.Currency
		|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&Date, ) AS ExchangeRatesOfDocument
		|		ON WorkOrderWithAmounts.DocumentCurrency = ExchangeRatesOfDocument.Currency
		|
		|GROUP BY
		|	WorkOrderWithAmounts.Ref,
		|	WorkOrderWithAmounts.Company,
		|	WorkOrderWithAmounts.VATTaxation,
		|	WorkOrderWithAmounts.DocumentCurrency,
		|	WorkOrderWithAmounts.PettyCash,
		|	WorkOrderWithAmounts.Counterparty,
		|	WorkOrderWithAmounts.Contract,
		|	WorkOrderWithAmounts.VATRate,
		|	WorkOrderWithAmounts.AdvanceFlag,
		|	WorkOrderWithAmounts.Document";
		
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
		|	WorkOrder.DocumentCurrency AS DocumentCurrency,
		|	WorkOrder.PettyCash AS PettyCash,
		|	WorkOrder.Counterparty AS Counterparty,
		|	WorkOrder.Contract AS Contract,
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
		|	WorkOrderTable.Ref AS Ref,
		|	WorkOrderTable.Company AS Company,
		|	WorkOrderTable.VATTaxation AS VATTaxation,
		|	WorkOrderTable.DocumentCurrency AS DocumentCurrency,
		|	WorkOrderTable.PettyCash AS PettyCash,
		|	WorkOrderTable.Counterparty AS Counterparty,
		|	WorkOrderTable.Contract AS Contract,
		|	Counterparties.DoOperationsByDocuments AS DoOperationsByDocuments,
		|	CounterpartyContracts.SettlementsCurrency AS SettlementsCurrency,
		|	ISNULL(WorkOrderStatuses.OrderStatus, VALUE(Enum.OrderStatuses.EmptyRef)) AS OrderStatus
		|INTO WorkOrderWithStatus
		|FROM
		|	WorkOrderTable AS WorkOrderTable
		|		INNER JOIN Catalog.Counterparties AS Counterparties
		|		ON WorkOrderTable.Counterparty = Counterparties.Ref
		|		INNER JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
		|		ON WorkOrderTable.Contract = CounterpartyContracts.Ref
		|		LEFT JOIN Catalog.WorkOrderStatuses AS WorkOrderStatuses
		|		ON WorkOrderTable.OrderState = WorkOrderStatuses.Ref
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
		|	WorkOrderWithStatus.PettyCash AS PettyCash,
		|	WorkOrderWithStatus.Counterparty AS Counterparty,
		|	WorkOrderWithStatus.Contract AS Contract,
		|	WorkOrderWithStatus.DoOperationsByDocuments AS DoOperationsByDocuments,
		|	WorkOrderWithStatus.SettlementsCurrency AS SettlementsCurrency,
		|	WorkOrderWithStatus.OrderStatus AS OrderStatus,
		|	ISNULL(WorkOrderFirstVATRate.VATRate, &VATRate) AS VATRate
		|INTO WorkOrderTableWithVAT
		|FROM
		|	WorkOrderWithStatus AS WorkOrderWithStatus
		|		LEFT JOIN WorkOrderFirstVATRate AS WorkOrderFirstVATRate
		|		ON WorkOrderWithStatus.Ref = WorkOrderFirstVATRate.Ref
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	REFPRESENTATION(WorkOrderTableWithVAT.Ref) AS Basis,
		|	VALUE(Enum.OperationTypesCashReceipt.FromCustomer) AS OperationKind,
		|	WorkOrderTableWithVAT.Ref AS BasisDocument,
		|	WorkOrderTableWithVAT.Company AS Company,
		|	WorkOrderTableWithVAT.VATTaxation AS VATTaxation,
		|	WorkOrderTableWithVAT.DocumentCurrency AS CashCurrency,
		|	WorkOrderTableWithVAT.PettyCash AS PettyCash,
		|	WorkOrderTableWithVAT.Counterparty AS Counterparty,
		|	WorkOrderTableWithVAT.Contract AS Contract,
		|	WorkOrderTableWithVAT.VATRate AS VATRate,
		|	SettlementsExchangeRates.ExchangeRate AS ExchangeRate,
		|	SettlementsExchangeRates.Multiplicity AS Multiplicity,
		|	WorkOrderPaymentCalendar.PaymentAmount AS DocumentAmount,
		|	WorkOrderPaymentCalendar.PaymentAmount AS PaymentAmount,
		|	CAST(WorkOrderPaymentCalendar.PaymentAmount * CASE
		|			WHEN WorkOrderTableWithVAT.DocumentCurrency <> WorkOrderTableWithVAT.SettlementsCurrency
		|					AND SettlementsExchangeRates.ExchangeRate <> 0
		|					AND ExchangeRatesOfDocument.Multiplicity <> 0
		|				THEN ExchangeRatesOfDocument.ExchangeRate * SettlementsExchangeRates.Multiplicity / (ISNULL(SettlementsExchangeRates.ExchangeRate, 1) * ISNULL(ExchangeRatesOfDocument.Multiplicity, 1))
		|			ELSE 1
		|		END AS NUMBER(15, 2)) AS SettlementsAmount,
		|	CAST(WorkOrderPaymentCalendar.PaymentAmount * (1 - 1 / ((WorkOrderTableWithVAT.VATRate.Rate + 100) / 100)) AS NUMBER(15, 2)) AS VATAmount,
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
		|		ON (SettlementsExchangeRates.Currency = WorkOrderTableWithVAT.SettlementsCurrency)
		|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&Date, ) AS ExchangeRatesOfDocument
		|		ON (ExchangeRatesOfDocument.Currency = WorkOrderTableWithVAT.DocumentCurrency)
		|WHERE
		|	WorkOrderPaymentCalendar.LineNumber = &LineNumber";
		
	EndIf;
	
	Selection = Query.Execute().Select();
	PaymentDetails.Clear();
	
	While Selection.Next() Do
		
		FillPropertyValues(ThisObject, Selection);
		NewRow = PaymentDetails.Add();
		FillPropertyValues(NewRow, Selection);
		
		If Not VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then
			FillVATRateByVATTaxation(NewRow);
		EndIf;
		
	EndDo;
	
	DocumentAmount = PaymentDetails.Total("PaymentAmount");
	
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
	
	Query.Text =
	"SELECT
	|	REFPRESENTATION(&Ref) AS Basis,
	|	VALUE(Enum.OperationTypesCashReceipt.FromCustomer) AS OperationKind,
	|	&Date AS Date,
	|	&Ref AS BasisDocument,
	|	DocumentHeader.Company AS Company,
	|	DocumentHeader.VATTaxation AS VATTaxation,
	|	DocumentHeader.DocumentCurrency AS CashCurrency,
	|	DocumentHeader.PettyCash AS PettyCash,
	|	DocumentHeader.Counterparty AS Counterparty,
	|	DocumentHeader.Contract AS Contract,
	|	TRUE AS AdvanceFlag,
	|	NestedSelect.VATRate AS VATRate,
	|	ISNULL(SettlementsExchangeRates.ExchangeRate, 1) AS ExchangeRate,
	|	ISNULL(SettlementsExchangeRates.Multiplicity, 1) AS Multiplicity,
	|	InvoicesAndOrdersPaymentTurnovers.AmountTurnover - InvoicesAndOrdersPaymentTurnovers.PaymentAmountTurnover - InvoicesAndOrdersPaymentTurnovers.AdvanceAmountTurnover AS DocumentAmount,
	|	InvoicesAndOrdersPaymentTurnovers.AmountTurnover - InvoicesAndOrdersPaymentTurnovers.PaymentAmountTurnover - InvoicesAndOrdersPaymentTurnovers.AdvanceAmountTurnover AS PaymentAmount,
	|	CAST((InvoicesAndOrdersPaymentTurnovers.AmountTurnover - InvoicesAndOrdersPaymentTurnovers.PaymentAmountTurnover - InvoicesAndOrdersPaymentTurnovers.AdvanceAmountTurnover) * CASE
	|			WHEN DocumentHeader.DocumentCurrency <> DocumentHeader.Contract.SettlementsCurrency
	|					AND SettlementsExchangeRates.ExchangeRate <> 0
	|					AND ExchangeRatesOfDocument.Multiplicity <> 0
	|				THEN ExchangeRatesOfDocument.ExchangeRate * SettlementsExchangeRates.Multiplicity / (ISNULL(SettlementsExchangeRates.ExchangeRate, 1) * ISNULL(ExchangeRatesOfDocument.Multiplicity, 1))
	|			ELSE 1
	|		END AS NUMBER(15, 2)) AS SettlementsAmount,
	|	CAST((InvoicesAndOrdersPaymentTurnovers.AmountTurnover - InvoicesAndOrdersPaymentTurnovers.PaymentAmountTurnover - InvoicesAndOrdersPaymentTurnovers.AdvanceAmountTurnover) * (1 - 1 / ((ISNULL(NestedSelect.VATRate.Rate, 0) + 100) / 100)) AS NUMBER(15, 2)) AS VATAmount,
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
	|WHERE
	|	DocumentHeader.Ref = &Ref";
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		
		FillPropertyValues(ThisObject, Selection);
		NewRow = PaymentDetails.Add();
		FillPropertyValues(NewRow, Selection);
		
		If Not VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then
			FillVATRateByVATTaxation(NewRow);
		EndIf;
		
	EndDo;
	
	DocumentAmount = PaymentDetails.Total("PaymentAmount");
	
EndProcedure

// Procedure of filling the document on the basis.
//
// Parameters:
// FillingData - Structure - Data on filling the document.
//	
Procedure FillBySalesInvoice(FillingData)
	
	Query = New Query;
	
	Query.SetParameter("Ref", FillingData);
	Query.SetParameter("Date", ?(ValueIsFilled(Date), Date, CurrentDate()));
	
	Query.Text =
	"SELECT
	|	VALUE(Enum.OperationTypesCashReceipt.FromCustomer) AS OperationKind,
	|	VALUE(Catalog.CashFlowItems.PaymentFromCustomers) AS Item,
	|	&Ref AS BasisDocument,
	|	DocumentHeader.Company AS Company,
	|	DocumentHeader.VATTaxation AS VATTaxation,
	|	PRESENTATION(DocumentHeader.Counterparty) AS AcceptedFrom,
	|	DocumentHeader.Company.PettyCashByDefault AS PettyCash,
	|	REFPRESENTATION(&Ref) AS Basis,
	|	DocumentHeader.Counterparty AS Counterparty,
	|	DocumentHeader.DocumentCurrency AS CashCurrency,
	|	CASE
	|		WHEN DocumentHeader.Counterparty.DoOperationsByOrders
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
	|		ON DocumentHeader.Contract.SettlementsCurrency = SettlementsExchangeRatesSliceLast.Currency,
	|	Constant.FunctionalCurrency AS ConstantNationalCurrency
	|WHERE
	|	DocumentHeader.Ref = &Ref
	|
	|GROUP BY
	|	DocumentHeader.Company,
	|	DocumentHeader.VATTaxation,
	|	DocumentHeader.Company.PettyCashByDefault,
	|	DocumentHeader.Counterparty,
	|	DocumentHeader.DocumentCurrency,
	|	DocumentTable.Order,
	|	DocumentHeader.Contract,
	|	DocumentTable.VATRate,
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
	|	END,
	|	CASE
	|		WHEN DocumentHeader.Counterparty.DoOperationsByOrders
	|			THEN DocumentTable.Order
	|		ELSE VALUE(Document.SalesOrder.EmptyRef)
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
	
EndProcedure

// Procedure of filling the document on the basis.
//
// Parameters:
// FillingData - Structure - Data on filling the document.
//	
Procedure FillByFixedAssetSale(FillingData)
	
	Query = New Query;
	
	Query.SetParameter("Ref", FillingData);
	Query.SetParameter("Date", ?(ValueIsFilled(Date), Date, CurrentDate()));
	
	Query.Text =
	"SELECT
	|	VALUE(Enum.OperationTypesCashReceipt.FromCustomer) AS OperationKind,
	|	&Ref AS BasisDocument,
	|	DocumentHeader.Company AS Company,
	|	DocumentHeader.VATTaxation AS VATTaxation,
	|	PRESENTATION(DocumentHeader.Counterparty) AS AcceptedFrom,
	|	DocumentHeader.Company.PettyCashByDefault AS PettyCash,
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
	|		ON DocumentHeader.Contract.SettlementsCurrency = SettlementsExchangeRatesSliceLast.Currency,
	|	Constant.FunctionalCurrency AS ConstantNationalCurrency
	|WHERE
	|	DocumentHeader.Ref = &Ref
	|
	|GROUP BY
	|	DocumentHeader.Company,
	|	DocumentHeader.VATTaxation,
	|	DocumentHeader.Company.PettyCashByDefault,
	|	DocumentHeader.Counterparty,
	|	DocumentHeader.DocumentCurrency,
	|	DocumentHeader.Contract,
	|	DocumentTable.VATRate,
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

// Procedure of filling the document on the basis.
//
// Parameters:
// FillingData - Structure - Data on filling the document.
//	
Procedure FillByShiftClosure(FillingData)
	
	Query = New Query;
	
	Query.SetParameter("Ref", FillingData);
	
	Query.Text =
	"SELECT
	|	DocumentHeader.Company AS Company,
	|	DocumentHeader.CashCR AS CashCR,
	|	DocumentHeader.Item AS Item,
	|	DocumentHeader.VATTaxation AS VATTaxation,
	|	DocumentHeader.DocumentCurrency AS DocumentCurrency,
	|	DocumentHeader.Ref AS Ref
	|INTO TT_DocumentHeader
	|FROM
	|	Document.ShiftClosure AS DocumentHeader
	|WHERE
	|	DocumentHeader.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	CashAccounts.Ref AS PettyCash
	|INTO TT_PettyCash
	|FROM
	|	TT_DocumentHeader AS TT_DocumentHeader
	|		INNER JOIN Catalog.CashAccounts AS CashAccounts
	|		ON TT_DocumentHeader.DocumentCurrency = CashAccounts.CurrencyByDefault
	|WHERE
	|	NOT CashAccounts.DeletionMark
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	VALUE(Enum.OperationTypesCashReceipt.RetailIncome) AS OperationKind,
	|	SUM(ISNULL(DocumentTable.Total, 0)) AS PaymentAmount,
	|	DocumentTable.VATRate AS VATRate,
	|	SUM(ISNULL(DocumentTable.VATAmount, 0)) AS VATAmount,
	|	REFPRESENTATION(&Ref) AS Basis,
	|	DocumentHeader.Company AS Company,
	|	DocumentHeader.CashCR AS CashCR,
	|	DocumentHeader.Item AS Item,
	|	DocumentHeader.VATTaxation AS VATTaxation,
	|	DocumentHeader.DocumentCurrency AS CashCurrency,
	|	DocumentHeader.Ref AS BasisDocument,
	|	TT_PettyCash.PettyCash AS PettyCash
	|FROM
	|	TT_DocumentHeader AS DocumentHeader
	|		LEFT JOIN Document.ShiftClosure.Inventory AS DocumentTable
	|		ON DocumentHeader.Ref = DocumentTable.Ref,
	|	TT_PettyCash AS TT_PettyCash
	|
	|GROUP BY
	|	DocumentTable.VATRate,
	|	DocumentHeader.Ref,
	|	DocumentHeader.Company,
	|	DocumentHeader.CashCR,
	|	DocumentHeader.Item,
	|	DocumentHeader.VATTaxation,
	|	DocumentHeader.DocumentCurrency,
	|	TT_PettyCash.PettyCash";
	
	QueryResult = Query.Execute();
	
	AmountLeftToDistribute = FillingData.PaymentWithPaymentCards.Total("Amount");
	
	If Not QueryResult.IsEmpty() Then
		
		Selection = QueryResult.Select();
		Selection.Next();
		FillPropertyValues(ThisObject, Selection);
		PaymentDetails.Clear();
		
		If Selection.PaymentAmount - AmountLeftToDistribute > 0 Then
			NewRow = PaymentDetails.Add();
			FillPropertyValues(NewRow, Selection);
			NewRow.PaymentAmount = Selection.PaymentAmount - AmountLeftToDistribute;
			NewRow.VATAmount = NewRow.PaymentAmount - (NewRow.PaymentAmount) / ((NewRow.VATRate.Rate + 100) / 100);
			DocumentAmount = Selection.PaymentAmount - AmountLeftToDistribute;
			AmountLeftToDistribute = 0;
		Else
			AmountLeftToDistribute = AmountLeftToDistribute - Selection.PaymentAmount;
		EndIf;
		
		While Selection.Next() Do
			If Selection.PaymentAmount - AmountLeftToDistribute > 0 Then
				NewRow = PaymentDetails.Add();
				FillPropertyValues(NewRow, Selection);
				NewRow.PaymentAmount = Selection.PaymentAmount - AmountLeftToDistribute;
				NewRow.VATAmount = NewRow.PaymentAmount - (NewRow.PaymentAmount) / ((NewRow.VATRate.Rate + 100) / 100);
				DocumentAmount = DocumentAmount + Selection.PaymentAmount - AmountLeftToDistribute;
				AmountLeftToDistribute = 0;
			Else
				AmountLeftToDistribute = AmountLeftToDistribute - Selection.PaymentAmount;
			EndIf;
		EndDo;
		
		If PaymentDetails.Count() = 0 Then
			PaymentDetails.Add();
		EndIf;
		
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
	
	If OperationKind = Enums.OperationTypesCashReceipt.FromCustomer AND PaymentDetails.Count() > 0 Then
		
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

#EndRegion

#Region EventHandlers

// Procedure - handler of the OnCopy event.
//
Procedure OnCopy(CopiedObject)
	
	SalesSlipNumber = "";
	
EndProcedure

// Procedure - event handler BeforeWrite object.
//
Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	AdditionalProperties.Insert("WriteMode", WriteMode);
	
	If Not Constants.UseSeveralLinesOfBusiness.Get() Then
		
		If OperationKind = Enums.OperationTypesCashReceipt.RetailIncomeEarningAccounting Then
			
			BusinessLine = Catalogs.LinesOfBusiness.MainLine;
			
		EndIf;
		
	EndIf;
	
	For Each TSRow In PaymentDetails Do
		If ValueIsFilled(Counterparty)
		AND Not Counterparty.DoOperationsByContracts
		AND Not ValueIsFilled(TSRow.Contract) Then
			TSRow.Contract = Counterparty.ContractByDefault;
		EndIf;
		
		// Miscellaneous payable
		If (OperationKind = Enums.OperationTypesCashReceipt.OtherSettlements)
			AND TSRow.VATRate.IsEmpty() Then
			TSRow.VATRate	= Catalogs.VATRates.Exempt;
			TSRow.VATAmount	= 0;
		EndIf;
		// End miscellaneous payable
	EndDo;
	
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

// Procedure - event handler FillingProcessor object.
//
Procedure Filling(FillingData, StandardProcessing) Export
	
	If Not ValueIsFilled(FillingData) Then
		Return;
	EndIf;
	
	If TypeOf(FillingData) = Type("DocumentRef.Quote") Then
		FillByQuote(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.CashInflowForecast") Then
		FillByCashInflowForecast(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.CashTransferPlan") Then
		FillByCashTransferPlan(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.SalesInvoice") Then
		FillBySalesInvoice(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.ShiftClosure") Then
		FillByShiftClosure(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.FixedAssetSale") Then
		FillByFixedAssetSale(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.SalesOrder") Then
		FillBySalesOrder(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.WorkOrder") Then
		FillByWorkOrder(FillingData);
	ElsIf TypeOf(FillingData)= Type("DocumentRef.LoanContract") Then
		FillByLoanContract(FillingData);
	ElsIf TypeOf(FillingData) = Type("Structure")
			AND FillingData.Property("Basis") Then
		If FillingData.Property("ConsiderBalances") 
			AND TypeOf(FillingData.Basis)= Type("DocumentRef.SalesOrder") Then
			FillBySalesOrderDependOnBalanceForPayment(FillingData.Basis);
		ElsIf TypeOf(FillingData.Basis)= Type("DocumentRef.Quote") Then
			FillByQuote(FillingData, FillingData.LineNumber);
		ElsIf TypeOf(FillingData.Basis)= Type("DocumentRef.SalesOrder") Then
			FillBySalesOrder(FillingData, FillingData.LineNumber);
		ElsIf TypeOf(FillingData.Basis)= Type("DocumentRef.WorkOrder") Then
			FillByWorkOrder(FillingData, FillingData.LineNumber);
		ElsIf TypeOf(FillingData.Document) = Type("DocumentRef.CashInflowForecast") Then
			FillByCashInflowForecast(FillingData.Document, FillingData.Amount);
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
		ElsIf TypeOf(FillingData.Document)= Type("DocumentRef.LoanInterestCommissionAccruals") Then
			FillByAccrualsForLoans(FillingData);
		EndIf;
	EndIf;
	
	If Not ValueIsFilled(AcceptedFrom)
	      AND ValueIsFilled(Counterparty)
	      AND (OperationKind = Enums.OperationTypesCashReceipt.FromCustomer
	     OR OperationKind = Enums.OperationTypesCashReceipt.FromVendor) Then
			
			AcceptedFrom = ?(Counterparty.DescriptionFull = "", Counterparty.Description, Counterparty.DescriptionFull);
			
	EndIf;
	
EndProcedure

// Procedure - event handler FillCheckProcessing object.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	// Deletion of verifiable attributes from the structure depending
	// on the operation type.
	If OperationKind = Enums.OperationTypesCashReceipt.FromVendor
	 OR OperationKind = Enums.OperationTypesCashReceipt.FromCustomer Then
	 
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "AdvanceHolder");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Correspondence");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Document");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "CashCR");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "StructuralUnit");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Department");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "BusinessLine");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "AccountingAmount");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "ExchangeRate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Multiplicity");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "LoanContract");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.TypeOfAmount");
		
		If Counterparty.DoOperationsByDocuments Then
			For Each RowPaymentDetails In PaymentDetails Do
				If Not ValueIsFilled(RowPaymentDetails.Document)
					AND (OperationKind = Enums.OperationTypesCashReceipt.FromVendor
				   OR (OperationKind = Enums.OperationTypesCashReceipt.FromCustomer
				   AND Not RowPaymentDetails.AdvanceFlag)) Then
					If PaymentDetails.Count() = 1 Then
						If OperationKind = Enums.OperationTypesCashReceipt.FromCustomer Then
							MessageText = NStr("en = 'Please specify the shipment document or select the ""Advance payment"" check box.'");
						Else
							MessageText = NStr("en = 'Specify a billing document.'");
						EndIf;
					Else
						If OperationKind = Enums.OperationTypesCashReceipt.FromCustomer Then
							MessageText = NStr("en = 'Please specify the shipment document or select the ""Advance payment"" check box in line #%1 of the payment details.'");
						Else
							MessageText = NStr("en = 'Specify a billing documen in line #%1 of the payment details.'");
						EndIf;
						MessageText = StrTemplate(MessageText, String(RowPaymentDetails.LineNumber));
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
			MessageText = StrTemplate(NStr("en = 'The document amount (%1 %2) is not equal to the sum of payment amounts in the payment details (%3 %4).'"), 
							String(DocumentAmount), 
							TrimAll(String(CashCurrency)),
							String(PaymentAmount), 
							TrimAll(String(CashCurrency)));
							
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
		
	ElsIf OperationKind = Enums.OperationTypesCashReceipt.FromAdvanceHolder Then
		
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Counterparty");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Correspondence");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "CashCR");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "StructuralUnit");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Department");
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
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "LoanContract");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.TypeOfAmount");
		
	ElsIf OperationKind = Enums.OperationTypesCashReceipt.RetailIncome Then
		
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "AdvanceHolder");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Counterparty");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Correspondence");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Document");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "StructuralUnit");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Department");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "BusinessLine");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Contract");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.SettlementsAmount");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.ExchangeRate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Multiplicity");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "AccountingAmount");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "ExchangeRate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Multiplicity");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "LoanContract");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.TypeOfAmount");
		
		PaymentAmount = PaymentDetails.Total("PaymentAmount");
		If PaymentAmount <> DocumentAmount Then
			MessageText = NStr("en = 'The document amount (%DocumentAmount% %CashCurrency%) is not equal to the sum of payment amounts in the payment details (%PaymentAmount% %CashCurrency%).!'");
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
		
		If ValueIsFilled(CashCR) Then
			
			If ValueIsFilled(PettyCash) And ValueIsFilled(CashCurrency) Then
				
				CashCRCurrency = CommonUse.ObjectAttributeValue(CashCR, "CashCurrency");
				
				If CashCRCurrency <> CashCurrency Then
					
					MessageText = NStr("en = 'Currency mismatch. The cash register and the cash account should have the same currency.'");
					DriveServer.ShowMessageAboutError(ThisObject, MessageText, , , "PettyCash", Cancel);
					
				EndIf;
				
			EndIf;
			
			If ValueIsFilled(BasisDocument) And TypeOf(BasisDocument) = Type("DocumentRef.ShiftClosure") Then
				
				ShiftClosureCashCR = CommonUse.ObjectAttributeValue(BasisDocument, "CashCR");
				
				If ShiftClosureCashCR <> CashCR Then
					
					MessageText = NStr("en = 'Cash registers mismatch. The selected cash register should be the same as in the shift closure.'");
					DriveServer.ShowMessageAboutError(ThisObject, MessageText, , , "CashCR", Cancel);
					
				EndIf;
				
			EndIf;
			
		EndIf;
		
	ElsIf OperationKind = Enums.OperationTypesCashReceipt.RetailIncomeEarningAccounting Then
		
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "AdvanceHolder");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Counterparty");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Correspondence");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Document");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "CashCR");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Contract");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.SettlementsAmount");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.ExchangeRate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Multiplicity");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "AccountingAmount");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "ExchangeRate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Multiplicity");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "LoanContract");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.TypeOfAmount");
		
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
		
	ElsIf OperationKind = Enums.OperationTypesCashReceipt.Other Then
		
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "AdvanceHolder");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Counterparty");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Document");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "CashCR");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "StructuralUnit");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Department");
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
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "LoanContract");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.TypeOfAmount");
		
	ElsIf OperationKind = Enums.OperationTypesCashReceipt.CurrencyPurchase Then
		
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "AdvanceHolder");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Counterparty");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Document");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "CashCR");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "StructuralUnit");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Department");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "BusinessLine");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Contract");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.AdvanceFlag");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.SettlementsAmount");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.ExchangeRate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Multiplicity");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.VATRate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "LoanContract");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.TypeOfAmount");
		
	// Miscellaneous payable
	ElsIf OperationKind = Enums.OperationTypesCashReceipt.OtherSettlements Then
		
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "AdvanceHolder");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Counterparty");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Document");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "CashCR");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "StructuralUnit");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Department");
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
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "LoanContract");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.TypeOfAmount");
		
		PaymentAmount = PaymentDetails.Total("PaymentAmount");
		If PaymentAmount <> DocumentAmount Then
			MessageText = NStr("en = 'Document amount: %DocumentAmount% %CashCurrency% does not match with the posted payments in the tabular section:  %PaymentAmount% %CashCurrency%!'");
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
	ElsIf OperationKind = Enums.OperationTypesCashReceipt.LoanRepaymentByEmployee Then
		
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Correspondence");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Counterparty");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Document");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "CashCR");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "StructuralUnit");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Department");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "BusinessLine");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "AccountingAmount");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "ExchangeRate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Multiplicity");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Contract");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.AdvanceFlag");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.VATRate");
				
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
		
	ElsIf OperationKind = Enums.OperationTypesCashReceipt.LoanSettlements Then
		
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "AdvanceHolder");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Correspondence");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Document");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "CashCR");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "StructuralUnit");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Department");
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
	// End Miscellaneous payable	
	EndIf;
	
EndProcedure

// Procedure - event handler Posting object.
//
Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting.
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Document data initialization.
	Documents.CashReceipt.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Preparation of records sets.
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Account for in accounting sections.
	DriveServer.ReflectCashAssets(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectCashAssetsInCashRegisters(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAdvanceHolders(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountsReceivable(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountsPayable(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectPaymentCalendar(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectInvoicesAndOrdersPayment(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectIncomeAndExpenses(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectIncomeAndExpensesCashMethod(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectUnallocatedExpenses(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectIncomeAndExpensesRetained(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectPOSSummary(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingJournalEntries(AdditionalProperties, RegisterRecords, Cancel);
	// Miscellaneous payable
	DriveServer.ReflectMiscellaneousPayable(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectLoanSettlements(AdditionalProperties, RegisterRecords, Cancel);
	// End Miscellaneous payable
	
	//VAT
	DriveServer.ReflectVATOutput(AdditionalProperties, RegisterRecords, Cancel);
	
	// Record of the records sets.
	DriveServer.WriteRecordSets(ThisObject);
	
	If Not Cancel Then
		WorkWithVAT.SubordinatedTaxInvoiceControl(DocumentWriteMode.Posting, Ref, DeletionMark);
	EndIf;
	
	// Control of occurrence of a negative balance.
	Documents.CashReceipt.RunControl(Ref, AdditionalProperties, Cancel);
	
	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
EndProcedure

// Procedure - event handler UndoPosting object.
//
Procedure UndoPosting(Cancel)
	
	// Initialization of additional properties to undo the posting of a document.
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Preparation of records sets.
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Record of the records sets.
	DriveServer.WriteRecordSets(ThisObject);
	
	If Not Cancel Then
		WorkWithVAT.SubordinatedTaxInvoiceControl(DocumentWriteMode.UndoPosting, Ref, DeletionMark);
	EndIf;
	
	// Control of occurrence of a negative balance.
	Documents.CashReceipt.RunControl(Ref, AdditionalProperties, Cancel, True);
	
EndProcedure

#Region OtherSettlements

Procedure FillByLoanContract(DocRefLoanContract, Amount = Undefined) Export
	      
	Query = New Query;
	Query.SetParameter("Ref",	DocRefLoanContract);
	Query.SetParameter("Date",	?(ValueIsFilled(Date), Date, CurrentDate()));
	
	If Amount <> Undefined Then
		
		Query.Text =
		"SELECT
		|	REFPRESENTATION(&Ref) AS Basis,
		|	CASE
		|		WHEN DocumentTable.LoanKind = VALUE(Enum.LoanContractTypes.Borrowed)
		|			THEN VALUE(Enum.OperationTypesCashReceipt.LoanSettlements)
		|		ELSE VALUE(Enum.OperationTypesCashReceipt.LoanRepaymentByEmployee)
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
		|	ISNULL(SettlementsExchangeRates.ExchangeRate, 1) AS ExchangeRate,
		|	ISNULL(SettlementsExchangeRates.Multiplicity, 1) AS Multiplicity,
		|	CAST(&Amount AS NUMBER(15, 2)) AS SettlementsAmount,
		|	CAST(&Amount * (1 - 1 / ((ISNULL(AccountingPolicySliceLast.DefaultVATRate.Rate, 0) + 100) / 100)) AS NUMBER(15, 2)) AS VATAmount
		|FROM
		|	Document.LoanContract AS DocumentTable
		|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&Date, ) AS SettlementsExchangeRates
		|		ON DocumentTable.SettlementsCurrency = SettlementsExchangeRates.Currency
		|		LEFT JOIN InformationRegister.AccountingPolicy.SliceLast(&Date, ) AS AccountingPolicySliceLast
		|		ON DocumentTable.Ref.Company = AccountingPolicySliceLast.Company
		|WHERE
		|	DocumentTable.Ref = &Ref";
		
	Else
		
		Query.Text =
		"SELECT
		|	REFPRESENTATION(&Ref) AS Basis,
		|	CASE
		|		WHEN DocumentTable.LoanKind = VALUE(Enum.LoanContractTypes.Borrowed)
		|			THEN VALUE(Enum.OperationTypesCashReceipt.LoanSettlements)
		|		ELSE VALUE(Enum.OperationTypesCashReceipt.LoanRepaymentByEmployee)
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
		|	ISNULL(SettlementsExchangeRates.ExchangeRate, 1) AS ExchangeRate,
		|	ISNULL(SettlementsExchangeRates.Multiplicity, 1) AS Multiplicity,
		|	CAST(DocumentTable.Total AS NUMBER(15, 2)) AS SettlementsAmount,
		|	CAST(DocumentTable.Total * (1 - 1 / ((ISNULL(AccountingPolicySliceLast.DefaultVATRate.Rate, 0) + 100) / 100)) AS NUMBER(15, 2)) AS VATAmount
		|FROM
		|	Document.LoanContract AS DocumentTable
		|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&Date, ) AS SettlementsExchangeRates
		|		ON DocumentTable.SettlementsCurrency = SettlementsExchangeRates.Currency
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
		Query.SetParameter("LoanContract",	FillingData.LoanContract);
		Query.SetParameter("SettlementsCurrency",	FillingData.SettlementsCurrency);
		
	ElsIf FillingData.Accruals.Count() > 0 Then
		
		Query.SetParameter("Ref",					FillingData);
		Query.SetParameter("Employee",				FillingData.Accruals[0].Employee);
		Query.SetParameter("Counterparty",			FillingData.Accruals[0].Lender);
		Query.SetParameter("LoanContract",			FillingData.Accruals[0].LoanContract);
		Query.SetParameter("SettlementsCurrency",	FillingData.Accruals[0].SettlementsCurrency);
		
	Else
		Return;
	EndIf;
	
	Query.SetParameter("Date", ?(ValueIsFilled(Date), Date, CurrentDate()));
	
	Query.Text =
	"SELECT
	|	REFPRESENTATION(&Ref) AS Basis,
	|	VALUE(Enum.OperationTypesCashReceipt.LoanRepaymentByEmployee) AS OperationKind,
	|	&Ref AS BasisDocument,
	|	DocumentTable.Ref.Company AS Company,
	|	DocumentTable.SettlementsCurrency AS CashCurrency,
	|	DocumentTable.Employee AS AdvanceHolder,
	|	DocumentTable.LoanContract AS LoanContract,
	|	DocumentTable.AmountType AS TypeOfAmount,
	|	DocumentTable.Total AS PaymentAmount,
	|	AccountingPolicySliceLast.DefaultVATRate AS VATRate,
	|	ISNULL(SettlementsExchangeRates.ExchangeRate, 1) AS ExchangeRate,
	|	ISNULL(SettlementsExchangeRates.Multiplicity, 1) AS Multiplicity,
	|	CAST(DocumentTable.Total AS NUMBER(15, 2)) AS SettlementsAmount,
	|	CAST(DocumentTable.Total * (1 - 1 / ((ISNULL(AccountingPolicySliceLast.DefaultVATRate.Rate, 0) + 100) / 100)) AS NUMBER(15, 2)) AS VATAmount
	|FROM
	|	Document.LoanInterestCommissionAccruals.Accruals AS DocumentTable
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&Date, ) AS SettlementsExchangeRates
	|		ON DocumentTable.SettlementsCurrency = SettlementsExchangeRates.Currency
	|		LEFT JOIN InformationRegister.AccountingPolicy.SliceLast(&Date, ) AS AccountingPolicySliceLast
	|		ON DocumentTable.Ref.Company = AccountingPolicySliceLast.Company
	|WHERE
	|	DocumentTable.Ref = &Ref
	|	AND DocumentTable.LoanContract = &LoanContract
	|	AND DocumentTable.SettlementsCurrency = &SettlementsCurrency
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

#EndIf
