#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

Procedure OutputErrorsReport(SpreadsheetDocumentMessages, Errors)
	
	SpreadsheetDocumentMessages.Clear();
	
	Template					= GetTemplate("Errors");
	AreaHeader			= Template.GetArea("Header");
	AreaErrorOrdinary	= Template.GetArea("ErrorOrdinary");
	AreaErrorCritical	= Template.GetArea("ErrorCritical");
	
	SpreadsheetDocumentMessages.Put(AreaHeader);
	For Each Error In Errors Do
		
		TemplateArea = ?(Error.Critical, AreaErrorCritical, AreaErrorOrdinary);
		TemplateArea.Parameters.Fill(Error);
		
		SpreadsheetDocumentMessages.Put(TemplateArea);
		
	EndDo;
	
EndProcedure

Procedure IsEmptyTabularDocument(SpreadsheetDocument, DenyTransitionNext)
	
	DenyTransitionNext = (SpreadsheetDocument.TableHeight < 1);
	
EndProcedure

Procedure CheckFillingTabularDocumentAndFillFormTable(SpreadsheetDocument, DataMatchingTable, GroupsAndFields, Errors)
	
	DataMatchingTable.Clear();
	
	Postfix = DataImportFromExternalSources.PostFixInputDataFieldNames();
	GroupAndFieldCopy = GroupsAndFields.Copy();
	
	StructureToFillRow = New Structure;
	NumberOfBlankRows = 0;
	For RowIndex = 2 To SpreadsheetDocument.TableHeight Do 
		
		WereValuesInString = False;
		
		StructureToFillRow.Clear();
		For Each GroupOrField In GroupAndFieldCopy.Rows Do
			
			If IsBlankString(GroupOrField.FieldsGroupName) Then
				
				If GroupOrField.FieldName = DataImportFromExternalSources.AdditionalAttributesForAddingFieldsName() Then
				
					For Each FieldOfAdditionalAttributeFieldGroup In GroupOrField.Rows Do 
						
						If FieldOfAdditionalAttributeFieldGroup.ColumnNumber = 0 Then
							Continue;
						EndIf;
						
						CellValue = SpreadsheetDocument.GetArea(RowIndex, FieldOfAdditionalAttributeFieldGroup.ColumnNumber).CurrentArea.Text;
						StructureToFillRow.Insert(FieldOfAdditionalAttributeFieldGroup.FieldName + Postfix, CellValue);
						
					EndDo;
					
					Continue;
					
				ElsIf GroupOrField.ColumnNumber = 0 Then
					Continue;
				EndIf;
				
				CellValue = SpreadsheetDocument.GetArea(RowIndex, GroupOrField.ColumnNumber).CurrentArea.Text;
				
				WereValuesInString = (WereValuesInString OR Not IsBlankString(CellValue));
				
				If WereValuesInString Then
					StructureToFillRow.Insert(GroupOrField.FieldName + Postfix, CellValue);
				EndIf;
				
				If GroupOrField.ColorNumberOriginal = 1
					AND WereValuesInString AND Not ValueIsFilled(CellValue) Then
					
					ErrorText = NStr("en = 'The column {%1} contains empty values.These rows will be skipped'");
					ErrorText = StringFunctionsClientServer.SubstituteParametersInString(ErrorText, GroupOrField.FieldPresentation);
							OccurrencePlace = NStr("en = 'Row #%1.'");
					OccurrencePlace = StringFunctionsClientServer.SubstituteParametersInString(OccurrencePlace, RowIndex);
					
					DataImportFromExternalSources.AddError(Errors, ErrorText, False, OccurrencePlace);
					
				EndIf;
				
			Else
				
				For Each FieldOfFieldGroup In GroupOrField.Rows Do 
					
					If FieldOfFieldGroup.ColumnNumber = 0 Then
						Continue;
					EndIf;
					
					CellValue = SpreadsheetDocument.GetArea(RowIndex, FieldOfFieldGroup.ColumnNumber).CurrentArea.Text;
					
					WereValuesInString = (WereValuesInString OR NOT IsBlankString(CellValue));
					
					If WereValuesInString Then
						StructureToFillRow.Insert(FieldOfFieldGroup.FieldName, CellValue);
					EndIf;
					
					If FieldOfFieldGroup.ColorNumberOriginal = 1 
						AND WereValuesInString AND Not ValueIsFilled(CellValue) Then
							
							ErrorText = NStr("en = 'The column {%1} contains empty values. These rows will be skipped'");
							ErrorText = StringFunctionsClientServer.SubstituteParametersInString(ErrorText, FieldOfFieldGroup.FieldPresentation);
							OccurrencePlace = NStr("en = 'Row #%1.'");
							OccurrencePlace = StringFunctionsClientServer.SubstituteParametersInString(OccurrencePlace, RowIndex);
							
							DataImportFromExternalSources.AddError(Errors, ErrorText, False, OccurrencePlace);
							
					EndIf;
				EndDo;
			EndIf;
		EndDo;
		
		
		If WereValuesInString Then
			NewDataRow = DataMatchingTable.Add();
			FillPropertyValues(NewDataRow, StructureToFillRow);
		Else
			NumberOfBlankRows = NumberOfBlankRows + 1;
		EndIf;
		
		If NumberOfBlankRows > SpreadsheetDocument.GetDataAreaVerticalSize() Then
			Break;
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure HasUnfilledMandatoryColumns(FieldTree, Errors)
	
	For Each FieldOrGroupField In FieldTree.Rows Do
		
		If Not IsBlankString(FieldOrGroupField.FieldsGroupName) Then
			
			UnselectedColumnNames = "";
			UnselectedColumnsInGroup = 0;
			
			For Each FieldOfFieldGroup In FieldOrGroupField.Rows Do 
				
				If FieldOfFieldGroup.ColorNumberOriginal = 1 
					AND FieldOfFieldGroup.ColumnNumber = 0 Then
					
					ErrorText = NStr("en = 'Required column {%1} is not selected'");
					ErrorText = StringFunctionsClientServer.SubstituteParametersInString(ErrorText, FieldOfFieldGroup.FieldPresentation);
					OccurrencePlace = NStr("en = 'Configure titles'");
					
					DataImportFromExternalSources.AddError(Errors, ErrorText, True, OccurrencePlace);
					
				ElsIf FieldOrGroupField.ColorNumberOriginal = 1 Then // If the group is required to fill and no one field is not selected
					
					UnselectedColumnsInGroup = UnselectedColumnsInGroup + 1;
					UnselectedColumnNames = UnselectedColumnNames + ?(IsBlankString(UnselectedColumnNames), "", ", ") + FieldOfFieldGroup.FieldPresentation;
					
				EndIf;
				
			EndDo;
			
			If FieldOrGroupField.Rows.Count() = UnselectedColumnsInGroup Then
				
				ErrorText = NStr("en = 'For the field group {%1} that is contained in the set of columns {% 2} in the importing data you must select at least one column.'");
				ErrorText = StringFunctionsClientServer.SubstituteParametersInString(ErrorText, FieldOrGroupField.ИмяГруппыПолей, UnselectedColumnNames);
				OccurrencePlace = NStr("en = 'Configure titles'");
				
				DataImportFromExternalSources.AddError(Errors, ErrorText, True, OccurrencePlace);
				
			EndIf;
			
		ElsIf FieldOrGroupField.ColorNumberOriginal = 1 
			AND FieldOrGroupField.ColumnNumber = 0 Then
			
			ErrorText = NStr("en = 'Required column {%1} is not selected'");
			ErrorText = StringFunctionsClientServer.SubstituteParametersInString(ErrorText, FieldOrGroupField.FieldPresentation);
			OccurrencePlace = NStr("en = 'Configure titles'");
			
			DataImportFromExternalSources.AddError(Errors, ErrorText, True, OccurrencePlace);
			
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure PreliminarilyDataProcessor(SpreadsheetDocument, DataMatchingTable, DataLoadSettings, SpreadsheetDocumentMessages, SkipPage, DenyTransitionNext) Export
	Var Errors;
	
	DataImportFromExternalSources.CreateErrorsDescriptionTable(Errors);
	
	IsEmptyTabularDocument(SpreadsheetDocument, DenyTransitionNext);
	If DenyTransitionNext Then
		
		ErrorText = NStr("en = 'Data being imported is not filled in.'");
		DataImportFromExternalSources.AddError(Errors, ErrorText);
		Return;
	EndIf;
	
	FieldTree = GetFromTempStorage(DataLoadSettings.FieldsTreeStorageAddress);
	HasUnfilledMandatoryColumns(FieldTree, Errors);
		
	If Errors.Find(True, "Critical") = Undefined Then
		CheckFillingTabularDocumentAndFillFormTable(SpreadsheetDocument, DataMatchingTable, FieldTree, Errors);
	EndIf;
	
	DataImportFromExternalSources.GeneratePropertyUpdateSettings(FieldTree, DataLoadSettings);
	
	SkipPage = (Errors.Count() < 1);
	If Not SkipPage Then
		
		DenyTransitionNext = (Errors.Find(True, "Critical") <> Undefined);
		OutputErrorsReport(SpreadsheetDocumentMessages, Errors);
		
	EndIf;
	
