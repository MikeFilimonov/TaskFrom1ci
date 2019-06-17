#Region UpdateHandlers

Procedure ProcessDataToUpgradeToNewVersion() Export
	
	Query = New Query;
	Query.TempTablesManager = New TempTablesManager;
	Query.Text = 
	"SELECT DISTINCT
	|	OrderPayments.Quote AS Quote
	|FROM
	|	InformationRegister.OrderPayments AS OrderPayments
	|WHERE
	|	VALUETYPE(OrderPayments.Quote) = TYPE(Document.Quote)";
	
	DataSelection = Query.Execute().Select();
	While DataSelection.Next() Do
		RegisterRecords = InformationRegisters.OrderPayments.CreateRecordSet();
		RegisterRecords.Filter.Quote.Set(DataSelection.Quote);
		RegisterRecords.Write();
	EndDo;
	
EndProcedure

#EndRegion
