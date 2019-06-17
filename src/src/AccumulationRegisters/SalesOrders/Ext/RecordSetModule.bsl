#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions

// Procedure calculates and writes the schedule of order execution.
// Shipping date is specified in "Period". Upon the actual shipment by order,
// the schedule is closed according to FIFO.
//
Procedure CalculateOrdersFulfilmentSchedule()
	
	OrdersTable = AdditionalProperties.OrdersTable;
	Query = New Query;
	Query.SetParameter("OrdersArray", OrdersTable.UnloadColumn("SalesOrder"));
	Query.Text =
	"SELECT
	|	SalesOrdersBalances.Company AS Company,
	|	SalesOrdersBalances.SalesOrder AS SalesOrder,
	|	SalesOrdersBalances.Products AS Products,
	|	SalesOrdersBalances.Characteristic AS Characteristic,
	|	SalesOrdersBalances.QuantityBalance AS QuantityBalance
	|INTO TU_Balance
	|FROM
	|	AccumulationRegister.SalesOrders.Balance(, SalesOrder IN (&OrdersArray)) AS SalesOrdersBalances
	|
	|INDEX BY
	|	Company,
	|	SalesOrder,
	|	Products,
	|	Characteristic
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CASE
	|		WHEN Table.ShipmentDate = DATETIME(1, 1, 1)
	|			THEN BEGINOFPERIOD(Table.Period, Day)
	|		ELSE BEGINOFPERIOD(Table.ShipmentDate, Day)
	|	END AS Period,
	|	Table.Company AS Company,
	|	Table.SalesOrder AS SalesOrder,
	|	Table.Products AS Products,
	|	Table.Characteristic AS Characteristic,
	|	SUM(Table.Quantity) AS QuantityPlan
	|INTO TU_RegisterRecordPlan
	|FROM
	|	AccumulationRegister.SalesOrders AS Table
	|WHERE
	|	Table.SalesOrder IN(&OrdersArray)
	|	AND Table.RecordType = VALUE(AccumulationRecordType.Receipt)
	|	AND Table.Quantity > 0
	|	AND Table.Active
	|
	|GROUP BY
	|	CASE
	|		WHEN Table.ShipmentDate = DATETIME(1, 1, 1)
	|			THEN BEGINOFPERIOD(Table.Period, Day)
	|		ELSE BEGINOFPERIOD(Table.ShipmentDate, Day)
	|	END,
	|	Table.Company,
	|	Table.SalesOrder,
	|	Table.Products,
	|	Table.Characteristic
	|
	|INDEX BY
	|	Company,
	|	SalesOrder,
	|	Products,
	|	Characteristic
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TU_Table.Period AS Period,
	|	TU_Table.Company AS Company,
	|	TU_Table.SalesOrder AS SalesOrder,
	|	TU_Table.Products AS Products,
	|	TU_Table.Characteristic AS Characteristic,
	|	TU_Table.QuantityPlan AS QuantityPlan,
	|	ISNULL(TU_Balance.QuantityBalance, 0) AS QuantityBalance
	|FROM
	|	TU_RegisterRecordPlan AS TU_Table
	|		LEFT JOIN TU_Balance AS TU_Balance
	|		ON TU_Table.Company = TU_Balance.Company
	|			AND TU_Table.SalesOrder = TU_Balance.SalesOrder
	|			AND TU_Table.Products = TU_Balance.Products
	|			AND TU_Table.Characteristic = TU_Balance.Characteristic
	|
	|ORDER BY
	|	SalesOrder,
	|	Products,
	|	Characteristic,
	|	Period DESC";
	
	RecordSet = InformationRegisters.OrderFulfillmentSchedule.CreateRecordSet();
	Selection = Query.Execute().Select();
	ThereAreRecordsInSelection = Selection.Next();
	While ThereAreRecordsInSelection Do
		
		CurPeriod = Undefined;
		CurCompany = Undefined;
		CurProducts = Undefined;
		CurCharacteristic = Undefined;
		CurSalesOrder = Selection.SalesOrder;
		
		RecordSet.Filter.Order.Set(CurSalesOrder);
		
		// Delete the closed order from the table.
		OrdersTable.Delete(OrdersTable.Find(CurSalesOrder, "SalesOrder"));
		
		// Cycle by single order strings.
		TotalPlan = 0;
		TotalBalance = 0;
		StructureRecordSet = New Structure;
		While ThereAreRecordsInSelection AND Selection.SalesOrder = CurSalesOrder Do
			
			TotalPlan = TotalPlan + Selection.QuantityPlan;
			
			If CurProducts <> Selection.Products
				OR CurCharacteristic <> Selection.Characteristic
				OR CurCompany <> Selection.Company Then
				
				CurProducts = Selection.Products;
				CurCharacteristic = Selection.Characteristic;
				CurCompany = Selection.Company;
				
				TotalQuantityBalance = 0;
				If Selection.QuantityBalance > 0 Then
					TotalQuantityBalance = Selection.QuantityBalance;
				EndIf;
				
				TotalBalance = TotalBalance + Selection.QuantityBalance;
				
			EndIf;
			
			CurQuantity = min(Selection.QuantityPlan, TotalQuantityBalance);
			If CurQuantity > 0 AND ?(ValueIsFilled(CurPeriod), CurPeriod > Selection.Period, True) Then
				
				StructureRecordSet.Insert("Period", Selection.Period);
				StructureRecordSet.Insert("SalesOrder", Selection.SalesOrder);
				
				CurPeriod = Selection.Period;
				
			EndIf;
			
			TotalQuantityBalance = TotalQuantityBalance - CurQuantity;
			
			// Go to the next record in the selection.
			ThereAreRecordsInSelection = Selection.Next();
			
		EndDo;
		
		// Writing and clearing the set.
		If StructureRecordSet.Count() > 0 Then
			Record = RecordSet.Add();
			Record.Period = StructureRecordSet.Period;
			Record.Order = StructureRecordSet.SalesOrder;
			Record.Completed = TotalPlan - TotalBalance;
		EndIf;
		
		RecordSet.Write(True);
		RecordSet.Clear();
		
	EndDo;
	
	// The register records should be cleared for unfinished orders.
	If OrdersTable.Count() > 0 Then
		For Each TabRow In OrdersTable Do
			
			RecordSet.Filter.Order.Set(TabRow.SalesOrder);
			RecordSet.Write(True);
			RecordSet.Clear();
			
		EndDo;
	EndIf;
	
