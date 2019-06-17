#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ProgramInterface

// Procedure fills advances.
//
Procedure FillPrepayment()Export
	
	ParentCompany = DriveServer.GetCompany(Company);
	
	// Preparation of the order table.
	OrdersTable = Inventory.Unload(, "PurchaseOrder, Total");
	OrdersTable.Columns.Add("TotalCalc");
	For Each CurRow In OrdersTable Do
		If Not Counterparty.DoOperationsByOrders Then
			CurRow.PurchaseOrder = Documents.PurchaseOrder.EmptyRef();
		EndIf;
		CurRow.TotalCalc = DriveServer.RecalculateFromCurrencyToCurrency(
			CurRow.Total,
			?(Contract.SettlementsCurrency = DocumentCurrency, ExchangeRate, 1),
			ExchangeRate,
			?(Contract.SettlementsCurrency = DocumentCurrency, Multiplicity, 1),
			Multiplicity
		);
	EndDo;
	OrdersTable.GroupBy("PurchaseOrder", "Total, TotalCalc");
	OrdersTable.Sort("PurchaseOrder Asc");

	
	// Filling prepayment details.
	Query = New Query;
	QueryText =
	"SELECT ALLOWED
	|	AccountsPayableBalances.Document AS Document,
	|	AccountsPayableBalances.Order AS Order,
	|	AccountsPayableBalances.DocumentDate AS DocumentDate,
	|	AccountsPayableBalances.Contract.SettlementsCurrency AS SettlementsCurrency,
	|	SUM(AccountsPayableBalances.AmountBalance) AS AmountBalance,
	|	SUM(AccountsPayableBalances.AmountCurBalance) AS AmountCurBalance
	|INTO TemporaryTableAccountsPayableBalances
	|FROM
	|	(SELECT
	|		AccountsPayableBalances.Contract AS Contract,
	|		AccountsPayableBalances.Document AS Document,
	|		AccountsPayableBalances.Document.Date AS DocumentDate,
	|		AccountsPayableBalances.Order AS Order,
	|		ISNULL(AccountsPayableBalances.AmountBalance, 0) AS AmountBalance,
	|		ISNULL(AccountsPayableBalances.AmountCurBalance, 0) AS AmountCurBalance
	|	FROM
	|		AccumulationRegister.AccountsPayable.Balance(
	|				,
	|				Company = &Company
	|					AND Counterparty = &Counterparty
	|					AND Contract = &Contract
	|					AND Order IN (&Order)
	|					AND SettlementsType = VALUE(Enum.SettlementsTypes.Advance)) AS AccountsPayableBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsVendorSettlements.Contract,
	|		DocumentRegisterRecordsVendorSettlements.Document,
	|		DocumentRegisterRecordsVendorSettlements.Document.Date,
	|		DocumentRegisterRecordsVendorSettlements.Order,
	|		CASE
	|			WHEN DocumentRegisterRecordsVendorSettlements.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -ISNULL(DocumentRegisterRecordsVendorSettlements.Amount, 0)
	|			ELSE ISNULL(DocumentRegisterRecordsVendorSettlements.Amount, 0)
	|		END,
	|		CASE
	|			WHEN DocumentRegisterRecordsVendorSettlements.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -ISNULL(DocumentRegisterRecordsVendorSettlements.AmountCur, 0)
	|			ELSE ISNULL(DocumentRegisterRecordsVendorSettlements.AmountCur, 0)
	|		END
	|	FROM
	|		AccumulationRegister.AccountsPayable AS DocumentRegisterRecordsVendorSettlements
	|	WHERE
	|		DocumentRegisterRecordsVendorSettlements.Recorder = &Ref
	|		AND DocumentRegisterRecordsVendorSettlements.Period <= &Period
	|		AND DocumentRegisterRecordsVendorSettlements.Company = &Company
	|		AND DocumentRegisterRecordsVendorSettlements.Counterparty = &Counterparty
	|		AND DocumentRegisterRecordsVendorSettlements.Contract = &Contract
	|		AND DocumentRegisterRecordsVendorSettlements.Order IN (&Order)
	|		AND DocumentRegisterRecordsVendorSettlements.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)) AS AccountsPayableBalances
	|
	|GROUP BY
	|	AccountsPayableBalances.Document,
	|	AccountsPayableBalances.Order,
	|	AccountsPayableBalances.DocumentDate,
	|	AccountsPayableBalances.Contract.SettlementsCurrency
	|
	|HAVING
	|	SUM(AccountsPayableBalances.AmountCurBalance) < 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	AccountsPayableBalances.Document AS Document,
	|	AccountsPayableBalances.Order AS Order,
	|	AccountsPayableBalances.DocumentDate AS DocumentDate,
	|	AccountsPayableBalances.SettlementsCurrency AS SettlementsCurrency,
	|	-SUM(AccountsPayableBalances.AccountingAmount) AS AccountingAmount,
	|	-SUM(AccountsPayableBalances.SettlementsAmount) AS SettlementsAmount,
	|	-SUM(AccountsPayableBalances.PaymentAmount) AS PaymentAmount,
	|	SUM(AccountsPayableBalances.AccountingAmount / CASE
	|			WHEN ISNULL(AccountsPayableBalances.SettlementsAmount, 0) <> 0
	|				THEN AccountsPayableBalances.SettlementsAmount
	|			ELSE 1
	|		END) * (AccountsPayableBalances.SettlementsCurrencyExchangeRatesRate / AccountsPayableBalances.SettlementsCurrencyExchangeRatesMultiplicity) AS ExchangeRate,
	|	1 AS Multiplicity,
	|	AccountsPayableBalances.DocumentCurrencyExchangeRatesRate AS DocumentCurrencyExchangeRatesRate,
	|	AccountsPayableBalances.DocumentCurrencyExchangeRatesMultiplicity AS DocumentCurrencyExchangeRatesMultiplicity
	|FROM
	|	(SELECT
	|		AccountsPayableBalances.SettlementsCurrency AS SettlementsCurrency,
	|		AccountsPayableBalances.Document AS Document,
	|		AccountsPayableBalances.DocumentDate AS DocumentDate,
	|		AccountsPayableBalances.Order AS Order,
	|		ISNULL(AccountsPayableBalances.AmountBalance, 0) AS AccountingAmount,
	|		ISNULL(AccountsPayableBalances.AmountCurBalance, 0) AS SettlementsAmount,
	|		ISNULL(AccountsPayableBalances.AmountBalance, 0) * SettlementsCurrencyExchangeRates.ExchangeRate * &MultiplicityOfDocumentCurrency / (&DocumentCurrencyRate * SettlementsCurrencyExchangeRates.Multiplicity) AS PaymentAmount,
	|		SettlementsCurrencyExchangeRates.ExchangeRate AS SettlementsCurrencyExchangeRatesRate,
	|		SettlementsCurrencyExchangeRates.Multiplicity AS SettlementsCurrencyExchangeRatesMultiplicity,
	|		&DocumentCurrencyRate AS DocumentCurrencyExchangeRatesRate,
	|		&MultiplicityOfDocumentCurrency AS DocumentCurrencyExchangeRatesMultiplicity
	|	FROM
	|		TemporaryTableAccountsPayableBalances AS AccountsPayableBalances
	|			LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&Period, Currency = &PresentationCurrency) AS SettlementsCurrencyExchangeRates
	|			ON (TRUE)) AS AccountsPayableBalances
	|
	|GROUP BY
	|	AccountsPayableBalances.Document,
	|	AccountsPayableBalances.Order,
	|	AccountsPayableBalances.DocumentDate,
	|	AccountsPayableBalances.SettlementsCurrency,
	|	AccountsPayableBalances.SettlementsCurrencyExchangeRatesRate,
	|	AccountsPayableBalances.SettlementsCurrencyExchangeRatesMultiplicity,
	|	AccountsPayableBalances.DocumentCurrencyExchangeRatesRate,
	|	AccountsPayableBalances.DocumentCurrencyExchangeRatesMultiplicity
	|
	|HAVING
	|	-SUM(AccountsPayableBalances.SettlementsAmount) > 0
	|
	|ORDER BY
	|	DocumentDate";
	
	Query.SetParameter("Order", OrdersTable.UnloadColumn("PurchaseOrder"));
	
	Query.SetParameter("Company", ParentCompany);
	Query.SetParameter("Counterparty", Counterparty);
	Query.SetParameter("Contract", Contract);
	Query.SetParameter("Period", Date);
	Query.SetParameter("DocumentCurrency", DocumentCurrency);
	Query.SetParameter("PresentationCurrency", Constants.PresentationCurrency.Get());
	If Contract.SettlementsCurrency = DocumentCurrency Then
		Query.SetParameter("DocumentCurrencyRate", ExchangeRate);
		Query.SetParameter("MultiplicityOfDocumentCurrency", Multiplicity);
	Else
		Query.SetParameter("DocumentCurrencyRate", 1);
		Query.SetParameter("MultiplicityOfDocumentCurrency", 1);
	EndIf;
	Query.SetParameter("Ref", Ref);
	
	Query.Text = QueryText;
	
	Prepayment.Clear();
	
	SelectionOfQueryResult = Query.Execute().Select();
	
	While SelectionOfQueryResult.Next() Do
		
		FoundString = OrdersTable.Find(SelectionOfQueryResult.Order, "PurchaseOrder");
		
		If FoundString.TotalCalc = 0 Then
			Continue;
		EndIf;
		
		If SelectionOfQueryResult.SettlementsAmount <= FoundString.TotalCalc  Then // balance amount is less or equal than it is necessary to distribute
			
			NewRow = Prepayment.Add();
			FillPropertyValues(NewRow, SelectionOfQueryResult);
			FoundString.TotalCalc = FoundString.TotalCalc - SelectionOfQueryResult.SettlementsAmount;
			
		Else // Balance amount is greater than it is necessary to distribute
			
			NewRow = Prepayment.Add();
			FillPropertyValues(NewRow, SelectionOfQueryResult);
			NewRow.SettlementsAmount = FoundString.TotalCalc;
			NewRow.PaymentAmount = DriveServer.RecalculateFromCurrencyToCurrency(
				NewRow.SettlementsAmount,
				SelectionOfQueryResult.ExchangeRate,
				SelectionOfQueryResult.DocumentCurrencyExchangeRatesRate,
				SelectionOfQueryResult.Multiplicity,
				SelectionOfQueryResult.DocumentCurrencyExchangeRatesMultiplicity
			);
			FoundString.TotalCalc = 0;
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Procedure of the document filling according to the header attributes.
//
Procedure FillByHeaderAttributes()
	
	Query = New Query();
	Query.SetParameter("Company",		DriveServer.GetCompany(Company));
	Query.SetParameter("Counterparty",			Counterparty);
	Query.SetParameter("Contract",			Contract);
	Query.SetParameter("SettlementsCurrency",		Contract.SettlementsCurrency);
	Query.SetParameter("DocumentCurrency",	DocumentCurrency);
	Query.SetParameter("EndOfPeriod",		CurrentDate());
	Query.SetParameter("SupplierPriceTypes",	SupplierPriceTypes);
	Query.SetParameter("PriceKindCurrency",		SupplierPriceTypes.PriceCurrency);
	Query.SetParameter("Ref",				Ref);
	Query.SetParameter("PresentationCurrency",		Constants.PresentationCurrency.Get());
	
	// Define date of the last report
	Query.Text = 
	"SELECT TOP 1
	|	AccountSalesToConsignor.Date AS Date
	|FROM
	|	Document.AccountSalesToConsignor AS AccountSalesToConsignor
	|WHERE
	|	AccountSalesToConsignor.Posted
	|	AND AccountSalesToConsignor.Company = &Company
	|	AND AccountSalesToConsignor.Counterparty = &Counterparty
	|	AND AccountSalesToConsignor.Contract = &Contract
	|	AND AccountSalesToConsignor.Date < &EndOfPeriod
	|	AND AccountSalesToConsignor.Ref <> &Ref
	|
	|ORDER BY
	|	Date DESC";
	Result = Query.Execute();
	If Result.IsEmpty() Then
		Query.SetParameter("BeginOfPeriod",Undefined);
	Else
		Selection = Result.Select();
		Selection.Next();
		Query.SetParameter("BeginOfPeriod",Selection.Date);
	EndIf;
	
	// Define the amount of sold goods and purchase prices
	Query.Text = 
	"SELECT ALLOWED
	|	AccountingPolicySliceLast.DefaultVATRate AS CompanyVATRate,
	|	SalesTurnovers.Products AS Products,
	|	SalesTurnovers.Products.VATRate AS ProductsVATRate,
	|	SalesTurnovers.Characteristic AS Characteristic,
	|	SalesTurnovers.Batch AS Batch,
	|	SalesTurnovers.SalesOrder AS SalesOrder,
	|	CASE
	|		WHEN VALUETYPE(SalesTurnovers.Document) = TYPE(Document.SalesInvoice)
	|			THEN SalesTurnovers.Document.Counterparty
	|	END AS Customer,
	|	CASE
	|		WHEN VALUETYPE(SalesTurnovers.Document) = TYPE(Document.SalesInvoice)
	|			THEN SalesTurnovers.Document.Date
	|	END AS DateOfSale,
	|	SalesTurnovers.QuantityTurnover AS Quantity,
	|	SalesTurnovers.Products.MeasurementUnit AS MeasurementUnit,
	|	CASE
	|		WHEN SalesTurnovers.QuantityTurnover > 0
	|			THEN CASE
	|					WHEN &DocumentCurrency = &PresentationCurrency
	|						THEN (SalesTurnovers.AmountTurnover + SalesTurnovers.VATAmountTurnover) / SalesTurnovers.QuantityTurnover
	|					ELSE ISNULL((SalesTurnovers.AmountTurnover + SalesTurnovers.VATAmountTurnover) * AccountingCurrencyRate.ExchangeRate * DocumentCurrencyRate.Multiplicity / (DocumentCurrencyRate.ExchangeRate * AccountingCurrencyRate.Multiplicity), 0) / SalesTurnovers.QuantityTurnover
	|				END
	|		ELSE 0
	|	END AS Price,
	|	CASE
	|		WHEN &DocumentCurrency = &PresentationCurrency
	|			THEN SalesTurnovers.AmountTurnover + SalesTurnovers.VATAmountTurnover
	|		ELSE (SalesTurnovers.AmountTurnover + SalesTurnovers.VATAmountTurnover) * AccountingCurrencyRate.ExchangeRate * DocumentCurrencyRate.Multiplicity / (DocumentCurrencyRate.ExchangeRate * AccountingCurrencyRate.Multiplicity)
	|	END AS Amount,
	|	ISNULL(CASE
	|			WHEN &DocumentCurrency = &PriceKindCurrency
	|				THEN FixedReceiptPrices.Price
	|			ELSE FixedReceiptPrices.Price * PriceKindCurrencyRate.ExchangeRate * DocumentCurrencyRate.Multiplicity / (DocumentCurrencyRate.ExchangeRate * PriceKindCurrencyRate.Multiplicity)
	|		END, 0) AS ReceiptPrice,
	|	StockReceivedFromThirdPartiesBalances.Order AS PurchaseOrder
	|FROM
	|	AccumulationRegister.Sales.Turnovers(
	|			&BeginOfPeriod,
	|			&EndOfPeriod,
	|			,
	|			Company = &Company
	|				AND Batch.Status = VALUE(Enum.BatchStatuses.CounterpartysInventory)
	|				AND Batch.BatchOwner = &Counterparty) AS SalesTurnovers
	|		LEFT JOIN AccumulationRegister.StockReceivedFromThirdParties.Balance(
	|				&EndOfPeriod,
	|				Company = &Company
	|					AND Counterparty = &Counterparty
	|					AND Contract = &Contract) AS StockReceivedFromThirdPartiesBalances
	|		ON (StockReceivedFromThirdPartiesBalances.Products = SalesTurnovers.Products)
	|			AND (StockReceivedFromThirdPartiesBalances.Characteristic = SalesTurnovers.Characteristic)
	|			AND (StockReceivedFromThirdPartiesBalances.Batch = SalesTurnovers.Batch)
	|		LEFT JOIN InformationRegister.CounterpartyPrices.SliceLast(
	|				&EndOfPeriod,
	|				SupplierPriceTypes = &SupplierPriceTypes
	|					AND Actuality) AS FixedReceiptPrices
	|		ON (FixedReceiptPrices.Products = SalesTurnovers.Products)
	|			AND (FixedReceiptPrices.Characteristic = SalesTurnovers.Characteristic)
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&EndOfPeriod, Currency = &SettlementsCurrency) AS SettlementsCurrencyRate
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&EndOfPeriod, Currency = &DocumentCurrency) AS DocumentCurrencyRate
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&EndOfPeriod, Currency = &PresentationCurrency) AS AccountingCurrencyRate
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&EndOfPeriod, Currency = &PriceKindCurrency) AS PriceKindCurrencyRate
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.AccountingPolicy.SliceLast(&EndOfPeriod, ) AS AccountingPolicySliceLast
	|		ON SalesTurnovers.Company = AccountingPolicySliceLast.Company
	|WHERE
	|	SalesTurnovers.QuantityTurnover > 0
	|	AND StockReceivedFromThirdPartiesBalances.QuantityBalance > 0";
	
	RemunerationVATRateNumber = DriveReUse.GetVATRateValue(VATCommissionFeePercent);
	
	// Refill the Inventory tabular section
	Inventory.Clear();
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		
		NewRow = Inventory.Add();
		FillPropertyValues(NewRow, Selection);
		
		// VAT rate, VATAmount and Total
		If VATTaxation <> Enums.VATTaxationTypes.SubjectToVAT Then
			If VATTaxation = Enums.VATTaxationTypes.NotSubjectToVAT Then
				NewRow.VATRate = Catalogs.VATRates.Exempt;
			Else
				NewRow.VATRate = Catalogs.VATRates.ZeroRate;
			EndIf;	
		ElsIf ValueIsFilled(Selection.ProductsVATRate) Then
			NewRow.VATRate = Selection.ProductsVATRate;
		Else
			NewRow.VATRate = Selection.CompanyVATRate;
		EndIf;
		VATRate = DriveReUse.GetVATRateValue(NewRow.VATRate);
		
		NewRow.VATAmount = ?(AmountIncludesVAT, 
								 NewRow.Amount - (NewRow.Amount) / ((VATRate + 100) / 100),
								 NewRow.Amount * VATRate / 100);
		
		NewRow.Total = NewRow.Amount + ?(AmountIncludesVAT, 0, NewRow.VATAmount);
		
		// Receipt amount and VAT.
		NewRow.AmountReceipt = NewRow.Quantity * NewRow.ReceiptPrice;
		
		NewRow.ReceiptVATAmount = ?(AmountIncludesVAT, 
											NewRow.AmountReceipt - (NewRow.AmountReceipt) / ((VATRate + 100) / 100),
											NewRow.AmountReceipt * VATRate / 100);
		
		// Fee
		If BrokerageCalculationMethod <> Enums.CommissionFeeCalculationMethods.IsNotCalculating Then

			If BrokerageCalculationMethod = Enums.CommissionFeeCalculationMethods.PercentFromSaleAmount Then
	
				NewRow.BrokerageAmount = CommissionFeePercent * NewRow.Amount / 100;
	
			ElsIf BrokerageCalculationMethod = Enums.CommissionFeeCalculationMethods.PercentFromDifferenceOfSaleAndAmountReceipts Then

				NewRow.BrokerageAmount = CommissionFeePercent * (NewRow.Amount - NewRow.AmountReceipt) / 100;

			Else
		
				NewRow.BrokerageAmount = 0;
		
			EndIf;
			
		EndIf;
	
		NewRow.BrokerageVATAmount = ?(AmountIncludesVAT, 
												NewRow.BrokerageAmount - (NewRow.BrokerageAmount) / ((RemunerationVATRateNumber + 100) / 100),
												NewRow.BrokerageAmount * RemunerationVATRateNumber / 100);
		
	EndDo;
	
