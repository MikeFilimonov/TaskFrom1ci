#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Variables

Var DBUserProcessingParameters; // Parameters that are filled out when processing the IB user.
                                        // It is used in event handler OnWrite.

Var IsNew; // Shows that a new object was written.
                // It is used in event handler OnWrite.

#EndRegion

#Region EventsHandlers

Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	IsNew = IsNew();
	
	UsersService.BeginOfDBUserProcessing(ThisObject, DBUserProcessingParameters);
	
EndProcedure

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If AdditionalProperties.Property("NewUserGroup")
		AND ValueIsFilled(AdditionalProperties.NewUserGroup) Then
		
		Block = New DataLock;
		LockItem = Block.Add("Catalog.UserGroups");
		LockItem.Mode = DataLockMode.Exclusive;
		Block.Lock();
		
		GroupObject = AdditionalProperties.NewUserGroup.GetObject();
		GroupObject.Content.Add().User = Ref;
		GroupObject.Write();
	EndIf;
	
	// Update automatic group content "All users".
	ParticipantsOfChange = New Map;
	ChangedGroups   = New Map;
	
	UsersService.UpdateUserGroupMembers(
		Catalogs.UserGroups.AllUsers, Ref, ParticipantsOfChange, ChangedGroups);
	
	UsersService.RefreshUsabilityRateOfUserGroups(
		Ref, ParticipantsOfChange, ChangedGroups);
	
	UsersService.EndOfIBUserProcessing(
		ThisObject, DBUserProcessingParameters);
	
	UsersService.AfterUserGroupStavesUpdating(
		ParticipantsOfChange, ChangedGroups);
	
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
