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
	
	If Not Users.InfobaseUserWithFullAccess(Undefined, True, False) Then
		Raise NStr("en = 'Insufficient rights to administer data synchronization between applications.'");
	EndIf;
	
	// Attribute values of the form
	RunMode = CommonUseReUse.ApplicationRunningMode();
	RunMode = New FixedStructure(RunMode);
	
	SetPrivilegedMode(True);
	
	// Settings of visible on launch
	Items.GroupApplySettings.Visible = RunMode.ThisIsWebClient;
	Items.OfflineWork.Visible = OfflineWorkService.OfflineWorkSupported();
	Items.GroupTemporaryDirectoriesServersCluster.Visible = RunMode.ClientServer AND RunMode.ThisIsSystemAdministrator;
	
	// Update items states
	SetEnabled();
	
EndProcedure

&AtClient
Procedure OnClose(Exit)
	
	If Exit Then
		Return;
	EndIf;

	#If Not WebClient Then
		RefreshApplicationInterface();
	#EndIf
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure HowToApplySettingsNavigationRefProcessing(Item, URL, StandardProcessing)
	StandardProcessing = False;
	RefreshInterface = True;
	AttachIdleHandler("RefreshApplicationInterface", 0.1, True);
EndProcedure

&AtClient
Procedure DataExchangeMessagesDirectoryForWindowsOnChange(Item)
	Attachable_OnAttributeChange(Item);
EndProcedure

&AtClient
Procedure DataExchangeMessagesDirectoryForLinuxOnChange(Item)
	Attachable_OnAttributeChange(Item);
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure MonitorSynchronizationData(Command)
	
	OpenForm("CommonForm.DataSyncMonitorSaaS",, ThisObject);
	
EndProcedure

&AtClient
Procedure ExchangeTransportSettings(Command)
	
	OpenForm("InformationRegister.ExchangeTransportSettings.ListForm",, ThisObject);
	
EndProcedure

&AtClient
Procedure DataAreasTransportExchangeSettings(Command)
	
	OpenForm("InformationRegister.DataAreasTransportExchangeSettings.ListForm",, ThisObject);
	
EndProcedure

&AtClient
Procedure DataExchangeRules(Command)
	
	OpenForm("InformationRegister.DataExchangeRules.ListForm",, ThisObject);
	
EndProcedure

&AtClient
Procedure UseDataSyncOnChange(Item)
	
	If ConstantsSet.UseDataSync = False Then
		ConstantsSet.OfflineSaaS = False;
		ConstantsSet.UseDataSyncSaaSWithLocalApplication = False;
		ConstantsSet.UseDataSyncSaaSWithApplicationInInternet = False;
	EndIf;
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

&AtClient
Procedure OfflineSaaSOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

&AtClient
Procedure UseDataSyncSaaSWithApplicationInInternetOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

&AtClient
Procedure UseDataSyncSaaSWithLocalApplicationOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

#Region Client

&AtClient
Procedure Attachable_OnAttributeChange(Item, RefreshingInterface = True)
	
	Result = OnAttributeChangeServer(Item.Name);
	
	If RefreshingInterface Then
		RefreshInterface = True;
		AttachIdleHandler("RefreshApplicationInterface", 1, True);
	EndIf;
	
	StandardSubsystemsClient.ShowExecutionResult(ThisObject, Result);
	
EndProcedure

&AtClient
Procedure RefreshApplicationInterface()
	
	If RefreshInterface = True Then
		RefreshInterface = False;
		CommonUseClient.RefreshApplicationInterface();
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
	
	If AttributePathToData = "ConstantsSet.UseDataSync" OR AttributePathToData = "" Then
		Items.DataSynchronizationSubordinatedGrouping.Enabled           = ConstantsSet.UseDataSync;
		Items.GroupDataSynchronizationMonitorSynchronizationData.Enabled = ConstantsSet.UseDataSync;
		Items.GroupTemporaryDirectoriesServersCluster.Enabled             = ConstantsSet.UseDataSync;
	EndIf;
	
EndProcedure

#EndRegion

#EndRegion
