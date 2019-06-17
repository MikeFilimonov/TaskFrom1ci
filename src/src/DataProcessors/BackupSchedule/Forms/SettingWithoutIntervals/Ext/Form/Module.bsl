#Region Variables

&AtClient
Var ResponseBeforeClose;

#EndRegion

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	BackupSettings = DataAreasBackup.GetZoneBackupSettings(
		SaaSOperations.SessionSeparatorValue());
	FillPropertyValues(ThisObject, BackupSettings);
	
	For MonthNumber = 1 To 12 Do
		Items.AnnualCopiesFormingMonth.ChoiceList.Add(MonthNumber, 
			Format(Date(2, MonthNumber, 1), "DF=MMMM"));
	EndDo;
	
	TimeZone = SessionTimeZone();
	TimeZoneAreas = TimeZone + " (" + TimeZonePresentation(TimeZone) + ")";
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	If NOT Modified Then
		Return;
	EndIf;
	
	If Exit Then
		WarningText = NStr("en = 'Changes will be lost'");
		Return;	
	EndIf;
	
	If ResponseBeforeClose <> True Then
		Cancel = True;
		NotifyDescription = New NotifyDescription("BeforeCloseEnd", ThisObject);
		ShowQueryBox(NotifyDescription, NStr("en = 'Settings were changed. Do you want to save changes?'"), 
			QuestionDialogMode.YesNoCancel, , DialogReturnCode.Yes);
	EndIf;
		
EndProcedure
		
&AtClient
Procedure BeforeCloseEnd(Response, AdditionalParameters) Export	
	
	If Response = DialogReturnCode.Cancel Then
		Return;
	EndIf;
	
	If Response = DialogReturnCode.Yes Then
		WriteSettingsBackup();
	EndIf;
	ResponseBeforeClose = True;
    Close();
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure SetDefault(Command)
	
	SetByDefaultAtServer();
	
EndProcedure

&AtClient
Procedure WriteAndClose(Command)
	
	WriteSettingsBackup();
	Modified = False;
	Close(DialogReturnCode.OK);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure SetByDefaultAtServer()
	
	BackupSettings = DataAreasBackup.GetZoneBackupSettings();
	FillPropertyValues(ThisObject, BackupSettings);
	
EndProcedure

&AtServer
Procedure WriteSettingsBackup()

	SettingsCorrespondence = DataAreasBackupReUse.RussianSettingsFieldsNamesToEnglishMap();
	
	BackupSettings = New Structure;
	For Each KeyAndValue In SettingsCorrespondence Do
		BackupSettings.Insert(KeyAndValue.Value, ThisObject[KeyAndValue.Value]);
	EndDo;
	
	DataAreasBackup.SetZoneBackupSettings(
		SaaSOperations.SessionSeparatorValue(), BackupSettings);
		
EndProcedure

#EndRegion
