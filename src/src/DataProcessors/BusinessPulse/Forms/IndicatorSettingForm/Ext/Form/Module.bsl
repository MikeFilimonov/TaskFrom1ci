
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Parameters.Property("Indicator", Indicator);
	Parameters.Property("Resource", Resource);
	Parameters.Property("Presentation", Presentation);
	Parameters.Property("Filters", Filters);
	
	If Filters = Undefined Then
		Filters = New FixedArray(New Array);
	EndIf;
	
	Parameters.Property("Settings", Settings);
	
	If Settings = Undefined Then
		Settings = New FixedArray(New Array);
	EndIf; 
	
	If Parameters.Property("RowID") Then
		RowID = Parameters.RowID;
		Title = NStr("en = 'Indicator setting'");
	Else
		RowID = -1;
		Title = NStr("en = 'Add indicator'");
	EndIf; 
	
	If Parameters.Property("IndicatorSettingAddress") AND IsTempStorageURL(Parameters.IndicatorSettingAddress) Then
		IndicatorSettings.Load(GetFromTempStorage(Parameters.IndicatorSettingAddress));
	EndIf; 
	
	Tab = IndicatorSettings.Unload(, "Indicator, Presentation");
	Tab.GroupBy("Indicator, Presentation");
	Items.Indicator.ChoiceList.Clear();
	
	For Each Str In Tab Do
		Items.Indicator.ChoiceList.Add(Str.Indicator, Str.Presentation);
	EndDo;
	
	SetSettingFieldVisibility();
	If ValueIsFilled(Indicator) AND ValueIsFilled(Resource) Then
		UpdateComposerParameters();
	EndIf; 
	
	If Not RowID = -1 Then
		UpdateFilterMarkDisplay();
		UpdateSettingDisplay();
		CurrentItem = Items.Resource;
	EndIf; 
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	FillInSelectionListResources();
	// Update values after filling in the selection list;
	Resource = Resource;

EndProcedure

&AtClient
Procedure ChoiceProcessing(SelectedValue, ChoiceSource)
	
	If Not TypeOf(SelectedValue) = Type("Structure") Then
		Return;
	EndIf;
	
	Value = SelectedValue.Value;
	
	If SelectedValue.Event = "AddFilter" Then
		MergeFiltersServer(SelectedValue);
	EndIf; 
	
EndProcedure

#EndRegion 

#Region FormsItemEventHandlers

&AtClient
Procedure IndicatorWhenChanging(Item)
	
	FillInSelectionListResources();
	
	If Not ValueIsFilled(Resource) AND Items.Resource.ChoiceList.Count() > 0 Then
		Resource = Items.Resource.ChoiceList[0].Value;
	EndIf;
	
	WhenChangingResourceIndicatorServer();
	GeneratePresentation();
	
EndProcedure

&AtClient
Procedure ResourceOnChange(Item)
	
	WhenChangingResourceIndicatorServer();
	GeneratePresentation();
	
EndProcedure

#Region FilterMarks

&AtClient
Procedure Attachable_DeleteFilterClick(Item, URL, StandardProcessing)
	
	StandardProcessing = False;
	
	ButtonName = Item.Name;	
	Str = AppliedFilterLine(ButtonName);
	If Str = Undefined Then
		Return;
	EndIf; 
	
	DeleteFilter(Str);
	
EndProcedure

&AtClient
Procedure DeleteFilter(AppliedFilterStr)
	
	ArrayToDelete	= New Array;
	FiltersArray	= New Array(Filters);
	
	For Each Filter In FiltersArray Do
		
		If Not AppliedFilterStr.Field = Filter.Field Then
			Continue;
		EndIf;
		
		If TypeOf(Filter.Value) = Type("ValueList") Then
			
			Item = Filter.Value.FindByValue(AppliedFilterStr.Value);
			
			If Not Item=Undefined Then
				Filter.Value.Delete(Item);
			EndIf; 
			
			If Filter.Value.Count() = 0 Then
				ArrayToDelete.Add(Filter);
			EndIf;
			
		ElsIf TypeOf(Filter.Value) = Type("Date") Then
			ArrayToDelete.Add(Filter);
		ElsIf TypeOf(Filter.Value) = Type("Number") Then
			ArrayToDelete.Add(Filter);
		ElsIf Filter.Value=AppliedFilterStr.Value Then 
			ArrayToDelete.Add(Filter);
		EndIf; 
		
	EndDo; 
	
	For Each Filter In ArrayToDelete Do
		FiltersArray.Delete(FiltersArray.Find(Filter));
	EndDo; 
	
	Filters = New FixedArray(FiltersArray);
	
	UpdateFilterMarkDisplay();
	
