
#Region ServiceProceduresAndFunctions

&AtServer
Procedure UpdateQueryText()

	TempQueryText = "";
	For Each TabRow In RequestsTable.FindRows(New Structure("Use", True)) Do

		TempQueryText = TempQueryText + ?(IsBlankString(TempQueryText), "", " UNION ALL ")
				+ TabRow.QueryText;

	EndDo;

	Position = Find(UPPER(TempQueryText), Upper("Select"));
	If Position > 0 Then

		TempQueryText = "SELECT ALLOWED " + Mid(TempQueryText, Position + StrLen("SELECT")) + 
		"ORDER
		|	BY
		|	Date, Document
		|";

	EndIf;

	QueryTextByDocuments = TempQueryText;

EndProcedure

&AtServer
Procedure SetFlagOfDocumentKindUsage()

	For Each TabRow In RequestsTable Do

		ItemOfList = DocumentsKindsList.FindByValue(TabRow.DocumentName);
		If ItemOfList <> Undefined Then
			TabRow.Use = ItemOfList.Check;
		EndIf;

	EndDo;

EndProcedure

&AtServer
Procedure UpdateDocumentTypesList()

	DocumentsKindsList.Clear();
	For Each String In RequestsTable Do
		DocumentsKindsList.Add(String.DocumentName, String.DocumentSynonym, String.Use);
	EndDo;

	DocumentsKindsList.SortByPresentation(SortDirection.Asc);

EndProcedure

&AtServer
Procedure ApplySettingsToDocumentTypesList(SettingValue)

	RearrangeQuery = False;
	For Each Item In SettingValue Do

		ItemOfList = DocumentsKindsList.FindByValue(Item.Value);
		If ItemOfList <> Undefined AND ItemOfList.Check <> Item.Check Then

			ItemOfList.Check = Item.Check;
			RearrangeQuery = True;

		EndIf;

	EndDo;

	If RearrangeQuery Then

		SetFlagOfDocumentKindUsage();

		UpdateQueryText();

		SaveSettings();

	EndIf;

EndProcedure

&AtClient
Procedure EditContentOfDocuments()

	Notification = New NotifyDescription("EditContentOfDocumentsEnd",ThisForm);
	OpenForm(FormNameDocumentTypesContentSetting,
				New Structure("DocumentsKindsList", DocumentsKindsList),,,,,Notification);

EndProcedure

&AtClient
Procedure EditContentOfDocumentsEnd(Result,Parameters) Export
	
	If TypeOf(Result) = Type("ValueList") Then
		ApplySettingsToDocumentTypesList(Result);
	EndIf;
	
EndProcedure

&AtServer
Procedure UpdateDocumentsTableAtServer()
	
	If IsBlankString(QueryTextByDocuments) Then
		
		CommonUseClientServer.MessageToUser(NStr("en = 'It is necessary to set content of documents'"),,"ThisForm");
		Return;
		
	EndIf;
	
	Query = New Query(QueryTextByDocuments);
	Query.SetParameter("Parameter",         Parameter);
	
	ValueToFormAttribute(Query.Execute().Unload(), "DocumentsTable");
	
EndProcedure

#Region WorkProcedureWithSettings

&AtServer
Procedure RestoreSettings()
	
	SettingsValue = CommonSettingsStorage.Load("DataProcessor.CounterpartyDocuments", SettingsKey);
	If TypeOf(SettingsValue) = Type("Map") Then
		
		ValueFromSetting = SettingsValue.Get("DocumentsKindsList");
		If TypeOf(ValueFromSetting) = Type("ValueList") Then
			ApplySettingsToDocumentTypesList(ValueFromSetting);
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure SaveSettings()
	
	Settings = New Map;
	Settings.Insert("DocumentsKindsList", DocumentsKindsList);
	
	CommonSettingsStorage.Save("DataProcessor.CounterpartyDocuments", SettingsKey, Settings);
	
EndProcedure

&AtServer
Procedure ApplyCommandParameters()

	If Parameters.Property("Filter") Then

		Parameters.Filter.Property("Order", Parameter);

	EndIf;

	If Parameters.Property("GenerateOnOpen") AND Parameters.GenerateOnOpen Then

		UpdateDocumentsTableAtServer();

	EndIf;

EndProcedure

&AtServer
Procedure FillQueryTable(DataProcessorObject)

	HeaderFields = New Array;
	HeaderFields.Add("DocumentAmount");
	HeaderFields.Add("OperationKind");
	HeaderFields.Add("DocumentCurrency");
	HeaderFields.Add("Department");
	HeaderFields.Add("Company");
	HeaderFields.Add("Responsible");
	HeaderFields.Add("Comment");
	HeaderFields.Add("Author");

	DataProcessorObject.FillQueryTable(RequestsTable,
			HeaderFields,,
			"SupplierQuoteDocuments");

EndProcedure

&AtServer
Procedure SetSettingsKey()

	If Parameters.Property("SettingsKey") AND Not IsBlankString(Parameters.SettingsKey) Then

		SettingsKey = Parameters.SettingsKey;

	Else

		SettingsKey = "WithoutOrder";

	EndIf;

	SettingsKey = SettingsKey + "_" + Users.CurrentUser().UUID();

	If Parameters.Property("Filter") AND Parameters.Filter.Property("Order") Then

		SettingsKey = SettingsKey + "_" + Parameters.Filter.Order.UUID();

	EndIf;

EndProcedure

#EndRegion

#EndRegion

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	DataProcessorObject = FormAttributeToValue("Object");

	FormNameDocumentTypesContentSetting = DataProcessorObject.Metadata().FullName()
			+ ".Form.DocumentsKindsCompositionSetting";

	SetSettingsKey();

	FillQueryTable(DataProcessorObject);

	UpdateDocumentTypesList();

	RestoreSettings();

	UpdateQueryText();

	ApplyCommandParameters();

EndProcedure

&AtClient
Procedure OnClose(Exit)
	
	If Exit Then
		Return;
	EndIf;

	SaveSettings();

EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure SetContentOfDocuments(Command)

	EditContentOfDocuments();

EndProcedure

&AtClient
Procedure Generate(Command)

	UpdateDocumentsTableAtServer();

EndProcedure

&AtClient
Procedure Edit(Command)

	CurrentData = Items.DocumentsTable.CurrentData;
	If CurrentData <> Undefined Then

		ShowValue(Undefined,CurrentData.Document);

	EndIf;

EndProcedure

&AtClient
Procedure DocumentsTableSelection(Item, SelectedRow, Field, StandardProcessing)

	ShowValue(Undefined,Item.CurrentData.Document);

EndProcedure

#EndRegion
