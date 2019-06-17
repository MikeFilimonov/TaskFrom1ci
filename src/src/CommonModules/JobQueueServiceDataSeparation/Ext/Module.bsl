////////////////////////////////////////////////////////////////////////////////
// JobQueue: Support separated queue jobs.
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProgramInterface

// Called while filling in catalogs array that
// can be used to store jobs queue jobs storage.
//
// Parameters:
//  ArrayCatalog - Array, catalogs managers should be
//    added to this parameter in this method that will be used to store queue jobs.
//
Procedure OnFillingCatalogsJobs(ArrayCatalog) Export
	
	ArrayCatalog.Add(Catalogs.JobQueueDataAreas);
	
EndProcedure

// Selects catalog for the added job of jobs queue.
//
// Parameters:
// JobParameters - - Structure - Added job parameters, possible keys:
//   DataArea
//   Usage
//   ScheduledStartTime
//   ExclusiveExecution.
//   MethodName - mandatory to be specified.
//   Parameters
//   Key
//   RestartIntervalOnFailure.
//   Schedule
//   RepetitionsQuantityOnFailure,
// Catalog - CatalogManager, as the value of this
//  parameter subscription to event must set catalog manager that should be used for the job.
// StandardProcessing - Boolean, as the value of this parameter
//  subscription to event should select the check box of standard processor
//  execution (and the DataAreasJobQueue catalog will be selected as a catalog).
//
Function OnChoiceCatalogForTasks1(Val JobParameters) Export
	
	If JobParameters.Property("DataArea") AND JobParameters.DataArea <> -1 Then
		
		Return Catalogs.JobQueueDataAreas;
		
	EndIf;
	
EndFunction

// Determines the DataAreaMainData separator value
//  that should be set before job execution.
//
// Parameters:
//  Task - CatalogRef, jobs queue job.
//
// Return value: Custom.
//
Function IdentifyDataAreaForTask(Val Task) Export
	
	If TypeOf(Task) = Type("CatalogRef.JobQueueDataAreas") Then
		Return CommonUse.ObjectAttributeValue(Task, "DataAreaAuxiliaryData");
	EndIf;
	
EndFunction

// Corrects the planned job start time considering the data area time zone.
//
// Parameters:
//  JobParameters - Structure - Added job parameters, possible keys:
//   DataArea
//   Usage
//   ScheduledStartTime
//   ExclusiveExecution.
//   MethodName - mandatory to be specified.
//   Parameters
//   Key
//   RestartIntervalOnFailure.
//   Schedule
//   RepetitionsQuantityOnFailure.
//  Result = Date (date and time), planned start time for job.
//  StandardProcessing - Boolean, shows that it is necessary
//    to reduce job type to server time zone.
//
Procedure WhenDefiningScheduledDateOfLaunch(Val JobParameters, Result, StandardProcessing) Export
	
	DataArea = Undefined;
	If Not JobParameters.Property("DataArea", DataArea) Then
		Return;
	EndIf;
	
	If DataArea <> - 1 Then
		
		// Time conversion from area time zone.
		TimeZone = SaaSOperations.GetDataAreaTimeZone(JobParameters.DataArea);
		Result = ToUniversalTime(JobParameters.ScheduledStartTime, TimeZone);
		StandardProcessing = False;
		
	EndIf;
	
EndProcedure

