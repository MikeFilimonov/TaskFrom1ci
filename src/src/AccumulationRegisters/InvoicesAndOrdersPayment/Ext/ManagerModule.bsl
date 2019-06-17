#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
	
#Region Public

#Region InfobaseUpdate

Procedure ProcessDataToUpgradeToNewVersion() Export
	
	Query = New Query;
	Query.Text = 
	"SELECT DISTINCT
	|	InvoicesAndOrdersPayment.Recorder AS Recorder
	|FROM
	|	AccumulationRegister.InvoicesAndOrdersPayment AS InvoicesAndOrdersPayment
	|WHERE
	|	VALUETYPE(InvoicesAndOrdersPayment.Recorder) = TYPE(Document.SupplierQuote)";
	
	DataSelection = Query.Execute().Select();
	While DataSelection.Next() Do
		
		RegisterRecords = AccumulationRegisters.InvoicesAndOrdersPayment.CreateRecordSet();
		RegisterRecords.Filter.Recorder.Set(DataSelection.Recorder);
		Try
			RegisterRecords.Write();
		Except
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Error on write document %1: %2'"),
				DataSelection.Recorder,
				BriefErrorDescription(ErrorInfo()));
				
			WriteLogEvent(
				"InfobaseUpdate",
				EventLogLevel.Error,
				Metadata.AccumulationRegisters.InvoicesAndOrdersPayment,
				,
				ErrorDescription);
		EndTry;
		
	EndDo;
	
EndProcedure

#EndRegion

#EndRegion

#EndIf
