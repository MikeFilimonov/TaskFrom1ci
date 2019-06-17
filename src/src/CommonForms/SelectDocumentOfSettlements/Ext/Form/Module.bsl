
#Region GeneralPurposeProceduresAndFunctions

// Gets query for customer settlement document selection for "Payment receipt" and "Cash receipt" documents.
// 
&AtServerNoContext
Function GetQueryTextAccountDocumentsOfAccountsReceivableReceipt()
	
	QueryText =
	"SELECT
	|	UNDEFINED AS Ref,
	|	DATETIME(1, 1, 1) AS Date,
	|	""000000000000"" AS Number,
	|	VALUE(Catalog.Companies.EmptyRef) AS Company,
	|	&CounterpartyByDefault AS Counterparty,
	|	&ContractByDefault AS Contract,
	|	0 AS Amount,
	|	&Currency AS Currency,
	|	UNDEFINED AS Type,
	|	0 AS DocumentStatus
	|WHERE
	|	FALSE
	|";
	
	If AccessRight("Read", Metadata.Documents.ArApAdjustments) Then
		
		QueryText = QueryText + "UNION ALL";
		
		QueryText = QueryText +
		"
		|SELECT
		|	DocumentData.Ref,
		|	DocumentData.Date,
		|	DocumentData.Number,
		|	DocumentData.Company,
		|	DocumentData.Counterparty,
		|	&ContractByDefault,
		|	DocumentData.SettlementsAmount,
		|	VALUE(Catalog.Currencies.EmptyRef),
		|	VALUETYPE(DocumentData.Ref),
		|	CASE
		|		WHEN DocumentData.Posted
		|			THEN 1
		|		WHEN DocumentData.DeletionMark
		|			THEN 2
		|		ELSE 0
		|	END
		|FROM
		|	Document.ArApAdjustments AS DocumentData
		|WHERE
		|	DocumentData.Posted
		|";
		
	EndIf;
	
	If AccessRight("Read", Metadata.Documents.AccountSalesFromConsignee) Then
		
		QueryText = QueryText + "UNION ALL";
		
		QueryText = QueryText +
		"
		|SELECT
		|	DocumentData.Ref,
		|	DocumentData.Date,
		|	DocumentData.Number,
		|	DocumentData.Company,
		|	DocumentData.Counterparty,
		|	DocumentData.Contract,
		|	DocumentData.DocumentAmount,
		|	DocumentData.DocumentCurrency,
		|	VALUETYPE(DocumentData.Ref),
		|	CASE
		|		WHEN DocumentData.Posted
		|			THEN 1
		|		WHEN DocumentData.DeletionMark
		|			THEN 2
		|		ELSE 0
		|	END
		|FROM
		|	Document.AccountSalesFromConsignee AS DocumentData
		|WHERE
		|	DocumentData.Posted
		|";
		
	EndIf;
	
	If AccessRight("Read", Metadata.Documents.SubcontractorReportIssued) Then
		
		QueryText = QueryText + "UNION ALL";
		
		QueryText = QueryText +
		"
		|SELECT
		|	DocumentData.Ref,
		|	DocumentData.Date,
		|	DocumentData.Number,
		|	DocumentData.Company,
		|	DocumentData.Counterparty,
		|	DocumentData.Contract,
		|	DocumentData.DocumentAmount,
		|	DocumentData.DocumentCurrency,
		|	VALUETYPE(DocumentData.Ref),
		|	CASE
		|		WHEN DocumentData.Posted
		|			THEN 1
		|		WHEN DocumentData.DeletionMark
		|			THEN 2
		|		ELSE 0
		|	END
		|FROM
		|	Document.SubcontractorReportIssued AS DocumentData
		|WHERE
		|	DocumentData.Posted
		|";
		
	EndIf;
	
	If AccessRight("Read", Metadata.Documents.FixedAssetSale) Then
		
		QueryText = QueryText + "UNION ALL";
		
		QueryText = QueryText +
		"
		|SELECT
		|	DocumentData.Ref,
		|	DocumentData.Date,
		|	DocumentData.Number,
		|	DocumentData.Company,
		|	DocumentData.Counterparty,
		|	DocumentData.Contract,
		|	DocumentData.DocumentAmount,
		|	DocumentData.DocumentCurrency,
		|	VALUETYPE(DocumentData.Ref),
		|	CASE
		|		WHEN DocumentData.Posted
		|			THEN 1
		|		WHEN DocumentData.DeletionMark
		|			THEN 2
		|		ELSE 0
		|	END
		|FROM
		|	Document.FixedAssetSale AS DocumentData
		|WHERE
		|	DocumentData.Posted
		|";
		
	EndIf;
	
	If AccessRight("Read", Metadata.Documents.SalesInvoice) Then
		
		QueryText = QueryText + "UNION ALL";
		
		QueryText = QueryText +
		"
		|SELECT
		|	DocumentData.Ref,
		|	DocumentData.Date,
		|	DocumentData.Number,
		|	DocumentData.Company,
		|	DocumentData.Counterparty,
		|	DocumentData.Contract,
		|	DocumentData.DocumentAmount,
		|	DocumentData.DocumentCurrency,
		|	VALUETYPE(DocumentData.Ref),
		|	CASE
		|		WHEN DocumentData.Posted
		|			THEN 1
		|		WHEN DocumentData.DeletionMark
		|			THEN 2
		|		ELSE 0
		|	END
		|FROM
		|	Document.SalesInvoice AS DocumentData
		|WHERE
		|	DocumentData.Posted
		|";
		
	EndIf;
	
	If Left(QueryText, 10) = "UNION" Then
		QueryText = Mid(QueryText, 14);
	EndIf;
	
	Return QueryText;
	
EndFunction