EndProcedure

Procedure AddMatchTableColumns(ThisObject, DataMatchingTable, DataLoadSettings) Export
	Var GroupsAndFields;
	
	If DataMatchingTable.Unload().Columns.Count() > 0 Then
		
		Return;
		
	EndIf;
	
	If Not DataLoadSettings.IsTabularSectionImport Then
		
		ManagerObject = Undefined;
		DataImportFromExternalSources.GetManagerByFillingObjectName(DataLoadSettings.FillingObjectFullName, ManagerObject);
		AttributesToLock = ManagerObject.GetObjectAttributesBeingLocked();
		
	EndIf;
	
	DataImportFromExternalSources.CreateAndFillGroupAndFieldsByObjectNameTree(DataLoadSettings, GroupsAndFields, DataLoadSettings.IsTabularSectionImport);
	
	AttributeArray= New Array;
	AttributePath	= "DataMatchingTable";
	MandatoryFieldsGroup = Undefined;
	OptionalFieldsGroup = Undefined;
	ServiceFieldsGroup = Undefined;
	For Each FieldsGroup In GroupsAndFields.Rows Do
		
		IsCustomFieldsGroup = DataImportFromExternalSources.IsCustomFieldsGroup(FieldsGroup.FieldsGroupName);
		If IsCustomFieldsGroup Then
			
			AddAttributesFromCustomFieldsGroup(ThisObject, FieldsGroup, AttributePath, AttributesToLock);
			
		ElsIf FieldsGroup.FieldsGroupName = DataImportFromExternalSources.FieldsMandatoryForFillingGroupName() Then
			
			MandatoryFieldsGroup = FieldsGroup;
			
		ElsIf FieldsGroup.FieldsGroupName = DataImportFromExternalSources.FieldsGroupMandatoryForFillingName() Then
			
			OptionalFieldsGroup = FieldsGroup;
			
		ElsIf FieldsGroup.FieldsGroupName = DataImportFromExternalSources.FieldsGroupNameService() Then
			
			ServiceFieldsGroup = FieldsGroup;
			
		EndIf;
		
	EndDo;
	
	AddMandatoryAttributes(ThisObject, MandatoryFieldsGroup, AttributePath, AttributesToLock);
	AddOptionalAttributes(ThisObject, OptionalFieldsGroup, AttributePath, AttributesToLock);
	AddServiceAttributes(ThisObject, ServiceFieldsGroup, AttributePath);
	
	DataImportFromExternalSourcesOverridable.AfterAddingItemsToMatchesTables(ThisObject, DataLoadSettings);
	DataImportFromExternalSourcesOverridable.AddConditionalMatchTablesDesign(ThisObject, AttributePath, DataLoadSettings);
	
