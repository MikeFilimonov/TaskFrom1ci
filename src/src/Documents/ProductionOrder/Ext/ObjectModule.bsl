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
	Inventory.GroupBy("Products, Characteristic, MeasurementUnit, Specification", "Quantity, Reserve");
	
EndProcedure

// Procedure fills the Quantity column by free balances at warehouse.
//
Procedure FillColumnReserveByBalances() Export
	
	Inventory.LoadColumn(New Array(Inventory.Count()), "Reserve");
	
	TempTablesManager = New TempTablesManager;
	
	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	Query.Text =
	"SELECT
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	VALUE(Catalog.ProductsBatches.EmptyRef) AS Batch
	|INTO TemporaryTableInventory
	|FROM
	|	&TableInventory AS TableInventory";
	
	Query.SetParameter("TableInventory", Inventory.Unload());
	Query.Execute();
	
	Query.Text =
	"SELECT
	|	InventoryBalances.Company AS Company,
	|	InventoryBalances.StructuralUnit AS StructuralUnit,
	|	InventoryBalances.GLAccount AS GLAccount,
	|	InventoryBalances.Products AS Products,
	|	InventoryBalances.Characteristic AS Characteristic,
	|	InventoryBalances.Batch AS Batch,
	|	SUM(InventoryBalances.QuantityBalance) AS QuantityBalance
	|FROM
	|	(SELECT
	|		InventoryBalances.Company AS Company,
	|		InventoryBalances.StructuralUnit AS StructuralUnit,
	|		InventoryBalances.GLAccount AS GLAccount,
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
	|						CASE
	|							WHEN &StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Department)
	|								THEN TableInventory.Products.ExpensesGLAccount
	|							ELSE TableInventory.Products.InventoryGLAccount
	|						END,
	|						TableInventory.Products,
	|						TableInventory.Characteristic,
	|						TableInventory.Batch,
	|						UNDEFINED AS SalesOrder
	|					FROM
	|						TemporaryTableInventory AS TableInventory)) AS InventoryBalances
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
	|		AND DocumentRegisterRecordsInventory.RecordType = VALUE(AccumulationRecordType.Expense)) AS InventoryBalances
	|
	|GROUP BY
	|	InventoryBalances.Company,
	|	InventoryBalances.StructuralUnit,
	|	InventoryBalances.GLAccount,
	|	InventoryBalances.Products,
	|	InventoryBalances.Characteristic,
	|	InventoryBalances.Batch";
	
	Query.SetParameter("Period", Date);
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("Company", DriveServer.GetCompany(Company));
	Query.SetParameter("StructuralUnit", StructuralUnitReserve);
	Query.SetParameter("StructuralUnitType", StructuralUnitReserve.StructuralUnitType);
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	While Selection.Next() Do
		
		StructureForSearch = New Structure;
		StructureForSearch.Insert("Products", Selection.Products);
		StructureForSearch.Insert("Characteristic", Selection.Characteristic);
		
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
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	ProductionOrder.Start AS Start,
	|	ProductionOrder.Start AS Finish,
	|	ProductionOrder.OperationKind AS OperationKind,
	|	ProductionOrder.Ref AS BasisDocument,
	|	CASE
	|		WHEN UseInventoryReservation.Value
	|			THEN ProductionOrder.SalesOrder
	|		ELSE VALUE(Document.SalesOrder.EmptyRef)
	|	END AS SalesOrder,
	|	ProductionOrder.Company AS Company,
	|	ProductionOrder.StructuralUnit AS StructuralUnit,
	|	CASE
	|		WHEN ProductionOrder.StructuralUnitReserve = VALUE(Catalog.BusinessUnits.EmptyRef)
	|				AND (ProductionOrder.StructuralUnit.TransferSource.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Warehouse)
	|					OR ProductionOrder.StructuralUnit.TransferSource.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Department))
	|			THEN ProductionOrder.StructuralUnit.TransferSource
	|		ELSE ProductionOrder.StructuralUnitReserve
	|	END AS StructuralUnitReserve,
	|	ProductionOrder.Inventory.(
	|		Products AS Products,
	|		Characteristic AS Characteristic,
	|		MeasurementUnit AS MeasurementUnit,
	|		Quantity AS Quantity,
	|		Specification AS Specification,
	|		Products.ProductsType AS ProductsType,
	|		Products.ReplenishmentMethod AS ReplenishmentMethod
	|	)
	|FROM
	|	Document.ProductionOrder AS ProductionOrder,
	|	Constant.UseInventoryReservation AS UseInventoryReservation
	|WHERE
	|	ProductionOrder.Ref = &BasisDocument";
	
	Query.SetParameter("BasisDocument", FillingData);
	
	Products.Clear();
	Inventory.Clear();
	QueryResult = Query.Execute();
	If Not QueryResult.IsEmpty() Then
		
		QueryResultSelection = QueryResult.Select();
		QueryResultSelection.Next();
		FillPropertyValues(ThisObject, QueryResultSelection);
		
		For Each StringInventory In QueryResultSelection.Inventory.Unload() Do
			If Not ValueIsFilled(StringInventory.Products) Then
				Continue;
			EndIf;
			If StringInventory.Quantity <=0 Then
				Continue;
			EndIf;
			If Not ValueIsFilled(StringInventory.Specification) 
				AND StringInventory.ReplenishmentMethod = Enums.InventoryReplenishmentMethods.Purchase Then
				Continue;
			EndIf; 
			NewRow = Products.Add();
			FillPropertyValues(NewRow, StringInventory);
		EndDo;
		
		If Products.Count() > 0 Then
			NodesBillsOfMaterialstack = New Array;
			FillTabularSectionBySpecification(NodesBillsOfMaterialstack);
		EndIf;
		
	EndIf;
	
