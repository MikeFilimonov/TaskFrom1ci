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
	LockItem = Block.Add("AccumulationRegister.AdvanceHolders.RecordSet");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.SetValue("Recorder", Filter.Recorder.Value);
	Block.Lock();
	
	If Not StructureTemporaryTables.Property("RegisterRecordsAdvanceHoldersChange")
	    OR StructureTemporaryTables.Property("RegisterRecordsAdvanceHoldersChange")
	   AND Not StructureTemporaryTables.RegisterRecordsAdvanceHoldersChange Then
		
		// If the temporary table "RegisterRecordsAdvanceHoldersChange" doesn't exist and doesn't
		// contain records about the set change then set is written for the first time and for set balance control was executed.
		// Current set state is placed in a
		// temporary table "RegisterRecordsAdvanceHoldersBeforeWrite" to get at record new set change rather current.
		
		Query = New Query(
		"SELECT
		|	RegisterAdvanceHolderss.LineNumber AS LineNumber,
		|	RegisterAdvanceHolderss.Company AS Company,
		|	RegisterAdvanceHolderss.Employee AS Employee,
		|	RegisterAdvanceHolderss.Currency AS Currency,
		|	RegisterAdvanceHolderss.Document AS Document,
		|	CASE
		|		WHEN RegisterAdvanceHolderss.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN RegisterAdvanceHolderss.Amount
		|		ELSE -RegisterAdvanceHolderss.Amount
		|	END AS SumBeforeWrite,
		|	CASE
		|		WHEN RegisterAdvanceHolderss.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN RegisterAdvanceHolderss.AmountCur
		|		ELSE -RegisterAdvanceHolderss.AmountCur
		|	END AS AmountCurBeforeWrite
		|INTO RegisterRecordsAdvanceHoldersBeforeWrite
		|FROM
		|	AccumulationRegister.AdvanceHolders AS RegisterAdvanceHolderss
		|WHERE
		|	RegisterAdvanceHolderss.Recorder = &Recorder
		|	AND &Replacing");
		
		Query.SetParameter("Recorder", Filter.Recorder.Value);
		Query.SetParameter("Replacing", Replacing);
				
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		
	Else
		
		// If the temporary table "RegisterRecordsAdvanceHoldersChange" exists and
		// contains records about the set change then set is written not for the first time and for set balance control wasn't executed.
		// Current set state and current change state are placed in
		// a temporary table "RegisterRecordsAdvanceHoldersBeforeWrite" to get at record new set change rather initial.
		
		Query = New Query(
		"SELECT
		|	RegisterRecordsAdvanceHoldersChange.LineNumber AS LineNumber,
		|	RegisterRecordsAdvanceHoldersChange.Company AS Company,
		|	RegisterRecordsAdvanceHoldersChange.Employee AS Employee,
		|	RegisterRecordsAdvanceHoldersChange.Currency AS Currency,
		|	RegisterRecordsAdvanceHoldersChange.Document AS Document,
		|	RegisterRecordsAdvanceHoldersChange.SumBeforeWrite AS SumBeforeWrite,
		|	RegisterRecordsAdvanceHoldersChange.AmountCurBeforeWrite AS AmountCurBeforeWrite
		|INTO RegisterRecordsAdvanceHoldersBeforeWrite
		|FROM
		|	RegisterRecordsAdvanceHoldersChange AS RegisterRecordsAdvanceHoldersChange
		|
		|UNION ALL
		|
		|SELECT
		|	RegisterAdvanceHolderss.LineNumber,
		|	RegisterAdvanceHolderss.Company,
		|	RegisterAdvanceHolderss.Employee,
		|	RegisterAdvanceHolderss.Currency,
		|	RegisterAdvanceHolderss.Document,
		|	CASE
		|		WHEN RegisterAdvanceHolderss.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN RegisterAdvanceHolderss.Amount
		|		ELSE -RegisterAdvanceHolderss.Amount
		|	END,
		|	CASE
		|		WHEN RegisterAdvanceHolderss.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN RegisterAdvanceHolderss.AmountCur
		|		ELSE -RegisterAdvanceHolderss.AmountCur
		|	END
		|FROM
		|	AccumulationRegister.AdvanceHolders AS RegisterAdvanceHolderss
		|WHERE
		|	RegisterAdvanceHolderss.Recorder = &Recorder
		|	AND &Replacing");
		
		Query.SetParameter("Recorder", Filter.Recorder.Value);
		Query.SetParameter("Replacing", Replacing);
				
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		
	EndIf;
	
	// Temporary table
	// "RegisterRecordsAdvanceHoldersChange" is destroyed info about its existence is Deleted.
	
	If StructureTemporaryTables.Property("RegisterRecordsAdvanceHoldersChange") Then
		
		Query = New Query("DROP RegisterRecordsAdvanceHoldersChange");
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		StructureTemporaryTables.Delete("RegisterRecordsAdvanceHoldersChange");
	
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
	// accumulated changes and placed into temporary table "RegisterRecordsAdvanceHoldersChange".
	
	Query = New Query(
	"SELECT
	|	MIN(RegisterRecordsAdvanceHoldersChange.LineNumber) AS LineNumber,
	|	RegisterRecordsAdvanceHoldersChange.Company AS Company,
	|	RegisterRecordsAdvanceHoldersChange.Employee AS Employee,
	|	RegisterRecordsAdvanceHoldersChange.Currency AS Currency,
	|	RegisterRecordsAdvanceHoldersChange.Document AS Document,
	|	SUM(RegisterRecordsAdvanceHoldersChange.SumBeforeWrite) AS SumBeforeWrite,
	|	SUM(RegisterRecordsAdvanceHoldersChange.AmountChange) AS AmountChange,
	|	SUM(RegisterRecordsAdvanceHoldersChange.AmountOnWrite) AS AmountOnWrite,
	|	SUM(RegisterRecordsAdvanceHoldersChange.AmountCurBeforeWrite) AS AmountCurBeforeWrite,
	|	SUM(RegisterRecordsAdvanceHoldersChange.SumCurChange) AS SumCurChange,
	|	SUM(RegisterRecordsAdvanceHoldersChange.SumCurOnWrite) AS SumCurOnWrite
	|INTO RegisterRecordsAdvanceHoldersChange
	|FROM
	|	(SELECT
	|		RegisterRecordsAdvanceHoldersBeforeWrite.LineNumber AS LineNumber,
	|		RegisterRecordsAdvanceHoldersBeforeWrite.Company AS Company,
	|		RegisterRecordsAdvanceHoldersBeforeWrite.Employee AS Employee,
	|		RegisterRecordsAdvanceHoldersBeforeWrite.Currency AS Currency,
	|		RegisterRecordsAdvanceHoldersBeforeWrite.Document AS Document,
	|		RegisterRecordsAdvanceHoldersBeforeWrite.SumBeforeWrite AS SumBeforeWrite,
	|		RegisterRecordsAdvanceHoldersBeforeWrite.SumBeforeWrite AS AmountChange,
	|		0 AS AmountOnWrite,
	|		RegisterRecordsAdvanceHoldersBeforeWrite.AmountCurBeforeWrite AS AmountCurBeforeWrite,
	|		RegisterRecordsAdvanceHoldersBeforeWrite.AmountCurBeforeWrite AS SumCurChange,
	|		0 AS SumCurOnWrite
	|	FROM
	|		RegisterRecordsAdvanceHoldersBeforeWrite AS RegisterRecordsAdvanceHoldersBeforeWrite
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		RegisterRecordsAdvanceHoldersOnWrite.LineNumber,
	|		RegisterRecordsAdvanceHoldersOnWrite.Company,
	|		RegisterRecordsAdvanceHoldersOnWrite.Employee,
	|		RegisterRecordsAdvanceHoldersOnWrite.Currency,
	|		RegisterRecordsAdvanceHoldersOnWrite.Document,
	|		0,
	|		CASE
	|			WHEN RegisterRecordsAdvanceHoldersOnWrite.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -RegisterRecordsAdvanceHoldersOnWrite.Amount
	|			ELSE RegisterRecordsAdvanceHoldersOnWrite.Amount
	|		END,
	|		RegisterRecordsAdvanceHoldersOnWrite.Amount,
	|		0,
	|		CASE
	|			WHEN RegisterRecordsAdvanceHoldersOnWrite.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -RegisterRecordsAdvanceHoldersOnWrite.AmountCur
	|			ELSE RegisterRecordsAdvanceHoldersOnWrite.AmountCur
	|		END,
	|		RegisterRecordsAdvanceHoldersOnWrite.AmountCur
	|	FROM
	|		AccumulationRegister.AdvanceHolders AS RegisterRecordsAdvanceHoldersOnWrite
	|	WHERE
	|		RegisterRecordsAdvanceHoldersOnWrite.Recorder = &Recorder) AS RegisterRecordsAdvanceHoldersChange
	|
	|GROUP BY
	|	RegisterRecordsAdvanceHoldersChange.Company,
	|	RegisterRecordsAdvanceHoldersChange.Employee,
	|	RegisterRecordsAdvanceHoldersChange.Currency,
	|	RegisterRecordsAdvanceHoldersChange.Document
	|
	|HAVING
	|	(SUM(RegisterRecordsAdvanceHoldersChange.AmountChange) <> 0
	|		OR SUM(RegisterRecordsAdvanceHoldersChange.SumCurChange) <> 0)
	|
	|INDEX BY
	|	Company,
	|	Employee,
	|	Currency,
	|	Document");
	
	Query.SetParameter("Recorder", Filter.Recorder.Value);
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	
	QueryResult = Query.Execute();
	
	QueryResultSelection = QueryResult.Select();
	QueryResultSelection.Next();
	
	// New changes were placed into temporary table "RegisterRecordsAdvanceHoldersChange".
	// It is added info about its existence and availability by her change records.
	StructureTemporaryTables.Insert("RegisterRecordsAdvanceHoldersChange", QueryResultSelection.Count > 0);
	
	// The "RegisterRecordsAdvanceHoldersBeforeWrite" temporary table is deleted
	Query = New Query("DROP RegisterRecordsAdvanceHoldersBeforeWrite");
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	Query.Execute();
	
EndProcedure

#EndRegion

#EndIf