#Region FormEventHandlers

&AtServer
// Procedure - OnCreateAtServer event handler.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Selection of main item
	List.Parameters.SetParameterValue("UserSetting", ChartsOfCharacteristicTypes.UserSettings["StatusOfNewWorkOrder"]);
	List.Parameters.SetParameterValue("CurrentUser", Users.CurrentUser());
	
	PaintList();
	
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
		Items.FormCommandSetMainItem.Title = NStr("en = 'Used to create new orders'");
		Items.FormCommandSetMainItem.Enabled = False;
	Else
		Items.FormCommandSetMainItem.Title = "";
		Items.FormCommandSetMainItem.Enabled = True;
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtClient
// Procedure - Command execution handler SetMainItem.
//
Procedure CommandSetMainItem(Command)
	
	SelectedItem = Items.List.CurrentRow;
	If ValueIsFilled(SelectedItem) Then
		DriveServer.SetUserSetting(SelectedItem, "StatusOfNewWorkOrder");
		Items.List.Refresh();
	EndIf;
	
EndProcedure

// Procedure colors the list.
//
&AtServer
Procedure PaintList()
	
	ConditionalAppearanceItem = List.SettingsComposer.Settings.ConditionalAppearance.Items.Add();
	
	FilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	
	FilterItem.LeftValue = New DataCompositionField("MainSetting");
	FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
	FilterItem.RightValue = True;
	
	ConditionalAppearanceItem.Appearance.SetParameterValue("Font", New Font(,, True));
	
	ConditionalAppearanceItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	ConditionalAppearanceItem.UserSettingID = "Preset";
	ConditionalAppearanceItem.Presentation = NStr("en = 'Order is canceled'");
	
EndProcedure

#EndRegion