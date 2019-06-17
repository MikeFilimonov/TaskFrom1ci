
#Region ServiceProceduresAndFunctions

Procedure AddError(Errors, ErrorText, ThisIsCriticalError = False, OccurrencePlace = "") Export
	
	ErrorDescription = Errors.Add();
	
	ErrorDescription.ErrorDescription		= ErrorText;
	ErrorDescription.Critical 			= ThisIsCriticalError;
	ErrorDescription.OccurrencePlace	= OccurrencePlace;
	
EndProcedure

Procedure FillInImportFieldsTable(ImportFieldsTable, DataLoadSettings) Export
	Var Manager;
	
	DataImportFromExternalSourcesOverridable.OverrideDataImportFieldsFilling(ImportFieldsTable, DataLoadSettings);
	
	If ImportFieldsTable.Count() = 0 Then
		DataImportFromExternalSourcesOverridable.DataImportFieldsFromExternalSource(ImportFieldsTable, DataLoadSettings);
	EndIf;
	
EndProcedure

Procedure OnCreateAtServer(FilledObject, DataLoadSettings, ThisObject, UseFormSSL = True) Export
	
	DataLoadSettings = New Structure;
	
	RunMode = CommonUseReUse.ApplicationRunningMode();
	DataLoadSettings.Insert("UseTogether", UseTogetherWithShippedSSLPart() AND UseFormSSL AND Not RunMode.ThisIsWebClient);
	
	If RunMode.ThisIsWebClient 
		OR Not DataLoadSettings.UseTogether Then
		
		DataImportMethodFromExternalSources= Enums.DataImportMethodFromExternalSources.FileChoice;
		
	Else
	
		DataImportMethodFromExternalSources= DriveReUse.GetValueOfSetting("DataImportMethodFromExternalSources");
		If Not ValueIsFilled(DataImportMethodFromExternalSources) Then
			
			DataImportMethodFromExternalSources= Enums.DataImportMethodFromExternalSources.FileChoice;
			DriveServer.SetUserSetting(DataImportMethodFromExternalSources, "DataImportMethodFromExternalSources");
			
		EndIf;
	
	EndIf;
	
	DataImportFormNameFromExternalSources = "DataProcessor.DataImportFromExternalSources.Form.AssistantFileChoice";
	
	FillingObjectFullName = FilledObject.FullName();
	DataImportFromExternalSourcesOverridable.WhenDeterminingDataImportForm(DataImportFormNameFromExternalSources, FillingObjectFullName, FilledObject);
	
	DataLoadSettings.Insert("FillingObjectFullName", 					FillingObjectFullName);
	DataLoadSettings.Insert("DataImportFormNameFromExternalSources",	DataImportFormNameFromExternalSources);
	
	IsTabularSectionImport = (Find(FillingObjectFullName, "TabularSection") > 0);
	DataLoadSettings.Insert("IsTabularSectionImport", IsTabularSectionImport);
	
	IsCatalogImport = (Find(FillingObjectFullName, "Catalog") > 0);
	DataLoadSettings.Insert("IsCatalogImport", IsCatalogImport);
	
	IsInformationRegisterImport = (Find(FillingObjectFullName, "InformationRegister") > 0);
	DataLoadSettings.Insert("IsInformationRegisterImport", IsInformationRegisterImport);
	
EndProcedure

Procedure AddImportDescriptionField(ImportFieldsTable, FieldName, FieldPresentation, FieldType, DerivedValueType, FieldsGroupName = "", Priority = 0, RequiredFilling = False, 
	GroupRequiredFilling = False, Visible = True, AdditionalAttributeFeature = False, AdditionalAttributeRef = Undefined) Export
	
	NewRow = ImportFieldsTable.Add();
	
	NewRow.FieldName 					= FieldName;
	NewRow.FieldPresentation 			= FieldPresentation;
	NewRow.FieldType 					= FieldType;
	NewRow.DerivedValueType 			= DerivedValueType;
	NewRow.FieldsGroupName 				= FieldsGroupName;
	NewRow.Priority 					= Priority;
	NewRow.RequiredFilling 				= RequiredFilling;
	NewRow.GroupRequiredFilling 		= GroupRequiredFilling;
	NewRow.Visible 						= Visible;
	NewRow.AdditionalAttributeFeature	= AdditionalAttributeFeature;
	NewRow.AdditionalAttributeRef 		= AdditionalAttributeRef;
	
