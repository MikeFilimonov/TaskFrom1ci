#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Interface

// Procedure distributes expenses by quantity.
//
Procedure DistributeTabSectExpensesByQuantity() Export
	
	SrcAmount = 0;
	
	DistributionBaseQuantity = Inventory.Total("Quantity");
	
	TotalExpenses = ExpensesAmountToBeAllocated();
	
	For Each StringInventory In Inventory Do
		
		StringInventory.AmountExpense = ?(DistributionBaseQuantity <> 0, Round((TotalExpenses - SrcAmount) * StringInventory.Quantity / DistributionBaseQuantity, 2, 1), 0);
		CalculateReverseChargeVATAmount(StringInventory);
		
		DistributionBaseQuantity = DistributionBaseQuantity - StringInventory.Quantity;
		SrcAmount = SrcAmount + StringInventory.AmountExpense;
		
	EndDo;
	
EndProcedure

// Procedure distributes expenses by amount.
//
Procedure DistributeTabSectExpensesByAmount() Export
	
	SrcAmount = 0;
	
	ReserveAmount = Inventory.Total("Total");
	
	TotalExpenses = ExpensesAmountToBeAllocated();
	
	For Each StringInventory In Inventory Do
		
		StringInventory.AmountExpense = ?(ReserveAmount <> 0, Round((TotalExpenses - SrcAmount) * StringInventory.Total / ReserveAmount, 2, 1),0);
		CalculateReverseChargeVATAmount(StringInventory);
		
		ReserveAmount = ReserveAmount - StringInventory.Total;
		SrcAmount = SrcAmount + StringInventory.AmountExpense;
		
	EndDo;
	
EndProcedure

Procedure CalculateReverseChargeVATAmount(TabularSectionRow)
	
	If VATTaxation = Enums.VATTaxationTypes.ReverseChargeVAT Then
		
		VATRate = DriveReUse.GetVATRateValue(TabularSectionRow.ReverseChargeVATRate);
		TabularSectionRow.ReverseChargeVATAmount = (TabularSectionRow.Total + TabularSectionRow.AmountExpense) * VATRate / 100;
		
	EndIf;
	
EndProcedure

Function ExpensesAmountToBeAllocated()
	
	TotalExpenses = Expenses.Total("Total");
	If VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then
		TotalExpenses = TotalExpenses - Expenses.Total("VATAmount");
	EndIf;
	
	Return TotalExpenses;
	
EndFunction

