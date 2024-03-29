﻿
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	Manager = ExchangePlans[Parameters.Node.Metadata().Name];
	
	If Parameters.Node = Manager.ThisNode() Then
		Raise
			NStr("en = 'Cannot create initial image for this node.'");
	Else
		BaseKind = 0; // File info base
		TypeDBMS = "";
		Node = Parameters.Node;
		CanCreateFilebase = True;
		SystemInfo = New SystemInfo;
		If SystemInfo.PlatformType = PlatformType.Linux_x86_64 Then
			CanCreateFilebase = False;
		EndIf;
		
		CodesLocale = GetAvailableLocaleCodes();
		LanguageFileBase = Items.Find("LanguageFileBase");
		LanguageOfServerDatabase = Items.Find("LanguageOfServerDatabase");
		
		For Each Code In CodesLocale Do
			Presentation = LocaleCodePresentation(Code);
			LanguageFileBase.ChoiceList.Add(Code, Presentation);
			LanguageOfServerDatabase.ChoiceList.Add(Code, Presentation);
		EndDo;
		
		Language = InfobaseLocaleCode();
		
	EndIf;
	
	AreFilesInVolumes = False;
	
	If FileFunctions.AreFileStorageVolumes() Then
		AreFilesInVolumes = FileFunctionsService.AreFilesInVolumes();
	EndIf;
	
	If AreFilesInVolumes Then
		ServerPlatformType = CommonUseReUse.ServerPlatformType();
		
		If ServerPlatformType = PlatformType.Windows_x86
		 OR ServerPlatformType = PlatformType.Windows_x86_64 Then
			
			Items.FileBaseFullName.AutoMarkIncomplete = True;
			Items.PathToArchiveWithVolumeFiles.AutoMarkIncomplete = True;
		Else
			Items.LinuxFileBaseFullName.AutoMarkIncomplete = True;
			Items.PathToArchiveWithLinuxVolumeFiles.AutoMarkIncomplete = True;
		EndIf;
	Else
		Items.GroupPathToArchiveWithVolumeFiles.Visible = False;
	EndIf;
	
	If Not StandardSubsystemsServerCall.ClientWorkParameters().FileInfobase Then
		Items.PathToArchiveWithVolumeFiles.InputHint = NStr("en = '\\server name\resource\files.zip'");
		Items.PathToArchiveWithVolumeFiles.ChoiceButton = False;
	EndIf;
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure BaseKindOnChange(Item)
	
	// Switch the parameters page.
	Pages = Items.Find("Pages");
	Pages.CurrentPage = Pages.ChildItems[BaseKind];
	
	If ThisObject.BaseKind = 0 Then
		Items.PathToArchiveWithVolumeFiles.InputHint = "";
		Items.PathToArchiveWithVolumeFiles.ChoiceButton = True;
	Else
		Items.PathToArchiveWithVolumeFiles.InputHint = NStr("en = '\\server name\resource\files.zip'");
		Items.PathToArchiveWithVolumeFiles.ChoiceButton = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure PathToArchiveWithVolumeFilesStartChoice(Item, ChoiceData, StandardProcessing)
	
	FileSavingHandler(
		"PathToArchiveWithWindowsVolumesFiles",
		StandardProcessing,
		"files.zip",
		"Archives zip(*.zip)|*.zip");
	
EndProcedure

