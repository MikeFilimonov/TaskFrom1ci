#Region Variables

&AtClient
Var RefreshInterface;

#EndRegion

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	// Attribute values of the form
	RunMode = CommonUseReUse.ApplicationRunningMode();
	RunMode = New FixedStructure(RunMode);
	
	// StandardSubsystems.FileFunctions
	MaximumFileSize              = FileFunctions.MaximumFileSizeCommon() / (1024*1024);
	MaxDataAreaFileSize = FileFunctions.MaximumFileSize() / (1024*1024);
	If RunMode.SaaS Then
		
		CommonUseClientServer.SetFormItemProperty(Items, "GroupVolumeControlFiles", "Visible", False);
		
	ElsIf RunMode.Local Then
		
		CommonUseClientServer.SetFormItemProperty(Items, "Decoration2", "Visible", False);
		
		// Visible settings on launch.
		Items.StoreFilesInDirectoriesOnHardDisk.Visible     = RunMode.ThisIsSystemAdministrator;
		Items.CatalogFileStorageVolumes.Visible  = RunMode.ThisIsSystemAdministrator;
		
	EndIf;
	// End StandardSubsystems.FileFunctions
	
	// Items state update.
	SetEnabled();
EndProcedure

&AtClient
Procedure OnClose(Exit)
	
	If Exit Then
		Return;
	EndIf;

	RefreshApplicationInterface();
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

// StandardSubsystems.FileFunctions
&AtClient
Procedure StoreFilesInVolumesOnDriveOnChange(Item)
	
	OldValue = Not ConstantsSet.StoreFilesInDirectoriesOnHardDisk;
	
	Try
		QueriesToUseExternalResources = 
			QueriesToUseExternalResourcesFileStorageVolumes(
				ConstantsSet.StoreFilesInDirectoriesOnHardDisk);
		
		WorkInSafeModeClient.ApplyQueriesOnExternalResourcesUse(
			QueriesToUseExternalResources, ThisObject, New NotifyDescription(
				"StoreFilesInVolumesOnDiskOnChangeEnd", ThisObject, Item))
	Except
		ConstantsSet.StoreFilesInDirectoriesOnHardDisk = OldValue;
		Raise;
	EndTry;
	
EndProcedure

&AtClient
Procedure ProhibitImportingFilesByExtensionOnChange(Item)
	Attachable_OnAttributeChange(Item);
EndProcedure

&AtClient
Procedure DataAreaForbiddenExtensionsListOnChange(Item)
	Attachable_OnAttributeChange(Item);
EndProcedure

&AtClient
Procedure MaximalDataAreaFileSizeOnChange(Item)
	Attachable_OnAttributeChange(Item);
EndProcedure

&AtClient
Procedure FileExtensionsListOpenDocumentDataAreaOnChange(Item)
	Attachable_OnAttributeChange(Item);
EndProcedure

&AtClient
Procedure TextFilesExtensionsListOnChange(Item)
	Attachable_OnAttributeChange(Item);
EndProcedure
// End StandardSubsystems.FileFunctions

#EndRegion

#Region FormCommandsHandlers

// StandardSubsystems.FileFunctions
&AtClient
Procedure CatalogFileStorageVolumes(Command)
	OpenForm("Catalog.FileStorageVolumes.ListForm", , ThisObject);
EndProcedure
// End StandardSubsystems.FileFunctions

// StandardSubsystems.DigitalSignature
&AtClient
Procedure ElectronicSignatureAndEncriptionSettings(Command)
	OpenForm("CommonForm.ElectronicSignatureAndEncriptionSettings");
EndProcedure

&AtClient
Procedure UseElectronicSignsOnChange(Item)
	Attachable_OnAttributeChange(Item);
EndProcedure

&AtClient
Procedure UseEncryptionOnChange(Item)
	Attachable_OnAttributeChange(Item);
EndProcedure
// End StandardSubsystems.DigitalSignature

#EndRegion

#Region ServiceProceduresAndFunctions

// StandardSubsystems.FileFunctions
&AtClient
Procedure StoreFilesInVolumesOnDiskOnChangeEnd(Response, Item) Export
	
	If Response <> DialogReturnCode.OK Then
		ConstantsSet.StoreFilesInDirectoriesOnHardDisk = Not ConstantsSet.StoreFilesInDirectoriesOnHardDisk;
	Else
		Attachable_OnAttributeChange(Item);
	EndIf;
	
EndProcedure

