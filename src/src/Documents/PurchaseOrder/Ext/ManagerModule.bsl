#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventory(DocumentRefPurchaseOrder, StructureAdditionalProperties)
	
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
	
	Query.SetParameter("Ref", DocumentRefPurchaseOrder);
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
			
			TableRowExpense.Amount = AmountToBeWrittenOff;
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
					
				TableRowReceipt.Amount = AmountToBeWrittenOff;
				TableRowReceipt.Quantity = QuantityRequiredReserve;
					
				TableRowReceipt.GLAccount = RowTableInventory.CorrGLAccount;
				TableRowReceipt.RecordKindAccountingJournalEntries = AccountingRecordType.Debit;
					
			EndIf;
			
		EndIf;
		
	EndDo;
	
	StructureAdditionalProperties.TableForRegisterRecords.TableInventory = TemporaryTableInventory;
	
EndProcedure

// Payment calendar table formation procedure.
//
// Parameters:
// DocumentRef - DocumentRef.CashInflowForecast - Current
// document AdditionalProperties - AdditionalProperties - Additional properties of the document
//
Procedure GenerateTablePaymentCalendar(DocumentRefPurchaseOrder, StructureAdditionalProperties)
	
	Query = New Query;
	
	Query.SetParameter("Ref", DocumentRefPurchaseOrder);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	
	Query.Text =
	"SELECT
	|	PurchaseOrder.Ref AS Ref,
	|	PurchaseOrder.AmountIncludesVAT,
	|	PurchaseOrder.ReceiptDate AS ReceiptDate,
	|	PurchaseOrder.CashAssetsType AS CashAssetsType,
	|	PurchaseOrder.Contract AS Contract,
	|	PurchaseOrder.PettyCash AS PettyCash,
	|	PurchaseOrder.DocumentCurrency AS DocumentCurrency,
	|	PurchaseOrder.BankAccount AS BankAccount,
	|	PurchaseOrder.Closed AS Closed,
	|	PurchaseOrder.OrderState AS OrderState
	|INTO Document
	|FROM
	|	Document.PurchaseOrder AS PurchaseOrder
	|WHERE
	|	PurchaseOrder.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	PurchaseOrderPaymentCalendar.PaymentDate AS Period,
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
	|			THEN PurchaseOrderPaymentCalendar.PaymentAmount
	|		ELSE PurchaseOrderPaymentCalendar.PaymentAmount + PurchaseOrderPaymentCalendar.PaymentVATAmount
	|	END AS PaymentAmount
	|INTO PaymentCalendar
	|FROM
	|	Document AS Document
	|		INNER JOIN Catalog.PurchaseOrderStatuses AS PurchaseOrderStatuses
	|		ON Document.OrderState = PurchaseOrderStatuses.Ref
	|			AND (NOT PurchaseOrderStatuses.OrderStatus = VALUE(Enum.OrderStatuses.Open))
	|			AND (NOT(PurchaseOrderStatuses.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|					AND Document.Closed))
	|		INNER JOIN Document.PurchaseOrder.PaymentCalendar AS PurchaseOrderPaymentCalendar
	|		ON Document.Ref = PurchaseOrderPaymentCalendar.Ref
	|			AND (PurchaseOrderPaymentCalendar.PaymentDate <= Document.ReceiptDate)
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
	|	VALUE(Catalog.CashFlowItems.PaymentToVendor) AS Item,
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
	|			THEN CAST(-PaymentCalendar.PaymentAmount * CASE
	|						WHEN SettlementsExchangeRates.ExchangeRate <> 0
	|								AND ExchangeRatesOfDocument.Multiplicity <> 0
	|							THEN ExchangeRatesOfDocument.ExchangeRate * SettlementsExchangeRates.Multiplicity / (ISNULL(SettlementsExchangeRates.ExchangeRate, 1) * ISNULL(ExchangeRatesOfDocument.Multiplicity, 1))
	|						ELSE 1
	|					END AS NUMBER(15, 2))
	|		ELSE -PaymentCalendar.PaymentAmount
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
Procedure GenerateTableInvoicesAndOrdersPayment(DocumentRefPurchaseOrder, StructureAdditionalProperties)
	
	Query = New Query;
	
	Query.SetParameter("Ref", DocumentRefPurchaseOrder);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	
	Query.Text =
	"SELECT
	|	DocumentTable.Date AS Period,
	|	&Company AS Company,
	|	DocumentTable.Ref AS Quote,
	|	DocumentTable.DocumentAmount AS Amount
	|FROM
	|	Document.PurchaseOrder AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|	AND (NOT DocumentTable.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.Open))
	|	AND (NOT(DocumentTable.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|				AND DocumentTable.Ref.Closed))";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInvoicesAndOrdersPayment", QueryResult.Unload());
	
