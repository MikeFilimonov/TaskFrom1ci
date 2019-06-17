#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

Procedure OnComposeResult(ResultDocument, DetailsData, StandardProcessing)

	ReportSettings = SettingsComposer.GetSettings();
	
	ParameterBeginOfPeriod = ReportSettings.DataParameters.FindParameterValue(New DataCompositionParameter("BeginOfPeriod"));
	ParameterEndOfPeriod = ReportSettings.DataParameters.FindParameterValue(New DataCompositionParameter("EndOfPeriod"));
	
	If ParameterBeginOfPeriod <> Undefined AND ParameterBeginOfPeriod.Use
		AND ParameterEndOfPeriod <> Undefined AND ParameterEndOfPeriod.Use
		AND TypeOf(ParameterBeginOfPeriod.Value) = Type("StandardBeginningDate")
		AND TypeOf(ParameterEndOfPeriod.Value) = Type("StandardBeginningDate")
		AND ParameterBeginOfPeriod.Value.Date <> Date(1,1,1)
		AND ParameterEndOfPeriod.Value.Date <> Date(1,1,1)
		AND ParameterBeginOfPeriod.Value.Date > ParameterEndOfPeriod.Value.Date Then
		
		Message = New UserMessage;
		Message.Text	 = NStr("en = 'Period start date cannot be greater than end date.'");
		Message.Message();
		
		StandardProcessing = False;
		Return;
		
	EndIf;
	
	DCTitle = SettingsComposer.Settings.OutputParameters.Items.Find("Title");
	DCTitle.Value = StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en = 'Month closing report as of %1.'"),
		Format(ParameterEndOfPeriod.Value, "DF='MMMM yyyy'"));
	
EndProcedure

#EndIf