#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

Procedure ProcessDataToUpgradeToNewVersion() Export
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	Quote.Ref AS Recorder,
	|	Quote.Date AS Period,
	|	Quote.Company AS Company,
	|	Quote.Counterparty AS Counterparty,
	|	Quote.DocumentAmount AS Amount
	|FROM
	|	Document.Quote AS Quote
	|		LEFT JOIN AccumulationRegister.Quotations.Turnovers(, , Recorder, ) AS QuotationsTurnovers
	|		ON (Quote.Ref = QuotationsTurnovers.Recorder)
	|WHERE
	|	QuotationsTurnovers.Recorder IS NULL
	|	AND Quote.Posted";
	
	QueryResult = Query.Execute();
	Selection	= QueryResult.Select();
	
	While Selection.Next() Do
		
		RegisterRecords = AccumulationRegisters.Quotations.CreateRecordSet();
		RegisterRecords.Filter.Recorder.Set(Selection.Recorder);
		NewRecord = RegisterRecords.Add();
		FillPropertyValues(NewRecord, Selection);
		
		Try
			RegisterRecords.Write();
		Except
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Error on write document %1: %2'"),
				Selection.Quotation,
				BriefErrorDescription(ErrorInfo()));
				
			WriteLogEvent(
				NStr("en = 'InfobaseUpdate'", CommonUseClientServer.MainLanguageCode()),
				EventLogLevel.Error,
				Metadata.AccumulationRegisters.Quotations,
				,
				ErrorDescription);
		EndTry;
			
	EndDo;
	
EndProcedure

#EndRegion

#EndIf