EndProcedure

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
Procedure InitializeDocumentData(DocumentRefPurchaseOrder, StructureAdditionalProperties) Export

	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text = 
	"SELECT
	|	PurchaseOrderInventory.LineNumber AS LineNumber,
	|	PurchaseOrderInventory.Ref.Date AS Period,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	&Company AS Company,
	|	PurchaseOrderInventory.Ref AS PurchaseOrder,
	|	PurchaseOrderInventory.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN PurchaseOrderInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN VALUETYPE(PurchaseOrderInventory.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|			THEN PurchaseOrderInventory.Quantity
	|		ELSE PurchaseOrderInventory.Quantity * PurchaseOrderInventory.MeasurementUnit.Factor
	|	END AS Quantity,
	|	PurchaseOrderInventory.ReceiptDate AS ReceiptDate
	|FROM
	|	Document.PurchaseOrder.Inventory AS PurchaseOrderInventory
	|WHERE
	|	PurchaseOrderInventory.Ref = &Ref
	|	AND (PurchaseOrderInventory.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|				AND PurchaseOrderInventory.Ref.Closed = FALSE
	|			OR PurchaseOrderInventory.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.Completed))
	|
	|ORDER BY
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	PurchaseOrderMaterials.LineNumber AS LineNumber,
	|	PurchaseOrderMaterials.Ref.Date AS Period,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	&Company AS Company,
	|	VALUE(Enum.InventoryMovementTypes.Shipment) AS MovementType,
	|	CASE
	|		WHEN Constants.UseInventoryReservation
	|			THEN PurchaseOrderMaterials.Ref.SalesOrder
	|		ELSE VALUE(Document.SalesOrder.EmptyRef)
	|	END AS SalesOrder,
	|	PurchaseOrderMaterials.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN PurchaseOrderMaterials.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN VALUETYPE(PurchaseOrderMaterials.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|			THEN PurchaseOrderMaterials.Quantity
	|		ELSE PurchaseOrderMaterials.Quantity * PurchaseOrderMaterials.MeasurementUnit.Factor
	|	END AS Quantity
	|FROM
	|	Document.PurchaseOrder.Materials AS PurchaseOrderMaterials,
	|	Constants AS Constants
	|WHERE
	|	PurchaseOrderMaterials.Ref = &Ref
	|	AND PurchaseOrderMaterials.Ref.OperationKind = VALUE(Enum.OperationTypesPurchaseOrder.OrderForProcessing)
	|	AND (PurchaseOrderMaterials.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|				AND PurchaseOrderMaterials.Ref.Closed = FALSE
	|			OR PurchaseOrderMaterials.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.Completed))
	|
	|ORDER BY
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	1 AS Ordering,
	|	PurchaseOrderInventory.LineNumber AS LineNumber,
	|	PurchaseOrderInventory.ReceiptDate AS Period,
	|	&Company AS Company,
	|	VALUE(Enum.InventoryMovementTypes.Receipt) AS MovementType,
	|	PurchaseOrderInventory.Ref AS Order,
	|	PurchaseOrderInventory.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN PurchaseOrderInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN VALUETYPE(PurchaseOrderInventory.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|			THEN PurchaseOrderInventory.Quantity
	|		ELSE PurchaseOrderInventory.Quantity * PurchaseOrderInventory.MeasurementUnit.Factor
	|	END AS Quantity
	|FROM
	|	Document.PurchaseOrder.Inventory AS PurchaseOrderInventory
	|WHERE
	|	PurchaseOrderInventory.Ref = &Ref
	|	AND (PurchaseOrderInventory.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|				AND PurchaseOrderInventory.Ref.Closed = FALSE
	|			OR PurchaseOrderInventory.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.Completed))
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	PurchaseOrderInventory.LineNumber,
	|	PurchaseOrderInventory.ShipmentDate,
	|	&Company,
	|	VALUE(Enum.InventoryMovementTypes.Shipment),
	|	UNDEFINED,
	|	PurchaseOrderInventory.Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN PurchaseOrderInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END,
	|	CASE
	|		WHEN VALUETYPE(PurchaseOrderInventory.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|			THEN PurchaseOrderInventory.Quantity
	|		ELSE PurchaseOrderInventory.Quantity * PurchaseOrderInventory.MeasurementUnit.Factor
	|	END
	|FROM
	|	Document.PurchaseOrder.Materials AS PurchaseOrderInventory
	|WHERE
	|	PurchaseOrderInventory.Ref = &Ref
	|	AND PurchaseOrderInventory.Ref.OperationKind = VALUE(Enum.OperationTypesPurchaseOrder.OrderForProcessing)
	|	AND (PurchaseOrderInventory.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|				AND PurchaseOrderInventory.Ref.Closed = FALSE
	|			OR PurchaseOrderInventory.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.Completed))
	|
	|ORDER BY
	|	Ordering,
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	PurchaseOrderInventory.LineNumber AS LineNumber,
	|	PurchaseOrderInventory.Ref.Date AS Period,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	&Company AS Company,
	|	CASE
	|		WHEN Constants.UseInventoryReservation
	|				AND PurchaseOrderInventory.Ref.SalesOrder <> VALUE(Document.SalesOrder.EmptyRef)
	|			THEN PurchaseOrderInventory.Ref.SalesOrder
	|		ELSE UNDEFINED
	|	END AS SalesOrder,
	|	PurchaseOrderInventory.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN PurchaseOrderInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	PurchaseOrderInventory.Ref AS SupplySource,
	|	CASE
	|		WHEN VALUETYPE(PurchaseOrderInventory.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|			THEN PurchaseOrderInventory.Quantity
	|		ELSE PurchaseOrderInventory.Quantity * PurchaseOrderInventory.MeasurementUnit.Factor
	|	END AS Quantity
	|FROM
	|	Document.PurchaseOrder.Inventory AS PurchaseOrderInventory,
	|	Constants AS Constants
	|WHERE
	|	PurchaseOrderInventory.Ref = &Ref
	|	AND PurchaseOrderInventory.Ref.SalesOrder <> VALUE(Document.SalesOrder.Emptyref)
	|	AND Constants.UseInventoryReservation
	|	AND (PurchaseOrderInventory.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|				AND PurchaseOrderInventory.Ref.Closed = FALSE
	|			OR PurchaseOrderInventory.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.Completed))
	|
	|ORDER BY
	|	PurchaseOrderInventory.LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	PurchaseOrderMaterials.LineNumber AS LineNumber,
	|	PurchaseOrderMaterials.Ref.Date AS Period,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	&Company AS Company,
	|	PurchaseOrderMaterials.Ref.StructuralUnitReserve AS StructuralUnit,
	|	PurchaseOrderMaterials.Products.InventoryGLAccount AS GLAccount,
	|	PurchaseOrderMaterials.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN PurchaseOrderMaterials.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	VALUE(Catalog.ProductsBatches.EmptyRef) AS Batch,
	|	UNDEFINED AS SalesOrder,
	|	CASE
	|		WHEN Constants.UseInventoryReservation
	|				AND PurchaseOrderMaterials.Ref.SalesOrder <> VALUE(Document.SalesOrder.EmptyRef)
	|			THEN PurchaseOrderMaterials.Ref.SalesOrder
	|		ELSE UNDEFINED
	|	END AS CustomerCorrOrder,
	|	CASE
	|		WHEN VALUETYPE(PurchaseOrderMaterials.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|			THEN PurchaseOrderMaterials.Reserve
	|		ELSE PurchaseOrderMaterials.Reserve * PurchaseOrderMaterials.MeasurementUnit.Factor
	|	END AS Quantity,
	|	0 AS Amount,
	|	VALUE(AccountingRecordType.Credit) AS RecordKindAccountingJournalEntries,
	|	&InventoryReservation AS ContentOfAccountingRecord
	|INTO TemporaryTableInventory
	|FROM
	|	Document.PurchaseOrder.Materials AS PurchaseOrderMaterials,
	|	Constants AS Constants
	|WHERE
	|	PurchaseOrderMaterials.Ref = &Ref
	|	AND PurchaseOrderMaterials.Reserve > 0
	|	AND (PurchaseOrderMaterials.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|				AND PurchaseOrderMaterials.Ref.Closed = FALSE
	|			OR PurchaseOrderMaterials.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.Completed))
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
	|	TableInventory.RecordKindAccountingJournalEntries AS RecordKindAccountingJournalEntries,
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
	|	TableInventory.RecordKindAccountingJournalEntries,
	|	TableInventory.StructuralUnit,
	|	TableInventory.GLAccount,
	|	TableInventory.Products,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch";

	MainLanguageCode = CommonUseClientServer.MainLanguageCode();
	
	Query.SetParameter("Ref", DocumentRefPurchaseOrder);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("UseCharacteristics", StructureAdditionalProperties.AccountingPolicy.UseCharacteristics);
	Query.SetParameter("UseBatches",  StructureAdditionalProperties.AccountingPolicy.UseBatches);
	Query.SetParameter("InventoryReservation", NStr("en = 'Inventory reservation'", MainLanguageCode));
	
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TablePurchaseOrders", ResultsArray[0].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryDemand", ResultsArray[1].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryFlowCalendar", ResultsArray[2].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableBackorders", ResultsArray[3].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventory", ResultsArray[5].Unload());
	
	GenerateTableInventory(DocumentRefPurchaseOrder, StructureAdditionalProperties);
	GenerateTablePaymentCalendar(DocumentRefPurchaseOrder, StructureAdditionalProperties);
	GenerateTableInvoicesAndOrdersPayment(DocumentRefPurchaseOrder, StructureAdditionalProperties);
	
