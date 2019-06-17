////////////////////////////////////////////////////////////////////////////////
// Subsystem "IB backup".
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProgramInterface

// See details of the same procedure in the StandardSubsystemsServer module.
Procedure OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers) Export
	
	// CLIENT HANDLERS.
	
	ClientHandlers[
		"StandardSubsystems.BasicFunctionality\BeforeExit"].Add(
			"InfobaseBackupClient");
	
	ClientHandlers[
		"StandardSubsystems.BasicFunctionality\OnStart"].Add(
			"InfobaseBackupClient");
	
	ClientHandlers[
		"StandardSubsystems.BasicFunctionality\WhenVerifyingBackupPossibilityInUserMode"].Add(
			"InfobaseBackupClient");
	
	ClientHandlers[
		"StandardSubsystems.BasicFunctionality\WhenUserIsOfferedToBackup"].Add(
			"InfobaseBackupClient");
	
	// SERVERSIDE HANDLERS.
		
	ServerHandlers[
		"StandardSubsystems.BasicFunctionality\OnAddParametersJobsClientLogicStandardSubsystemsRunning"].Add(
		"InfobaseBackupServer");
	
	ServerHandlers[
		"StandardSubsystems.BasicFunctionality\OnAddParametersJobsClientLogicStandardSubsystems"].Add(
		"InfobaseBackupServer");
		
	ServerHandlers["StandardSubsystems.BasicFunctionality\OnSwitchUsingSecurityProfiles"].Add(
		"InfobaseBackupServer");
	
	If CommonUse.SubsystemExists("StandardSubsystems.ToDoList") Then
		ServerHandlers["StandardSubsystems.ToDoList\AtFillingToDoList"].Add(
			"InfobaseBackupServer");
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// Returns the parameters of IBBackup subsystem required
// on user operation end.
//
// Returns:
// Structure - Parameters.
//
Function ParametersOnWorkCompletion()
	
	BackupSettings = BackupSettings();
	ExecuteOnWorkCompletion = ?(BackupSettings = Undefined, False,
		BackupSettings.ExecuteAutomaticBackup
		AND BackupSettings.ExecutionVariant = "OnWorkCompletion");
	
	ParametersOnComplete = New Structure;
	ParametersOnComplete.Insert("NotificationRolesAvailability",   HasRightsToAlertAboutBackupConfiguration());
	ParametersOnComplete.Insert("ExecuteOnWorkCompletion", ExecuteOnWorkCompletion);
	
	Return ParametersOnComplete;
	
EndFunction

// Returns saved backup parameters.
//
// Returns - Structure - backup parameters.
//
Function BackupParameters() Export
	
	Parameters = CommonUse.CommonSettingsStorageImport("BackupParameters");
	If Parameters = Undefined Then
		Parameters = InitialBackupSettingsFilling();
	Else
		BringBackupParameters(Parameters);
	EndIf;
	Return Parameters;
	
EndFunction

// Displays backup parameters.
// If in current backup parameters there is no parameter which exists in function "BackupSettingsInitialFilling" then it
// is added with default value.
//
// Parameters:
// BackupParameters - Structure - parameters of IB backup.
//
Procedure BringBackupParameters(BackupParameters)
	
	ParametersChanged = False;
	
	Parameters = InitialBackupSettingsFilling(False);
	For Each StructureItem In Parameters Do
		FoundValue = Undefined;
		If BackupParameters.Property(StructureItem.Key, FoundValue) Then
			If FoundValue = Undefined AND StructureItem.Value <> Undefined Then
				BackupParameters.Insert(StructureItem.Key, StructureItem.Value);
				ParametersChanged = True;
			EndIf;
		Else
			If StructureItem.Value <> Undefined Then
				BackupParameters.Insert(StructureItem.Key, StructureItem.Value);
				ParametersChanged = True;
			EndIf;
		EndIf;
	EndDo;
	
	If Not ParametersChanged Then 
		Return;
	EndIf;
	
	SetBackupParameters(BackupParameters);
	
EndProcedure

