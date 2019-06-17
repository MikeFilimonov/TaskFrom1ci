#Region AddTheHandlersOfServiceEventsSubscriptions

// See details of the same procedure in the StandardSubsystemsServer module.
Procedure OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers) Export
	
	ServerHandlers["StandardSubsystems.AccessManagement\WhenUpdatingIBUserRoles"].Add(
		"AccessManagementServiceSaaSSTL");
	
EndProcedure

#EndRegion

#Region HandlersOfTheServiceEvents

// Gets called when updating the roles of infobase user.
//
// Parameters:
//  InfobaseUserID - UUID,
//  Denial - Boolean. When installing the parameter value to False inside
//    event handler, update of roles for this user of infobase will be skipped.
Procedure WhenUpdatingIBUserRoles(Val UserID, Cancel) Export
	
	If CommonUseReUse.DataSeparationEnabled()
			AND UsersServiceSaaSSTL.UserRegisteredAsUnseparated(UserID) Then
		Cancel = True;
	EndIf;
	
EndProcedure

#EndRegion
