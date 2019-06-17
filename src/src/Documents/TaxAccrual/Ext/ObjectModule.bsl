#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

// Procedure - event handler BeforeWrite object.
//
Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Not Constants.UseSeveralDepartments.Get() Then
		
		For Each RowTaxes In Taxes Do
			
			If RowTaxes.Correspondence.TypeOfAccount = Enums.GLAccountsTypes.WorkInProcess
			 OR RowTaxes.Correspondence.TypeOfAccount = Enums.GLAccountsTypes.IndirectExpenses
			 OR RowTaxes.Correspondence.TypeOfAccount = Enums.GLAccountsTypes.Revenue
			 OR RowTaxes.Correspondence.TypeOfAccount = Enums.GLAccountsTypes.Expenses Then
				RowTaxes.Department = Catalogs.BusinessUnits.MainDepartment;
			EndIf;
			
		EndDo;
		
	EndIf;
	
	If Not Constants.UseSeveralLinesOfBusiness.Get() Then
		
		For Each RowTaxes In Taxes Do
			If RowTaxes.Correspondence.TypeOfAccount = Enums.GLAccountsTypes.Revenue
			 OR RowTaxes.Correspondence.TypeOfAccount = Enums.GLAccountsTypes.Expenses Then
				RowTaxes.BusinessLine = Catalogs.LinesOfBusiness.MainLine;
			EndIf;
		EndDo;
			
	EndIf;
	
	DocumentAmount = Taxes.Total("Amount");
	
	AdditionalProperties.Insert("WriteMode", WriteMode);
	
EndProcedure

// Procedure - event handler FillCheckProcessing object.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	For Each RowTaxes In Taxes Do
		
		If Constants.UseSeveralDepartments.Get()
		   AND (RowTaxes.Correspondence.TypeOfAccount = Enums.GLAccountsTypes.WorkInProcess
		 OR RowTaxes.Correspondence.TypeOfAccount = Enums.GLAccountsTypes.IndirectExpenses
		 OR RowTaxes.Correspondence.TypeOfAccount = Enums.GLAccountsTypes.Revenue
		 OR RowTaxes.Correspondence.TypeOfAccount = Enums.GLAccountsTypes.Expenses)
		 AND Not ValueIsFilled(RowTaxes.Department) Then
		 
		 	MessageText = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'The ""Department"" attribute should be filled in for the %1 costs account specified in the %2 line of the ""Taxes"" list.'"),
				RowTaxes.Correspondence,
				RowTaxes.LineNumber);
				
			DriveServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				"Taxes",
				RowTaxes.LineNumber,
				"Department",
				Cancel
			);
		EndIf;
		
	EndDo;
	
EndProcedure

// Procedure - event handler Posting(). Creates
// a document movement by accumulation registers and accounting register.
//
// 1. Delete the existing document transactions.
// 2. Generation document header structure with
// fields used in document post algorithms.
// 3. header value filling check and tabular document sections.
// 4. Creation temporary table by document which
// is necessary for transaction generating.
// 5. Creating the document records in accumulation register.
// 6. Creating the document records in accounting register.
//
Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting.
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Document data initialization.
	Documents.TaxAccrual.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Preparation of records sets.
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Account for in accounting sections.
	DriveServer.ReflectTaxesSettlements(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectIncomeAndExpenses(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectInventory(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingJournalEntries(AdditionalProperties, RegisterRecords, Cancel);
	
	// Record of the records sets.
	DriveServer.WriteRecordSets(ThisObject);
	
	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
EndProcedure

// Procedure - event handler UndoPosting object.
//
Procedure UndoPosting(Cancel)
	
	// Initialization of additional properties to undo document posting
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Preparation of record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Writing of record sets
	DriveServer.WriteRecordSets(ThisObject);
	
EndProcedure

#EndRegion

#EndIf