#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ProgramInterface

Procedure FillBySalesOrders(DocumentData, FilterData, Products) Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	SalesOrder.Ref AS Ref,
	|	SalesOrder.Contract AS Contract,
	|	SalesOrder.PointInTime AS PointInTime
	|INTO TT_SalesOrders
	|FROM
	|	Document.SalesOrder AS SalesOrder
	|WHERE
	|	&SalesOrdersConditions
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	GoodsIssueProducts.Order AS Order,
	|	GoodsIssueProducts.Products AS Products,
	|	GoodsIssueProducts.Characteristic AS Characteristic,
	|	GoodsIssueProducts.Batch AS Batch,
	|	SUM(GoodsIssueProducts.Quantity * ISNULL(UOM.Factor, 1)) AS BaseQuantity
	|INTO TT_AlreadyShipped
	|FROM
	|	Document.GoodsIssue.Products AS GoodsIssueProducts
	|		INNER JOIN TT_SalesOrders AS TT_SalesOrders
	|		ON GoodsIssueProducts.Order = TT_SalesOrders.Ref
	|		INNER JOIN Document.GoodsIssue AS GoodsIssueDocument
	|		ON GoodsIssueProducts.Ref = GoodsIssueDocument.Ref
	|		INNER JOIN Catalog.Products AS ProductsCatalog
	|		ON GoodsIssueProducts.Products = ProductsCatalog.Ref
	|		LEFT JOIN Catalog.UOM AS UOM
	|		ON GoodsIssueProducts.MeasurementUnit = UOM.Ref
	|WHERE
	|	GoodsIssueDocument.Posted
	|	AND GoodsIssueProducts.Ref <> &Ref
	|	AND ProductsCatalog.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
	|
	|GROUP BY
	|	GoodsIssueProducts.Batch,
	|	GoodsIssueProducts.Order,
	|	GoodsIssueProducts.Products,
	|	GoodsIssueProducts.Characteristic
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
	|WHERE
	|	ProductsCatalog.ProductsType IN (VALUE(Enum.ProductsTypes.InventoryItem), VALUE(Enum.ProductsTypes.Service))
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
	|	TT_SalesOrders.PointInTime AS PointInTime,
	|	TT_SalesOrders.Contract AS Contract
	|INTO TT_Products
	|FROM
	|	Document.SalesOrder.Inventory AS SalesOrderInventory
	|		INNER JOIN TT_SalesOrders AS TT_SalesOrders
	|		ON SalesOrderInventory.Ref = TT_SalesOrders.Ref
	|		INNER JOIN Catalog.Products AS ProductsCatalog
	|		ON SalesOrderInventory.Products = ProductsCatalog.Ref
	|		LEFT JOIN Catalog.UOM AS UOM
	|		ON SalesOrderInventory.MeasurementUnit = UOM.Ref
	|WHERE
	|	ProductsCatalog.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_Products.LineNumber AS LineNumber,
	|	TT_Products.Products AS Products,
	|	TT_Products.Characteristic AS Characteristic,
	|	TT_Products.Batch AS Batch,
	|	TT_Products.Order AS Order,
	|	TT_Products.Factor AS Factor,
	|	TT_Products.Quantity * TT_Products.Factor AS BaseQuantity,
	|	SUM(TT_ProductsCumulative.Quantity * TT_ProductsCumulative.Factor) AS BaseQuantityCumulative
	|INTO TT_ProductsCumulative
	|FROM
	|	TT_Products AS TT_Products
	|		INNER JOIN TT_Products AS TT_ProductsCumulative
	|		ON TT_Products.Products = TT_ProductsCumulative.Products
	|			AND TT_Products.Characteristic = TT_ProductsCumulative.Characteristic
	|			AND TT_Products.Batch = TT_ProductsCumulative.Batch
	|			AND TT_Products.Order = TT_ProductsCumulative.Order
	|			AND TT_Products.LineNumber >= TT_ProductsCumulative.LineNumber
	|
	|GROUP BY
	|	TT_Products.LineNumber,
	|	TT_Products.Products,
	|	TT_Products.Characteristic,
	|	TT_Products.Batch,
	|	TT_Products.Order,
	|	TT_Products.Factor,
	|	TT_Products.Quantity * TT_Products.Factor
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_ProductsCumulative.LineNumber AS LineNumber,
	|	TT_ProductsCumulative.Products AS Products,
	|	TT_ProductsCumulative.Characteristic AS Characteristic,
	|	TT_ProductsCumulative.Batch AS Batch,
	|	TT_ProductsCumulative.Order AS Order,
	|	TT_ProductsCumulative.Factor AS Factor,
	|	CASE
	|		WHEN TT_AlreadyShipped.BaseQuantity > TT_ProductsCumulative.BaseQuantityCumulative - TT_ProductsCumulative.BaseQuantity
	|			THEN TT_ProductsCumulative.BaseQuantityCumulative - TT_AlreadyShipped.BaseQuantity
	|		ELSE TT_ProductsCumulative.BaseQuantity
	|	END AS BaseQuantity
	|INTO TT_ProductsNotYetShipped
	|FROM
	|	TT_ProductsCumulative AS TT_ProductsCumulative
	|		LEFT JOIN TT_AlreadyShipped AS TT_AlreadyShipped
	|		ON TT_ProductsCumulative.Products = TT_AlreadyShipped.Products
	|			AND TT_ProductsCumulative.Characteristic = TT_AlreadyShipped.Characteristic
	|			AND TT_ProductsCumulative.Batch = TT_AlreadyShipped.Batch
	|			AND TT_ProductsCumulative.Order = TT_AlreadyShipped.Order
	|WHERE
	|	ISNULL(TT_AlreadyShipped.BaseQuantity, 0) < TT_ProductsCumulative.BaseQuantityCumulative
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_ProductsNotYetShipped.LineNumber AS LineNumber,
	|	TT_ProductsNotYetShipped.Products AS Products,
	|	TT_ProductsNotYetShipped.Characteristic AS Characteristic,
	|	TT_ProductsNotYetShipped.Batch AS Batch,
	|	TT_ProductsNotYetShipped.Order AS Order,
	|	TT_ProductsNotYetShipped.Factor AS Factor,
	|	TT_ProductsNotYetShipped.BaseQuantity AS BaseQuantity,
	|	SUM(TT_ProductsNotYetShippedCumulative.BaseQuantity) AS BaseQuantityCumulative
	|INTO TT_ProductsNotYetShippedCumulative
	|FROM
	|	TT_ProductsNotYetShipped AS TT_ProductsNotYetShipped
	|		INNER JOIN TT_ProductsNotYetShipped AS TT_ProductsNotYetShippedCumulative
	|		ON TT_ProductsNotYetShipped.Products = TT_ProductsNotYetShippedCumulative.Products
	|			AND TT_ProductsNotYetShipped.Characteristic = TT_ProductsNotYetShippedCumulative.Characteristic
	|			AND TT_ProductsNotYetShipped.Batch = TT_ProductsNotYetShippedCumulative.Batch
	|			AND TT_ProductsNotYetShipped.Order = TT_ProductsNotYetShippedCumulative.Order
	|			AND TT_ProductsNotYetShipped.LineNumber >= TT_ProductsNotYetShippedCumulative.LineNumber
	|
	|GROUP BY
	|	TT_ProductsNotYetShipped.LineNumber,
	|	TT_ProductsNotYetShipped.Products,
	|	TT_ProductsNotYetShipped.Characteristic,
	|	TT_ProductsNotYetShipped.Batch,
	|	TT_ProductsNotYetShipped.Order,
	|	TT_ProductsNotYetShipped.Factor,
	|	TT_ProductsNotYetShipped.BaseQuantity
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_ProductsNotYetShippedCumulative.LineNumber AS LineNumber,
	|	TT_ProductsNotYetShippedCumulative.Products AS Products,
	|	TT_ProductsNotYetShippedCumulative.Characteristic AS Characteristic,
	|	TT_ProductsNotYetShippedCumulative.Batch AS Batch,
	|	TT_ProductsNotYetShippedCumulative.Order AS Order,
	|	TT_ProductsNotYetShippedCumulative.Factor AS Factor,
	|	CASE
	|		WHEN TT_OrdersBalances.QuantityBalance > TT_ProductsNotYetShippedCumulative.BaseQuantityCumulative
	|			THEN TT_ProductsNotYetShippedCumulative.BaseQuantity
	|		WHEN TT_OrdersBalances.QuantityBalance > TT_ProductsNotYetShippedCumulative.BaseQuantityCumulative - TT_ProductsNotYetShippedCumulative.BaseQuantity
	|			THEN TT_OrdersBalances.QuantityBalance - (TT_ProductsNotYetShippedCumulative.BaseQuantityCumulative - TT_ProductsNotYetShippedCumulative.BaseQuantity)
	|	END AS BaseQuantity
	|INTO TT_ProductsToBeShipped
	|FROM
	|	TT_ProductsNotYetShippedCumulative AS TT_ProductsNotYetShippedCumulative
	|		INNER JOIN TT_OrdersBalances AS TT_OrdersBalances
	|		ON TT_ProductsNotYetShippedCumulative.Products = TT_OrdersBalances.Products
	|			AND TT_ProductsNotYetShippedCumulative.Characteristic = TT_OrdersBalances.Characteristic
	|			AND TT_ProductsNotYetShippedCumulative.Order = TT_OrdersBalances.SalesOrder
	|WHERE
	|	TT_OrdersBalances.QuantityBalance > TT_ProductsNotYetShippedCumulative.BaseQuantityCumulative - TT_ProductsNotYetShippedCumulative.BaseQuantity
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_Products.LineNumber AS LineNumber,
	|	TT_Products.Products AS Products,
	|	TT_Products.Characteristic AS Characteristic,
	|	TT_Products.Batch AS Batch,
	|	CASE
	|		WHEN (CAST(TT_Products.Quantity * TT_Products.Factor AS NUMBER(15, 3))) = TT_ProductsToBeShipped.BaseQuantity
	|			THEN TT_Products.Quantity
	|		ELSE CAST(TT_ProductsToBeShipped.BaseQuantity / TT_Products.Factor AS NUMBER(15, 3))
	|	END AS Quantity,
	|	TT_Products.MeasurementUnit AS MeasurementUnit,
	|	TT_Products.Factor AS Factor,
	|	TT_Products.Order AS Order,
	|	VALUE(Document.GoodsIssue.EmptyRef) AS GoodsIssue,
	|	TT_Products.SerialNumbers AS SerialNumbers,
	|	TT_Products.PointInTime AS PointInTime,
	|	TT_Products.Contract AS Contract
	|FROM
	|	TT_Products AS TT_Products
	|		INNER JOIN TT_ProductsToBeShipped AS TT_ProductsToBeShipped
	|		ON TT_Products.LineNumber = TT_ProductsToBeShipped.LineNumber
	|			AND TT_Products.Order = TT_ProductsToBeShipped.Order
	|
	|ORDER BY
	|	PointInTime,
	|	LineNumber";
	
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
	
	Products.Load(Query.Execute().Unload());
	
EndProcedure

