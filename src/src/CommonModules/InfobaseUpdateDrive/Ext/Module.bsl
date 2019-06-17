////////////////////////////////////////////////////////////////////////////////
// Infobase update
//
////////////////////////////////////////////////////////////////////////////////

#Region Public

// Fills out basic information about the library or default configuration.
// Library which name matches configuration name in metadata is defined as default configuration.
// 
// Parameters:
//  Definition - Structure - information about the library:
//
//   Name                 - String - name of the library, for example, "StandardSubsystems".
//   Version              - String - version in the format of 4 digits, for example, "2.1.3.1".
//
//   RequiredSubsystems - Array - names of other libraries (String) on which this library depends.
//                                  Update handlers of such libraries should
//                                  be called before update handlers of this library.
//                                  IN case of circular dependencies or, on
//                                  the contrary, absence of any dependencies, call out
//                                  procedure of update handlers is defined by the order of modules addition in
//                                  procedure WhenAddingSubsystems of common module ConfigurationSubsystemsOverridable.
//
Procedure OnAddSubsystem(Definition) Export
	
	Definition.Name		= "Drive";
	Definition.Version	= "1.1.5.11";
	
EndProcedure

#EndRegion

#Region Internal

// Adds to the list of
// procedures (IB data update handlers) for all supported versions of the library or configuration.
// Appears before the start of IB data update to build up the update plan.
//
// Parameters:
//  Handlers - ValueTable - See description
// of the fields in the procedure UpdateResults.UpdateHandlersNewTable
//
// Example of adding the procedure-processor to the list:
//  Handler = Handlers.Add();
//  Handler.Version              = "1.0.0.0";
//  Handler.Procedure           = "IBUpdate.SwitchToVersion_1_0_0_0";
//  Handler.ExclusiveMode    = False;
//  Handler.Optional        = True;
// 
Procedure OnAddUpdateHandlers(Handlers) Export
	
	Handler = Handlers.Add();
	Handler.Version			= "1.0.0.1";
	Handler.InitialFilling	= True;
	Handler.Procedure		= "InfobaseUpdateDrive.FirstLaunch";
	
	Handler = Handlers.Add();
	Handler.Version			= "1.1.0.1";
	Handler.PerformModes	= "Promptly";
	Handler.Procedure		= "Catalogs.ContactInformationTypes.SetPropertiesForCompanyWebpagePredefinedItem";
	
	Handler = Handlers.Add();
	Handler.Version			= "1.1.0.1";
	Handler.PerformModes	= "Promptly";
	Handler.Procedure		= "Catalogs.Counterparties.SetPropertiesForRetailCustomerPredefinedItem";
	
	Handler = Handlers.Add();
	Handler.Version			= "1.1.0.1";
	Handler.PerformModes	= "Promptly";
	Handler.Procedure		= "Documents.ShiftClosure.VATOutputEntriesGeneration";
	
	Handler = Handlers.Add();
	Handler.Version			= "1.1.0.1";
	Handler.PerformModes	= "Promptly";
	Handler.Procedure		= "Documents.SalesInvoice.VATOutputEntriesReGeneration";
	
	Handler = Handlers.Add();
	Handler.Version			= "1.1.0.1";
	Handler.PerformModes	= "Promptly";
	Handler.Procedure		= "Documents.CreditNote.FillingInventoryTotal";
	
	Handler = Handlers.Add();
	Handler.Version			= "1.1.0.1";
	Handler.PerformModes	= "Promptly";
	Handler.Procedure		= "Documents.DebitNote.FillingInventoryTotal";
	
	Handler = Handlers.Add();
	Handler.Version			= "1.1.0.1";
	Handler.PerformModes	= "Promptly";
	Handler.Procedure		= "Documents.GoodsReturn.ProcessDataToUpgradeToNewVersion";	
	
	Handler = Handlers.Add();
	Handler.Version			= "1.1.0.1";
	Handler.PerformModes	= "Promptly";
	Handler.Procedure		= "Catalogs.DefaultGLAccounts.DeleteDublicateBankFeesCreditAccount";
	
	Handler = Handlers.Add();
	Handler.Version			= "1.1.0.1";
	Handler.PerformModes	= "Promptly";
	Handler.Procedure		= "Catalogs.CashierWorkplaceSettings.RepairCWPSettings";

	Handler = Handlers.Add();
	Handler.Version			= "1.1.0.1";
	Handler.PerformModes	= "Promptly";
	Handler.Procedure		= "AccumulationRegisters.AccountsPayable.ProcessDataToUpgradeToNewVersion";
	
	Handler = Handlers.Add();
	Handler.Version			= "1.1.0.1";
	Handler.PerformModes	= "Promptly";
	Handler.Procedure		= "AccumulationRegisters.AccountsReceivable.ProcessDataToUpgradeToNewVersion";
	
	Handler = Handlers.Add();
	Handler.Version			= "1.1.0.1";
	Handler.PerformModes	= "Promptly";
	Handler.Procedure		= "AccumulationRegisters.IncomeAndExpenses.ProcessDataToUpgradeToNewVersion";
	
	Handler = Handlers.Add();
	Handler.Version			= "1.1.0.1";
	Handler.PerformModes	= "Promptly";
	Handler.Procedure		= "AccumulationRegisters.Inventory.ProcessDataToUpgradeToNewVersion";
	
	Handler = Handlers.Add();
	Handler.Version			= "1.1.0.1";
	Handler.PerformModes	= "Promptly";
	Handler.Procedure		= "AccountingRegisters.AccountingJournalEntries.ProcessDataToUpgradeToNewVersion";
	
	Handler = Handlers.Add();
	Handler.Version			= "1.1.1.2";
	Handler.PerformModes	= "Promptly";
	Handler.Procedure		= "AccumulationRegisters.Sales.ExcludeVATAmount";
	
	Handler = Handlers.Add();
	Handler.Version			= "1.1.1.2";
	Handler.PerformModes	= "Promptly";
	Handler.Procedure		= "AccumulationRegisters.Purchases.ExcludeVATAmount";
	
	Handler = Handlers.Add();
	Handler.Version			= "1.1.1.2";
	Handler.PerformModes	= "Promptly";
	Handler.Procedure		= "AccumulationRegisters.SalesTarget.ExcludeVATAmount";
	
	Handler = Handlers.Add();
	Handler.Version			= "1.1.1.2";
	Handler.PerformModes	= "Promptly";
	Handler.Procedure		= "InformationRegisters.OrderPayments.ProcessDataToUpgradeToNewVersion";
	
	Handler = Handlers.Add();
	Handler.Version			= "1.1.1.2";
	Handler.PerformModes	= "Promptly";
	Handler.Procedure		= "InformationRegisters.OrdersPaymentSchedule.ProcessDataToUpgradeToNewVersion";
	
	Handler = Handlers.Add();
	Handler.Version			= "1.1.1.2";
	Handler.PerformModes	= "Promptly";
	Handler.Procedure		= "InformationRegisters.PaymentsSchedule.ProcessDataToUpgradeToNewVersion";
	
	Handler = Handlers.Add();
	Handler.Version			= "1.1.1.4";
	Handler.PerformModes	= "Promptly";
	Handler.Procedure		= "Catalogs.TaxTypes.FillPredefinedItemsData";
	
	Handler = Handlers.Add();
	Handler.Version			= "1.1.1.4";
	Handler.PerformModes	= "Promptly";
	Handler.Procedure		= "Catalogs.VATRates.FillPredefinedItemsData";
	
	Handler = Handlers.Add();
	Handler.Version			= "1.1.1.5";
	Handler.PerformModes	= "Promptly";
	Handler.Procedure		= "Catalogs.Counterparties.SetPropertiesForRetailCustomerPredefinedItem";
	
	Handler = Handlers.Add();
	Handler.Version			= "1.1.1.7";
	Handler.PerformModes	= "Promptly";
	Handler.Procedure		= "Documents.TaxInvoiceIssued.ProcessDataToUpgradeToNewVersion";
	
	Handler = Handlers.Add();
	Handler.Version			= "1.1.1.7";
	Handler.PerformModes	= "Promptly";
	Handler.Procedure		= "Documents.TaxInvoiceReceived.ProcessDataToUpgradeToNewVersion";
	
	Handler = Handlers.Add();
	Handler.Version			= "1.1.1.7";
	Handler.PerformModes	= "Promptly";
	Handler.Procedure		= "AccumulationRegisters.VATOutput.ProcessDataToUpgradeToNewVersion";
	
	Handler = Handlers.Add();
	Handler.Version			= "1.1.1.7";
	Handler.PerformModes	= "Promptly";
	Handler.Procedure		= "AccumulationRegisters.VATInput.ProcessDataToUpgradeToNewVersion";
	
	Handler = Handlers.Add();
	Handler.Version			= "1.1.1.7";
	Handler.PerformModes	= "Promptly";
	Handler.Procedure		= "AccumulationRegisters.VATIncurred.ProcessDataToUpgradeToNewVersion";
	
	Handler = Handlers.Add();
	Handler.Version			= "1.1.2.2";
	Handler.PerformModes	= "Promptly";
	Handler.Procedure		= "Documents.PaymentExpense.ProcessDataToUpgradeToNewVersion";
	
	Handler = Handlers.Add();
	Handler.Version			= "1.1.3.1";
	Handler.PerformModes	= "Promptly";
	Handler.Procedure		= "Catalogs.BankAccounts.ProcessDataToUpgradeToNewVersion";
		
	Handler = Handlers.Add();
	Handler.Version			= "1.1.4.1";
	Handler.PerformModes	= "Promptly";
	Handler.Procedure		= "InformationRegisters.QuotationStatuses.ProcessDataToUpgradeToNewVersion";

	Handler = Handlers.Add();
	Handler.Version			= "1.1.4.1";
	Handler.PerformModes	= "Promptly";
	Handler.Procedure		= "InformationRegisters.TasksForUpdatingStatuses.ProcessDataToUpgradeToNewVersion";

	Handler = Handlers.Add();
	Handler.Version			= "1.1.4.1";
	Handler.PerformModes	= "Promptly";
	Handler.Procedure		= "AccumulationRegisters.InvoicesAndOrdersPayment.ProcessDataToUpgradeToNewVersion";
	
	Handler = Handlers.Add();
	Handler.Version			= "1.1.4.1";
	Handler.PerformModes	= "Promptly";
	Handler.Procedure		= "Catalogs.ShippingAddresses.ShippingAddresses_SetKindProperties";
	
	Handler = Handlers.Add();
	Handler.Version			= "1.1.4.2";
	Handler.PerformModes	= "Promptly";
	Handler.Procedure		= "InformationRegisters.TasksForUpdatingStatuses.ProcessDataToUpgradeToNewVersion";
	
	Handler = Handlers.Add();
	Handler.Version			= "1.1.4.2";
	Handler.PerformModes	= "Promptly";
	Handler.Procedure		= "AccumulationRegisters.AccountsPayable.ProcessDataToUpgradeToNewVersion";	
	
	Handler = Handlers.Add();
	Handler.Version			= "1.1.4.2";
	Handler.PerformModes	= "Promptly";
	Handler.Procedure		= "InformationRegisters.UsingPaymentTermsInDocuments.ProcessDataToUpgradeToNewVersion";
	
	Handler = Handlers.Add();
	Handler.Version			= "1.1.4.2";
	Handler.PerformModes	= "Promptly";
	Handler.Procedure		= "AccumulationRegisters.Inventory.FillCorrAttributes";
	
	Handler = Handlers.Add();
	Handler.Version			= "1.1.4.3";
	Handler.PerformModes	= "Promptly";
	Handler.Procedure		= "InfobaseUpdateDrive.FillPredefinedPeripheralsDrivers";
	
	Handler = Handlers.Add();
	Handler.Version			= "1.1.4.4";
	Handler.PerformModes	= "Promptly";
	Handler.Procedure		= "Documents.GoodsIssue.FillOperationType";
	
	Handler = Handlers.Add();
	Handler.Version			= "1.1.4.4";
	Handler.PerformModes	= "Promptly";
	Handler.Procedure		= "Documents.GoodsReceipt.FillOperationType";
	
	Handler = Handlers.Add();
	Handler.Version			= "1.1.4.4";
	Handler.PerformModes	= "Promptly";
	Handler.Procedure		= "AccumulationRegisters.PaymentCalendar.ProcessDataToUpgradeToNewVersion";
	
	Handler = Handlers.Add();
	Handler.Version			= "1.1.5.2";
	Handler.PerformModes	= "Promptly";
	Handler.Procedure		= "ContactInformationDrive.Leads_SetKindProperties";
	
	Handler = Handlers.Add();
	Handler.Version			= "1.1.5.2";
	Handler.PerformModes	= "Promptly";
	Handler.Procedure		= "ChartsOfCharacteristicTypes.UserSettings.ProcessDataToUpgradeToNewVersion";
	
	Handler = Handlers.Add();
	Handler.Version			= "1.1.5.5";
	Handler.PerformModes	= "Promptly";
	Handler.Procedure		= "AccumulationRegisters.Quotations.ProcessDataToUpgradeToNewVersion";
	
	Handler = Handlers.Add();
	Handler.Version			= "1.1.5.6";
	Handler.PerformModes	= "Promptly";
	Handler.Procedure		= "Documents.SupplierInvoice.FillNewGLAccounts";
	
	Handler = Handlers.Add();
	Handler.Version			= "1.1.5.6";
	Handler.PerformModes	= "Promptly";
	Handler.Procedure		= "Documents.Production.FillNewGLAccounts";
	
	Handler = Handlers.Add();
	Handler.Version			= "1.1.5.6";
	Handler.PerformModes	= "Promptly";
	Handler.Procedure		= "Documents.AdditionalExpenses.FillNewGLAccounts";
	
	Handler = Handlers.Add();
	Handler.Version			= "1.1.5.6";
	Handler.PerformModes	= "Promptly";
	Handler.Procedure		= "Documents.AccountSalesFromConsignee.FillNewGLAccounts";
	
	Handler = Handlers.Add();
	Handler.Version			= "1.1.5.6";
	Handler.PerformModes	= "Promptly";
	Handler.Procedure		= "Documents.CostAllocation.FillNewGLAccounts";
	
	Handler = Handlers.Add();
	Handler.Version			= "1.1.5.6";
	Handler.PerformModes	= "Promptly";
	Handler.Procedure		= "Documents.CustomsDeclaration.FillNewGLAccounts";
	
	Handler = Handlers.Add();
	Handler.Version			= "1.1.5.6";
	Handler.PerformModes	= "Promptly";
	Handler.Procedure		= "Documents.CreditNote.FillNewGLAccounts";
	
	Handler = Handlers.Add();
	Handler.Version			= "1.1.5.6";
	Handler.PerformModes	= "Promptly";
	Handler.Procedure		= "Documents.DebitNote.FillNewGLAccounts";
	
	Handler = Handlers.Add();
	Handler.Version			= "1.1.5.6";
	Handler.PerformModes	= "Promptly";
	Handler.Procedure		= "Documents.InventoryIncrease.FillNewGLAccounts";
	
	Handler = Handlers.Add();
	Handler.Version			= "1.1.5.6";
	Handler.PerformModes	= "Promptly";
	Handler.Procedure		= "Documents.InventoryWriteOff.FillNewGLAccounts";
	
	Handler = Handlers.Add();
	Handler.Version			= "1.1.5.7";
	Handler.PerformModes	= "Promptly";
	Handler.Procedure		= "Documents.InventoryReservation.FillNewGLAccounts";
	
	Handler = Handlers.Add();
	Handler.Version			= "1.1.5.7";
	Handler.PerformModes	= "Promptly";
	Handler.Procedure		= "Documents.ProductReturn.FillNewGLAccounts";
	
	Handler = Handlers.Add();
	Handler.Version			= "1.1.5.7";
	Handler.PerformModes	= "Promptly";
	Handler.Procedure		= "Documents.SalesSlip.FillNewGLAccounts";
	
	Handler = Handlers.Add();
	Handler.Version			= "1.1.5.7";
	Handler.PerformModes	= "Promptly";
	Handler.Procedure		= "Documents.ShiftClosure.FillNewGLAccounts";
	
	Handler = Handlers.Add();
	Handler.Version			= "1.1.5.8";
	Handler.PerformModes	= "Promptly";
	Handler.Procedure		= "Documents.OpeningBalanceEntry.FillNewGLAccounts";
	
	Handler = Handlers.Add();
	Handler.Version			= "1.1.5.9";
	Handler.PerformModes	= "Promptly";
	Handler.Procedure		= "Documents.FixedAssetRecognition.FillNewGLAccounts";
	
	Handler = Handlers.Add();
	Handler.Version			= "1.1.5.9";
	Handler.PerformModes	= "Promptly";
	Handler.Procedure		= "Documents.SubcontractorReport.FillNewGLAccounts";
	
	Handler = Handlers.Add();
	Handler.Version			= "1.1.5.10";
	Handler.PerformModes	= "Promptly";
	Handler.Procedure		= "Documents.GoodsIssue.FillNewGLAccounts";
	
	Handler = Handlers.Add();
	Handler.Version			= "1.1.5.10";
	Handler.PerformModes	= "Promptly";
	Handler.Procedure		= "Documents.GoodsReceipt.FillNewGLAccounts";
	
	Handler = Handlers.Add();
	Handler.Version			= "1.1.5.10";
	Handler.PerformModes	= "Promptly";
	Handler.Procedure		= "Documents.SalesInvoice.FillNewGLAccounts";
	
	Handler = Handlers.Add();
	Handler.Version			= "1.1.5.10";
	Handler.PerformModes	= "Promptly";
	Handler.Procedure		= "Documents.InventoryTransfer.FillNewGLAccounts";
	
	Handler = Handlers.Add();
	Handler.Version			= "1.1.5.11";
	Handler.PerformModes	= "Promptly";
	Handler.Procedure		= "Documents.SalesOrder.FillNewGLAccounts";
	
	Handler = Handlers.Add();
	Handler.Version			= "1.1.5.6";
	Handler.PerformModes	= "Promptly";
	Handler.Procedure		= "Documents.WorkOrder.ChangeSalesOrderEmptyRefToUndefined";
	
