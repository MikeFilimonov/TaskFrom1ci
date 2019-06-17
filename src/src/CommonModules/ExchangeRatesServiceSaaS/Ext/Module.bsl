////////////////////////////////////////////////////////////////////////////////
// Subsystem "Currencies in service model".
//  
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProgramInterface

// See details of the same procedure in the StandardSubsystemsServer module.
Procedure OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers) Export
	
	// SERVERSIDE HANDLERS.
	
	If CommonUse.SubsystemExists("StandardSubsystems.SaaS.SuppliedData") Then
		ServerHandlers[
			"StandardSubsystems.SaaS.SuppliedData\OnDefenitionHandlersProvidedData"].Add(
			"ExchangeRatesServiceSaaS");
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.SaaS.JobQueue") Then
		ServerHandlers[
			"StandardSubsystems.SaaS.JobQueue\WhenYouDefineAliasesHandlers"].Add(
			"ExchangeRatesServiceSaaS");
	EndIf;
	
	If CommonUse.SubsystemExists("ServiceTechnology.DataExportImport") Then
		ServerHandlers[
			"ServiceTechnology.DataExportImport\AfterDataImportFromOtherMode"].Add(
				"ExchangeRatesServiceSaaS");
	EndIf;
	
EndProcedure

// Import a full exchange rate list since ever.
//
Procedure ImportRates() Export
	
	Descriptors = SuppliedData.ProvidedDataFromManagerDescriptors("ExchangeRates");
	
	If Descriptors.Descriptor.Count() < 1 Then
		Raise(NStr("en = 'There is no data of the ExchangeRates kind in the service manager'"));
	EndIf;
	
	ExchangeRates = SuppliedData.RefOfProvidedDataFromCache("RatesOfOneCurrency");
	For Each ExchangeRate In ExchangeRates Do
		SuppliedData.DeleteProvidedDataFromCache(ExchangeRate);
	EndDo; 
	
	SuppliedData.ImportAndProcessData(Descriptors.Descriptor[0]);
	
EndProcedure

// Called once data is imported to the area.
// Updates exchange rates from the supplied data.
//
Procedure UpdateExchangeRates() Export
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	Currencies.Code
	|FROM
	|	Catalog.Currencies AS Currencies
	|WHERE
	|	Currencies.SetRateMethod = VALUE(Enum.ExchangeRateSetupMethod.ExportFromInternet)";
	Selection = Query.Execute().Select();
	
	// Copy exchange rates. It is to be done synchronously as once UpdateExchangeRates is called, 
	// IB update is processed that tries to lock the base. Copying exchange rates - 
	// long process which can start at any moment in
	// the asynchronous mode and prevent lock.
	While Selection.Next() Do
		CopyExchangeRatesCurrencies(Selection.Code);
	EndDo;
	
EndProcedure

#Region HandlersOfSuppliedDataReceipt

// Registers the handlers of supplied data during the day and since ever.
//
Procedure RegisterProvidedDataHandlers(Val Handlers) Export
	
	Handler = Handlers.Add();
	Handler.DataKind = "ExchangeRatesForDay";
	Handler.ProcessorCode = "ExchangeRatesForDay";
	Handler.Handler = ExchangeRatesServiceSaaS;
	
	Handler = Handlers.Add();
	Handler.DataKind = "ExchangeRates";
	Handler.ProcessorCode = "ExchangeRates";
	Handler.Handler = ExchangeRatesServiceSaaS;
	
EndProcedure

// It is called when a notification of new data received.
// IN the body you should check whether these data is necessary for the application, and if so, - select the Import
// check box.
// 
// Parameters:
//   Descriptor - XDTOObject Descriptor.
//   Import     - Boolean, return.
//
Procedure AvailableNewData(Val Handle, Import) Export
	
	// When receiving ExchangeRatesForDay, file data is written to all stored exchange
	// rates by currency and written to all data areas for the currencies specified in the area. Only rate for
	// the date is written.
	//
	If Handle.DataType = "ExchangeRatesForDay" Then
		Import = True;
	// Data ExchangeRates is received in the following cases - 
	// when IB connects to MS,
	// when you update the IB, when currencies were required after update that were not needed before,
	// when you manually import an exchange rate file to MS.
	// IN all cases reset cache, rewrite all exchange rates in all data areas.
	ElsIf Handle.DataType = "ExchangeRates" Then
		Import = True;
	EndIf;
	
