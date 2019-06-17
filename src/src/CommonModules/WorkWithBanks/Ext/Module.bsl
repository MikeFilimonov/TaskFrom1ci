////////////////////////////////////////////////////////////////////////////////
// Subsystem "Banks".
//
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

#Region WorkWithTheBankClassifierCatalogData

// Receives data from the BankClassifier catalog by BIC values and bank correspondent account.
// 
// Parameters:
//  BIC          - String - bank identification code.
//  RecordAboutBank - CatalogRef, String - (return) found bank.
Procedure GetBankClassifierData(BIC = "", RecordAboutBank = "") Export
	If Not IsBlankString(BIC) Then
		RecordAboutBank = Catalogs.BankClassifier.FindByCode(BIC);
	Else
		RecordAboutBank = "";
	EndIf;
	If RecordAboutBank = Catalogs.BankClassifier.EmptyRef() Then
		RecordAboutBank = "";
	EndIf;
EndProcedure

#EndRegion

#EndRegion

#Region ServiceProgramInterface

// See details of the same procedure in the StandardSubsystemsServer module.
Procedure OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers) Export
	
	// CLIENT HANDLERS.
	
	ClientHandlers["StandardSubsystems.BasicFunctionality\AfterSystemOperationStart"].Add(
		"WorkWithBanksClient");
	
	// SERVERSIDE HANDLERS.
	
	ServerHandlers["StandardSubsystems.BasicFunctionality\OnAddWorkParametersClientOnStart"].Add(
		"WorkWithBanks");
	
	If CommonUse.SubsystemExists("StandardSubsystems.SaaS.JobQueue") Then
		ServerHandlers["StandardSubsystems.SaaS.JobQueue\OnDefenitionOfUsageOfScheduledJobs"].Add(
			"WorkWithBanks");
	EndIf;
	
	If CommonUse.SubsystemExists("ServiceTechnology.DataExportImport") Then
		ServerHandlers["ServiceTechnology.DataExportImport\WhenFillingCommonDataTypesSupportingMatchingRefsOnImport"].Add(
			"WorkWithBanks");
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.ToDoList") Then
		ServerHandlers["StandardSubsystems.ToDoList\AtFillingToDoList"].Add(
			"WorkWithBanks");
	EndIf;
	
	ServerHandlers["StandardSubsystems.BasicFunctionality\WhenFillingOutPermitsForAccessToExternalResources"].Add(
		"WorkWithBanks");
	
EndProcedure

// Define the list of catalogs available for import using the Import data from file subsystem.
//
// Parameters:
//  ImportedCatalogs - ValueTable - list of catalogs, to which the data can be imported.
//      * FullName          - String - full name of the catalog (as in the metadata).
//      * Presentation      - String - presentation of the catalog in the selection list.
//      *AppliedImport - Boolean - if True, then the catalog uses its own
//                                      importing algorithm and the functions are defined in the catalog manager module.
//
Procedure OnDetermineCatalogsForDataImport(ImportedCatalogs) Export
	
	// Import to the BankClassifier classifier is prohibited.
	TableRow = ImportedCatalogs.Find(Metadata.Catalogs.BankClassifier.FullName(), "FullName");
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
	Objects.Insert(Metadata.Catalogs.BankClassifier.FullName(), "NotEditableInGroupProcessingAttributes");
EndProcedure

#EndRegion

#Region BackgroundJobsProcedures

Procedure ExecuteImportFromFile(ParametersStructure, BackgroundJobStorageAddress = "") Export

	ResultStructure = New Structure;
	ResultStructure.Insert("JobName",		"ExecuteImportFromFile");
	ResultStructure.Insert("Done",			True);
	ResultStructure.Insert("Errors",		Undefined);
	ResultStructure.Insert("ImportedTable",	ParametersStructure.ImportedTable);
	
	ParametersStructure.Delete("ImportedTable");
	
	Try
		DataProc = AdditionalReportsAndDataProcessors.GetObjectOfExternalDataProcessor(ParametersStructure.ExchangeSettings.DataProcessor);
		DataProc.ImportDataFromFile(ParametersStructure, ResultStructure);
	Except
		ResultStructure.Done = False;
		CommonUseClientServer.AddUserError(
			ResultStructure.Errors,
			"",
			BriefErrorDescription(ErrorInfo()),
			"");
	EndTry;
	
	If ResultStructure.Done
		AND ResultStructure.ImportedTable.Count() = 0 Then
		ResultStructure.Done = False;
		CommonUseClientServer.AddUserError(
			ResultStructure.Errors,
			"",
			NStr("en = 'Bank transactions not found in the file'"),
			"");
	EndIf;
	
	PutToTempStorage(ResultStructure, BackgroundJobStorageAddress);
	
