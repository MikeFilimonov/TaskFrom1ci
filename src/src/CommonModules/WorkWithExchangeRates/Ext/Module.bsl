////////////////////////////////////////////////////////////////////////////////
// Subsystem "Currencies"
// 
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Adds currencies from the classifier to the currencies catalog.
//
// Parameters:
//   Codes - Array - digit codes of the added currencies.
//
// Returns:
//   Array, CatalogRef.Currencies - created currencies refs.
//
Function AddCurrenciesByCode(Val Codes) Export
	
	ClassifierTable = GetCurrencyClassifierTable();
	
	Result = New Array();
	
	For Each Code In Codes Do
		
		Row = ClassifierTable.Find(Code, "Code"); 
		
		If Row = Undefined Then
			Continue;
		EndIf;
		
		CurrencyRef = Catalogs.Currencies.FindByCode(Row.Code);
		
		If CurrencyRef.IsEmpty() Then
			NewRow									= Catalogs.Currencies.CreateItem();
			NewRow.Code								= Row.Code;
			NewRow.Description						= Row.CodeSymbol;
			NewRow.DescriptionFull					= Row.Name;
			NewRow.SetRateMethod					= Enums.ExchangeRateSetupMethod.ManualInput;
			NewRow.InWordParametersInHomeLanguage	= Row.NumerationItemOptions;
			NewRow.Write();
			Result.Add(NewRow.Ref);
		Else
			Result.Add(CurrencyRef);
		EndIf;
		
	EndDo; 
	
	Return	Result;
	
EndFunction

// Returns exchange rate for a date.
//
// Parameters:
//   Currency    - CatalogRef.Currencies - Currency for which currency rate is composed.
//   ExchangeRateDate - Date - Date for which currency rate is composed.
//
// Returns: 
//   Structure - Exchange rate parameters.
//       * ExchangeRate     - Number                - Exchange rate for the specified date.
//       * Multiplicity     - Number                - The exchange rate multiplier for the specified date.
//       * Currency         - CatalogRef.Currencies - Ref currency.
//       * ExchangeRateDate - Date                  - Currency rate receipt date.
//
Function GetCurrencyRate(Currency, ExchangeRateDate) Export
	
	Result = InformationRegisters.ExchangeRates.GetLast(ExchangeRateDate, New Structure("Currency", Currency));
	
	Result.Insert("Currency",    Currency);
	Result.Insert("ExchangeRateDate", ExchangeRateDate);
	
	Return Result;
	
EndFunction

// Generates amount presentation in writing in the specified currency.
//
// Parameters:
//   AmountAsNumber - Number - amount that should be in writing.
//   Currency - CatalogRef.Currencies - currency in which amount should be presented.
//   DisplayAmountWithoutCents - Boolean - shows that amount is presented without kopeks.
//
// Returns:
//   String - amount in writing.
//
Function GenerateAmountInWords(AmountAsNumber, Currency, DisplayAmountWithoutCents = False) Export
	
	Amount				= ?(AmountAsNumber < 0, -AmountAsNumber, AmountAsNumber);
	SubjectParameters	= CommonUse.ObjectAttributesValues(Currency, "InWordParametersInEnglish");
	
	Result = NumberInWords(Amount, "L=" + CommonUseClientServer.MainLanguageCode() + ";FS=False", SubjectParameters.InWordParametersInEnglish);
	
	If DisplayAmountWithoutCents AND Int(Amount) = Amount Then
		Result = Left(Result, Find(Result, "0") - 1);
	EndIf;
	
	Return Result;
	
EndFunction

// Recalculates amount from one currency to another.
//
// Parameters:
//  Amount          - Number - amount that should be recalculated;
//  SourceCurrency - CatalogRef.Currencies - recalculated currency;
//  NewCurrency    - CatalogRef.Currencies - currency to which you should recalculate;
//  Date           - Date - exchange rates date.
//
// Returns:
//  Number - recalculated amount.
//
Function RecalculateToCurrency(Amount, SourceCurrency, NewCurrency, Date) Export
	
	Return WorkWithExchangeRatesClientServer.RecalculateByRate(Amount,
		GetCurrencyRate(SourceCurrency, Date),
		GetCurrencyRate(NewCurrency, Date));
		