// Saves backup parameters.
//
// Parameters:
// ParametersStructure - Structure - backup parameters.
//
Procedure SetBackupParameters(ParametersStructure, CurrentUser = Undefined) Export
	CommonUse.CommonSettingsStorageSave("BackupParameters", , ParametersStructure);
	If CurrentUser <> Undefined Then
		ParametersOfCopying = New Structure("User", CurrentUser);
		Constants.BackupParameters.Set(New ValueStorage(ParametersOfCopying));
	EndIf;
EndProcedure

// Checks if it is time for automatic backup.
//
// Returns:
//   Boolean - True if it is time to back up.
//
Function NecessityOfAutomaticBackup() Export
	
	If Not CommonUse.FileInfobase() Then
		Return False;
	EndIf;
	
	Parameters = BackupParameters();
	If Parameters = Undefined Then
		Return False;
	EndIf;
	Schedule = Parameters.CopyingSchedule;
	If Schedule = Undefined Then
		Return False;
	EndIf;
	
	If Parameters.Property("ProcessIsRunning") Then 
		If Parameters.ProcessIsRunning Then 
			Return False;
		EndIf;
	EndIf;
	
	CheckDate = CurrentSessionDate();
	If Parameters.MinimumDateOfNextAutomaticBackup > CheckDate Then
		Return False;
	EndIf;
	
	CheckStartDate = Parameters.DateOfLastBackup;
	ScheduleValue = CommonUseClientServer.StructureIntoSchedule(Schedule);
	Return ScheduleValue.ExecutionRequired(CheckDate, CheckStartDate);
	
EndFunction

// Generates the dates of nearest automatic backup according to the schedule.
//
// Parameters:
// InitialSetting - Boolean - flag of initial setup.
//
Function GenerateDatesOfNextAutomaticCopy(InitialSetting = False) Export
	
	Result = New Structure;
	BackupSettings = BackupSettings();
	
	CurrentDate = CurrentSessionDate();
	If InitialSetting Then
		Result.Insert("MinimumDateOfNextAutomaticBackup", CurrentDate);
		Result.Insert("DateOfLastBackup", CurrentDate);
	Else
		CopyingSchedule = BackupSettings.CopyingSchedule;
		RepeatPeriodInDay = CopyingSchedule.RepeatPeriodInDay;
		DaysRepeatPeriod = CopyingSchedule.DaysRepeatPeriod;
		
		If RepeatPeriodInDay <> 0 Then
			Value = CurrentDate + RepeatPeriodInDay;
		ElsIf DaysRepeatPeriod <> 0 Then
			Value = CurrentDate + DaysRepeatPeriod * 3600 * 24;
		Else
			Value = BegOfDay(EndOfDay(CurrentDate) + 1);
		EndIf;
		Result.Insert("MinimumDateOfNextAutomaticBackup", Value);
	EndIf;
	
	FillPropertyValues(BackupSettings, Result);
	SetBackupParameters(BackupSettings);
	
	Return Result;
	
EndFunction

// Returns the value of setting "Backup status" in result part.
// Used at system start to show the forms with backup results.
//
Procedure SetBackupResult() Export
	
	ParametersStructure = BackupSettings();
	ParametersStructure.CopyingHasBeenPerformed = False;
	SetBackupParameters(ParametersStructure);
	
EndProcedure

// Sets the value of setting "LastBackupDate".
//
// Parameters: 
//   CopyingDate - date and time of last backup.
//
Procedure SetLastCopyingDate(CopyingDate) Export
	
	ParametersStructure = BackupParameters();
	ParametersStructure.DateOfLastBackup = CopyingDate;
	SetBackupParameters(ParametersStructure);
	
EndProcedure

// Sets the date of last notification of user.
//
// Parameters: 
// DateReminders - Date - date and time of last user notification about
//                          the need to back up.
//
Procedure SetLastReminderDate(DateReminders) Export
	
	NotificationParameters = BackupParameters();
	NotificationParameters.LastNotificationDate = DateReminders;
	SetBackupParameters(NotificationParameters);
	
EndProcedure

// Sets the setting to backup parameters. 
// 
// Parameters: 
// ItemName - String - parameter name.
// 	ItemValue - Arbitrary type - value of the parameter.
//
Procedure SetSettingValue(ItemName, ItemValue) Export
	
	SettingsStructure = BackupParameters();
	SettingsStructure.Insert(ItemName, ItemValue);
	SetBackupParameters(SettingsStructure);
	
