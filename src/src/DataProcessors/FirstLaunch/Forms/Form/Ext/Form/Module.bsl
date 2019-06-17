#Region Variables

&AtClient
Var IdleHandlerParameters;

#EndRegion

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("FirstLaunchPassed")
		And Not Parameters.FirstLaunchPassed Then
		
		UpdateConfigurationPackage = False;
		
	ElsIf Parameters.Property("UpdateConfigurationPackage")
		And Parameters.UpdateConfigurationPackage Then
		
		UpdateConfigurationPackage = True;
		
		CustomizationRegion = Constants.CustomizationRegion.Get();
		If ValueIsFilled(CustomizationRegion) Then
			Country = CustomizationRegion;
		Else
			Country = "Default";
		EndIf;
	EndIf;
	
	SystemVersion = Metadata.Version;
	ConfigurationName = Metadata.Name;
	
	PathToConfigurationPackage = "";
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If Not ValueIsFilled(PathToConfigurationPackage) Then
		SetPathToConfigurationPackage();
	EndIf;
	
	If UpdateConfigurationPackage Then
		AttachIdleHandler("Attachable_LoadConfigurationData", 0.2, True);
	Else
		AttachIdleHandler("Attachable_FillCountries", 0.2, True);
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	If Not InitialSetupDone Then
		
		StandardProcessing	= False;
		Cancel				= True;
		
		WarningText = NStr("en = 'Initial configuration setup is a mandatory step and cannot be omitted.'");
		
		If Exit Then
			Return;
		EndIf;
			
		Buttons = New ValueList;
		Buttons.Add("Exit", NStr("en = 'Exit'"));
		Buttons.Add("Cancel", NStr("en = 'Cancel'"));
				
		Notification = New NotifyDescription("ConfirmFormClosingEnd", ThisObject, Parameters);
		ShowQueryBox(Notification, WarningText, Buttons,, "Cancel");
		
	ElsIf ExtensionsLoaded Then
		Terminate(True);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure DecorationLoadURLProcessing(Item, FormattedStringURL, StandardProcessing)
	StandardProcessing = False;
	LoadFromCustomFile();
EndProcedure

&AtClient
Procedure PathToConfigurationPackageStartChoice(Item, ChoiceData, StandardProcessing)
	StandardProcessing = False;
	LoadFromCustomFile();
EndProcedure

&AtClient
Procedure CountryOnChange(Item)
	RefreshFormData();
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure CancelBackgroundJob(Command)
	CancelBackgroundJobAtServer(JobID);
	SetCurrentPage();
EndProcedure

&AtClient
Procedure OK(Command)
	
	If LanguageIsChanged Then
		Terminate(True, "/C ""RunInfobaseUpdate; DisableUpdateConfigurationPackage""");
	Else
		Close();
	EndIf;
	
EndProcedure

&AtClient
Procedure Proceed(Command)
	
	If Items.GroupPages.CurrentPage = Items.GroupHomePage Then
		
		If Country = "" Then 
			CommonUseClientServer.MessageToUser(
				NStr("en = 'Choose your country'")
					,
					,
					"Country");
		Else
			Items.GroupPages.CurrentPage = Items.GroupLoadingPage;
			AttachIdleHandler("Attachable_FillPredefinedData", 0.2, True);
		EndIf;
		
	ElsIf Items.GroupPages.CurrentPage = Items.GroupChooseConfigurationPackageManually Then
		
		If PathToConfigurationPackage = "" Then 
			CommonUseClientServer.MessageToUser(
				NStr("en = 'Choose your configuration file'"));
		Else
			Items.GroupPages.CurrentPage = Items.GroupLoadingPage;
			If UpdateConfigurationPackage Then
				AttachIdleHandler("Attachable_LoadConfigurationData", 0.2, True);
			Else
				AttachIdleHandler("Attachable_FillCountries", 0.2, True);
			EndIf;
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure SeeEventLog(Command)
	OpenForm("DataProcessor.EventLogMonitor.Form");
EndProcedure

#EndRegion

#Region Private

#Region AttachableAndNotifyProceduresAndFunctions

&AtClient
Procedure Attachable_CheckJobExecution()
	
	Try
		JobCompleted = JobCompleted(JobID);
	Except
		
		SetCurrentPage();
		
		ErrorInfo = BriefErrorDescription(ErrorInfo());
		ShowErrorMessageToUser(ErrorInfo);
		
		Return;
	EndTry;
	
	If JobCompleted Then
		AfterJobComplete();
	Else
		LongActionsClient.UpdateIdleHandlerParameters(IdleHandlerParameters);
		AttachIdleHandler("Attachable_CheckJobExecution", IdleHandlerParameters.CurrentInterval, True);
	EndIf;

