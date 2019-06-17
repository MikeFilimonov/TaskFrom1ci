#Region FormEventHandlers

// Procedure OnCreateAtServer
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If ValueIsFilled(Object.Ref) Then
		Color = Object.Ref.Color.Get();
		If Object.Ref = DriveReUse.GetValueOfSetting("StatusOfNewWorkOrder") Then
			Items.FormCommandSetMainItem.Title = NStr("en = 'Used to create new orders'");
			Items.FormCommandSetMainItem.Enabled = False;
		EndIf;
	Else
		CopyingValue = Undefined;
		Parameters.Property("CopyingValue", CopyingValue);
		If CopyingValue <> Undefined Then
			Color = CopyingValue.Color.Get();
		Else
			Color = New Color(0, 0, 0);
		EndIf;
	EndIf;
	
EndProcedure

// Procedure BeforeWriteAtServer
//
&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	If Color = New Color(0, 0, 0) Then
		CurrentObject.Color = New ValueStorage(Undefined);
	Else
		CurrentObject.Color = New ValueStorage(Color);
	EndIf;
	
EndProcedure

// Procedure - Command execution handler SetMainItem.
//
&AtClient
Procedure CommandSetMainItem(Command)
	
	If ValueIsFilled(Object.Ref) Then
		SetMainItem();
		Notify("UserSettingsChanged");
	Else
		ShowMessageBox(Undefined, NStr("en = 'Write the item first.'"));
	EndIf;
	
EndProcedure

// Procedure BeforeWrite
//
&AtClient
Procedure AfterWrite(WriteParameters)
	
	Notify("Record_WorkOrderStates");
	
EndProcedure

#EndRegion

#Region Private

// Procedure saves the selected item in settings.
//
&AtServer
Procedure SetMainItem()
	
	If Object.Ref <> DriveReUse.GetValueOfSetting("StatusOfNewWorkOrder") Then
		DriveServer.SetUserSetting(Object.Ref, "StatusOfNewWorkOrder");
		Items.FormCommandSetMainItem.Title = NStr("en = 'Used to create new orders'");
		Items.FormCommandSetMainItem.Enabled = False;
	EndIf;
	
EndProcedure

#EndRegion
