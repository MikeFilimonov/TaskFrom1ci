
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	 OpenForm("DataProcessor.BackupInfobase.Form.RestoreDataFromBackup", , 
	 	CommandExecuteParameters.Source, CommandExecuteParameters.Uniqueness, CommandExecuteParameters.Window);
EndProcedure
