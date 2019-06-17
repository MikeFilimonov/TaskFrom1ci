
#Region FormEventHandlers

&AtClient
Procedure OnOpen(Cancel)
	
	If DaysNumber = 0 Then
		DaysNumber = 30;
	EndIf;
	
	If Not ValueIsFilled(ProductsPurchaseMode) Then
		ProductsPurchaseMode = "FromSupplier";
	EndIf;
	
	If Not ValueIsFilled(MiddleSalesCalculationPeriod.StartDate)
		OR Not ValueIsFilled(MiddleSalesCalculationPeriod.EndDate) Then
		MiddleSalesCalculationPeriod.Variant = StandardPeriodVariant.LastMonth;
	EndIf;
	
	SetVisibleServer();
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "ChangedOrderVendor" Then
		
		ClearMessages();
		RefreshTablePartOrdersServer();
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemEventHandlers

&AtClient
Procedure ProductsPurchaseModeOnChange(Item)
	
	SetVisibleServer();
	
EndProcedure

#Region EventHandlersOfTheDemandForm

&AtClient
Procedure RequirmentSelect(Item, SelectedRow, Field, StandardProcessing)
	
	FieldName = Field.Name;
	
	If FieldName <> "DemandVendor" 
		AND FieldName <> "DemandProducts"
		AND FieldName <> "DemandCharacteristic" Then
		
		Return;
	EndIf;
	
	AttributeName = StrReplace(Field.Name, "Demand", "");
	
	Value = Item.CurrentData[AttributeName];
	If ValueIsFilled(Value) Then
		ShowValue(Undefined, Value);
	EndIf;
	
EndProcedure

&AtClient
Procedure NeedToCheckOnChange(Item)
	
	CurrentData = Items.Demand.CurrentData;
	If CurrentData <> Undefined Then
		
		MarkValue = CurrentData.Check;
		If CurrentData.GetParent() = Undefined Then
			FillMarksRequirement(MarkValue, CurrentData.GetID());
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure DemandQuantityForPurchaseOnChange(Item)
	
	CurrentData = Items.Demand.CurrentData;
	If CurrentData <> Undefined Then
		
		UpperLevelRow = CurrentData.GetParent();
		If UpperLevelRow <> Undefined Then
			
			QuantityForPurchaseTotal = 0;
			LowerLevelElements = UpperLevelRow.GetItems();
			For Each LowerLevelElement In LowerLevelElements Do
				QuantityForPurchaseTotal = QuantityForPurchaseTotal + LowerLevelElement.QuantityForPurchase;
			EndDo;
			
			UpperLevelRow.QuantityForPurchase = QuantityForPurchaseTotal;
			
			If Not CurrentData.Check Then
				CurrentData.Check = True;
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region EventHandlersOfTheOrdersForm

