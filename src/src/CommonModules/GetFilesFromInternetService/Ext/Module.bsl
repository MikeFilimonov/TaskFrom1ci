////////////////////////////////////////////////////////////////////////////////
// Subsystem "Receiving files from the Internet".
// 
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProgramInterface

#Region AddHandlersOfTheServiceEventssubsriptions

// See details of the same procedure in the StandardSubsystemsServer module.
Procedure OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers) Export
	
	// SERVERSIDE HANDLERS.
	
	ServerHandlers["StandardSubsystems.BasicFunctionality\OnAddParametersJobsClientLogicStandardSubsystems"].Add(
		"GetFilesFromInternetService");
	
	ServerHandlers["StandardSubsystems.BasicFunctionality\OnSwitchUsingSecurityProfiles"].Add(
		"GetFilesFromInternetService");
		
EndProcedure

#EndRegion

#Region HandlersOfServiceEvents

// Fills the structure of the parameters required
// for the client configuration code.
//
// Parameters:
//   Parameters   - Structure - Parameters structure.
//
Procedure OnAddParametersJobsClientLogicStandardSubsystems(Parameters) Export
	
	Parameters.Insert("ProxyServerSettings", GetFilesFromInternet.GetProxyServerSetting());
	
EndProcedure

// Appears when you enable the use of the infobase for security profiles.
//
Procedure OnSwitchUsingSecurityProfiles() Export
	
	// Reset proxy server settings on the system.
	SaveProxySettingsAt1CEnterpriseServer(Undefined);
	
	WriteLogEvent(GetFilesFromInternetClientServer.EventLogMonitorEvent(),
		EventLogLevel.Warning, Metadata.Constants.ProxyServerSetting,,
		NStr("en = 'When enabling security profiles, proxy server settings were reset to default values.'"));
	
EndProcedure

#EndRegion

#EndRegion

#Region ServiceProceduresAndFunctions

// Saves the proxy server settings on the side of 1C:Enterprise server.
//
Procedure SaveProxySettingsAt1CEnterpriseServer(Val Settings) Export
	
	If Not Users.InfobaseUserWithFullAccess(, True) Then
		Raise(NStr("en = 'Insufficient rights to perform the operation'"));
	EndIf;
	
	SetPrivilegedMode(True);
	Constants.ProxyServerSetting.Set(New ValueStorage(Settings));
	
EndProcedure

#EndRegion