Procedure CheckPermissionToChangeWarehouse(Cancel)
	
	If IsNew() Then
		
		Return;
		
	EndIf;
	
	Query = New Query;
	
	Query.Text =
	"SELECT
	|	CustomsDeclarationInventory.Ref AS Ref
	|INTO TT_CD
	|FROM
	|	Document.CustomsDeclaration.Inventory AS CustomsDeclarationInventory
	|WHERE
	|	CustomsDeclarationInventory.Invoice = &Ref
	|	AND CustomsDeclarationInventory.StructuralUnit <> &StructuralUnit
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	TT_CD.Ref AS Ref
	|FROM
	|	TT_CD AS TT_CD
	|		INNER JOIN Document.CustomsDeclaration AS CustomsDeclaration
	|		ON TT_CD.Ref = CustomsDeclaration.Ref
	|WHERE
	|	CustomsDeclaration.Posted";
	
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("StructuralUnit", StructuralUnit);
	
	If Not Query.Execute().IsEmpty() Then
		
		MessageText = NStr(
			"en = 'You can''t change the warehouse, because landed costs have already been allocated by the Customs declaration.
			|Please clear posting of the subordinate Customs declaration and try again.'");
		
		DriveServer.ShowMessageAboutError(
			ThisObject,
			MessageText,
			,
			,
			"StructuralUnit",
			Cancel);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region DocumentFillingProcedures

Procedure FillByStructure(FillingData) Export
	
	If FillingData.Property("ArrayOfPurchaseOrders") Then
		FillByPurchaseOrder(FillingData);
	ElsIf FillingData.Property("GoodsReceiptArray") Then
		FillByGoodsReceipt(FillingData);
	EndIf;
	
EndProcedure

// Procedure fills advances.
//
Procedure FillPrepayment() Export
	
	OrderInHeader = (PurchaseOrderPosition = Enums.AttributeStationing.InHeader);
	ParentCompany = DriveServer.GetCompany(Company);
	
	// Preparation of the order table.
	OrdersTable = Inventory.Unload(, "Order, Total");
	OrdersTable.Columns.Add("TotalCalc");
	For Each CurRow In Expenses Do
		NewRow = OrdersTable.Add();
		NewRow.Order = CurRow.PurchaseOrder;
		NewRow.Total = CurRow.Total;
	EndDo;
	For Each CurRow In OrdersTable Do
		If Not Counterparty.DoOperationsByOrders Then
			CurRow.Order = Documents.PurchaseOrder.EmptyRef();
		ElsIf OrderInHeader Then
			CurRow.Order = Order;
		Else
			CurRow.Order = ?(CurRow.Order = Undefined, Documents.PurchaseOrder.EmptyRef(), CurRow.Order);
		EndIf;
		CurRow.TotalCalc = DriveServer.RecalculateFromCurrencyToCurrency(
			CurRow.Total,
			?(Contract.SettlementsCurrency = DocumentCurrency, ExchangeRate, 1),
			ExchangeRate,
			?(Contract.SettlementsCurrency = DocumentCurrency, Multiplicity, 1),
			Multiplicity
		);
	EndDo;
	OrdersTable.GroupBy("Order", "Total, TotalCalc");
	OrdersTable.Sort("Order Asc");
	
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
	
	Query.SetParameter("Order", OrdersTable.UnloadColumn("Order"));
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
		
		FoundString = OrdersTable.Find(SelectionOfQueryResult.Order, "Order");
		
		If FoundString.TotalCalc = 0 Then
			Continue;
		EndIf;
		
		If SelectionOfQueryResult.SettlementsAmount <= FoundString.TotalCalc Then // balance amount is less or equal than it is necessary to distribute
			
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
	
	WorkWithVAT.FillPrepaymentVATFromVATInput(ThisObject);
	
EndProcedure

// Procedure of document filling based on purchase order.
//
// Parameters:
// FillingData - Structure - Document filling data
//	
Procedure FillByPurchaseOrder(FillingData) Export
	
	// Document basis and document setting.
	OrdersArray = New Array;
	If TypeOf(FillingData) = Type("Structure") AND FillingData.Property("ArrayOfPurchaseOrders") Then
		OrdersArray = FillingData.ArrayOfPurchaseOrders;
		PurchaseOrderPosition = Enums.AttributeStationing.InTabularSection;
	Else
		OrdersArray.Add(FillingData.Ref);
		PurchaseOrderPosition = DriveReUse.GetValueOfSetting("PurchaseOrderPositionInReceiptDocuments");
		If Not ValueIsFilled(PurchaseOrderPosition) Then
			PurchaseOrderPosition = Enums.AttributeStationing.InHeader;
		EndIf;
		If PurchaseOrderPosition = Enums.AttributeStationing.InHeader Then
			Order = FillingData;
		EndIf;
	EndIf;
	
	// Header filling.
	Query = New Query;
	Query.Text =
	"SELECT
	|	PurchaseOrder.Ref AS BasisRef,
	|	PurchaseOrder.Posted AS BasisPosted,
	|	PurchaseOrder.Closed AS Closed,
	|	PurchaseOrder.OrderState AS OrderState,
	|	PurchaseOrder.SalesOrder AS SalesOrder,
	|	PurchaseOrder.StructuralUnit AS StructuralUnitExpense,
	|	PurchaseOrder.Company AS Company,
	|	PurchaseOrder.Counterparty AS Counterparty,
	|	PurchaseOrder.Contract AS Contract,
	|	PurchaseOrder.DocumentCurrency AS DocumentCurrency,
	|	PurchaseOrder.AmountIncludesVAT AS AmountIncludesVAT,
	|	PurchaseOrder.IncludeVATInPrice AS IncludeVATInPrice,
	|	PurchaseOrder.VATTaxation AS VATTaxation,
	|	CASE
	|		WHEN PurchaseOrder.SupplierPriceTypes = VALUE(Catalog.SupplierPriceTypes.EmptyRef)
	|			THEN PurchaseOrder.Contract.SupplierPriceTypes
	|		ELSE PurchaseOrder.SupplierPriceTypes
	|	END AS SupplierPriceTypes,
	|	TRUE AS RegisterVendorPrices,
	|	CASE
	|		WHEN PurchaseOrder.DocumentCurrency = FunctionalCurrency.Value
	|			THEN PurchaseOrder.ExchangeRate
	|		ELSE ExchangeRatesSliceLast.ExchangeRate
	|	END AS ExchangeRate,
	|	CASE
	|		WHEN PurchaseOrder.DocumentCurrency = FunctionalCurrency.Value
	|			THEN PurchaseOrder.Multiplicity
	|		ELSE ExchangeRatesSliceLast.Multiplicity
	|	END AS Multiplicity,
	|	PurchaseOrder.Warehouse AS StructuralUnit,
	|	PurchaseOrder.PettyCash AS PettyCash,
	|	PurchaseOrder.BankAccount AS BankAccount,
	|	PurchaseOrder.CashAssetsType AS CashAssetsType
	|FROM
	|	Document.PurchaseOrder AS PurchaseOrder
	|		{LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&DocumentDate, ) AS ExchangeRatesSliceLast
	|		ON PurchaseOrder.Contract.SettlementsCurrency = ExchangeRatesSliceLast.Currency},
	|	Constant.FunctionalCurrency AS FunctionalCurrency
	|WHERE
	|	PurchaseOrder.Ref IN(&OrdersArray)";
	
	Query.SetParameter("OrdersArray", OrdersArray);
	Query.SetParameter("DocumentDate", ?(ValueIsFilled(Date), Date, CurrentSessionDate()));
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		VerifiedAttributesValues = New Structure("OrderState, Closed, Posted", Selection.OrderState, Selection.Closed, Selection.BasisPosted);
		Documents.PurchaseOrder.CheckEnteringAbilityOnTheBasisOfVendorOrder(Selection.BasisRef, VerifiedAttributesValues);
	EndDo;
	
	FillPropertyValues(ThisObject, Selection);
	
	If OrdersArray.Count() = 1 Then
		BasisDocument = OrdersArray[0];
	EndIf;
	
	DocumentData = New Structure;
	DocumentData.Insert("Ref",					Ref);
	DocumentData.Insert("Company",				Company);
	DocumentData.Insert("StructuralUnit",		StructuralUnit);
	DocumentData.Insert("AmountIncludesVAT",	AmountIncludesVAT);
	DocumentData.Insert("VATTaxation",			VATTaxation);
	
	Documents.SupplierInvoice.FillByPurchaseOrders(DocumentData, New Structure("OrdersArray", OrdersArray), Inventory, Expenses);
	
	// Payment calendar
	PaymentCalendar.Clear();
	
	If OrdersArray.Count() = 1 Then
		Query = New Query;
		Query.SetParameter("Date", ?(ValueIsFilled(Date), Date, CurrentSessionDate()));
		Query.SetParameter("OrdersArray", OrdersArray);
		Query.Text = 
		"SELECT
		|	DATEADD(&Date, DAY, DATEDIFF(PurchaseOrderPaymentCalendar.Ref.ReceiptDate, PurchaseOrderPaymentCalendar.PaymentDate, DAY)) AS PaymentDate,
		|	PurchaseOrderPaymentCalendar.PaymentPercentage AS PaymentPercentage,
		|	PurchaseOrderPaymentCalendar.PaymentAmount AS PaymentAmount,
		|	PurchaseOrderPaymentCalendar.PaymentVATAmount AS PaymentVATAmount
		|FROM
		|	Document.PurchaseOrder.PaymentCalendar AS PurchaseOrderPaymentCalendar
		|WHERE
		|	PurchaseOrderPaymentCalendar.Ref IN(&OrdersArray)";
		
		Selection = Query.Execute().Select();
		While Selection.Next() Do
			NewLine = PaymentCalendar.Add();
			FillPropertyValues(NewLine, Selection);
		EndDo;
		
		SetPaymentTerms = PaymentCalendar.Count() > 0;
		
	Else
		
		FillPaymentCalendarFromContract();
		
	EndIf;
	
	FillEarlyPaymentDiscounts();
	
