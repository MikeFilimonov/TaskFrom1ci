////////////////////////////////////////////////////////////////////////////////
// Subsystem "Configuration update".
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProceduresAndFunctions

// Receives the settings of update assistant from common settings storage.
//
// Details - see description InstallUpdates.ReceiveAssistantSettingsStructure().
//
Function GetSettingsStructureOfAssistant() Export
	
	Return ConfigurationUpdate.GetSettingsStructureOfAssistant();
	
EndFunction

// Writes the settings of update assistant to common settings storage.
//
// Details - see description InstallUpdates.WriteAssistantSettingsStructure().
//
Procedure WriteStructureOfAssistantSettings(ConfigurationUpdateOptions, MessagesForEventLogMonitor = Undefined) Export
	
	ConfigurationUpdate.WriteStructureOfAssistantSettings(ConfigurationUpdateOptions, MessagesForEventLogMonitor);
	
EndProcedure

#EndRegion
