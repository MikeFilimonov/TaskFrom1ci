
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	SetVisibility();
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	Notify("RecordedItemExchangeSettings", Object.Ref, ThisForm);
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "Write_BankStatementProcessingSetting"
		AND Parameter = Object.DataProcessor Then
		Read();
	EndIf;
	
EndProcedure

#EndRegion

#Region FormItemsEventHandlers

&AtClient
Procedure DataProcessorOnChange(Item)
	If ValueIsFilled(Object.DataProcessor) Then
		UpdateSettingsAtServer();
	EndIf;
EndProcedure

&AtClient
Procedure ImportCatalogStartChoice(Item, ChoiceData, StandardProcessing)
	
	NotifyDescription = New NotifyDescription("SelectCatalog", ThisForm, New Structure("Import", True));
	CommonUseClient.ShowFileSystemExtensionInstallationQuestion(NotifyDescription);
	
EndProcedure

&AtClient
Procedure ExportCatalogStartChoice(Item, ChoiceData, StandardProcessing)
	
	NotifyDescription = New NotifyDescription("SelectCatalog", ThisForm, New Structure("Import", False));
	CommonUseClient.ShowFileSystemExtensionInstallationQuestion(NotifyDescription);
	
EndProcedure

&AtClient
Procedure SelectCatalog(IsInstalled, AdditionalParameters) Export
	
	CatalogSelection = New FileDialog(FileDialogMode.ChooseDirectory);
	CatalogSelection.Multiselect	= False;
	CatalogSelection.Title			= NStr("en = 'Select directory'");
	
	If CatalogSelection.Choose() Then
		If AdditionalParameters.Import Then
			Object.ImportDirectory = CatalogSelection.Directory;
		Else
			Object.ExportDirectory = CatalogSelection.Directory;
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure SetVisibility()
	
	DataProcIsSet = ValueIsFilled(Object.DataProcessor);
	
	Items.FileExtensions.Visible			= DataProcIsSet;
	Items.Encoding.Visible					= DataProcIsSet;
	Items.GroupPages.Visible				= DataProcIsSet;
	Items.PageImport.Visible				= Object.UseImportFromFile;
	Items.PageExport.Visible				= Object.UseExportToFile;
	Items.PageAdditionalSettings.Visible	= Object.AdditionalSettings.Count() > 0;
	
EndProcedure

&AtServer
Procedure UpdateSettingsAtServer()
	
	SettingObj = FormAttributeToValue("Object");
	Catalogs.BankStatementProcessingSettings.UpdateSettingsFromDataProcessor(SettingObj, SettingObj.DataProcessor);
	ValueToFormAttribute(SettingObj, "Object");
	
	SetVisibility();
	
EndProcedure

#EndRegion