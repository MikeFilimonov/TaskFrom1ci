
#Region EventsHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	If DriveReUse.SettingsForSynchronizationSaaS() Then
		
		If StandardSubsystemsClientReUse.ClientWorkParameters().CanUseSeparatedData Then
			
			OpenForm(
				"DataProcessor.AdministrationPaneIIntegration.Form.DataSynchronizationSettings",
				New Structure,
				CommandExecuteParameters.Source,
				"DataProcessor.AdministrationPaneIIntegration.Form.DataSynchronizationSettings" + ?(CommandExecuteParameters.Window = Undefined, ".SingleWindow", ""),
				CommandExecuteParameters.Window);
				
		Else
			OpenForm(
				"DataProcessor.AdministrationPanelSSLSaaS.Form.DataSynchronizationForServiceAdministrator",
				New Structure,
				CommandExecuteParameters.Source,
				"DataProcessor.AdministrationPanelSSLSaaS.Form.DataSynchronizationForServiceAdministrator" + ?(CommandExecuteParameters.Window = Undefined, ".SingleWindow", ""),
				CommandExecuteParameters.Window);
			
		EndIf;
			
	Else
			
		OpenForm(
			"DataProcessor.AdministrationPaneIIntegration.Form.DataSynchronizationSettings",
			New Structure,
			CommandExecuteParameters.Source,
			"DataProcessor.AdministrationPaneIIntegration.Form.DataSynchronizationSettings" + ?(CommandExecuteParameters.Window = Undefined, ".SingleWindow", ""),
			CommandExecuteParameters.Window);
		
	EndIf;
	
EndProcedure

#EndRegion