EndProcedure

Procedure FillByGoodsReceipt(FillingData) Export
	
	// Document basis and document setting.
	GoodsReceiptArray = New Array;
	Contract = Undefined;
	
	If TypeOf(FillingData) = Type("Structure")
		AND FillingData.Property("GoodsReceiptArray") Then
		
		For Each ArrayItem In FillingData.GoodsReceiptArray Do
			Contract = ArrayItem.Contract;
			GoodsReceiptArray.Add(ArrayItem.Ref);
		EndDo;
		
		GoodsReceipt = GoodsReceiptArray[0];
		
	Else
		GoodsReceiptArray.Add(FillingData.Ref);
		GoodsReceipt = FillingData;
	EndIf;
	
	// Header filling.
	Query = New Query;
	Query.Text =
	"SELECT
	|	GoodsReceipt.Ref AS BasisRef,
	|	GoodsReceipt.Posted AS BasisPosted,
	|	GoodsReceipt.Company AS Company,
	|	GoodsReceipt.StructuralUnit AS StructuralUnit,
	|	GoodsReceipt.Contract AS Contract,
	|	GoodsReceipt.Order AS Order,
	|	GoodsReceipt.Counterparty AS Counterparty,
	|	GoodsReceipt.Cell AS Cell,
	|	GoodsReceipt.OperationType AS OperationType
	|INTO GoodsReceiptHeader
	|FROM
	|	Document.GoodsReceipt AS GoodsReceipt
	|WHERE
	|	GoodsReceipt.Ref IN(&ArrayOfGoodsReceipts)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	GoodsReceiptHeader.BasisRef AS BasisRef,
	|	GoodsReceiptHeader.BasisPosted AS BasisPosted,
	|	GoodsReceiptHeader.Company AS Company,
	|	GoodsReceiptHeader.StructuralUnit AS StructuralUnit,
	|	GoodsReceiptHeader.Counterparty AS Counterparty,
	|	CASE
	|		WHEN GoodsReceiptProducts.Contract <> VALUE(Catalog.CounterpartyContracts.EmptyRef)
	|			THEN GoodsReceiptProducts.Contract
	|		ELSE GoodsReceiptHeader.Contract
	|	END AS Contract,
	|	CASE
	|		WHEN GoodsReceiptProducts.Order <> VALUE(Document.PurchaseOrder.EmptyRef)
	|			THEN GoodsReceiptProducts.Order
	|		ELSE GoodsReceiptHeader.Order
	|	END AS Order,
	|	GoodsReceiptHeader.Cell AS Cell,
	|	GoodsReceiptHeader.OperationType AS OperationType
	|INTO GIFiltred
	|FROM
	|	GoodsReceiptHeader AS GoodsReceiptHeader
	|		LEFT JOIN Document.GoodsReceipt.Products AS GoodsReceiptProducts
	|		ON GoodsReceiptHeader.BasisRef = GoodsReceiptProducts.Ref
	|WHERE
	|	(GoodsReceiptProducts.Contract = &Contract
	|			OR &Contract = VALUE(Catalog.CounterpartyContracts.EmptyRef))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	GIFiltred.BasisRef AS BasisRef,
	|	GIFiltred.BasisPosted AS BasisPosted,
	|	GIFiltred.Company AS Company,
	|	GIFiltred.StructuralUnit AS StructuralUnit,
	|	GIFiltred.Counterparty AS Counterparty,
	|	GIFiltred.Contract AS Contract,
	|	GIFiltred.Order AS Order,
	|	PurchaseOrder.DocumentCurrency AS DocumentCurrency,
	|	PurchaseOrder.VATTaxation AS VATTaxation,
	|	PurchaseOrder.AmountIncludesVAT AS AmountIncludesVAT,
	|	PurchaseOrder.IncludeVATInPrice AS IncludeVATInPrice,
	|	CASE
	|		WHEN PurchaseOrder.DocumentCurrency = FunctionalCurrency.Value
	|			THEN PurchaseOrder.ExchangeRate
	|		ELSE ExchangeRatesSliceLast.ExchangeRate
	|	END AS ExchangeRate,
	|	CASE
	|		WHEN PurchaseOrder.DocumentCurrency = FunctionalCurrency.Value
	|			THEN PurchaseOrder.Multiplicity
	|		ELSE ExchangeRatesSliceLast.Multiplicity
	|	END AS Multiplicity,
	|	PurchaseOrder.CashAssetsType AS CashAssetsType,
	|	PurchaseOrder.PettyCash AS PettyCash,
	|	PurchaseOrder.SetPaymentTerms AS SetPaymentTerms,
	|	PurchaseOrder.BankAccount AS BankAccount,
	|	GIFiltred.Cell AS Cell,
	|	GIFiltred.OperationType AS OperationType
	|FROM
	|	GIFiltred AS GIFiltred
	|		LEFT JOIN Document.PurchaseOrder AS PurchaseOrder
	|		ON GIFiltred.Order = PurchaseOrder.Ref
	|		{LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&DocumentDate, ) AS ExchangeRatesSliceLast
	|		ON (PurchaseOrder.Contract.SettlementsCurrency = ExchangeRatesSliceLast.Currency)},
	|	Constant.FunctionalCurrency AS FunctionalCurrency";
	
	Query.SetParameter("ArrayOfGoodsReceipts",	GoodsReceiptArray);
	Query.SetParameter("DocumentDate",			?(ValueIsFilled(Date), Date, CurrentSessionDate()));
	Query.SetParameter("Contract",				Contract);
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		Documents.GoodsReceipt.CheckAbilityOfEnteringByGoodsReceipt(Selection.BasisRef, Selection.BasisPosted, Selection.OperationType, True);
	EndDo;
	
	FillPropertyValues(ThisObject, Selection);
	
	If GoodsReceiptArray.Count() = 1 Then
		BasisDocument = GoodsReceiptArray[0];
	EndIf;
	
	DocumentData = New Structure;
	DocumentData.Insert("Ref",					Ref);
	DocumentData.Insert("Company",				Company);
	DocumentData.Insert("StructuralUnit",		StructuralUnit);
	DocumentData.Insert("AmountIncludesVAT",	AmountIncludesVAT);
	DocumentData.Insert("VATTaxation",			VATTaxation);

	Documents.SupplierInvoice.FillByGoodsReceipts(DocumentData, New Structure("ArrayOfGoodsReceipts, Contract", GoodsReceiptArray, Contract), Inventory, Expenses);

	OrdersTable = Inventory.Unload(, "Order, GoodsReceipt");
	OrdersTable.GroupBy("Order, GoodsReceipt");
	If OrdersTable.Count() > 1 Then
		PurchaseOrderPosition = Enums.AttributeStationing.InTabularSection;
	Else
		
		PurchaseOrderPosition = DriveReUse.GetValueOfSetting("PurchaseOrderPositionInReceiptDocuments");
		If Not ValueIsFilled(PurchaseOrderPosition) Then
			PurchaseOrderPosition = Enums.AttributeStationing.InHeader;
		EndIf;
		
	EndIf;

	If PurchaseOrderPosition = Enums.AttributeStationing.InTabularSection Then
		Order = Undefined;
	ElsIf Not ValueIsFilled(Order) AND GoodsReceiptArray.Count() > 0 Then
		Order = GoodsReceiptArray[0].Order;
	EndIf;
	
	If Inventory.Count() = 0 Then
		CommonUseClientServer.MessageToUser(
			StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'The %1 is completely invoiced before'"),
				GoodsReceipt),
			Ref);
	EndIf;
	
	FillEarlyPaymentDiscounts();
	