EndProcedure

&AtClient
Procedure Attachable_FillCountries()
	
	If ValueIsFilled(PathToConfigurationPackage) Then
		
		File = New File(PathToConfigurationPackage);
		If File.Exist() Then
			StorageAddress = PutToTempStorage(New BinaryData(PathToConfigurationPackage));
			LoadCountriesFromFirstLaunch(StorageAddress);
		Else
			SetDefaultCountry();
		EndIf;
	Else
		SetDefaultCountry();
	EndIf;
	
EndProcedure

&AtClient
Procedure Attachable_LoadConfigurationData()
	
	ConfigurationPackage = New File(PathToConfigurationPackage);
	
	If Upper(Country) = "DEFAULT" Then
		AttachIdleHandler("Attachable_FillPredefinedData", 0.2, True);
	ElsIf ConfigurationPackage.Exist() Then
		Folder = PathToCountryFolder(Country);
		If ValueIsFilled(Folder) Then
			AttachIdleHandler("Attachable_FillPredefinedData", 0.2, True);
		Else
			AttachIdleHandler("Attachable_FillCountries", 0.2, True);
		EndIf;
		Items.GroupPages.CurrentPage = Items.GroupLoadingPage;
	Else
		SetPathToConfigurationPackageManually();
	EndIf;
	
EndProcedure

&AtClient
Procedure Attachable_FillPredefinedData()
	
	If ValueIsFilled(PathToConfigurationPackage) Then
		
		File = New File(PathToConfigurationPackage);
		If File.Exist() Then
			StorageAddress = PutToTempStorage(New BinaryData(PathToConfigurationPackage));
		Else
			SetPathToConfigurationPackageManually();
		EndIf;
	Else
		StorageAddress = Undefined;
	EndIf;
	
	Result = FillPredefinedDataInBackground(StorageAddress);
	AfterBackgroundJobStarts(Result);
	
EndProcedure

&AtClient
Procedure Attachable_ApplyExtensions()
	
	Try
		Result = ApplyExtensions();
		If TypeOf(Result) = Type("String") Then
			
			Items.GroupPages.CurrentPage = Items.GroupHomePage;
			CommonUseClientServer.MessageToUser(Result);
			
			AnErrorOnLoadingExtensions = True;
			
			Return;
		EndIf;
		
		ClearMessages();
		CommonUseClientServer.MessageToUser(
			NStr("en = 'Configuration extensions applied succesfully'"));
		
		AfterBackgroundJobStarts(Result);
		
	Except
		Items.GroupPages.CurrentPage = Items.GroupHomePage;
		ShowErrorMessageToUser(ErrorDescription());
		AnErrorOnLoadingExtensions = True;
	EndTry;
		
EndProcedure

&AtServer
Function FillPredefinedDataInBackground(StorageAddress)
	
	If Upper(Country) = "DEFAULT" Then
		
		LanguageIsChanged = False;
		JobParameters = New Structure();
		JobParameters.Insert("ExtensionsLoaded", ExtensionsLoaded);
		JobParameters.Insert("UpdateConfigurationPackage", UpdateConfigurationPackage);
		JobParameters.Insert("FullPath", "default");
		ProcedureName = "InfobaseUpdateDrive.ExecuteFillByDefault";
		JobDescription = NStr("en = 'First launch - fill by default is in a progress'");
		
	Else
		
		JobParameters = New Structure();
		JobParameters.Insert("FullPath", Folder);
		JobParameters.Insert("ExtensionsLoaded", ExtensionsLoaded);
		JobParameters.Insert("ZIP", GetFromTempStorage(StorageAddress));
		JobParameters.Insert("UpdateConfigurationPackage", UpdateConfigurationPackage);
		JobParameters.Insert("LanguageIsChanged", LanguageIsChanged);
		
		ProcedureName = "InfobaseUpdateDrive.ExecuteFillPredefinedData";
		JobDescription = NStr("en = 'First launch - fill predefined data from file is in a progress'");
		
	EndIf;
	
	Return LongActions.ExecuteInBackground(UUID, ProcedureName, JobParameters, JobDescription);
	
EndFunction

&AtClient
Procedure ConfirmFormClosingEnd(Response, Parameters) Export
	
	If Response = "Exit" Then
		Terminate();
	EndIf;
	
