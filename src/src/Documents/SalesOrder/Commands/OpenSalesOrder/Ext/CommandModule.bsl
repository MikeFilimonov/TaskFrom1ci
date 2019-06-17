
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	If CommandExecuteParameters.Window = Undefined Then
		Source = Undefined;
		Uniqueness = "SalesOrder";
	Else
		Source = CommandExecuteParameters.Source;
		Uniqueness = CommandExecuteParameters.Uniqueness;
	EndIf;
	
	OpenForm("Document.SalesOrder.ListForm", , Source, Uniqueness, CommandExecuteParameters.Window);
	
EndProcedure
