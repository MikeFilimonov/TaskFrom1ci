#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ProgramInterface

Procedure FillBySalesOrders(DocumentData, FilterData, Inventory) Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	SalesOrder.Ref AS Ref
	|INTO TT_SalesOrders
	|FROM
	|	Document.SalesOrder AS SalesOrder
	|WHERE
	|	&SalesOrdersConditions
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SalesInvoiceInventory.Order AS Order,
	|	SalesInvoiceInventory.Products AS Products,
	|	SalesInvoiceInventory.Characteristic AS Characteristic,
	|	SalesInvoiceInventory.Batch AS Batch,
	|	SUM(SalesInvoiceInventory.Quantity * ISNULL(UOM.Factor, 1)) AS BaseQuantity
	|INTO TT_AlreadyInvoiced
	|FROM
	|	Document.SalesInvoice.Inventory AS SalesInvoiceInventory
	|		INNER JOIN TT_SalesOrders AS TT_SalesOrders
	|		ON SalesInvoiceInventory.Order = TT_SalesOrders.Ref
	|		INNER JOIN Document.SalesInvoice AS SalesInvoiceDocument
	|		ON SalesInvoiceInventory.Ref = SalesInvoiceDocument.Ref
	|		INNER JOIN Catalog.Products AS ProductsCatalog
	|		ON SalesInvoiceInventory.Products = ProductsCatalog.Ref
	|		LEFT JOIN Catalog.UOM AS UOM
	|		ON SalesInvoiceInventory.MeasurementUnit = UOM.Ref
	|WHERE
	|	SalesInvoiceDocument.Posted
	|	AND SalesInvoiceInventory.Ref <> &Ref
	|
	|GROUP BY
	|	SalesInvoiceInventory.Batch,
	|	SalesInvoiceInventory.Order,
	|	SalesInvoiceInventory.Products,
	|	SalesInvoiceInventory.Characteristic
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	OrdersBalance.SalesOrder AS SalesOrder,
	|	OrdersBalance.Products AS Products,
	|	OrdersBalance.Characteristic AS Characteristic,
	|	SUM(OrdersBalance.QuantityBalance) AS QuantityBalance
	|INTO TT_OrdersBalances
	|FROM
	|	(SELECT
	|		OrdersBalance.SalesOrder AS SalesOrder,
	|		OrdersBalance.Products AS Products,
	|		OrdersBalance.Characteristic AS Characteristic,
	|		OrdersBalance.QuantityBalance AS QuantityBalance
	|	FROM
	|		AccumulationRegister.SalesOrders.Balance(
	|				,
	|				SalesOrder IN
	|					(SELECT
	|						TT_SalesOrders.Ref
	|					FROM
	|						TT_SalesOrders)) AS OrdersBalance
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsSalesOrders.SalesOrder,
	|		DocumentRegisterRecordsSalesOrders.Products,
	|		DocumentRegisterRecordsSalesOrders.Characteristic,
	|		CASE
	|			WHEN DocumentRegisterRecordsSalesOrders.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN ISNULL(DocumentRegisterRecordsSalesOrders.Quantity, 0)
	|			ELSE -ISNULL(DocumentRegisterRecordsSalesOrders.Quantity, 0)
	|		END
	|	FROM
	|		AccumulationRegister.SalesOrders AS DocumentRegisterRecordsSalesOrders
	|	WHERE
	|		DocumentRegisterRecordsSalesOrders.Recorder = &Ref) AS OrdersBalance
	|		INNER JOIN Catalog.Products AS ProductsCatalog
	|		ON OrdersBalance.Products = ProductsCatalog.Ref
	|
	|GROUP BY
	|	OrdersBalance.SalesOrder,
	|	OrdersBalance.Products,
	|	OrdersBalance.Characteristic
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SalesOrderInventory.LineNumber AS LineNumber,
	|	SalesOrderInventory.Products AS Products,
	|	SalesOrderInventory.Products.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem) AS ProductsTypeInventory,
	|	SalesOrderInventory.Characteristic AS Characteristic,
	|	SalesOrderInventory.Batch AS Batch,
	|	SalesOrderInventory.Quantity AS Quantity,
	|	SalesOrderInventory.MeasurementUnit AS MeasurementUnit,
	|	ISNULL(UOM.Factor, 1) AS Factor,
	|	SalesOrderInventory.Price AS Price,
	|	SalesOrderInventory.DiscountMarkupPercent AS DiscountMarkupPercent,
	|	SalesOrderInventory.Amount AS Amount,
	|	SalesOrderInventory.VATRate AS VATRate,
	|	SalesOrderInventory.VATAmount AS VATAmount,
	|	SalesOrderInventory.Total AS Total,
	|	SalesOrderInventory.Ref AS Order,
	|	SalesOrderInventory.Content AS Content,
	|	SalesOrderInventory.AutomaticDiscountsPercent AS AutomaticDiscountsPercent,
	|	SalesOrderInventory.AutomaticDiscountAmount AS AutomaticDiscountAmount,
	|	SalesOrderInventory.SerialNumbers AS SerialNumbers,
	|	SalesOrderInventory.Ref.PointInTime AS PointInTime
	|INTO TT_Inventory
	|FROM
	|	Document.SalesOrder.Inventory AS SalesOrderInventory
	|		INNER JOIN TT_SalesOrders AS TT_SalesOrders
	|		ON SalesOrderInventory.Ref = TT_SalesOrders.Ref
	|		INNER JOIN Catalog.Products AS ProductsCatalog
	|		ON SalesOrderInventory.Products = ProductsCatalog.Ref
	|		LEFT JOIN Catalog.UOM AS UOM
	|		ON SalesOrderInventory.MeasurementUnit = UOM.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_Inventory.LineNumber AS LineNumber,
	|	TT_Inventory.Products AS Products,
	|	TT_Inventory.Characteristic AS Characteristic,
	|	TT_Inventory.Batch AS Batch,
	|	TT_Inventory.Order AS Order,
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
	|			AND TT_Inventory.LineNumber >= TT_InventoryCumulative.LineNumber
	|
	|GROUP BY
	|	TT_Inventory.LineNumber,
	|	TT_Inventory.Products,
	|	TT_Inventory.Characteristic,
	|	TT_Inventory.Batch,
	|	TT_Inventory.Order,
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
	|			AND TT_InventoryNotYetInvoiced.LineNumber >= TT_InventoryNotYetInvoicedCumulative.LineNumber
	|
	|GROUP BY
	|	TT_InventoryNotYetInvoiced.LineNumber,
	|	TT_InventoryNotYetInvoiced.Products,
	|	TT_InventoryNotYetInvoiced.Characteristic,
	|	TT_InventoryNotYetInvoiced.Batch,
	|	TT_InventoryNotYetInvoiced.Order,
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
	|	TT_InventoryNotYetInvoicedCumulative.Factor AS Factor,
	|	CASE
	|		WHEN TT_OrdersBalances.QuantityBalance > TT_InventoryNotYetInvoicedCumulative.BaseQuantityCumulative
	|			THEN TT_InventoryNotYetInvoicedCumulative.BaseQuantity
	|		WHEN TT_OrdersBalances.QuantityBalance > TT_InventoryNotYetInvoicedCumulative.BaseQuantityCumulative - TT_InventoryNotYetInvoicedCumulative.BaseQuantity
	|			THEN TT_OrdersBalances.QuantityBalance - (TT_InventoryNotYetInvoicedCumulative.BaseQuantityCumulative - TT_InventoryNotYetInvoicedCumulative.BaseQuantity)
	|	END AS BaseQuantity
	|INTO TT_InventoryToBeInvoiced
	|FROM
	|	TT_InventoryNotYetInvoicedCumulative AS TT_InventoryNotYetInvoicedCumulative
	|		INNER JOIN TT_OrdersBalances AS TT_OrdersBalances
	|		ON TT_InventoryNotYetInvoicedCumulative.Products = TT_OrdersBalances.Products
	|			AND TT_InventoryNotYetInvoicedCumulative.Characteristic = TT_OrdersBalances.Characteristic
	|			AND TT_InventoryNotYetInvoicedCumulative.Order = TT_OrdersBalances.SalesOrder
	|WHERE
	|	TT_OrdersBalances.QuantityBalance > TT_InventoryNotYetInvoicedCumulative.BaseQuantityCumulative - TT_InventoryNotYetInvoicedCumulative.BaseQuantity
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
	|	TT_Inventory.Price AS Price,
	|	TT_Inventory.DiscountMarkupPercent AS DiscountMarkupPercent,
	|	CASE
	|		WHEN (CAST(TT_Inventory.Quantity * TT_Inventory.Factor AS NUMBER(15, 3))) = TT_InventoryToBeInvoiced.BaseQuantity
	|			THEN TT_Inventory.Amount
	|		ELSE CAST((CAST((CAST(TT_InventoryToBeInvoiced.BaseQuantity / TT_Inventory.Factor AS NUMBER(15, 3))) * TT_Inventory.Price AS NUMBER(15, 2))) * (1 - TT_Inventory.DiscountMarkupPercent / 100) AS NUMBER(15, 2))
	|	END AS Amount,
	|	TT_Inventory.VATRate AS VATRate,
	|	CASE
	|		WHEN (CAST(TT_Inventory.Quantity * TT_Inventory.Factor AS NUMBER(15, 3))) = TT_InventoryToBeInvoiced.BaseQuantity
	|			THEN TT_Inventory.VATAmount
	|		WHEN &AmountIncludesVAT
	|			THEN CAST((CAST((CAST((CAST(TT_InventoryToBeInvoiced.BaseQuantity / TT_Inventory.Factor AS NUMBER(15, 3))) * TT_Inventory.Price AS NUMBER(15, 2))) * (1 - TT_Inventory.DiscountMarkupPercent / 100) AS NUMBER(15, 2))) * TT_Inventory.VATRate.Rate / (100 + TT_Inventory.VATRate.Rate) AS NUMBER(15, 2))
	|		ELSE CAST((CAST((CAST((CAST(TT_InventoryToBeInvoiced.BaseQuantity / TT_Inventory.Factor AS NUMBER(15, 3))) * TT_Inventory.Price AS NUMBER(15, 2))) * (1 - TT_Inventory.DiscountMarkupPercent / 100) AS NUMBER(15, 2))) * TT_Inventory.VATRate.Rate / 100 AS NUMBER(15, 2))
	|	END AS VATAmount,
	|	CASE
	|		WHEN (CAST(TT_Inventory.Quantity * TT_Inventory.Factor AS NUMBER(15, 3))) = TT_InventoryToBeInvoiced.BaseQuantity
	|			THEN TT_Inventory.Total
	|		WHEN &AmountIncludesVAT
	|			THEN CAST((CAST((CAST(TT_InventoryToBeInvoiced.BaseQuantity / TT_Inventory.Factor AS NUMBER(15, 3))) * TT_Inventory.Price AS NUMBER(15, 2))) * (1 - TT_Inventory.DiscountMarkupPercent / 100) AS NUMBER(15, 2))
	|		ELSE CAST((CAST((CAST((CAST(TT_InventoryToBeInvoiced.BaseQuantity / TT_Inventory.Factor AS NUMBER(15, 3))) * TT_Inventory.Price AS NUMBER(15, 2))) * (1 - TT_Inventory.DiscountMarkupPercent / 100) AS NUMBER(15, 2))) * (100 + TT_Inventory.VATRate.Rate) / 100 AS NUMBER(15, 2))
	|	END AS Total,
	|	TT_Inventory.Order AS Order,
	|	SalesOrder.SalesRep AS SalesRep,
	|	VALUE(Document.GoodsIssue.EmptyRef) AS GoodsIssue,
	|	TT_Inventory.Content AS Content,
	|	TT_Inventory.AutomaticDiscountsPercent AS AutomaticDiscountsPercent,
	|	TT_Inventory.AutomaticDiscountAmount AS AutomaticDiscountAmount,
	|	TT_Inventory.SerialNumbers AS SerialNumbers,
	|	TT_Inventory.PointInTime AS PointInTime
	|INTO TT_InventoryToFillReserve
	|FROM
	|	TT_Inventory AS TT_Inventory
	|		INNER JOIN TT_InventoryToBeInvoiced AS TT_InventoryToBeInvoiced
	|		ON TT_Inventory.LineNumber = TT_InventoryToBeInvoiced.LineNumber
	|			AND TT_Inventory.Order = TT_InventoryToBeInvoiced.Order
	|		INNER JOIN Document.SalesOrder AS SalesOrder
	|		ON TT_Inventory.Order = SalesOrder.Ref
	|";
	
	If Constants.UseInventoryReservation.Get() AND ValueIsFilled(DocumentData.StructuralUnit) Then
		Query.Text = Query.Text + GetFillReserveColumnQueryText();
	Else
		Query.Text = StrReplace(Query.Text, "INTO TT_InventoryToFillReserve", "");
	EndIf;
	
	Query.Text = Query.Text + "
	|ORDER BY
	|	TT_Inventory.PointInTime,
	|	TT_Inventory.LineNumber";
	
	If FilterData.Property("OrdersArray") Then
		FilterString = "SalesOrder.Ref IN(&OrdersArray)";
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
			FilterString = FilterString + "SalesOrder." + FilterItem.Key + " = &" + FilterItem.Key;
			Query.SetParameter(FilterItem.Key, FilterItem.Value);
		EndDo;
	EndIf;
	Query.Text = StrReplace(Query.Text, "&SalesOrdersConditions", FilterString);
	Query.SetParameter("Ref", DocumentData.Ref);
	Query.SetParameter("Company", DriveServer.GetCompany(DocumentData.Company));
	Query.SetParameter("StructuralUnit", DocumentData.StructuralUnit);
	Query.SetParameter("AmountIncludesVAT", DocumentData.AmountIncludesVAT);
	
	Inventory.Load(Query.Execute().Unload());
	
EndProcedure

Procedure FillByWorkOrdersInventory(DocumentData, FilterData, Inventory) Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	WorkOrder.Ref AS Ref,
	|	WorkOrder.SalesRep AS SalesRep
	|INTO TT_SalesOrders
	|FROM
	|	Document.WorkOrder AS WorkOrder
	|WHERE
	|	&SalesOrdersConditions
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SalesInvoiceInventory.Order AS Order,
	|	SalesInvoiceInventory.Products AS Products,
	|	SalesInvoiceInventory.Characteristic AS Characteristic,
	|	SalesInvoiceInventory.Batch AS Batch,
	|	SUM(SalesInvoiceInventory.Quantity * ISNULL(UOM.Factor, 1)) AS BaseQuantity
	|INTO TT_AlreadyInvoiced
	|FROM
	|	Document.SalesInvoice.Inventory AS SalesInvoiceInventory
	|		INNER JOIN TT_SalesOrders AS TT_SalesOrders
	|		ON SalesInvoiceInventory.Order = TT_SalesOrders.Ref
	|		INNER JOIN Document.SalesInvoice AS SalesInvoiceDocument
	|		ON SalesInvoiceInventory.Ref = SalesInvoiceDocument.Ref
	|		INNER JOIN Catalog.Products AS ProductsCatalog
	|		ON SalesInvoiceInventory.Products = ProductsCatalog.Ref
	|		LEFT JOIN Catalog.UOM AS UOM
	|		ON SalesInvoiceInventory.MeasurementUnit = UOM.Ref
	|WHERE
	|	SalesInvoiceDocument.Posted
	|	AND SalesInvoiceInventory.Ref <> &Ref
	|
	|GROUP BY
	|	SalesInvoiceInventory.Batch,
	|	SalesInvoiceInventory.Order,
	|	SalesInvoiceInventory.Products,
	|	SalesInvoiceInventory.Characteristic
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	OrdersBalance.SalesOrder AS SalesOrder,
	|	OrdersBalance.Products AS Products,
	|	OrdersBalance.Characteristic AS Characteristic,
	|	SUM(OrdersBalance.QuantityBalance) AS QuantityBalance
	|INTO TT_OrdersBalances
	|FROM
	|	(SELECT
	|		WorkOrdersBalance.WorkOrder AS SalesOrder,
	|		WorkOrdersBalance.Products AS Products,
	|		WorkOrdersBalance.Characteristic AS Characteristic,
	|		WorkOrdersBalance.QuantityBalance AS QuantityBalance
	|	FROM
	|		AccumulationRegister.WorkOrders.Balance(
	|				,
	|				WorkOrder IN
	|					(SELECT
	|						TT_SalesOrders.Ref
	|					FROM
	|						TT_SalesOrders)) AS WorkOrdersBalance
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		WorkOrders.WorkOrder,
	|		WorkOrders.Products,
	|		WorkOrders.Characteristic,
	|		CASE
	|			WHEN WorkOrders.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN ISNULL(WorkOrders.Quantity, 0)
	|			ELSE -ISNULL(WorkOrders.Quantity, 0)
	|		END
	|	FROM
	|		AccumulationRegister.WorkOrders AS WorkOrders
	|	WHERE
	|		WorkOrders.Recorder = &Ref) AS OrdersBalance
	|		INNER JOIN Catalog.Products AS ProductsCatalog
	|		ON OrdersBalance.Products = ProductsCatalog.Ref
	|
	|GROUP BY
	|	OrdersBalance.SalesOrder,
	|	OrdersBalance.Products,
	|	OrdersBalance.Characteristic
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	WorkOrderInventory.LineNumber AS LineNumber,
	|	WorkOrderInventory.Products AS Products,
	|	WorkOrderInventory.Products.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem) AS ProductsTypeInventory,
	|	WorkOrderInventory.Characteristic AS Characteristic,
	|	WorkOrderInventory.Batch AS Batch,
	|	WorkOrderInventory.Quantity AS Quantity,
	|	WorkOrderInventory.MeasurementUnit AS MeasurementUnit,
	|	ISNULL(UOM.Factor, 1) AS Factor,
	|	WorkOrderInventory.Price AS Price,
	|	WorkOrderInventory.DiscountMarkupPercent AS DiscountMarkupPercent,
	|	WorkOrderInventory.Amount AS Amount,
	|	WorkOrderInventory.VATRate AS VATRate,
	|	WorkOrderInventory.VATAmount AS VATAmount,
	|	WorkOrderInventory.Total AS Total,
	|	WorkOrderInventory.Ref AS Order,
	|	WorkOrderInventory.Content AS Content,
	|	WorkOrderInventory.AutomaticDiscountsPercent AS AutomaticDiscountsPercent,
	|	WorkOrderInventory.AutomaticDiscountAmount AS AutomaticDiscountAmount,
	|	WorkOrderInventory.SerialNumbers AS SerialNumbers,
	|	WorkOrderInventory.Ref.PointInTime AS PointInTime,
	|	TT_SalesOrders.SalesRep AS SalesRep
	|INTO TT_Inventory
	|FROM
	|	Document.WorkOrder.Inventory AS WorkOrderInventory
	|		INNER JOIN TT_SalesOrders AS TT_SalesOrders
	|		ON WorkOrderInventory.Ref = TT_SalesOrders.Ref
	|		INNER JOIN Catalog.Products AS ProductsCatalog
	|		ON WorkOrderInventory.Products = ProductsCatalog.Ref
	|		LEFT JOIN Catalog.UOM AS UOM
	|		ON WorkOrderInventory.MeasurementUnit = UOM.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_Inventory.LineNumber AS LineNumber,
	|	TT_Inventory.Products AS Products,
	|	TT_Inventory.Characteristic AS Characteristic,
	|	TT_Inventory.Batch AS Batch,
	|	TT_Inventory.Order AS Order,
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
	|			AND TT_Inventory.LineNumber >= TT_InventoryCumulative.LineNumber
	|
	|GROUP BY
	|	TT_Inventory.LineNumber,
	|	TT_Inventory.Products,
	|	TT_Inventory.Characteristic,
	|	TT_Inventory.Batch,
	|	TT_Inventory.Order,
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
	|			AND TT_InventoryNotYetInvoiced.LineNumber >= TT_InventoryNotYetInvoicedCumulative.LineNumber
	|
	|GROUP BY
	|	TT_InventoryNotYetInvoiced.LineNumber,
	|	TT_InventoryNotYetInvoiced.Products,
	|	TT_InventoryNotYetInvoiced.Characteristic,
	|	TT_InventoryNotYetInvoiced.Batch,
	|	TT_InventoryNotYetInvoiced.Order,
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
	|	TT_InventoryNotYetInvoicedCumulative.Factor AS Factor,
	|	CASE
	|		WHEN TT_OrdersBalances.QuantityBalance > TT_InventoryNotYetInvoicedCumulative.BaseQuantityCumulative
	|			THEN TT_InventoryNotYetInvoicedCumulative.BaseQuantity
	|		WHEN TT_OrdersBalances.QuantityBalance > TT_InventoryNotYetInvoicedCumulative.BaseQuantityCumulative - TT_InventoryNotYetInvoicedCumulative.BaseQuantity
	|			THEN TT_OrdersBalances.QuantityBalance - (TT_InventoryNotYetInvoicedCumulative.BaseQuantityCumulative - TT_InventoryNotYetInvoicedCumulative.BaseQuantity)
	|	END AS BaseQuantity
	|INTO TT_InventoryToBeInvoiced
	|FROM
	|	TT_InventoryNotYetInvoicedCumulative AS TT_InventoryNotYetInvoicedCumulative
	|		INNER JOIN TT_OrdersBalances AS TT_OrdersBalances
	|		ON TT_InventoryNotYetInvoicedCumulative.Products = TT_OrdersBalances.Products
	|			AND TT_InventoryNotYetInvoicedCumulative.Characteristic = TT_OrdersBalances.Characteristic
	|			AND TT_InventoryNotYetInvoicedCumulative.Order = TT_OrdersBalances.SalesOrder
	|WHERE
	|	TT_OrdersBalances.QuantityBalance > TT_InventoryNotYetInvoicedCumulative.BaseQuantityCumulative - TT_InventoryNotYetInvoicedCumulative.BaseQuantity
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
	|	TT_Inventory.Price AS Price,
	|	TT_Inventory.DiscountMarkupPercent AS DiscountMarkupPercent,
	|	CASE
	|		WHEN (CAST(TT_Inventory.Quantity * TT_Inventory.Factor AS NUMBER(15, 3))) = TT_InventoryToBeInvoiced.BaseQuantity
	|			THEN TT_Inventory.Amount
	|		ELSE CAST((CAST((CAST(TT_InventoryToBeInvoiced.BaseQuantity / TT_Inventory.Factor AS NUMBER(15, 3))) * TT_Inventory.Price AS NUMBER(15, 2))) * (1 - TT_Inventory.DiscountMarkupPercent / 100) AS NUMBER(15, 2))
	|	END AS Amount,
	|	TT_Inventory.VATRate AS VATRate,
	|	CASE
	|		WHEN (CAST(TT_Inventory.Quantity * TT_Inventory.Factor AS NUMBER(15, 3))) = TT_InventoryToBeInvoiced.BaseQuantity
	|			THEN TT_Inventory.VATAmount
	|		WHEN &AmountIncludesVAT
	|			THEN CAST((CAST((CAST((CAST(TT_InventoryToBeInvoiced.BaseQuantity / TT_Inventory.Factor AS NUMBER(15, 3))) * TT_Inventory.Price AS NUMBER(15, 2))) * (1 - TT_Inventory.DiscountMarkupPercent / 100) AS NUMBER(15, 2))) * TT_Inventory.VATRate.Rate / (100 + TT_Inventory.VATRate.Rate) AS NUMBER(15, 2))
	|		ELSE CAST((CAST((CAST((CAST(TT_InventoryToBeInvoiced.BaseQuantity / TT_Inventory.Factor AS NUMBER(15, 3))) * TT_Inventory.Price AS NUMBER(15, 2))) * (1 - TT_Inventory.DiscountMarkupPercent / 100) AS NUMBER(15, 2))) * TT_Inventory.VATRate.Rate / 100 AS NUMBER(15, 2))
	|	END AS VATAmount,
	|	CASE
	|		WHEN (CAST(TT_Inventory.Quantity * TT_Inventory.Factor AS NUMBER(15, 3))) = TT_InventoryToBeInvoiced.BaseQuantity
	|			THEN TT_Inventory.Total
	|		WHEN &AmountIncludesVAT
	|			THEN CAST((CAST((CAST(TT_InventoryToBeInvoiced.BaseQuantity / TT_Inventory.Factor AS NUMBER(15, 3))) * TT_Inventory.Price AS NUMBER(15, 2))) * (1 - TT_Inventory.DiscountMarkupPercent / 100) AS NUMBER(15, 2))
	|		ELSE CAST((CAST((CAST((CAST(TT_InventoryToBeInvoiced.BaseQuantity / TT_Inventory.Factor AS NUMBER(15, 3))) * TT_Inventory.Price AS NUMBER(15, 2))) * (1 - TT_Inventory.DiscountMarkupPercent / 100) AS NUMBER(15, 2))) * (100 + TT_Inventory.VATRate.Rate) / 100 AS NUMBER(15, 2))
	|	END AS Total,
	|	TT_Inventory.Order AS Order,
	|	VALUE(Document.GoodsIssue.EmptyRef) AS GoodsIssue,
	|	TT_Inventory.Content AS Content,
	|	TT_Inventory.AutomaticDiscountsPercent AS AutomaticDiscountsPercent,
	|	TT_Inventory.AutomaticDiscountAmount AS AutomaticDiscountAmount,
	|	TT_Inventory.SerialNumbers AS SerialNumbers,
	|	TT_Inventory.PointInTime AS PointInTime,
	|	TT_Inventory.SalesRep AS SalesRep
	|INTO TT_InventoryToFillReserve
	|FROM
	|	TT_Inventory AS TT_Inventory
	|		INNER JOIN TT_InventoryToBeInvoiced AS TT_InventoryToBeInvoiced
	|		ON TT_Inventory.LineNumber = TT_InventoryToBeInvoiced.LineNumber
	|			AND TT_Inventory.Order = TT_InventoryToBeInvoiced.Order";
	
	
	If Constants.UseInventoryReservation.Get() AND ValueIsFilled(DocumentData.StructuralUnit) Then
		Query.Text = Query.Text + GetFillWorkOrderReserveColumnQueryText();
	Else
		Query.Text = StrReplace(Query.Text, "INTO TT_InventoryToFillReserve", "");
	EndIf;
	
	Query.Text = Query.Text + "
	|ORDER BY
	|	TT_Inventory.PointInTime,
	|	TT_Inventory.LineNumber";
	
	If FilterData.Property("OrdersArray") Then
		FilterString = "WorkOrder.Ref IN(&OrdersArray)";
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
			FilterString = FilterString + "WorkOrder." + FilterItem.Key + " = &" + FilterItem.Key;
			Query.SetParameter(FilterItem.Key, FilterItem.Value);
		EndDo;
	EndIf;
	Query.Text = StrReplace(Query.Text, "&SalesOrdersConditions", FilterString);
	Query.SetParameter("Ref", DocumentData.Ref);
	Query.SetParameter("Company", DriveServer.GetCompany(DocumentData.Company));
	Query.SetParameter("StructuralUnit", DocumentData.StructuralUnit);
	Query.SetParameter("AmountIncludesVAT", DocumentData.AmountIncludesVAT);
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	While SelectionDetailRecords.Next() Do
		NewLine = Inventory.Add();
		FillPropertyValues(NewLine, SelectionDetailRecords);
	EndDo;
	
EndProcedure