EndProcedure

#EndRegion 

#EndRegion 

#Region FormCommandHandlers

&AtClient
Procedure SaveSettings(Command)
	
	If IsBlankString(TrimAll(Presentation)) 
		OR (Not ValueIsFilled(Indicator) 
			OR Not ValueIsFilled(Resource)) 
		AND Items.SettingsGroup.Visible Then
		
		Return;
		
	EndIf; 
	
	Result = New Structure;
	Result.Insert("Event", "IndicatorSetting");
	
	If RowID >= 0 Then
		Result.Insert("RowID", RowID);
	EndIf;
	
	Result.Insert("Indicator",		Indicator);
	Result.Insert("Resource",		Resource);
	Result.Insert("Presentation",	Presentation);
	Result.Insert("Filters",		Filters);
	
	If TypeOf(Settings) = Type("FixedArray") Then
		For Each Item In Settings Do
			Item.Value = ThisForm[Item.Name];
		EndDo; 
	EndIf; 
	
	Result.Insert("Settings", Settings);
	NotifyChoice(Result);
	
EndProcedure

&AtClient
Procedure CancelSetting(Command)	
	Close();	
EndProcedure

&AtClient
Procedure AddFilter(Command)
	
	OpeningStructure = New Structure;
	OpeningStructure.Insert("SchemaURL", SchemaURL);
	OpeningStructure.Insert("Filters", Filters);

	OpenForm("DataProcessor.BusinessPulse.Form.FilterAdditionForm", OpeningStructure, ThisForm);
	
EndProcedure

#EndRegion 

#Region InternalProceduresAndFunctions

&AtClient
Procedure FillInSelectionListResources()
	
	FilterStructure = New Structure;
	FilterStructure.Insert("Indicator", Indicator);
	Rows = IndicatorSettings.FindRows(FilterStructure);
	
	Items.Resource.ChoiceList.Clear();
	
	For Each Str In Rows Do
		Items.Resource.ChoiceList.Add(Str.Resource, Str.ResourcePresentation);
	EndDo; 
	
EndProcedure

&AtServer
Procedure WhenChangingResourceIndicatorServer()
	
	Filters = New FixedArray(New Array);
	Settings = New FixedArray(New Array);
	
	UpdateComposerParameters();
	UpdateFilterMarkDisplay();
	UpdateSettingDisplay();
	SetSettingFieldVisibility();
	
EndProcedure

&AtServer
Procedure SetSettingFieldVisibility()
	
	Items.Indicator.Enabled	= RowID < 0;
	Items.Resource.Visible	= ValueIsFilled(Indicator);
	Items.AddFilter.Visible = ValueIsFilled(Indicator) AND ValueIsFilled(Resource);
	
EndProcedure

&AtServer
Procedure UpdateComposerParameters()
	
	If IsBlankString(Indicator) OR IsBlankString(Resource) Then
		Return;
	EndIf;
	
	FilterStructure = New Structure;
	FilterStructure.Insert("Indicator", Indicator);
	FilterStructure.Insert("Resource", Resource);
	IndicatorLines = IndicatorSettings.FindRows(FilterStructure);
	
	If IndicatorLines.Count() = 0 Then
		Return;
	EndIf;
	
	TemplateName = IndicatorLines[0].TemplateName;
	BalanceMode = IndicatorLines[0].Balance;
	
	If Metadata.DataProcessors.BusinessPulse.Templates.Find(TemplateName) = Undefined Then
		Return;
	EndIf; 
	
	DataCompositionSchema	= DataProcessors.BusinessPulse.GetTemplate(TemplateName);
	SchemaURL				= PutToTempStorage(DataCompositionSchema, UUID);
	SettingsSource			= New DataCompositionAvailableSettingsSource(SchemaURL);
	
	Composer.Initialize(SettingsSource);
	Composer.LoadSettings(DataCompositionSchema.DefaultSettings);
	
	SettingsArray = New Array(Settings);
	SettingsArray.Clear();
	
	Settings = New FixedArray(SettingsArray);
	
