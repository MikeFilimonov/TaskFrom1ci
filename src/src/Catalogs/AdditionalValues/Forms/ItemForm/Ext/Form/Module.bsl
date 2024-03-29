﻿
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	If Not ValueIsFilled(Object.Ref)
	   AND Parameters.FillingValues.Property("Description") Then
		
		Object.Description = Parameters.FillingValues.Description;
	EndIf;
	
	If Not Parameters.HideOwner Then
		Items.Owner.Visible = True;
	EndIf;
	
	If TypeOf(Parameters.ShowWeight) = Type("Boolean") Then
		ShowWeight = Parameters.ShowWeight;
	Else
		ShowWeight = CommonUse.ObjectAttributeValue(Object.Owner, "AdditionalValuesWithWeight");
	EndIf;
	
	If ShowWeight = True Then
		Items.Weight.Visible = True;
	Else
		Items.Weight.Visible = False;
		Object.Weight = 0;
	EndIf;
	
	SetTitle();
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "Update_ValueIsCharacterizedByWeighting"
	   AND Source = Object.Owner Then
		
		If Parameter = True Then
			Items.Weight.Visible = True;
		Else
			Items.Weight.Visible = False;
			Object.Weight = 0;
		EndIf;
	EndIf;
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	SetTitle();
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	Notify("Record_ValuesOfObjectProperties",
		New Structure("Ref", Object.Ref), Object.Ref);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

Procedure SetTitle()
	
	AttributeValues = CommonUse.ObjectAttributesValues(
		Object.Owner, "Title, ValueFormHeader");
	
	PropertyName = TrimAll(AttributeValues.ValueFormHeader);
	
	If Not IsBlankString(PropertyName) Then
		If ValueIsFilled(Object.Ref) Then
			Title = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = '%1 (%2)'"),
				Object.Description,
				PropertyName);
		Else
			Title = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = '%1 (creation)'"), PropertyName);
		EndIf;
	Else
		PropertyName = String(AttributeValues.Title);
		
		If ValueIsFilled(Object.Ref) Then
			Title = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = '%1 (value of attribute %2)'"),
				Object.Description,
				PropertyName);
		Else
			Title = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Value of attribute %1 (Create)'"), PropertyName);
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion
