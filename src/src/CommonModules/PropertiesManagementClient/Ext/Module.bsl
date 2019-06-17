////////////////////////////////////////////////////////////////////////////////
// Properties subsystem
// 
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Opens the form for editing the additional attributes.
//
// Parameters:
//  Form        - ManagedForm, preconfigured in procedure.
//                PropertiesManagement.OnCreateAtServer()
//
Procedure EditContentOfProperties(Form, Ref = Undefined) Export
	
	Sets = Form.Properties_AdditionalObjectAttributesSets;
	
	If Sets.Count() = 0
		OR NOT ValueIsFilled(Sets[0].Value) Then
		
		ShowMessageBox(,
			NStr("en = 'Failed to receive the additional object attributes.
			     |Perhaps, the necessary attributes have not been filled for the document.'"));
	
	Else
		FormParameters = New Structure;
		FormParameters.Insert("ShowAdditionalAttributes");
		
		OpenForm("Catalog.AdditionalAttributesAndInformationSets.ListForm", FormParameters);
		
		ParametersOfTransition = New Structure;
		ParametersOfTransition.Insert("Set",							Sets[0].Value);
		ParametersOfTransition.Insert("Property",						Undefined);
		ParametersOfTransition.Insert("ThisIsAdditionalInformation",	False);
		
		LengthBeginning = StrLen("AdditionalAttributeValue_");
		If Upper(Left(Form.CurrentItem.Name, LengthBeginning)) = Upper("AdditionalAttributeValue_") Then
			
			IDSet   = StrReplace(Mid(Form.CurrentItem.Name, LengthBeginning +  1, 36), "x", "-");
			PropertyID = StrReplace(Mid(Form.CurrentItem.Name, LengthBeginning + 38, 36), "x", "-");
			
			If StringFunctionsClientServer.ThisIsUUID(Lower(IDSet)) Then
				ParametersOfTransition.Insert("Set", IDSet);
			EndIf;
			
			If StringFunctionsClientServer.ThisIsUUID(Lower(PropertyID)) Then
				ParametersOfTransition.Insert("Property", PropertyID);
			EndIf;
		EndIf;
		
		Notify("Transition_SetsOfAdditionalDetailsAndInformation", ParametersOfTransition);
	EndIf;
	
EndProcedure

// Defines that the specified event is the event related to the change of attributes set.
// 
// Return value:
//  Boolean - if True, this notification is about changing the attributes
//            set, and you need to handle it in a form.
//
Function ProcessAlerts(Form, EventName, Parameter) Export
	
	If NOT Form.Properties_UseProperties
		OR NOT Form.Properties_UseAdditAttributes Then
		
		Return False;
	EndIf;
	
	If EventName = "Writing_AdditionalAttributesAndInformationSets" Then
		Return Form.Properties_AdditionalObjectAttributesSets.FindByValue(Parameter.Ref) <> Undefined;
		
	ElsIf EventName = "Writing_AdditionalAttributesAndInformation" Then
		Filter = New Structure("Property", Parameter.Ref);
		Return Form.Properties_AdditionalAttributesDescription.FindRows(Filter).Count() > 0;
		
	EndIf;
	
	Return False;
	
EndFunction

Procedure AfterAdditionalAttributeImport(Form) Export
	
	If NOT Form.Properties_UseProperties
		OR NOT Form.Properties_UseAdditAttributes Then
		
		Return;
	EndIf;
	
	If Form.Properties_DescriptionDependentAdditionalAttributes.Count() > 0 Then
		Form.AttachIdleHandler("UpdateAdditionalAttributeDependencies", 2);
	EndIf;
	
EndProcedure

// Updates visibility, availability and check filling
// additional attributes.
//
// Parameters:
//  Form	- ManagedForm		- processed form.
//  Object	- FormDataStructure	- Description of the object to which the properties are connected,
// 									if the property is not specified or Undefined, then
// 									the object will be taken from the "Object" attribute form.
//
Procedure UpdateAdditionalAttributeDependencies(Form, Object = Undefined) Export
	
	If NOT Form.Properties_UseProperties
		OR NOT Form.Properties_UseAdditionalAttributes Then
		
		Return;
	EndIf;
	
	If Object = Undefined Then
		ObjectDescription = Form.Object;
	Else
		ObjectDescription = Object;
	EndIf;
	
	For Each AdditionalAttributeDependence In Form.Properties_DescriptionDependentAdditionalAttributes Do
		
		If AdditionalAttributeDependence.DisplayAsHyperlink Then
			ProcessedElement = StrReplace(AdditionalAttributeDependence.AttributeNameValue, "AdditionalAttributeValue_", "Group_");
		Else
			ProcessedElement = AdditionalAttributeDependence.AttributeNameValue;
		EndIf;
		
		If AdditionalAttributeDependence.AvailabilityCondition <> Undefined Then
			Parameters = New Structure;
			Parameters.Insert("ParameterValues",	AdditionalAttributeDependence.AvailabilityCondition.ParameterValues);
			Parameters.Insert("Form",				Form);
			Parameters.Insert("ObjectDescription",	ObjectDescription);
			Result = Eval(AdditionalAttributeDependence.AvailabilityCondition.ConditionCode);
			
			Item = Form.Items[ProcessedElement];
			If Item.Enabled <> Result Then
				Item.Enabled = Result;
			EndIf;
			
		EndIf;
		
		If AdditionalAttributeDependence.VisibilityCondition <> Undefined Then
			Parameters = New Structure;
			Parameters.Insert("ParameterValues",	AdditionalAttributeDependence.VisibilityCondition.ParameterValues);
			Parameters.Insert("Form",				Form);
			Parameters.Insert("ObjectDescription",	ObjectDescription);
			Result = Eval(AdditionalAttributeDependence.VisibilityCondition.ConditionCode);
			
			Item = Form.Items[ProcessedElement];
			If Item.Visibility <> Result Then
				Item.Visibility = Result;
			EndIf;
			
		EndIf;
		
		If AdditionalAttributeDependence.CheckFillingCondition <> Undefined Then
			
			If NOT AdditionalAttributeDependence.FillingRequired Then
				Continue;;
			EndIf;
			
			Parameters = New Structure;
			Parameters.Insert("ParameterValues",	AdditionalAttributeDependence.CheckFillingCondition.ParameterValues);
			Parameters.Insert("Form",				Form);
			Parameters.Insert("ObjectDescription",	ObjectDescription);
			Result = Eval(AdditionalAttributeDependence.CheckFillingCondition.ConditionCode);
			
			Item = Form.Items[ProcessedElement];
			If Item.AutoUnfilled <> Result Then
				Item.AutoUnfilled = Result;
			EndIf;
			
		EndIf;
		
	EndDo;
	
EndProcedure

#EndRegion
