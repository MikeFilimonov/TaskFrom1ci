
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	FormParameters = New Structure("PurposeUseKey", "SalesOrders");
	OpenedForm = OpenForm("DataProcessor.OrdersClosing.Form.Form", FormParameters, CommandExecuteParameters.Source,
					CommandExecuteParameters.Uniqueness, CommandExecuteParameters.Window, CommandExecuteParameters.URL);
	
EndProcedure
