#Region InfobaseUpdate

Procedure ProcessDataToUpgradeToNewVersion() Export
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	AccountSalesFromConsignee.Ref AS Document,
	|	AccountSalesFromConsignee.SetPaymentTerms AS UsingPaymentTerms
	|FROM
	|	Document.AccountSalesFromConsignee AS AccountSalesFromConsignee
	|		LEFT JOIN InformationRegister.UsingPaymentTermsInDocuments AS UsingPaymentTermsInDocuments
	|		ON (UsingPaymentTermsInDocuments.Document = AccountSalesFromConsignee.Ref)
	|WHERE
	|	UsingPaymentTermsInDocuments.Document IS NULL
	|
	|UNION ALL
	|
	|SELECT
	|	AccountSalesToConsignor.Ref,
	|	AccountSalesToConsignor.SetPaymentTerms
	|FROM
	|	Document.AccountSalesToConsignor AS AccountSalesToConsignor
	|		LEFT JOIN InformationRegister.UsingPaymentTermsInDocuments AS UsingPaymentTermsInDocuments
	|		ON (UsingPaymentTermsInDocuments.Document = AccountSalesToConsignor.Ref)
	|WHERE
	|	UsingPaymentTermsInDocuments.Document IS NULL
	|
	|UNION ALL
	|
	|SELECT
	|	AdditionalExpenses.Ref,
	|	AdditionalExpenses.SetPaymentTerms
	|FROM
	|	Document.AdditionalExpenses AS AdditionalExpenses
	|		LEFT JOIN InformationRegister.UsingPaymentTermsInDocuments AS UsingPaymentTermsInDocuments
	|		ON (UsingPaymentTermsInDocuments.Document = AdditionalExpenses.Ref)
	|WHERE
	|	UsingPaymentTermsInDocuments.Document IS NULL
	|
	|UNION ALL
	|
	|SELECT
	|	PurchaseOrder.Ref,
	|	PurchaseOrder.SetPaymentTerms
	|FROM
	|	Document.PurchaseOrder AS PurchaseOrder
	|		LEFT JOIN InformationRegister.UsingPaymentTermsInDocuments AS UsingPaymentTermsInDocuments
	|		ON (UsingPaymentTermsInDocuments.Document = PurchaseOrder.Ref)
	|WHERE
	|	UsingPaymentTermsInDocuments.Document IS NULL
	|
	|UNION ALL
	|
	|SELECT
	|	Quote.Ref,
	|	Quote.SetPaymentTerms
	|FROM
	|	Document.Quote AS Quote
	|		LEFT JOIN InformationRegister.UsingPaymentTermsInDocuments AS UsingPaymentTermsInDocuments
	|		ON (UsingPaymentTermsInDocuments.Document = Quote.Ref)
	|WHERE
	|	UsingPaymentTermsInDocuments.Document IS NULL
	|
	|UNION ALL
	|
	|SELECT
	|	SalesInvoice.Ref,
	|	SalesInvoice.SetPaymentTerms
	|FROM
	|	Document.SalesInvoice AS SalesInvoice
	|		LEFT JOIN InformationRegister.UsingPaymentTermsInDocuments AS UsingPaymentTermsInDocuments
	|		ON (UsingPaymentTermsInDocuments.Document = SalesInvoice.Ref)
	|WHERE
	|	UsingPaymentTermsInDocuments.Document IS NULL
	|
	|UNION ALL
	|
	|SELECT
	|	SalesOrder.Ref,
	|	SalesOrder.SetPaymentTerms
	|FROM
	|	Document.SalesOrder AS SalesOrder
	|		LEFT JOIN InformationRegister.UsingPaymentTermsInDocuments AS UsingPaymentTermsInDocuments
	|		ON (UsingPaymentTermsInDocuments.Document = SalesOrder.Ref)
	|WHERE
	|	UsingPaymentTermsInDocuments.Document IS NULL
	|
	|UNION ALL
	|
	|SELECT
	|	SubcontractorReportIssued.Ref,
	|	SubcontractorReportIssued.SetPaymentTerms
	|FROM
	|	Document.SubcontractorReportIssued AS SubcontractorReportIssued
	|		LEFT JOIN InformationRegister.UsingPaymentTermsInDocuments AS UsingPaymentTermsInDocuments
	|		ON (UsingPaymentTermsInDocuments.Document = SubcontractorReportIssued.Ref)
	|WHERE
	|	UsingPaymentTermsInDocuments.Document IS NULL
	|
	|UNION ALL
	|
	|SELECT
	|	SupplierInvoice.Ref,
	|	SupplierInvoice.SetPaymentTerms
	|FROM
	|	Document.SupplierInvoice AS SupplierInvoice
	|		LEFT JOIN InformationRegister.UsingPaymentTermsInDocuments AS UsingPaymentTermsInDocuments
	|		ON (UsingPaymentTermsInDocuments.Document = SupplierInvoice.Ref)
	|WHERE
	|	UsingPaymentTermsInDocuments.Document IS NULL
	|
	|UNION ALL
	|
	|SELECT
	|	SupplierQuote.Ref,
	|	SupplierQuote.SetPaymentTerms
	|FROM
	|	Document.SupplierQuote AS SupplierQuote
	|		LEFT JOIN InformationRegister.UsingPaymentTermsInDocuments AS UsingPaymentTermsInDocuments
	|		ON (UsingPaymentTermsInDocuments.Document = SupplierQuote.Ref)
	|WHERE
	|	UsingPaymentTermsInDocuments.Document IS NULL";
	
	QueryResult = Query.Execute();
	Selection	= QueryResult.Select();
	
	While Selection.Next() Do
		RecordManager = InformationRegisters.UsingPaymentTermsInDocuments.CreateRecordManager();
		FillPropertyValues(RecordManager, Selection);
		Try
			RecordManager.Write();
		Except
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Error on write document %1: %2'"),
				Selection.Document,
				BriefErrorDescription(ErrorInfo()));
				
			WriteLogEvent(
				"InfobaseUpdate",
				EventLogLevel.Error,
				Metadata.InformationRegisters.UsingPaymentTermsInDocuments,
				,
				ErrorDescription);
		EndTry;
	EndDo;
	
EndProcedure

#EndRegion
