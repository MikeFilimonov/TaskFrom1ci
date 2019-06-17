#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Variables

Var OldProfile;      // Access group profile
                     // before change in order to use in the OnWrite event handler.

Var OldDeletionMark; // Deletion mark of the access
                     // group before change in order to use in the OnWrite event handler.

Var OldMembers;      // Access group participants
                     // before change in order to use in the OnWrite event handler.

#EndRegion

#Region EventsHandlers

Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If IsFolder Then
		Return;
	EndIf;
	
	If Not AdditionalProperties.Property("DoNotUpdateUsersRoles") Then
		If ValueIsFilled(Ref) Then
			OldTableUsers = CommonUse.ObjectAttributeValue(Ref, "Users");
			OldMembers = OldTableUsers.Unload().UnloadColumn("User");
		Else
			OldMembers = New Array;
		EndIf;
	EndIf;
	
	OldValues = CommonUse.ObjectAttributesValues(
		Ref, "Profile, DeletionMark");
	
	OldProfile         = OldValues.Profile;
	OldDeletionMark = OldValues.DeletionMark;
	
	If Ref = Catalogs.AccessGroups.Administrators Then
		
		// Always predefined Administrator profile.
		Profile = Catalogs.AccessGroupsProfiles.Administrator;
		
		// It can not be personal access group.
		User = Undefined;
		
		// It can not have common responsible person (only full users).
		Responsible = Undefined;
		
		// Only ordinary users.
		UsersType = Catalogs.Users.EmptyRef();
		
		// Change is allowed only for user with full rights.
		If Not PrivilegedMode()
		   AND Not AccessManagement.IsRole("FullRights") Then
			
			Raise NStr("en = 'Cannot save the Administrators group because you do not have enough rights to edit it.
			           |Contact the administrator for details.'");
		EndIf;
		
		// Check whether there are only users.
		For Each CurrentRow In Users Do
			If TypeOf(CurrentRow.User) <> Type("CatalogRef.Users") Then
				
				Raise NStr("en = 'Cannot save the Administrators group because it contains 
				           |one or several items of the following types: user group, external user,
				           |or external user group.
				           |
				           |Remove these items and try again.'");
			EndIf;
		EndDo;
		
	// Not set the predefined Administrator profile to the arbitrary access group.
	ElsIf Profile = Catalogs.AccessGroupsProfiles.Administrator Then
		Raise NStr("en = 'Cannot save the access group because it contains the Administrator profile.
		           |This profile is exclusive to the Administrators group.
		           |Remove the Administrator profile and try again.'");
	EndIf;
	
	If Not IsFolder Then
		
		// Automatic setting of the attributes for the personal access group.
		If ValueIsFilled(User) Then
			Parent         = Catalogs.AccessGroups.ParentOfPersonalAccessGroups();
			UsersType = Undefined;
		Else
			User = Undefined;
			If Parent = Catalogs.AccessGroups.ParentOfPersonalAccessGroups(True) Then
				Parent = Undefined;
			EndIf;
		EndIf;
		
		// When removing the deletion mark from the
		// access group, the removing the deletion mark from this access group profile is executed.
		If Not DeletionMark
		   AND OldDeletionMark = True
		   AND CommonUse.ObjectAttributeValue(Profile, "DeletionMark") = True Then
			
			LockDataForEdit(Profile);
			ProfileObject = Profile.GetObject();
			ProfileObject.DeletionMark = False;
			ProfileObject.Write();
		EndIf;
	EndIf;
	
EndProcedure

// Updates:
// - roles of the added, remained and deleted users;
// - InformationRegister.AccessGroupsTables;
// - InformationRegister.AccessGroupsValues.
//
Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If IsFolder Then
		Return;
	EndIf;
	
	If Not AdditionalProperties.Property("DoNotUpdateUsersRoles") Then
		
		If CommonUseReUse.DataSeparationEnabled()
			AND Ref = Catalogs.AccessGroups.Administrators
			AND Not CommonUseReUse.SessionWithoutSeparator()
			AND AdditionalProperties.Property("ServiceUserPassword") Then
			
			ServiceUserPassword = AdditionalProperties.ServiceUserPassword;
		Else
			ServiceUserPassword = Undefined;
		EndIf;
		
		UpdateUsersRolesOnAccessGroupChange(ServiceUserPassword);
	EndIf;
	
	If Profile         <> OldProfile
	 OR DeletionMark <> OldDeletionMark Then
		
		InformationRegisters.AccessGroupsTables.RefreshDataRegister(Ref);
	EndIf;
	
	InformationRegisters.AccessGroupsValues.RefreshDataRegister(Ref);
	
EndProcedure

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If AdditionalProperties.Property("CheckedObjectAttributes") Then
		CommonUse.DeleteUnverifiableAttributesFromArray(
			CheckedAttributes, AdditionalProperties.CheckedObjectAttributes);
	EndIf;
	
EndProcedure

#Region HelperProcedureAndFunctions

Procedure UpdateUsersRolesOnAccessGroupChange(ServiceUserPassword)
	
	SetPrivilegedMode(True);
	
	// Updating of roles for the added, remained and deleted users.
	Query = New Query;
	Query.SetParameter("AccessGroup",   Ref);
	Query.SetParameter("OldMembers", OldMembers);
	
	If Profile         <> OldProfile
	 OR DeletionMark <> OldDeletionMark Then
		
		// Selection of all new and old participants of the access group.
		Query.Text =
		"SELECT DISTINCT
		|	Data.User
		|FROM
		|	(SELECT DISTINCT
		|		UserGroupMembers.User AS User
		|	FROM
		|		InformationRegister.UserGroupMembers AS UserGroupMembers
		|	WHERE
		|		UserGroupMembers.UsersGroup IN(&OldMembers)
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		UserGroupMembers.User
		|	FROM
		|		Catalog.AccessGroups.Users AS AccessGroupsUsers
		|			INNER JOIN InformationRegister.UserGroupMembers AS UserGroupMembers
		|			ON AccessGroupsUsers.User = UserGroupMembers.UsersGroup
		|				AND (AccessGroupsUsers.Ref = &AccessGroup)) AS Data";
	Else
		// Changes selection of the access group participants.
		Query.Text =
		"SELECT
		|	Data.User
		|FROM
		|	(SELECT DISTINCT
		|		UserGroupMembers.User AS User,
		|		-1 AS RowChangeKind
		|	FROM
		|		InformationRegister.UserGroupMembers AS UserGroupMembers
		|	WHERE
		|		UserGroupMembers.UsersGroup IN(&OldMembers)
		|	
		|	UNION ALL
		|	
		|	SELECT DISTINCT
		|		UserGroupMembers.User,
		|		1
		|	FROM
		|		Catalog.AccessGroups.Users AS AccessGroupsUsers
		|			INNER JOIN InformationRegister.UserGroupMembers AS UserGroupMembers
		|			ON AccessGroupsUsers.User = UserGroupMembers.UsersGroup
		|				AND (AccessGroupsUsers.Ref = &AccessGroup)) AS Data
		|
		|GROUP BY
		|	Data.User
		|
		|HAVING
		|	SUM(Data.RowChangeKind) <> 0";
	EndIf;
	UsersForUpdating = Query.Execute().Unload().UnloadColumn("User");
	
	If Ref = Catalogs.AccessGroups.Administrators Then
		// Adding users, associated with the IB users, having FullRights role.
		
		For Each IBUser In InfobaseUsers.GetUsers() Do
			If IBUser.Roles.Contains(Metadata.Roles.FullRights) Then
				
				FoundUser = Catalogs.Users.FindByAttribute(
					"InfobaseUserID", IBUser.UUID);
				
				If Not ValueIsFilled(FoundUser) Then
					FoundUser = Catalogs.ExternalUsers.FindByAttribute(
						"InfobaseUserID", IBUser.UUID);
				EndIf;
				
				If ValueIsFilled(FoundUser)
				   AND UsersForUpdating.Find(FoundUser) = Undefined Then
					
					UsersForUpdating.Add(FoundUser);
				EndIf;
				
			EndIf;
		EndDo;
	EndIf;
	
	AccessManagement.UpdateUsersRoles(UsersForUpdating, ServiceUserPassword);
	
EndProcedure

#EndRegion

#EndRegion

#EndIf
