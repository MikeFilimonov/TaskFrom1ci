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
	LockItem = Block.Add("AccumulationRegister.Backorders.RecordSet");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.SetValue("Recorder", Filter.Recorder.Value);
	Block.Lock();
	
	If Not StructureTemporaryTables.Property("RegisterRecordsBackordersChange") OR
		StructureTemporaryTables.Property("RegisterRecordsBackordersChange") AND Not StructureTemporaryTables.RegisterRecordsBackordersChange Then
		
		// If the temporary table "RegisterRecordsBackordersChange" doesn't exist and doesn't
		// contain records about the set change then set is written for the first time and for set balance control was executed.
		// Current set state is placed in a
		// temporary table "RegisterRecordsBackordersBeforeWrite" to get at record new set change rather current.
		
		Query = New Query(
		"SELECT
		|	Backorders.LineNumber AS LineNumber,
		|	Backorders.Company AS Company,
		|	Backorders.SalesOrder AS SalesOrder,
		|	Backorders.Products AS Products,
		|	Backorders.Characteristic AS Characteristic,
		|	Backorders.SupplySource AS SupplySource,
		|	CASE
		|		WHEN Backorders.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN Backorders.Quantity
		|		ELSE -Backorders.Quantity
		|	END AS QuantityBeforeWrite
		|INTO RegisterRecordsBackordersBeforeWrite
		|FROM
		|	AccumulationRegister.Backorders AS Backorders
		|WHERE
		|	Backorders.Recorder = &Recorder
		|	AND &Replacing");
		
		Query.SetParameter("Recorder", Filter.Recorder.Value);
		Query.SetParameter("Replacing", Replacing);
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		
	Else
		
		// If the temporary table "RegisterRecordsBackordersChange" exists and
		// contains records about the set change then set is written not for the first time and for set balance control wasn't executed.
		// Current set state and current change state are placed in
		// a temporary table "RegisterRecordsBackordersBeforeWrite" to get at record new set change rather initial.
		
		Query = New Query(
		"SELECT
		|	RegisterRecordsBackordersChange.LineNumber AS LineNumber,
		|	RegisterRecordsBackordersChange.Company AS Company,
		|	RegisterRecordsBackordersChange.SalesOrder AS SalesOrder,
		|	RegisterRecordsBackordersChange.Products AS Products,
		|	RegisterRecordsBackordersChange.Characteristic AS Characteristic,
		|	RegisterRecordsBackordersChange.SupplySource AS SupplySource,
		|	RegisterRecordsBackordersChange.QuantityBeforeWrite AS QuantityBeforeWrite
		|INTO RegisterRecordsBackordersBeforeWrite
		|FROM
		|	RegisterRecordsBackordersChange AS RegisterRecordsBackordersChange
		|
		|UNION ALL
		|
		|SELECT
		|	Backorders.LineNumber,
		|	Backorders.Company,
		|	Backorders.SalesOrder,
		|	Backorders.Products,
		|	Backorders.Characteristic,
		|	Backorders.SupplySource,
		|	CASE
		|		WHEN Backorders.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN Backorders.Quantity
		|		ELSE -Backorders.Quantity
		|	END
		|FROM
		|	AccumulationRegister.Backorders AS Backorders
		|WHERE
		|	Backorders.Recorder = &Recorder
		|	AND &Replacing");
		
		Query.SetParameter("Recorder", Filter.Recorder.Value);
		Query.SetParameter("Replacing", Replacing);
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		
	EndIf;
	
	// Temporary table
	// "RegisterRecordsBackordersChange" is destroyed info about its existence is Deleted.
	
	If StructureTemporaryTables.Property("RegisterRecordsBackordersChange") Then
		
		Query = New Query("DROP RegisterRecordsBackordersChange");
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		StructureTemporaryTables.Delete("RegisterRecordsBackordersChange");
	
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
	// accumulated changes and placed into temporary table "RegisterRecordsBackordersChange".
	
	Query = New Query(
	"SELECT
	|	MIN(RegisterRecordsBackordersChange.LineNumber) AS LineNumber,
	|	RegisterRecordsBackordersChange.Company AS Company,
	|	RegisterRecordsBackordersChange.SalesOrder AS SalesOrder,
	|	RegisterRecordsBackordersChange.Products AS Products,
	|	RegisterRecordsBackordersChange.Characteristic AS Characteristic,
	|	RegisterRecordsBackordersChange.SupplySource AS SupplySource,
	|	SUM(RegisterRecordsBackordersChange.QuantityBeforeWrite) AS QuantityBeforeWrite,
	|	SUM(RegisterRecordsBackordersChange.QuantityChange) AS QuantityChange,
	|	SUM(RegisterRecordsBackordersChange.QuantityOnWrite) AS QuantityOnWrite
	|INTO RegisterRecordsBackordersChange
	|FROM
	|	(SELECT
	|		RegisterRecordsBackordersBeforeWrite.LineNumber AS LineNumber,
	|		RegisterRecordsBackordersBeforeWrite.Company AS Company,
	|		RegisterRecordsBackordersBeforeWrite.SalesOrder AS SalesOrder,
	|		RegisterRecordsBackordersBeforeWrite.Products AS Products,
	|		RegisterRecordsBackordersBeforeWrite.Characteristic AS Characteristic,
	|		RegisterRecordsBackordersBeforeWrite.SupplySource AS SupplySource,
	|		RegisterRecordsBackordersBeforeWrite.QuantityBeforeWrite AS QuantityBeforeWrite,
	|		RegisterRecordsBackordersBeforeWrite.QuantityBeforeWrite AS QuantityChange,
	|		0 AS QuantityOnWrite
	|	FROM
	|		RegisterRecordsBackordersBeforeWrite AS RegisterRecordsBackordersBeforeWrite
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		RegisterRecordsBackordersOnWrite.LineNumber,
	|		RegisterRecordsBackordersOnWrite.Company,
	|		RegisterRecordsBackordersOnWrite.SalesOrder,
	|		RegisterRecordsBackordersOnWrite.Products,
	|		RegisterRecordsBackordersOnWrite.Characteristic,
	|		RegisterRecordsBackordersOnWrite.SupplySource,
	|		0,
	|		CASE
	|			WHEN RegisterRecordsBackordersOnWrite.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -RegisterRecordsBackordersOnWrite.Quantity
	|			ELSE RegisterRecordsBackordersOnWrite.Quantity
	|		END,
	|		RegisterRecordsBackordersOnWrite.Quantity
	|	FROM
	|		AccumulationRegister.Backorders AS RegisterRecordsBackordersOnWrite
	|	WHERE
	|		RegisterRecordsBackordersOnWrite.Recorder = &Recorder) AS RegisterRecordsBackordersChange
	|
	|GROUP BY
	|	RegisterRecordsBackordersChange.Company,
	|	RegisterRecordsBackordersChange.SalesOrder,
	|	RegisterRecordsBackordersChange.Products,
	|	RegisterRecordsBackordersChange.Characteristic,
	|	RegisterRecordsBackordersChange.SupplySource
	|
	|HAVING
	|	SUM(RegisterRecordsBackordersChange.QuantityChange) <> 0
	|
	|INDEX BY
	|	Company,
	|	SalesOrder,
	|	Products,
	|	Characteristic,
	|	SupplySource");
	
	Query.SetParameter("Recorder", Filter.Recorder.Value);
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	
	QueryResult = Query.Execute();
	
	QueryResultSelection = QueryResult.Select();
	QueryResultSelection.Next();
	
	// New changes were placed into temporary table "RegisterRecordsBackordersChange".
	// It is added info about its existence and availability by her change records.
	StructureTemporaryTables.Insert("RegisterRecordsBackordersChange", QueryResultSelection.Count > 0);
	
	// The "RegisterRecordsBackordersBeforeWrite" temporary table is deleted
	Query = New Query("DROP RegisterRecordsBackordersBeforeWrite");
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	Query.Execute();
	
EndProcedure

#EndRegion

#EndIf