// Gets query for supplier settlement document selection for "Payment receipt" and "Cash Reciept" documents.
// 
&AtServerNoContext
Function GetQueryTextDocumentsOfAccountsPayableReceipt()
	
	QueryText =
	"SELECT
	|	UNDEFINED AS Ref,
	|	DATETIME(1, 1, 1) AS Date,
	|	""000000000000"" AS Number,
	|	VALUE(Catalog.Companies.EmptyRef) AS Company,
	|	&CounterpartyByDefault AS Counterparty,
	|	&ContractByDefault AS Contract,
	|	0 AS Amount,
	|	&Currency AS Currency,
	|	UNDEFINED AS Type,
	|	0 AS DocumentStatus
	|WHERE
	|	FALSE
	|";
	
	If AccessRight("Read", Metadata.Documents.ExpenseReport) Then
		
		QueryText = QueryText + "UNION ALL";
		
		QueryText = QueryText +
		"
		|SELECT
		|	DocumentData.Ref,
		|	DocumentData.Date,
		|	DocumentData.Number,
		|	DocumentData.Company,
		|	&CounterpartyByDefault,
		|	&ContractByDefault,
		|	DocumentData.DocumentAmount,
		|	DocumentData.DocumentCurrency,
		|	VALUETYPE(DocumentData.Ref),
		|	CASE
		|		WHEN DocumentData.Posted
		|			THEN 1
		|		WHEN DocumentData.DeletionMark
		|			THEN 2
		|		ELSE 0
		|	END
		|FROM
		|	Document.ExpenseReport AS DocumentData
		|WHERE
		|	DocumentData.Posted
		|";
		
	EndIf;
	
	If AccessRight("Read", Metadata.Documents.AdditionalExpenses) Then
		
		QueryText = QueryText + "UNION ALL";
		
		QueryText = QueryText +
		"
		|SELECT
		|	DocumentData.Ref,
		|	DocumentData.Date,
		|	DocumentData.Number,
		|	DocumentData.Company,
		|	DocumentData.Counterparty,
		|	DocumentData.Contract,
		|	DocumentData.DocumentAmount,
		|	DocumentData.DocumentCurrency,
		|	VALUETYPE(DocumentData.Ref),
		|	CASE
		|		WHEN DocumentData.Posted
		|			THEN 1
		|		WHEN DocumentData.DeletionMark
		|			THEN 2
		|		ELSE 0
		|	END
		|FROM
		|	Document.AdditionalExpenses AS DocumentData
		|WHERE
		|	DocumentData.Posted
		|";
		
	EndIf;
	
	If AccessRight("Read", Metadata.Documents.ArApAdjustments) Then
		
		QueryText = QueryText + "UNION ALL";
		
		QueryText = QueryText +
		"
		|SELECT
		|	DocumentData.Ref,
		|	DocumentData.Date,
		|	DocumentData.Number,
		|	DocumentData.Company,
		|	DocumentData.Counterparty,
		|	&ContractByDefault,
		|	DocumentData.SettlementsAmount,
		|	VALUE(Catalog.Currencies.EmptyRef),
		|	VALUETYPE(DocumentData.Ref),
		|	CASE
		|		WHEN DocumentData.Posted
		|			THEN 1
		|		WHEN DocumentData.DeletionMark
		|			THEN 2
		|		ELSE 0
		|	END
		|FROM
		|	Document.ArApAdjustments AS DocumentData
		|WHERE
		|	DocumentData.Posted
		|";
		
	EndIf;
	
	If AccessRight("Read", Metadata.Documents.AccountSalesToConsignor) Then
		
		QueryText = QueryText + "UNION ALL";
		
		QueryText = QueryText +
		"
		|SELECT
		|	DocumentData.Ref,
		|	DocumentData.Date,
		|	DocumentData.Number,
		|	DocumentData.Company,
		|	DocumentData.Counterparty,
		|	DocumentData.Contract,
		|	DocumentData.DocumentAmount,
		|	DocumentData.DocumentCurrency,
		|	VALUETYPE(DocumentData.Ref),
		|	CASE WHEN DocumentData.Posted THEN
		|		1
		|	WHEN DocumentData.DeletionMark THEN
		|		2
		|	ELSE
		|		0
		|	END
		|FROM
		|	Document.AccountSalesToConsignor AS DocumentData
		|WHERE
		|	DocumentData.Posted
		|";
		
	EndIf;
	
	If AccessRight("Read", Metadata.Documents.SubcontractorReport) Then
		
		QueryText = QueryText + "UNION ALL";
		
		QueryText = QueryText +
		"
		|SELECT
		|	DocumentData.Ref,
		|	DocumentData.Date,
		|	DocumentData.Number,
		|	DocumentData.Company,
		|	DocumentData.Counterparty,
		|	DocumentData.Contract,
		|	DocumentData.Amount,
		|	DocumentData.DocumentCurrency,
		|	VALUETYPE(DocumentData.Ref),
		|	CASE WHEN DocumentData.Posted THEN
		|		1
		|	WHEN DocumentData.DeletionMark THEN
		|		2
		|	ELSE
		|		0
		|	END
		|FROM
		|	Document.SubcontractorReport AS DocumentData
		|WHERE
		|	DocumentData.Posted
		|";
		
	EndIf;
	
	If AccessRight("Read", Metadata.Documents.SupplierInvoice) Then
		
		QueryText = QueryText + "UNION ALL";
		
		QueryText = QueryText +
		"
		|SELECT
		|	DocumentData.Ref,
		|	DocumentData.Date,
		|	DocumentData.Number,
		|	DocumentData.Company,
		|	DocumentData.Counterparty,
		|	DocumentData.Contract,
		|	DocumentData.DocumentAmount,
		|	DocumentData.DocumentCurrency,
		|	VALUETYPE(DocumentData.Ref),
		|	CASE
		|		WHEN DocumentData.Posted
		|			THEN 1
		|		WHEN DocumentData.DeletionMark
		|			THEN 2
		|		ELSE 0
		|	END
		|FROM
		|	Document.SupplierInvoice AS DocumentData
		|WHERE
		|	DocumentData.Posted
		|";
		
	EndIf;
	
	If AccessRight("Read", Metadata.Documents.CashVoucher) Then
		
		QueryText = QueryText + "UNION ALL";
		
		QueryText = QueryText +
		"
		|SELECT
		|	DocumentData.Ref,
		|	DocumentData.Date,
		|	DocumentData.Number,
		|	DocumentData.Company,
		|	DocumentData.Counterparty,
		|	&ContractByDefault,
		|	DocumentData.DocumentAmount,
		|	DocumentData.CashCurrency,
		|	VALUETYPE(DocumentData.Ref),
		|	CASE
		|		WHEN DocumentData.Posted
		|			THEN 1
		|		WHEN DocumentData.DeletionMark
		|			THEN 2
		|		ELSE 0
		|	END
		|FROM
		|	Document.CashVoucher AS DocumentData
		|WHERE
		|	DocumentData.Posted
		|";
		
	EndIf;
	
	If AccessRight("Read", Metadata.Documents.PaymentExpense) Then
		
		QueryText = QueryText + "UNION ALL";
		
		QueryText = QueryText +
		"
		|SELECT
		|	DocumentData.Ref,
		|	DocumentData.Date,
		|	DocumentData.Number,
		|	DocumentData.Company,
		|	DocumentData.Counterparty,
		|	&ContractByDefault,
		|	DocumentData.DocumentAmount,
		|	DocumentData.CashCurrency,
		|	VALUETYPE(DocumentData.Ref),
		|	CASE
		|		WHEN DocumentData.Posted
		|			THEN 1
		|		WHEN DocumentData.DeletionMark
		|			THEN 2
		|		ELSE 0
		|	END
		|FROM
		|	Document.PaymentExpense AS DocumentData
		|WHERE
		|	DocumentData.Posted
		|";
		
	EndIf;
	
	If Left(QueryText, 10) = "UNION" Then
		QueryText = Mid(QueryText, 14);
	EndIf;
	
	Return QueryText;
	
