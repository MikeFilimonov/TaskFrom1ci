﻿#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Services_methods

// Fill in empty dates with dates
// from accounting documents for the CounterpartyData tabular section
Procedure FillEmptyDatesForCounterpartyAtServer(CounterpartyData) Export
	
	If Not ValueIsFilled(CounterpartyData) Then
		Return;
	EndIf;
	
EndProcedure

// Sets status for documents array
//
// Parameters:
// DocumentArray - Array(DocumentRef.ReconciliationStatement) 	  - Array of documents for
// status setting StatusValue  - EnumRef.ReconciliationStatementStatus - Set status
//
// Return value: Boolean - Function execution result
//
Function SetStatus(DocumentArray, StatusValue) Export

	Query = New Query("
		|SELECT ALLOWED
		|	Table.Ref AS Ref
		|FROM
		|	Document.ReconciliationStatement AS Table
		|WHERE
		|	Table.Status <> &Status
		|	AND Table.Ref IN(&DocumentArray)
		|	AND Not Table.DeletionMark
		|");
	Query.SetParameter("DocumentArray", DocumentArray);
	Query.SetParameter("Status", StatusValue);
	Selection = Query.Execute().Select();

	NumberOfProcessed = 0;

	BeginTransaction();
	While Selection.Next() Do

		Try
			LockDataForEdit(Selection.Ref);
		Except

			ErrorText = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Failed to lock %1. %2'"),
				Selection.Ref,
				BriefErrorDescription(ErrorInfo()));
			Raise ErrorText;

		EndTry;

		DocObject 			= Selection.Ref.GetObject();
		DocObject.Status 	= StatusValue;
		
		Try
		
			DocObject.Write(DocumentWriteMode.Write);
			NumberOfProcessed = NumberOfProcessed + 1;
			
		Except
		
			ErrorText = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Unable to write %1. %2'"),
				Selection.Ref,
				BriefErrorDescription(ErrorInfo()));
			Raise ErrorText;

		EndTry;

	EndDo;

	CommitTransaction();

	Return NumberOfProcessed;

EndFunction

#EndRegion

#Region description_and_Presentation_details

// Procedure processes query data and fills in document string (strings)
//
// Parameters:
//	DataSelectionFromQuery - query data for transfer to
//	the DocumentDataStructure tabular section - data structure from reconciliation document according to which query is generated
//
//	DocumentCurrentStringFieldsStructure - structure of the ReconciliationStatements
//											current string fields If the RemainingsInput document is selected, you can add strings
//
Function GetCompanyRowData(DocumentData, Selection) Export
	
	RowData = New Structure;
	
	RowData.Insert("DocumentNumber", 		Selection.DocumentNumber);
	RowData.Insert("DocumentDate",			Selection.Period);
	RowData.Insert("Contract", 				Selection.Contract);
	RowData.Insert("ContractCurrency", 		Selection.ContractCurrency);
	RowData.Insert("AccountingDocument", 	Selection.AccountingDocument);
	
	DocumentDescription = CompanyAccountingDocumentDescription(Selection.AccountingDocument, "", Undefined, DocumentData.CompanyToPresentation);
	RowData.Insert("DocumentDescription", DocumentDescription);
	
	Amount = 0;
	If Selection.AmountCurTurnover > 0 Then 
		
		Amount = Selection.AmountCurTurnover; 
		StructureKey = "ClientDebtAmount";
		
	Else
		
		Amount = -Selection.AmountCurTurnover; 
		StructureKey = "CompanyDebtAmount";
		
	EndIf;
	
	If Selection.ContractCurrency <> DocumentData.DocumentCurrency Then
		
		SettlementsCurrencyRate = WorkWithExchangeRates.GetCurrencyRate(Selection.ContractCurrency, DocumentData.Date);
		DocumentCurrencyRate = WorkWithExchangeRates.GetCurrencyRate(DocumentData.DocumentCurrency, DocumentData.Date);
		
		Amount = WorkWithExchangeRatesClientServer.RecalculateFromCurrencyToCurrency(Amount, Selection.ContractCurrency, DocumentData.DocumentCurrency, SettlementsCurrencyRate.ExchangeRate, DocumentCurrencyRate.ExchangeRate, SettlementsCurrencyRate.Multiplicity, DocumentCurrencyRate.Multiplicity);
		
	EndIf;
	
	RowData.Insert(StructureKey, Amount);
	
	Return RowData;
	
EndFunction

// Returns documents listing with their synonyms for the Reconciliation statement 
//
Function GetDocumentPresentationsForCounterparties()
	
	DocumentTypesCounterparty = New Structure;
	
	DocumentTypesCounterparty.Insert("ExpenseReport",				NStr("en = 'Sales invoice'"));
	DocumentTypesCounterparty.Insert("ArApAdjustments",				NStr("en = 'AR/AP adjustment'"));
	DocumentTypesCounterparty.Insert("SalesOrder",					NStr("en = 'Purchase order'"));
	DocumentTypesCounterparty.Insert("PurchaseOrder",				NStr("en = 'Sales order'"));
	DocumentTypesCounterparty.Insert("RegistersCorrection",			NStr("en = 'AR/AP adjustment'"));
	DocumentTypesCounterparty.Insert("AccountSalesFromConsignee",	NStr("en = 'Account sales to consignor'"));
	DocumentTypesCounterparty.Insert("AccountSalesToConsignor",		NStr("en = 'Account sales from consignee'"));
	DocumentTypesCounterparty.Insert("PaymentReceipt",				NStr("en = 'Bank payment'"));
	DocumentTypesCounterparty.Insert("CashReceipt",					NStr("en = 'Cash voucher'"));
	DocumentTypesCounterparty.Insert("PaymentExpense",				NStr("en = 'Bank receipt'"));
	DocumentTypesCounterparty.Insert("CashVoucher",					NStr("en = 'Cash receipt'"));
	DocumentTypesCounterparty.Insert("SupplierInvoice",				NStr("en = 'Sales invoice'"));
	DocumentTypesCounterparty.Insert("SalesInvoice",				NStr("en = 'Supplier invoice'"));
	
	Return DocumentTypesCounterparty;
	
EndFunction

// Receives an incoming number by
// the counterparty document if it is not possible to receive number, it returns an empty string
Function GetIncNumber(DocumentRef, DecryptionJSC = Undefined) Export
	
	IncomingDocumentNumber = "";
	If Not ValueIsFilled(DocumentRef) Then 
		
		Return IncomingDocumentNumber;
		
	EndIf;
	
	// Possible accounting documents list in description
	If TypeOf(DocumentRef) = Type("DocumentRef.ExpenseReport") 
		AND TypeOf(DecryptionJSC) = Type("Structure") Then
		
		Query = New Query;
		Query.SetParameter("Contract", DecryptionJSC.Contract);
		Query.SetParameter("PaymentAmount", DecryptionJSC.PaymentAmount);
		Query.Text = "SELECT AO.IncomingDocumentNumber FROM Document.ExpenseReport.Payments AS AO WHERE AO.AdvanceFlag AND AO.Contract = &Contract AND AO.PaymentAmount = &PaymentAmount";
		
		Selection = Query.Execute().Select();
		If Selection.Next() Then
			
			IncomingDocumentNumber = Selection.IncomingDocumentNumber;
			
		EndIf;
		
	ElsIf DriveServer.IsDocumentAttribute("IncomingDocumentNumber", DocumentRef.Metadata()) Then
		
		IncomingDocumentNumber = DocumentRef.IncomingDocumentNumber;
		
	EndIf;
	
	Return IncomingDocumentNumber;
	
EndFunction

// Receives an incoming date
// by the counterparty document if it is not possible to receive date, it returns an empty date
Function GetIncDate(DocumentRef, DecryptionJSC = Undefined) Export
	
	IncomingDocumentDate = Date(01, 01, 01);
	If Not ValueIsFilled(DocumentRef) Then 
		
		Return IncomingDocumentDate;
		
	EndIf;
	
	// List of possible accounting documents in the description to the GetLoginNumber() function
	If TypeOf(DocumentRef) = Type("DocumentRef.ExpenseReport") 
		AND TypeOf(DecryptionJSC) = Type("Structure") Then
		
		Query = New Query;
		Query.SetParameter("Contract", DecryptionJSC.Contract);
		Query.SetParameter("PaymentAmount", DecryptionJSC.PaymentAmount);
		Query.Text = "SELECT AO.IncomingDocumentDate FROM Document.ExpenseReport.Payments AS AO WHERE AO.AdvanceFlag AND AO.Contract = &Contract AND AO.PaymentAmount = &PaymentAmount";
		
		Selection = Query.Execute().Select();
		If Selection.Next() Then
			
			IncomingDocumentDate = Selection.IncomingDocumentDate;
			
		EndIf;
		
	ElsIf DriveServer.IsDocumentAttribute("IncomingDocumentDate", DocumentRef.Metadata()) Then
		
		IncomingDocumentDate = DocumentRef.IncomingDocumentDate;
		
	EndIf;
	
	Return IncomingDocumentDate;
	
