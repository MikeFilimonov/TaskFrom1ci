#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions

// Procedure fills tabular section according to specification.
//
Procedure FillTabularSectionBySpecification(NodesBillsOfMaterialstack, NodesTable = Undefined) Export
	
	TempTablesManager = New TempTablesManager;
	
	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	Query.Text =
	"SELECT
	|	TableProduction.LineNumber AS LineNumber,
	|	TableProduction.Quantity AS Quantity,
	|	TableProduction.Factor AS Factor,
	|	TableProduction.Specification AS Specification
	|INTO TemporaryTableProduction
	|FROM
	|	&TableProduction AS TableProduction
	|WHERE
	|	TableProduction.Specification <> VALUE(Catalog.BillsOfMaterials.EmptyRef)";
	
	If NodesTable = Undefined Then
		Inventory.Clear();
		TableProduction = Products.Unload();
		Array = New Array();
		Array.Add(Type("Number"));
		TypeDescriptionC = New TypeDescription(Array, , ,New NumberQualifiers(10,3));
		TableProduction.Columns.Add("Factor", TypeDescriptionC);
		For Each StringProducts In TableProduction Do
			If ValueIsFilled(StringProducts.MeasurementUnit)
				AND TypeOf(StringProducts.MeasurementUnit) = Type("CatalogRef.UOM") Then
				StringProducts.Factor = StringProducts.MeasurementUnit.Factor;
			Else
				StringProducts.Factor = 1;
			EndIf;
		EndDo;
		NodesTable = TableProduction.CopyColumns("LineNumber,Quantity,Factor,Specification");
		Query.SetParameter("TableProduction", TableProduction);
	Else
		Query.SetParameter("TableProduction", NodesTable);
	EndIf;
	
	Query.Execute();
	
	Query.Text =
	"SELECT
	|	MIN(TableProduction.LineNumber) AS ProductionLineNumber,
	|	TableProduction.Specification AS ProductionSpecification,
	|	MIN(TableMaterials.LineNumber) AS StructureLineNumber,
	|	TableMaterials.ContentRowType AS ContentRowType,
	|	TableMaterials.Products AS Products,
	|	CASE
	|		WHEN UseCharacteristics.Value
	|			THEN TableMaterials.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	SUM(TableMaterials.Quantity / TableMaterials.ProductsQuantity * TableProduction.Factor * TableProduction.Quantity) AS Quantity,
	|	TableMaterials.MeasurementUnit AS MeasurementUnit,
	|	CASE
	|		WHEN TableMaterials.ContentRowType = VALUE(Enum.BOMLineType.Node)
	|				AND VALUETYPE(TableMaterials.MeasurementUnit) = Type(Catalog.UOM)
	|				AND TableMaterials.MeasurementUnit <> VALUE(Catalog.UOM.EmptyRef)
	|			THEN TableMaterials.MeasurementUnit.Factor
	|		ELSE 1
	|	END AS Factor,
	|	TableMaterials.CostPercentage AS CostPercentage,
	|	TableMaterials.Specification AS Specification
	|FROM
	|	TemporaryTableProduction AS TableProduction
	|		LEFT JOIN Catalog.BillsOfMaterials.Content AS TableMaterials
	|		ON TableProduction.Specification = TableMaterials.Ref,
	|	Constant.UseCharacteristics AS UseCharacteristics
	|WHERE
	|	TableMaterials.Products.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
	|
	|GROUP BY
	|	TableProduction.Specification,
	|	TableMaterials.ContentRowType,
	|	TableMaterials.Products,
	|	TableMaterials.MeasurementUnit,
	|	CASE
	|		WHEN TableMaterials.ContentRowType = VALUE(Enum.BOMLineType.Node)
	|				AND VALUETYPE(TableMaterials.MeasurementUnit) = Type(Catalog.UOM)
	|				AND TableMaterials.MeasurementUnit <> VALUE(Catalog.UOM.EmptyRef)
	|			THEN TableMaterials.MeasurementUnit.Factor
	|		ELSE 1
	|	END,
	|	TableMaterials.CostPercentage,
	|	TableMaterials.Specification,
	|	CASE
	|		WHEN UseCharacteristics.Value
	|			THEN TableMaterials.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END
	|
	|ORDER BY
	|	ProductionLineNumber,
	|	StructureLineNumber";
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		If Selection.ContentRowType = Enums.BOMLineType.Node Then
			NodesTable.Clear();
			If Not NodesBillsOfMaterialstack.Find(Selection.Specification) = Undefined Then
				MessageText = NStr("en = 'During filling in of the Specification materials
				                   |tabular section a recursive item occurrence was found'")+" "+Selection.Products+" "+NStr("en = 'in BOM'")+" "+Selection.ProductionSpecification+"
									|The operation failed.";
				Raise MessageText;
			EndIf;
			NodesBillsOfMaterialstack.Add(Selection.Specification);
			NewRow = NodesTable.Add();
			FillPropertyValues(NewRow, Selection);
			FillTabularSectionBySpecification(NodesBillsOfMaterialstack, NodesTable);
		Else
			NewRow = Inventory.Add();
			FillPropertyValues(NewRow, Selection);
		EndIf;
	EndDo;
	
	NodesBillsOfMaterialstack.Clear();
	Inventory.GroupBy("Products, Characteristic, Batch, MeasurementUnit, Specification, CostPercentage", "Quantity, Reserve");
	
EndProcedure

// Procedure fills out the Quantity column according to reserves to be ordered.
//
Procedure FillColumnReserveByReserves() Export
	
	Inventory.LoadColumn(New Array(Inventory.Count()), "Reserve");
	
	TempTablesManager = New TempTablesManager;
	
	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	Query.Text =
	"SELECT
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.ConsumptionGLAccount AS ConsumptionGLAccount,
	|	&Order AS SalesOrder
	|INTO TemporaryTableInventory
	|FROM
	|	&TableInventory AS TableInventory";
	
	Query.SetParameter("TableInventory", Inventory.Unload());
	Query.SetParameter("Order", ?(ValueIsFilled(SalesOrder), SalesOrder, Undefined));
	Query.Execute();
	
	Query.Text =
	"SELECT
	|	InventoryBalances.Company AS Company,
	|	InventoryBalances.StructuralUnit AS StructuralUnit,
	|	InventoryBalances.GLAccount AS GLAccount,
	|	InventoryBalances.SalesOrder AS SalesOrder,
	|	InventoryBalances.Products AS Products,
	|	InventoryBalances.Characteristic AS Characteristic,
	|	InventoryBalances.Batch AS Batch,
	|	SUM(InventoryBalances.QuantityBalance) AS QuantityBalance
	|FROM
	|	(SELECT
	|		InventoryBalances.Company AS Company,
	|		InventoryBalances.StructuralUnit AS StructuralUnit,
	|		InventoryBalances.GLAccount AS GLAccount,
	|		InventoryBalances.SalesOrder AS SalesOrder,
	|		InventoryBalances.Products AS Products,
	|		InventoryBalances.Characteristic AS Characteristic,
	|		InventoryBalances.Batch AS Batch,
	|		InventoryBalances.QuantityBalance AS QuantityBalance
	|	FROM
	|		AccumulationRegister.Inventory.Balance(
	|				,
	|				(Company, StructuralUnit, GLAccount, Products, Characteristic, Batch, SalesOrder) In
	|					(SELECT
	|						&Company,
	|						&StructuralUnit,
	|						TableInventory.ConsumptionGLAccount,
	|						TableInventory.Products,
	|						TableInventory.Characteristic,
	|						TableInventory.Batch,
	|						TableInventory.SalesOrder
	|					FROM
	|						TemporaryTableInventory AS TableInventory
	|					WHERE
	|						TableInventory.SalesOrder <> UNDEFINED)) AS InventoryBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsInventory.Company,
	|		DocumentRegisterRecordsInventory.StructuralUnit,
	|		DocumentRegisterRecordsInventory.GLAccount,
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
	|		AND DocumentRegisterRecordsInventory.Period <= &Period
	|		AND DocumentRegisterRecordsInventory.RecordType = VALUE(AccumulationRecordType.Expense)
	|		AND DocumentRegisterRecordsInventory.SalesOrder <> UNDEFINED) AS InventoryBalances
	|
	|GROUP BY
	|	InventoryBalances.Company,
	|	InventoryBalances.StructuralUnit,
	|	InventoryBalances.GLAccount,
	|	InventoryBalances.SalesOrder,
	|	InventoryBalances.Products,
	|	InventoryBalances.Characteristic,
	|	InventoryBalances.Batch";
	
	Query.SetParameter("Period", Date);
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("Company", DriveServer.GetCompany(Company));
	Query.SetParameter("StructuralUnit", InventoryStructuralUnit);
	Query.SetParameter("StructuralUnitType", InventoryStructuralUnit.StructuralUnitType);
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	While Selection.Next() Do
		
		StructureForSearch = New Structure;
		StructureForSearch.Insert("Products", Selection.Products);
		StructureForSearch.Insert("Characteristic", Selection.Characteristic);
		StructureForSearch.Insert("Batch", Selection.Batch);
		
		TotalBalance = Selection.QuantityBalance;
		ArrayOfRowsInventory = Inventory.FindRows(StructureForSearch);
		For Each StringInventory In ArrayOfRowsInventory Do
			
			TotalBalance = ?(TypeOf(StringInventory.MeasurementUnit) = Type("CatalogRef.UOMClassifier"), TotalBalance, TotalBalance / StringInventory.MeasurementUnit.Factor);
			If StringInventory.Quantity >= TotalBalance Then
				StringInventory.Reserve = TotalBalance;
				TotalBalance = 0;
			Else
				StringInventory.Reserve = StringInventory.Quantity;
				TotalBalance = TotalBalance - StringInventory.Quantity;
				TotalBalance = ?(TypeOf(StringInventory.MeasurementUnit) = Type("CatalogRef.UOMClassifier"), TotalBalance, TotalBalance * StringInventory.MeasurementUnit.Factor);
			EndIf;
			
		EndDo;
		
	EndDo;
	
EndProcedure

// Procedure for filling the document basing on Production order.
//
Procedure FillByProductionOrder(FillingData) Export
	
	// Header filling.
	Query = New Query;
	Query.Text =
	"SELECT
	|	ProductionOrder.Ref AS BasisRef,
	|	ProductionOrder.Posted AS BasisPosted,
	|	ProductionOrder.Closed AS Closed,
	|	ProductionOrder.OrderState AS OrderState,
	|	CASE
	|		WHEN ProductionOrder.OperationKind = VALUE(Enum.OperationTypesProductionOrder.Assembly)
	|			THEN VALUE(Enum.OperationTypesProduction.Assembly)
	|		ELSE VALUE(Enum.OperationTypesProduction.Disassembly)
	|	END AS OperationKind,
	|	ProductionOrder.Start AS Start,
	|	ProductionOrder.Finish AS Finish,
	|	ProductionOrder.Ref AS BasisDocument,
	|	ProductionOrder.SalesOrder AS SalesOrder,
	|	ProductionOrder.Company AS Company,
	|	ProductionOrder.StructuralUnit AS StructuralUnit,
	|	CASE
	|		WHEN ProductionOrder.StructuralUnit.TransferRecipient.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Warehouse)
	|				OR ProductionOrder.StructuralUnit.TransferRecipient.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Department)
	|			THEN ProductionOrder.StructuralUnit.TransferRecipient
	|		ELSE VALUE(Catalog.BusinessUnits.EmptyRef)
	|	END AS ProductsStructuralUnit,
	|	CASE
	|		WHEN ProductionOrder.StructuralUnit.TransferRecipient.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Warehouse)
	|				OR ProductionOrder.StructuralUnit.TransferRecipient.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Department)
	|			THEN ProductionOrder.StructuralUnit.TransferRecipientCell
	|		ELSE VALUE(Catalog.Cells.EmptyRef)
	|	END AS ProductsCell,
	|	CASE
	|		WHEN ProductionOrder.StructuralUnit.TransferSource.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Warehouse)
	|				OR ProductionOrder.StructuralUnit.TransferSource.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Department)
	|			THEN ProductionOrder.StructuralUnit.TransferSource
	|		ELSE VALUE(Catalog.BusinessUnits.EmptyRef)
	|	END AS InventoryStructuralUnit,
	|	CASE
	|		WHEN ProductionOrder.StructuralUnit.TransferSource.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Warehouse)
	|				OR ProductionOrder.StructuralUnit.TransferSource.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Department)
	|			THEN ProductionOrder.StructuralUnit.TransferSourceCell
	|		ELSE VALUE(Catalog.Cells.EmptyRef)
	|	END AS CellInventory,
	|	ProductionOrder.StructuralUnit.RecipientOfWastes AS DisposalsStructuralUnit,
	|	ProductionOrder.StructuralUnit.DisposalsRecipientCell AS DisposalsCell
	|FROM
	|	Document.ProductionOrder AS ProductionOrder
	|WHERE
	|	ProductionOrder.Ref = &BasisDocument";
	
	Query.SetParameter("BasisDocument", FillingData);
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		VerifiedAttributesValues = New Structure("OrderState, Closed, Posted", Selection.OrderState, Selection.Closed, Selection.BasisPosted);
		Documents.ProductionOrder.VerifyEnteringAbilityByProductionOrder(Selection.BasisRef, VerifiedAttributesValues);
	EndDo;
	
	IntermediateStructuralUnit = StructuralUnit;
	FillPropertyValues(ThisObject, Selection);
	
	If ValueIsFilled(StructuralUnit) Then
			
		If Not ValueIsFilled(ProductsStructuralUnit) Then
			ProductsStructuralUnit = StructuralUnit;
		EndIf;
		
		If Not ValueIsFilled(InventoryStructuralUnit) Then
			InventoryStructuralUnit = StructuralUnit;
		EndIf;
		
		If Not ValueIsFilled(DisposalsStructuralUnit) Then
			DisposalsStructuralUnit = StructuralUnit;
		EndIf;
		
	EndIf;
	
	If IntermediateStructuralUnit <> StructuralUnit Then
		Cell = Undefined;
	EndIf;
	
	// Filling out tabular section.
	Query = New Query;
	Query.Text =
	"SELECT
	|	OrdersBalance.ProductionOrder AS ProductionOrder,
	|	OrdersBalance.Products AS Products,
	|	OrdersBalance.Characteristic AS Characteristic,
	|	SUM(OrdersBalance.QuantityBalance) AS QuantityBalance
	|FROM
	|	(SELECT
	|		OrdersBalance.ProductionOrder AS ProductionOrder,
	|		OrdersBalance.Products AS Products,
	|		OrdersBalance.Characteristic AS Characteristic,
	|		OrdersBalance.QuantityBalance AS QuantityBalance
	|	FROM
	|		AccumulationRegister.ProductionOrders.Balance(
	|				,
	|				ProductionOrder = &BasisDocument
	|					AND Products.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)) AS OrdersBalance
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsProductionOrders.ProductionOrder,
	|		DocumentRegisterRecordsProductionOrders.Products,
	|		DocumentRegisterRecordsProductionOrders.Characteristic,
	|		CASE
	|			WHEN DocumentRegisterRecordsProductionOrders.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN ISNULL(DocumentRegisterRecordsProductionOrders.Quantity, 0)
	|			ELSE -ISNULL(DocumentRegisterRecordsProductionOrders.Quantity, 0)
	|		END
	|	FROM
	|		AccumulationRegister.ProductionOrders AS DocumentRegisterRecordsProductionOrders
	|	WHERE
	|		DocumentRegisterRecordsProductionOrders.Recorder = &Ref) AS OrdersBalance
	|
	|GROUP BY
	|	OrdersBalance.ProductionOrder,
	|	OrdersBalance.Products,
	|	OrdersBalance.Characteristic
	|
	|HAVING
	|	SUM(OrdersBalance.QuantityBalance) > 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ProductionOrder.Products.(
	|		Products AS Products,
	|		Products.ProductsType AS ProductsType,
	|		Characteristic AS Characteristic,
	|		Quantity AS Quantity,
	|		CASE
	|			WHEN VALUETYPE(ProductionOrder.Products.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|				THEN 1
	|			ELSE ProductionOrder.Products.MeasurementUnit.Factor
	|		END AS Factor,
	|		MeasurementUnit AS MeasurementUnit,
	|		Specification AS Specification
	|	),
	|	ProductionOrder.Inventory.(
	|		Products AS Products,
	|		Products.ProductsType AS ProductsType,
	|		Characteristic AS Characteristic,
	|		Quantity AS Quantity,
	|		CASE
	|			WHEN VALUETYPE(ProductionOrder.Inventory.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|				THEN 1
	|			ELSE ProductionOrder.Inventory.MeasurementUnit.Factor
	|		END AS Factor,
	|		MeasurementUnit AS MeasurementUnit,
	|		Specification AS Specification,
	|		1 AS CostPercentage
	|	)
	|FROM
	|	Document.ProductionOrder AS ProductionOrder
	|WHERE
	|	ProductionOrder.Ref = &BasisDocument";
	
	Query.Text = Query.Text + ";";
	
	If FillingData.OperationKind = Enums.OperationTypesProductionOrder.Disassembly Then
		
		TabularSectionName = "Inventory";
		Query.Text = Query.Text +
		"SELECT
		|	OrdersBalance.Products AS Products,
		|	OrdersBalance.Characteristic AS Characteristic,
		|	OrdersBalance.MeasurementUnit AS MeasurementUnit,
		|	OrdersBalance.Specification AS Specification,
		|	SUM(OrdersBalance.Reserve) AS Reserve,
		|	SUM(OrdersBalance.Quantity) AS Quantity
		|FROM
		|	(SELECT
		|		OrderForProductsProduction.Products AS Products,
		|		OrderForProductsProduction.Characteristic AS Characteristic,
		|		OrderForProductsProduction.MeasurementUnit AS MeasurementUnit,
		|		OrderForProductsProduction.Specification AS Specification,
		|		OrderForProductsProduction.Reserve AS Reserve,
		|		OrderForProductsProduction.Quantity AS Quantity
		|	FROM
		|		Document.ProductionOrder.Products AS OrderForProductsProduction
		|	WHERE
		|		OrderForProductsProduction.Ref = &BasisDocument
		|		AND OrderForProductsProduction.Products.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		ProductionProducts.Products,
		|		ProductionProducts.Characteristic,
		|		ProductionProducts.MeasurementUnit,
		|		ProductionProducts.Specification,
		|		-ProductionProducts.Reserve,
		|		-ProductionProducts.Quantity
		|	FROM
		|		Document.Production.Products AS ProductionProducts
		|	WHERE
		|		ProductionProducts.Ref.Posted
		|		AND ProductionProducts.Ref.BasisDocument = &BasisDocument
		|		AND Not ProductionProducts.Ref = &Ref) AS OrdersBalance
		|
		|GROUP BY
		|	OrdersBalance.Products,
		|	OrdersBalance.Characteristic,
		|	OrdersBalance.MeasurementUnit,
		|	OrdersBalance.Specification
		|
		|HAVING
		|	SUM(OrdersBalance.Quantity) > 0";
		
	Else
		
		TabularSectionName = "Products";
		Query.Text = Query.Text +
		"SELECT
		|	OrdersBalance.Products AS Products,
		|	OrdersBalance.Characteristic AS Characteristic,
		|	OrdersBalance.MeasurementUnit AS MeasurementUnit,
		|	OrdersBalance.Specification AS Specification,
		|	SUM(OrdersBalance.Quantity) AS Quantity
		|FROM
		|	(SELECT
		|		ProductionOrderInventory.Products AS Products,
		|		ProductionOrderInventory.Characteristic AS Characteristic,
		|		ProductionOrderInventory.MeasurementUnit AS MeasurementUnit,
		|		ProductionOrderInventory.Specification AS Specification,
		|		ProductionOrderInventory.Quantity AS Quantity
		|	FROM
		|		Document.ProductionOrder.Inventory AS ProductionOrderInventory
		|	WHERE
		|		ProductionOrderInventory.Ref = &BasisDocument
		|		AND ProductionOrderInventory.Products.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		ProductionInventory.Products,
		|		ProductionInventory.Characteristic,
		|		ProductionInventory.MeasurementUnit,
		|		ProductionInventory.Specification,
		|		-ProductionInventory.Quantity
		|	FROM
		|		Document.Production.Inventory AS ProductionInventory
		|	WHERE
		|		ProductionInventory.Ref.Posted
		|		AND ProductionInventory.Ref.BasisDocument = &BasisDocument
		|		AND Not ProductionInventory.Ref = &Ref) AS OrdersBalance
		|
		|GROUP BY
		|	OrdersBalance.Products,
		|	OrdersBalance.Characteristic,
		|	OrdersBalance.MeasurementUnit,
		|	OrdersBalance.Specification
		|
		|HAVING
		|	SUM(OrdersBalance.Quantity) > 0";
		
	EndIf;
	
	Query.SetParameter("BasisDocument", FillingData);
	Query.SetParameter("Ref", Ref);
	
	ResultsArray = Query.ExecuteBatch();
	BalanceTable = ResultsArray[0].Unload();
	BalanceTable.Indexes.Add("ProductionOrder,Products,Characteristic");
	
	Products.Clear();
	Inventory.Clear();
	Disposals.Clear();
	If BalanceTable.Count() > 0 Then
		
		Selection = ResultsArray[1].Select();
		Selection.Next();
		For Each SelectionProducts In Selection[TabularSectionName].Unload() Do
			
			If SelectionProducts.ProductsType <> Enums.ProductsTypes.InventoryItem Then
				Continue;
			EndIf;
			
			StructureForSearch = New Structure;
			StructureForSearch.Insert("ProductionOrder", FillingData);
			StructureForSearch.Insert("Products", SelectionProducts.Products);
			StructureForSearch.Insert("Characteristic", SelectionProducts.Characteristic);
			
			BalanceRowsArray = BalanceTable.FindRows(StructureForSearch);
			If BalanceRowsArray.Count() = 0 Then
				Continue;
			EndIf;
			
			NewRow = ThisObject[TabularSectionName].Add();
			FillPropertyValues(NewRow, SelectionProducts);
			
			QuantityToWriteOff = SelectionProducts.Quantity * SelectionProducts.Factor;
			BalanceRowsArray[0].QuantityBalance = BalanceRowsArray[0].QuantityBalance - QuantityToWriteOff;
			If BalanceRowsArray[0].QuantityBalance < 0 Then
				
				NewRow.Quantity = (QuantityToWriteOff + BalanceRowsArray[0].QuantityBalance) / SelectionProducts.Factor;
				
			EndIf;
			
			If BalanceRowsArray[0].QuantityBalance <= 0 Then
				BalanceTable.Delete(BalanceRowsArray[0]);
			EndIf;
			
		EndDo;
		
	EndIf;
	
	If Products.Count() > 0 Then
		Selection = ResultsArray[2].Select();
		While Selection.Next() Do
			NewRow = Inventory.Add();
			FillPropertyValues(NewRow, Selection);
		EndDo;
	ElsIf Inventory.Count() > 0 Then
		Selection = ResultsArray[2].Select();
		While Selection.Next() Do
			NewRow = Products.Add();
			FillPropertyValues(NewRow, Selection);
		EndDo;
	EndIf;
	
	// Fill out according to specification.
	If Products.Count() > 0 AND FillingData.Inventory.Count() = 0 Then
		NodesBillsOfMaterialstack = New Array;
		FillTabularSectionBySpecification(NodesBillsOfMaterialstack);
	EndIf;
	
	// Filling out reserves.
	If TabularSectionName = "Products" AND Inventory.Count() > 0
		AND Constants.UseInventoryReservation.Get()
		AND ValueIsFilled(InventoryStructuralUnit) Then
		FillColumnReserveByReserves();
	EndIf;
	
EndProcedure

// Procedure for filling the document basing on Sales order.
//
Procedure FillUsingSalesOrder(FillingData) Export
	
	If OperationKind = Enums.OperationTypesProduction.Disassembly Then
		TabularSectionName = "Inventory";
	Else
		TabularSectionName = "Products";
	EndIf;
	
	Query = New Query( 
	"SELECT
	|	SalesOrderInventory.Ref AS SalesOrder,
	|	DATEADD(SalesOrderInventory.ShipmentDate, DAY, -SalesOrderInventory.Products.ReplenishmentDeadline) AS Start,
	|	SalesOrderInventory.ShipmentDate AS Finish,
	|	SalesOrderInventory.Ref.Company AS Company,
	|	SalesOrderInventory.Ref.SalesStructuralUnit AS StructuralUnit,
	|	CASE
	|		WHEN SalesOrderInventory.Ref.SalesStructuralUnit.TransferRecipient.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Warehouse)
	|				OR SalesOrderInventory.Ref.SalesStructuralUnit.TransferRecipient.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Department)
	|			THEN SalesOrderInventory.Ref.SalesStructuralUnit.TransferRecipient
	|		ELSE VALUE(Catalog.BusinessUnits.EmptyRef)
	|	END AS ProductsStructuralUnit,
	|	CASE
	|		WHEN SalesOrderInventory.Ref.SalesStructuralUnit.TransferRecipient.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Warehouse)
	|				OR SalesOrderInventory.Ref.SalesStructuralUnit.TransferRecipient.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Department)
	|			THEN SalesOrderInventory.Ref.SalesStructuralUnit.TransferRecipientCell
	|		ELSE VALUE(Catalog.Cells.EmptyRef)
	|	END AS ProductsCell,
	|	CASE
	|		WHEN SalesOrderInventory.Ref.SalesStructuralUnit.TransferSource.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Warehouse)
	|				OR SalesOrderInventory.Ref.SalesStructuralUnit.TransferSource.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Department)
	|			THEN SalesOrderInventory.Ref.SalesStructuralUnit.TransferSource
	|		ELSE VALUE(Catalog.BusinessUnits.EmptyRef)
	|	END AS InventoryStructuralUnit,
	|	CASE
	|		WHEN SalesOrderInventory.Ref.SalesStructuralUnit.TransferSource.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Warehouse)
	|				OR SalesOrderInventory.Ref.SalesStructuralUnit.TransferSource.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Department)
	|			THEN SalesOrderInventory.Ref.SalesStructuralUnit.TransferSourceCell
	|		ELSE VALUE(Catalog.Cells.EmptyRef)
	|	END AS CellInventory,
	|	SalesOrderInventory.Ref.SalesStructuralUnit.RecipientOfWastes AS DisposalsStructuralUnit,
	|	SalesOrderInventory.Ref.SalesStructuralUnit.DisposalsRecipientCell AS DisposalsCell,
	|	SalesOrderInventory.Products AS Products,
	|	SalesOrderInventory.Products.ProductsType AS ProductsType,
	|	SalesOrderInventory.Characteristic AS Characteristic,
	|	SalesOrderInventory.MeasurementUnit AS MeasurementUnit,
	|	SalesOrderInventory.Quantity AS Quantity,
	|	SalesOrderInventory.Reserve AS Reserve,
	|	SalesOrderInventory.Specification AS Specification
	|FROM
	|	Document.SalesOrder.Inventory AS SalesOrderInventory
	|WHERE
	|	SalesOrderInventory.Ref = &BasisDocument
	|	AND (SalesOrderInventory.Specification <> VALUE(Catalog.BillsOfMaterials.EmptyRef)
	|			OR SalesOrderInventory.Products.ReplenishmentMethod = VALUE(Enum.InventoryReplenishmentMethods.Production)
	|			OR &OperationKind = VALUE(Enum.OperationTypesProductionOrder.Disassembly))");
	
	Query.SetParameter("BasisDocument", FillingData);
	Query.SetParameter("OperationKind", OperationKind);
	
	Products.Clear();
	Inventory.Clear();
	
	QueryResult = Query.Execute();
	If Not QueryResult.IsEmpty() Then
		
		QueryResultSelection = QueryResult.Select();
		QueryResultSelection.Next();
		FillPropertyValues(ThisObject, QueryResultSelection);
		
		If ValueIsFilled(StructuralUnit) Then
			
			If Not ValueIsFilled(ProductsStructuralUnit) Then
				ProductsStructuralUnit = StructuralUnit;
			EndIf;
			
			If Not ValueIsFilled(InventoryStructuralUnit) Then
				InventoryStructuralUnit = StructuralUnit;
			EndIf;
			
			If Not ValueIsFilled(DisposalsStructuralUnit) Then
				DisposalsStructuralUnit = StructuralUnit;
			EndIf;
			
		EndIf;
		
		QueryResultSelection.Reset();
		While QueryResultSelection.Next() Do
		
			If ValueIsFilled(QueryResultSelection.Products) Then
			
				If QueryResultSelection.ProductsType <> Enums.ProductsTypes.InventoryItem Then
					Continue;
				EndIf;
				
				NewRow = ThisObject[TabularSectionName].Add();
				FillPropertyValues(NewRow, QueryResultSelection);
				
				If Not ValueIsFilled(NewRow.Specification) Then
					NewRow.Specification = DriveServer.GetDefaultSpecification(NewRow.Products, NewRow.Characteristic);
				EndIf;
				
			EndIf;
		
		EndDo;
		
		If Products.Count() > 0 Then
			NodesBillsOfMaterialstack = New Array;
			FillTabularSectionBySpecification(NodesBillsOfMaterialstack);
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region EventHandlers

