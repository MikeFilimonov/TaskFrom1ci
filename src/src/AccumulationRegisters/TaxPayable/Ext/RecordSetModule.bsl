#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

// Procedure - event handler BeforeWrite record set.
//
Procedure BeforeWrite(Cancel, Replacing)
	
	If DataExchange.Load
  OR Not AdditionalProperties.Property("ForPosting")
  OR Not AdditionalProperties.ForPosting.Property("StructureTemporaryTables") Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// Setting the exclusive lock of current registrar record set.
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.TaxPayable.RecordSet");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.SetValue("Recorder", Filter.Recorder.Value);
	Block.Lock();
	
	If Not StructureTemporaryTables.Property("RegisterRecordsTaxesSettlementsUpdate")
		OR StructureTemporaryTables.Property("RegisterRecordsTaxesSettlementsUpdate")
	   AND Not StructureTemporaryTables.RegisterRecordsTaxesSettlementsUpdate Then
		
		// If the temporary table "RegisterRecordsTaxesSettlementsChange" doesn't exist and doesn't
		// contain records about the set change then set is written for the first time and for set balance control was executed.
		// Current set state is placed in a
		// temporary table "RegisterRecordsTaxesSettlementsBeforeWrite" to get at record new set change rather current.
		
		Query = New Query(
		"SELECT
		|	TaxPayable.LineNumber AS LineNumber,
		|	TaxPayable.Company AS Company,
		|	TaxPayable.TaxKind AS TaxKind,
		|	CASE
		|		WHEN TaxPayable.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN TaxPayable.Amount
		|		ELSE -TaxPayable.Amount
		|	END AS SumBeforeWrite
		|INTO RegisterRecordsTaxesSettlementsBeforeWrite
		|FROM
		|	AccumulationRegister.TaxPayable AS TaxPayable
		|WHERE
		|	TaxPayable.Recorder = &Recorder
		|	AND &Replacing");
		
		Query.SetParameter("Recorder", Filter.Recorder.Value);
		Query.SetParameter("Replacing", Replacing);
				
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		
	Else
		
		// If the temporary table "RegisterRecordsTaxesSettlementsChange" exists and
		// contains records about the set change then set is written not for the first time and for set balance control wasn't executed.
		// Current set state and current change state are placed in
		// a temporary table "RegisterRecordsTaxesSettlementsBeforeWrite" to get at record new set change rather initial.
		
		Query = New Query(
		"SELECT
		|	RegisterRecordsTaxesSettlementsUpdate.LineNumber AS LineNumber,
		|	RegisterRecordsTaxesSettlementsUpdate.Company AS Company,
		|	RegisterRecordsTaxesSettlementsUpdate.TaxKind AS TaxKind,
		|	RegisterRecordsTaxesSettlementsUpdate.SumBeforeWrite AS SumBeforeWrite
		|INTO RegisterRecordsTaxesSettlementsBeforeWrite
		|FROM
		|	RegisterRecordsTaxesSettlementsUpdate AS RegisterRecordsTaxesSettlementsUpdate
		|
		|UNION ALL
		|
		|SELECT
		|	TaxPayable.LineNumber,
		|	TaxPayable.Company,
		|	TaxPayable.TaxKind,
		|	CASE
		|		WHEN TaxPayable.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN TaxPayable.Amount
		|		ELSE -TaxPayable.Amount
		|	END
		|FROM
		|	AccumulationRegister.TaxPayable AS TaxPayable
		|WHERE
		|	TaxPayable.Recorder = &Recorder
		|	AND &Replacing");
		
		Query.SetParameter("Recorder", Filter.Recorder.Value);
		Query.SetParameter("Replacing", Replacing);
				
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		
	EndIf;
	
	// Temporary table
	// "RegisterRecordsTaxesSettlementsChange" is destroyed info about its existence is Deleted.
	
	If StructureTemporaryTables.Property("RegisterRecordsTaxesSettlementsUpdate") Then
		
		Query = New Query("DROP RegisterRecordsTaxesSettlementsChange");
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		StructureTemporaryTables.Delete("RegisterRecordsTaxesSettlementsUpdate");
	
	EndIf;
	
EndProcedure

// Procedure - event handler OnWrite record set.
//
Procedure OnWrite(Cancel, Replacing)
	
	If DataExchange.Load
  OR Not AdditionalProperties.Property("ForPosting")
  OR Not AdditionalProperties.ForPosting.Property("StructureTemporaryTables") Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// New set change is calculated relatively current with accounting
	// accumulated changes and placed into temporary table "RegisterRecordsTaxesSettlementsChange".
	
	Query = New Query(
	"SELECT
	|	MIN(RegisterRecordsTaxesSettlementsUpdate.LineNumber) AS LineNumber,
	|	RegisterRecordsTaxesSettlementsUpdate.Company AS Company,
	|	RegisterRecordsTaxesSettlementsUpdate.TaxKind AS TaxKind,
	|	SUM(RegisterRecordsTaxesSettlementsUpdate.SumBeforeWrite) AS SumBeforeWrite,
	|	SUM(RegisterRecordsTaxesSettlementsUpdate.AmountChange) AS AmountChange,
	|	SUM(RegisterRecordsTaxesSettlementsUpdate.AmountOnWrite) AS AmountOnWrite
	|INTO RegisterRecordsTaxesSettlementsUpdate
	|FROM
	|	(SELECT
	|		RegisterRecordsTaxesSettlementsBeforeWrite.LineNumber AS LineNumber,
	|		RegisterRecordsTaxesSettlementsBeforeWrite.Company AS Company,
	|		RegisterRecordsTaxesSettlementsBeforeWrite.TaxKind AS TaxKind,
	|		RegisterRecordsTaxesSettlementsBeforeWrite.SumBeforeWrite AS SumBeforeWrite,
	|		RegisterRecordsTaxesSettlementsBeforeWrite.SumBeforeWrite AS AmountChange,
	|		0 AS AmountOnWrite
	|	FROM
	|		RegisterRecordsTaxesSettlementsBeforeWrite AS RegisterRecordsTaxesSettlementsBeforeWrite
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		RegisterRecordsTaxesSettlementsOnWrite.LineNumber,
	|		RegisterRecordsTaxesSettlementsOnWrite.Company,
	|		RegisterRecordsTaxesSettlementsOnWrite.TaxKind,
	|		0,
	|		CASE
	|			WHEN RegisterRecordsTaxesSettlementsOnWrite.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -RegisterRecordsTaxesSettlementsOnWrite.Amount
	|			ELSE RegisterRecordsTaxesSettlementsOnWrite.Amount
	|		END,
	|		RegisterRecordsTaxesSettlementsOnWrite.Amount
	|	FROM
	|		AccumulationRegister.TaxPayable AS RegisterRecordsTaxesSettlementsOnWrite
	|	WHERE
	|		RegisterRecordsTaxesSettlementsOnWrite.Recorder = &Recorder) AS RegisterRecordsTaxesSettlementsUpdate
	|
	|GROUP BY
	|	RegisterRecordsTaxesSettlementsUpdate.Company,
	|	RegisterRecordsTaxesSettlementsUpdate.TaxKind
	|
	|HAVING
	|	SUM(RegisterRecordsTaxesSettlementsUpdate.AmountChange) <> 0
	|
	|INDEX BY
	|	Company,
	|	TaxKind");
	
	Query.SetParameter("Recorder", Filter.Recorder.Value);
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	
	QueryResult = Query.Execute();
	
	QueryResultSelection = QueryResult.Select();
	QueryResultSelection.Next();
	
	// New changes were placed into temporary table "RegisterRecordsTaxesSettlementsChange".
	// It is added info about its existence and availability by her change records.
	StructureTemporaryTables.Insert("RegisterRecordsTaxesSettlementsUpdate", QueryResultSelection.Count > 0);
	
	// The "RegisterRecordsTaxesSettlementsBeforeWrite" temporary table is deleted
	Query = New Query("DROP RegisterRecordsTaxesSettlementsBeforeWrite");
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	Query.Execute();
	
EndProcedure

#EndRegion

#EndIf