EndFunction

// Returns data of Reconciliation statement 
//
// Parameters:
//    DocumentPrint - DocumentRef.ReconciliationStatement - Document for selection
//
// Return value: Selection from query result
//
Function PrintingDocumentsData(DocumentPrint) Export
	
	QueryDocumentData = New Query;
	QueryDocumentData.SetParameter("DocumentPrint", DocumentPrint);
	
	QueryDocumentData.Text =
	"SELECT
	|	DocumentData.Ref AS DocumentRef
	|	,DocumentData.DataVersion
	|	,DocumentData.DeletionMark
	|	,DocumentData.Number
	|	,DocumentData.Date
	|	,DocumentData.Posted
	|	,DocumentData.Company
	|	,DocumentData.Counterparty
	|	,DocumentData.BeginOfPeriod
	|	,DocumentData.EndOfPeriod
	|	,DocumentData.Status
	|	,DocumentData.Responsible AS Responsible
	|	,DocumentData.Comment
	|	,DocumentData.CounterpartyRepresentative AS CounterpartyRepresentative
	|	,DocumentData.CounterpartyRepresentative.Position AS CounterpartyRepresentativePosition
	|	,DocumentData.Author
	|	,DocumentData.Presentation
	|	,DocumentData.PointInTime
	|	,DocumentData.BalanceBeginPeriod AS BalanceBeginPeriod
	|	,DocumentData.SortByContracts
	|	,DocumentData.DocumentDescription
	|	,EmployeesInformation.Position AS CompanyRepresentativePosition
	|	,DocumentData.DocumentCurrency AS DocumentCurrency
	|	,DocumentData.CompanyData.(
	|		Ref,
	|		LineNumber,
	|		DocumentDate,
	|		DocumentNumber,
	|		AccountingDocument,
	|		Contract,
	|		DocumentDescription AS CompanyDocumentDescription,
	|		CompanyDebtAmount,
	|		ClientDebtAmount,
	|		ContractCurrency
	|	) AS CompanyData
	|	,DocumentData.CounterpartyData.(
	|		Ref
	|		,LineNumber
	|		,Contract
	|		,IncomingDocumentDate
	|		,IncomingDocumentNumber
	|		,AccountingDocument
	|		,DocumentDescription AS CounterpartyDocumentDescription
	|		,DocumentCurrency
	|		,CompanyDebtAmount
	|		,ClientDebtAmount
	|	)
	|	,DocumentData.CounterpartyContracts.(
	|		Ref
	|		,LineNumber
	|		,CounterpartyContracts.Select
	|		,Contract
	|	) AS CounterpartyContracts
	|FROM
	|	Document.ReconciliationStatement AS DocumentData
	|		LEFT JOIN InformationRegister.Employees.SliceLast AS EmployeesInformation
	|		ON DocumentData.Date >= EmployeesInformation.Period
	|			AND DocumentData.Company = EmployeesInformation.Company
	|			AND DocumentData.Responsible = EmployeesInformation.Employee
	|WHERE
	|	DocumentData.Ref IN(&DocumentPrint)
	|
	|ORDER BY
	|	DocumentData.Date
	|	,DocumentData.Number";
	
	Return QueryDocumentData.Execute();
	
EndFunction

// Returns accouning document presentation for the Reconciliation statement 
//
// Parameters:
//    DocumentRef 	- DocumentRef 	- Ref to accounting document;
//    Number		- String		- Accounting document
//    number Date	- Date			- Payment document date
//
// Return value: String.
//
Function CompanyAccountingDocumentDescription(DocumentRef, DocumentNumber = "" , Val DocumentDate, CompanyToPresentation = False) Export
	
	If DocumentRef = Undefined Then
		
		DescriptionString =  NStr("en = 'Settlement document #%1 dated %2'");
		DescriptionString = StringFunctionsClientServer.SubstituteParametersInString(DescriptionString, 
			?(IsBlankString(DocumentNumber), NStr("en = '_______'"), ObjectPrefixationClientServer.GetNumberForPrinting(DocumentNumber, False, True)), 
			?(ValueIsFilled(DocumentDate), Format(DocumentDate, "DLF=D"), NStr("en = '___.___.________'"))
			);
		
		Return DescriptionString;
		
	EndIf;
	
	// Document description
	DocumentDescription = String(TypeOf(DocumentRef));
	
	// Addition to description
	AddToDescriptionFull = "";
	If TypeOf(DocumentRef) = Type("DocumentRef.GoodsReceipt")
		AND DocumentRef.OperationKind = Enums.OperationTypesGoodsReceipt.ReturnFromAThirdParty Then
		
		AddToDescriptionFull = " (return from customer)";
		
	ElsIf TypeOf(DocumentRef) = Type("DocumentRef.GoodsIssue")
		AND DocumentRef.OperationKind = Enums.OperationTypesGoodsIssue.ReturnToAThirdParty Then
		
		AddToDescriptionFull = " (return to vendor)";
		
	EndIf;
	
	// Document No.
	If IsBlankString(DocumentNumber) Then
		
		DocumentNumber = DocumentRef.Number;
		
	EndIf;
	DocumentNumber = ObjectPrefixationClientServer.GetNumberForPrinting(DocumentNumber, False, True);
	
	// Document date
	If Not ValueIsFilled(DocumentDate) Then
		
		DocumentDate = DocumentRef.Date;
		
	EndIf;
	DocumentDate = Format(DocumentDate, "DLF=D");
	
	SetCompanyPresentation = "";
	If CompanyToPresentation Then
		
		SetCompanyPresentation = "' ('" + DocumentRef.Company.DescriptionFull + "')'";
		
	EndIf;
	
	Return DocumentDescription + AddToDescriptionFull + " " + StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en = '#%1, %2.'"),
		DocumentNumber, 
		DocumentDate)
	+ SetCompanyPresentation;
	
EndFunction

// Returns accouning document presentation for the Reconciliation statement 
//
// Parameters:
//    DocumentRef 		- DocumentRef 	- Ref to accounting document;
//    Number			- String		- Accounting document
//    number Date		- Date			- Payment document date
//
// Return value: String.
//
Function CounterpartyAccountingDocumentDescription(DocumentRef, Val DocumentNumber, Val DocumentDate, CompanyToPresentation = False) Export
	
	// Process number and date immediately as it is needed for an empty ref
	DocumentNumber	= ?(IsBlankString(DocumentNumber), "_______", ObjectPrefixationClientServer.GetNumberForPrinting(DocumentNumber, False, True));
	DocumentDate	= ?(ValueIsFilled(DocumentDate), Format(DocumentDate, "DLF=D"), "___.___._______");
	
	If DocumentRef = Undefined Then
		
		DescriptionString = NStr("en = 'Settlement document #%1 dated %2'");
		DescriptionString = StringFunctionsClientServer.SubstituteParametersInString(DescriptionString, DocumentNumber, DocumentDate);
		
		Return DescriptionString;
		
	EndIf;
	
	// Document description
	DocumentDescription = "";
	CounterpartyDocumentsPresentation = GetDocumentPresentationsForCounterparties();
	CounterpartyDocumentsPresentation.Property(DocumentRef.Metadata().Name, DocumentDescription);
	
	If IsBlankString(DocumentDescription) Then
		
		DocumentDescription = NStr("en = 'Payment document'");
		
	EndIf;
	
	// Addition to description
	AddToDescriptionFull = "";
	If TypeOf(DocumentRef) = Type("DocumentRef.GoodsReceipt") 
		AND DocumentRef.OperationKind = Enums.OperationTypesGoodsReceipt.ReturnFromAThirdParty Then
		
		AddToDescriptionFull = " (" + NStr("en = 'return to supplier'") + ")";
		
	ElsIf TypeOf(DocumentRef) = Type("DocumentRef.GoodsIssue") 
		AND DocumentRef.OperationKind = Enums.OperationTypesGoodsIssue.ReturnToAThirdParty Then
		
		AddToDescriptionFull = " (" + NStr("en = 'return from customer'") + ")";
		
	EndIf;
	
	// Company when the "Accounting by company" option is enabled.
	SetCompanyPresentation = "";
	If CompanyToPresentation Then
		
		SetCompanyPresentation = " (" + DocumentRef.Company.DescriptionFull + ")";
		
	EndIf;
	
	Return DocumentDescription + AddToDescriptionFull + " " + StringFunctionsClientServer.SubstituteParametersInString( 
		NStr("en = '#%1, %2.'"),
		DocumentNumber, 
		DocumentDate)
	+ " " + SetCompanyPresentation;
	
