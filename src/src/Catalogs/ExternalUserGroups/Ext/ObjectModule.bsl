﻿#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Variables

Var OldParent; // Group parent value before
                      // change to use in event handler OnWrite.

Var OldCompositionOfExternalUsersGroup; // Content of external
                                              // users of the external user
                                              // group before change for the use in OnWrite event handler.

Var FormerExternalUserGroupRolesSet; // Content of the
                                                   // roles of external user group before
                                                   // change for the use in OnWrite event handler.

Var FormerValueAllAuhorizationObjects; // Value of
                                           // attribute AllAuthorizationObjects before change for
                                           // the use in OnWrite event handler.

Var IsNew; // Shows that a new object was written.
                // It is used in event handler OnWrite.

#EndRegion

#Region EventsHandlers

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If AdditionalProperties.Property("CheckedObjectAttributes") Then
		CheckedObjectAttributes = AdditionalProperties.CheckedObjectAttributes;
	Else
		CheckedObjectAttributes = New Array;
	EndIf;
	
	Errors = Undefined;
	
	// Parent use checking.
	If Parent = Catalogs.ExternalUserGroups.AllExternalUsers Then
		CommonUseClientServer.AddUserError(Errors,
			"Object.Parent",
			NStr("en = 'Predefined group ""All external users"" cannot be a parent group.'"),
			"");
	EndIf;
	
	// Check of the unfilled and repetitive external users.
	CheckedObjectAttributes.Add("Content.ExternalUser");
	
	For Each CurrentRow In Content Do
		LineNumber = Content.IndexOf(CurrentRow);
		
		// Value fill checking.
		If Not ValueIsFilled(CurrentRow.ExternalUser) Then
			CommonUseClientServer.AddUserError(Errors,
				"Object.Content[%1].ExternalUser",
				NStr("en = 'External user is not selected.'"),
				"Object.Content",
				LineNumber,
				NStr("en = 'External user in line %1 was not selected.'"));
			Continue;
		EndIf;
		
		// Checking existence of duplicate values.
		FoundValues = Content.FindRows(New Structure("ExternalUser", CurrentRow.ExternalUser));
		If FoundValues.Count() > 1 Then
			CommonUseClientServer.AddUserError(Errors,
				"Object.Content[%1].ExternalUser",
				NStr("en = 'External user is repeated.'"),
				"Object.Content",
				LineNumber,
				NStr("en = 'External user in line %1 is repeated.'"));
		EndIf;
	EndDo;
	
	CommonUseClientServer.ShowErrorsToUser(Errors, Cancel);
	
	CommonUse.DeleteUnverifiableAttributesFromArray(CheckedAttributes, CheckedObjectAttributes);
	