EndProcedure

// Returns the structure with backup parameters.
// 
// Parameters: 
// OperationStart - Boolean - flag of call at application start.
//
// Returns:
//  Structure - backup parameters.
//
Function BackupSettings(OperationStart = False) Export
	
	If Not CommonUseReUse.CanUseSeparatedData() Then
		Return Undefined; // Cannot log on to the data area.
	EndIf;
	
	If Not HasRightsToAlertAboutBackupConfiguration() Then
		Return Undefined; // Current user does not have necessary rights.
	EndIf;
	
	Result = BackupParameters();
	
	VariantNotifications = VariantNotifications();
	
	Result.Insert("NotificationParameter", VariantNotifications);
	If Result.CopyingHasBeenPerformed AND Result.CopyingResult  Then
		CurrentSessionDate = CurrentSessionDate();
		Result.DateOfLastBackup = CurrentSessionDate;
		// Saving the date of last backup in common settings storage.
		SetLastCopyingDate(CurrentSessionDate);
	EndIf;
	
	If Result.RecoverHasBeenPerformed Then
		UpdateRecoverResult();
	EndIf;
	
	If OperationStart AND Result.ProcessIsRunning Then
		Result.ProcessIsRunning = False;
		SetSettingValue("ProcessIsRunning", False);
	EndIf;
	
	Return Result;
	
EndFunction

// Updates the result of restoration and the structure of backup parameters. 
//
Procedure UpdateRecoverResult()
	
	ReturnStructure = BackupParameters();
	ReturnStructure.RecoverHasBeenPerformed = False;
	SetBackupParameters(ReturnStructure);
	
EndProcedure

// Selects notification option to show to user.
// Called from the form of backup assistant to determine start form.
//
// Returns: 
//   String:
//     "Configured" - automatic backup is configured.
//     "Overdue" - automatic backup is overdue.
//     "NotConfiguredYet" - Backup is not configured yet.
//     "DoNotNotify" - do not notify of necessity to back up (for
//                     example if executed by third-party tools).
//
Function VariantNotifications()
	
	Result = "DoNotNotify";
	If Not HasRightsToAlertAboutBackupConfiguration() Then
		Return Result;
	EndIf;
	
	NotificationParameterAboutCopying = BackupParameters();
	NotifyAboutBackupNecessity = CurrentSessionDate() >= (NotificationParameterAboutCopying.LastNotificationDate + 3600 * 24);
	
	If NotificationParameterAboutCopying.ExecuteAutomaticBackup Then
		
		If NecessityOfAutomaticBackup() Then
			Result = "Overdue";
		Else
			Result = "Configured";
		EndIf;
		
	ElsIf Not NotificationParameterAboutCopying.BackupIsConfigured Then
		
		If NotifyAboutBackupNecessity Then
			
			BackupSettings = Constants.BackupParameters.Get().Get();
			If BackupSettings <> Undefined
				AND BackupSettings.User <> UsersClientServer.CurrentUser() Then
				Result = "DoNotNotify";
			Else
				Result = "YetNotConfigured";
			EndIf;
			
		EndIf;
		
	EndIf;
	
	Return Result;
	
EndFunction

// Returns initial filling of automatic backup settings.
//
// Parameters:
// SaveParameters - save parameters in settings storage or not.
//
// Returns - Structure - initial filling of backup parameters.
//
Function InitialBackupSettingsFilling(SaveParameters = True) Export
	
	Parameters = New Structure;
	
	Parameters.Insert("ExecuteAutomaticBackup", False);
	Parameters.Insert("BackupIsConfigured", False);
	
	Parameters.Insert("LastNotificationDate", '00010101');
	Parameters.Insert("DateOfLastBackup", '00010101');
	Parameters.Insert("MinimumDateOfNextAutomaticBackup", '29990101');
	
	Parameters.Insert("CopyingSchedule", CommonUseClientServer.ScheduleIntoStructure(New JobSchedule));
	Parameters.Insert("DirectoryStorageOfBackupCopies", "");
	Parameters.Insert("BackupStorageDirectoryOnManualLaunch", ""); // On manual execution
	Parameters.Insert("CopyingHasBeenPerformed", False);
	Parameters.Insert("RecoverHasBeenPerformed", False);
	Parameters.Insert("CopyingResult", Undefined);
	Parameters.Insert("BackupFileName", "");
	Parameters.Insert("ExecutionVariant", "OnSchedule");
	Parameters.Insert("ProcessIsRunning", False);
	Parameters.Insert("InfobaseAdministrator", "");
	Parameters.Insert("IBAdministratorPassword", "");
	Parameters.Insert("DeletionParameters", DefaultParametersForBackupDeletion());
	Parameters.Insert("LastBackupManualLaunch", True);
	
	If SaveParameters Then
		SetBackupParameters(Parameters);
	EndIf;
	
	Return Parameters;
	
