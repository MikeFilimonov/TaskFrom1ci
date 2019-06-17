#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

#Region InfobaseUpdate

// Replaces an empty sales order reference with an undefined
//
Procedure ChangeSalesOrderEmptyRefToUndefined() Export
	
	Query = New Query;
	Query.Text = 
	"SELECT DISTINCT
	|	LandedCosts.Recorder AS Ref
	|FROM
	|	AccumulationRegister.LandedCosts AS LandedCosts
	|WHERE
	|	(LandedCosts.SalesOrder = VALUE(Document.SalesOrder.EmptyRef)
	|			OR LandedCosts.CorrSalesOrder = VALUE(Document.SalesOrder.EmptyRef))";
	
	QueryResult = Query.Execute();
	Selection	= QueryResult.Select();
	
	While Selection.Next() Do
		
		Query.Text = 
		"SELECT
		|	LandedCosts.Period AS Period,
		|	LandedCosts.Recorder AS Recorder,
		|	LandedCosts.LineNumber AS LineNumber,
		|	LandedCosts.Active AS Active,
		|	LandedCosts.RecordType AS RecordType,
		|	LandedCosts.Company AS Company,
		|	LandedCosts.Products AS Products,
		|	CASE
		|		WHEN LandedCosts.SalesOrder = VALUE(Document.SalesOrder.EmptyRef)
		|			THEN UNDEFINED
		|		ELSE LandedCosts.SalesOrder
		|	END AS SalesOrder,
		|	LandedCosts.CostLayer AS CostLayer,
		|	LandedCosts.Characteristic AS Characteristic,
		|	LandedCosts.Batch AS Batch,
		|	LandedCosts.StructuralUnit AS StructuralUnit,
		|	LandedCosts.GLAccount AS GLAccount,
		|	LandedCosts.Amount AS Amount,
		|	LandedCosts.SourceRecord AS SourceRecord,
		|	LandedCosts.VATRate AS VATRate,
		|	LandedCosts.Responsible AS Responsible,
		|	LandedCosts.Department AS Department,
		|	LandedCosts.SourceDocument AS SourceDocument,
		|	CASE
		|		WHEN LandedCosts.CorrSalesOrder = VALUE(Document.SalesOrder.EmptyRef)
		|			THEN UNDEFINED
		|		ELSE LandedCosts.CorrSalesOrder
		|	END AS CorrSalesOrder,
		|	LandedCosts.CorrStructuralUnit AS CorrStructuralUnit,
		|	LandedCosts.CorrGLAccount AS CorrGLAccount,
		|	LandedCosts.RIMTransfer AS RIMTransfer
		|FROM
		|	AccumulationRegister.LandedCosts AS LandedCosts
		|WHERE
		|	LandedCosts.Recorder = &Ref";
		
		Query.SetParameter("Ref", Selection.Ref);
		
		RegisterRecords = AccumulationRegisters.LandedCosts.CreateRecordSet();
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
				Metadata.AccumulationRegisters.LandedCosts,
				,
				ErrorDescription);
				
		EndTry;
			
	EndDo;
	
EndProcedure

#EndRegion

#EndRegion

#EndIf