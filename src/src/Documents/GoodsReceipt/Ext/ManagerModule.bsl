#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ProgramInterface

Procedure FillByPurchaseOrders(DocumentData, FilterData, Products) Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	PurchaseOrder.Ref AS Ref,
	|	PurchaseOrder.Contract AS Contract,
	|	PurchaseOrder.PointInTime AS PointInTime
	|INTO TT_PurchaseOrders
	|FROM
	|	Document.PurchaseOrder AS PurchaseOrder
	|WHERE
	|	&PurchaseOrdersConditions
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	GoodsReceiptProducts.Order AS Order,
	|	GoodsReceiptProducts.Products AS Products,
	|	GoodsReceiptProducts.Characteristic AS Characteristic,
	|	GoodsReceiptProducts.Batch AS Batch,
	|	SUM(GoodsReceiptProducts.Quantity * ISNULL(UOM.Factor, 1)) AS BaseQuantity
	|INTO TT_AlreadyInvoiced
	|FROM
	|	TT_PurchaseOrders AS TT_PurchaseOrders
	|		INNER JOIN Document.GoodsReceipt.Products AS GoodsReceiptProducts
	|		ON (GoodsReceiptProducts.Order = TT_PurchaseOrders.Ref)
	|		INNER JOIN Document.GoodsReceipt AS GoodsReceiptDocument
	|		ON (GoodsReceiptProducts.Ref = GoodsReceiptDocument.Ref)
	|		INNER JOIN Catalog.Products AS ProductsCatalog
	|		ON (GoodsReceiptProducts.Products = ProductsCatalog.Ref)
	|		LEFT JOIN Catalog.UOM AS UOM
	|		ON (GoodsReceiptProducts.MeasurementUnit = UOM.Ref)
	|WHERE
	|	GoodsReceiptDocument.Posted
	|	AND GoodsReceiptProducts.Ref <> &Ref
	|	AND ProductsCatalog.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
	|
	|GROUP BY
	|	GoodsReceiptProducts.Batch,
	|	GoodsReceiptProducts.Order,
	|	GoodsReceiptProducts.Products,
	|	GoodsReceiptProducts.Characteristic
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	OrdersBalance.PurchaseOrder AS PurchaseOrder,
	|	OrdersBalance.Products AS Products,
	|	OrdersBalance.Characteristic AS Characteristic,
	|	SUM(OrdersBalance.QuantityBalance) AS QuantityBalance
	|INTO TT_OrdersBalances
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
	|					(SELECT
	|						TT_PurchaseOrders.Ref
	|					FROM
	|						TT_PurchaseOrders)) AS OrdersBalance
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsPurchaseOrders.PurchaseOrder,
	|		DocumentRegisterRecordsPurchaseOrders.Products,
	|		DocumentRegisterRecordsPurchaseOrders.Characteristic,
	|		CASE
	|			WHEN DocumentRegisterRecordsPurchaseOrders.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN ISNULL(DocumentRegisterRecordsPurchaseOrders.Quantity, 0)
	|			ELSE -ISNULL(DocumentRegisterRecordsPurchaseOrders.Quantity, 0)
	|		END
	|	FROM
	|		AccumulationRegister.PurchaseOrders AS DocumentRegisterRecordsPurchaseOrders
	|	WHERE
	|		DocumentRegisterRecordsPurchaseOrders.Recorder = &Ref) AS OrdersBalance
	|		INNER JOIN Catalog.Products AS ProductsCatalog
	|		ON OrdersBalance.Products = ProductsCatalog.Ref
	|WHERE
	|	ProductsCatalog.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
	|
	|GROUP BY
	|	OrdersBalance.PurchaseOrder,
	|	OrdersBalance.Products,
	|	OrdersBalance.Characteristic
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	PurchaseOrderInventory.LineNumber AS LineNumber,
	|	PurchaseOrderInventory.Products AS Products,
	|	PurchaseOrderInventory.Characteristic AS Characteristic,
	|	PurchaseOrderInventory.Quantity AS Quantity,
	|	PurchaseOrderInventory.MeasurementUnit AS MeasurementUnit,
	|	ISNULL(UOM.Factor, 1) AS Factor,
	|	PurchaseOrderInventory.Price AS Price,
	|	PurchaseOrderInventory.Amount AS Amount,
	|	PurchaseOrderInventory.VATRate AS VATRate,
	|	PurchaseOrderInventory.VATAmount AS VATAmount,
	|	PurchaseOrderInventory.Total AS Total,
	|	PurchaseOrderInventory.Ref AS Order,
	|	PurchaseOrderInventory.Content AS Content,
	|	TT_PurchaseOrders.PointInTime AS PointInTime,
	|	TT_PurchaseOrders.Contract AS Contract
	|INTO TT_Products
	|FROM
	|	Document.PurchaseOrder.Inventory AS PurchaseOrderInventory
	|		INNER JOIN TT_PurchaseOrders AS TT_PurchaseOrders
	|		ON PurchaseOrderInventory.Ref = TT_PurchaseOrders.Ref
	|		INNER JOIN Catalog.Products AS ProductsCatalog
	|		ON PurchaseOrderInventory.Products = ProductsCatalog.Ref
	|		LEFT JOIN Catalog.UOM AS UOM
	|		ON PurchaseOrderInventory.MeasurementUnit = UOM.Ref
	|WHERE
	|	ProductsCatalog.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_Products.LineNumber AS LineNumber,
	|	TT_Products.Products AS Products,
	|	TT_Products.Characteristic AS Characteristic,
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
	|			AND TT_Products.Order = TT_ProductsCumulative.Order
	|			AND TT_Products.LineNumber >= TT_ProductsCumulative.LineNumber
	|
	|GROUP BY
	|	TT_Products.LineNumber,
	|	TT_Products.Products,
	|	TT_Products.Characteristic,
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
	|	TT_ProductsCumulative.Order AS Order,
	|	TT_ProductsCumulative.Factor AS Factor,
	|	CASE
	|		WHEN TT_AlreadyInvoiced.BaseQuantity > TT_ProductsCumulative.BaseQuantityCumulative - TT_ProductsCumulative.BaseQuantity
	|			THEN TT_ProductsCumulative.BaseQuantityCumulative - TT_AlreadyInvoiced.BaseQuantity
	|		ELSE TT_ProductsCumulative.BaseQuantity
	|	END AS BaseQuantity
	|INTO TT_ProductsNotYetInvoiced
	|FROM
	|	TT_ProductsCumulative AS TT_ProductsCumulative
	|		LEFT JOIN TT_AlreadyInvoiced AS TT_AlreadyInvoiced
	|		ON TT_ProductsCumulative.Products = TT_AlreadyInvoiced.Products
	|			AND TT_ProductsCumulative.Characteristic = TT_AlreadyInvoiced.Characteristic
	|			AND TT_ProductsCumulative.Order = TT_AlreadyInvoiced.Order
	|WHERE
	|	ISNULL(TT_AlreadyInvoiced.BaseQuantity, 0) < TT_ProductsCumulative.BaseQuantityCumulative
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_ProductsNotYetInvoiced.LineNumber AS LineNumber,
	|	TT_ProductsNotYetInvoiced.Products AS Products,
	|	TT_ProductsNotYetInvoiced.Characteristic AS Characteristic,
	|	TT_ProductsNotYetInvoiced.Order AS Order,
	|	TT_ProductsNotYetInvoiced.Factor AS Factor,
	|	TT_ProductsNotYetInvoiced.BaseQuantity AS BaseQuantity,
	|	SUM(TT_ProductsNotYetInvoicedCumulative.BaseQuantity) AS BaseQuantityCumulative
	|INTO TT_ProductsNotYetInvoicedCumulative
	|FROM
	|	TT_ProductsNotYetInvoiced AS TT_ProductsNotYetInvoiced
	|		INNER JOIN TT_ProductsNotYetInvoiced AS TT_ProductsNotYetInvoicedCumulative
	|		ON TT_ProductsNotYetInvoiced.Products = TT_ProductsNotYetInvoicedCumulative.Products
	|			AND TT_ProductsNotYetInvoiced.Characteristic = TT_ProductsNotYetInvoicedCumulative.Characteristic
	|			AND TT_ProductsNotYetInvoiced.Order = TT_ProductsNotYetInvoicedCumulative.Order
	|			AND TT_ProductsNotYetInvoiced.LineNumber >= TT_ProductsNotYetInvoicedCumulative.LineNumber
	|
	|GROUP BY
	|	TT_ProductsNotYetInvoiced.LineNumber,
	|	TT_ProductsNotYetInvoiced.Products,
	|	TT_ProductsNotYetInvoiced.Characteristic,
	|	TT_ProductsNotYetInvoiced.Order,
	|	TT_ProductsNotYetInvoiced.Factor,
	|	TT_ProductsNotYetInvoiced.BaseQuantity
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_ProductsNotYetInvoicedCumulative.LineNumber AS LineNumber,
	|	TT_ProductsNotYetInvoicedCumulative.Products AS Products,
	|	TT_ProductsNotYetInvoicedCumulative.Characteristic AS Characteristic,
	|	TT_ProductsNotYetInvoicedCumulative.Order AS Order,
	|	TT_ProductsNotYetInvoicedCumulative.Factor AS Factor,
	|	CASE
	|		WHEN TT_OrdersBalances.QuantityBalance > TT_ProductsNotYetInvoicedCumulative.BaseQuantityCumulative
	|			THEN TT_ProductsNotYetInvoicedCumulative.BaseQuantity
	|		WHEN TT_OrdersBalances.QuantityBalance > TT_ProductsNotYetInvoicedCumulative.BaseQuantityCumulative - TT_ProductsNotYetInvoicedCumulative.BaseQuantity
	|			THEN TT_OrdersBalances.QuantityBalance - (TT_ProductsNotYetInvoicedCumulative.BaseQuantityCumulative - TT_ProductsNotYetInvoicedCumulative.BaseQuantity)
	|	END AS BaseQuantity
	|INTO TT_ProductsToBeInvoiced
	|FROM
	|	TT_ProductsNotYetInvoicedCumulative AS TT_ProductsNotYetInvoicedCumulative
	|		INNER JOIN TT_OrdersBalances AS TT_OrdersBalances
	|		ON TT_ProductsNotYetInvoicedCumulative.Products = TT_OrdersBalances.Products
	|			AND TT_ProductsNotYetInvoicedCumulative.Characteristic = TT_OrdersBalances.Characteristic
	|			AND TT_ProductsNotYetInvoicedCumulative.Order = TT_OrdersBalances.PurchaseOrder
	|WHERE
	|	TT_OrdersBalances.QuantityBalance > TT_ProductsNotYetInvoicedCumulative.BaseQuantityCumulative - TT_ProductsNotYetInvoicedCumulative.BaseQuantity
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_Products.LineNumber AS LineNumber,
	|	TT_Products.Products AS Products,
	|	TT_Products.Characteristic AS Characteristic,
	|	CASE
	|		WHEN (CAST(TT_Products.Quantity * TT_Products.Factor AS NUMBER(15, 3))) = TT_ProductsToBeInvoiced.BaseQuantity
	|			THEN TT_Products.Quantity
	|		ELSE CAST(TT_ProductsToBeInvoiced.BaseQuantity / TT_Products.Factor AS NUMBER(15, 3))
	|	END AS Quantity,
	|	TT_Products.MeasurementUnit AS MeasurementUnit,
	|	TT_Products.Factor AS Factor,
	|	TT_Products.Order AS Order,
	|	TT_Products.PointInTime AS PointInTime,
	|	TT_Products.Contract AS Contract
	|FROM
	|	TT_Products AS TT_Products
	|		INNER JOIN TT_ProductsToBeInvoiced AS TT_ProductsToBeInvoiced
	|		ON TT_Products.LineNumber = TT_ProductsToBeInvoiced.LineNumber
	|			AND TT_Products.Order = TT_ProductsToBeInvoiced.Order
	|
	|ORDER BY
	|	PointInTime,
	|	LineNumber";
	
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
	
	Query.SetParameter("Ref", DocumentData.Ref);
	Query.SetParameter("Company", DriveServer.GetCompany(DocumentData.Company));
	Query.SetParameter("StructuralUnit", DocumentData.StructuralUnit);
	
	Products.Load(Query.Execute().Unload());
	