EndFunction

// Gets a query for selecting accounts receivable documents for "Payment expense" and "Cash payment" documents.
// 
&AtServerNoContext
Function GetQueryTextAccountDocumentsOfAccountsReceivableWriteOff()
	
	QueryText =
	"SELECT
	|	UNDEFINED AS Ref,
	|	DATETIME(1, 1, 1) AS Date,
	|	""000000000000"" AS Number,
	|	VALUE(Catalog.Companies.EmptyRef) AS Company,
	|	&CounterpartyByDefault AS Counterparty,
	|	&ContractByDefault AS Contract,
	|	0 AS Amount,
	|	&Currency AS Currency,
	|	UNDEFINED AS Type,
	|	0 AS DocumentStatus
	|WHERE
	|	FALSE
	|";
	
	If AccessRight("Read", Metadata.Documents.CashReceipt) Then
		
		QueryText = QueryText + "UNION ALL";
		
		QueryText = QueryText +
		"
		|SELECT
		|	DocumentData.Ref,
		|	DocumentData.Date,
		|	DocumentData.Number,
		|	DocumentData.Company,
		|	DocumentData.Counterparty,
		|	&ContractByDefault,
		|	DocumentData.DocumentAmount,
		|	DocumentData.CashCurrency,
		|	VALUETYPE(DocumentData.Ref),
		|	CASE
		|		WHEN DocumentData.Posted
		|			THEN 1
		|		WHEN DocumentData.DeletionMark
		|			THEN 2
		|		ELSE 0
		|	END
		|FROM
		|	Document.CashReceipt AS DocumentData
		|WHERE
		|	DocumentData.Posted
		|";
		
	EndIf;
	
	If AccessRight("Read", Metadata.Documents.PaymentReceipt) Then
		
		QueryText = QueryText + "UNION ALL";
		
		QueryText = QueryText +
		"
		|SELECT
		|	DocumentData.Ref,
		|	DocumentData.Date,
		|	DocumentData.Number,
		|	DocumentData.Company,
		|	DocumentData.Counterparty,
		|	&ContractByDefault,
		|	DocumentData.DocumentAmount,
		|	DocumentData.CashCurrency,
		|	VALUETYPE(DocumentData.Ref),
		|	CASE
		|		WHEN DocumentData.Posted
		|			THEN 1
		|		WHEN DocumentData.DeletionMark
		|			THEN 2
		|		ELSE 0
		|	END
		|FROM
		|	Document.PaymentReceipt AS DocumentData
		|WHERE
		|	DocumentData.Posted
		|";
		
	EndIf;
	
	If AccessRight("Read", Metadata.Documents.ArApAdjustments) Then
		
		QueryText = QueryText + "UNION ALL";
		
		QueryText = QueryText +
		"
		|SELECT
		|	DocumentData.Ref,
		|	DocumentData.Date,
		|	DocumentData.Number,
		|	DocumentData.Company,
		|	DocumentData.Counterparty,
		|	&ContractByDefault,
		|	DocumentData.SettlementsAmount,
		|	VALUE(Catalog.Currencies.EmptyRef),
		|	VALUETYPE(DocumentData.Ref),
		|	CASE
		|		WHEN DocumentData.Posted
		|			THEN 1
		|		WHEN DocumentData.DeletionMark
		|			THEN 2
		|		ELSE 0
		|	END
		|FROM
		|	Document.ArApAdjustments AS DocumentData
		|WHERE
		|	DocumentData.Posted
		|";
		
	EndIf;
	
	If AccessRight("Read", Metadata.Documents.AccountSalesFromConsignee) Then
		
		QueryText = QueryText + "UNION ALL";
		
		QueryText = QueryText +
		"
		|SELECT
		|	DocumentData.Ref,
		|	DocumentData.Date,
		|	DocumentData.Number,
		|	DocumentData.Company,
		|	DocumentData.Counterparty,
		|	DocumentData.Contract,
		|	DocumentData.DocumentAmount,
		|	DocumentData.DocumentCurrency,
		|	VALUETYPE(DocumentData.Ref),
		|	CASE
		|		WHEN DocumentData.Posted
		|			THEN 1
		|		WHEN DocumentData.DeletionMark
		|			THEN 2
		|		ELSE 0
		|	END
		|FROM
		|	Document.AccountSalesFromConsignee AS DocumentData
		|WHERE
		|	DocumentData.Posted
		|";
		
	EndIf;
	
	If AccessRight("Read", Metadata.Documents.SubcontractorReportIssued) Then
		
		QueryText = QueryText + "UNION ALL";
		
		QueryText = QueryText +
		"
		|SELECT
		|	DocumentData.Ref,
		|	DocumentData.Date,
		|	DocumentData.Number,
		|	DocumentData.Company,
		|	DocumentData.Counterparty,
		|	DocumentData.Contract,
		|	DocumentData.DocumentAmount,
		|	DocumentData.DocumentCurrency,
		|	VALUETYPE(DocumentData.Ref),
		|	CASE
		|		WHEN DocumentData.Posted
		|			THEN 1
		|		WHEN DocumentData.DeletionMark
		|			THEN 2
		|		ELSE 0
		|	END
		|FROM
		|	Document.SubcontractorReportIssued AS DocumentData
		|WHERE
		|	DocumentData.Posted
		|";
		
	EndIf;
	
	If AccessRight("Read", Metadata.Documents.FixedAssetSale) Then
		
		QueryText = QueryText + "UNION ALL";
		
		QueryText = QueryText +
		"
		|SELECT
		|	DocumentData.Ref,
		|	DocumentData.Date,
		|	DocumentData.Number,
		|	DocumentData.Company,
		|	DocumentData.Counterparty,
		|	DocumentData.Contract,
		|	DocumentData.DocumentAmount,
		|	DocumentData.DocumentCurrency,
		|	VALUETYPE(DocumentData.Ref),
		|	CASE
		|		WHEN DocumentData.Posted
		|			THEN 1
		|		WHEN DocumentData.DeletionMark
		|			THEN 2
		|		ELSE 0
		|	END
		|FROM
		|	Document.FixedAssetSale AS DocumentData
		|WHERE
		|	DocumentData.Posted
		|";
		
	EndIf;
	
	If AccessRight("Read", Metadata.Documents.SalesInvoice) Then
		
		QueryText = QueryText + "UNION ALL";
		
		QueryText = QueryText +
		"
		|SELECT
		|	DocumentData.Ref,
		|	DocumentData.Date,
		|	DocumentData.Number,
		|	DocumentData.Company,
		|	DocumentData.Counterparty,
		|	DocumentData.Contract,
		|	DocumentData.DocumentAmount,
		|	DocumentData.DocumentCurrency,
		|	VALUETYPE(DocumentData.Ref),
		|	CASE
		|		WHEN DocumentData.Posted
		|			THEN 1
		|		WHEN DocumentData.DeletionMark
		|			THEN 2
		|		ELSE 0
		|	END
		|FROM
		|	Document.SalesInvoice AS DocumentData
		|WHERE
		|	DocumentData.Posted
		|";
		
	EndIf;
	
	If Left(QueryText, 10) = "UNION" Then
		QueryText = Mid(QueryText, 14);
	EndIf;
	
	Return QueryText;
	
