#Region Variables

&AtClient
Var RefreshInterface;

#EndRegion

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	// Attribute values of the form
	RunMode = CommonUseReUse.ApplicationRunningMode();
	RunMode = New FixedStructure(RunMode);
	
	// Visible settings on launch.
	
	// StandardSubsystems.AccessManagement
	SimplifiedInterface = AccessManagementService.SimplifiedInterfaceOfAccessRightsSettings();
	Items.OpenAccessGroups.Visible       = Not SimplifiedInterface;
	// End StandardSubsystems.AccessManagement
	
	CommonUseClientServer.SetFormItemProperty(Items, "UseUserGroups", "Visible", Not SimplifiedInterface);
	CommonUseClientServer.SetFormItemProperty(Items, "ExternalUsersSetup", "Visible", False);
	
	Items.OpenAccessGroupsProfiles.Visible = Not SimplifiedInterface;
	
	// Items state update.
	SetEnabled();
EndProcedure

&AtClient
Procedure OnClose(Exit)
	
	If Exit Then
		Return;
	EndIf;
	
	RefreshApplicationInterface();
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

// StandardSubsystems.AccessManagement
&AtClient
Procedure UseUserGroupsOnChange(Item)
	Attachable_OnAttributeChange(Item);
EndProcedure
// End StandardSubsystems.AccessManagement

// StandardSubsystems.AccessManagement
&AtClient
Procedure LimitAccessOnRecordsLevelOnChange(Item)
	
	If ConstantsSet.UseRowLevelSecurity Then
		
		QuestionText =
			NStr("en = 'Do you want to enable
			     |
			     |the access restriction on the write level?
			     |Filling data will be required which will
			     |be executed by schedule job parts ""Filling data for access restriction"" (perform step in events log monitor).
			     |
			     |Execution can greatly slow down the
			     |application work and it is executed from a few seconds to many hours (depending on data volume).'");
		
		ShowQueryBox(
			New NotifyDescription(
				"LimitAccessOnWriteLevelOnChangeEnd",
				ThisObject,
				Item),
			QuestionText,
			QuestionDialogMode.YesNo);
	Else
		Attachable_OnAttributeChange(Item);
		
	EndIf;
	
EndProcedure
// End StandardSubsystems.AccessManagement

// StandardSubsystems.Users
&AtClient
Procedure UseExternalUsersOnChange(Item)
	Attachable_OnAttributeChange(Item);
EndProcedure
// End StandardSubsystems.Users

&AtClient
Procedure UseCounterpartiesAccessGroupsOnChange(Item)
	Attachable_OnAttributeChange(Item);
EndProcedure

#EndRegion

#Region FormCommandsHandlers

// StandardSubsystems.Users
&AtClient
Procedure CatalogExternalUsers(Command)
	OpenForm("Catalog.ExternalUsers.ListForm", , ThisObject);
EndProcedure
// End StandardSubsystems.Users

&AtClient
Procedure OpenCounterpartiesAccessGroups(Command)
	OpenForm("Catalog.CounterpartiesAccessGroups.ListForm", , ThisObject);
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

#Region Client

&AtClient
Procedure Attachable_OnAttributeChange(Item, RefreshingInterface = True)
	
	Result = OnAttributeChangeServer(Item.Name);
	
	If RefreshingInterface Then
		AttachIdleHandler("RefreshApplicationInterface", 1, True);
		RefreshInterface = True;
	EndIf;
	
	StandardSubsystemsClient.ShowExecutionResult(ThisObject, Result);
	
EndProcedure

&AtClient
Procedure RefreshApplicationInterface()
	
	If RefreshInterface = True Then
		RefreshInterface = False;
		RefreshInterface();
	EndIf;
	
EndProcedure

// StandardSubsystems.AccessManagement
&AtClient
Procedure LimitAccessOnWriteLevelOnChangeEnd(Response, Item) Export
	
	If Response = DialogReturnCode.No Then
		ConstantsSet.UseRowLevelSecurity = False;
	Else
		Attachable_OnAttributeChange(Item);
	EndIf;
	
EndProcedure
// End StandardSubsystems.AccessManagement

#EndRegion

#Region CallingTheServer

&AtServer
Function OnAttributeChangeServer(ItemName)
	
	Result = New Structure;
	
	AttributePathToData = Items[ItemName].DataPath;
	
	SaveAttributeValue(AttributePathToData, Result);
	
	SetEnabled(AttributePathToData);
	
	RefreshReusableValues();
	
	Return Result;
	
EndFunction

#EndRegion

#Region Server

&AtServer
Procedure SaveAttributeValue(AttributePathToData, Result)
	
	// Save attribute values not connected with constants directly (one-to-one ratio).
	If AttributePathToData = "" Then
		Return;
	EndIf;
	
	// Definition of constant name.
	ConstantName = "";
	If Lower(Left(AttributePathToData, 13)) = Lower("ConstantsSet.") Then
		// If the path to attribute data is specified through "ConstantsSet".
		ConstantName = Mid(AttributePathToData, 14);
	Else
		// Definition of name and attribute value record in the corresponding constant from "ConstantsSet".
		// Used for the attributes of the form directly connected with constants (one-to-one ratio).
	EndIf;
	
	// Saving the constant value.
	If ConstantName <> "" Then
		ConstantManager = Constants[ConstantName];
		ConstantValue = ConstantsSet[ConstantName];
		
		If ConstantManager.Get() <> ConstantValue Then
			ConstantManager.Set(ConstantValue);
		EndIf;
		
		StandardSubsystemsClientServer.ExecutionResultAddNotificationOfOpenForms(Result, "Record_ConstantsSet", New Structure, ConstantName);
		// StandardSubsystems.ReportsVariants
		ReportsVariants.AddNotificationOnValueChangeConstants(Result, ConstantManager);
		// End StandardSubsystems.ReportsVariants
	EndIf;
	
EndProcedure

&AtServer
Procedure SetEnabled(AttributePathToData = "")
	
	// StandardSubsystems.Users
	If AttributePathToData = "ConstantsSet.UseExternalUsers" OR AttributePathToData = "" Then
		Items.OpenExternalUsers.Enabled = ConstantsSet.UseExternalUsers;
	EndIf;
	// End StandardSubsystems.Users
	
	// StandardSubsystems.Interactions
	If AttributePathToData = "ConstantsSet.UseExternalUsers" OR AttributePathToData = "" Then
		CommonUseClientServer.SetFormItemProperty(Items, "AddressPublicationsInformationBaseOnWeb", "Enabled", ConstantsSet.UseExternalUsers);
	EndIf;
	// End StandardSubsystems.Interactions
	
	If AttributePathToData = "ConstantsSet.UseRowLevelSecurity" OR AttributePathToData = "" Then
		If Not ConstantsSet.UseRowLevelSecurity Then
			ConstantsSet.UseCounterpartiesAccessGroups = False;
		EndIf;
		Items.UseCounterpartiesAccessGroups.Enabled = ConstantsSet.UseRowLevelSecurity;
		OnAttributeChangeServer("UseCounterpartiesAccessGroups");
	EndIf;
	
	If AttributePathToData = "ConstantsSet.UseCounterpartiesAccessGroups" OR AttributePathToData = "" Then
		Items.OpenCounterpartiesAccessGroups.Enabled = ConstantsSet.UseCounterpartiesAccessGroups;
	EndIf;

EndProcedure

#EndRegion

#EndRegion