EndFunction

#EndRegion

#Region Filling_CWT

// Procedure fills in tabular section "Company data".
//
// Parameters:
// DocumentData	 - Structure					- Reconciliation statement data;
// TabularSection	 - Document tabular section	- Tabular section for filling.
//
Procedure FillDataByCompany(DocumentData, TabularSection) Export
	
	SetPrivilegedMode(True);
	
	TabularSection.Clear();
	QueryResult = GetCompanyDataSelection(DocumentData);
	
	Selection = QueryResult.Select();
	While Selection.Next() Do
		
		NewRow = TabularSection.Add();
		DataStructure = GetCompanyRowData(DocumentData, Selection);
		
		FillPropertyValues(NewRow, DataStructure);
		
	EndDo;
	
	SetPrivilegedMode(False);
	
EndProcedure

// Procedure fills in tabular section "Company data".
//
Procedure FillCounterpartyInformationByCompanyData(CompanyData, CounterpartyData, CompanyToPresentation = False) Export
	
	CounterpartyData.Clear();
	For Each CompanyRow In CompanyData Do
		
		CounterpartyRow = CounterpartyData.Add();
		FillPropertyValues(CounterpartyRow, CompanyRow, "AccountingDocument, Contract");
		CounterpartyRow.DocumentCurrency = CompanyRow.ContractCurrency;
		
		DecryptionJSC = Undefined;
		If TypeOf(CompanyRow.AccountingDocument) = Type("DocumentRef.ExpenseReport") Then
			
			DecryptionJSC = New Structure;
			DecryptionJSC.Insert("Contract", CompanyRow.Contract);
			DecryptionJSC.Insert("PaymentAmount", CompanyRow.ClientDebtAmount);
			
		EndIf;
		
		CounterpartyRow.IncomingDocumentNumber = GetIncNumber(CompanyRow.AccountingDocument, DecryptionJSC);
		CounterpartyRow.IncomingDocumentDate = GetIncDate(CompanyRow.AccountingDocument, DecryptionJSC);
		
		CounterpartyRow.DocumentDescription = CounterpartyAccountingDocumentDescription(CompanyRow.AccountingDocument, CounterpartyRow.IncomingDocumentNumber, CounterpartyRow.IncomingDocumentDate, CompanyToPresentation);
		
		CounterpartyRow.CompanyDebtAmount = CompanyRow.ClientDebtAmount;
		CounterpartyRow.ClientDebtAmount = CompanyRow.CompanyDebtAmount;
		
	EndDo;
	
EndProcedure

#EndRegion

#Region DataReceiving

