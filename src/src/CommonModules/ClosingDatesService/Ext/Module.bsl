////////////////////////////////////////////////////////////////////////////////
// Subsystem "Change prohibition dates".
// 
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProgramInterface

// See details of the same procedure in the StandardSubsystemsServer module.
Procedure OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers) Export
	
	// SERVERSIDE HANDLERS.
		
	ServerHandlers["StandardSubsystems.BasicFunctionality\OnAddSessionSettingsSetupHandler"].Add(
		"ClosingDatesService");
	
	If CommonUse.SubsystemExists("StandardSubsystems.ReportsVariants") Then
		ServerHandlers["StandardSubsystems.ReportsVariants\OnConfiguringOptionsReports"].Add(
			"ClosingDatesService");
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.SaaS.JobQueue") Then
		ServerHandlers["StandardSubsystems.SaaS.JobQueue\ListOfTemplatesOnGet"].Add(
			"ClosingDatesService");
	EndIf;
	
	If CommonUse.SubsystemExists("ServiceTechnology.DataExportImport") Then
		ServerHandlers[
			"ServiceTechnology.DataExportImport\WhenFillingCommonDataTypesDoNotRequireMatchingRefsOnImport"].Add(
				"ClosingDatesService");
	EndIf;
	
EndProcedure

#Region HandlersOfConditionalCallsFromOtherSubsystems

// Disables or enables the check of change prohibition for current session.
//
Procedure SkipChangeProhibitionCheck(Skip = True) Export
	
	SessionParameters.SkipChangeProhibitionCheck = Skip;
	
EndProcedure

#EndRegion

#EndRegion

#Region ServiceProceduresAndFunctions

#Region EventHandlersOfTheSSLSubsystems

// Returns a match of session parameters and handlers parameters to initialize them.
//
Procedure OnAddSessionSettingsSetupHandler(Handlers) Export
	
	Handlers.Insert("SkipChangeProhibitionCheck", "ClosingDatesService.SessionParametersSetting");
	
EndProcedure

// ReportsVariants subsystem events handlers.

