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
		StructureByCurrency.ExchangeRate);
		
	CurrencyUnitConversionFactor = ?(
		StructureByCurrency.ExchangeRate = 0,
		1,
		StructureByCurrency.Multiplicity);
	
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
	|	AccountsPayableBalances.Company AS Company,
	|	AccountsPayableBalances.Counterparty AS Counterparty,
	|	AccountsPayableBalances.Contract AS Contract,
	|	AccountsPayableBalances.Document AS Document,
	|	AccountsPayableBalances.Order AS Order,
	|	AccountsPayableBalances.SettlementsType AS SettlementsType,
	|	AccountsPayableBalances.AmountCurBalance AS AmountCurBalance
	|INTO AccountsPayableTable
	|FROM
	|	AccumulationRegister.AccountsPayable.Balance(
	|			,
	|			Company = &Company
	|				AND Counterparty = &Counterparty
	|				AND SettlementsType = VALUE(Enum.SettlementsTypes.Debt)) AS AccountsPayableBalances
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentAccountsPayable.Company,
	|	DocumentAccountsPayable.Counterparty,
	|	DocumentAccountsPayable.Contract,
	|	DocumentAccountsPayable.Document,
	|	DocumentAccountsPayable.Order,
	|	DocumentAccountsPayable.SettlementsType,
	|	CASE
	|		WHEN DocumentAccountsPayable.RecordType = VALUE(AccumulationRecordType.Receipt)
	|			THEN -DocumentAccountsPayable.AmountCur
	|		ELSE DocumentAccountsPayable.AmountCur
	|	END
	|FROM
	|	AccumulationRegister.AccountsPayable AS DocumentAccountsPayable
	|WHERE
	|	DocumentAccountsPayable.Recorder = &Ref
	|	AND DocumentAccountsPayable.Period <= &Period
	|	AND DocumentAccountsPayable.Company = &Company
	|	AND DocumentAccountsPayable.Counterparty = &Counterparty
	|	AND DocumentAccountsPayable.SettlementsType = VALUE(Enum.SettlementsTypes.Debt)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccountsPayableTable.Counterparty AS Counterparty,
	|	AccountsPayableTable.Contract AS Contract,
	|	AccountsPayableTable.Document AS Document,
	|	AccountsPayableTable.Order AS Order,
	|	SUM(AccountsPayableTable.AmountCurBalance) AS AmountCurBalance
	|INTO AccountsPayableGrouped
	|FROM
	|	AccountsPayableTable AS AccountsPayableTable
	|WHERE
	|	AccountsPayableTable.AmountCurBalance > 0
	|
	|GROUP BY
	|	AccountsPayableTable.Counterparty,
	|	AccountsPayableTable.Contract,
	|	AccountsPayableTable.Document,
	|	AccountsPayableTable.Order
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccountsPayableGrouped.Counterparty AS Counterparty,
	|	AccountsPayableGrouped.Contract AS Contract,
	|	CASE
	|		WHEN Counterparties.DoOperationsByDocuments
	|			THEN AccountsPayableGrouped.Document
	|		ELSE UNDEFINED
	|	END AS Document,
	|	CASE
	|		WHEN Counterparties.DoOperationsByOrders
	|			THEN AccountsPayableGrouped.Order
	|		ELSE VALUE(Document.PurchaseOrder.EmptyRef)
	|	END AS Order,
	|	AccountsPayableGrouped.AmountCurBalance AS AmountCurBalance,
	|	CounterpartyContracts.SettlementsCurrency AS SettlementsCurrency
	|INTO AccountsPayableContract
	|FROM
	|	AccountsPayableGrouped AS AccountsPayableGrouped
	|		INNER JOIN Catalog.Counterparties AS Counterparties
	|		ON AccountsPayableGrouped.Counterparty = Counterparties.Ref
	|		INNER JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
	|		ON AccountsPayableGrouped.Contract = CounterpartyContracts.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	AccountsPayableTable.Document AS Document
	|INTO DocumentTable
	|FROM
	|	AccountsPayableTable AS AccountsPayableTable
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	TRUE AS ExistsEPD,
	|	SupplierInvoiceEarlyPaymentDiscounts.Ref AS SupplierInvoice
	|INTO EarlyPaymentDiscounts
	|FROM
	|	Document.SupplierInvoice.EarlyPaymentDiscounts AS SupplierInvoiceEarlyPaymentDiscounts
	|		INNER JOIN DocumentTable AS DocumentTable
	|		ON SupplierInvoiceEarlyPaymentDiscounts.Ref = DocumentTable.Document
	|WHERE
	|	ENDOFPERIOD(SupplierInvoiceEarlyPaymentDiscounts.DueDate, DAY) >= &Period
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
	|	AccountsPayableContract.Contract AS Contract,
	|	AccountsPayableContract.Document AS Document,
	|	ISNULL(EntriesRecorderPeriod.Period, DATETIME(1, 1, 1)) AS DocumentDate,
	|	AccountsPayableContract.Order AS Order,
	|	ExchangeRatesOfDocument.ExchangeRate AS CashAssetsRate,
	|	ExchangeRatesOfDocument.Multiplicity AS CashMultiplicity,
	|	SettlementsExchangeRates.ExchangeRate AS ExchangeRate,
	|	SettlementsExchangeRates.Multiplicity AS Multiplicity,
	|	AccountsPayableContract.AmountCurBalance AS AmountCurBalance,
	|	CAST(AccountsPayableContract.AmountCurBalance * SettlementsExchangeRates.ExchangeRate * ExchangeRatesOfDocument.Multiplicity / (ExchangeRatesOfDocument.ExchangeRate * SettlementsExchangeRates.Multiplicity) AS NUMBER(15, 2)) AS AmountCurDocument,
	|	ISNULL(EarlyPaymentDiscounts.ExistsEPD, FALSE) AS ExistsEPD
	|INTO AccountsPayableWithDiscount
	|FROM
	|	AccountsPayableContract AS AccountsPayableContract
	|		LEFT JOIN ExchangeRatesOnPeriod AS ExchangeRatesOfDocument
	|		ON (ExchangeRatesOfDocument.Currency = &Currency)
	|		LEFT JOIN ExchangeRatesOnPeriod AS SettlementsExchangeRates
	|		ON AccountsPayableContract.SettlementsCurrency = SettlementsExchangeRates.Currency
	|		LEFT JOIN EarlyPaymentDiscounts AS EarlyPaymentDiscounts
	|		ON AccountsPayableContract.Document = EarlyPaymentDiscounts.SupplierInvoice
	|		LEFT JOIN EntriesRecorderPeriod AS EntriesRecorderPeriod
	|		ON AccountsPayableContract.Document = EntriesRecorderPeriod.Recorder
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccountsPayableWithDiscount.Contract AS Contract,
	|	AccountsPayableWithDiscount.Document AS Document,
	|	AccountsPayableWithDiscount.DocumentDate AS DocumentDate,
	|	AccountsPayableWithDiscount.Order AS Order,
	|	MAX(AccountsPayableWithDiscount.CashAssetsRate) AS CashAssetsRate,
	|	MAX(AccountsPayableWithDiscount.CashMultiplicity) AS CashMultiplicity,
	|	MAX(AccountsPayableWithDiscount.ExchangeRate) AS ExchangeRate,
	|	MAX(AccountsPayableWithDiscount.Multiplicity) AS Multiplicity,
	|	SUM(AccountsPayableWithDiscount.AmountCurBalance) AS AmountCurBalance,
	|	SUM(AccountsPayableWithDiscount.AmountCurDocument) AS AmountCurDocument,
	|	AccountsPayableWithDiscount.ExistsEPD AS ExistsEPD
	|FROM
	|	AccountsPayableWithDiscount AS AccountsPayableWithDiscount
	|
	|GROUP BY
	|	AccountsPayableWithDiscount.Contract,
	|	AccountsPayableWithDiscount.Document,
	|	AccountsPayableWithDiscount.DocumentDate,
	|	AccountsPayableWithDiscount.ExistsEPD,
	|	AccountsPayableWithDiscount.Order
	|
	|ORDER BY
	|	DocumentDate";
	
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
	
	SelectionOfQueryResult = Query.Execute().Select();
	
	PaymentDetails.Clear();
	
	AmountLeftToDistribute = DocumentAmount;
	
	While AmountLeftToDistribute > 0 Do
		
		NewRow = PaymentDetails.Add();
		
		If SelectionOfQueryResult.Next() Then
			
			FillPropertyValues(NewRow, SelectionOfQueryResult);
			
			If SelectionOfQueryResult.AmountCurDocument <= AmountLeftToDistribute Then // balance amount is less or equal than it is necessary to distribute
				
				NewRow.SettlementsAmount = SelectionOfQueryResult.AmountCurBalance;
				NewRow.PaymentAmount = SelectionOfQueryResult.AmountCurDocument;
				NewRow.VATRate = DefaultVATRate;
				NewRow.VATAmount = NewRow.PaymentAmount - (NewRow.PaymentAmount) / ((DefaultVATRate.Rate + 100) / 100);
				AmountLeftToDistribute = AmountLeftToDistribute - SelectionOfQueryResult.AmountCurDocument;
				
			Else // Balance amount is greater than it is necessary to distribute
				
				NewRow.SettlementsAmount = DriveServer.RecalculateFromCurrencyToCurrency(
					AmountLeftToDistribute,
					SelectionOfQueryResult.CashAssetsRate,
					SelectionOfQueryResult.ExchangeRate,
					SelectionOfQueryResult.CashMultiplicity,
					SelectionOfQueryResult.Multiplicity);
					
				NewRow.PaymentAmount = AmountLeftToDistribute;
				NewRow.VATRate = DefaultVATRate;
				NewRow.VATAmount = NewRow.PaymentAmount - (NewRow.PaymentAmount) / ((DefaultVATRate.Rate + 100) / 100);
				AmountLeftToDistribute = 0;
				
			EndIf;
			
		Else
			
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
				
			NewRow.AdvanceFlag = True;
			NewRow.PaymentAmount = AmountLeftToDistribute;
			NewRow.VATRate = DefaultVATRate;
			NewRow.VATAmount = NewRow.PaymentAmount - (NewRow.PaymentAmount) / ((DefaultVATRate.Rate + 100) / 100);
			AmountLeftToDistribute = 0;
			
		EndIf;
		
	EndDo;
	
	If PaymentDetails.Count() = 0 Then
		PaymentDetails.Add();
		PaymentDetails[0].PaymentAmount = DocumentAmount;
	EndIf;
	
	PaymentAmount = PaymentDetails.Total("PaymentAmount");
	
