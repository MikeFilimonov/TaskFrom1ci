﻿
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;

	If Parameters.Property("ShowAdditionalAttributes") Then
		
		StandardSubsystemsServer.SetFormPurposeKey(ThisObject, "SetsAdditionalDetails");
		Items.ThisIsSetOfAdditionalInformation.Visible	= False;
		
	ElsIf Parameters.Property("ShowAdditionalInformation") Then
		
		StandardSubsystemsServer.SetFormPurposeKey(ThisObject, "AdditionalInformationSets");
		Items.ThisIsSetOfAdditionalInformation.Visible	= False;
		ThisIsSetOfAdditionalInformation				= True;
		
	EndIf;
	
	Parameters.Property("CurrentSet", CurrentSet);
	
	ColorForms = Items.Properties.BackColor;
	
	ApplyAppearanceSetsAndProperties();
	
	ConfigureUsingCommands();
	
	ConfigureRepresentationSets();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	Items.PropertiesSets.CurrentRow = CurrentSet;
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "Writing_AdditionalAttributesAndInformation"
	 OR EventName = "Record_ValuesOfObjectProperties"
	 OR EventName = "Record_ValuesOfObjectPropertiesHierarchy" Then
		
		// When writing the attribute it is necessary to pass the attribute to the appropriate group.
		// When writing the value it is necessary to update the list of first 3 values.
		OnChangeOfCurrentSetAtServer();
		
	ElsIf EventName = "Transition_SetsOfAdditionalDetailsAndInformation" Then
		// When opening the form for editing the attribute content
		// of the specified metadata object it is necessary to go to the set or set group of this metadata object.
		If TypeOf(Parameter) = Type("Structure") Then
			SelectSpecifiedRows(Parameter);
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure ThisIsSetOfAdditionalInformationOnChange(Item)
	
	ConfigureRepresentationSets();
	
EndProcedure

#EndRegion

#Region FormTableItemsEventsHandlersPropertiesSets

&AtClient
Procedure PropertySetsOnActivateRow(Item)
	
	AttachIdleHandler("OnChangeOfCurrentSet", 0.1, True);
	
EndProcedure

&AtClient
Procedure PropertiesSetsRowBeforeChange(Item, Cancel)
	
	Cancel = True;
	
EndProcedure

#EndRegion

#Region FormTableItemsEventsHandlersProperties

&AtClient
Procedure PropertiesOnActivateRow(Item)
	
	PropertiesSetEnabledCommands(ThisObject);
	
EndProcedure

&AtClient
Procedure PropertiesBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	If Copy Then
		Copy();
	Else
		Create();
	EndIf;
	
	Cancel = True;
	
EndProcedure

&AtClient
Procedure PropertiesBeforeRowChange(Item, Cancel)
	
	Change();
	
	Cancel = True;
	
EndProcedure

&AtClient
Procedure PropertiesBeforeDelete(Item, Cancel)
	
	ChangeDeletionMark();
	
	Cancel = True;
	
EndProcedure

&AtClient
Procedure PropertiesChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	StandardProcessing = False;
	
	If TypeOf(ValueSelected) = Type("Structure") Then
		If ValueSelected.Property("AdditionalValuesOwner") Then
			
			FormParameters = New Structure;
			FormParameters.Insert("ThisIsAdditionalInformation",	ThisIsSetOfAdditionalInformation);
			FormParameters.Insert("CurrentSetOfProperties",			CurrentSet);
			FormParameters.Insert("AdditionalValuesOwner",			ValueSelected.AdditionalValuesOwner);
			
			OpenForm("ChartOfCharacteristicTypes.AdditionalAttributesAndInformation.ObjectForm",
				FormParameters, Items.Properties);
			
		ElsIf ValueSelected.Property("CommonProperty") Then
			
			ExecuteCommandAtServer("AddCommonProperty", ValueSelected.CommonProperty);
			
			Notify("Writing_AdditionalAttributesAndInformationSets",
				New Structure("Ref", CurrentSet), CurrentSet);
		Else
			SelectSpecifiedRows(ValueSelected);
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure Create(Command = Undefined)
	
	FormParameters = New Structure;
	FormParameters.Insert("PropertySet",					CurrentSet);
	FormParameters.Insert("ThisIsAdditionalInformation",	ThisIsSetOfAdditionalInformation);
	FormParameters.Insert("CurrentSetOfProperties",			CurrentSet);
	
	OpenForm("ChartOfCharacteristicTypes.AdditionalAttributesAndInformation.ObjectForm",
		FormParameters, Items.Properties);
	
EndProcedure

&AtClient
Procedure CreateSample(Command)
	
	FormParameters = New Structure;
	FormParameters.Insert("ChoiceMode", True);
	FormParameters.Insert("ThisIsAdditionalInformation",		ThisIsSetOfAdditionalInformation);
	FormParameters.Insert("OwnersSelectionOfAdditionalValues",	True);
	FormParameters.Insert("CurrentSetOfProperties",				CurrentSet);
	
	OpenForm("ChartOfCharacteristicTypes.AdditionalAttributesAndInformation.ChoiceForm",
		FormParameters, Items.Properties);
	