EndFunction

// Gets a query for selecting accounts payable documents for "Payment expense" and "Cash payment" documents.
// 
&AtServerNoContext
Function GetQueryTextDocumentsOfAccountsPayableWriteOff()
	
	QueryText =
	"SELECT
	|	UNDEFINED AS Ref,
	|	DATETIME(1, 1, 1) AS Date,
	|	""000000000000"" AS Number,
	|	VALUE(Catalog.Companies.EmptyRef) AS Company,
	|	&CounterpartyByDefault AS Counterparty,
	|	&ContractByDefault AS Contract,
	|	0 AS Amount,
	|	&Currency AS Currency,
	|	UNDEFINED AS Type,
	|	0 AS DocumentStatus
	|WHERE
	|	FALSE
	|";
	
	If AccessRight("Read", Metadata.Documents.AdditionalExpenses) Then
		
		QueryText = QueryText + "UNION ALL";
		
		QueryText = QueryText +
		"
		|SELECT
		|	DocumentData.Ref,
		|	DocumentData.Date,
		|	DocumentData.Number,
		|	DocumentData.Company,
		|	DocumentData.Counterparty,
		|	DocumentData.Contract,
		|	DocumentData.DocumentAmount,
		|	DocumentData.DocumentCurrency,
		|	VALUETYPE(DocumentData.Ref),
		|	CASE
		|		WHEN DocumentData.Posted
		|			THEN 1
		|		WHEN DocumentData.DeletionMark
		|			THEN 2
		|		ELSE 0
		|	END
		|FROM
		|	Document.AdditionalExpenses AS DocumentData
		|WHERE
		|	DocumentData.Posted
		|";
		
	EndIf;
	
	If AccessRight("Read", Metadata.Documents.SupplierInvoice) Then
		
		QueryText = QueryText + "UNION ALL";
		
		QueryText = QueryText +
		"
		|SELECT
		|	DocumentData.Ref,
		|	DocumentData.Date,
		|	DocumentData.Number,
		|	DocumentData.Company,
		|	DocumentData.Counterparty,
		|	DocumentData.Contract,
		|	DocumentData.DocumentAmount,
		|	DocumentData.DocumentCurrency,
		|	VALUETYPE(DocumentData.Ref),
		|	CASE
		|		WHEN DocumentData.Posted
		|			THEN 1
		|		WHEN DocumentData.DeletionMark
		|			THEN 2
		|		ELSE 0
		|	END
		|FROM
		|	Document.SupplierInvoice AS DocumentData
		|WHERE
		|	DocumentData.Posted
		|";
		
	EndIf;
	
	If AccessRight("Read", Metadata.Documents.SalesInvoice) Then
		
		QueryText = QueryText + "UNION ALL";
		
		QueryText = QueryText +
		"
		|SELECT
		|	DocumentData.Ref,
		|	DocumentData.Date,
		|	DocumentData.Number,
		|	DocumentData.Company,
		|	DocumentData.Counterparty,
		|	DocumentData.Contract,
		|	DocumentData.DocumentAmount,
		|	DocumentData.DocumentCurrency,
		|	VALUETYPE(DocumentData.Ref),
		|	CASE
		|		WHEN DocumentData.Posted
		|			THEN 1
		|		WHEN DocumentData.DeletionMark
		|			THEN 2
		|		ELSE 0
		|	END
		|FROM
		|	Document.SalesInvoice AS DocumentData
		|WHERE
		|	DocumentData.Posted
		|";
		
	EndIf;
	
	If AccessRight("Read", Metadata.Documents.AccountSalesToConsignor) Then
		
		QueryText = QueryText + "UNION ALL";
		
		QueryText = QueryText +
		"
		|SELECT
		|	DocumentData.Ref,
		|	DocumentData.Date,
		|	DocumentData.Number,
		|	DocumentData.Company,
		|	DocumentData.Counterparty,
		|	DocumentData.Contract,
		|	DocumentData.DocumentAmount,
		|	DocumentData.DocumentCurrency,
		|	VALUETYPE(DocumentData.Ref),
		|	CASE WHEN DocumentData.Posted THEN
		|		1
		|	WHEN DocumentData.DeletionMark THEN
		|		2
		|	ELSE
		|		0
		|	END
		|FROM
		|	Document.AccountSalesToConsignor AS DocumentData
		|WHERE
		|	DocumentData.Posted
		|";
		
	EndIf;
	
	If AccessRight("Read", Metadata.Documents.SubcontractorReport) Then
		
		QueryText = QueryText + "UNION ALL";
		
		QueryText = QueryText +
		"
		|SELECT
		|	DocumentData.Ref,
		|	DocumentData.Date,
		|	DocumentData.Number,
		|	DocumentData.Company,
		|	DocumentData.Counterparty,
		|	DocumentData.Contract,
		|	DocumentData.Amount,
		|	DocumentData.DocumentCurrency,
		|	VALUETYPE(DocumentData.Ref),
		|	CASE WHEN DocumentData.Posted THEN
		|		1
		|	WHEN DocumentData.DeletionMark THEN
		|		2
		|	ELSE
		|		0
		|	END
		|FROM
		|	Document.SubcontractorReport AS DocumentData
		|WHERE
		|	DocumentData.Posted
		|";
		
	EndIf;
	
	If AccessRight("Read", Metadata.Documents.ArApAdjustments) Then
		
		QueryText = QueryText + "UNION ALL";
		
		QueryText = QueryText +
		"
		|SELECT
		|	DocumentData.Ref,
		|	DocumentData.Date,
		|	DocumentData.Number,
		|	DocumentData.Company,
		|	DocumentData.Counterparty,
		|	&ContractByDefault,
		|	DocumentData.SettlementsAmount,
		|	VALUE(Catalog.Currencies.EmptyRef),
		|	VALUETYPE(DocumentData.Ref),
		|	CASE
		|		WHEN DocumentData.Posted
		|			THEN 1
		|		WHEN DocumentData.DeletionMark
		|			THEN 2
		|		ELSE 0
		|	END
		|FROM
		|	Document.ArApAdjustments AS DocumentData
		|WHERE
		|	DocumentData.Posted
		|";
		
	EndIf;
	
	If Left(QueryText, 10) = "UNION" Then
		QueryText = Mid(QueryText, 14);
	EndIf;
	
	Return QueryText;
	