EndProcedure

// Procedure of document filling based on purchase order.
//
// Parameters:
// FillingData - Structure - Document filling data
//	
Procedure FillBySupplierQuote(FillingData) Export
	
	// Filling out a document header.
	BasisDocument = FillingData.Ref;
	
	Order = Undefined;
	
	Company = FillingData.Company;
	Counterparty = FillingData.Counterparty;
	Contract = FillingData.Contract;
	DocumentCurrency = FillingData.DocumentCurrency;
	AmountIncludesVAT = FillingData.AmountIncludesVAT;
	VATTaxation = FillingData.VATTaxation;
	
	SupplierPriceTypes = FillingData.SupplierPriceTypes;
	If Not ValueIsFilled(SupplierPriceTypes) Then
		SupplierPriceTypes = Contract.SupplierPriceTypes;
	EndIf;
	
	RegisterVendorPrices = ValueIsFilled(SupplierPriceTypes);
	
	If DocumentCurrency = Constants.FunctionalCurrency.Get() Then
		ExchangeRate = FillingData.ExchangeRate;
		Multiplicity = FillingData.Multiplicity;
	Else
		StructureByCurrency = InformationRegisters.ExchangeRates.GetLast(Date, New Structure("Currency", Contract.SettlementsCurrency));
		ExchangeRate = StructureByCurrency.ExchangeRate;
		Multiplicity = StructureByCurrency.Multiplicity;
	EndIf;
	
	// Filling document tabular section.
	Inventory.Clear();
	Expenses.Clear();
	For Each TabularSectionRow In FillingData.Inventory Do
		
		ProductsData = CommonUse.ObjectAttributesValues(TabularSectionRow.Products, "ProductsType, ExpensesGLAccount, VATRate");
		
		If ProductsData.ProductsType = Enums.ProductsTypes.InventoryItem Then
			
			NewRow = Inventory.Add();
			FillPropertyValues(NewRow, TabularSectionRow);
			
		ElsIf ProductsData.ProductsType = Enums.ProductsTypes.Service Then
			
			NewRow = Expenses.Add();
			FillPropertyValues(NewRow, TabularSectionRow);
			
			TypePaymentExpenses = CommonUse.ObjectAttributeValue(ProductsData.ExpensesGLAccount, "TypeOfAccount");
			If TypePaymentExpenses = Enums.GLAccountsTypes.Expenses
				Or TypePaymentExpenses = Enums.GLAccountsTypes.Revenue
				Or TypePaymentExpenses = Enums.GLAccountsTypes.WorkInProcess
				Or TypePaymentExpenses = Enums.GLAccountsTypes.IndirectExpenses Then
				
				NewRow.StructuralUnit = FillingData.Department;
				
			Else
				
				NewRow.Order = Undefined;
				NewRow.StructuralUnit = Undefined;
				
			EndIf;
			
		EndIf;
		
		DataStructure = New Structure("Amount, VATRate, VATAmount, AmountIncludesVAT, Total");
		DataStructure.Amount = NewRow.Total;
		DataStructure.VATRate = ProductsData.VATRate;
		DataStructure.VATAmount = 0;
		DataStructure.AmountIncludesVAT = False;
		DataStructure.Total = 0;
		
		DataStructure = DriveServer.GetTabularSectionRowSum(DataStructure);
		
		NewRow.ReverseChargeVATRate = DataStructure.VATRate;
		NewRow.ReverseChargeVATAmount = DataStructure.VATAmount;
		
	EndDo;
	
	// Payment calendar
	FillPropertyValues(ThisObject, FillingData, "CashAssetsType, BankAccount, PettyCash");
	
	PaymentCalendar.Clear();
	
	Query = New Query;
	Query.SetParameter("Date", ?(ValueIsFilled(Date), Date, CurrentSessionDate()));
	Query.SetParameter("BasisDocument", FillingData);
	Query.Text = 
	"SELECT
	|	DATEADD(&Date, DAY, DATEDIFF(SupplierQuotePaymentCalendar.Ref.Date, SupplierQuotePaymentCalendar.PaymentDate, DAY)) AS PaymentDate,
	|	SupplierQuotePaymentCalendar.PaymentPercentage AS PaymentPercentage,
	|	SupplierQuotePaymentCalendar.PaymentAmount AS PaymentAmount,
	|	SupplierQuotePaymentCalendar.PaymentVATAmount AS PaymentVATAmount
	|FROM
	|	Document.SupplierQuote.PaymentCalendar AS SupplierQuotePaymentCalendar
	|WHERE
	|	SupplierQuotePaymentCalendar.Ref = &BasisDocument";
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		NewLine = PaymentCalendar.Add();
		FillPropertyValues(NewLine, Selection);
	EndDo;
	
	SetPaymentTerms = PaymentCalendar.Count() > 0;
	
	FillEarlyPaymentDiscounts();
	