EndProcedure

&AtClient
Procedure CreateCommon(Command)
	
	SelectedValues = New Array;
	FoundStrings = Properties.FindRows(New Structure("Common", True));
	For Each String In FoundStrings Do
		SelectedValues.Add(String.Property);
	EndDo;
	
	FormParameters = New Structure;
	FormParameters.Insert("ChoiceMode",						True);
	FormParameters.Insert("ThisIsAdditionalInformation",	ThisIsSetOfAdditionalInformation);
	FormParameters.Insert("SelectionOfCommonProperty",		True);
	FormParameters.Insert("CurrentSetOfProperties",			CurrentSet);
	FormParameters.Insert("SelectedValues",					SelectedValues);
	
	OpenForm("ChartOfCharacteristicTypes.AdditionalAttributesAndInformation.ChoiceForm",
		FormParameters, Items.Properties);
	
EndProcedure

&AtClient
Procedure Change(Command = Undefined)
	
	If Items.Properties.CurrentData <> Undefined Then
		// Ownership form opening.
		FormParameters = New Structure("Key, CurrentSetOfProperties", Items.Properties.CurrentData.Property, CurrentSet);
		
		OpenForm("ChartOfCharacteristicTypes.AdditionalAttributesAndInformation.ObjectForm",
			FormParameters, Items.Properties);
	EndIf;
	
EndProcedure

&AtClient
Procedure Copy(Command = Undefined)
	
	FormParameters = New Structure;
	FormParameters.Insert("CurrentSetOfProperties",	CurrentSet);
	FormParameters.Insert("CopyingValue",			Items.Properties.CurrentData.Property);
	
	OpenForm("ChartOfCharacteristicTypes.AdditionalAttributesAndInformation.ObjectForm", FormParameters);
	
EndProcedure

&AtClient
Procedure MarkToDelete(Command)
	
	ChangeDeletionMark();
	
EndProcedure

&AtClient
Procedure MoveUp(Command)
	
	ExecuteCommandAtServer("MoveUp");
	
EndProcedure

&AtClient
Procedure MoveDown(Command)
	
	ExecuteCommandAtServer("MoveDown");
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure ApplyAppearanceSetsAndProperties()
	
	// Creating the appearance of the list set root.
	ConditionalAppearanceItem = ConditionalAppearance.Items.Add();
	
	ItemColorsDesign = ConditionalAppearanceItem.Appearance.Items.Find("Text");
	ItemColorsDesign.Value	= NStr("en = 'Sets'");
	ItemColorsDesign.Use	= True;
	
	CommonUseClientServer.AddCompositionItem(ConditionalAppearanceItem.Filter, "PropertiesSets.Ref", 
		DataCompositionComparisonType.NotFilled,,, True);
	
	ItemProcessedFields = ConditionalAppearanceItem.Fields.Items.Add();
	ItemProcessedFields.Field	= New DataCompositionField("Presentation");
	ItemProcessedFields.Use		= True;
	
	// Creating the appearance of unavailable set groups that are implicitly displayed by the platform as a part of the
	// group tree.
	ConditionalAppearanceItem = ConditionalAppearance.Items.Add();
	
	ItemColorsDesign = ConditionalAppearanceItem.Appearance.Items.Find("TextColor");
	ItemColorsDesign.Value	= Metadata.StyleItems.InaccessibleDataColor.Value;
	ItemColorsDesign.Use	= True;
	
	FolderSelectionDataElements = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
	FolderSelectionDataElements.GroupType	= DataCompositionFilterItemsGroupType.AndGroup;
	FolderSelectionDataElements.Use			= True;
	
	CommonUseClientServer.AddCompositionItem(FolderSelectionDataElements, "PropertiesSets.Ref", 
		DataCompositionComparisonType.NotInList, AvailableSetsList,, True);
	
	CommonUseClientServer.AddCompositionItem(FolderSelectionDataElements, "PropertiesSets.Parent",
		DataCompositionComparisonType.NotInList, AvailableSetsList,, True);
	
	CommonUseClientServer.AddCompositionItem(FolderSelectionDataElements, "PropertiesSets.Ref",
		DataCompositionComparisonType.Filled,,, True);
	
	ItemProcessedFields = ConditionalAppearanceItem.Fields.Items.Add();
	ItemProcessedFields.Field	= New DataCompositionField("Presentation");
	ItemProcessedFields.Use		= True;
	
	// Creating the appearance of attributes to be filled.
	ConditionalAppearanceItem = ConditionalAppearance.Items.Add();
	
	ItemColorsDesign = ConditionalAppearanceItem.Appearance.Items.Find("Font");
	ItemColorsDesign.Value	= New Font(,, True);
	ItemColorsDesign.Use	= True;
	
	CommonUseClientServer.AddCompositionItem(ConditionalAppearanceItem.Filter, "Properties.FillObligatory",
		DataCompositionComparisonType.Equal, True,, True);
	
	ItemProcessedFields = ConditionalAppearanceItem.Fields.Items.Add();
	ItemProcessedFields.Field	= New DataCompositionField("PropertiesTitle");
	ItemProcessedFields.Use		= True;
	
