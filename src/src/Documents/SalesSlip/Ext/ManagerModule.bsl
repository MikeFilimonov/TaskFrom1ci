#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventoryInWarehouses(DocumentRefSalesSlip, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	SalesSlipInventory.LineNumber AS LineNumber,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	SalesSlipInventory.Date AS Period,
	|	SalesSlipInventory.Company AS Company,
	|	SalesSlipInventory.Products AS Products,
	|	SalesSlipInventory.Characteristic AS Characteristic,
	|	SalesSlipInventory.Batch AS Batch,
	|	SalesSlipInventory.StructuralUnit AS StructuralUnit,
	|	SUM(SalesSlipInventory.Quantity) AS Quantity
	|FROM
	|	TemporaryTableInventory AS SalesSlipInventory
	|WHERE
	|	SalesSlipInventory.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
	|	AND (&CheckIssued
	|			OR &ProductReserved)
	|	AND (NOT &Archival)
	|
	|GROUP BY
	|	SalesSlipInventory.LineNumber,
	|	SalesSlipInventory.Date,
	|	SalesSlipInventory.Company,
	|	SalesSlipInventory.Products,
	|	SalesSlipInventory.Characteristic,
	|	SalesSlipInventory.Batch,
	|	SalesSlipInventory.StructuralUnit
	|
	|ORDER BY
	|	LineNumber";
	
	Query.SetParameter("Ref", DocumentRefSalesSlip);
	Query.SetParameter("CheckIssued", StructureAdditionalProperties.ForPosting.CheckIssued);
	Query.SetParameter("ProductReserved", StructureAdditionalProperties.ForPosting.ProductReserved);
	Query.SetParameter("Archival", StructureAdditionalProperties.ForPosting.Archival);
		
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryInWarehouses", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableCashAssetsInCashRegisters(DocumentRefSalesSlip, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	1 AS LineNumber,
	|	DocumentData.Date AS Date,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	DocumentData.Company AS Company,
	|	DocumentData.CashCR AS CashCR,
	|	DocumentData.CashCRGLAccount AS GLAccount,
	|	DocumentData.DocumentCurrency AS Currency,
	|	SUM(DocumentData.Amount) AS Amount,
	|	SUM(DocumentData.AmountCur) AS AmountCur,
	|	SUM(DocumentData.Amount) AS AmountForBalance,
	|	SUM(DocumentData.AmountCur) AS AmountCurForBalance,
	|	CAST(&CashFundsReceipt AS String(100)) AS ContentOfAccountingRecord
	|INTO TemporaryTableCashAssetsInRetailCashes
	|FROM
	|	TemporaryTableInventory AS DocumentData
	|WHERE
	|	&CheckIssued
	|	AND Not &Archival
	|
	|GROUP BY
	|	DocumentData.Date,
	|	DocumentData.Company,
	|	DocumentData.CashCR,
	|	DocumentData.CashCRGLAccount,
	|	DocumentData.DocumentCurrency
	|
	|UNION ALL
	|
	|SELECT
	|	1,
	|	DocumentData.Date,
	|	VALUE(AccumulationRecordType.Expense),
	|	DocumentData.Company,
	|	DocumentData.CashCR,
	|	DocumentData.CashCRGLAccount,
	|	DocumentData.DocumentCurrency,
	|	SUM(DocumentData.Amount),
	|	SUM(DocumentData.AmountCur),
	|	-SUM(DocumentData.Amount),
	|	-SUM(DocumentData.AmountCur),
	|	CAST(&PaymentWithPaymentCards AS String(100))
	|FROM
	|	TemporaryTablePaymentCards AS DocumentData
	|WHERE
	|	&CheckIssued
	|	AND Not &Archival
	|
	|GROUP BY
	|	DocumentData.Date,
	|	DocumentData.Company,
	|	DocumentData.CashCR,
	|	DocumentData.CashCRGLAccount,
	|	DocumentData.DocumentCurrency
	|
	|INDEX BY
	|	Company,
	|	CashCR,
	|	Currency,
	|	GLAccount";
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();
	
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("Ref", DocumentRefSalesSlip);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("CheckIssued", StructureAdditionalProperties.ForPosting.CheckIssued);
	Query.SetParameter("Archival", StructureAdditionalProperties.ForPosting.Archival);
	Query.SetParameter("CashFundsReceipt", NStr("en = 'Cash receipt to cash register'", MainLanguageCode));
	Query.SetParameter("PaymentWithPaymentCards", NStr("en = 'Payment with payment cards'", MainLanguageCode));
	Query.SetParameter("ExchangeDifference", NStr("en = 'Foreign currency exchange gains and losses'", MainLanguageCode));
	
	Query.Execute();
	
	// Setting of the exclusive lock of the cash funds controlled balances.
	Query.Text =
	"SELECT
	|	TemporaryTableCashAssetsInRetailCashes.Company AS Company,
	|	TemporaryTableCashAssetsInRetailCashes.CashCR AS CashCR
	|FROM
	|	TemporaryTableCashAssetsInRetailCashes";
	
	QueryResult = Query.Execute();
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.CashInCashRegisters");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;
	
	For Each ColumnQueryResult In QueryResult.Columns Do
		LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
	EndDo;
	Block.Lock();
	
	QueryNumber = 0;
	Query.Text = DriveServer.GetQueryTextExchangeRateDifferencesCashInCashRegisters(Query.TempTablesManager, QueryNumber);
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableCashInCashRegisters", ResultsArray[QueryNumber].Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableIncomeAndExpenses(DocumentRefSalesSlip, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	1 AS Order,
	|	TableIncomeAndExpenses.LineNumber AS LineNumber,
	|	TableIncomeAndExpenses.Date AS Period,
	|	TableIncomeAndExpenses.Company AS Company,
	|	TableIncomeAndExpenses.Department AS StructuralUnit,
	|	TableIncomeAndExpenses.BusinessLine AS BusinessLine,
	|	CASE
	|		WHEN TableIncomeAndExpenses.SalesOrder = VALUE(Document.SalesOrder.EmptyRef)
	|				OR TableIncomeAndExpenses.SalesOrder = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE TableIncomeAndExpenses.SalesOrder
	|	END AS SalesOrder,
	|	TableIncomeAndExpenses.GLAccountRevenueFromSales AS GLAccount,
	|	CAST(&IncomeReflection AS STRING(100)) AS ContentOfAccountingRecord,
	|	SUM(TableIncomeAndExpenses.Amount - TableIncomeAndExpenses.VATAmount) AS AmountIncome,
	|	0 AS AmountExpense,
	|	FALSE AS OfflineRecord
	|FROM
	|	TemporaryTableInventory AS TableIncomeAndExpenses
	|WHERE
	|	NOT TableIncomeAndExpenses.ProductsOnCommission
	|	AND &CheckIssued
	|	AND NOT &Archival
	|
	|GROUP BY
	|	TableIncomeAndExpenses.Date,
	|	TableIncomeAndExpenses.LineNumber,
	|	TableIncomeAndExpenses.Company,
	|	TableIncomeAndExpenses.Department,
	|	TableIncomeAndExpenses.BusinessLine,
	|	TableIncomeAndExpenses.SalesOrder,
	|	TableIncomeAndExpenses.GLAccountRevenueFromSales
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	UNDEFINED,
	|	VALUE(Catalog.LinesOfBusiness.Other),
	|	UNDEFINED,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN &PositiveExchangeDifferenceGLAccount
	|		ELSE &NegativeExchangeDifferenceAccountOfAccounting
	|	END,
	|	&ExchangeDifference,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN DocumentTable.AmountOfExchangeDifferences
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN 0
	|		ELSE -DocumentTable.AmountOfExchangeDifferences
	|	END,
	|	FALSE
	|FROM
	|	TemporaryTableExchangeRateLossesCashAssetsInRetailCashes AS DocumentTable
	|WHERE
	|	&CheckIssued
	|	AND NOT &Archival
	|
	|ORDER BY
	|	Order,
	|	LineNumber";
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();
	
	Query.SetParameter("PositiveExchangeDifferenceGLAccount",			Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeGain"));
	Query.SetParameter("NegativeExchangeDifferenceAccountOfAccounting", Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeLoss"));
	Query.SetParameter("IncomeReflection",								NStr("en = 'Record income'", MainLanguageCode));
	Query.SetParameter("ExchangeDifference",							NStr("en = 'Foreign currency exchange gains and losses'", MainLanguageCode));
	Query.SetParameter("CheckIssued",									StructureAdditionalProperties.ForPosting.CheckIssued);
	Query.SetParameter("Archival",										StructureAdditionalProperties.ForPosting.Archival);
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpenses", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableSales(DocumentRefSalesSlip, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	TableSales.Date AS Period,
	|	TableSales.Company AS Company,
	|	TableSales.Products AS Products,
	|	TableSales.Characteristic AS Characteristic,
	|	TableSales.Batch AS Batch,
	|	TableSales.SalesOrder AS SalesOrder,
	|	TableSales.Document AS Document,
	|	TableSales.VATRate AS VATRate,
	|	TableSales.Department AS Department,
	|	TableSales.Responsible AS Responsible,
	|	SUM(TableSales.Quantity) AS Quantity,
	|	SUM(TableSales.AmountVATPurchaseSale) AS VATAmount,
	|	SUM(TableSales.Amount - TableSales.AmountVATPurchaseSale) AS Amount,
	|	0 AS Cost
	|FROM
	|	TemporaryTableInventory AS TableSales
	|WHERE
	|	&CheckIssued
	|	AND (NOT &Archival)
	|
	|GROUP BY
	|	TableSales.Date,
	|	TableSales.Company,
	|	TableSales.Products,
	|	TableSales.Characteristic,
	|	TableSales.Batch,
	|	TableSales.SalesOrder,
	|	TableSales.Document,
	|	TableSales.VATRate,
	|	TableSales.Department,
	|	TableSales.Responsible";
	
	Query.SetParameter("CheckIssued", StructureAdditionalProperties.ForPosting.CheckIssued);
	Query.SetParameter("Archival", StructureAdditionalProperties.ForPosting.Archival);
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSales", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableAccountingJournalEntries(DocumentRefSalesSlip, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	1 AS Order,
	|	TableAccountingJournalEntries.LineNumber AS LineNumber,
	|	TableAccountingJournalEntries.Date AS Period,
	|	TableAccountingJournalEntries.Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	TableAccountingJournalEntries.CashCRGLAccount AS AccountDr,
	|	CASE
	|		WHEN TableAccountingJournalEntries.CashCRGLAccount.Currency
	|			THEN TableAccountingJournalEntries.DocumentCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN TableAccountingJournalEntries.CashCRGLAccount.Currency
	|			THEN TableAccountingJournalEntries.AmountCur - TableAccountingJournalEntries.VATAmountCur
	|		ELSE 0
	|	END AS AmountCurDr,
	|	CASE
	|		WHEN TableAccountingJournalEntries.ProductsOnCommission
	|			THEN &AccountsPayable
	|		ELSE TableAccountingJournalEntries.GLAccountRevenueFromSales
	|	END AS AccountCr,
	|	CASE
	|		WHEN TableAccountingJournalEntries.ProductsOnCommission
	|			THEN &PresentationCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	CASE
	|		WHEN TableAccountingJournalEntries.ProductsOnCommission
	|			THEN TableAccountingJournalEntries.Amount - TableAccountingJournalEntries.VATAmount
	|		ELSE 0
	|	END AS AmountCurCr,
	|	TableAccountingJournalEntries.Amount - TableAccountingJournalEntries.VATAmount AS Amount,
	|	&IncomeReflection AS Content,
	|	FALSE AS OfflineRecord
	|FROM
	|	TemporaryTableInventory AS TableAccountingJournalEntries
	|WHERE
	|	&CheckIssued
	|	AND NOT &Archival
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	TableAccountingJournalEntries.LineNumber,
	|	TableAccountingJournalEntries.Date,
	|	TableAccountingJournalEntries.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	TableAccountingJournalEntries.POSTerminalGlAccount,
	|	CASE
	|		WHEN TableAccountingJournalEntries.POSTerminalGlAccount.Currency
	|			THEN TableAccountingJournalEntries.DocumentCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN TableAccountingJournalEntries.POSTerminalGlAccount.Currency
	|			THEN TableAccountingJournalEntries.AmountCur
	|		ELSE 0
	|	END,
	|	TableAccountingJournalEntries.CashCRGLAccount,
	|	CASE
	|		WHEN TableAccountingJournalEntries.CashCRGLAccount.Currency
	|			THEN TableAccountingJournalEntries.DocumentCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN TableAccountingJournalEntries.CashCRGLAccount.Currency
	|			THEN TableAccountingJournalEntries.AmountCur
	|		ELSE 0
	|	END,
	|	TableAccountingJournalEntries.Amount,
	|	&ReflectionOfPaymentByCards,
	|	FALSE
	|FROM
	|	TemporaryTablePaymentCards AS TableAccountingJournalEntries
	|WHERE
	|	&CheckIssued
	|	AND NOT &Archival
	|
	|UNION ALL
	|
	|SELECT
	|	3,
	|	TableAccountingJournalEntries.LineNumber,
	|	TableAccountingJournalEntries.Date,
	|	TableAccountingJournalEntries.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	CASE
	|		WHEN TableAccountingJournalEntries.AmountOfExchangeDifferences > 0
	|			THEN TableAccountingJournalEntries.GLAccount
	|		ELSE &NegativeExchangeDifferenceAccountOfAccounting
	|	END,
	|	CASE
	|		WHEN TableAccountingJournalEntries.AmountOfExchangeDifferences > 0
	|				AND TableAccountingJournalEntries.GLAccount.Currency
	|			THEN TableAccountingJournalEntries.Currency
	|		ELSE UNDEFINED
	|	END,
	|	0,
	|	CASE
	|		WHEN TableAccountingJournalEntries.AmountOfExchangeDifferences > 0
	|			THEN &PositiveExchangeDifferenceGLAccount
	|		ELSE TableAccountingJournalEntries.GLAccount
	|	END,
	|	CASE
	|		WHEN TableAccountingJournalEntries.AmountOfExchangeDifferences < 0
	|				AND TableAccountingJournalEntries.GLAccount.Currency
	|			THEN TableAccountingJournalEntries.Currency
	|		ELSE UNDEFINED
	|	END,
	|	0,
	|	CASE
	|		WHEN TableAccountingJournalEntries.AmountOfExchangeDifferences > 0
	|			THEN TableAccountingJournalEntries.AmountOfExchangeDifferences
	|		ELSE -TableAccountingJournalEntries.AmountOfExchangeDifferences
	|	END,
	|	&ExchangeDifference,
	|	FALSE
	|FROM
	|	TemporaryTableExchangeRateLossesCashAssetsInRetailCashes AS TableAccountingJournalEntries
	|WHERE
	|	&CheckIssued
	|	AND NOT &Archival
	|
	|UNION ALL
	|
	|SELECT
	|	4,
	|	TableAccountingJournalEntries.LineNumber,
	|	TableAccountingJournalEntries.Date,
	|	TableAccountingJournalEntries.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	TableAccountingJournalEntries.CashCRGLAccount,
	|	CASE
	|		WHEN TableAccountingJournalEntries.CashCRGLAccount.Currency
	|			THEN TableAccountingJournalEntries.DocumentCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN TableAccountingJournalEntries.CashCRGLAccount.Currency
	|			THEN TableAccountingJournalEntries.VATAmountCur
	|		ELSE 0
	|	END,
	|	TableAccountingJournalEntries.VATOutputGLAccount,
	|	UNDEFINED,
	|	0,
	|	TableAccountingJournalEntries.VATAmount,
	|	&VAT,
	|	FALSE
	|FROM
	|	TemporaryTableInventory AS TableAccountingJournalEntries
	|WHERE
	|	&CheckIssued
	|	AND NOT &Archival
	|	AND TableAccountingJournalEntries.VATAmount > 0
	|
	|ORDER BY
	|	Order,
	|	LineNumber";
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();
	
	Query.SetParameter("AccountsPayable",								Catalogs.DefaultGLAccounts.GetDefaultGLAccount("AccountsPayable"));
	Query.SetParameter("IncomeReflection",								NStr("en = 'Revenue'", MainLanguageCode));
	Query.SetParameter("ReflectionOfPaymentByCards",					NStr("en = 'Payment with payment cards'", MainLanguageCode));
	Query.SetParameter("PresentationCurrency",							Constants.PresentationCurrency.Get());
	Query.SetParameter("PositiveExchangeDifferenceGLAccount",			Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeGain"));
	Query.SetParameter("NegativeExchangeDifferenceAccountOfAccounting",	Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeLoss"));
	Query.SetParameter("CheckIssued",									StructureAdditionalProperties.ForPosting.CheckIssued);
	Query.SetParameter("Archival",										StructureAdditionalProperties.ForPosting.Archival);
	Query.SetParameter("ExchangeDifference",							NStr("en = 'Foreign currency exchange gains and losses'", MainLanguageCode));
	Query.SetParameter("VAT",											NStr("en = 'VAT'", MainLanguageCode));

	QueryResult = Query.Execute();
	Selection	= QueryResult.Select();
	
	While Selection.Next() Do  
		NewEntry = StructureAdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries.Add();
		FillPropertyValues(NewEntry, Selection);
	EndDo;
	
EndProcedure

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
Procedure InitializeDocumentData(DocumentRefSalesSlip, StructureAdditionalProperties) Export
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	SalesSlipInventory.LineNumber AS LineNumber,
	|	SalesSlipInventory.Ref AS Document,
	|	SalesSlipInventory.Ref.Date AS Date,
	|	UNDEFINED AS SalesOrder,
	|	SalesSlipInventory.Ref.CashCR AS CashCR,
	|	SalesSlipInventory.Ref.Responsible AS Responsible,
	|	SalesSlipInventory.Ref.CashCR.Owner AS CashCROwner,
	|	SalesSlipInventory.Ref.CashCR.GLAccount AS CashCRGLAccount,
	|	SalesSlipInventory.Ref.DocumentCurrency AS DocumentCurrency,
	|	&Company AS Company,
	|	SalesSlipInventory.Ref.StructuralUnit AS StructuralUnit,
	|	SalesSlipInventory.Ref.Department AS Department,
	|	SalesSlipInventory.Products.BusinessLine AS BusinessLine,
	|	SalesSlipInventory.Products.ProductsType AS ProductsType,
	|	SalesSlipInventory.RevenueGLAccount AS GLAccountRevenueFromSales,
	|	UNDEFINED AS Cell,
	|	CASE
	|		WHEN &UseBatches
	|				AND SalesSlipInventory.Batch.Status = VALUE(Enum.BatchStatuses.CounterpartysInventory)
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS ProductsOnCommission,
	|	SalesSlipInventory.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN SalesSlipInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseBatches
	|			THEN SalesSlipInventory.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS Batch,
	|	CASE
	|		WHEN VALUETYPE(SalesSlipInventory.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN SalesSlipInventory.Quantity
	|		ELSE SalesSlipInventory.Quantity * SalesSlipInventory.MeasurementUnit.Factor
	|	END AS Quantity,
	|	SalesSlipInventory.VATRate AS VATRate,
	|	CAST(CASE
	|			WHEN SalesSlipInventory.Ref.IncludeVATInPrice
	|				THEN 0
	|			ELSE SalesSlipInventory.VATAmount * DocCurrencyExchangeRates.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * DocCurrencyExchangeRates.Multiplicity)
	|		END AS NUMBER(15, 2)) AS VATAmount,
	|	CAST(SalesSlipInventory.VATAmount * DocCurrencyExchangeRates.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * DocCurrencyExchangeRates.Multiplicity) AS NUMBER(15, 2)) AS AmountVATPurchaseSale,
	|	CAST(SalesSlipInventory.Total * DocCurrencyExchangeRates.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * DocCurrencyExchangeRates.Multiplicity) AS NUMBER(15, 2)) AS Amount,
	|	CAST(SalesSlipInventory.VATAmount AS NUMBER(15, 2)) AS VATAmountCur,
	|	CAST(SalesSlipInventory.Total AS NUMBER(15, 2)) AS AmountCur,
	|	SalesSlipInventory.ConnectionKey AS ConnectionKey,
	|	SalesSlipInventory.VATOutputGLAccount AS VATOutputGLAccount
	|INTO TemporaryTableInventory
	|FROM
	|	Document.SalesSlip.Inventory AS SalesSlipInventory
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(
	|				&PointInTime,
	|				Currency IN
	|					(SELECT
	|						Constants.PresentationCurrency
	|					FROM
	|						Constants AS Constants)) AS ManagExchangeRates
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&PointInTime, ) AS DocCurrencyExchangeRates
	|		ON SalesSlipInventory.Ref.DocumentCurrency = DocCurrencyExchangeRates.Currency
	|WHERE
	|	SalesSlipInventory.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TabularSection.LineNumber AS LineNumber,
	|	TabularSection.Ref.Date AS Date,
	|	&Ref AS Document,
	|	&Company AS Company,
	|	TabularSection.Ref.CashCR AS CashCR,
	|	TabularSection.Ref.CashCR.GLAccount AS CashCRGLAccount,
	|	TabularSection.Ref.POSTerminal.GLAccount AS POSTerminalGlAccount,
	|	TabularSection.Ref.DocumentCurrency AS DocumentCurrency,
	|	CAST(TabularSection.Amount * ExchangeRatesOfPettyCashe.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * ExchangeRatesOfPettyCashe.Multiplicity) AS NUMBER(15, 2)) AS Amount,
	|	TabularSection.Amount AS AmountCur
	|INTO TemporaryTablePaymentCards
	|FROM
	|	Document.SalesSlip.PaymentWithPaymentCards AS TabularSection
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(
	|				&PointInTime,
	|				Currency IN
	|					(SELECT
	|						Constants.PresentationCurrency
	|					FROM
	|						Constants AS Constants)) AS AccountingExchangeRatesSliceLast
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&PointInTime, ) AS ExchangeRatesOfPettyCashe
	|		ON TabularSection.Ref.DocumentCurrency = ExchangeRatesOfPettyCashe.Currency
	|WHERE
	|	TabularSection.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SalesSlipDiscountsMarkups.ConnectionKey AS ConnectionKey,
	|	SalesSlipDiscountsMarkups.DiscountMarkup AS DiscountMarkup,
	|	CAST(CASE
	|			WHEN SalesSlipDiscountsMarkups.Ref.DocumentCurrency = ConstantNationalCurrency.Value
	|				THEN SalesSlipDiscountsMarkups.Amount * RegExchangeRates.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * RegExchangeRates.Multiplicity)
	|			ELSE SalesSlipDiscountsMarkups.Amount * ManagExchangeRates.Multiplicity / ManagExchangeRates.ExchangeRate
	|		END AS NUMBER(15, 2)) AS Amount,
	|	SalesSlipDiscountsMarkups.Ref.Date AS Period,
	|	SalesSlipDiscountsMarkups.Ref.StructuralUnit AS StructuralUnit
	|INTO TemporaryTableAutoDiscountsMarkups
	|FROM
	|	Document.SalesSlip.DiscountsMarkups AS SalesSlipDiscountsMarkups
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(
	|				&PointInTime,
	|				Currency IN
	|					(SELECT
	|						ConstantAccountingCurrency.Value
	|					FROM
	|						Constant.PresentationCurrency AS ConstantAccountingCurrency)) AS ManagExchangeRates
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(
	|				&PointInTime,
	|				Currency IN
	|					(SELECT
	|						ConstantNationalCurrency.Value
	|					FROM
	|						Constant.FunctionalCurrency AS ConstantNationalCurrency)) AS RegExchangeRates
	|		ON (TRUE),
	|	Constant.FunctionalCurrency AS ConstantNationalCurrency
	|WHERE
	|	SalesSlipDiscountsMarkups.Ref = &Ref
	|	AND SalesSlipDiscountsMarkups.Amount <> 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SalesInvoiceSerialNumbers.ConnectionKey AS ConnectionKey,
	|	SalesInvoiceSerialNumbers.SerialNumber AS SerialNumber
	|INTO TemporaryTableSerialNumbers
	|FROM
	|	Document.SalesSlip.SerialNumbers AS SalesInvoiceSerialNumbers
	|WHERE
	|	SalesInvoiceSerialNumbers.Ref = &Ref
	|	AND &UseSerialNumbers";
	
	Query.SetParameter("Ref", DocumentRefSalesSlip);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("UseCharacteristics", StructureAdditionalProperties.AccountingPolicy.UseCharacteristics);
	Query.SetParameter("UseBatches", StructureAdditionalProperties.AccountingPolicy.UseBatches);
	Query.SetParameter("UseSerialNumbers", StructureAdditionalProperties.AccountingPolicy.UseSerialNumbers);
	
	Query.ExecuteBatch();
	
	// Creation of document postings.
	DriveServer.GenerateTransactionsTable(DocumentRefSalesSlip, StructureAdditionalProperties);
	
	GenerateTableInventoryInWarehouses(DocumentRefSalesSlip, StructureAdditionalProperties);
	GenerateTableCashAssetsInCashRegisters(DocumentRefSalesSlip, StructureAdditionalProperties);
	GenerateTableIncomeAndExpenses(DocumentRefSalesSlip, StructureAdditionalProperties);
	GenerateTableSales(DocumentRefSalesSlip, StructureAdditionalProperties);
	GenerateTableAccountingJournalEntries(DocumentRefSalesSlip, StructureAdditionalProperties);
	
	// DiscountCards
	GenerateTableSalesByDiscountCard(DocumentRefSalesSlip, StructureAdditionalProperties);
	// AutomaticDiscounts
	GenerateTableSalesByAutomaticDiscountsApplied(DocumentRefSalesSlip, StructureAdditionalProperties);
	
	// Serial numbers
	GenerateTableSerialNumbers(DocumentRefSalesSlip, StructureAdditionalProperties);
	
