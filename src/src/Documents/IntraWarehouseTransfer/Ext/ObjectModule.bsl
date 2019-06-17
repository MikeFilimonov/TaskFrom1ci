#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions

// Procedure of filling the document on the basis.
//
// Parameters:
// FillingData - Structure - Data on filling the document.
//	
Procedure FillByPurchaseInvoice(FillingData)
	
	// Header filling.
	AttributeValues = CommonUse.ObjectAttributesValues(FillingData, New Structure("Company, StructuralUnit, Cell"));
	
	FillPropertyValues(ThisObject, AttributeValues);
	BasisDocument = FillingData;
	OperationKind = Enums.OperationTypesIntraWarehouseTransfer.FromOneToSeveral;
	
	// Filling out tabular section.
	Query = New Query;
	Query.Text =
	"SELECT
	|	SupplierInvoiceInventory.Products AS Products,
	|	SupplierInvoiceInventory.Characteristic AS Characteristic,
	|	SupplierInvoiceInventory.Batch AS Batch,
	|	SupplierInvoiceInventory.MeasurementUnit AS MeasurementUnit,
	|	SUM(SupplierInvoiceInventory.Quantity) AS Quantity,
	|	SupplierInvoiceInventory.SerialNumbers,
	|	SupplierInvoiceInventory.ConnectionKey
	|FROM
	|	Document.SupplierInvoice.Inventory AS SupplierInvoiceInventory
	|WHERE
	|	SupplierInvoiceInventory.Ref = &BasisDocument
	|
	|GROUP BY
	|	SupplierInvoiceInventory.Products,
	|	SupplierInvoiceInventory.Characteristic,
	|	SupplierInvoiceInventory.Batch,
	|	SupplierInvoiceInventory.MeasurementUnit,
	|	SupplierInvoiceInventory.SerialNumbers,
	|	SupplierInvoiceInventory.ConnectionKey";
	
	Query.SetParameter("BasisDocument", FillingData);
	
	Inventory.Load(Query.Execute().Unload());
	
	WorkWithSerialNumbers.FillTSSerialNumbersByConnectionKey(ThisObject, FillingData);
	
EndProcedure

#EndRegion

#Region EventsHandlers

// IN the FillingProcessor event handler the document is being processed.
//
Procedure Filling(FillingData, StandardProcessing) Export
	
	If TypeOf(FillingData) = Type("DocumentRef.SupplierInvoice") Then
		
		FillByPurchaseInvoice(FillingData);
		
	EndIf;
	
EndProcedure

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
	Documents.IntraWarehouseTransfer.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Preparation of record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Registering in accounting sections
	DriveServer.ReflectInventoryInWarehouses(AdditionalProperties, RegisterRecords, Cancel);

	// SerialNumbers
	DriveServer.ReflectTheSerialNumbersOfTheGuarantee(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectTheSerialNumbersBalance(AdditionalProperties, RegisterRecords, Cancel);
	
	// Writing of record sets
	DriveServer.WriteRecordSets(ThisObject);

	// Control
	Documents.IntraWarehouseTransfer.RunControl(Ref, AdditionalProperties, Cancel);
	
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
	Documents.IntraWarehouseTransfer.RunControl(Ref, AdditionalProperties, Cancel, True);
	
	DriveServer.CreateRecordsInTasksRegisters(ThisObject, Cancel);
	
EndProcedure

#EndRegion

#EndIf