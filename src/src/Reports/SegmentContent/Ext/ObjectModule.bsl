#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

Procedure OnComposeResult(ResultDocument, DetailsData, StandardProcessing)
	
	ReportSettings = SettingsComposer.GetSettings();
	
	SegmentParameter = ReportSettings.DataParameters.FindParameterValue(New DataCompositionParameter("Segment"));
	If SegmentParameter <> Undefined
		AND SegmentParameter.Use
		AND ValueIsFilled(SegmentParameter.Value) Then
		
		ReportSettings.Filter.Items[0].RightValue = Catalogs.Segments.GetSegmentContent(SegmentParameter.Value);
	EndIf;
	
	DriveReports.SetReportAppearanceTemplate(ReportSettings);
	SettingsComposer.LoadSettings(ReportSettings);
	
EndProcedure

#EndIf