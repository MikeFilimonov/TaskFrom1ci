
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	ComplCurrencyCharacter = CommonUse.ObjectAttributeValue(DriveReUse.GetAccountCurrency(), "Description");
	
	Parameters.Property("Chart",			Chart);	
	Parameters.Property("Series",			Series);
	Parameters.Property("Point",			Point);
	Parameters.Property("Presentation",		Presentation);
	Parameters.Property("Period",			Period);
	Parameters.Property("ComparisonPeriod",	ComparisonPeriod);
	
	Parameters.Property("Filters",			Filters);	
	If Filters = Undefined Then
		Filters = New FixedArray(New Array);
	EndIf; 
	
	Parameters.Property("Settings",			Settings);
	If Settings = Undefined Then
		Settings = New FixedArray(New Array);
	EndIf; 
	
	If Parameters.Property("RowID") Then
		RowID = Parameters.RowID;
		Title = NStr("en = 'Chart setting'");
	Else
		RowID = -1;
		Title = NStr("en = 'Add chart'");
	EndIf; 
	
	If Parameters.Property("ChartSettingAddress") AND IsTempStorageURL(Parameters.ChartSettingAddress) Then
		ChartSettings.Load(GetFromTempStorage(Parameters.ChartSettingAddress));
	EndIf; 
	
	Tab = ChartSettings.Unload(, "Chart, Presentation");
	Tab.GroupBy("Chart, Presentation");
	Items.Chart.ChoiceList.Clear();
	
	For Each Str In Tab Do
		Items.Chart.ChoiceList.Add(Str.Chart, Str.Presentation);
	EndDo;
	
	SetSettingVisibility();
	
	If ValueIsFilled(Chart) Then
		UpdateComposerParameters();
	EndIf;
	
	SetPeriodFieldProperties();
	
	If Not RowID = -1 Then		
		UpdateFilterMarkDisplay();
		UpdateSettingDisplay();
		CurrentItem = Items.Series;	
	EndIf; 
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If ValueIsFilled(Chart) Then
		FillInSelectionListSeriesPoints();
	EndIf;
	// Update values after filling in the selection list;
	Series = Series;
	Point = Point;
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(SelectedValue, ChoiceSource)
	
	If Not TypeOf(SelectedValue) = Type("Structure") Then
		Return;
	EndIf;
	
	If SelectedValue.Event="AddFilter" Then
		MergeFiltersServer(SelectedValue);
	EndIf; 
	
EndProcedure

#EndRegion 

#Region FormsItemEventHandlers

&AtClient
Procedure ChartOnChange(Item)
	
	FillInSelectionListSeriesPoints();
	
	If Items.Series.ChoiceList.Count() > 0 Then
		Series = Items.Series.ChoiceList[0].Value;
	Else
		Series = "";
	EndIf;
	
	If Items.Point.ChoiceList.Count() > 0 Then
		Point = Items.Point.ChoiceList[0].Value;
	Else
		Point = "";
	EndIf;
	
	WhenChangingChartServer();
	GeneratePresentation();
	
EndProcedure

&AtClient
Procedure SeriesOnChange(Item)
	
	UpdatePointSelectionList();
	WhenChangingSeriesServer();
	GeneratePresentation();
	
EndProcedure

&AtClient
Procedure PointOnChange(Item)
	
	WhenChangingPointServer();
	GeneratePresentation()
	
EndProcedure

&AtClient
Procedure PeriodPresentationClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	SelectPeriodStart(Item);
	
EndProcedure

