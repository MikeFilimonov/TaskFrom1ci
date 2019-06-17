////////////////////////////////////////////////////////////////////////////////
// Subsystem "Additional reports and data processors".
//
////////////////////////////////////////////////////////////////////////////////

#Region ApplicationInterface

// Connects and returns a name that is connected to external report or processor.
//   After enabling report or processor is registered in the
//   application with a name using which you can create object or open forms of report or processor.
//
// Parameters:
//   Ref - CatalogRef.AdditionalReportsAndDataProcessors - Connected data processor.
//
// Returns: 
//   * String       - Name of connected report or data processor.
//   * Undefined - If incorrect reference is passed.
//
Function ConnectExternalDataProcessor(Ref) Export
	
	StandardProcessing = True;
	Result = Undefined;
	
	EventHandlers = CommonUse.ServiceEventProcessor(
		"StandardSubsystems.AdditionalReportsAndDataProcessors\OnEnableExternalProcessor");
	
	For Each Handler In EventHandlers Do
		
		Handler.Module.OnEnableExternalProcessor(Ref, StandardProcessing, Result);
		
		If Not StandardProcessing Then
			Return Result;
		EndIf;
		
	EndDo;
	
	// Checks whether passed parameters are correct.
	If TypeOf(Ref) <> Type("CatalogRef.AdditionalReportsAndDataProcessors") 
		Or Ref = Catalogs.AdditionalReportsAndDataProcessors.EmptyRef() Then
		Return Undefined;
	EndIf;
	
	// Connection
	#If ThickClientOrdinaryApplication Then
		DataProcessorName = GetTempFileName();
		DataProcessorStorage = CommonUse.ObjectAttributeValue(Ref, "DataProcessorStorage");
		BinaryData = DataProcessorStorage.Get();
		BinaryData.Write(DataProcessorName);
		Return DataProcessorName;
	#EndIf
	
	Kind = CommonUse.ObjectAttributeValue(Ref, "Type");
	If Kind = Enums.AdditionalReportsAndDataProcessorsTypes.Report
		Or Kind = Enums.AdditionalReportsAndDataProcessorsTypes.AdditionalReport Then
		Manager = ExternalReports;
	Else
		Manager = ExternalDataProcessors;
	EndIf;
	
	LaunchParameters = CommonUse.ObjectAttributesValues(Ref, "SafeMode, DataProcessorStorage");
	AddressInTemporaryStorage = PutToTempStorage(LaunchParameters.DataProcessorStorage.Get());
	
	If GetFunctionalOption("SecurityProfilesAreUsed") Then
		
		SafeMode = WorkInSafeModeService.ExternalModuleConnectionMode(Ref);
		
		If SafeMode = Undefined Then
			SafeMode = True;
		EndIf;
		
	Else
		
		SafeMode = GetFunctionalOption("StandardSubsystemsSaaS") Or LaunchParameters.SafeMode;
		
		If SafeMode Then
			PermissionsQuery = New Query(
				"SELECT TOP 1
				|	AdditionalReportsAndDataProcessorsPermissions.LineNumber,
				|	AdditionalReportsAndDataProcessorsPermissions.TypePermissions
				|FROM
				|	Catalog.AdditionalReportsAndDataProcessors.permissions AS AdditionalReportsAndDataProcessorsPermissions
				|WHERE
				|	AdditionalReportsAndDataProcessorsPermissions.Ref = &Ref");
			PermissionsQuery.SetParameter("Ref", Ref);
			HasPermissions = Not PermissionsQuery.Execute().IsEmpty();
			
			CompatibilityMode = CommonUse.ObjectAttributeValue(Ref, "PermissionsCompatibilityMode");
			If CompatibilityMode = Enums.AdditionalReportAndDataProcessorPermissionCompatibilityModes.Version_2_2_2
				AND HasPermissions Then
				SafeMode = False;
			EndIf;
		EndIf;
		
	EndIf;
	
	WriteNote(Ref, NStr("en = 'Connection, SafeMode = ""%1"".'"), SafeMode);
	
	UnsafeOperation = New UnsafeOperationProtectionDescription;
	UnsafeOperation.UnsafeOperationWarnings = False;
	
	If Ref.Publication = Enums.AdditionalReportsAndDataProcessorsPublicationOptions.DebugMode AND ValueIsFilled(ref.FileNameForDebugging) Then
		
		FileOnDisk = New File(ref.FileNameForDebugging);
		
		If FileOnDisk.Exist() Then 					
			DataProcessorName = Manager.Create(ref.FileNameForDebugging, False, UnsafeOperation);
			DataProcessorName = Ref.ObjectName;			
		Else
			DataProcessorName = Manager.Connect(AddressInTemporaryStorage, , SafeMode, UnsafeOperation);
		EndIf;
		
	Else						
		DataProcessorName = Manager.Connect(AddressInTemporaryStorage, , SafeMode, UnsafeOperation); 		
	EndIf;
	
	Return DataProcessorName;
	
EndFunction

// Returns an object of external report or data processor.
//
// Parameters:
//   Ref - CatalogRef.AdditionalReportsAndDataProcessors - Attachable report or data processor.
//
// Returns: 
//   * ExternalDataProcessorObject - Report of connected data processor.
//   * ExternalReportObject     - Connected report object.
//   * Undefined           - If incorrect reference is passed.
//
Function GetObjectOfExternalDataProcessor(Ref) Export
	
	StandardProcessing = True;
	Result = Undefined;
	
	EventHandlers = CommonUse.ServiceEventProcessor(
		"StandardSubsystems.AdditionalReportsAndDataProcessors\OnCreateExternalDataProcessor");
	
	For Each Handler In EventHandlers Do
		
		Handler.Module.OnCreateExternalDataProcessor(Ref, StandardProcessing, Result);
		
		If Not StandardProcessing Then
			Return Result;
		EndIf;
		
	EndDo;
	
	// Connection
	DataProcessorName = ConnectExternalDataProcessor(Ref);
	
	// Checks whether passed parameters are correct.
	If DataProcessorName = Undefined Then
		Return Undefined;
	EndIf;
	
	// Getting an object instance.
	If Ref.Type = Enums.AdditionalReportsAndDataProcessorsTypes.Report
		OR Ref.Type = Enums.AdditionalReportsAndDataProcessorsTypes.AdditionalReport Then
		Manager = ExternalReports;
	Else
		Manager = ExternalDataProcessors;
	EndIf;
	
	Return Manager.Create(DataProcessorName);
	
EndFunction

// Set parameters of the form functional options
//   (it is required to generate form command interface).
//
// Parameters:
//   Form  - ManagedForm
//   FormType - String - Optional. "ListForm" for the lists forms and "ObjectForm" for the items form.
//      See also ListFormType() and ObjectFormType() functions of
//       the AdditionalReportsAndDataProcessorsClientServer general module.
//
Procedure OnCreateAtServer(Form, FormType = Undefined) Export
	
	// Set form parameters for commands of the additional reports and processors call.
	Parameters = AdditionalReportsAndDataProcessorsReUse.AssignedObjectFormParameters(Form.FormName, FormType);
	If TypeOf(Parameters) <> Type("FixedStructure") Then
		Return;
	EndIf;
	
	FunctionalOptionsParameters = New Structure;
	FunctionalOptionsParameters.Insert("AdditionalReportsAndDataProcessorsDestinationObject", Parameters.ParentRef);
	FunctionalOptionsParameters.Insert("AdditionalReportsAndDataProcessorsFormType",         ?(FormType = Undefined, Parameters.FormType, FormType));
	
	Form.SetFormFunctionalOptionParameters(FunctionalOptionsParameters);
	
	If Parameters.OutputPopupObjectFilling Then
		GeneratePopupCommandsFill(Form, Parameters);
	EndIf;
	
EndProcedure

// Generates a print form by an external source.
//
// Parameters:
//   Ref (CatalogRef.AdditionalReportsAndDataProcessors) External processor.
//   SourceParameters - Structure -
//       * CommandID - String - Comma-separated list of templates
//       * DestinationObjects (Array).
//   PrintFormsCollection - ValueTable - see description of procedure Print() in documentation.
//   PrintingObjects         (ValuesList)  see description of the Printing() procedure in the documents.
//   OutputParameters       - Structure -      see description of procedure Print() in documentation.
//
Procedure PrintByExternalSource(Ref, SourceParameters, PrintFormsCollection,
	PrintObjects, OutputParameters) Export
	
	PrintFormsCollection = PrintManagement.PrepareCollectionOfPrintForms(SourceParameters.CommandID);
	
	OutputParameters = PrintManagement.PrepareOutputParametersStructure();
	
	PrintObjects = New ValueList;
	
	ExternalDataProcessorObject = GetObjectOfExternalDataProcessor(Ref);
	
	If ExternalDataProcessorObject = Undefined Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'External data processor ""%1"" (type ""%2"") is not supported by the ""Additional reports and data processors"" subsystem'"),
			String(Ref),
			String(TypeOf(Ref)));
	EndIf;
	
	ExternalDataProcessorObject.Print(
		SourceParameters.DestinationObjects,
		PrintFormsCollection,
		PrintObjects,
		OutputParameters);
	
	// Check whether all templates are generated.
	For Each Str In PrintFormsCollection Do
		If Str.SpreadsheetDocument = Undefined Then
			ErrorMessageText = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Spreadsheet document for %1 was not generated in the print processor'"),
				Str.TemplateName);
			Raise(ErrorMessageText);
		EndIf;
		
		Str.SpreadsheetDocument.Copies = Str.Copies;
	EndDo;

EndProcedure

// Generates an information structure template about the external report or processor for further filling.
//
// Parameters:
//   SSLVersion - String - Library version of the standard subsystems which external object mechanisms expect.
//       Details - see StandardSubsystemsServer.LibraryVersion().
//
// Returns: 
//   RegistrationParameters - Structure - External object parameters.
//       * Type - String - External object kind. Corresponds
//                        to the "Kind" attribute (EnumRef.AdditionalReportsAndDataProcessorsKind).
//           To determine the kind, you can use the
//           "Kind*" function of the AdditionalReportsAndDataProcessorsClientServer general module or specify the kind explicitly:
//           ** "PrintForm"
//           ** "ObjectFill"
//           ** "CreatingLinkedObjects"
//           ** "Report"
//           ** "AdditionalInformationProcessor"
//           ** "AdditionalReport".
//       * Version - String - Object version.
//           Specified as: "<Senior number>.<Junior number>".
//       * Purpose - Array - in - String - Optional. Configuration objects names for
//                               which this object is designed.
//           Specified as  "<MetadataObjectClassName>.[*|<MetadataObjectName>]".
//       * Description - String - Optional. Presentation for administrator (catalog item name).
//           If it is not filled in, presentation of external object metadata object is taken.
//       * SafeMode - Boolean - Optional. Shows that external processor is enabled in the safe mode.
//           Default value True (processor will be executed safely).
//           Details - see "ExternalReportsManager.Enable" and "ExternalProcessorManager.Enable" help sections.
//       * Information - String - Optional. Short information on the external object.
//           IN this parameter for the administrator it is recommended to specify the description of an external object possibilities.
//           If it is not filled in, then comment of external object metadata object is taken.
//       * SSLVersion - String - Optional. Library version which external object mechanisms expect.
//           Details - see StandardSubsystemsServer.LibraryVersion().
//       * Commands - ValueTable - Optional for reports. Table of commands supplied by an external object.
//           Column types correspond to the Commands tabular sections types of the AdditionalReportsAndDataProcessors catalog.
//           ** Identifier - String - Command name. For print form - templates list.
//           ** Usage - String - Command type. Corresponds
//                                       to the "StartOption" attribute (EnumRef.AdditionalProcessorsCallMethods).
//               ***
//               "CallOfClientMethod" ***
//               "CallOfServerMethod" ***
//               "FormFilling" ***
//               "FormOpening" *** "ScriptInSafeMode".
//           ** Presentation - String - Command presentation for an end user.
//           ** ShowNotification - Boolean - True = when launch Commands will shown standard notification.
//               Not works for commands "FormOpening".
//           ** Modifier - String - Auxiliary modifier Commands.
//               *** "MXLPrint" for print forms on the basis of templates MXL.
//           ** Hide - Boolean - True if command should be hidden in the item form.
//       * Permissions - Array from ObjectXDTO.
//                      {http://www.1c.ru/1cFresh/ApplicationExtensions/Permissions/a.b.c.d}PermissionBase -
//           Optional. An array of permissions provided to an additional report
//           or processor while working in the safe mode.
//       * DefineFormSettings - Boolean - Optional.
//           When True, an additional report has application interface for close integration with
//           the report form and can override some form settings and subscribe to its events.
//           If True, and the report is connected to
//           common form ReportForm, then a procedure should be defined from a template in the report object module:
//               
//               // Settings of common form for subsystem report "Reports options".
//              
//                Parameters:
//               //   Form - ManagedForm, Undefined - Report form or report settings form.
//                  //    Undefined when call is without context.
//                  VariantKey - String, Undefined - Name
//                      of the predefined one or unique identifier of user report option.
//                      Undefined when call is without context.
//                  Settings - Structure - see return
//                      value ReportsClientServer.GetReportSettingsByDefault().
//              
//               Procedure DefineFormSettings(Form, VariantKey, Settings)
//               	 Export Procedure code.
//               EndProcedure
//
Function ExternalDataProcessorInfo(SSLVersion = "") Export
	RegistrationParameters = New Structure;
	
	RegistrationParameters.Insert("Type", "");
	RegistrationParameters.Insert("Version", "0.0");
	RegistrationParameters.Insert("Purpose", New Array);
	RegistrationParameters.Insert("Description", Undefined);
	RegistrationParameters.Insert("SafeMode", True);
	RegistrationParameters.Insert("Information", Undefined);
	RegistrationParameters.Insert("SSLVersion", SSLVersion);
	RegistrationParameters.Insert("DefineFormSettings", False);
	
	AttributesTableParts = Metadata.Catalogs.AdditionalReportsAndDataProcessors.TabularSections.Commands.Attributes;
	
	CommandTable = New ValueTable;
	CommandTable.Columns.Add("Presentation", AttributesTableParts.Presentation.Type);
	CommandTable.Columns.Add("ID", AttributesTableParts.ID.Type);
	CommandTable.Columns.Add("Use", New TypeDescription("String"));
	CommandTable.Columns.Add("ShowAlert", AttributesTableParts.ShowAlert.Type);
	CommandTable.Columns.Add("Modifier", AttributesTableParts.Modifier.Type);
	CommandTable.Columns.Add("Hide",      AttributesTableParts.Hide.Type);
	
	RegistrationParameters.Insert("Commands", CommandTable);
	RegistrationParameters.Insert("permissions", New Array);
	
	Return RegistrationParameters;