EndFunction

#EndRegion

#Region ServiceProgramInterface

// See details of the same procedure in the StandardSubsystemsServer module.
Procedure OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers) Export
	
	// CLIENT HANDLERS.
	
	ClientHandlers["StandardSubsystems.BasicFunctionality\AfterSystemOperationStart"].Add(
		"WorkWithExchangeRatesClient");
	
	// SERVERSIDE HANDLERS.
	
	ServerHandlers["StandardSubsystems.BasicFunctionality\OnAddExceptionsSearchLinks"].Add(
		"WorkWithExchangeRates");
	
	ServerHandlers["StandardSubsystems.BasicFunctionality\OnAddWorkParametersClientOnStart"].Add(
		"WorkWithExchangeRates");
	
	If CommonUse.SubsystemExists("StandardSubsystems.SaaS.JobQueue") Then
		ServerHandlers["StandardSubsystems.SaaS.JobQueue\OnDefenitionOfUsageOfScheduledJobs"].Add(
			"WorkWithExchangeRates");
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.ToDoList") Then
		ServerHandlers["StandardSubsystems.ToDoList\AtFillingToDoList"].Add(
			"WorkWithExchangeRates");
	EndIf;
			
	ServerHandlers["StandardSubsystems.BasicFunctionality\WhenFillingOutPermitsForAccessToExternalResources"].Add(
		"WorkWithExchangeRates");
	
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
	
	ModuleToDoListService = CommonUse.CommonModule("ToDoListService");
	If CommonUseReUse.DataSeparationEnabled() // Updated automatically in the service model.
		Or Not AccessRight("Update", Metadata.InformationRegisters.ExchangeRates)
		Or ModuleToDoListService.WorkDisabled("CurrencyClassifier") Then
		Return;
	EndIf;
	ModuleToDoListServer = CommonUse.CommonModule("ToDoListServer");
	
	ExchangeRatesAreRelevant = ExchangeRatesAreRelevant();
	
	// The procedure is called only if there is the
	// To-do lists subsystem, that is why here is no checking of subsystem existence.
	Sections = ModuleToDoListServer.SectionsForObject(Metadata.Catalogs.Currencies.FullName());
	
	If Sections = Undefined Then
		Return; // Interface of work with currencies is not in the user command interface.
	EndIf;
	
	For Each Section In Sections Do
		
		CurrencyID = "CurrencyClassifier" + StrReplace(Section.FullName(), ".", "");
		Work				= ToDoList.Add();
		Work.ID				= CurrencyID;
		Work.ThereIsWork	= Not ExchangeRatesAreRelevant;
		Work.Presentation	= NStr("en = 'Exchange rates are outdated'");
		Work.Important		= True;
		Work.Form			= "DataProcessor.ImportExchangeRates.Form";
		Work.FormParameters	= New Structure("OpenFromList", True);
		Work.Owner			= Section;
		
	EndDo;
	
EndProcedure

// Define the list of catalogs available for import using the Import data from file subsystem.
//
// Parameters:
//  Handlers - ValueTable - list of catalogs, to which the data can be imported.
//      * FullName          - String - full name of the catalog (as in the metadata).
//      * Presentation      - String - presentation of the catalog in the selection list.
//      *AppliedImport - Boolean - if True, then the catalog uses its own
//                                      importing algorithm and the functions are defined in the catalog manager module.
//
Procedure OnDetermineCatalogsForDataImport(ImportedCatalogs) Export
	
	// Cannot import to the currency classifier.
	TableRow = ImportedCatalogs.Find(Metadata.Catalogs.Currencies.FullName(), "FullName");
	If TableRow <> Undefined Then 
		ImportedCatalogs.Delete(TableRow);
	EndIf;
	
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
	Objects.Insert(Metadata.Catalogs.Currencies.FullName(), "EditedAttributesInGroupDataProcessing");
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

