
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	FieldList = Parameters.FieldList;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure Apply(Command)
	
	Cancel = False;
	
	MarkedListItemArray = CommonUseClientServer.GetArrayOfMarkedListItems(FieldList);
	
	If MarkedListItemArray.Count() = 0 Then
		
		NString = NStr("en = 'Specify at least one field'");
		
		CommonUseClientServer.MessageToUser(NString,,"FieldList",, Cancel);
		
	ElsIf MarkedListItemArray.Count() > MaximumQuantityOfCustomFields() Then
		
		// Value can not be greater than the set one.
		MessageString = StringFunctionsClientServer.SubstituteParametersInString(
							NStr("en = 'Reduce the number of fields (select no more than %1 fields).'"),
							String(MaximumQuantityOfCustomFields()));
							
		CommonUseClientServer.MessageToUser(MessageString,,"FieldList",, Cancel);
		
	EndIf;
	
	If Not Cancel Then
		
		NotifyChoice(FieldList.Copy());
		
	EndIf;
	
EndProcedure

&AtClient
Procedure Cancel(Command)
	
	NotifyChoice(Undefined);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Function MaximumQuantityOfCustomFields()
	
	Return DataExchangeClient.MaximumQuantityOfFieldsOfObjectMapping();
	
EndFunction

#EndRegion
