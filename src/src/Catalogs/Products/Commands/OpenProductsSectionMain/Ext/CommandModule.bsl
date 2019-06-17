
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	OpeningParameters = New Structure("IsHomePage", False);
	OpenForm("Catalog.Products.ListForm", OpeningParameters, CommandExecuteParameters.Source, CommandExecuteParameters.Uniqueness, CommandExecuteParameters.Window, CommandExecuteParameters.URL);
	
EndProcedure
