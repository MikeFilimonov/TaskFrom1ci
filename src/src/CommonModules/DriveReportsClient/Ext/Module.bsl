
// Opens a predefined report option
//
// Parameters:
//  Variant  - Structure - description of a report option:
//     * ReportName           - String - report
//     name * VariantKey        - String - key of a report option
//
Procedure OpenReportOption(Variant) Export
	
	OpenParameters = New Structure;
	OpenParameters.Insert("VariantKey", Variant.VariantKey);
	
	Uniqueness = "Report." + Variant.ReportName + "/VariantKey." + Variant.VariantKey;
	
	OpenParameters.Insert("PrintParametersKey",        Uniqueness);
	OpenParameters.Insert("WindowOptionsKey", Uniqueness);
	
	OpenForm("Report." + Variant.ReportName + ".Form", OpenParameters, Undefined, Uniqueness);
	
EndProcedure

Procedure DetailProcessing(ThisForm, Item, Details, StandardProcessing) Export
	
	If ThisForm.UniqueKey = "Report.AccountsReceivableTrend/VariantKey.DebtDynamics" Then
		
		StandardProcessing = False;
		
		ReportOptionProperties = New Structure("VariantKey, ObjectKey",
			"Default", "Report.AccountsReceivableAging");
		
		ReportVariantSettingsLinker = DriveReportsServerCall.ReportVariantSettingsLinker(ReportOptionProperties);
		If ReportVariantSettingsLinker = Undefined Then
			Return;
		EndIf;
		
		CurrentVariantSettingsLinker = ThisForm.Report.SettingsComposer;
		CopyFilter(ReportVariantSettingsLinker, CurrentVariantSettingsLinker);
		
		ReportVariantUserSettings = ReportVariantSettingsLinker.UserSettings;
		
		PeriodValue = DriveReportsServerCall.ReceiveDecryptionValue("Period", Details, ThisForm.ReportDetailsData);
		If PeriodValue <> Undefined Then
			LayoutParameter = New DataCompositionParameter("PeriodUs");
			For Each SettingItem In ReportVariantUserSettings.Items Do
				If TypeOf(SettingItem) = Type("DataCompositionSettingsParameterValue") AND SettingItem.Parameter = LayoutParameter Then
					ParameterValue = SettingItem;
					If TypeOf(ParameterValue.Value) = Type("StandardBeginningDate") Then
						ParameterValue.Value.Variant = StandardBeginningDateVariant.Custom;
						ParameterValue.Value.Date = PeriodValue;
						ParameterValue.Use = True;
					EndIf;
					Break;
				EndIf;
			EndDo;
		EndIf;
		
		ReportParameters = New Structure("UserSettings, 
											|VariantKey, 
											|PurposeUseKey, 
											|GenerateOnOpen",
											ReportVariantUserSettings,
											ReportOptionProperties.VariantKey,
											"CustomersDebtDynamicsDecryption",
											True);
		
		OpenForm("Report.AccountsReceivableAging.Form", ReportParameters);
		
	ElsIf ThisForm.UniqueKey = "Report.AccountsPayableTrend/VariantKey.DebtDynamics" Then
		
		StandardProcessing = False;
		
		ReportOptionProperties = New Structure("VariantKey, ObjectKey",
			"Default", "Report.AccountsPayableAging");
		
		ReportVariantSettingsLinker = DriveReportsServerCall.ReportVariantSettingsLinker(ReportOptionProperties);
		If ReportVariantSettingsLinker = Undefined Then
			Return;
		EndIf;
		
		CurrentVariantSettingsLinker = ThisForm.Report.SettingsComposer;
		CopyFilter(ReportVariantSettingsLinker, CurrentVariantSettingsLinker);
		
		ReportVariantUserSettings = ReportVariantSettingsLinker.UserSettings;
		
		PeriodValue = DriveReportsServerCall.ReceiveDecryptionValue("DynamicPeriod", Details, ThisForm.ReportDetailsData);
		If PeriodValue <> Undefined Then
			LayoutParameter = New DataCompositionParameter("PeriodUs");
			For Each SettingItem In ReportVariantUserSettings.Items Do
				If TypeOf(SettingItem) = Type("DataCompositionSettingsParameterValue") AND SettingItem.Parameter = LayoutParameter Then
					ParameterValue = SettingItem;
					If TypeOf(ParameterValue.Value) = Type("StandardBeginningDate") Then
						ParameterValue.Value.Variant = StandardBeginningDateVariant.Custom;
						ParameterValue.Value.Date = PeriodValue;
						ParameterValue.Use = True;
					EndIf;
					
					Break;
				EndIf;
			EndDo;
		EndIf;
		
		ReportParameters = New Structure("UserSettings, 
											|VariantKey, 
											|PurposeUseKey, 
											|GenerateOnOpen",
											ReportVariantUserSettings,
											ReportOptionProperties.VariantKey,
											"DebtToVendorsDynamicsDecryption",
											True);
		
		OpenForm("Report.AccountsPayableAging.Form", ReportParameters);
		
	ElsIf ThisForm.FormName = "Report.SalesFunnel.Form" Then
	
		If ThisForm.FormOwner = Undefined Then
			
			ReportOptionProperties = New Structure("VariantKey, ObjectKey",
				ThisForm.CurrentVariantKey, "Report.SalesFunnel");
			
			ReportVariantSettingsLinker = DriveReportsServerCall.ReportVariantSettingsLinker(ReportOptionProperties);
			If ReportVariantSettingsLinker = Undefined Then
				Return;
			EndIf;
			
			StandardProcessing = False;
			
			CurrentVariantSettingsLinker = ThisForm.Report.SettingsComposer;
			CopyFilter(ReportVariantSettingsLinker, CurrentVariantSettingsLinker);
			
			ReportVariantUserSettings = ReportVariantSettingsLinker.UserSettings;
			
			For Each SettingItem In CurrentVariantSettingsLinker.UserSettings.Items Do
				
				For Each ReportVariantSettingItem In ReportVariantUserSettings.Items Do
					
					If SettingItem.Parameter = ReportVariantSettingItem.Parameter Then
						
						ReportVariantSettingItem.Value = SettingItem.Value;
						Break;
						
					EndIf;
					
				EndDo;
				
			EndDo;
			
			// Filter
			ReportVariantUserSettings.AdditionalProperties.Insert("FilterStructure",
				DriveReportsServerCall.GetDetailsDataStructure(Details, ThisForm.ReportDetailsData));
			
			ReportVariantUserSettings.AdditionalProperties.Insert("DrillDown", True);
			
			ReportParameters = New Structure();
			ReportParameters.Insert("UserSettings", ReportVariantUserSettings);
			ReportParameters.Insert("VariantKey", ReportOptionProperties.VariantKey);
			ReportParameters.Insert("GenerateOnOpen", True);
			
			OpenForm("Report.SalesFunnel.Form", ReportParameters, ThisForm, True);
			
		EndIf;
	
	ElsIf ThisForm.FormName = "Report.SalesPipeline.Form" Then
		
		If ThisForm.FormOwner = Undefined Then
			
			ReportOptionProperties = New Structure("VariantKey, ObjectKey",
				ThisForm.CurrentVariantKey, "Report.SalesPipeline");
			
			ReportVariantSettingsLinker = DriveReportsServerCall.ReportVariantSettingsLinker(ReportOptionProperties);
			If ReportVariantSettingsLinker = Undefined Then
				Return;
			EndIf;
			
			StandardProcessing = False;
			
			CurrentVariantSettingsLinker = ThisForm.Report.SettingsComposer;
			CopyFilter(ReportVariantSettingsLinker, CurrentVariantSettingsLinker);
			
			ReportVariantUserSettings = ReportVariantSettingsLinker.UserSettings;
			
			For Each SettingItem In CurrentVariantSettingsLinker.UserSettings.Items Do
				
				For Each ReportVariantSettingItem In ReportVariantUserSettings.Items Do
					
					If SettingItem.Parameter = ReportVariantSettingItem.Parameter Then
						
						ReportVariantSettingItem.Value = SettingItem.Value;
						Break;
						
					EndIf;
					
				EndDo;
				
			EndDo;
			
			// Filter
			ReportVariantUserSettings.AdditionalProperties.Insert("FilterStructure",
				DriveReportsServerCall.GetDetailsDataStructure(Details, ThisForm.ReportDetailsData));
			
			ReportVariantUserSettings.AdditionalProperties.Insert("DrillDown", True);
			
			ReportParameters = New Structure();
			ReportParameters.Insert("UserSettings", ReportVariantUserSettings);
			ReportParameters.Insert("VariantKey", ReportOptionProperties.VariantKey);
			ReportParameters.Insert("GenerateOnOpen", True);
			
			OpenForm("Report.SalesPipeline.Form", ReportParameters, ThisForm, True);
			
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure CopyFilter(LinkerReceiver, LinkerSource) Export
	
	ReceiverSettings = LinkerReceiver.Settings;
	SourceSettings = LinkerSource.Settings;
	UserSettingsSource = LinkerSource.UserSettings;
	
	For Each FilterItem In SourceSettings.Filter.Items Do
		If ValueIsFilled(FilterItem.UserSettingID) Then
			
			For Each UserSetting In UserSettingsSource.Items Do
				If UserSetting.UserSettingID = FilterItem.UserSettingID Then
					If TypeOf(UserSetting) = Type("DataCompositionFilterItem")
						AND UserSetting.Use Then
						
						CommonUseClientServer.SetFilterItem(
							ReceiverSettings.Filter,
							String(FilterItem.LeftValue),
							UserSetting.RightValue,
							UserSetting.ComparisonType,
							,
							True);
						
					EndIf;
					Break;
				EndIf;
			EndDo;
		EndIf;
	EndDo;
	
	LinkerReceiver.LoadSettings(ReceiverSettings);

EndProcedure

