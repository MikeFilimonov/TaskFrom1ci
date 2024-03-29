﻿////////////////////////////////////////////////////////////////////////////////
// Subsystem "Configuration update".
//  
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProgramInterface

// See details of the same procedure in the StandardSubsystemsServer module.
Procedure OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers) Export
	
	// CLIENT HANDLERS.
	
	ClientHandlers[
		"StandardSubsystems.BasicFunctionality\OnStart"].Add(
			"ConfigurationUpdateClient");
	
	ClientHandlers[
		"StandardSubsystems.BasicFunctionality\OnGetListOfWarningsToCompleteJobs"].Add(
			"ConfigurationUpdateClient");
	
	// SERVERSIDE HANDLERS.
	
	ServerHandlers["StandardSubsystems.BasicFunctionality\OnAddParametersJobsClientLogicStandardSubsystemsRunning"].Add(
		"ConfigurationUpdate");
	
	ServerHandlers["StandardSubsystems.BasicFunctionality\OnAddParametersJobsClientLogicStandardSubsystems"].Add(
		"ConfigurationUpdate");
	
EndProcedure

// Fills the structure of the parameters required
// for the client configuration code. 
//
// Parameters:
//   Parameters   - Structure - Parameters structure.
//
Procedure AddClientWorkParameters(Parameters) Export
	
	If Not CommonUseReUse.CanUseSeparatedData()
		OR CommonUseClientServer.IsLinuxClient() Then
		Return;
	EndIf;
	
	Parameters.Insert("UpdateSettings", New FixedStructure(GetUpdateSettings()));

EndProcedure

// Fills the structure of the parameters required
// for functioning of the client code at the configuration start. 
//
// Parameters:
//   Parameters   - Structure - Parameters structure.
//
Procedure AddClientWorkParametersOnStart(Parameters) Export
	
	If CommonUseClientServer.IsLinuxClient() Then
		Return;
	EndIf;
	
	Parameters.Insert("UpdateSettings", New FixedStructure(GetUpdateSettings()));
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// Check whether application is run as external user and delete exception in this case.
//
// Parameters:
//  MessageText  - String - exception text. If it is
// not specified, text is used by default.
//
// Useful example:
//    AbortExecutionIfExternalUserIsAuthorized();
//    ... next is the code fragment that relies only on
// the execution from a "normal" user.
//
Procedure AbortExecuteIfExternalUserAuthorized(Val MessageText = "") Export
	
	SetPrivilegedMode(True);
	
	If UsersClientServer.IsExternalUserSession() Then
		
		ErrorMessage = MessageText;
		
		If IsBlankString(ErrorMessage) Then
			ErrorMessage = NStr("en = 'This operation is not available for external system user.'");
		EndIf;
		
		Raise ErrorMessage;
		
	EndIf;
	
EndProcedure

// Receive update global settings for 1C:Enterprise session.
//
Function GetUpdateSettings() Export
	
	IsAccessForUpdate = CheckAccessForUpdate();
	HasAccessForChecksUpdate = CheckAccessForUpdateCheck();
	
	ConfigurationChanged = ?(IsAccessForUpdate Or HasAccessForChecksUpdate, ConfigurationChanged(), False);
	
	StructureSettings = CommonUse.CommonSettingsStorageImport("ConfigurationUpdate", "ConfigurationUpdateOptions");
	
	Settings = New Structure;
	Settings.Insert("ConfigurationShortName",                  ConfigurationShortName(StructureSettings));
	Settings.Insert("ServerAddressForVerificationOfUpdateAvailability", ServerAddressForVerificationOfUpdateAvailability(StructureSettings));
	Settings.Insert("UpdatesDirectory",                        UpdatesDirectory(StructureSettings));
	Settings.Insert("AddressOfResourceForVerificationOfUpdateAvailability", AddressOfResourceForVerificationOfUpdateAvailability(StructureSettings));
	Settings.Insert("LegalityCheckServiceAddress",          LegalityCheckServiceAddress());
	Settings.Insert("ConfigurationChanged",                     ConfigurationChanged);
	Settings.Insert("CheckPastBaseUpdate",           ConfigurationUpdateSuccessful() <> Undefined);
	Settings.Insert("IsAccessForUpdate",                  IsAccessForUpdate);
	Settings.Insert("HasAccessForChecksUpdate",          HasAccessForChecksUpdate);
	
	Settings.Insert("ConfigurationUpdateOptions", GetSettingsStructureOfAssistant());
	
	Return Settings;
	
EndFunction

