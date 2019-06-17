#Region UpdateHandlers

Procedure ProcessDataToUpgradeToNewVersion() Export
	
	Query = New Query;
	Query.TempTablesManager = New TempTablesManager;
	Query.Text = 
	"SELECT DISTINCT
	|	OrdersPaymentSchedule.Quote AS Quote
	|FROM
	|	InformationRegister.OrdersPaymentSchedule AS OrdersPaymentSchedule
	|WHERE
	|	VALUETYPE(OrdersPaymentSchedule.Quote) = TYPE(Document.Quote)";
	
	DataSelection = Query.Execute().Select();
	While DataSelection.Next() Do
		RegisterRecords = InformationRegisters.OrdersPaymentSchedule.CreateRecordSet();
		RegisterRecords.Filter.Quote.Set(DataSelection.Quote);
		RegisterRecords.Write();
	EndDo;
	
EndProcedure

#EndRegion