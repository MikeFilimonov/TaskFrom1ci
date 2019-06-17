#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

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

#Region Private

// Procedure calculates and writes the schedule of order execution.
// Shipping date is specified in "Period". Upon the actual shipment by order,
// the schedule is closed according to FIFO.
//
Procedure CalculateOrdersFulfilmentSchedule()
	
	OrdersTable = AdditionalProperties.OrdersTable;
	Query = New Query;
	Query.SetParameter("OrdersArray", OrdersTable.UnloadColumn("WorkOrder"));
	Query.Text =
	"SELECT
	|	WorkOrdersBalance.Company AS Company,
	|	WorkOrdersBalance.Products AS Products,
	|	WorkOrdersBalance.Characteristic AS Characteristic,
	|	WorkOrdersBalance.QuantityBalance AS QuantityBalance,
	|	WorkOrdersBalance.WorkOrder AS WorkOrder
	|INTO TU_Balance
	|FROM
	|	AccumulationRegister.WorkOrders.Balance(, WorkOrder IN (&OrdersArray)) AS WorkOrdersBalance
	|
	|INDEX BY
	|	Company,
	|	Products,
	|	Characteristic,
	|	WorkOrder
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CASE
	|		WHEN WorkOrders.ShipmentDate = DATETIME(1, 1, 1)
	|			THEN BEGINOFPERIOD(WorkOrders.Period, DAY)
	|		ELSE BEGINOFPERIOD(WorkOrders.ShipmentDate, DAY)
	|	END AS Period,
	|	WorkOrders.Company AS Company,
	|	WorkOrders.Products AS Products,
	|	WorkOrders.Characteristic AS Characteristic,
	|	SUM(WorkOrders.Quantity) AS QuantityPlan,
	|	WorkOrders.WorkOrder AS WorkOrder
	|INTO TU_RegisterRecordPlan
	|FROM
	|	AccumulationRegister.WorkOrders AS WorkOrders
	|WHERE
	|	WorkOrders.RecordType = VALUE(AccumulationRecordType.Receipt)
	|	AND WorkOrders.Quantity > 0
	|	AND WorkOrders.Active
	|	AND WorkOrders.WorkOrder IN(&OrdersArray)
	|
	|GROUP BY
	|	CASE
	|		WHEN WorkOrders.ShipmentDate = DATETIME(1, 1, 1)
	|			THEN BEGINOFPERIOD(WorkOrders.Period, DAY)
	|		ELSE BEGINOFPERIOD(WorkOrders.ShipmentDate, DAY)
	|	END,
	|	WorkOrders.Company,
	|	WorkOrders.Products,
	|	WorkOrders.Characteristic,
	|	WorkOrders.WorkOrder
	|
	|INDEX BY
	|	Company,
	|	Products,
	|	Characteristic,
	|	WorkOrder
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TU_Table.Period AS Period,
	|	TU_Table.Company AS Company,
	|	TU_Table.Products AS Products,
	|	TU_Table.Characteristic AS Characteristic,
	|	TU_Table.QuantityPlan AS QuantityPlan,
	|	ISNULL(TU_Balance.QuantityBalance, 0) AS QuantityBalance,
	|	TU_Table.WorkOrder AS WorkOrder
	|FROM
	|	TU_RegisterRecordPlan AS TU_Table
	|		LEFT JOIN TU_Balance AS TU_Balance
	|		ON TU_Table.Company = TU_Balance.Company
	|			AND TU_Table.Products = TU_Balance.Products
	|			AND TU_Table.Characteristic = TU_Balance.Characteristic
	|			AND TU_Table.WorkOrder = TU_Balance.WorkOrder
	|
	|ORDER BY
	|	WorkOrder,
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
		CurWorkOrder = Selection.WorkOrder;
		
		RecordSet.Filter.Order.Set(CurWorkOrder);
		
		// Delete the closed order from the table.
		OrdersTable.Delete(OrdersTable.Find(CurWorkOrder, "WorkOrder"));
		
		// Cycle by single order strings.
		TotalPlan = 0;
		TotalBalance = 0;
		StructureRecordSet = New Structure;
		While ThereAreRecordsInSelection AND Selection.WorkOrder = CurWorkOrder Do
			
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
				StructureRecordSet.Insert("WorkOrder", Selection.WorkOrder);
				
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
			Record.Order = StructureRecordSet.WorkOrder;
			Record.Completed = TotalPlan - TotalBalance;
		EndIf;
		
		RecordSet.Write(True);
		RecordSet.Clear();
		
	EndDo;
	
	// The register records should be cleared for unfinished orders.
	If OrdersTable.Count() > 0 Then
		For Each TabRow In OrdersTable Do
			
			RecordSet.Filter.Order.Set(TabRow.WorkOrder);
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
	|	TableWorkOrders.WorkOrder AS WorkOrder
	|FROM
	|	AccumulationRegister.WorkOrders AS TableWorkOrders
	|WHERE
	|	TableWorkOrders.Recorder = &Recorder";
	
	OrdersTable = Query.Execute().Unload();
	TableOfNewOrders = Unload(, "WorkOrder");
	TableOfNewOrders.GroupBy("WorkOrder");
	For Each Record In TableOfNewOrders Do
		
		If OrdersTable.Find(Record.WorkOrder, "WorkOrder") = Undefined Then
			OrdersTable.Add().WorkOrder = Record.WorkOrder;
		EndIf;
		
	EndDo;
	
	AdditionalProperties.Insert("OrdersTable", OrdersTable);
	