EndProcedure

Procedure ExecuteExportToFile(ParametersStructure, BackgroundJobStorageAddress = "") Export
	
	ResultStructure = New Structure;
	ResultStructure.Insert("JobName",		"ExecuteExportToFile");
	ResultStructure.Insert("Done",			True);
	ResultStructure.Insert("Errors",		Undefined);
	ResultStructure.Insert("BinaryData",	"");
	
	Try
		DataProc = AdditionalReportsAndDataProcessors.GetObjectOfExternalDataProcessor(ParametersStructure.ExchangeSettings.DataProcessor);
		DataProc.ExportDataToFile(ParametersStructure, ResultStructure);
	Except
		ResultStructure.Done = False;
		CommonUseClientServer.AddUserError(
			ResultStructure.Errors,
			"",
			BriefErrorDescription(ErrorInfo()),
			"");
	EndTry;
	
	If ResultStructure.Done
		AND TypeOf(ResultStructure.BinaryData) <> Type("BinaryData") Then
		ResultStructure.Done = False;
		CommonUseClientServer.AddUserError(
			ResultStructure.Errors,
			"",
			NStr("en = 'No data to write to file'"),
			"");
	EndIf;
	
	PutToTempStorage(ResultStructure, BackgroundJobStorageAddress);
	
EndProcedure

Procedure ExecuteCreateImportDocuments(ParametersStructure, BackgroundJobStorageAddress = "") Export
	
	ResultStructure = New Structure;
	ResultStructure.Insert("JobName",		"ExecuteCreateImportDocuments");
	ResultStructure.Insert("Done",			True);
	ResultStructure.Insert("Errors",		Undefined);
	ResultStructure.Insert("ImportTable",	"");
	
	Try
		CreateImportDocuments(ParametersStructure, ResultStructure);
	Except
		ResultStructure.Done = False;
		CommonUseClientServer.AddUserError(
			ResultStructure.Errors,
			"",
			BriefErrorDescription(ErrorInfo()),
			"");
	EndTry;
	
	PutToTempStorage(ResultStructure, BackgroundJobStorageAddress);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

#Region BankStatementDocumentCreation

Procedure CreateImportDocuments(ParametersStructure, ResultStructure)
	
	ImportTable = ParametersStructure.ImportTable;
	
	AutomaticallyFillInDebts = ParametersStructure.AutomaticallyFillInDebts;
	
	Counter = 0;
	
	For Each SectionRow In ImportTable Do
		If SectionRow.Mark Then
			
			If Not ValueIsFilled(SectionRow.Document) Then
				ObjectOfDocument = Documents[SectionRow.DocumentKind].CreateDocument();
				IsNewDocument = True;
			Else
				ObjectOfDocument = SectionRow.Document.GetObject();
				IsNewDocument = False;
			EndIf;
			
			If SectionRow.DocumentKind = "PaymentExpense" Then
				FillAttributesPaymentExpense(ObjectOfDocument, SectionRow, IsNewDocument);
			ElsIf SectionRow.DocumentKind = "PaymentReceipt" Then
				FillAttributesPaymentReceipt(ObjectOfDocument, SectionRow, IsNewDocument);
			EndIf;
			
			WriteObject(ObjectOfDocument, SectionRow, IsNewDocument, AutomaticallyFillInDebts, ResultStructure, Counter);
			
			If NOT ValueIsFilled(SectionRow.Document) Then
				SectionRow.Document = ObjectOfDocument.Ref;
			EndIf;
			
		EndIf;
	EndDo;
	
	CommonUseClientServer.AddUserError(
		ResultStructure.Errors,
		"",
		StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = '%1 lines imported successfully.'"),
			Counter),
		"");
	
	ResultStructure.ImportTable = ImportTable;
	
EndProcedure

Procedure SetProperty(Object, PropertyName, PropertyValue, IsNewDocument, RequiredReplacementOfOldValues = False)
	
	If PropertyValue <> Undefined
		AND Object[PropertyName] <> PropertyValue
		AND (IsNewDocument
			OR (NOT ValueIsFilled(Object[PropertyName])
			OR RequiredReplacementOfOldValues)
			OR TypeOf(Object[PropertyName]) = Type("Boolean")
			OR TypeOf(Object[PropertyName]) = Type("Date"))Then
			
			Object[PropertyName] = PropertyValue;
			
	EndIf;
	
EndProcedure

