#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Key.IsEmpty() Then
		ContactInformationDrive.OnCreateOnReadAtServer(ThisObject);
	EndIf;
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	ContactInformationDrive.OnCreateOnReadAtServer(ThisObject);
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	ContactInformationDrive.BeforeWriteAtServer(ThisObject, CurrentObject);
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	ContactInformationDrive.FillCheckProcessingAtServer(ThisObject, Cancel);
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	If NOT CheckByIsDefault() Then
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Default shipping address for %1 already exists.'"),
			Object.Owner);
		CommonUseClientServer.MessageToUser(MessageText,,,,Cancel);
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Function CheckByIsDefault()
	
	If NOT Object.IsDefault Then
		Return True;
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	TRUE AS Field1
	|FROM
	|	Catalog.ShippingAddresses AS ShippingAddresses
	|WHERE
	|	ShippingAddresses.Owner = &Owner
	|	AND ShippingAddresses.Ref <> &Ref
	|	AND ShippingAddresses.IsDefault";
	
	Query.SetParameter("Owner", Object.Owner);
	Query.SetParameter("Ref", Object.Ref);
	
	Return Query.Execute().IsEmpty();
	
EndFunction

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