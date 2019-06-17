#Region EventsHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	NotifyDescription = New NotifyDescription("ImportCurrencyClient", ThisObject);
	ShowQueryBox(NotifyDescription, 
		NStr("en = 'The files will be imported from the service manager with full data on the exchange rates of all currencies for the whole period.
		     |The exchange rates marked in the data areas for import from the Internet will be replaced in the background job. Continue?'"), 
		QuestionDialogMode.YesNo);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure ImportCurrencyClient(Response, AdditionalParameters) Export
	
	If Response = DialogReturnCode.No Then
		Return;
	EndIf;
	
	ImportRates();
	
	ShowUserNotification(
		NStr("en = 'Import is scheduled.'"), ,
		NStr("en = 'Rates will be imported in background after some time.'"),
		PictureLib.Information32);
	
EndProcedure

&AtServer
Procedure ImportRates()
	
	ExchangeRatesServiceSaaS.ImportRates();
	
EndProcedure

#EndRegion
