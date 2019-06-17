#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions

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
			
			MessageText = StrTemplate(NStr("en = 'For products and services %1 in string %2 of the ""Inventory"" list the retail price is not set.'"), 
			DriveServer.PresentationOfProducts(SelectionOfQueryResult.ProductsPresentation, 
														SelectionOfQueryResult.CharacteristicPresentation, 
														SelectionOfQueryResult.BatchPresentation),
			String(SelectionOfQueryResult.LineNumber));  
			
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

#EndRegion

#Region EventsHandlers

// IN the event handler of the FillingProcessor document
// - document filling by inventory reconciliation in the warehouse.
//
Procedure Filling(FillingData, StandardProcessing) Export
	
	If TypeOf(FillingData) = Type("DocumentRef.Stocktaking") AND ValueIsFilled(FillingData) Then
		
		BasisDocument = FillingData.Ref;
		Company = FillingData.Company;
		StructuralUnit = FillingData.StructuralUnit;
		Cell = FillingData.Cell;
		
		// FO Use Production subsystem.
		If Not Constants.UseProductionSubsystem.Get()
			AND StructuralUnit.StructuralUnitType = Enums.BusinessUnitsTypes.Department Then
			Raise NStr("en = 'To allow generation of inventory increases from stocktakings, turn on Settings > Accounting settings > Production > Enable section use.'");
		EndIf;
		
		Query = New Query(
		"SELECT
		|	MIN(Stocktaking.LineNumber) AS LineNumber,
		|	Stocktaking.Products AS Products,
		|	Stocktaking.Characteristic AS Characteristic,
		|	Stocktaking.Batch AS Batch,
		|	Stocktaking.MeasurementUnit AS MeasurementUnit,
		|	MAX(Stocktaking.Quantity - Stocktaking.QuantityAccounting) AS QuantityInventorytakingRejection,
		|	SUM(CASE
		|			WHEN InventoryIncrease.Quantity IS NULL
		|				THEN 0
		|			ELSE InventoryIncrease.Quantity
		|		END) AS QuantityDebited,
		|	Stocktaking.Price AS Price
		|FROM
		|	Document.Stocktaking.Inventory AS Stocktaking
		|		LEFT JOIN Document.InventoryIncrease.Inventory AS InventoryIncrease
		|		ON Stocktaking.Products = InventoryIncrease.Products
		|			AND Stocktaking.Characteristic = InventoryIncrease.Characteristic
		|			AND Stocktaking.Batch = InventoryIncrease.Batch
		|			AND Stocktaking.Ref = InventoryIncrease.Ref.BasisDocument
		|			AND (InventoryIncrease.Ref <> &DocumentRef)
		|			AND (InventoryIncrease.Ref.Posted)
		|WHERE
		|	Stocktaking.Ref = &BasisDocument
		|	AND Stocktaking.Quantity - Stocktaking.QuantityAccounting > 0
		|	AND CASE
		|			WHEN Stocktaking.Batch <> VALUE(Catalog.ProductsBatches.EmptyRef)
		|				THEN Stocktaking.Batch.Status = VALUE(Enum.BatchStatuses.OwnInventory)
		|			ELSE TRUE
		|		END
		|
		|GROUP BY
		|	Stocktaking.Products,
		|	Stocktaking.Characteristic,
		|	Stocktaking.Batch,
		|	Stocktaking.MeasurementUnit,
		|	Stocktaking.Price
		|
		|ORDER BY
		|	LineNumber");
		
		Query.SetParameter("BasisDocument", FillingData);
		Query.SetParameter("DocumentRef", Ref);
		
		QueryResult = Query.Execute();
		
		If Not QueryResult.IsEmpty() Then
			
			Selection = QueryResult.Select();
			
			// Filling document tabular section.
			Inventory.Clear();
			
			While Selection.Next() Do
				
				QuantityToReceive = Selection.QuantityInventorytakingRejection - Selection.QuantityDebited;
				If QuantityToReceive <= 0 Then
					Continue;
				EndIf;
				
				TabularSectionRow = Inventory.Add();
				TabularSectionRow.Products		= Selection.Products;
				TabularSectionRow.Characteristic		= Selection.Characteristic;
				TabularSectionRow.Batch				= Selection.Batch;
				TabularSectionRow.MeasurementUnit	= Selection.MeasurementUnit;
				TabularSectionRow.Quantity			= QuantityToReceive;
				TabularSectionRow.Price				= Selection.Price;
				TabularSectionRow.Amount				= TabularSectionRow.Quantity * TabularSectionRow.Price;
			
			EndDo;
			
		EndIf;
		
		GLAccountsInDocuments.FillTabSectionFromProductGLAccounts(ThisObject, FillingData);
		
		If Inventory.Count() = 0 Then
			
			Raise NStr("en = 'No data for capitalization registration.'");
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Procedure - event handler FillCheckProcessing object.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	CheckExistenceOfRetailPrice(Cancel);
	
	WorkWithSerialNumbers.FillCheckingSerialNumbers(Cancel, Inventory, SerialNumbers, StructuralUnit, ThisObject);
	
EndProcedure

// Procedure - event handler BeforeWrite object.
//
Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	DocumentAmount = Inventory.Total("Amount");
	
	AdditionalProperties.Insert("WriteMode", WriteMode);
	
EndProcedure

// Procedure - event handler Posting object.
//
Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Initialization of document data
	Documents.InventoryIncrease.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Preparation of record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Registering in accounting sections
	DriveServer.ReflectInventoryInWarehouses(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectInventory(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectIncomeAndExpenses(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingJournalEntries(AdditionalProperties, RegisterRecords, Cancel);
	
	// SerialNumbers
	DriveServer.ReflectTheSerialNumbersOfTheGuarantee(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectTheSerialNumbersBalance(AdditionalProperties, RegisterRecords, Cancel);
	
	// Offline registers
	DriveServer.ReflectInventoryCostLayer(AdditionalProperties, RegisterRecords, Cancel);
	
	// Writing of record sets
	DriveServer.WriteRecordSets(ThisObject);
	
	// Control
	Documents.InventoryIncrease.RunControl(Ref, AdditionalProperties, Cancel);
	
	DriveServer.CreateRecordsInTasksRegisters(ThisObject, Cancel);
	
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
	Documents.InventoryIncrease.RunControl(Ref, AdditionalProperties, Cancel, True);
	
EndProcedure

#EndRegion

#EndIf