#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

// Procedure - event handler FillCheckProcessing object.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	ExceptionArray = New Array;
	ExceptionArray.Add(Catalogs.PayCodes.WeekEnd);
	ExceptionArray.Add(Catalogs.PayCodes.AnnualLeave);
	
	If DataInputMethod = Enums.TimeDataInputMethods.ByDays Then
		
		For Each TSRow In HoursWorkedByDays Do
			
			For Counter = 1 To 31 Do
			
				If ValueIsFilled(TSRow["FirstTimeKind" + Counter])
					AND Not ValueIsFilled(TSRow["FirstHours" + Counter]) Then
					
					If ExceptionArray.Find(TSRow["FirstTimeKind" + Counter]) = Undefined Then 
					
						DriveServer.ShowMessageAboutError(ThisObject, 
						"Hour quantity by time kind isn't specified.",
						"HoursWorkedByDays",
						TSRow.LineNumber,
						"FirstHours" + Counter,
						Cancel);
						
					EndIf;
					
				EndIf;
				
				If ValueIsFilled(TSRow["SecondTimeKind" + Counter])
					AND Not ValueIsFilled(TSRow["SecondHours" + Counter]) Then
					
					If ExceptionArray.Find(TSRow["SecondTimeKind" + Counter]) = Undefined Then 
					
						DriveServer.ShowMessageAboutError(ThisObject, 
						"Hour quantity by time kind isn't specified.",
						"HoursWorkedByDays",
						TSRow.LineNumber,
						"SecondHours" + Counter,
						Cancel);
						
					EndIf;
					
				EndIf;
				
				If ValueIsFilled(TSRow["ThirdTimeKind" + Counter])
					AND Not ValueIsFilled(TSRow["ThirdHours" + Counter]) Then
					
					If ExceptionArray.Find(TSRow["ThirdTimeKind" + Counter]) = Undefined Then 
					
						DriveServer.ShowMessageAboutError(ThisObject, 
						"Hour quantity by time kind isn't specified.",
						"HoursWorkedByDays",
						TSRow.LineNumber,
						"ThirdHours" + Counter,
						Cancel);
						
					EndIf;
					
				EndIf;
			
			EndDo;		
			
		EndDo; 
		
	Else	
		
		For Each TSRow In HoursWorkedPerPeriod Do
			For Counter = 1 To 6 Do
			
				If ValueIsFilled(TSRow["TimeKind" + Counter])
					AND Not ValueIsFilled(TSRow["Days" + Counter])
					AND Not ValueIsFilled(TSRow["Hours" + Counter]) Then
					DriveServer.ShowMessageAboutError(ThisObject, 
					"Day and hour quantity by time kind isn't specified.",
					"HoursWorkedPerPeriod",
					TSRow.LineNumber,
					"TimeKind" + Counter,
					Cancel);
				EndIf;
			
			EndDo;		
		EndDo;
		
	EndIf;
	
EndProcedure

// Procedure - event handler Posting object.
//
Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting.
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Document data initialization.
	Documents.Timesheet.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Preparation of records sets.
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Account for in accounting sections.
	DriveServer.ReflectTimesheet(AdditionalProperties, RegisterRecords, Cancel);
	
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