&AtClient
Procedure ComparisonPeriodPresentationClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	SelectPeriodStart(Item);
	
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
	
	ArrayToDelete = New Array;
	
	FiltersArray = New Array(Filters);
	For Each Filter In FiltersArray Do
		
		If Not AppliedFilterStr.Field = Filter.Field Then
			Continue;
		EndIf;
		
		If TypeOf(Filter.Value) = Type("ValueList") Then
			
			Item = Filter.Value.FindByValue(AppliedFilterStr.Value);
			
			If Not Item = Undefined Then
				Filter.Value.Delete(Item);
			EndIf;
			
			If Filter.Value.Count() = 0 Then
				ArrayToDelete.Add(Filter);
			EndIf;
			
		ElsIf TypeOf(Filter.Value)=Type("Date") Then
			
			If Filter.ComparisonType = DataCompositionComparisonType.Less 
				OR Filter.ComparisonType=DataCompositionComparisonType.LessOrEqual Then
				
				ComparisonValue = New StandardPeriod('0001-01-01', Filter.Value);
				
			ElsIf Filter.ComparisonType = DataCompositionComparisonType.Greater 
				OR Filter.ComparisonType = DataCompositionComparisonType.GreaterOrEqual Then
					
				ComparisonValue = New StandardPeriod(Filter.Value, '0001-01-01');
				
			EndIf;
			
			If AppliedFilterStr.Value=ComparisonValue Then
				ArrayToDelete.Add(Filter);
			EndIf;
			
		ElsIf TypeOf(Filter.Value)=Type("Number") Then
			
			If (Filter.ComparisonType = DataCompositionComparisonType.Less 
					OR Filter.ComparisonType = DataCompositionComparisonType.LessOrEqual)
				AND AppliedFilterStr.Value.ValueTo = Filter.Value Then
				
				ArrayToDelete.Add(Filter);
				
			ElsIf (Filter.ComparisonType = DataCompositionComparisonType.Greater 
					OR Filter.ComparisonType = DataCompositionComparisonType.GreaterOrEqual)
				AND AppliedFilterStr.Value.ValueFrom = Filter.Value  Then
				
				ArrayToDelete.Add(Filter);
				
			EndIf;
			
		ElsIf Filter.Value = AppliedFilterStr.Value Then 
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
		OR Not ValueIsFilled(Chart) 
		OR Not ValueIsFilled(Series)
		OR Not ValueIsFilled(Point) Then
			Return;
	EndIf; 
	
	// ID connection with the chart options table
	FilterStructure = New Structure;
	FilterStructure.Insert("Chart", Chart);
	
	Rows				= ChartSettings.FindRows(FilterStructure);
	SettingPage			= Rows[0];
	SeriesDescription	= SettingPage.Series[Series];
	PointDescription	= SettingPage.Points[Point];
	
	Result = New Structure;
	Result.Insert("Event", "ChartSetting");
	If RowID >= 0 Then
		Result.Insert("RowID", RowID);
	EndIf;
	
	Result.Insert("Chart",				Chart);
	Result.Insert("Series",				Series);
	Result.Insert("Point",				Point);
	Result.Insert("Period",				Period);
	Result.Insert("ComparisonPeriod",	ComparisonPeriod);
	Result.Insert("Presentation",		Presentation);
	Result.Insert("BalanceMode",		BalanceMode);
	
	FiltersArray = New Array(Filters);
	
	If ValueIsFilled(SeriesDescription.RequiredFilters) Then
		
		Cancel = False;
		
		For Each FilterDescription In SeriesDescription.RequiredFilters Do
			FilterValue = ThisObject["ChartSetting_" + FilterDescription.Key];
			AvailableField = Composer.Settings.FilterAvailableFields.FindField(New DataCompositionField(FilterDescription.Key));
			
			If Not ValueIsFilled(FilterValue) Then
				Status(NStr("en = 'Required filter is not specified:'") + " " + ?(AvailableField = Undefined, FilterDescription.Key, AvailableField.Title));
				Cancel = True;
			EndIf;
			
			FilterStructure = New Structure;
			FilterStructure.Insert("Field",				FilterDescription.Key);
			FilterStructure.Insert("Value",				FilterValue);
			FilterStructure.Insert("ComparisonType",	DataCompositionComparisonType.Equal);
			FilterStructure.Insert("Presentation",		AvailableField.Title);
			
			FiltersArray.Insert(0, FilterStructure);
		EndDo;
		
		If Cancel Then
			Return;
		EndIf;
	EndIf;
	
	Filters = New FixedArray(FiltersArray);
	Result.Insert("Filters", Filters);
	
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

&AtServer
Procedure SetSettingVisibility()
	
	Items.Chart.Enabled		= RowID < 0;
	Items.Series.Visible	= ValueIsFilled(Chart);
	Items.Point.Visible		= ValueIsFilled(Chart);
	
	SettingsPopulated = ValueIsFilled(Chart) AND ValueIsFilled(Series) AND ValueIsFilled(Point);
	
	Items.PeriodPresentation.Visible			= SettingsPopulated;
	Items.ComparisonPeriodPresentation.Visible	= SettingsPopulated;
	Items.AddFilter.Visible						= SettingsPopulated;
	
	If ValueIsFilled(Chart) Then
		UpdateComposerParameters();
		SetPeriodFieldProperties();
	EndIf;
	
	If ValueIsFilled(Chart) Then
		
		FilterStructure = New Structure;
		FilterStructure.Insert("Chart", Chart);
		
		SettingLines = ChartSettings.FindRows(FilterStructure);
		SettingPage = SettingLines[0];
		If SettingPage.ProhibitComparison Then
			Items.ComparisonPeriodPresentation.Visible = False;
		EndIf; 
		
		If ValueIsFilled(Series) Then
			
			SeriesSettings = SettingPage.Series[Series];
			
			If SeriesSettings.ChartType=ChartType.Pie 
				OR SeriesSettings.ChartType=ChartType.Pie3D Then
				
				Items.Series.Title = NStr("en = 'Indicator'");
				Items.Point.Title = NStr("en = 'Values'");
				Items.ComparisonPeriodPresentation.Visible = False;
				
			ElsIf SeriesSettings.ChartType=ChartType.StackedColumn 
				OR SeriesSettings.ChartType=ChartType.StackedColumn3D Then
				
				Items.Series.Title = NStr("en = 'Vertical'");
				Items.Point.Title = NStr("en = 'Horizontal'");
				Items.ComparisonPeriodPresentation.Visible = False;
				
			Else
				Items.Series.Title = NStr("en = 'Vertical'");
				Items.Point.Title = NStr("en = 'Horizontal'");
			EndIf; 
		EndIf; 
	EndIf; 
	
