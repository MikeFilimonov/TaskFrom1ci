
#Region ServiceProceduresAndFunctions

&AtClient
Procedure FieldsGroupProcessing(Field, Cancel)
	
	If Not IsBlankString(Field.FieldsGroupName) Then
		
		Cancel = True;
		ShowMessageBox(, NStr("en = 'You can not select group.'"));
		
	EndIf;
	
EndProcedure

&AtClient
Procedure AdditionalAttributesFieldProcessing(Field, Cancel)
	
	If Field.FieldName = ValueCache.AdditionalAttributesFieldName Then
		
		Cancel = True;
		
		MaximumOfAdditionalAttributes = DataImportFromExternalSourcesOverridable.MaximumOfAdditionalAttributesTableDocument();
		If Parameters.DataLoadSettings.SelectedAdditionalAttributes.Count() >= MaximumOfAdditionalAttributes Then
			
			MessageText = NStr("en = 'A lot of additional attributes slows down the import process.
			                   |It is recommended to divide the load into several iterations.'");
			
			TitleText = StrTemplate(NStr("en = '%1 attributes selected'"), MaximumOfAdditionalAttributes);
			ShowMessageBox( , MessageText, 0, TitleText);
			Return;
			
		EndIf;
		
		Items.Pages.CurrentPage = Items.PageAdditionalAttributes;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure ExecuteRequiredActionsAtServer(SelectedFieldName)

	FieldsTree = FormDataToValue(ImportFieldsTree, Type("ValueTree"));
	
	FilterParameters = New Structure("ColumnNumber", ValueCache.ColumnNumber);
	
	FoundRowsFieldsTree = FieldsTree.Rows.FindRows(FilterParameters, True);
	If FoundRowsFieldsTree.Count() > 1 Then
		
		For Each FieldsTreeRow In FoundRowsFieldsTree Do
			
			If FieldsTreeRow.FieldName <> SelectedFieldName Then
				
				FieldsTreeRow.ColumnNumber = 0;
				FieldsTreeRow.ColorNumber  = FieldsTreeRow.ColorNumberOriginal;
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
	PutToTempStorage(FieldsTree, Parameters.DataLoadSettings.FieldsTreeStorageAddress);

EndProcedure

&AtServer
Procedure FillImportFieldsTree(FieldsTree)
	
	ValueToFormAttribute(FieldsTree, "ImportFieldsTree");
	
EndProcedure

&AtServer
Procedure FillAdditionalAttributeTree()
	
	If Not Parameters.DataLoadSettings.Property("AdditionalAttributeDescription") Then
		
		Return;
		
	EndIf;
	
	AdditionalAttributeTree = FormAttributeToValue("AdditionalAttributes");
	
	OwnerRows = AdditionalAttributeTree.Rows;
	For Each Description In Parameters.DataLoadSettings.AdditionalAttributeDescription Do
		
		AdditionalAttribute = Description.Key;
		
		AdditionalAttributeOwner = OwnerRows.Find(AdditionalAttribute.PropertySet, "AdditionalAttributeOwner", False);
		If AdditionalAttributeOwner = Undefined Then
			
			AdditionalAttributeOwner = OwnerRows.Add();
			AdditionalAttributeOwner.AdditionalAttributeOwner	= AdditionalAttribute.PropertySet;
			AdditionalAttributeOwner.Presentation				= AdditionalAttribute.PropertySet.Description;
			AdditionalAttributeOwner.ItemAvailable				= True; // Always True for groups
			
		EndIf;
		
		NewRow = AdditionalAttributeOwner.Rows.Add();
		NewRow.AdditionalAttribute	= Description.Key;
		NewRow.Presentation			= String(Description.Key.Description);
		NewRow.ItemAvailable		= True;
		
	EndDo;
	
	NewRow = OwnerRows.Add();
	NewRow.AdditionalAttribute	= ChartsOfCharacteristicTypes.AdditionalAttributesAndInformation.EmptyRef();
	NewRow.Presentation			= ValueCache.ReturnFieldList;
	NewRow.ItemAvailable		= True;
	
	ValueToFormAttribute(AdditionalAttributeTree, "AdditionalAttributes");
	
EndProcedure

&AtClient
Function IsMaximumSelectedAdditionalAttributes(AdditionalAttributeItemCollection)
	
	MaximumAdditionalAttributes = DataImportFromExternalSourcesOverridable.MaximumOfAdditionalAttributesTableDocument();
	
	Return AdditionalAttributeItemCollection.Count() >= MaximumAdditionalAttributes;
	
EndFunction

&AtClient
Function AddAdditionalAttributeFieldInFieldTree(AdditionalAttributeItemCollection, AdditionalAttributeRow)
	
	AdditionalAttributeField = AdditionalAttributeItemCollection.Add();
	
	AdditionalAttributeField.FieldsGroupName		= "";
	AdditionalAttributeField.FieldName				= Parameters.DataLoadSettings.AdditionalAttributeDescription.Get(AdditionalAttributeRow.AdditionalAttribute);
	AdditionalAttributeField.DerivedValueType		= Undefined;
	AdditionalAttributeField.FieldPresentation		= AdditionalAttributeRow.Presentation;
	AdditionalAttributeField.ColorNumber			= 3;
	AdditionalAttributeField.ColorNumberOriginal	= 4;
	
	Return AdditionalAttributeField;
	
EndFunction

&AtClient
Function FindAdditionalAttributeFieldInFieldTree(AdditionalAttributeItemCollection, AdditionalAttributeRow)
	
	For Each AdditionalAttributeField In AdditionalAttributeItemCollection Do
		
		If AdditionalAttributeField.FieldName = 
			Parameters.DataLoadSettings.AdditionalAttributeDescription.Get(AdditionalAttributeRow.AdditionalAttribute) Then
			Break;
		EndIf;
		
	EndDo;
	
	Return AdditionalAttributeField;
	
EndFunction

&AtClient
Procedure ProcessAdditionalAttributeChoice(AdditionalAttributeRow)
	
	If AdditionalAttributeRow.GetItems().Count() > 0 Then
		ShowMessageBox(, NStr("en = 'You can not select group.'"));
		Return;
	EndIf;
	
	AdditionalAttributeGroup = Undefined;
	
	FirstLevelItems = ImportFieldsTree.GetItems();
	For Each TreeRow In FirstLevelItems Do
		
		If TreeRow.FieldName = ValueCache.AdditionalAttributesGroupName Then
			AdditionalAttributeGroup = TreeRow;
			Break;
		EndIf;
		
	EndDo;
	
	AdditionalAttributeItemCollection = AdditionalAttributeGroup.GetItems();
	If Parameters.DataLoadSettings.SelectedAdditionalAttributes.Get(AdditionalAttributeRow.AdditionalAttribute) = Undefined Then
		
		AdditionalAttributeField = AddAdditionalAttributeFieldInFieldTree(AdditionalAttributeItemCollection, AdditionalAttributeRow);
		
		If IsMaximumSelectedAdditionalAttributes(AdditionalAttributeItemCollection) Then
			AdditionalAttributeGroup.ColorNumber = 3;
		EndIf;
		
	Else
		AdditionalAttributeField = FindAdditionalAttributeFieldInFieldTree(AdditionalAttributeItemCollection, AdditionalAttributeRow);
	EndIf;
	
	RememberSelectionAndCloseForm(AdditionalAttributeField, AdditionalAttributeRow.AdditionalAttribute);
	
EndProcedure

&AtClient
Procedure RememberSelectionAndCloseForm(Field, AdditionalAttribute = Undefined)
	
	Result = New Structure;
	Result.Insert("Presentation", 			Field.FieldPresentation);
	Result.Insert("Value", 					Field.FieldName);
	Result.Insert("AdditionalAttribute",	AdditionalAttribute);
	
	If Field.ColumnNumber <> 0 Then
		
		Result.Insert("CancelSelectionInColumn", Field.ColumnNumber);
		
	EndIf;
	
	
	ChoseSameField = (Field.ColumnNumber = ValueCache.ColumnNumber);
	If Not IsBlankString(Field.FieldName) Then
		
		Field.ColumnNumber	= ?(ChoseSameField, 0, ValueCache.ColumnNumber);
		Field.ColorNumber	= ?(ChoseSameField, Field.ColorNumberOriginal, 3);
		
	EndIf;
	
	ExecuteRequiredActionsAtServer(Field.FieldName);
	
	Close(Result);
	
	
EndProcedure

#EndRegion

#Region FormEvents

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	Var ColumnTitle;
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	If Parameters.Property("ColumnTitle", ColumnTitle) Then
		Title = NStr("en = 'Field choice'") + ?(IsBlankString(ColumnTitle), "", ": " + TrimAll(ColumnTitle));
	Else
		Raise NStr("en = 'You can not open the data processor without context.'");
	EndIf;
	
	ValueCache = New Structure;
	ValueCache.Insert("AdditionalAttributesFieldName",	DataImportFromExternalSources.AdditionalAttributesForAddingFieldsName());
	ValueCache.Insert("ColumnNumber", 					Parameters.ColumnNumber);
	ValueCache.Insert("ReturnFieldList",	 			NStr("en = 'Back to the list of attributes'"));
	ValueCache.Insert("AdditionalAttributesGroupName",	DataImportFromExternalSources.AdditionalAttributesForAddingFieldsName());
	
	FieldsTree = GetFromTempStorage(Parameters.DataLoadSettings.FieldsTreeStorageAddress);
	FillImportFieldsTree(FieldsTree);
	FillAdditionalAttributeTree();
	
	
EndProcedure

#EndRegion

#Region FormAttributesEvents

&AtClient
Procedure ImportFiledsTableChoice(Item, SelectedRow, Field, StandardProcessing)
	
	Cancel = False;
	StandardProcessing = False;
	
	Field = ImportFieldsTree.FindByID(SelectedRow);
	
	FieldsGroupProcessing(Field, Cancel);
	AdditionalAttributesFieldProcessing(Field, Cancel);
	
	If Not Cancel Then
		
		RememberSelectionAndCloseForm(Field);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure AdditionalAttributesSelection(Item, SelectedRow, Field, StandardProcessing)
	
	AdditionalAttributeRow = AdditionalAttributes.FindByID(SelectedRow);
	If AdditionalAttributeRow.Presentation = ValueCache.ReturnFieldList Then
		Items.Pages.CurrentPage = Items.PageFields;
	Else
		ProcessAdditionalAttributeChoice(AdditionalAttributeRow);
	EndIf;
	
	
EndProcedure

#EndRegion