EndProcedure

// :::Building a field tree

Procedure CreateFieldsTreeTemplateAvailableForUser(FieldsTree)
	
	TypeDescriptionString100	= New TypeDescription("String", , , , New StringQualifiers(100));
	TypeDescriptionString256	= New TypeDescription("String", , , , New StringQualifiers(256));
	TypeDescriptionNumber1_0	= New TypeDescription("Number", , , , New NumberQualifiers(1, 0, AllowedSign.Nonnegative));
	TypeDescriptionNumber2_0	= New TypeDescription("Number", , , , New NumberQualifiers(2, 0, AllowedSign.Nonnegative));
	TypeDescriptionTD			= New TypeDescription("TypeDescription");
	
	FieldsTree = New ValueTree;
	
	FieldsTree.Columns.Add("FieldsGroupName",		TypeDescriptionString100,,);
	FieldsTree.Columns.Add("DerivedValueType",		TypeDescriptionTD,,);
	FieldsTree.Columns.Add("FieldName",				TypeDescriptionString100,,);
	FieldsTree.Columns.Add("FieldPresentation",		TypeDescriptionString256,,);
	FieldsTree.Columns.Add("ColumnNumber",			TypeDescriptionNumber2_0,,);
	FieldsTree.Columns.Add("ColorNumber",			TypeDescriptionNumber1_0,,);
	FieldsTree.Columns.Add("ColorNumberOriginal",	TypeDescriptionNumber1_0,,);
	