EndProcedure

// It is called after the call of AvailableNewData, allows you to parse data.
//
// Parameters:
//   Descriptor   - XDTOObject Descriptor.
//   PathToFile   - String or Undefined. The full name of the extracted file. File will be deleted automatically after
//                  completion of the procedure. If the file was not specified in the service manager - The argument
//                  value is Undefined.
//
Procedure ProcessNewData(Val Handle, Val PathToFile) Export
	
	If Handle.DataType = "ExchangeRatesForDay" Then
		ProcessProvidedRatesForDay(Handle, PathToFile);
	ElsIf Handle.DataType = "ExchangeRates" Then
		ProcessProvidedRates(Handle, PathToFile);
	EndIf;
	
EndProcedure

// It is called on cancellation of data processing in case of failure.
//
Procedure DataProcessingCanceled(Val Handle) Export 
	
	SuppliedData.AreaProcessed(Handle.FileGUID, "ExchangeRatesForDay", Undefined);
	
EndProcedure

#EndRegion

#EndRegion

#Region ServiceProceduresAndFunctions

#Region EventHandlersOfTheSSLSubsystems

// Fills in the match of methods names and their aliases for call from the jobs queue.
//
// Parameters:
//  AccordanceNamespaceAliases - Correspondence
//   Key - Method alias, for example, ClearDataArea.
//   Value - Method name for call, for example, SaaSOperations.ClearDataArea.
//    You can specify Undefined as a value, in this case, it is
//    considered that name matches the alias.
//
Procedure WhenYouDefineAliasesHandlers(AccordanceNamespaceAliases) Export
	
	AccordanceNamespaceAliases.Insert("ExchangeRatesServiceSaaS.CopyExchangeRatesCurrencies");
	
EndProcedure

// Register the handlers of supplied data.
//
// When getting notification of new common data accessibility the procedure is called.
// AvailableNewData modules registered through GetSuppliedDataHandlers.
// Descriptor is passed to the procedure - XDTOObject Descriptor.
// 
// IN case the AvailableNewData sets the Import argument to true, the data is imported, the descriptor and path to the
// data file are passed to the procedure. ProcessNewData. File will be deleted automatically after completion of the procedure.
// If the file was not specified in the service manager - The argument value is Undefined.
//
// Parameters: 
//   Handlers, ValueTable - The table for adding handlers. 
//       Columns:
//        DataKind, string - the code of data kind processed by the handler.
//        HandlersCode, string (20) - it will be used during restoring data processing after the failure.
//        Handler, CommonModule - the module that contains the following procedures:
//          AvailableNewData(Handle, Import) Export 
//          ProcessNewData(Handle, PathToFile) Export
//          DataProcessingCanceled(Handle) Export
//
Procedure OnDefenitionHandlersProvidedData(Handlers) Export
	
	RegisterProvidedDataHandlers(Handlers);
	
EndProcedure

// It is called once data is imported
// from a local version to the service data area or vice versa.
//
Procedure AfterDataImportFromOtherMode() Export
	
	If CommonUse.SubsystemExists("StandardSubsystems.SaaS.SuppliedData") Then
		// Create links between separated and unseparated currencies, copy exchange rates.
		UpdateExchangeRates();
	EndIf;
	
EndProcedure

#EndRegion

#Region SerializationDeserializationOfExchangeRateFile

// Writes a file in the format of supplied data.
//
// Parameters:
//  ExchangeRatesTable - a ValueTable with columns Code, Date, Multiplier, and Exchange rate.
//  File - String or TextWriter.
//
Procedure WriteExchangeRatesTable(Val ExchangeRatesTable, Val File)
	
	If TypeOf(File) = Type("String") Then
		TextWriter = New TextWriter(File);
	Else
		TextWriter = File;
	EndIf;
	
	For Each TableRow In ExchangeRatesTable Do
			
		XMLExchangeRate = StrReplace(
		StrReplace(
		StrReplace(
			StrReplace("<Rate Code=""%1"" Date=""%2"" Factor=""%3"" Rate=""%4""/>", 
			"%1", TableRow.Code),
			"%2", Left(XDTOSerializer.XMLString(TableRow.Date), 10)),
			"%3", XDTOSerializer.XMLString(TableRow.Multiplicity)),
			"%4", XDTOSerializer.XMLString(TableRow.ExchangeRate));
		
		TextWriter.WriteLine(XMLExchangeRate);
	EndDo; 
	
	If TypeOf(File) = Type("String") Then
		TextWriter.Close();
	EndIf;
	