&AtClient
Procedure FileBaseFullNameStartChoice(Item, ChoiceData, StandardProcessing)
	
	FileSavingHandler(
		"WindowsFileBaseFullName",
		StandardProcessing,
		"1Cv8.1CD",
		"Any file(*.*)|*.*");
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure CreateInitialImage(Command)
	
	ClearMessages();
	
	Status(
		NStr("en = 'Data synchronization'"),
		,
		NStr("en = 'Initial image is being created...'"),
		PictureLib.CreateInitialImage);
	
	If BaseKind = 0 Then
		
		If Not CanCreateFilebase Then
			Raise
				NStr("en = 'Creation of initial image of
				     |file infobase is not supported at this platform.'");
		EndIf;
		
		If Not CreateFileInitialImageAtServer() Then
			Status();
			Return;
		EndIf;
		
	Else
		If Not CreateServerInitialImageAtServer() Then
			Status();
			Return;
		EndIf;
		
	EndIf;
	
	Handler = New NotifyDescription("CreateInitialImageEnd", ThisObject);
	ShowMessageBox(Handler, NStr("en = 'Initial image has been created.'"));
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure CreateInitialImageEnd(ExecuteParameters) Export
	Close();
EndProcedure

&AtClient
Procedure FileSavingHandler(PropertyName,
                                    StandardProcessing,
                                    FileName,
                                    Filter = "")
	
	StandardProcessing = False;
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("PropertyName", PropertyName);
	AdditionalParameters.Insert("FileName", FileName);
	AdditionalParameters.Insert("Filter", Filter);
	
	AlertFileOperationsConnectionExtension = New NotifyDescription(
		"FileSavingHandlerAfterConnectionExpansionFileOperations",
		ThisForm, AdditionalParameters);
	
	BeginAttachingFileSystemExtension(AlertFileOperationsConnectionExtension);
	
EndProcedure

&AtClient
Procedure FileSavingHandlerAfterConnectionExpansionFileOperations(Attached, AdditionalParameters) Export
	
	If Not Attached Then
		FileFunctionsServiceClient.ShowWarningAboutNeedToFileOperationsExpansion(Undefined);
		Return;
	EndIf;
	
	Dialog = New FileDialog(FileDialogMode.Save);
	
	Dialog.Title                = NStr("en = 'Select a file to save to'");
	Dialog.Multiselect       = False;
	Dialog.Preview  = False;
	Dialog.Filter                   = AdditionalParameters.Filter;
	Dialog.FullFileName           =
		?(ThisObject[AdditionalParameters.PropertyName] = "",
		AdditionalParameters.FileName,
		ThisObject[AdditionalParameters.PropertyName]);
	
	SelectionDialogAlertDescription = New NotifyDescription(
		"FileSavingHandlerAfterSelectInDialog",
		ThisForm, AdditionalParameters);
	Dialog.Show(SelectionDialogAlertDescription);
	
EndProcedure

&AtClient
Procedure FileSavingHandlerAfterSelectInDialog(SelectedFiles, AdditionalParameters) Export
	
	If SelectedFiles <> Undefined
		AND SelectedFiles.Count() = 1 Then
		
		ThisObject[AdditionalParameters.PropertyName] = SelectedFiles[0];
	EndIf;
	
EndProcedure

&AtServer
Function CreateFileInitialImageAtServer()
	
	Return FileFunctionsService.CreateFileInitialImageAtServer(
		Node,
		UUID,
		Language,
		WindowsFileBaseFullName,
		LinuxFileBaseFullName,
		PathToArchiveWithWindowsVolumesFiles,
		PathToArchiveWithLinuxVolumeFiles);
	
EndFunction

&AtServer
Function CreateServerInitialImageAtServer()
	
	ConnectionString =
		"Srvr="""       + Server + """;"
		+ "Ref="""      + NameBase + """;"
		+ "DBMS="""     + TypeDBMS + """;"
		+ "DBSrvr="""   + DataBaseServer + """;"
		+ "DB="""       + NameOfDataBase + """;"
		+ "DBUID="""    + DataBaseUser + """;"
		+ "DBPwd="""    + UserPassword + """;"
		+ "SQLYOffs=""" + Format(DateShift, "NG=") + """;"
		+ "Locale="""   + Language + """;"
		+ "SchJobDn=""" + ?(SetSheduledJobLock, "Y", "N") + """;";
	
	Return FileFunctionsService.CreateServerInitialImageAtServer(
		Node, ConnectionString, PathToArchiveWithWindowsVolumesFiles, PathToArchiveWithLinuxVolumeFiles);
	
EndFunction

#EndRegion