Procedure CalculateRateAndAmountOfAccounts(StringPayment, SettlementsCurrency, ExchangeRateDate, ObjectOfDocument, IsNewDocument)
	
	StructureRateCalculations = GetCurrencyRate(SettlementsCurrency, ExchangeRateDate);
	StructureRateCalculations.ExchangeRate = ?(StructureRateCalculations.ExchangeRate = 0, 1, StructureRateCalculations.ExchangeRate);
	StructureRateCalculations.Multiplicity = ?(StructureRateCalculations.Multiplicity = 0, 1, StructureRateCalculations.Multiplicity);
	
	SetProperty(
		StringPayment,
		"ExchangeRate",
		StructureRateCalculations.ExchangeRate,
		IsNewDocument);
		
	SetProperty(
		StringPayment,
		"Multiplicity",
		StructureRateCalculations.Multiplicity,
		IsNewDocument);
		
	DocumentRateStructure = GetCurrencyRate(ObjectOfDocument.CashCurrency, ExchangeRateDate);
	
	SettlementsAmount = DriveServer.RecalculateFromCurrencyToCurrency(
		StringPayment.PaymentAmount,
		DocumentRateStructure.ExchangeRate,
		StructureRateCalculations.ExchangeRate,
		DocumentRateStructure.Multiplicity,
		StructureRateCalculations.Multiplicity);
	
	SetProperty(
		StringPayment,
		"SettlementsAmount",
		SettlementsAmount,
		IsNewDocument,
		True);
	
EndProcedure

Function GetObjectPresentation(Object)
	
	If TypeOf(Object) = Type("DocumentObject.PaymentReceipt") Then
		NameObject = NStr("en = 'Payment receipt'");
	ElsIf TypeOf(Object) = Type("DocumentObject.PaymentExpense") Then
		NameObject = NStr("en = 'Payment expense'");
	EndIf;
	
	Return StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = '%1 document #%2 dated %3'"),
			NameObject,
			String(TrimAll(Object.Number)),
			String(Object.Date));
	
EndFunction