EndProcedure

// Reads a file in the format of supplied data.
//
// Parameters:
//  PathToFile - String, attachment file name.
//  SearchDuplicates - Boolean, collapses records with the same date.
//
// Return value
//  a ValueTable with columns Code, Date, Multiplier, and Exchange rate.
//
Function ReadExchangeRatesTable(Val PathToFile, Val SearchDuplicates = False)
	
	ExchangeRateDataType = XDTOFactory.Type("http://www.1c.ru/SaaS/SuppliedData/ExchangeRates", "Rate");
	ExchangeRatesTable = New ValueTable();
	ExchangeRatesTable.Columns.Add("Code", New TypeDescription("String", , New StringQualifiers(200)));
	ExchangeRatesTable.Columns.Add("Date", New TypeDescription("Date", , , New DateQualifiers(DateFractions.Date)));
	ExchangeRatesTable.Columns.Add("Multiplicity", New TypeDescription("Number", New NumberQualifiers(9, 0)));
	ExchangeRatesTable.Columns.Add("ExchangeRate", New TypeDescription("Number", New NumberQualifiers(20, 4)));
	
	Read = New TextReader(PathToFile);
	CurrentRow = Read.ReadLine();
	While CurrentRow <> Undefined Do
		
		XMLReader = New XMLReader();
		XMLReader.SetString(CurrentRow);
		ExchangeRate = XDTOFactory.ReadXML(XMLReader, ExchangeRateDataType);
		
		If SearchDuplicates Then
			For Each Duplicate In ExchangeRatesTable.FindRows(New Structure("Date", ExchangeRate.Date)) Do
				ExchangeRatesTable.Delete(Duplicate);
			EndDo;
		EndIf;
		
		WriteCoursesOfCurrency = ExchangeRatesTable.Add();
		WriteCoursesOfCurrency.Code    = ExchangeRate.Code;
		WriteCoursesOfCurrency.Date    = ExchangeRate.Date;
		WriteCoursesOfCurrency.Multiplicity = ExchangeRate.Factor;
		WriteCoursesOfCurrency.ExchangeRate      = ExchangeRate.Rate;

		CurrentRow = Read.ReadLine();
	EndDo;
	Read.Close();
	
	ExchangeRatesTable.Indexes.Add("Code");
	Return ExchangeRatesTable;
		
EndFunction

// It is called when data of kind "ExchangeRates" is received.
//
// Parameters:
//   Descriptor  - XDTOObject Descriptor.
//   PathToFile  - String. The full name of the extracted file.
//
Procedure ProcessProvidedRates(Val Handle, Val PathToFile)
	
	ExchangeRatesTable = ReadExchangeRatesTable(PathToFile);
	ExchangeRatesTable.Indexes.Add("Code");
	
	// Parse into files by currency and write to the base.
	CodeTable = ExchangeRatesTable.Copy( , "Code");
	CodeTable.GroupBy("Code");
	For Each CodeString In CodeTable Do
		
		TempFileName = GetTempFileName();
		WriteExchangeRatesTable(ExchangeRatesTable.FindRows(New Structure("Code", CodeString.Code)), TempFileName);
		
		Handle = New Structure("DataKind, AddingDate, FileID, Characteristics",
			"RatesOfOneCurrency", CurrentUniversalDate(), New UUID, New Array);
		Handle.Characteristics.Add(New Structure("Code, Value, Key", "Currency", CodeString.Code, True));
		
		SuppliedData.SaveProvidedDataToCache(Handle, TempFileName);
		DeleteFiles(TempFileName);
		
	EndDo;
	
	AreasForUpdating = SuppliedData.AreasRequiredProcessing(
		Handle.FileID, "ExchangeRates");
	
	DistributeRatesByOD(, ExchangeRatesTable, AreasForUpdating, 
		Handle.FileID, "ExchangeRates");