EndProcedure

// Called before the procedures-handlers of IB data update.
//
Procedure BeforeInformationBaseUpdating() Export
	
	
	
EndProcedure

// Called after the completion of IB data update.
//		
// Parameters:
//   PreviousVersion       - String - version before update. 0.0.0.0 for an empty IB.
//   CurrentVersion          - String - version after update.
//   ExecutedHandlers - ValueTree - list of completed
//                                             update procedures-handlers grouped by version number.
//   PutReleaseNotes - Boolean - (return value) if
//                                you set True, then form with events description will be output. By default True.
//   ExclusiveMode           - Boolean - True if the update was executed in the exclusive mode.
//		
// Example of bypass of executed update handlers:
//		
// For Each Version From ExecutedHandlers.Rows Cycle
//		
// 	If Version.Version =
// 		 * Then Ha//ndler that can be run every time the version changes.
// 	Otherwise,
// 		 Handler runs for a definite version.
// 	EndIf;
//		
// 	For Each Handler From Version.Rows
// 		Cycle ...
// 	EndDo;
//		
// EndDo;
//
Procedure AfterInformationBaseUpdate(Val PreviousVersion, Val CurrentVersion,
		Val ExecutedHandlers, PutReleaseNotes, ExclusiveMode) Export
	
	SetUpdateConfigurationPackage();
	
EndProcedure

// Called when you prepare a tabular document with description of changes in the application.
//
// Parameters:
//   Template - SpreadsheetDocument - description of update of all libraries and the configuration.
//           You can append or replace the template.
//          See also common template ReleaseNotes.
//
Procedure OnPreparationOfUpdatesDescriptionTemplate(Val Template) Export
	
EndProcedure

// Adds procedure-processors of transition from another application to the list (with another configuration name).
// For example, for the transition between different but related configurations: base -> prof -> corp.
// Called before the beginning of the IB data update.
//
// Parameters:
//  Handlers - ValueTable - with columns:
//    * PreviousConfigurationName - String - name of the configuration, with which the transition is run;
//    * Procedure                 - String - full name of the procedure-processor of the transition from the
//                                  PreviousConfigurationName application. ForExample, UpdatedERPInfobase.FillExportPolicy
//                                  is required to be export.
//
// Example of adding the procedure-processor to the list:
//  Handler = Handlers.Add();
//  Handler.PreviousConfigurationName  = TradeManagement;
//  Handler.Procedure                  = ERPInfobaseUpdate.FillAccountingPolicy;
//
Procedure OnAddTransitionFromAnotherApplicationHandlers(Handlers) Export
	
	
	
EndProcedure

// Helps to override mode of the infobase data update.
// To use in rare (emergency) cases of transition that
// do not happen in a standard procedure of the update mode.
//
// Parameters:
//   DataUpdateMode - String - you can set one of the values in the handler:
//              InitialFilling     - if it is the first launch of an empty base (data field);
//              VersionUpdate        - if it is the first launch after the update of the data base configuration;
//              TransitionFromAnotherApplication - if first launch is run after the update of
// the data base configuration with changed name of the main configuration.
//
//   StandardProcessing  - Boolean - if you set False, then
//                                    a standard procedure of the update
//                                    mode fails and the DataUpdateMode value is used.
//
Procedure OnDefineDataUpdateMode(DataUpdateMode, StandardProcessing) Export
	
EndProcedure

// Called after all procedures-processors of transfer from another application (with another
// configuration name) and before beginning of the IB data update.
//
// Parameters:
//  PreviousConfigurationName    - String - name of configuration before transition.
//  PreviousConfigurationVersion - String - name of the previous configuration (before transition).
//  Parameters                    - Structure - 
//    * UpdateFromVersion   - Boolean - True by default. If you set
// False, only the mandatory handlers of the update will be run (with the * version).
//    * ConfigurationVersion           - String - version No after transition. 
//        By default it equals to the value of the configuration version in the metadata properties.
//        To run, for example, all update handlers from the PreviousConfigurationVersion version,
// you should set parameter value in PreviousConfigurationVersion.
//        To process all updates, set the 0.0.0.1 value.
//    * ClearInformationAboutPreviousConfiguration - Boolean - True by default. 
//        For cases when the previous configuration matches by name with the subsystem of the current configuration, set
//        False.
//
Procedure OnEndTransitionFromAnotherApplication(Val PreviousConfigurationName, Val PreviousConfigurationVersion, Parameters) Export
	
EndProcedure

#Region ConfigurationPackage

#Region FirstLaunchHandlers