EndProcedure

// Procedure of filling the document on the basis of the supplier invoice.
//
// Parameters:
// BasisDocument - DocumentRef.SupplierInvoice - supplier
// invoice FillingData - Structure - Document filling
//	data
Procedure FillByGoodsReceipt(FillingData)
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	Header.Ref AS Ref,
	|	Header.Company AS Company,
	|	Header.Counterparty AS Counterparty,
	|	Header.Contract AS Contract
	|INTO Header
	|FROM
	|	Document.GoodsReceipt AS Header
	|WHERE
	|	Header.Ref = &BasisDocument
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Header.Company AS Company,
	|	Header.Counterparty AS Counterparty,
	|	Header.Contract AS Contract,
	|	Contracts.SettlementsCurrency AS SettlementsCurrency,
	|	GRProducts.Products AS Products,
	|	GRProducts.Characteristic AS Characteristic,
	|	GRProducts.Batch AS Batch,
	|	GRProducts.Quantity AS Quantity,
	|	GRProducts.MeasurementUnit AS MeasurementUnit,
	|	GRProducts.Order AS SalesOrder,
	|	ISNULL(SalesOrderRef.SalesRep, Counterparties.SalesRep) AS SalesRep,
	|	0 AS ConnectionKey,
	|	GRProducts.ConnectionKey AS ConnectionKeySerialNumbes,
	|	Contracts.PaymentMethod AS PaymentMethod,
	|	Companies.BankAccountByDefault AS BankAccountByDefault,
	|	Companies.PettyCashByDefault AS PettyCashByDefault,
	|	Contracts.PriceKind AS PriceKind
	|FROM
	|	Header AS Header
	|		INNER JOIN Document.GoodsReceipt.Products AS GRProducts
	|		ON Header.Ref = GRProducts.Ref
	|		LEFT JOIN Catalog.CounterpartyContracts AS Contracts
	|		ON (GRProducts.Ref.Contract = Contracts.Ref)
	|		LEFT JOIN Catalog.Companies AS Companies
	|		ON (GRProducts.Ref.Company = Companies.Ref)
	|		LEFT JOIN Document.SalesOrder AS SalesOrderRef
	|		ON GRProducts.Order = SalesOrderRef.Ref
	|		LEFT JOIN Catalog.Counterparties AS Counterparties
	|		ON Header.Counterparty = Counterparties.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Calendar.Term AS Term,
	|	Calendar.DuePeriod AS DuePeriod,
	|	Calendar.PaymentPercentage AS PaymentPercentage
	|FROM
	|	Catalog.CounterpartyContracts.StagesOfPayment AS Calendar
	|		INNER JOIN Header AS Header
	|		ON (Header.Contract = Calendar.Ref)";
	
	Query.SetParameter("BasisDocument", FillingData);
	
	QueryResultFull = Query.ExecuteBatch();
	QueryResult = QueryResultFull[1];
	
	QueryResultSelection = QueryResult.Select();
	
	QueryResultSelection.Next();
	FillPropertyValues(ThisObject, QueryResultSelection);
	
	If DocumentCurrency <> Constants.FunctionalCurrency.Get() Then
		StructureByCurrency = InformationRegisters.ExchangeRates.GetLast(Date, New Structure("Currency", QueryResultSelection.SettlementsCurrency));
		ExchangeRate = StructureByCurrency.ExchangeRate;
		Multiplicity = StructureByCurrency.Multiplicity;
	EndIf;
	
	QueryResultSelection.Reset();
	While QueryResultSelection.Next() Do
		NewRow = Inventory.Add();
		FillPropertyValues(NewRow, QueryResultSelection);
	EndDo;
	
	If GetFunctionalOption("UseSerialNumbers") Then
		SerialNumbers.Load(FillingData.SerialNumbers.Unload());
		For Each Str In Inventory Do
			Str.SerialNumbers = WorkWithSerialNumbersClientServer.StringPresentationOfSerialNumbersOfLine(SerialNumbers, Str.ConnectionKey);
		EndDo;
	EndIf;
	
	QueryResult = QueryResultFull[2];
	SessionDate = CurrentSessionDate();
	
	CalendarSelection = QueryResult.Select();
	While CalendarSelection.Next() Do
		
		NewLine = PaymentCalendar.Add();
		NewLine.PaymentPercentage = CalendarSelection.PaymentPercentage;
		
		If CalendarSelection.Term = Enums.PaymentTerm.PaymentInAdvance Then
			NewLine.PaymentDate = SessionDate - CalendarSelection.DuePeriod * 86400;
		Else
			NewLine.PaymentDate = SessionDate + CalendarSelection.DuePeriod * 86400;
		EndIf;
		
	EndDo;
	
	SetPaymentTerms = False;
	If QueryResultSelection.PaymentMethod = Enums.CashAssetTypes.Noncash Then
		BankAccount = QueryResultSelection.BankAccountByDefault;
	ElsIf QueryResultSelection = Enums.CashAssetTypes.Cash Then
		PettyCash = QueryResultSelection.PettyCashByDefault;
	EndIf;
	
