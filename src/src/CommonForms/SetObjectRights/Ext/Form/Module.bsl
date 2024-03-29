﻿
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	SetConditionalAppearance();
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	ObjectReference = Parameters.ObjectReference;
	PossibleRights = AccessManagementServiceReUse.Parameters(
		).PossibleRightsForObjectRightsSettings;
	
	If PossibleRights.ByRefsTypes[TypeOf(ObjectReference)] = Undefined Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Access rights
			     |are not set for the %1 type objects.'"),
			String(TypeOf(ObjectReference)));
	EndIf;
	
	// Check permissons to open form.
	CheckPermissionToManageRights();
	
	UseExternalUsers =
		ExternalUsers.UseExternalUsers()
		AND AccessRight("view", Metadata.Catalogs.ExternalUsers);
	
	SetPrivilegedMode(True);
	
	ListOfUserTypes.Add(Type("CatalogRef.Users"),
		Metadata.Catalogs.Users.Synonym);
	
	ListOfUserTypes.Add(Type("CatalogRef.ExternalUsers"),
		Metadata.Catalogs.ExternalUsers.Synonym);
	
	ParentFilled =
		Parameters.ObjectReference.Metadata().Hierarchical
		AND ValueIsFilled(CommonUse.ObjectAttributeValue(Parameters.ObjectReference, "Parent"));
	
	Items.InheritParentsRights.Visible = ParentFilled;
	
	RightSettings = InformationRegisters.ObjectRightsSettings.Read(Parameters.ObjectReference);
	
	FillRights();
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)	
	
	If Exit Then
		Return;
	EndIf;
	
	Notification = New NotifyDescription("WriteAndCloseNotification", ThisObject);
	CommonUseClient.ShowFormClosingConfirmation(Notification, Cancel, Exit);
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure InheritParentsRightsOnChange(Item)
	
	InheritParentsRightsOnChangeAtServer();
	
EndProcedure

&AtServer
Procedure InheritParentsRightsOnChangeAtServer()
	
	If InheritParentsRights Then
		AddInheritedRights();
		FillUserPictureNumbers();
	Else
		// Clear settings inherited from the parents according to hierarchy.
		IndexOf = RightGroups.Count()-1;
		While IndexOf >= 0 Do
			If RightGroups.Get(IndexOf).ParentSettings Then
				RightGroups.Delete(IndexOf);
			EndIf;
			IndexOf = IndexOf - 1;
		EndDo;
	EndIf;
	
EndProcedure

#EndRegion

#Region TableItemFormEventsHandlersRightGroups

&AtClient
Procedure RightGroupsOnChange(Item)
	
	RightGroups.Sort("ParentSetting Desc");
	
EndProcedure

&AtClient
Procedure RightGroupsChoice(Item, SelectedRow, Field, StandardProcessing)
	
	If Field.Name = "RightGroupsUser" Then
		Return;
	EndIf;
	
	Cancel = False;
	CheckOnPosibilityOfRightsChanging(Cancel);
	
	If Not Cancel Then
		CurrentRight  = Mid(Field.Name, StrLen("RightGroups") + 1);
		CurrentData = Items.RightGroups.CurrentData;
		
		If CurrentRight = "InheritanceAllowed" Then
			CurrentData[CurrentRight] = Not CurrentData[CurrentRight];
			Modified = True;
			
		ElsIf PossibleRights.Property(CurrentRight) Then
			OldValue = CurrentData[CurrentRight];
			
			If CurrentData[CurrentRight] = True Then
				CurrentData[CurrentRight] = False;
				
			ElsIf CurrentData[CurrentRight] = False Then
				CurrentData[CurrentRight] = Undefined;
			Else
				CurrentData[CurrentRight] = True;
			EndIf;
			Modified = True;
			
			RefreshDependentRights(CurrentData, CurrentRight, OldValue);
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure RightGroupsOnActivatingRow(Item)
	
	CurrentData = Items.RightGroups.CurrentData;
	
	CommandsEnabled = ?(CurrentData = Undefined, False, Not CurrentData.ParentSettings);
	Items.RightGroupsDeleteContextMenu.Enabled = CommandsEnabled;
	Items.FormDelete.Enabled                     = CommandsEnabled;
	Items.FormMoveUp.Enabled            = CommandsEnabled;
	Items.FormMoveDown.Enabled             = CommandsEnabled;
	