EndProcedure

// Procedure locks data for schedule calculation.
//
Procedure InstallLocksOnDataForCalculatingSchedule()
	
	Block = New DataLock;
	
	// Locking the register for balance calculation by orders.
	LockItem = Block.Add("AccumulationRegister.WorkOrders");
	LockItem.Mode = DataLockMode.Shared;
	LockItem.DataSource = AdditionalProperties.OrdersTable;
	LockItem.UseFromDataSource("WorkOrder", "WorkOrder");
	
	// Locking the record set.
	LockItem = Block.Add("InformationRegister.OrderFulfillmentSchedule");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = AdditionalProperties.OrdersTable;
	LockItem.UseFromDataSource("Order", "WorkOrder");
	
	Block.Lock();
	
EndProcedure

// Procedure forms the table of initial records of the register.
//
Procedure GenerateSourceRecordsTable(Cancel, Replacing)
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// Setting the exclusive lock of the current set of records of the registrar.
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.WorkOrders.RecordSet");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.SetValue("Recorder", Filter.Recorder.Value);
	Block.Lock();
	
	If Not StructureTemporaryTables.Property("RegisterRecordsWorkOrdersChange")
		OR (StructureTemporaryTables.Property("RegisterRecordsWorkOrdersChange")
			AND NOT StructureTemporaryTables.RegisterRecordsWorkOrdersChange) Then
		
		// If the "RegisterRecordsWorkOrdersChange" temporary table does not exist and
		// does not contain records on change of the set, it means that the set is written for the first time, and the set was
		// controlled for balances. Current state of the set is placed into the "RegisterRecordsWorkOrdersBeforeWrite"
		// temporary table to get the change of a new set with respect to the current set when writing.
		
		Query = New Query(
		"SELECT
		|	WorkOrders.LineNumber AS LineNumber,
		|	WorkOrders.Company AS Company,
		|	WorkOrders.WorkOrder AS WorkOrder,
		|	WorkOrders.Products AS Products,
		|	WorkOrders.Characteristic AS Characteristic,
		|	CASE
		|		WHEN WorkOrders.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN WorkOrders.Quantity
		|		ELSE -WorkOrders.Quantity
		|	END AS QuantityBeforeWrite
		|INTO RegisterRecordsWorkOrdersBeforeWrite
		|FROM
		|	AccumulationRegister.WorkOrders AS WorkOrders
		|WHERE
		|	WorkOrders.Recorder = &Recorder
		|	AND &Replacing");
		
		Query.SetParameter("Recorder", Filter.Recorder.Value);
		Query.SetParameter("Replacing", Replacing);
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		
	Else
		
		// If the "RegisterRecordsWorkOrdersChange" temporary table exists and
		// contains records about the set change, it means the set is written not for the first time and the set was not
		// controlled for balances. Current state of the set and current state of changes are placed into the
		// "RegisterRecordsWorkOrdersBeforeWrite" temporary table to get the change of a new set with respect to the initial
		// set when writing.
		
		Query = New Query(
		"SELECT
		|	RegisterRecordsWorkOrdersChange.LineNumber AS LineNumber,
		|	RegisterRecordsWorkOrdersChange.Company AS Company,
		|	RegisterRecordsWorkOrdersChange.WorkOrder AS WorkOrder,
		|	RegisterRecordsWorkOrdersChange.Products AS Products,
		|	RegisterRecordsWorkOrdersChange.Characteristic AS Characteristic,
		|	RegisterRecordsWorkOrdersChange.QuantityBeforeWrite AS QuantityBeforeWrite
		|INTO RegisterRecordsWorkOrdersBeforeWrite
		|FROM
		|	RegisterRecordsWorkOrdersChange AS RegisterRecordsWorkOrdersChange
		|
		|UNION ALL
		|
		|SELECT
		|	WorkOrders.LineNumber,
		|	WorkOrders.Company,
		|	WorkOrders.WorkOrder,
		|	WorkOrders.Products,
		|	WorkOrders.Characteristic,
		|	CASE
		|		WHEN WorkOrders.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN WorkOrders.Quantity
		|		ELSE -WorkOrders.Quantity
		|	END
		|FROM
		|	AccumulationRegister.WorkOrders AS WorkOrders
		|WHERE
		|	WorkOrders.Recorder = &Recorder
		|	AND &Replacing");
		
		Query.SetParameter("Recorder", Filter.Recorder.Value);
		Query.SetParameter("Replacing", Replacing);
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		
	EndIf;
	
	// Temporary table "RegisterRecordsWorkOrdersChange" is deleted
	// Information related to its existence is deleted.
	
	If StructureTemporaryTables.Property("RegisterRecordsWorkOrdersChange") Then
		
		Query = New Query("DROP RegisterRecordsWorkOrdersChange");
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		StructureTemporaryTables.Delete("RegisterRecordsWorkOrdersChange");
		
	EndIf;
	
EndProcedure

// Procedure forms the table of change records of the register.
//
Procedure GenerateRecordsChangeTable(Cancel, Replacing)
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// Change of a new set is calculated with respect to current one, taking into account the accumulated changes,
	// and the set is placed into the "RegisterRecordsWorkOrdersChange" temporary table.
	
	Query = New Query(
	"SELECT
	|	MIN(RegisterRecordsWorkOrdersChange.LineNumber) AS LineNumber,
	|	RegisterRecordsWorkOrdersChange.Company AS Company,
	|	RegisterRecordsWorkOrdersChange.WorkOrder AS WorkOrder,
	|	RegisterRecordsWorkOrdersChange.Products AS Products,
	|	RegisterRecordsWorkOrdersChange.Characteristic AS Characteristic,
	|	SUM(RegisterRecordsWorkOrdersChange.QuantityBeforeWrite) AS QuantityBeforeWrite,
	|	SUM(RegisterRecordsWorkOrdersChange.QuantityChange) AS QuantityChange,
	|	SUM(RegisterRecordsWorkOrdersChange.QuantityOnWrite) AS QuantityOnWrite
	|INTO RegisterRecordsWorkOrdersChange
	|FROM
	|	(SELECT
	|		RegisterRecordsWorkOrdersBeforeWrite.LineNumber AS LineNumber,
	|		RegisterRecordsWorkOrdersBeforeWrite.Company AS Company,
	|		RegisterRecordsWorkOrdersBeforeWrite.WorkOrder AS WorkOrder,
	|		RegisterRecordsWorkOrdersBeforeWrite.Products AS Products,
	|		RegisterRecordsWorkOrdersBeforeWrite.Characteristic AS Characteristic,
	|		RegisterRecordsWorkOrdersBeforeWrite.QuantityBeforeWrite AS QuantityBeforeWrite,
	|		RegisterRecordsWorkOrdersBeforeWrite.QuantityBeforeWrite AS QuantityChange,
	|		0 AS QuantityOnWrite
	|	FROM
	|		RegisterRecordsWorkOrdersBeforeWrite AS RegisterRecordsWorkOrdersBeforeWrite
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		RegisterRecordsWorkOrdersOnWrite.LineNumber,
	|		RegisterRecordsWorkOrdersOnWrite.Company,
	|		RegisterRecordsWorkOrdersOnWrite.WorkOrder,
	|		RegisterRecordsWorkOrdersOnWrite.Products,
	|		RegisterRecordsWorkOrdersOnWrite.Characteristic,
	|		0,
	|		CASE
	|			WHEN RegisterRecordsWorkOrdersOnWrite.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -RegisterRecordsWorkOrdersOnWrite.Quantity
	|			ELSE RegisterRecordsWorkOrdersOnWrite.Quantity
	|		END,
	|		RegisterRecordsWorkOrdersOnWrite.Quantity
	|	FROM
	|		AccumulationRegister.WorkOrders AS RegisterRecordsWorkOrdersOnWrite
	|	WHERE
	|		RegisterRecordsWorkOrdersOnWrite.Recorder = &Recorder) AS RegisterRecordsWorkOrdersChange
	|
	|GROUP BY
	|	RegisterRecordsWorkOrdersChange.Company,
	|	RegisterRecordsWorkOrdersChange.WorkOrder,
	|	RegisterRecordsWorkOrdersChange.Products,
	|	RegisterRecordsWorkOrdersChange.Characteristic
	|
	|HAVING
	|	SUM(RegisterRecordsWorkOrdersChange.QuantityChange) <> 0
	|
	|INDEX BY
	|	Company,
	|	WorkOrder,
	|	Products,
	|	Characteristic");
	
	Query.SetParameter("Recorder", Filter.Recorder.Value);
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	
	QueryResult = Query.Execute();
	
	QueryResultSelection = QueryResult.Select();
	QueryResultSelection.Next();
	
	// New changes were placed into temporary table "RegisterRecordsWorkOrdersChange".
	// The information on its existence and change records availability in it is added.
	StructureTemporaryTables.Insert("RegisterRecordsWorkOrdersChange", QueryResultSelection.Count > 0);
	
	// The "RegisterRecordsInventoryInWarehousesBeforeWrite" temporary table is deleted
	Query = New Query("DROP RegisterRecordsWorkOrdersBeforeWrite");
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	Query.Execute();
	
EndProcedure

#EndRegion

#EndIf