// Contains the settings of report options placement in reports panel.
//   
// Parameters:
//   Settings - Collection - Used for the description of reports
//       settings and options, see description to ReportsVariants.ConfigurationReportVariantsSetupTree().
//   
// Definition:
//   IN this procedure it is required to specify how the
//   reports predefined variants will be registered in application and shown in the reports panel.
//   
// Auxiliary methods:
//   ReportSettings   = ReportsVariants.ReportDescription(Settings, Metadata.Reports.<ReportName>);
//   VariantSettings = ReportsVariants.VariantDesc(Settings, ReportSettings, "<VariantName>");
//   
//   These functions receive respectively report settings and report option settings of the next structure:
//       * Enabled - Boolean -
//           If False then the report option is not registered in the subsystem.
//           Used to delete technical and contextual report options from all interfaces.
//           These report options can still be opened applicationmatically as report
//           using opening parameters (see help on "Managed form extension for the VariantKeys" report).
//       * VisibleByDefault - Boolean -
//           If False then the report option is hidden by default in the reports panel.
//           User can "enable" it in the reports
//           panel setting mode or open via the "All reports" form.
//       *Description - String - Additional information on the report option.
//           It is displayed as a tooltip in the reports panel.
//           Must decrypt for user the report
//           option content and should not duplicate the report option name.
//       * Placement - Map - Settings for report option location in sections.
//           ** Key     - MetadataObject: Subsystem - Subsystem that hosts the report or the report option.
//           ** Value - String - Optional. Settings for location in the subsystem.
//               ""        - Output report in its group in regular font.
//               "Important"  - Output report in its group in bold.
//               "SeeAlso" - Output report in the group "See also".
//       * FunctionalOptions - Array from String -
//            Names of the functional report option options.
//   
// ForExample:
//   
//  (1) Add a report option to the subsystem.
// Variant = ReportsVariants.VariantDescription(Settings, Metadata.Reports.ReportName, "VariantName1");
// Variant.Location.Insert(Metadata.Subsystems.SectionName.Subsystems.SubsystemName);
//   
//  (2) Disable report option.
// Variant = ReportsVariants.VariantDescription(Settings, Metadata.Reports.ReportName, "VariantName1");
// Variant.Enabled = False;
//   
//  (3) Disable all report options except for the required one.
// Report = ReportsVariants.ReportDescription(Settings, Metadata.Reports.ReportName);
// Report.Enabled = False;
// Variant = ReportsVariants.VariantDescription (Settings, Report, "VariantName");
// Variant.Enabled = True;
//   
//  (4) Completion result of 4.1 and 4.2 will be the same:
//  (4.1)
// Report = ReportsVariants.ReportDescription(Settings, Metadata.Reports.ReportName);
// Variant = ReportsVariants.VariantDescription (Settings, Report, "VariantName1");
// Variant.Location.Delete(Metadata.Subsystems.SectionName.Subsystems.SubsystemName);
// Variant = ReportsVariants.VariantDescription (Settings, Report, "VariantName2");
// Variant.Location.Delete(Metadata.Subsystems.SectionName.Subsystems.SubsystemName);
// Variant = ReportsVariants.VariantDescription (Settings, Report, "VariantName3");
// Variant.Location.Delete(Metadata.Subsystems.SectionName.Subsystems.SubsystemName);
//   
//  (4.2)
// Report = ReportsVariants.ReportDescription(Settings, Metadata.Reports.ReportName);
// Report.Location.Delete(Metadata.Subsystems.SectionName.Subsystems.SubsystemName);
// ReportsVariants.VariantDesc(Settings, Report, "VariantName1");
// ReportsVariants.VariantDesc(Settings, Report, "VariantName2");
// ReportsVariants.VariantDesc(Settings, Report, "VariantName3");
// Report.Location.Insert(Metadata.Subsystems.SectionName.Subsystems.SubsystemName);
//   
// IMPORTANT:
//   Report serves as variants container.
//     By modifying the report settings you can change the settings of all its variants at the same time.
//     However if you receive report option settings directly, they
//     will become the self-service ones, i.e. will not inherit settings changes from the report.See examples 3 and 4.
//   
//   Initial setting of reports locating by the subsystems
//     is read from metadata and it is not required to duplicate it in the code.
//   
//   Functional variants options unite with functional reports options by the following rules:
//     (ReportFunctionalOption1 OR ReportFunctionalOption2) And
//     (VariantFunctionalOption3 OR VariantFunctionalOption4).
//   Reports functional options are
//     not read from the metadata, they are applied when the user uses the subsystem.
//   You can add functional options via ReportDescription that will be connected by
//     the rules specified above. But remember that these functional options will be valid only
//     for predefined options of this report.
//   For user report options only functional report options are valid.
//     - they are disabled only along with total report disabling.
//
Procedure OnConfiguringOptionsReports(Settings) Export
	ModuleReportsVariants = CommonUse.CommonModule("ReportsVariants");
	ModuleReportsVariants.SetReportInManagerModule(Settings, Metadata.Reports.ClosingDatesOfDataImport);
	ModuleReportsVariants.SetReportInManagerModule(Settings, Metadata.Reports.ClosingDates);
EndProcedure

// SaaS subsystem event handlers.TasksQueue.

// Handler of the OnReceiveTemplatesList event.
//
// Forms a list of queue jobs templates
//
// Parameters:
//  Patterns - String array. You should add the names
//   of predefined undivided scheduled jobs in the parameter
//   that should be used as a template for setting a queue.
//
Procedure ListOfTemplatesOnGet(Patterns) Export
	
	Patterns.Add("ChangeProhibitionRelativeDatesCurrentValuesRecalculation");
	
EndProcedure

// ServiceTechnology library event handlers.

// Fills the array of types of undivided data for which
// the refs mapping during data import to another infobase is not necessary as correct refs
// mapping is guaranteed by using other mechanisms.
//
// Parameters:
//  Types - Array(MetadataObject)
//
Procedure WhenFillingCommonDataTypesDoNotRequireMatchingRefsOnImport(Types) Export
	
	// IN separated data, only the refs to predefined
	// plan items of the ClosingDateSections characteristics kinds are used.
	Types.Add(Metadata.ChartsOfCharacteristicTypes.ClosingDateSections);
	
EndProcedure

#EndRegion

#Region OtherProceduresAndFunctions