EndProcedure

Procedure AddFields(FieldsParent, FieldsGroup, ColorNumber, IsCustomFieldsGroup = False)
	
	For Each Field In FieldsGroup.Rows Do
		
		If Field.Visible Then
			
			NewRow 						= FieldsParent.Rows.Add();
			NewRow.FieldsGroupName		= Field.FieldsGroupName;
			NewRow.DerivedValueType		= Field.DerivedValueType;
			NewRow.FieldName			= Field.FieldName;
			NewRow.FieldPresentation	= Field.FieldPresentation;
			NewRow.ColumnNumber			= Field.ColumnNumber;
			
			If NewRow.ColumnNumber <> 0 Then
				
				NewRow.ColorNumber = 3;
				If IsCustomFieldsGroup Then
					FieldsParent.ColorNumber	= 3;
				EndIf;
				
			ElsIf Field.AdditionalAttributeFeature = True 
				AND ColorNumber <> 1 Then // Required fields do not recolor
				
				NewRow.ColorNumber		= 4;
				
			Else
				NewRow.ColorNumber		= ?(Field.RequiredFilling, 1, ColorNumber);
			EndIf;
			
			NewRow.ColorNumberOriginal	= NewRow.ColorNumber;
			
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure CreateFieldsTreeAvailableForUser(FieldsTree, DataLoadSettings) Export
	Var GroupsAndField;
	
	CreateFieldsTreeTemplateAvailableForUser(FieldsTree);
	DataImportFromExternalSources.CreateAndFillGroupAndFieldsByObjectNameTree(DataLoadSettings, GroupsAndField);
	
	NewRow = FieldsTree.Rows.Add();
	NewRow.FieldPresentation = "Do not import";
	
	For Each FieldsGroup In GroupsAndField.Rows Do
		
		If FieldsGroup.FieldsGroupName = DataImportFromExternalSources.FieldsGroupNameService() Then
			Return;
		EndIf;
		
		ColorNumber = 0;
		IsCustomFieldsGroup = DataImportFromExternalSources.IsCustomFieldsGroup(FieldsGroup.FieldsGroupName);
		
		If IsCustomFieldsGroup Then
			
			ColorNumber = 2;
			
			NewRow = FieldsTree.Rows.Add();
			NewRow.FieldPresentation	= FieldsGroup.FieldsGroupName;
			NewRow.FieldsGroupName		= FieldsGroup.FieldsGroupName;
			NewRow.ColorNumber 			= ?(FieldsGroup.GroupRequiredFilling, 1, 0);
			AddFields(NewRow, FieldsGroup, ColorNumber, IsCustomFieldsGroup);
			Continue;
			
		ElsIf FieldsGroup.FieldsGroupName = DataImportFromExternalSources.FieldsMandatoryForFillingGroupName() Then
			ColorNumber = 1;
		EndIf;
		
		AddFields(FieldsTree, FieldsGroup, ColorNumber);
		
	EndDo;
	