EndProcedure

Procedure CreateFieldsAndGroupsTree(GroupsAndFields)
	
	GroupsAndFields = New ValueTree;
	GroupsAndFields.Columns.Add("FieldsGroupName",				New TypeDescription("String"));
	GroupsAndFields.Columns.Add("IncomingDataType");
	GroupsAndFields.Columns.Add("DerivedValueType");
	GroupsAndFields.Columns.Add("FieldName",					New TypeDescription("String"));
	GroupsAndFields.Columns.Add("FieldPresentation",			New TypeDescription("String"));
	GroupsAndFields.Columns.Add("ColumnNumber",					New TypeDescription("Number"));
	GroupsAndFields.Columns.Add("RequiredFilling",				New TypeDescription("Boolean"));
	GroupsAndFields.Columns.Add("GroupRequiredFilling",			New TypeDescription("Boolean"));
	GroupsAndFields.Columns.Add("Visible",						New TypeDescription("Boolean"));
	GroupsAndFields.Columns.Add("AdditionalAttributeFeature",	New TypeDescription("Boolean"));
	GroupsAndFields.Columns.Add("AdditionalAttributeRef",		New TypeDescription("ChartOfCharacteristicTypesRef.AdditionalAttributesAndInformation"));
	
EndProcedure

Procedure CreateImportDescriptionFieldsTable(ImportFieldsTable) Export
	
	ImportFieldsTable = New ValueTable;
	ImportFieldsTable.Columns.Add("FieldName");
	ImportFieldsTable.Columns.Add("FieldPresentation");
	ImportFieldsTable.Columns.Add("FieldType"); 					// Incoming data type
	ImportFieldsTable.Columns.Add("DerivedValueType");	// Data type in the application
	ImportFieldsTable.Columns.Add("FieldsGroupName");
	ImportFieldsTable.Columns.Add("Priority");
	ImportFieldsTable.Columns.Add("RequiredFilling");
	ImportFieldsTable.Columns.Add("GroupRequiredFilling");
	ImportFieldsTable.Columns.Add("Visible");
	ImportFieldsTable.Columns.Add("AdditionalAttributeFeature", New TypeDescription("Boolean"));
	ImportFieldsTable.Columns.Add("AdditionalAttributeRef", New TypeDescription("ChartOfCharacteristicTypesRef.AdditionalAttributesAndInformation"));
	
EndProcedure

Procedure CreateErrorsDescriptionTable(Errors) Export
	
	Errors = New ValueTable;
	
	Errors.Columns.Add("ErrorDescription",	New TypeDescription("String"));
	Errors.Columns.Add("Critical", 			New TypeDescription("Boolean"));
	Errors.Columns.Add("OccurrencePlace",	New TypeDescription("String"));
	
EndProcedure

Procedure GeneratePropertyUpdateSettings(FieldTree, DataLoadSettings) Export
	
	PropertyUpdateSettings = New Structure("UpdatableFieldNames, NotUpdatableFieldNames", "", "");
	FillFieldNameRows(FieldTree, DataLoadSettings, PropertyUpdateSettings);
	
	DataLoadSettings.Insert("PropertyUpdateSettings", PropertyUpdateSettings);
	
EndProcedure

Procedure GetManagerByFillingObjectName(FillingObjectFullName, Manager) Export
	
	Manager = CommonUse.ObjectManagerByFullName(FillingObjectFullName);
	
EndProcedure