EndProcedure

&AtClient
Procedure RightGroupsOnActivateField(Item)
	
	CommandsEnabled = PossibleRights.Property(Mid(Item.CurrentItem.Name, StrLen("RightGroups") + 1));
	Items.RightGroupsContextMenuRemoveRightSet.Enabled       = CommandsEnabled;
	Items.RightGroupsContextMenuSetRightResolution.Enabled = CommandsEnabled;
	Items.RightGroupsContextMenuSetRightProhibition.Enabled     = CommandsEnabled;
	
EndProcedure

&AtClient
Procedure RightGroupsBeforeRowChange(Item, Cancel)
	
	CheckOnPosibilityOfRightsChanging(Cancel);
	
EndProcedure

&AtClient
Procedure RightGroupsBeforeDeleteRow(Item, Cancel)
	
	CheckOnPosibilityOfRightsChanging(Cancel, True);
	
EndProcedure

&AtClient
Procedure RightGroupsOnStartEdit(Item, NewRow, Copy)
	
	If NewRow Then
		
		// Initial values setting.
		Items.RightGroups.CurrentData.SettingOwner     = Parameters.ObjectReference;
		Items.RightGroups.CurrentData.InheritanceAllowed = True;
		Items.RightGroups.CurrentData.ParentSettings     = False;
		
		For Each AddedAttribute In AddedAttributes Do
			Items.RightGroups.CurrentData[AddedAttribute.Key] = AddedAttribute.Value;
		EndDo;
	EndIf;
	
	If Items.RightGroups.CurrentData.User = Undefined Then
		Items.RightGroups.CurrentData.User  = PredefinedValue("Catalog.Users.EmptyRef");
		Items.RightGroups.CurrentData.PictureNumber = -1;
	EndIf;
	
EndProcedure

&AtClient
Procedure RightGroupsUserOnChange(Item)
	
	If ValueIsFilled(Items.RightGroups.CurrentData.User) Then
		FillUserPictureNumbers(Items.RightGroups.CurrentRow);
	Else
		Items.RightGroups.CurrentData.PictureNumber = -1;
	EndIf;
	
EndProcedure

&AtClient
Procedure RightGroupsUserStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	SelectUsers();
	
EndProcedure

&AtClient
Procedure RightGroupsUserClearing(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	Items.RightGroups.CurrentData.User  = PredefinedValue("Catalog.Users.EmptyRef");
	Items.RightGroups.CurrentData.PictureNumber = -1;
	
EndProcedure

&AtClient
Procedure RightGroupsUserTextEntryEnd(Item, Text, ChoiceData, StandardProcessing)
	
	If ValueIsFilled(Text) Then 
		StandardProcessing = False;
		ChoiceData = FormDataOfUserChoice(Text);
	EndIf;
	
EndProcedure

&AtClient
Procedure RightGroupsUserAutoCompleteText(Item, Text, ChoiceData, Wait, StandardProcessing)
	
	If ValueIsFilled(Text) Then
		StandardProcessing = False;
		ChoiceData = FormDataOfUserChoice(Text);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure WriteAndClose(Command)
	
	WriteBegin(True);
	
EndProcedure

&AtClient
Procedure Write(Command)
	
	WriteBegin();
	
EndProcedure

&AtClient
Procedure Reread(Command)
	
	If Not Modified Then
		ReadRights();
	Else
		ShowQueryBox(
			New NotifyDescription("RereadCompletion", ThisObject),
			NStr("en = 'Data is changed. Read without saving?'"),
			QuestionDialogMode.YesNo,
			5,
			DialogReturnCode.No);
	EndIf;
	
EndProcedure

&AtClient
Procedure RemoveRIghtInstallation(Command)
	
	SetCurrentRightValue(Undefined);
	
EndProcedure

&AtClient
Procedure SetRightProhibition(Command)
	
	SetCurrentRightValue(False);
	
EndProcedure

&AtClient
Procedure SetRightResolution(Command)
	
	SetCurrentRightValue(True);
	
EndProcedure

&AtClient
Procedure SetCurrentRightValue(NewValue)
	
	Cancel = False;
	CheckOnPosibilityOfRightsChanging(Cancel);
	
	If Not Cancel Then
		CurrentRight  = Mid(Items.RightGroups.CurrentItem.Name, StrLen("RightGroups") + 1);
		CurrentData = Items.RightGroups.CurrentData;
		
		If PossibleRights.Property(CurrentRight)
		   AND CurrentData <> Undefined Then
			
			OldValue = CurrentData[CurrentRight];
			CurrentData[CurrentRight] = NewValue;
			
			Modified = True;
			
			RefreshDependentRights(CurrentData, CurrentRight, OldValue);
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.RightGroups.Name);

	FilterElement = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("RightGroups.ParentSettings");
	FilterElement.ComparisonType = DataCompositionComparisonType.Equal;
	FilterElement.RightValue = True;

	Item.Appearance.SetParameterValue("TextColor", WebColors.Gray);

