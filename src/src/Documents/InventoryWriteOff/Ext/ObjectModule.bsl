#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

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
		
		Query = New Query(
		"SELECT
		|	MIN(Stocktaking.LineNumber) AS LineNumber,
		|	Stocktaking.Products AS Products,
		|	Stocktaking.Characteristic AS Characteristic,
		|	Stocktaking.Batch AS Batch,
		|	Stocktaking.MeasurementUnit AS MeasurementUnit,
		|	MAX(Stocktaking.QuantityAccounting - Stocktaking.Quantity) AS QuantityRejection,
		|	SUM(CASE
		|			WHEN InventoryWriteOff.Quantity IS NULL 
		|				THEN 0
		|			ELSE InventoryWriteOff.Quantity
		|		END) AS WrittenOffQuantity
		|FROM
		|	Document.Stocktaking.Inventory AS Stocktaking
		|		LEFT JOIN Document.InventoryWriteOff.Inventory AS InventoryWriteOff
		|		ON Stocktaking.Products = InventoryWriteOff.Products
		|			AND Stocktaking.Characteristic = InventoryWriteOff.Characteristic
		|			AND Stocktaking.Batch = InventoryWriteOff.Batch
		|			AND Stocktaking.Ref = InventoryWriteOff.Ref.BasisDocument
		|			AND (InventoryWriteOff.Ref <> &DocumentRef)
		|			AND (InventoryWriteOff.Ref.Posted)
		|WHERE
		|	Stocktaking.Ref = &BasisDocument
		|	AND Stocktaking.QuantityAccounting - Stocktaking.Quantity > 0
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
		|	Stocktaking.MeasurementUnit
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
				
				CountWriteOff = Selection.QuantityRejection - Selection.WrittenOffQuantity;
				
				If CountWriteOff <= 0 Then
					Continue;
				EndIf;
				
				TabularSectionRow = Inventory.Add();
				TabularSectionRow.Products		= Selection.Products;
				TabularSectionRow.Characteristic		= Selection.Characteristic;
				TabularSectionRow.Batch				= Selection.Batch;
				TabularSectionRow.MeasurementUnit	= Selection.MeasurementUnit;
				TabularSectionRow.Quantity			= CountWriteOff;
				
			EndDo;
			
		EndIf;
		
		If Inventory.Count() = 0 Then
			
			Message = New UserMessage();
			Raise NStr("en = 'No data to register write-off.'");
			Message.Message();
			
			StandardProcessing = False;
			
		EndIf;
		
	EndIf;
	
	GLAccountsInDocuments.FillTabSectionFromProductGLAccounts(ThisObject, FillingData);
	
EndProcedure

// Procedure - event handler FillCheckProcessing object.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	// Serial numbers
	WorkWithSerialNumbers.FillCheckingSerialNumbers(Cancel, Inventory, SerialNumbers, StructuralUnit, ThisObject);
	
EndProcedure

// Procedure - event handler Posting object.
//
Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Initialization of document data
	Documents.InventoryWriteOff.InitializeDocumentData(Ref, AdditionalProperties);
	
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
	
	// Writing of record sets
	DriveServer.WriteRecordSets(ThisObject);

	// Control
	Documents.InventoryWriteOff.RunControl(Ref, AdditionalProperties, Cancel);
	
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
	Documents.InventoryWriteOff.RunControl(Ref, AdditionalProperties, Cancel, True);
	
	DriveServer.CreateRecordsInTasksRegisters(ThisObject, Cancel);
	
EndProcedure

Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	AdditionalProperties.Insert("WriteMode", WriteMode);
EndProcedure

#EndRegion

#EndIf