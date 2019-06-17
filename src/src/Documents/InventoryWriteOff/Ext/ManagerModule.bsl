#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventory(DocumentRefInventoryWriteOff, StructureAdditionalProperties)
	
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
	|	UNDEFINED AS SalesOrder
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|
	|GROUP BY
	|	TableInventory.Company,
	|	TableInventory.StructuralUnit,
	|	TableInventory.GLAccount,
	|	TableInventory.Products,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch";
	
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
	|		InventoryBalances.Batch
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
	|	InventoryBalances.Batch";
	
	Query.SetParameter("Ref", DocumentRefInventoryWriteOff);
	Query.SetParameter("ControlTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.PointInTime.Date);
	
	QueryResult = Query.Execute();
	
	TableInventoryBalances = QueryResult.Unload();
	TableInventoryBalances.Indexes.Add("Company,StructuralUnit,GLAccount,Products,Characteristic,Batch");
	
	TableAccountingJournalEntries = DriveServer.EmptyAccountingJournalEntriesTable();
	
	For n = 0 To StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Count() - 1 Do
		
		RowTableInventory = StructureAdditionalProperties.TableForRegisterRecords.TableInventory[n];
		
		StructureForSearch = New Structure;
		StructureForSearch.Insert("Company", RowTableInventory.Company);
		StructureForSearch.Insert("StructuralUnit", RowTableInventory.StructuralUnit);
		StructureForSearch.Insert("GLAccount", RowTableInventory.GLAccount);
		StructureForSearch.Insert("Products", RowTableInventory.Products);
		StructureForSearch.Insert("Characteristic", RowTableInventory.Characteristic);
		StructureForSearch.Insert("Batch", RowTableInventory.Batch);
		
		QuantityWanted = RowTableInventory.Quantity;
		
		If QuantityWanted > 0 Then
			
			BalanceRowsArray = TableInventoryBalances.FindRows(StructureForSearch);
			
			QuantityBalance = 0;
			AmountBalance = 0;
			
			If BalanceRowsArray.Count() > 0 Then
				QuantityBalance = BalanceRowsArray[0].QuantityBalance;
				AmountBalance = BalanceRowsArray[0].AmountBalance;
			EndIf;
			
			If QuantityBalance > 0 AND QuantityBalance > QuantityWanted Then

				AmountToBeWrittenOff = Round(AmountBalance * QuantityWanted / QuantityBalance , 2, 1);

				BalanceRowsArray[0].QuantityBalance = BalanceRowsArray[0].QuantityBalance - QuantityWanted;
				BalanceRowsArray[0].AmountBalance = BalanceRowsArray[0].AmountBalance - AmountToBeWrittenOff;

			ElsIf QuantityBalance = QuantityWanted Then

				AmountToBeWrittenOff = AmountBalance;

				BalanceRowsArray[0].QuantityBalance = 0;
				BalanceRowsArray[0].AmountBalance = 0;

			Else
				AmountToBeWrittenOff = 0;
			EndIf;
	
			RowTableInventory.Amount = AmountToBeWrittenOff;
			RowTableInventory.Quantity = QuantityWanted;
					
		EndIf;
		
		// Generate postings.
		If Round(RowTableInventory.Amount, 2, 1) <> 0 Then
			RowTableAccountingJournalEntries = TableAccountingJournalEntries.Add();
			FillPropertyValues(RowTableAccountingJournalEntries, RowTableInventory);
		EndIf;
		
	EndDo;
	
	StructureAdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries = 
		DriveServer.AddOfflineAccountingJournalEntriesRecords(TableAccountingJournalEntries, DocumentRefInventoryWriteOff);
	
EndProcedure

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefInventoryWriteOff, StructureAdditionalProperties) Export

	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text = 
	"SELECT
	|	Header.Ref AS Ref,
	|	Header.Date AS Date,
	|	Header.Company AS Company,
	|	Header.Cell AS Cell,
	|	Header.StructuralUnit AS StructuralUnit,
	|	Header.Correspondence AS Correspondence,
	|	Header.RetireInventoryFromOperation AS RetireInventoryFromOperation
	|INTO Header
	|FROM
	|	Document.InventoryWriteOff AS Header
	|WHERE
	|	Header.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	InventoryWriteOffInventory.LineNumber AS LineNumber,
	|	InventoryWriteOffInventory.ConnectionKey AS ConnectionKey,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	Header.Ref AS Ref,
	|	Header.Date AS Period,
	|	&Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	Header.StructuralUnit AS StructuralUnit,
	|	Header.Cell AS Cell,
	|	InventoryWriteOffInventory.InventoryGLAccount AS GLAccount,
	|	InventoryWriteOffInventory.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN InventoryWriteOffInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseBatches
	|			THEN InventoryWriteOffInventory.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS Batch,
	|	CASE
	|		WHEN VALUETYPE(InventoryWriteOffInventory.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN InventoryWriteOffInventory.Quantity
	|		ELSE InventoryWriteOffInventory.Quantity * InventoryWriteOffInventory.MeasurementUnit.Factor
	|	END AS Quantity,
	|	0 AS Amount,
	|	Header.Correspondence AS AccountDr,
	|	Header.Correspondence AS Correspondence,
	|	InventoryWriteOffInventory.InventoryGLAccount AS AccountCr,
	|	&InventoryWriteOff AS ContentOfAccountingRecord
	|INTO TemporaryTableInventory
	|FROM
	|	Document.InventoryWriteOff.Inventory AS InventoryWriteOffInventory
	|		INNER JOIN Header AS Header
	|		ON InventoryWriteOffInventory.Ref = Header.Ref
	|		INNER JOIN Catalog.BusinessUnits AS StructuralUnitRef
	|		ON (Header.StructuralUnit = StructuralUnitRef.Ref)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(TableInventory.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableInventory.Period AS Period,
	|	TableInventory.Company AS Company,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	TableInventory.GLAccount AS GLAccount,
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	UNDEFINED AS SalesOrder,
	|	SUM(TableInventory.Quantity) AS Quantity,
	|	SUM(TableInventory.Amount) AS Amount,
	|	TableInventory.PlanningPeriod AS PlanningPeriod,
	|	TableInventory.Ref AS SourceDocument,
	|	TableInventory.AccountDr AS AccountDr,
	|	TableInventory.AccountCr AS AccountCr,
	|	TableInventory.Correspondence AS CorrGLAccount,
	|	TableInventory.ContentOfAccountingRecord AS ContentOfAccountingRecord,
	|	TableInventory.ContentOfAccountingRecord AS Content,
	|	FALSE AS OfflineRecord
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|
	|GROUP BY
	|	TableInventory.Period,
	|	TableInventory.Company,
	|	TableInventory.StructuralUnit,
	|	TableInventory.GLAccount,
	|	TableInventory.Products,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	TableInventory.PlanningPeriod,
	|	TableInventory.Ref,
	|	TableInventory.AccountDr,
	|	TableInventory.AccountCr,
	|	TableInventory.Correspondence,
	|	TableInventory.ContentOfAccountingRecord,
	|	TableInventory.ContentOfAccountingRecord
	|
	|UNION ALL
	|
	|SELECT
	|	OfflineRecords.LineNumber,
	|	OfflineRecords.RecordType,
	|	OfflineRecords.Period,
	|	OfflineRecords.Company,
	|	OfflineRecords.StructuralUnit,
	|	OfflineRecords.GLAccount,
	|	OfflineRecords.Products,
	|	OfflineRecords.Characteristic,
	|	OfflineRecords.Batch,
	|	OfflineRecords.SalesOrder,
	|	OfflineRecords.Quantity,
	|	OfflineRecords.Amount,
	|	UNDEFINED,
	|	OfflineRecords.SourceDocument,
	|	UNDEFINED,
	|	UNDEFINED,
	|	OfflineRecords.CorrGLAccount,
	|	OfflineRecords.ContentOfAccountingRecord,
	|	OfflineRecords.ContentOfAccountingRecord,
	|	OfflineRecords.OfflineRecord
	|FROM
	|	AccumulationRegister.Inventory AS OfflineRecords
	|WHERE
	|	OfflineRecords.Recorder = &Ref
	|	AND OfflineRecords.OfflineRecord
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableInventory.LineNumber AS LineNumber,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableInventory.Period AS Period,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	TableInventory.Cell AS Cell,
	|	TableInventory.Company AS Company,
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.Quantity AS Quantity
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableInventory.Ref.Date AS Period,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableInventory.Period AS EventDate,
	|	VALUE(Enum.SerialNumbersOperations.Expense) AS Operation,
	|	TableSerialNumbers.SerialNumber AS SerialNumber,
	|	&Company AS Company,
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	TableInventory.Cell AS Cell,
	|	1 AS Quantity
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|		INNER JOIN Document.InventoryWriteOff.SerialNumbers AS TableSerialNumbers
	|		ON TableInventory.Ref = TableSerialNumbers.Ref
	|			AND TableInventory.ConnectionKey = TableSerialNumbers.ConnectionKey
	|WHERE
	|	&UseSerialNumbers
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Inventory.Ref AS Ref,
	|	SUM(Inventory.Amount) AS Amount
	|INTO AmountOfExpenses
	|FROM
	|	TemporaryTableInventory AS Inventory
	|
	|GROUP BY
	|	Inventory.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Header.Date AS Period,
	|	Header.Company AS Company,
	|	Header.StructuralUnit AS StructuralUnit,
	|	VALUE(Catalog.LinesOfBusiness.Other) AS BusinessLine,
	|	UNDEFINED AS SalesOrder,
	|	Header.Correspondence AS GLAccount,
	|	0 AS AmountIncome,
	|	Expenses.Amount AS AmountExpense,
	|	&ReceiptExpenses AS ContentOfAccountingRecord,
	|	FALSE AS OfflineRecord
	|FROM
	|	AmountOfExpenses AS Expenses
	|		INNER JOIN Header AS Header
	|		ON (Header.Ref = Expenses.Ref)
	|		INNER JOIN ChartOfAccounts.PrimaryChartOfAccounts AS ChartOfAccounts
	|		ON (Header.Correspondence = ChartOfAccounts.Ref)
	|WHERE
	|	Expenses.Amount > 0
	|	AND ChartOfAccounts.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherExpenses)
	|
	|UNION ALL
	|
	|SELECT
	|	OfflineRecords.Period,
	|	OfflineRecords.Company,
	|	OfflineRecords.StructuralUnit,
	|	OfflineRecords.BusinessLine,
	|	OfflineRecords.SalesOrder,
	|	OfflineRecords.GLAccount,
	|	OfflineRecords.AmountIncome,
	|	OfflineRecords.AmountExpense,
	|	OfflineRecords.ContentOfAccountingRecord,
	|	OfflineRecords.OfflineRecord
	|FROM
	|	AccumulationRegister.IncomeAndExpenses AS OfflineRecords
	|WHERE
	|	OfflineRecords.Recorder = &Ref
	|	AND OfflineRecords.OfflineRecord";
	
	AccountingPolicy = StructureAdditionalProperties.AccountingPolicy;
	
	Query.SetParameter("Ref", DocumentRefInventoryWriteOff);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("UseCharacteristics", AccountingPolicy.UseCharacteristics);
	Query.SetParameter("UseStorageBins", AccountingPolicy.UseStorageBins);
	Query.SetParameter("UseBatches", AccountingPolicy.UseBatches);
	
	Query.SetParameter("UseSerialNumbers", AccountingPolicy.UseSerialNumbers);

	FillAmount = (AccountingPolicy.InventoryValuationMethod = Enums.InventoryValuationMethods.WeightedAverage);
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();
	
	Query.SetParameter("InventoryWriteOff", NStr("en = 'Inventory write-off'", MainLanguageCode));
	Query.SetParameter("ReceiptExpenses", NStr("en = 'Other expenses'", MainLanguageCode));
	
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventory", ResultsArray[2].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryInWarehouses", ResultsArray[3].Unload());
	
	// Serial numbers
	QueryResult4 = ResultsArray[4].Unload();
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbersInWarranty", QueryResult4);
	If AccountingPolicy.SerialNumbersBalance Then
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbersBalance", QueryResult4);
	Else
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbersBalance", New ValueTable);
	EndIf;
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpenses", ResultsArray[6].Unload());
	
	// Generate an empty table of postings.
	DriveServer.GenerateTransactionsTable(DocumentRefInventoryWriteOff, StructureAdditionalProperties);
	
	If FillAmount Then
		// Calculation of the inventory write-off cost.
		GenerateTableInventory(DocumentRefInventoryWriteOff, StructureAdditionalProperties);
	Else
		TableAccountingJournalEntries = AccountingOfflineRecords(DocumentRefInventoryWriteOff);
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountingJournalEntries", TableAccountingJournalEntries);
	EndIf;
	