EndProcedure

&AtClient
Procedure WriteAndCloseNotification(Result = Undefined, NotSpecified = Undefined) Export
	
	WriteBegin(True);
	
EndProcedure

&AtClient
Procedure WriteBegin(Close = False)
	
	Cancel = False;
	FillCheckProcessing(Cancel);
	
	If Cancel Then
		Return;
	EndIf;
	
	ConfirmCancelRightsManagement = Undefined;
	WriteRights(ConfirmCancelRightsManagement);
	
	If ConfirmCancelRightsManagement = True Then
		Buttons = New ValueList;
		Buttons.Add("WriteAndClose", NStr("en = 'Save and close'"));
		Buttons.Add("Cancel", NStr("en = 'Cancel'"));
		ShowQueryBox(
			New NotifyDescription("WriteAfterConfirmation", ThisObject),
			NStr("en = 'After writing, you cannot assign access rights.'"),
			Buttons,, "Cancel");
	Else
		If Close Then
			Close();
		Else
			ClearMessages();
		EndIf;
		WriteCompletion();
	EndIf;
	
EndProcedure

&AtClient
Procedure WriteAfterConfirmation(Response, NotSpecified) Export
	
	If Response = "WriteAndClose" Then
		ConfirmCancelRightsManagement = False;
		WriteRights(ConfirmCancelRightsManagement);
		Close();
	EndIf;
	
	WriteCompletion();
	
EndProcedure

&AtClient
Procedure WriteCompletion()
	
	Notify("Write_ObjectRightsSettings", , Parameters.ObjectReference);
	
EndProcedure

&AtClient
Procedure RereadCompletion(Response, NotSpecified) Export
	
	If Response = DialogReturnCode.Yes Then
		ReadRights();
	EndIf;
	
EndProcedure

#Region HelperProcedureAndFunctions

