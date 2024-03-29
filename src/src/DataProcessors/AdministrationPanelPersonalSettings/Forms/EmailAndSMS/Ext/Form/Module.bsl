﻿
#Region EventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	ReadValues();
	
EndProcedure

&AtClient
Procedure AtAttributeChange(Item)
	
	SaveAttributeValue(Item.Name);
	
EndProcedure

&AtClient
Procedure SaveSignature(Command)
	
	SaveAttributeValue("SignatureFormattedDocument");
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure ReadValues()
	
	SMSSenderName = CommonUse.CommonSettingsStorageImport("SMSSettings", "SMSSenderName", "");
	
	AddSignatureForNewMessages = CommonUse.CommonSettingsStorageImport("EmailSettings", "AddSignatureForNewMessages", False);
	
	HTMLSignature = CommonUse.CommonSettingsStorageImport("EmailSettings", "HTMLSignature", "");
	If IsBlankString(HTMLSignature) Then
		DefaultSignature = Chars.LF + Chars.LF + "---------------------------------" + Chars.LF;
		HTMLSignature = New FormattedString(DefaultSignature);
		SignatureFormattedDocument.SetFormattedString(HTMLSignature);
	Else
		SignatureFormattedDocument.SetHTML(HTMLSignature, New Structure);
	EndIf;
	
	DefaultEmailAccount = DriveReUse.GetValueOfSetting("DefaultEmailAccount");
	
EndProcedure

&AtServer
Procedure SaveAttributeValue(ItemName)
	
	AttributePathToData = Items[ItemName].DataPath;
	
	If AttributePathToData = "DefaultEmailAccount" Then
		
		DriveServer.SetUserSetting(DefaultEmailAccount, "DefaultEmailAccount");
		
	EndIf;
	
	If AttributePathToData = "AddSignatureForNewMessages" Then
		
		CommonUse.CommonSettingsStorageSave("EmailSettings", "AddSignatureForNewMessages", AddSignatureForNewMessages, , , True);
		
	EndIf;
	
	If AttributePathToData = "SignatureFormattedDocument" Then
		
		HTMLSignature = "";
		Attachments = New Structure;
		SignatureFormattedDocument.GetHTML(HTMLSignature, Attachments);
		
		CommonUse.CommonSettingsStorageSave("EmailSettings", "HTMLSignature", HTMLSignature, , , True);
		CommonUse.CommonSettingsStorageSave("EmailSettings", "SignatureSimpleText", SignatureFormattedDocument.GetText(), , , True);
		
	EndIf;
	
	If AttributePathToData = "SMSSenderName" Then
		
		CommonUse.CommonSettingsStorageSave("SMSSettings", "SMSSenderName", SMSSenderName, , , True);
		
	EndIf;
	
EndProcedure

#EndRegion