EndProcedure

Procedure InitializeDocumentData(DocumentRefGoodsReceipt, StructureAdditionalProperties) Export
	
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
	|INTO GoodsReceiptHeader
	|FROM
	|	Document.GoodsReceipt AS Header
	|WHERE
	|	Header.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	GoodsReceiptProducts.LineNumber AS LineNumber,
	|	GoodsReceiptProducts.Ref AS Document,
	|	GoodsReceiptHeader.Responsible AS Responsible,
	|	GoodsReceiptHeader.Counterparty AS Counterparty,
	|	CASE
	|		WHEN GoodsReceiptHeader.Contract <> VALUE(Catalog.CounterpartyContracts.EmptyRef)
	|			THEN GoodsReceiptHeader.Contract
	|		ELSE GoodsReceiptProducts.Contract
	|	END AS Contract,
	|	GoodsReceiptHeader.Date AS Period,
	|	&Company AS Company,
	|	GoodsReceiptHeader.StructuralUnit AS StructuralUnit,
	|	GoodsReceiptHeader.Department AS Department,
	|	GoodsReceiptHeader.Cell AS Cell,
	|	CASE
	|		WHEN GoodsReceiptHeader.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.ReceiptFromAThirdParty)
	|			THEN GoodsReceiptProducts.InventoryReceivedGLAccount
	|		ELSE GoodsReceiptProducts.InventoryGLAccount
	|	END AS GLAccount,
	|	GoodsReceiptProducts.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN GoodsReceiptProducts.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseBatches
	|			THEN GoodsReceiptProducts.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS Batch,
	|	CASE
	|		WHEN GoodsReceiptHeader.Order <> UNDEFINED
	|				AND GoodsReceiptHeader.Order <> VALUE(Document.PurchaseOrder.EmptyRef)
	|			THEN GoodsReceiptHeader.Order
	|		WHEN GoodsReceiptProducts.Order <> VALUE(Document.PurchaseOrder.EmptyRef)
	|			THEN GoodsReceiptProducts.Order
	|		ELSE VALUE(Document.PurchaseOrder.EmptyRef)
	|	END AS Order,
	|	CASE
	|		WHEN VALUETYPE(GoodsReceiptProducts.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN GoodsReceiptProducts.Quantity
	|		ELSE GoodsReceiptProducts.Quantity * GoodsReceiptProducts.MeasurementUnit.Factor
	|	END AS Quantity,
	|	GoodsReceiptProducts.ConnectionKey AS ConnectionKey,
	|	GoodsReceiptHeader.OperationType AS OperationType,
	|	CASE
	|		WHEN GoodsReceiptHeader.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.ReturnFromAThirdParty)
	|			THEN &Company
	|		ELSE UNDEFINED
	|	END AS CorrOrganization,
	|	CASE
	|		WHEN GoodsReceiptHeader.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.ReturnFromAThirdParty)
	|			THEN GoodsReceiptHeader.Counterparty
	|		ELSE UNDEFINED
	|	END AS StructuralUnitCorr,
	|	CASE
	|		WHEN GoodsReceiptHeader.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.ReturnFromAThirdParty)
	|			THEN GoodsReceiptProducts.InventoryTransferredGLAccount
	|		ELSE UNDEFINED
	|	END AS CorrGLAccount,
	|	CASE
	|		WHEN GoodsReceiptHeader.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.ReturnFromAThirdParty)
	|			THEN GoodsReceiptProducts.Products
	|		ELSE UNDEFINED
	|	END AS ProductsCorr,
	|	CASE
	|		WHEN GoodsReceiptHeader.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.ReturnFromAThirdParty)
	|			THEN CASE
	|					WHEN &UseCharacteristics
	|						THEN GoodsReceiptProducts.Characteristic
	|					ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|				END
	|		ELSE UNDEFINED
	|	END AS CharacteristicCorr,
	|	CASE
	|		WHEN GoodsReceiptHeader.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.ReturnFromAThirdParty)
	|			THEN CASE
	|					WHEN &UseBatches
	|						THEN GoodsReceiptProducts.Batch
	|					ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|				END
	|		ELSE UNDEFINED
	|	END AS BatchCorr,
	|	CASE
	|		WHEN GoodsReceiptHeader.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.ReturnFromAThirdParty)
	|			THEN CASE
	|					WHEN GoodsReceiptHeader.Order REFS Document.SalesOrder
	|							AND GoodsReceiptHeader.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|						THEN GoodsReceiptHeader.Order
	|					WHEN GoodsReceiptHeader.Order REFS Document.PurchaseOrder
	|							AND GoodsReceiptHeader.Order <> VALUE(Document.PurchaseOrder.EmptyRef)
	|						THEN GoodsReceiptHeader.Order
	|					ELSE UNDEFINED
	|				END
	|		ELSE UNDEFINED
	|	END AS CorrOrder
	|INTO TemporaryTableProducts
	|FROM
	|	GoodsReceiptHeader AS GoodsReceiptHeader
	|		INNER JOIN Document.GoodsReceipt.Products AS GoodsReceiptProducts
	|		ON GoodsReceiptHeader.Ref = GoodsReceiptProducts.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	GoodsReceiptSerialNumbers.ConnectionKey AS ConnectionKey,
	|	GoodsReceiptSerialNumbers.SerialNumber AS SerialNumber
	|INTO TemporaryTableSerialNumbers
	|FROM
	|	Document.GoodsReceipt.SerialNumbers AS GoodsReceiptSerialNumbers
	|WHERE
	|	GoodsReceiptSerialNumbers.Ref = &Ref
	|	AND &UseSerialNumbers";
	
	Query.SetParameter("Ref",					DocumentRefGoodsReceipt);
	Query.SetParameter("Company",				StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PointInTime",			New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("UseCharacteristics",	StructureAdditionalProperties.AccountingPolicy.UseCharacteristics);
	Query.SetParameter("UseBatches",			StructureAdditionalProperties.AccountingPolicy.UseBatches);
	Query.SetParameter("UseSerialNumbers",		StructureAdditionalProperties.AccountingPolicy.UseSerialNumbers);
	
	Query.ExecuteBatch();
	
	// Creation of document postings.
	DriveServer.GenerateTransactionsTable(DocumentRefGoodsReceipt, StructureAdditionalProperties);
	
	PerformanceEstimationClientServer.StartTimeMeasurement("DocumentGoodsReceiptPositingGenerateTable");
	
	GenerateTableInventoryDemand(DocumentRefGoodsReceipt, StructureAdditionalProperties);
	GenerateTableInventoryInWarehouses(DocumentRefGoodsReceipt, StructureAdditionalProperties);
	GenerateTablePurchaseOrders(DocumentRefGoodsReceipt, StructureAdditionalProperties);
	GenerateTableSalesOrders(DocumentRefGoodsReceipt, StructureAdditionalProperties);
	GenerateTableGoodsReceivedNotInvoiced(DocumentRefGoodsReceipt, StructureAdditionalProperties);
	GenerateTableStockReceivedFromThirdParties(DocumentRefGoodsReceipt, StructureAdditionalProperties);
	GenerateTableStockTransferredToThirdParties(DocumentRefGoodsReceipt, StructureAdditionalProperties);
	
	PerformanceEstimationClientServer.StartTimeMeasurement("DocumentGoodsReceiptPositingGenerateTableInventory");
	
	GenerateTableInventory(DocumentRefGoodsReceipt, StructureAdditionalProperties);
	
	PerformanceEstimationClientServer.StartTimeMeasurement("DocumentGoodsReceiptPositingGenerateTableManagement");
	
	// Serial numbers
	GenerateTableSerialNumbers(DocumentRefGoodsReceipt, StructureAdditionalProperties);
	
EndProcedure

Procedure CheckAbilityOfEnteringByGoodsReceipt(FillingData, Posted, OperationType, IsSupplierInvoice) Export
	
	If IsSupplierInvoice AND OperationType <> Enums.OperationTypesGoodsReceipt.PurchaseFromSupplier Then
		ErrorText = NStr("en = 'Cannot use %1 as a base document for Supplier invoice. Please select a goods receipt with ""Purchase from supplier"" operation.'");
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

Procedure RunControl(DocumentRefGoodsReceipt, AdditionalProperties, Cancel, PostingDelete = False) Export
	
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
		OR StructureTemporaryTables.RegisterRecordsPurchaseOrdersChange
		OR StructureTemporaryTables.RegisterRecordsGoodsReceivedNotInvoicedChange Then
		
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
		|		INNER JOIN AccumulationRegister.GoodsReceivedNotInvoiced.Balance(&ControlTime, ) AS GoodsReceivedNotInvoicedBalances
		|		ON RegisterRecordsGoodsReceivedNotInvoicedChange.Company = GoodsReceivedNotInvoicedBalances.Company
		|			AND RegisterRecordsGoodsReceivedNotInvoicedChange.GoodsReceipt = GoodsReceivedNotInvoicedBalances.GoodsReceipt
		|			AND RegisterRecordsGoodsReceivedNotInvoicedChange.Contract = GoodsReceivedNotInvoicedBalances.Contract
		|			AND RegisterRecordsGoodsReceivedNotInvoicedChange.Products = GoodsReceivedNotInvoicedBalances.Products
		|			AND RegisterRecordsGoodsReceivedNotInvoicedChange.Characteristic = GoodsReceivedNotInvoicedBalances.Characteristic
		|			AND (ISNULL(GoodsReceivedNotInvoicedBalances.QuantityBalance, 0) < 0)
		|
		|ORDER BY
		|	LineNumber");
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.SetParameter("ControlTime", AdditionalProperties.ForPosting.ControlTime);
		
		ResultsArray = Query.ExecuteBatch();
		
		If Not ResultsArray[0].IsEmpty()
			OR Not ResultsArray[1].IsEmpty()
			OR Not ResultsArray[2].IsEmpty()
			OR Not ResultsArray[3].IsEmpty()Then
			DocumentObjectGoodsReceipt = DocumentRefGoodsReceipt.GetObject();
		EndIf;
		
		// Negative balance of inventory in the warehouse.
		If Not ResultsArray[0].IsEmpty() Then
			QueryResultSelection = ResultsArray[0].Select();
			DriveServer.ShowMessageAboutPostingToInventoryInWarehousesRegisterErrors(DocumentObjectGoodsReceipt, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance of inventory.
		If Not ResultsArray[1].IsEmpty() Then
			QueryResultSelection = ResultsArray[1].Select();
			DriveServer.ShowMessageAboutPostingToInventoryRegisterErrors(DocumentObjectGoodsReceipt, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance on purchase order.
		If Not ResultsArray[2].IsEmpty() Then
			QueryResultSelection = ResultsArray[2].Select();
			DriveServer.ShowMessageAboutPostingToPurchaseOrdersRegisterErrors(DocumentObjectGoodsReceipt, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance on goods received not yet invoiced
		If Not ResultsArray[3].IsEmpty() Then
			QueryResultSelection = ResultsArray[3].Select();
			DriveServer.ShowMessageAboutPostingToGoodsReceivedNotInvoicedRegisterErrors(DocumentObjectGoodsReceipt, QueryResultSelection, Cancel);
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region TableGeneration

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
	|	SUM(TablePurchaseOrders.Quantity) AS Quantity
	|FROM
	|	TemporaryTableProducts AS TablePurchaseOrders
	|WHERE
	|	TablePurchaseOrders.Order <> VALUE(Document.PurchaseOrder.EmptyRef)
	|	AND TablePurchaseOrders.Order REFS Document.PurchaseOrder
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

Procedure GenerateTableInventory(DocumentRef, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	TableProducts.LineNumber AS LineNumber,
	|	TableProducts.Period AS Period,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TableProducts.Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	FALSE AS Return,
	|	TableProducts.Document AS Document,
	|	UNDEFINED AS SourceDocument,
	|	UNDEFINED AS CorrSalesOrder,
	|	ISNULL(TableProducts.StructuralUnit, VALUE(Catalog.Counterparties.EmptyRef)) AS StructuralUnit,
	|	TableProducts.GLAccount AS GLAccount,
	|	TableProducts.Products AS Products,
	|	TableProducts.Characteristic AS Characteristic,
	|	TableProducts.Batch AS Batch,
	|	TableProducts.Quantity AS Quantity,
	|	CASE
	|		WHEN TableProducts.Order REFS Document.SalesOrder
	|				AND TableProducts.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|				AND TableProducts.Order <> VALUE(Document.WorkOrder.EmptyRef)
	|			THEN TableProducts.Order
	|		ELSE UNDEFINED
	|	END AS SalesOrder,
	|	FALSE AS FixedCost,
	|	0 AS Amount,
	|	TableProducts.ProductsCorr AS ProductsCorr,
	|	TableProducts.CharacteristicCorr AS CharacteristicCorr,
	|	TableProducts.BatchCorr AS BatchCorr,
	|	CASE
	|		WHEN TableProducts.CorrOrder = VALUE(Document.SalesOrder.EmptyRef)
	|				OR TableProducts.CorrOrder = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE TableProducts.CorrOrder
	|	END AS CorrOrder,
	|	TableProducts.CorrOrganization AS CorrOrganization,
	|	TableProducts.StructuralUnitCorr AS StructuralUnitCorr,
	|	TableProducts.CorrGLAccount AS CorrGLAccount
	|FROM
	|	TemporaryTableProducts AS TableProducts";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventory", QueryResult.Unload());
	
	If DocumentRef.OperationType = Enums.OperationTypesGoodsReceipt.ReturnFromAThirdParty Then
		GenerateTableInventoryReturn(DocumentRef, StructureAdditionalProperties);
	EndIf;
	
EndProcedure

Procedure GenerateTableInventoryReturn(DocumentRef, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	// Setting the exclusive lock for the controlled inventory balances.
	Query.Text =
	"SELECT
	|	TableInventory.CorrOrganization AS Company,
	|	TableInventory.StructuralUnitCorr AS StructuralUnit,
	|	TableInventory.CorrGLAccount AS GLAccount,
	|	TableInventory.ProductsCorr AS Products,
	|	TableInventory.CharacteristicCorr AS Characteristic,
	|	TableInventory.BatchCorr AS Batch,
	|	CASE
	|		WHEN TableInventory.CorrOrder REFS Document.SalesOrder
	|				AND TableInventory.CorrOrder <> VALUE(Document.SalesOrder.EmptyRef)
	|				AND TableInventory.CorrOrder <> VALUE(Document.WorkOrder.EmptyRef)
	|			THEN TableInventory.CorrOrder
	|		ELSE UNDEFINED
	|	END AS SalesOrder
	|FROM
	|	TemporaryTableProducts AS TableInventory
	|
	|GROUP BY
	|	TableInventory.CorrOrganization,
	|	TableInventory.StructuralUnitCorr,
	|	TableInventory.CorrGLAccount,
	|	TableInventory.ProductsCorr,
	|	TableInventory.CharacteristicCorr,
	|	TableInventory.BatchCorr,
	|	TableInventory.CorrOrder";
	
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
	|						TableInventory.CorrOrganization,
	|						TableInventory.StructuralUnitCorr,
	|						TableInventory.CorrGLAccount,
	|						TableInventory.ProductsCorr,
	|						TableInventory.CharacteristicCorr,
	|						TableInventory.BatchCorr,
	|						CASE
	|							WHEN TableInventory.CorrOrder REFS Document.SalesOrder
	|									AND TableInventory.CorrOrder <> VALUE(Document.SalesOrder.EmptyRef)
	|									AND TableInventory.CorrOrder <> VALUE(Document.WorkOrder.EmptyRef)
	|								THEN TableInventory.CorrOrder
	|							ELSE UNDEFINED
	|						END
	|					FROM
	|						TemporaryTableProducts AS TableInventory)) AS InventoryBalances
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
	
	Query.SetParameter("Ref", DocumentRef);
	Query.SetParameter("ControlTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.PointInTime.Date);
	
	QueryResult = Query.Execute();
	
	TableInventoryBalances = QueryResult.Unload();
	TableInventoryBalances.Indexes.Add("Company,StructuralUnit,GLAccount,Products,Characteristic,Batch,SalesOrder");
	
	TableInventory = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.CopyColumns();
	For n = 0 To StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Count() - 1 Do
		
		RowTableInventory = StructureAdditionalProperties.TableForRegisterRecords.TableInventory[n];
		
		StructureForSearch = New Structure;
		StructureForSearch.Insert("Company",		RowTableInventory.Company);
		StructureForSearch.Insert("StructuralUnit",	RowTableInventory.StructuralUnitCorr);
		StructureForSearch.Insert("GLAccount",		RowTableInventory.CorrGLAccount);
		StructureForSearch.Insert("Products",		RowTableInventory.ProductsCorr);
		StructureForSearch.Insert("Characteristic",	RowTableInventory.CharacteristicCorr);
		StructureForSearch.Insert("Batch",			RowTableInventory.BatchCorr);
		StructureForSearch.Insert("SalesOrder",		RowTableInventory.CorrOrder);
		
		QuantityWanted = RowTableInventory.Quantity;
		
		If QuantityWanted > 0 Then
			
			BalanceRowsArray = TableInventoryBalances.FindRows(StructureForSearch);
			
			QuantityBalance = 0;
			AmountBalance = 0;
			
			If BalanceRowsArray.Count() > 0 Then
				QuantityBalance = BalanceRowsArray[0].QuantityBalance;
				AmountBalance = BalanceRowsArray[0].AmountBalance;
			EndIf;
			
			If QuantityBalance > 0 AND QuantityBalance > QuantityWanted Then
			
				AmountToBeWrittenOff = Round(AmountBalance * QuantityWanted / QuantityBalance , 2, 1);
				
				BalanceRowsArray[0].QuantityBalance = BalanceRowsArray[0].QuantityBalance - QuantityWanted;
				BalanceRowsArray[0].AmountBalance = BalanceRowsArray[0].AmountBalance - AmountToBeWrittenOff;
				
			ElsIf QuantityBalance = QuantityWanted Then
				
				AmountToBeWrittenOff = AmountBalance;
				
				BalanceRowsArray[0].QuantityBalance = 0;
				BalanceRowsArray[0].AmountBalance = 0;
				
			Else
				AmountToBeWrittenOff = 0;
			EndIf;
			
			// Expense.
			TableRowReceipt = TableInventory.Add();
			FillPropertyValues(TableRowReceipt, RowTableInventory);
			
			TableRowReceipt.RecordType = AccumulationRecordType.Receipt;
			TableRowReceipt.Amount = -AmountToBeWrittenOff;
			TableRowReceipt.Quantity = QuantityWanted;
			
			TableRowReceipt.SalesOrder = Undefined;
			
			TableRowReceipt.Return = True;
			
			// Generate postings.
			If Round(AmountToBeWrittenOff, 2, 1) <> 0 Then
				RowTableAccountingJournalEntries = StructureAdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries.Add();
				FillPropertyValues(RowTableAccountingJournalEntries, RowTableInventory);
				RowTableAccountingJournalEntries.AccountDr = RowTableInventory.GLAccount;
				RowTableAccountingJournalEntries.CurrencyDr = Undefined;
				RowTableAccountingJournalEntries.AmountCurDr = 0;
				RowTableAccountingJournalEntries.AccountCr = RowTableInventory.CorrGLAccount;
				RowTableAccountingJournalEntries.CurrencyCr = Undefined;
				RowTableAccountingJournalEntries.AmountCurCr = 0;
				RowTableAccountingJournalEntries.Amount = AmountToBeWrittenOff;
			EndIf;
			
			TableRowExpense = TableInventory.Add();
			FillPropertyValues(TableRowExpense, RowTableInventory,,"StructuralUnit, StructuralUnitCorr");
			
			TableRowExpense.RecordType = AccumulationRecordType.Expense;
			TableRowExpense.Company = RowTableInventory.CorrOrganization;
			TableRowExpense.StructuralUnit = RowTableInventory.StructuralUnitCorr;
			TableRowExpense.GLAccount = RowTableInventory.CorrGLAccount;
			TableRowExpense.Products = RowTableInventory.ProductsCorr;
			TableRowExpense.Characteristic = RowTableInventory.CharacteristicCorr;
			TableRowExpense.Batch = RowTableInventory.BatchCorr;
			TableRowExpense.SalesOrder = RowTableInventory.CorrOrder;
			
			TableRowExpense.CorrOrganization = RowTableInventory.Company;
			TableRowExpense.StructuralUnitCorr = RowTableInventory.StructuralUnit;
			TableRowExpense.CorrGLAccount = RowTableInventory.GLAccount;
			TableRowExpense.ProductsCorr = RowTableInventory.Products;
			TableRowExpense.CharacteristicCorr = RowTableInventory.Characteristic;
			TableRowExpense.BatchCorr = RowTableInventory.Batch;
			TableRowExpense.CorrOrder = Undefined;
			
			TableRowExpense.Amount = - AmountToBeWrittenOff;
			TableRowExpense.Quantity = QuantityWanted;
			
			TableRowExpense.GLAccount = RowTableInventory.CorrGLAccount;
			
			TableRowExpense.Return = True;
			
		EndIf;
		
	EndDo;
	
	StructureAdditionalProperties.TableForRegisterRecords.TableInventory = TableInventory;
	
EndProcedure

Procedure GenerateTableInventoryInWarehouses(DocumentRef, StructureAdditionalProperties)
	
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

Procedure GenerateTableGoodsReceivedNotInvoiced(DocumentRef, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	MIN(TableProducts.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TableProducts.Period AS Period,
	|	&Ref AS GoodsReceipt,
	|	TableProducts.Company AS Company,
	|	TableProducts.Counterparty AS Counterparty,
	|	TableProducts.Contract AS Contract,
	|	TableProducts.Products AS Products,
	|	TableProducts.Characteristic AS Characteristic,
	|	TableProducts.Batch AS Batch,
	|	TableProducts.Order AS PurchaseOrder,
	|	SUM(TableProducts.Quantity) AS Quantity
	|FROM
	|	TemporaryTableProducts AS TableProducts
	|WHERE
	|	TableProducts.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.PurchaseFromSupplier)
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
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableGoodsReceivedNotInvoiced", QueryResult.Unload());
	
EndProcedure

Procedure GenerateTableStockReceivedFromThirdParties(DocumentRef, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	MIN(TableStockReceivedFromThirdParties.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
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
	|	SUM(TableStockReceivedFromThirdParties.Quantity) AS Quantity
	|FROM
	|	TemporaryTableProducts AS TableStockReceivedFromThirdParties
	|WHERE
	|	TableStockReceivedFromThirdParties.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.ReceiptFromAThirdParty)
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
	|	TableStockReceivedFromThirdParties.GLAccount";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableStockReceivedFromThirdParties", QueryResult.Unload());
	
EndProcedure

Procedure GenerateTableStockTransferredToThirdParties(DocumentRef, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	MIN(TableStockTransferredToThirdParties.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableStockTransferredToThirdParties.Period AS Period,
	|	TableStockTransferredToThirdParties.Company AS Company,
	|	TableStockTransferredToThirdParties.Products AS Products,
	|	TableStockTransferredToThirdParties.Characteristic AS Characteristic,
	|	TableStockTransferredToThirdParties.Batch AS Batch,
	|	TableStockTransferredToThirdParties.Counterparty AS Counterparty,
	|	TableStockTransferredToThirdParties.Contract AS Contract,
	|	CASE
	|		WHEN TableStockTransferredToThirdParties.Order <> VALUE(Document.PurchaseOrder.EmptyRef)
	|			THEN TableStockTransferredToThirdParties.Order
	|		ELSE UNDEFINED
	|	END AS Order,
	|	SUM(TableStockTransferredToThirdParties.Quantity) AS Quantity
	|FROM
	|	TemporaryTableProducts AS TableStockTransferredToThirdParties
	|WHERE
	|	TableStockTransferredToThirdParties.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.ReturnFromAThirdParty)
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

Procedure GenerateTableSalesOrders(DocumentRef, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	MIN(TableSalesOrders.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TableSalesOrders.Period AS Period,
	|	TableSalesOrders.Company AS Company,
	|	TableSalesOrders.Products AS Products,
	|	TableSalesOrders.Characteristic AS Characteristic,
	|	TableSalesOrders.Order AS SalesOrder,
	|	SUM(TableSalesOrders.Quantity) AS Quantity
	|FROM
	|	TemporaryTableProducts AS TableSalesOrders
	|WHERE
	|	TableSalesOrders.Order REFS Document.SalesOrder
	|	AND TableSalesOrders.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|	AND TableSalesOrders.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.ReturnFromAThirdParty)
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

Procedure GenerateTableInventoryDemand(DocumentRef, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	MIN(TableInventory.LineNumber) AS LineNumber,
	|	TableInventory.Period AS Period,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	VALUE(Enum.InventoryMovementTypes.Receipt) AS MovementType,
	|	TableInventory.Company AS Company,
	|	CASE
	|		WHEN TableInventory.Order REFS Document.SalesOrder
	|			THEN TableInventory.Order
	|		ELSE VALUE(Document.SalesOrder.EmptyRef)
	|	END AS SalesOrder,
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	SUM(TableInventory.Quantity) AS Quantity
	|FROM
	|	TemporaryTableProducts AS TableInventory
	|WHERE
	|	TableInventory.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.ReceiptFromAThirdParty)
	|
	|GROUP BY
	|	TableInventory.Period,
	|	TableInventory.Company,
	|	TableInventory.Order,
	|	TableInventory.Products,
	|	TableInventory.Characteristic
	|
	|ORDER BY
	|	LineNumber";
		
	QueryResult = Query.Execute();
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryDemand", QueryResult.Unload());
		
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	TableInventoryDemand.Company AS Company,
	|	VALUE(Enum.InventoryMovementTypes.Receipt) AS MovementType,
	|	CASE
	|		WHEN TableInventoryDemand.Order REFS Document.SalesOrder
	|			THEN TableInventoryDemand.Order
	|		ELSE VALUE(Document.SalesOrder.EmptyRef)
	|	END AS SalesOrder,
	|	TableInventoryDemand.Products AS Products,
	|	TableInventoryDemand.Characteristic AS Characteristic
	|FROM
	|	TemporaryTableProducts AS TableInventoryDemand
	|WHERE
	|	TableInventoryDemand.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.ReceiptFromAThirdParty)";
	
	QueryResult = Query.Execute();
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.InventoryDemand");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;

	For Each ColumnQueryResult In QueryResult.Columns Do
		LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
	EndDo;
	Block.Lock();

	// Receive balance.
	Query.Text =
	"SELECT
	|	InventoryDemandBalances.Company AS Company,
	|	InventoryDemandBalances.SalesOrder AS SalesOrder,
	|	InventoryDemandBalances.Products AS Products,
	|	InventoryDemandBalances.Characteristic AS Characteristic,
	|	SUM(InventoryDemandBalances.Quantity) AS QuantityBalance
	|FROM
	|	(SELECT
	|		InventoryDemandBalances.Company AS Company,
	|		InventoryDemandBalances.SalesOrder AS SalesOrder,
	|		InventoryDemandBalances.Products AS Products,
	|		InventoryDemandBalances.Characteristic AS Characteristic,
	|		SUM(InventoryDemandBalances.QuantityBalance) AS Quantity
	|	FROM
	|		AccumulationRegister.InventoryDemand.Balance(
	|				&ControlTime,
	|				(Company, MovementType, SalesOrder, Products, Characteristic) IN
	|					(SELECT
	|						TemporaryTableInventory.Company AS Company,
	|						VALUE(Enum.InventoryMovementTypes.Receipt) AS MovementType,
	|						CASE
	|							WHEN TemporaryTableInventory.Order REFS Document.SalesOrder
	|								THEN TemporaryTableInventory.Order
	|							ELSE VALUE(Document.SalesOrder.EmptyRef)
	|						END AS SalesOrder,
	|						TemporaryTableInventory.Products AS Products,
	|						TemporaryTableInventory.Characteristic AS Characteristic
	|					FROM
	|						TemporaryTableProducts AS TemporaryTableInventory
	|					WHERE
	|						TemporaryTableInventory.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.ReceiptFromAThirdParty))) AS InventoryDemandBalances
	|	
	|	GROUP BY
	|		InventoryDemandBalances.Company,
	|		InventoryDemandBalances.SalesOrder,
	|		InventoryDemandBalances.Products,
	|		InventoryDemandBalances.Characteristic
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsInventoryDemand.Company,
	|		DocumentRegisterRecordsInventoryDemand.SalesOrder,
	|		DocumentRegisterRecordsInventoryDemand.Products,
	|		DocumentRegisterRecordsInventoryDemand.Characteristic,
	|		CASE
	|			WHEN DocumentRegisterRecordsInventoryDemand.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN ISNULL(DocumentRegisterRecordsInventoryDemand.Quantity, 0)
	|			ELSE -ISNULL(DocumentRegisterRecordsInventoryDemand.Quantity, 0)
	|		END
	|	FROM
	|		AccumulationRegister.InventoryDemand AS DocumentRegisterRecordsInventoryDemand
	|	WHERE
	|		DocumentRegisterRecordsInventoryDemand.Recorder = &Ref
	|		AND DocumentRegisterRecordsInventoryDemand.Period <= &ControlPeriod) AS InventoryDemandBalances
	|
	|GROUP BY
	|	InventoryDemandBalances.Company,
	|	InventoryDemandBalances.SalesOrder,
	|	InventoryDemandBalances.Products,
	|	InventoryDemandBalances.Characteristic";
	
	Query.SetParameter("Ref", DocumentRef);
	Query.SetParameter("ControlTime", StructureAdditionalProperties.ForPosting.ControlTime);
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.ControlPeriod);

	QueryResult = Query.Execute();
	
	TableInventoryDemandBalance = QueryResult.Unload();
	TableInventoryDemandBalance.Indexes.Add("Company,SalesOrder,Products,Characteristic");

	TemporaryTableInventoryDemand = StructureAdditionalProperties.TableForRegisterRecords.TableInventoryDemand.CopyColumns();
	
	For Each RowTablesForInventory In StructureAdditionalProperties.TableForRegisterRecords.TableInventoryDemand Do
		
		StructureForSearch = New Structure;
		StructureForSearch.Insert("Company",		RowTablesForInventory.Company);
		StructureForSearch.Insert("SalesOrder",		RowTablesForInventory.SalesOrder);
		StructureForSearch.Insert("Products",		RowTablesForInventory.Products);
		StructureForSearch.Insert("Characteristic",	RowTablesForInventory.Characteristic);
		
		BalanceRowsArray = TableInventoryDemandBalance.FindRows(StructureForSearch);
		If BalanceRowsArray.Count() > 0 Then
			
			If RowTablesForInventory.Quantity > BalanceRowsArray[0].QuantityBalance Then
				RowTablesForInventory.Quantity = BalanceRowsArray[0].QuantityBalance;
			EndIf;
			
			TableRowExpense = TemporaryTableInventoryDemand.Add();
			FillPropertyValues(TableRowExpense, RowTablesForInventory);
			
		EndIf;
		
	EndDo;
	
	StructureAdditionalProperties.TableForRegisterRecords.TableInventoryDemand = TemporaryTableInventoryDemand;
	
EndProcedure

#EndRegion

#Region PrintInterface

Procedure Print(ObjectsArray, PrintParameters, PrintFormsCollection, PrintObjects, OutputParameters) Export
	
	Var Errors;
	
	If PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "GoodsReceivedNote") Then
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection,
															"GoodsReceivedNote",
															NStr("en = 'Goods received note'"),
															DataProcessors.PrintGoodsReceivedNote.PrintForm(ObjectsArray, PrintObjects, "GoodsReceivedNote"));
	EndIf;

	If Errors <> Undefined Then
		CommonUseClientServer.ShowErrorsToUser(Errors);
	EndIf;
	
	// parameters of sending printing forms by email
	DriveServer.FillSendingParameters(OutputParameters.SendingParameters, ObjectsArray, PrintFormsCollection);
	
EndProcedure

Procedure AddPrintCommands(PrintCommands) Export
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID							= "GoodsReceivedNote";
	PrintCommand.Presentation				= NStr("en = 'Goods received note'");
	PrintCommand.CheckPostingBeforePrint	= False;
	PrintCommand.Order						= 1;
	
EndProcedure

#EndRegion

#Region InfobaseUpdate

Procedure FillOperationType() Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	GoodsReceipt.Ref AS Ref
	|FROM
	|	Document.GoodsReceipt AS GoodsReceipt
	|WHERE
	|	GoodsReceipt.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.EmptyRef)";
	
	Selection = Query.Execute().Select();
	
	PurchaseFromSupplier = Enums.OperationTypesGoodsReceipt.PurchaseFromSupplier;
	
	While Selection.Next() Do
		
		DocObj = Selection.Ref.GetObject();
		DocObj.OperationType = PurchaseFromSupplier;
		DocObj.Write(DocumentWriteMode.Write);
		
	EndDo;
	
EndProcedure

Procedure FillNewGLAccounts() Export
	
	DocumentName = "GoodsReceipt";
	
	Tables = New Array();
	
	TableDecription = New Structure("Name, Conditions", "Products", New Array());
	
	GLAccountFields = ChartsOfAccounts.PrimaryChartOfAccounts.GLAccountFields();
	GLAccountFields.Source = "Products.InventoryGLAccount";
	GLAccountFields.Receiver = "InventoryGLAccount";
	TableDecription.Conditions.Add(GLAccountFields);
	
	GLAccountFields = ChartsOfAccounts.PrimaryChartOfAccounts.GLAccountFields();
	GLAccountFields.Source = "&GoodsReceivedNotInvoicedGLAccount";
	GLAccountFields.Receiver = "GoodsReceivedNotInvoicedGLAccount";
	GLAccountFields.Parameter = Catalogs.DefaultGLAccounts.GetDefaultGLAccount("GoodsReceivedNotInvoiced");
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