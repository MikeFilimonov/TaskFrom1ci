﻿
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	If CommonUseClientServer.IsLinuxClient() Then
		Return; // Fail is set in OnOpen().
	EndIf;
	
	If CommonUseClientServer.ThisIsWebClient() Then
		Raise NStr("en = 'Backup is not available in web client.'");
	EndIf;
	
	If Not CommonUse.FileInfobase() Then
		Raise NStr("en = 'Back up data using external tools (DBMS tools) in the client/server mode.'");
	EndIf;
	
	BackupSettings = InfobaseBackupServer.BackupSettings();
	IBAdministratorPassword = BackupSettings.IBAdministratorPassword;
	Object.BackupDirectory = BackupSettings.DirectoryStorageOfBackupCopies;
	
	If InfobaseSessionCount() > 1 Then
		
		Items.RestoreStatusPages.CurrentPage = Items.ActiveUsersPage;
		
	EndIf;
	
	// First part of the check on server - if there are users in the infobase.
	PasswordEnterIsRequired = (InfobaseUsers.GetUsers().Count() > 0);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If CommonUseClientServer.IsLinuxClient() Then
		Cancel = True;
		MessageText = NStr("en = 'Backup is not available on the client running Linux OS.'");
		ShowMessageBox(,MessageText);
		Return;
	EndIf;
	
	ClientWorkParameters = StandardSubsystemsClientReUse.ClientWorkParameters();
	UserInfo = ClientWorkParameters.UserInfo;
	
	// Second part of the check on client - if current user
	// (administrator) uses standard authentication and the password is set.
	PasswordEnterIsRequired = PasswordEnterIsRequired AND UserInfo.StandardAuthentication AND UserInfo.PasswordIsSet;
	
	If PasswordEnterIsRequired Then
		InfobaseAdministrator = UserInfo.Name;
	Else
		Items.GroupAuthorization.Visible = False;
	EndIf;
	
#If WebClient Then
	Items.GroupComcntrFileMode.Visible = False;
#EndIf
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	CurrentPage = Items.DataImportPages.CurrentPage;
	If CurrentPage = Items.DataImportPages.ChildItems.InformationAndBackupPerformingPage Then
		
		WarningText = NStr("en = 'Do you want to stop preparing to restore data?'");
		CommonUseClient.ShowArbitraryFormClosingConfirmation(ThisObject,
			Cancel, Exit, WarningText, "ForceCloseForm");
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OnClose(Exit)
	
	DetachIdleHandler("TimeOutLapse");
	DetachIdleHandler("CheckThatConnectionIsSingle");
	DetachIdleHandler("TerminateUserSessions");

EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	If EventName = "UserSessions" AND Parameter.NumberOfSessions <= 1
		AND Items.DataImportPages.CurrentPage = Items.InformationAndBackupPerformingPage Then
			StartBackup();
	EndIf;
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure PathToArchivesDirectoryStartChoice(Item, ChoiceData, StandardProcessing)
	
	SelectBackupFile();
	
EndProcedure

&AtClient
Procedure UsersListClick(Item)
	
	OpenForm("DataProcessor.ActiveUsers.Form.ActiveUsersListForm", , ThisObject);
	
EndProcedure

&AtClient
Procedure UpdateVersionLabelComponentsNavigationRefDataProcessor(Item, URL, StandardProcessing)
	StandardProcessing = False;
	CommonUseClient.RegisterCOMConnector();
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure FormCancel(Command)
	
	Close();
	
EndProcedure

&AtClient
Procedure Done(Command)
	
	ClearMessages();
	
	If Not CheckAttributesFilling() Then
		Return;
	EndIf;
	
	Pages = Items.DataImportPages;
	
	If InfobaseBackupClient.ValidateAccessToInformationBase(IBAdministratorPassword) Then
		SetBackupParameters();
	Else
		Items.RestoreStatusPages.CurrentPage = Items.RestoreStatusPages.ChildItems.ConnectionErrorPage;
		Return;
	EndIf;

	Pages.CurrentPage = Items.InformationAndBackupPerformingPage; 
	Items.Close.Enabled = True;
	Items.Done.Enabled = False;
	
	InfobaseSessionCount = InfobaseSessionCount();
	Items.ActiveUserCount.Title = InfobaseSessionCount;
	
	SetConnectionLock = True;
	InfobaseConnectionsServerCall.SetConnectionLock(NStr("en = 'Infobase recovery is in progress.'"), "Backup");
	
	If InfobaseSessionCount = 1 Then
		InfobaseConnectionsClient.SetUserTerminationInProgressFlag(SetConnectionLock);
		InfobaseConnectionsClient.TerminateThisSession(False);
		StartBackup();
	Else
		InfobaseConnectionsClient.SetIdleHandlerOfUserSessionsTermination(SetConnectionLock);
		SetBackupBeginIdleHandler();
		SetBackupTimeoutLapseIdleHandler();
	EndIf;
	
