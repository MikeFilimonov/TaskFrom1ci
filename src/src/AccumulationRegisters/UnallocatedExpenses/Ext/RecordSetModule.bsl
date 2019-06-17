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
	LockItem = Block.Add("AccumulationRegister.UnallocatedExpenses.RecordSet");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.SetValue("Recorder", Filter.Recorder.Value);
	Block.Lock();
	
	If Not StructureTemporaryTables.Property("RegisterRecordsUnallocatedExpensesChange") OR
		StructureTemporaryTables.Property("RegisterRecordsUnallocatedExpensesChange") AND Not StructureTemporaryTables.RegisterRecordsUnallocatedExpensesChange Then
		
		// If the temporary table "RegisterRecordsUnallocatedExpensesChange" doesn't exist and doesn't
		// contain records about the set change then set is written for the first time and for set balance control was executed.
		// Current set state is placed in a
		// temporary table "RegisterRecordsUnallocatedExpensesBeforeWrite" to get at record new set change rather current.
		
		Query = New Query(
		"SELECT
		|	AccumulationRegisterUnassignedIncomesAndExpenditures.LineNumber AS LineNumber,
		|	AccumulationRegisterUnassignedIncomesAndExpenditures.Company AS Company,
		|	AccumulationRegisterUnassignedIncomesAndExpenditures.Document AS Document,
		|	AccumulationRegisterUnassignedIncomesAndExpenditures.Item AS Item,
		|	CASE
		|		WHEN AccumulationRegisterUnassignedIncomesAndExpenditures.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN AccumulationRegisterUnassignedIncomesAndExpenditures.AmountIncome
		|		ELSE -AccumulationRegisterUnassignedIncomesAndExpenditures.AmountIncome
		|	END AS AmountIncomeBeforeWrite,
		|	CASE
		|		WHEN AccumulationRegisterUnassignedIncomesAndExpenditures.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN AccumulationRegisterUnassignedIncomesAndExpenditures.AmountExpense
		|		ELSE -AccumulationRegisterUnassignedIncomesAndExpenditures.AmountExpense
		|	END AS AmountExpensesBeforeWrite
		|INTO RegisterRecordsUnallocatedExpensesBeforeWrite
		|FROM
		|	AccumulationRegister.UnallocatedExpenses AS AccumulationRegisterUnassignedIncomesAndExpenditures
		|WHERE
		|	AccumulationRegisterUnassignedIncomesAndExpenditures.Recorder = &Recorder
		|	AND &Replacing");
		
		Query.SetParameter("Recorder", Filter.Recorder.Value);
		Query.SetParameter("Replacing", Replacing);
				
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		
	Else
		
		// If the temporary table "RegisterRecordsUnallocatedExpensesChange" exists and
		// contains records about the set change then set is written not for the first time and for set balance control wasn't executed.
		// Current set state and current change state are placed in
		// a temporary table "RegisterRecordsUnallocatedExpensesBeforeWrite" to get at record new set change rather initial.
		
		Query = New Query(
		"SELECT
		|	RegisterRecordsUnallocatedExpensesChange.LineNumber AS LineNumber,
		|	RegisterRecordsUnallocatedExpensesChange.Company AS Company,
		|	RegisterRecordsUnallocatedExpensesChange.Document AS Document,
		|	RegisterRecordsUnallocatedExpensesChange.Item AS Item,
		|	RegisterRecordsUnallocatedExpensesChange.AmountIncomeBeforeWrite AS AmountIncomeBeforeWrite,
		|	RegisterRecordsUnallocatedExpensesChange.AmountExpensesBeforeWrite AS AmountExpensesBeforeWrite
		|INTO RegisterRecordsUnallocatedExpensesBeforeWrite
		|FROM
		|	RegisterRecordsUnallocatedExpensesChange AS RegisterRecordsUnallocatedExpensesChange
		|
		|UNION ALL
		|
		|SELECT
		|	AccumulationRegisterUnassignedIncomesAndExpenditures.LineNumber,
		|	AccumulationRegisterUnassignedIncomesAndExpenditures.Company,
		|	AccumulationRegisterUnassignedIncomesAndExpenditures.Document,
		|	AccumulationRegisterUnassignedIncomesAndExpenditures.Item,
		|	CASE
		|		WHEN AccumulationRegisterUnassignedIncomesAndExpenditures.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN AccumulationRegisterUnassignedIncomesAndExpenditures.AmountIncome
		|		ELSE -AccumulationRegisterUnassignedIncomesAndExpenditures.AmountIncome
		|	END,
		|	CASE
		|		WHEN AccumulationRegisterUnassignedIncomesAndExpenditures.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN AccumulationRegisterUnassignedIncomesAndExpenditures.AmountExpense
		|		ELSE -AccumulationRegisterUnassignedIncomesAndExpenditures.AmountExpense
		|	END
		|FROM
		|	AccumulationRegister.UnallocatedExpenses AS AccumulationRegisterUnassignedIncomesAndExpenditures
		|WHERE
		|	AccumulationRegisterUnassignedIncomesAndExpenditures.Recorder = &Recorder
		|	AND &Replacing");
		
		Query.SetParameter("Recorder", Filter.Recorder.Value);
		Query.SetParameter("Replacing", Replacing);
				
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		
	EndIf;
	
	// Temporary table
	// "RegisterRecordsUnallocatedExpensesChange" is destroyed info about its existence is Deleted.
	
	If StructureTemporaryTables.Property("RegisterRecordsUnallocatedExpensesChange") Then
		
		Query = New Query("DROP RegisterRecordsUnallocatedExpensesChange");
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		StructureTemporaryTables.Delete("RegisterRecordsUnallocatedExpensesChange");
	
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
	// accumulated changes and placed into temporary table "RegisterRecordsUnallocatedExpensesChange".
	
	Query = New Query(
	"SELECT
	|	MIN(RegisterRecordsUnallocatedExpensesChange.LineNumber) AS LineNumber,
	|	RegisterRecordsUnallocatedExpensesChange.Company AS Company,
	|	RegisterRecordsUnallocatedExpensesChange.Document AS Document,
	|	RegisterRecordsUnallocatedExpensesChange.Item AS Item,
	|	SUM(RegisterRecordsUnallocatedExpensesChange.AmountIncomeBeforeWrite) AS AmountIncomeBeforeWrite,
	|	SUM(RegisterRecordsUnallocatedExpensesChange.AmountIncomeUpdate) AS AmountIncomeUpdate,
	|	SUM(RegisterRecordsUnallocatedExpensesChange.AmountIncomeOnWrite) AS AmountIncomeOnWrite,
	|	SUM(RegisterRecordsUnallocatedExpensesChange.AmountExpensesBeforeWrite) AS AmountExpensesBeforeWrite,
	|	SUM(RegisterRecordsUnallocatedExpensesChange.AmountExpensesUpdate) AS AmountExpensesUpdate,
	|	SUM(RegisterRecordsUnallocatedExpensesChange.AmountExpensesOnWrite) AS AmountExpensesOnWrite
	|INTO RegisterRecordsUnallocatedExpensesChange
	|FROM
	|	(SELECT
	|		RegisterRecordsUnallocatedExpensesBeforeWrite.LineNumber AS LineNumber,
	|		RegisterRecordsUnallocatedExpensesBeforeWrite.Company AS Company,
	|		RegisterRecordsUnallocatedExpensesBeforeWrite.Document AS Document,
	|		RegisterRecordsUnallocatedExpensesBeforeWrite.Item AS Item,
	|		RegisterRecordsUnallocatedExpensesBeforeWrite.AmountIncomeBeforeWrite AS AmountIncomeBeforeWrite,
	|		RegisterRecordsUnallocatedExpensesBeforeWrite.AmountIncomeBeforeWrite AS AmountIncomeUpdate,
	|		0 AS AmountIncomeOnWrite,
	|		RegisterRecordsUnallocatedExpensesBeforeWrite.AmountExpensesBeforeWrite AS AmountExpensesBeforeWrite,
	|		RegisterRecordsUnallocatedExpensesBeforeWrite.AmountExpensesBeforeWrite AS AmountExpensesUpdate,
	|		0 AS AmountExpensesOnWrite
	|	FROM
	|		RegisterRecordsUnallocatedExpensesBeforeWrite AS RegisterRecordsUnallocatedExpensesBeforeWrite
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		RegisterRecordsUnallocatedExpensesOnWrite.LineNumber,
	|		RegisterRecordsUnallocatedExpensesOnWrite.Company,
	|		RegisterRecordsUnallocatedExpensesOnWrite.Document,
	|		RegisterRecordsUnallocatedExpensesOnWrite.Item,
	|		0,
	|		CASE
	|			WHEN RegisterRecordsUnallocatedExpensesOnWrite.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -RegisterRecordsUnallocatedExpensesOnWrite.AmountIncome
	|			ELSE RegisterRecordsUnallocatedExpensesOnWrite.AmountIncome
	|		END,
	|		RegisterRecordsUnallocatedExpensesOnWrite.AmountIncome,
	|		0,
	|		CASE
	|			WHEN RegisterRecordsUnallocatedExpensesOnWrite.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -RegisterRecordsUnallocatedExpensesOnWrite.AmountExpense
	|			ELSE RegisterRecordsUnallocatedExpensesOnWrite.AmountExpense
	|		END,
	|		RegisterRecordsUnallocatedExpensesOnWrite.AmountExpense
	|	FROM
	|		AccumulationRegister.UnallocatedExpenses AS RegisterRecordsUnallocatedExpensesOnWrite
	|	WHERE
	|		RegisterRecordsUnallocatedExpensesOnWrite.Recorder = &Recorder) AS RegisterRecordsUnallocatedExpensesChange
	|
	|GROUP BY
	|	RegisterRecordsUnallocatedExpensesChange.Company,
	|	RegisterRecordsUnallocatedExpensesChange.Document,
	|	RegisterRecordsUnallocatedExpensesChange.Item
	|
	|HAVING
	|	(SUM(RegisterRecordsUnallocatedExpensesChange.AmountIncomeUpdate) <> 0
	|		OR SUM(RegisterRecordsUnallocatedExpensesChange.AmountExpensesUpdate) <> 0)
	|
	|INDEX BY
	|	Company,
	|	Document,
	|	Item");
	
	Query.SetParameter("Recorder", Filter.Recorder.Value);
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	
	QueryResult = Query.Execute();
	
	QueryResultSelection = QueryResult.Select();
	QueryResultSelection.Next();
	
	// New changes were placed into temporary table "RegisterRecordsUnallocatedExpensesChange".
	// It is added info about its existence and availability by her change records.
	StructureTemporaryTables.Insert("RegisterRecordsUnallocatedExpensesChange", QueryResultSelection.Count > 0);
	
	// The "RegisterRecordsUnallocatedExpensesBeforeWrite" temporary table is deleted
	Query = New Query("DROP RegisterRecordsUnallocatedExpensesBeforeWrite");
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	Query.Execute();
	
EndProcedure

#EndRegion

#EndIf