EndProcedure

// Procedure forms the table of orders that were
// previously in the register records and which will be written now.
//
Procedure GenerateTableOfOrders()
	
	Query = New Query;
	Query.SetParameter("Recorder", Filter.Recorder.Value);
	Query.Text =
	"SELECT DISTINCT
	|	TableSalesOrders.SalesOrder AS SalesOrder
	|FROM
	|	AccumulationRegister.SalesOrders AS TableSalesOrders
	|WHERE
	|	TableSalesOrders.Recorder = &Recorder";
	
	OrdersTable = Query.Execute().Unload();
	TableOfNewOrders = Unload(, "SalesOrder");
	TableOfNewOrders.GroupBy("SalesOrder");
	For Each Record In TableOfNewOrders Do
		
		If OrdersTable.Find(Record.SalesOrder, "SalesOrder") = Undefined Then
			OrdersTable.Add().SalesOrder = Record.SalesOrder;
		EndIf;
		
	EndDo;
	
	AdditionalProperties.Insert("OrdersTable", OrdersTable);
	
EndProcedure

// Procedure locks data for schedule calculation.
//
Procedure InstallLocksOnDataForCalculatingSchedule()
	
	Block = New DataLock;
	
	// Locking the register for balance calculation by orders.
	LockItem = Block.Add("AccumulationRegister.SalesOrders");
	LockItem.Mode = DataLockMode.Shared;
	LockItem.DataSource = AdditionalProperties.OrdersTable;
	LockItem.UseFromDataSource("SalesOrder", "SalesOrder");
	
	// Locking the record set.
	LockItem = Block.Add("InformationRegister.OrderFulfillmentSchedule");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = AdditionalProperties.OrdersTable;
	LockItem.UseFromDataSource("Order", "SalesOrder");
	
	Block.Lock();
	
EndProcedure