EndProcedure

&AtClient
Procedure SelectSpecifiedRows(Definition)
	
	If Definition.Property("Set") Then
		
		If TypeOf(Definition.Set) = Type("String") Then
			ConvertRowsToLinks(Definition);
		EndIf;
		
		If Definition.ThisIsAdditionalInformation <> ThisIsSetOfAdditionalInformation Then
			ThisIsSetOfAdditionalInformation = Definition.ThisIsAdditionalInformation;
			ConfigureRepresentationSets();
		EndIf;
		
		Items.PropertiesSets.CurrentRow	= Definition.Set;
		CurrentSet						= Undefined;
		
		OnChangeOfCurrentSet();
		
		FoundStrings = Properties.FindRows(New Structure("Property", Definition.Property));
		If FoundStrings.Count() > 0 Then
			Items.Properties.CurrentRow = FoundStrings[0].GetID();
		Else
			Items.Properties.CurrentRow = Undefined;
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Procedure ConvertRowsToLinks(Definition)
	
	Definition.Insert("Set", Catalogs.AdditionalAttributesAndInformationSets.GetRef(New UUID(Definition.Set)));
	
	Definition.Insert("Property", ChartsOfCharacteristicTypes.AdditionalAttributesAndInformation.GetRef(New UUID(Definition.Property)));
	
EndProcedure

&AtServer
Procedure ConfigureUsingCommands()
	
	Items.PropertiesOnlyCreate.Visible				= False;
	Items.PropertiesPopupAdd.Visible				= True;
	Items.PropertiesContextMenuOnlyCreate.Visible	= False;
	Items.PropertiesContextMenuPopupAdd.Visible		= True;
	
EndProcedure