EndFunction

// Executes assigned command in the context from destination object form.
//
// Parameters:
//   Form - ManagedForm - Form from which command is called.
//   ItemName - String - Form command name that was clicked.
//   ExecutionResult - Structure - See StandardSubsystemsClientServer.NewExecutionResult().
//
// Definition:
//   It is designed to call using the code of this subsystem from assigned
//   object item form (for example, directory or document).
//
Procedure ExecuteAllocatedCommandAtServer(Form, ItemName, ExecutionResult) Export
	
	CommandDetails = DataProcessorCommandsDescription(ItemName, 
		Form.Commands.Find("AdditionalProcessorsCommandsAddressToTemporaryStorage").Action);
	
	ExternalObject = GetObjectOfExternalDataProcessor(CommandDetails.Ref);
	CommandID = CommandDetails.ID;
	
	CommandParameters = New Structure;
	CommandParameters.Insert("ThisForm", Form);
	
	ExecutionResult = ExecuteExternalObjectCommand(ExternalObject, CommandID, CommandParameters, Undefined);
	
EndProcedure

// Runs processor command and returns its result.
//
// Parameters:
//   CommandParameters - Structure - Parameters with which command is run.
//       * AdditionalDataProcessorRef - CatalogRef.AdditionalReportsAndDataProcessors - Catalog item.
//       * CommandID - String - Name of the executed command.
//       * PurposeObjects    - Array - References to objects for which data processor is executed. Mandatory
//                                         for assigned processors.
//       * ExecutionResult  - Structure - Optional. Adds return value.
//          See StandardSubsystemsClientServer.ExecutionNewResult().
//   ResultAddress - String - Optional. Temporary storage address by which execution
//                              result will be placed.
//
// Returns:
//   * Structure - Executioon result that is passed to client.
//   * Undefined - If ResultAddress is passed.
//
Function RunCommand(CommandParameters, ResultAddress = Undefined) Export
	
	If TypeOf(CommandParameters.AdditionalProcessorRef) <> Type("CatalogRef.AdditionalReportsAndDataProcessors")
		Or CommandParameters.AdditionalProcessorRef = Catalogs.AdditionalReportsAndDataProcessors.EmptyRef() Then
		Return Undefined;
	EndIf;
	
	ExternalObject = GetObjectOfExternalDataProcessor(CommandParameters.AdditionalProcessorRef);
	
	ExecutionResult = ExecuteExternalObjectCommand(ExternalObject, CommandParameters.CommandID, CommandParameters, ResultAddress);
	
	Return ExecutionResult;
	
EndFunction

// Runs the processor command directly from the form of the external object and returns the result of its execution.
//   Useful example - see AdditionalReportsAndDataProcessorsClient.RunCommandInBackground().
//
// Parameters:
//   CommandID - String - Command name as it is specified in the InformationAboutExternalProcessor() function of the
//                        object module.
//   CommandParameters - Structure - Command run parameters.
//      See AdditionalReportsAndDataProcessors.ExecuteCommandInBackground().
//   Form - ManagedForm - Form to which it is required to return the result.
//
// Returns:
//   ExecutionResult - Structure - See StandardSubsystemsClientServer.NewExecutionResult().
//
Function ExecuteCommandFromOuterObjectsForm(CommandID, CommandParameters, Form) Export
	
	ExternalObject = Form.FormAttributeToValue("Object");
	
	ExecutionResult = ExecuteExternalObjectCommand(ExternalObject, CommandID, CommandParameters, Undefined);
	
	Return ExecutionResult;
	
EndFunction

// Generates sections list in which additional reports call command is available.
//
// Returns: 
//   Array MetadataObject: Subsystem - Sections metadata to which additional reports commands list is output.
//
Function AdditionalReportsSections() Export
	SectionsMetadata = New Array;
	
	AdditionalReportsAndDataProcessorsOverridable.GetSectionsWithAdditionalReports(SectionsMetadata);
	
	If CommonUse.SubsystemExists("StandardSubsystems.ApplicationSettings") Then
		ProcessorModuleAdministrationPanelSSL = CommonUse.CommonModule("DataProcessors.AdministrationPanelSSL");
		ProcessorModuleAdministrationPanelSSL.OnDeterminingSectionsWithAdditionalReports(SectionsMetadata);
	EndIf;
	
	Return SectionsMetadata;
EndFunction

// Generates sections list where additional processors call command is available.
//
// Returns: 
//   Array from MetadataObject: Subsystem - Sections metadata to which additional processors
//   commands list is output.
//
Function AdditionalDataProcessorSections() Export
	SectionsMetadata = New Array;
	
	AdditionalReportsAndDataProcessorsOverridable.GetSectionsWithAdditionalInformationProcessors(SectionsMetadata);
	
	If CommonUse.SubsystemExists("StandardSubsystems.ApplicationSettings") Then
		ProcessorModuleAdministrationPanelSSL = CommonUse.CommonModule("DataProcessors.AdministrationPanelSSL");
		ProcessorModuleAdministrationPanelSSL.OnDeterminingSectionsWithAdditionalProcessors(SectionsMetadata);
	EndIf;
	
	Return SectionsMetadata;
EndFunction

#Region ProceduresUsedDuringTheDataExchange

// Overrides the standard behavior during data import.
//   GUIDScheduledJob attribute of the Commands tabular
//   section is not transferred as connected with the current base scheduled job.
//
Procedure OnAdditionalInformationProcessorReceiving(DataItem, ItemReceive) Export
	
	If ItemReceive = DataItemReceive.Ignore Then
		
		// Do not override standard data processor.
		
	ElsIf TypeOf(DataItem) = Type("CatalogObject.AdditionalReportsAndDataProcessors")
		AND DataItem.Type = Enums.AdditionalReportsAndDataProcessorsTypes.AdditionalInformationProcessor Then
		
		// Table of scheduled jobs unique ids.
		QueryText =
		"SELECT
		|	Commands.Ref AS Ref,
		|	Commands.ID AS ID,
		|	Commands.ScheduledJobGUID AS ScheduledJobGUID
		|FROM
		|	Catalog.AdditionalReportsAndDataProcessors.Commands AS Commands
		|WHERE
		|	Commands.Ref = &Ref";
		
		Query = New Query(QueryText);
		Query.Parameters.Insert("Ref", DataItem.Ref);
		
		ScheduledJobsID = Query.Execute().Unload();
		
		// Fill in scheduled jobs identifiers in commands table from current DB data.
		For Each RowCommand In DataItem.Commands Do
			Found = ScheduledJobsID.FindRows(New Structure("ID", RowCommand.ID));
			If Found.Count() = 0 Then
				RowCommand.ScheduledJobGUID = New UUID("00000000-0000-0000-0000-000000000000");
			Else
				RowCommand.ScheduledJobGUID = Found[0].ScheduledJobGUID;
			EndIf;
		EndDo;
		
	EndIf;
	
EndProcedure

#EndRegion

#EndRegion

#Region ServiceApplicationInterface

// Declares AdditionalReportsAndDataProcessors subsystem service events:
//
// Server events:
//   OnUpdateBusinessCalendars.
//
// See details of the same procedure in the StandardSubsystemsServer module.
Procedure OnAddOfficeEvent(ClientEvents, ServerEvents) Export
	
	// SERVER EVENTS.
	
	// It is called on determining if current user rights allow to add additional report or data processor into the data area.
	//
	// Parameters:
	//  AdditionalInformationProcessor - CatalogObject.AdditionalReportsAndDataProcessors,
	//    item handbook that is recorded by user.
	//  Result - Boolean, in this procedure this parameter is used to set the flag showing that there is a right,
	//      StandardProcessing - Boolean, in this procedure this parameter is used to set the flag showing that the right
	//                           is checked by standard processor
	//
	// Syntax:
	// Procedure OnCheckAddingRight(Val AdditionalProcessor, Result, StandardProcessor) Export
	//
	ServerEvents.Add("StandardSubsystems.AdditionalReportsAndDataProcessors\OnCheckingRightsAdd");
	
	// Called while checking possibility to import additional report or processor from file.
	//
	// Parameters:
	//  AdditionalInformationProcessor - CatalogRef.AdditionalReportsAndDataProcessors,
	//  Result - Boolean, in this procedure this parameter is used to set the flag showing the option to import an
	//      additional report or data processor from file, StandardProcessing - Boolean, in this procedure this parameter
	//      is used to set the flag showing the execution of the standard processing checking the option to import an
	//      additional report or data processor from file, StandardProcessing
	//
	// Syntax:
	// Procedure OnCheckImportProcessorFromFilePossibility(Val AdditionalProcessor, Result, StandardProcessor)  Export
	//
	ServerEvents.Add("StandardSubsystems.AdditionalReportsAndDataProcessors\OnCheckingPossibilityOfDataExportProcessorsFromFile");
	
	// Called while checking whether it is possible to export additional report or processor to file.
	//
	// Parameters:
	//  AdditionalInformationProcessor - CatalogRef.AdditionalReportsAndDataProcessors,
	//  Result - Boolean, in this parameter during this procedure sets
	//    the flag of possibility of additional report
	//  or data processor import from file, StandardProcessing - Boolean, in this parameter during this procedure
	//    sets the flag of checking standard processing completion possibility of additional report or data processor
	//    import in file.
	//
	// Syntax:
	// Procedure OnCheckExportProcessorToFilePossibility(Val AdditionalProcessor, Result, StandardProcessor) Export
	//
	ServerEvents.Add("StandardSubsystems.AdditionalReportsAndDataProcessors\OnCheckingCapabilitiesOfDataProcessorsInExportingsFile");
	
	// It is called when checking the necessity to show the detailed information on additional reports and data processors
	// in user interface.
	//
	// Parameters:
	//  AdditionalInformationProcessor - CatalogRef.AdditionalReportsAndDataProcessors,
	//  Result - Boolean, in this procedure this parameter is used to set the flag showing the necessity to display
	//           detailed information on additional reports and data processors import in user interface.
	//  StandardProcessing - Boolean, in this procedure this parameter is used to set the flag showing the execution of
	//      standard processing checking the necessity to display detailed information of additional reports and data
	//      processors in user interface.
	//
	// Syntax:
	// Procedure OnCheckNeedDisplayExtendedInformation(Val AdditionalProcessor, Result, StandardProcessor) Export
	//
	ServerEvents.Add("StandardSubsystems.AdditionalReportsAndDataProcessors\OnCheckingWhetherToDisplayExtendedInformation");
	
	// Fills the kinds of additional reports and data processors
	// publication that are unavailable for use in current infobase model.
	//
	// Parameters:
	//  UnavailablePublicationsKinds - String array.
	//
	// Syntax:
	// Procedure OnFillingUnavailablePublishingKinds(Val UnavailablePublishingKinds) Export
	//
	ServerEvents.Add("StandardSubsystems.AdditionalReportsAndDataProcessors\OnFillingInaccessiblePublicationKinds");

	// Called from the BeforeWriting event of the catalog.
	// AdditionalReportsAndDataProcessors checks
	// whether it is fair to change items attributes
	// of this catalog for additional processors received from catalog of additional service manager processor.
	//
	// Parameters:
	//  Source - CatalogObject.AdditionalReportsAndDataProcessors,
	//  Denial - Boolean, flag showing that catalog item recording is rejected.
	//
	// Syntax:
	// Procedure BeforeWriteExternalProcessor(Val Source, Denial) Export
	//
	ServerEvents.Add("StandardSubsystems.AdditionalReportsAndDataProcessors\AdditionalProcessingBeforeWrite");
		
	// Called from the BeforeDeletion event of catalog.
	// AdditionalReportsAndDataProcessors.
	//
	// Parameters:
	//  Source - CatalogObject.AdditionalReportsAndDataProcessors,
	//  Denial - Boolean, check box of refusal to delete catalog item from infobase.
	//
	// Syntax:
	// Procedure BeforeDeleteAdditionalProcessor(Val Source, Denial) Export
	//
	ServerEvents.Add("StandardSubsystems.AdditionalReportsAndDataProcessors\BeforeAdditionalInformationProcessorDeletion");
	
	// Called while receiving registration data for a
	// new additional report or processor.
	//
	// Parameters:
	//  Object - CatalogObject.AdditionalReportsAndDataProcessors
	//  RegistrationData - Structure similar to one returned by the export function.
	//  	InformationAboutExternalProcessor() of the external processors.
	//  StandardProcessing - Boolean
	//
	// Syntax:
	// Procedure OnGetRegistrationData(Val Object, RegistrationData, StandardProcessor) Export
	//
	ServerEvents.Add("StandardSubsystems.AdditionalReportsAndDataProcessors\OnGetOfRegistrationData");
	
	// Called while enabling external processor.
	//
	// Parameters:
	//  Ref - CatalogRef.AdditionalReportsAndDataProcessors,
	//  StandardProcessor - Boolean, check box showing the
	//    need to
	//  execute standard processor of enabling external processor, Result - String - name of enabled external report or
	//  processor (in this case, if in the handler for the StandardProcessor parameter False value is set).
	//
	// Syntax:
	// Procedure OnEnableExternalProcessor(Val Ref, StandardProcessor, Result) Export
	//
	ServerEvents.Add("StandardSubsystems.AdditionalReportsAndDataProcessors\OnEnableExternalProcessor");
	
	// Called while creating external processor object.
	//
	// Parameters:
	//  Ref - CatalogRef.AdditionalReportsAndDataProcessors,
	//  StandardProcessor - Boolean, check box showing the
	//    need to
	//  execute standard processor of enabling external processor, Result - ExternalDataProcessorObject,
	//  ExternalReportObject - object of enabled external report or processor (in this case if in the handler for the
	//                         StandardProcessor parameter False value is set).
	//
	// Syntax:
	// Procedure OnCreateExternalProcessor(Val Ref, StandardProcessor, Result) Export
	//
	ServerEvents.Add("StandardSubsystems.AdditionalReportsAndDataProcessors\OnCreateExternalDataProcessor");
	
	// Called while receiving permissions of the safe mode session.
	//
	// Parameters:
	//  SessionKey - UUID,
	//  PermissionDescriptions - ValueTable:
	//    * PermissionKind - String,
	//    * Parameters - ValueStorage,
	//  StandardProcessing - Boolean, check box showing the need to execute standard processor
	//
	// Syntax:
	// Procedure OnGetSafeModeSessionPermissions(Val SessionKey, PermissionsDescriptions, StandardProcessor) Export
	//
	ServerEvents.Add("StandardSubsystems.AdditionalReportsAndDataProcessors\OnGetSafeModeSessionsPermissions");
	
