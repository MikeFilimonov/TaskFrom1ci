#Region FormHeaderItemEventHandlers

&AtClient
Procedure OpenActiveUsersForm(Item)
	
	OpenForm("DataProcessor.ActiveUsers.Form.ActiveUsersListForm");
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Import(Command)
	
	NotifyDescription = New NotifyDescription("ContinueDataImport", ThisObject);
	BeginPutFile(NotifyDescription, , "data_dump.zip");
	
EndProcedure

&AtClient
Procedure ContinueDataImport(SelectionComplete, StorageAddress, SelectedFileName, AdditionalParameters) Export
	
	If SelectionComplete Then
		
		Status(
			NStr("en = 'Data is being imported from the service.
			     |Operation can take a long time, please, wait...'"),);
		
		RunImport(StorageAddress, ExportUserDetails);
		Terminate(True);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServerNoContext
Procedure RunImport(Val FileURL, Val ExportUserDetails)
	
	SetExclusiveMode(True);
	
	Try
		
		ArchiveData = GetFromTempStorage(FileURL);
		ArchiveName = GetTempFileName("zip");
		ArchiveData.Write(ArchiveName);
		
		DataAreasExportImport.ImportCurrentDataAreaFromArchive(ArchiveName, ExportUserDetails, True);
		
		DataExportImportService.DeleteTemporaryFile(ArchiveName);
		
		SetExclusiveMode(False);
		
	Except
		
		ErrorInfo = ErrorInfo();
		
		SetExclusiveMode(False);
		
		WriteLogEventTemplate = NStr("en = 'An error occurred while importing data:
		                             |-----------------------------------------
		                             |%1
		                             |-----------------------------------------'");
		WriteLogEventText = StringFunctionsClientServer.SubstituteParametersInString(WriteLogEventTemplate, DetailErrorDescription(ErrorInfo));

		WriteLogEvent(
			NStr("en = 'Data Import'"),
			EventLogLevel.Error,
			,
			,
			WriteLogEventText);

		ExceptionPattern = NStr("en = 'An error occurred during data import: %1.
		                        |
		                        |Detailed information for support service is written to the events log monitor. If you do not know the cause of error, you should contact technical support service providing the donwloaded events log monitor and file from which it was attempted to import data.'");

		Raise StringFunctionsClientServer.SubstituteParametersInString(ExceptionPattern, BriefErrorDescription(ErrorInfo));
		
	EndTry;
	
EndProcedure

#EndRegion