EndProcedure

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
	
	TotalAmount = Inventory.Total("Amount") + Expenses.Total("Amount");
	TotalVAT = Inventory.Total("VATAmount") + Expenses.Total("VATAmount");
	
	DocumentDate = IncomingDocumentDate;
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = ?(ValueIsFilled(Date), Date, CurrentSessionDate());
	EndIf;
	
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

// Fills in the table section "EarlyPaymentDiscounts" from the contract
//
Procedure FillEarlyPaymentDiscounts() Export
	
	If Counterparty.DoOperationsByDocuments AND Contract.ContractKind = Enums.ContractType.WithVendor Then
	
		Query = New Query;
		Query.Text =
		"SELECT
		|	ContractsEarlyPaymentDiscounts.Period AS Period,
		|	ContractsEarlyPaymentDiscounts.Discount AS Discount,
		|	Contracts.ProvideEPD AS ProvideEPD
		|FROM
		|	Catalog.CounterpartyContracts AS Contracts
		|		INNER JOIN Catalog.CounterpartyContracts.EarlyPaymentDiscounts AS ContractsEarlyPaymentDiscounts
		|		ON Contracts.Ref = ContractsEarlyPaymentDiscounts.Ref
		|WHERE
		|	Contracts.Ref = &Ref";
		
		Query.SetParameter("Ref", Contract);
		
		QueryResult = Query.Execute();
		If QueryResult.IsEmpty() Then
			Return;
		EndIf;
		
		EarlyPaymentDiscounts.Clear();
		
		TotalAmount		= Inventory.Total("Total");
		DocumentDate	= ?(ValueIsFilled(IncomingDocumentDate), IncomingDocumentDate, Date);
		DocumentDate	= ?(ValueIsFilled(DocumentDate), DocumentDate, CurrentSessionDate());
		
		ResultTable = QueryResult.Unload();
		
		ProvideEPD = ResultTable[0].ProvideEPD;
		
		For each ResultRow In ResultTable Do
			
			NewRow = EarlyPaymentDiscounts.Add();
			FillPropertyValues(NewRow, ResultRow);
			
			NewRow.DueDate			= DocumentDate + NewRow.Period * 86400;
			NewRow.DiscountAmount	= Round(TotalAmount * NewRow.Discount / 100, 2);
			
		EndDo;
		
	Else
		
		EarlyPaymentDiscounts.Clear();
		ProvideEPD = Undefined;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region EventHandlers

