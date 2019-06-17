
#Region Variables

&AtClient
Var IdleHandlerParameters;

#EndRegion

#Region FormEventHandlers

&AtClient
Procedure OnOpen(Cancel)
	
	Items.ImportCompany.TypeRestriction					= New TypeDescription("CatalogRef.Companies");
	Items.ImportCompanyAccount.TypeRestriction			= New TypeDescription("CatalogRef.BankAccounts");
	Items.ImportCounterparty.TypeRestriction			= New TypeDescription("CatalogRef.Counterparties");
	Items.ImportCounterpartyBankAccount.TypeRestriction	= New TypeDescription("CatalogRef.BankAccounts");
	Items.ImportContract.TypeRestriction				= New TypeDescription("CatalogRef.CounterpartyContracts");
	
	Items.Footer.Visible = False;
	
	If ValueIsFilled(Object.Bank) Then
		UpdateSettings();
		CheckSettings();
	Else
		Items.ImportBankStatement.Enabled = False;
		Items.ExportBankStatement.Enabled = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "RecordedItemBank" OR EventName = "RecordedItemExchangeSettings" Then
		UpdateSettings();
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure Back(Command)
	
	If Object.Import.Count() > 0 Then
		ShowQueryBox(New NotifyDescription("BackQuestionEnd", ThisForm),
			NStr("en = 'Unapplied changes will be lost. Continue?'"),
			QuestionDialogMode.OKCancel);
	Else
		ClearAndBack();
	EndIf;
	
EndProcedure

&AtClient
Procedure CancelBackgroundJob(Command)
	CancelBackgroundJobAtServer(JobID);
	ClearAndBack();
EndProcedure

&AtClient
Procedure Setting(Command)
	
	If CheckSettings() Then
		OpenForm("Catalog.BankStatementProcessingSettings.ObjectForm",
			New Structure("Key", Object.ExchangeSettings),
			ThisForm);
	EndIf;
	
EndProcedure

&AtClient
Procedure ImportBankStatementFromFile(Command)
	
	If CheckSettings() Then
		
		IsImport = True;
		TableName = "Import";
		
		DialogueParameters = New Structure;
		DialogueParameters.Insert("Mode",			FileDialogMode.Open);
		DialogueParameters.Insert("Filter",			FileExtensions);
		DialogueParameters.Insert("Multiselect",	False);
		DialogueParameters.Insert("Title",			NStr("en = 'Select a file for import'"));
		DialogueParameters.Insert("CheckFileExist",	True);
		DialogueParameters.Insert("Directory",		ImportDirectory);
		
		NotifyDescription = New NotifyDescription("AfterFilePlace", ThisObject);
		
		Items.Pages.CurrentPage = Items.PageLongOperation;
		
		StandardSubsystemsClient.ShowFilePlace(NotifyDescription, UUID, "", DialogueParameters);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ExportBankStatementToFile(Command)
	
	If CheckSettings() Then
		
		IsImport = False;
		TableName = "DocumentsForExport";
		
		If Not ValueIsFilled(Object.StartPeriod) Then
			Object.StartPeriod = BegOfDay(CurrentDate());
		EndIf;
		
		If Not ValueIsFilled(Object.EndPeriod) Then
			Object.EndPeriod = EndOfDay(CurrentDate());
		EndIf;
		
		Period.StartDate = Object.StartPeriod;
		Period.EndDate = Object.EndPeriod;
		
		Items.Pages.CurrentPage				= Items.PageExport;
		Items.Footer.Visible				= True;
		Items.ExportButton.DefaultButton	= True;
		If IsBlankString(HideRowsWithExportedDocuments) Then
			HideRowsWithExportedDocuments = "ShowAll";
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure MarkAllExecute(Command)
	SetFlags(True);
EndProcedure

&AtClient
Procedure ClearAllExecute(Command)
	SetFlags(False);
EndProcedure

&AtClient
Procedure MarkAllExecuteExport(Command)
	SetFlagsExport(True);
EndProcedure

&AtClient
Procedure ClearAllExecuteExport(Command)
	SetFlagsExport(False);
EndProcedure

&AtClient
Procedure ImportExecute(Command)
	
	ClearMessages();
	
	ShowEmptyError = NOT Object.Import.Count() > 0;
	
	If NOT ShowEmptyError Then
		
		ShowEmptyError = True;
		
		For Each Row In Object.Import Do
			If Row.Mark Then
				ShowEmptyError = False;
			EndIf;
		EndDo;
		
		If CheckImport() Then
			IsCreatingDocuments = True;
			AttachIdleHandler("Attachable_ExecuteInBackground", 0.2, True);
		EndIf;
		
	EndIf;
	
	If ShowEmptyError Then
		ShowMessageBox(Undefined, NStr("en = 'Document list for import is empty.'"));
	EndIf;
	
