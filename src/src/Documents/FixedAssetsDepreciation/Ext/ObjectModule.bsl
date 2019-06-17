#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions

// Procedure of filling the document on the basis.
//
// Parameters:
// FillingData - Structure - Data on filling the document.
//	
Procedure FillByCompany(FillingData)
	
	Company = FillingData;
	
EndProcedure

#EndRegion

#Region EventsHandlers

// Procedure - handler of the FillingProcessor event.
//
Procedure Filling(FillingData, StandardProcessing)
	
	If TypeOf(FillingData) = Type("CatalogRef.Companies") Then
		FillByCompany(FillingData);
	EndIf;
	
EndProcedure

// Procedure - event handler Posting().
// Creates a document movement by accumulation registers and accounting register.
//
Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Initialization of document data
	Documents.FixedAssetsDepreciation.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Preparation of record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Registering in accounting sections
	DriveServer.ReflectInventory(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectIncomeAndExpenses(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectFixedAssets(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingJournalEntries(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectMonthEndErrors(AdditionalProperties, RegisterRecords, Cancel);
	
	If AdditionalProperties.TableForRegisterRecords.TableMonthEndErrors.Count() > 0 Then
		MessageText = NStr("en = 'Warnings were generated during depreciation accrual. For more information, see the month ending report.'");
		CommonUseClientServer.MessageToUser(MessageText);
	EndIf;
	
	// Writing of record sets
	DriveServer.WriteRecordSets(ThisObject);
	
	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
EndProcedure

Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	AdditionalProperties.Insert("WriteMode", WriteMode);
EndProcedure

#EndRegion

#EndIf