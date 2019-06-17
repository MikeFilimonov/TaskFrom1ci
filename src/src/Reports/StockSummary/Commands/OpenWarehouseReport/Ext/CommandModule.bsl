
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	FormParameters = New Structure("VariantKey, UsePurposeKey, Filter, GenerateAtOpen, ReportVariantCommandVisible", 
		"Statement",
		CommandParameter,
		New Structure("Products", CommandParameter), 
		True, 
		False);
	
	OpenForm("Report.StockSummary.Form",
		FormParameters,
		,
		"Products=" + CommandParameter,
		CommandExecuteParameters.Window
	);
	
EndProcedure