EndProcedure

&AtClient
Procedure ExportExecute(Command)
	
	DocumentsForExportTable.Clear();
	For Each DocumentRow In Object.DocumentsForExport Do
		If DocumentRow.Mark Then
			NewRow = DocumentsForExportTable.Add();
			NewRow.Document = DocumentRow.Document;
		EndIf;
	EndDo;
	
	If DocumentsForExportTable.Count() > 0 Then
		If CheckExport() Then
			AttachIdleHandler("Attachable_ExecuteInBackground", 0.2, True);
		EndIf;
	Else
		ShowMessageBox(Undefined, NStr("en = 'There are no selected documents to export.'"));
	EndIf;
	
EndProcedure

&AtClient
Procedure SaveAndRefresh(Command)
	
	If IsImport Then
		SaveAndRecheck();
	Else
		SaveDocumentAttributesAndRecheck()
	EndIf;
	
	UpdateTotals();
	
EndProcedure

&AtClient
Procedure RefreshImport(Command)
	CheckAtServer();
	UpdateTotals();
EndProcedure

&AtClient
Procedure RefreshExport(Command)

	UpdatePaymentList();
	SetExportRowFilter();
	
EndProcedure

&AtClient
Procedure FillThisValueInEmptyLines(Command)
	
	CurData = Items.Import.CurrentData;
	
	If CurData = Undefined Then
		Return;
	EndIf;
	
	CurCounterparty	= CurData.Counterparty;
	CurCFItem		= CurData.CFItem;
	CurContract		= CurData.Contract;
	
	For Each Row In Object.Import Do
		
		If Row.Counterparty = CurCounterparty
			AND Row.CFItem = CurCFItem
			AND (TypeOf(Row.Contract) = Type("String")
				OR NOT ValueIsFilled(Row.Contract)) Then
			
			Row.Contract = CurContract;
			
		EndIf;
		
	EndDo;
	
	CheckAtServer();
	
EndProcedure

#EndRegion

#Region FormItemsEventHandlers

&AtClient
Procedure BankAccountOnChange(Item)
	
	If Object.DocumentsForExport.Count() > 0 Then
		ShowQueryBox(New NotifyDescription("BankAccountChangeQuestionEnd", ThisForm, Undefined),
			NStr("en = 'All data in table will be lost. Continue?'"),
			QuestionDialogMode.OKCancel);
	Else
		Object.DocumentsForExport.Clear();
		UpdatePaymentList();
		UpdateTotals();
		SetExportRowFilter();
	EndIf;
	
EndProcedure

&AtClient
Procedure BankOnChange(Item)
	UpdateSettings();
EndProcedure

&AtClient
Procedure DocumentsForExportMarkOnChange(Item)
	UpdateTotals();
EndProcedure

&AtClient
Procedure DocumentsForExportOnActivateRow(Item)
	
	CurData = Item.CurrentData;
	
	If CurData = Undefined Then
		Return;
	EndIf;
	
	RefillErrorTable(CurData.ErrorID);
	
EndProcedure

&AtClient
Procedure DocumentsForExportSelection(Item, SelectedRow, Field, StandardProcessing)
	
	CurData = Items.DocumentsForExport.CurrentData;
	
	If Field.Name = "DocumentsForExportDocument"
		AND ValueIsFilled(CurData.Document) Then
		OpenForm("Document.PaymentExpense.ObjectForm",
			New Structure("Key", CurData.Document),
			CurData.Document);
		EndIf;
		
EndProcedure

&AtClient
Procedure HideRowsWithDocumentsOnChange(Item)
	SetImportRowFilter();
EndProcedure

&AtClient
Procedure HideRowsWithExportedDocumentsOnChange(Item)
	SetExportRowFilter();
EndProcedure

&AtClient
Procedure ImportOnActivateRow(Item)
	
	CurData = Item.CurrentData;
	
	If CurData = Undefined Then
		Return;
	EndIf;
	
	RefillErrorTable(CurData.ErrorID);
	
EndProcedure

&AtClient
Procedure ImportOnActivateField(Item)
	
	If Item.CurrentItem.Name = "ImportContract" Then
		ItemForChange = Item.ContextMenu.ChildItems.Find("ImportContextMenuFillThisValueInEmptyLines");
		ItemForChange.Visible = True;
	Else
		ItemForChange = Item.ContextMenu.ChildItems.Find("ImportContextMenuFillThisValueInEmptyLines");
		ItemForChange.Visible = False;
	EndIf;