&AtClient
Procedure OrdersSelection(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	
	Document = Item.CurrentData.Document;
	If ValueIsFilled(Document) Then
		ShowValue(Undefined, Document);
	EndIf;
	
EndProcedure

#EndRegion

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure CheckAll(Command)
	
	FillMarksRequirement(True);
	
EndProcedure

&AtClient
Procedure UncheckAll(Command)
	
	FillMarksRequirement(False);
	
EndProcedure

&AtClient
Procedure OrderFlagsSet(Command)
	
	OrdersFillMarks(True);
	
EndProcedure

&AtClient
Procedure RemoveOrdersFlags(Command)
	
	OrdersFillMarks(False);
	
EndProcedure

&AtClient
Procedure ShowZeroSales(Command)
	
	If Demand.GetItems().Count() > 0 Then
		QuestionText = NStr("en = 'Tabular section will be filled in again. Continue?'");
		Response = Undefined;

		ShowQueryBox(New NotifyDescription("ShowZeroSalesEnd", ThisObject), QuestionText, QuestionDialogMode.YesNo);
        Return;
	EndIf;
	
	ShowZeroSalesFragment();
EndProcedure

&AtClient
Procedure ShowZeroSalesEnd(Result, AdditionalParameters) Export
    
    Response = Result;
    If Response = DialogReturnCode.No Then
        Return;
    EndIf;
    
    ShowZeroSalesFragment();

EndProcedure

&AtClient
Procedure ShowZeroSalesFragment()
    
    Items.ShowZeroSales.Check = Not Items.ShowZeroSales.Check;
    FillAndCalculateServer();
    
    TreeStringsRecount();

EndProcedure

&AtClient
Procedure FillAndCalculate(Command)
	
	If Demand.GetItems().Count() > 0 Then
		QuestionText = NStr("en = 'Tabular section will be filled in again. Continue?'");
		Response = Undefined;

		ShowQueryBox(New NotifyDescription("FillAndCalculateEnd", ThisObject), QuestionText, QuestionDialogMode.YesNo);
        Return;
	EndIf;
	
	FillAndCalculateFragment();
EndProcedure

&AtClient
Procedure FillAndCalculateEnd(Result, AdditionalParameters) Export
    
    Response = Result;
    If Response = DialogReturnCode.No Then
        Return;
    EndIf;
    
    FillAndCalculateFragment();

EndProcedure

&AtClient
Procedure FillAndCalculateFragment()
    
    If Not ValueIsFilled(MiddleSalesCalculationPeriod.StartDate)
        OR Not ValueIsFilled(MiddleSalesCalculationPeriod.EndDate) Then
        
        MiddleSalesCalculationPeriod.Variant = StandardPeriodVariant.LastMonth;
    EndIf;
    
    FillAndCalculateServer();
    
    TreeStringsRecount();

EndProcedure

&AtClient
Procedure GenerateOrders(Command)
	
	ClearMessages();
	Orders.Clear();
	If OrderSetServer() Then
		
		ShowUserNotification(
			,,
			NStr("en = 'Purchase orders are successfully created.'"),
			PictureLib.Information32
		);
		
		Items.PagesProducts.CurrentPage = Items.OrdersPage;
		
	Else
		
		Message = New UserMessage;
		Message.Text = NStr("en = 'No data to generate orders.'");
		Message.Message();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OrderEdit(Command)
	
	CurrentData = Items.Orders.CurrentData;
	If CurrentData <> Undefined
		AND ValueIsFilled(CurrentData.Document) Then
		ShowValue(Undefined, CurrentData.Document);
	EndIf;
	
EndProcedure

&AtClient
Procedure DeleteOrder(Command)
	
	OrdersForDeleting = Orders.FindRows(New Structure("Check", True));
	If OrdersForDeleting.Count() = 0 Then
		
		Return;
		
	ElsIf OrdersForDeleting.Count() = 1 Then
		
		QuestionText = NStr("en = 'Selected document will be deleted. Continue?'");
		
	Else
		
		QuestionText = NStr("en = 'Selected documents will be deleted. Continue?'");
		
	EndIf;
	
	Response = Undefined;

	
	ShowQueryBox(New NotifyDescription("DeleteOrderEnd", ThisObject), QuestionText, QuestionDialogMode.YesNo);
	
EndProcedure

&AtClient
Procedure DeleteOrderEnd(Result, AdditionalParameters) Export
    
    Response = Result;
    If Response = DialogReturnCode.Yes Then
        
        OrdersDeleteServer();
        
    EndIf;

EndProcedure

&AtClient
Procedure PostOrders(Command)
	
	ClearMessages();
	PostOrdersServer();
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// Procedure sets the form item visible.
//
&AtServer
Procedure SetVisibleServer()
	
	If ProductsPurchaseMode = "FromSupplier" Then
		Items.Vendor.Visible = True;
		Items.ProductsGroup.Visible = False;
	Else
		Items.Vendor.Visible = False;
		Items.ProductsGroup.Visible = True;
	EndIf;
	
EndProcedure

// Procedure fills the Demand
// table by data and calculates the quantity recommended for purchase.
//
&AtServer
Procedure FillAndCalculateServer()
	
	RequirementTree = FormAttributeToValue("Demand");
	RequirementTree.Rows.Clear();
	
	OutputZeroSale = Items.ShowZeroSales.Check;
	
	BeginOfPeriodForCalculatingStatistics = MiddleSalesCalculationPeriod.StartDate;
	EndOfPeriodForCalculatingStatistics = MiddleSalesCalculationPeriod.EndDate;
	
	TableBalancesOnDays = New ValueTable;
	
	TableBalancesOnDays.Columns.Add("DayPeriod", New TypeDescription("Date"));
	TableBalancesOnDays.Columns.Add("Products", New TypeDescription("CatalogRef.Products"));
	TableBalancesOnDays.Columns.Add("Characteristic", New TypeDescription("CatalogRef.ProductsCharacteristics"));
	TableBalancesOnDays.Columns.Add("DaysNumber", New TypeDescription("Number"));
	TableBalancesOnDays.Columns.Add("OpeningBalance", New TypeDescription("Number"));
	TableBalancesOnDays.Columns.Add("ClosingBalance", New TypeDescription("Number"));
	TableBalancesOnDays.Columns.Add("QuantityReceipt", New TypeDescription("Number"));
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	InventoryInWarehousesBalanceAndTurnovers.Period AS DayPeriod,
	|	InventoryInWarehousesBalanceAndTurnovers.Products AS Products,
	|	InventoryInWarehousesBalanceAndTurnovers.Characteristic AS Characteristic,
	|	InventoryInWarehousesBalanceAndTurnovers.QuantityOpeningBalance AS OpeningBalance,
	|	InventoryInWarehousesBalanceAndTurnovers.QuantityReceipt AS QuantityReceipt,
	|	InventoryInWarehousesBalanceAndTurnovers.QuantityExpense AS QuantityExpense,
	|	InventoryInWarehousesBalanceAndTurnovers.QuantityClosingBalance AS ClosingBalance
	|FROM
	|	AccumulationRegister.InventoryInWarehouses.BalanceAndTurnovers(
	|			&BeginOfPeriod,
	|			&EndOfPeriod,
	|			Day,
	|			RegisterRecordsAndPeriodBoundaries,
	|			%FilterByVendor%
	|				AND %FilterByGroup%) AS InventoryInWarehousesBalanceAndTurnovers
	|
	|ORDER BY
	|	DayPeriod,
	|	Products,
	|	Characteristic
	|TOTALS
	|	SUM(OpeningBalance),
	|	SUM(QuantityReceipt),
	|	SUM(QuantityExpense),
	|	SUM(ClosingBalance)
	|BY
	|	DayPeriod PERIODS(Day, &BeginOfPeriod, &EndOfPeriod),
	|	Products,
	|	Characteristic";
	
	Query.SetParameter("BeginOfPeriod", BeginOfPeriodForCalculatingStatistics);
	Query.SetParameter("EndOfPeriod", EndOfPeriodForCalculatingStatistics);

	ProcessQueryText(Query);
	
	QueryResult = Query.Execute();

	SelectionPeriod = QueryResult.Select(QueryResultIteration.ByGroups, "DayPeriod", "All");

	While SelectionPeriod.Next() Do

		SelectionProducts = SelectionPeriod.Select(QueryResultIteration.ByGroups);
		While SelectionProducts.Next() Do
			
			SelectionCharacteristic = SelectionProducts.Select(QueryResultIteration.ByGroups);
			While SelectionCharacteristic.Next() Do
				
				If SelectionCharacteristic.OpeningBalance > 0
					OR SelectionCharacteristic.ClosingBalance > 0
					OR (SelectionCharacteristic.QuantityReceipt <> Null AND SelectionCharacteristic.QuantityReceipt > 0) Then
					
					NewRow = TableBalancesOnDays.Add();
					FillPropertyValues(NewRow, SelectionCharacteristic);
					NewRow.DaysNumber = 1;
					
				EndIf;
				
			EndDo;
		EndDo;
	EndDo;
	
	TableBalancesOnDays.GroupBy("Products, Characteristic", "DaysNumber");
	TableBalancesOnDays.Indexes.Add("Products, Characteristic");

	Query = New Query;
	Query.Text = 
	"SELECT
	|	TableBalancesOnDays.Products AS Products,
	|	TableBalancesOnDays.Characteristic AS Characteristic,
	|	TableBalancesOnDays.DaysNumber AS NumberOfSalesDays
	|INTO Tu_NumberOfSalesDays
	|FROM
	|	&TableBalancesOnDays AS TableBalancesOnDays
	|
	|INDEX BY
	|	Products,
	|	Characteristic
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	Products.Ref AS Products,
	|	VALUE(Catalog.ProductsCharacteristics.EmptyRef) AS Characteristic,
	|	Products.Vendor
	|INTO Tu_ProductsCharacteristics
	|FROM
	|	Catalog.Products AS Products
	|WHERE
	|	Products.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
	|	AND Not Products.IsFolder
	|	AND %FilterByVendor%
	|	AND %FilterByGroup%
	|
	|UNION ALL
	|
	|SELECT
	|	Products.Ref,
	|	ProductsCharacteristics.Ref,
	|	Products.Vendor
	|FROM
	|	Catalog.Products AS Products
	|		INNER JOIN Catalog.ProductsCharacteristics AS ProductsCharacteristics
	|		ON (ProductsCharacteristics.Owner = Products.Ref)
	|WHERE
	|	Products.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
	|	AND Not Products.IsFolder
	|	AND %FilterByVendor%
	|	AND %FilterByGroup%
	|
	|INDEX BY
	|	Products,
	|	Characteristic
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ProductsCharacteristics.Vendor AS Vendor,
	|	ProductsCharacteristics.Products AS Products,
	|	ProductsCharacteristics.Characteristic AS Characteristic,
	|	ISNULL(InventoryBalances.QuantityBalance, 0) AS CurrentBalance
	|INTO Tu_ProductsCharacteristicsBalance
	|FROM
	|	Tu_ProductsCharacteristics AS ProductsCharacteristics
	|		LEFT JOIN AccumulationRegister.Inventory.Balance(
	|				,
	|				(Products, Characteristic) In
	|					(SELECT
	|						ProductsCharacteristics.Products,
	|						ProductsCharacteristics.Characteristic
	|					FROM
	|						Tu_ProductsCharacteristics AS ProductsCharacteristics)) AS InventoryBalances
	|		ON ProductsCharacteristics.Products = InventoryBalances.Products
	|			AND ProductsCharacteristics.Characteristic = InventoryBalances.Characteristic
	|
	|INDEX BY
	|	Products,
	|	Characteristic
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	SalesTurnovers.Products,
	|	SalesTurnovers.Characteristic,
	|	SUM(SalesTurnovers.QuantityTurnover) AS Sold
	|INTO Tu_Sales
	|FROM
	|	AccumulationRegister.Sales.Turnovers(
	|			&StartPeriod,
	|			&EndPeriod,
	|			Auto,
	|			(Products, Characteristic) In
	|				(SELECT
	|					Tu_ProductsCharacteristics.Products,
	|					Tu_ProductsCharacteristics.Characteristic
	|				FROM
	|					Tu_ProductsCharacteristics AS Tu_ProductsCharacteristics)) AS SalesTurnovers
	|
	|GROUP BY
	|	SalesTurnovers.Products,
	|	SalesTurnovers.Characteristic
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Tu_ProductsCharacteristicsBalance.Vendor AS Vendor,
	|	Tu_ProductsCharacteristicsBalance.Products AS Products,
	|	Tu_ProductsCharacteristicsBalance.Characteristic AS Characteristic,
	|	Tu_ProductsCharacteristicsBalance.CurrentBalance AS CurrentBalance,
	|	ISNULL(Tu_Sales.Sold, 0) AS SalesStatisticsQuantity,
	|	CASE
	|		WHEN ISNULL(Tu_Sales.Sold, 0) = 0 
	|				OR ISNULL(Tu_NumberOfSalesDays.NumberOfSalesDays, 0) = 0
	|			THEN 0
	|		ELSE ISNULL(Tu_Sales.Sold, 0) / Tu_NumberOfSalesDays.NumberOfSalesDays
	|	END AS SalesStatisticsAverageSale,
	|	CASE
	|		WHEN ISNULL(Tu_Sales.Sold, 0) = 0 
	|				OR ISNULL(Tu_NumberOfSalesDays.NumberOfSalesDays, 0) = 0
	|			THEN 0
	|		ELSE ISNULL(Tu_Sales.Sold, 0) / Tu_NumberOfSalesDays.NumberOfSalesDays
	|	END * &DaysNumber - Tu_ProductsCharacteristicsBalance.CurrentBalance AS QuantityForPurchase,
	|	Tu_NumberOfSalesDays.NumberOfSalesDays AS SalesStatisticsQuantityDays
	|FROM
	|	Tu_ProductsCharacteristicsBalance AS Tu_ProductsCharacteristicsBalance
	|		LEFT JOIN Tu_Sales AS Tu_Sales
	|		ON Tu_ProductsCharacteristicsBalance.Products = Tu_Sales.Products
	|			AND Tu_ProductsCharacteristicsBalance.Characteristic = Tu_Sales.Characteristic
	|		LEFT JOIN Tu_NumberOfSalesDays AS Tu_NumberOfSalesDays
	|		ON Tu_ProductsCharacteristicsBalance.Products = Tu_NumberOfSalesDays.Products
	|			AND Tu_ProductsCharacteristicsBalance.Characteristic = Tu_NumberOfSalesDays.Characteristic
	|WHERE
	|	CASE
	|			WHEN Not &OutputZeroSale
	|				THEN ISNULL(Tu_Sales.Sold, 0) > 0
	|			ELSE TRUE
	|		END
	|
	|ORDER BY
	|	Vendor, QuantityForPurchase DESC, Products, Characteristic
	|TOTALS
	|	SUM(CurrentBalance),
	|	SUM(SalesStatisticsQuantity),
	|	SUM(SalesStatisticsAverageSale),
	|	SUM(QuantityForPurchase),
	|	SUM(SalesStatisticsQuantityDays)
	|BY
	|	Vendor";
	
	Query.SetParameter("TableBalancesOnDays", TableBalancesOnDays);
	Query.SetParameter("StartPeriod", BeginOfPeriodForCalculatingStatistics);
	Query.SetParameter("EndPeriod", EndOfPeriodForCalculatingStatistics);
	Query.SetParameter("DaysNumber", DaysNumber);
	Query.SetParameter("OutputZeroSale", OutputZeroSale);
	
	ProcessQueryText(Query);
	
	Result = Query.Execute();
	
	If Result.IsEmpty() Then
		ValueToFormAttribute(RequirementTree, "Demand");
		Return;
	EndIf;
	
	VendorSelection = Query.Execute().Select(QueryResultIteration.ByGroups);
	While VendorSelection.Next() Do
		
		SuplierString = RequirementTree.Rows.Add();
		FillPropertyValues(SuplierString, VendorSelection);
		
		SuplierString.QuantityForPurchase = Round(SuplierString.QuantityForPurchase);
		
		SelectionProducts = VendorSelection.Select();
		While SelectionProducts.Next() Do
			
			StringProducts = SuplierString.Rows.Add();
			FillPropertyValues(StringProducts, SelectionProducts,,"Vendor");
			
			StringProducts.QuantityForPurchase = Round(StringProducts.QuantityForPurchase);
			
		EndDo;
		
	EndDo;
	
	ValueToFormAttribute(RequirementTree, "Demand");
	Items.Demand.InitialTreeView = InitialTreeView.ExpandAllLevels;
	
EndProcedure

&AtServer
Procedure ProcessQueryText(Query)
	
	If ProductsPurchaseMode = "FromSupplier"
		AND ValueIsFilled(Vendor) Then
		
		Query.SetParameter("Vendor", Vendor);
		Query.Text = StrReplace(Query.Text, "%FilterByVendor%", "Products.Vendor = &Vendor");
		Query.Text = StrReplace(Query.Text, "%FilterByGroup%", "TRUE");
		
	ElsIf ProductsPurchaseMode = "ProductsGroup"
		AND ValueIsFilled(ProductsGroup) Then
		
		Query.SetParameter("ProductsGroup", ProductsGroup);
		Query.Text = StrReplace(Query.Text, "%FilterByGroup%", "Products.Ref IN HIERARCHY (&ProductsGroup)");
		Query.Text = StrReplace(Query.Text, "%FilterByVendor%", "TRUE");
		
	Else
		
		Query.Text = StrReplace(Query.Text, "%FilterByVendor%", "TRUE");
		Query.Text = StrReplace(Query.Text, "%FilterByGroup%", "TRUE");
		
	EndIf;
	
EndProcedure

// Procedure fills the string check boxes in the Orders table.
//
&AtClient
Procedure OrdersFillMarks(MarkValue)
	
	For Each TableRow In Orders Do
		TableRow.Check = MarkValue;
	EndDo;
	
EndProcedure

// Procedure fills the string check boxes in the Demand table.
//
&AtClient
Procedure FillMarksRequirement(MarkValue, ItemIdentificator = Undefined)
	
	If ItemIdentificator <> Undefined Then
		TreeItem = Demand.FindByID(ItemIdentificator);
		LowerLevelElements = TreeItem.GetItems();
		For Each LowerLevelElement In LowerLevelElements Do
			LowerLevelElement.Check = MarkValue;
		EndDo;
	Else
		UpperLevelItems = Demand.GetItems();
		For Each TopLevelItem In UpperLevelItems Do
			TopLevelItem.Check = MarkValue;
			LowerLevelElements = TopLevelItem.GetItems();
			For Each LowerLevelElement In LowerLevelElements Do
				LowerLevelElement.Check = MarkValue;
			EndDo;
		EndDo;
	EndIf;
	
EndProcedure

// Receives the counterparty contract corresponding to document conditions by default.
//
&AtServerNoContext
Function GetContractByDefault(Document, Counterparty, OperationKind, Company)
	
	If Not Counterparty.DoOperationsByContracts Then
		Return Counterparty.ContractByDefault;
	EndIf;
	
	ContractKindsList = New ValueList;
	ContractKindsList.Add(Enums.ContractType.WithVendor);
	ContractKindsList.Add(Enums.ContractType.FromPrincipal);
	
	ContractByDefault = Catalogs.CounterpartyContracts.GetDefaultContractByCompanyContractKind(Counterparty, Company, ContractKindsList);
	
	Return ContractByDefault;
	
EndFunction

// The procedure generates purchase orders by data in selected strings of the Demand table.
//
&AtServer
Function OrderSetServer()
	
	RequirementTree = FormAttributeToValue("Demand");
	OrdersComposed = False;
	
	BeginTransaction();
	
	Try
		
		For Each SuplierString In RequirementTree.Rows Do
			
			If SuplierString.Rows.Find(True, "Check") = Undefined
				OR SuplierString.Rows.Total("QuantityForPurchase") = 0 Then
				Continue;
			EndIf;
			
			VendorCounterparty = SuplierString.Vendor;
			
			DocumentObject = Documents.PurchaseOrder.CreateDocument();
			
			OperationKind = Enums.OperationTypesPurchaseOrder.OrderForPurchase;
			PostingIsAllowed = True;
			
			DocumentObject.AmountIncludesVAT = True;
			
			DriveServer.FillDocumentHeader(
				DocumentObject,
				OperationKind,,,
				PostingIsAllowed
			);
			
			DocumentObject.Date = CurrentDate();
			DocumentObject.OperationKind = OperationKind;
			DocumentObject.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT;
			DocumentObject.ReceiptDatePosition = Enums.AttributeStationing.InHeader;
			DocumentObject.Counterparty = VendorCounterparty;
			
			ContractByDefault = GetContractByDefault(DocumentObject, VendorCounterparty, OperationKind, DocumentObject.Company);
			If ValueIsFilled(ContractByDefault) Then
				
				DocumentObject.DocumentCurrency = ContractByDefault.SettlementsCurrency;
				DocumentObject.Contract = ContractByDefault;
				
				SupplierPriceTypes = ContractByDefault.SupplierPriceTypes;
				DocumentObject.SupplierPriceTypes = SupplierPriceTypes;
				
			EndIf;
			
			Filter = New Structure("Currency", DocumentObject.DocumentCurrency);
			StructureByCurrency = InformationRegisters.ExchangeRates.GetLast(CurrentDate(), Filter);
			
			DocumentObject.ExchangeRate = StructureByCurrency.ExchangeRate;
			DocumentObject.Multiplicity = StructureByCurrency.Multiplicity;
			
			If ValueIsFilled(SupplierPriceTypes) Then
				DocumentObject.AmountIncludesVAT = SupplierPriceTypes.PriceIncludesVAT;
			EndIf;
			
			For Each StringProducts In SuplierString.Rows Do
				
				If Not StringProducts.Check
					OR StringProducts.QuantityForPurchase = 0 Then
					Continue;
				EndIf;
				
				NewRow = DocumentObject.Inventory.Add();
				NewRow.Products = StringProducts.Products;
				NewRow.Characteristic = StringProducts.Characteristic;
				NewRow.Quantity = StringProducts.QuantityForPurchase;
				
				StructureData = New Structure;
				StructureData.Insert("Company", DocumentObject.Company);
				StructureData.Insert("Products", NewRow.Products);
				StructureData.Insert("Characteristic", NewRow.Characteristic);
				StructureData.Insert("VATTaxation", DocumentObject.VATTaxation);
				
				If ValueIsFilled(DocumentObject.SupplierPriceTypes) Then
					
					StructureData.Insert("ProcessingDate", DocumentObject.Date);
					StructureData.Insert("DocumentCurrency", DocumentObject.DocumentCurrency);
					StructureData.Insert("AmountIncludesVAT", DocumentObject.AmountIncludesVAT);
					StructureData.Insert("SupplierPriceTypes", DocumentObject.SupplierPriceTypes);
					StructureData.Insert("Factor", 1);
					
				EndIf;
				
				StructureData = GetDataProductsOnChange(StructureData);
				
				NewRow.MeasurementUnit = StructureData.MeasurementUnit;
				NewRow.Quantity = StringProducts.QuantityForPurchase;
				NewRow.Price = StructureData.Price;
				NewRow.VATRate = StructureData.VATRate;
				NewRow.Content = "";
				
				CalculateAmountInTabularSectionLine(NewRow, DocumentObject.AmountIncludesVAT);
				
			EndDo;
			
			If DocumentObject.Inventory.Count() = 0 Then
				DocumentObject = Undefined;
				Continue;
			EndIf;
			
			DocumentObject.DocumentAmount = DocumentObject.Inventory.Total("Total");
			DocumentObject.Comment = NStr("en = 'Automatically created using the ""Goods demand calculation"" data processor'");
			
			DocumentObject.Write(DocumentWriteMode.Write);
			
			OrdersString = Orders.Add();
			OrdersString.Document = DocumentObject.Ref;
			OrdersString.Vendor = DocumentObject.Counterparty;
			OrdersString.DocumentAmount = DocumentObject.DocumentAmount;
			OrdersString.PictureIndex = 0;
			
			OrdersComposed = True
		EndDo;
		
		CommitTransaction();
		
	Except
		
		RollbackTransaction();
		
		ErrorDescription = NStr("en = 'While generating an order, an error occurred.
		                        |Order generation is canceled.
		                        |Additional
		                        |description: %AdditionalDetails%'");
		
		ErrorDescription = StrReplace(ErrorDescription, "%AdditionalDetails%", ErrorInfo().Definition);
		Raise ErrorDescription;
		
	EndTry;
	
	Return OrdersComposed;
	
EndFunction

&AtServerNoContext
Function GetDataProductsOnChange(StructureData)
	
	StructureData.Insert("MeasurementUnit", StructureData.Products.MeasurementUnit);
	
	If StructureData.Property("VATTaxation") 
		AND Not StructureData.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then
		
		If StructureData.VATTaxation = Enums.VATTaxationTypes.NotSubjectToVAT Then
			StructureData.Insert("VATRate", Catalogs.VATRates.Exempt);
		Else
			StructureData.Insert("VATRate", Catalogs.VATRates.ZeroRate);
		EndIf;
		
	ElsIf ValueIsFilled(StructureData.Products.VATRate) Then
		StructureData.Insert("VATRate", StructureData.Products.VATRate);
	Else
		StructureData.Insert("VATRate", InformationRegisters.AccountingPolicy.GetDefaultVATRate(, StructureData.Company));
	EndIf;
	
	If StructureData.Property("SupplierPriceTypes") Then
		
		Price = DriveServer.GetPriceProductsBySupplierPriceTypes(StructureData);
		StructureData.Insert("Price", Price);
		
	Else
		
		StructureData.Insert("Price", 0);
		
	EndIf;
	
	Return StructureData;
	
EndFunction

&AtServer
Procedure CalculateAmountInTabularSectionLine(TabularSectionRow, AmountIncludesVAT)
	
	// Amount.
	TabularSectionRow.Amount = TabularSectionRow.Quantity * TabularSectionRow.Price;
	
	// VAT amount.
	VATRate = DriveReUse.GetVATRateValue(TabularSectionRow.VATRate);
	
	TabularSectionRow.VATAmount = ?(AmountIncludesVAT, 
	TabularSectionRow.Amount - (TabularSectionRow.Amount) / ((VATRate + 100) / 100),
	TabularSectionRow.Amount * VATRate / 100);
	
	// Total.
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
EndProcedure

// The procedure posts the selected purchase orders.
//
&AtServer
Procedure PostOrdersServer()
	
	For Each TableRow In Orders Do
		
		If Not TableRow.Check
			OR Not ValueIsFilled(TableRow.Document) Then
			Continue;
		EndIf;
		
		DocumentObject = TableRow.Document.GetObject();
		DocumentPostedSuccessfully = False;
		Try
			
			If DocumentObject.CheckFilling() Then
				
				// Trying to post the document
				DocumentObject.Write(DocumentWriteMode.Posting);
				DocumentPostedSuccessfully = DocumentObject.Posted;
				
			Else
				
				DocumentPostedSuccessfully = False;
				
			EndIf;
			
		Except
			
			DocumentPostedSuccessfully = False;
			
		EndTry;
		
		If DocumentPostedSuccessfully Then
			
			TableRow.PictureIndex = 1;
			
		Else
			
			MessageText = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Cannot post the %1 document.'"), String(DocumentObject));
			
			Message = New UserMessage;
			Message.Text = MessageText;
			Message.Message();
			
			TableRow.PictureIndex = 0;
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Function defines references to the document.
//
&AtServerNoContext
Function IsReferencesToDocument(Document)

	RefArray = New Array;
	RefArray.Add(Document);
	
	ReferenceTab = FindByRef(RefArray);
	
	If ReferenceTab.Count() > 0 Then
		Return True;
	Else
		Return False;
	EndIf;

EndFunction

// The procedure removes the selected purchase orders.
//
&AtServer
Procedure OrdersDeleteServer()
	
	SetPrivilegedMode(True);
	
	StringsArrayForDelete = New Array;
	
	For Each TableRow In Orders Do
		
		If Not TableRow.Check
			OR Not ValueIsFilled(TableRow.Document) Then
			Continue;
		EndIf;
		
		DocumentObject = TableRow.Document.GetObject();
		Try
			If IsReferencesToDocument(DocumentObject.Ref) Then
				DocumentObject.SetDeletionMark(True);
			Else
				DocumentObject.Delete();
			EndIf;
			StringsArrayForDelete.Add(TableRow);
		Except
			
			MessageText = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Cannot mark the document for deletion: %1.'"), String(DocumentObject));
			
			Message = New UserMessage;
			Message.Text = MessageText;
			Message.Message();
			
		EndTry;
		
	EndDo;
	
	For Each RowForDeletion In StringsArrayForDelete Do
		
		Orders.Delete(RowForDeletion);
		
	EndDo;
	
EndProcedure

// The procedure updates the Orders table data while changing a purchase order.
//
&AtServer
Procedure RefreshTablePartOrdersServer()
	
	For Each TableRow In Orders Do
		If Not ValueIsFilled(TableRow.Document) Then
			Continue;
		EndIf;
		
		AttributeValues = CommonUse.ObjectAttributesValues(TableRow.Document, "Posted, Counterparty, DocumentAmount");
		TableRow.Vendor = AttributeValues.Counterparty;
		TableRow.DocumentAmount = AttributeValues.DocumentAmount;
		
		TableRow.PictureIndex = ?(AttributeValues.Posted, 1, 0);
		
	EndDo;
	
EndProcedure

&AtClient
Procedure TreeStringsRecount()
	
	UpperLevelStrings = Demand.GetItems();
	For Each UpperLevelRow In UpperLevelStrings Do
		
		QuantityForPurchaseTotal = 0;
		SalesStatisticsQuantityDaysMax = 0;
		SalesStatisticsAverageSaleMax = 0;
		
		LowerLevelElements = UpperLevelRow.GetItems();
		For Each LowerLevelElement In LowerLevelElements Do
			QuantityForPurchaseTotal = QuantityForPurchaseTotal + LowerLevelElement.QuantityForPurchase;
			If LowerLevelElement.SalesStatisticsQuantityDays > SalesStatisticsQuantityDaysMax Then
				SalesStatisticsQuantityDaysMax = LowerLevelElement.SalesStatisticsQuantityDays;
			EndIf;
			If LowerLevelElement.SalesStatisticsAverageSale > SalesStatisticsAverageSaleMax Then
				SalesStatisticsAverageSaleMax = LowerLevelElement.SalesStatisticsAverageSale;
			EndIf;
		EndDo;
		
		UpperLevelRow.QuantityForPurchase = QuantityForPurchaseTotal;
		UpperLevelRow.SalesStatisticsQuantityDays = SalesStatisticsQuantityDaysMax;
		UpperLevelRow.SalesStatisticsAverageSale = SalesStatisticsAverageSaleMax;
		
	EndDo;
	
EndProcedure

#EndRegion
