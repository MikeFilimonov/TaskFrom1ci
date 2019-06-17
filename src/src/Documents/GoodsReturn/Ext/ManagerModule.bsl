#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableSales(DocumentRefGoodsReturn, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	TableSales.Period AS Period,
	|	TableSales.Recorder AS Recorder,
	|	TableSales.Product AS Products,
	|	TableSales.Characteristic AS Characteristic,
	|	TableSales.Batch AS Batch,
	|	CASE
	|		WHEN VALUETYPE(TableSales.SalesDocument) = TYPE(Document.SalesSlip)
	|				AND TableSales.Archival
	|			THEN TableSales.ShiftClosure
	|		ELSE TableSales.SalesDocument
	|	END AS Document,
	|	TableSales.Company AS Company,
	|	CASE
	|		WHEN TableSales.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|				AND TableSales.Order <> VALUE(Document.WorkOrder.EmptyRef)
	|			THEN TableSales.Order
	|		ELSE UNDEFINED
	|	END AS SalesOrder,
	|	TableSales.Department AS Department,
	|	TableSales.VATRate AS VATRate,
	|	-TableSales.CostOfGoodsSold AS Cost,
	|	TableSales.Responsible AS Responsible,
	|	TableSales.SalesRep AS SalesRep,
	|	FALSE AS OfflineRecord
	|FROM
	|	TemporaryTableProducts AS TableSales
	|
	|UNION ALL
	|
	|SELECT
	|	OfflineRecords.Period,
	|	OfflineRecords.Recorder,
	|	OfflineRecords.Products,
	|	OfflineRecords.Characteristic,
	|	OfflineRecords.Batch,
	|	OfflineRecords.Document,
	|	OfflineRecords.Company,
	|	OfflineRecords.SalesOrder,
	|	OfflineRecords.Department,
	|	OfflineRecords.VATRate,
	|	OfflineRecords.Cost,
	|	OfflineRecords.Responsible,
	|	OfflineRecords.SalesRep,
	|	OfflineRecords.OfflineRecord
	|FROM
	|	AccumulationRegister.Sales AS OfflineRecords
	|WHERE
	|	OfflineRecords.Recorder = &Ref
	|	AND OfflineRecords.OfflineRecord";
	
	Query.SetParameter("Ref", DocumentRefGoodsReturn);
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSales", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventoryInWarehouses(DocumentRefGoodsReturn, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	TableInventoryInWarehouses.Period AS Period,
	|	TableInventoryInWarehouses.Recorder AS Recorder,
	|	CASE
	|		WHEN TableInventoryInWarehouses.Operationkind = VALUE(Enum.OperationTypesGoodsReturn.FromCustomer)
	|			THEN VALUE(AccumulationRecordType.Receipt)
	|		WHEN TableInventoryInWarehouses.OperationKind = VALUE(Enum.OperationTypesGoodsReturn.ToSupplier)
	|			THEN VALUE(AccumulationRecordType.Expense)
	|	END AS RecordType,
	|	TableInventoryInWarehouses.Company AS Company,
	|	TableInventoryInWarehouses.StructuralUnit AS StructuralUnit,
	|	TableInventoryInWarehouses.Product AS Products,
	|	TableInventoryInWarehouses.Characteristic AS Characteristic,
	|	TableInventoryInWarehouses.Batch AS Batch,
	|	TableInventoryInWarehouses.Cell AS Cell,
	|	TableInventoryInWarehouses.ReturnQuantity AS Quantity
	|FROM
	|	TemporaryTableProducts AS TableInventoryInWarehouses";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryInWarehouses", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventory(DocumentRefGoodsReturn, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	TableInventory.Period AS Period,
	|	TableInventory.Recorder AS Recorder,
	|	CASE
	|		WHEN TableInventory.OperationKind = VALUE(Enum.OperationTypesGoodsReturn.FromCustomer)
	|			THEN VALUE(AccumulationRecordType.Receipt)
	|		WHEN TableInventory.OperationKind = VALUE(Enum.OperationTypesGoodsReturn.ToSupplier)
	|			THEN VALUE(AccumulationRecordType.Expense)
	|	END AS RecordType,
	|	TableInventory.Company AS Company,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	TableInventory.Product AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.Product.InventoryGLAccount AS GLAccount,
	|	TableInventory.ReturnQuantity AS Quantity,
	|	CASE
	|		WHEN NOT &FillAmount
	|			THEN 0
	|		WHEN TableInventory.OperationKind = VALUE(Enum.OperationTypesGoodsReturn.FromCustomer)
	|			THEN TableInventory.CostOfGoodsSold
	|		WHEN TableInventory.OperationKind = VALUE(Enum.OperationTypesGoodsReturn.ToSupplier)
	|			THEN TableInventory.AdjustmentAmount
	|	END AS Amount,
	|	&Content AS ContentOfAccountingRecord,
	|	CASE
	|		WHEN TableInventory.Order = VALUE(Document.SalesOrder.EmptyRef)
	|				OR TableInventory.Order = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE TableInventory.Order
	|	END AS CorrSalesOrder,
	|	CASE
	|		WHEN TableInventory.OperationKind = VALUE(Enum.OperationTypesGoodsReturn.ToSupplier)
	|			THEN TableInventory.SupplierInvoice
	|		WHEN VALUETYPE(TableInventory.SalesDocument) = TYPE(Document.SalesSlip)
	|			THEN TableInventory.ShiftClosure
	|		ELSE TableInventory.SalesDocument
	|	END AS SourceDocument,
	|	TableInventory.Department AS Department,
	|	TableInventory.Responsible AS Responsible,
	|	TableInventory.VATRate AS VATRate,
	|	TRUE AS Return,
	|	FALSE AS OfflineRecord
	|FROM
	|	TemporaryTableProducts AS TableInventory
	|
	|UNION ALL
	|
	|SELECT
	|	OfflineRecords.Period,
	|	OfflineRecords.Recorder,
	|	OfflineRecords.RecordType,
	|	OfflineRecords.Company,
	|	OfflineRecords.StructuralUnit,
	|	OfflineRecords.Products,
	|	OfflineRecords.Characteristic,
	|	OfflineRecords.Batch,
	|	OfflineRecords.GLAccount,
	|	OfflineRecords.Quantity,
	|	OfflineRecords.Amount,
	|	OfflineRecords.ContentOfAccountingRecord,
	|	OfflineRecords.CorrSalesOrder,
	|	OfflineRecords.SourceDocument,
	|	OfflineRecords.Department,
	|	OfflineRecords.Responsible,
	|	OfflineRecords.VATRate,
	|	OfflineRecords.Return,
	|	OfflineRecords.OfflineRecord
	|FROM
	|	AccumulationRegister.Inventory AS OfflineRecords
	|WHERE
	|	OfflineRecords.Recorder = &Ref
	|	AND OfflineRecords.OfflineRecord";
	
	Query.SetParameter("Content", NStr("en = 'Goods return'", CommonUseClientServer.MainLanguageCode()));
	Query.SetParameter("FillAmount", StructureAdditionalProperties.AccountingPolicy.InventoryValuationMethod = Enums.InventoryValuationMethods.WeightedAverage);
	Query.SetParameter("Ref", DocumentRefGoodsReturn);
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventory", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableIncomeAndExpenses(DocumentRefGoodsReturn, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	TableIncomeAndExpenses.Period AS Period,
	|	TableIncomeAndExpenses.Recorder AS Recorder,
	|	TableIncomeAndExpenses.Company AS Company,
	|	TableIncomeAndExpenses.SalesInvoiceStructuralUnit AS StructuralUnit,
	|	TableIncomeAndExpenses.BusinessLine AS BusinessLine,
	|	TableIncomeAndExpenses.BusinessLine.GLAccountCostOfSales AS GLAccount,
	|	TableIncomeAndExpenses.Order AS SalesOrder,
	|	CASE
	|		WHEN TableIncomeAndExpenses.Recorder.OperationKind = VALUE(Enum.OperationTypesGoodsReturn.FromCustomer)
	|			THEN 0
	|		WHEN TableIncomeAndExpenses.Recorder.OperationKind = VALUE(Enum.OperationTypesGoodsReturn.ToSupplier)
	|			THEN TableIncomeAndExpenses.AdjustmentAmount
	|	END AS AmountIncome,
	|	CASE
	|		WHEN TableIncomeAndExpenses.Recorder.OperationKind = VALUE(Enum.OperationTypesGoodsReturn.FromCustomer)
	|			THEN -TableIncomeAndExpenses.CostOfGoodsSold
	|		WHEN TableIncomeAndExpenses.Recorder.OperationKind = VALUE(Enum.OperationTypesGoodsReturn.ToSupplier)
	|			THEN 0
	|	END AS AmountExpense,
	|	&Content AS ContentOfAccountingRecord
	|INTO TableIncomeAndExpenses
	|FROM
	|	TemporaryTableProducts AS TableIncomeAndExpenses
	|WHERE
	|	CASE
	|			WHEN TableIncomeAndExpenses.Recorder.OperationKind = VALUE(Enum.OperationTypesGoodsReturn.FromCustomer)
	|				THEN TableIncomeAndExpenses.CostOfGoodsSold <> 0
	|		END
	|
	|UNION ALL
	|
	|SELECT
	|	TableIncomeAndExpenses.Period,
	|	TableIncomeAndExpenses.Recorder,
	|	TableIncomeAndExpenses.Company,
	|	TableIncomeAndExpenses.StructuralUnit,
	|	TableIncomeAndExpenses.BusinessLine,
	|	TableIncomeAndExpenses.GLAccount,
	|	TableIncomeAndExpenses.Order,
	|	0,
	|	CASE
	|		WHEN TableIncomeAndExpenses.Recorder.OperationKind = VALUE(Enum.OperationTypesGoodsReturn.FromCustomer)
	|			THEN -TableIncomeAndExpenses.CostOfGoodsSold
	|		WHEN TableIncomeAndExpenses.Recorder.OperationKind = VALUE(Enum.OperationTypesGoodsReturn.ToSupplier)
	|			THEN TableIncomeAndExpenses.AdjustmentAmount
	|	END,
	|	&Content
	|FROM
	|	TemporaryTableProducts AS TableIncomeAndExpenses
	|WHERE
	|	TableIncomeAndExpenses.Recorder.OperationKind = VALUE(Enum.OperationTypesGoodsReturn.ToSupplier)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableIncomeAndExpenses.Period AS Period,
	|	TableIncomeAndExpenses.Recorder AS Recorder,
	|	TableIncomeAndExpenses.Company AS Company,
	|	TableIncomeAndExpenses.StructuralUnit AS StructuralUnit,
	|	TableIncomeAndExpenses.BusinessLine AS BusinessLine,
	|	TableIncomeAndExpenses.GLAccount AS GLAccount,
	|	CASE
	|		WHEN TableIncomeAndExpenses.SalesOrder = VALUE(Document.SalesOrder.EmptyRef)
	|				OR TableIncomeAndExpenses.SalesOrder = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE TableIncomeAndExpenses.SalesOrder
	|	END AS SalesOrder,
	|	SUM(TableIncomeAndExpenses.AmountIncome) AS AmountIncome,
	|	SUM(TableIncomeAndExpenses.AmountExpense) AS AmountExpense,
	|	TableIncomeAndExpenses.ContentOfAccountingRecord AS ContentOfAccountingRecord,
	|	FALSE AS OfflineRecord
	|FROM
	|	TableIncomeAndExpenses AS TableIncomeAndExpenses
	|
	|GROUP BY
	|	TableIncomeAndExpenses.Recorder,
	|	TableIncomeAndExpenses.Period,
	|	TableIncomeAndExpenses.Company,
	|	TableIncomeAndExpenses.StructuralUnit,
	|	TableIncomeAndExpenses.SalesOrder,
	|	TableIncomeAndExpenses.BusinessLine,
	|	TableIncomeAndExpenses.ContentOfAccountingRecord,
	|	TableIncomeAndExpenses.GLAccount
	|
	|UNION ALL
	|
	|SELECT
	|	OfflineRecords.Period,
	|	OfflineRecords.Recorder,
	|	OfflineRecords.Company,
	|	OfflineRecords.StructuralUnit,
	|	OfflineRecords.BusinessLine,
	|	OfflineRecords.GLAccount,
	|	OfflineRecords.SalesOrder,
	|	OfflineRecords.AmountIncome,
	|	OfflineRecords.AmountExpense,
	|	OfflineRecords.ContentOfAccountingRecord,
	|	OfflineRecords.OfflineRecord
	|FROM
	|	AccumulationRegister.IncomeAndExpenses AS OfflineRecords
	|WHERE
	|	OfflineRecords.Recorder = &Ref
	|	AND OfflineRecords.OfflineRecord";
	
	Query.SetParameter("Content", NStr("en = 'Goods return'", CommonUseClientServer.MainLanguageCode()));
	Query.SetParameter("Ref", DocumentRefGoodsReturn);
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpenses", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableAccountingJournalEntries(DocumentRefGoodsReturn, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	If DocumentRefGoodsReturn.OperationKind = Enums.OperationTypesGoodsReturn.FromCustomer Then
		
		Query.Text =
		"SELECT
		|	TableAccountingJournalEntries.Period AS Period,
		|	TableAccountingJournalEntries.Recorder AS Recorder,
		|	TableAccountingJournalEntries.Company AS Company,
		|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
		|	TableAccountingJournalEntries.InventoryGLAccount AS AccountDr,
		|	CASE
		|		WHEN TableAccountingJournalEntries.InventoryGLAccount.Currency
		|			THEN TableAccountingJournalEntries.SettlementsCurrency
		|		ELSE UNDEFINED
		|	END AS CurrencyDr,
		|	SUM(CASE
		|			WHEN TableAccountingJournalEntries.InventoryGLAccount.Currency
		|				THEN TableAccountingJournalEntries.AmountCur
		|			ELSE 0
		|		END) AS AmountCurDr,
		|	TableAccountingJournalEntries.GLAccountCostOfSales AS AccountCr,
		|	CASE
		|		WHEN TableAccountingJournalEntries.GLAccountCostOfSales.Currency
		|			THEN TableAccountingJournalEntries.SettlementsCurrency
		|		ELSE UNDEFINED
		|	END AS CurrencyCr,
		|	SUM(CASE
		|			WHEN TableAccountingJournalEntries.GLAccountCostOfSales.Currency
		|				THEN TableAccountingJournalEntries.AmountCur
		|			ELSE 0
		|		END) AS AmountCurCr,
		|	SUM(TableAccountingJournalEntries.CostOfGoodsSold) AS Amount,
		|	&Content AS Content,
		|	FALSE AS OfflineRecord
		|FROM
		|	TemporaryTableProducts AS TableAccountingJournalEntries
		|
		|GROUP BY
		|	TableAccountingJournalEntries.GLAccountCostOfSales,
		|	TableAccountingJournalEntries.Recorder,
		|	TableAccountingJournalEntries.Company,
		|	TableAccountingJournalEntries.Period,
		|	CASE
		|		WHEN TableAccountingJournalEntries.InventoryGLAccount.Currency
		|			THEN TableAccountingJournalEntries.SettlementsCurrency
		|		ELSE UNDEFINED
		|	END,
		|	CASE
		|		WHEN TableAccountingJournalEntries.GLAccountCostOfSales.Currency
		|			THEN TableAccountingJournalEntries.SettlementsCurrency
		|		ELSE UNDEFINED
		|	END,
		|	TableAccountingJournalEntries.InventoryGLAccount
		|
		|UNION ALL
		|
		|SELECT
		|	OfflineRecords.Period,
		|	OfflineRecords.Recorder,
		|	OfflineRecords.Company,
		|	OfflineRecords.PlanningPeriod,
		|	OfflineRecords.AccountDr,
		|	OfflineRecords.CurrencyDr,
		|	OfflineRecords.AmountCurDr,
		|	OfflineRecords.AccountCr,
		|	OfflineRecords.CurrencyCr,
		|	OfflineRecords.AmountCurCr,
		|	OfflineRecords.Amount,
		|	OfflineRecords.Content,
		|	OfflineRecords.OfflineRecord
		|FROM
		|	AccountingRegister.AccountingJournalEntries AS OfflineRecords
		|WHERE
		|	OfflineRecords.Recorder = &Ref
		|	AND OfflineRecords.OfflineRecord";
		
	ElsIf DocumentRefGoodsReturn.OperationKind = Enums.OperationTypesGoodsReturn.ToSupplier Then
		
		Query.Text =
		"SELECT
		|	TableAccountingJournalEntries.Period AS Period,
		|	TableAccountingJournalEntries.Recorder AS Recorder,
		|	TableAccountingJournalEntries.Company AS Company,
		|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
		|	TableAccountingJournalEntries.GLAccount AS AccountDr,
		|	CASE
		|		WHEN TableAccountingJournalEntries.GLAccount.Currency
		|			THEN TableAccountingJournalEntries.SettlementsCurrency
		|		ELSE UNDEFINED
		|	END AS CurrencyDr,
		|	SUM(CASE
		|			WHEN TableAccountingJournalEntries.GLAccount.Currency
		|				THEN TableAccountingJournalEntries.AmountCur
		|			ELSE 0
		|		END) AS AmountCurDr,
		|	TableAccountingJournalEntries.InventoryGLAccount AS AccountCr,
		|	CASE
		|		WHEN TableAccountingJournalEntries.InventoryGLAccount.Currency
		|			THEN TableAccountingJournalEntries.SettlementsCurrency
		|		ELSE UNDEFINED
		|	END AS CurrencyCr,
		|	SUM(CASE
		|			WHEN TableAccountingJournalEntries.InventoryGLAccount.Currency
		|				THEN TableAccountingJournalEntries.AmountCur
		|			ELSE 0
		|		END) AS AmountCurCr,
		|	SUM(TableAccountingJournalEntries.AdjustmentAmount) AS Amount,
		|	&Content AS Content,
		|	FALSE AS OfflineRecord
		|FROM
		|	TemporaryTableProducts AS TableAccountingJournalEntries
		|
		|GROUP BY
		|	TableAccountingJournalEntries.GLAccount,
		|	TableAccountingJournalEntries.Recorder,
		|	TableAccountingJournalEntries.Company,
		|	TableAccountingJournalEntries.Period,
		|	CASE
		|		WHEN TableAccountingJournalEntries.InventoryGLAccount.Currency
		|			THEN TableAccountingJournalEntries.SettlementsCurrency
		|		ELSE UNDEFINED
		|	END,
		|	CASE
		|		WHEN TableAccountingJournalEntries.GLAccount.Currency
		|			THEN TableAccountingJournalEntries.SettlementsCurrency
		|		ELSE UNDEFINED
		|	END,
		|	TableAccountingJournalEntries.InventoryGLAccount";
		
	EndIf;
	
	Query.SetParameter("Content", NStr("en = 'Goods return'", CommonUseClientServer.MainLanguageCode()));
	Query.SetParameter("Ref", DocumentRefGoodsReturn);
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountingJournalEntries", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableSerialNumbers(DocumentRefGoodsReturn, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	TableSerialNumbersBalance.Period AS Period,
	|	CASE
	|		WHEN TableSerialNumbersBalance.OperationKind = VALUE(Enum.OperationTypesGoodsReturn.FromCustomer)
	|			THEN VALUE(AccumulationRecordType.Receipt)
	|		WHEN TableSerialNumbersBalance.OperationKind = VALUE(Enum.OperationTypesGoodsReturn.ToSupplier)
	|			THEN VALUE(AccumulationRecordType.Expense)
	|	END AS RecordType,
	|	TableSerialNumbersBalance.Period AS EventDate,
	|	TableSerialNumbersBalance.Company AS Company,
	|	CASE
	|		WHEN TableSerialNumbersBalance.OperationKind = VALUE(Enum.OperationTypesGoodsReturn.FromCustomer)
	|			THEN VALUE(Enum.SerialNumbersOperations.Receipt)
	|		WHEN TableSerialNumbersBalance.OperationKind = VALUE(Enum.OperationTypesGoodsReturn.ToSupplier)
	|			THEN VALUE(Enum.SerialNumbersOperations.Expense)
	|	END AS Operation,
	|	TableSerialNumbersBalance.StructuralUnit AS StructuralUnit,
	|	TableSerialNumbersBalance.Product AS Products,
	|	TableSerialNumbersBalance.Characteristic AS Characteristic,
	|	TableSerialNumbersBalance.Batch AS Batch,
	|	TableSerialNumbersBalance.Cell AS Cell,
	|	GoodsReturnSerialNumbers.SerialNumber AS SerialNumber,
	|	1 AS Quantity
	|FROM
	|	TemporaryTableProducts AS TableSerialNumbersBalance
	|		INNER JOIN Document.GoodsReturn.SerialNumbers AS GoodsReturnSerialNumbers
	|		ON TableSerialNumbersBalance.Recorder = GoodsReturnSerialNumbers.Ref
	|			AND TableSerialNumbersBalance.ConnectionKey = GoodsReturnSerialNumbers.ConnectionKey
	|WHERE
	|	GoodsReturnSerialNumbers.Ref = &Ref
	|	AND &UseSerialNumbers
	|
	|GROUP BY
	|	TableSerialNumbersBalance.StructuralUnit,
	|	TableSerialNumbersBalance.OperationKind,
	|	TableSerialNumbersBalance.Period,
	|	TableSerialNumbersBalance.Company,
	|	TableSerialNumbersBalance.Product,
	|	TableSerialNumbersBalance.Characteristic,
	|	TableSerialNumbersBalance.Batch,
	|	TableSerialNumbersBalance.Cell,
	|	GoodsReturnSerialNumbers.SerialNumber,
	|	TableSerialNumbersBalance.Period";
	
	Query.SetParameter("Ref", 				DocumentRefGoodsReturn);
	Query.SetParameter("UseSerialNumbers",	GetFunctionalOption("UseSerialNumbers"));
	
	QueryResult = Query.Execute();
	
	ResultTable = QueryResult.Unload();
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbersInWarranty", ResultTable);
	
	If StructureAdditionalProperties.AccountingPolicy.SerialNumbersBalance Then
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbersBalance", ResultTable);
	Else
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbersBalance", New ValueTable);
	EndIf; 
	
EndProcedure

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefGoodsReturn, StructureAdditionalProperties) Export

	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	ExchangeRatesSliceLast.Currency AS Currency,
	|	ExchangeRatesSliceLast.ExchangeRate AS ExchangeRate,
	|	ExchangeRatesSliceLast.Multiplicity AS Multiplicity
	|INTO TemporaryTableExchangeRatesSliceLatest
	|FROM
	|	InformationRegister.ExchangeRates.SliceLast(&PointInTime, Currency IN (&PresentationCurrency, &CurrencyNational, &DocumentCurrency)) AS ExchangeRatesSliceLast
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	GoodsReturn.Ref AS Ref,
	|	GoodsReturn.Cell AS Cell,
	|	GoodsReturn.Contract AS Contract,
	|	GoodsReturn.Department AS Department,
	|	GoodsReturn.StructuralUnit AS StructuralUnit,
	|	GoodsReturn.OperationKind AS OperationKind,
	|	GoodsReturn.Date AS Date,
	|	GoodsReturn.DocumentCurrency AS DocumentCurrency,
	|	GoodsReturn.ExchangeRate AS ExchangeRate,
	|	GoodsReturn.GLAccount AS GLAccount,
	|	GoodsReturn.Multiplicity AS Multiplicity,
	|	GoodsReturn.Responsible AS Responsible,
	|	GoodsReturn.SalesDocument AS SalesDocument,
	|	GoodsReturn.SupplierInvoice AS SupplierInvoice
	|INTO GoodsReturnHeader
	|FROM
	|	Document.GoodsReturn AS GoodsReturn
	|WHERE
	|	GoodsReturn.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	GoodsReturnProducts.Ref AS Ref,
	|	GoodsReturnProducts.Batch AS Batch,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN GoodsReturnProducts.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	GoodsReturnProducts.VATRate AS VATRate,
	|	GoodsReturnProducts.Products AS Products,
	|	GoodsReturnProducts.CostOfGoodsSold AS CostOfGoodsSold,
	|	GoodsReturnProducts.ConnectionKey AS ConnectionKey,
	|	GoodsReturnProducts.InitialQuantity AS InitialQuantity,
	|	GoodsReturnProducts.Quantity AS Quantity,
	|	GoodsReturnProducts.MeasurementUnit AS MeasurementUnit,
	|	GoodsReturnProducts.Amount AS Amount,
	|	GoodsReturnProducts.InitialAmount AS InitialAmount,
	|	GoodsReturnProducts.Order AS Order,
	|	GoodsReturnHeader.Cell AS Cell,
	|	GoodsReturnHeader.Contract AS Contract,
	|	GoodsReturnHeader.Department AS Department,
	|	GoodsReturnHeader.StructuralUnit AS StructuralUnit,
	|	GoodsReturnHeader.OperationKind AS OperationKind,
	|	GoodsReturnHeader.Date AS Date,
	|	GoodsReturnHeader.DocumentCurrency AS DocumentCurrency,
	|	GoodsReturnHeader.ExchangeRate AS ExchangeRate,
	|	GoodsReturnHeader.Multiplicity AS Multiplicity,
	|	GoodsReturnHeader.GLAccount AS GLAccount,
	|	GoodsReturnHeader.Responsible AS Responsible,
	|	GoodsReturnHeader.SalesDocument AS SalesDocument,
	|	GoodsReturnHeader.SupplierInvoice AS SupplierInvoice,
	|	GoodsReturnProducts.SalesRep AS SalesRep
	|INTO TabProducts
	|FROM
	|	GoodsReturnHeader AS GoodsReturnHeader
	|		INNER JOIN Document.GoodsReturn.Inventory AS GoodsReturnProducts
	|		ON GoodsReturnHeader.Ref = GoodsReturnProducts.Ref
	|			AND (GoodsReturnProducts.Amount <> 0)
	|
	|GROUP BY
	|	GoodsReturnProducts.Batch,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN GoodsReturnProducts.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END,
	|	GoodsReturnProducts.VATRate,
	|	GoodsReturnProducts.Ref,
	|	GoodsReturnProducts.Products,
	|	GoodsReturnProducts.ConnectionKey,
	|	GoodsReturnProducts.CostOfGoodsSold,
	|	GoodsReturnProducts.InitialQuantity,
	|	GoodsReturnProducts.Quantity,
	|	GoodsReturnProducts.MeasurementUnit,
	|	GoodsReturnProducts.Amount,
	|	GoodsReturnProducts.InitialAmount,
	|	GoodsReturnProducts.Order,
	|	GoodsReturnHeader.Cell,
	|	GoodsReturnHeader.Contract,
	|	GoodsReturnHeader.Department,
	|	GoodsReturnHeader.StructuralUnit,
	|	GoodsReturnHeader.OperationKind,
	|	GoodsReturnHeader.Date,
	|	GoodsReturnHeader.DocumentCurrency,
	|	GoodsReturnHeader.ExchangeRate,
	|	GoodsReturnHeader.Multiplicity,
	|	GoodsReturnHeader.GLAccount,
	|	GoodsReturnHeader.Responsible,
	|	GoodsReturnHeader.SalesDocument,
	|	GoodsReturnHeader.SupplierInvoice,
	|	GoodsReturnProducts.SalesRep
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TabProducts.Ref AS Recorder,
	|	SUM(CAST(CASE
	|				WHEN TabProducts.DocumentCurrency = &CurrencyNational
	|					THEN CASE
	|							WHEN TabProducts.InitialQuantity = 0
	|								THEN 0
	|							ELSE TabProducts.InitialAmount / TabProducts.InitialQuantity
	|						END * TabProducts.Quantity * RegExchangeRates.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * RegExchangeRates.Multiplicity)
	|				ELSE TabProducts.InitialAmount * TabProducts.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * TabProducts.Multiplicity)
	|			END AS NUMBER(15, 2))) AS Amount,
	|	TabProducts.Batch AS Batch,
	|	TabProducts.Characteristic AS Characteristic,
	|	SUM(TabProducts.InitialQuantity * ISNULL(UOM.Factor, 1)) AS Quantity,
	|	SUM(TabProducts.Quantity * ISNULL(UOM.Factor, 1)) AS ReturnQuantity,
	|	TabProducts.Date AS Period,
	|	TabProducts.VATRate AS VATRate,
	|	&Company AS Company,
	|	SUM(CAST(CASE
	|				WHEN TabProducts.DocumentCurrency = &CurrencyNational
	|					THEN TabProducts.Amount * RegExchangeRates.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * RegExchangeRates.Multiplicity)
	|				ELSE TabProducts.Amount * TabProducts.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * TabProducts.Multiplicity)
	|			END AS NUMBER(15, 2))) AS AdjustmentAmount,
	|	LinesOfBusiness.Ref AS BusinessLine,
	|	TabProducts.OperationKind AS OperationKind,
	|	TabProducts.Department AS Department,
	|	TabProducts.Responsible AS Responsible,
	|	TabProducts.StructuralUnit AS StructuralUnit,
	|	SUM(CAST(CASE
	|				WHEN TabProducts.DocumentCurrency = &CurrencyNational
	|					THEN TabProducts.Amount * RegExchangeRates.ExchangeRate * TabProducts.Multiplicity / (TabProducts.ExchangeRate * RegExchangeRates.Multiplicity)
	|				ELSE TabProducts.Amount
	|			END AS NUMBER(15, 2))) AS AmountCur,
	|	TabProducts.Products AS Product,
	|	TabProducts.SalesDocument AS SalesDocument,
	|	TabProducts.SupplierInvoice AS SupplierInvoice,
	|	TabProducts.CostOfGoodsSold AS CostOfGoodsSold,
	|	TabProducts.Order AS Order,
	|	CounterpartyContracts.SettlementsCurrency AS SettlementsCurrency,
	|	TabProducts.Cell AS Cell,
	|	SalesInvoice.StructuralUnit AS SalesInvoiceStructuralUnit,
	|	TabProducts.GLAccount AS GLAccount,
	|	TabProducts.ConnectionKey AS ConnectionKey,
	|	TabProducts.Products.InventoryGLAccount AS InventoryGLAccount,
	|	LinesOfBusiness.GLAccountCostOfSales AS GLAccountCostOfSales,
	|	ISNULL(SalesSlip.CashCRSession, VALUE(Document.ShiftClosure.EmptyRef)) AS ShiftClosure,
	|	SalesSlip.Archival AS Archival,
	|	TabProducts.SalesRep AS SalesRep
	|INTO TemporaryTableProducts
	|FROM
	|	TabProducts AS TabProducts
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS ManagExchangeRates
	|		ON (ManagExchangeRates.Currency = &CurrencyNational)
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS RegExchangeRates
	|		ON (RegExchangeRates.Currency = &PresentationCurrency)
	|		LEFT JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
	|		ON TabProducts.Contract = CounterpartyContracts.Ref
	|		LEFT JOIN Catalog.LinesOfBusiness AS LinesOfBusiness
	|		ON TabProducts.Products.BusinessLine = LinesOfBusiness.Ref
	|		LEFT JOIN Document.SalesInvoice AS SalesInvoice
	|		ON TabProducts.SalesDocument = SalesInvoice.Ref
	|		LEFT JOIN Catalog.UOM AS UOM
	|		ON TabProducts.MeasurementUnit = UOM.Ref
	|		LEFT JOIN Document.SalesSlip AS SalesSlip
	|		ON TabProducts.SalesDocument = SalesSlip.Ref
	|
	|GROUP BY
	|	TabProducts.Batch,
	|	TabProducts.VATRate,
	|	TabProducts.Ref,
	|	TabProducts.Date,
	|	TabProducts.OperationKind,
	|	TabProducts.Department,
	|	TabProducts.Responsible,
	|	TabProducts.StructuralUnit,
	|	TabProducts.Products,
	|	TabProducts.SalesDocument,
	|	TabProducts.SupplierInvoice,
	|	TabProducts.Cell,
	|	TabProducts.GLAccount,
	|	TabProducts.ConnectionKey,
	|	TabProducts.CostOfGoodsSold,
	|	CounterpartyContracts.SettlementsCurrency,
	|	SalesInvoice.StructuralUnit,
	|	TabProducts.Characteristic,
	|	LinesOfBusiness.Ref,
	|	TabProducts.Products.InventoryGLAccount,
	|	LinesOfBusiness.GLAccountCostOfSales,
	|	CAST(CASE
	|			WHEN TabProducts.DocumentCurrency = &CurrencyNational
	|				THEN TabProducts.Amount * RegExchangeRates.ExchangeRate * TabProducts.Multiplicity / (TabProducts.ExchangeRate * RegExchangeRates.Multiplicity)
	|			ELSE TabProducts.Amount
	|		END AS NUMBER(15, 2)),
	|	TabProducts.Order,
	|	ISNULL(SalesSlip.CashCRSession, VALUE(Document.ShiftClosure.EmptyRef)),
	|	SalesSlip.Archival,
	|	TabProducts.SalesRep";
	
	Query.SetParameter("Ref",					DocumentRefGoodsReturn);
	Query.SetParameter("Company", 				StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PointInTime", 			New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("UseCharacteristics",	StructureAdditionalProperties.AccountingPolicy.UseCharacteristics);
	Query.SetParameter("PresentationCurrency",	Constants.PresentationCurrency.Get());
	Query.SetParameter("CurrencyNational",		Constants.FunctionalCurrency.Get());
	Query.SetParameter("DocumentCurrency",		DocumentRefGoodsReturn.DocumentCurrency);

	ResultsArray = Query.ExecuteBatch();
	
	// Creation of document postings.
	DriveServer.GenerateTransactionsTable(DocumentRefGoodsReturn, StructureAdditionalProperties);
	
	PerformanceEstimationClientServer.StartTimeMeasurement("DocumentCreditNoteGenerateTables");
	
	If DocumentRefGoodsReturn.OperationKind = Enums.OperationTypesGoodsReturn.FromCustomer Then
		GenerateTableSales(DocumentRefGoodsReturn, StructureAdditionalProperties);
	EndIf;
	
	GenerateTableInventoryInWarehouses(DocumentRefGoodsReturn, StructureAdditionalProperties);
	GenerateTableInventory(DocumentRefGoodsReturn, StructureAdditionalProperties);
	GenerateTableIncomeAndExpenses(DocumentRefGoodsReturn, StructureAdditionalProperties);
	GenerateTableAccountingJournalEntries(DocumentRefGoodsReturn, StructureAdditionalProperties);
	
	// Serial numbers
	GenerateTableSerialNumbers(DocumentRefGoodsReturn, StructureAdditionalProperties);	
	
EndProcedure

// Controls the occurrence of negative balances.
//
Procedure RunControl(DocumentRefGoodsReturn, AdditionalProperties, Cancel, PostingDelete = False) Export
	
	If Not DriveServer.RunBalanceControl() Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// If temporary tables "RegisterRecordsInventoryChange", "MovementsInventoryInWarehousesChange"
	//  contain records, it is required to control goods implementation.
		
	If StructureTemporaryTables.RegisterRecordsInventoryChange
	 OR StructureTemporaryTables.RegisterRecordsInventoryInWarehousesChange Then
		
		Query = New Query(
		"SELECT
		|	RegisterRecordsInventoryInWarehousesChange.LineNumber AS LineNumber,
		|	RegisterRecordsInventoryInWarehousesChange.Company AS CompanyPresentation,
		|	RegisterRecordsInventoryInWarehousesChange.StructuralUnit AS StructuralUnitPresentation,
		|	RegisterRecordsInventoryInWarehousesChange.Products AS ProductsPresentation,
		|	RegisterRecordsInventoryInWarehousesChange.Characteristic AS CharacteristicPresentation,
		|	RegisterRecordsInventoryInWarehousesChange.Batch AS BatchPresentation,
		|	RegisterRecordsInventoryInWarehousesChange.Cell AS PresentationCell,
		|	InventoryInWarehousesOfBalance.StructuralUnit.StructuralUnitType AS StructuralUnitType,
		|	InventoryInWarehousesOfBalance.Products.MeasurementUnit AS MeasurementUnitPresentation,
		|	RegisterRecordsInventoryInWarehousesChange.QuantityChange + InventoryInWarehousesOfBalance.QuantityBalance AS BalanceInventoryInWarehouses,
		|	InventoryInWarehousesOfBalance.QuantityBalance AS QuantityBalanceInventoryInWarehouses
		|FROM
		|	RegisterRecordsInventoryInWarehousesChange AS RegisterRecordsInventoryInWarehousesChange
		|		INNER JOIN AccumulationRegister.InventoryInWarehouses.Balance(&ControlTime, ) AS InventoryInWarehousesOfBalance
		|		ON RegisterRecordsInventoryInWarehousesChange.Company = InventoryInWarehousesOfBalance.Company
		|			AND RegisterRecordsInventoryInWarehousesChange.StructuralUnit = InventoryInWarehousesOfBalance.StructuralUnit
		|			AND RegisterRecordsInventoryInWarehousesChange.Products = InventoryInWarehousesOfBalance.Products
		|			AND RegisterRecordsInventoryInWarehousesChange.Characteristic = InventoryInWarehousesOfBalance.Characteristic
		|			AND RegisterRecordsInventoryInWarehousesChange.Batch = InventoryInWarehousesOfBalance.Batch
		|			AND RegisterRecordsInventoryInWarehousesChange.Cell = InventoryInWarehousesOfBalance.Cell
		|			AND (InventoryInWarehousesOfBalance.QuantityBalance < 0)
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
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
		|	RegisterRecordsInventoryChange.QuantityChange + InventoryBalances.QuantityBalance AS BalanceInventory,
		|	InventoryBalances.QuantityBalance AS QuantityBalanceInventory,
		|	InventoryBalances.AmountBalance AS AmountBalanceInventory
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
		|			AND (InventoryBalances.QuantityBalance < 0)");
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.SetParameter("ControlTime", AdditionalProperties.ForPosting.ControlTime);
		
		ResultsArray = Query.ExecuteBatch();
		
		// Negative balance of inventory in the warehouse.
		If Not ResultsArray[0].IsEmpty() Then
			DocumentObjectGoodsReturn = DocumentRefGoodsReturn.GetObject();
			QueryResultSelection = ResultsArray[0].Select();
			DriveServer.ShowMessageAboutPostingToInventoryInWarehousesRegisterErrors(DocumentObjectGoodsReturn, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance of inventory.
		If Not ResultsArray[1].IsEmpty() Then
			DocumentObjectGoodsReturn = DocumentRefGoodsReturn.GetObject();
			QueryResultSelection = ResultsArray[1].Select();
			DriveServer.ShowMessageAboutPostingToInventoryRegisterErrors(DocumentObjectGoodsReturn, QueryResultSelection, Cancel);
		EndIf;
		
	EndIf;
	
EndProcedure

#Region PrintInterface

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
	
	If PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "Requisition") Then
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection,
															"Requisition",
															NStr("en = 'Requisition'"),
															DataProcessors.PrintRequisition.PrintForm(ObjectsArray, PrintObjects, "Requisition"));
	EndIf;
	
EndProcedure

// Fills in the list of printing commands.
// 
// Parameters:
//   PrintCommands - ValueTable - see fields' content in the PrintManagement.CreatePrintCommandsCollection function.
//
Procedure AddPrintCommands(PrintCommands) Export
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID							= "Requisition";
	PrintCommand.Presentation				= NStr("en = 'Requisition'");
	PrintCommand.FormsList					= "DocumentForm,ListForm";
	PrintCommand.CheckPostingBeforePrint	= False;
	PrintCommand.Order						= 1;
	
EndProcedure

Procedure PresentationGetProcessing(Data, Presentation, StandardProcessing)
	
	If Data.Number = Null
		OR Not ValueIsFilled(Data.Ref) Then
		Return;
	EndIf;
	
	StandardProcessing = False;
	
	Status = "";
	If Data.Ref.DeletionMark Then
		Status = NStr("en = '(deleted)'");
	ElsIf Not Data.Ref.Posted Then
		Status = NStr("en = '(not posted)'");
	EndIf;
	
	Presentation = StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en = '%1 %2 %3 dated %4 %5'"),
		Data.Ref.Metadata().Presentation(),
		Lower(Data.Ref.OperationKind),
		?(Data.Property("Number"), ObjectPrefixationClientServer.GetNumberForPrinting(Data.Number, True, True), ""),
		Format(Data.Date, "DLF=D"),
		Status);
		
