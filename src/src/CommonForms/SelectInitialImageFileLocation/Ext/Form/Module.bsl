﻿
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	If StandardSubsystemsServerCall.ClientWorkParameters().FileInfobase Then
		Items.PathToWindowsArchive.Title = NStr("en = 'For the 1C:Enterprise server under Microsoft Windows'"); 
	Else
		Items.PathToWindowsArchive.ChoiceButton = False; 
	EndIf;
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure PathToArchiveWindowsInitialSelection(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	If Not FileFunctionsServiceClient.FileOperationsExtensionConnected() Then
		FileFunctionsServiceClient.ShowWarningAboutNeedToFileOperationsExpansion(Undefined);
		Return;
	EndIf;
	
	Dialog = New FileDialog(FileDialogMode.Open);
	
	Dialog.Title                    = NStr("en = 'Select file'");
	Dialog.FullFileName               = ?(ThisObject.PathToWindowsArchive = "", "files.zip", ThisObject.PathToWindowsArchive);
	Dialog.Multiselect           = False;
	Dialog.Preview      = False;
	Dialog.CheckFileExist  = True;
	Dialog.Filter                       = NStr("en = 'Zip archives(*.zip)|*.zip'");
	
	If Dialog.Choose() Then
		
		ThisObject.PathToWindowsArchive = Dialog.FullFileName;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure Place(Command)
	
	ClearMessages();
	
	If IsBlankString(PathToWindowsArchive) AND IsBlankString(PathToLinuxArchive) Then
		Text = NStr("en = 'Specify the full name
		            |of the archive with files of the initial image (file *.zip)'");
		CommonUseClientServer.MessageToUser(Text, , "PathToWindowsArchive");
		Return;
	EndIf;
	
	If Not StandardSubsystemsClientReUse.ClientWorkParameters().FileInfobase Then
	
		If Not IsBlankString(PathToWindowsArchive) AND (Left(PathToWindowsArchive, 2) <> "\\" OR Find(PathToWindowsArchive, ":") <> 0) Then
			ErrorText = NStr("en = 'Path to archive with initial
			                 |image files must be in UNC format (\\servername\resource).'");
			CommonUseClientServer.MessageToUser(ErrorText, , "PathToWindowsArchive");
			Return;
		EndIf;
	
	EndIf;
	
	Status(
		NStr("en = 'Data exchange description'"),
		,
		NStr("en = 'File placement from
		     |archive with initial image files is executed...'"),
		PictureLib.CreateInitialImage);
	
	AddFilesToVolumes();
	
	NotificationText = NStr("en = 'File placement from archive
	                        |with initial image files is successfully completed.'");
	ShowUserNotification(NotificationText);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure AddFilesToVolumes()
	
	FileFunctionsService.AddFilesToVolumes(PathToWindowsArchive, PathToLinuxArchive);
	
EndProcedure

#EndRegion
