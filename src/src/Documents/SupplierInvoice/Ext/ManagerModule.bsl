#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ProgramInterface

Procedure FillByPurchaseOrders(DocumentData, FilterData, Inventory, Expenses, DefaultFill = True) Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	PurchaseOrder.Ref AS Ref,
	|	PurchaseOrder.SalesOrder AS SalesOrder,
	|	PurchaseOrder.StructuralUnit AS StructuralUnit
	|INTO TT_PurchaseOrders
	|FROM
	|	Document.PurchaseOrder AS PurchaseOrder
	|WHERE
	|	&PurchaseOrdersConditions
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	OrdersBalance.PurchaseOrder AS PurchaseOrder,
	|	OrdersBalance.Products AS Products,
	|	OrdersBalance.Characteristic AS Characteristic,
	|	SUM(OrdersBalance.QuantityBalance) AS QuantityBalance
	|FROM
	|	(SELECT
	|		OrdersBalance.PurchaseOrder AS PurchaseOrder,
	|		OrdersBalance.Products AS Products,
	|		OrdersBalance.Characteristic AS Characteristic,
	|		OrdersBalance.QuantityBalance AS QuantityBalance
	|	FROM
	|		AccumulationRegister.PurchaseOrders.Balance(
	|				,
	|				PurchaseOrder IN
	|						(SELECT
	|							TT_PurchaseOrders.Ref
	|						FROM
	|							TT_PurchaseOrders)
	|					AND (Products.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
	|						OR Products.ProductsType = VALUE(Enum.ProductsTypes.Service))) AS OrdersBalance
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsPurchaseOrders.PurchaseOrder,
	|		DocumentRegisterRecordsPurchaseOrders.Products,
	|		DocumentRegisterRecordsPurchaseOrders.Characteristic,
	|		CASE
	|			WHEN DocumentRegisterRecordsPurchaseOrders.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN DocumentRegisterRecordsPurchaseOrders.Quantity
	|			ELSE -DocumentRegisterRecordsPurchaseOrders.Quantity
	|		END
	|	FROM
	|		AccumulationRegister.PurchaseOrders AS DocumentRegisterRecordsPurchaseOrders
	|	WHERE
	|		DocumentRegisterRecordsPurchaseOrders.Recorder = &Ref) AS OrdersBalance
	|
	|GROUP BY
	|	OrdersBalance.PurchaseOrder,
	|	OrdersBalance.Products,
	|	OrdersBalance.Characteristic
	|
	|HAVING
	|	SUM(OrdersBalance.QuantityBalance) > 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	PurchaseOrderInventory.LineNumber AS LineNumber,
	|	TT_PurchaseOrders.SalesOrder AS SalesOrder,
	|	TT_PurchaseOrders.StructuralUnit AS StructuralUnitExpense,
	|	ProductsCatalog.Ref AS Products,
	|	ProductsCatalog.ProductsType AS ProductsType,
	|	PrimaryChartOfAccounts.TypeOfAccount AS TypeOfAccount,
	|	PurchaseOrderInventory.Characteristic AS Characteristic,
	|	ISNULL(UOM.Factor, 1) AS Factor,
	|	PurchaseOrderInventory.Quantity AS Quantity,
	|	PurchaseOrderInventory.MeasurementUnit AS MeasurementUnit,
	|	PurchaseOrderInventory.Price AS Price,
	|	PurchaseOrderInventory.Amount AS Amount,
	|	PurchaseOrderInventory.VATRate AS VATRate,
	|	PurchaseOrderInventory.VATAmount AS VATAmount,
	|	PurchaseOrderInventory.Total AS Total,
	|	ProductsCatalog.VATRate AS ReverseChargeVATRate,
	|	PurchaseOrderInventory.Content AS Content,
	|	PurchaseOrderInventory.Ref AS OrderBasis,
	|	ProductsCatalog.ProductsType = VALUE(Enum.ProductsTypes.inventoryItem) AS ProductsTypeInventory
	|FROM
	|	TT_PurchaseOrders AS TT_PurchaseOrders
	|		INNER JOIN Document.PurchaseOrder.Inventory AS PurchaseOrderInventory
	|		ON TT_PurchaseOrders.Ref = PurchaseOrderInventory.Ref
	|		INNER JOIN Catalog.Products AS ProductsCatalog
	|		ON (PurchaseOrderInventory.Products = ProductsCatalog.Ref)
	|		LEFT JOIN ChartOfAccounts.PrimaryChartOfAccounts AS PrimaryChartOfAccounts
	|		ON (ProductsCatalog.ExpensesGLAccount = PrimaryChartOfAccounts.Ref)
	|		LEFT JOIN Catalog.UOM AS UOM
	|		ON (PurchaseOrderInventory.MeasurementUnit = UOM.Ref)
	|WHERE
	|	(ProductsCatalog.ProductsType = VALUE(Enum.ProductsTypes.Service)
	|			OR ProductsCatalog.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem))
	|
	|ORDER BY
	|	LineNumber";
	
	Query.SetParameter("Ref", DocumentData.Ref);
	
	If FilterData.Property("OrdersArray") Then
		FilterString = "PurchaseOrder.Ref IN(&OrdersArray)";
		Query.SetParameter("OrdersArray", FilterData.OrdersArray);
	Else
		FilterString = "";
		NotFirstItem = False;
		For Each FilterItem In FilterData Do
			If NotFirstItem Then
				FilterString = FilterString + "
				|	AND ";
			Else
				NotFirstItem = True;
			EndIf;
			FilterString = FilterString + "PurchaseOrder." + FilterItem.Key + " = &" + FilterItem.Key;
			Query.SetParameter(FilterItem.Key, FilterItem.Value);
		EndDo;
	EndIf;
	
	Query.Text = StrReplace(Query.Text, "&PurchaseOrdersConditions", FilterString);
	
	ResultsArray = Query.ExecuteBatch();
	BalanceTable = ResultsArray[1].Unload();
	BalanceTable.Indexes.Add("PurchaseOrder,Products,Characteristic");
	
	Inventory.Clear();
	Expenses.Clear();
	
	IsReverseCharge = DocumentData.VATTaxation = Enums.VATTaxationTypes.ReverseChargeVAT;
	
	If BalanceTable.Count() > 0 Then
		
		Selection = ResultsArray[2].Select();
		While Selection.Next() Do
			
			StructureForSearch = New Structure;
			StructureForSearch.Insert("PurchaseOrder",	Selection.OrderBasis);
			StructureForSearch.Insert("Products",		Selection.Products);
			StructureForSearch.Insert("Characteristic",	Selection.Characteristic);
			
			BalanceRowsArray = BalanceTable.FindRows(StructureForSearch);
			If BalanceRowsArray.Count() = 0 Then
				Continue;
			EndIf;
			
			If Selection.ProductsTypeInventory Then
				NewRow = Inventory.Add();
				NewRow.Order = Selection.OrderBasis;
			Else
				
				NewRow = Expenses.Add();
				NewRow.PurchaseOrder = Selection.OrderBasis;
				NewRow.StructuralUnit = Selection.StructuralUnitExpense;
				
				If DefaultFill Then
					If ValueIsFilled(Selection.SalesOrder)
						AND (Selection.TypeOfAccount = Enums.GLAccountsTypes.Expenses
						OR Selection.TypeOfAccount = Enums.GLAccountsTypes.IndirectExpenses
						OR Selection.TypeOfAccount = Enums.GLAccountsTypes.WorkInProcess) Then
						NewRow.Order = Selection.SalesOrder;
					EndIf;
				Else
					NewRow.Order = Selection.OrderBasis;
				EndIf;
				
			EndIf;
			
			FillPropertyValues(NewRow, Selection);
			
			QuantityToWriteOff = Selection.Quantity * Selection.Factor;
			BalanceRowsArray[0].QuantityBalance = BalanceRowsArray[0].QuantityBalance - QuantityToWriteOff;
			If BalanceRowsArray[0].QuantityBalance < 0 Then
				
				QuantityToWriteOff = (QuantityToWriteOff + BalanceRowsArray[0].QuantityBalance) / Selection.Factor;
				
				DataStructure = New Structure("Quantity, Price, Amount, VATRate, VATAmount, AmountIncludesVAT, Total");
				DataStructure.Quantity			= QuantityToWriteOff;
				DataStructure.Price				= Selection.Price;
				DataStructure.Amount			= 0;
				DataStructure.VATRate			= Selection.VATRate;
				DataStructure.VATAmount			= 0;
				DataStructure.AmountIncludesVAT	= DocumentData.AmountIncludesVAT;
				DataStructure.Total				= 0;
				
				DataStructure = DriveServer.GetTabularSectionRowSum(DataStructure);
				
				FillPropertyValues(NewRow, DataStructure);
				
			EndIf;
			
			If IsReverseCharge Then
				
				DataStructure = New Structure("Amount, VATRate, VATAmount, AmountIncludesVAT, Total");
				DataStructure.Amount			= NewRow.Total;
				DataStructure.VATRate			= NewRow.ReverseChargeVATRate;
				DataStructure.VATAmount			= 0;
				DataStructure.AmountIncludesVAT	= False;
				DataStructure.Total				= 0;
				
				DataStructure = DriveServer.GetTabularSectionRowSum(DataStructure);
			
				NewRow.ReverseChargeVATAmount = DataStructure.VATAmount;
				
			EndIf;
			
			If BalanceRowsArray[0].QuantityBalance <= 0 Then
				BalanceTable.Delete(BalanceRowsArray[0]);
			EndIf;
			
		EndDo;
		
	EndIf;
	
EndProcedure