Procedure FillAttributesPaymentExpense(ObjectOfDocument, SourceData, IsNewDocument)
	
	// Filling out a document header.
	SetProperty(
		ObjectOfDocument,
		"Date",
		SourceData.Received,
		IsNewDocument);
	
	SetProperty(
		ObjectOfDocument,
		"OperationKind",
		SourceData.OperationKind,
		IsNewDocument,
		True);
	
	SetProperty(
		ObjectOfDocument,
		"Company",
		SourceData.Company,
		IsNewDocument);
	
	SetProperty(
		ObjectOfDocument,
		"BankAccount",
		SourceData.BankAccount,
		IsNewDocument,
		True);
	
	SetProperty(
		ObjectOfDocument,
		"CashCurrency",
		SourceData.BankAccount.CashCurrency,
		IsNewDocument,
		True);
	
	SetProperty(
		ObjectOfDocument,
		"Item",
		SourceData.CFItem,
		True,
		IsNewDocument);
	
	SetProperty(
		ObjectOfDocument,
		"DocumentAmount",
		SourceData.Amount,
		IsNewDocument,
		True);
	
	SetProperty(
		ObjectOfDocument,
		"ExternalDocumentNumber",
		SourceData.ExternalDocumentNumber,
		IsNewDocument);
	
	SetProperty(
		ObjectOfDocument,
		"ExternalDocumentDate",
		SourceData.ExternalDocumentDate,
		IsNewDocument);
		
	SetProperty(
		ObjectOfDocument,
		"Paid",
		True,
		IsNewDocument);
		
	SetProperty(
		ObjectOfDocument,
		"PaymentDate",
		SourceData.PaymentDate,
		IsNewDocument);
	
	If IsNewDocument Then
		ObjectOfDocument.SetNewNumber();
		If SourceData.OperationKind = Enums.OperationTypesPaymentExpense.ToCustomer Then
			ObjectOfDocument.VATTaxation = DriveServer.VATTaxation(SourceData.Company, SourceData.Received);
		ElsIf SourceData.OperationKind = Enums.OperationTypesPaymentExpense.LoanSettlements
			OR SourceData.OperationKind = Enums.OperationTypesPaymentExpense.IssueLoanToEmployee Then
			ObjectOfDocument.VATTaxation = Enums.VATTaxationTypes.NotSubjectToVAT;
		Else
			ObjectOfDocument.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT;
		EndIf;
	EndIf;
	
	// Filling document tabular section.
	If SourceData.OperationKind = Enums.OperationTypesPaymentExpense.Vendor
	 OR SourceData.OperationKind = Enums.OperationTypesPaymentExpense.ToCustomer Then
		
		If TypeOf(SourceData.CounterpartyBankAccount) <> Type("String") Then
			SetProperty(
				ObjectOfDocument,
				"CounterpartyAccount",
				SourceData.CounterpartyBankAccount,
				IsNewDocument);
		EndIf;
			
		SetProperty(
			ObjectOfDocument,
			"Counterparty",
			SourceData.Counterparty,
			IsNewDocument);
		
		If ObjectOfDocument.PaymentDetails.Count() = 0 Then
			RowOfDetails = ObjectOfDocument.PaymentDetails.Add();
		Else
			RowOfDetails = ObjectOfDocument.PaymentDetails[0];
		EndIf;
		
		OneRowInDecipheringPayment = ObjectOfDocument.PaymentDetails.Count() = 1;
		
		SetProperty(
			RowOfDetails,
			"Contract",
			SourceData.Contract,
			IsNewDocument);
		
		SetProperty(
			RowOfDetails,
			"AdvanceFlag",
			SourceData.AdvanceFlag,
			IsNewDocument,
			True);
	
		If IsNewDocument
			OR OneRowInDecipheringPayment
				AND RowOfDetails.PaymentAmount <> ObjectOfDocument.DocumentAmount Then
		
			RowOfDetails.PaymentAmount	= ObjectOfDocument.DocumentAmount;
			DateOfFilling				= ObjectOfDocument.Date;
			SettlementsCurrency			= RowOfDetails.Contract.SettlementsCurrency;
			
			CalculateRateAndAmountOfAccounts(
				RowOfDetails,
				SettlementsCurrency,
				DateOfFilling,
				ObjectOfDocument,
				IsNewDocument);
			
			If RowOfDetails.ExchangeRate = 0 Then
				
				SetProperty(
					RowOfDetails,
					"ExchangeRate",
					1,
					IsNewDocument);
				
				SetProperty(
					RowOfDetails,
					"Multiplicity",
					1,
					IsNewDocument);
				
				SetProperty(
					RowOfDetails,
					"SettlementsAmount",
					RowOfDetails.PaymentAmount,
					IsNewDocument);
				
			EndIf;
			
			If ObjectOfDocument.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then
				
				DefaultVATRate	= InformationRegisters.AccountingPolicy.GetDefaultVATRate(ObjectOfDocument.Date, ObjectOfDocument.Company);
				VATRateValue	= DriveReUse.GetVATRateValue(DefaultVATRate);
				
				RowOfDetails.VATRate	= DefaultVATRate;
				RowOfDetails.VATAmount	= RowOfDetails.PaymentAmount - (RowOfDetails.PaymentAmount) / ((VATRateValue + 100) / 100);
				
			Else
				
				If ObjectOfDocument.VATTaxation = Enums.VATTaxationTypes.NotSubjectToVAT Then
					DefaultVATRate = Catalogs.VATRates.Exempt;
				Else
					DefaultVATRate = Catalogs.VATRates.ZeroRate;
				EndIf;
				
				RowOfDetails.VATRate	= DefaultVATRate;
				RowOfDetails.VATAmount	= 0;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure FillAttributesPaymentReceipt(ObjectOfDocument, SourceData, IsNewDocument)
	
	SetProperty(
		ObjectOfDocument,
		"Date",
		SourceData.Received,
		IsNewDocument);
	
	SetProperty(
		ObjectOfDocument,
		"OperationKind",
		SourceData.OperationKind,
		IsNewDocument,
		True);
	
	SetProperty(
		ObjectOfDocument,
		"Company",
		SourceData.Company,
		IsNewDocument);
	
	SetProperty(
		ObjectOfDocument,
		"BankAccount",
		SourceData.BankAccount,
		IsNewDocument,
		True);
	
	SetProperty(
		ObjectOfDocument,
		"CashCurrency",
		SourceData.BankAccount.CashCurrency,
		IsNewDocument,
		True);
	
	SetProperty(
		ObjectOfDocument,
		"Item",
		SourceData.CFItem,
		IsNewDocument,
		True);
	
	SetProperty(
		ObjectOfDocument,
		"DocumentAmount",
		SourceData.Amount,
		IsNewDocument,
		True);
	
	SetProperty(
		ObjectOfDocument,
		"ExternalDocumentNumber",
		SourceData.ExternalDocumentNumber,
		IsNewDocument);
	
	SetProperty(
		ObjectOfDocument,
		"ExternalDocumentDate",
		SourceData.ExternalDocumentDate,
		IsNewDocument);
	
	If IsNewDocument Then
		
		ObjectOfDocument.SetNewNumber();
		
		If ObjectOfDocument.OperationKind = Enums.OperationTypesPaymentReceipt.FromCustomer Then
			ObjectOfDocument.VATTaxation = DriveServer.VATTaxation(SourceData.Company, SourceData.Received);
		Else
			ObjectOfDocument.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT;
		EndIf;
		
	EndIf;
	
	// Filling document tabular section.
	If SourceData.OperationKind = Enums.OperationTypesPaymentReceipt.FromCustomer
		OR SourceData.OperationKind = Enums.OperationTypesPaymentReceipt.FromVendor Then
		
		If TypeOf(SourceData.CounterpartyBankAccount) <> Type("String") Then
			SetProperty(
				ObjectOfDocument,
				"CounterpartyAccount",
				SourceData.CounterpartyBankAccount,
				IsNewDocument);
		EndIf;
		
		SetProperty(
			ObjectOfDocument,
			"Counterparty",
			SourceData.Counterparty,
			IsNewDocument);
		
		If ObjectOfDocument.PaymentDetails.Count() = 0 Then
			RowOfDetails = ObjectOfDocument.PaymentDetails.Add();
		Else
			RowOfDetails = ObjectOfDocument.PaymentDetails[0];
		EndIf;
		
		OneRowInDecipheringPayment = ObjectOfDocument.PaymentDetails.Count() = 1;
		
		SetProperty(
			RowOfDetails,
			"Contract",
			SourceData.Contract,
			IsNewDocument);
		
		SetProperty(
			RowOfDetails,
			"AdvanceFlag",
			SourceData.AdvanceFlag,
			IsNewDocument,
			True);
		
		// Filling document tabular section.
		If IsNewDocument
			OR OneRowInDecipheringPayment
				AND RowOfDetails.PaymentAmount <> ObjectOfDocument.DocumentAmount Then
			
			RowOfDetails.PaymentAmount	= ObjectOfDocument.DocumentAmount;
			DateOfFilling				= ObjectOfDocument.Date;
			SettlementsCurrency			= RowOfDetails.Contract.SettlementsCurrency;
			
			CalculateRateAndAmountOfAccounts(
				RowOfDetails,
				SettlementsCurrency,
				DateOfFilling,
				ObjectOfDocument,
				IsNewDocument);
			
			If RowOfDetails.ExchangeRate = 0 Then
				
				SetProperty(
					RowOfDetails,
					"ExchangeRate",
					1,
					IsNewDocument);
				
				SetProperty(
					RowOfDetails,
					"Multiplicity",
					1,
					IsNewDocument);
				
				SetProperty(
					RowOfDetails,
					"SettlementsAmount",
					RowOfDetails.PaymentAmount,
					IsNewDocument);
				
			EndIf;
			
			If ObjectOfDocument.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then
				
				DefaultVATRate	= InformationRegisters.AccountingPolicy.GetDefaultVATRate(ObjectOfDocument.Date, ObjectOfDocument.Company);
				VATRateValue	= DriveReUse.GetVATRateValue(DefaultVATRate);
				
				RowOfDetails.VATRate	= DefaultVATRate;
				RowOfDetails.VATAmount	= RowOfDetails.PaymentAmount - (RowOfDetails.PaymentAmount) / ((VATRateValue + 100) / 100);
				
			Else
				
				If ObjectOfDocument.VATTaxation = Enums.VATTaxationTypes.NotSubjectToVAT Then
					DefaultVATRate = Catalogs.VATRates.Exempt;
				Else
					DefaultVATRate = Catalogs.VATRates.ZeroRate;
				EndIf;
				
				RowOfDetails.VATRate	= DefaultVATRate;
				RowOfDetails.VATAmount	= 0;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure WriteObject(ObjectToWrite, SectionRow, IsNewDocument, AutomaticallyFillInDebts, ResultStructure, Counter)
	
	DocumentType = ObjectToWrite.Metadata().Name;
	If DocumentType = "PaymentExpense"
		AND AutomaticallyFillInDebts
		AND SectionRow.OperationKind = Enums.OperationTypesPaymentExpense.Vendor Then
		DriveServer.FillPaymentDetailsExpense(ObjectToWrite,,,,, SectionRow.Contract);
	ElsIf DocumentType = "PaymentReceipt"
		AND AutomaticallyFillInDebts
		AND SectionRow.OperationKind = Enums.OperationTypesPaymentReceipt.FromCustomer Then
		DriveServer.FillPaymentDetailsReceipt(ObjectToWrite,,,,, SectionRow.Contract);
	EndIf;
	
	SetProperty(
		ObjectToWrite,
		"PaymentPurpose",
		SectionRow.PaymentPurpose,
		IsNewDocument,
		False);
		
	SetProperty(
		ObjectToWrite,
		"Author",
		Users.CurrentUser(),
		IsNewDocument,
		True);
		
	If ValueIsFilled(SectionRow.ExpenseGLAccount) Then
		SetProperty(
			ObjectToWrite,
			"Correspondence",
			SectionRow.ExpenseGLAccount,
			IsNewDocument);
	EndIf;
		
	ObjectModified	= ObjectToWrite.Modified();
	ObjectPosted	= ObjectToWrite.Posted;
	NameObject		= GetObjectPresentation(ObjectToWrite);
	
	If ObjectModified Then
		
		Try
			
			If ObjectPosted Then
				ObjectToWrite.Write(DocumentWriteMode.UndoPosting);
			Else
				ObjectToWrite.Write(DocumentWriteMode.Write);
			EndIf;
			
			Counter = Counter + 1;
			
		Except
			
			CommonUseClientServer.AddUserError(
				ResultStructure.Errors,
				"Object.Import[%1].Document",
				StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = '%1 %2. Errors occurred while writing.'"),
					NameObject,
					?(ObjectToWrite.IsNew(),
						NStr("en = 'not created'"), 
						NStr("en = 'not written'"))),
				"",
				SectionRow.LineNumber);
			Return;
			
		EndTry;
		
	Else
		CommonUseClientServer.AddUserError(
			ResultStructure.Errors,
			"Object.Import[%1].Document",
			StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = '%1 already exists. Import have been performed earlier.'"),
				NameObject),
			"",
			SectionRow.LineNumber);
	EndIf;
	
