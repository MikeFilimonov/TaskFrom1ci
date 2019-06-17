
#Region ProcedureFormEventHandlers

// Procedure - event handler OnCreateAtServer of the form.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	ResourcesList.Parameters.SetParameterValue("CompanyResourceType", Object.Ref);
	
	// Delete prohibition from the All resources kind content.
	If Object.Ref = Catalogs.CompanyResourceTypes.AllResources Then
		Items.ResourcesList.CommandBar.ChildItems.ResourcesListDelete.Enabled = False;
		Items.ResourcesList.ContextMenu.ChildItems.ResourcesListContextMenuDelete.Enabled = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "Record_CompanyResourceTypes" Then
		
		ResourcesList.Parameters.SetParameterValue("CompanyResourceType", Object.Ref);
		
	EndIf;
	
EndProcedure

#Region EventsHandlersOfListForm

// Procedure - Change event handler of the ResourcesList form list.
//
&AtClient
Procedure ListChange(Command)
	
	If Not ValueIsFilled(Object.Ref) Then
		Message = New UserMessage();
		Message.Text = NStr("en = 'The data is not written yet.'");
		Message.Message();
	Else
		OpenParameters = New Structure;
		OpenParameters.Insert("Key", Items.ResourcesList.CurrentRow);
		OpenParameters.Insert("AvailabilityOfKind", False);
		If Items.ResourcesList.CurrentRow = Undefined Then
			OpenParameters.Insert("ValueCompanyResourceType", Object.Ref);
		EndIf;
		OpenForm("InformationRegister.CompanyResourceTypes.RecordForm", OpenParameters);
		
	EndIf;
	
EndProcedure

// Procedure - BeforeAddingBegin event handler of the ResourcesList form list.
//
&AtClient
Procedure ResourcesListBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	Cancel = True;
	If Not ValueIsFilled(Object.Ref) Then
		Message = New UserMessage();
		Message.Text = NStr("en = 'The data is not written yet.'");
		Message.Message();
	Else
		OpenParameters = New Structure;
		OpenParameters.Insert("AvailabilityOfKind", False);
		OpenParameters.Insert("ValueCompanyResourceType", Object.Ref);
		OpenForm("InformationRegister.CompanyResourceTypes.RecordForm", OpenParameters, Item);
	EndIf;
	
EndProcedure

// Procedure - Selection event handler of the ResourcesList form list.
//
&AtClient
Procedure ResourcesListSelection(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	OpenParameters = New Structure;
	OpenParameters.Insert("Key", Items.ResourcesList.CurrentRow);
	OpenParameters.Insert("AvailabilityOfKind", False);
	OpenForm("InformationRegister.CompanyResourceTypes.RecordForm", OpenParameters);
	
EndProcedure

// Procedure - BeforeDelete event handler of the ResourcesList form list.
//
&AtClient
Procedure ResourcesListBeforeDeleteRow(Item, Cancel)
	
	If Object.Ref = PredefinedValue("Catalog.CompanyResourceTypes.AllResources") Then
		MessageText = NStr("en = 'Object is not deleted as the company resource should be included in the ""All resources"" kind.'");
		DriveClient.ShowMessageAboutError(Object, MessageText, , , , Cancel);
	EndIf;
	
EndProcedure

// Procedure - AfterDeletion event handler of the ResourcesList form list.
//
&AtClient
Procedure ResourcesListAfterDeleteRow(Item)
	
	Notify("Record_CompanyResourceTypes");
	
EndProcedure

#EndRegion

#EndRegion
