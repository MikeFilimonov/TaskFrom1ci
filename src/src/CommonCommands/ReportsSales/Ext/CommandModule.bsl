
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	CallParameters = New Structure("Source, Window");
	FillPropertyValues(CallParameters, CommandExecuteParameters);
	CallParameters.Insert("Uniqueness", "Panel_Sales");
	ReportsVariantsClient.ShowReportsPanel("Sales", CallParameters, NStr("en = 'Sales reports'"));
	
EndProcedure
