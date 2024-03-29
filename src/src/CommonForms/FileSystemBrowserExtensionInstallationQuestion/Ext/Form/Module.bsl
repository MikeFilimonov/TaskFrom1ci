﻿
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	If Not IsBlankString(Parameters.SuggestionText) Then
		Items.CommentDecoration.Title = Parameters.SuggestionText
			+ Chars.LF
			+ NStr("en = 'Set?'");
		
	ElsIf Not Parameters.PossibleToContinueWithoutInstallation Then
		Items.CommentDecoration.Title =
			NStr("en = 'For the action execution it is required to install extension for the 1C:Enterprise web client.
			     |Install?'");
	EndIf;
	
	If Not Parameters.PossibleToContinueWithoutInstallation Then
		Items.ContinueWithoutInstallation.Title = NStr("en = 'Cancel'");
		Items.DoNotRemindMore.Visible = False;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure InstallAndContinue(Command)
	
	Notification = New NotifyDescription("InstallAndContinueEnd", ThisObject);
	BeginInstallFileSystemExtension(Notification);
	
EndProcedure

&AtClient
Procedure ContinueWithoutInstallation(Command)
	Close("ContinueWithoutInstallation");
EndProcedure

&AtClient
Procedure DoNotRemindMore(Command)
	Close("DoNotOfferAgain");
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure InstallAndContinueEnd(AdditionalParameters) Export
	
	Notification = New NotifyDescription("InstallAndContinueAfterExpansionConnecting", ThisObject);
	BeginAttachingFileSystemExtension(Notification);
	
EndProcedure

&AtClient
Procedure InstallAndContinueAfterExpansionConnecting(Attached, AdditionalParameters) Export
	
	If Attached Then
		Result = "ExtensionAttached";
	Else
		Result = "ContinueWithoutInstallation";
	EndIf;
	Close(Result);
	
EndProcedure

#EndRegion