Procedure AddServiceFields(ImportFieldsTable, ServiceFieldsGroup, FillingObjectFullName, ThisIsImportToTP) Export
	
	// Mandatory service field. Used by assistant.
	ServiceField						= ServiceFieldsGroup.Rows.Add(); 
	ServiceField.FieldName				= ServiceFieldNameImportToApplicationPossible();
	ServiceField.DerivedValueType= New TypeDescription("Boolean");
	
	If Not ThisIsImportToTP Then
		
		ServiceField						= ServiceFieldsGroup.Rows.Add(); 
		ServiceField.FieldName				= "_RowMatched";
		ServiceField.DerivedValueType		= New TypeDescription("Boolean");
		
	EndIf;
	
	// Possibility to describe custom service fields
	DataImportFromExternalSourcesOverridable.WhenAddingServiceFields(ServiceFieldsGroup, FillingObjectFullName);
	
EndProcedure

Procedure FillInGroupAndFieldsTree(ImportFieldsTable, GroupsAndFields, FillingObjectFullName, ThisIsImportToTP)
	
	FieldGroupsTable = ImportFieldsTable.Copy(,"FieldsGroupName");
	FieldGroupsTable.GroupBy("FieldsGroupName");
	
	TableRow = FieldGroupsTable.Add();
	TableRow.FieldsGroupName = FieldsMandatoryForFillingGroupName();
	
	TableRow = FieldGroupsTable.Add();
	TableRow.FieldsGroupName = FieldsGroupMandatoryForFillingName();
	
	TableRow = FieldGroupsTable.Add();
	TableRow.FieldsGroupName = FieldsGroupNameService();
	
	For Each TableRow In FieldGroupsTable Do
		
		If IsBlankString(TableRow.FieldsGroupName) Then
			
			// Fields are not united in groups and decomposed separately by property RequiredFilling
			Continue;
			
		EndIf;
		
		NewFirstLevelRow= GroupsAndFields.Rows.Add();
		NewFirstLevelRow.FieldsGroupName = TableRow.FieldsGroupName;
		
		FilterParameters = New Structure;
		FilterParameters.Insert("FieldsGroupName", TableRow.FieldsGroupName);
		If TableRow.FieldsGroupName = FieldsMandatoryForFillingGroupName() Then
			
			FilterParameters.Insert("FieldsGroupName", "");
			FilterParameters.Insert("RequiredFilling", True);
			
		ElsIf TableRow.FieldsGroupName = FieldsGroupMandatoryForFillingName() Then
			
			FilterParameters.Insert("FieldsGroupName", "");
			FilterParameters.Insert("RequiredFilling", False);
			
		ElsIf TableRow.FieldsGroupName = FieldsGroupNameService() Then
			
			AddServiceFields(ImportFieldsTable, NewFirstLevelRow, FillingObjectFullName, ThisIsImportToTP);
			Continue;
			
		EndIf;
		
		GroupRequiredFilling = False;
		RowArray 			= ImportFieldsTable.FindRows(FilterParameters);
		If RowArray.Count() > 0 Then
			
			IsCustomFieldsGroup = IsCustomFieldsGroup(TableRow.FieldsGroupName);
			If IsCustomFieldsGroup Then
				
				NewFirstLevelRow.DerivedValueType = RowArray[0].DerivedValueType; // type of a derived value is the same in all fields of one fields group (reference, string, number, etc.)
				NewFirstLevelRow.Visible = False;
				
			EndIf;
			
			For Each ArrayRow In RowArray Do
				
				NewSecondLevelRow = NewFirstLevelRow.Rows.Add();
				NewSecondLevelRow.FieldName = ArrayRow.FieldName;
				NewSecondLevelRow.IncomingDataType = ArrayRow.FieldType; // incoming data type (string, number)
				NewSecondLevelRow.DerivedValueType = ArrayRow.DerivedValueType;
				NewSecondLevelRow.FieldPresentation = ArrayRow.FieldPresentation;
				NewSecondLevelRow.RequiredFilling = ArrayRow.RequiredFilling;
				NewSecondLevelRow.GroupRequiredFilling = ArrayRow.GroupRequiredFilling;
				NewSecondLevelRow.Visible = ArrayRow.Visible;
				
				If NewSecondLevelRow.Visible Then
					
					NewFirstLevelRow.Visible = True;
					
				EndIf;
				
				GroupRequiredFilling = GroupRequiredFilling OR ArrayRow.GroupRequiredFilling;
				
			EndDo;
			
		EndIf;
		
		NewFirstLevelRow.GroupRequiredFilling = GroupRequiredFilling;
		
	EndDo;
	