EndProcedure

#Region AddHandlersOfTheServiceEventsSubsriptions

// See details of the same procedure in the StandardSubsystemsServer module.
Procedure OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers) Export
	
	// SERVERSIDE HANDLERS.
	
	ServerHandlers["StandardSubsystems.BasicFunctionality\OnReceiveDataFromSubordinate"].Add(
		"AdditionalReportsAndDataProcessors");
	
	ServerHandlers["StandardSubsystems.BasicFunctionality\OnReceiveDataFromMaster"].Add(
		"AdditionalReportsAndDataProcessors");
	
	If CommonUse.SubsystemExists("StandardSubsystems.ToDoList") Then
		ServerHandlers["StandardSubsystems.ToDoList\AtFillingToDoList"].Add(
			"AdditionalReportsAndDataProcessors");
	EndIf;
	
EndProcedure

#EndRegion

#Region HandlersOfServiceEvents

// The procedure is the handler of an event of the
// same name that occurs at data exchange in distributed infobase.
//  See description of the OnGetDataFromSubordinate() event handler in syntax assistant.
//
Procedure OnReceiveDataFromSubordinate(DataItem, ItemReceive, SendBack, Sender) Export
	
	OnAdditionalInformationProcessorReceiving(DataItem, ItemReceive);
	
EndProcedure

// The procedure is the handler of an event of the
// same name that occurs at data exchange in distributed infobase.
//  See description of OnGetDataFromMain() event handler in syntax assistant.
//
Procedure OnReceiveDataFromMaster(DataItem, ItemReceive, SendBack, Sender) Export
	
	OnAdditionalInformationProcessorReceiving(DataItem, ItemReceive);
	
EndProcedure

// Fills the user current work list.
//
// Parameters:
//  ToDoList - ValueTable - a table of values with the following columns:
//    * Identifier - String - an internal work identifier used by the Current Work mechanism.
//    * ThereIsWork      - Boolean - if True, the work is displayed in the user current work list.
//    * Important        - Boolean - If True, the work is marked in red.
//    * Presentation - String - a work presentation displayed to the user.
//    * Count    - Number  - a quantitative indicator of work, it is displayed in the work header string.
//    * Form         - String - the complete path to the form which you need
//                               to open at clicking the work hyperlink on the Current Work bar.
//    * FormParameters- Structure - the parameters to be used to open the indicator form.
//    * Owner      - String, metadata object - a string identifier of the work, which
//                      will be the owner for the current work or a subsystem metadata object.
//    * ToolTip     - String - The tooltip wording.
//
Procedure AtFillingToDoList(ToDoList) Export
	
	// IN box.
	If CommonUseReUse.DataSeparationEnabled() Then
		Return;
	EndIf;
	
	// There are rights for this catalog data.
	ModuleToDoListService = CommonUse.CommonModule("ToDoListService");
	If Not AccessRight("Edit", Metadata.Catalogs.AdditionalReportsAndDataProcessors)
		Or ModuleToDoListService.WorkDisabled("AdditionalReportsAndDataProcessors") Then
		Return;
	EndIf;
	
	// There is the "Administration" section.
	Subsystem = Metadata.Subsystems.Find("Administration");
	If Subsystem = Undefined
		Or Not AccessRight("view", Subsystem)
		Or Not CommonUse.MetadataObjectAvailableByFunctionalOptions(Subsystem) Then
		Return;
	EndIf;
	
	OutputToDo = True;
	CheckedForVersion = CommonSettingsStorage.Load("ToDoList", "AdditionalReportsAndDataProcessors");
	If CheckedForVersion <> Undefined Then
		VersionArray  = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(Metadata.Version, ".");
		CurrentVersion = VersionArray[0] + VersionArray[1] + VersionArray[2];
		If CheckedForVersion = CurrentVersion Then
			OutputToDo = False; // Additional reports and processors are checked on the current version.
		EndIf;
	EndIf;
	
	AdditionalReportsAndDataProcessorsQuantity = AdditionalReportsAndDataProcessorsCount();
	
	Work = ToDoList.Add();
	Work.ID = "AdditionalReportsAndDataProcessors";
	Work.ThereIsWork      = OutputToDo AND AdditionalReportsAndDataProcessorsQuantity > 0;
	Work.Presentation = NStr("en = 'Additional reports and data processors'");
	Work.Count    = AdditionalReportsAndDataProcessorsQuantity;
	Work.Form         = "Catalog.AdditionalReportsAndDataProcessors.Form.CheckAdditionalReportsAndDataProcessors";
	Work.Owner      = "CheckCompatibilityWithCurrentVersion";
	
	// Check if there is a to-do group. If there is no group - add.
	ToDosGroup = ToDoList.Find("CheckCompatibilityWithCurrentVersion", "ID");
	If ToDosGroup = Undefined Then
		ToDosGroup = ToDoList.Add();
		ToDosGroup.ID = "CheckCompatibilityWithCurrentVersion";
		ToDosGroup.ThereIsWork      = Work.ThereIsWork;
		ToDosGroup.Presentation = NStr("en = 'Check compatibility'");
		If Work.ThereIsWork Then
			ToDosGroup.Count = Work.Count;
		EndIf;
		ToDosGroup.Owner = Subsystem;
	Else
		If Not ToDosGroup.ThereIsWork Then
			ToDosGroup.ThereIsWork = Work.ThereIsWork;
		EndIf;
		
		If Work.ThereIsWork Then
			ToDosGroup.Count = ToDosGroup.Count + Work.Count;
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region ConditionalCallHandlers

// Receives additional report reference if it is connected to the Report options subsystem storage.
//
// Parameters:
//   ReportInformation - Structure - See ReportOptions.GenerateInformationAboutReportByFullName().
//
Procedure OnDefenitionTypeAndReferencesIfAdditionalReport(ReportInformation) Export
	
	QueryText =
	"SELECT TOP 1
	|	Table.Ref
	|FROM
	|	Catalog.AdditionalReportsAndDataProcessors AS Table
	|WHERE
	|	Table.ObjectName = &ObjectName
	|	AND Table.DeletionMark = FALSE
	|	AND Table.Type = &TypeAdditionalReport
	|	AND Table.UsesVariantsStorage = TRUE
	|	AND Table.Publication = &PublicationIsUsed";
	
	Query = New Query;
	Query.SetParameter("ObjectName", ReportInformation.ReportName);
	Query.SetParameter("TypeAdditionalReport", Enums.AdditionalReportsAndDataProcessorsTypes.AdditionalReport);
	Query.SetParameter("PublicationIsUsed", Enums.AdditionalReportsAndDataProcessorsPublicationOptions.Used);
	If ReportInformation.ConnectedAllReports Then
		QueryText = StrReplace(QueryText, "And Table.UsesVariantsStorage = TRUE", "");
	EndIf;
	Query.Text = QueryText;
	
	// Required for the generated data integrity. Access rights will be applied on the usage step.
	SetPrivilegedMode(True);
	Selection = Query.Execute().Select();
	
	If Selection.Next() Then
		ReportInformation.Report = Selection.Ref;
		ReportInformation.Insert("AdditionalReport");
	EndIf;
	
EndProcedure

// Expands the array using additional reports references available to the current user.
//
// Parameters:
//   Result - Array of <see. Catalogs.ReportsVariants.Attributes.Report> -
//       Reports references are available for the current user.
//
// Usage location:
//   ReportOptions.CurrentUserReports().
//
Procedure OnAddAdditionalReportsAvailableToCurrentUser(AvailableReports) Export

	If Not AccessRight("Read", Metadata.Catalogs.AdditionalReportsAndDataProcessors) Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED DISTINCT
	|	Table.Ref
	|FROM
	|	Catalog.AdditionalReportsAndDataProcessors AS Table
	|WHERE
	|	Table.UsesVariantsStorage
	|	AND Table.Type = &TypeAdditionalReport
	|	AND NOT Table.Ref IN (&AvailableReports)";
	
	Query.SetParameter("AvailableReports", AvailableReports);
	Query.SetParameter("TypeAdditionalReport", Enums.AdditionalReportsAndDataProcessorsTypes.AdditionalReport);
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		AvailableReports.Add(Selection.Ref);
	EndDo;
	
EndProcedure

// Enables "Additional reports and processors" subsystem report.
//   Exceptions are processed by a managing code.
//
// Parameters:
//   Ref - CatalogRef.AdditionalReportsAndDataProcessors - Report that should be initialized.
//   ReportParameters - Structure - Parameters set received during the report and report enabling process.
//      See ReportsMailing.InitializeReport().
//   Result - Boolean, Undefined - Connection result.
//       True       - Additional report is enabled.
//       False         - Unable to enable an additional report.
//       Undefined - Additional reports subsystem is unavailable.
//
// Usage location:
//   ReportOptions.EnableReportObject().
//   ReportsMailing.InitializeReport().
//
Procedure OnConnectingAdd1Report(Ref, ReportParameters, Result) Export

	Kind = CommonUse.ObjectAttributeValue(Ref, "Type");
	If Kind = Enums.AdditionalReportsAndDataProcessorsTypes.Report
		OR Kind = Enums.AdditionalReportsAndDataProcessorsTypes.AdditionalReport Then
		
		Try
			ReportParameters.Name = ConnectExternalDataProcessor(Ref);
			ReportParameters.Object = ExternalReports.Create(ReportParameters.Name);
			ReportParameters.Metadata = ReportParameters.Object.Metadata();
			Result = True;
		Except
			ReportParameters.Errors = 
				StrReplace(NStr("en = 'An error occurred while connecting additional report ""%1"":'"), "%1", String(Ref))
				+ Chars.LF
				+ DetailErrorDescription(ErrorInfo());
			Result = False;
		EndTry;
		
	Else
		
		ReportParameters.Errors = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Item %1 is not an additional report'"), 
			"'"+ String(Ref) +"'");
		
		Result = False;
		
	EndIf;
	
EndProcedure