EndProcedure

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
	
	SeriesDescription = Undefined;
	If Not IsBlankString(Chart) AND Not IsBlankString(Series) Then
		FilterStructure = New Structure;
		FilterStructure.Insert("Chart", Chart);
		
		Rows = ChartSettings.FindRows(FilterStructure);
		If Rows.Count() > 0 Then
			SettingPage = Rows[0];
			SeriesDescription = SettingPage.Series[Series];
		EndIf; 
	EndIf; 
	
	For Each Str In AppliedFilters Do
		
		If Not SeriesDescription = Undefined AND Not SeriesDescription.RequiredFilters = Undefined Then
			
			Ignore = False;
			
			For Each RequiredFilter In SeriesDescription.RequiredFilters Do
				If Str.Field = RequiredFilter.Key Then
					Ignore = True;
					Break;
				EndIf; 
			EndDo;
			
			If Ignore Then
				Continue;
			EndIf; 
			
		EndIf; 
		
		ItemMark = Items.Add(Str.ButtonName, Type("FormDecoration"), FilterMarkGroup);
		
		TitleItems = New Array;
		
		If StrLen(Str.Title)>60 Then
			TitleItems.Add(Left(Str.Title, 58) + "...");
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
	
	AttributesToDeleteArray	= New Array;
	AttributesToAddArray	= New Array;
	ArrayToDelete			= New Array;
	
	For Each Item In Items.SettingsGroup.ChildItems Do
		ArrayToDelete.Add(Item);
		
		If Not TypeOf(Item) = Type("FormField") Then
			Continue;
		EndIf;
		
		AttributesToDeleteArray.Add(Item.DataPath);
	EndDo;
	
	For Each Item In ArrayToDelete Do
		Items.Delete(Item);
	EndDo; 
	
	For Each Item In Settings Do
		AttributesToAddArray.Add(New FormAttribute(Item.Name, New TypeDescription("Boolean"),, Item.Title));
	EndDo;
	
	SeriesDescription = Undefined;
	
	If Not IsBlankString(Chart) AND Not IsBlankString(Series) Then
		FilterStructure = New Structure;
		FilterStructure.Insert("Chart", Chart);
		
		Rows = ChartSettings.FindRows(FilterStructure);
		If Rows.Count() > 0 Then
			
			SettingPage = Rows[0];
			SeriesDescription = SettingPage.Series[Series];
			
			If ValueIsFilled(SeriesDescription.RequiredFilters) Then
				AttributeArray = New Array;
				
				For Each FilterDescription In SeriesDescription.RequiredFilters Do
					Field = Composer.Settings.FilterAvailableFields.FindField(New DataCompositionField(FilterDescription.Key));
					AttributeName = "ChartSetting_" + FilterDescription.Key;
					AttributesToAddArray.Add(New FormAttribute(AttributeName, Field.ValueType,, Field.Title));
				EndDo;
				
			EndIf;
		EndIf; 
	EndIf; 
	
	ChangeAttributes(AttributesToAddArray, AttributesToDeleteArray);
	
	For Each Item In Settings Do
		SettingsGroup = Items.SettingsGroup;
		
		FormItem			= Items.Add(Item.Name, Type("FormField"), SettingsGroup);
		FormItem.DataPath	= Item.Name;
		FormItem.Type		= FormFieldType.CheckBoxField;
		ThisForm[Item.Name]	= Item.Value;
	EndDo; 
	
	If Not SeriesDescription = Undefined AND ValueIsFilled(SeriesDescription.RequiredFilters) Then
		FiltersArray = New Array(Filters);
		
		For Each FilterDescription In SeriesDescription.RequiredFilters Do
			AttributeName = "ChartSetting_" + FilterDescription.Key;
			
			Item					= Items.Add(AttributeName, Type("FormField"), Items.SettingsGroup);
			Item.DataPath			= AttributeName;
			Item.Type				= FormFieldType.InputField;
			Item.OpenButton			= False;
			Item.AutoMarkIncomplete	= True;
			
			For Each FilterStructure In FiltersArray Do
				If FilterStructure.Field = FilterDescription.Key AND Not TypeOf(FilterStructure.Value) = Type("Array") Then
					ThisObject[AttributeName] = FilterStructure.Value;
					FiltersArray.Delete(FiltersArray.Find(FilterStructure));
					Break;
				EndIf; 
			EndDo; 
			
			ParameterArray = New Array;
			
			If TypeOf(FilterDescription.Value)=Type("Map") Then
				For Each SelectionParameterDescription In FilterDescription.Value Do
					
					If SelectionParameterDescription.Key = "FieldParameters" Then
						For Each PropertyDetails In SelectionParameterDescription.Value Do
							Item[PropertyDetails.Key] = PropertyDetails.Value;
						EndDo; 
					Else
						ChoiceParameter = New ChoiceParameter(
							SelectionParameterDescription.Key, 
							?(TypeOf(SelectionParameterDescription.Value) = Type("Array"), 
								New FixedArray(SelectionParameterDescription.Value), 
								SelectionParameterDescription.Value));
						ParameterArray.Add(ChoiceParameter);
					EndIf; 
					
				EndDo;
			EndIf;
			
			Item.ChoiceParameters = New FixedArray(ParameterArray);
			
		EndDo;
		
		Filters = New FixedArray(FiltersArray);
		
	EndIf; 
	