// Sets parameters of data exchange subsystem session.
//
// Parameters:
//  ParameterName - String - name of the session parameter the value of which shall be set.
//  SpecifiedParameters - array - this parameter includes info on the setup session parameters.
// 
Procedure SessionParametersSetting(ParameterName, SpecifiedParameters) Export
	
	SessionParameters.SkipChangeProhibitionCheck = False;
	SpecifiedParameters.Add("SkipChangeProhibitionCheck");
	
EndProcedure

// Performs recalculation and update of
// current values of relative prohibition dates according to the current session date.
//
// Parameters:
//  WriteResultDescriptionToEventLogMonitor - Boolean.
//  ResultDescription - String.
//
Procedure RecalculateCurrentValuesOfRelativeProhibitionDates(WriteResultDescriptionToEventLogMonitor = True, ResultDescription = "") Export
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	ClosingDates.Section,
	|	ClosingDates.Object,
	|	ClosingDates.User,
	|	ClosingDates.ProhibitionDate,
	|	ClosingDates.ProhibitionDateDescription
	|FROM
	|	InformationRegister.ClosingDates AS ClosingDates";
	
	Selection = Query.Execute().Select();
	
	CurrentDateAtServer = BegOfDay(CurrentSessionDate());
	RecordManager = InformationRegisters.ClosingDates.CreateRecordManager();
	ErrorPresentation = "";
	Cancel = False;
	AreUpdatedDates = False;
	ThereAreNoRelativeDates = True;
	
	While Selection.Next() Do
		CalculatedProhibitionDate = CalculateProhibitionDateByDescription(
			CurrentDateAtServer, Selection.ProhibitionDateDescription);
		
		If ValueIsFilled(CalculatedProhibitionDate) Then
			ThereAreNoRelativeDates = False;
			
			If Selection.ProhibitionDate <> CalculatedProhibitionDate Then
				FillPropertyValues(RecordManager, Selection);
				
				Block = New DataLock;
				LockItem = Block.Add();
				LockItem.Region = "InformationRegister.ClosingDates";
				LockItem.SetValue("Section",       Selection.Section);
				LockItem.SetValue("Object",       Selection.Object);
				LockItem.SetValue("User", Selection.User);
				LockItem.Mode = DataLockMode.Exclusive;
				
				BeginTransaction();
				Try
					Block.Lock();
					RecordManager.Read();
					If RecordManager.Selected() Then
						If Selection.ProhibitionDateDescription <> RecordManager.ProhibitionDateDescription Then
							CalculatedProhibitionDate = CalculateProhibitionDateByDescription(
								CurrentDateAtServer, RecordManager.ProhibitionDateDescription);
						EndIf;
						If ValueIsFilled(CalculatedProhibitionDate) Then
							RecordManager.ProhibitionDate = CalculatedProhibitionDate;
							RecordManager.Write();
							AreUpdatedDates = True;
						EndIf;
					EndIf;
					CommitTransaction();
				Except
					RollbackTransaction();
					Cancel = True;
					ErrorPresentation = ErrorPresentation + Chars.LF + Chars.LF +
						BriefErrorDescription(ErrorInfo());
				EndTry;
			EndIf;
		EndIf;
	EndDo;
	
	If ThereAreNoRelativeDates Then
		ResultDescription = NStr("en = 'Relative closing dates are not specified.'");
		
	ElsIf Cancel Then
		If AreUpdatedDates Then
			ResultDescription =
				NStr("en = 'Some current values of the relative prohibition dates have been recalculated.
				     |During recalculation, errors occurred:'");
		Else
			ResultDescription =
				NStr("en = 'Current prohibition dates are not recalculated.
				     |During recalculation, errors occurred:'");
		EndIf;
		ResultDescription = ResultDescription + ErrorPresentation;
	Else
		If AreUpdatedDates Then
			ResultDescription =
				NStr("en = 'Current values of relative closing dates are recalculated.'");
		Else
			ResultDescription =
				NStr("en = 'Current values of relative closing dates were already recalculated today.'");
		EndIf;
	EndIf;
	
	If WriteResultDescriptionToEventLogMonitor Then
		WriteLogEvent(
			NStr("en = 'Change closing dates.Relative date recalculation'",
			     CommonUseClientServer.MainLanguageCode()),
			?(Cancel, EventLogLevel.Error, EventLogLevel.Information),
			,
			,
			ResultDescription,
			EventLogEntryTransactionMode.Independent);
	EndIf;
	
	If Cancel Then
		Raise
			NStr("en = 'Failed to calculate all the relative prohibition dates.
			     |Details in the event log.'");
	EndIf;
	
EndProcedure

// Scheduled job handler ChangeProhibitionRelativeDatesCurrentValuesRecalculation.
Procedure ChangeProhibitionRelativeDatesCurrentValuesRecalculation() Export
	
	CommonUse.OnStartExecutingScheduledJob();
	
	RecalculateCurrentValuesOfRelativeProhibitionDates();
	
EndProcedure

// Looks for date changing/loading prohibition for objects of type:
//  CatalogObject,
//  ChartOfCharacteristicTypesObject,
//  ChartOfAccountsObject,
//  ChartOfCalculationTypesObject,
//  BusinessProcessObject,
//  TaskObject,
//  ExchangePlanObject,
//  DocumentObject,
//  InformationRegisterRecordSet,
//  AccumulationRegisterRecordSet,
//  AccountingRegisterRecordSet,
//  CalculationRegisterRecordSet,
//  ObjectDeletion.
//
// Parameters:
//  Source             - one of the types listed above.
//
//  Cancel                - Boolean (return value) will be
//                         set as True if object does not pass prohibition dates checks.
//
//  SourceRegister      - Boolean - False - Source is the register otherwise the object.
//
//  Replacing            - Boolean - if the source is the register
//                         and addition is executed it is necessary to set False.
//
//  Delete             - Boolean - if the source is an object and
//                         the object deletion is executed it is nesessary to set True.
//
//  InformAboutProhibition     - Boolean if True, the user
//                         will get a message about data changing prohibition.
//
//  StandardProcessing - Boolean if False, changing prohibition
//                         check (for users) will be skipped.
//
//  ExchangePlanNode      - Undefined, PlansExchangeRef.<Exchange plan name> -
//                         If you specify a node import prohibition check will be completed.
//
//  FoundProhibitions     - Structure (return value).
//                         If the data changing prohibition is
//                         found, then there is FoundDataChangeProhibition
//                         property if data loading prohibition is found then there is FoundDataImportingProhibition property.
//
Procedure CheckDataImportClosingDates(
		Source,
		Cancel,
		SourceRegister,
		Replacing,
		Delete,
		AdditionalParameters = Undefined) Export
	
	InformAboutProhibition     = True;
	StandardProcessing = True;
	ExchangePlanNode      = Undefined;
	FoundProhibitions     = Undefined;
	
	If TypeOf(AdditionalParameters) = Type("Structure") Then
		AdditionalParameters.Property("InformAboutProhibition",     InformAboutProhibition);
		AdditionalParameters.Property("StandardProcessing", StandardProcessing);
		AdditionalParameters.Property("ExchangePlanNode",      ExchangePlanNode);
		AdditionalParameters.Property("FoundProhibitions",     FoundProhibitions);
	EndIf;
	
	If SkipProhibitionDatesCheck(
	         Source,
	         InformAboutProhibition,
	         StandardProcessing,
	         ExchangePlanNode) Then
	
	ElsIf Not SourceRegister
	        AND Not Source.IsNew()
	        AND Not Delete Then
		
		If ChangingOrImportingIsProhibited(
				Source,
				Source.Ref,
				InformAboutProhibition,
				StandardProcessing,
				ExchangePlanNode,
				FoundProhibitions) Then
			
			Cancel = True;
		EndIf;
		
	ElsIf SourceRegister AND Replacing Then
		
		If ChangingOrImportingIsProhibited(
				Source,
				Source.Filter,
				InformAboutProhibition,
				StandardProcessing,
				ExchangePlanNode,
				FoundProhibitions) Then
			
			Cancel = True;
		EndIf;
		
	ElsIf TypeOf(Source) = Type("ObjectDeletion") Then
		
		If ChangingOrImportingIsProhibited(
				Source.Ref.Metadata.FullName(),
				Source.Ref,
				InformAboutProhibition,
				StandardProcessing,
				ExchangePlanNode,
				FoundProhibitions) Then
			
			Cancel = True;
		EndIf;
		
	Else
		//     NOT SourceRegister AND
		// Source.ThisIsNew OR SourceRegister AND NOT Replacing
		// OR NOT SourceRegister AND Deletion
		If ChangingOrImportingIsProhibited(
				Source,
				,
				InformAboutProhibition,
				StandardProcessing,
				ExchangePlanNode,
				FoundProhibitions) Then
			
			Cancel = True;
		EndIf;
	EndIf;
	
	If TypeOf(AdditionalParameters) = Type("Structure") Then
		AdditionalParameters.Insert("InformAboutProhibition",     InformAboutProhibition);
		AdditionalParameters.Insert("StandardProcessing", StandardProcessing);
		AdditionalParameters.Insert("ExchangePlanNode",      ExchangePlanNode);
		AdditionalParameters.Insert("FoundProhibitions",     FoundProhibitions);
	EndIf;
	
EndProcedure

// Checks if data changing or loading prohibition check is necessary.
Function SkipProhibitionDatesCheck(Source,
                                     InformAboutProhibition,
                                     StandardProcessing,
                                     ExchangePlanNode) Export
	
	If TypeOf(Source) <> Type("ObjectDeletion")
	   AND Source.AdditionalProperties.Property("SkipChangeProhibitionCheck") Then
		
		Return True;
	EndIf;
	
	SetPrivilegedMode(True);
	If SessionParameters.SkipChangeProhibitionCheck Then
		Return True;
	EndIf;
	SetPrivilegedMode(False);
	
	If DataChangeProhibitionNotUsed() Then
		Return True;
	EndIf;
	
	If UpdateResults.InfobaseUpdateInProgress() Then
		Return True;
	EndIf;
	
	ClosingDatesOverridable.BeforeChangeProhibitionCheck(
		Source, StandardProcessing, ExchangePlanNode, InformAboutProhibition);
	
	Return Not StandardProcessing          // DO NOT verify changing prohibition.
	      AND ExchangePlanNode = Undefined;  // DO NOT verify loading prohibition.
	
EndFunction

// Common function for search of data changing and loading prohibitions.
Function ChangingOrImportingIsProhibited(
		Data,
		DataId,
		InformAboutProhibition,
		StandardProcessing,
		ExchangePlanNode,
		FoundProhibitions) Export
	
	DataForChecking = New Structure;
	// Optional reference to data in the data base.
	DataForChecking.Insert("DataId", DataId);
	DataForChecking.Insert("DataIdForPresentation", DataId);
	
	If TypeOf(Data) = Type("String") Then
		// Name of the table required for DataID
		// property of the Filter type, and also when the source data is of the ObjectDeletion type.
		DataForChecking.Insert("Table", Data);
		// DataID is filled and there is no object in memory.
		DataForChecking.Insert("FieldValuesFromObject", Undefined);
	Else
		// Name of the table that is required for DataID property of Filter type.
		DataForChecking.Insert("Table", Data.Metadata().FullName());
		// DataID can be not filled and there is object in memory.
		If DataId = Undefined Then
			DataForChecking.Insert("FieldValuesFromObject", ExtractFieldValuesFromObject(Data,
				DataForChecking.DataIdForPresentation));
		Else
			DataForChecking.Insert("FieldValuesFromObject", ExtractFieldValuesFromObject(Data));
		EndIf;
	EndIf;
	
	FoundProhibitions = Undefined;
	ProhibitionFound = ClosingDates.DataChangeProhibitionFound(
		DataForChecking, InformAboutProhibition, , StandardProcessing, ExchangePlanNode, FoundProhibitions);
	
	// Outdated. Left for backward compatibility starting from version 2.1.2.15,
	// as it was stated in the documentation without clarification
	// but was required for interaction during data exchange.
	If ProhibitionFound AND TypeOf(Data) <> Type("String") Then
		For Each KeyAndValue In FoundProhibitions Do
			Data.AdditionalProperties.Insert(KeyAndValue.Key, KeyAndValue.Value);
		EndDo;
	EndIf;
	
	Return ProhibitionFound;
	
EndFunction

// Only for internal use.
Function GetRegisterFields(DataSources, Table) Export
	
	RegisterFields = ",";
	
	For Each DataSource In DataSources Do
		
		Fields = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(
			DataSource.DataField, ".");
		
		If Fields.Count() = 0 Then
			Raise(StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'The date field for
				     |the table ""%1"" in data source
				     |for changing prohibition check is not specified.'"),
				Table));
		ElsIf Not ValueIsFilled(Fields[0]) Then
			Raise(StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'The date field for
				     |the table ""%1"" in data source
				     |for changing prohibition check is specified incorrectly: %2.'"),
				Table,
				DataSource.DataField));
		EndIf;
		If Find(RegisterFields, "," + Fields[0] + ",") = 0 Then
			RegisterFields = RegisterFields + Fields[0] + ",";
		EndIf;
		
		If ValueIsFilled(DataSource.ObjectField) Then
			
			Fields = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(
				DataSource.ObjectField, ".");
			
			If Not ValueIsFilled(Fields[0]) Then
				Raise(StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = 'Object field for the
					     |table ""%1"" in data source for
					     |changing prohibition check is specified incorrectly: %2.'"),
					Table,
					DataSource.ObjectField));
			EndIf;
			If Find(RegisterFields, "," + Fields[0] + ",") = 0 Then
				RegisterFields = RegisterFields + Fields[0] + ",";
			EndIf;
		EndIf;
	EndDo;
	
	Return Mid(RegisterFields, 2, StrLen(RegisterFields)-2);
	
