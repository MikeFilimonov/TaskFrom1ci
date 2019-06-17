#If Server OR ThickClientOrdinaryApplication OR ExternalConnection Then

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventory(DocumentRefSalesOrder, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	FillAmount = StructureAdditionalProperties.AccountingPolicy.InventoryValuationMethod = Enums.InventoryValuationMethods.WeightedAverage;
	
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
	|				(Company, StructuralUnit, GLAccount, Products, Characteristic, Batch, SalesOrder) In
	|					(SELECT
	|						TableInventory.Company,
	|						TableInventory.StructuralUnit,
	|						TableInventory.GLAccount,
	|						TableInventory.Products,
	|						TableInventory.Characteristic,
	|						TableInventory.Batch,
	|						UNDEFINED AS SalesOrder
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
	|		AND DocumentRegisterRecordsInventory.Period <= &ControlPeriod
	|		AND DocumentRegisterRecordsInventory.RecordType = VALUE(AccumulationRecordType.Expense)) AS InventoryBalances
	|
	|GROUP BY
	|	InventoryBalances.Company,
	|	InventoryBalances.StructuralUnit,
	|	InventoryBalances.GLAccount,
	|	InventoryBalances.Products,
	|	InventoryBalances.Characteristic,
	|	InventoryBalances.Batch";
	
	Query.SetParameter("Ref", DocumentRefSalesOrder);
	Query.SetParameter("ControlTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.PointInTime.Date);
	
	QueryResult = Query.Execute();
	
	TableInventoryBalances = QueryResult.Unload();
	TableInventoryBalances.Indexes.Add("Company,StructuralUnit,GLAccount,Products,Characteristic,Batch");
	
	TemporaryTableInventory = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.CopyColumns();

	For n = 0 To StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Count() - 1 Do
		
		RowTableInventory = StructureAdditionalProperties.TableForRegisterRecords.TableInventory[n];
		
		StructureForSearch = New Structure;
		StructureForSearch.Insert("Company", RowTableInventory.Company);
		StructureForSearch.Insert("StructuralUnit", RowTableInventory.StructuralUnit);
		StructureForSearch.Insert("GLAccount", RowTableInventory.GLAccount);
		StructureForSearch.Insert("Products", RowTableInventory.Products);
		StructureForSearch.Insert("Characteristic", RowTableInventory.Characteristic);
		StructureForSearch.Insert("Batch", RowTableInventory.Batch);
		
		QuantityRequiredReserve = RowTableInventory.Quantity;
		
		If QuantityRequiredReserve > 0 Then
			
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
	
			// Expense.
			TableRowExpense = TemporaryTableInventory.Add();
			FillPropertyValues(TableRowExpense, RowTableInventory);
			
			If FillAmount Then
				TableRowExpense.Amount = AmountToBeWrittenOff;
			EndIf;
			TableRowExpense.Quantity = QuantityRequiredReserve;
			TableRowExpense.SalesOrder = Undefined;
			
			// Receipt
			If Round(AmountToBeWrittenOff, 2, 1) <> 0 OR QuantityRequiredReserve > 0 Then
				
				TableRowReceipt = TemporaryTableInventory.Add();
				FillPropertyValues(TableRowReceipt, RowTableInventory);
					
				TableRowReceipt.RecordType = AccumulationRecordType.Receipt;
					
				TableRowReceipt.StructuralUnit = RowTableInventory.StructuralUnitCorr;
				TableRowReceipt.GLAccount = RowTableInventory.CorrGLAccount;
				TableRowReceipt.Products = RowTableInventory.ProductsCorr;
				TableRowReceipt.Characteristic = RowTableInventory.CharacteristicCorr;
				TableRowReceipt.Batch = RowTableInventory.BatchCorr;
				TableRowReceipt.SalesOrder = RowTableInventory.CustomerCorrOrder;
					
				TableRowReceipt.StructuralUnitCorr = RowTableInventory.StructuralUnit;
				TableRowReceipt.CorrGLAccount = RowTableInventory.GLAccount;
				TableRowReceipt.ProductsCorr = RowTableInventory.Products;
				TableRowReceipt.CharacteristicCorr = RowTableInventory.Characteristic;
				TableRowReceipt.BatchCorr = RowTableInventory.Batch;
				TableRowReceipt.CustomerCorrOrder = Undefined;
				
				If FillAmount Then
					TableRowReceipt.Amount = AmountToBeWrittenOff;
				EndIf;
				TableRowReceipt.Quantity = QuantityRequiredReserve;
					
				TableRowReceipt.GLAccount = RowTableInventory.CorrGLAccount;
					
			EndIf;
			
		EndIf;
		
	EndDo;
	
	StructureAdditionalProperties.TableForRegisterRecords.TableInventory = TemporaryTableInventory;
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventoryCostLayer(DocumentRefSalesOrder, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	Inventory.Period AS Period,
	|	Inventory.RecordType AS RecordType,
	|	Inventory.Company AS Company,
	|	Inventory.Products AS Products,
	|	Inventory.SalesOrder AS SalesOrder,
	|	Inventory.CostLayer AS CostLayer,
	|	Inventory.Characteristic AS Characteristic,
	|	Inventory.Batch AS Batch,
	|	Inventory.StructuralUnit AS StructuralUnit,
	|	Inventory.GLAccount AS GLAccount,
	|	Inventory.Quantity AS Quantity,
	|	Inventory.Amount AS Amount,
	|	Inventory.SourceRecord AS SourceRecord,
	|	Inventory.VATRate AS VATRate,
	|	Inventory.Responsible AS Responsible,
	|	Inventory.Department AS Department,
	|	Inventory.SourceDocument AS SourceDocument,
	|	Inventory.CorrSalesOrder AS CorrSalesOrder,
	|	Inventory.CorrStructuralUnit AS CorrStructuralUnit,
	|	Inventory.CorrGLAccount AS CorrGLAccount,
	|	Inventory.RIMTransfer AS RIMTransfer
	|FROM
	|	AccumulationRegister.InventoryCostLayer AS Inventory
	|		INNER JOIN Header AS Header
	|		ON Inventory.Recorder = Header.Ref
	|WHERE
	|	NOT Header.Closed
	|	AND Inventory.Quantity > 0";
	
	Query.SetParameter("Ref", DocumentRefSalesOrder);
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryCostLayer", QueryResult.Unload());

EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableLandedCosts(DocumentRefSalesOrder, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	LandedCosts.Period AS Period,
	|	LandedCosts.Company AS Company,
	|	LandedCosts.Products AS Products,
	|	LandedCosts.SalesOrder AS SalesOrder,
	|	LandedCosts.CostLayer AS CostLayer,
	|	LandedCosts.Characteristic AS Characteristic,
	|	LandedCosts.Batch AS Batch,
	|	LandedCosts.StructuralUnit AS StructuralUnit,
	|	LandedCosts.GLAccount AS GLAccount,
	|	LandedCosts.Amount AS Amount,
	|	LandedCosts.SourceRecord AS SourceRecord,
	|	LandedCosts.VATRate AS VATRate,
	|	LandedCosts.Responsible AS Responsible,
	|	LandedCosts.Department AS Department,
	|	LandedCosts.SourceDocument AS SourceDocument,
	|	LandedCosts.CorrSalesOrder AS CorrSalesOrder,
	|	LandedCosts.CorrStructuralUnit AS CorrStructuralUnit,
	|	LandedCosts.CorrGLAccount AS CorrGLAccount,
	|	LandedCosts.RIMTransfer AS RIMTransfer
	|FROM
	|	AccumulationRegister.LandedCosts AS LandedCosts
	|		INNER JOIN Header AS Header
	|		ON LandedCosts.Recorder = Header.Ref
	|WHERE
	|	NOT Header.Closed
	|	AND LandedCosts.Amount > 0";
	
	Query.SetParameter("Ref", DocumentRefSalesOrder);
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableLandedCosts", QueryResult.Unload());

EndProcedure

// Payment calendar table formation procedure.
//
// Parameters:
// DocumentRef - DocumentRef.CashInflowForecast - Current
// document AdditionalProperties - AdditionalProperties - Additional properties of the document
//
Procedure GenerateTablePaymentCalendar(DocumentRefSalesOrder, StructureAdditionalProperties)
	
	Query = New Query;
	
	Query.SetParameter("Ref", DocumentRefSalesOrder);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	
	Query.Text =
	"SELECT
	|	SalesOrder.Ref AS Ref,
	|	SalesOrder.ShipmentDate AS ShipmentDate,
	|	SalesOrder.AmountIncludesVAT AS AmountIncludesVAT,
	|	SalesOrder.CashAssetsType AS CashAssetsType,
	|	SalesOrder.Contract AS Contract,
	|	SalesOrder.PettyCash AS PettyCash,
	|	SalesOrder.DocumentCurrency AS DocumentCurrency,
	|	SalesOrder.BankAccount AS BankAccount,
	|	SalesOrder.Closed AS Closed,
	|	SalesOrder.OrderState AS OrderState
	|INTO Document
	|FROM
	|	Document.SalesOrder AS SalesOrder
	|WHERE
	|	SalesOrder.Ref = &Ref
	|	AND NOT SalesOrder.Closed
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DocumentTable.PaymentDate AS Period,
	|	Document.CashAssetsType AS CashAssetsType,
	|	Document.Ref AS Quote,
	|	CounterpartyContracts.SettlementsCurrency AS SettlementsCurrency,
	|	CounterpartyContracts.SettlementsInStandardUnits AS SettlementsInStandardUnits,
	|	Document.PettyCash AS PettyCash,
	|	Document.DocumentCurrency AS DocumentCurrency,
	|	Document.BankAccount AS BankAccount,
	|	Document.Ref AS Ref,
	|	CASE
	|		WHEN Document.AmountIncludesVAT
	|			THEN DocumentTable.PaymentAmount
	|		ELSE DocumentTable.PaymentAmount + DocumentTable.PaymentVATAmount
	|	END AS PaymentAmount
	|INTO PaymentCalendar
	|FROM
	|	Document AS Document
	|		INNER JOIN Catalog.SalesOrderStatuses AS SalesOrderStatuses
	|		ON Document.OrderState = SalesOrderStatuses.Ref
	|			AND (SalesOrderStatuses.OrderStatus IN (VALUE(Enum.OrderStatuses.InProcess), VALUE(Enum.OrderStatuses.Completed)))
	|		INNER JOIN Document.SalesOrder.PaymentCalendar AS DocumentTable
	|		ON Document.Ref = DocumentTable.Ref
	|			AND (DocumentTable.PaymentDate <= Document.ShipmentDate)
	|		LEFT JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
	|		ON Document.Contract = CounterpartyContracts.Ref
	|		INNER JOIN Constant.UsePaymentCalendar AS UsePaymentCalendar
	|		ON (UsePaymentCalendar.Value)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	PaymentCalendar.Period AS Period,
	|	&Company AS Company,
	|	PaymentCalendar.CashAssetsType AS CashAssetsType,
	|	VALUE(Enum.PaymentApprovalStatuses.Approved) AS PaymentConfirmationStatus,
	|	PaymentCalendar.Ref AS Quote,
	|	VALUE(Catalog.CashFlowItems.PaymentFromCustomers) AS Item,
	|	CASE
	|		WHEN PaymentCalendar.CashAssetsType = VALUE(Enum.CashAssetTypes.Cash)
	|			THEN PaymentCalendar.PettyCash
	|		WHEN PaymentCalendar.CashAssetsType = VALUE(Enum.CashAssetTypes.Noncash)
	|			THEN PaymentCalendar.BankAccount
	|		ELSE UNDEFINED
	|	END AS BankAccountPettyCash,
	|	CASE
	|		WHEN PaymentCalendar.SettlementsInStandardUnits
	|			THEN PaymentCalendar.SettlementsCurrency
	|		ELSE PaymentCalendar.DocumentCurrency
	|	END AS Currency,
	|	CASE
	|		WHEN PaymentCalendar.SettlementsInStandardUnits
	|			THEN CAST(PaymentCalendar.PaymentAmount * CASE
	|						WHEN SettlementsExchangeRates.ExchangeRate <> 0
	|								AND ExchangeRatesOfDocument.Multiplicity <> 0
	|							THEN ExchangeRatesOfDocument.ExchangeRate * SettlementsExchangeRates.Multiplicity / (ISNULL(SettlementsExchangeRates.ExchangeRate, 1) * ISNULL(ExchangeRatesOfDocument.Multiplicity, 1))
	|						ELSE 1
	|					END AS NUMBER(15, 2))
	|		ELSE PaymentCalendar.PaymentAmount
	|	END AS Amount
	|FROM
	|	PaymentCalendar AS PaymentCalendar
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&PointInTime, ) AS ExchangeRatesOfDocument
	|		ON PaymentCalendar.DocumentCurrency = ExchangeRatesOfDocument.Currency
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&PointInTime, ) AS SettlementsExchangeRates
	|		ON PaymentCalendar.SettlementsCurrency = SettlementsExchangeRates.Currency";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TablePaymentCalendar", QueryResult.Unload());
	
EndProcedure

// Generating procedure for the table of invoices for payment.
//
// Parameters:
// DocumentRef - DocumentRef.CashInflowForecast - Current
// document AdditionalProperties - AdditionalProperties - Additional properties of the document
//
Procedure GenerateTableInvoicesAndOrdersPayment(DocumentRefSalesOrder, StructureAdditionalProperties)
	
	Query = New Query;
	
	Query.SetParameter("Ref", DocumentRefSalesOrder);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	
	Query.Text =
	"SELECT
	|	DocumentTable.Date AS Period,
	|	&Company AS Company,
	|	DocumentTable.Ref AS Quote,
	|	DocumentTable.DocumentAmount AS Amount
	|FROM
	|	Document.SalesOrder AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|	AND (NOT DocumentTable.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.Open))
	|	AND (NOT(DocumentTable.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|				AND DocumentTable.Ref.Closed))
	|	AND DocumentTable.DocumentAmount <> 0";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInvoicesAndOrdersPayment", QueryResult.Unload());
	
