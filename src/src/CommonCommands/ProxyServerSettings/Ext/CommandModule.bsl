
#Region EventsHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
#If WebClient Then
	ShowMessageBox(, NStr("en = 'Set proxy server parameters of web client in browser settings.'"));
	Return;
#EndIf
	
	OpenForm("CommonForm.ProxyServerSettings", New Structure("ProxySettingAtClient", True));
	
EndProcedure

#EndRegion
