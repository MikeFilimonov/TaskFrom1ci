#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProgramInterface

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventoryInventory(DocumentRefCosting, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	// Setting the exclusive lock for the controlled inventory balances.
	Query.Text = 
	"SELECT
	|	TableInventory.Company AS Company,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	TableInventory.GLAccount AS GLAccount,
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.SalesOrder AS SalesOrder
	|FROM
	|	(SELECT
	|		TableInventory.Company AS Company,
	|		TableInventory.StructuralUnit AS StructuralUnit,
	|		TableInventory.GLAccount AS GLAccount,
	|		TableInventory.Products AS Products,
	|		TableInventory.Characteristic AS Characteristic,
	|		TableInventory.Batch AS Batch,
	|		TableInventory.SalesOrder AS SalesOrder
	|	FROM
	|		TemporaryTableInventory AS TableInventory
	|	WHERE
	|		TableInventory.SalesOrder <> VALUE(Document.SalesOrder.EmptyRef)
	|		AND TableInventory.SalesOrder <> VALUE(Document.WorkOrder.EmptyRef)
	|		AND TableInventory.SalesOrder <> UNDEFINED
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		TableInventory.Company,
	|		TableInventory.StructuralUnit,
	|		TableInventory.GLAccount,
	|		TableInventory.Products,
	|		TableInventory.Characteristic,
	|		TableInventory.Batch,
	|		UNDEFINED
	|	FROM
	|		TemporaryTableInventory AS TableInventory) AS TableInventory
	|
	|GROUP BY
	|	TableInventory.Company,
	|	TableInventory.StructuralUnit,
	|	TableInventory.GLAccount,
	|	TableInventory.Products,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	TableInventory.SalesOrder";
	
	QueryResult = Query.Execute();
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.Inventory");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;

	For Each ColumnQueryResult In QueryResult.Columns Do
		LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
	EndDo;
	Block.Lock();
	
	// Receiving inventory balances by cost.
	Query.Text = 	
	"SELECT
	|	InventoryBalances.Company AS Company,
	|	InventoryBalances.StructuralUnit AS StructuralUnit,
	|	InventoryBalances.GLAccount AS GLAccount,
	|	InventoryBalances.Products AS Products,
	|	InventoryBalances.Characteristic AS Characteristic,
	|	InventoryBalances.Batch AS Batch,
	|	InventoryBalances.SalesOrder AS SalesOrder,
	|	SUM(InventoryBalances.QuantityBalance) AS QuantityBalance,
	|	SUM(InventoryBalances.AmountBalance) AS AmountBalance
	|FROM
	|	(SELECT
	|		InventoryBalances.Company AS Company,
	|		InventoryBalances.StructuralUnit AS StructuralUnit,
	|		InventoryBalances.GLAccount AS GLAccount,
	|		InventoryBalances.Products AS Products,
	|		InventoryBalances.Characteristic AS Characteristic,
	|		InventoryBalances.Batch AS Batch,
	|		InventoryBalances.SalesOrder AS SalesOrder,
	|		SUM(InventoryBalances.QuantityBalance) AS QuantityBalance,
	|		SUM(InventoryBalances.AmountBalance) AS AmountBalance
	|	FROM
	|		AccumulationRegister.Inventory.Balance(
	|				&ControlTime,
	|				(Company, StructuralUnit, GLAccount, Products, Characteristic, Batch, SalesOrder) IN
	|					(SELECT
	|						TableInventory.Company,
	|						TableInventory.StructuralUnit,
	|						TableInventory.GLAccount,
	|						TableInventory.Products,
	|						TableInventory.Characteristic,
	|						TableInventory.Batch,
	|						TableInventory.SalesOrder
	|					FROM
	|						TemporaryTableInventory AS TableInventory
	|					WHERE
	|						TableInventory.SalesOrder <> VALUE(Document.SalesOrder.EmptyRef)
	|						AND TableInventory.SalesOrder <> VALUE(Document.WorkOrder.EmptyRef)
	|						AND TableInventory.SalesOrder <> UNDEFINED)) AS InventoryBalances
	|	
	|	GROUP BY
	|		InventoryBalances.Company,
	|		InventoryBalances.StructuralUnit,
	|		InventoryBalances.GLAccount,
	|		InventoryBalances.Products,
	|		InventoryBalances.Characteristic,
	|		InventoryBalances.Batch,
	|		InventoryBalances.SalesOrder
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		InventoryBalances.Company,
	|		InventoryBalances.StructuralUnit,
	|		InventoryBalances.GLAccount,
	|		InventoryBalances.Products,
	|		InventoryBalances.Characteristic,
	|		InventoryBalances.Batch,
	|		InventoryBalances.SalesOrder,
	|		SUM(InventoryBalances.QuantityBalance),
	|		SUM(InventoryBalances.AmountBalance)
	|	FROM
	|		AccumulationRegister.Inventory.Balance(
	|				&ControlTime,
	|				(Company, StructuralUnit, GLAccount, Products, Characteristic, Batch, SalesOrder) IN
	|					(SELECT
	|						TableInventory.Company,
	|						TableInventory.StructuralUnit,
	|						TableInventory.GLAccount,
	|						TableInventory.Products,
	|						TableInventory.Characteristic,
	|						TableInventory.Batch,
	|						UNDEFINED
	|					FROM
	|						TemporaryTableInventory AS TableInventory)) AS InventoryBalances
	|	
	|	GROUP BY
	|		InventoryBalances.Company,
	|		InventoryBalances.StructuralUnit,
	|		InventoryBalances.GLAccount,
	|		InventoryBalances.Products,
	|		InventoryBalances.Characteristic,
	|		InventoryBalances.Batch,
	|		InventoryBalances.SalesOrder
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsInventory.Company,
	|		DocumentRegisterRecordsInventory.StructuralUnit,
	|		DocumentRegisterRecordsInventory.GLAccount,
	|		DocumentRegisterRecordsInventory.Products,
	|		DocumentRegisterRecordsInventory.Characteristic,
	|		DocumentRegisterRecordsInventory.Batch,
	|		DocumentRegisterRecordsInventory.SalesOrder,
	|		CASE
	|			WHEN DocumentRegisterRecordsInventory.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN ISNULL(DocumentRegisterRecordsInventory.Quantity, 0)
	|			ELSE -ISNULL(DocumentRegisterRecordsInventory.Quantity, 0)
	|		END,
	|		CASE
	|			WHEN DocumentRegisterRecordsInventory.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN ISNULL(DocumentRegisterRecordsInventory.Amount, 0)
	|			ELSE -ISNULL(DocumentRegisterRecordsInventory.Amount, 0)
	|		END
	|	FROM
	|		AccumulationRegister.Inventory AS DocumentRegisterRecordsInventory
	|	WHERE
	|		DocumentRegisterRecordsInventory.Recorder = &Ref
	|		AND DocumentRegisterRecordsInventory.Period <= &ControlPeriod) AS InventoryBalances
	|
	|GROUP BY
	|	InventoryBalances.Company,
	|	InventoryBalances.StructuralUnit,
	|	InventoryBalances.GLAccount,
	|	InventoryBalances.Products,
	|	InventoryBalances.Characteristic,
	|	InventoryBalances.Batch,
	|	InventoryBalances.SalesOrder";
	
	Query.SetParameter("Ref", DocumentRefCosting);
	Query.SetParameter("ControlTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.PointInTime.Date);
	
	QueryResult = Query.Execute();
	
	TableInventoryBalances = QueryResult.Unload();
	TableInventoryBalances.Indexes.Add("Company,StructuralUnit,GLAccount,Products,Characteristic,Batch,SalesOrder");
	
	For n = 0 To StructureAdditionalProperties.TableForRegisterRecords.TableInventoryInventory.Count() - 1 Do
		
		RowTableInventory = StructureAdditionalProperties.TableForRegisterRecords.TableInventoryInventory[n];
		
		StructureForSearch = New Structure;
		StructureForSearch.Insert("Company", RowTableInventory.Company);
		StructureForSearch.Insert("StructuralUnit", RowTableInventory.StructuralUnit);
		StructureForSearch.Insert("GLAccount", RowTableInventory.GLAccount);
		StructureForSearch.Insert("Products", RowTableInventory.Products);
		StructureForSearch.Insert("Characteristic", RowTableInventory.Characteristic);
		StructureForSearch.Insert("Batch", RowTableInventory.Batch);
		
		QuantityRequiredReserve = RowTableInventory.Reserve;
		QuantityRequiredAvailableBalance = RowTableInventory.Quantity;
		
		If QuantityRequiredReserve > 0 Then
			
			QuantityRequiredAvailableBalance = QuantityRequiredAvailableBalance - QuantityRequiredReserve;
			
			StructureForSearch.Insert("SalesOrder", RowTableInventory.SalesOrder);
			
			BalanceRowsArray = TableInventoryBalances.FindRows(StructureForSearch);
			
			QuantityBalance = 0;
			AmountBalance = 0;
			
			If BalanceRowsArray.Count() > 0 Then
				QuantityBalance = BalanceRowsArray[0].QuantityBalance;
				AmountBalance = BalanceRowsArray[0].AmountBalance;
			EndIf;
			
			If QuantityBalance > 0 AND QuantityBalance > QuantityRequiredReserve Then

				AmountToBeWrittenOff = Round(AmountBalance * QuantityRequiredReserve / QuantityBalance , 2, 1);

				BalanceRowsArray[0].QuantityBalance = BalanceRowsArray[0].QuantityBalance - QuantityRequiredReserve;
				BalanceRowsArray[0].AmountBalance = BalanceRowsArray[0].AmountBalance - AmountToBeWrittenOff;

			ElsIf QuantityBalance = QuantityRequiredReserve Then

				AmountToBeWrittenOff = AmountBalance;

				BalanceRowsArray[0].QuantityBalance = 0;
				BalanceRowsArray[0].AmountBalance = 0;

			Else
				AmountToBeWrittenOff = 0;	
			EndIf;
			
			// Write inventory off the warehouse (producing department).
			TableRowExpense = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
			FillPropertyValues(TableRowExpense, RowTableInventory);
			
			TableRowExpense.Amount = AmountToBeWrittenOff;
			TableRowExpense.Quantity = QuantityRequiredReserve;
			TableRowExpense.ProductionExpenses = True;
			
			// Assign written off stocks to either inventory cost in the warehouse, or to WIP costs.
			If Round(AmountToBeWrittenOff, 2, 1) <> 0 Then
				
				TableRowReceipt = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
				FillPropertyValues(TableRowReceipt, RowTableInventory);
					
				TableRowReceipt.RecordType = AccumulationRecordType.Receipt;
					
				TableRowReceipt.Company = RowTableInventory.Company;
				TableRowReceipt.StructuralUnit = RowTableInventory.StructuralUnitCorr;
				TableRowReceipt.GLAccount = RowTableInventory.CorrGLAccount;
				TableRowReceipt.Products = RowTableInventory.ProductsCorr;
				TableRowReceipt.Characteristic = RowTableInventory.CharacteristicCorr;
				TableRowReceipt.Batch = RowTableInventory.BatchCorr;
				TableRowReceipt.Specification = RowTableInventory.SpecificationCorr;
				TableRowReceipt.SalesOrder = RowTableInventory.CustomerCorrOrder;
					
				TableRowReceipt.StructuralUnitCorr = RowTableInventory.StructuralUnit;
				TableRowReceipt.CorrGLAccount = RowTableInventory.GLAccount;
				TableRowReceipt.ProductsCorr = RowTableInventory.Products;
				TableRowReceipt.CharacteristicCorr = RowTableInventory.Characteristic;
				TableRowReceipt.BatchCorr = RowTableInventory.Batch;
				TableRowReceipt.SpecificationCorr = RowTableInventory.Specification;
				TableRowReceipt.CustomerCorrOrder = RowTableInventory.SalesOrder;
					
				TableRowReceipt.Amount = AmountToBeWrittenOff;
				TableRowReceipt.Quantity = 0;
					
				TableRowReceipt.GLAccount = RowTableInventory.CorrGLAccount;
				TableRowReceipt.RecordKindAccountingJournalEntries = AccountingRecordType.Debit;
				
				// Generate postings.
				If Round(AmountToBeWrittenOff, 2, 1) <> 0 Then
					RowTableAccountingJournalEntries = StructureAdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries.Add();
					FillPropertyValues(RowTableAccountingJournalEntries, TableRowReceipt);
				EndIf;
				
			EndIf;
			
		EndIf;
		
		If QuantityRequiredAvailableBalance > 0 Then
			
			StructureForSearch.Insert("SalesOrder", Undefined);
			
			BalanceRowsArray = TableInventoryBalances.FindRows(StructureForSearch);
			
			QuantityBalance = 0;
			AmountBalance = 0;
			
			If BalanceRowsArray.Count() > 0 Then
				QuantityBalance = BalanceRowsArray[0].QuantityBalance;
				AmountBalance = BalanceRowsArray[0].AmountBalance;
			EndIf;
			
			If QuantityBalance > 0 AND QuantityBalance > QuantityRequiredAvailableBalance Then

				AmountToBeWrittenOff = Round(AmountBalance * QuantityRequiredAvailableBalance / QuantityBalance , 2, 1);

				BalanceRowsArray[0].QuantityBalance = BalanceRowsArray[0].QuantityBalance - QuantityRequiredAvailableBalance;
				BalanceRowsArray[0].AmountBalance = BalanceRowsArray[0].AmountBalance - AmountToBeWrittenOff;

			ElsIf QuantityBalance = QuantityRequiredAvailableBalance Then

				AmountToBeWrittenOff = AmountBalance;

				BalanceRowsArray[0].QuantityBalance = 0;
				BalanceRowsArray[0].AmountBalance = 0;

			Else
				AmountToBeWrittenOff = 0;	
			EndIf;
			
			// Expense.
			TableRowExpense = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
			FillPropertyValues(TableRowExpense, RowTableInventory);
			
			TableRowExpense.Amount = AmountToBeWrittenOff;
			TableRowExpense.Quantity = QuantityRequiredAvailableBalance;
			TableRowExpense.SalesOrder = Undefined;
			TableRowExpense.ProductionExpenses = True;
			
			// Receipt
			If Round(AmountToBeWrittenOff, 2, 1) <> 0 Then
				
				TableRowReceipt = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
				FillPropertyValues(TableRowReceipt, RowTableInventory);
					
				TableRowReceipt.RecordType = AccumulationRecordType.Receipt;
					
				TableRowReceipt.Company = RowTableInventory.Company;
				TableRowReceipt.StructuralUnit = RowTableInventory.StructuralUnitCorr;
				TableRowReceipt.GLAccount = RowTableInventory.CorrGLAccount;
				TableRowReceipt.Products = RowTableInventory.ProductsCorr;
				TableRowReceipt.Characteristic = RowTableInventory.CharacteristicCorr;
				TableRowReceipt.Batch = RowTableInventory.BatchCorr;
				TableRowReceipt.Specification = RowTableInventory.SpecificationCorr;
				TableRowReceipt.SalesOrder = RowTableInventory.CustomerCorrOrder;
					
				TableRowReceipt.StructuralUnitCorr = RowTableInventory.StructuralUnit;
				TableRowReceipt.CorrGLAccount = RowTableInventory.GLAccount;
				TableRowReceipt.ProductsCorr = RowTableInventory.Products;
				TableRowReceipt.CharacteristicCorr = RowTableInventory.Characteristic;
				TableRowReceipt.BatchCorr = RowTableInventory.Batch;
				TableRowReceipt.SpecificationCorr = RowTableInventory.Specification;
				TableRowReceipt.CustomerCorrOrder = Undefined;
					
				TableRowReceipt.Amount = AmountToBeWrittenOff;
				TableRowReceipt.Quantity = 0;
					
				TableRowReceipt.GLAccount = RowTableInventory.CorrGLAccount;
				TableRowReceipt.RecordKindAccountingJournalEntries = AccountingRecordType.Debit;
				
				// Generate postings.
				If Round(AmountToBeWrittenOff, 2, 1) <> 0 Then
					RowTableAccountingJournalEntries = StructureAdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries.Add();
					FillPropertyValues(RowTableAccountingJournalEntries, TableRowReceipt);
				EndIf;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	StructureAdditionalProperties.TableForRegisterRecords.Delete("TableInventoryInventory");
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventoryDemand(DocumentRefCosting, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text = 
	"SELECT
	|	TableInventoryDemand.Company AS Company,
	|	VALUE(Enum.InventoryMovementTypes.Shipment) AS MovementType,
	|	TableInventoryDemand.SalesOrder AS SalesOrder,
	|	TableInventoryDemand.Products AS Products,
	|	TableInventoryDemand.Characteristic AS Characteristic
	|FROM
	|	TemporaryTableInventory AS TableInventoryDemand";
	
	QueryResult = Query.Execute();
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.InventoryDemand");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;

	For Each ColumnQueryResult In QueryResult.Columns Do
		LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
	EndDo;
	Block.Lock();
     	
	// Receive balance.
	Query.Text = 	
	"SELECT
	|	InventoryDemandBalances.Company AS Company,
	|	InventoryDemandBalances.SalesOrder AS SalesOrder,
	|	InventoryDemandBalances.Products AS Products,
	|	InventoryDemandBalances.Characteristic AS Characteristic,
	|	SUM(InventoryDemandBalances.Quantity) AS QuantityBalance
	|FROM
	|	(SELECT
	|		InventoryDemandBalances.Company AS Company,
	|		InventoryDemandBalances.SalesOrder AS SalesOrder,
	|		InventoryDemandBalances.Products AS Products,
	|		InventoryDemandBalances.Characteristic AS Characteristic,
	|		SUM(InventoryDemandBalances.QuantityBalance) AS Quantity
	|	FROM
	|		AccumulationRegister.InventoryDemand.Balance(
	|				&ControlTime,
	|				(Company, MovementType, SalesOrder, Products, Characteristic) In
	|					(SELECT
	|						TemporaryTableInventory.Company AS Company,
	|						VALUE(Enum.InventoryMovementTypes.Shipment) AS MovementType,
	|						TemporaryTableInventory.SalesOrder AS SalesOrder,
	|						TemporaryTableInventory.Products AS Products,
	|						TemporaryTableInventory.Characteristic AS Characteristic
	|					FROM
	|						TemporaryTableInventory AS TemporaryTableInventory)) AS InventoryDemandBalances
	|	
	|	GROUP BY
	|		InventoryDemandBalances.Company,
	|		InventoryDemandBalances.SalesOrder,
	|		InventoryDemandBalances.Products,
	|		InventoryDemandBalances.Characteristic
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsInventoryDemand.Company,
	|		DocumentRegisterRecordsInventoryDemand.SalesOrder,
	|		DocumentRegisterRecordsInventoryDemand.Products,
	|		DocumentRegisterRecordsInventoryDemand.Characteristic,
	|		CASE
	|			WHEN DocumentRegisterRecordsInventoryDemand.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN ISNULL(DocumentRegisterRecordsInventoryDemand.Quantity, 0)
	|			ELSE -ISNULL(DocumentRegisterRecordsInventoryDemand.Quantity, 0)
	|		END
	|	FROM
	|		AccumulationRegister.InventoryDemand AS DocumentRegisterRecordsInventoryDemand
	|	WHERE
	|		DocumentRegisterRecordsInventoryDemand.Recorder = &Ref
	|		AND DocumentRegisterRecordsInventoryDemand.Period <= &ControlPeriod) AS InventoryDemandBalances
	|
	|GROUP BY
	|	InventoryDemandBalances.Company,
	|	InventoryDemandBalances.SalesOrder,
	|	InventoryDemandBalances.Products,
	|	InventoryDemandBalances.Characteristic";
	
	Query.SetParameter("Ref", DocumentRefCosting);
	Query.SetParameter("ControlTime", StructureAdditionalProperties.ForPosting.ControlTime);
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.ControlPeriod);

	QueryResult = Query.Execute();
	
	TableInventoryDemandBalance = QueryResult.Unload();
	TableInventoryDemandBalance.Indexes.Add("Company,SalesOrder,Products,Characteristic");

	TemporaryTableInventoryDemand = StructureAdditionalProperties.TableForRegisterRecords.TableInventoryDemand.CopyColumns();
	
	For Each RowTablesForInventory In StructureAdditionalProperties.TableForRegisterRecords.TableInventoryDemand Do
		
		StructureForSearch = New Structure;
		StructureForSearch.Insert("Company", 		RowTablesForInventory.Company);
		StructureForSearch.Insert("SalesOrder", 	RowTablesForInventory.SalesOrder);
		StructureForSearch.Insert("Products", 	RowTablesForInventory.Products);
		StructureForSearch.Insert("Characteristic", 	RowTablesForInventory.Characteristic);
		
		BalanceRowsArray = TableInventoryDemandBalance.FindRows(StructureForSearch);
		If BalanceRowsArray.Count() > 0 Then
			
			If RowTablesForInventory.Quantity > BalanceRowsArray[0].QuantityBalance Then
				RowTablesForInventory.Quantity = BalanceRowsArray[0].QuantityBalance;
			EndIf;	
			
			TableRowExpense = TemporaryTableInventoryDemand.Add();
			FillPropertyValues(TableRowExpense, RowTablesForInventory);
			
		EndIf;
		
	EndDo;
	
	StructureAdditionalProperties.TableForRegisterRecords.TableInventoryDemand = TemporaryTableInventoryDemand;
	
EndProcedure

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure DataInitializationByInventory(DocumentRefCosting, StructureAdditionalProperties) Export

	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text = 
	"SELECT
	|	Inventory.LineNumber AS LineNumber,
	|	Inventory.Ref.Date AS Period,
	|	&Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	Inventory.Ref.StructuralUnit AS StructuralUnit,
	|	CASE
	|		WHEN &UseStorageBins
	|			THEN Inventory.Ref.Cell
	|		ELSE VALUE(Catalog.Cells.EmptyRef)
	|	END AS Cell,
	|	Inventory.ConsumptionGLAccount AS GLAccount,
	|	InventoryDistribution.ConsumptionGLAccount AS CorrGLAccount,
	|	Inventory.Products AS Products,
	|	InventoryDistribution.Products AS ProductsCorr,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN Inventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN InventoryDistribution.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS CharacteristicCorr,
	|	CASE
	|		WHEN &UseBatches
	|			THEN Inventory.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS Batch,
	|	CASE
	|		WHEN &UseBatches
	|			THEN InventoryDistribution.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS BatchCorr,
	|	Inventory.Specification AS Specification,
	|	InventoryDistribution.Specification AS SpecificationCorr,
	|	Inventory.SalesOrder AS SalesOrder,
	|	InventoryDistribution.SalesOrder AS CustomerCorrOrder,
	|	CASE
	|		WHEN VALUETYPE(Inventory.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN InventoryDistribution.Quantity
	|		ELSE InventoryDistribution.Quantity * Inventory.MeasurementUnit.Factor
	|	END AS Quantity,
	|	CASE
	|		WHEN VALUETYPE(Inventory.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN InventoryDistribution.Reserve
	|		ELSE InventoryDistribution.Reserve * Inventory.MeasurementUnit.Factor
	|	END AS Reserve,
	|	0 AS Amount,
	|	InventoryDistribution.ConsumptionGLAccount AS AccountDr,
	|	Inventory.ConsumptionGLAccount AS AccountCr,
	|	CAST(&InventoryDistribution AS STRING(100)) AS ContentOfAccountingRecord,
	|	CAST(&InventoryDistribution AS STRING(100)) AS Content
	|INTO TemporaryTableInventory
	|FROM
	|	Document.CostAllocation.Inventory AS Inventory
	|		LEFT JOIN Document.CostAllocation.InventoryDistribution AS InventoryDistribution
	|		ON Inventory.Ref = InventoryDistribution.Ref
	|			AND Inventory.ConnectionKey = InventoryDistribution.ConnectionKey
	|WHERE
	|	Inventory.Ref = &Ref
	|	AND InventoryDistribution.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(TableInventory.LineNumber) AS LineNumber,
	|	TableInventory.Period AS Period,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableInventory.Company AS Company,
	|	TableInventory.PlanningPeriod AS PlanningPeriod,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	TableInventory.StructuralUnit AS StructuralUnitCorr,
	|	TableInventory.GLAccount AS GLAccount,
	|	TableInventory.CorrGLAccount AS CorrGLAccount,
	|	TableInventory.Products AS Products,
	|	TableInventory.ProductsCorr AS ProductsCorr,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.CharacteristicCorr AS CharacteristicCorr,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.BatchCorr AS BatchCorr,
	|	TableInventory.Specification AS Specification,
	|	TableInventory.SpecificationCorr AS SpecificationCorr,
	|	CASE
	|		WHEN TableInventory.SalesOrder = VALUE(Document.SalesOrder.EmptyRef)
	|				OR TableInventory.SalesOrder = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE TableInventory.SalesOrder
	|	END AS SalesOrder,
	|	CASE
	|		WHEN TableInventory.CustomerCorrOrder = VALUE(Document.SalesOrder.EmptyRef)
	|				OR TableInventory.CustomerCorrOrder = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE TableInventory.CustomerCorrOrder
	|	END AS CustomerCorrOrder,
	|	TableInventory.AccountDr AS AccountDr,
	|	TableInventory.AccountCr AS AccountCr,
	|	TableInventory.ContentOfAccountingRecord AS Content,
	|	TableInventory.ContentOfAccountingRecord AS ContentOfAccountingRecord,
	|	FALSE AS ProductionExpenses,
	|	SUM(TableInventory.Quantity) AS Quantity,
	|	SUM(TableInventory.Reserve) AS Reserve,
	|	0 AS Amount
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|
	|GROUP BY
	|	TableInventory.Period,
	|	TableInventory.Company,
	|	TableInventory.PlanningPeriod,
	|	TableInventory.StructuralUnit,
	|	TableInventory.GLAccount,
	|	TableInventory.CorrGLAccount,
	|	TableInventory.Products,
	|	TableInventory.ProductsCorr,
	|	TableInventory.Characteristic,
	|	TableInventory.CharacteristicCorr,
	|	TableInventory.Batch,
	|	TableInventory.BatchCorr,
	|	TableInventory.Specification,
	|	TableInventory.SpecificationCorr,
	|	TableInventory.SalesOrder,
	|	TableInventory.CustomerCorrOrder,
	|	TableInventory.ContentOfAccountingRecord,
	|	TableInventory.AccountDr,
	|	TableInventory.AccountCr,
	|	TableInventory.StructuralUnit,
	|	TableInventory.ContentOfAccountingRecord
	|
	|ORDER BY
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(TableInventory.LineNumber) AS LineNumber,
	|	TableInventory.Period AS Period,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableInventory.Company AS Company,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	SUM(TableInventory.Quantity) AS Quantity
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|
	|GROUP BY
	|	TableInventory.Period,
	|	TableInventory.Company,
	|	TableInventory.StructuralUnit,
	|	TableInventory.Products,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch
	|
	|ORDER BY
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableInventory.Company AS Company,
	|	TableInventory.Period AS Period,
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	CASE
	|		WHEN TableInventory.SalesOrder = VALUE(Document.SalesOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE TableInventory.SalesOrder
	|	END AS Order,
	|	SUM(TableInventory.Quantity) AS Quantity
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|WHERE
	|	TableInventory.Batch.Status = VALUE(Enum.BatchStatuses.CounterpartysInventory)
	|
	|GROUP BY
	|	TableInventory.Company,
	|	TableInventory.Period,
	|	TableInventory.Products,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	CASE
	|		WHEN TableInventory.SalesOrder = VALUE(Document.SalesOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE TableInventory.SalesOrder
	|	END
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(TableInventory.LineNumber) AS LineNumber,
	|	TableInventory.Period AS Period,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	VALUE(Enum.InventoryMovementTypes.Shipment) AS MovementType,
	|	TableInventory.Company AS Company,
	|	TableInventory.SalesOrder AS SalesOrder,
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	SUM(TableInventory.Quantity) AS Quantity
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|
	|GROUP BY
	|	TableInventory.Period,
	|	TableInventory.Company,
	|	TableInventory.SalesOrder,
	|	TableInventory.Products,
	|	TableInventory.Characteristic
	|
	|ORDER BY
	|	LineNumber";
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();

	Query.SetParameter("Ref",					DocumentRefCosting);
	Query.SetParameter("ControlTime",			StructureAdditionalProperties.ForPosting.ControlTime);
	Query.SetParameter("Company",				StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("UseCharacteristics",	StructureAdditionalProperties.AccountingPolicy.UseCharacteristics);
	Query.SetParameter("UseBatches",			StructureAdditionalProperties.AccountingPolicy.UseBatches);
	Query.SetParameter("UseStorageBins",		StructureAdditionalProperties.AccountingPolicy.UseStorageBins);
	Query.SetParameter("InventoryDistribution",	NStr("en = 'Direct costs allocation'", MainLanguageCode));
	
	ResultsArray = Query.ExecuteBatch();
	
	// Determine table for inventory accounting.
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryInventory", ResultsArray[1].Unload());

	// Generate table for inventory accounting.
	GenerateTableInventoryInventory(DocumentRefCosting, StructureAdditionalProperties);

	// Generate table for warehouses.
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryInWarehouses", ResultsArray[2].Unload());

	// Determine a table of consumed raw material accepted for processing for which you will have to report in the future.
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableStockReceivedFromThirdParties", ResultsArray[3].Unload());
	
	// Determine table for movement by the needs of dependent demand positions.
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryDemand", ResultsArray[4].Unload());
	GenerateTableInventoryDemand(DocumentRefCosting, StructureAdditionalProperties);

EndProcedure

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefCosting, StructureAdditionalProperties) Export

	Query = New Query;
	Query.Text = 
	"SELECT
	|	Costs.LineNumber AS LineNumber,
	|	Costs.Ref.Date AS Period,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	&Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	Costs.Ref.StructuralUnit AS StructuralUnit,
	|	Costs.Ref.StructuralUnit AS StructuralUnitCorr,
	|	Costs.GLExpenseAccount AS GLAccount,
	|	CostAllocation.ConsumptionGLAccount AS CorrGLAccount,
	|	CostAllocation.Products AS ProductsCorr,
	|	UNDEFINED AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN CostAllocation.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS CharacteristicCorr,
	|	UNDEFINED AS Characteristic,
	|	CASE
	|		WHEN &UseBatches
	|			THEN CostAllocation.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS BatchCorr,
	|	UNDEFINED AS Batch,
	|	CostAllocation.Specification AS SpecificationCorr,
	|	UNDEFINED AS Specification,
	|	CASE
	|		WHEN Costs.SalesOrder = VALUE(Document.SalesOrder.EmptyRef)
	|				OR Costs.SalesOrder = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE Costs.SalesOrder
	|	END AS SalesOrder,
	|	CASE
	|		WHEN CostAllocation.SalesOrder = VALUE(Document.SalesOrder.EmptyRef)
	|				OR CostAllocation.SalesOrder = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE CostAllocation.SalesOrder
	|	END AS CustomerCorrOrder,
	|	CostAllocation.Amount AS Amount,
	|	VALUE(AccountingRecordType.Credit) AS RecordKindAccountingJournalEntries,
	|	FALSE AS ProductionExpenses,
	|	TRUE AS FixedCost,
	|	0 AS Quantity,
	|	CostAllocation.Products.ExpensesGLAccount AS AccountDr,
	|	Costs.GLExpenseAccount AS AccountCr,
	|	CAST(&DistributionExpenses AS STRING(100)) AS Content,
	|	CAST(&DistributionExpenses AS STRING(100)) AS ContentOfAccountingRecord
	|FROM
	|	Document.CostAllocation.Costs AS Costs
	|		LEFT JOIN Document.CostAllocation.CostAllocation AS CostAllocation
	|		ON Costs.Ref = CostAllocation.Ref
	|			AND Costs.ConnectionKey = CostAllocation.ConnectionKey
	|WHERE
	|	Costs.Ref = &Ref
	|	AND CostAllocation.Ref = &Ref";
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();

	Query.SetParameter("Ref",					DocumentRefCosting);
	Query.SetParameter("Company",				StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("UseCharacteristics",	StructureAdditionalProperties.AccountingPolicy.UseCharacteristics);
	Query.SetParameter("UseBatches",			StructureAdditionalProperties.AccountingPolicy.UseBatches);
	Query.SetParameter("DistributionExpenses",	NStr("en = 'Overhead costs allocation'", MainLanguageCode));
	
	// Generate transactions table structure.
	DriveServer.GenerateTransactionsTable(DocumentRefCosting, StructureAdditionalProperties);
	
	TableAccountingJournalEntries = DriveServer.EmptyAccountingJournalEntriesTable();
		
	TableInventory = Query.Execute().Unload();
	For n = 0 To TableInventory.Count() - 1 Do
		
		// Expense.
		RowTableSuppliesExpense = TableInventory[n];
		RowTableSuppliesExpense.ProductionExpenses = True;
		
		// Receipt.
		RowTableInventoryIncrease = TableInventory.Add();
		FillPropertyValues(RowTableInventoryIncrease, RowTableSuppliesExpense);

		RowTableInventoryIncrease.RecordType = AccumulationRecordType.Receipt;

		RowTableInventoryIncrease.Company = RowTableSuppliesExpense.Company; 
		
		RowTableInventoryIncrease.StructuralUnit = RowTableSuppliesExpense.StructuralUnitCorr;
		RowTableInventoryIncrease.GLAccount = RowTableSuppliesExpense.CorrGLAccount;
		RowTableInventoryIncrease.Products = RowTableSuppliesExpense.ProductsCorr; 
		RowTableInventoryIncrease.Characteristic = RowTableSuppliesExpense.CharacteristicCorr;
		RowTableInventoryIncrease.Batch = RowTableSuppliesExpense.BatchCorr;
		RowTableInventoryIncrease.Specification = RowTableSuppliesExpense.SpecificationCorr;
		RowTableInventoryIncrease.SalesOrder = RowTableSuppliesExpense.CustomerCorrOrder;

		RowTableInventoryIncrease.StructuralUnitCorr = RowTableSuppliesExpense.StructuralUnit;
		RowTableInventoryIncrease.CorrGLAccount = RowTableSuppliesExpense.GLAccount;
		RowTableInventoryIncrease.SpecificationCorr = RowTableSuppliesExpense.Specification;
		RowTableInventoryIncrease.CustomerCorrOrder = RowTableSuppliesExpense.SalesOrder;

		RowTableInventoryIncrease.RecordKindAccountingJournalEntries = AccountingRecordType.Debit;
		RowTableInventoryIncrease.ProductionExpenses = False;
		
		// Generate postings.
		If RowTableSuppliesExpense.Amount > 0 Then
			RowTableAccountingJournalEntries = TableAccountingJournalEntries.Add();
			FillPropertyValues(RowTableAccountingJournalEntries, RowTableSuppliesExpense);
		EndIf;
		
	EndDo;
	
	TableAccountingJournalEntries = DriveServer.AddOfflineAccountingJournalEntriesRecords(TableAccountingJournalEntries, DocumentRefCosting);
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventory", TableInventory);
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountingJournalEntries", TableAccountingJournalEntries);
	
	DataInitializationByInventory(DocumentRefCosting, StructureAdditionalProperties);
	
EndProcedure

// Controls the occurrence of negative balances.
//
Procedure RunControl(DocumentRefCosting, AdditionalProperties, Cancel, PostingDelete = False) Export
	
	If Not DriveServer.RunBalanceControl() Then
		Return;
	EndIf;

	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// If "RegisterRecordsInventoryChange"
	// temporary tables contain records, it is required to control costs writeoff.
	
	If StructureTemporaryTables.RegisterRecordsInventoryChange Then

		Query = New Query(
		"SELECT
		|	RegisterRecordsInventoryChange.LineNumber AS LineNumber,
		|	REFPRESENTATION(RegisterRecordsInventoryChange.Company) AS CompanyPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryChange.StructuralUnit) AS StructuralUnitPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryChange.GLAccount) AS GLAccountPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryChange.Products) AS ProductsPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryChange.Characteristic) AS CharacteristicPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryChange.Batch) AS BatchPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryChange.SalesOrder) AS SalesOrderPresentation,
		|	InventoryBalances.StructuralUnit.StructuralUnitType AS StructuralUnitType,
		|	REFPRESENTATION(InventoryBalances.Products.MeasurementUnit) AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsInventoryChange.QuantityChange, 0) + ISNULL(InventoryBalances.QuantityBalance, 0) AS BalanceInventory,
		|	ISNULL(InventoryBalances.QuantityBalance, 0) AS QuantityBalanceInventory,
		|	ISNULL(InventoryBalances.AmountBalance, 0) AS AmountBalanceInventory
		|FROM
		|	RegisterRecordsInventoryChange AS RegisterRecordsInventoryChange
		|		LEFT JOIN AccumulationRegister.Inventory.Balance(
		|				&ControlTime,
		|				(Company, StructuralUnit, GLAccount, Products, Characteristic, Batch, SalesOrder) IN
		|					(SELECT
		|						RegisterRecordsInventoryChange.Company AS Company,
		|						RegisterRecordsInventoryChange.StructuralUnit AS StructuralUnit,
		|						RegisterRecordsInventoryChange.GLAccount AS GLAccount,
		|						RegisterRecordsInventoryChange.Products AS Products,
		|						RegisterRecordsInventoryChange.Characteristic AS Characteristic,
		|						RegisterRecordsInventoryChange.Batch AS Batch,
		|						RegisterRecordsInventoryChange.SalesOrder AS SalesOrder
		|					FROM
		|						RegisterRecordsInventoryChange AS RegisterRecordsInventoryChange)) AS InventoryBalances
		|		ON RegisterRecordsInventoryChange.Company = InventoryBalances.Company
		|			AND RegisterRecordsInventoryChange.StructuralUnit = InventoryBalances.StructuralUnit
		|			AND RegisterRecordsInventoryChange.GLAccount = InventoryBalances.GLAccount
		|			AND RegisterRecordsInventoryChange.Products = InventoryBalances.Products
		|			AND RegisterRecordsInventoryChange.Characteristic = InventoryBalances.Characteristic
		|			AND RegisterRecordsInventoryChange.Batch = InventoryBalances.Batch
		|			AND RegisterRecordsInventoryChange.SalesOrder = InventoryBalances.SalesOrder
		|WHERE
		|	ISNULL(InventoryBalances.QuantityBalance, 0) < 0
		|
		|ORDER BY
		|	LineNumber");
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.SetParameter("ControlTime", AdditionalProperties.ForPosting.ControlTime);
		
		ResultsArray = Query.Execute();
		
		// Negative balance of inventory.
		If Not ResultsArray.IsEmpty() Then
			DocumentObjectCosting = DocumentRefCosting.GetObject();
			QueryResultSelection = ResultsArray.Select();
			DriveServer.ShowMessageAboutPostingToInventoryRegisterErrors(DocumentObjectCosting, QueryResultSelection, Cancel);
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region PrintInterface

// Fills in the list of printing commands.
// 
// Parameters:
//   PrintCommands - ValueTable - see fields' content in the PrintManagement.CreatePrintCommandsCollection function.
//
Procedure AddPrintCommands(PrintCommands) Export
	
	
	
EndProcedure

#EndRegion

#Region InfobaseUpdate

Procedure FillNewGLAccounts() Export
	
	DocumentName = "CostAllocation";
	
	Tables = New Array();
	
	// Table "CostAllocation"
	TableDecription = New Structure("Name, Conditions", "CostAllocation", New Array());
	
	GLAccountFields = ChartsOfAccounts.PrimaryChartOfAccounts.GLAccountFields();
	GLAccountFields.Source = "Products.ExpensesGLAccount";
	GLAccountFields.Receiver = "ConsumptionGLAccount";
	TableDecription.Conditions.Add(GLAccountFields);
	
	Tables.Add(TableDecription);
	
	// Table "Inventory"
	TableDecription = New Structure("Name, Conditions", "Inventory", New Array());
	
	GLAccountFields = ChartsOfAccounts.PrimaryChartOfAccounts.GLAccountFields();
	GLAccountFields.Source = "Products.ExpensesGLAccount";
	GLAccountFields.Receiver = "ConsumptionGLAccount";
	TableDecription.Conditions.Add(GLAccountFields);
	
	Tables.Add(TableDecription);
	
	// Table "InventoryDistribution"
	TableDecription = New Structure("Name, Conditions", "InventoryDistribution", New Array());
	
	GLAccountFields = ChartsOfAccounts.PrimaryChartOfAccounts.GLAccountFields();
	GLAccountFields.Source = "Products.ExpensesGLAccount";
	GLAccountFields.Receiver = "ConsumptionGLAccount";
	TableDecription.Conditions.Add(GLAccountFields);
	
	Tables.Add(TableDecription);
	
	ChartsOfAccounts.PrimaryChartOfAccounts.FillNewGLAccounts(DocumentName, Tables);
	
EndProcedure

#EndRegion


#EndIf