///  Updates queue jobs created according to templates.
Procedure UpdateQueueJobsByTemplates(Parameters = Undefined) Export
	
	If Not CommonUseReUse.DataSeparationEnabled() Then
		Return;
	EndIf;
	
	If Parameters = Undefined Then
		Parameters = New Structure;
		Parameters.Insert("ExclusiveMode", True);
	EndIf;
	
	RunInSingleUserMode = Parameters.ExclusiveMode;
	
	Block = New DataLock;
	Block.Add("Catalog.JobQueueDataAreas");
	
	BeginTransaction();
	Try
		Block.Lock();
		
		ChangesTemplates = RefreshJobQueueTemplates(Parameters);
		If Not RunInSingleUserMode 
			AND Parameters.ExclusiveMode Then
			
			RollbackTransaction();
			Return;
		EndIf;
		
		If ChangesTemplates.Deleted.Count() > 0
			OR ChangesTemplates.AddedModified.Count() > 0 Then
			
			// Delete jobs by deleted templates.
			Query = New Query(
			"SELECT
			|	Queue.Ref
			|FROM
			|	Catalog.JobQueueDataAreas AS Queue
			|WHERE
			|	Queue.Pattern IN(&DeletedTemplates)");
			Query.SetParameter("DeletedTemplates", ChangesTemplates.Deleted);
			
			Selection = Query.Execute().Select();
			While Selection.Next() Do
				
				Task = Selection.Ref.GetObject();
				Task.DataExchange.Load = True;
				Task.Delete();
				
			EndDo;
			
			// Add jobs by added templates.
			AddedModified = ChangesTemplates.AddedModified;
			
			Query = New Query(
			"SELECT
			|	Areas.DataAreaAuxiliaryData AS DataArea,
			|	Queue.Ref AS ID,
			|	Patterns.Ref AS Pattern,
			|	ISNULL(Queue.LastStartDate, DATETIME(1, 1, 1)) AS LastStartDate,
			|	TimeZone.Value AS TimeZone
			|FROM
			|	InformationRegister.DataAreas AS Areas
			|		INNER JOIN Catalog.JobQueueTemplates AS Patterns
			|		ON (Patterns.Ref IN (&AddedModifiedTemplates))
			|			AND (Areas.Status = VALUE(Enum.DataAreaStatuses.Used))
			|		LEFT JOIN Catalog.JobQueueDataAreas AS Queue
			|		ON Areas.DataAreaAuxiliaryData = Queue.DataAreaAuxiliaryData
			|			AND (Patterns.Ref = Queue.Pattern)
			|		LEFT JOIN Constant.DataAreaTimeZone AS TimeZone
			|		ON Areas.DataAreaAuxiliaryData = TimeZone.DataAreaAuxiliaryData");
			Query.SetParameter("AddedModifiedTemplates", AddedModified.UnloadColumn("Ref"));
			
			Selection = Query.Execute().Select();
			While Selection.Next() Do
				
				RowTemplate = AddedModified.Find(Selection.Pattern, "Ref");
				If RowTemplate = Undefined Then
					MessagePattern = NStr("en = 'Job template %1 was not found while updating'");
					MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, Selection.Ref);
					Raise(MessageText);
				EndIf;
				
				If ValueIsFilled(Selection.ID) Then
					Task = Selection.ID.GetObject();
				Else
					
					Task = Catalogs.JobQueueDataAreas.CreateItem();
					Task.Pattern = Selection.Pattern;
					Task.DataAreaAuxiliaryData = Selection.DataArea;
					
				EndIf;
				
				Task.Use = RowTemplate.Use;
				Task.Key = RowTemplate.Key;
				
				Task.ScheduledStartTime = 
					JobQueueService.GetScheduledJobStartTime(
						RowTemplate.Schedule,
						Selection.TimeZone,
						Selection.LastStartDate);
						
				If ValueIsFilled(Task.ScheduledStartTime) Then
					Task.JobState = Enums.JobStatuses.Planned;
				Else
					Task.JobState = Enums.JobStatuses.NotPlanned;
				EndIf;
				
				Task.Write();
				
			EndDo;
		
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Creates jobs by templates in the current data area.
Procedure CreateQueueJobsByTemplatesInCurrentArea() Export
	
	If Not CommonUseReUse.DataSeparationEnabled() Then
		Return;
	EndIf;
	
	BeginTransaction();
	Try
		Block = New DataLock;
		Block.Add("Catalog.JobQueueDataAreas");
		Block.Lock();
		
		Query = New Query;
		Query.Text =
		"SELECT
		|	Queue.Ref AS ID,
		|	Patterns.Ref AS Pattern,
		|	ISNULL(Queue.LastStartDate, DATETIME(1, 1, 1)) AS LastStartDate,
		|	TimeZone.Value AS TimeZone,
		|	Patterns.Schedule AS Schedule,
		|	Patterns.Use AS Use,
		|	Patterns.Key AS Key
		|FROM
		|	Catalog.JobQueueTemplates AS Patterns
		|		LEFT JOIN Catalog.JobQueueDataAreas AS Queue
		|		ON Patterns.Ref = Queue.Pattern
		|		LEFT JOIN Constant.DataAreaTimeZone AS TimeZone
		|		ON (TRUE)";
		Result = Query.Execute();
		Selection = Result.Select();
		While Selection.Next() Do
			
			If ValueIsFilled(Selection.ID) Then
				Task = Selection.ID.GetObject();
			Else
				Task = Catalogs.JobQueueDataAreas.CreateItem();
				Task.Pattern = Selection.Pattern;
			EndIf;
			
			Task.Use = Selection.Use;
			Task.Key = Selection.Key;
			Task.ScheduledStartTime = 
				JobQueueService.GetScheduledJobStartTime(Selection.Schedule.Get(), 
					Selection.TimeZone, 
					Selection.LastStartDate);
					
			If ValueIsFilled(Task.ScheduledStartTime) Then
				Task.JobState = Enums.JobStatuses.Planned;
			Else
				Task.JobState = Enums.JobStatuses.NotPlanned;
			EndIf;
			
			Task.Write();
			
		EndDo;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

#Region DeclareServiceEventsToWhichSSLHandlersCanBeAttached

// See details of the same procedure in the StandardSubsystemsServer module.
Procedure OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers) Export
	
	// SERVERSIDE HANDLERS.
	
	ServerHandlers[
		"StandardSubsystems.InfobaseVersionUpdate\OnAddUpdateHandlers"].Add(
			"JobQueueServiceDataSeparation");
	
	ServerHandlers[
		"StandardSubsystems.BasicFunctionality\OnEnableSeparationByDataAreas"].Add(
			"JobQueueServiceDataSeparation");
	
	If CommonUse.SubsystemExists("ServiceTechnology.DataExportImport") Then
		
		ServerHandlers[
			"ServiceTechnology.DataExportImport\WhenFillingTypesExcludedFromExportImport"].Add(
				"JobQueueServiceDataSeparation");
		
		ServerHandlers[
		"ServiceTechnology.DataExportImport\AfterDataImportFromOtherMode"].Add(
			"JobQueueServiceDataSeparation");
		
	EndIf;
	