EndProcedure

// Procedure of filling the document on the basis.
//
// Parameters:
//  FillingData - Structure - Data on filling the document.
//	
Procedure FillByExpenditureRequest(BasisDocument, Amount = Undefined)
	
	If BasisDocument.PaymentConfirmationStatus = Enums.PaymentApprovalStatuses.NotApproved Then
		Raise NStr("en = 'Please select an approved expenditure request.'");
	EndIf;
	If BasisDocument.CashAssetsType = Enums.CashAssetTypes.Noncash Then
		Raise NStr("en = 'Please select an expenditure request with a cash or undefined payment method.'");
	EndIf;

	Query = New Query;
	Query.SetParameter("Ref",	BasisDocument);
	Query.SetParameter("Date",	?(ValueIsFilled(Date), Date, CurrentDate()));
	
	If Amount <> Undefined Then
		
		Query.SetParameter("Amount", Amount);
		Query.Text =
		"SELECT
		|	REFPRESENTATION(&Ref) AS Basis,
		|	VALUE(Enum.OperationTypesCashVoucher.Vendor) AS OperationKind,
		|	&Ref AS BasisDocument,
		|	DocumentTable.BasisDocument AS RequestBasisDocument,
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
		|	Document.ExpenditureRequest AS DocumentTable
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
		|	VALUE(Enum.OperationTypesCashVoucher.Vendor) AS OperationKind,
		|	&Ref AS BasisDocument,
		|	DocumentTable.BasisDocument AS RequestBasisDocument,
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
		|	Document.ExpenditureRequest AS DocumentTable
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
			AND TypeOf(BasisDocument.BasisDocument) = Type("DocumentRef.PurchaseOrder")
			AND Counterparty.DoOperationsByOrders Then
			
			NewRow.Order = BasisDocument.BasisDocument;
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Procedure of filling the document on the basis.
//
// Parameters:
//  FillingData - Structure - Data on filling the document.
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
	|	REFPRESENTATION(&Ref) AS Basis,
	|	VALUE(Enum.OperationTypesCashVoucher.Other) AS OperationKind,
	|	&Ref AS BasisDocument,
	|	DocumentTable.Company AS Company,
	|	VALUE(Enum.VATTaxationTypes.SubjectToVAT) AS VATTaxation,
	|	DocumentTable.CashFlowItem AS Item,
	|	DocumentTable.DocumentCurrency AS CashCurrency,
	|	DocumentTable.PettyCash AS PettyCash,
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
//  FillingData - Structure - Data on filling the document.
//	
Procedure FillBySupplierInvoice(BasisDocument)
	
	Query = New Query;
	
	Query.SetParameter("Ref", BasisDocument);
	Query.SetParameter("Date", ?(ValueIsFilled(Date), Date, CurrentDate()));
	Query.SetParameter("FunctionalCurrency", Constants.FunctionalCurrency.Get());
	
	Query.Text =
	"SELECT
	|	SupplierInvoice.Ref AS Ref,
	|	SupplierInvoice.DocumentCurrency AS DocumentCurrency,
	|	SupplierInvoice.ExchangeRate AS ExchangeRate,
	|	SupplierInvoice.Multiplicity AS Multiplicity,
	|	SupplierInvoice.Company AS Company,
	|	SupplierInvoice.Counterparty AS Counterparty,
	|	SupplierInvoice.Contract AS Contract,
	|	SupplierInvoice.VATTaxation AS VATTaxation,
	|	SupplierInvoice.BasisDocument AS BasisDocument
	|INTO SupplierInvoice
	|FROM
	|	Document.SupplierInvoice AS SupplierInvoice
	|WHERE
	|	SupplierInvoice.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SupplierInvoice.Company AS Company,
	|	SupplierInvoice.VATTaxation AS VATTaxation,
	|	SupplierInvoice.Counterparty AS Counterparty,
	|	SupplierInvoice.DocumentCurrency AS CashCurrency,
	|	SupplierInvoice.Contract AS Contract,
	|	CASE
	|		WHEN SupplierInvoice.DocumentCurrency = &FunctionalCurrency
	|			THEN RegCurrenciesRates.ExchangeRate * SupplierInvoice.Multiplicity / (SupplierInvoice.ExchangeRate * RegCurrenciesRates.Multiplicity)
	|		ELSE 1
	|	END AS SettlementsAmountExchangeRate,
	|	CASE
	|		WHEN SupplierInvoice.DocumentCurrency = &FunctionalCurrency
	|			THEN SupplierInvoice.ExchangeRate
	|		ELSE ISNULL(SettlementsExchangeRatesSliceLast.ExchangeRate, 1)
	|	END AS ExchangeRate,
	|	CASE
	|		WHEN SupplierInvoice.DocumentCurrency = &FunctionalCurrency
	|			THEN SupplierInvoice.Multiplicity
	|		ELSE ISNULL(SettlementsExchangeRatesSliceLast.Multiplicity, 1)
	|	END AS Multiplicity,
	|	SupplierInvoiceInventory.Total AS PaymentAmount,
	|	SupplierInvoiceInventory.VATRate AS VATRate,
	|	SupplierInvoiceInventory.VATAmount AS VATAmount,
	|	SupplierInvoice.DocumentCurrency AS DocumentCurrency,
	|	SupplierInvoiceInventory.Total AS Total,
	|	CASE
	|		WHEN SupplierInvoiceInventory.Order = UNDEFINED
	|				OR VALUETYPE(SupplierInvoiceInventory.Order) = TYPE(Document.SalesOrder)
	|			THEN VALUE(Document.PurchaseOrder.EmptyRef)
	|		ELSE SupplierInvoiceInventory.Order
	|	END AS PurchaseOrder,
	|	CASE
	|		WHEN VALUETYPE(SupplierInvoice.BasisDocument) = TYPE(Document.SalesInvoice)
	|				AND SupplierInvoice.BasisDocument <> VALUE(Document.SalesInvoice.EmptyRef)
	|			THEN SupplierInvoice.BasisDocument
	|		ELSE &Ref
	|	END AS Document
	|INTO Table
	|FROM
	|	SupplierInvoice AS SupplierInvoice
	|		INNER JOIN Document.SupplierInvoice.Inventory AS SupplierInvoiceInventory
	|			LEFT JOIN InformationRegister.ExchangeRates.SliceLast(
	|					&Date,
	|					Currency IN
	|						(SELECT
	|							ConstantNationalCurrency.Value
	|						FROM
	|							Constant.FunctionalCurrency AS ConstantNationalCurrency)) AS RegCurrenciesRates
	|			ON (TRUE)
	|		ON SupplierInvoice.Ref = SupplierInvoiceInventory.Ref
	|		LEFT JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
	|			LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&Date, ) AS SettlementsExchangeRatesSliceLast
	|			ON CounterpartyContracts.SettlementsCurrency = SettlementsExchangeRatesSliceLast.Currency
	|		ON SupplierInvoice.Contract = CounterpartyContracts.Ref
	|
	|UNION ALL
	|
	|SELECT
	|	SupplierInvoice.Company,
	|	SupplierInvoice.VATTaxation,
	|	SupplierInvoice.Counterparty,
	|	SupplierInvoice.DocumentCurrency,
	|	SupplierInvoice.Contract,
	|	CASE
	|		WHEN SupplierInvoice.DocumentCurrency = &FunctionalCurrency
	|			THEN RegCurrenciesRates.ExchangeRate * SupplierInvoice.Multiplicity / (SupplierInvoice.ExchangeRate * RegCurrenciesRates.Multiplicity)
	|		ELSE 1
	|	END,
	|	CASE
	|		WHEN SupplierInvoice.DocumentCurrency = &FunctionalCurrency
	|			THEN SupplierInvoice.ExchangeRate
	|		ELSE ISNULL(SettlementsExchangeRatesSliceLast.ExchangeRate, 1)
	|	END,
	|	CASE
	|		WHEN SupplierInvoice.DocumentCurrency = &FunctionalCurrency
	|			THEN SupplierInvoice.Multiplicity
	|		ELSE ISNULL(SettlementsExchangeRatesSliceLast.Multiplicity, 1)
	|	END,
	|	SupplierInvoiceExpenses.Total,
	|	SupplierInvoiceExpenses.VATRate,
	|	SupplierInvoiceExpenses.VATAmount,
	|	SupplierInvoice.DocumentCurrency,
	|	SupplierInvoiceExpenses.Total,
	|	SupplierInvoiceExpenses.PurchaseOrder,
	|	CASE
	|		WHEN VALUETYPE(SupplierInvoice.BasisDocument) = TYPE(Document.SalesInvoice)
	|				AND SupplierInvoice.BasisDocument <> VALUE(Document.SalesInvoice.EmptyRef)
	|			THEN SupplierInvoice.BasisDocument
	|		ELSE &Ref
	|	END
	|FROM
	|	SupplierInvoice AS SupplierInvoice
	|		INNER JOIN Document.SupplierInvoice.Expenses AS SupplierInvoiceExpenses
	|			LEFT JOIN InformationRegister.ExchangeRates.SliceLast(
	|					&Date,
	|					Currency IN
	|						(SELECT
	|							ConstantNationalCurrency.Value
	|						FROM
	|							Constant.FunctionalCurrency AS ConstantNationalCurrency)) AS RegCurrenciesRates
	|			ON (TRUE)
	|		ON SupplierInvoice.Ref = SupplierInvoiceExpenses.Ref
	|		LEFT JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
	|			LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&Date, ) AS SettlementsExchangeRatesSliceLast
	|			ON CounterpartyContracts.SettlementsCurrency = SettlementsExchangeRatesSliceLast.Currency
	|		ON SupplierInvoice.Contract = CounterpartyContracts.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	VALUE(Enum.OperationTypesCashVoucher.Vendor) AS OperationKind,
	|	VALUE(Catalog.CashFlowItems.PaymentToVendor) AS Item,
	|	CASE
	|		WHEN Counterparties.DoOperationsByDocuments
	|			THEN Table.Document
	|		ELSE UNDEFINED
	|	END AS Document,
	|	Table.Company AS Company,
	|	Table.VATTaxation AS VATTaxation,
	|	REFPRESENTATION(&Ref) AS Basis,
	|	Table.Counterparty AS Counterparty,
	|	Table.DocumentCurrency AS CashCurrency,
	|	Table.Contract AS Contract,
	|	FALSE AS AdvanceFlag,
	|	SUM(CAST(Table.Total * Table.SettlementsAmountExchangeRate AS NUMBER(15, 2))) AS SettlementsAmount,
	|	Table.ExchangeRate AS ExchangeRate,
	|	Table.Multiplicity AS Multiplicity,
	|	SUM(Table.PaymentAmount) AS PaymentAmount,
	|	Table.VATRate AS VATRate,
	|	SUM(Table.VATAmount) AS VATAmount,
	|	CASE
	|		WHEN Counterparties.DoOperationsByOrders
	|			THEN Table.PurchaseOrder
	|		ELSE VALUE(Document.PurchaseOrder.EmptyRef)
	|	END AS Order,
	|	&Ref AS BasisDocument
	|FROM
	|	Table AS Table
	|		LEFT JOIN Catalog.Counterparties AS Counterparties
	|		ON Table.Counterparty = Counterparties.Ref
	|
	|GROUP BY
	|	Table.Company,
	|	Table.VATTaxation,
	|	Table.Counterparty,
	|	Table.DocumentCurrency,
	|	Table.Contract,
	|	Table.ExchangeRate,
	|	Table.Multiplicity,
	|	Table.VATRate,
	|	CASE
	|		WHEN Counterparties.DoOperationsByOrders
	|			THEN Table.PurchaseOrder
	|		ELSE VALUE(Document.PurchaseOrder.EmptyRef)
	|	END,
	|	CASE
	|		WHEN Counterparties.DoOperationsByDocuments
	|			THEN Table.Document
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
	
