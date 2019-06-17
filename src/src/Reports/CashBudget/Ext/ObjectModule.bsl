#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

Procedure OnComposeResult(ResultDocument, DetailsData, StandardProcessing)
	
	ReportSettings = SettingsComposer.GetSettings();
	TemplateComposer = New DataCompositionTemplateComposer;
	CompositionTemplate = TemplateComposer.Execute(DataCompositionSchema, ReportSettings, DetailsData);
	
	ParameterEndOfPeriod = CompositionTemplate.ParameterValues.Find("EndOfPeriod");
	If Not ParameterEndOfPeriod = Undefined Then
		
		If TypeOf(ParameterEndOfPeriod.Value) = Type("Date")
			AND ParameterEndOfPeriod.Value = Date(1,1,1) Then 
		
			ParameterEndOfPeriod.Value = Date(3999,12,31,23,59,59);
			
		Else
			
			ParameterEndOfPeriod.Value = EndOfDay(ParameterEndOfPeriod.Value);
			
		EndIf;
	
	EndIf;
	
EndProcedure

#EndIf