EndProcedure

#EndRegion

#Region EventHandlers

// Procedure - event handler FillingProcessor object.
//
Procedure Filling(FillingData, StandardProcessing) Export
	
	If Not ValueIsFilled(FillingData) Then
		Return;
	EndIf;
	
	If TypeOf(FillingData) = Type("CatalogRef.Counterparties") Then
	
		Counterparty	= FillingData;
		Contract		= FillingData.ContractByDefault;
		
		DocumentCurrency	= Contract.SettlementsCurrency;
		StructureByCurrency	= InformationRegisters.ExchangeRates.GetLast(Date, New Structure("Currency", Contract.SettlementsCurrency));
		ExchangeRate		= StructureByCurrency.ExchangeRate;
		Multiplicity		= StructureByCurrency.Multiplicity;
		
		SettingValue = DriveReUse.GetValueByDefaultUser(Users.CurrentUser(), "MainCompany");
		If ValueIsFilled(SettingValue) Then
			If Company <> SettingValue Then
				Company = SettingValue;
			EndIf;
		Else
			Company = Catalogs.Companies.MainCompany;
		EndIf;
		
		VATTaxation = DriveServer.CounterpartyVATTaxation(Counterparty, DriveServer.VATTaxation(Company, Date));
		
		FillByHeaderAttributes();
		
	ElsIf TypeOf(FillingData) = Type("DocumentRef.GoodsReceipt") Then
		
		If FillingData.OperationType = Enums.OperationTypesGoodsReceipt.ReceiptFromAThirdParty Then
			FillByGoodsReceipt(FillingData);
		Else
			Raise NStr("en = 'Please select a goods receipt with ""Receipt from a third party"" operation.'");
		EndIf;
		
	ElsIf TypeOf(FillingData) = Type("Structure") Then
		
		FillPropertyValues(ThisObject, FillingData);
		
		FillByHeaderAttributes();
		
	EndIf;
	
	WorkWithVAT.ForbidReverseChargeTaxationTypeDocumentGeneration(ThisObject);
	
