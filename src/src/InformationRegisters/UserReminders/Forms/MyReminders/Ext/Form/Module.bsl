﻿
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	If Not CommonUse.OnCreateAtServer(ThisObject, Cancel, StandardProcessing) Then
		Return;
	EndIf;
	
	List.Parameters.SetParameterValue("User", Users.CurrentUser());
	
EndProcedure

#EndRegion

#Region FormTableItemsEventsHandlersList

&AtClient
Procedure ListBeforeRowChange(Item, Cancel)
	Cancel = True;
	OpenForm("InformationRegister.UserReminders.Form.Reminder", New Structure("Key", Items.List.CurrentRow));
EndProcedure

&AtClient
Procedure ListOnActivateRow(Item)
	StringSelected = Not Item.CurrentRow = Undefined;
	Items.ButtonDelete.Enabled = StringSelected;
	Items.ButtonChange.Enabled = StringSelected;
EndProcedure

&AtClient
Procedure ListBeforeDelete(Item, Cancel)
	Cancel = True;
	DeleteReminder();
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure Change(Command)
	OpenForm("InformationRegister.UserReminders.Form.Reminder", New Structure("Key", Items.List.CurrentRow));
EndProcedure

&AtClient
Procedure Delete(Command)
	DeleteReminder();
EndProcedure

&AtClient
Procedure Create(Command)
	OpenForm("InformationRegister.UserReminders.Form.Reminder");
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure DisableReminder(ReminderParameters)
	UserRemindersService.DisableReminder(ReminderParameters, False);
EndProcedure

&AtClient
Procedure DeleteReminder()
	
	DialogButtons = New ValueList;
	DialogButtons.Add(DialogReturnCode.Yes, NStr("en = 'Delete'"));
	DialogButtons.Add(DialogReturnCode.Cancel, NStr("en = 'Do not delete'"));
	NotifyDescription = New NotifyDescription("DeleteReminderEnd", ThisObject);
	
	ShowQueryBox(NotifyDescription, NStr("en = 'Dismiss the reminder?'"), DialogButtons);
	
EndProcedure

&AtClient
Procedure DeleteReminderEnd(QuestionResult, AdditionalParameters) Export
	
	If QuestionResult <> DialogReturnCode.Yes Then
		Return;
	EndIf;

	RecordKey = Items.List.CurrentRow;
	ReminderParameters = New Structure("User,EventTime,Source");
	FillPropertyValues(ReminderParameters, Items.List.CurrentData);
	
	DisableReminder(ReminderParameters);
	UserRemindersClient.DeleteRecordFromNotificationCache(ReminderParameters);
	Notify("Record_UserReminders", New Structure, RecordKey);
	NotifyChanged(Type("InformationRegisterRecordKey.UserReminders"));
	
EndProcedure

#EndRegion