// Procedure - event handler FillingProcessor object.
//
Procedure Filling(FillingData, StandardProcessing) Export
	
	If TypeOf(FillingData) = Type("DocumentRef.SalesOrder") Then
		FillUsingSalesOrder(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.ProductionOrder") Then
		FillByProductionOrder(FillingData);
	EndIf;
	
	GLAccountsInDocuments.FillTabSectionFromProductGLAccounts(ThisObject, FillingData);
	
EndProcedure

// Procedure - BeforeWrite event handler.
//
Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	ProductsList = "";
	FOUseCharacteristics = Constants.UseCharacteristics.Get();
	For Each StringProducts In Products Do
		
		If Not ValueIsFilled(StringProducts.Products) Then
			Continue;
		EndIf;
		
		CharacteristicPresentation = "";
		If FOUseCharacteristics AND ValueIsFilled(StringProducts.Characteristic) Then
			CharacteristicPresentation = " (" + TrimAll(StringProducts.Characteristic) + ")";
		EndIf;
		
		If ValueIsFilled(ProductsList) Then
			ProductsList = ProductsList + Chars.LF;
		EndIf;
		ProductsList = ProductsList + TrimAll(StringProducts.Products) + CharacteristicPresentation + ", " + StringProducts.Quantity + " " + TrimAll(StringProducts.MeasurementUnit);
		
	EndDo;
	
	AdditionalProperties.Insert("WriteMode", WriteMode);
	
EndProcedure

// Procedure - event handler FillCheckProcessing object.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Inventory.Total("Reserve") > 0 Then
		
		If Not ValueIsFilled(SalesOrder) Then
			
			MessageText = NStr("en = 'Sales order which is a reserve source is not specified.'");
			DriveServer.ShowMessageAboutError(ThisObject, MessageText,,,"SalesOrder",Cancel);
			
		EndIf;
		
	EndIf;
	
	If Constants.UseInventoryReservation.Get() Then
		
		If OperationKind = Enums.OperationTypesProduction.Assembly Then
			
			For Each StringInventory In Inventory Do
				
				If StringInventory.Reserve > StringInventory.Quantity Then
					
					MessageText = NStr("en = 'In row #%Number% of the ""Inventory"" tabular section, the number of items for write-off from reserve exceeds the total inventory quantity.'");
					MessageText = StrReplace(MessageText, "%Number%", StringInventory.LineNumber);
					DriveServer.ShowMessageAboutError(
						ThisObject,
						MessageText,
						"Inventory",
						StringInventory.LineNumber,
						"Reserve",
						Cancel
					);
					
				EndIf;
				
			EndDo;
			
		Else
			
			For Each StringProducts In Products Do
				
				If StringProducts.Reserve > StringProducts.Quantity Then
					
					MessageText = NStr("en = 'In row #%Number% of the ""Products"" tabular section, the number of items for write-off from reserve exceeds the total inventory quantity.'");
					MessageText = StrReplace(MessageText, "%Number%", StringProducts.LineNumber);
					DriveServer.ShowMessageAboutError(
						ThisObject,
						MessageText,
						"Products",
						StringProducts.LineNumber,
						"Reserve",
						Cancel
					);
					
				EndIf;
				
			EndDo;
			
		EndIf;
		
	EndIf;
	
	// Serial numbers
	WorkWithSerialNumbers.FillCheckingSerialNumbers(Cancel, Products, SerialNumbersProducts, StructuralUnit, ThisObject);
	WorkWithSerialNumbers.FillCheckingSerialNumbers(Cancel, Inventory, SerialNumbers, StructuralUnit, ThisObject);
	
EndProcedure

// Procedure - event handler FillingProcessor object.
//
Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Initialization of document data
	Documents.Production.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Preparation of record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Registering in accounting sections
	DriveServer.ReflectInventory(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectInventoryInWarehouses(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectProductRelease(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectInventoryAccepted(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectInventoryDemand(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectProductionOrders(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectBackorders(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingJournalEntries(AdditionalProperties, RegisterRecords, Cancel);
	
	// SerialNumbers
	DriveServer.ReflectTheSerialNumbersOfTheGuarantee(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectTheSerialNumbersBalance(AdditionalProperties, RegisterRecords, Cancel);
	
	// Writing of record sets
	DriveServer.WriteRecordSets(ThisObject);
	
	// Control
	Documents.Production.RunControl(Ref, AdditionalProperties, Cancel);
	
	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
EndProcedure

// Procedure - event handler UndoPosting object.
//
Procedure UndoPosting(Cancel)
	
	// Initialization of additional properties for document posting
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Preparation of record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Writing of record sets
	DriveServer.WriteRecordSets(ThisObject);
	
	// Control
	Documents.Production.RunControl(Ref, AdditionalProperties, Cancel, True);
	
EndProcedure

#EndRegion

#EndIf
