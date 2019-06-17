
#Region Variables

&AtClient
Var RefreshInterface;

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure Attachable_OnAttributeChange(Item, RefreshingInterface = True)
	
	Result = OnAttributeChangeServer(Item.Name);
	
	If RefreshingInterface Then
		AttachIdleHandler("RefreshApplicationInterface", 1, True);
		RefreshInterface = True;
	EndIf;
	
	If Result.Property("NotificationForms") Then
		Notify(Result.NotificationForms.EventName, Result.NotificationForms.Parameter, Result.NotificationForms.Source);
	EndIf;
	
EndProcedure

&AtClient
Procedure RefreshApplicationInterface()
	
	If RefreshInterface = True Then
		RefreshInterface = False;
		RefreshInterface();
	EndIf;
	
EndProcedure

&AtServer
Procedure SetEnabled(AttributePathToData = "")
	
	If RunMode.ThisIsSystemAdministrator Then
		
		// StandardSubsystems.PerformanceMeasurement
		If AttributePathToData = "ConstantsSet.MeasurePerformance"
			Or AttributePathToData = "" Then
			Items.ProcessingProductivityRating.Enabled = ConstantsSet.MeasurePerformance;
		EndIf;
		// End StandardSubsystems.PerformanceMeasurement
		
	EndIf;
	
EndProcedure

&AtServer
Function OnAttributeChangeServer(ItemName)
	
	Result = New Structure;
	
	AttributePathToData = Items[ItemName].DataPath;
	
	SaveAttributeValue(AttributePathToData, Result);
	
	SetEnabled(AttributePathToData);
	
	RefreshReusableValues();
	
	Return Result;
	
EndFunction

&AtServer
Procedure SaveAttributeValue(AttributePathToData, Result)
	
	// Save attribute values not connected with constants directly (one-to-one ratio).
	If AttributePathToData = "" Then
		Return;
	EndIf;
	
	// Definition of constant name.
	ConstantName = "";
	If Lower(Left(AttributePathToData, 14)) = Lower("ConstantsSet.") Then
		// If the path to attribute data is specified through "ConstantsSet".
		ConstantName = Mid(AttributePathToData, 15);
	Else
		// Definition of name and attribute value record in the corresponding constant from "ConstantsSet".
		// Used for the attributes of the form directly connected with constants (one-to-one ratio).
	EndIf;
	
	// Saving the constant value.
	If ConstantName <> "" Then
		ConstantManager = Constants[ConstantName];
		ConstantValue = ConstantsSet[ConstantName];
		
		If ConstantManager.Get() <> ConstantValue Then
			ConstantManager.Set(ConstantValue);
		EndIf;
		
		NotificationForms = New Structure("EventName, Parameter, Source", "Record_ConstantsSet", New Structure, ConstantName);
		Result.Insert("NotificationForms", NotificationForms);
	EndIf;
	
EndProcedure