EndProcedure

// Controls the occurrence of negative balances.
//
Procedure RunControl(DocumentRefSalesSlip, AdditionalProperties, Cancel, PostingDelete = False) Export
	
	If Not DriveServer.RunBalanceControl()
	 OR Not Constants.CheckStockBalanceWhenIssuingSalesSlips.Get()
	    OR DocumentRefSalesSlip.Archival Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// If temporary tables "RegisterRecordsInventoryChange", control goods implementation.
	If StructureTemporaryTables.RegisterRecordsInventoryInWarehousesChange
		OR StructureTemporaryTables.RegisterRecordsCashInCashRegistersChange
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
		|				(Company, StructuralUnit, Products, Characteristic, Batch, Cell) In
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
		|	RegisterRecordsCashInCashRegistersChange.LineNumber AS LineNumber,
		|	REFPRESENTATION(RegisterRecordsCashInCashRegistersChange.Company) AS CompanyPresentation,
		|	REFPRESENTATION(RegisterRecordsCashInCashRegistersChange.CashCR) AS CashCRDescription,
		|	REFPRESENTATION(RegisterRecordsCashInCashRegistersChange.CashCR.CashCurrency) AS CurrencyPresentation,
		|	ISNULL(CashAssetsInRetailCashesBalances.AmountBalance, 0) AS AmountBalance,
		|	ISNULL(CashAssetsInRetailCashesBalances.AmountCurBalance, 0) AS AmountCurBalance,
		|	RegisterRecordsCashInCashRegistersChange.SumCurChange + ISNULL(CashAssetsInRetailCashesBalances.AmountCurBalance, 0) AS BalanceCashAssets,
		|	RegisterRecordsCashInCashRegistersChange.SumBeforeWrite AS SumBeforeWrite,
		|	RegisterRecordsCashInCashRegistersChange.AmountOnWrite AS AmountOnWrite,
		|	RegisterRecordsCashInCashRegistersChange.AmountChange AS AmountChange,
		|	RegisterRecordsCashInCashRegistersChange.AmountCurBeforeWrite AS AmountCurBeforeWrite,
		|	RegisterRecordsCashInCashRegistersChange.SumCurOnWrite AS SumCurOnWrite,
		|	RegisterRecordsCashInCashRegistersChange.SumCurChange AS SumCurChange
		|FROM
		|	RegisterRecordsCashInCashRegistersChange AS RegisterRecordsCashInCashRegistersChange
		|		LEFT JOIN AccumulationRegister.CashInCashRegisters.Balance(
		|				&ControlTime,
		|				(Company, CashCR) In
		|					(SELECT
		|						RegisterRecordsCashInCashRegistersChange.Company AS Company,
		|						RegisterRecordsCashInCashRegistersChange.CashCR AS CashAssetsType
		|					FROM
		|						RegisterRecordsCashInCashRegistersChange AS RegisterRecordsCashInCashRegistersChange)) AS CashAssetsInRetailCashesBalances
		|		ON RegisterRecordsCashInCashRegistersChange.Company = CashAssetsInRetailCashesBalances.Company
		|			AND RegisterRecordsCashInCashRegistersChange.CashCR = CashAssetsInRetailCashesBalances.CashCR
		|WHERE
		|	ISNULL(CashAssetsInRetailCashesBalances.AmountCurBalance, 0) < 0
		|
		|ORDER BY
		|	LineNumber
		|;
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
		|	ISNULL(SerialNumbersBalance.QuantityBalance, 0) AS BalanceQuantitySerialNumbers
		|FROM
		|	RegisterRecordsSerialNumbersChange AS RegisterRecordsSerialNumbersChange
		|		INNER JOIN AccumulationRegister.SerialNumbers.Balance(&ControlTime, ) AS SerialNumbersBalance
		|		ON RegisterRecordsSerialNumbersChange.StructuralUnit = SerialNumbersBalance.StructuralUnit
		|			AND RegisterRecordsSerialNumbersChange.Products = SerialNumbersBalance.Products
		|			AND RegisterRecordsSerialNumbersChange.Characteristic = SerialNumbersBalance.Characteristic
		|			AND RegisterRecordsSerialNumbersChange.Batch = SerialNumbersBalance.Batch
		|			AND RegisterRecordsSerialNumbersChange.SerialNumber = SerialNumbersBalance.SerialNumber
		|			AND RegisterRecordsSerialNumbersChange.Cell = SerialNumbersBalance.Cell
		|			AND (ISNULL(SerialNumbersBalance.QuantityBalance, 0) < 0)");
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.SetParameter("ControlTime", AdditionalProperties.ForPosting.ControlTime);
		
		ResultsArray = Query.ExecuteBatch();
		
		If Not ResultsArray[0].IsEmpty()
		 OR Not ResultsArray[1].IsEmpty() Then
			DocumentObjectSalesSlip = DocumentRefSalesSlip.GetObject()
		EndIf;
		
		// Negative balance of inventory in the warehouse.
		If Not ResultsArray[0].IsEmpty() Then
			QueryResultSelection = ResultsArray[0].Select();
			DriveServer.ShowMessageAboutPostingToInventoryInWarehousesRegisterErrors(DocumentObjectSalesSlip, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance in cash CR.
		If Not ResultsArray[1].IsEmpty() Then
			QueryResultSelection = ResultsArray[1].Select();
			DriveServer.ErrorMessageOfPostingOnRegisterOfCashAtCashRegisters(DocumentObjectSalesSlip, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance of serial numbers in the warehouse.
		If Not ResultsArray[2].IsEmpty() Then
			QueryResultSelection = ResultsArray[2].Select();
			DriveServer.ShowMessageAboutPostingSerialNumbersRegisterErrors(DocumentObjectSalesSlip, QueryResultSelection, Cancel);
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region DiscountCards

// Generates values table creating data for posting by the SalesWithCardBasedDiscounts register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableSalesByDiscountCard(DocumentRefSalesSlip, StructureAdditionalProperties)
	
	If DocumentRefSalesSlip.DiscountCard.IsEmpty() Then
		StructureAdditionalProperties.TableForRegisterRecords.Insert("SaleByDiscountCardTable", New ValueTable);
		Return;
	EndIf;
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	TableSales.Date AS Period,
	|	TableSales.Document.DiscountCard AS DiscountCard,
	|	TableSales.Document.DiscountCard.CardOwner AS CardOwner,
	|	SUM(TableSales.Amount) AS Amount
	|FROM
	|	TemporaryTableInventory AS TableSales
	|WHERE
	|	&CheckIssued
	|	AND (NOT &Archival)
	|
	|GROUP BY
	|	TableSales.Date,
	|	TableSales.Document.DiscountCard,
	|	TableSales.Document.DiscountCard.CardOwner";
	
	Query.SetParameter("CheckIssued", StructureAdditionalProperties.ForPosting.CheckIssued);
	Query.SetParameter("Archival", StructureAdditionalProperties.ForPosting.Archival);
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("SaleByDiscountCardTable", QueryResult.Unload());
	
EndProcedure

#EndRegion

#Region AutomaticDiscounts

// Generates a table of values that contains the data for posting by the register AutomaticDiscountsApplied.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableSalesByAutomaticDiscountsApplied(DocumentRefSalesSlip, StructureAdditionalProperties)
	
	If DocumentRefSalesSlip.DiscountsMarkups.Count() = 0 OR Not GetFunctionalOption("UseAutomaticDiscounts") Then
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAutomaticDiscountsApplied", New ValueTable);
		Return;
	EndIf;
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	TemporaryTableAutoDiscountsMarkups.Period,
	|	TemporaryTableAutoDiscountsMarkups.DiscountMarkup AS AutomaticDiscount,
	|	TemporaryTableAutoDiscountsMarkups.Amount AS DiscountAmount,
	|	TemporaryTableInventory.Products,
	|	TemporaryTableInventory.Characteristic,
	|	TemporaryTableInventory.Document AS DocumentDiscounts,
	|	TemporaryTableInventory.StructuralUnit AS RecipientDiscounts
	|FROM
	|	TemporaryTableInventory AS TemporaryTableInventory
	|		INNER JOIN TemporaryTableAutoDiscountsMarkups AS TemporaryTableAutoDiscountsMarkups
	|		ON TemporaryTableInventory.ConnectionKey = TemporaryTableAutoDiscountsMarkups.ConnectionKey
	|WHERE
	|	&CheckIssued
	|	AND (NOT &Archival)";
	
	Query.SetParameter("CheckIssued", StructureAdditionalProperties.ForPosting.CheckIssued);
	Query.SetParameter("Archival", StructureAdditionalProperties.ForPosting.Archival);
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAutomaticDiscountsApplied", QueryResult.Unload());
	
EndProcedure

#EndRegion

#Region PrintInterface

// Function generates tabular document of petty cash book cover.
//
Function PrintForm(ObjectsArray, PrintObjects, TemplateName)
	
	Template = PrintManagement.PrintedFormsTemplate("Document.SalesSlip.PF_MXL_SalesReceipt");
	
	Spreadsheet = New SpreadsheetDocument;
	Spreadsheet.PrintParametersName = "PRINT_PARAMETERS_Check_SaleInvoice";
	
	FirstDocument = True;
	
	For Each SalesSlip In ObjectsArray Do
		
		If Not FirstDocument Then
			Spreadsheet.PutHorizontalPageBreak();
		EndIf;
		FirstDocument = False;
		
		FirstLineNumber = Spreadsheet.TableHeight + 1;
		
		Query = New Query;
		Query.SetParameter("CurrentDocument", SalesSlip.Ref);
		
		Query.Text =
		"SELECT
		|	DocReceipt.Number AS Number,
		|	DocReceipt.Date AS Date,
		|	DocReceipt.CashCR AS CashCR,
		|	DocReceipt.DocumentCurrency AS Currency,
		|	DocReceipt.CashCR.Presentation AS Customer,
		|	DocReceipt.Company AS Company,
		|	DocReceipt.Company.Prefix AS Prefix,
		|	DocReceipt.Company.Presentation AS Vendor,
		|	DocReceipt.DocumentAmount AS DocumentAmount,
		|	DocReceipt.AmountIncludesVAT AS AmountIncludesVAT,
		|	DocReceipt.Responsible.Ind AS Responsible,
		|	DocReceipt.Inventory.(
		|		LineNumber AS LineNumber,
		|		Products AS Products,
		|		Products.Presentation AS InventoryItem,
		|		Products.DescriptionFull AS InventoryFullDescr,
		|		Products.Code AS Code,
		|		Products.SKU AS SKU,
		|		Characteristic AS Characteristic,
		|		Quantity AS Quantity,
		|		MeasurementUnit AS MeasurementUnit,
		|		Price AS Price,
		|		Amount AS Amount,
		|		VATAmount AS VATAmount,
		|		Total AS Total,
		|		ConnectionKey,
		|		DiscountMarkupPercent,
		|		CASE
		|			WHEN DocReceipt.Inventory.DiscountMarkupPercent <> 0
		|					OR DocReceipt.Inventory.AutomaticDiscountAmount <> 0
		|				THEN 1
		|			ELSE 0
		|		END AS IsDiscount,
		|		AutomaticDiscountAmount
		|	),
		|	DocReceipt.SerialNumbers.(
		|		SerialNumber,
		|		ConnectionKey
		|	)
		|FROM
		|	Document.SalesSlip AS DocReceipt
		|WHERE
		|	DocReceipt.Ref = &CurrentDocument";
		
		Header = Query.Execute().Select();
		Header.Next();
		
		InfoAboutCompany = DriveServer.InfoAboutLegalEntityIndividual(Header.Company, Header.Date, ,);
		
		If Header.Date < Date('20110101') Then
			DocumentNumber = DriveServer.GetNumberForPrinting(Header.Number, Header.Prefix);
		Else
			DocumentNumber = ObjectPrefixationClientServer.GetNumberForPrinting(Header.Number, True, True);
		EndIf;
		
		// Output invoice header.
		TemplateArea = Template.GetArea("Title");
		TemplateArea.Parameters.HeaderText = "Sales receipt No "
									+ DocumentNumber
									+ " from "
									+ Format(Header.Date, "DLF=DD");
		
		Spreadsheet.Put(TemplateArea);
		
		TemplateArea = Template.GetArea("Vendor");
		VendorPresentation = DriveServer.CompaniesDescriptionFull(InfoAboutCompany, "FullDescr,TIN,LegalAddress,PhoneNumbers,");
		TemplateArea.Parameters.VendorPresentation = VendorPresentation;
		TemplateArea.Parameters.Vendor = Header.Company;
		Spreadsheet.Put(TemplateArea);
		
		AreDiscounts = Header.Inventory.Unload().Total("IsDiscount") <> 0;
		
		NumberArea = Template.GetArea("TableHeader|LineNumber");
		DataArea = Template.GetArea("TableHeader|Data");
		DiscountsArea = Template.GetArea("TableHeader|Discount");
		AmountArea  = Template.GetArea("TableHeader|Amount");
		
		Spreadsheet.Put(NumberArea);
		
		Spreadsheet.Join(DataArea);
		If AreDiscounts Then
			Spreadsheet.Join(DiscountsArea);
		EndIf;
		Spreadsheet.Join(AmountArea);
		
		AreaColumnInventory = Template.Area("InventoryItem");
		
		If Not AreDiscounts Then
			AreaColumnInventory.ColumnWidth =
				AreaColumnInventory.ColumnWidth
			  + Template.Area("AmountWithoutDiscount").ColumnWidth
			  + Template.Area("DiscountAmount").ColumnWidth;
		EndIf;
		
		NumberArea = Template.GetArea("String|LineNumber");
		DataArea = Template.GetArea("String|Data");
		DiscountsArea = Template.GetArea("String|Discount");
		AmountArea  = Template.GetArea("String|Amount");
		
		Amount			= 0;
		VATAmount		= 0;
		Total			= 0;
		TotalDiscounts		= 0;
		TotalWithoutDiscounts	= 0;
		
		LinesSelectionInventory = Header.Inventory.Select();
		LinesSelectionSerialNumbers = Header.SerialNumbers.Select();
		
		While LinesSelectionInventory.Next() Do
			
			If Not ValueIsFilled(LinesSelectionInventory.Products) Then
				CommonUseClientServer.MessageToUser(
					NStr("en = 'Products value is not filled in in one of the rows - String during printing is skipped.'"));
				Continue;
			EndIf;
			
			NumberArea.Parameters.Fill(LinesSelectionInventory);
			Spreadsheet.Put(NumberArea);
			
			DataArea.Parameters.Fill(LinesSelectionInventory);
			StringSerialNumbers = WorkWithSerialNumbers.SerialNumbersStringFromSelection(LinesSelectionSerialNumbers, LinesSelectionInventory.ConnectionKey);
			DataArea.Parameters.InventoryItem = DriveServer.GetProductsPresentationForPrinting(
				LinesSelectionInventory.InventoryItem, LinesSelectionInventory.Characteristic, LinesSelectionInventory.SKU, StringSerialNumbers);
			
			Spreadsheet.Join(DataArea);
			
			Discount = 0;
			
			If AreDiscounts Then
				If LinesSelectionInventory.DiscountMarkupPercent = 100 Then
					Discount = LinesSelectionInventory.Price * LinesSelectionInventory.Quantity;
					DiscountsArea.Parameters.Discount = Discount;
					DiscountsArea.Parameters.AmountWithoutDiscount = Discount;
				ElsIf LinesSelectionInventory.DiscountMarkupPercent = 0 AND LinesSelectionInventory.AutomaticDiscountAmount = 0 Then
					DiscountsArea.Parameters.Discount = 0;
					DiscountsArea.Parameters.AmountWithoutDiscount = LinesSelectionInventory.Amount;
				Else
					Discount = LinesSelectionInventory.Quantity * LinesSelectionInventory.Price - LinesSelectionInventory.Amount; // AutomaticDiscounts
					DiscountsArea.Parameters.Discount = Discount;
					DiscountsArea.Parameters.AmountWithoutDiscount = LinesSelectionInventory.Amount + Discount;
				EndIf;
				Spreadsheet.Join(DiscountsArea);
			EndIf;
			
			AmountArea.Parameters.Fill(LinesSelectionInventory);
			Spreadsheet.Join(AmountArea);
			
			Amount			= Amount			+ LinesSelectionInventory.Amount;
			VATAmount		= VATAmount		+ LinesSelectionInventory.VATAmount;
			Total			= Total			+ LinesSelectionInventory.Total;
			TotalDiscounts		= TotalDiscounts	+ Discount;
			TotalWithoutDiscounts	= Amount			+ TotalDiscounts;
			
		EndDo;
		
		// Output Total.
		FillStructureSection = New Structure;
		FillStructureSection.Insert("TitleVAT", ?(Header.AmountIncludesVAT, "Including VAT:", "VAT Amount:"));
		
		NumberArea = Template.GetArea("Total|LineNumber");
		DataArea = Template.GetArea("Total|Data");
		DiscountsArea = Template.GetArea("Total|Discount");
		AmountArea  = Template.GetArea("Total|Amount");
		
		Spreadsheet.Put(NumberArea);
		
		DataArea.Parameters.Fill(FillStructureSection);
		Spreadsheet.Join(DataArea);
		
		If AreDiscounts Then
			
			FillStructureSection.Insert("TotalDiscounts", TotalDiscounts);
			FillStructureSection.Insert("TotalWithoutDiscounts", TotalWithoutDiscounts);
			
			DiscountsArea.Parameters.Fill(FillStructureSection);
			Spreadsheet.Join(DiscountsArea);
			
		EndIf;
		
		FillStructureSection.Insert("Amount", Amount);
		FillStructureSection.Insert("VATAmount", VATAmount);
		FillStructureSection.Insert("Total", Total);
		
		AmountArea.Parameters.Fill(FillStructureSection);
		Spreadsheet.Join(AmountArea);
		
		// Output amount in writing.
		TemplateArea = Template.GetArea("AmountInWords");
		AmountToBeWrittenInWords = Total;
		TemplateArea.Parameters.TotalRow = "Total titles "
										+ String(LinesSelectionInventory.Count())
										+ ", in the amount of "
										+ DriveServer.AmountsFormat(AmountToBeWrittenInWords, Header.Currency);
		
		TemplateArea.Parameters.AmountInWords = WorkWithExchangeRates.GenerateAmountInWords(AmountToBeWrittenInWords, Header.Currency);
		
		Spreadsheet.Put(TemplateArea);
		
		// Output signatures.
		TemplateArea = Template.GetArea("Signatures");
		
		If ValueIsFilled(Header.Responsible) Then
			
			ResponsibleData = DriveServer.IndData(
				DriveServer.GetCompany(Header.Company),
				Header.Responsible, 
				Header.Date);
			
			TemplateArea.Parameters.ResponsiblePosition		= ResponsibleData.Position;
			TemplateArea.Parameters.ResponsibleDetails	= ResponsibleData.Presentation;
			
		EndIf;
		
		TemplateArea.Parameters.Fill(Header);
		Spreadsheet.Put(TemplateArea);
		
		PrintManagement.SetDocumentPrintArea(Spreadsheet, FirstLineNumber, PrintObjects, SalesSlip);
		
	EndDo;
	
	Spreadsheet.FitToPage = True;
	
	Return Spreadsheet;
	
EndFunction

// Document printing procedure.
//
Procedure Print(ObjectsArray, PrintParameters, PrintFormsCollection, PrintObjects, OutputParameters) Export
	
	If PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "SalesReceipt") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection, "SalesReceipt", "Sales receipt", PrintForm(ObjectsArray, PrintObjects, "Sales receipt"));
		
	EndIf;
	
	If PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "SimplifiedTaxInvoice") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection, "SimplifiedTaxInvoice", "Simplified tax invoice", DataProcessors.PrintSimplifiedTaxInvoice.PrintForm(ObjectsArray, PrintObjects, "SimplifiedTaxInvoice"));
		
	EndIf;
	
	If PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "GuaranteeCard") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection, "GuaranteeCard", "Guarantee card", 
			WorkWithProductsServer.PrintGuaranteeCard(ObjectsArray, PrintObjects));
		
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
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID = "SalesReceipt";
	PrintCommand.Presentation = NStr("en = 'Receipt'");
	PrintCommand.FormsList = "DocumentForm,ListForm,DocumentForm_CWP";
	PrintCommand.CheckPostingBeforePrint = False;
	PrintCommand.Order = 1;
	
	If GetFunctionalOption("UseVAT") Then
		PrintCommand = PrintCommands.Add();
		PrintCommand.ID = "SimplifiedTaxInvoice";
		PrintCommand.Presentation = NStr("en = 'Tax invoice'");
		PrintCommand.FormsList = "DocumentForm,ListForm,DocumentForm_CWP";
		PrintCommand.CheckPostingBeforePrint = False;
		PrintCommand.Order = 2;
	EndIf;
	
	If GetFunctionalOption("UseSerialNumbers") Then
		PrintCommand = PrintCommands.Add();
		PrintCommand.ID = "GuaranteeCard";
		PrintCommand.Presentation = NStr("en = 'Warranty card'");
		PrintCommand.FormsList = "DocumentForm,ListForm,DocumentForm_CWP";
		PrintCommand.CheckPostingBeforePrint = True;
		PrintCommand.Order = 3;
	EndIf;
	
