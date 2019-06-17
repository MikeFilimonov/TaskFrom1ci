
&AtServer
Procedure FillFormByObject()
	
	WorkWithBanksOverridable.ReadManualEditFlag(ThisForm);
	
	Items.PagesActivityDiscontinued.CurrentPage = ?(ActivityDiscontinued,
		Items.PageLabelActivityDiscontinued, Items.PageBlank);
	
EndProcedure

#Region ProcedureFormEventHandlers

&AtClient
Procedure AfterWrite(WriteParameters)
	
	// Notify the bank account form about the change of bank requisites
	Notify("RecordedItemBank", Object.Ref, ThisForm);

EndProcedure

&AtClient
Procedure Change(Command)
	
	Text = NStr("en = 'Record for this bank is automatically kept in sync with the bank classifier. 
	            |If you enable manual modification of bank record, the record will no longer be updated automatically. 
	            |Do you want to edit bank record and disable automatic updates?'");
	Result = Undefined;

	ShowQueryBox(New NotifyDescription("ChangeEnd", ThisObject), Text, QuestionDialogMode.YesNo,, DialogReturnCode.No);
	
EndProcedure

&AtClient
Procedure ChangeEnd(Result1, AdditionalParameters) Export
	
	Result = Result1;
	
	If Result = DialogReturnCode.Yes Then
		
		LockFormDataForEdit();
		Modified		= True;
		ManualChanging	= True;
		
		WorkWithBanksClientOverridable.ProcessManualEditFlag(ThisForm);
		
	EndIf;

EndProcedure

&AtClient
Procedure UpdateFromClassifier(Command)
	
	ExecuteUpdate = False;
	WorkWithBanksClientOverridable.RefreshItemFromClassifier(ThisForm, ExecuteUpdate);
	
EndProcedure

&AtServer
Procedure UpdateAtServer()
	
	WorkWithBanksOverridable.RestoreItemFromSharedData(ThisForm);
	
EndProcedure

#Region InteractiveActionResultHandlers

&AtClient
// Procedure-handler of response on the question about data update from classifier
//
Procedure DetermineNecessityForDataUpdateFromClassifier(ClosingResult, AdditionalParameters) Export
	
	If ClosingResult = DialogReturnCode.Yes Then
		
		LockFormDataForEdit();
		Modified = True;
		UpdateAtServer();
		NotifyChanged(Object.Ref);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region LibrariesHandlers

// StandardSubsystems.Printing
&AtClient
Procedure Attachable_ExecutePrintCommand(Command)
	PrintManagementClient.ExecuteConnectedPrintCommand(Command, ThisObject, Object);
EndProcedure
// End StandardSubsystems.Printing

// StandardSubsystems.Properties
&AtClient
Procedure Attachable_EditContentOfProperties(Command)
	
	PropertiesManagementClient.EditContentOfProperties(ThisForm, Object.Ref);
	
EndProcedure

&AtServer
Procedure UpdateAdditionalAttributesItems()
	
	PropertiesManagement.UpdateAdditionalAttributesItems(ThisForm, FormAttributeToValue("Object"));
	
EndProcedure
// End StandardSubsystems.Printing

#EndRegion

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Object.Ref.IsEmpty() Then
		If Parameters.Code <> "" Then
			Object.Code = Parameters.Code;
		EndIf;
		
		FillFormByObject();
	EndIf;
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.Printing
	
	// StandardSubsystems.Properties
	PropertiesManagement.OnCreateAtServer(ThisForm, Object, "GroupAdditionalAttributes");
	// End StandardSubsystems.Properties
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	// StandardSubsystems.Properties
	If PropertiesManagementClient.ProcessAlerts(ThisForm, EventName, Parameter) Then
		UpdateAdditionalAttributesItems();
	EndIf;
	// End StandardSubsystems.Properties
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	// StandardSubsystems.Properties
	PropertiesManagement.OnReadAtServer(ThisForm, CurrentObject);
	// End StandardSubsystems.Properties
	
	FillFormByObject();
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	// StandardSubsystems.Properties
	PropertiesManagement.BeforeWriteAtServer(ThisForm, CurrentObject);
	// End StandardSubsystems.Properties
	
	CurrentObject.ManualChanging = ?(ManualChanging = Undefined, 2, ManualChanging);
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	// StandardSubsystems.Properties
	PropertiesManagement.FillCheckProcessing(ThisForm, Cancel, CheckedAttributes);
	// End StandardSubsystems.Properties
EndProcedure

#EndRegion

#EndRegion
