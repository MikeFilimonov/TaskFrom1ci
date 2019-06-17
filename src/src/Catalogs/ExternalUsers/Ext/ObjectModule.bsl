#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Variables

Var DBUserProcessingParameters; // Parameters that are filled out when processing the IB user.
                                // It is used in event handler OnWrite.

Var IsNew; // Shows that a new object was written.
           // It is used in event handler OnWrite.

Var OldAuthorizationObject; // Authorization object values before change.
                            // It is used in event handler OnWrite.

#EndRegion

#Region EventsHandlers

Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	IsNew = IsNew();
	
	If Not ValueIsFilled(AuthorizationObject) Then
		Raise NStr("en = 'Authorization object is not set for an external user.'");
	Else
		ErrorText = "";
		If UsersService.AuthorizationObjectInUse(
		         AuthorizationObject, Ref, , , ErrorText) Then
			
			Raise ErrorText;
		EndIf;
	EndIf;
	
	// Checking that authorization object isn't change.
	If IsNew Then
		OldAuthorizationObject = NULL;
	Else
		OldAuthorizationObject = CommonUse.ObjectAttributeValue(
			Ref, "AuthorizationObject");
		
		If ValueIsFilled(OldAuthorizationObject)
		   AND OldAuthorizationObject <> AuthorizationObject Then
			
			Raise NStr("en = 'Cannot change previously specified authorization object.'");
		EndIf;
	EndIf;
	
	UsersService.BeginOfDBUserProcessing(ThisObject, DBUserProcessingParameters);
	
EndProcedure

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	// Updating content of the new external user group (if it is set).
	If AdditionalProperties.Property("NewExternalUserGroup") AND
	     ValueIsFilled(AdditionalProperties.NewExternalUserGroup) Then
		
		Block = New DataLock;
		LockItem = Block.Add("Catalog.ExternalUserGroups");
		LockItem.Mode = DataLockMode.Exclusive;
		Block.Lock();
		
		GroupObject = AdditionalProperties.NewExternalUserGroup.GetObject();
		GroupObject.Content.Add().ExternalUser = Ref;
		GroupObject.Write();
	EndIf;
	
	// Updating the content of the automatic group "All external users".
	ParticipantsOfChange = New Map;
	ChangedGroups   = New Map;
	
	UsersService.UpdateExternalUserGroupsStaves(
		Catalogs.ExternalUserGroups.AllExternalUsers,
		Ref,
		ParticipantsOfChange,
		ChangedGroups);
	
	UsersService.RefreshUsabilityRateOfUserGroups(
		Ref, ParticipantsOfChange, ChangedGroups);
	
	UsersService.EndOfIBUserProcessing(
		ThisObject, DBUserProcessingParameters);
	
	UsersService.AfterExternalUserGroupsStavesUpdating(
		ParticipantsOfChange,
		ChangedGroups);
	
	If OldAuthorizationObject <> AuthorizationObject Then
		UsersService.AfterExternalUserAuthorizationObjectChange(
			Ref, OldAuthorizationObject, AuthorizationObject);
	EndIf;
	
	UsersService.AfterUserOrGroupChangeAdding(Ref, IsNew);
	
EndProcedure

Procedure BeforeDelete(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	GeneralActionsBeforeDeletionInNormalModeAndOnDataExchange();
	
EndProcedure

Procedure OnCopy(CopiedObject)
	
	AdditionalProperties.Insert("CopyingValue", CopiedObject.Ref);
	
	InfobaseUserID = Undefined;
	ServiceUserID = Undefined;
	Prepared = False;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// Only for internal use.
Procedure GeneralActionsBeforeDeletionInNormalModeAndOnDataExchange() Export
	
	// It is required to delete the IB user, else it will get
	// to the error list in the form of IBUsers, besides the input by this IB user will lead to an error.
	
	IBUserDescription = New Structure;
	IBUserDescription.Insert("Action", "Delete");
	AdditionalProperties.Insert("IBUserDescription", IBUserDescription);
	
	UsersService.BeginOfDBUserProcessing(ThisObject, DBUserProcessingParameters, True);
	UsersService.EndOfIBUserProcessing(ThisObject, DBUserProcessingParameters);
	
EndProcedure

#EndRegion

#EndIf