EndProcedure

Procedure CreateAndFillGroupAndFieldsByObjectNameTree(DataLoadSettings, GroupsAndFields, ThisIsImportToTP = False) Export
	Var ImportFieldsTable;
	
	FillingObjectFullName = DataLoadSettings.FillingObjectFullName;
	IsTabularSectionImport = DataLoadSettings.IsTabularSectionImport;
	
	CreateImportDescriptionFieldsTable(ImportFieldsTable);
	FillInImportFieldsTable(ImportFieldsTable, DataLoadSettings);
	CreateFieldsAndGroupsTree(GroupsAndFields);
	FillInGroupAndFieldsTree(ImportFieldsTable, GroupsAndFields, FillingObjectFullName, ThisIsImportToTP);
	
EndProcedure

Procedure FillColumnNumbersInMandatoryFieldsAndGroupsTree(GroupsAndFields, SpreadsheetDocument) Export
	
	SelectedFields = New Array;
	
	Header = SpreadsheetDocument.GetArea("R1");
	For ColumnNumber = 1 To Header.TableWidth Do
		
		CellWithBreakdown = Header.GetArea(1, ColumnNumber, 1, ColumnNumber);
		FieldName = CellWithBreakdown.CurrentArea.DetailsParameter;
		
		If Not IsBlankString(FieldName) Then
			
			RowArray = GroupsAndFields.Rows.FindRows(New Structure("FieldName", FieldName), True);
			If RowArray.Count() > 0 Then
				
				RowArray[0].ColumnNumber = ColumnNumber;
				SelectedFields.Add(FieldName); // Remember that this field is already selected.
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure DeleteUnselectedFieldsInGroupsMadatoryForFilling(GroupsAndFields) Export
	
	For Each FieldsGroup In GroupsAndFields.Rows Do
		
		If FieldsGroup.FieldsGroupName = "_FieldsGroupMandatoryForFilling" Then // do not clear fields mandatory for filling
			
			Continue;
			
		EndIf;
		
		RecordsLeftToHandle = FieldsGroup.Rows.Count();
		While RecordsLeftToHandle <> 0 Do
			
			FieldsGroupField = FieldsGroup.Rows.Get(RecordsLeftToHandle - 1);
			If FieldsGroupField.ColumnNumber = 0 Then
				
				FieldsGroup.Rows.Delete(FieldsGroupField);
				
			EndIf;
			
			RecordsLeftToHandle = RecordsLeftToHandle - 1;
			
		EndDo;
		
	EndDo;
	
EndProcedure

Procedure AddAdditionalAttributeInObject(CatalogItem, IsExistingObject, Property, AdditionalAttributeValue);
	
	If IsExistingObject Then
		
		RowFilter = New Structure("Property", Property);
		FoundedAdditionalAttributeRows = CatalogItem.AdditionalAttributes.FindRows(RowFilter);
		AdditionalAttributeRow = ?(FoundedAdditionalAttributeRows.Count() < 1, CatalogItem.AdditionalAttributes.Add(), FoundedAdditionalAttributeRows[0]);
		
	Else
		AdditionalAttributeRow = CatalogItem.AdditionalAttributes.Add();
	EndIf;
	
	AdditionalAttributeRow.Property = Property;
	AdditionalAttributeRow.Value = AdditionalAttributeValue;
	
EndProcedure