// Returns data selection by accounts payable
// balance by the registers "Accounts receivable" and "Accounts payable"
// 
// Parameters:
//    DocumentsData - Structure - Structure containing fields:
//    									Company - CatalogRef.Companies - Company for selection from registers;
//    									Counterparty  - CatalogRef.Counterparties - Counterparty for selection from registers;
//    									EndOfPeriod - Date - Period for balance receipt.
// Returns:
//    Selection from query result OR Undefined - if query result is empty.
//
Function GetCompanyDataSelection(DocumentData) Export
	
	CompanyDataQuery = New Query;
	CompanyDataQuery.Text = 
	"SELECT
	|	CASE
	|		WHEN CAST(CustomersSettlementsTurnovers.Recorder AS Document.SalesOrder) REFS Document.SalesOrder
	|			THEN CustomersSettlementsTurnovers.Recorder.Finish
	|		WHEN CAST(CustomersSettlementsTurnovers.Recorder AS Document.OpeningBalanceEntry) REFS Document.OpeningBalanceEntry
	|			THEN CASE
	|					WHEN CAST(CustomersSettlementsTurnovers.Document AS Document.SalesOrder) REFS Document.SalesOrder
	|						THEN CustomersSettlementsTurnovers.Document.Finish
	|					ELSE CustomersSettlementsTurnovers.Document.Date
	|				END
	|		WHEN CAST(CustomersSettlementsTurnovers.Recorder AS Document.RegistersCorrection) REFS Document.RegistersCorrection
	|			THEN CASE
	|					WHEN CAST(CustomersSettlementsTurnovers.Document AS Document.SalesOrder) REFS Document.SalesOrder
	|						THEN CustomersSettlementsTurnovers.Document.Finish
	|					ELSE CustomersSettlementsTurnovers.Document.Date
	|				END
	|		ELSE CustomersSettlementsTurnovers.Recorder.Date
	|	END AS Period,
	|	CASE
	|		WHEN CAST(CustomersSettlementsTurnovers.Recorder AS Document.OpeningBalanceEntry) REFS Document.OpeningBalanceEntry
	|			THEN CustomersSettlementsTurnovers.Document.Number
	|		WHEN CAST(CustomersSettlementsTurnovers.Recorder AS Document.RegistersCorrection) REFS Document.RegistersCorrection
	|			THEN CustomersSettlementsTurnovers.Document.Number
	|		ELSE CustomersSettlementsTurnovers.Recorder.Number
	|	END AS DocumentNumber,
	|	CustomersSettlementsTurnovers.Contract AS Contract,
	|	CustomersSettlementsTurnovers.Contract.ContractDate AS ContractDate,
	|	CustomersSettlementsTurnovers.Contract.SettlementsCurrency AS ContractCurrency,
	|	CASE
	|		WHEN CAST(CustomersSettlementsTurnovers.Recorder AS Document.OpeningBalanceEntry) REFS Document.OpeningBalanceEntry
	|			THEN CustomersSettlementsTurnovers.Document
	|		WHEN CAST(CustomersSettlementsTurnovers.Recorder AS Document.RegistersCorrection) REFS Document.RegistersCorrection
	|			THEN CustomersSettlementsTurnovers.Document
	|		ELSE CustomersSettlementsTurnovers.Recorder
	|	END AS AccountingDocument,
	|	CustomersSettlementsTurnovers.Recorder,
	|	SUM(CustomersSettlementsTurnovers.AmountCurTurnover) AS AmountCurTurnover
	|FROM
	|	AccumulationRegister.AccountsReceivable.Turnovers(
	|			,
	|			,
	|			Recorder,
	|			Company = &Company
	|				AND Contract IN (&ContractsArray)) AS CustomersSettlementsTurnovers
	|WHERE
	|	Not ISNULL(CAST(CustomersSettlementsTurnovers.Recorder AS Document.MonthEndClosing) REFS Document.MonthEndClosing, FALSE)
	|	AND CASE
	|			WHEN CAST(CustomersSettlementsTurnovers.Recorder AS Document.SalesOrder) REFS Document.SalesOrder
	|				THEN CustomersSettlementsTurnovers.Recorder.Finish between &BeginOfPeriod AND &EndOfPeriod
	|			ELSE CustomersSettlementsTurnovers.Recorder.Date between &BeginOfPeriod AND &EndOfPeriod
	|		END
	|	AND &SelectDocumentDataByCustomers
	|
	|GROUP BY
	|	CASE
	|		WHEN CAST(CustomersSettlementsTurnovers.Recorder AS Document.SalesOrder) REFS Document.SalesOrder
	|			THEN CustomersSettlementsTurnovers.Recorder.Finish
	|		WHEN CAST(CustomersSettlementsTurnovers.Recorder AS Document.OpeningBalanceEntry) REFS Document.OpeningBalanceEntry
	|			THEN CASE
	|					WHEN CAST(CustomersSettlementsTurnovers.Document AS Document.SalesOrder) REFS Document.SalesOrder
	|						THEN CustomersSettlementsTurnovers.Document.Finish
	|					ELSE CustomersSettlementsTurnovers.Document.Date
	|				END
	|		WHEN CAST(CustomersSettlementsTurnovers.Recorder AS Document.RegistersCorrection) REFS Document.RegistersCorrection
	|			THEN CASE
	|					WHEN CAST(CustomersSettlementsTurnovers.Document AS Document.SalesOrder) REFS Document.SalesOrder
	|						THEN CustomersSettlementsTurnovers.Document.Finish
	|					ELSE CustomersSettlementsTurnovers.Document.Date
	|				END
	|		ELSE CustomersSettlementsTurnovers.Recorder.Date
	|	END,
	|	CASE
	|		WHEN CAST(CustomersSettlementsTurnovers.Recorder AS Document.OpeningBalanceEntry) REFS Document.OpeningBalanceEntry
	|			THEN CustomersSettlementsTurnovers.Document.Number
	|		WHEN CAST(CustomersSettlementsTurnovers.Recorder AS Document.RegistersCorrection) REFS Document.RegistersCorrection
	|			THEN CustomersSettlementsTurnovers.Document.Number
	|		ELSE CustomersSettlementsTurnovers.Recorder.Number
	|	END,
	|	CustomersSettlementsTurnovers.Contract,
	|	CustomersSettlementsTurnovers.Contract.SettlementsCurrency,
	|	CASE
	|		WHEN CAST(CustomersSettlementsTurnovers.Recorder AS Document.OpeningBalanceEntry) REFS Document.OpeningBalanceEntry
	|			THEN CustomersSettlementsTurnovers.Document
	|		WHEN CAST(CustomersSettlementsTurnovers.Recorder AS Document.RegistersCorrection) REFS Document.RegistersCorrection
	|			THEN CustomersSettlementsTurnovers.Document
	|		ELSE CustomersSettlementsTurnovers.Recorder
	|	END,
	|	CustomersSettlementsTurnovers.Recorder,
	|	CustomersSettlementsTurnovers.Contract.ContractDate
	|
	|UNION ALL
	|
	|SELECT
	|	CASE
	|		WHEN CAST(VendorsSettlementsTurnovers.Recorder AS Document.OpeningBalanceEntry) REFS Document.OpeningBalanceEntry
	|			THEN VendorsSettlementsTurnovers.Document.Date
	|		WHEN CAST(VendorsSettlementsTurnovers.Recorder AS Document.RegistersCorrection) REFS Document.RegistersCorrection
	|			THEN VendorsSettlementsTurnovers.Document.Date
	|		ELSE VendorsSettlementsTurnovers.Recorder.Date
	|	END,
	|	CASE
	|		WHEN CAST(VendorsSettlementsTurnovers.Recorder AS Document.OpeningBalanceEntry) REFS Document.OpeningBalanceEntry
	|			THEN VendorsSettlementsTurnovers.Document.Number
	|		WHEN CAST(VendorsSettlementsTurnovers.Recorder AS Document.RegistersCorrection) REFS Document.RegistersCorrection
	|			THEN VendorsSettlementsTurnovers.Document.Number
	|		ELSE VendorsSettlementsTurnovers.Recorder.Number
	|	END,
	|	VendorsSettlementsTurnovers.Contract,
	|	VendorsSettlementsTurnovers.Contract.ContractDate,
	|	VendorsSettlementsTurnovers.Contract.SettlementsCurrency,
	|	CASE
	|		WHEN CAST(VendorsSettlementsTurnovers.Recorder AS Document.OpeningBalanceEntry) REFS Document.OpeningBalanceEntry
	|			THEN VendorsSettlementsTurnovers.Document
	|		WHEN CAST(VendorsSettlementsTurnovers.Recorder AS Document.RegistersCorrection) REFS Document.RegistersCorrection
	|			THEN VendorsSettlementsTurnovers.Document
	|		ELSE VendorsSettlementsTurnovers.Recorder
	|	END,
	|	VendorsSettlementsTurnovers.Recorder,
	|	SUM(-VendorsSettlementsTurnovers.AmountCurTurnover)
	|FROM
	|	AccumulationRegister.AccountsPayable.Turnovers(
	|			,
	|			,
	|			Recorder,
	|			Company = &Company
	|				AND Contract IN (&ContractsArray)) AS VendorsSettlementsTurnovers
	|WHERE
	|	Not ISNULL(CAST(VendorsSettlementsTurnovers.Recorder AS Document.MonthEndClosing) REFS Document.MonthEndClosing, FALSE)
	|	AND VendorsSettlementsTurnovers.Recorder.Date between &BeginOfPeriod AND &EndOfPeriod
	|	AND &SelectDocumentDataByVendors
	|
	|GROUP BY
	|	CASE
	|		WHEN CAST(VendorsSettlementsTurnovers.Recorder AS Document.OpeningBalanceEntry) REFS Document.OpeningBalanceEntry
	|			THEN VendorsSettlementsTurnovers.Document.Date
	|		WHEN CAST(VendorsSettlementsTurnovers.Recorder AS Document.RegistersCorrection) REFS Document.RegistersCorrection
	|			THEN VendorsSettlementsTurnovers.Document.Date
	|		ELSE VendorsSettlementsTurnovers.Recorder.Date
	|	END,
	|	CASE
	|		WHEN CAST(VendorsSettlementsTurnovers.Recorder AS Document.OpeningBalanceEntry) REFS Document.OpeningBalanceEntry
	|			THEN VendorsSettlementsTurnovers.Document.Number
	|		WHEN CAST(VendorsSettlementsTurnovers.Recorder AS Document.RegistersCorrection) REFS Document.RegistersCorrection
	|			THEN VendorsSettlementsTurnovers.Document.Number
	|		ELSE VendorsSettlementsTurnovers.Recorder.Number
	|	END,
	|	VendorsSettlementsTurnovers.Contract,
	|	VendorsSettlementsTurnovers.Contract.SettlementsCurrency,
	|	CASE
	|		WHEN CAST(VendorsSettlementsTurnovers.Recorder AS Document.OpeningBalanceEntry) REFS Document.OpeningBalanceEntry
	|			THEN VendorsSettlementsTurnovers.Document
	|		WHEN CAST(VendorsSettlementsTurnovers.Recorder AS Document.RegistersCorrection) REFS Document.RegistersCorrection
	|			THEN VendorsSettlementsTurnovers.Document
	|		ELSE VendorsSettlementsTurnovers.Recorder
	|	END,
	|	VendorsSettlementsTurnovers.Recorder,
	|	VendorsSettlementsTurnovers.Contract.ContractDate
	|
	|ORDER BY
	|	ContractDate,
	|	Contract,
	|	Period";
	
	CompanyDataQuery.SetParameter("BeginOfPeriod",	DocumentData.BeginOfPeriod);
	CompanyDataQuery.SetParameter("EndOfPeriod",	EndOfDay(DocumentData.EndOfPeriod));
	CompanyDataQuery.SetParameter("Company",		DocumentData.Company);
	CompanyDataQuery.SetParameter("ContractsArray",	DocumentData.CounterpartyContracts.UnloadColumn("Contract"));
	
	If Not DocumentData.SortByContracts Then
		
		Rows_SortByContracts = 
		"	ContractDate,
		|	Contract,
		|	Period";
		
		Rows_SortByDates = 
		"	Period,
		|	Contract,
		|	ContractDate";
		
		CompanyDataQuery.Text = StrReplace(CompanyDataQuery.Text, Rows_SortByContracts, Rows_SortByDates); 
		
	EndIf;
	
	If ValueIsFilled(DocumentData.Ref) Then
		
		CompanyDataQuery.Text = StrReplace(CompanyDataQuery.Text, "&SelectDocumentDataByCustomers", "AccountsReceivable.Registrar.Ref = &Ref");
		CompanyDataQuery.Text = StrReplace(CompanyDataQuery.Text, "&SelectDocumentDataByVendors", "AccountsPayable.Registrar.Ref = &Ref");
		CompanyDataQuery.SetParameter("Ref", DocumentData.Ref);
		
	Else
		
		CompanyDataQuery.Text = StrReplace(CompanyDataQuery.Text, "&SelectDocumentDataByCustomers", "True");
		CompanyDataQuery.Text = StrReplace(CompanyDataQuery.Text, "&SelectDocumentDataByVendors", "True");
		
	EndIf;
	
	Return CompanyDataQuery.Execute();
	
EndFunction

#EndRegion

#Region PrintInterface