EndFunction

&AtServerNoContext
Function GetQueryTextDocumentForBankStatementProcessing()
	
	QueryText =
	"SELECT
	|	UNDEFINED AS Ref,
	|	DATETIME(1, 1, 1) AS Date,
	|	""000000000000"" AS Number,
	|	VALUE(Catalog.Companies.EmptyRef) AS Company,
	|	&CounterpartyByDefault AS Counterparty,
	|	&ContractByDefault AS Contract,
	|	0 AS Amount,
	|	&Currency AS Currency,
	|	UNDEFINED AS Type,
	|	0 AS DocumentStatus
	|WHERE
	|	FALSE
	|";
	
	If AccessRight("Read", Metadata.Documents.PaymentExpense) Then
		
		QueryText = QueryText + "UNION ALL";
		
		QueryText = QueryText +
		"
		|SELECT
		|	DocumentData.Ref,
		|	DocumentData.Date,
		|	DocumentData.Number,
		|	DocumentData.Company,
		|	DocumentData.Counterparty,
		|	&ContractByDefault,
		|	DocumentData.DocumentAmount,
		|	DocumentData.CashCurrency,
		|	VALUETYPE(DocumentData.Ref),
		|	CASE
		|		WHEN DocumentData.Posted
		|			THEN 1
		|		WHEN DocumentData.DeletionMark
		|			THEN 2
		|		ELSE 0
		|	END
		|FROM
		|	Document.PaymentExpense AS DocumentData
		|";
		
	EndIf;
	
	If AccessRight("Read", Metadata.Documents.PaymentReceipt) Then
		
		QueryText = QueryText + "UNION ALL";
		
		QueryText = QueryText +
		"
		|SELECT
		|	DocumentData.Ref,
		|	DocumentData.Date,
		|	DocumentData.Number,
		|	DocumentData.Company,
		|	DocumentData.Counterparty,
		|	&ContractByDefault,
		|	DocumentData.DocumentAmount,
		|	DocumentData.CashCurrency,
		|	VALUETYPE(DocumentData.Ref),
		|	CASE
		|		WHEN DocumentData.Posted
		|			THEN 1
		|		WHEN DocumentData.DeletionMark
		|			THEN 2
		|		ELSE 0
		|	END
		|FROM
		|	Document.PaymentReceipt AS DocumentData";
		
	EndIf;
	
	If Left(QueryText, 10) = "UNION" Then
		QueryText = Mid(QueryText, 14);
	EndIf;
	
	Return QueryText;
	
EndFunction

// Gets order from the settlement document header.
//
&AtServerNoContext
Function GetOrder(Document, ThisIsAccountsReceivable)
	
	If ThisIsAccountsReceivable Then
		
		If TypeOf(Document) = Type("DocumentRef.SubcontractorReportIssued") Then
			
			Order = Document.SalesOrder;
			
		ElsIf (TypeOf(Document) = Type("DocumentRef.ArApAdjustments")
			OR TypeOf(Document) = Type("DocumentRef.SupplierInvoice")
			OR TypeOf(Document) = Type("DocumentRef.SalesInvoice"))
			AND TypeOf(Document.Order) = Type("DocumentRef.SalesOrder") Then
			
			Order = Document.Order;
			
		Else
			
			Order = Documents.SalesOrder.EmptyRef();
			
		EndIf;
			
	Else
		
		If TypeOf(Document) = Type("DocumentRef.AdditionalExpenses") Then
			
			Order = Document.PurchaseOrder;
			
		ElsIf (TypeOf(Document) = Type("DocumentRef.ArApAdjustments")
			OR TypeOf(Document) = Type("DocumentRef.SupplierInvoice")
			OR TypeOf(Document) = Type("DocumentRef.SalesInvoice"))
			AND TypeOf(Document.Order) = Type("DocumentRef.PurchaseOrder") Then
			
			Order = Document.Order;
			
		Else
			
			Order = Documents.PurchaseOrder.EmptyRef();
			
		EndIf;
		
	EndIf;
	
	Return Order;
	
EndFunction