Procedure ProcessSelectedAdditionalAttributes(CatalogItem, IsExistingObject, TableRow, SelectedAdditionalAttributes) Export
	
	Postfix = "_IncomingData";
	
	For Each AdditionalAttributeDescription In SelectedAdditionalAttributes Do
		
		StringValue 				= TableRow[AdditionalAttributeDescription.Value + Postfix];
		AdditionalAttributeValue 	= TableRow[AdditionalAttributeDescription.Value];
		Property 					= AdditionalAttributeDescription.Key;
		
		If ValueIsFilled(AdditionalAttributeValue) Then
			
			AddAdditionalAttributeInObject(CatalogItem, IsExistingObject, Property, AdditionalAttributeValue);
			
		ElsIf NOT IsBlankString(StringValue) Then
			
			ValueTypeArray = Property.ValueType.Types();
			If ValueTypeArray.Find(Type("CatalogRef.AdditionalValues")) <> Undefined Then
				
				DataImportFromExternalSourcesOverridable.CreateAdditionalProperty(AdditionalAttributeValue, Property, False, StringValue);
				
			ElsIf ValueTypeArray.Find(Type("CatalogRef.AdditionalValuesHierarchy")) <> Undefined Then
				
				DataImportFromExternalSourcesOverridable.CreateAdditionalProperty(AdditionalAttributeValue, Property, True, StringValue);
				
			EndIf;
			
			If ValueIsFilled(AdditionalAttributeValue) Then
				AddAdditionalAttributeInObject(CatalogItem, IsExistingObject, Property, AdditionalAttributeValue);
			EndIf;
			
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure PrepareMapForAdditionalAttributes(DataLoadSettings, Owner) Export
	
	AdditionalAttributeDescription = New Map;
	
	QueryText = 
	"SELECT
	|	AdditionalAttributes.Property AS Property
	|FROM
	|	Catalog.AdditionalAttributesAndInformationSets.AdditionalAttributes AS AdditionalAttributes
	|WHERE
	|	NOT AdditionalAttributes.DeletionMark
	|	AND AdditionalAttributes.Ref = &Owner";
	
	Query = New Query(QueryText);
	Query.SetParameter("Owner", Owner);
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		
		AdditionalAttributeNumber = 0;
		
		Selection = QueryResult.Select();
		While Selection.Next() Do
			
			AdditionalAttributeNumber = AdditionalAttributeNumber + 1;
			AdditionalAttributeDescription.Insert(Selection.Property, "AdditionalAttribute" + Format(AdditionalAttributeNumber, "NG=0"));
			
		EndDo;
		
	EndIf;
	
	DataLoadSettings.Insert("AdditionalAttributeDescription", AdditionalAttributeDescription); // To fill of all the attributes
	DataLoadSettings.Insert("SelectedAdditionalAttributes", New Map); // Only those that are in the Excel
	
EndProcedure

Procedure AddFieldNameInPropertyDescriptonRow(PropertyDescriptonRow, FieldName)
	
	NotUpdatableStandardFieldNames = DataImportFromExternalSourcesOverridable.NotUpdatableStandardFieldNames();
	If StrFind(NotUpdatableStandardFieldNames, FieldName) > 0 Then
		
		Return;
		
	EndIf;
	
	PropertyDescriptonRow = PropertyDescriptonRow + ?(IsBlankString(PropertyDescriptonRow), "", ",") + FieldName;
	
EndProcedure