// Procedure fills in empty IB.
//
Procedure FirstLaunch() Export
	
	BeginTransaction();
	
	// Fill the Calendar under BusinessCalendar.
	Calendar = DriveServer.GetFiveDaysCalendar();// Will be removed - 567
	If Calendar = Undefined Then
		
		CreateFiveDaysCalendar();
		Calendar = DriveServer.GetFiveDaysCalendar(); 
		
	EndIf;
	
	If Not CommonUseReUse.CanUseSeparatedData() Then
		Constants.ExtractFileTextsAtServer.Set(true);
	EndIf;
	
	If Not CommonUseReUse.DataSeparationEnabled() Then
		Constants.GlobalNumerationPrefix.Set(DataExchangeOverridable.InfobasePrefixByDefault());
	EndIf;
	
	// Fill in calculation and Earnings kinds parameters.
	FillCalculationParametersAndEarningKinds(); // Will be removed - 563
	
	FillFilterUserSettings();
	
	// Fill in structural units
	MainDepartment = Catalogs.BusinessUnits.MainDepartment.GetObject();
	MainDepartment.Company				= Catalogs.Companies.MainCompany;
	MainDepartment.StructuralUnitType	= Enums.BusinessUnitsTypes.Department;
	
	WriteCatalogObject(MainDepartment);
	
	DriveServer.SetUserSetting(MainDepartment.Ref, "MainDepartment");
	
	MainWarehouse = Catalogs.BusinessUnits.MainWarehouse.GetObject();
	MainWarehouse.Company				= Catalogs.Companies.MainCompany;
	MainWarehouse.StructuralUnitType	= Enums.BusinessUnitsTypes.Warehouse;
	
	WriteCatalogObject(MainWarehouse);
	
	DriveServer.SetUserSetting(MainWarehouse.Ref, "MainWarehouse");
	
	Constants.PlannedTotalsOptimizationDate.Set(EndOfMonth(AddMonth(CurrentSessionDate(), 1)));
	
	ContactInformationDrive.SetPropertiesPredefinedContactInformationTypes();
		
	// Fill in contracts forms.
	FillContractsForms(); // Will be removed - 568 and 698

	EquipmentManagerServerCallOverridable.RefreshSuppliedDrivers();
	
	Constants.UseFIFO.Set(True);
	Constants.UseWorkOrderStatuses.Set(True);
	
	CommitTransaction();
	
EndProcedure

#EndRegion

#Region BackgroundJobsProcedures

Procedure ExecuteFillByDefault(ParametersStructure, BackgroundJobStorageAddress = "") Export
	
	JobResult = JobResult();
	
	FillDataByDefaultFirstLaunch(ParametersStructure.ExtensionsLoaded, JobResult);
	
	PutToTempStorage(JobResult, BackgroundJobStorageAddress); 
	
EndProcedure

Procedure ExecuteLoadCountriesFromFirstLaunch(JobParameters, StorageAddress = "") Export
	
	JobResult = JobResult();
	JobResult.Insert("Countries", Undefined);
	
	Try
		JobResult.Countries = LoadCountriesFromFirstLaunch(JobParameters);
	Except
		JobResult.Done = False;
		JobResult.ErrorMessage = BriefErrorDescription(ErrorInfo());
	EndTry;
	
	PutToTempStorage(JobResult, StorageAddress);
	
EndProcedure

Procedure ExecuteFillPredefinedData(Parameters, BackgroundJobStorageAddress = "") Export
	
	JobResult = JobResult();
	
	BasePath	= "";
	FullPath	= Parameters.FullPath;
	
	If Parameters.Property("ZIP") Then
		
		ZIPFile = Parameters.ZIP;
	
		TemporaryFolderToUnpacking = GetTempFileName("");
		TemporaryZIPFile = GetTempFileName("zip"); 
		
		ZIPFile.Write(TemporaryZIPFile);
		
		Archive = New ZipFileReader();
		Archive.Open(TemporaryZIPFile);
		Archive.ExtractAll(TemporaryFolderToUnpacking, ZIPRestoreFilePathsMode.Restore);
		Archive.Close();
		
		BasePath = TemporaryFolderToUnpacking + "\";
		FullPath = BasePath + FullPath + "\data.xml";
		
	EndIf;
	
	UpdateConfigurationPackage = False;
	If Parameters.Property("UpdateConfigurationPackage") Then
		UpdateConfigurationPackage = Parameters.UpdateConfigurationPackage;
	EndIf;
	
	Try
		FillPredefinedData(FullPath, BasePath, UpdateConfigurationPackage, Parameters.ExtensionsLoaded, JobResult);
	Except
		JobResult.Done			= False;
		JobResult.ErrorMessage	= BriefErrorDescription(ErrorInfo());
	EndTry;
	
	PutToTempStorage(JobResult, BackgroundJobStorageAddress);
	
EndProcedure

Procedure ExecuteUpdateExtensions(ParametersStructure, BackgroundJobStorageAddress = "") Export
	
	ResultStructure = New Structure("Done, ErrorMessage", True, "");
	
	Try
		LoadExtensions(ParametersStructure, ResultStructure);
	Except
		ResultStructure.Done			= False;
		ResultStructure.ErrorMessage	= BriefErrorDescription(ErrorInfo());
	EndTry;
	
	PutToTempStorage(ResultStructure, BackgroundJobStorageAddress);
	
	
EndProcedure

#EndRegion

#Region ExportServiceProceduresAndFunctions

// Procedure creates a work schedule based on the business calendar the "Five-day working week" template
// 
Procedure CreateFiveDaysCalendar() Export
	
	BusinessCalendar = CalendarSchedules.FiveDaysBusinessCalendar();
	If BusinessCalendar = Undefined Then 
		Return;
	EndIf;
	
	If Not Catalogs.Calendars.FindByAttribute("BusinessCalendar", BusinessCalendar).IsEmpty() Then
		Return;
	EndIf;
	
	NewWorkSchedule = Catalogs.Calendars.CreateItem();
	NewWorkSchedule.Description = CommonUse.GetAttributeValue(BusinessCalendar, "Description");
	NewWorkSchedule.BusinessCalendar = BusinessCalendar;
	NewWorkSchedule.FillMethod = Enums.WorkScheduleFillingMethods.ByWeeks;
	NewWorkSchedule.StartDate = BegOfYear(CurrentSessionDate());
	NewWorkSchedule.ConsiderHolidays = False;
	
	// Fill in week cycle as five-day working week
	For DayNumber = 1 To 7 Do
		NewWorkSchedule.FillTemplate.Add().DayIncludedInSchedule = DayNumber <= 5;
	EndDo;
	
	UpdateResults.WriteData(NewWorkSchedule, True, True);
	
EndProcedure

// Procedure fills in the passed object catalog and outputs message.
// It is intended to invoke from procedures of filling and processing the infobase directories.
//
// Parameters:
//  CatalogObject - an object that required record.
//
Procedure WriteCatalogObject(CatalogObject, Inform = False) Export

	If Not CatalogObject.Modified() Then
		Return;
	EndIf;

	If CatalogObject.IsNew() Then
		If CatalogObject.IsFolder Then
			MessageStr = NStr("en = 'Group of catalog ""%1"" is created, code: ""%2"", name: ""%3""'") ;
		Else
			MessageStr = NStr("en = 'Item of catalog ""%1"" is created, code: ""%2"", name: ""%3""'") ;
		EndIf; 
	Else
		If CatalogObject.IsFolder Then
			MessageStr = NStr("en = 'Catalog group ""%1"" is processed, code: ""%2"", name: ""%3""'") ;
		Else
			MessageStr = NStr("en = 'Catalog item ""%1"" is processed, code: ""%2"", name: ""%3""'") ;
		EndIf; 
	EndIf;

	If CatalogObject.Metadata().CodeLength > 0 Then
		FullCode = CatalogObject.FullCode();
	Else
		FullCode = NStr("en = '<without code>'");
	EndIf; 
	MessageStr = StringFunctionsClientServer.SubstituteParametersInString(MessageStr, CatalogObject.Metadata().Synonym, FullCode, CatalogObject.Description);

	Try
		CatalogObject.Write();
		If Inform = True Then
			CommonUseClientServer.MessageToUser(MessageStr, CatalogObject);
		EndIf;

	Except

		MessageText = NStr("en = 'Cannot finish action: %1'");
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessageText, MessageStr);

		CommonUseClientServer.MessageToUser(MessageText);

		ErrorDescription = ErrorInfo();
		WriteLogEvent(MessageText, EventLogLevel.Error,,, ErrorDescription.Definition);

	EndTry;

EndProcedure

#EndRegion

#EndRegion

#EndRegion

#Region Private

#Region DefaultConfigurationPackage

Procedure FillDataByDefaultFirstLaunch(ExtensionsLoaded, ResultStructure)
	
	TemporaryDirectoryToUnpacking = GetTempFileName("") + "\";
	Path = TemporaryDirectoryToUnpacking + "default\";
	CreateDirectory(Path);
	
	WriteTemplateToDisk(Path, "data.xml", "DefaultDataXML");
	WriteTemplateToDisk(Path, "order_statuses.xml", "DefaultOrderStatuses");
	WriteTemplateToDisk(Path, "default_gl_accounts.xml", "DefaultGLAccounts");
	
	DataXMLFilePath = Path + "data.xml";
	
	UpdateConfiguration = Constants.FirstLaunchPassed.Get();
	
	FillPredefinedData(DataXMLFilePath, TemporaryDirectoryToUnpacking, UpdateConfiguration, ExtensionsLoaded, ResultStructure, False);
	
EndProcedure

Procedure WriteTemplateToDisk(Path, FileName, TemplateName)
	
	Template = DataProcessors.FirstLaunch.GetTemplate(TemplateName);
	Template.Write(Path + FileName);
	
EndProcedure

#EndRegion

#Region ConfigurationPackage

#Region Countries

Function LoadCountriesFromFirstLaunch(Parameters)
	
	ZIPFile = Parameters.ZIP;
	
	TemporaryFolderToUnpacking = GetTempFileName("");
	TemporaryZIPFile = GetTempFileName("zip");
	
	ZIPFile.Write(TemporaryZIPFile);

	Archive = New ZipFileReader();
	Archive.Open(TemporaryZIPFile);
	Archive.ExtractAll(TemporaryFolderToUnpacking, ZIPRestoreFilePathsMode.Restore);
	Archive.Close();
	
	Countries = GetCountries(TemporaryFolderToUnpacking);
	If Countries.Count() = 0 Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Unable to get xml file on path: %1.
				     |Check file format.'"),
				TemporaryFolderToUnpacking + "\countries.xml");
	EndIf;
	
	Return Countries;
EndFunction

Function GetCountries(PathToTemporaryFolder)
	
	Countries = New Array();
	
	PathToFile = PathToTemporaryFolder + "\countries.xml";
	If Not FileExist(PathToFile) Then
		Return Countries;
	EndIf;
	
	DOMDocument = DOMDocument(PathToFile);
	Resolver = DOMDocument.CreateNSResolver();
	XPathResult = DOMDocument.EvaluateXPathExpression("//xmlns:country", DOMDocument, Resolver);
	DOMElement = XPathResult.IterateNext();
	
	While DOMElement <> Undefined Do
		
		Country = New Structure();
		For Each Node In DOMElement.ChildNodes Do
			Country.Insert(Node.NodeName, Node.TextContent);
		EndDo;
		
		PathToCountryFile = PathToTemporaryFolder + "\" + Country.Folder;
		If FileExist(PathToCountryFile) Then
			Countries.Add(Country);
		EndIf;
		
		DOMElement = XPathResult.IterateNext();
	EndDo;
	
	Return Countries;
EndFunction

#EndRegion

#Region Extesions

