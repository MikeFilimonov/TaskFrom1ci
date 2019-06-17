
#Region Public

#Region LeadActivities

Function LeadState(LeadRef) Export
	
	StateStructure = New Structure();
	StateStructure.Insert("Campaign", Catalogs.Campaigns.EmptyRef());
	StateStructure.Insert("SalesRep", Catalogs.Employees.EmptyRef());
	StateStructure.Insert("Activity", Catalogs.CampaignActivities.EmptyRef());

	Query = New Query;
	Query.Text = 
		"SELECT
		|	LeadActivitiesSliceLast.Campaign AS Campaign,
		|	LeadActivitiesSliceLast.SalesRep AS SalesRep,
		|	LeadActivitiesSliceLast.Activity AS Activity
		|FROM
		|	InformationRegister.LeadActivities.SliceLast(, Lead = &Lead) AS LeadActivitiesSliceLast";
	
	Query.SetParameter("Lead", LeadRef);
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	If SelectionDetailRecords.Next() Then
		FillPropertyValues(StateStructure, SelectionDetailRecords);
	EndIf;
	
	Return StateStructure;
	
EndFunction

Function GetAvailableActivities(Campaign) Export

	Activities = New ValueList;
	
	If ValueIsFilled(Campaign) Then
		
		Query = New Query;
		Query.Text = 
		"SELECT
		|	CampaignsActivities.Activity AS Activity
		|FROM
		|	Catalog.Campaigns.Activities AS CampaignsActivities
		|WHERE
		|	CampaignsActivities.Ref = &Campaign
		|
		|ORDER BY
		|	CampaignsActivities.LineNumber";
		
		Query.SetParameter("Campaign", Campaign);
		
		QueryResult = Query.Execute();
		
		SelectionDetailRecords = QueryResult.Select();
		
		While SelectionDetailRecords.Next() Do
			Activities.Add(SelectionDetailRecords.Activity);
		EndDo;
		
	EndIf;
	
	Return Activities;
	
EndFunction

Procedure WriteCurrentAcrivity(Lead, Campaign, SalesRep, Activity) Export
	
	ActivityRecord = InformationRegisters.LeadActivities.CreateRecordManager();
	ActivityRecord.Period = CurrentSessionDate();
	ActivityRecord.Lead = Lead;
	ActivityRecord.Campaign = Campaign;
	ActivityRecord.SalesRep = SalesRep;
	ActivityRecord.Activity = Activity;
	ActivityRecord.Write();
	
EndProcedure

#EndRegion

#Region LeadsListConditionalAppearance

Procedure SetConditionalAppearanceInCampaignsColors(ConditionalAppearanceCS) Export
	
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
		|		INNER JOIN Catalog.Campaigns AS Campaigns
		|		ON CampaignsActivities.Ref = Campaigns.Ref
		|WHERE
		|	NOT Campaigns.DeletionMark";
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	While SelectionDetailRecords.Next() Do
		
		ActivityColor = SelectionDetailRecords.HighlightColor.Get();
		If TypeOf(ActivityColor) <> Type("Color") OR ActivityColor = New Color(0, 0, 0) Then
			Continue;
		EndIf;
		
		ConditionalAppearanceItem =  ConditionalAppearanceCS.Items.Add();
		
		ConditionalAppearanceItem.Appearance.SetParameterValue("BackColor", ActivityColor);
		ConditionalAppearanceItem.UserSettingID = "ActivityColor";
		ConditionalAppearanceItem.ViewMode = DataCompositionSettingsItemViewMode.QuickAccess;
		ConditionalAppearanceItem.Presentation = NStr("en = 'Appearance in activity color'");
		
		FilterCampaign = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
		FilterCampaign.LeftValue = New DataCompositionField("Campaign");
		FilterCampaign.ComparisonType = DataCompositionComparisonType.Equal;
		FilterCampaign.RightValue = SelectionDetailRecords.Campaign;
		
		FilterActivity = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
		FilterActivity.LeftValue = New DataCompositionField("Activity");
		FilterActivity.RightValue = SelectionDetailRecords.Activity;
		
	EndDo;
	
EndProcedure

#EndRegion

#EndRegion
