
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	CallParameters = New Structure("Source, Window");
	FillPropertyValues(CallParameters, CommandExecuteParameters);
	
	CallParameters.Insert("Uniqueness", "Panel_Production");
	
	ReportsVariantsClient.ShowReportsPanel("Production", CallParameters, NStr("en = 'More reports...'"));
	
EndProcedure