&AtClient
Procedure RefreshDependentRights(Val Data, Val Right, Val OldValue, Val RecursionDepth = 0)
	
	If Data[Right] = OldValue Then
		Return;
	EndIf;
	
	If RecursionDepth > 100 Then
		Return;
	Else
		RecursionDepth = RecursionDepth + 1;
	EndIf;
	
	DependentRights = Undefined;
	
	If Data[Right] = True Then
		
		// Permissions are increased (from Undefined or False to True).
		// You need to increase permissions for the leading rights.
		DirectDependencesOfRights.Property(Right, DependentRights);
		ValueOfDependentRight = True;
		
	ElsIf Data[Right] = False Then
		
		// Prohibitions are increased (from True or Undefined to False).
		// You need to increase prohibitions for dependent rights.
		InverseDependencesOfRights.Property(Right, DependentRights);
		ValueOfDependentRight = False;
	Else
		If OldValue = False Then
			// Prohibitions are reduced (from False to Undefined).
			// You need to reduce prohibitions for the leading rights.
			DirectDependencesOfRights.Property(Right, DependentRights);
			ValueOfDependentRight = Undefined;
		Else
			// Reduced permissions (from True to Undefined).
			// You need to reduce permissions for dependent rights.
			InverseDependencesOfRights.Property(Right, DependentRights);
			ValueOfDependentRight = Undefined;
		EndIf;
	EndIf;
	
	If DependentRights <> Undefined Then
		For Each DependentRight In DependentRights Do
			If TypeOf(DependentRight) = Type("Array") Then
				SetDependentRight = True;
				For Each OneDependentRights In DependentRight Do
					If Data[OneDependentRights] = ValueOfDependentRight Then
						SetDependentRight = False;
						Break;
					EndIf;
				EndDo;
				If SetDependentRight Then
					If Not (ValueOfDependentRight = Undefined AND Data[DependentRight[0]] <> OldValue) Then
						CurrentOldValue = Data[DependentRight[0]];
						Data[DependentRight[0]] = ValueOfDependentRight;
						RefreshDependentRights(Data, DependentRight[0], CurrentOldValue);
					EndIf;
				EndIf;
			Else
				If Not (ValueOfDependentRight = Undefined AND Data[DependentRight] <> OldValue) Then
					CurrentOldValue = Data[DependentRight];
					Data[DependentRight] = ValueOfDependentRight;
					RefreshDependentRights(Data, DependentRight, CurrentOldValue);
				EndIf;
			EndIf;
		EndDo;
	EndIf;
	
EndProcedure

&AtServer
Procedure AddAttribute(NewAttributes, Attribute, InitialValue)
	
	NewAttributes.Add(Attribute);
	AddedAttributes.Insert(Attribute.Name, InitialValue);
	
EndProcedure

&AtServer
Function AddItem(Name, Type, Parent)
	
	Item = Items.Add(Name, Type, Parent);
	Item.FixingInTable = FixingInTable.None;
	
	Return Item;
	
EndFunction

