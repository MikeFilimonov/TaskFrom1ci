#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProgramInterface
// Procedure fills team members.
//
Procedure FillTeamMembers() Export

	If ValueIsFilled(Performer) AND TypeOf(Performer) = Type("CatalogRef.Teams") Then
		
		Query = New Query;
		Query.Text = 
		"SELECT
		|	WorkgroupsContent.Employee,
		|	1 AS LPF
		|FROM
		|	Catalog.Teams.Content AS WorkgroupsContent
		|WHERE
		|	WorkgroupsContent.Ref = &Ref";
		
		Query.SetParameter("Ref", Performer);	
		
		TeamMembers.Load(Query.Execute().Unload());
		
	EndIf;	

EndProcedure

// Procedure fills tabular section according to specification.
//
Procedure FillTableBySpecification(BySpecification, ByMeasurementUnit, ByQuantity, TableContent)
	
	Query = New Query(
	"SELECT
	|	MAX(BillsOfMaterialsContent.LineNumber) AS BillsOfMaterialsContentLineNumber,
	|	BillsOfMaterialsContent.Products AS Products,
	|	BillsOfMaterialsContent.ContentRowType AS ContentRowType,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN BillsOfMaterialsContent.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	BillsOfMaterialsContent.Specification AS Specification,
	|	BillsOfMaterialsContent.CostPercentage AS CostPercentage,
	|	BillsOfMaterialsContent.MeasurementUnit AS MeasurementUnit,
	|	SUM(BillsOfMaterialsContent.Quantity / BillsOfMaterialsContent.ProductsQuantity * &Factor * &Quantity) AS Quantity
	|FROM
	|	Catalog.BillsOfMaterials.Content AS BillsOfMaterialsContent
	|WHERE
	|	BillsOfMaterialsContent.Ref = &Specification
	|	AND BillsOfMaterialsContent.Products.ProductsType = &ProductsType
	|
	|GROUP BY
	|	BillsOfMaterialsContent.Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN BillsOfMaterialsContent.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END,
	|	BillsOfMaterialsContent.Specification,
	|	BillsOfMaterialsContent.MeasurementUnit,
	|	BillsOfMaterialsContent.ContentRowType,
	|	BillsOfMaterialsContent.CostPercentage
	|
	|ORDER BY
	|	BillsOfMaterialsContentLineNumber");
	
	Query.SetParameter("UseCharacteristics", Constants.UseCharacteristics.Get());
	
	Query.SetParameter("Specification", BySpecification);
	Query.SetParameter("Quantity", ByQuantity);
	
	If TypeOf(ByMeasurementUnit) = Type("CatalogRef.UOM")
		AND ValueIsFilled(ByMeasurementUnit) Then
		ByFactor = ByMeasurementUnit.Factor;
	Else
		ByFactor = 1;
	EndIf;
	Query.SetParameter("Factor", ByFactor);
	Query.SetParameter("ProductsType", Enums.ProductsTypes.InventoryItem);
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		
		If Selection.ContentRowType = Enums.BOMLineType.Node Then
			
			FillTableBySpecification(Selection.Specification, Selection.MeasurementUnit, Selection.Quantity, TableContent);
			
		Else
			
			NewRow = TableContent.Add();
			FillPropertyValues(NewRow, Selection);
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Procedure for filling the document basing on Sales order.
//
Procedure FillUsingSalesOrder(FillingData)
	
	AttributeValues = CommonUse.ObjectAttributesValues(FillingData,
			New Structure("Company, OperationKind, SalesStructuralUnit, Start, Finish, ShipmentDate"));
	
	Company = AttributeValues.Company;
	StructuralUnit = AttributeValues.SalesStructuralUnit;
	DocumentCurrency = Catalogs.PriceTypes.Accounting.PriceCurrency;
	
	ClosingDate = AttributeValues.ShipmentDate;
	Period = ?(ValueIsFilled(AttributeValues.ShipmentDate), AttributeValues.ShipmentDate, CurrentDate());
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	&Period AS Period,
	|	SalesOrderInventory.LineNumber AS LineNumber,
	|	SalesOrderInventory.Ref AS SalesOrder,
	|	SalesOrderInventory.Products AS Products,
	|	SalesOrderInventory.Characteristic AS Characteristic,
	|	SalesOrderInventory.Batch AS Batch,
	|	SalesOrderInventory.Quantity AS QuantityPlan,
	|	SalesOrderInventory.Specification AS Specification,
	|	OperationSpecification.Operation,
	|	OperationSpecification.Operation.MeasurementUnit AS MeasurementUnit,
	|	ISNULL(OperationSpecification.TimeNorm, 0) / ISNULL(OperationSpecification.ProductsQuantity, 1) * CASE
	|		WHEN VALUETYPE(SalesOrderInventory.MeasurementUnit) = TYPE(Catalog.UOM)
	|				AND SalesOrderInventory.MeasurementUnit <> VALUE(Catalog.UOM.EmptyRef)
	|			THEN SalesOrderInventory.MeasurementUnit.Factor
	|		ELSE 1
	|	END AS TimeNorm,
	|	ISNULL(PricesSliceLast.Price / ISNULL(PricesSliceLast.MeasurementUnit.Factor, 1), 0) AS Tariff
	|FROM
	|	Document.SalesOrder.Inventory AS SalesOrderInventory
	|		LEFT JOIN Catalog.BillsOfMaterials.Operations AS OperationSpecification
	|			LEFT JOIN InformationRegister.Prices.SliceLast(&Period, PriceKind = VALUE(Catalog.PriceTypes.Accounting)) AS PricesSliceLast
	|			ON OperationSpecification.Operation = PricesSliceLast.Products
	|		ON SalesOrderInventory.Specification = OperationSpecification.Ref
	|WHERE
	|	SalesOrderInventory.Ref = &BasisDocument
	|	AND (SalesOrderInventory.Products.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
	|			OR SalesOrderInventory.Products.ProductsType = VALUE(Enum.ProductsTypes.Work))
	|	AND (SalesOrderInventory.Specification <> VALUE(Catalog.BillsOfMaterials.EmptyRef)
	|			OR SalesOrderInventory.Products.ReplenishmentMethod = VALUE(Enum.InventoryReplenishmentMethods.Production))
	|
	|ORDER BY
	|	LineNumber";
	
	Query.SetParameter("BasisDocument", FillingData);
	Query.SetParameter("Period", Period);
	
	Operations.Clear();
	QueryResult = Query.Execute();
	If Not QueryResult.IsEmpty() Then
		Selection = QueryResult.Select();
		While Selection.Next() Do
			NewRow = Operations.Add();
			FillPropertyValues(NewRow, Selection);
		EndDo;
		
	EndIf
	
EndProcedure

#EndRegion

#Region EventHandlers

// IN the event handler of the FillingProcessor document
// - document filling by inventory reconciliation in the warehouse.
//
Procedure Filling(FillingData, StandardProcessing) Export
	
	If Not ValueIsFilled(FillingData) Then
		Return;
	EndIf;
	
	If TypeOf(FillingData) = Type("Structure") Then
		
		FillPropertyValues(ThisObject, FillingData);
		
		If FillingData.Property("Operations") Then
			For Each StringOperations In FillingData.Operations Do
				NewRow = Operations.Add();
				FillPropertyValues(NewRow, StringOperations);
			EndDo;
		EndIf;
		
	ElsIf TypeOf(FillingData) = Type("DocumentRef.SalesOrder") Then
		
		FillUsingSalesOrder(FillingData);
		
	ElsIf TypeOf(FillingData) = Type("DocumentRef.ProductionOrder") Then
		
		If FillingData.StructuralUnit.StructuralUnitType = Enums.BusinessUnitsTypes.Warehouse Then
			
			Raise NStr("en = 'Please select a production order with a department specified as a manufacturer.'");
			
		ElsIf FillingData.OperationKind = Enums.OperationTypesProductionOrder.Assembly Then
			
			Query = New Query;
			Query.Text =
			"SELECT
			|	OrderForProductsProduction.Ref.Company AS Company,
			|	OrderForProductsProduction.Ref.StructuralUnit AS StructuralUnit,
			|	OrderForProductsProduction.Ref.Finish AS ClosingDate,
			|	&Period AS Period,
			|	OrderForProductsProduction.Ref.SalesOrder AS SalesOrder,
			|	OrderForProductsProduction.Products AS Products,
			|	OrderForProductsProduction.Characteristic AS Characteristic,
			|	OrderForProductsProduction.Quantity AS QuantityPlan,
			|	OrderForProductsProduction.Specification AS Specification,
			|	OperationSpecification.Operation,
			|	OperationSpecification.Operation.MeasurementUnit AS MeasurementUnit,
			|	ISNULL(OperationSpecification.TimeNorm, 0) / ISNULL(OperationSpecification.ProductsQuantity, 1) * CASE
			|		WHEN VALUETYPE(OrderForProductsProduction.MeasurementUnit) = Type(Catalog.UOM)
			|				AND OrderForProductsProduction.MeasurementUnit <> VALUE(Catalog.UOM.EmptyRef)
			|			THEN OrderForProductsProduction.MeasurementUnit.Factor
			|		ELSE 1
			|	END AS TimeNorm,
			|	ISNULL(PricesSliceLast.Price / ISNULL(PricesSliceLast.MeasurementUnit.Factor, 1), 0) AS Tariff
			|FROM
			|	Document.ProductionOrder.Products AS OrderForProductsProduction
			|		LEFT JOIN Catalog.BillsOfMaterials.Operations AS OperationSpecification
			|			LEFT JOIN InformationRegister.Prices.SliceLast(&Period, PriceKind = VALUE(Catalog.PriceTypes.Accounting)) AS PricesSliceLast
			|			ON OperationSpecification.Operation = PricesSliceLast.Products
			|		ON OrderForProductsProduction.Specification = OperationSpecification.Ref
			|WHERE
			|	OrderForProductsProduction.Ref = &BasisDocument";
			
			Query.SetParameter("BasisDocument", FillingData);
			Query.SetParameter("Period", ?(ValueIsFilled(FillingData.Start), FillingData.Start, CurrentDate()));
			
			QueryResult = Query.Execute();
			If Not QueryResult.IsEmpty() Then
				
				QueryResultSelection = QueryResult.Select();
				QueryResultSelection.Next();
				FillPropertyValues(ThisObject, QueryResultSelection);
				DocumentCurrency = Catalogs.PriceTypes.Accounting.PriceCurrency;
				
				QueryResultSelection.Reset();
				Operations.Clear();
				While QueryResultSelection.Next() Do
					NewRow = Operations.Add();
					FillPropertyValues(NewRow, QueryResultSelection);
				EndDo;
				
			EndIf
			
		Else
			
			TableContent = New ValueTable;
			
			Array = New Array;
			
			Array.Add(Type("CatalogRef.Products"));
			TypeDescription = New TypeDescription(Array, ,);
			Array.Clear();
			TableContent.Columns.Add("Products", TypeDescription);
			
			Array.Add(Type("CatalogRef.ProductsCharacteristics"));
			TypeDescription = New TypeDescription(Array, ,);
			Array.Clear();
			TableContent.Columns.Add("Characteristic", TypeDescription);
			
			Array.Add(Type("CatalogRef.BillsOfMaterials"));
			TypeDescription = New TypeDescription(Array, ,);
			Array.Clear();
			TableContent.Columns.Add("Specification", TypeDescription);
			
			Array.Add(Type("Number"));
			TypeDescription = New TypeDescription(Array, ,);
			TableContent.Columns.Add("Quantity", TypeDescription);
			
			Array.Add(Type("Number"));
			TypeDescription = New TypeDescription(Array, ,);
			TableContent.Columns.Add("CostPercentage", TypeDescription);
			
			Query = New Query;
			Query.Text =
			"SELECT
			|	&Period AS Period,
			|	OrderForProductsProduction.Ref.Company AS Company,
			|	OrderForProductsProduction.Ref.StructuralUnit AS StructuralUnit,
			|	OrderForProductsProduction.Ref.Finish AS ClosingDate,
			|	OrderForProductsProduction.Ref.SalesOrder AS SalesOrder,
			|	OrderForProductsProduction.Products AS Products,
			|	OrderForProductsProduction.Characteristic AS Characteristic,
			|	OrderForProductsProduction.MeasurementUnit AS MeasurementUnit,
			|	OrderForProductsProduction.Quantity AS Quantity,
			|	OrderForProductsProduction.Specification AS Specification,
			|	OperationSpecification.Operation AS Operation,
			|	OperationSpecification.Operation.MeasurementUnit AS OperationMeasurementUnit,
			|	ISNULL(OperationSpecification.TimeNorm, 0) / ISNULL(OperationSpecification.ProductsQuantity, 1) * CASE
			|		WHEN VALUETYPE(OrderForProductsProduction.MeasurementUnit) = Type(Catalog.UOM)
			|				AND OrderForProductsProduction.MeasurementUnit <> VALUE(Catalog.UOM.EmptyRef)
			|			THEN OrderForProductsProduction.MeasurementUnit.Factor
			|		ELSE 1
			|	END AS TimeNorm,
			|	ISNULL(PricesSliceLast.Price / ISNULL(PricesSliceLast.MeasurementUnit.Factor, 1), 0) AS Tariff
			|FROM
			|	Document.ProductionOrder.Products AS OrderForProductsProduction
			|		LEFT JOIN Catalog.BillsOfMaterials.Operations AS OperationSpecification
			|			LEFT JOIN InformationRegister.Prices.SliceLast(&Period, PriceKind = VALUE(Catalog.PriceTypes.Accounting)) AS PricesSliceLast
			|			ON OperationSpecification.Operation = PricesSliceLast.Products
			|		ON OrderForProductsProduction.Specification = OperationSpecification.Ref
			|WHERE
			|	OrderForProductsProduction.Ref = &BasisDocument";
			
			Query.SetParameter("BasisDocument", FillingData);
			Query.SetParameter("Period", ?(ValueIsFilled(FillingData.Start), FillingData.Start, CurrentDate()));
			
			QueryResult = Query.Execute();
			If Not QueryResult.IsEmpty() Then
				
				Selection = QueryResult.Select();
				Selection.Next();
				FillPropertyValues(ThisObject, Selection);
				DocumentCurrency = Catalogs.PriceTypes.Accounting.PriceCurrency;
				
				Selection.Reset();
				While Selection.Next() Do
					
					TableContent.Clear();
					FillTableBySpecification(Selection.Specification, Selection.MeasurementUnit, Selection.Quantity, TableContent);
					TotalCostPercentage = TableContent.Total("CostPercentage");
					
					LeftToDistribute = Selection.TimeNorm;
					
					NewRow = Undefined;
					For Each TableRow In TableContent Do
					
						NewRow = Operations.Add();
						NewRow.Period = Selection.Period;
						NewRow.SalesOrder = Selection.SalesOrder;
						NewRow.Products = TableRow.Products;
						NewRow.Characteristic = TableRow.Characteristic;
						NewRow.Operation = Selection.Operation;
						NewRow.MeasurementUnit = Selection.OperationMeasurementUnit;
						NewRow.QuantityPlan = TableRow.Quantity;
						NewRow.Tariff = Selection.Tariff;
						NewRow.Specification = Selection.Specification;
						
						TimeNorm = Round(Selection.TimeNorm * TableRow.CostPercentage / ?(TotalCostPercentage = 0, 1, TotalCostPercentage),3,0);
						NewRow.TimeNorm = TimeNorm;
						LeftToDistribute = LeftToDistribute - TimeNorm;
						
					EndDo;
					
					If NewRow <> Undefined Then
						NewRow.TimeNorm = NewRow.TimeNorm + LeftToDistribute;
					EndIf;
					
				EndDo;
				
			Else
				Return;
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Procedure - event handler FillCheckProcessing object.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If DataExchange.Load Then
	
		Return;
		
	EndIf;
	
	If Closed Then
		
		CheckedAttributes.Add("ClosingDate");
	
	EndIf;
		
EndProcedure

// Procedure - event handler BeforeWrite object.
//
Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;

	DocumentAmount = Operations.Total("Cost");
	
	AdditionalProperties.Insert("WriteMode", WriteMode);
	
EndProcedure

// Procedure - event handler FillingProcessor object.
//
Procedure Posting(Cancel, PostingMode)

	// Initialization of additional properties for document posting
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Initialization of document data
	Documents.JobSheet.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Preparation of record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Registering in accounting sections
	DriveServer.ReflectEarningsAndDeductions(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectPayroll(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectInventory(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectWorkload(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingJournalEntries(AdditionalProperties, RegisterRecords, Cancel);

	// Writing of record sets
	DriveServer.WriteRecordSets(ThisObject);
	
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
	
EndProcedure

#EndRegion

#EndIf