// Procedure forms the table of initial records of the register.
//
Procedure GenerateSourceRecordsTable(Cancel, Replacing)
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// Setting the exclusive lock of the current set of records of the registrar.
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.SalesOrders.RecordSet");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.SetValue("Recorder", Filter.Recorder.Value);
	Block.Lock();
	
	If Not StructureTemporaryTables.Property("RegisterRecordsSalesOrdersChange") OR
		StructureTemporaryTables.Property("RegisterRecordsSalesOrdersChange") AND Not StructureTemporaryTables.RegisterRecordsSalesOrdersChange Then
		
		// If the "RegisterRecordsSalesOrdersChange" temporary table does not exist and
		// does not contain records on change of the set, it means that the set is written for the first time, and the set was
		// controlled for balances. Current state of the set is placed into the "RegisterRecordsSalesOrdersBeforeWrite"
		// temporary table to get the change of a new set with respect to the current set when writing.
		
		Query = New Query(
		"SELECT
		|	SalesOrders.LineNumber AS LineNumber,
		|	SalesOrders.Company AS Company,
		|	SalesOrders.SalesOrder AS SalesOrder,
		|	SalesOrders.Products AS Products,
		|	SalesOrders.Characteristic AS Characteristic,
		|	CASE
		|		WHEN SalesOrders.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN SalesOrders.Quantity
		|		ELSE -SalesOrders.Quantity
		|	END AS QuantityBeforeWrite
		|INTO RegisterRecordsSalesOrdersBeforeWrite
		|FROM
		|	AccumulationRegister.SalesOrders AS SalesOrders
		|WHERE
		|	SalesOrders.Recorder = &Recorder
		|	AND &Replacing");
		
		Query.SetParameter("Recorder", Filter.Recorder.Value);
		Query.SetParameter("Replacing", Replacing);
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		
	Else
		
		// If the "RegisterRecordsSalesOrdersChange" temporary table exists and
		// contains records about the set change, it means the set is written not for the first time and the set was not
		// controlled for balances. Current state of the set and current state of changes are placed into the
		// "RegisterRecordsSalesOrdersBeforeWrite" temporary table to get the change of a new set with respect to the initial
		// set when writing.
		
		Query = New Query(
		"SELECT
		|	RegisterRecordsSalesOrdersChange.LineNumber AS LineNumber,
		|	RegisterRecordsSalesOrdersChange.Company AS Company,
		|	RegisterRecordsSalesOrdersChange.SalesOrder AS SalesOrder,
		|	RegisterRecordsSalesOrdersChange.Products AS Products,
		|	RegisterRecordsSalesOrdersChange.Characteristic AS Characteristic,
		|	RegisterRecordsSalesOrdersChange.QuantityBeforeWrite AS QuantityBeforeWrite
		|INTO RegisterRecordsSalesOrdersBeforeWrite
		|FROM
		|	RegisterRecordsSalesOrdersChange AS RegisterRecordsSalesOrdersChange
		|
		|UNION ALL
		|
		|SELECT
		|	SalesOrders.LineNumber,
		|	SalesOrders.Company,
		|	SalesOrders.SalesOrder,
		|	SalesOrders.Products,
		|	SalesOrders.Characteristic,
		|	CASE
		|		WHEN SalesOrders.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN SalesOrders.Quantity
		|		ELSE -SalesOrders.Quantity
		|	END
		|FROM
		|	AccumulationRegister.SalesOrders AS SalesOrders
		|WHERE
		|	SalesOrders.Recorder = &Recorder
		|	AND &Replacing");
		
		Query.SetParameter("Recorder", Filter.Recorder.Value);
		Query.SetParameter("Replacing", Replacing);
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		
	EndIf;
	
	// Temporary table "RegisterRecordsSalesOrdersChange" is deleted
	// Information related to its existence is deleted.
	
	If StructureTemporaryTables.Property("RegisterRecordsSalesOrdersChange") Then
		
		Query = New Query("DROP RegisterRecordsSalesOrdersChange");
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		StructureTemporaryTables.Delete("RegisterRecordsSalesOrdersChange");
		
	EndIf;
	
EndProcedure

// Procedure forms the table of change records of the register.
//
Procedure GenerateRecordsChangeTable(Cancel, Replacing)
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// Change of a new set is calculated with respect to current one, taking into account the accumulated changes,
	// and the set is placed into the "RegisterRecordsSalesOrdersChange" temporary table.
	
	Query = New Query(
	"SELECT
	|	MIN(RegisterRecordsSalesOrdersChange.LineNumber) AS LineNumber,
	|	RegisterRecordsSalesOrdersChange.Company AS Company,
	|	RegisterRecordsSalesOrdersChange.SalesOrder AS SalesOrder,
	|	RegisterRecordsSalesOrdersChange.Products AS Products,
	|	RegisterRecordsSalesOrdersChange.Characteristic AS Characteristic,
	|	SUM(RegisterRecordsSalesOrdersChange.QuantityBeforeWrite) AS QuantityBeforeWrite,
	|	SUM(RegisterRecordsSalesOrdersChange.QuantityChange) AS QuantityChange,
	|	SUM(RegisterRecordsSalesOrdersChange.QuantityOnWrite) AS QuantityOnWrite
	|INTO RegisterRecordsSalesOrdersChange
	|FROM
	|	(SELECT
	|		RegisterRecordsSalesOrdersBeforeWrite.LineNumber AS LineNumber,
	|		RegisterRecordsSalesOrdersBeforeWrite.Company AS Company,
	|		RegisterRecordsSalesOrdersBeforeWrite.SalesOrder AS SalesOrder,
	|		RegisterRecordsSalesOrdersBeforeWrite.Products AS Products,
	|		RegisterRecordsSalesOrdersBeforeWrite.Characteristic AS Characteristic,
	|		RegisterRecordsSalesOrdersBeforeWrite.QuantityBeforeWrite AS QuantityBeforeWrite,
	|		RegisterRecordsSalesOrdersBeforeWrite.QuantityBeforeWrite AS QuantityChange,
	|		0 AS QuantityOnWrite
	|	FROM
	|		RegisterRecordsSalesOrdersBeforeWrite AS RegisterRecordsSalesOrdersBeforeWrite
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		RegisterRecordsSalesOrdersOnWrite.LineNumber,
	|		RegisterRecordsSalesOrdersOnWrite.Company,
	|		RegisterRecordsSalesOrdersOnWrite.SalesOrder,
	|		RegisterRecordsSalesOrdersOnWrite.Products,
	|		RegisterRecordsSalesOrdersOnWrite.Characteristic,
	|		0,
	|		CASE
	|			WHEN RegisterRecordsSalesOrdersOnWrite.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -RegisterRecordsSalesOrdersOnWrite.Quantity
	|			ELSE RegisterRecordsSalesOrdersOnWrite.Quantity
	|		END,
	|		RegisterRecordsSalesOrdersOnWrite.Quantity
	|	FROM
	|		AccumulationRegister.SalesOrders AS RegisterRecordsSalesOrdersOnWrite
	|	WHERE
	|		RegisterRecordsSalesOrdersOnWrite.Recorder = &Recorder) AS RegisterRecordsSalesOrdersChange
	|
	|GROUP BY
	|	RegisterRecordsSalesOrdersChange.Company,
	|	RegisterRecordsSalesOrdersChange.SalesOrder,
	|	RegisterRecordsSalesOrdersChange.Products,
	|	RegisterRecordsSalesOrdersChange.Characteristic
	|
	|HAVING
	|	SUM(RegisterRecordsSalesOrdersChange.QuantityChange) <> 0
	|
	|INDEX BY
	|	Company,
	|	SalesOrder,
	|	Products,
	|	Characteristic");
	
	Query.SetParameter("Recorder", Filter.Recorder.Value);
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	
	QueryResult = Query.Execute();
	
	QueryResultSelection = QueryResult.Select();
	QueryResultSelection.Next();
	
	// New changes were placed into temporary table "RegisterRecordsSalesOrdersChange".
	// The information on its existence and change records availability in it is added.
	StructureTemporaryTables.Insert("RegisterRecordsSalesOrdersChange", QueryResultSelection.Count > 0);
	
	// The "RegisterRecordsInventoryInWarehousesBeforeWrite" temporary table is deleted
	Query = New Query("DROP RegisterRecordsSalesOrdersBeforeWrite");
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	Query.Execute();
	
EndProcedure

#EndRegion

#Region EventsHandlers

// Procedure - event handler BeforeWrite record set.
//
Procedure BeforeWrite(Cancel, Replacing)
	
	If DataExchange.Load
		OR Not AdditionalProperties.Property("ForPosting")
		OR Not AdditionalProperties.ForPosting.Property("StructureTemporaryTables") Then
		Return;
	EndIf;
	
	GenerateSourceRecordsTable(Cancel, Replacing);
	
	GenerateTableOfOrders();
	InstallLocksOnDataForCalculatingSchedule();
	
EndProcedure

// Procedure - event handler OnWrite record set.
//
Procedure OnWrite(Cancel, Replacing)
	
	If DataExchange.Load
		OR Not AdditionalProperties.Property("ForPosting")
		OR Not AdditionalProperties.ForPosting.Property("StructureTemporaryTables") Then
		Return;
	EndIf;
	
	GenerateRecordsChangeTable(Cancel, Replacing);
	
	CalculateOrdersFulfilmentSchedule();
	
EndProcedure

#EndRegion

#EndIf