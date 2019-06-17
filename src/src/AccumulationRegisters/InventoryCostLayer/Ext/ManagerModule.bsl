#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

#Region InfobaseUpdate

// Replacing Sales order empty ref to UNDEFINED
Procedure ChangeSalesOrderEmptyRefToUndefined() Export
	
	Query = New Query;
	Query.TempTablesManager = New TempTablesManager;
	Query.Text = 
	"SELECT
	|	InventoryCostLayer.Recorder AS Ref
	|FROM
	|	AccumulationRegister.InventoryCostLayer AS InventoryCostLayer
	|WHERE
	|	(InventoryCostLayer.SalesOrder = VALUE(Document.SalesOrder.EmptyRef)
	|			OR InventoryCostLayer.CorrSalesOrder = VALUE(Document.SalesOrder.EmptyRef))";
	
	QueryResult = Query.Execute();
	Selection	= QueryResult.Select();
	
	While Selection.Next() Do
		Query.Text = 
		"SELECT
		|	InventoryCostLayer.Period AS Period,
		|	InventoryCostLayer.Recorder AS Recorder,
		|	InventoryCostLayer.LineNumber AS LineNumber,
		|	InventoryCostLayer.Active AS Active,
		|	InventoryCostLayer.RecordType AS RecordType,
		|	InventoryCostLayer.Company AS Company,
		|	InventoryCostLayer.Products AS Products,
		|	CASE
		|		WHEN InventoryCostLayer.SalesOrder = VALUE(Document.SalesOrder.EmptyRef)
		|			THEN UNDEFINED
		|		ELSE InventoryCostLayer.SalesOrder
		|	END AS SalesOrder,
		|	InventoryCostLayer.CostLayer AS CostLayer,
		|	InventoryCostLayer.Characteristic AS Characteristic,
		|	InventoryCostLayer.Batch AS Batch,
		|	InventoryCostLayer.StructuralUnit AS StructuralUnit,
		|	InventoryCostLayer.GLAccount AS GLAccount,
		|	InventoryCostLayer.Quantity AS Quantity,
		|	InventoryCostLayer.Amount AS Amount,
		|	InventoryCostLayer.SourceRecord AS SourceRecord,
		|	InventoryCostLayer.VATRate AS VATRate,
		|	InventoryCostLayer.Responsible AS Responsible,
		|	InventoryCostLayer.Department AS Department,
		|	InventoryCostLayer.SourceDocument AS SourceDocument,
		|	CASE
		|		WHEN InventoryCostLayer.CorrSalesOrder = VALUE(Document.SalesOrder.EmptyRef)
		|			THEN UNDEFINED
		|		ELSE InventoryCostLayer.CorrSalesOrder
		|	END AS CorrSalesOrder,
		|	InventoryCostLayer.CorrStructuralUnit AS CorrStructuralUnit,
		|	InventoryCostLayer.CorrGLAccount AS CorrGLAccount,
		|	InventoryCostLayer.RIMTransfer AS RIMTransfer
		|FROM
		|	AccumulationRegister.InventoryCostLayer AS InventoryCostLayer
		|WHERE
		|	InventoryCostLayer.Recorder = &Ref";
		
		Query.SetParameter("Ref", Selection.Ref);
		
		RegisterRecords = AccumulationRegisters.InventoryCostLayer.CreateRecordSet();
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
				Metadata.AccumulationRegisters.InventoryCostLayer,
				,
				ErrorDescription);
		EndTry;
			
	EndDo;
	
EndProcedure

#EndRegion

#EndRegion

#EndIf


