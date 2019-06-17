
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	FormParameters = New Structure("PurposeUseKey", "PurchaseOrders");
	OpenedForm = OpenForm("DataProcessor.OrdersClosing.Form.Form", FormParameters, CommandExecuteParameters.Source,
					CommandExecuteParameters.Uniqueness, CommandExecuteParameters.Window, CommandExecuteParameters.URL);
	
EndProcedure