EndProcedure

&AtServer
Procedure UpdateComposerParameters()
	
	If IsBlankString(Chart) Then
		Return;
	EndIf;
	
	FilterStructure = New Structure;
	FilterStructure.Insert("Chart", Chart);
	
	ChartLines = ChartSettings.FindRows(FilterStructure);
	If ChartLines.Count() = 0 Then
		Return;
	EndIf;
	
	TemplateName = ChartLines[0].TemplateName;
	If Not IsBlankString(Series) Then
		BalanceMode = ChartLines[0].Balance;
	Else
		BalanceMode = False;
	EndIf; 
	
	If Metadata.DataProcessors.BusinessPulse.Templates.Find(TemplateName)=Undefined Then
		Return;
	EndIf; 
	
	DataCompositionSchema	= DataProcessors.BusinessPulse.GetTemplate(TemplateName);
	SchemaURL				= PutToTempStorage(DataCompositionSchema, UUID);
	SettingsSource			= New DataCompositionAvailableSettingsSource(SchemaURL);
	Composer.Initialize(SettingsSource);
	Composer.LoadSettings(DataCompositionSchema.DefaultSettings);
	
	SettingsArray = New Array(Settings);
	SettingsArray.Clear();
	// Feature for adding additional chart settings
	Settings = New FixedArray(SettingsArray);
	
EndProcedure
 
&AtClient
Procedure GeneratePresentation()
	
	Presentation = "";
	
	If IsBlankString(Chart) OR IsBlankString(Series) Then
		Return;
	EndIf;
	
	FilterStructure = New Structure;
	FilterStructure.Insert("Chart", Chart);
	
	Rows = ChartSettings.FindRows(FilterStructure);
	For Each Str In Rows Do
		Presentation = Str.Presentation;
		SeriesDescription = Str.Series[Series];
		If SeriesDescription.Currency Then
			Presentation = Presentation + ", " + ComplCurrencyCharacter;
		EndIf;  
	EndDo; 
	
	If BalanceMode Then
		If ValueIsFilled(Period) AND Not Period.Variant = StandardBeginningDateVariant.BeginningOfNextDay Then
			Presentation = Presentation + " (" + StandardStartDatePresentation(Period) + ")";
		EndIf; 
	Else
		If ValueIsFilled(Period) Then
			Presentation = Presentation + " (" + StandardPeriodPresentation(Period) + ")";
		EndIf; 
	EndIf; 
	
EndProcedure

&AtClient
Procedure FillInSelectionListSeriesPoints()
	
	FilterStructure = New Structure;
	FilterStructure.Insert("Chart", Chart);
	
	Rows = ChartSettings.FindRows(FilterStructure);
	Items.Series.ChoiceList.Clear();
	Items.Point.ChoiceList.Clear();
	
	For Each Str In Rows Do
		For Each Item In Str.Series Do
			If Item.Value.Presentations.Count()>1 Then
				SeriesPresentation = Item.Value.Title;
			Else
				SeriesPresentation = Item.Value.Presentations[0];
			EndIf; 
			Items.Series.ChoiceList.Add(Item.Key, SeriesPresentation);
		EndDo;
		
		For Each Item In Str.Points Do
			Items.Point.ChoiceList.Add(Item.Key, Item.Value.Presentations[0]);
		EndDo; 
	EndDo;
	
	Items.Series.Enabled	= Items.Series.ChoiceList.Count() > 1;
	Items.Point.Enabled		= Items.Point.ChoiceList.Count() > 1;
	
EndProcedure

&AtClient
Procedure UpdatePointSelectionList()
	
	If IsBlankString(Chart) OR IsBlankString(Series) Then
		Return;
	EndIf;
	
	Items.Point.ChoiceList.Clear();
	FilterStructure = New Structure;
	FilterStructure.Insert("Chart", Chart);
	
	Rows = ChartSettings.FindRows(FilterStructure);
	For Each Str In Rows Do
		ItemSeries = Str.Series[Series];
		
		If IsBlankString(ItemSeries.AvailableSeriesPoints) Then
			For Each Item In Str.Points Do
				Items.Point.ChoiceList.Add(Item.Key, Item.Value.Presentations[0]);
			EndDo; 
		Else
			PointArray = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(ItemSeries.AvailableSeriesPoints);
			For Each PointName In PointArray Do
				PointItem = Str.Points[PointName];
				Items.Point.ChoiceList.Add(PointName, PointItem.Presentations[0]);
			EndDo; 
		EndIf;
		
		If Items.Point.ChoiceList.Count() = 0 Then
			Point = "";
			Continue;
		EndIf; 
		
		If Items.Point.ChoiceList.FindByValue(Point) = Undefined Then
			Point = Items.Point.ChoiceList[0].Value;
		EndIf; 
	EndDo; 
	
