#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure OnComposeResult(ResultDocument, DetailsData, StandardProcessing)

	StandardProcessing = False;
	
	ArrayHeaderResources = New Array;
	ReportSettings = SettingsComposer.GetSettings();
	
	AdditionalProperties = SettingsComposer.UserSettings.AdditionalProperties;
	
	// Drill down vision
	DrillDown = AdditionalProperties.Property("DrillDown")
		AND AdditionalProperties.DrillDown;
		
	FromDrillDown = False;
	For Each StructureItem In ReportSettings.Structure Do
		If StructureItem.Name = "DrillDown" AND StructureItem.Use Then
			FromDrillDown = True;
			Break;
		EndIf;
	EndDo;
	
	If DrillDown OR FromDrillDown Then
		For Each StructureItem In ReportSettings.Structure Do
			StructureItem.Use = (StructureItem.Name = "DrillDown");
		EndDo;
		If DrillDown Then
			AdditionalProperties.DrillDown = False;
		EndIf;
	EndIf;
	
	// Filter
	If AdditionalProperties.Property("FilterStructure") Then
		For Each FilterItem In AdditionalProperties.FilterStructure Do
			CommonUseClientServer.SetFilterItem(ReportSettings.Filter,
				FilterItem.Key,
				FilterItem.Value);
		EndDo;
		AdditionalProperties.Delete("FilterStructure");
	EndIf;
		
	CampaignField = New DataCompositionParameter("Campaign");
	CampaignFilter = Undefined;
	For Each SettingItem In ReportSettings.DataParameters.Items Do
		If SettingItem.Parameter = CampaignField Then
			CampaignFilter = SettingItem.Value;
			Break;
		EndIf;
	EndDo;
	
	If ValueIsFilled(CampaignFilter) Then
		SetConditionalAppearanceInCampaignsColors(ReportSettings.ConditionalAppearance, CampaignFilter);
	EndIf;
	
	TemplateComposer = New DataCompositionTemplateComposer;
	CompositionTemplate = TemplateComposer.Execute(DataCompositionSchema, ReportSettings, DetailsData);

	// Create and initialize the processor layout and precheck parameters
	CompositionProcessor = New DataCompositionProcessor;
	CompositionProcessor.Initialize(CompositionTemplate, , DetailsData, True);

	// Create and initialize the result output processor
	OutputProcessor = New DataCompositionResultSpreadsheetDocumentOutputProcessor;
	OutputProcessor.SetDocument(ResultDocument);
	
	// Indicate the output begin
	OutputProcessor.Output(CompositionProcessor);
	
EndProcedure

#EndRegion

#Region Private

Procedure SetConditionalAppearanceInCampaignsColors(ConditionalAppearanceCS, Campaign)
	
	DeleteItems = New Array;
	
	For Each ConditionalAppearanceItem In ConditionalAppearanceCS.Items Do
		If ConditionalAppearanceItem.UserSettingID = "ActivityColor" Then
			DeleteItems.Add(ConditionalAppearanceItem);
		EndIf;
	EndDo;
	
	For Each DeleteItem In DeleteItems Do
		ConditionalAppearanceCS.Items.Delete(DeleteItem);
	EndDo;
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	CampaignsActivities.Ref AS Campaign,
		|	CampaignsActivities.Activity AS Activity,
		|	CampaignsActivities.HighlightColor AS HighlightColor
		|FROM
		|	Catalog.Campaigns.Activities AS CampaignsActivities
		|WHERE
		|	CampaignsActivities.Ref = &Campaign";
	
	Query.SetParameter("Campaign", Campaign);
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	While SelectionDetailRecords.Next() Do
		
		ActivityColor = SelectionDetailRecords.HighlightColor.Get();
		If TypeOf(ActivityColor) <> Type("Color") OR ActivityColor = New Color(0, 0, 0) Then
			Continue;
		EndIf;
		
		ConditionalAppearanceItem =  ConditionalAppearanceCS.Items.Add();
		
		ConditionalAppearanceItem.Appearance.SetParameterValue("ColorInChart", ActivityColor);
		ConditionalAppearanceItem.UserSettingID = "ActivityColor";
		ConditionalAppearanceItem.ViewMode = DataCompositionSettingsItemViewMode.QuickAccess;
		ConditionalAppearanceItem.Presentation = NStr("en = 'Appearance in activity color'");
		
		FilterActivity = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
		FilterActivity.LeftValue = New DataCompositionField("Activity");
		FilterActivity.ComparisonType = DataCompositionComparisonType.Equal;
		FilterActivity.RightValue = SelectionDetailRecords.Activity;
		
	EndDo;
	
EndProcedure

#EndRegion

#EndIf