#Region HandlersOfSSLSubsystemsInternalEvents

// Fills out parameters that are used by the client code when launching the configuration.
//
// Parameters:
//   Parameters - Structure - Launch parameters.
//
Procedure OnAddWorkParametersClientOnStart(Parameters) Export
	
	If CommonUseReUse.DataSeparationEnabled() Then
		ExchangeRatesAreRelevantUpdatedByResponsible = False; // Updated automatically in the service model.
	ElsIf Not AccessRight("Update", Metadata.InformationRegisters.ExchangeRates) Then
		ExchangeRatesAreRelevantUpdatedByResponsible = False; // User can not update exchange rates.
	Else
		ExchangeRatesAreRelevantUpdatedByResponsible = ExchangeRatesExportedFromInternet(); // There are currencies for which currency rates can be imported.
	EndIf;
	
	EnableAlert = Not CommonUse.SubsystemExists("StandardSubsystems.ToDoList");
	WorkWithExchangeRatesOverridable.OnDeterminingOfWarningsShowAboutOutDatedExchangeRates(EnableAlert);
	
	Parameters.Insert("Currencies", New FixedStructure("ExchangeRatesAreRelevantUpdatedByResponsible", (ExchangeRatesAreRelevantUpdatedByResponsible AND EnableAlert)));
	
EndProcedure

// Fills the array with the list of metadata objects names that might include
// references to different metadata objects with these references ignored in the business-specific application logic
//
// Parameters:
//  Array - array of strings for example "InformationRegister.ObjectsVersions".
//
Procedure OnAddExceptionsSearchLinks(Array) Export
	
	Array.Add(Metadata.InformationRegisters.ExchangeRates.FullName());
	
EndProcedure
	
// Adds information about subsystem scheduled jobs for the service model to the table.
//
// Parameters:
//   UsageTable - ValueTable - Scheduled jobs table.
//      * ScheduledJob - String - Predefined scheduled job name.
//      * Use       - Boolean - True if scheduled job
//          should be executed in the service model.
//
Procedure OnDefenitionOfUsageOfScheduledJobs(UsageTable) Export
	
	NewRow = UsageTable.Add();
	NewRow.ScheduledJob = "ExchangeRatesImportProcess";
	NewRow.Use       = False;
	
EndProcedure

// Fills out a list of queries for external permissions
// that must be provided when creating an infobase or updating a application.
//
// Parameters:
//  PermissionsQueries - Array - list of values returned by the function.
//                      WorkInSafeMode.QueryOnExternalResourcesUse().
//
Procedure WhenFillingOutPermitsForAccessToExternalResources(PermissionsQueries) Export
	
	If CommonUseReUse.DataSeparationEnabled() Then
		Return;
	EndIf;
	
	PermissionsQueries.Add(
		WorkInSafeMode.QueryOnExternalResourcesUse(permissions()));
	
EndProcedure

// Returns list of permissions for exchange rates import from website.
//
// Returns:
//  Array.
//
Function permissions()
	
	permissions = New Array;
	
	Return permissions;
	
EndFunction

#EndRegion

#Region ExportServiceProceduresAndFunctions

// Checks whether a fixed exchange rate and multiplier are available for the date January 1, 1980.
// If they are not available, sets them both to 1.
//
// Parameters:
//  Currency - ref to the Currencies catalog item.
//
Procedure CheckRateOn01Correctness_01_1980(Currency) Export
	
	ExchangeRateDate = Date("19800101");
	StructureRate = InformationRegisters.ExchangeRates.GetLast(ExchangeRateDate, New Structure("Currency", Currency));
	
	If (StructureRate.ExchangeRate = 0) Or (StructureRate.Multiplicity = 0) Then
		RecordSet = InformationRegisters.ExchangeRates.CreateRecordSet();
		RecordSet.Filter.Currency.Set(Currency);
		Record = RecordSet.Add();
		Record.Currency = Currency;
		Record.Period = ExchangeRateDate;
		Record.ExchangeRate = 1;
		Record.Multiplicity = 1;
		RecordSet.AdditionalProperties.Insert("SkipChangeProhibitionCheck");
		RecordSet.Write();
	EndIf;
	
