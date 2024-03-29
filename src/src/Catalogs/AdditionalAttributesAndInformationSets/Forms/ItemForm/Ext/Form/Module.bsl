﻿
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	ReadOnly = True;
	
	SetPropertyTypes	= PropertiesManagementService.SetPropertyTypes(Object.Ref);
	UseAdditAttributes	= SetPropertyTypes.AdditionalAttributes;
	UseAdditInfo		= SetPropertyTypes.AdditionalInformation;
	
	If UseAdditAttributes AND UseAdditInfo Then
		Title = Object.Description + " " + NStr("en = '(Set of additional attributes and information)'")
		
	ElsIf UseAdditAttributes Then
		Title = Object.Description + " " + NStr("en = '(Additional attribute set)'")
		
	ElsIf UseAdditInfo Then
		Title = Object.Description + " " + NStr("en = '(Additional information set)'")
	EndIf;
	
	If Not UseAdditAttributes AND Object.AdditionalAttributes.Count() = 0 Then
		Items.AdditionalAttributes.Visible = False;
	EndIf;
	
	If Not UseAdditInfo AND Object.AdditionalInformation.Count() = 0 Then
		Items.AdditionalInformation.Visible = False;
	EndIf;
	
EndProcedure

#EndRegion