Procedure FillByWorkOrdersWorks(DocumentData, FilterData, Inventory) Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	WorkOrder.Ref AS Ref,
	|	WorkOrder.SalesRep AS SalesRep
	|INTO TT_SalesOrders
	|FROM
	|	Document.WorkOrder AS WorkOrder
	|WHERE
	|	&SalesOrdersConditions
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SalesInvoiceInventory.Order AS Order,
	|	SalesInvoiceInventory.Products AS Products,
	|	SalesInvoiceInventory.Characteristic AS Characteristic,
	|	SalesInvoiceInventory.Batch AS Batch,
	|	SUM(SalesInvoiceInventory.Quantity * ISNULL(UOM.Factor, 1)) AS BaseQuantity
	|INTO TT_AlreadyInvoiced
	|FROM
	|	Document.SalesInvoice.Inventory AS SalesInvoiceInventory
	|		INNER JOIN TT_SalesOrders AS TT_SalesOrders
	|		ON SalesInvoiceInventory.Order = TT_SalesOrders.Ref
	|		INNER JOIN Document.SalesInvoice AS SalesInvoiceDocument
	|		ON SalesInvoiceInventory.Ref = SalesInvoiceDocument.Ref
	|		INNER JOIN Catalog.Products AS ProductsCatalog
	|		ON SalesInvoiceInventory.Products = ProductsCatalog.Ref
	|		LEFT JOIN Catalog.UOM AS UOM
	|		ON SalesInvoiceInventory.MeasurementUnit = UOM.Ref
	|WHERE
	|	SalesInvoiceDocument.Posted
	|	AND SalesInvoiceInventory.Ref <> &Ref
	|
	|GROUP BY
	|	SalesInvoiceInventory.Batch,
	|	SalesInvoiceInventory.Order,
	|	SalesInvoiceInventory.Products,
	|	SalesInvoiceInventory.Characteristic
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	OrdersBalance.SalesOrder AS SalesOrder,
	|	OrdersBalance.Products AS Products,
	|	OrdersBalance.Characteristic AS Characteristic,
	|	SUM(OrdersBalance.QuantityBalance) AS QuantityBalance
	|INTO TT_OrdersBalances
	|FROM
	|	(SELECT
	|		WorkOrdersBalance.WorkOrder AS SalesOrder,
	|		WorkOrdersBalance.Products AS Products,
	|		WorkOrdersBalance.Characteristic AS Characteristic,
	|		WorkOrdersBalance.QuantityBalance AS QuantityBalance
	|	FROM
	|		AccumulationRegister.WorkOrders.Balance(
	|				,
	|				WorkOrder IN
	|					(SELECT
	|						TT_SalesOrders.Ref
	|					FROM
	|						TT_SalesOrders)) AS WorkOrdersBalance
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		WorkOrders.WorkOrder,
	|		WorkOrders.Products,
	|		WorkOrders.Characteristic,
	|		CASE
	|			WHEN WorkOrders.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN ISNULL(WorkOrders.Quantity, 0)
	|			ELSE -ISNULL(WorkOrders.Quantity, 0)
	|		END
	|	FROM
	|		AccumulationRegister.WorkOrders AS WorkOrders
	|	WHERE
	|		WorkOrders.Recorder = &Ref) AS OrdersBalance
	|		INNER JOIN Catalog.Products AS ProductsCatalog
	|		ON OrdersBalance.Products = ProductsCatalog.Ref
	|
	|GROUP BY
	|	OrdersBalance.SalesOrder,
	|	OrdersBalance.Products,
	|	OrdersBalance.Characteristic
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	WorkOrderWorks.LineNumber AS LineNumber,
	|	WorkOrderWorks.Products AS Products,
	|	WorkOrderWorks.Products.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem) AS ProductsTypeInventory,
	|	WorkOrderWorks.Characteristic AS Characteristic,
	|	WorkOrderWorks.Quantity * WorkOrderWorks.StandardHours AS Quantity,
	|	1 AS Factor,
	|	WorkOrderWorks.Price AS Price,
	|	WorkOrderWorks.DiscountMarkupPercent AS DiscountMarkupPercent,
	|	WorkOrderWorks.Amount AS Amount,
	|	WorkOrderWorks.VATRate AS VATRate,
	|	WorkOrderWorks.VATAmount AS VATAmount,
	|	WorkOrderWorks.Total AS Total,
	|	WorkOrderWorks.Ref AS Order,
	|	WorkOrderWorks.Content AS Content,
	|	WorkOrderWorks.AutomaticDiscountsPercent AS AutomaticDiscountsPercent,
	|	WorkOrderWorks.AutomaticDiscountAmount AS AutomaticDiscountAmount,
	|	WorkOrderWorks.Ref.PointInTime AS PointInTime,
	|	ProductsCatalog.MeasurementUnit AS MeasurementUnit,
	|	TT_SalesOrders.SalesRep AS SalesRep
	|INTO TT_Inventory
	|FROM
	|	Document.WorkOrder.Works AS WorkOrderWorks
	|		INNER JOIN TT_SalesOrders AS TT_SalesOrders
	|		ON WorkOrderWorks.Ref = TT_SalesOrders.Ref
	|		INNER JOIN Catalog.Products AS ProductsCatalog
	|		ON WorkOrderWorks.Products = ProductsCatalog.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_Inventory.LineNumber AS LineNumber,
	|	TT_Inventory.Products AS Products,
	|	TT_Inventory.Characteristic AS Characteristic,
	|	TT_Inventory.Order AS Order,
	|	TT_Inventory.Factor AS Factor,
	|	TT_Inventory.Quantity * TT_Inventory.Factor AS BaseQuantity,
	|	SUM(TT_InventoryCumulative.Quantity * TT_InventoryCumulative.Factor) AS BaseQuantityCumulative
	|INTO TT_InventoryCumulative
	|FROM
	|	TT_Inventory AS TT_Inventory
	|		INNER JOIN TT_Inventory AS TT_InventoryCumulative
	|		ON TT_Inventory.Products = TT_InventoryCumulative.Products
	|			AND TT_Inventory.Characteristic = TT_InventoryCumulative.Characteristic
	|			AND TT_Inventory.Order = TT_InventoryCumulative.Order
	|			AND TT_Inventory.LineNumber >= TT_InventoryCumulative.LineNumber
	|
	|GROUP BY
	|	TT_Inventory.LineNumber,
	|	TT_Inventory.Products,
	|	TT_Inventory.Characteristic,
	|	TT_Inventory.Order,
	|	TT_Inventory.Factor,
	|	TT_Inventory.Quantity * TT_Inventory.Factor
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_InventoryCumulative.LineNumber AS LineNumber,
	|	TT_InventoryCumulative.Products AS Products,
	|	TT_InventoryCumulative.Characteristic AS Characteristic,
	|	TT_InventoryCumulative.Order AS Order,
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
	|			AND TT_InventoryCumulative.Order = TT_AlreadyInvoiced.Order
	|WHERE
	|	ISNULL(TT_AlreadyInvoiced.BaseQuantity, 0) < TT_InventoryCumulative.BaseQuantityCumulative
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_InventoryNotYetInvoiced.LineNumber AS LineNumber,
	|	TT_InventoryNotYetInvoiced.Products AS Products,
	|	TT_InventoryNotYetInvoiced.Characteristic AS Characteristic,
	|	TT_InventoryNotYetInvoiced.Order AS Order,
	|	TT_InventoryNotYetInvoiced.Factor AS Factor,
	|	TT_InventoryNotYetInvoiced.BaseQuantity AS BaseQuantity,
	|	SUM(TT_InventoryNotYetInvoicedCumulative.BaseQuantity) AS BaseQuantityCumulative
	|INTO TT_InventoryNotYetInvoicedCumulative
	|FROM
	|	TT_InventoryNotYetInvoiced AS TT_InventoryNotYetInvoiced
	|		INNER JOIN TT_InventoryNotYetInvoiced AS TT_InventoryNotYetInvoicedCumulative
	|		ON TT_InventoryNotYetInvoiced.Products = TT_InventoryNotYetInvoicedCumulative.Products
	|			AND TT_InventoryNotYetInvoiced.Characteristic = TT_InventoryNotYetInvoicedCumulative.Characteristic
	|			AND TT_InventoryNotYetInvoiced.Order = TT_InventoryNotYetInvoicedCumulative.Order
	|			AND TT_InventoryNotYetInvoiced.LineNumber >= TT_InventoryNotYetInvoicedCumulative.LineNumber
	|
	|GROUP BY
	|	TT_InventoryNotYetInvoiced.LineNumber,
	|	TT_InventoryNotYetInvoiced.Products,
	|	TT_InventoryNotYetInvoiced.Characteristic,
	|	TT_InventoryNotYetInvoiced.Order,
	|	TT_InventoryNotYetInvoiced.Factor,
	|	TT_InventoryNotYetInvoiced.BaseQuantity
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_InventoryNotYetInvoicedCumulative.LineNumber AS LineNumber,
	|	TT_InventoryNotYetInvoicedCumulative.Products AS Products,
	|	TT_InventoryNotYetInvoicedCumulative.Characteristic AS Characteristic,
	|	TT_InventoryNotYetInvoicedCumulative.Order AS Order,
	|	TT_InventoryNotYetInvoicedCumulative.Factor AS Factor,
	|	CASE
	|		WHEN TT_OrdersBalances.QuantityBalance > TT_InventoryNotYetInvoicedCumulative.BaseQuantityCumulative
	|			THEN TT_InventoryNotYetInvoicedCumulative.BaseQuantity
	|		WHEN TT_OrdersBalances.QuantityBalance > TT_InventoryNotYetInvoicedCumulative.BaseQuantityCumulative - TT_InventoryNotYetInvoicedCumulative.BaseQuantity
	|			THEN TT_OrdersBalances.QuantityBalance - (TT_InventoryNotYetInvoicedCumulative.BaseQuantityCumulative - TT_InventoryNotYetInvoicedCumulative.BaseQuantity)
	|	END AS BaseQuantity
	|INTO TT_InventoryToBeInvoiced
	|FROM
	|	TT_InventoryNotYetInvoicedCumulative AS TT_InventoryNotYetInvoicedCumulative
	|		INNER JOIN TT_OrdersBalances AS TT_OrdersBalances
	|		ON TT_InventoryNotYetInvoicedCumulative.Products = TT_OrdersBalances.Products
	|			AND TT_InventoryNotYetInvoicedCumulative.Characteristic = TT_OrdersBalances.Characteristic
	|			AND TT_InventoryNotYetInvoicedCumulative.Order = TT_OrdersBalances.SalesOrder
	|WHERE
	|	TT_OrdersBalances.QuantityBalance > TT_InventoryNotYetInvoicedCumulative.BaseQuantityCumulative - TT_InventoryNotYetInvoicedCumulative.BaseQuantity
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_Inventory.LineNumber AS LineNumber,
	|	TT_Inventory.Products AS Products,
	|	TT_Inventory.ProductsTypeInventory AS ProductsTypeInventory,
	|	TT_Inventory.Characteristic AS Characteristic,
	|	VALUE(Catalog.ProductsBatches.EmptyRef) AS Batch,
	|	CASE
	|		WHEN (CAST(TT_Inventory.Quantity * TT_Inventory.Factor AS NUMBER(15, 3))) = TT_InventoryToBeInvoiced.BaseQuantity
	|			THEN TT_Inventory.Quantity
	|		ELSE CAST(TT_InventoryToBeInvoiced.BaseQuantity / TT_Inventory.Factor AS NUMBER(15, 3))
	|	END AS Quantity,
	|	TT_Inventory.MeasurementUnit AS MeasurementUnit,
	|	TT_Inventory.Factor AS Factor,
	|	TT_Inventory.Price AS Price,
	|	TT_Inventory.DiscountMarkupPercent AS DiscountMarkupPercent,
	|	CASE
	|		WHEN (CAST(TT_Inventory.Quantity * TT_Inventory.Factor AS NUMBER(15, 3))) = TT_InventoryToBeInvoiced.BaseQuantity
	|			THEN TT_Inventory.Amount
	|		ELSE CAST((CAST((CAST(TT_InventoryToBeInvoiced.BaseQuantity / TT_Inventory.Factor AS NUMBER(15, 3))) * TT_Inventory.Price AS NUMBER(15, 2))) * (1 - TT_Inventory.DiscountMarkupPercent / 100) AS NUMBER(15, 2))
	|	END AS Amount,
	|	TT_Inventory.VATRate AS VATRate,
	|	CASE
	|		WHEN (CAST(TT_Inventory.Quantity * TT_Inventory.Factor AS NUMBER(15, 3))) = TT_InventoryToBeInvoiced.BaseQuantity
	|			THEN TT_Inventory.VATAmount
	|		WHEN &AmountIncludesVAT
	|			THEN CAST((CAST((CAST((CAST(TT_InventoryToBeInvoiced.BaseQuantity / TT_Inventory.Factor AS NUMBER(15, 3))) * TT_Inventory.Price AS NUMBER(15, 2))) * (1 - TT_Inventory.DiscountMarkupPercent / 100) AS NUMBER(15, 2))) * TT_Inventory.VATRate.Rate / (100 + TT_Inventory.VATRate.Rate) AS NUMBER(15, 2))
	|		ELSE CAST((CAST((CAST((CAST(TT_InventoryToBeInvoiced.BaseQuantity / TT_Inventory.Factor AS NUMBER(15, 3))) * TT_Inventory.Price AS NUMBER(15, 2))) * (1 - TT_Inventory.DiscountMarkupPercent / 100) AS NUMBER(15, 2))) * TT_Inventory.VATRate.Rate / 100 AS NUMBER(15, 2))
	|	END AS VATAmount,
	|	CASE
	|		WHEN (CAST(TT_Inventory.Quantity * TT_Inventory.Factor AS NUMBER(15, 3))) = TT_InventoryToBeInvoiced.BaseQuantity
	|			THEN TT_Inventory.Total
	|		WHEN &AmountIncludesVAT
	|			THEN CAST((CAST((CAST(TT_InventoryToBeInvoiced.BaseQuantity / TT_Inventory.Factor AS NUMBER(15, 3))) * TT_Inventory.Price AS NUMBER(15, 2))) * (1 - TT_Inventory.DiscountMarkupPercent / 100) AS NUMBER(15, 2))
	|		ELSE CAST((CAST((CAST((CAST(TT_InventoryToBeInvoiced.BaseQuantity / TT_Inventory.Factor AS NUMBER(15, 3))) * TT_Inventory.Price AS NUMBER(15, 2))) * (1 - TT_Inventory.DiscountMarkupPercent / 100) AS NUMBER(15, 2))) * (100 + TT_Inventory.VATRate.Rate) / 100 AS NUMBER(15, 2))
	|	END AS Total,
	|	TT_Inventory.Order AS Order,
	|	VALUE(Document.GoodsIssue.EmptyRef) AS GoodsIssue,
	|	TT_Inventory.Content AS Content,
	|	TT_Inventory.AutomaticDiscountsPercent AS AutomaticDiscountsPercent,
	|	TT_Inventory.AutomaticDiscountAmount AS AutomaticDiscountAmount,
	|	VALUE(Catalog.SerialNumbers.EmptyRef) AS SerialNumbers,
	|	TT_Inventory.PointInTime AS PointInTime,
	|	TT_Inventory.SalesRep AS SalesRep
	|FROM
	|	TT_Inventory AS TT_Inventory
	|		INNER JOIN TT_InventoryToBeInvoiced AS TT_InventoryToBeInvoiced
	|		ON TT_Inventory.LineNumber = TT_InventoryToBeInvoiced.LineNumber
	|			AND TT_Inventory.Order = TT_InventoryToBeInvoiced.Order
	|
	|ORDER BY
	|	PointInTime,
	|	LineNumber";
	
	If FilterData.Property("OrdersArray") Then
		FilterString = "WorkOrder.Ref IN(&OrdersArray)";
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
			FilterString = FilterString + "WorkOrder." + FilterItem.Key + " = &" + FilterItem.Key;
			Query.SetParameter(FilterItem.Key, FilterItem.Value);
		EndDo;
	EndIf;
	Query.Text = StrReplace(Query.Text, "&SalesOrdersConditions", FilterString);
	Query.SetParameter("Ref", DocumentData.Ref);
	Query.SetParameter("Company", DriveServer.GetCompany(DocumentData.Company));
	Query.SetParameter("StructuralUnit", DocumentData.StructuralUnit);
	Query.SetParameter("AmountIncludesVAT", DocumentData.AmountIncludesVAT);
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	While SelectionDetailRecords.Next() Do
		NewLine = Inventory.Add();
		FillPropertyValues(NewLine, SelectionDetailRecords);
	EndDo;
	
EndProcedure