EndProcedure

&AtServer
Procedure WhenChangingChartServer()	
	WhenChangingChartSeriesPointServer();	
EndProcedure
 
&AtServer
Procedure WhenChangingSeriesServer()	
	WhenChangingChartSeriesPointServer();	
EndProcedure
 
&AtServer
Procedure WhenChangingPointServer()	
	WhenChangingChartSeriesPointServer();	
EndProcedure
 
&AtServer
Procedure WhenChangingChartSeriesPointServer()
	
	Filters = New FixedArray(New Array);
	Settings = New FixedArray(New Array);
	UpdateFilterMarkDisplay();
	UpdateSettingDisplay();
	
	SetSettingVisibility();
	
EndProcedure

&AtServer
Procedure MergeFiltersServer(SelectedValue)
	
	FiltersArray = New Array(Filters);
	AvailableField = Composer.Settings.FilterAvailableFields.FindField(New DataCompositionField(SelectedValue.Field));
	
	DataProcessors.BusinessPulse.MergeFilters(FiltersArray, 
		SelectedValue.Field, 
		SelectedValue.ComparisonType, 
		SelectedValue.Value, 
		?(AvailableField=Undefined, "", AvailableField.Title));
	
	Filters = New FixedArray(FiltersArray);
	UpdateFilterMarkDisplay();
	
EndProcedure

#Region Periods

&AtServer
Procedure SetPeriodFieldProperties()
	
	If BalanceMode AND Not TypeOf(Period) = Type("StandardBeginningDate") Then
		
		Period = New StandardBeginningDate(StandardBeginningDateVariant.Custom);
		ComparisonPeriod = New StandardBeginningDate(StandardBeginningDateVariant.Custom);
		
	ElsIf Not BalanceMode 
		AND Not TypeOf(Period) = Type("StandardPeriod") 
		AND Not TypeOf(Period) = Type("Structure") Then
		
		Period = New StandardPeriod(StandardPeriodVariant.Custom);
		ComparisonPeriod = New StandardPeriod(StandardPeriodVariant.Custom);
		
	EndIf; 
	
	If BalanceMode Then
		
		If Not ValueIsFilled(Period) Then
			Period = New StandardBeginningDate(StandardBeginningDateVariant.BeginningOfNextDay);
		EndIf; 
		
		Items.PeriodPresentation.Title = NStr("en = 'As of'");
		PeriodPresentation = StandardStartDatePresentation(Period);
		ComparisonPeriodPresentation = StandardStartDatePresentation(ComparisonPeriod);
		
	Else
		
		If Not ValueIsFilled(Period) Then
			Period = New StandardPeriod(StandardPeriodVariant.Today);
		EndIf;
		
		Items.PeriodPresentation.Title = NStr("en = 'Period'");
		PeriodPresentation = StandardPeriodPresentation(Period);
		ComparisonPeriodPresentation = StandardPeriodPresentation(ComparisonPeriod);
		
	EndIf; 
	
EndProcedure