EndProcedure

&AtClient
Procedure ImportOnChange(Item)
	
	CurData = Item.CurrentData;
	
	If CurData = Undefined
		OR Item.CurrentItem.Name = "Mark" Then
		Return;
	EndIf;
	
	CheckAtServer();
	
EndProcedure

&AtClient
Procedure ImportOnStartEdit(Item, NewRow, Clone)
	
	CurData = Item.CurrentData;
	
	If CurData = Undefined Then
		Return;
	EndIf;
	
	If Item.CurrentItem.Name = "ImportOperationKind" Then
		
		TypeRestrict = Undefined;
		
		If NOT ValueIsFilled(CurData.DocumentKind) Then
			Return;
		ElsIf CurData.DocumentKind = "PaymentExpense" Then
			TypeRestrict = New TypeDescription("EnumRef.OperationTypesPaymentExpense");
		Else
			TypeRestrict = New TypeDescription("EnumRef.OperationTypesPaymentReceipt");
		EndIf;
		
		Item.CurrentItem.TypeRestriction = TypeRestrict;
		
	ElsIf Item.CurrentItem.Name = "ImportCounterpartyBankAccount" Then
		
		If ValueIsFilled(CurData.Counterparty) Then
			
			ResultArray		= New Array;
			NewParameter	= New ChoiceParameter("Filter.Owner", CurData.Counterparty);
			ResultArray.Add(NewParameter);
			
			Item.CurrentItem.ChoiceParameters = New FixedArray(ResultArray);
			
		Else
			
			ResultArray		= New Array;
			NewParameter	= New ChoiceParameter("Filter.IsCompanyAccount", False);
			ResultArray.Add(NewParameter);
			
			Item.CurrentItem.ChoiceParameters = New FixedArray(ResultArray);
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ImportSelection(Item, SelectedRow, Field, StandardProcessing)
	
	CurData = Items.Import.CurrentData;
	
	If Field.Name = "ImportDocument"
		AND ValueIsFilled(CurData.Document) Then
		OpenForm("Document." + CurData.DocumentKind + ".ObjectForm",
			New Structure("Key", CurData.Document),
			CurData.Document);
	EndIf;
	
EndProcedure

&AtClient
Procedure ImportDocumentStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	TabularSectionRow = Items.Import.CurrentData;
	
	StructureFilter = New Structure;
	
	If TypeOf(TabularSectionRow.Counterparty) = Type("CatalogRef.Counterparties")
		AND ValueIsFilled(TabularSectionRow.Counterparty) Then
		StructureFilter.Insert("Counterparty", TabularSectionRow.Counterparty);
	EndIf;
	
	If TypeOf(TabularSectionRow.Company) = Type("CatalogRef.Companies")
		AND ValueIsFilled(TabularSectionRow.Company) Then
		StructureFilter.Insert("Company", TabularSectionRow.Company);
	EndIf;
	
	ParameterStructure = New Structure("Filter, DocumentType, ThisIsBankStatementProcessing",
							StructureFilter, Undefined, True);
	
	OpenForm("CommonForm.SelectDocumentOfSettlements", ParameterStructure, Item);
	
EndProcedure

&AtClient
Procedure ErrorTableOnStartEdit(Item, NewRow, Clone)
	
	CurData = Item.CurrentData;
	
	If CurData = Undefined Then
		Return;
	EndIf;
	
	ItemForChange = Items.ErrorTableValue;
	
	If TypeOf(CurData.DefaultValue) = Type("CatalogRef.BankAccounts") Then
		ItemForChange.ChoiceParameters = GetChoiceParametersByErrorID(CurData.ID, CurData.Attribute);
	EndIf;

EndProcedure

&AtClient
Procedure ErrorTableValueOnChange(Item)
	
	CurData = Items.ErrorTable.CurrentData;
	
	If CurData = Undefined Then
		Return;
	EndIf;
	
	SaveAndFillDependenceInErrorTable(CurData.ID, CurData.Attribute, CurData.ReceivedValue, CurData.Value);
	
EndProcedure

&AtClient
Procedure PeriodOnChange(Item)
	
	Object.StartPeriod = Period.StartDate;
	Object.EndPeriod = ?(ValueIsFilled(Period.EndDate), EndOfDay(Period.EndDate), Period.EndDate);
	
	PeriodOnChangeOnServer();
	UpdateTotals();
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

#Region AttachableAndNotificationProcedures