EndProcedure

#EndRegion

#Region HandlersOfSSLSubsystemsInternalEvents

// Adds the update procedure-handlers necessary for the subsystem.
//
// Parameters:
//  Handlers - ValueTable - see NewUpdateHandlersTable function description of UpdateResults common module.
// 
Procedure OnAddUpdateHandlers(Handlers) Export
	
	Handler = Handlers.Add();
	Handler.InitialFilling = True;
	Handler.Procedure = "JobQueueServiceDataSeparation.CreateQueueJobsByTemplatesInCurrentArea";
	Handler.ExclusiveMode = True;
	Handler.ExecuteUnderMandatory = True;
	Handler.Priority = 98;
	
	Handler = Handlers.Add();
	Handler.Version = "*";
	Handler.Procedure = "JobQueueServiceDataSeparation.UpdateQueueJobsByTemplates";
	Handler.SharedData = True;
	Handler.ExclusiveMode = True;
	Handler.Priority = 63;
	
EndProcedure

// Called up at enabling data classification into data fields.
//
Procedure OnEnableSeparationByDataAreas() Export
	
	UpdateQueueJobsByTemplates();
	
EndProcedure

// It is called once data is imported
// from a local version to the service data area or vice versa.
//
Procedure AfterDataImportFromOtherMode() Export
	
	If Not CommonUseReUse.DataSeparationEnabled() Then
		Return;
	EndIf;
	
	CreateQueueJobsByTemplatesInCurrentArea();
	
EndProcedure

// Fills the array of types excluded from the import and export of data.
//
// Parameters:
//  Types - Array(Types).
//
Procedure WhenFillingTypesExcludedFromExportImport(Types) Export
	
	Types.Add(Metadata.Catalogs.JobQueueDataAreas);
	
