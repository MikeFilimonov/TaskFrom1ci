#Region Variables

&AtClient
Var FormIsClosing;

#EndRegion

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("ShowGoodsIssue") Then
		ShowGoodsIssue = Parameters.ShowGoodsIssue;
	EndIf;
	
	If Parameters.Property("ShowPurchaseOrders") Then
		ShowPurchaseOrders = Parameters.ShowPurchaseOrders;
	EndIf;
	
	If ShowPurchaseOrders Or Not ShowGoodsIssue Then
		Items.InventoryReserve.Visible			= False;
		Items.InventoryReserveInvoiced.Visible	= False;
		Items.InventoryReserveOrdered.Visible	= False;
	EndIf;
	
	Items.InventorySalesInvoice.Visible = Not (ShowGoodsIssue Or ShowPurchaseOrders);
	
	If ShowGoodsIssue Then
		
		If Parameters.Property("DocumentCurrency") Then
			DocumentCurrency = Parameters.DocumentCurrency;
		EndIf;
	
		If Parameters.Property("AmountIncludesVAT") Then
			AmountIncludesVAT = Parameters.AmountIncludesVAT;
		EndIf;
		
		If Parameters.Property("VATTaxation") Then
			Items.InventoryVATRate.Visible = Parameters.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT;
		Else
			Items.InventoryVATRate.Visible = False;
		EndIf;
		
	Else
		AmountIncludesVAT	= True;
		DocumentCurrency	= Undefined;
		
		Items.InventoryQuantityShipped.Visible	= False;
		Items.InventoryGoodsIssue.Visible		= False;
		Items.InventoryPrice.Visible			= False;
		Items.InventoryVATRate.Visible			= False;
		Items.GroupTotals.Visible				= False;
		
	EndIf;
	
	If ShowPurchaseOrders Then
		Items.InventoryQuantityShipped.Title	= NStr("en = 'Quantity recieved'");
		Items.InventoryGoodsIssue.Title			= NStr("en = 'Goods receipt'");
	EndIf;
	
	FillInventoryTable();
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, MessageText, StandardProcessing)
	
	If Not FormIsClosing AND Not Exit Then
		
		SearchStructure = New Structure("IsSelected", True);
		If AlreadySelectedOrdersOnly Then
			SearchStructure.Insert("OrderIsAlreadySelected", True);
		EndIf;
		
		If Inventory.FindRows(SearchStructure).Count() Then
			Cancel = True;
			ShowQueryBox(New NotifyDescription("BeforeClosingQueryBoxHandler", ThisObject),
					NStr("en = 'Add selected rows to document?'"),
					QuestionDialogMode.YesNoCancel);
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormItemEventHandlersHeader

&AtClient
Procedure Select(Command)
	AddSelectedInventoryToInvoice();
EndProcedure

&AtClient
Procedure CheckAll(Command)
	CheckUncheckAllHandler(True);
EndProcedure

&AtClient
Procedure UncheckAll(Command)
	CheckUncheckAllHandler(False);
EndProcedure

&AtClient
Procedure AlreadySelectedOrdersOnlyOnChange(Item)
	SetAlreadySelectedOrdersOnlyRowFilter();
EndProcedure

#EndRegion

#Region FormItemEventHandlersFormTableInventory