Procedure FillByGoodsReceipts(DocumentData, FilterData, Inventory, Expenses, DefaultFill = True) Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	GoodsReceipt.Ref AS Ref,
	|	GoodsReceipt.StructuralUnit AS StructuralUnit
	|INTO TT_GoodsReceipt
	|FROM
	|	Document.GoodsReceipt AS GoodsReceipt
	|WHERE
	|	&GoodsReceiptConditions
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SupplierInvoiceInventory.Order AS Order,
	|	SupplierInvoiceInventory.GoodsReceipt AS GoodsReceipt,
	|	SupplierInvoiceInventory.Products AS Products,
	|	SupplierInvoiceInventory.Characteristic AS Characteristic,
	|	SupplierInvoiceInventory.Batch AS Batch,
	|	SUM(SupplierInvoiceInventory.Quantity * ISNULL(UOM.Factor, 1)) AS BaseQuantity
	|INTO TT_AlreadyInvoiced
	|FROM
	|	Document.SupplierInvoice.Inventory AS SupplierInvoiceInventory
	|		INNER JOIN TT_GoodsReceipt AS TT_GoodsReceipt
	|		ON SupplierInvoiceInventory.GoodsReceipt = TT_GoodsReceipt.Ref
	|		INNER JOIN Document.SalesInvoice AS SalesInvoiceDocument
	|		ON SupplierInvoiceInventory.Ref = SalesInvoiceDocument.Ref
	|		INNER JOIN Catalog.Products AS ProductsCatalog
	|		ON SupplierInvoiceInventory.Products = ProductsCatalog.Ref
	|		LEFT JOIN Catalog.UOM AS UOM
	|		ON SupplierInvoiceInventory.MeasurementUnit = UOM.Ref
	|WHERE
	|	SalesInvoiceDocument.Posted
	|	AND SupplierInvoiceInventory.Ref <> &Ref
	|
	|GROUP BY
	|	SupplierInvoiceInventory.Batch,
	|	SupplierInvoiceInventory.Order,
	|	SupplierInvoiceInventory.Products,
	|	SupplierInvoiceInventory.Characteristic,
	|	SupplierInvoiceInventory.GoodsReceipt
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	OrdersBalance.GoodsReceipt AS GoodsReceipt,
	|	OrdersBalance.PurchaseOrder AS Order,
	|	OrdersBalance.Products AS Products,
	|	OrdersBalance.Characteristic AS Characteristic,
	|	OrdersBalance.Batch AS Batch,
	|	SUM(OrdersBalance.QuantityBalance) AS QuantityBalance
	|INTO GoodsReceivedBalance
	|FROM
	|	(SELECT
	|		GoodsReceivedNotInvoicedBalance.PurchaseOrder AS PurchaseOrder,
	|		GoodsReceivedNotInvoicedBalance.GoodsReceipt AS GoodsReceipt,
	|		GoodsReceivedNotInvoicedBalance.Products AS Products,
	|		GoodsReceivedNotInvoicedBalance.Batch AS Batch,
	|		GoodsReceivedNotInvoicedBalance.Characteristic AS Characteristic,
	|		GoodsReceivedNotInvoicedBalance.QuantityBalance AS QuantityBalance
	|	FROM
	|		AccumulationRegister.GoodsReceivedNotInvoiced.Balance(
	|				,
	|				GoodsReceipt IN
	|					(SELECT
	|						TT_GoodsReceipt.Ref
	|					FROM
	|						TT_GoodsReceipt)) AS GoodsReceivedNotInvoicedBalance
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsGoodsReceivedNotInvoiced.PurchaseOrder,
	|		DocumentRegisterRecordsGoodsReceivedNotInvoiced.GoodsReceipt,
	|		DocumentRegisterRecordsGoodsReceivedNotInvoiced.Products,
	|		DocumentRegisterRecordsGoodsReceivedNotInvoiced.Batch,
	|		DocumentRegisterRecordsGoodsReceivedNotInvoiced.Characteristic,
	|		CASE
	|			WHEN DocumentRegisterRecordsGoodsReceivedNotInvoiced.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN DocumentRegisterRecordsGoodsReceivedNotInvoiced.Quantity
	|			ELSE -DocumentRegisterRecordsGoodsReceivedNotInvoiced.Quantity
	|		END
	|	FROM
	|		AccumulationRegister.GoodsReceivedNotInvoiced AS DocumentRegisterRecordsGoodsReceivedNotInvoiced
	|	WHERE
	|		DocumentRegisterRecordsGoodsReceivedNotInvoiced.Recorder = &Ref) AS OrdersBalance
	|
	|GROUP BY
	|	OrdersBalance.GoodsReceipt,
	|	OrdersBalance.PurchaseOrder,
	|	OrdersBalance.Products,
	|	OrdersBalance.Characteristic,
	|	OrdersBalance.Batch
	|
	|HAVING
	|	SUM(OrdersBalance.QuantityBalance) > 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	GoodsReceiptInventory.LineNumber AS LineNumber,
	|	TT_GoodsReceipt.StructuralUnit AS StructuralUnitExpense,
	|	ProductsCatalog.Ref AS Products,
	|	ProductsCatalog.ProductsType AS ProductsType,
	|	GoodsReceiptInventory.Characteristic AS Characteristic,
	|	ISNULL(UOM.Factor, 1) AS Factor,
	|	GoodsReceiptInventory.Quantity AS Quantity,
	|	GoodsReceiptInventory.MeasurementUnit AS MeasurementUnit,
	|	GoodsReceiptInventory.Batch AS Batch,
	|	GoodsReceiptInventory.Order AS Order,
	|	GoodsReceiptInventory.Contract AS Contract,
	|	ProductsCatalog.VATRate AS VATRate,
	|	ProductsCatalog.VATRate AS ReverseChargeVATRate,
	|	GoodsReceiptInventory.Ref AS GoodsReceipt,
	|	TRUE AS ProductsTypeInventory,
	|	GoodsReceiptInventory.InventoryGLAccount AS InventoryGLAccount,
	|	GoodsReceiptInventory.GoodsReceivedNotInvoicedGLAccount AS GoodsReceivedNotInvoicedGLAccount,
	|	GoodsReceiptInventory.GoodsInvoicedNotDeliveredGLAccount AS GoodsInvoicedNotDeliveredGLAccount
	|INTO TT_Inventory
	|FROM
	|	TT_GoodsReceipt AS TT_GoodsReceipt
	|		INNER JOIN Document.GoodsReceipt.Products AS GoodsReceiptInventory
	|		ON TT_GoodsReceipt.Ref = GoodsReceiptInventory.Ref
	|		INNER JOIN Catalog.Products AS ProductsCatalog
	|		ON (GoodsReceiptInventory.Products = ProductsCatalog.Ref)
	|		LEFT JOIN Catalog.UOM AS UOM
	|		ON (GoodsReceiptInventory.MeasurementUnit = UOM.Ref)
	|WHERE
	|	(GoodsReceiptInventory.Contract = &Contract
	|			OR &Contract = UNDEFINED)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_Inventory.LineNumber AS LineNumber,
	|	TT_Inventory.Products AS Products,
	|	TT_Inventory.Characteristic AS Characteristic,
	|	TT_Inventory.Batch AS Batch,
	|	TT_Inventory.Order AS Order,
	|	TT_Inventory.GoodsReceipt AS GoodsReceipt,
	|	TT_Inventory.Factor AS Factor,
	|	TT_Inventory.Quantity * TT_Inventory.Factor AS BaseQuantity,
	|	SUM(TT_InventoryCumulative.Quantity * TT_InventoryCumulative.Factor) AS BaseQuantityCumulative
	|INTO TT_InventoryCumulative
	|FROM
	|	TT_Inventory AS TT_Inventory
	|		INNER JOIN TT_Inventory AS TT_InventoryCumulative
	|		ON TT_Inventory.Products = TT_InventoryCumulative.Products
	|			AND TT_Inventory.Characteristic = TT_InventoryCumulative.Characteristic
	|			AND TT_Inventory.Batch = TT_InventoryCumulative.Batch
	|			AND TT_Inventory.Order = TT_InventoryCumulative.Order
	|			AND TT_Inventory.GoodsReceipt = TT_InventoryCumulative.GoodsReceipt
	|			AND TT_Inventory.LineNumber >= TT_InventoryCumulative.LineNumber
	|
	|GROUP BY
	|	TT_Inventory.LineNumber,
	|	TT_Inventory.Products,
	|	TT_Inventory.Characteristic,
	|	TT_Inventory.Batch,
	|	TT_Inventory.Order,
	|	TT_Inventory.GoodsReceipt,
	|	TT_Inventory.Factor,
	|	TT_Inventory.Quantity * TT_Inventory.Factor
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_InventoryCumulative.LineNumber AS LineNumber,
	|	TT_InventoryCumulative.Products AS Products,
	|	TT_InventoryCumulative.Characteristic AS Characteristic,
	|	TT_InventoryCumulative.Batch AS Batch,
	|	TT_InventoryCumulative.Order AS Order,
	|	TT_InventoryCumulative.GoodsReceipt AS GoodsReceipt,
	|	TT_InventoryCumulative.Factor AS Factor,
	|	CASE
	|		WHEN TT_AlreadyInvoiced.BaseQuantity > TT_InventoryCumulative.BaseQuantityCumulative - TT_InventoryCumulative.BaseQuantity
	|			THEN TT_InventoryCumulative.BaseQuantityCumulative - TT_AlreadyInvoiced.BaseQuantity
	|		ELSE TT_InventoryCumulative.BaseQuantity
	|	END AS BaseQuantity
	|INTO TT_InventoryNotYetInvoiced
	|FROM
	|	TT_InventoryCumulative AS TT_InventoryCumulative
	|		LEFT JOIN TT_AlreadyInvoiced AS TT_AlreadyInvoiced
	|		ON TT_InventoryCumulative.Products = TT_AlreadyInvoiced.Products
	|			AND TT_InventoryCumulative.Characteristic = TT_AlreadyInvoiced.Characteristic
	|			AND TT_InventoryCumulative.Batch = TT_AlreadyInvoiced.Batch
	|			AND TT_InventoryCumulative.Order = TT_AlreadyInvoiced.Order
	|			AND TT_InventoryCumulative.GoodsReceipt = TT_AlreadyInvoiced.GoodsReceipt
	|WHERE
	|	ISNULL(TT_AlreadyInvoiced.BaseQuantity, 0) < TT_InventoryCumulative.BaseQuantityCumulative
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_InventoryNotYetInvoiced.LineNumber AS LineNumber,
	|	TT_InventoryNotYetInvoiced.Products AS Products,
	|	TT_InventoryNotYetInvoiced.Characteristic AS Characteristic,
	|	TT_InventoryNotYetInvoiced.Batch AS Batch,
	|	TT_InventoryNotYetInvoiced.Order AS Order,
	|	TT_InventoryNotYetInvoiced.GoodsReceipt AS GoodsReceipt,
	|	TT_InventoryNotYetInvoiced.Factor AS Factor,
	|	TT_InventoryNotYetInvoiced.BaseQuantity AS BaseQuantity,
	|	SUM(TT_InventoryNotYetInvoicedCumulative.BaseQuantity) AS BaseQuantityCumulative
	|INTO TT_InventoryNotYetInvoicedCumulative
	|FROM
	|	TT_InventoryNotYetInvoiced AS TT_InventoryNotYetInvoiced
	|		INNER JOIN TT_InventoryNotYetInvoiced AS TT_InventoryNotYetInvoicedCumulative
	|		ON TT_InventoryNotYetInvoiced.Products = TT_InventoryNotYetInvoicedCumulative.Products
	|			AND TT_InventoryNotYetInvoiced.Characteristic = TT_InventoryNotYetInvoicedCumulative.Characteristic
	|			AND TT_InventoryNotYetInvoiced.Batch = TT_InventoryNotYetInvoicedCumulative.Batch
	|			AND TT_InventoryNotYetInvoiced.Order = TT_InventoryNotYetInvoicedCumulative.Order
	|			AND TT_InventoryNotYetInvoiced.GoodsReceipt = TT_InventoryNotYetInvoicedCumulative.GoodsReceipt
	|			AND TT_InventoryNotYetInvoiced.LineNumber >= TT_InventoryNotYetInvoicedCumulative.LineNumber
	|
	|GROUP BY
	|	TT_InventoryNotYetInvoiced.LineNumber,
	|	TT_InventoryNotYetInvoiced.Products,
	|	TT_InventoryNotYetInvoiced.Characteristic,
	|	TT_InventoryNotYetInvoiced.Batch,
	|	TT_InventoryNotYetInvoiced.Order,
	|	TT_InventoryNotYetInvoiced.GoodsReceipt,
	|	TT_InventoryNotYetInvoiced.Factor,
	|	TT_InventoryNotYetInvoiced.BaseQuantity
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_InventoryNotYetInvoicedCumulative.LineNumber AS LineNumber,
	|	TT_InventoryNotYetInvoicedCumulative.Products AS Products,
	|	TT_InventoryNotYetInvoicedCumulative.Characteristic AS Characteristic,
	|	TT_InventoryNotYetInvoicedCumulative.Batch AS Batch,
	|	TT_InventoryNotYetInvoicedCumulative.Order AS Order,
	|	TT_InventoryNotYetInvoicedCumulative.GoodsReceipt AS GoodsReceipt,
	|	TT_InventoryNotYetInvoicedCumulative.Factor AS Factor,
	|	CASE
	|		WHEN TT_GoodsReceivedBalance.QuantityBalance > TT_InventoryNotYetInvoicedCumulative.BaseQuantityCumulative
	|			THEN TT_InventoryNotYetInvoicedCumulative.BaseQuantity
	|		WHEN TT_GoodsReceivedBalance.QuantityBalance > TT_InventoryNotYetInvoicedCumulative.BaseQuantityCumulative - TT_InventoryNotYetInvoicedCumulative.BaseQuantity
	|			THEN TT_GoodsReceivedBalance.QuantityBalance - (TT_InventoryNotYetInvoicedCumulative.BaseQuantityCumulative - TT_InventoryNotYetInvoicedCumulative.BaseQuantity)
	|	END AS BaseQuantity
	|INTO TT_InventoryToBeInvoiced
	|FROM
	|	TT_InventoryNotYetInvoicedCumulative AS TT_InventoryNotYetInvoicedCumulative
	|		INNER JOIN GoodsReceivedBalance AS TT_GoodsReceivedBalance
	|		ON TT_InventoryNotYetInvoicedCumulative.Products = TT_GoodsReceivedBalance.Products
	|			AND TT_InventoryNotYetInvoicedCumulative.Characteristic = TT_GoodsReceivedBalance.Characteristic
	|			AND TT_InventoryNotYetInvoicedCumulative.Order = TT_GoodsReceivedBalance.Order
	|			AND TT_InventoryNotYetInvoicedCumulative.GoodsReceipt = TT_GoodsReceivedBalance.GoodsReceipt
	|WHERE
	|	TT_GoodsReceivedBalance.QuantityBalance > TT_InventoryNotYetInvoicedCumulative.BaseQuantityCumulative - TT_InventoryNotYetInvoicedCumulative.BaseQuantity
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_Inventory.LineNumber AS LineNumber,
	|	TT_Inventory.Products AS Products,
	|	TT_Inventory.ProductsTypeInventory AS ProductsTypeInventory,
	|	TT_Inventory.Characteristic AS Characteristic,
	|	TT_Inventory.Batch AS Batch,
	|	CASE
	|		WHEN (CAST(TT_Inventory.Quantity * TT_Inventory.Factor AS NUMBER(15, 3))) = TT_InventoryToBeInvoiced.BaseQuantity
	|			THEN TT_Inventory.Quantity
	|		ELSE CAST(TT_InventoryToBeInvoiced.BaseQuantity / TT_Inventory.Factor AS NUMBER(15, 3))
	|	END AS Quantity,
	|	TT_Inventory.MeasurementUnit AS MeasurementUnit,
	|	TT_Inventory.Factor AS Factor,
	|	TT_Inventory.Order AS Order,
	|	TT_Inventory.Contract AS Contract,
	|	TT_Inventory.GoodsReceipt AS GoodsReceipt,
	|	PurchaseOrderInventory.Price AS Price,
	|	ISNULL(PurchaseOrderInventory.VATRate, CatProducts.VATRate) AS VATRate,
	|	ISNULL(PurchaseOrderInventory.Quantity, 0) AS QuantityOrd,
	|	TT_Inventory.InventoryGLAccount AS InventoryGLAccount,
	|	TT_Inventory.GoodsReceivedNotInvoicedGLAccount AS GoodsReceivedNotInvoicedGLAccount,
	|	TT_Inventory.GoodsInvoicedNotDeliveredGLAccount AS GoodsInvoicedNotDeliveredGLAccount
	|INTO TT_WithOrders
	|FROM
	|	TT_Inventory AS TT_Inventory
	|		INNER JOIN TT_InventoryToBeInvoiced AS TT_InventoryToBeInvoiced
	|		ON TT_Inventory.LineNumber = TT_InventoryToBeInvoiced.LineNumber
	|			AND TT_Inventory.Order = TT_InventoryToBeInvoiced.Order
	|			AND TT_Inventory.GoodsReceipt = TT_InventoryToBeInvoiced.GoodsReceipt
	|		LEFT JOIN Document.PurchaseOrder.Inventory AS PurchaseOrderInventory
	|		ON TT_Inventory.Order = PurchaseOrderInventory.Ref
	|			AND TT_Inventory.Products = PurchaseOrderInventory.Products
	|			AND TT_Inventory.Characteristic = PurchaseOrderInventory.Characteristic
	|			AND TT_Inventory.MeasurementUnit = PurchaseOrderInventory.MeasurementUnit
	|		LEFT JOIN Catalog.Products AS CatProducts
	|		ON TT_Inventory.Products = CatProducts.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_WithOrders.LineNumber AS LineNumber,
	|	TT_WithOrders.Products AS Products,
	|	TT_WithOrders.ProductsTypeInventory AS ProductsTypeInventory,
	|	TT_WithOrders.Characteristic AS Characteristic,
	|	TT_WithOrders.Batch AS Batch,
	|	TT_WithOrders.Quantity AS Quantity,
	|	TT_WithOrders.MeasurementUnit AS MeasurementUnit,
	|	TT_WithOrders.Factor AS Factor,
	|	TT_WithOrders.Order AS Order,
	|	TT_WithOrders.Contract AS Contract,
	|	TT_WithOrders.GoodsReceipt AS GoodsReceipt,
	|	MAX(ISNULL(ISNULL(TT_WithOrders.Price, PricesSliceLast.Price), 0)) AS Price,
	|	TT_WithOrders.VATRate AS VATRate,
	|	MAX(TT_WithOrders.QuantityOrd) AS QuantityOrd,
	|	TT_WithOrders.InventoryGLAccount AS InventoryGLAccount,
	|	TT_WithOrders.GoodsReceivedNotInvoicedGLAccount AS GoodsReceivedNotInvoicedGLAccount,
	|	TT_WithOrders.GoodsInvoicedNotDeliveredGLAccount AS GoodsInvoicedNotDeliveredGLAccount
	|FROM
	|	TT_WithOrders AS TT_WithOrders
	|		LEFT JOIN InformationRegister.CounterpartyPrices.SliceLast AS PricesSliceLast
	|		ON TT_WithOrders.Products = PricesSliceLast.Products
	|			AND TT_WithOrders.Characteristic = PricesSliceLast.Characteristic
	|			AND TT_WithOrders.MeasurementUnit = PricesSliceLast.MeasurementUnit
	|			AND TT_WithOrders.Contract.SupplierPriceTypes = PricesSliceLast.SupplierPriceTypes
	|
	|GROUP BY
	|	TT_WithOrders.MeasurementUnit,
	|	TT_WithOrders.Products,
	|	TT_WithOrders.ProductsTypeInventory,
	|	TT_WithOrders.Order,
	|	TT_WithOrders.Batch,
	|	TT_WithOrders.Characteristic,
	|	TT_WithOrders.Contract,
	|	TT_WithOrders.GoodsReceipt,
	|	TT_WithOrders.VATRate,
	|	TT_WithOrders.LineNumber,
	|	TT_WithOrders.Quantity,
	|	TT_WithOrders.Factor,
	|	TT_WithOrders.InventoryGLAccount,
	|	TT_WithOrders.GoodsReceivedNotInvoicedGLAccount,
	|	TT_WithOrders.GoodsInvoicedNotDeliveredGLAccount";
	
	Query.SetParameter("Ref", DocumentData.Ref);
		
	Contract = Undefined;
	
	FilterData.Property("Contract", Contract);
	Query.SetParameter("Contract", Contract);
	
	If FilterData.Property("ArrayOfGoodsReceipts") Then
		FilterString = "GoodsReceipt.Ref IN(&ArrayOfGoodsReceipts)";
		Query.SetParameter("ArrayOfGoodsReceipts", FilterData.ArrayOfGoodsReceipts);
	Else
		FilterString = "";
		NotFirstItem = False;
		For Each FilterItem In FilterData Do
			If NotFirstItem Then
				FilterString = FilterString + "
				|	AND ";
			Else
				NotFirstItem = True;
			EndIf;
			FilterString = FilterString + "GoodsReceipt." + FilterItem.Key + " = &" + FilterItem.Key;
			Query.SetParameter(FilterItem.Key, FilterItem.Value);
		EndDo;
	EndIf;
	
	Query.Text = StrReplace(Query.Text, "&GoodsReceiptConditions", FilterString);
	
	Result = Query.Execute();
	Selection = Result.Select();
	
	StructureData = New Structure;
	StructureData.Insert("ObjectParameters", DocumentData);
	
	Inventory.Clear();
	Expenses.Clear();
	
	While Selection.Next() Do
		
		TabularSectionRow = Inventory.Add();
		
		FillPropertyValues(TabularSectionRow, Selection);
		
		If Not DefaultFill Then
			TabularSectionRow.GoodsIssue = Selection.GoodsReceipt;
		EndIf;
		
		TabularSectionRow.Amount = TabularSectionRow.Quantity * TabularSectionRow.Price;
		
		VATRate = DriveReUse.GetVATRateValue(TabularSectionRow.VATRate);
	
		TabularSectionRow.VATAmount = ?(DocumentData.AmountIncludesVAT,
										TabularSectionRow.Amount - (TabularSectionRow.Amount) / ((VATRate + 100) / 100),
										TabularSectionRow.Amount * VATRate / 100);

		TabularSectionRow.Total = TabularSectionRow.Amount + ?(DocumentData.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
		
	EndDo;
	
	If FilterData.Property("ArrayOfGoodsReceipts") Then
		GLAccountsInDocuments.FillTabSectionFromProductGLAccounts(DocumentData.Ref, FilterData.ArrayOfGoodsReceipts);
	EndIf;

EndProcedure

// Exists or not Early payment discount on specified date
// Parameters:
//  DocumentRefSupplierInvoice - DocumentRef.SupplierInvoice - the Supplier invoice on which we check the EPD
//  CheckDate - date - the date of EPD check
// Returns:
//  Boolean - TRUE if EPD exists
//
Function CheckExistsEPD(DocumentRefSupplierInvoice, CheckDate) Export
	
	Result = False;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	TRUE AS ExistsEPD
	|FROM
	|	Document.SupplierInvoice.EarlyPaymentDiscounts AS SupplierInvoiceEarlyPaymentDiscounts
	|WHERE
	|	SupplierInvoiceEarlyPaymentDiscounts.Ref = &Ref
	|	AND ENDOFPERIOD(SupplierInvoiceEarlyPaymentDiscounts.DueDate, DAY) >= &DueDate";
	
	Query.SetParameter("Ref", DocumentRefSupplierInvoice);
	Query.SetParameter("DueDate", CheckDate);
	
	QuerySelection = Query.Execute().Select();
	If QuerySelection.Next() Then
		Result = QuerySelection.ExistsEPD;
	EndIf;
	
	Return Result;
	
EndFunction

// Gets an array of invoices that have an EPD on the specified date
// Parameters:
//  SupplierInvoiceArray - Array - documents (DocumentRef.SupplierInvoice)
//  CheckDate - date - the date of EPD check
// Returns:
//  Array - documents (DocumentRef.SupplierInvoice) that have an EPD
//
Function GetSupplierInvoiceArrayWithEPD(SupplierInvoiceArray, Val CheckDate) Export
	
	Result = New Array;
	
	Query = New Query;
	Query.Text =
	"SELECT DISTINCT
	|	SupplierInvoiceEarlyPaymentDiscounts.Ref AS SupplierInvoice
	|FROM
	|	Document.SupplierInvoice.EarlyPaymentDiscounts AS SupplierInvoiceEarlyPaymentDiscounts
	|WHERE
	|	SupplierInvoiceEarlyPaymentDiscounts.Ref IN(&SupplierInvoices)
	|	AND ENDOFPERIOD(SupplierInvoiceEarlyPaymentDiscounts.DueDate, DAY) >= &DueDate";
	
	Query.SetParameter("SupplierInvoices", SupplierInvoiceArray);
	Query.SetParameter("DueDate", CheckDate);
	
	QueryResult = Query.Execute();
	
	If NOT QueryResult.IsEmpty() Then
		Result = QueryResult.Unload().UnloadColumn("SupplierInvoice");
	EndIf;
	
	Return Result;
	
EndFunction

#EndRegion

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventory(DocumentRefPurchaseInvoice, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	MIN(TableInventory.LineNumber) AS LineNumber,
	|	TableInventory.RecordType AS RecordType,
	|	TableInventory.Period AS Period,
	|	TableInventory.Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	TableInventory.CorrOrganization AS CorrOrganization,
	|	ISNULL(TableInventory.StructuralUnit, VALUE(Catalog.Counterparties.EmptyRef)) AS StructuralUnit,
	|	ISNULL(TableInventory.StructuralUnitCorr, VALUE(Catalog.BusinessUnits.EmptyRef)) AS StructuralUnitCorr,
	|	TableInventory.GLAccount AS GLAccount,
	|	TableInventory.CorrGLAccount AS CorrGLAccount,
	|	TableInventory.Products AS Products,
	|	TableInventory.ProductsCorr AS ProductsCorr,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.CharacteristicCorr AS CharacteristicCorr,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.BatchCorr AS BatchCorr,
	|	TableInventory.VATRate AS VATRate,
	|	VALUE(Catalog.Employees.EmptyRef) AS Responsible,
	|	FALSE AS Return,
	|	CASE
	|		WHEN TableInventory.GoodsReceipt <> VALUE(Document.GoodsReceipt.EmptyRef)
	|			THEN TableInventory.GoodsReceipt
	|		ELSE UNDEFINED
	|	END AS SourceDocument,
	|	UNDEFINED AS SalesOrder,
	|	UNDEFINED AS CorrSalesOrder,
	|	VALUE(Catalog.BusinessUnits.EmptyRef) AS Department,
	|	TableInventory.Order AS SupplySource,
	|	UNDEFINED AS CustomerCorrOrder,
	|	TableInventory.FixedCost AS FixedCost,
	|	TableInventory.ContentOfAccountingRecord AS ContentOfAccountingRecord,
	|	SUM(CASE
	|			WHEN TableInventory.GoodsReceipt <> VALUE(Document.GoodsReceipt.EmptyRef)
	|				THEN 0
	|			ELSE TableInventory.Quantity
	|		END) AS Quantity,
	|	SUM(TableInventory.Amount - TableInventory.VATAmount + TableInventory.AmountExpense + TableInventory.ReverseChargeVATAmountForNotRegistered) AS Amount,
	|	0 AS Cost,
	|	FALSE AS OfflineRecord
	|FROM
	|	TemporaryTableInventory AS TableInventory,
	|	Constant.UseInventoryReservation AS UseInventoryReservation
	|WHERE
	|	NOT TableInventory.RetailTransferEarningAccounting
	|
	|GROUP BY
	|	TableInventory.Period,
	|	TableInventory.Company,
	|	TableInventory.CorrOrganization,
	|	TableInventory.StructuralUnit,
	|	TableInventory.StructuralUnitCorr,
	|	TableInventory.GLAccount,
	|	TableInventory.CorrGLAccount,
	|	TableInventory.Products,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	TableInventory.ProductsCorr,
	|	TableInventory.CharacteristicCorr,
	|	TableInventory.BatchCorr,
	|	TableInventory.VATRate,
	|	TableInventory.FixedCost,
	|	TableInventory.ContentOfAccountingRecord,
	|	TableInventory.RecordType,
	|	CASE
	|		WHEN TableInventory.GoodsReceipt <> VALUE(Document.GoodsReceipt.EmptyRef)
	|			THEN TableInventory.GoodsReceipt
	|		ELSE UNDEFINED
	|	END,
	|	TableInventory.Order
	|
	|UNION ALL
	|
	|SELECT
	|	OfflineRecords.LineNumber,
	|	OfflineRecords.RecordType,
	|	OfflineRecords.Period,
	|	OfflineRecords.Company,
	|	UNDEFINED,
	|	UNDEFINED,
	|	OfflineRecords.StructuralUnit,
	|	OfflineRecords.StructuralUnitCorr,
	|	OfflineRecords.GLAccount,
	|	OfflineRecords.CorrGLAccount,
	|	OfflineRecords.Products,
	|	OfflineRecords.ProductsCorr,
	|	OfflineRecords.Characteristic,
	|	OfflineRecords.CharacteristicCorr,
	|	OfflineRecords.Batch,
	|	OfflineRecords.BatchCorr,
	|	OfflineRecords.VATRate,
	|	OfflineRecords.Responsible,
	|	OfflineRecords.Return,
	|	OfflineRecords.SourceDocument,
	|	OfflineRecords.SalesOrder,
	|	OfflineRecords.CorrSalesOrder,
	|	OfflineRecords.Department,
	|	UNDEFINED,
	|	OfflineRecords.CustomerCorrOrder,
	|	OfflineRecords.FixedCost,
	|	OfflineRecords.ContentOfAccountingRecord,
	|	OfflineRecords.Quantity,
	|	OfflineRecords.Amount,
	|	0,
	|	OfflineRecords.OfflineRecord
	|FROM
	|	AccumulationRegister.Inventory AS OfflineRecords
	|WHERE
	|	OfflineRecords.Recorder = &Ref
	|	AND OfflineRecords.OfflineRecord";
	
	Query.SetParameter("RegisteredForVAT", StructureAdditionalProperties.AccountingPolicy.RegisteredForVAT);
	Query.SetParameter("Ref", DocumentRefPurchaseInvoice);
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventory", QueryResult.Unload());
	
	GenerateTableInventoryIncrease(DocumentRefPurchaseInvoice, StructureAdditionalProperties);
	GenerateTableSalesInvoices(DocumentRefPurchaseInvoice, StructureAdditionalProperties);
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventoryIncrease(DocumentRefPurchaseInvoice, StructureAdditionalProperties)
	
	TableInventory = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.CopyColumns();
	TableBackorders = StructureAdditionalProperties.TableForRegisterRecords.TableBackorders.CopyColumns();
	
	PlacementsNumber = StructureAdditionalProperties.TableForRegisterRecords.TableBackorders.Total("Quantity");
	
	For n = 0 To StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Count() - 1 Do
		
		RowTableInventory = TableInventory.Add();
		FillPropertyValues(RowTableInventory, StructureAdditionalProperties.TableForRegisterRecords.TableInventory[n]);
		
		StructureForSearch = New Structure;
		StructureForSearch.Insert("SupplySource",	RowTableInventory.SupplySource);
		StructureForSearch.Insert("Products",		RowTableInventory.Products);
		StructureForSearch.Insert("Characteristic",	RowTableInventory.Characteristic);
		
		RowTableInventory.SalesOrder = Undefined;
		
		If PlacementsNumber = 0 Then
			Continue;
		EndIf;
		
		PlacedOrdersArray = StructureAdditionalProperties.TableForRegisterRecords.TableBackorders.FindRows(StructureForSearch);
		
		RowTableInventoryQuantity = RowTableInventory.Quantity;
		
		If PlacedOrdersArray.Count() > 0 Then
			
			For Each ArrayRow In PlacedOrdersArray Do
				
				If RowTableInventoryQuantity > 0 AND ArrayRow.Quantity >= RowTableInventoryQuantity Then
					
					// Placement
					NewRowTableBackorders = TableBackorders.Add();
					FillPropertyValues(NewRowTableBackorders, ArrayRow);
					
					NewRowTableBackorders.Quantity = RowTableInventoryQuantity;
					
					// Inventory
					RowTableInventory.SalesOrder = ArrayRow.SalesOrder;
					RowTableInventoryQuantity = 0;
					
				ElsIf RowTableInventoryQuantity > 0 AND ArrayRow.Quantity < RowTableInventoryQuantity Then
					
					// Placement
					NewRowTableBackorders = TableBackorders.Add();
					FillPropertyValues(NewRowTableBackorders, ArrayRow);
					
					// Inventory
					AmountToBeWrittenOff = Round(RowTableInventory.Amount * ArrayRow.Quantity / RowTableInventoryQuantity, 2, 1);
					
					NewRowTableSupplies = TableInventory.Add();
					FillPropertyValues(NewRowTableSupplies, RowTableInventory);
					NewRowTableSupplies.SalesOrder = ?(ValueIsFilled(ArrayRow.SalesOrder), ArrayRow.SalesOrder, Undefined);
					NewRowTableSupplies.Quantity = ArrayRow.Quantity;
					NewRowTableSupplies.Amount = AmountToBeWrittenOff;
					
					RowTableInventoryQuantity = RowTableInventoryQuantity - ArrayRow.Quantity;
					
					RowTableInventory.Quantity = RowTableInventoryQuantity;
					RowTableInventory.Amount = RowTableInventory.Amount - AmountToBeWrittenOff;
					
				EndIf;
				
			EndDo;
			
		EndIf;
		
	EndDo;
	
	StructureAdditionalProperties.TableForRegisterRecords.TableInventory = TableInventory;
	
	StructureAdditionalProperties.TableForRegisterRecords.TableBackorders = TableBackorders;
	TableBackorders = Undefined;
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableSalesInvoices(DocumentRefPurchaseInvoice, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	MIN(TableInventory.LineNumber) AS LineNumber,
	|	TableInventory.RecordType AS RecordType,
	|	TableInventory.Period AS Period,
	|	TableInventory.Company AS Company,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	TableInventory.GLAccount AS GLAccount,
	|	VALUE(Catalog.Products.EmptyRef) AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	CASE
	|		WHEN TableInventory.Order = VALUE(Document.SalesOrder.EmptyRef)
	|				OR TableInventory.Order = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE TableInventory.Order
	|	END AS SalesOrder,
	|	0 AS Quantity,
	|	SUM(TableInventory.Amount - TableInventory.VATAmount) AS Amount,
	|	TRUE AS FixedCost,
	|	&OtherExpenses AS ContentOfAccountingRecord
	|FROM
	|	TemporaryTableExpenses AS TableInventory
	|WHERE
	|	NOT TableInventory.IncludeExpensesInCostPrice
	|	AND (TableInventory.TypeOfAccount = VALUE(Enum.GLAccountsTypes.WorkInProcess)
	|			OR TableInventory.TypeOfAccount = VALUE(Enum.GLAccountsTypes.IndirectExpenses))
	|
	|GROUP BY
	|	TableInventory.Period,
	|	TableInventory.Company,
	|	TableInventory.StructuralUnit,
	|	TableInventory.GLAccount,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	TableInventory.Order,
	|	TableInventory.RecordType";
	
	Query.SetParameter("OtherExpenses",
		NStr("en = 'Expenses incurred'",
			StructureAdditionalProperties.DefaultLanguageCode));
	
	QueryResult = Query.Execute();
	
	If StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Count() = 0 Then
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventory", QueryResult.Unload());
	Else
		
		Selection = QueryResult.Select();
		While Selection.Next() Do
			
			NewRow = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
			FillPropertyValues(NewRow, Selection);
			
		EndDo;
		
	EndIf;
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableIncomeAndExpenses(DocumentRefPurchaseInvoice, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	MIN(TableIncomeAndExpenses.LineNumber) AS LineNumber,
	|	TableIncomeAndExpenses.Period AS Period,
	|	TableIncomeAndExpenses.Company AS Company,
	|	TableIncomeAndExpenses.StructuralUnit AS StructuralUnit,
	|	CASE
	|		WHEN TableIncomeAndExpenses.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherExpenses)
	|			THEN VALUE(Catalog.LinesOfBusiness.Other)
	|		ELSE TableIncomeAndExpenses.BusinessLine
	|	END AS BusinessLine,
	|	CASE
	|		WHEN TableIncomeAndExpenses.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherExpenses)
	|				OR TableIncomeAndExpenses.Order = VALUE(Document.SalesOrder.EmptyRef)
	|				OR TableIncomeAndExpenses.Order = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE TableIncomeAndExpenses.Order
	|	END AS SalesOrder,
	|	TableIncomeAndExpenses.GLAccount AS GLAccount,
	|	CAST(&OtherExpenses AS STRING(100)) AS ContentOfAccountingRecord,
	|	0 AS AmountIncome,
	|	SUM(TableIncomeAndExpenses.Amount - TableIncomeAndExpenses.VATAmount + TableIncomeAndExpenses.ReverseChargeVATAmountForNotRegistered) AS AmountExpense,
	|	FALSE AS OfflineRecord
	|FROM
	|	TemporaryTableExpenses AS TableIncomeAndExpenses
	|WHERE
	|	NOT TableIncomeAndExpenses.IncludeExpensesInCostPrice
	|	AND (TableIncomeAndExpenses.TypeOfAccount = VALUE(Enum.GLAccountsTypes.Expenses)
	|			OR TableIncomeAndExpenses.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherExpenses))
	|
	|GROUP BY
	|	TableIncomeAndExpenses.Period,
	|	TableIncomeAndExpenses.Company,
	|	TableIncomeAndExpenses.StructuralUnit,
	|	TableIncomeAndExpenses.BusinessLine,
	|	TableIncomeAndExpenses.TypeOfAccount,
	|	TableIncomeAndExpenses.Order,
	|	TableIncomeAndExpenses.GLAccount
	|
	|UNION ALL
	|
	|SELECT
	|	OfflineRecords.LineNumber,
	|	OfflineRecords.Period,
	|	OfflineRecords.Company,
	|	OfflineRecords.StructuralUnit,
	|	OfflineRecords.BusinessLine,
	|	OfflineRecords.SalesOrder,
	|	OfflineRecords.GLAccount,
	|	OfflineRecords.ContentOfAccountingRecord,
	|	OfflineRecords.AmountIncome,
	|	OfflineRecords.AmountExpense,
	|	OfflineRecords.OfflineRecord
	|FROM
	|	AccumulationRegister.IncomeAndExpenses AS OfflineRecords
	|WHERE
	|	OfflineRecords.Recorder = &Ref
	|	AND OfflineRecords.OfflineRecord
	|
	|ORDER BY
	|	LineNumber";
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();
	
	Query.SetParameter("PositiveExchangeDifferenceGLAccount",			Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeGain"));
	Query.SetParameter("NegativeExchangeDifferenceAccountOfAccounting",	Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeLoss"));
	Query.SetParameter("RegisteredForVAT",								StructureAdditionalProperties.AccountingPolicy.RegisteredForVAT);
	Query.SetParameter("Ref",											DocumentRefPurchaseInvoice);
	
	Query.SetParameter("OtherExpenses",
		NStr("en = 'Expenses incurred'",
			StructureAdditionalProperties.DefaultLanguageCode));
	
	Query.SetParameter("ExchangeDifference",
		NStr("en = 'Foreign currency exchange gains and losses'",
			StructureAdditionalProperties.DefaultLanguageCode));
	
	Query.SetParameter("IncomeReflection",
		NStr("en = 'Income accrued'",
			StructureAdditionalProperties.DefaultLanguageCode));
	
	Query.SetParameter("CostsReflection",
		NStr("en = 'Expenses accrued'",
			StructureAdditionalProperties.DefaultLanguageCode));
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpenses", QueryResult.Unload());
	
EndProcedure

// Payment calendar table formation procedure.
//
// Parameters:
// DocumentRef - DocumentRef.CashInflowForecast - Current
// document AdditionalProperties - AdditionalProperties - Additional properties of the document
//
Procedure GenerateTablePaymentCalendar(DocumentRefPurchaseInvoice, StructureAdditionalProperties)
	
	Query = New Query;
	
	Query.SetParameter("Ref", DocumentRefPurchaseInvoice);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	
	Query.Text =
	"SELECT
	|	SupplierInvoice.Ref AS Ref,
	|	SupplierInvoice.AmountIncludesVAT AS AmountIncludesVAT,
	|	SupplierInvoice.Date AS Date,
	|	SupplierInvoice.CashAssetsType AS CashAssetsType,
	|	SupplierInvoice.Contract AS Contract,
	|	SupplierInvoice.PettyCash AS PettyCash,
	|	SupplierInvoice.DocumentCurrency AS DocumentCurrency,
	|	SupplierInvoice.BankAccount AS BankAccount
	|INTO Document
	|FROM
	|	Document.SupplierInvoice AS SupplierInvoice
	|WHERE
	|	SupplierInvoice.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DocumentTable.PaymentDate AS Period,
	|	Document.CashAssetsType AS CashAssetsType,
	|	Document.Ref AS Quote,
	|	CounterpartyContracts.SettlementsCurrency AS SettlementsCurrency,
	|	CounterpartyContracts.SettlementsInStandardUnits AS SettlementsInStandardUnits,
	|	Document.PettyCash AS PettyCash,
	|	Document.DocumentCurrency AS DocumentCurrency,
	|	Document.BankAccount AS BankAccount,
	|	Document.Ref AS Ref,
	|	CASE
	|		WHEN Document.AmountIncludesVAT
	|			THEN DocumentTable.PaymentAmount
	|		ELSE DocumentTable.PaymentAmount + DocumentTable.PaymentVATAmount
	|	END AS PaymentAmount
	|INTO PaymentCalendar
	|FROM
	|	Document AS Document
	|		INNER JOIN Document.SupplierInvoice.PaymentCalendar AS DocumentTable
	|		ON Document.Ref = DocumentTable.Ref
	|			AND (DocumentTable.PaymentDate > Document.Date)
	|		LEFT JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
	|		ON Document.Contract = CounterpartyContracts.Ref
	|		INNER JOIN Constant.UsePaymentCalendar AS UsePaymentCalendar
	|		ON (UsePaymentCalendar.Value)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	PaymentCalendar.Period AS Period,
	|	&Company AS Company,
	|	PaymentCalendar.CashAssetsType AS CashAssetsType,
	|	VALUE(Enum.PaymentApprovalStatuses.Approved) AS PaymentConfirmationStatus,
	|	PaymentCalendar.Quote AS Quote,
	|	VALUE(Catalog.CashFlowItems.PaymentToVendor) AS Item,
	|	CASE
	|		WHEN PaymentCalendar.CashAssetsType = VALUE(Enum.CashAssetTypes.Cash)
	|			THEN PaymentCalendar.PettyCash
	|		WHEN PaymentCalendar.CashAssetsType = VALUE(Enum.CashAssetTypes.Noncash)
	|			THEN PaymentCalendar.BankAccount
	|		ELSE UNDEFINED
	|	END AS BankAccountPettyCash,
	|	CASE
	|		WHEN PaymentCalendar.SettlementsInStandardUnits
	|			THEN PaymentCalendar.SettlementsCurrency
	|		ELSE PaymentCalendar.DocumentCurrency
	|	END AS Currency,
	|	CASE
	|		WHEN PaymentCalendar.SettlementsInStandardUnits
	|			THEN CAST(-PaymentCalendar.PaymentAmount * CASE
	|						WHEN SettlementsExchangeRates.ExchangeRate <> 0
	|								AND ExchangeRatesOfDocument.Multiplicity <> 0
	|							THEN ExchangeRatesOfDocument.ExchangeRate * SettlementsExchangeRates.Multiplicity / (ISNULL(SettlementsExchangeRates.ExchangeRate, 1) * ISNULL(ExchangeRatesOfDocument.Multiplicity, 1))
	|						ELSE 1
	|					END AS NUMBER(15, 2))
	|		ELSE -PaymentCalendar.PaymentAmount
	|	END AS Amount
	|FROM
	|	PaymentCalendar AS PaymentCalendar
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&PointInTime, ) AS ExchangeRatesOfDocument
	|		ON PaymentCalendar.DocumentCurrency = ExchangeRatesOfDocument.Currency
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&PointInTime, ) AS SettlementsExchangeRates
	|		ON PaymentCalendar.SettlementsCurrency = SettlementsExchangeRates.Currency";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TablePaymentCalendar", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTablePurchases(DocumentRefPurchaseInvoice, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	TablePurchases.Period AS Period,
	|	TablePurchases.Company AS Company,
	|	TablePurchases.Products AS Products,
	|	TablePurchases.Characteristic AS Characteristic,
	|	TablePurchases.Batch AS Batch,
	|	TablePurchases.Order AS PurchaseOrder,
	|	TablePurchases.Document AS Document,
	|	TablePurchases.VATRate AS VATRate,
	|	SUM(TablePurchases.Quantity) AS Quantity,
	|	SUM(TablePurchases.AmountVATPurchaseSale) AS VATAmount,
	|	SUM(TablePurchases.Amount - TablePurchases.AmountVATPurchaseSale) AS Amount
	|FROM
	|	TemporaryTableInventory AS TablePurchases
	|
	|GROUP BY
	|	TablePurchases.Period,
	|	TablePurchases.Company,
	|	TablePurchases.Products,
	|	TablePurchases.Characteristic,
	|	TablePurchases.Batch,
	|	TablePurchases.Order,
	|	TablePurchases.Document,
	|	TablePurchases.VATRate
	|
	|UNION ALL
	|
	|SELECT
	|	TablePurchases.Period,
	|	TablePurchases.Company,
	|	TablePurchases.Products,
	|	TablePurchases.Characteristic,
	|	TablePurchases.Batch,
	|	TablePurchases.PurchaseOrder,
	|	TablePurchases.Document,
	|	TablePurchases.VATRate,
	|	SUM(TablePurchases.Quantity),
	|	SUM(TablePurchases.AmountVATPurchaseSale),
	|	SUM(TablePurchases.Amount - TablePurchases.AmountVATPurchaseSale)
	|FROM
	|	TemporaryTableExpenses AS TablePurchases
	|
	|GROUP BY
	|	TablePurchases.Period,
	|	TablePurchases.Company,
	|	TablePurchases.Products,
	|	TablePurchases.Characteristic,
	|	TablePurchases.Batch,
	|	TablePurchases.PurchaseOrder,
	|	TablePurchases.Document,
	|	TablePurchases.VATRate";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TablePurchases", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventoryInWarehouses(DocumentRefPurchaseInvoice, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	MIN(TableInventoryInWarehouses.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TableInventoryInWarehouses.Period AS Period,
	|	TableInventoryInWarehouses.Company AS Company,
	|	TableInventoryInWarehouses.Products AS Products,
	|	TableInventoryInWarehouses.Characteristic AS Characteristic,
	|	TableInventoryInWarehouses.Batch AS Batch,
	|	TableInventoryInWarehouses.StructuralUnit AS StructuralUnit,
	|	TableInventoryInWarehouses.Cell AS Cell,
	|	SUM(TableInventoryInWarehouses.Quantity) AS Quantity
	|FROM
	|	TemporaryTableInventory AS TableInventoryInWarehouses
	|WHERE
	|	NOT TableInventoryInWarehouses.RetailTransferEarningAccounting
	|	AND TableInventoryInWarehouses.GoodsReceipt = VALUE(Document.GoodsReceipt.EmptyRef)
	|
	|GROUP BY
	|	TableInventoryInWarehouses.Period,
	|	TableInventoryInWarehouses.Company,
	|	TableInventoryInWarehouses.Products,
	|	TableInventoryInWarehouses.Characteristic,
	|	TableInventoryInWarehouses.Batch,
	|	TableInventoryInWarehouses.StructuralUnit,
	|	TableInventoryInWarehouses.Cell";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryInWarehouses", QueryResult.Unload());
	
EndProcedure

Procedure GenerateTableGoodsAwaitingCustomsClearance(DocumentRefPurchaseInvoice, StructureAdditionalProperties)
	
	If Not StructureAdditionalProperties.DocumentAttributes.VATTaxation = Enums.VATTaxationTypes.ForExport Then
		
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableGoodsAwaitingCustomsClearance", New ValueTable);
		Return;
		
	EndIf;
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	MIN(TemporaryTableInventory.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TemporaryTableInventory.Period AS Period,
	|	TemporaryTableInventory.Company AS Company,
	|	TemporaryTableInventory.Counterparty AS Counterparty,
	|	TemporaryTableInventory.Contract AS Contract,
	|	TemporaryTableInventory.Document AS SupplierInvoice,
	|	TemporaryTableInventory.Products AS Products,
	|	TemporaryTableInventory.Characteristic AS Characteristic,
	|	TemporaryTableInventory.Batch AS Batch,
	|	SUM(TemporaryTableInventory.Quantity) AS Quantity
	|FROM
	|	TemporaryTableInventory AS TemporaryTableInventory
	|WHERE
	|	NOT TemporaryTableInventory.RetailTransferEarningAccounting
	|
	|GROUP BY
	|	TemporaryTableInventory.Contract,
	|	TemporaryTableInventory.Characteristic,
	|	TemporaryTableInventory.Company,
	|	TemporaryTableInventory.Batch,
	|	TemporaryTableInventory.Period,
	|	TemporaryTableInventory.Document,
	|	TemporaryTableInventory.Counterparty,
	|	TemporaryTableInventory.Products";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableGoodsAwaitingCustomsClearance", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventoryCostLayer(DocumentRefPurchaseInvoice, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	Inventory.Period AS Period,
	|	Inventory.Company AS Company,
	|	Inventory.Products AS Products,
	|	UNDEFINED AS SalesOrder,
	|	Inventory.Characteristic AS Characteristic,
	|	&Ref AS CostLayer,
	|	Inventory.Batch AS Batch,
	|	Inventory.StructuralUnit AS StructuralUnit,
	|	Inventory.GLAccount AS GLAccount,
	|	SUM(Inventory.Quantity) AS Quantity,
	|	SUM(Inventory.Amount + Inventory.AmountExpense - Inventory.AmountVATPurchaseSale) AS Amount,
	|	TRUE AS SourceRecord
	|FROM
	|	TemporaryTableInventory AS Inventory,
	|	Constant.UseInventoryReservation AS UseInventoryReservation
	|WHERE
	|	NOT Inventory.RetailTransferEarningAccounting
	|	AND &UseFIFO
	|
	|GROUP BY
	|	Inventory.Period,
	|	Inventory.Company,
	|	Inventory.Products,
	|	Inventory.Characteristic,
	|	Inventory.Batch,
	|	Inventory.StructuralUnit,
	|	Inventory.GLAccount";
	
	Query.SetParameter("Ref", DocumentRefPurchaseInvoice);
	Query.SetParameter("UseFIFO", StructureAdditionalProperties.AccountingPolicy.UseFIFO);
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryCostLayer", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTablePurchaseOrders(DocumentRefPurchaseInvoice, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	MIN(TablePurchaseOrders.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TablePurchaseOrders.Period AS Period,
	|	TablePurchaseOrders.Company AS Company,
	|	TablePurchaseOrders.Products AS Products,
	|	TablePurchaseOrders.Characteristic AS Characteristic,
	|	TablePurchaseOrders.Order AS PurchaseOrder,
	|	SUM(TablePurchaseOrders.Quantity) AS Quantity
	|FROM
	|	TemporaryTableInventory AS TablePurchaseOrders
	|WHERE
	|	TablePurchaseOrders.Order <> UNDEFINED
	|	AND TablePurchaseOrders.GoodsReceipt = VALUE(Document.GoodsReceipt.EmptyRef)
	|
	|GROUP BY
	|	TablePurchaseOrders.Period,
	|	TablePurchaseOrders.Company,
	|	TablePurchaseOrders.Products,
	|	TablePurchaseOrders.Characteristic,
	|	TablePurchaseOrders.Order
	|
	|UNION ALL
	|
	|SELECT
	|	MIN(TablePurchaseOrders.LineNumber),
	|	VALUE(AccumulationRecordType.Expense),
	|	TablePurchaseOrders.Period,
	|	TablePurchaseOrders.Company,
	|	TablePurchaseOrders.Products,
	|	TablePurchaseOrders.Characteristic,
	|	TablePurchaseOrders.PurchaseOrder,
	|	SUM(TablePurchaseOrders.Quantity)
	|FROM
	|	TemporaryTableExpenses AS TablePurchaseOrders
	|WHERE
	|	TablePurchaseOrders.PurchaseOrder <> VALUE(Document.PurchaseOrder.EmptyRef)
	|
	|GROUP BY
	|	TablePurchaseOrders.Period,
	|	TablePurchaseOrders.Company,
	|	TablePurchaseOrders.Products,
	|	TablePurchaseOrders.Characteristic,
	|	TablePurchaseOrders.PurchaseOrder";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TablePurchaseOrders", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableBackorders(DocumentRefPurchaseInvoice, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	// Inventory and expenses placement.
	Query.Text =
	"SELECT
	|	TablePlacement.Period AS Period,
	|	TablePlacement.Company AS Company,
	|	TablePlacement.Products AS Products,
	|	TablePlacement.Characteristic AS Characteristic,
	|	TablePlacement.Order AS Order,
	|	SUM(TablePlacement.Quantity) AS Quantity
	|INTO TemporaryTablePlacement
	|FROM
	|	(SELECT
	|		TablePlacementInventory.Period AS Period,
	|		TablePlacementInventory.Company AS Company,
	|		TablePlacementInventory.Products AS Products,
	|		TablePlacementInventory.Characteristic AS Characteristic,
	|		TablePlacementInventory.Order AS Order,
	|		TablePlacementInventory.Quantity AS Quantity
	|	FROM
	|		TemporaryTableInventory AS TablePlacementInventory
	|	WHERE
	|		NOT TablePlacementInventory.Order IN (VALUE(Document.SalesOrder.EmptyRef), VALUE(Document.PurchaseOrder.EmptyRef), VALUE(Document.ProductionOrder.EmptyRef), UNDEFINED)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		TablePlacementExpenses.Period,
	|		TablePlacementExpenses.Company,
	|		TablePlacementExpenses.Products,
	|		TablePlacementExpenses.Characteristic,
	|		TablePlacementExpenses.PurchaseOrder,
	|		TablePlacementExpenses.Quantity
	|	FROM
	|		TemporaryTableExpenses AS TablePlacementExpenses
	|	WHERE
	|		NOT TablePlacementExpenses.PurchaseOrder IN (VALUE(Document.PurchaseOrder.EmptyRef), UNDEFINED)) AS TablePlacement
	|
	|GROUP BY
	|	TablePlacement.Period,
	|	TablePlacement.Company,
	|	TablePlacement.Products,
	|	TablePlacement.Characteristic,
	|	TablePlacement.Order";
	
	Query.Execute();
	
	// Set exclusive lock of the controlled orders placement.
	Query.Text = 
	"SELECT
	|	TableBackorders.Company AS Company,
	|	TableBackorders.Products AS Products,
	|	TableBackorders.Characteristic AS Characteristic,
	|	TableBackorders.Order AS SupplySource
	|FROM
	|	TemporaryTablePlacement AS TableBackorders";
	
	QueryResult = Query.Execute();
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.Backorders");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;
	
	For Each ColumnQueryResult In QueryResult.Columns Do
		LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
	EndDo;
	Block.Lock();
	
	// Receive balance.
	Query.Text =
	"SELECT
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableBackorders.Period AS Period,
	|	TableBackorders.Company AS Company,
	|	BackordersBalances.SalesOrder AS SalesOrder,
	|	TableBackorders.Products AS Products,
	|	TableBackorders.Characteristic AS Characteristic,
	|	TableBackorders.Order AS SupplySource,
	|	CASE
	|		WHEN TableBackorders.Quantity > ISNULL(BackordersBalances.Quantity, 0)
	|			THEN ISNULL(BackordersBalances.Quantity, 0)
	|		WHEN TableBackorders.Quantity <= ISNULL(BackordersBalances.Quantity, 0)
	|			THEN TableBackorders.Quantity
	|	END AS Quantity
	|FROM
	|	TemporaryTablePlacement AS TableBackorders
	|		LEFT JOIN (SELECT
	|			BackordersBalances.Company AS Company,
	|			BackordersBalances.Products AS Products,
	|			BackordersBalances.Characteristic AS Characteristic,
	|			BackordersBalances.SalesOrder AS SalesOrder,
	|			BackordersBalances.SupplySource AS SupplySource,
	|			SUM(BackordersBalances.QuantityBalance) AS Quantity
	|		FROM
	|			(SELECT
	|				BackordersBalances.Company AS Company,
	|				BackordersBalances.Products AS Products,
	|				BackordersBalances.Characteristic AS Characteristic,
	|				BackordersBalances.SalesOrder AS SalesOrder,
	|				BackordersBalances.SupplySource AS SupplySource,
	|				BackordersBalances.QuantityBalance AS QuantityBalance
	|			FROM
	|				AccumulationRegister.Backorders.Balance(
	|						&ControlTime,
	|						(Company, Products, Characteristic, SupplySource) In
	|							(SELECT
	|								TableBackorders.Company AS Company,
	|								TableBackorders.Products AS Products,
	|								TableBackorders.Characteristic AS Characteristic,
	|								TableBackorders.Order AS SupplySource
	|							FROM
	|								TemporaryTablePlacement AS TableBackorders)) AS BackordersBalances
			
	|			UNION ALL
			
	|			SELECT
	|				DocumentRegisterRecordsBackorders.Company,
	|				DocumentRegisterRecordsBackorders.Products,
	|				DocumentRegisterRecordsBackorders.Characteristic,
	|				DocumentRegisterRecordsBackorders.SalesOrder,
	|				DocumentRegisterRecordsBackorders.SupplySource,
	|				CASE
	|					WHEN DocumentRegisterRecordsBackorders.RecordType = VALUE(AccumulationRecordType.Expense)
	|						THEN ISNULL(DocumentRegisterRecordsBackorders.Quantity, 0)
	|					ELSE -ISNULL(DocumentRegisterRecordsBackorders.Quantity, 0)
	|				END
	|			FROM
	|				AccumulationRegister.Backorders AS DocumentRegisterRecordsBackorders
	|			WHERE
	|				DocumentRegisterRecordsBackorders.Recorder = &Ref
	|				AND DocumentRegisterRecordsBackorders.Period <= &ControlPeriod) AS BackordersBalances
		
	|		GROUP BY
	|			BackordersBalances.Company,
	|			BackordersBalances.Products,
	|			BackordersBalances.Characteristic,
	|			BackordersBalances.SalesOrder,
	|			BackordersBalances.SupplySource) AS BackordersBalances
	|		ON TableBackorders.Company = BackordersBalances.Company
	|			AND TableBackorders.Products = BackordersBalances.Products
	|			AND TableBackorders.Characteristic = BackordersBalances.Characteristic
	|			AND TableBackorders.Order = BackordersBalances.SupplySource
	|WHERE
	|	BackordersBalances.SalesOrder IS Not NULL ";
	
	Query.SetParameter("Ref", DocumentRefPurchaseInvoice);
	Query.SetParameter("ControlTime", StructureAdditionalProperties.ForPosting.ControlTime);
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.ControlPeriod);
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableBackorders", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableAccountsPayable(DocumentRefPurchaseInvoice, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefPurchaseInvoice);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("ExpectedPayments", NStr("en = 'Expected payment'", StructureAdditionalProperties.DefaultLanguageCode));
	
	Query.SetParameter("AppearenceOfLiabilityToVendor",
		NStr("en = 'Accounts payable recognition'",
			StructureAdditionalProperties.DefaultLanguageCode));
	
	Query.SetParameter("AdvanceCredit",
		NStr("en = 'Advance payment clearing'",
			StructureAdditionalProperties.DefaultLanguageCode));
	
	Query.SetParameter("ExchangeDifference",
		NStr("en = 'Foreign currency exchange gains and losses'",
			StructureAdditionalProperties.DefaultLanguageCode));
	
	Query.Text =
	"SELECT
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	DocumentTable.Period AS Date,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.Counterparty AS Counterparty,
	|	DocumentTable.DoOperationsByDocuments AS DoOperationsByDocuments,
	|	DocumentTable.GLAccountVendorSettlements AS GLAccount,
	|	DocumentTable.Contract AS Contract,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByDocuments
	|			THEN DocumentTable.Document
	|		ELSE UNDEFINED
	|	END AS Document,
	|	CASE
	|		WHEN DocumentTable.Order REFS Document.PurchaseOrder
	|				AND DocumentTable.Order <> VALUE(Document.PurchaseOrder.EmptyRef)
	|				AND DocumentTable.DoOperationsByOrders
	|			THEN DocumentTable.Order
	|		ELSE VALUE(Document.PurchaseOrder.EmptyRef)
	|	END AS Order,
	|	DocumentTable.SettlementsCurrency AS Currency,
	|	VALUE(Enum.SettlementsTypes.Debt) AS SettlementsType,
	|	SUM(DocumentTable.Amount) AS Amount,
	|	SUM(DocumentTable.AmountCur) AS AmountCur,
	|	SUM(DocumentTable.Amount) AS AmountForBalance,
	|	SUM(DocumentTable.AmountCur) AS AmountCurForBalance,
	|	CAST(&AppearenceOfLiabilityToVendor AS STRING(100)) AS ContentOfAccountingRecord,
	|	SUM(CASE
	|			WHEN DocumentTable.SetPaymentTerms
	|				THEN 0
	|			ELSE DocumentTable.Amount
	|		END) AS AmountForPayment,
	|	SUM(CASE
	|			WHEN DocumentTable.SetPaymentTerms
	|				THEN 0
	|			ELSE DocumentTable.AmountCur
	|		END) AS AmountForPaymentCur
	|INTO TemporaryTableAccountsPayable
	|FROM
	|	TemporaryTableInventory AS DocumentTable
	|
	|GROUP BY
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	DocumentTable.Counterparty,
	|	DocumentTable.DoOperationsByDocuments,
	|	DocumentTable.Contract,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByDocuments
	|			THEN DocumentTable.Document
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.Order REFS Document.PurchaseOrder
	|				AND DocumentTable.Order <> VALUE(Document.PurchaseOrder.EmptyRef)
	|				AND DocumentTable.DoOperationsByOrders
	|			THEN DocumentTable.Order
	|		ELSE VALUE(Document.PurchaseOrder.EmptyRef)
	|	END,
	|	DocumentTable.SettlementsCurrency,
	|	DocumentTable.GLAccountVendorSettlements
	|
	|UNION ALL
	|
	|SELECT
	|	VALUE(AccumulationRecordType.Receipt),
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	DocumentTable.Counterparty,
	|	DocumentTable.DoOperationsByDocuments,
	|	DocumentTable.GLAccountVendorSettlements,
	|	DocumentTable.Contract,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByDocuments
	|			THEN DocumentTable.Document
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByOrders
	|			THEN DocumentTable.PurchaseOrder
	|		ELSE VALUE(Document.PurchaseOrder.EmptyRef)
	|	END,
	|	DocumentTable.SettlementsCurrency,
	|	VALUE(Enum.SettlementsTypes.Debt),
	|	SUM(DocumentTable.Amount),
	|	SUM(DocumentTable.AmountCur),
	|	SUM(DocumentTable.Amount),
	|	SUM(DocumentTable.AmountCur),
	|	CAST(&AppearenceOfLiabilityToVendor AS STRING(100)),
	|	CASE
	|		WHEN DocumentTable.SetPaymentTerms
	|			THEN 0
	|		ELSE DocumentTable.Amount
	|	END,
	|	CASE
	|		WHEN DocumentTable.SetPaymentTerms
	|			THEN 0
	|		ELSE DocumentTable.AmountCur
	|	END
	|FROM
	|	TemporaryTableExpenses AS DocumentTable
	|
	|GROUP BY
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	DocumentTable.Counterparty,
	|	DocumentTable.DoOperationsByDocuments,
	|	DocumentTable.Contract,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByDocuments
	|			THEN DocumentTable.Document
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByOrders
	|			THEN DocumentTable.PurchaseOrder
	|		ELSE VALUE(Document.PurchaseOrder.EmptyRef)
	|	END,
	|	DocumentTable.SettlementsCurrency,
	|	DocumentTable.GLAccountVendorSettlements,
	|	CASE
	|		WHEN DocumentTable.SetPaymentTerms
	|			THEN 0
	|		ELSE DocumentTable.Amount
	|	END,
	|	CASE
	|		WHEN DocumentTable.SetPaymentTerms
	|			THEN 0
	|		ELSE DocumentTable.AmountCur
	|	END
	|
	|UNION ALL
	|
	|SELECT
	|	VALUE(AccumulationRecordType.Receipt),
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	DocumentTable.Counterparty,
	|	DocumentTable.DoOperationsByDocuments,
	|	DocumentTable.VendorAdvancesGLAccount,
	|	DocumentTable.Contract,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByDocuments
	|			THEN DocumentTable.Document
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.Order REFS Document.PurchaseOrder
	|				AND DocumentTable.Order <> VALUE(Document.PurchaseOrder.EmptyRef)
	|				AND DocumentTable.DoOperationsByOrders
	|			THEN DocumentTable.Order
	|		ELSE VALUE(Document.PurchaseOrder.EmptyRef)
	|	END,
	|	DocumentTable.SettlementsCurrency,
	|	DocumentTable.SettlementsType,
	|	SUM(DocumentTable.Amount),
	|	SUM(DocumentTable.AmountCur),
	|	SUM(DocumentTable.Amount),
	|	SUM(DocumentTable.AmountCur),
	|	CAST(&AdvanceCredit AS STRING(100)),
	|	SUM(CASE
	|			WHEN DocumentTable.SetPaymentTerms
	|				THEN 0
	|			ELSE DocumentTable.Amount
	|		END),
	|	SUM(CASE
	|			WHEN DocumentTable.SetPaymentTerms
	|				THEN 0
	|			ELSE DocumentTable.AmountCur
	|		END)
	|FROM
	|	TemporaryTablePrepayment AS DocumentTable
	|
	|GROUP BY
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	DocumentTable.Counterparty,
	|	DocumentTable.DoOperationsByDocuments,
	|	DocumentTable.Contract,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByDocuments
	|			THEN DocumentTable.Document
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.Order REFS Document.PurchaseOrder
	|				AND DocumentTable.Order <> VALUE(Document.PurchaseOrder.EmptyRef)
	|				AND DocumentTable.DoOperationsByOrders
	|			THEN DocumentTable.Order
	|		ELSE VALUE(Document.PurchaseOrder.EmptyRef)
	|	END,
	|	DocumentTable.SettlementsType,
	|	DocumentTable.SettlementsCurrency,
	|	DocumentTable.VendorAdvancesGLAccount
	|
	|UNION ALL
	|
	|SELECT
	|	VALUE(AccumulationRecordType.Expense),
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	DocumentTable.Counterparty,
	|	DocumentTable.DoOperationsByDocuments,
	|	DocumentTable.GLAccountVendorSettlements,
	|	DocumentTable.Contract,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByDocuments
	|			THEN DocumentTable.DocumentWhere
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.Order REFS Document.PurchaseOrder
	|				AND DocumentTable.Order <> VALUE(Document.PurchaseOrder.EmptyRef)
	|				AND DocumentTable.DoOperationsByOrders
	|			THEN DocumentTable.Order
	|		ELSE VALUE(Document.PurchaseOrder.EmptyRef)
	|	END,
	|	DocumentTable.SettlementsCurrency,
	|	DocumentTable.SettlemensTypeWhere,
	|	SUM(DocumentTable.Amount),
	|	SUM(DocumentTable.AmountCur),
	|	-SUM(DocumentTable.Amount),
	|	-SUM(DocumentTable.AmountCur),
	|	CAST(&AdvanceCredit AS STRING(100)),
	|	SUM(CASE
	|			WHEN DocumentTable.SetPaymentTerms
	|				THEN 0
	|			ELSE DocumentTable.Amount
	|		END),
	|	SUM(CASE
	|			WHEN DocumentTable.SetPaymentTerms
	|				THEN 0
	|			ELSE DocumentTable.AmountCur
	|		END)
	|FROM
	|	TemporaryTablePrepayment AS DocumentTable
	|
	|GROUP BY
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	DocumentTable.Counterparty,
	|	DocumentTable.DoOperationsByDocuments,
	|	DocumentTable.Contract,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByDocuments
	|			THEN DocumentTable.DocumentWhere
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.Order REFS Document.PurchaseOrder
	|				AND DocumentTable.Order <> VALUE(Document.PurchaseOrder.EmptyRef)
	|				AND DocumentTable.DoOperationsByOrders
	|			THEN DocumentTable.Order
	|		ELSE VALUE(Document.PurchaseOrder.EmptyRef)
	|	END,
	|	DocumentTable.GLAccountVendorSettlements,
	|	DocumentTable.SettlementsCurrency,
	|	DocumentTable.SettlemensTypeWhere
	|
	|UNION ALL
	|
	|SELECT
	|	VALUE(AccumulationRecordType.Receipt),
	|	Calendar.Period,
	|	Calendar.Company,
	|	Calendar.Counterparty,
	|	Calendar.DoOperationsByDocuments,
	|	Calendar.GLAccountCustomerSettlements,
	|	Calendar.Contract,
	|	CASE
	|		WHEN Calendar.DoOperationsByDocuments
	|			THEN Calendar.DocumentWhere
	|		ELSE UNDEFINED
	|	END,
	|	Calendar.Order,
	|	Calendar.SettlementsCurrency,
	|	Calendar.SettlemensTypeWhere,
	|	0,
	|	0,
	|	0,
	|	0,
	|	CAST(&ExpectedPayments AS STRING(100)),
	|	Calendar.Amount,
	|	Calendar.AmountCur
	|FROM
	|	TemporaryTablePaymentCalendar AS Calendar
	|
	|INDEX BY
	|	Company,
	|	Counterparty,
	|	Contract,
	|	Currency,
	|	Document,
	|	Order,
	|	SettlementsType,
	|	GLAccount";
	
	Query.Execute();
	
	// Setting the exclusive lock for the controlled balances of accounts payable.
	Query.Text =
	"SELECT
	|	TemporaryTableAccountsPayable.Company AS Company,
	|	TemporaryTableAccountsPayable.Counterparty AS Counterparty,
	|	TemporaryTableAccountsPayable.Contract AS Contract,
	|	TemporaryTableAccountsPayable.Document AS Document,
	|	TemporaryTableAccountsPayable.Order AS Order,
	|	TemporaryTableAccountsPayable.SettlementsType AS SettlementsType
	|FROM
	|	TemporaryTableAccountsPayable AS TemporaryTableAccountsPayable";
	
	QueryResult = Query.Execute();
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.AccountsPayable");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;
	
	For Each ColumnQueryResult In QueryResult.Columns Do
		LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
	EndDo;
	Block.Lock();
	
	QueryNumber = 0;
	Query.Text = DriveServer.GetQueryTextExchangeRatesDifferencesAccountsPayable(Query.TempTablesManager, True, QueryNumber);
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountsPayable", ResultsArray[QueryNumber].Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableIncomeAndExpensesRetained(DocumentRefPurchaseInvoice, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefPurchaseInvoice);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("IncomeAndExpensesAccountingCashMethod", StructureAdditionalProperties.AccountingPolicy.IncomeAndExpensesAccountingCashMethod);
	
	Query.Text =
	"SELECT
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Period AS Period,
	|	DocumentTable.Company AS Company,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByDocuments
	|			THEN &Ref
	|		ELSE UNDEFINED
	|	END AS Document,
	|	DocumentTable.BusinessLineSales AS BusinessLine,
	|	DocumentTable.Amount - DocumentTable.VATAmount AS AmountExpense
	|FROM
	|	TemporaryTableInventory AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|
	|UNION ALL
	|
	|SELECT
	|	VALUE(AccumulationRecordType.Receipt),
	|	DocumentTable.LineNumber,
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByDocuments
	|			THEN &Ref
	|		ELSE UNDEFINED
	|	END,
	|	DocumentTable.BusinessLine,
	|	DocumentTable.Amount - DocumentTable.VATAmount
	|FROM
	|	TemporaryTableExpenses AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|
	|ORDER BY
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DocumentTable.Company AS Company,
	|	SUM(DocumentTable.Amount) AS AmountToBeWrittenOff
	|FROM
	|	TemporaryTablePrepayment AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|
	|GROUP BY
	|	DocumentTable.Company
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Item AS Item
	|FROM
	|	TemporaryTablePrepayment AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|
	|ORDER BY
	|	LineNumber";

	ResultsArray = Query.ExecuteBatch();
	
	TableInventoryIncomeAndExpensesRetained = ResultsArray[0].Unload();
	SelectionOfQueryResult = ResultsArray[1].Select();
	
	TablePrepaymentIncomeAndExpensesRetained = TableInventoryIncomeAndExpensesRetained.Copy();
	TablePrepaymentIncomeAndExpensesRetained.Clear();
	
	If SelectionOfQueryResult.Next() Then
		AmountToBeWrittenOff = SelectionOfQueryResult.AmountToBeWrittenOff;
		For Each StringInventoryIncomeAndExpensesRetained In TableInventoryIncomeAndExpensesRetained Do
			If AmountToBeWrittenOff = 0 Then
				Continue
			ElsIf StringInventoryIncomeAndExpensesRetained.AmountExpense <= AmountToBeWrittenOff Then
				StringPrepaymentIncomeAndExpensesRetained = TablePrepaymentIncomeAndExpensesRetained.Add();
				FillPropertyValues(StringPrepaymentIncomeAndExpensesRetained, StringInventoryIncomeAndExpensesRetained);
				AmountToBeWrittenOff = AmountToBeWrittenOff - StringInventoryIncomeAndExpensesRetained.AmountExpense;
			ElsIf StringInventoryIncomeAndExpensesRetained.AmountExpense > AmountToBeWrittenOff Then
				StringPrepaymentIncomeAndExpensesRetained = TablePrepaymentIncomeAndExpensesRetained.Add();
				FillPropertyValues(StringPrepaymentIncomeAndExpensesRetained, StringInventoryIncomeAndExpensesRetained);
				StringPrepaymentIncomeAndExpensesRetained.AmountExpense = AmountToBeWrittenOff;
				AmountToBeWrittenOff = 0;
			EndIf;
		EndDo;
	EndIf;
	
	For Each StringPrepaymentIncomeAndExpensesRetained In TablePrepaymentIncomeAndExpensesRetained Do
		StringInventoryIncomeAndExpensesRetained = TableInventoryIncomeAndExpensesRetained.Add();
		FillPropertyValues(StringInventoryIncomeAndExpensesRetained, StringPrepaymentIncomeAndExpensesRetained);
		StringInventoryIncomeAndExpensesRetained.RecordType = AccumulationRecordType.Expense;
	EndDo;
	
	SelectionOfQueryResult = ResultsArray[2].Select();
	
	If SelectionOfQueryResult.Next() Then
		Item = SelectionOfQueryResult.Item;
	Else
		Item = Catalogs.CashFlowItems.PaymentToVendor;
	EndIf;

	Query.Text =
	"SELECT
	|	Table.LineNumber AS LineNumber,
	|	Table.Period AS Period,
	|	Table.Company AS Company,
	|	Table.Document AS Document,
	|	&Item AS Item,
	|	Table.BusinessLine AS BusinessLine,
	|	Table.AmountExpense AS AmountExpense
	|INTO TemporaryTablePrepaidIncomeAndExpensesRetained
	|FROM
	|	&Table AS Table";
	Query.SetParameter("Table", TablePrepaymentIncomeAndExpensesRetained);
	Query.SetParameter("Item", Item);
	
	Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpensesRetained", TableInventoryIncomeAndExpensesRetained);
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableUnallocatedExpenses(DocumentRefPurchaseInvoice, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("IncomeAndExpensesAccountingCashMethod", StructureAdditionalProperties.AccountingPolicy.IncomeAndExpensesAccountingCashMethod);
	
	Query.Text =
	"SELECT
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	DocumentTable.Period AS Period,
	|	DocumentTable.Company AS Company,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByDocuments
	|			THEN DocumentTable.Document
	|		ELSE UNDEFINED
	|	END AS Document,
	|	DocumentTable.Item AS Item,
	|	DocumentTable.Amount AS AmountExpense
	|FROM
	|	TemporaryTablePrepayment AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableUnallocatedExpenses", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableIncomeAndExpensesCashMethod(DocumentRefPurchaseInvoice, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefPurchaseInvoice);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("IncomeAndExpensesAccountingCashMethod", StructureAdditionalProperties.AccountingPolicy.IncomeAndExpensesAccountingCashMethod);
	
	Query.Text =
	"SELECT
	|	DocumentTable.DocumentDate AS Period,
	|	DocumentTable.Company AS Company,
	|	UNDEFINED AS BusinessLine,
	|	DocumentTable.Item AS Item,
	|	-DocumentTable.Amount AS AmountExpense
	|FROM
	|	TemporaryTablePrepayment AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|
	|UNION ALL
	|
	|SELECT
	|	Table.Period,
	|	Table.Company,
	|	Table.BusinessLine,
	|	Table.Item,
	|	Table.AmountExpense
	|FROM
	|	TemporaryTablePrepaidIncomeAndExpensesRetained AS Table";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpensesCashMethod", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTablePOSSummary(DocumentRefPurchaseInvoice, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.SetParameter("Ref", DocumentRefPurchaseInvoice);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	
	Query.SetParameter("RetailIncome",
		NStr("en = 'Receipt to retail'",
			StructureAdditionalProperties.DefaultLanguageCode));
	
	Query.SetParameter("ExchangeDifference",
		NStr("en = 'Foreign currency exchange gains and losses'",
			StructureAdditionalProperties.DefaultLanguageCode));
	
	Query.Text =
	"SELECT
	|	DocumentTable.Period AS Date,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.RetailPriceKind AS RetailPriceKind,
	|	DocumentTable.Products AS Products,
	|	DocumentTable.Characteristic AS Characteristic,
	|	DocumentTable.StructuralUnit AS StructuralUnit,
	|	DocumentTable.PriceCurrency AS Currency,
	|	DocumentTable.GLAccount AS GLAccount,
	|	DocumentTable.MarkupGLAccount AS MarkupGLAccount,
	|	SUM(CAST(PricesSliceLast.Price * DocumentTable.Quantity * CurrencyPriceExchangeRate.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * CurrencyPriceExchangeRate.Multiplicity) / ISNULL(PricesSliceLast.MeasurementUnit.Factor, 1) AS NUMBER(15, 2))) AS Amount,
	|	SUM(CAST(PricesSliceLast.Price * DocumentTable.Quantity / ISNULL(PricesSliceLast.MeasurementUnit.Factor, 1) AS NUMBER(15, 2))) AS AmountCur,
	|	SUM(CAST(PricesSliceLast.Price * DocumentTable.Quantity * CurrencyPriceExchangeRate.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * CurrencyPriceExchangeRate.Multiplicity) / ISNULL(PricesSliceLast.MeasurementUnit.Factor, 1) AS NUMBER(15, 2))) AS AmountForBalance,
	|	SUM(CAST(PricesSliceLast.Price * DocumentTable.Quantity / ISNULL(PricesSliceLast.MeasurementUnit.Factor, 1) AS NUMBER(15, 2))) AS AmountCurForBalance,
	|	SUM(DocumentTable.Amount + DocumentTable.AmountExpense) AS Cost,
	|	&RetailIncome AS ContentOfAccountingRecord
	|INTO TemporaryTablePOSSummary
	|FROM
	|	TemporaryTableInventory AS DocumentTable
	|		LEFT JOIN InformationRegister.Prices.SliceLast(
	|				&PointInTime,
	|				(PriceKind, Products, Characteristic) In
	|					(SELECT
	|						TemporaryTableInventory.RetailPriceKind,
	|						TemporaryTableInventory.Products,
	|						TemporaryTableInventory.Characteristic
	|					FROM
	|						TemporaryTableInventory)) AS PricesSliceLast
	|		ON DocumentTable.Products = PricesSliceLast.Products
	|			AND DocumentTable.RetailPriceKind = PricesSliceLast.PriceKind
	|			AND DocumentTable.Characteristic = PricesSliceLast.Characteristic
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(
	|				&PointInTime,
	|				Currency In
	|					(SELECT
	|						ConstantAccountingCurrency.Value
	|					FROM
	|						Constant.PresentationCurrency AS ConstantAccountingCurrency)) AS ManagExchangeRates
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&PointInTime, ) AS CurrencyPriceExchangeRate
	|		ON DocumentTable.PriceCurrency = CurrencyPriceExchangeRate.Currency
	|WHERE
	|	DocumentTable.RetailTransferEarningAccounting
	|
	|GROUP BY
	|	DocumentTable.Period,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Company,
	|	DocumentTable.RetailPriceKind,
	|	DocumentTable.Products,
	|	DocumentTable.Characteristic,
	|	DocumentTable.StructuralUnit,
	|	DocumentTable.PriceCurrency,
	|	DocumentTable.GLAccount,
	|	DocumentTable.MarkupGLAccount
	|
	|INDEX BY
	|	Company,
	|	StructuralUnit,
	|	Currency,
	|	GLAccount";
	
	Query.Execute();
	
	// Setting of the exclusive lock of the cash funds controlled balances.
	Query.Text =
	"SELECT
	|	TemporaryTablePOSSummary.Company AS Company,
	|	TemporaryTablePOSSummary.StructuralUnit AS StructuralUnit,
	|	TemporaryTablePOSSummary.Currency AS Currency
	|FROM
	|	TemporaryTablePOSSummary AS TemporaryTablePOSSummary";
	
	QueryResult = Query.Execute();
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.POSSummary");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;
	
	For Each ColumnQueryResult In QueryResult.Columns Do
		LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
	EndDo;
	Block.Lock();
	
	QueryNumber = 0;
	Query.Text = DriveServer.GetQueryTextExchangeRateDifferencesPOSSummary(Query.TempTablesManager, QueryNumber);
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TablePOSSummary", ResultsArray[QueryNumber].Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableAccountingJournalEntries(DocumentRefPurchaseInvoice, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	ISNULL(SUM(TemporaryTable.ReverseChargeVATAmount), 0) AS ReverseChargeVATInventory
	|FROM
	|	TemporaryTableInventory AS TemporaryTable
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ISNULL(SUM(CASE
	|				WHEN NOT TemporaryTable.IncludeExpensesInCostPrice
	|					THEN TemporaryTable.ReverseChargeVATAmount
	|				ELSE 0
	|			END), 0) AS ReverseChargeVATExpenses
	|FROM
	|	TemporaryTableExpenses AS TemporaryTable";
	
	ResultArray = Query.ExecuteBatch();
	
	Selection = ResultArray[0].Select();
	Selection.Next();
	ReverseChargeVATInventory		= Selection.ReverseChargeVATInventory;
	
	Selection = ResultArray[1].Select();
	Selection.Next();
	ReverseChargeVATExpenses	= Selection.ReverseChargeVATExpenses;
	
	Query.Text =
	"SELECT
	|	1 AS Ordering,
	|	TableAccountingJournalEntries.Period AS Period,
	|	TableAccountingJournalEntries.Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	TableAccountingJournalEntries.GLAccount AS AccountDr,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccount.Currency
	|			THEN TableAccountingJournalEntries.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccount.Currency
	|			THEN TableAccountingJournalEntries.AmountCur + TableAccountingJournalEntries.AmountExpenseCur - TableAccountingJournalEntries.VATAmountCur
	|		ELSE 0
	|	END AS AmountCurDr,
	|	TableAccountingJournalEntries.GLAccountVendorSettlements AS AccountCr,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccountVendorSettlements.Currency
	|			THEN TableAccountingJournalEntries.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccountVendorSettlements.Currency
	|			THEN TableAccountingJournalEntries.AmountCur + TableAccountingJournalEntries.AmountExpenseCur - TableAccountingJournalEntries.VATAmountCur
	|		ELSE 0
	|	END AS AmountCurCr,
	|	TableAccountingJournalEntries.Amount + TableAccountingJournalEntries.AmountExpense - TableAccountingJournalEntries.VATAmount AS Amount,
	|	&InventoryIncrease AS Content,
	|	FALSE AS OfflineRecord
	|FROM
	|	TemporaryTableInventory AS TableAccountingJournalEntries
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	TableAccountingJournalEntries.Period,
	|	TableAccountingJournalEntries.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	TableAccountingJournalEntries.GLAccount,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccount.Currency
	|			THEN TableAccountingJournalEntries.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccount.Currency
	|			THEN TableAccountingJournalEntries.ReverseChargeVATAmountCur
	|		ELSE 0
	|	END,
	|	TableAccountingJournalEntries.VATInputGLAccount,
	|	UNDEFINED,
	|	0,
	|	TableAccountingJournalEntries.ReverseChargeVATAmount,
	|	&ReverseChargeVAT,
	|	FALSE
	|FROM
	|	TemporaryTableInventory AS TableAccountingJournalEntries
	|WHERE
	|	TableAccountingJournalEntries.VATTaxation = VALUE(Enum.VATTaxationTypes.ReverseChargeVAT)
	|	AND NOT &RegisteredForVAT
	|
	|UNION ALL
	|
	|SELECT
	|	3,
	|	TableAccountingJournalEntries.Period,
	|	TableAccountingJournalEntries.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	TableAccountingJournalEntries.GLAccount,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccount.Currency
	|			THEN TableAccountingJournalEntries.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccount.Currency
	|			THEN TableAccountingJournalEntries.AmountCur - TableAccountingJournalEntries.VATAmountCur
	|		ELSE 0
	|	END,
	|	TableAccountingJournalEntries.GLAccountVendorSettlements,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccountVendorSettlements.Currency
	|			THEN TableAccountingJournalEntries.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccountVendorSettlements.Currency
	|			THEN TableAccountingJournalEntries.AmountCur - TableAccountingJournalEntries.VATAmountCur
	|		ELSE 0
	|	END,
	|	TableAccountingJournalEntries.Amount - TableAccountingJournalEntries.VATAmount,
	|	&OtherExpenses,
	|	FALSE
	|FROM
	|	TemporaryTableExpenses AS TableAccountingJournalEntries
	|WHERE
	|	NOT TableAccountingJournalEntries.IncludeExpensesInCostPrice
	|
	|UNION ALL
	|
	|SELECT
	|	4,
	|	TableAccountingJournalEntries.Period,
	|	TableAccountingJournalEntries.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	TableAccountingJournalEntries.GLAccount,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccount.Currency
	|			THEN TableAccountingJournalEntries.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccount.Currency
	|			THEN TableAccountingJournalEntries.ReverseChargeVATAmountCur
	|		ELSE 0
	|	END,
	|	TableAccountingJournalEntries.VATInputGLAccount,
	|	UNDEFINED,
	|	0,
	|	TableAccountingJournalEntries.ReverseChargeVATAmount,
	|	&ReverseChargeVAT,
	|	FALSE
	|FROM
	|	TemporaryTableExpenses AS TableAccountingJournalEntries
	|WHERE
	|	NOT TableAccountingJournalEntries.IncludeExpensesInCostPrice
	|	AND TableAccountingJournalEntries.VATTaxation = VALUE(Enum.VATTaxationTypes.ReverseChargeVAT)
	|	AND NOT &RegisteredForVAT
	|
	|UNION ALL
	|
	|SELECT
	|	8,
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.CustomerAdvancesGLAccount,
	|	CASE
	|		WHEN DocumentTable.CustomerAdvancesGLAccount.Currency
	|			THEN DocumentTable.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.CustomerAdvancesGLAccount.Currency
	|			THEN -DocumentTable.AmountCur
	|		ELSE 0
	|	END,
	|	DocumentTable.GLAccountCustomerSettlements,
	|	CASE
	|		WHEN DocumentTable.GLAccountCustomerSettlements.Currency
	|			THEN DocumentTable.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.GLAccountCustomerSettlements.Currency
	|			THEN -DocumentTable.AmountCur
	|		ELSE 0
	|	END,
	|	-DocumentTable.Amount,
	|	&PrepaymentReversal,
	|	FALSE
	|FROM
	|	TemporaryTablePrepayment AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	11,
	|	TableAccountingJournalEntries.Date,
	|	TableAccountingJournalEntries.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	TableAccountingJournalEntries.GLAccount,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccount.Currency
	|			THEN TableAccountingJournalEntries.Currency
	|		ELSE UNDEFINED
	|	END,
	|	0,
	|	TableAccountingJournalEntries.MarkupGLAccount,
	|	CASE
	|		WHEN TableAccountingJournalEntries.MarkupGLAccount.Currency
	|			THEN TableAccountingJournalEntries.Currency
	|		ELSE UNDEFINED
	|	END,
	|	0,
	|	TableAccountingJournalEntries.Amount - TableAccountingJournalEntries.Cost,
	|	&Markup,
	|	FALSE
	|FROM
	|	TemporaryTablePOSSummary AS TableAccountingJournalEntries
	|
	|UNION ALL
	|
	|SELECT
	|	12,
	|	TableAccountingJournalEntries.Period,
	|	TableAccountingJournalEntries.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	TableAccountingJournalEntries.VATInputGLAccount,
	|	UNDEFINED,
	|	0,
	|	TableAccountingJournalEntries.GLAccountVendorSettlements,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccountVendorSettlements.Currency
	|			THEN TableAccountingJournalEntries.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	SUM(CASE
	|			WHEN TableAccountingJournalEntries.GLAccountVendorSettlements.Currency
	|				THEN TableAccountingJournalEntries.VATAmountCur
	|			ELSE 0
	|		END),
	|	SUM(TableAccountingJournalEntries.VATAmount),
	|	&PreVAT,
	|	FALSE
	|FROM
	|	TemporaryTableInventory AS TableAccountingJournalEntries
	|WHERE
	|	TableAccountingJournalEntries.IncludeExpensesInCostPrice
	|	AND TableAccountingJournalEntries.VATAmount > 0
	|
	|GROUP BY
	|	TableAccountingJournalEntries.Period,
	|	TableAccountingJournalEntries.GLAccountVendorSettlements,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccountVendorSettlements.Currency
	|			THEN TableAccountingJournalEntries.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	TableAccountingJournalEntries.VATInputGLAccount,
	|	TableAccountingJournalEntries.Company
	|
	|UNION ALL
	|
	|SELECT
	|	13,
	|	TableAccountingJournalEntries.Period,
	|	TableAccountingJournalEntries.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	TableAccountingJournalEntries.VATInputGLAccount,
	|	UNDEFINED,
	|	0,
	|	TableAccountingJournalEntries.GLAccountVendorSettlements,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccountVendorSettlements.Currency
	|			THEN TableAccountingJournalEntries.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	SUM(CASE
	|			WHEN TableAccountingJournalEntries.GLAccountVendorSettlements.Currency
	|				THEN TableAccountingJournalEntries.VATAmountCur
	|			ELSE 0
	|		END),
	|	SUM(TableAccountingJournalEntries.VATAmount),
	|	&PreVAT,
	|	FALSE
	|FROM
	|	TemporaryTableExpenses AS TableAccountingJournalEntries
	|WHERE
	|	TableAccountingJournalEntries.IncludeExpensesInCostPrice
	|	AND TableAccountingJournalEntries.VATAmount > 0
	|
	|GROUP BY
	|	TableAccountingJournalEntries.Period,
	|	TableAccountingJournalEntries.VATInputGLAccount,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccountVendorSettlements.Currency
	|			THEN TableAccountingJournalEntries.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	TableAccountingJournalEntries.Company,
	|	TableAccountingJournalEntries.GLAccountVendorSettlements
	|
	|UNION ALL
	|
	|SELECT
	|	14,
	|	TableAccountingJournalEntries.Period,
	|	TableAccountingJournalEntries.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	TableAccountingJournalEntries.VATInputGLAccount,
	|	UNDEFINED,
	|	0,
	|	TableAccountingJournalEntries.GLAccountVendorSettlements,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccountVendorSettlements.Currency
	|			THEN TableAccountingJournalEntries.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	SUM(CASE
	|			WHEN TableAccountingJournalEntries.GLAccountVendorSettlements.Currency
	|				THEN TableAccountingJournalEntries.VATAmountCur
	|			ELSE 0
	|		END),
	|	SUM(TableAccountingJournalEntries.VATAmount),
	|	&PreVATInventory,
	|	FALSE
	|FROM
	|	TemporaryTableInventory AS TableAccountingJournalEntries
	|WHERE
	|	NOT TableAccountingJournalEntries.IncludeExpensesInCostPrice
	|	AND TableAccountingJournalEntries.VATAmount > 0
	|
	|GROUP BY
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccountVendorSettlements.Currency
	|			THEN TableAccountingJournalEntries.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	TableAccountingJournalEntries.VATInputGLAccount,
	|	TableAccountingJournalEntries.Company,
	|	TableAccountingJournalEntries.GLAccountVendorSettlements,
	|	TableAccountingJournalEntries.Period
	|
	|UNION ALL
	|
	|SELECT
	|	15,
	|	TableAccountingJournalEntries.Period,
	|	TableAccountingJournalEntries.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	TableAccountingJournalEntries.VATInputGLAccount,
	|	UNDEFINED,
	|	0,
	|	TableAccountingJournalEntries.GLAccountVendorSettlements,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccountVendorSettlements.Currency
	|			THEN TableAccountingJournalEntries.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	SUM(CASE
	|			WHEN TableAccountingJournalEntries.GLAccountVendorSettlements.Currency
	|				THEN TableAccountingJournalEntries.VATAmountCur
	|			ELSE 0
	|		END),
	|	SUM(TableAccountingJournalEntries.VATAmount),
	|	&PreVATExpenses,
	|	FALSE
	|FROM
	|	TemporaryTableExpenses AS TableAccountingJournalEntries
	|WHERE
	|	NOT TableAccountingJournalEntries.IncludeExpensesInCostPrice
	|	AND TableAccountingJournalEntries.VATAmount > 0
	|
	|GROUP BY
	|	TableAccountingJournalEntries.Company,
	|	TableAccountingJournalEntries.Period,
	|	TableAccountingJournalEntries.VATInputGLAccount,
	|	TableAccountingJournalEntries.GLAccountVendorSettlements,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccountVendorSettlements.Currency
	|			THEN TableAccountingJournalEntries.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END
	|
	|UNION ALL
	|
	|SELECT
	|	16,
	|	TableAccountingJournalEntries.Period,
	|	TableAccountingJournalEntries.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	&GLAccountVATReverseCharge,
	|	UNDEFINED,
	|	0,
	|	TableAccountingJournalEntries.VATOutputGLAccount,
	|	UNDEFINED,
	|	0,
	|	SUM(TableAccountingJournalEntries.ReverseChargeVATAmount),
	|	&ReverseChargeVAT,
	|	FALSE
	|FROM
	|	TemporaryTableInventory AS TableAccountingJournalEntries
	|WHERE
	|	&RegisteredForVAT
	|	AND TableAccountingJournalEntries.ReverseChargeVATAmount > 0
	|
	|GROUP BY
	|	TableAccountingJournalEntries.Period,
	|	TableAccountingJournalEntries.Company,
	|	TableAccountingJournalEntries.VATOutputGLAccount
	|
	|UNION ALL
	|
	|SELECT
	|	17,
	|	TableAccountingJournalEntries.Period,
	|	TableAccountingJournalEntries.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	&GLAccountVATReverseCharge,
	|	UNDEFINED,
	|	0,
	|	TableAccountingJournalEntries.VATOutputGLAccount,
	|	UNDEFINED,
	|	0,
	|	SUM(CASE
	|			WHEN NOT TableAccountingJournalEntries.IncludeExpensesInCostPrice
	|				THEN TableAccountingJournalEntries.ReverseChargeVATAmount
	|			ELSE 0
	|		END),
	|	&ReverseChargeVAT,
	|	FALSE
	|FROM
	|	TemporaryTableExpenses AS TableAccountingJournalEntries
	|WHERE
	|	&RegisteredForVAT
	|	AND TableAccountingJournalEntries.ReverseChargeVATAmount > 0
	|
	|GROUP BY
	|	TableAccountingJournalEntries.Period,
	|	TableAccountingJournalEntries.VATOutputGLAccount,
	|	TableAccountingJournalEntries.Company
	|
	|UNION ALL
	|
	|SELECT
	|	18,
	|	TableAccountingJournalEntries.Period,
	|	TableAccountingJournalEntries.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	TableAccountingJournalEntries.VATInputGLAccount,
	|	UNDEFINED,
	|	0,
	|	&GLAccountVATReverseCharge,
	|	UNDEFINED,
	|	0,
	|	SUM(TableAccountingJournalEntries.ReverseChargeVATAmount),
	|	&ReverseChargeVATReclaimed,
	|	FALSE
	|FROM
	|	TemporaryTableInventory AS TableAccountingJournalEntries
	|WHERE
	|	&RegisteredForVAT
	|	AND TableAccountingJournalEntries.ReverseChargeVATAmount > 0
	|
	|GROUP BY
	|	TableAccountingJournalEntries.VATInputGLAccount,
	|	TableAccountingJournalEntries.Period,
	|	TableAccountingJournalEntries.Company
	|
	|UNION ALL
	|
	|SELECT
	|	19,
	|	TableAccountingJournalEntries.Period,
	|	TableAccountingJournalEntries.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	TableAccountingJournalEntries.VATInputGLAccount,
	|	UNDEFINED,
	|	0,
	|	&GLAccountVATReverseCharge,
	|	UNDEFINED,
	|	0,
	|	SUM(CASE
	|			WHEN NOT TableAccountingJournalEntries.IncludeExpensesInCostPrice
	|				THEN TableAccountingJournalEntries.ReverseChargeVATAmount
	|			ELSE 0
	|		END),
	|	&ReverseChargeVATReclaimed,
	|	FALSE
	|FROM
	|	TemporaryTableExpenses AS TableAccountingJournalEntries
	|WHERE
	|	&RegisteredForVAT
	|	AND TableAccountingJournalEntries.ReverseChargeVATAmount > 0
	|
	|GROUP BY
	|	TableAccountingJournalEntries.VATInputGLAccount,
	|	TableAccountingJournalEntries.Company,
	|	TableAccountingJournalEntries.Period
	|
	|UNION ALL
	|
	|SELECT
	|	20,
	|	PrepaymentVAT.Period,
	|	PrepaymentVAT.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	&VATAdvancesToSuppliers,
	|	UNDEFINED,
	|	0,
	|	&VATInput,
	|	UNDEFINED,
	|	0,
	|	SUM(PrepaymentVAT.VATAmount),
	|	&ContentVATRevenue,
	|	FALSE
	|FROM
	|	TemporaryTablePrepaymentVAT AS PrepaymentVAT
	|		LEFT JOIN PrepaymentPostBySourceDocuments AS PrepaymentPostBySourceDocuments
	|		ON PrepaymentVAT.ShipmentDocument = PrepaymentPostBySourceDocuments.ShipmentDocument
	|		LEFT JOIN PrepaymentWithoutInvoice AS PrepaymentWithoutInvoice
	|		ON PrepaymentVAT.ShipmentDocument = PrepaymentWithoutInvoice.ShipmentDocument
	|WHERE
	|	PrepaymentWithoutInvoice.ShipmentDocument IS NULL
	|	AND PrepaymentPostBySourceDocuments.ShipmentDocument IS NULL
	|	AND &PostVATEntriesBySourceDocuments
	|
	|GROUP BY
	|	PrepaymentVAT.Period,
	|	PrepaymentVAT.Company
	|
	|UNION ALL
	|
	|SELECT
	|	21,
	|	PrepaymentVAT.Period,
	|	PrepaymentVAT.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	&VATAdvancesToSuppliers,
	|	UNDEFINED,
	|	0,
	|	&VATInput,
	|	UNDEFINED,
	|	0,
	|	SUM(PrepaymentVAT.VATAmount),
	|	&ContentVATRevenue,
	|	FALSE
	|FROM
	|	TemporaryTablePrepaymentVAT AS PrepaymentVAT
	|		INNER JOIN PrepaymentWithoutInvoice AS PrepaymentWithoutInvoice
	|		ON PrepaymentVAT.ShipmentDocument = PrepaymentWithoutInvoice.ShipmentDocument
	|		INNER JOIN PrepaymentPostBySourceDocuments AS PrepaymentPostBySourceDocuments
	|		ON PrepaymentVAT.ShipmentDocument = PrepaymentPostBySourceDocuments.ShipmentDocument
	|WHERE
	|	&PostVATEntriesBySourceDocuments
	|
	|GROUP BY
	|	PrepaymentVAT.Period,
	|	PrepaymentVAT.Company
	|
	|UNION ALL
	|
	|SELECT
	|	22,
	|	OfflineRecords.Period,
	|	OfflineRecords.Company,
	|	OfflineRecords.PlanningPeriod,
	|	OfflineRecords.AccountDr,
	|	OfflineRecords.CurrencyDr,
	|	OfflineRecords.AmountCurDr,
	|	OfflineRecords.AccountCr,
	|	OfflineRecords.CurrencyCr,
	|	OfflineRecords.AmountCurCr,
	|	OfflineRecords.Amount,
	|	OfflineRecords.Content,
	|	OfflineRecords.OfflineRecord
	|FROM
	|	AccountingRegister.AccountingJournalEntries AS OfflineRecords
	|WHERE
	|	OfflineRecords.Recorder = &Ref
	|	AND OfflineRecords.OfflineRecord
	|
	|ORDER BY
	|	Ordering";
	
	Query.SetParameter("PositiveExchangeDifferenceGLAccount",			Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeGain"));
	Query.SetParameter("NegativeExchangeDifferenceAccountOfAccounting",	Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeLoss"));
	
	Query.SetParameter("VATAdvancesToSuppliers",			Catalogs.DefaultGLAccounts.GetDefaultGLAccount("VATAdvancesToSuppliers"));
	Query.SetParameter("VATInput",							Catalogs.DefaultGLAccounts.GetDefaultGLAccount("VATInput"));
	Query.SetParameter("Date",								StructureAdditionalProperties.ForPosting.Date);
	Query.SetParameter("Company",							StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PostVATEntriesBySourceDocuments",	StructureAdditionalProperties.AccountingPolicy.PostVATEntriesBySourceDocuments);
	Query.SetParameter("RegisteredForVAT",					StructureAdditionalProperties.AccountingPolicy.RegisteredForVAT);
	Query.SetParameter("Ref",								DocumentRefPurchaseInvoice);
	
	Query.SetParameter("InventoryIncrease",
		NStr("en = 'Inventory receipt'",
			StructureAdditionalProperties.DefaultLanguageCode));
	
	Query.SetParameter("OtherExpenses",
		NStr("en = 'Expenses incurred'",
			StructureAdditionalProperties.DefaultLanguageCode));
	
	Query.SetParameter("SetOffAdvancePayment",
		NStr("en = 'Advance payment clearing'",
			StructureAdditionalProperties.DefaultLanguageCode));
	
	Query.SetParameter("PrepaymentReversal",
		NStr("en = 'Advance payment reversal'",
			StructureAdditionalProperties.DefaultLanguageCode));
	
	Query.SetParameter("ReversalOfReserves",
		NStr("en = 'Cost of goods sold reversal'",
			StructureAdditionalProperties.DefaultLanguageCode));
	
	Query.SetParameter("Markup",
		NStr("en = 'Retail markup'",
			StructureAdditionalProperties.DefaultLanguageCode));
	
	Query.SetParameter("ExchangeDifference",
		NStr("en = 'Foreign currency exchange gains and losses'",
			StructureAdditionalProperties.DefaultLanguageCode));
	
	Query.SetParameter("PreVATInventory",
		NStr("en = 'VAT input on goods purchased'",
			StructureAdditionalProperties.DefaultLanguageCode));
	
	Query.SetParameter("PreVATExpenses",
		NStr("en = 'VAT input on expenses incurred'",
			StructureAdditionalProperties.DefaultLanguageCode));
	
	Query.SetParameter("PreVAT",
		NStr("en = 'VAT input'",
			StructureAdditionalProperties.DefaultLanguageCode));
	
	Query.SetParameter("ContentVATRevenue",
		NStr("en = 'Advance VAT clearing'",
			StructureAdditionalProperties.DefaultLanguageCode));
	
	Query.SetParameter("ReverseChargeVAT",
		NStr("en = 'Reverse charge VAT'",
			StructureAdditionalProperties.DefaultLanguageCode));
	
	Query.SetParameter("ReverseChargeVATReclaimed",
		NStr("en = 'Reverse charge VAT reclaimed'",
			StructureAdditionalProperties.DefaultLanguageCode));
	
	If Query.Parameters.RegisteredForVAT
		And ReverseChargeVATInventory + ReverseChargeVATExpenses > 0 Then
		
		Query.SetParameter("GLAccountVATReverseCharge", Catalogs.DefaultGLAccounts.GetDefaultGLAccount("VATReverseCharge"));
		
	Else
		
		Query.SetParameter("GLAccountVATReverseCharge", Undefined);
		
	EndIf;
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	
	While Selection.Next() Do
		NewEntry = StructureAdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries.Add();
		FillPropertyValues(NewEntry, Selection);
	EndDo;
	
EndProcedure

Procedure GenerateTableVATIncurred(DocumentRefPurchaseInvoice, StructureAdditionalProperties)
	
	If Not StructureAdditionalProperties.AccountingPolicy.RegisteredForVAT
		Or Not StructureAdditionalProperties.DocumentAttributes.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT
		Or StructureAdditionalProperties.DocumentAttributes.Counterparty = Catalogs.Counterparties.RetailCustomer Then
		
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableVATIncurred", New ValueTable);
		Return;
		
	EndIf;
	
	QueryText = "";
	If NOT StructureAdditionalProperties.AccountingPolicy.PostVATEntriesBySourceDocuments Then
		QueryText = WorkWithVAT.GetVATPreparationQueryText() + 
		"SELECT
		|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
		|	TTVATPreparation.Document AS ShipmentDocument,
		|	TTVATPreparation.VATRate AS VATRate,
		|	TTVATPreparation.Period AS Period,
		|	TTVATPreparation.Company AS Company,
		|	TTVATPreparation.Counterparty AS Supplier,
		|	TTVATPreparation.VATAmount AS VATAmount,
		|	TTVATPreparation.AmountExcludesVAT AS AmountExcludesVAT
		|FROM
		|	TTVATPreparation AS TTVATPreparation";
	EndIf;
	
	If ValueIsFilled(QueryText) Then
		QueryText = QueryText + "
		|
		|UNION ALL
		|"
	EndIf;
	
	QueryText = QueryText +
	"SELECT
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	PrepaymentVAT.ShipmentDocument AS ShipmentDocument,
	|	PrepaymentVAT.VATRate AS VATRate,
	|	PrepaymentVAT.Period AS Period,
	|	PrepaymentVAT.Company AS Company,
	|	PrepaymentVAT.Customer AS Supplier,
	|	PrepaymentVAT.VATAmount AS VATAmount,
	|	PrepaymentVAT.AmountExcludesVAT AS AmountExcludesVAT
	|FROM
	|	TemporaryTablePrepaymentVAT AS PrepaymentVAT
	|		INNER JOIN PrepaymentWithoutInvoice AS PrepaymentWithoutInvoice
	|		ON PrepaymentVAT.ShipmentDocument = PrepaymentWithoutInvoice.ShipmentDocument
	|		LEFT JOIN PrepaymentPostBySourceDocuments AS PrepaymentPostBySourceDocuments
	|		ON PrepaymentVAT.ShipmentDocument = PrepaymentPostBySourceDocuments.ShipmentDocument
	|WHERE
	|	PrepaymentPostBySourceDocuments.ShipmentDocument IS NULL";
	
	Query = New Query(QueryText);
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableVATIncurred", QueryResult.Unload());
	
EndProcedure

Procedure GenerateTableVATInput(DocumentRefPurchaseInvoice, StructureAdditionalProperties)
	
	If Not StructureAdditionalProperties.AccountingPolicy.RegisteredForVAT
		Or StructureAdditionalProperties.DocumentAttributes.Counterparty = Catalogs.Counterparties.RetailCustomer Then
		
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableVATInput", New ValueTable);
		Return;
		
	EndIf;
	
	QueryText = "";
	
	If StructureAdditionalProperties.AccountingPolicy.PostVATEntriesBySourceDocuments
		And StructureAdditionalProperties.DocumentAttributes.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then
		
		QueryText = WorkWithVAT.GetVATPreparationQueryText() + 
		"SELECT
		|	TTVATPreparation.Document AS ShipmentDocument,
		|	TTVATPreparation.VATRate AS VATRate,
		|	TTVATPreparation.Period AS Period,
		|	TTVATPreparation.Company AS Company,
		|	TTVATPreparation.Counterparty AS Supplier,
		|	VALUE(Enum.VATOperationTypes.Purchases) AS OperationType,
		|	TTVATPreparation.ProductsType AS ProductType,
		|	TTVATPreparation.VATAmount AS VATAmount,
		|	TTVATPreparation.AmountExcludesVAT AS AmountExcludesVAT
		|FROM
		|	TTVATPreparation AS TTVATPreparation
		|
		|UNION ALL
		|
		|SELECT
		|	PrepaymentVAT.ShipmentDocument,
		|	PrepaymentVAT.VATRate,
		|	PrepaymentVAT.Period,
		|	PrepaymentVAT.Company,
		|	PrepaymentVAT.Customer,
		|	VALUE(Enum.VATOperationTypes.AdvanceCleared) AS OperationType,
		|	VALUE(Enum.ProductsTypes.EmptyRef) AS ProductType,
		|	-PrepaymentVAT.VATAmount,
		|	-PrepaymentVAT.AmountExcludesVAT
		|FROM
		|	TemporaryTablePrepaymentVAT AS PrepaymentVAT
		|		INNER JOIN PrepaymentPostBySourceDocuments AS PrepaymentPostBySourceDocuments
		|		ON PrepaymentVAT.ShipmentDocument = PrepaymentPostBySourceDocuments.ShipmentDocument
		|		INNER JOIN PrepaymentWithoutInvoice AS PrepaymentWithoutInvoice
		|		ON PrepaymentVAT.ShipmentDocument = PrepaymentWithoutInvoice.ShipmentDocument
		|
		|UNION ALL
		|
		|SELECT
		|	PrepaymentVAT.ShipmentDocument,
		|	PrepaymentVAT.VATRate,
		|	PrepaymentVAT.Period,
		|	PrepaymentVAT.Company,
		|	PrepaymentVAT.Customer,
		|	VALUE(Enum.VATOperationTypes.AdvanceCleared) AS OperationType,
		|	VALUE(Enum.ProductsTypes.EmptyRef) AS ProductType,
		|	-PrepaymentVAT.VATAmount,
		|	-PrepaymentVAT.AmountExcludesVAT
		|FROM
		|	TemporaryTablePrepaymentVAT AS PrepaymentVAT
		|		LEFT JOIN PrepaymentPostBySourceDocuments AS PrepaymentPostBySourceDocuments
		|		ON PrepaymentVAT.ShipmentDocument = PrepaymentPostBySourceDocuments.ShipmentDocument
		|		LEFT JOIN PrepaymentWithoutInvoice AS PrepaymentWithoutInvoice
		|		ON PrepaymentVAT.ShipmentDocument = PrepaymentWithoutInvoice.ShipmentDocument
		|WHERE
		|	PrepaymentWithoutInvoice.ShipmentDocument IS NULL
		|	AND PrepaymentPostBySourceDocuments.ShipmentDocument IS NULL";
		
	ElsIf StructureAdditionalProperties.DocumentAttributes.VATTaxation = Enums.VATTaxationTypes.ReverseChargeVAT Then
		
		QueryText = QueryText + 
		"SELECT
		|	UnionTable.Document AS ShipmentDocument,
		|	UnionTable.VATRate AS VATRate,
		|	UnionTable.Period AS Period,
		|	UnionTable.Company AS Company,
		|	UnionTable.Company AS Supplier,
		|	VALUE(Enum.VATOperationTypes.ReverseChargeApplied) AS OperationType,
		|	UnionTable.ProductsType AS ProductType,
		|	SUM(UnionTable.VATAmount) AS VATAmount,
		|	SUM(UnionTable.AmountExcludesVAT) AS AmountExcludesVAT
		|FROM
		|	(SELECT
		|		TemporaryTableInventory.ReverseChargeVATRate AS VATRate,
		|		TemporaryTableInventory.ReverseChargeVATAmountCur * TemporaryTableInventory.ExchangeRate / TemporaryTableInventory.Multiplicity AS VATAmount,
		|		(TemporaryTableInventory.AmountCur + TemporaryTableInventory.AmountExpenseCur) * TemporaryTableInventory.ExchangeRate / TemporaryTableInventory.Multiplicity AS AmountExcludesVAT,
		|		TemporaryTableInventory.Document AS Document,
		|		TemporaryTableInventory.Period AS Period,
		|		TemporaryTableInventory.ProductsType AS ProductsType,
		|		TemporaryTableInventory.Company AS Company
		|	FROM
		|		TemporaryTableInventory AS TemporaryTableInventory
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		TemporaryTableExpenses.ReverseChargeVATRate,
		|		TemporaryTableExpenses.ReverseChargeVATAmountCur * TemporaryTableExpenses.ExchangeRate / TemporaryTableExpenses.Multiplicity,
		|		TemporaryTableExpenses.AmountCur * TemporaryTableExpenses.ExchangeRate / TemporaryTableExpenses.Multiplicity,
		|		TemporaryTableExpenses.Document,
		|		TemporaryTableExpenses.Period,
		|		TemporaryTableExpenses.ProductsType,
		|		TemporaryTableExpenses.Company
		|	FROM
		|		TemporaryTableExpenses AS TemporaryTableExpenses
		|	WHERE
		|		NOT TemporaryTableExpenses.IncludeExpensesInCostPrice) AS UnionTable
		|
		|GROUP BY
		|	UnionTable.VATRate,
		|	UnionTable.ProductsType,
		|	UnionTable.Document,
		|	UnionTable.Period,
		|	UnionTable.Company";
		
	Else
		
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableVATInput", New ValueTable);
		Return;
		
	EndIf;
	
	Query = New Query(QueryText);
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableVATInput", QueryResult.Unload());
	
EndProcedure

Procedure GenerateTableVATOutput(DocumentRefPurchaseInvoice, StructureAdditionalProperties)
	
	If Not StructureAdditionalProperties.AccountingPolicy.RegisteredForVAT Then
		
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableVATOutput", New ValueTable);
		Return;
		
	EndIf;
	
	QueryText = "";
	If StructureAdditionalProperties.DocumentAttributes.VATTaxation = Enums.VATTaxationTypes.ReverseChargeVAT Then
		
		QueryText = QueryText + 
		"SELECT
		|	UnionTable.Document AS ShipmentDocument,
		|	UnionTable.VATRate AS VATRate,
		|	UnionTable.Period AS Period,
		|	UnionTable.Company AS Company,
		|	UnionTable.Company AS Customer,
		|	VALUE(Enum.VATOperationTypes.ReverseChargeApplied) AS OperationType,
		|	UnionTable.ProductsType AS ProductType,
		|	SUM(UnionTable.VATAmount) AS VATAmount,
		|	SUM(UnionTable.AmountExcludesVAT) AS AmountExcludesVAT
		|FROM
		|	(SELECT
		|		TemporaryTableInventory.ReverseChargeVATRate AS VATRate,
		|		TemporaryTableInventory.ReverseChargeVATAmountCur * TemporaryTableInventory.ExchangeRate / TemporaryTableInventory.Multiplicity AS VATAmount,
		|		(TemporaryTableInventory.AmountCur + TemporaryTableInventory.AmountExpenseCur) * TemporaryTableInventory.ExchangeRate / TemporaryTableInventory.Multiplicity AS AmountExcludesVAT,
		|		TemporaryTableInventory.Document AS Document,
		|		TemporaryTableInventory.Period AS Period,
		|		TemporaryTableInventory.ProductsType AS ProductsType,
		|		TemporaryTableInventory.Company AS Company
		|	FROM
		|		TemporaryTableInventory AS TemporaryTableInventory
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		TemporaryTableExpenses.ReverseChargeVATRate,
		|		TemporaryTableExpenses.ReverseChargeVATAmountCur * TemporaryTableExpenses.ExchangeRate / TemporaryTableExpenses.Multiplicity,
		|		TemporaryTableExpenses.AmountCur * TemporaryTableExpenses.ExchangeRate / TemporaryTableExpenses.Multiplicity,
		|		TemporaryTableExpenses.Document,
		|		TemporaryTableExpenses.Period,
		|		TemporaryTableExpenses.ProductsType,
		|		TemporaryTableExpenses.Company
		|	FROM
		|		TemporaryTableExpenses AS TemporaryTableExpenses
		|	WHERE
		|		NOT TemporaryTableExpenses.IncludeExpensesInCostPrice) AS UnionTable
		|
		|GROUP BY
		|	UnionTable.VATRate,
		|	UnionTable.Document,
		|	UnionTable.Period,
		|	UnionTable.ProductsType,
		|	UnionTable.Company";
		
	Else
		
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableVATOutput", New ValueTable);
		Return;
		
	EndIf;
	
	Query = New Query(QueryText);
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableVATOutput", QueryResult.Unload());
	
EndProcedure

Procedure GenerateTableTaxPayable(DocumentRefPurchaseInvoice, StructureAdditionalProperties)
	
	If StructureAdditionalProperties.AccountingPolicy.RegisteredForVAT
		Or Not StructureAdditionalProperties.DocumentAttributes.VATTaxation = Enums.VATTaxationTypes.ReverseChargeVAT Then
		
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableTaxAccounting", New ValueTable);
		Return;
		
	EndIf;
	
	QueryText = 
	"SELECT
	|	UnionTable.Period AS Period,
	|	UnionTable.Company AS Company,
	|	VALUE(Catalog.TaxTypes.VAT) AS TaxKind,
	|	SUM(UnionTable.ReverseChargeVATAmount) AS Amount,
	|	&ReverseChargeVAT AS ContentOfAccountingRecord
	|FROM
	|	(SELECT
	|		TemporaryTableInventory.Period AS Period,
	|		TemporaryTableInventory.Company AS Company,
	|		TemporaryTableInventory.ReverseChargeVATAmount AS ReverseChargeVATAmount
	|	FROM
	|		TemporaryTableInventory AS TemporaryTableInventory
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		TemporaryTableExpenses.Period,
	|		TemporaryTableExpenses.Company,
	|		TemporaryTableExpenses.ReverseChargeVATAmount
	|	FROM
	|		TemporaryTableExpenses AS TemporaryTableExpenses
	|	WHERE
	|		NOT TemporaryTableExpenses.IncludeExpensesInCostPrice) AS UnionTable
	|
	|GROUP BY
	|	UnionTable.Period,
	|	UnionTable.Company";
	
	Query = New Query(QueryText);
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("ReverseChargeVAT",
		NStr("en = 'Reverse charge VAT'",
			StructureAdditionalProperties.DefaultLanguageCode));
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableTaxAccounting", QueryResult.Unload());
	
EndProcedure

Procedure GenerateTableGoodsReceivedNotInvoiced(DocumentRef, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	MIN(TableProducts.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableProducts.Period AS Period,
	|	TableProducts.GoodsReceipt AS GoodsReceipt,
	|	TableProducts.Company AS Company,
	|	TableProducts.Counterparty AS Counterparty,
	|	TableProducts.Contract AS Contract,
	|	TableProducts.Products AS Products,
	|	TableProducts.Characteristic AS Characteristic,
	|	TableProducts.Batch AS Batch,
	|	TableProducts.Order AS PurchaseOrder,
	|	SUM(TableProducts.Quantity) AS Quantity
	|FROM
	|	TemporaryTableInventory AS TableProducts
	|WHERE
	|	TableProducts.GoodsReceipt <> VALUE(Document.GoodsReceipt.EmptyRef)
	|
	|GROUP BY
	|	TableProducts.Period,
	|	TableProducts.GoodsReceipt,
	|	TableProducts.Company,
	|	TableProducts.Counterparty,
	|	TableProducts.Contract,
	|	TableProducts.Products,
	|	TableProducts.Characteristic,
	|	TableProducts.Batch,
	|	TableProducts.Order";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableGoodsReceivedNotInvoiced", QueryResult.Unload());
	
EndProcedure

#Region WorkWithSerialNumbers

// Generates a table of values that contains the data for the SerialNumbersInWarranty information register.
// Tables of values saves into the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableSerialNumbers(DocumentRef, StructureAdditionalProperties)
	
	If DocumentRef.SerialNumbers.Count() = 0 Then
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbersBalance", New ValueTable);
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbersInWarranty", New ValueTable);
		Return;
	EndIf;
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	TemporaryTableInventory.Period AS Period,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	VALUE(Enum.SerialNumbersOperations.Receipt) AS Operation,
	|	TemporaryTableInventory.Period AS EventDate,
	|	SerialNumbers.SerialNumber AS SerialNumber,
	|	TemporaryTableInventory.Company AS Company,
	|	TemporaryTableInventory.Products AS Products,
	|	TemporaryTableInventory.Characteristic AS Characteristic,
	|	TemporaryTableInventory.Batch AS Batch,
	|	TemporaryTableInventory.StructuralUnit AS StructuralUnit,
	|	TemporaryTableInventory.Cell AS Cell,
	|	1 AS Quantity
	|FROM
	|	TemporaryTableInventory AS TemporaryTableInventory
	|		INNER JOIN TemporaryTableSerialNumbers AS SerialNumbers
	|		ON TemporaryTableInventory.ConnectionKey = SerialNumbers.ConnectionKey
	|WHERE
	|	TemporaryTableInventory.GoodsReceipt = VALUE(Document.GoodsReceipt.EmptyRef)";
	
	QueryResult = Query.Execute().Unload();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbersInWarranty", QueryResult);
	If StructureAdditionalProperties.AccountingPolicy.SerialNumbersBalance Then
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbersBalance", QueryResult);
	Else
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbersBalance", New ValueTable);
	EndIf;
	
EndProcedure

#EndRegion

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefPurchaseInvoice, StructureAdditionalProperties) Export
	
	StructureAdditionalProperties.Insert("DefaultLanguageCode", Metadata.DefaultLanguage.LanguageCode);
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	Header.Ref AS Ref,
	|	Header.Date AS Date,
	|	Header.Company AS Company,
	|	Header.Counterparty AS Counterparty,
	|	Header.ExchangeRate AS ExchangeRate,
	|	Header.Multiplicity AS Multiplicity,
	|	Header.SetPaymentTerms AS SetPaymentTerms
	|INTO SupplierInvoiceHeader
	|FROM
	|	Document.SupplierInvoice AS Header
	|WHERE
	|	Header.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ExchangeRatesSliceLast.Currency AS Currency,
	|	ExchangeRatesSliceLast.ExchangeRate AS ExchangeRate,
	|	ExchangeRatesSliceLast.Multiplicity AS Multiplicity
	|INTO TemporaryTableExchangeRatesSliceLatest
	|FROM
	|	InformationRegister.ExchangeRates.SliceLast(&PointInTime, Currency IN (&PresentationCurrency, &CurrencyNational)) AS ExchangeRatesSliceLast
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SupplierInvoiceInventory.LineNumber AS LineNumber,
	|	SupplierInvoiceInventory.Ref AS Document,
	|	SupplierInvoiceInventory.Ref.BasisDocument AS BasisDocument,
	|	SupplierInvoiceInventory.Ref.Counterparty AS Counterparty,
	|	SupplierInvoiceInventory.Ref.Counterparty.DoOperationsByContracts AS DoOperationsByContracts,
	|	SupplierInvoiceInventory.Ref.Counterparty.DoOperationsByDocuments AS DoOperationsByDocuments,
	|	SupplierInvoiceInventory.Ref.Counterparty.DoOperationsByOrders AS DoOperationsByOrders,
	|	SupplierInvoiceInventory.Ref.Contract AS Contract,
	|	SupplierInvoiceInventory.Ref.Responsible AS Responsible,
	|	SupplierInvoiceInventory.Ref.StructuralUnit.MarkupGLAccount AS MarkupGLAccount,
	|	SupplierInvoiceInventory.Ref.StructuralUnit.RetailPriceKind AS RetailPriceKind,
	|	SupplierInvoiceInventory.Ref.StructuralUnit.RetailPriceKind.PriceCurrency AS PriceCurrency,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	CASE
	|		WHEN SupplierInvoiceInventory.Ref.StructuralUnit.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.RetailEarningAccounting)
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS RetailTransferEarningAccounting,
	|	SupplierInvoiceInventory.Ref.Date AS Period,
	|	&Company AS Company,
	|	SupplierInvoiceInventory.Ref.StructuralUnit AS StructuralUnit,
	|	CASE
	|		WHEN &UseStorageBins
	|			THEN SupplierInvoiceInventory.Ref.Cell
	|		ELSE UNDEFINED
	|	END AS Cell,
	|	SupplierInvoiceInventory.InventoryGLAccount AS GLAccount,
	|	SupplierInvoiceInventory.Products AS Products,
	|	SupplierInvoiceInventory.Products.ProductsType AS ProductsType,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN SupplierInvoiceInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseBatches
	|			THEN SupplierInvoiceInventory.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS Batch,
	|	CASE
	|		WHEN SupplierInvoiceInventory.Order REFS Document.PurchaseOrder
	|				AND SupplierInvoiceInventory.Order <> VALUE(Document.PurchaseOrder.EmptyRef)
	|			THEN SupplierInvoiceInventory.Order
	|		ELSE UNDEFINED
	|	END AS Order,
	|	FALSE AS ProductsOnCommission,
	|	CASE
	|		WHEN SupplierInvoiceInventory.Ref.BasisDocument REFS Document.SalesInvoice
	|				AND SupplierInvoiceInventory.Ref.BasisDocument <> VALUE(Document.SalesInvoice.EmptyRef)
	|			THEN SupplierInvoiceInventory.Ref.BasisDocument.Department
	|		ELSE SupplierInvoiceInventory.Ref.Department
	|	END AS DepartmentSales,
	|	SupplierInvoiceInventory.Products.BusinessLine AS BusinessLineSales,
	|	CASE
	|		WHEN VALUETYPE(SupplierInvoiceInventory.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN SupplierInvoiceInventory.Quantity
	|		ELSE SupplierInvoiceInventory.Quantity * SupplierInvoiceInventory.MeasurementUnit.Factor
	|	END AS Quantity,
	|	SupplierInvoiceInventory.VATRate AS VATRate,
	|	CAST(CASE
	|			WHEN SupplierInvoiceInventory.Ref.IncludeVATInPrice
	|				THEN 0
	|			ELSE CASE
	|					WHEN SupplierInvoiceInventory.Ref.DocumentCurrency = &CurrencyNational
	|						THEN SupplierInvoiceInventory.VATAmount * RegExchangeRates.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * RegExchangeRates.Multiplicity)
	|					ELSE SupplierInvoiceInventory.VATAmount * SupplierInvoiceInventory.Ref.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * SupplierInvoiceInventory.Ref.Multiplicity)
	|				END
	|		END AS NUMBER(15, 2)) AS VATAmount,
	|	CAST(CASE
	|			WHEN SupplierInvoiceInventory.Ref.DocumentCurrency = &CurrencyNational
	|				THEN SupplierInvoiceInventory.VATAmount * RegExchangeRates.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * RegExchangeRates.Multiplicity)
	|			ELSE SupplierInvoiceInventory.VATAmount * SupplierInvoiceInventory.Ref.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * SupplierInvoiceInventory.Ref.Multiplicity)
	|		END AS NUMBER(15, 2)) AS AmountVATPurchaseSale,
	|	CAST(CASE
	|			WHEN SupplierInvoiceInventory.Ref.DocumentCurrency = &CurrencyNational
	|				THEN SupplierInvoiceInventory.Total * RegExchangeRates.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * RegExchangeRates.Multiplicity)
	|			ELSE SupplierInvoiceInventory.Total * SupplierInvoiceInventory.Ref.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * SupplierInvoiceInventory.Ref.Multiplicity)
	|		END AS NUMBER(15, 2)) AS Amount,
	|	CAST(CASE
	|			WHEN NOT SupplierInvoiceInventory.Ref.IncludeExpensesInCostPrice
	|				THEN 0
	|			WHEN SupplierInvoiceInventory.Ref.DocumentCurrency = &CurrencyNational
	|				THEN SupplierInvoiceInventory.AmountExpense * RegExchangeRates.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * RegExchangeRates.Multiplicity)
	|			ELSE SupplierInvoiceInventory.AmountExpense * SupplierInvoiceInventory.Ref.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * SupplierInvoiceInventory.Ref.Multiplicity)
	|		END AS NUMBER(15, 2)) AS AmountExpense,
	|	CAST(CASE
	|			WHEN NOT SupplierInvoiceInventory.Ref.IncludeExpensesInCostPrice
	|				THEN 0
	|			WHEN SupplierInvoiceInventory.Ref.DocumentCurrency = &CurrencyNational
	|				THEN SupplierInvoiceInventory.AmountExpense * RegExchangeRates.ExchangeRate * SupplierInvoiceInventory.Ref.Multiplicity / (SupplierInvoiceInventory.Ref.ExchangeRate * RegExchangeRates.Multiplicity)
	|			ELSE SupplierInvoiceInventory.AmountExpense
	|		END AS NUMBER(15, 2)) AS AmountExpenseCur,
	|	SupplierInvoiceInventory.Total AS SettlementsAmountTakenPassed,
	|	SupplierInvoiceInventory.Ref.IncludeExpensesInCostPrice AS IncludeExpensesInCostPrice,
	|	TRUE AS FixedCost,
	|	CAST(&InventoryIncrease AS STRING(100)) AS ContentOfAccountingRecord,
	|	SupplierInvoiceInventory.Ref.Counterparty.GLAccountCustomerSettlements AS GLAccountCustomerSettlements,
	|	SupplierInvoiceInventory.Ref.Counterparty.GLAccountVendorSettlements AS GLAccountVendorSettlements,
	|	SupplierInvoiceInventory.Ref.Contract.SettlementsCurrency AS SettlementsCurrency,
	|	CAST(CASE
	|			WHEN SupplierInvoiceInventory.Ref.DocumentCurrency = &CurrencyNational
	|				THEN SupplierInvoiceInventory.Total * RegExchangeRates.ExchangeRate * SupplierInvoiceInventory.Ref.Multiplicity / (SupplierInvoiceInventory.Ref.ExchangeRate * RegExchangeRates.Multiplicity)
	|			ELSE SupplierInvoiceInventory.Total
	|		END AS NUMBER(15, 2)) AS AmountCur,
	|	CAST(CASE
	|			WHEN SupplierInvoiceInventory.Ref.IncludeVATInPrice
	|				THEN 0
	|			ELSE CASE
	|					WHEN SupplierInvoiceInventory.Ref.DocumentCurrency = &CurrencyNational
	|						THEN SupplierInvoiceInventory.VATAmount * RegExchangeRates.ExchangeRate * SupplierInvoiceInventory.Ref.Multiplicity / (SupplierInvoiceInventory.Ref.ExchangeRate * RegExchangeRates.Multiplicity)
	|					ELSE SupplierInvoiceInventory.VATAmount
	|				END
	|		END AS NUMBER(15, 2)) AS VATAmountCur,
	|	SupplierInvoiceInventory.ConnectionKey AS ConnectionKey,
	|	SupplierInvoiceInventory.Ref.ExchangeRate AS ExchangeRate,
	|	SupplierInvoiceInventory.Ref.Multiplicity AS Multiplicity,
	|	SupplierInvoiceInventory.Ref.VATTaxation AS VATTaxation,
	|	SupplierInvoiceInventory.ReverseChargeVATRate AS ReverseChargeVATRate,
	|	CAST(CASE
	|			WHEN NOT SupplierInvoiceInventory.Ref.VATTaxation = VALUE(Enum.VATTaxationTypes.ReverseChargeVAT)
	|				THEN 0
	|			WHEN SupplierInvoiceInventory.Ref.DocumentCurrency = &CurrencyNational
	|				THEN SupplierInvoiceInventory.ReverseChargeVATAmount * RegExchangeRates.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * RegExchangeRates.Multiplicity)
	|			ELSE SupplierInvoiceInventory.ReverseChargeVATAmount * SupplierInvoiceInventory.Ref.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * SupplierInvoiceInventory.Ref.Multiplicity)
	|		END AS NUMBER(15, 2)) AS ReverseChargeVATAmount,
	|	CAST(CASE
	|			WHEN NOT SupplierInvoiceInventory.Ref.VATTaxation = VALUE(Enum.VATTaxationTypes.ReverseChargeVAT)
	|				THEN 0
	|			WHEN SupplierInvoiceInventory.Ref.DocumentCurrency = &CurrencyNational
	|				THEN SupplierInvoiceInventory.ReverseChargeVATAmount * RegExchangeRates.ExchangeRate * SupplierInvoiceInventory.Ref.Multiplicity / (SupplierInvoiceInventory.Ref.ExchangeRate * RegExchangeRates.Multiplicity)
	|			ELSE SupplierInvoiceInventory.ReverseChargeVATAmount
	|		END AS NUMBER(15, 2)) AS ReverseChargeVATAmountCur,
	|	CAST(CASE
	|			WHEN NOT SupplierInvoiceInventory.Ref.VATTaxation = VALUE(Enum.VATTaxationTypes.ReverseChargeVAT)
	|					OR &RegisteredForVAT
	|				THEN 0
	|			WHEN SupplierInvoiceInventory.Ref.DocumentCurrency = &CurrencyNational
	|				THEN SupplierInvoiceInventory.ReverseChargeVATAmount * RegExchangeRates.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * RegExchangeRates.Multiplicity)
	|			ELSE SupplierInvoiceInventory.ReverseChargeVATAmount * SupplierInvoiceInventory.Ref.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * SupplierInvoiceInventory.Ref.Multiplicity)
	|		END AS NUMBER(15, 2)) AS ReverseChargeVATAmountForNotRegistered,
	|	CAST(CASE
	|			WHEN NOT SupplierInvoiceInventory.Ref.VATTaxation = VALUE(Enum.VATTaxationTypes.ReverseChargeVAT)
	|					OR &RegisteredForVAT
	|				THEN 0
	|			WHEN SupplierInvoiceInventory.Ref.DocumentCurrency = &CurrencyNational
	|				THEN SupplierInvoiceInventory.ReverseChargeVATAmount * RegExchangeRates.ExchangeRate * SupplierInvoiceInventory.Ref.Multiplicity / (SupplierInvoiceInventory.Ref.ExchangeRate * RegExchangeRates.Multiplicity)
	|			ELSE SupplierInvoiceInventory.ReverseChargeVATAmount
	|		END AS NUMBER(15, 2)) AS ReverseChargeVATAmountCurForNotRegistered,
	|	SupplierInvoiceInventory.GoodsReceipt AS GoodsReceipt,
	|	UNDEFINED AS ProductsCorr,
	|	UNDEFINED AS CharacteristicCorr,
	|	UNDEFINED AS BatchCorr,
	|	UNDEFINED AS CorrOrder,
	|	UNDEFINED AS CorrOrganization,
	|	UNDEFINED AS StructuralUnitCorr,
	|	CASE
	|		WHEN SupplierInvoiceInventory.GoodsReceipt = VALUE(Document.GoodsReceipt.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE SupplierInvoiceInventory.GoodsReceivedNotInvoicedGLAccount
	|	END AS CorrGLAccount,
	|	SupplierInvoiceInventory.Ref.SetPaymentTerms AS SetPaymentTerms,
	|	SupplierInvoiceInventory.VATInputGLAccount AS VATInputGLAccount,
	|	SupplierInvoiceInventory.VATOutputGLAccount AS VATOutputGLAccount
	|INTO TemporaryTableInventory
	|FROM
	|	Document.SupplierInvoice.Inventory AS SupplierInvoiceInventory
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS ManagExchangeRates
	|		ON (ManagExchangeRates.Currency = &PresentationCurrency)
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS RegExchangeRates
	|		ON (RegExchangeRates.Currency = &CurrencyNational)
	|WHERE
	|	SupplierInvoiceInventory.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	PurchaseInvoiceExpenses.LineNumber AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	PurchaseInvoiceExpenses.Ref.Date AS Period,
	|	PurchaseInvoiceExpenses.Ref AS Document,
	|	&Company AS Company,
	|	PurchaseInvoiceExpenses.StructuralUnit AS StructuralUnit,
	|	PurchaseInvoiceExpenses.Ref.DocumentCurrency AS Currency,
	|	PurchaseInvoiceExpenses.InventoryGLAccount AS GLAccount,
	|	PurchaseInvoiceExpenses.Products AS Products,
	|	PurchaseInvoiceExpenses.Products.ProductsType AS ProductsType,
	|	VALUE(Catalog.Products.EmptyRef) AS InventoryProducts,
	|	VALUE(Catalog.ProductsCharacteristics.EmptyRef) AS Characteristic,
	|	VALUE(Catalog.ProductsBatches.EmptyRef) AS Batch,
	|	PurchaseInvoiceExpenses.Order AS Order,
	|	PurchaseInvoiceExpenses.PurchaseOrder AS PurchaseOrder,
	|	CASE
	|		WHEN VALUETYPE(PurchaseInvoiceExpenses.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN PurchaseInvoiceExpenses.Quantity
	|		ELSE PurchaseInvoiceExpenses.Quantity * PurchaseInvoiceExpenses.MeasurementUnit.Factor
	|	END AS Quantity,
	|	PurchaseInvoiceExpenses.VATRate AS VATRate,
	|	CAST(CASE
	|			WHEN PurchaseInvoiceExpenses.Ref.DocumentCurrency = &CurrencyNational
	|				THEN PurchaseInvoiceExpenses.Total * RegExchangeRates.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * RegExchangeRates.Multiplicity)
	|			ELSE PurchaseInvoiceExpenses.Total * PurchaseInvoiceExpenses.Ref.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * PurchaseInvoiceExpenses.Ref.Multiplicity)
	|		END AS NUMBER(15, 2)) AS Amount,
	|	CAST(CASE
	|			WHEN PurchaseInvoiceExpenses.Ref.DocumentCurrency = &CurrencyNational
	|				THEN PurchaseInvoiceExpenses.Total * RegExchangeRates.ExchangeRate * PurchaseInvoiceExpenses.Ref.Multiplicity / (PurchaseInvoiceExpenses.Ref.ExchangeRate * RegExchangeRates.Multiplicity)
	|			ELSE PurchaseInvoiceExpenses.Total
	|		END AS NUMBER(15, 2)) AS AmountCur,
	|	CAST(CASE
	|			WHEN PurchaseInvoiceExpenses.Ref.IncludeVATInPrice
	|				THEN 0
	|			ELSE CASE
	|					WHEN PurchaseInvoiceExpenses.Ref.DocumentCurrency = &CurrencyNational
	|						THEN PurchaseInvoiceExpenses.VATAmount * RegExchangeRates.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * RegExchangeRates.Multiplicity)
	|					ELSE PurchaseInvoiceExpenses.VATAmount * PurchaseInvoiceExpenses.Ref.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * PurchaseInvoiceExpenses.Ref.Multiplicity)
	|				END
	|		END AS NUMBER(15, 2)) AS VATAmount,
	|	CAST(CASE
	|			WHEN PurchaseInvoiceExpenses.Ref.IncludeVATInPrice
	|				THEN 0
	|			ELSE CASE
	|					WHEN PurchaseInvoiceExpenses.Ref.DocumentCurrency = &CurrencyNational
	|						THEN PurchaseInvoiceExpenses.VATAmount * RegExchangeRates.ExchangeRate * PurchaseInvoiceExpenses.Ref.Multiplicity / (PurchaseInvoiceExpenses.Ref.ExchangeRate * RegExchangeRates.Multiplicity)
	|					ELSE PurchaseInvoiceExpenses.VATAmount
	|				END
	|		END AS NUMBER(15, 2)) AS VATAmountCur,
	|	CAST(CASE
	|			WHEN PurchaseInvoiceExpenses.Ref.DocumentCurrency = &CurrencyNational
	|				THEN PurchaseInvoiceExpenses.VATAmount * RegExchangeRates.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * RegExchangeRates.Multiplicity)
	|			ELSE PurchaseInvoiceExpenses.VATAmount * PurchaseInvoiceExpenses.Ref.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * PurchaseInvoiceExpenses.Ref.Multiplicity)
	|		END AS NUMBER(15, 2)) AS AmountVATPurchaseSale,
	|	PurchaseInvoiceExpenses.Ref.IncludeExpensesInCostPrice AS IncludeExpensesInCostPrice,
	|	CASE
	|		WHEN PurchaseInvoiceExpenses.Products.ExpensesGLAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.Expenses)
	|				AND NOT PurchaseInvoiceExpenses.Ref.IncludeExpensesInCostPrice
	|			THEN PurchaseInvoiceExpenses.BusinessLine
	|		ELSE PurchaseInvoiceExpenses.Products.BusinessLine
	|	END AS BusinessLine,
	|	PurchaseInvoiceExpenses.Ref.Counterparty AS Counterparty,
	|	PurchaseInvoiceExpenses.Ref.Counterparty.DoOperationsByContracts AS DoOperationsByContracts,
	|	PurchaseInvoiceExpenses.Ref.Counterparty.DoOperationsByDocuments AS DoOperationsByDocuments,
	|	PurchaseInvoiceExpenses.Ref.Counterparty.DoOperationsByOrders AS DoOperationsByOrders,
	|	PurchaseInvoiceExpenses.Ref.Contract AS Contract,
	|	PurchaseInvoiceExpenses.Ref.Contract.SettlementsCurrency AS SettlementsCurrency,
	|	PurchaseInvoiceExpenses.Ref.Counterparty.GLAccountVendorSettlements AS GLAccountVendorSettlements,
	|	PurchaseInvoiceExpenses.Products.ExpensesGLAccount.TypeOfAccount AS TypeOfAccount,
	|	PurchaseInvoiceExpenses.Ref.ExchangeRate AS ExchangeRate,
	|	PurchaseInvoiceExpenses.Ref.Multiplicity AS Multiplicity,
	|	PurchaseInvoiceExpenses.Ref.VATTaxation AS VATTaxation,
	|	PurchaseInvoiceExpenses.ReverseChargeVATRate AS ReverseChargeVATRate,
	|	CAST(CASE
	|			WHEN NOT PurchaseInvoiceExpenses.Ref.VATTaxation = VALUE(Enum.VATTaxationTypes.ReverseChargeVAT)
	|				THEN 0
	|			WHEN PurchaseInvoiceExpenses.Ref.DocumentCurrency = &CurrencyNational
	|				THEN PurchaseInvoiceExpenses.ReverseChargeVATAmount * RegExchangeRates.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * RegExchangeRates.Multiplicity)
	|			ELSE PurchaseInvoiceExpenses.ReverseChargeVATAmount * PurchaseInvoiceExpenses.Ref.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * PurchaseInvoiceExpenses.Ref.Multiplicity)
	|		END AS NUMBER(15, 2)) AS ReverseChargeVATAmount,
	|	CAST(CASE
	|			WHEN NOT PurchaseInvoiceExpenses.Ref.VATTaxation = VALUE(Enum.VATTaxationTypes.ReverseChargeVAT)
	|				THEN 0
	|			WHEN PurchaseInvoiceExpenses.Ref.DocumentCurrency = &CurrencyNational
	|				THEN PurchaseInvoiceExpenses.ReverseChargeVATAmount * RegExchangeRates.ExchangeRate * PurchaseInvoiceExpenses.Ref.Multiplicity / (PurchaseInvoiceExpenses.Ref.ExchangeRate * RegExchangeRates.Multiplicity)
	|			ELSE PurchaseInvoiceExpenses.ReverseChargeVATAmount
	|		END AS NUMBER(15, 2)) AS ReverseChargeVATAmountCur,
	|	CAST(CASE
	|			WHEN NOT PurchaseInvoiceExpenses.Ref.VATTaxation = VALUE(Enum.VATTaxationTypes.ReverseChargeVAT)
	|					OR &RegisteredForVAT
	|				THEN 0
	|			WHEN PurchaseInvoiceExpenses.Ref.DocumentCurrency = &CurrencyNational
	|				THEN PurchaseInvoiceExpenses.ReverseChargeVATAmount * RegExchangeRates.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * RegExchangeRates.Multiplicity)
	|			ELSE PurchaseInvoiceExpenses.ReverseChargeVATAmount * PurchaseInvoiceExpenses.Ref.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * PurchaseInvoiceExpenses.Ref.Multiplicity)
	|		END AS NUMBER(15, 2)) AS ReverseChargeVATAmountForNotRegistered,
	|	CAST(CASE
	|			WHEN NOT PurchaseInvoiceExpenses.Ref.VATTaxation = VALUE(Enum.VATTaxationTypes.ReverseChargeVAT)
	|					OR &RegisteredForVAT
	|				THEN 0
	|			WHEN PurchaseInvoiceExpenses.Ref.DocumentCurrency = &CurrencyNational
	|				THEN PurchaseInvoiceExpenses.ReverseChargeVATAmount * RegExchangeRates.ExchangeRate * PurchaseInvoiceExpenses.Ref.Multiplicity / (PurchaseInvoiceExpenses.Ref.ExchangeRate * RegExchangeRates.Multiplicity)
	|			ELSE PurchaseInvoiceExpenses.ReverseChargeVATAmount
	|		END AS NUMBER(15, 2)) AS ReverseChargeVATAmountCurForNotRegistered,
	|	PurchaseInvoiceExpenses.Ref.SetPaymentTerms AS SetPaymentTerms,
	|	PurchaseInvoiceExpenses.VATInputGLAccount AS VATInputGLAccount,
	|	PurchaseInvoiceExpenses.VATOutputGLAccount AS VATOutputGLAccount
	|INTO TemporaryTableExpenses
	|FROM
	|	Document.SupplierInvoice.Expenses AS PurchaseInvoiceExpenses
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS ManagExchangeRates
	|		ON (ManagExchangeRates.Currency = &PresentationCurrency)
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS RegExchangeRates
	|		ON (RegExchangeRates.Currency = &CurrencyNational)
	|WHERE
	|	PurchaseInvoiceExpenses.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MAX(DocumentTable.LineNumber) AS LineNumber,
	|	DocumentTable.Ref.Date AS Period,
	|	&Company AS Company,
	|	DocumentTable.Ref.Counterparty AS Counterparty,
	|	DocumentTable.Ref.Counterparty.DoOperationsByContracts AS DoOperationsByContracts,
	|	DocumentTable.Ref.Counterparty.DoOperationsByDocuments AS DoOperationsByDocuments,
	|	DocumentTable.Ref.Counterparty.DoOperationsByOrders AS DoOperationsByOrders,
	|	DocumentTable.Ref.Counterparty.GLAccountCustomerSettlements AS GLAccountCustomerSettlements,
	|	DocumentTable.Ref.Counterparty.CustomerAdvancesGLAccount AS CustomerAdvancesGLAccount,
	|	DocumentTable.Ref.Counterparty.GLAccountVendorSettlements AS GLAccountVendorSettlements,
	|	DocumentTable.Ref.Counterparty.VendorAdvancesGLAccount AS VendorAdvancesGLAccount,
	|	DocumentTable.Ref.Contract AS Contract,
	|	DocumentTable.Ref.Contract.SettlementsCurrency AS SettlementsCurrency,
	|	DocumentTable.Order AS Order,
	|	VALUE(Catalog.LinesOfBusiness.Other) AS BusinessLineSales,
	|	VALUE(Enum.SettlementsTypes.Advance) AS SettlementsType,
	|	VALUE(Enum.SettlementsTypes.Debt) AS SettlemensTypeWhere,
	|	&Ref AS DocumentWhere,
	|	DocumentTable.Document AS Document,
	|	DocumentTable.Ref.BasisDocument AS BasisDocument,
	|	CASE
	|		WHEN NOT DocumentTable.Ref.Counterparty.DoOperationsByDocuments
	|				OR VALUETYPE(DocumentTable.Document) = TYPE(Document.ExpenseReport)
	|				OR VALUETYPE(DocumentTable.Document) = TYPE(Document.ArApAdjustments)
	|			THEN VALUE(Catalog.CashFlowItems.PaymentToVendor)
	|		ELSE CASE
	|				WHEN DocumentTable.Document REFS Document.PaymentExpense
	|					THEN CAST(DocumentTable.Document AS Document.PaymentExpense).Item
	|				WHEN DocumentTable.Document REFS Document.PaymentReceipt
	|					THEN CAST(DocumentTable.Document AS Document.PaymentReceipt).Item
	|				WHEN DocumentTable.Document REFS Document.CashReceipt
	|					THEN CAST(DocumentTable.Document AS Document.CashReceipt).Item
	|				WHEN DocumentTable.Document REFS Document.CashVoucher
	|					THEN CAST(DocumentTable.Document AS Document.CashVoucher).Item
	|				ELSE VALUE(Catalog.CashFlowItems.PaymentToVendor)
	|			END
	|	END AS Item,
	|	CASE
	|		WHEN DocumentTable.Ref.Counterparty.DoOperationsByDocuments
	|			THEN CASE
	|					WHEN DocumentTable.Document REFS Document.PaymentExpense
	|						THEN CAST(DocumentTable.Document AS Document.PaymentExpense).Date
	|					WHEN DocumentTable.Document REFS Document.PaymentReceipt
	|						THEN CAST(DocumentTable.Document AS Document.PaymentReceipt).Date
	|					WHEN DocumentTable.Document REFS Document.CashReceipt
	|						THEN CAST(DocumentTable.Document AS Document.CashReceipt).Date
	|					WHEN DocumentTable.Document REFS Document.CashVoucher
	|						THEN CAST(DocumentTable.Document AS Document.CashVoucher).Date
	|					WHEN DocumentTable.Document REFS Document.ExpenseReport
	|						THEN CAST(DocumentTable.Document AS Document.ExpenseReport).Date
	|					WHEN DocumentTable.Document REFS Document.ArApAdjustments
	|						THEN CAST(DocumentTable.Document AS Document.ArApAdjustments).Date
	|				END
	|		ELSE DocumentTable.Ref.Date
	|	END AS DocumentDate,
	|	SUM(CAST(DocumentTable.SettlementsAmount * DocumentTable.Ref.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * DocumentTable.Ref.Multiplicity) AS NUMBER(15, 2))) AS Amount,
	|	SUM(DocumentTable.SettlementsAmount) AS AmountCur,
	|	DocumentTable.Ref.SetPaymentTerms AS SetPaymentTerms
	|INTO TemporaryTablePrepayment
	|FROM
	|	Document.SupplierInvoice.Prepayment AS DocumentTable
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS AccountingExchangeRatesSliceLast
	|		ON (AccountingExchangeRatesSliceLast.Currency = &PresentationCurrency)
	|WHERE
	|	DocumentTable.Ref = &Ref
	|
	|GROUP BY
	|	DocumentTable.Ref,
	|	DocumentTable.Document,
	|	DocumentTable.Ref.Date,
	|	DocumentTable.Ref.Counterparty,
	|	DocumentTable.Ref.Contract,
	|	DocumentTable.Order,
	|	DocumentTable.Ref.Contract.SettlementsCurrency,
	|	DocumentTable.Ref.Counterparty.GLAccountCustomerSettlements,
	|	DocumentTable.Ref.Counterparty.CustomerAdvancesGLAccount,
	|	DocumentTable.Ref.Counterparty.GLAccountVendorSettlements,
	|	DocumentTable.Ref.Counterparty.VendorAdvancesGLAccount,
	|	DocumentTable.Ref.BasisDocument,
	|	CASE
	|		WHEN NOT DocumentTable.Ref.Counterparty.DoOperationsByDocuments
	|				OR VALUETYPE(DocumentTable.Document) = TYPE(Document.ExpenseReport)
	|				OR VALUETYPE(DocumentTable.Document) = TYPE(Document.ArApAdjustments)
	|			THEN VALUE(Catalog.CashFlowItems.PaymentToVendor)
	|		ELSE CASE
	|				WHEN DocumentTable.Document REFS Document.PaymentExpense
	|					THEN CAST(DocumentTable.Document AS Document.PaymentExpense).Item
	|				WHEN DocumentTable.Document REFS Document.PaymentReceipt
	|					THEN CAST(DocumentTable.Document AS Document.PaymentReceipt).Item
	|				WHEN DocumentTable.Document REFS Document.CashReceipt
	|					THEN CAST(DocumentTable.Document AS Document.CashReceipt).Item
	|				WHEN DocumentTable.Document REFS Document.CashVoucher
	|					THEN CAST(DocumentTable.Document AS Document.CashVoucher).Item
	|				ELSE VALUE(Catalog.CashFlowItems.PaymentToVendor)
	|			END
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.Counterparty.DoOperationsByDocuments
	|			THEN CASE
	|					WHEN DocumentTable.Document REFS Document.PaymentExpense
	|						THEN CAST(DocumentTable.Document AS Document.PaymentExpense).Date
	|					WHEN DocumentTable.Document REFS Document.PaymentReceipt
	|						THEN CAST(DocumentTable.Document AS Document.PaymentReceipt).Date
	|					WHEN DocumentTable.Document REFS Document.CashReceipt
	|						THEN CAST(DocumentTable.Document AS Document.CashReceipt).Date
	|					WHEN DocumentTable.Document REFS Document.CashVoucher
	|						THEN CAST(DocumentTable.Document AS Document.CashVoucher).Date
	|					WHEN DocumentTable.Document REFS Document.ExpenseReport
	|						THEN CAST(DocumentTable.Document AS Document.ExpenseReport).Date
	|					WHEN DocumentTable.Document REFS Document.ArApAdjustments
	|						THEN CAST(DocumentTable.Document AS Document.ArApAdjustments).Date
	|				END
	|		ELSE DocumentTable.Ref.Date
	|	END,
	|	DocumentTable.Ref.Counterparty.DoOperationsByContracts,
	|	DocumentTable.Ref.Counterparty.DoOperationsByDocuments,
	|	DocumentTable.Ref.Counterparty.DoOperationsByOrders,
	|	DocumentTable.Ref.SetPaymentTerms
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SalesInvoiceSerialNumbers.ConnectionKey AS ConnectionKey,
	|	SalesInvoiceSerialNumbers.SerialNumber AS SerialNumber
	|INTO TemporaryTableSerialNumbers
	|FROM
	|	Document.SupplierInvoice.SerialNumbers AS SalesInvoiceSerialNumbers
	|WHERE
	|	SalesInvoiceSerialNumbers.Ref = &Ref
	|	AND &UseSerialNumbers
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Header.Company AS Company,
	|	Header.Date AS Period,
	|	Header.Counterparty AS Customer,
	|	PrepaymentVAT.Document AS ShipmentDocument,
	|	PrepaymentVAT.VATRate AS VATRate,
	|	SUM(PrepaymentVAT.VATAmount) AS VATAmount,
	|	SUM(PrepaymentVAT.AmountExcludesVAT) AS AmountExcludesVAT,
	|	PrepaymentVAT.Ref.SetPaymentTerms AS SetPaymentTerms
	|INTO TemporaryTablePrepaymentVAT
	|FROM
	|	Document.SupplierInvoice.PrepaymentVAT AS PrepaymentVAT
	|		INNER JOIN SupplierInvoiceHeader AS Header
	|		ON PrepaymentVAT.Ref = Header.Ref
	|WHERE
	|	NOT PrepaymentVAT.VATRate.NotTaxable
	|
	|GROUP BY
	|	Header.Company,
	|	Header.Date,
	|	Header.Counterparty,
	|	PrepaymentVAT.Document,
	|	PrepaymentVAT.VATRate,
	|	PrepaymentVAT.Ref.SetPaymentTerms
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	PrepaymentVAT.ShipmentDocument AS ShipmentDocument
	|INTO PrepaymentWithoutInvoice
	|FROM
	|	TemporaryTablePrepaymentVAT AS PrepaymentVAT
	|		LEFT JOIN Document.TaxInvoiceReceived.BasisDocuments AS PrepaymentDocuments
	|		ON PrepaymentVAT.ShipmentDocument = PrepaymentDocuments.BasisDocument
	|WHERE
	|	PrepaymentDocuments.BasisDocument IS NULL
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	PrepaymentVAT.ShipmentDocument AS ShipmentDocument
	|INTO PrepaymentPostBySourceDocuments
	|FROM
	|	TemporaryTablePrepaymentVAT AS PrepaymentVAT
	|		INNER JOIN AccumulationRegister.VATInput AS VATInput
	|		ON PrepaymentVAT.ShipmentDocument = VATInput.Recorder
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SupplierInvoicePaymentCalendar.LineNumber AS LineNumber,
	|	SupplierInvoicePaymentCalendar.Ref AS Ref,
	|	SupplierInvoicePaymentCalendar.PaymentDate AS PaymentDate,
	|	SupplierInvoicePaymentCalendar.PaymentAmount AS PaymentAmount,
	|	SupplierInvoicePaymentCalendar.PaymentVATAmount AS PaymentVATAmount
	|INTO TemporaryTablePaymentCalendarWithoutGroup
	|FROM
	|	Document.SupplierInvoice.PaymentCalendar AS SupplierInvoicePaymentCalendar
	|WHERE
	|	SupplierInvoicePaymentCalendar.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Calendar.LineNumber AS LineNumber,
	|	Calendar.PaymentDate AS Period,
	|	&Company AS Company,
	|	SupplierInvoice.Counterparty AS Counterparty,
	|	CounterpartyRef.DoOperationsByContracts AS DoOperationsByContracts,
	|	CounterpartyRef.DoOperationsByDocuments AS DoOperationsByDocuments,
	|	CounterpartyRef.DoOperationsByOrders AS DoOperationsByOrders,
	|	CounterpartyRef.GLAccountCustomerSettlements AS GLAccountCustomerSettlements,
	|	SupplierInvoice.Contract AS Contract,
	|	CounterpartyContractsRef.SettlementsCurrency AS SettlementsCurrency,
	|	&Ref AS DocumentWhere,
	|	VALUE(Enum.SettlementsTypes.Debt) AS SettlemensTypeWhere,
	|	CASE
	|		WHEN VALUETYPE(SupplierInvoice.BasisDocument) = TYPE(Document.PurchaseOrder)
	|			THEN SupplierInvoice.BasisDocument
	|		ELSE VALUE(Document.PurchaseOrder.EmptyRef)
	|	END AS Order,
	|	CASE
	|		WHEN SupplierInvoice.AmountIncludesVAT
	|			THEN CAST(Calendar.PaymentAmount * SupplierInvoice.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * SupplierInvoice.Multiplicity) AS NUMBER(15, 2))
	|		ELSE CAST((Calendar.PaymentAmount + Calendar.PaymentVATAmount) * SupplierInvoice.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * SupplierInvoice.Multiplicity) AS NUMBER(15, 2))
	|	END AS Amount,
	|	CASE
	|		WHEN SupplierInvoice.AmountIncludesVAT
	|			THEN Calendar.PaymentAmount
	|		ELSE Calendar.PaymentAmount + Calendar.PaymentVATAmount
	|	END AS AmountCur
	|INTO TemporaryTablePaymentCalendarWithoutGroupWithHeader
	|FROM
	|	TemporaryTablePaymentCalendarWithoutGroup AS Calendar
	|		INNER JOIN Document.SupplierInvoice AS SupplierInvoice
	|		ON (SupplierInvoice.Ref = Calendar.Ref)
	|		LEFT JOIN Catalog.Counterparties AS CounterpartyRef
	|		ON (CounterpartyRef.Ref = SupplierInvoice.Counterparty)
	|		LEFT JOIN Catalog.CounterpartyContracts AS CounterpartyContractsRef
	|		ON (CounterpartyContractsRef.Ref = SupplierInvoice.Contract)
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(
	|				&PointInTime,
	|				Currency IN
	|					(SELECT
	|						ConstantAccountingCurrency.Value
	|					FROM
	|						Constant.PresentationCurrency AS ConstantAccountingCurrency)) AS AccountingExchangeRatesSliceLast
	|		ON (TRUE)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MAX(Calendar.LineNumber) AS LineNumber,
	|	Calendar.Period AS Period,
	|	Calendar.Company AS Company,
	|	Calendar.Counterparty AS Counterparty,
	|	Calendar.DoOperationsByContracts AS DoOperationsByContracts,
	|	Calendar.DoOperationsByDocuments AS DoOperationsByDocuments,
	|	Calendar.DoOperationsByOrders AS DoOperationsByOrders,
	|	Calendar.GLAccountCustomerSettlements AS GLAccountCustomerSettlements,
	|	Calendar.Contract AS Contract,
	|	Calendar.SettlementsCurrency AS SettlementsCurrency,
	|	Calendar.DocumentWhere AS DocumentWhere,
	|	Calendar.SettlemensTypeWhere AS SettlemensTypeWhere,
	|	Calendar.Order AS Order,
	|	SUM(Calendar.Amount) AS Amount,
	|	SUM(Calendar.AmountCur) AS AmountCur
	|INTO TemporaryTablePaymentCalendar
	|FROM
	|	TemporaryTablePaymentCalendarWithoutGroupWithHeader AS Calendar
	|
	|GROUP BY
	|	Calendar.Period,
	|	Calendar.Company,
	|	Calendar.Counterparty,
	|	Calendar.DoOperationsByContracts,
	|	Calendar.DoOperationsByDocuments,
	|	Calendar.DoOperationsByOrders,
	|	Calendar.GLAccountCustomerSettlements,
	|	Calendar.Contract,
	|	Calendar.SettlementsCurrency,
	|	Calendar.DocumentWhere,
	|	Calendar.SettlemensTypeWhere,
	|	Calendar.Order
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP TemporaryTablePaymentCalendarWithoutGroup
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP TemporaryTablePaymentCalendarWithoutGroupWithHeader";
	
	Query.SetParameter("Ref",					DocumentRefPurchaseInvoice);
	Query.SetParameter("Company",				StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PointInTime",			New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("UseCharacteristics",	StructureAdditionalProperties.AccountingPolicy.UseCharacteristics);
	Query.SetParameter("UseBatches",			StructureAdditionalProperties.AccountingPolicy.UseBatches);
	Query.SetParameter("UseStorageBins",		StructureAdditionalProperties.AccountingPolicy.UseStorageBins);
	Query.SetParameter("UseSerialNumbers",		StructureAdditionalProperties.AccountingPolicy.UseSerialNumbers);
	Query.SetParameter("PresentationCurrency",	Constants.PresentationCurrency.Get());
	Query.SetParameter("CurrencyNational",		Constants.FunctionalCurrency.Get());
	Query.SetParameter("RegisteredForVAT",		StructureAdditionalProperties.AccountingPolicy.RegisteredForVAT);
	
	Query.SetParameter("InventoryIncrease",
		NStr("en = 'Inventory receipt'",
			StructureAdditionalProperties.DefaultLanguageCode));
	
	Query.SetParameter("InventoryWriteOff",
		NStr("en = 'Inventory write-off'",
			StructureAdditionalProperties.DefaultLanguageCode));
	
	Query.ExecuteBatch();
	
	DocumentAttributes = CommonUse.ObjectAttributeValues(DocumentRefPurchaseInvoice, "VATTaxation, Counterparty, DiscountCard");
	StructureAdditionalProperties.Insert("DocumentAttributes", DocumentAttributes);
	
	// Creation of document postings.
	DriveServer.GenerateTransactionsTable(DocumentRefPurchaseInvoice, StructureAdditionalProperties);
	
	GenerateTablePurchases(DocumentRefPurchaseInvoice, StructureAdditionalProperties);
	GenerateTableInventoryInWarehouses(DocumentRefPurchaseInvoice, StructureAdditionalProperties);
	GenerateTableGoodsAwaitingCustomsClearance(DocumentRefPurchaseInvoice, StructureAdditionalProperties);
	GenerateTablePurchaseOrders(DocumentRefPurchaseInvoice, StructureAdditionalProperties);
	GenerateTableGoodsReceivedNotInvoiced(DocumentRefPurchaseInvoice, StructureAdditionalProperties);
	GenerateTableBackorders(DocumentRefPurchaseInvoice, StructureAdditionalProperties);
	GenerateTableInventory(DocumentRefPurchaseInvoice, StructureAdditionalProperties);
	GenerateTableAccountsPayable(DocumentRefPurchaseInvoice, StructureAdditionalProperties);
	GenerateTableIncomeAndExpenses(DocumentRefPurchaseInvoice, StructureAdditionalProperties);
	GenerateTableIncomeAndExpensesRetained(DocumentRefPurchaseInvoice, StructureAdditionalProperties);
	GenerateTableUnallocatedExpenses(DocumentRefPurchaseInvoice, StructureAdditionalProperties);
	GenerateTableIncomeAndExpensesCashMethod(DocumentRefPurchaseInvoice, StructureAdditionalProperties);
	GenerateTablePOSSummary(DocumentRefPurchaseInvoice, StructureAdditionalProperties);
	GenerateTableInventoryCostLayer(DocumentRefPurchaseInvoice, StructureAdditionalProperties);
	GenerateTablePaymentCalendar(DocumentRefPurchaseInvoice, StructureAdditionalProperties);
	
	GenerateTableAccountingJournalEntries(DocumentRefPurchaseInvoice, StructureAdditionalProperties);
	
	// Serial numbers
	GenerateTableSerialNumbers(DocumentRefPurchaseInvoice, StructureAdditionalProperties);
	
	//VAT
	GenerateTableVATIncurred(DocumentRefPurchaseInvoice, StructureAdditionalProperties);
	GenerateTableVATInput(DocumentRefPurchaseInvoice, StructureAdditionalProperties);
	GenerateTableVATOutput(DocumentRefPurchaseInvoice, StructureAdditionalProperties);
	GenerateTableTaxPayable(DocumentRefPurchaseInvoice, StructureAdditionalProperties);
	
EndProcedure

// Controls the occurrence of negative balances.
//
Procedure RunControl(DocumentRefPurchaseInvoice, AdditionalProperties, Cancel, PostingDelete = False) Export
	
	If Not DriveServer.RunBalanceControl() Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	If StructureTemporaryTables.RegisterRecordsInventoryChange
		OR StructureTemporaryTables.RegisterRecordsInventoryInWarehousesChange
		OR StructureTemporaryTables.RegisterRecordsBackordersChange
		OR StructureTemporaryTables.RegisterRecordsSalesOrdersChange
		OR StructureTemporaryTables.RegisterRecordsPurchaseOrdersChange
		OR StructureTemporaryTables.RegisterRecordsInventoryDemandChange
		OR StructureTemporaryTables.RegisterRecordsSuppliersSettlementsChange
		OR StructureTemporaryTables.RegisterRecordsPOSSummaryUpdate
		OR StructureTemporaryTables.RegisterRecordsVATIncurredChange
		OR StructureTemporaryTables.RegisterRecordsGoodsReceivedNotInvoicedChange
		OR StructureTemporaryTables.RegisterRecordsGoodsAwaitingCustomsClearanceChange Then
		
		Query = New Query(
		"SELECT
		|	RegisterRecordsInventoryInWarehousesChange.LineNumber AS LineNumber,
		|	RegisterRecordsInventoryInWarehousesChange.Company AS CompanyPresentation,
		|	RegisterRecordsInventoryInWarehousesChange.StructuralUnit AS StructuralUnitPresentation,
		|	RegisterRecordsInventoryInWarehousesChange.Products AS ProductsPresentation,
		|	RegisterRecordsInventoryInWarehousesChange.Characteristic AS CharacteristicPresentation,
		|	RegisterRecordsInventoryInWarehousesChange.Batch AS BatchPresentation,
		|	RegisterRecordsInventoryInWarehousesChange.Cell AS PresentationCell,
		|	InventoryInWarehousesOfBalance.StructuralUnit.StructuralUnitType AS StructuralUnitType,
		|	InventoryInWarehousesOfBalance.Products.MeasurementUnit AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsInventoryInWarehousesChange.QuantityChange, 0) + ISNULL(InventoryInWarehousesOfBalance.QuantityBalance, 0) AS BalanceInventoryInWarehouses,
		|	ISNULL(InventoryInWarehousesOfBalance.QuantityBalance, 0) AS QuantityBalanceInventoryInWarehouses
		|FROM
		|	RegisterRecordsInventoryInWarehousesChange AS RegisterRecordsInventoryInWarehousesChange
		|		INNER JOIN AccumulationRegister.InventoryInWarehouses.Balance(&ControlTime, ) AS InventoryInWarehousesOfBalance
		|		ON RegisterRecordsInventoryInWarehousesChange.Company = InventoryInWarehousesOfBalance.Company
		|			AND RegisterRecordsInventoryInWarehousesChange.StructuralUnit = InventoryInWarehousesOfBalance.StructuralUnit
		|			AND RegisterRecordsInventoryInWarehousesChange.Products = InventoryInWarehousesOfBalance.Products
		|			AND RegisterRecordsInventoryInWarehousesChange.Characteristic = InventoryInWarehousesOfBalance.Characteristic
		|			AND RegisterRecordsInventoryInWarehousesChange.Batch = InventoryInWarehousesOfBalance.Batch
		|			AND RegisterRecordsInventoryInWarehousesChange.Cell = InventoryInWarehousesOfBalance.Cell
		|			AND (ISNULL(InventoryInWarehousesOfBalance.QuantityBalance, 0) < 0)
		|
		|ORDER BY
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	RegisterRecordsInventoryChange.LineNumber AS LineNumber,
		|	RegisterRecordsInventoryChange.Company AS CompanyPresentation,
		|	RegisterRecordsInventoryChange.StructuralUnit AS StructuralUnitPresentation,
		|	RegisterRecordsInventoryChange.GLAccount AS GLAccountPresentation,
		|	RegisterRecordsInventoryChange.Products AS ProductsPresentation,
		|	RegisterRecordsInventoryChange.Characteristic AS CharacteristicPresentation,
		|	RegisterRecordsInventoryChange.Batch AS BatchPresentation,
		|	RegisterRecordsInventoryChange.SalesOrder AS SalesOrderPresentation,
		|	InventoryBalances.StructuralUnit.StructuralUnitType AS StructuralUnitType,
		|	InventoryBalances.Products.MeasurementUnit AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsInventoryChange.QuantityChange, 0) + ISNULL(InventoryBalances.QuantityBalance, 0) AS BalanceInventory,
		|	ISNULL(InventoryBalances.QuantityBalance, 0) AS QuantityBalanceInventory,
		|	ISNULL(InventoryBalances.AmountBalance, 0) AS AmountBalanceInventory
		|FROM
		|	RegisterRecordsInventoryChange AS RegisterRecordsInventoryChange
		|		INNER JOIN AccumulationRegister.Inventory.Balance(&ControlTime, ) AS InventoryBalances
		|		ON RegisterRecordsInventoryChange.Company = InventoryBalances.Company
		|			AND RegisterRecordsInventoryChange.StructuralUnit = InventoryBalances.StructuralUnit
		|			AND RegisterRecordsInventoryChange.GLAccount = InventoryBalances.GLAccount
		|			AND RegisterRecordsInventoryChange.Products = InventoryBalances.Products
		|			AND RegisterRecordsInventoryChange.Characteristic = InventoryBalances.Characteristic
		|			AND RegisterRecordsInventoryChange.Batch = InventoryBalances.Batch
		|			AND RegisterRecordsInventoryChange.SalesOrder = InventoryBalances.SalesOrder
		|			AND (ISNULL(InventoryBalances.QuantityBalance, 0) < 0)
		|
		|ORDER BY
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	RegisterRecordsSalesOrdersChange.LineNumber AS LineNumber,
		|	RegisterRecordsSalesOrdersChange.Company AS CompanyPresentation,
		|	RegisterRecordsSalesOrdersChange.SalesOrder AS OrderPresentation,
		|	RegisterRecordsSalesOrdersChange.Products AS ProductsPresentation,
		|	RegisterRecordsSalesOrdersChange.Characteristic AS CharacteristicPresentation,
		|	SalesOrdersBalances.Products.MeasurementUnit AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsSalesOrdersChange.QuantityChange, 0) + ISNULL(SalesOrdersBalances.QuantityBalance, 0) AS BalanceSalesOrders,
		|	ISNULL(SalesOrdersBalances.QuantityBalance, 0) AS QuantityBalanceSalesOrders
		|FROM
		|	RegisterRecordsSalesOrdersChange AS RegisterRecordsSalesOrdersChange
		|		INNER JOIN AccumulationRegister.SalesOrders.Balance(&ControlTime, ) AS SalesOrdersBalances
		|		ON RegisterRecordsSalesOrdersChange.Company = SalesOrdersBalances.Company
		|			AND RegisterRecordsSalesOrdersChange.SalesOrder = SalesOrdersBalances.SalesOrder
		|			AND RegisterRecordsSalesOrdersChange.Products = SalesOrdersBalances.Products
		|			AND RegisterRecordsSalesOrdersChange.Characteristic = SalesOrdersBalances.Characteristic
		|			AND (ISNULL(SalesOrdersBalances.QuantityBalance, 0) < 0)
		|
		|ORDER BY
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	RegisterRecordsPurchaseOrdersChange.LineNumber AS LineNumber,
		|	RegisterRecordsPurchaseOrdersChange.Company AS CompanyPresentation,
		|	RegisterRecordsPurchaseOrdersChange.PurchaseOrder AS PurchaseOrderPresentation,
		|	RegisterRecordsPurchaseOrdersChange.Products AS ProductsPresentation,
		|	RegisterRecordsPurchaseOrdersChange.Characteristic AS CharacteristicPresentation,
		|	PurchaseOrdersBalances.Products.MeasurementUnit AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsPurchaseOrdersChange.QuantityChange, 0) + ISNULL(PurchaseOrdersBalances.QuantityBalance, 0) AS BalancePurchaseOrders,
		|	ISNULL(PurchaseOrdersBalances.QuantityBalance, 0) AS QuantityBalancePurchaseOrders
		|FROM
		|	RegisterRecordsPurchaseOrdersChange AS RegisterRecordsPurchaseOrdersChange
		|		INNER JOIN AccumulationRegister.PurchaseOrders.Balance(&ControlTime, ) AS PurchaseOrdersBalances
		|		ON RegisterRecordsPurchaseOrdersChange.Company = PurchaseOrdersBalances.Company
		|			AND RegisterRecordsPurchaseOrdersChange.PurchaseOrder = PurchaseOrdersBalances.PurchaseOrder
		|			AND RegisterRecordsPurchaseOrdersChange.Products = PurchaseOrdersBalances.Products
		|			AND RegisterRecordsPurchaseOrdersChange.Characteristic = PurchaseOrdersBalances.Characteristic
		|			AND (ISNULL(PurchaseOrdersBalances.QuantityBalance, 0) < 0)
		|
		|ORDER BY
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	RegisterRecordsInventoryDemandChange.LineNumber AS LineNumber,
		|	RegisterRecordsInventoryDemandChange.Company AS CompanyPresentation,
		|	RegisterRecordsInventoryDemandChange.MovementType AS MovementTypePresentation,
		|	RegisterRecordsInventoryDemandChange.SalesOrder AS SalesOrderPresentation,
		|	RegisterRecordsInventoryDemandChange.Products AS ProductsPresentation,
		|	RegisterRecordsInventoryDemandChange.Characteristic AS CharacteristicPresentation,
		|	InventoryDemandBalances.Products.MeasurementUnit AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsInventoryDemandChange.QuantityChange, 0) + ISNULL(InventoryDemandBalances.QuantityBalance, 0) AS BalanceInventoryDemand,
		|	ISNULL(InventoryDemandBalances.QuantityBalance, 0) AS QuantityBalanceInventoryDemand
		|FROM
		|	RegisterRecordsInventoryDemandChange AS RegisterRecordsInventoryDemandChange
		|		INNER JOIN AccumulationRegister.InventoryDemand.Balance(&ControlTime, ) AS InventoryDemandBalances
		|		ON RegisterRecordsInventoryDemandChange.Company = InventoryDemandBalances.Company
		|			AND RegisterRecordsInventoryDemandChange.MovementType = InventoryDemandBalances.MovementType
		|			AND RegisterRecordsInventoryDemandChange.SalesOrder = InventoryDemandBalances.SalesOrder
		|			AND RegisterRecordsInventoryDemandChange.Products = InventoryDemandBalances.Products
		|			AND RegisterRecordsInventoryDemandChange.Characteristic = InventoryDemandBalances.Characteristic
		|			AND (ISNULL(InventoryDemandBalances.QuantityBalance, 0) < 0)
		|
		|ORDER BY
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	RegisterRecordsBackordersChange.LineNumber AS LineNumber,
		|	RegisterRecordsBackordersChange.Company AS CompanyPresentation,
		|	RegisterRecordsBackordersChange.SalesOrder AS SalesOrderPresentation,
		|	RegisterRecordsBackordersChange.Products AS ProductsPresentation,
		|	RegisterRecordsBackordersChange.Characteristic AS CharacteristicPresentation,
		|	RegisterRecordsBackordersChange.SupplySource AS SupplySourcePresentation,
		|	BackordersBalances.Products.MeasurementUnit AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsBackordersChange.QuantityChange, 0) + ISNULL(BackordersBalances.QuantityBalance, 0) AS BalanceBackorders,
		|	ISNULL(BackordersBalances.QuantityBalance, 0) AS QuantityBalanceBackorders
		|FROM
		|	RegisterRecordsBackordersChange AS RegisterRecordsBackordersChange
		|		INNER JOIN AccumulationRegister.Backorders.Balance(&ControlTime, ) AS BackordersBalances
		|		ON RegisterRecordsBackordersChange.Company = BackordersBalances.Company
		|			AND RegisterRecordsBackordersChange.SalesOrder = BackordersBalances.SalesOrder
		|			AND RegisterRecordsBackordersChange.Products = BackordersBalances.Products
		|			AND RegisterRecordsBackordersChange.Characteristic = BackordersBalances.Characteristic
		|			AND RegisterRecordsBackordersChange.SupplySource = BackordersBalances.SupplySource
		|			AND (ISNULL(BackordersBalances.QuantityBalance, 0) < 0)
		|
		|ORDER BY
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	RegisterRecordsSuppliersSettlementsChange.LineNumber AS LineNumber,
		|	RegisterRecordsSuppliersSettlementsChange.Company AS CompanyPresentation,
		|	RegisterRecordsSuppliersSettlementsChange.Counterparty AS CounterpartyPresentation,
		|	RegisterRecordsSuppliersSettlementsChange.Contract AS ContractPresentation,
		|	RegisterRecordsSuppliersSettlementsChange.Contract.SettlementsCurrency AS CurrencyPresentation,
		|	RegisterRecordsSuppliersSettlementsChange.Document AS DocumentPresentation,
		|	RegisterRecordsSuppliersSettlementsChange.Order AS OrderPresentation,
		|	RegisterRecordsSuppliersSettlementsChange.SettlementsType AS CalculationsTypesPresentation,
		|	FALSE AS RegisterRecordsOfCashDocuments,
		|	RegisterRecordsSuppliersSettlementsChange.SumBeforeWrite AS SumBeforeWrite,
		|	RegisterRecordsSuppliersSettlementsChange.AmountOnWrite AS AmountOnWrite,
		|	RegisterRecordsSuppliersSettlementsChange.AmountChange AS AmountChange,
		|	RegisterRecordsSuppliersSettlementsChange.AmountCurBeforeWrite AS AmountCurBeforeWrite,
		|	RegisterRecordsSuppliersSettlementsChange.SumCurOnWrite AS SumCurOnWrite,
		|	RegisterRecordsSuppliersSettlementsChange.SumCurChange AS SumCurChange,
		|	RegisterRecordsSuppliersSettlementsChange.SumCurOnWrite - ISNULL(AccountsPayableBalances.AmountCurBalance, 0) AS AdvanceAmountsPaid,
		|	RegisterRecordsSuppliersSettlementsChange.SumCurChange + ISNULL(AccountsPayableBalances.AmountCurBalance, 0) AS AmountOfOutstandingDebt,
		|	ISNULL(AccountsPayableBalances.AmountBalance, 0) AS AmountBalance,
		|	ISNULL(AccountsPayableBalances.AmountCurBalance, 0) AS AmountCurBalance,
		|	RegisterRecordsSuppliersSettlementsChange.SettlementsType AS SettlementsType
		|FROM
		|	RegisterRecordsSuppliersSettlementsChange AS RegisterRecordsSuppliersSettlementsChange
		|		INNER JOIN AccumulationRegister.AccountsPayable.Balance(&ControlTime, ) AS AccountsPayableBalances
		|		ON RegisterRecordsSuppliersSettlementsChange.Company = AccountsPayableBalances.Company
		|			AND RegisterRecordsSuppliersSettlementsChange.Counterparty = AccountsPayableBalances.Counterparty
		|			AND RegisterRecordsSuppliersSettlementsChange.Contract = AccountsPayableBalances.Contract
		|			AND RegisterRecordsSuppliersSettlementsChange.Document = AccountsPayableBalances.Document
		|			AND RegisterRecordsSuppliersSettlementsChange.Order = AccountsPayableBalances.Order
		|			AND RegisterRecordsSuppliersSettlementsChange.SettlementsType = AccountsPayableBalances.SettlementsType
		|			AND (CASE
		|				WHEN RegisterRecordsSuppliersSettlementsChange.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)
		|					THEN ISNULL(AccountsPayableBalances.AmountCurBalance, 0) > 0
		|				ELSE ISNULL(AccountsPayableBalances.AmountCurBalance, 0) < 0
		|			END)
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	RegisterRecordsPOSSummaryUpdate.LineNumber AS LineNumber,
		|	RegisterRecordsPOSSummaryUpdate.Company AS CompanyPresentation,
		|	RegisterRecordsPOSSummaryUpdate.StructuralUnit AS StructuralUnitPresentation,
		|	RegisterRecordsPOSSummaryUpdate.StructuralUnit.RetailPriceKind.PriceCurrency AS CurrencyPresentation,
		|	ISNULL(POSSummaryBalances.AmountBalance, 0) AS AmountBalance,
		|	RegisterRecordsPOSSummaryUpdate.SumCurChange + ISNULL(POSSummaryBalances.AmountCurBalance, 0) AS BalanceInRetail,
		|	RegisterRecordsPOSSummaryUpdate.SumBeforeWrite AS SumBeforeWrite,
		|	RegisterRecordsPOSSummaryUpdate.AmountOnWrite AS AmountOnWrite,
		|	RegisterRecordsPOSSummaryUpdate.AmountChange AS AmountChange,
		|	RegisterRecordsPOSSummaryUpdate.AmountCurBeforeWrite AS AmountCurBeforeWrite,
		|	RegisterRecordsPOSSummaryUpdate.SumCurOnWrite AS SumCurOnWrite,
		|	RegisterRecordsPOSSummaryUpdate.SumCurChange AS SumCurChange,
		|	RegisterRecordsPOSSummaryUpdate.CostBeforeWrite AS CostBeforeWrite,
		|	RegisterRecordsPOSSummaryUpdate.CostOnWrite AS CostOnWrite,
		|	RegisterRecordsPOSSummaryUpdate.CostUpdate AS CostUpdate
		|FROM
		|	RegisterRecordsPOSSummaryUpdate AS RegisterRecordsPOSSummaryUpdate
		|		INNER JOIN AccumulationRegister.POSSummary.Balance(&ControlTime, ) AS POSSummaryBalances
		|		ON RegisterRecordsPOSSummaryUpdate.Company = POSSummaryBalances.Company
		|			AND RegisterRecordsPOSSummaryUpdate.StructuralUnit = POSSummaryBalances.StructuralUnit
		|			AND (ISNULL(POSSummaryBalances.AmountCurBalance, 0) < 0)
		|
		|ORDER BY
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	RegisterRecordsGoodsReceivedNotInvoicedChange.LineNumber AS LineNumber,
		|	RegisterRecordsGoodsReceivedNotInvoicedChange.Company AS CompanyPresentation,
		|	RegisterRecordsGoodsReceivedNotInvoicedChange.GoodsReceipt AS GoodsReceiptPresentation,
		|	RegisterRecordsGoodsReceivedNotInvoicedChange.Products AS ProductsPresentation,
		|	RegisterRecordsGoodsReceivedNotInvoicedChange.Characteristic AS CharacteristicPresentation,
		|	GoodsReceivedNotInvoicedBalances.Products.MeasurementUnit AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsGoodsReceivedNotInvoicedChange.QuantityChange, 0) + ISNULL(GoodsReceivedNotInvoicedBalances.QuantityBalance, 0) AS BalanceGoodsReceivedNotInvoiced,
		|	ISNULL(GoodsReceivedNotInvoicedBalances.QuantityBalance, 0) AS QuantityBalanceGoodsReceivedNotInvoiced
		|FROM
		|	RegisterRecordsGoodsReceivedNotInvoicedChange AS RegisterRecordsGoodsReceivedNotInvoicedChange
		|		INNER JOIN AccumulationRegister.GoodsReceivedNotInvoiced.Balance(&ControlTimeGR, ) AS GoodsReceivedNotInvoicedBalances
		|		ON RegisterRecordsGoodsReceivedNotInvoicedChange.Company = GoodsReceivedNotInvoicedBalances.Company
		|			AND RegisterRecordsGoodsReceivedNotInvoicedChange.GoodsReceipt = GoodsReceivedNotInvoicedBalances.GoodsReceipt
		|			AND RegisterRecordsGoodsReceivedNotInvoicedChange.Contract = GoodsReceivedNotInvoicedBalances.Contract
		|			AND RegisterRecordsGoodsReceivedNotInvoicedChange.Products = GoodsReceivedNotInvoicedBalances.Products
		|			AND RegisterRecordsGoodsReceivedNotInvoicedChange.Characteristic = GoodsReceivedNotInvoicedBalances.Characteristic
		|			AND (ISNULL(GoodsReceivedNotInvoicedBalances.QuantityBalance, 0) < 0)
		|
		|ORDER BY
		|	LineNumber");
		
		Query.Text = Query.Text + DriveClientServer.GetQueryDelimeter();
		Query.Text = Query.Text + AccumulationRegisters.VATIncurred.BalancesControlQueryText();
		
		Query.Text = Query.Text + DriveClientServer.GetQueryDelimeter();
		Query.Text = Query.Text + AccumulationRegisters.GoodsAwaitingCustomsClearance.BalancesControlQueryText();
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.SetParameter("ControlTime", AdditionalProperties.ForPosting.ControlTime);
		Query.SetParameter("ControlTimeGR", New Boundary(EndOfMonth(AdditionalProperties.ForPosting.Date), BoundaryType.Including));
		
		ResultsArray = Query.ExecuteBatch();
		
		If Not ResultsArray[0].IsEmpty()
			OR Not ResultsArray[1].IsEmpty()
			OR Not ResultsArray[2].IsEmpty()
			OR Not ResultsArray[3].IsEmpty()
			OR Not ResultsArray[4].IsEmpty()
			OR Not ResultsArray[5].IsEmpty()
			OR Not ResultsArray[6].IsEmpty()
			OR Not ResultsArray[7].IsEmpty()
			OR Not ResultsArray[8].IsEmpty()
			OR Not ResultsArray[10].IsEmpty()
			OR Not ResultsArray[11].IsEmpty() Then
			DocumentObjectSupplierInvoice = DocumentRefPurchaseInvoice.GetObject()
		EndIf;
		
		// Negative balance of inventory in the warehouse.
		If Not ResultsArray[0].IsEmpty() Then
			QueryResultSelection = ResultsArray[0].Select();
			DriveServer.ShowMessageAboutPostingToInventoryInWarehousesRegisterErrors(DocumentObjectSupplierInvoice, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance of inventory.
		If Not ResultsArray[1].IsEmpty() Then
			QueryResultSelection = ResultsArray[1].Select();
			DriveServer.ShowMessageAboutPostingToInventoryRegisterErrors(DocumentObjectSupplierInvoice, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance on sales order.
		If Not ResultsArray[2].IsEmpty() Then
			QueryResultSelection = ResultsArray[2].Select();
			DriveServer.ShowMessageAboutPostingToSalesOrdersRegisterErrors(DocumentObjectSupplierInvoice, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance by the purchase order.
		If Not ResultsArray[3].IsEmpty() Then
			QueryResultSelection = ResultsArray[3].Select();
			DriveServer.ShowMessageAboutPostingToPurchaseOrdersRegisterErrors(DocumentObjectSupplierInvoice, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance of needs in inventory.
		If Not ResultsArray[4].IsEmpty() Then
			QueryResultSelection = ResultsArray[4].Select();
			DriveServer.ShowMessageAboutPostingToInventoryDemandRegisterErrors(DocumentObjectSupplierInvoice, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance of inventory placement.
		If Not ResultsArray[5].IsEmpty() Then
			QueryResultSelection = ResultsArray[5].Select();
			DriveServer.ShowMessageAboutPostingToBackordersRegisterErrors(DocumentObjectSupplierInvoice, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance on accounts payable.
		If Not ResultsArray[6].IsEmpty() Then
			QueryResultSelection = ResultsArray[6].Select();
			DriveServer.ShowMessageAboutPostingToAccountsPayableRegisterErrors(DocumentObjectSupplierInvoice, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance according to the amount-based account in retail.
		If Not ResultsArray[7].IsEmpty() Then
			QueryResultSelection = ResultsArray[7].Select();
			DriveServer.ShowMessageAboutPostingToPOSSummaryRegisterErrors(DocumentObjectSupplierInvoice, QueryResultSelection, Cancel);
		EndIf;
		
		If Not ResultsArray[8].IsEmpty() Then
			QueryResultSelection = ResultsArray[8].Select();
			DriveServer.ShowMessageAboutPostingToGoodsReceivedNotInvoicedRegisterErrors(DocumentObjectSupplierInvoice, QueryResultSelection, Cancel);
		EndIf;
		
		If Not ResultsArray[10].IsEmpty() Then
			QueryResultSelection = ResultsArray[10].Select();
			DriveServer.ShowMessageAboutPostingToVATIncurredRegisterErrors(DocumentObjectSupplierInvoice, QueryResultSelection, Cancel);
		EndIf;
		
		If Not ResultsArray[11].IsEmpty() Then
			QueryResultSelection = ResultsArray[11].Select();
			DriveServer.ShowMessageAboutPostingToGoodsAwaitingCustomsClearanceRegisterErrors(DocumentObjectSupplierInvoice, QueryResultSelection, Cancel);
		EndIf;
		
	EndIf;
	
EndProcedure

// Writes to the Counterparties products prices information register.
//
Procedure RecordVendorPrices(DocumentRefPurchaseInvoice) Export

	If DocumentRefPurchaseInvoice.Posted Then
		DeleteVendorPrices(DocumentRefPurchaseInvoice);
	EndIf;
	
	If Not ValueIsFilled(DocumentRefPurchaseInvoice.SupplierPriceTypes) Then
		Return;
	EndIf; 
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	TablePrices.Ref.Date AS Period,
	|	TablePrices.Ref.SupplierPriceTypes AS SupplierPriceTypes,
	|	TablePrices.Products AS Products,
	|	TablePrices.Characteristic AS Characteristic,
	|	MAX(CASE
	|			WHEN TablePrices.Ref.AmountIncludesVAT = TablePrices.Ref.SupplierPriceTypes.PriceIncludesVAT
	|				THEN ISNULL(TablePrices.Price * DocumentCurrencyRate.ExchangeRate * RateCurrencyTypePrices.Multiplicity / (RateCurrencyTypePrices.ExchangeRate * DocumentCurrencyRate.Multiplicity), 0)
	|			WHEN TablePrices.Ref.AmountIncludesVAT > TablePrices.Ref.SupplierPriceTypes.PriceIncludesVAT
	|				THEN ISNULL(TablePrices.Price * DocumentCurrencyRate.ExchangeRate * RateCurrencyTypePrices.Multiplicity / (RateCurrencyTypePrices.ExchangeRate * DocumentCurrencyRate.Multiplicity) * 100 / (100 + TablePrices.VATRate.Rate), 0)
	|			ELSE ISNULL(TablePrices.Price * DocumentCurrencyRate.ExchangeRate * RateCurrencyTypePrices.Multiplicity / (RateCurrencyTypePrices.ExchangeRate * DocumentCurrencyRate.Multiplicity) * (100 + TablePrices.VATRate.Rate) / 100, 0)
	|		END) AS Price,
	|	TablePrices.MeasurementUnit AS MeasurementUnit,
	|	TRUE AS Actuality,
	|	TablePrices.Ref AS DocumentRecorder,
	|	TablePrices.Ref.Author AS Author
	|FROM
	|	Document.SupplierInvoice.Inventory AS TablePrices
	|		LEFT JOIN InformationRegister.CounterpartyPrices AS CounterpartyPrices
	|		ON TablePrices.Ref.SupplierPriceTypes = CounterpartyPrices.SupplierPriceTypes
	|			AND TablePrices.Products = CounterpartyPrices.Products
	|			AND TablePrices.Characteristic = CounterpartyPrices.Characteristic
	|			AND (BEGINOFPERIOD(TablePrices.Ref.Date, DAY) = CounterpartyPrices.Period)
	|			AND TablePrices.Ref.Date <= CounterpartyPrices.DocumentRecorder.Date
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&ProcessingDate, ) AS RateCurrencyTypePrices
	|		ON TablePrices.Ref.SupplierPriceTypes.PriceCurrency = RateCurrencyTypePrices.Currency,
	|	InformationRegister.ExchangeRates.SliceLast(&ProcessingDate, Currency = &DocumentCurrency) AS DocumentCurrencyRate
	|WHERE
	|	TablePrices.Ref.RegisterVendorPrices
	|	AND CounterpartyPrices.SupplierPriceTypes IS NULL
	|	AND TablePrices.Ref = &Ref
	|	AND TablePrices.Price <> 0
	|
	|GROUP BY
	|	TablePrices.Products,
	|	TablePrices.Characteristic,
	|	TablePrices.MeasurementUnit,
	|	TablePrices.Ref.Date,
	|	TablePrices.Ref.SupplierPriceTypes,
	|	TablePrices.Ref,
	|	TablePrices.Ref.Author";
	
	Query.SetParameter("Ref", DocumentRefPurchaseInvoice);
	Query.SetParameter("DocumentCurrency", DocumentRefPurchaseInvoice.DocumentCurrency);
	Query.SetParameter("ProcessingDate", DocumentRefPurchaseInvoice.Date);
	
	QueryResult = Query.Execute();
	RecordsTable = QueryResult.Unload();
	
	// IR set record
	RecordSet = InformationRegisters.CounterpartyPrices.CreateRecordSet();
	RecordSet.Filter.Period.Set(DocumentRefPurchaseInvoice.Date);
	RecordSet.Filter.SupplierPriceTypes.Set(DocumentRefPurchaseInvoice.SupplierPriceTypes);
	For Each TableRow In RecordsTable Do
		NewRecord = RecordSet.Add();
		FillPropertyValues(NewRecord, TableRow);
	EndDo; 
	RecordSet.Write();
	
EndProcedure

// Deletes records from the Counterparties products prices information register.
//
Procedure DeleteVendorPrices(DocumentRefPurchaseInvoice) Export

	Query = New Query;
	Query.Text =
	"SELECT
	|	CounterpartyPrices.Period,
	|	CounterpartyPrices.SupplierPriceTypes,
	|	CounterpartyPrices.Products,
	|	CounterpartyPrices.Characteristic
	|FROM
	|	InformationRegister.CounterpartyPrices AS CounterpartyPrices
	|WHERE
	|	CounterpartyPrices.DocumentRecorder = &DocumentRecorder";
	
	Query.SetParameter("DocumentRecorder", DocumentRefPurchaseInvoice);
	
	QueryResult = Query.Execute();
	RecordsTable = QueryResult.Unload();
	
	For Each TableRow In RecordsTable Do
		RecordSet = InformationRegisters.CounterpartyPrices.CreateRecordSet();
		RecordSet.Filter.Period.Set(TableRow.Period);
		RecordSet.Filter.SupplierPriceTypes.Set(TableRow.SupplierPriceTypes);
		RecordSet.Filter.Products.Set(TableRow.Products);
		RecordSet.Filter.Characteristic.Set(TableRow.Characteristic);
		RecordSet.Write();
	EndDo;

EndProcedure

#Region PrintInterface

// Function generates document printing form by specified layout.
//
// Parameters:
// SpreadsheetDocument - TabularDocument in which
// 			   printing form will be displayed.
//  TemplateName    - String, printing form layout name.
//
Function PrintForm(ObjectsArray, PrintObjects, TemplateName)
	
	SpreadsheetDocument = New SpreadsheetDocument;
	SpreadsheetDocument.PrintParametersKey = "PrintParameters_SupplierInvoice";
	
	FirstDocument = True;
	
	For Each CurrentDocument In ObjectsArray Do
	
		If Not FirstDocument Then
			SpreadsheetDocument.PutHorizontalPageBreak();
		EndIf;
		FirstDocument = False;
		
		FirstLineNumber = SpreadsheetDocument.TableHeight + 1;
		
		Query = New Query();
		Query.SetParameter("CurrentDocument", CurrentDocument);
		
		If TemplateName = "MerchandiseFillingForm" Then
			
			Query.Text = 
			"SELECT
			|	SupplierInvoice.Date AS DocumentDate,
			|	SupplierInvoice.StructuralUnit AS WarehousePresentation,
			|	SupplierInvoice.Cell AS CellPresentation,
			|	SupplierInvoice.Number,
			|	SupplierInvoice.Company.Prefix AS Prefix,
			|	SupplierInvoice.Inventory.(
			|		LineNumber AS LineNumber,
			|		Products.Warehouse AS Warehouse,
			|		Products.Cell AS Cell,
			|		CASE
			|			WHEN (CAST(SupplierInvoice.Inventory.Products.DescriptionFull AS String(100))) = """"
			|				THEN SupplierInvoice.Inventory.Products.Description
			|			ELSE SupplierInvoice.Inventory.Products.DescriptionFull
			|		END AS InventoryItem,
			|		Products.SKU AS SKU,
			|		Products.Code AS Code,
			|		MeasurementUnit.Description AS MeasurementUnit,
			|		Quantity AS Quantity,
			|		Characteristic,
			|		Products.ProductsType AS ProductsType,
			|		ConnectionKey
			|	),
			|	SupplierInvoice.SerialNumbers.(
			|		SerialNumber,
			|		ConnectionKey
			|	)
			|FROM
			|	Document.SupplierInvoice AS SupplierInvoice
			|WHERE
			|	SupplierInvoice.Ref = &CurrentDocument
			|
			|ORDER BY
			|	LineNumber";
			
			Header = Query.Execute().Select();
			Header.Next();
			
			LinesSelectionInventory = Header.Inventory.Select();
			LinesSelectionSerialNumbers = Header.SerialNumbers.Select();
			
			SpreadsheetDocument.PrintParametersName = "PRINT_PARAMETERS_IncomeOrder_FormOfFilling";
			
			Template = PrintManagement.GetTemplate("Document.SupplierInvoice.PF_MXL_MerchandiseFillingForm");
			
			If Header.DocumentDate < Date('20110101') Then
				DocumentNumber = DriveServer.GetNumberForPrinting(Header.Number, Header.Prefix);
			Else
				DocumentNumber = ObjectPrefixationClientServer.GetNumberForPrinting(Header.Number, True, True);
			EndIf;
			
			TemplateArea = Template.GetArea("Title");
			TemplateArea.Parameters.HeaderText =
				"Supplier invoice #"
			  + DocumentNumber
			  + " dated "
			  + Format(Header.DocumentDate, "DLF=DD");
			
			SpreadsheetDocument.Put(TemplateArea);
			
			TemplateArea = Template.GetArea("Warehouse");
			TemplateArea.Parameters.WarehousePresentation = Header.WarehousePresentation;
			SpreadsheetDocument.Put(TemplateArea);
			
			If Constants.UseStorageBins.Get() Then
				
				TemplateArea = Template.GetArea("Cell");
				TemplateArea.Parameters.CellPresentation = Header.CellPresentation;
				SpreadsheetDocument.Put(TemplateArea);
				
			EndIf;
			
			TemplateArea = Template.GetArea("PrintingTime");
			TemplateArea.Parameters.PrintingTime =
				"Date and time of printing: "
			  + CurrentDate()
			  + ". User: "
			  + Users.CurrentUser();
			
			SpreadsheetDocument.Put(TemplateArea);
			
			TemplateArea = Template.GetArea("TableHeader");
			SpreadsheetDocument.Put(TemplateArea);
			TemplateArea = Template.GetArea("String");
			
			While LinesSelectionInventory.Next() Do
				
				If Not LinesSelectionInventory.ProductsType = Enums.ProductsTypes.InventoryItem Then
					Continue;
				EndIf;
				
				TemplateArea.Parameters.Fill(LinesSelectionInventory);
				StringSerialNumbers = WorkWithSerialNumbers.SerialNumbersStringFromSelection(LinesSelectionSerialNumbers, LinesSelectionInventory.ConnectionKey);
				TemplateArea.Parameters.InventoryItem = DriveServer.GetProductsPresentationForPrinting(
					LinesSelectionInventory.InventoryItem,
					LinesSelectionInventory.Characteristic,
					LinesSelectionInventory.SKU,
					StringSerialNumbers
				);
				
				SpreadsheetDocument.Put(TemplateArea);
				
			EndDo;
			
			TemplateArea = Template.GetArea("Total");
			SpreadsheetDocument.Put(TemplateArea);
			
		EndIf;
		
		PrintManagement.SetDocumentPrintArea(SpreadsheetDocument, FirstLineNumber, PrintObjects, CurrentDocument);
		
	EndDo;
	
	SpreadsheetDocument.FitToPage = True;
	
	Return SpreadsheetDocument;
	
EndFunction

// Generate printed forms of objects
//
// Incoming:
//   TemplateNames    - String    - Names of layouts separated
//   by commas ObjectsArray  - Array    - Array of refs to objects that
//   need to be printed PrintParameters - Structure - Structure of additional printing parameters
//
// Outgoing:
//   PrintFormsCollection - Values table - Generated
//   table documents OutputParameters       - Structure        - Parameters of generated table documents
//
Procedure Print(ObjectsArray, PrintParameters, PrintFormsCollection, PrintObjects, OutputParameters) Export
	
	If PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "MerchandiseFillingForm") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection, "MerchandiseFillingForm", "Merchandise filling form", PrintForm(ObjectsArray, PrintObjects, "MerchandiseFillingForm"));
		
	ElsIf PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "GoodsReceivedNote") Then
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection,
															"GoodsReceivedNote",
															NStr("en = 'Goods received note'"),
															DataProcessors.PrintGoodsReceivedNote.PrintForm(ObjectsArray, PrintObjects, "GoodsReceivedNote"));
	EndIf;
	
	// parameters of sending printing forms by email
	DriveServer.FillSendingParameters(OutputParameters.SendingParameters, ObjectsArray, PrintFormsCollection);
	
EndProcedure

// Fills in the list of printing commands.
// 
// Parameters:
//   PrintCommands - ValueTable - see fields' content in the PrintManagement.CreatePrintCommandsCollection function.
//
Procedure AddPrintCommands(PrintCommands) Export
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID							= "GoodsReceivedNote";
	PrintCommand.Presentation				= NStr("en = 'Goods received note'");
	PrintCommand.CheckPostingBeforePrint	= False;
	PrintCommand.Order						= 1;
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID = "MerchandiseFillingForm";
	PrintCommand.Presentation = NStr("en = 'Goods content form'");
	PrintCommand.FormsList = "DocumentForm,ListForm,DocumentsListForm";
	PrintCommand.CheckPostingBeforePrint = False;
	PrintCommand.Order = 10;
	
	If AccessRight("view", Metadata.DataProcessors.PrintLabelsAndTags) Then
		
		PrintCommand = PrintCommands.Add();
		PrintCommand.Handler = "DriveClient.PrintLabelsAndPriceTagsFromDocuments";
		PrintCommand.ID = "LabelsPrintingFromSupplierInvoice";
		PrintCommand.Presentation = NStr("en = 'Print labels'");
		PrintCommand.FormsList = "DocumentForm,ListForm,DocumentsListForm";
		PrintCommand.CheckPostingBeforePrint = False;
		PrintCommand.Order = 14;
		
		PrintCommand = PrintCommands.Add();
		PrintCommand.Handler = "DriveClient.PrintLabelsAndPriceTagsFromDocuments";
		PrintCommand.ID = "PriceTagsPrintingFromSupplierInvoice";
		PrintCommand.Presentation = NStr("en = 'Print price tags'");
		PrintCommand.FormsList = "DocumentForm,ListForm,DocumentsListForm";
		PrintCommand.CheckPostingBeforePrint = False;
		PrintCommand.Order = 17;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region InfobaseUpdate

Procedure FillNewGLAccounts() Export
	
	DocumentName = "SupplierInvoice";
	
	Tables = New Array();
	
	// Table "Inventory"
	TableDecription = New Structure("Name, Conditions", "Inventory", New Array());
	
	GLAccountFields = ChartsOfAccounts.PrimaryChartOfAccounts.GLAccountFields();
	GLAccountFields.Source = "Products.InventoryGLAccount";
	GLAccountFields.Receiver = "InventoryGLAccount";
	TableDecription.Conditions.Add(GLAccountFields);
	
	GLAccountFields = ChartsOfAccounts.PrimaryChartOfAccounts.GLAccountFields();
	GLAccountFields.Source = "&VATInputGLAccount";
	GLAccountFields.Receiver = "VATInputGLAccount";
	GLAccountFields.Parameter = Catalogs.DefaultGLAccounts.GetDefaultGLAccount("VATInput");
	TableDecription.Conditions.Add(GLAccountFields);
	
	GLAccountFields = ChartsOfAccounts.PrimaryChartOfAccounts.GLAccountFields();
	GLAccountFields.Source = "&GoodsReceivedNotInvoicedGLAccount";
	GLAccountFields.Receiver = "GoodsReceivedNotInvoicedGLAccount";
	GLAccountFields.Parameter = Catalogs.DefaultGLAccounts.GetDefaultGLAccount("GoodsReceivedNotInvoiced");
	TableDecription.Conditions.Add(GLAccountFields);
	
	GLAccountFields = ChartsOfAccounts.PrimaryChartOfAccounts.GLAccountFields();
	GLAccountFields.Source = "&VATOutputGLAccount";
	GLAccountFields.Receiver = "VATOutputGLAccount";
	GLAccountFields.Parameter = Catalogs.DefaultGLAccounts.GetDefaultGLAccount("VATOutput");
	TableDecription.Conditions.Add(GLAccountFields);
	
	Tables.Add(TableDecription);
	
	// Table "Expenses"
	TableDecription = New Structure("Name, Conditions", "Expenses", New Array());
	
	GLAccountFields = ChartsOfAccounts.PrimaryChartOfAccounts.GLAccountFields();
	GLAccountFields.Source = "Products.ExpensesGLAccount";
	GLAccountFields.Receiver = "InventoryGLAccount";
	TableDecription.Conditions.Add(GLAccountFields);
	
	GLAccountFields = ChartsOfAccounts.PrimaryChartOfAccounts.GLAccountFields();
	GLAccountFields.Source = "&VATInputGLAccount";
	GLAccountFields.Receiver = "VATInputGLAccount";
	GLAccountFields.Parameter = Catalogs.DefaultGLAccounts.GetDefaultGLAccount("VATInput");
	TableDecription.Conditions.Add(GLAccountFields);
	
	GLAccountFields = ChartsOfAccounts.PrimaryChartOfAccounts.GLAccountFields();
	GLAccountFields.Source = "&VATOutputGLAccount";
	GLAccountFields.Receiver = "VATOutputGLAccount";
	GLAccountFields.Parameter = Catalogs.DefaultGLAccounts.GetDefaultGLAccount("VATOutput");
	TableDecription.Conditions.Add(GLAccountFields);
	
	Tables.Add(TableDecription);
	
	ChartsOfAccounts.PrimaryChartOfAccounts.FillNewGLAccounts(DocumentName, Tables);
	
EndProcedure

#EndRegion

#EndIf