#Region Variables

&AtClient
Var IdleHandlerParameters;

#EndRegion

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	If Not Parameters.Property("OpenFromList") Then
		// Open by navigation reference.
		If WorkWithBanks.ClassifierIsActual() Then
			NotifyClassifierIsActual = True;
			Return;
		EndIf;
	EndIf;
	
	Settings = WorkWithBanks.Settings();
	UseImportFromWeb = Settings.UseImportFromWeb;	
	UseImportFromFile = Settings.UseImportFromFile;	
	
	If CommonUseClientServer.ThisIsWebClient() Or (UseImportFromWeb AND Not UseImportFromFile) Then
		AutoSaveDataInSettings = AutoSaveFormDataInSettings.DontUse;
		Items.ImportingOption.Enabled = False;
		Items.PathToFile.Enabled = False;
		Items.FormPages.CurrentPage = Items.ImportingFromWebsite;
	ElsIf UseImportFromWeb AND UseImportFromFile Then
		Items.FormPages.CurrentPage = Items.PageSelectSource;
	ElsIf UseImportFromFile Then
		Items.FormPages.CurrentPage = Items.ImportingFromFile;
		ImportingOption = "FILE";
	Else
		Raise NStr("en = 'Import methods are not set in bank classifier import processor'");
	EndIf;
	
	VerifyAccessRights("Update", Metadata.Catalogs.BankClassifier);
	ImportingOption = "WEB";
	
	SetChangesInInterface();
EndProcedure

&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	SetChangesInInterface();
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	If NotifyClassifierIsActual Then
		WorkWithBanksClient.NotifyClassifierIsActual();
		Cancel = True;
		Return;
	EndIf;
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure ImportingOptionOnChange(Item)
	SetChangesInInterface();
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure GoToNext(Command)
	
	If Items.FormPages.CurrentPage = Items.ResultPage Then
		Close();
	Else
		ClearMessages();
		
		If ImportingOption = "File" AND Not ValueIsFilled(PathToFile) AND CommonUseClientServer.IsLinuxClient() Then
			// Under Linux - search of drive letters is impossible.
			CommonUseClientServer.MessageToUser(
				NStr("en = 'When working under Linux OS it is necessary to distinctly specify the path to the file'"),
				,
				"PathToFile");
			Return;
		EndIf;
		Items.FormPages.CurrentPage = Items.ImportingInProgress;
		SetChangesInInterface();
		AttachIdleHandler("ImportClassifier", 0.1, True);
	EndIf;

EndProcedure

&AtClient
Procedure Back(Command)
	CurrentPage = Items.FormPages.CurrentPage;
	
	If CurrentPage = Items.ResultPage Then
		#If WebClient Then
		Items.FormPages.CurrentPage = Items.ImportingFromWebsite;
		#Else
		Items.FormPages.CurrentPage = Items.PageSelectSource;
		#EndIf
	EndIf;
	
	SetChangesInInterface();

EndProcedure

&AtClient
Procedure Cancel(Command)
	If ValueIsFilled(JobID) Then
		CompleteBackgroundTasks(JobID);
	EndIf;
	Close();
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

#Region Client

&AtClient
Procedure ImportClassifier()
	// Imports bank classifier from file or from website.
	
	ClassifierImportParameters = New Map;
	// (Number) Quantity of new classifier records:
	ClassifierImportParameters.Insert("Exported", 0);
	// (Number) Quantity of updated classifier records:
	ClassifierImportParameters.Insert("Updated", 0);
	// (String) Message text about import results:
	ClassifierImportParameters.Insert("MessageText", "");
	// (Boolean) Flag of successfull classifier data import complete:
	ClassifierImportParameters.Insert("ImportCompleted", False);
	
	If ImportingOption = "FILE" Then
		GetDataFile(ClassifierImportParameters);
		StorageAddress = PutToTempStorage(Undefined, UUID);
		PutToTempStorage(ClassifierImportParameters, StorageAddress);
		Result = New Structure("JobCompleted, StorageAddress", True, StorageAddress);
	ElsIf ImportingOption = "WEB" Then
		Result = GetDataFromWebsite(ClassifierImportParameters);
	EndIf;
	
	StorageAddress = Result.StorageAddress;
	If Not Result.JobCompleted Then
		JobID = Result.JobID;
		
		LongActionsClient.InitIdleHandlerParameters(IdleHandlerParameters);
		AttachIdleHandler("Attachable_CheckJobExecution", 1, True);
	Else
		ImportResult();
	EndIf;
 	
