
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	OpenForm("Catalog.Peripherals.Form.PaymentTerminalFunctions", , CommandExecuteParameters.Source, CommandExecuteParameters.Uniqueness);
	
EndProcedure
