////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS OF SAVING SETTINGS

&AtClient
// Procedure - Command execution handler SetMainItem.
//
Procedure CommandSetMainItem(Command)
		
	SelectedItem = Items.List.CurrentRow;
	If ValueIsFilled(SelectedItem) Then
		DriveServer.SetUserSetting(SelectedItem, "StatusOfNewSalesOrder");
		Items.List.Refresh();
	EndIf;
	
EndProcedure

#Region ProcedureFormEventHandlers

&AtServer
// Procedure - OnCreateAtServer event handler.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
		
	// Selection of main item	
	List.Parameters.SetParameterValue("UserSetting", ChartsOfCharacteristicTypes.UserSettings["StatusOfNewSalesOrder"]);
	List.Parameters.SetParameterValue("CurrentUser", Users.CurrentUser());
	
EndProcedure

&AtClient
// Procedure - event handler NotificationProcessing.
//
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "UserSettingsChanged" Then
		Items.List.Refresh();
	EndIf;
	
EndProcedure

&AtClient
// Procedure - event handler OnActivateRow.
//
Procedure ListOnActivateRow(Item)
	
	MainSetting = Items.List.CurrentData.MainSetting;
	
	If MainSetting Then
		Items.FormCommandSetMainItem.Title = "Used to create new orders";
		Items.FormCommandSetMainItem.Enabled = False;
	Else
		Items.FormCommandSetMainItem.Title = "";
		Items.FormCommandSetMainItem.Enabled = True;
	EndIf;
	
EndProcedure
// 

#EndRegion
