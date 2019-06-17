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
	LockItem = Block.Add("AccumulationRegister.StockReceivedFromThirdParties.RecordSet");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.SetValue("Recorder", Filter.Recorder.Value);
	Block.Lock();
	
	If Not StructureTemporaryTables.Property("RegisterRecordsStockReceivedFromThirdPartiesChange") OR
		StructureTemporaryTables.Property("RegisterRecordsStockReceivedFromThirdPartiesChange") AND Not StructureTemporaryTables.RegisterRecordsStockReceivedFromThirdPartiesChange Then
		
		// If the temporary table "RegisterRecordsStockReceivedFromThirdPartiesChange" doesn't exist and
		// doesn't contain records about the set change then set is written for the first time and for set balance control was executed.
		// Current set state is placed in a
		// temporary table "RegisterRecordsInventoryBeforeWrite" to get at record new set change rather current.
		
		Query = New Query(
		"SELECT
		|	StockReceivedFromThirdParties.LineNumber AS LineNumber,
		|	StockReceivedFromThirdParties.Company AS Company,
		|	StockReceivedFromThirdParties.Products AS Products,
		|	StockReceivedFromThirdParties.Characteristic AS Characteristic,
		|	StockReceivedFromThirdParties.Batch AS Batch,
		|	StockReceivedFromThirdParties.Counterparty AS Counterparty,
		|	StockReceivedFromThirdParties.Contract AS Contract,
		|	StockReceivedFromThirdParties.Order AS Order,
		|	CASE
		|		WHEN StockReceivedFromThirdParties.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN StockReceivedFromThirdParties.Quantity
		|		ELSE -StockReceivedFromThirdParties.Quantity
		|	END AS QuantityBeforeWrite
		|INTO RegisterRecordsStockReceivedFromThirdPartiesBeforeWrite
		|FROM
		|	AccumulationRegister.StockReceivedFromThirdParties AS StockReceivedFromThirdParties
		|WHERE
		|	StockReceivedFromThirdParties.Recorder = &Recorder
		|	AND &Replacing");
		
		Query.SetParameter("Recorder", Filter.Recorder.Value);
		Query.SetParameter("Replacing", Replacing);
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		
	Else
		
		// If the temporary table "RegisterRecordsStockReceivedFromThirdPartiesChange" exists and
		// contains records about the set change then set is written not for the first time and for set balance control wasn't executed.
		// Current set state and current change state are placed in
		// a temporary table "RegisterRecordsInventoryBeforeWrite" to get at record new set change rather initial.
		
		Query = New Query(
		"SELECT
		|	RegisterRecordsStockReceivedFromThirdPartiesChange.LineNumber AS LineNumber,
		|	RegisterRecordsStockReceivedFromThirdPartiesChange.Company AS Company,
		|	RegisterRecordsStockReceivedFromThirdPartiesChange.Products AS Products,
		|	RegisterRecordsStockReceivedFromThirdPartiesChange.Characteristic AS Characteristic,
		|	RegisterRecordsStockReceivedFromThirdPartiesChange.Batch AS Batch,
		|	RegisterRecordsStockReceivedFromThirdPartiesChange.Counterparty AS Counterparty,
		|	RegisterRecordsStockReceivedFromThirdPartiesChange.Contract AS Contract,
		|	RegisterRecordsStockReceivedFromThirdPartiesChange.Order AS Order,
		|	RegisterRecordsStockReceivedFromThirdPartiesChange.QuantityBeforeWrite AS QuantityBeforeWrite
		|INTO RegisterRecordsStockReceivedFromThirdPartiesBeforeWrite
		|FROM
		|	RegisterRecordsStockReceivedFromThirdPartiesChange AS RegisterRecordsStockReceivedFromThirdPartiesChange
		|
		|UNION ALL
		|
		|SELECT
		|	StockReceivedFromThirdParties.LineNumber,
		|	StockReceivedFromThirdParties.Company,
		|	StockReceivedFromThirdParties.Products,
		|	StockReceivedFromThirdParties.Characteristic,
		|	StockReceivedFromThirdParties.Batch,
		|	StockReceivedFromThirdParties.Counterparty,
		|	StockReceivedFromThirdParties.Contract,
		|	StockReceivedFromThirdParties.Order,
		|	CASE
		|		WHEN StockReceivedFromThirdParties.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN StockReceivedFromThirdParties.Quantity
		|		ELSE -StockReceivedFromThirdParties.Quantity
		|	END
		|FROM
		|	AccumulationRegister.StockReceivedFromThirdParties AS StockReceivedFromThirdParties
		|WHERE
		|	StockReceivedFromThirdParties.Recorder = &Recorder
		|	AND &Replacing");
		
		Query.SetParameter("Recorder", Filter.Recorder.Value);
		Query.SetParameter("Replacing", Replacing);
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		
	EndIf;
	
	// Temporary table
	// "RegisterRecordsStockReceivedFromThirdPartiesChange" is destroyed info about its existence is Deleted.
	
	If StructureTemporaryTables.Property("RegisterRecordsStockReceivedFromThirdPartiesChange") Then
		
		Query = New Query("DROP RegisterRecordsStockReceivedFromThirdPartiesChange");
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		StructureTemporaryTables.Delete("RegisterRecordsStockReceivedFromThirdPartiesChange");
	
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
	// accumulated changes and placed into temporary table "RegisterRecordsStockReceivedFromThirdPartiesChange".
	
	Query = New Query(
	"SELECT
	|	MIN(RegisterRecordsStockReceivedFromThirdPartiesChange.LineNumber) AS LineNumber,
	|	RegisterRecordsStockReceivedFromThirdPartiesChange.Company AS Company,
	|	RegisterRecordsStockReceivedFromThirdPartiesChange.Products AS Products,
	|	RegisterRecordsStockReceivedFromThirdPartiesChange.Characteristic AS Characteristic,
	|	RegisterRecordsStockReceivedFromThirdPartiesChange.Batch AS Batch,
	|	RegisterRecordsStockReceivedFromThirdPartiesChange.Counterparty AS Counterparty,
	|	RegisterRecordsStockReceivedFromThirdPartiesChange.Contract AS Contract,
	|	RegisterRecordsStockReceivedFromThirdPartiesChange.Order AS Order,
	|	SUM(RegisterRecordsStockReceivedFromThirdPartiesChange.QuantityBeforeWrite) AS QuantityBeforeWrite,
	|	SUM(RegisterRecordsStockReceivedFromThirdPartiesChange.QuantityChange) AS QuantityChange,
	|	SUM(RegisterRecordsStockReceivedFromThirdPartiesChange.QuantityOnWrite) AS QuantityOnWrite
	|INTO RegisterRecordsStockReceivedFromThirdPartiesChange
	|FROM
	|	(SELECT
	|		RegisterRecordsStockReceivedFromThirdPartiesBeforeWrite.LineNumber AS LineNumber,
	|		RegisterRecordsStockReceivedFromThirdPartiesBeforeWrite.Company AS Company,
	|		RegisterRecordsStockReceivedFromThirdPartiesBeforeWrite.Products AS Products,
	|		RegisterRecordsStockReceivedFromThirdPartiesBeforeWrite.Characteristic AS Characteristic,
	|		RegisterRecordsStockReceivedFromThirdPartiesBeforeWrite.Batch AS Batch,
	|		RegisterRecordsStockReceivedFromThirdPartiesBeforeWrite.Counterparty AS Counterparty,
	|		RegisterRecordsStockReceivedFromThirdPartiesBeforeWrite.Contract AS Contract,
	|		RegisterRecordsStockReceivedFromThirdPartiesBeforeWrite.Order AS Order,
	|		RegisterRecordsStockReceivedFromThirdPartiesBeforeWrite.QuantityBeforeWrite AS QuantityBeforeWrite,
	|		RegisterRecordsStockReceivedFromThirdPartiesBeforeWrite.QuantityBeforeWrite AS QuantityChange,
	|		0 AS QuantityOnWrite
	|	FROM
	|		RegisterRecordsStockReceivedFromThirdPartiesBeforeWrite AS RegisterRecordsStockReceivedFromThirdPartiesBeforeWrite
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		RegisterRecordsStockReceivedFromThirdPartiesOnWrite.LineNumber,
	|		RegisterRecordsStockReceivedFromThirdPartiesOnWrite.Company,
	|		RegisterRecordsStockReceivedFromThirdPartiesOnWrite.Products,
	|		RegisterRecordsStockReceivedFromThirdPartiesOnWrite.Characteristic,
	|		RegisterRecordsStockReceivedFromThirdPartiesOnWrite.Batch,
	|		RegisterRecordsStockReceivedFromThirdPartiesOnWrite.Counterparty,
	|		RegisterRecordsStockReceivedFromThirdPartiesOnWrite.Contract,
	|		RegisterRecordsStockReceivedFromThirdPartiesOnWrite.Order,
	|		0,
	|		CASE
	|			WHEN RegisterRecordsStockReceivedFromThirdPartiesOnWrite.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -RegisterRecordsStockReceivedFromThirdPartiesOnWrite.Quantity
	|			ELSE RegisterRecordsStockReceivedFromThirdPartiesOnWrite.Quantity
	|		END,
	|		RegisterRecordsStockReceivedFromThirdPartiesOnWrite.Quantity
	|	FROM
	|		AccumulationRegister.StockReceivedFromThirdParties AS RegisterRecordsStockReceivedFromThirdPartiesOnWrite
	|	WHERE
	|		RegisterRecordsStockReceivedFromThirdPartiesOnWrite.Recorder = &Recorder) AS RegisterRecordsStockReceivedFromThirdPartiesChange
	|
	|GROUP BY
	|	RegisterRecordsStockReceivedFromThirdPartiesChange.Company,
	|	RegisterRecordsStockReceivedFromThirdPartiesChange.Products,
	|	RegisterRecordsStockReceivedFromThirdPartiesChange.Characteristic,
	|	RegisterRecordsStockReceivedFromThirdPartiesChange.Batch,
	|	RegisterRecordsStockReceivedFromThirdPartiesChange.Counterparty,
	|	RegisterRecordsStockReceivedFromThirdPartiesChange.Contract,
	|	RegisterRecordsStockReceivedFromThirdPartiesChange.Order
	|
	|HAVING
	|	SUM(RegisterRecordsStockReceivedFromThirdPartiesChange.QuantityChange) <> 0
	|
	|INDEX BY
	|	Company,
	|	Products,
	|	Characteristic,
	|	Batch,
	|	RegisterRecordsStockReceivedFromThirdPartiesChange.Counterparty,
	|	RegisterRecordsStockReceivedFromThirdPartiesChange.Contract,
	|	RegisterRecordsStockReceivedFromThirdPartiesChange.Order");
	
	Query.SetParameter("Recorder", Filter.Recorder.Value);
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	
	QueryResult = Query.Execute();
	
	QueryResultSelection = QueryResult.Select();
	QueryResultSelection.Next();
	
	// New changes were placed into temporary table "RegisterRecordsStockReceivedFromThirdPartiesChange".
	// It is added info about its existence and availability by her change records.
	StructureTemporaryTables.Insert("RegisterRecordsStockReceivedFromThirdPartiesChange", QueryResultSelection.Count > 0);
	
	// The "RegisterRecordsInventoryBeforeWrite" temprorary table is deleted
	Query = New Query("DROP RegisterRecordsStockReceivedFromThirdPartiesBeforeWrite");
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	Query.Execute();
	
EndProcedure

#EndRegion

#EndIf