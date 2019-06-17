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
	LockItem = Block.Add("AccumulationRegister.GoodsReceivedNotInvoiced.RecordSet");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.SetValue("Recorder", Filter.Recorder.Value);
	Block.Lock();
	
	If Not StructureTemporaryTables.Property("RegisterRecordsGoodsReceivedNotInvoicedChange")
		OR StructureTemporaryTables.Property("RegisterRecordsGoodsReceivedNotInvoicedChange")
			AND Not StructureTemporaryTables.RegisterRecordsGoodsReceivedNotInvoicedChange Then
		
		// If the temporary table "RegisterRecordsGoodsReceivedNotInvoicedChange" doesn't exist and
		// doesn't contain records about the set change then set is written for the first time and for set balance control was executed.
		// Current set state is placed in a
		// temporary table "RegisterRecordsGoodsReceivedNotInvoicedBeforeWrite" to get at record new set change rather current.
		
		Query = New Query(
		"SELECT
		|	GoodsReceivedNotInvoiced.LineNumber AS LineNumber,
		|	GoodsReceivedNotInvoiced.Company AS Company,
		|	GoodsReceivedNotInvoiced.GoodsReceipt AS GoodsReceipt,
		|	GoodsReceivedNotInvoiced.Counterparty AS Counterparty,
		|	GoodsReceivedNotInvoiced.Contract AS Contract,
		|	GoodsReceivedNotInvoiced.Products AS Products,
		|	GoodsReceivedNotInvoiced.Characteristic AS Characteristic,
		|	GoodsReceivedNotInvoiced.Batch AS Batch,
		|	GoodsReceivedNotInvoiced.PurchaseOrder AS PurchaseOrder,
		|	CASE
		|		WHEN GoodsReceivedNotInvoiced.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN GoodsReceivedNotInvoiced.Quantity
		|		ELSE -GoodsReceivedNotInvoiced.Quantity
		|	END AS QuantityBeforeWrite
		|INTO RegisterRecordsGoodsReceivedNotInvoicedBeforeWrite
		|FROM
		|	AccumulationRegister.GoodsReceivedNotInvoiced AS GoodsReceivedNotInvoiced
		|WHERE
		|	GoodsReceivedNotInvoiced.Recorder = &Recorder
		|	AND &Replacing");
		
		Query.SetParameter("Recorder", Filter.Recorder.Value);
		Query.SetParameter("Replacing", Replacing);
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		
	Else
		
		// If the temporary table "RegisterRecordsGoodsReceivedNotInvoicedChange" exists and
		// contains records about the set change then set is written not for the first time and for set balance control wasn't executed.
		// Current set state and current change state are placed in
		// a temporary table "RegisterRecordsGoodsReceivedNotInvoicedBeforeWrite" to get at record new set change rather initial.
		
		Query = New Query(
		"SELECT
		|	RegisterRecordsGoodsReceivedNotInvoicedChange.LineNumber AS LineNumber,
		|	RegisterRecordsGoodsReceivedNotInvoicedChange.Company AS Company,
		|	RegisterRecordsGoodsReceivedNotInvoicedChange.GoodsReceipt AS GoodsReceipt,
		|	RegisterRecordsGoodsReceivedNotInvoicedChange.Counterparty AS Counterparty,
		|	RegisterRecordsGoodsReceivedNotInvoicedChange.Contract AS Contract,
		|	RegisterRecordsGoodsReceivedNotInvoicedChange.Products AS Products,
		|	RegisterRecordsGoodsReceivedNotInvoicedChange.Characteristic AS Characteristic,
		|	RegisterRecordsGoodsReceivedNotInvoicedChange.Batch AS Batch,
		|	RegisterRecordsGoodsReceivedNotInvoicedChange.PurchaseOrder AS PurchaseOrder,
		|	RegisterRecordsGoodsReceivedNotInvoicedChange.QuantityBeforeWrite AS QuantityBeforeWrite
		|INTO RegisterRecordsGoodsReceivedNotInvoicedBeforeWrite
		|FROM
		|	RegisterRecordsGoodsReceivedNotInvoicedChange AS RegisterRecordsGoodsReceivedNotInvoicedChange
		|
		|UNION ALL
		|
		|SELECT
		|	GoodsReceivedNotInvoiced.LineNumber,
		|	GoodsReceivedNotInvoiced.Company,
		|	GoodsReceivedNotInvoiced.GoodsReceipt,
		|	GoodsReceivedNotInvoiced.Counterparty,
		|	GoodsReceivedNotInvoiced.Contract,
		|	GoodsReceivedNotInvoiced.Products,
		|	GoodsReceivedNotInvoiced.Characteristic,
		|	GoodsReceivedNotInvoiced.Batch,
		|	GoodsReceivedNotInvoiced.PurchaseOrder,
		|	CASE
		|		WHEN GoodsReceivedNotInvoiced.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN GoodsReceivedNotInvoiced.Quantity
		|		ELSE -GoodsReceivedNotInvoiced.Quantity
		|	END
		|FROM
		|	AccumulationRegister.GoodsReceivedNotInvoiced AS GoodsReceivedNotInvoiced
		|WHERE
		|	GoodsReceivedNotInvoiced.Recorder = &Recorder
		|	AND &Replacing");
		
		Query.SetParameter("Recorder", Filter.Recorder.Value);
		Query.SetParameter("Replacing", Replacing);
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		
	EndIf;
	
	// Temporary table
	// "RegisterRecordsGoodsReceivedNotInvoicedChange" is destroyed info about its existence is Deleted.
	
	If StructureTemporaryTables.Property("RegisterRecordsGoodsReceivedNotInvoicedChange") Then
		
		Query = New Query("DROP RegisterRecordsGoodsReceivedNotInvoicedChange");
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		StructureTemporaryTables.Delete("RegisterRecordsGoodsReceivedNotInvoicedChange");
	
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
	// accumulated changes and placed into temporary table "RegisterRecordsGoodsReceivedNotInvoicedChange".
	
	Query = New Query(
	"SELECT
	|	MIN(RegisterRecordsGoodsReceivedNotInvoicedChange.LineNumber) AS LineNumber,
	|	RegisterRecordsGoodsReceivedNotInvoicedChange.Company AS Company,
	|	RegisterRecordsGoodsReceivedNotInvoicedChange.GoodsReceipt AS GoodsReceipt,
	|	RegisterRecordsGoodsReceivedNotInvoicedChange.Counterparty AS Counterparty,
	|	RegisterRecordsGoodsReceivedNotInvoicedChange.Contract AS Contract,
	|	RegisterRecordsGoodsReceivedNotInvoicedChange.Products AS Products,
	|	RegisterRecordsGoodsReceivedNotInvoicedChange.Characteristic AS Characteristic,
	|	RegisterRecordsGoodsReceivedNotInvoicedChange.Batch AS Batch,
	|	RegisterRecordsGoodsReceivedNotInvoicedChange.PurchaseOrder AS PurchaseOrder,
	|	SUM(RegisterRecordsGoodsReceivedNotInvoicedChange.QuantityBeforeWrite) AS QuantityBeforeWrite,
	|	SUM(RegisterRecordsGoodsReceivedNotInvoicedChange.QuantityChange) AS QuantityChange,
	|	SUM(RegisterRecordsGoodsReceivedNotInvoicedChange.QuantityOnWrite) AS QuantityOnWrite
	|INTO RegisterRecordsGoodsReceivedNotInvoicedChange
	|FROM
	|	(SELECT
	|		RegisterRecordsGoodsReceivedNotInvoicedBeforeWrite.LineNumber AS LineNumber,
	|		RegisterRecordsGoodsReceivedNotInvoicedBeforeWrite.Company AS Company,
	|		RegisterRecordsGoodsReceivedNotInvoicedBeforeWrite.GoodsReceipt AS GoodsReceipt,
	|		RegisterRecordsGoodsReceivedNotInvoicedBeforeWrite.Counterparty AS Counterparty,
	|		RegisterRecordsGoodsReceivedNotInvoicedBeforeWrite.Contract AS Contract,
	|		RegisterRecordsGoodsReceivedNotInvoicedBeforeWrite.Products AS Products,
	|		RegisterRecordsGoodsReceivedNotInvoicedBeforeWrite.Characteristic AS Characteristic,
	|		RegisterRecordsGoodsReceivedNotInvoicedBeforeWrite.Batch AS Batch,
	|		RegisterRecordsGoodsReceivedNotInvoicedBeforeWrite.PurchaseOrder AS PurchaseOrder,
	|		RegisterRecordsGoodsReceivedNotInvoicedBeforeWrite.QuantityBeforeWrite AS QuantityBeforeWrite,
	|		RegisterRecordsGoodsReceivedNotInvoicedBeforeWrite.QuantityBeforeWrite AS QuantityChange,
	|		0 AS QuantityOnWrite
	|	FROM
	|		RegisterRecordsGoodsReceivedNotInvoicedBeforeWrite AS RegisterRecordsGoodsReceivedNotInvoicedBeforeWrite
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		RegisterRecordsGoodsReceivedNotInvoicedOnWrite.LineNumber,
	|		RegisterRecordsGoodsReceivedNotInvoicedOnWrite.Company,
	|		RegisterRecordsGoodsReceivedNotInvoicedOnWrite.GoodsReceipt,
	|		RegisterRecordsGoodsReceivedNotInvoicedOnWrite.Counterparty,
	|		RegisterRecordsGoodsReceivedNotInvoicedOnWrite.Contract,
	|		RegisterRecordsGoodsReceivedNotInvoicedOnWrite.Products,
	|		RegisterRecordsGoodsReceivedNotInvoicedOnWrite.Characteristic,
	|		RegisterRecordsGoodsReceivedNotInvoicedOnWrite.Batch,
	|		RegisterRecordsGoodsReceivedNotInvoicedOnWrite.PurchaseOrder,
	|		0,
	|		CASE
	|			WHEN RegisterRecordsGoodsReceivedNotInvoicedOnWrite.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -RegisterRecordsGoodsReceivedNotInvoicedOnWrite.Quantity
	|			ELSE RegisterRecordsGoodsReceivedNotInvoicedOnWrite.Quantity
	|		END,
	|		RegisterRecordsGoodsReceivedNotInvoicedOnWrite.Quantity
	|	FROM
	|		AccumulationRegister.GoodsReceivedNotInvoiced AS RegisterRecordsGoodsReceivedNotInvoicedOnWrite
	|	WHERE
	|		RegisterRecordsGoodsReceivedNotInvoicedOnWrite.Recorder = &Recorder) AS RegisterRecordsGoodsReceivedNotInvoicedChange
	|
	|GROUP BY
	|	RegisterRecordsGoodsReceivedNotInvoicedChange.Company,
	|	RegisterRecordsGoodsReceivedNotInvoicedChange.GoodsReceipt,
	|	RegisterRecordsGoodsReceivedNotInvoicedChange.Counterparty,
	|	RegisterRecordsGoodsReceivedNotInvoicedChange.Contract,
	|	RegisterRecordsGoodsReceivedNotInvoicedChange.Products,
	|	RegisterRecordsGoodsReceivedNotInvoicedChange.Characteristic,
	|	RegisterRecordsGoodsReceivedNotInvoicedChange.Batch,
	|	RegisterRecordsGoodsReceivedNotInvoicedChange.PurchaseOrder
	|
	|HAVING
	|	SUM(RegisterRecordsGoodsReceivedNotInvoicedChange.QuantityChange) <> 0
	|
	|INDEX BY
	|	Company,
	|	GoodsReceipt,
	|	Counterparty,
	|	Contract,
	|	Products,
	|	Characteristic,
	|	Batch,
	|	PurchaseOrder");
	
	Query.SetParameter("Recorder", Filter.Recorder.Value);
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	
	QueryResult = Query.Execute();
	
	QueryResultSelection = QueryResult.Select();
	QueryResultSelection.Next();
	
	// New changes were placed into temporary table "RegisterRecordsGoodsReceivedNotInvoicedChange".
	// It is added info about its existence and availability by her change records.
	StructureTemporaryTables.Insert("RegisterRecordsGoodsReceivedNotInvoicedChange", QueryResultSelection.Count > 0);
	
	// The "RegisterRecordsGoodsReceivedNotInvoicedBeforeWrite" temporary table is deleted
	Query = New Query("DROP RegisterRecordsGoodsReceivedNotInvoicedBeforeWrite");
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	Query.Execute();
	
EndProcedure

#EndRegion

#EndIf