&AtServer
Procedure AddAttributesOrFormItems(NewAttributes = Undefined)
	
	DescriptionFullsOfPossibleRights = AccessManagementServiceReUse.Parameters(
		).PossibleRightsForObjectRightsSettings.ByRefsTypes.Get(
			TypeOf(Parameters.ObjectReference));
	
	PseudoCheckBoxTypeDescription = New TypeDescription("Boolean, Number",
		New NumberQualifiers(1, 0, AllowedSign.Nonnegative));
	
	// Add possible rights set by owner (table of access values).
	For Each RightDetails In DescriptionFullsOfPossibleRights Do
		
		If NewAttributes <> Undefined Then
			
			AddAttribute(NewAttributes, New FormAttribute(RightDetails.Name, PseudoCheckBoxTypeDescription,
				"RightGroups", RightDetails.Title), RightDetails.InitialValue);
			
			PossibleRights.Insert(RightDetails.Name);
			
			// Insert direct and reverse dependencies of rights.
			DirectDependencesOfRights.Insert(RightDetails.Name, RightDetails.RequiredRights);
			For Each DependentRight In RightDetails.RequiredRights Do
				If TypeOf(DependentRight) = Type("Array") Then
					DependentRights = DependentRight;
				Else
					DependentRights = New Array;
					DependentRights.Add(DependentRight);
				EndIf;
				For Each DependentRight In DependentRights Do
					If InverseDependencesOfRights.Property(DependentRight) Then
						DependentRights = InverseDependencesOfRights[DependentRight];
					Else
						DependentRights = New Array;
						InverseDependencesOfRights.Insert(DependentRight, DependentRights);
					EndIf;
					If DependentRights.Find(RightDetails.Name) = Undefined Then
						DependentRights.Add(RightDetails.Name);
					EndIf;
				EndDo;
			EndDo;
		Else
			Item = AddItem("RightGroups" + RightDetails.Name, Type("FormField"), Items.RightGroups);
			Item.ReadOnly                = True;
			Item.Format                        = "ND=1; NZ=; BF=No; BT=Yes";
			Item.HeaderHorizontalAlign = ItemHorizontalLocation.Center;
			Item.HorizontalAlign       = ItemHorizontalLocation.Center;
			Item.DataPath                   = "RightGroups." + RightDetails.Name;
			
			Item.ToolTip = RightDetails.ToolTip;
			// Optimal width of the item calculation.
			ItemWidth = 0;
			For LineNumber = 1 To StrLineCount(RightDetails.Title) Do
				ItemWidth = Max(ItemWidth, StrLen(StrGetLine(RightDetails.Title, LineNumber)));
			EndDo;
			If StrLineCount(RightDetails.Title) = 1 Then
				ItemWidth = ItemWidth + 1;
			EndIf;
			Item.Width = ItemWidth;
		EndIf;
		
		If Items.RightGroups.HeaderHeight < StrLineCount(RightDetails.Title) Then
			Items.RightGroups.HeaderHeight = StrLineCount(RightDetails.Title);
		EndIf;
	EndDo;
	
	If NewAttributes = Undefined AND Parameters.ObjectReference.Metadata().Hierarchical Then
		Item = AddItem("RightGroupsInheritanceAllowed", Type("FormField"), Items.RightGroups);
		Item.ReadOnly                = True;
		Item.Format                        = "ND=1; NZ=; BF=No; BT=Yes";
		Item.HeaderHorizontalAlign = ItemHorizontalLocation.Center;
		Item.HorizontalAlign       = ItemHorizontalLocation.Center;
		Item.DataPath                   = "RightGroups.InheritanceAllowed";
		
		Item.Title = NStr("en = 'For subfolders'");
		Item.ToolTip = NStr("en = 'Rights not only to the current folder, but also to its subfolders'");
		
		Item = AddItem("RightGroupsSettingOwner", Type("FormField"), Items.RightGroups);
		Item.ReadOnly = True;
		Item.DataPath    = "RulesGroups.SettingOwner";
		Item.Title = NStr("en = 'Inherited from'");
		Item.ToolTip = NStr("en = 'Folder from which access rights settings are inherited'");
		Item.Visible = ParentFilled;
		
		ConditionalAppearanceItem = ConditionalAppearance.Items.Add();
		ConditionalAppearanceItem.Use = True;
		ConditionalAppearanceItem.Appearance.SetParameterValue("Text", "");
		
		FilterItem = ConditionalAppearanceItem.Filter.Items.Add(
			Type("DataCompositionFilterItem"));
		FilterItem.Use  = True;
		FilterItem.LeftValue  = New DataCompositionField("RightGroups.ParentSettings");
		FilterItem.ComparisonType   = DataCompositionComparisonType.Equal;
		FilterItem.RightValue = False;
		
		MadeOutField = ConditionalAppearanceItem.Fields.Items.Add();
		MadeOutField.Use = True;
		MadeOutField.Field = New DataCompositionField("RightGroupsSettingOwner");
		
		If Items.RightGroups.HeaderHeight = 1 Then
			Items.RightGroups.HeaderHeight = 2;
		EndIf;
	EndIf;
	
EndProcedure

&AtServer
Procedure FillRights()
	
	DirectDependencesOfRights   = New Structure;
	InverseDependencesOfRights = New Structure;
	PossibleRights          = New Structure;
	
	AddedAttributes = New Structure;
	NewAttributes = New Array;
	AddAttributesOrFormItems(NewAttributes);
	
	// Add form attributes.
	ChangeAttributes(NewAttributes);
	
	// Add form items
	AddAttributesOrFormItems();
	
	ReadRights();
	
EndProcedure

