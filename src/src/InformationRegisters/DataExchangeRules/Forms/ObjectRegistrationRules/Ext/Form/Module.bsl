﻿#Region Variables

&AtClient
Var ExternalResourcesAllowed;

#EndRegion

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	RefreshExchangePlansChoiceList();
	
	RefreshRulesTemplateChoiceList();
	
	UpdateRuleInfo();
	
	UpdateRuleSource();
	
	DataExchangeRuleImportingEventLogMonitorMessageText = DataExchangeServer.DataExchangeRuleImportingEventLogMonitorMessageText();
	
	Items.ExchangePlanGroup.Visible = IsBlankString(Record.ExchangePlanName);
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	If ExternalResourcesAllowed <> True Then
		
		ClosingAlert = New NotifyDescription("AllowExternalResourceEnd", ThisObject, WriteParameters);
		Queries = CreateQueryOnExternalResourcesUse(Record);
		WorkInSafeModeClient.ApplyQueriesOnExternalResourcesUse(Queries, ThisObject, ClosingAlert);
		
		Cancel = True;
		Return;
		
	EndIf;
	ExternalResourcesAllowed = False;
	
	If RulesSource = "StandardFromConfiguration" Then
		// From configuration
		ImportRulesExecute(Undefined, "", False);
	EndIf;
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	If WriteParameters.Property("WriteAndClose") Then
		Close();
	EndIf;
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure ExchangePlanNameOnChange(Item)
	
	Record.RulesTemplateName = "";
	
	// server call
	RefreshRulesTemplateChoiceList();
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure ImportRules(Command)
	
	ClearMessages();
	
	// From file from client
	NameParts = CommonUseClientServer.SplitFullFileName(Record.RulesFilename);
	
	DialogueParameters = New Structure;
	DialogueParameters.Insert("Title", NStr("en = 'Specify a file to import the rules from'"));
	DialogueParameters.Insert("Filter",
		  NStr("en = 'Registration rule files (*.xml)'") + "|*.xml|"
		+ NStr("en = 'ZIP archives (*.zip)'")   + "|*.zip"
	);
	
	DialogueParameters.Insert("FullFileName", NameParts.FullName);
	DialogueParameters.Insert("FilterIndex", ?( Lower(NameParts.Extension) = ".zip", 1, 0) ); 
	
	Notification = New NotifyDescription("ImportRulesEnd", ThisObject);
	DataExchangeClient.SelectAndSendFileToServer(Notification, DialogueParameters, UUID);
EndProcedure

&AtClient
Procedure UnloadRules(Command)
	
	NameParts = CommonUseClientServer.SplitFullFileName(Record.RulesFilename);
	
	StorageAddress = GetURLAtServer();
	NameFilter = NStr("en = 'Rule files (*.xml)'") + "|*.xml";
	
	If IsBlankString(StorageAddress) Then
		Return;
	EndIf;
	
	If IsBlankString(NameParts.BaseName) Then
		FullFileName = NStr("en = 'Registration Rules'");
	Else
		FullFileName = NameParts.BaseName;
	EndIf;
	
	DialogueParameters = New Structure;
	DialogueParameters.Insert("Mode", FileDialogMode.Save);
	DialogueParameters.Insert("Title", NStr("en = 'Specify a file the rules will be exported to'") );
	DialogueParameters.Insert("FullFileName", FullFileName);
	DialogueParameters.Insert("Filter", NameFilter);
	
	ReceivedFile = New Structure("Name, Storage", FullFileName, StorageAddress);
	
	DataExchangeClient.SelectAndSaveFileOnClient(ReceivedFile, DialogueParameters);

	
EndProcedure

&AtClient
Procedure WriteAndClose(Command)
	
	WriteParameters = New Structure;
	WriteParameters.Insert("WriteAndClose");
	Write(WriteParameters);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure ShowEventLogMonitorOnError(Response, AdditionalParameters) Export
	
	If Response = DialogReturnCode.Yes Then
		
		Filter = New Structure;
		Filter.Insert("EventLogMonitorEvent", DataExchangeRuleImportingEventLogMonitorMessageText);
		OpenForm("DataProcessor.EventLogMonitor.Form", Filter, ThisObject, , , , , FormWindowOpeningMode.LockOwnerWindow);
		
	EndIf;
	
EndProcedure

&AtServer
Procedure RefreshExchangePlansChoiceList()
	
	ExchangePlanList = DataExchangeReUse.SLExchangePlanList();
	
	FillList(ExchangePlanList, Items.ExchangePlanName.ChoiceList);
	
EndProcedure

&AtServer
Procedure RefreshRulesTemplateChoiceList()
	
	If IsBlankString(Record.ExchangePlanName) Then
		
		Items.MainGroup.Title = NStr("en = 'Conversion rules'");
		
	Else
		
		Items.MainGroup.Title = StringFunctionsClientServer.SubstituteParametersInString(
			Items.MainGroup.Title, Metadata.ExchangePlans[Record.ExchangePlanName].Synonym);
		
	EndIf;
	
	TemplateList = DataExchangeReUse.GetTypicalRegistrationRulesList(Record.ExchangePlanName);
	
	ChoiceList = Items.RulesTemplateName.ChoiceList;
	ChoiceList.Clear();
	
	FillList(TemplateList, ChoiceList);
	
	Items.SourceConfigurationTemplate.CurrentPage = ?(TemplateList.Count() = 1,
		Items.PageOneTemplate, Items.MultipleModelsPage);
	