// Called during configuration update completion via COM-connection.
//
// Parameters:
//  UpdateResult  - Boolean - Update result.
//
Procedure FinishUpdate(Val UpdateResult, Val Email, Val UpdateAdministratorName) Export

	MessageText = NStr("en = 'Completing update from the external script.'");
	WriteLogEvent(EventLogMonitorEvent(), EventLogLevel.Information,,,MessageText);
	
	If Not CheckAccessForUpdate() Then
		MessageText = NStr("en = 'Insufficient rights to complete the configuration update.'");
		WriteLogEvent(EventLogMonitorEvent(), EventLogLevel.Error,,,MessageText);
		Raise MessageText;
	EndIf;
	
	WriteUpdateStatus(UpdateAdministratorName, False, True, UpdateResult);
	
	If CommonUse.SubsystemExists("StandardSubsystems.EmailOperations")
		AND Not IsBlankString(Email) Then
		Try
			SendNotificationAboutUpdate(UpdateAdministratorName, Email, UpdateResult);
			MessageText = NStr("en = 'Update notification is successfully sent to the email address:'")
				+ " " + Email;
			WriteLogEvent(EventLogMonitorEvent(), EventLogLevel.Information,,,MessageText);
		Except
			MessageText = NStr("en = 'An error occurred when sending the email:'")
				+ " " + Email + Chars.LF + DetailErrorDescription(ErrorInfo());
			WriteLogEvent(EventLogMonitorEvent(), EventLogLevel.Error,,,MessageText);
		EndTry;
	EndIf;
	
	If UpdateResult Then
		
		AfterUpdatingCompletion();
		
	EndIf;
	
EndProcedure

// Receive short name (identifier) of configuration.
//
// Returns:
//   String   - short configuration name.
Function ConfigurationShortName(StructureSettings)
	
	Value = ConfigurationUpdateOverridable.ConfigurationShortName();
	If Not ValueIsFilled(Value) Then
		Value = "Drive";
	EndIf;
	ConfigurationUpdateOverridable.WhenDeterminingConfigurationShortName(Value);
	
	Value = Value + "/";
	
	// Determine configuration edition.
	VersionSubstrings = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(Metadata.Version, ".");
	If VersionSubstrings.Count() > 1 Then
		Value = Value + VersionSubstrings[0] + VersionSubstrings[1] + "/";
	EndIf;
	// Determine platform version.
	System_Info = New SystemInfo;
	VersionSubstrings = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(System_Info.AppVersion, ".");
	Value = Value + VersionSubstrings[0] + VersionSubstrings[1] + "/";
	
	If StructureSettings <> Undefined Then // Value from user settings.
		UseSettingValue = False;
		StructureSettings.Property("UseSettingValueConfigurationShortName", UseSettingValue);
		If UseSettingValue = True Then
			Value = StructureSettings.ConfigurationShortName;
		EndIf;
	EndIf;
	
	Return Value;
	
EndFunction

// Receive address of configuration vendor web
// server where information about available updates is located.
// 
// Returns:
//   String   - web server address.
// 
// Example of implementation:
// 
// Return "localhost"; // local web server for testing.
//
Function ServerAddressForVerificationOfUpdateAvailability(StructureSettings)
	
	Value = ConfigurationUpdateOverridable.ServerAddressForVerificationOfUpdateAvailability();
	If Not ValueIsFilled(Value) Then
		Value = "https://1c-dn.com"; // Value by default
	EndIf;
	ConfigurationUpdateOverridable.WhenDeterminingServerAddressForUpdatesCheck(Value);
	
	If StructureSettings <> Undefined Then // Value from user settings.
		UseSettingValue = False;
		StructureSettings.Property("UseCheckForUpdatesServerSettingValue", UseSettingValue);
		If UseSettingValue = True Then
			Value = StructureSettings.ServerAddressForVerificationOfUpdateAvailability;
		EndIf;
	EndIf;
	
	Return Value;
	
EndFunction

Function UpdatesDirectory(StructureSettings)
	
	Value = ConfigurationUpdateOverridable.UpdatesDirectory();
	If Not ValueIsFilled(Value) Then
		// Value by default
		Value = ConfigurationUpdateClientServer.AddFinalPathSeparator(Metadata.UpdateCatalogAddress);
	EndIf;
	
	ConfigurationUpdateOverridable.WhenDeterminingUpdatesDirectoryAddress(Value);
	
	If StructureSettings <> Undefined Then // Value from user settings.
		UseSettingValue = False;
		StructureSettings.Property("UseSettingValueUpdateDirectory", UseSettingValue);
		If UseSettingValue = True Then
			Value = StructureSettings.UpdatesDirectory;
		EndIf;
	EndIf;
	
	Return Value;
	
EndFunction

