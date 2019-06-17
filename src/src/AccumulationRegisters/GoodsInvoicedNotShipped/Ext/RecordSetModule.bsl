#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure BeforeWrite(Cancel, Replacing)
	
	If DataExchange.Load
		OR Not AdditionalProperties.Property("ForPosting")
		OR Not AdditionalProperties.ForPosting.Property("StructureTemporaryTables") Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// Setting the exclusive lock of current registrar record set.
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.GoodsInvoicedNotShipped.RecordSet");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.SetValue("Recorder", Filter.Recorder.Value);
	Block.Lock();
	
	If Not StructureTemporaryTables.Property("RegisterRecordsGoodsInvoicedNotShippedChange")
		OR StructureTemporaryTables.Property("RegisterRecordsGoodsInvoicedNotShippedChange")
			AND Not StructureTemporaryTables.RegisterRecordsGoodsInvoicedNotShippedChange Then
		
		// If the temporary table "RegisterRecordsGoodsInvoicedNotShippedChange" doesn't exist and
		// doesn't contain records about the set change then set is written for the first time and for set balance control was executed.
		// Current set state is placed in a
		// temporary table "RegisterRecordsGoodsInvoicedNotShippedBeforeWrite" to get at record new set change rather current.
		
		Query = New Query(
		"SELECT
		|	GoodsInvoicedNotShipped.LineNumber AS LineNumber,
		|	GoodsInvoicedNotShipped.Company AS Company,
		|	GoodsInvoicedNotShipped.SalesInvoice AS SalesInvoice,
		|	GoodsInvoicedNotShipped.Counterparty AS Counterparty,
		|	GoodsInvoicedNotShipped.Contract AS Contract,
		|	GoodsInvoicedNotShipped.SalesOrder AS SalesOrder,
		|	GoodsInvoicedNotShipped.Products AS Products,
		|	GoodsInvoicedNotShipped.Characteristic AS Characteristic,
		|	GoodsInvoicedNotShipped.Batch AS Batch,
		|	GoodsInvoicedNotShipped.VATRate AS VATRate,
		|	GoodsInvoicedNotShipped.Department AS Department,
		|	GoodsInvoicedNotShipped.Responsible AS Responsible,
		|	CASE
		|		WHEN GoodsInvoicedNotShipped.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN GoodsInvoicedNotShipped.Quantity
		|		ELSE -GoodsInvoicedNotShipped.Quantity
		|	END AS QuantityBeforeWrite
		|INTO RegisterRecordsGoodsInvoicedNotShippedBeforeWrite
		|FROM
		|	AccumulationRegister.GoodsInvoicedNotShipped AS GoodsInvoicedNotShipped
		|WHERE
		|	GoodsInvoicedNotShipped.Recorder = &Recorder
		|	AND &Replacing");
		
		Query.SetParameter("Recorder", Filter.Recorder.Value);
		Query.SetParameter("Replacing", Replacing);
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		
	Else
		
		// If the temporary table "RegisterRecordsGoodsInvoicedNotShippedChange" exists and
		// contains records about the set change then set is written not for the first time and for set balance control wasn't executed.
		// Current set state and current change state are placed in
		// a temporary table "RegisterRecordsGoodsInvoicedNotShippedBeforeWrite" to get at record new set change rather initial.
		
		Query = New Query(
		"SELECT
		|	RegisterRecordsGoodsInvoicedNotShippedChange.LineNumber AS LineNumber,
		|	RegisterRecordsGoodsInvoicedNotShippedChange.Company AS Company,
		|	RegisterRecordsGoodsInvoicedNotShippedChange.SalesInvoice AS SalesInvoice,
		|	RegisterRecordsGoodsInvoicedNotShippedChange.Counterparty AS Counterparty,
		|	RegisterRecordsGoodsInvoicedNotShippedChange.Contract AS Contract,
		|	RegisterRecordsGoodsInvoicedNotShippedChange.SalesOrder AS SalesOrder,
		|	RegisterRecordsGoodsInvoicedNotShippedChange.Products AS Products,
		|	RegisterRecordsGoodsInvoicedNotShippedChange.Characteristic AS Characteristic,
		|	RegisterRecordsGoodsInvoicedNotShippedChange.Batch AS Batch,
		|	RegisterRecordsGoodsInvoicedNotShippedChange.VATRate AS VATRate,
		|	RegisterRecordsGoodsInvoicedNotShippedChange.Department AS Department,
		|	RegisterRecordsGoodsInvoicedNotShippedChange.Responsible AS Responsible,
		|	RegisterRecordsGoodsInvoicedNotShippedChange.QuantityBeforeWrite AS QuantityBeforeWrite
		|INTO RegisterRecordsGoodsInvoicedNotShippedBeforeWrite
		|FROM
		|	RegisterRecordsGoodsInvoicedNotShippedChange AS RegisterRecordsGoodsInvoicedNotShippedChange
		|
		|UNION ALL
		|
		|SELECT
		|	GoodsInvoicedNotShipped.LineNumber,
		|	GoodsInvoicedNotShipped.Company,
		|	GoodsInvoicedNotShipped.SalesInvoice,
		|	GoodsInvoicedNotShipped.Counterparty,
		|	GoodsInvoicedNotShipped.Contract,
		|	GoodsInvoicedNotShipped.SalesOrder,
		|	GoodsInvoicedNotShipped.Products,
		|	GoodsInvoicedNotShipped.Characteristic,
		|	GoodsInvoicedNotShipped.Batch,
		|	GoodsInvoicedNotShipped.VATRate,
		|	GoodsInvoicedNotShipped.Department,
		|	GoodsInvoicedNotShipped.Responsible,
		|	CASE
		|		WHEN GoodsInvoicedNotShipped.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN GoodsInvoicedNotShipped.Quantity
		|		ELSE -GoodsInvoicedNotShipped.Quantity
		|	END
		|FROM
		|	AccumulationRegister.GoodsInvoicedNotShipped AS GoodsInvoicedNotShipped
		|WHERE
		|	GoodsInvoicedNotShipped.Recorder = &Recorder
		|	AND &Replacing");
		
		Query.SetParameter("Recorder", Filter.Recorder.Value);
		Query.SetParameter("Replacing", Replacing);
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		
	EndIf;
	
	// Temporary table
	// "RegisterRecordsGoodsInvoicedNotShippedChange" is destroyed info about its existence is Deleted.
	
	If StructureTemporaryTables.Property("RegisterRecordsGoodsInvoicedNotShippedChange") Then
		
		Query = New Query("DROP RegisterRecordsGoodsInvoicedNotShippedChange");
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		StructureTemporaryTables.Delete("RegisterRecordsGoodsInvoicedNotShippedChange");
	
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
	// accumulated changes and placed into temporary table "RegisterRecordsGoodsInvoicedNotShippedChange".
	
	Query = New Query(
	"SELECT
	|	MIN(RegisterRecordsGoodsInvoicedNotShippedChange.LineNumber) AS LineNumber,
	|	RegisterRecordsGoodsInvoicedNotShippedChange.Company AS Company,
	|	RegisterRecordsGoodsInvoicedNotShippedChange.SalesInvoice AS SalesInvoice,
	|	RegisterRecordsGoodsInvoicedNotShippedChange.Counterparty AS Counterparty,
	|	RegisterRecordsGoodsInvoicedNotShippedChange.Contract AS Contract,
	|	RegisterRecordsGoodsInvoicedNotShippedChange.SalesOrder AS SalesOrder,
	|	RegisterRecordsGoodsInvoicedNotShippedChange.Products AS Products,
	|	RegisterRecordsGoodsInvoicedNotShippedChange.Characteristic AS Characteristic,
	|	RegisterRecordsGoodsInvoicedNotShippedChange.Batch AS Batch,
	|	RegisterRecordsGoodsInvoicedNotShippedChange.VATRate AS VATRate,
	|	RegisterRecordsGoodsInvoicedNotShippedChange.Department AS Department,
	|	RegisterRecordsGoodsInvoicedNotShippedChange.Responsible AS Responsible,
	|	SUM(RegisterRecordsGoodsInvoicedNotShippedChange.QuantityBeforeWrite) AS QuantityBeforeWrite,
	|	SUM(RegisterRecordsGoodsInvoicedNotShippedChange.QuantityChange) AS QuantityChange,
	|	SUM(RegisterRecordsGoodsInvoicedNotShippedChange.QuantityOnWrite) AS QuantityOnWrite
	|INTO RegisterRecordsGoodsInvoicedNotShippedChange
	|FROM
	|	(SELECT
	|		RegisterRecordsGoodsInvoicedNotShippedBeforeWrite.LineNumber AS LineNumber,
	|		RegisterRecordsGoodsInvoicedNotShippedBeforeWrite.Company AS Company,
	|		RegisterRecordsGoodsInvoicedNotShippedBeforeWrite.SalesInvoice AS SalesInvoice,
	|		RegisterRecordsGoodsInvoicedNotShippedBeforeWrite.Counterparty AS Counterparty,
	|		RegisterRecordsGoodsInvoicedNotShippedBeforeWrite.Contract AS Contract,
	|		RegisterRecordsGoodsInvoicedNotShippedBeforeWrite.SalesOrder AS SalesOrder,
	|		RegisterRecordsGoodsInvoicedNotShippedBeforeWrite.Products AS Products,
	|		RegisterRecordsGoodsInvoicedNotShippedBeforeWrite.Characteristic AS Characteristic,
	|		RegisterRecordsGoodsInvoicedNotShippedBeforeWrite.Batch AS Batch,
	|		RegisterRecordsGoodsInvoicedNotShippedBeforeWrite.VATRate AS VATRate,
	|		RegisterRecordsGoodsInvoicedNotShippedBeforeWrite.Department AS Department,
	|		RegisterRecordsGoodsInvoicedNotShippedBeforeWrite.Responsible AS Responsible,
	|		RegisterRecordsGoodsInvoicedNotShippedBeforeWrite.QuantityBeforeWrite AS QuantityBeforeWrite,
	|		RegisterRecordsGoodsInvoicedNotShippedBeforeWrite.QuantityBeforeWrite AS QuantityChange,
	|		0 AS QuantityOnWrite
	|	FROM
	|		RegisterRecordsGoodsInvoicedNotShippedBeforeWrite AS RegisterRecordsGoodsInvoicedNotShippedBeforeWrite
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		RegisterRecordsGoodsInvoicedNotShippedOnWrite.LineNumber,
	|		RegisterRecordsGoodsInvoicedNotShippedOnWrite.Company,
	|		RegisterRecordsGoodsInvoicedNotShippedOnWrite.SalesInvoice,
	|		RegisterRecordsGoodsInvoicedNotShippedOnWrite.Counterparty,
	|		RegisterRecordsGoodsInvoicedNotShippedOnWrite.Contract,
	|		RegisterRecordsGoodsInvoicedNotShippedOnWrite.SalesOrder,
	|		RegisterRecordsGoodsInvoicedNotShippedOnWrite.Products,
	|		RegisterRecordsGoodsInvoicedNotShippedOnWrite.Characteristic,
	|		RegisterRecordsGoodsInvoicedNotShippedOnWrite.Batch,
	|		RegisterRecordsGoodsInvoicedNotShippedOnWrite.VATRate,
	|		RegisterRecordsGoodsInvoicedNotShippedOnWrite.Department,
	|		RegisterRecordsGoodsInvoicedNotShippedOnWrite.Responsible,
	|		0,
	|		CASE
	|			WHEN RegisterRecordsGoodsInvoicedNotShippedOnWrite.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -RegisterRecordsGoodsInvoicedNotShippedOnWrite.Quantity
	|			ELSE RegisterRecordsGoodsInvoicedNotShippedOnWrite.Quantity
	|		END,
	|		RegisterRecordsGoodsInvoicedNotShippedOnWrite.Quantity
	|	FROM
	|		AccumulationRegister.GoodsInvoicedNotShipped AS RegisterRecordsGoodsInvoicedNotShippedOnWrite
	|	WHERE
	|		RegisterRecordsGoodsInvoicedNotShippedOnWrite.Recorder = &Recorder) AS RegisterRecordsGoodsInvoicedNotShippedChange
	|
	|GROUP BY
	|	RegisterRecordsGoodsInvoicedNotShippedChange.Company,
	|	RegisterRecordsGoodsInvoicedNotShippedChange.SalesInvoice,
	|	RegisterRecordsGoodsInvoicedNotShippedChange.Counterparty,
	|	RegisterRecordsGoodsInvoicedNotShippedChange.Contract,
	|	RegisterRecordsGoodsInvoicedNotShippedChange.SalesOrder,
	|	RegisterRecordsGoodsInvoicedNotShippedChange.Products,
	|	RegisterRecordsGoodsInvoicedNotShippedChange.Characteristic,
	|	RegisterRecordsGoodsInvoicedNotShippedChange.Batch,
	|	RegisterRecordsGoodsInvoicedNotShippedChange.VATRate,
	|	RegisterRecordsGoodsInvoicedNotShippedChange.Department,
	|	RegisterRecordsGoodsInvoicedNotShippedChange.Responsible
	|
	|HAVING
	|	SUM(RegisterRecordsGoodsInvoicedNotShippedChange.QuantityChange) <> 0
	|
	|INDEX BY
	|	Company,
	|	SalesInvoice,
	|	Counterparty,
	|	Contract,
	|	Products,
	|	Characteristic,
	|	Batch,
	|	VATRate,
	|	Department,
	|	Responsible,
	|	SalesOrder");
	
	Query.SetParameter("Recorder", Filter.Recorder.Value);
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	
	QueryResult = Query.Execute();
	
	QueryResultSelection = QueryResult.Select();
	QueryResultSelection.Next();
	
	// New changes were placed into temporary table "RegisterRecordsGoodsInvoicedNotShippedChange".
	// It is added info about its existence and availability by her change records.
	StructureTemporaryTables.Insert("RegisterRecordsGoodsInvoicedNotShippedChange", QueryResultSelection.Count > 0);
	
	// The "RegisterRecordsGoodsInvoicedNotShippedBeforeWrite" temporary table is deleted
	Query = New Query("DROP RegisterRecordsGoodsInvoicedNotShippedBeforeWrite");
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	Query.Execute();
	
EndProcedure

#EndRegion

#EndIf