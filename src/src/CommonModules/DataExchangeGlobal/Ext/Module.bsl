////////////////////////////////////////////////////////////////////////////////
// Data exchange subsystem
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProceduresAndFunctions

// Checks the necessity to update the database configuration in the subordinate node.
//
Procedure CheckSubordinatedNodeConfigurationUpdateNecessity() Export
	
	UpdateNeeded = StandardSubsystemsClientReUse.ClientWorkParameters().SiteConfigurationUpdateRequiredRIB;
	CheckUpdateNecessity(UpdateNeeded);
	
EndProcedure

// Checks the necessity to update the database configuration in the subordinate node on start.
//
Procedure CheckSubordinatedNodeConfigurationUpdateNecessityOnStart() Export
	
	UpdateNeeded = StandardSubsystemsClientReUse.ClientWorkParametersOnStart().SiteConfigurationUpdateRequiredRIB;
	CheckUpdateNecessity(UpdateNeeded);
	
EndProcedure

Procedure CheckUpdateNecessity(SiteConfigurationUpdateRequiredRIB)
	
	If SiteConfigurationUpdateRequiredRIB Then
		Explanation = NStr("en = 'The application update is received from ""%1"".
		                   |Install the update so that data synchronization continues.'");
		Explanation = StringFunctionsClientServer.SubstituteParametersInString(Explanation, StandardSubsystemsClientReUse.ClientWorkParameters().MasterNode);
		ShowUserNotification(NStr("en = 'Install the update'"), "e1cib/app/DataProcessor.DataExchangeExecution",
			Explanation, PictureLib.Warning32);
		Notify("DataExchangeCompleted");
	EndIf;
	
	AttachIdleHandler("CheckSubordinatedNodeConfigurationUpdateNecessity", 60 * 60, True); // once an hour
	
EndProcedure

#EndRegion