// Gets payment account associated with the settlement document.
//
&AtServerNoContext
Function GetQuote(Document, Order, ThisIsAccountsReceivable)

	If NOT ThisIsAccountsReceivable Then
		
		Quote = Documents.SupplierQuote.EmptyRef();
		If Not ValueIsFilled(Order) Then
			Return Quote;
		EndIf;
		
		Query = New Query;
		Query.Text = 
		"SELECT ALLOWED
		|	SupplierQuote.Ref AS Quote
		|FROM
		|	Document.SupplierQuote AS SupplierQuote
		|WHERE
		|	SupplierQuote.BasisDocument = &BasisDocument";
		
		Query.SetParameter("BasisDocument", Order);
		Selection = Query.Execute().Select();
		
		If Selection.Count() = 1
			AND Selection.Next() Then
			
			Quote = Selection.Quote;
			
		EndIf;
		
	EndIf;
	
	Return Quote;

EndFunction

// Gets advans payments to supplier.
//
&AtServerNoContext
Function GetQueryTextAdvancePaymentsReceived()
	
	QueryText =
	"SELECT
	|	UNDEFINED AS Ref,
	|	DATETIME(1, 1, 1) AS Date,
	|	""000000000000"" AS Number,
	|	VALUE(Catalog.Companies.EmptyRef) AS Company,
	|	&CounterpartyByDefault AS Counterparty,
	|	&ContractByDefault AS Contract,
	|	0 AS Amount,
	|	&Currency AS Currency,
	|	UNDEFINED AS Type,
	|	0 AS DocumentStatus
	|WHERE
	|	FALSE
	|";
	
	If AccessRight("Read", Metadata.Documents.CashVoucher) Then
		
		QueryText = QueryText + "UNION ALL";
		
		QueryText = QueryText +
		"
		|SELECT
		|	DocumentData.Ref,
		|	DocumentData.Date,
		|	DocumentData.Number,
		|	DocumentData.Company,
		|	DocumentData.Counterparty,
		|	&ContractByDefault,
		|	DocumentData.DocumentAmount,
		|	DocumentData.CashCurrency,
		|	VALUETYPE(DocumentData.Ref),
		|	CASE
		|		WHEN DocumentData.Posted
		|			THEN 1
		|		WHEN DocumentData.DeletionMark
		|			THEN 2
		|		ELSE 0
		|	END
		|FROM
		|	Document.CashVoucher AS DocumentData
		|		LEFT JOIN Document.TaxInvoiceReceived.BasisDocuments AS BasisDocuments
		|		ON DocumentData.Ref = BasisDocuments.BasisDocument
		|WHERE
		|	BasisDocuments.BasisDocument IS NULL
		|	AND DocumentData.OperationKind = VALUE(Enum.OperationTypesCashVoucher.Vendor)
		|	AND DocumentData.Posted
		|	AND DocumentData.CashCurrency = &Currency
		|";
		
	EndIf;
	
	If AccessRight("Read", Metadata.Documents.PaymentExpense) Then
		
		QueryText = QueryText + "UNION ALL";
		
		QueryText = QueryText +
		"
		|SELECT
		|	DocumentData.Ref,
		|	DocumentData.Date,
		|	DocumentData.Number,
		|	DocumentData.Company,
		|	DocumentData.Counterparty,
		|	&ContractByDefault,
		|	DocumentData.DocumentAmount,
		|	DocumentData.CashCurrency,
		|	VALUETYPE(DocumentData.Ref),
		|	CASE
		|		WHEN DocumentData.Posted
		|			THEN 1
		|		WHEN DocumentData.DeletionMark
		|			THEN 2
		|		ELSE 0
		|	END
		|FROM
		|	Document.PaymentExpense AS DocumentData
		|		LEFT JOIN Document.TaxInvoiceReceived.BasisDocuments AS BasisDocuments
		|		ON DocumentData.Ref = BasisDocuments.BasisDocument
		|WHERE
		|	BasisDocuments.BasisDocument IS NULL
		|	AND DocumentData.OperationKind = VALUE(Enum.OperationTypesPaymentExpense.Vendor)
		|	AND DocumentData.Posted
		|	AND DocumentData.CashCurrency = &Currency
		|";
		
	EndIf;
	
	If Left(QueryText, 10) = "UNION" Then
		QueryText = Mid(QueryText, 14);
	EndIf;
	
	Return QueryText;
	
EndFunction

// Gets text for the Tax invoice received.
//
&AtServerNoContext
Function GetQueryTextTaxInvoiceReceived()
	
	QueryText =
	"SELECT
	|	UNDEFINED AS Ref,
	|	DATETIME(1, 1, 1) AS Date,
	|	""000000000000"" AS Number,
	|	VALUE(Catalog.Companies.EmptyRef) AS Company,
	|	&CounterpartyByDefault AS Counterparty,
	|	&ContractByDefault AS Contract,
	|	0 AS Amount,
	|	&Currency AS Currency,
	|	UNDEFINED AS Type,
	|	0 AS DocumentStatus
	|WHERE
	|	FALSE
	|";
	
	If AccessRight("Read", Metadata.Documents.DebitNote) Then
		
		QueryText = QueryText + "UNION ALL";
		
		QueryText = QueryText +
		"
		|SELECT
		|	DocumentData.Ref,
		|	DocumentData.Date,
		|	DocumentData.Number,
		|	DocumentData.Company,
		|	DocumentData.Counterparty,
		|	&ContractByDefault,
		|	DocumentData.DocumentAmount,
		|	DocumentData.DocumentCurrency,
		|	VALUETYPE(DocumentData.Ref),
		|	CASE
		|		WHEN DocumentData.Posted
		|			THEN 1
		|		WHEN DocumentData.DeletionMark
		|			THEN 2
		|		ELSE 0
		|	END
		|FROM
		|	Document.DebitNote AS DocumentData
		|		LEFT JOIN Document.TaxInvoiceReceived.BasisDocuments AS BasisDocuments
		|		ON DocumentData.Ref = BasisDocuments.BasisDocument
		|WHERE
		|	BasisDocuments.BasisDocument IS NULL
		|	AND DocumentData.Posted
		|	AND DocumentData.DocumentCurrency = &Currency
		|";
		
	EndIf;
	
	If AccessRight("Read", Metadata.Documents.SupplierInvoice) Then
		
		QueryText = QueryText + "UNION ALL";
		
		QueryText = QueryText +
		"
		|SELECT
		|	DocumentData.Ref,
		|	DocumentData.Date,
		|	DocumentData.Number,
		|	DocumentData.Company,
		|	DocumentData.Counterparty,
		|	&ContractByDefault,
		|	DocumentData.DocumentAmount,
		|	DocumentData.DocumentCurrency,
		|	VALUETYPE(DocumentData.Ref),
		|	CASE
		|		WHEN DocumentData.Posted
		|			THEN 1
		|		WHEN DocumentData.DeletionMark
		|			THEN 2
		|		ELSE 0
		|	END
		|FROM
		|	Document.SupplierInvoice AS DocumentData
		|		LEFT JOIN Document.TaxInvoiceReceived.BasisDocuments AS BasisDocuments
		|		ON DocumentData.Ref = BasisDocuments.BasisDocument
		|WHERE
		|	BasisDocuments.BasisDocument IS NULL
		|	AND DocumentData.Posted
		|	AND DocumentData.DocumentCurrency = &Currency
		|";
		
	EndIf;
	
	If Left(QueryText, 10) = "UNION" Then
		QueryText = Mid(QueryText, 14);
	EndIf;
	
	Return QueryText;
	
