#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, ExecuteParameters)
	ReportsVariantsClient.ShowReportsPanel("SetupAndAdministration", ExecuteParameters);
EndProcedure

#EndRegion
