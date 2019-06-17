
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	OpenForm("CommonForm.DataSyncSaaS",,
			CommandExecuteParameters.Source,
			CommandExecuteParameters.Uniqueness,
			CommandExecuteParameters.Window);
	
EndProcedure
