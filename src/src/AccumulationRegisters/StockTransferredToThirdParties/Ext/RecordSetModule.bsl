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
	LockItem = Block.Add("AccumulationRegister.StockTransferredToThirdParties.RecordSet");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.SetValue("Recorder", Filter.Recorder.Value);
	Block.Lock();
	
	If Not StructureTemporaryTables.Property("RegisterRecordsStockTransferredToThirdPartiesChange") OR
		StructureTemporaryTables.Property("RegisterRecordsStockTransferredToThirdPartiesChange") AND Not StructureTemporaryTables.RegisterRecordsStockTransferredToThirdPartiesChange Then
		
		// If the temporary table "RegisterRecordsTransferredInventoryChange" doesn't exist and
		// doesn't contain records about the set change then set is written for the first time and for set balance control was executed.
		// Current set state is placed in a
		// temporary table "RegisterRecordsTransferredInventoryBeforeWrite" to get at record new set change rather current.
		
		Query = New Query(
		"SELECT
		|	StockTransferredToThirdParties.LineNumber AS LineNumber,
		|	StockTransferredToThirdParties.Company AS Company,
		|	StockTransferredToThirdParties.Products AS Products,
		|	StockTransferredToThirdParties.Characteristic AS Characteristic,
		|	StockTransferredToThirdParties.Batch AS Batch,
		|	StockTransferredToThirdParties.Counterparty AS Counterparty,
		|	StockTransferredToThirdParties.Contract AS Contract,
		|	StockTransferredToThirdParties.Order AS Order,
		|	CASE
		|		WHEN StockTransferredToThirdParties.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN StockTransferredToThirdParties.Quantity
		|		ELSE -StockTransferredToThirdParties.Quantity
		|	END AS QuantityBeforeWrite
		|INTO RegisterRecordsStockTransferredToThirdPartiesBeforeWrite
		|FROM
		|	AccumulationRegister.StockTransferredToThirdParties AS StockTransferredToThirdParties
		|WHERE
		|	StockTransferredToThirdParties.Recorder = &Recorder
		|	AND &Replacing");
		
		Query.SetParameter("Recorder", Filter.Recorder.Value);
		Query.SetParameter("Replacing", Replacing);
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		
	Else
		
		// If the temporary table "RegisterRecordsTransferredInventoryChange" exists and
		// contains records about the set change then set is written not for the first time and for set balance control wasn't executed.
		// Current set state and current change state are placed in
		// a temporary table "RegisterRecordsTransferredInventoryBeforeWrite" to get at record new set change rather initial.
		
		Query = New Query(
		"SELECT
		|	RegisterRecordsStockTransferredToThirdPartiesChange.LineNumber AS LineNumber,
		|	RegisterRecordsStockTransferredToThirdPartiesChange.Company AS Company,
		|	RegisterRecordsStockTransferredToThirdPartiesChange.Products AS Products,
		|	RegisterRecordsStockTransferredToThirdPartiesChange.Characteristic AS Characteristic,
		|	RegisterRecordsStockTransferredToThirdPartiesChange.Batch AS Batch,
		|	RegisterRecordsStockTransferredToThirdPartiesChange.Counterparty AS Counterparty,
		|	RegisterRecordsStockTransferredToThirdPartiesChange.Contract AS Contract,
		|	RegisterRecordsStockTransferredToThirdPartiesChange.Order AS Order,
		|	RegisterRecordsStockTransferredToThirdPartiesChange.QuantityBeforeWrite AS QuantityBeforeWrite
		|INTO RegisterRecordsStockTransferredToThirdPartiesBeforeWrite
		|FROM
		|	RegisterRecordsStockTransferredToThirdPartiesChange AS RegisterRecordsStockTransferredToThirdPartiesChange
		|
		|UNION ALL
		|
		|SELECT
		|	StockTransferredToThirdParties.LineNumber,
		|	StockTransferredToThirdParties.Company,
		|	StockTransferredToThirdParties.Products,
		|	StockTransferredToThirdParties.Characteristic,
		|	StockTransferredToThirdParties.Batch,
		|	StockTransferredToThirdParties.Counterparty,
		|	StockTransferredToThirdParties.Contract,
		|	StockTransferredToThirdParties.Order,
		|	CASE
		|		WHEN StockTransferredToThirdParties.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN StockTransferredToThirdParties.Quantity
		|		ELSE -StockTransferredToThirdParties.Quantity
		|	END
		|FROM
		|	AccumulationRegister.StockTransferredToThirdParties AS StockTransferredToThirdParties
		|WHERE
		|	StockTransferredToThirdParties.Recorder = &Recorder
		|	AND &Replacing");
		
		Query.SetParameter("Recorder", Filter.Recorder.Value);
		Query.SetParameter("Replacing", Replacing);
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		
	EndIf;
	
	// Temporary table
	// "RegisterRecordsTransferredInventoryChange" is destroyed info about its existence is Deleted.
	
	If StructureTemporaryTables.Property("RegisterRecordsStockTransferredToThirdPartiesChange") Then
		
		Query = New Query("DELETE RegisterRecordsTransferredInventoryChange");
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		StructureTemporaryTables.Delete("RegisterRecordsStockTransferredToThirdPartiesChange");
		
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
	// accumulated changes and placed into temporary table "RegisterRecordsTransferredInventoryChange".
	
	Query = New Query(
	"SELECT
	|	MIN(RegisterRecordsStockTransferredToThirdPartiesChange.LineNumber) AS LineNumber,
	|	RegisterRecordsStockTransferredToThirdPartiesChange.Company AS Company,
	|	RegisterRecordsStockTransferredToThirdPartiesChange.Products AS Products,
	|	RegisterRecordsStockTransferredToThirdPartiesChange.Characteristic AS Characteristic,
	|	RegisterRecordsStockTransferredToThirdPartiesChange.Batch AS Batch,
	|	RegisterRecordsStockTransferredToThirdPartiesChange.Counterparty AS Counterparty,
	|	RegisterRecordsStockTransferredToThirdPartiesChange.Contract AS Contract,
	|	RegisterRecordsStockTransferredToThirdPartiesChange.Order AS Order,
	|	SUM(RegisterRecordsStockTransferredToThirdPartiesChange.QuantityBeforeWrite) AS QuantityBeforeWrite,
	|	SUM(RegisterRecordsStockTransferredToThirdPartiesChange.QuantityChange) AS QuantityChange,
	|	SUM(RegisterRecordsStockTransferredToThirdPartiesChange.QuantityOnWrite) AS QuantityOnWrite
	|INTO RegisterRecordsStockTransferredToThirdPartiesChange
	|FROM
	|	(SELECT
	|		RegisterRecordsStockTransferredToThirdPartiesBeforeWrite.LineNumber AS LineNumber,
	|		RegisterRecordsStockTransferredToThirdPartiesBeforeWrite.Company AS Company,
	|		RegisterRecordsStockTransferredToThirdPartiesBeforeWrite.Products AS Products,
	|		RegisterRecordsStockTransferredToThirdPartiesBeforeWrite.Characteristic AS Characteristic,
	|		RegisterRecordsStockTransferredToThirdPartiesBeforeWrite.Batch AS Batch,
	|		RegisterRecordsStockTransferredToThirdPartiesBeforeWrite.Counterparty AS Counterparty,
	|		RegisterRecordsStockTransferredToThirdPartiesBeforeWrite.Contract AS Contract,
	|		RegisterRecordsStockTransferredToThirdPartiesBeforeWrite.Order AS Order,
	|		RegisterRecordsStockTransferredToThirdPartiesBeforeWrite.QuantityBeforeWrite AS QuantityBeforeWrite,
	|		RegisterRecordsStockTransferredToThirdPartiesBeforeWrite.QuantityBeforeWrite AS QuantityChange,
	|		0 AS QuantityOnWrite
	|	FROM
	|		RegisterRecordsStockTransferredToThirdPartiesBeforeWrite AS RegisterRecordsStockTransferredToThirdPartiesBeforeWrite
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		RegisterRecordsStockTransferredToThirdPartiesOnWrite.LineNumber,
	|		RegisterRecordsStockTransferredToThirdPartiesOnWrite.Company,
	|		RegisterRecordsStockTransferredToThirdPartiesOnWrite.Products,
	|		RegisterRecordsStockTransferredToThirdPartiesOnWrite.Characteristic,
	|		RegisterRecordsStockTransferredToThirdPartiesOnWrite.Batch,
	|		RegisterRecordsStockTransferredToThirdPartiesOnWrite.Counterparty,
	|		RegisterRecordsStockTransferredToThirdPartiesOnWrite.Contract,
	|		RegisterRecordsStockTransferredToThirdPartiesOnWrite.Order,
	|		0,
	|		CASE
	|			WHEN RegisterRecordsStockTransferredToThirdPartiesOnWrite.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -RegisterRecordsStockTransferredToThirdPartiesOnWrite.Quantity
	|			ELSE RegisterRecordsStockTransferredToThirdPartiesOnWrite.Quantity
	|		END,
	|		RegisterRecordsStockTransferredToThirdPartiesOnWrite.Quantity
	|	FROM
	|		AccumulationRegister.StockTransferredToThirdParties AS RegisterRecordsStockTransferredToThirdPartiesOnWrite
	|	WHERE
	|		RegisterRecordsStockTransferredToThirdPartiesOnWrite.Recorder = &Recorder) AS RegisterRecordsStockTransferredToThirdPartiesChange
	|
	|GROUP BY
	|	RegisterRecordsStockTransferredToThirdPartiesChange.Company,
	|	RegisterRecordsStockTransferredToThirdPartiesChange.Products,
	|	RegisterRecordsStockTransferredToThirdPartiesChange.Characteristic,
	|	RegisterRecordsStockTransferredToThirdPartiesChange.Batch,
	|	RegisterRecordsStockTransferredToThirdPartiesChange.Counterparty,
	|	RegisterRecordsStockTransferredToThirdPartiesChange.Contract,
	|	RegisterRecordsStockTransferredToThirdPartiesChange.Order
	|
	|HAVING
	|	SUM(RegisterRecordsStockTransferredToThirdPartiesChange.QuantityChange) <> 0
	|
	|INDEX BY
	|	Company,
	|	Products,
	|	Characteristic,
	|	Batch,
	|	Counterparty,
	|	Contract,
	|	Order");
	
	Query.SetParameter("Recorder", Filter.Recorder.Value);
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	
	QueryResult = Query.Execute();
	
	QueryResultSelection = QueryResult.Select();
	QueryResultSelection.Next();
	
	// New changes were placed into temporary table "RegisterRecordsTransferredInventoryChange".
	// It is added info about its existence and availability by her change records.
	StructureTemporaryTables.Insert("RegisterRecordsStockTransferredToThirdPartiesChange", QueryResultSelection.Count > 0);
	
	// The "RegisterRecordsTransferredInventoryBeforeWrite" temporary table is deleted
	Query = New Query("DROP RegisterRecordsStockTransferredToThirdPartiesBeforeWrite");
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	Query.Execute();
	
EndProcedure

#EndRegion

#EndIf