// The function returns user report settings.
//
// Parameters:
//  ReportName			 - String	 - Report name as set
//  in metadata ParametersStructure	 - structure that specifies filters and parameters by default. Key - filter field name, value - filter value.
// Returns:
//  custom - report settings
//    
Function GetReportUserSettings(ReportName, ParametersStructure)

    DataCompositionSchema = Reports[ReportName].GetTemplate("MainDataCompositionSchema");

    DataCompositionSettingsComposer = New DataCompositionSettingsComposer;
    DataCompositionSettingsComposer.Initialize(New DataCompositionAvailableSettingsSource(DataCompositionSchema));
    DataCompositionSettingsComposer.LoadSettings(DataCompositionSchema.SettingVariants.SalesByDiscountCard.Settings);

    For Each KeyAndValue In ParametersStructure Do
        CommonUseClientServer.SetFilterItem(DataCompositionSettingsComposer.Settings.Filter, KeyAndValue.Key, KeyAndValue.Value,,, True);
		FoundParameter = DataCompositionSettingsComposer.Settings.DataParameters.FindParameterValue(New DataCompositionParameter(KeyAndValue.Key));
		If Not FoundParameter = Undefined Then
			DataCompositionSettingsComposer.Settings.DataParameters.SetParameterValue(FoundParameter.Parameter, KeyAndValue.Value);
		EndIf;
    EndDo;

    Return DataCompositionSettingsComposer.UserSettings;

EndFunction

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	Period = DriveServer.GetProgressiveDiscountsCalculationPeriodByDiscountCard(CurrentDate(), CommandParameter);
	ItmPeriod = New StandardPeriod(Period.BeginOfPeriod, Period.EndOfPeriod);
	
	InstalledSettings = New Structure;
	InstalledSettings.Insert("DiscountCard", CommandParameter);
	If ValueIsFilled(Period.BeginOfPeriod) OR ValueIsFilled(Period.EndOfPeriod) Then
		InstalledSettings.Insert("ItmPeriod", ItmPeriod);
	EndIf;
	
	UserSettings = GetReportUserSettings("SalesWithCardBasedDiscounts", InstalledSettings);
	
	FormParameters = New Structure;
	FormParameters.Insert("VariantKey",		 		 "SalesByDiscountCard");
	FormParameters.Insert("UserSettings", UserSettings);
	FormParameters.Insert("FilterByOrderStatuses", "NotShipped");
	FormParameters.Insert("GenerateOnOpen",	 True);
	
	If TypeOf(CommandExecuteParameters.Source) = Type("ManagedForm") Then
		If Find(CommandExecuteParameters.Source.FormName, "ItemForm") > 0 Then
			OpenForm("Report.SalesWithCardBasedDiscounts.Form", FormParameters, CommandExecuteParameters.Source, CommandExecuteParameters.Uniqueness, CommandExecuteParameters.Window);
			Return;
		EndIf;
	EndIf;
	
	OpenForm("Report.SalesWithCardBasedDiscounts.Form", FormParameters, , CommandParameter.UUID());
	
EndProcedure
