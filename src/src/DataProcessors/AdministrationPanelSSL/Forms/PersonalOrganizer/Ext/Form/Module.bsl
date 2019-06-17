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
	
	// Form attribute values.
	RunMode = CommonUseReUse.ApplicationRunningMode();
	RunMode = New FixedStructure(RunMode);
	
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

// StandardSubsystems.UserReminders
&AtClient
Procedure UseRemindersUserOnChange(Item)
	Attachable_OnAttributeChange(Item);
EndProcedure
// End StandardSubsystems.UserReminders

#EndRegion

#Region FormCommandsHandlers

// Procedure - command handler UsersReminders
// 
&AtClient
Procedure UsersReminders(Command)
	
	OpenForm("InformationRegister.UserReminders.ListForm");
	
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
		
		If (ConstantName = "UseEmailClient" OR ConstantName = "UseBusinessProcessesAndTasks") AND ConstantValue = False Then
			ThisObject.Read();
		EndIf;
		
		StandardSubsystemsClientServer.ExecutionResultAddNotificationOfOpenForms(Result, "Record_ConstantsSet", New Structure, ConstantName);
		// StandardSubsystems.ReportsVariants
		ReportsVariants.AddNotificationOnValueChangeConstants(Result, ConstantManager);
		// End StandardSubsystems.ReportsVariants
	EndIf;
	
EndProcedure

&AtServer
Procedure SetEnabled(AttributePathToData = "")
	
	If AttributePathToData = "ConstantsSet.UseReminders" Or AttributePathToData = "" Then
		
		CommonUseClientServer.SetFormItemProperty(Items, "UsersReminders", "Enabled", ConstantsSet.UseReminders);
		
	EndIf;
	
EndProcedure

#EndRegion

#EndRegion