EndFunction

// Only for internal use.
Function GetObjectFieldsStructure(MetadataObject, DataSources, Table) Export
	
	FieldsStructure = New Structure;
	
	For Each DataSource In DataSources Do
		
		AddField(MetadataObject,
		             DataSource,
		             FieldsStructure,
		             DataSource.DataField,
		             Table,
		             NStr("en = 'date field'"));
		
		If ValueIsFilled(DataSource.ObjectField) Then
			
			AddField(MetadataObject,
			             DataSource,
			             FieldsStructure,
			             DataSource.ObjectField,
			             Table,
			             NStr("en = 'object field'"));
		EndIf;
	EndDo;
	
	Return FieldsStructure;
	
EndFunction

#EndRegion

#Region HelperProcedureAndFunctions

Function CalculateProhibitionDateByDescription(CurrentDateAtServer, ProhibitionDateDescription)
	
	TwentyFourHours = 60*60*24;
	RegistrationDateVariant = "";
	PermissionDaysCount = 0;
	
	If ValueIsFilled(ProhibitionDateDescription) Then
		RegistrationDateVariant = StrGetLine(ProhibitionDateDescription, 1);
		Row2            = StrGetLine(ProhibitionDateDescription, 2);
		If ValueIsFilled(Row2) Then
			DescriptionOfType = New TypeDescription("Number");
			PermissionDaysCount = DescriptionOfType.AdjustValue(Row2);
		EndIf;
	EndIf;
	
	If RegistrationDateVariant = "LastYearEnd" Then
		CurrentProhibitionDate    = BegOfYear(CurrentDateAtServer) - TwentyFourHours;
		PreviousProhibitionDate = BegOfYear(CurrentProhibitionDate) - TwentyFourHours;
		
	ElsIf RegistrationDateVariant = "LastQuarterEnd" Then
		CurrentProhibitionDate    = BegOfQuarter(CurrentDateAtServer) - TwentyFourHours;
		PreviousProhibitionDate = BegOfQuarter(CurrentProhibitionDate) - TwentyFourHours;
		
	ElsIf RegistrationDateVariant = "LastMonthEnd" Then
		CurrentProhibitionDate    = BegOfMonth(CurrentDateAtServer) - TwentyFourHours;
		PreviousProhibitionDate = BegOfMonth(CurrentProhibitionDate) - TwentyFourHours;
		
	ElsIf RegistrationDateVariant = "LastWeekEnd" Then
		CurrentProhibitionDate    = BegOfWeek(CurrentDateAtServer) - TwentyFourHours;
		PreviousProhibitionDate = BegOfWeek(CurrentProhibitionDate) - TwentyFourHours;
		
	ElsIf RegistrationDateVariant = "PreviousDay" Then
		CurrentProhibitionDate    = BegOfDay(CurrentDateAtServer) - TwentyFourHours;
		PreviousProhibitionDate = BegOfDay(CurrentProhibitionDate) - TwentyFourHours;
	Else
		CurrentProhibitionDate    = '00000000';
	EndIf;
	
	If ValueIsFilled(CurrentProhibitionDate) Then
		PermissionTerm = CurrentProhibitionDate + PermissionDaysCount * TwentyFourHours;
		If Not CurrentDateAtServer > PermissionTerm Then
			CurrentProhibitionDate = PreviousProhibitionDate;
		EndIf;
	EndIf;
	
	Return CurrentProhibitionDate;
	
