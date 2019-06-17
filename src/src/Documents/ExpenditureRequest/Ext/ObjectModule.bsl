#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions

// Procedure of filling the document on the basis.
//
// Parameters:
// FillingData - Structure - Data on filling the document.
//	
Procedure FillByPurchaseOrder(FillingData)
	
	Query = New Query();
	
	Query.SetParameter("Ref", FillingData);
	Query.SetParameter("Date", CurrentDate());
	
	// Fill document header data.
	Query.Text =
	"SELECT
	|	VALUE(Enum.OperationTypesCashReceipt.FromCustomer) AS OperationKind,
	|	&Ref AS BasisDocument,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.Number AS IncomingDocumentNumber,
	|	DocumentTable.Date AS IncomingDocumentDate,
	|	DocumentTable.DocumentCurrency AS DocumentCurrency,
	|	DocumentTable.PettyCash AS PettyCash,
	|	DocumentTable.BankAccount AS BankAccount,
	|	DocumentTable.CashAssetsType AS CashAssetsType,
	|	DocumentTable.Counterparty AS Counterparty,
	|	DocumentTable.Contract AS Contract,
	|	DocumentTable.DocumentAmount AS DocumentAmount
	|FROM
	|	Document.PurchaseOrder AS DocumentTable
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
Procedure FillByPurchaseInvoice(FillingData)
	
	Query = New Query();
	
	Query.SetParameter("Ref", FillingData);
	Query.SetParameter("Date", CurrentDate());
	
	// Fill document header data.
	Query.Text =
	"SELECT
	|	VALUE(Enum.OperationTypesCashReceipt.FromCustomer) AS OperationKind,
	|	&Ref AS BasisDocument,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.Number AS IncomingDocumentNumber,
	|	DocumentTable.Date AS IncomingDocumentDate,
	|	DocumentTable.DocumentCurrency AS DocumentCurrency,
	|	DocumentTable.Counterparty AS Counterparty,
	|	DocumentTable.Contract AS Contract,
	|	DocumentTable.DocumentAmount AS DocumentAmount
	|FROM
	|	Document.SupplierInvoice AS DocumentTable
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
//  FillingData - Structure - Data on filling the document.
//	
Procedure FillByExpenseReport(FillingData)
	
	Query = New Query();
	
	Query.SetParameter("Ref", FillingData);
	Query.SetParameter("Date", CurrentDate());
	
	// Fill document header data.
	Query.Text =
	"SELECT
	|	VALUE(Enum.OperationTypesCashReceipt.FromCustomer) AS OperationKind,
	|	&Ref AS BasisDocument,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.Number AS IncomingDocumentNumber,
	|	DocumentTable.Date AS IncomingDocumentDate,
	|	DocumentTable.DocumentCurrency AS DocumentCurrency,
	|	DocumentTable.DocumentAmount AS DocumentAmount
	|FROM
	|	Document.ExpenseReport AS DocumentTable
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
//  FillingData - Structure - Data on filling the document.
//	
Procedure FillByAccountSalesToConsignor(FillingData)
	
	Query = New Query();
	
	Query.SetParameter("Ref", FillingData);
	Query.SetParameter("Date", CurrentDate());
	
	// Fill document header data.
	Query.Text =
	"SELECT
	|	VALUE(Enum.OperationTypesCashReceipt.FromCustomer) AS OperationKind,
	|	&Ref AS BasisDocument,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.Number AS IncomingDocumentNumber,
	|	DocumentTable.Date AS IncomingDocumentDate,
	|	DocumentTable.DocumentCurrency AS DocumentCurrency,
	|	DocumentTable.Counterparty AS Counterparty,
	|	DocumentTable.Contract AS Contract,
	|	DocumentTable.DocumentAmount AS DocumentAmount
	|FROM
	|	Document.AccountSalesToConsignor AS DocumentTable
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
//  FillingData - Structure - Data on filling the document.
//	
Procedure FillByPayrollSheet(FillingData)
	
	Query = New Query();
	
	Query.SetParameter("Ref", FillingData);
	Query.SetParameter("Date", CurrentDate());
	
	// Fill document header data.
	Query.Text =
	"SELECT
	|	VALUE(Enum.OperationTypesCashReceipt.FromCustomer) AS OperationKind,
	|	&Ref AS BasisDocument,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.Number AS IncomingDocumentNumber,
	|	DocumentTable.Date AS IncomingDocumentDate,
	|	DocumentTable.DocumentCurrency AS DocumentCurrency,
	|	DocumentTable.DocumentAmount AS DocumentAmount
	|FROM
	|	Document.PayrollSheet AS DocumentTable
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
//  FillingData - Structure - Data on filling the document.
//	
Procedure FillByAdditionalExpenses(FillingData)
	
	Query = New Query();
	
	Query.SetParameter("Ref", FillingData);
	Query.SetParameter("Date", CurrentDate());
	
	// Fill document header data.
	Query.Text =
	"SELECT
	|	VALUE(Enum.OperationTypesCashReceipt.FromCustomer) AS OperationKind,
	|	&Ref AS BasisDocument,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.Number AS IncomingDocumentNumber,
	|	DocumentTable.Date AS IncomingDocumentDate,
	|	DocumentTable.DocumentCurrency AS DocumentCurrency,
	|	DocumentTable.Counterparty AS Counterparty,
	|	DocumentTable.Contract AS Contract,
	|	DocumentTable.DocumentAmount AS DocumentAmount
	|FROM
	|	Document.AdditionalExpenses AS DocumentTable
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
//  FillingData - Structure - Data on filling the document.
//	
Procedure FillBySubcontractorReport(FillingData)
	
	Query = New Query();
	
	Query.SetParameter("Ref", FillingData);
	Query.SetParameter("Date", CurrentDate());
	
	// Fill document header data.
	Query.Text =
	"SELECT
	|	VALUE(Enum.OperationTypesCashReceipt.FromCustomer) AS OperationKind,
	|	&Ref AS BasisDocument,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.Number AS IncomingDocumentNumber,
	|	DocumentTable.Date AS IncomingDocumentDate,
	|	DocumentTable.DocumentCurrency AS DocumentCurrency,
	|	DocumentTable.Counterparty AS Counterparty,
	|	DocumentTable.Contract AS Contract,
	|	DocumentTable.Amount AS DocumentAmount
	|FROM
	|	Document.SubcontractorReport AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref";
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		
		Selection = QueryResult.Select();
		Selection.Next();
		FillPropertyValues(ThisObject, Selection);
		
	EndIf;
	