Procedure FillByGoodsIssues(DocumentData, FilterData, Inventory) Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	GoodsIssue.Ref AS Ref,
	|	GoodsIssue.PointInTime AS PointInTime
	|INTO TT_GoodsIssues
	|FROM
	|	Document.GoodsIssue AS GoodsIssue
	|WHERE
	|	&GoodsIssuesConditions
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SalesInvoiceInventory.Order AS Order,
	|	SalesInvoiceInventory.GoodsIssue AS GoodsIssue,
	|	SalesInvoiceInventory.Products AS Products,
	|	SalesInvoiceInventory.Characteristic AS Characteristic,
	|	SalesInvoiceInventory.Batch AS Batch,
	|	SUM(SalesInvoiceInventory.Quantity * ISNULL(UOM.Factor, 1)) AS BaseQuantity
	|INTO TT_AlreadyInvoiced
	|FROM
	|	Document.SalesInvoice.Inventory AS SalesInvoiceInventory
	|		INNER JOIN TT_GoodsIssues AS TT_GoodsIssues
	|		ON SalesInvoiceInventory.GoodsIssue = TT_GoodsIssues.Ref
	|		INNER JOIN Document.SalesInvoice AS SalesInvoiceDocument
	|		ON SalesInvoiceInventory.Ref = SalesInvoiceDocument.Ref
	|		INNER JOIN Catalog.Products AS ProductsCatalog
	|		ON SalesInvoiceInventory.Products = ProductsCatalog.Ref
	|		LEFT JOIN Catalog.UOM AS UOM
	|		ON SalesInvoiceInventory.MeasurementUnit = UOM.Ref
	|WHERE
	|	SalesInvoiceDocument.Posted
	|	AND SalesInvoiceInventory.Ref <> &Ref
	|
	|GROUP BY
	|	SalesInvoiceInventory.Batch,
	|	SalesInvoiceInventory.Order,
	|	SalesInvoiceInventory.Products,
	|	SalesInvoiceInventory.Characteristic,
	|	SalesInvoiceInventory.GoodsIssue
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	GoodsIssueBalance.SalesOrder AS SalesOrder,
	|	GoodsIssueBalance.GoodsIssue AS GoodsIssue,
	|	GoodsIssueBalance.Products AS Products,
	|	GoodsIssueBalance.Characteristic AS Characteristic,
	|	SUM(GoodsIssueBalance.QuantityBalance) AS QuantityBalance
	|INTO TT_GoodsIssueBalance
	|FROM
	|	(SELECT
	|		GoodsIssueBalance.SalesOrder AS SalesOrder,
	|		GoodsIssueBalance.GoodsIssue AS GoodsIssue,
	|		GoodsIssueBalance.Products AS Products,
	|		GoodsIssueBalance.Characteristic AS Characteristic,
	|		GoodsIssueBalance.QuantityBalance AS QuantityBalance
	|	FROM
	|		AccumulationRegister.GoodsShippedNotInvoiced.Balance(
	|				,
	|				GoodsIssue IN
	|					(SELECT
	|						TT_GoodsIssues.Ref
	|					FROM
	|						TT_GoodsIssues)) AS GoodsIssueBalance
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsGoodsIssue.SalesOrder,
	|		DocumentRegisterRecordsGoodsIssue.GoodsIssue,
	|		DocumentRegisterRecordsGoodsIssue.Products,
	|		DocumentRegisterRecordsGoodsIssue.Characteristic,
	|		CASE
	|			WHEN DocumentRegisterRecordsGoodsIssue.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN ISNULL(DocumentRegisterRecordsGoodsIssue.Quantity, 0)
	|			ELSE -ISNULL(DocumentRegisterRecordsGoodsIssue.Quantity, 0)
	|		END
	|	FROM
	|		AccumulationRegister.GoodsShippedNotInvoiced AS DocumentRegisterRecordsGoodsIssue
	|	WHERE
	|		DocumentRegisterRecordsGoodsIssue.Recorder = &Ref) AS GoodsIssueBalance
	|		INNER JOIN Catalog.Products AS ProductsCatalog
	|		ON GoodsIssueBalance.Products = ProductsCatalog.Ref
	|
	|GROUP BY
	|	GoodsIssueBalance.SalesOrder,
	|	GoodsIssueBalance.GoodsIssue,
	|	GoodsIssueBalance.Products,
	|	GoodsIssueBalance.Characteristic
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	GoodsIssueProducts.LineNumber AS LineNumber,
	|	GoodsIssueProducts.Products AS Products,
	|	GoodsIssueProducts.Products.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem) AS ProductsTypeInventory,
	|	GoodsIssueProducts.Characteristic AS Characteristic,
	|	GoodsIssueProducts.Batch AS Batch,
	|	GoodsIssueProducts.Quantity AS Quantity,
	|	GoodsIssueProducts.MeasurementUnit AS MeasurementUnit,
	|	ISNULL(UOM.Factor, 1) AS Factor,
	|	GoodsIssueProducts.Ref AS GoodsIssue,
	|	GoodsIssueProducts.Order AS Order,
	|	GoodsIssueProducts.Contract AS Contract,
	|	GoodsIssueProducts.SerialNumbers AS SerialNumbers,
	|	TT_GoodsIssues.PointInTime AS PointInTime,
	|	GoodsIssueProducts.InventoryGLAccount AS InventoryGLAccount,
	|	GoodsIssueProducts.GoodsShippedNotInvoicedGLAccount AS GoodsShippedNotInvoicedGLAccount,
	|	GoodsIssueProducts.UnearnedRevenueGLAccount AS UnearnedRevenueGLAccount,
	|	GoodsIssueProducts.RevenueGLAccount AS RevenueGLAccount,
	|	GoodsIssueProducts.COGSGLAccount AS COGSGLAccount
	|INTO TT_Inventory
	|FROM
	|	Document.GoodsIssue.Products AS GoodsIssueProducts
	|		INNER JOIN TT_GoodsIssues AS TT_GoodsIssues
	|		ON GoodsIssueProducts.Ref = TT_GoodsIssues.Ref
	|		INNER JOIN Catalog.Products AS ProductsCatalog
	|		ON GoodsIssueProducts.Products = ProductsCatalog.Ref
	|		LEFT JOIN Catalog.UOM AS UOM
	|		ON GoodsIssueProducts.MeasurementUnit = UOM.Ref
	|WHERE
	|	(GoodsIssueProducts.Contract = &Contract
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
	|	TT_Inventory.GoodsIssue AS GoodsIssue,
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
	|			AND TT_Inventory.GoodsIssue = TT_InventoryCumulative.GoodsIssue
	|			AND TT_Inventory.LineNumber >= TT_InventoryCumulative.LineNumber
	|
	|GROUP BY
	|	TT_Inventory.LineNumber,
	|	TT_Inventory.Products,
	|	TT_Inventory.Characteristic,
	|	TT_Inventory.Batch,
	|	TT_Inventory.Order,
	|	TT_Inventory.GoodsIssue,
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
	|	TT_InventoryCumulative.GoodsIssue AS GoodsIssue,
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
	|			AND TT_InventoryCumulative.GoodsIssue = TT_AlreadyInvoiced.GoodsIssue
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
	|	TT_InventoryNotYetInvoiced.GoodsIssue AS GoodsIssue,
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
	|			AND TT_InventoryNotYetInvoiced.GoodsIssue = TT_InventoryNotYetInvoicedCumulative.GoodsIssue
	|			AND TT_InventoryNotYetInvoiced.LineNumber >= TT_InventoryNotYetInvoicedCumulative.LineNumber
	|
	|GROUP BY
	|	TT_InventoryNotYetInvoiced.LineNumber,
	|	TT_InventoryNotYetInvoiced.Products,
	|	TT_InventoryNotYetInvoiced.Characteristic,
	|	TT_InventoryNotYetInvoiced.Batch,
	|	TT_InventoryNotYetInvoiced.Order,
	|	TT_InventoryNotYetInvoiced.GoodsIssue,
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
	|	TT_InventoryNotYetInvoicedCumulative.GoodsIssue AS GoodsIssue,
	|	TT_InventoryNotYetInvoicedCumulative.Factor AS Factor,
	|	CASE
	|		WHEN TT_GoodsIssueBalance.QuantityBalance > TT_InventoryNotYetInvoicedCumulative.BaseQuantityCumulative
	|			THEN TT_InventoryNotYetInvoicedCumulative.BaseQuantity
	|		WHEN TT_GoodsIssueBalance.QuantityBalance > TT_InventoryNotYetInvoicedCumulative.BaseQuantityCumulative - TT_InventoryNotYetInvoicedCumulative.BaseQuantity
	|			THEN TT_GoodsIssueBalance.QuantityBalance - (TT_InventoryNotYetInvoicedCumulative.BaseQuantityCumulative - TT_InventoryNotYetInvoicedCumulative.BaseQuantity)
	|	END AS BaseQuantity
	|INTO TT_InventoryToBeInvoiced
	|FROM
	|	TT_InventoryNotYetInvoicedCumulative AS TT_InventoryNotYetInvoicedCumulative
	|		INNER JOIN TT_GoodsIssueBalance AS TT_GoodsIssueBalance
	|		ON TT_InventoryNotYetInvoicedCumulative.Products = TT_GoodsIssueBalance.Products
	|			AND TT_InventoryNotYetInvoicedCumulative.Characteristic = TT_GoodsIssueBalance.Characteristic
	|			AND TT_InventoryNotYetInvoicedCumulative.Order = TT_GoodsIssueBalance.SalesOrder
	|			AND TT_InventoryNotYetInvoicedCumulative.GoodsIssue = TT_GoodsIssueBalance.GoodsIssue
	|WHERE
	|	TT_GoodsIssueBalance.QuantityBalance > TT_InventoryNotYetInvoicedCumulative.BaseQuantityCumulative - TT_InventoryNotYetInvoicedCumulative.BaseQuantity
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
	|	TT_Inventory.GoodsIssue AS GoodsIssue,
	|	TT_Inventory.SerialNumbers AS SerialNumbers,
	|	TT_Inventory.PointInTime AS PointInTime,
	|	SalesOrderInventory.Price AS Price,
	|	ISNULL(SalesOrderInventory.DiscountMarkupPercent, 0) AS DiscountMarkupPercent,
	|	CASE
	|		WHEN AccountingPolicySliceLast.RegisteredForVAT
	|			THEN ISNULL(SalesOrderInventory.VATRate, CatProducts.VATRate)
	|		ELSE VALUE(Catalog.VATRates.Exempt)
	|	END AS VATRate,
	|	ISNULL(SalesOrderInventory.AutomaticDiscountsPercent, 0) AS AutomaticDiscountsPercent,
	|	ISNULL(TT_Inventory.Quantity * SalesOrderInventory.AutomaticDiscountAmount / SalesOrderInventory.Quantity, 0) AS AutomaticDiscountAmount,
	|	ISNULL(SalesOrderInventory.Quantity, 0) AS QuantityOrd,
	|	TT_Inventory.InventoryGLAccount AS InventoryGLAccount,
	|	TT_Inventory.GoodsShippedNotInvoicedGLAccount AS GoodsShippedNotInvoicedGLAccount,
	|	TT_Inventory.UnearnedRevenueGLAccount AS UnearnedRevenueGLAccount,
	|	TT_Inventory.RevenueGLAccount AS RevenueGLAccount,
	|	TT_Inventory.COGSGLAccount AS COGSGLAccount
	|INTO TT_WithOrders
	|FROM
	|	TT_Inventory AS TT_Inventory
	|		INNER JOIN TT_InventoryToBeInvoiced AS TT_InventoryToBeInvoiced
	|		ON TT_Inventory.LineNumber = TT_InventoryToBeInvoiced.LineNumber
	|			AND TT_Inventory.Order = TT_InventoryToBeInvoiced.Order
	|			AND TT_Inventory.GoodsIssue = TT_InventoryToBeInvoiced.GoodsIssue
	|		LEFT JOIN Document.SalesOrder.Inventory AS SalesOrderInventory
	|		ON TT_Inventory.Order = SalesOrderInventory.Ref
	|			AND TT_Inventory.Products = SalesOrderInventory.Products
	|			AND TT_Inventory.Characteristic = SalesOrderInventory.Characteristic
	|			AND TT_Inventory.MeasurementUnit = SalesOrderInventory.MeasurementUnit
	|		LEFT JOIN Catalog.Products AS CatProducts
	|		ON TT_Inventory.Products = CatProducts.Ref
	|		LEFT JOIN InformationRegister.AccountingPolicy.SliceLast(, Company = &Company) AS AccountingPolicySliceLast
	|		ON (TRUE)
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
	|	SalesOrder.SalesRep AS SalesRep,
	|	TT_WithOrders.Contract AS Contract,
	|	TT_WithOrders.GoodsIssue AS GoodsIssue,
	|	TT_WithOrders.PointInTime AS PointInTime,
	|	MAX(ISNULL(ISNULL(TT_WithOrders.Price, PricesSliceLast.Price), 0)) AS Price,
	|	MAX(TT_WithOrders.DiscountMarkupPercent) AS DiscountMarkupPercent,
	|	TT_WithOrders.VATRate AS VATRate,
	|	MAX(TT_WithOrders.AutomaticDiscountsPercent) AS AutomaticDiscountsPercent,
	|	MAX(TT_WithOrders.AutomaticDiscountAmount) AS AutomaticDiscountAmount,
	|	MAX(TT_WithOrders.QuantityOrd) AS QuantityOrd,
	|	TT_WithOrders.InventoryGLAccount AS InventoryGLAccount,
	|	TT_WithOrders.GoodsShippedNotInvoicedGLAccount AS GoodsShippedNotInvoicedGLAccount,
	|	TT_WithOrders.UnearnedRevenueGLAccount AS UnearnedRevenueGLAccount,
	|	TT_WithOrders.RevenueGLAccount AS RevenueGLAccount,
	|	TT_WithOrders.COGSGLAccount AS COGSGLAccount
	|FROM
	|	TT_WithOrders AS TT_WithOrders
	|		LEFT JOIN InformationRegister.Prices.SliceLast AS PricesSliceLast
	|		ON TT_WithOrders.Products = PricesSliceLast.Products
	|			AND TT_WithOrders.Characteristic = PricesSliceLast.Characteristic
	|			AND TT_WithOrders.MeasurementUnit = PricesSliceLast.MeasurementUnit
	|			AND TT_WithOrders.Contract.PriceKind = PricesSliceLast.PriceKind
	|		LEFT JOIN Document.SalesOrder AS SalesOrder
	|		ON TT_WithOrders.Order = SalesOrder.Ref
	|
	|GROUP BY
	|	TT_WithOrders.MeasurementUnit,
	|	TT_WithOrders.Products,
	|	TT_WithOrders.ProductsTypeInventory,
	|	TT_WithOrders.Order,
	|	SalesOrder.SalesRep,
	|	TT_WithOrders.Batch,
	|	TT_WithOrders.Characteristic,
	|	TT_WithOrders.Contract,
	|	TT_WithOrders.GoodsIssue,
	|	TT_WithOrders.PointInTime,
	|	TT_WithOrders.VATRate,
	|	TT_WithOrders.LineNumber,
	|	TT_WithOrders.Quantity,
	|	TT_WithOrders.Factor,
	|	TT_WithOrders.InventoryGLAccount,
	|	TT_WithOrders.GoodsShippedNotInvoicedGLAccount,
	|	TT_WithOrders.UnearnedRevenueGLAccount,
	|	TT_WithOrders.RevenueGLAccount,
	|	TT_WithOrders.COGSGLAccount";
	
	Contract = Undefined;
	
	FilterData.Property("Contract", Contract);
	Query.SetParameter("Contract", Contract);
	
	If FilterData.Property("GoodsIssuesArray") Then
		FilterString = "GoodsIssue.Ref IN(&GoodsIssuesArray)";
		Query.SetParameter("GoodsIssuesArray", FilterData.GoodsIssuesArray);
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
			
			FilterString = FilterString + "GoodsIssue." + FilterItem.Key + " = &" + FilterItem.Key;
			Query.SetParameter(FilterItem.Key, FilterItem.Value);
			
		EndDo;
		
	EndIf;
	
	Query.Text = StrReplace(Query.Text, "&GoodsIssuesConditions", FilterString);
	Query.SetParameter("Ref", DocumentData.Ref);
	Query.SetParameter("Company", DriveServer.GetCompany(DocumentData.Company));
	
	StructureData = New Structure;
	StructureData.Insert("ObjectParameters", DocumentData);
	
	Inventory.Clear();
	
	Result = Query.Execute();
	Selection = Result.Select();
	
	While Selection.Next() Do
		
		TabularSectionRow = Inventory.Add();
		
		FillPropertyValues(TabularSectionRow, Selection);
		
		TabularSectionRow.Amount = TabularSectionRow.Quantity * TabularSectionRow.Price;
		
		If TabularSectionRow.DiscountMarkupPercent = 100 Then
			
			TabularSectionRow.Amount = 0;
			
		ElsIf Not TabularSectionRow.DiscountMarkupPercent = 0
			AND Not TabularSectionRow.Quantity = 0 Then
			
			TabularSectionRow.Amount = TabularSectionRow.Amount * (1 - TabularSectionRow.DiscountMarkupPercent / 100);
			
		EndIf;
		
		VATRate = DriveReUse.GetVATRateValue(TabularSectionRow.VATRate);
	
		TabularSectionRow.VATAmount = ?(DocumentData.AmountIncludesVAT, 
										TabularSectionRow.Amount - (TabularSectionRow.Amount) / ((VATRate + 100) / 100),
										TabularSectionRow.Amount * VATRate / 100);

		TabularSectionRow.Total = TabularSectionRow.Amount + ?(DocumentData.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
		
	EndDo;
	
	If FilterData.Property("GoodsIssuesArray") Then
		GLAccountsInDocuments.FillTabSectionFromProductGLAccounts(DocumentData.Ref, FilterData.GoodsIssuesArray);
	EndIf;
	
EndProcedure

Procedure FillColumnReserveByReserves(DocumentData, Inventory) Export

	Query = New Query;
	Query.Text =
	"SELECT
	|	TableInventory.LineNumber AS LineNumber,
	|	CAST(TableInventory.Products AS Catalog.Products) AS Products,
	|	TableInventory.ProductsTypeInventory AS ProductsTypeInventory,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.Quantity AS Quantity,
	|	0 AS Reserve,
	|	TableInventory.MeasurementUnit AS MeasurementUnit,
	|	TableInventory.Price AS Price,
	|	TableInventory.DiscountMarkupPercent AS DiscountMarkupPercent,
	|	TableInventory.Amount AS Amount,
	|	TableInventory.VATRate AS VATRate,
	|	TableInventory.VATAmount AS VATAmount,
	|	TableInventory.Total AS Total,
	|	CASE
	|		WHEN &OrderInHeader
	|			THEN &Order
	|		WHEN TableInventory.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|				AND TableInventory.Order <> VALUE(Document.WorkOrder.EmptyRef)
	|			THEN TableInventory.Order
	|		ELSE UNDEFINED
	|	END AS Order,
	|	TableInventory.Content AS Content,
	|	TableInventory.AutomaticDiscountsPercent AS AutomaticDiscountsPercent,
	|	TableInventory.AutomaticDiscountAmount AS AutomaticDiscountAmount,
	|	TableInventory.ConnectionKey AS ConnectionKey,
	|	TableInventory.SerialNumbers AS SerialNumbers
	|INTO TT_TableInventory
	|FROM
	|	&TableInventory AS TableInventory
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_TableInventory.LineNumber AS LineNumber,
	|	TT_TableInventory.Products AS Products,
	|	TT_TableInventory.ProductsTypeInventory AS ProductsTypeInventory,
	|	TT_TableInventory.Characteristic AS Characteristic,
	|	TT_TableInventory.Batch AS Batch,
	|	TT_TableInventory.Quantity AS Quantity,
	|	TT_TableInventory.Reserve AS Reserve,
	|	TT_TableInventory.MeasurementUnit AS MeasurementUnit,
	|	ISNULL(UOM.Factor, 1) AS Factor,
	|	TT_TableInventory.Price AS Price,
	|	TT_TableInventory.DiscountMarkupPercent AS DiscountMarkupPercent,
	|	TT_TableInventory.Amount AS Amount,
	|	TT_TableInventory.VATRate AS VATRate,
	|	TT_TableInventory.VATAmount AS VATAmount,
	|	TT_TableInventory.Total AS Total,
	|	TT_TableInventory.Order AS Order,
	|	TT_TableInventory.Content AS Content,
	|	TT_TableInventory.AutomaticDiscountsPercent AS AutomaticDiscountsPercent,
	|	TT_TableInventory.AutomaticDiscountAmount AS AutomaticDiscountAmount,
	|	TT_TableInventory.ConnectionKey AS ConnectionKey,
	|	TT_TableInventory.SerialNumbers AS SerialNumbers
	|INTO TT_InventoryToFillReserve
	|FROM
	|	TT_TableInventory AS TT_TableInventory
	|		LEFT JOIN Catalog.UOM AS UOM
	|		ON TT_TableInventory.MeasurementUnit = UOM.Ref";
	
	Query.Text = Query.Text + GetFillReserveColumnQueryText();
	
	If DocumentData.Property("SalesOrderPosition") Then
		OrderInHeader = DocumentData.SalesOrderPosition = Enums.AttributeStationing.InHeader;
	Else
		OrderInHeader = False;
	EndIf;
	Query.SetParameter("TableInventory", Inventory.Unload());
	Query.SetParameter("OrderInHeader", OrderInHeader);
	Query.SetParameter("Order", ?(DocumentData.Property("Order") AND ValueIsFilled(DocumentData.Order), DocumentData.Order, Undefined));
	Query.SetParameter("Ref", DocumentData.Ref);
	Query.SetParameter("Company", DriveServer.GetCompany(DocumentData.Company));
	Query.SetParameter("StructuralUnit", DocumentData.StructuralUnit);
	
	Inventory.Load(Query.Execute().Unload());
	
EndProcedure

Function GetFillReserveColumnQueryText()
	
	Return DriveClientServer.GetQueryDelimeter() +
	"SELECT
	|	InventoryBalances.Products AS Products,
	|	InventoryBalances.Characteristic AS Characteristic,
	|	InventoryBalances.Batch AS Batch,
	|	InventoryBalances.SalesOrder AS Order,
	|	SUM(InventoryBalances.QuantityBalance) AS QuantityBalance
	|INTO TT_InventoryBalances
	|FROM
	|	(SELECT
	|		InventoryBalances.SalesOrder AS SalesOrder,
	|		InventoryBalances.Products AS Products,
	|		InventoryBalances.Characteristic AS Characteristic,
	|		InventoryBalances.Batch AS Batch,
	|		InventoryBalances.QuantityBalance AS QuantityBalance
	|	FROM
	|		AccumulationRegister.Inventory.Balance(
	|				,
	|				Company = &Company
	|					AND StructuralUnit = &StructuralUnit
	|					AND SalesOrder <> UNDEFINED
	|					AND (Products, Characteristic, Batch, SalesOrder) IN
	|						(SELECT
	|							TT_InventoryToFillReserve.Products,
	|							TT_InventoryToFillReserve.Characteristic,
	|							TT_InventoryToFillReserve.Batch,
	|							TT_InventoryToFillReserve.Order
	|						FROM
	|							TT_InventoryToFillReserve AS TT_InventoryToFillReserve)) AS InventoryBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsInventory.SalesOrder,
	|		DocumentRegisterRecordsInventory.Products,
	|		DocumentRegisterRecordsInventory.Characteristic,
	|		DocumentRegisterRecordsInventory.Batch,
	|		CASE
	|			WHEN DocumentRegisterRecordsInventory.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN ISNULL(DocumentRegisterRecordsInventory.Quantity, 0)
	|			ELSE -ISNULL(DocumentRegisterRecordsInventory.Quantity, 0)
	|		END
	|	FROM
	|		AccumulationRegister.Inventory AS DocumentRegisterRecordsInventory
	|	WHERE
	|		DocumentRegisterRecordsInventory.Recorder = &Ref
	|		AND DocumentRegisterRecordsInventory.SalesOrder <> UNDEFINED) AS InventoryBalances
	|
	|GROUP BY
	|	InventoryBalances.SalesOrder,
	|	InventoryBalances.Products,
	|	InventoryBalances.Characteristic,
	|	InventoryBalances.Batch
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_InventoryToFillReserve.LineNumber AS LineNumber,
	|	TT_InventoryToFillReserve.Products AS Products,
	|	TT_InventoryToFillReserve.Characteristic AS Characteristic,
	|	TT_InventoryToFillReserve.Batch AS Batch,
	|	TT_InventoryToFillReserve.Order AS Order,
	|	TT_InventoryToFillReserve.Factor AS Factor,
	|	TT_InventoryToFillReserve.Quantity * TT_InventoryToFillReserve.Factor AS BaseQuantity,
	|	SUM(TT_InventoryToFillReserveCumulative.Quantity * TT_InventoryToFillReserveCumulative.Factor) AS BaseQuantityCumulative
	|INTO TT_InventoryToFillReserveCumulative
	|FROM
	|	TT_InventoryToFillReserve AS TT_InventoryToFillReserve
	|		INNER JOIN TT_InventoryToFillReserve AS TT_InventoryToFillReserveCumulative
	|		ON TT_InventoryToFillReserve.Products = TT_InventoryToFillReserveCumulative.Products
	|			AND TT_InventoryToFillReserve.Characteristic = TT_InventoryToFillReserveCumulative.Characteristic
	|			AND TT_InventoryToFillReserve.Batch = TT_InventoryToFillReserveCumulative.Batch
	|			AND TT_InventoryToFillReserve.Order = TT_InventoryToFillReserveCumulative.Order
	|			AND TT_InventoryToFillReserve.LineNumber >= TT_InventoryToFillReserveCumulative.LineNumber
	|
	|GROUP BY
	|	TT_InventoryToFillReserve.LineNumber,
	|	TT_InventoryToFillReserve.Characteristic,
	|	TT_InventoryToFillReserve.Batch,
	|	TT_InventoryToFillReserve.Order,
	|	TT_InventoryToFillReserve.Products,
	|	TT_InventoryToFillReserve.Factor,
	|	TT_InventoryToFillReserve.Quantity * TT_InventoryToFillReserve.Factor
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_InventoryToFillReserveCumulative.LineNumber AS LineNumber,
	|	TT_InventoryToFillReserveCumulative.Order AS Order,
	|	TT_InventoryToFillReserveCumulative.Factor AS Factor,
	|	TT_InventoryToFillReserveCumulative.BaseQuantity AS BaseQuantity,
	|	CASE
	|		WHEN TT_InventoryBalances.QuantityBalance > TT_InventoryToFillReserveCumulative.BaseQuantityCumulative
	|			THEN TT_InventoryToFillReserveCumulative.BaseQuantity
	|		WHEN TT_InventoryBalances.QuantityBalance > TT_InventoryToFillReserveCumulative.BaseQuantityCumulative - TT_InventoryToFillReserveCumulative.BaseQuantity
	|			THEN TT_InventoryBalances.QuantityBalance - (TT_InventoryToFillReserveCumulative.BaseQuantityCumulative - TT_InventoryToFillReserveCumulative.BaseQuantity)
	|		ELSE 0
	|	END AS BaseReserve
	|INTO TT_InventoryReserve
	|FROM
	|	TT_InventoryToFillReserveCumulative AS TT_InventoryToFillReserveCumulative
	|		LEFT JOIN TT_InventoryBalances AS TT_InventoryBalances
	|		ON TT_InventoryToFillReserveCumulative.Products = TT_InventoryBalances.Products
	|			AND TT_InventoryToFillReserveCumulative.Characteristic = TT_InventoryBalances.Characteristic
	|			AND TT_InventoryToFillReserveCumulative.Batch = TT_InventoryBalances.Batch
	|			AND TT_InventoryToFillReserveCumulative.Order = TT_InventoryBalances.Order
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_Inventory.LineNumber AS LineNumber,
	|	TT_Inventory.Products AS Products,
	|	TT_Inventory.ProductsTypeInventory AS ProductsTypeInventory,
	|	TT_Inventory.Characteristic AS Characteristic,
	|	TT_Inventory.Batch AS Batch,
	|	TT_Inventory.Quantity AS Quantity,
	|	CASE
	|		WHEN TT_InventoryReserve.BaseReserve = TT_InventoryReserve.BaseQuantity
	|			THEN TT_Inventory.Quantity
	|		ELSE TT_InventoryReserve.BaseReserve / TT_InventoryReserve.Factor
	|	END AS Reserve,
	|	TT_Inventory.MeasurementUnit AS MeasurementUnit,
	|	TT_Inventory.Factor AS Factor,
	|	TT_Inventory.Price AS Price,
	|	TT_Inventory.DiscountMarkupPercent AS DiscountMarkupPercent,
	|	TT_Inventory.Amount AS Amount,
	|	TT_Inventory.VATRate AS VATRate,
	|	TT_Inventory.VATAmount AS VATAmount,
	|	TT_Inventory.Total AS Total,
	|	TT_Inventory.Order AS Order,
	|	SalesOrder.SalesRep AS SalesRep,
	|	VALUE(Document.GoodsIssue.EmptyRef) AS GoodsIssue,
	|	TT_Inventory.Content AS Content,
	|	TT_Inventory.AutomaticDiscountsPercent AS AutomaticDiscountsPercent,
	|	TT_Inventory.AutomaticDiscountAmount AS AutomaticDiscountAmount,
	|	TT_Inventory.SerialNumbers AS SerialNumbers
	|FROM
	|	TT_InventoryToFillReserve AS TT_Inventory
	|		LEFT JOIN TT_InventoryReserve AS TT_InventoryReserve
	|		ON TT_Inventory.LineNumber = TT_InventoryReserve.LineNumber
	|			AND TT_Inventory.Order = TT_InventoryReserve.Order
	|		INNER JOIN Document.SalesOrder AS SalesOrder
	|		ON TT_Inventory.Order = SalesOrder.Ref
	|";

EndFunction

Function GetFillWorkOrderReserveColumnQueryText()
	
	Return DriveClientServer.GetQueryDelimeter() +
	"SELECT
	|	InventoryBalances.Products AS Products,
	|	InventoryBalances.Characteristic AS Characteristic,
	|	InventoryBalances.Batch AS Batch,
	|	InventoryBalances.SalesOrder AS Order,
	|	SUM(InventoryBalances.QuantityBalance) AS QuantityBalance
	|INTO TT_InventoryBalances
	|FROM
	|	(SELECT
	|		InventoryBalances.SalesOrder AS SalesOrder,
	|		InventoryBalances.Products AS Products,
	|		InventoryBalances.Characteristic AS Characteristic,
	|		InventoryBalances.Batch AS Batch,
	|		InventoryBalances.QuantityBalance AS QuantityBalance
	|	FROM
	|		AccumulationRegister.Inventory.Balance(
	|				,
	|				Company = &Company
	|					AND StructuralUnit = &StructuralUnit
	|					AND SalesOrder <> UNDEFINED
	|					AND (Products, Characteristic, Batch, SalesOrder) IN
	|						(SELECT
	|							TT_InventoryToFillReserve.Products,
	|							TT_InventoryToFillReserve.Characteristic,
	|							TT_InventoryToFillReserve.Batch,
	|							TT_InventoryToFillReserve.Order
	|						FROM
	|							TT_InventoryToFillReserve AS TT_InventoryToFillReserve)) AS InventoryBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsInventory.SalesOrder,
	|		DocumentRegisterRecordsInventory.Products,
	|		DocumentRegisterRecordsInventory.Characteristic,
	|		DocumentRegisterRecordsInventory.Batch,
	|		CASE
	|			WHEN DocumentRegisterRecordsInventory.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN ISNULL(DocumentRegisterRecordsInventory.Quantity, 0)
	|			ELSE -ISNULL(DocumentRegisterRecordsInventory.Quantity, 0)
	|		END
	|	FROM
	|		AccumulationRegister.Inventory AS DocumentRegisterRecordsInventory
	|	WHERE
	|		DocumentRegisterRecordsInventory.Recorder = &Ref
	|		AND DocumentRegisterRecordsInventory.SalesOrder <> UNDEFINED) AS InventoryBalances
	|
	|GROUP BY
	|	InventoryBalances.SalesOrder,
	|	InventoryBalances.Products,
	|	InventoryBalances.Characteristic,
	|	InventoryBalances.Batch
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_InventoryToFillReserve.LineNumber AS LineNumber,
	|	TT_InventoryToFillReserve.Products AS Products,
	|	TT_InventoryToFillReserve.Characteristic AS Characteristic,
	|	TT_InventoryToFillReserve.Batch AS Batch,
	|	TT_InventoryToFillReserve.Order AS Order,
	|	TT_InventoryToFillReserve.Factor AS Factor,
	|	TT_InventoryToFillReserve.Quantity * TT_InventoryToFillReserve.Factor AS BaseQuantity,
	|	SUM(TT_InventoryToFillReserveCumulative.Quantity * TT_InventoryToFillReserveCumulative.Factor) AS BaseQuantityCumulative
	|INTO TT_InventoryToFillReserveCumulative
	|FROM
	|	TT_InventoryToFillReserve AS TT_InventoryToFillReserve
	|		INNER JOIN TT_InventoryToFillReserve AS TT_InventoryToFillReserveCumulative
	|		ON TT_InventoryToFillReserve.Products = TT_InventoryToFillReserveCumulative.Products
	|			AND TT_InventoryToFillReserve.Characteristic = TT_InventoryToFillReserveCumulative.Characteristic
	|			AND TT_InventoryToFillReserve.Batch = TT_InventoryToFillReserveCumulative.Batch
	|			AND TT_InventoryToFillReserve.Order = TT_InventoryToFillReserveCumulative.Order
	|			AND TT_InventoryToFillReserve.LineNumber >= TT_InventoryToFillReserveCumulative.LineNumber
	|
	|GROUP BY
	|	TT_InventoryToFillReserve.LineNumber,
	|	TT_InventoryToFillReserve.Characteristic,
	|	TT_InventoryToFillReserve.Batch,
	|	TT_InventoryToFillReserve.Order,
	|	TT_InventoryToFillReserve.Products,
	|	TT_InventoryToFillReserve.Factor,
	|	TT_InventoryToFillReserve.Quantity * TT_InventoryToFillReserve.Factor
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_InventoryToFillReserveCumulative.LineNumber AS LineNumber,
	|	TT_InventoryToFillReserveCumulative.Order AS Order,
	|	TT_InventoryToFillReserveCumulative.Factor AS Factor,
	|	TT_InventoryToFillReserveCumulative.BaseQuantity AS BaseQuantity,
	|	CASE
	|		WHEN TT_InventoryBalances.QuantityBalance > TT_InventoryToFillReserveCumulative.BaseQuantityCumulative
	|			THEN TT_InventoryToFillReserveCumulative.BaseQuantity
	|		WHEN TT_InventoryBalances.QuantityBalance > TT_InventoryToFillReserveCumulative.BaseQuantityCumulative - TT_InventoryToFillReserveCumulative.BaseQuantity
	|			THEN TT_InventoryBalances.QuantityBalance - (TT_InventoryToFillReserveCumulative.BaseQuantityCumulative - TT_InventoryToFillReserveCumulative.BaseQuantity)
	|		ELSE 0
	|	END AS BaseReserve
	|INTO TT_InventoryReserve
	|FROM
	|	TT_InventoryToFillReserveCumulative AS TT_InventoryToFillReserveCumulative
	|		LEFT JOIN TT_InventoryBalances AS TT_InventoryBalances
	|		ON TT_InventoryToFillReserveCumulative.Products = TT_InventoryBalances.Products
	|			AND TT_InventoryToFillReserveCumulative.Characteristic = TT_InventoryBalances.Characteristic
	|			AND TT_InventoryToFillReserveCumulative.Batch = TT_InventoryBalances.Batch
	|			AND TT_InventoryToFillReserveCumulative.Order = TT_InventoryBalances.Order
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_Inventory.LineNumber AS LineNumber,
	|	TT_Inventory.Products AS Products,
	|	TT_Inventory.ProductsTypeInventory AS ProductsTypeInventory,
	|	TT_Inventory.Characteristic AS Characteristic,
	|	TT_Inventory.Batch AS Batch,
	|	TT_Inventory.Quantity AS Quantity,
	|	CASE
	|		WHEN TT_InventoryReserve.BaseReserve = TT_InventoryReserve.BaseQuantity
	|			THEN TT_Inventory.Quantity
	|		ELSE TT_InventoryReserve.BaseReserve / TT_InventoryReserve.Factor
	|	END AS Reserve,
	|	TT_Inventory.MeasurementUnit AS MeasurementUnit,
	|	TT_Inventory.Factor AS Factor,
	|	TT_Inventory.Price AS Price,
	|	TT_Inventory.DiscountMarkupPercent AS DiscountMarkupPercent,
	|	TT_Inventory.Amount AS Amount,
	|	TT_Inventory.VATRate AS VATRate,
	|	TT_Inventory.VATAmount AS VATAmount,
	|	TT_Inventory.Total AS Total,
	|	TT_Inventory.Order AS Order,
	|	VALUE(Document.GoodsIssue.EmptyRef) AS GoodsIssue,
	|	TT_Inventory.Content AS Content,
	|	TT_Inventory.AutomaticDiscountsPercent AS AutomaticDiscountsPercent,
	|	TT_Inventory.AutomaticDiscountAmount AS AutomaticDiscountAmount,
	|	TT_Inventory.SerialNumbers AS SerialNumbers,
	|	TT_Inventory.SalesRep AS SalesRep
	|FROM
	|	TT_InventoryToFillReserve AS TT_Inventory
	|		LEFT JOIN TT_InventoryReserve AS TT_InventoryReserve
	|		ON TT_Inventory.LineNumber = TT_InventoryReserve.LineNumber
	|			AND TT_Inventory.Order = TT_InventoryReserve.Order
	|		INNER JOIN Document.WorkOrder AS WorkOrder
	|		ON TT_Inventory.Order = WorkOrder.Ref";

EndFunction

// Exists or not Early payment discount on specified date
// Parameters:
//  DocumentRefSalesInvoice - DocumentRef.SalesInvoice - the Sales invoice on which we check the EPD
//  CheckDate - date - the date of EPD check
// Returns:
//  Boolean - TRUE if EPD exists
//
Function CheckExistsEPD(DocumentRefSalesInvoice, CheckDate) Export
	
	Result = False;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	TRUE AS ExistsEPD
	|FROM
	|	Document.SalesInvoice.EarlyPaymentDiscounts AS SalesInvoiceEarlyPaymentDiscounts
	|WHERE
	|	SalesInvoiceEarlyPaymentDiscounts.Ref = &Ref
	|	AND ENDOFPERIOD(SalesInvoiceEarlyPaymentDiscounts.DueDate, DAY) >= &DueDate";
	
	Query.SetParameter("Ref", DocumentRefSalesInvoice);
	Query.SetParameter("DueDate", CheckDate);
	
	QuerySelection = Query.Execute().Select();
	If QuerySelection.Next() Then
		Result = QuerySelection.ExistsEPD;
	EndIf;
	
	Return Result;
	
EndFunction

// Gets an array of invoices that have an EPD on the specified date
// Parameters:
//  SalesInvoiceArray - Array - documents (DocumentRef.SalesInvoice)
//  CheckDate - date - the date of EPD check
// Returns:
//  Array - documents (DocumentRef.SalesIncoice) that have an EPD
//
Function GetSalesInvoiceArrayWithEPD(SalesInvoiceArray, Val CheckDate) Export
	
	Result = New Array;
	
	Query = New Query;
	Query.Text =
	"SELECT DISTINCT
	|	SalesInvoiceEarlyPaymentDiscounts.Ref AS SalesInvoce
	|FROM
	|	Document.SalesInvoice.EarlyPaymentDiscounts AS SalesInvoiceEarlyPaymentDiscounts
	|WHERE
	|	SalesInvoiceEarlyPaymentDiscounts.Ref IN(&SalesInvoices)
	|	AND ENDOFPERIOD(SalesInvoiceEarlyPaymentDiscounts.DueDate, DAY) >= &DueDate";
	
	Query.SetParameter("SalesInvoices", SalesInvoiceArray);
	Query.SetParameter("DueDate", CheckDate);
	
	QueryResult = Query.Execute();
	
	If NOT QueryResult.IsEmpty() Then
		Result = QueryResult.Unload().UnloadColumn("SalesInvoce");
	EndIf;
	
	Return Result;
	
EndFunction

#EndRegion

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventory(DocumentRefSalesInvoice, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	MIN(TableInventory.LineNumber) AS LineNumber,
	|	TableInventory.Period AS Period,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableInventory.Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	FALSE AS Return,
	|	TableInventory.Document AS Document,
	|	TableInventory.Document AS SourceDocument,
	|	CASE
	|		WHEN TableInventory.Order = VALUE(Document.SalesOrder.EmptyRef)
	|				OR TableInventory.Order = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE TableInventory.Order
	|	END AS CorrSalesOrder,
	|	TableInventory.DepartmentSales AS Department,
	|	TableInventory.Responsible AS Responsible,
	|	TableInventory.DepartmentSales AS DepartmentSales,
	|	TableInventory.BusinessLineSales AS BusinessLine,
	|	TableInventory.GLAccountCost AS GLAccountCost,
	|	TableInventory.CorrOrganization AS CorrOrganization,
	|	ISNULL(TableInventory.StructuralUnit, VALUE(Catalog.Counterparties.EmptyRef)) AS StructuralUnit,
	|	ISNULL(TableInventory.StructuralUnitCorr, VALUE(Catalog.BusinessUnits.EmptyRef)) AS StructuralUnitCorr,
	|	TableInventory.GLAccount AS GLAccount,
	|	TableInventory.CorrGLAccount AS CorrGLAccount,
	|	TableInventory.ProductsOnCommission AS ProductsOnCommission,
	|	TableInventory.Products AS Products,
	|	TableInventory.ProductsCorr AS ProductsCorr,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.CharacteristicCorr AS CharacteristicCorr,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.BatchCorr AS BatchCorr,
	|	CASE
	|		WHEN TableInventory.Order = VALUE(Document.SalesOrder.EmptyRef)
	|				OR TableInventory.Order = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE TableInventory.Order
	|	END AS SalesOrder,
	|	TableInventory.SalesRep AS SalesRep,
	|	UNDEFINED AS CustomerCorrOrder,
	|	SUM(TableInventory.Quantity) AS Quantity,
	|	SUM(TableInventory.Reserve) AS Reserve,
	|	TableInventory.VATRate AS VATRate,
	|	SUM(TableInventory.VATAmount) AS VATAmount,
	|	SUM(TableInventory.Amount) AS Amount,
	|	0 AS Cost,
	|	FALSE AS FixedCost,
	|	TableInventory.GLAccountCost AS AccountDr,
	|	TableInventory.GLAccount AS AccountCr,
	|	CAST(&InventoryWriteOff AS STRING(100)) AS Content,
	|	CAST(&InventoryWriteOff AS STRING(100)) AS ContentOfAccountingRecord,
	|	FALSE AS OfflineRecord
	|INTO SourceInventory
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|		LEFT JOIN Document.SalesOrder AS SalesOrderRef
	|		ON TableInventory.Order = SalesOrderRef.Ref,
	|	Constant.UseInventoryReservation AS UseInventoryReservation
	|WHERE
	|	TableInventory.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
	|	AND (NOT TableInventory.GoodsIssue = VALUE(Document.GoodsIssue.EmptyRef)
	|			OR NOT TableInventory.AdvanceInvoicing)
	|
	|GROUP BY
	|	TableInventory.Period,
	|	TableInventory.Company,
	|	TableInventory.Document,
	|	TableInventory.Order,
	|	TableInventory.SalesRep,
	|	TableInventory.DepartmentSales,
	|	TableInventory.Responsible,
	|	TableInventory.BusinessLineSales,
	|	TableInventory.GLAccountCost,
	|	TableInventory.CorrOrganization,
	|	TableInventory.StructuralUnit,
	|	TableInventory.StructuralUnitCorr,
	|	TableInventory.GLAccount,
	|	TableInventory.CorrGLAccount,
	|	TableInventory.ProductsOnCommission,
	|	TableInventory.Products,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	TableInventory.ProductsCorr,
	|	TableInventory.CharacteristicCorr,
	|	TableInventory.BatchCorr,
	|	TableInventory.VATRate,
	|	TableInventory.Document,
	|	TableInventory.DepartmentSales,
	|	TableInventory.Order,
	|	TableInventory.GLAccountCost,
	|	TableInventory.GLAccount
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableInventory.LineNumber AS LineNumber,
	|	TableInventory.Period AS Period,
	|	TableInventory.RecordType AS RecordType,
	|	TableInventory.Company AS Company,
	|	TableInventory.PlanningPeriod AS PlanningPeriod,
	|	TableInventory.Return AS Return,
	|	TableInventory.Document AS Document,
	|	TableInventory.SourceDocument AS SourceDocument,
	|	TableInventory.CorrSalesOrder AS CorrSalesOrder,
	|	TableInventory.Department AS Department,
	|	TableInventory.Responsible AS Responsible,
	|	TableInventory.DepartmentSales AS DepartmentSales,
	|	TableInventory.BusinessLine AS BusinessLine,
	|	TableInventory.GLAccountCost AS GLAccountCost,
	|	TableInventory.CorrOrganization AS CorrOrganization,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	TableInventory.StructuralUnitCorr AS StructuralUnitCorr,
	|	TableInventory.GLAccount AS GLAccount,
	|	TableInventory.CorrGLAccount AS CorrGLAccount,
	|	TableInventory.ProductsOnCommission AS ProductsOnCommission,
	|	TableInventory.Products AS Products,
	|	TableInventory.ProductsCorr AS ProductsCorr,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.CharacteristicCorr AS CharacteristicCorr,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.BatchCorr AS BatchCorr,
	|	CASE
	|		WHEN &FillAmount
	|			OR TableInventory.Reserve = 0
	|			THEN TableInventory.SalesOrder
	|		ELSE UNDEFINED
	|	END AS SalesOrder,
	|	TableInventory.CustomerCorrOrder AS CustomerCorrOrder,
	|	CASE
	|		WHEN &FillAmount
	|			THEN TableInventory.Quantity
	|		ELSE TableInventory.Quantity - TableInventory.Reserve
	|	END AS Quantity,
	|	TableInventory.Reserve AS Reserve,
	|	TableInventory.VATRate AS VATRate,
	|	CASE WHEN &FillAmount
	|		THEN TableInventory.VATAmount
	|		ELSE 0
	|	END AS VATAmount,
	|	CASE WHEN &FillAmount
	|		THEN TableInventory.Amount
	|		ELSE 0
	|	END AS Amount,
	|	CASE WHEN &FillAmount
	|		THEN TableInventory.Cost
	|		ELSE 0
	|	END AS Cost,
	|	TableInventory.FixedCost AS FixedCost,
	|	TableInventory.AccountDr AS AccountDr,
	|	TableInventory.AccountCr AS AccountCr,
	|	TableInventory.Content AS Content,
	|	TableInventory.ContentOfAccountingRecord AS ContentOfAccountingRecord,
	|	TableInventory.OfflineRecord AS OfflineRecord,
	|	TableInventory.SalesRep AS SalesRep
	|FROM
	|	SourceInventory AS TableInventory
	|WHERE
	|	TableInventory.Quantity > TableInventory.Reserve
	|
	|UNION ALL
	|
	|SELECT
	|	TableInventory.LineNumber,
	|	TableInventory.Period,
	|	TableInventory.RecordType,
	|	TableInventory.Company,
	|	UNDEFINED,
	|	TableInventory.Return,
	|	UNDEFINED,
	|	TableInventory.SourceDocument,
	|	TableInventory.CorrSalesOrder,
	|	TableInventory.Department,
	|	TableInventory.Responsible,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	TableInventory.StructuralUnit,
	|	TableInventory.StructuralUnitCorr,
	|	TableInventory.GLAccount,
	|	TableInventory.CorrGLAccount,
	|	UNDEFINED,
	|	TableInventory.Products,
	|	TableInventory.ProductsCorr,
	|	TableInventory.Characteristic,
	|	TableInventory.CharacteristicCorr,
	|	TableInventory.Batch,
	|	TableInventory.BatchCorr,
	|	TableInventory.SalesOrder,
	|	TableInventory.CustomerCorrOrder,
	|	TableInventory.Reserve,
	|	0,
	|	TableInventory.VATRate,
	|	0,
	|	0,
	|	0,
	|	TableInventory.FixedCost,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	TableInventory.ContentOfAccountingRecord,
	|	TableInventory.OfflineRecord,
	|	TableInventory.SalesRep
	|FROM
	|	SourceInventory AS TableInventory
	|WHERE
	|	NOT &FillAmount
	|	AND TableInventory.Reserve > 0
	|
	|UNION ALL
	|
	|SELECT
	|	OfflineRecords.LineNumber,
	|	OfflineRecords.Period,
	|	OfflineRecords.RecordType,
	|	OfflineRecords.Company,
	|	UNDEFINED,
	|	OfflineRecords.Return,
	|	UNDEFINED,
	|	OfflineRecords.SourceDocument,
	|	OfflineRecords.CorrSalesOrder,
	|	OfflineRecords.Department,
	|	OfflineRecords.Responsible,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	OfflineRecords.StructuralUnit,
	|	OfflineRecords.StructuralUnitCorr,
	|	OfflineRecords.GLAccount,
	|	OfflineRecords.CorrGLAccount,
	|	UNDEFINED,
	|	OfflineRecords.Products,
	|	OfflineRecords.ProductsCorr,
	|	OfflineRecords.Characteristic,
	|	OfflineRecords.CharacteristicCorr,
	|	OfflineRecords.Batch,
	|	OfflineRecords.BatchCorr,
	|	OfflineRecords.SalesOrder,
	|	OfflineRecords.CustomerCorrOrder,
	|	OfflineRecords.Quantity,
	|	UNDEFINED,
	|	OfflineRecords.VATRate,
	|	UNDEFINED,
	|	OfflineRecords.Amount,
	|	UNDEFINED,
	|	OfflineRecords.FixedCost,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	OfflineRecords.ContentOfAccountingRecord,
	|	OfflineRecords.OfflineRecord,
	|	SalesOrderRef.SalesRep
	|FROM
	|	AccumulationRegister.Inventory AS OfflineRecords
	|		LEFT JOIN Document.SalesOrder AS SalesOrderRef
	|		ON OfflineRecords.SalesOrder = SalesOrderRef.Ref
	|WHERE
	|	OfflineRecords.Recorder = &Ref
	|	AND OfflineRecords.OfflineRecord";
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();
	
	Query.SetParameter("InventoryIncrease", NStr("en = 'Inventory increase'", MainLanguageCode));
	Query.SetParameter("InventoryWriteOff", NStr("en = 'Inventory write-off'", MainLanguageCode));
	FillAmount = StructureAdditionalProperties.AccountingPolicy.InventoryValuationMethod = Enums.InventoryValuationMethods.WeightedAverage;
	Query.SetParameter("FillAmount", FillAmount);
	Query.SetParameter("Ref", DocumentRefSalesInvoice);
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventory", QueryResult.Unload());
	
	If FillAmount Then
		
		PerformanceEstimationClientServer.StartTimeMeasurement("DocumentSalesInvoicePositingGenerateTableProductionCostTable");
		
		GenerateTableInventorySale(DocumentRefSalesInvoice, StructureAdditionalProperties);
		
	EndIf;
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventorySale(DocumentRefSalesInvoice, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	// Setting the exclusive lock for the controlled inventory balances.
	Query.Text =
	"SELECT
	|	TableInventory.Company AS Company,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	TableInventory.GLAccount AS GLAccount,
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.SalesOrder AS SalesOrder
	|FROM
	|	(SELECT
	|		TableInventory.Company AS Company,
	|		TableInventory.StructuralUnit AS StructuralUnit,
	|		TableInventory.GLAccount AS GLAccount,
	|		TableInventory.Products AS Products,
	|		TableInventory.Characteristic AS Characteristic,
	|		TableInventory.Batch AS Batch,
	|		TableInventory.Order AS SalesOrder
	|	FROM
	|		TemporaryTableInventory AS TableInventory
	|	WHERE
	|		TableInventory.Order <> UNDEFINED
	|		AND TableInventory.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|		AND TableInventory.Order <> VALUE(Document.WorkOrder.EmptyRef)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		TableInventory.Company,
	|		TableInventory.StructuralUnit,
	|		TableInventory.GLAccount,
	|		TableInventory.Products,
	|		TableInventory.Characteristic,
	|		TableInventory.Batch,
	|		UNDEFINED
	|	FROM
	|		TemporaryTableInventory AS TableInventory) AS TableInventory
	|
	|GROUP BY
	|	TableInventory.Company,
	|	TableInventory.StructuralUnit,
	|	TableInventory.GLAccount,
	|	TableInventory.Products,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	TableInventory.SalesOrder";
	
	QueryResult = Query.Execute();
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.Inventory");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;
	
	For Each ColumnQueryResult In QueryResult.Columns Do
		LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
	EndDo;
	Block.Lock();
	
	// Receiving inventory balances by cost.
	Query.Text =
	"SELECT
	|	InventoryBalances.Company AS Company,
	|	InventoryBalances.StructuralUnit AS StructuralUnit,
	|	InventoryBalances.GLAccount AS GLAccount,
	|	InventoryBalances.Products AS Products,
	|	InventoryBalances.Characteristic AS Characteristic,
	|	InventoryBalances.Batch AS Batch,
	|	InventoryBalances.SalesOrder AS SalesOrder,
	|	SUM(InventoryBalances.QuantityBalance) AS QuantityBalance,
	|	SUM(InventoryBalances.AmountBalance) AS AmountBalance
	|FROM
	|	(SELECT
	|		InventoryBalances.Company AS Company,
	|		InventoryBalances.StructuralUnit AS StructuralUnit,
	|		InventoryBalances.GLAccount AS GLAccount,
	|		InventoryBalances.Products AS Products,
	|		InventoryBalances.Characteristic AS Characteristic,
	|		InventoryBalances.Batch AS Batch,
	|		InventoryBalances.SalesOrder AS SalesOrder,
	|		SUM(InventoryBalances.QuantityBalance) AS QuantityBalance,
	|		SUM(InventoryBalances.AmountBalance) AS AmountBalance
	|	FROM
	|		AccumulationRegister.Inventory.Balance(
	|				&ControlTime,
	|				(Company, StructuralUnit, GLAccount, Products, Characteristic, Batch, SalesOrder) IN
	|					(SELECT
	|						TableInventory.Company AS Company,
	|						TableInventory.StructuralUnit AS StructuralUnit,
	|						TableInventory.GLAccount AS GLAccount,
	|						TableInventory.Products AS Products,
	|						TableInventory.Characteristic AS Characteristic,
	|						TableInventory.Batch AS Batch,
	|						TableInventory.Order
	|					FROM
	|						TemporaryTableInventory AS TableInventory
	|					WHERE
	|						TableInventory.Order <> UNDEFINED
	|						AND TableInventory.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|						AND TableInventory.Order <> VALUE(Document.WorkOrder.EmptyRef))) AS InventoryBalances
	|	
	|	GROUP BY
	|		InventoryBalances.Company,
	|		InventoryBalances.StructuralUnit,
	|		InventoryBalances.GLAccount,
	|		InventoryBalances.Products,
	|		InventoryBalances.Characteristic,
	|		InventoryBalances.Batch,
	|		InventoryBalances.SalesOrder
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		InventoryBalances.Company,
	|		InventoryBalances.StructuralUnit,
	|		InventoryBalances.GLAccount,
	|		InventoryBalances.Products,
	|		InventoryBalances.Characteristic,
	|		InventoryBalances.Batch,
	|		UNDEFINED,
	|		SUM(InventoryBalances.QuantityBalance),
	|		SUM(InventoryBalances.AmountBalance)
	|	FROM
	|		AccumulationRegister.Inventory.Balance(
	|				&ControlTime,
	|				(Company, StructuralUnit, GLAccount, Products, Characteristic, Batch, SalesOrder) IN
	|					(SELECT
	|						TableInventory.Company,
	|						TableInventory.StructuralUnit,
	|						TableInventory.GLAccount,
	|						TableInventory.Products,
	|						TableInventory.Characteristic,
	|						TableInventory.Batch,
	|						UNDEFINED
	|					FROM
	|						TemporaryTableInventory AS TableInventory)) AS InventoryBalances
	|	
	|	GROUP BY
	|		InventoryBalances.Company,
	|		InventoryBalances.StructuralUnit,
	|		InventoryBalances.GLAccount,
	|		InventoryBalances.Products,
	|		InventoryBalances.Characteristic,
	|		InventoryBalances.Batch
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsInventory.Company,
	|		DocumentRegisterRecordsInventory.StructuralUnit,
	|		DocumentRegisterRecordsInventory.GLAccount,
	|		DocumentRegisterRecordsInventory.Products,
	|		DocumentRegisterRecordsInventory.Characteristic,
	|		DocumentRegisterRecordsInventory.Batch,
	|		DocumentRegisterRecordsInventory.SalesOrder,
	|		CASE
	|			WHEN DocumentRegisterRecordsInventory.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN ISNULL(DocumentRegisterRecordsInventory.Quantity, 0)
	|			ELSE -ISNULL(DocumentRegisterRecordsInventory.Quantity, 0)
	|		END,
	|		CASE
	|			WHEN DocumentRegisterRecordsInventory.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN ISNULL(DocumentRegisterRecordsInventory.Amount, 0)
	|			ELSE -ISNULL(DocumentRegisterRecordsInventory.Amount, 0)
	|		END
	|	FROM
	|		AccumulationRegister.Inventory AS DocumentRegisterRecordsInventory
	|	WHERE
	|		DocumentRegisterRecordsInventory.Recorder = &Ref
	|		AND DocumentRegisterRecordsInventory.Period <= &ControlPeriod) AS InventoryBalances
	|
	|GROUP BY
	|	InventoryBalances.Company,
	|	InventoryBalances.StructuralUnit,
	|	InventoryBalances.GLAccount,
	|	InventoryBalances.Products,
	|	InventoryBalances.Characteristic,
	|	InventoryBalances.Batch,
	|	InventoryBalances.SalesOrder";
	
	Query.SetParameter("Ref", DocumentRefSalesInvoice);
	Query.SetParameter("ControlTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.PointInTime.Date);
	
	QueryResult = Query.Execute();
	
	TableInventoryBalances = QueryResult.Unload();
	TableInventoryBalances.Indexes.Add("Company,StructuralUnit,GLAccount,Products,Characteristic,Batch,SalesOrder");
	
	TemporaryTableInventory = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.CopyColumns();
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();
	
	For n = 0 To StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Count() - 1 Do
		
		RowTableInventory = StructureAdditionalProperties.TableForRegisterRecords.TableInventory[n];
		
		StructureForSearch = New Structure;
		StructureForSearch.Insert("Company", RowTableInventory.Company);
		StructureForSearch.Insert("StructuralUnit", RowTableInventory.StructuralUnit);
		StructureForSearch.Insert("GLAccount", RowTableInventory.GLAccount);
		StructureForSearch.Insert("Products", RowTableInventory.Products);
		StructureForSearch.Insert("Characteristic", RowTableInventory.Characteristic);
		StructureForSearch.Insert("Batch", RowTableInventory.Batch);
		
		QuantityRequiredReserve = ?(ValueIsFilled(RowTableInventory.Reserve), RowTableInventory.Reserve, 0);
		QuantityRequiredAvailableBalance = ?(ValueIsFilled(RowTableInventory.Quantity), RowTableInventory.Quantity, 0);
		
		If QuantityRequiredReserve > 0 Then
			
			QuantityRequiredAvailableBalance = QuantityRequiredAvailableBalance - QuantityRequiredReserve;
			
			StructureForSearch.Insert("SalesOrder", RowTableInventory.SalesOrder);
			
			BalanceRowsArray = TableInventoryBalances.FindRows(StructureForSearch);
			
			QuantityBalance = 0;
			AmountBalance = 0;
			
			If BalanceRowsArray.Count() > 0 Then
				QuantityBalance = BalanceRowsArray[0].QuantityBalance;
				AmountBalance = BalanceRowsArray[0].AmountBalance;
			EndIf;
			
			If QuantityBalance > 0 AND QuantityBalance > QuantityRequiredReserve Then
				
				AmountToBeWrittenOff = Round(AmountBalance * QuantityRequiredReserve / QuantityBalance , 2, 1);
				
				BalanceRowsArray[0].QuantityBalance = BalanceRowsArray[0].QuantityBalance - QuantityRequiredReserve;
				BalanceRowsArray[0].AmountBalance = BalanceRowsArray[0].AmountBalance - AmountToBeWrittenOff;
				
			ElsIf QuantityBalance = QuantityRequiredReserve Then
				
				AmountToBeWrittenOff = AmountBalance;
				
				BalanceRowsArray[0].QuantityBalance = 0;
				BalanceRowsArray[0].AmountBalance = 0;
				
			Else
				AmountToBeWrittenOff = 0;
			EndIf;
			
			// Expense. Inventory.
			TableRowExpense = TemporaryTableInventory.Add();
			FillPropertyValues(TableRowExpense, RowTableInventory);
			
			TableRowExpense.Amount = AmountToBeWrittenOff;
			TableRowExpense.Quantity = QuantityRequiredReserve;
			
			// Generate postings.
			If Round(AmountToBeWrittenOff, 2, 1) <> 0 Then
				RowTableAccountingJournalEntries = StructureAdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries.Add();
				FillPropertyValues(RowTableAccountingJournalEntries, RowTableInventory);
				RowTableAccountingJournalEntries.Amount = AmountToBeWrittenOff;
			EndIf;
			
			If Round(AmountToBeWrittenOff, 2, 1) <> 0 Then
				
				// Move income and expenses.
				RowIncomeAndExpenses = StructureAdditionalProperties.TableForRegisterRecords.TableIncomeAndExpenses.Add();
				FillPropertyValues(RowIncomeAndExpenses, RowTableInventory);
				
				RowIncomeAndExpenses.StructuralUnit = RowTableInventory.DepartmentSales;
				RowIncomeAndExpenses.GLAccount = RowTableInventory.GLAccountCost;
				RowIncomeAndExpenses.AmountIncome = 0;
				RowIncomeAndExpenses.AmountExpense = AmountToBeWrittenOff;
				RowIncomeAndExpenses.Amount = AmountToBeWrittenOff;
				
				RowIncomeAndExpenses.ContentOfAccountingRecord = NStr("en = 'Expenses incurred'", MainLanguageCode);
				
			EndIf;
			
			If Round(AmountToBeWrittenOff, 2, 1) <> 0 Then
				
				// Move the cost of sales.
				SaleString = StructureAdditionalProperties.TableForRegisterRecords.TableSales.Add();
				FillPropertyValues(SaleString, RowTableInventory);
				SaleString.Quantity = 0;
				SaleString.Amount = 0;
				SaleString.VATAmount = 0;
				SaleString.Cost = AmountToBeWrittenOff;
				
			EndIf;
			
			
		EndIf;
		
		If QuantityRequiredAvailableBalance > 0 Then
			
			StructureForSearch.Insert("SalesOrder", Undefined);
			
			BalanceRowsArray = TableInventoryBalances.FindRows(StructureForSearch);
			
			QuantityBalance = 0;
			AmountBalance = 0;
			
			If BalanceRowsArray.Count() > 0 Then
				QuantityBalance = BalanceRowsArray[0].QuantityBalance;
				AmountBalance = BalanceRowsArray[0].AmountBalance;
			EndIf;
			
			If QuantityBalance > 0 AND QuantityBalance > QuantityRequiredAvailableBalance Then
				
				AmountToBeWrittenOff = Round(AmountBalance * QuantityRequiredAvailableBalance / QuantityBalance , 2, 1);
				
				BalanceRowsArray[0].QuantityBalance = BalanceRowsArray[0].QuantityBalance - QuantityRequiredAvailableBalance;
				BalanceRowsArray[0].AmountBalance = BalanceRowsArray[0].AmountBalance - AmountToBeWrittenOff;
				
			ElsIf QuantityBalance = QuantityRequiredAvailableBalance Then
				
				AmountToBeWrittenOff = AmountBalance;
				
				BalanceRowsArray[0].QuantityBalance = 0;
				BalanceRowsArray[0].AmountBalance = 0;
				
			Else
				AmountToBeWrittenOff = 0;
			EndIf;
			
			// Expense. Inventory.
			TableRowExpense = TemporaryTableInventory.Add();
			FillPropertyValues(TableRowExpense, RowTableInventory);
			
			TableRowExpense.Amount = AmountToBeWrittenOff;
			TableRowExpense.Quantity = QuantityRequiredAvailableBalance;
			TableRowExpense.SalesOrder = Undefined;
			
			// Generate postings.
			If Round(AmountToBeWrittenOff, 2, 1) <> 0 Then
				RowTableAccountingJournalEntries = StructureAdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries.Add();
				FillPropertyValues(RowTableAccountingJournalEntries, RowTableInventory);
				RowTableAccountingJournalEntries.Amount = AmountToBeWrittenOff;
			EndIf;
			
			If Round(AmountToBeWrittenOff, 2, 1) <> 0 Then
				
				// Move income and expenses.
				RowIncomeAndExpenses = StructureAdditionalProperties.TableForRegisterRecords.TableIncomeAndExpenses.Add();
				FillPropertyValues(RowIncomeAndExpenses, RowTableInventory);
				
				RowIncomeAndExpenses.StructuralUnit = RowTableInventory.DepartmentSales;
				RowIncomeAndExpenses.GLAccount = RowTableInventory.GLAccountCost;
				RowIncomeAndExpenses.AmountIncome = 0;
				RowIncomeAndExpenses.AmountExpense = AmountToBeWrittenOff;
				
				RowIncomeAndExpenses.ContentOfAccountingRecord = NStr("en = 'Cost of goods sold'", MainLanguageCode);
				
			EndIf;
			
			If Round(AmountToBeWrittenOff, 2, 1) <> 0 Then
				
				// Move the cost of sales.
				SaleString = StructureAdditionalProperties.TableForRegisterRecords.TableSales.Add();
				FillPropertyValues(SaleString, RowTableInventory);
				SaleString.Quantity = 0;
				SaleString.Amount = 0;
				SaleString.VATAmount = 0;
				SaleString.Cost = AmountToBeWrittenOff;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	StructureAdditionalProperties.TableForRegisterRecords.TableInventory = TemporaryTableInventory;
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
// Payment calendar table formation procedure.
//
// Parameters:
// DocumentRef - DocumentRef.CashInflowForecast - Current
// document AdditionalProperties - AdditionalProperties - Additional properties of the document
//
Procedure GenerateTablePaymentCalendar(DocumentRefSalesInvoice, StructureAdditionalProperties)
	
	Query = New Query;
	
	Query.SetParameter("Ref", DocumentRefSalesInvoice);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	
	Query.Text =
	"SELECT
	|	SalesInvoice.Ref AS Ref,
	|	SalesInvoice.Date AS Date,
	|	SalesInvoice.AmountIncludesVAT AS AmountIncludesVAT,
	|	SalesInvoice.CashAssetsType AS CashAssetsType,
	|	SalesInvoice.Contract AS Contract,
	|	SalesInvoice.PettyCash AS PettyCash,
	|	SalesInvoice.DocumentCurrency AS DocumentCurrency,
	|	SalesInvoice.BankAccount AS BankAccount
	|INTO Document
	|FROM
	|	Document.SalesInvoice AS SalesInvoice
	|WHERE
	|	SalesInvoice.Ref = &Ref
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
	|		INNER JOIN Document.SalesInvoice.PaymentCalendar AS DocumentTable
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
	|	VALUE(Catalog.CashFlowItems.PaymentFromCustomers) AS Item,
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
	|			THEN CAST(PaymentCalendar.PaymentAmount * CASE
	|						WHEN SettlementsExchangeRates.ExchangeRate <> 0
	|								AND ExchangeRatesOfDocument.Multiplicity <> 0
	|							THEN ExchangeRatesOfDocument.ExchangeRate * SettlementsExchangeRates.Multiplicity / (ISNULL(SettlementsExchangeRates.ExchangeRate, 1) * ISNULL(ExchangeRatesOfDocument.Multiplicity, 1))
	|						ELSE 1
	|					END AS NUMBER(15, 2))
	|		ELSE PaymentCalendar.PaymentAmount
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

Procedure GenerateTableSales(DocumentRefSalesInvoice, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	TableSales.Period AS Period,
	|	TableSales.Company AS Company,
	|	TableSales.Products AS Products,
	|	TableSales.Characteristic AS Characteristic,
	|	TableSales.Batch AS Batch,
	|	CASE
	|		WHEN TableSales.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|				AND TableSales.Order <> VALUE(Document.WorkOrder.EmptyRef)
	|			THEN TableSales.Order
	|		ELSE UNDEFINED
	|	END AS SalesOrder,
	|	TableSales.Document AS Document,
	|	TableSales.VATRate AS VATRate,
	|	TableSales.DepartmentSales AS Department,
	|	TableSales.Responsible AS Responsible,
	|	SUM(TableSales.Quantity) AS Quantity,
	|	SUM(TableSales.AmountVATPurchaseSale) AS VATAmount,
	|	SUM(TableSales.Amount - TableSales.AmountVATPurchaseSale) AS Amount,
	|	0 AS Cost,
	|	FALSE AS OfflineRecord,
	|	TableSales.SalesRep AS SalesRep
	|FROM
	|	TemporaryTableInventory AS TableSales
	|	LEFT JOIN Document.SalesOrder AS SalesOrder
	|	ON TableSales.Order = SalesOrder.Ref
	|WHERE
	|	(NOT TableSales.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
	|			OR NOT TableSales.GoodsIssue = VALUE(Document.GoodsIssue.EmptyRef)
	|			OR NOT TableSales.AdvanceInvoicing)
	|
	|GROUP BY
	|	TableSales.Period,
	|	TableSales.Company,
	|	TableSales.Products,
	|	TableSales.Characteristic,
	|	TableSales.Batch,
	|	CASE
	|		WHEN TableSales.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|				AND TableSales.Order <> VALUE(Document.WorkOrder.EmptyRef)
	|			THEN TableSales.Order
	|		ELSE UNDEFINED
	|	END,
	|	TableSales.Document,
	|	TableSales.VATRate,
	|	TableSales.DepartmentSales,
	|	TableSales.Responsible,
	|	TableSales.SalesRep
	|
	|UNION ALL
	|
	|SELECT
	|	TableSales.Period,
	|	TableSales.Company,
	|	TableSales.Products,
	|	TableSales.Characteristic,
	|	TableSales.Batch,
	|	TableSales.SalesOrder,
	|	TableSales.Document,
	|	TableSales.VATRate,
	|	TableSales.Department,
	|	TableSales.Responsible,
	|	TableSales.Quantity,
	|	TableSales.VATAmount,
	|	TableSales.Amount,
	|	TableSales.Cost,
	|	TableSales.OfflineRecord,
	|	TableSales.SalesRep
	|FROM
	|	AccumulationRegister.Sales AS TableSales
	|WHERE
	|	TableSales.Recorder = &Ref
	|	AND TableSales.OfflineRecord";
	
	Query.SetParameter("Ref", DocumentRefSalesInvoice);
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSales", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableProductRelease(DocumentRefSalesInvoice, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	MIN(TableProductRelease.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TableProductRelease.Period AS Period,
	|	TableProductRelease.Company AS Company,
	|	TableProductRelease.DepartmentSales AS StructuralUnit,
	|	TableProductRelease.Products AS Products,
	|	TableProductRelease.Characteristic AS Characteristic,
	|	CASE
	|		WHEN TableProductRelease.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|				AND TableProductRelease.Order <> VALUE(Document.WorkOrder.EmptyRef)
	|			THEN TableProductRelease.Order
	|		ELSE UNDEFINED
	|	END AS SalesOrder,
	|	SUM(TableProductRelease.Quantity) AS Quantity
	|FROM
	|	TemporaryTableInventory AS TableProductRelease
	|WHERE
	|	TableProductRelease.ProductsType = VALUE(Enum.ProductsTypes.Service)
	|
	|GROUP BY
	|	TableProductRelease.Period,
	|	TableProductRelease.Company,
	|	TableProductRelease.DepartmentSales,
	|	TableProductRelease.Products,
	|	TableProductRelease.Characteristic,
	|	CASE
	|		WHEN TableProductRelease.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|				AND TableProductRelease.Order <> VALUE(Document.WorkOrder.EmptyRef)
	|			THEN TableProductRelease.Order
	|		ELSE UNDEFINED
	|	END";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableProductRelease", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventoryInWarehouses(DocumentRefSalesInvoice, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	MIN(TableInventoryInWarehouses.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
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
	|	TableInventoryInWarehouses.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
	|	AND NOT TableInventoryInWarehouses.AdvanceInvoicing
	|	AND TableInventoryInWarehouses.GoodsIssue = VALUE(Document.GoodsIssue.EmptyRef)
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

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableSalesOrders(DocumentRefSalesInvoice, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	MIN(TableSalesOrders.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableSalesOrders.Period AS Period,
	|	TableSalesOrders.Company AS Company,
	|	TableSalesOrders.Products AS Products,
	|	TableSalesOrders.Characteristic AS Characteristic,
	|	TableSalesOrders.Order AS SalesOrder,
	|	SUM(TableSalesOrders.Quantity) AS Quantity
	|FROM
	|	TemporaryTableInventory AS TableSalesOrders
	|WHERE
	|	VALUETYPE(TableSalesOrders.Order) = TYPE(Document.SalesOrder)
	|	AND TableSalesOrders.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|	AND TableSalesOrders.GoodsIssue = VALUE(Document.GoodsIssue.EmptyRef)
	|
	|GROUP BY
	|	TableSalesOrders.Period,
	|	TableSalesOrders.Company,
	|	TableSalesOrders.Products,
	|	TableSalesOrders.Characteristic,
	|	TableSalesOrders.Order";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSalesOrders", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableWorkOrders(DocumentRefSalesInvoice, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	MIN(TableSalesOrders.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableSalesOrders.Period AS Period,
	|	TableSalesOrders.Company AS Company,
	|	TableSalesOrders.Products AS Products,
	|	TableSalesOrders.Characteristic AS Characteristic,
	|	TableSalesOrders.Order AS WorkOrder,
	|	SUM(TableSalesOrders.Quantity) AS Quantity
	|FROM
	|	TemporaryTableInventory AS TableSalesOrders
	|WHERE
	|	VALUETYPE(TableSalesOrders.Order) = TYPE(Document.WorkOrder)
	|	AND TableSalesOrders.GoodsIssue = VALUE(Document.GoodsIssue.EmptyRef)
	|
	|GROUP BY
	|	TableSalesOrders.Period,
	|	TableSalesOrders.Company,
	|	TableSalesOrders.Products,
	|	TableSalesOrders.Characteristic,
	|	TableSalesOrders.Order";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableWorkOrders", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableIncomeAndExpenses(DocumentRefSalesInvoice, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	1 AS Ordering,
	|	TableIncomeAndExpenses.LineNumber AS LineNumber,
	|	TableIncomeAndExpenses.Period AS Period,
	|	TableIncomeAndExpenses.Company AS Company,
	|	TableIncomeAndExpenses.DepartmentSales AS StructuralUnit,
	|	TableIncomeAndExpenses.BusinessLineSales AS BusinessLine,
	|	CASE
	|		WHEN TableIncomeAndExpenses.Order = VALUE(Document.SalesOrder.EmptyRef)
	|				OR TableIncomeAndExpenses.Order = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE TableIncomeAndExpenses.Order
	|	END AS SalesOrder,
	|	TableIncomeAndExpenses.AccountStatementSales AS GLAccount,
	|	CAST(&Income AS STRING(100)) AS ContentOfAccountingRecord,
	|	SUM(TableIncomeAndExpenses.Amount - TableIncomeAndExpenses.VATAmount) AS AmountIncome,
	|	0 AS AmountExpense,
	|	FALSE AS OfflineRecord
	|FROM
	|	TemporaryTableInventory AS TableIncomeAndExpenses
	|WHERE
	|	NOT TableIncomeAndExpenses.ProductsOnCommission
	|	AND TableIncomeAndExpenses.Amount <> 0
	|	AND (NOT TableIncomeAndExpenses.AdvanceInvoicing
	|			OR NOT TableIncomeAndExpenses.GoodsIssue = VALUE(Document.GoodsIssue.EmptyRef)
	|			OR NOT TableIncomeAndExpenses.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem))
	|
	|GROUP BY
	|	TableIncomeAndExpenses.Period,
	|	TableIncomeAndExpenses.LineNumber,
	|	TableIncomeAndExpenses.Company,
	|	TableIncomeAndExpenses.DepartmentSales,
	|	TableIncomeAndExpenses.BusinessLineSales,
	|	TableIncomeAndExpenses.Order,
	|	TableIncomeAndExpenses.AccountStatementSales
	|
	|UNION ALL
	|
	|SELECT
	|	3,
	|	1,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	UNDEFINED,
	|	VALUE(Catalog.LinesOfBusiness.Other),
	|	UNDEFINED,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN &PositiveExchangeDifferenceGLAccount
	|		ELSE &NegativeExchangeDifferenceAccountOfAccounting
	|	END,
	|	&ExchangeDifference,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN DocumentTable.AmountOfExchangeDifferences
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN 0
	|		ELSE -DocumentTable.AmountOfExchangeDifferences
	|	END,
	|	FALSE
	|FROM
	|	(SELECT
	|		TableExchangeRateDifferencesAccountsReceivable.Date AS Date,
	|		TableExchangeRateDifferencesAccountsReceivable.Company AS Company,
	|		SUM(TableExchangeRateDifferencesAccountsReceivable.AmountOfExchangeDifferences) AS AmountOfExchangeDifferences
	|	FROM
	|		(SELECT
	|			DocumentTable.Date AS Date,
	|			DocumentTable.Company AS Company,
	|			DocumentTable.AmountOfExchangeDifferences AS AmountOfExchangeDifferences
	|		FROM
	|			TemporaryTableExchangeRateDifferencesAccountsReceivable AS DocumentTable
	|		WHERE
	|			DocumentTable.SettlementsType = VALUE(Enum.SettlementsTypes.Debt)
	|		
	|		UNION ALL
	|		
	|		SELECT
	|			DocumentTable.Date,
	|			DocumentTable.Company,
	|			DocumentTable.AmountOfExchangeDifferences
	|		FROM
	|			TemporaryTableExchangeRateDifferencesAccountsReceivable AS DocumentTable
	|		WHERE
	|			DocumentTable.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)) AS TableExchangeRateDifferencesAccountsReceivable
	|	
	|	GROUP BY
	|		TableExchangeRateDifferencesAccountsReceivable.Date,
	|		TableExchangeRateDifferencesAccountsReceivable.Company
	|	
	|	HAVING
	|		(SUM(TableExchangeRateDifferencesAccountsReceivable.AmountOfExchangeDifferences) >= 0.005
	|			OR SUM(TableExchangeRateDifferencesAccountsReceivable.AmountOfExchangeDifferences) <= -0.005)) AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	4,
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
	|	Ordering,
	|	LineNumber";
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();
	
	Query.SetParameter("PositiveExchangeDifferenceGLAccount",			Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeGain"));
	Query.SetParameter("NegativeExchangeDifferenceAccountOfAccounting", Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeLoss"));
	Query.SetParameter("Income",										NStr("en = 'Revenue'", MainLanguageCode));
	Query.SetParameter("ExchangeDifference",							NStr("en = 'Foreign currency exchange gains and losses'", MainLanguageCode));
	Query.SetParameter("Ref",											DocumentRefSalesInvoice);
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpenses", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableCustomerAccounts(DocumentRefSalesInvoice, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();
	
	Query.SetParameter("Ref", DocumentRefSalesInvoice);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("AppearenceOfCustomerLiability", NStr("en = 'Accounts receivable recognition'", MainLanguageCode));
	Query.SetParameter("AdvanceCredit", NStr("en = 'Advance payment clearing'", MainLanguageCode));
	Query.SetParameter("ExchangeDifference", NStr("en = 'Foreign currency exchange gains and losses'", MainLanguageCode));
	Query.SetParameter("ExpectedPayments", NStr("en = 'Expected payments'", MainLanguageCode));
	
	// Generate temporary table by accounts payable.
	Query.Text =
	"SELECT
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	DocumentTable.Period AS Date,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.Counterparty AS Counterparty,
	|	DocumentTable.DoOperationsByDocuments AS DoOperationsByDocuments,
	|	DocumentTable.GLAccountCustomerSettlements AS GLAccount,
	|	DocumentTable.Contract AS Contract,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByDocuments
	|			THEN DocumentTable.Document
	|		ELSE UNDEFINED
	|	END AS Document,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByOrders
	|				AND DocumentTable.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|				AND DocumentTable.Order <> VALUE(Document.WorkOrder.EmptyRef)
	|			THEN DocumentTable.Order
	|		ELSE UNDEFINED
	|	END AS Order,
	|	DocumentTable.SettlementsCurrency AS Currency,
	|	VALUE(Enum.SettlementsTypes.Debt) AS SettlementsType,
	|	SUM(DocumentTable.Amount) AS Amount,
	|	SUM(DocumentTable.AmountCur) AS AmountCur,
	|	SUM(DocumentTable.Amount) AS AmountForBalance,
	|	SUM(DocumentTable.AmountCur) AS AmountCurForBalance,
	|	SUM(CASE
	|			WHEN DocumentTable.SetPaymentTerms
	|				THEN 0
	|			ELSE DocumentTable.Amount
	|		END) AS AmountForPayment,
	|	SUM(CASE
	|			WHEN DocumentTable.SetPaymentTerms
	|				THEN 0
	|			ELSE DocumentTable.AmountCur
	|		END) AS AmountForPaymentCur,
	|	CAST(&AppearenceOfCustomerLiability AS STRING(100)) AS ContentOfAccountingRecord
	|INTO TemporaryTableAccountsReceivable
	|FROM
	|	TemporaryTableInventory AS DocumentTable
	|WHERE
	|	DocumentTable.Amount <> 0
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
	|				AND DocumentTable.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|				AND DocumentTable.Order <> VALUE(Document.WorkOrder.EmptyRef)
	|			THEN DocumentTable.Order
	|		ELSE UNDEFINED
	|	END,
	|	DocumentTable.SettlementsCurrency,
	|	DocumentTable.GLAccountCustomerSettlements
	|
	|UNION ALL
	|
	|SELECT
	|	VALUE(AccumulationRecordType.Receipt),
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	DocumentTable.Counterparty,
	|	DocumentTable.DoOperationsByDocuments,
	|	DocumentTable.CustomerAdvancesGLAccount,
	|	DocumentTable.Contract,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByDocuments
	|			THEN DocumentTable.Document
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByOrders
	|				AND DocumentTable.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|				AND DocumentTable.Order <> VALUE(Document.WorkOrder.EmptyRef)
	|			THEN DocumentTable.Order
	|		ELSE UNDEFINED
	|	END,
	|	DocumentTable.SettlementsCurrency,
	|	DocumentTable.SettlementsType,
	|	SUM(DocumentTable.Amount),
	|	SUM(DocumentTable.AmountCur),
	|	SUM(DocumentTable.Amount),
	|	SUM(DocumentTable.AmountCur),
	|	SUM(DocumentTable.Amount),
	|	SUM(DocumentTable.AmountCur),
	|	CAST(&AdvanceCredit AS STRING(100))
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
	|		WHEN DocumentTable.DoOperationsByOrders
	|				AND DocumentTable.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|				AND DocumentTable.Order <> VALUE(Document.WorkOrder.EmptyRef)
	|			THEN DocumentTable.Order
	|		ELSE UNDEFINED
	|	END,
	|	DocumentTable.SettlementsType,
	|	DocumentTable.SettlementsCurrency,
	|	DocumentTable.CustomerAdvancesGLAccount
	|
	|UNION ALL
	|
	|SELECT
	|	VALUE(AccumulationRecordType.Expense),
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	DocumentTable.Counterparty,
	|	DocumentTable.DoOperationsByDocuments,
	|	DocumentTable.GLAccountCustomerSettlements,
	|	DocumentTable.Contract,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByDocuments
	|			THEN DocumentTable.DocumentWhere
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByOrders
	|				AND DocumentTable.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|				AND DocumentTable.Order <> VALUE(Document.WorkOrder.EmptyRef)
	|			THEN DocumentTable.Order
	|		ELSE UNDEFINED
	|	END,
	|	DocumentTable.SettlementsCurrency,
	|	DocumentTable.SettlemensTypeWhere,
	|	SUM(DocumentTable.Amount),
	|	SUM(DocumentTable.AmountCur),
	|	-SUM(DocumentTable.Amount),
	|	-SUM(DocumentTable.AmountCur),
	|	SUM(DocumentTable.Amount),
	|	SUM(DocumentTable.AmountCur),
	|	CAST(&AdvanceCredit AS STRING(100))
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
	|		WHEN DocumentTable.DoOperationsByOrders
	|				AND DocumentTable.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|				AND DocumentTable.Order <> VALUE(Document.WorkOrder.EmptyRef)
	|			THEN DocumentTable.Order
	|		ELSE UNDEFINED
	|	END,
	|	DocumentTable.GLAccountCustomerSettlements,
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
	|	Calendar.Amount,
	|	Calendar.AmountCur,
	|	CAST(&ExpectedPayments AS STRING(100))
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
	
	// Setting the exclusive lock for the controlled balances of accounts receivable.
	Query.Text =
	"SELECT
	|	TemporaryTableAccountsReceivable.Company AS Company,
	|	TemporaryTableAccountsReceivable.Counterparty AS Counterparty,
	|	TemporaryTableAccountsReceivable.Contract AS Contract,
	|	TemporaryTableAccountsReceivable.Document AS Document,
	|	TemporaryTableAccountsReceivable.Order AS Order,
	|	TemporaryTableAccountsReceivable.SettlementsType AS SettlementsType
	|FROM
	|	TemporaryTableAccountsReceivable";
	
	QueryResult = Query.Execute();
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.AccountsReceivable");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;
	
	For Each ColumnQueryResult In QueryResult.Columns Do
		LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
	EndDo;
	Block.Lock();
	
	QueryNumber = 0;
	Query.Text = DriveServer.GetQueryTextCurrencyExchangeRateAccountsReceivable(Query.TempTablesManager, True, QueryNumber);
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountsReceivable", ResultsArray[QueryNumber].Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableIncomeAndExpensesRetained(DocumentRefSalesInvoice, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefSalesInvoice);
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
	|	DocumentTable.Amount - DocumentTable.VATAmount AS AmountIncome
	|FROM
	|	TemporaryTableInventory AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.Amount <> 0
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
			ElsIf StringInventoryIncomeAndExpensesRetained.AmountIncome <= AmountToBeWrittenOff Then
				StringPrepaymentIncomeAndExpensesRetained = TablePrepaymentIncomeAndExpensesRetained.Add();
				FillPropertyValues(StringPrepaymentIncomeAndExpensesRetained, StringInventoryIncomeAndExpensesRetained);
				AmountToBeWrittenOff = AmountToBeWrittenOff - StringInventoryIncomeAndExpensesRetained.AmountIncome;
			ElsIf StringInventoryIncomeAndExpensesRetained.AmountIncome > AmountToBeWrittenOff Then
				StringPrepaymentIncomeAndExpensesRetained = TablePrepaymentIncomeAndExpensesRetained.Add();
				FillPropertyValues(StringPrepaymentIncomeAndExpensesRetained, StringInventoryIncomeAndExpensesRetained);
				StringPrepaymentIncomeAndExpensesRetained.AmountIncome = AmountToBeWrittenOff;
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
		Item = Catalogs.CashFlowItems.PaymentFromCustomers;
	EndIf;
	
	Query.Text =
	"SELECT
	|	Table.LineNumber AS LineNumber,
	|	Table.Period AS Period,
	|	Table.Company AS Company,
	|	Table.Document AS Document,
	|	&Item AS Item,
	|	Table.BusinessLine AS BusinessLine,
	|	Table.AmountIncome AS AmountIncome
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
Procedure GenerateTableUnallocatedExpenses(DocumentRefSalesInvoice, StructureAdditionalProperties)
	
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
	|	DocumentTable.Amount AS AmountIncome
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
Procedure GenerateTableIncomeAndExpensesCashMethod(DocumentRefSalesInvoice, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefSalesInvoice);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("IncomeAndExpensesAccountingCashMethod", StructureAdditionalProperties.AccountingPolicy.IncomeAndExpensesAccountingCashMethod);
	
	Query.Text =
	"SELECT
	|	DocumentTable.DocumentDate AS Period,
	|	DocumentTable.Company AS Company,
	|	UNDEFINED AS BusinessLine,
	|	DocumentTable.Item AS Item,
	|	-DocumentTable.Amount AS AmountIncome
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
	|	Table.AmountIncome
	|FROM
	|	TemporaryTablePrepaidIncomeAndExpensesRetained AS Table";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpensesCashMethod", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableAccountingJournalEntries(DocumentRefSalesInvoice, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	1 AS Ordering,
	|	TableAccountingJournalEntries.Period AS Period,
	|	TableAccountingJournalEntries.Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	TableAccountingJournalEntries.GLAccountCustomerSettlements AS AccountDr,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccountCustomerSettlements.Currency
	|			THEN TableAccountingJournalEntries.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccountCustomerSettlements.Currency
	|			THEN TableAccountingJournalEntries.AmountCur - TableAccountingJournalEntries.VATAmountCur
	|		ELSE 0
	|	END AS AmountCurDr,
	|	CASE
	|		WHEN TableAccountingJournalEntries.ProductsOnCommission
	|			THEN TableAccountingJournalEntries.GLAccountVendorSettlements
	|		ELSE TableAccountingJournalEntries.AccountStatementSales
	|	END AS AccountCr,
	|	CASE
	|		WHEN TableAccountingJournalEntries.ProductsOnCommission
	|			THEN &PresentationCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	CASE
	|		WHEN TableAccountingJournalEntries.ProductsOnCommission
	|			THEN TableAccountingJournalEntries.Amount - TableAccountingJournalEntries.VATAmount
	|		ELSE 0
	|	END AS AmountCurCr,
	|	TableAccountingJournalEntries.Amount - TableAccountingJournalEntries.VATAmount AS Amount,
	|	&IncomeReflection AS Content,
	|	FALSE AS OfflineRecord
	|FROM
	|	TemporaryTableInventory AS TableAccountingJournalEntries
	|WHERE
	|	TableAccountingJournalEntries.Amount <> 0
	|	AND (NOT TableAccountingJournalEntries.AdvanceInvoicing
	|			OR NOT TableAccountingJournalEntries.GoodsIssue = VALUE(Document.GoodsIssue.EmptyRef)
	|			OR NOT TableAccountingJournalEntries.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem))
	|
	|UNION ALL
	|
	|SELECT
	|	2 AS Ordering,
	|	TableAccountingJournalEntries.Period AS Period,
	|	TableAccountingJournalEntries.Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	TableAccountingJournalEntries.GLAccountCustomerSettlements AS AccountDr,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccountCustomerSettlements.Currency
	|			THEN TableAccountingJournalEntries.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccountCustomerSettlements.Currency
	|			THEN TableAccountingJournalEntries.AmountCur - TableAccountingJournalEntries.VATAmountCur
	|		ELSE 0
	|	END AS AmountCurDr,
	|	CASE
	|		WHEN TableAccountingJournalEntries.ProductsOnCommission
	|			THEN TableAccountingJournalEntries.GLAccountVendorSettlements
	|		ELSE TableAccountingJournalEntries.AccountStatementDeferredSales
	|	END AS AccountCr,
	|	CASE
	|		WHEN TableAccountingJournalEntries.ProductsOnCommission
	|			THEN &PresentationCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	CASE
	|		WHEN TableAccountingJournalEntries.ProductsOnCommission
	|			THEN TableAccountingJournalEntries.Amount - TableAccountingJournalEntries.VATAmount
	|		ELSE 0
	|	END AS AmountCurCr,
	|	TableAccountingJournalEntries.Amount - TableAccountingJournalEntries.VATAmount AS Amount,
	|	&DeferredIncomeReflection AS Content,
	|	FALSE AS OfflineRecord
	|FROM
	|	TemporaryTableInventory AS TableAccountingJournalEntries
	|WHERE
	|	TableAccountingJournalEntries.Amount <> 0
	|	AND TableAccountingJournalEntries.AdvanceInvoicing
	|	AND TableAccountingJournalEntries.GoodsIssue = VALUE(Document.GoodsIssue.EmptyRef)
	|	AND TableAccountingJournalEntries.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
	|
	|UNION ALL
	|
	|SELECT
	|	3,
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.CustomerAdvancesGLAccount,
	|	CASE
	|		WHEN DocumentTable.CustomerAdvancesGLAccountForeignCurrency
	|			THEN DocumentTable.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.CustomerAdvancesGLAccountForeignCurrency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END,
	|	DocumentTable.GLAccountCustomerSettlements,
	|	CASE
	|		WHEN DocumentTable.GLAccountCustomerSettlementsCurrency
	|			THEN DocumentTable.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.GLAccountCustomerSettlementsCurrency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END,
	|	DocumentTable.Amount,
	|	&SetOffAdvancePayment,
	|	FALSE
	|FROM
	|	(SELECT
	|		DocumentTable.Period AS Period,
	|		DocumentTable.Company AS Company,
	|		DocumentTable.CustomerAdvancesGLAccount AS CustomerAdvancesGLAccount,
	|		DocumentTable.CustomerAdvancesGLAccountForeignCurrency AS CustomerAdvancesGLAccountForeignCurrency,
	|		DocumentTable.GLAccountCustomerSettlements AS GLAccountCustomerSettlements,
	|		DocumentTable.GLAccountCustomerSettlementsCurrency AS GLAccountCustomerSettlementsCurrency,
	|		DocumentTable.SettlementsCurrency AS SettlementsCurrency,
	|		SUM(DocumentTable.AmountCur) AS AmountCur,
	|		SUM(DocumentTable.Amount) AS Amount
	|	FROM
	|		(SELECT
	|			DocumentTable.Period AS Period,
	|			DocumentTable.Company AS Company,
	|			DocumentTable.CustomerAdvancesGLAccount AS CustomerAdvancesGLAccount,
	|			DocumentTable.CustomerAdvancesGLAccount.Currency AS CustomerAdvancesGLAccountForeignCurrency,
	|			DocumentTable.GLAccountCustomerSettlements AS GLAccountCustomerSettlements,
	|			DocumentTable.GLAccountCustomerSettlements.Currency AS GLAccountCustomerSettlementsCurrency,
	|			DocumentTable.SettlementsCurrency AS SettlementsCurrency,
	|			DocumentTable.AmountCur AS AmountCur,
	|			DocumentTable.Amount AS Amount
	|		FROM
	|			TemporaryTablePrepayment AS DocumentTable
	|		
	|		UNION ALL
	|		
	|		SELECT
	|			DocumentTable.Date,
	|			DocumentTable.Company,
	|			DocumentTable.Counterparty.CustomerAdvancesGLAccount,
	|			DocumentTable.Counterparty.CustomerAdvancesGLAccount.Currency,
	|			DocumentTable.Counterparty.GLAccountCustomerSettlements,
	|			DocumentTable.Counterparty.GLAccountCustomerSettlements.Currency,
	|			DocumentTable.Currency,
	|			0,
	|			DocumentTable.AmountOfExchangeDifferences
	|		FROM
	|			TemporaryTableExchangeRateDifferencesAccountsReceivable AS DocumentTable
	|		WHERE
	|			DocumentTable.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)) AS DocumentTable
	|	
	|	GROUP BY
	|		DocumentTable.Period,
	|		DocumentTable.Company,
	|		DocumentTable.CustomerAdvancesGLAccount,
	|		DocumentTable.CustomerAdvancesGLAccountForeignCurrency,
	|		DocumentTable.GLAccountCustomerSettlements,
	|		DocumentTable.GLAccountCustomerSettlementsCurrency,
	|		DocumentTable.SettlementsCurrency
	|	
	|	HAVING
	|		(SUM(DocumentTable.Amount) >= 0.005
	|			OR SUM(DocumentTable.Amount) <= -0.005
	|			OR SUM(DocumentTable.AmountCur) >= 0.005
	|			OR SUM(DocumentTable.AmountCur) <= -0.005)) AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	6,
	|	TableAccountingJournalEntries.Date,
	|	TableAccountingJournalEntries.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	CASE
	|		WHEN TableAccountingJournalEntries.AmountOfExchangeDifferences > 0
	|			THEN TableAccountingJournalEntries.GLAccount
	|		ELSE &NegativeExchangeDifferenceAccountOfAccounting
	|	END,
	|	CASE
	|		WHEN TableAccountingJournalEntries.AmountOfExchangeDifferences > 0
	|				AND TableAccountingJournalEntries.GLAccountForeignCurrency
	|			THEN TableAccountingJournalEntries.Currency
	|		ELSE UNDEFINED
	|	END,
	|	0,
	|	CASE
	|		WHEN TableAccountingJournalEntries.AmountOfExchangeDifferences > 0
	|			THEN &PositiveExchangeDifferenceGLAccount
	|		ELSE TableAccountingJournalEntries.GLAccount
	|	END,
	|	CASE
	|		WHEN TableAccountingJournalEntries.AmountOfExchangeDifferences < 0
	|				AND TableAccountingJournalEntries.GLAccountForeignCurrency
	|			THEN TableAccountingJournalEntries.Currency
	|		ELSE UNDEFINED
	|	END,
	|	0,
	|	CASE
	|		WHEN TableAccountingJournalEntries.AmountOfExchangeDifferences > 0
	|			THEN TableAccountingJournalEntries.AmountOfExchangeDifferences
	|		ELSE -TableAccountingJournalEntries.AmountOfExchangeDifferences
	|	END,
	|	&ExchangeDifference,
	|	FALSE
	|FROM
	|	(SELECT
	|		TableExchangeRateDifferencesAccountsReceivable.Date AS Date,
	|		TableExchangeRateDifferencesAccountsReceivable.Company AS Company,
	|		TableExchangeRateDifferencesAccountsReceivable.GLAccount AS GLAccount,
	|		TableExchangeRateDifferencesAccountsReceivable.GLAccountForeignCurrency AS GLAccountForeignCurrency,
	|		TableExchangeRateDifferencesAccountsReceivable.Currency AS Currency,
	|		SUM(TableExchangeRateDifferencesAccountsReceivable.AmountOfExchangeDifferences) AS AmountOfExchangeDifferences
	|	FROM
	|		(SELECT
	|			DocumentTable.Date AS Date,
	|			DocumentTable.Company AS Company,
	|			DocumentTable.GLAccount AS GLAccount,
	|			DocumentTable.GLAccount.Currency AS GLAccountForeignCurrency,
	|			DocumentTable.Currency AS Currency,
	|			DocumentTable.AmountOfExchangeDifferences AS AmountOfExchangeDifferences
	|		FROM
	|			TemporaryTableExchangeRateDifferencesAccountsReceivable AS DocumentTable
	|		WHERE
	|			DocumentTable.SettlementsType = VALUE(Enum.SettlementsTypes.Debt)
	|		
	|		UNION ALL
	|		
	|		SELECT
	|			DocumentTable.Date,
	|			DocumentTable.Company,
	|			DocumentTable.GLAccount,
	|			DocumentTable.GLAccount.Currency,
	|			DocumentTable.Currency,
	|			DocumentTable.AmountOfExchangeDifferences
	|		FROM
	|			TemporaryTableExchangeRateDifferencesAccountsReceivable AS DocumentTable
	|		WHERE
	|			DocumentTable.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)) AS TableExchangeRateDifferencesAccountsReceivable
	|	
	|	GROUP BY
	|		TableExchangeRateDifferencesAccountsReceivable.Date,
	|		TableExchangeRateDifferencesAccountsReceivable.Company,
	|		TableExchangeRateDifferencesAccountsReceivable.GLAccount,
	|		TableExchangeRateDifferencesAccountsReceivable.GLAccountForeignCurrency,
	|		TableExchangeRateDifferencesAccountsReceivable.Currency
	|	
	|	HAVING
	|		(SUM(TableExchangeRateDifferencesAccountsReceivable.AmountOfExchangeDifferences) >= 0.005
	|			OR SUM(TableExchangeRateDifferencesAccountsReceivable.AmountOfExchangeDifferences) <= -0.005)) AS TableAccountingJournalEntries
	|
	|UNION ALL
	|
	|SELECT
	|	7,
	|	TableAccountingJournalEntries.Period,
	|	TableAccountingJournalEntries.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	TableAccountingJournalEntries.GLAccountCustomerSettlements,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccountCustomerSettlements.Currency
	|			THEN TableAccountingJournalEntries.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	SUM(CASE
	|			WHEN TableAccountingJournalEntries.GLAccountCustomerSettlements.Currency
	|				THEN TableAccountingJournalEntries.VATAmountCur
	|			ELSE 0
	|		END),
	|	TableAccountingJournalEntries.VATOutputGLAccount,
	|	UNDEFINED,
	|	0,
	|	TableAccountingJournalEntries.VATAmount,
	|	&VAT,
	|	FALSE
	|FROM
	|	TemporaryTableInventory AS TableAccountingJournalEntries
	|WHERE
	|	TableAccountingJournalEntries.VATAmount <> 0
	|
	|GROUP BY
	|	TableAccountingJournalEntries.Company,
	|	TableAccountingJournalEntries.GLAccountCustomerSettlements,
	|	TableAccountingJournalEntries.VATAmount,
	|	TableAccountingJournalEntries.Period,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccountCustomerSettlements.Currency
	|			THEN TableAccountingJournalEntries.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	TableAccountingJournalEntries.VATOutputGLAccount
	|
	|UNION ALL
	|
	|SELECT
	|	9,
	|	PrepaymentVAT.Period,
	|	PrepaymentVAT.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	&VATOutput,
	|	UNDEFINED,
	|	0,
	|	&VATAdvancesFromCustomers,
	|	UNDEFINED,
	|	0,
	|	SUM(PrepaymentVAT.VATAmount),
	|	&ContentVATRevenue,
	|	FALSE
	|FROM
	|	TemporaryTablePrepaymentVAT AS PrepaymentVAT
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
	|	10,
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
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();
	
	Query.SetParameter("SetOffAdvancePayment",							NStr("en = 'Advance payment clearing'", MainLanguageCode));
	Query.SetParameter("PrepaymentReversal",							NStr("en = 'Advance payment reversal'", MainLanguageCode));
	Query.SetParameter("ReversingSupplies",								NStr("en = 'Purchase reversal'", MainLanguageCode));
	Query.SetParameter("IncomeReflection",								NStr("en = 'Revenue'", MainLanguageCode));
	Query.SetParameter("DeferredIncomeReflection",						NStr("en = 'Deferred revenue'", MainLanguageCode));
	Query.SetParameter("PresentationCurrency",							Constants.PresentationCurrency.Get());
	Query.SetParameter("PositiveExchangeDifferenceGLAccount",			Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeGain"));
	Query.SetParameter("NegativeExchangeDifferenceAccountOfAccounting",	Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeLoss"));
	Query.SetParameter("ExchangeDifference",							NStr("en = 'Foreign currency exchange gains and losses'", MainLanguageCode));
	Query.SetParameter("VAT",											NStr("en = 'VAT'", MainLanguageCode));
	Query.SetParameter("ContentVATRevenue",								NStr("en = 'Deduction of VAT charged on advance payment'", MainLanguageCode));
	Query.SetParameter("VATAdvancesFromCustomers",						Catalogs.DefaultGLAccounts.GetDefaultGLAccount("VATAdvancesFromCustomers"));
	Query.SetParameter("VATOutput",										Catalogs.DefaultGLAccounts.GetDefaultGLAccount("VATOutput"));
	Query.SetParameter("Date",											StructureAdditionalProperties.ForPosting.Date);
	Query.SetParameter("Company",										StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PostVATEntriesBySourceDocuments",				StructureAdditionalProperties.AccountingPolicy.PostVATEntriesBySourceDocuments);
	Query.SetParameter("PostVATEntriesBySourceDocuments",				StructureAdditionalProperties.AccountingPolicy.PostVATEntriesBySourceDocuments);
	Query.SetParameter("Ref",											DocumentRefSalesInvoice);
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	
	While Selection.Next() Do
		NewEntry = StructureAdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries.Add();
		FillPropertyValues(NewEntry, Selection);
	EndDo;
	
EndProcedure

Procedure GenerateTableGoodsShippedNotInvoiced(DocumentRefSalesInvoice, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	MIN(TableProducts.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableProducts.Period AS Period,
	|	TableProducts.GoodsIssue AS GoodsIssue,
	|	TableProducts.Company AS Company,
	|	TableProducts.Counterparty AS Counterparty,
	|	TableProducts.Contract AS Contract,
	|	TableProducts.Products AS Products,
	|	TableProducts.Characteristic AS Characteristic,
	|	TableProducts.Batch AS Batch,
	|	TableProducts.Order AS SalesOrder,
	|	SUM(TableProducts.Quantity) AS Quantity
	|FROM
	|	TemporaryTableInventory AS TableProducts
	|WHERE
	|	TableProducts.GoodsIssue <> VALUE(Document.GoodsIssue.EmptyRef)
	|	AND TableProducts.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
	|
	|GROUP BY
	|	TableProducts.Period,
	|	TableProducts.Company,
	|	TableProducts.Counterparty,
	|	TableProducts.Contract,
	|	TableProducts.Products,
	|	TableProducts.Characteristic,
	|	TableProducts.Batch,
	|	TableProducts.Order,
	|	TableProducts.GoodsIssue";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableGoodsShippedNotInvoiced", QueryResult.Unload());
	
EndProcedure

Procedure GenerateTableGoodsInvoicedNotShipped(DocumentRefSalesInvoice, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	MIN(TableProducts.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TableProducts.Period AS Period,
	|	TableProducts.Document AS SalesInvoice,
	|	TableProducts.Company AS Company,
	|	TableProducts.Counterparty AS Counterparty,
	|	TableProducts.Contract AS Contract,
	|	TableProducts.Order AS SalesOrder,
	|	TableProducts.Products AS Products,
	|	TableProducts.Characteristic AS Characteristic,
	|	TableProducts.Batch AS Batch,
	|	TableProducts.VATRate AS VATRate,
	|	TableProducts.DepartmentSales AS Department,
	|	TableProducts.Responsible AS Responsible,
	|	SUM(TableProducts.Quantity) AS Quantity,
	|	SUM(TableProducts.Amount - TableProducts.AmountVATPurchaseSale) AS Amount,
	|	SUM(TableProducts.AmountVATPurchaseSale) AS VATAmount
	|FROM
	|	TemporaryTableInventory AS TableProducts
	|WHERE
	|	TableProducts.AdvanceInvoicing
	|	AND TableProducts.GoodsIssue = VALUE(Document.GoodsIssue.EmptyRef)
	|	AND TableProducts.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
	|
	|GROUP BY
	|	TableProducts.Company,
	|	TableProducts.Counterparty,
	|	TableProducts.Contract,
	|	TableProducts.Period,
	|	TableProducts.Document,
	|	TableProducts.Order,
	|	TableProducts.Products,
	|	TableProducts.Characteristic,
	|	TableProducts.Batch,
	|	TableProducts.VATRate,
	|	TableProducts.DepartmentSales,
	|	TableProducts.Responsible";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableGoodsInvoicedNotShipped", QueryResult.Unload());
	
EndProcedure

#Region DiscountCards

// Generates values table creating data for posting by the SalesWithCardBasedDiscounts register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableSalesByDiscountCard(DocumentRefSalesInvoice, StructureAdditionalProperties)
	
	If DocumentRefSalesInvoice.DiscountCard.IsEmpty() Then
		StructureAdditionalProperties.TableForRegisterRecords.Insert("SaleByDiscountCardTable", New ValueTable);
		Return;
	EndIf;
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	TableSales.Period AS Period,
	|	TableSales.Document.DiscountCard AS DiscountCard,
	|	TableSales.Document.DiscountCard.CardOwner AS CardOwner,
	|	SUM(TableSales.Amount) AS Amount
	|FROM
	|	TemporaryTableInventory AS TableSales
	|
	|GROUP BY
	|	TableSales.Period,
	|	TableSales.Document.DiscountCard,
	|	TableSales.Document.DiscountCard.CardOwner";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("SaleByDiscountCardTable", QueryResult.Unload());
	
EndProcedure

#EndRegion

#Region AutomaticDiscounts

// Generates a table of values that contains the data for posting by the register AutomaticDiscountsApplied.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableSalesByAutomaticDiscountsApplied(DocumentRefSalesInvoice, StructureAdditionalProperties)
	
	If DocumentRefSalesInvoice.DiscountsMarkups.Count() = 0 Or Not GetFunctionalOption("UseAutomaticDiscounts") Then
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAutomaticDiscountsApplied", New ValueTable);
		Return;
	EndIf;
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	TemporaryTableAutoDiscountsMarkups.Period,
	|	TemporaryTableAutoDiscountsMarkups.DiscountMarkup AS AutomaticDiscount,
	|	TemporaryTableAutoDiscountsMarkups.Amount AS DiscountAmount,
	|	TemporaryTableInventory.Products,
	|	TemporaryTableInventory.Characteristic,
	|	TemporaryTableInventory.Document AS DocumentDiscounts,
	|	TemporaryTableInventory.Counterparty AS RecipientDiscounts
	|FROM
	|	TemporaryTableInventory AS TemporaryTableInventory
	|		INNER JOIN TemporaryTableAutoDiscountsMarkups AS TemporaryTableAutoDiscountsMarkups
	|		ON TemporaryTableInventory.ConnectionKey = TemporaryTableAutoDiscountsMarkups.ConnectionKey";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAutomaticDiscountsApplied", QueryResult.Unload());
	
EndProcedure

#EndRegion

Procedure GenerateTableVATOutput(DocumentRefSalesInvoice, StructureAdditionalProperties)
	
	If WorkWithVAT.GetUseTaxInvoiceForPostingVAT(DocumentRefSalesInvoice.Date, DocumentRefSalesInvoice.Company) Then
		
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableVATOutput", New ValueTable);
		Return;
		
	EndIf;
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.Text =
	"SELECT
	|	TemporaryTableInventory.Document AS ShipmentDocument,
	|	TemporaryTableInventory.Period AS Period,
	|	TemporaryTableInventory.Company AS Company,
	|	TemporaryTableInventory.Counterparty AS Customer,
	|	TemporaryTableInventory.VATRate AS VATRate,
	|	CASE
	|		WHEN TemporaryTableInventory.VATTaxation = VALUE(Enum.VATTaxationTypes.ForExport)
	|				OR TemporaryTableInventory.VATTaxation = VALUE(Enum.VATTaxationTypes.ReverseChargeVAT)
	|			THEN VALUE(Enum.VATOperationTypes.Export)
	|		ELSE VALUE(Enum.VATOperationTypes.Sales)
	|	END AS OperationType,
	|	TemporaryTableInventory.ProductsType AS ProductType,
	|	SUM(TemporaryTableInventory.VATAmountCur) * CASE
	|		WHEN TemporaryTableInventory.DocumentCurrency = TemporaryTableInventory.NationalCurrency
	|			THEN 1
	|		ELSE TemporaryTableInventory.ExchangeRate / TemporaryTableInventory.Multiplicity
	|	END AS VATAmount,
	|	SUM(TemporaryTableInventory.AmountCur - TemporaryTableInventory.VATAmountCur) * CASE
	|		WHEN TemporaryTableInventory.DocumentCurrency = TemporaryTableInventory.NationalCurrency
	|			THEN 1
	|		ELSE TemporaryTableInventory.ExchangeRate / TemporaryTableInventory.Multiplicity
	|	END AS AmountExcludesVAT
	|FROM
	|	TemporaryTableInventory AS TemporaryTableInventory
	|WHERE
	|	NOT TemporaryTableInventory.VATRate.NotTaxable
	|
	|GROUP BY
	|	TemporaryTableInventory.VATRate,
	|	TemporaryTableInventory.VATTaxation,
	|	TemporaryTableInventory.ProductsType,
	|	TemporaryTableInventory.Document,
	|	TemporaryTableInventory.Period,
	|	TemporaryTableInventory.Company,
	|	TemporaryTableInventory.Counterparty,
	|	TemporaryTableInventory.NationalCurrency,
	|	TemporaryTableInventory.DocumentCurrency,
	|	TemporaryTableInventory.Multiplicity,
	|	TemporaryTableInventory.ExchangeRate
	|
	|UNION ALL
	|
	|SELECT
	|	Prepayment.ShipmentDocument,
	|	Prepayment.Period,
	|	Prepayment.Company,
	|	Prepayment.Customer,
	|	Prepayment.VATRate,
	|	VALUE(Enum.VATOperationTypes.AdvanceCleared),
	|	VALUE(Enum.ProductsTypes.EmptyRef),
	|	-Prepayment.VATAmount,
	|	-Prepayment.AmountExcludesVAT
	|FROM
	|	TemporaryTablePrepaymentVAT AS Prepayment";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableVATOutput", QueryResult.Unload());
	
EndProcedure

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefSalesInvoice, StructureAdditionalProperties) Export
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	Header.Ref AS Ref,
	|	Header.Date AS Date,
	|	Header.Company AS Company,
	|	Header.Counterparty AS Counterparty,
	|	Header.Contract AS Contract,
	|	Header.Order AS Order,
	|	Header.AmountIncludesVAT AS AmountIncludesVAT,
	|	Header.ExchangeRate AS ExchangeRate,
	|	Header.Multiplicity AS Multiplicity
	|INTO SalesInvoiceHeader
	|FROM
	|	Document.SalesInvoice AS Header
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
	|	InformationRegister.ExchangeRates.SliceLast(&PointInTime, Currency IN (&PresentationCurrency, &NationalCurrency, &InvoiceCurrency)) AS ExchangeRatesSliceLast
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SalesInvoiceInventory.LineNumber AS LineNumber,
	|	SalesInvoiceInventory.Ref AS Document,
	|	SalesInvoiceInventory.Ref.Responsible AS Responsible,
	|	SalesInvoiceInventory.Ref.BasisDocument AS BasisDocument,
	|	SalesInvoiceInventory.Ref.Counterparty AS Counterparty,
	|	SalesInvoiceInventory.Ref.Counterparty.DoOperationsByContracts AS DoOperationsByContracts,
	|	SalesInvoiceInventory.Ref.Counterparty.DoOperationsByDocuments AS DoOperationsByDocuments,
	|	SalesInvoiceInventory.Ref.Counterparty.DoOperationsByOrders AS DoOperationsByOrders,
	|	SalesInvoiceInventory.Ref.Contract AS Contract,
	|	SalesInvoiceInventory.Ref.Date AS Period,
	|	&Company AS Company,
	|	UNDEFINED AS CorrOrganization,
	|	SalesInvoiceInventory.Ref.Department AS DepartmentSales,
	|	SalesInvoiceInventory.Products.BusinessLine AS BusinessLineSales,
	|	SalesInvoiceInventory.RevenueGLAccount AS AccountStatementSales,
	|	SalesInvoiceInventory.UnearnedRevenueGLAccount AS AccountStatementDeferredSales,
	|	SalesInvoiceInventory.COGSGLAccount AS GLAccountCost,
	|	SalesInvoiceInventory.Products.ProductsType AS ProductsType,
	|	CASE
	|		WHEN SalesInvoiceInventory.GoodsIssue = VALUE(Document.GoodsIssue.EmptyRef)
	|			THEN SalesInvoiceInventory.Ref.StructuralUnit
	|		ELSE SalesInvoiceInventory.Ref.Counterparty
	|	END AS StructuralUnit,
	|	UNDEFINED AS StructuralUnitCorr,
	|	CASE
	|		WHEN &UseStorageBins
	|			THEN SalesInvoiceInventory.Ref.Cell
	|		ELSE UNDEFINED
	|	END AS Cell,
	|	CASE
	|		WHEN SalesInvoiceInventory.GoodsIssue = VALUE(Document.GoodsIssue.EmptyRef)
	|				AND SalesInvoiceInventory.Batch <> VALUE(Catalog.ProductsBatches.EmptyRef)
	|				AND SalesInvoiceInventory.Batch.Status = VALUE(Enum.BatchStatuses.CounterpartysInventory)
	|			THEN SalesInvoiceInventory.InventoryReceivedGLAccount
	|		WHEN SalesInvoiceInventory.GoodsIssue = VALUE(Document.GoodsIssue.EmptyRef)
	|			THEN SalesInvoiceInventory.InventoryGLAccount
	|		ELSE SalesInvoiceInventory.GoodsShippedNotInvoicedGLAccount
	|	END AS GLAccount,
	|	UNDEFINED AS CorrGLAccount,
	|	FALSE AS ProductsOnCommission,
	|	SalesInvoiceInventory.Products AS Products,
	|	UNDEFINED AS ProductsCorr,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN SalesInvoiceInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	UNDEFINED AS CharacteristicCorr,
	|	CASE
	|		WHEN &UseBatches
	|			THEN SalesInvoiceInventory.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS Batch,
	|	UNDEFINED AS BatchCorr,
	|	SalesInvoiceInventory.Order AS Order,
	|	SalesInvoiceInventory.GoodsIssue AS GoodsIssue,
	|	UNDEFINED AS CorrOrder,
	|	CASE
	|		WHEN VALUETYPE(SalesInvoiceInventory.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN SalesInvoiceInventory.Quantity
	|		ELSE SalesInvoiceInventory.Quantity * SalesInvoiceInventory.MeasurementUnit.Factor
	|	END AS Quantity,
	|	CASE
	|		WHEN VALUETYPE(SalesInvoiceInventory.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN SalesInvoiceInventory.Reserve
	|		ELSE SalesInvoiceInventory.Reserve * SalesInvoiceInventory.MeasurementUnit.Factor
	|	END AS Reserve,
	|	SalesInvoiceInventory.VATRate AS VATRate,
	|	CAST(CASE
	|			WHEN SalesInvoiceInventory.Ref.IncludeVATInPrice
	|				THEN 0
	|			ELSE CASE
	|					WHEN SalesInvoiceInventory.Ref.DocumentCurrency = &NationalCurrency
	|						THEN SalesInvoiceInventory.VATAmount * RegExchangeRates.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * RegExchangeRates.Multiplicity)
	|					ELSE SalesInvoiceInventory.VATAmount * SalesInvoiceInventory.Ref.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * SalesInvoiceInventory.Ref.Multiplicity)
	|				END
	|		END AS NUMBER(15, 2)) AS VATAmount,
	|	CAST(CASE
	|			WHEN SalesInvoiceInventory.Ref.DocumentCurrency = &NationalCurrency
	|				THEN SalesInvoiceInventory.VATAmount * RegExchangeRates.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * RegExchangeRates.Multiplicity)
	|			ELSE SalesInvoiceInventory.VATAmount * SalesInvoiceInventory.Ref.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * SalesInvoiceInventory.Ref.Multiplicity)
	|		END AS NUMBER(15, 2)) AS AmountVATPurchaseSale,
	|	CAST(CASE
	|			WHEN SalesInvoiceInventory.Ref.DocumentCurrency = &NationalCurrency
	|				THEN SalesInvoiceInventory.Total * RegExchangeRates.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * RegExchangeRates.Multiplicity)
	|			ELSE SalesInvoiceInventory.Total * SalesInvoiceInventory.Ref.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * SalesInvoiceInventory.Ref.Multiplicity)
	|		END AS NUMBER(15, 2)) AS Amount,
	|	CAST(CASE
	|			WHEN SalesInvoiceInventory.Ref.IncludeVATInPrice
	|				THEN 0
	|			ELSE CASE
	|					WHEN SalesInvoiceInventory.Ref.DocumentCurrency = &NationalCurrency
	|						THEN SalesInvoiceInventory.VATAmount * RegExchangeRates.ExchangeRate * SalesInvoiceInventory.Ref.Multiplicity / (SalesInvoiceInventory.Ref.ExchangeRate * RegExchangeRates.Multiplicity)
	|					ELSE SalesInvoiceInventory.VATAmount
	|				END
	|		END AS NUMBER(15, 2)) AS VATAmountCur,
	|	CAST(CASE
	|			WHEN SalesInvoiceInventory.Ref.DocumentCurrency = &NationalCurrency
	|				THEN SalesInvoiceInventory.Total * RegExchangeRates.ExchangeRate * SalesInvoiceInventory.Ref.Multiplicity / (SalesInvoiceInventory.Ref.ExchangeRate * RegExchangeRates.Multiplicity)
	|			ELSE SalesInvoiceInventory.Total
	|		END AS NUMBER(15, 2)) AS AmountCur,
	|	SalesInvoiceInventory.Total AS SettlementsAmountTakenPassed,
	|	SalesInvoiceInventory.Ref.Counterparty.GLAccountCustomerSettlements AS GLAccountCustomerSettlements,
	|	SalesInvoiceInventory.Ref.Counterparty.GLAccountVendorSettlements AS GLAccountVendorSettlements,
	|	SalesInvoiceInventory.Ref.Contract.SettlementsCurrency AS SettlementsCurrency,
	|	SalesInvoiceInventory.ConnectionKey AS ConnectionKey,
	|	SalesInvoiceInventory.Ref.DocumentCurrency AS DocumentCurrency,
	|	SalesInvoiceInventory.Ref.ExchangeRate AS ExchangeRate,
	|	SalesInvoiceInventory.Ref.Multiplicity AS Multiplicity,
	|	SalesInvoiceInventory.Ref.VATTaxation AS VATTaxation,
	|	SalesInvoiceInventory.Ref.AdvanceInvoicing AS AdvanceInvoicing,
	|	&PresentationCurrency AS PresentationCurrency,
	|	&NationalCurrency AS NationalCurrency,
	|	SalesInvoiceInventory.Ref.SetPaymentTerms AS SetPaymentTerms,
	|	SalesInvoiceInventory.SalesRep AS SalesRep,
	|	SalesInvoiceInventory.VATOutputGLAccount AS VATOutputGLAccount
	|INTO TemporaryTableInventory
	|FROM
	|	Document.SalesInvoice.Inventory AS SalesInvoiceInventory
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS ManagExchangeRates
	|		ON (ManagExchangeRates.Currency = &PresentationCurrency)
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS RegExchangeRates
	|		ON (RegExchangeRates.Currency = &NationalCurrency)
	|WHERE
	|	SalesInvoiceInventory.Ref = &Ref
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
	|	DocumentTable.Ref.BasisDocument AS BasisDocument,
	|	DocumentTable.Document AS Document,
	|	CASE
	|		WHEN NOT DocumentTable.Ref.Counterparty.DoOperationsByDocuments
	|				OR VALUETYPE(DocumentTable.Document) = TYPE(Document.ArApAdjustments)
	|			THEN VALUE(Catalog.CashFlowItems.PaymentFromCustomers)
	|		ELSE CASE
	|				WHEN DocumentTable.Document REFS Document.PaymentExpense
	|					THEN CAST(DocumentTable.Document AS Document.PaymentExpense).Item
	|				WHEN DocumentTable.Document REFS Document.CashReceipt
	|					THEN CAST(DocumentTable.Document AS Document.CashReceipt).Item
	|				WHEN DocumentTable.Document REFS Document.CashVoucher
	|					THEN CAST(DocumentTable.Document AS Document.CashVoucher).Item
	|				WHEN DocumentTable.Document REFS Document.PaymentReceipt
	|					THEN CAST(DocumentTable.Document AS Document.PaymentReceipt).Item
	|				ELSE VALUE(Catalog.CashFlowItems.PaymentFromCustomers)
	|			END
	|	END AS Item,
	|	CASE
	|		WHEN DocumentTable.Ref.Counterparty.DoOperationsByDocuments
	|			THEN CASE
	|					WHEN DocumentTable.Document REFS Document.PaymentExpense
	|						THEN CAST(DocumentTable.Document AS Document.PaymentExpense).Date
	|					WHEN DocumentTable.Document REFS Document.CashReceipt
	|						THEN CAST(DocumentTable.Document AS Document.CashReceipt).Date
	|					WHEN DocumentTable.Document REFS Document.CashVoucher
	|						THEN CAST(DocumentTable.Document AS Document.CashVoucher).Date
	|					WHEN DocumentTable.Document REFS Document.PaymentReceipt
	|						THEN CAST(DocumentTable.Document AS Document.PaymentReceipt).Date
	|					WHEN DocumentTable.Document REFS Document.ArApAdjustments
	|						THEN CAST(DocumentTable.Document AS Document.ArApAdjustments).Date
	|				END
	|		ELSE DocumentTable.Ref.Date
	|	END AS DocumentDate,
	|	SUM(CAST(DocumentTable.PaymentAmount * DocumentCurrencyExchangeRateSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * DocumentCurrencyExchangeRateSliceLast.Multiplicity) AS NUMBER(15, 2))) AS Amount,
	|	SUM(DocumentTable.SettlementsAmount) AS AmountCur,
	|	DocumentTable.Ref.SetPaymentTerms AS SetPaymentTerms
	|INTO TemporaryTablePrepayment
	|FROM
	|	Document.SalesInvoice.Prepayment AS DocumentTable
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS AccountingExchangeRatesSliceLast
	|		ON (AccountingExchangeRatesSliceLast.Currency = &PresentationCurrency)
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS DocumentCurrencyExchangeRateSliceLast
	|		ON (DocumentCurrencyExchangeRateSliceLast.Currency = &InvoiceCurrency)
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
	|	CASE
	|		WHEN NOT DocumentTable.Ref.Counterparty.DoOperationsByDocuments
	|				OR VALUETYPE(DocumentTable.Document) = TYPE(Document.ArApAdjustments)
	|			THEN VALUE(Catalog.CashFlowItems.PaymentFromCustomers)
	|		ELSE CASE
	|				WHEN DocumentTable.Document REFS Document.PaymentExpense
	|					THEN CAST(DocumentTable.Document AS Document.PaymentExpense).Item
	|				WHEN DocumentTable.Document REFS Document.CashReceipt
	|					THEN CAST(DocumentTable.Document AS Document.CashReceipt).Item
	|				WHEN DocumentTable.Document REFS Document.CashVoucher
	|					THEN CAST(DocumentTable.Document AS Document.CashVoucher).Item
	|				WHEN DocumentTable.Document REFS Document.PaymentReceipt
	|					THEN CAST(DocumentTable.Document AS Document.PaymentReceipt).Item
	|				ELSE VALUE(Catalog.CashFlowItems.PaymentFromCustomers)
	|			END
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.Counterparty.DoOperationsByDocuments
	|			THEN CASE
	|					WHEN DocumentTable.Document REFS Document.PaymentExpense
	|						THEN CAST(DocumentTable.Document AS Document.PaymentExpense).Date
	|					WHEN DocumentTable.Document REFS Document.CashReceipt
	|						THEN CAST(DocumentTable.Document AS Document.CashReceipt).Date
	|					WHEN DocumentTable.Document REFS Document.CashVoucher
	|						THEN CAST(DocumentTable.Document AS Document.CashVoucher).Date
	|					WHEN DocumentTable.Document REFS Document.PaymentReceipt
	|						THEN CAST(DocumentTable.Document AS Document.PaymentReceipt).Date
	|					WHEN DocumentTable.Document REFS Document.ArApAdjustments
	|						THEN CAST(DocumentTable.Document AS Document.ArApAdjustments).Date
	|				END
	|		ELSE DocumentTable.Ref.Date
	|	END,
	|	DocumentTable.Ref.BasisDocument,
	|	DocumentTable.Ref.Counterparty.DoOperationsByContracts,
	|	DocumentTable.Ref.Counterparty.DoOperationsByDocuments,
	|	DocumentTable.Ref.Counterparty.DoOperationsByOrders,
	|	DocumentTable.Ref.SetPaymentTerms
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SalesInvoiceDiscountsMarkups.ConnectionKey AS ConnectionKey,
	|	SalesInvoiceDiscountsMarkups.DiscountMarkup AS DiscountMarkup,
	|	CAST(CASE
	|			WHEN SalesInvoiceDiscountsMarkups.Ref.DocumentCurrency = ConstantNationalCurrency.Value
	|				THEN SalesInvoiceDiscountsMarkups.Amount * RegExchangeRates.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * RegExchangeRates.Multiplicity)
	|			ELSE SalesInvoiceDiscountsMarkups.Amount * SalesInvoiceDiscountsMarkups.Ref.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * SalesInvoiceDiscountsMarkups.Ref.Multiplicity)
	|		END AS NUMBER(15, 2)) AS Amount,
	|	SalesInvoiceDiscountsMarkups.Ref.Date AS Period,
	|	SalesInvoiceDiscountsMarkups.Ref.StructuralUnit AS StructuralUnit
	|INTO TemporaryTableAutoDiscountsMarkups
	|FROM
	|	Document.SalesInvoice.DiscountsMarkups AS SalesInvoiceDiscountsMarkups
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(
	|				&PointInTime,
	|				Currency IN
	|					(SELECT
	|						ConstantAccountingCurrency.Value
	|					FROM
	|						Constant.PresentationCurrency AS ConstantAccountingCurrency)) AS ManagExchangeRates
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(
	|				&PointInTime,
	|				Currency IN
	|					(SELECT
	|						ConstantNationalCurrency.Value
	|					FROM
	|						Constant.FunctionalCurrency AS ConstantNationalCurrency)) AS RegExchangeRates
	|		ON (TRUE),
	|	Constant.FunctionalCurrency AS ConstantNationalCurrency
	|WHERE
	|	SalesInvoiceDiscountsMarkups.Ref = &Ref
	|	AND SalesInvoiceDiscountsMarkups.Amount <> 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SalesInvoiceSerialNumbers.ConnectionKey AS ConnectionKey,
	|	SalesInvoiceSerialNumbers.SerialNumber AS SerialNumber
	|INTO TemporaryTableSerialNumbers
	|FROM
	|	Document.SalesInvoice.SerialNumbers AS SalesInvoiceSerialNumbers
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
	|	SUM(PrepaymentVAT.AmountExcludesVAT) AS AmountExcludesVAT
	|INTO TemporaryTablePrepaymentVAT
	|FROM
	|	Document.SalesInvoice.PrepaymentVAT AS PrepaymentVAT
	|		INNER JOIN SalesInvoiceHeader AS Header
	|		ON PrepaymentVAT.Ref = Header.Ref
	|WHERE
	|	NOT PrepaymentVAT.VATRate.NotTaxable
	|
	|GROUP BY
	|	Header.Company,
	|	Header.Date,
	|	Header.Counterparty,
	|	PrepaymentVAT.Document,
	|	PrepaymentVAT.VATRate
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Calendar.LineNumber AS LineNumber,
	|	Calendar.PaymentDate AS Period,
	|	&Company AS Company,
	|	Header.Counterparty AS Counterparty,
	|	CounterpartyRef.DoOperationsByContracts AS DoOperationsByContracts,
	|	CounterpartyRef.DoOperationsByDocuments AS DoOperationsByDocuments,
	|	CounterpartyRef.DoOperationsByOrders AS DoOperationsByOrders,
	|	CounterpartyRef.GLAccountCustomerSettlements AS GLAccountCustomerSettlements,
	|	Header.Contract AS Contract,
	|	CounterpartyContractsRef.SettlementsCurrency AS SettlementsCurrency,
	|	&Ref AS DocumentWhere,
	|	VALUE(Enum.SettlementsTypes.Debt) AS SettlemensTypeWhere,
	|	Header.Order AS Order,
	|	CASE
	|		WHEN Header.AmountIncludesVAT
	|			THEN CAST(Calendar.PaymentAmount * Header.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * Header.Multiplicity) AS NUMBER(15, 2))
	|		ELSE CAST((Calendar.PaymentAmount + Calendar.PaymentVATAmount) * Header.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * Header.Multiplicity) AS NUMBER(15, 2))
	|	END AS Amount,
	|	CASE
	|		WHEN Header.AmountIncludesVAT
	|			THEN Calendar.PaymentAmount
	|		ELSE Calendar.PaymentAmount + Calendar.PaymentVATAmount
	|	END AS AmountCur
	|INTO TemporaryTablePaymentCalendarWithoutGroup
	|FROM
	|	SalesInvoiceHeader AS Header
	|		INNER JOIN Document.SalesInvoice.PaymentCalendar AS Calendar
	|		ON Header.Ref = Calendar.Ref
	|		LEFT JOIN Catalog.Counterparties AS CounterpartyRef
	|		ON (CounterpartyRef.Ref = Header.Counterparty)
	|		LEFT JOIN Catalog.CounterpartyContracts AS CounterpartyContractsRef
	|		ON (CounterpartyContractsRef.Ref = Header.Contract)
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
	|	TemporaryTablePaymentCalendarWithoutGroup AS Calendar
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
	|DROP SalesInvoiceHeader";
	
	Query.SetParameter("Ref", DocumentRefSalesInvoice);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("UseCharacteristics", StructureAdditionalProperties.AccountingPolicy.UseCharacteristics);
	Query.SetParameter("UseBatches", StructureAdditionalProperties.AccountingPolicy.UseBatches);
	Query.SetParameter("UseStorageBins", StructureAdditionalProperties.AccountingPolicy.UseStorageBins);
	Query.SetParameter("UseSerialNumbers", StructureAdditionalProperties.AccountingPolicy.UseSerialNumbers);
	
	Query.SetParameter("PresentationCurrency", Constants.PresentationCurrency.Get());
	Query.SetParameter("NationalCurrency", Constants.FunctionalCurrency.Get());
	Query.SetParameter("InvoiceCurrency", DocumentRefSalesInvoice.DocumentCurrency);

	
	Query.ExecuteBatch();
	
	// Creation of document postings.
	DriveServer.GenerateTransactionsTable(DocumentRefSalesInvoice, StructureAdditionalProperties);
	
	PerformanceEstimationClientServer.StartTimeMeasurement("DocumentSalesInvoicePositingGenerateTable");
	
	GenerateTableSales(DocumentRefSalesInvoice, StructureAdditionalProperties);
	GenerateTableProductRelease(DocumentRefSalesInvoice, StructureAdditionalProperties);
	GenerateTableInventoryInWarehouses(DocumentRefSalesInvoice, StructureAdditionalProperties);
	GenerateTableSalesOrders(DocumentRefSalesInvoice, StructureAdditionalProperties);
	GenerateTableWorkOrders(DocumentRefSalesInvoice, StructureAdditionalProperties);
	GenerateTableGoodsShippedNotInvoiced(DocumentRefSalesInvoice, StructureAdditionalProperties);
	GenerateTableGoodsInvoicedNotShipped(DocumentRefSalesInvoice, StructureAdditionalProperties);
	GenerateTableCustomerAccounts(DocumentRefSalesInvoice, StructureAdditionalProperties);
	GenerateTableIncomeAndExpenses(DocumentRefSalesInvoice, StructureAdditionalProperties);
	GenerateTablePaymentCalendar(DocumentRefSalesInvoice, StructureAdditionalProperties);
	
	// DiscountCards
	GenerateTableSalesByDiscountCard(DocumentRefSalesInvoice, StructureAdditionalProperties);
	// AutomaticDiscounts
	GenerateTableSalesByAutomaticDiscountsApplied(DocumentRefSalesInvoice, StructureAdditionalProperties);
	
	PerformanceEstimationClientServer.StartTimeMeasurement("DocumentSalesInvoicePositingGenerateTableInventory");
	
	GenerateTableInventory(DocumentRefSalesInvoice, StructureAdditionalProperties);
	
	PerformanceEstimationClientServer.StartTimeMeasurement("DocumentSalesInvoicePositingGenerateTableIncomeAndExpenses");
	
	GenerateTableIncomeAndExpensesRetained(DocumentRefSalesInvoice, StructureAdditionalProperties);
	GenerateTableUnallocatedExpenses(DocumentRefSalesInvoice, StructureAdditionalProperties);
	GenerateTableIncomeAndExpensesCashMethod(DocumentRefSalesInvoice, StructureAdditionalProperties);
	
	PerformanceEstimationClientServer.StartTimeMeasurement("DocumentSalesInvoicePositingGenerateTableManagement");
	
	GenerateTableAccountingJournalEntries(DocumentRefSalesInvoice, StructureAdditionalProperties);
	
	// Serial numbers
	GenerateTableSerialNumbers(DocumentRefSalesInvoice, StructureAdditionalProperties);
	
	//VAT
	GenerateTableVATOutput(DocumentRefSalesInvoice, StructureAdditionalProperties);
	
EndProcedure

// Controls the occurrence of negative balances.
//
Procedure RunControl(DocumentRefSalesInvoice, AdditionalProperties, Cancel, PostingDelete = False) Export
	
	If Not DriveServer.RunBalanceControl() Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// If temporary tables "RegisterRecordsInventoryChange", "MovementsInventoryInWarehousesChange",
	// "MovementsInventoryPassedChange", "RegisterRecordsStockReceivedFromThirdPartiesChange",
	// "RegisterRecordsBackordersChange", "RegisterRecordsInventoryDemandChange" contain records, it is
	// required to control goods implementation.
	
	If StructureTemporaryTables.RegisterRecordsInventoryChange
		OR StructureTemporaryTables.RegisterRecordsInventoryInWarehousesChange
		OR StructureTemporaryTables.RegisterRecordsSalesOrdersChange 
		OR StructureTemporaryTables.RegisterRecordsAccountsReceivableChange
		OR StructureTemporaryTables.RegisterRecordsGoodsShippedNotInvoicedChange
		OR StructureTemporaryTables.RegisterRecordsGoodsInvoicedNotShippedChange Then
		
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
		|	RegisterRecordsAccountsReceivableChange.LineNumber AS LineNumber,
		|	RegisterRecordsAccountsReceivableChange.Company AS CompanyPresentation,
		|	RegisterRecordsAccountsReceivableChange.Counterparty AS CounterpartyPresentation,
		|	RegisterRecordsAccountsReceivableChange.Contract AS ContractPresentation,
		|	RegisterRecordsAccountsReceivableChange.Contract.SettlementsCurrency AS CurrencyPresentation,
		|	RegisterRecordsAccountsReceivableChange.Document AS DocumentPresentation,
		|	RegisterRecordsAccountsReceivableChange.Order AS OrderPresentation,
		|	RegisterRecordsAccountsReceivableChange.SettlementsType AS CalculationsTypesPresentation,
		|	FALSE AS RegisterRecordsOfCashDocuments,
		|	RegisterRecordsAccountsReceivableChange.SumBeforeWrite AS SumBeforeWrite,
		|	RegisterRecordsAccountsReceivableChange.AmountOnWrite AS AmountOnWrite,
		|	RegisterRecordsAccountsReceivableChange.AmountChange AS AmountChange,
		|	RegisterRecordsAccountsReceivableChange.AmountCurBeforeWrite AS AmountCurBeforeWrite,
		|	RegisterRecordsAccountsReceivableChange.SumCurOnWrite AS SumCurOnWrite,
		|	RegisterRecordsAccountsReceivableChange.SumCurChange AS SumCurChange,
		|	RegisterRecordsAccountsReceivableChange.SumCurOnWrite - ISNULL(AccountsReceivableBalances.AmountCurBalance, 0) AS AdvanceAmountsReceived,
		|	RegisterRecordsAccountsReceivableChange.SumCurChange + ISNULL(AccountsReceivableBalances.AmountCurBalance, 0) AS AmountOfOutstandingDebt,
		|	ISNULL(AccountsReceivableBalances.AmountBalance, 0) AS AmountBalance,
		|	ISNULL(AccountsReceivableBalances.AmountCurBalance, 0) AS AmountCurBalance,
		|	RegisterRecordsAccountsReceivableChange.SettlementsType AS SettlementsType
		|FROM
		|	RegisterRecordsAccountsReceivableChange AS RegisterRecordsAccountsReceivableChange
		|		INNER JOIN AccumulationRegister.AccountsReceivable.Balance(&ControlTime, ) AS AccountsReceivableBalances
		|		ON RegisterRecordsAccountsReceivableChange.Company = AccountsReceivableBalances.Company
		|			AND RegisterRecordsAccountsReceivableChange.Counterparty = AccountsReceivableBalances.Counterparty
		|			AND RegisterRecordsAccountsReceivableChange.Contract = AccountsReceivableBalances.Contract
		|			AND RegisterRecordsAccountsReceivableChange.Document = AccountsReceivableBalances.Document
		|			AND RegisterRecordsAccountsReceivableChange.Order = AccountsReceivableBalances.Order
		|			AND RegisterRecordsAccountsReceivableChange.SettlementsType = AccountsReceivableBalances.SettlementsType
		|			AND (CASE
		|				WHEN RegisterRecordsAccountsReceivableChange.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)
		|					THEN ISNULL(AccountsReceivableBalances.AmountCurBalance, 0) > 0
		|				ELSE ISNULL(AccountsReceivableBalances.AmountCurBalance, 0) < 0
		|			END)
		|
		|ORDER BY
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	RegisterRecordsGoodsShippedNotInvoicedChange.LineNumber AS LineNumber,
		|	RegisterRecordsGoodsShippedNotInvoicedChange.Company AS CompanyPresentation,
		|	RegisterRecordsGoodsShippedNotInvoicedChange.GoodsIssue AS GoodsIssuePresentation,
		|	RegisterRecordsGoodsShippedNotInvoicedChange.Contract AS ContractPresentation,
		|	RegisterRecordsGoodsShippedNotInvoicedChange.Products AS ProductsPresentation,
		|	RegisterRecordsGoodsShippedNotInvoicedChange.Characteristic AS CharacteristicPresentation,
		|	GoodsShippedNotInvoicedBalances.Products.MeasurementUnit AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsGoodsShippedNotInvoicedChange.QuantityChange, 0) + ISNULL(GoodsShippedNotInvoicedBalances.QuantityBalance, 0) AS BalanceGoodsShippedNotInvoiced,
		|	ISNULL(GoodsShippedNotInvoicedBalances.QuantityBalance, 0) AS QuantityBalanceGoodsShippedNotInvoiced
		|FROM
		|	RegisterRecordsGoodsShippedNotInvoicedChange AS RegisterRecordsGoodsShippedNotInvoicedChange
		|		INNER JOIN AccumulationRegister.GoodsShippedNotInvoiced.Balance(&ControlTime, ) AS GoodsShippedNotInvoicedBalances
		|		ON RegisterRecordsGoodsShippedNotInvoicedChange.Company = GoodsShippedNotInvoicedBalances.Company
		|			AND RegisterRecordsGoodsShippedNotInvoicedChange.GoodsIssue = GoodsShippedNotInvoicedBalances.GoodsIssue
		|			AND RegisterRecordsGoodsShippedNotInvoicedChange.Contract = GoodsShippedNotInvoicedBalances.Contract
		|			AND RegisterRecordsGoodsShippedNotInvoicedChange.Products = GoodsShippedNotInvoicedBalances.Products
		|			AND RegisterRecordsGoodsShippedNotInvoicedChange.Characteristic = GoodsShippedNotInvoicedBalances.Characteristic
		|			AND (ISNULL(GoodsShippedNotInvoicedBalances.QuantityBalance, 0) < 0)
		|
		|ORDER BY
		|	LineNumber");
		
		Query.Text = Query.Text + DriveClientServer.GetQueryDelimeter();
		Query.Text = Query.Text + AccumulationRegisters.GoodsInvoicedNotShipped.BalancesControlQueryText();
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.SetParameter("ControlTime", AdditionalProperties.ForPosting.ControlTime);
		
		ResultsArray = Query.ExecuteBatch();
		
		If Not ResultsArray[0].IsEmpty()
			OR Not ResultsArray[1].IsEmpty()
			OR Not ResultsArray[2].IsEmpty()
			OR Not ResultsArray[3].IsEmpty()
			OR Not ResultsArray[4].IsEmpty()
			OR Not ResultsArray[5].IsEmpty() Then
			DocumentObjectSalesInvoice = DocumentRefSalesInvoice.GetObject()
		EndIf;
		
		// Negative balance of inventory in the warehouse.
		If Not ResultsArray[0].IsEmpty() Then
			QueryResultSelection = ResultsArray[0].Select();
			DriveServer.ShowMessageAboutPostingToInventoryInWarehousesRegisterErrors(DocumentObjectSalesInvoice, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance of inventory.
		If Not ResultsArray[1].IsEmpty() Then
			QueryResultSelection = ResultsArray[1].Select();
			DriveServer.ShowMessageAboutPostingToInventoryRegisterErrors(DocumentObjectSalesInvoice, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance on sales order.
		If Not ResultsArray[2].IsEmpty() Then
			QueryResultSelection = ResultsArray[2].Select();
			DriveServer.ShowMessageAboutPostingToSalesOrdersRegisterErrors(DocumentObjectSalesInvoice, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance on accounts receivable.
		If Not ResultsArray[3].IsEmpty() Then
			QueryResultSelection = ResultsArray[3].Select();
			DriveServer.ShowMessageAboutPostingToAccountsReceivableRegisterErrors(DocumentObjectSalesInvoice, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance on goods issued not yet invoiced
		If Not ResultsArray[4].IsEmpty() Then
			QueryResultSelection = ResultsArray[4].Select();
			DriveServer.ShowMessageAboutPostingToGoodsShippedNotInvoicedRegisterErrors(DocumentObjectSalesInvoice, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance on goods invoiced not shipped
		If Not ResultsArray[5].IsEmpty() Then
			QueryResultSelection = ResultsArray[5].Select();
			DriveServer.ShowMessageAboutPostingToGoodsInvoicedNotShippedRegisterErrors(DocumentObjectSalesInvoice, QueryResultSelection, Cancel);
		EndIf;
		
	EndIf;
	
EndProcedure

#Region PrintInterface

Function PrintSalesInvoice(ObjectsArray, PrintObjects, TemplateName)
	
	SpreadsheetDocument = New SpreadsheetDocument;
	SpreadsheetDocument.PrintParametersKey = "PrintParameters_SalesInvoice";
	
	Query = New Query();
	Query.SetParameter("ObjectsArray", ObjectsArray);
	Query.SetParameter("ReverseChargeAppliesRate", NStr("en = 'Reverse charge applies'"));
	
	#Region PrintSalesInvoiceQueryText
	
	Query.Text = 
	"SELECT
	|	SalesInvoice.Ref AS Ref,
	|	SalesInvoice.Number AS Number,
	|	SalesInvoice.Date AS Date,
	|	SalesInvoice.Company AS Company,
	|	SalesInvoice.Counterparty AS Counterparty,
	|	SalesInvoice.Contract AS Contract,
	|	SalesInvoice.ShippingAddress AS ShippingAddress,
	|	SalesInvoice.ContactPerson AS ContactPerson,
	|	SalesInvoice.AmountIncludesVAT AS AmountIncludesVAT,
	|	SalesInvoice.DocumentCurrency AS DocumentCurrency,
	|	CAST(SalesInvoice.Comment AS STRING(1024)) AS Comment,
	|	SalesInvoice.Order AS Order,
	|	SalesInvoice.SalesOrderPosition AS SalesOrderPosition,
	|	SalesInvoice.VATTaxation = VALUE(Enum.VATTaxationTypes.ReverseChargeVAT) AS ReverseCharge,
	|	SalesInvoice.StructuralUnit AS StructuralUnit,
	|	SalesInvoice.DeliveryOption AS DeliveryOption,
	|	SalesInvoice.ProvideEPD AS ProvideEPD
	|INTO SalesInvoices
	|FROM
	|	Document.SalesInvoice AS SalesInvoice
	|WHERE
	|	SalesInvoice.Ref IN(&ObjectsArray)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SalesInvoice.Ref AS Ref,
	|	SalesInvoice.Number AS DocumentNumber,
	|	SalesInvoice.Date AS DocumentDate,
	|	SalesInvoice.Company AS Company,
	|	Companies.LogoFile AS CompanyLogoFile,
	|	SalesInvoice.Counterparty AS Counterparty,
	|	SalesInvoice.Contract AS Contract,
	|	SalesInvoice.ShippingAddress AS ShippingAddress,
	|	CASE
	|		WHEN SalesInvoice.ContactPerson <> VALUE(Catalog.ContactPersons.EmptyRef)
	|			THEN SalesInvoice.ContactPerson
	|		WHEN CounterpartyContracts.ContactPerson <> VALUE(Catalog.ContactPersons.EmptyRef)
	|			THEN CounterpartyContracts.ContactPerson
	|		ELSE Counterparties.ContactPerson
	|	END AS CounterpartyContactPerson,
	|	SalesInvoice.AmountIncludesVAT AS AmountIncludesVAT,
	|	SalesInvoice.DocumentCurrency AS DocumentCurrency,
	|	ISNULL(SalesOrder.Number, """") AS SalesOrderNumber,
	|	ISNULL(SalesOrder.Date, DATETIME(1, 1, 1)) AS SalesOrderDate,
	|	SalesInvoice.Comment AS Comment,
	|	SalesInvoice.ReverseCharge AS ReverseCharge,
	|	SUM(ISNULL(SalesInvoicePrepayment.SettlementsAmount, 0)) AS Paid,
	|	SalesInvoice.StructuralUnit AS StructuralUnit,
	|	SalesInvoice.DeliveryOption AS DeliveryOption,
	|	SalesInvoice.ProvideEPD AS ProvideEPD
	|INTO Header
	|FROM
	|	SalesInvoices AS SalesInvoice
	|		LEFT JOIN Catalog.Companies AS Companies
	|		ON SalesInvoice.Company = Companies.Ref
	|		LEFT JOIN Catalog.Counterparties AS Counterparties
	|		ON SalesInvoice.Counterparty = Counterparties.Ref
	|		LEFT JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
	|		ON SalesInvoice.Contract = CounterpartyContracts.Ref
	|		LEFT JOIN Document.SalesOrder AS SalesOrder
	|		ON SalesInvoice.Order = SalesOrder.Ref
	|			AND (SalesInvoice.SalesOrderPosition = VALUE(Enum.AttributeStationing.InHeader))
	|		LEFT JOIN Document.SalesInvoice.Prepayment AS SalesInvoicePrepayment
	|		ON SalesInvoice.Ref = SalesInvoicePrepayment.Ref
	|
	|GROUP BY
	|	SalesInvoice.Number,
	|	SalesInvoice.Date,
	|	SalesInvoice.Counterparty,
	|	SalesInvoice.Company,
	|	Companies.LogoFile,
	|	SalesInvoice.Ref,
	|	SalesInvoice.Comment,
	|	ISNULL(SalesOrder.Date, DATETIME(1, 1, 1)),
	|	ISNULL(SalesOrder.Number, """"),
	|	SalesInvoice.DocumentCurrency,
	|	SalesInvoice.AmountIncludesVAT,
	|	SalesInvoice.ShippingAddress,
	|	CASE
	|		WHEN SalesInvoice.ContactPerson <> VALUE(Catalog.ContactPersons.EmptyRef)
	|			THEN SalesInvoice.ContactPerson
	|		WHEN CounterpartyContracts.ContactPerson <> VALUE(Catalog.ContactPersons.EmptyRef)
	|			THEN CounterpartyContracts.ContactPerson
	|		ELSE Counterparties.ContactPerson
	|	END,
	|	SalesInvoice.ReverseCharge,
	|	SalesInvoice.Contract,
	|	SalesInvoice.StructuralUnit,
	|	SalesInvoice.DeliveryOption,
	|	SalesInvoice.ProvideEPD
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SalesInvoiceInventory.Ref AS Ref,
	|	SalesInvoiceInventory.LineNumber AS LineNumber,
	|	SalesInvoiceInventory.Products AS Products,
	|	SalesInvoiceInventory.Characteristic AS Characteristic,
	|	SalesInvoiceInventory.Batch AS Batch,
	|	SalesInvoiceInventory.Quantity AS Quantity,
	|	SalesInvoiceInventory.Reserve AS Reserve,
	|	SalesInvoiceInventory.MeasurementUnit AS MeasurementUnit,
	|	SalesInvoiceInventory.Price * (SalesInvoiceInventory.Total - SalesInvoiceInventory.VATAmount) / SalesInvoiceInventory.Amount AS Price,
	|	SalesInvoiceInventory.DiscountMarkupPercent AS DiscountMarkupPercent,
	|	SalesInvoiceInventory.Total - SalesInvoiceInventory.VATAmount AS Amount,
	|	SalesInvoiceInventory.VATRate AS VATRate,
	|	SalesInvoiceInventory.VATAmount AS VATAmount,
	|	SalesInvoiceInventory.Total AS Total,
	|	SalesInvoiceInventory.Order AS Order,
	|	SalesInvoiceInventory.Content AS Content,
	|	SalesInvoiceInventory.AutomaticDiscountsPercent AS AutomaticDiscountsPercent,
	|	SalesInvoiceInventory.AutomaticDiscountAmount AS AutomaticDiscountAmount,
	|	SalesInvoiceInventory.ConnectionKey AS ConnectionKey
	|INTO FilteredInventory
	|FROM
	|	Document.SalesInvoice.Inventory AS SalesInvoiceInventory
	|		INNER JOIN SalesInvoices AS SalesInvoices
	|		ON SalesInvoiceInventory.Ref = SalesInvoices.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Header.Ref AS Ref,
	|	Header.DocumentNumber AS DocumentNumber,
	|	Header.DocumentDate AS DocumentDate,
	|	Header.Company AS Company,
	|	Header.CompanyLogoFile AS CompanyLogoFile,
	|	Header.Counterparty AS Counterparty,
	|	Header.Contract AS Contract,
	|	Header.ShippingAddress AS ShippingAddress,
	|	Header.CounterpartyContactPerson AS CounterpartyContactPerson,
	|	Header.AmountIncludesVAT AS AmountIncludesVAT,
	|	Header.DocumentCurrency AS DocumentCurrency,
	|	Header.Comment AS Comment,
	|	Header.ReverseCharge AS ReverseCharge,
	|	MIN(FilteredInventory.LineNumber) AS LineNumber,
	|	CatalogProducts.SKU AS SKU,
	|	CASE
	|		WHEN (CAST(FilteredInventory.Content AS STRING(1024))) <> """"
	|			THEN CAST(FilteredInventory.Content AS STRING(1024))
	|		WHEN (CAST(CatalogProducts.DescriptionFull AS STRING(1024))) <> """"
	|			THEN CAST(CatalogProducts.DescriptionFull AS STRING(1024))
	|		ELSE CatalogProducts.Description
	|	END AS ProductDescription,
	|	(CAST(FilteredInventory.Content AS STRING(1024))) <> """" AS ContentUsed,
	|	CASE
	|		WHEN CatalogProducts.UseCharacteristics
	|			THEN CatalogCharacteristics.Description
	|		ELSE """"
	|	END AS CharacteristicDescription,
	|	CASE
	|		WHEN CatalogProducts.UseBatches
	|			THEN CatalogBatches.Description
	|		ELSE """"
	|	END AS BatchDescription,
	|	CatalogProducts.UseSerialNumbers AS UseSerialNumbers,
	|	MIN(FilteredInventory.ConnectionKey) AS ConnectionKey,
	|	ISNULL(CatalogUOM.Description, CatalogUOMClassifier.Description) AS UOM,
	|	SUM(FilteredInventory.Quantity) AS Quantity,
	|	FilteredInventory.Price AS Price,
	|	FilteredInventory.DiscountMarkupPercent AS DiscountRate,
	|	SUM(FilteredInventory.AutomaticDiscountAmount) AS AutomaticDiscountAmount,
	|	SUM(FilteredInventory.Amount) AS Amount,
	|	FilteredInventory.Price * SUM(CASE
	|			WHEN CatalogProducts.IsFreightService
	|				THEN FilteredInventory.Quantity
	|			ELSE 0
	|		END) AS Freight,
	|	FilteredInventory.VATRate AS VATRate,
	|	SUM(FilteredInventory.VATAmount) AS VATAmount,
	|	SUM(FilteredInventory.Total) AS Total,
	|	FilteredInventory.Price * SUM(CASE
	|			WHEN CatalogProducts.IsFreightService
	|				THEN 0
	|			ELSE FilteredInventory.Quantity
	|		END) AS Subtotal,
	|	ISNULL(SalesOrder.Number, Header.SalesOrderNumber) AS SalesOrderNumber,
	|	ISNULL(SalesOrder.Date, Header.SalesOrderDate) AS SalesOrderDate,
	|	FilteredInventory.Products AS Products,
	|	FilteredInventory.Characteristic AS Characteristic,
	|	FilteredInventory.MeasurementUnit AS MeasurementUnit,
	|	FilteredInventory.Batch AS Batch,
	|	MAX(Header.Paid) AS Paid,
	|	Header.StructuralUnit AS StructuralUnit,
	|	Header.DeliveryOption AS DeliveryOption,
	|	CatalogProducts.IsFreightService AS IsFreightService,
	|	Header.ProvideEPD AS ProvideEPD
	|INTO Tabular
	|FROM
	|	Header AS Header
	|		INNER JOIN FilteredInventory AS FilteredInventory
	|		ON Header.Ref = FilteredInventory.Ref
	|		LEFT JOIN Catalog.Products AS CatalogProducts
	|		ON (FilteredInventory.Products = CatalogProducts.Ref)
	|		LEFT JOIN Catalog.ProductsCharacteristics AS CatalogCharacteristics
	|		ON (FilteredInventory.Characteristic = CatalogCharacteristics.Ref)
	|		LEFT JOIN Catalog.ProductsBatches AS CatalogBatches
	|		ON (FilteredInventory.Batch = CatalogBatches.Ref)
	|		LEFT JOIN Catalog.UOM AS CatalogUOM
	|		ON (FilteredInventory.MeasurementUnit = CatalogUOM.Ref)
	|		LEFT JOIN Catalog.UOMClassifier AS CatalogUOMClassifier
	|		ON (FilteredInventory.MeasurementUnit = CatalogUOMClassifier.Ref)
	|		LEFT JOIN Document.SalesOrder AS SalesOrder
	|		ON (FilteredInventory.Order = SalesOrder.Ref)
	|			AND (Header.SalesOrderNumber = """")
	|
	|GROUP BY
	|	Header.DocumentNumber,
	|	Header.DocumentDate,
	|	Header.Company,
	|	Header.Ref,
	|	Header.Counterparty,
	|	Header.CompanyLogoFile,
	|	Header.Contract,
	|	Header.ShippingAddress,
	|	Header.CounterpartyContactPerson,
	|	Header.AmountIncludesVAT,
	|	Header.DocumentCurrency,
	|	Header.Comment,
	|	Header.ReverseCharge,
	|	CatalogProducts.SKU,
	|	CASE
	|		WHEN (CAST(FilteredInventory.Content AS STRING(1024))) <> """"
	|			THEN CAST(FilteredInventory.Content AS STRING(1024))
	|		WHEN (CAST(CatalogProducts.DescriptionFull AS STRING(1024))) <> """"
	|			THEN CAST(CatalogProducts.DescriptionFull AS STRING(1024))
	|		ELSE CatalogProducts.Description
	|	END,
	|	ISNULL(SalesOrder.Date, Header.SalesOrderDate),
	|	CASE
	|		WHEN CatalogProducts.UseCharacteristics
	|			THEN CatalogCharacteristics.Description
	|		ELSE """"
	|	END,
	|	ISNULL(SalesOrder.Number, Header.SalesOrderNumber),
	|	CatalogProducts.UseSerialNumbers,
	|	FilteredInventory.VATRate,
	|	ISNULL(CatalogUOM.Description, CatalogUOMClassifier.Description),
	|	FilteredInventory.Products,
	|	CASE
	|		WHEN CatalogProducts.UseBatches
	|			THEN CatalogBatches.Description
	|		ELSE """"
	|	END,
	|	(CAST(FilteredInventory.Content AS STRING(1024))) <> """",
	|	FilteredInventory.Price,
	|	FilteredInventory.DiscountMarkupPercent,
	|	FilteredInventory.Characteristic,
	|	FilteredInventory.MeasurementUnit,
	|	FilteredInventory.Batch,
	|	Header.StructuralUnit,
	|	Header.DeliveryOption,
	|	CatalogProducts.IsFreightService,
	|	Header.ProvideEPD
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	FilteredInventory.Ref AS Ref,
	|	SUM(FilteredInventory.Total) AS TotalForCount
	|INTO TotalTable
	|FROM
	|	FilteredInventory AS FilteredInventory
	|
	|GROUP BY
	|	FilteredInventory.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Tabular.Ref AS Ref,
	|	Tabular.DocumentNumber AS DocumentNumber,
	|	Tabular.DocumentDate AS DocumentDate,
	|	Tabular.Company AS Company,
	|	Tabular.CompanyLogoFile AS CompanyLogoFile,
	|	Tabular.Counterparty AS Counterparty,
	|	Tabular.Contract AS Contract,
	|	Tabular.ShippingAddress AS ShippingAddress,
	|	Tabular.CounterpartyContactPerson AS CounterpartyContactPerson,
	|	Tabular.AmountIncludesVAT AS AmountIncludesVAT,
	|	Tabular.DocumentCurrency AS DocumentCurrency,
	|	Tabular.Comment AS Comment,
	|	Tabular.LineNumber AS LineNumber,
	|	Tabular.SKU AS SKU,
	|	Tabular.ProductDescription AS ProductDescription,
	|	Tabular.ContentUsed AS ContentUsed,
	|	Tabular.UseSerialNumbers AS UseSerialNumbers,
	|	Tabular.Quantity AS Quantity,
	|	Tabular.Price AS Price,
	|	Tabular.Amount AS Amount,
	|	Tabular.Freight AS FreightTotal,
	|	Tabular.VATRate AS VATRate,
	|	Tabular.VATAmount AS VATAmount,
	|	Tabular.Total AS Total,
	|	Tabular.Subtotal AS Subtotal,
	|	CAST(Tabular.Quantity * Tabular.Price - Tabular.Amount AS NUMBER(15, 2)) AS DiscountAmount,
	|	CASE
	|		WHEN Tabular.AutomaticDiscountAmount = 0
	|			THEN Tabular.DiscountRate
	|		WHEN Tabular.Subtotal = 0
	|			THEN 0
	|		ELSE CAST((Tabular.Subtotal - Tabular.Amount) / Tabular.Subtotal * 100 AS NUMBER(15, 2))
	|	END AS DiscountRate,
	|	Tabular.Products AS Products,
	|	Tabular.CharacteristicDescription AS CharacteristicDescription,
	|	Tabular.BatchDescription AS BatchDescription,
	|	Tabular.ConnectionKey AS ConnectionKey,
	|	Tabular.Characteristic AS Characteristic,
	|	Tabular.MeasurementUnit AS MeasurementUnit,
	|	Tabular.Batch AS Batch,
	|	Tabular.UOM AS UOM,
	|	Tabular.Paid AS Paid,
	|	TotalTable.TotalForCount - Tabular.Paid AS TotalDue,
	|	Tabular.StructuralUnit AS StructuralUnit,
	|	Tabular.DeliveryOption AS DeliveryOption,
	|	Tabular.ProvideEPD AS ProvideEPD
	|FROM
	|	Tabular AS Tabular
	|		LEFT JOIN TotalTable AS TotalTable
	|		ON Tabular.Ref = TotalTable.Ref
	|
	|ORDER BY
	|	Tabular.DocumentNumber,
	|	LineNumber
	|TOTALS
	|	MAX(DocumentNumber),
	|	MAX(DocumentDate),
	|	MAX(Company),
	|	MAX(CompanyLogoFile),
	|	MAX(Counterparty),
	|	MAX(Contract),
	|	MAX(ShippingAddress),
	|	MAX(CounterpartyContactPerson),
	|	MAX(AmountIncludesVAT),
	|	MAX(DocumentCurrency),
	|	MAX(Comment),
	|	COUNT(LineNumber),
	|	SUM(Quantity),
	|	SUM(FreightTotal),
	|	SUM(VATAmount),
	|	SUM(Total),
	|	SUM(Subtotal),
	|	SUM(DiscountAmount),
	|	MAX(Paid),
	|	MAX(TotalDue),
	|	MAX(StructuralUnit),
	|	MAX(DeliveryOption),
	|	MAX(ProvideEPD)
	|BY
	|	Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	Tabular.Ref AS Ref,
	|	Tabular.SalesOrderNumber AS Number,
	|	Tabular.SalesOrderDate AS Date
	|FROM
	|	Tabular AS Tabular
	|WHERE
	|	Tabular.SalesOrderNumber <> """"
	|
	|ORDER BY
	|	Tabular.SalesOrderNumber
	|TOTALS BY
	|	Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Tabular.Ref AS Ref,
	|	CASE
	|		WHEN Tabular.ReverseCharge
	|				AND Tabular.VATRate = VALUE(Catalog.VATRates.ZeroRate)
	|			THEN &ReverseChargeAppliesRate
	|		ELSE Tabular.VATRate
	|	END AS VATRate,
	|	SUM(Tabular.Amount) AS Amount,
	|	SUM(Tabular.VATAmount) AS VATAmount
	|FROM
	|	Tabular AS Tabular
	|
	|GROUP BY
	|	Tabular.Ref,
	|	CASE
	|		WHEN Tabular.ReverseCharge
	|				AND Tabular.VATRate = VALUE(Catalog.VATRates.ZeroRate)
	|			THEN &ReverseChargeAppliesRate
	|		ELSE Tabular.VATRate
	|	END
	|TOTALS BY
	|	Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Tabular.ConnectionKey AS ConnectionKey,
	|	Tabular.Ref AS Ref,
	|	SerialNumbers.Description AS SerialNumber
	|FROM
	|	FilteredInventory AS FilteredInventory
	|		INNER JOIN Tabular AS Tabular
	|		ON FilteredInventory.Products = Tabular.Products
	|			AND FilteredInventory.DiscountMarkupPercent = Tabular.DiscountRate
	|			AND FilteredInventory.Price = Tabular.Price
	|			AND FilteredInventory.VATRate = Tabular.VATRate
	|			AND (NOT Tabular.ContentUsed)
	|			AND FilteredInventory.Ref = Tabular.Ref
	|			AND FilteredInventory.Characteristic = Tabular.Characteristic
	|			AND FilteredInventory.MeasurementUnit = Tabular.MeasurementUnit
	|			AND FilteredInventory.Batch = Tabular.Batch
	|		INNER JOIN Document.SalesInvoice.SerialNumbers AS SalesInvoiceSerialNumbers
	|			LEFT JOIN Catalog.SerialNumbers AS SerialNumbers
	|			ON SalesInvoiceSerialNumbers.SerialNumber = SerialNumbers.Ref
	|		ON (SalesInvoiceSerialNumbers.ConnectionKey = FilteredInventory.ConnectionKey)
	|			AND FilteredInventory.Ref = SalesInvoiceSerialNumbers.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	COUNT(Tabular.LineNumber) AS LineNumber,
	|	Tabular.Ref AS Ref,
	|	SUM(Tabular.Quantity) AS Quantity
	|FROM
	|	Tabular AS Tabular
	|WHERE
	|	NOT Tabular.IsFreightService
	|
	|GROUP BY
	|	Tabular.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MAX(SalesInvoiceEarlyPaymentDiscounts.Period) AS Period,
	|	MAX(SalesInvoiceEarlyPaymentDiscounts.Discount) AS Discount,
	|	MAX(SalesInvoiceEarlyPaymentDiscounts.DiscountAmount) AS DiscountAmount,
	|	SalesInvoiceEarlyPaymentDiscounts.DueDate AS DueDate,
	|	SalesInvoiceEarlyPaymentDiscounts.Ref AS Ref
	|FROM
	|	Document.SalesInvoice.EarlyPaymentDiscounts AS SalesInvoiceEarlyPaymentDiscounts
	|		INNER JOIN Tabular AS Tabular
	|		ON SalesInvoiceEarlyPaymentDiscounts.Ref = Tabular.Ref
	|
	|GROUP BY
	|	SalesInvoiceEarlyPaymentDiscounts.DueDate,
	|	SalesInvoiceEarlyPaymentDiscounts.Ref
	|
	|ORDER BY
	|	DueDate
	|TOTALS BY
	|	Ref";
	
	#EndRegion
	
	ResultArray = Query.ExecuteBatch();
	
	FirstDocument = True;
	
	Header						= ResultArray[5].Select(QueryResultIteration.ByGroupsWithHierarchy);
	SalesOrdersNumbersHeaderSel	= ResultArray[6].Select(QueryResultIteration.ByGroupsWithHierarchy);
	TaxesHeaderSel				= ResultArray[7].Select(QueryResultIteration.ByGroupsWithHierarchy);
	SerialNumbersSel			= ResultArray[8].Select();
	TotalLineNumber				= ResultArray[9].Unload();
	EarlyPaymentDiscountSel		= ResultArray[10].Select(QueryResultIteration.ByGroupsWithHierarchy);
	
	While Header.Next() Do
		
		If Not FirstDocument Then
			SpreadsheetDocument.PutHorizontalPageBreak();
		EndIf;
		FirstDocument = False;
		
		FirstLineNumber = SpreadsheetDocument.TableHeight + 1;
		
		SpreadsheetDocument.PrintParametersName = "PRINT_PARAMETERS_SalesInvoice";
		
		Template = PrintManagement.PrintedFormsTemplate("Document.SalesInvoice.PF_MXL_SalesInvoice");
		
		#Region PrintSalesInvoiceTitleArea
		
		TitleArea = Template.GetArea("Title");
		TitleArea.Parameters.Fill(Header);
		
		If ValueIsFilled(Header.CompanyLogoFile) Then
			
			PictureData = AttachedFiles.GetFileBinaryData(Header.CompanyLogoFile);
			If ValueIsFilled(PictureData) Then
				
				TitleArea.Drawings.Logo.Picture = New Picture(PictureData);
				
			EndIf;
			
		Else
			
			TitleArea.Drawings.Delete(TitleArea.Drawings.Logo);
			
		EndIf;
		
		SpreadsheetDocument.Put(TitleArea);
		
		#EndRegion
		
		#Region PrintSalesInvoiceCompanyInfoArea
		
		CompanyInfoArea = Template.GetArea("CompanyInfo");
		
		InfoAboutCompany = DriveServer.InfoAboutLegalEntityIndividual(Header.Company, Header.DocumentDate, ,);
		CompanyInfoArea.Parameters.Fill(InfoAboutCompany);
		
		SpreadsheetDocument.Put(CompanyInfoArea);
		
		#EndRegion
		
		#Region PrintSalesInvoiceCounterpartyInfoArea
		
		CounterpartyInfoArea = Template.GetArea("CounterpartyInfo");
		CounterpartyInfoArea.Parameters.Fill(Header);
		
		InfoAboutCounterparty = DriveServer.InfoAboutLegalEntityIndividual(Header.Counterparty, Header.DocumentDate, ,);
		CounterpartyInfoArea.Parameters.Fill(InfoAboutCounterparty);
		
		TitleParameters = New Structure;
		TitleParameters.Insert("TitleShipTo", NStr("en = 'Ship to'"));
		TitleParameters.Insert("TitleShipDate", NStr("en = 'Ship date'"));
		
		If Header.DeliveryOption = Enums.DeliveryOptions.SelfPickup Then
			
			InfoAboutPickupLocation	= DriveServer.InfoAboutLegalEntityIndividual(Header.StructuralUnit, Header.DocumentDate);
			ResponsibleEmployee		= InfoAboutPickupLocation.ResponsibleEmployee;
			
			If NOT IsBlankString(InfoAboutPickupLocation.FullDescr) Then
				CounterpartyInfoArea.Parameters.FullDescrShipTo = InfoAboutPickupLocation.FullDescr;
			EndIf;
			
			If NOT IsBlankString(InfoAboutPickupLocation.DeliveryAddress) Then
				CounterpartyInfoArea.Parameters.DeliveryAddress = InfoAboutPickupLocation.DeliveryAddress;
			EndIf;
			
			If ValueIsFilled(ResponsibleEmployee) Then
				CounterpartyInfoArea.Parameters.CounterpartyContactPerson = ResponsibleEmployee.Description;
			EndIf;
			
			If NOT IsBlankString(InfoAboutPickupLocation.PhoneNumbers) Then
				CounterpartyInfoArea.Parameters.PhoneNumbers = InfoAboutPickupLocation.PhoneNumbers;
			EndIf;
			
			TitleParameters.TitleShipTo		= NStr("en = 'Pickup location'");
			TitleParameters.TitleShipDate	= NStr("en = 'Pickup date'");
			
		Else
			
			InfoAboutShippingAddress	= DriveServer.InfoAboutShippingAddress(Header.ShippingAddress);
			InfoAboutContactPerson		= DriveServer.InfoAboutContactPerson(Header.CounterpartyContactPerson);
		
			If NOT IsBlankString(InfoAboutShippingAddress.DeliveryAddress) Then
				CounterpartyInfoArea.Parameters.DeliveryAddress = InfoAboutShippingAddress.DeliveryAddress;
			EndIf;
			
			If NOT IsBlankString(InfoAboutContactPerson.PhoneNumbers) Then
				CounterpartyInfoArea.Parameters.PhoneNumbers = InfoAboutContactPerson.PhoneNumbers;
			EndIf;
			
		EndIf;
		
		CounterpartyInfoArea.Parameters.Fill(TitleParameters);
		
		If IsBlankString(CounterpartyInfoArea.Parameters.DeliveryAddress) Then
			
			If Not IsBlankString(InfoAboutCounterparty.ActualAddress) Then
				
				CounterpartyInfoArea.Parameters.DeliveryAddress = InfoAboutCounterparty.ActualAddress;
				
			Else
				
				CounterpartyInfoArea.Parameters.DeliveryAddress = InfoAboutCounterparty.LegalAddress;
				
			EndIf;
			
		EndIf;
		
		CounterpartyInfoArea.Parameters.PaymentTerms = PaymentTermsServer.TitlePaymentTerms(Header.Ref);
		
		SalesOrdersNumbersHeaderSel.Reset();
		If SalesOrdersNumbersHeaderSel.FindNext(New Structure("Ref", Header.Ref)) Then
			
			SalesOrdersNumbersArray = New Array;
			
			SalesOrdersNumbersSel = SalesOrdersNumbersHeaderSel.Select();
			While SalesOrdersNumbersSel.Next() Do
				
				SalesOrdersNumbersArray.Add(
					SalesOrdersNumbersSel.Number
					+ StringFunctionsClientServer.SubstituteParametersInString(
						" %1 ", NStr("en = 'dated'"))
					+ Format(SalesOrdersNumbersSel.Date, "DLF=D"));
				
			EndDo;
			
			CounterpartyInfoArea.Parameters.SalesOrders = StringFunctionsClientServer.GetStringFromSubstringArray(SalesOrdersNumbersArray, ", ");
			
		EndIf;
		
		SpreadsheetDocument.Put(CounterpartyInfoArea);
		
		#EndRegion
		
		#Region PrintEPDArea
		
		EarlyPaymentDiscountSel.Reset();
		If EarlyPaymentDiscountSel.FindNext(New Structure("Ref", Header.Ref)) Then
			
			EPDArea = Template.GetArea("EPDSection");
			
			EPDArray = New Array;
			
			EPDSel = EarlyPaymentDiscountSel.Select();
			While EPDSel.Next() Do
				
				EPDArray.Add(StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = 'A discount of %1% of the full price applies if payment is made within %2 days of the invoice date. Discounted total %3 %4.'"),
					EPDSel.Discount,
					EPDSel.Period,
					Format(Header.Total - EPDSel.DiscountAmount,"NFD=2"),
					Header.DocumentCurrency));
				
			EndDo;
			
			If Header.ProvideEPD = Enums.VariantsOfProvidingEPD.PaymentDocumentWithVATAdjustment
				OR Header.ProvideEPD = Enums.VariantsOfProvidingEPD.PaymentDocument Then
				
				EPDArray.Add(NStr("en = 'No credit note will be issued.'"));
				
				If Header.ProvideEPD = Enums.VariantsOfProvidingEPD.PaymentDocumentWithVATAdjustment Then
					EPDArray.Add(NStr("en = 'On payment you may only recover the VAT actually paid.'"));
				EndIf;
				
			EndIf;
			
			EPDArea.Parameters.EPD = StringFunctionsClientServer.GetStringFromSubstringArray(EPDArray, " ");
			
			SpreadsheetDocument.Put(EPDArea);
			
		EndIf;
		
		#EndRegion
		
		#Region PrintSalesInvoiceCommentArea
		
		CommentArea = Template.GetArea("Comment");
		CommentArea.Parameters.Fill(Header);
		SpreadsheetDocument.Put(CommentArea);
		
		#EndRegion
		
		#Region PrintSalesInvoiceTotalsAndTaxesAreaPrefill
		
		TotalsAndTaxesAreasArray = New Array;
		
		LineTotalArea = Template.GetArea("LineTotal");
		LineTotalArea.Parameters.Fill(Header);
		
		SearchStructure = New Structure("Ref", Header.Ref);
		
		SearchArray = TotalLineNumber.FindRows(SearchStructure);
		If SearchArray.Count() > 0 Then
			LineTotalArea.Parameters.Quantity	= SearchArray[0].Quantity;
			LineTotalArea.Parameters.LineNumber	= SearchArray[0].LineNumber;
		Else
			LineTotalArea.Parameters.Quantity	= 0;
			LineTotalArea.Parameters.LineNumber	= 0;
		EndIf;
		
		TotalsAndTaxesAreasArray.Add(LineTotalArea);
		
		TaxesHeaderSel.Reset();
		If TaxesHeaderSel.FindNext(New Structure("Ref", Header.Ref)) Then
			
			TaxSectionHeaderArea = Template.GetArea("TaxSectionHeader");
			TotalsAndTaxesAreasArray.Add(TaxSectionHeaderArea);
			
			TaxesSel = TaxesHeaderSel.Select();
			While TaxesSel.Next() Do
				
				TaxSectionLineArea = Template.GetArea("TaxSectionLine");
				TaxSectionLineArea.Parameters.Fill(TaxesSel);
				TotalsAndTaxesAreasArray.Add(TaxSectionLineArea);
				
			EndDo;
			
		EndIf;
		
		#EndRegion
		
		#Region PrintSalesInvoiceLinesArea
		
		LineHeaderArea = Template.GetArea("LineHeader");
		SpreadsheetDocument.Put(LineHeaderArea);
		
		LineSectionArea	= Template.GetArea("LineSection");
		SeeNextPageArea	= Template.GetArea("SeeNextPage");
		EmptyLineArea	= Template.GetArea("EmptyLine");
		PageNumberArea	= Template.GetArea("PageNumber");
		
		PageNumber = 0;
		AreasToBeChecked = New Array;
		
		TabSelection = Header.Select();
		While TabSelection.Next() Do
			
			If TabSelection.FreightTotal <> 0 Then
				Continue;
			EndIf;
			
			LineSectionArea.Parameters.Fill(TabSelection);
			
			PrintManagement.ComplimentProductDescription(LineSectionArea.Parameters.ProductDescription, TabSelection, SerialNumbersSel);
			
			AreasToBeChecked.Add(LineSectionArea);
			For Each Area In TotalsAndTaxesAreasArray Do
				AreasToBeChecked.Add(Area);
			EndDo;
			AreasToBeChecked.Add(PageNumberArea);
			
			If CommonUse.SpreadsheetDocumentFitsPage(SpreadsheetDocument, AreasToBeChecked) Then
				
				SpreadsheetDocument.Put(LineSectionArea);
				
			Else
				
				SpreadsheetDocument.Put(SeeNextPageArea);
				
				AreasToBeChecked.Clear();
				AreasToBeChecked.Add(EmptyLineArea);
				AreasToBeChecked.Add(PageNumberArea);
				
				For i = 1 To 50 Do
					
					If Not CommonUse.SpreadsheetDocumentFitsPage(SpreadsheetDocument, AreasToBeChecked)
						Or i = 50 Then
						
						PageNumber = PageNumber + 1;
						PageNumberArea.Parameters.PageNumber = PageNumber;
						SpreadsheetDocument.Put(PageNumberArea);
						Break;
						
					Else
						
						SpreadsheetDocument.Put(EmptyLineArea);
						
					EndIf;
					
				EndDo;
				
				SpreadsheetDocument.PutHorizontalPageBreak();
				SpreadsheetDocument.Put(TitleArea);
				SpreadsheetDocument.Put(LineHeaderArea);
				SpreadsheetDocument.Put(LineSectionArea);
				
			EndIf;
			
		EndDo;
		
		#EndRegion
		
		#Region PrintSalesInvoiceTotalsAndTaxesArea
		
		For Each Area In TotalsAndTaxesAreasArray Do
			
			SpreadsheetDocument.Put(Area);
			
		EndDo;
		
		AreasToBeChecked.Clear();
		AreasToBeChecked.Add(EmptyLineArea);
		AreasToBeChecked.Add(PageNumberArea);
		
		For i = 1 To 50 Do
			
			If Not CommonUse.SpreadsheetDocumentFitsPage(SpreadsheetDocument, AreasToBeChecked)
				Or i = 50 Then
				
				PageNumber = PageNumber + 1;
				PageNumberArea.Parameters.PageNumber = PageNumber;
				SpreadsheetDocument.Put(PageNumberArea);
				Break;
				
			Else
				
				SpreadsheetDocument.Put(EmptyLineArea);
				
			EndIf;
			
		EndDo;
		
		#EndRegion
		
		PrintManagement.SetDocumentPrintArea(SpreadsheetDocument, FirstLineNumber, PrintObjects, Header.Ref);
		
	EndDo;
	
	SpreadsheetDocument.FitToPage = True;
	
	Return SpreadsheetDocument;
	
EndFunction

Function PrintForm(ObjectsArray, PrintObjects, TemplateName)
	
	If TemplateName = "SalesInvoice" Then
		
		Return PrintSalesInvoice(ObjectsArray, PrintObjects, TemplateName)
		
	EndIf;
	
EndFunction

Procedure Print(ObjectsArray, PrintParameters, PrintFormsCollection, PrintObjects, OutputParameters) Export
	
	If PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "SalesInvoice") Then
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection, "SalesInvoice", "Sales invoice", PrintForm(ObjectsArray, PrintObjects, "SalesInvoice"));
	EndIf;
	
	If PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "DeliveryNote") Then
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection,
															"DeliveryNote",
															"Delivery note",
															DataProcessors.PrintDeliveryNote.PrintForm(ObjectsArray, PrintObjects, "DeliveryNote"));
	EndIf;
	
	If PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "TaxInvoice") Then
		If ObjectsArray.Count() > 0 Then			
			PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection, "TaxInvoice", "Tax invoice", DataProcessors.PrintTaxInvoice.PrintForm(ObjectsArray, PrintObjects, "TaxInvoice"));
		EndIf;
	EndIf;
	
	If PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "Requisition") Then
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection,
															"Requisition",
															NStr("en = 'Requisition'"),
															DataProcessors.PrintRequisition.PrintForm(ObjectsArray, PrintObjects, "Requisition"));
	EndIf;
														
	// parameters of sending printing forms by email
	DriveServer.FillSendingParameters(OutputParameters.SendingParameters, ObjectsArray, PrintFormsCollection);
	