&AtServer
Procedure ConfigureRepresentationSets()
	
	CommandCreate			= Commands.Find("Create");
	CommandCreateBySample	= Commands.Find("CreateSample");
	CommandCreateCommon		= Commands.Find("CreateCommon");
	CommandCopy				= Commands.Find("Copy");
	CommandChange			= Commands.Find("Change");
	CommandMarkToDelete		= Commands.Find("MarkToDelete");
	CommandMoveUp			= Commands.Find("MoveUp");
	CommandMoveDown			= Commands.Find("MoveDown");
	
	If ThisIsSetOfAdditionalInformation Then
		Title = NStr("en = 'Additional information'");
		
		CommandCreate.ToolTip	= NStr("en = 'Create unique information'");
		CommandCreate.Title		= NStr("en = 'New'");
		CommandCreate.ToolTip	= NStr("en = 'Create unique information'");
		
		CommandCreateBySample.Title		= NStr("en = 'According to sample'");
		CommandCreateBySample.ToolTip	= NStr("en = 'Create information according to the sample (common value list)'");
		
		CommandCreateCommon.Title	= NStr("en = 'Common...'");
		CommandCreateCommon.ToolTip	= NStr("en = 'Select common information from the existing information'");
		CommandCopy.ToolTip			= NStr("en = 'Create new information by copying the existing one'");
		CommandChange.ToolTip		= NStr("en = 'Change (or open) the current information'");
		CommandMarkToDelete.ToolTip	= NStr("en = 'Mark current information for deletion (Del)'");		
		CommandMoveUp.ToolTip		= NStr("en = 'Move the current data up'");
		CommandMoveDown.ToolTip		= NStr("en = 'Move the current information down'");
		
		MetadataTabularSection = Metadata.Catalogs.AdditionalAttributesAndInformationSets.TabularSections.AdditionalInformation;
		
		Items.PropertiesTitle.Title		= MetadataTabularSection.Attributes.Property.Synonym;
		Items.PropertiesTitle.ToolTip	= MetadataTabularSection.Attributes.Property.ToolTip;
		
		Items.PropertiesRequiredToFill.Visible	= False;
		
		Items.PropertiesValueType.ToolTip		= NStr("en = 'Value types that can be entered on filling in the information.'");	
		Items.PropertiesSharedValues.ToolTip	= NStr("en = 'Information uses sample list of values.'");
		
		Items.PropertiesCommon.Title	= NStr("en = 'Common'");
		Items.PropertiesCommon.ToolTip	= NStr("en = 'Common custom data used in several additional data sets.'");
	Else
		
		Title = NStr("en = 'Additional attributes'");
		CommandCreate.Title		= NStr("en = 'New'");
		CommandCreate.ToolTip	= NStr("en = 'Create a unique field'");
		
		CommandCreateBySample.Title		= NStr("en = 'According to sample'");
		CommandCreateBySample.ToolTip	= NStr("en = 'Create a field according to the sample (common value list)'");
		CommandCreateCommon.Title		= NStr("en = 'Common...'");
		CommandCreateCommon.ToolTip     = NStr("en = 'Select a common attribute from the existing ones'");
		
		CommandCopy.ToolTip			= NStr("en = 'Create a new attribute by copying the current one'");
		CommandChange.ToolTip		= NStr("en = 'Edit (or open) the current field'");
		CommandMarkToDelete.ToolTip	= NStr("en = 'Mark the current field for deletion (Del)'");
		CommandMoveUp.ToolTip		= NStr("en = 'Move the current attribute up'");
		CommandMoveDown.ToolTip		= NStr("en = 'Move current attribute down'");
		
		MetadataTabularSection = Metadata.Catalogs.AdditionalAttributesAndInformationSets.TabularSections.AdditionalAttributes;
		
		Items.PropertiesTitle.Title		= MetadataTabularSection.Attributes.Property.Synonym;
		Items.PropertiesTitle.ToolTip	= MetadataTabularSection.Attributes.Property.ToolTip;
		
		Items.PropertiesRequiredToFill.Visible = True;
		Items.PropertiesRequiredToFill.ToolTip = Metadata.ChartsOfCharacteristicTypes.AdditionalAttributesAndInformation.Attributes.FillObligatory.ToolTip;
		
		Items.PropertiesValueType.ToolTip		= NStr("en = 'Types of values that can be entered on filling in the attribute.'");	
		Items.PropertiesSharedValues.ToolTip	= NStr("en = 'The attribute uses the attribute-sample value list.'");
		
		Items.PropertiesCommon.Title	= NStr("en = 'Common'");
		Items.PropertiesCommon.ToolTip	= NStr("en = 'A common custom field used in several custom field sets.'");
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	Sets.Ref AS Ref
	|FROM
	|	Catalog.AdditionalAttributesAndInformationSets AS Sets
	|WHERE
	|	Sets.Parent = VALUE(Catalog.AdditionalAttributesAndInformationSets.EmptyRef)";
	
	Sets = Query.Execute().Unload().UnloadColumn("Ref");
	AvailableSets = New Array;
	AvailableSetsList.Clear();
	
	For Each Ref In Sets Do
		SetPropertyTypes = PropertiesManagementService.SetPropertyTypes(Ref, False);
		
		If (ThisIsSetOfAdditionalInformation
				AND SetPropertyTypes.AdditionalInformation)
			OR (NOT ThisIsSetOfAdditionalInformation
				AND SetPropertyTypes.AdditionalAttributes) Then
			
			AvailableSets.Add(Ref);
			AvailableSetsList.Add(Ref);
			
		EndIf;
	EndDo;
	
	CommonUseClientServer.SetDynamicListParameter(PropertiesSets, "ThisIsSetOfAdditionalInformation", ThisIsSetOfAdditionalInformation, True);
	
	CommonUseClientServer.SetDynamicListParameter(PropertiesSets, "Sets", AvailableSets, True);
		
	If Not Items.ThisIsSetOfAdditionalInformation.Visible Then
		// Hide marked for deletion.
		CommonUseClientServer.SetFilterDynamicListItem(
			PropertiesSets, "DeletionMark", False, , , True,
			DataCompositionSettingsItemViewMode.Normal);
	EndIf;
	
	OnChangeOfCurrentSetAtServer();
	
EndProcedure

&AtClient
Procedure OnChangeOfCurrentSet()
	
	If Items.PropertiesSets.CurrentData = Undefined Then
		
		If ValueIsFilled(CurrentSet) Then
			CurrentSet = Undefined;
			OnChangeOfCurrentSetAtServer();
		EndIf;
		
	ElsIf Items.PropertiesSets.CurrentData.Ref <> CurrentSet Then
		
		CurrentSet			= Items.PropertiesSets.CurrentData.Ref;
		CurrentSetIsFolder	= Items.PropertiesSets.CurrentData.IsFolder;
		OnChangeOfCurrentSetAtServer();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ChangeDeletionMark()
	
	If Items.Properties.CurrentData <> Undefined Then
		
		If ThisIsSetOfAdditionalInformation Then
			If Items.Properties.CurrentData.Common Then
				QuestionText = NStr("en = 'Exclude the current common information from the set?'");	
			ElsIf Items.Properties.CurrentData.DeletionMark Then
				QuestionText = NStr("en = 'Clear mark for deletion for the current information?'");
			Else
				QuestionText = NStr("en = 'Mark current information for deletion?'");
			EndIf;
		Else
			If Items.Properties.CurrentData.Common Then
				QuestionText = NStr("en = 'Exclude the current common attribute from the set?'");			
			ElsIf Items.Properties.CurrentData.DeletionMark Then
				QuestionText = NStr("en = 'Clear mark for deletion for the current attribute?'");
			Else
				QuestionText = NStr("en = 'Mark the current field for deletion?'");
			EndIf;
		EndIf;
		
		ShowQueryBox(New NotifyDescription("ChangeDeletionMarkEnd", ThisObject, CurrentSet),
			QuestionText, QuestionDialogMode.YesNo);
	EndIf;
	
