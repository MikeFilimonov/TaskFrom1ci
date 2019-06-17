#Region UpdateHandlers

Procedure ProcessDataToUpgradeToNewVersion() Export
	
	Query = New Query;
	Query.TempTablesManager = New TempTablesManager;
	Query.Text = 
	"SELECT DISTINCT
	|	PaymentsSchedule.Quote AS Quote
	|FROM
	|	InformationRegister.PaymentsSchedule AS PaymentsSchedule
	|WHERE
	|	VALUETYPE(PaymentsSchedule.Quote) = TYPE(Document.Quote)";
	
	DataSelection = Query.Execute().Select();
	While DataSelection.Next() Do
		RegisterRecords = InformationRegisters.PaymentsSchedule.CreateRecordSet();
		RegisterRecords.Filter.Quote.Set(DataSelection.Quote);
		RegisterRecords.Write();
	EndDo;
	
EndProcedure

#EndRegion