Procedure OnCopy(CopiedObject)
	
	Prepayment.Clear();
	
EndProcedure

Procedure Filling(FillingData, StandardProcessing) Export
	
 	FillingStrategy = New Map;
	FillingStrategy[Type("Structure")]					= "FillByStructure";
	FillingStrategy[Type("DocumentRef.PurchaseOrder")]	= "FillByPurchaseOrder";
	FillingStrategy[Type("DocumentRef.SupplierQuote")]	= "FillBySupplierQuote";
	FillingStrategy[Type("DocumentRef.SalesSlip")]		= "FillBySalesSlip";
	FillingStrategy[Type("DocumentRef.GoodsReceipt")]	= "FillByGoodsReceipt";
	
	ExcludingProperties = "Order";
	If TypeOf(FillingData) = Type("Structure")
		AND FillingData.Property("ArrayOfPurchaseOrders") Then
		ExcludingProperties = ExcludingProperties + ", AmountIncludesVAT";
	EndIf;
	
	ObjectFillingDrive.FillDocument(ThisObject, FillingData, FillingStrategy, ExcludingProperties);
	
	RegisterVendorPrices = ValueIsFilled(SupplierPriceTypes);
	
EndProcedure

Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If PurchaseOrderPosition = Enums.AttributeStationing.InHeader Then
		For Each TabularSectionRow In Inventory Do
			TabularSectionRow.Order = Order;
		EndDo;
		If Counterparty.DoOperationsByOrders Then
			For Each TabularSectionRow In Prepayment Do
				TabularSectionRow.Order = Order;
			EndDo;
		EndIf;
	EndIf;
	
	DocumentAmount = Inventory.Total("Total") + Expenses.Total("Total");
	
	If Not Constants.UseSeveralLinesOfBusiness.Get() 
		AND Not IncludeExpensesInCostPrice Then
			For Each RowsExpenses In Expenses Do
				
				If RowsExpenses.InventoryGLAccount.TypeOfAccount = Enums.GLAccountsTypes.Expenses Then
					RowsExpenses.BusinessLine = Catalogs.LinesOfBusiness.MainLine;
				EndIf;
				
			EndDo;
	EndIf;
	
	If ValueIsFilled(Counterparty)
		AND Not Counterparty.DoOperationsByContracts
		AND Not ValueIsFilled(Contract) Then
		Contract = Counterparty.ContractByDefault;
	EndIf;
	
	AdditionalProperties.Insert("WriteMode", WriteMode);
	