// Bypasses parameters collection and puts dashes for unfilled records
//
Procedure ReplaceEmptyParametersWithUnderscores(TemplateParameters)
	
	Underline = "__________________";
	For Each Parameter In TemplateParameters Do
		
		If Parameter.Key = "PeriodPresentation" 
			OR Parameter.Key = "CompanyPresentation"
			OR Parameter.Key = "PresentationOfCounterparty" Then
			
			Continue;
			
		ElsIf Not ValueIsFilled(Parameter.Value) Then
			
			TemplateParameters[Parameter.Key] = Underline;
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Returns filled printing form "Reconciliation statement  (without difference)"
//
// Parameters:
//    DocumentPrint  - DocumentRef    - Document that
//    should be printed PrintingObjects	  - ValueList	  - Printing objects list
//
// Return value: Tabular document
//
Function GeneratePrintFormCertificateWithoutDifferences(DocumentPrint, PrintObjects, OutputFacsimile = False)
	Var Errors;
	
	SetPrivilegedMode(True);
	
	SpreadsheetDocument = New SpreadsheetDocument;
	
	QueryResult = PrintingDocumentsData(DocumentPrint);
	DocumentsSelection = QueryResult.Select();
	
	FirstDocument = True;
	While DocumentsSelection.Next() Do
		
		FirstLineNumber = SpreadsheetDocument.TableHeight + 1;
		
		SpreadsheetDocument.PrintParametersName = "PRINTING_PARAMETERS_ReconciliationStatementCertificateReconciled";
		Template = PrintManagement.GetTemplate("Document.ReconciliationStatement.PF_MXL_ReconciliationStatementActChecked");
		
		If Not FirstDocument Then
			SpreadsheetDocument.PutHorizontalPageBreak();
		EndIf;
		FirstDocument = False;
		
		Header = DocumentsSelection;
		CounterpartyContracts = DocumentsSelection.CounterpartyContracts.Select();
		
		CompanyData = DocumentsSelection.CompanyData.Unload();
		
		// Title (the same for both layouts)
		TemplateArea = Template.GetArea("Title");
		TemplateParameters = New Structure;
		
		DrawingUpDatePresentation = NStr("en = 'Document is generated on %1'");
		DrawingUpDatePresentation = StringFunctionsClientServer.SubstituteParametersInString(DrawingUpDatePresentation, Format(Header.Date, "DLF=DD"));
		TemplateParameters.Insert("DrawingUpDatePresentation", DrawingUpDatePresentation);
		
		InfoAboutCompany = DriveServer.InfoAboutLegalEntityIndividual(Header.Company, Header.Date);
		TemplateParameters.Insert("CompanyPresentation", "1. " + DriveServer.CompaniesDescriptionFull(InfoAboutCompany, "FullDescr, TIN, LegalAddress, PhoneNumbers, Fax"));
		TemplateParameters.Insert("FullDescrCompany", DriveServer.CompaniesDescriptionFull(InfoAboutCompany, "FullDescr"));
		
		InfoAboutCounterparty = DriveServer.InfoAboutLegalEntityIndividual(Header.Counterparty,  Header.Date);
		TemplateParameters.Insert("PresentationOfCounterparty", "2. " + DriveServer.CompaniesDescriptionFull(InfoAboutCounterparty, "FullDescr, TIN, LegalAddress, PhoneNumbers, Fax"));
		TemplateParameters.Insert("FullDescrCounterparty", DriveServer.CompaniesDescriptionFull(InfoAboutCounterparty, "FullDescr"));
		
		TemplateParameters.Insert("CompanyRepresentativeDescriptionFull", Header.Responsible);
		TemplateParameters.Insert("CompanyRepresentativePosition", Lower(Header.CompanyRepresentativePosition));
		
		TemplateParameters.Insert("CounterpartyRepresentativeDescriptionFull", Header.CounterpartyRepresentative);
		TemplateParameters.Insert("CounterpartyRepresentativePosition", Lower(Header.CounterpartyRepresentativePosition));
		
		If ValueIsFilled(Header.BeginOfPeriod) Then
			
			PeriodPresentation = NStr("en = 'from %1 to %2'");
			PeriodPresentation = StringFunctionsClientServer.SubstituteParametersInString(PeriodPresentation, Format(Header.BeginOfPeriod, "DLF=DD"), Format(Header.EndOfPeriod, "DLF=DD"));
			
		Else
			
			PeriodPresentation = NStr("en = 'as of %1'");
			PeriodPresentation = StringFunctionsClientServer.SubstituteParametersInString(PeriodPresentation, Format(Header.EndOfPeriod, "DLF=DD"));
			
		EndIf;
		TemplateParameters.Insert("PeriodPresentation", PeriodPresentation);
		
		ReplaceEmptyParametersWithUnderscores(TemplateParameters);
		TemplateArea.Parameters.Fill(TemplateParameters);
		SpreadsheetDocument.Put(TemplateArea);
		
		// TableHeader
		TemplateArea = Template.GetArea("TableHeader");
		TemplateParameters.Clear();
		
		TemplateParameters.Insert("CompanyShortName", Header.Company);
		TemplateParameters.Insert("CounterpartyShortName", Header.Counterparty);
		
		TemplateArea.Parameters.Fill(TemplateParameters);
		SpreadsheetDocument.Put(TemplateArea);
		
		// RowBalancePeriodStart (the same for both layouts)
		TemplateArea = Template.GetArea("RowBalanceBeginOfPeriod");
		TemplateParameters.Clear();
		
		If Header.BalanceBeginPeriod > 0 Then
			
			TemplateParameters.Insert("CompanyDebtBeginOfPeriod", Header.BalanceBeginPeriod);
			
		Else
			
			TemplateParameters.Insert("CounterpartyDebtBeginOfPeriod", - Header.BalanceBeginPeriod);
			
		EndIf;
		
		TemplateArea.Parameters.Fill(TemplateParameters);
		SpreadsheetDocument.Put(TemplateArea);
		
		// SettlementsTableRow
		TemplateArea = Template.GetArea("SettlementsTableRow");
		For Each TableRow In CompanyData Do
			
			TemplateParameters.Clear();
			
			TemplateArea.Parameters.Fill(TableRow);
			SpreadsheetDocument.Put(TemplateArea);
			
		EndDo; 
		
		// RowTurnoversForPeriod
		TemplateArea = Template.GetArea("RowTurnoversForPeriod");
		
		TemplateParameters.Clear();
		TemplateParameters.Insert("CompanyDebtAmount", CompanyData.Total("CompanyDebtAmount"));
		TemplateParameters.Insert("ClientDebtAmount", CompanyData.Total("ClientDebtAmount"));
		
		TemplateArea.Parameters.Fill(TemplateParameters);
		SpreadsheetDocument.Put(TemplateArea);
		
		// RowBalanceEndOfPeriod
		TemplateArea = Template.GetArea("RowBalanceEndOfPeriod");
		TemplateParameters.Clear();
		
		BalanceAtTheEnd = Header.BalanceBeginPeriod + CompanyData.Total("CompanyDebtAmount") - CompanyData.Total("ClientDebtAmount");
		TemplateParameters.Insert("DebtCompaniesEndOfPeriod", Max(BalanceAtTheEnd, 0));
		TemplateParameters.Insert("CounterpartyDebtEndOfPeriod", Max(-BalanceAtTheEnd, 0));
		
		TemplateArea.Parameters.Fill(TemplateParameters);
		SpreadsheetDocument.Put(TemplateArea);
		
		// FooterNoDebt or FooterDebtExists 
		TemplateParameters.Clear();
		TemplateParameters.Insert("EndOfPeriodReconciliation", Format(Header.EndOfPeriod, "DLF=DD"));
		If BalanceAtTheEnd = 0 Then
			
			TemplateArea = Template.GetArea("FooterNoDebt");
			
		Else
			
			TemplateArea = Template.GetArea("FooterDebtExist");
			
			TemplateParameters.Insert("FullDescrCompany", DriveServer.CompaniesDescriptionFull(InfoAboutCompany, "FullDescr"));
			
			If BalanceAtTheEnd > 0 Then
				
				DebtorPresentation = DriveServer.CompaniesDescriptionFull(InfoAboutCompany, "FullDescr");
				
			Else
				
				DebtorPresentation = DriveServer.CompaniesDescriptionFull(InfoAboutCounterparty, "FullDescr");
				
			EndIf;
			
			TemplateParameters.Insert("Debitor", DebtorPresentation);
			
			AmountByModule = Max(BalanceAtTheEnd, -BalanceAtTheEnd);
			TemplateParameters.Insert("Amount", Format(AmountByModule, "ND=15; NFD=2; NG=3,0"));
			TemplateParameters.Insert("DocumentCurrency", Header.DocumentCurrency);
			TemplateParameters.Insert("AmountInWords", WorkWithExchangeRates.GenerateAmountInWords(AmountByModule, Header.DocumentCurrency));
			
		EndIf;
		
		TemplateArea.Parameters.Fill(TemplateParameters);
		SpreadsheetDocument.Put(TemplateArea);
		
		// Signatures
		OutputFieldsUnderOriginalSignature = Not OutputFacsimile; // output signature fields if facsimile is not filled in or prints normal layout
		If OutputFacsimile Then
			
			If Template.Areas.Find("InvoiceFooterWithFaxPrint") <> Undefined Then
				
				If ValueIsFilled(Header.Company.FileFacsimilePrinting) Then
					
					TemplateArea = Template.GetArea("InvoiceFooterWithFaxPrint");
					
					PictureData = AttachedFiles.GetFileBinaryData(Header.Company.FileFacsimilePrinting);
					If ValueIsFilled(PictureData) Then
						
						TemplateArea.Drawings.FacsimilePrint.Picture = New Picture(PictureData);
						
					EndIf;
					
					SpreadsheetDocument.Put(TemplateArea);
					
				Else
					
					MessageText = NStr(
						"en = 'Facsimile for company is not set. Facsimile is set in the company card, the ""Printing setting"" section.'");
					CommonUseClientServer.AddUserError(Errors, , MessageText, Undefined);
					OutputFieldsUnderOriginalSignature = True;
					
				EndIf;
				
			Else
				
				MessageText = NStr(
					"en = 'You are possibly using a custom template. Default procedures of account printing might work incorrectly.'");
				CommonUseClientServer.AddUserError(Errors, , MessageText, Undefined);
				OutputFieldsUnderOriginalSignature = True;
				
			EndIf;
			
		EndIf;
		
		If OutputFieldsUnderOriginalSignature Then
			
			TemplateArea = Template.GetArea("Signatures");
			TemplateParameters.Clear();
			
			TemplateParameters.Insert("CompanyPresentation", 			DriveServer.CompaniesDescriptionFull(InfoAboutCompany, "FullDescr, TIN, LegalAddress"));
			TemplateParameters.Insert("PresentationOfCounterparty", 	DriveServer.CompaniesDescriptionFull(InfoAboutCounterparty, "FullDescr, TIN, LegalAddress"));
			TemplateParameters.Insert("HeadDescriptionFull", 			Header.Responsible);
			TemplateParameters.Insert("HeadPost", 						Header.CompanyRepresentativePosition);
			TemplateParameters.Insert("CounterpartyHeadNameAndSurname", Header.CounterpartyRepresentative);
			TemplateParameters.Insert("CounterpartyHeadPost", 			Header.CounterpartyRepresentativePosition);
			
			TemplateArea.Parameters.Fill(TemplateParameters);
			SpreadsheetDocument.Put(TemplateArea);
			
		EndIf;
		
		PrintManagement.SetDocumentPrintArea(SpreadsheetDocument, FirstLineNumber, PrintObjects, Header.DocumentRef);
		
	EndDo;
	
	SpreadsheetDocument.FitToPage = True; 
	SpreadsheetDocument.PageOrientation = PageOrientation.Portrait;
	SetPrivilegedMode(False);
	
	CommonUseClientServer.ShowErrorsToUser(Errors);
	Return SpreadsheetDocument;
	