EndProcedure

Function GetCurrencyRate(Currency, ExchangeRateDate)
	
	Return InformationRegisters.ExchangeRates.GetLast(ExchangeRateDate, New Structure("Currency", Currency));
	
EndFunction

#EndRegion

// Fills out parameters that are used by the client code when launching the configuration.
//
// Parameters:
//   Parameters (Structure) Start parameters.
//
Procedure OnAddWorkParametersClientOnStart(Parameters) Export
	
	StaleAlertOutput = (
		Not CommonUseReUse.DataSeparationEnabled() // Updated automatically in the service model.
		AND Not CommonUse.IsSubordinateDIBNode() // Updated automatically in DIB node.
		AND AccessRight("Update", Metadata.Catalogs.BankClassifier) // User with the required rights.
		AND Not ClassifierIsActual()); // Classifier is already updated.
	
	EnableAlert = Not CommonUse.SubsystemExists("StandardSubsystems.ToDoList");
	WorkWithBanksOverridable.OnDeterminingWhetherToShowWarningsAboutOutdatedClassifierBanks(EnableAlert);
	
	Parameters.Insert("Banks", New FixedStructure("StaleAlertOutput", (StaleAlertOutput AND EnableAlert)));
	
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
		Or CommonUse.IsSubordinateDIBNode() // Updated automatically in DIB node.
		Or Not AccessRight("Update", Metadata.Catalogs.BankClassifier)
		Or ModuleToDoListService.WorkDisabled("BankClassifier") Then
		Return;
	EndIf;
	ModuleToDoListServer = CommonUse.CommonModule("ToDoListServer");
	
	Result = BankClassifierRelevancy();
	
	// The procedure is called only if there is the
	// To-do lists subsystem, that is why here is no checking of subsystem existence.
	Sections = ModuleToDoListServer.SectionsForObject(Metadata.Catalogs.BankClassifier.FullName());
	
	If Sections = Undefined Then
		Return; // Interface of work with banks is not submitted to the user command interface.
	EndIf;
	
	For Each Section In Sections Do
		
		IdentifierBanks			= "BankClassifier" + StrReplace(Section.FullName(), ".", "");
		Work 					= ToDoList.Add();
		Work.ID  				= IdentifierBanks;
		Work.ThereIsWork       	= Result.ClassifierObsolete;
		Work.Important         	= Result.ClassifierOverdue;
		Work.Presentation  		= NStr("en = 'Bank classifier is outdated'");
		Work.ToolTip      		= StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Last update %1 ago'"), 
			Result.OverdueAmountAsString);
		Work.Form          		= "Catalog.BankClassifier.Form.ImportClassifier";
		Work.FormParameters 	= New Structure("OpenFromList", True);
		Work.Owner       		= Section;
		
	EndDo;
	
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
	NewRow.ScheduledJob = "ImportBankClassifier";
	NewRow.Use       = False;
	