&AtClient
Procedure Attachable_CheckJobExecution()
	
	JobCompleted = Undefined;
	
	Try
		JobCompleted = JobCompleted(JobID);
	Except
		
		Items.Pages.CurrentPage = Items.PageStart;
		Return;
		
	EndTry;
		
	If JobCompleted Then
		AfterJobCompleteAtServer();
	Else
		LongActionsClient.UpdateIdleHandlerParameters(IdleHandlerParameters);
		AttachIdleHandler(
			"Attachable_CheckJobExecution", 
			IdleHandlerParameters.CurrentInterval, 
			True);
	EndIf;

EndProcedure

&AtClient
Procedure Attachable_ExecuteInBackground()
	
	Items.Pages.CurrentPage	= Items.PageLongOperation;
	Items.Footer.Visible	= False;
	
	AfterBackgroundJobEnds(ExecuteInBackground());
	
EndProcedure

&AtClient
Procedure AfterFilePlace(PlacedFiles, AdditionalParameters) Export
	
	If PlacedFiles = Undefined OR PlacedFiles.Count() = 0 Then
		Items.Pages.CurrentPage = Items.PageStart;
		Return;
	EndIf;
	
	IsImport		= True;
	StorageAddress	= PlacedFiles[0].Location;
	
	AttachIdleHandler("Attachable_ExecuteInBackground", 0.2, True);
	
EndProcedure

&AtClient
Procedure BackQuestionEnd(Response, AdditionalParameters) Export
	
	If Response = DialogReturnCode.OK Then
		ClearAndBack();
	EndIf;
	
EndProcedure

&AtClient
Procedure BankAccountChangeQuestionEnd(Response, AdditionalParameters) Export
	
	If Response = DialogReturnCode.OK Then
		Object.DocumentsForExport.Clear();
		UpdatePaymentList();
		UpdateTotals();
		SetExportRowFilter();
	EndIf;
	
EndProcedure

&AtClient
Procedure ShowSaveFile(IsInstalled, AdditionalParameters) Export
	
	SaveFile = New FileDialog(FileDialogMode.Save);
	SaveFile.Multiselect	= False;
	SaveFile.Title			= NStr("en = 'Save file'");
	SaveFile.Directory		= ExportDirectory;
	SaveFile.Filter			= StringFunctionsClientServer.SubstituteParametersInString(
								"%1",
								FileExtensions);
		
	If SaveFile.Choose() Then
		PathToFile = SaveFile.FullFileName;
		Items.Pages.CurrentPage = Items.PageExport;
	Else
		Items.Pages.CurrentPage = Items.PageExport;
		Return;
	EndIf;
	
EndProcedure

&AtClient
Procedure SettingsQuestionEnd(Response, AdditionalParameters) Export
	
	If Response = DialogReturnCode.OK Then
		OpenForm("Catalog.Banks.ObjectForm", New Structure("Key", Object.Bank));
	EndIf;
	
EndProcedure

#EndRegion

#Region BackgroundJobsHandlers

&AtClient
Procedure AfterBackgroundJobEnds(Result)
	
	JobID				= Result.JobID;
	JobStorageAddress	= Result.StorageAddress;
	
	If Result.JobCompleted Then
		AfterJobComplete();
		UpdateTotals();
	Else
		LongActionsClient.InitIdleHandlerParameters(IdleHandlerParameters);
		AttachIdleHandler("Attachable_CheckJobExecution", 1, True);
	EndIf;
	
EndProcedure

&AtClient
Procedure AfterJobComplete()
	
	If NOT IsImport Then
		NotifyDescription = New NotifyDescription("ShowSaveFile", ThisForm);
		CommonUseClient.ShowFileSystemExtensionInstallationQuestion(NotifyDescription);
	EndIf;
	
	Result = AfterJobCompleteAtServer();
	
	If Result AND NOT IsImport AND Not IsBlankString(PathToFile) Then
		BinaryData.Write(PathToFile);
		CommonUseClientServer.MessageToUser(StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = '%1 lines exported successfully.';"),
			DocumentsForExportTable.Count()));
	EndIf;
	
EndProcedure

