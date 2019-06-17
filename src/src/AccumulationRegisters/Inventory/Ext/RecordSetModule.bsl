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
	LockItem = Block.Add("AccumulationRegister.Inventory.RecordSet");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.SetValue("Recorder", Filter.Recorder.Value);
	Block.Lock();
	
	Query = New Query();
	
	If Not StructureTemporaryTables.Property("RegisterRecordsInventoryChange")
		OR (StructureTemporaryTables.Property("RegisterRecordsInventoryChange")
			AND Not StructureTemporaryTables.RegisterRecordsInventoryChange) Then
		
		// If the temporary table "RegisterRecordsInventoryChange" doesn't exist and
		// doesn't contain records about the set change then set is written for the first time and for set balance control was executed.
		// Current set state is placed in a
		// temporary table "RegisterRecordsInventoryBeforeWrite" to get at record new set change rather current.
		
		Query.Text = 
		"SELECT
		|	Inventory.LineNumber AS LineNumber,
		|	Inventory.Company AS Company,
		|	Inventory.StructuralUnit AS StructuralUnit,
		|	Inventory.GLAccount AS GLAccount,
		|	Inventory.Products AS Products,
		|	Inventory.Characteristic AS Characteristic,
		|	Inventory.Batch AS Batch,
		|	Inventory.SalesOrder AS SalesOrder,
		|	CASE
		|		WHEN Inventory.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN Inventory.Quantity
		|		ELSE -Inventory.Quantity
		|	END AS QuantityBeforeWrite,
		|	CASE
		|		WHEN Inventory.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN Inventory.Amount
		|		ELSE -Inventory.Amount
		|	END AS SumBeforeWrite
		|INTO RegisterRecordsInventoryBeforeWrite
		|FROM
		|	AccumulationRegister.Inventory AS Inventory
		|WHERE
		|	Inventory.Recorder = &Recorder
		|	AND &Replacing";
		
	Else
		
		// If the temporary table "RegisterRecordsInventoryChange" exists and
		// contains records about the set change then set is written not for the first time and for set balance control wasn't executed.
		// Current set state and current change state are placed in
		// a temporary table "RegisterRecordsInventoryBeforeWrite" to get at record new set change rather initial.
		
		Query.Text = 
		"SELECT
		|	RegisterRecordsInventoryChange.LineNumber AS LineNumber,
		|	RegisterRecordsInventoryChange.Company AS Company,
		|	RegisterRecordsInventoryChange.StructuralUnit AS StructuralUnit,
		|	RegisterRecordsInventoryChange.GLAccount AS GLAccount,
		|	RegisterRecordsInventoryChange.Products AS Products,
		|	RegisterRecordsInventoryChange.Characteristic AS Characteristic,
		|	RegisterRecordsInventoryChange.Batch AS Batch,
		|	RegisterRecordsInventoryChange.SalesOrder AS SalesOrder,
		|	RegisterRecordsInventoryChange.QuantityBeforeWrite AS QuantityBeforeWrite,
		|	RegisterRecordsInventoryChange.SumBeforeWrite AS SumBeforeWrite
		|INTO RegisterRecordsInventoryBeforeWrite
		|FROM
		|	RegisterRecordsInventoryChange AS RegisterRecordsInventoryChange
		|
		|UNION ALL
		|
		|SELECT
		|	Inventory.LineNumber,
		|	Inventory.Company,
		|	Inventory.StructuralUnit,
		|	Inventory.GLAccount,
		|	Inventory.Products,
		|	Inventory.Characteristic,
		|	Inventory.Batch,
		|	Inventory.SalesOrder,
		|	CASE
		|		WHEN Inventory.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN Inventory.Quantity
		|		ELSE -Inventory.Quantity
		|	END,
		|	CASE
		|		WHEN Inventory.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN Inventory.Amount
		|		ELSE -Inventory.Amount
		|	END
		|FROM
		|	AccumulationRegister.Inventory AS Inventory
		|WHERE
		|	Inventory.Recorder = &Recorder
		|	AND &Replacing";
		
	EndIf;
	
	DriveClientServer.AddDelimeter(Query.Text);
	
	Query.Text = Query.Text + 
	"SELECT
	|	Inventory.Period AS Period,
	|	Inventory.Recorder AS Recorder,
	|	Inventory.RecordType AS RecordType,
	|	Inventory.Company AS Company,
	|	Inventory.StructuralUnit AS StructuralUnit,
	|	Inventory.GLAccount AS GLAccount,
	|	Inventory.Products AS Products,
	|	Inventory.Characteristic AS Characteristic,
	|	Inventory.Batch AS Batch,
	|	Inventory.SalesOrder AS SalesOrder,
	|	Inventory.Quantity AS Quantity,
	|	Inventory.Amount AS Amount
	|INTO InventoryBeforeWrite
	|FROM
	|	AccumulationRegister.Inventory AS Inventory
	|WHERE
	|	Inventory.Recorder = &Recorder
	|	AND &FIFOIsUsed";
	
	Query.SetParameter("Recorder", Filter.Recorder.Value);
	Query.SetParameter("Replacing", Replacing);
	Query.SetParameter("FIFOIsUsed", Constants.UseFIFO.Get());
	
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	Query.Execute();
	
	// Temporary table
	// "RegisterRecordsInventoryChange" is destroyed info about its existence is Deleted.
	
	If StructureTemporaryTables.Property("RegisterRecordsInventoryChange") Then
		Query = New Query("DROP RegisterRecordsInventoryChange");
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		StructureTemporaryTables.Delete("RegisterRecordsInventoryChange");
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
	// accumulated changes and placed into temporary table "RegisterRecordsInventoryChange".
	
	Query = New Query(
	"SELECT
	|	MIN(RegisterRecordsInventoryChange.LineNumber) AS LineNumber,
	|	RegisterRecordsInventoryChange.Company AS Company,
	|	RegisterRecordsInventoryChange.StructuralUnit AS StructuralUnit,
	|	RegisterRecordsInventoryChange.GLAccount AS GLAccount,
	|	RegisterRecordsInventoryChange.Products AS Products,
	|	RegisterRecordsInventoryChange.Characteristic AS Characteristic,
	|	RegisterRecordsInventoryChange.Batch AS Batch,
	|	RegisterRecordsInventoryChange.SalesOrder AS SalesOrder,
	|	SUM(RegisterRecordsInventoryChange.QuantityBeforeWrite) AS QuantityBeforeWrite,
	|	SUM(RegisterRecordsInventoryChange.QuantityChange) AS QuantityChange,
	|	SUM(RegisterRecordsInventoryChange.QuantityOnWrite) AS QuantityOnWrite,
	|	SUM(RegisterRecordsInventoryChange.SumBeforeWrite) AS SumBeforeWrite,
	|	SUM(RegisterRecordsInventoryChange.AmountChange) AS AmountChange,
	|	SUM(RegisterRecordsInventoryChange.AmountOnWrite) AS AmountOnWrite
	|INTO RegisterRecordsInventoryChange
	|FROM
	|	(SELECT
	|		RegisterRecordsInventoryBeforeWrite.LineNumber AS LineNumber,
	|		RegisterRecordsInventoryBeforeWrite.Company AS Company,
	|		RegisterRecordsInventoryBeforeWrite.StructuralUnit AS StructuralUnit,
	|		RegisterRecordsInventoryBeforeWrite.GLAccount AS GLAccount,
	|		RegisterRecordsInventoryBeforeWrite.Products AS Products,
	|		RegisterRecordsInventoryBeforeWrite.Characteristic AS Characteristic,
	|		RegisterRecordsInventoryBeforeWrite.Batch AS Batch,
	|		RegisterRecordsInventoryBeforeWrite.SalesOrder AS SalesOrder,
	|		RegisterRecordsInventoryBeforeWrite.QuantityBeforeWrite AS QuantityBeforeWrite,
	|		RegisterRecordsInventoryBeforeWrite.QuantityBeforeWrite AS QuantityChange,
	|		0 AS QuantityOnWrite,
	|		RegisterRecordsInventoryBeforeWrite.SumBeforeWrite AS SumBeforeWrite,
	|		RegisterRecordsInventoryBeforeWrite.SumBeforeWrite AS AmountChange,
	|		0 AS AmountOnWrite
	|	FROM
	|		RegisterRecordsInventoryBeforeWrite AS RegisterRecordsInventoryBeforeWrite
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		RegisterRecordsInventoryOnWrite.LineNumber,
	|		RegisterRecordsInventoryOnWrite.Company,
	|		RegisterRecordsInventoryOnWrite.StructuralUnit,
	|		RegisterRecordsInventoryOnWrite.GLAccount,
	|		RegisterRecordsInventoryOnWrite.Products,
	|		RegisterRecordsInventoryOnWrite.Characteristic,
	|		RegisterRecordsInventoryOnWrite.Batch,
	|		RegisterRecordsInventoryOnWrite.SalesOrder,
	|		0,
	|		CASE
	|			WHEN RegisterRecordsInventoryOnWrite.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -RegisterRecordsInventoryOnWrite.Quantity
	|			ELSE RegisterRecordsInventoryOnWrite.Quantity
	|		END,
	|		RegisterRecordsInventoryOnWrite.Quantity,
	|		0,
	|		CASE
	|			WHEN RegisterRecordsInventoryOnWrite.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -RegisterRecordsInventoryOnWrite.Amount
	|			ELSE RegisterRecordsInventoryOnWrite.Amount
	|		END,
	|		RegisterRecordsInventoryOnWrite.Amount
	|	FROM
	|		AccumulationRegister.Inventory AS RegisterRecordsInventoryOnWrite
	|	WHERE
	|		RegisterRecordsInventoryOnWrite.Recorder = &Recorder) AS RegisterRecordsInventoryChange
	|
	|GROUP BY
	|	RegisterRecordsInventoryChange.Company,
	|	RegisterRecordsInventoryChange.StructuralUnit,
	|	RegisterRecordsInventoryChange.GLAccount,
	|	RegisterRecordsInventoryChange.Products,
	|	RegisterRecordsInventoryChange.Characteristic,
	|	RegisterRecordsInventoryChange.Batch,
	|	RegisterRecordsInventoryChange.SalesOrder
	|
	|HAVING
	|	(SUM(RegisterRecordsInventoryChange.QuantityChange) <> 0
	|		OR SUM(RegisterRecordsInventoryChange.AmountChange) <> 0)
	|
	|INDEX BY
	|	Company,
	|	StructuralUnit,
	|	GLAccount,
	|	Products,
	|	Characteristic,
	|	Batch,
	|	SalesOrder
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	BEGINOFPERIOD(Table.Period, MONTH) AS Month,
	|	Table.Company AS Company,
	|	Table.Recorder AS Document
	|INTO InventoryTasks
	|FROM
	|	(SELECT
	|		BeforeWrite.Period AS Period,
	|		BeforeWrite.Recorder AS Recorder,
	|		BeforeWrite.RecordType AS RecordType,
	|		BeforeWrite.Company AS Company,
	|		BeforeWrite.StructuralUnit AS StructuralUnit,
	|		BeforeWrite.GLAccount AS GLAccount,
	|		BeforeWrite.Products AS Products,
	|		BeforeWrite.Characteristic AS Characteristic,
	|		BeforeWrite.Batch AS Batch,
	|		BeforeWrite.SalesOrder AS SalesOrder,
	|		BeforeWrite.Quantity AS Quantity,
	|		BeforeWrite.Amount AS Amount
	|	FROM
	|		InventoryBeforeWrite AS BeforeWrite
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		AfterWrite.Period,
	|		AfterWrite.Recorder,
	|		AfterWrite.RecordType,
	|		AfterWrite.Company,
	|		AfterWrite.StructuralUnit,
	|		AfterWrite.GLAccount,
	|		AfterWrite.Products,
	|		AfterWrite.Characteristic,
	|		AfterWrite.Batch,
	|		AfterWrite.SalesOrder,
	|		-AfterWrite.Quantity,
	|		-AfterWrite.Amount
	|	FROM
	|		AccumulationRegister.Inventory AS AfterWrite
	|	WHERE
	|		AfterWrite.Recorder = &Recorder
	|		AND &FIFOIsUsed) AS Table
	|
	|GROUP BY
	|	BEGINOFPERIOD(Table.Period, MONTH),
	|	Table.Recorder,
	|	Table.Period,
	|	Table.RecordType,
	|	Table.Company,
	|	Table.StructuralUnit,
	|	Table.GLAccount,
	|	Table.Products,
	|	Table.Characteristic,
	|	Table.Batch,
	|	Table.SalesOrder
	|
	|HAVING
	|	(SUM(Table.Quantity) <> 0
	|		OR SUM(Table.Amount) <> 0)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP InventoryBeforeWrite
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP RegisterRecordsInventoryBeforeWrite");
	
	Query.SetParameter("Recorder", Filter.Recorder.Value);
	Query.SetParameter("FIFOIsUsed", Constants.UseFIFO.Get());
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	
	QueryResult = Query.ExecuteBatch();
	
	QueryResultSelection = QueryResult[0].Select();
	QueryResultSelection.Next();
	
	// New changes were placed into temporary table "RegisterRecordsInventoryChange".
	// It is added info about its existence and availability by her change records.
	StructureTemporaryTables.Insert("RegisterRecordsInventoryChange", QueryResultSelection.Count > 0);
	
EndProcedure

#EndRegion

#EndIf