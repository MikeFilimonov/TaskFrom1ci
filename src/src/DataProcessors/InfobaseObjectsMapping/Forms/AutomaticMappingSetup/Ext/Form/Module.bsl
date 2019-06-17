
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	MappingFieldList = Parameters.MappingFieldList;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	RefreshExplanationLabelText();
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure MappingFieldListOnChange(Item)
	
	RefreshExplanationLabelText();
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure PerformMapping(Command)
	
	NotifyChoice(MappingFieldList.Copy());
	
EndProcedure

&AtClient
Procedure Cancel(Command)
	
	NotifyChoice(Undefined);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure RefreshExplanationLabelText()
	
	MarkedListItemArray = CommonUseClientServer.GetArrayOfMarkedListItems(MappingFieldList);
	
	If MarkedListItemArray.Count() = 0 Then
		
		ExplanatoryInscription = NStr("en = 'Objects will be mapped only by internal identifiers.'");
		
	Else
		
		ExplanatoryInscription = NStr("en = 'Objects will be mapped by internal identifiers and selected fields.'");
		
	EndIf;
	
EndProcedure

#EndRegion
