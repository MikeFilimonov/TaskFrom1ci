#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	If CheckBeforeFilling(CommandParameter) Then
		Return;
	EndIf;
	
	OpenForm(
		"Document.CreditNote.ObjectForm",
		New Structure("Basis", CommandParameter),
		CommandExecuteParameters.Source,
		CommandExecuteParameters.Uniqueness,
		CommandExecuteParameters.Window,
		CommandExecuteParameters.URL);
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Function CheckBeforeFilling(Documents)
	
	Return EarlyPaymentDiscountsServer.CheckBeforeCreditNoteFilling(Documents);
	
EndFunction

#EndRegion