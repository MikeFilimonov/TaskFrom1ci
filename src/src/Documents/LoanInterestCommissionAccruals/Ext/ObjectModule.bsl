#If Server OR ThickClientOrdinaryApplication OR ExternalConnection Then

#Region EventHandlers

Procedure Filling(FillingData, StandardProcessing)
	
	AccrualPeriod = New StandardPeriod;
	AccrualPeriod.Variant	= StandardPeriodVariant.LastMonth;
	StartDate				= AccrualPeriod.StartDate;
	EndDate					= AccrualPeriod.EndDate;
	
	ObjectFillingDrive.FillDocument(ThisObject, FillingData);
	
EndProcedure

// Procedure - handler of the PostingProcessing event of the object.
//
Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties to post the document
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Document data initialization
	Documents.LoanInterestCommissionAccruals.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Prepare record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Record in accounting sections
	DriveServer.ReflectIncomeAndExpenses(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingJournalEntries(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectLoanSettlements(AdditionalProperties, RegisterRecords, Cancel);
	
	// Record of record sets
	DriveServer.WriteRecordSets(ThisObject);

	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
EndProcedure

// Procedure - handler of the PopulationCheckProcessing event of the object.
//
Procedure FillCheckProcessing(Cancel, AttributesToCheck)
	
	If OperationType = Enums.LoanAccrualTypes.AccrualsForLoansBorrowed Then
		DriveServer.DeleteAttributeBeingChecked(AttributesToCheck, "Accruals.Employee");
	Else		
		DriveServer.DeleteAttributeBeingChecked(AttributesToCheck, "Accruals.Lender");
	EndIf;
	
	If ValueIsFilled(StartDate) AND ValueIsFilled(EndDate)
		AND StartDate > EndDate Then
		
		MessageText = NStr("en = 'Incorrect period is specified. Start date > End date.'");
		
		DriveServer.ShowMessageAboutError(
			ThisObject,
			MessageText,,,
			"StartDate",
			Cancel);
		
	EndIf;
	
EndProcedure

// Procedure - handler of the PostingDeletionProcessing of the object event.
//
Procedure UndoPosting(Cancel)
	
	// Initialization of additional properties to post the document
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Prepare record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Record of record sets
	DriveServer.WriteRecordSets(ThisObject);

EndProcedure

// Procedure - handler of the BeforeWriting event of the object.
//
Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	AdditionalProperties.Insert("WriteMode", WriteMode);
	
EndProcedure

#EndRegion

#EndIf
