////////////////////////////////////////////////////////////////////////////////
// The subsystem "Basic functionality".
//  
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// It returns the structure of
// the parameters necessary for the configuration work on the client at starting, i.e. in the event handlers.
// - BeforeSystemWorkStart,
// - OnStart
// 
// Important: when starting you can not use
// cache reset command for reused modules otherwise
// the start can lead to unpredictable errors and excess server calls.
// 
// Returns:
//   FixedStructure - structure of the client work parameters on start.
//
Function ClientWorkParametersOnStart() Export
	
	ParameterName = "StandardSubsystems.ParametersAtApplicationStartAndExit";
	If ApplicationParameters[ParameterName] = Undefined Then
		ApplicationParameters.Insert(ParameterName, New Structure);
	EndIf;
	ParametersAtApplicationStartAndExit = ApplicationParameters["StandardSubsystems.ParametersAtApplicationStartAndExit"];
	
	Parameters = New Structure;
	Parameters.Insert("ReceivedClientParameters", Undefined);
	
	If ParametersAtApplicationStartAndExit.Property("ReceivedClientParameters")
	   AND TypeOf(ParametersAtApplicationStartAndExit.ReceivedClientParameters) = Type("Structure") Then
		
		Parameters.Insert("ReceivedClientParameters",
			ParametersAtApplicationStartAndExit.ReceivedClientParameters);
	EndIf;
	
	If ParametersAtApplicationStartAndExit.Property("SkipClearingDesktopHide") Then
		Parameters.Insert("SkipClearingDesktopHide");
	EndIf;
	
	#If WebClient Then
		ThisIsWebClient = True;
	#Else
		ThisIsWebClient = False;
	#EndIf
	
	SystemInfo = New SystemInfo;
	IsLinuxClient = SystemInfo.PlatformType = PlatformType.Linux_x86
	              OR SystemInfo.PlatformType = PlatformType.Linux_x86_64;

	Parameters.Insert("LaunchParameter",			LaunchParameter);
	Parameters.Insert("InfobaseConnectionString",	InfobaseConnectionString());
	Parameters.Insert("ThisIsWebClient",			ThisIsWebClient);
	Parameters.Insert("ThisIsMacOSWebClient",		CommonUseClientReUse.ThisIsMacOSWebClient());
	Parameters.Insert("IsLinuxClient",				IsLinuxClient);
	Parameters.Insert("HideDesktopOnStart",			False);
	
	ClientParameters = StandardSubsystemsServerCall.ClientWorkParametersOnStart(Parameters);
	
	ParameterName = "StandardSubsystems.ClientParameters";
	If TypeOf(ApplicationParameters[ParameterName]) <> Type("Structure") Then
		
		ApplicationParameters[ParameterName] = New Structure;
		ApplicationParameters[ParameterName].Insert("AskConfirmationOnClose");
		ApplicationParameters[ParameterName].Insert("AuthorizedUser");
		ApplicationParameters[ParameterName].Insert("CanUseSeparatedData");
		ApplicationParameters[ParameterName].Insert("ClientEventHandlers");
		ApplicationParameters[ParameterName].Insert("CountEmployedFiles");
		ApplicationParameters[ParameterName].Insert("DataSeparationEnabled");
		ApplicationParameters[ParameterName].Insert("InfobaseBackupOnComplete");
		ApplicationParameters[ParameterName].Insert("IsExternalUserSession");
		ApplicationParameters[ParameterName].Insert("FileInfobase");	
		ApplicationParameters[ParameterName].Insert("OfflineWorkParameters");		
		ApplicationParameters[ParameterName].Insert("PersonalFileOperationsSettings");
		
	EndIf;
	
	FillPropertyValues(ApplicationParameters[ParameterName], ClientParameters);
	
	// Update of the desktop hide state on the client based on the server state.
	StandardSubsystemsClient.HideDesktopOnStart(
		Parameters.HideDesktopOnStart, True);
	
	Return ClientParameters;
	
EndFunction

// It returns the structure of
// the parameters necessary for the configuration work on the client.
// 
// Returns:
//   FixedStructure - structure of the client work parameters on start.
//                           
Function ClientWorkParameters() Export
	
	CurrentDate = CurrentDate(); // Current date of the client computer.
	
	ClientWorkParameters = New Structure;
	WorkParameters = StandardSubsystemsServerCall.ClientWorkParameters();
	For Each Parameter In WorkParameters Do
		ClientWorkParameters.Insert(Parameter.Key, Parameter.Value);
	EndDo;
	ClientWorkParameters.SessionTimeOffset = ClientWorkParameters.SessionTimeOffset - CurrentDate;
	
	Return New FixedStructure(ClientWorkParameters);
	
EndFunction

#EndRegion

#Region ServiceProceduresAndFunctions

// It returns the array of the client event handler descriptions.
Function HandlersForClientEvents(Event, Service = False) Export
	
	PreparedHandlers = PreparedHandlersForClientEvents(Event, Service);
	
	If PreparedHandlers = Undefined Then
		// Cache autoupdate. Update reused values is required.
		StandardSubsystemsServerCall.OnGettingErrorHandlersEvents();
		RefreshReusableValues();
		// Retry to get event handlers.
		PreparedHandlers = PreparedHandlersForClientEvents(Event, Service, False);
	EndIf;
	
	Return PreparedHandlers;
	
EndFunction

// It returns the matching of the names and client modules.
Function NamesOfClientModules() Export
	
	NameArray = StandardSubsystemsServerCall.ArrayOfNamesOfClientModules();
	
	ClientModules = New Map;
	
	For Each Name In NameArray Do
		ClientModules.Insert(Eval(Name), Name);
	EndDo;
	
	Return New FixedMap(ClientModules);
	
EndFunction

#Region WorkWithPredefinedData

// It receives the predefined item reference by its full name.
//  Details - see CommonUseClientServer.PredefinedItem();
//
Function PredefinedItem(Val FullPredefinedName) Export
	
	Return StandardSubsystemsServerCall.PredefinedItem(FullPredefinedName);
	
EndFunction

#EndRegion

#Region HelperProcedureAndFunctions

Function PreparedHandlersForClientEvents(Event, Service = False, FirstTry = True)
	
	Parameters = StandardSubsystemsClient.ClientParameter("ClientEventHandlers");
	
	If Service Then
		Handlers = Parameters.ServiceEventHandlers.Get(Event);
	Else
		Handlers = Parameters.EventsHandlers.Get(Event);
	EndIf;
	
	If FirstTry AND Handlers = Undefined Then
		Return Undefined;
	EndIf;
	
	If Handlers = Undefined Then
		If Service Then
			Raise StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Client service event ""%1"" is not found.'"), Event);
		Else
			Raise StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'The ""%1"" client event is not found.'"), Event);
		EndIf;
	EndIf;
	
	Array = New Array;
	
	For Each Handler In Handlers Do
		Item = New Structure;
		Module = Undefined;
		
		If FirstTry Then
			Try
				Module = CommonUseClient.CommonModule(Handler.Module);
			Except
				Return Undefined;
			EndTry;
		Else
			Module = CommonUseClient.CommonModule(Handler.Module);
		EndIf;
		Item.Insert("Module",     Module);
		Item.Insert("Version",     Handler.Version);
		Item.Insert("Subsystem", Handler.Subsystem);
		Array.Add(New FixedStructure(Item));
	EndDo;
	
	Return New FixedArray(Array);
	
EndFunction

#EndRegion

#EndRegion