&AtServer
Function AfterJobCompleteAtServer()
	
	ResultStructure = GetFromTempStorage(JobStorageAddress);
	Result = True;
	
	If ResultStructure.Done Then
		
		If ResultStructure.JobName = "ExecuteImportFromFile" Then
			
			Object.Import.Load(ResultStructure.ImportedTable);
			
			CheckAtServer();
			
			Items.Pages.CurrentPage				= Items.PageImport;
			Items.Footer.Visible				= True;
			Items.ImportButton.DefaultButton	= True;
			
			If IsBlankString(HideRowsWithDocuments) Then
				HideRowsWithDocuments = "ShowAll";
			EndIf;
			
			SetImportRowFilter();
			
		ElsIf ResultStructure.JobName = "ExecuteExportToFile" Then
			BinaryData = ResultStructure.BinaryData;
			
			If IsBlankString(HideRowsWithExportedDocuments) Then
				HideRowsWithExportedDocuments = "ShowAll";
			EndIf;
			
			If NOT IsBlankString(PathToFile) Then
				For Each DocumentRow In DocumentsForExportTable Do
					PaymentObject = DocumentRow.Document.GetObject();
					PaymentObject.ExportDate = CurrentDate();
					PaymentObject.Write();
				EndDo;
				
				UpdatePaymentList();
				SetExportRowFilter();
			EndIf;
			
		ElsIf ResultStructure.JobName = "ExecuteCreateImportDocuments" Then
			
			Object.Import.Load(ResultStructure.ImportTable);
			If NOT ResultStructure.Errors = Undefined Then
				CommonUseClientServer.ShowErrorsToUser(ResultStructure.Errors);
			EndIf;
			
			Items.Pages.CurrentPage	= Items.PageImport;
			Items.Footer.Visible	= True;
			
			SaveAndRecheck();
			
		EndIf;
		
	Else
		
		CommonUseClientServer.ShowErrorsToUser(ResultStructure.Errors);
		
		If ResultStructure.JobName = "ExecuteImportFromFile" Then
			Items.Pages.CurrentPage = Items.PageStart;
		ElsIf ResultStructure.JobName = "ExecuteExportToFile" Then
			Items.Pages.CurrentPage	= Items.PageExport;
			Items.Footer.Visible	= True;
		ElsIf ResultStructure.JobName = "ExecuteCreateImportDocuments" Then
			Items.Pages.CurrentPage	= Items.PageImport;
			Items.Footer.Visible	= True;
		EndIf;
		
		Result = False;
		
	EndIf;
	
	Return Result;
	
EndFunction

&AtServerNoContext
Procedure CancelBackgroundJobAtServer(JobID)
	LongActions.CancelJobExecution(JobID);
EndProcedure

&AtServer
Function ExecuteInBackground()
	
	ParametersStructureBackgroundJob	= New Structure("ExchangeSettings", Object.ExchangeSettings);
	BackgroundJobProcedure				= "";
	JobDescription						= "";
	
	If IsCreatingDocuments Then
		
		ParametersStructureBackgroundJob.Insert("AutomaticallyFillInDebts",	Object.ExchangeSettings.AutomaticallyFillInDebts);
		ParametersStructureBackgroundJob.Insert("ImportTable",				Object.Import.Unload());
		
		BackgroundJobProcedure	= "WorkWithBanks.ExecuteCreateImportDocuments";
		JobDescription			= NStr("en = 'Bank statement processing - creating imported documents'");
	
	ElsIf IsImport Then
		
		Object.Import.Clear();
		
		ParametersStructureBackgroundJob.Insert("BinaryData",		GetFromTempStorage(StorageAddress));
		ParametersStructureBackgroundJob.Insert("ImportedTable",	Object.Import.Unload());
		
		BackgroundJobProcedure	= "WorkWithBanks.ExecuteImportFromFile";
		JobDescription			= NStr("en = 'Bank statement processing - reading file'");
		
	Else
		
		ParametersStructureBackgroundJob.Insert("DocumentsForExportTable", FormAttributeToValue("DocumentsForExportTable"));
		
		BackgroundJobProcedure	= "WorkWithBanks.ExecuteExportToFile";
		JobDescription			= NStr("en = 'Bank statement processing - exporting to file'");
	
	EndIf;
	
	Return LongActions.ExecuteInBackground(
		UUID,
		BackgroundJobProcedure,
		ParametersStructureBackgroundJob,
		JobDescription);
	
EndFunction

&AtServerNoContext
Function JobCompleted(JobID)
	Return LongActions.JobCompleted(JobID);
EndFunction

#EndRegion

&AtClient
Procedure ClearAndBack()
	
	ClearMessages();
	
	Object.Import.Clear();
	Object.DocumentsForExport.Clear();
	Object.ErrorTable.Clear();
	ErrorTable.Clear();
	
	BankAccount			= Undefined;
	IsCreatingDocuments = False;
	
	Items.Pages.CurrentPage	= Items.PageStart;
	Items.Footer.Visible	= False;
	
EndProcedure

&AtServer
Procedure RefillErrorTable(ErrorID)
	
	ErrorTable.Clear();
	
	Rows = Object.ErrorTable.FindRows(New Structure("ID", ErrorID));
	For Each Row In Rows Do
		
		NewRow = ErrorTable.Add();
		FillPropertyValues(NewRow, Row);
		
	EndDo;
	
	CountOfErrors = ErrorTable.Count() > 0;
	Items.DataMapping.Visible = CountOfErrors;
	Items.DataErrors.Visible = CountOfErrors;