EndProcedure

// :::Work with attributes and items of assistant forms

Procedure AddAttributesFromCustomFieldsGroup(ThisObject, FieldsGroup, AttributePath, AttributesToLock = Undefined)
	
	Items = ThisObject.Items;
	
	FirstLevelGroup = Items.Add("Group" + FieldsGroup.FieldsGroupName, Type("FormGroup"), Items.DataMatchingTable);
	FirstLevelGroup.Group = ColumnsGroup.Vertical;
	FirstLevelGroup.ShowTitle = False;
	
	NewAttributeGroup = New FormAttribute(FieldsGroup.FieldsGroupName, FieldsGroup.DerivedValueType, AttributePath, FieldsGroup.FieldsGroupName);
	
	AttributeArray = New Array;
	AttributeArray.Add(NewAttributeGroup);
	ThisObject.ChangeAttributes(AttributeArray);
	
	SecondLevelGroup = Items.Add("GroupIncoming" + FieldsGroup.FieldsGroupName, Type("FormGroup"), FirstLevelGroup);
	SecondLevelGroup.Group = ColumnsGroup.InCell;
	SecondLevelGroup.ShowTitle = False;
	
	For Each GroupRow In FieldsGroup.Rows Do
		
		AttributeArray.Clear();
		
		NewAttribute = New FormAttribute(GroupRow.FieldName, GroupRow.IncomingDataType, AttributePath, FieldsGroup.FieldPresentation);
		AttributeArray.Add(NewAttribute);
		
		ThisObject.ChangeAttributes(AttributeArray);
		
		NewItem 				= Items.Add(GroupRow.FieldName, Type("FormField"), SecondLevelGroup);
		NewItem.Type			= FormFieldType.InputField;
		NewItem.DataPath	= "DataMatchingTable." + GroupRow.FieldName;
		NewItem.Title		= GroupRow.FieldPresentation;
		NewItem.ReadOnly = True;
		NewItem.Width 		= 4;
		NewItem.HorizontalStretch = False;
		
	EndDo;
	
	NewItem 				= Items.Add(FieldsGroup.FieldsGroupName, Type("FormField"), FirstLevelGroup);
	NewItem.Type			= FormFieldType.InputField;
	NewItem.DataPath	= "DataMatchingTable." + FieldsGroup.FieldsGroupName;
	NewItem.Title		= FieldsGroup.FieldPresentation;
	NewItem.EditMode = ColumnEditMode.Enter;
	NewItem.MarkIncomplete = FieldsGroup.GroupRequiredFilling;
	NewItem.AutoMarkIncomplete = FieldsGroup.GroupRequiredFilling;
	NewItem.CreateButton = False;
		
EndProcedure

