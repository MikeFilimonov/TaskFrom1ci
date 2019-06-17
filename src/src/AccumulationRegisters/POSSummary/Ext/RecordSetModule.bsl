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
	LockItem = Block.Add("AccumulationRegister.POSSummary.RecordSet");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.SetValue("Recorder", Filter.Recorder.Value);
	Block.Lock();
	
	If Not StructureTemporaryTables.Property("RegisterRecordsPOSSummaryUpdate") OR
		StructureTemporaryTables.Property("RegisterRecordsPOSSummaryUpdate") AND Not StructureTemporaryTables.RegisterRecordsPOSSummaryUpdate Then
		
		// If the temporary table "RegisterRecordsPOSSummaryChange" doesn't exist and
		// doesn't contain records about the set change then set is written for the first time and for set balance control was executed.
		// Current set state is placed in a
		// temporary table "RegisterRecordsPOSSummaryBeforeWrite" to get at record new set change rather current.
		
		Query = New Query(
		"SELECT
		|	AccumulationRegisterPOSSummary.LineNumber AS LineNumber,
		|	AccumulationRegisterPOSSummary.Company AS Company,
		|	AccumulationRegisterPOSSummary.StructuralUnit AS StructuralUnit,
		|	AccumulationRegisterPOSSummary.Currency AS Currency,
		|	CASE
		|		WHEN AccumulationRegisterPOSSummary.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN AccumulationRegisterPOSSummary.Amount
		|		ELSE -AccumulationRegisterPOSSummary.Amount
		|	END AS SumBeforeWrite,
		|	CASE
		|		WHEN AccumulationRegisterPOSSummary.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN AccumulationRegisterPOSSummary.AmountCur
		|		ELSE -AccumulationRegisterPOSSummary.AmountCur
		|	END AS AmountCurBeforeWrite,
		|	CASE
		|		WHEN AccumulationRegisterPOSSummary.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN AccumulationRegisterPOSSummary.Cost
		|		ELSE -AccumulationRegisterPOSSummary.Cost
		|	END AS CostBeforeWrite
		|INTO RegisterRecordsPOSSummaryBeforeWrite
		|FROM
		|	AccumulationRegister.POSSummary AS AccumulationRegisterPOSSummary
		|WHERE
		|	AccumulationRegisterPOSSummary.Recorder = &Recorder
		|	AND &Replacing");
		
		Query.SetParameter("Recorder", Filter.Recorder.Value);
		Query.SetParameter("Replacing", Replacing);
				
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		
	Else
		
		// If the temporary table "RegisterRecordsPOSSummaryChange" exists and
		// contains records about the set change then set is written not for the first time and for set balance control wasn't executed.
		// Current set state and current change state are placed in
		// a temporary table "RegisterRecordsPOSSummaryBeforeWrite" to get at record new set change rather initial.
		
		Query = New Query(
		"SELECT
		|	RegisterRecordsPOSSummaryUpdate.LineNumber AS LineNumber,
		|	RegisterRecordsPOSSummaryUpdate.Company AS Company,
		|	RegisterRecordsPOSSummaryUpdate.StructuralUnit AS StructuralUnit,
		|	RegisterRecordsPOSSummaryUpdate.Currency AS Currency,
		|	RegisterRecordsPOSSummaryUpdate.SumBeforeWrite AS SumBeforeWrite,
		|	RegisterRecordsPOSSummaryUpdate.AmountCurBeforeWrite AS AmountCurBeforeWrite,
		|	RegisterRecordsPOSSummaryUpdate.CostBeforeWrite AS CostBeforeWrite
		|INTO RegisterRecordsPOSSummaryBeforeWrite
		|FROM
		|	RegisterRecordsPOSSummaryUpdate AS RegisterRecordsPOSSummaryUpdate
		|
		|UNION ALL
		|
		|SELECT
		|	AccumulationRegisterPOSSummary.LineNumber,
		|	AccumulationRegisterPOSSummary.Company,
		|	AccumulationRegisterPOSSummary.StructuralUnit,
		|	AccumulationRegisterPOSSummary.Currency,
		|	CASE
		|		WHEN AccumulationRegisterPOSSummary.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN AccumulationRegisterPOSSummary.Amount
		|		ELSE -AccumulationRegisterPOSSummary.Amount
		|	END,
		|	CASE
		|		WHEN AccumulationRegisterPOSSummary.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN AccumulationRegisterPOSSummary.AmountCur
		|		ELSE -AccumulationRegisterPOSSummary.AmountCur
		|	END,
		|	CASE
		|		WHEN AccumulationRegisterPOSSummary.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN AccumulationRegisterPOSSummary.Cost
		|		ELSE -AccumulationRegisterPOSSummary.Cost
		|	END
		|FROM
		|	AccumulationRegister.POSSummary AS AccumulationRegisterPOSSummary
		|WHERE
		|	AccumulationRegisterPOSSummary.Recorder = &Recorder
		|	AND &Replacing");
		
		Query.SetParameter("Recorder", Filter.Recorder.Value);
		Query.SetParameter("Replacing", Replacing);
				
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		
	EndIf;
	
	// Temporary table
	// "RegisterRecordsPOSSummaryChange" is destroyed info about its existence is Deleted.
	
	If StructureTemporaryTables.Property("RegisterRecordsPOSSummaryUpdate") Then
		
		Query = New Query("DROP RegisterRecordsPOSSummaryChange");
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		StructureTemporaryTables.Delete("RegisterRecordsPOSSummaryUpdate");
	
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
	// accumulated changes and placed into temporary table "RegisterRecordsPOSSummaryChange".
	
	Query = New Query(
	"SELECT
	|	MIN(RegisterRecordsPOSSummaryUpdate.LineNumber) AS LineNumber,
	|	RegisterRecordsPOSSummaryUpdate.Company AS Company,
	|	RegisterRecordsPOSSummaryUpdate.StructuralUnit AS StructuralUnit,
	|	RegisterRecordsPOSSummaryUpdate.Currency AS Currency,
	|	SUM(RegisterRecordsPOSSummaryUpdate.SumBeforeWrite) AS SumBeforeWrite,
	|	SUM(RegisterRecordsPOSSummaryUpdate.AmountChange) AS AmountChange,
	|	SUM(RegisterRecordsPOSSummaryUpdate.AmountOnWrite) AS AmountOnWrite,
	|	SUM(RegisterRecordsPOSSummaryUpdate.AmountCurBeforeWrite) AS AmountCurBeforeWrite,
	|	SUM(RegisterRecordsPOSSummaryUpdate.SumCurChange) AS SumCurChange,
	|	SUM(RegisterRecordsPOSSummaryUpdate.SumCurOnWrite) AS SumCurOnWrite,
	|	SUM(RegisterRecordsPOSSummaryUpdate.CostBeforeWrite) AS CostBeforeWrite,
	|	SUM(RegisterRecordsPOSSummaryUpdate.CostUpdate) AS CostUpdate,
	|	SUM(RegisterRecordsPOSSummaryUpdate.CostOnWrite) AS CostOnWrite
	|
	|INTO RegisterRecordsPOSSummaryUpdate
	|FROM
	|	(SELECT
	|		RegisterRecordsPOSSummaryBeforeWrite.LineNumber AS LineNumber,
	|		RegisterRecordsPOSSummaryBeforeWrite.Company AS Company,
	|		RegisterRecordsPOSSummaryBeforeWrite.StructuralUnit AS StructuralUnit,
	|		RegisterRecordsPOSSummaryBeforeWrite.Currency AS Currency,
	|		RegisterRecordsPOSSummaryBeforeWrite.SumBeforeWrite AS SumBeforeWrite,
	|		RegisterRecordsPOSSummaryBeforeWrite.SumBeforeWrite AS AmountChange,
	|		0 AS AmountOnWrite,
	|		RegisterRecordsPOSSummaryBeforeWrite.AmountCurBeforeWrite AS AmountCurBeforeWrite,
	|		RegisterRecordsPOSSummaryBeforeWrite.AmountCurBeforeWrite AS SumCurChange,
	|		0 AS SumCurOnWrite,
	|		RegisterRecordsPOSSummaryBeforeWrite.CostBeforeWrite AS CostBeforeWrite,
	|		RegisterRecordsPOSSummaryBeforeWrite.CostBeforeWrite AS CostUpdate,
	|		0 AS CostOnWrite
	|
	|	FROM
	|		RegisterRecordsPOSSummaryBeforeWrite AS RegisterRecordsPOSSummaryBeforeWrite
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		RegisterRecordsPOSSummaryOnWrite.LineNumber,
	|		RegisterRecordsPOSSummaryOnWrite.Company,
	|		RegisterRecordsPOSSummaryOnWrite.StructuralUnit,
	|		RegisterRecordsPOSSummaryOnWrite.Currency,
	|		0,
	|		CASE
	|			WHEN RegisterRecordsPOSSummaryOnWrite.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -RegisterRecordsPOSSummaryOnWrite.Amount
	|			ELSE RegisterRecordsPOSSummaryOnWrite.Amount
	|		END,
	|		RegisterRecordsPOSSummaryOnWrite.Amount,
	|		0,
	|		CASE
	|			WHEN RegisterRecordsPOSSummaryOnWrite.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -RegisterRecordsPOSSummaryOnWrite.AmountCur
	|			ELSE RegisterRecordsPOSSummaryOnWrite.AmountCur
	|		END,
	|		RegisterRecordsPOSSummaryOnWrite.AmountCur,
	|		0,
	|		CASE
	|			WHEN RegisterRecordsPOSSummaryOnWrite.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -RegisterRecordsPOSSummaryOnWrite.Cost
	|			ELSE RegisterRecordsPOSSummaryOnWrite.Cost
	|		END,
	|		RegisterRecordsPOSSummaryOnWrite.Cost
	|
	|	FROM
	|		AccumulationRegister.POSSummary AS RegisterRecordsPOSSummaryOnWrite
	|	WHERE
	|		RegisterRecordsPOSSummaryOnWrite.Recorder = &Recorder) AS RegisterRecordsPOSSummaryUpdate
	|
	|GROUP BY
	|	RegisterRecordsPOSSummaryUpdate.Company,
	|	RegisterRecordsPOSSummaryUpdate.StructuralUnit,
	|	RegisterRecordsPOSSummaryUpdate.Currency
	|
	|HAVING
	|	(SUM(RegisterRecordsPOSSummaryUpdate.AmountChange) <> 0
	|		OR SUM(RegisterRecordsPOSSummaryUpdate.SumCurChange) <> 0
	|		OR SUM(RegisterRecordsPOSSummaryUpdate.CostUpdate) <> 0)
	|
	|INDEX BY
	|	Company,
	|	StructuralUnit,
	|	Currency");
	
	Query.SetParameter("Recorder", Filter.Recorder.Value);
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	
	QueryResult = Query.Execute();
	
	QueryResultSelection = QueryResult.Select();
	QueryResultSelection.Next();
	
	// New changes were placed into temporary table "RegisterRecordsPOSSummaryChange".
	// It is added info about its existence and availability by her change records.
	StructureTemporaryTables.Insert("RegisterRecordsPOSSummaryUpdate", QueryResultSelection.Count > 0);
	
	// The "RegisterRecordsPOSSummaryBeforeWrite" temporary table is deleted
	Query = New Query("DROP RegisterRecordsPOSSummaryBeforeWrite");
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	Query.Execute();
	
EndProcedure

#EndRegion

#EndIf