EndProcedure

// Procedure for filling the document basing on Sales order.
//
Procedure FillUsingSalesOrder(FillingData) Export
	
	If OperationKind = Enums.OperationTypesProductionOrder.Disassembly Then
		TabularSectionName = "Inventory";
	Else
		TabularSectionName = "Products";
	EndIf;
	
	// Header filling.
	Query = New Query;
	Query.Text =
	"SELECT
	|	SalesOrder.Ref AS BasisRef,
	|	SalesOrder.Posted AS BasisPosted,
	|	SalesOrder.Closed AS BasisClosed,
	|	SalesOrder.OrderState AS BasisState,
	|	SalesOrder.OperationKind AS BasisOperationKind,
	|	CASE
	|		WHEN UseInventoryReservation.Value
	|			THEN SalesOrder.Ref
	|		ELSE VALUE(Document.SalesOrder.EmptyRef)
	|	END AS SalesOrder,
	|	SalesOrder.Company AS Company,
	|	CASE
	|		WHEN SalesOrder.SalesStructuralUnit.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Department)
	|			THEN SalesOrder.SalesStructuralUnit
	|		ELSE VALUE(Catalog.BusinessUnits.EmptyRef)
	|	END AS StructuralUnit,
	|	CASE
	|		WHEN SalesOrder.SalesStructuralUnit.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Department)
	|				AND SalesOrder.StructuralUnitReserve = VALUE(Catalog.BusinessUnits.EmptyRef)
	|				AND (SalesOrder.SalesStructuralUnit.TransferSource.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Warehouse)
	|					OR SalesOrder.SalesStructuralUnit.TransferSource.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Department))
	|			THEN SalesOrder.SalesStructuralUnit.TransferSource
	|		ELSE SalesOrder.StructuralUnitReserve
	|	END AS StructuralUnitReserve,
	|	BEGINOFPERIOD(SalesOrder.ShipmentDate, Day) AS Start,
	|	ENDOFPERIOD(SalesOrder.ShipmentDate, Day) AS Finish
	|FROM
	|	Document.SalesOrder AS SalesOrder,
	|	Constant.UseInventoryReservation AS UseInventoryReservation
	|WHERE
	|	SalesOrder.Ref = &BasisDocument";
	
	Query.SetParameter("BasisDocument", FillingData);
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		VerifiedAttributesValues = New Structure("OperationKind, OrderStatus, Closed, Posted", Selection.BasisOperationKind, Selection.BasisState, Selection.BasisClosed, Selection.BasisPosted);
		Documents.SalesOrder.CheckAbilityOfEnteringBySalesOrder(Selection.BasisRef, VerifiedAttributesValues);
	EndIf;
	
	FillPropertyValues(ThisObject, Selection);
	
	If Not ValueIsFilled(StructuralUnit) Then
		SettingValue = DriveReUse.GetValueOfSetting("MainDepartment");
		If Not ValueIsFilled(SettingValue) Then
			StructuralUnit = Catalogs.BusinessUnits.MainDepartment;
		EndIf;
	EndIf;
	
	BasisOperationKind = Selection.BasisOperationKind;
	
	// Filling out tabular section.
	Query = New Query;
	Query.Text =
	"SELECT
	|	OrdersBalance.Products AS Products,
	|	OrdersBalance.Characteristic AS Characteristic,
	|	SUM(OrdersBalance.QuantityBalance) AS QuantityBalance
	|FROM
	|	(SELECT
	|		OrdersBalance.Products AS Products,
	|		OrdersBalance.Characteristic AS Characteristic,
	|		OrdersBalance.QuantityBalance AS QuantityBalance
	|	FROM
	|		AccumulationRegister.SalesOrders.Balance(, SalesOrder = &BasisDocument) AS OrdersBalance
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		InventoryBalances.Products,
	|		InventoryBalances.Characteristic,
	|		-InventoryBalances.QuantityBalance
	|	FROM
	|		AccumulationRegister.Inventory.Balance(, SalesOrder = &BasisDocument) AS InventoryBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		PlacementBalances.Products,
	|		PlacementBalances.Characteristic,
	|		-PlacementBalances.QuantityBalance
	|	FROM
	|		AccumulationRegister.Backorders.Balance(, SalesOrder = &BasisDocument) AS PlacementBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsBackorders.Products,
	|		DocumentRegisterRecordsBackorders.Characteristic,
	|		CASE
	|			WHEN DocumentRegisterRecordsBackorders.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN -ISNULL(DocumentRegisterRecordsBackorders.Quantity, 0)
	|			ELSE ISNULL(DocumentRegisterRecordsBackorders.Quantity, 0)
	|		END
	|	FROM
	|		AccumulationRegister.Backorders AS DocumentRegisterRecordsBackorders
	|	WHERE
	|		DocumentRegisterRecordsBackorders.Recorder = &Ref
	|		AND DocumentRegisterRecordsBackorders.SalesOrder = &BasisDocument) AS OrdersBalance
	|
	|GROUP BY
	|	OrdersBalance.Products,
	|	OrdersBalance.Characteristic
	|
	|HAVING
	|	SUM(OrdersBalance.QuantityBalance) > 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(SalesOrderInventory.LineNumber) AS LineNumber,
	|	SalesOrderInventory.Products AS Products,
	|	SalesOrderInventory.Characteristic AS Characteristic,
	|	CASE
	|		WHEN VALUETYPE(SalesOrderInventory.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN 1
	|		ELSE SalesOrderInventory.MeasurementUnit.Factor
	|	END AS Factor,
	|	SalesOrderInventory.MeasurementUnit AS MeasurementUnit,
	|	SalesOrderInventory.Specification AS Specification,
	|	SalesOrderInventory.Products.ProductsType AS ProductsType,
	|	SUM(SalesOrderInventory.Quantity) AS Quantity
	|FROM
	|	Document.SalesOrder.Inventory AS SalesOrderInventory
	|WHERE
	|	SalesOrderInventory.Ref = &BasisDocument
	|	AND (SalesOrderInventory.Specification <> VALUE(Catalog.BillsOfMaterials.EmptyRef)
	|			OR SalesOrderInventory.Products.ReplenishmentMethod = VALUE(Enum.InventoryReplenishmentMethods.Production)
	|			OR &OperationKind = VALUE(Enum.OperationTypesProductionOrder.Disassembly))
	|
	|GROUP BY
	|	SalesOrderInventory.Products,
	|	SalesOrderInventory.Characteristic,
	|	SalesOrderInventory.MeasurementUnit,
	|	SalesOrderInventory.Products.ProductsType,
	|	CASE
	|		WHEN VALUETYPE(SalesOrderInventory.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN 1
	|		ELSE SalesOrderInventory.MeasurementUnit.Factor
	|	END,
	|	SalesOrderInventory.Specification
	|
	|ORDER BY
	|	LineNumber";
	
	Query.SetParameter("BasisDocument", FillingData);
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("OperationKind", OperationKind);
	
	ResultsArray = Query.ExecuteBatch();
	BalanceTable = ResultsArray[0].Unload();
	BalanceTable.Indexes.Add("Products,Characteristic");
	
	Products.Clear();
	Inventory.Clear();
	If BalanceTable.Count() > 0 Then
		
		Selection = ResultsArray[1].Select();
		While Selection.Next() Do
			
			If TabularSectionName = "Inventory"
				AND Selection.ProductsType <> Enums.ProductsTypes.InventoryItem Then
				Continue;
			EndIf;
			
			StructureForSearch = New Structure;
			StructureForSearch.Insert("Products", Selection.Products);
			StructureForSearch.Insert("Characteristic", Selection.Characteristic);
			
			BalanceRowsArray = BalanceTable.FindRows(StructureForSearch);
			If BalanceRowsArray.Count() = 0 Then
				Continue;
			EndIf;
			
			NewRow = ThisObject[TabularSectionName].Add();
			FillPropertyValues(NewRow, Selection);
			
			If Not ValueIsFilled(NewRow.Specification) Then
				NewRow.Specification = DriveServer.GetDefaultSpecification(NewRow.Products, NewRow.Characteristic);
			EndIf;
			
			QuantityToWriteOff = Selection.Quantity * Selection.Factor;
			BalanceRowsArray[0].QuantityBalance = BalanceRowsArray[0].QuantityBalance - QuantityToWriteOff;
			If BalanceRowsArray[0].QuantityBalance < 0 Then
				
				NewRow.Quantity = (QuantityToWriteOff + BalanceRowsArray[0].QuantityBalance) / Selection.Factor;
				
			EndIf;
			
			If BalanceRowsArray[0].QuantityBalance <= 0 Then
				BalanceTable.Delete(BalanceRowsArray[0]);
			EndIf;
			
		EndDo;
		
	EndIf;
	
	If Products.Count() > 0 Then
		NodesBillsOfMaterialstack = New Array;
		FillTabularSectionBySpecification(NodesBillsOfMaterialstack);
	EndIf;
	
EndProcedure

// Procedure fills document when copying.
//
Procedure FillOnCopy()
	
	If Constants.UseProductionOrderStatuses.Get() Then
		User = Users.CurrentUser();
		SettingValue = DriveReUse.GetValueByDefaultUser(User, "StatusOfNewProductionOrder");
		If ValueIsFilled(SettingValue) Then
			If OrderState <> SettingValue Then
				OrderState = SettingValue;
			EndIf;
		Else
			OrderState = Catalogs.ProductionOrderStatuses.Open;
		EndIf;
	Else
		OrderState = Constants.ProductionOrdersInProgressStatus.Get();
	EndIf;
	
	Closed = False;
	
EndProcedure

#EndRegion

#Region EventHandlers

// Procedure - event handler of the OnCopy object.
//
Procedure OnCopy(CopiedObject)
	
	FillOnCopy();
	
EndProcedure

// Procedure - event handler FillingProcessor object.
//
Procedure Filling(FillingData, StandardProcessing) Export
	
	If Not ValueIsFilled(FillingData) Then
		Return;
	EndIf;
	
	If TypeOf(FillingData) = Type("Structure")
		AND FillingData.Property("DemandPlanning") Then
		NodesBillsOfMaterialstack = New Array;
		FillTabularSectionBySpecification(NodesBillsOfMaterialstack);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.SalesOrder") Then
		FillUsingSalesOrder(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.ProductionOrder") Then
		FillByProductionOrder(FillingData);
	EndIf;
	
EndProcedure

// Procedure - BeforeWrite event handler.
//
Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Closed And OrderState = DriveReUse.GetOrderStatus("ProductionOrderStatuses", "Completed") Then 
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'You cannot make changes to a completed %1.'"), Ref);
		CommonUseClientServer.MessageToUser(MessageText,,,,);
		Return;
	EndIf;
	
	ResourcesList = "";
	For Each RowResource In CompanyResources Do
		ResourcesList = ResourcesList + ?(ResourcesList = "","","; " + Chars.LF) + TrimAll(RowResource.CompanyResource);
	EndDo;
	
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
	
	If (Inventory.Total("Reserve") > 0 OR Products.Total("Reserve") > 0)
		AND Not ValueIsFilled(StructuralUnitReserve) Then
		
		MessageText = NStr("en = 'Reserve warehouse is not specified.'");
		DriveServer.ShowMessageAboutError(ThisObject, MessageText,,, "StructuralUnitReserve", Cancel);
		
	EndIf;
	
	If Constants.UseInventoryReservation.Get() Then
		
		If OperationKind = Enums.OperationTypesProductionOrder.Assembly Then
			
			For Each StringInventory In Inventory Do
				
				If StringInventory.Reserve > StringInventory.Quantity Then
					
					MessageText = NStr("en = 'In line #%Number% of tablular section ""Materials"" quantity of reserved positions exceeds the total materials.'");
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
					
					MessageText = NStr("en = 'In line #%Number% of tabular section ""Goods"" quantity of the reserved positions exceeds the total goods.'");
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
	
	If Inventory.Count() > 0 Then
		
		FilterStructure = New Structure("ProductsType", Enums.ProductsTypes.Service);
		ArrayOfStringsServices = Products.FindRows(FilterStructure);
		If Products.Count() = ArrayOfStringsServices.Count() Then
			
			MessageText = NStr("en = 'Demand for materials is not planned for services.
			                   |Services only are indicated in the tabular section ""Products"". It is necessary to clear the tabular section ""Materials"".'");
			DriveServer.ShowMessageAboutError(ThisObject, MessageText,,,, Cancel);
			
		EndIf;
		
	EndIf;
	
	If Not Constants.UseProductionOrderStatuses.Get() Then
		
		If Not ValueIsFilled(OrderState) Then
			MessageText = NStr("en = 'The ""Order state"" field is not filled. Specify state values in the accounting parameter settings.'");
			DriveServer.ShowMessageAboutError(ThisObject, MessageText, , , "OrderState", Cancel);
		EndIf;
		
	EndIf;
	
EndProcedure

// Procedure - event handler FillingProcessor object.
//
Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Initialization of document data
	Documents.ProductionOrder.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Preparation of record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Registering in accounting sections
	DriveServer.ReflectInventoryFlowCalendar(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectProductionOrders(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectInventoryDemand(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectBackorders(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectInventory(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectProductRelease(AdditionalProperties, RegisterRecords, Cancel);
	
	// Writing of record sets
	DriveServer.WriteRecordSets(ThisObject);
	
	// Control
	Documents.ProductionOrder.RunControl(Ref, AdditionalProperties, Cancel);
	
	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
EndProcedure

// Procedure - event handler UndoPosting object.
//
Procedure UndoPosting(Cancel)
	
	Closed = False;
	
	// Initialization of additional properties for document posting
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Preparation of record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Writing of record sets
	DriveServer.WriteRecordSets(ThisObject);
	
	// Control
	Documents.ProductionOrder.RunControl(Ref, AdditionalProperties, Cancel, True);
	
EndProcedure

#EndRegion

#EndIf