EndFunction

// Returns filled printing form "Reconciliation statement (with counterparty data)"
//
// Parameters:
//    DocumentPrint  - DocumentRef	  - Document that
//    should be printed PrintingObjects	  - ValueList	  - Printing objects list
//
// Return value: Tabular document
//
Function GeneratePrintFormCertificateWithCounterpartyData(DocumentPrint, PrintObjects, OutputFacsimile = False)
	Var Errors;
	
	SetPrivilegedMode(True);
	
	SpreadsheetDocument = New SpreadsheetDocument;
	
	QueryResult = PrintingDocumentsData(DocumentPrint);
	DocumentsSelection = QueryResult.Select();
	
	FirstDocument = True;
	While DocumentsSelection.Next() Do
		
		FirstLineNumber = SpreadsheetDocument.TableHeight + 1;
		
		SpreadsheetDocument.PrintParametersName = "PRINTING_PARAMETERS_ReconciliationStatementCertificate";
		Template = PrintManagement.GetTemplate("Document.ReconciliationStatement.PF_MXL_ReconciliationStatementAct");
		
		If Not FirstDocument Then
			SpreadsheetDocument.PutHorizontalPageBreak();
		EndIf;
		FirstDocument = False;
		
		Header = DocumentsSelection;
		CounterpartyContracts = DocumentsSelection.CounterpartyContracts.Select();
		
		CompanyData = DocumentsSelection.CompanyData.Unload();
		CounterpartyData = DocumentsSelection.CounterpartyData.Unload();
		
		// Title (the same for both layouts)
		TemplateArea = Template.GetArea("Title");
		TemplateParameters = New Structure;
		
		DrawingUpDatePresentation = NStr("en = 'Document is generated on %1'");
		DrawingUpDatePresentation = StringFunctionsClientServer.SubstituteParametersInString(DrawingUpDatePresentation, Format(Header.Date, "DLF=DD"));
		TemplateParameters.Insert("DrawingUpDatePresentation", DrawingUpDatePresentation);
		
		InfoAboutCompany = DriveServer.InfoAboutLegalEntityIndividual(Header.Company, Header.Date);
		TemplateParameters.Insert("CompanyPresentation", "1. " + DriveServer.CompaniesDescriptionFull(InfoAboutCompany, "FullDescr, TIN, LegalAddress, PhoneNumbers, Fax"));
		TemplateParameters.Insert("FullDescrCompany", DriveServer.CompaniesDescriptionFull(InfoAboutCompany, "FullDescr"));
		
		InfoAboutCounterparty = DriveServer.InfoAboutLegalEntityIndividual(Header.Counterparty,  Header.Date);
		TemplateParameters.Insert("PresentationOfCounterparty", "2. " + DriveServer.CompaniesDescriptionFull(InfoAboutCounterparty, "FullDescr, TIN, LegalAddress, PhoneNumbers, Fax"));
		TemplateParameters.Insert("FullDescrCounterparty", DriveServer.CompaniesDescriptionFull(InfoAboutCounterparty, "FullDescr"));
		
		TemplateParameters.Insert("CompanyRepresentativeDescriptionFull", Header.Responsible);
		TemplateParameters.Insert("CompanyRepresentativePosition", Lower(Header.CompanyRepresentativePosition));
		
		TemplateParameters.Insert("CounterpartyRepresentativeDescriptionFull", Header.CounterpartyRepresentative);
		TemplateParameters.Insert("CounterpartyRepresentativePosition", Lower(Header.CounterpartyRepresentativePosition));
		
		If ValueIsFilled(Header.BeginOfPeriod) Then
			
			PeriodPresentation = NStr("en = 'from %1 to %2'");
			PeriodPresentation = StringFunctionsClientServer.SubstituteParametersInString(PeriodPresentation, Format(Header.BeginOfPeriod, "DLF=DD"), Format(Header.EndOfPeriod, "DLF=DD"));
			
		Else
			
			PeriodPresentation = NStr("en = 'as of %1'");
			PeriodPresentation = StringFunctionsClientServer.SubstituteParametersInString(PeriodPresentation, Format(Header.EndOfPeriod, "DLF=DD"));
			
		EndIf;
		TemplateParameters.Insert("PeriodPresentation", PeriodPresentation);
		
		ReplaceEmptyParametersWithUnderscores(TemplateParameters);
		TemplateArea.Parameters.Fill(TemplateParameters);
		SpreadsheetDocument.Put(TemplateArea);
		
		// TableHeader (the same for both layouts)
		TemplateArea = Template.GetArea("TableHeader");
		TemplateParameters.Clear();
		
		TemplateParameters.Insert("CompanyShortName", Header.Company);
		TemplateParameters.Insert("CounterpartyShortName", Header.Counterparty);
		
		TemplateArea.Parameters.Fill(TemplateParameters);
		SpreadsheetDocument.Put(TemplateArea);
		
		// RowBalancePeriodStart (the same for both layouts)
		TemplateArea = Template.GetArea("RowBalanceBeginOfPeriod");
		TemplateParameters.Clear();
		
		// Assume that at the beginning of the period the balance is agreed
		If Header.BalanceBeginPeriod > 0 Then
			
			TemplateParameters.Insert("CompanyDebtBeginOfPeriod", Header.BalanceBeginPeriod);
			
		Else
			
			TemplateParameters.Insert("CounterpartyDebtBeginOfPeriod", - Header.BalanceBeginPeriod);
			
		EndIf;
		
		TemplateArea.Parameters.Fill(TemplateParameters);
		SpreadsheetDocument.Put(TemplateArea);
		
		// Contract, SettlementsTableRow
		LayoutAreaContract = Template.GetArea("Contract");
		LayoutAreaDetails = Template.GetArea("SettlementsTableRow");
		
		Contract = Catalogs.CounterpartyContracts.EmptyRef();
		CompanyMaxRowIndex = CompanyData.Count() - 1;
		CounterpartyMaxRowIndex = CounterpartyData.Count() - 1;
		MaxIndex = Max(CompanyMaxRowIndex, CounterpartyMaxRowIndex);
		For RowCounter = 0 To MaxIndex Do
			
			TemplateParameters.Clear();
			
			If RowCounter <= CompanyMaxRowIndex Then
				
				CompanyDataRow = CompanyData[RowCounter];
				TemplateParameters.Insert("Contract", 					CompanyDataRow.Contract);
				TemplateParameters.Insert("DocumentDate", 				CompanyDataRow.DocumentDate);
				TemplateParameters.Insert("CompanyDocumentDescription", CompanyDataRow.CompanyDocumentDescription);
				TemplateParameters.Insert("CompanyDebtAmount", 			CompanyDataRow.CompanyDebtAmount);
				TemplateParameters.Insert("ClientDebtAmount", 			CompanyDataRow.ClientDebtAmount);
				
			Else
				
				CompanyDataRow = Undefined;
				TemplateParameters.Insert("DocumentDate", 				Undefined);
				TemplateParameters.Insert("CompanyDocumentDescription", Undefined);
				TemplateParameters.Insert("CompanyDebtAmount", 			Undefined);
				TemplateParameters.Insert("ClientDebtAmount", 			Undefined);
			
			EndIf;
			
			If RowCounter <= CounterpartyMaxRowIndex Then
				
				CounterpartyDataRow = CounterpartyData[RowCounter];
				TemplateParameters.Insert("Contract", 							CounterpartyDataRow.Contract);
				TemplateParameters.Insert("CounterpartyDate", 					CounterpartyDataRow.IncomingDocumentDate);
				TemplateParameters.Insert("CounterpartyDocumentDescription", 	CounterpartyDataRow.CounterpartyDocumentDescription);
				TemplateParameters.Insert("CounterpartyCompanyDebtAmount", 		CounterpartyDataRow.CompanyDebtAmount);
				TemplateParameters.Insert("CounterpartyClientDebtAmount", 		CounterpartyDataRow.ClientDebtAmount);
				
			Else
				
				CounterpartyDataRow = Undefined;
				TemplateParameters.Insert("CounterpartyDate", 					Undefined);
				TemplateParameters.Insert("CounterpartyDocumentDescription", 	Undefined);
				TemplateParameters.Insert("CounterpartyCompanyDebtAmount", 		Undefined);
				TemplateParameters.Insert("CounterpartyClientDebtAmount", 		Undefined);
				
			EndIf;
			
			If Header.SortByContracts Then
				
				DataRow = ?(CompanyDataRow <> Undefined, CompanyDataRow, CounterpartyDataRow);
				
				If DataRow.Contract <> Contract Then
					
					Contract = DataRow.Contract;
					TemplateParameters.Insert("PresentationTreaty", NStr("en = 'Under contract:'") + " " + Contract);
					LayoutAreaContract.Parameters.Fill(TemplateParameters);
					SpreadsheetDocument.Put(LayoutAreaContract);
					
				EndIf;
				
			EndIf;
			
			LayoutAreaDetails.Parameters.Fill(TemplateParameters);
			SpreadsheetDocument.Put(LayoutAreaDetails);
			
		EndDo;
		
		// RowTurnoversForPeriod
		TemplateArea = Template.GetArea("RowTurnoversForPeriod");
		TemplateParameters.Clear();
		
		TemplateParameters.Insert("CompanyDebtAmount", 				CompanyData.Total("CompanyDebtAmount"));
		TemplateParameters.Insert("ClientDebtAmount", 				CompanyData.Total("ClientDebtAmount"));
		TemplateParameters.Insert("CounterpartyCompanyDebtAmount", 	CounterpartyData.Total("CompanyDebtAmount"));
		TemplateParameters.Insert("CounterpartyClientDebtAmount", 	CounterpartyData.Total("ClientDebtAmount"));
		
		TemplateArea.Parameters.Fill(TemplateParameters);
		SpreadsheetDocument.Put(TemplateArea);
		
		// RowBalanceEndOfPeriod
		TemplateArea = Template.GetArea("RowBalanceEndOfPeriod");
		TemplateParameters.Clear();
		
		BalanceAtTheEnd = Header.BalanceBeginPeriod + CompanyData.Total("CompanyDebtAmount") - CompanyData.Total("ClientDebtAmount");
		TemplateParameters.Insert("DebtCompaniesEndOfPeriod", Max(BalanceAtTheEnd, 0));
		TemplateParameters.Insert("CounterpartyDebtEndOfPeriod", Max(-BalanceAtTheEnd, 0));
		
		BalanceAtTheEndC = -Header.BalanceBeginPeriod + CounterpartyData.Total("CompanyDebtAmount") - CounterpartyData.Total("ClientDebtAmount");
		TemplateParameters.Insert("CompanyDebtBasedOnCounterpartyDataEndOfPeriod", Max(BalanceAtTheEndC, 0));
		TemplateParameters.Insert("CounterpartyDebtBasedOnCounterpartyDataEndOfPeriod", Max(-BalanceAtTheEndC, 0));
		
		TemplateArea.Parameters.Fill(TemplateParameters);
		SpreadsheetDocument.Put(TemplateArea);
		
		// Footer
		TemplateArea = Template.GetArea("Footer");
		TemplateParameters.Clear();
		
		TemplateParameters.Insert("EndOfPeriodReconciliation", 	Format(Header.EndOfPeriod, "DLF=DD"));
		TemplateParameters.Insert("FullDescrCompany", 			DriveServer.CompaniesDescriptionFull(InfoAboutCompany, "FullDescr"));
		TemplateParameters.Insert("FullDescrCounterparty", 		DriveServer.CompaniesDescriptionFull(InfoAboutCounterparty, "FullDescr"));
		TemplateParameters.Insert("DocumentCurrency", 			Header.DocumentCurrency);
		
		If BalanceAtTheEnd < 0 Then
			
			DebtorPresentation = DriveServer.CompaniesDescriptionFull(InfoAboutCompany, "FullDescr");
			
		Else
			
			DebtorPresentation = DriveServer.CompaniesDescriptionFull(InfoAboutCounterparty, "FullDescr");
			
		EndIf;
		TemplateParameters.Insert("DebitorByCompanyData", DebtorPresentation);
		
		AmountByModule = Max(BalanceAtTheEnd, -BalanceAtTheEnd);
		TemplateParameters.Insert("AmountCompanyData", Format(AmountByModule, "ND=15; NFD=2; NG=3,0"));
		TemplateParameters.Insert("CompanyDataInWriting", WorkWithExchangeRates.GenerateAmountInWords(AmountByModule, Header.DocumentCurrency));
		
		If BalanceAtTheEndC > 0 Then
			
			DebtorPresentation = DriveServer.CompaniesDescriptionFull(InfoAboutCompany, "FullDescr");
			
		Else
			
			DebtorPresentation = DriveServer.CompaniesDescriptionFull(InfoAboutCounterparty, "FullDescr");
			
		EndIf;
		TemplateParameters.Insert("DebitorByCounterpartyData", DebtorPresentation);
		
		AmountByModule = Max(BalanceAtTheEndC, -BalanceAtTheEndC);
		TemplateParameters.Insert("AmountCounterpartyData", Format(AmountByModule, "ND=15; NFD=2; NG=3,0"));
		TemplateParameters.Insert("CounterpartyDataInWriting", WorkWithExchangeRates.GenerateAmountInWords(AmountByModule, Header.DocumentCurrency));
		
		TemplateArea.Parameters.Fill(TemplateParameters);
		SpreadsheetDocument.Put(TemplateArea);
		
		// Differences
		Discrepancy = Max(BalanceAtTheEnd + BalanceAtTheEndC, -1 * (BalanceAtTheEnd + BalanceAtTheEndC));
		If Discrepancy <> 0 Then
			
			TemplateArea = Template.GetArea("Differences");
			TemplateParameters.Clear();
			
			ReconciliationTotal = NStr(
				"en = 'Difference of information about accounts state is found as a result of verification to the extent '")
			+ Format(Discrepancy, "ND=21; NFD=2") + " " + String(Header.DocumentCurrency)
			+ " (" + WorkWithExchangeRates.GenerateAmountInWords(Discrepancy, Header.DocumentCurrency, False) + ")";
						
			TemplateParameters.Insert("ReconciliationTotal", ReconciliationTotal);
			
			TemplateArea.Parameters.Fill(TemplateParameters);
			SpreadsheetDocument.Put(TemplateArea);
			
		EndIf; 
		
		// Document description
		If Not IsBlankString(Header.DocumentDescription) Then
			
			TemplateArea = Template.GetArea("DocumentDescription");
			TemplateParameters.Clear();
			
			TemplateParameters.Insert("DocumentDescription", Header.DocumentDescription);
			
			TemplateArea.Parameters.Fill(TemplateParameters);
			SpreadsheetDocument.Put(TemplateArea);
			
		EndIf;
		
		// Signatures
		OutputFieldsUnderOriginalSignature = Not OutputFacsimile; // output signature fields if facsimile is not filled in or prints normal layout
		If OutputFacsimile Then
			
			If Template.Areas.Find("InvoiceFooterWithFaxPrint") <> Undefined Then
				
				If ValueIsFilled(Header.Company.FileFacsimilePrinting) Then
					
					TemplateArea = Template.GetArea("InvoiceFooterWithFaxPrint");
					
					PictureData = AttachedFiles.GetFileBinaryData(Header.Company.FileFacsimilePrinting);
					If ValueIsFilled(PictureData) Then
						
						TemplateArea.Drawings.FacsimilePrint.Picture = New Picture(PictureData);
						
					EndIf;
					
					SpreadsheetDocument.Put(TemplateArea);
					
				Else
					
					MessageText = NStr("en = 'Facsimile for company is not set. Facsimile is set in the company card, the ""Printing setting"" section.'");
					CommonUseClientServer.AddUserError(Errors, , MessageText, Undefined);
					OutputFieldsUnderOriginalSignature = True;
					
				EndIf;
				
			Else
				
				MessageText = NStr("en = 'You are possibly using a custom template. Default procedures of account printing might work incorrectly.'");
				CommonUseClientServer.AddUserError(Errors, , MessageText, Undefined);
				OutputFieldsUnderOriginalSignature = True;
				
			EndIf;
			
		EndIf;
		
		If OutputFieldsUnderOriginalSignature Then
		
			TemplateArea = Template.GetArea("Signatures");
			TemplateParameters.Clear();
			
			TemplateParameters.Insert("CompanyPresentation", DriveServer.CompaniesDescriptionFull(InfoAboutCompany, "FullDescr, TIN, LegalAddress"));
			TemplateParameters.Insert("PresentationOfCounterparty", DriveServer.CompaniesDescriptionFull(InfoAboutCounterparty, "FullDescr, TIN, LegalAddress"));
			TemplateParameters.Insert("HeadDescriptionFull", Header.Responsible);
			TemplateParameters.Insert("HeadPost", Header.CompanyRepresentativePosition);
			TemplateParameters.Insert("CounterpartyHeadNameAndSurname", Header.CounterpartyRepresentative);
			TemplateParameters.Insert("CounterpartyHeadPost", Header.CounterpartyRepresentativePosition);
			
			TemplateArea.Parameters.Fill(TemplateParameters);
			SpreadsheetDocument.Put(TemplateArea);
			
		EndIf;
		
		PrintManagement.SetDocumentPrintArea(SpreadsheetDocument, FirstLineNumber, PrintObjects, Header.DocumentRef);
		
	EndDo;
	
	SpreadsheetDocument.FitToPage = True;
	SpreadsheetDocument.PageOrientation = PageOrientation.Landscape;
	SetPrivilegedMode(False);
	
	Return SpreadsheetDocument;
	