EndProcedure

#EndRegion

#Region BackgroundJobsHandlers

&AtClient
Procedure AfterBackgroundJobStarts(Result)
	
	JobID				= Result.JobID;
	JobStorageAddress	= Result.StorageAddress;
	
	If Result.JobCompleted Then
		AfterJobComplete();
	Else
		LongActionsClient.InitIdleHandlerParameters(IdleHandlerParameters);
		AttachIdleHandler("Attachable_CheckJobExecution", 1, True);
	EndIf;
	
EndProcedure

&AtClient
Procedure AfterJobComplete()
	
	JobResult = GetFromTempStorage(JobStorageAddress);
	
	If JobResult.Done Then
		
		If JobResult.Property("Countries") Then
			
			FillCountriesAtServer(JobResult.Countries);
			
			Items.GroupPages.CurrentPage = Items.GroupHomePage;
		
		ElsIf JobResult.Property("Extensions") Then
			AttachIdleHandler("Attachable_ApplyExtensions", ?(AnErrorOnLoadingExtensions, 5, 0.2), True);
		Else
			InitialSetupDone = JobResult.Done;
			If InitialSetupDone Then
				LanguageIsChanged = JobResult.LanguageIsChanged;
				If ExtensionsLoaded Or LanguageIsChanged Then
					Items.DecorationSuccessText.Title = NStr("en = 'Configuration setup has been completed successfully. 
					                                         |1C:Drive must be restarted for changes to take effect.'");
					Items.OK.Title = NStr("en = 'Restart'");
				EndIf;
				Items.GroupPages.CurrentPage = Items.GroupFinishPage;
				Items.PagesStatus.CurrentPage = Items.PageSucces;
				UpdateServiceData(Country);
			Else
				Items.GroupPages.CurrentPage = Items.GroupHomePage;
			EndIf;
		EndIf;
	Else
		ShowErrorMessageToUser(JobResult.ErrorMessage);
	EndIf;
	
EndProcedure

&AtServerNoContext
Procedure CancelBackgroundJobAtServer(JobID)
	LongActions.CancelJobExecution(JobID);
EndProcedure

&AtServerNoContext
Function JobCompleted(JobID)
	Return LongActions.JobCompleted(JobID);
EndFunction

#EndRegion

#Region ConfigurationPackage

&AtClient
Procedure SetPathToConfigurationPackage()
	
	If CommonUseClientServer.IsWindowsClient()
		And Not CommonUseClientServer.ThisIsWebClient() Then
		
		Shell = New COMObject("WScript.Shell");
		APPDATAFolder = Shell.ExpandEnvironmentStrings("%APPDATA%");
		
		Template = APPDATAFolder + "\1C\1cv8\tmplts\1c\%1\%2\ConfigurationPackage\first_launch.zip";
		PathToConfigurationPackage = StringFunctionsClientServer.SubstituteParametersInString(
			Template,
			ConfigurationName,
			StrReplace(SystemVersion, ".", "_"));
			
	EndIf;
	
EndProcedure

&AtClient
Procedure SetDefaultCountry()
	
	DetachIdleHandler("Attachable_FillCountries");
	
	Country = "Default";
	PathToConfigurationPackage = "";
	
	Items.Country.ChoiceList.Add("Default", NStr("en = 'Initialize with default settings'"));
	Items.GroupPages.CurrentPage = Items.GroupHomePage;
	
EndProcedure

&AtClient
Procedure LoadCountriesFromFirstLaunch(StorageAddress)
	
	Result = FillCountriesInBackground(StorageAddress);
	AfterBackgroundJobStarts(Result);
	
EndProcedure

#EndRegion

#Region LongActions

&AtServer
Function FillCountriesInBackground(StorageAddress)
	
	JobParameters = New Structure("ZIP, Countries", GetFromTempStorage(StorageAddress), Countries.Unload());
	ProcedureName = "InfobaseUpdateDrive.ExecuteLoadCountriesFromFirstLaunch";
	JobDescription = NStr("en = 'First launch - countries from ZIP file loading is in a progress'");
	
	Return LongActions.ExecuteInBackground(UUID, ProcedureName, JobParameters, JobDescription);
EndFunction

&AtServerNoContext
Procedure UpdateServiceData(Country)
	
	If ValueIsFilled(Country) Then
		FolderName = PathToCountryFolder(Country);
		Constants.CustomizationRegion.Set(FolderName);
	EndIf;
	
	Constants.UpdateConfigurationPackage.Set(False);
	Constants.FirstLaunchPassed.Set(True);
	
EndProcedure

&AtServer
Function ApplyExtensions()
	
	ExtensionsLoaded = False;
	
	If Not ExclusiveModeEnabled() Then
		Return NStr("en = 'Unable to set exclusive connection mode for the infobase. 
		            |If 1C:Drive was launched from the designer, please close the designer and try again.'");
	EndIf;
	
	InternalExtensions = ConfigurationExtensions.Get();
	ExistExtensions = New Map();
	For Each InternalExtension In InternalExtensions Do
		ExistExtensions.Insert(InternalExtension.Name, InternalExtension);
	EndDo;
	
	ProtectDescription = CommonUse.ProtectDescriptionWithoutWarnings();
	
	ResultStructure = GetFromTempStorage(JobStorageAddress);
	For Each ExternalExtension In ResultStructure.Extensions Do
		
		InternalExtension = ExistExtensions.Get(ExternalExtension.Name);
		
		If ExternalExtension.Delete Then
			
			If InternalExtension = Undefined Then
				
				TextMessage = NStr("en = 'There is no extision ""%1"" for delete in configuration.'",
					CommonUseClientServer.MainLanguageCode());
					
				TextMessage = StringFunctionsClientServer.SubstituteParametersInString(TextMessage, ExternalExtension.Name);
				
				WriteLogEvent(
					"InfobaseUpdate",
					EventLogLevel.Error,
					Metadata.CommonModules.InfobaseUpdateDrive,
					ExternalExtension.Name,
					TextMessage);
					
			Else
				
				BeginTransaction();
				Try
					InternalExtension.Delete();
				Except
					RollbackTransaction();
					SetExclusiveMode(False);
					Raise BriefErrorDescription(ErrorInfo());
				EndTry;
				CommitTransaction();
				
			EndIf;
				
		Else
			
			If InternalExtension = Undefined Then
				InternalExtension = ConfigurationExtensions.Create();
				InternalExtension.UnsafeActionProtection = ProtectDescription
			EndIf;
			
			ExtensionBinary = ExternalExtension.Data.Get();
			
			BeginTransaction();
			Try
				InternalExtension.Write(ExtensionBinary);
			Except
				RollbackTransaction();
				SetExclusiveMode(False);
				Raise BriefErrorDescription(ErrorInfo());
			EndTry;
			CommitTransaction();
			
		EndIf;
		
	EndDo;
	
	SetExclusiveMode(False);
	
	ExtensionsLoaded = True;
	
	StorageAddress = PutToTempStorage(New BinaryData(PathToConfigurationPackage));
	
	Result = New Structure("StorageAddress, JobCompleted, JobID",
		StorageAddress, False, Undefined);
		
	Task = ExecutionExtensionInBackground();
	
	Timeout = ?(GetClientConnectionSpeed() = ClientConnectionSpeed.Low, 4, 2);
	
	Try
		Task.WaitForCompletion(Timeout);
	Except
		// Special processor is not required, exception may be caused by timeout.
	EndTry;

	Result.JobCompleted = JobCompleted(Task.UUID);
	Result.JobID = Task.UUID;
	
	Return Result;
EndFunction

&AtServer
Function ExecutionExtensionInBackground()
	
	If Upper(Country) = "DEFAULT" Then
		LanguageIsChanged = False;
		JobParameters = New Structure("ExtensionsLoaded, FullPath", ExtensionsLoaded, Folder);
		ProcedureName = "InfobaseUpdateDrive.ExecuteFillByDefault";
		JobDescription = NStr("en = 'First launch - fill by default is in a progress'");
	Else
		
		JobParameters = New Structure();
		JobParameters.Insert("FullPath", Folder);
		JobParameters.Insert("ExtensionsLoaded", ExtensionsLoaded);
		JobParameters.Insert("ZIP", GetFromTempStorage(StorageAddress));
		JobParameters.Insert("UpdateConfigurationPackage", UpdateConfigurationPackage);
		JobParameters.Insert("LanguageIsChanged", LanguageIsChanged);
		
		ProcedureName = "InfobaseUpdateDrive.ExecuteFillPredefinedData";
		JobDescription = NStr("en = 'First launch - fill predefined data from file is in a progress'");
	EndIf;
	
	ProcedureParameters = New Array;
	ProcedureParameters.Add(JobParameters);
	ProcedureParameters.Add(StorageAddress);
	
	Return ConfigurationExtensions.ExecuteBackgroundJobWithDatabaseExtensions(ProcedureName, ProcedureParameters, "", JobDescription);
EndFunction

&AtServer
Function ExclusiveModeEnabled()
	
	ExclusiveModeEnabled = False;
	
	Try
		SetExclusiveMode(True);
		ExclusiveModeEnabled = True;
	Except
		Return ExclusiveModeEnabled;
	EndTry;
	
	Connections = GetInfoBaseConnections();
	If Connections.Count() > 1 Then
		
		NumberOfConnections = 0;
		CurrentConnectionNumber = InfoBaseConnectionNumber();
		
		For Each Connection In Connections Do
			If NOT (Connection.SessionNumber = 0 OR Connection.ConnectionNumber = CurrentConnectionNumber) Then
				NumberOfConnections = NumberOfConnections + 1;
			EndIf;
		EndDo;
		
		If NumberOfConnections > 0 Then
			SetExclusiveMode(False);
			ExclusiveModeEnabled = False;
			Return ExclusiveModeEnabled;
		EndIf;
		
	EndIf;
	
	Return ExclusiveModeEnabled;
EndFunction

&AtServer
Procedure FillCountriesAtServer(CountriesArray)
	
	Countries.Clear();
	
	For Each Row In CountriesArray Do
		NewRow = Countries.Add();
		FillPropertyValues(NewRow, Row);
	EndDo;
	
	ArrayOfCountries = Countries.Unload().UnloadColumn("Name");
	Items.Country.ChoiceList.LoadValues(ArrayOfCountries);
	Items.Country.ChoiceList.Add("Default", NStr("en = 'Initialize with default settings'"));
	
	If ArrayOfCountries.Count() = 1 Then
		
		Country = ArrayOfCountries[0];
		
		Rows = Countries.FindRows(New Structure("Name", Country));
		If Rows.Count() = 0 Then
			Return;
		EndIf;
		
		Description = Rows[0].Description;
		Folder		= Rows[0].Folder;

	ElsIf ArrayOfCountries.Count() = 0 Then
		Country = "Default";
	EndIf;
	
EndProcedure

&AtServerNoContext
Function PathToCountryFolder(Country)
	PathToCountryFolder = StrReplace(Lower(Country), " ","_");
	Return PathToCountryFolder;
EndFunction

#EndRegion

#Region FormItems

&AtClient
Procedure SetPathToConfigurationPackageManually()
	
	PathToConfigurationPackage = "";
	Items.GroupPages.CurrentPage = Items.GroupChooseConfigurationPackageManually;
	
EndProcedure

&AtClient
Procedure SetCurrentPage()
	
	If JobName = "ExecuteUpdateExtensions" Then
		Items.GroupPages.CurrentPage = Items.GroupChooseConfigurationPackageManually;
	Else
		Items.GroupPages.CurrentPage = Items.GroupHomePage;
	EndIf;
	
EndProcedure

&AtClient
Procedure RefreshFormData()
	
	Rows = Countries.FindRows(New Structure("Name", Country));
	If Rows.Count() = 0 Then
		Return;
	EndIf;
	
	Description = Rows[0].Description;
	Folder		= Rows[0].Folder;
	
EndProcedure

&AtClient
Procedure ShowErrorMessageToUser(Text)
	
	Items.GroupPages.CurrentPage = Items.GroupFinishPage;
	Items.PagesStatus.CurrentPage = Items.PageError;
	
	Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'An error occured during initial configuration setup.
			     |Contact your partner and provide him following information: %1'"),
			Text);
	
EndProcedure

#EndRegion

#Region LoadFromFile

&AtClient
Procedure LoadFromCustomFile()
	
	Dialog = New FileDialog(FileDialogMode.Open);
	Dialog.Title = NStr("en = 'Choose configuration data file...'");
	Dialog.Filter = "Compressed file (*.zip)|*.zip";
	Dialog.Multiselect = False;
	
	NotifyDescription = New NotifyDescription("AfterFileChoise", ThisObject);
	
	Dialog.Show(NotifyDescription);
	
EndProcedure

&AtClient
Procedure AfterFileChoise(SelectedFiles, AdditionalParameters) Export
	
	If SelectedFiles <> Undefined Then
		PathToConfigurationPackage = SelectedFiles[0];
		
		Items.GroupPages.CurrentPage = Items.GroupLoadingPage;
		If UpdateConfigurationPackage Then
			AttachIdleHandler("Attachable_FillPredefinedData", 0.2, True);
		Else
			AttachIdleHandler("Attachable_FillCountries", 0.2, True);
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#EndRegion