EndProcedure

&AtClient
Procedure ChangeDeletionMarkEnd(Response, CurrentSet) Export
	
	If Response <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	ExecuteCommandAtServer("ChangeDeletionMark");
	
	Notify("Writing_AdditionalAttributesAndInformationSets", New Structure("Ref", CurrentSet), CurrentSet);
	
EndProcedure

&AtServer
Procedure OnChangeOfCurrentSetAtServer()
	
	If ValueIsFilled(CurrentSet)
		AND NOT CurrentSetIsFolder Then
		
		CurrentEnabled = True;
		If Items.Properties.BackColor <> Items.PropertiesSets.BackColor Then
			Items.Properties.BackColor = Items.PropertiesSets.BackColor;
		EndIf;
		
		RefreshListOfPropertiesOfCurrentSetOf(CurrentEnabled);
		
	Else
		
		CurrentEnabled = False;
		If Items.Properties.BackColor <> ColorForms Then
			Items.Properties.BackColor = ColorForms;
		EndIf;
		
		Properties.Clear();
		
	EndIf;
	
	If Items.Properties.ReadOnly = CurrentEnabled Then
		Items.Properties.ReadOnly = NOT CurrentEnabled;
	EndIf;
	
	PropertiesSetEnabledCommands(ThisObject);
	
	Items.PropertiesSets.Refresh();
	
EndProcedure

&AtClientAtServerNoContext
Procedure PropertiesSetEnabledCommands(Context)
	
	Items = Context.Items;
	
	TotalEnabled = NOT Items.Properties.ReadOnly;
	
	EnabledForRows = TotalEnabled
		AND Context.Items.Properties.CurrentRow <> Undefined;
	
	// Configuring the commands of the command panels.
	Items.PropertiesCreate.Enabled			= TotalEnabled;
	Items.PropertiesOnlyCreate.Enabled		= TotalEnabled;
	Items.CreatePropertiesOnSample.Enabled	= TotalEnabled;
	Items.PropertiesCreateCommon.Enabled	= TotalEnabled;
	Items.PropertiesCopy.Enabled			= EnabledForRows;
	Items.PropertiesChange.Enabled			= EnabledForRows;
	Items.PropertiesMarkToDelete.Enabled	= EnabledForRows;
	Items.PropertiesMoveUp.Enabled			= EnabledForRows;
	Items.PropertiesMoveDown.Enabled		= EnabledForRows;
	
	// Configuring the shortcut menu commands.
	Items.PropertiesContextMenuCreate.Enabled			= TotalEnabled;
	Items.PropertiesContextMenuOnlyCreate.Enabled		= TotalEnabled;
	Items.CreateContextMenuPropertiesOnSample.Enabled	= TotalEnabled;
	Items.PropertiesContextMenuCreateCommon.Enabled		= TotalEnabled;	
	Items.PropertiesContextMenuCopy.Enabled				= EnabledForRows;
	Items.PropertiesContextMenuChange.Enabled			= EnabledForRows;
	Items.PropertiesContextMenuMarkToDelete.Enabled		= EnabledForRows;
	
EndProcedure