&AtClient
Procedure InventorySelection(Item, SelectedRow, Field, StandardProcessing)
	
	ItemsInventoryCurrentData = Items.Inventory.CurrentData;
	
	If ItemsInventoryCurrentData <> Undefined Then
		If Field.Name = "InventoryOrder" Then
			ShowValue(Undefined, ItemsInventoryCurrentData.Order);
		ElsIf Field.Name = "InventoryGoodsIssue" Then
			CurrentDataGoodsIssue = ItemsInventoryCurrentData.GoodsIssue;
			If ValueIsFilled(CurrentDataGoodsIssue) Then
				ShowValue(Undefined, CurrentDataGoodsIssue);
			EndIf;
		ElsIf Field.Name = "InventorySalesInvoice" Then
			ShowValue(Undefined, ItemsInventoryCurrentData.SalesInvoice);
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure InventoryQuantityOnChange(Item)
	
	InventoryRow = Items.Inventory.CurrentData;
	
	InventoryRow.Amount = InventoryRow.Quantity * InventoryRow.Price;
	
	If InventoryRow.DiscountMarkupPercent = 100 Then
		InventoryRow.Amount = 0;
	ElsIf Not InventoryRow.DiscountMarkupPercent = 0
		AND Not InventoryRow.Quantity = 0 Then
		InventoryRow.Amount = InventoryRow.Amount * (1 - InventoryRow.DiscountMarkupPercent / 100);
	EndIf;
	
	VATRate = DriveReUse.GetVATRateValue(InventoryRow.VATRate);
	
	If AmountIncludesVAT Then
		InventoryRow.VATAmount = InventoryRow.Amount - (InventoryRow.Amount) / ((VATRate + 100) / 100);
	Else
		InventoryRow.VATAmount = InventoryRow.Amount * VATRate / 100;
	EndIf;
	
	InventoryRow.Total = InventoryRow.Amount + ?(AmountIncludesVAT, 0, InventoryRow.VATAmount);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

#Region RetrievingInventoryTableData