Function GetExtesions(DOMDocument, ConfigurationPackagePath)
	
	Extesions = New Array();
	XPathResult = GetXPathResultByTagName(DOMDocument, "extension");
	
	DOMElement = XPathResult.IterateNext();
	While DOMElement <> Undefined Do
		
		ExtesionProperties = New Structure("Name, Data, Delete");
		
		PathToExtension = DOMElement.Attributes.GetNamedItem("path").NodeValue;
		FullPath = ConfigurationPackagePath + StrReplace(PathToExtension, "/", "\");
		
		ArrayOfString = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(PathToExtension, "/");
		ExtensionBinary = New BinaryData(FullPath);
		
		Action = DOMElement.Attributes.GetNamedItem("action").NodeValue;
		
		ExtesionProperties.Name = StrReplace(ArrayOfString[1], ".cfe", "");
		ExtesionProperties.Data = New ValueStorage(ExtensionBinary, New Deflation(9));
		ExtesionProperties.Delete = (Lower(Action) = "delete");
		
		Extesions.Add(ExtesionProperties);
		
		DOMElement = XPathResult.IterateNext();
	EndDo;
	
	Return Extesions;
	
EndFunction

Procedure LoadExtensions(ParametersStructure, ResultStructure)
	
	For Each ExternalExtension In ParametersStructure.ArrayOfExtensions Do
		
		Filter = New Structure("Name", ExternalExtension.Name);
		InternalExtensions = ConfigurationExtensions.Get(Filter);
		If InternalExtensions.Count() > 0 Then
			Extension = InternalExtensions[0];
		Else
			Extension = ConfigurationExtensions.Create();
		EndIf;
		
		Extension.SafeMode = False;
		CommonUse.ProtectDescriptionWithoutWarnings();
		Try
			ExtensionData = GetFromTempStorage(ExternalExtension.Address);
			Extension.Write(ExtensionData);
		Except
				ErrorDescription = ErrorDescription();
				WriteLogEvent(
					"InfobaseUpdate",
					EventLogLevel.Error,
					Metadata.CommonModules.InfobaseUpdateDrive,
					ExternalExtension.Name,
					ErrorDescription);
				Raise ErrorDescription;
		EndTry;
	EndDo;
	
EndProcedure

Procedure RunExtensionUpdateHandlers()
	
	Handlers = UpdateResults.NewUpdateHandlersTable();
	
	For Each CommonModule In Metadata.CommonModules Do
		If StrFind(CommonModule.Name, "_InfobaseUpdate") Then
			Execute(CommonModule.Name + ".OnAddUpdateExtensionHandlers(Handlers)");
		EndIf;
	EndDo;
	
	CurrentVersion = Metadata.Version;
	For Each Handler In Handlers Do
		If CommonUseClientServer.CompareVersions(CurrentVersion, Handler.Version) = 0 Then
			Execute(Handler.Procedure + "()");
		EndIf;
	EndDo;
	
EndProcedure

#EndRegion

// Fill predefined data from the confugation package file.
//
// Parameters:
//	PathToDataFile - String - Path to data.xml at server.
//	BasePath       - String   - Path to default folder of data.xml.
//	UpdateConfiguration - Boolean - It shows what configuration was updated.
//	ExtensionsLoaded    - Boolean - It shows what extensions loaded.
//	Result - Structure  - Array of extension including in this structure.
//	CheckVersion        - Boolean - Check versions in configuration package file.
//
Procedure FillPredefinedData(PathToDataFile, BasePath = "", UpdateConfiguration, ExtensionsLoaded = False, Result = Undefined, CheckVersion = True)
	
	DOMDocument = DOMDocument(PathToDataFile);
	
	If CheckVersion And Not VersionInConfigurationPackageIsCorrect(DOMDocument) Then
		Return;
	EndIf;
	
	Extensions = GetExtesions(DOMDocument, BasePath);
	If Not ExtensionsLoaded And Extensions.Count() > 0 Then
		Result.Insert("Extensions", Extensions);
		Return;
	ElsIf ExtensionsLoaded Then
		RunExtensionUpdateHandlers();
	EndIf;
	
	CreatedElements = CreatedElements();
	
	LoadDataXML(DOMDocument, BasePath);
	
	If UpdateConfiguration Then
		XPathResult = GetXPathResultByTagName(DOMDocument, "item[@initial_filling=""False""]"); // select only items for update
	Else
		XPathResult = GetXPathResultByTagName(DOMDocument, "item"); // select all items
	EndIf;
	
	DOMElement = XPathResult.IterateNext();
	While DOMElement <> Undefined Do
		
		NodeName = DOMElement.Attributes.GetNamedItem("item_type").NodeValue;
		
		If NodeName = "catalog" Then
			LoadCatalogs(DOMElement, CreatedElements);
		ElsIf NodeName = "constant" Then
			LoadConstants(DOMElement, CreatedElements);
		ElsIf NodeName = "data_processor" Then
			LoadDataProcessor(DOMElement, BasePath);
		ElsIf NodeName = "information_register" Then
			LoadInformationRegister(DOMElement, CreatedElements);
		ElsIf NodeName = "chart_of_accounts" Then
			LoadChartsOfAccounts(DOMElement);
		ElsIf NodeName = "sl_data_xml" Then
			DOMElement = XPathResult.IterateNext();
			Continue; // this node was already loaded in
		ElsIf NodeName = "DefaultLanguage" Then
			LanguageIsChanged = False;
			SetDefaultLanguage(DOMElement, LanguageIsChanged);
			Result.Insert("LanguageIsChanged", LanguageIsChanged);
		Else
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'There is no event handler for the node ""%1""'", CommonUseClientServer.MainLanguageCode()),
				NodeName);
			WriteLogException(ErrorDescription);
		EndIf;
		
		DOMElement = XPathResult.IterateNext();
	EndDo;
	
EndProcedure

#Region LoadDataFromXML

Procedure LoadDataXML(DOMDocument, BasePath)
	
	XPathResult = GetXPathResultByTagName(DOMDocument, "item[@item_type=""sl_data_xml""]");
	
	DOMElement = XPathResult.IterateNext();
	While DOMElement <> Undefined Do
		DataPath = DOMElement.Attributes.GetNamedItem("item_name").NodeValue;
		LocalPath = BasePath + StrReplace(DataPath, "/", "\");
		
		FillBySLDataXML(LocalPath);
		DOMElement = XPathResult.IterateNext();
	EndDo;
	
EndProcedure

Procedure LoadConstants(DOMElement, CreatedElements)
	
	ConstantName = DOMElement.Attributes.GetNamedItem("item_name").NodeValue;
	
	Try
		ConstantManager = Constants[ConstantName];
	Except
		ErrorDescription = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Can''t find constant ""%1"" in the configuration'", CommonUseClientServer.MainLanguageCode()),
			ConstantName);
			
		WriteLogException(ErrorDescription);
		Return;
	EndTry;
	
	CurrentConstantValue = ConstantManager.Get();
	ConstantValue = DOMElement.Attributes.GetNamedItem("value").NodeValue;
	
	NewValue = GetReferenceByValue(CurrentConstantValue, ConstantValue, CreatedElements);
	If NewValue = Undefined 
		And ConstantValue <> Undefined Then
		ErrorDescription = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Can''t find value ""%1"" for constant ""%2"" in the configuration'", CommonUseClientServer.MainLanguageCode()),
			ConstantValue,
			ConstantName);
			
		WriteLogException(ErrorDescription);
		Return;
	EndIf;
	
	Try
		ConstantManager.Set(NewValue);
	Except
		ErrorDescription = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Can''t set value ""%1"" for constant ""%2""'", CommonUseClientServer.MainLanguageCode()),
			ConstantValue,
			ConstantName);
			
		WriteLogException(ErrorDescription);
	EndTry;
	
EndProcedure

Procedure LoadCatalogs(DOMElement, CreatedElements)
	
	CatalogName = DOMElement.Attributes.GetNamedItem("item_name").NodeValue;
	
	Try
		CatalogManager = Catalogs[CatalogName];
	Except
		ErrorDescription = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Can''t find catalog ""%1"" in the configuration'", CommonUseClientServer.MainLanguageCode()),
			CatalogName);
			
		WriteLogException(ErrorDescription);
		Return;
	EndTry;
	
	ChildNodes = DomElement.ChildNodes;
	For Each Node In ChildNodes Do // elements in the catalog
	
		Attributes = New Structure();
		For Each Attribute In Node.ChildNodes Do // attribute of current element
			If ValueIsFilled(Attribute.LocalName) Then
				Attributes.Insert(Attribute.LocalName, Attribute.TextContent);
			EndIf;
		EndDo;
		
		Try
			ItemRef = Undefined;
			IsPredefinedElement = False;
			PredefinedKey = Undefined;
			
			Attributes.Property("Predefined", PredefinedKey);
			If ValueIsFilled(PredefinedKey) Then
				IsPredefinedElement = Boolean(PredefinedKey);
			EndIf;
			
			If IsPredefinedElement Then
				ItemRef = GetReferenceByValue(CatalogManager.EmptyRef(), Attributes["PredefinedDataName"], CreatedElements);
				PredefinedDataName = Attributes["PredefinedDataName"];
			Else
				ItemRef = GetReferenceByValue(CatalogManager.EmptyRef(), Attributes["Description"], CreatedElements);
			EndIf;
			
			If ItemRef = Undefined Then
				If Attributes.Property("Folder") = True Then
					Item = CatalogManager.CreateFolder();
				Else
					Item = CatalogManager.CreateItem();
				EndIf;
			Else
				Item = ItemRef.GetObject();
			EndIf;
			
			DeleteKeyInStructure(Attributes, "Predefined");
			DeleteKeyInStructure(Attributes, "PredefinedDataName");
			DeleteKeyInStructure(Attributes, "Folder");
			
			For Each Attribute In Attributes Do
				Item[Attribute.Key] = GetReferenceByValue(Item[Attribute.Key], Attribute.Value, CreatedElements)
			EndDo;
			
			Item.Write();
			
			AddCreatedElement(CreatedElements, Item);
		Except
			If IsPredefinedElement Then
				ErrorDescription = StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = 'Error on write predefined element ""%1"" in the catalog ""%2""'"),
					PredefinedDataName,
					CatalogName);
			Else
				ErrorDescription = StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = 'Error on write element ""%1"" in the catalog ""%2""'", CommonUseClientServer.MainLanguageCode()),
					Attributes["Description"],
					CatalogName);
			EndIf;
			
			WriteLogException(ErrorDescription);
		EndTry;
		
	EndDo;
	
EndProcedure

