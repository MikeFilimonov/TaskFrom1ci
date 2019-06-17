﻿
#Region Variables

&AtClient
Var RefreshInterface;

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure Attachable_OnAttributeChange(Item, RefreshingInterface = True)
	
	Result = OnAttributeChangeServer(Item.Name);
	
	If RefreshingInterface Then
		AttachIdleHandler("RefreshApplicationInterface", 1, True);
		RefreshInterface = True;
	EndIf;
	
	If Item.Name = "ConfirmationOnApplicationExit" Then
		StandardSubsystemsClient.SetClientParameter("AskConfirmationOnClose", ConfirmationOnApplicationExit);
	EndIf;
	
	If Result.Property("NotificationForms") Then
		Notify(Result.NotificationForms.EventName, Result.NotificationForms.Parameter, Result.NotificationForms.Source);
	EndIf;
	
EndProcedure

&AtClient
Procedure RefreshApplicationInterface()
	
	If RefreshInterface = True Then
		RefreshInterface = False;
		RefreshInterface();
	EndIf;
	
EndProcedure

&AtServer
Procedure SetEnabled(AttributePathToData = "")
	
	
	
EndProcedure

&AtServer
Function OnAttributeChangeServer(ItemName)
	
	Result = New Structure;
	
	AttributePathToData = Items[ItemName].DataPath;
	
	SaveAttributeValue(AttributePathToData, Result);
	
	SetEnabled(AttributePathToData);
	
	RefreshReusableValues();
	
	Return Result;
	
EndFunction

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
		
		NotificationForms = New Structure("EventName, Parameter, Source", "Record_ConstantsSet", New Structure, ConstantName);
		Result.Insert("NotificationForms", NotificationForms);
	EndIf;
	
	If AttributePathToData = "ConfirmationOnApplicationExit" Then
		
		StandardSubsystemsServerCall.SaveExitConfirmationSettings(ConfirmationOnApplicationExit);
		
	EndIf;
	
EndProcedure

&AtServer
Procedure VisibleManagementElements(AttributePathToData = "")
	
	If AttributePathToData = "FullTextSearch" OR IsBlankString(AttributePathToData) Then
		
		CommonUseClientServer.SetFormItemProperty(Items, "ExplanationFullTextSearchInData", "Visible", GetFunctionalOption("UseFullTextSearch"));
		
	EndIf;
	
	If AttributePathToData = "EquipmentConnectionAndSetup" OR IsBlankString(AttributePathToData) Then
		
		CommonUseClientServer.SetFormItemProperty(Items, "Decoration1", "Visible", GetFunctionalOption("UsePeripherals"));
		
	EndIf;
	
EndProcedure

#Region FormCommandHandlers

// Command handler "FullTextSearch"
//
&AtClient
Procedure FullTextSearch(Command)
	
	OpenForm("DataProcessor.FullTextSearch.Form");
	
EndProcedure

&AtClient
Procedure UserInfo(Command)
	
	ShowValue(Undefined,AuthorizedUser);
	
EndProcedure

&AtClient
Procedure ProxyServerSettings(Command)
	
	OpenForm("CommonForm.ProxyServerSettings",
					New Structure("ProxySettingAtClient", True));
	
EndProcedure

&AtClient
Procedure InstallFileOperationsExtensionAtClient(Command)
	
	BeginInstallFileSystemExtension(Undefined);
	
EndProcedure

&AtClient
Procedure UpdateSystemParameters(Command)
	
	RefreshReusableValues();
	RefreshInterface();
	
EndProcedure

&AtClient
Procedure EquipmentConnectionAndSetup(Command)
	
	EquipmentManagerClient.RefreshClientWorkplace();
	
	OpenForm("Catalog.Peripherals.ListForm");
	
EndProcedure

#EndRegion

#EndRegion

#Region ProcedureFormEventHandlers

// Procedure - OnCreateAtServer form event handler.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	// Attribute values of the form
	RunMode = CommonUseReUse.ApplicationRunningMode();
	RunMode = New FixedStructure(RunMode);
	
	InfobaseUserWithFullAccess = Users.InfobaseUserWithFullAccess( ,False, False);
	CommonUseClientServer.SetFormItemProperty(Items, "EquipmentConnectionAndSetup", "Visible", InfobaseUserWithFullAccess);
	
	// work with users
	AuthorizedUser = Users.AuthorizedUser();
	
	VisibleManagementElements();
	
	SetEnabled();
	
EndProcedure

// Procedure - OnOpen form event handler.
//
&AtClient
Procedure OnOpen(Cancel)
	
	ConfirmationOnApplicationExit = StandardSubsystemsClientReUse.ClientWorkParameters().AskConfirmationOnExit;
	
EndProcedure

// Procedure - event handler OnClose form.
&AtClient
Procedure OnClose(Exit)
	
	If Exit Then
		Return;
	EndIf;

	RefreshApplicationInterface();
	
EndProcedure

#Region ProcedureEventHandlersOfFormAttributes

// Procedure - event handler OnChange field (check box) ConfirmationOnApplicationExit
//
&AtClient
Procedure ConfirmationOnApplicationExitOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

#EndRegion

#EndRegion
