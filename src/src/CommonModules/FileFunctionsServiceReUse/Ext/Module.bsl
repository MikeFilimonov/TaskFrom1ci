////////////////////////////////////////////////////////////////////////////////
// Subsystem "File functions".
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProceduresAndFunctions

#Region GeneralAndPersonalFileSettings

// Returns a structure that contains GeneralSettings and PersonalSettingsTip.
Function FileOperationsSettings() Export
	
	CommonSettings        = New Structure;
	PersonalSettingsTip = New Structure;
	
	FileFunctionsService.WhenAddSettingsFileOperations(
		CommonSettings, PersonalSettingsTip);
	
	AddFileOperationsSettings(CommonSettings, PersonalSettingsTip);
	
	Settings = New Structure;
	Settings.Insert("CommonSettings",        CommonSettings);
	Settings.Insert("PersonalSettingsTip", PersonalSettingsTip);
	
	Return Settings;
	
EndFunction

// Sets general and personal settings of file functions.
Procedure AddFileOperationsSettings(CommonSettings, PersonalSettingsTip)
	
	SetPrivilegedMode(True);
	
	// Fill in general settings.
	
	// ExtractFileTextsAtServer.
	CommonSettings.Insert(
		"ExtractFileTextsAtServer", FileFunctionsService.ExtractFileTextsAtServer());
	
	// MaximumFileSize.
	CommonSettings.Insert("MaximumFileSize", FileFunctions.MaximumFileSize());
	
	// DenyFilesOfCertainExtensions.
	DenyFilesOfCertainExtensions = Constants.DenyFilesOfCertainExtensions.Get();
	If DenyFilesOfCertainExtensions = Undefined Then
		DenyFilesOfCertainExtensions = False;
		Constants.DenyFilesOfCertainExtensions.Set(DenyFilesOfCertainExtensions);
	EndIf;
	CommonSettings.Insert("ImportingFilesByExtensionProhibition", DenyFilesOfCertainExtensions);
	
	// ProhibitedFileExtensionsList.
	CommonSettings.Insert("ProhibitedFileExtensionsList", ProhibitedFileExtensionsList());
	
	// OpendocumentFileExtensionsList.
	CommonSettings.Insert("OpendocumentFileExtensionsList", OpendocumentFileExtensionsList());
	
	// TextFileExtensionsList.
	CommonSettings.Insert("TextFileExtensionsList", TextFileExtensionsList());
	
	// Fill in personal settings.
	
	// LocalFilesCacheMaximumSize.
	LocalFilesCacheMaximumSize = CommonUse.CommonSettingsStorageImport(
		"LocalFilesCache", "LocalFilesCacheMaximumSize");
	
	If LocalFilesCacheMaximumSize = Undefined Then
		LocalFilesCacheMaximumSize = 100*1024*1024; // 100 Mb.
		
		CommonUse.CommonSettingsStorageSave(
			"LocalFilesCache",
			"LocalFilesCacheMaximumSize",
			LocalFilesCacheMaximumSize);
	EndIf;
	
	PersonalSettingsTip.Insert(
		"LocalFilesCacheMaximumSize",
		LocalFilesCacheMaximumSize);
	
	// PathToFilesLocalCache.
	PathToFilesLocalCache = CommonUse.CommonSettingsStorageImport(
		"LocalFilesCache", "PathToFilesLocalCache");
	// It is not recommended to get this variable directly.
	// You must use function UserWorkingDirectory 
	// of module FileFunctionsServiceClient.
	PersonalSettingsTip.Insert("PathToFilesLocalCache", PathToFilesLocalCache);
	
	// DeleteFileFromFilesLocalCacheOnEditEnd.
	DeleteFileFromFilesLocalCacheOnEditEnd =
		CommonUse.CommonSettingsStorageImport(
			"LocalFilesCache", "DeleteFileFromFilesLocalCacheOnEditEnd");
	
	If DeleteFileFromFilesLocalCacheOnEditEnd = Undefined Then
		DeleteFileFromFilesLocalCacheOnEditEnd = False;
	EndIf;
	
	PersonalSettingsTip.Insert(
		"DeleteFileFromFilesLocalCacheOnEditEnd",
		DeleteFileFromFilesLocalCacheOnEditEnd);
	
	// ConfirmWhenDeletingFromLocalFilesCache.
	ConfirmWhenDeletingFromLocalFilesCache =
		CommonUse.CommonSettingsStorageImport(
			"LocalFilesCache", "ConfirmWhenDeletingFromLocalFilesCache");
	
	If ConfirmWhenDeletingFromLocalFilesCache = Undefined Then
		ConfirmWhenDeletingFromLocalFilesCache = False;
	EndIf;
	
	PersonalSettingsTip.Insert(
		"ConfirmWhenDeletingFromLocalFilesCache",
		ConfirmWhenDeletingFromLocalFilesCache);
	
	// ShowFileEditTips.
	ShowFileEditTips = CommonUse.CommonSettingsStorageImport(
		"ApplicationSettings", "ShowFileEditTips");
	
	If ShowFileEditTips = Undefined Then
		ShowFileEditTips = True;
		
		CommonUse.CommonSettingsStorageSave(
			"ApplicationSettings",
			"ShowFileEditTips",
			ShowFileEditTips);
	EndIf;
	PersonalSettingsTip.Insert(
		"ShowFileEditTips",
		ShowFileEditTips);
	
	// ShowFileNotChangedMessage.
	ShowFileNotChangedMessage = CommonUse.CommonSettingsStorageImport(
		"ApplicationSettings", "ShowFileNotChangedMessage");
	
	If ShowFileNotChangedMessage = Undefined Then
		ShowFileNotChangedMessage = True;
		
		CommonUse.CommonSettingsStorageSave(
			"ApplicationSettings",
			"ShowFileNotChangedMessage",
			ShowFileNotChangedMessage);
	EndIf;
	PersonalSettingsTip.Insert(
		"ShowFileNotChangedMessage",
		ShowFileNotChangedMessage);
	
	// File opening settings.
	TextFilesExtension = CommonUse.CommonSettingsStorageImport(
		"OpenFileSettings\TextFiles",
		"Extension", "TXT XML INI");
	
	TextFilesOpeningMethod = CommonUse.CommonSettingsStorageImport(
		"OpenFileSettings\TextFiles", 
		"OpeningMethod",
		Enums.FilesAssociation.InEmbeddedEditor);
	
	GraphicalSchemaExtension = CommonUse.CommonSettingsStorageImport(
		"OpenFileSettings\GraphicSchemes", "Extension", "GRS");
	
	GraphicSchemesOpeningMethod = CommonUse.CommonSettingsStorageImport(
		"OpenFileSettings\GraphicSchemes",
		"OpeningMethod",
		Enums.FilesAssociation.InEmbeddedEditor);
	
	PersonalSettingsTip.Insert("TextFilesExtension",       TextFilesExtension);
	PersonalSettingsTip.Insert("TextFilesOpeningMethod",   TextFilesOpeningMethod);
	PersonalSettingsTip.Insert("GraphicalSchemaExtension",     GraphicalSchemaExtension);
	PersonalSettingsTip.Insert("GraphicSchemesOpeningMethod", GraphicSchemesOpeningMethod);
	