EndProcedure

Procedure AddPrintCommands(PrintCommands) Export
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID							= "SalesInvoice";
	PrintCommand.Presentation				= NStr("en = 'Invoice'");
	PrintCommand.CheckPostingBeforePrint	= False;
	PrintCommand.Order						= 1;
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID							= "DeliveryNote";
	PrintCommand.Presentation				= NStr("en = 'Delivery note'");
	PrintCommand.CheckPostingBeforePrint	= False;
	PrintCommand.Order						= 3;
	
	If GetFunctionalOption("UseVAT") Then
		PrintCommand = PrintCommands.Add();
		PrintCommand.ID							= "TaxInvoice";
		PrintCommand.Presentation				= NStr("en = 'Tax invoice'");
		PrintCommand.CheckPostingBeforePrint	= True;
		PrintCommand.Order						= 4;
	EndIf;
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID							= "Requisition";
	PrintCommand.Presentation				= NStr("en = 'Requisition'");
	PrintCommand.CheckPostingBeforePrint	= False;
	PrintCommand.Order						= 5;
	
EndProcedure

#EndRegion

#Region WorkWithSerialNumbers

// Generates a table of values that contains the data for the SerialNumbersInWarranty information register.
// Tables of values saves into the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableSerialNumbers(DocumentRef, StructureAdditionalProperties)
	
	If DocumentRef.SerialNumbers.Count()=0 Then
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbersBalance", New ValueTable);
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbersInWarranty", New ValueTable);
		Return;
	EndIf;
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	TemporaryTableInventory.Period AS Period,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	VALUE(Enum.SerialNumbersOperations.Expense) AS Operation,
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
	|			AND (NOT TemporaryTableInventory.AdvanceInvoicing)
	|			AND (TemporaryTableInventory.GoodsIssue = VALUE(Document.GoodsIssue.EmptyRef))";
	
	QueryResult = Query.Execute().Unload();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbersInWarranty", QueryResult);
	If StructureAdditionalProperties.AccountingPolicy.SerialNumbersBalance Then
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbersBalance", QueryResult);
	Else
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbersBalance", New ValueTable);
	EndIf; 
	