Procedure LoadDataProcessor(DOMElement, BasePath)
	
	DataProcessorPath = DOMElement.Attributes.GetNamedItem("item_name").NodeValue;
	
	LocalPath = BasePath + StrReplace(DataProcessorPath, "/", "\");
	BinaryData = New BinaryData(LocalPath);
	
	SubstringArray = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(DataProcessorPath, "\");
	
	DataProcessorFileName = SubstringArray.Get(SubstringArray.UBound());
	FileExtension = Upper(Right(DataProcessorFileName, 3));
	
	If FileExtension <> "ERF"
		And FileExtension <> "EPF" Then
		
		ErrorDescription = NStr("en = 'File extension ""%1"" does not match those of the external report (ERF) or data processor (EPF).'",
			CommonUseClientServer.MainLanguageCode());
			
		ErrorDescription = StringFunctionsClientServer.SubstituteParametersInString(ErrorDescription, FileExtension);
			
		WriteLogException(ErrorDescription);
		Return;
	EndIf;
	
	RegistrationParameters = New Structure();
	RegistrationParameters.Insert("DataProcessorDataAddress", PutToTempStorage(BinaryData));
	RegistrationParameters.Insert("DisableConflicts", False);
	RegistrationParameters.Insert("Success", False);
	RegistrationParameters.Insert("FileName", DataProcessorFileName);
	RegistrationParameters.Insert("IsReport", FileExtension = "ERF");
	RegistrationParameters.Insert("DisablePublishing", False);
	RegistrationParameters.Insert("UnsafeOperation", False);
	
	DataProcessor = Catalogs.AdditionalReportsAndDataProcessors.CreateItem();
	DataProcessor.Publication = Enums.AdditionalReportsAndDataProcessorsPublicationOptions.Used;
	
	Result = AdditionalReportsAndDataProcessors.RegisterDataProcessor(DataProcessor, RegistrationParameters);
	
	If Not Result.Success Then
		If Result.Property("Conflicting")
			And ValueIsFilled(Result.Conflicting) Then
			
			RegistrationParameters.Insert("Conflicting", Result.Conflicting);
			RegistrationParameters.DisableConflicts = True;
			Result = AdditionalReportsAndDataProcessors.RegisterDataProcessor(DataProcessor, RegistrationParameters);
		EndIf;
	EndIf;
	
	If Not Result.Success Then
		WriteLogException(Result.ErrorText);
		Return;
	EndIf;
	
	BinaryData = GetFromTempStorage(RegistrationParameters.DataProcessorDataAddress);
	DataProcessor.DataProcessorStorage = New ValueStorage(BinaryData, New Deflation(9));
	
	Try
		DataProcessor.Write();
	Except
		WriteLogException();
	EndTry;
	
EndProcedure

Procedure LoadInformationRegister(DOMElement, CreatedElements)
	
	RegisterName = DOMElement.Attributes.GetNamedItem("item_name").NodeValue;
	
	Try
		RegisterManager = InformationRegisters[RegisterName];
	Except
		ErrorDescription = NStr("en = 'Can''t find information register  ""%1"" in the configuration'",
			CommonUseClientServer.MainLanguageCode());
			
		ErrorDescription = StringFunctionsClientServer.SubstituteParametersInString(ErrorDescription, RegisterName);
			
		WriteLogException(ErrorDescription);
		Return;
	EndTry;
	
	RecorsNodes = DomElement.ChildNodes;
	For Each RecordNode In RecorsNodes Do // records of the information register
		
		NewRecord = RegisterManager.CreateRecordManager();
		For Each Attribute In RecordNode.ChildNodes Do // attrubute of current record
			
			AttributeName = Attribute.TagName;
			
			Try
				RecordAttribute = NewRecord[Attribute.TagName];
			Except
				ErrorDescription = NStr("en = 'There is no attribyte ""%1"" in information register ""%2""'",
					CommonUseClientServer.MainLanguageCode());
					
				ErrorDescription = StringFunctionsClientServer.SubstituteParametersInString(
					ErrorDescription,
					AttributeName,
					RegisterName);
					
				WriteLogException(ErrorDescription);
				Return;
			EndTry;
			
			AttributeValue = Attribute.TextContent;
			
			InfobaseObject = GetReferenceByValue(RecordAttribute, AttributeValue, CreatedElements);
			If InfobaseObject = Undefined 
				And AttributeValue <> Undefined Then
				
				ErrorDescription =  NStr("en = 'Can''t find value ""%1"" for information register ""%2"" in the configuration'",
					CommonUseClientServer.MainLanguageCode());
					
				ErrorDescription = StringFunctionsClientServer.SubstituteParametersInString(
					ErrorDescription,
					AttributeValue,
					RegisterName);
					
				WriteLogException(ErrorDescription);
				Return;
			EndIf;
			
			NewRecord[Attribute.TagName] = InfobaseObject;
			
		EndDo;
		
		Try
			NewRecord.Write();
		Except
			WriteLogException();
			Return;
		EndTry;
		
	EndDo;
	
EndProcedure

Procedure LoadChartsOfAccounts(DOMElement)
	
	ChartOfAccountsName = DOMElement.Attributes.GetNamedItem("item_name").NodeValue;
	
	Try
		ChartOfAccountsManager = ChartsOfAccounts[ChartOfAccountsName];
	Except
		ErrorDescription = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Can''t find chart of accounts ""%1"" in the configuration'", CommonUseClientServer.MainLanguageCode()),
			ChartOfAccountsName);
			
		WriteLogException(ErrorDescription);
		Return;
	EndTry;
	
	Accounts = DomElement.ChildNodes;
	For Each Account In Accounts Do
		
		AttributesValue = New Structure();
		For Each Attribute In Account.ChildNodes Do // attribute of current account
			AttributesValue.Insert(Attribute.LocalName, Attribute.TextContent);
		EndDo;
		
		AccountDescription = AttributesValue["Description"];
		
		AccountRef = ChartOfAccountsManager.FindByDescription(AccountDescription);
		If ValueIsFilled(AccountRef) Then
			AccountObject = AccountRef.GetObject();
		Else
			AccountObject = ChartOfAccountsManager.CreateAccount();
		EndIf;
		
		FillPropertyValues(AccountObject, AttributesValue);
		
		Try
			AccountObject.Write();
		Except
			
			ErrorDescription = NStr("en = 'Error on create account ""%1"" in the charts of accounts ""%2""'",
				CommonUseClientServer.MainLanguageCode());
				
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersInString(
				ErrorDescription,
				AccountDescription,
				ChartOfAccountsName);
			
			WriteLogException(ErrorDescription);
		EndTry;
		
	EndDo;
	
EndProcedure

Procedure SetDefaultLanguage(DOMElement, LanguageIsChanged)
	
	LanguageName = DOMElement.Attributes.GetNamedItem("item_name").NodeValue;
	
	Try
		Langugage = Metadata.Languages[LanguageName];
	Except
		ErrorDescription = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Can''t find language ""%1"" in the configuration'", CommonUseClientServer.MainLanguageCode()),
			LanguageName);
			
		WriteLogException(ErrorDescription);
		Return;
	EndTry;
	
	UserName = "Administrator";
	Administrator = InfoBaseUsers.FindByName(UserName);
	If Administrator = Undefined Then
		ErrorDescription = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Can''t find user ""%1"" in the configuration'", CommonUseClientServer.MainLanguageCode()),
			UserName);
			
		WriteLogException(ErrorDescription);
		Return;
	EndIf;
	
	If Administrator.Language <> Langugage Then
		Administrator.Language = Langugage;
		LanguageIsChanged = True;
	Else
		LanguageIsChanged = False;
		Return;
	EndIf;
	
	Try
		Administrator.Write();
	Except
		ErrorDescription = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Can''t set language on user ""%1""'", CommonUseClientServer.MainLanguageCode()),
			UserName);
			
		WriteLogException(ErrorDescription);
		Return;
	EndTry;
	
EndProcedure

#EndRegion

#Region DOMDocument

Function DOMDocument(Path)
	
	XMLReader = New XMLReader;
	DOMBuilder = New DOMBuilder;
	XMLReader.OpenFile(Path);
	DOMDocument = DOMBuilder.Read(XMLReader);
	XMLReader.Close();
	
	Return DOMDocument;
	
EndFunction

Function GetXPathResultByTagName(DOMDocument, TagName)
	
	Resolver = DOMDocument.CreateNSResolver();
	XPathResult = DOMDocument.EvaluateXPathExpression("//xmlns:" + TagName, DOMDocument, Resolver);
	
	Return XPathResult;
EndFunction

#EndRegion

#Region Other

Function GetReferenceByValue(EmptyValue, NewValue, CreatedElements)
	
	InfobaseObject = Undefined;
	
	TypeOfEmptyValue = TypeOf(EmptyValue);
	If TypeOfEmptyValue = Type("Number")
		Or TypeOfEmptyValue = Type("String")
		Or TypeOfEmptyValue = Type("Date")
		Or TypeOfEmptyValue = Type("Boolean")
		Or TypeOfEmptyValue = Type("UUID") Then
		
		InfobaseObject = NewValue;
	ElsIf Enums.AllRefsType().ContainsType(TypeOfEmptyValue) Then
		
		ValueType = EmptyValue.Metadata();
		InfobaseObject = Enums[ValueType.Name][NewValue];
		
	Else
		Filter = New Structure("Type, Description", TypeOfEmptyValue, NewValue);
		FoundedElements = CreatedElements.FindRows(Filter);
		If FoundedElements.Count() > 0 Then
			InfobaseObject = FoundedElements[0].Ref;
		Else
			If ChartsOfCalculationTypes.AllRefsType().ContainsType(TypeOfEmptyValue)
				Or ChartsOfCharacteristicTypes.AllRefsType().ContainsType(TypeOfEmptyValue)
				Or ChartsOfAccounts.AllRefsType().ContainsType(TypeOfEmptyValue)
				Or Catalogs.AllRefsType().ContainsType(TypeOfEmptyValue) Then
				
				MetadataObject = EmptyValue.Metadata();
				PredefinedElements = MetadataObject.GetPredefinedNames();
				
				Index = PredefinedElements.Find(NewValue);
				If Index <> Undefined Then
					
					ValueType = EmptyValue.Metadata();
					TypeManager = CommonUse.ObjectManagerByFullName(ValueType.FullName());
					
					InfobaseObject = TypeManager[NewValue];
				EndIf;
			EndIf;
				
			If InfobaseObject = Undefined Then
				If Catalogs.AllRefsType().ContainsType(TypeOfEmptyValue)
					Or ChartsOfAccounts.AllRefsType().ContainsType(TypeOfEmptyValue) Then
					
					ValueType = EmptyValue.Metadata();
					TypeManager = CommonUse.ObjectManagerByFullName(ValueType.FullName());
					
					FoundedObject = TypeManager.FindByDescription(NewValue, True);
					If NOT ValueIsFilled(FoundedObject) Then
						FoundedObject = TypeManager.FindByCode(NewValue);
					EndIf;
					If ValueIsFilled(FoundedObject) Then
						InfobaseObject = FoundedObject;
					EndIf;
				Else
					ErrorDescription = StringFunctionsClientServer.SubstituteParametersInString(
						NStr("en = 'Can''t find metadata ""%1"" for type ""%2""'", CommonUseClientServer.MainLanguageCode()),
						NewValue,
						TypeOfEmptyValue);
					WriteLogException(ErrorDescription)
				EndIf;
			EndIf;
		EndIf;
	EndIf;
	
	Return InfobaseObject;
EndFunction

Procedure WriteLogException(ErrorDescription = Undefined)
	
	If Not ValueIsFilled(ErrorDescription) Then
		ErrorDescription = BriefErrorDescription(ErrorInfo());
	EndIf;
	
	WriteLogEvent(
		"UpdateResults.LoadPredefinedData",
		EventLogLevel.Error,
		Metadata.CommonModules.InfobaseUpdateDrive,
		,
		ErrorDescription);
		
	Raise ErrorDescription;
	
EndProcedure

Function JobResult()
	Return New Structure("Done, ErrorMessage, LanguageIsChanged", True, "", False);
EndFunction

Function FileExist(PathToFile)
	TempFile = New File(PathToFile);
	Return TempFile.Exist()
EndFunction

Procedure DeleteKeyInStructure(Structure, KeyName)
	
	If Structure.Property(KeyName) Then
		Structure.Delete(KeyName);
	EndIf;
	
EndProcedure


Function VersionInConfigurationPackageIsCorrect(DOMDocument)
	
	XPathResult = GetXPathResultByTagName(DOMDocument, "items[@version]");
	
	DOMElement = XPathResult.IterateNext();
	If DOMElement <> Undefined Then
		
		ConfigurationPackageVersion = DOMElement.Attributes.GetNamedItem("version").NodeValue;
		CurrentConfigurationVersion = Metadata.Version;
		
		If CommonUseClientServer.CompareVersions(ConfigurationPackageVersion, CurrentConfigurationVersion) = 0 Then
			VersionIsCorrect = True;
		Else
			VersionIsCorrect = False;
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'There is incorrect version in configuration package file.
				     |Configuration version is ""%1"".
				     |Configuration package file version is ""%2""'"),
				CurrentConfigurationVersion,
				ConfigurationPackageVersion);
			WriteLogException(ErrorDescription);
		EndIf;
	Else
		ErrorDescription = NStr("en = 'There is no version number in the configuration package file'",
			CommonUseClientServer.MainLanguageCode());
		WriteLogException(ErrorDescription);
		VersionIsCorrect = False;
	EndIf;
	
	Return VersionIsCorrect;
