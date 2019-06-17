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
	LockItem = Block.Add("AccumulationRegister.Payroll.RecordSet");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.SetValue("Recorder", Filter.Recorder.Value);
	Block.Lock();
	
	If Not StructureTemporaryTables.Property("RegisterRecordsPayrollUpdate") OR
		StructureTemporaryTables.Property("RegisterRecordsPayrollUpdate") AND Not StructureTemporaryTables.RegisterRecordsPayrollUpdate Then
		
		// If the temporary table "RegisterRecordsPayrollChange" doesn't exist and doesn't
		// contain records about the set change then set is written for the first time and for set balance control was executed.
		// Current set state is placed in a
		// temporary table "RegisterRecordsPayrollBeforeWrite" to get at record new set change rather current.
		
		Query = New Query(
		"SELECT
		|	Payroll.LineNumber AS LineNumber,
		|	Payroll.Company AS Company,
		|	Payroll.StructuralUnit AS StructuralUnit,
		|	Payroll.Employee AS Employee,
		|	Payroll.Currency AS Currency,
		|	Payroll.RegistrationPeriod AS RegistrationPeriod,
		|	CASE
		|		WHEN Payroll.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN Payroll.Amount
		|		ELSE -Payroll.Amount
		|	END AS SumBeforeWrite,
		|	CASE
		|		WHEN Payroll.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN Payroll.AmountCur
		|		ELSE -Payroll.AmountCur
		|	END AS AmountCurBeforeWrite
		|INTO RegisterRecordsPayrollBeforeWrite
		|FROM
		|	AccumulationRegister.Payroll AS Payroll
		|WHERE
		|	Payroll.Recorder = &Recorder
		|	AND &Replacing");
		
		Query.SetParameter("Recorder", Filter.Recorder.Value);
		Query.SetParameter("Replacing", Replacing);
				
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		
	Else
		
		// If the temporary table "RegisterRecordsPayrollChange" exists and
		// contains records about the set change then set is written not for the first time and for set balance control wasn't executed.
		// Current set state and current change state are placed in
		// a temporary table "RegisterRecordsPayrollBeforeWrite" to get at record new set change rather initial.
		
		Query = New Query(
		"SELECT
		|	RegisterRecordsPayrollUpdate.LineNumber AS LineNumber,
		|	RegisterRecordsPayrollUpdate.Company AS Company,
		|	RegisterRecordsPayrollUpdate.StructuralUnit AS StructuralUnit,
		|	RegisterRecordsPayrollUpdate.Employee AS Employee,
		|	RegisterRecordsPayrollUpdate.Currency AS Currency,
		|	RegisterRecordsPayrollUpdate.RegistrationPeriod AS RegistrationPeriod,
		|	RegisterRecordsPayrollUpdate.SumBeforeWrite AS SumBeforeWrite,
		|	RegisterRecordsPayrollUpdate.AmountCurBeforeWrite AS AmountCurBeforeWrite
		|INTO RegisterRecordsPayrollBeforeWrite
		|FROM
		|	RegisterRecordsPayrollUpdate AS RegisterRecordsPayrollUpdate
		|
		|UNION ALL
		|
		|SELECT
		|	Payroll.LineNumber,
		|	Payroll.Company,
		|	Payroll.StructuralUnit,
		|	Payroll.Employee,
		|	Payroll.Currency,
		|	Payroll.RegistrationPeriod,
		|	CASE
		|		WHEN Payroll.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN Payroll.Amount
		|		ELSE -Payroll.Amount
		|	END,
		|	CASE
		|		WHEN Payroll.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN Payroll.AmountCur
		|		ELSE -Payroll.AmountCur
		|	END
		|FROM
		|	AccumulationRegister.Payroll AS Payroll
		|WHERE
		|	Payroll.Recorder = &Recorder
		|	AND &Replacing");
		
		Query.SetParameter("Recorder", Filter.Recorder.Value);
		Query.SetParameter("Replacing", Replacing);
				
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		
	EndIf;
	
	// Temporary table
	// "RegisterRecordsPayrollChange" is destroyed info about its existence is Deleted.
	
	If StructureTemporaryTables.Property("RegisterRecordsPayrollUpdate") Then
		
		Query = New Query("DROP RegisterRecordsPayrollChange");
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		StructureTemporaryTables.Delete("RegisterRecordsPayrollUpdate");
	
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
	// accumulated changes and placed into temporary table "RegisterRecordsPayrollChange".
	
	Query = New Query(
	"SELECT
	|	MIN(RegisterRecordsPayrollUpdate.LineNumber) AS LineNumber,
	|	RegisterRecordsPayrollUpdate.Company AS Company,
	|	RegisterRecordsPayrollUpdate.StructuralUnit AS StructuralUnit,
	|	RegisterRecordsPayrollUpdate.Employee AS Employee,
	|	RegisterRecordsPayrollUpdate.Currency AS Currency,
	|	RegisterRecordsPayrollUpdate.RegistrationPeriod AS RegistrationPeriod,
	|	SUM(RegisterRecordsPayrollUpdate.SumBeforeWrite) AS SumBeforeWrite,
	|	SUM(RegisterRecordsPayrollUpdate.AmountChange) AS AmountChange,
	|	SUM(RegisterRecordsPayrollUpdate.AmountOnWrite) AS AmountOnWrite,
	|	SUM(RegisterRecordsPayrollUpdate.AmountCurBeforeWrite) AS AmountCurBeforeWrite,
	|	SUM(RegisterRecordsPayrollUpdate.SumCurChange) AS SumCurChange,
	|	SUM(RegisterRecordsPayrollUpdate.SumCurOnWrite) AS SumCurOnWrite
	|INTO RegisterRecordsPayrollUpdate
	|FROM
	|	(SELECT
	|		RegisterRecordsPayrollBeforeWrite.LineNumber AS LineNumber,
	|		RegisterRecordsPayrollBeforeWrite.Company AS Company,
	|		RegisterRecordsPayrollBeforeWrite.StructuralUnit AS StructuralUnit,
	|		RegisterRecordsPayrollBeforeWrite.Employee AS Employee,
	|		RegisterRecordsPayrollBeforeWrite.Currency AS Currency,
	|		RegisterRecordsPayrollBeforeWrite.RegistrationPeriod AS RegistrationPeriod,
	|		RegisterRecordsPayrollBeforeWrite.SumBeforeWrite AS SumBeforeWrite,
	|		RegisterRecordsPayrollBeforeWrite.SumBeforeWrite AS AmountChange,
	|		0 AS AmountOnWrite,
	|		RegisterRecordsPayrollBeforeWrite.AmountCurBeforeWrite AS AmountCurBeforeWrite,
	|		RegisterRecordsPayrollBeforeWrite.AmountCurBeforeWrite AS SumCurChange,
	|		0 AS SumCurOnWrite
	|	FROM
	|		RegisterRecordsPayrollBeforeWrite AS RegisterRecordsPayrollBeforeWrite
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		RegisterRecordsPayrollOnWrite.LineNumber,
	|		RegisterRecordsPayrollOnWrite.Company,
	|		RegisterRecordsPayrollOnWrite.StructuralUnit,
	|		RegisterRecordsPayrollOnWrite.Employee,
	|		RegisterRecordsPayrollOnWrite.Currency,
	|		RegisterRecordsPayrollOnWrite.RegistrationPeriod,
	|		0,
	|		CASE
	|			WHEN RegisterRecordsPayrollOnWrite.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -RegisterRecordsPayrollOnWrite.Amount
	|			ELSE RegisterRecordsPayrollOnWrite.Amount
	|		END,
	|		RegisterRecordsPayrollOnWrite.Amount,
	|		0,
	|		CASE
	|			WHEN RegisterRecordsPayrollOnWrite.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -RegisterRecordsPayrollOnWrite.AmountCur
	|			ELSE RegisterRecordsPayrollOnWrite.AmountCur
	|		END,
	|		RegisterRecordsPayrollOnWrite.AmountCur
	|	FROM
	|		AccumulationRegister.Payroll AS RegisterRecordsPayrollOnWrite
	|	WHERE
	|		RegisterRecordsPayrollOnWrite.Recorder = &Recorder) AS RegisterRecordsPayrollUpdate
	|
	|GROUP BY
	|	RegisterRecordsPayrollUpdate.Company,
	|	RegisterRecordsPayrollUpdate.StructuralUnit,
	|	RegisterRecordsPayrollUpdate.Employee,
	|	RegisterRecordsPayrollUpdate.Currency,
	|	RegisterRecordsPayrollUpdate.RegistrationPeriod
	|
	|HAVING
	|	(SUM(RegisterRecordsPayrollUpdate.AmountChange) <> 0
	|		OR SUM(RegisterRecordsPayrollUpdate.SumCurChange) <> 0)
	|
	|INDEX BY
	|	Company,
	|	StructuralUnit,
	|	Employee,
	|	Currency,
	|	RegistrationPeriod");
	
	Query.SetParameter("Recorder", Filter.Recorder.Value);
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	
	QueryResult = Query.Execute();
	
	QueryResultSelection = QueryResult.Select();
	QueryResultSelection.Next();
	
	// New changes were placed into temporary table "RegisterRecordsPayrollChange".
	// It is added info about its existence and availability by her change records.
	StructureTemporaryTables.Insert("RegisterRecordsPayrollUpdate", QueryResultSelection.Count > 0);
	
	// The "RegisterRecordsPayrollBeforeWrite" temporary table is deleted
	Query = New Query("DROP RegisterRecordsPayrollBeforeWrite");
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	Query.Execute();
	
EndProcedure

#EndRegion

#EndIf