EndProcedure

&AtClient
Function CheckImport()
	
	Cancel = False;
	
	For Each Row In Object.Import Do
		
		If Row.Mark AND ValueIsFilled(Row.ErrorID) Then
			CommonUseClientServer.MessageToUser(
				StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = 'Data in the line %1 is not mapped. See data mapping section for details.'"),
					Row.LineNumber),,
				CommonUseClientServer.PathToTabularSection("Import", Row.LineNumber, "ImageNumber"),
				"Object",
				Cancel);
		EndIf;
		
	EndDo;
	
	Return Not Cancel;
	
EndFunction

&AtClient
Function CheckExport()
	
	Cancel = False;
	
	For Each Row In Object.DocumentsForExport Do
		
		If Row.Mark And Row.ImageNumber = 5 Then
			If Not ValueIsFilled(Row.CounterpartyBankAccount) Then
				CommonUseClientServer.MessageToUser(
				NStr("en = 'Counterparty bank account is unfilled'"),,
				CommonUseClientServer.PathToTabularSection("DocumentsForExport", Row.LineNumber, "CounterpartyBankAccount"),
				"Object",
				Cancel);
			EndIf;
		EndIf;
	EndDo;
	
	Return Not Cancel;
	
EndFunction

&AtServer
Function GetOpeningBalance()
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	CashAssetsBalance.AmountCurBalance AS AmountBalance,
		|	CashAssetsBalance.Currency AS Currency
		|FROM
		|	AccumulationRegister.CashAssets.Balance(&Period, BankAccountPettyCash = &BankAccount) AS CashAssetsBalance";
	
	Query.SetParameter("BankAccount", BankAccount);
	Query.SetParameter("Period", CurrentDate());
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	If Selection.Next() Then
		Currency = Selection.Currency;
		Return Selection.AmountBalance;	
	EndIf;
	
EndFunction

&AtServer
Procedure SaveAndRecheck()
	
	MappingRecordSet	= InformationRegisters.BankStatementMapping.CreateRecordSet();
	MappingVT			= MappingRecordSet.Unload();
	MetadataAttributes	= Metadata.Enums.BankMappingAttribute.EnumValues;
	EnumsBankMapManager	= Enums.BankMappingAttribute;
	EnumIndex			= "";
	
	For Each ImportRow In Object.Import Do
		
		If ValueIsFilled(ImportRow.ErrorID) Then
			
			ErrorRows = Object.ErrorTable.FindRows(New Structure("ID", ImportRow.ErrorID));
			For Each ErrorRow In ErrorRows Do
				
				If ValueIsFilled(ErrorRow.Value) Then
					
					EnumIndex = EnumsBankMapManager.IndexOf(ErrorRow.Attribute);
					ImportRow[MetadataAttributes[EnumIndex].Name] = ErrorRow.Value;
					
					If NOT IsBlankString(ErrorRow.ReceivedValue) Then
						NewRecord = MappingVT.Add();
						FillPropertyValues(NewRecord, ErrorRow);
						NewRecord.Bank = Object.Bank;
					EndIf;
					
				EndIf;
				
			EndDo;
			
		EndIf;
		
	EndDo;
	
	If MappingVT.Count() > 0 Then
		MappingVT.GroupBy("Bank, Attribute, ReceivedValue, Value");
		MappingRecordSet.Load(MappingVT);
		MappingRecordSet.Write(False);
	EndIf;
	
	CheckAtServer();
	
EndProcedure

&AtServer
Procedure SaveDocumentAttributesAndRecheck()
	
	If ErrorTable.Count() = 0 Then
		Return;
	Else
		DocumentRows = Object.DocumentsForExport.FindRows(New Structure("ErrorID", ErrorTable[0].ID));
		If DocumentRows.Count() > 0 Then
			PaymentObject = DocumentRows[0].Document.GetObject();
		EndIf;
	EndIf;
	
	WriteObject = False;
	
	For Each ErrorRow In ErrorTable Do
		If TypeOf(ErrorRow.Value) = Type("CatalogRef.BankAccounts")
			And ValueIsFilled(ErrorRow.Value) Then
			
			WriteObject = True;
			
			If ErrorRow.Attribute = Enums.BankMappingAttribute.BankAccount Then
				PaymentObject.BankAccount = ErrorRow.Value;
			ElsIf ErrorRow.Attribute = Enums.BankMappingAttribute.CounterpartyBankAccount Then
				PaymentObject.CounterpartyAccount = ErrorRow.Value;
			EndIf;
		EndIf;
	EndDo;
	
	If WriteObject Then 
		PaymentObject.Write();
		CheckAtServer();
	EndIf;
	
