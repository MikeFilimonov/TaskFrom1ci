﻿#Region Variables

&AtClient
Var CheckIteration;

#EndRegion

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	If CommonUseReUse.DataSeparationEnabled() Then
		FormHeaderText = NStr("en = 'Export data to migrate to the on premises version'");
		MessageText      = NStr("en = 'Data from the service will be exported to the
		                        |file for its following import and use in the local version.'");
	Else
		FormHeaderText = NStr("en = 'Export data to migrate to the SaaS version'");
		MessageText      = NStr("en = 'Data from the local version will be exported to the
		                        |file for its following import and use in the service mode.'");
	EndIf;
	Items.WarningDecoration.Title = MessageText;
	Title = FormHeaderText;
	
EndProcedure

#EndRegion

#Region FormHeaderItemEventHandlers

&AtClient
Procedure OpenActiveUsersForm(Command)
	
	OpenForm("DataProcessor.ActiveUsers.Form.ActiveUsersListForm");
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure ExportData(Command)
	
	StartDataExportAtServer();
	
	Items.GroupPages.CurrentPage = Items.Export;
	
	CheckIteration = 1;
	
	AttachIdleHandler("CheckExportReadyState", 15);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient 
Procedure SaveExportFile()
	
	FileName = "data_dump.zip";
	
	DialogueParameters = New Structure;
	DialogueParameters.Insert("Filter", "ZIP archive(*.zip)|*.zip");
	DialogueParameters.Insert("Extension", "zip");
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("FileName", FileName);
	AdditionalParameters.Insert("DialogueParameters", DialogueParameters);
	
	AlertFileOperationsConnectionExtension = New NotifyDescription(
		"SelectAndSaveFileAfterConnectionFileOperationsExtension",
		ThisForm, AdditionalParameters);
	
	BeginAttachingFileSystemExtension(AlertFileOperationsConnectionExtension);
	
EndProcedure

&AtClient 
Procedure SelectAndSaveFileAfterConnectionFileOperationsExtension(Attached, AdditionalParameters) Export
	
	If Attached Then
		
		FileDialog = New FileDialog(FileDialogMode.Save);
		FillPropertyValues(FileDialog, AdditionalParameters.DialogueParameters);
		
		FilesToReceive = New Array;
		FilesToReceive.Add(New TransferableFileDescription(AdditionalParameters.FileName, StorageAddress));
		
		FilesReceiptAlertDescription = New NotifyDescription(
			"SelectAndSaveFile",
			ThisForm, AdditionalParameters);
		
		BeginGettingFiles(FilesReceiptAlertDescription, FilesToReceive, FileDialog, True);
		
	Else
		
		GetFile(StorageAddress, AdditionalParameters.FileName, True);
		Close();
		
	EndIf;
	
EndProcedure

&AtClient 
Procedure SelectAndSaveFile(ReceivedFiles, AdditionalParameters) Export
	
	Close();
	
EndProcedure

&AtServerNoContext
Procedure SwitchOffExclusiveModeAfterExport()
	
	SetExclusiveMode(False);
	
EndProcedure

&AtClient
Procedure CheckExportReadyState()
	
	Try
		ExportReadyState = ExportDataReady();
	Except
		
		ErrorInfo = ErrorInfo();
		
		DetachIdleHandler("CheckExportReadyState");
		SwitchOffExclusiveModeAfterExport();
		
		HandleError(
			BriefErrorDescription(ErrorInfo),
			DetailErrorDescription(ErrorInfo));
		
	EndTry;
	
	If ExportReadyState Then
		SwitchOffExclusiveModeAfterExport();
		DetachIdleHandler("CheckExportReadyState");
		SaveExportFile();
	Else
		
		CheckIteration = CheckIteration + 1;
		
		If CheckIteration = 3 Then
			DetachIdleHandler("CheckExportReadyState");
			AttachIdleHandler("CheckExportReadyState", 30);
		ElsIf CheckIteration = 4 Then
			DetachIdleHandler("CheckExportReadyState");
			AttachIdleHandler("CheckExportReadyState", 60);
		EndIf;
			
	EndIf;
	
EndProcedure

&AtServerNoContext
Function FindJobByID(ID)
	
	Task = BackgroundJobs.FindByUUID(ID);
	
	Return Task;
	
EndFunction

&AtServer
Function ExportDataReady()
	
	Task = FindJobByID(JobID);
	
	If Task <> Undefined
		AND Task.State = BackgroundJobState.Active Then
		
		Return False;
	EndIf;
	
	Items.GroupPages.CurrentPage = Items.Warning;
	
	If Task = Undefined Then
		Raise(NStr("en = 'An error occurred when preparing export, export preparation job is not found.'"));
	EndIf;
	
	If Task.State = BackgroundJobState.Failed Then
		JobError = Task.ErrorInfo;
		If JobError <> Undefined Then
			Raise(DetailErrorDescription(JobError));
		Else
			Raise(NStr("en = 'An error occurred when preparing export, export preparation job was completed with an unknown error.'"));
		EndIf;
	ElsIf Task.State = BackgroundJobState.Canceled Then
		Raise(NStr("en = 'An error occurred when preparing export, export preparation job was canceled by the administrator.'"));
	Else
		JobID = Undefined;
		Return True;
	EndIf;
	
EndFunction

&AtServer
Procedure StartDataExportAtServer()
	
	SetExclusiveMode(True);
	
	Try
		
		StorageAddress = PutToTempStorage(Undefined, UUID);
		
		JobParameters = New Array;
		JobParameters.Add(StorageAddress);
		
		Task = BackgroundJobs.Execute("DataAreasExportImport.ExportCurrentDataAreaIntoTemporaryStorage", 
			JobParameters,
			,
			NStr("en = 'Prepare data area export'"));
			
		JobID = Task.UUID;
		
	Except
		
		ErrorInfo = ErrorInfo();
		SetExclusiveMode(False);
		HandleError(
			BriefErrorDescription(ErrorInfo),
			DetailErrorDescription(ErrorInfo));
		
	EndTry;
	
EndProcedure

&AtClient
Procedure OnClose(Exit)
	
	If Exit Then
		Return;
	EndIf;
	
	If ValueIsFilled(JobID) Then
		CancelInitializationJob(JobID);
		SwitchOffExclusiveModeAfterExport();
	EndIf;
	
EndProcedure

&AtServerNoContext
Procedure CancelInitializationJob(Val JobID)
	
	Task = FindJobByID(JobID);
	If Task = Undefined
		OR Task.State <> BackgroundJobState.Active Then
		
		Return;
	EndIf;
	
	Try
		Task.Cancel();
	Except
		// The job might end at the moment and there is no error.
		WriteLogEvent(NStr("en = 'Job execution on data area export preparation canceled'", 
			CommonUseClientServer.MainLanguageCode()),
			EventLogLevel.Error,,,
			DetailErrorDescription(ErrorInfo()));
	EndTry;
	
EndProcedure

&AtServerNoContext
Procedure HandleError(Val ShortPresentation, Val DetailedPresentation)
	
	WriteLogEventTemplate = NStr("en = 'An error occurred when exporting data: ----------------------------------------- %1 -----------------------------------------'");
	WriteLogEventText = StringFunctionsClientServer.SubstituteParametersInString(WriteLogEventTemplate, DetailedPresentation);
	
	WriteLogEvent(
		NStr("en = 'Data export'"),
		EventLogLevel.Error,
		,
		,
		WriteLogEventText);
	
	ExceptionPattern = NStr("en = 'An error occurred while exporting the data: %1.
	                        |
	                        |Detailed information for support service is written to the events log monitor. If you do not know the reason of error, you are recommended to contact the technical support service providing to them the infobase and exported event log monitor for investigation.'");
	
	Raise StringFunctionsClientServer.SubstituteParametersInString(ExceptionPattern, ShortPresentation);
	
EndProcedure

#EndRegion