EndProcedure

// Imports exchange rates for the current date.
//
// Parameters:
//  ExportParameters - Structure - import details:
//   * BeginOfPeriod - Date - import period start;
//   * EndOfPeriod - Date - import period end;
//   * CurrenciesList - ValueTable - imported currencies:
//     ** Currency - CatalogRef.Currencies;
//     ** CurrencyCode - String.
//  ResultAddress - String - address in the temporary storage to place import results there.
//
Procedure ImportExchangeRates(ExportParameters = Undefined, ResultAddress = Undefined) Export
		
	If CommonUseReUse.DataSeparationEnabled() Then
		Raise NStr("en = 'Invalid call of the ""ImportRelevantCurrencyRate"" procedure.'");
	EndIf;
	
	CommonUse.OnStartExecutingScheduledJob();
	
	EventName = NStr("en = 'Currency.Exchange rates import'",
		CommonUseClientServer.MainLanguageCode());
	
	WriteLogEvent(EventName, EventLogLevel.Information, , ,
		NStr("en = 'Scheduled import of exchange rates is started'"));
				
	DataProcessorManager = GetExchangeRatesImportProcessor();	
	
	CurrentDate = CurrentSessionDate();
	
	ImportStatus = Undefined;
	ErrorsOccuredOnImport = False;
	
	If ExportParameters = Undefined Then
		QueryText = 
		"SELECT
		|	ExchangeRates.Currency AS Currency,
		|	ExchangeRates.Currency.Code AS CurrencyCode,
		|	MAX(ExchangeRates.Period) AS ExchangeRateDate
		|FROM
		|	InformationRegister.ExchangeRates AS ExchangeRates
		|WHERE
		|	ExchangeRates.Currency.SetRateMethod = VALUE(Enum.ExchangeRateSetupMethod.ExportFromInternet)
		|	AND Not ExchangeRates.Currency.DeletionMark
		|
		|GROUP BY
		|	ExchangeRates.Currency,
		|	ExchangeRates.Currency.Code";
		Query = New Query(QueryText);
		Selection = Query.Execute().Select();
		
		EndOfPeriod = CurrentDate;
		While Selection.Next() Do
			BeginOfPeriod = ?(Selection.ExchangeRateDate = '198001010000', BegOfYear(CurrentDate), Selection.ExchangeRateDate + 60*60*24);
			CurrenciesList = CommonUseClientServer.ValueInArray(Selection);
			
			DataProcessorManager.ExchangeRatesImportByParameters(
				CurrenciesList, BeginOfPeriod, EndOfPeriod, ErrorsOccuredOnImport);
		EndDo;
	Else
		Result = DataProcessorManager.ExchangeRatesImportByParameters(ExportParameters.CurrenciesList,
			ExportParameters.BeginOfPeriod, ExportParameters.EndOfPeriod, ErrorsOccuredOnImport);
	EndIf;
		
	If ResultAddress <> Undefined Then
		PutToTempStorage(Result, ResultAddress);
	EndIf;
	
	If ErrorsOccuredOnImport Then
		WriteLogEvent(
			EventName,
			EventLogLevel.Error,
			, 
			,
			NStr("en = 'Errors occurred during the scheduled job of the exchange rate import'"));
	Else
		WriteLogEvent(
			EventName,
			EventLogLevel.Information,
			,
			,
			NStr("en = 'Scheduled download of exchange rates is completed.'"));
	EndIf;

	
EndProcedure

// Returns currencies array currency rates of which are imported from the website.
//
Function GetImportCurrenciesArray() Export
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	Currencies.Ref AS Ref
	|FROM
	|	Catalog.Currencies AS Currencies
	|WHERE
	|	Currencies.SetRateMethod = VALUE(Enum.ExchangeRateSetupMethod.ExportFromInternet)
	|	AND Not Currencies.DeletionMark
	|
	|ORDER BY
	|	Currencies.DescriptionFull";

	Return Query.Execute().Unload().UnloadColumn("Ref");
	
