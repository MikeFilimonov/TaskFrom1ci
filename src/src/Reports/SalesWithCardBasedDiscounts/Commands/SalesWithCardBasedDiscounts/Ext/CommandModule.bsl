
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	FormParameters 	= New Structure("VariantKey", "SalesWithCardBasedDiscounts");
	
	OpenForm("Report.SalesWithCardBasedDiscounts.Form", FormParameters, CommandExecuteParameters.Source, CommandExecuteParameters.Uniqueness, CommandExecuteParameters.Window);
	
EndProcedure