&AtServerNoContext
Function QueriesToUseExternalResourcesFileStorageVolumes(inclusion)
	
	QueriesToUse = New Array;
	
	If inclusion Then
		Catalogs.FileStorageVolumes.AddQueriesToUseExternalResourcesAllVolumes(
			QueriesToUse);
	Else
		Catalogs.FileStorageVolumes.AddQueriesToAbolitionUseExternalResourcesAllVolumes(
			QueriesToUse);
	EndIf;
	
	Return QueriesToUse;
	
EndFunction

// End StandardSubsystems.FileFunctions

&AtClient
Procedure Attachable_OnAttributeChange(Item, RefreshingInterface = True)
	
	Result = OnAttributeChangeServer(Item.Name);
	
	RefreshReusableValues();
	
	If RefreshingInterface Then
		AttachIdleHandler("RefreshApplicationInterface", 1, True);
		RefreshInterface = True;
	EndIf;
	
	StandardSubsystemsClient.ShowExecutionResult(ThisObject, Result);
	
EndProcedure

&AtClient
Procedure RefreshApplicationInterface()
	
	If RefreshInterface = True Then
		RefreshInterface = False;
		RefreshInterface();
	EndIf;
	
EndProcedure

&AtServer
Function OnAttributeChangeServer(ItemName)
	
	Result = New Structure;
	
	AttributePathToData = Items[ItemName].DataPath;
	
	SaveAttributeValue(AttributePathToData, Result);
	
	SetEnabled(AttributePathToData);
	
	RefreshReusableValues();
	
	Return Result;
	
EndFunction

&AtServer
Procedure SaveAttributeValue(AttributePathToData, Result)
	
	// Save attribute values not connected with constants directly (one-to-one ratio).
	If AttributePathToData = "" Then
		Return;
	EndIf;
	
	// Definition of constant name.
	ConstantName = "";
	If Lower(Left(AttributePathToData, 13)) = Lower("ConstantsSet.") Then
		// If the path to attribute data is specified through "ConstantsSet".
		ConstantName = Mid(AttributePathToData, 14);
	Else
		// Definition of name and attribute value record in the corresponding constant from "ConstantsSet".
		// Used for the attributes of the form directly connected with constants (one-to-one ratio).
		
		// StandardSubsystems.FileFunctions
		If AttributePathToData = "MaxDataAreaFileSize" Then
			If RunMode.Local Or RunMode.Standalone Then
				ConstantsSet.MaximumFileSize = MaxDataAreaFileSize * (1024*1024);
				ConstantName = "MaximumFileSize";
			Else
				ConstantsSet.MaxDataAreaFileSize = MaxDataAreaFileSize * (1024*1024);
				ConstantName = "MaxDataAreaFileSize";
			EndIf;
		EndIf;
		// End StandardSubsystems.FileFunctions
		
	EndIf;
	
	// Saving the constant value.
	If ConstantName <> "" Then
		ConstantManager = Constants[ConstantName];
		ConstantValue = ConstantsSet[ConstantName];
		
		If ConstantManager.Get() <> ConstantValue Then
			ConstantManager.Set(ConstantValue);
		EndIf;
		
		StandardSubsystemsClientServer.ExecutionResultAddNotificationOfOpenForms(Result, "Record_ConstantsSet", New Structure, ConstantName);
		// StandardSubsystems.ReportsVariants
		ReportsVariants.AddNotificationOnValueChangeConstants(Result, ConstantManager);
		// End StandardSubsystems.ReportsVariants
	EndIf;
	
EndProcedure

&AtServer
Procedure SetEnabled(AttributePathToData = "")
	
	// StandardSubsystems.FileFunctions
	If RunMode.Local AND (AttributePathToData = "ConstantsSet.StoreFilesInDirectoriesOnHardDisk" OR AttributePathToData = "") Then
		Items.CatalogFileStorageVolumes.Enabled = ConstantsSet.StoreFilesInDirectoriesOnHardDisk;
	EndIf;
	// End StandardSubsystems.FileFunctions
	
	// StandardSubsystems.FileFunctions
	If AttributePathToData = "ConstantsSet.DenyFilesOfCertainExtensions" OR AttributePathToData = "" Then
		Items.ProhibitedDataAreaFileExtensionList.Enabled = ConstantsSet.DenyFilesOfCertainExtensions;
	EndIf;
	// End StandardSubsystems.FileFunctions
	
	// StandardSubsystems.DigitalSignature
	If AttributePathToData = "ConstantsSet.UseDigitalSignature"
		OR AttributePathToData = "ConstantsSet.UseEncryption"
		OR AttributePathToData = "" Then
		
		Items.CommonFormCryptographySettings.Enabled = ConstantsSet.UseDigitalSignature OR ConstantsSet.UseEncryption;
		
	EndIf;
	// End StandardSubsystems.DigitalSignature
	
EndProcedure

#EndRegion
