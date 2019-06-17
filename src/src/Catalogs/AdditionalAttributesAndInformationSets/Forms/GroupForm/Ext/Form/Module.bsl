
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	ReadOnly = True;
	
	SetPropertyTypes = PropertiesManagementService.SetPropertyTypes(Object.Ref);
	UseAdditAttributes = SetPropertyTypes.AdditionalAttributes;
	UseAdditInfo  = SetPropertyTypes.AdditionalInformation;
	
	If UseAdditAttributes AND UseAdditInfo Then
		Title = Object.Description + " " + NStr("en = '(Group of sets of additional attributes and information)'")
		
	ElsIf UseAdditAttributes Then
		Title = Object.Description + " " + NStr("en = '(Group of sets of additional attributes)'")
		
	ElsIf UseAdditInfo Then
		Title = Object.Description + " " + NStr("en = '(Group of additional information sets)'")
	EndIf;
	
EndProcedure

#EndRegion