EndFunction

// Generate printed forms of objects
//
// PARAMETERS.
// Incoming:
//   DocumentPrint  - DocumentRef		- Document that
//   should be printed PrintingParameters - Structure 			- Structure of additional printing parameters
//
// Outgoing:
//   PrintFormsCollection - Values table - Generated
//   tabular documents PrintingObjects		   - ValueList	  - InputParameters
//   printing objects list       - Structure        - Parameters of generated table documents
//
Procedure Print(DocumentPrint, PrintParameters, PrintFormsCollection, PrintObjects, OutputParameters) Export
	
	If PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "CertificateWithoutDifferences") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection, "CertificateWithoutDifferences", "Reconciliation statement (Without Differences)", GeneratePrintFormCertificateWithoutDifferences(DocumentPrint, PrintObjects));
		
	EndIf;
	
	If PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "CertificateWithoutDifferencesWithFacsimile") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection, "CertificateWithoutDifferencesWithFacsimile", "Reconciliation statement (without facsimile differences)", GeneratePrintFormCertificateWithoutDifferences(DocumentPrint, PrintObjects, True));
		
	EndIf;
	
	If PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "CertificateWithCounterpartyData") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection, "CertificateWithCounterpartyData", "Reconciliation statement (with counterparty data)", GeneratePrintFormCertificateWithCounterpartyData(DocumentPrint, PrintObjects));
		
	EndIf;
	
	If PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "CertificateWithCounterpartyDataWithFacsimile") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection, "CertificateWithCounterpartyDataWithFacsimile", "Reconciliation statement (with counterparty and with facsimile)", GeneratePrintFormCertificateWithCounterpartyData(DocumentPrint, PrintObjects, True));
		
	EndIf;
	
	If DocumentPrint.Count() > 0 Then
		
		ObjectArrayPrint = New Array;
		ObjectArrayPrint.Add(DocumentPrint[0]);
		
		// parameters of sending printing forms by email
		DriveServer.FillSendingParameters(OutputParameters.SendingParameters, ObjectArrayPrint, PrintFormsCollection);
		
	EndIf;
	