EndProcedure

&AtServer
Procedure SetImportRowFilter()
	
	Value = Undefined;
	
	If HideRowsWithDocuments = "Hide" Then
		
		EmptyExpense = Documents.PaymentExpense.EmptyRef();
		EmptyReceipt = Documents.PaymentReceipt.EmptyRef();
		
		For Each Row In Object.Import Do
			Row.Show = Row.Document = Undefined
						OR Row.Document = EmptyExpense
						OR Row.Document = EmptyReceipt;
		EndDo;
		
		Value = New FixedStructure("Show", True);
		
	EndIf;
	
	Items.Import.RowFilter = Value;
	
EndProcedure

&AtServer
Procedure SetExportRowFilter()
	
	Value = Undefined;

	If HideRowsWithExportedDocuments = "Hide" Then
		
		For Each Row In Object.DocumentsForExport  Do
			Row.Show = Not ValueIsFilled(Row.ExportDate);
		EndDo;
		
		Value = New FixedStructure("Show", True);
		
	EndIf;
	
	Items.DocumentsForExport.RowFilter = Value;
	
EndProcedure

&AtServer
Procedure CheckAtServer()
	
	ProcObj = FormAttributeToValue("Object");
	If IsImport Then
		ProcObj.CheckAndFillInImportTable(IsImport);
	Else
		ProcObj.CheckAndFillInExportTable(BankAccount, IsImport);
	EndIf;
	
	ValueToFormAttribute(ProcObj, "Object");
	
	ErrorTable.Clear();
	
	If Object.ErrorTable.Count() > 0 Then
		
		Items.ErrorTable.Visible = True;
		
		CurRow = Items.Import.CurrentRow;
		If CurRow <> Undefined Then
			CurData = Object.Import.FindByID(CurRow);
			If CurData <> Undefined Then
				RefillErrorTable(CurData.ErrorID);
			EndIf;
		EndIf;
		
	Else
		Items.ErrorTable.Visible = False;
	EndIf;
	
	If IsImport Then
		SetImportRowFilter();
	Else
		SetExportRowFilter();
	EndIf;
	
EndProcedure

&AtClient
Function CheckSettings()
	
	ReturningValue = False;
	
	If NOT ValueIsFilled(Object.Bank) Then
		CommonUseClientServer.MessageToUser(
			NStr("en = 'Select a bank to exchange data with.'"),,
			"Object.Bank");
	ElsIf NOT ValueIsFilled(Object.ExchangeSettings) Then
		NotifyDescription = New NotifyDescription("SettingsQuestionEnd", ThisForm);
		ShowQueryBox(NotifyDescription,
			StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Bank statement processing settings are missing for ""%1"". Do you want to specify them now?'"),
				Object.Bank),
			QuestionDialogMode.OKCancel);
	Else
		ReturningValue = True;
	EndIf;
	
	Return ReturningValue;
	
EndFunction

&AtClient
Procedure SetFlags(ValueOfFlag)
	
	For Each Row In Object.Import Do
		If NOT ValueIsFilled(Row.Document) Then
			Row.Mark = ValueOfFlag;
		EndIf;
	EndDo;
	
	UpdateTotals();
	
EndProcedure

&AtClient
Procedure SetFlagsExport(ValueOfFlag)
	
	For Each Row In Object.DocumentsForExport Do
		If NOT ValueIsFilled(Row.ExportDate) Or NOT ValueOfFlag Then
			Row.Mark = ValueOfFlag;
		EndIf;
	EndDo;
	
	UpdateTotals();
	
EndProcedure

&AtServer
Procedure UpdateSettings()
	
	Object.ExchangeSettings = Object.Bank.ExchangeSettings;
	
	Encoding		= Object.ExchangeSettings.Encoding;
	FileExtensions	= Object.ExchangeSettings.FileExtensions;
	ImportDirectory	= Object.ExchangeSettings.ImportDirectory;
	ExportDirectory	= Object.ExchangeSettings.ExportDirectory;
	
	Items.ImportBankStatement.Enabled	= Object.ExchangeSettings.UseImportFromFile;
	Items.ExportBankStatement.Enabled	= Object.ExchangeSettings.UseExportToFile;
	
EndProcedure

