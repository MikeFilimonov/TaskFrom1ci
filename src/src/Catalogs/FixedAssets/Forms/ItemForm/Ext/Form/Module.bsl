﻿#Region GeneralPurposeProceduresAndFunctions

&AtClient
// Procedure sets the form attribute visible.
//
// Parameters:
//  No.
//
Procedure SetAttributesVisible()
	
	If Object.DepreciationMethod = ProportionallyToProductsVolume Then
		Items.MeasurementUnit.Visible = True;
	Else
		Items.MeasurementUnit.Visible = False;
		Object.MeasurementUnit = Undefined;
	EndIf;
	
EndProcedure

#EndRegion

#Region ProcedureFormEventHandlers

&AtServer
// Procedure-handler of the OnCreateAtServer event.
// Performs initial filling and sets
// form attribute visible.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	ProportionallyToProductsVolume = Enums.FixedAssetDepreciationMethods.ProportionallyToProductsVolume;
	PresentationCurrency = Constants.PresentationCurrency.Get();
	
	If Object.DepreciationMethod = ProportionallyToProductsVolume Then
		Items.MeasurementUnit.Visible = True;
	Else
		Items.MeasurementUnit.Visible = False;
		Object.MeasurementUnit = Undefined;
	EndIf;
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.Printing
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "AccountsChangedFixedAssets" Then
		Object.GLAccount = Parameter.GLAccount;
		Object.DepreciationAccount = Parameter.DepreciationAccount;
		Modified = True;
	EndIf;
	
EndProcedure

#EndRegion

#Region ProcedureEventHandlersOfFormAttributes

&AtClient
// Event handler procedure OnChange of input field DepreciationMethod.
//
Procedure DepreciationMethodOnChange(Item)
	
	SetAttributesVisible();
	
EndProcedure

#Region LibrariesHandlers

// StandardSubsystems.AdditionalReportsAndDataProcessors
&AtClient
Procedure Attachable_ExecuteAssignedCommand(Command)
	If Not AdditionalReportsAndDataProcessorsClient.ExecuteAllocatedCommandAtClient(ThisForm, Command.Name) Then
		ExecutionResult = Undefined;
		AdditionalReportsAndProcessingsExecuteAllocatedCommandAtServer(Command.Name, ExecutionResult);
		AdditionalReportsAndDataProcessorsClient.ShowCommandExecutionResult(ThisForm, ExecutionResult);
	EndIf;
EndProcedure

&AtServer
Procedure AdditionalReportsAndProcessingsExecuteAllocatedCommandAtServer(ItemName, ExecutionResult)
	AdditionalReportsAndDataProcessors.ExecuteAllocatedCommandAtServer(ThisForm, ItemName, ExecutionResult);
EndProcedure
// End StandardSubsystems.AdditionalReportsAndDataProcessors

// StandardSubsystems.Printing
&AtClient
Procedure Attachable_ExecutePrintCommand(Command)
	PrintManagementClient.ExecuteConnectedPrintCommand(Command, ThisObject, Object);
EndProcedure
// End StandardSubsystems.Printing

#EndRegion

#EndRegion