&AtServer
Procedure ReadRights()
	
	RightGroups.Clear();
	
	SetPrivilegedMode(True);
	RightSettings = InformationRegisters.ObjectRightsSettings.Read(Parameters.ObjectReference);
	
	InheritParentsRights = RightSettings.Inherit;
	
	For Each Settings In RightSettings.Settings Do
		If InheritParentsRights OR Not Settings.ParentSettings Then
			FillPropertyValues(RightGroups.Add(), Settings);
		EndIf;
	EndDo;
	FillUserPictureNumbers();
	
	Modified = False;
	
EndProcedure

&AtServer
Procedure AddInheritedRights()
	
	SetPrivilegedMode(True);
	RightSettings = InformationRegisters.ObjectRightsSettings.Read(Parameters.ObjectReference);
	
	IndexOf = 0;
	For Each Settings In RightSettings.Settings Do
		If Settings.ParentSettings Then
			FillPropertyValues(RightGroups.Insert(IndexOf), Settings);
			IndexOf = IndexOf + 1;
		EndIf;
	EndDo;
	
	FillUserPictureNumbers();
	
EndProcedure

&AtClient
Procedure FillCheckProcessing(Cancel)
	
	ClearMessages();
	
	LineNumber = RightGroups.Count()-1;
	
	While Not Cancel AND LineNumber >= 0 Do
		CurrentRow = RightGroups.Get(LineNumber);
		
		// Check if rights check boxes are selected.
		NoFilledRight = True;
		NameOfFirstRight = "";
		For Each PossibleRight In PossibleRights Do
			If Not ValueIsFilled(NameOfFirstRight) Then
				NameOfFirstRight = PossibleRight.Key;
			EndIf;
			If TypeOf(CurrentRow[PossibleRight.Key]) = Type("Boolean") Then
				NoFilledRight = False;
				Break;
			EndIf;
		EndDo;
		If NoFilledRight Then
			CommonUseClientServer.MessageToUser(
				NStr("en = 'No access right is specified.'"),
				,
				"RightGroups[" + Format(LineNumber, "NG=0") + "]." + NameOfFirstRight,
				,
				Cancel);
			Return;
		EndIf;
		
		// Check how users/user
		// groups, access values and their duplicates are filled.
		
		// Check filling
		If Not ValueIsFilled(CurrentRow["User"]) Then
			CommonUseClientServer.MessageToUser(
				NStr("en = 'User or group is not entered.'"),
				,
				"RightGroups[" + Format(LineNumber, "NG=0") + "].User",
				,
				Cancel);
			Return;
		EndIf;
		
		// Check for duplicates
		Filter = New Structure("SettingOwner, User",
		                        CurrentRow["SettingOwner"],
		                        CurrentRow["User"]);
		If RightGroups.FindRows(Filter).Count() > 1 Then
			If TypeOf(Filter.User) = Type("CatalogRef.Users") Then
				MessageText = NStr("en = 'Setting for user ""%1"" already exists.'");
			Else
				MessageText = NStr("en = 'Setting for user group ""%1"" already exists.'");
			EndIf;
			CommonUseClientServer.MessageToUser(
				StringFunctionsClientServer.SubstituteParametersInString(MessageText, Filter.User),
				,
				"RightGroups[" + Format(LineNumber, "NG=0") + "].User",
				,
				Cancel);
			Return;
		EndIf;
			
		LineNumber = LineNumber - 1;
	EndDo;
	
EndProcedure

&AtServer
Procedure WriteRights(ConfirmCancelRightsManagement)
	
	CheckPermissionToManageRights();
	
	BeginTransaction();
	Try
		SetPrivilegedMode(True);
		InformationRegisters.ObjectRightsSettings.Write(Parameters.ObjectReference, RightGroups, InheritParentsRights);
		SetPrivilegedMode(False);
		
		If ConfirmCancelRightsManagement = False
		 OR AccessManagement.IsRight("RightsManagement", Parameters.ObjectReference) Then
			
			CommitTransaction();
			Modified = False;
		Else
			RollbackTransaction();
			ConfirmCancelRightsManagement = True;
		EndIf;
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