EndProcedure

&AtClient
Procedure ImportResult()
	// Displays the import attempt result of Russian Federation bank
	// classifier in the events log monitor and in import form.
	
	If ImportingOption = "FILE" Then
		Source = NStr("en = 'File'");
	Else
		Source = NStr("en = 'Website'");
	EndIf;
	
	ClassifierImportParameters = GetFromTempStorage(StorageAddress);
	
	EventName = StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en = 'Bank classifier import. %1.'"), Source);
	
	If ClassifierImportParameters["ImportCompleted"] Then
		EventLogMonitorClient.AddMessageForEventLogMonitor(EventName,, 
			ClassifierImportParameters["MessageText"],, True);
		WorkWithBanksClient.NotifyClassifierUpdatedSuccessfully();
	Else
		EventLogMonitorClient.AddMessageForEventLogMonitor(EventName, 
			"Error", ClassifierImportParameters["MessageText"],, True);
	EndIf;
	Items.ExplanationText.Title = ClassifierImportParameters["MessageText"];
	
	Items.FormPages.CurrentPage = Items.ResultPage;
	SetChangesInInterface();
	
	If (ClassifierImportParameters["Updated"] > 0) Or (ClassifierImportParameters["Exported"] > 0) Then
		NotifyChanged(Type("CatalogRef.BankClassifier"));
	EndIf;
	
EndProcedure

&AtClient
Procedure Attachable_CheckJobExecution()
	JobCompleted = Undefined;
	Try
		JobCompleted = JobCompleted(JobID);
	Except
		EventLogMonitorClient.AddMessageForEventLogMonitor(NStr("en = 'Bank classifier import. %1.'", CommonUseClientServer.MainLanguageCode()),
			"Error", DetailErrorDescription(ErrorInfo()), , True);
			
		Items.ExplanationText.Title = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Bank classifier import is aborted by the reason of: %1
			     |Details see in events log monitor.'"),
			BriefErrorDescription(ErrorInfo()));
			
		Items.FormPages.CurrentPage = Items.ResultPage;
		SetChangesInInterface();
		Return;
	EndTry;
		
	If JobCompleted Then 
		ImportResult();
	Else
		LongActionsClient.UpdateIdleHandlerParameters(IdleHandlerParameters);
		AttachIdleHandler(
			"Attachable_CheckJobExecution", 
			IdleHandlerParameters.CurrentInterval, 
			True);
	EndIf;

EndProcedure

&AtClient
Procedure GetDataFile(ClassifierImportParameters) 
	// Receives, sorts, writes classifier data from file.
	
	FilesImportingParameters = New Map;
	// (String) Path to File:
	FilesImportingParameters.Insert("PathToFile", "");
	// (String) Error text:
	FilesImportingParameters.Insert("MessageText", ClassifierImportParameters["MessageText"]);
	// Other parameters - see variable description FileImportParameters in ImportClassifier():
	FilesImportingParameters.Insert("Exported", ClassifierImportParameters["Exported"]);
	FilesImportingParameters.Insert("Updated", ClassifierImportParameters["Updated"]);
	
	DataExportFile(FilesImportingParameters);
	DataExportFileOnServer(FilesImportingParameters);
	
	ClassifierImportParameters.Insert("Exported", FilesImportingParameters["Exported"]);
	ClassifierImportParameters.Insert("Updated", FilesImportingParameters["Updated"]);
	ClassifierImportParameters.Insert("MessageText", FilesImportingParameters["MessageText"]);
	ClassifierImportParameters.Insert("ImportCompleted", True);
	
EndProcedure

&AtClient
Procedure DataExportFile(FilesImportingParameters)
	// Receives classifier data from file.
	
	DataFile = Undefined;
	FileFound = False;
	
	Result = New Structure;
	If ValueIsFilled(PathToFile) Then
		// Path to the file is specified clearly.
		DataFile = New File(PathToFile);
		If DataFile.Exist() Then
			FilesImportingParameters.Insert("PathToFile", PathToFile);
			FileFound = True;
		Else
			SupportData = "";
		EndIf;
	EndIf;
	
	If FileFound Then
		FileBinaryDataAddress = PutToTempStorage(New BinaryData(DataFile.FullName));
		FilesImportingParameters.Insert("FileBinaryDataAddress", FileBinaryDataAddress);
		DataFile = Undefined;
	Else
		MessageText = NStr("en = 'Classifier data was not found.'");
		FilesImportingParameters.Insert("MessageText", MessageText);
	EndIf;
	
	FilesImportingParameters.Insert("MessageText", MessageText);
	