// Expands printing commands list with the external printing forms.
//
// Parameters:
//   PrintCommands - ValueTable - See PrintingManagement.CreatePrintingCommandsCollection().
//   FormName      - String          - Form full name for which it is required to receive printing commands list.
//
// Usage location:
//   PrintingManagement.FormPrintingCommands().
//
Procedure OnPrintCommandsReceive(PrintCommands, FormName) Export
	
	If Not AccessRight("Read", Metadata.Catalogs.AdditionalReportsAndDataProcessors) Then
		Return;
	EndIf;
	
	FormMetadata = Metadata.FindByFullName(FormName);
	If FormMetadata = Undefined Then
		Return;
	EndIf;
	
	FullMetadataObjectName	= FormMetadata.Parent().FullName();
	Query					= NewQueryByAvailableCommands(Enums.AdditionalReportsAndDataProcessorsTypes.PrintForm, FullMetadataObjectName);
	CommandTable			= Query.Execute().Unload();
	
	If CommandTable.Count() = 0 Then
		Return;
	EndIf;
	
	For Each TableRow In CommandTable Do
		PrintCommand = PrintCommands.Add();
		
		// Mandatory parameters.
		FillPropertyValues(PrintCommand, TableRow, "ID, Presentation");
		// Parameters that identify subsystem.
		PrintCommand.PrintManager = "StandardSubsystems.AdditionalReportsAndDataProcessors";
		
		// Additional parameters.
		PrintCommand.AdditionalParameters = New Structure("Ref, Modifier, StartVariant, ShowAlert");
		FillPropertyValues(PrintCommand.AdditionalParameters, TableRow);
	EndDo;
	
EndProcedure

// Fills in printing forms list from the external sources.
//
// Parameters:
//   ExternalPrintForms - ValueList - Printing forms.
//       Value      - String - Printing form identifier.
//       Presentation - String - Printing form name.
//   FullMetadataObjectName - String - Full name of
//       the metadata object for which it is required to get a list of printed forms.
//
// Usage location:
//   PrintingManagement.OnGetExternalPrintingFormsList().
//
Procedure OnReceivingExternalPrintFormsList(ExternalPrintForms, FullMetadataObjectName) Export
	
	If Not AccessRight("Read", Metadata.Catalogs.AdditionalReportsAndDataProcessors) Then
		Return;
	EndIf;
	
	Query = NewQueryByAvailableCommands(Enums.AdditionalReportsAndDataProcessorsTypes.PrintForm, FullMetadataObjectName);
	
	CommandTable = Query.Execute().Unload();
	
	For Each Command In CommandTable Do
		If Find(Command.ID, ",") = 0 Then // except of "sets"
			ExternalPrintForms.Add(Command.ID, Command.Presentation);
		EndIf;
	EndDo;
	
EndProcedure

// Returns a reference to external print form object.
//
// Usage location:
//   PrintingManagement.OnGetExternalPrintingForm().
//
Procedure OnExternalPrintFormReceiving(ID, FullMetadataObjectName, ExternalPrintFormRef) Export

	If Not AccessRight("Read", Metadata.Catalogs.AdditionalReportsAndDataProcessors) Then
		Return;
	EndIf;
	
	Query = NewQueryByAvailableCommands(Enums.AdditionalReportsAndDataProcessorsTypes.PrintForm, FullMetadataObjectName);
	
	CommandTable = Query.Execute().Unload();
	
	Command = CommandTable.Find(ID, "ID");
	If Command <> Undefined Then 
		ExternalPrintFormRef = Command.Ref;
	EndIf;
	
EndProcedure

// Receives additional reports and processors settings for the passed user.
//
// Parameters:
//   UserRef - CatalogRef.Users - User for which it is required to receive settings.
//   Settings          - Structure - Other users settings.
//       * SettingName - String - name that will be displayed in the processor settings tree.
//       * SettingPicture - Picture - picture that will be displayed in the processor tree.
//       * SettingsList    - ValueList - list of received settings.
//
// Usage location:
//   UsersService.OnGetOtherUserSettings().
//
Procedure ReceiveAdditionalReportsAndDataProcessorsSettings(UserRef, Settings) Export
	
	// Settings string name displayed in the processor settings tree.
	SettingName = NStr("en = 'Settings of quick access to additional reports and data processors'");
	
	// Settings string picture.
	SettingPicture = "";
	
	// List of additional reports and processors that are located in user's quick access.
	Query = New Query;
	Query.Text = 
	"SELECT
	|	UserAccessToDataProcessors.AdditionalReportOrDataProcessor AS Object,
	|	UserAccessToDataProcessors.CommandID AS ID,
	|	UserAccessToDataProcessors.User AS User
	|FROM
	|	InformationRegister.UserAccessToDataProcessors AS UserAccessToDataProcessors
	|WHERE
	|	User = &User";
	
	Query.Parameters.Insert("User", UserRef);
	
	QueryResult = Query.Execute().Unload();
	
	Settings = New Structure;
	Settings.Insert("SettingName", SettingName);
	Settings.Insert("SettingPicture", SettingPicture);
	Settings.Insert("SettingsList", QueryResult);
	
EndProcedure

// Saves commands of additional reports and processors by a specified user.
//
// Parameters:
//   Settings - ValueList - Saved settings keys list.
//   ReceiversUsers - Array from CatalogRef.Users -
//       Users for whom it is required to copy settings.
//
// Usage location:
//   UsersService.OnSaveOtherUserSettings().
//
Procedure AddCommandsInQuickAccessList(Settings, UserTarget) Export
	
	For Each ItemRow In Settings Do
		
		Record = InformationRegisters.UserAccessToDataProcessors.CreateRecordManager();
		
		Record.AdditionalReportOrDataProcessor  = ItemRow.Value;
		Record.CommandID             = ItemRow.Presentation;
		Record.User                     = UserTarget;
		Record.Available                         = True;
		
		Record.Write(True);
		
	EndDo;
	
EndProcedure

// Clears commands of additional reports and processors for the specified user.
//
// Parameters:
//   KeyList - ValueList - List of cleared settings keys.
//   ClearedUser - CatalogRef.Users -
//       User for which settings should be cleared.
//
// Usage location:
//   UsersService.OnDeleteOtherUserSettings().
//
Procedure DeleteCommandsFromQuickAccessList(KeyList, ClearedUser) Export
	
	For Each ItemRow In KeyList Do
		
		Record = InformationRegisters.UserAccessToDataProcessors.CreateRecordManager();
		
		Record.AdditionalReportOrDataProcessor  = ItemRow.Value;
		Record.CommandID             = ItemRow.Presentation;
		Record.User                     = ClearedUser;
		
		Record.Read();
		
		Record.Delete();
		
	EndDo;
	
EndProcedure

// Adds "Additional reports and processors" subsystem
//   reports in object modules of which there is a DefineFormSettings procedure().
//
// Parameters:
//   ReportsWithSettings - Array - The references of reports in the objects modules of which there is the
//                                 DefineFormSettings procedure().
//
// Usage location:
//   ReportOptionsReUse.ReportsWithSettings().
//
Procedure WhenDefineReportsWithSettings(ReportsWithSettings) Export
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	AdditionalReportsAndDataProcessors.Ref
	|FROM
	|	Catalog.AdditionalReportsAndDataProcessors AS AdditionalReportsAndDataProcessors
	|WHERE
	|	AdditionalReportsAndDataProcessors.UsesVariantsStorage
	|	AND AdditionalReportsAndDataProcessors.DeepIntegrationWithReportForm
	|	AND Not AdditionalReportsAndDataProcessors.DeletionMark
	|	AND (AdditionalReportsAndDataProcessors.Type = VALUE(Enum.AdditionalReportsAndDataProcessorsTypes.AdditionalReport)
	|			OR AdditionalReportsAndDataProcessors.Type = VALUE(Enum.AdditionalReportsAndDataProcessorsTypes.Report))";
	
	SetPrivilegedMode(True);
	AdditReportsWithSettings = Query.Execute().Unload().UnloadColumn("Ref");
	For Each Ref In AdditReportsWithSettings Do
		ReportsWithSettings.Add(Ref);
	EndDo;
EndProcedure

// Define metadata objects in which modules managers it is restricted to edit attributes on bulk edit.
//
// Parameters:
//   Objects - Map - as a key specify the full name
//                            of the metadata object that is connected to the "Group object change" subsystem. 
//                            Additionally, names of export functions can be listed in the value:
//                            "UneditableAttributesInGroupProcessing",
//                            "EditableAttributesInGroupProcessing".
//                            Each name shall begin with a new row.
//                            If an empty row is specified, then both functions are defined in the manager module.
//
Procedure WhenDefiningObjectsWithEditableAttributes(Objects) Export
	Objects.Insert(Metadata.Catalogs.AdditionalReportsAndDataProcessors.FullName(), "EditedAttributesInGroupDataProcessing");
EndProcedure

#EndRegion

#Region HandlersOfTheSubscriptionsToEvents

// Delete subsystems references before you delete them.
Procedure BeforeMetadataObjectIdentifierDeletion(MOIObject, Cancel) Export
	If MOIObject.DataExchange.Load Then
		Return;
	EndIf;
	
	MOIRef = MOIObject.Ref;
	
	QueryText =
	"SELECT DISTINCT
	|	Table.Ref
	|INTO TTReferences
	|FROM
	|	Catalog.AdditionalReportsAndDataProcessors.Sections AS Table
	|WHERE
	|	Table.Section = &MOIRef
	|
	|UNION ALL
	|
	|SELECT DISTINCT
	|	Table.Ref
	|FROM
	|	Catalog.AdditionalReportsAndDataProcessors.Purpose AS Table
	|WHERE
	|	Table.ObjectDestination = &MOIRef
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	TTReferences.Ref
	|FROM
	|	TTReferences AS TTReferences";
	
	Query = New Query;
	Query.SetParameter("MOIRef", MOIRef);
	Query.Text = QueryText;
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		CatalogObject = Selection.Ref.GetObject();
		
		Found = CatalogObject.Sections.FindRows(New Structure("Section", MOIRef));
		For Each TableRow In Found Do
			CatalogObject.Sections.Delete(TableRow);
		EndDo;
		
		Found = CatalogObject.Purpose.FindRows(New Structure("ObjectDestination", MOIRef));
		For Each TableRow In Found Do
			CatalogObject.Purpose.Delete(TableRow);
		EndDo;
		
		CatalogObject.Write();
	EndDo;
EndProcedure

#EndRegion

#EndRegion

#Region ServiceProceduresAndFunctions

#Region ScheduledJobs

// Handler of the ProcessorsStart scheduled job instance.
//   Starts the global processor handler by
//   the scheduled job with the specified command id.
//
// Parameters:
//   ExternalDataProcessor     - CatalogRef.AdditionalReportsAndDataProcessors - Executed data processor reference.
//   CommandID - String - Executed command identifier.
//
Procedure RunDataProcessorInScheduledJob(ExternalDataProcessor, CommandID) Export
	
	CommonUse.OnStartExecutingScheduledJob();
	
	// Events log monitor record
	WriteInformation(ExternalDataProcessor, NStr("en = 'Command %1: Start.'"), CommandID);
	
	// Run command
	Try
		RunCommand(New Structure("AdditionalProcessorRef, CommandID", ExternalDataProcessor, CommandID), Undefined);
	Except
		WriteError(
			ExternalDataProcessor,
			NStr("en = 'Command %1: Execution error:%2'"),
			CommandID,
			Chars.LF + DetailErrorDescription(ErrorInfo()));
	EndTry;
	
	// Events log monitor record
	WriteInformation(ExternalDataProcessor, NStr("en = 'Command %1: End.'"), CommandID);
	
EndProcedure

#EndRegion

#Region ExportServiceProceduresAndFunctions

