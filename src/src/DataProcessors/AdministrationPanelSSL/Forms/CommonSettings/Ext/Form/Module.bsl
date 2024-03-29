﻿#Region Variables

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
	
	ApplicationTimeZone = GetInfobaseTimeZone();
	If IsBlankString(ApplicationTimeZone) Then
		ApplicationTimeZone = TimeZone();
	EndIf;
	Items.ApplicationTimeZone.ChoiceList.Add(ApplicationTimeZone);
	
	// Visible settings on launch.
	
	// StandardSubsystems.BasicFunctionality
	Items.OpenSecurityProfilesUseSettings.Visible = WorkInSafeModeService.SecurityProfilesSetupAvailable() AND RunMode.ThisIsSystemAdministrator;
	// End of StandardSubsystems BasicFunctionality
	
	// StandardSubsystems.GetFilesFromInternet
	Items.OpenProxyServerParameters.Visible = RunMode.ClientServer AND RunMode.ThisIsSystemAdministrator;
	// End StandardSubsystems.GetFilesFromInternet
	
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

&AtClient
Procedure ApplicationTitleOnChange(Item)
	Attachable_OnAttributeChange(Item);
	StandardSubsystemsClient.SetAdvancedApplicationCaption();
EndProcedure

&AtClient
Procedure ApplicationTimeZoneOnChange(Item)
	Attachable_OnAttributeChange(Item);
EndProcedure

&AtClient
Procedure ApplicationTimeZoneStartChoice(Item, ChoiceData, StandardProcessing)
	If Item.ChoiceList.Count() < 2 Then
		ImportTimeZones();
	EndIf;
EndProcedure

&AtClient
Procedure HomeCountryOnChange(Item)
	Attachable_OnAttributeChange(Item);
EndProcedure

// StandardSubsystems.ObjectVersioning
&AtClient
Procedure UseObjectVersioningOnChange(Item)
	Attachable_OnAttributeChange(Item);
EndProcedure
// End StandardSubsystems.ObjectVersioning

#EndRegion

#Region FormCommandsHandlers

// StandardSubsystems.ObjectVersioning
&AtClient
Procedure InformationRegisterSettingsObjectVersioning(Command)
	
	OpenForm("InformationRegister.ObjectVersioningSettings.ListForm", , ThisObject);
	
EndProcedure
// End StandardSubsystems.ObjectVersioning

// StandardSubsystems.Properties
&AtClient
Procedure AdditionalAttributes(Command)
	
	FormParameters = New Structure;
	FormParameters.Insert("ShowAdditionalAttributes");
	
	OpenForm("Catalog.AdditionalAttributesAndInformationSets.ListForm", FormParameters);
	
EndProcedure

&AtClient
Procedure AdditionalInformation(Command)
	
	FormParameters = New Structure;
	FormParameters.Insert("ShowAdditionalInformation");
	
	OpenForm("Catalog.AdditionalAttributesAndInformationSets.ListForm", FormParameters);
	
EndProcedure
// End StandardSubsystems.Properties

&AtClient
Procedure ShowCurrentSessionTime(Command)
	
	ShowMessageBox(,
		StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Session time: %1 On server: %2 On client: %3 Session time is a server time relative to the client time zone.'"),
			Format(CommonUseClient.SessionDate(), "DLF=T"),
			Format(ServerDate(), "DLF=T"),
			Format(CurrentDate(), "DLF=T")));
	
EndProcedure

// StandardSubsystems.BasicFunctionality
&AtClient
Procedure UseSecurityProfiles(Command)
	
	WorkInSafeModeClient.OpenDialogForSecurityProfilesUseSetup();
	
EndProcedure
// End of StandardSubsystems BasicFunctionality

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

&AtServer
Procedure ImportTimeZones()
	
	Items.ApplicationTimeZone.ChoiceList.LoadValues(GetAvailableTimeZones());
	
EndProcedure

&AtServerNoContext
Function ServerDate()
	
	Return CurrentDate();
	
EndFunction

#EndRegion

#Region Server

&AtServer
Procedure SaveAttributeValue(AttributePathToData, Result)
	
	// Save attribute values not connected with constants directly (one-to-one ratio).
	If AttributePathToData = "ApplicationTimeZone" Then
		If ApplicationTimeZone <> GetInfobaseTimeZone() Then 
			SetPrivilegedMode(True);
			Try
				CommonUse.LockInfobase();
				SetInfobaseTimeZone(ApplicationTimeZone);
				CommonUse.UnlockInfobase();
			Except
				CommonUse.UnlockInfobase();
				Raise;
			EndTry;
			SetPrivilegedMode(False);
			SetSessionTimeZone(ApplicationTimeZone);
		EndIf;
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
	
	// StandardSubsystems.ObjectVersioning
	If AttributePathToData = "ConstantsSet.UseObjectVersioning"
	 OR AttributePathToData = "" Then
		
		CommonUseClientServer.SetFormItemProperty(
			Items,
			"InformationRegisterSettingsObjectVersioning",
			"Enabled",
			ConstantsSet.UseObjectVersioning);
	EndIf;
	// End StandardSubsystems.ObjectVersioning
		
	// StandardSubsystems.BasicFunctionality
	If AttributePathToData = "" Then
		
		AvailabilityProxySettingsOnServer = Not GetFunctionalOption("SecurityProfilesAreUsed");
		
		CommonUseClientServer.SetFormItemProperty(
			Items,
			"OpenProxyServerParameters",
			"Enabled",
			AvailabilityProxySettingsOnServer);
		CommonUseClientServer.SetFormItemProperty(
			Items,
			"GroupProxyServerSettingIsNotAvailableatServerWhenUseSecurityProfiles",
			"Visible",
			Not AvailabilityProxySettingsOnServer);
			
	EndIf;
	// End of StandardSubsystems BasicFunctionality
	
EndProcedure

#EndRegion

#EndRegion

#Region Drive

&AtClient
Procedure PostponeEditProhibitionDateOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

&AtClient
Procedure ControlBalancesOnPostingOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

#EndRegion