EndProcedure

#EndRegion

#Region CallingTheServer

&AtServerNoContext
Function JobCompleted(JobID)
	Return LongActions.JobCompleted(JobID);
EndFunction

&AtServer
Procedure SetChangesInInterface()
	// Depending on the current page it sets the accessibility of certain fields for the user.
	
	Items.PathToFile.Enabled = (ImportingOption = "FILE");
	
	If Items.FormPages.CurrentPage = Items.PageSelectSource
		Or Items.FormPages.CurrentPage = Items.ImportingFromFile 
		Or Items.FormPages.CurrentPage = Items.ImportingFromWebsite Then
		Items.FormButtonBack.Visible  = False;
		Items.FormNextButton.Title = NStr("en = 'Import'");
		Items.FormCancelButton.Enabled = True;
		Items.FormNextButton.Enabled  = True;
	ElsIf Items.FormPages.CurrentPage = Items.ImportingInProgress Then
		Items.FormButtonBack.Visible = False;
		Items.FormNextButton.Enabled  = False;
		Items.FormCancelButton.Enabled = True;
	Else
		Items.FormButtonBack.Visible = True;
		Items.FormNextButton.Title = NStr("en = 'Close'");
		Items.FormCancelButton.Enabled = False;
		Items.FormNextButton.Enabled  = True;
	EndIf;
	
EndProcedure

&AtServer
Procedure CompleteBackgroundTasks(JobID)
	BackgroundJob = BackgroundJobs.FindByUUID(JobID);
	If BackgroundJob <> Undefined Then
		BackgroundJob.Cancel();
	EndIf;
EndProcedure

&AtServer
Procedure DataExportFileOnServer(FilesImportingParameters)
	// Imports data from file in the bank classifier.
	// 
// Parameters:
//    FilesImportingParameters - see variable description ClassifierImportParameters
	//                                in GetDataFile().
	
	If CommonUseReUse.DataSeparationEnabled() Then
		Raise TextImportingIsProhibited();
	EndIf;
	
	WorkWithBanks.ImportDataFile(FilesImportingParameters);
	
EndProcedure

&AtServer
Function GetDataFromWebsite(FilesImportingParameters)
	// Imports data from file to the bank classifier.
	//
// Parameters:
	//   FilesImportingParameters - see description of the same name variable in ImportClassifier().
	
	If CommonUseReUse.DataSeparationEnabled() Then
		Raise TextImportingIsProhibited();
	EndIf;
	
	JobDescription = NStr("en = 'Import bank classifier'");
	
	Result = LongActions.ExecuteInBackground(
		UUID,
		"WorkWithBanks.GetWebsiteData", 
		FilesImportingParameters, 
		JobDescription);
	
	Return Result;
	
EndFunction

#EndRegion

#Region Server

&AtServer
Function TextImportingIsProhibited()
	Return NStr("en = 'Import of the bank classifier in the separated mode is prohibited'");
EndFunction

&AtClient
Procedure PathToFileStartChoice(Item, ChoiceData, StandardProcessing)
	ClearMessages();
	
	SelectDialog = New FileDialog(FileDialogMode.Open);
	SelectDialog.Title = NStr("en = 'Choose the path '");
	SelectDialog.Directory   = PathToFile;
	
	If Not SelectDialog.Choose() Then
		Return;
	EndIf;
	
	PathToFile = SelectDialog.FullFileName;
EndProcedure

&AtClient
Procedure PathToFile1StartChoice(Item, ChoiceData, StandardProcessing)
	ClearMessages();
	
	SelectDialog = New FileDialog(FileDialogMode.Open);
	SelectDialog.Title = NStr("en = 'Specify path '");
	SelectDialog.Directory   = PathToFile;
	
	If Not SelectDialog.Choose() Then
		Return;
	EndIf;
	
	PathToFile = SelectDialog.FullFileName;
EndProcedure

#EndRegion

#EndRegion