EndProcedure

// It is called once new data of kind ExchangeRatesForDay is received.
//
// Parameters:
//   Descriptor   - XDTOObject Descriptor.
//   PathToFile   - String. The full name of the extracted file.
//
Procedure ProcessProvidedRatesForDay(Val Handle, Val PathToFile)
		
	ExchangeRatesTable = ReadExchangeRatesTable(PathToFile);
	
	ExchangeRatesDate = "";
	For Each Characteristic In Handle.Properties.Property Do
		If Characteristic.Code = "Date" Then
			ExchangeRatesDate = Date(Characteristic.Value); 		
		EndIf;
	EndDo; 
	
	If ExchangeRatesDate = "" Then
		Raise NStr("en = 'Data of the ""ExchangeRatesForDay"" kind does not contain the ""Date"" characteristics. Cannot update the rates.'"); 
	EndIf;
	
	AreasForUpdating = SuppliedData.AreasRequiredProcessing(Handle.FileGUID, "ExchangeRatesForDay", True);
	
	IndexOfCommonCourses = AreasForUpdating.Find(-1);
	If IndexOfCommonCourses <> Undefined Then
		
		ExchangeRatesCache = SuppliedData.DescriptorsProvidedDataFromCache("RatesOfOneCurrency", , False);
		If ExchangeRatesCache.Count() > 0 Then
			For Each ExchangeRatesRow In ExchangeRatesTable Do
				
				CacheOfCurrent = Undefined;
				For	Each HandleCache In ExchangeRatesCache Do
					If HandleCache.Characteristics.Count() > 0 
						AND HandleCache.Characteristics[0].Code = "Currency"
						AND HandleCache.Characteristics[0].Value = ExchangeRatesRow.Code Then
						CacheOfCurrent = HandleCache;
						Break;
					EndIf;
				EndDo;
				
				TempFileName = GetTempFileName();
				If CacheOfCurrent <> Undefined Then
					Data = SuppliedData.ProvidedDataFromCache(CacheOfCurrent.FileID);
					Data.Write(TempFileName);
				Else
					CacheOfCurrent = New Structure("DataKind, AddingDate, FileID, Characteristics",
						"RatesOfOneCurrency", CurrentUniversalDate(), New UUID, New Array);
					CacheOfCurrent.Characteristics.Add(New Structure("Code, Value, Key", "Currency", ExchangeRatesRow.Code, True));
				EndIf;
				
				TextWriter = New TextWriter(TempFileName, TextEncoding.UTF8, 
				Chars.LF, True);
				
				TableForWriting = New Array;
				TableForWriting.Add(ExchangeRatesRow);
				WriteExchangeRatesTable(TableForWriting, TextWriter);
				TextWriter.Close();
				
				SuppliedData.SaveProvidedDataToCache(CacheOfCurrent, TempFileName);
				DeleteFiles(TempFileName);
			EndDo;
			
		EndIf;
		
		AreasForUpdating.Delete(IndexOfCommonCourses);
	EndIf;
	
	DistributeRatesByOD(ExchangeRatesDate, ExchangeRatesTable, AreasForUpdating, 
		Handle.FileGUID, "ExchangeRatesForDay");

EndProcedure