EndProcedure

// Procedure of filling the document on the basis.
//
// Parameters:
//  FillingData - Structure - Data on filling the document.
//	
Procedure FillByCreditNote(BasisDocument)
	
	Query = New Query;
	
	Query.SetParameter("Ref", BasisDocument);
	Query.SetParameter("Date", ?(ValueIsFilled(Date), Date, CurrentDate()));
	Query.SetParameter("FunctionalCurrency", Constants.FunctionalCurrency.Get());
	
	Query.Text =
	"SELECT
	|	CreditNote.Ref AS Ref,
	|	CreditNote.DocumentCurrency AS DocumentCurrency,
	|	CreditNote.ExchangeRate AS ExchangeRate,
	|	CreditNote.Multiplicity AS Multiplicity,
	|	CreditNote.Company AS Company,
	|	CreditNote.Counterparty AS Counterparty,
	|	CreditNote.Contract AS Contract,
	|	CreditNote.VATTaxation AS VATTaxation,
	|	CreditNote.BasisDocument AS BasisDocument
	|INTO CreditNote
	|FROM
	|	Document.CreditNote AS CreditNote
	|WHERE
	|	CreditNote.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CreditNote.Company AS Company,
	|	CreditNote.VATTaxation AS VATTaxation,
	|	CreditNote.Counterparty AS Counterparty,
	|	CreditNote.DocumentCurrency AS CashCurrency,
	|	CreditNoteInventory.Order AS Order,
	|	CreditNote.Contract AS Contract,
	|	ISNULL(CASE
	|			WHEN CreditNote.DocumentCurrency = &FunctionalCurrency
	|				THEN RegCurrenciesRates.ExchangeRate * CreditNote.Multiplicity / (CreditNote.ExchangeRate * RegCurrenciesRates.Multiplicity)
	|			ELSE 1
	|		END, 0) AS SettlementsAmountExchangeRate,
	|	CASE
	|		WHEN CreditNote.DocumentCurrency = &FunctionalCurrency
	|			THEN CreditNote.ExchangeRate
	|		ELSE ISNULL(SettlementsExchangeRatesSliceLast.ExchangeRate, 1)
	|	END AS ExchangeRate,
	|	CASE
	|		WHEN CreditNote.DocumentCurrency = &FunctionalCurrency
	|			THEN CreditNote.Multiplicity
	|		ELSE ISNULL(SettlementsExchangeRatesSliceLast.Multiplicity, 1)
	|	END AS Multiplicity,
	|	ISNULL(CreditNoteInventory.Total, 0) AS PaymentAmount,
	|	CreditNoteInventory.VATRate AS VATRate,
	|	ISNULL(CreditNoteInventory.VATAmount, 0) AS VATAmount,
	|	CreditNote.DocumentCurrency AS DocumentCurrency,
	|	CreditNoteInventory.Total AS Total
	|INTO Inventory
	|FROM
	|	CreditNote AS CreditNote
	|		LEFT JOIN Document.CreditNote.Inventory AS CreditNoteInventory
	|			LEFT JOIN InformationRegister.ExchangeRates.SliceLast(
	|					&Date,
	|					Currency IN
	|						(SELECT
	|							ConstantNationalCurrency.Value
	|						FROM
	|							Constant.FunctionalCurrency AS ConstantNationalCurrency)) AS RegCurrenciesRates
	|			ON (TRUE)
	|		ON CreditNote.Ref = CreditNoteInventory.Ref
	|		LEFT JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
	|			LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&Date, ) AS SettlementsExchangeRatesSliceLast
	|			ON CounterpartyContracts.SettlementsCurrency = SettlementsExchangeRatesSliceLast.Currency
	|		ON CreditNote.Contract = CounterpartyContracts.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	VALUE(Enum.OperationTypesCashVoucher.ToCustomer) AS OperationKind,
	|	VALUE(Catalog.CashFlowItems.PaymentFromCustomers) AS Item,
	|	&Ref AS Document,
	|	Inventory.Company AS Company,
	|	Inventory.VATTaxation AS VATTaxation,
	|	REFPRESENTATION(&Ref) AS Basis,
	|	Inventory.Counterparty AS Counterparty,
	|	Inventory.DocumentCurrency AS CashCurrency,
	|	Inventory.Contract AS Contract,
	|	FALSE AS AdvanceFlag,
	|	SUM(CAST(Inventory.Total * Inventory.SettlementsAmountExchangeRate AS NUMBER(15, 2))) AS SettlementsAmount,
	|	Inventory.ExchangeRate AS ExchangeRate,
	|	Inventory.Multiplicity AS Multiplicity,
	|	SUM(Inventory.PaymentAmount) AS PaymentAmount,
	|	Inventory.VATRate AS VATRate,
	|	SUM(Inventory.VATAmount) AS VATAmount,
	|	CASE
	|		WHEN Counterparties.DoOperationsByOrders
	|			THEN Inventory.Order
	|		ELSE VALUE(Document.SalesOrder.EmptyRef)
	|	END AS Order,
	|	&Ref AS BasisDocument
	|FROM
	|	Inventory AS Inventory
	|		LEFT JOIN Catalog.Counterparties AS Counterparties
	|		ON Inventory.Counterparty = Counterparties.Ref
	|
	|GROUP BY
	|	Inventory.Company,
	|	Inventory.VATTaxation,
	|	Inventory.Counterparty,
	|	Inventory.DocumentCurrency,
	|	Inventory.Contract,
	|	Inventory.ExchangeRate,
	|	Inventory.Multiplicity,
	|	Inventory.VATRate,
	|	CASE
	|		WHEN Counterparties.DoOperationsByOrders
	|			THEN Inventory.Order
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
		
	EndIf;
	
EndProcedure