Procedure FillBySalesInvoices(DocumentData, FilterData, Products) Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	SalesInvoice.Ref AS Ref,
	|	SalesInvoice.Contract AS Contract,
	|	SalesInvoice.PointInTime AS PointInTime
	|INTO TT_SalesInvoices
	|FROM
	|	Document.SalesInvoice AS SalesInvoice
	|WHERE
	|	&SalesInvoicesConditions
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	GoodsIssueProducts.SalesInvoice AS SalesInvoice,
	|	GoodsIssueProducts.Order AS Order,
	|	GoodsIssueProducts.Products AS Products,
	|	GoodsIssueProducts.Characteristic AS Characteristic,
	|	GoodsIssueProducts.Batch AS Batch,
	|	SUM(GoodsIssueProducts.Quantity * ISNULL(UOM.Factor, 1)) AS BaseQuantity
	|INTO TT_AlreadyShipped
	|FROM
	|	TT_SalesInvoices AS TT_SalesInvoices
	|		INNER JOIN Document.GoodsIssue.Products AS GoodsIssueProducts
	|		ON TT_SalesInvoices.Ref = GoodsIssueProducts.SalesInvoice
	|		INNER JOIN Document.GoodsIssue AS GoodsIssueDocument
	|		ON (GoodsIssueProducts.Ref = GoodsIssueDocument.Ref)
	|		INNER JOIN Catalog.Products AS ProductsCatalog
	|		ON (GoodsIssueProducts.Products = ProductsCatalog.Ref)
	|		LEFT JOIN Catalog.UOM AS UOM
	|		ON (GoodsIssueProducts.MeasurementUnit = UOM.Ref)
	|WHERE
	|	GoodsIssueDocument.Posted
	|	AND GoodsIssueProducts.Ref <> &Ref
	|	AND ProductsCatalog.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
	|
	|GROUP BY
	|	GoodsIssueProducts.SalesInvoice,
	|	GoodsIssueProducts.Order,
	|	GoodsIssueProducts.Products,
	|	GoodsIssueProducts.Characteristic,
	|	GoodsIssueProducts.Batch
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	InvoicedBalance.SalesInvoice AS SalesInvoice,
	|	InvoicedBalance.Order AS Order,
	|	InvoicedBalance.Products AS Products,
	|	InvoicedBalance.Characteristic AS Characteristic,
	|	SUM(InvoicedBalance.QuantityBalance) AS QuantityBalance
	|INTO TT_InvoicedBalances
	|FROM
	|	(SELECT
	|		InvoicedBalance.SalesInvoice AS SalesInvoice,
	|		InvoicedBalance.SalesOrder AS Order,
	|		InvoicedBalance.Products AS Products,
	|		InvoicedBalance.Characteristic AS Characteristic,
	|		InvoicedBalance.QuantityBalance AS QuantityBalance
	|	FROM
	|		AccumulationRegister.GoodsInvoicedNotShipped.Balance(
	|				,
	|				SalesInvoice IN
	|					(SELECT
	|						TT_SalesInvoices.Ref
	|					FROM
	|						TT_SalesInvoices)) AS InvoicedBalance
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecords.SalesInvoice,
	|		DocumentRegisterRecords.SalesOrder,
	|		DocumentRegisterRecords.Products,
	|		DocumentRegisterRecords.Characteristic,
	|		CASE
	|			WHEN DocumentRegisterRecords.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN ISNULL(DocumentRegisterRecords.Quantity, 0)
	|			ELSE -ISNULL(DocumentRegisterRecords.Quantity, 0)
	|		END
	|	FROM
	|		AccumulationRegister.GoodsInvoicedNotShipped AS DocumentRegisterRecords
	|	WHERE
	|		DocumentRegisterRecords.Recorder = &Ref) AS InvoicedBalance
	|
	|GROUP BY
	|	InvoicedBalance.SalesInvoice,
	|	InvoicedBalance.Order,
	|	InvoicedBalance.Products,
	|	InvoicedBalance.Characteristic
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SalesInvoiceInventory.LineNumber AS LineNumber,
	|	SalesInvoiceInventory.Products AS Products,
	|	SalesInvoiceInventory.Characteristic AS Characteristic,
	|	SalesInvoiceInventory.Batch AS Batch,
	|	SalesInvoiceInventory.Quantity AS Quantity,
	|	SalesInvoiceInventory.MeasurementUnit AS MeasurementUnit,
	|	ISNULL(UOM.Factor, 1) AS Factor,
	|	SalesInvoiceInventory.Ref AS SalesInvoice,
	|	SalesInvoiceInventory.Order AS Order,
	|	TT_SalesInvoices.PointInTime AS PointInTime,
	|	TT_SalesInvoices.Contract AS Contract,
	|	SalesInvoiceInventory.SalesRep AS SalesRep,
	|	SalesInvoiceInventory.InventoryGLAccount AS InventoryGLAccount,
	|	SalesInvoiceInventory.GoodsShippedNotInvoicedGLAccount AS GoodsShippedNotInvoicedGLAccount,
	|	SalesInvoiceInventory.UnearnedRevenueGLAccount AS UnearnedRevenueGLAccount,
	|	SalesInvoiceInventory.RevenueGLAccount AS RevenueGLAccount,
	|	SalesInvoiceInventory.COGSGLAccount AS COGSGLAccount
	|INTO TT_Products
	|FROM
	|	TT_SalesInvoices AS TT_SalesInvoices
	|		INNER JOIN Document.SalesInvoice.Inventory AS SalesInvoiceInventory
	|		ON TT_SalesInvoices.Ref = SalesInvoiceInventory.Ref
	|		INNER JOIN Catalog.Products AS ProductsCatalog
	|		ON (SalesInvoiceInventory.Products = ProductsCatalog.Ref)
	|		LEFT JOIN Catalog.UOM AS UOM
	|		ON (SalesInvoiceInventory.MeasurementUnit = UOM.Ref)
	|WHERE
	|	ProductsCatalog.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_Products.LineNumber AS LineNumber,
	|	TT_Products.Products AS Products,
	|	TT_Products.Characteristic AS Characteristic,
	|	TT_Products.Batch AS Batch,
	|	TT_Products.SalesInvoice AS SalesInvoice,
	|	TT_Products.Order AS Order,
	|	TT_Products.Factor AS Factor,
	|	TT_Products.Quantity * TT_Products.Factor AS BaseQuantity,
	|	SUM(TT_ProductsCumulative.Quantity * TT_ProductsCumulative.Factor) AS BaseQuantityCumulative
	|INTO TT_ProductsCumulative
	|FROM
	|	TT_Products AS TT_Products
	|		INNER JOIN TT_Products AS TT_ProductsCumulative
	|		ON TT_Products.Products = TT_ProductsCumulative.Products
	|			AND TT_Products.Characteristic = TT_ProductsCumulative.Characteristic
	|			AND TT_Products.Batch = TT_ProductsCumulative.Batch
	|			AND TT_Products.SalesInvoice = TT_ProductsCumulative.SalesInvoice
	|			AND TT_Products.Order = TT_ProductsCumulative.Order
	|			AND TT_Products.LineNumber >= TT_ProductsCumulative.LineNumber
	|
	|GROUP BY
	|	TT_Products.LineNumber,
	|	TT_Products.Products,
	|	TT_Products.Characteristic,
	|	TT_Products.Batch,
	|	TT_Products.SalesInvoice,
	|	TT_Products.Order,
	|	TT_Products.Factor,
	|	TT_Products.Quantity * TT_Products.Factor
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_ProductsCumulative.LineNumber AS LineNumber,
	|	TT_ProductsCumulative.Products AS Products,
	|	TT_ProductsCumulative.Characteristic AS Characteristic,
	|	TT_ProductsCumulative.Batch AS Batch,
	|	TT_ProductsCumulative.SalesInvoice AS SalesInvoice,
	|	TT_ProductsCumulative.Order AS Order,
	|	TT_ProductsCumulative.Factor AS Factor,
	|	CASE
	|		WHEN TT_AlreadyShipped.BaseQuantity > TT_ProductsCumulative.BaseQuantityCumulative - TT_ProductsCumulative.BaseQuantity
	|			THEN TT_ProductsCumulative.BaseQuantityCumulative - TT_AlreadyShipped.BaseQuantity
	|		ELSE TT_ProductsCumulative.BaseQuantity
	|	END AS BaseQuantity
	|INTO TT_ProductsNotYetShipped
	|FROM
	|	TT_ProductsCumulative AS TT_ProductsCumulative
	|		LEFT JOIN TT_AlreadyShipped AS TT_AlreadyShipped
	|		ON TT_ProductsCumulative.Products = TT_AlreadyShipped.Products
	|			AND TT_ProductsCumulative.Characteristic = TT_AlreadyShipped.Characteristic
	|			AND TT_ProductsCumulative.Batch = TT_AlreadyShipped.Batch
	|			AND TT_ProductsCumulative.SalesInvoice = TT_AlreadyShipped.SalesInvoice
	|			AND TT_ProductsCumulative.Order = TT_AlreadyShipped.Order
	|WHERE
	|	ISNULL(TT_AlreadyShipped.BaseQuantity, 0) < TT_ProductsCumulative.BaseQuantityCumulative
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_ProductsNotYetShipped.LineNumber AS LineNumber,
	|	TT_ProductsNotYetShipped.Products AS Products,
	|	TT_ProductsNotYetShipped.Characteristic AS Characteristic,
	|	TT_ProductsNotYetShipped.Batch AS Batch,
	|	TT_ProductsNotYetShipped.SalesInvoice AS SalesInvoice,
	|	TT_ProductsNotYetShipped.Order AS Order,
	|	TT_ProductsNotYetShipped.Factor AS Factor,
	|	TT_ProductsNotYetShipped.BaseQuantity AS BaseQuantity,
	|	SUM(TT_ProductsNotYetShippedCumulative.BaseQuantity) AS BaseQuantityCumulative
	|INTO TT_ProductsNotYetShippedCumulative
	|FROM
	|	TT_ProductsNotYetShipped AS TT_ProductsNotYetShipped
	|		INNER JOIN TT_ProductsNotYetShipped AS TT_ProductsNotYetShippedCumulative
	|		ON TT_ProductsNotYetShipped.Products = TT_ProductsNotYetShippedCumulative.Products
	|			AND TT_ProductsNotYetShipped.Characteristic = TT_ProductsNotYetShippedCumulative.Characteristic
	|			AND TT_ProductsNotYetShipped.Batch = TT_ProductsNotYetShippedCumulative.Batch
	|			AND TT_ProductsNotYetShipped.SalesInvoice = TT_ProductsNotYetShippedCumulative.SalesInvoice
	|			AND TT_ProductsNotYetShipped.Order = TT_ProductsNotYetShippedCumulative.Order
	|			AND TT_ProductsNotYetShipped.LineNumber >= TT_ProductsNotYetShippedCumulative.LineNumber
	|
	|GROUP BY
	|	TT_ProductsNotYetShipped.LineNumber,
	|	TT_ProductsNotYetShipped.Products,
	|	TT_ProductsNotYetShipped.Characteristic,
	|	TT_ProductsNotYetShipped.Batch,
	|	TT_ProductsNotYetShipped.SalesInvoice,
	|	TT_ProductsNotYetShipped.Order,
	|	TT_ProductsNotYetShipped.Factor,
	|	TT_ProductsNotYetShipped.BaseQuantity
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_ProductsNotYetShippedCumulative.LineNumber AS LineNumber,
	|	TT_ProductsNotYetShippedCumulative.Products AS Products,
	|	TT_ProductsNotYetShippedCumulative.Characteristic AS Characteristic,
	|	TT_ProductsNotYetShippedCumulative.Batch AS Batch,
	|	TT_ProductsNotYetShippedCumulative.SalesInvoice AS SalesInvoice,
	|	TT_ProductsNotYetShippedCumulative.Order AS Order,
	|	TT_ProductsNotYetShippedCumulative.Factor AS Factor,
	|	CASE
	|		WHEN TT_InvoicedBalances.QuantityBalance > TT_ProductsNotYetShippedCumulative.BaseQuantityCumulative
	|			THEN TT_ProductsNotYetShippedCumulative.BaseQuantity
	|		WHEN TT_InvoicedBalances.QuantityBalance > TT_ProductsNotYetShippedCumulative.BaseQuantityCumulative - TT_ProductsNotYetShippedCumulative.BaseQuantity
	|			THEN TT_InvoicedBalances.QuantityBalance - (TT_ProductsNotYetShippedCumulative.BaseQuantityCumulative - TT_ProductsNotYetShippedCumulative.BaseQuantity)
	|	END AS BaseQuantity
	|INTO TT_ProductsToBeShipped
	|FROM
	|	TT_ProductsNotYetShippedCumulative AS TT_ProductsNotYetShippedCumulative
	|		INNER JOIN TT_InvoicedBalances AS TT_InvoicedBalances
	|		ON TT_ProductsNotYetShippedCumulative.Products = TT_InvoicedBalances.Products
	|			AND TT_ProductsNotYetShippedCumulative.Characteristic = TT_InvoicedBalances.Characteristic
	|			AND TT_ProductsNotYetShippedCumulative.SalesInvoice = TT_InvoicedBalances.SalesInvoice
	|			AND TT_ProductsNotYetShippedCumulative.Order = TT_InvoicedBalances.Order
	|WHERE
	|	TT_InvoicedBalances.QuantityBalance > TT_ProductsNotYetShippedCumulative.BaseQuantityCumulative - TT_ProductsNotYetShippedCumulative.BaseQuantity
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_Products.LineNumber AS LineNumber,
	|	TT_Products.Products AS Products,
	|	TT_Products.Characteristic AS Characteristic,
	|	TT_Products.Batch AS Batch,
	|	CASE
	|		WHEN (CAST(TT_Products.Quantity * TT_Products.Factor AS NUMBER(15, 3))) = TT_ProductsToBeShipped.BaseQuantity
	|			THEN TT_Products.Quantity
	|		ELSE CAST(TT_ProductsToBeShipped.BaseQuantity / TT_Products.Factor AS NUMBER(15, 3))
	|	END AS Quantity,
	|	TT_Products.MeasurementUnit AS MeasurementUnit,
	|	TT_Products.Factor AS Factor,
	|	TT_Products.SalesInvoice AS SalesInvoice,
	|	TT_Products.Order AS Order,
	|	VALUE(Document.GoodsIssue.EmptyRef) AS GoodsIssue,
	|	TT_Products.PointInTime AS PointInTime,
	|	TT_Products.Contract AS Contract,
	|	TT_Products.SalesRep AS SalesRep,
	|	TT_Products.InventoryGLAccount AS InventoryGLAccount,
	|	TT_Products.GoodsShippedNotInvoicedGLAccount AS GoodsShippedNotInvoicedGLAccount,
	|	TT_Products.UnearnedRevenueGLAccount AS UnearnedRevenueGLAccount,
	|	TT_Products.RevenueGLAccount AS RevenueGLAccount,
	|	TT_Products.COGSGLAccount AS COGSGLAccount
	|FROM
	|	TT_Products AS TT_Products
	|		INNER JOIN TT_ProductsToBeShipped AS TT_ProductsToBeShipped
	|		ON TT_Products.LineNumber = TT_ProductsToBeShipped.LineNumber
	|			AND TT_Products.SalesInvoice = TT_ProductsToBeShipped.SalesInvoice
	|
	|ORDER BY
	|	PointInTime,
	|	LineNumber";
	
	If FilterData.Property("InvoicesArray") Then
		FilterString = "SalesInvoice.Ref IN(&InvoicesArray)";
		Query.SetParameter("InvoicesArray", FilterData.InvoicesArray);
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
			
			FilterString = FilterString + "SalesInvoice." + FilterItem.Key + " = &" + FilterItem.Key;
			Query.SetParameter(FilterItem.Key, FilterItem.Value);
			
		EndDo;
		
	EndIf;
	
	Query.Text = StrReplace(Query.Text, "&SalesInvoicesConditions", FilterString);
	
	Query.SetParameter("Ref", DocumentData.Ref);
	Query.SetParameter("Company", DriveServer.GetCompany(DocumentData.Company));
	Query.SetParameter("StructuralUnit", DocumentData.StructuralUnit);
	
	StructureData = New Structure;
	StructureData.Insert("ObjectParameters", DocumentData);
	
	ResultTable = Query.Execute().Unload();
	For Each ResultTableRow In ResultTable Do
		NewRow = Products.Add();
		FillPropertyValues(NewRow, ResultTableRow);
	EndDo;
	
	If FilterData.Property("InvoicesArray") Then
		GLAccountsInDocuments.FillTabSectionFromProductGLAccounts(DocumentData.Ref, FilterData.InvoicesArray);
	EndIf;
	