EndProcedure

Function ProhibitedFileExtensionsList()
	
	SetPrivilegedMode(True);
	
	ProhibitedDataAreaFileExtensionList =
		Constants.ProhibitedDataAreaFileExtensionList.Get();
	
	If ProhibitedDataAreaFileExtensionList = Undefined
	 OR ProhibitedDataAreaFileExtensionList = "" Then
		
		ProhibitedDataAreaFileExtensionList = "COM EXE BAT CMD VBS VBE JS JSE WSF WSH PCR";
		
		Constants.ProhibitedDataAreaFileExtensionList.Set(
			ProhibitedDataAreaFileExtensionList);
	EndIf;
	
	FinalListOfExtensions = "";
	
	If CommonUseReUse.DataSeparationEnabled()
	   AND CommonUseReUse.CanUseSeparatedData() Then
		
		ProhibitedFileExtensionsList = Constants.ProhibitedFileExtensionsList.Get();
		
		FinalListOfExtensions = 
			ProhibitedFileExtensionsList + " "  + ProhibitedDataAreaFileExtensionList;
	Else
		FinalListOfExtensions = ProhibitedDataAreaFileExtensionList;
	EndIf;
		
	Return FinalListOfExtensions;
	
EndFunction

Function OpendocumentFileExtensionsList()
	
	SetPrivilegedMode(True);
	
	DataAreasOpenDocumentFileExtensionList =
		Constants.DataAreasOpenDocumentFileExtensionList.Get();
	
	If DataAreasOpenDocumentFileExtensionList = Undefined
	 OR DataAreasOpenDocumentFileExtensionList = "" Then
		
		DataAreasOpenDocumentFileExtensionList =
			"ODT OTT ODP OTP ODS OTS ODC OTC ODF OTF ODM OTH SDW STW SXW STC SXC SDC SDD STI";
		
		Constants.DataAreasOpenDocumentFileExtensionList.Set(
			DataAreasOpenDocumentFileExtensionList);
	EndIf;
	
	FinalListOfExtensions = "";
	
	If CommonUseReUse.DataSeparationEnabled()
	   AND CommonUseReUse.CanUseSeparatedData() Then
		
		ProhibitedFileExtensionsList = Constants.OpendocumentFileExtensionsList.Get();
		
		FinalListOfExtensions =
			ProhibitedFileExtensionsList + " "  + DataAreasOpenDocumentFileExtensionList;
	Else
		FinalListOfExtensions = DataAreasOpenDocumentFileExtensionList;
	EndIf;
	
	Return FinalListOfExtensions;
	
EndFunction

Function TextFileExtensionsList()

	SetPrivilegedMode(True);
	
	TextFileExtensionsList = Constants.TextFileExtensionsList.Get();
	
	If IsBlankString(TextFileExtensionsList) Then
		TextFileExtensionsList = "TXT";
		Constants.TextFileExtensionsList.Set(TextFileExtensionsList);
	EndIf;
	
	Return TextFileExtensionsList;

EndFunction

#EndRegion

#EndRegion
