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
	
	// Edge inside
	For Each ChartItem In ResultDocument.Drawings Do
		If TypeOf(ChartItem.Object) = Type("Chart") Then
			ChartItem.Object.LabelLocation = ChartLabelLocation.EdgeInside;
		EndIf;
	EndDo;
	
EndProcedure

#EndRegion

#EndIf
