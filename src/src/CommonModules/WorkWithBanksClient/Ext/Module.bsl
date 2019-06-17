////////////////////////////////////////////////////////////////////////////////
// Subsystem "Banks".
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProgramInterface

// It is called once the configuration is launched, activates the wait handler.
//
Procedure AfterSystemOperationStart() Export
	
	ClientParameters = StandardSubsystemsClientReUse.ClientWorkParametersOnStart();
	If ClientParameters.Property("Banks") AND ClientParameters.Banks.StaleAlertOutput Then
		AttachIdleHandler("WorkWithBanksWithdrawNotificationOfIrrelevance", 45, True);
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

#Region UpdateOfTheBankClassifier

// Displays an appropriate notification.
//
Procedure NotifyClassifierOutOfDate() Export
	
	ShowUserNotification(
		NStr("en = 'Bank classifier is outdated'"),
		URLFormsExport(),
		NStr("en = 'Update the bank clasifier'"),
		PictureLib.Warning32);
	
EndProcedure

// Displays an appropriate notification.
//
Procedure NotifyClassifierUpdatedSuccessfully() Export
	
	ShowUserNotification(
		NStr("en = 'Bank classifier has been successfully updated'"),
		URLFormsExport(),
		NStr("en = 'Bank classifier is updated'"),
		PictureLib.Information32);
	
EndProcedure

// Displays an appropriate notification.
//
Procedure NotifyClassifierIsActual() Export
	
	ShowMessageBox(,NStr("en = 'The bank classifier is up-to-date and doesn''t need an update.'"));
	
EndProcedure

// Returns the navigational link for the notifications.
//
Function URLFormsExport()
	Return "e1cib/data/Catalog.BankClassifier.Form.ImportClassifier";
EndFunction

#EndRegion

#EndRegion