EndFunction

// Returns information about the exchange rate by reference to the currency.
// Data is returned as a structure.
//
// Parameters:
// SelectedCurrency - Catalog.Currencies / Ref - ref to the
//                  currency, currency rate information of which should be received.
//
// Returns:
// ExchangeRateData   - structure containing information about the
// latest available currency rate record.
//
Function FillRateDataForCurrencies(SelectedCurrency) Export
	
	ExchangeRateData = New Structure("ExchangeRateDate, ExchangeRate, Multiplicity");
	
	Query = New Query;
	
	Query.Text = "SELECT RegExchangeRates.Period, RegExchangeRates.ExchangeRate, RegExchangeRates.Multiplicity
	              | FROM InformationRegister.ExchangeRates.SliceLast(&ImportEndOfPeriod, Currency = &SelectedCurrency) AS RegExchangeRates";
	Query.SetParameter("SelectedCurrency", SelectedCurrency);
	Query.SetParameter("ImportEndOfPeriod", CurrentSessionDate());
	
	SelectionExchangeRate = Query.Execute().Select();
	SelectionExchangeRate.Next();
	
	ExchangeRateData.ExchangeRateDate = SelectionExchangeRate.Period;
	ExchangeRateData.ExchangeRate      = SelectionExchangeRate.ExchangeRate;
	ExchangeRateData.Multiplicity = SelectionExchangeRate.Multiplicity;
	
	Return ExchangeRateData;
	
EndFunction

// Returns values table - currencies that
// depend on the passed as a parameter.
// Return
// value
// ValuesTable column "Ref". - CatalogRef.Currencies
// "Markup" column - Number
//
Function DependentCurrenciesList(CurrencyBasic, AdditionalProperties = Undefined) Export
	
	Cached = (TypeOf(AdditionalProperties) = Type("Structure"));
	
	If Cached Then
		
		DependentCurrencies = AdditionalProperties.DependentCurrencies.Get(CurrencyBasic);
		
		If TypeOf(DependentCurrencies) = Type("ValueTable") Then
			Return DependentCurrencies;
		EndIf;
		
	EndIf;
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	CatCurrencies.Ref,
	|	CatCurrencies.Markup,
	|	CatCurrencies.SetRateMethod,
	|	CatCurrencies.RateCalculationFormula
	|FROM
	|	Catalog.Currencies AS CatCurrencies
	|WHERE
	|	(CatCurrencies.MainCurrency = &CurrencyBasic
	|			OR CatCurrencies.RateCalculationFormula LIKE &SymbolicCode)";
	
	Query.SetParameter("CurrencyBasic", CurrencyBasic);
	Query.SetParameter("SymbolicCode", "%" + CommonUse.ObjectAttributeValue(CurrencyBasic, "Description") + "%");
	
	DependentCurrencies = Query.Execute().Unload();
	
	If Cached Then
		
		AdditionalProperties.DependentCurrencies.Insert(CurrencyBasic, DependentCurrencies);
		
	EndIf;
	
	Return DependentCurrencies;
	
EndFunction

// Returns values table - currency classifier
//
Function GetCurrencyClassifierTable() Export
	
	Builder = New QueryBuilder;
    ClassifierTemplate = Catalogs.Currencies.GetTemplate("CurrencyClassifier");
    
    Builder.DataSource = New DataSourceDescription(ClassifierTemplate.Area());
    Builder.Execute();
	
	Return Builder.Result.Unload();
	
EndFunction

#EndRegion

#Region UpdateOfTheCurrencyExchangeRates

