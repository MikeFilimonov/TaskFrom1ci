﻿
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If CommonUseClientServer.ThisIsWebClient() Then
		Raise NStr("en = 'Backup is not available in web client.'");
	EndIf;
	
	If CommonUseClientServer.IsLinuxClient() Then
		Return; // Fail is set in OnOpen().
	EndIf;
	
	BackupParameters = InfobaseBackupServer.BackupParameters();
	DisableReminders = BackupParameters.BackupIsConfigured;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If CommonUseClientServer.IsLinuxClient() Then
		Cancel = True;
		MessageText = NStr("en = 'Backup is not supported on the client running Linux OS.'");
		ShowMessageBox(, MessageText);
		Return;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure OK(Command)
	
	ApplicationParameters["StandardSubsystems.IBBackupParameters"].NotificationParameter =
		?(DisableReminders, "DoNotNotify", "YetNotConfigured");
	
	If DisableReminders Then
		InfobaseBackupClient.DisableBackupWaitHandler();
	Else
		InfobaseBackupClient.EnableBackupWaitHandler();
	EndIf;
	
	OKOnServer();
	Notify("BackupSettingsSessionFormClosed");
	Close();
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure OKOnServer()
	
	BackupParameters = InfobaseBackupServer.BackupParameters();
	
	BackupParameters.BackupIsConfigured = DisableReminders;
	BackupParameters.ExecuteAutomaticBackup = False;
	
	InfobaseBackupServer.SetBackupParameters(BackupParameters);
	
EndProcedure

#EndRegion