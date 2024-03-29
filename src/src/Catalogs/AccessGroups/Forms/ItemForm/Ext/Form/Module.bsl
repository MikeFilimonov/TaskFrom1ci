﻿
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	// Auxiliary data preparation.
	AccessManagementService.OnCreateAtServerAllowedValuesEditingForms(ThisObject);
	
	InitialSettingOnReadAndCreate(Object);
	
	CatalogExternalUsersEnabled = AccessRight(
		"view", Metadata.Catalogs.ExternalUsers);
	
	ListOfUserTypes.Add(Type("CatalogRef.Users"));
	
	ListOfUserTypes.Add(Type("CatalogRef.ExternalUsers"));
	
	// Filling the list of users type selection.
	FillListOfUserTypes();
	
	// Setting constant property accessibility.
	
	// Defining the necessity to configure the settings of access limit.
	If Not AccessManagement.UseRowLevelSecurity() Then
		Items.Access.Visible = False;
	EndIf;
	
	// Setting the accessibility on opening the form for view only.
	Items.UsersFill.Enabled                = Not ReadOnly;
	Items.ContextMenuUsersSelect.Enabled = Not ReadOnly;
	
	If CommonUseReUse.DataSeparationEnabled()
		AND Object.Ref = Catalogs.AccessGroups.Administrators Then
		
		ActionsWithServiceUser = Undefined;
		AccessManagementService.WhenUserActionService(ActionsWithServiceUser);
		
		If Not ActionsWithServiceUser.ChangeAdmininstrativeAccess Then
			Raise
				NStr("en = 'You do not have enough rights to edit the Administrators group.'");
		EndIf;
	EndIf;
	
	CompletedProcedureOnCreateAtServer = True;
	
	If ClientApplication.CurrentInterfaceVariant() = ClientApplicationInterfaceVariant.Version8_2 Then
		Items.UsersAdd.OnlyInAllActions = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If QuestionAnswerOnOpenForms = "SetViewOnly" Then
		QuestionAnswerOnOpenForms = "";
		ReadOnly = True;
	EndIf;
	
	If QuestionAnswerOnOpenForms = "SetProfileAdministrator" Then
		QuestionAnswerOnOpenForms = Undefined;
		Object.Profile = PredefinedValue("Catalog.AccessGroupsProfiles.Administrator");
		Modified = True;
		
	ElsIf Object.Ref = PredefinedValue("Catalog.AccessGroups.Administrators")
		    AND Object.Profile <> PredefinedValue("Catalog.AccessGroupsProfiles.Administrator") Then
		
		Cancel = True;
		ShowQueryBox(
			New NotifyDescription("OnOpenAfterSettingAdministratorProfileConfirmation", ThisObject),
			NStr("en = 'The Administrators access group does not have the Administrator profile.
			     |
			     |Do you want to set the Administrators profile for this group? If you click No, the group will be opened in read-only mode.'"),
			QuestionDialogMode.YesNo,
			,
			DialogReturnCode.No);
	Else
		If QuestionAnswerOnOpenForms = "UpdateContentOfAccessKinds" Then
			QuestionAnswerOnOpenForms = "";
			UpdateContentOfAccessKinds();
			ChangedContentOfAccessKindsOnRead = False;
			
		ElsIf Not ReadOnly AND ChangedContentOfAccessKindsOnRead Then
			
			Cancel = True;
			ShowQueryBox(
				New NotifyDescription("OnOpenAfterUpdateConfirmationAccessKinds", ThisObject),
				NStr("en = 'The access restrictions of the access group profile were changed.
				     |
				     |Do you want to update the access restrictions in the access group? If you click No, the group will be opened in read-only mode.'"),
				QuestionDialogMode.YesNo,
				,
				DialogReturnCode.No);
		
		ElsIf Not ReadOnly
			   AND Not ValueIsFilled(Object.Ref)
			   AND TypeOf(FormOwner) = Type("FormTable")
			   AND FormOwner.Parent.Parameters.Property("Profile") Then
			
			If ValueIsFilled(FormOwner.Parent.Parameters.Profile) Then
				Object.Profile = FormOwner.Parent.Parameters.Profile;
				AttachIdleHandler("IdleHandlerProfileOnChange", 0.1, True);
			EndIf;
		EndIf;
	EndIf;
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	If Not CompletedProcedureOnCreateAtServer Then
		Return;
	EndIf;
	
	AccessManagementService.OnRereadingOnFormServerAllowedValuesEditing(ThisObject, CurrentObject);
	
	InitialSettingOnReadAndCreate(CurrentObject);
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	If StandardSubsystemsClientReUse.ClientWorkParameters().DataSeparationEnabled
	   AND Object.Ref = PredefinedValue("Catalog.AccessGroups.Administrators")
	   AND ServiceUserPassword = Undefined Then
		
		Cancel = True;
		StandardSubsystemsClient.WhenPromptedForPasswordForAuthenticationToService(
			New NotifyDescription("BeforeWriteContinuation", ThisObject, WriteParameters),
			ThisObject,
			ServiceUserPassword);
		Return;
	EndIf;
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	If Not Users.InfobaseUserWithFullAccess() Then
		// Responsible person can not change anything, but the content of users.
		// IN order to prevent the change of access group
		// on client in the forbidden parts the object is read repeatedly.
		RestoreObjectWithoutUserGroupsMembers(CurrentObject);
	EndIf;
	
	CurrentObject.Users.Clear();
	
	If CurrentObject.Ref <> Catalogs.AccessGroups.Administrators
	   AND ValueIsFilled(CurrentObject.User) Then
		
		If UsePersonalAccess Then
			CurrentObject.Users.Add().User = CurrentObject.User;
		EndIf;
	Else
		For Each Item In GroupUsers.GetItems() Do
			CurrentObject.Users.Add().User = Item.User;
		EndDo;
	EndIf;
	
	If CurrentObject.Ref = Catalogs.AccessGroups.Administrators Then
		Object.Responsible = Undefined;
	EndIf;
	
	If CommonUseReUse.DataSeparationEnabled()
		AND Object.Ref = Catalogs.AccessGroups.Administrators Then
		
		CurrentObject.AdditionalProperties.Insert(
			"ServiceUserPassword", ServiceUserPassword);
	EndIf;
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	SetPrivilegedMode(True);
	
	ProfileIsMarkedForDelete = CommonUse.ObjectAttributeValue(
		Object.Profile, "DeletionMark") = True;
	
	SetPrivilegedMode(False);
	
	If Not Object.DeletionMark AND ProfileIsMarkedForDelete Then
		WriteParameters.Insert("NotifyThatTheProfileIsMarkedForDeletion");
	EndIf;
	
	AccessManagementService.AfterWriteOnServerAllowedValuesEditingForms(
		ThisObject, CurrentObject, WriteParameters);
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	Notify("Record_AccessGroups", New Structure, Object.Ref);
	
	If WriteParameters.Property("NotifyThatTheProfileIsMarkedForDeletion") Then
		
		ShowMessageBox(,
			NStr("en = 'The access group does not grant any rights to its members because its profile is marked for deletion.
			     |Select a different profile.'"));
	EndIf;
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	CheckedObjectAttributes = New Array;
	Errors = Undefined;
	
	// Checking blank and duplicate users.
	CheckedObjectAttributes.Add("Users.User");
	TreeOfUsersRows = FormAttributeToValue("GroupUsers").Rows;
	ErrorsCount = ?(Errors = Undefined, 0, Errors.Count());
	
	// Data preparation to check match types of the authorization objects.
	If Object.UsersType <> Undefined Then
		Query = New Query;
		Query.SetParameter(
			"Users", TreeOfUsersRows.UnloadColumn("User"));
		Query.Text =
		"SELECT
		|	ExternalUsers.Ref AS User,
		|	ExternalUsers.AuthorizationObject AS TypeOfAuthorizationObjects
		|FROM
		|	Catalog.ExternalUsers AS ExternalUsers
		|WHERE
		|	ExternalUsers.Ref IN(&Users)
		|
		|UNION ALL
		|
		|SELECT
		|	ExternalUserGroups.Ref,
		|	ExternalUserGroups.TypeOfAuthorizationObjects
		|FROM
		|	Catalog.ExternalUserGroups AS ExternalUserGroups
		|WHERE
		|	ExternalUserGroups.Ref IN(&Users)";
		SetPrivilegedMode(True);
		TypesOfObjectsUsersAuthorization = Query.Execute().Unload();
		SetPrivilegedMode(False);
		TypesOfObjectsUsersAuthorization.Indexes.Add("User");
	EndIf;
	
	For Each CurrentRow In TreeOfUsersRows Do
		LineNumber = TreeOfUsersRows.IndexOf(CurrentRow);
		Participant = CurrentRow.User;
		
		// Checking existence of duplicate values.
		FoundValues = TreeOfUsersRows.FindRows(
			New Structure("User", CurrentRow.User));
		
		If FoundValues.Count() > 1 Then
			
			If TypeOf(CurrentRow.User) = Type("CatalogRef.Users") Then
				SingleErrorText      = NStr("en = 'User ""%2"" is duplicated.'");
				SeveralErrorText = NStr("en = 'Duplicate user ""%2"" in line %1.'");
				
			ElsIf TypeOf(CurrentRow.User) = Type("CatalogRef.ExternalUsers") Then
				SingleErrorText      = NStr("en = 'Duplicate external user ""%2"".'");
				SeveralErrorText = NStr("en = 'Duplicate external user ""%2"" in line %1.'");
				
			ElsIf TypeOf(CurrentRow.User) = Type("CatalogRef.UserGroups") Then
				SingleErrorText      = NStr("en = 'Duplicate user group ""%2"".'");
				SeveralErrorText = NStr("en = 'Duplicate user group ""%2"" in line %1.'");
			Else
				SingleErrorText      = NStr("en = 'Duplicate external user group ""%2"".'");
				SeveralErrorText = NStr("en = 'Duplicate external user group ""%2"" in line %1.'");
			EndIf;
			
			CommonUseClientServer.AddUserError(Errors,
				"GroupUsers[%1].User",
				ClarifyMessage(SingleErrorText, Participant),
				"GroupUsers",
				LineNumber,
				ClarifyMessage(SeveralErrorText, Participant));
		EndIf;
		
		// Check whether there are only users in the predefined Administrators group.
		If Object.Ref = Catalogs.AccessGroups.Administrators
		   AND TypeOf(CurrentRow.User) <> Type("CatalogRef.Users") Then
			
			If TypeOf(CurrentRow.User) = Type("CatalogRef.ExternalUsers") Then
				SingleErrorText      = NStr("en = 'The Administrators access group cannot contain external users. Remove external user ""%2"" from the Administrators group.'");
				SeveralErrorText = NStr("en = 'External user ""%2"" in line %1 is invalid in predefined group Administrators.'");
				
			ElsIf TypeOf(CurrentRow.User) = Type("CatalogRef.UserGroups") Then
				SingleErrorText      = NStr("en = 'The Administrators access group cannot contain user groups. Remove user group ""%2"" from the Administrators group.'");
				SeveralErrorText = NStr("en = 'The ""%2"" user group in line %1 is invalid in predefined access group Administrators.'");
			Else
				SingleErrorText      = NStr("en = 'The Administrators access group cannot contain external user groups. Remove external user group ""%2"" from the Administrators group.'");
				SeveralErrorText = NStr("en = 'External user group ""%2"" in line %1 is invalid in predefined access group Administrators.'");
			EndIf;
			
			CommonUseClientServer.AddUserError(Errors,
				"GroupUsers[%1].User",
				ClarifyMessage(SingleErrorText, Participant),
				"GroupUsers",
				LineNumber,
				ClarifyMessage(SeveralErrorText, Participant));
		EndIf;
		
		If Object.UsersType <> Undefined Then
			// Check matching of the types of authorization objects
			// of external users and external users group with the users type in the access group.
			SingleErrorText = "";
			
			If TypeOf(CurrentRow.User) = Type("CatalogRef.Users") Then
				
				If TypeOf(Object.UsersType) <> Type("CatalogRef.Users") Then
					SingleErrorText      = NStr("en = 'The type of user ""%2"" does not match the specified member type. Change the member type or select another user.'");
					SeveralErrorText = NStr("en = 'The type of user ""%2"" in line %1 does not match the specified member type. Change the member type or select another user.'");
				EndIf;
				
			ElsIf TypeOf(CurrentRow.User) = Type("CatalogRef.UserGroups") Then
				
				If TypeOf(Object.UsersType) <> Type("CatalogRef.Users") Then
					SingleErrorText      = NStr("en = 'The type of user group ""%2"" does not match the specified member type. Change the member type or select another user.'");
					SeveralErrorText = NStr("en = 'The type of user group ""%2"" in line %1 does not match the specified member type. Change the member type or select another user.'");
				EndIf;
			Else
				DescriptionOfTheAuthorizationObjectType = TypesOfObjectsUsersAuthorization.Find(
					CurrentRow.User, "User");
				
				If TypeOf(CurrentRow.User) = Type("CatalogRef.ExternalUsers") Then
					
					If DescriptionOfTheAuthorizationObjectType = Undefined
					 OR TypeOf(Object.UsersType) <> TypeOf(DescriptionOfTheAuthorizationObjectType.TypeOfAuthorizationObjects) Then
						
						SingleErrorText      = NStr("en = 'The type of external user ""%2"" does not match the specified member type. Change the member type or select another user.'");
						SeveralErrorText = NStr("en = 'The type of external user ""%2"" in line %1 does not match the specified member type. Change the member type or select another user.'");
					EndIf;
				
				Else // External users group.
					
					If DescriptionOfTheAuthorizationObjectType = Undefined
					 OR TypeOf(Object.UsersType) = Type("CatalogRef.Users")
					 OR DescriptionOfTheAuthorizationObjectType.TypeOfAuthorizationObjects <> Undefined
					   AND TypeOf(Object.UsersType) <> TypeOf(DescriptionOfTheAuthorizationObjectType.TypeOfAuthorizationObjects) Then
						
						SingleErrorText      = NStr("en = 'The type of external user group ""%2"" does not match the specified member type. Change the member type or select another user.'");
						SeveralErrorText = NStr("en = 'The type of external user group ""%2"" in line %1 does not match the specified member type. Change the member type or select another user.'");
					EndIf;
				EndIf;
			EndIf;
			
			If ValueIsFilled(SingleErrorText) Then
				CommonUseClientServer.AddUserError(Errors,
					"GroupUsers[%1].User",
					ClarifyMessage(SingleErrorText, Participant),
					"GroupUsers",
					LineNumber,
					ClarifyMessage(SeveralErrorText, Participant));
			EndIf;
		EndIf;
		
	EndDo;
	
	If Not CommonUseReUse.DataSeparationEnabled()
		AND Object.Ref = Catalogs.AccessGroups.Administrators Then
		
		ErrorDescription = "";
		AccessManagementService.CheckEnabledOfUserAccessAdministratorsGroupIB(
			GroupUsers.GetItems(), ErrorDescription);
		
		If ValueIsFilled(ErrorDescription) Then
			CommonUseClientServer.AddUserError(Errors,
				"GroupUsers", ErrorDescription, "");
		EndIf;
	EndIf;
	
	// Check of unfilled and repetitive access values.
	SkipCheckingKindsAndValues = False;
	If ErrorsCount <> ?(Errors = Undefined, 0, Errors.Count()) Then
		SkipCheckingKindsAndValues = True;
		Items.UsersAndAccess.CurrentPage = Items.GroupUsers;
	EndIf;
	
	AccessManagementServiceClientServer.AllowedValuesEditFormFillCheckProcessingAtServerProcessor(
		ThisObject, Cancel, CheckedObjectAttributes, Errors, SkipCheckingKindsAndValues);
	
	CommonUseClientServer.ShowErrorsToUser(Errors, Cancel);
	
	CheckedAttributes.Delete(CheckedAttributes.Find("Object"));
	CurrentObject = FormAttributeToValue("Object");
	
	CurrentObject.AdditionalProperties.Insert(
		"CheckedObjectAttributes", CheckedObjectAttributes);
	
	If Not CurrentObject.CheckFilling() Then
		Cancel = True;
	EndIf;
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure ProfileOnChange(Item)
	
	ProfileOnChangeAtServer();
	
EndProcedure

&AtClient
Procedure UsersTypePresentationStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	ShowChooseFromList(
		New NotifyDescription("UsersTypePresentationStartChoiceEnd", ThisObject),
		UserTypes,
		Item,
		UserTypes.FindByValue(Object.UsersType));
	
EndProcedure

&AtClient
Procedure UsersTypePresentationClearing(Item, StandardProcessing)
	
	StandardProcessing = False;
	
EndProcedure

&AtClient
Procedure UserOwnerStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
EndProcedure

#EndRegion

#Region FormTableItemsEventsHandlersUsers

&AtClient
Procedure UsersOnChange(Item)
	
	Modified = True;
	
EndProcedure

&AtClient
Procedure UsersBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	If Copy Then
		
		If Item.CurrentData.GetParent() <> Undefined Then
			Cancel = True;
			
			Items.Users.CurrentRow =
				Item.CurrentData.GetParent().GetID();
			
			Items.Users.CopyRow();
		EndIf;
		
	ElsIf Items.Users.CurrentRow <> Undefined Then
		Cancel = True;
		Items.Users.CopyRow();
	EndIf;
	
EndProcedure

&AtClient
Procedure UsersBeforeRowChange(Item, Cancel)
	
	If Item.CurrentData.GetParent() <> Undefined Then
		Cancel = True;
		
		Items.Users.CurrentRow =
			Item.CurrentData.GetParent().GetID();
		
		Items.Users.ChangeRow();
	EndIf;
	
EndProcedure

&AtClient
Procedure UsersBeforeDeleteRow(Item, Cancel)
	
	ParentRow = Item.CurrentData.GetParent();
	
	If ParentRow <> Undefined Then
		Cancel = True;
		
		If TypeOf(ParentRow.User) =
		        Type("CatalogRef.UserGroups") Then
			
			ShowMessageBox(,
				NStr("en = 'Cannot remove users directly from the list.
				     |They are user group members that are displayed for reference only.
				     |To remove a user from the list, remove it from the user group that is a part of the list.'"));
		Else
			ShowMessageBox(,
				NStr("en = 'Cannot remove external users directly from the list.
				     |They are external user group members that are displayed for reference only.
				     |To remove an external user from the list, remove it from the external user group that is a part of the list.'"));
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure UsersOnStartEdit(Item, NewRow, Copy)
	
	If Copy Then
		Item.CurrentData.User = Undefined;
	EndIf;
	
	If Item.CurrentData.User = Undefined Then
		Item.CurrentData.PictureNumber = -1;
		Item.CurrentData.User = PredefinedValue(
			"Catalog.Users.EmptyRef");
	EndIf;
	
EndProcedure

&AtClient
Procedure UsersOnEditEnd(Item, NewRow, CancelEdit)
	
	If NewRow
	   AND Item.CurrentData <> Undefined
	   AND Item.CurrentData.User = PredefinedValue(
	     	"Catalog.Users.EmptyRef") Then
		
		Item.CurrentData.User = Undefined;
	EndIf;
	
EndProcedure

&AtClient
Procedure UsersChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	HasChanges = False;
	If PickMode Then
		GroupUsers.GetItems().Clear();
	EndIf;
	ModifiedRows = New Array;
	
	If TypeOf(ValueSelected) = Type("Array") Then
		For Each Value In ValueSelected Do
			ValueNotFound = True;
			For Each Item In GroupUsers.GetItems() Do
				If Item.User = Value Then
					ValueNotFound = False;
					Break;
				EndIf;
			EndDo;
			If ValueNotFound Then
				NewItem = GroupUsers.GetItems().Add();
				NewItem.User = Value;
				ModifiedRows.Add(NewItem.GetID());
			EndIf;
		EndDo;
		
	ElsIf Item.CurrentData.User <> ValueSelected Then
		Item.CurrentData.User = ValueSelected;
		ModifiedRows.Add(Item.CurrentRow);
	EndIf;
	
	If ModifiedRows.Count() > 0 Then
		UpdatedLines = Undefined;
		UpdateGroupUsers(ModifiedRows, UpdatedLines);
		For Each RowID In UpdatedLines Do
			Items.Users.Expand(RowID);
		EndDo;
		Modified = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure UsersAfterDeleteRow(Item)
	
	// Setting of the tree displaying.
	ThereNested = False;
	For Each Item In GroupUsers.GetItems() Do
		If Item.GetItems().Count() > 0 Then
			ThereNested = True;
			Break;
		EndIf;
	EndDo;
	
	Items.Users.Representation =
		?(ThereNested, TableRepresentation.Tree, TableRepresentation.List);
	
EndProcedure

&AtClient
Procedure UserOnChange(Item)
	
	If ValueIsFilled(Items.Users.CurrentData.User) Then
		UpdateGroupUsers(Items.Users.CurrentRow);
		Items.Users.Expand(Items.Users.CurrentRow);
	Else
		Items.Users.CurrentData.PictureNumber = -1;
	EndIf;
	
EndProcedure

&AtClient
Procedure UserStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	SelectSelectUsers(False);
	PickMode = False;
	
EndProcedure

&AtClient
Procedure UserClearing(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	Items.Users.CurrentData.PictureNumber = -1;
	Items.Users.CurrentData.User  = PredefinedValue(
		"Catalog.Users.EmptyRef");
	
EndProcedure

&AtClient
Procedure UserTextEntryEnd(Item, Text, ChoiceData, StandardProcessing)
	
	If ValueIsFilled(Text) Then
		StandardProcessing = False;
		If Object.Ref = PredefinedValue("Catalog.AccessGroups.Administrators") Then
			ChoiceData = AccessManagementServiceServerCall.FormDataOfUserChoice(
				Text, False, False);
		Else
			ChoiceData = AccessManagementServiceServerCall.FormDataOfUserChoice(
				Text);
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure UserAutoCompleteText(Item, Text, ChoiceData, Wait, StandardProcessing)
	
	If ValueIsFilled(Text) Then
		StandardProcessing = False;
		If Object.Ref = PredefinedValue("Catalog.AccessGroups.Administrators") Then
			ChoiceData = AccessManagementServiceServerCall.FormDataOfUserChoice(
				Text, False, False);
		Else
			ChoiceData = AccessManagementServiceServerCall.FormDataOfUserChoice(
				Text);
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormTableItemsEventsHandlersAccessKinds

&AtClient
Procedure AccessKindSelection(Item, SelectedRow, Field, StandardProcessing)
	
	If Not ReadOnly Then
		Items.AccessKinds.ChangeRow();
	EndIf;
	
EndProcedure

&AtClient
Procedure AccessKindsOnActivateRow(Item)
	
	AccessManagementServiceClient.AccessKindsOnActivateRow(
		ThisObject, Item);
	
EndProcedure

&AtClient
Procedure AccessKindsOnActivateCell(Item)
	
	AccessManagementServiceClient.AccessKindsOnActivateCell(
		ThisObject, Item);
	
EndProcedure

&AtClient
Procedure AccessKindsOnStartEdit(Item, NewRow, Copy)
	
	AccessManagementServiceClient.AccessKindsOnStartEdit(
		ThisObject, Item, NewRow, Copy);
	
EndProcedure

&AtClient
Procedure AccessKindsOnEditEnd(Item, NewRow, CancelEdit)
	
	AccessManagementServiceClient.AccessKindsOnEditEnd(
		ThisObject, Item, NewRow, CancelEdit);
	
EndProcedure

#Region EventHandlersOfFormTableItemAllAllowedPresentationAccessKinds

&AtClient
Procedure AccessKindsAllAllowedPresentationOnChange(Item)
	
	AccessManagementServiceClient.AccessKindsAllAllowedPresentationOnChange(
		ThisObject, Item);
	
EndProcedure

&AtClient
Procedure AccessKindsAllAllowedPresentationChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	AccessManagementServiceClient.AccessKindsAllAllowedPresentationChoiceProcessing(
		ThisObject, Item, ValueSelected, StandardProcessing);
	
EndProcedure

#EndRegion

#EndRegion

#Region FormTableItemsEventsHandlersAccessValues

&AtClient
Procedure AccessValuesOnChange(Item)
	
	AccessManagementServiceClient.AccessValuesOnChange(
		ThisObject, Item);
	
EndProcedure

&AtClient
Procedure AccessValuesOnStartEdit(Item, NewRow, Copy)
	
	AccessManagementServiceClient.AccessValuesOnStartEdit(
		ThisObject, Item, NewRow, Copy);
	
EndProcedure

&AtClient
Procedure AccessValuesOnEditEnd(Item, NewRow, CancelEdit)
	
	AccessManagementServiceClient.AccessValuesOnEditEnd(
		ThisObject, Item, NewRow, CancelEdit);
	
EndProcedure

&AtClient
Procedure AccessValueStartChoice(Item, ChoiceData, StandardProcessing)
	
	AccessManagementServiceClient.AccessValueStartChoice(
		ThisObject, Item, ChoiceData, StandardProcessing);
	
EndProcedure

&AtClient
Procedure AccessValueChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	AccessManagementServiceClient.AccessValueChoiceProcessing(
		ThisObject, Item, ValueSelected, StandardProcessing);
	
EndProcedure

&AtClient
Procedure AccessValueClearing(Item, StandardProcessing)
	
	AccessManagementServiceClient.AccessValueClearing(
		ThisObject, Item, StandardProcessing);
	
EndProcedure

&AtClient
Procedure AccessValueAutoComplete(Item, Text, ChoiceData, Wait, StandardProcessing)
	
	AccessManagementServiceClient.AccessValueAutoComplete(
		ThisObject, Item, Text, ChoiceData, Wait, StandardProcessing);
	
EndProcedure

&AtClient
Procedure AccessValueTextEditEnd(Item, Text, ChoiceData, StandardProcessing)
	
	AccessManagementServiceClient.AccessValueTextEditEnd(
		ThisObject, Item, Text, ChoiceData, StandardProcessing);
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure Pick(Command)
	
	SelectSelectUsers(True);
	PickMode = True;
	
EndProcedure

&AtClient
Procedure ShowUnusedAccessKinds(Command)
	
	ShowUnusedAccessKindsAtServer();
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// Event handler continuation OnOpen.
&AtClient
Procedure OnOpenAfterSettingAdministratorProfileConfirmation(Response, NotSpecified) Export
	
	If Response = DialogReturnCode.Yes Then
		QuestionAnswerOnOpenForms = "SetProfileAdministrator";
	Else
		QuestionAnswerOnOpenForms = "SetViewOnly";
	EndIf;
	
	Open();
	
EndProcedure

// Event handler continuation OnOpen.
&AtClient
Procedure OnOpenAfterUpdateConfirmationAccessKinds(Response, NotSpecified) Export
	
	If Response = DialogReturnCode.Yes Then
		QuestionAnswerOnOpenForms = "UpdateContentOfAccessKinds";
	Else
		QuestionAnswerOnOpenForms = "SetViewOnly";
	EndIf;
	
	Open();
	
EndProcedure

// Event handler continuation BeforeWrite.
&AtClient
Procedure BeforeWriteContinuation(NewServiceUserPassword, WriteParameters) Export
	
	If NewServiceUserPassword = Undefined Then
		Return;
	EndIf;
	
	ServiceUserPassword = NewServiceUserPassword;
	
	Try
		
		Write(WriteParameters);
		
	Except
		
		ServiceUserPassword = Undefined;
		Raise;
		
	EndTry;
	
EndProcedure

// Event handler continuation UsersTypePresentationStartChoice.
&AtClient
Procedure UsersTypePresentationStartChoiceEnd(SelectedItem, NotSpecified) Export
	
	If SelectedItem <> Undefined
	   AND Object.UsersType <> SelectedItem.Value Then
		
		Modified = True;
		Object.UsersType        = SelectedItem.Value;
		UsersTypePresentation = SelectedItem.Presentation;
		
		If Object.UsersType <> Undefined Then
			DeleteNonTypicalUsers();
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure IdleHandlerProfileOnChange()
	
	ProfileOnChangeAtServer();
	
EndProcedure

&AtServer
Procedure InitialSettingOnReadAndCreate(CurrentObject)
	
	If CurrentObject.Ref <> Catalogs.AccessGroups.Administrators Then
		
		// Preparation for the personal access group mode.
		If ValueIsFilled(CurrentObject.User) Then
			
			AutoTitle = False;
			
			Title
				= CurrentObject.Description
				+ ": "
				+ CurrentObject.User
				+ " "
				+ NStr("en = '(Access group)'");
			
			Filter = New Structure("User", CurrentObject.User);
			FoundStrings = CurrentObject.Users.FindRows(Filter);
			UsePersonalAccess = FoundStrings.Count() > 0;
		Else
			AutoTitle = True;
		EndIf;
		
		UserFilled = ValueIsFilled(CurrentObject.User);
		
		Items.Description.ReadOnly                 = UserFilled;
		Items.Parent.ReadOnly                     = UserFilled;
		Items.Profile.ReadOnly                      = UserFilled;
		Items.PropertiesOfPersonalGroup.Visible        = UserFilled;
		Items.UsersTypePresentation.Visible    = Not UserFilled;
		Items.GroupUsers.Visible                = Not UserFilled;
		Items.ResponsibleForPersonalGroup.Visible = UserFilled;
		
		Items.UsersAndAccess.PagesRepresentation =
			?(UserFilled,
			  FormPagesRepresentation.None,
			  FormPagesRepresentation.TabsOnTop);
		
		Items.AccessKinds.TitleLocation =
			?(UserFilled,
			  FormItemTitleLocation.Top,
			  FormItemTitleLocation.None);
		
		Items.UsersTypePresentation.Visible
			= Not UserFilled
			AND (    ExternalUsers.UseExternalUsers()
			   OR   Object.UsersType <> Undefined
			       AND TypeOf(Object.UsersType) <> Type("CatalogRef.Users"));
		
		Items.UserOwner.ReadOnly
			= AccessManagementService.SimplifiedInterfaceOfAccessRightsSettings();
		
		// Preparation for the users editing mode who are responsible for the participants.
		If Not Users.InfobaseUserWithFullAccess() Then
			Items.Description.ReadOnly = True;
			Items.Parent.ReadOnly = True;
			Items.Profile.ReadOnly = True;
			Items.UsersTypePresentation.ReadOnly = True;
			Items.Access.ReadOnly = True;
			Items.Responsible.ReadOnly = True;
			Items.ResponsibleForPersonalGroup.ReadOnly = True;
			Items.Definition.ReadOnly = True;
		EndIf;
	Else
		Items.Description.ReadOnly                  = True;
		Items.Profile.ReadOnly                      = True;
		Items.PropertiesOfPersonalGroup.Visible     = False;
		Items.UsersTypePresentation.ReadOnly        = True;
		Items.Responsible.ReadOnly                  = True;
		Items.ResponsibleForPersonalGroup.Visible   = False;
		Items.Definition.ReadOnly                   = True;
		
		If Not AccessManagement.IsRole("FullRights") Then
			ReadOnly = True;
		EndIf;
	EndIf;
	
	UpdateContentOfAccessKinds(True);
	
	// Preparation of the users tree.
	UserTree = GroupUsers.GetItems();
	UserTree.Clear();
	For Each TSRow In CurrentObject.Users Do
		UserTree.Add().User = TSRow.User;
	EndDo;
	UpdateGroupUsers();
	
EndProcedure

&AtServer
Procedure ProfileOnChangeAtServer()
	
	UpdateContentOfAccessKinds();
	AccessManagementServiceClientServer.FillAccessKindsPropertiesInForm(ThisObject);
	
EndProcedure

&AtServer
Procedure FillListOfUserTypes()
	
	UserTypes.Add(
		Undefined,
		NStr("en = 'All users'"));
	
	UserTypes.Add(
		Catalogs.Users.EmptyRef(),
		NStr("en = 'Regular users'"));
	
	If UseExternalUsers Then
		
		TypesOfLinksAuthorizationObject =
			Metadata.Catalogs.ExternalUsers.Attributes.AuthorizationObject.Type.Types();
		
		For Each AuthorizationObjectRefType In TypesOfLinksAuthorizationObject Do
			
			TypeMetadata = Metadata.FindByType(AuthorizationObjectRefType);
			
			TypeArray = New Array;
			TypeArray.Add(AuthorizationObjectRefType);
			ReferenceTypeDescription = New TypeDescription(TypeArray);
			
			UserTypes.Add(
				ReferenceTypeDescription.AdjustValue(Undefined),
				StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = 'External users (%1)'"),
					TypeMetadata.Synonym));
		EndDo;
	EndIf;
	
	FoundItem = UserTypes.FindByValue(Object.UsersType);
	
	UsersTypePresentation =
		?(FoundItem = Undefined,
		  StringFunctionsClientServer.SubstituteParametersInString(
		      NStr("en = 'Unknown type ""%1""'"),
		      String(TypeOf(Object.UsersType))),
		  FoundItem.Presentation);
	
EndProcedure

&AtServer
Procedure DeleteNonTypicalUsers()
	
	If Object.UsersType = Undefined Then
		Return;
	EndIf;
	
	If TypeOf(Object.UsersType) = Type("CatalogRef.Users") Then
	
		IndexOf = Object.Users.Count()-1;
		While IndexOf >= 0 Do
			
			If TypeOf(Object.Users[IndexOf].User)
			     <> Type("CatalogRef.Users")
			   AND TypeOf(Object.Users[IndexOf].User)
			     <> Type("CatalogRef.UserGroups") Then
				
				Object.Users.Delete(IndexOf);
			EndIf;
			
			IndexOf = IndexOf - 1;
		EndDo;
	Else
		IndexOf = Object.Users.Count()-1;
		While IndexOf >= 0 Do
			
			If TypeOf(Object.Users[IndexOf].User)
			     <> Type("CatalogRef.ExternalUsers")
			   AND TypeOf(Object.Users[IndexOf].User)
			     <> Type("CatalogRef.ExternalUserGroups") Then
				
				Object.Users.Delete(IndexOf);
			EndIf;
			IndexOf = IndexOf - 1;
		EndDo;
		
		Query = New Query(
		"SELECT
		|	ExternalUsers.Ref
		|FROM
		|	Catalog.ExternalUsers AS ExternalUsers
		|WHERE
		|	VALUETYPE(ExternalUsers.AuthorizationObject) <> &TypeOfExternalUsers
		|	AND ExternalUsers.Ref IN(&ExternalUsersAndGroupsSelected)
		|
		|UNION ALL
		|
		|SELECT
		|	ExternalUserGroups.Ref
		|FROM
		|	Catalog.ExternalUserGroups AS ExternalUserGroups
		|WHERE
		|	ExternalUserGroups.TypeOfAuthorizationObjects <> UNDEFINED
		|	AND VALUETYPE(ExternalUserGroups.TypeOfAuthorizationObjects) <> &TypeOfExternalUsers
		|	AND ExternalUserGroups.Ref IN(&ExternalUsersAndGroupsSelected)");
		
		Query.SetParameter(
			"ExternalUsersAndGroupsSelected",
			Object.Users.Unload().UnloadColumn("User"));
		
		Query.SetParameter("TypeOfExternalUsers", TypeOf(Object.UsersType));
		
		Selection = Query.Execute().Select();
		
		While Selection.Next() Do
			Filter = New Structure("User", Selection.Ref);
			FoundStrings = Object.Users.FindRows(Filter);
			For Each FoundString In FoundStrings Do
				Object.Users.Delete(Object.Users.IndexOf(FoundString));
			EndDo;
		EndDo;
	EndIf;
	
EndProcedure

&AtServer
Procedure UpdateContentOfAccessKinds(Val OnReadAtServer = False)
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	AccessTypesProfile.AccessKind,
	|	AccessTypesProfile.Preset,
	|	AccessTypesProfile.AllAllowed
	|FROM
	|	Catalog.AccessGroupsProfiles.AccessKinds AS AccessTypesProfile
	|WHERE
	|	AccessTypesProfile.Ref = &Ref
	|	AND NOT AccessTypesProfile.Preset";
	
	Query.SetParameter("Ref", Object.Profile);
	
	SetPrivilegedMode(True);
	AccessTypesProfile = Query.Execute().Unload();
	SetPrivilegedMode(False);
	
	ContentOfAccessKindsChanged = False;
	
	// Adding of the missing access kinds.
	IndexOf = AccessTypesProfile.Count() - 1;
	While IndexOf >= 0 Do
		String = AccessTypesProfile[IndexOf];
		
		Filter = New Structure("AccessKind", String.AccessKind);
		AccessTypeProperties = AccessManagementService.AccessTypeProperties(String.AccessKind);
		
		If AccessTypeProperties = Undefined Then
			AccessTypesProfile.Delete(String);
		
		ElsIf Object.AccessKinds.FindRows(Filter).Count() = 0 Then
			ContentOfAccessKindsChanged = True;
			
			If OnReadAtServer Then
				Break;
			Else
				NewRow = Object.AccessKinds.Add();
				NewRow.AccessKind   = String.AccessKind;
				NewRow.AllAllowed = String.AllAllowed;
			EndIf;
		EndIf;
		IndexOf = IndexOf - 1;
	EndDo;
	
	// Deletion of the unnecessary access kinds.
	IndexOf = Object.AccessKinds.Count() - 1;
	While IndexOf >= 0 Do
		
		AccessKind = Object.AccessKinds[IndexOf].AccessKind;
		Filter = New Structure("AccessKind", AccessKind);
		
		PropertiesOfAccessKindInProfile = AccessTypesProfile.FindRows(Filter);
		AccessTypeProperties = AccessManagementService.AccessTypeProperties(AccessKind);
		
		If AccessTypeProperties = Undefined
		 OR AccessTypesProfile.FindRows(Filter).Count() = 0 Then
			
			ContentOfAccessKindsChanged = True;
			If OnReadAtServer Then
				Break;
			Else
				Object.AccessKinds.Delete(IndexOf);
				For Each CollectionItem In Object.AccessValues.FindRows(Filter) Do
					Object.AccessValues.Delete(CollectionItem);
				EndDo;
			EndIf;
		EndIf;
		IndexOf = IndexOf - 1;
	EndDo;
	
	Modified = Modified
		OR ContentOfAccessKindsChanged AND Not OnReadAtServer;
	
	// Enabling the check box to prompt the user's decision to update the content of the access kinds.
	If OnReadAtServer
	     AND Not Object.Ref.IsEmpty() // This is new.
	     AND ContentOfAccessKindsChanged
	     AND Users.InfobaseUserWithFullAccess() // Only administrator can update the access kinds.
	     AND CommonUse.ObjectAttributeValue(Object.Ref, "Profile") = Object.Profile Then
	     
		ChangedContentOfAccessKindsOnRead = True;
	EndIf;
	
	Items.Access.Enabled = Object.AccessKinds.Count() > 0;
	
	// Setting of access kinds order by a profile.
	If Not ChangedContentOfAccessKindsOnRead Then
		For Each TSRow In AccessTypesProfile Do
			Filter = New Structure("AccessKind", TSRow.AccessKind);
			IndexOf = Object.AccessKinds.IndexOf(Object.AccessKinds.FindRows(Filter)[0]);
			Object.AccessKinds.Move(IndexOf, AccessTypesProfile.IndexOf(TSRow) - IndexOf);
		EndDo;
	EndIf;
	
	If ContentOfAccessKindsChanged Then
		CurrentAccessType = Undefined;
	EndIf;
	
	AccessManagementServiceClientServer.FillAccessKindsPropertiesInForm(ThisObject);
	
EndProcedure

&AtServer
Procedure ShowUnusedAccessKindsAtServer()
	
	AccessManagementService.RefreshUnusedAccessKindsDisplay(ThisObject);
	
EndProcedure

&AtClient
Procedure ShowUsersTypeSelectionOrExternalUsers(ContinuationProcessor)
	
	SelectionAndPickOutOfExternalUsers = False;
	
	If Object.Ref = PredefinedValue("Catalog.AccessGroups.Administrators") Then
		ExecuteNotifyProcessing(ContinuationProcessor, SelectionAndPickOutOfExternalUsers);
		Return;
	EndIf;
	
	If Object.UsersType <> Undefined Then
		If TypeOf(Object.UsersType) <> Type("CatalogRef.Users") Then
			SelectionAndPickOutOfExternalUsers = True;
		EndIf;
		ExecuteNotifyProcessing(ContinuationProcessor, SelectionAndPickOutOfExternalUsers);
		Return;
	EndIf;
	
	If UseExternalUsers Then
		
		ListOfUserTypes.ShowChooseItem(
			New NotifyDescription(
				"ShowTypeSelectionUsersOrExternalUsersEnd",
				ThisObject,
				ContinuationProcessor),
			NStr("en = 'Select user type'"),
			ListOfUserTypes[0]);
	Else
		ExecuteNotifyProcessing(ContinuationProcessor, SelectionAndPickOutOfExternalUsers);
	EndIf;
	
EndProcedure

&AtClient
Procedure ShowTypeSelectionUsersOrExternalUsersEnd(SelectedItem, ContinuationProcessor) Export
	
	If SelectedItem <> Undefined Then
		SelectionAndPickOutOfExternalUsers =
			SelectedItem.Value = Type("CatalogRef.ExternalUsers");
		
		ExecuteNotifyProcessing(ContinuationProcessor, SelectionAndPickOutOfExternalUsers);
	Else
		ExecuteNotifyProcessing(ContinuationProcessor, Undefined);
	EndIf;
	
EndProcedure

&AtClient
Procedure SelectSelectUsers(Pick)
	
	CurrentUser = ?(Items.Users.CurrentData = Undefined,
		Undefined, Items.Users.CurrentData.User);
	
	If Not Pick
	   AND ValueIsFilled(CurrentUser)
	   AND (    TypeOf(CurrentUser) = Type("CatalogRef.Users")
	      OR TypeOf(CurrentUser) = Type("CatalogRef.UserGroups") ) Then
	
		SelectionAndPickOutOfExternalUsers = False;
	
	ElsIf Not Pick
	        AND UseExternalUsers
	        AND ValueIsFilled(CurrentUser)
	        AND (    TypeOf(CurrentUser) = Type("CatalogRef.ExternalUsers")
	           OR TypeOf(CurrentUser) = Type("CatalogRef.ExternalUserGroups") ) Then
	
		SelectionAndPickOutOfExternalUsers = True;
	Else
		ShowUsersTypeSelectionOrExternalUsers(
			New NotifyDescription("PickSelectUsersEnd", ThisObject, Pick));
		Return;
	EndIf;
	
	PickSelectUsersEnd(SelectionAndPickOutOfExternalUsers, Pick);
	
EndProcedure

&AtClient
Procedure PickSelectUsersEnd(SelectionAndPickOutOfExternalUsers, Pick) Export
	
	If SelectionAndPickOutOfExternalUsers = Undefined Then
		Return;
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("ChoiceMode", True);
	FormParameters.Insert("CurrentRow", ?(
		Items.Users.CurrentData = Undefined,
		Undefined,
		Items.Users.CurrentData.User));
	
	If Object.Ref <> PredefinedValue("Catalog.AccessGroups.Administrators") Then
		If SelectionAndPickOutOfExternalUsers Then
			FormParameters.Insert("ExternalUserGroupChoice", True);
		Else
			FormParameters.Insert("UserGroupChoice", True);
		EndIf;
	EndIf;
	
	If Pick Then
		FormParameters.Insert("CloseOnChoice", False);
		FormParameters.Insert("Multiselect", True);
		FormParameters.Insert("AdvancedSelection", True);
		FormParameters.Insert("AnExtendedFormOfSelectionOptions", SelectedMembersGroupAccess());
	EndIf;
	
	If SelectionAndPickOutOfExternalUsers Then
	
		If Object.UsersType <> Undefined Then
			FormParameters.Insert("TypeOfAuthorizationObjects", Object.UsersType);
		EndIf;
		If CatalogExternalUsersEnabled Then
			OpenForm("Catalog.ExternalUsers.ChoiceForm", FormParameters, Items.Users);
		Else
			ShowMessageBox(, NStr("en = 'You do not have enough rights to select external users.'"));
		EndIf;
	Else
		OpenForm("Catalog.Users.ChoiceForm", FormParameters, Items.Users);
	EndIf;
	
EndProcedure

&AtServer
Function SelectedMembersGroupAccess()
	
	CollectionItems = GroupUsers.GetItems();
	
	SelectedUsers = New ValueTable;
	SelectedUsers.Columns.Add("User");
	SelectedUsers.Columns.Add("PictureNumber");
	
	For Each Item In CollectionItems Do
		
		RowSelectedUsers = SelectedUsers.Add();
		RowSelectedUsers.User = Item.User;
		RowSelectedUsers.PictureNumber = Item.PictureNumber;
		
	EndDo;
	
	FormHeaderSelection = NStr("en = 'Select access group members'");
	AnExtendedFormOfSelectionOptions = New Structure("FormHeaderSelection, SelectedUsers",
	                                                   FormHeaderSelection, SelectedUsers);
	StorageAddress = PutToTempStorage(AnExtendedFormOfSelectionOptions);
	Return StorageAddress;
	
EndFunction

&AtServer
Procedure UpdateGroupUsers(RowID = Undefined,
                                     ModifiedRows = Undefined)
	
	SetPrivilegedMode(True);
	ModifiedRows = New Array;
	
	If RowID = Undefined Then
		CollectionItems = GroupUsers.GetItems();
		
	ElsIf TypeOf(RowID) = Type("Array") Then
		CollectionItems = New Array;
		For Each ID In RowID Do
			CollectionItems.Add(GroupUsers.FindByID(ID));
		EndDo;
	Else
		CollectionItems = New Array;
		CollectionItems.Add(GroupUsers.FindByID(RowID));
	EndIf;
	
	UserGroupsMembers = New Array;
	For Each Item In CollectionItems Do
		
		If TypeOf(Item.User) = Type("CatalogRef.UserGroups")
		 OR TypeOf(Item.User) = Type("CatalogRef.ExternalUserGroups") Then
		
			UserGroupsMembers.Add(Item.User);
		EndIf;
	EndDo;
	
	Query = New Query;
	Query.SetParameter("UserGroupsMembers", UserGroupsMembers);
	Query.Text =
	"SELECT
	|	UserGroupMembers.UsersGroup,
	|	UserGroupMembers.User
	|FROM
	|	InformationRegister.UserGroupMembers AS UserGroupMembers
	|WHERE
	|	UserGroupMembers.UsersGroup IN(&UserGroupsMembers)";
	
	UsersOfGroups = Query.Execute().Unload();
	UsersOfGroups.Indexes.Add("UsersGroup");
	
	For Each Item In CollectionItems Do
		Item.Ref = Item.User;
		
		If TypeOf(Item.User) = Type("CatalogRef.UserGroups")
		 OR TypeOf(Item.User) = Type("CatalogRef.ExternalUserGroups") Then
		
			// Filling the group users.
			OldUsers = Item.GetItems();
			Filter = New Structure("UsersGroup", Item.User);
			NewUsers = UsersOfGroups.FindRows(Filter);
			
			HasChanges = False;
			
			If OldUsers.Count() <> NewUsers.Count() Then
				OldUsers.Clear();
				For Each String In NewUsers Do
					NewItem = OldUsers.Add();
					NewItem.Ref       = String.User;
					NewItem.User = String.User;
				EndDo;
				HasChanges = True;
			Else
				IndexOf = 0;
				For Each String In OldUsers Do
					
					If String.Ref       <> NewUsers[IndexOf].User
					 OR String.User <> NewUsers[IndexOf].User Then
						
						String.Ref       = NewUsers[IndexOf].User;
						String.User = NewUsers[IndexOf].User;
						HasChanges = True;
					EndIf;
					IndexOf = IndexOf + 1;
				EndDo;
			EndIf;
			
			If HasChanges Then
				ModifiedRows.Add(Item.GetID());
			EndIf;
		EndIf;
	EndDo;
	
	Users.FillUserPictureNumbers(
		GroupUsers, "Ref", "PictureNumber", RowID, True);
	
	// Setting of the tree displaying.
	HasTree = False;
	For Each Item In GroupUsers.GetItems() Do
		If Item.GetItems().Count() > 0 Then
			HasTree = True;
			Break;
		EndIf;
	EndDo;
	Items.Users.Representation = ?(HasTree, TableRepresentation.Tree, TableRepresentation.List);
	
EndProcedure

&AtServer
Procedure RestoreObjectWithoutUserGroupsMembers(CurrentObject)
	
	SetPrivilegedMode(True);
	
	Query = New Query(
	"SELECT
	|	AccessGroups.DeletionMark,
	|	AccessGroups.Predefined,
	|	AccessGroups.Parent,
	|	AccessGroups.IsFolder,
	|	AccessGroups.Description,
	|	AccessGroups.Profile,
	|	AccessGroups.Responsible,
	|	AccessGroups.UsersType,
	|	AccessGroups.User,
	|	AccessGroups.Definition
	|FROM
	|	Catalog.AccessGroups AS AccessGroups
	|WHERE
	|	AccessGroups.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccessGroupsAccessKinds.AccessKind,
	|	AccessGroupsAccessKinds.AllAllowed
	|FROM
	|	Catalog.AccessGroups.AccessKinds AS AccessGroupsAccessKinds
	|WHERE
	|	AccessGroupsAccessKinds.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccessGroupsAccessValues.AccessKind,
	|	AccessGroupsAccessValues.AccessValue
	|FROM
	|	Catalog.AccessGroups.AccessValues AS AccessGroupsAccessValues
	|WHERE
	|	AccessGroupsAccessValues.Ref = &Ref");
	
	Query.SetParameter("Ref", CurrentObject.Ref);
	QueryResults = Query.ExecuteBatch();
	
	// Attributes restoring.
	FillPropertyValues(CurrentObject, QueryResults[0].Unload()[0]);
	
	// Restoration of tabular section AccessKinds.
	CurrentObject.AccessKinds.Load(QueryResults[1].Unload());
	
	// Restoration of tabular section AccessValues.
	CurrentObject.AccessValues.Load(QueryResults[2].Unload());
	
EndProcedure

&AtServer
Function ClarifyMessage(String, Value)
	
	Return StrReplace(String, "%2", Value);
	
EndFunction

#EndRegion
