
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	DontShowAgain = False;
	
	ReminderText = 
	NStr("en = 'Version was not created as the file was not changed. The comment is not saved.'");
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure OK(Command)
	
	If DontShowAgain = True Then
		CommonUseServerCall.CommonSettingsStorageSaveAndRefreshReusableValues(
			"ApplicationSettings",
			"ShowFileNotChangedMessage",
			False);
	EndIf;
	
	Close(DontShowAgain);
	
EndProcedure

#EndRegion
