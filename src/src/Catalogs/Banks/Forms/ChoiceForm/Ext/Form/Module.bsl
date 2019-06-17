
///////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM COMMAND HANDLERS

&AtClient
Procedure PickFromClassifier(Command)
	
	FormParameters = New Structure("CloseOnChoice, Multiselect", True, True);
	OpenForm("Catalog.BankClassifier.ChoiceForm", FormParameters, ThisForm);

EndProcedure

#Region ProcedureFormEventHandlers

// Procedure form event handler OnCreateAtServer
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("ListOfFoundBanks") Then
		
		DriveClientServer.SetListFilterItem(List, "Ref", Parameters.ListOfFoundBanks, True,DataCompositionComparisonType.InList);
		Items.List.ChoiceFoldersAndItems = FoldersAndItemsUse.Items;
		Items.List.Representation = TableRepresentation.List;
		
	EndIf;
	
EndProcedure

// Form event handler procedure NotificationProcessing
//
&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "RefreshAfterAdd" Then
		Items.List.Refresh();
	EndIf;
	
EndProcedure

#Region InteractiveActionResultHandlers

&AtClient
// Procedure-handler of the prompt result about selecting the bank from classifier
//
//
Procedure DetermineBankPickNeedFromClassifier(ClosingResult, AdditionalParameters) Export
	
	If ClosingResult = DialogReturnCode.Yes Then
		
		FormParameters = New Structure("ChoiceMode, CloseOnChoice, Multiselect", True, True, True);
		OpenForm("Catalog.BankClassifier.ChoiceForm", FormParameters, ThisForm);
		
	Else
		
		If AdditionalParameters.IsFolder Then
			
			OpenForm("Catalog.Banks.FolderForm", New Structure("IsFolder",True), ThisObject);
			
		Else
			
			OpenForm("Catalog.Banks.ObjectForm");
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormItemsEventsHandlers

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	Cancel = True;
	
	QuestionText = NStr("en = 'Do you want to choose bank from the bank classifier or create it manually?
	                    |Click Yes to choose bank from the classifier and modify it if necessary.
	                    |Click No to create new record from scratch.'");
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("IsFolder", Group);
	NotifyDescription = New NotifyDescription("DetermineBankPickNeedFromClassifier", ThisObject, AdditionalParameters);
	
	ShowQueryBox(NotifyDescription, QuestionText, QuestionDialogMode.YesNo, , DialogReturnCode.Yes);
	
EndProcedure

#EndRegion

#EndRegion