EndProcedure

&AtClient
Procedure GeneratePresentation()
	
	Presentation = "";
	
	Item = Items.Indicator.ChoiceList.FindByValue(Indicator);
	If Not Item = Undefined Then
		Presentation = Presentation + Item.Presentation;
	EndIf;
	
	Item = Items.Resource.ChoiceList.FindByValue(Resource);
	If Not Item = Undefined Then
		Presentation = Presentation + ?(IsBlankString(Presentation), "", " - ") + Item.Presentation;
	EndIf;
	
EndProcedure

&AtServer
Procedure MergeFiltersServer(SelectedValue)
	
	FiltersArray = New Array(Filters);
	AvailableField = Composer.Settings.FilterAvailableFields.FindField(New DataCompositionField(SelectedValue.Field));
	
	DataProcessors.BusinessPulse.MergeFilters(FiltersArray, 
		SelectedValue.Field, 
		SelectedValue.ComparisonType, 
		SelectedValue.Value, 
		?(AvailableField = Undefined, "", AvailableField.Title));
	
	Filters = New FixedArray(FiltersArray);
	UpdateFilterMarkDisplay();
	
EndProcedure

#Region AppliedFilters

&AtServer
Procedure FillInAppliedFilterTable()
	
	AppliedFilters.Clear();
	
	FilterStructure = New Structure;
	FilterStructure.Insert("Indicator", Indicator);
	FilterStructure.Insert("Resource", Resource);
	Rows = IndicatorSettings.FindRows(FilterStructure);
	
	If Rows.Count() = 0 Then
		Return;
	EndIf;
	
	TemplateName = Rows[0].TemplateName;
	If Metadata.DataProcessors.BusinessPulse.Templates.Find(TemplateName) = Undefined Then
		Return;
	EndIf; 
	
	DCSchema = DataProcessors.BusinessPulse.GetTemplate(TemplateName);
	
	For Each ItemFilter In Filters Do
		
		If Not ItemFilter.Property("Presentation") Then
			ItemFilter.Insert("Presentation", "");
		EndIf;
		
		If Not ItemFilter.Property("ComparisonType") Then
			ItemFilter.Insert("ComparisonType", Undefined);
		EndIf; 
		
		FieldName = ItemFilter.Field;
		AvailableField = Composer.Settings.FilterAvailableFields.FindField(New DataCompositionField(FieldName));
		
		If ItemFilter.ComparisonType = DataCompositionComparisonType.GreaterOrEqual 
			OR ItemFilter.ComparisonType = DataCompositionComparisonType.Greater
			OR ItemFilter.ComparisonType = DataCompositionComparisonType.LessOrEqual
			OR ItemFilter.ComparisonType = DataCompositionComparisonType.Less Then
			
			FilterStructure = New Structure;
			FilterStructure.Insert("Field", FieldName);
			FilterLines = AppliedFilters.FindRows(FilterStructure);
			
			If FilterLines.Count() = 0 Then
				Str = AppliedFilters.Add();
				
				If AvailableField.ValueType.ContainsType(Type("Date")) Then
					Str.Value = New StandardPeriod;
				Else
					Str.Value = New Structure("ValueFrom,ValueTo",0,0);
				EndIf; 
			Else
				Str = FilterLines[0];
			EndIf;
			
		Else
			Str = AppliedFilters.Add();
		EndIf; 
		
		Str.Field = FieldName;
		Str.Title = ?(IsBlankString(ItemFilter.Presentation), AvailableField.Title, ItemFilter.Presentation);
		
		If ItemFilter.ComparisonType = DataCompositionComparisonType.NotEqual 
			OR ItemFilter.ComparisonType = DataCompositionComparisonType.NotInList 
			OR ItemFilter.ComparisonType = DataCompositionComparisonType.NotInHierarchy
			OR ItemFilter.ComparisonType = DataCompositionComparisonType.NotInListByHierarchy Then
				Str.ShowsExclusion = True;
		EndIf; 
		
		If ItemFilter.ComparisonType = DataCompositionComparisonType.GreaterOrEqual 
			OR ItemFilter.ComparisonType = DataCompositionComparisonType.Greater Then
			
			If TypeOf(Str.Value) = Type("StandardPeriod") Then
				Str.Value.StartDate = BegOfDay(ItemFilter.Value);
			Else
				Str.Value.ValueFrom = Max(ItemFilter.Value, Str.Value.ValueFrom);
			EndIf; 
			
		ElsIf ItemFilter.ComparisonType=DataCompositionComparisonType.LessOrEqual 
			OR ItemFilter.ComparisonType=DataCompositionComparisonType.Less Then
			
			If TypeOf(Str.Value) = Type("StandardPeriod") Then
				Str.Value.EndDate = ?(Not ValueIsFilled(ItemFilter.Value), ItemFilter.Value, EndOfDay(ItemFilter.Value));
			Else
				Str.Value.ValueTo = ?(Str.Value.ValueTo=0, ItemFilter.Value, Min(ItemFilter.Value, Str.Value.ValueTo));
			EndIf; 
			
		ElsIf TypeOf(ItemFilter.Value) = Type("ValueList") Then
			
			For Each ListItem In ItemFilter.Value Do
				If ValueIsFilled(Str.Value) Then
					
					NewRow = AppliedFilters.Add();
					FillPropertyValues(NewRow, Str);
					
					NewRow.Value = ListItem.Value;
					Str = NewRow;
					
				Else
					Str.Value = ListItem.Value;
				EndIf; 
			EndDo; 
			
		Else
		    Str.Value = ItemFilter.Value;
		EndIf;
		
	EndDo;
	
	For Each Str In AppliedFilters Do
		
		If IsBlankString(Str.ButtonName) Then
			Str.ButtonName = "FilterMark" + StrReplace(String(New UUID), "-", "");;
		EndIf;
		
		If Not ValueIsFilled(Str.Value) OR IsBlankString(Str.Field) Then
			Continue;
		EndIf; 
		
		FilterTitle = Str.Title;
		Prefix = "";
		
		If TypeOf(Str.Value) = Type("StandardPeriod") Then
			ValuePresentation = PeriodPresentation(Str.Value.StartDate, Str.Value.EndDate);
			Prefix = LastTitlePart(FilterTitle);
		ElsIf TypeOf(Str.Value) = Type("Structure") Then
			ValuePresentation = Format(Str.Value.ValueFrom, "NZ = '0'") + " - " + Format(Str.Value.ValueTo, "NZ = '...'");
			Prefix = LastTitlePart(FilterTitle);
		ElsIf CommonUse.IsReference(TypeOf(Str.Value)) Then
			ValuePresentation = String(Str.Value);
		ElsIf TypeOf(Str.Value) = Type("Boolean") Then
			SchemeField = SchemeField(DCSchema, Str.Field);
			
			If SchemeField <> Undefined Then
				Parameter = SchemeField.EditParameters.FindParameterValue(New DataCompositionParameter("EditFormat"));
				If Not Parameter = Undefined 
					AND Parameter.Use 
					AND ValueIsFilled(Parameter.Value) Then
					
					ValuePresentation = Format(Str.Value, Parameter.Value);
					Prefix = "";
					
				Else
					ValuePresentation = String(Str.Value);
					Prefix = LastTitlePart(FilterTitle);
				EndIf; 
				
			Else
				ValuePresentation = String(Str.Value);
				Prefix = LastTitlePart(FilterTitle);
			EndIf; 
			
		Else
			ValuePresentation = String(Str.Value);
			Prefix = LastTitlePart(FilterTitle);
		EndIf;
		
		Str.Title = ?(IsBlankString(Prefix), "", Prefix + ": ") + ValuePresentation;
		
	EndDo;
	
