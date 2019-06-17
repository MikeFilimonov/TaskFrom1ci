
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Key.IsEmpty() Then
		ContactInformationDrive.OnCreateOnReadAtServer(ThisObject);
	EndIf;
	
	DriveClientServer.SetPictureForComment(Items.GroupComment, Object.Comment);
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.Properties
	PropertiesManagement.OnCreateAtServer(ThisForm, Object, "GroupAdditionalAttributes");
	// End StandardSubsystems.Properties
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	ContactInformationDrive.OnCreateOnReadAtServer(ThisObject);
	
	// StandardSubsystems.Properties
	PropertiesManagement.OnReadAtServer(ThisForm, CurrentObject);
	// End StandardSubsystems.Properties
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	// Mechanism handler "Properties".
	If PropertiesManagementClient.ProcessAlerts(ThisForm, EventName, Parameter) Then
		UpdateAdditionalAttributesItems();
	EndIf;
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	ContactInformationDrive.BeforeWriteAtServer(ThisObject, CurrentObject);
	
	// Mechanism handler "Properties".
	PropertiesManagement.BeforeWriteAtServer(ThisForm, CurrentObject);
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	ContactInformationDrive.FillCheckProcessingAtServer(ThisObject, Cancel);
	
	// StandardSubsystems.Properties
	PropertiesManagement.FillCheckProcessing(ThisForm, Cancel, CheckedAttributes);
	// End StandardSubsystems.Properties
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	// StandardSubsystems.PerformanceMeasurement
	PerformanceEstimationClientServer.StartTimeMeasurement("CatalogIndividualsWrite");
	// StandardSubsystems.PerformanceMeasurement
	
	Object.Description = Object.FirstName + ?(ValueIsFilled(Object.MiddleName), " " + Object.MiddleName, "")+ ?(ValueIsFilled(Object.LastName), " " + Object.LastName, "");
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	DriveClientServer.SetPictureForComment(Items.GroupComment, Object.Comment);
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	Notify("Write_Individuals", Object.Ref)
	
EndProcedure

#EndRegion

#Region ContactInformationDrive

&AtServer
Procedure AddContactInformationServer(AddingKind, SetShowInFormAlways = False) Export
	
	ContactInformationDrive.AddContactInformation(ThisObject, AddingKind, SetShowInFormAlways);
	
EndProcedure

&AtClient
Procedure Attachable_ActionCIClick(Item)
	
	ContactInformationDriveClient.ActionCIClick(ThisObject, Item);
	
EndProcedure

&AtClient
Procedure Attachable_PresentationCIOnChange(Item)
	
	ContactInformationDriveClient.PresentationCIOnChange(ThisObject, Item);
	
EndProcedure

&AtClient
Procedure Attachable_PresentationCIStartChoice(Item, ChoiceData, StandardProcessing)
	
	ContactInformationDriveClient.PresentationCIStartChoice(ThisObject, Item, ChoiceData, StandardProcessing);
	
EndProcedure

&AtClient
Procedure Attachable_PresentationCIClearing(Item, StandardProcessing)
	
	ContactInformationDriveClient.PresentationCIClearing(ThisObject, Item, StandardProcessing);
	
EndProcedure

&AtClient
Procedure Attachable_CommentCIOnChange(Item)
	
	ContactInformationDriveClient.CommentCIOnChange(ThisObject, Item);
	
EndProcedure

&AtClient
Procedure Attachable_ContactInformationDriveExecuteCommand(Command)
	
	ContactInformationDriveClient.ExecuteCommand(ThisObject, Command);
	
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

// StandardSubsystems.Properties
&AtClient
Procedure Attachable_EditContentOfProperties(Command)
	
	PropertiesManagementClient.EditContentOfProperties(ThisForm, Object.Ref);
	
EndProcedure

&AtServer
Procedure UpdateAdditionalAttributesItems()
	
	PropertiesManagement.UpdateAdditionalAttributesItems(ThisForm, FormAttributeToValue("Object"));
	
EndProcedure

// End StandardSubsystems.Properties

#EndRegion

