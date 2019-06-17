////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS OF SAVING SETTINGS

&AtServer
// Procedure saves the selected item in settings.
//
Procedure SetMainItem(SelectedItem)
	
	If SelectedItem <> DriveReUse.GetValueOfSetting("MainResponsible") Then
		DriveServer.SetUserSetting(SelectedItem, "MainResponsible");	
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
	
	// Setting current row.
	If Parameters.Property("Responsible")
		AND ValueIsFilled(Parameters.Responsible) Then
		
		Items.List.CurrentRow = Parameters.Responsible;
		
	EndIf;
	
	// Main item allocation.
	DriveServer.MarkMainItemWithBold(DriveReUse.GetValueOfSetting("MainResponsible"), List);
	
EndProcedure
// 

#EndRegion