// Generates query to receive table of additional reports and processors commands.
//
// Parameters:
//   KindOfDataProcessors - EnumRef.AdditionalReportsAndDataProcessorsKind - Data processor kind.
//   FullNameOrLinkOfParentOrSection - CatalogRef.MetadataObjectIDs, String -
//       Metadata object link or FullName).
//       For assigned data processors - catalog or document.
//       For global data processors - subsystems.
//   ThisIsObjectForm - Boolean - Optional.
//       True - for object form.
//       False - for list form.
//
// Returns: 
//   ValueTable - Commands of additional reports and data processors.
//       * Ref - CatalogRef.AdditionalReportsAndDataProcessors - Ref to an additional report or data processor.
//       * Identifier - String - Command identifier as it is specified by the additional object developer.
//       * StartOption - EnumRef.AdditionalProcessorsCallMethods -
//           Launch method of additional object command.
//       * Presentation - String - Command name in the user interface.
//       * ShowNotification - Boolean - Show alert to user after running the command.
//       * Modifier - String - Command modifier.
//
Function NewQueryByAvailableCommands(KindOfDataProcessors, FullNameOrLinkOfParentOrSection, ThisIsObjectForm = Undefined) Export
	
	ThisIsGlobalDataProcessors = CheckGlobalProcessing(KindOfDataProcessors);
	
	If TypeOf(FullNameOrLinkOfParentOrSection) = Type("CatalogRef.MetadataObjectIDs") Then
		ParentRefOrSection = FullNameOrLinkOfParentOrSection;
	Else
		ParentRefOrSection = CommonUse.MetadataObjectID(FullNameOrLinkOfParentOrSection);
	EndIf;
	
	Query = New Query;
	
	// Queries are fundamentally different for global and assigned processors.
	If ThisIsGlobalDataProcessors Then
		QueryText =
		"SELECT DISTINCT
		|	QuickAccess.AdditionalReportOrDataProcessor AS Ref,
		|	QuickAccess.CommandID
		|INTO ttFastAccess
		|FROM
		|	InformationRegister.UserAccessToDataProcessors AS QuickAccess
		|WHERE
		|	QuickAccess.User = &CurrentUser
		|	AND QuickAccess.Available = TRUE
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	TableQuickAccess.Ref,
		|	TableQuickAccess.CommandID
		|INTO ttReferencesAndCommands
		|FROM
		|	ttFastAccess AS TableQuickAccess
		|		INNER JOIN Catalog.AdditionalReportsAndDataProcessors AS AdditionalReportsAndDataProcessors
		|		ON TableQuickAccess.Ref = AdditionalReportsAndDataProcessors.Ref
		|			AND (AdditionalReportsAndDataProcessors.DeletionMark = FALSE)
		|			AND (AdditionalReportsAndDataProcessors.Type = &Kind)
		|			AND (AdditionalReportsAndDataProcessors.Publication = &Publication)
		|		INNER JOIN Catalog.AdditionalReportsAndDataProcessors.Sections AS SectionsTable
		|		ON TableQuickAccess.Ref = SectionsTable.Ref
		|			AND (SectionsTable.Section = &SectionReference)
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	CommandTable.Ref,
		|	CommandTable.ID,
		|	CommandTable.StartVariant,
		|	CommandTable.Presentation AS Presentation,
		|	CommandTable.ShowAlert,
		|	CommandTable.Modifier
		|FROM
		|	ttReferencesAndCommands AS TableReferencesAndCommands
		|		INNER JOIN Catalog.AdditionalReportsAndDataProcessors.Commands AS CommandTable
		|		ON TableReferencesAndCommands.Ref = CommandTable.Ref
		|			AND TableReferencesAndCommands.CommandID = CommandTable.ID
		|			AND (CommandTable.Hide = FALSE)
		|
		|ORDER BY
		|	Presentation";
		
		Query.SetParameter("SectionReference", ParentRefOrSection);
		
	Else
		
		QueryText =
		"SELECT DISTINCT
		|	TablePurpose.Ref
		|INTO TTReferences
		|FROM
		|	Catalog.AdditionalReportsAndDataProcessors.Purpose AS TablePurpose
		|		INNER JOIN Catalog.AdditionalReportsAndDataProcessors AS AdditionalReportsAndDataProcessors
		|		ON (TablePurpose.ObjectDestination = &ParentRef)
		|			AND TablePurpose.Ref = AdditionalReportsAndDataProcessors.Ref
		|			AND (AdditionalReportsAndDataProcessors.DeletionMark = FALSE)
		|			AND (AdditionalReportsAndDataProcessors.Type = &Kind)
		|			AND (AdditionalReportsAndDataProcessors.Publication = &Publication)
		|			AND (AdditionalReportsAndDataProcessors.UseForListForm = TRUE)
		|			AND (AdditionalReportsAndDataProcessors.UseForObjectForm = TRUE)
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	CommandTable.Ref,
		|	CommandTable.ID,
		|	CommandTable.StartVariant,
		|	CommandTable.Presentation AS Presentation,
		|	CommandTable.ShowAlert,
		|	CommandTable.Modifier
		|FROM
		|	TTReferences AS TableReferences
		|		INNER JOIN Catalog.AdditionalReportsAndDataProcessors.Commands AS CommandTable
		|		ON TableReferences.Ref = CommandTable.Ref
		|			AND (CommandTable.Hide = FALSE)
		|
		|ORDER BY
		|	Presentation";
		
		Query.SetParameter("ParentRef", ParentRefOrSection);
		
		// Remove filter by a list form and object.
		If ThisIsObjectForm <> True Then            
			QueryText = StrReplace(QueryText, "AND (AdditionalReportsAndDataProcessors.UseForObjectForm = TRUE)", "");
		EndIf;
		If ThisIsObjectForm <> False Then
			QueryText = StrReplace(QueryText, "AND (AdditionalReportsAndDataProcessors.UseForListForm = TRUE)", "");
		EndIf;
	EndIf;
	
	Query.SetParameter("Kind", KindOfDataProcessors);
	If Users.RolesAvailable("AddChangeAdditionalReportsAndDataProcessors") Then
		QueryText = StrReplace(QueryText, "Publication = &Publication", "Publication <> &Publication");
		Query.SetParameter("Publication", Enums.AdditionalReportsAndDataProcessorsPublicationOptions.Disabled);
	Else
		Query.SetParameter("Publication", Enums.AdditionalReportsAndDataProcessorsPublicationOptions.Used);
	EndIf;
	Query.SetParameter("CurrentUser", Users.CurrentUser());
	Query.Text = QueryText;
	
	Return Query;
EndFunction

// Determines the metadata objects list which can be processed by the passed kind.
//
// Parameters:
//   Kind - EnumRef.AdditionalReportsAndDataProcessorsKind - External data processor kind.
//
// Returns: 
//   Undefined - If incorrect Kind is passed.
//   ValueTable - Description of metadata objects.
//       * MetadataObjectsFullName - String - Full name of the metadata object, for example, "Catalog.Currencies".
//       * PurposeObject - CatalogRef.MetadataObjectIDs - Metadata object reference.
//       * MetadataObjectKind - String - Metadata object kind.
//       * Presentation - String - Metadata object presentation.
//       * FullPresentation - String - Presentation of metadata object name and kind.
//
Function AssignedMetadataObjectsByExternalObjectKind(Kind) Export
	Purpose = New ValueTable;
	Purpose.Columns.Add("MetadataObject");
	Purpose.Columns.Add("FullMetadataObjectName", New TypeDescription("String"));
	Purpose.Columns.Add("ObjectDestination", New TypeDescription("CatalogRef.MetadataObjectIDs"));
	Purpose.Columns.Add("MetadataObjectKind", New TypeDescription("String"));
	Purpose.Columns.Add("Presentation", New TypeDescription("String"));
	Purpose.Columns.Add("FullPresentation", New TypeDescription("String"));
	
	TypesOrMetadataArray = New Array;
	
	If Kind = Enums.AdditionalReportsAndDataProcessorsTypes.ObjectFill Then
		
		TypesOrMetadataArray = Metadata.CommonCommands.ObjectFill.CommandParameterType.Types();
		
	ElsIf Kind = Enums.AdditionalReportsAndDataProcessorsTypes.Report Then
		
		TypesOrMetadataArray = Metadata.CommonCommands.ObjectReports.CommandParameterType.Types();
		
	ElsIf Kind = Enums.AdditionalReportsAndDataProcessorsTypes.PrintForm Then
		                       
		TypesOrMetadataArray = Metadata.DefinedTypes.AdditionalPrintForms.Type.Types();
		
	ElsIf Kind = Enums.AdditionalReportsAndDataProcessorsTypes.CreatingLinkedObjects Then
		
		TypesOrMetadataArray = Metadata.CommonCommands.CreatingLinkedObjects.CommandParameterType.Types();
		
	ElsIf Kind = Enums.AdditionalReportsAndDataProcessorsTypes.AdditionalInformationProcessor Then
		
		TypesOrMetadataArray = AdditionalDataProcessorSections();
		
	ElsIf Kind = Enums.AdditionalReportsAndDataProcessorsTypes.AdditionalReport Then
		
		TypesOrMetadataArray = AdditionalReportsSections();
		
	Else
		
		Return Undefined;
		
	EndIf;
	
	For Each TypeOrMetadata In TypesOrMetadataArray Do
		If TypeOf(TypeOrMetadata) = Type("Type") Then
			MetadataObject = Metadata.FindByType(TypeOrMetadata);
			If MetadataObject = Undefined Then
				Continue;
			EndIf;
		Else
			MetadataObject = TypeOrMetadata;
		EndIf;
		
		NewPurpose = Purpose.Add();
		
		If MetadataObject = AdditionalReportsAndDataProcessorsClientServer.DesktopID() Then
			NewPurpose.FullMetadataObjectName = AdditionalReportsAndDataProcessorsClientServer.DesktopID();
			NewPurpose.ObjectDestination = Catalogs.MetadataObjectIDs.EmptyRef();
			NewPurpose.MetadataObjectKind = "Subsystem";
			NewPurpose.Presentation = NStr("en = 'Desktop'");
		Else
			NewPurpose.FullMetadataObjectName = MetadataObject.FullName();
			NewPurpose.ObjectDestination = CommonUse.MetadataObjectID(MetadataObject);
			NewPurpose.MetadataObjectKind = Left(NewPurpose.FullMetadataObjectName, Find(NewPurpose.FullMetadataObjectName, ".") - 1);
			NewPurpose.Presentation = MetadataObject.Presentation();
		EndIf;
		
		NewPurpose.FullPresentation = NewPurpose.Presentation + " (" + NewPurpose.MetadataObjectKind + ")";
	EndDo;
	
	Return Purpose;
EndFunction

// Returns True if the kind is related to the category of additional global reports or processors.
//
// Parameters:
//   Kind - EnumRef.AdditionalReportsAndDataProcessorsKind - External data processor kind.
//
// Returns: 
//    True - processor belongs to the global category.
//    False   - processor belongs to the category of assigned ones.
//
Function CheckGlobalProcessing(Kind) Export
	
	Return Kind = Enums.AdditionalReportsAndDataProcessorsTypes.AdditionalInformationProcessor
		OR Kind = Enums.AdditionalReportsAndDataProcessorsTypes.AdditionalReport
		OR Kind = Enums.AdditionalReportsAndDataProcessorsTypes.BankClassifierImportProcessor
		OR Kind = Enums.AdditionalReportsAndDataProcessorsTypes.BankExchangeProcessor
		OR Kind = Enums.AdditionalReportsAndDataProcessorsTypes.ExchangeRatesImportProcessor
		OR Kind = Enums.AdditionalReportsAndDataProcessorsTypes.SMSProvider;
	
EndFunction

// Converts additional reports or processors kind from the string constant to the enumeration reference.
//
// Parameters:
//   StringPresentation - String - String presentation of kind.
//
// Returns: 
//   EnumRef.AdditionalReportsAndDataProcessorsKind - Ref of type.
//
Function GetDataProcessorKindByKindStringPresentation(StringPresentation) Export
	
	If StringPresentation = AdditionalReportsAndDataProcessorsClientServer.DataProcessorKindObjectFilling() Then
		Return Enums.AdditionalReportsAndDataProcessorsTypes.ObjectFill;
	ElsIf StringPresentation = AdditionalReportsAndDataProcessorsClientServer.DataProcessorKindReport() Then
		Return Enums.AdditionalReportsAndDataProcessorsTypes.Report;
	ElsIf StringPresentation = AdditionalReportsAndDataProcessorsClientServer.DataProcessorKindPrintForm() Then
		Return Enums.AdditionalReportsAndDataProcessorsTypes.PrintForm;
	ElsIf StringPresentation = AdditionalReportsAndDataProcessorsClientServer.DataProcessorKindCreatingRelatedObjects() Then
		Return Enums.AdditionalReportsAndDataProcessorsTypes.CreatingLinkedObjects;
	ElsIf StringPresentation = AdditionalReportsAndDataProcessorsClientServer.DataProcessorKindAdditionalInformationProcessor() Then
		Return Enums.AdditionalReportsAndDataProcessorsTypes.AdditionalInformationProcessor;
	ElsIf StringPresentation = AdditionalReportsAndDataProcessorsClientServer.DataProcessorKindAdditionalReport() Then
		Return Enums.AdditionalReportsAndDataProcessorsTypes.AdditionalReport;
	ElsIf StringPresentation = AdditionalReportsAndDataProcessorsClientServer.DataProcessorKindBankClassifierImportProcessor() Then
		Return Enums.AdditionalReportsAndDataProcessorsTypes.BankClassifierImportProcessor;
	ElsIf StringPresentation = AdditionalReportsAndDataProcessorsClientServer.DataProcessorKindBankExchangeProcessor() Then
		Return Enums.AdditionalReportsAndDataProcessorsTypes.BankExchangeProcessor;
	ElsIf StringPresentation = AdditionalReportsAndDataProcessorsClientServer.DataProcessorKindExchangeRatesImportProcessor() Then
		Return Enums.AdditionalReportsAndDataProcessorsTypes.ExchangeRatesImportProcessor;
	ElsIf StringPresentation = AdditionalReportsAndDataProcessorsClientServer.DataProcessorKindSMSProvider() Then
		Return Enums.AdditionalReportsAndDataProcessorsTypes.SMSProvider;
	EndIf;
	
EndFunction

// Converts additional reports or processors kind from the enumeration reference to the string constant.
Function TypeToString(KindReference) Export
	
	If KindReference = Enums.AdditionalReportsAndDataProcessorsTypes.ObjectFill Then
		Return AdditionalReportsAndDataProcessorsClientServer.DataProcessorKindObjectFilling();
		
	ElsIf KindReference = Enums.AdditionalReportsAndDataProcessorsTypes.Report Then
		Return AdditionalReportsAndDataProcessorsClientServer.DataProcessorKindReport();
		
	ElsIf KindReference = Enums.AdditionalReportsAndDataProcessorsTypes.PrintForm Then
		Return AdditionalReportsAndDataProcessorsClientServer.DataProcessorKindPrintForm();
		
	ElsIf KindReference = Enums.AdditionalReportsAndDataProcessorsTypes.CreatingLinkedObjects Then
		Return AdditionalReportsAndDataProcessorsClientServer.DataProcessorKindCreatingRelatedObjects();
		
	ElsIf KindReference = Enums.AdditionalReportsAndDataProcessorsTypes.AdditionalInformationProcessor Then
		Return AdditionalReportsAndDataProcessorsClientServer.DataProcessorKindAdditionalInformationProcessor();
		
	ElsIf KindReference = Enums.AdditionalReportsAndDataProcessorsTypes.AdditionalReport Then
		Return AdditionalReportsAndDataProcessorsClientServer.DataProcessorKindAdditionalReport();
		
	Else
		Return "";
	EndIf;
	