EndProcedure

#EndRegion

#Region WorkWithSerialNumbers

// Generates a table of values that contains the data for the SerialNumbersInWarranty information register.
// Tables of values saves into the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableSerialNumbers(DocumentRef, StructureAdditionalProperties)
	
	If DocumentRef.SerialNumbers.Count()=0 Then
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbersBalance", New ValueTable);
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbersInWarranty", New ValueTable);
		Return;
	EndIf;
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	TemporaryTableInventory.Date AS Period,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TemporaryTableInventory.Date AS EventDate,
	|	VALUE(Enum.SerialNumbersOperations.Expense) AS Operation,
	|	SerialNumbers.SerialNumber AS SerialNumber,
	|	TemporaryTableInventory.Company AS Company,
	|	TemporaryTableInventory.Products AS Products,
	|	TemporaryTableInventory.Characteristic AS Characteristic,
	|	TemporaryTableInventory.Batch AS Batch,
	|	TemporaryTableInventory.StructuralUnit AS StructuralUnit,
	|	TemporaryTableInventory.Cell AS Cell,
	|	1 AS Quantity
	|FROM
	|	TemporaryTableInventory AS TemporaryTableInventory
	|		INNER JOIN TemporaryTableSerialNumbers AS SerialNumbers
	|		ON TemporaryTableInventory.ConnectionKey = SerialNumbers.ConnectionKey
	|			AND (&CheckIssued)
	|			AND (NOT &Archival)";
	Query.SetParameter("CheckIssued", StructureAdditionalProperties.ForPosting.CheckIssued);
	Query.SetParameter("Archival", StructureAdditionalProperties.ForPosting.Archival);
	
	QueryResult = Query.Execute().Unload();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbersInWarranty", QueryResult);
	If StructureAdditionalProperties.AccountingPolicy.SerialNumbersBalance Then
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbersBalance", QueryResult);
	Else
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbersBalance", New ValueTable);
	EndIf; 
	
EndProcedure

#EndRegion

#Region InfoBaseUpdate

Procedure FillNewGLAccounts() Export
	
	DocumentName = "SalesSlip";
	
	Tables = New Array();
	TableDecription = New Structure("Name, Conditions", "Inventory", New Array());
	
	GLAccountFields = ChartsOfAccounts.PrimaryChartOfAccounts.GLAccountFields();
	GLAccountFields.Source = "Products.BusinessLine.GLAccountRevenueFromSales";
	GLAccountFields.Receiver = "RevenueGLAccount";
	TableDecription.Conditions.Add(GLAccountFields);
	
	GLAccountFields = ChartsOfAccounts.PrimaryChartOfAccounts.GLAccountFields();
	GLAccountFields.Source = "&VATOutputGLAccount";
	GLAccountFields.Receiver = "VATOutputGLAccount";
	GLAccountFields.Parameter = Catalogs.DefaultGLAccounts.GetDefaultGLAccount("VATOutput");
	TableDecription.Conditions.Add(GLAccountFields);
	
	Tables.Add(TableDecription);
	
	ChartsOfAccounts.PrimaryChartOfAccounts.FillNewGLAccounts(DocumentName, Tables);
	
EndProcedure

#EndRegion

#EndIf