EndProcedure

&AtClient
Function AppliedFilterLine(ButtonName)
	
	SearchStructure = New Structure;
	SearchStructure.Insert("ButtonName", ButtonName);
	
	Rows = AppliedFilters.FindRows(SearchStructure);
	If Rows.Count() = 0 Then
		Return Undefined;
	Else
		Return Rows[0];
	EndIf; 
	
EndFunction

&AtServerNoContext
Function SchemeField(Schema, Field)
	
	FieldName = String(Field);
	For Each Set In Schema.DataSets Do
		SchemeField = Set.Fields.Find(FieldName);
		
		If Not SchemeField = Undefined Then
			Return SchemeField;
		EndIf;  
	EndDo;
	
	Return Undefined;
	
EndFunction

&AtServer
Procedure UpdateFilterMarkDisplay()
	
	FillInAppliedFilterTable();
	
	ArrayToDelete = New Array;
	
	FilterMarkGroup = Items.FilterMarkGroup;
	For Each Item In FilterMarkGroup.ChildItems Do
		ArrayToDelete.Add(Item);
	EndDo; 
	
	For Each Item In ArrayToDelete Do
		Items.Delete(Item);
	EndDo;
	
	For Each Str In AppliedFilters Do
		
		ItemMark = Items.Add(Str.ButtonName, Type("FormDecoration"), FilterMarkGroup);
		
		TitleItems = New Array;
		
		If StrLen(Str.Title) > 60 Then
			TitleItems.Add(Left(Str.Title, 58)+"...");
			ItemMark.Tooltip = Str.Title;
		Else
			TitleItems.Add(Str.Title);
		EndIf; 
		
		TitleItems.Add(New FormattedString(PictureLib.Clear,,,, Str.ButtonName));
		
		ItemMark.Type	= FormDecorationType.Label;
		ItemMark.Title	= New FormattedString(TitleItems);
		ItemMark.Border	= New Border(ControlBorderType.Single, 1);
		
		If Str.ShowsExclusion Then
			ItemMark.BorderColor = WebColors.Red;
		EndIf; 
		
		ItemMark.HorizontalAlign	= ItemHorizontalLocation.Center;
		ItemMark.BackColor			= StyleColors.FormBackColor;
		ItemMark.Height				= 1;
		ItemMark.HorizontalStretch	= True;
		ItemMark.AutoMaxWidth		= False;
		ItemMark.MaxWidth			= 50;
		
		ItemMark.SetAction("URLProcessing", "Attachable_DeleteFilterClick");
		
	EndDo;  
		