Function AddressOfResourceForVerificationOfUpdateAvailability(StructureSettings)
	
	Value = ConfigurationUpdateOverridable.AddressOfResourceForVerificationOfUpdateAvailability();
	If Not ValueIsFilled(Value) Then
		Value = "/update/"; // Value by default
	EndIf;
	ConfigurationUpdateOverridable.WhenDeterminingResourceAddressForUpdatesCheck(Value);
	
	If StructureSettings <> Undefined Then // Value from user settings.
		UseSettingValue = False;
		StructureSettings.Property("UseCheckForUpdatesPathSettingValue", UseSettingValue);
		If UseSettingValue = True Then
			Value = StructureSettings.AddressOfResourceForVerificationOfUpdateAvailability;
		EndIf;
	EndIf;
	
	Return Value;
	
EndFunction

Function LegalityCheckServiceAddress()
	
	Value = "";  // Value by default
	
	StructureSettings = CommonUse.CommonSettingsStorageImport(
		"ConfigurationUpdate",
		"ConfigurationUpdateOptions");
	
	If StructureSettings <> Undefined Then // Value from user settings.
		UseSettingValue = False;
		StructureSettings.Property("UseSettingValueLegalityCheckServiceAddress", UseSettingValue);
		If UseSettingValue = True Then
			Value = StructureSettings.LegalityCheckServiceAddress;
		EndIf;	
	EndIf;	
	
	Return Value;
	
EndFunction

// Returns check box of successful configuration update based on the settings constant data.
Function ConfigurationUpdateSuccessful() Export

	If Not AccessRight("Read", Metadata.Constants.ConfigurationUpdateStatus) Then
		Return Undefined;
	EndIf;
	
	ValueStore = Constants.ConfigurationUpdateStatus.Get();
	
	Status = Undefined;
	If ValueStore <> Undefined Then
		Status = ValueStore.Get();
	EndIf;

	If Status = Undefined Then
		Return Undefined;
	EndIf;
	
	If Not Status.UpdateExecuted OR 
		(Status.UpdateAdministratorName <> UserName()) Then
		Return Undefined;
	EndIf;
	
	Return Status.ConfigurationUpdateResult;

EndFunction

// Sets new value to update
// settings constant according to success of the last configuration update attempt.
Procedure WriteUpdateStatus(Val UpdateAdministratorName, Val RefreshEnabledPlanned,
	Val RefreshCompleted, Val UpdateResult, MessagesForEventLogMonitor = Undefined) Export

	EventLogMonitor.WriteEventsToEventLogMonitor(MessagesForEventLogMonitor);
	
	Status = New Structure("UpdateAdministratorName,
		 |UpdatePlanned,
		 |UpdateExecuted,
		 |ConfigurationUpdateResult",
		 UpdateAdministratorName,
		 RefreshEnabledPlanned,
		 RefreshCompleted,
		 UpdateResult);
							 
	Constants.ConfigurationUpdateStatus.Set(New ValueStorage(Status));

EndProcedure

// Clears all settings of the configuration update.
Procedure ResetStatusOfConfigurationUpdate() Export
	
	Constants.ConfigurationUpdateStatus.Set(New ValueStorage(Undefined));
	
EndProcedure

// Receives configuration update settings from general settings storage.
Function GetSettingsStructureOfAssistant() Export
	
	Schedule = Undefined;
	Settings = CommonUse.CommonSettingsStorageImport("ConfigurationUpdate", "ConfigurationUpdateOptions");
	
	If Settings = Undefined Then
		OldSettingsCount = 0;
	ElsIf TypeOf(Settings) = Type("Structure") OR TypeOf(Settings) = Type("Map") Then
		OldSettingsCount = Settings.Count();
	Else
		OldSettingsCount = 0;
	EndIf;
	Settings = ConfigurationUpdateClientServer.GetUpdatedConfigurationUpdateSettings(Settings);
	// If new settings appeared, they should be saved.
	If Settings.Count() > OldSettingsCount Then
		SetPrivilegedMode(True);
		WriteStructureOfAssistantSettings(Settings);	
		SetPrivilegedMode(False);
	EndIf;
	// If schedule is saved in the early versions and the
	// UpdateUpdatePresenceCheckSchedule update handler has not worked, then...
	If Settings <> Undefined AND Settings.Property("ScheduleOfUpdateExistsCheck", Schedule) 
		AND TypeOf(Schedule) = Type("JobSchedule") Then
		Settings.ScheduleOfUpdateExistsCheck = CommonUseClientServer.ScheduleIntoStructure(Schedule);
	EndIf;
	Return Settings;
	
EndFunction