EndFunction

Procedure SetUpdateConfigurationPackage()
	
	If Constants.FirstLaunchPassed.Get() Then
		
		LaunchParameter = SessionParameters.ClientParametersOnServer.Get("LaunchParameter");
		If Not ValueIsFilled(LaunchParameter)
			Or StrFind(LaunchParameter, "DisableUpdateConfigurationPackage") = 0 Then
			Constants.UpdateConfigurationPackage.Set(True);
		Else
			Constants.UpdateConfigurationPackage.Set(False);
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region CreatedElements

Function CreatedElements()
	
	CreatedElements = New ValueTable;
	CreatedElements.Columns.Add("Type");
	CreatedElements.Columns.Add("Description");
	CreatedElements.Columns.Add("Ref");
	
	Return CreatedElements;
	
EndFunction

Procedure AddCreatedElement(CreatedElements, NewObject)
	
	NewElement = CreatedElements.Add();
	NewElement.Type 		= TypeOf(NewObject.Ref);
	NewElement.Description	= NewObject.Description;
	NewElement.Ref			= NewObject.Ref;
	
EndProcedure

#EndRegion

#Region SLDataXMLLoad

// Function start filling data for choisen country
// 
// Parameters:
//    FileName - string - 
//
Function FillBySLDataXML(Val FileName)
	
	File = New File(FileName);
	
	If File.Extension = ".fi" 
		Or File.Extension = ".finf" Then
		
		XMLReader = New FastInfosetReader;
		XMLReader.Read();
		XMLReader.OpenFile(FileName);
		
		XMLWriter = New XMLWriter;
		TempFileName = GetTempFileName("xml");
		XMLWriter.OpenFile(TempFileName, "UTF-8");
		
		While XMLReader.Read() Do
			XMLWriter.WriteCurrent(XMLReader);
		EndDo;
		
		XMLWriter.Close();
		
		FileName = TempFileName;
		
	EndIf;
	
	XMLReader = New XMLReader;
	XMLReader.OpenFile(FileName);
	If Not XMLReader.Read()
		OR XMLReader.NodeType <> XMLNodeType.StartElement
		OR XMLReader.LocalName <> "_1CV8DtUD"
		OR XMLReader.NamespaceURI <> "http://www.1c.ru/V8/1CV8DtUD/" Then
		
		RaiseExceptionBadFormat();
		Return False;
		
	ElsIf Not XMLReader.Read()
		OR XMLReader.NodeType <> XMLNodeType.StartElement
		OR XMLReader.LocalName <> "Data" Then
		
		RaiseExceptionBadFormat();
		Return False;
		
	EndIf;
	
	MapReplaceOfRef = New Map;
	
	LoadTableOfPredifined(XMLReader, MapReplaceOfRef);
	ReplaceRefToPredefined(FileName, MapReplaceOfRef);
	
	XMLReader.OpenFile(FileName);
	XMLReader.Read();
	XMLReader.Read();
	
	If Not XMLReader.Read() Then 
		
		RaiseExceptionBadFormat();
		Return False;
		
	EndIf;
	
	Serializer = InitializateSerializatorXDTOWithAnnotationTypes();
	
	While Serializer.CanReadXML(XMLReader) Do
		
		Try
			WriteValue = Serializer.ReadXML(XMLReader);
		Except
			Raise;
		EndTry;
		
		Try
			WriteValue.DataExchange.Load = True;
		Except
		EndTry;
		
		Try
			WriteValue.Write();
		Except
			
			ErrorText = ErrorDescription();
			
			Try
				TextForMessage = NStr("en = 'In loading process for Object %1(%2) raised error: %3'");
				TextForMessage = StringFunctionsClientServer.SubstituteParametersInString(TextForMessage, WriteValue, TypeOf(WriteValue), ErrorText);
			Except
				TextForMessage = NStr("en = 'In loading data process raised error: %1'");
				TextForMessage = StringFunctionsClientServer.SubstituteParametersInString(TextForMessage, ErrorText);
			EndTry;
			
			CommonUseClientServer.MessageToUser(TextForMessage);
			
		EndTry;
		
	EndDo;
	
	If XMLReader.NodeType <> XMLNodeType.EndElement
		OR XMLReader.LocalName <> "Data" Then
		
		RaiseExceptionBadFormat();
		Return False;
		
	EndIf;
	
	If Not XMLReader.Read()
		OR XMLReader.NodeType <> XMLNodeType.StartElement
		OR XMLReader.LocalName <> "PredefinedData" Then
		
		RaiseExceptionBadFormat();
		Return False;
		
	EndIf;
	
	XMLReader.Skip();
	
	If Not XMLReader.Read()
		OR XMLReader.NodeType <> XMLNodeType.EndElement
		OR XMLReader.LocalName <> "_1CV8DtUD"
		OR XMLReader.NamespaceURI <> "http://www.1c.ru/V8/1CV8DtUD/" Then
		
		RaiseExceptionBadFormat();
		Return False;
		
	EndIf;
	
	XMLReader.Close();
	
	Return True;
	
EndFunction

Procedure RaiseExceptionBadFormat()

	Raise NStr("en = 'File format is wrong.'");
	
EndProcedure

Function InitializateTableOfPredifined()
	
	TableOfPredifined = New ValueTable;
	TableOfPredifined.Columns.Add("TableName");
	TableOfPredifined.Columns.Add("Ref");
	TableOfPredifined.Columns.Add("PredefinedDataName");
	
	Return TableOfPredifined;
	
EndFunction

Procedure LoadTableOfPredifined(XMLReader, MapReplaceOfRef)
	
	XMLReader.Skip();
	XMLReader.Read();
	
	TableOfPredifined = InitializateTableOfPredifined();
	TempRow = TableOfPredifined.Add();
	
	While XMLReader.Read() Do
		If XMLReader.NodeType = XMLNodeType.StartElement Then
			If XMLReader.LocalName <> "item" Then
				
				TempRow.TableName = XMLReader.LocalName;
				
				TextQuery = 
				"Select
				|	Table.Ref AS Ref
				|From
				|	" + TempRow.TableName + " AS Table
				|Where
				|	Table.PredefinedDataName = &PredefinedDataName";
				Query = New Query(TextQuery);
				
			Else
				While XMLReader.ReadAttribute() Do
					TempRow[XMLReader.LocalName] = XMLReader.Value;
				EndDo;
				
				Query.SetParameter("PredefinedDataName", TempRow.PredefinedDataName);
				
				QueryResult = Query.Execute();
				If Not QueryResult.IsEmpty() Then
					
					Selecter = QueryResult.Select();
					
					If Selecter.Count() = 1 Then
						
						Selecter.Next();
						
						RefInIB = XMLString(Selecter.Ref);
						RefInFile = TempRow.Ref;
						
						If RefInIB <> RefInFile Then
							
							XMLType = XMLTypeOfRef(Selecter.Ref);
							
							MapType = MapReplaceOfRef.Get(XMLType);
							
							If MapType = Undefined Then
								
								MapType = New Map;
								MapType.Insert(RefInFile, RefInIB);
								MapReplaceOfRef.Insert(XMLType, MapType);
								
							Else
								MapType.Insert(RefInFile, RefInIB);
							EndIf;
						EndIf;
					Else
						
						Raise StringFunctionsClientServer.SubstituteParametersInString(
								NStr("en = 'Predefined elements %1 are duplicated in table %2.'"),
								TempRow.PredefinedDataName, 
								TempRow.TableName);
						
					EndIf;
				EndIf;
			EndIf;
		EndIf;
	EndDo;
	
	XMLReader.Close();
	
EndProcedure

// Return XDTOSerializer with annotation type.
//
// Return value:
//	XDTOSerializer - Serializer.
//
Function InitializateSerializatorXDTOWithAnnotationTypes()
	
	TypeWithAnotationsRef = PredifinedTypeForUnload();
	
	If TypeWithAnotationsRef.Count() > 0 Then
		Factory = FactoryWithTypes(TypeWithAnotationsRef);
		Serializer = New XDTOSerializer(Factory);
	Else
		Serializer = XDTOSerializer;
	EndIf;
	
	Return Serializer;
	
EndFunction

Function PredifinedTypeForUnload()
	
	Types = New Array;
	
	For Each MetadataObject Из Metadata.Catalogs Do
		Types.Add(MetadataObject);
	EndDo;
	
	For Each MetadataObject Из Metadata.ChartsOfAccounts Do
		Types.Add(MetadataObject);
	EndDo;
	
	For Each MetadataObject Из Metadata.ChartsOfCharacteristicTypes Do
		Types.Add(MetadataObject);
	EndDo;
	
	For Each MetadataObject Из Metadata.ChartsOfCalculationTypes Do
		Types.Add(MetadataObject);
	EndDo;
	
	Return Types;
	
EndFunction

Function FactoryWithTypes(Val Types)
	
	SchemaSet = XDTOFactory.ExportXMLSchema("http://v8.1c.ru/8.1/data/enterprise/current-config");
	Schema = SchemaSet[0];
	Schema.UpdateDOMElement();
	
	SpecifiedTypes = New Map;
	For Each Type Из Types Do
		SpecifiedTypes.Insert(XMLTypeOfRef(Type), True);
	EndDo;
	
	NameSpace = New Map;
	NameSpace.Insert("xs", "http://www.w3.org/2001/XMLSchema");
	DOMNamespaceResolver = New DOMNamespaceResolver(NameSpace);
	TextXPath = "/xs:schema/xs:complexType/xs:sequence/xs:element[starts-with(@type,'tns:')]";
	
	Query = Schema.DOMDocument.CreateXPathExpression(TextXPath, DOMNamespaceResolver);
	Result = Query.Evaluate(Schema.DOMDocument);

	While True Do
		
		Node = Result.IterateNext();
		If Node = Undefined Then
			Break;
		EndIf;
		TypeAttribute = Node.Attributes.GetNamedItem("type");
		TypeWithoutNSPrefix = Mid(TypeAttribute.TextContent, StrLen("tns:") + 1);
		
		If SpecifiedTypes.Get(TypeWithoutNSPrefix) = Undefined Then
			Continue;
		EndIf;
		
		Node.SetAttribute("nillable", "true");
		Node.RemoveAttribute("type");
	EndDo;
	
	XMLWriter = New XMLWriter;
	SchemeFileName = GetTempFileName("xsd");
	XMLWriter.OpenFile(SchemeFileName);
	DOMWriter = New DOMWriter;
	DOMWriter.Write(Schema.DOMDocument, XMLWriter);
	XMLWriter.Close();
	
	Factory = CreateXDTOFactory(SchemeFileName);
	
	Try
		DeleteFiles(SchemeFileName);
	Except
	EndTry;
	
	Return Factory;
	
EndFunction

Function XMLTypeOfRef(Val Value)
	
	If TypeOf(Value) = Type("MetadataObject") Then
		MetadataObject = Value;
		ObjectManager = CommonUse.ObjectManagerByFullName(MetadataObject.FullName());
		Ref = ObjectManager.GetRef();
	Else
		MetadataObject = Value.Metadata();
		Ref = Value;
	EndIf;
	
	If ObjectFormsReferenceType(MetadataObject) Then
		
		Return XDTOSerializer.XMLTypeOf(Ref).TypeName;
		
	Else
		
		Raise StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = 'Error in definition XMLType reference for object %1: object is not reference.'"),
					MetadataObject.FullName()
				);
		
	EndIf;
	
EndFunction