EndFunction

// Returns the flag showing that the user has full rights.
//
// Returns - Boolean - True if this is a full user.
//
Function HasRightsToAlertAboutBackupConfiguration() Export
	Return Users.InfobaseUserWithFullAccess(,True);
EndFunction

// Procedure called from script through com connection.
// Writes backup result to the settings.
// 
// Parameters:
// Result - Boolean - result of copying.
// BackupFileName - String - backup attachment file name.
//
Procedure CompleteBackup(Result, BackupFileName =  "") Export
	
	ResultStructure = BackupSettings();
	ResultStructure.CopyingHasBeenPerformed = True;
	ResultStructure.CopyingResult = Result;
	ResultStructure.BackupFileName = BackupFileName;
	SetBackupParameters(ResultStructure);
	
EndProcedure

// Called from the script
// through com connection to record the result of IB restoration into the settings.
//
// Parameters:
// Result - Boolean - result of restoration.
//
Procedure CompleteRecovering(Result) Export
	
	ResultStructure = BackupSettings();
	ResultStructure.RecoverHasBeenPerformed = True;
	SetBackupParameters(ResultStructure);
	
EndProcedure

// Returns current backup setting in a string.
// Two options of function use - or with passing of all parameters or without parameters.
//
Function CurrentBackupSetting() Export
	
	BackupSettings = BackupSettings();
	If BackupSettings = Undefined Then
		Return NStr("en = 'To configure backup, contact administrator.'");
	EndIf;
	
	CurrentSetting = NStr("en = 'Backup is not configured. It can expose infobase to risks of data loss.'");
	
	If CommonUse.FileInfobase() Then
		
		If BackupSettings.ExecuteAutomaticBackup Then
			
			If BackupSettings.ExecutionVariant = "OnWorkCompletion" Then
				CurrentSetting = NStr("en = 'Backup is made regularly on closing the application.'");
			ElsIf BackupSettings.ExecutionVariant = "OnSchedule" Then // On schedule
				Schedule = CommonUseClientServer.StructureIntoSchedule(BackupSettings.CopyingSchedule);
				If Not IsBlankString(Schedule) Then
					CurrentSetting = NStr("en = 'Regular backup on schedule: %1'");
					CurrentSetting = StringFunctionsClientServer.SubstituteParametersInString(CurrentSetting, Schedule);
				EndIf;
			EndIf;
			
		Else
			
			If BackupSettings.BackupIsConfigured Then
				CurrentSetting = NStr("en = 'Backup is not running (organized by external applications).'");
			EndIf;
			
		EndIf;
		
	Else
		
		CurrentSetting = NStr("en = 'Backup is not running (organized by DBMS resources).'");
		
	EndIf;
	
	Return CurrentSetting;
	
EndFunction

Function DefaultParametersForBackupDeletion()
	
	DeletionParameters = New Structure;
	
	DeletionParameters.Insert("RestrictionType", "ByPeriod");
	
	DeletionParameters.Insert("CopiesCount", 10);
	
	DeletionParameters.Insert("PeriodMeasurementUnit", "Month");
	DeletionParameters.Insert("ValueInMeasurementUnits", 6);
	
	Return DeletionParameters;
	
EndFunction
#Region EventHandlersOfTheSSLSubsystems

// Fills the structure of the parameters required
// for the client configuration code. 
//
// Parameters:
//   Parameters   - Structure - Parameters structure.
//
Procedure OnAddParametersJobsClientLogicStandardSubsystemsRunning(Parameters) Export
	
	Parameters.Insert("BackupInfobase", BackupSettings(True));
	Parameters.Insert("InfobaseBackupOnComplete", ParametersOnWorkCompletion());
	