EndFunction

Function DataChangeProhibitionNotUsed()
	
	SetPrivilegedMode(True);
	
	If InfobaseUpdateServiceReUse.InfobaseUpdateRequired() Then
		Return True;
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	TRUE AS TrueValue
	|FROM
	|	InformationRegister.ClosingDates AS ClosingDates";
	NotUsed = Query.Execute().IsEmpty();
	
	Return NotUsed;
	
EndFunction

Function ExtractFieldValuesFromObject(Val Data, DataIdForPresentation = Undefined)
	
	FieldsValues = New Structure;
	MetadataObject = Data.Metadata();
	Filter = New Structure("Table", MetadataObject.FullName());
	DataSources = GetDataSources(Filter);
	
	If CommonUse.ThisIsRegister(MetadataObject) Then
		// Filling the fields values from records set.
		RegisterFields = GetRegisterFields(DataSources, Filter.Table);
		FieldsValues = Data.Unload(, RegisterFields);
		FieldsValues.GroupBy(RegisterFields);
		DataIdForPresentation = Data.Filter;
	Else
		// Filling the fields values from the object.
		FieldsValues = GetObjectFieldsStructure(MetadataObject, DataSources, Filter.Table);
		For Each Field In FieldsValues Do
			If MetadataObject.TabularSections.Find(Field.Key) <> Undefined Then
				Fields = Field.Value;
				FieldsValues[Field.Key] = Data[Field.Key].Unload(, Fields);
				FieldsValues[Field.Key].GroupBy(Fields);
			Else
				FieldsValues[Field.Key] = Data[Field.Key];
			EndIf;
		EndDo;
		If Not Data.IsNew() Then
			DataIdForPresentation = Data.Ref;
		EndIf;
	EndIf;
	
	Return FieldsValues;
	