// Procedure of filling the document on the basis.
//
// Parameters:
//  FillingData - Structure - Data on filling the document.
//	
Procedure FillByAdditionalExpenses(BasisDocument)
	
	Query = New Query;
	
	Query.SetParameter("Ref", BasisDocument);
	Query.SetParameter("Date", ?(ValueIsFilled(Date), Date, CurrentDate()));
	
	Query.Text =
	"SELECT
	|	DocumentHeader.Company AS Company,
	|	DocumentHeader.VATTaxation AS VATTaxation,
	|	VALUE(Enum.OperationTypesCashVoucher.Vendor) AS OperationKind,
	|	&Ref AS BasisDocument,
	|	DocumentHeader.Company.PettyCashByDefault AS PettyCash,
	|	REFPRESENTATION(&Ref) AS Basis,
	|	DocumentHeader.Counterparty AS Counterparty,
	|	DocumentHeader.DocumentCurrency AS CashCurrency,
	|	CASE
	|		WHEN DocumentHeader.Counterparty.DoOperationsByOrders
	|			THEN DocumentHeader.PurchaseOrder
	|		ELSE VALUE(Document.PurchaseOrder.EmptyRef)
	|	END AS Order,
	|	DocumentHeader.Contract AS Contract,
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
	|	Document.AdditionalExpenses AS DocumentHeader
	|		LEFT JOIN Document.AdditionalExpenses.Expenses AS DocumentTable
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
	|	DocumentHeader.PurchaseOrder,
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
	|		WHEN DocumentHeader.Counterparty.DoOperationsByOrders
	|			THEN DocumentHeader.PurchaseOrder
	|		ELSE VALUE(Document.PurchaseOrder.EmptyRef)
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
//  FillingData - Structure - Data on filling the document.
//	
Procedure FillByAccountSalesFromConsignee(BasisDocument)
	
	Query = New Query;
	
	Query.SetParameter("Ref", BasisDocument);
	Query.SetParameter("Date", ?(ValueIsFilled(Date), Date, CurrentDate()));
	
	Query.Text =
	"SELECT
	|	DocumentHeader.Company AS Company,
	|	DocumentHeader.VATTaxation AS VATTaxation,
	|	VALUE(Enum.OperationTypesCashVoucher.ToCustomer) AS OperationKind,
	|	&Ref AS BasisDocument,
	|	DocumentHeader.Company.PettyCashByDefault AS PettyCash,
	|	REFPRESENTATION(&Ref) AS Basis,
	|	DocumentHeader.Counterparty AS Counterparty,
	|	DocumentHeader.DocumentCurrency AS CashCurrency,
	|	DocumentHeader.Contract AS Contract,
	|	CASE
	|		WHEN DocumentHeader.Counterparty.DoOperationsByOrders
	|			THEN DocumentTable.SalesOrder
	|		ELSE VALUE(Document.SalesOrder.EmptyRef)
	|	END AS Order,
	|	CASE
	|		WHEN DocumentHeader.Counterparty.DoOperationsByDocuments
	|			THEN &Ref
	|		ELSE UNDEFINED
	|	END AS Document,
	|	SUM(ISNULL(CAST(CASE
	|					WHEN DocumentHeader.AmountIncludesVAT
	|						THEN DocumentTable.BrokerageAmount
	|					ELSE DocumentTable.BrokerageAmount + DocumentTable.BrokerageVATAmount
	|				END * CASE
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
	|	SUM(ISNULL(CASE
	|				WHEN DocumentHeader.AmountIncludesVAT
	|					THEN DocumentTable.BrokerageAmount
	|				ELSE DocumentTable.BrokerageAmount + DocumentTable.BrokerageVATAmount
	|			END, 0)) AS PaymentAmount,
	|	DocumentTable.VATRate AS VATRate,
	|	SUM(ISNULL(DocumentTable.BrokerageVATAmount, 0)) AS VATAmount
	|FROM
	|	Document.AccountSalesFromConsignee AS DocumentHeader
	|		LEFT JOIN Document.AccountSalesFromConsignee.Inventory AS DocumentTable
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
	|	DocumentTable.SalesOrder,
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
	|		WHEN DocumentHeader.Counterparty.DoOperationsByOrders
	|			THEN DocumentTable.SalesOrder
	|		ELSE VALUE(Document.SalesOrder.EmptyRef)
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
//  FillingData - Structure - Data on filling the document.
//	
Procedure FillByAccountSalesToConsignor(BasisDocument)
	
	Query = New Query;
	
	Query.SetParameter("Ref", BasisDocument);
	Query.SetParameter("Date", ?(ValueIsFilled(Date), Date, CurrentDate()));
	
	Query.Text =
	"SELECT
	|	DocumentHeader.Company AS Company,
	|	DocumentHeader.VATTaxation AS VATTaxation,
	|	VALUE(Enum.OperationTypesCashVoucher.Vendor) AS OperationKind,
	|	&Ref AS BasisDocument,
	|	DocumentHeader.Company.PettyCashByDefault AS PettyCash,
	|	REFPRESENTATION(&Ref) AS Basis,
	|	DocumentHeader.Counterparty AS Counterparty,
	|	DocumentHeader.DocumentCurrency AS CashCurrency,
	|	DocumentHeader.Contract AS Contract,
	|	CASE
	|		WHEN DocumentHeader.Counterparty.DoOperationsByOrders
	|			THEN DocumentTable.PurchaseOrder
	|		ELSE VALUE(Document.PurchaseOrder.EmptyRef)
	|	END AS Order,
	|	CASE
	|		WHEN DocumentHeader.Counterparty.DoOperationsByDocuments
	|			THEN &Ref
	|		ELSE UNDEFINED
	|	END AS Document,
	|	SUM(ISNULL(CAST(CASE
	|					WHEN DocumentHeader.AmountIncludesVAT
	|						THEN CASE
	|								WHEN DocumentHeader.KeepBackComissionFee
	|									THEN DocumentTable.AmountReceipt + DocumentTable.ReceiptVATAmount - DocumentTable.BrokerageAmount - DocumentTable.BrokerageVATAmount
	|								ELSE DocumentTable.AmountReceipt + DocumentTable.ReceiptVATAmount
	|							END
	|					ELSE CASE
	|							WHEN DocumentHeader.KeepBackComissionFee
	|								THEN DocumentTable.AmountReceipt - DocumentTable.BrokerageAmount
	|							ELSE DocumentTable.AmountReceipt
	|						END
	|				END * CASE
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
	|	SUM(ISNULL(CASE
	|				WHEN DocumentHeader.AmountIncludesVAT
	|					THEN CASE
	|							WHEN DocumentHeader.KeepBackComissionFee
	|								THEN DocumentTable.AmountReceipt + DocumentTable.ReceiptVATAmount - DocumentTable.BrokerageAmount - DocumentTable.BrokerageVATAmount
	|							ELSE DocumentTable.AmountReceipt + DocumentTable.ReceiptVATAmount
	|						END
	|				ELSE CASE
	|						WHEN DocumentHeader.KeepBackComissionFee
	|							THEN DocumentTable.AmountReceipt - DocumentTable.BrokerageAmount
	|						ELSE DocumentTable.AmountReceipt
	|					END
	|			END, 0)) AS PaymentAmount,
	|	DocumentTable.VATRate AS VATRate,
	|	SUM(ISNULL(CASE
	|				WHEN DocumentHeader.KeepBackComissionFee
	|					THEN DocumentTable.ReceiptVATAmount - DocumentTable.BrokerageVATAmount
	|				ELSE DocumentTable.ReceiptVATAmount
	|			END, 0)) AS VATAmount
	|FROM
	|	Document.AccountSalesToConsignor AS DocumentHeader
	|		LEFT JOIN Document.AccountSalesToConsignor.Inventory AS DocumentTable
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
	|	DocumentTable.PurchaseOrder,
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
	|		WHEN DocumentHeader.Counterparty.DoOperationsByOrders
	|			THEN DocumentTable.PurchaseOrder
	|		ELSE VALUE(Document.PurchaseOrder.EmptyRef)
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
//  FillingData - Structure - Data on filling the document.
//	
Procedure FillBySupplierQuote(FillingData, LineNumber = Undefined, Amount = Undefined)
	
	Query = New Query();
	
	If Amount <> Undefined Then
		
		Query.SetParameter("Ref", FillingData);
		Query.SetParameter("Date", ?(ValueIsFilled(Date), Date, CurrentDate()));
		Query.SetParameter("Amount", Amount);
		
		// Fill data of the document tabular sections.
		Query.Text =
		"SELECT
		|	REFPRESENTATION(&Ref) AS Basis,
		|	VALUE(Enum.OperationTypesCashVoucher.Vendor) AS OperationKind,
		|	&Ref AS BasisDocument,
		|	DocumentHeader.Company AS Company,
		|	DocumentHeader.VATTaxation AS VATTaxation,
		|	DocumentHeader.DocumentCurrency AS CashCurrency,
		|	DocumentHeader.PettyCash AS PettyCash,
		|	DocumentHeader.Counterparty AS Counterparty,
		|	DocumentHeader.Contract AS Contract,
		|	TRUE AS AdvanceFlag,
		|	UNDEFINED AS Document,
		|	VALUE(Document.SupplierQuote.EmptyRef) AS Quote,
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
		|	Document.SupplierQuote AS DocumentHeader
		|		LEFT JOIN Document.SupplierQuote.Inventory AS DocumentTable
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
		|	VALUE(Enum.OperationTypesCashVoucher.Vendor) AS OperationKind,
		|	&Ref AS BasisDocument,
		|	DocumentHeader.Company AS Company,
		|	DocumentHeader.VATTaxation AS VATTaxation,
		|	DocumentHeader.DocumentCurrency AS CashCurrency,
		|	DocumentHeader.PettyCash AS PettyCash,
		|	DocumentHeader.Counterparty AS Counterparty,
		|	DocumentHeader.Contract AS Contract,
		|	TRUE AS AdvanceFlag,
		|	UNDEFINED AS Document,
		|	VALUE(Document.SupplierQuote.EmptyRef) AS Quote,
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
		|	Document.SupplierQuote AS DocumentHeader
		|		LEFT JOIN Document.SupplierQuote.Inventory AS DocumentTable
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
		|	VALUE(Enum.OperationTypesCashVoucher.Vendor) AS OperationKind,
		|	&Ref AS BasisDocument,
		|	DocumentTable.Ref.Company AS Company,
		|	DocumentTable.Ref.VATTaxation AS VATTaxation,
		|	DocumentTable.Ref.DocumentCurrency AS CashCurrency,
		|	DocumentTable.Ref.PettyCash AS PettyCash,
		|	DocumentTable.Ref.Counterparty AS Counterparty,
		|	DocumentTable.Ref.Contract AS Contract,
		|	TRUE AS AdvanceFlag,
		|	UNDEFINED AS Document,
		|	VALUE(Document.SupplierQuote.EmptyRef) AS Quote,
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
		|	CAST(DocumentTable.PaymentAmount * (1 - 1 / ((ISNULL(VATRates.VATRate.Rate, 0) + 100) / 100)) AS NUMBER(15, 2)) AS VATAmount
		|FROM
		|	Document.SupplierQuote.PaymentCalendar AS DocumentTable
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
		|			Document.SupplierQuote.Inventory AS DocumentTable
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
Procedure FillByPurchaseOrder(FillingData, LineNumber = Undefined, Amount = Undefined)
	
	Query = New Query();
	
	If Amount <> Undefined Then
		
		Query.SetParameter("Ref", FillingData);
		Query.SetParameter("Date", ?(ValueIsFilled(Date), Date, CurrentDate()));
		Query.SetParameter("Amount", Amount);
		
		// Fill data of the document tabular sections.
		Query.Text =
		"SELECT
		|	REFPRESENTATION(&Ref) AS Basis,
		|	VALUE(Enum.OperationTypesCashVoucher.Vendor) AS OperationKind,
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
		|		ELSE VALUE(Document.PurchaseOrder.EmptyRef)
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
		|	Document.PurchaseOrder AS DocumentHeader
		|		LEFT JOIN Document.PurchaseOrder.Inventory AS DocumentTable
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
		
		// Fill out the data from the document tabular section.
		Query.Text =
		"SELECT
		|	REFPRESENTATION(&Ref) AS Basis,
		|	VALUE(Enum.OperationTypesCashVoucher.Vendor) AS OperationKind,
		|	&Ref AS BasisDocument,
		|	CASE
		|		WHEN DocumentHeader.Counterparty.DoOperationsByOrders
		|			THEN &Ref
		|		ELSE VALUE(Document.PurchaseOrder.EmptyRef)
		|	END AS Order,
		|	DocumentHeader.Company AS Company,
		|	DocumentHeader.VATTaxation AS VATTaxation,
		|	DocumentHeader.DocumentCurrency AS CashCurrency,
		|	DocumentHeader.PettyCash AS PettyCash,
		|	DocumentHeader.Counterparty AS Counterparty,
		|	DocumentHeader.Contract AS Contract,
		|	TRUE AS AdvanceFlag,
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
		|	Document.PurchaseOrder AS DocumentHeader
		|		LEFT JOIN Document.PurchaseOrder.Inventory AS DocumentTable
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
		|	SettlementsExchangeRates.Multiplicity,
		|	CASE
		|		WHEN DocumentHeader.Counterparty.DoOperationsByOrders
		|			THEN &Ref
		|		ELSE VALUE(Document.PurchaseOrder.EmptyRef)
		|	END";
		
	Else
	
		Query.SetParameter("Ref", FillingData.Basis);
		Query.SetParameter("LineNumber", LineNumber);
		Query.SetParameter("Date", ?(ValueIsFilled(Date), Date, CurrentDate()));
		
		// Fill document header data.
		Query.Text =
		"SELECT
		|	REFPRESENTATION(&Ref) AS Basis,
		|	VALUE(Enum.OperationTypesCashVoucher.Vendor) AS OperationKind,
		|	&Ref AS BasisDocument,
		|	CASE
		|		WHEN DocumentTable.Ref.Counterparty.DoOperationsByOrders
		|			THEN &Ref
		|		ELSE VALUE(Document.PurchaseOrder.EmptyRef)
		|	END AS Order,
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
		|	CAST(DocumentTable.PaymentAmount * (1 - 1 / ((ISNULL(VATRates.VATRate.Rate, 0) + 100) / 100)) AS NUMBER(15, 2)) AS VATAmount
		|FROM
		|	Document.PurchaseOrder.PaymentCalendar AS DocumentTable
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
		|			Document.PurchaseOrder.Inventory AS DocumentTable
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
Procedure FillByPurchaseOrderDependOnBalanceForPayment(FillingData)
	
	Query = New Query();
	Query.SetParameter("Ref", FillingData);
	Query.SetParameter("Date", CurrentDate());
	
	Query.Text =
	"SELECT
	|	REFPRESENTATION(&Ref) AS Basis,
	|	VALUE(Enum.OperationTypesCashVoucher.Vendor) AS OperationKind,
	|	&Date AS Date,
	|	&Ref AS BasisDocument,
	|	CASE
	|		WHEN DocumentHeader.Counterparty.DoOperationsByOrders
	|			THEN &Ref
	|		ELSE VALUE(Document.PurchaseOrder.EmptyRef)
	|	END AS Order,
	|	DocumentHeader.Company AS Company,
	|	DocumentHeader.VATTaxation AS VATTaxation,
	|	DocumentHeader.DocumentCurrency AS CashCurrency,
	|	DocumentHeader.PettyCash AS PettyCash,
	|	DocumentHeader.Counterparty AS Counterparty,
	|	DocumentHeader.Contract AS Contract,
	|	TRUE AS AdvanceFlag,
	|	DocumentTable.VATRate AS VATRate,
	|	SettlementsExchangeRates.ExchangeRate AS ExchangeRate,
	|	SettlementsExchangeRates.Multiplicity AS Multiplicity,
	|	InvoicesAndOrdersPaymentTurnovers.AmountTurnover - InvoicesAndOrdersPaymentTurnovers.PaymentAmountTurnover - InvoicesAndOrdersPaymentTurnovers.AdvanceAmountTurnover AS DocumentAmount,
	|	InvoicesAndOrdersPaymentTurnovers.AmountTurnover - InvoicesAndOrdersPaymentTurnovers.PaymentAmountTurnover - InvoicesAndOrdersPaymentTurnovers.AdvanceAmountTurnover AS PaymentAmount,
	|	CAST((InvoicesAndOrdersPaymentTurnovers.AmountTurnover - InvoicesAndOrdersPaymentTurnovers.PaymentAmountTurnover - InvoicesAndOrdersPaymentTurnovers.AdvanceAmountTurnover) * CASE
	|			WHEN DocumentHeader.DocumentCurrency <> DocumentHeader.Contract.SettlementsCurrency
	|					AND SettlementsExchangeRates.ExchangeRate <> 0
	|					AND ExchangeRatesOfDocument.Multiplicity <> 0
	|				THEN ExchangeRatesOfDocument.ExchangeRate * SettlementsExchangeRates.Multiplicity / (ISNULL(SettlementsExchangeRates.ExchangeRate, 1) * ISNULL(ExchangeRatesOfDocument.Multiplicity, 1))
	|			ELSE 1
	|		END AS NUMBER(15, 2)) AS SettlementsAmount,
	|	CAST((InvoicesAndOrdersPaymentTurnovers.AmountTurnover - InvoicesAndOrdersPaymentTurnovers.PaymentAmountTurnover - InvoicesAndOrdersPaymentTurnovers.AdvanceAmountTurnover) * (1 - 1 / ((ISNULL(DocumentTable.VATRate.Rate, 0) + 100) / 100)) AS NUMBER(15, 2)) AS VATAmount
	|FROM
	|	Document.PurchaseOrder AS DocumentHeader
	|		LEFT JOIN (SELECT TOP 1
	|			&Ref AS Ref,
	|			PurchaseOrderInventory.VATRate AS VATRate
	|		FROM
	|			Document.PurchaseOrder.Inventory AS PurchaseOrderInventory
	|		WHERE
	|			PurchaseOrderInventory.Ref = &Ref) AS DocumentTable
	|		ON DocumentHeader.Ref = DocumentTable.Ref
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
Procedure FillByPayrollSheet(BasisDocument)
	
	Query = New Query;
	
	Query.SetParameter("Ref", BasisDocument);
	Query.SetParameter("Date", ?(ValueIsFilled(Date), Date, CurrentDate()));
	
	Query.Text =
	"SELECT
	|	DocumentTable.Ref.Company AS Company,
	|	VALUE(Catalog.CashFlowItems.Other) AS Item,
	|	VALUE(Enum.OperationTypesCashVoucher.Salary) AS OperationKind,
	|	&Ref AS BasisDocument,
	|	&Ref AS Statement,
	|	DocumentTable.Ref.Company.PettyCashByDefault AS PettyCash,
	|	REFPRESENTATION(DocumentTable.Ref) AS Basis,
	|	DocumentTable.DocumentAmount AS DocumentAmount,
	|	DocumentTable.DocumentAmount AS PaymentAmount,
	|	DocumentTable.DocumentCurrency AS CashCurrency
	|FROM
	|	Document.PayrollSheet AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref";
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		
		Selection = QueryResult.Select();
		Selection.Next();
		FillPropertyValues(ThisObject, Selection);
		PayrollPayment.Clear();
		NewRow = PayrollPayment.Add();
		FillPropertyValues(NewRow, Selection);
		
	EndIf;
	
EndProcedure

// Procedure of filling the document on the basis of tax Earning.
//
// Parameters:
// BasisDocument - DocumentRef.CashInflowForecast - Scheduled payment 
// FillingData   - Structure - Data on filling the document.
//	
Procedure FillByTaxAccrual(BasisDocument)
	
	If BasisDocument.OperationKind <> Enums.OperationTypesTaxAccrual.Accrual Then
		Raise NStr("en = 'Please select a tax accrual with ""Compensation"" operation.'");
	EndIf;

	Query = New Query;
	Query.SetParameter("Ref",							BasisDocument);
	Query.SetParameter("Date",							?(ValueIsFilled(Date), Date, CurrentDate()));
	Query.SetParameter("ConstantNationalCurrency",		Constants.FunctionalCurrency.Get());
	Query.SetParameter("ConstantAccountingCurrency",	Constants.PresentationCurrency.Get());
	
	Query.Text =
	"SELECT
	|	REFPRESENTATION(&Ref) AS Basis,
	|	VALUE(Enum.OperationTypesCashVoucher.Taxes) AS OperationKind,
	|	&Ref AS BasisDocument,
	|	VALUE(Catalog.CashFlowItems.Other) AS Item,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.Company.PettyCashByDefault AS PettyCash,
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
	
	If OperationKind = Enums.OperationTypesCashVoucher.Vendor AND PaymentDetails.Count() > 0 Then
		
		DocumentArray			= PaymentDetails.UnloadColumn("Document");
		CheckDate				= ?(ValueIsFilled(Date), Date, CurrentSessionDate());
		DocumentArrayWithEPD	= Documents.SupplierInvoice.GetSupplierInvoiceArrayWithEPD(DocumentArray, CheckDate);
		
		For Each TabularSectionRow In PaymentDetails Do
			
			If TypeOf(TabularSectionRow.Document) = Type("DocumentRef.SupplierInvoice") Then
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

// Calculates Early payment discount.
//
Procedure CalculateEPD() Export
	
	If OperationKind = Enums.OperationTypesCashVoucher.Vendor Then
		
		DocumentTable = PaymentDetails.Unload(New Structure("ExistsEPD", True), "Document");
		
		ParentCompany = DriveServer.GetCompany(Company);
		
		If VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then
			DefaultVATRate = InformationRegisters.AccountingPolicy.GetDefaultVATRate(Date, Company);
		ElsIf VATTaxation = Enums.VATTaxationTypes.NotSubjectToVAT Then
			DefaultVATRate = Catalogs.VATRates.Exempt;
		Else
			DefaultVATRate = Catalogs.VATRates.ZeroRate;
		EndIf;
		
		Query = New Query;
		Query.Text =
		"SELECT DISTINCT
		|	DocumentTable.Document AS Document
		|INTO SupplierInvoiceTable
		|FROM
		|	&DocumentTable AS DocumentTable
		|WHERE
		|	DocumentTable.Document REFS Document.SupplierInvoice
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
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
		|	AccountsPayableBalances.Company AS Company,
		|	AccountsPayableBalances.Counterparty AS Counterparty,
		|	AccountsPayableBalances.Contract AS Contract,
		|	AccountsPayableBalances.Document AS Document,
		|	AccountsPayableBalances.SettlementsType AS SettlementsType,
		|	AccountsPayableBalances.AmountCurBalance AS AmountCurBalance
		|INTO AccountsPayableTable
		|FROM
		|	AccumulationRegister.AccountsPayable.Balance(
		|			,
		|			Company = &Company
		|				AND Counterparty = &Counterparty
		|				AND SettlementsType = VALUE(Enum.SettlementsTypes.Debt)
		|				AND Document IN
		|					(SELECT
		|						SupplierInvoiceTable.Document
		|					FROM
		|						SupplierInvoiceTable)) AS AccountsPayableBalances
		|
		|UNION ALL
		|
		|SELECT
		|	DocumentAccountsPayable.Company,
		|	DocumentAccountsPayable.Counterparty,
		|	DocumentAccountsPayable.Contract,
		|	DocumentAccountsPayable.Document,
		|	DocumentAccountsPayable.SettlementsType,
		|	CASE
		|		WHEN DocumentAccountsPayable.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN -DocumentAccountsPayable.AmountCur
		|		ELSE DocumentAccountsPayable.AmountCur
		|	END
		|FROM
		|	AccumulationRegister.AccountsPayable AS DocumentAccountsPayable
		|		INNER JOIN SupplierInvoiceTable AS SupplierInvoiceTable
		|		ON DocumentAccountsPayable.Document = SupplierInvoiceTable.Document
		|WHERE
		|	DocumentAccountsPayable.Recorder = &Ref
		|	AND DocumentAccountsPayable.Period <= &Period
		|	AND DocumentAccountsPayable.Company = &Company
		|	AND DocumentAccountsPayable.Counterparty = &Counterparty
		|	AND DocumentAccountsPayable.SettlementsType = VALUE(Enum.SettlementsTypes.Debt)
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	AccountsPayableTable.Contract AS Contract,
		|	AccountsPayableTable.Document AS Document,
		|	SUM(AccountsPayableTable.AmountCurBalance) AS AmountCurBalance
		|INTO AccountsPayableGrouped
		|FROM
		|	AccountsPayableTable AS AccountsPayableTable
		|WHERE
		|	AccountsPayableTable.AmountCurBalance > 0
		|
		|GROUP BY
		|	AccountsPayableTable.Contract,
		|	AccountsPayableTable.Document
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	AccountsPayableGrouped.Contract AS Contract,
		|	AccountsPayableGrouped.Document AS Document,
		|	AccountsPayableGrouped.AmountCurBalance AS AmountCurBalance,
		|	CounterpartyContracts.SettlementsCurrency AS SettlementsCurrency
		|INTO AccountsPayableContract
		|FROM
		|	AccountsPayableGrouped AS AccountsPayableGrouped
		|		INNER JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
		|		ON AccountsPayableGrouped.Contract = CounterpartyContracts.Ref
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	SupplierInvoiceEarlyPaymentDiscounts.DueDate AS DueDate,
		|	SupplierInvoiceEarlyPaymentDiscounts.DiscountAmount AS DiscountAmount,
		|	SupplierInvoiceEarlyPaymentDiscounts.Ref AS SupplierInvoice
		|INTO EarlyPaymentDiscounts
		|FROM
		|	Document.SupplierInvoice.EarlyPaymentDiscounts AS SupplierInvoiceEarlyPaymentDiscounts
		|		INNER JOIN SupplierInvoiceTable AS SupplierInvoiceTable
		|		ON SupplierInvoiceEarlyPaymentDiscounts.Ref = SupplierInvoiceTable.Document
		|WHERE
		|	ENDOFPERIOD(SupplierInvoiceEarlyPaymentDiscounts.DueDate, DAY) >= &Period
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	MIN(EarlyPaymentDiscounts.DueDate) AS DueDate,
		|	EarlyPaymentDiscounts.SupplierInvoice AS SupplierInvoice
		|INTO EarlyPaymentMinDueDate
		|FROM
		|	EarlyPaymentDiscounts AS EarlyPaymentDiscounts
		|
		|GROUP BY
		|	EarlyPaymentDiscounts.SupplierInvoice
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	EarlyPaymentDiscounts.DiscountAmount AS DiscountAmount,
		|	EarlyPaymentDiscounts.SupplierInvoice AS SupplierInvoice
		|INTO EarlyPaymentMaxDiscountAmount
		|FROM
		|	EarlyPaymentDiscounts AS EarlyPaymentDiscounts
		|		INNER JOIN EarlyPaymentMinDueDate AS EarlyPaymentMinDueDate
		|		ON EarlyPaymentDiscounts.SupplierInvoice = EarlyPaymentMinDueDate.SupplierInvoice
		|			AND EarlyPaymentDiscounts.DueDate = EarlyPaymentMinDueDate.DueDate
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	AccountsPayableContract.Contract AS Contract,
		|	AccountsPayableContract.Document AS Document,
		|	ExchangeRatesOfDocument.ExchangeRate AS CashAssetsRate,
		|	ExchangeRatesOfDocument.Multiplicity AS CashMultiplicity,
		|	SettlementsExchangeRates.ExchangeRate AS ExchangeRate,
		|	SettlementsExchangeRates.Multiplicity AS Multiplicity,
		|	AccountsPayableContract.AmountCurBalance AS AmountCur,
		|	CAST(AccountsPayableContract.AmountCurBalance * SettlementsExchangeRates.ExchangeRate * ExchangeRatesOfDocument.Multiplicity / (ExchangeRatesOfDocument.ExchangeRate * SettlementsExchangeRates.Multiplicity) AS NUMBER(15, 2)) AS AmountCurDocument,
		|	ISNULL(EarlyPaymentMaxDiscountAmount.DiscountAmount, 0) AS SettlementsEPDAmount,
		|	CAST(ISNULL(EarlyPaymentMaxDiscountAmount.DiscountAmount, 0) * SettlementsExchangeRates.ExchangeRate * ExchangeRatesOfDocument.Multiplicity / (ExchangeRatesOfDocument.ExchangeRate * SettlementsExchangeRates.Multiplicity) AS NUMBER(15, 2)) AS EPDAmount
		|FROM
		|	AccountsPayableContract AS AccountsPayableContract
		|		LEFT JOIN ExchangeRatesOnPeriod AS ExchangeRatesOfDocument
		|		ON (ExchangeRatesOfDocument.Currency = &Currency)
		|		LEFT JOIN ExchangeRatesOnPeriod AS SettlementsExchangeRates
		|		ON AccountsPayableContract.SettlementsCurrency = SettlementsExchangeRates.Currency
		|		LEFT JOIN EarlyPaymentMaxDiscountAmount AS EarlyPaymentMaxDiscountAmount
		|		ON AccountsPayableContract.Document = EarlyPaymentMaxDiscountAmount.SupplierInvoice";
		
		Query.SetParameter("Company", ParentCompany);
		Query.SetParameter("Counterparty", Counterparty);
		Query.SetParameter("Period", Date);
		Query.SetParameter("Currency", CashCurrency);
		Query.SetParameter("Ref", Ref);
		Query.SetParameter("DocumentTable", DocumentTable);
		
		Selection = Query.Execute().Select();
		While Selection.Next() Do
			
			FilterParameters = New Structure("Contract,Document,ExistsEPD", Selection.Contract, Selection.Document, True);
			
			PaymentRows			= PaymentDetails.FindRows(FilterParameters);
			PaymentTable		= PaymentDetails.Unload(FilterParameters);
			PaymentAmountTotal	= PaymentTable.Total("PaymentAmount") + PaymentTable.Total("EPDAmount");
			
			EPDAmount				= Selection.EPDAmount;
			SettlementsEPDAmount	= Selection.SettlementsEPDAmount;
			
			If PaymentAmountTotal >= Selection.AmountCurDocument Then
				ValidForEPD = True;
			Else
				ValidForEPD = False;
			EndIf;
				
			For each Row In PaymentRows Do
				
				Row.PaymentAmount			= Row.PaymentAmount + Row.EPDAmount;
				Row.SettlementsAmount		= Row.SettlementsAmount + Row.SettlementsEPDAmount;
				Row.EPDAmount				= 0;
				Row.SettlementsEPDAmount	= 0;
				
				If ValidForEPD Then
					
					If Row.PaymentAmount > EPDAmount Then
						
						Row.EPDAmount				= EPDAmount;
						Row.SettlementsEPDAmount	= SettlementsEPDAmount;
						Row.PaymentAmount			= Row.PaymentAmount - Row.EPDAmount;
						Row.SettlementsAmount		= Row.SettlementsAmount - Row.SettlementsEPDAmount;
						
						EPDAmount				= 0;
						SettlementsEPDAmount	= 0;
						
					Else
						
						Row.EPDAmount				= Row.PaymentAmount;
						Row.SettlementsEPDAmount	= Row.SettlementsAmount;
						Row.PaymentAmount			= 0;
						Row.SettlementsAmount		= 0;
						
						EPDAmount				= EPDAmount - Row.EPDAmount;
						SettlementsEPDAmount	= SettlementsEPDAmount - Row.SettlementsEPDAmount;
						
					EndIf;
					
				EndIf;
				
				VATRate = ?(ValueIsFilled(Row.VATRate), Row.VATRate, DefaultVATRate);
				
				Row.VATRate		= VATRate;
				Row.VATAmount	= Row.PaymentAmount - (Row.PaymentAmount) / ((VATRate.Rate + 100) / 100);
				
			EndDo;
			
		EndDo;
		
		PaymentRowsWithoutEPD = PaymentDetails.FindRows(New Structure("ExistsEPD", False));
		For each Row In PaymentRowsWithoutEPD Do
			
			If Row.EPDAmount > 0 Then
				
				Row.PaymentAmount			= Row.PaymentAmount + Row.EPDAmount;
				Row.SettlementsAmount		= Row.SettlementsAmount + Row.SettlementsEPDAmount;
				Row.EPDAmount				= 0;
				Row.SettlementsEPDAmount	= 0;
				
				VATRate = ?(ValueIsFilled(Row.VATRate), Row.VATRate, DefaultVATRate);
				
				Row.VATRate		= VATRate;
				Row.VATAmount	= Row.PaymentAmount - (Row.PaymentAmount) / ((VATRate.Rate + 100) / 100);
				
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

// Procedure - handler of the FillingProcessor event.
//
Procedure Filling(FillingData, StandardProcessing)
	
	If TypeOf(FillingData) = Type("DocumentRef.ExpenditureRequest") Then
		FillByExpenditureRequest(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.CashTransferPlan") Then
		FillByCashTransferPlan(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.SupplierInvoice") Then
		FillBySupplierInvoice(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.CreditNote") Then
		FillByCreditNote(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.AdditionalExpenses") Then
		FillByAdditionalExpenses(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.AccountSalesFromConsignee") Then
		FillByAccountSalesFromConsignee(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.AccountSalesToConsignor") Then
		FillByAccountSalesToConsignor(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.PurchaseOrder") Then
		FillByPurchaseOrder(FillingData);
	ElsIf TypeOf(FillingData)= Type("DocumentRef.SupplierQuote") Then
		FillBySupplierQuote(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.PayrollSheet") Then
		FillByPayrollSheet(FillingData);
	ElsIf TypeOf(FillingData)= Type("DocumentRef.TaxAccrual") Then
		FillByTaxAccrual(FillingData);
	ElsIf TypeOf(FillingData)= Type("DocumentRef.LoanContract") Then
		FillByLoanContract(FillingData);	
	ElsIf TypeOf(FillingData) = Type("Structure")
			AND FillingData.Property("Basis") Then
		If FillingData.Property("ConsiderBalances") 
			AND TypeOf(FillingData.Basis)= Type("DocumentRef.PurchaseOrder") Then
			FillByPurchaseOrderDependOnBalanceForPayment(FillingData.Basis);
		ElsIf TypeOf(FillingData.Basis)= Type("DocumentRef.SupplierQuote") Then
			FillBySupplierQuote(FillingData, FillingData.LineNumber);
		ElsIf TypeOf(FillingData.Basis)= Type("DocumentRef.PurchaseOrder") Then
			FillByPurchaseOrder(FillingData, FillingData.LineNumber);
		ElsIf TypeOf(FillingData.Document) = Type("DocumentRef.ExpenditureRequest") Then
			FillByExpenditureRequest(FillingData.Document, FillingData.Amount);
		EndIf;
	ElsIf TypeOf(FillingData) = Type("Structure")
			AND FillingData.Property("Document") Then
		If TypeOf(FillingData.Document) = Type("DocumentRef.SupplierQuote") Then
			FillBySupplierQuote(FillingData.Document, Undefined, FillingData.Amount);
		ElsIf TypeOf(FillingData.Document) = Type("DocumentRef.PurchaseOrder") Then
			FillByPurchaseOrder(FillingData.Document, Undefined, FillingData.Amount);
		ElsIf TypeOf(FillingData.Document) = Type("DocumentRef.ExpenditureRequest") Then
			FillByExpenditureRequest(FillingData.Document, FillingData.Amount);
		ElsIf TypeOf(FillingData.Document) = Type("DocumentRef.CashTransferPlan") Then
			FillByCashTransferPlan(FillingData.Document, FillingData.Amount);
		ElsIf TypeOf(FillingData.Document)= Type("DocumentRef.LoanInterestCommissionAccruals") Then
			FillByAccrualsForLoans(FillingData);
		EndIf;
	EndIf;
	
EndProcedure

// Procedure - event handler FillCheckProcessing object.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	// Deletion of verifiable attributes from the structure depending
	// on the operation type.
	If OperationKind = Enums.OperationTypesCashVoucher.Vendor
	 OR OperationKind = Enums.OperationTypesCashVoucher.ToCustomer Then
		
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "AdvanceHolder");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Correspondence");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "TaxKind");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Department");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "RegistrationPeriod");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "CashCR");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "LoanContract");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.TypeOfAmount");
		If Counterparty.DoOperationsByDocuments Then
			For Each RowPaymentDetails In PaymentDetails Do
				If Not ValueIsFilled(RowPaymentDetails.Document)
					AND (OperationKind = Enums.OperationTypesCashVoucher.ToCustomer
				   OR (OperationKind = Enums.OperationTypesCashVoucher.Vendor
				   AND Not RowPaymentDetails.AdvanceFlag)) Then
					If PaymentDetails.Count() = 1 Then
						If OperationKind = Enums.OperationTypesCashVoucher.Vendor Then
							MessageText = NStr("en = 'Specify a shipment document or an advance payment.'");
						Else
							MessageText = NStr("en = 'Specify a billing document.'");
						EndIf;
					Else
						If OperationKind = Enums.OperationTypesCashVoucher.Vendor Then
							MessageText = NStr("en = 'Specify a shipment document or payment flag in line #%LineNumber% of the payment details.'");
						Else
							MessageText = NStr("en = 'Specify a billing document in line #%LineNumber% of the payment details.'");
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
			MessageText = NStr("en = 'The document amount (%DocumentAmount %CashCurrency%) is not equal to the sum of payment amounts in the payment details (%PaymentAmount% %CashCurrency%).'");
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
		
	ElsIf OperationKind = Enums.OperationTypesCashVoucher.ToAdvanceHolder Then
		
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Counterparty");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Correspondence");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "TaxKind");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Department");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "RegistrationPeriod");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "CashCR");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Contract");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.AdvanceFlag");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.SettlementsAmount");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.ExchangeRate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Multiplicity");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.VATRate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "LoanContract");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.TypeOfAmount");
		
	ElsIf OperationKind = Enums.OperationTypesCashVoucher.Salary Then
		
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Counterparty");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Correspondence");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "TaxKind");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Contract");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.AdvanceFlag");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.SettlementsAmount");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.ExchangeRate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Multiplicity");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.VATRate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "AdvanceHolder");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Department");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "RegistrationPeriod");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "CashCR");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "LoanContract");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.TypeOfAmount");
		PaymentAmount = PayrollPayment.Total("PaymentAmount");
		If PaymentAmount <> DocumentAmount Then
			MessageText = NStr("en = 'The document amount (%DocumentAmount %CashCurrency%) is not equal to the sum of payment amounts in the payment details (%PaymentAmount% %CashCurrency%).'");
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
		
	ElsIf OperationKind = Enums.OperationTypesCashVoucher.SalaryForEmployee Then
		
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Counterparty");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Correspondence");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "TaxKind");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "CashCR");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Contract");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.AdvanceFlag");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.SettlementsAmount");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.ExchangeRate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Multiplicity");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.VATRate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "LoanContract");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.TypeOfAmount");
		
	ElsIf OperationKind = Enums.OperationTypesCashVoucher.Other Then
		
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "AdvanceHolder");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Counterparty");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "TaxKind");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "RegistrationPeriod");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "CashCR");
		If Correspondence.TypeOfAccount <> Enums.GLAccountsTypes.Expenses Then
			DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Department");
		EndIf;
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Contract");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.AdvanceFlag");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.SettlementsAmount");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.ExchangeRate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Multiplicity");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.VATRate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "LoanContract");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.TypeOfAmount");
		
	ElsIf OperationKind = Enums.OperationTypesCashVoucher.TransferToCashCR Then
		
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "AdvanceHolder");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Counterparty");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Correspondence");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Department");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "RegistrationPeriod");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "TaxKind");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Contract");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.AdvanceFlag");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.SettlementsAmount");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.ExchangeRate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Multiplicity");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.VATRate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "LoanContract");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.TypeOfAmount");
		
	// Other settlement
	ElsIf OperationKind = Enums.OperationTypesCashVoucher.IssueLoanToEmployee Then
		
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Counterparty");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Correspondence");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Department");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "RegistrationPeriod");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "TaxKind");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "CashCR");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Contract");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.AdvanceFlag");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.SettlementsAmount");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.ExchangeRate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Multiplicity");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.VATRate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.TypeOfAmount");
				
	ElsIf OperationKind = Enums.OperationTypesCashVoucher.LoanSettlements Then
		
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "AdvanceHolder");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Correspondence");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Department");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "RegistrationPeriod");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "TaxKind");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "CashCR");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "CashCR");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Contract");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.AdvanceFlag");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.VATRate");
				
		PaymentAmount = PaymentDetails.Total("PaymentAmount");
		If PaymentAmount <> DocumentAmount Then
			MessageText = NStr("en = 'The document amount (%DocumentAmount %CashCurrency%) is not equal to the sum of payment amounts in the payment details (%PaymentAmount% %CashCurrency%).'");
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
		
	ElsIf OperationKind = Enums.OperationTypesCashVoucher.OtherSettlements Then
		
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "AdvanceHolder");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Counterparty");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "TaxKind");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "RegistrationPeriod");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "CashCR");
		If Correspondence.TypeOfAccount <> Enums.GLAccountsTypes.Expenses Then
			DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Department");
		EndIf;
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
			MessageText = NStr("en = 'The document amount (%DocumentAmount %CashCurrency%) is not equal to the sum of payment amounts in the payment details (%PaymentAmount% %CashCurrency%).'");
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
		
	// End Other settlement
	Else
		
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "AdvanceHolder");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Counterparty");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Correspondence");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Department");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "RegistrationPeriod");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "CashCR");
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
	