&AtClient
Procedure CheckOnPosibilityOfRightsChanging(Cancel, CheckOfDeletion = False)
	
	CurrentSettingOwner = Items.RightGroups.CurrentData["SettingOwner"];
	
	If ValueIsFilled(CurrentSettingOwner)
	   AND CurrentSettingOwner <> Parameters.ObjectReference Then
		
		Cancel = True;
		
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'These rights are inherited, they can be changed in
			     |the form of rights setting of the higher %1 folder.'"),
			CurrentSettingOwner);
		
		If CheckOfDeletion Then
			MessageText = MessageText + Chars.LF + Chars.LF
				+ StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = 'To delete all inherited rights,
					     |clear the %1 check box.'"),
					Items.InheritParentsRights.Title);
		EndIf;
	EndIf;
	
	If Cancel Then
		ShowMessageBox(, MessageText);
	EndIf;
	
EndProcedure

&AtServerNoContext
Function FormDataOfUserChoice(Text)
	
	Return Users.FormDataOfUserChoice(Text);
	
EndFunction

&AtClient
Procedure ShowUsersTypeSelectionOrExternalUsers(ContinuationProcessor)
	
	SelectionAndPickOutOfExternalUsers = False;
	
	If UseExternalUsers Then
		
		ListOfUserTypes.ShowChooseItem(
			New NotifyDescription(
				"ShowTypeSelectionUsersOrExternalUsersEnd",
				ThisObject,
				ContinuationProcessor),
			NStr("en = 'Select data type'"),
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
Procedure SelectUsers()
	
	CurrentUser = ?(Items.RightGroups.CurrentData = Undefined,
		Undefined, Items.RightGroups.CurrentData.User);
	
	If ValueIsFilled(CurrentUser)
	   AND (    TypeOf(CurrentUser) = Type("CatalogRef.Users")
	      OR TypeOf(CurrentUser) = Type("CatalogRef.UserGroups") ) Then
		
		SelectionAndPickOutOfExternalUsers = False;
		
	ElsIf UseExternalUsers
	        AND ValueIsFilled(CurrentUser)
	        AND (    TypeOf(CurrentUser) = Type("CatalogRef.ExternalUsers")
	           OR TypeOf(CurrentUser) = Type("CatalogRef.ExternalUserGroups") ) Then
	
		SelectionAndPickOutOfExternalUsers = True;
	Else
		ShowUsersTypeSelectionOrExternalUsers(
			New NotifyDescription("SelectUsersEnd", ThisObject));
		Return;
	EndIf;
	
	SelectUsersEnd(SelectionAndPickOutOfExternalUsers);
	
EndProcedure

&AtClient
Procedure SelectUsersEnd(SelectionAndPickOutOfExternalUsers, NotSpecified = Undefined) Export
	
	If SelectionAndPickOutOfExternalUsers = Undefined Then
		Return;
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("ChoiceMode", True);
	FormParameters.Insert("CurrentRow", ?(
		Items.RightGroups.CurrentData = Undefined,
		Undefined,
		Items.RightGroups.CurrentData.User));
	
	If SelectionAndPickOutOfExternalUsers Then
		FormParameters.Insert("ExternalUserGroupChoice", True);
	Else
		FormParameters.Insert("UserGroupChoice", True);
	EndIf;
	
	If SelectionAndPickOutOfExternalUsers Then
		
		OpenForm(
			"Catalog.ExternalUsers.ChoiceForm",
			FormParameters,
			Items.RightGroupsUser);
	Else
		OpenForm(
			"Catalog.Users.ChoiceForm",
			FormParameters,
			Items.RightGroupsUser);
	EndIf;
	
EndProcedure

&AtServer
Procedure FillUserPictureNumbers(RowID = Undefined)
	
	Users.FillUserPictureNumbers(RightGroups, "User", "PictureNumber", RowID);
	
EndProcedure

&AtServer
Procedure CheckPermissionToManageRights()
	
	If AccessManagement.IsRight("RightsManagement", Parameters.ObjectReference) Then
		Return;
	EndIf;
	
	Raise NStr("en = 'Right setting is not available.'");
	
EndProcedure

#EndRegion

#EndRegion