EndFunction

Function GetDataSources(Filter)
	
	TablesDataSources = ClosingDatesServiceReUse.DataSourcesForChangeProhibitionCheck();
	
	DataSources = TablesDataSources.FindRows(Filter);
	
	If DataSources.Count() = 0 Then
		Raise(StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Data sources for table ""%1""
			     |for changing prohibition check are not found.'"),
			Filter.Table));
	EndIf;
	
	Return DataSources;
	
EndFunction

Procedure AddField(MetadataObject,
                       DataSource,
                       FieldsStructure,
                       Field,
                       Table,
                       FieldTypeForMessages)
	
	Fields = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(Field, ".");
	If Fields.Count() = 0 Then
		Raise(StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'The %2 is not specified to check prohibition change in the data source for table ""%1"".'"),
			Table,
			FieldTypeForMessages));
		
	ElsIf Not ValueIsFilled(Fields[0]) Then
		Raise(StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'The %2 in the
			     |data source for table ""%1"" for
			     |changing prohibition check is specified incorrectly: ""%3"".'"),
			Table,
			FieldTypeForMessages,
			Field));
	EndIf;
	
	If Not FieldsStructure.Property(Fields[0]) Then
		FieldsStructure.Insert(Fields[0]);
	EndIf;
	
	If MetadataObject.TabularSections.Find(Fields[0]) <> Undefined Then
		If Fields.Count() = 1 Then
			Raise(StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'The %2 in the
				     |data source for table ""%1"" for
				     |changing prohibition check
				     |is specified incorrectly: the field of the defined tabular section ""%3"" is not specified.'"),
				Table,
				FieldTypeForMessages,
				Field));
		ElsIf Not ValueIsFilled(Fields[1]) Then
			Raise(StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'The %2 in the
				     |data source for table ""%1"" for
				     |changing prohibition check
				     |is specified incorrectly: the field of the defined tabular section ""%3"" is specified incorrectly.'"),
				Table,
				FieldTypeForMessages,
				Field));
		EndIf;
		If FieldsStructure[Fields[0]] = Undefined Then
			FieldsStructure[Fields[0]] = Fields[1];
		Else
			FieldsStructure[Fields[0]] = FieldsStructure[Field] + "," + Fields[1];
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#EndRegion