Procedure AddMandatoryAttributes(ThisObject, FieldsGroup, AttributePath, AttributesToLock = Undefined)
	
	Items = ThisObject.Items;
	
	FirstLevelGroup = Items.Add(DataImportFromExternalSources.FieldsMandatoryForFillingGroupName(), Type("FormGroup"), Items.DataMatchingTable);
	FirstLevelGroup.Group = ColumnsGroup.Horizontal;
	FirstLevelGroup.ShowTitle = False;
	
	PostFix = DataImportFromExternalSources.PostFixInputDataFieldNames();
	
	AttributeArray = New Array;
	For Each GroupRow In FieldsGroup.Rows Do
		
		SecondLevelGroup = Items.Add("Group" + GroupRow.FieldName, Type("FormGroup"), FirstLevelGroup);
		SecondLevelGroup.Group = ColumnsGroup.Vertical;
		SecondLevelGroup.ShowTitle = False;
		
		AttributeArray.Clear();
		
		NewAttribute = New FormAttribute(GroupRow.FieldName, GroupRow.DerivedValueType, AttributePath, FieldsGroup.FieldPresentation);
		AttributeArray.Add(NewAttribute);
		
		NewAttribute = New FormAttribute(GroupRow.FieldName + PostFix, GroupRow.IncomingDataType, AttributePath, FieldsGroup.FieldPresentation);
		AttributeArray.Add(NewAttribute);
		
		ThisObject.ChangeAttributes(AttributeArray);
		
		NewItem 				= Items.Add(GroupRow.FieldName, Type("FormField"), SecondLevelGroup);
		NewItem.Type			= FormFieldType.InputField;
		NewItem.DataPath	= "DataMatchingTable." + GroupRow.FieldName;
		NewItem.Title		= GroupRow.FieldPresentation;
		NewItem.ReadOnly = False;
		NewItem.MarkIncomplete = True;
		NewItem.AutoMarkIncomplete = True;
		NewItem.CreateButton = False;
		
		If AttributesToLock <> Undefined
			AND AttributesToLock.Find(GroupRow.FieldName) = Undefined Then
			
			NewItem.HeaderPicture = PictureLib.ExclamationMarkGray;
			
		EndIf;
		
		NewItem 				= Items.Add(GroupRow.FieldName + PostFix, Type("FormField"), SecondLevelGroup);
		NewItem.Type			= FormFieldType.InputField;
		NewItem.DataPath	= "DataMatchingTable." + GroupRow.FieldName + PostFix;
		NewItem.Title		= " ";//GroupRow.FieldsPresentation + PostFix;
		NewItem.ReadOnly = True;
		NewItem.MarkIncomplete = False;
		
	EndDo;
	
EndProcedure

Procedure AddOptionalAttributes(ThisObject, FieldsGroup, AttributePath, AttributesToLock = Undefined)
	
	Items = ThisObject.Items;
	
	FirstLevelGroup = Items.Add(DataImportFromExternalSources.FieldsGroupMandatoryForFillingName(), Type("FormGroup"), Items.DataMatchingTable);
	FirstLevelGroup.Group = ColumnsGroup.Horizontal;
	FirstLevelGroup.ShowTitle = False;
	
	PostFix = DataImportFromExternalSources.PostFixInputDataFieldNames();
	
	AttributeArray = New Array;
	For Each GroupRow In FieldsGroup.Rows Do
		
		SecondLevelGroup = Items.Add("Group" + GroupRow.FieldName, Type("FormGroup"), FirstLevelGroup);
		SecondLevelGroup.Group = ColumnsGroup.Vertical;
		SecondLevelGroup.ShowTitle = False;
		
		AttributeArray.Clear();
		
		NewAttribute = New FormAttribute(GroupRow.FieldName, GroupRow.DerivedValueType, AttributePath, FieldsGroup.FieldPresentation);
		AttributeArray.Add(NewAttribute);
		
		NewAttribute = New FormAttribute(GroupRow.FieldName + PostFix, GroupRow.IncomingDataType, AttributePath, FieldsGroup.FieldPresentation);
		AttributeArray.Add(NewAttribute);
		
		ThisObject.ChangeAttributes(AttributeArray);
		
		NewItem 				= Items.Add(GroupRow.FieldName, Type("FormField"), SecondLevelGroup);
		NewItem.Type			= FormFieldType.InputField;
		NewItem.DataPath	= "DataMatchingTable." + GroupRow.FieldName;
		NewItem.Title		= GroupRow.FieldPresentation;
		NewItem.ReadOnly = False;
		NewItem.CreateButton = False;
		
		If AttributesToLock <> Undefined
			AND AttributesToLock.Find(GroupRow.FieldName) <> Undefined Then
			
			NewItem.HeaderPicture = PictureLib.UnavailableFieldsInformtion;
			
		EndIf;
		
		NewItem 				= Items.Add(GroupRow.FieldName + PostFix, Type("FormField"), SecondLevelGroup);
		NewItem.Type			= FormFieldType.InputField;
		NewItem.DataPath	= "DataMatchingTable." + GroupRow.FieldName + PostFix;
		NewItem.Title		= " "; // GroupRow.FieldsPresentation + PostFix;
		NewItem.ReadOnly = True;
		
	EndDo;
	
