﻿
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	If Parameters.ChoiceMode Then
		StandardSubsystemsServer.SetFormPurposeKey(ThisObject, "PickupSelection");
	EndIf;
	
	Items.List.ChoiceMode = Parameters.ChoiceMode;
	
	ParentOfPersonalAccessGroups = Catalogs.AccessGroups.ParentOfPersonalAccessGroups(True);
	
	SimplifiedInterfaceOfAccessRightsSettings = AccessManagementService.SimplifiedInterfaceOfAccessRightsSettings();
	
	If SimplifiedInterfaceOfAccessRightsSettings Then
		Items.FormCreate.Visible = False;
		Items.FormCopy.Visible = False;
		Items.ListContextMenuCreate.Visible = False;
		Items.ListContextMenuCopy.Visible = False;
	EndIf;
	
	List.Parameters.SetParameterValue("Profile", Parameters.Profile);
	If ValueIsFilled(Parameters.Profile) Then
		Items.Profile.Visible = False;
		Items.List.Representation = TableRepresentation.List;
		AutoTitle = False;
		
		Title = NStr("en = 'Access groups'");
		
		Items.FormCreateFolder.Visible = False;
		Items.ListContextMenuCreateGroup.Visible = False;
	EndIf;
	
	If Not AccessRight("Read", Metadata.Catalogs.AccessGroupsProfiles) Then
		Items.Profile.Visible = False;
	EndIf;
	
	If AccessRight("view", Metadata.Catalogs.ExternalUsers) Then
		List.QueryText = StrReplace(
			List.QueryText,
			"&ErrorObjectNotFound",
			"IsNULL(CAST(AccessGroups.User AS Catalog.ExternalUsers).Description, &ErrorObjectNotFound)");
	EndIf;
	
	InaccessibleGroupList = New ValueList;
	
	If Not Users.InfobaseUserWithFullAccess() Then
		// Hide access group Administrators.
		CommonUseClientServer.SetFilterDynamicListItem(
			List, "Ref", Catalogs.AccessGroups.Administrators,
			DataCompositionComparisonType.NotEqual, , True);
	EndIf;
	
	ChoiceMode = Parameters.ChoiceMode;
	
	List.Parameters.SetParameterValue(
		"ErrorObjectNotFound",
		NStr("en = '<Object not found>'"));
	
	If Parameters.ChoiceMode Then
		
		WindowOpeningMode = FormWindowOpeningMode.LockOwnerWindow;
		
		// Filter of items not marked for deletion.
		CommonUseClientServer.SetFilterDynamicListItem(
			List, "DeletionMark", False, , , True,
			DataCompositionSettingsItemViewMode.Normal);
		
		Items.List.ChoiceMode = True;
		Items.List.ChoiceFoldersAndItems = Parameters.ChoiceFoldersAndItems;
		
		AutoTitle = False;
		If Parameters.CloseOnChoice = False Then
			// Choice mode.
			Items.List.Multiselect = True;
			Items.List.SelectionMode = TableSelectionMode.MultiRow;
			
			Title = NStr("en = 'Select access groups'");
		Else
			Title = NStr("en = 'Select access group'");
			Items.FormChoose.DefaultButton = False;
		EndIf;
	EndIf;
EndProcedure

#EndRegion

#Region FormTableItemsEventsHandlersList

&AtClient
Procedure ListOnActivateRow(Item)
	
	If Items.List.CurrentData <> Undefined
		AND Items.List.CurrentData.Property("User")
		AND Items.List.CurrentData.Property("Ref") Then
		
		TransferAvailable = Not ValueIsFilled(Items.List.CurrentData.User)
		                  AND Items.List.CurrentData.Ref <> ParentOfPersonalAccessGroups;
		
		If Items.Find("FormMoveItem") <> Undefined Then
			Items.FormMoveItem.Enabled = TransferAvailable;
		EndIf;
		
		If Items.Find("ListContextMenuTransferItem") <> Undefined Then
			Items.ListContextMenuTransferItem.Enabled = TransferAvailable;
		EndIf;
		
		If Items.Find("ListMoveItem") <> Undefined Then
			Items.ListMoveItem.Enabled = TransferAvailable;
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure ValueChoiceList(Item, Value, StandardProcessing)
	
	If Value = ParentOfPersonalAccessGroups Then
		StandardProcessing = False;
		ShowMessageBox(, NStr("en = 'This folder can contain only personal access groups.'"));
	EndIf;
	
EndProcedure

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	If Parent = ParentOfPersonalAccessGroups Then
		
		Cancel = True;
		
		If Group Then
			ShowMessageBox(, NStr("en = 'This folder cannot contain subfolders.'"));
			
		ElsIf SimplifiedInterfaceOfAccessRightsSettings Then
			ShowMessageBox(,
				NStr("en = 'Cannot create a personal access group.
				     |To create a personal access group, use the ""Access rights"" window.'"));
		Else
			ShowMessageBox(, NStr("en = 'Personal access groups are not available.'"));
		EndIf;
		
	ElsIf Not Group
	        AND SimplifiedInterfaceOfAccessRightsSettings Then
		
		Cancel = True;
		
		ShowMessageBox(,
			NStr("en = 'To create a personal access group, use the ""Access rights"" window.'"));
	EndIf;
	
EndProcedure

&AtClient
Procedure ListDrag(Item, DragParameters, StandardProcessing, String, Field)
	
	If String = ParentOfPersonalAccessGroups Then
		StandardProcessing = False;
		ShowMessageBox(, NStr("en = 'This folder can contain only personal access groups.'"));
		
	ElsIf DragParameters.Value = ParentOfPersonalAccessGroups Then
		StandardProcessing = False;
		ShowMessageBox(, NStr("en = 'Cannot move the personal access groups folder.'"));
	EndIf;
	
EndProcedure

#EndRegion