EndProcedure

// Controls the occurrence of negative balances.
//
Procedure RunControl(DocumentRefInventoryWriteOff, AdditionalProperties, Cancel, PostingDelete = False) Export
	
	If Not DriveServer.RunBalanceControl() Then
		Return;
	EndIf;

	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// If the "InventoryTransferAtWarehouseChange",
	// "RegisterRecordsInventoryChange" temporary tables contain records, it is necessary to control the sales of goods.
	If StructureTemporaryTables.RegisterRecordsInventoryInWarehousesChange
		OR StructureTemporaryTables.RegisterRecordsInventoryChange
		OR StructureTemporaryTables.RegisterRecordsSerialNumbersChange Then
		
		Query = New Query(
		"SELECT
		|	RegisterRecordsInventoryInWarehousesChange.LineNumber AS LineNumber,
		|	REFPRESENTATION(RegisterRecordsInventoryInWarehousesChange.Company) AS CompanyPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryInWarehousesChange.StructuralUnit) AS StructuralUnitPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryInWarehousesChange.Products) AS ProductsPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryInWarehousesChange.Characteristic) AS CharacteristicPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryInWarehousesChange.Batch) AS BatchPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryInWarehousesChange.Cell) AS PresentationCell,
		|	InventoryInWarehousesOfBalance.StructuralUnit.StructuralUnitType AS StructuralUnitType,
		|	REFPRESENTATION(InventoryInWarehousesOfBalance.Products.MeasurementUnit) AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsInventoryInWarehousesChange.QuantityChange, 0) + ISNULL(InventoryInWarehousesOfBalance.QuantityBalance, 0) AS BalanceInventoryInWarehouses,
		|	ISNULL(InventoryInWarehousesOfBalance.QuantityBalance, 0) AS QuantityBalanceInventoryInWarehouses
		|FROM
		|	RegisterRecordsInventoryInWarehousesChange AS RegisterRecordsInventoryInWarehousesChange
		|		LEFT JOIN AccumulationRegister.InventoryInWarehouses.Balance(
		|				&ControlTime,
		|				(Company, StructuralUnit, Products, Characteristic, Batch, Cell) IN
		|					(SELECT
		|						RegisterRecordsInventoryInWarehousesChange.Company AS Company,
		|						RegisterRecordsInventoryInWarehousesChange.StructuralUnit AS StructuralUnit,
		|						RegisterRecordsInventoryInWarehousesChange.Products AS Products,
		|						RegisterRecordsInventoryInWarehousesChange.Characteristic AS Characteristic,
		|						RegisterRecordsInventoryInWarehousesChange.Batch AS Batch,
		|						RegisterRecordsInventoryInWarehousesChange.Cell AS Cell
		|					FROM
		|						RegisterRecordsInventoryInWarehousesChange AS RegisterRecordsInventoryInWarehousesChange)) AS InventoryInWarehousesOfBalance
		|		ON RegisterRecordsInventoryInWarehousesChange.Company = InventoryInWarehousesOfBalance.Company
		|			AND RegisterRecordsInventoryInWarehousesChange.StructuralUnit = InventoryInWarehousesOfBalance.StructuralUnit
		|			AND RegisterRecordsInventoryInWarehousesChange.Products = InventoryInWarehousesOfBalance.Products
		|			AND RegisterRecordsInventoryInWarehousesChange.Characteristic = InventoryInWarehousesOfBalance.Characteristic
		|			AND RegisterRecordsInventoryInWarehousesChange.Batch = InventoryInWarehousesOfBalance.Batch
		|			AND RegisterRecordsInventoryInWarehousesChange.Cell = InventoryInWarehousesOfBalance.Cell
		|WHERE
		|	ISNULL(InventoryInWarehousesOfBalance.QuantityBalance, 0) < 0
		|
		|ORDER BY
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
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
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	RegisterRecordsSerialNumbersChange.LineNumber AS LineNumber,
		|	RegisterRecordsSerialNumbersChange.SerialNumber AS SerialNumberPresentation,
		|	RegisterRecordsSerialNumbersChange.StructuralUnit AS StructuralUnitPresentation,
		|	RegisterRecordsSerialNumbersChange.Products AS ProductsPresentation,
		|	RegisterRecordsSerialNumbersChange.Characteristic AS CharacteristicPresentation,
		|	RegisterRecordsSerialNumbersChange.Batch AS BatchPresentation,
		|	RegisterRecordsSerialNumbersChange.Cell AS PresentationCell,
		|	SerialNumbersBalance.StructuralUnit.StructuralUnitType AS StructuralUnitType,
		|	SerialNumbersBalance.Products.MeasurementUnit AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsSerialNumbersChange.QuantityChange, 0) + ISNULL(SerialNumbersBalance.QuantityBalance, 0) AS BalanceSerialNumbers,
		|	ISNULL(SerialNumbersBalance.QuantityBalance, 0) AS QuantityBalanceSerialNumbers
		|FROM
		|	RegisterRecordsSerialNumbersChange AS RegisterRecordsSerialNumbersChange
		|		INNER JOIN AccumulationRegister.SerialNumbers.Balance(&ControlTime, ) AS SerialNumbersBalance
		|		ON RegisterRecordsSerialNumbersChange.StructuralUnit = SerialNumbersBalance.StructuralUnit
		|			AND RegisterRecordsSerialNumbersChange.Products = SerialNumbersBalance.Products
		|			AND RegisterRecordsSerialNumbersChange.Characteristic = SerialNumbersBalance.Characteristic
		|			AND RegisterRecordsSerialNumbersChange.Batch = SerialNumbersBalance.Batch
		|			AND RegisterRecordsSerialNumbersChange.SerialNumber = SerialNumbersBalance.SerialNumber
		|			AND RegisterRecordsSerialNumbersChange.Cell = SerialNumbersBalance.Cell
		|			AND (ISNULL(SerialNumbersBalance.QuantityBalance, 0) < 0)
		|
		|ORDER BY
		|	LineNumber");
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.SetParameter("ControlTime", AdditionalProperties.ForPosting.ControlTime);
		
		ResultsArray = Query.ExecuteBatch();
		
		If Not ResultsArray[0].IsEmpty()
			OR Not ResultsArray[1].IsEmpty()
			OR NOT ResultsArray[2].IsEmpty() Then
			DocumentObjectInventoryWriteOff = DocumentRefInventoryWriteOff.GetObject()
		EndIf;
		
		// Negative balance of inventory in the warehouse.
		If Not ResultsArray[0].IsEmpty() Then
			QueryResultSelection = ResultsArray[0].Select();
			DriveServer.ShowMessageAboutPostingToInventoryInWarehousesRegisterErrors(DocumentObjectInventoryWriteOff, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance of inventory and cost accounting.
		If Not ResultsArray[1].IsEmpty() Then
			QueryResultSelection = ResultsArray[1].Select();
			DriveServer.ShowMessageAboutPostingToInventoryRegisterErrors(DocumentObjectInventoryWriteOff, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance of serial numbers in the warehouse.
		If NOT ResultsArray[2].IsEmpty() Then
			QueryResultSelection = ResultsArray[2].Select();
			DriveServer.ShowMessageAboutPostingSerialNumbersRegisterErrors(DocumentObjectInventoryWriteOff, QueryResultSelection, Cancel);
		EndIf;
		
	EndIf;
	
EndProcedure

Function AccountingOfflineRecords(DocumentRef)
	
	Query = New Query(
	"SELECT
	|	OfflineRecords.Period AS Period,
	|	OfflineRecords.AccountDr AS AccountDr,
	|	OfflineRecords.AccountCr AS AccountCr,
	|	OfflineRecords.Company AS Company,
	|	OfflineRecords.PlanningPeriod AS PlanningPeriod,
	|	OfflineRecords.CurrencyDr AS CurrencyDr,
	|	OfflineRecords.CurrencyCr AS CurrencyCr,
	|	OfflineRecords.Amount AS Amount,
	|	OfflineRecords.AmountCurDr AS AmountCurDr,
	|	OfflineRecords.AmountCurCr AS AmountCurCr,
	|	OfflineRecords.Content AS Content,
	|	OfflineRecords.OfflineRecord AS OfflineRecord
	|FROM
	|	AccountingRegister.AccountingJournalEntries AS OfflineRecords
	|WHERE
	|	OfflineRecords.Recorder = &Ref
	|	AND OfflineRecords.OfflineRecord
	|");
	
	Query.SetParameter("Ref", DocumentRef);
	
	Return Query.Execute().Unload();
	
EndFunction

#Region PrintInterface

Procedure GenerateMerchandiseFillingForm(SpreadsheetDocument, CurrentDocument)
	
	Query = New Query();
	Query.SetParameter("CurrentDocument", CurrentDocument);
	Query.Text = 
	"SELECT
	|	InventoryWriteOff.Date AS DocumentDate,
	|	InventoryWriteOff.Number AS Number,
	|	InventoryWriteOff.Company.Prefix AS Prefix,
	|	InventoryWriteOff.StructuralUnit AS WarehousePresentation,
	|	InventoryWriteOff.Cell AS CellPresentation,
	|	InventoryWriteOff.Inventory.(
	|		LineNumber AS LineNumber,
	|		Products.Warehouse AS Warehouse,
	|		Products.Cell AS Cell,
	|		CASE
	|			WHEN (CAST(InventoryWriteOff.Inventory.Products.DescriptionFull AS String(100))) = """"
	|				THEN InventoryWriteOff.Inventory.Products.Description
	|			ELSE InventoryWriteOff.Inventory.Products.DescriptionFull
	|		END AS InventoryItem,
	|		Products.SKU AS SKU,
	|		Products.Code AS Code,
	|		MeasurementUnit.Description AS MeasurementUnit,
	|		Quantity AS Quantity,
	|		Characteristic,
	|		Products.ProductsType AS ProductsType,
	|		ConnectionKey
	|	),
	|	InventoryWriteOff.SerialNumbers.(
	|		SerialNumber,
	|		ConnectionKey
	|	)
	|FROM
	|	Document.InventoryWriteOff AS InventoryWriteOff
	|WHERE
	|	InventoryWriteOff.Ref = &CurrentDocument
	|
	|ORDER BY
	|	LineNumber";
	
	Header = Query.Execute().Select();
	Header.Next();
	
	LinesSelectionInventory = Header.Inventory.Select();
	LinesSelectionSerialNumbers = Header.SerialNumbers.Select();
	
	SpreadsheetDocument.PrintParametersName = "PRINT_PARAMETERS_InventoryWriteOff_MerchandiseFillingForm";
	
	Template = PrintManagement.PrintedFormsTemplate("Document.InventoryWriteOff.PF_MXL_MerchandiseFillingForm");
	
	If Header.DocumentDate < Date('20110101') Then
		DocumentNumber = DriveServer.GetNumberForPrinting(Header.Number, Header.Prefix);
	Else
		DocumentNumber = ObjectPrefixationClientServer.GetNumberForPrinting(Header.Number, True, True);
	EndIf;		
	
	TemplateArea = Template.GetArea("Title");
	TemplateArea.Parameters.HeaderText = StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en = 'Inventory write-off #%1 dated %2.'"),
		DocumentNumber,
		Format(Header.DocumentDate, "DLF=DD"));
											
	SpreadsheetDocument.Put(TemplateArea);
	
	TemplateArea = Template.GetArea("Warehouse");
	TemplateArea.Parameters.WarehousePresentation = Header.WarehousePresentation;
	SpreadsheetDocument.Put(TemplateArea);
	
	If Constants.UseStorageBins.Get() Then
		
		TemplateArea = Template.GetArea("Cell");
		TemplateArea.Parameters.CellPresentation = Header.CellPresentation;
		SpreadsheetDocument.Put(TemplateArea);
		
	EndIf;			
	
	TemplateArea = Template.GetArea("PrintingTime");
	TemplateArea.Parameters.PrintingTime = StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en = 'Date and time of printing: %1. User: %2.'"),
		CurrentDate(),
		Users.CurrentUser());
	SpreadsheetDocument.Put(TemplateArea);
	
	TemplateArea = Template.GetArea("TableHeader");
	SpreadsheetDocument.Put(TemplateArea);
	TemplateArea = Template.GetArea("String");
	
	While LinesSelectionInventory.Next() Do

		If Not LinesSelectionInventory.ProductsType = Enums.ProductsTypes.InventoryItem Then
			Continue;
		EndIf;	
			
		TemplateArea.Parameters.Fill(LinesSelectionInventory);
		
		StringSerialNumbers = WorkWithSerialNumbers.SerialNumbersStringFromSelection(LinesSelectionSerialNumbers, LinesSelectionInventory.ConnectionKey);
		TemplateArea.Parameters.InventoryItem = DriveServer.GetProductsPresentationForPrinting(LinesSelectionInventory.InventoryItem, 
																LinesSelectionInventory.Characteristic, LinesSelectionInventory.SKU, StringSerialNumbers);
								
		SpreadsheetDocument.Put(TemplateArea);
						
	EndDo;

	TemplateArea = Template.GetArea("Total");
	SpreadsheetDocument.Put(TemplateArea);

	
EndProcedure

Function PrintForm(ObjectsArray, PrintObjects, TemplateName)
	
	SpreadsheetDocument = New SpreadsheetDocument;
	SpreadsheetDocument.PrintParametersKey = "PrintParameters_InventoryWriteOff";

	FirstDocument = True;
	
	For Each CurrentDocument In ObjectsArray Do
	
		If Not FirstDocument Then
			SpreadsheetDocument.PutHorizontalPageBreak();
		EndIf;
		FirstDocument = False;
		
		FirstLineNumber = SpreadsheetDocument.TableHeight + 1;
		
		If TemplateName = "MerchandiseFillingForm" Then
			
			GenerateMerchandiseFillingForm(SpreadsheetDocument, CurrentDocument);
			
		EndIf;
		
		PrintManagement.SetDocumentPrintArea(SpreadsheetDocument, FirstLineNumber, PrintObjects, CurrentDocument);
		
	EndDo;
	
	SpreadsheetDocument.FitToPage = True;
	
	Return SpreadsheetDocument;
	
EndFunction

// Generate printed forms of objects
//
// Incoming:
//   TemplateNames   - String    - Names of layouts separated by commas
//   ObjectsArray    - Array     - Array of refs to objects that need to be printed 
//   PrintParameters - Structure - Structure of additional printing parameters
//
// Outgoing:
//   PrintFormsCollection - Values table - Generated table documents 
//   OutputParameters     - Structure    - Parameters of generated table documents
//
Procedure Print(ObjectsArray, PrintParameters, PrintFormsCollection, PrintObjects, OutputParameters) Export
	
	If PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "MerchandiseFillingForm") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection, "MerchandiseFillingForm", "Merchandise filling form", PrintForm(ObjectsArray, PrintObjects, "MerchandiseFillingForm"));
		
	EndIf;
	
	If PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "Requisition") Then
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection,
															"Requisition",
															NStr("en = 'Requisition'"),
															DataProcessors.PrintRequisition.PrintForm(ObjectsArray, PrintObjects, "Requisition"));
	EndIf;
	
	// parameters of sending printing forms by email
	DriveServer.FillSendingParameters(OutputParameters.SendingParameters, ObjectsArray, PrintFormsCollection);
	
EndProcedure

// Fills in the list of printing commands.
// 
// Parameters:
//   PrintCommands - ValueTable - see fields' content in the PrintManagement.CreatePrintCommandsCollection function.
//
Procedure AddPrintCommands(PrintCommands) Export
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID							= "MerchandiseFillingForm";
	PrintCommand.Presentation				= NStr("en = 'Goods content form'");
	PrintCommand.FormsList					= "DocumentForm,ListForm";
	PrintCommand.CheckPostingBeforePrint	= False;
	PrintCommand.Order						= 1;
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID							= "Requisition";
	PrintCommand.Presentation				= NStr("en = 'Requisition'");
	PrintCommand.FormsList					= "DocumentForm,ListForm";
	PrintCommand.CheckPostingBeforePrint	= False;
	PrintCommand.Order						= 2;
	
EndProcedure

#EndRegion

#Region InfoBaseUpdate

Procedure FillNewGLAccounts() Export
	
	DocumentName = "InventoryWriteOff";
	
	Tables = New Array();
	TableDecription = New Structure("Name, Conditions", "Inventory", New Array());
	
	GLAccountFields = ChartsOfAccounts.PrimaryChartOfAccounts.GLAccountFields();
	GLAccountFields.Source = "Products.InventoryGLAccount";
	GLAccountFields.Receiver = "InventoryGLAccount";
	TableDecription.Conditions.Add(GLAccountFields);
	
	Tables.Add(TableDecription);
	
	ChartsOfAccounts.PrimaryChartOfAccounts.FillNewGLAccounts(DocumentName, Tables);
	
EndProcedure

#EndRegion

#EndIf