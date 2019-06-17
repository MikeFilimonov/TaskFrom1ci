#Region InfobaseUpdate

Procedure ExcludeVATAmount() Export
	
	Query = New Query;
	
	Query.Text =
	"SELECT DISTINCT
	|	Purchases.Recorder AS Recorder
	|FROM
	|	AccumulationRegister.Purchases AS Purchases
	|WHERE
	|	Purchases.ObsoleteAmount <> 0
	|	AND Purchases.Amount = 0";
	
	Sel = Query.Execute().Select();
	
	While Sel.Next() Do
		
		Query.SetParameter("Recorder", Sel.Recorder);
		Query.Text =
		"SELECT
		|	Purchases.Period AS Period,
		|	Purchases.Active AS Active,
		|	Purchases.Company AS Company,
		|	Purchases.PurchaseOrder AS PurchaseOrder,
		|	Purchases.Products AS Products,
		|	Purchases.Characteristic AS Characteristic,
		|	Purchases.Batch AS Batch,
		|	Purchases.Document AS Document,
		|	Purchases.VATRate AS VATRate,
		|	Purchases.Quantity AS Quantity,
		|	Purchases.ObsoleteAmount - Purchases.VATAmount AS Amount,
		|	Purchases.VATAmount AS VATAmount,
		|	Purchases.ObsoleteAmount AS ObsoleteAmount
		|FROM
		|	AccumulationRegister.Purchases AS Purchases
		|WHERE
		|	Purchases.Recorder = &Recorder
		|
		|ORDER BY
		|	Purchases.LineNumber";
		
		RecordSet = AccumulationRegisters.Purchases.CreateRecordSet();
		RecordSet.Filter.Recorder.Set(Sel.Recorder);
		RecordSet.Load(Query.Execute().Unload());
		RecordSet.Write();
		
	EndDo;
	
EndProcedure

#EndRegion