EndProcedure

Procedure AddAdditionalAttributes(ThisObject, SelectedAdditionalAttributes) Export
	
	Items 						= ThisObject.Items;
	Postfix 					= DataImportFromExternalSources.PostFixInputDataFieldNames();
	AttributePath 				= "DataMatchingTable";
	TypeDescriptionString150	= New TypeDescription("String", , , , New StringQualifiers(150));
	
	FirstLevelGroup = Items.Find(DataImportFromExternalSources.FieldsGroupMandatoryForFillingName()); //Additional attributes are not mandatory
	
	AttributesArray = New Array;
	For Each MatchRow In SelectedAdditionalAttributes Do
		
		If Items.Find(MatchRow.Value) <> Undefined Then
			
			Continue; // It was added earlier
			
		EndIf;
		
		SecondLevelGroup = Items.Add("Group" + MatchRow.Value, Type("FormGroup"), FirstLevelGroup);
		SecondLevelGroup.Group 		= ColumnsGroup.Vertical;
		SecondLevelGroup.ShowTitle	= False;
		SecondLevelGroup.Width 		= 8;
		
		AttributesArray.Clear();
		
		NewAttribute = New FormAttribute(MatchRow.Value, MatchRow.Key.ValueType, AttributePath, String(MatchRow.Key.Description));
		AttributesArray.Add(NewAttribute);
		
		NewAttribute = New FormAttribute(MatchRow.Value + Postfix, TypeDescriptionString150, AttributePath, String(MatchRow.Key.Description));
		AttributesArray.Add(NewAttribute);
		
		ThisObject.ChangeAttributes(AttributesArray);
		
		NewItem 				= Items.Add(MatchRow.Value, Type("FormField"), SecondLevelGroup);
		NewItem.Type			= FormFieldType.InputField;
		NewItem.DataPath		= "DataMatchingTable." + MatchRow.Value;
		NewItem.Title			= String(MatchRow.Key.Description);
		NewItem.ReadOnly 		= False;
		NewItem.CreateButton	= False;
		NewItem.Width			= 8;
		
		NewItem 			= Items.Add(MatchRow.Value + Postfix, Type("FormField"), SecondLevelGroup);
		NewItem.Type		= FormFieldType.InputField;
		NewItem.DataPath	= "DataMatchingTable." + MatchRow.Value + Postfix;
		NewItem.Title		= " ";
		NewItem.ReadOnly	= True;
		NewItem.Width		= 8;
		
	EndDo;
	
EndProcedure

Procedure AddServiceAttributes(ThisObject, FieldsGroup, AttributePath)
	
	AttributeArray = New Array;
	For Each GroupRow In FieldsGroup.Rows Do
		
		NewAttribute = New FormAttribute(GroupRow.FieldName, GroupRow.DerivedValueType, AttributePath, GroupRow.FieldName);
		AttributeArray.Add(NewAttribute);
		
	EndDo;
	
	ThisObject.ChangeAttributes(AttributeArray);
	
EndProcedure

#EndIf