EndProcedure

&AtClient
Procedure GoToEventLogMonitor(Command)
	OpenForm("DataProcessor.EventLogMonitor.Form.EventLogMonitor", , ThisObject);
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// Enables the handler of the timeout end waiting before
// an enforced launch of the backup/data restoration.
&AtClient
Procedure SetBackupTimeoutLapseIdleHandler()
	
	AttachIdleHandler("TimeOutLapse", 300, True);
	
EndProcedure

// Enables a waiting handler during the postponed backup.
&AtClient
Procedure SetBackupBeginIdleHandler() 
	
	AttachIdleHandler("CheckThatConnectionIsSingle", 60);
	
EndProcedure

// Function asks a user and returns a path to file or directory.
&AtClient
Procedure SelectBackupFile()
	
	FileOpeningDialog = New FileDialog(FileDialogMode.Open);
	FileOpeningDialog.Filter = NStr("en = 'Archive with backup (*.zip)|*.zip'");
	FileOpeningDialog.Title= NStr("en = 'Select a backup file'");
	FileOpeningDialog.CheckFileExist = True;
	
	If FileOpeningDialog.Choose() Then
		
		Object.BackupImportingFile = FileOpeningDialog.FullFileName;
		
	EndIf;
	
EndProcedure

&AtClient
Function CheckAttributesFilling()
	
	AttributesFilled = True;
	
	If PasswordEnterIsRequired AND IsBlankString(IBAdministratorPassword) Then
		MessageText = NStr("en = 'Administrator password is not specified.'");
		CommonUseClientServer.MessageToUser(MessageText,, "IBAdministratorPassword");
		AttributesFilled = False;
	EndIf;
	
	FileName = Object.BackupImportingFile;
	
	If IsBlankString(FileName) Then
		MessageText = NStr("en = 'Backup file is not selected.'");
		CommonUseClientServer.MessageToUser(MessageText,, "Object.BackupImportingFile");
		Return False;
	EndIf;
	
	FileOfArchive = New File(FileName);
	If FileOfArchive.Extension <> ".zip" Then
		
		MessageText = NStr("en = 'The selected file is not an archive with backup.'");
		CommonUseClientServer.MessageToUser(MessageText,, "Object.BackupImportingFile");
		Return False;
		
	EndIf;
	
	#If Not WebClient Then
		ZipFile = New ZipFileReader(FileName);
		If ZipFile.Items.Count() <> 1 Then
			
			MessageText = NStr("en = 'The selected file is not an archive with backup (contains more than one file).'");
			CommonUseClientServer.MessageToUser(MessageText,, "Object.BackupImportingFile");
			Return False;
			
		EndIf;
		
		FileInArchive = ZipFile.Items[0];
		
		If UPPER(FileInArchive.Extension) <> "1CD" Then
			
			MessageText = NStr("en = 'The selected file is not an archive with backup (does not contain an infobase file).'");
			CommonUseClientServer.MessageToUser(MessageText,, "Object.BackupImportingFile");
			Return False;
			
		EndIf;
		
		If UPPER(FileInArchive.BaseName) <> "1CV8" Then
			
			MessageText = NStr("en = 'The selected file is not an archive with backup (invalid name of infobase file).'");
			CommonUseClientServer.MessageToUser(MessageText,, "Object.BackupImportingFile");
			Return False;
			
		EndIf;
	#EndIf
	
	Return AttributesFilled;
	
EndFunction

#Region ProceduresOfWaitingHandlers

&AtClient
Procedure TimeOutLapse()
	
	DetachIdleHandler("CheckThatConnectionIsSingle");
	CancelPreparation();
	
EndProcedure