EndProcedure

// Controls the occurrence of negative balances.
//
Procedure RunControl(DocumentRefPurchaseOrder, AdditionalProperties, Cancel, PostingDelete = False) Export
	
	If Not DriveServer.RunBalanceControl() Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// If temporary tables "RegisterRecordsPurchaseOrdersChange", "RegisterRecordsInventoryChange",
	// "RegisterRecordsInventoryDemandChange" contain records, control purchse order.
	
	If StructureTemporaryTables.RegisterRecordsPurchaseOrdersChange
		OR StructureTemporaryTables.RegisterRecordsInventoryChange
		OR StructureTemporaryTables.RegisterRecordsInventoryDemandChange Then
		
		Query = New Query(
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
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	RegisterRecordsPurchaseOrdersChange.LineNumber AS LineNumber,
		|	RegisterRecordsPurchaseOrdersChange.Company AS CompanyPresentation,
		|	RegisterRecordsPurchaseOrdersChange.PurchaseOrder AS PurchaseOrderPresentation,
		|	RegisterRecordsPurchaseOrdersChange.Products AS ProductsPresentation,
		|	RegisterRecordsPurchaseOrdersChange.Characteristic AS CharacteristicPresentation,
		|	PurchaseOrdersBalances.Products.MeasurementUnit AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsPurchaseOrdersChange.QuantityChange, 0) + ISNULL(PurchaseOrdersBalances.QuantityBalance, 0) AS BalancePurchaseOrders,
		|	ISNULL(PurchaseOrdersBalances.QuantityBalance, 0) AS QuantityBalancePurchaseOrders
		|FROM
		|	RegisterRecordsPurchaseOrdersChange AS RegisterRecordsPurchaseOrdersChange
		|		INNER JOIN AccumulationRegister.PurchaseOrders.Balance(&ControlTime, ) AS PurchaseOrdersBalances
		|		ON RegisterRecordsPurchaseOrdersChange.Company = PurchaseOrdersBalances.Company
		|			AND RegisterRecordsPurchaseOrdersChange.PurchaseOrder = PurchaseOrdersBalances.PurchaseOrder
		|			AND RegisterRecordsPurchaseOrdersChange.Products = PurchaseOrdersBalances.Products
		|			AND RegisterRecordsPurchaseOrdersChange.Characteristic = PurchaseOrdersBalances.Characteristic
		|			AND (ISNULL(PurchaseOrdersBalances.QuantityBalance, 0) < 0)
		|
		|ORDER BY
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
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
		|	LineNumber");
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.SetParameter("ControlTime", AdditionalProperties.ForPosting.ControlTime);
		
		ResultsArray = Query.ExecuteBatch();
		
		If Not ResultsArray[0].IsEmpty()
			OR Not ResultsArray[1].IsEmpty()
			OR Not ResultsArray[2].IsEmpty() Then
			DocumentObjectPurchaseOrder = DocumentRefPurchaseOrder.GetObject()
		EndIf;
		
		// Negative balance of inventory and cost accounting.
		If Not ResultsArray[0].IsEmpty() Then
			QueryResultSelection = ResultsArray[0].Select();
			DriveServer.ShowMessageAboutPostingToInventoryRegisterErrors(DocumentObjectPurchaseOrder, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance on the order to the vendor.
		If Not ResultsArray[1].IsEmpty() Then
			QueryResultSelection = ResultsArray[1].Select();
			DriveServer.ShowMessageAboutPostingToPurchaseOrdersRegisterErrors(DocumentObjectPurchaseOrder, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance of need for inventory.
		If Not ResultsArray[2].IsEmpty() Then
			QueryResultSelection = ResultsArray[2].Select();
			DriveServer.ShowMessageAboutPostingToInventoryDemandRegisterErrors(DocumentObjectPurchaseOrder, QueryResultSelection, Cancel);
		EndIf;
		
	EndIf;
	
EndProcedure

// Checks the possibility of input on the basis.
//
Procedure CheckEnteringAbilityOnTheBasisOfVendorOrder(FillingData, AttributeValues) Export
	
	If AttributeValues.Property("Posted") Then
		If Not AttributeValues.Posted Then
			Raise NStr("en = 'Please select a posted document.'");
		EndIf;
	EndIf;
	
	If AttributeValues.Property("Closed") Then
		If AttributeValues.Closed Then
			Raise NStr("en = 'Please select an order that is not completed.'");
		EndIf;
	EndIf;
	
	If AttributeValues.Property("OrderState") Then
		If AttributeValues.OrderState.OrderStatus = Enums.OrderStatuses.Open Then
			Raise NStr("en = 'Generation from orders with ""Open"" status is not available.'");
		EndIf;
	EndIf;
	
	If AttributeValues.Property("GoodsIssue")
		AND AttributeValues.Property("OperationKind")
		AND AttributeValues.OperationKind <> Enums.OperationTypesPurchaseOrder.OrderForProcessing Then
			
			ErrorText = NStr("en = 'Cannot use %1 as a base document for Goods Issue. Please select a purchase order with ""Subcontractor order"" operation.'");
			Raise StringFunctionsClientServer.SubstituteParametersInString(
					ErrorText,
					FillingData);
	EndIf;
	
EndProcedure

#Region PrintInterface

// The procedure of document printing.
//
Function PrintForm(ObjectsArray, PrintObjects, TemplateName)
	
	If TemplateName = "PurchaseOrder" Then
		
		Return PrintPurchaseOrder(ObjectsArray, PrintObjects, TemplateName);
		
	ElsIf TemplateName = "PurchaseOrderInTermsOfSupplier" Then
		
		Return PrintPurchaseOrder(ObjectsArray, PrintObjects, TemplateName);
		
	EndIf;
	
EndFunction

// The procedure of document printing.
Function PrintPurchaseOrder(ObjectsArray, PrintObjects, TemplateName)
	
	SpreadsheetDocument = New SpreadsheetDocument;
	SpreadsheetDocument.PrintParametersKey = "PrintParameters_PurchaseOrder";
	
	Query = New Query();
	Query.SetParameter("ObjectsArray", ObjectsArray);
	
	#Region PrintPurchaseOrderQueryText
	
	If TemplateName = "PurchaseOrder" Then
		
		Query.Text = QueryText();
		
	ElsIf TemplateName = "PurchaseOrderInTermsOfSupplier" Then
		
		Query.Text = QueryTextInTermsOfSupplier();
		
	EndIf;
	
	#EndRegion
	
	ResultArray = Query.Execute();
	
	FirstDocument = True;
	
	Header = ResultArray.Select(QueryResultIteration.ByGroupsWithHierarchy);
	
	While Header.Next() Do
		
		If Not FirstDocument Then
			SpreadsheetDocument.PutHorizontalPageBreak();
		EndIf;
		FirstDocument = False;
		
		FirstLineNumber = SpreadsheetDocument.TableHeight + 1;
		
		Template = PrintManagement.PrintedFormsTemplate("Document.PurchaseOrder.PF_MXL_PurchaseOrderTemplate");
		
		#Region PrintPurchaseOrderTitleArea
		
		TitleArea = Template.GetArea("Title");
		TitleArea.Parameters.Fill(Header);
		InfoAboutCounterparty = DriveServer.InfoAboutLegalEntityIndividual(Header.Counterparty, Header.DocumentDate, ,);
		TitleArea.Parameters.FullDescr = InfoAboutCounterparty.FullDescr;
		
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
		
		#Region PrintPurchaseOrderWarehouseInfoArea
		
		WarehouseInfoArea = Template.GetArea("WarehouseInfo");
		WarehouseInfoArea.Parameters.Fill(InfoAboutCompany);
		
		InfoAboutWarehouse = DriveServer.InfoAboutLegalEntityIndividual(Header.Warehouse, Header.DocumentDate);
		WarehouseInfoArea.Parameters.WarehouseDescr = InfoAboutWarehouse.FullDescr;
		WarehouseInfoArea.Parameters.WarehouseAddress = InfoAboutWarehouse.DeliveryAddress;
		WarehouseInfoArea.Parameters.WarehousePhoneNumbers = InfoAboutWarehouse.PhoneNumbers;
		
		InfoAboutContactPerson = DriveServer.InfoAboutLegalEntityIndividual(InfoAboutWarehouse.ResponsibleEmployee, Header.DocumentDate);
		WarehouseInfoArea.Parameters.WarehouseContactPerson = InfoAboutContactPerson.FullDescr;
		WarehouseInfoArea.Parameters.ContactPhoneNumbers = InfoAboutContactPerson.PhoneNumbers;
		
		If IsBlankString(WarehouseInfoArea.Parameters.WarehouseAddress) Then
			If Not IsBlankString(InfoAboutCompany.ActualAddress) Then
				WarehouseInfoArea.Parameters.WarehouseAddress = InfoAboutCompany.ActualAddress;
			Else
				WarehouseInfoArea.Parameters.WarehouseAddress = InfoAboutCompany.LegalAddress;
			EndIf;
		EndIf;
		
		WarehouseInfoArea.Parameters.PaymentTerms = PaymentTermsServer.TitlePaymentTerms(Header.Ref);
		
		SpreadsheetDocument.Put(WarehouseInfoArea);
		
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
		
		LineTotalArea.Parameters.FreightTotal = 0;
		
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
		
		TabSelection = Header.Select();
		While TabSelection.Next() Do
			
			LineSectionArea.Parameters.Fill(TabSelection);
			
			AreasToBeChecked = New Array;
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

// The procedure of document printing.
Function QueryTextInTermsOfSupplier()
	
	QueryText = 
	"SELECT
	|	PurchaseOrder.Ref AS Ref,
	|	PurchaseOrder.Number AS Number,
	|	PurchaseOrder.Date AS Date,
	|	PurchaseOrder.Company AS Company,
	|	PurchaseOrder.Counterparty AS Counterparty,
	|	PurchaseOrder.Contract AS Contract,
	|	PurchaseOrder.AmountIncludesVAT AS AmountIncludesVAT,
	|	PurchaseOrder.DocumentCurrency AS DocumentCurrency,
	|	CAST(PurchaseOrder.Comment AS STRING(1024)) AS Comment,
	|	PurchaseOrder.Warehouse AS Warehouse
	|INTO PurchaseOrders
	|FROM
	|	Document.PurchaseOrder AS PurchaseOrder
	|WHERE
	|	PurchaseOrder.Ref IN(&ObjectsArray)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	PurchaseOrder.Ref AS Ref,
	|	PurchaseOrder.Number AS DocumentNumber,
	|	PurchaseOrder.Date AS DocumentDate,
	|	PurchaseOrder.Company AS Company,
	|	Companies.LogoFile AS CompanyLogoFile,
	|	PurchaseOrder.Counterparty AS Counterparty,
	|	PurchaseOrder.Contract AS Contract,
	|	CASE
	|		WHEN CounterpartyContracts.ContactPerson = VALUE(Catalog.ContactPersons.EmptyRef)
	|			THEN Counterparties.ContactPerson
	|		ELSE CounterpartyContracts.ContactPerson
	|	END AS CounterpartyContactPerson,
	|	PurchaseOrder.AmountIncludesVAT AS AmountIncludesVAT,
	|	PurchaseOrder.DocumentCurrency AS DocumentCurrency,
	|	PurchaseOrder.Comment AS Comment,
	|	PurchaseOrder.Warehouse AS Warehouse
	|INTO Header
	|FROM
	|	PurchaseOrders AS PurchaseOrder
	|		LEFT JOIN Catalog.Companies AS Companies
	|		ON PurchaseOrder.Company = Companies.Ref
	|		LEFT JOIN Catalog.Counterparties AS Counterparties
	|		ON PurchaseOrder.Counterparty = Counterparties.Ref
	|		LEFT JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
	|		ON PurchaseOrder.Contract = CounterpartyContracts.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	PurchaseOrderInventory.Ref AS Ref,
	|	PurchaseOrderInventory.LineNumber AS LineNumber,
	|	PurchaseOrderInventory.Products AS Products,
	|	PurchaseOrderInventory.Characteristic AS Characteristic,
	|	PurchaseOrderInventory.Quantity AS Quantity,
	|	PurchaseOrderInventory.MeasurementUnit AS MeasurementUnit,
	|	PurchaseOrderInventory.Price AS Price,
	|	PurchaseOrderInventory.Amount AS Amount,
	|	PurchaseOrderInventory.VATRate AS VATRate,
	|	PurchaseOrderInventory.VATAmount AS VATAmount,
	|	PurchaseOrderInventory.Total AS Total,
	|	PurchaseOrderInventory.Content AS Content,
	|	PurchaseOrderInventory.ReceiptDate AS ReceiptDate
	|INTO FilteredInventory
	|FROM
	|	Document.PurchaseOrder.Inventory AS PurchaseOrderInventory
	|WHERE
	|	PurchaseOrderInventory.Ref IN(&ObjectsArray)
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
	|	Header.Comment AS Comment,
	|	MIN(FilteredInventory.LineNumber) AS LineNumber,
	|	ISNULL(SuppliersProducts.SKU, CatalogProducts.SKU) AS SKU,
	|	CASE
	|		WHEN SuppliersProducts.Description IS NULL
	|			THEN CASE
	|					WHEN (CAST(FilteredInventory.Content AS STRING(1024))) <> """"
	|						THEN CAST(FilteredInventory.Content AS STRING(1024))
	|					WHEN (CAST(CatalogProducts.DescriptionFull AS STRING(1024))) <> """"
	|						THEN CAST(CatalogProducts.DescriptionFull AS STRING(1024))
	|					ELSE CatalogProducts.Description
	|				END
	|		ELSE SuppliersProducts.Description
	|	END AS ProductDescription,
	|	(CAST(FilteredInventory.Content AS STRING(1024))) <> """" AS ContentUsed,
	|	CASE
	|		WHEN CatalogProducts.UseCharacteristics
	|			THEN CatalogCharacteristics.Description
	|		ELSE """"
	|	END AS CharacteristicDescription,
	|	CatalogProducts.UseSerialNumbers AS UseSerialNumbers,
	|	ISNULL(CatalogUOM.Description, CatalogUOMClassifier.Description) AS UOM,
	|	SUM(FilteredInventory.Quantity) AS Quantity,
	|	FilteredInventory.Price AS Price,
	|	SUM(FilteredInventory.Amount) AS Amount,
	|	FilteredInventory.VATRate AS VATRate,
	|	SUM(FilteredInventory.VATAmount) AS VATAmount,
	|	SUM(FilteredInventory.Total) AS Total,
	|	SUM(CASE
	|			WHEN Header.AmountIncludesVAT
	|				THEN CAST(FilteredInventory.Amount - FilteredInventory.VATAmount AS NUMBER(15, 2))
	|			ELSE CAST(FilteredInventory.Amount AS NUMBER(15, 2))
	|		END) AS Subtotal,
	|	FilteredInventory.Products AS Products,
	|	FilteredInventory.Characteristic AS Characteristic,
	|	FilteredInventory.MeasurementUnit AS MeasurementUnit,
	|	Header.Warehouse AS Warehouse,
	|	FilteredInventory.ReceiptDate AS ReceiptDate
	|INTO Tabular
	|FROM
	|	Header AS Header
	|		INNER JOIN FilteredInventory AS FilteredInventory
	|		ON Header.Ref = FilteredInventory.Ref
	|		LEFT JOIN Catalog.Products AS CatalogProducts
	|		ON (FilteredInventory.Products = CatalogProducts.Ref)
	|		LEFT JOIN Catalog.ProductsCharacteristics AS CatalogCharacteristics
	|		ON (FilteredInventory.Characteristic = CatalogCharacteristics.Ref)
	|		LEFT JOIN Catalog.UOM AS CatalogUOM
	|		ON (FilteredInventory.MeasurementUnit = CatalogUOM.Ref)
	|		LEFT JOIN Catalog.UOMClassifier AS CatalogUOMClassifier
	|		ON (FilteredInventory.MeasurementUnit = CatalogUOMClassifier.Ref)
	|		LEFT JOIN Catalog.SuppliersProducts AS SuppliersProducts
	|		ON Header.Counterparty = SuppliersProducts.Owner
	|			AND (FilteredInventory.Products = SuppliersProducts.Products)
	|			AND (FilteredInventory.Characteristic = SuppliersProducts.Characteristic)
	|
	|GROUP BY
	|	FilteredInventory.VATRate,
	|	Header.Company,
	|	Header.Counterparty,
	|	Header.Contract,
	|	Header.CounterpartyContactPerson,
	|	Header.AmountIncludesVAT,
	|	Header.Comment,
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
	|	CatalogProducts.UseSerialNumbers,
	|	ISNULL(CatalogUOM.Description, CatalogUOMClassifier.Description),
	|	FilteredInventory.Products,
	|	FilteredInventory.Characteristic,
	|	FilteredInventory.MeasurementUnit,
	|	Header.Warehouse,
	|	FilteredInventory.ReceiptDate,
	|	CASE
	|		WHEN SuppliersProducts.Description IS NULL
	|			THEN CASE
	|					WHEN (CAST(FilteredInventory.Content AS STRING(1024))) <> """"
	|						THEN CAST(FilteredInventory.Content AS STRING(1024))
	|					WHEN (CAST(CatalogProducts.DescriptionFull AS STRING(1024))) <> """"
	|						THEN CAST(CatalogProducts.DescriptionFull AS STRING(1024))
	|					ELSE CatalogProducts.Description
	|				END
	|		ELSE SuppliersProducts.Description
	|	END,
	|	ISNULL(SuppliersProducts.SKU, CatalogProducts.SKU),
	|	FilteredInventory.Price
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
	|	Tabular.Comment AS Comment,
	|	Tabular.LineNumber AS LineNumber,
	|	Tabular.SKU AS SKU,
	|	Tabular.ProductDescription AS ProductDescription,
	|	Tabular.ContentUsed AS ContentUsed,
	|	Tabular.UseSerialNumbers AS UseSerialNumbers,
	|	Tabular.Quantity AS Quantity,
	|	Tabular.Price AS Price,
	|	Tabular.Amount AS Amount,
	|	Tabular.VATRate AS VATRate,
	|	Tabular.VATAmount AS VATAmount,
	|	Tabular.Total AS Total,
	|	Tabular.Subtotal AS Subtotal,
	|	CAST(Tabular.Quantity * Tabular.Price - Tabular.Amount AS NUMBER(15, 2)) AS DiscountAmount,
	|	Tabular.CharacteristicDescription AS CharacteristicDescription,
	|	Tabular.Characteristic AS Characteristic,
	|	Tabular.UOM AS UOM,
	|	Tabular.Warehouse AS Warehouse,
	|	Tabular.ReceiptDate AS ReceiptDate
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
	|	MAX(Comment),
	|	COUNT(LineNumber),
	|	SUM(Quantity),
	|	SUM(VATAmount),
	|	SUM(Total),
	|	SUM(Subtotal),
	|	SUM(DiscountAmount),
	|	MAX(Warehouse)
	|BY
	|	Ref";
	
	Return QueryText;
	
EndFunction

// The procedure of document printing.
Function QueryText()
	
	QueryText = 
	"SELECT
	|	PurchaseOrder.Ref AS Ref,
	|	PurchaseOrder.Number AS Number,
	|	PurchaseOrder.Date AS Date,
	|	PurchaseOrder.Company AS Company,
	|	PurchaseOrder.Counterparty AS Counterparty,
	|	PurchaseOrder.Contract AS Contract,
	|	PurchaseOrder.AmountIncludesVAT AS AmountIncludesVAT,
	|	PurchaseOrder.DocumentCurrency AS DocumentCurrency,
	|	CAST(PurchaseOrder.Comment AS STRING(1024)) AS Comment,
	|	PurchaseOrder.Warehouse AS Warehouse
	|INTO PurchaseOrders
	|FROM
	|	Document.PurchaseOrder AS PurchaseOrder
	|WHERE
	|	PurchaseOrder.Ref IN(&ObjectsArray)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	PurchaseOrder.Ref AS Ref,
	|	PurchaseOrder.Number AS DocumentNumber,
	|	PurchaseOrder.Date AS DocumentDate,
	|	PurchaseOrder.Company AS Company,
	|	Companies.LogoFile AS CompanyLogoFile,
	|	PurchaseOrder.Counterparty AS Counterparty,
	|	PurchaseOrder.Contract AS Contract,
	|	CASE
	|		WHEN CounterpartyContracts.ContactPerson = VALUE(Catalog.ContactPersons.EmptyRef)
	|			THEN Counterparties.ContactPerson
	|		ELSE CounterpartyContracts.ContactPerson
	|	END AS CounterpartyContactPerson,
	|	PurchaseOrder.AmountIncludesVAT AS AmountIncludesVAT,
	|	PurchaseOrder.DocumentCurrency AS DocumentCurrency,
	|	PurchaseOrder.Comment AS Comment,
	|	PurchaseOrder.Warehouse AS Warehouse
	|INTO Header
	|FROM
	|	PurchaseOrders AS PurchaseOrder
	|		LEFT JOIN Catalog.Companies AS Companies
	|		ON PurchaseOrder.Company = Companies.Ref
	|		LEFT JOIN Catalog.Counterparties AS Counterparties
	|		ON PurchaseOrder.Counterparty = Counterparties.Ref
	|		LEFT JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
	|		ON PurchaseOrder.Contract = CounterpartyContracts.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	PurchaseOrderInventory.Ref AS Ref,
	|	PurchaseOrderInventory.LineNumber AS LineNumber,
	|	PurchaseOrderInventory.Products AS Products,
	|	PurchaseOrderInventory.Characteristic AS Characteristic,
	|	PurchaseOrderInventory.Quantity AS Quantity,
	|	PurchaseOrderInventory.MeasurementUnit AS MeasurementUnit,
	|	PurchaseOrderInventory.Price AS Price,
	|	PurchaseOrderInventory.Amount AS Amount,
	|	PurchaseOrderInventory.VATRate AS VATRate,
	|	PurchaseOrderInventory.VATAmount AS VATAmount,
	|	PurchaseOrderInventory.Total AS Total,
	|	PurchaseOrderInventory.Content AS Content,
	|	PurchaseOrderInventory.ReceiptDate AS ReceiptDate
	|INTO FilteredInventory
	|FROM
	|	Document.PurchaseOrder.Inventory AS PurchaseOrderInventory
	|WHERE
	|	PurchaseOrderInventory.Ref IN(&ObjectsArray)
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
	|	CatalogProducts.UseSerialNumbers AS UseSerialNumbers,
	|	ISNULL(CatalogUOM.Description, CatalogUOMClassifier.Description) AS UOM,
	|	SUM(FilteredInventory.Quantity) AS Quantity,
	|	FilteredInventory.Price AS Price,
	|	SUM(FilteredInventory.Amount) AS Amount,
	|	FilteredInventory.VATRate AS VATRate,
	|	SUM(FilteredInventory.VATAmount) AS VATAmount,
	|	SUM(FilteredInventory.Total) AS Total,
	|	SUM(CASE
	|			WHEN Header.AmountIncludesVAT
	|				THEN CAST(FilteredInventory.Amount - FilteredInventory.VATAmount AS NUMBER(15, 2))
	|			ELSE CAST(FilteredInventory.Amount AS NUMBER(15, 2))
	|		END) AS Subtotal,
	|	FilteredInventory.Products AS Products,
	|	FilteredInventory.Characteristic AS Characteristic,
	|	FilteredInventory.MeasurementUnit AS MeasurementUnit,
	|	Header.Warehouse AS Warehouse,
	|	FilteredInventory.ReceiptDate AS ReceiptDate
	|INTO Tabular
	|FROM
	|	Header AS Header
	|		INNER JOIN FilteredInventory AS FilteredInventory
	|		ON Header.Ref = FilteredInventory.Ref
	|		LEFT JOIN Catalog.Products AS CatalogProducts
	|		ON (FilteredInventory.Products = CatalogProducts.Ref)
	|		LEFT JOIN Catalog.ProductsCharacteristics AS CatalogCharacteristics
	|		ON (FilteredInventory.Characteristic = CatalogCharacteristics.Ref)
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
	|	CatalogProducts.UseSerialNumbers,
	|	ISNULL(CatalogUOM.Description, CatalogUOMClassifier.Description),
	|	FilteredInventory.Products,
	|	FilteredInventory.Characteristic,
	|	FilteredInventory.MeasurementUnit,
	|	Header.Warehouse,
	|	FilteredInventory.ReceiptDate,
	|	FilteredInventory.Price
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
	|	Tabular.Comment AS Comment,
	|	Tabular.LineNumber AS LineNumber,
	|	Tabular.SKU AS SKU,
	|	Tabular.ProductDescription AS ProductDescription,
	|	Tabular.ContentUsed AS ContentUsed,
	|	Tabular.UseSerialNumbers AS UseSerialNumbers,
	|	Tabular.Quantity AS Quantity,
	|	Tabular.Price AS Price,
	|	Tabular.Amount AS Amount,
	|	Tabular.VATRate AS VATRate,
	|	Tabular.VATAmount AS VATAmount,
	|	Tabular.Total AS Total,
	|	Tabular.Subtotal AS Subtotal,
	|	CAST(Tabular.Quantity * Tabular.Price - Tabular.Amount AS NUMBER(15, 2)) AS DiscountAmount,
	|	Tabular.CharacteristicDescription AS CharacteristicDescription,
	|	Tabular.Characteristic AS Characteristic,
	|	Tabular.UOM AS UOM,
	|	Tabular.Warehouse AS Warehouse,
	|	Tabular.ReceiptDate AS ReceiptDate
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
	|	MAX(Comment),
	|	COUNT(LineNumber),
	|	SUM(Quantity),
	|	SUM(VATAmount),
	|	SUM(Total),
	|	SUM(Subtotal),
	|	SUM(DiscountAmount),
	|	MAX(Warehouse)
	|BY
	|	Ref";;
	
	Return QueryText;
	
EndFunction

// Generate printed forms of objects
//
// Incoming:
//   TemplateNames    - String    - Names of layouts separated
//   by commas ObjectsArray  - Array    - Array of refs to objects that
//   need to be printed PrintParameters - Structure - Structure of additional printing parameters
//
// Outgoing:
//   PrintFormsCollection - Values table - Generated
//   table documents OutputParameters       - Structure        - Parameters of generated table documents
//
Procedure Print(ObjectsArray, PrintParameters, PrintFormsCollection, PrintObjects, OutputParameters) Export
	
	If PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "PurchaseOrderTemplate") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection, "PurchaseOrderTemplate", 
		NStr("en = 'Purchase order'"), PrintForm(ObjectsArray, PrintObjects, "PurchaseOrder"));
		
	ElsIf PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "PurchaseOrderInTermsOfSupplier") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection, "PurchaseOrderInTermsOfSupplier", 
		NStr("en = 'Purchase order in terms of supplier'"), PrintForm(ObjectsArray, PrintObjects, "PurchaseOrderInTermsOfSupplier"));
		
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
	PrintCommand.ID = "PurchaseOrderTemplate";
	PrintCommand.Presentation = NStr("en = 'Purchase order'");
	PrintCommand.FormsList = "DocumentForm,ListForm,DocumentsListForm";
	PrintCommand.CheckPostingBeforePrint = False;
	PrintCommand.Order = 1;
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID = "PurchaseOrderInTermsOfSupplier";
	PrintCommand.Presentation = NStr("en = 'Purchase order in terms of supplier'");
	PrintCommand.FormsList = "DocumentForm,ListForm,DocumentsListForm";
	PrintCommand.CheckPostingBeforePrint = False;
	PrintCommand.Order = 2;  
	
EndProcedure

#EndRegion

#EndIf