&AtServer
Procedure RefreshListOfPropertiesOfCurrentSetOf(CurrentEnabled)
	
	Query = New Query;
	Query.SetParameter("Set", CurrentSet);
	
	Query.Text =
	"SELECT
	|	SetsProperties.LineNumber,
	|	SetsProperties.Property,
	|	SetsProperties.DeletionMark,
	|	ISNULL(Properties.Title, PRESENTATION(SetsProperties.Property)) AS Title,
	|	Properties.AdditionalValuesOwner,
	|	Properties.FillObligatory,
	|	Properties.ValueType AS ValueType,
	|	CASE
	|		WHEN Properties.Ref IS NULL 
	|			THEN TRUE
	|		WHEN Properties.PropertySet = VALUE(Catalog.AdditionalAttributesAndInformationSets.EmptyRef)
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS Common,
	|	CASE
	|		WHEN SetsProperties.DeletionMark = TRUE
	|			THEN 4
	|		ELSE 3
	|	END AS PictureNumber
	|FROM
	|	Catalog.AdditionalAttributesAndInformationSets.AdditionalAttributes AS SetsProperties
	|		LEFT JOIN ChartOfCharacteristicTypes.AdditionalAttributesAndInformation AS Properties
	|		ON SetsProperties.Property = Properties.Ref
	|WHERE
	|	SetsProperties.Ref = &Set
	|
	|ORDER BY
	|	SetsProperties.LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Sets.DataVersion AS DataVersion
	|FROM
	|	Catalog.AdditionalAttributesAndInformationSets AS Sets
	|WHERE
	|	Sets.Ref = &Set";
	
	If ThisIsSetOfAdditionalInformation Then
		Query.Text = StrReplace(
			Query.Text,
			"Catalog.AdditionalAttributesAndInformationSets.AdditionalAttributes",
			"Catalog.AdditionalAttributesAndInformationSets.AdditionalInformation");
	EndIf;
	
	BeginTransaction();
	Try
		ResultsOfQuery = Query.ExecuteBatch();
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	If Items.Properties.CurrentRow = Undefined Then
		String = Undefined;
	Else
		String = Properties.FindByID(Items.Properties.CurrentRow);
	EndIf;
	CurrentProperty = ?(String = Undefined, Undefined, String.Property);
	
	Properties.Clear();
	
	If ResultsOfQuery[1].IsEmpty() Then
		CurrentEnabled = False;
		Return;
	EndIf;
	
	CurrentSetDataVersion = ResultsOfQuery[1].Unload()[0].DataVersion;
	
	Selection = ResultsOfQuery[0].Select();
	While Selection.Next() Do
		
		NewRow = Properties.Add();
		FillPropertyValues(NewRow, Selection);
		
		NewRow.GeneralValues = ValueIsFilled(Selection.AdditionalValuesOwner);
		
		If Selection.ValueType <> NULL
		   AND PropertiesManagementService.ValueTypeContainsPropertiesValues(Selection.ValueType) Then
			
			NewRow.ValueType = String(New TypeDescription(
				Selection.ValueType,
				,
				"CatalogRef.AdditionalValuesHierarchy, CatalogRef.AdditionalValues"));
			
			Query = New Query;
			
			If ValueIsFilled(Selection.AdditionalValuesOwner) Then
				Query.SetParameter("Owner", Selection.AdditionalValuesOwner);
			Else
				Query.SetParameter("Owner", Selection.Property);
			EndIf;
			
			Query.Text =
			"SELECT TOP 4
			|	AdditionalValues.Description AS Description
			|FROM
			|	Catalog.AdditionalValues AS AdditionalValues
			|WHERE
			|	AdditionalValues.Owner = &Owner
			|	AND Not AdditionalValues.IsFolder
			|	AND Not AdditionalValues.DeletionMark
			|
			|UNION
			|
			|SELECT TOP 4
			|	AdditionalValuesHierarchy.Description
			|FROM
			|	Catalog.AdditionalValuesHierarchy AS AdditionalValuesHierarchy
			|WHERE
			|	AdditionalValuesHierarchy.Owner = &Owner
			|	AND Not AdditionalValuesHierarchy.DeletionMark
			|;
			|
			|////////////////////////////////////////////////////////////////////////////////
			|SELECT TOP 1
			|	TRUE AS TrueValue
			|FROM
			|	Catalog.AdditionalValues AS AdditionalValues
			|WHERE
			|	AdditionalValues.Owner = &Owner
			|	AND Not AdditionalValues.IsFolder
			|
			|UNION ALL
			|
			|SELECT TOP 1
			|	TRUE
			|FROM
			|	Catalog.AdditionalValuesHierarchy AS AdditionalValuesHierarchy
			|WHERE
			|	AdditionalValuesHierarchy.Owner = &Owner";
			ResultsOfQuery = Query.ExecuteBatch();
			
			FirstValues = ResultsOfQuery[0].Unload().UnloadColumn("Description");
			
			If FirstValues.Count() = 0 Then
				If ResultsOfQuery[1].IsEmpty() Then
					ValuesPresentation = NStr("en = 'No values entered'");
				Else
					ValuesPresentation = NStr("en = 'Values are marked for deletion'");
				EndIf;
			Else
				
				ValuesPresentation	= "";
				Number				= 0;
				
				For Each Value In FirstValues Do
					Number = Number + 1;
					
					If Number = 4 Then
						ValuesPresentation = ValuesPresentation + ",...";
						Break;
					EndIf;
					
					ValuesPresentation = ValuesPresentation + ?(Number > 1, ", ", "") + Value;
				EndDo;
				
			EndIf;
			
			ValuesPresentation = "<" + ValuesPresentation + ">";
			If ValueIsFilled(NewRow.ValueType) Then
				ValuesPresentation = ValuesPresentation + ", ";
			EndIf;
			
			NewRow.ValueType = ValuesPresentation + NewRow.ValueType;
			
		EndIf;
		
		If Selection.Property = CurrentProperty Then
			Items.Properties.CurrentRow =
				Properties[Properties.Count()-1].GetID();
		EndIf;
	EndDo;
	
EndProcedure

