////////////////////////////////////////////////////////////////////////////////
// Subsystem "Data exchange in the service model".
// 
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProgramInterface

// Handler of the application client session start.
// If the session is started for the offline workplace, then
// the user is notified about the necessity to synchronize
// data with the application in the Internet (if the corresponding flag is set).
//
Procedure OnStart(Parameters) Export
	
	ClientWorkParameters = StandardSubsystemsClientReUse.ClientWorkParametersOnStart();
	
	If ClientWorkParameters.DataSeparationEnabled Then
		Return;
	EndIf;
	
	If ClientWorkParameters.ThisIsOfflineWorkplace Then
		ParameterName = "StandardSubsystems.OfferToSynchronizeDataWithApplicationOnTheInternetOnSessionExit";
		If ApplicationParameters[ParameterName] = Undefined Then
			ApplicationParameters.Insert(ParameterName, Undefined);
		EndIf;
		
		ApplicationParameters["StandardSubsystems.OfferToSynchronizeDataWithApplicationOnTheInternetOnSessionExit"] =
			ClientWorkParameters.SynchronizeDataWithApplicationInInternetOnExit;
		
		If ClientWorkParameters.SynchronizeDataWithApplicationInInternetOnWorkStart Then
			
			ShowUserNotification(NStr("en = 'OffLine work'"), "e1cib/app/DataProcessor.DataExchangeExecution",
				NStr("en = 'It is recommended to synchronize data with the online application.'"), PictureLib.Information32);
			
		EndIf;
		
	EndIf;
	
EndProcedure

// It is called on system shutdown to request
// a list of warnings displayed to a user.
//
// Parameters:
// see OnReceiveListOfEndWorkWarning.
//
Procedure BeforeExit(Cancel, Warnings) Export
	
	OfflineWorkParameters = StandardSubsystemsClient.ClientParameter("OfflineWorkParameters");
	If ApplicationParameters["StandardSubsystems.OfferToSynchronizeDataWithApplicationOnTheInternetOnSessionExit"] = True
		AND OfflineWorkParameters.SynchronizationWithServiceHasNotBeenExecutedLongAgo Then
		
		WarningParameters = StandardSubsystemsClient.AlertOnEndWork();
		WarningParameters.ExtendedTooltip = NStr("en = 'In some cases data synchronization can take a long time:
		                                         | - slow communication channel;
		                                         | - large data volume;
		                                         | - application update is avaliable in the Internet.'");

		WarningParameters.FlagText = NStr("en = 'Synchronize data with the online application'");
		WarningParameters.Priority = 80;
		
		ActionIfMarked = WarningParameters.ActionIfMarked;
		ActionIfMarked.Form = "DataProcessor.DataExchangeExecution.Form.Form";
		
		FormParameters = OfflineWorkParameters.FormParametersDataExchange;
		FormParameters = CommonUseClientServer.CopyStructure(FormParameters);
		FormParameters.Insert("CompletingOfWorkSystem", True);
		ActionIfMarked.FormParameters = FormParameters;
		
		Warnings.Add(WarningParameters);
	EndIf;
	
EndProcedure

#EndRegion
