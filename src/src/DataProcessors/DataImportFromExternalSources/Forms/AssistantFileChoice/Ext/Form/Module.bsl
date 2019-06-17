
#Region ServiceProceduresAndFunctions

// :::CommonUse

&AtServer
Procedure CreateFieldsTreeAvailableForUser()
	Var FieldsTree;
	
	DataProcessors.DataImportFromExternalSources.CreateFieldsTreeAvailableForUser(FieldsTree, Parameters.DataLoadSettings);
	FieldsTreeStorageAddress = PutToTempStorage(FieldsTree, UUID);
	
	Parameters.DataLoadSettings.Insert("FieldsTreeStorageAddress", FieldsTreeStorageAddress);
	
EndProcedure

&AtServer
Procedure GenerateDataCheckingPageTitle()
	
	NormalText = NStr("en = 'If 100 blank rows are found, the cheking stops.
	                  |While checking the spreadsheet'");
	
	BoldText = NStr("en = 'the following errors found:'");
	
	Font8N = New Font(Items.PictureToolTipDataChecks.Font, , 10, False);
	Font8B = New Font(Items.PictureToolTipDataChecks.Font, , 10, True);
	
	FormattedStringArray = New Array;
	FormattedStringArray.Add(New FormattedString(NormalText,	Font8N));
	FormattedStringArray.Add(New FormattedString(BoldText, 		Font8B));
	
	Items.PictureToolTipDataChecks.Title = New FormattedString(FormattedStringArray);
	
EndProcedure

&AtClient
Procedure ProccessAdditionalAttributeChoice(AdditionalAttribute)

	If AdditionalAttribute <> Undefined Then
		If Parameters.DataLoadSettings.SelectedAdditionalAttributes.Get(AdditionalAttribute) = Undefined Then
			
			Parameters.DataLoadSettings.SelectedAdditionalAttributes.Insert(AdditionalAttribute, Parameters.DataLoadSettings.AdditionalAttributeDescription.Get(AdditionalAttribute));
			
		EndIf;
	EndIf;

EndProcedure

&AtClient
Function ReceiveTitleArea()
	
	TitleArea = Items.SpreadsheetDocument.CurrentArea;
	If TitleArea.AreaType = SpreadsheetDocumentCellAreaType.Columns Then // missed, highlighted column
		
		TitleArea = SpreadsheetDocument.Area("R1" + TitleArea.Name);
		
	EndIf;
	
	Return TitleArea;
	
EndFunction

&AtClient
Procedure SpreadsheetDocumentDetailProcessing(Item, Details, StandardProcessing)
	
	StandardProcessing = False;
	
	If Items.SpreadsheetDocument.CurrentArea.AreaType = SpreadsheetDocumentCellAreaType.Columns 
		OR Items.SpreadsheetDocument.CurrentArea.AreaType = SpreadsheetDocumentCellAreaType.Rectangle Then
		
		If TypeOf(Details) = Type("ValueList") Then
			
			NotifyDescription = New NotifyDescription("ColumnTitleDetailsDataProcessor", ThisObject);
			
			TitleArea = ReceiveTitleArea();
			
			ImportParameters = New Structure;
			ImportParameters.Insert("DataLoadSettings",		Parameters.DataLoadSettings);
			ImportParameters.Insert("FieldPresentation",	TitleArea.Text);
			ImportParameters.Insert("FieldName",			TitleArea.DetailsParameter);
			ImportParameters.Insert("ColumnTitle",			TitleArea.Comment.Text);
			ImportParameters.Insert("ColumnNumber", 		TitleArea.Right);
			
			OpenForm("DataProcessor.DataImportFromExternalSources.Form.FieldChoice", ImportParameters, ThisObject, , , , NotifyDescription);
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure FillMatchTableFilterChoiceList(IsTabularSectionImport)
	
	If Parameters.DataLoadSettings.IsTabularSectionImport Then
		
		Items.FilterComparisonTable.ChoiceList.Insert(1, NStr("en = 'FilterNoErrors'"),	NStr("en = 'Ready for import'"));
		Items.FilterComparisonTable.ChoiceList.Insert(2, NStr("en = 'FilterErrors'"), 	NStr("en = 'Impossible to import'"));
		
	Else
		
		Items.FilterComparisonTable.ChoiceList.Insert(1, NStr("en = 'Mapped'"), NStr("en = 'Matched'"));
		Items.FilterComparisonTable.ChoiceList.Insert(1, NStr("en = 'WillBeCreated'"), NStr("en = 'Data with no match in the database'"));
		Items.FilterComparisonTable.ChoiceList.Insert(1, NStr("en = 'Inconsistent'"), NStr("en = 'Data containing error (incomplete)'"));
		
	EndIf;
	
EndProcedure

&AtClient
Procedure SetDecorationTitleTextUnmatchedRows()
	
	If CreateIfNotMatched Then
		
		HeaderText = ?(Parameters.DataLoadSettings.IsCatalogImport, 
			NStr("en = 'new items to be created:'"), 
			NStr("en = 'new records to be created:'"));
		
	Else
		HeaderText = NStr("en = 'rows will be skipped:'");
	EndIf;
	
	ItemName = ?(Parameters.DataLoadSettings.IsCatalogImport, "DecorationUnmatchedRowsHeaderObject", "DecorationUnmatchedRowsHeaderIR");
	
	Items[ItemName].Title = HeaderText;
	
EndProcedure

&AtClient
Procedure SetMatchedObjectsDecorationTitleText()
	
	TitleText = ?(UpdateExisting,
		NStr("en = 'among them are matched and will be updated'"),
		NStr("en = 'among them are matched'"));
		
	ItemName = ?(Parameters.DataLoadSettings.IsCatalogImport, "DecorationMatchedHeaderObject", "DecorationMatchedHeaderIR");
	
	Items[ItemName].Title = TitleText;
	
EndProcedure

&AtServer
Procedure ChangeConditionalDesignText()
	
	DataImportFromExternalSourcesOverridable.ChangeConditionalDesignText(ThisObject.ConditionalAppearance, Parameters.DataLoadSettings);
	
EndProcedure

&AtServer
Function CheckExecutionAtServer(BackgroundJobID, BackgroundJobStorageAddress)
	
	CheckResult = New Structure("JobCompleted, Value", False, Undefined);
	If LongActions.JobCompleted(BackgroundJobID) Then
		
		CheckResult.JobCompleted	= True;
		SpreadsheetDocument			= GetFromTempStorage(BackgroundJobStorageAddress);
		
	EndIf;
	
	Return CheckResult;
	
EndFunction

&AtClient
Procedure CheckExecution()
	
	CheckResult = CheckExecutionAtServer(BackgroundJobID, BackgroundJobStorageAddress);
	If CheckResult.JobCompleted Then
		
		ChangeGoToNumber(+1);
		
	Else	
		
		If BackgroundJobIntervalChecks < 15 Then
			
			BackgroundJobIntervalChecks = BackgroundJobIntervalChecks + 0.7;
			
		EndIf;
		
		AttachIdleHandler("CheckExecution", BackgroundJobIntervalChecks, True);
		
	EndIf;
	
EndProcedure

// :::PageDataImport

&AtServer
Procedure ImportFileWithDataToTabularDocumentOnServer(GoToNext)
	
	Extension = CommonUseClientServer.ExtensionWithoutDot(CommonUseClientServer.GetFileNameExtension(NameOfSelectedFile));
	
	TempFileName	= GetTempFileName(Extension);
	BinaryData = GetFromTempStorage(TemporaryStorageAddress);
	
	If BinaryData = Undefined Then
		Return;
	Else
		BinaryData.Write(TempFileName);
	EndIf;
	
	SpreadsheetDocument.Clear();
	DataMatchingTable.Clear();
	
	ServerCallParameters = New Structure;
	ServerCallParameters.Insert("TempFileName",			TempFileName);
	ServerCallParameters.Insert("Extension", 			Extension);
	ServerCallParameters.Insert("SpreadsheetDocument",	SpreadsheetDocument);
	ServerCallParameters.Insert("DataLoadSettings",		Parameters.DataLoadSettings);
	
	If CommonUse.FileInfobase() Then
		
		DataImportFromExternalSources.ImportData(ServerCallParameters, TemporaryStorageAddress);
		SpreadsheetDocument = GetFromTempStorage(TemporaryStorageAddress);
		
	Else
		
		MethodName = "DataImportFromExternalSources.ImportData";
		Description = NStr("en = 'The ImportDataFromExternalSource subsystem: Execution of the server procedure to import data from file'");
		
		BackgroundJobResult = LongActions.ExecuteInBackground(UUID, MethodName, ServerCallParameters, Description);
		If BackgroundJobResult.JobCompleted Then
			
			BackgroundJobStorageAddress = BackgroundJobResult.StorageAddress;
			SpreadsheetDocument = GetFromTempStorage(BackgroundJobStorageAddress);
			
		Else 
			
			GoToNext = False;
			BackgroundJobID  = BackgroundJobResult.JobID;
			BackgroundJobStorageAddress = BackgroundJobResult.StorageAddress;
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure ExecuteDataImportAtServer(GoToNext)
	
	DataProcessors.DataImportFromExternalSources.AddMatchTableColumns(ThisObject, DataMatchingTable, Parameters.DataLoadSettings);
	If Parameters.DataLoadSettings.ManualFilling = True Then
		
		DataImportFromExternalSources.FillInDetailsInTabularDocument(SpreadsheetDocument,
			DataImportFromExternalSourcesOverridable.MaximumOfUsefulColumnsTableDocument(), Parameters.DataLoadSettings);
		CommonUseClientServer.SetFormItemProperty(Items, "SpreadsheetDocument", "Edit", True);
		
	Else
		
		ImportFileWithDataToTabularDocumentOnServer(GoToNext);
		
	EndIf;
	
EndProcedure

// :::PagesDataCheck

&AtServer
Procedure AddAdditionalAttributesInMatchingTable(DataLoadSettings)
	
	DataProcessors.DataImportFromExternalSources.AddAdditionalAttributes(ThisObject, Parameters.DataLoadSettings.SelectedAdditionalAttributes);
	
EndProcedure

&AtServer
Procedure CheckReceivedData(SkipPage, DenyTransitionNext)
	
	If Parameters.DataLoadSettings.Property("SelectedAdditionalAttributes")
		AND Parameters.DataLoadSettings.SelectedAdditionalAttributes.Count() > 0 Then
		
		AddAdditionalAttributesInMatchingTable(Parameters.DataLoadSettings);
		
	EndIf;
	
	DataProcessors.DataImportFromExternalSources.PreliminarilyDataProcessor(SpreadsheetDocument, DataMatchingTable, Parameters.DataLoadSettings, SpreadsheetDocumentMessages, SkipPage, DenyTransitionNext);
	
EndProcedure

// :::PageMatch

&AtServer
Procedure AddNewMatch(TableRow)
	
	If Not Parameters.DataLoadSettings.Property("Supplier") Then
		Return;
	EndIf;
	
	NewSupplierProduct = Catalogs.SuppliersProducts.CreateItem();
	NewSupplierProduct.Products		= TableRow.Products;
	NewSupplierProduct.Description	= TableRow.ProductsDescription;
	NewSupplierProduct.Owner		= Parameters.DataLoadSettings.Supplier;
	
	Try
		NewSupplierProduct.Write();
	Except
		CommonUseClientServer.MessageToUser(ErrorDescription());
	EndTry;
	
EndProcedure

&AtServer
Procedure CheckDataCorrectnessInTableRow(RowFormID)
	
	Var Manager;
	
	FormTableRow = DataMatchingTable.FindByID(RowFormID);
	
	AddNewMatch(FormTableRow);
	
	DataImportFromExternalSourcesOverridable.CheckDataCorrectnessInTableRow(FormTableRow, Parameters.DataLoadSettings.FillingObjectFullName);
	
EndProcedure

&AtClient
Procedure SetRowsQuantityDecorationText()
	
	TableRowCount		= DataMatchingTable.Count();
	RowsQuantityWithoutErrors	= DataMatchingTable.FindRows(New Structure("_ImportToApplicationPossible", True)).Count();
	If Not Parameters.DataLoadSettings.IsTabularSectionImport Then
		
		UnmatchedData = DataMatchingTable.FindRows(New Structure("_RowMatched", False)).Count();
		InconsistentData = DataMatchingTable.FindRows(New Structure("_ImportToApplicationPossible", False)).Count();
		
	EndIf;
	
	NewHeader 				= "";
	
	If FilterComparisonTable = "WithoutFilter" Then 
		
		NewHeader = NStr("en = 'Total number of rows: %1'");
		ParameterValue = TableRowCount;
		
	ElsIf FilterComparisonTable = "FilterNoErrors" Then 
		
		NewHeader = NStr("en = 'Rows to be imported in the database: %1'");
		ParameterValue = RowsQuantityWithoutErrors;
		
	ElsIf FilterComparisonTable = "FilterErrors" Then 
		
		NewHeader = NStr("en = 'Rows containing errors: %1'");
		ParameterValue = TableRowCount - RowsQuantityWithoutErrors;
		
	ElsIf FilterComparisonTable = "Mapped" Then 
		
		If UpdateExisting Then
			
			NewHeader = NStr("en = 'Matched data will be updated: %1'");
			
		Else
			
			NewHeader = NStr("en = 'Data matched: %1'");
			
		EndIf;
		
		ParameterValue = TableRowCount - UnmatchedData;
		
	ElsIf FilterComparisonTable = "WillBeCreated" Then 
		
		NewHeader = NStr("en = 'Data not mapped: %1'");
		ParameterValue = UnmatchedData;
		
	ElsIf FilterComparisonTable = "Inconsistent" Then 
		
		NewHeader = NStr("en = 'Rows containing errors or incomplete: %1'");
		ParameterValue = InconsistentData;
		
	EndIf;
	
	NewHeader = StringFunctionsClientServer.SubstituteParametersInString(NewHeader, ParameterValue);
	Items.DecorationLineCount.Title = NewHeader;
	
EndProcedure

&AtClient
Procedure SetRowsFilterByFilterValue()
	
	If FilterComparisonTable = "WithoutFilter" Then
		
		Items.DataMatchingTable.RowFilter = Undefined;
		
	ElsIf FilterComparisonTable = "FilterNoErrors" Then
		
		Items.DataMatchingTable.RowFilter = New FixedStructure(ServiceFieldName, True);
		
	ElsIf FilterComparisonTable = "FilterErrors" Then
		
		Items.DataMatchingTable.RowFilter = New FixedStructure(ServiceFieldName, False);
		
	ElsIf FilterComparisonTable = "Mapped" Then
		
		Items.DataMatchingTable.RowFilter = New FixedStructure("_RowMatched", True);
		
	ElsIf FilterComparisonTable = "WillBeCreated" Then
		
		If Parameters.DataLoadSettings.IsCatalogImport Then
			
			FixedRowsFilterStructure = New FixedStructure("_ImportToApplicationPossible, _RowMatched", True, False);
			Items.DataMatchingTable.RowFilter = FixedRowsFilterStructure;
			
		ElsIf Parameters.DataLoadSettings.IsInformationRegisterImport Then
			
			FixedRowsFilterStructure = New FixedStructure("_ImportToApplicationPossible, _RowMatched", True, False);
			Items.DataMatchingTable.RowFilter = FixedRowsFilterStructure;
			
		EndIf;
		
	ElsIf FilterComparisonTable = "Inconsistent" Then
		
		Items.DataMatchingTable.RowFilter = New FixedStructure("_ImportToApplicationPossible", False);
		
	EndIf;
	
EndProcedure

&AtServer
Procedure ExportedDataComparison()
	Var Manager;
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("DataLoadSettings", Parameters.DataLoadSettings);
	
	DataImportFromExternalSourcesOverridable.MatchImportedDataFromExternalSource(DataMatchingTable, Parameters.DataLoadSettings);
	
EndProcedure

#EndRegion

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	Var Manager;
	
	DataImportFromExternalSources.GetManagerByFillingObjectName(Parameters.DataLoadSettings.FillingObjectFullName, Manager);
	
	ServiceFieldName = DataImportFromExternalSources.ServiceFieldNameImportToApplicationPossible();
	
	UpdateExisting 		= False;
	CreateIfNotMatched	= True;
	
	Parameters.DataLoadSettings.Insert("UpdateExisting", 		UpdateExisting);
	Parameters.DataLoadSettings.Insert("CreateIfNotMatched",	CreateIfNotMatched);
	Parameters.DataLoadSettings.Insert("ManualFilling",			False);
	
	If Parameters.DataLoadSettings.IsInformationRegisterImport  
		AND Not Parameters.DataLoadSettings.Property("CommonValue") Then
		
		CommonUseClientServer.SetFormItemProperty(Items, "DecorationKeyValueIRHeader", "Visible", False);
		CommonUseClientServer.SetFormItemProperty(Items, "CommonValueIR", "Visible", False);
		CommonUseClientServer.SetFormItemProperty(Items, "ClearCommonValueIR", "Visible", False);
		
	EndIf;
	
	CommonUseClientServer.SetFormItemProperty(Items, "Group4", "Visible", Not CommonUseClientServer.ThisIsWebClient());
	CommonUseClientServer.SetFormItemProperty(Items, "Group5", "Visible", Not CommonUseClientServer.ThisIsWebClient());
	
	CreateFieldsTreeAvailableForUser();
	
	GenerateDataCheckingPageTitle();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	Parameters.DataLoadSettings.Insert("CreateIfNotMatched", CreateIfNotMatched);
	FillMatchTableFilterChoiceList(Parameters.DataLoadSettings.IsTabularSectionImport);
	
	SetDecorationTitleTextUnmatchedRows();
	SetMatchedObjectsDecorationTitleText();
	
	// Set the current table of transitions
	TableOfGoToByScript();
	
	// Position at the assistant's first step
	SetGoToNumber(1);
	
EndProcedure

#EndRegion

#Region FormItemEventsHandlers

&AtClient
Procedure FilterComparisonTableOnChange(Item)
	
	SetRowsFilterByFilterValue();
	SetRowsQuantityDecorationText();
	
	CurrentItem = Items.DataMatchingTable;
	
EndProcedure

&AtClient
Procedure CreateIfNotMatchedOnChange(Item)
	
	Parameters.DataLoadSettings.Insert("CreateIfNotMatched", CreateIfNotMatched);
	
	SetDecorationTitleTextUnmatchedRows();
	
	ChangeConditionalDesignText();
	
EndProcedure

&AtClient
Procedure DataMatchingTableOnChange(Item)
	
	RowFormID = Items.DataMatchingTable.CurrentData.GetID();
	CheckDataCorrectnessInTableRow(RowFormID);
	SetRowsQuantityDecorationText();
	
EndProcedure

&AtClient
Procedure SpreadsheetDocumentOnActivateArea(Item)
	
	Item.Protection = Not (Item.CurrentArea.Top > 1);
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure CommandNext(Command)
	
	ChangeGoToNumber(+1);
	
EndProcedure

&AtClient
Procedure CommandBack(Command)
	
	Step = -1;
	If Items.MainPanel.CurrentPage = Items.PagePreliminarilyTS
		OR Items.MainPanel.CurrentPage = Items.PagePreliminaryCatalog
		OR Items.MainPanel.CurrentPage = Items.PagePreliminarilyInformationRegister Then
		
		Step = -2;
		
	EndIf;
	
	ChangeGoToNumber(Step);
	
EndProcedure

&AtClient
Procedure CommandDone(Command)
	
	ForceCloseForm = True;
	
	ClosingResult = New Structure;
	ClosingResult.Insert("ActionsDetails",		"ProcessPreparedData");
	ClosingResult.Insert("DataMatchingTable",	DataMatchingTable);
	ClosingResult.Insert("DataLoadSettings",	Parameters.DataLoadSettings);
	
	NotifyChoice(ClosingResult);
	Notify("ProcessPreparedData", ClosingResult);
	
EndProcedure

&AtClient
Procedure CommandCancel(Command)
	
	Close();
	
EndProcedure

&AtClient
Procedure ShowMatchingTable_WithoutFilter(Command)
	
	ChoiceListItem = Items.FilterComparisonTable.ChoiceList.FindByValue("WithoutFilter");
	FilterComparisonTable = ChoiceListItem.Value;
	
	ChangeGoToNumber(-1);
	
EndProcedure

&AtClient
Procedure ShowMatchingTable_WillBeCreated(Command)
	
	ChoiceListItem = Items.FilterComparisonTable.ChoiceList.FindByValue("WillBeCreated");
	FilterComparisonTable = ChoiceListItem.Value;
	
	ChangeGoToNumber(-1);
	
EndProcedure

&AtClient
Procedure ShowMatchingTable_InconsistentData(Command)
	
	ChoiceListItem = Items.FilterComparisonTable.ChoiceList.FindByValue("Inconsistent");
	FilterComparisonTable = ChoiceListItem.Value;
	
	ChangeGoToNumber(-1);
	
EndProcedure

&AtClient
Procedure ShowMatchingTable_FilterNoErrors(Command)
	
	ChoiceListItem = Items.FilterComparisonTable.ChoiceList.FindByValue("FilterNoErrors");
	FilterComparisonTable = ChoiceListItem.Value;
	
	ChangeGoToNumber(-1);
	
EndProcedure

&AtClient
Procedure ShowMatchingTable_FilterErrors(Command)
	
	ChoiceListItem = Items.FilterComparisonTable.ChoiceList.FindByValue("FilterErrors");
	FilterComparisonTable = ChoiceListItem.Value;
	
	ChangeGoToNumber(-1);
	
EndProcedure

&AtClient
Procedure ShowMatchingTable_Mapped(Command)
	
	ChoiceListItem = Items.FilterComparisonTable.ChoiceList.FindByValue("Mapped");
	FilterComparisonTable = ChoiceListItem.Value;
	
	ChangeGoToNumber(-1);
	
EndProcedure

&AtClient
Procedure CommonValue(Command)
	
	DataImportFromExternalSourcesClientOverridable.OnSetGeneralValue(ThisObject, Parameters.DataLoadSettings, DataMatchingTable);
	
EndProcedure

&AtClient
Procedure ClearCommonValue(Command)
	
	DataImportFromExternalSourcesClientOverridable.OnClearGeneralValue(ThisObject, Parameters.DataLoadSettings, DataMatchingTable);
	
EndProcedure

&AtClient
Procedure UpdateExistingOnChange(Item)
	
	Parameters.DataLoadSettings.Insert("UpdateExisting", UpdateExisting);
	
	SetMatchedObjectsDecorationTitleText();
	
EndProcedure

#EndRegion

#Region InteractiveActionResultHandlers

&AtClient
Procedure SelectExternalFileDataProcessorEnd(PlacedFiles, AdditionalParameters) Export
	
	If PlacedFiles <> Undefined Then
		TemporaryStorageAddress	= PlacedFiles[0].Location;
		NameOfSelectedFile 		= PlacedFiles[0].Name;
		Extension 				= CommonUseClientServer.ExtensionWithoutDot(CommonUseClientServer.GetFileNameExtension(NameOfSelectedFile));
		
		ChangeGoToNumber(+1);
	EndIf;
	
EndProcedure

&AtClient
Procedure ColumnTitleDetailsDataProcessor(Result, AdditionalParameters) Export
	
	If TypeOf(Result) = Type("Structure") Then
		
		ProccessAdditionalAttributeChoice(Result.AdditionalAttribute);
		
		TitleArea = ReceiveTitleArea();
		
		TitleArea.Text 				= Result.Presentation;
		TitleArea.DetailsParameter	= Result.Value;
		
		If Result.Property("CancelSelectionInColumn") Then
			TitleArea 					= SpreadsheetDocument.Area("R1C" + Result.CancelSelectionInColumn);
			TitleArea.Text 				= NStr("en = 'Do not import'");
			TitleArea.DetailsParameter	= "";
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions_SuppliedPart

&AtClient
Procedure ChangeGoToNumber(Iterator)
	
	ClearMessages();
	
	SetGoToNumber(GoToNumber + Iterator);
	
EndProcedure

&AtClient
Procedure SetGoToNumber(Val Value)
	
	IsGoNext = (Value > GoToNumber);
	
	GoToNumber = Value;
	
	If GoToNumber < 0 Then
		
		GoToNumber = 0;
		
	EndIf;
	
	GoToNumberOnChange(IsGoNext);
	
EndProcedure

&AtClient
Procedure GoToNumberOnChange(Val IsGoNext)
	
	// Executing the step change event handlers
	ExecuteGoToEventHandlers(IsGoNext);
	
	// Setting page visible
	GoToRowsCurrent = GoToTable.FindRows(New Structure("GoToNumber", GoToNumber));
	
	If GoToRowsCurrent.Count() = 0 Then
		Raise NStr("en = 'Page to display is not defined.'");
	EndIf;
	
	GoToRowCurrent = GoToRowsCurrent[0];
	
	Items.MainPanel.CurrentPage  = Items[GoToRowCurrent.MainPageName];
	Items.NavigationPanel.CurrentPage = Items[GoToRowCurrent.NavigationPageName];
	
	// Set current button by default
	ButtonNext = GetFormButtonByCommandName(Items.NavigationPanel.CurrentPage, "CommandNext");
	
	If ButtonNext <> Undefined Then
		
		ButtonNext.DefaultButton = True;
		
	Else
		
		DoneButton = GetFormButtonByCommandName(Items.NavigationPanel.CurrentPage, "CommandDone");
		
		If DoneButton <> Undefined Then
			
			DoneButton.DefaultButton = True;
			
		EndIf;
		
	EndIf;
	
	If IsGoNext AND GoToRowCurrent.LongAction Then
		
		AttachIdleHandler("ExecuteLongOperationHandler", 0.1, True);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ExecuteGoToEventHandlers(Val IsGoNext)
	
	// Transition events handlers
	If IsGoNext Then
		
		GoToRows = GoToTable.FindRows(New Structure("GoToNumber", GoToNumber - 1));
		
		If GoToRows.Count() > 0 Then
			
			GoToRow = GoToRows[0];
			
			// handler OnGoingNext
			If Not IsBlankString(GoToRow.GoNextHandlerName)
				AND Not GoToRow.LongAction Then
				
				ProcedureName = "Attachable_[HandlerName](Cancel)";
				ProcedureName = StrReplace(ProcedureName, "[HandlerName]", GoToRow.GoNextHandlerName);
				
				Cancel = False;
				
				A = Eval(ProcedureName);
				
				If Cancel Then
					
					SetGoToNumber(GoToNumber - 1);
					
					Return;
					
				EndIf;
				
			EndIf;
			
		EndIf;
		
	Else
		
		GoToRows = GoToTable.FindRows(New Structure("GoToNumber", GoToNumber + 1));
		
		If GoToRows.Count() > 0 Then
			
			GoToRow = GoToRows[0];
			
			// handler OnGoingBack
			If Not IsBlankString(GoToRow.GoBackHandlerName)
				AND Not GoToRow.LongAction Then
				
				ProcedureName = "Attachable_[HandlerName](Cancel)";
				ProcedureName = StrReplace(ProcedureName, "[HandlerName]", GoToRow.GoBackHandlerName);
				
				Cancel = False;
				
				A = Eval(ProcedureName);
				
				If Cancel Then
					
					SetGoToNumber(GoToNumber + 1);
					
					Return;
					
				EndIf;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	GoToRowsCurrent = GoToTable.FindRows(New Structure("GoToNumber", GoToNumber));
	
	If GoToRowsCurrent.Count() = 0 Then
		Raise NStr("en = 'Page to display is not defined.'");
	EndIf;
	
	GoToRowCurrent = GoToRowsCurrent[0];
	
	If GoToRowCurrent.LongAction AND Not IsGoNext Then
		
		SetGoToNumber(GoToNumber - 1);
		Return;
	EndIf;
	
	// handler OnOpen
	If Not IsBlankString(GoToRowCurrent.OnOpenHandlerName) Then
		
		ProcedureName = "Attachable_[HandlerName](Cancel, SkipPage, IsGoNext)";
		ProcedureName = StrReplace(ProcedureName, "[HandlerName]", GoToRowCurrent.OnOpenHandlerName);
		
		Cancel = False;
		SkipPage = False;
		
		A = Eval(ProcedureName);
		
		If Cancel Then
			
			SetGoToNumber(GoToNumber - 1);
			
			Return;
			
		ElsIf SkipPage Then
			
			If IsGoNext Then
				
				SetGoToNumber(GoToNumber + 1);
				
				Return;
				
			Else
				
				SetGoToNumber(GoToNumber - 1);
				
				Return;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ExecuteLongOperationHandler()
	
	GoToRowsCurrent = GoToTable.FindRows(New Structure("GoToNumber", GoToNumber));
	
	If GoToRowsCurrent.Count() = 0 Then
		Raise NStr("en = 'Page to display is not defined.'");
	EndIf;
	
	GoToRowCurrent = GoToRowsCurrent[0];
	
	// handler LongOperationHandling
	If Not IsBlankString(GoToRowCurrent.LongOperationHandlerName) Then
		
		ProcedureName = "Attachable_[HandlerName](Cancel, GoToNext)";
		ProcedureName = StrReplace(ProcedureName, "[HandlerName]", GoToRowCurrent.LongOperationHandlerName);
		
		Cancel = False;
		GoToNext = True;
		
		Try
			A = Eval(ProcedureName);
		Except
			Cancel = True;
			Info = ErrorInfo();
			ShowErrorInfo(Info);		
		EndTry;
		
		If Cancel Then
			
			SetGoToNumber(GoToNumber - 1);
			
			Return;
			
		ElsIf GoToNext Then
			
			SetGoToNumber(GoToNumber + 1);
			
			Return;
			
		EndIf;
		
	Else
		
		SetGoToNumber(GoToNumber + 1);
		
		Return;
		
	EndIf;
	
EndProcedure

// Adds new row to the end of current transitions table
//
// Parameters:
//
//  TransitionSequenceNumber (mandatory) - Number. Sequence number of transition that corresponds
//  to the current MainPageName transition step (mandatory) - String. Name of the MainPanel panel page that corresponds
//  to the current number of the NavigationPageName transition (mandatory) - String. Name of the NavigationPanel panel
//  page that corresponds to the current HandlerNameOnOpen transition number (optional) - String. Name of the
//  function-processor of the HandlerNameOnGoingNext assistant current page open event (optional) - String. Name of the function-processor of the HandlerNameOnGoingBack
//  transition to the next assistant page event (optional) - String. Name of the function-processor of the LongAction
//  transition to assistant previous page event (optional) - Boolean. Shows displayed long operation page.
//  True - long operation page is displayed; False - show normal page. Value by default - False.
// 
&AtClient
Procedure GoToTableNewRow(GoToNumber,
									MainPageName,
									NavigationPageName,
									DecorationPageName = "",
									OnOpenHandlerName = "",
									GoNextHandlerName = "",
									GoBackHandlerName = "",
									LongAction = False,
									LongOperationHandlerName = "")
	NewRow = GoToTable.Add();
	
	NewRow.GoToNumber			= GoToNumber;
	NewRow.MainPageName     	= MainPageName;
	NewRow.DecorationPageName	= DecorationPageName;
	NewRow.NavigationPageName	= NavigationPageName;
	
	NewRow.GoNextHandlerName = GoNextHandlerName;
	NewRow.GoBackHandlerName = GoBackHandlerName;
	NewRow.OnOpenHandlerName = OnOpenHandlerName;
	
	NewRow.LongAction = LongAction;
	NewRow.LongOperationHandlerName = LongOperationHandlerName;
	
EndProcedure

&AtClient
Function GetFormButtonByCommandName(FormItem, CommandName)
	
	For Each Item In FormItem.ChildItems Do
		
		If TypeOf(Item) = Type("FormGroup") Then
			
			FormItemByCommandName = GetFormButtonByCommandName(Item, CommandName);
			
			If FormItemByCommandName <> Undefined Then
				
				Return FormItemByCommandName;
				
			EndIf;
			
		ElsIf TypeOf(Item) = Type("FormButton")
			AND Find(Item.CommandName, CommandName) > 0 Then
			
			Return Item;
			
		Else
			
			Continue;
			
		EndIf;
		
	EndDo;
	
	Return Undefined;
	
EndFunction

#EndRegion

#Region ConnectedTransitionEventHandlers

&AtClient
Procedure FillTableManually()
	
	Parameters.DataLoadSettings.ManualFilling = True;
	ChangeGoToNumber(+1);
	
EndProcedure

// :::PageFileSelection

&AtClient
Function Attachable_PageFileSelection_OnOpen(Cancel, SkipPage, Val IsGoNext)
	
	If NOT IsGoNext Then
		ClearCurrentSettings();	
	EndIf;
	
EndFunction

&AtServer
Procedure ResetColumnNumbersInFieldTree()
	
	FieldTree = GetFromTempStorage(Parameters.DataLoadSettings.FieldsTreeStorageAddress);
	
	For Each FirstLevelRow In FieldTree.Rows Do
		
		FirstLevelRow.ColumnNumber	= 0;
		FirstLevelRow.ColorNumber	= FirstLevelRow.ColorNumberOriginal;
		
		For Each SecondLevelRow In FirstLevelRow.Rows Do
			SecondLevelRow.ColumnNumber	= 0;
			SecondLevelRow.ColorNumber	= SecondLevelRow.ColorNumberOriginal;
		EndDo;
		
	EndDo;
	
	PutToTempStorage(FieldTree, Parameters.DataLoadSettings.FieldsTreeStorageAddress);
	
EndProcedure

&AtServer
Procedure ClearCurrentSettings()
	
	SpreadsheetDocument.Clear();
	SpreadsheetDocumentMessages.Clear();
	
	ResetColumnNumbersInFieldTree()
	
EndProcedure

// :::PageDataImport

&AtClient
Function Attachable_PageDataImport_LongOperationProcessing(Cancel, GoToNext)
	
	GoToNext = True;
	ExecuteDataImportAtServer(GoToNext);
	If Not GoToNext Then
		
		AttachIdleHandler("CheckExecution", 0.1, True);
		
	EndIf;
	
EndFunction

// :::PagesDataCheck

&AtClient
Function Attachable_PagesDataCheck_OnOpen(Cancel, SkipPage, Val IsGoNext)
	Var Errors;
	
	If Not IsGoNext Then
		
		SkipPage = True;
		Return Undefined;
		
	EndIf;
	
	DenyTransitionNext = False;
	CheckReceivedData(SkipPage, DenyTransitionNext);
	
	If SkipPage Then
		
		Return Undefined;
		
	ElsIf DenyTransitionNext Then
		
		CommonUseClientServer.SetFormItemProperty(Items, "CommandNext1", "Enabled", False);
		
	EndIf;
	
EndFunction

&AtClient
Function Attachable_PagesDataCheck_OnGoBack(Cancel)
	
	CommonUseClientServer.SetFormItemProperty(Items, "CommandNext1", "Enabled", True);
	
EndFunction

// :::PageMatch

&AtClient
Function Attachable_PageMatching_OnOpen(Cancel, SkipPage, Val IsGoNext)
	
	If IsGoNext = True Then
		
		ExportedDataComparison();
		SkipPage = True;
		
	Else
		
		SetRowsFilterByFilterValue();
		SetRowsQuantityDecorationText();
		
		CurrentItem = Items.DataMatchingTable;
		
	EndIf;
	
EndFunction

// :::ImportSettingPage

&AtClient
Function Attachable_PagePreliminarilyTS_OnOpen(Cancel, SkipPage, Val IsGoNext) Export
	
	AddPossible = DataMatchingTable.FindRows(New Structure("_ImportToApplicationPossible", True)).Count();
	AddImpossible = DataMatchingTable.FindRows(New Structure("_ImportToApplicationPossible", False)).Count();
	
	Items.DecorationWillBeImportedCount.Title = String(AddPossible);
	Items.DecorationWillBeSkippedCount.Title = String(AddImpossible);
	
EndFunction

&AtClient
Function Attachable_PagePreliminaryCatalog_OnOpen(Cancel, SkipPage, Val IsGoNext) Export
	
	ReceivedData	= DataMatchingTable.Count();
	ConsistentData	= DataMatchingTable.FindRows(New Structure("_ImportToApplicationPossible", True)).Count();
	DataMatched		= DataMatchingTable.FindRows(New Structure("_RowMatched", True)).Count();
	
	Items.DecorationReceivedDataCount.Title 		= ReceivedData;
	Items.DecorationMatchedCountObject.Title 		= DataMatched;
	Items.DecorationUnmatchedRowsCountObject.Title	= ConsistentData - DataMatched;
	Items.DecorationIncorrectRowsCountObjects.Title	= ReceivedData - ConsistentData;
	
EndFunction

&AtClient
Function Attachable_PagePreliminarilyIR_OnOpen(Cancel, SkipPage, Val IsGoNext) Export
	
	ReceivedData 		= DataMatchingTable.Count();
	ConsistentData	= DataMatchingTable.FindRows(New Structure("_ImportToApplicationPossible", True)).Count();
	DataMatched	= DataMatchingTable.FindRows(New Structure("_RowMatched", True)).Count();
	
	Items.DecorationReceivedDataCountRS.Title	= ReceivedData;
	Items.DecorationMatchedCountIR.Title		= DataMatched;
	Items.DecorationUnmatchedRowsCountIR.Title	= ConsistentData - DataMatched;
	Items.DecorationIncorrectRowsCountIR.Title	= ReceivedData - ConsistentData;
	
EndFunction

#EndRegion

#Region TableOfGoToByScript

// Procedure defines scripted transitions table No1.
// To fill transitions table, use TransitionsTableNewRow()procedure
//
&AtClient
Procedure TableOfGoToByScript()
	
	GoToTable.Clear();
	
	GoToTableNewRow(1, "PageFileSelection",	"NavigationPageStart", , "PageFileSelection_OnOpen");
	GoToTableNewRow(2, "PageDataImport",	"NavigationPageWait",,,,, True, "PageDataImport_LongOperationProcessing");
	GoToTableNewRow(3, "PagesReceivedData",	"NavigationPageContinuation",,, );
	GoToTableNewRow(4, "PagesDataCheck",	"NavigationPageContinuation", , "PagesDataCheck_OnOpen", , "PagesDataCheck_OnGoBack");
	GoToTableNewRow(5, "PageMatching",		"NavigationPageContinuation", , "PageMatching_OnOpen");
	
	If Parameters.DataLoadSettings.IsTabularSectionImport Then
		
		GoToTableNewRow(6, "PagePreliminarilyTS", "NavigationPageEnd", , "PagePreliminarilyTS_OnOpen");
		
	ElsIf Parameters.DataLoadSettings.IsCatalogImport Then
		
		GoToTableNewRow(6, "PagePreliminaryCatalog","NavigationPageEnd", , "PagePreliminaryCatalog_OnOpen");
		
	ElsIf Parameters.DataLoadSettings.IsInformationRegisterImport Then
		
		GoToTableNewRow(6, "PagePreliminarilyInformationRegister", "NavigationPageEnd", , "PagePreliminarilyIR_OnOpen");
		
	EndIf;
	
EndProcedure

&AtClient
Procedure Decoration3URLProcessing(Item, FormattedStringURL, StandardProcessing)
	
	If FormattedStringURL = "ImportFromFile" Then	
		
		StandardProcessing							= False;		
		Parameters.DataLoadSettings.ManualFilling	= False;
		NotifyDescription 							= New NotifyDescription("SelectExternalFileDataProcessorEnd", ThisObject);
		
		DialogParameters = New Structure;
		DialogParameters.Insert("Mode",				FileDialogMode.Open);
		Filter = NStr("en = 'External sources for importing (*.%1, *.%2, *.%3)|*.%1;*.%2;*.%3|Microsoft Excel Workbook (*.%1)|*.%1|
		              |Spreadsheet document (*.%2)|*.%2|Comma Separated Values (*.%3)|*.%3'");
		Filter = StringFunctionsClientServer.SubstituteParametersInString(Filter, "xlsx", "mxl", "csv");
		DialogParameters.Insert("Filter",			Filter);
		DialogParameters.Insert("Multiselect",		False);
		DialogParameters.Insert("Title",			NStr("en = 'Select external file'"));
		DialogParameters.Insert("CheckFileExist",	True);
		
		StandardSubsystemsClient.ShowFilePlace(NotifyDescription, UUID, "", DialogParameters);
		
	ElsIf FormattedStringURL = "PasteCopiedData" Then
		
		StandardProcessing = False;		
		FillTableManually();
		
	EndIf;	
	
EndProcedure

#EndRegion