EndProcedure

// Procedure for filling the document on the basis of InvoicesForPayment
//
// Parameters:
//  FillingData - Structure - Data on filling the document.
//	
Procedure FillByVendorQuote(FillingData)
	
	Query = New Query();
	
	Query.SetParameter("Ref", FillingData);
	Query.SetParameter("Date", CurrentDate());
	
	// Fill document header data.
	Query.Text =
	"SELECT
	|	VALUE(Enum.OperationTypesCashReceipt.FromCustomer) AS OperationKind,
	|	&Ref AS BasisDocument,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.Number AS IncomingDocumentNumber,
	|	DocumentTable.Date AS IncomingDocumentDate,
	|	DocumentTable.DocumentCurrency AS DocumentCurrency,
	|	DocumentTable.PettyCash AS PettyCash,
	|	DocumentTable.BankAccount AS BankAccount,
	|	DocumentTable.CashAssetsType AS CashAssetsType,
	|	DocumentTable.Counterparty AS Counterparty,
	|	DocumentTable.Contract AS Contract,
	|	DocumentTable.DocumentAmount AS DocumentAmount
	|FROM
	|	Document.SupplierQuote AS DocumentTable
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
Procedure Filling(FillingData, StandardProcessing) Export
	
	If TypeOf(FillingData) = Type("DocumentRef.PurchaseOrder") Then
		FillByPurchaseOrder(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.SupplierInvoice") Then
		FillByPurchaseInvoice(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.ExpenseReport") Then
		FillByExpenseReport(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.AccountSalesToConsignor") Then
		FillByAccountSalesToConsignor(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.PayrollSheet") Then
		FillByPayrollSheet(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.AdditionalExpenses") Then
		FillByAdditionalExpenses(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.SubcontractorReport") Then
		FillBySubcontractorReport(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.SupplierQuote") Then
		FillByVendorQuote(FillingData);
	EndIf;
	
EndProcedure

// Procedure - "FillCheckProcessing" event handler.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If PaymentConfirmationStatus = Enums.PaymentApprovalStatuses.Approved Then
		
		CheckedAttributes.Add("CashAssetsType");
		
		If CashAssetsType = Enums.CashAssetTypes.Noncash Then
			CheckedAttributes.Add("BankAccount");
		ElsIf CashAssetsType = Enums.CashAssetTypes.Cash Then
			CheckedAttributes.Add("PettyCash");
		EndIf;
		
	EndIf;
	
EndProcedure

// Procedure - event handler "Posting".
//
Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Initialization of document data
	Documents.ExpenditureRequest.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Preparation of record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Registering in accounting sections
	DriveServer.ReflectPaymentCalendar(AdditionalProperties, RegisterRecords, Cancel);
	
	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
EndProcedure

#EndRegion

#EndIf
