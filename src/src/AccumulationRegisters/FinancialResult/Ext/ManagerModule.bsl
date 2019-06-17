#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

#Region InfobaseUpdate

// Replaces an empty sales order reference with an undefined
//
Procedure ChangeSalesOrderEmptyRefToUndefined() Export
	
	Query = New Query;
	Query.Text = 
	"SELECT DISTINCT
	|	FinancialResult.Recorder AS Ref
	|FROM
	|	AccumulationRegister.FinancialResult AS FinancialResult
	|WHERE
	|	FinancialResult.SalesOrder = VALUE(Document.SalesOrder.EmptyRef)";
	
	QueryResult = Query.Execute();
	Selection	= QueryResult.Select();
	
	While Selection.Next() Do
		
		Query.Text = 
		"SELECT
		|	FinancialResult.Period AS Period,
		|	FinancialResult.Recorder AS Recorder,
		|	FinancialResult.LineNumber AS LineNumber,
		|	FinancialResult.Active AS Active,
		|	FinancialResult.Company AS Company,
		|	FinancialResult.StructuralUnit AS StructuralUnit,
		|	FinancialResult.BusinessLine AS BusinessLine,
		|	CASE
		|		WHEN FinancialResult.SalesOrder = VALUE(Document.SalesOrder.EmptyRef)
		|			THEN UNDEFINED
		|		ELSE FinancialResult.SalesOrder
		|	END AS SalesOrder,
		|	FinancialResult.GLAccount AS GLAccount,
		|	FinancialResult.AmountIncome AS AmountIncome,
		|	FinancialResult.AmountExpense AS AmountExpense,
		|	FinancialResult.ContentOfAccountingRecord AS ContentOfAccountingRecord
		|FROM
		|	AccumulationRegister.FinancialResult AS FinancialResult
		|WHERE
		|	FinancialResult.Recorder = &Ref";
		
		Query.SetParameter("Ref", Selection.Ref);
		
		RegisterRecords = AccumulationRegisters.FinancialResult.CreateRecordSet();
		RegisterRecords.Filter.Recorder.Set(Selection.Ref);
		RegisterRecords.Load(Query.Execute().Unload());
		
		Try
			
			RegisterRecords.Write();
			
		Except
			
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Error on write document %1: %2'"),
				Selection.Ref,
				BriefErrorDescription(ErrorInfo()));
				
			WriteLogEvent(
				NStr("en = 'InfobaseUpdate'", CommonUseClientServer.MainLanguageCode()),
				EventLogLevel.Error,
				Metadata.AccumulationRegisters.FinancialResult,
				,
				ErrorDescription);
				
		EndTry;
			
	EndDo;
	
EndProcedure

#EndRegion

#EndRegion

#EndIf
