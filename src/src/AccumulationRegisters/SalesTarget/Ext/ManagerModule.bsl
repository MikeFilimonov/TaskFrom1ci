#Region InfobaseUpdate

Procedure ExcludeVATAmount() Export
	
	Query = New Query;
	
	Query.Text =
	"SELECT DISTINCT
	|	SalesTarget.Recorder AS Recorder
	|FROM
	|	AccumulationRegister.SalesTarget AS SalesTarget
	|WHERE
	|	SalesTarget.ObsoleteAmount <> 0
	|	AND SalesTarget.Amount = 0";
	
	Sel = Query.Execute().Select();
	
	While Sel.Next() Do
		
		Query.SetParameter("Recorder", Sel.Recorder);
		Query.Text =
		"SELECT
		|	SalesTarget.Period AS Period,
		|	SalesTarget.Active AS Active,
		|	SalesTarget.Company AS Company,
		|	SalesTarget.StructuralUnit AS StructuralUnit,
		|	SalesTarget.PlanningPeriod AS PlanningPeriod,
		|	SalesTarget.Products AS Products,
		|	SalesTarget.Characteristic AS Characteristic,
		|	SalesTarget.SalesOrder AS SalesOrder,
		|	SalesTarget.PlanningDocument AS PlanningDocument,
		|	SalesTarget.Quantity AS Quantity,
		|	SalesTarget.ObsoleteAmount - SalesTarget.VATAmount AS Amount,
		|	SalesTarget.VATAmount AS VATAmount,
		|	SalesTarget.ObsoleteAmount AS ObsoleteAmount
		|FROM
		|	AccumulationRegister.SalesTarget AS SalesTarget
		|WHERE
		|	SalesTarget.Recorder = &Recorder
		|
		|ORDER BY
		|	SalesTarget.LineNumber";
		
		RecordSet = AccumulationRegisters.SalesTarget.CreateRecordSet();
		RecordSet.Filter.Recorder.Set(Sel.Recorder);
		RecordSet.Load(Query.Execute().Unload());
		RecordSet.Write();
		
	EndDo;
	
EndProcedure

#EndRegion