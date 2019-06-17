#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
	
#Region Public

#Region InfobaseUpdate

// Replaces an empty sales order reference with an undefined
//
Procedure ChangeSalesOrderEmptyRefToUndefined() Export
	
	Query = New Query;
	Query.Text = 
	"SELECT DISTINCT
	|	ProductRelease.Recorder AS Ref
	|FROM
	|	AccumulationRegister.ProductRelease AS ProductRelease
	|WHERE
	|	ProductRelease.SalesOrder = VALUE(Document.SalesOrder.EmptyRef)";
	
	QueryResult = Query.Execute();
	Selection	= QueryResult.Select();
	
	While Selection.Next() Do
		
		Query.Text = 
		"SELECT
		|	ProductRelease.Period AS Period,
		|	ProductRelease.Recorder AS Recorder,
		|	ProductRelease.LineNumber AS LineNumber,
		|	ProductRelease.Active AS Active,
		|	ProductRelease.Company AS Company,
		|	ProductRelease.StructuralUnit AS StructuralUnit,
		|	ProductRelease.Products AS Products,
		|	ProductRelease.Characteristic AS Characteristic,
		|	ProductRelease.Batch AS Batch,
		|	CASE
		|		WHEN ProductRelease.SalesOrder = VALUE(Document.SalesOrder.EmptyRef)
		|			THEN UNDEFINED
		|		ELSE ProductRelease.SalesOrder
		|	END AS SalesOrder,
		|	ProductRelease.Specification AS Specification,
		|	ProductRelease.Quantity AS Quantity,
		|	ProductRelease.QuantityPlan AS QuantityPlan
		|FROM
		|	AccumulationRegister.ProductRelease AS ProductRelease
		|WHERE
		|	ProductRelease.Recorder = &Ref";
		
		Query.SetParameter("Ref", Selection.Ref);
		
		RegisterRecords = AccumulationRegisters.ProductRelease.CreateRecordSet();
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
				Metadata.AccumulationRegisters.ProductRelease,
				,
				ErrorDescription);
				
		EndTry;
		
	EndDo;
	
EndProcedure

#EndRegion

#EndRegion

#EndIf