EndFunction

// Returns a command work place name.
Function PresentationOfSection(Section) Export
	If Section = AdditionalReportsAndDataProcessorsClientServer.DesktopID()
		OR Section = Catalogs.MetadataObjectIDs.EmptyRef() Then
		Return NStr("en = 'Desktop'");
	EndIf;
	
	If TypeOf(Section) = Type("CatalogRef.MetadataObjectIDs") Then
		Attributes = CommonUse.ObjectAttributesValues(Section, "Synonym, DeletionMark");
		If Attributes.DeletionMark Then
			Return Undefined;
		EndIf;
		PresentationOfSection = Attributes.Synonym;
	ElsIf TypeOf(Section) = Type("MetadataObject") Then
		PresentationOfSection = Section.Presentation();
	Else
		PresentationOfSection = Metadata.Subsystems.Find(Section).Presentation();
	EndIf;
	
	Return StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en = 'Section ""%1""'"), 
		PresentationOfSection);
EndFunction

// Function that adds additional processor commands to the "own" list.
Procedure AddCommandsToOwnList(ArrayOfCommands) Export
	
	For Each ItemRow In ArrayOfCommands Do
		Record = InformationRegisters.UserAccessToDataProcessors.CreateRecordManager();
		
		Record.AdditionalReportOrDataProcessor  = ItemRow.DataProcessor;
		Record.CommandID             = ItemRow.ID;
		Record.User                     = Users.CurrentUser();
		Record.Available                         = True;
		
		Record.Write(True);
	EndDo;
	
EndProcedure

// Function that excludes additional processor commands from the "own" list.
Procedure DeleteCommandsFromOwnList(ArrayOfCommands) Export
	
	For Each ItemRow In ArrayOfCommands Do
		
		Record = InformationRegisters.UserAccessToDataProcessors.CreateRecordManager();
		
		Record.AdditionalReportOrDataProcessor  = ItemRow.DataProcessor;
		Record.CommandID             = ItemRow.ID;
		Record.User                     = Users.CurrentUser();
		
		Record.Read();
		
		Record.Delete();
		
	EndDo;
	
EndProcedure

// Checks whether configuration is integrated with report options storage subsystem.
Function UsedIntegrationWithReportVariants() Export
	Return Metadata.SettingsStorages.Find("ReportsVariantsStorage") <> Undefined;
EndFunction

// Checks whether there is the right to add additional reports and processors.
Function AddRight(Val AdditionalInformationProcessor = Undefined) Export
	
	Result = False;
	StandardProcessing = True;
	
	EventHandlers = CommonUse.ServiceEventProcessor(
		"StandardSubsystems.AdditionalReportsAndDataProcessors\OnCheckingRightsAdd");
	
	For Each Handler In EventHandlers Do
		Handler.Module.OnCheckingRightsAdd(AdditionalInformationProcessor, Result, StandardProcessing);
		
		If Not StandardProcessing Then
			Return Result;
		EndIf;
		
	EndDo;
	
	If StandardProcessing Then
		
		If CommonUseReUse.DataSeparationEnabled() AND CommonUse.UseSessionSeparator() Then
			Result = Users.InfobaseUserWithFullAccess(, True);
		Else
			Result = Users.RolesAvailable("AddChangeAdditionalReportsAndDataProcessors");
		EndIf;
		
	EndIf;
	
	Return Result;
	
EndFunction

// Checks whether it is possible to export additional report and processor from applications to file.
//
// Parameters:
//   DataProcessor - CatalogRef.AdditionalReportsAndDataProcessors
//
// Returns:
//   Boolean
//
Function DataProcessorExportToFileIsAvailable(Val DataProcessor) Export
	
	Result = False;
	StandardProcessing = True;
	
	EventHandlers = CommonUse.ServiceEventProcessor(
		"StandardSubsystems.AdditionalReportsAndDataProcessors\OnCheckingCapabilitiesOfDataProcessorsInExportingsFile");
	
	For Each Handler In EventHandlers Do
		Handler.Module.OnCheckingCapabilitiesOfDataProcessorsInExportingsFile(DataProcessor, Result, StandardProcessing);
		
		If Not StandardProcessing Then
			Return Result;
		EndIf;
		
	EndDo;
	
	If StandardProcessing Then
		Return True;
	EndIf;
	
EndFunction

// Checks whether it is possible to import additional processor that already exists in IB from file.
//
// Parameters:
//   DataProcessor - CatalogRef.AdditionalReportsAndDataProcessors
//
// Returns:
//   Boolean
//
Function ItIsPossibleToImportProcessingsFromFile(Val DataProcessor) Export
	
	Result = False;
	StandardProcessing = True;
	
	EventHandlers = CommonUse.ServiceEventProcessor(
		"StandardSubsystems.AdditionalReportsAndDataProcessors\OnCheckingPossibilityOfDataExportProcessorsFromFile");
	
	For Each Handler In EventHandlers Do
		Handler.Module.OnCheckingPossibilityOfDataExportProcessorsFromFile(DataProcessor, Result, StandardProcessing);
		
		If Not StandardProcessing Then
			Return Result;
		EndIf;
		
	EndDo;
	
	If StandardProcessing Then
		Return True;
	EndIf;
	
EndFunction

// Returns check box of displaying extended information about additional report or processor to a user.
//
// Parameters:
//   DataProcessor - CatalogRef.AdditionalReportsAndDataProcessors
//
// Returns:
//   Boolean
//
Function ShowExtendedInformation(Val DataProcessor) Export
	
	Return True;
	
EndFunction

// Publishing kinds that are unavailable for use in the current application work mode.
Function UnavailablePublicationsKinds() Export
	
	Result = New Array;
	
	EventHandlers = CommonUse.ServiceEventProcessor(
		"StandardSubsystems.AdditionalReportsAndDataProcessors\OnFillingInaccessiblePublicationKinds");
	
	For Each Handler In EventHandlers Do
		Handler.Module.OnFillingInaccessiblePublicationKinds(Result);
	EndDo;
	
	Return Result;
	
EndFunction

// Procedure should be called from the BeforeWriting event of the catalog.
//  AdditionalReportsAndDataProcessors checks
//  whether it is fair to change items attributes
//  of this catalog for additional processors received from catalog of additional service manager processor.
//
// Parameters:
//   Source - CatalogObject.AdditionalReportsAndDataProcessors
//   Denial - Boolean, flag showing that catalog item recording is rejected.
//
Procedure AdditionalProcessingBeforeWrite(Source, Cancel) Export
	
	EventHandlers = CommonUse.ServiceEventProcessor(
		"StandardSubsystems.AdditionalReportsAndDataProcessors\AdditionalProcessingBeforeWrite");
	
	For Each Handler In EventHandlers Do
		
		Handler.Module.AdditionalProcessingBeforeWrite(Source, Cancel);
		
	EndDo;
	
EndProcedure

// Procedure should be called from the BeforeDeletion event of a directory.
//  AdditionalReportsAndDataProcessors.
//
// Parameters:
//  Source - CatalogObject.AdditionalReportsAndDataProcessors,
//  Denial - Boolean, check box of refusal to delete catalog item from infobase.
//
Procedure BeforeAdditionalInformationProcessorDeletion(Source, Cancel) Export
	
	EventHandlers = CommonUse.ServiceEventProcessor(
		"StandardSubsystems.AdditionalReportsAndDataProcessors\BeforeAdditionalInformationProcessorDeletion");
	
	For Each Handler In EventHandlers Do
		
		Handler.Module.BeforeAdditionalInformationProcessorDeletion(Source, Cancel);
		
	EndDo;
	
EndProcedure

// Write error to the events log monitor by the additional report or processor.
Procedure WriteError(Ref, MessageText, Attribute1 = Undefined, Attribute2 = Undefined, Attribute3 = Undefined) Export
	Level = EventLogLevel.Error;
	WriteInJournal(Level, Ref, MessageText, Attribute1, Attribute2, Attribute3);
EndProcedure

// Write warning to the events log monitor by the additional report or processor.
Procedure WriteWarning(Ref, MessageText, Attribute1 = Undefined, Attribute2 = Undefined, Attribute3 = Undefined) Export
	Level = EventLogLevel.Warning;
	WriteInJournal(Level, Ref, MessageText, Attribute1, Attribute2, Attribute3);
EndProcedure

// Write information to the events log monitor by the additional report or processor.
Procedure WriteInformation(Ref, MessageText, Attribute1 = Undefined, Attribute2 = Undefined, Attribute3 = Undefined) Export
	Level = EventLogLevel.Information;
	WriteInJournal(Level, Ref, MessageText, Attribute1, Attribute2, Attribute3);
EndProcedure

// Write note to the events log monitor by the additional report or processor.
Procedure WriteNote(Ref, MessageText, Attribute1 = Undefined, Attribute2 = Undefined, Attribute3 = Undefined) Export
	Level = EventLogLevel.Note;
	WriteInJournal(Level, Ref, MessageText, Attribute1, Attribute2, Attribute3);
EndProcedure

// Write event to the events log monitor by the additional report or processor.
Procedure WriteInJournal(Level, Ref, MessageText, Attribute1, Attribute2, Attribute3)
	WriteLogEvent(
		AdditionalReportsAndDataProcessorsClientServer.SubsystemDescription(Undefined),
		Level,
		Metadata.Catalogs.AdditionalReportsAndDataProcessors,
		Ref,
		StringFunctionsClientServer.SubstituteParametersInString(
			MessageText,
			String(Attribute1),
			String(Attribute2),
			String(Attribute3)));
EndProcedure

#EndRegion

#Region LocalServiceProceduresAndFunctions

// Output filling commands in the object forms.
Procedure GeneratePopupCommandsFill(Form, Parameters)
	
	QueryText =
	"SELECT DISTINCT
	|	AdditionalReportsAndDataProcessorsPurpose.Ref
	|INTO TTReferences
	|FROM
	|	Catalog.AdditionalReportsAndDataProcessors.Purpose AS AdditionalReportsAndDataProcessorsPurpose
	|WHERE
	|	AdditionalReportsAndDataProcessorsPurpose.ObjectDestination = &ObjectDestination
	|	AND AdditionalReportsAndDataProcessorsPurpose.Ref.Type = &Kind
	|	AND AdditionalReportsAndDataProcessorsPurpose.Ref.UseForObjectForm = TRUE
	|	AND AdditionalReportsAndDataProcessorsPurpose.Ref.Publication = &Publication
	|	AND AdditionalReportsAndDataProcessorsPurpose.Ref.DeletionMark = FALSE
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AdditionalReportsAndDataProcessorsCommands.Ref,
	|	AdditionalReportsAndDataProcessorsCommands.ID,
	|	AdditionalReportsAndDataProcessorsCommands.StartVariant,
	|	AdditionalReportsAndDataProcessorsCommands.Presentation AS Presentation,
	|	AdditionalReportsAndDataProcessorsCommands.ShowAlert,
	|	AdditionalReportsAndDataProcessorsCommands.Modifier,
	|	AdditionalReportsAndDataProcessorsCommands.Ref.Type
	|FROM
	|	TTReferences AS TTReferences
	|		INNER JOIN Catalog.AdditionalReportsAndDataProcessors.Commands AS AdditionalReportsAndDataProcessorsCommands
	|		ON TTReferences.Ref = AdditionalReportsAndDataProcessorsCommands.Ref
	|
	|ORDER BY
	|	Presentation";
	
	Query = New Query;
	Query.SetParameter("ObjectDestination", Parameters.ParentRef);
	Query.SetParameter("Kind", Enums.AdditionalReportsAndDataProcessorsTypes.ObjectFill);
	Query.SetParameter("StartVariant", Enums.AdditionalDataProcessorsCallMethods.FillForm);
	If Users.RolesAvailable("AddChangeAdditionalReportsAndDataProcessors") Then
		QueryText = StrReplace(QueryText, "Publication = &Publication", "Publication <> &Publication");
		Query.SetParameter("Publication", Enums.AdditionalReportsAndDataProcessorsPublicationOptions.Disabled);
	Else
		Query.SetParameter("Publication", Enums.AdditionalReportsAndDataProcessorsPublicationOptions.Used);
	EndIf;
	Query.Text = QueryText;
	
	Result = Query.Execute();
	If Result.IsEmpty() Then
		Return;
	EndIf;
	
	// Determine groups to which commands will be added.
	Items = Form.Items;
	
	PresetCommands = New Array;
	Popup = Items.Find("PopupAdditionalFillingDataprocessors");
	If Popup = Undefined Then
		CommandBar = Items.Find("CommandBar");
		If CommandBar = Undefined Then
			CommandBar = Form.CommandBar;
		EndIf;
		Popup = Items.Insert("PopupAdditionalFillingDataprocessors", Type("FormGroup"), CommandBar);
		Popup.Title = NStr("en = 'Fill in'");
		Popup.Type = FormGroupType.Popup;
		Popup.Picture = PictureLib.FillForm;
		Popup.Representation = ButtonRepresentation.PictureAndText;
	Else
		For Each Item In Popup.ChildItems Do
			PresetCommands.Add(Item);
		EndDo;
	EndIf;
	
	CommandTable = Result.Unload();
	CommandTable.Columns.Add("ItemName", New TypeDescription("String"));
	CommandTable.Columns.Add("IsReport", New TypeDescription("Boolean"));
	
	For ItemNumber = 0 To CommandTable.Count() - 1 Do
		CommandDetails = CommandTable[ItemNumber];
		ItemName = "CommandAdditionalInformationProcessors" + Format(ItemNumber, "NG=");
		CommandDetails.ItemName = ItemName;
		
		Command = Form.Commands.Add(ItemName);
		Command.Action  = "Attachable_ExecuteAssignedCommand";
		Command.Title = CommandDetails.Presentation;
		
		Item = Form.Items.Add(ItemName, Type("FormButton"), Popup);
		Item.CommandName = ItemName;
		Item.OnlyInAllActions = False;
	EndDo;
	Command = Form.Commands.Add("AdditionalProcessorsCommandsAddressToTemporaryStorage");
	Command.Action = PutToTempStorage(CommandTable, Form.UUID);
	
	For Each Item In PresetCommands Do
		Items.Move(Item, Popup);
	EndDo;
	