&AtServer
Procedure FillInventoryTable()
	
	DocumentData = New Structure(
		"Ref,
		|Company,
		|StructuralUnit");
	
	If ShowPurchaseOrders OR ShowGoodsIssue Then
		DocumentData.Insert("AmountIncludesVAT");
	EndIf;
	
	If ShowPurchaseOrders Then
		DocumentData.Insert("VATTaxation");
	EndIf;
	
	FillPropertyValues(DocumentData, Parameters);
	
	FilterData = GenerateFilterStructure(Not ShowPurchaseOrders, ShowPurchaseOrders);
	FilterDataForGoodsIssue = GenerateFilterStructure(False);
	
	If ShowPurchaseOrders Then
		If ShowGoodsIssue Then
			
			Documents.SupplierInvoice.FillByPurchaseOrders(DocumentData, FilterData, Inventory, Inventory, False);
			
			SupplierInvoiceInventory = Inventory.Unload();
			
			Inventory.Clear();
			Documents.SupplierInvoice.FillByGoodsReceipts(DocumentData, FilterDataForGoodsIssue, Inventory, Inventory, False);
			
			UnionInventory(SupplierInvoiceInventory);
		
		Else
			Documents.GoodsReceipt.FillByPurchaseOrders(DocumentData, FilterDataForGoodsIssue, Inventory);
		EndIf;
	ElsIf ShowGoodsIssue Then
		
		Documents.SalesInvoice.FillBySalesOrders(DocumentData, FilterData, Inventory);
		
		SalesInvoiceInventory = Inventory.Unload();
		
		Inventory.Clear();
		Documents.SalesInvoice.FillByGoodsIssues(DocumentData, FilterDataForGoodsIssue, Inventory);
		
		UnionInventory(SalesInvoiceInventory);
		
		Documents.SalesInvoice.FillByWorkOrdersInventory(DocumentData, FilterData, Inventory);
		Documents.SalesInvoice.FillByWorkOrdersWorks(DocumentData, FilterData, Inventory);
		
	Else
		Documents.GoodsIssue.FillBySalesOrders(DocumentData, FilterDataForGoodsIssue, Inventory);
		
		GoodsIssueInventory = Inventory.Unload();
		
		Inventory.Clear();
		Documents.GoodsIssue.FillBySalesInvoices(DocumentData, FilterDataForGoodsIssue, Inventory);
		
		UnionInventory(GoodsIssueInventory);
		
	EndIf;
	
	InventoryInvoiced = GetFromTempStorage(Parameters.TempStorageInventoryAddress);
	InvoicedAndOrderedInventory = GetInvoicedAndOrderedInventory(InventoryInvoiced);
	InvoicedAndOrderedInventory.Indexes.Add("Products, Characteristic, Batch, Order, GoodsIssue");
	
	AlreadyInvoicedOrders = InvoicedAndOrderedInventory.Copy( , "Order, GoodsIssue, SalesInvoice");
	AlreadyInvoicedOrders.GroupBy("Order, GoodsIssue, SalesInvoice");
	AlreadySelectedOrdersOnly = AlreadyInvoicedOrders.Count();
	
	If Not AlreadySelectedOrdersOnly
		And ValueIsFilled(Parameters.Order) Then
		AlreadySelectedOrdersOnly = True;
		SelectedOrder = Parameters.Order;
	EndIf;
	
	Items.AlreadySelectedOrdersOnly.Visible = AlreadySelectedOrdersOnly;
	SetAlreadySelectedOrdersOnlyRowFilter();

	EmptyGoodsIssueRef = Documents.GoodsIssue.EmptyRef();
	
	For Each InventoryRow In Inventory Do
		
		GoodsIssueFilled = ValueIsFilled(InventoryRow.GoodsIssue);
		GoodsIssueForSearch = ?(InventoryRow.GoodsIssue = Undefined, EmptyGoodsIssueRef, InventoryRow.GoodsIssue);
		
		If NOT GoodsIssueFilled 
			AND ValueIsFilled(InventoryRow.Order) Then
			InventoryRow.QuantityOrdered = InventoryRow.Quantity;
		EndIf;
		
		If ShowGoodsIssue Then
			
			InventoryRow.ReserveOrdered = InventoryRow.Reserve;
			
			If GoodsIssueFilled Then
				InventoryRow.QuantityShipped = InventoryRow.Quantity;
			EndIf;
			
		EndIf;
		
		SearchStructure = New Structure("Products, Characteristic, Batch, Order, GoodsIssue, SalesInvoice");
		FillPropertyValues(SearchStructure, InventoryRow);
		
		SearchStructure.GoodsIssue = GoodsIssueForSearch;
		
		InvoicedAndOrderedInventoryRows = InvoicedAndOrderedInventory.FindRows(SearchStructure);
		If InvoicedAndOrderedInventoryRows.Count() Then
			
			InventoryRow.QuantityInvoiced = InvoicedAndOrderedInventoryRows[0].Quantity;
			
			If ShowGoodsIssue Then
				InventoryRow.ReserveInvoiced = InvoicedAndOrderedInventoryRows[0].Reserve;
				InventoryRow.Content = InvoicedAndOrderedInventoryRows[0].Content;
			EndIf;
			
		EndIf;
		
		If AlreadySelectedOrdersOnly Then
			
			If ValueIsFilled(SelectedOrder) Then
				InventoryRow.OrderIsAlreadySelected = InventoryRow.Order = SelectedOrder;
			Else
				
				RowsFilter = New Structure("Order, GoodsIssue, SalesInvoice", InventoryRow.Order, GoodsIssueForSearch, InventoryRow.SalesInvoice);
				RowsFound = AlreadyInvoicedOrders.FindRows(RowsFilter).Count() > 0;
				
				InventoryRow.OrderIsAlreadySelected = RowsFound OR GoodsIssueFilled AND ShowGoodsIssue;
				
			EndIf;
			
		EndIf;
		
		InventoryRow.IsSelected = InventoryRow.OrderIsAlreadySelected Or Not AlreadySelectedOrdersOnly;
		
	EndDo;
	
EndProcedure

&AtServer
Function GenerateFilterStructure(IsSalesInvoiceFilter, IsSupplierInvoiceFilter = False)
	
	FilterData = New Structure(
		"Company,
		|Counterparty");
	
	If IsSalesInvoiceFilter Then
		FilterData.Insert("PriceKind");
	EndIf;
	
	If IsSalesInvoiceFilter OR IsSupplierInvoiceFilter Then
		FilterData.Insert("DocumentCurrency");
		FilterData.Insert("VATTaxation");
		FilterData.Insert("Contract");
	EndIf;
	
	FillPropertyValues(FilterData, Parameters);
	
	If IsSalesInvoiceFilter Then
		FilterData.Insert("StructuralUnitReserve", Parameters.StructuralUnit);
	EndIf;
	
	Return FilterData
	
EndFunction

&AtServer
Procedure UnionInventory(SalesInvoiceInventory)
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	Inventory.Amount AS Amount,
	|	Inventory.AutomaticDiscountAmount AS AutomaticDiscountAmount,
	|	Inventory.AutomaticDiscountsPercent AS AutomaticDiscountsPercent,
	|	Inventory.Batch AS Batch,
	|	Inventory.Characteristic AS Characteristic,
	|	Inventory.ConnectionKey AS ConnectionKey,
	|	Inventory.Content AS Content,
	|	Inventory.DiscountMarkupPercent AS DiscountMarkupPercent,
	|	Inventory.Factor AS Factor,
	|	Inventory.GoodsIssue AS GoodsIssue,
	|	Inventory.SalesInvoice AS SalesInvoice,
	|	Inventory.Contract AS Contract,
	|	Inventory.IsSelected AS IsSelected,
	|	Inventory.LineNumber AS LineNumber,
	|	Inventory.MeasurementUnit AS MeasurementUnit,
	|	Inventory.Order AS Order,
	|	Inventory.OrderIsAlreadySelected AS OrderIsAlreadySelected,
	|	Inventory.Price AS Price,
	|	Inventory.Products AS Products,
	|	Inventory.ProductsTypeInventory AS ProductsTypeInventory,
	|	Inventory.Quantity AS Quantity,
	|	Inventory.QuantityInvoiced AS QuantityInvoiced,
	|	Inventory.QuantityOrdered AS QuantityOrdered,
	|	Inventory.QuantityShipped AS QuantityShipped,
	|	Inventory.Reserve AS Reserve,
	|	Inventory.ReserveInvoiced AS ReserveInvoiced,
	|	Inventory.ReserveOrdered AS ReserveOrdered,
	|	Inventory.SerialNumbers AS SerialNumbers,
	|	Inventory.Total AS Total,
	|	Inventory.VATAmount AS VATAmount,
	|	Inventory.VATRate AS VATRate
	|INTO Inventory
	|FROM
	|	&Inventory AS Inventory
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SalesInvoiceInventory.Amount AS Amount,
	|	SalesInvoiceInventory.AutomaticDiscountAmount AS AutomaticDiscountAmount,
	|	SalesInvoiceInventory.AutomaticDiscountsPercent AS AutomaticDiscountsPercent,
	|	SalesInvoiceInventory.Batch AS Batch,
	|	SalesInvoiceInventory.Characteristic AS Characteristic,
	|	SalesInvoiceInventory.ConnectionKey AS ConnectionKey,
	|	SalesInvoiceInventory.Content AS Content,
	|	SalesInvoiceInventory.DiscountMarkupPercent AS DiscountMarkupPercent,
	|	SalesInvoiceInventory.Factor AS Factor,
	|	SalesInvoiceInventory.GoodsIssue AS GoodsIssue,
	|	SalesInvoiceInventory.SalesInvoice AS SalesInvoice,
	|	SalesInvoiceInventory.Contract AS Contract,
	|	SalesInvoiceInventory.IsSelected AS IsSelected,
	|	SalesInvoiceInventory.LineNumber AS LineNumber,
	|	SalesInvoiceInventory.MeasurementUnit AS MeasurementUnit,
	|	SalesInvoiceInventory.Order AS Order,
	|	SalesInvoiceInventory.OrderIsAlreadySelected AS OrderIsAlreadySelected,
	|	SalesInvoiceInventory.Price AS Price,
	|	SalesInvoiceInventory.Products AS Products,
	|	SalesInvoiceInventory.ProductsTypeInventory AS ProductsTypeInventory,
	|	SalesInvoiceInventory.Quantity AS Quantity,
	|	SalesInvoiceInventory.QuantityInvoiced AS QuantityInvoiced,
	|	SalesInvoiceInventory.QuantityOrdered AS QuantityOrdered,
	|	SalesInvoiceInventory.QuantityShipped AS QuantityShipped,
	|	SalesInvoiceInventory.Reserve AS Reserve,
	|	SalesInvoiceInventory.ReserveInvoiced AS ReserveInvoiced,
	|	SalesInvoiceInventory.ReserveOrdered AS ReserveOrdered,
	|	SalesInvoiceInventory.SerialNumbers AS SerialNumbers,
	|	SalesInvoiceInventory.Total AS Total,
	|	SalesInvoiceInventory.VATAmount AS VATAmount,
	|	SalesInvoiceInventory.VATRate AS VATRate
	|INTO SalesInvoiceInventory
	|FROM
	|	&SalesInvoiceInventory AS SalesInvoiceInventory
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SUM(AllInventory.Amount) AS Amount,
	|	SUM(AllInventory.AutomaticDiscountAmount) AS AutomaticDiscountAmount,
	|	MAX(AllInventory.AutomaticDiscountsPercent) AS AutomaticDiscountsPercent,
	|	AllInventory.Batch AS Batch,
	|	AllInventory.Characteristic AS Characteristic,
	|	AllInventory.ConnectionKey AS ConnectionKey,
	|	MAX(AllInventory.Content) AS Content,
	|	MAX(AllInventory.DiscountMarkupPercent) AS DiscountMarkupPercent,
	|	AllInventory.Factor AS Factor,
	|	AllInventory.GoodsIssue AS GoodsIssue,
	|	AllInventory.SalesInvoice AS SalesInvoice,
	|	AllInventory.Contract AS Contract,
	|	AllInventory.IsSelected AS IsSelected,
	|	AllInventory.MeasurementUnit AS MeasurementUnit,
	|	AllInventory.Order AS Order,
	|	AllInventory.OrderIsAlreadySelected AS OrderIsAlreadySelected,
	|	MAX(AllInventory.Price) AS Price,
	|	AllInventory.Products AS Products,
	|	MAX(AllInventory.ProductsTypeInventory) AS ProductsTypeInventory,
	|	SUM(AllInventory.Quantity) AS Quantity,
	|	SUM(AllInventory.QuantityInvoiced) AS QuantityInvoiced,
	|	SUM(AllInventory.QuantityOrdered) AS QuantityOrdered,
	|	SUM(AllInventory.QuantityShipped) AS QuantityShipped,
	|	SUM(AllInventory.Reserve) AS Reserve,
	|	SUM(AllInventory.ReserveInvoiced) AS ReserveInvoiced,
	|	SUM(AllInventory.ReserveOrdered) AS ReserveOrdered,
	|	AllInventory.SerialNumbers AS SerialNumbers,
	|	SUM(AllInventory.Total) AS Total,
	|	SUM(AllInventory.VATAmount) AS VATAmount,
	|	MAX(AllInventory.VATRate) AS VATRate
	|FROM
	|	(SELECT
	|		Inventory.Amount AS Amount,
	|		Inventory.AutomaticDiscountAmount AS AutomaticDiscountAmount,
	|		Inventory.AutomaticDiscountsPercent AS AutomaticDiscountsPercent,
	|		Inventory.Batch AS Batch,
	|		Inventory.Characteristic AS Characteristic,
	|		Inventory.ConnectionKey AS ConnectionKey,
	|		Inventory.Content AS Content,
	|		Inventory.DiscountMarkupPercent AS DiscountMarkupPercent,
	|		Inventory.Factor AS Factor,
	|		Inventory.GoodsIssue AS GoodsIssue,
	|		Inventory.SalesInvoice AS SalesInvoice,
	|		Inventory.Contract AS Contract,
	|		Inventory.IsSelected AS IsSelected,
	|		Inventory.LineNumber AS LineNumber,
	|		Inventory.MeasurementUnit AS MeasurementUnit,
	|		Inventory.Order AS Order,
	|		Inventory.OrderIsAlreadySelected AS OrderIsAlreadySelected,
	|		Inventory.Price AS Price,
	|		Inventory.Products AS Products,
	|		Inventory.ProductsTypeInventory AS ProductsTypeInventory,
	|		Inventory.Quantity AS Quantity,
	|		Inventory.QuantityInvoiced AS QuantityInvoiced,
	|		Inventory.QuantityOrdered AS QuantityOrdered,
	|		Inventory.QuantityShipped AS QuantityShipped,
	|		Inventory.Reserve AS Reserve,
	|		Inventory.ReserveInvoiced AS ReserveInvoiced,
	|		Inventory.ReserveOrdered AS ReserveOrdered,
	|		Inventory.SerialNumbers AS SerialNumbers,
	|		Inventory.Total AS Total,
	|		Inventory.VATAmount AS VATAmount,
	|		Inventory.VATRate AS VATRate
	|	FROM
	|		Inventory AS Inventory
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		SalesInvoiceInventory.Amount,
	|		SalesInvoiceInventory.AutomaticDiscountAmount,
	|		SalesInvoiceInventory.AutomaticDiscountsPercent,
	|		SalesInvoiceInventory.Batch,
	|		SalesInvoiceInventory.Characteristic,
	|		SalesInvoiceInventory.ConnectionKey,
	|		SalesInvoiceInventory.Content,
	|		SalesInvoiceInventory.DiscountMarkupPercent,
	|		SalesInvoiceInventory.Factor,
	|		SalesInvoiceInventory.GoodsIssue,
	|		SalesInvoiceInventory.SalesInvoice AS SalesInvoice,
	|		SalesInvoiceInventory.Contract AS Contract,
	|		SalesInvoiceInventory.IsSelected,
	|		SalesInvoiceInventory.LineNumber,
	|		SalesInvoiceInventory.MeasurementUnit,
	|		SalesInvoiceInventory.Order,
	|		SalesInvoiceInventory.OrderIsAlreadySelected,
	|		SalesInvoiceInventory.Price,
	|		SalesInvoiceInventory.Products,
	|		SalesInvoiceInventory.ProductsTypeInventory,
	|		SalesInvoiceInventory.Quantity,
	|		SalesInvoiceInventory.QuantityInvoiced,
	|		SalesInvoiceInventory.QuantityOrdered,
	|		SalesInvoiceInventory.QuantityShipped,
	|		SalesInvoiceInventory.Reserve,
	|		SalesInvoiceInventory.ReserveInvoiced,
	|		SalesInvoiceInventory.ReserveOrdered,
	|		SalesInvoiceInventory.SerialNumbers,
	|		SalesInvoiceInventory.Total,
	|		SalesInvoiceInventory.VATAmount,
	|		SalesInvoiceInventory.VATRate
	|	FROM
	|		SalesInvoiceInventory AS SalesInvoiceInventory) AS AllInventory
	|
	|GROUP BY
	|	AllInventory.IsSelected,
	|	AllInventory.ConnectionKey,
	|	AllInventory.Factor,
	|	AllInventory.GoodsIssue,
	|	AllInventory.SalesInvoice,
	|	AllInventory.Contract,
	|	AllInventory.MeasurementUnit,
	|	AllInventory.Order,
	|	AllInventory.OrderIsAlreadySelected,
	|	AllInventory.Products,
	|	AllInventory.SerialNumbers,
	|	AllInventory.Characteristic,
	|	AllInventory.Batch";
	Query.SetParameter("SalesInvoiceInventory", SalesInvoiceInventory);
	Query.SetParameter("Inventory", Inventory.Unload());
	
	Inventory.Load(Query.Execute().Unload());
	
EndProcedure

&AtServer
Function GetInvoicedAndOrderedInventory(InventoryInvoiced)
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	InventoryInvoiced.Products AS Products,
	|	InventoryInvoiced.Characteristic AS Characteristic,
	|	InventoryInvoiced.Batch AS Batch,
	|	CASE
	|		WHEN InventoryInvoiced.Order = VALUE(Document.PurchaseOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE InventoryInvoiced.Order
	|	END AS Order,
	|	InventoryInvoiced.MeasurementUnit AS MeasurementUnit,
	|	InventoryInvoiced.Quantity AS Quantity,
	|	InventoryInvoiced.Reserve AS Reserve,
	|	CASE
	|		WHEN &ShowGoodsIssue
	|			THEN CAST(InventoryInvoiced.Content AS STRING(1024))
	|		ELSE """"
	|	END AS Content,
	|	CASE
	|		WHEN InventoryInvoiced.GoodsIssue = UNDEFINED
	|				OR InventoryInvoiced.GoodsIssue = VALUE(Document.GoodsReceipt.EmptyRef)
	|			THEN VALUE(Document.GoodsIssue.EmptyRef)
	|		ELSE InventoryInvoiced.GoodsIssue
	|	END AS GoodsIssue,
	|	InventoryInvoiced.SalesInvoice AS SalesInvoice
	|INTO TT_InventoryInvoiced
	|FROM
	|	&InventoryInvoiced AS InventoryInvoiced
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	InventoryOrdered.Products AS Products,
	|	InventoryOrdered.Characteristic AS Characteristic,
	|	InventoryOrdered.Batch AS Batch,
	|	CASE
	|		WHEN InventoryOrdered.Order = VALUE(Document.PurchaseOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE InventoryOrdered.Order
	|	END AS Order,
	|	InventoryOrdered.Factor AS Factor,
	|	InventoryOrdered.Quantity AS Quantity,
	|	InventoryOrdered.Reserve AS Reserve,
	|	CASE
	|		WHEN InventoryOrdered.GoodsIssue = UNDEFINED
	|				OR InventoryOrdered.GoodsIssue = VALUE(Document.GoodsReceipt.EmptyRef)
	|			THEN VALUE(Document.GoodsIssue.EmptyRef)
	|		ELSE InventoryOrdered.GoodsIssue
	|	END AS GoodsIssue,
	|	InventoryOrdered.SalesInvoice AS SalesInvoice
	|INTO TT_InventoryOrdered
	|FROM
	|	&InventoryOrdered AS InventoryOrdered
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_InventoryInvoiced.Products AS Products,
	|	TT_InventoryInvoiced.Characteristic AS Characteristic,
	|	TT_InventoryInvoiced.Batch AS Batch,
	|	TT_InventoryInvoiced.Order AS Order,
	|	SUM(CASE
	|			WHEN VALUETYPE(TT_InventoryInvoiced.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|				THEN 1
	|			ELSE CAST(TT_InventoryInvoiced.MeasurementUnit AS Catalog.UOM).Factor
	|		END * TT_InventoryInvoiced.Quantity / TT_InventoryOrdered.Factor) AS Quantity,
	|	SUM(CASE
	|			WHEN VALUETYPE(TT_InventoryInvoiced.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|				THEN 1
	|			ELSE CAST(TT_InventoryInvoiced.MeasurementUnit AS Catalog.UOM).Factor
	|		END * TT_InventoryInvoiced.Reserve / TT_InventoryOrdered.Factor) AS Reserve,
	|	MAX(TT_InventoryInvoiced.Content) AS Content,
	|	TT_InventoryInvoiced.GoodsIssue AS GoodsIssue,
	|	TT_InventoryInvoiced.SalesInvoice AS SalesInvoice
	|FROM
	|	TT_InventoryInvoiced AS TT_InventoryInvoiced
	|		INNER JOIN TT_InventoryOrdered AS TT_InventoryOrdered
	|		ON TT_InventoryInvoiced.Products = TT_InventoryOrdered.Products
	|			AND TT_InventoryInvoiced.Characteristic = TT_InventoryOrdered.Characteristic
	|			AND TT_InventoryInvoiced.Batch = TT_InventoryOrdered.Batch
	|			AND TT_InventoryInvoiced.Order = TT_InventoryOrdered.Order
	|			AND TT_InventoryInvoiced.GoodsIssue = TT_InventoryOrdered.GoodsIssue
	|			AND TT_InventoryInvoiced.SalesInvoice = TT_InventoryOrdered.SalesInvoice
	|WHERE
	|	TT_InventoryOrdered.Factor > 0
	|
	|GROUP BY
	|	TT_InventoryInvoiced.Characteristic,
	|	TT_InventoryInvoiced.Order,
	|	TT_InventoryInvoiced.GoodsIssue,
	|	TT_InventoryInvoiced.SalesInvoice,
	|	TT_InventoryInvoiced.Products,
	|	TT_InventoryInvoiced.Batch";
	Query.SetParameter("InventoryInvoiced", InventoryInvoiced);
	Query.SetParameter("InventoryOrdered", Inventory.Unload());
	Query.SetParameter("ShowGoodsIssue", ShowGoodsIssue);
	
	Return Query.Execute().Unload();
	
EndFunction

#EndRegion

#Region TransferringInvetoryTableDataToInvoice

&AtClient
Procedure BeforeClosingQueryBoxHandler(QueryResult, AdditionalParameters) Export
	
	If QueryResult = DialogReturnCode.Yes Then
		FormIsClosing = True;
		AddSelectedInventoryToInvoice();
	ElsIf QueryResult = DialogReturnCode.No Then
		FormIsClosing = True;
		Close();
	EndIf;

EndProcedure

&AtClient
Procedure AddSelectedInventoryToInvoice()
	
	TempStorageInventoryAddress = PutInventoryToTempStorage();
	FormIsClosing = True;
	Close();
	NotifyChoice(New Structure("TempStorageInventoryAddress", TempStorageInventoryAddress));
	
EndProcedure

&AtServer
Function PutInventoryToTempStorage()
	
	FilterStructure = New Structure("IsSelected", True);
	If AlreadySelectedOrdersOnly Then
		FilterStructure.Insert("OrderIsAlreadySelected", True);
	EndIf;
	
	SelectedInventory = Inventory.Unload(FilterStructure);
	
	InventoryStructure = New Structure("Inventory", SelectedInventory);
	
	Return PutToTempStorage(InventoryStructure);

EndFunction

#EndRegion

&AtServer
Procedure SetAlreadySelectedOrdersOnlyRowFilter()
	If AlreadySelectedOrdersOnly Then
		Items.Inventory.RowFilter = New FixedStructure("OrderIsAlreadySelected", True);
	Else
		Items.Inventory.RowFilter = Undefined;
	EndIf;
EndProcedure

&AtClient
Procedure CheckUncheckAllHandler(CheckBoxValue)
	
	SelectedRows = Items.Inventory.SelectedRows;
	
	If SelectedRows.Count() > 1 Then
		InventoryRowsToBeProccessed = New Array;
		For Each SelectedRowID In SelectedRows Do
			InventoryRowsToBeProccessed.Add(Inventory.FindByID(SelectedRowID));
		EndDo;
	Else
		InventoryRowsToBeProccessed = Inventory;
	EndIf;
	
	For Each InventoryRow In InventoryRowsToBeProccessed Do
		If InventoryRow.OrderIsAlreadySelected Or Not AlreadySelectedOrdersOnly Then
			InventoryRow.IsSelected = CheckBoxValue;
		EndIf;
	EndDo;
	
EndProcedure

#EndRegion

#Region Initialize

FormIsClosing = False;

#EndRegion