// Copies all exchange rates to OD
//
// Parameters:
//  ExchangeRatesDate - Date or Undefined. Exchange rates are added for the specified date or since ever.
//  ExchangeRatesTable - ValueTable with exchange rates.
//  AreasForUpdating - Array with a list of area codes.
//  FileID - UUID of processed exchange rate file.
//  ProcessorCode - String, handler code.
//
Procedure DistributeRatesByOD(Val ExchangeRatesDate, Val ExchangeRatesTable, 
	Val AreasForUpdating, Val FileID, Val ProcessorCode)
	
	For Each DataArea In AreasForUpdating Do
	
		CommonUse.SetSessionSeparation(True, DataArea);
		
		CurrencyQuery = New Query;
		CurrencyQuery.Text = 
		"SELECT
		|	Currencies.Ref,
		|	Currencies.Code
		|FROM
		|	Catalog.Currencies AS Currencies
		|WHERE
		|	Currencies.SetRateMethod = VALUE(Enum.ExchangeRateSetupMethod.ExportFromInternet)";
		
		SelectionCurrencies = CurrencyQuery.Execute().Select();
		BeginTransaction();
		While SelectionCurrencies.Next() Do
		
			ExchangeRates = ExchangeRatesTable.FindRows(New Structure("Code", SelectionCurrencies.Code));
			If ExchangeRates.Count() = 0 Then
				Continue;
			EndIf;
		
			RecordSet = InformationRegisters.ExchangeRates.CreateRecordSet();
			RecordSet.Filter.Currency.Set(SelectionCurrencies.Ref);
			If ExchangeRatesDate <> Undefined Then
				RecordSet.Filter.Period.Set(ExchangeRatesDate);
			Else 
				// Lock inefficient updates of related currencies.
				RecordSet.DataExchange.Load = True;
			EndIf;
			
			For Each ExchangeRatesRow In ExchangeRates Do
				Record = RecordSet.Add();
				Record.Currency = SelectionCurrencies.Ref;
				Record.Period = ExchangeRatesRow.Date;
				Record.Multiplicity = ExchangeRatesRow.Multiplicity;
				Record.ExchangeRate = ExchangeRatesRow.ExchangeRate;
			EndDo; 
			RecordSet.Write();
			
		EndDo;
		SuppliedData.AreaProcessed(FileID, ProcessorCode, DataArea);
		CommitTransaction();
	EndDo;
	
EndProcedure

// It is called if a method of setting the exchange rate is changed.
//
// Currency - CatalogRef.Currencies
//
Procedure PlanCopyingRatesOfCurrency(Val Currency) Export
	
	If Currency.SetRateMethod <> Enums.ExchangeRateSetupMethod.ExportFromInternet Then
		Return;
	EndIf;
	
	MethodParameters = New Array;
	MethodParameters.Add(Currency.Code);

	JobParameters = New Structure;
	JobParameters.Insert("MethodName", "ExchangeRatesServiceSaaS.CopyExchangeRatesCurrencies");
	JobParameters.Insert("Parameters", MethodParameters);
	
	SetPrivilegedMode(True);
	JobQueue.AddJob(JobParameters);

EndProcedure

// It is called once data is imported to the area or when changing a method of setting an exchange rate.
// Copies all exchange rates of a single currency from unseparated xml file to a separated register for all dates.
// 
// Parameters:
//  CurrencyCode - String
//
Procedure CopyExchangeRatesCurrencies(Val CurrencyCode) Export
	
	CurrencyRef = Catalogs.Currencies.FindByCode(CurrencyCode);
	If CurrencyRef.IsEmpty() Then
		Return;
	EndIf;
	
	ExchangeRateDataType = XDTOFactory.Type("http://www.1c.ru/SaaS/SuppliedData/ExchangeRates", "Rate");
	
	Filter = New Array;
	Filter.Add(New Structure("Code, Value", "Currency", CurrencyCode));
	ExchangeRates = SuppliedData.RefOfProvidedDataFromCache("RatesOfOneCurrency", Filter);
	If ExchangeRates.Count() = 0 Then
		Return;
	EndIf;
	
	PathToFile = GetTempFileName();
	SuppliedData.ProvidedDataFromCache(ExchangeRates[0]).Write(PathToFile);
	ExchangeRatesTable = ReadExchangeRatesTable(PathToFile, True);
	DeleteFiles(PathToFile);
	
	ExchangeRatesTable.Columns.Date.Name = "Period";
	ExchangeRatesTable.Columns.Add("Currency");
	ExchangeRatesTable.FillValues(CurrencyRef, "Currency");
	
	RecordSet = InformationRegisters.ExchangeRates.CreateRecordSet();
	RecordSet.Filter.Currency.Set(CurrencyRef);
	RecordSet.Load(ExchangeRatesTable);
	RecordSet.DataExchange.Load = True;
	RecordSet.Write();

EndProcedure

#EndRegion

#EndRegion