&AtClient
Procedure SelectPeriodStart(Item)
	
	ChoiceData = New ValueList;
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("Item", Item);
	If BalanceMode Then
		
		If Item = Items.PeriodPresentation Then
			// Slice date
			CalculationPeriod = New StandardBeginningDate(StandardBeginningDateVariant.BeginningOfNextDay);
			ChoiceData.Add(CalculationPeriod, StandardStartDatePresentation(CalculationPeriod));
			CalculationPeriod = New StandardBeginningDate(StandardBeginningDateVariant.BeginningOfThisDay);
			ChoiceData.Add(CalculationPeriod, StandardStartDatePresentation(CalculationPeriod));
			ChoiceData.Add(New StandardBeginningDate(StandardBeginningDateVariant.BeginningOfThisWeek));
			ChoiceData.Add(New StandardBeginningDate(StandardBeginningDateVariant.BeginningOfThisMonth));
			ChoiceData.Add(New StandardBeginningDate(StandardBeginningDateVariant.BeginningOfThisQuarter));
			ChoiceData.Add(New StandardBeginningDate(StandardBeginningDateVariant.BeginningOfThisHalfYear));
			ChoiceData.Add(New StandardBeginningDate(StandardBeginningDateVariant.BeginningOfThisYear));
			ChoiceData.Add(New StandardBeginningDate(StandardBeginningDateVariant.Custom), NStr("en = 'Arbitrary date'"));
			
			ParametersStructure.Insert("Value", Period);
			
		ElsIf Item=Items.ComparisonPeriodPresentation Then
			// Comparison date
			ChoiceData.Add(Undefined, NStr("en = 'Do not compare'"));
			
			If Period = New StandardBeginningDate(StandardBeginningDateVariant.BeginningOfNextDay) Then
				
				CalculationPeriod = New StandardBeginningDate(StandardBeginningDateVariant.BeginningOfThisDay);
				ChoiceData.Add(Period, StandardStartDatePresentation(CalculationPeriod));
				ChoiceData.Add(New StandardBeginningDate(StandardBeginningDateVariant.BeginningOfLastDay));
				ChoiceData.Add(New StandardBeginningDate(StandardBeginningDateVariant.BeginningOfThisWeek));
				ChoiceData.Add(New StandardBeginningDate(StandardBeginningDateVariant.BeginningOfThisMonth));
				
			ElsIf Period = New StandardBeginningDate(StandardBeginningDateVariant.BeginningOfThisDay) Then
				
				ChoiceData.Add(New StandardBeginningDate(StandardBeginningDateVariant.BeginningOfLastDay));
				ChoiceData.Add(New StandardBeginningDate(StandardBeginningDateVariant.BeginningOfThisWeek));
				ChoiceData.Add(New StandardBeginningDate(StandardBeginningDateVariant.BeginningOfThisMonth));
				
			ElsIf Period = New StandardBeginningDate(StandardBeginningDateVariant.BeginningOfThisWeek) Then
				ChoiceData.Add(New StandardBeginningDate(StandardBeginningDateVariant.BeginningOfLastWeek));
			ElsIf Period = New StandardBeginningDate(StandardBeginningDateVariant.BeginningOfThisMonth) Then
				ChoiceData.Add(New StandardBeginningDate(StandardBeginningDateVariant.BeginningOfLastMonth));
			ElsIf Period = New StandardBeginningDate(StandardBeginningDateVariant.BeginningOfThisQuarter) Then
				ChoiceData.Add(New StandardBeginningDate(StandardBeginningDateVariant.BeginningOfLastQuarter));
			ElsIf Period = New StandardBeginningDate(StandardBeginningDateVariant.BeginningOfThisHalfYear) Then
				ChoiceData.Add(New StandardBeginningDate(StandardBeginningDateVariant.BeginningOfLastHalfYear));
			ElsIf Period = New StandardBeginningDate(StandardBeginningDateVariant.BeginningOfThisYear) Then
				ChoiceData.Add(New StandardBeginningDate(StandardBeginningDateVariant.BeginningOfNextYear));
			EndIf;
			
			CalculationDate = ?(Period.Variant=StandardBeginningDateVariant.BeginningOfNextDay, EndOfDay(CurrentDate()), BegOfDay(Period.Date));
			CalculationPeriod = CalculationDate-7*86400;
			PeriodStructure = New Structure("Option, Date", "SameDayLastWeek", CalculationPeriod);
			ChoiceData.Add(PeriodStructure, StandardStartDatePresentation(PeriodStructure));
			
			CalculationPeriod = AddMonth(CalculationDate, -1);
			PeriodStructure = New Structure("Option, Date", "SameDayLastMonth", CalculationPeriod);
			
			ChoiceData.Add(PeriodStructure, StandardStartDatePresentation(PeriodStructure));
			CalculationPeriod = Date(Year(CalculationDate)-1, Month(CalculationDate), Day(CalculationDate), Hour(CalculationDate), Minute(CalculationDate), Second(CalculationDate));
			PeriodStructure = New Structure("Option, Date", "SameDayLastYear", CalculationPeriod);
			
			ChoiceData.Add(PeriodStructure, StandardStartDatePresentation(PeriodStructure));
			ChoiceData.Add(New StandardBeginningDate(StandardBeginningDateVariant.Custom), NStr("en = 'Arbitrary date'"));
			ParametersStructure.Insert("Value", ComparisonPeriod);
			
		EndIf; 
	Else
		
		If Item = Items.PeriodPresentation Then
			// Period
			ChoiceData.Add(New StandardPeriod(StandardPeriodVariant.Today));
			ChoiceData.Add(New StandardPeriod(StandardPeriodVariant.FromBeginningOfThisWeek));
			ChoiceData.Add(New StandardPeriod(StandardPeriodVariant.FromBeginningOfThisMonth));
			ChoiceData.Add(New StandardPeriod(StandardPeriodVariant.FromBeginningOfThisQuarter));
			ChoiceData.Add(New StandardPeriod(StandardPeriodVariant.FromBeginningOfThisHalfYear));
			ChoiceData.Add(New StandardPeriod(StandardPeriodVariant.FromBeginningOfThisYear));
			ChoiceData.Add(New StandardPeriod(StandardPeriodVariant.Last7Days));
			ChoiceData.Add(New Structure("Variant", "Last7DaysExceptForCurrentDay"), NStr("en = 'Last 7 days except for the current day'"));
			ChoiceData.Add(New StandardPeriod(StandardPeriodVariant.Custom), NStr("en = 'Arbitrary period'"));
			ParametersStructure.Insert("Value", Period);
			
		ElsIf Item = Items.ComparisonPeriodPresentation Then
			// Comparison period
			ChoiceData.Add(Undefined, NStr("en = 'Do not compare'"));
			If TypeOf(Period) = Type("Structure") OR ValueIsFilled(Period.StartDate) Then
				CalculationPeriod = DriveClientServer.PreviousFloatingPeriod(Period);
				PeriodStructure = New Structure("Option, Period", "PreviousFloatingPeriod", CalculationPeriod);
				ChoiceData.Add(PeriodStructure, StandardPeriodPresentation(PeriodStructure));
				CalculationPeriod = DriveClientServer.SamePeriodOfLastYear(Period);
				
				If Not CalculationPeriod = Undefined Then
					PeriodStructure = New Structure("Option, Period", "ForLastYear", CalculationPeriod);
					ChoiceData.Add(PeriodStructure, StandardPeriodPresentation(PeriodStructure));
				EndIf; 
			EndIf; 
			
			ChoiceData.Add(New StandardPeriod(StandardPeriodVariant.Custom), NStr("en = 'Arbitrary period'"));
			ParametersStructure.Insert("Value", ComparisonPeriod);
			
		EndIf; 
	EndIf; 
	
	Notification = New NotifyDescription("PeriodSelectionEnd", ThisObject, ParametersStructure);
	ShowChooseFromMenu(Notification, ChoiceData, Item);
	