EndProcedure

// Procedure - event handler BeforeWrite object.
//
Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	AdditionalProperties.Insert("WriteMode", WriteMode);
	
	If Not Constants.UseSeveralLinesOfBusiness.Get()
		  AND Correspondence.TypeOfAccount = Enums.GLAccountsTypes.Expenses Then
		
		BusinessLine = Catalogs.LinesOfBusiness.MainLine;
		
	EndIf;
	
	For Each TSRow In PaymentDetails Do
		If ValueIsFilled(Counterparty)
		AND Not Counterparty.DoOperationsByContracts
		AND Not ValueIsFilled(TSRow.Contract) Then
			TSRow.Contract = Counterparty.ContractByDefault;
		EndIf;
		
		If (OperationKind = Enums.OperationTypesCashVoucher.OtherSettlements)
			OR OperationKind = Enums.OperationTypesCashVoucher.LoanSettlements
			AND TSRow.VATRate.IsEmpty() Then
			TSRow.VATRate	= Catalogs.VATRates.Exempt;
			TSRow.VATAmount	= 0;
		EndIf;
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

// Procedure - event handler Posting object.
//
Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting.
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Document data initialization.
	Documents.CashVoucher.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Preparation of records sets.
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Account for in accounting sections.
	DriveServer.ReflectCashAssets(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectCashAssetsInCashRegisters(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountsPayable(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountsReceivable(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAdvanceHolders(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectPayroll(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectPaymentCalendar(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectInvoicesAndOrdersPayment(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectIncomeAndExpenses(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectIncomeAndExpensesCashMethod(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectUnallocatedExpenses(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectIncomeAndExpensesRetained(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectTaxesSettlements(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingJournalEntries(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectMiscellaneousPayable(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectLoanSettlements(AdditionalProperties, RegisterRecords, Cancel);
	
	//VAT
	DriveServer.ReflectVATIncurred(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectVATInput(AdditionalProperties, RegisterRecords, Cancel);
	
	// Record of the records sets.
	DriveServer.WriteRecordSets(ThisObject);
	
	If Not Cancel Then
		WorkWithVAT.SubordinatedTaxInvoiceControl(DocumentWriteMode.Posting, Ref, DeletionMark);
	EndIf;
	
	// Control of occurrence of a negative balance.
	Documents.CashVoucher.RunControl(Ref, AdditionalProperties, Cancel);
	
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
	Documents.CashVoucher.RunControl(Ref, AdditionalProperties, Cancel, True);
	
EndProcedure

#Region OtherSettlements

Procedure FillByLoanContract(DocRefLoanContract) Export
	      
	Query = New Query;
	Query.SetParameter("Ref",			DocRefLoanContract);
	Query.SetParameter("Date",			?(ValueIsFilled(Date), Date, CurrentSessionDate()));
	Query.SetParameter("LoanKind",		Enums.LoanContractTypes.EmployeeLoanAgreement);
	
	Query.Text =
	"SELECT
	|	REFPRESENTATION(&Ref) AS Basis,
	|	CASE
	|		WHEN DocumentTable.LoanKind = VALUE(Enum.LoanContractTypes.Borrowed)
	|			THEN VALUE(Enum.OperationTypesCashVoucher.LoanSettlements)
	|		ELSE VALUE(Enum.OperationTypesCashVoucher.IssueLoanToEmployee)
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
	|		ON DocumentTable.Ref.Company = AccountingPolicySliceLast.Company
	|WHERE
	|	DocumentTable.Ref = &Ref";
		
	QueryResult = Query.Execute();
	
	If QueryResult.IsEmpty() Then
		Return;
	EndIf;
	
	Selection = QueryResult.Select();
	Selection.Next();
	FillPropertyValues(ThisObject, Selection);
	                     
	VATTaxation = Enums.VATTaxationTypes.NotSubjectToVAT;
	
	PaymentDetails.Clear();
	If DocRefLoanContract.LoanKind = Enums.LoanContractTypes.EmployeeLoanAgreement Then
		NewRow = PaymentDetails.Add();
		FillPropertyValues(NewRow, Selection);
	Else
		DocumentAmount = 0;
	EndIf;
	
	PettyCash = Catalogs.CashAccounts.GetPettyCashByDefault(Company);
	
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
		Query.SetParameter("Counterparty",			FillingData.Accruals[0].Counterparty);
		Query.SetParameter("LoanContract",			FillingData.Accruals[0].LoanContract);
		Query.SetParameter("Currency",				FillingData.Accruals[0].SettlementsCurrency);
		
	Else
		Return;
	EndIf;
	
	Query.SetParameter("Date", ?(ValueIsFilled(Date), Date, CurrentDate()));
	
	Query.Text =
	"SELECT
	|	REFPRESENTATION(&Ref) AS Basis,
	|	VALUE(Enum.OperationTypesCashVoucher.LoanSettlements) AS OperationKind,
	|	&Ref AS BasisDocument,
	|	DocumentTable.Ref.Company AS Company,
	|	DocumentTable.SettlementsCurrency AS CashCurrency,
	|	DocumentTable.LoanContract AS LoanContract,
	|	DocumentTable.AmountType AS TypeOfAmount,
	|	DocumentTable.Total AS PaymentAmount,
	|	AccountingPolicySliceLast.DefaultVATRate AS VATRate,
	|	ISNULL(ExchangeRates.ExchangeRate, 1) AS ExchangeRate,
	|	ISNULL(ExchangeRates.Multiplicity, 1) AS Multiplicity,
	|	CAST(DocumentTable.Total AS NUMBER(15, 2)) AS SettlementsAmount,
	|	CAST(DocumentTable.Total * (1 - 1 / ((ISNULL(AccountingPolicySliceLast.DefaultVATRate.Rate, 0) + 100) / 100)) AS NUMBER(15, 2)) AS VATAmount,
	|	DocumentTable.LoanContract.Counterparty AS Counterparty
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
	
	If QueryResult.IsEmpty() Then
		Return;
	EndIf;
	
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
	
EndProcedure

#EndRegion

#EndRegion

#EndIf