EndProcedure

Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Not UsersService.BanEditOfRoles() Then
		QueryResult = CommonUse.ObjectAttributeValue(Ref, "Roles");
		If TypeOf(QueryResult) = Type("QueryResult") Then
			FormerExternalUserGroupRolesSet = QueryResult.Unload();
		Else
			FormerExternalUserGroupRolesSet = Roles.Unload(New Array);
		EndIf;
	EndIf;
	
	IsNew = IsNew();
	
	If Ref = Catalogs.ExternalUserGroups.AllExternalUsers Then
		
		TypeOfAuthorizationObjects = Undefined;
		AllAuthorizationObjects  = False;
		
		If Not Parent.IsEmpty() Then
			Raise
				NStr("en = 'Predefined group ""All external users"" cannot be moved.'");
		EndIf;
		If Content.Count() > 0 Then
			Raise
				NStr("en = 'Adding participants to predefined group ""All external users"" is forbidden.'");
		EndIf;
	Else
		If Parent = Catalogs.ExternalUserGroups.AllExternalUsers Then
			Raise
				NStr("en = 'Cannot add subgroup to the predefined group ""All external users"".'");
		ElsIf Parent.AllAuthorizationObjects Then
			Raise StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Cannot add a subgroup to the ""%1"" group because it includes all users.'"), Parent);
		EndIf;
		
		If TypeOfAuthorizationObjects = Undefined Then
			AllAuthorizationObjects = False;
			
		ElsIf AllAuthorizationObjects
		        AND ValueIsFilled(Parent) Then
			
			Raise
				NStr("en = 'Cannot move the group that includes all users.'");
		EndIf;
		
		// Check for uniqueness of a group of all authorization objects of the specified type.
		If AllAuthorizationObjects Then
			
			Query = New Query;
			Query.SetParameter("Ref", Ref);
			Query.SetParameter("TypeOfAuthorizationObjects", TypeOfAuthorizationObjects);
			Query.Text =
			"SELECT
			|	PRESENTATION(ExternalUserGroups.Ref) AS RefPresentation
			|FROM
			|	Catalog.ExternalUserGroups AS ExternalUserGroups
			|WHERE
			|	ExternalUserGroups.Ref <> &Ref
			|	AND ExternalUserGroups.TypeOfAuthorizationObjects = &TypeOfAuthorizationObjects
			|	AND ExternalUserGroups.AllAuthorizationObjects";
			
			QueryResult = Query.Execute();
			If Not QueryResult.IsEmpty() Then
			
				Selection = QueryResult.Select();
				Selection.Next();
				Raise StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = 'The ""%1"" group already exists and includes all users of the ""%2"" kind.'"),
					Selection.RefPresentation,
					TypeOfAuthorizationObjects.Metadata().Synonym);
			EndIf;
		EndIf;
		
		// Checking the matches of authorization object
		// types with the parent (valid if the type of parent is not specified).
		If ValueIsFilled(Parent) Then
			
			ParentAuthorizationObjectType = CommonUse.ObjectAttributeValue(
				Parent, "TypeOfAuthorizationObjects");
			
			If ParentAuthorizationObjectType <> Undefined
			   AND ParentAuthorizationObjectType <> TypeOfAuthorizationObjects Then
				
				Raise StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = 'Kind of participants shall be
					     |""%1"" as in the upstream group of external users ""%2"".'"),
					ParentAuthorizationObjectType.Metadata().Synonym,
					Parent);
			EndIf;
		EndIf;
		
		// If in the external user group the type of participants
		// is set to "All users of specified type", check the existence of subordinate groups.
		If AllAuthorizationObjects
			AND ValueIsFilled(Ref) Then
			Query = New Query;
			Query.SetParameter("Ref", Ref);
			Query.Text =
			"SELECT
			|	PRESENTATION(ExternalUserGroups.Ref) AS RefPresentation
			|FROM
			|	Catalog.ExternalUserGroups AS ExternalUserGroups
			|WHERE
			|	ExternalUserGroups.Parent = &Ref";
			
			QueryResult = Query.Execute();
			If Not QueryResult.IsEmpty() Then
				Raise StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = 'Cannot change a kind
					     |of participants of group ""%1"" as it has subgroups.'"),
					Description);
			EndIf;
			
		EndIf;
		
		// Check that during the change
		// of types of authorization objects there are no subordinate items of other type (type clearing is possible).
		If TypeOfAuthorizationObjects <> Undefined
		   AND ValueIsFilled(Ref) Then
			
			Query = New Query;
			Query.SetParameter("Ref", Ref);
			Query.SetParameter("TypeOfAuthorizationObjects", TypeOfAuthorizationObjects);
			Query.Text =
			"SELECT
			|	PRESENTATION(ExternalUserGroups.Ref) AS RefPresentation,
			|	ExternalUserGroups.TypeOfAuthorizationObjects
			|FROM
			|	Catalog.ExternalUserGroups AS ExternalUserGroups
			|WHERE
			|	ExternalUserGroups.Parent = &Ref
			|	AND ExternalUserGroups.TypeOfAuthorizationObjects <> &TypeOfAuthorizationObjects";
			
			QueryResult = Query.Execute();
			If Not QueryResult.IsEmpty() Then
				
				Selection = QueryResult.Select();
				Selection.Next();
				
				If Selection.TypeOfAuthorizationObjects = Undefined Then
					OtherAuthorizationObjectTypePresentation = NStr("en = 'Any user'");
				Else
					OtherAuthorizationObjectTypePresentation =
						Selection.TypeOfAuthorizationObjects.Metadata().Synonym;
				EndIf;
				Raise StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = 'Cannot change a kind
					     |of participants of group ""%1"" as it has subgroup ""%2"" with another kind of participants ""%3"".'"),
					Description,
					Selection.RefPresentation,
					OtherAuthorizationObjectTypePresentation);
			EndIf;
		EndIf;
		
		OldValues = CommonUse.ObjectAttributesValues(
			Ref, "AllAuthorizationObjects, Parent");
		
		OldParent                      = OldValues.Parent;
		FormerValueAllAuhorizationObjects = OldValues.AllAuthorizationObjects;
		
		If ValueIsFilled(Ref)
		   AND Ref <> Catalogs.ExternalUserGroups.AllExternalUsers Then
			
			QueryResult = CommonUse.ObjectAttributeValue(Ref, "Content");
			If TypeOf(QueryResult) = Type("QueryResult") Then
				OldCompositionOfExternalUsersGroup = QueryResult.Unload();
			Else
				OldCompositionOfExternalUsersGroup = Content.Unload(New Array);
			EndIf;
		EndIf;
	EndIf;
	
EndProcedure

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If UsersService.BanEditOfRoles() Then
		IsExternalUserGroupRoleContentChanged = False;
		
	Else
		IsExternalUserGroupRoleContentChanged =
			UsersService.ColumnValuesDifferences(
				"Role",
				Roles.Unload(),
				FormerExternalUserGroupRolesSet).Count() <> 0;
	EndIf;
	
	ParticipantsOfChange = New Map;
	ChangedGroups   = New Map;
	
	If Ref <> Catalogs.ExternalUserGroups.AllExternalUsers Then
		
		If AllAuthorizationObjects
		 OR FormerValueAllAuhorizationObjects = True Then
			
			UsersService.UpdateExternalUserGroupsStaves(
				Ref, , ParticipantsOfChange, ChangedGroups);
		Else
			StaffChange = UsersService.ColumnValuesDifferences(
				"ExternalUser",
				Content.Unload(),
				OldCompositionOfExternalUsersGroup);
			
			UsersService.UpdateExternalUserGroupsStaves(
				Ref, StaffChange, ParticipantsOfChange, ChangedGroups);
			
			If OldParent <> Parent Then
				
				If ValueIsFilled(Parent) Then
					UsersService.UpdateExternalUserGroupsStaves(
						Parent, , ParticipantsOfChange, ChangedGroups);
				EndIf;
				
				If ValueIsFilled(OldParent) Then
					UsersService.UpdateExternalUserGroupsStaves(
						OldParent, , ParticipantsOfChange, ChangedGroups);
				EndIf;
			EndIf;
		EndIf;
		
		UsersService.RefreshUsabilityRateOfUserGroups(
			Ref, ParticipantsOfChange, ChangedGroups);
	EndIf;
	
	If IsExternalUserGroupRoleContentChanged Then
		UsersService.RefreshRolesOfExternalUsers(Ref);
	EndIf;
	
	UsersService.AfterExternalUserGroupsStavesUpdating(
		ParticipantsOfChange, ChangedGroups);
	
	UsersService.AfterUserOrGroupChangeAdding(Ref, IsNew);
	
EndProcedure

#EndRegion

#EndIf