EndProcedure

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	// Check existence of retail prices.
	CheckExistenceOfRetailPrice(Cancel);
	
	If Inventory.Count() > 0 Then
		
		CheckedAttributes.Add("StructuralUnit");
		
	EndIf;
	
	If Not IncludeExpensesInCostPrice Then
		
		For Each RowsExpenses In Expenses Do
			
			If Constants.UseSeveralDepartments.Get()
				AND (RowsExpenses.InventoryGLAccount.TypeOfAccount = Enums.GLAccountsTypes.WorkInProcess
					OR RowsExpenses.InventoryGLAccount.TypeOfAccount = Enums.GLAccountsTypes.IndirectExpenses
					OR RowsExpenses.InventoryGLAccount.TypeOfAccount = Enums.GLAccountsTypes.Revenue
					OR RowsExpenses.InventoryGLAccount.TypeOfAccount = Enums.GLAccountsTypes.Expenses)
				AND Not ValueIsFilled(RowsExpenses.StructuralUnit) Then
				
				MessageText = StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = 'The ""Department"" attribute must be filled in for the ""%1"" products specified in the %2 line of the ""Services"" list.'"),
					TrimAll(String(RowsExpenses.Products)),
					String(RowsExpenses.LineNumber));
					
				DriveServer.ShowMessageAboutError(
					ThisObject,
					MessageText,
					"Expenses",
					RowsExpenses.LineNumber,
					"StructuralUnit",
					Cancel);
				
			EndIf;
		
		EndDo;
		
	EndIf;
	
	RegisteredForVAT = InformationRegisters.AccountingPolicy.GetAccountingPolicy(Date, Company).RegisteredForVAT;
	
	If IncludeExpensesInCostPrice And Inventory.Total("AmountExpense") <> ExpensesAmountToBeAllocated() Then
			
		MessageText = NStr(
			"en = 'Amount of services is not equal to the amount allocated by inventory.'");
		
		DriveServer.ShowMessageAboutError(
			,
			MessageText,
			Undefined,
			Undefined,
			Undefined,
			Cancel);
		
	EndIf;
	
	OrderReceptionInHeader = PurchaseOrderPosition = Enums.AttributeStationing.InHeader;
	
	TableInventory = Inventory.Unload(, "Order, Total");
	TableInventory.GroupBy("Order", "Total");
	
	TableExpenses = Expenses.Unload(, "PurchaseOrder, Total");
	TableExpenses.GroupBy("PurchaseOrder", "Total");
	
	TablePrepayment = Prepayment.Unload(, "Order, PaymentAmount");
	TablePrepayment.GroupBy("Order", "PaymentAmount");
	
	If OrderReceptionInHeader Then
		For Each StringInventory In TableInventory Do
			StringInventory.Order = Order;
		EndDo;
		If Counterparty.DoOperationsByOrders Then
			For Each RowPrepayment In TablePrepayment Do
				RowPrepayment.Order = Order;
			EndDo;
		EndIf;
	EndIf;
	
	QuantitySalesInvoices = Inventory.Count() + Expenses.Count();
	
	For Each String In TablePrepayment Do
		
		FoundStringExpenses = Undefined;
		FoundStringInventory = Undefined;
		
		If Counterparty.DoOperationsByOrders
		   AND String.Order <> Undefined
		   AND String.Order <> Documents.PurchaseOrder.EmptyRef() Then
			FoundStringInventory = TableInventory.Find(String.Order, "Order");
			FoundStringExpenses = TableExpenses.Find(String.Order, "PurchaseOrder");
			Total = 0 + ?(FoundStringInventory = Undefined, 0, FoundStringInventory.Total) + ?(FoundStringExpenses = Undefined, 0, FoundStringExpenses.Total);
		ElsIf Counterparty.DoOperationsByOrders Then
			FoundStringInventory = TableInventory.Find(Undefined, "Order");
			FoundStringInventory = ?(FoundStringInventory = Undefined, TableInventory.Find(Documents.PurchaseOrder.EmptyRef(), "Order"), FoundStringInventory);
			FoundStringExpenses = TableExpenses.Find(Undefined, "PurchaseOrder");
			FoundStringExpenses = ?(FoundStringExpenses = Undefined, TableExpenses.Find(Documents.PurchaseOrder.EmptyRef(), "PurchaseOrder"), FoundStringExpenses);
			Total = 0 + ?(FoundStringInventory = Undefined, 0, FoundStringInventory.Total) + ?(FoundStringExpenses = Undefined, 0, FoundStringExpenses.Total);
		Else
			Total = Inventory.Total("Total") + Expenses.Total("Total");
		EndIf;
		
		If FoundStringInventory = Undefined
		   AND FoundStringExpenses = Undefined
		   AND QuantitySalesInvoices > 0
		   AND Counterparty.DoOperationsByOrders Then
			MessageText = NStr("en = 'Advance of order that is different from the one specified in tabular sections ""Inventory"" or ""Services"" cannot be set off.'");
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
	
	If Not VATTaxation = Enums.VATTaxationTypes.ReverseChargeVAT Then
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Inventory.ReverseChargeVATRate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Expenses.ReverseChargeVATRate");
	EndIf;
	
	// Serial numbers
	WorkWithSerialNumbers.FillCheckingSerialNumbers(Cancel, Inventory, SerialNumbers, StructuralUnit, ThisObject);
	
	CheckPermissionToChangeWarehouse(Cancel);
	
	//Payment calendar
	Amount = Inventory.Total("Amount") + Expenses.Total("Amount");
	VATAmount = Inventory.Total("VATAmount") + Expenses.Total("VATAmount");
	PaymentTermsServer.CheckCorrectPaymentCalendar(ThisObject, Cancel, Amount, VATAmount);
	
