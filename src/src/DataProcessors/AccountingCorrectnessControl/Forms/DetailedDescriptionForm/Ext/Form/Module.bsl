
#Region FormEventHandlers

// Procedure - OnCreateAtServer event handler.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	HTMLData = FormAttributeToValue("Object").GetTemplate("DetailedDescriptionHTML");
	DetailedDescriptionText = HTMLData.GetText();
	
	TransitionLink = "link_" + Parameters.TransitionLink;
	
EndProcedure

#EndRegion

#Region FormItemsEventsHandlers

// Procedure-handler of the event of HTML-document generating end of the TextDetailedDescription field
//
&AtClient
Procedure DetailedDescriptionTextDocumentCreated(Item)
	
	If TransitionLink = "" Then
		Return;	
	EndIf;
	
	For Each LinkItem In Items.DetailedDescriptionText.Document.Links Do
		If LinkItem.name = TransitionLink Then
			LinkItem.Click();
		EndIf;
	EndDo; 	
	
EndProcedure

#EndRegion
