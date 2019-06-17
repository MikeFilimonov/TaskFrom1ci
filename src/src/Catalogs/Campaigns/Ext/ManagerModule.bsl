#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

Function GetFirstActivity(Campaign) Export
	
	Activity = Catalogs.CampaignActivities.EmptyRef();
	
	If ValueIsFilled(Campaign) Then
		
		Query = New Query;
		Query.Text = 
			"SELECT TOP 1
			|	CampaignsActivities.LineNumber AS LineNumber,
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
		
		If SelectionDetailRecords.Next() Then
			Activity = SelectionDetailRecords.Activity;
		EndIf;
		
	EndIf;
	
	Return Activity;
	
EndFunction

#EndRegion

#EndIf