&AtServer
Procedure CancelPreparation()
	
	Items.LabelItWasNotPossible.Title = StringFunctionsClientServer.SubstituteParametersInString(NStr("en = '%1.
	                                                                                                  |Preparation for data restoration from the backup is cancelled. Infobase is locked.'"),
		InfobaseConnections.EnabledSessionsMessage());
	Items.DataImportPages.CurrentPage = Items.PageOfErrorsOnCopying;
	Items.Done.Visible = False;
	Items.Close.Title = NStr("en = 'Close'");
	Items.Close.DefaultButton = True;
	
	InfobaseConnections.AllowUsersWork();
	
EndProcedure

&AtClient
Procedure CheckThatConnectionIsSingle()
	
	If InfobaseSessionCount() = 1 Then
		StartBackup();
	EndIf;
	
EndProcedure

&AtClient
Procedure StartBackup() 
	
	ScriptMainFileName = GenerateUpdateScriptFiles();
	EventLogMonitorClient.AddMessageForEventLogMonitor(InfobaseBackupClient.EventLogMonitorEvent(), 
		"Information",
		NStr("en = 'Infobase backup is in progress:'") + " " + ScriptMainFileName);
	
	ForceCloseForm = True;
	Close();
	
	ApplicationParameters.Insert("StandardSubsystems.SkipAlertBeforeExit", True);
	
	Exit(False);
	RunApp("""" + ScriptMainFileName + """",	InfobaseBackupClient.GetFileDir(ScriptMainFileName));
	
EndProcedure

#EndRegion

#Region PreparationForDataRestoration

&AtClient
Function GenerateUpdateScriptFiles() 
	
	ParametersOfCopying		= InfobaseBackupClient.ClientParametersOfBackup();
	ClientWorkParameters	= StandardSubsystemsClientReUse.ClientWorkParameters();
	CreateDirectory(ParametersOfCopying.UpdateTempFilesDir);
	
	// Structure of the parameters is required for defining them on client and passing to server.
	ParametersStructure = New Structure;
	ParametersStructure.Insert("ApplicationFileName",				ParametersOfCopying.ApplicationFileName);
	ParametersStructure.Insert("EventLogMonitorEvent",				ParametersOfCopying.EventLogMonitorEvent);
	ParametersStructure.Insert("COMConnectorName",					ClientWorkParameters.COMConnectorName);
	ParametersStructure.Insert("ThisIsBasicConfigurationVersion",	ClientWorkParameters.ThisIsBasicConfigurationVersion);
	ParametersStructure.Insert("FileInfobase",						ClientWorkParameters.FileInfobase);
	ParametersStructure.Insert("ScriptParameters",					InfobaseBackupClient.AdministratorAuthenticationParametersUpdate(IBAdministratorPassword));
	
	TemplateNames = "AdditionalBackupFile";
	TemplateNames = TemplateNames + ",RecoverySplashScreen";
	
	TemplateTexts = GetTextsOfTemplates(TemplateNames, ParametersStructure, ApplicationParameters["StandardSubsystems.MessagesForEventLogMonitor"]);
	
	ScriptFile = New TextDocument;
	ScriptFile.Output = UseOutput.Enable;
	ScriptFile.SetText(TemplateTexts[0]);
	
	ScriptFileName = ParametersOfCopying.UpdateTempFilesDir + "main.js";
	ScriptFile.Write(ScriptFileName, "UTF-16");
	
	// Helper file: helpers.js.
	ScriptFile = New TextDocument;
	ScriptFile.Output = UseOutput.Enable;
	ScriptFile.SetText(TemplateTexts[1]);
	ScriptFile.Write(ParametersOfCopying.UpdateTempFilesDir + "helpers.js", "UTF-16");
	
	ScriptMainFileName = Undefined;
	// Helper file: splash.png.
	PictureLib.ExternalActionSplash.Write(ParametersOfCopying.UpdateTempFilesDir + "splash.png");
	// Helper file: splash.ico.
	PictureLib.ExternalActionSplashIcon.Write(ParametersOfCopying.UpdateTempFilesDir + "splash.ico");
	// Helper file: progress.gif.
	PictureLib.LongOperation48.Write(ParametersOfCopying.UpdateTempFilesDir + "progress.gif");
	// Main splash screen file: splash.hta.
	ScriptMainFileName = ParametersOfCopying.UpdateTempFilesDir + "splash.hta";
	
	ScriptFile = New TextDocument;
	ScriptFile.Output = UseOutput.Enable;
	ScriptFile.SetText(TemplateTexts[2]);
	ScriptFile.Write(ScriptMainFileName, "UTF-16");
	
	Return ScriptMainFileName;
	
EndFunction

&AtServer
Function GetTextsOfTemplates(TemplateNames, ParametersStructure, MessagesForEventLogMonitor)
	
	// Write accumulated ELM events.
	
	EventLogMonitor.WriteEventsToEventLogMonitor(MessagesForEventLogMonitor);
	
	Result = New Array();
	Result.Add(GetScriptText(ParametersStructure));
	
	TemplateNamesArray = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(TemplateNames);
	For Each TemplateName In TemplateNamesArray Do
		Result.Add(DataProcessors.BackupInfobase.GetTemplate(TemplateName).GetText());
	EndDo;
	Return Result;
	
EndFunction

&AtServer
Function GetScriptText(ParametersStructure)
	
	// Configuration update file: main.js.
	ScriptTemplate = DataProcessors.BackupInfobase.GetTemplate("IBImportFileTemplate");
	
	Script = ScriptTemplate.GetArea("ParameterArea");
	Script.DeleteLine(1);
	Script.DeleteLine(Script.LineCount());
	
	Text = ScriptTemplate.GetArea("BackupArea");
	Text.DeleteLine(1);
	Text.DeleteLine(Text.LineCount());
	
	Return InsertScriptParameters(Script.GetText(), ParametersStructure) + Text.GetText();
	
EndFunction

&AtServer
Function InsertScriptParameters(Val Text, Val ParametersStructure)
	
	Result = Text;
	
	FileNamesUpdate = "";
	FileNamesUpdate = "[" + "" + "]";
	
	InfobaseConnectionString = ParametersStructure.ScriptParameters.InfobaseConnectionString +
	ParametersStructure.ScriptParameters.ConnectionString; 
	
	ApplicationExecutableFileName = BinDir() + ParametersStructure.ApplicationFileName;
	
	// Define a path to infobase.
	FileModeFlag = Undefined;
	InformationBasePath = InfobaseConnectionsClientServer.InformationBasePath(FileModeFlag, 0);
	
	ParameterOfPathToInformationBase = ?(FileModeFlag, "/F", "/S") + InformationBasePath; 
	InfobasePathString	= ?(FileModeFlag, InformationBasePath, "");
	
	Result = StrReplace(Result, "[UpdateFilesNames]"				, FileNamesUpdate);
	Result = StrReplace(Result, "[ExecutedApplicationFileName]"		, PrepareText(ApplicationExecutableFileName));
	Result = StrReplace(Result, "[PathToInfobaseParameter]"		, PrepareText(ParameterOfPathToInformationBase));
	Result = StrReplace(Result, "[RowPathToInfobaseFile]"	, PrepareText(CommonUseClientServer.AddFinalPathSeparator(StrReplace(InfobasePathString, """", ""))));
	Result = StrReplace(Result, "[InfobaseConnectionRow]"	, PrepareText(InfobaseConnectionString));
	Result = StrReplace(Result, "[UserAuthenticationParameters]"	, PrepareText(ParametersStructure.ScriptParameters.AuthenticationParameters));
	Result = StrReplace(Result, "[EventLogMonitorEvent]"			, PrepareText(ParametersStructure.EventLogMonitorEvent));
	Result = StrReplace(Result, "[EmailAddress]", "");
	Result = StrReplace(Result, "[CreateBackup]"				,"true");
	
	Result = StrReplace(Result, "[BackupDirectory]",PrepareText(Object.BackupImportingFile));
	DirectoryRow = CheckDirectoryOnRootItemSpecifying(Object.BackupDirectory);
	
	Result = StrReplace(Result, "[BackupDirectory2]"				,PrepareText(DirectoryRow+"\backup"+DirectoryRowFromDate()));
	Result = StrReplace(Result, "[RestoreInfobase]"	, "false");
	Result = StrReplace(Result, "[COMConnectorName]"					, PrepareText(ParametersStructure.COMConnectorName));
	Result = StrReplace(Result, "[UseCOMConnector]"			, ?(ParametersStructure.ThisIsBasicConfigurationVersion, "false", "true"));
	Result = StrReplace(Result, "[TemporaryFilesDirectory]"				, PrepareText(TempFilesDir()));
	Return Result;
	
EndFunction

&AtServer
Function CheckDirectoryOnRootItemSpecifying(DirectoryRow)
	
	If Right(DirectoryRow, 2) = ":\" Then
		Return Left(DirectoryRow, StrLen(DirectoryRow) - 1) ;
	Else
		Return DirectoryRow;
	EndIf;
	
EndFunction

&AtServer
Function DirectoryRowFromDate()
	
	ReturnString = "";
	DateNow = CurrentSessionDate();
	ReturnString = Format(DateNow, "DF = yyyy_MM_dd_HH_mm_ss");
	Return ReturnString;
	
EndFunction

&AtServerNoContext
Function PrepareText(Val Text)
	
	Return "'" + StrReplace(Text, "\", "\\") + "'";
	
EndFunction

&AtServer
Procedure SetBackupParameters()
	
	BackupParameters = InfobaseBackupServer.BackupSettings();
	
	BackupParameters.Insert("InfobaseAdministrator", InfobaseAdministrator);
	BackupParameters.Insert("IBAdministratorPassword", ?(PasswordEnterIsRequired, IBAdministratorPassword, ""));
	
	InfobaseBackupServer.SetBackupParameters(BackupParameters);
	
EndProcedure

&AtServer
Function InfobaseSessionCount()
	
	Return InfobaseConnections.InfobaseSessionCount(False, False);
	
EndFunction

#EndRegion

#EndRegion