EndProcedure

&AtServer
Procedure FillList(SourceList, TargetList)
	
	For Each Item In SourceList Do
		
		FillPropertyValues(TargetList.Add(), Item);
		
	EndDo;
	
EndProcedure

&AtServer
Procedure ImportRulesAtServer(Cancel, TemporaryStorageAddress, RulesFilename, IsArchive)
	
	Record.RulesSource = ?(RulesSource = "StandardFromConfiguration",
		Enums.RuleSourcesForDataExchange.ConfigurationTemplate, Enums.RuleSourcesForDataExchange.File);
	
	Object = FormAttributeToValue("Record");
	
	InformationRegisters.DataExchangeRules.ImportRules(Cancel, Object, TemporaryStorageAddress, RulesFilename, IsArchive);
	
	If Not Cancel Then
		
		Object.Write();
		
		Modified = False;
		
		// Cache of open sessions for the registration mechanism has become irrelevant.
		DataExchangeServerCall.ResetCacheMechanismForRegistrationOfObjects();
		RefreshReusableValues();
	EndIf;
	
	ValueToFormAttribute(Object, "Record");
	
	UpdateRuleInfo();
	Items.ExchangePlanGroup.Visible = IsBlankString(Record.ExchangePlanName);
	
EndProcedure

&AtServer
Function GetURLAtServer()
	
	Filter = New Structure;
	Filter.Insert("ExchangePlanName", Record.ExchangePlanName);
	Filter.Insert("RuleKind",      Record.RuleKind);
	
	RecordKey = InformationRegisters.DataExchangeRules.CreateRecordKey(Filter);
	
	Return GetURL(RecordKey, "XML_Rules");
	
EndFunction

&AtServer
Procedure UpdateRuleInfo()
	
	If Record.RulesSource = Enums.RuleSourcesForDataExchange.File Then
		
		RulesInformation = StringFunctionsClientServer.SubstituteParametersInString(
							NStr("en = 'Use of rules imported from the file may lead to errors when updating application to a new version.
							     |%1'"),
							Record.RulesInformation);
		
	Else
		RulesInformation = Record.RulesInformation;
	EndIf;
	
EndProcedure

&AtServer
Procedure UpdateRuleSource()
	
	RulesSource = ?(Record.RulesSource = Enums.RuleSourcesForDataExchange.ConfigurationTemplate,
		"StandardFromConfiguration", "ExportedFromTheFile");
	
EndProcedure

&AtClient
Procedure ImportRulesExecute(Val PlacedFileAddress, Val FileName, Val IsArchive)
	Cancel = False;
	
	Status(NStr("en = 'Importing rules to the infobase...'"));
	ImportRulesAtServer(Cancel, PlacedFileAddress, FileName, IsArchive);
	Status();
	
	If Not Cancel Then
		ShowUserNotification(,, NStr("en = 'Rules were successfully imported to the infobase.'"));
		Return;
	EndIf;
	
	ErrorText = NStr("en = 'Errors were found during the import.
	                 |Do you want to open the event log?'");
	
	Notification = New NotifyDescription("ShowEventLogMonitorOnError", ThisObject);
	ShowQueryBox(Notification, ErrorText, QuestionDialogMode.YesNo, ,DialogReturnCode.No);
EndProcedure

&AtClient
Procedure ImportRulesEnd(Val FilesPlacingResult, Val AdditionalParameters) Export
	
	PlacedFileAddress = FilesPlacingResult.Location;
	ErrorText           = FilesPlacingResult.ErrorDescription;
	
	If IsBlankString(ErrorText) AND IsBlankString(PlacedFileAddress) Then
		ErrorText = NStr("en = 'An error occurred when transferring the file to the server'");
	EndIf;
	
	If Not IsBlankString(ErrorText) Then
		CommonUseClientServer.MessageToUser(ErrorText);
		Return;
	EndIf;
		
	RulesSource = "ExportedFromTheFile";
	
	// Sent file successfully, import on server.
	NameParts = CommonUseClientServer.SplitFullFileName(FilesPlacingResult.Name);
	
	ImportRulesExecute(PlacedFileAddress, NameParts.Name, Lower(NameParts.Extension) = ".zip");
EndProcedure

&AtClient
Procedure AllowExternalResourceEnd(Result, WriteParameters) Export
	
	If Result = DialogReturnCode.OK Then
		ExternalResourcesAllowed = True;
		Write(WriteParameters);
	EndIf;
	
EndProcedure

&AtServerNoContext
Function CreateQueryOnExternalResourcesUse(Val Record)
	
	PermissionsQueries = New Array;
	ConversionRulesFromFile = InformationRegisters.DataExchangeRules.ConversionRulesFromFile(Record.ExchangePlanName);
	ThereAreConversionRules = (ConversionRulesFromFile <> Undefined);
	RegistrationFromFileRules = (Record.RulesSource = Enums.RuleSourcesForDataExchange.File);
	InformationRegisters.DataExchangeRules.QueryOnExternalResourcesUse(PermissionsQueries,
		?(ThereAreConversionRules, ConversionRulesFromFile, Record), ThereAreConversionRules, RegistrationFromFileRules);
	Return PermissionsQueries;
	
EndFunction

#EndRegion