Function ObjectFormsReferenceType(ObjectMD)
	
	If ObjectMD = Undefined Then
		Return False;
	EndIf;
	
	If Metadata.Catalogs.Contains(ObjectMD)
		OR Metadata.Documents.Contains(ObjectMD)
		OR Metadata.ChartsOfCharacteristicTypes.Contains(ObjectMD)
		OR Metadata.ChartsOfAccounts.Contains(ObjectMD)
		OR Metadata.ChartsOfCalculationTypes.Contains(ObjectMD)
		OR Metadata.ExchangePlans.Contains(ObjectMD)
		OR Metadata.BusinessProcesses.Contains(ObjectMD)
		OR Metadata.Tasks.Contains(ObjectMD) Then
		Return True;
	EndIf;
	
	Return False;
EndFunction

Procedure ReplaceRefToPredefined(FileName, MapReplaceOfRef)
	
	ReadFlow = New TextReader(FileName);
	
	TempFile = GetTempFileName("xml");
	
	WriteFlow = New TextWriter(TempFile);
	
	// Constans for parse text
	StartOfType = "xsi:type=""v8:";
	LengthStartOfType = StrLen(StartOfType);
	EndOfType = """>";
	LengthEndOfType = StrLen(EndOfType);
	
	SourceRow = ReadFlow.ReadLine();
	While SourceRow <> Undefined Do
		
		RemainsOfRow = Undefined;
		
		CurrentPosition = 1;
		TypePosition = Find(SourceRow, StartOfType);
		While TypePosition > 0 Do
			
			WriteFlow.Write(Mid(SourceRow, CurrentPosition, TypePosition - 1 + LengthStartOfType));
			
			RemainsOfRow = Mid(SourceRow, CurrentPosition + TypePosition + LengthStartOfType - 1);
			CurrentPosition = CurrentPosition + TypePosition + LengthStartOfType - 1;
			
			EndOfTypePosition = Find(RemainsOfRow, EndOfType);
			If EndOfTypePosition = 0 Then
				Break;
			EndIf;
			
			TypeName = Left(RemainsOfRow, EndOfTypePosition - 1);
			MapReplace = MapReplaceOfRef.Get(TypeName);
			If MapReplace = Undefined Then
				TypePosition = Find(RemainsOfRow, StartOfType);
				Continue;
			EndIf;
			
			WriteFlow.Write(TypeName);
			WriteFlow.Write(EndOfType);
			
			SourceRowXML = Mid(RemainsOfRow, EndOfTypePosition + LengthEndOfType, 36);
			
			FindRowXML = MapReplace.Get(SourceRowXML);
			
			If FindRowXML = Undefined Then
				WriteFlow.Write(SourceRowXML);
			Else
				WriteFlow.Write(FindRowXML);
			EndIf;
			
			CurrentPosition = CurrentPosition + EndOfTypePosition - 1 + LengthEndOfType + 36;
			RemainsOfRow = Mid(RemainsOfRow, EndOfTypePosition + LengthEndOfType + 36);
			TypePosition = Find(RemainsOfRow, StartOfType);
			
		EndDo;
		
		If RemainsOfRow <> Undefined Then
			WriteFlow.WriteLine(RemainsOfRow);
		Else
			WriteFlow.WriteLine(SourceRow);
		EndIf;
		
		SourceRow = ReadFlow.ReadLine();
		
	EndDo;
	
	ReadFlow.Close();
	WriteFlow.Close();
	
	FileName = TempFile;
	
EndProcedure

#EndRegion

#EndRegion

#Region FillingMetadata

// Procedure fills in "Earnings calculation parameters" and "Earning and deduction types" catalogs.
//
Procedure FillCalculationParametersAndEarningKinds()
	
	// Earnings calculation parameters.
	
	// Sales amount by responsible (SAR)
	If Not DriveServer.SettlementsParameterExist("SalesAmountForResponsible") Then
		
		SAREarningsCalculationParameters = Catalogs.EarningsCalculationParameters.CreateItem();
		
		SAREarningsCalculationParameters.Description						= "Sales amount by responsible";
		SAREarningsCalculationParameters.ID								= "SalesAmountForResponsible"; 
		SAREarningsCalculationParameters.CustomQuery						= True;
		SAREarningsCalculationParameters.SpecifyValueAtPayrollCalculation	= False;
		
		NewQueryParameter 						 = SAREarningsCalculationParameters.QueryParameters.Add();
		NewQueryParameter.Name 					 = "AccountingCurrencyExchangeRate";
		NewQueryParameter.Presentation 			 = "AccountingCurrencyExchangeRate";
		
		NewQueryParameter 						 = SAREarningsCalculationParameters.QueryParameters.Add();
		NewQueryParameter.Name 					 = "DocumentCurrencyMultiplicity";
		NewQueryParameter.Presentation 			 = "DocumentCurrencyMultiplicity";
		
		NewQueryParameter 						 = SAREarningsCalculationParameters.QueryParameters.Add();
		NewQueryParameter.Name 					 = "DocumentCurrencyRate";
		NewQueryParameter.Presentation 			 = "DocumentCurrencyRate";
		
		NewQueryParameter 						 = SAREarningsCalculationParameters.QueryParameters.Add();
		NewQueryParameter.Name 					 = "AccountingCurrecyFrequency";
		NewQueryParameter.Presentation 			 = "AccountingCurrecyFrequency";
		
		NewQueryParameter 						 = SAREarningsCalculationParameters.QueryParameters.Add();
		NewQueryParameter.Name 					 = "RegistrationPeriod";
		NewQueryParameter.Presentation 			 = "RegistrationPeriod";
		
		NewQueryParameter 						 = SAREarningsCalculationParameters.QueryParameters.Add();
		NewQueryParameter.Name 					 = "Company";
		NewQueryParameter.Presentation 			 = "Company";
		
		NewQueryParameter 						 = SAREarningsCalculationParameters.QueryParameters.Add();
		NewQueryParameter.Name 					 = "Department";
		NewQueryParameter.Presentation 			 = "Department";
		
		NewQueryParameter 						 = SAREarningsCalculationParameters.QueryParameters.Add();
		NewQueryParameter.Name 					 = "Employee";
		NewQueryParameter.Presentation 			 = "Employee";
		
		
		SAREarningsCalculationParameters.Query = 
		"SELECT ALLOWED
		|	SUM(ISNULL(Sales.Amount * &AccountingCurrencyExchangeRate * &DocumentCurrencyMultiplicity / (&DocumentCurrencyRate * &AccountingCurrecyFrequency), 0)) AS SalesAmount
		|FROM
		|	AccumulationRegister.Sales AS Sales
		|WHERE
		|	Sales.Amount >= 0
		|	AND Sales.Period BETWEEN BEGINOFPERIOD(&RegistrationPeriod, MONTH) AND ENDOFPERIOD(&RegistrationPeriod, MONTH)
		|	AND Sales.Company = &Company
		|	AND Sales.Department = &Department
		|	AND Sales.Document.Responsible = &Employee
		|	AND (CAST(Sales.Recorder AS Document.SalesOrder) REFS Document.SalesOrder
		|			OR CAST(Sales.Recorder AS Document.SubcontractorReportIssued) REFS Document.SubcontractorReportIssued
		|			OR CAST(Sales.Recorder AS Document.ShiftClosure) REFS Document.ShiftClosure
		|			OR CAST(Sales.Recorder AS Document.SalesInvoice) REFS Document.SalesInvoice
		|			OR CAST(Sales.Recorder AS Document.SalesSlip) REFS Document.SalesSlip)
		|
		|GROUP BY
		|	Sales.Document.Responsible";
		
		SAREarningsCalculationParameters.Write();
		
	EndIf;
	
	// Fixed amount
	If Not DriveServer.SettlementsParameterExist("FixedAmount") Then
		
		ParameterCalculationsFixedAmount = Catalogs.EarningsCalculationParameters.CreateItem();
		ParameterCalculationsFixedAmount.Description						= "Fixed amount";
		ParameterCalculationsFixedAmount.ID									= "FixedAmount";
		ParameterCalculationsFixedAmount.CustomQuery						= False;
		ParameterCalculationsFixedAmount.SpecifyValueAtPayrollCalculation	= True;
		ParameterCalculationsFixedAmount.Write();
		
	EndIf;
	
	// Norm of days
	If Not DriveServer.SettlementsParameterExist("NormDays") Then
		
		SettlementsParameterNormDays = Catalogs.EarningsCalculationParameters.CreateItem();
		SettlementsParameterNormDays.Description 		= "Norm of days";
		SettlementsParameterNormDays.ID					= "NormDays";
		SettlementsParameterNormDays.CustomQuery		= True;
		SettlementsParameterNormDays.SpecifyValueAtPayrollCalculation = False;
		NewQueryParameter						= SettlementsParameterNormDays.QueryParameters.Add();
		NewQueryParameter.Name					= "Company";
		NewQueryParameter.Presentation			= "Company";
		NewQueryParameter						= SettlementsParameterNormDays.QueryParameters.Add();
		NewQueryParameter.Name					= "RegistrationPeriod";
		NewQueryParameter.Presentation			= "Registration period";
		SettlementsParameterNormDays.Query		= 
		"SELECT
		|	SUM(1) AS NormDays
		|FROM
		|	InformationRegister.CalendarSchedules AS CalendarSchedules
		|		INNER JOIN Catalog.Companies AS Companies
		|		ON CalendarSchedules.Calendar = Companies.BusinessCalendar
		|			AND (Companies.Ref = &Company)
		|WHERE
		|	CalendarSchedules.Year = YEAR(&RegistrationPeriod)
		|	AND CalendarSchedules.ScheduleDate between BEGINOFPERIOD(&RegistrationPeriod, MONTH) AND ENDOFPERIOD(&RegistrationPeriod, MONTH)
		|	AND CalendarSchedules.DayIncludedInSchedule";
		
		SettlementsParameterNormDays.Write();
		
	EndIf;
	
	// Norm of hours
	If Not DriveServer.SettlementsParameterExist("NormHours") Then
		
		ParameterCalculationsNormHours = Catalogs.EarningsCalculationParameters.CreateItem();
		ParameterCalculationsNormHours.Description	= "Norm of hours";
		ParameterCalculationsNormHours.ID			= "NormHours";
		ParameterCalculationsNormHours.CustomQuery	= True;
		ParameterCalculationsNormHours.SpecifyValueAtPayrollCalculation = False;
		NewQueryParameter						= ParameterCalculationsNormHours.QueryParameters.Add();
		NewQueryParameter.Name					= "Company";
		NewQueryParameter.Presentation			= "Company";
		NewQueryParameter						= ParameterCalculationsNormHours.QueryParameters.Add();
		NewQueryParameter.Name					= "RegistrationPeriod";
		NewQueryParameter.Presentation			= "Registration period";
		ParameterCalculationsNormHours.Query	= 
		"SELECT
		|	SUM(8) AS NormHours
		|FROM
		|	InformationRegister.CalendarSchedules AS CalendarSchedules
		|		INNER JOIN Catalog.Companies AS Companies
		|		ON CalendarSchedules.Calendar = Companies.BusinessCalendar
		|			AND (Companies.Ref = &Company)
		|WHERE
		|	CalendarSchedules.Year = YEAR(&RegistrationPeriod)
		|	AND CalendarSchedules.ScheduleDate between BEGINOFPERIOD(&RegistrationPeriod, MONTH) AND ENDOFPERIOD(&RegistrationPeriod, MONTH)
		|	AND CalendarSchedules.DayIncludedInSchedule";
		ParameterCalculationsNormHours.Write();
		
	EndIf;
	
	// Days worked
	If Not DriveServer.SettlementsParameterExist("DaysWorked") Then
		
		ParameterCalculationsDaysWorked = Catalogs.EarningsCalculationParameters.CreateItem();
		ParameterCalculationsDaysWorked.Description	= "Days worked";
		ParameterCalculationsDaysWorked.ID			= "DaysWorked";
		ParameterCalculationsDaysWorked.CustomQuery = False;
		ParameterCalculationsDaysWorked.SpecifyValueAtPayrollCalculation = True;
		ParameterCalculationsDaysWorked.Write();
		
	EndIf;
	
	// Hours worked
	If Not DriveServer.SettlementsParameterExist("HoursWorked") Then
		
		ParameterCalculationsHoursWorked = Catalogs.EarningsCalculationParameters.CreateItem();
		ParameterCalculationsHoursWorked.Description	= "Hours worked";
		ParameterCalculationsHoursWorked.ID				= "HoursWorked";
		ParameterCalculationsHoursWorked.CustomQuery	= False;
		ParameterCalculationsHoursWorked.SpecifyValueAtPayrollCalculation = True;
		ParameterCalculationsHoursWorked.Write();
		
	EndIf;
	
	// Tariff rate
	If Not DriveServer.SettlementsParameterExist("TariffRate") Then
		
		CalculationsParameterTariffRate = Catalogs.EarningsCalculationParameters.CreateItem();
		CalculationsParameterTariffRate.Description	= "Tariff rate";
		CalculationsParameterTariffRate.ID			= "TariffRate";
		CalculationsParameterTariffRate.CustomQuery = False;
		CalculationsParameterTariffRate.SpecifyValueAtPayrollCalculation = True;
		CalculationsParameterTariffRate.Write();
		
	EndIf;
	
	// Worked by jobs
	If Not DriveServer.SettlementsParameterExist("HoursWorkedByJobs") Then
		
		ParameterCalculationsPieceDevelopment = Catalogs.EarningsCalculationParameters.CreateItem();
		ParameterCalculationsPieceDevelopment.Description	= "Hours worked by jobs";
		ParameterCalculationsPieceDevelopment.ID			= "HoursWorkedByJobs";
		ParameterCalculationsPieceDevelopment.CustomQuery	= True;
		ParameterCalculationsPieceDevelopment.SpecifyValueAtPayrollCalculation = False;
		
		NewQueryParameter = ParameterCalculationsPieceDevelopment.QueryParameters.Add();
		NewQueryParameter.Name			= "BeginOfPeriod"; 
		NewQueryParameter.Presentation	= "Begin of period"; 
		
		NewQueryParameter = ParameterCalculationsPieceDevelopment.QueryParameters.Add();
		NewQueryParameter.Name			= "EndOfPeriod";
		NewQueryParameter.Presentation	= "End of period";
		
		NewQueryParameter = ParameterCalculationsPieceDevelopment.QueryParameters.Add();
		NewQueryParameter.Name			= "Employee";
		NewQueryParameter.Presentation	= "Employee";
		
		NewQueryParameter = ParameterCalculationsPieceDevelopment.QueryParameters.Add();
		NewQueryParameter.Name			= "Company"; 
		NewQueryParameter.Presentation	= "Company"; 
		
		NewQueryParameter = ParameterCalculationsPieceDevelopment.QueryParameters.Add();
		NewQueryParameter.Name			= "Department";
		NewQueryParameter.Presentation	= "Department";
		
		ParameterCalculationsPieceDevelopment.Query =
		"SELECT
		|	Source.ImportActualTurnover
		|FROM
		|	AccumulationRegister.ObsoleteWorkOrders.Turnovers(&BeginOfPeriod, &EndOfPeriod, Auto, ) AS Source
		|WHERE
		|	Source.Employee = &Employee
		|	AND Source.StructuralUnit = &Department
		|	AND Source.Company = &Company";
		
		ParameterCalculationsPieceDevelopment.Write();
		
	EndIf;
	
	// Earning types
	If Not DriveServer.EarningAndDeductionTypesInitialFillingPerformed() Then
		
		// Groups
		NewEarning = Catalogs.EarningAndDeductionTypes.CreateFolder();
		NewEarning.Description = "Earnings";
		NewEarning.Write();
		GroupEarning = NewEarning.Ref;
		
		NewEarning = Catalogs.EarningAndDeductionTypes.CreateFolder();
		NewEarning.Description = "Deductions";
		NewEarning.Write();
		GroupDeduction = NewEarning.Ref;
		
		// Salary by days
		NewEarning = Catalogs.EarningAndDeductionTypes.CreateItem();
		NewEarning.Parent			= GroupEarning;
		NewEarning.Description		= "Salary by days";
		NewEarning.Type				= Enums.EarningAndDeductionTypes.Earning;
		NewEarning.GLExpenseAccount	= Catalogs.DefaultGLAccounts.GetDefaultGLAccount("PayrollExpenses");
		NewEarning.Formula			= "[TariffRate] * [DaysWorked] / [NormDays]";
		NewEarning.Write();
		
		// Salary by hours
		NewEarning = Catalogs.EarningAndDeductionTypes.CreateItem();
		NewEarning.Parent			= GroupEarning;
		NewEarning.Description		= "Salary by hours";
		NewEarning.Type				= Enums.EarningAndDeductionTypes.Earning;
		NewEarning.GLExpenseAccount	= Catalogs.DefaultGLAccounts.GetDefaultGLAccount("PayrollExpenses");;
		NewEarning.Formula			= "[TariffRate] * [HoursWorked] / [NormHours]";
		NewEarning.Write();
		
		// Payment by jobs
		NewEarning = Catalogs.EarningAndDeductionTypes.CreateItem();
		NewEarning.Parent			= GroupEarning;
		NewEarning.Description		= "Payment by jobs";
		NewEarning.Type				= Enums.EarningAndDeductionTypes.Earning;
		NewEarning.GLExpenseAccount	= Catalogs.DefaultGLAccounts.GetDefaultGLAccount("WorkInProcess");
		NewEarning.Formula			= "[TariffRate] * [HoursProcessedByJobs]";
		NewEarning.Write();
		
		// Sales fee by responsible
		NewEarning = Catalogs.EarningAndDeductionTypes.CreateItem();
		NewEarning.Parent			= GroupEarning;
		NewEarning.Description		= "Sales fee by responsible";
		NewEarning.Type				= Enums.EarningAndDeductionTypes.Earning;
		NewEarning.GLExpenseAccount	= Catalogs.DefaultGLAccounts.GetDefaultGLAccount("WorkInProcess");
		NewEarning.Formula			= "[SalesAmountByResponsible]  /  100 * [TariffRate]";
		NewEarning.Write();
		
		// Piece-rate pay
		NewEarningReference = Catalogs.EarningAndDeductionTypes.PieceRatePay;
		NewEarning			= NewEarningReference.GetObject();
		NewEarning.Parent			= GroupEarning;
		NewEarning.Description		= "Piece-rate pay";
		NewEarning.Type				= Enums.EarningAndDeductionTypes.Earning;
		NewEarning.GLExpenseAccount	= Catalogs.DefaultGLAccounts.GetDefaultGLAccount("WorkInProcess");
		NewEarning.Formula			= "";
		NewEarning.Write();
		
		// Piece-rate pay (percent)
		NewEarningReference = Catalogs.EarningAndDeductionTypes.PieceRatePayPercent;
		NewEarning			= NewEarningReference.GetObject();
		NewEarning.Parent			= GroupEarning;
		NewEarning.Description		= "Piece-rate pay (percent)";
		NewEarning.Type				= Enums.EarningAndDeductionTypes.Earning;
		NewEarning.GLExpenseAccount	= Catalogs.DefaultGLAccounts.GetDefaultGLAccount("WorkInProcess");
		NewEarning.Formula			= "";
		NewEarning.Write();
		
		// Piece-rate pay (fixed amount)
		NewEarningReference = Catalogs.EarningAndDeductionTypes.PieceRatePayFixedAmount;
		NewEarning			= NewEarningReference.GetObject();
		NewEarning.Code				= "";
		NewEarning.Parent			= GroupEarning;
		NewEarning.Description		= "Piece-rate pay (fixed amount)";
		NewEarning.Type				= Enums.EarningAndDeductionTypes.Earning;
		NewEarning.GLExpenseAccount	= Catalogs.DefaultGLAccounts.GetDefaultGLAccount("WorkInProcess");
		NewEarning.Formula			= "[FixedAmount]";
		NewEarning.SetNewCode();
		NewEarning.Write();
		
		// Interest on loan
		NewEarningReference = Catalogs.EarningAndDeductionTypes.InterestOnLoan;
		NewEarning		= NewEarningReference.GetObject();
		NewEarning.Code		= "";
		NewEarning.Parent	= GroupDeduction;
		NewEarning.Type		= Enums.EarningAndDeductionTypes.Deduction;
		NewEarning.SetNewCode();
		NewEarning.Write();
		
		// Repayment of loan from salary
		NewEarningReference = Catalogs.EarningAndDeductionTypes.RepaymentOfLoanFromSalary;
		NewEarning		= NewEarningReference.GetObject();
		NewEarning.Code		= "";
		NewEarning.Parent	= GroupDeduction;
		NewEarning.Type		= Enums.EarningAndDeductionTypes.Deduction;
		NewEarning.SetNewCode();
		NewEarning.Write();
		
	EndIf;
	
EndProcedure

// Procedure fills in the selection settings on the first start
//
Procedure FillFilterUserSettings()
	
	CurrentUser = Users.CurrentUser();
	
	DriveServer.SetStandardFilterSettings(CurrentUser);
	
EndProcedure

// Procedure fills in contracts forms from layout.
//
Procedure FillContractsForms()
	
	PurchaseAndSaleContractTemplate = Catalogs.ContractForms.GetTemplate("PurchaseAndSaleContractTemplate");
	
	Templates = New Array(1);
	Templates[0] = PurchaseAndSaleContractTemplate;
	
	LayoutNames = New Array(1);
	LayoutNames[0] = "PurchaseAndSaleContractTemplate";
	
	Forms = New Array(1);
	Forms[0] = Catalogs.ContractForms.PurchaseAndSaleContract.Ref.GetObject();
	
	Iterator = 0;
	While Iterator < Templates.Count() Do 
		
		ContractTemplate = Catalogs.ContractForms.GetTemplate(LayoutNames[Iterator]);
		
		TextHTML = ContractTemplate.GetText();
		Attachments = New Structure;
		
		EditableParametersNumber = StrOccurrenceCount(TextHTML, "{FilledField");
		
		Forms[Iterator].EditableParameters.Clear();
		ParameterNumber = 1;
		While ParameterNumber <= EditableParametersNumber Do 
			NewRow = Forms[Iterator].EditableParameters.Add();
			NewRow.Presentation = "{FilledField" + ParameterNumber + "}";
			NewRow.ID = "parameter" + ParameterNumber;
			
			ParameterNumber = ParameterNumber + 1;
		EndDo;
		
		FormattedDocumentStructure = New Structure;
		FormattedDocumentStructure.Insert("HTMLText", TextHTML);
		FormattedDocumentStructure.Insert("Attachments", Attachments);
		
		Forms[Iterator].Form = New ValueStorage(FormattedDocumentStructure);
		Forms[Iterator].PredefinedFormTemplate = LayoutNames[Iterator];
		Forms[Iterator].EditableParametersNumber = EditableParametersNumber;
		Forms[Iterator].Write();
		
		Iterator = Iterator + 1;
		
	EndDo;
	
EndProcedure

#EndRegion

#Region InfobaseUpdate

Procedure FillPredefinedPeripheralsDrivers() Export
	EquipmentManagerServerCallOverridable.RefreshSuppliedDrivers();
EndProcedure

#EndRegion

#EndRegion