EndProcedure

Function DataProcessorCommandsDescription(ItemName, CommandsInTemporaryStorageTableAddress) Export
	CommandTable = GetFromTempStorage(CommandsInTemporaryStorageTableAddress);
	For Each DataProcessorCommand In CommandTable.FindRows(New Structure("ItemName", ItemName)) Do
		Return CommonUse.ValueTableRowToStructure(DataProcessorCommand);
	EndDo;
EndFunction

// For an internal use.
Procedure ExecuteAddinionalReportOrDataProcessors(ExternalObject, Val CommandID, CommandParameters, Val ScriptInSafeMode = False)
	
	If ScriptInSafeMode Then
		
		ExecuteScriptInSafeMode(ExternalObject, CommandParameters);
		
	Else
		
		If CommandParameters = Undefined Then
			
			ExternalObject.RunCommand(CommandID);
			
		Else
			
			ExternalObject.RunCommand(CommandID, CommandParameters);
			
		EndIf;
		
	EndIf;
	
EndProcedure

// For an internal use.
Procedure ExecuteCommandToAssignAdditionalReportOrDataProcessors(ExternalObject, Val CommandID, CommandParameters, DestinationObjects, Val ScriptInSafeMode = False)
	
	If ScriptInSafeMode Then
		
		ExecuteScriptInSafeMode(ExternalObject, CommandParameters, DestinationObjects);
		
	Else
		
		If CommandParameters = Undefined Then
			ExternalObject.RunCommand(CommandID, DestinationObjects);
		Else
			ExternalObject.RunCommand(CommandID, DestinationObjects, CommandParameters);
		EndIf;
		
	EndIf;
	
EndProcedure

// For an internal use.
Procedure ExecuteCommandCreateLinkedObjects(ExternalObject, Val CommandID, CommandParameters, DestinationObjects, ModifiedObject, Val ScriptInSafeMode = False)
	
	If ScriptInSafeMode Then
		
		CommandParameters.Insert("ModifiedObject", ModifiedObject);
		
		ExecuteScriptInSafeMode(ExternalObject, CommandParameters, DestinationObjects);
		
	Else
		
		If CommandParameters = Undefined Then
			ExternalObject.RunCommand(CommandID, DestinationObjects, ModifiedObject);
		Else
			ExternalObject.RunCommand(CommandID, DestinationObjects, ModifiedObject, CommandParameters);
		EndIf;
		
	EndIf;
	
EndProcedure

// For an internal use.
Procedure ExecuteCommandFormationOfPrintedForms(ExternalObject, Val CommandID, CommandParameters, DestinationObjects, Val ScriptInSafeMode = False)
	
	If ScriptInSafeMode Then
		
		ExecuteScriptInSafeMode(ExternalObject, CommandParameters, DestinationObjects);
		
	Else
		
		If CommandParameters = Undefined Then
			ExternalObject.Print(CommandID, DestinationObjects);
		Else
			ExternalObject.Print(CommandID, DestinationObjects, CommandParameters);
		EndIf;
		
	EndIf;
	
EndProcedure

// Runs command of additional report or processor from object.
Function ExecuteExternalObjectCommand(ExternalObject, CommandID, CommandParameters, ResultAddress)
	
	AdditionalInformationOnExternalObject = ExternalObject.ExternalDataProcessorInfo();
	
	DataProcessorKind = GetDataProcessorKindByKindStringPresentation(AdditionalInformationOnExternalObject.Type);
	
	TransmitParameters = (
		AdditionalInformationOnExternalObject.Property("SSLVersion")
		AND CommonUseClientServer.CompareVersions(AdditionalInformationOnExternalObject.SSLVersion, "1.2.1.4") >= 0);
	
	If Not CommandParameters.Property("ExecutionResult") OR TypeOf(CommandParameters.ExecutionResult) <> Type("Structure") Then
		CommandParameters.Insert("ExecutionResult", StandardSubsystemsClientServer.NewExecutionResult());
	EndIf;
	
	CommandDetails = AdditionalInformationOnExternalObject.Commands.Find(CommandID, "ID");
	If CommandDetails = Undefined Then
		
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Command %1 is not found.'"), CommandID);
		
	EndIf;
	IsScriptInSafeMode = (CommandDetails.Use = "ScriptInSafeMode");
	
	ModifiedObject = Undefined;
	
	If DataProcessorKind = Enums.AdditionalReportsAndDataProcessorsTypes.AdditionalInformationProcessor
		OR DataProcessorKind = Enums.AdditionalReportsAndDataProcessorsTypes.AdditionalReport
		OR DataProcessorKind = Enums.AdditionalReportsAndDataProcessorsTypes.BankClassifierImportProcessor
		OR DataProcessorKind = Enums.AdditionalReportsAndDataProcessorsTypes.BankExchangeProcessor
		OR DataProcessorKind = Enums.AdditionalReportsAndDataProcessorsTypes.ExchangeRatesImportProcessor
		OR DataProcessorKind = Enums.AdditionalReportsAndDataProcessorsTypes.SMSProvider Then
		
		ExecuteAddinionalReportOrDataProcessors(
			ExternalObject, CommandID,
			?(TransmitParameters, CommandParameters, Undefined),
			IsScriptInSafeMode);
		
	ElsIf DataProcessorKind = Enums.AdditionalReportsAndDataProcessorsTypes.CreatingLinkedObjects Then
		
		ModifiedObject = New Array;
		ExecuteCommandCreateLinkedObjects(
			ExternalObject, CommandID,
			?(TransmitParameters, CommandParameters, Undefined),
			CommandParameters.DestinationObjects,
			ModifiedObject,
			IsScriptInSafeMode);
		
	ElsIf DataProcessorKind = Enums.AdditionalReportsAndDataProcessorsTypes.ObjectFill
		OR DataProcessorKind = Enums.AdditionalReportsAndDataProcessorsTypes.Report
		OR DataProcessorKind = Enums.AdditionalReportsAndDataProcessorsTypes.PrintForm Then
		
		DestinationObjects = Undefined;
		CommandParameters.Property("DestinationObjects", DestinationObjects);
		
		If DataProcessorKind = Enums.AdditionalReportsAndDataProcessorsTypes.PrintForm Then
			
			// Only random print here. printing to MXL is executed using the Printing subsystem.
			ExecuteCommandFormationOfPrintedForms(
				ExternalObject, CommandID,
				?(TransmitParameters, CommandParameters, Undefined),
				DestinationObjects,
				IsScriptInSafeMode);
			
		Else
			
			ExecuteCommandToAssignAdditionalReportOrDataProcessors(
				ExternalObject, CommandID,
				?(TransmitParameters, CommandParameters, Undefined),
				DestinationObjects,
				IsScriptInSafeMode);
			
			If DataProcessorKind = Enums.AdditionalReportsAndDataProcessorsTypes.ObjectFill Then
				ModifiedObject = DestinationObjects;
			EndIf;
		EndIf;
		
	EndIf;
	
	StandardSubsystemsClientServer.NotifyDynamicLists(CommandParameters.ExecutionResult, ModifiedObject);
	
	If TypeOf(ResultAddress) = Type("String") AND IsTempStorageURL(ResultAddress) Then
		PutToTempStorage(CommandParameters.ExecutionResult, ResultAddress);
	EndIf;
	
	Return CommandParameters.ExecutionResult;
	
EndFunction

// For an internal use.
Procedure ExecuteScriptInSafeMode(ExternalObject, CommandParameters, DestinationObjects = Undefined)
	
	ExtensionOfSafeMode = AdditionalReportsAndDataProcessorsInSafeModeService;
	
	ExternalObject = GetObjectOfExternalDataProcessor(CommandParameters.AdditionalInformationProcessorRef);
	CommandID = CommandParameters.CommandID;
	
	Script = ExternalObject.GenerateScript(CommandID, CommandParameters);
	SessionKey = AdditionalReportsAndDataProcessorsInSafeModeService.GenerateSessionKeyExpansionOfSafeMode(
		CommandParameters.AdditionalInformationProcessorRef);
	
	ExtensionOfSafeMode.ExecuteScriptSafeMode(
		SessionKey, Script, ExternalObject, CommandParameters, Undefined, DestinationObjects);
	
EndProcedure

#EndRegion

#Region Other