EndProcedure

#EndRegion

#Region InfobaseUpdate

// Re-generation of "VAT output" register entries
// to fix rounding off errors of amounts being converted
// from document currencty into functional currency
Procedure VATOutputEntriesReGeneration() Export
	
	If Constants.FunctionalCurrency.Get() = Constants.PresentationCurrency.Get() Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT DISTINCT
	|	VATOutput.Recorder AS Ref
	|FROM
	|	AccumulationRegister.VATOutput AS VATOutput
	|WHERE
	|	VATOutput.Recorder REFS Document.SalesInvoice";
	
	Sel = Query.Execute().Select();
	
	BeginTransaction();
	
	While Sel.Next() Do
		
		DocObject = Sel.Ref.GetObject();
		
		DriveServer.InitializeAdditionalPropertiesForPosting(DocObject.Ref, DocObject.AdditionalProperties);
		
		Documents.SalesInvoice.InitializeDocumentData(DocObject.Ref, DocObject.AdditionalProperties);
		
		DriveServer.ReflectVATOutput(DocObject.AdditionalProperties, DocObject.RegisterRecords, False);
		
		DriveServer.WriteRecordSets(DocObject.ThisObject);
		
		DocObject.AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
		
	EndDo;
	
	CommitTransaction();
	
EndProcedure