EndProcedure

// Fills the array of types of undivided data for
// which the refs matching during data import to another infobase is supported.
//
// Parameters:
//  Types - Array(MetadataObject)
//
Procedure WhenFillingCommonDataTypesSupportingMatchingRefsOnImport(Types) Export
	
	Types.Add(Metadata.Catalogs.BankClassifier);
	
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
	
	DataProcessorManager = GetBankClassifierImportProcessor();	
	PermissionsQueries.Add(
		WorkInSafeMode.QueryOnExternalResourcesUse(DataProcessorManager.Permissions()));
	
EndProcedure

#Region WorkWithWebsiteData

// Generates and expands text of message to user if classifier data is imported successfully.
// 
// Parameters:
// ClassifierImportParameters - Map:
// Exported						- Number  - Classifier new records quantity.
// Updated						- Number  - Quantity of updated classifier records.
// MessageText					- String - import results message text.
// ImportCompleted               - Boolean - check box of successful classifier data import end.
//
Procedure SupplementMessageText(ClassifierImportParameters) Export
	
	If IsBlankString(ClassifierImportParameters["MessageText"]) Then
		MessageText = NStr("en = 'The bank classifier was imported successfully.'");
	Else
		MessageText = ClassifierImportParameters["MessageText"];
	EndIf;
	
	If ClassifierImportParameters["Exported"] > 0 Then
		
		MessageText = MessageText + StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'New records: %1.'"),
			ClassifierImportParameters["Exported"]);
	
	EndIf;
	
	If ClassifierImportParameters["Updated"] > 0 Then
		
		MessageText = MessageText + StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en = 'Records updated: %1.'"),
		ClassifierImportParameters["Updated"]);

	EndIf;
	
	ClassifierImportParameters.Insert("MessageText", MessageText);
	