EndProcedure

// Fills in the list of printing commands.
// 
// Parameters:
//   PrintCommands - ValueTable - see fields' content in the PrintManagement.CreatePrintCommandsCollection function.
//
Procedure AddPrintCommands(PrintCommands) Export
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID = "CertificateWithoutDifferences,CertificateWithCounterpartyData";
	PrintCommand.Presentation = NStr("en = 'Customized document set'");
	PrintCommand.FormsList = "DocumentForm,ListForm";
	PrintCommand.CheckPostingBeforePrint = False;
	PrintCommand.Order = 1;
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID = "CertificateWithoutDifferences";
	PrintCommand.Presentation = NStr("en = 'Accounts reconciliation statement (without variances)'");
	PrintCommand.FormsList = "DocumentForm,ListForm,DocumentsListForm";
	PrintCommand.CheckPostingBeforePrint = False;
	PrintCommand.Order = 4;
	
	//
	// Definition Commands printing NStr("en = 'Accounts reconciliation statement (without variances with
	// facsimile)'; ru = 'Акт сверки взаиморасчетов (без расхождений с факсимиле)'");
	//
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID = "CertificateWithCounterpartyData";
	PrintCommand.Presentation = NStr("en = 'Accounts reconciliation statement (with counterparty data)'");
	PrintCommand.FormsList = "DocumentForm,ListForm";
	PrintCommand.CheckPostingBeforePrint = False;
	PrintCommand.Order = 10;
	
	//
	// Definition Commands printing NStr("en = 'Accounts reconciliation statement (with counterparty data and
	// facsimile)'; ru = 'Акт сверки взаиморасчетов (с данными контрагента и с факсимиле)'");
	//
	
EndProcedure

#EndRegion

#EndIf