EndProcedure

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
Procedure InitializeDocumentData(DocumentRefSalesOrder, StructureAdditionalProperties) Export

	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text = 
	"SELECT
	|	SalesOrderInventory.LineNumber AS LineNumber,
	|	SalesOrderInventory.Ref.Date AS Period,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	&Company AS Company,
	|	SalesOrderInventory.Ref AS SalesOrder,
	|	SalesOrderInventory.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN SalesOrderInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN VALUETYPE(SalesOrderInventory.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN SalesOrderInventory.Quantity
	|		ELSE SalesOrderInventory.Quantity * SalesOrderInventory.MeasurementUnit.Factor
	|	END AS Quantity,
	|	SalesOrderInventory.ShipmentDate AS ShipmentDate
	|FROM
	|	Document.SalesOrder.Inventory AS SalesOrderInventory
	|WHERE
	|	SalesOrderInventory.Ref = &Ref
	|	AND (SalesOrderInventory.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|				AND SalesOrderInventory.Ref.Closed = FALSE
	|			OR SalesOrderInventory.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.Completed))
	|
	|ORDER BY
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SalesOrderMaterials.LineNumber AS LineNumber,
	|	SalesOrderMaterials.Ref.Date AS Period,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	&Company AS Company,
	|	VALUE(Enum.InventoryMovementTypes.Receipt) AS MovementType,
	|	SalesOrderMaterials.Ref AS SalesOrder,
	|	SalesOrderMaterials.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN SalesOrderMaterials.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN VALUETYPE(SalesOrderMaterials.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN SalesOrderMaterials.Quantity
	|		ELSE SalesOrderMaterials.Quantity * SalesOrderMaterials.MeasurementUnit.Factor
	|	END AS Quantity
	|FROM
	|	Document.SalesOrder.ConsumerMaterials AS SalesOrderMaterials
	|WHERE
	|	SalesOrderMaterials.Ref = &Ref
	|	AND SalesOrderMaterials.Ref.OperationKind = VALUE(Enum.OperationTypesSalesOrder.OrderForProcessing)
	|	AND (SalesOrderMaterials.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|				AND SalesOrderMaterials.Ref.Closed = FALSE
	|			OR SalesOrderMaterials.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.Completed))
	|
	|ORDER BY
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	1 AS Ordering,
	|	SalesOrderInventory.LineNumber AS LineNumber,
	|	SalesOrderInventory.ShipmentDate AS Period,
	|	&Company AS Company,
	|	VALUE(Enum.InventoryMovementTypes.Shipment) AS MovementType,
	|	SalesOrderInventory.Ref AS Order,
	|	SalesOrderInventory.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN SalesOrderInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN VALUETYPE(SalesOrderInventory.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN SalesOrderInventory.Quantity
	|		ELSE SalesOrderInventory.Quantity * SalesOrderInventory.MeasurementUnit.Factor
	|	END AS Quantity
	|FROM
	|	Document.SalesOrder.Inventory AS SalesOrderInventory
	|WHERE
	|	SalesOrderInventory.Ref = &Ref
	|	AND (SalesOrderInventory.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|				AND SalesOrderInventory.Ref.Closed = FALSE
	|			OR SalesOrderInventory.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.Completed))
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	SalesOrderMaterials.LineNumber,
	|	SalesOrderMaterials.ReceiptDate,
	|	&Company,
	|	VALUE(Enum.InventoryMovementTypes.Receipt),
	|	SalesOrderMaterials.Ref,
	|	SalesOrderMaterials.Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN SalesOrderMaterials.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END,
	|	CASE
	|		WHEN VALUETYPE(SalesOrderMaterials.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN SalesOrderMaterials.Quantity
	|		ELSE SalesOrderMaterials.Quantity * SalesOrderMaterials.MeasurementUnit.Factor
	|	END
	|FROM
	|	Document.SalesOrder.ConsumerMaterials AS SalesOrderMaterials
	|WHERE
	|	SalesOrderMaterials.Ref = &Ref
	|	AND SalesOrderMaterials.Ref.OperationKind = VALUE(Enum.OperationTypesSalesOrder.OrderForProcessing)
	|	AND (SalesOrderMaterials.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|				AND SalesOrderMaterials.Ref.Closed = FALSE
	|			OR SalesOrderMaterials.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.Completed))
	|
	|ORDER BY
	|	Ordering,
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SalesOrderMaterials.LineNumber AS LineNumber,
	|	SalesOrderMaterials.Ref.Date AS Period,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	&Company AS Company,
	|	SalesOrderMaterials.Ref AS SalesOrder,
	|	SalesOrderMaterials.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN SalesOrderMaterials.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	SalesOrderMaterials.Ref AS SupplySource,
	|	CASE
	|		WHEN VALUETYPE(SalesOrderMaterials.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN SalesOrderMaterials.Quantity
	|		ELSE SalesOrderMaterials.Quantity * SalesOrderMaterials.MeasurementUnit.Factor
	|	END AS Quantity
	|FROM
	|	Document.SalesOrder.ConsumerMaterials AS SalesOrderMaterials
	|WHERE
	|	SalesOrderMaterials.Ref = &Ref
	|	AND SalesOrderMaterials.Ref.OperationKind = VALUE(Enum.OperationTypesSalesOrder.OrderForProcessing)
	|	AND (SalesOrderMaterials.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|				AND SalesOrderMaterials.Ref.Closed = FALSE
	|			OR SalesOrderMaterials.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.Completed))
	|
	|ORDER BY
	|	SalesOrderMaterials.LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SalesOrderInventory.LineNumber AS LineNumber,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	SalesOrderInventory.Ref.Date AS Period,
	|	&Company AS Company,
	|	SalesOrderInventory.Ref.StructuralUnitReserve AS StructuralUnit,
	|	SalesOrderInventory.InventoryGLAccount AS GLAccount,
	|	SalesOrderInventory.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN SalesOrderInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseBatches
	|			THEN SalesOrderInventory.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS Batch,
	|	UNDEFINED AS SalesOrder,
	|	SalesOrderInventory.Ref AS CustomerCorrOrder,
	|	CASE
	|		WHEN VALUETYPE(SalesOrderInventory.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN SalesOrderInventory.Reserve
	|		ELSE SalesOrderInventory.Reserve * SalesOrderInventory.MeasurementUnit.Factor
	|	END AS Quantity,
	|	0 AS Amount,
	|	&InventoryReservation AS ContentOfAccountingRecord
	|INTO TemporaryTableInventory
	|FROM
	|	Document.SalesOrder.Inventory AS SalesOrderInventory
	|WHERE
	|	SalesOrderInventory.Ref = &Ref
	|	AND SalesOrderInventory.Reserve > 0
	|	AND (SalesOrderInventory.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|				AND SalesOrderInventory.Ref.Closed = FALSE
	|			OR SalesOrderInventory.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.Completed))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(TableInventory.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableInventory.Period AS Period,
	|	TableInventory.Company AS Company,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	TableInventory.StructuralUnit AS StructuralUnitCorr,
	|	TableInventory.GLAccount AS GLAccount,
	|	TableInventory.GLAccount AS CorrGLAccount,
	|	TableInventory.Products AS Products,
	|	TableInventory.Products AS ProductsCorr,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Characteristic AS CharacteristicCorr,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.Batch AS BatchCorr,
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
	|	TableInventory.ContentOfAccountingRecord AS ContentOfAccountingRecord,
	|	SUM(TableInventory.Quantity) AS Quantity,
	|	SUM(TableInventory.Amount) AS Amount,
	|	FALSE AS FixedCost
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
	|	TableInventory.SalesOrder,
	|	TableInventory.CustomerCorrOrder,
	|	TableInventory.ContentOfAccountingRecord,
	|	TableInventory.StructuralUnit,
	|	TableInventory.GLAccount,
	|	TableInventory.Products,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SalesOrder.Ref AS Ref,
	|	SalesOrder.Closed AS Closed
	|INTO Header
	|FROM
	|	Document.SalesOrder AS SalesOrder
	|WHERE
	|	SalesOrder.Ref = &Ref";
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();
	
	Query.SetParameter("Ref", 					DocumentRefSalesOrder);
	Query.SetParameter("PointInTime", 			New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("Company", 				StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("UseCharacteristics", 	StructureAdditionalProperties.AccountingPolicy.UseCharacteristics);
	Query.SetParameter("UseBatches",  			StructureAdditionalProperties.AccountingPolicy.UseBatches);
	Query.SetParameter("InventoryReservation", 	NStr("en = 'Inventory reservation'", MainLanguageCode));
	
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSalesOrders", ResultsArray[0].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryDemand", ResultsArray[1].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryFlowCalendar", ResultsArray[2].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableBackorders", ResultsArray[3].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventory", ResultsArray[5].Unload());
	
	PerformanceEstimationClientServer.StartTimeMeasurement("SalesOrderDocumentPostingGeneratingCostTable");
	
	GenerateTableInventory(DocumentRefSalesOrder, StructureAdditionalProperties);
	
	//Restore records in offline registers
	GenerateTableInventoryCostLayer(DocumentRefSalesOrder, StructureAdditionalProperties);
	GenerateTableLandedCosts(DocumentRefSalesOrder, StructureAdditionalProperties);
	
	PerformanceEstimationClientServer.StartTimeMeasurement("SalesOrderDocumentPostingGeneratingTable");
	
	GenerateTablePaymentCalendar(DocumentRefSalesOrder, StructureAdditionalProperties);
	GenerateTableInvoicesAndOrdersPayment(DocumentRefSalesOrder, StructureAdditionalProperties);
	
EndProcedure

// Function returns batch query template.
//
Function GenerateBatchQueryTemplate()
	
	QueryText =
	Chars.LF +
	";
	|
	|////////////////////////////////////////////////////////////////////////////////"
	+ Chars.LF;
	
	Return QueryText;
	
EndFunction

// Function returns query text by the balance of Inventory register.
//
Function GenerateQueryTextBalancesInventory()
	
	QueryText =
	"SELECT
	|	RegisterRecordsInventoryChange.LineNumber AS LineNumber,
	|	RegisterRecordsInventoryChange.Company AS CompanyPresentation,
	|	RegisterRecordsInventoryChange.StructuralUnit AS StructuralUnitPresentation,
	|	RegisterRecordsInventoryChange.GLAccount AS GLAccountPresentation,
	|	RegisterRecordsInventoryChange.Products AS ProductsPresentation,
	|	RegisterRecordsInventoryChange.Characteristic AS CharacteristicPresentation,
	|	RegisterRecordsInventoryChange.Batch AS BatchPresentation,
	|	RegisterRecordsInventoryChange.SalesOrder AS SalesOrderPresentation,
	|	InventoryBalances.StructuralUnit.StructuralUnitType AS StructuralUnitType,
	|	InventoryBalances.Products.MeasurementUnit AS MeasurementUnitPresentation,
	|	ISNULL(RegisterRecordsInventoryChange.QuantityChange, 0) + ISNULL(InventoryBalances.QuantityBalance, 0) AS BalanceInventory,
	|	ISNULL(InventoryBalances.QuantityBalance, 0) AS QuantityBalanceInventory,
	|	ISNULL(InventoryBalances.AmountBalance, 0) AS AmountBalanceInventory
	|FROM
	|	RegisterRecordsInventoryChange AS RegisterRecordsInventoryChange
	|		INNER JOIN AccumulationRegister.Inventory.Balance(&ControlTime, ) AS InventoryBalances
	|		ON RegisterRecordsInventoryChange.Company = InventoryBalances.Company
	|			AND RegisterRecordsInventoryChange.StructuralUnit = InventoryBalances.StructuralUnit
	|			AND RegisterRecordsInventoryChange.GLAccount = InventoryBalances.GLAccount
	|			AND RegisterRecordsInventoryChange.Products = InventoryBalances.Products
	|			AND RegisterRecordsInventoryChange.Characteristic = InventoryBalances.Characteristic
	|			AND RegisterRecordsInventoryChange.Batch = InventoryBalances.Batch
	|			AND RegisterRecordsInventoryChange.SalesOrder = InventoryBalances.SalesOrder
	|			AND (ISNULL(InventoryBalances.QuantityBalance, 0) < 0)
	|
	|ORDER BY
	|	LineNumber";
	
	Return QueryText + GenerateBatchQueryTemplate();
	
EndFunction

// Function returns query text by the balance of SalesOrders register.
//
Function GenerateQueryTextBalancesSalesOrders()
	
	QueryText =
	"SELECT
	|	RegisterRecordsSalesOrdersChange.LineNumber AS LineNumber,
	|	RegisterRecordsSalesOrdersChange.Company AS CompanyPresentation,
	|	RegisterRecordsSalesOrdersChange.SalesOrder AS OrderPresentation,
	|	RegisterRecordsSalesOrdersChange.Products AS ProductsPresentation,
	|	RegisterRecordsSalesOrdersChange.Characteristic AS CharacteristicPresentation,
	|	SalesOrdersBalances.Products.MeasurementUnit AS MeasurementUnitPresentation,
	|	ISNULL(RegisterRecordsSalesOrdersChange.QuantityChange, 0) + ISNULL(SalesOrdersBalances.QuantityBalance, 0) AS BalanceSalesOrders,
	|	ISNULL(SalesOrdersBalances.QuantityBalance, 0) AS QuantityBalanceSalesOrders
	|FROM
	|	RegisterRecordsSalesOrdersChange AS RegisterRecordsSalesOrdersChange
	|		INNER JOIN AccumulationRegister.SalesOrders.Balance(&ControlTime, ) AS SalesOrdersBalances
	|		ON RegisterRecordsSalesOrdersChange.Company = SalesOrdersBalances.Company
	|			AND RegisterRecordsSalesOrdersChange.SalesOrder = SalesOrdersBalances.SalesOrder
	|			AND RegisterRecordsSalesOrdersChange.Products = SalesOrdersBalances.Products
	|			AND RegisterRecordsSalesOrdersChange.Characteristic = SalesOrdersBalances.Characteristic
	|			AND (ISNULL(SalesOrdersBalances.QuantityBalance, 0) < 0)
	|
	|ORDER BY
	|	LineNumber";
	
	Return QueryText + GenerateBatchQueryTemplate();
	
EndFunction

// Function returns query text by the balance of InventoryDemand register.
//
Function GenerateQueryTextBalancesInventoryDemand()
	
	QueryText =
	"SELECT
	|	RegisterRecordsInventoryDemandChange.LineNumber AS LineNumber,
	|	RegisterRecordsInventoryDemandChange.Company AS CompanyPresentation,
	|	RegisterRecordsInventoryDemandChange.MovementType AS MovementTypePresentation,
	|	RegisterRecordsInventoryDemandChange.SalesOrder AS SalesOrderPresentation,
	|	RegisterRecordsInventoryDemandChange.Products AS ProductsPresentation,
	|	RegisterRecordsInventoryDemandChange.Characteristic AS CharacteristicPresentation,
	|	InventoryDemandBalances.Products.MeasurementUnit AS MeasurementUnitPresentation,
	|	ISNULL(RegisterRecordsInventoryDemandChange.QuantityChange, 0) + ISNULL(InventoryDemandBalances.QuantityBalance, 0) AS BalanceInventoryDemand,
	|	ISNULL(InventoryDemandBalances.QuantityBalance, 0) AS QuantityBalanceInventoryDemand
	|FROM
	|	RegisterRecordsInventoryDemandChange AS RegisterRecordsInventoryDemandChange
	|		INNER JOIN AccumulationRegister.InventoryDemand.Balance(&ControlTime, ) AS InventoryDemandBalances
	|		ON RegisterRecordsInventoryDemandChange.Company = InventoryDemandBalances.Company
	|			AND RegisterRecordsInventoryDemandChange.MovementType = InventoryDemandBalances.MovementType
	|			AND RegisterRecordsInventoryDemandChange.SalesOrder = InventoryDemandBalances.SalesOrder
	|			AND RegisterRecordsInventoryDemandChange.Products = InventoryDemandBalances.Products
	|			AND RegisterRecordsInventoryDemandChange.Characteristic = InventoryDemandBalances.Characteristic
	|			AND (ISNULL(InventoryDemandBalances.QuantityBalance, 0) < 0)
	|
	|ORDER BY
	|	LineNumber";
	
	Return QueryText + GenerateBatchQueryTemplate();
	
EndFunction

// Controls the occurrence of negative balances.
//
Procedure RunControl(DocumentObjectSalesOrder, AdditionalProperties, Cancel, PostingDelete = False) Export
	
	If Not DriveServer.RunBalanceControl() Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// If temporary tables "RegisterRecordsInventoryInWarehousesChange",
	// "RegisterRecordsInventoryChange" "RegisterRecordsSalesOrdersChange",
	// "RegisterRecordsInventoryDemandChange", "RegisterRecordsAccountsReceivableChange" contain records, execute
	// the control of balances.
		
	If StructureTemporaryTables.RegisterRecordsInventoryChange
		OR StructureTemporaryTables.RegisterRecordsSalesOrdersChange
		OR StructureTemporaryTables.RegisterRecordsInventoryDemandChange Then
		
		Query = New Query;
		Query.Text = GenerateQueryTextBalancesInventory() // [0]
		+ GenerateQueryTextBalancesSalesOrders() // [1]
		+ GenerateQueryTextBalancesInventoryDemand(); // [2]
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.SetParameter("ControlTime", AdditionalProperties.ForPosting.ControlTime);
		
		ResultsArray = Query.ExecuteBatch();
		
		// Negative balance of inventory.
		If Not ResultsArray[0].IsEmpty() Then
			QueryResultSelection = ResultsArray[0].Select();
			DriveServer.ShowMessageAboutPostingToInventoryRegisterErrors(DocumentObjectSalesOrder, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance on sales order.
		If Not ResultsArray[1].IsEmpty() Then
			QueryResultSelection = ResultsArray[1].Select();
			DriveServer.ShowMessageAboutPostingToSalesOrdersRegisterErrors(DocumentObjectSalesOrder, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance of need for inventory.
		If Not ResultsArray[2].IsEmpty() Then
			QueryResultSelection = ResultsArray[2].Select();
			DriveServer.ShowMessageAboutPostingToInventoryDemandRegisterErrors(DocumentObjectSalesOrder, QueryResultSelection, Cancel);
		EndIf;
		
	EndIf;
	
EndProcedure

// Calculates earning amount for assignee row
//
//
Function ComputeEarningValueByRowAtServer(WorkCoefficients, WorkAmount, LPF, AmountLPF, EarningAndDeductionType, Size) Export
	
	If EarningAndDeductionType = Catalogs.EarningAndDeductionTypes.PieceRatePayFixedAmount Then
		
		Return Size;
		
	ElsIf EarningAndDeductionType = Catalogs.EarningAndDeductionTypes.PieceRatePay Then
		
		Return WorkCoefficients * Size * (LPF / AmountLPF);
		
	ElsIf EarningAndDeductionType = Catalogs.EarningAndDeductionTypes.PieceRatePayPercent Then
		
		Return (WorkAmount / 100 * Size) * (LPF / AmountLPF);
		
	EndIf;
	
EndFunction

// Returns the row from TS Works to specified key
//
// TabularSectionWorks - TS of Work, wob order document;
// ConnectionKey - ConnectionKey attribute value;
//
Function GetRowWorksByConnectionKey(TabularSectionWorks, ConnectionKey) Export
	
	ArrayFoundStrings = TabularSectionWorks.FindRows(New Structure("ConnectionKey", ConnectionKey));
	
	Return ?(ArrayFoundStrings.Count() <> 1, Undefined, ArrayFoundStrings[0]);
	
EndFunction

// Returns the rows of Performers TS by received connection key
//
// TabularSectionPerformers - TS Performers of Work order document;
// ConnectionKey - ConnectionKey attribute value;
//
Function GetRowsPerformersByConnectionKey(TabularSectionPerformers, ConnectionKey) Export
	
	Return TabularSectionPerformers.FindRows(New Structure("ConnectionKey", ConnectionKey));
	
EndFunction

// Returns the amount of Performers LPC included in the Earning for specified work
// 
// TabularSectionPerformers - TS Performers of Work order document;
// ConnectionKey - ConnectionKey attribute value;
//
Function ComputeLPFSumByConnectionKey(TabularSectionPerformers, ConnectionKey) Export
	
	If Not ValueIsFilled(ConnectionKey) Then
		
		Return 1; 
		
	EndIf;
	
	Query = New Query;
	Query.TempTablesManager = New TempTablesManager;
	
	Query.Text = 
	"SELECT *
	|INTO CWT_Performers
	|FROM
	|	&TabularSection AS SalesOrderPerformers
	| WHERE SalesOrderPerformers.ConnectionKey = &ConnectionKey";
	
	Query.SetParameter("ConnectionKey", ConnectionKey);
	Query.SetParameter("TabularSection", TabularSectionPerformers.Unload());
	Query.Execute();
	
	Query.Text = 
	"SELECT
	|	SUM(CWT_Performers.LPF) AS AmountLPF
	|FROM
	|	CWT_Performers AS CWT_Performers
	|WHERE 
	|	CWT_Performers.EarningAndDeductionType <> Value(Catalog.EarningAndDeductionTypes.PieceRatePayFixedAmount)";
	
	QueryResult = Query.Execute();
	
	If QueryResult.IsEmpty() Then 
		
		Return 1;
		
	EndIf;
		
	Selection = QueryResult.Select();
	Selection.Next();
	
	Return ?(Selection.AmountLPF = 0, 1, Selection.AmountLPF);
	
EndFunction

Function ArePerformersWithEmptyEarningSum(Performers) Export
	
	Var Errors;
	MessageTextTemplate = NStr("en = 'Earnings for employee %1 in line %2 are incorrect.'");
	
	For Each Performer In Performers Do
		
		If Performer.AccruedAmount = 0 Then
			
			SingleErrorText = 
				StringFunctionsClientServer.SubstituteParametersInString(MessageTextTemplate, Performer.Employee.Description, Performer.LineNumber);
			
			CommonUseClientServer.AddUserError(
				Errors, 
				"Object.Performers[%1].Employee", 
				SingleErrorText, 
				Undefined, 
				Performer.LineNumber, 
				);
			
		EndIf;
		
	EndDo;
	
	If ValueIsFilled(Errors) Then
		
		CommonUseClientServer.ShowErrorsToUser(Errors);
		Return True;
		
	EndIf;
	
	Return False;
	
EndFunction

// Checks the possibility of input on the basis.
//
Procedure CheckAbilityOfEnteringBySalesOrder(FillingData, AttributeValues) Export
	
	If AttributeValues.Property("Posted") Then
		If Not AttributeValues.Posted Then
			ErrorText = NStr("en = '%Document% is not posted. Cannot use it as a base document. Please, post it first.'");
			ErrorText = StrReplace(ErrorText, "%Document%", FillingData);
			Raise ErrorText;
		EndIf;
	EndIf;
	
	If AttributeValues.Property("Closed") Then
		If (AttributeValues.Property("WorkOrderReturn") AND Constants.UseSalesOrderStatuses.Get())
			OR Not AttributeValues.Property("WorkOrderReturn") Then
			If AttributeValues.Closed Then
				ErrorText = NStr("en = '%Document% is completed. Cannot use a completed order as a base document.'");
				ErrorText = StrReplace(ErrorText, "%Document%", FillingData);
				Raise ErrorText;
			EndIf;
		EndIf;
	EndIf;
	
	If AttributeValues.Property("OrderState") Then
		
		If AttributeValues.OrderState.OrderStatus = Enums.OrderStatuses.Open Then
			ErrorText = NStr("en = 'The status of %Document% is %OrderState%. Cannot use it as a base document.'");
			ErrorText = StrReplace(ErrorText, "%Document%", FillingData);
			ErrorText = StrReplace(ErrorText, "%OrderState%", AttributeValues.OrderState);
			Raise ErrorText;
		EndIf;
		
		If AttributeValues.Property("OperationKind") Then
			
			If AttributeValues.Property("GoodsReceipt")
				AND AttributeValues.OperationKind <> Enums.OperationTypesSalesOrder.OrderForProcessing Then
				
				ErrorText = NStr("en = 'Cannot use %1 as a base document for Goods Receipt. Please select a sales order with ""Contractor work order"" operation.'");
				Raise StringFunctionsClientServer.SubstituteParametersInString(
						ErrorText,
						FillingData);
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

#Region PrintInterface

Function PrintEstimate(ObjectArray, PrintObjects, TemplateName)
	Var FirstDocument, FirstRowNumber;
	
	SpreadsheetDocument = New SpreadsheetDocument;
	SpreadsheetDocument.PrintParametersKey = "PrintParameters_SalesOrder";

	FirstDocument = True;
	
	SpreadsheetDocument.PrintParametersName = "PRINT_PARAMETERS_PF_MXL_Estimate";
	
	Template = PrintManagement.PrintedFormsTemplate("Document.SalesOrder.PF_MXL_Estimate");
	ShowCost = SystemSettingsStorage.Load("SalesOrder", "ShowCost");
	If TypeOf(ShowCost)<>Type("Boolean") Then
		ShowCost = IsInRole("FullRights");
	EndIf; 
	
	Query = New Query();
	Query.SetParameter("ObjectArray", ObjectArray);
	Query.Text =
	"SELECT
	|	SalesOrder.Ref AS Ref,
	|	SalesOrder.Number AS Number,
	|	SalesOrder.Date AS Date,
	|	SalesOrder.Company AS Company,
	|	SalesOrder.Counterparty AS Counterparty,
	|	SalesOrder.EstimateIsCalculated AS EstimateIsCalculated,
	|	SalesOrder.DocumentAmount AS DocumentAmount
	|INTO Orders
	|FROM
	|	Document.SalesOrder AS SalesOrder
	|WHERE
	|	SalesOrder.Ref IN(&ObjectArray)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SalesOrderInventory.Ref AS Ref,
	|	SalesOrderInventory.LineNumber AS LineNumber,
	|	SalesOrderInventory.Products AS Products,
	|	SalesOrderInventory.Characteristic AS Characteristic,
	|	SalesOrderInventory.Specification AS Specification,
	|	SalesOrderInventory.MeasurementUnit AS MeasurementUnit,
	|	SalesOrderInventory.Quantity AS Quantity,
	|	SalesOrderInventory.Total AS Total,
	|	SalesOrderInventory.Total / (1 - (SalesOrderInventory.DiscountMarkupPercent + SalesOrderInventory.AutomaticDiscountsPercent) / 100) - SalesOrderInventory.Total AS DiscountAmount,
	|	SalesOrderInventory.ConnectionKey AS ConnectionKey
	|INTO Inventory
	|FROM
	|	Orders AS Orders
	|		LEFT JOIN Document.SalesOrder.Inventory AS SalesOrderInventory
	|		ON Orders.Ref = SalesOrderInventory.Ref
	|
	|UNION ALL
	|
	|SELECT
	|	Orders.Ref,
	|	MAX(SalesOrderInventory.LineNumber) + 1,
	|	NULL,
	|	VALUE(Catalog.ProductsCharacteristics.EmptyRef),
	|	VALUE(Catalog.BillsOfMaterials.EmptyRef),
	|	NULL,
	|	1,
	|	NULL,
	|	0,
	|	-1
	|FROM
	|	Orders AS Orders
	|		LEFT JOIN Document.SalesOrder.Inventory AS SalesOrderInventory
	|		ON Orders.Ref = SalesOrderInventory.Ref
	|
	|GROUP BY
	|	Orders.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SalesOrderEstimate.Ref AS Ref,
	|	SalesOrderEstimate.Products AS Products,
	|	SalesOrderEstimate.Characteristic AS Characteristic,
	|	SalesOrderEstimate.Specification AS Specification,
	|	SalesOrderEstimate.Quantity AS Quantity,
	|	SalesOrderEstimate.MeasurementUnit AS MeasurementUnit,
	|	SalesOrderEstimate.Cost AS Cost,
	|	SalesOrderEstimate.ConnectionKey AS ConnectionKey,
	|	SalesOrderEstimate.Source AS Source
	|INTO Estimates
	|FROM
	|	Document.SalesOrder.Estimate AS SalesOrderEstimate
	|WHERE
	|	SalesOrderEstimate.Ref IN(&ObjectArray)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Orders.Ref AS Ref,
	|	Orders.Number AS Number,
	|	Orders.Date AS DocumentDate,
	|	Orders.Company AS Company,
	|	Orders.Counterparty AS Counterparty,
	|	Orders.Company.Prefix AS Prefix,
	|	Orders.EstimateIsCalculated AS EstimateIsCalculated,
	|	Orders.DocumentAmount AS DocumentAmount,
	|	Estimates.ConnectionKey AS ConnectionKey,
	|	CASE
	|		WHEN VALUETYPE(Estimates.Products) = TYPE(ChartOfAccounts.PrimaryChartOfAccounts)
	|			THEN Estimates.Products.Description
	|		WHEN (CAST(Estimates.Products.DescriptionFull AS STRING(1000))) = """"
	|			THEN Estimates.Products.Description
	|		ELSE CAST(Estimates.Products.DescriptionFull AS STRING(1000))
	|	END AS Products,
	|	Estimates.Characteristic AS Characteristic,
	|	Estimates.Specification AS Specification,
	|	Estimates.Quantity AS Quantity,
	|	Estimates.MeasurementUnit AS MeasurementUnit,
	|	ISNULL(Estimates.Products.SKU, """") AS SKU,
	|	ISNULL(CASE
	|			WHEN VALUETYPE(Inventory.Products) = TYPE(ChartOfAccounts.PrimaryChartOfAccounts)
	|				THEN Inventory.Products.Description
	|			WHEN (CAST(Inventory.Products.DescriptionFull AS STRING(1000))) = """"
	|				THEN Inventory.Products.Description
	|			ELSE CAST(Inventory.Products.DescriptionFull AS STRING(1000))
	|		END, UNDEFINED) AS ProductsProduct,
	|	ISNULL(Inventory.Characteristic, UNDEFINED) AS CharacteristicProduct,
	|	ISNULL(Inventory.Specification, UNDEFINED) AS SpecificationProduct,
	|	ISNULL(Inventory.MeasurementUnit, UNDEFINED) AS MeasurementUnitProduct,
	|	ISNULL(Inventory.Quantity, UNDEFINED) AS ProductQuantity,
	|	ISNULL(Inventory.Products.SKU, """") AS SKUProduct,
	|	ISNULL(Inventory.LineNumber, 999999) AS InventoriesLineNumber,
	|	CASE
	|		WHEN Inventory.Products IS NULL
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS AdditionalMaterial,
	|	Estimates.Cost AS Cost,
	|	Inventory.Total AS Total,
	|	Inventory.DiscountAmount AS Discount
	|FROM
	|	Orders AS Orders
	|		LEFT JOIN Estimates AS Estimates
	|			LEFT JOIN Inventory AS Inventory
	|			ON Estimates.Ref = Inventory.Ref
	|				AND (Estimates.ConnectionKey = Inventory.ConnectionKey
	|						AND Estimates.Source = VALUE(Enum.EstimateRowsSources.InventoryItem)
	|					OR Inventory.ConnectionKey = -1
	|						AND Estimates.Source = VALUE(Enum.EstimateRowsSources.Delivery)
	|						AND Estimates.Products = Inventory.Products)
	|		ON Orders.Ref = Estimates.Ref
	|WHERE
	|	Orders.EstimateIsCalculated
	|
	|UNION ALL
	|
	|SELECT
	|	Orders.Ref,
	|	Orders.Number,
	|	Orders.Date,
	|	Orders.Company,
	|	Orders.Counterparty,
	|	Orders.Company.Prefix,
	|	Orders.EstimateIsCalculated,
	|	Orders.DocumentAmount,
	|	Inventory.ConnectionKey,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	Inventory.Products,
	|	Inventory.Characteristic,
	|	Inventory.Specification,
	|	Inventory.MeasurementUnit,
	|	Inventory.Quantity,
	|	Inventory.Products.SKU,
	|	Inventory.LineNumber,
	|	FALSE,
	|	0,
	|	Inventory.Total,
	|	Inventory.DiscountAmount
	|FROM
	|	Orders AS Orders
	|		LEFT JOIN Inventory AS Inventory
	|			LEFT JOIN Estimates AS Estimates
	|			ON Inventory.Ref = Estimates.Ref
	|				AND (Estimates.ConnectionKey = Inventory.ConnectionKey
	|						AND Estimates.Source = VALUE(Enum.EstimateRowsSources.InventoryItem)
	|					OR Inventory.ConnectionKey = -1
	|						AND Estimates.Source = VALUE(Enum.EstimateRowsSources.Delivery)
	|						AND Estimates.Products = Inventory.Products)
	|		ON Orders.Ref = Inventory.Ref
	|WHERE
	|	(Estimates.Ref IS NULL
	|			OR NOT Orders.EstimateIsCalculated)
	|
	|ORDER BY
	|	Ref,
	|	InventoriesLineNumber
	|TOTALS
	|	MAX(Number),
	|	MAX(DocumentDate),
	|	MAX(Company),
	|	MAX(Counterparty),
	|	MAX(Prefix),
	|	MAX(EstimateIsCalculated),
	|	MAX(DocumentAmount),
	|	MAX(ProductsProduct),
	|	MAX(CharacteristicProduct),
	|	MAX(SpecificationProduct),
	|	MAX(MeasurementUnitProduct),
	|	MAX(ProductQuantity),
	|	MAX(SKUProduct),
	|	SUM(Cost),
	|	MAX(Total),
	|	MAX(Discount)
	|BY
	|	Ref,
	|	InventoriesLineNumber";
	
	Header = Query.Execute().Select(QueryResultIteration.ByGroups);
	
	While Header.Next() Do
				
		FirstRowNumber = SpreadsheetDocument.TableHeight + 1;
				
		InfoAboutCompany = DriveServer.InfoAboutLegalEntityIndividual(Header.Company, Header.DocumentDate, ,);
		InfoAboutCounterparty = DriveServer.InfoAboutLegalEntityIndividual(Header.Counterparty, Header.DocumentDate, ,);
		
		DocumentNumber = ObjectPrefixationClientServer.GetNumberForPrinting(Header.Number, True, True);
		
		If Not Header.EstimateIsCalculated Then
			TextMessage = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Estimate is not calculated for order %1 (%2)'"),
				DocumentNumber,
				Format(Header.DocumentDate, "DLF=D"));
			CommonUseClientServer.MessageToUser(TextMessage);
			Continue;
		EndIf; 
		
		TemplateArea = Template.GetArea("Title");
		TemplateArea.Parameters.HeaderText = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Sales order estimate No. %1 dated %2'"),
			DocumentNumber,
			Format(Header.DocumentDate, "DLF=DD"));
		
		SpreadsheetDocument.Put(TemplateArea);
		
		TemplateArea = Template.GetArea("Customer");
		TemplateArea.Parameters.RecipientPresentation = DriveServer.CompaniesDescriptionFull(InfoAboutCounterparty, "FullDescr,TIN,LegalAddress,PhoneNumbers,");
		SpreadsheetDocument.Put(TemplateArea);
		
		
		TemplateArea = Template.GetArea("TableHeader");
		SpreadsheetDocument.Put(TemplateArea);
		RowArea = Template.GetArea("String");
		ContentRegion = Template.GetArea("Content");
		
		LineNumber = 0;
		SpreadsheetDocument.StartRowAutoGrouping();
		
		ProductsSelection = Header.Select(QueryResultIteration.ByGroups);
		While ProductsSelection.Next() Do
			
			If ValueIsFilled(ProductsSelection.ProductsProduct) Then
				
				LineNumber = LineNumber + 1;
				
				RowArea.Parameters.Fill(ProductsSelection);
				RowArea.Parameters.InventoryItem = DriveServer.GetProductsPresentationForPrinting(
				ProductsSelection.ProductsProduct, 
				ProductsSelection.CharacteristicProduct, 
				ProductsSelection.SKUProduct);
				RowArea.Parameters.LineNumber = Format(LineNumber, "NG=0");
				SpreadsheetDocument.Put(RowArea, 0);
				
			EndIf; 
			
			ContentSelection = ProductsSelection.Select();
			While ContentSelection.Next() Do
				
				If Not ValueIsFilled(ContentSelection.Products) OR ContentSelection.Products=ContentSelection.ProductsProduct Then
					Continue;
				EndIf; 
				
				If ContentSelection.AdditionalMaterial Then
					
					LineNumber = LineNumber + 1;
					
					RowArea.Parameters.Fill(ContentSelection);
					RowArea.Parameters.InventoryItem = DriveServer.GetProductsPresentationForPrinting(
					ContentSelection.Products, 
					ContentSelection.Characteristic, 
					ContentSelection.SKU);
					RowArea.Parameters.ProductQuantity = ContentSelection.Quantity;
					RowArea.Parameters.MeasurementUnitProduct = ContentSelection.MeasurementUnit;
					RowArea.Parameters.LineNumber = Format(LineNumber, "NG=0");
					SpreadsheetDocument.Put(RowArea, 0);
					Continue;
					
				EndIf;
				
				ContentRegion.Parameters.Fill(ContentSelection);
				
				ContentRegion.Parameters.InventoryItem = DriveServer.GetProductsPresentationForPrinting(
				ContentSelection.Products, 
				ContentSelection.Characteristic, 
				ContentSelection.SKU);
				
				SpreadsheetDocument.Put(ContentRegion, 1);
			
			EndDo; 
			
		EndDo;
		
		SpreadsheetDocument.EndRowAutoGrouping();
		TemplateArea = Template.GetArea("Footer");
		TemplateArea.Parameters.Fill(Header);
		SpreadsheetDocument.Put(TemplateArea);
		
		PrintManagement.SetDocumentPrintArea(SpreadsheetDocument, FirstRowNumber, PrintObjects, Header.Ref);
		
	EndDo;
	
	If Not ShowCost Then
		SpreadsheetDocument.DeleteArea(SpreadsheetDocument.Area(, 23, , 25), SpreadsheetDocumentShiftType.Horizontal);
	EndIf;
	
	Return SpreadsheetDocument;
	
EndFunction

Function PrintOrderConfirmation(ObjectsArray, PrintObjects, TemplateName)
	
	SpreadsheetDocument = New SpreadsheetDocument;
	SpreadsheetDocument.PrintParametersKey = "PrintParameters_OrderConfirmation";
	
	Query = New Query();
	Query.SetParameter("ObjectsArray", ObjectsArray);
	
	#Region PrintOrderConfirmationQueryText
	
	Query.Text = 
	"SELECT
	|	SalesOrder.Ref AS Ref,
	|	SalesOrder.Number AS Number,
	|	SalesOrder.Date AS Date,
	|	SalesOrder.Company AS Company,
	|	SalesOrder.Counterparty AS Counterparty,
	|	SalesOrder.Contract AS Contract,
	|	SalesOrder.AmountIncludesVAT AS AmountIncludesVAT,
	|	SalesOrder.DocumentCurrency AS DocumentCurrency,
	|	SalesOrder.ShipmentDate AS ShipmentDate,
	|	CAST(SalesOrder.Comment AS STRING(1024)) AS Comment,
	|	SalesOrder.ShippingAddress AS ShippingAddress,
	|	SalesOrder.ContactPerson AS ContactPerson,
	|	SalesOrder.DeliveryOption AS DeliveryOption,
	|	SalesOrder.StructuralUnitReserve AS StructuralUnit
	|INTO SalesOrders
	|FROM
	|	Document.SalesOrder AS SalesOrder
	|WHERE
	|	SalesOrder.Ref IN(&ObjectsArray)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SalesOrder.Ref AS Ref,
	|	SalesOrder.Number AS DocumentNumber,
	|	SalesOrder.Date AS DocumentDate,
	|	SalesOrder.Company AS Company,
	|	Companies.LogoFile AS CompanyLogoFile,
	|	SalesOrder.Counterparty AS Counterparty,
	|	SalesOrder.Contract AS Contract,
	|	CASE
	|		WHEN SalesOrder.ContactPerson <> VALUE(Catalog.ContactPersons.EmptyRef)
	|			THEN SalesOrder.ContactPerson
	|		WHEN CounterpartyContracts.ContactPerson <> VALUE(Catalog.ContactPersons.EmptyRef)
	|			THEN CounterpartyContracts.ContactPerson
	|		ELSE Counterparties.ContactPerson
	|	END AS CounterpartyContactPerson,
	|	SalesOrder.AmountIncludesVAT AS AmountIncludesVAT,
	|	SalesOrder.DocumentCurrency AS DocumentCurrency,
	|	SalesOrder.ShipmentDate AS ShipmentDate,
	|	SalesOrder.Comment AS Comment,
	|	SalesOrder.ShippingAddress AS ShippingAddress,
	|	SalesOrder.DeliveryOption AS DeliveryOption,
	|	SalesOrder.StructuralUnit AS StructuralUnit
	|INTO Header
	|FROM
	|	SalesOrders AS SalesOrder
	|		LEFT JOIN Catalog.Companies AS Companies
	|		ON SalesOrder.Company = Companies.Ref
	|		LEFT JOIN Catalog.Counterparties AS Counterparties
	|		ON SalesOrder.Counterparty = Counterparties.Ref
	|		LEFT JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
	|		ON SalesOrder.Contract = CounterpartyContracts.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SalesOrderInventory.Ref AS Ref,
	|	SalesOrderInventory.LineNumber AS LineNumber,
	|	SalesOrderInventory.Products AS Products,
	|	SalesOrderInventory.Characteristic AS Characteristic,
	|	SalesOrderInventory.Batch AS Batch,
	|	SalesOrderInventory.Quantity AS Quantity,
	|	SalesOrderInventory.MeasurementUnit AS MeasurementUnit,
	|	SalesOrderInventory.Price * (SalesOrderInventory.Total - SalesOrderInventory.VATAmount) / SalesOrderInventory.Amount AS Price,
	|	SalesOrderInventory.DiscountMarkupPercent AS DiscountMarkupPercent,
	|	SalesOrderInventory.Total - SalesOrderInventory.VATAmount AS Amount,
	|	SalesOrderInventory.VATRate AS VATRate,
	|	SalesOrderInventory.VATAmount AS VATAmount,
	|	SalesOrderInventory.Total AS Total,
	|	SalesOrderInventory.Content AS Content,
	|	SalesOrderInventory.AutomaticDiscountsPercent AS AutomaticDiscountsPercent,
	|	SalesOrderInventory.AutomaticDiscountAmount AS AutomaticDiscountAmount,
	|	SalesOrderInventory.ConnectionKey AS ConnectionKey
	|INTO FilteredInventory
	|FROM
	|	Document.SalesOrder.Inventory AS SalesOrderInventory
	|WHERE
	|	SalesOrderInventory.Ref IN(&ObjectsArray)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Header.Ref AS Ref,
	|	Header.DocumentNumber AS DocumentNumber,
	|	Header.DocumentDate AS DocumentDate,
	|	Header.Company AS Company,
	|	Header.CompanyLogoFile AS CompanyLogoFile,
	|	Header.Counterparty AS Counterparty,
	|	Header.Contract AS Contract,
	|	Header.CounterpartyContactPerson AS CounterpartyContactPerson,
	|	Header.AmountIncludesVAT AS AmountIncludesVAT,
	|	Header.DocumentCurrency AS DocumentCurrency,
	|	Header.ShipmentDate AS ShipmentDate,
	|	Header.Comment AS Comment,
	|	MIN(FilteredInventory.LineNumber) AS LineNumber,
	|	CatalogProducts.SKU AS SKU,
	|	CASE
	|		WHEN (CAST(FilteredInventory.Content AS STRING(1024))) <> """"
	|			THEN CAST(FilteredInventory.Content AS STRING(1024))
	|		WHEN (CAST(CatalogProducts.DescriptionFull AS STRING(1024))) <> """"
	|			THEN CAST(CatalogProducts.DescriptionFull AS STRING(1024))
	|		ELSE CatalogProducts.Description
	|	END AS ProductDescription,
	|	(CAST(FilteredInventory.Content AS STRING(1024))) <> """" AS ContentUsed,
	|	CASE
	|		WHEN CatalogProducts.UseCharacteristics
	|			THEN CatalogCharacteristics.Description
	|		ELSE """"
	|	END AS CharacteristicDescription,
	|	CASE
	|		WHEN CatalogProducts.UseBatches
	|			THEN CatalogBatches.Description
	|		ELSE """"
	|	END AS BatchDescription,
	|	CatalogProducts.UseSerialNumbers AS UseSerialNumbers,
	|	MIN(FilteredInventory.ConnectionKey) AS ConnectionKey,
	|	ISNULL(CatalogUOM.Description, CatalogUOMClassifier.Description) AS UOM,
	|	SUM(FilteredInventory.Quantity) AS Quantity,
	|	FilteredInventory.Price AS Price,
	|	SUM(FilteredInventory.AutomaticDiscountAmount) AS AutomaticDiscountAmount,
	|	FilteredInventory.DiscountMarkupPercent AS DiscountMarkupPercent,
	|	SUM(FilteredInventory.Amount) AS Amount,
	|	FilteredInventory.Price * SUM(CASE
	|			WHEN CatalogProducts.IsFreightService
	|				THEN FilteredInventory.Quantity
	|			ELSE 0
	|		END) AS Freight,
	|	FilteredInventory.VATRate AS VATRate,
	|	SUM(FilteredInventory.VATAmount) AS VATAmount,
	|	SUM(FilteredInventory.Total) AS Total,
	|	FilteredInventory.Price * SUM(CASE
	|			WHEN CatalogProducts.IsFreightService
	|				THEN 0
	|			ELSE FilteredInventory.Quantity
	|		END) AS Subtotal,
	|	FilteredInventory.Products AS Products,
	|	FilteredInventory.Characteristic AS Characteristic,
	|	FilteredInventory.Batch AS Batch,
	|	FilteredInventory.MeasurementUnit AS MeasurementUnit,
	|	Header.ShippingAddress AS ShippingAddress,
	|	Header.DeliveryOption AS DeliveryOption,
	|	Header.StructuralUnit AS StructuralUnit,
	|	CatalogProducts.IsFreightService AS IsFreightService
	|INTO Tabular
	|FROM
	|	Header AS Header
	|		INNER JOIN FilteredInventory AS FilteredInventory
	|		ON Header.Ref = FilteredInventory.Ref
	|		LEFT JOIN Catalog.Products AS CatalogProducts
	|		ON (FilteredInventory.Products = CatalogProducts.Ref)
	|		LEFT JOIN Catalog.ProductsCharacteristics AS CatalogCharacteristics
	|		ON (FilteredInventory.Characteristic = CatalogCharacteristics.Ref)
	|		LEFT JOIN Catalog.ProductsBatches AS CatalogBatches
	|		ON (FilteredInventory.Batch = CatalogBatches.Ref)
	|		LEFT JOIN Catalog.UOM AS CatalogUOM
	|		ON (FilteredInventory.MeasurementUnit = CatalogUOM.Ref)
	|		LEFT JOIN Catalog.UOMClassifier AS CatalogUOMClassifier
	|		ON (FilteredInventory.MeasurementUnit = CatalogUOMClassifier.Ref)
	|
	|GROUP BY
	|	FilteredInventory.VATRate,
	|	Header.Company,
	|	Header.Counterparty,
	|	Header.Contract,
	|	CatalogProducts.SKU,
	|	Header.CounterpartyContactPerson,
	|	Header.AmountIncludesVAT,
	|	Header.Comment,
	|	CASE
	|		WHEN (CAST(FilteredInventory.Content AS STRING(1024))) <> """"
	|			THEN CAST(FilteredInventory.Content AS STRING(1024))
	|		WHEN (CAST(CatalogProducts.DescriptionFull AS STRING(1024))) <> """"
	|			THEN CAST(CatalogProducts.DescriptionFull AS STRING(1024))
	|		ELSE CatalogProducts.Description
	|	END,
	|	Header.ShipmentDate,
	|	(CAST(FilteredInventory.Content AS STRING(1024))) <> """",
	|	Header.CompanyLogoFile,
	|	Header.DocumentNumber,
	|	Header.DocumentCurrency,
	|	Header.Ref,
	|	Header.DocumentDate,
	|	CASE
	|		WHEN CatalogProducts.UseCharacteristics
	|			THEN CatalogCharacteristics.Description
	|		ELSE """"
	|	END,
	|	CASE
	|		WHEN CatalogProducts.UseBatches
	|			THEN CatalogBatches.Description
	|		ELSE """"
	|	END,
	|	CatalogProducts.UseSerialNumbers,
	|	ISNULL(CatalogUOM.Description, CatalogUOMClassifier.Description),
	|	FilteredInventory.DiscountMarkupPercent,
	|	FilteredInventory.Products,
	|	FilteredInventory.Characteristic,
	|	FilteredInventory.Batch,
	|	FilteredInventory.MeasurementUnit,
	|	FilteredInventory.Price,
	|	Header.ShippingAddress,
	|	Header.DeliveryOption,
	|	Header.StructuralUnit,
	|	CatalogProducts.IsFreightService
	|
	|UNION ALL
	|
	|SELECT
	|	Header.Ref,
	|	Header.DocumentNumber,
	|	Header.DocumentDate,
	|	Header.Company,
	|	Header.CompanyLogoFile,
	|	Header.Counterparty,
	|	Header.Contract,
	|	Header.CounterpartyContactPerson,
	|	Header.AmountIncludesVAT,
	|	Header.DocumentCurrency,
	|	Header.ShipmentDate,
	|	Header.Comment,
	|	SalesOrderWorks.LineNumber,
	|	CatalogProducts.SKU,
	|	CASE
	|		WHEN (CAST(SalesOrderWorks.Content AS STRING(1024))) <> """"
	|			THEN CAST(SalesOrderWorks.Content AS STRING(1024))
	|		WHEN (CAST(CatalogProducts.DescriptionFull AS STRING(1024))) <> """"
	|			THEN CAST(CatalogProducts.DescriptionFull AS STRING(1024))
	|		ELSE CatalogProducts.Description
	|	END,
	|	(CAST(SalesOrderWorks.Content AS STRING(1024))) <> """",
	|	CASE
	|		WHEN CatalogProducts.UseCharacteristics
	|			THEN CatalogCharacteristics.Description
	|		ELSE """"
	|	END,
	|	"""",
	|	CatalogProducts.UseSerialNumbers,
	|	SalesOrderWorks.ConnectionKey,
	|	CatalogUOMClassifier.Description,
	|	CAST(SalesOrderWorks.Quantity * SalesOrderWorks.Factor * SalesOrderWorks.Multiplicity AS NUMBER(15, 3)),
	|	SalesOrderWorks.Price,
	|	SalesOrderWorks.AutomaticDiscountAmount,
	|	SalesOrderWorks.DiscountMarkupPercent,
	|	SalesOrderWorks.Amount,
	|	0,
	|	SalesOrderWorks.VATRate,
	|	SalesOrderWorks.VATAmount,
	|	SalesOrderWorks.Total,
	|	CAST(SalesOrderWorks.Quantity * SalesOrderWorks.Price AS NUMBER(15, 2)),
	|	CatalogProducts.Ref,
	|	CatalogCharacteristics.Ref,
	|	VALUE(Catalog.ProductsBatches.EmptyRef),
	|	CatalogUOMClassifier.Ref,
	|	Header.ShippingAddress,
	|	Header.DeliveryOption,
	|	Header.StructuralUnit,
	|	CatalogProducts.IsFreightService
	|FROM
	|	Header AS Header
	|		INNER JOIN Document.SalesOrder.Works AS SalesOrderWorks
	|		ON Header.Ref = SalesOrderWorks.Ref
	|		LEFT JOIN Catalog.Products AS CatalogProducts
	|		ON (SalesOrderWorks.Products = CatalogProducts.Ref)
	|		LEFT JOIN Catalog.ProductsCharacteristics AS CatalogCharacteristics
	|		ON (SalesOrderWorks.Characteristic = CatalogCharacteristics.Ref)
	|		LEFT JOIN Catalog.UOMClassifier AS CatalogUOMClassifier
	|		ON (CatalogProducts.MeasurementUnit = CatalogUOMClassifier.Ref)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Tabular.Ref AS Ref,
	|	Tabular.DocumentNumber AS DocumentNumber,
	|	Tabular.DocumentDate AS DocumentDate,
	|	Tabular.Company AS Company,
	|	Tabular.CompanyLogoFile AS CompanyLogoFile,
	|	Tabular.Counterparty AS Counterparty,
	|	Tabular.Contract AS Contract,
	|	Tabular.CounterpartyContactPerson AS CounterpartyContactPerson,
	|	Tabular.AmountIncludesVAT AS AmountIncludesVAT,
	|	Tabular.DocumentCurrency AS DocumentCurrency,
	|	Tabular.ShipmentDate AS ShipmentDate,
	|	Tabular.Comment AS Comment,
	|	Tabular.LineNumber AS LineNumber,
	|	Tabular.SKU AS SKU,
	|	Tabular.ProductDescription AS ProductDescription,
	|	Tabular.ContentUsed AS ContentUsed,
	|	Tabular.UseSerialNumbers AS UseSerialNumbers,
	|	Tabular.ConnectionKey AS ConnectionKey,
	|	Tabular.Quantity AS Quantity,
	|	Tabular.Price AS Price,
	|	CASE
	|		WHEN Tabular.AutomaticDiscountAmount = 0
	|			THEN Tabular.DiscountMarkupPercent
	|		WHEN Tabular.Subtotal = 0
	|			THEN 0
	|		ELSE CAST((Tabular.Subtotal - Tabular.Amount) / Tabular.Subtotal * 100 AS NUMBER(15, 2))
	|	END AS DiscountRate,
	|	Tabular.Amount AS Amount,
	|	Tabular.Freight AS FreightTotal,
	|	Tabular.VATRate AS VATRate,
	|	Tabular.VATAmount AS VATAmount,
	|	Tabular.Total AS Total,
	|	Tabular.Subtotal AS Subtotal,
	|	CAST(Tabular.Quantity * Tabular.Price - Tabular.Amount AS NUMBER(15, 2)) AS DiscountAmount,
	|	Tabular.CharacteristicDescription AS CharacteristicDescription,
	|	Tabular.BatchDescription AS BatchDescription,
	|	Tabular.Characteristic AS Characteristic,
	|	Tabular.Batch AS Batch,
	|	Tabular.UOM AS UOM,
	|	Tabular.ShippingAddress AS ShippingAddress,
	|	Tabular.DeliveryOption AS DeliveryOption,
	|	Tabular.StructuralUnit AS StructuralUnit
	|FROM
	|	Tabular AS Tabular
	|
	|ORDER BY
	|	DocumentNumber,
	|	LineNumber
	|TOTALS
	|	MAX(DocumentNumber),
	|	MAX(DocumentDate),
	|	MAX(Company),
	|	MAX(CompanyLogoFile),
	|	MAX(Counterparty),
	|	MAX(Contract),
	|	MAX(CounterpartyContactPerson),
	|	MAX(AmountIncludesVAT),
	|	MAX(DocumentCurrency),
	|	MAX(ShipmentDate),
	|	MAX(Comment),
	|	COUNT(LineNumber),
	|	SUM(Quantity),
	|	SUM(FreightTotal),
	|	SUM(VATAmount),
	|	SUM(Total),
	|	SUM(Subtotal),
	|	SUM(DiscountAmount),
	|	MAX(ShippingAddress),
	|	MAX(DeliveryOption),
	|	MAX(StructuralUnit)
	|BY
	|	Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Tabular.ConnectionKey AS ConnectionKey,
	|	Tabular.Ref AS Ref,
	|	SerialNumbers.Description AS SerialNumber
	|FROM
	|	FilteredInventory AS FilteredInventory
	|		INNER JOIN Tabular AS Tabular
	|		ON FilteredInventory.Products = Tabular.Products
	|			AND FilteredInventory.DiscountMarkupPercent = Tabular.DiscountMarkupPercent
	|			AND FilteredInventory.Price = Tabular.Price
	|			AND FilteredInventory.VATRate = Tabular.VATRate
	|			AND (NOT Tabular.ContentUsed)
	|			AND FilteredInventory.Ref = Tabular.Ref
	|			AND FilteredInventory.Characteristic = Tabular.Characteristic
	|			AND FilteredInventory.MeasurementUnit = Tabular.MeasurementUnit
	|			AND FilteredInventory.Batch = Tabular.Batch
	|		INNER JOIN Document.SalesInvoice.SerialNumbers AS SalesOrderSerialNumbers
	|			LEFT JOIN Catalog.SerialNumbers AS SerialNumbers
	|			ON SalesOrderSerialNumbers.SerialNumber = SerialNumbers.Ref
	|		ON (SalesOrderSerialNumbers.ConnectionKey = FilteredInventory.ConnectionKey)
	|			AND FilteredInventory.Ref = SalesOrderSerialNumbers.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	COUNT(Tabular.LineNumber) AS LineNumber,
	|	Tabular.Ref AS Ref,
	|	SUM(Tabular.Quantity) AS Quantity
	|FROM
	|	Tabular AS Tabular
	|WHERE
	|	NOT Tabular.IsFreightService
	|
	|GROUP BY
	|	Tabular.Ref";
	
	#EndRegion
	
	ResultArray = Query.ExecuteBatch();
	
	FirstDocument = True;
	
	Header 				= ResultArray[4].Select(QueryResultIteration.ByGroupsWithHierarchy);
	SerialNumbersSel	= ResultArray[5].Select();
	TotalLineNumber		= ResultArray[6].Unload();
	
	While Header.Next() Do
		
		If Not FirstDocument Then
			SpreadsheetDocument.PutHorizontalPageBreak();
		EndIf;
		FirstDocument = False;
		
		FirstLineNumber = SpreadsheetDocument.TableHeight + 1;
		
		SpreadsheetDocument.PrintParametersName = "PRINT_PARAMETERS_SalesOrder_OrderConfirmation";
		
		Template = PrintManagement.PrintedFormsTemplate("Document.SalesOrder.PF_MXL_OrderConfirmation");
		
		#Region PrintOrderConfirmationTitleArea
		
		TitleArea = Template.GetArea("Title");
		TitleArea.Parameters.Fill(Header);
		
		If ValueIsFilled(Header.CompanyLogoFile) Then
			
			PictureData = AttachedFiles.GetFileBinaryData(Header.CompanyLogoFile);
			If ValueIsFilled(PictureData) Then
				
				TitleArea.Drawings.Logo.Picture = New Picture(PictureData);
				
			EndIf;
			
		Else
			
			TitleArea.Drawings.Delete(TitleArea.Drawings.Logo);
			
		EndIf;
		
		SpreadsheetDocument.Put(TitleArea);
		
		#EndRegion
		
		#Region PrintOrderConfirmationCompanyInfoArea
		
		CompanyInfoArea = Template.GetArea("CompanyInfo");
		
		InfoAboutCompany = DriveServer.InfoAboutLegalEntityIndividual(Header.Company, Header.DocumentDate, ,);
		CompanyInfoArea.Parameters.Fill(InfoAboutCompany);
		
		SpreadsheetDocument.Put(CompanyInfoArea);
		
		#EndRegion
		
		#Region PrintOrderConfirmationCounterpartyInfoArea
		
		CounterpartyInfoArea = Template.GetArea("CounterpartyInfo");
		CounterpartyInfoArea.Parameters.Fill(Header);
		
		InfoAboutCounterparty = DriveServer.InfoAboutLegalEntityIndividual(Header.Counterparty, Header.DocumentDate, ,);
		CounterpartyInfoArea.Parameters.Fill(InfoAboutCounterparty);
		
		TitleParameters = New Structure;
		TitleParameters.Insert("TitleShipTo", NStr("en = 'Ship to'"));
		TitleParameters.Insert("TitleShipDate", NStr("en = 'Ship date'"));
		
		If Header.DeliveryOption = Enums.DeliveryOptions.SelfPickup Then
			
			InfoAboutPickupLocation	= DriveServer.InfoAboutLegalEntityIndividual(Header.StructuralUnit, Header.DocumentDate);
			ResponsibleEmployee		= InfoAboutPickupLocation.ResponsibleEmployee;
			
			If NOT IsBlankString(InfoAboutPickupLocation.FullDescr) Then
				CounterpartyInfoArea.Parameters.FullDescrShipTo = InfoAboutPickupLocation.FullDescr;
			EndIf;
			
			If NOT IsBlankString(InfoAboutPickupLocation.DeliveryAddress) Then
				CounterpartyInfoArea.Parameters.DeliveryAddress = InfoAboutPickupLocation.DeliveryAddress;
			EndIf;
			
			If ValueIsFilled(ResponsibleEmployee) Then
				CounterpartyInfoArea.Parameters.CounterpartyContactPerson = ResponsibleEmployee.Description;
			EndIf;
			
			If NOT IsBlankString(InfoAboutPickupLocation.PhoneNumbers) Then
				CounterpartyInfoArea.Parameters.PhoneNumbers = InfoAboutPickupLocation.PhoneNumbers;
			EndIf;
			
			TitleParameters.TitleShipTo		= NStr("en = 'Pickup location'");
			TitleParameters.TitleShipDate	= NStr("en = 'Pickup date'");
			
		Else
			
			InfoAboutShippingAddress	= DriveServer.InfoAboutShippingAddress(Header.ShippingAddress);
			InfoAboutContactPerson		= DriveServer.InfoAboutContactPerson(Header.CounterpartyContactPerson);
		
			If NOT IsBlankString(InfoAboutShippingAddress.DeliveryAddress) Then
				CounterpartyInfoArea.Parameters.DeliveryAddress = InfoAboutShippingAddress.DeliveryAddress;
			EndIf;
			
			If NOT IsBlankString(InfoAboutContactPerson.PhoneNumbers) Then
				CounterpartyInfoArea.Parameters.PhoneNumbers = InfoAboutContactPerson.PhoneNumbers;
			EndIf;
			
		EndIf;
		
		CounterpartyInfoArea.Parameters.Fill(TitleParameters);
		
		If IsBlankString(CounterpartyInfoArea.Parameters.DeliveryAddress) Then
			
			If Not IsBlankString(InfoAboutCounterparty.ActualAddress) Then
				
				CounterpartyInfoArea.Parameters.DeliveryAddress = InfoAboutCounterparty.ActualAddress;
				
			Else
				
				CounterpartyInfoArea.Parameters.DeliveryAddress = InfoAboutCounterparty.LegalAddress;
				
			EndIf;
			
		EndIf;
		
		CounterpartyInfoArea.Parameters.PaymentTerms = PaymentTermsServer.TitlePaymentTerms(Header.Ref);
		
		SpreadsheetDocument.Put(CounterpartyInfoArea);
		
		#EndRegion
		
		#Region PrintOrderConfirmationCommentArea
		
		CommentArea = Template.GetArea("Comment");
		CommentArea.Parameters.Fill(Header);
		SpreadsheetDocument.Put(CommentArea);
		
		#EndRegion
		
		#Region PrintOrderConfirmationTotalsAreaPrefill
		
		TotalsAreasArray = New Array;
		
		LineTotalArea = Template.GetArea("LineTotal");
		LineTotalArea.Parameters.Fill(Header);
		
		SearchStructure = New Structure("Ref", Header.Ref);
		
		SearchArray = TotalLineNumber.FindRows(SearchStructure);
		If SearchArray.Count() > 0 Then
			LineTotalArea.Parameters.Quantity	= SearchArray[0].Quantity;
			LineTotalArea.Parameters.LineNumber	= SearchArray[0].LineNumber;
		Else
			LineTotalArea.Parameters.Quantity	= 0;
			LineTotalArea.Parameters.LineNumber	= 0;
		EndIf;
		
		TotalsAreasArray.Add(LineTotalArea);
		
		#EndRegion
		
		#Region PrintOrderConfirmationLinesArea
		
		LineHeaderArea = Template.GetArea("LineHeader");
		SpreadsheetDocument.Put(LineHeaderArea);
		
		LineSectionArea	= Template.GetArea("LineSection");
		SeeNextPageArea	= Template.GetArea("SeeNextPage");
		EmptyLineArea	= Template.GetArea("EmptyLine");
		PageNumberArea	= Template.GetArea("PageNumber");
		
		PageNumber = 0;
		AreasToBeChecked = New Array;
		
		TabSelection = Header.Select();
		While TabSelection.Next() Do
			
			If TabSelection.FreightTotal <> 0 Then
				Continue;
			EndIf;
			
			LineSectionArea.Parameters.Fill(TabSelection);
			
			PrintManagement.ComplimentProductDescription(LineSectionArea.Parameters.ProductDescription, TabSelection, SerialNumbersSel);
			
			AreasToBeChecked.Add(LineSectionArea);
			For Each Area In TotalsAreasArray Do
				AreasToBeChecked.Add(Area);
			EndDo;
			AreasToBeChecked.Add(PageNumberArea);
			
			If CommonUse.SpreadsheetDocumentFitsPage(SpreadsheetDocument, AreasToBeChecked) Then
				
				SpreadsheetDocument.Put(LineSectionArea);
				
			Else
				
				SpreadsheetDocument.Put(SeeNextPageArea);
				
				AreasToBeChecked.Clear();
				AreasToBeChecked.Add(EmptyLineArea);
				AreasToBeChecked.Add(PageNumberArea);
				
				For i = 1 To 50 Do
					
					If Not CommonUse.SpreadsheetDocumentFitsPage(SpreadsheetDocument, AreasToBeChecked)
						Or i = 50 Then
						
						PageNumber = PageNumber + 1;
						PageNumberArea.Parameters.PageNumber = PageNumber;
						SpreadsheetDocument.Put(PageNumberArea);
						Break;
						
					Else
						
						SpreadsheetDocument.Put(EmptyLineArea);
						
					EndIf;
					
				EndDo;
				
				SpreadsheetDocument.PutHorizontalPageBreak();
				SpreadsheetDocument.Put(TitleArea);
				SpreadsheetDocument.Put(LineHeaderArea);
				SpreadsheetDocument.Put(LineSectionArea);
				
			EndIf;
			
		EndDo;
		
		#EndRegion
		
		#Region PrintOrderConfirmationTotalsArea
		
		For Each Area In TotalsAreasArray Do
			
			SpreadsheetDocument.Put(Area);
			
		EndDo;
		
		AreasToBeChecked.Clear();
		AreasToBeChecked.Add(EmptyLineArea);
		AreasToBeChecked.Add(PageNumberArea);
		
		For i = 1 To 50 Do
			
			If Not CommonUse.SpreadsheetDocumentFitsPage(SpreadsheetDocument, AreasToBeChecked)
				Or i = 50 Then
				
				PageNumber = PageNumber + 1;
				PageNumberArea.Parameters.PageNumber = PageNumber;
				SpreadsheetDocument.Put(PageNumberArea);
				Break;
				
			Else
				
				SpreadsheetDocument.Put(EmptyLineArea);
				
			EndIf;
			
		EndDo;
		
		#EndRegion
		
		PrintManagement.SetDocumentPrintArea(SpreadsheetDocument, FirstLineNumber, PrintObjects, Header.Ref);
		
	EndDo;
	
	SpreadsheetDocument.FitToPage = True;
	
	Return SpreadsheetDocument;
	
EndFunction

// Function checks if the document is posted and calls
// the procedure of document printing.
//
Function PrintForm(ObjectsArray, PrintObjects, TemplateName)
	
	If TemplateName = "Quote" Then
		
		Return DataProcessors.PrintQuote.PrintQuote(ObjectsArray, PrintObjects, TemplateName);
		
	ElsIf TemplateName = "ProformaInvoice" Then
		
		Return DataProcessors.PrintQuote.PrintProformaInvoice(ObjectsArray, PrintObjects, TemplateName);
		
	ElsIf TemplateName = "GuaranteeCard" Then
		
		Return WorkWithProductsServer.PrintGuaranteeCard(ObjectsArray, PrintObjects);
				
	ElsIf TemplateName = "Estimate" Then
		
		Return PrintEstimate(ObjectsArray, PrintObjects, TemplateName);
		
	ElsIf TemplateName = "OrderConfirmation" Then
		
		Return PrintOrderConfirmation(ObjectsArray, PrintObjects, TemplateName);
		
	EndIf;
	
EndFunction

// Generate printed forms of objects
//
// Incoming:
//  TemplateNames   - String	- Names of layouts separated by commas 
//	ObjectsArray	- Array		- Array of refs to objects that need to be printed 
//	PrintParameters - Structure - Structure of additional printing parameters
//
// Outgoing:
//   PrintFormsCollection	- Values table	- Generated table documents 
//	OutputParameters		- Structure     - Parameters of generated table documents
//
Procedure Print(ObjectsArray, PrintParameters, PrintFormsCollection, PrintObjects, OutputParameters) Export
	
	If PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "Quote") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection, "Quote", "Quote", PrintForm(ObjectsArray, PrintObjects, "Quote"));
		
	ElsIf PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "ProformaInvoice") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection, "ProformaInvoice", "Proforma invoice", PrintForm(ObjectsArray, PrintObjects, "ProformaInvoice"));
		
	ElsIf PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "GuaranteeCard") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection, "GuaranteeCard", "Warranty card", PrintForm(ObjectsArray, PrintObjects, "GuaranteeCard"));
		
	ElsIf PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "Estimate") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection, "Estimate", "Estimate", PrintForm(ObjectsArray, PrintObjects, "Estimate"));
		
	ElsIf PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "OrderConfirmation") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection, "OrderConfirmation", "Order confirmation", PrintForm(ObjectsArray, PrintObjects, "OrderConfirmation"));
		
	ElsIf PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "PickList") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection, "PickList", "Pick list", DataProcessors.PrintPickList.PrintForm(ObjectsArray, PrintObjects, "PickList"));
		
	ElsIf PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "Requisition") Then
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection,
															"Requisition",
															NStr("en = 'Requisition'"),
															DataProcessors.PrintRequisition.PrintForm(ObjectsArray, PrintObjects, "Requisition"));
	EndIf;
	
	// parameters of sending printing forms by email
	DriveServer.FillSendingParameters(OutputParameters.SendingParameters, ObjectsArray, PrintFormsCollection);
	
EndProcedure

// Fills in Sales order printing commands list
// 
// Parameters:
//   PrintCommands - ValueTable - see fields' content in the PrintManagement.CreatePrintCommandsCollection function.
//
Procedure AddPrintCommands(PrintCommands) Export
	
	// Order confirmation
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID							= "OrderConfirmation";
	PrintCommand.Presentation				= NStr("en = 'Order confirmation'");
	PrintCommand.FormsList					= "DocumentForm, ListForm, ShipmentDocumentsListForm, PaymentDocumentsListForm";
	PrintCommand.CheckPostingBeforePrint	= False;
	PrintCommand.PlaceProperties			= "GroupImportantCommandsSalesOrder";
	PrintCommand.Order						= 1;
	
	// Pick list
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID							= "PickList";
	PrintCommand.Presentation				= NStr("en = 'Pick list'");
	PrintCommand.FormsList					= "DocumentForm, ListForm, ShipmentDocumentsListForm, PaymentDocumentsListForm";
	PrintCommand.CheckPostingBeforePrint	= False;
	PrintCommand.PlaceProperties			= "GroupImportantCommandsSalesOrder";
	PrintCommand.Order						= 2;
	
	// Quote
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID							= "Quote";
	PrintCommand.Presentation				= NStr("en = 'Quotation'");
	PrintCommand.FormsList					= "DocumentForm,ListForm,ShipmentDocumentsListForm,PaymentDocumentsListForm";
	PrintCommand.CheckPostingBeforePrint	= False;
	PrintCommand.PlaceProperties			= "GroupImportantCommandsSalesOrder";
	PrintCommand.Order						= 3;
	
	// Proforma invoice
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID							= "ProformaInvoice";
	PrintCommand.Presentation				= NStr("en = 'Proforma invoice'");
	PrintCommand.FormsList					= "DocumentForm,ListForm,ShipmentDocumentsListForm,PaymentDocumentsListForm";
	PrintCommand.CheckPostingBeforePrint	= False;
	PrintCommand.PlaceProperties			= "GroupImportantCommandsSalesOrder";
	PrintCommand.Order						= 10;
	
	// Contract
	PrintCommand = PrintCommands.Add();
	PrintCommand.Handler					= "DriveClient.GenerateContractForms";
	PrintCommand.ID							= "ContractForm";
	PrintCommand.Presentation				= NStr("en = 'Contract template'");
	PrintCommand.FormsList					= "DocumentForm,ListForm,ShipmentDocumentsListForm,PaymentDocumentsListForm";
	PrintCommand.CheckPostingBeforePrint	= False;
	PrintCommand.PlaceProperties			= "GroupImportantCommandsSalesOrder";
	PrintCommand.Order						= 17;
	
	// Work order
	//
	
	// Documents set
	PrintCommand = PrintCommands.Add();
	
	IdentifierValue = "ProformaInvoice,GuaranteeCard";
	IdentifierValue = StrReplace(IdentifierValue, ",GuaranteeCard", ?(GetFunctionalOption("UseSerialNumbers"), ",GuaranteeCard", ""));
	
	PrintCommand.ID							= IdentifierValue;
	PrintCommand.Presentation				= NStr("en = 'Customizable document set'");
	PrintCommand.FormsList					= "ShipmentDocumentsListForm,PaymentDocumentsListForm";
	PrintCommand.CheckPostingBeforePrint	= False;
	PrintCommand.PlaceProperties			= "GroupImportantCommandsWorkOrder";
	PrintCommand.Order						= 51;
	
	// Invoice for payment
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID							= "ProformaInvoice";
	PrintCommand.Presentation				= NStr("en = 'Quote'");
	PrintCommand.FormsList					= "ShipmentDocumentsListForm,PaymentDocumentsListForm";
	PrintCommand.CheckPostingBeforePrint	= False;
	PrintCommand.PlaceProperties			= "GroupImportantCommandsWorkOrder";
	PrintCommand.Order						= 72;
	
	// Contract
	PrintCommand = PrintCommands.Add();
	PrintCommand.Handler					= "DriveClient.GenerateContractForms";
	PrintCommand.ID							= "ContractForm";
	PrintCommand.Presentation				= NStr("en = 'Contract template'");
	PrintCommand.FormsList					= "ShipmentDocumentsListForm,PaymentDocumentsListForm";
	PrintCommand.CheckPostingBeforePrint	= False;
	PrintCommand.PlaceProperties			= "GroupImportantCommandsWorkOrder";
	PrintCommand.Order						= 96;
	
	// Estimate
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID							= "Estimate";
	PrintCommand.Presentation				= NStr("en = 'Estimate'");
	PrintCommand.FormsList					= "DocumentForm,EstimateForm";
	PrintCommand.CheckPostingBeforePrint	= False;
	PrintCommand.PlaceProperties			= "GroupImportantCommandsSalesOrder";
	PrintCommand.Order						= 18;
	
	//Requisition
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID							= "Requisition";
	PrintCommand.Presentation				= NStr("en = 'Requisition'");
	PrintCommand.FormsList					= "ShipmentDocumentsListForm,PaymentDocumentsListForm";
	PrintCommand.CheckPostingBeforePrint	= False;
	PrintCommand.PlaceProperties			= "GroupImportantCommandsWorkOrder";
	PrintCommand.Order						= 103;
	
EndProcedure

#EndRegion

#Region EventHandlers

Procedure PresentationFieldsGetProcessing(Fields, StandardProcessing)
	
	StandardProcessing = False;
	Fields.Add("Ref");
	Fields.Add("Date");
	Fields.Add("Number");
	Fields.Add("OperationKind");
	Fields.Add("Posted");
	Fields.Add("DeletionMark");
	
EndProcedure

#EndRegion

#Region InfobaseUpdate

Procedure FillNewGLAccounts() Export
	
	DocumentName = "SalesOrder";
	
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