EndProcedure

// Receives, sorts, writes bank classifier data from site.
// 
// Parameters:
// ClassifierImportParameters - Map:
// Exported						- Number	 - Classifier new records quantity.
// Updated						- Number	 - Quantity of updated classifier records.
// MessageText					- String - import results message text.
// ImportCompleted              - Boolean - check box of successful classifier data import end.
// StorageAddress				- String - internal storage address.
Procedure GetWebsiteData(ClassifierImportParameters, StorageAddress = "") Export
	
	DataProcessorManager = GetBankClassifierImportProcessor();	
	DataProcessorManager.ImportDataFromWeb(ClassifierImportParameters, StorageAddress);
	
	SetBankClassifierVersion();
	SupplementMessageText(ClassifierImportParameters);
	
	If Not IsBlankString(StorageAddress) Then
		PutToTempStorage(ClassifierImportParameters, StorageAddress);
	EndIf;

EndProcedure

// Receives, sorts, writes bank classifier data from site;
//
Procedure ImportBankClassifier() Export
	
	CommonUse.OnStartExecutingScheduledJob();
	
	EventLevel = EventLogLevel.Information;
	
	If CommonUse.IsSubordinateDIBNode() Then
		WriteLogEvent(EventNameInEventLogMonitor(), EventLevel, , ,
			NStr("en = 'Import is not supported in subordinate DIB node'"));
		Return;
	EndIf;
	
	ClassifierImportParameters = New Map;
	ClassifierImportParameters.Insert("Exported", 0);
	ClassifierImportParameters.Insert("Updated", 0);
	ClassifierImportParameters.Insert("MessageText", "");
	ClassifierImportParameters.Insert("ImportCompleted", False);
	
	GetWebsiteData(ClassifierImportParameters);
	
	If ClassifierImportParameters["ImportCompleted"] Then
		If IsBlankString(ClassifierImportParameters["MessageText"]) Then
			SupplementMessageText(ClassifierImportParameters);
		EndIf;
	Else
		EventLevel = EventLogLevel.Error;
	EndIf;
	
	WriteLogEvent(EventNameInEventLogMonitor(), EventLevel, , , ClassifierImportParameters["MessageText"]);
	
EndProcedure

// Imports bank classifier from file received from file.
Function ImportDataFromFile(FileName) Export
	
	FolderWithExtractedFiles = ExtractFilesFromArchive(FileName);
	Parameters = New Map;
	Parameters.Insert("PathToFile", FolderWithExtractedFiles);
	Parameters.Insert("Exported", 0);
	Parameters.Insert("Updated", 0);
	Parameters.Insert("MessageText", "");
	Parameters.Insert("ImportCompleted", Undefined);
	
	ImportDataFile(Parameters);
	SetBankClassifierVersion();
	
EndFunction

Function ExtractFilesFromArchive(ZipFile)
	
	TemporaryFolder = GetTempFileName();
	CreateDirectory(TemporaryFolder);
	
	Try
		ZipFileReader = New ZipFileReader(ZipFile);
		ZipFileReader.ExtractAll(TemporaryFolder);
	Except
		WriteErrorInEventLogMonitor(DetailErrorDescription(ErrorInfo()));
		DeleteFiles(TemporaryFolder);
	EndTry;
	
	Return TemporaryFolder;
	
EndFunction

Procedure WriteErrorInEventLogMonitor(ErrorText)
	
	WriteLogEvent(EventNameInEventLogMonitor(), EventLogLevel.Error,,, ErrorText);
	