// Replaces an empty sales order reference with an undefined
//
Procedure ChangeSalesOrderEmptyRefToUndefined() Export
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	SalesInvoice.Ref AS Ref
	|INTO TempSalesInvoice
	|FROM
	|	Document.SalesInvoice AS SalesInvoice
	|WHERE
	|	SalesInvoice.Order = VALUE(Document.SalesOrder.EmptyRef)
	|
	|UNION ALL
	|
	|SELECT
	|	SalesInvoiceInventory.Ref
	|FROM
	|	Document.SalesInvoice.Inventory AS SalesInvoiceInventory
	|WHERE
	|	SalesInvoiceInventory.Order = VALUE(Document.SalesOrder.EmptyRef)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	TempSalesInvoice.Ref AS Ref
	|FROM
	|	TempSalesInvoice AS TempSalesInvoice";
	
	QueryResult = Query.Execute();
	Selection	= QueryResult.Select();
	
	SalesOrderEmptyRef = Documents.SalesOrder.EmptyRef();
	
	While Selection.Next() Do
		
		Try
			
			SalesInvoiceObject = Selection.Ref.GetObject();
			
			If SalesInvoiceObject.Order = SalesOrderEmptyRef Then
				SalesInvoiceObject.Order = Undefined;
			EndIf;
			
			For Each Row In SalesInvoiceObject.Inventory Do
				
				If Row.Order = SalesOrderEmptyRef Then
					Row.Order = Undefined;
				EndIf;
				
			EndDo;
			
			SalesInvoiceObject.Write();
			
		Except
			
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Error on write document %1: %2'"),
				Selection.Ref,
				BriefErrorDescription(ErrorInfo()));
				
			WriteLogEvent(
				NStr("en = 'InfobaseUpdate'", CommonUseClientServer.MainLanguageCode()),
				EventLogLevel.Error,
				Metadata.Documents.SalesInvoice,
				,
				ErrorDescription);
				
		EndTry;
		
	EndDo;
	
