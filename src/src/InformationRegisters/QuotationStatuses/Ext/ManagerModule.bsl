#Region InfobaseUpdate

Procedure ProcessDataToUpgradeToNewVersion() Export
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	QuotationStatuses.ObsoleteQuotation AS ObsoleteQuotation,
	|	QuotationStatuses.ObsoleteQuotation AS Document,
	|	QuotationStatuses.Status AS Status
	|FROM
	|	InformationRegister.QuotationStatuses AS QuotationStatuses
	|WHERE
	|	QuotationStatuses.Document = VALUE(Document.Quote.EmptyRef)";
	
	QueryResult = Query.Execute();
	Selection	= QueryResult.Select();
	
	While Selection.Next() Do
		RecordManager = InformationRegisters.QuotationStatuses.CreateRecordManager();
		FillPropertyValues(RecordManager, Selection);
		RecordManager.Write();
	EndDo;
	
EndProcedure

#EndRegion