Procedure FillFieldNameRows(FieldName, DataLoadSettings, PropertyUpdateSettings)
	
	NotUpdatableFieldNames = PropertyUpdateSettings.NotUpdatableFieldNames;
	NotUpdatableFieldNames = NotUpdatableStandardFieldNames(DataLoadSettings);
	
	UpdatableFieldNames = PropertyUpdateSettings.UpdatableFieldNames;
	
	For Each FirstLevelRows In FieldName.Rows Do
		
		If FirstLevelRows.ColumnNumber <> 0 Then
			
			AddFieldNameInPropertyDescriptonRow(UpdatableFieldNames, FirstLevelRows.FieldName);
			
		ElsIf NOT IsBlankString(FirstLevelRows.FieldName)
			AND FirstLevelRows.FieldName <> AdditionalAttributesForAddingFieldsName() Then
			
			AddFieldNameInPropertyDescriptonRow(NotUpdatableFieldNames, FirstLevelRows.FieldName);
			
		ElsIf NOT IsBlankString(FirstLevelRows.FieldsGroupName) Then
			
			For Each SecondLevelRows In FirstLevelRows.Rows Do
				
				If SecondLevelRows.ColumnNumber <> 0 Then
					
					AddFieldNameInPropertyDescriptonRow(UpdatableFieldNames, SecondLevelRows.FieldName);
					
				ElsIf NOT IsBlankString(SecondLevelRows.FieldName) Then
					
					AddFieldNameInPropertyDescriptonRow(NotUpdatableFieldNames, SecondLevelRows.FieldName);
					
				EndIf;
				
			EndDo;
			
		EndIf;
		
	EndDo;
	
	PropertyUpdateSettings.NotUpdatableFieldNames = NotUpdatableFieldNames;
	PropertyUpdateSettings.UpdatableFieldNames = UpdatableFieldNames;
	
EndProcedure

Function NotUpdatableStandardFieldNames(DataLoadSettings)
	
	Return DataImportFromExternalSourcesOverridable.NotUpdatableStandardFieldNames();
	
EndFunction

Function IsCustomFieldsGroup(FieldsGroupName) Export
	
	Return (FieldsGroupName <> FieldsMandatoryForFillingGroupName() AND FieldsGroupName <> FieldsGroupMandatoryForFillingName() AND FieldsGroupName <> FieldsGroupNameService());
	
EndFunction

Function ServiceFieldNameImportToApplicationPossible() Export
	
	Return "_ImportToApplicationPossible";
	
EndFunction

Function FieldsMandatoryForFillingGroupName() Export
	
	Return "_FieldsGroupMandatoryForFilling";
	
EndFunction

Function FieldsGroupMandatoryForFillingName() Export
	
	Return "_FieldsGroupOptionalForFilling";
	
EndFunction

Function AdditionalAttributesForAddingFieldsName() Export
	
	Return "_AdditionalInformationAndAttributes";
	
EndFunction

Function FieldsGroupNameService() Export
	
	Return "_ServiceFieldsGroup";
	
EndFunction

Function PostFixInputDataFieldNames() Export
	
	Return "_IncomingData";
	
EndFunction

Function UseTogetherWithShippedSSLPart() Export
	
	UseTogether = True;
	DataImportFromExternalSourcesOverridable.WhenDeterminingUsageMode(UseTogether);
	
	Return UseTogether;
	
EndFunction

// :::DataImport

// Taken from StringFunctionsClientServer.DecomposeStringToWordsArray
//
// Its own procedure is used because of error parsing string:
// Works and services;;Designing of air-conditioning and ventilation systems;
// where second and fourth parameter will be skipped instead of filling in an empty value.
//
Function DecomposeStringIntoSubstringsArray(Val String, Delimiter) Export
	
	Substrings = New Array;
	
	TextSize = StrLen(String);
	SubstringBeginning = 1;
	For Position = 1 To TextSize Do
		
		CharCode = CharCode(String, Position);
		If StringFunctionsClientServer.IsWordSeparator(CharCode, Delimiter) Then
			
			If Position <> SubstringBeginning Then
				
				Substrings.Add(Mid(String, SubstringBeginning, Position - SubstringBeginning));
				
			ElsIf Position = SubstringBeginning Then
				
				Substrings.Add("");
				
			EndIf;
			
			SubstringBeginning = Position + 1;
			
		EndIf;
		
	EndDo;
	
	If Position <> SubstringBeginning Then
		
		Substrings.Add(Mid(String, SubstringBeginning, Position - SubstringBeginning));
		
	ElsIf Position = SubstringBeginning Then
		
		Substrings.Add("");
		
	EndIf;
	
	Return Substrings;
	
