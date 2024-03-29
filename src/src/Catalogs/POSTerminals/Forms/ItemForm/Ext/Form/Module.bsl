﻿
#Region GeneralPurposeProceduresAndFunctions

// Function generates a bank account description.
//
&AtClient
Function MakeAutoDescription()
	
	Items.Description.ChoiceList.Clear();
	
	DescriptionString = NStr("en = 'POS terminal'") + " (" + String(Object.PettyCash) + ")";
	DescriptionString = Left(DescriptionString, 100);
	
	Items.Description.ChoiceList.Add(DescriptionString);
	
	Return DescriptionString;

EndFunction

#EndRegion

#Region ProcedureFormEventHandlers

// Procedure - form event handler "OnCreateAtServer".
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Not ValueIsFilled(Object.Ref) AND Not ValueIsFilled(Parameters.CopyingValue) Then
		SettingValue = DriveReUse.GetValueByDefaultUser(
			Users.CurrentUser(),
			"MainCompany"
		);
		If ValueIsFilled(SettingValue) Then
			Object.Company = SettingValue;
		Else
			Object.Company = Catalogs.Companies.MainCompany;
		EndIf;
		If Not Constants.UsePeripherals.Get() Then
			Object.UseWithoutEquipmentConnection = True;
		EndIf;
	EndIf;
	
	If Object.UseWithoutEquipmentConnection
	AND Not Constants.UsePeripherals.Get() Then
		Items.UseWithoutEquipmentConnection.Enabled = False;
	EndIf;
	
	Items.Peripherals.Enabled = Not Object.UseWithoutEquipmentConnection;
	
	// Subsystem for prohibition of editing the key object attributes.
	ObjectsAttributesEditProhibition.LockAttributes(ThisForm);
	
EndProcedure

// Procedure - form event handler "BeforeWrite".
//
&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)

	If IsBlankString(Object.Description) Then
		Object.Description = MakeAutoDescription();
	EndIf;
	
EndProcedure

// Procedure - form event handler "AfterWriteAtServer".
//
&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	// editing prohibition subsystem of key object attributes	
	ObjectsAttributesEditProhibition.LockAttributes(ThisForm);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	MakeAutoDescription();
	
EndProcedure

&AtClient
Procedure UseWithoutEquipmentConnectionOnChange(Item)
	
	Items.Peripherals.Enabled = Not Object.UseWithoutEquipmentConnection;
	
EndProcedure

&AtClient
Procedure PettyCashOnChange(Item)
	
	MakeAutoDescription();
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "GLAccountChangedPOSTerminals" Then
		Object.GLAccount = Parameter.GLAccount;
		Modified = True;
	EndIf;
	
EndProcedure

#EndRegion