EndProcedure

&AtServer
Procedure UpdateSettingDisplay()
	
	AttributeArray = New Array;
	ArrayToDelete = New Array;
	
	For Each Item In Items.SettingsGroup.ChildItems Do
		ArrayToDelete.Add(Item);
		AttributeArray.Add(Item.DataPath);
	EndDo;
	
	For Each Item In ArrayToDelete Do
		Items.Delete(Item);
	EndDo;
	
	ChangeAttributes(, AttributeArray);
	
	AttributeArray = New Array;
	For Each Item In Settings Do
		AttributeArray.Add(New FormAttribute(Item.Name, New TypeDescription("Boolean"),, Item.Title));
	EndDo; 
	
	ChangeAttributes(AttributeArray);
	
	For Each Item In Settings Do
		
		SettingsGroup = Items.SettingsGroup;
		
		FormItem = Items.Add(Item.Name, Type("FormField"), SettingsGroup);
		FormItem.DataPath	= Item.Name;
		FormItem.Type		= FormFieldType.CheckBoxField;
		ThisForm[Item.Name]	= Item.Value;
		
	EndDo; 
	
EndProcedure

&AtServerNoContext
Function LastTitlePart(Title)
	
	Result		= Title;
	Position	= Find(Result, ".");
	
	While Position > 0 Do
		Result = Mid(Result, Position + 1);
		Position = Find(Result, ".");
	EndDo;
	
	Return Result;
	
EndFunction

#EndRegion 

#EndRegion
 