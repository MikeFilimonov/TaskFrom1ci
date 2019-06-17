
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	CallParameters = New Structure("Source, Window");
	FillPropertyValues(CallParameters, CommandExecuteParameters);
	CallParameters.Insert("Uniqueness", "Panel_Purchases");
	ReportsVariantsClient.ShowReportsPanel("Purchases", CallParameters, NStr("en = 'Inventory and purchasing reports'"));
	
EndProcedure