EndProcedure

Procedure InitializeDocumentData(DocumentRefGoodsIssue, StructureAdditionalProperties) Export
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	Header.Ref AS Ref,
	|	Header.Date AS Date,
	|	Header.Company AS Company,
	|	Header.Counterparty AS Counterparty,
	|	Header.Responsible AS Responsible,
	|	Header.Department AS Department,
	|	Header.StructuralUnit AS StructuralUnit,
	|	Header.Cell AS Cell,
	|	Header.Contract AS Contract,
	|	Header.Order AS Order,
	|	Header.OperationType AS OperationType
	|INTO GoodsIssueHeader
	|FROM
	|	Document.GoodsIssue AS Header
	|WHERE
	|	Header.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	GoodsIssueProducts.LineNumber AS LineNumber,
	|	GoodsIssueProducts.Ref AS Document,
	|	GoodsIssueHeader.Responsible AS Responsible,
	|	GoodsIssueHeader.Counterparty AS Counterparty,
	|	CASE
	|		WHEN GoodsIssueHeader.Contract <> VALUE(Catalog.CounterpartyContracts.EmptyRef)
	|			THEN GoodsIssueHeader.Contract
	|		ELSE GoodsIssueProducts.Contract
	|	END AS Contract,
	|	GoodsIssueHeader.Date AS Period,
	|	&Company AS Company,
	|	CatalogLinesOfBusiness.Ref AS BusinessLineSales,
	|	CASE
	|		WHEN GoodsIssueProducts.SalesInvoice = VALUE(Document.SalesInvoice.EmptyRef)
	|			THEN GoodsIssueProducts.GoodsShippedNotInvoicedGLAccount
	|		ELSE GoodsIssueProducts.COGSGLAccount
	|	END AS GLAccountCost,
	|	GoodsIssueProducts.RevenueGLAccount AS AccountStatementSales,
	|	GoodsIssueProducts.UnearnedRevenueGLAccount AS AccountStatementDeferredSales,
	|	GoodsIssueHeader.StructuralUnit AS StructuralUnit,
	|	GoodsIssueHeader.Department AS Department,
	|	GoodsIssueHeader.Cell AS Cell,
	|	CASE
	|		WHEN GoodsIssueHeader.OperationType = VALUE(Enum.OperationTypesGoodsIssue.ReturnToAThirdParty)
	|			THEN GoodsIssueProducts.InventoryReceivedGLAccount
	|		ELSE GoodsIssueProducts.InventoryGLAccount
	|	END AS GLAccount,
	|	GoodsIssueProducts.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN GoodsIssueProducts.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseBatches
	|			THEN GoodsIssueProducts.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS Batch,
	|	CASE
	|		WHEN GoodsIssueHeader.Order <> UNDEFINED
	|				AND GoodsIssueHeader.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|			THEN GoodsIssueHeader.Order
	|		WHEN GoodsIssueProducts.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|			THEN GoodsIssueProducts.Order
	|		ELSE VALUE(Document.SalesOrder.EmptyRef)
	|	END AS Order,
	|	GoodsIssueProducts.SalesInvoice AS SalesInvoice,
	|	CASE
	|		WHEN VALUETYPE(GoodsIssueProducts.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN GoodsIssueProducts.Quantity
	|		ELSE GoodsIssueProducts.Quantity * GoodsIssueProducts.MeasurementUnit.Factor
	|	END AS Quantity,
	|	GoodsIssueProducts.ConnectionKey AS ConnectionKey,
	|	GoodsIssueHeader.OperationType AS OperationType,
	|	CASE
	|		WHEN GoodsIssueHeader.OperationType = VALUE(Enum.OperationTypesGoodsIssue.TransferToAThirdParty)
	|			THEN &Company
	|		ELSE UNDEFINED
	|	END AS CorrOrganization,
	|	CASE
	|		WHEN GoodsIssueHeader.OperationType = VALUE(Enum.OperationTypesGoodsIssue.TransferToAThirdParty)
	|			THEN GoodsIssueHeader.Counterparty
	|		ELSE UNDEFINED
	|	END AS StructuralUnitCorr,
	|	CASE
	|		WHEN GoodsIssueHeader.OperationType = VALUE(Enum.OperationTypesGoodsIssue.TransferToAThirdParty)
	|			THEN GoodsIssueProducts.InventoryTransferredGLAccount
	|		WHEN GoodsIssueHeader.OperationType = VALUE(Enum.OperationTypesGoodsIssue.ReturnToAThirdParty)
	|			THEN UNDEFINED
	|		WHEN GoodsIssueProducts.SalesInvoice = VALUE(Document.SalesInvoice.EmptyRef)
	|			THEN GoodsIssueProducts.GoodsShippedNotInvoicedGLAccount
	|		ELSE GoodsIssueProducts.COGSGLAccount
	|	END AS CorrGLAccount,
	|	CASE
	|		WHEN GoodsIssueHeader.OperationType = VALUE(Enum.OperationTypesGoodsIssue.TransferToAThirdParty)
	|			THEN CASE
	|					WHEN GoodsIssueHeader.Order REFS Document.SalesOrder
	|							AND GoodsIssueHeader.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|						THEN GoodsIssueHeader.Order
	|					WHEN GoodsIssueHeader.Order REFS Document.PurchaseOrder
	|							AND GoodsIssueHeader.Order <> VALUE(Document.PurchaseOrder.EmptyRef)
	|						THEN GoodsIssueHeader.Order
	|					ELSE UNDEFINED
	|				END
	|		ELSE UNDEFINED
	|	END AS CorrOrder,
	|	CASE
	|		WHEN &UseBatches
	|				AND GoodsIssueProducts.Batch.Status = VALUE(Enum.BatchStatuses.CounterpartysInventory)
	|				AND GoodsIssueHeader.OperationType = VALUE(Enum.OperationTypesGoodsIssue.SaleToCustomer)
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS ProductsOnCommission,
	|	GoodsIssueHeader.Counterparty.GLAccountVendorSettlements AS GLAccountVendorSettlements,
	|	GoodsIssueProducts.SalesRep AS SalesRep,
	|	GoodsIssueProducts.InventoryTransferredGLAccount AS InventoryTransferredGLAccount
	|INTO TemporaryTableProducts
	|FROM
	|	GoodsIssueHeader AS GoodsIssueHeader
	|		INNER JOIN Document.GoodsIssue.Products AS GoodsIssueProducts
	|		ON GoodsIssueHeader.Ref = GoodsIssueProducts.Ref
	|		LEFT JOIN Catalog.Products AS CatalogProducts
	|		ON (GoodsIssueProducts.Products = CatalogProducts.Ref)
	|		LEFT JOIN Catalog.LinesOfBusiness AS CatalogLinesOfBusiness
	|		ON (CatalogProducts.BusinessLine = CatalogLinesOfBusiness.Ref)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	GoodsIssueSerialNumbers.ConnectionKey AS ConnectionKey,
	|	GoodsIssueSerialNumbers.SerialNumber AS SerialNumber
	|INTO TemporaryTableSerialNumbers
	|FROM
	|	Document.GoodsIssue.SerialNumbers AS GoodsIssueSerialNumbers
	|WHERE
	|	GoodsIssueSerialNumbers.Ref = &Ref
	|	AND &UseSerialNumbers";
	
	Query.SetParameter("Ref",					DocumentRefGoodsIssue);
	Query.SetParameter("Company",				StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PointInTime",			New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("UseCharacteristics",	StructureAdditionalProperties.AccountingPolicy.UseCharacteristics);
	Query.SetParameter("UseBatches",			StructureAdditionalProperties.AccountingPolicy.UseBatches);
	Query.SetParameter("UseSerialNumbers",		StructureAdditionalProperties.AccountingPolicy.UseSerialNumbers);
	
	Query.ExecuteBatch();
	
	// Creation of document postings.
	StructureAdditionalProperties.TableForRegisterRecords.Insert(
		"TableAccountingJournalEntries",
		DriveServer.EmptyAccountingJournalEntriesTable());
		
	IncomeAndExpensesRecordSet = AccumulationRegisters.IncomeAndExpenses.CreateRecordSet();
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpenses", IncomeAndExpensesRecordSet.Unload());
	
	SalesRecordSet = AccumulationRegisters.Sales.CreateRecordSet();
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSales", SalesRecordSet.Unload());
	
	PerformanceEstimationClientServer.StartTimeMeasurement("DocumentGoodsIssuePositingGenerateTable");
	
	GenerateTableInventoryInWarehouses(DocumentRefGoodsIssue, StructureAdditionalProperties);
	GenerateTableSalesOrders(DocumentRefGoodsIssue, StructureAdditionalProperties);
	GenerateTableGoodsShippedNotInvoiced(DocumentRefGoodsIssue, StructureAdditionalProperties);
	GenerateTableStockReceivedFromThirdParties(DocumentRefGoodsIssue, StructureAdditionalProperties);
	GenerateTableStockTransferredToThirdParties(DocumentRefGoodsIssue, StructureAdditionalProperties);
	GenerateTablePurchaseOrders(DocumentRefGoodsIssue, StructureAdditionalProperties);
	GenerateTableInventoryDemand(DocumentRefGoodsIssue, StructureAdditionalProperties);
	
	PerformanceEstimationClientServer.StartTimeMeasurement("DocumentGoodsIssuePositingGenerateTableInventory");
	
	GenerateTableInventory(DocumentRefGoodsIssue, StructureAdditionalProperties);
	
	PerformanceEstimationClientServer.StartTimeMeasurement("DocumentGoodsIssuePositingGenerateTableGoodsInvoicedNotShipped");
	
	GenerateTableGoodsInvoicedNotShipped(DocumentRefGoodsIssue, StructureAdditionalProperties);
	
	PerformanceEstimationClientServer.StartTimeMeasurement("DocumentGoodsIssuePositingGenerateTableManagement");
	
	// Serial numbers
	GenerateTableSerialNumbers(DocumentRefGoodsIssue, StructureAdditionalProperties);
	
	StructureAdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries = 
		DriveServer.AddOfflineAccountingJournalEntriesRecords(StructureAdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries, DocumentRefGoodsIssue);
	
EndProcedure

Procedure CheckAbilityOfEnteringByGoodsIssue(FillingData, Posted, OperationType, IsSalesInvoice) Export
	
	If IsSalesInvoice AND OperationType <> Enums.OperationTypesGoodsIssue.SaleToCustomer Then
		ErrorText = NStr("en = 'Cannot use %1 as a base document for Sales invoice. Please select a goods issue with ""Sales to customer"" operation.'");
		Raise StringFunctionsClientServer.SubstituteParametersInString(
				ErrorText,
				FillingData);
	EndIf;

	If Posted <> Undefined AND Not Posted Then
		ErrorText = NStr("en = '%1 is not posted. Cannot use it as a base document. Please, post it first.'");
		Raise StringFunctionsClientServer.SubstituteParametersInString(
				ErrorText,
				FillingData);
	EndIf;
	
EndProcedure

Procedure RunControl(DocumentRefGoodsIssue, AdditionalProperties, Cancel, PostingDelete = False) Export
	
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
		OR StructureTemporaryTables.RegisterRecordsGoodsShippedNotInvoicedChange
		OR StructureTemporaryTables.RegisterRecordsGoodsInvoicedNotShippedChange
		OR StructureTemporaryTables.RegisterRecordsStockTransferredToThirdPartiesChange 
		OR StructureTemporaryTables.RegisterRecordsStockReceivedFromThirdPartiesChange 
		OR StructureTemporaryTables.RegisterRecordsPurchaseOrdersChange
		OR StructureTemporaryTables.RegisterRecordsInventoryDemandChange Then
		
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
		|	RegisterRecordsGoodsShippedNotInvoicedChange.LineNumber AS LineNumber,
		|	RegisterRecordsGoodsShippedNotInvoicedChange.Company AS CompanyPresentation,
		|	RegisterRecordsGoodsShippedNotInvoicedChange.GoodsIssue AS GoodsIssuePresentation,
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
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	RegisterRecordsStockTransferredToThirdPartiesChange.LineNumber AS LineNumber,
		|	RegisterRecordsStockTransferredToThirdPartiesChange.Company AS CompanyPresentation,
		|	RegisterRecordsStockTransferredToThirdPartiesChange.Products AS ProductsPresentation,
		|	RegisterRecordsStockTransferredToThirdPartiesChange.Characteristic AS CharacteristicPresentation,
		|	RegisterRecordsStockTransferredToThirdPartiesChange.Batch AS BatchPresentation,
		|	RegisterRecordsStockTransferredToThirdPartiesChange.Counterparty AS CounterpartyPresentation,
		|	RegisterRecordsStockTransferredToThirdPartiesChange.Contract AS ContractPresentation,
		|	RegisterRecordsStockTransferredToThirdPartiesChange.Order AS OrderPresentation,
		|	StockTransferredToThirdPartiesBalances.Products.MeasurementUnit AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsStockTransferredToThirdPartiesChange.QuantityChange, 0) + ISNULL(StockTransferredToThirdPartiesBalances.QuantityBalance, 0) AS BalanceStockTransferredToThirdParties,
		|	ISNULL(StockTransferredToThirdPartiesBalances.QuantityBalance, 0) AS QuantityBalanceStockTransferredToThirdParties
		|FROM
		|	RegisterRecordsStockTransferredToThirdPartiesChange AS RegisterRecordsStockTransferredToThirdPartiesChange
		|		INNER JOIN AccumulationRegister.StockTransferredToThirdParties.Balance(&ControlTime, ) AS StockTransferredToThirdPartiesBalances
		|		ON RegisterRecordsStockTransferredToThirdPartiesChange.Company = StockTransferredToThirdPartiesBalances.Company
		|			AND RegisterRecordsStockTransferredToThirdPartiesChange.Products = StockTransferredToThirdPartiesBalances.Products
		|			AND RegisterRecordsStockTransferredToThirdPartiesChange.Characteristic = StockTransferredToThirdPartiesBalances.Characteristic
		|			AND RegisterRecordsStockTransferredToThirdPartiesChange.Batch = StockTransferredToThirdPartiesBalances.Batch
		|			AND RegisterRecordsStockTransferredToThirdPartiesChange.Counterparty = StockTransferredToThirdPartiesBalances.Counterparty
		|			AND RegisterRecordsStockTransferredToThirdPartiesChange.Contract = StockTransferredToThirdPartiesBalances.Contract
		|			AND RegisterRecordsStockTransferredToThirdPartiesChange.Order = StockTransferredToThirdPartiesBalances.Order
		|			AND (ISNULL(StockTransferredToThirdPartiesBalances.QuantityBalance, 0) < 0)
		|
		|ORDER BY
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	RegisterRecordsStockReceivedFromThirdPartiesChange.LineNumber AS LineNumber,
		|	RegisterRecordsStockReceivedFromThirdPartiesChange.Company AS CompanyPresentation,
		|	RegisterRecordsStockReceivedFromThirdPartiesChange.Products AS ProductsPresentation,
		|	RegisterRecordsStockReceivedFromThirdPartiesChange.Characteristic AS CharacteristicPresentation,
		|	RegisterRecordsStockReceivedFromThirdPartiesChange.Batch AS BatchPresentation,
		|	RegisterRecordsStockReceivedFromThirdPartiesChange.Counterparty AS CounterpartyPresentation,
		|	RegisterRecordsStockReceivedFromThirdPartiesChange.Contract AS ContractPresentation,
		|	RegisterRecordsStockReceivedFromThirdPartiesChange.Order AS OrderPresentation,
		|	StockReceivedFromThirdPartiesBalances.Products.MeasurementUnit AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsStockReceivedFromThirdPartiesChange.QuantityChange, 0) + ISNULL(StockReceivedFromThirdPartiesBalances.QuantityBalance, 0) AS BalanceStockReceivedFromThirdParties,
		|	ISNULL(StockReceivedFromThirdPartiesBalances.QuantityBalance, 0) AS QuantityBalanceStockReceivedFromThirdParties
		|FROM
		|	RegisterRecordsStockReceivedFromThirdPartiesChange AS RegisterRecordsStockReceivedFromThirdPartiesChange
		|		INNER JOIN AccumulationRegister.StockReceivedFromThirdParties.Balance(&ControlTime, ) AS StockReceivedFromThirdPartiesBalances
		|		ON RegisterRecordsStockReceivedFromThirdPartiesChange.Company = StockReceivedFromThirdPartiesBalances.Company
		|			AND RegisterRecordsStockReceivedFromThirdPartiesChange.Products = StockReceivedFromThirdPartiesBalances.Products
		|			AND RegisterRecordsStockReceivedFromThirdPartiesChange.Characteristic = StockReceivedFromThirdPartiesBalances.Characteristic
		|			AND RegisterRecordsStockReceivedFromThirdPartiesChange.Batch = StockReceivedFromThirdPartiesBalances.Batch
		|			AND RegisterRecordsStockReceivedFromThirdPartiesChange.Counterparty = StockReceivedFromThirdPartiesBalances.Counterparty
		|			AND RegisterRecordsStockReceivedFromThirdPartiesChange.Contract = StockReceivedFromThirdPartiesBalances.Contract
		|			AND RegisterRecordsStockReceivedFromThirdPartiesChange.Order = StockReceivedFromThirdPartiesBalances.Order
		|			AND (ISNULL(StockReceivedFromThirdPartiesBalances.QuantityBalance, 0) < 0)
		|
		|ORDER BY
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	RegisterRecordsPurchaseOrdersChange.LineNumber AS LineNumber,
		|	RegisterRecordsPurchaseOrdersChange.Company AS CompanyPresentation,
		|	RegisterRecordsPurchaseOrdersChange.PurchaseOrder AS OrderPresentation,
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
			OR Not ResultsArray[5].IsEmpty()
			OR Not ResultsArray[6].IsEmpty()
			OR Not ResultsArray[7].IsEmpty()
			OR Not ResultsArray[8].IsEmpty() Then
			DocumentObjectGoodsIssue = DocumentRefGoodsIssue.GetObject();
		EndIf;
		
		// Negative balance of inventory in the warehouse.
		If Not ResultsArray[0].IsEmpty() Then
			QueryResultSelection = ResultsArray[0].Select();
			DriveServer.ShowMessageAboutPostingToInventoryInWarehousesRegisterErrors(DocumentObjectGoodsIssue, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance of inventory.
		If Not ResultsArray[1].IsEmpty() Then
			QueryResultSelection = ResultsArray[1].Select();
			DriveServer.ShowMessageAboutPostingToInventoryRegisterErrors(DocumentObjectGoodsIssue, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance on sales order.
		If Not ResultsArray[2].IsEmpty() Then
			QueryResultSelection = ResultsArray[2].Select();
			DriveServer.ShowMessageAboutPostingToSalesOrdersRegisterErrors(DocumentObjectGoodsIssue, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance on goods issued not yet invoiced
		If Not ResultsArray[3].IsEmpty() Then
			QueryResultSelection = ResultsArray[3].Select();
			DriveServer.ShowMessageAboutPostingToGoodsShippedNotInvoicedRegisterErrors(DocumentObjectGoodsIssue, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance of transferred inventory.
		If Not ResultsArray[4].IsEmpty() Then
			QueryResultSelection = ResultsArray[4].Select();
			DriveServer.ShowMessageAboutPostingToStockTransferredToThirdPartiesRegisterErrors(DocumentObjectGoodsIssue, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance of inventory received.
		If Not ResultsArray[5].IsEmpty() Then
			QueryResultSelection = ResultsArray[5].Select();
			DriveServer.ShowMessageAboutPostingToStockReceivedFromThirdPartiesRegisterErrors(DocumentObjectGoodsIssue, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance on the order to the vendor.
		If Not ResultsArray[6].IsEmpty() Then
			QueryResultSelection = ResultsArray[6].Select();
			DriveServer.ShowMessageAboutPostingToPurchaseOrdersRegisterErrors(DocumentObjectGoodsIssue, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance of need for inventory.
		If Not ResultsArray[7].IsEmpty() Then
			QueryResultSelection = ResultsArray[7].Select();
			DriveServer.ShowMessageAboutPostingToInventoryDemandRegisterErrors(DocumentObjectGoodsIssue, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance of goods invoiced not shipped
		If Not ResultsArray[8].IsEmpty() Then
			QueryResultSelection = ResultsArray[8].Select();
			DriveServer.ShowMessageAboutPostingToGoodsInvoicedNotShippedRegisterErrors(DocumentObjectGoodsIssue, QueryResultSelection, Cancel);
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region TableGeneration

Procedure GenerateTableSalesOrders(DocumentRef, StructureAdditionalProperties)
	
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
	|	TemporaryTableProducts AS TableSalesOrders
	|WHERE
	|	TableSalesOrders.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|	AND TableSalesOrders.Order REFS Document.SalesOrder
	|	AND TableSalesOrders.SalesInvoice = VALUE(Document.SalesInvoice.EmptyRef)
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

Procedure GenerateTableInventory(DocumentRef, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	TableProducts.LineNumber AS LineNumber,
	|	TableProducts.Period AS Period,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableProducts.Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	CASE
	|		WHEN TableProducts.OperationType = VALUE(Enum.OperationTypesGoodsIssue.ReturnToAThirdParty)
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS Return,
	|	TableProducts.Document AS Document,
	|	CASE
	|		WHEN TableProducts.OperationType = VALUE(Enum.OperationTypesGoodsIssue.SaleToCustomer)
	|			THEN CASE
	|					WHEN TableProducts.SalesInvoice = VALUE(Document.SalesInvoice.EmptyRef)
	|						THEN TableProducts.Document
	|					ELSE TableProducts.SalesInvoice
	|				END
	|		ELSE UNDEFINED
	|	END AS SourceDocument,
	|	CASE
	|		WHEN TableProducts.OperationType = VALUE(Enum.OperationTypesGoodsIssue.SaleToCustomer)
	|				AND TableProducts.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|				AND TableProducts.Order <> VALUE(Document.WorkOrder.EmptyRef)
	|			THEN TableProducts.Order
	|		ELSE UNDEFINED
	|	END AS CorrSalesOrder,
	|	CASE
	|		WHEN TableProducts.OperationType = VALUE(Enum.OperationTypesGoodsIssue.SaleToCustomer)
	|			THEN TableProducts.Department
	|		ELSE UNDEFINED
	|	END AS Department,
	|	CASE
	|		WHEN TableProducts.OperationType = VALUE(Enum.OperationTypesGoodsIssue.SaleToCustomer)
	|			THEN TableProducts.Responsible
	|		ELSE UNDEFINED
	|	END AS Responsible,
	|	TableProducts.GLAccountCost AS GLAccountCost,
	|	ISNULL(TableProducts.StructuralUnit, VALUE(Catalog.Counterparties.EmptyRef)) AS StructuralUnit,
	|	CASE
	|		WHEN TableProducts.OperationType = VALUE(Enum.OperationTypesGoodsIssue.SaleToCustomer)
	|			THEN TableProducts.Counterparty
	|		ELSE TableProducts.StructuralUnitCorr
	|	END AS StructuralUnitCorr,
	|	CASE
	|		WHEN TableProducts.OperationType = VALUE(Enum.OperationTypesGoodsIssue.SaleToCustomer)
	|			THEN TableProducts.Company
	|		ELSE TableProducts.CorrOrganization
	|	END AS CorrOrganization,
	|	TableProducts.CorrGLAccount AS CorrGLAccount,
	|	TableProducts.Products AS ProductsCorr,
	|	TableProducts.Characteristic AS CharacteristicCorr,
	|	TableProducts.Batch AS BatchCorr,
	|	CASE
	|		WHEN NOT &FillAmount
	|				OR TableProducts.Order = VALUE(Document.SalesOrder.EmptyRef)
	|				OR TableProducts.Order = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN UNDEFINED
	|		WHEN TableProducts.Order REFS Document.SalesOrder
	|				AND TableProducts.OperationType <> VALUE(Enum.OperationTypesGoodsIssue.ReturnToAThirdParty)
	|			THEN TableProducts.Order
	|		WHEN TableProducts.Order REFS Document.PurchaseOrder
	|				AND TableProducts.OperationType = VALUE(Enum.OperationTypesGoodsIssue.TransferToAThirdParty)
	|				AND TableProducts.Order.SalesOrder <> VALUE(Document.SalesOrder.EmptyRef)
	|				AND TableProducts.Order.SalesOrder <> VALUE(Document.WorkOrder.EmptyRef)
	|			THEN TableProducts.Order.SalesOrder
	|		ELSE UNDEFINED
	|	END AS SalesOrder,
	|	CASE
	|		WHEN TableProducts.CorrOrder REFS Document.SalesOrder
	|				AND TableProducts.CorrOrder <> VALUE(Document.SalesOrder.EmptyRef)
	|				AND TableProducts.CorrOrder <> VALUE(Document.WorkOrder.EmptyRef)
	|			THEN TableProducts.CorrOrder
	|		WHEN TableProducts.CorrOrder REFS Document.PurchaseOrder
	|				AND TableProducts.OperationType = VALUE(Enum.OperationTypesGoodsIssue.TransferToAThirdParty)
	|				AND TableProducts.CorrOrder.SalesOrder <> VALUE(Document.SalesOrder.EmptyRef)
	|				AND TableProducts.CorrOrder.SalesOrder <> VALUE(Document.WorkOrder.EmptyRef)
	|			THEN TableProducts.CorrOrder.SalesOrder
	|		ELSE UNDEFINED
	|	END AS CustomerCorrOrder,
	|	TableProducts.GLAccount AS GLAccount,
	|	TableProducts.Products AS Products,
	|	TableProducts.Characteristic AS Characteristic,
	|	TableProducts.Batch AS Batch,
	|	TableProducts.Quantity AS Quantity,
	|	0 AS Cost,
	|	0 AS Amount,
	|	CASE
	|		WHEN TableProducts.OperationType = VALUE(Enum.OperationTypesGoodsIssue.SaleToCustomer)
	|				OR TableProducts.OperationType = VALUE(Enum.OperationTypesGoodsIssue.TransferToAThirdParty)
	|			THEN FALSE
	|		ELSE TRUE
	|	END AS FixedCost,
	|	CASE
	|		WHEN TableProducts.OperationType = VALUE(Enum.OperationTypesGoodsIssue.SaleToCustomer)
	|			THEN TableProducts.GLAccountCost
	|		ELSE TableProducts.InventoryTransferredGLAccount
	|	END AS AccountDr,
	|	TableProducts.GLAccount AS AccountCr,
	|	CAST(&InventoryWriteOff AS STRING(100)) AS Content,
	|	CAST(&InventoryWriteOff AS STRING(100)) AS ContentOfAccountingRecord,
	|	TableProducts.SalesInvoice AS SalesInvoice,
	|	FALSE AS OfflineRecord,
	|	TableProducts.SalesRep AS SalesRep
	|FROM
	|	TemporaryTableProducts AS TableProducts
	|
	|UNION ALL
	|
	|SELECT
	|	TableProducts.LineNumber,
	|	TableProducts.Period,
	|	VALUE(AccumulationRecordType.Receipt),
	|	TableProducts.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	FALSE,
	|	TableProducts.Document,
	|	TableProducts.Document,
	|	CASE
	|		WHEN TableProducts.Order = VALUE(Document.SalesOrder.EmptyRef)
	|				OR TableProducts.Order = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE TableProducts.Order
	|	END,
	|	TableProducts.Department,
	|	TableProducts.Responsible,
	|	TableProducts.GLAccountCost,
	|	TableProducts.Counterparty,
	|	UNDEFINED,
	|	TableProducts.Company,
	|	TableProducts.GLAccount,
	|	TableProducts.Products,
	|	TableProducts.Characteristic,
	|	TableProducts.Batch,
	|	CASE
	|		WHEN TableProducts.Order = VALUE(Document.SalesOrder.EmptyRef)
	|				OR TableProducts.Order = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE TableProducts.Order
	|	END,
	|	UNDEFINED,
	|	TableProducts.CorrGLAccount,
	|	TableProducts.Products,
	|	TableProducts.Characteristic,
	|	TableProducts.Batch,
	|	TableProducts.Quantity,
	|	0,
	|	0,
	|	FALSE,
	|	TableProducts.GLAccountCost,
	|	TableProducts.GLAccount,
	|	CAST(&InventoryWriteOff AS STRING(100)),
	|	CAST(&InventoryWriteOff AS STRING(100)),
	|	TableProducts.SalesInvoice,
	|	FALSE,
	|	TableProducts.SalesRep
	|FROM
	|	TemporaryTableProducts AS TableProducts
	|WHERE
	|	TableProducts.OperationType = VALUE(Enum.OperationTypesGoodsIssue.SaleToCustomer)
	|	AND TableProducts.SalesInvoice = VALUE(Document.SalesInvoice.EmptyRef)
	|	AND NOT &FillAmount
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
	|	OfflineRecords.StructuralUnit,
	|	OfflineRecords.StructuralUnitCorr,
	|	UNDEFINED,
	|	OfflineRecords.CorrGLAccount,
	|	OfflineRecords.ProductsCorr,
	|	OfflineRecords.CharacteristicCorr,
	|	OfflineRecords.BatchCorr,
	|	OfflineRecords.SalesOrder,
	|	OfflineRecords.CustomerCorrOrder,
	|	OfflineRecords.GLAccount,
	|	OfflineRecords.Products,
	|	OfflineRecords.Characteristic,
	|	OfflineRecords.Batch,
	|	OfflineRecords.Quantity,
	|	UNDEFINED,
	|	OfflineRecords.Amount,
	|	OfflineRecords.FixedCost,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	OfflineRecords.ContentOfAccountingRecord,
	|	UNDEFINED,
	|	OfflineRecords.OfflineRecord,
	|	OfflineRecords.SalesRep
	|FROM
	|	AccumulationRegister.Inventory AS OfflineRecords
	|WHERE
	|	OfflineRecords.Recorder = &Ref
	|	AND OfflineRecords.OfflineRecord";
	
	Query.SetParameter("InventoryWriteOff", NStr("en = 'Inventory shipped'", CommonUseClientServer.MainLanguageCode()));
	FillAmount = StructureAdditionalProperties.AccountingPolicy.InventoryValuationMethod = Enums.InventoryValuationMethods.WeightedAverage;
	Query.SetParameter("FillAmount", FillAmount);
	Query.SetParameter("Ref", DocumentRef);
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventory", QueryResult.Unload());
	
	If DocumentRef.OperationType = Enums.OperationTypesGoodsIssue.ReturnToAThirdParty Then
		GenerateTableInventoryReturn(DocumentRef, StructureAdditionalProperties);
	ElsIf FillAmount Then
		GenerateTableInventorySale(DocumentRef, StructureAdditionalProperties);
	EndIf;
	
EndProcedure

Procedure GenerateTableInventorySale(DocumentRef, StructureAdditionalProperties)
	
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
	|		CASE
	|			WHEN TableInventory.Order REFS Document.SalesOrder
	|				THEN TableInventory.Order
	|			WHEN TableInventory.Order REFS Document.PurchaseOrder
	|					AND TableInventory.OperationType = VALUE(Enum.OperationTypesGoodsIssue.TransferToAThirdParty)
	|					AND TableInventory.Order.SalesOrder <> VALUE(Document.SalesOrder.EmptyRef)
	|					AND TableInventory.Order.SalesOrder <> VALUE(Document.WorkOrder.EmptyRef)
	|				THEN TableInventory.Order.SalesOrder
	|			ELSE UNDEFINED
	|		END AS SalesOrder
	|	FROM
	|		TemporaryTableProducts AS TableInventory
	|	WHERE
	|		TableInventory.Order <> UNDEFINED
	|		AND TableInventory.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|		AND TableInventory.Order <> VALUE(Document.WorkOrder.EmptyRef)
	|		AND TableInventory.Order <> VALUE(Document.PurchaseOrder.EmptyRef)
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
	|		TemporaryTableProducts AS TableInventory) AS TableInventory
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
	|						CASE
	|							WHEN TableInventory.Order REFS Document.SalesOrder
	|								THEN TableInventory.Order
	|							WHEN TableInventory.Order REFS Document.PurchaseOrder
	|									AND TableInventory.OperationType = VALUE(Enum.OperationTypesGoodsIssue.TransferToAThirdParty)
	|									AND TableInventory.Order.SalesOrder <> VALUE(Document.SalesOrder.EmptyRef)
	|									AND TableInventory.Order.SalesOrder <> VALUE(Document.WorkOrder.EmptyRef)
	|								THEN TableInventory.Order.SalesOrder
	|							ELSE UNDEFINED
	|						END
	|					FROM
	|						TemporaryTableProducts AS TableInventory
	|					WHERE
	|						TableInventory.Order <> UNDEFINED
	|						AND TableInventory.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|						AND TableInventory.Order <> VALUE(Document.WorkOrder.EmptyRef)
	|						AND TableInventory.Order <> VALUE(Document.PurchaseOrder.EmptyRef))) AS InventoryBalances
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
	|						TemporaryTableProducts AS TableInventory)) AS InventoryBalances
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
	
	Query.SetParameter("Ref", DocumentRef);
	Query.SetParameter("ControlTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.PointInTime.Date);
	
	QueryResult = Query.Execute();
	
	TableInventoryBalances = QueryResult.Unload();
	TableInventoryBalances.Indexes.Add("Company,StructuralUnit,GLAccount,Products,Characteristic,Batch,SalesOrder");
	
	TemporaryTableInventory = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.CopyColumns();
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();
	
	TableAccountingJournalEntries = StructureAdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries;
	
	For n = 0 To StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Count() - 1 Do
		
		RowTableInventory = StructureAdditionalProperties.TableForRegisterRecords.TableInventory[n];
		
		StructureForSearch = New Structure;
		StructureForSearch.Insert("Company",		RowTableInventory.Company);
		StructureForSearch.Insert("StructuralUnit",	RowTableInventory.StructuralUnit);
		StructureForSearch.Insert("GLAccount",		RowTableInventory.GLAccount);
		StructureForSearch.Insert("Products",		RowTableInventory.Products);
		StructureForSearch.Insert("Characteristic",	RowTableInventory.Characteristic);
		StructureForSearch.Insert("Batch",			RowTableInventory.Batch);
		
		QuantityRequiredAvailableBalance = ?(ValueIsFilled(RowTableInventory.Quantity), RowTableInventory.Quantity, 0);
		
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
				RowTableAccountingJournalEntries = TableAccountingJournalEntries.Add();
				FillPropertyValues(RowTableAccountingJournalEntries, RowTableInventory);
				RowTableAccountingJournalEntries.Amount = AmountToBeWrittenOff;
			EndIf;
			
			If Not ValueIsFilled(RowTableInventory.SalesInvoice) Then
				
				TableRowReceipt = TemporaryTableInventory.Add();
				FillPropertyValues(TableRowReceipt, RowTableInventory,,"StructuralUnit, StructuralUnitCorr");
				
				TableRowReceipt.RecordType = AccumulationRecordType.Receipt;
				
				TableRowReceipt.Company = RowTableInventory.CorrOrganization;
				TableRowReceipt.StructuralUnit = RowTableInventory.StructuralUnitCorr;
				TableRowReceipt.GLAccount = RowTableInventory.CorrGLAccount;
				TableRowReceipt.Products = RowTableInventory.ProductsCorr;
				TableRowReceipt.Characteristic = RowTableInventory.CharacteristicCorr;
				TableRowReceipt.Batch = RowTableInventory.BatchCorr;
				
				TableRowReceipt.SalesOrder = RowTableInventory.CustomerCorrOrder;
				
				TableRowReceipt.CorrOrganization = RowTableInventory.Company;
				TableRowReceipt.StructuralUnitCorr = RowTableInventory.StructuralUnit;
				TableRowReceipt.CorrGLAccount = RowTableInventory.GLAccount;
				TableRowReceipt.ProductsCorr = RowTableInventory.Products;
				TableRowReceipt.CharacteristicCorr = RowTableInventory.Characteristic;
				TableRowReceipt.BatchCorr = RowTableInventory.Batch;
				
				TableRowReceipt.CustomerCorrOrder = Undefined;
				
				TableRowReceipt.Amount = AmountToBeWrittenOff;
				TableRowReceipt.Quantity = QuantityRequiredAvailableBalance;
				
				TableRowReceipt.ContentOfAccountingRecord = NStr("en = 'Inventory transfer'", MainLanguageCode);
				
				TableRowReceipt.GLAccount = RowTableInventory.CorrGLAccount;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	StructureAdditionalProperties.TableForRegisterRecords.TableInventory = TemporaryTableInventory;
	
EndProcedure

Procedure GenerateTableInventoryReturn(DocumentRef, StructureAdditionalProperties)
	
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
	|	UNDEFINED AS SalesOrder
	|FROM
	|	TemporaryTableProducts AS TableInventory
	|
	|GROUP BY
	|	TableInventory.Company,
	|	TableInventory.StructuralUnit,
	|	TableInventory.GLAccount,
	|	TableInventory.Products,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch";
	
	QueryResult = Query.Execute();
	
	Block = New DataLock;
	LockItem			= Block.Add("AccumulationRegister.Inventory");
	LockItem.Mode		= DataLockMode.Exclusive;
	LockItem.DataSource	= QueryResult;
	
	For Each ColumnQueryResult In QueryResult.Columns Do
		LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
	EndDo;
	Block.Lock();
	
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
	|		UNDEFINED AS SalesOrder,
	|		SUM(InventoryBalances.QuantityBalance) AS QuantityBalance,
	|		SUM(InventoryBalances.AmountBalance) AS AmountBalance
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
	|						TemporaryTableProducts AS TableInventory)) AS InventoryBalances
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
	|		ISNULL(DocumentRegisterRecordsInventory.Quantity, 0),
	|		ISNULL(DocumentRegisterRecordsInventory.Amount, 0)
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
	
	Query.SetParameter("Ref",			DocumentRef);
	Query.SetParameter("ControlTime",	New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod",	StructureAdditionalProperties.ForPosting.PointInTime.Date);
	
	TableAccountingJournalEntries = StructureAdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries;
	
	QueryResult = Query.Execute();
	TableInventoryBalances = QueryResult.Unload();
	
	TableInventoryBalances.Indexes.Add("Company, StructuralUnit, GLAccount, Products, Characteristic, Batch");
	
	For n = 0 To StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Count() - 1 Do
		
		RowTableInventory = StructureAdditionalProperties.TableForRegisterRecords.TableInventory[n];
		
		StructureForSearch = New Structure;
		StructureForSearch.Insert("Company",			RowTableInventory.Company);
		StructureForSearch.Insert("StructuralUnit",		RowTableInventory.StructuralUnit);
		StructureForSearch.Insert("GLAccount",			RowTableInventory.GLAccount);
		StructureForSearch.Insert("Products",			RowTableInventory.Products);
		StructureForSearch.Insert("Characteristic",		RowTableInventory.Characteristic);
		StructureForSearch.Insert("Batch",				RowTableInventory.Batch);
		
		QuantityRequiredAvailableBalance = -RowTableInventory.Quantity;
		
		If QuantityRequiredAvailableBalance > 0 Then
			
			BalanceRowsArray = TableInventoryBalances.FindRows(StructureForSearch);
			
			QuantityBalance = 0;
			AmountBalance = 0;
			
			If BalanceRowsArray.Count() > 0 Then
				QuantityBalance	= BalanceRowsArray[0].QuantityBalance;
				AmountBalance	= BalanceRowsArray[0].AmountBalance;
			EndIf;
			
			If QuantityBalance > 0 AND QuantityBalance > QuantityRequiredAvailableBalance Then
				
				AmountToBeWrittenOff = Round(AmountBalance * QuantityRequiredAvailableBalance / QuantityBalance , 2, 1);
				
				BalanceRowsArray[0].QuantityBalance	= BalanceRowsArray[0].QuantityBalance - QuantityRequiredAvailableBalance;
				BalanceRowsArray[0].AmountBalance	= BalanceRowsArray[0].AmountBalance - AmountToBeWrittenOff;
				
			ElsIf QuantityBalance = QuantityRequiredAvailableBalance Then
				
				AmountToBeWrittenOff = AmountBalance;
				
				BalanceRowsArray[0].QuantityBalance = 0;
				BalanceRowsArray[0].AmountBalance = 0;
				
			Else
				AmountToBeWrittenOff = 0;
			EndIf;
			
			// Inventory.
			If Round((RowTableInventory.Amount + AmountToBeWrittenOff), 2, 1) <> 0 Then
				
				TableRowExpense = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
				FillPropertyValues(TableRowExpense, RowTableInventory);
				
				CalculatedAmount = TableRowExpense.Amount + AmountToBeWrittenOff;
				TableRowExpense.RecordType	= AccumulationRecordType.Expense;
				TableRowExpense.Amount		= CalculatedAmount;
				
				TableRowExpense.Quantity		= 0;
				TableRowExpense.SourceDocument	= DocumentRef;
				TableRowExpense.Return			= True;
				TableRowExpense.FixedCost		= True;
				
				// Income and expenses.
				RowIncomeAndExpenses = StructureAdditionalProperties.TableForRegisterRecords.TableIncomeAndExpenses.Add();
				FillPropertyValues(RowIncomeAndExpenses, RowTableInventory);
				
				RowIncomeAndExpenses.StructuralUnit	= Undefined;
				RowIncomeAndExpenses.SalesOrder		= Undefined;
				RowIncomeAndExpenses.BusinessLine	= Catalogs.LinesOfBusiness.Other;
				
				If TableRowExpense.Amount < 0 Then
					RowIncomeAndExpenses.GLAccount		= Catalogs.DefaultGLAccounts.GetDefaultGLAccount("Expenses");
					RowIncomeAndExpenses.AmountExpense	= TableRowExpense.Amount;
				Else
					RowIncomeAndExpenses.GLAccount		= Catalogs.DefaultGLAccounts.GetDefaultGLAccount("OtherIncome");
					RowIncomeAndExpenses.AmountIncome	= TableRowExpense.Amount;
				EndIf;
				
				RowIncomeAndExpenses.ContentOfAccountingRecord = NStr("en = 'Expenses accrued'");
				
				// Management.
				RowTableAccountingJournalEntries = TableAccountingJournalEntries.Add();
				FillPropertyValues(RowTableAccountingJournalEntries, RowTableInventory);
				
				If TableRowExpense.Amount < 0 Then
					RowTableAccountingJournalEntries.AccountDr	= Catalogs.DefaultGLAccounts.GetDefaultGLAccount("Expenses");
					RowTableAccountingJournalEntries.AccountCr	= RowTableInventory.AccountCr;
					RowTableAccountingJournalEntries.Amount		= TableRowExpense.Amount;
				Else
					RowTableAccountingJournalEntries.AccountDr	= RowTableInventory.AccountCr;
					RowTableAccountingJournalEntries.AccountCr	= Catalogs.DefaultGLAccounts.GetDefaultGLAccount("OtherIncome");
					RowTableAccountingJournalEntries.Amount		= TableRowExpense.Amount;
				EndIf;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure GenerateTableInventoryInWarehouses(DocumentRef, StructureAdditionalProperties)
	
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
	|	TemporaryTableProducts AS TableInventoryInWarehouses
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
	|	TemporaryTableProducts AS TemporaryTableInventory
	|		INNER JOIN TemporaryTableSerialNumbers AS SerialNumbers
	|		ON TemporaryTableInventory.ConnectionKey = SerialNumbers.ConnectionKey";
	
	QueryResult = Query.Execute().Unload();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbersInWarranty", QueryResult);
	If StructureAdditionalProperties.AccountingPolicy.SerialNumbersBalance Then
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbersBalance", QueryResult);
	Else
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbersBalance", New ValueTable);
	EndIf;
	
EndProcedure

Procedure GenerateTableGoodsShippedNotInvoiced(DocumentRef, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	MIN(TableProducts.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TableProducts.Period AS Period,
	|	&Ref AS GoodsIssue,
	|	TableProducts.Company AS Company,
	|	TableProducts.Counterparty AS Counterparty,
	|	TableProducts.Contract AS Contract,
	|	TableProducts.Products AS Products,
	|	TableProducts.Characteristic AS Characteristic,
	|	TableProducts.Batch AS Batch,
	|	TableProducts.Order AS SalesOrder,
	|	SUM(TableProducts.Quantity) AS Quantity
	|FROM
	|	TemporaryTableProducts AS TableProducts
	|WHERE
	|	TableProducts.OperationType = VALUE(Enum.OperationTypesGoodsIssue.SaleToCustomer)
	|	AND TableProducts.SalesInvoice = VALUE(Document.SalesInvoice.EmptyRef)
	|
	|GROUP BY
	|	TableProducts.Period,
	|	TableProducts.Company,
	|	TableProducts.Counterparty,
	|	TableProducts.Contract,
	|	TableProducts.Products,
	|	TableProducts.Characteristic,
	|	TableProducts.Batch,
	|	TableProducts.Order";
	
	Query.SetParameter("Ref", DocumentRef);
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableGoodsShippedNotInvoiced", QueryResult.Unload());
	
EndProcedure

Procedure GenerateTableGoodsInvoicedNotShipped(DocumentRef, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
#Region GenerateTableGoodsInvoicedNotShippedQueryText
	
	Query.Text =
	"SELECT
	|	TableProducts.SalesInvoice AS SalesInvoice,
	|	TableProducts.Company AS Company,
	|	TableProducts.Counterparty AS Counterparty,
	|	TableProducts.Contract AS Contract,
	|	TableProducts.Order AS SalesOrder,
	|	TableProducts.Products AS Products,
	|	TableProducts.Characteristic AS Characteristic,
	|	TableProducts.Batch AS Batch,
	|	SUM(TableProducts.Quantity) AS Quantity,
	|	TableProducts.Period AS Period,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableProducts.BusinessLineSales AS BusinessLine,
	|	TableProducts.AccountStatementSales AS GLAccountSales,
	|	TableProducts.GLAccountCost AS GLAccountCost,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	TableProducts.AccountStatementSales AS AccountCr,
	|	TableProducts.AccountStatementDeferredSales AS AccountDr,
	|	TableProducts.SalesRep AS SalesRep
	|FROM
	|	TemporaryTableProducts AS TableProducts
	|WHERE
	|	TableProducts.OperationType = VALUE(Enum.OperationTypesGoodsIssue.SaleToCustomer)
	|	AND TableProducts.SalesInvoice <> VALUE(Document.SalesInvoice.EmptyRef)
	|	AND TableProducts.Quantity > 0
	|
	|GROUP BY
	|	TableProducts.SalesInvoice,
	|	TableProducts.Company,
	|	TableProducts.Counterparty,
	|	TableProducts.Contract,
	|	TableProducts.Order,
	|	TableProducts.Products,
	|	TableProducts.Characteristic,
	|	TableProducts.Batch,
	|	TableProducts.Period,
	|	TableProducts.BusinessLineSales,
	|	TableProducts.AccountStatementSales,
	|	TableProducts.GLAccountCost,
	|	TableProducts.AccountStatementDeferredSales,
	|	TableProducts.AccountStatementSales,
	|	TableProducts.SalesRep";
	
#EndRegion

	Query.SetParameter("Ref", DocumentRef);
	QueryResult = Query.Execute();
	
	If QueryResult.IsEmpty() Then
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableGoodsInvoicedNotShipped", New ValueTable);
		Return;
	EndIf;
	
	TableInventory = QueryResult.Unload();
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.GoodsInvoicedNotShipped");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;
	
	StructureForSearch = New Structure;
	
	For i = 1 To 8 Do
		ColumnQueryResult = QueryResult.Columns[i - 1];
		LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
		StructureForSearch.Insert(ColumnQueryResult.Name);
	EndDo;
	Block.Lock();
	
#Region GenerateTableGoodsInvoicedNotShippedBalancesQueryText
	
	Query.Text =
	"SELECT
	|	UNDEFINED AS Period,
	|	UNDEFINED AS RecordType,
	|	Balances.SalesInvoice AS SalesInvoice,
	|	Balances.Company AS Company,
	|	Balances.Counterparty AS Counterparty,
	|	Balances.Contract AS Contract,
	|	Balances.SalesOrder AS SalesOrder,
	|	Balances.Products AS Products,
	|	Balances.Characteristic AS Characteristic,
	|	Balances.Batch AS Batch,
	|	Balances.VATRate AS VATRate,
	|	Balances.Department AS Department,
	|	Balances.Responsible AS Responsible,
	|	SUM(Balances.Quantity) AS Quantity,
	|	SUM(Balances.Amount) AS Amount,
	|	SUM(Balances.VATAmount) AS VATAmount
	|FROM
	|	(SELECT
	|		Balances.SalesInvoice AS SalesInvoice,
	|		Balances.Company AS Company,
	|		Balances.Counterparty AS Counterparty,
	|		Balances.Contract AS Contract,
	|		Balances.SalesOrder AS SalesOrder,
	|		Balances.Products AS Products,
	|		Balances.Characteristic AS Characteristic,
	|		Balances.Batch AS Batch,
	|		Balances.VATRate AS VATRate,
	|		Balances.Department AS Department,
	|		Balances.Responsible AS Responsible,
	|		Balances.QuantityBalance AS Quantity,
	|		Balances.AmountBalance AS Amount,
	|		Balances.VATAmountBalance AS VATAmount
	|	FROM
	|		AccumulationRegister.GoodsInvoicedNotShipped.Balance(
	|				&ControlTime,
	|				(SalesInvoice, Company, Counterparty, Contract, SalesOrder, Products, Characteristic, Batch) IN
	|					(SELECT
	|						TableProducts.SalesInvoice AS SalesInvoice,
	|						TableProducts.Company AS Company,
	|						TableProducts.Counterparty AS Counterparty,
	|						TableProducts.Contract AS Contract,
	|						TableProducts.Order AS SalesOrder,
	|						TableProducts.Products AS Products,
	|						TableProducts.Characteristic AS Characteristic,
	|						TableProducts.Batch AS Batch
	|					FROM
	|						TemporaryTableProducts AS TableProducts)) AS Balances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRecords.SalesInvoice,
	|		DocumentRecords.Company,
	|		DocumentRecords.Counterparty,
	|		DocumentRecords.Contract,
	|		DocumentRecords.SalesOrder,
	|		DocumentRecords.Products,
	|		DocumentRecords.Characteristic,
	|		DocumentRecords.Batch,
	|		DocumentRecords.VATRate,
	|		DocumentRecords.Department,
	|		DocumentRecords.Responsible,
	|		CASE
	|			WHEN DocumentRecords.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN DocumentRecords.Quantity
	|			ELSE DocumentRecords.Quantity
	|		END,
	|		CASE
	|			WHEN DocumentRecords.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN DocumentRecords.Amount
	|			ELSE DocumentRecords.Amount
	|		END,
	|		CASE
	|			WHEN DocumentRecords.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN DocumentRecords.VATAmount
	|			ELSE DocumentRecords.VATAmount
	|		END
	|	FROM
	|		AccumulationRegister.GoodsInvoicedNotShipped AS DocumentRecords
	|	WHERE
	|		DocumentRecords.Recorder = &Ref
	|		AND DocumentRecords.Period <= &ControlPeriod) AS Balances
	|
	|GROUP BY
	|	Balances.SalesInvoice,
	|	Balances.Company,
	|	Balances.Counterparty,
	|	Balances.Contract,
	|	Balances.SalesOrder,
	|	Balances.Products,
	|	Balances.Characteristic,
	|	Balances.Batch,
	|	Balances.VATRate,
	|	Balances.Department,
	|	Balances.Responsible";
	
#EndRegion
	
	Query.SetParameter("Ref", DocumentRef);
	Query.SetParameter("ControlTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.PointInTime.Date);
	
	QueryResult = Query.Execute();
	
	TableBalances = QueryResult.Unload();
	TableBalances.Indexes.Add("SalesInvoice, Company, Counterparty, Contract, SalesOrder, Products, Characteristic, Batch");
	
	TemporaryTableInventory = TableBalances.CopyColumns();
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();
	
	TablesForRegisterRecords = StructureAdditionalProperties.TableForRegisterRecords;
	
	TableAccountingJournalEntries = TablesForRegisterRecords.TableAccountingJournalEntries;
	TableIncomeAndExpenses = TablesForRegisterRecords.TableIncomeAndExpenses;
	TableSales = TablesForRegisterRecords.TableSales;
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();
	ContentTextIncome = NStr("en = 'Revenue'", MainLanguageCode);
	ContentTextGost = NStr("en = 'Cost of goods sold'", MainLanguageCode);
	
	TableInventoryBalances = TablesForRegisterRecords.TableInventory.Copy();
	StructureForSearchInventoryBalances = New Structure("Company, Products, Characteristic, Batch");
	
	For Each TableInventoryRow In TableInventory Do
		
		FillPropertyValues(StructureForSearch, TableInventoryRow);
		
		BalanceRowsArray = TableBalances.FindRows(StructureForSearch);
		
		QuantityToBeWrittenOff = TableInventoryRow.Quantity;
		
		For Each TableBalancesRow In BalanceRowsArray Do
			
			If TableBalancesRow.Quantity > 0 Then
				
				NewRow = TemporaryTableInventory.Add();
				FillPropertyValues(NewRow, TableBalancesRow, , "Quantity, Amount, VATAmount");
				FillPropertyValues(NewRow, TableInventoryRow, "Period, RecordType");
				
				NewRow.Quantity = Min(TableBalancesRow.Quantity, QuantityToBeWrittenOff);
				
				If NewRow.Quantity < TableBalancesRow.Quantity Then
					
					NewRow.Amount = Round(TableBalancesRow.Amount * NewRow.Quantity / TableBalancesRow.Quantity, 2, 1);
					NewRow.VATAmount = Round(TableBalancesRow.VATAmount * NewRow.Quantity / TableBalancesRow.Quantity, 2, 1);
					QuantityToBeWrittenOff = 0;
					
				Else
					
					NewRow.Amount = TableBalancesRow.Amount;
					NewRow.VATAmount = TableBalancesRow.VATAmount;
					QuantityToBeWrittenOff = QuantityToBeWrittenOff - NewRow.Quantity;
					
				EndIf;
				
				CostAmount = 0;
				CostQuantity = NewRow.Quantity;
				
				FillPropertyValues(StructureForSearchInventoryBalances, NewRow);
				InventoryBalancesRows = TableInventoryBalances.FindRows(StructureForSearchInventoryBalances);
				For Each InventoryBalancesRow In InventoryBalancesRows Do
					
					If InventoryBalancesRow.Quantity > 0 Then
						CurrentCostQuantity = Min(CostQuantity, InventoryBalancesRow.Quantity);
						If CurrentCostQuantity < InventoryBalancesRow.Quantity Then
							CostAmount = CostAmount + Round(InventoryBalancesRow.Amount * CurrentCostQuantity / InventoryBalancesRow.Quantity, 2, 1);
							CostQuantity = 0;
						Else
							CostAmount = CostAmount + InventoryBalancesRow.Amount;
							CostQuantity = CostQuantity - CurrentCostQuantity;
						EndIf;
					EndIf;
					If CostQuantity = 0 Then
						Break;
					EndIf;
					
				EndDo;
				
				IncomeAndExpensesRow = TableIncomeAndExpenses.Add();
				FillPropertyValues(IncomeAndExpensesRow, TableInventoryRow);
				IncomeAndExpensesRow.Active = True;
				IncomeAndExpensesRow.StructuralUnit = NewRow.Department;
				IncomeAndExpensesRow.SalesOrder = ?(ValueIsFilled(TableInventoryRow.SalesOrder), TableInventoryRow.SalesOrder, Undefined);
				IncomeAndExpensesRow.GLAccount = TableInventoryRow.GLAccountSales;
				IncomeAndExpensesRow.AmountIncome = NewRow.Amount;
				IncomeAndExpensesRow.ContentOfAccountingRecord = ContentTextIncome;
				
				SalesRow = TableSales.Add();
				FillPropertyValues(SalesRow, NewRow);
				SalesRow.Active = True;
				SalesRow.Document = NewRow.SalesInvoice;
				SalesRow.SalesRep = TableInventoryRow.SalesRep;
				
				TableAccountingRow = TableAccountingJournalEntries.Add();
				FillPropertyValues(TableAccountingRow, TableInventoryRow);
				TableAccountingRow.Amount = NewRow.Amount;
				TableAccountingRow.Content = ContentTextIncome;
				
				If CostAmount <> 0 Then
					
					IncomeAndExpensesRow = TableIncomeAndExpenses.Add();
					FillPropertyValues(IncomeAndExpensesRow, TableInventoryRow);
					IncomeAndExpensesRow.Active = True;
					IncomeAndExpensesRow.StructuralUnit = NewRow.Department;
					IncomeAndExpensesRow.SalesOrder = ?(ValueIsFilled(TableInventoryRow.SalesOrder), TableInventoryRow.SalesOrder, Undefined);
					IncomeAndExpensesRow.GLAccount = TableInventoryRow.GLAccountCost;
					IncomeAndExpensesRow.AmountExpense = CostAmount;
					IncomeAndExpensesRow.ContentOfAccountingRecord = ContentTextGost;
					
					SalesRow = TableSales.Add();
					FillPropertyValues(SalesRow, NewRow);
					SalesRow.SalesRep = TableInventoryRow.SalesRep;
					SalesRow.Active = True;
					SalesRow.Document = NewRow.SalesInvoice;
					SalesRow.Quantity = 0;
					SalesRow.Amount = 0;
					SalesRow.VATAmount = 0;
					SalesRow.Cost = CostAmount;
					
				EndIf;
				
			EndIf;
			
			If QuantityToBeWrittenOff = 0 Then
				Break;
			EndIf;
			
		EndDo;
		
		If QuantityToBeWrittenOff > 0 Then
			
			NewRow = TemporaryTableInventory.Add();
			FillPropertyValues(NewRow, TableInventoryRow, , "Quantity");
			NewRow.Quantity = QuantityToBeWrittenOff;
			
		EndIf;
		
	EndDo;
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableGoodsInvoicedNotShipped", TemporaryTableInventory);
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpenses", TableIncomeAndExpenses);
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSales", TableSales);
	
EndProcedure

Procedure GenerateTableStockReceivedFromThirdParties(DocumentRef, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	1 AS Ordering,
	|	MIN(TableStockReceivedFromThirdParties.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableStockReceivedFromThirdParties.Period AS Period,
	|	TableStockReceivedFromThirdParties.Company AS Company,
	|	TableStockReceivedFromThirdParties.Products AS Products,
	|	TableStockReceivedFromThirdParties.Characteristic AS Characteristic,
	|	TableStockReceivedFromThirdParties.Batch AS Batch,
	|	TableStockReceivedFromThirdParties.Counterparty AS Counterparty,
	|	TableStockReceivedFromThirdParties.Contract AS Contract,
	|	CASE
	|		WHEN TableStockReceivedFromThirdParties.Order REFS Document.PurchaseOrder
	|				AND TableStockReceivedFromThirdParties.Order <> VALUE(Document.PurchaseOrder.EmptyRef)
	|			THEN TableStockReceivedFromThirdParties.Order
	|		ELSE UNDEFINED
	|	END AS Order,
	|	TableStockReceivedFromThirdParties.GLAccount AS GLAccount,
	|	SUM(TableStockReceivedFromThirdParties.Quantity) AS Quantity,
	|	CAST(&InventoryReception AS STRING(100)) AS ContentOfAccountingRecord
	|FROM
	|	TemporaryTableProducts AS TableStockReceivedFromThirdParties
	|WHERE
	|	TableStockReceivedFromThirdParties.OperationType = VALUE(Enum.OperationTypesGoodsIssue.ReturnToAThirdParty)
	|
	|GROUP BY
	|	TableStockReceivedFromThirdParties.Period,
	|	TableStockReceivedFromThirdParties.Company,
	|	TableStockReceivedFromThirdParties.Products,
	|	TableStockReceivedFromThirdParties.Characteristic,
	|	TableStockReceivedFromThirdParties.Batch,
	|	TableStockReceivedFromThirdParties.Counterparty,
	|	TableStockReceivedFromThirdParties.Contract,
	|	TableStockReceivedFromThirdParties.Order,
	|	TableStockReceivedFromThirdParties.GLAccount
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	MIN(TableStockReceivedFromThirdParties.LineNumber),
	|	VALUE(AccumulationRecordType.Receipt),
	|	TableStockReceivedFromThirdParties.Period,
	|	TableStockReceivedFromThirdParties.Company,
	|	TableStockReceivedFromThirdParties.Products,
	|	TableStockReceivedFromThirdParties.Characteristic,
	|	TableStockReceivedFromThirdParties.Batch,
	|	UNDEFINED,
	|	UNDEFINED,
	|	TableStockReceivedFromThirdParties.Order,
	|	TableStockReceivedFromThirdParties.GLAccountVendorSettlements,
	|	SUM(TableStockReceivedFromThirdParties.Quantity),
	|	CAST(&InventoryIncreaseProductsOnCommission AS STRING(100))
	|FROM
	|	TemporaryTableProducts AS TableStockReceivedFromThirdParties
	|WHERE
	|	TableStockReceivedFromThirdParties.ProductsOnCommission
	|
	|GROUP BY
	|	TableStockReceivedFromThirdParties.Period,
	|	TableStockReceivedFromThirdParties.Company,
	|	TableStockReceivedFromThirdParties.Products,
	|	TableStockReceivedFromThirdParties.Characteristic,
	|	TableStockReceivedFromThirdParties.Batch,
	|	TableStockReceivedFromThirdParties.Counterparty,
	|	TableStockReceivedFromThirdParties.Contract,
	|	TableStockReceivedFromThirdParties.Order,
	|	TableStockReceivedFromThirdParties.GLAccountVendorSettlements,
	|	TableStockReceivedFromThirdParties.GLAccount";
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();
	
	Query.SetParameter("InventoryReception", "");
	Query.SetParameter("InventoryIncreaseProductsOnCommission", NStr("en = 'Inventory increase'", MainLanguageCode));
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableStockReceivedFromThirdParties", QueryResult.Unload());
	
EndProcedure

Procedure GenerateTableStockTransferredToThirdParties(DocumentRef, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	MIN(TableStockTransferredToThirdParties.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TableStockTransferredToThirdParties.Period AS Period,
	|	TableStockTransferredToThirdParties.Company AS Company,
	|	TableStockTransferredToThirdParties.Products AS Products,
	|	TableStockTransferredToThirdParties.Characteristic AS Characteristic,
	|	TableStockTransferredToThirdParties.Batch AS Batch,
	|	TableStockTransferredToThirdParties.Counterparty AS Counterparty,
	|	TableStockTransferredToThirdParties.Contract AS Contract,
	|	CASE
	|		WHEN TableStockTransferredToThirdParties.Order REFS Document.PurchaseOrder
	|				AND TableStockTransferredToThirdParties.Order <> VALUE(Document.PurchaseOrder.EmptyRef)
	|			THEN TableStockTransferredToThirdParties.Order
	|		ELSE UNDEFINED
	|	END AS Order,
	|	SUM(TableStockTransferredToThirdParties.Quantity) AS Quantity
	|FROM
	|	TemporaryTableProducts AS TableStockTransferredToThirdParties
	|WHERE
	|	TableStockTransferredToThirdParties.OperationType = VALUE(Enum.OperationTypesGoodsIssue.TransferToAThirdParty)
	|
	|GROUP BY
	|	TableStockTransferredToThirdParties.Period,
	|	TableStockTransferredToThirdParties.Company,
	|	TableStockTransferredToThirdParties.Products,
	|	TableStockTransferredToThirdParties.Characteristic,
	|	TableStockTransferredToThirdParties.Batch,
	|	TableStockTransferredToThirdParties.Counterparty,
	|	TableStockTransferredToThirdParties.Contract,
	|	TableStockTransferredToThirdParties.Order";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableStockTransferredToThirdParties", QueryResult.Unload());
	
EndProcedure

Procedure GenerateTablePurchaseOrders(DocumentRef, StructureAdditionalProperties)
	
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
	|	-SUM(TablePurchaseOrders.Quantity) AS Quantity
	|FROM
	|	TemporaryTableProducts AS TablePurchaseOrders
	|WHERE
	|	TablePurchaseOrders.Order REFS Document.PurchaseOrder
	|	AND TablePurchaseOrders.Order <> VALUE(Document.PurchaseOrder.EmptyRef)
	|	AND TablePurchaseOrders.OperationType = VALUE(Enum.OperationTypesGoodsIssue.ReturnToAThirdParty)
	|
	|GROUP BY
	|	TablePurchaseOrders.Period,
	|	TablePurchaseOrders.Company,
	|	TablePurchaseOrders.Products,
	|	TablePurchaseOrders.Characteristic,
	|	TablePurchaseOrders.Order";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TablePurchaseOrders", QueryResult.Unload());
	
EndProcedure

Procedure GenerateTableInventoryDemand(DocumentRef, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	TableInventoryDemand.Period AS Period,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableInventoryDemand.Company AS Company,
	|	VALUE(Enum.InventoryMovementTypes.Shipment) AS MovementType,
	|	TableInventoryDemand.Products AS Products,
	|	TableInventoryDemand.Characteristic AS Characteristic,
	|	CASE
	|		WHEN UseInventoryReservation.Value
	|				AND TableInventoryDemand.Order REFS Document.PurchaseOrder
	|			THEN ISNULL(TableInventoryDemand.Order.SalesOrder, VALUE(Document.SalesOrder.EmptyRef))
	|		ELSE VALUE(Document.SalesOrder.EmptyRef)
	|	END AS SalesOrder,
	|	SUM(TableInventoryDemand.Quantity) AS Quantity
	|FROM
	|	TemporaryTableProducts AS TableInventoryDemand,
	|	Constant.UseInventoryReservation AS UseInventoryReservation
	|WHERE
	|	TableInventoryDemand.Order REFS Document.PurchaseOrder
	|	AND TableInventoryDemand.Order <> VALUE(Document.PurchaseOrder.EmptyRef)
	|	AND TableInventoryDemand.OperationType = VALUE(Enum.OperationTypesGoodsIssue.TransferToAThirdParty)
	|
	|GROUP BY
	|	TableInventoryDemand.Period,
	|	TableInventoryDemand.Company,
	|	TableInventoryDemand.Products,
	|	TableInventoryDemand.Characteristic,
	|	CASE
	|		WHEN UseInventoryReservation.Value
	|				AND TableInventoryDemand.Order REFS Document.PurchaseOrder
	|			THEN ISNULL(TableInventoryDemand.Order.SalesOrder, VALUE(Document.SalesOrder.EmptyRef))
	|		ELSE VALUE(Document.SalesOrder.EmptyRef)
	|	END";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryDemand", QueryResult.Unload());
	
EndProcedure

#EndRegion

#Region PrintInterface

Procedure Print(ObjectsArray, PrintParameters, PrintFormsCollection, PrintObjects, OutputParameters) Export
	
	Var Errors;
	
	If PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "DeliveryNote") Then
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection,
															"DeliveryNote",
															"Delivery note",
															DataProcessors.PrintDeliveryNote.PrintForm(ObjectsArray, PrintObjects, "DeliveryNote"));
	ElsIf PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "Requisition") Then
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection,
															"Requisition",
															NStr("en = 'Requisition'"),
															DataProcessors.PrintRequisition.PrintForm(ObjectsArray, PrintObjects, "Requisition"));
	EndIf;
	
	If Errors <> Undefined Then
		CommonUseClientServer.ShowErrorsToUser(Errors);
	EndIf;
	
	// parameters of sending printing forms by email
	DriveServer.FillSendingParameters(OutputParameters.SendingParameters, ObjectsArray, PrintFormsCollection);
	
EndProcedure

Procedure AddPrintCommands(PrintCommands) Export
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID							= "DeliveryNote";
	PrintCommand.Presentation				= NStr("en = 'Delivery note'");
	PrintCommand.CheckPostingBeforePrint	= False;
	PrintCommand.Order						= 1;
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID							= "Requisition";
	PrintCommand.Presentation				= NStr("en = 'Requisition'");
	PrintCommand.CheckPostingBeforePrint	= False;
	PrintCommand.Order						= 2;
	
EndProcedure

#EndRegion

#Region InfobaseUpdate

Procedure FillOperationType() Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	GoodsIssue.Ref AS Ref
	|FROM
	|	Document.GoodsIssue AS GoodsIssue
	|WHERE
	|	GoodsIssue.OperationType = VALUE(Enum.OperationTypesGoodsIssue.EmptyRef)";
	
	Selection = Query.Execute().Select();
	
	SaleToCustomer = Enums.OperationTypesGoodsIssue.SaleToCustomer;
	
	While Selection.Next() Do
		
		DocObj = Selection.Ref.GetObject();
		DocObj.OperationType = SaleToCustomer;
		DocObj.Write(DocumentWriteMode.Write);
		
	EndDo;
	
EndProcedure

Procedure FillNewGLAccounts() Export
	
	DocumentName = "GoodsIssue";
	
	Tables = New Array();
	
	TableDecription = New Structure("Name, Conditions", "Products", New Array());
	
	GLAccountFields = ChartsOfAccounts.PrimaryChartOfAccounts.GLAccountFields();
	GLAccountFields.Source = "Products.InventoryGLAccount";
	GLAccountFields.Receiver = "InventoryGLAccount";
	TableDecription.Conditions.Add(GLAccountFields);
	
	GLAccountFields = ChartsOfAccounts.PrimaryChartOfAccounts.GLAccountFields();
	GLAccountFields.Source = "&GoodsShippedNotInvoicedGLAccount";
	GLAccountFields.Receiver = "GoodsShippedNotInvoicedGLAccount";
	GLAccountFields.Parameter = Catalogs.DefaultGLAccounts.GetDefaultGLAccount("GoodsShippedNotInvoiced");
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
	GLAccountFields.Source = "Products.InventoryGLAccount";
	GLAccountFields.Receiver = "InventoryReceivedGLAccount";
	TableDecription.Conditions.Add(GLAccountFields);
	
	Tables.Add(TableDecription);
	
	ChartsOfAccounts.PrimaryChartOfAccounts.FillNewGLAccounts(DocumentName, Tables);
	
EndProcedure

#EndRegion

#EndIf