EndProcedure

Function EventNameInEventLogMonitor()
	
	Return NStr("en = 'Bank classifier import. Website'",
	CommonUseClientServer.MainLanguageCode());
	
EndFunction

#EndRegion

#Region WorkWithFileData

// Receives, writes classifier data from file.
// 
// Parameters:
// FilesImportingParameters		 - Map:
// Exported						 - Number		      - Classifier new records quantity.
// Updated						 - Number			  - Quantity of updated classifier records.
// MessageText					 - String			  - import results message text.
// ImportCompleted                - Boolean             - check box of successful classifier data import end.
//
Procedure ImportDataFile(FilesImportingParameters, StorageAddress = "") Export
	
	DataProcessorManager = GetBankClassifierImportProcessor();	
	DataProcessorManager.ImportDataFromFile(FilesImportingParameters, StorageAddress);
	
	SetBankClassifierVersion("");
	
	If IsBlankString(FilesImportingParameters["MessageText"]) Then
		FilesImportingParameters.Insert("ImportCompleted", True);
		SupplementMessageText(FilesImportingParameters);
	EndIf;
	
EndProcedure

#EndRegion

#Region OtherProceduresAndFunctions

// Sets import date value of the classifier data.
// 
// Parameters:
//  VersionDate - DateTime - To import classifier data.
Procedure SetBankClassifierVersion(VersionDate = "") Export
	SetPrivilegedMode(True);
	If TypeOf(VersionDate) <> Type("Date") Then
		Constants.BankClassifierLastUpdate.Set(CurrentUniversalDate());
	Else
		Constants.BankClassifierLastUpdate.Set(VersionDate);
	EndIf;
EndProcedure

// Determines whether classifier data update is required.
//
Function ClassifierIsActual() Export
	SetPrivilegedMode(True);
	LastUpdate = Constants.BankClassifierLastUpdate.Get();
	PermissibleDelay = 30*60*60*24;
	
	If CurrentSessionDate() > LastUpdate + PermissibleDelay Then
		Return False; // There is an overdue.
	EndIf;
	
	Return True;
EndFunction

Function BankClassifierRelevancy()
	
	SetPrivilegedMode(True);
	LastUpdate = Constants.BankClassifierLastUpdate.Get();
	PermissibleDelay = 60*60*24;
	
	Result = New Structure;
	Result.Insert("ClassifierObsolete", False);
	Result.Insert("ClassifierOverdue", False);
	Result.Insert("OverdueAmountAsString", "");
	
	If CurrentSessionDate() > LastUpdate + PermissibleDelay Then
		Result.OverdueAmountAsString = CommonUse.TimeIntervalAsString(LastUpdate, CurrentSessionDate());
		
		OverdueAmount = (CurrentSessionDate() - LastUpdate);
		DaysOverdue = Int(OverdueAmount/60/60/24);
		
		Result.ClassifierObsolete = DaysOverdue >= 1;
		Result.ClassifierOverdue = DaysOverdue >= 7;
	EndIf;
	
	Return Result;
	
EndFunction

// Returns name of external data processor BankClassifierImportProcessor
//
Function GetBankClassifierImportProcessor() Export
	 	
	ExtDataProcessor = Constants.BankClassifierImportProcessor.Get();
	
	If Not ValueIsFilled(ExtDataProcessor) Then	
		Raise NStr("en = 'Bank classifier import processor is not set. 
		           |You can configure it in the Settings - Support and service - Classifiers section'");
	EndIf;
	
	Return AdditionalReportsAndDataProcessors.GetObjectOfExternalDataProcessor(ExtDataProcessor);

EndFunction

// Generates fields structure for settings.
// If you use import from the site you should set "UseImportFromSite" to "True"
// If you use import from the file you should set "UseImportFromFile" to "True"
// You can use both methods.
//
// If you use import from Web you need to set:
//  - Protocol;
//  - Port;
//  - ServerSource;
//  - Address;
//  - ClassifierFileOnWeb;
//
// Returns:
//   Settings - Structure - Additional data processor settings
//
Function Settings() Export

	Settings = New Structure;
	Settings.Insert("UseImportFromWeb", 	False);
	Settings.Insert("UseImportFromFile", 	True);
	Settings.Insert("Protocol", 			"");
	Settings.Insert("Port", 				Undefined);
	Settings.Insert("ServerSource", 		"");
	Settings.Insert("Address", 				"");
	Settings.Insert("ClassifierFileOnWeb",	"");
	
	DataProcessorManager = GetBankClassifierImportProcessor();	
	DataProcessorManager.OnDefineSettings(Settings);
	
	Return Settings;

EndFunction

#EndRegion

#EndRegion
