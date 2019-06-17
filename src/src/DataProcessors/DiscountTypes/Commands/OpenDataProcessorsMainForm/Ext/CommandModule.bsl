
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	// Insert handler content
	OpenForm("DataProcessor.DiscountTypes.Form", , CommandExecuteParameters.Source, CommandExecuteParameters.Uniqueness, CommandExecuteParameters.Window, CommandExecuteParameters.URL);
EndProcedure