EndProcedure

Procedure FillNewGLAccounts() Export
	
	DocumentName = "SalesInvoice";
	
	Tables = New Array();
	TableDecription = New Structure("Name, Conditions", "Inventory", New Array());
	
	GLAccountFields = ChartsOfAccounts.PrimaryChartOfAccounts.GLAccountFields();
	GLAccountFields.Source = "Products.InventoryGLAccount";
	GLAccountFields.Receiver = "InventoryGLAccount";
	TableDecription.Conditions.Add(GLAccountFields);
	
	GLAccountFields = ChartsOfAccounts.PrimaryChartOfAccounts.GLAccountFields();
	GLAccountFields.Source = "Products.BusinessLine.ObsoleteGLAccountDeferredRevenueFromSales";
	GLAccountFields.Receiver = "UnearnedRevenueGLAccount";
	TableDecription.Conditions.Add(GLAccountFields);
	
	GLAccountFields = ChartsOfAccounts.PrimaryChartOfAccounts.GLAccountFields();
	GLAccountFields.Source = "Products.BusinessLine.GLAccountRevenueFromSales";
	GLAccountFields.Receiver = "RevenueGLAccount";
	TableDecription.Conditions.Add(GLAccountFields);
	
	GLAccountFields = ChartsOfAccounts.PrimaryChartOfAccounts.GLAccountFields();
	GLAccountFields.Source = "Products.BusinessLine.GLAccountCostOfSales";
	GLAccountFields.Receiver = "COGSGLAccount";
	TableDecription.Conditions.Add(GLAccountFields);
	
	GLAccountFields = ChartsOfAccounts.PrimaryChartOfAccounts.GLAccountFields();
	GLAccountFields.Source = "&VATOutputGLAccount";
	GLAccountFields.Receiver = "VATOutputGLAccount";
	GLAccountFields.Parameter = Catalogs.DefaultGLAccounts.GetDefaultGLAccount("VATOutput");
	TableDecription.Conditions.Add(GLAccountFields);
	
	GLAccountFields = ChartsOfAccounts.PrimaryChartOfAccounts.GLAccountFields();
	GLAccountFields.Source = "&GoodsShippedNotInvoiced";
	GLAccountFields.Receiver = "GoodsShippedNotInvoicedGLAccount";
	GLAccountFields.Parameter = Catalogs.DefaultGLAccounts.GetDefaultGLAccount("GoodsShippedNotInvoiced");
	TableDecription.Conditions.Add(GLAccountFields);
	
	GLAccountFields = ChartsOfAccounts.PrimaryChartOfAccounts.GLAccountFields();
	GLAccountFields.Source = "Products.InventoryGLAccount";
	GLAccountFields.Receiver = "InventoryReceivedGLAccount";
	TableDecription.Conditions.Add(GLAccountFields);
	
	Tables.Add(TableDecription);
	
	ChartsOfAccounts.PrimaryChartOfAccounts.FillNewGLAccounts(DocumentName, Tables);
	
EndProcedure

#EndRegion

#EndIf