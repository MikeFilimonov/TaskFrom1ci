#Region FormEventHandlers

&AtServer
// Procedure - OnCreateAtServer event handler.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Items.ConfigureAttributesSet.Visible				= True;
	Items.ConfigureCharacteristicsAttributesSet.Visible	= GetFunctionalOption("UseCharacteristics");
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.Printing
	
EndProcedure

&AtClient
// Procedure - event handler Click of the hyperlink ConfigureCharacteristicsPropertiesSet.
//
Procedure ConfigureCharacteristicsAttributesSetClick(Item)
	
	If Not ValueIsFilled(Object.SetOfCharacteristicProperties) Then
		
		QuestionText = NStr("en = 'You can edit properties only after saving. Do you wish to save?'");
		
		Notification = New NotifyDescription("ConfigureSetOfPropertiesCharacteristicsClickEnd", ThisForm);
		ShowQueryBox(Notification, QuestionText, QuestionDialogMode.OKCancel,, DialogReturnCode.Cancel, 
			NStr("en = 'Edit properties'"));
		
		Return;
		
	EndIf;
	
	OpenAdditionalSetsForm(Object.SetOfCharacteristicProperties);
	
EndProcedure

&AtClient
Procedure ConfigureAttributesSetClick(Item)
	
	If Not ValueIsFilled(Object.PropertySet) Then
		
		QuestionText = NStr("en = 'You can edit attributes only after saving. Do you wish to save?'");
		
		Notification = New NotifyDescription("ConfigurePropertySetClickEnd", ThisForm);
		ShowQueryBox(Notification, QuestionText, QuestionDialogMode.OKCancel,, DialogReturnCode.Cancel, 
			NStr("en = 'Edit attributes'"));
		
		Return;
		
	EndIf;
	
	OpenAdditionalSetsForm(Object.PropertySet);

EndProcedure

#EndRegion

#Region NotificationHandlers

&AtClient
Procedure ConfigureSetOfPropertiesCharacteristicsClickEnd(Response, Parameters) Export
	
	If Response = DialogReturnCode.Cancel
		OR Not Write() Then
			Return;
	EndIf;
	
	OpenAdditionalSetsForm(Object.SetOfCharacteristicProperties);
	
EndProcedure

&AtClient
Procedure ConfigurePropertySetClickEnd(Response, Parameters) Export
	
	If Response = DialogReturnCode.Cancel Then
		Return;
	EndIf;
	
	If Not Write() Then
		Return;
	EndIf;
	
	OpenAdditionalSetsForm(Object.PropertySet);
	
EndProcedure

&AtClient
Procedure OpenAdditionalSetsForm(CurrentSet)
	OpenForm("Catalog.AdditionalAttributesAndInformationSets.ListForm", New Structure("CurrentSet", CurrentSet));	
EndProcedure

#EndRegion

#Region LibrariesHandlers

// StandardSubsystems.AdditionalReportsAndDataProcessors
&AtClient
Procedure Attachable_ExecuteAssignedCommand(Command)
	If Not AdditionalReportsAndDataProcessorsClient.ExecuteAllocatedCommandAtClient(ThisForm, Command.Name) Then
		ExecutionResult = Undefined;
		AdditionalReportsAndProcessingsExecuteAllocatedCommandAtServer(Command.Name, ExecutionResult);
		AdditionalReportsAndDataProcessorsClient.ShowCommandExecutionResult(ThisForm, ExecutionResult);
	EndIf;
EndProcedure

&AtServer
Procedure AdditionalReportsAndProcessingsExecuteAllocatedCommandAtServer(ItemName, ExecutionResult)
	AdditionalReportsAndDataProcessors.ExecuteAllocatedCommandAtServer(ThisForm, ItemName, ExecutionResult);
EndProcedure
// End StandardSubsystems.AdditionalReportsAndDataProcessors

// StandardSubsystems.Printing
&AtClient
Procedure Attachable_ExecutePrintCommand(Command)
	PrintManagementClient.ExecuteConnectedPrintCommand(Command, ThisObject, Object);
EndProcedure
// End StandardSubsystems.Printing

#EndRegion