EndProcedure

&AtClient
Procedure PeriodSelectionEnd(SelectedValue, ParametersStructure) Export
	
	If SelectedValue = Undefined Then
		Return;
	EndIf;
	
	CalculationPeriod = SelectedValue.Value;
	If BalanceMode Then
		
		If Not ValueIsFilled(CalculationPeriod) AND Not CalculationPeriod = Undefined Then
			
			CurrentValue = ?(TypeOf(ParametersStructure.Value)=Type("StandardBeginningDate"), ParametersStructure.Value, New StandardBeginningDate);
			Notification = New NotifyDescription("SelectArbitraryPeriod", ThisObject, ParametersStructure);
			ShowInputDate(Notification, CurrentValue.Date, NStr("en = 'Specify date'"), DateFractions.Date); 
			
		ElsIf ParametersStructure.Item=Items.PeriodPresentation Then
			
			Period = CalculationPeriod;
			PeriodPresentation = StandardStartDatePresentation(CalculationPeriod);
			GeneratePresentation();
			
		Else
			ComparisonPeriod = CalculationPeriod;
			ComparisonPeriodPresentation = StandardStartDatePresentation(CalculationPeriod);
		EndIf;
		
	Else
		
		If Not ValueIsFilled(CalculationPeriod) AND Not CalculationPeriod=Undefined Then
			
			Notification = New NotifyDescription("SelectArbitraryPeriod", ThisObject, ParametersStructure);
			Dialog = New StandardPeriodEditDialog;
			Dialog.Period = ?(TypeOf(ParametersStructure.Value)=Type("StandardPeriod"), ParametersStructure.Value, New StandardPeriod);
			Dialog.Show(Notification);
			
		ElsIf ParametersStructure.Item = Items.PeriodPresentation Then
			
			Period = CalculationPeriod;
			PeriodPresentation = StandardPeriodPresentation(CalculationPeriod);
			GeneratePresentation();
			
		Else
			ComparisonPeriod = CalculationPeriod;
			ComparisonPeriodPresentation = StandardPeriodPresentation(CalculationPeriod);
		EndIf;
		
	EndIf; 
	
EndProcedure

&AtClient
Procedure SelectArbitraryPeriod(SelectedValue, ParametersStructure) Export
	
	If SelectedValue = Undefined Then
		Return;
	EndIf;
	
	If BalanceMode Then
		
		If ParametersStructure.Item = Items.PeriodPresentation Then
			
			Period = New StandardBeginningDate(SelectedValue);
			PeriodPresentation = StandardStartDatePresentation(Period);
			GeneratePresentation();
			
		Else
			ComparisonPeriod = New StandardBeginningDate(SelectedValue);
			ComparisonPeriodPresentation = StandardStartDatePresentation(ComparisonPeriod);
		EndIf;
		
	Else
		
		If ParametersStructure.Item=Items.PeriodPresentation Then
			
			Period = SelectedValue;
			PeriodPresentation = StandardPeriodPresentation(Period);
			GeneratePresentation();
			
		Else
			ComparisonPeriod = SelectedValue;
			ComparisonPeriodPresentation = StandardPeriodPresentation(ComparisonPeriod);
		EndIf;
		
	EndIf; 
	
EndProcedure
 
