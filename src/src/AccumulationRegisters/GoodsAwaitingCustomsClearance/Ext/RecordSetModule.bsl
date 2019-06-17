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
	LockItem = Block.Add("AccumulationRegister.GoodsAwaitingCustomsClearance.RecordSet");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.SetValue("Recorder", Filter.Recorder.Value);
	Block.Lock();
	
	If Not StructureTemporaryTables.Property("RegisterRecordsGoodsAwaitingCustomsClearanceChange")
		OR StructureTemporaryTables.Property("RegisterRecordsGoodsAwaitingCustomsClearanceChange")
			AND Not StructureTemporaryTables.RegisterRecordsGoodsAwaitingCustomsClearanceChange Then
		
		// If the temporary table "RegisterRecordsGoodsAwaitingCustomsClearanceChange" doesn't exist and
		// doesn't contain records about the set change then set is written for the first time and for set balance control was executed.
		// Current set state is placed in a
		// temporary table "RegisterRecordsGoodsAwaitingCustomsClearanceBeforeWrite" to get at record new set change rather current.
		
		Query = New Query(
		"SELECT
		|	GoodsAwaitingCustomsClearance.LineNumber AS LineNumber,
		|	GoodsAwaitingCustomsClearance.Company AS Company,
		|	GoodsAwaitingCustomsClearance.Counterparty AS Counterparty,
		|	GoodsAwaitingCustomsClearance.Contract AS Contract,
		|	GoodsAwaitingCustomsClearance.SupplierInvoice AS SupplierInvoice,
		|	GoodsAwaitingCustomsClearance.Products AS Products,
		|	GoodsAwaitingCustomsClearance.Characteristic AS Characteristic,
		|	GoodsAwaitingCustomsClearance.Batch AS Batch,
		|	CASE
		|		WHEN GoodsAwaitingCustomsClearance.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN GoodsAwaitingCustomsClearance.Quantity
		|		ELSE -GoodsAwaitingCustomsClearance.Quantity
		|	END AS QuantityBeforeWrite
		|INTO RegisterRecordsGoodsAwaitingCustomsClearanceBeforeWrite
		|FROM
		|	AccumulationRegister.GoodsAwaitingCustomsClearance AS GoodsAwaitingCustomsClearance
		|WHERE
		|	GoodsAwaitingCustomsClearance.Recorder = &Recorder
		|	AND &Replacing");
		
		Query.SetParameter("Recorder", Filter.Recorder.Value);
		Query.SetParameter("Replacing", Replacing);
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		
	Else
		
		// If the temporary table "RegisterRecordsGoodsAwaitingCustomsClearanceChange" exists and
		// contains records about the set change then set is written not for the first time and for set balance control wasn't executed.
		// Current set state and current change state are placed in
		// a temporary table "RegisterRecordsGoodsAwaitingCustomsClearanceBeforeWrite" to get at record new set change rather initial.
		
		Query = New Query(
		"SELECT
		|	RegisterRecordsGoodsAwaitingCustomsClearanceChange.LineNumber AS LineNumber,
		|	RegisterRecordsGoodsAwaitingCustomsClearanceChange.Company AS Company,
		|	RegisterRecordsGoodsAwaitingCustomsClearanceChange.Counterparty AS Counterparty,
		|	RegisterRecordsGoodsAwaitingCustomsClearanceChange.Contract AS Contract,
		|	RegisterRecordsGoodsAwaitingCustomsClearanceChange.SupplierInvoice AS SupplierInvoice,
		|	RegisterRecordsGoodsAwaitingCustomsClearanceChange.Products AS Products,
		|	RegisterRecordsGoodsAwaitingCustomsClearanceChange.Characteristic AS Characteristic,
		|	RegisterRecordsGoodsAwaitingCustomsClearanceChange.Batch AS Batch,
		|	RegisterRecordsGoodsAwaitingCustomsClearanceChange.QuantityBeforeWrite AS QuantityBeforeWrite
		|INTO RegisterRecordsGoodsAwaitingCustomsClearanceBeforeWrite
		|FROM
		|	RegisterRecordsGoodsAwaitingCustomsClearanceChange AS RegisterRecordsGoodsAwaitingCustomsClearanceChange
		|
		|UNION ALL
		|
		|SELECT
		|	GoodsAwaitingCustomsClearance.LineNumber,
		|	GoodsAwaitingCustomsClearance.Company,
		|	GoodsAwaitingCustomsClearance.Counterparty,
		|	GoodsAwaitingCustomsClearance.Contract,
		|	GoodsAwaitingCustomsClearance.SupplierInvoice,
		|	GoodsAwaitingCustomsClearance.Products,
		|	GoodsAwaitingCustomsClearance.Characteristic,
		|	GoodsAwaitingCustomsClearance.Batch,
		|	CASE
		|		WHEN GoodsAwaitingCustomsClearance.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN GoodsAwaitingCustomsClearance.Quantity
		|		ELSE -GoodsAwaitingCustomsClearance.Quantity
		|	END
		|FROM
		|	AccumulationRegister.GoodsAwaitingCustomsClearance AS GoodsAwaitingCustomsClearance
		|WHERE
		|	GoodsAwaitingCustomsClearance.Recorder = &Recorder
		|	AND &Replacing");
		
		Query.SetParameter("Recorder", Filter.Recorder.Value);
		Query.SetParameter("Replacing", Replacing);
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		
	EndIf;
	
	// Temporary table
	// "RegisterRecordsGoodsAwaitingCustomsClearanceChange" is destroyed info about its existence is Deleted.
	
	If StructureTemporaryTables.Property("RegisterRecordsGoodsAwaitingCustomsClearanceChange") Then
		
		Query = New Query("DROP RegisterRecordsGoodsAwaitingCustomsClearanceChange");
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		StructureTemporaryTables.Delete("RegisterRecordsGoodsAwaitingCustomsClearanceChange");
	
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
	// accumulated changes and placed into temporary table "RegisterRecordsGoodsAwaitingCustomsClearanceChange".
	
	Query = New Query(
	"SELECT
	|	MIN(RegisterRecordsGoodsAwaitingCustomsClearanceChange.LineNumber) AS LineNumber,
	|	RegisterRecordsGoodsAwaitingCustomsClearanceChange.Company AS Company,
	|	RegisterRecordsGoodsAwaitingCustomsClearanceChange.Counterparty AS Counterparty,
	|	RegisterRecordsGoodsAwaitingCustomsClearanceChange.Contract AS Contract,
	|	RegisterRecordsGoodsAwaitingCustomsClearanceChange.SupplierInvoice AS SupplierInvoice,
	|	RegisterRecordsGoodsAwaitingCustomsClearanceChange.Products AS Products,
	|	RegisterRecordsGoodsAwaitingCustomsClearanceChange.Characteristic AS Characteristic,
	|	RegisterRecordsGoodsAwaitingCustomsClearanceChange.Batch AS Batch,
	|	SUM(RegisterRecordsGoodsAwaitingCustomsClearanceChange.QuantityBeforeWrite) AS QuantityBeforeWrite,
	|	SUM(RegisterRecordsGoodsAwaitingCustomsClearanceChange.QuantityChange) AS QuantityChange,
	|	SUM(RegisterRecordsGoodsAwaitingCustomsClearanceChange.QuantityOnWrite) AS QuantityOnWrite
	|INTO RegisterRecordsGoodsAwaitingCustomsClearanceChange
	|FROM
	|	(SELECT
	|		RegisterRecordsGoodsAwaitingCustomsClearanceBeforeWrite.LineNumber AS LineNumber,
	|		RegisterRecordsGoodsAwaitingCustomsClearanceBeforeWrite.Company AS Company,
	|		RegisterRecordsGoodsAwaitingCustomsClearanceBeforeWrite.Counterparty AS Counterparty,
	|		RegisterRecordsGoodsAwaitingCustomsClearanceBeforeWrite.Contract AS Contract,
	|		RegisterRecordsGoodsAwaitingCustomsClearanceBeforeWrite.SupplierInvoice AS SupplierInvoice,
	|		RegisterRecordsGoodsAwaitingCustomsClearanceBeforeWrite.Products AS Products,
	|		RegisterRecordsGoodsAwaitingCustomsClearanceBeforeWrite.Characteristic AS Characteristic,
	|		RegisterRecordsGoodsAwaitingCustomsClearanceBeforeWrite.Batch AS Batch,
	|		RegisterRecordsGoodsAwaitingCustomsClearanceBeforeWrite.QuantityBeforeWrite AS QuantityBeforeWrite,
	|		RegisterRecordsGoodsAwaitingCustomsClearanceBeforeWrite.QuantityBeforeWrite AS QuantityChange,
	|		0 AS QuantityOnWrite
	|	FROM
	|		RegisterRecordsGoodsAwaitingCustomsClearanceBeforeWrite AS RegisterRecordsGoodsAwaitingCustomsClearanceBeforeWrite
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		RegisterRecordsGoodsAwaitingCustomsClearanceOnWrite.LineNumber,
	|		RegisterRecordsGoodsAwaitingCustomsClearanceOnWrite.Company,
	|		RegisterRecordsGoodsAwaitingCustomsClearanceOnWrite.Counterparty,
	|		RegisterRecordsGoodsAwaitingCustomsClearanceOnWrite.Contract,
	|		RegisterRecordsGoodsAwaitingCustomsClearanceOnWrite.SupplierInvoice,
	|		RegisterRecordsGoodsAwaitingCustomsClearanceOnWrite.Products,
	|		RegisterRecordsGoodsAwaitingCustomsClearanceOnWrite.Characteristic,
	|		RegisterRecordsGoodsAwaitingCustomsClearanceOnWrite.Batch,
	|		0,
	|		CASE
	|			WHEN RegisterRecordsGoodsAwaitingCustomsClearanceOnWrite.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -RegisterRecordsGoodsAwaitingCustomsClearanceOnWrite.Quantity
	|			ELSE RegisterRecordsGoodsAwaitingCustomsClearanceOnWrite.Quantity
	|		END,
	|		RegisterRecordsGoodsAwaitingCustomsClearanceOnWrite.Quantity
	|	FROM
	|		AccumulationRegister.GoodsAwaitingCustomsClearance AS RegisterRecordsGoodsAwaitingCustomsClearanceOnWrite
	|	WHERE
	|		RegisterRecordsGoodsAwaitingCustomsClearanceOnWrite.Recorder = &Recorder) AS RegisterRecordsGoodsAwaitingCustomsClearanceChange
	|
	|GROUP BY
	|	RegisterRecordsGoodsAwaitingCustomsClearanceChange.Company,
	|	RegisterRecordsGoodsAwaitingCustomsClearanceChange.Counterparty,
	|	RegisterRecordsGoodsAwaitingCustomsClearanceChange.Contract,
	|	RegisterRecordsGoodsAwaitingCustomsClearanceChange.SupplierInvoice,
	|	RegisterRecordsGoodsAwaitingCustomsClearanceChange.Products,
	|	RegisterRecordsGoodsAwaitingCustomsClearanceChange.Characteristic,
	|	RegisterRecordsGoodsAwaitingCustomsClearanceChange.Batch
	|
	|HAVING
	|	SUM(RegisterRecordsGoodsAwaitingCustomsClearanceChange.QuantityChange) <> 0
	|
	|INDEX BY
	|	Company,
	|	Counterparty,
	|	Contract,
	|	SupplierInvoice,
	|	Products,
	|	Characteristic,
	|	Batch");
	
	Query.SetParameter("Recorder", Filter.Recorder.Value);
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	
	QueryResult = Query.Execute();
	
	QueryResultSelection = QueryResult.Select();
	QueryResultSelection.Next();
	
	// New changes were placed into temporary table "RegisterRecordsGoodsAwaitingCustomsClearanceChange".
	// It is added info about its existence and availability by her change records.
	StructureTemporaryTables.Insert("RegisterRecordsGoodsAwaitingCustomsClearanceChange", QueryResultSelection.Count > 0);
	
	// The "RegisterRecordsGoodsAwaitingCustomsClearanceBeforeWrite" temporary table is deleted
	Query = New Query("DROP RegisterRecordsGoodsAwaitingCustomsClearanceBeforeWrite");
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	Query.Execute();
	
EndProcedure

#EndRegion

#EndIf