#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions

// Procedure of filling the document on the basis.
//
// Parameters:
// FillingData - Structure - Data on filling the document.
//	
Procedure FillBySalesOrder(FillingData)
	
	Query = New Query();
	
	Query.SetParameter("Ref", FillingData);
	Query.SetParameter("Date", CurrentDate());
	
	// Fill document header data.
	Query.Text =
	"SELECT
	|	VALUE(Enum.OperationTypesCashReceipt.FromCustomer) AS OperationKind,
	|	&Ref AS BasisDocument,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.DocumentCurrency AS DocumentCurrency,
	|	DocumentTable.PettyCash AS PettyCash,
	|	DocumentTable.BankAccount AS BankAccount,
	|	DocumentTable.CashAssetsType AS CashAssetsType,
	|	DocumentTable.Counterparty AS Counterparty,
	|	DocumentTable.Contract AS Contract,
	|	DocumentTable.DocumentAmount AS DocumentAmount
	|FROM
	|	Document.SalesOrder AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref";
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		
		Selection = QueryResult.Select();
		Selection.Next();
		FillPropertyValues(ThisObject, Selection);
		
	EndIf;
	
EndProcedure

// Procedure of filling the document on the basis.
//
// Parameters:
// FillingData - Structure - Data on filling the document.
//	
Procedure FillByAccountSalesFromConsignee(FillingData)
	
	Query = New Query();
	
	Query.SetParameter("Ref", FillingData);
	Query.SetParameter("Date", CurrentDate());
	
	// Fill document header data.
	Query.Text =
	"SELECT
	|	VALUE(Enum.OperationTypesCashReceipt.FromCustomer) AS OperationKind,
	|	&Ref AS BasisDocument,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.DocumentCurrency AS DocumentCurrency,
	|	DocumentTable.Counterparty AS Counterparty,
	|	DocumentTable.Contract AS Contract,
	|	DocumentTable.DocumentAmount AS DocumentAmount
	|FROM
	|	Document.AccountSalesFromConsignee AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref";
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		
		Selection = QueryResult.Select();
		Selection.Next();
		FillPropertyValues(ThisObject, Selection);
		
	EndIf;
	
EndProcedure

// Procedure of filling the document on the basis.
//
// Parameters:
// FillingData - Structure - Data on filling the document.
//	
Procedure FillBySalesInvoice(FillingData)
	
	Query = New Query();
	
	Query.SetParameter("Ref", FillingData);
	Query.SetParameter("Date", CurrentDate());
	
	// Fill document header data.
	Query.Text =
	"SELECT
	|	VALUE(Enum.OperationTypesCashReceipt.FromCustomer) AS OperationKind,
	|	&Ref AS BasisDocument,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.DocumentCurrency AS DocumentCurrency,
	|	DocumentTable.Counterparty AS Counterparty,
	|	DocumentTable.Contract AS Contract,
	|	DocumentTable.DocumentAmount AS DocumentAmount
	|FROM
	|	Document.SalesInvoice AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref";
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		
		Selection = QueryResult.Select();
		Selection.Next();
		FillPropertyValues(ThisObject, Selection);
		
	EndIf;
	
EndProcedure

// Procedure of filling the document on the basis.
//
// Parameters:
// FillingData - Structure - Data on filling the document.
//	
Procedure FillBySubcontractorReportIssued(FillingData)
	
	Query = New Query();
	
	Query.SetParameter("Ref", FillingData);
	Query.SetParameter("Date", CurrentDate());
	
	// Fill document header data.
	Query.Text =
	"SELECT
	|	VALUE(Enum.OperationTypesCashReceipt.FromCustomer) AS OperationKind,
	|	&Ref AS BasisDocument,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.DocumentCurrency AS DocumentCurrency,
	|	DocumentTable.Counterparty AS Counterparty,
	|	DocumentTable.Contract AS Contract,
	|	DocumentTable.DocumentAmount AS DocumentAmount
	|FROM
	|	Document.SubcontractorReportIssued AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref";
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		
		Selection = QueryResult.Select();
		Selection.Next();
		FillPropertyValues(ThisObject, Selection);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region EventHandlers

// Procedure - handler of the FillingProcessor event.
//
Procedure Filling(FillingData, StandardProcessing)
	
	If TypeOf(FillingData) = Type("DocumentRef.SalesOrder") Then
		FillBySalesOrder(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.AccountSalesFromConsignee") Then
		FillByAccountSalesFromConsignee(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.SalesInvoice") Then
		FillBySalesInvoice(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.SubcontractorReportIssued") Then
		FillBySubcontractorReportIssued(FillingData);
	EndIf;
	
EndProcedure

// Procedure - event handler "Posting".
//
Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Initialization of document data
	Documents.CashInflowForecast.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Preparation of record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Registering in accounting sections
	DriveServer.ReflectPaymentCalendar(AdditionalProperties, RegisterRecords, Cancel);
	
	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
EndProcedure

#EndRegion

#EndIf