EndFunction

Procedure ImportCSVFileToTabularDocument(TempFileName, SpreadsheetDocument)
	
	File = New File(TempFileName);
	If Not File.Exist() Then 
		Return;
	EndIf;
	
	Template = DataProcessors.DataImportFromExternalSources.GetTemplate("SimpleTemplate");
	AreaValue = Template.GetArea("Value");
	
	TextReader = New TextReader(TempFileName, TextEncoding.ANSI);
	String = TextReader.ReadLine();
	ListSeparator = DriveServer.GetListSeparator(String);
	
	While String <> Undefined Do
		
		FirstColumn = True;
		
		SubstringArray = DecomposeStringIntoSubstringsArray(String, ListSeparator);
		For Each Substring In SubstringArray Do
			
			AreaValue.Parameters.Value = String(Substring);
			
			If FirstColumn Then
				SpreadsheetDocument.Put(AreaValue);
				FirstColumn = False;
			Else
				SpreadsheetDocument.Join(AreaValue);
			EndIf;
			
		EndDo;
		
		String = TextReader.ReadLine();
		
	EndDo;
	
EndProcedure

Procedure ImportData(ServerCallParameters, TemporaryStorageAddress) Export
	
	MaximumOfUsefulColumns	= DataImportFromExternalSourcesOverridable.MaximumOfUsefulColumnsTableDocument();
	TempFileName			= ServerCallParameters.TempFileName;
	Extension 				= ServerCallParameters.Extension;
	SpreadsheetDocument		= ServerCallParameters.SpreadsheetDocument;
	DataLoadSettings		= ServerCallParameters.DataLoadSettings;
	
	If Extension = "csv" Then 
		
		ImportCSVFileToTabularDocument(TempFileName, SpreadsheetDocument);
		FillInDetailsInTabularDocument(SpreadsheetDocument, SpreadsheetDocument.TableWidth, DataLoadSettings);
		
	Else
		
		OriginalSpreadsheetDocument = New SpreadsheetDocument;
		OriginalSpreadsheetDocument.Read(TempFileName);
		
		OptimizeSpreadsheetDocument(OriginalSpreadsheetDocument, SpreadsheetDocument);
		
		FillInDetailsInTabularDocument(SpreadsheetDocument, Min(SpreadsheetDocument.TableWidth, MaximumOfUsefulColumns), DataLoadSettings);
		
	EndIf;
	
	TemporaryStorageAddress = PutToTempStorage(SpreadsheetDocument, TemporaryStorageAddress);
	
EndProcedure

Function ConvertDataToColumnType(Value, ColumnType)
	
	Result = Value;
	
	For Each Type In ColumnType.Types() Do
		
		If Type = Type("Date") Then
			
			If StrLen(Value) < 11 Then
				Value = Mid(Value, 7, 4) + Mid(Value,4,2) + Left(Value, 2);
			Else
				Value = Mid(Value, 7, 4) + Mid(Value,4,2) + Left(Value, 2); 
			EndIf;
				
			TargetType = New TypeDescription("Date");
			Result = TargetType.AdjustValue(Value);
			
		ElsIf Type = Type("Number") Then
			TargetType = New TypeDescription("Number");
			Result = TargetType.AdjustValue(Value);
		EndIf;
	
	EndDo;
	
	Return Result;

EndFunction

Procedure DataFromValuesTableToTabularDocument(DataFromFile, SpreadsheetDocument, FillingObjectFullName) Export 
	
	ColumnsCount = DataFromFile.Columns.Count();
	If ColumnsCount < 1 Then
		
		Return;
		
	EndIf;
	
	SpreadsheetDocument.Clear();
	
	Template = DataProcessors.DataImportFromExternalSources.GetTemplate("SimpleTemplate");
	AreaValue = Template.GetArea("Value");
	
	For RowIndex = 0 To DataFromFile.Count() - 1 Do
		
		VTRow = DataFromFile.Get(RowIndex);
		For ColumnIndex = 0 To ColumnsCount - 1 Do
			
			AreaValue.Parameters.Value = ConvertDataToColumnType(VTRow[ColumnIndex], DataFromFile.Columns.Get(ColumnIndex).ValueType);
			
			If ColumnIndex = 0 Then
				
				SpreadsheetDocument.Put(AreaValue);
				
			Else
				
				SpreadsheetDocument.Join(AreaValue);
				
			EndIf;
			
		EndDo;
		
	EndDo;
	
	FillInDetailsInTabularDocument(SpreadsheetDocument, ColumnsCount, FillingObjectFullName);
	
