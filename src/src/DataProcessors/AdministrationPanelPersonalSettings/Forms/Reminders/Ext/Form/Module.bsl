
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
	
	If AttributePathToData = "CheckRemindersInterval" OR AttributePathToData = "" Then
		
		UseReminders = GetFunctionalOption("UseReminders");
		CommonUseClientServer.SetFormItemProperty(Items, "RemindersSettings", "Enabled", UseReminders);
		
	EndIf;
	
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
	
	If AttributePathToData = "CheckRemindersInterval" Then
		
		CommonSettingsStorage.Save("ReminderSettings", "CheckRemindersInterval", CheckRemindersInterval);
		
	EndIf;
	
EndProcedure

// Read values from common settings storage
//
&AtServer
Procedure ReadValuesFromStoreCommonSettings(AttributePathToData = "")
	
	If AttributePathToData = "CheckRemindersInterval" OR IsBlankString(AttributePathToData) Then
		
		CheckRemindersInterval = UserRemindersService.GetCheckRemindersInterval();
		
	EndIf;
	
EndProcedure

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
	
	SetEnabled();
	
	// Work with files
	ReadValuesFromStoreCommonSettings();
	
	CheckRemindersInterval = UserRemindersService.GetCheckRemindersInterval();
	
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

// Procedure - event handler OnChange field RemindersCheckInterval
//
&AtClient
Procedure CheckIntervalRemindersOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

#EndRegion

#EndRegion