&AtServer
Procedure VisibleManagementElements(AttributePathToData = "")
	
	If AttributePathToData = "GroupDataProcessorGroupObjectsChange" OR IsBlankString(AttributePathToData) Then
		
		CommonUseClientServer.SetFormItemProperty(Items, "GroupDataProcessorGroupObjectsChange", "Visible", RunMode.IsApplicationAdministrator);
		
	EndIf;
	
	If AttributePathToData = "ImportDataFromService" OR IsBlankString(AttributePathToData) Then
		
		CommonUseClientServer.SetFormItemProperty(Items, "ImportDataFromService", "Visible", IsInRole("SystemAdministrator") AND RunMode.Local);
		
	EndIf;
	
	// Data
	// export From the local version export for the service, from the service for the local version
	If AttributePathToData = "ExportDataToMigrateToOnPremises" OR IsBlankString(AttributePathToData) Then
		
		CommonUseClientServer.SetFormItemProperty(Items, "ExportDataToMigrateToOnPremises", "Visible", IsInRole("FullRights") AND RunMode.SaaS);
		
	EndIf;
	
	If AttributePathToData = "ExportDataToMigrateToSaaS" OR IsBlankString(AttributePathToData) Then
		
		CommonUseClientServer.SetFormItemProperty(Items, "ExportDataToMigrateToSaaS", "Visible", IsInRole("SystemAdministrator") AND RunMode.Local);
		
	EndIf;
	// Data export end
	
	If AttributePathToData = "AutomaticTextsExtraction" OR IsBlankString(AttributePathToData) Then
		
		CommonUseClientServer.SetFormItemProperty(Items, "ExplanationAutomaticTextExtraction", "Visible", GetFunctionalOption("StandardSubsystemsLocalMode"));
		
	EndIf;
	
	If AttributePathToData = "AdministratorReports" OR IsBlankString(AttributePathToData) Then
		
		CommonUseClientServer.SetFormItemProperty(Items, "ExplanationReportsAdministrator", "Visible", GetFunctionalOption("StandardSubsystemsLocalMode"));
		
	EndIf;
	
	If AttributePathToData = "DataAreaInput" OR IsBlankString(AttributePathToData) Then
		
		CommonUseClientServer.SetFormItemProperty(Items, "DataAreaInput", "Visible", IsInRole("SystemAdministrator") AND CommonUseReUse.DataSeparationEnabled());
		CommonUseClientServer.SetFormItemProperty(Items, "ExplanationDataAreaInput", "Visible", IsInRole("SystemAdministrator") AND CommonUseReUse.DataSeparationEnabled());
		
	EndIf;
	
	If AttributePathToData = "ScheduledAndBackgroundJobs" OR IsBlankString(AttributePathToData) Then
		
		CommonUseClientServer.SetFormItemProperty(Items, "ScheduledAndBackgroundJobs", "Visible", IsInRole("SystemAdministrator"));
		CommonUseClientServer.SetFormItemProperty(Items, "ExplanationScheduledAndBackgroundTasks", "Visible", IsInRole("SystemAdministrator"));
		
	EndIf;
	
EndProcedure

#Region FormCommandHandlers

// Procedure - command handler DocumentRegistersCorrection
//
&AtClient
Procedure UserActivity(Command)
	
	OpenForm("Report.UserActivity.ObjectForm");
	
EndProcedure

// Procedure - command handler DocumentRegistersCorrection
//
&AtClient
Procedure AutomaticTextsExtraction(Command)
	
	OpenForm("DataProcessor.AutomaticTextsExtraction.Form");
	
EndProcedure

// Procedure - command handler BatchDocumentReposting
//
&AtClient
Procedure BatchDocumentReposting(Command)
	
	OpenForm("DataProcessor.BatchDocumentReposting.Form");
	
EndProcedure

// Procedure - command handler DocumentRegistersCorrection
//
&AtClient
Procedure DocumentRegistersCorrection(Command)
	
	OpenForm("Document.RegistersCorrection.ListForm");
	
EndProcedure

// Procedure - command handler ExportDataToMigrateToSaaS
//
&AtClient
Procedure DataExportForGoToServiceClick(Item)
	
	OpenForm("CommonForm.DataExport", , ThisForm, , );
	
EndProcedure

// Procedure - command handler ExportDataToMigrateToOnPremises
//
&AtClient
Procedure DataExportIntoLocalVersionClick(Item)
	
	OpenForm("CommonForm.DataExport", , ThisForm, , );
	
EndProcedure

// Procedure - command handler ImportDataFromService
//
&AtClient
Procedure ImportDataFromServiceClick(Item)
	
	OpenForm("CommonForm.ImportDataFromService", , ThisForm, , );
	
EndProcedure

// Procedure - command handler DataImportFromTM103
//
&AtClient
Procedure DataImportFromExternalSources(Command)
	
	OpenForm("DataProcessor.DataImportFromExternalSources.Form.ShortDescription");
	
EndProcedure

// StandardSubsystems.BasicFunctionality
&AtClient
Procedure SearchAndDeleteDuplicates(Command)
	
	OpenForm("DataProcessor.SearchAndDeleteDuplicates.Form.SearchDuplicates");
	
EndProcedure
// End of StandardSubsystems BasicFunctionality