EndProcedure

// Procedure - event handler FillCheckProcessing object.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	TableInventory = Inventory.Unload(, "PurchaseOrder, Total");
	TableInventory.GroupBy("PurchaseOrder", "Total");
	
	TablePrepayment = Prepayment.Unload(, "Order, PaymentAmount");
	TablePrepayment.GroupBy("Order", "PaymentAmount");
	
	QuantityInventory = Inventory.Count();
	
	For Each String In TablePrepayment Do
		
		FoundStringWorksAndServices = Undefined;
		
		If Counterparty.DoOperationsByOrders
		   AND String.Order <> Undefined
		   AND String.Order <> Documents.PurchaseOrder.EmptyRef() Then
			FoundStringInventory = Inventory.Find(String.Order, "PurchaseOrder");
			Total = ?(FoundStringInventory = Undefined, 0, FoundStringInventory.Total);
		ElsIf Counterparty.DoOperationsByOrders Then
			FoundStringInventory = TableInventory.Find(Undefined, "PurchaseOrder");
			FoundStringInventory = ?(FoundStringInventory = Undefined, TableInventory.Find(Documents.PurchaseOrder.EmptyRef(), "PurchaseOrder"), FoundStringInventory);
			Total = ?(FoundStringInventory = Undefined, 0, FoundStringInventory.Total);
		Else
			Total = Inventory.Total("Total");
		EndIf;
		
		If FoundStringInventory = Undefined
		   AND QuantityInventory > 0
		   AND Counterparty.DoOperationsByOrders Then
			MessageText = NStr("en = 'Cannot register the advance payment because the order to be paid is not listed on the Goods tab'");
			DriveServer.ShowMessageAboutError(
				,
				MessageText,
				Undefined,
				Undefined,
				"PrepaymentTotalSettlementsAmountCurrency",
				Cancel
			);
		EndIf;
	EndDo;
	
	If Not Counterparty.DoOperationsByContracts Then
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Contract");
	EndIf;
	
	//Payment calendar
	If KeepBackComissionFee Then
		InventoryTotal = Inventory.Total("Total");
		VATAmount = Inventory.Total("VATAmount") - Inventory.Total("BrokerageVATAmount");
		Amount = Round(InventoryTotal - (CommissionFeePercent * InventoryTotal / 100) - VATAmount, 2);
	Else
		VATAmount = Inventory.Total("VATAmount");
		Amount = Inventory.Total("Amount");
	EndIf;
	PaymentTermsServer.CheckCorrectPaymentCalendar(ThisObject, Cancel, Amount, VATAmount);
	