EndProcedure

// Fills the structure of the parameters required
// for the client configuration code.
//
// Parameters:
//   Parameters   - Structure - Parameters structure.
//
Procedure OnAddParametersJobsClientLogicStandardSubsystems(Parameters) Export
	
	Parameters.Insert("BackupInfobase", BackupSettings());
	
EndProcedure

// Appears when you enable the use of the infobase for security profiles.
//
Procedure OnSwitchUsingSecurityProfiles() Export
	
	BackupParameters = BackupSettings();
	
	If BackupParameters = Undefined Then
		Return;
	EndIf;
	
	If BackupParameters.Property("IBAdministratorPassword") Then
		
		BackupParameters.IBAdministratorPassword = "";
		SetBackupParameters(BackupParameters);
		
	EndIf;
	
EndProcedure

// Fills the user current work list.
//
// Parameters:
//  ToDoList - ValueTable - a table of values with the following columns:
//    * Identifier - String - an internal work identifier used by the Current Work mechanism.
//    * ThereIsWork      - Boolean - if True, the work is displayed in the user current work list.
//    * Important        - Boolean - If True, the work is marked in red.
//    * Presentation - String - a work presentation displayed to the user.
//    * Count    - Number  - a quantitative indicator of work, it is displayed in the work header string.
//    * Form         - String - the complete path to the form which you need
//                               to open at clicking the work hyperlink on the Current Work bar.
//    * FormParameters- Structure - the parameters to be used to open the indicator form.
//    * Owner      - String, metadata object - a string identifier of the work, which
//                      will be the owner for the current work or a subsystem metadata object.
//    * ToolTip     - String - The tooltip wording.
//
Procedure AtFillingToDoList(ToDoList) Export
	
	ThisIsWebClient = CommonUseClientServer.ThisIsWebClient();
	If Not CommonUse.FileInfobase() // Executed by third-party tools in client-server.
		Or ThisIsWebClient Then // Not supported in web client.
		Return;
	EndIf;
	
	ModuleToDoListService = CommonUse.CommonModule("ToDoListService");
	NotificationOnBackupConfigurationDisabled = ModuleToDoListService.WorkDisabled("SetupBackup");
	BackupNotificationDisabled = ModuleToDoListService.WorkDisabled("ExecuteBackingUpNow");
	
	If Not AccessRight("view", Metadata.DataProcessors.BackupInfobase)
		Or (NotificationOnBackupConfigurationDisabled
			AND BackupNotificationDisabled) Then
		Return;
	EndIf;
	ModuleToDoListServer = CommonUse.CommonModule("ToDoListServer");
	
	BackupSettings = BackupSettings();
	VariantNotifications = BackupSettings.NotificationParameter;
	
	// The procedure is called only if there is the
	// To-do lists subsystem, that is why here is no checking of subsystem existence.
	Sections = ModuleToDoListServer.SectionsForObject(Metadata.DataProcessors.BackupInfobase.FullName());
	
	If Sections = Undefined Then
		Return;
	EndIf;
	
	RequiredToBackUp = NecessityOfAutomaticBackup();
	For Each Section In Sections Do
		
		If Not NotificationOnBackupConfigurationDisabled Then
			Work = ToDoList.Add();
			Work.ID  = "SetupBackup" + StrReplace(Section.FullName(), ".", "");
			Work.ThereIsWork       = VariantNotifications = "YetNotConfigured";
			Work.Presentation  = NStr("en = 'Configure backup'");
			Work.Important         = True;
			Work.Form          = "DataProcessor.BackupSetup.Form.Form";
			Work.Owner       = Section;
		EndIf;
		
		If Not BackupNotificationDisabled Then
			Work = ToDoList.Add();
			Work.ID  = "ExecuteBackingUpNow" + StrReplace(Section.FullName(), ".", "");
			Work.ThereIsWork       = VariantNotifications = "Overdue";
			Work.Presentation  = NStr("en = 'Backup not completed'");
			Work.Important         = True;
			Work.Form          = "DataProcessor.BackupInfobase.Form.DataBackup";
			Work.Owner       = Section;
		EndIf;
		
	EndDo;
	
EndProcedure

#EndRegion

#EndRegion