EndProcedure

#EndRegion

#Region InfobaseUpdate

Procedure ProcessDataToUpgradeToNewVersion() Export
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	GoodsReturn.Ref AS Ref,
	|	SalesInvoices.AmountIncludesVAT AS AmountIncludesVAT
	|FROM
	|	Document.GoodsReturn AS GoodsReturn
	|		INNER JOIN Document.SalesInvoice AS SalesInvoices
	|		ON GoodsReturn.SalesDocument = SalesInvoices.Ref
	|WHERE
	|	GoodsReturn.AmountIncludesVAT <> GoodsReturn.SalesDocument.AmountIncludesVAT
	|
	|UNION ALL
	|
	|SELECT
	|	GoodsReturn.Ref,
	|	SupplierInvoices.AmountIncludesVAT
	|FROM
	|	Document.GoodsReturn AS GoodsReturn
	|		INNER JOIN Document.SupplierInvoice AS SupplierInvoices
	|		ON GoodsReturn.SupplierInvoice = SupplierInvoices.Ref
	|WHERE
	|	GoodsReturn.AmountIncludesVAT <> GoodsReturn.SupplierInvoice.AmountIncludesVAT";
	
	QueryResult = Query.Execute();
	Selection	= QueryResult.Select();
	
	While Selection.Next() Do
		DocObject = Selection.Ref.GetObject();
		DocObject = Selection.AmountIncludesVAT;
		
		Try
			DocObject.Write();
		Except
			TextError = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'An error on write document: %1'", CommonUseClientServer.MainLanguageCode()),
				Selection.Ref);
			WriteLogEvent(TextError, EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
		EndTry;		
	EndDo;
	
EndProcedure

#EndRegion


#EndIf