&AtClientAtServerNoContext
Function StandardPeriodPresentation(Period)
	
	If TypeOf(Period) = Type("Structure") Then
		Period = Period.Period;
	EndIf;
	
	If Not ValueIsFilled(Period) Then
		Return NStr("en = 'Not selected'");
	ElsIf Period.Variant = StandardPeriodVariant.Custom Then
		
		If Not ValueIsFilled(Period.StartDate) Then
			Return NStr("en = 'before'") + " " + Format(Period.EndDate, "DLF=D");
		ElsIf Not ValueIsFilled(Period.EndDate) Then
			Return NStr("en = 'Date'") + " " + Format(Period.StartDate, "DLF=D");
		Else
			
			Return PeriodPresentation(
				BegOfDay(Period.StartDate), 
				?(ValueIsFilled(Period.EndDate), 
				EndOfDay(Period.EndDate), 
				Period.EndDate)
			);
			
		EndIf; 
		
	ElsIf Period.Variant = "PreviousFloatingPeriod" Then
		
		Return NStr("en = 'Previous period ('")
			+ PeriodPresentation(BegOfDay(Period.Period.StartDate), EndOfDay(Period.Period.EndDate)) 
			+ ")";
			
	ElsIf Period.Variant = "ForLastYear" Then
			
		Return NStr("en = 'For the last year ('")
			+ PeriodPresentation(BegOfDay(Period.Period.StartDate), EndOfDay(Period.Period.EndDate))
			+ ")";
			
	ElsIf Period.Variant = "Last7DaysExceptForCurrentDay" Then
		Return NStr("en = 'Last 7 days except for the current day'");
	Else
		Return String(Period);
	EndIf; 
	
EndFunction

&AtClientAtServerNoContext
Function StandardStartDatePresentation(Period)
	
	If Not ValueIsFilled(Period) Then
		Return NStr("en = 'Not selected'");
	ElsIf Period.Variant = StandardBeginningDateVariant.Custom Then
		Return Format(Period.Date, "DLF=D");
	ElsIf Period.Variant = StandardBeginningDateVariant.BeginningOfThisDay Then
		Return NStr("en = 'Today, as of the beginning of the day'");
	ElsIf Period.Variant = StandardBeginningDateVariant.BeginningOfNextDay Then
		Return NStr("en = 'Always relevant'");
	ElsIf Period.Variant = "SameDayLastWeek" Then
		Return NStr("en = 'Same day last week ('") + Format(Period.Date, "DLF=D") + ")";
	ElsIf Period.Variant = "SameDayLastMonth" Then
		Return NStr("en = 'Same day last month ('") + Format(Period.Date, "DLF=D") + ")";
	ElsIf Period.Variant = "SameDayLastYear" Then
		Return NStr("en = 'Same day last year ('") + Format(Period.Date, "DLF=D") + ")";
	Else
		Return String(Period);
	EndIf; 
	
EndFunction

#EndRegion 

#Region AppliedFilters

&AtServer
Procedure FillInAppliedFilterTable(ThisIsChart = False)
	
	AppliedFilters.Clear();
	
	FilterStructure = New Structure;
	FilterStructure.Insert("Chart", Chart);
	
	Rows = ChartSettings.FindRows(FilterStructure);	
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
					Str.Value = New Structure("ValueFrom, ValueTo", 0, 0);
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
			
		ElsIf ItemFilter.ComparisonType = DataCompositionComparisonType.LessOrEqual 
			OR ItemFilter.ComparisonType = DataCompositionComparisonType.Less Then
			
			If TypeOf(Str.Value) = Type("StandardPeriod") Then
				Str.Value.EndDate = ?(Not ValueIsFilled(ItemFilter.Value), ItemFilter.Value, EndOfDay(ItemFilter.Value));
			Else
				Str.Value.ValueTo = ?(Str.Value.ValueTo = 0, ItemFilter.Value, Min(ItemFilter.Value, Str.Value.ValueTo));
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
			Str.ButtonName = "FilterMark" + StrReplace(String(New UUID), "-", "");
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
			
			ValuePresentation = Format(Str.Value.ValueFrom, "NZ=0") + " - " + Format(Str.Value.ValueTo, "NZ=...");
			Prefix = LastTitlePart(FilterTitle);
			
		ElsIf CommonUse.IsReference(TypeOf(Str.Value)) Then
			ValuePresentation = String(Str.Value);
		ElsIf TypeOf(Str.Value) = Type("Boolean") Then
			
			SchemeField = SchemeField(DCSchema, Str.Field);
			
			If SchemeField = Undefined Then
				Parameter = Undefined;	
			Else
				Parameter = SchemeField.EditParameters.FindParameterValue(New DataCompositionParameter("EditFormat"));
			EndIf;
			
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

&AtServerNoContext
Function LastTitlePart(Title)
	
	Result = Title;
	Position = Find(Result, ".");
	
	While Position > 0 Do
		Result = Mid(Result, Position + 1);
		Position = Find(Result, ".");
	EndDo;
	
	Return Result;
	
EndFunction

#EndRegion 

#EndRegion
 