// For an internal use.
Function RegisterDataProcessor(Val Object, Val RegistrationParameters) Export
	
	KindAdditionalInformationProcessor = Enums.AdditionalReportsAndDataProcessorsTypes.AdditionalInformationProcessor;
	TypeAdditionalReport     = Enums.AdditionalReportsAndDataProcessorsTypes.AdditionalReport;
	ReportKind                   = Enums.AdditionalReportsAndDataProcessorsTypes.Report;
	
	// Receives processor files from the temporary storage,
	// tries to create processor object (external report) and receives information from the external processor object (report).
	
	If RegistrationParameters.DisableConflicts Then
		For Each ItemOfList In RegistrationParameters.Conflicting Do
			ConflictingObject = ItemOfList.Value.GetObject();
			ConflictingObject.Publication = AdditionalReportsAndDataProcessorsReUse.PublicationTypeForConflictProcessings();
			ConflictingObject.Write();
		EndDo;
	ElsIf RegistrationParameters.DisablePublishing Then 
		Object.Publication = AdditionalReportsAndDataProcessorsReUse.PublicationTypeForConflictProcessings();
	EndIf;
	
	Result = New Structure("ObjectName, StandardObjectName, Success, ObjectNameUsed, Conflicting , ErrorText, BriefErrorDescription");
	Result.ObjectNameUsed = False;
	Result.Success = False;
	If Object.IsNew() Then
		Result.StandardObjectName = Object.ObjectName;
	Else
		Result.StandardObjectName = CommonUse.ObjectAttributeValue(Object.Ref, "ObjectName");
	EndIf;
	
	RegistrationData = GetRegistrationData(Object, RegistrationParameters, Result);
	If RegistrationData = Undefined
		Or RegistrationData.Count() = 0
		Or ValueIsFilled(Result.ErrorText)
		Or ValueIsFilled(Result.BriefErrorDescription) Then
		Return Result;
	EndIf;
	
	// If the report is published, it is necessary to control the uniqueness of the object name under which the additional
	// report is registered in the system.
	If Object.Publication = Enums.AdditionalReportsAndDataProcessorsPublicationOptions.Used Then
		// Check name
		QueryText =
		"SELECT
		|	DirectoriesTable.Ref,
		|	DirectoriesTable.Presentation
		|FROM
		|	Catalog.AdditionalReportsAndDataProcessors AS DirectoriesTable
		|WHERE
		|	DirectoriesTable.ObjectName = &ObjectName
		|	AND &AdditReportCondition
		|	AND DirectoriesTable.Publication = VALUE(Enum.AdditionalReportsAndDataProcessorsPublicationOptions.Used)
		|	AND DirectoriesTable.DeletionMark = FALSE
		|	AND DirectoriesTable.Ref <> &Ref";
		
		AdditionalReportTypes = New Array;
		AdditionalReportTypes.Add(TypeAdditionalReport);
		AdditionalReportTypes.Add(ReportKind);
		
		Query = New Query;
		Query.SetParameter("ObjectName",     Result.ObjectName);
		Query.SetParameter("AdditionalReportTypes", AdditionalReportTypes);
		Query.SetParameter("Ref", Object.Ref);
		
		If RegistrationParameters.IsReport Then
			QueryText = StrReplace(QueryText, "&AdditReportCondition", "DirectoriesTable.Type IN (&AdditionalReportTypes)");
		Else
			QueryText = StrReplace(QueryText, "&AdditReportCondition", "NOT DirectoriesTable.Type IN (&AdditionalReportTypes)");
		EndIf;
		
		Query.Text = QueryText;
		
		SetPrivilegedMode(True);
		Conflicting = Query.Execute().Unload();
		SetPrivilegedMode(False);
		
		If Conflicting.Count() > 0 Then
			Result.ObjectNameUsed = True;
			Result.Conflicting = New ValueList;
			For Each TableRow In Conflicting Do
				Result.Conflicting.Add(TableRow.Ref, TableRow.Presentation);
			EndDo;
			Return Result;
		EndIf;
	EndIf;
	
	If RegistrationData.SafeMode
		OR Users.InfobaseUserWithFullAccess(, True) Then
		// do nothing
	Else
		Result.ErrorText = NStr("en = 'To connect data processor run in the unsafe mode, administrative rights are required.'");
		Return Result;
	EndIf;
	
	If Not Object.IsNew() AND RegistrationData.Type <> Object.Type Then
		Result.ErrorText = 
			StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Imported object kind (%1) does not correspond to the current one (%2).
			     |To import a new object, click Create.'"),
			String(RegistrationData.Type),
			String(Object.Type)
		);
		Return Result;
	ElsIf RegistrationParameters.IsReport <> (RegistrationData.Type = TypeAdditionalReport OR RegistrationData.Type = ReportKind) Then
		Result.ErrorText = NStr("en = 'Data processor kind from external data processor data does not correspond to its extension.'");
		Return Result;
	EndIf;
	
	Object.Description    = RegistrationData.Description;
	Object.Version          = RegistrationData.Version;
	
	If RegistrationData.Property("SSLVersion") Then
		If CommonUseClientServer.CompareVersions(RegistrationData.SSLVersion, "2.2.2.0") > 0 Then
			Object.PermissionsCompatibilityMode = Enums.AdditionalReportAndDataProcessorPermissionCompatibilityModes.Version_2_2_2;
		Else
			Object.PermissionsCompatibilityMode = Enums.AdditionalReportAndDataProcessorPermissionCompatibilityModes.Version_2_1_3;
		EndIf;
	Else
		Object.PermissionsCompatibilityMode = Enums.AdditionalReportAndDataProcessorPermissionCompatibilityModes.Version_2_1_3;
	EndIf;
	
	If RegistrationData.Property("SafeMode") Then
		Object.SafeMode = RegistrationData.SafeMode;
	EndIf;
	
	Object.Information      = RegistrationData.Information;
	Object.FileName        = RegistrationParameters.FileName;
	Object.ObjectName      = Result.ObjectName;
	
	Object.UsesVariantsStorage = False;
	If (RegistrationData.Type = TypeAdditionalReport) OR (RegistrationData.Type = ReportKind) Then
		If RegistrationData.VariantsStorage = "ReportsVariantsStorage"
			OR (Metadata.ReportsVariantsStorage <> Undefined
				AND Metadata.ReportsVariantsStorage.Name = "ReportsVariantsStorage") Then
			Object.UsesVariantsStorage = True;
		EndIf;
		RegistrationParameters.Property("DefineFormSettings", Object.DeepIntegrationWithReportForm);
	EndIf;
	
	// Another processor is imported (object name and processor kind is changed).
	If Object.IsNew() OR Object.ObjectName <> Result.ObjectName OR Object.Type <> RegistrationData.Type Then
		Object.Purpose.Clear();
		Object.Sections.Clear();
		Object.Type = RegistrationData.Type;
	EndIf;
	
	// If the destination is not filled in - set destination from the data processor.
	If Object.Purpose.Count() = 0
		AND Object.Type <> TypeAdditionalReport
		AND Object.Type <> KindAdditionalInformationProcessor Then
		
		If RegistrationData.Property("Purpose") Then
			AssignedMetadataObjects = AssignedMetadataObjectsByExternalObjectKind(Object.Type);
			
			For Each FullMetadataObjectName In RegistrationData.Purpose Do
				DotPosition = Find(FullMetadataObjectName, ".");
				If Mid(FullMetadataObjectName, DotPosition + 1) = "*" Then
					Search = New Structure("MetadataObjectKind", Left(FullMetadataObjectName, DotPosition - 1));
				Else
					Search = New Structure("FullMetadataObjectName", FullMetadataObjectName);
				EndIf;
				
				Found = AssignedMetadataObjects.FindRows(Search);
				For Each TableRow In Found Do
					PurposeRow = Object.Purpose.Add();
					PurposeRow.ObjectDestination = TableRow.ObjectDestination;
				EndDo;
			EndDo;
		EndIf;
		
		Object.Purpose.GroupBy("ObjectDestination", "");
		
	EndIf;
	
	Object.Commands.Clear();
	
	// Initializing commands
	
	For Each CommandDetails In RegistrationData.Commands Do
		
		If Not ValueIsFilled(CommandDetails.StartVariant) Then
			CommonUseClientServer.MessageToUser(
				StrReplace(NStr("en = 'The launch method is not defined for the ""%1"" command.'"), "%1", CommandDetails.Presentation));
		EndIf;
		
		Command = Object.Commands.Add();
		FillPropertyValues(Command, CommandDetails);
		
	EndDo;
	
	// Read permissions requested by the additional processor.
	Object.permissions.Clear();
	permissions = Undefined;
	If RegistrationData.Property("permissions", permissions) Then
		
		For Each Resolution In permissions Do
			
			XDTOType = Resolution.Type();
			
			TSRow = Object.permissions.Add();
			TSRow.TypePermissions = XDTOType.Name;
			
			Parameters = New Structure();
			
			For Each XDTOProperty In XDTOType.Properties Do
				
				Container = Resolution.GetXDTO(XDTOProperty.Name);
				
				If Container <> Undefined Then
					Parameters.Insert(XDTOProperty.Name, Container.Value);
				Else
					Parameters.Insert(XDTOProperty.Name);
				EndIf;
				
			EndDo;
			
			TSRow.Parameters = New ValueStorage(Parameters);
			
		EndDo;
		
	EndIf;
	
	Object.Responsible = Users.CurrentUser();
	
	Result.Success = True;
	
	Return Result;
	
EndFunction

// For an internal use.
Function GetRegistrationData(Val Object, Val RegistrationParameters, Val RegistrationResult)
	EventHandlers = CommonUse.ServiceEventProcessor(
		"StandardSubsystems.AdditionalReportsAndDataProcessors\OnGetOfRegistrationData");
	
	RegistrationData = New Structure;
	
	StandardProcessing = True;
	
	For Each Handler In EventHandlers Do
		Handler.Module.OnGetOfRegistrationData(Object, RegistrationData, StandardProcessing);
	EndDo;
	
	If StandardProcessing Then
		OnGetOfRegistrationData(Object, RegistrationData, RegistrationParameters, RegistrationResult);
	EndIf;
	
	Return RegistrationData;
EndFunction

// For an internal use.
Procedure OnGetOfRegistrationData(Object, RegistrationData, RegistrationParameters, RegistrationResult)
	
	// Enable and receive name under which object will be enabled.
	Manager = ?(RegistrationParameters.IsReport, ExternalReports, ExternalDataProcessors);
	
	#If ThickClientOrdinaryApplication Then
		RegistrationResult.ObjectName = GetTempFileName();
		BinaryData = GetFromTempStorage(RegistrationParameters.DataProcessorDataAddress);
		BinaryData.Write(RegistrationResult.ObjectName);
	#Else
		UnsafeOperation = New UnsafeOperationProtectionDescription;
		UnsafeWarnings = True;
		If Not RegistrationParameters.Property("UnsafeOperation", UnsafeWarnings) Then
			UnsafeWarnings = True;		
		EndIf;	
		UnsafeOperation.UnsafeOperationWarnings = UnsafeWarnings;
		RegistrationResult.ObjectName = TrimAll(Manager.Connect(RegistrationParameters.DataProcessorDataAddress, , True, UnsafeOperation));
	#EndIf
	
	ErrorInfo = Undefined;
	Try
		// Getting info on external data processor.
		ExternalObject = Manager.Create(RegistrationResult.ObjectName);
		ExternalObjectMetadata = ExternalObject.Metadata();
		
		ExternalDataProcessorInfo = ExternalObject.ExternalDataProcessorInfo();
		CommonUseClientServer.ExpandStructure(RegistrationData, ExternalDataProcessorInfo, True);
	Except
		ErrorInfo = ErrorInfo();
	EndTry;
	If ErrorInfo <> Undefined Then
		If RegistrationParameters.IsReport Then
			ErrorText = NStr("en = 'Unable to enable additional report from file.
			                 |It might not be compatible with the application version.'");
		Else
			ErrorText = NStr("en = 'Unable to enable additional processor from file.
			                 |It may not be suitable for this version of the application.'");
		EndIf;
		RegistrationResult.ErrorText = ErrorText;
		RegistrationResult.BriefErrorDescription = BriefErrorDescription(ErrorInfo);
		ErrorText = ErrorText + Chars.LF + Chars.LF + NStr("en = 'Technical information:'") + Chars.LF;
		WriteError(Object.Ref, ErrorText + DetailErrorDescription(ErrorInfo));
		Return;
	EndIf;
	
	If RegistrationData.Description = Undefined OR RegistrationData.Information = Undefined Then
		If RegistrationData.Description = Undefined Then
			RegistrationData.Description = ExternalObjectMetadata.Presentation();
		EndIf;
		If RegistrationData.Information = Undefined Then
			RegistrationData.Information = ExternalObjectMetadata.Comment;
		EndIf;
	EndIf;
	
	If TypeOf(RegistrationData.Type) <> Type("EnumRef.AdditionalReportsAndDataProcessorsTypes") Then
		RegistrationData.Type = Enums.AdditionalReportsAndDataProcessorsTypes[RegistrationData.Type];
	EndIf;
	
	RegistrationData.Insert("VariantsStorage");
	If RegistrationData.Type = Enums.AdditionalReportsAndDataProcessorsTypes.AdditionalReport Then
		If ExternalObjectMetadata.VariantsStorage <> Undefined Then
			RegistrationData.VariantsStorage = ExternalObjectMetadata.VariantsStorage.Name;
		EndIf;
	EndIf;
	
	RegistrationData.Commands.Columns.Add("StartVariant");
	
	For Each CommandDetails In RegistrationData.Commands Do
		CommandDetails.StartVariant = Enums.AdditionalDataProcessorsCallMethods[CommandDetails.Use];
	EndDo;
	
	#If ThickClientOrdinaryApplication Then
		RegistrationResult.ObjectName = ExternalObjectMetadata.Name;
	#EndIf
EndProcedure

// Only for internal use.
//
Function AdditionalReportsAndDataProcessorsCount() Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	AdditionalReportsAndDataProcessors.Description
	|FROM
	|	Catalog.AdditionalReportsAndDataProcessors AS AdditionalReportsAndDataProcessors";
	
	Result = Query.Execute().Unload();
	Return Result.Count();
	
EndFunction

#EndRegion

#Region WorkingWithForms

// Description of the instruction to add items of conditional design.
Function ConditionalDesignInstruction() Export
	Return New Structure("Filters, Appearance, Fields", New Map, New Map, "");
EndFunction

// Adds an item of conditional design according to description in the instruction.
Function AddConditionalAppearanceItem(Form, ConditionalDesignInstruction) Export
	DCConditionalAppearanceItem = Form.ConditionalAppearance.Items.Add();
	DCConditionalAppearanceItem.Use = True;
	
	For Each KeyAndValue In ConditionalDesignInstruction.Filters Do
		DCFilterItem = DCConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
		DCFilterItem.LeftValue = New DataCompositionField(KeyAndValue.Key);
		Setting = KeyAndValue.Value;
		Type = TypeOf(Setting);
		If Type = Type("Structure") Then
			DCFilterItem.ComparisonType = DataCompositionComparisonType[Setting.Kind];
			DCFilterItem.RightValue = Setting.Value;
		ElsIf Type = Type("Array") Then
			DCFilterItem.ComparisonType = DataCompositionComparisonType.InList;
			DCFilterItem.RightValue = Setting;
		ElsIf Type = Type("DataCompositionComparisonType") Then
			DCFilterItem.ComparisonType = Setting;
		Else
			DCFilterItem.ComparisonType = DataCompositionComparisonType.Equal;
			DCFilterItem.RightValue = Setting;
		EndIf;
		DCFilterItem.Application = DataCompositionFilterApplicationType.Items;
	EndDo;
	
	For Each KeyAndValue In ConditionalDesignInstruction.Appearance Do
		DCConditionalAppearanceItem.Appearance.SetParameterValue(
			New DataCompositionParameter(KeyAndValue.Key),
			KeyAndValue.Value);
	EndDo;
	
	Fields = ConditionalDesignInstruction.Fields;
	If TypeOf(Fields) = Type("String") Then
		Fields = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(Fields, ",");
	EndIf;
	For Each Field In Fields Do
		DCField = DCConditionalAppearanceItem.Fields.Items.Add();
		DCField.Use = True;
		DCField.Field = New DataCompositionField(Field);
	EndDo;
	
	Return DCConditionalAppearanceItem;
EndFunction

#EndRegion

#EndRegion
