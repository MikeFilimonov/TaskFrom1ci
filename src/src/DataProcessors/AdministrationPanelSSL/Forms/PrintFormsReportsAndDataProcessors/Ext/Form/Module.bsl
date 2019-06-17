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
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	Items.GroupOpenAdditionalReportsAndDataProcessors.Visible = RunMode.Local Or RunMode.Standalone; 
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
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

#Region FormCommandHandlers

// StandardSubsystems.AdditionalReportsAndDataProcessors
&AtClient
Procedure CatalogAdditionalReportsAndDataProcessors(Command)
	
	OpenForm("Catalog.AdditionalReportsAndDataProcessors.ListForm", , ThisObject);
	
EndProcedure
// End StandardSubsystems.AdditionalReportsAndDataProcessors

#EndRegion

#EndRegion

#Region ServiceProceduresAndFunctions

#Region Client

&AtClient
Procedure RefreshApplicationInterface()
	
	If RefreshInterface = True Then
		RefreshInterface = False;
		RefreshInterface();
	EndIf;
	
EndProcedure

#EndRegion

#EndRegion