// Writes the settings of update assistant to common settings storage.
Procedure WriteStructureOfAssistantSettings(ConfigurationUpdateOptions, MessagesForEventLogMonitor = Undefined) Export
	
	EventLogMonitor.WriteEventsToEventLogMonitor(MessagesForEventLogMonitor);
	
	CommonUse.CommonSettingsStorageSave(
		"ConfigurationUpdate", 
		"ConfigurationUpdateOptions", 
		ConfigurationUpdateOptions);
		
	AuthenticationParameters = New Structure("Login,Password");
	ConfigurationUpdateOptions.Property("UpdateServerUserCode", AuthenticationParameters.Login);
	ConfigurationUpdateOptions.Property("UpdatesServerPassword", AuthenticationParameters.Password);
	StandardSubsystemsServer.SaveAuthenticationParametersOnSite(AuthenticationParameters);
	
EndProcedure

// Check whether there is an access to the InstallUpdates subsystem.
Function CheckAccessForUpdate()
	Return Users.InfobaseUserWithFullAccess(, True);
EndFunction

// Returns check box of update by the current user availability.
Function CheckAccessForUpdateCheck() Export
	
	Return Users.RolesAvailable("CheckForAvailableConfigurationUpdates")
	      AND TypeOf(Users.AuthorizedUser()) = Type("CatalogRef.Users");
	
EndFunction

Procedure SendNotificationAboutUpdate(Val UserName, Val AddressOfDestination, Val SuccessfulRefresh)
	
	Subject = ? (SuccessfulRefresh, NStr("en = 'Configuration ""%1"" is successfully updated, version %2'"), 
		NStr("en = 'Configuration ""%1"" update error, version %2'"));
	Subject = StringFunctionsClientServer.SubstituteParametersInString(Subject, Metadata.BriefInformation, Metadata.Version);
	
	Details = ?(SuccessfulRefresh, NStr("en = 'Configuration is successfully updated.'"), 
		NStr("en = 'Configuration update failed. Details have been written to the event log.'"));
	Text = StringFunctionsClientServer.SubstituteParametersInString(NStr("en = '%1
	                                                                     |
	                                                                     |Configuration:
	                                                                     |%2 Version:
	                                                                     |%3 Connection string: %4'"),
	Details, Metadata.BriefInformation, Metadata.Version, InfobaseConnectionString());
	
	EmailParameters = New Structure;
	EmailParameters.Insert("Subject", Subject);
	EmailParameters.Insert("Body", Text);
	EmailParameters.Insert("Whom", AddressOfDestination);
	
	ModuleEmailOperations = CommonUse.CommonModule("EmailOperations");
	ModuleEmailOperations.SendE_Mail(
		ModuleEmailOperations.SystemAccount(), EmailParameters);
	
EndProcedure

// Returns event name for events log monitor record.
Function EventLogMonitorEvent() Export
	Return NStr("en = 'Update configuration'", CommonUseClientServer.MainLanguageCode());
EndFunction

#Region HandlersOfSSLSubsystemsInternalEvents

// Fills the structure of the parameters required
// for the client configuration code. 
//
// Parameters:
//   Parameters   - Structure - Parameters structure.
//
Procedure OnAddParametersJobsClientLogicStandardSubsystemsRunning(Parameters) Export
	
	AddClientWorkParameters(Parameters);
	
EndProcedure

// Fills the structure of the parameters required
// for the client configuration code.
//
// Parameters:
//   Parameters   - Structure - Parameters structure.
//
Procedure OnAddParametersJobsClientLogicStandardSubsystems(Parameters) Export
	
	AddClientWorkParameters(Parameters);
	
EndProcedure

#EndRegion

#Region HandlersOfConditionalCallsFromOtherSubsystems

// Called not via event as call is required to be executed last.
//
Procedure AfterInformationBaseUpdate() Export
	
	If CommonUseReUse.DataSeparationEnabled() Then
		Return;
	EndIf;
	
	ValueStore = Constants.ConfigurationUpdateStatus.Get();
	
	Status = Undefined;
	If ValueStore <> Undefined Then
		Status = ValueStore.Get();
	EndIf;
	
	If Status <> Undefined AND Status.UpdateExecuted AND Status.ConfigurationUpdateResult <> Undefined
		AND Not Status.UpdateResultConfiguration Then
		
		Status.ConfigurationUpdateResult = True;
		Constants.ConfigurationUpdateStatus.Set(New ValueStorage(Status));
		
	EndIf;
	
EndProcedure

#EndRegion

#Region HandlersOfTheConditionalCallsIntoOtherSubsystems

// Called during execution of the update script from the InstallUpdates procedure.FinishUpdate().
Procedure AfterUpdatingCompletion() Export
	
	InfobaseUpdateService.AfterUpdatingCompletion();
	
EndProcedure

#EndRegion

#EndRegion
