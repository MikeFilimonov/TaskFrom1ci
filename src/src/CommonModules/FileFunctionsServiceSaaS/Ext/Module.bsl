////////////////////////////////////////////////////////////////////////////////
// Subsystem "File functions in service model".
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProgramInterface

// See details of the same procedure in the StandardSubsystemsServer module.
Procedure OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers) Export
	
	// SERVERSIDE HANDLERS.
	
	If CommonUse.SubsystemExists("StandardSubsystems.SaaS.JobQueue") Then
		ServerHandlers[
			"StandardSubsystems.SaaS.JobQueue\WhenYouDefineAliasesHandlers"].Add(
				"FileFunctionsServiceSaaS");
	
		ServerHandlers[
			"StandardSubsystems.SaaS.JobQueue\OnDefenitionOfUsageOfScheduledJobs"].Add(
				"FileFunctionsServiceSaaS");
	EndIf;
	
	If CommonUse.SubsystemExists("ServiceTechnology.DataExportImport") Then
		ServerHandlers[
			"ServiceTechnology.DataExportImport\WhenFillingTypesExcludedFromExportImport"].Add(
				"FileFunctionsServiceSaaS");
	EndIf;
	
EndProcedure

// Handler of event WhenYouDefineAliasesHandlers.
//
// Fills in the match of methods names and their aliases for call from the jobs queue.
//
// Parameters:
//  AccordanceNamespaceAliases - Correspondence
//   Key - Method alias, for example, ClearDataArea.
//   Value - Method name for call, for example, SaaSOperations.ClearDataArea.
//    You can specify Undefined as a value, in this case, it is
// considered that name matches the alias.
//
Procedure WhenYouDefineAliasesHandlers(AccordanceNamespaceAliases) Export
	
	AccordanceNamespaceAliases.Insert("FileFunctionsService.ExtractTextFromFilesOnServer");
	
EndProcedure

// Generates scheduled
// jobs table with the flag of usage in the service model.
//
// Parameters:
// UsageTable - ValueTable - table that should be filled in with the scheduled jobs a flag of usage, columns:
//  ScheduledJob - String - name of the predefined scheduled job.
//  Use - Boolean - True if scheduled job
//   should be executed in the service model. False - if it should not.
//
Procedure OnDefenitionOfUsageOfScheduledJobs(UsageTable) Export
	
	NewRow = UsageTable.Add();
	NewRow.ScheduledJob = "TextExtractionPlanningSaaS";
	NewRow.Use       = True;
	
EndProcedure

// Fills the array of types excluded from the import and export of data.
//
// Parameters:
//  Types - Array(Types).
//
Procedure WhenFillingTypesExcludedFromExportImport(Types) Export
	
	Types.Add(Metadata.InformationRegisters.TextExtractionQueue);
	
EndProcedure

#Region TextExtraction

// Adds and deletes records from the TextExtraction information
// register while changing state of files version text extraction.
//
// Parameters:
// SourceText - CatalogRef.FileVersions,
// 	CatalogRef.*AttachedFiles file which text extraction state was changed.
// TextExtractionState - EnumRef.FileTextExtractionStatuses,
// 	new status of text extraction from file.
//
Procedure RefreshTextExtractionQueueStatus(SourceText, TextExtractionState) Export
	
	SetPrivilegedMode(True);
	
	RecordSet = InformationRegisters.TextExtractionQueue.CreateRecordSet();
	RecordSet.Filter.DataAreaAuxiliaryData.Set(CommonUse.SessionSeparatorValue());
	RecordSet.Filter.SourceText.Set(SourceText);
	
	If TextExtractionState = Enums.FileTextExtractionStatuses.NotExtracted
			OR TextExtractionState = Enums.FileTextExtractionStatuses.EmptyRef() Then
			
		Record = RecordSet.Add();
		Record.DataAreaAuxiliaryData = CommonUse.SessionSeparatorValue();
		Record.SourceText = SourceText.Ref;
			
	EndIf;
		
	RecordSet.Write();
	
EndProcedure

#EndRegion

#EndRegion

#Region ServiceProceduresAndFunctions

#Region TextExtraction

// Defines the list of data in areas that require removing
// the text, and plans for them its execution using jobs queue.
//
Procedure ProcessTextExtractionQueue() Export
	
	If Not CommonUseReUse.DataSeparationEnabled() Then
		Return;
	EndIf;
	
	CommonUse.OnStartExecutingScheduledJob();
	
	SetPrivilegedMode(True);
	
	SeparatedMethodName = "FileFunctionsService.ExtractTextFromFilesOnServer";
	
	QueryText = 
	"SELECT DISTINCT
	|	TextExtractionQueue.DataAreaAuxiliaryData AS DataArea,
	|	CASE
	|		WHEN TimeZone.Value = """"
	|			THEN UNDEFINED
	|		ELSE ISNULL(TimeZone.Value, UNDEFINED)
	|	END AS TimeZone
	|FROM
	|	InformationRegister.TextExtractionQueue AS TextExtractionQueue
	|		LEFT JOIN Constant.DataAreaTimeZone AS TimeZone
	|		ON TextExtractionQueue.DataAreaAuxiliaryData = TimeZone.DataAreaAuxiliaryData
	|		LEFT JOIN InformationRegister.DataAreas AS DataAreas
	|		ON TextExtractionQueue.DataAreaAuxiliaryData = DataAreas.DataAreaAuxiliaryData
	|WHERE
	|	Not TextExtractionQueue.DataAreaAuxiliaryData IN (&ProcessedDataAreas)
	|	AND DataAreas.Status = VALUE(Enum.DataAreaStatuses.Used)";
	Query = New Query(QueryText);
	Query.SetParameter("ProcessedDataAreas", JobQueue.GetJobs(
		New Structure("MethodName", SeparatedMethodName)));
	
	Selection = CommonUse.ExecuteQueryBeyondTransaction(Query).Select();
	While Selection.Next() Do
		// Checks whether the data area is locked on.
		If SaaSOperations.DataAreaBlocked(Selection.DataArea) Then
			// The area is locked, move to the next record.
			Continue;
		EndIf;
		
		NewJob = New Structure();
		NewJob.Insert("DataArea", Selection.DataArea);
		NewJob.Insert("ScheduledStartTime", ToLocalTime(CurrentUniversalDate(), Selection.TimeZone));
		NewJob.Insert("MethodName", SeparatedMethodName);
		JobQueue.AddJob(NewJob);
	EndDo;
	
EndProcedure

#EndRegion

#EndRegion