// Checks the exchange rates relevance of all the currencies.
//
Function ExchangeRatesAreRelevant() Export
	QueryText =
	"SELECT
	|	Currencies.Ref AS Ref
	|INTO TTCurrencies
	|FROM
	|	Catalog.Currencies AS Currencies
	|WHERE
	|	Currencies.SetRateMethod = VALUE(Enum.ExchangeRateSetupMethod.ExportFromInternet)
	|	AND Currencies.DeletionMark = FALSE
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	1 AS Field1
	|FROM
	|	TTCurrencies AS Currencies
	|		LEFT JOIN InformationRegister.ExchangeRates AS ExchangeRates
	|		ON Currencies.Ref = ExchangeRates.Currency
	|			AND (ExchangeRates.Period = &CurrentDate)
	|WHERE
	|	ExchangeRates.Currency IS NULL ";
	
	Query = New Query;
	Query.SetParameter("CurrentDate", BegOfDay(CurrentSessionDate()));
	Query.Text = QueryText;
	
	Return Query.Execute().IsEmpty();
EndFunction

// Determines whether there is at least one currency, currency rate of which is imported from the Internet.
//
Function ExchangeRatesExportedFromInternet()
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	1 AS Field1
	|FROM
	|	Catalog.Currencies AS Currencies
	|WHERE
	|	Currencies.SetRateMethod = VALUE(Enum.ExchangeRateSetupMethod.ExportFromInternet)
	|	AND Currencies.DeletionMark = FALSE";
	Return Not Query.Execute().IsEmpty();
EndFunction

// Returns value of ExchangeRatesImportProcessor constant and fill check
//
Function GetConstantExchangeRatesImportProcessor() Export
	
	If CurrenciesImportedFromInternet().Count() = 0 Then
		Raise NStr("en = 'There are no currencies detected which rates should be imported from the Internet. 
		           |In order to enable rate import for a given currency, please navigate to Funds - Currencies, 
		           |edit selected currency, then set value ""imported from the Internet"" for option ""Exchange rate"".'"
		);
	EndIf;
	
	ExtDataProcessor = Constants.ExchangeRatesImportProcessor.Get();
	
	If Not ValueIsFilled(ExtDataProcessor) Then	
		Raise NStr("en = 'Exchange rates import processor isn''t set. 
		           |Configure exchange rates import in the Setting - Support and Service - Classifiers section'"
		);
	EndIf;

	Return ExtDataProcessor;
	
EndFunction

// Returns objeck of external data processor ExchangeRatesImportProcessor
//
Function GetExchangeRatesImportProcessor() Export	
	Return AdditionalReportsAndDataProcessors.GetObjectOfExternalDataProcessor(GetConstantExchangeRatesImportProcessor());
EndFunction

#EndRegion

#Region LocalServiceProceduresAndFunctions

// Highlights from the passed
//  string the first value up to the "TAB" character.
//
// Parameters: 
//  SourceLine - String - String for parsing.
//
// Returns:
//  subrow up to the "TAB" character
//

// Returns currencies list currency rates of which are imported from the Internet.
Function CurrenciesImportedFromInternet() Export
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	Currencies.Ref AS Currency,
	|	Currencies.Code AS CurrencyCode
	|FROM
	|	Catalog.Currencies AS Currencies
	|WHERE
	|	Currencies.SetRateMethod = VALUE(Enum.ExchangeRateSetupMethod.ExportFromInternet)
	|	AND Not Currencies.DeletionMark
	|
	|ORDER BY
	|	Currencies.DescriptionFull";

	Return Query.Execute().Unload();
	
EndFunction

#EndRegion

#Region HandlersOfTheConditionalCallsIntoOtherSubsystems

// Updates links between currencies catalog and supplied
// currency rates file depending on the currencies setting method.
//
// Parameters:
//   Currency - CatalogObject.Currencies
//
Function OnUpdatingExchangeRatesSaaS(Currency) Export
	
	If CommonUse.SubsystemExists("StandardSubsystems.SaaS.CurrenciesSaaS") Then
		ModuleExchangeRatesServiceSaaS = CommonUse.CommonModule("ExchangeRatesServiceSaaS");
		ModuleExchangeRatesServiceSaaS.PlanCopyingRatesOfCurrency(Currency);
	EndIf;
	
EndFunction

#EndRegion

#EndRegion
