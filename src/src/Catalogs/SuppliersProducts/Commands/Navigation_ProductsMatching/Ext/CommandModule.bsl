
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	FilterStructure = New Structure("Products", CommandParameter);
	FormParameters = New Structure("Filter, ShowCreateGroup", FilterStructure, False);
	
	OpenForm("Catalog.SuppliersProducts.ListForm",
				FormParameters,
				CommandExecuteParameters.Source,
				CommandExecuteParameters.Uniqueness,
				CommandExecuteParameters.Window,
				CommandExecuteParameters.URL);
EndProcedure