EndProcedure

Procedure FillInDetailsInTabularDocument(SpreadsheetDocument, ColumnsCount, DataLoadSettings) Export
	Var ImportFieldsTable;
	
	If Number(ColumnsCount) < 1 Then
		
		Return;
		
	EndIf;
	
	CreateImportDescriptionFieldsTable(ImportFieldsTable);
	FillInImportFieldsTable(ImportFieldsTable, DataLoadSettings);
	
	Details = New ValueList;
	Details.Add("Do not import", NStr("en = 'Do not import'"));
	For Each TableRow In ImportFieldsTable Do
	
		Details.Add(TableRow.FieldName, TableRow.FieldPresentation);
		
	EndDo;
	
	Template = DataProcessors.DataImportFromExternalSources.GetTemplate("SimpleTemplate");
	HeaderArea = Template.GetArea("Title");
	
	For ColumnNumber = 1 To ColumnsCount Do
		
		DestinationArea = SpreadsheetDocument.Area(1, ColumnNumber, 1, ColumnNumber);
		SpreadsheetDocument.InsertArea(HeaderArea.Areas.Title, DestinationArea, SpreadsheetDocumentShiftType.WithoutShift, True);
		
		DestinationArea.Text 				= NStr("en = 'Do not import'");
		DestinationArea.DetailsParameter	= "";
		DestinationArea.Details				= Details;
		
		AreaColumn = SpreadsheetDocument.Area(, ColumnNumber, , ColumnNumber);
		AreaColumn.ColumnWidth = 22.75;
		
	EndDo;
	
EndProcedure

// Rules for optimizing a table document:
// - the maximum number of columns is specified in DataImportFromExternalSourcesOverridable.MaximumOfUsefulColumnsTableDocument();
// - for the document, the number of columns is determined by the minimum of the Table Width and the Maximum number of columns;
// - then the columns are deleted according to the rule: if in the first 10 cells of the column is empty, then the
// column is not efficient, ignore (the step from the maximum to the first column); - if the copying (there is no copy
// in the WEB client), import the template (maximum) number of columns; - all rows are imported, because the number of
// rows is not critical;
//
Procedure OptimizeSpreadsheetDocument(OriginalSpreadsheetDocument, SpreadsheetDocument)
	
	MaximumOfUsefulColumns = Min(OriginalSpreadsheetDocument.TableWidth, DataImportFromExternalSourcesOverridable.MaximumOfUsefulColumnsTableDocument());
	While True Do
		
		ThereAreFilledCells = False;
		CellsCounter = 0;
		
		For CellsCounter = 1 To 10 Do
			
			Area = OriginalSpreadsheetDocument.Area(CellsCounter, MaximumOfUsefulColumns); // check the cell in the last column
			If Not IsBlankString(Area.Text) Then
				
				ThereAreFilledCells = True;
				Break;
				
			EndIf;
			
		EndDo;
		
		If ThereAreFilledCells 
			Or MaximumOfUsefulColumns < 7 Then
			
			Break;
		Else
			MaximumOfUsefulColumns = MaximumOfUsefulColumns - 1;
		EndIf;
		
	EndDo;
	
	SpreadsheetDocument.Put(OriginalSpreadsheetDocument.GetArea(1, 1, OriginalSpreadsheetDocument.TableHeight, MaximumOfUsefulColumns));
	
EndProcedure

#EndRegion