&AtServer
Function GetChoiceParametersByErrorID(ErrorID, Attribute)
	
	ResultArray			= New Array();
	IsCompanyAccount	= False;
	
	If Attribute = Enums.BankMappingAttribute.BankAccount Then
		IsCompanyAccount			= True;
		AttributeForSearch			= Enums.BankMappingAttribute.Company;
		AttributeForSearchInImport	= "Company";
	Else
		AttributeForSearch			= Enums.BankMappingAttribute.Counterparty;
		AttributeForSearchInImport	= "Counterparty";
	EndIf;
	
	IsCompanyAccountParameter = New ChoiceParameter("Filter.IsCompanyAccount", IsCompanyAccount);
	ResultArray.Add(IsCompanyAccountParameter);
	
	SearchArray = ErrorTable.FindRows(New Structure("ID, Attribute", ErrorID, AttributeForSearch));
	
	If SearchArray.Count() = 0 Then
		
		SearchArray = Object[TableName].FindRows(New Structure("ErrorID", ErrorID));
		
		If SearchArray.Count() = 0 Then
			Return New FixedArray(ResultArray);
		EndIf;
		
		Value = SearchArray[0][AttributeForSearchInImport];
		
	Else
		Value = SearchArray[0].Value;
	EndIf;
	
	If TypeOf(Value) = Type("String") 
		OR NOT ValueIsFilled(Value) Then
		Return New FixedArray(ResultArray);
	EndIf;
	
	NewParameter = New ChoiceParameter("Filter.Owner", Value);
	ResultArray.Add(NewParameter);
	
	Return New FixedArray(ResultArray);
	
EndFunction

&AtServer
Procedure SaveAndFillDependenceInErrorTable(ID, Attribute, ReceivedValue, Value)
	
	Rows = Object.ErrorTable.FindRows(New Structure("Attribute, ReceivedValue", Attribute, ReceivedValue));
	
	For Each Row In Rows Do
		
		If Row.ID = ID
			OR NOT ValueIsFilled(Row.Value)Then
			Row.Value = Value;
		EndIf;
		
	EndDo;
	
	If Attribute = Enums.BankMappingAttribute.CounterpartyBankAccount Then
		AttributeForSearch	= Enums.BankMappingAttribute.Counterparty;
		NewValue			= Value.Owner;
	ElsIf Attribute = Enums.BankMappingAttribute.Counterparty Then
		AttributeForSearch	= Enums.BankMappingAttribute.CounterpartyBankAccount;
		NewValue			= Undefined;
	ElsIf Attribute = Enums.BankMappingAttribute.BankAccount Then
		AttributeForSearch	= Enums.BankMappingAttribute.Company;
		NewValue			= Undefined;
	ElsIf Attribute = Enums.BankMappingAttribute.Company Then
		AttributeForSearch	= Enums.BankMappingAttribute.BankAccount;
		NewValue			= Value.Owner;
	Else
		Return;
	EndIf;
	
	SearchArray = ErrorTable.FindRows(New Structure("Attribute", AttributeForSearch));
	
	If SearchArray.Count() = 0 Then
		Return;
	EndIf;
	
	SearchArray[0].Value = NewValue;
	
	SearchInObjectArray = Object.ErrorTable.FindRows(New Structure("Attribute, ID", AttributeForSearch, ID));
	
	If SearchInObjectArray.Count() = 0 Then
		Return;
	EndIf;
	
	SearchInObjectArray[0].Value = NewValue;
	
EndProcedure

&AtClient
Procedure UpdateTotals()
	
	TotalCr = 0;
	TotalDr = 0;
	
	If IsImport Then
		For Each Row In Object.Import Do
			If Row.DocumentKind = "PaymentExpense" Then
				TotalCr = TotalCr + Row.Amount;
			Else
				TotalDr = TotalDr + Row.Amount;
			EndIf;
		EndDo;
	Else
		ClosingBalance = OpeningBalance;  
		For Each Row In Object.DocumentsForExport Do
			If Row.Mark Then
				TotalCr = TotalCr + Row.Amount;
				ClosingBalance = ClosingBalance - Row.Amount; 
			EndIf;
		EndDo;
	EndIf;
	
EndProcedure

&AtServer
Procedure PeriodOnChangeOnServer()
	UpdatePaymentList();
	SetExportRowFilter();
EndProcedure

&AtServer
Procedure UpdatePaymentList()
	
	If Not ValueIsFilled(BankAccount) Then
		Return;
	EndIf;
	
	ProcObj = FormAttributeToValue("Object");
	ProcObj.CheckAndFillInExportTable(BankAccount, IsImport);
	
	ValueToFormAttribute(ProcObj, "Object");
	
	OpeningBalance = GetOpeningBalance();

EndProcedure

#EndRegion