EndProcedure

// Procedure - event handler BeforeWrite object.
//
Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If ValueIsFilled(Counterparty)
	AND Not Counterparty.DoOperationsByContracts
	AND Not ValueIsFilled(Contract) Then
		Contract = Counterparty.ContractByDefault;
	EndIf;
	
	DocumentAmount = Inventory.Total("Total");
	
EndProcedure

// Procedure - event handler Posting object.
//
Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting.
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Document data initialization.
	Documents.AccountSalesToConsignor.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Preparation of records sets.
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Account for in accounting sections.
	DriveServer.ReflectSales(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectInventoryAccepted(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectIncomeAndExpenses(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountsPayable(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectIncomeAndExpensesCashMethod(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectUnallocatedExpenses(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectIncomeAndExpensesRetained(AdditionalProperties, RegisterRecords, Cancel);
	
	DriveServer.ReflectAccountingJournalEntries(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectPaymentCalendar(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectUsingPaymentTermsInDocuments(Ref, Cancel);
	
	// SerialNumbers
	DriveServer.ReflectTheSerialNumbersOfTheGuarantee(AdditionalProperties, RegisterRecords, Cancel);
	
	// Record of the records sets.
	DriveServer.WriteRecordSets(ThisObject);
	
	// Control of occurrence of a negative balance.
	Documents.AccountSalesToConsignor.RunControl(Ref, AdditionalProperties, Cancel);
	
	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
EndProcedure

// Procedure - event handler UndoPosting object.
//
Procedure UndoPosting(Cancel)
	
	// Initialization of additional properties for document posting.
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Preparation of records sets.
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Record of the records sets.
	DriveServer.WriteRecordSets(ThisObject);
	
	// Control of occurrence of a negative balance.
	Documents.AccountSalesToConsignor.RunControl(Ref, AdditionalProperties, Cancel, True);
	
EndProcedure

// Procedure - event handler of the OnCopy object.
//
Procedure OnCopy(CopiedObject)
	
	Prepayment.Clear();
	
EndProcedure

#EndRegion

#Region DocumentFillingProcedures

// Procedure of payment calendar filling based on contract.
//
Procedure FillPaymentCalendarFromContract() Export
	
	Query = New Query("
	|SELECT
	|	Table.Term AS Term,
	|	Table.DuePeriod AS DuePeriod,
	|	Table.PaymentPercentage AS PaymentPercentage
	|FROM
	|	Catalog.CounterpartyContracts.StagesOfPayment AS Table
	|WHERE
	|	Table.Ref = &Ref
	|");
	
	Query.SetParameter("Ref", Contract);
	
	Result = Query.Execute();
	DataSelection = Result.Select();
	
	If Result.IsEmpty() Then
		Return;
	EndIf;
	
	PaymentCalendar.Clear();
	
	TotalAmountForCorrectBalance = 0;
	TotalVATForCorrectBalance = 0;
	
	If KeepBackComissionFee Then
		InventoryTotal = Inventory.Total("Amount");
		TotalAmount = InventoryTotal - (CommissionFeePercent * InventoryTotal / 100)
		- (Inventory.Total("VATAmount") - Inventory.Total("BrokerageVATAmount"));
	Else
		TotalAmount = Inventory.Total("Amount");
	EndIf;
	
	If KeepBackComissionFee Then
		TotalVAT = Inventory.Total("VATAmount") - Inventory.Total("BrokerageVATAmount");
	Else
		TotalVAT = Inventory.Total("VATAmount")
	EndIf;
	
	DocumentDate = ?(ValueIsFilled(Date), Date, CurrentSessionDate());
	
	While DataSelection.Next() Do
		
		NewLine = PaymentCalendar.Add();
		
		If DataSelection.Term = Enums.PaymentTerm.PaymentInAdvance Then
			NewLine.PaymentDate = DocumentDate - DataSelection.DuePeriod * 86400;
		Else
			NewLine.PaymentDate = DocumentDate + DataSelection.DuePeriod * 86400;
		EndIf;
		
		NewLine.PaymentPercentage = DataSelection.PaymentPercentage;
		NewLine.PaymentAmount = Round(TotalAmount * NewLine.PaymentPercentage / 100, 2, RoundMode.Round15as20);
		NewLine.PaymentVATAmount = Round(TotalVAT * NewLine.PaymentPercentage / 100, 2, RoundMode.Round15as20);
		
		TotalAmountForCorrectBalance = TotalAmountForCorrectBalance + NewLine.PaymentAmount;
		TotalVATForCorrectBalance = TotalVATForCorrectBalance + NewLine.PaymentVATAmount;
		
	EndDo;
	
	// correct balance
	NewLine.PaymentAmount = NewLine.PaymentAmount + (TotalAmount - TotalAmountForCorrectBalance);
	NewLine.PaymentVATAmount = NewLine.PaymentVATAmount + (TotalVAT - TotalVATForCorrectBalance);
	
	SetPaymentTerms = True;
	CashAssetsType = CommonUse.ObjectAttributeValue(Contract, "PaymentMethod");
	
	If CashAssetsType = Enums.CashAssetTypes.Noncash Then
		BankAccountByDefault = CommonUse.ObjectAttributeValue(Company, "BankAccountByDefault");
		If ValueIsFilled(BankAccountByDefault) Then
			BankAccount = BankAccountByDefault;
		EndIf;
	ElsIf CashAssetsType = Enums.CashAssetTypes.Cash Then
		PettyCashByDefault = CommonUse.ObjectAttributeValue(Company, "PettyCashByDefault");
		If ValueIsFilled(PettyCashByDefault) Then
			PettyCash = PettyCashByDefault;
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#EndIf