EndProcedure

#EndRegion

#EndRegion

#Region ServiceProceduresAndFunctions

// Fills in JobQueueTemplates catalog with the list
// of scheduled jobs used as a templates for the jobs queue and
// forcefully clears the Usage flag for these jobs.
//
// Returns:
//  Structure - added and deleted in the process of update templates, keys:
//   AddedModified - ValueTable, columns:
//    Ref - CatalogRef.JobQueueTemplates - template catalog.
//      Ref identifier equals to scheduled job identifier.
//    Use - Boolean - check box of job usage.
//    Schedule    - JobSchedule - schedule of job.
//
//   Deleted   - UUID values array - added 
//       templates IDs
// 
Function RefreshJobQueueTemplates(Parameters)
	
	If Not CommonUseReUse.DataSeparationEnabled() Then
		Return New Structure("Added, Deleted", New Array, New Array);
	EndIf;
	
	Block = New DataLock;
	Block.Add("Catalog.JobQueueTemplates");
	
	BeginTransaction();
	Try
		Block.Lock();
		
		TableOfTemplates = New ValueTable;
		TableOfTemplates.Columns.Add("Ref", New TypeDescription("CatalogRef.JobQueueTemplates"));
		TableOfTemplates.Columns.Add("Use", New TypeDescription("Boolean"));
		TableOfTemplates.Columns.Add("MethodName", New TypeDescription("String", , New StringQualifiers(255, AllowedLength.Variable)));
		TableOfTemplates.Columns.Add("Key", New TypeDescription("String", , New StringQualifiers(128, AllowedLength.Variable)));
		TableOfTemplates.Columns.Add("RestartCountOnFailure", New TypeDescription("Number", New NumberQualifiers(10, 0)));
		TableOfTemplates.Columns.Add("RestartIntervalOnFailure", New TypeDescription("Number", New NumberQualifiers(10, 0)));
		TableOfTemplates.Columns.Add("Schedule", New TypeDescription("JobSchedule"));
		TableOfTemplates.Columns.Add("Presentation", New TypeDescription("String", , New StringQualifiers(150, AllowedLength.Variable)));
		TableOfTemplates.Columns.Add("Name", New TypeDescription("String", , New StringQualifiers(255, AllowedLength.Variable)));
		
		NamesOfTemplates = GetJobQueueTemplatesList();
		
		Jobs = ScheduledJobs.GetScheduledJobs();
		For Each Task In Tasks Do
			If NamesOfTemplates.Find(Task.Metadata.Name) <> Undefined Then
				NewRow = TableOfTemplates.Add();
				NewRow.Ref = Catalogs.JobQueueTemplates.GetRef(Task.UUID);
				NewRow.Use = Task.Metadata.Use;
				NewRow.MethodName = Task.Metadata.MethodName;
				NewRow.Key = Task.Metadata.Key;
				NewRow.RestartCountOnFailure = 
					Task.Metadata.RestartCountOnFailure;
				NewRow.RestartIntervalOnFailure = 
					Task.Metadata.RestartIntervalOnFailure;
				NewRow.Schedule = Task.Schedule;
				NewRow.Presentation = Task.Metadata.Presentation();
				NewRow.Name = Task.Metadata.Name;
				
				If Not Parameters.ExclusiveMode
					AND Task.Use Then
					
					Parameters.ExclusiveMode = True;
					
					RollbackTransaction();
					
					Return Undefined;
				EndIf;
				
				Task.Use = False;
				Task.Write();
			EndIf;
		EndDo;
		
		DeletedTemplates = New Array;
		AddedModifiedTemplates = New ValueTable;
		AddedModifiedTemplates.Columns.Add("Ref", New TypeDescription("CatalogRef.JobQueueTemplates"));
		AddedModifiedTemplates.Columns.Add("Use", New TypeDescription("Boolean"));
		AddedModifiedTemplates.Columns.Add("Key", New TypeDescription("String", , New StringQualifiers(128, AllowedLength.Variable)));
		AddedModifiedTemplates.Columns.Add("Schedule", New TypeDescription("JobSchedule"));
		
		Query = New Query;
		Query.Text =
		"SELECT
		|	JobQueueTemplates.Ref AS Ref,
		|	JobQueueTemplates.Use,
		|	JobQueueTemplates.Key,
		|	JobQueueTemplates.Schedule
		|FROM
		|	Catalog.JobQueueTemplates AS JobQueueTemplates";
		SourceTableTemplates = Query.Execute().Unload();
		
		// Process added / changed templates.
		For Each TableRow In TableOfTemplates Do
			
			TemplateChanged = False;
			
			TemplateSourceRow = SourceTableTemplates.Find(TableRow.Ref, "Ref");
			If TemplateSourceRow = Undefined
				OR TableRow.Use <> TemplateSourceRow.Use
				OR TableRow.Key <> TemplateSourceRow.Key
				OR Not CommonUseClientServer.SchedulesAreEqual(TableRow.Schedule, 
					TemplateSourceRow.Schedule.Get()) Then
					
				StringChanges = AddedModifiedTemplates.Add();
				StringChanges.Ref = TableRow.Ref;
				StringChanges.Use = TableRow.Use;
				StringChanges.Key = TableRow.Key;
				StringChanges.Schedule = TableRow.Schedule;
				
				TemplateChanged = True;
				
			EndIf;
			
			If TemplateSourceRow = Undefined Then
				Pattern = Catalogs.JobQueueTemplates.CreateItem();
				Pattern.SetNewObjectRef(TableRow.Ref);
			Else
				Pattern = TableRow.Ref.GetObject();
				SourceTableTemplates.Delete(TemplateSourceRow);
			EndIf;
			
			If TemplateChanged
				OR Pattern.Description <> TableRow.Presentation
				OR Pattern.MethodName <> TableRow.MethodName
				OR Pattern.RestartCountOnFailure <> TableRow.RestartCountOnFailure
				OR Pattern.RestartIntervalOnFailure <> TableRow.RestartIntervalOnFailure
				OR Pattern.Name <> TableRow.Name Then
				
				If Not Parameters.ExclusiveMode Then
					Parameters.ExclusiveMode = True;
					RollbackTransaction();
					Return Undefined;
				EndIf;
				
				Pattern.Description = TableRow.Presentation;
				Pattern.Use = TableRow.Use;
				Pattern.MethodName = TableRow.MethodName;
				Pattern.Key = TableRow.Key;
				Pattern.RestartCountOnFailure = TableRow.RestartCountOnFailure;
				Pattern.RestartIntervalOnFailure = TableRow.RestartIntervalOnFailure;
				Pattern.Schedule = New ValueStorage(TableRow.Schedule);
				Pattern.Name = TableRow.Name;
				Pattern.Write();
			EndIf;
			
		EndDo;
		
		// Process deleted templates.
		For Each TemplateSourceRow In SourceTableTemplates Do
			If Not Parameters.ExclusiveMode Then
				Parameters.ExclusiveMode = True;
				RollbackTransaction();
				Return Undefined;
			EndIf;
			
			Pattern = TemplateSourceRow.Ref.GetObject();
			Pattern.DataExchange.Load = True;
			Pattern.Delete();
			
			DeletedTemplates.Add(TemplateSourceRow.Ref);
		EndDo;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	Return New Structure("AddedModified, Deleted", AddedModifiedTemplates, DeletedTemplates);
	
EndFunction

Function GetJobQueueTemplatesList()
	
	Patterns = New Array;
	
	EventHandlers = CommonUse.ServiceEventProcessor(
		"StandardSubsystems.SaaS.JobQueue\ListOfTemplatesOnGet");
	
	For Each Handler In EventHandlers Do
		Handler.Module.ListOfTemplatesOnGet(Patterns);
	EndDo;
	
	JobQueueOverridable.ListOfTemplatesOnGet(Patterns);
	// For backward compatibility.
	JobQueueOverridable.FillSeparatedScheduledJobList(Patterns);
	
	Return Patterns;
	
EndFunction

#EndRegion
