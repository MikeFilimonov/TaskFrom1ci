#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

Procedure BeforeWrite(Cancel, Replacing)
	
	If DataExchange.Load
		OR Not AdditionalProperties.Property("ForPosting")
		OR Not AdditionalProperties.ForPosting.Property("StructureTemporaryTables") Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// Setting the exclusive lock of current registrar record set.
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.GoodsShippedNotInvoiced.RecordSet");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.SetValue("Recorder", Filter.Recorder.Value);
	Block.Lock();
	
	If Not StructureTemporaryTables.Property("RegisterRecordsGoodsShippedNotInvoicedChange")
		OR StructureTemporaryTables.Property("RegisterRecordsGoodsShippedNotInvoicedChange")
			AND Not StructureTemporaryTables.RegisterRecordsGoodsShippedNotInvoicedChange Then
		
		// If the temporary table "RegisterRecordsGoodsShippedNotInvoicedChange" doesn't exist and
		// doesn't contain records about the set change then set is written for the first time and for set balance control was executed.
		// Current set state is placed in a
		// temporary table "RegisterRecordsGoodsShippedNotInvoicedBeforeWrite" to get at record new set change rather current.
		
		Query = New Query(
		"SELECT
		|	GoodsShippedNotInvoiced.LineNumber AS LineNumber,
		|	GoodsShippedNotInvoiced.Company AS Company,
		|	GoodsShippedNotInvoiced.GoodsIssue AS GoodsIssue,
		|	GoodsShippedNotInvoiced.Counterparty AS Counterparty,
		|	GoodsShippedNotInvoiced.Contract AS Contract,
		|	GoodsShippedNotInvoiced.Products AS Products,
		|	GoodsShippedNotInvoiced.Characteristic AS Characteristic,
		|	GoodsShippedNotInvoiced.Batch AS Batch,
		|	GoodsShippedNotInvoiced.SalesOrder AS SalesOrder,
		|	CASE
		|		WHEN GoodsShippedNotInvoiced.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN GoodsShippedNotInvoiced.Quantity
		|		ELSE -GoodsShippedNotInvoiced.Quantity
		|	END AS QuantityBeforeWrite
		|INTO RegisterRecordsGoodsShippedNotInvoicedBeforeWrite
		|FROM
		|	AccumulationRegister.GoodsShippedNotInvoiced AS GoodsShippedNotInvoiced
		|WHERE
		|	GoodsShippedNotInvoiced.Recorder = &Recorder
		|	AND &Replacing");
		
		Query.SetParameter("Recorder", Filter.Recorder.Value);
		Query.SetParameter("Replacing", Replacing);
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		
	Else
		
		// If the temporary table "RegisterRecordsGoodsShippedNotInvoicedChange" exists and
		// contains records about the set change then set is written not for the first time and for set balance control wasn't executed.
		// Current set state and current change state are placed in
		// a temporary table "RegisterRecordsGoodsShippedNotInvoicedBeforeWrite" to get at record new set change rather initial.
		
		Query = New Query(
		"SELECT
		|	RegisterRecordsGoodsShippedNotInvoicedChange.LineNumber AS LineNumber,
		|	RegisterRecordsGoodsShippedNotInvoicedChange.Company AS Company,
		|	RegisterRecordsGoodsShippedNotInvoicedChange.GoodsIssue AS GoodsIssue,
		|	RegisterRecordsGoodsShippedNotInvoicedChange.Counterparty AS Counterparty,
		|	RegisterRecordsGoodsShippedNotInvoicedChange.Contract AS Contract,
		|	RegisterRecordsGoodsShippedNotInvoicedChange.Products AS Products,
		|	RegisterRecordsGoodsShippedNotInvoicedChange.Characteristic AS Characteristic,
		|	RegisterRecordsGoodsShippedNotInvoicedChange.Batch AS Batch,
		|	RegisterRecordsGoodsShippedNotInvoicedChange.SalesOrder AS SalesOrder,
		|	RegisterRecordsGoodsShippedNotInvoicedChange.QuantityBeforeWrite AS QuantityBeforeWrite
		|INTO RegisterRecordsGoodsShippedNotInvoicedBeforeWrite
		|FROM
		|	RegisterRecordsGoodsShippedNotInvoicedChange AS RegisterRecordsGoodsShippedNotInvoicedChange
		|
		|UNION ALL
		|
		|SELECT
		|	GoodsShippedNotInvoiced.LineNumber,
		|	GoodsShippedNotInvoiced.Company,
		|	GoodsShippedNotInvoiced.GoodsIssue,
		|	GoodsShippedNotInvoiced.Counterparty,
		|	GoodsShippedNotInvoiced.Contract,
		|	GoodsShippedNotInvoiced.Products,
		|	GoodsShippedNotInvoiced.Characteristic,
		|	GoodsShippedNotInvoiced.Batch,
		|	GoodsShippedNotInvoiced.SalesOrder,
		|	CASE
		|		WHEN GoodsShippedNotInvoiced.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN GoodsShippedNotInvoiced.Quantity
		|		ELSE -GoodsShippedNotInvoiced.Quantity
		|	END
		|FROM
		|	AccumulationRegister.GoodsShippedNotInvoiced AS GoodsShippedNotInvoiced
		|WHERE
		|	GoodsShippedNotInvoiced.Recorder = &Recorder
		|	AND &Replacing");
		
		Query.SetParameter("Recorder", Filter.Recorder.Value);
		Query.SetParameter("Replacing", Replacing);
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		
	EndIf;
	
	// Temporary table
	// "RegisterRecordsGoodsShippedNotInvoicedChange" is destroyed info about its existence is Deleted.
	
	If StructureTemporaryTables.Property("RegisterRecordsGoodsShippedNotInvoicedChange") Then
		
		Query = New Query("DROP RegisterRecordsGoodsShippedNotInvoicedChange");
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		StructureTemporaryTables.Delete("RegisterRecordsGoodsShippedNotInvoicedChange");
	
	EndIf;
	
EndProcedure

Procedure OnWrite(Cancel, Replacing)
	
	If DataExchange.Load
		OR Not AdditionalProperties.Property("ForPosting")
		OR Not AdditionalProperties.ForPosting.Property("StructureTemporaryTables") Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// New set change is calculated relatively current with accounting
	// accumulated changes and placed into temporary table "RegisterRecordsGoodsShippedNotInvoicedChange".
	
	Query = New Query(
	"SELECT
	|	MIN(RegisterRecordsGoodsShippedNotInvoicedChange.LineNumber) AS LineNumber,
	|	RegisterRecordsGoodsShippedNotInvoicedChange.Company AS Company,
	|	RegisterRecordsGoodsShippedNotInvoicedChange.GoodsIssue AS GoodsIssue,
	|	RegisterRecordsGoodsShippedNotInvoicedChange.Counterparty AS Counterparty,
	|	RegisterRecordsGoodsShippedNotInvoicedChange.Contract AS Contract,
	|	RegisterRecordsGoodsShippedNotInvoicedChange.Products AS Products,
	|	RegisterRecordsGoodsShippedNotInvoicedChange.Characteristic AS Characteristic,
	|	RegisterRecordsGoodsShippedNotInvoicedChange.Batch AS Batch,
	|	RegisterRecordsGoodsShippedNotInvoicedChange.SalesOrder AS SalesOrder,
	|	SUM(RegisterRecordsGoodsShippedNotInvoicedChange.QuantityBeforeWrite) AS QuantityBeforeWrite,
	|	SUM(RegisterRecordsGoodsShippedNotInvoicedChange.QuantityChange) AS QuantityChange,
	|	SUM(RegisterRecordsGoodsShippedNotInvoicedChange.QuantityOnWrite) AS QuantityOnWrite
	|INTO RegisterRecordsGoodsShippedNotInvoicedChange
	|FROM
	|	(SELECT
	|		RegisterRecordsGoodsShippedNotInvoicedBeforeWrite.LineNumber AS LineNumber,
	|		RegisterRecordsGoodsShippedNotInvoicedBeforeWrite.Company AS Company,
	|		RegisterRecordsGoodsShippedNotInvoicedBeforeWrite.GoodsIssue AS GoodsIssue,
	|		RegisterRecordsGoodsShippedNotInvoicedBeforeWrite.Counterparty AS Counterparty,
	|		RegisterRecordsGoodsShippedNotInvoicedBeforeWrite.Contract AS Contract,
	|		RegisterRecordsGoodsShippedNotInvoicedBeforeWrite.Products AS Products,
	|		RegisterRecordsGoodsShippedNotInvoicedBeforeWrite.Characteristic AS Characteristic,
	|		RegisterRecordsGoodsShippedNotInvoicedBeforeWrite.Batch AS Batch,
	|		RegisterRecordsGoodsShippedNotInvoicedBeforeWrite.SalesOrder AS SalesOrder,
	|		RegisterRecordsGoodsShippedNotInvoicedBeforeWrite.QuantityBeforeWrite AS QuantityBeforeWrite,
	|		RegisterRecordsGoodsShippedNotInvoicedBeforeWrite.QuantityBeforeWrite AS QuantityChange,
	|		0 AS QuantityOnWrite
	|	FROM
	|		RegisterRecordsGoodsShippedNotInvoicedBeforeWrite AS RegisterRecordsGoodsShippedNotInvoicedBeforeWrite
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		RegisterRecordsGoodsShippedNotInvoicedOnWrite.LineNumber,
	|		RegisterRecordsGoodsShippedNotInvoicedOnWrite.Company,
	|		RegisterRecordsGoodsShippedNotInvoicedOnWrite.GoodsIssue,
	|		RegisterRecordsGoodsShippedNotInvoicedOnWrite.Counterparty,
	|		RegisterRecordsGoodsShippedNotInvoicedOnWrite.Contract,
	|		RegisterRecordsGoodsShippedNotInvoicedOnWrite.Products,
	|		RegisterRecordsGoodsShippedNotInvoicedOnWrite.Characteristic,
	|		RegisterRecordsGoodsShippedNotInvoicedOnWrite.Batch,
	|		RegisterRecordsGoodsShippedNotInvoicedOnWrite.SalesOrder,
	|		0,
	|		CASE
	|			WHEN RegisterRecordsGoodsShippedNotInvoicedOnWrite.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -RegisterRecordsGoodsShippedNotInvoicedOnWrite.Quantity
	|			ELSE RegisterRecordsGoodsShippedNotInvoicedOnWrite.Quantity
	|		END,
	|		RegisterRecordsGoodsShippedNotInvoicedOnWrite.Quantity
	|	FROM
	|		AccumulationRegister.GoodsShippedNotInvoiced AS RegisterRecordsGoodsShippedNotInvoicedOnWrite
	|	WHERE
	|		RegisterRecordsGoodsShippedNotInvoicedOnWrite.Recorder = &Recorder) AS RegisterRecordsGoodsShippedNotInvoicedChange
	|
	|GROUP BY
	|	RegisterRecordsGoodsShippedNotInvoicedChange.Company,
	|	RegisterRecordsGoodsShippedNotInvoicedChange.GoodsIssue,
	|	RegisterRecordsGoodsShippedNotInvoicedChange.Counterparty,
	|	RegisterRecordsGoodsShippedNotInvoicedChange.Contract,
	|	RegisterRecordsGoodsShippedNotInvoicedChange.Products,
	|	RegisterRecordsGoodsShippedNotInvoicedChange.Characteristic,
	|	RegisterRecordsGoodsShippedNotInvoicedChange.Batch,
	|	RegisterRecordsGoodsShippedNotInvoicedChange.SalesOrder
	|
	|HAVING
	|	SUM(RegisterRecordsGoodsShippedNotInvoicedChange.QuantityChange) <> 0
	|
	|INDEX BY
	|	Company,
	|	GoodsIssue,
	|	Counterparty,
	|	Contract,
	|	Products,
	|	Characteristic,
	|	Batch,
	|	SalesOrder");
	
	Query.SetParameter("Recorder", Filter.Recorder.Value);
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	
	QueryResult = Query.Execute();
	
	QueryResultSelection = QueryResult.Select();
	QueryResultSelection.Next();
	
	// New changes were placed into temporary table "RegisterRecordsGoodsShippedNotInvoicedChange".
	// It is added info about its existence and availability by her change records.
	StructureTemporaryTables.Insert("RegisterRecordsGoodsShippedNotInvoicedChange", QueryResultSelection.Count > 0);
	
	// The "RegisterRecordsGoodsShippedNotInvoicedBeforeWrite" temporary table is deleted
	Query = New Query("DROP RegisterRecordsGoodsShippedNotInvoicedBeforeWrite");
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	Query.Execute();
	
EndProcedure

#EndRegion

#EndIf