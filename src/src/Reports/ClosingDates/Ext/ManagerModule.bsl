#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProgramInterface

// Placement settings in the report panel.
//
// Parameters:
//   Settings - Collection - Used for the description of report
//       settings and variants, see description to ReportsVariants.ConfigurationReportVariantsSettingTree().
//   ReportSettings - ValueTreeRow - Placement settings of all report options.
//      See "Attributes for change" of the ReportsVariants function.ConfigurationReportVariantsSetupTree().
//
// Description:
//  See ReportsVariantsOverridable.SetReportsVariants().
//
// Auxiliary methods:
//   VariantSettings = ReportsVariants.VariantDesc(Settings, ReportSettings, "<VariantName>");
//   ReportsVariants.SetOutputModeInReportPanels
//   False (Settings, ReportSettings,True/False); Repor//t supports only this mode.
//
Procedure ConfigureReportsVariants(Settings, ReportSettings) Export
	ModuleReportsVariants = CommonUse.CommonModule("ReportsVariants");
	ReportSettings.Enabled = False;
	
	Properties = ClosingDatesServiceReUse.SectionsProperties();
	If Properties.ShowSections AND Not Properties.AllSectionsWithoutObjects Then
		VariantName = "ProhibitionDateChangeBySectionsObjectsForUsers";
		VariantDesc =
			NStr("en = 'Displays no-edit dates
			     |for users grouped by sections with objects.'");
		
	ElsIf Properties.AllSectionsWithoutObjects Then
		VariantName = "ClosingDatesBySectionsForUsers";
		VariantDesc =
			NStr("en = 'Displays no-edit dates
			     |for users grouped by sections.'");
	Else
		VariantName = "ClosingDatesByObjectsForUsers";
		VariantDesc =
			NStr("en = 'Displays no-edit dates
			     |for users grouped by objects.'");
	EndIf;
	VariantSettings = ModuleReportsVariants.VariantDesc(Settings, ReportSettings, VariantName);
	VariantSettings.Enabled  = True;
	VariantSettings.Description = VariantDesc;
	
	If Properties.ShowSections AND Not Properties.AllSectionsWithoutObjects Then
		VariantName = "ClosingDatesByUsers";
		VariantDesc =
			NStr("en = 'Displays no-edit dates for sections
			     |with objects grouped by users.'");
		
	ElsIf Properties.AllSectionsWithoutObjects Then
		VariantName = "ClosingDatesByUsersWithoutObjects";
		VariantDesc =
			NStr("en = 'Displays no-edit dates
			     |for sections grouped by users.'");
	Else
		VariantName = "ClosingDatesByUsersWithoutSections";
		VariantDesc =
			NStr("en = 'Displays no-edit dates
			     |for objects grouped by users.'");
	EndIf;
	VariantSettings = ModuleReportsVariants.VariantDesc(Settings, ReportSettings, VariantName);
	VariantSettings.Enabled  = True;
	VariantSettings.Description = VariantDesc;
EndProcedure

#EndRegion

#EndIf