// StandardSubsystems.AdditionalReportsAndDataProcessors
&AtClient
Procedure AdditionalAdministrativeDataProcessors(Command)
	
	ParametersForm = New Structure;
	ParametersForm.Insert("SectionName", "SetupAndAdministration");
	ParametersForm.Insert("DestinationObjects", New ValueList);
	ParametersForm.Insert("Kind", AdditionalReportsAndDataProcessorsClientServer.DataProcessorKindAdditionalInformationProcessor());
	ParametersForm.Insert("WindowOpeningMode", FormWindowOpeningMode.LockOwnerWindow);
	ParametersForm.Insert("Title", NStr("en = 'Additional data processors for administration'"));
	OpenForm("CommonForm.AdditionalReportsAndDataProcessors", ParametersForm, ThisObject);
	
EndProcedure
// End StandardSubsystems.AdditionalReportsAndDataProcessors

// StandardSubsystems.AdditionalReportsAndDataProcessors
&AtClient
Procedure AdditionalReportsOnAdministration(Command)
	ParametersForm = New Structure;
	ParametersForm.Insert("SectionName", "SetupAndAdministration");
	ParametersForm.Insert("DestinationObjects", New ValueList);
	ParametersForm.Insert("Kind", AdditionalReportsAndDataProcessorsClientServer.DataProcessorKindAdditionalReport());
	ParametersForm.Insert("WindowOpeningMode", FormWindowOpeningMode.LockOwnerWindow);
	ParametersForm.Insert("Title", NStr("en = 'Additional administration reports'"));
	OpenForm("CommonForm.AdditionalReportsAndDataProcessors", ParametersForm, ThisObject);
EndProcedure
// End StandardSubsystems.AdditionalReportsAndDataProcessors

// StandardSubsystems.PerformanceMeasurement
&AtClient
Procedure ExecutePerformanceMeasurementsOnChange(Item)
	Attachable_OnAttributeChange(Item);
EndProcedure
// End StandardSubsystems.PerformanceMeasurement

// Procedure - command handler AdministratorReports
//
&AtClient
Procedure AdministratorReports(Command)
	
	ExecuteParameters = New Structure;
	ExecuteParameters.Insert("Source", Window);
	ExecuteParameters.Insert("Uniqueness", "SetupAndAdministration");
	ExecuteParameters.Insert("Window", Window);
	
	ReportsVariantsClient.ShowReportsPanel("SetupAndAdministration", ExecuteParameters);
	
EndProcedure

// Procedure - command handler DataAreaInput
//
&AtClient
Procedure DataAreaInput(Command)
	
	OpenForm("CommonForm.DataAreaInput");
	
EndProcedure

// Procedure - command handler ScheduledAndBackgroundTasksClick
//
&AtClient
Procedure ScheduledAndBackgroundJobsClick(Item)
	
	OpenForm("DataProcessor.ScheduledAndBackgroundJobs.Form", , ThisForm, , );
	
EndProcedure

// Procedure - command handler StandardODataInterfaceSetupClick
//
&AtClient
Procedure StandardODataInterfaceSetupClick(Item)
	
	OpenForm("DataProcessor.StandardODataInterfaceSetup.Form");
	
EndProcedure

#EndRegion

#EndRegion

#Region ProcedureFormEventHandlers

// Procedure - event handler OnCreateAtServer of the form.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	// Attribute values of the form
	RunMode = CommonUseReUse.ApplicationRunningMode();
	RunMode = New FixedStructure(RunMode);
	
	// StandardSubsystems.PerformanceMeasurement
	Items.GroupPerformanceEstimation.Visible = RunMode.ThisIsSystemAdministrator;
	If RunMode.ThisIsSystemAdministrator Then
		ConstantsSet.MeasurePerformance = Constants.MeasurePerformance.Get();
	EndIf;
	// End StandardSubsystems.PerformanceMeasurement
	
	// ServiceTechnology.SaaS.StandardODataInterfaceSetup
	If Metadata.CompatibilityMode = Metadata.ObjectProperties.CompatibilityMode.DontUse Then
		
		CommonUseClientServer.SetFormItemProperty(Items, "Group6", "Visible", RunMode.SaaS AND RunMode.IsApplicationAdministrator);
		
	EndIf;
	// End ServiceTechnology.SaaS.StandardODataInterfaceSetup
	
	VisibleManagementElements();
	
	SetEnabled();
	
EndProcedure

// Procedure - event handler OnClose form.
&AtClient
Procedure OnClose(Exit)
	
	If Exit Then
		Return;
	EndIf;

	RefreshApplicationInterface();
	
EndProcedure

#EndRegion