EndFunction

// Gets advans payments from customer.
//
&AtServerNoContext
Function GetQueryTextAdvancePaymentsIssued()
	
	QueryText =
	"SELECT
	|	UNDEFINED AS Ref,
	|	DATETIME(1, 1, 1) AS Date,
	|	""000000000000"" AS Number,
	|	VALUE(Catalog.Companies.EmptyRef) AS Company,
	|	&CounterpartyByDefault AS Counterparty,
	|	&ContractByDefault AS Contract,
	|	0 AS Amount,
	|	&Currency AS Currency,
	|	UNDEFINED AS Type,
	|	0 AS DocumentStatus
	|WHERE
	|	FALSE
	|";
	
	If AccessRight("Read", Metadata.Documents.CashVoucher) Then
		
		QueryText = QueryText + "UNION ALL";
		
		QueryText = QueryText +
		"
		|SELECT
		|	DocumentData.Ref,
		|	DocumentData.Date,
		|	DocumentData.Number,
		|	DocumentData.Company,
		|	DocumentData.Counterparty,
		|	&ContractByDefault,
		|	DocumentData.DocumentAmount,
		|	DocumentData.CashCurrency,
		|	VALUETYPE(DocumentData.Ref),
		|	CASE
		|		WHEN DocumentData.Posted
		|			THEN 1
		|		WHEN DocumentData.DeletionMark
		|			THEN 2
		|		ELSE 0
		|	END
		|FROM
		|	Document.CashReceipt AS DocumentData
		|		LEFT JOIN Document.TaxInvoiceIssued.BasisDocuments AS BasisDocuments
		|		ON DocumentData.Ref = BasisDocuments.BasisDocument
		|WHERE
		|	BasisDocuments.BasisDocument IS NULL
		|	AND DocumentData.OperationKind = VALUE(Enum.OperationTypesCashReceipt.FromCustomer)
		|	AND DocumentData.Posted
		|	AND DocumentData.CashCurrency = &Currency
		|";
		
	EndIf;
	
	If AccessRight("Read", Metadata.Documents.PaymentExpense) Then
		
		QueryText = QueryText + "UNION ALL";
		
		QueryText = QueryText +
		"
		|SELECT
		|	DocumentData.Ref,
		|	DocumentData.Date,
		|	DocumentData.Number,
		|	DocumentData.Company,
		|	DocumentData.Counterparty,
		|	&ContractByDefault,
		|	DocumentData.DocumentAmount,
		|	DocumentData.CashCurrency,
		|	VALUETYPE(DocumentData.Ref),
		|	CASE
		|		WHEN DocumentData.Posted
		|			THEN 1
		|		WHEN DocumentData.DeletionMark
		|			THEN 2
		|		ELSE 0
		|	END
		|FROM
		|	Document.PaymentReceipt AS DocumentData
		|		LEFT JOIN Document.TaxInvoiceIssued.BasisDocuments AS BasisDocuments
		|		ON DocumentData.Ref = BasisDocuments.BasisDocument
		|WHERE
		|	BasisDocuments.BasisDocument IS NULL
		|	AND DocumentData.OperationKind = VALUE(Enum.OperationTypesPaymentReceipt.FromCustomer)
		|	AND DocumentData.Posted
		|	AND DocumentData.CashCurrency = &Currency
		|";
		
	EndIf;
	
	If Left(QueryText, 10) = "UNION" Then
		QueryText = Mid(QueryText, 14);
	EndIf;
	
	Return QueryText;
	
EndFunction

// Gets text for the Tax invoice issued.
//
&AtServerNoContext
Function GetQueryTextTaxInvoiceIssued()
	
	QueryText =
	"SELECT
	|	UNDEFINED AS Ref,
	|	DATETIME(1, 1, 1) AS Date,
	|	""000000000000"" AS Number,
	|	VALUE(Catalog.Companies.EmptyRef) AS Company,
	|	&CounterpartyByDefault AS Counterparty,
	|	&ContractByDefault AS Contract,
	|	0 AS Amount,
	|	&Currency AS Currency,
	|	UNDEFINED AS Type,
	|	0 AS DocumentStatus
	|WHERE
	|	FALSE
	|";
	
	If AccessRight("Read", Metadata.Documents.CreditNote) Then
		
		QueryText = QueryText + "UNION ALL";
		
		QueryText = QueryText +
		"
		|SELECT
		|	DocumentData.Ref,
		|	DocumentData.Date,
		|	DocumentData.Number,
		|	DocumentData.Company,
		|	DocumentData.Counterparty,
		|	&ContractByDefault,
		|	DocumentData.DocumentAmount,
		|	DocumentData.DocumentCurrency,
		|	VALUETYPE(DocumentData.Ref),
		|	CASE
		|		WHEN DocumentData.Posted
		|			THEN 1
		|		WHEN DocumentData.DeletionMark
		|			THEN 2
		|		ELSE 0
		|	END
		|FROM
		|	Document.CreditNote AS DocumentData
		|		LEFT JOIN Document.TaxInvoiceReceived.BasisDocuments AS BasisDocuments
		|		ON DocumentData.Ref = BasisDocuments.BasisDocument
		|WHERE
		|	BasisDocuments.BasisDocument IS NULL
		|	AND DocumentData.Posted
		|	AND DocumentData.DocumentCurrency = &Currency
		|";
		
	EndIf;
	
	If AccessRight("Read", Metadata.Documents.SalesInvoice) Then
		
		QueryText = QueryText + "UNION ALL";
		
		QueryText = QueryText +
		"
		|SELECT
		|	DocumentData.Ref,
		|	DocumentData.Date,
		|	DocumentData.Number,
		|	DocumentData.Company,
		|	DocumentData.Counterparty,
		|	&ContractByDefault,
		|	DocumentData.DocumentAmount,
		|	DocumentData.DocumentCurrency,
		|	VALUETYPE(DocumentData.Ref),
		|	CASE
		|		WHEN DocumentData.Posted
		|			THEN 1
		|		WHEN DocumentData.DeletionMark
		|			THEN 2
		|		ELSE 0
		|	END
		|FROM
		|	Document.SalesInvoice AS DocumentData
		|		LEFT JOIN Document.TaxInvoiceReceived.BasisDocuments AS BasisDocuments
		|		ON DocumentData.Ref = BasisDocuments.BasisDocument
		|WHERE
		|	BasisDocuments.BasisDocument IS NULL
		|	AND DocumentData.Posted
		|	AND DocumentData.DocumentCurrency = &Currency
		|";
		
	EndIf;
	
	If Left(QueryText, 10) = "UNION" Then
		QueryText = Mid(QueryText, 14);
	EndIf;
	
	Return QueryText;
	
