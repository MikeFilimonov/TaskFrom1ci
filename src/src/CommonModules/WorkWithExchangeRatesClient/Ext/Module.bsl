////////////////////////////////////////////////////////////////////////////////
// Subsystem "Currencies"
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProgramInterface

// It is called once the configuration is launched, activates the wait handler.
Procedure AfterSystemOperationStart() Export
	
	ClientParameters = StandardSubsystemsClientReUse.ClientWorkParametersOnStart();
	If ClientParameters.Property("Currencies") AND ClientParameters.Currencies.ExchangeRatesAreRelevantUpdatedByResponsible Then
		AttachIdleHandler("ExchangeRateOperationsShowNotificationAboutNonActuality", 15, True);
	EndIf;
	
EndProcedure

#EndRegion

#Region ProgramInterface

// Open external data processor form - ExchangeRatesImportProcessor
Procedure OpenFormOfExchangeRatesImportProcessor(FormParameters = Undefined) Export         
	
	// Check for data processor
	WorkWithExchangeRatesServerCall.GetConstantExchangeRatesImportProcessor();
	
	OpenForm("DataProcessor.ImportExchangeRates.Form", FormParameters);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

#Region UpdateOfTheCurrencyExchangeRates

// Displays an appropriate notification.
//
Procedure NotifyRatesOutdated() Export
	
	ShowUserNotification(
		NStr("en = 'Exchange rates are outdated'"),
		ProcessorsURL(),
		NStr("en = 'Update exchange rates'"),
		PictureLib.Warning32);
	
EndProcedure

// Displays an appropriate notification.
//
Procedure NotifyExchangeRatesSuccessfullyUpdated() Export
	
	ShowUserNotification(
		NStr("en = 'Exchange rates are successfully updated'"),
		,
		NStr("en = 'Exchange rates are updated'"),
		PictureLib.Information32);
	
EndProcedure

// Displays an appropriate notification.
//
Procedure NotifyCoursesAreActual() Export
	
	ShowMessageBox(,NStr("en = 'Exchange rates are relevant.'"));
	
EndProcedure

// Returns the navigational link for the notifications.
//
Function ProcessorsURL()
	Return "e1cib/app/DataProcessor.ImportExchangeRates";
EndFunction

#EndRegion

#EndRegion