EndProcedure

Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting.
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Document data initialization.
	Documents.SupplierInvoice.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Preparation of records sets.
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Account for in accounting sections.
	DriveServer.ReflectInventory(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectBackorders(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectPurchases(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectInventoryInWarehouses(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectGoodsAwaitingCustomsClearance(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectPaymentCalendar(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectPurchaseOrders(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectGoodsReceivedNotInvoiced(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectIncomeAndExpenses(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectIncomeAndExpensesCashMethod(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectUnallocatedExpenses(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectIncomeAndExpensesRetained(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountsPayable(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectPOSSummary(AdditionalProperties, RegisterRecords, Cancel);
	
	DriveServer.ReflectAccountingJournalEntries(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectUsingPaymentTermsInDocuments(Ref, Cancel);
	
	// Serial numbers
	DriveServer.ReflectTheSerialNumbersOfTheGuarantee(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectTheSerialNumbersBalance(AdditionalProperties, RegisterRecords, Cancel);
	
	//VAT
	DriveServer.ReflectVATIncurred(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectVATInput(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectVATOutput(AdditionalProperties, RegisterRecords, Cancel);
	
	DriveServer.ReflectTaxesSettlements(AdditionalProperties, RegisterRecords, Cancel);
	
	// Offline registers
	DriveServer.ReflectInventoryCostLayer(AdditionalProperties, RegisterRecords, Cancel);
	
	// Record of the records sets.
	DriveServer.WriteRecordSets(ThisObject);
	
	// Subordinate tax invoice
	If Not Cancel Then
		WorkWithVAT.SubordinatedTaxInvoiceControl(DocumentWriteMode.Posting, Ref, DeletionMark);
	EndIf;
	
	// Control of occurrence of a negative balance.
	Documents.SupplierInvoice.RunControl(Ref, AdditionalProperties, Cancel);
	
	// Recording prices in information register Prices of counterparty products.
	Documents.SupplierInvoice.RecordVendorPrices(Ref);
	
	DriveServer.CreateRecordsInTasksRegisters(ThisObject, Cancel);
	DriveServer.ReflectTasksForUpdatingStatuses(Ref, Cancel);
	
	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
	// Subordinate tax invoice
	If Not Cancel Then
		WorkWithVAT.SubordinatedTaxInvoiceControl(DocumentWriteMode.Posting, Ref, DeletionMark);		
	EndIf;
	
EndProcedure

Procedure UndoPosting(Cancel)
	
	// Initialization of additional properties for document posting
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Preparation of record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Writing of record sets
	DriveServer.WriteRecordSets(ThisObject);
	
	// Subordinate tax invoice
	If Not Cancel Then
		WorkWithVAT.SubordinatedTaxInvoiceControl(DocumentWriteMode.UndoPosting, Ref, DeletionMark);
	EndIf;
	
	// Control of occurrence of a negative balance.
	Documents.SupplierInvoice.RunControl(Ref, AdditionalProperties, Cancel, True);
	
	// Deleting the prices from information register Prices of counterparty products.
	Documents.SupplierInvoice.DeleteVendorPrices(Ref);
	
	DriveServer.CreateRecordsInTasksRegisters(ThisObject, Cancel);
	DriveServer.ReflectTasksForUpdatingStatuses(Ref, Cancel);
	
EndProcedure

// Procedure checks the existence of retail price.
//
Procedure CheckExistenceOfRetailPrice(Cancel)
	
	If StructuralUnit.StructuralUnitType = Enums.BusinessUnitsTypes.Retail
	 OR StructuralUnit.StructuralUnitType = Enums.BusinessUnitsTypes.RetailEarningAccounting Then
	 
		Query = New Query;
		Query.SetParameter("Date", Date);
		Query.SetParameter("DocumentTable", Inventory);
		Query.SetParameter("RetailPriceKind", StructuralUnit.RetailPriceKind);
		Query.SetParameter("ListProducts", Inventory.UnloadColumn("Products"));
		Query.SetParameter("ListCharacteristic", Inventory.UnloadColumn("Characteristic"));
		
		Query.Text =
		"SELECT
		|	DocumentTable.LineNumber AS LineNumber,
		|	DocumentTable.Products AS Products,
		|	DocumentTable.Characteristic AS Characteristic,
		|	DocumentTable.Batch AS Batch
		|INTO InventoryTransferInventory
		|FROM
		|	&DocumentTable AS DocumentTable
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	InventoryTransferInventory.LineNumber AS LineNumber,
		|	PRESENTATION(InventoryTransferInventory.Products) AS ProductsPresentation,
		|	PRESENTATION(InventoryTransferInventory.Characteristic) AS CharacteristicPresentation,
		|	PRESENTATION(InventoryTransferInventory.Batch) AS BatchPresentation
		|FROM
		|	InventoryTransferInventory AS InventoryTransferInventory
		|		LEFT JOIN InformationRegister.Prices.SliceLast(
		|				&Date,
		|				PriceKind = &RetailPriceKind
		|					AND Products IN (&ListProducts)
		|					AND Characteristic IN (&ListCharacteristic)) AS PricesSliceLast
		|		ON InventoryTransferInventory.Products = PricesSliceLast.Products
		|			AND InventoryTransferInventory.Characteristic = PricesSliceLast.Characteristic
		|WHERE
		|	ISNULL(PricesSliceLast.Price, 0) = 0";
		
		SelectionOfQueryResult = Query.Execute().Select();
		
		While SelectionOfQueryResult.Next() Do
			
			MessageText = NStr("en = 'For products %ProductsPresentation% in string %LineNumber% of list ""Inventory"" retail price is not set.'");
			MessageText = StrReplace(MessageText, "%LineNumber%", String(SelectionOfQueryResult.LineNumber));
			MessageText = StrReplace(MessageText, "%ProductsPresentation%",  DriveServer.PresentationOfProducts(SelectionOfQueryResult.ProductsPresentation, SelectionOfQueryResult.CharacteristicPresentation, SelectionOfQueryResult.BatchPresentation));
			DriveServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				"Inventory",
				SelectionOfQueryResult.LineNumber,
				"Products",
				Cancel
			);
	
		EndDo;
	 
	EndIf;
	
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

#EndRegion

#EndIf