EndFunction

#EndRegion

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	ThisIsAccountsReceivable = Parameters.ThisIsAccountsReceivable;
	
	ThisIsBankStatementProcessing = Parameters.Property("ThisIsBankStatementProcessing");
	ThisIsAdvancePaymentsReceived = Parameters.Property("ThisIsAdvancePaymentsReceived");
	ThisIsAdvancePaymentsIssued = Parameters.Property("ThisIsAdvancePaymentsIssued");
	ThisIsTaxInvoiceReceived = Parameters.Property("ThisIsTaxInvoiceReceived");
	ThisIsTaxInvoiceIssued = Parameters.Property("ThisIsTaxInvoiceIssued");
	
	DocumentType = Parameters.DocumentType;
	
	If DocumentType = Type("DocumentRef.PaymentReceipt")
		OR DocumentType = Type("DocumentRef.CashReceipt") 
		OR DocumentType = Type("DocumentRef.DebitNote") Then
		
		If ThisIsAccountsReceivable Then
			List.QueryText = GetQueryTextAccountDocumentsOfAccountsReceivableReceipt();
		Else
			List.QueryText = GetQueryTextDocumentsOfAccountsPayableReceipt();
		EndIf;
		
	Else
		
		If ThisIsAccountsReceivable Then
			List.QueryText = GetQueryTextAccountDocumentsOfAccountsReceivableWriteOff();
		ElsIf ThisIsBankStatementProcessing Then
			List.QueryText = GetQueryTextDocumentForBankStatementProcessing();
		ElsIf ThisIsAdvancePaymentsReceived Then
			List.QueryText = GetQueryTextAdvancePaymentsReceived();
		ElsIf ThisIsAdvancePaymentsIssued Then
			List.QueryText = GetQueryTextAdvancePaymentsIssued();
		ElsIf ThisIsTaxInvoiceReceived Then
			List.QueryText = GetQueryTextTaxInvoiceReceived();
		ElsIf ThisIsTaxInvoiceIssued Then
			List.QueryText = GetQueryTextTaxInvoiceIssued();
		Else
			List.QueryText = GetQueryTextDocumentsOfAccountsPayableWriteOff();
		EndIf;
		
	EndIf;
	
	Items.Company.Visible = Not Parameters.Filter.Property("Company");
	
	If Parameters.Filter.Property("Counterparty") Then
		Items.Counterparty.Visible = True;
		List.Parameters.SetParameterValue("CounterpartyByDefault", Parameters.Filter.Counterparty);
	Else
		Items.Counterparty.Visible = False;
		List.Parameters.SetParameterValue("CounterpartyByDefault", Catalogs.Counterparties.EmptyRef());
	EndIf;
	
	If Parameters.Filter.Property("Contract") Then
		List.Parameters.SetParameterValue("ContractByDefault", Parameters.Filter.Contract);
	Else
		List.Parameters.SetParameterValue("ContractByDefault", Catalogs.CounterpartyContracts.EmptyRef());
	EndIf;
	
	If Parameters.Filter.Property("Currency") Then
		List.Parameters.SetParameterValue("Currency", Parameters.Filter.Currency);
	ElsIf Parameters.Filter.Property("DocumentCurrency") Then
		List.Parameters.SetParameterValue("Currency", Parameters.Filter.DocumentCurrency);
	Else
		List.Parameters.SetParameterValue("Currency", Catalogs.Currencies.EmptyRef());
	EndIf;
	
EndProcedure

#EndRegion

#Region ActionsOfTheFormCommandPanels

// The procedure is called when clicking button "Select".
//
&AtClient
Procedure ChooseDocument(Command)
	
	CurrentData = Items.List.CurrentData;
	If CurrentData <> Undefined Then
		
		DocumentData = New Structure;
		DocumentData.Insert("Document", CurrentData.Ref);
		DocumentData.Insert("Contract", CurrentData.Contract);
		
		Order = GetOrder(CurrentData.Ref, ThisIsAccountsReceivable);
		DocumentData.Insert("Order", Order);
		
		Quote = GetQuote(CurrentData.Ref, Order, ThisIsAccountsReceivable);
		DocumentData.Insert("Quote", Quote);
		
		NotifyChoice(DocumentData);
	Else
		Close();
	EndIf;
	
EndProcedure

// The procedure is called when clicking button "Open document".
//
&AtClient
Procedure OpenDocument(Command)
	
	TableRow = Items.List.CurrentData;
	If TableRow <> Undefined Then
		ShowValue(Undefined,TableRow.Ref);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormFieldEventHandlers

&AtClient
Procedure ListSelection(Item, SelectedRow, Field, StandardProcessing)
	
	CurrentData = Items.List.CurrentData;
	
	DocumentData = New Structure;
	DocumentData.Insert("Document", CurrentData.Ref);
	DocumentData.Insert("Contract", CurrentData.Contract);
	
	Order = GetOrder(CurrentData.Ref, ThisIsAccountsReceivable);
	DocumentData.Insert("Order", Order);
	
	Quote = GetQuote(CurrentData.Ref, Order, ThisIsAccountsReceivable);
	DocumentData.Insert("Quote", Quote);
	
	NotifyChoice(DocumentData);
	
EndProcedure

#EndRegion
