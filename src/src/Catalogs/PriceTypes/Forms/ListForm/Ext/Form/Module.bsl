////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS OF SAVING SETTINGS

&AtServer
// Procedure saves the selected item in settings.
//
Procedure SetMainItem(SelectedItem)
	
	If SelectedItem <> DriveReUse.GetValueOfSetting("MainPriceTypesales") Then
		DriveServer.SetUserSetting(SelectedItem, "MainPriceTypesales");	
		DriveServer.MarkMainItemWithBold(SelectedItem, List);
	EndIf; 
		
EndProcedure

&AtClient
// Procedure - Command execution handler SetMainItem.
//
Procedure CommandSetMainItem(Command)
		
	SelectedItem = Items.List.CurrentRow;
	If ValueIsFilled(SelectedItem) Then
		SetMainItem(SelectedItem);	
	EndIf; 
	
EndProcedure

#Region ProcedureFormEventHandlers

&AtServer
// Procedure - OnCreateAtServer event handler.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Price accessibility setup for editing.
	AllowedEditDocumentPrices = DriveAccessManagementReUse.AllowedEditDocumentPrices();
	
	Items.List.ReadOnly = Not AllowedEditDocumentPrices;
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// Selection of main item	
	DriveServer.MarkMainItemWithBold(DriveReUse.GetValueOfSetting("MainPriceTypesales"), List);
	
EndProcedure

#EndRegion
