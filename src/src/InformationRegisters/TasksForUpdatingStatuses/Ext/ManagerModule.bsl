#Region InfobaseUpdate

Procedure ProcessDataToUpgradeToNewVersion() Export
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	Quote.Ref AS Document
	|FROM
	|	Document.Quote AS Quote
	|		LEFT JOIN InformationRegister.QuotationStatuses AS QuotationStatuses
	|		ON Quote.Ref = QuotationStatuses.Document
	|WHERE
	|	QuotationStatuses.Document IS NULL
	|
	|UNION ALL
	|
	|SELECT
	|	GoodsReceipt.Ref
	|FROM
	|	Document.GoodsReceipt AS GoodsReceipt
	|		LEFT JOIN InformationRegister.GoodsDocumentsStatuses AS GoodsDocumentsStatuses
	|		ON GoodsReceipt.Ref = GoodsDocumentsStatuses.Document
	|WHERE
	|	GoodsDocumentsStatuses.Document IS NULL
	|
	|UNION ALL
	|
	|SELECT
	|	GoodsIssue.Ref
	|FROM
	|	Document.GoodsIssue AS GoodsIssue
	|		LEFT JOIN InformationRegister.GoodsDocumentsStatuses AS GoodsDocumentsStatuses
	|		ON GoodsIssue.Ref = GoodsDocumentsStatuses.Document
	|WHERE
	|	GoodsDocumentsStatuses.Document IS NULL
	|
	|UNION ALL
	|
	|SELECT
	|	SalesInvoice.Ref
	|FROM
	|	Document.SalesInvoice AS SalesInvoice
	|		LEFT JOIN InformationRegister.InvoicesPaymentStatuses AS InvoicesPaymentStatuses
	|		ON SalesInvoice.Ref = InvoicesPaymentStatuses.Document
	|WHERE
	|	InvoicesPaymentStatuses.Document IS NULL
	|
	|UNION ALL
	|
	|SELECT
	|	SupplierInvoice.Ref
	|FROM
	|	Document.SupplierInvoice AS SupplierInvoice
	|		LEFT JOIN InformationRegister.InvoicesPaymentStatuses AS InvoicesPaymentStatuses
	|		ON SupplierInvoice.Ref = InvoicesPaymentStatuses.Document
	|WHERE
	|	InvoicesPaymentStatuses.Document IS NULL";
	
	QueryResult = Query.Execute();
	Selection	= QueryResult.Select();
	
	While Selection.Next() Do
		RecordManager = InformationRegisters.TasksForUpdatingStatuses.CreateRecordManager();
		RecordManager.Document = Selection.Document;
		RecordManager.Write();
	EndDo;
	
EndProcedure

#EndRegion
