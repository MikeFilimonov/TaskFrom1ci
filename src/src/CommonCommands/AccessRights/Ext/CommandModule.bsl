﻿
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	If CommandParameter = Undefined Then 
		Return;
	EndIf;
	
	If Not DriveAccessManagementReUse.InfobaseUserWithFullAccess() Then
		ErrorMessage = NStr("en = 'The setting is available only for administrator of the application.'");
		Raise ErrorMessage;
		Return;
	EndIf;
	
	If StandardSubsystemsClientReUse.ClientWorkParameters(
			).SimplifiedInterfaceOfAccessRightsSettings Then
		
		FormName = "CommonForm.AccessRightsSimplified";
	Else
		FormName = "CommonForm.AccessRights";
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("User", CommandParameter);
	
	OpenForm(
		FormName,
		FormParameters,
		CommandExecuteParameters.Source,
		CommandExecuteParameters.Uniqueness,
		CommandExecuteParameters.Window);
	
EndProcedure