&AtServer
Procedure ExecuteCommandAtServer(Command, Parameter = Undefined)
	
	Block = New DataLock;
	
	If Command = "ChangeDeletionMark" Then
		LockItem = Block.Add("Catalog.AdditionalAttributesAndInformationSets");
		LockItem.Mode = DataLockMode.Exclusive;
		
		LockItem = Block.Add("ChartOfCharacteristicTypes.AdditionalAttributesAndInformation");
		LockItem.Mode = DataLockMode.Exclusive;
		
		LockItem = Block.Add("Catalog.AdditionalValues");
		LockItem.Mode = DataLockMode.Exclusive;
		
		LockItem = Block.Add("Catalog.AdditionalValuesHierarchy");
		LockItem.Mode = DataLockMode.Exclusive;
	Else
		LockItem = Block.Add("Catalog.AdditionalAttributesAndInformationSets");
		LockItem.Mode = DataLockMode.Exclusive;
		LockItem.SetValue("Ref", CurrentSet);
	EndIf;
	
	Try
		LockDataForEdit(CurrentSet);
		BeginTransaction();
		
		Try
			Block.Lock();
			LockDataForEdit(CurrentSet);
			
			CurrentSetObject = CurrentSet.GetObject();
			If CurrentSetObject.DataVersion <> CurrentSetDataVersion Then
				
				OnChangeOfCurrentSetAtServer();
				
				If ThisIsSetOfAdditionalInformation Then
					Raise
						NStr("en = 'Action is not performed since the
						     |content of additional information was changed by another user.
						     |New content of additional information is read.
						     |Retry the action if necessary'");
				Else
					Raise
						NStr("en = 'Action is not performed since the
						     |content of additional attributes was changed by another user.
						     |New content of additional attributes is read.
						     |Retry the action if necessary'");
				EndIf;
					
			EndIf;
			
			TabularSection = CurrentSetObject[?(ThisIsSetOfAdditionalInformation,
				"AdditionalInformation", "AdditionalAttributes")];
			
			If Command = "AddCommonProperty" Then
				
				FoundString = TabularSection.Find(Parameter, "Property");
				
				If FoundString = Undefined Then
					
					NewRow = TabularSection.Add();
					NewRow.Property = Parameter;
					CurrentSetObject.Write();
					
				ElsIf FoundString.DeletionMark Then
					FoundString.DeletionMark = False;
					CurrentSetObject.Write();
				EndIf;
				
			Else
				
				String = Properties.FindByID(Items.Properties.CurrentRow);
				
				If String <> Undefined Then
					IndexOf = String.LineNumber-1;
					
					If Command = "MoveUp" Then
						
						IndexOfTopRows = Properties.IndexOf(String) - 1;
						If IndexOfTopRows >= 0 Then
							Shift = Properties[IndexOfTopRows].LineNumber - String.LineNumber;
							TabularSection.Move(IndexOf, Shift);
						EndIf;
						CurrentSetObject.Write();
						
					ElsIf Command = "MoveDown" Then
						
						IndexOfBottomRows = Properties.IndexOf(String) + 1;
						If IndexOfBottomRows < Properties.Count() Then
							Shift = Properties[IndexOfBottomRows].LineNumber - String.LineNumber;
							TabularSection.Move(IndexOf, Shift);
						EndIf;
						CurrentSetObject.Write();
						
					ElsIf Command = "ChangeDeletionMark" Then
						
						String = Properties.FindByID(Items.Properties.CurrentRow);
						
						If String.Common Then
							
							TabularSection.Delete(IndexOf);
							CurrentSetObject.Write();
							
							Properties.Delete(String);
							
							If TabularSection.Count() > IndexOf Then
								Items.Properties.CurrentRow = Properties[IndexOf].GetID();
							ElsIf TabularSection.Count() > 0 Then
								Items.Properties.CurrentRow = Properties[Properties.Count()-1].GetID();
							EndIf;
							
						Else
							TabularSection[IndexOf].DeletionMark = Not TabularSection[IndexOf].DeletionMark;
							CurrentSetObject.Write();
							
							ChangeDeletionMarkAndValuesOwner(
								CurrentSetObject.Ref,
								TabularSection[IndexOf].Property,
								TabularSection[IndexOf].DeletionMark);
						EndIf;
					EndIf;
				EndIf;
			EndIf;
			
			CommitTransaction();
			
		Except
			RollbackTransaction();
			Raise;
		EndTry;
		
	Except
		UnlockDataForEdit(CurrentSet);
		Raise;
	EndTry;
	
	OnChangeOfCurrentSetAtServer();
	
EndProcedure

&AtServer
Procedure ChangeDeletionMarkAndValuesOwner(CurrentSet, CurrentProperty, DeletionMarkProperties)
	
	OldOwnerValues	= CurrentProperty;
	NewCheckValues	= Undefined;
	NewOwnerValues	= Undefined;	
	PropertyObject	= CurrentProperty.GetObject();
	
	If ValueIsFilled(PropertyObject.PropertySet) Then
		
		If DeletionMarkProperties Then
			// When marking the unique property:
			// - mark property,
			// - if there are attributes created using the
			//   sample and not marked for
			//   deletion, specify the new value owner
			//   and assign a new sample to all attributes, otherwise mark all values for deletion.
			PropertyObject.DeletionMark = True;
			
			If NOT ValueIsFilled(PropertyObject.AdditionalValuesOwner) Then
				
				Query = New Query;
				Query.SetParameter("Property", PropertyObject.Ref);
				Query.Text =
				"SELECT
				|	Properties.Ref,
				|	Properties.DeletionMark
				|FROM
				|	ChartOfCharacteristicTypes.AdditionalAttributesAndInformation AS Properties
				|WHERE
				|	Properties.AdditionalValuesOwner = &Property";
				Exporting	= Query.Execute().Unload();
				FoundString	= Exporting.Find(False, "DeletionMark");
				
				If FoundString <> Undefined Then
					NewOwnerValues  = FoundString.Ref;
					PropertyObject.AdditionalValuesOwner = NewOwnerValues;
					For Each String In Exporting Do
						CurrentObject = String.Ref.GetObject();
						If CurrentObject.Ref = NewOwnerValues Then
							CurrentObject.AdditionalValuesOwner = Undefined;
						Else
							CurrentObject.AdditionalValuesOwner = NewOwnerValues;
						EndIf;
						CurrentObject.Write();
					EndDo;
				Else
					NewCheckValues = True;
				EndIf;
				
			EndIf;
			
			PropertyObject.Write();
			
		Else
			
			If PropertyObject.DeletionMark Then
				PropertyObject.DeletionMark = False;
				PropertyObject.Write();
			EndIf;
			// When removing the flag of the unique property:
			// - unmark properties,
			// - If the attribute is
			//   created using the sample, then if
			//   the sample is marked for deletion, then specify
			//   a new owner of values (current) for all attributes and remove
			//   the delection flag from the values, otherwise remove the deletion flag from the values.
			
			If Not ValueIsFilled(PropertyObject.AdditionalValuesOwner) Then
				
				NewCheckValues = False;
				
			ElsIf CommonUse.ObjectAttributeValue(
			            PropertyObject.AdditionalValuesOwner, "DeletionMark") Then
				
				Query = New Query;
				Query.SetParameter("Property", PropertyObject.AdditionalValuesOwner);
				Query.Text =
				"SELECT
				|	Properties.Ref AS Ref
				|FROM
				|	ChartOfCharacteristicTypes.AdditionalAttributesAndInformation AS Properties
				|WHERE
				|	Properties.AdditionalValuesOwner = &Property";
				Array = Query.Execute().Unload().UnloadColumn("Ref");
				Array.Add(PropertyObject.AdditionalValuesOwner);
				
				NewOwnerValues = PropertyObject.Ref;
				
				For Each CurrentRef In Array Do
					If CurrentRef = NewOwnerValues Then
						Continue;
					EndIf;
					CurrentObject = CurrentRef.GetObject();
					CurrentObject.AdditionalValuesOwner = NewOwnerValues;
					CurrentObject.Write();
				EndDo;
				
				OldOwnerValues = PropertyObject.AdditionalValuesOwner;
				
				PropertyObject.AdditionalValuesOwner = Undefined;
				PropertyObject.Write();
				
				NewCheckValues = False;
				
			EndIf;
		EndIf;
	EndIf;
	
	If NewCheckValues = Undefined
		AND NewOwnerValues = Undefined Then
			Return;
	EndIf;
	
	Query = New Query;
	Query.SetParameter("Owner", OldOwnerValues);
	Query.Text =
	"SELECT
	|	AdditionalValues.Ref AS Ref,
	|	AdditionalValues.DeletionMark AS DeletionMark
	|FROM
	|	Catalog.AdditionalValues AS AdditionalValues
	|WHERE
	|	AdditionalValues.Owner = &Owner
	|
	|UNION ALL
	|
	|SELECT
	|	AdditionalValuesHierarchy.Ref,
	|	AdditionalValuesHierarchy.DeletionMark
	|FROM
	|	Catalog.AdditionalValuesHierarchy AS AdditionalValuesHierarchy
	|WHERE
	|	AdditionalValuesHierarchy.Owner = &Owner";
	
	Exporting = Query.Execute().Unload();
	
	If NewOwnerValues <> Undefined Then
		For Each String In Exporting Do
			
			CurrentObject = String.Ref.GetObject();
			
			If CurrentObject.Owner <> NewOwnerValues Then
				CurrentObject.Owner = NewOwnerValues;
			EndIf;
			
			If CurrentObject.Modified() Then
				CurrentObject.DataExchange.Load = True;
				CurrentObject.Write();
			EndIf;
			
		EndDo;
	EndIf;
	
	If NewCheckValues <> Undefined Then
		For Each String In Exporting Do
			
			CurrentObject = String.Ref.GetObject();
			
			If CurrentObject.DeletionMark <> NewCheckValues Then
				CurrentObject.DeletionMark = NewCheckValues;
			EndIf;
			
			If CurrentObject.Modified() Then
				CurrentObject.Write();
			EndIf;
			
		EndDo;
	EndIf;
	
EndProcedure

#EndRegion
