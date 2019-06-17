#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTablePurchases(DocumentRefDebitNote, StructureAdditionalProperties)
	
    Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	TablePurchases.Period AS Period,
	|	TablePurchases.Recorder AS Recorder,
	|	TablePurchases.Products AS Products,
	|	TablePurchases.Characteristic AS Characteristic,
	|	TablePurchases.Batch AS Batch,
	|	TablePurchases.BasisDocument AS Document,
	|	TablePurchases.Company AS Company,
	|	TablePurchases.Order AS PurchaseOrder,
	|	TablePurchases.Department AS Department,
	|	-TablePurchases.ReturnQuantity AS Quantity,
	|	-TablePurchases.AdjustmentAmount AS Amount,
	|	TablePurchases.VATRate AS VATRate,
	|	-TablePurchases.VATAmount AS VATAmount,
	|	TablePurchases.Responsible AS Responsible
	|FROM
	|	TemporaryTableInventory AS TablePurchases";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TablePurchases", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableAccountsPayable(DocumentRefDebitNote, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.SetParameter("Ref",					DocumentRefDebitNote);
	Query.SetParameter("PointInTime",			New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod",			StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("ExchangeDifference",	NStr("en = 'Foreign currency exchange gains and losses'",
													CommonUseClientServer.MainLanguageCode()));
	
	Query.Text =
	"SELECT
	|	TableAccountsPayable.Period AS Date,
	|	TableAccountsPayable.LineNumber AS LineNumber,
	|	TableAccountsPayable.Recorder AS Recorder,
	|	TableAccountsPayable.Company AS Company,
	|	CASE
	|		WHEN TableAccountsPayable.AdvanceFlag
	|			THEN VALUE(Enum.SettlementsTypes.Advance)
	|		ELSE VALUE(Enum.SettlementsTypes.Debt)
	|	END AS SettlementsType,
	|	TableAccountsPayable.Counterparty AS Counterparty,
	|	TableAccountsPayable.Contract AS Contract,
	|	TableAccountsPayable.Currency AS Currency,
	|	TableAccountsPayable.Document AS Document,
	|	TableAccountsPayable.Order AS Order,
	|	CASE
	|		WHEN TableAccountsPayable.AdvanceFlag
	|			THEN TableAccountsPayable.CustomerAdvancesGLAccount
	|		ELSE TableAccountsPayable.GLAccountVendorSettlements
	|	END AS GLAccount,
	|	TableAccountsPayable.OffsetAmount AS PaymentAmount,
	|	TableAccountsPayable.Amount AS Amount,
	|	TableAccountsPayable.OffsetAmount AS AmountCur,
	|	-TableAccountsPayable.Amount AS AmountForBalance,
	|	-TableAccountsPayable.OffsetAmount AS AmountCurForBalance,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableAccountsPayable.OperationKind AS ContentOfAccountingRecord,
	|	TableAccountsPayable.Amount AS AmountForPayment,
	|	TableAccountsPayable.OffsetAmount AS AmountForPaymentCur
	|INTO TemporaryTableAccountsPayable
	|FROM
	|	TemporaryTableAmountAllocation AS TableAccountsPayable";
	
	QueryResult = Query.Execute();
	
	QueryNumber = 0;
	Query.Text = DriveServer.GetQueryTextExchangeRatesDifferencesAccountsPayable(Query.TempTablesManager, False, QueryNumber);
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountsPayable", ResultsArray[QueryNumber].Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableIncomeAndExpenses(DocumentRefDebitNote, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.SetParameter("Ref", 											DocumentRefDebitNote);
	Query.SetParameter("PositiveExchangeDifferenceGLAccount",			Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeGain"));
	Query.SetParameter("NegativeExchangeDifferenceAccountOfAccounting", Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeLoss"));
	Query.SetParameter("ExchangeDifference",							NStr("en = 'Foreign currency exchange gains and losses'",
																			CommonUseClientServer.MainLanguageCode()));
	Query.Text =
	"SELECT
	|	TableIncomeAndExpenses.Period AS Period,
	|	TableIncomeAndExpenses.Recorder AS Recorder,
	|	TableIncomeAndExpenses.Company AS Company,
	|	TableIncomeAndExpenses.Department AS StructuralUnit,
	|	TableIncomeAndExpenses.BusinessLine AS BusinessLine,
	|	TableIncomeAndExpenses.GLAccount AS GLAccount,
	|	TableIncomeAndExpenses.AdjustmentAmount AS AmountIncome,
	|	0 AS AmountExpense,
	|	TableIncomeAndExpenses.OperationKind AS ContentOfAccountingRecord
	|INTO TableIncomeAndExpenses
	|FROM
	|	TemporaryTableInventory AS TableIncomeAndExpenses
	|
	|UNION ALL
	|
	|SELECT
	|	TemporaryTableHeader.Period,
	|	TemporaryTableHeader.Recorder,
	|	TemporaryTableHeader.Company,
	|	TemporaryTableHeader.Department,
	|	TemporaryTableHeader.BusinessLine,
	|	TemporaryTableHeader.GLAccount,
	|	TemporaryTableHeader.Amount,
	|	0,
	|	TemporaryTableHeader.OperationKind
	|FROM
	|	TemporaryTableHeader AS TemporaryTableHeader
	|WHERE
	|	(TemporaryTableHeader.OperationKind = VALUE(Enum.OperationTypesDebitNote.Adjustments)
	|			OR TemporaryTableHeader.OperationKind = VALUE(Enum.OperationTypesDebitNote.DiscountReceived))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DocumentTable.Date AS Date,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.AmountOfExchangeDifferences AS AmountOfExchangeDifferences
	|INTO TableExchangeRateDifferencesAccountsPayable
	|FROM
	|	TemporaryTableOfExchangeRateDifferencesAccountsPayable AS DocumentTable
	|WHERE
	|	DocumentTable.SettlementsType = VALUE(Enum.SettlementsTypes.Debt)
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	DocumentTable.AmountOfExchangeDifferences
	|FROM
	|	TemporaryTableOfExchangeRateDifferencesAccountsPayable AS DocumentTable
	|WHERE
	|	DocumentTable.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableExchangeRateDifferencesAccountsPayable.Date AS Date,
	|	TableExchangeRateDifferencesAccountsPayable.Company AS Company,
	|	&Ref AS Ref,
	|	SUM(TableExchangeRateDifferencesAccountsPayable.AmountOfExchangeDifferences) AS AmountOfExchangeDifferences
	|INTO GroupedTableExchangeRateDifferencesAccountsPayable
	|FROM
	|	TableExchangeRateDifferencesAccountsPayable AS TableExchangeRateDifferencesAccountsPayable
	|
	|GROUP BY
	|	TableExchangeRateDifferencesAccountsPayable.Date,
	|	TableExchangeRateDifferencesAccountsPayable.Company
	|
	|HAVING
	|	(SUM(TableExchangeRateDifferencesAccountsPayable.AmountOfExchangeDifferences) >= 0.005
	|		OR SUM(TableExchangeRateDifferencesAccountsPayable.AmountOfExchangeDifferences) <= -0.005)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableIncomeAndExpenses.Period AS Period,
	|	TableIncomeAndExpenses.Recorder AS Recorder,
	|	TableIncomeAndExpenses.Company AS Company,
	|	TableIncomeAndExpenses.StructuralUnit AS StructuralUnit,
	|	TableIncomeAndExpenses.BusinessLine AS BusinessLine,
	|	UNDEFINED AS SalesOrder,
	|	TableIncomeAndExpenses.GLAccount AS GLAccount,
	|	SUM(TableIncomeAndExpenses.AmountIncome) AS AmountIncome,
	|	SUM(TableIncomeAndExpenses.AmountExpense) AS AmountExpense,
	|	TableIncomeAndExpenses.ContentOfAccountingRecord AS ContentOfAccountingRecord,
	|	FALSE AS OfflineRecord
	|FROM
	|	TableIncomeAndExpenses AS TableIncomeAndExpenses
	|
	|GROUP BY
	|	TableIncomeAndExpenses.Company,
	|	TableIncomeAndExpenses.StructuralUnit,
	|	TableIncomeAndExpenses.Recorder,
	|	TableIncomeAndExpenses.GLAccount,
	|	TableIncomeAndExpenses.ContentOfAccountingRecord,
	|	TableIncomeAndExpenses.BusinessLine,
	|	TableIncomeAndExpenses.Period
	|
	|UNION ALL
	|
	|SELECT
	|	GroupedTableExchangeRateDifferencesAccountsPayable.Date,
	|	GroupedTableExchangeRateDifferencesAccountsPayable.Ref,
	|	GroupedTableExchangeRateDifferencesAccountsPayable.Company,
	|	TableDocument.Department,
	|	TableDocument.BusinessLine,
	|	UNDEFINED,
	|	CASE
	|		WHEN GroupedTableExchangeRateDifferencesAccountsPayable.AmountOfExchangeDifferences > 0
	|			THEN &NegativeExchangeDifferenceAccountOfAccounting
	|		ELSE &PositiveExchangeDifferenceGLAccount
	|	END,
	|	CASE
	|		WHEN GroupedTableExchangeRateDifferencesAccountsPayable.AmountOfExchangeDifferences > 0
	|			THEN 0
	|		ELSE -GroupedTableExchangeRateDifferencesAccountsPayable.AmountOfExchangeDifferences
	|	END,
	|	CASE
	|		WHEN GroupedTableExchangeRateDifferencesAccountsPayable.AmountOfExchangeDifferences > 0
	|			THEN GroupedTableExchangeRateDifferencesAccountsPayable.AmountOfExchangeDifferences
	|		ELSE 0
	|	END,
	|	&ExchangeDifference,
	|	FALSE
	|FROM
	|	GroupedTableExchangeRateDifferencesAccountsPayable AS GroupedTableExchangeRateDifferencesAccountsPayable
	|		INNER JOIN TemporaryTableHeader AS TableDocument
	|		ON (TableDocument.Recorder = GroupedTableExchangeRateDifferencesAccountsPayable.Ref)
	|
	|UNION ALL
	|
	|SELECT
	|	OfflineRecords.Period,
	|	OfflineRecords.Recorder,
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
	|	AND OfflineRecords.OfflineRecord
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP TableIncomeAndExpenses
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP TableExchangeRateDifferencesAccountsPayable";
	
	Query.SetParameter("Content", NStr("en = 'Goods return'", CommonUseClientServer.MainLanguageCode()));
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpenses", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableAccountingJournalEntries(DocumentRefDebitNote, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.SetParameter("ForeignCurrencyExchangeGain",	Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeGain"));
	Query.SetParameter("ForeignCurrencyExchangeLoss",	Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeLoss"));
	Query.SetParameter("ExchangeDifference",			NStr("en = 'Foreign currency exchange gains and losses'",
															CommonUseClientServer.MainLanguageCode()));
	Query.SetParameter("Ref",							DocumentRefDebitNote);
	
	Query.Text =
	"SELECT
	|	TableAccountingJournalEntries.Period AS Period,
	|	TableAccountingJournalEntries.Recorder AS Recorder,
	|	TableAccountingJournalEntries.Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	TableAccountingJournalEntries.GLAccountVendorSettlements AS AccountDr,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccountVendorSettlements.Currency
	|			THEN TableAccountingJournalEntries.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccountVendorSettlements.Currency
	|			THEN TableAccountingJournalEntries.AmountCur
	|		ELSE 0
	|	END AS AmountCurDr,
	|	CASE
	|		WHEN TableAccountingJournalEntries.OperationKind = VALUE(Enum.OperationTypesDebitNote.PurchaseReturn)
	|			THEN TemporaryTableInventory.GLAccount
	|		ELSE TableAccountingJournalEntries.GLAccount
	|	END AS AccountCr,
	|	CASE
	|		WHEN TableAccountingJournalEntries.OperationKind = VALUE(Enum.OperationTypesDebitNote.PurchaseReturn)
	|					AND TemporaryTableInventory.GLAccount.Currency
	|				OR TableAccountingJournalEntries.GLAccount.Currency
	|			THEN TableAccountingJournalEntries.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	CASE
	|		WHEN TableAccountingJournalEntries.OperationKind = VALUE(Enum.OperationTypesDebitNote.PurchaseReturn)
	|				AND TemporaryTableInventory.GLAccount.Currency
	|			THEN TemporaryTableInventory.AmountCur
	|		WHEN TableAccountingJournalEntries.GLAccount.Currency
	|			THEN TableAccountingJournalEntries.AmountCur
	|		ELSE 0
	|	END AS AmountCurCr,
	|	CASE
	|		WHEN TableAccountingJournalEntries.OperationKind = VALUE(Enum.OperationTypesDebitNote.PurchaseReturn)
	|			THEN TemporaryTableInventory.AdjustmentAmount
	|		ELSE TableAccountingJournalEntries.Amount
	|	END AS Amount,
	|	TableAccountingJournalEntries.OperationKind AS Content,
	|	FALSE AS OfflineRecord
	|INTO UngroupedTable
	|FROM
	|	TemporaryTableHeader AS TableAccountingJournalEntries
	|		LEFT JOIN TemporaryTableInventory AS TemporaryTableInventory
	|		ON TableAccountingJournalEntries.Recorder = TemporaryTableInventory.Recorder
	|
	|UNION ALL
	|
	|SELECT
	|	TableAccountingJournalEntries.Period,
	|	TableAccountingJournalEntries.Recorder,
	|	TableAccountingJournalEntries.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	TableAccountingJournalEntries.GLAccountVendorSettlements,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccountVendorSettlements.Currency
	|			THEN TableAccountingJournalEntries.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccountVendorSettlements.Currency
	|			THEN TableAccountingJournalEntries.VATAmountCur
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN TableAccountingJournalEntries.OperationKind = VALUE(Enum.OperationTypesDebitNote.PurchaseReturn)
	|			THEN TemporaryTableInventory.VATInputGLAccount
	|		ELSE DefaultGLAccounts.GLAccount
	|	END,
	|	UNDEFINED,
	|	0,
	|	CASE
	|		WHEN TableAccountingJournalEntries.OperationKind = VALUE(Enum.OperationTypesDebitNote.PurchaseReturn)
	|			THEN TemporaryTableInventory.VATAmount
	|		ELSE TableAccountingJournalEntries.VATAmount
	|	END,
	|	TableAccountingJournalEntries.OperationKind,
	|	FALSE
	|FROM
	|	TemporaryTableHeader AS TableAccountingJournalEntries
	|		LEFT JOIN TemporaryTableInventory AS TemporaryTableInventory
	|		ON TableAccountingJournalEntries.Recorder = TemporaryTableInventory.Recorder
	|		LEFT JOIN Catalog.DefaultGLAccounts AS DefaultGLAccounts
	|		ON (DefaultGLAccounts.Ref = VALUE(Catalog.DefaultGLAccounts.VATOutput))
	|WHERE
	|	TableAccountingJournalEntries.VATTaxation <> VALUE(Enum.VATTaxationTypes.NotSubjectToVAT)
	|	AND TableAccountingJournalEntries.VATAmount <> 0
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
	|	AND OfflineRecords.OfflineRecord
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	UngroupedTable.Period AS Period,
	|	UngroupedTable.Recorder AS Recorder,
	|	UngroupedTable.Company AS Company,
	|	UngroupedTable.PlanningPeriod AS PlanningPeriod,
	|	UngroupedTable.AccountDr AS AccountDr,
	|	UngroupedTable.CurrencyDr AS CurrencyDr,
	|	SUM(UngroupedTable.AmountCurDr) AS AmountCurDr,
	|	UngroupedTable.AccountCr AS AccountCr,
	|	UngroupedTable.CurrencyCr AS CurrencyCr,
	|	SUM(UngroupedTable.AmountCurCr) AS AmountCurCr,
	|	SUM(UngroupedTable.Amount) AS Amount,
	|	UngroupedTable.Content AS Content,
	|	UngroupedTable.OfflineRecord AS OfflineRecord
	|FROM
	|	UngroupedTable AS UngroupedTable
	|
	|GROUP BY
	|	UngroupedTable.Recorder,
	|	UngroupedTable.Company,
	|	UngroupedTable.AccountDr,
	|	UngroupedTable.CurrencyCr,
	|	UngroupedTable.OfflineRecord,
	|	UngroupedTable.Content,
	|	UngroupedTable.CurrencyDr,
	|	UngroupedTable.AccountCr,
	|	UngroupedTable.Period,
	|	UngroupedTable.PlanningPeriod";
	
	If DocumentRefDebitNote.OperationKind = Enums.OperationTypesDebitNote.PurchaseReturn 
		AND Not StructureAdditionalProperties.AccountingPolicy.UseGoodsReturnToSupplier Then
		
		Query.Text = Query.Text + DriveClientServer.GetQueryUnion() + 
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
		|	TableAccountingJournalEntries.OperationKind AS Content,
		|	FALSE
		|FROM
		|	TemporaryTableInventory AS TableAccountingJournalEntries
		|WHERE
		|	TableAccountingJournalEntries.ThisIsInventoryItem
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
		|	TableAccountingJournalEntries.InventoryGLAccount,
		|	TableAccountingJournalEntries.OperationKind";
		
	EndIf;
	
	//Exchange rate differences	
	Query.Text = Query.Text + DriveClientServer.GetQueryUnion() + 
	"SELECT
	|	GroupedTableExchangeRateDifferencesAccountsPayable.Date AS Period,
	|	GroupedTableExchangeRateDifferencesAccountsPayable.Ref AS Recorder,
	|	GroupedTableExchangeRateDifferencesAccountsPayable.Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	CASE
	|		WHEN GroupedTableExchangeRateDifferencesAccountsPayable.AmountOfExchangeDifferences > 0
	|			THEN &ForeignCurrencyExchangeLoss
	|		ELSE TableDocument.GLAccountVendorSettlements
	|	END AS AccountDr,
	|	CASE
	|		WHEN GroupedTableExchangeRateDifferencesAccountsPayable.AmountOfExchangeDifferences < 0
	|				AND TableDocument.GLAccountVendorSettlementsCurrency
	|			THEN TableDocument.DocumentCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	0 AS AmountCurDr,
	|	CASE
	|		WHEN GroupedTableExchangeRateDifferencesAccountsPayable.AmountOfExchangeDifferences > 0
	|			THEN TableDocument.GLAccountVendorSettlements
	|		ELSE &ForeignCurrencyExchangeGain
	|	END AS AccountCr,
	|	CASE
	|		WHEN GroupedTableExchangeRateDifferencesAccountsPayable.AmountOfExchangeDifferences > 0
	|				AND TableDocument.GLAccountVendorSettlementsCurrency
	|			THEN TableDocument.DocumentCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	0 AS AmountCurCr,
	|	CASE
	|		WHEN GroupedTableExchangeRateDifferencesAccountsPayable.AmountOfExchangeDifferences > 0
	|			THEN GroupedTableExchangeRateDifferencesAccountsPayable.AmountOfExchangeDifferences
	|		ELSE -GroupedTableExchangeRateDifferencesAccountsPayable.AmountOfExchangeDifferences
	|	END AS Amount,
	|	&ExchangeDifference AS ExchangeDifference,
	|	FALSE AS OfflineRecord
	|FROM
	|	GroupedTableExchangeRateDifferencesAccountsPayable AS GroupedTableExchangeRateDifferencesAccountsPayable
	|		INNER JOIN TemporaryTableHeader AS TableDocument
	|		ON (TableDocument.Recorder = GroupedTableExchangeRateDifferencesAccountsPayable.Ref)";

	QueryResult = Query.Execute();
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountingJournalEntries", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventoryInWarehouses(DocumentRefDebitNote, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	TableInventoryInWarehouses.Period AS Period,
	|	TableInventoryInWarehouses.Recorder AS Recorder,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableInventoryInWarehouses.Company AS Company,
	|	TableInventoryInWarehouses.StructuralUnit AS StructuralUnit,
	|	TableInventoryInWarehouses.Products AS Products,
	|	TableInventoryInWarehouses.Characteristic AS Characteristic,
	|	TableInventoryInWarehouses.Batch AS Batch,
	|	TableInventoryInWarehouses.Cell AS Cell,
	|	TableInventoryInWarehouses.ReturnQuantity AS Quantity
	|FROM
	|	TemporaryTableInventory AS TableInventoryInWarehouses
	|WHERE
	|	TableInventoryInWarehouses.ThisIsInventoryItem";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryInWarehouses", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventory(DocumentRefDebitNote, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	FillAmount = StructureAdditionalProperties.AccountingPolicy.InventoryValuationMethod = Enums.InventoryValuationMethods.WeightedAverage;
	Query.SetParameter("FillAmount", FillAmount);
	
	Query.Text =
	"SELECT
	|	TableInventory.Period AS Period,
	|	TableInventory.Recorder AS Recorder,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableInventory.Company AS Company,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	TableInventory.BusinessLine AS BusinessLine,
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.InventoryGLAccount AS GLAccount,
	|	TableInventory.ReturnQuantity AS Quantity,
	|	CASE
	|		WHEN NOT &FillAmount
	|			THEN 0
	|		ELSE TableInventory.AdjustmentAmount
	|	END AS Amount,
	|	TableInventory.OperationKind AS ContentOfAccountingRecord,
	|	TableInventory.Department AS Department,
	|	TableInventory.Responsible AS Responsible,
	|	TableInventory.VATRate AS VATRate,
	|	TRUE AS Return,
	|	TableInventory.GLAccount AS AccountDr,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	TableInventory.BasisDocument AS SourceDocument,
	|	FALSE AS OfflineRecord
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|WHERE
	|	TableInventory.ThisIsInventoryItem
	|
	|UNION ALL
	|
	|SELECT
	|	OfflineRecords.Period,
	|	OfflineRecords.Recorder,
	|	OfflineRecords.RecordType,
	|	OfflineRecords.Company,
	|	OfflineRecords.StructuralUnit,
	|	UNDEFINED,
	|	OfflineRecords.Products,
	|	OfflineRecords.Characteristic,
	|	OfflineRecords.Batch,
	|	OfflineRecords.GLAccount,
	|	OfflineRecords.Quantity,
	|	OfflineRecords.Amount,
	|	OfflineRecords.ContentOfAccountingRecord,
	|	OfflineRecords.Department,
	|	OfflineRecords.Responsible,
	|	OfflineRecords.VATRate,
	|	OfflineRecords.Return,
	|	UNDEFINED,
	|	UNDEFINED,
	|	OfflineRecords.SourceDocument,
	|	OfflineRecords.OfflineRecord
	|FROM
	|	AccumulationRegister.Inventory AS OfflineRecords
	|WHERE
	|	OfflineRecords.Recorder = &Ref
	|	AND OfflineRecords.OfflineRecord";
	
	Query.SetParameter("Ref", DocumentRefDebitNote);
	
	Result = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventory", Result.Unload());
	
	If FillAmount Then
		FillAmountInInventoryTable(DocumentRefDebitNote, StructureAdditionalProperties);
	EndIf;
	
EndProcedure

Procedure FillAmountInInventoryTable(DocumentRefDebitNote, StructureAdditionalProperties)
	
	Query = New Query("
	|SELECT
	|	InventoryBalances.Company AS Company,
	|	InventoryBalances.StructuralUnit AS StructuralUnit,
	|	InventoryBalances.GLAccount AS GLAccount,
	|	InventoryBalances.Products AS Products,
	|	InventoryBalances.Characteristic AS Characteristic,
	|	InventoryBalances.Batch AS Batch,
	|	SUM(InventoryBalances.QuantityBalance) AS QuantityBalance,
	|	SUM(InventoryBalances.AmountBalance) AS AmountBalance
	|INTO InventoryBalances
	|FROM
	|	AccumulationRegister.Inventory.Balance(
	|			&ControlTime,
	|			(Company, StructuralUnit, GLAccount, Products, Characteristic, Batch, SalesOrder) IN
	|				(SELECT
	|					TableInventory.Company,
	|					TableInventory.StructuralUnit,
	|					TableInventory.InventoryGLAccount,
	|					TableInventory.Products,
	|					TableInventory.Characteristic,
	|					TableInventory.Batch,
	|					UNDEFINED AS SalesOrder
	|				FROM
	|					TemporaryTableInventory AS TableInventory)) AS InventoryBalances
	|
	|GROUP BY
	|	InventoryBalances.Company,
	|	InventoryBalances.StructuralUnit,
	|	InventoryBalances.GLAccount,
	|	InventoryBalances.Products,
	|	InventoryBalances.Characteristic,
	|	InventoryBalances.Batch
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentRegisterRecordsInventory.Company,
	|	DocumentRegisterRecordsInventory.StructuralUnit,
	|	DocumentRegisterRecordsInventory.GLAccount,
	|	DocumentRegisterRecordsInventory.Products,
	|	DocumentRegisterRecordsInventory.Characteristic,
	|	DocumentRegisterRecordsInventory.Batch,
	|	CASE
	|		WHEN DocumentRegisterRecordsInventory.RecordType = VALUE(AccumulationRecordType.Expense)
	|			THEN ISNULL(DocumentRegisterRecordsInventory.Quantity, 0)
	|		ELSE -ISNULL(DocumentRegisterRecordsInventory.Quantity, 0)
	|	END,
	|	CASE
	|		WHEN DocumentRegisterRecordsInventory.RecordType = VALUE(AccumulationRecordType.Expense)
	|			THEN ISNULL(DocumentRegisterRecordsInventory.Amount, 0)
	|		ELSE -ISNULL(DocumentRegisterRecordsInventory.Amount, 0)
	|	END
	|FROM
	|	AccumulationRegister.Inventory AS DocumentRegisterRecordsInventory
	|WHERE
	|	DocumentRegisterRecordsInventory.Recorder = &Ref
	|	AND DocumentRegisterRecordsInventory.Period <= &ControlPeriod
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	InventoryBalances.Company AS Company,
	|	InventoryBalances.StructuralUnit AS StructuralUnit,
	|	InventoryBalances.GLAccount AS GLAccount,
	|	InventoryBalances.Products AS Products,
	|	InventoryBalances.Characteristic AS Characteristic,
	|	InventoryBalances.Batch AS Batch,
	|	SUM(InventoryBalances.QuantityBalance) AS QuantityBalance,
	|	SUM(InventoryBalances.AmountBalance) AS AmountBalance
	|FROM
	|	InventoryBalances AS InventoryBalances
	|
	|GROUP BY
	|	InventoryBalances.Batch,
	|	InventoryBalances.Characteristic,
	|	InventoryBalances.Products,
	|	InventoryBalances.Company,
	|	InventoryBalances.StructuralUnit,
	|	InventoryBalances.GLAccount");
	
	PostingParemeters = StructureAdditionalProperties.ForPosting;
	Query.TempTablesManager = PostingParemeters.StructureTemporaryTables.TempTablesManager;
	Query.SetParameter("Ref", 			DocumentRefDebitNote);
	Query.SetParameter("ControlTime",	New Boundary(PostingParemeters.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod",	PostingParemeters.PointInTime.Date);
	
	Result = Query.Execute();
	
	// Receiving inventory balances by cost.
	TableInventoryBalances = Result.Unload();
	TableInventoryBalances.Indexes.Add("Company,StructuralUnit,GLAccount,Products,Characteristic,Batch");
	
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
		
		// Generate income and expenses register records.
		If Round(RowTableInventory.Amount, 2, 1) <> 0 Then
			RowTableIncomeAndExpenses = StructureAdditionalProperties.TableForRegisterRecords.TableIncomeAndExpenses.Add();
			FillPropertyValues(RowTableIncomeAndExpenses, RowTableInventory);
			RowTableIncomeAndExpenses.GLAccount = RowTableInventory.AccountDr;
			RowTableIncomeAndExpenses.AmountExpense = RowTableInventory.Amount;
			
		EndIf;
		
		// Generate postings.
		If Round(RowTableInventory.Amount, 2, 1) <> 0 Then
			RowTableAccountingJournalEntries = StructureAdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries.Add();
			FillPropertyValues(RowTableAccountingJournalEntries, RowTableInventory);
			RowTableAccountingJournalEntries.AccountCr = RowTableInventory.GLAccount;
			RowTableAccountingJournalEntries.Content = RowTableInventory.ContentOfAccountingRecord;
		EndIf;
		
	EndDo;

EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableSerialNumbers(DocumentRefDebitNote, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
    "SELECT
    |	TableSerialNumbersBalance.Period AS Period,
    |	VALUE(AccumulationRecordType.Expense) AS RecordType,
    |	TableSerialNumbersBalance.Period AS EventDate,
    |	TableSerialNumbersBalance.Company AS Company,
    |	VALUE(Enum.SerialNumbersOperations.Expense) AS Operation,
    |	TableSerialNumbersBalance.StructuralUnit AS StructuralUnit,
    |	TableSerialNumbersBalance.Products AS Products,
    |	TableSerialNumbersBalance.Characteristic AS Characteristic,
    |	TableSerialNumbersBalance.Batch AS Batch,
    |	TableSerialNumbersBalance.Cell AS Cell,
    |	DebitNoteSerialNumbers.SerialNumber AS SerialNumber,
    |	1 AS Quantity
    |FROM
    |	TemporaryTableInventory AS TableSerialNumbersBalance
    |		INNER JOIN Document.DebitNote.SerialNumbers AS DebitNoteSerialNumbers
    |		ON TableSerialNumbersBalance.Recorder = DebitNoteSerialNumbers.Ref
    |			AND TableSerialNumbersBalance.ConnectionKey = DebitNoteSerialNumbers.ConnectionKey
    |WHERE
    |	DebitNoteSerialNumbers.Ref = &Ref
    |	AND &UseSerialNumbers
    |	AND TableSerialNumbersBalance.ThisIsInventoryItem
    |	AND TableSerialNumbersBalance.Quantity > 0
    |
    |GROUP BY
    |	TableSerialNumbersBalance.StructuralUnit,
    |	TableSerialNumbersBalance.OperationKind,
    |	TableSerialNumbersBalance.Period,
    |	TableSerialNumbersBalance.Company,
    |	TableSerialNumbersBalance.Products,
    |	TableSerialNumbersBalance.Characteristic,
    |	TableSerialNumbersBalance.Batch,
    |	TableSerialNumbersBalance.Cell,
    |	DebitNoteSerialNumbers.SerialNumber,
    |	TableSerialNumbersBalance.Period";
	
	Query.SetParameter("Ref", 				DocumentRefDebitNote);
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

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Function GenerateTableVATInput(Query, DocumentRefDebitNote, StructureAdditionalProperties)
	
	If DocumentRefDebitNote.OperationKind = Enums.OperationTypesDebitNote.PurchaseReturn Then
		Query.Text = 
		"SELECT
		|	DebitNoteHeader.Date AS Period,
		|	DebitNoteHeader.Ref AS Recorder,
		|	&Company AS Company,
		|	DebitNoteHeader.Counterparty AS Supplier,
		|	DebitNoteInventory.VATRate AS VATRate,
		|	CASE
		|		WHEN DebitNoteHeader.BasisDocument REFS Document.SupplierInvoice
		|			THEN DebitNoteHeader.BasisDocument
		|		ELSE CAST(DebitNoteHeader.BasisDocument AS Document.GoodsReturn).SupplierInvoice
		|	END AS ShipmentDocument,
		|	VALUE(Enum.VATOperationTypes.PurchasesReturn) AS OperationType,
		|	CatalogProducts.ProductsType AS ProductType,
		|	SUM(-(CAST(CASE
		|				WHEN DebitNoteHeader.DocumentCurrency = &PresentationCurrency
		|					THEN DebitNoteInventory.Amount * ManagExchangeRates.ExchangeRate * RegExchangeRates.Multiplicity / (RegExchangeRates.ExchangeRate * ManagExchangeRates.Multiplicity)
		|				ELSE DebitNoteInventory.Amount * DebitNoteHeader.ExchangeRate * RegExchangeRates.Multiplicity / (RegExchangeRates.ExchangeRate * DebitNoteHeader.Multiplicity)
		|			END AS NUMBER(15, 2)))) AS AmountExcludesVAT,
		|	SUM(-(CAST(CASE
		|				WHEN DebitNoteHeader.DocumentCurrency = &PresentationCurrency
		|					THEN DebitNoteInventory.VATAmount * ManagExchangeRates.ExchangeRate * RegExchangeRates.Multiplicity / (RegExchangeRates.ExchangeRate * ManagExchangeRates.Multiplicity)
		|				ELSE DebitNoteInventory.VATAmount * DebitNoteHeader.ExchangeRate * RegExchangeRates.Multiplicity / (RegExchangeRates.ExchangeRate * DebitNoteHeader.Multiplicity)
		|			END AS NUMBER(15, 2)))) AS VATAmount
		|FROM
		|	TemporaryTableDocument AS DebitNoteHeader
		|		INNER JOIN TemporaryTableDocInventory AS DebitNoteInventory
		|		ON DebitNoteHeader.Ref = DebitNoteInventory.Ref
		|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS ManagExchangeRates
		|		ON (ManagExchangeRates.Currency = &PresentationCurrency)
		|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS RegExchangeRates
		|		ON (RegExchangeRates.Currency = &CurrencyNational)
		|		LEFT JOIN Catalog.Products AS CatalogProducts
		|		ON (DebitNoteInventory.Products = CatalogProducts.Ref)
		|WHERE
		|	NOT DebitNoteInventory.VATRate.NotTaxable
		|
		|GROUP BY
		|	DebitNoteInventory.VATRate,
		|	CatalogProducts.ProductsType,
		|	DebitNoteHeader.Ref,
		|	DebitNoteHeader.Date,
		|	DebitNoteHeader.Counterparty,
		|	CASE
		|		WHEN DebitNoteHeader.BasisDocument REFS Document.SupplierInvoice
		|			THEN DebitNoteHeader.BasisDocument
		|		ELSE CAST(DebitNoteHeader.BasisDocument AS Document.GoodsReturn).SupplierInvoice
		|	END";
	Else
		Query.Text = 
		"SELECT
		|	DebitNoteHeader.Date AS Period,
		|	DebitNoteAmountAllocation.Ref AS Recorder,
		|	&Company AS Company,
		|	DebitNoteHeader.Counterparty AS Supplier,
		|	DebitNoteAmountAllocation.Ref AS ShipmentDocument,
		|	SUM(-(CAST(CASE
		|				WHEN DebitNoteHeader.DocumentCurrency = &PresentationCurrency
		|					THEN (DebitNoteAmountAllocation.OffsetAmount - DebitNoteAmountAllocation.VATAmount) * ManagExchangeRates.ExchangeRate * RegExchangeRates.Multiplicity / (RegExchangeRates.ExchangeRate * ManagExchangeRates.Multiplicity)
		|				ELSE (DebitNoteAmountAllocation.OffsetAmount - DebitNoteAmountAllocation.VATAmount) * DebitNoteHeader.ExchangeRate * RegExchangeRates.Multiplicity / (RegExchangeRates.ExchangeRate * DebitNoteHeader.Multiplicity)
		|			END AS NUMBER(15, 2)))) AS AmountExcludesVAT,
		|	DebitNoteAmountAllocation.VATRate AS VATRate,
		|	CASE
		|		WHEN DebitNoteAmountAllocation.OperationKind = VALUE(Enum.OperationTypesDebitNote.Adjustments)
		|			THEN VALUE(Enum.VATOperationTypes.OtherAdjustments)
		|		WHEN DebitNoteAmountAllocation.OperationKind = VALUE(Enum.OperationTypesDebitNote.DiscountReceived)
		|			THEN VALUE(Enum.VATOperationTypes.DiscountReceived)
		|	END AS OperationType,
		|	VALUE(Enum.ProductsTypes.EmptyRef) AS ProductType,
		|	SUM(-(CAST(CASE
		|				WHEN DebitNoteHeader.DocumentCurrency = &PresentationCurrency
		|					THEN DebitNoteAmountAllocation.VATAmount * ManagExchangeRates.ExchangeRate * RegExchangeRates.Multiplicity / (RegExchangeRates.ExchangeRate * ManagExchangeRates.Multiplicity)
		|				ELSE DebitNoteAmountAllocation.VATAmount * DebitNoteHeader.ExchangeRate * RegExchangeRates.Multiplicity / (RegExchangeRates.ExchangeRate * DebitNoteHeader.Multiplicity)
		|			END AS NUMBER(15, 2)))) AS VATAmount
		|FROM
		|	TemporaryTableDocument AS DebitNoteHeader
		|		INNER JOIN TemporaryTableDocAmountAllocation AS DebitNoteAmountAllocation
		|		ON DebitNoteHeader.Ref = DebitNoteAmountAllocation.Ref
		|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS ManagExchangeRates
		|		ON (ManagExchangeRates.Currency = &PresentationCurrency)
		|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS RegExchangeRates
		|		ON (RegExchangeRates.Currency = &CurrencyNational)
		|WHERE
		|	NOT DebitNoteAmountAllocation.VATRate.NotTaxable
		|
		|GROUP BY
		|	DebitNoteAmountAllocation.VATRate,
		|	DebitNoteAmountAllocation.OperationKind,
		|	DebitNoteHeader.Date,
		|	DebitNoteAmountAllocation.Ref,
		|	DebitNoteHeader.Counterparty,
		|	DebitNoteAmountAllocation.Ref";
	EndIf;
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableVATInput", QueryResult.Unload());
	
EndFunction

Function GenerateTableVATIncurred(Query, DocumentRefDebitNote, StructureAdditionalProperties)
	
	If DocumentRefDebitNote.OperationKind = Enums.OperationTypesDebitNote.PurchaseReturn Then
		Query.Text = 
		"SELECT
		|	DebitNoteHeader.Date AS Period,
		|	DebitNoteHeader.Ref AS Recorder,
		|	&Company AS Company,
		|	DebitNoteHeader.Counterparty AS Supplier,
		|	DebitNoteHeader.Ref AS ShipmentDocument,
		|	DebitNoteInventory.VATRate AS VATRate,
		|	SUM(-(CAST(CASE
		|				WHEN DebitNoteHeader.DocumentCurrency = &PresentationCurrency
		|					THEN DebitNoteInventory.Amount * ManagExchangeRates.ExchangeRate * RegExchangeRates.Multiplicity / (RegExchangeRates.ExchangeRate * ManagExchangeRates.Multiplicity)
		|				ELSE DebitNoteInventory.Amount * DebitNoteHeader.ExchangeRate * RegExchangeRates.Multiplicity / (RegExchangeRates.ExchangeRate * DebitNoteHeader.Multiplicity)
		|			END AS NUMBER(15, 2)))) AS AmountExcludesVAT,
		|	SUM(-(CAST(CASE
		|				WHEN DebitNoteHeader.DocumentCurrency = &PresentationCurrency
		|					THEN DebitNoteInventory.VATAmount * ManagExchangeRates.ExchangeRate * RegExchangeRates.Multiplicity / (RegExchangeRates.ExchangeRate * ManagExchangeRates.Multiplicity)
		|				ELSE DebitNoteInventory.VATAmount * DebitNoteHeader.ExchangeRate * RegExchangeRates.Multiplicity / (RegExchangeRates.ExchangeRate * DebitNoteHeader.Multiplicity)
		|			END AS NUMBER(15, 2)))) AS VATAmount
		|FROM
		|	TemporaryTableDocument AS DebitNoteHeader
		|		INNER JOIN TemporaryTableDocInventory AS DebitNoteInventory
		|		ON DebitNoteHeader.Ref = DebitNoteInventory.Ref
		|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS ManagExchangeRates
		|		ON (ManagExchangeRates.Currency = &PresentationCurrency)
		|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS RegExchangeRates
		|		ON (RegExchangeRates.Currency = &CurrencyNational)
		|WHERE
		|	NOT DebitNoteInventory.VATRate.NotTaxable
		|
		|GROUP BY
		|	DebitNoteInventory.VATRate,
		|	DebitNoteHeader.Ref,
		|	DebitNoteHeader.Date,
		|	DebitNoteHeader.Counterparty,
		|	DebitNoteHeader.Ref";
	Else
		Query.Text = 
		"SELECT
		|	DebitNoteHeader.Date AS Period,
		|	DebitNoteHeader.Ref AS Recorder,
		|	&Company AS Company,
		|	DebitNoteHeader.Counterparty AS Supplier,
		|	DebitNoteHeader.Ref AS ShipmentDocument,
		|	DebitNoteAmountAllocation.VATRate AS VATRate,
		|	SUM(-(CAST(CASE
		|				WHEN DebitNoteHeader.DocumentCurrency = &PresentationCurrency
		|					THEN (DebitNoteAmountAllocation.OffsetAmount - DebitNoteAmountAllocation.VATAmount) * ManagExchangeRates.ExchangeRate * RegExchangeRates.Multiplicity / (RegExchangeRates.ExchangeRate * ManagExchangeRates.Multiplicity)
		|				ELSE (DebitNoteAmountAllocation.OffsetAmount - DebitNoteAmountAllocation.VATAmount) * DebitNoteHeader.ExchangeRate * RegExchangeRates.Multiplicity / (RegExchangeRates.ExchangeRate * DebitNoteHeader.Multiplicity)
		|			END AS NUMBER(15, 2)))) AS AmountExcludesVAT,
		|	SUM(-(CAST(CASE
		|				WHEN DebitNoteHeader.DocumentCurrency = &PresentationCurrency
		|					THEN DebitNoteAmountAllocation.VATAmount * ManagExchangeRates.ExchangeRate * RegExchangeRates.Multiplicity / (RegExchangeRates.ExchangeRate * ManagExchangeRates.Multiplicity)
		|				ELSE DebitNoteAmountAllocation.VATAmount * DebitNoteHeader.ExchangeRate * RegExchangeRates.Multiplicity / (RegExchangeRates.ExchangeRate * DebitNoteHeader.Multiplicity)
		|			END AS NUMBER(15, 2)))) AS VATAmount
		|FROM
		|	TemporaryTableDocument AS DebitNoteHeader
		|		INNER JOIN TemporaryTableDocAmountAllocation AS DebitNoteAmountAllocation
		|		ON DebitNoteHeader.Ref = DebitNoteAmountAllocation.Ref
		|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS ManagExchangeRates
		|		ON (ManagExchangeRates.Currency = &PresentationCurrency)
		|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS RegExchangeRates
		|		ON (RegExchangeRates.Currency = &CurrencyNational)
		|WHERE
		|	NOT DebitNoteAmountAllocation.VATRate.NotTaxable
		|
		|GROUP BY
		|	DebitNoteAmountAllocation.VATRate,
		|	DebitNoteHeader.Date,
		|	DebitNoteHeader.Counterparty,
		|	DebitNoteHeader.Ref,
		|	DebitNoteHeader.Ref";
	EndIf;
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableVATIncurred", QueryResult.Unload());
	
EndFunction

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefDebitNote, StructureAdditionalProperties) Export

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
	|	DebitNote.Date AS Date,
	|	DebitNote.Ref AS Ref,
	|	DebitNote.Counterparty AS Counterparty,
	|	DebitNote.Contract AS Contract,
	|	DebitNote.ExchangeRate AS ExchangeRate,
	|	DebitNote.Multiplicity AS Multiplicity,
	|	DebitNote.VATAmount AS VATAmount,
	|	DebitNote.GLAccount AS GLAccount,
	|	DebitNote.OperationKind AS OperationKind,
	|	DebitNote.DocumentCurrency AS DocumentCurrency,
	|	DebitNote.VATTaxation AS VATTaxation,
	|	DebitNote.AdjustmentAmount AS DocumentAmount,
	|	DebitNote.Department AS Department,
	|	DebitNote.Responsible AS Responsible,
	|	DebitNote.Cell AS Cell,
	|	DebitNote.AmountIncludesVAT AS AmountIncludesVAT,
	|	DebitNote.StructuralUnit AS StructuralUnit,
	|	DebitNote.BasisDocument AS BasisDocument,
	|	CASE
	|		WHEN DebitNote.AmountIncludesVAT
	|				OR DebitNote.OperationKind = VALUE(Enum.OperationTypesDebitNote.PurchaseReturn)
	|			THEN DebitNote.AdjustmentAmount - DebitNote.VATAmount
	|		ELSE DebitNote.AdjustmentAmount
	|	END AS Subtotal
	|INTO TemporaryTableDocument
	|FROM
	|	Document.DebitNote AS DebitNote
	|WHERE
	|	DebitNote.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TemporaryTableDocument.Date AS Period,
	|	TemporaryTableDocument.Ref AS Recorder,
	|	&Company AS Company,
	|	TemporaryTableDocument.Counterparty AS Counterparty,
	|	TemporaryTableDocument.Contract AS Contract,
	|	CAST(CASE
	|			WHEN TemporaryTableDocument.DocumentCurrency = &CurrencyNational
	|				THEN TemporaryTableDocument.VATAmount * RegExchangeRates.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * RegExchangeRates.Multiplicity)
	|			ELSE TemporaryTableDocument.VATAmount * TemporaryTableDocument.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * TemporaryTableDocument.Multiplicity)
	|		END AS NUMBER(15, 2)) AS VATAmount,
	|	TemporaryTableDocument.GLAccount AS GLAccount,
	|	TemporaryTableDocument.OperationKind AS OperationKind,
	|	CounterpartyContracts.BusinessLine AS BusinessLine,
	|	CounterpartyContracts.SettlementsCurrency AS SettlementsCurrency,
	|	CAST(CASE
	|			WHEN TemporaryTableDocument.DocumentCurrency = &CurrencyNational
	|				THEN TemporaryTableDocument.VATAmount * RegExchangeRates.ExchangeRate * TemporaryTableDocument.Multiplicity / (TemporaryTableDocument.ExchangeRate * RegExchangeRates.Multiplicity)
	|			ELSE TemporaryTableDocument.VATAmount
	|		END AS NUMBER(15, 2)) AS VATAmountCur,
	|	CAST(CASE
	|			WHEN TemporaryTableDocument.DocumentCurrency = &CurrencyNational
	|				THEN TemporaryTableDocument.Subtotal * RegExchangeRates.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * RegExchangeRates.Multiplicity)
	|			ELSE TemporaryTableDocument.Subtotal * TemporaryTableDocument.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * TemporaryTableDocument.Multiplicity)
	|		END AS NUMBER(15, 2)) AS Amount,
	|	CAST(CASE
	|			WHEN TemporaryTableDocument.DocumentCurrency = &CurrencyNational
	|				THEN TemporaryTableDocument.Subtotal * RegExchangeRates.ExchangeRate * TemporaryTableDocument.Multiplicity / (TemporaryTableDocument.ExchangeRate * RegExchangeRates.Multiplicity)
	|			ELSE TemporaryTableDocument.Subtotal
	|		END AS NUMBER(15, 2)) AS AmountCur,
	|	TemporaryTableDocument.VATTaxation AS VATTaxation,
	|	TemporaryTableDocument.Department AS Department,
	|	Counterparties.GLAccountVendorSettlements AS GLAccountVendorSettlements,
	|	&UseGoodsReturnToSupplier AS UseGoodsReturnToSupplier,
	|	TemporaryTableDocument.DocumentCurrency AS DocumentCurrency,
	|	PrimaryChartOfAccounts.Currency AS GLAccountVendorSettlementsCurrency
	|INTO TemporaryTableHeader
	|FROM
	|	TemporaryTableDocument AS TemporaryTableDocument
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS ManagExchangeRates
	|		ON (ManagExchangeRates.Currency = &PresentationCurrency)
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS RegExchangeRates
	|		ON (RegExchangeRates.Currency = &CurrencyNational)
	|		LEFT JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
	|		ON TemporaryTableDocument.Contract = CounterpartyContracts.Ref
	|		LEFT JOIN Catalog.Counterparties AS Counterparties
	|		ON TemporaryTableDocument.Counterparty = Counterparties.Ref
	|		LEFT JOIN ChartOfAccounts.PrimaryChartOfAccounts AS PrimaryChartOfAccounts
	|		ON (Counterparties.GLAccountVendorSettlements = PrimaryChartOfAccounts.Ref)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SupplierInvoice.Ref AS Basis,
	|	SupplierInvoice.Order AS Order,
	|	SupplierInvoice.Department AS Department,
	|	SupplierInvoice.Responsible AS Responsible,
	|	SupplierInvoice.Ref AS SupplierInvoice
	|INTO TemporaryTableBasis
	|FROM
	|	TemporaryTableDocument AS TemporaryTableDocument
	|		LEFT JOIN Document.SupplierInvoice AS SupplierInvoice
	|		ON (SupplierInvoice.Ref REFS Document.SupplierInvoice)
	|			AND TemporaryTableDocument.Ref.BasisDocument = SupplierInvoice.Ref
	|
	|UNION ALL
	|
	|SELECT
	|	GoodsReturn.Ref,
	|	GoodsReturn.SupplierInvoice.Order,
	|	GoodsReturn.Department,
	|	GoodsReturn.Responsible,
	|	GoodsReturn.SupplierInvoice
	|FROM
	|	TemporaryTableDocument AS TemporaryTableDocument
	|		LEFT JOIN Document.GoodsReturn AS GoodsReturn
	|		ON (GoodsReturn.Ref REFS Document.GoodsReturn)
	|			AND TemporaryTableDocument.Ref.BasisDocument = GoodsReturn.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DebitNoteInventory.Ref AS Ref,
	|	CASE
	|		WHEN TemporaryTableDocument.AmountIncludesVAT
	|			THEN DebitNoteInventory.Amount - DebitNoteInventory.VATAmount
	|		ELSE DebitNoteInventory.Amount
	|	END AS AdjustmentAmount,
	|	DebitNoteInventory.Batch AS Batch,
	|	DebitNoteInventory.Characteristic AS Characteristic,
	|	DebitNoteInventory.MeasurementUnit AS MeasurementUnit,
	|	DebitNoteInventory.InitialQuantity AS Quantity,
	|	DebitNoteInventory.InitialPrice AS Price,
	|	DebitNoteInventory.Products AS Products,
	|	DebitNoteInventory.Quantity AS ReturnQuantity,
	|	DebitNoteInventory.VATAmount AS VATAmount,
	|	DebitNoteInventory.VATRate AS VATRate,
	|	DebitNoteInventory.InventoryGLAccount AS InventoryGLAccount,
	|	DebitNoteInventory.PurchaseReturnGLAccount AS GLAccount,
	|	DebitNoteInventory.VATInputGLAccount AS VATInputGLAccount,
	|	DebitNoteInventory.ConnectionKey AS ConnectionKey,
	|	CASE
	|		WHEN TemporaryTableDocument.AmountIncludesVAT
	|			THEN DebitNoteInventory.Amount - DebitNoteInventory.VATAmount
	|		ELSE DebitNoteInventory.Amount
	|	END AS Amount,
	|	DebitNoteInventory.Order AS Order,
	|	TemporaryTableDocument.Date AS Date,
	|	TemporaryTableDocument.Contract AS Contract,
	|	TemporaryTableDocument.ExchangeRate AS ExchangeRate,
	|	TemporaryTableDocument.Multiplicity AS Multiplicity,
	|	TemporaryTableDocument.OperationKind AS OperationKind,
	|	TemporaryTableDocument.DocumentCurrency AS DocumentCurrency,
	|	TemporaryTableDocument.Department AS Department,
	|	TemporaryTableDocument.Responsible AS Responsible,
	|	TemporaryTableDocument.Cell AS Cell,
	|	TemporaryTableDocument.AmountIncludesVAT AS AmountIncludesVAT,
	|	TemporaryTableDocument.StructuralUnit AS StructuralUnit,
	|	TemporaryTableDocument.BasisDocument AS BasisDocument
	|INTO TemporaryTableDocInventory
	|FROM
	|	TemporaryTableDocument AS TemporaryTableDocument
	|		INNER JOIN Document.DebitNote.Inventory AS DebitNoteInventory
	|		ON TemporaryTableDocument.Ref = DebitNoteInventory.Ref
	|WHERE
	|	DebitNoteInventory.Amount <> 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TemporaryTableDocInventory.Ref AS Recorder,
	|	TemporaryTableDocInventory.Batch AS Batch,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN TemporaryTableDocInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	SUM(CASE
	|			WHEN VALUETYPE(TemporaryTableDocInventory.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|				THEN TemporaryTableDocInventory.Quantity
	|			ELSE TemporaryTableDocInventory.Quantity * TemporaryTableDocInventory.MeasurementUnit.Factor
	|		END) AS Quantity,
	|	TemporaryTableDocInventory.Products AS Products,
	|	SUM(CASE
	|			WHEN VALUETYPE(TemporaryTableDocInventory.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|				THEN TemporaryTableDocInventory.ReturnQuantity
	|			ELSE TemporaryTableDocInventory.ReturnQuantity * TemporaryTableDocInventory.MeasurementUnit.Factor
	|		END) AS ReturnQuantity,
	|	TemporaryTableDocInventory.Date AS Period,
	|	TemporaryTableDocInventory.Department AS Department,
	|	TemporaryTableBasis.SupplierInvoice AS BasisDocument,
	|	TemporaryTableDocInventory.Responsible AS Responsible,
	|	TemporaryTableDocInventory.VATRate AS VATRate,
	|	SUM(CAST(CASE
	|				WHEN TemporaryTableDocInventory.DocumentCurrency = &CurrencyNational
	|					THEN TemporaryTableDocInventory.VATAmount * RegExchangeRates.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * RegExchangeRates.Multiplicity)
	|				ELSE TemporaryTableDocInventory.VATAmount * TemporaryTableDocInventory.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * TemporaryTableDocInventory.Multiplicity)
	|			END AS NUMBER(15, 2))) AS VATAmount,
	|	&Company AS Company,
	|	SUM(CAST(CASE
	|				WHEN TemporaryTableDocInventory.DocumentCurrency = &CurrencyNational
	|					THEN TemporaryTableDocInventory.AdjustmentAmount * RegExchangeRates.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * RegExchangeRates.Multiplicity)
	|				ELSE TemporaryTableDocInventory.AdjustmentAmount * TemporaryTableDocInventory.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * TemporaryTableDocInventory.Multiplicity)
	|			END AS NUMBER(15, 2))) AS AdjustmentAmount,
	|	TemporaryTableDocInventory.Order AS Order,
	|	TemporaryTableDocInventory.AmountIncludesVAT AS AmountIncludesVAT,
	|	TemporaryTableDocInventory.StructuralUnit AS StructuralUnit,
	|	TemporaryTableDocInventory.Cell AS Cell,
	|	LinesOfBusiness.Ref AS BusinessLine,
	|	CounterpartyContracts.SettlementsCurrency AS SettlementsCurrency,
	|	TemporaryTableDocInventory.InventoryGLAccount AS InventoryGLAccount,
	|	TemporaryTableDocInventory.OperationKind AS OperationKind,
	|	TemporaryTableDocInventory.ConnectionKey AS ConnectionKey,
	|	TemporaryTableDocInventory.GLAccount AS GLAccount,
	|	CAST(CASE
	|			WHEN TemporaryTableDocInventory.DocumentCurrency = &CurrencyNational
	|				THEN TemporaryTableDocInventory.Amount * RegExchangeRates.ExchangeRate * TemporaryTableDocInventory.Multiplicity / (TemporaryTableDocInventory.ExchangeRate * RegExchangeRates.Multiplicity)
	|			ELSE TemporaryTableDocInventory.Amount
	|		END AS NUMBER(15, 2)) AS AmountCur,
	|	TemporaryTableDocInventory.Products.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem) AS ThisIsInventoryItem,
	|	&UseGoodsReturnToSupplier AS UseGoodsReturnToSupplier,
	|	SUM(TemporaryTableDocInventory.AdjustmentAmount + TemporaryTableDocInventory.VATAmount) AS Total,
	|	CASE
	|		WHEN TemporaryTableDocInventory.OperationKind = VALUE(Enum.OperationTypesDebitNote.PurchaseReturn)
	|				AND NOT &UseGoodsReturnToSupplier
	|				AND TemporaryTableDocInventory.Products.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
	|			THEN CAST(CASE
	|						WHEN TemporaryTableDocInventory.DocumentCurrency = &CurrencyNational
	|							THEN TemporaryTableDocInventory.AdjustmentAmount * RegExchangeRates.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * RegExchangeRates.Multiplicity)
	|						ELSE TemporaryTableDocInventory.AdjustmentAmount * TemporaryTableDocInventory.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * TemporaryTableDocInventory.Multiplicity)
	|					END AS NUMBER(15, 2))
	|		ELSE 0
	|	END AS Expense,
	|	CAST(CASE
	|			WHEN TemporaryTableDocInventory.DocumentCurrency = &CurrencyNational
	|				THEN (TemporaryTableDocInventory.AdjustmentAmount + TemporaryTableDocInventory.VATAmount) * RegExchangeRates.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * RegExchangeRates.Multiplicity)
	|			ELSE (TemporaryTableDocInventory.AdjustmentAmount + TemporaryTableDocInventory.VATAmount) * TemporaryTableDocInventory.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * TemporaryTableDocInventory.Multiplicity)
	|		END AS NUMBER(15, 2)) AS TotalCur,
	|	TemporaryTableDocInventory.VATInputGLAccount AS VATInputGLAccount
	|INTO TemporaryTableInventory
	|FROM
	|	TemporaryTableDocInventory AS TemporaryTableDocInventory
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS ManagExchangeRates
	|		ON (ManagExchangeRates.Currency = &CurrencyNational)
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS RegExchangeRates
	|		ON (RegExchangeRates.Currency = &PresentationCurrency)
	|		LEFT JOIN TemporaryTableBasis AS TemporaryTableBasis
	|		ON TemporaryTableDocInventory.BasisDocument = TemporaryTableBasis.Basis
	|		LEFT JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
	|		ON TemporaryTableDocInventory.Contract = CounterpartyContracts.Ref
	|		LEFT JOIN Catalog.LinesOfBusiness AS LinesOfBusiness
	|		ON TemporaryTableDocInventory.Products.BusinessLine = LinesOfBusiness.Ref
	|
	|GROUP BY
	|	TemporaryTableDocInventory.Batch,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN TemporaryTableDocInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END,
	|	TemporaryTableDocInventory.VATRate,
	|	TemporaryTableDocInventory.Products,
	|	TemporaryTableDocInventory.Ref,
	|	TemporaryTableDocInventory.Date,
	|	TemporaryTableDocInventory.AmountIncludesVAT,
	|	TemporaryTableBasis.SupplierInvoice,
	|	TemporaryTableDocInventory.Department,
	|	TemporaryTableDocInventory.Responsible,
	|	TemporaryTableDocInventory.StructuralUnit,
	|	TemporaryTableDocInventory.Cell,
	|	LinesOfBusiness.Ref,
	|	CounterpartyContracts.SettlementsCurrency,
	|	TemporaryTableDocInventory.OperationKind,
	|	TemporaryTableDocInventory.ConnectionKey,
	|	TemporaryTableDocInventory.GLAccount,
	|	CAST(CASE
	|			WHEN TemporaryTableDocInventory.DocumentCurrency = &CurrencyNational
	|				THEN TemporaryTableDocInventory.Amount * RegExchangeRates.ExchangeRate * TemporaryTableDocInventory.Multiplicity / (TemporaryTableDocInventory.ExchangeRate * RegExchangeRates.Multiplicity)
	|			ELSE TemporaryTableDocInventory.Amount
	|		END AS NUMBER(15, 2)),
	|	TemporaryTableDocInventory.Products.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem),
	|	TemporaryTableDocInventory.Order,
	|	CAST(CASE
	|			WHEN TemporaryTableDocInventory.DocumentCurrency = &CurrencyNational
	|				THEN (TemporaryTableDocInventory.AdjustmentAmount + TemporaryTableDocInventory.VATAmount) * RegExchangeRates.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * RegExchangeRates.Multiplicity)
	|			ELSE (TemporaryTableDocInventory.AdjustmentAmount + TemporaryTableDocInventory.VATAmount) * TemporaryTableDocInventory.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * TemporaryTableDocInventory.Multiplicity)
	|		END AS NUMBER(15, 2)),
	|	CASE
	|		WHEN TemporaryTableDocInventory.OperationKind = VALUE(Enum.OperationTypesDebitNote.PurchaseReturn)
	|				AND NOT &UseGoodsReturnToSupplier
	|				AND TemporaryTableDocInventory.Products.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
	|			THEN CAST(CASE
	|						WHEN TemporaryTableDocInventory.DocumentCurrency = &CurrencyNational
	|							THEN TemporaryTableDocInventory.AdjustmentAmount * RegExchangeRates.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * RegExchangeRates.Multiplicity)
	|						ELSE TemporaryTableDocInventory.AdjustmentAmount * TemporaryTableDocInventory.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * TemporaryTableDocInventory.Multiplicity)
	|					END AS NUMBER(15, 2))
	|		ELSE 0
	|	END,
	|	TemporaryTableDocInventory.InventoryGLAccount,
	|	TemporaryTableDocInventory.VATInputGLAccount
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DebitNoteAmountAllocation.Ref AS Ref,
	|	DebitNoteAmountAllocation.Contract AS Contract,
	|	DebitNoteAmountAllocation.AdvanceFlag AS AdvanceFlag,
	|	DebitNoteAmountAllocation.Document AS Document,
	|	DebitNoteAmountAllocation.OffsetAmount AS OffsetAmount,
	|	DebitNoteAmountAllocation.Order AS Order,
	|	TemporaryTableDocument.Date AS Date,
	|	TemporaryTableDocument.Counterparty AS Counterparty,
	|	TemporaryTableDocument.ExchangeRate AS ExchangeRate,
	|	TemporaryTableDocument.Multiplicity AS Multiplicity,
	|	TemporaryTableDocument.OperationKind AS OperationKind,
	|	TemporaryTableDocument.DocumentCurrency AS DocumentCurrency,
	|	DebitNoteAmountAllocation.VATRate AS VATRate,
	|	DebitNoteAmountAllocation.VATAmount AS VATAmount,
	|	DebitNoteAmountAllocation.LineNumber AS LineNumber,
	|	Counterparties.CustomerAdvancesGLAccount AS CustomerAdvancesGLAccount,
	|	Counterparties.GLAccountVendorSettlements AS GLAccountVendorSettlements
	|INTO TemporaryTableDocAmountAllocation
	|FROM
	|	TemporaryTableDocument AS TemporaryTableDocument
	|		INNER JOIN Document.DebitNote.AmountAllocation AS DebitNoteAmountAllocation
	|		ON TemporaryTableDocument.Ref = DebitNoteAmountAllocation.Ref
	|		INNER JOIN Catalog.Counterparties AS Counterparties
	|		ON TemporaryTableDocument.Counterparty = Counterparties.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TemporaryTableDocAmountAllocation.Date AS Period,
	|	TemporaryTableDocAmountAllocation.Ref AS Recorder,
	|	&Company AS Company,
	|	TemporaryTableDocAmountAllocation.Counterparty AS Counterparty,
	|	TemporaryTableDocAmountAllocation.Contract AS Contract,
	|	TemporaryTableDocAmountAllocation.Document AS Document,
	|	CAST(CASE
	|			WHEN TemporaryTableDocAmountAllocation.DocumentCurrency = &CurrencyNational
	|				THEN TemporaryTableDocAmountAllocation.OffsetAmount * RegExchangeRates.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * RegExchangeRates.Multiplicity)
	|			ELSE TemporaryTableDocAmountAllocation.OffsetAmount * TemporaryTableDocAmountAllocation.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * TemporaryTableDocAmountAllocation.Multiplicity)
	|		END AS NUMBER(15, 2)) AS Amount,
	|	TemporaryTableDocAmountAllocation.Order AS Order,
	|	CAST(CASE
	|			WHEN TemporaryTableDocAmountAllocation.DocumentCurrency = &CurrencyNational
	|				THEN TemporaryTableDocAmountAllocation.OffsetAmount * RegExchangeRates.ExchangeRate * TemporaryTableDocAmountAllocation.Multiplicity / (TemporaryTableDocAmountAllocation.ExchangeRate * RegExchangeRates.Multiplicity)
	|			ELSE TemporaryTableDocAmountAllocation.OffsetAmount
	|		END AS NUMBER(15, 2)) AS AmountCur,
	|	TemporaryTableDocAmountAllocation.AdvanceFlag AS AdvanceFlag,
	|	TemporaryTableDocAmountAllocation.OperationKind AS OperationKind,
	|	TemporaryTableDocAmountAllocation.LineNumber AS LineNumber,
	|	TemporaryTableDocAmountAllocation.DocumentCurrency AS Currency,
	|	TemporaryTableDocAmountAllocation.OffsetAmount AS OffsetAmount,
	|	TemporaryTableDocAmountAllocation.GLAccountVendorSettlements AS GLAccountVendorSettlements,
	|	TemporaryTableDocAmountAllocation.CustomerAdvancesGLAccount AS CustomerAdvancesGLAccount
	|INTO TemporaryTableAmountAllocation
	|FROM
	|	TemporaryTableDocAmountAllocation AS TemporaryTableDocAmountAllocation
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS ManagExchangeRates
	|		ON (ManagExchangeRates.Currency = &PresentationCurrency)
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS RegExchangeRates
	|		ON (RegExchangeRates.Currency = &CurrencyNational)";
	
	Query.SetParameter("Ref",						DocumentRefDebitNote);
	Query.SetParameter("Company",					StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PointInTime", 				New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("UseCharacteristics",		StructureAdditionalProperties.AccountingPolicy.UseCharacteristics);
	Query.SetParameter("UseGoodsReturnToSupplier",	StructureAdditionalProperties.AccountingPolicy.UseGoodsReturnToSupplier);
	Query.SetParameter("PresentationCurrency",		Constants.PresentationCurrency.Get());
	Query.SetParameter("CurrencyNational",			Constants.FunctionalCurrency.Get());
	Query.SetParameter("DocumentCurrency",			DocumentRefDebitNote.DocumentCurrency);

	ResultsArray = Query.ExecuteBatch();
	
	// Creation of document postings.
	DriveServer.GenerateTransactionsTable(DocumentRefDebitNote, StructureAdditionalProperties);
	                                                                              
	PerformanceEstimationClientServer.StartTimeMeasurement("DocumentDebitNoteGenerateTables");
	
	GenerateTablePurchases(DocumentRefDebitNote, StructureAdditionalProperties);
	GenerateTableAccountsPayable(DocumentRefDebitNote, StructureAdditionalProperties);
	GenerateTableIncomeAndExpenses(DocumentRefDebitNote, StructureAdditionalProperties);
	
	If DocumentRefDebitNote.OperationKind = Enums.OperationTypesDebitNote.PurchaseReturn Then
		If NOT StructureAdditionalProperties.AccountingPolicy.UseGoodsReturnToSupplier Then
			GenerateTableInventoryInWarehouses(DocumentRefDebitNote, StructureAdditionalProperties);
			GenerateTableInventory(DocumentRefDebitNote, StructureAdditionalProperties);
			GenerateTableSerialNumbers(DocumentRefDebitNote, StructureAdditionalProperties);	
		EndIf;
	EndIf;
	
	GenerateTableAccountingJournalEntries(DocumentRefDebitNote, StructureAdditionalProperties);
	
	If GetFunctionalOption("UseVAT")
		AND DocumentRefDebitNote.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then
		
		If WorkWithVAT.GetUseTaxInvoiceForPostingVAT(DocumentRefDebitNote.Date, DocumentRefDebitNote.Company) Then
			
			GenerateTableVATIncurred(Query, DocumentRefDebitNote, StructureAdditionalProperties);
			
		Else
			
			GenerateTableVATInput(Query, DocumentRefDebitNote, StructureAdditionalProperties);
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Controls the occurrence of negative balances.
//
Procedure RunControl(DocumentRefDebitNote, AdditionalProperties, Cancel, PostingDelete = False) Export
	
	If Not DriveServer.RunBalanceControl() Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// If temporary tables "RegisterRecordsInventoryChange", "MovementsInventoryInWarehousesChange"
	// contain records, it is required to control goods implementation.
		
	If StructureTemporaryTables.RegisterRecordsInventoryChange
		OR StructureTemporaryTables.RegisterRecordsInventoryInWarehousesChange
		OR StructureTemporaryTables.RegisterRecordsSuppliersSettlementsChange
		OR StructureTemporaryTables.RegisterRecordsVATIncurredChange Then
		
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
		|	ISNULL(RegisterRecordsInventoryInWarehousesChange.QuantityChange, 0) + ISNULL(InventoryInWarehousesOfBalance.QuantityBalance, 0) AS BalanceInventoryInWarehouses,
		|	ISNULL(InventoryInWarehousesOfBalance.QuantityBalance, 0) AS QuantityBalanceInventoryInWarehouses
		|FROM
		|	RegisterRecordsInventoryInWarehousesChange AS RegisterRecordsInventoryInWarehousesChange
		|		INNER JOIN AccumulationRegister.InventoryInWarehouses.Balance(&ControlTime, ) AS InventoryInWarehousesOfBalance
		|		ON RegisterRecordsInventoryInWarehousesChange.Company = InventoryInWarehousesOfBalance.Company
		|			AND RegisterRecordsInventoryInWarehousesChange.StructuralUnit = InventoryInWarehousesOfBalance.StructuralUnit
		|			AND RegisterRecordsInventoryInWarehousesChange.Products = InventoryInWarehousesOfBalance.Products
		|			AND RegisterRecordsInventoryInWarehousesChange.Characteristic = InventoryInWarehousesOfBalance.Characteristic
		|			AND RegisterRecordsInventoryInWarehousesChange.Batch = InventoryInWarehousesOfBalance.Batch
		|			AND RegisterRecordsInventoryInWarehousesChange.Cell = InventoryInWarehousesOfBalance.Cell
		|			AND (ISNULL(InventoryInWarehousesOfBalance.QuantityBalance, 0) < 0)
		|
		|ORDER BY
		|	LineNumber
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
		|	RegisterRecordsSuppliersSettlementsChange.LineNumber AS LineNumber,
		|	RegisterRecordsSuppliersSettlementsChange.Company AS CompanyPresentation,
		|	RegisterRecordsSuppliersSettlementsChange.Counterparty AS CounterpartyPresentation,
		|	RegisterRecordsSuppliersSettlementsChange.Contract AS ContractPresentation,
		|	RegisterRecordsSuppliersSettlementsChange.Contract.SettlementsCurrency AS CurrencyPresentation,
		|	RegisterRecordsSuppliersSettlementsChange.Document AS DocumentPresentation,
		|	RegisterRecordsSuppliersSettlementsChange.Order AS OrderPresentation,
		|	RegisterRecordsSuppliersSettlementsChange.SettlementsType AS CalculationsTypesPresentation,
		|	FALSE AS RegisterRecordsOfCashDocuments,
		|	RegisterRecordsSuppliersSettlementsChange.SumBeforeWrite AS SumBeforeWrite,
		|	RegisterRecordsSuppliersSettlementsChange.AmountOnWrite AS AmountOnWrite,
		|	RegisterRecordsSuppliersSettlementsChange.AmountChange AS AmountChange,
		|	RegisterRecordsSuppliersSettlementsChange.AmountCurBeforeWrite AS AmountCurBeforeWrite,
		|	RegisterRecordsSuppliersSettlementsChange.SumCurOnWrite AS SumCurOnWrite,
		|	RegisterRecordsSuppliersSettlementsChange.SumCurChange AS SumCurChange,
		|	RegisterRecordsSuppliersSettlementsChange.SumCurOnWrite - ISNULL(AccountsPayableBalances.AmountCurBalance, 0) AS AdvanceAmountsPaid,
		|	RegisterRecordsSuppliersSettlementsChange.SumCurChange + ISNULL(AccountsPayableBalances.AmountCurBalance, 0) AS AmountOfOutstandingDebt,
		|	ISNULL(AccountsPayableBalances.AmountBalance, 0) AS AmountBalance,
		|	ISNULL(AccountsPayableBalances.AmountCurBalance, 0) AS AmountCurBalance,
		|	RegisterRecordsSuppliersSettlementsChange.SettlementsType AS SettlementsType
		|FROM
		|	RegisterRecordsSuppliersSettlementsChange AS RegisterRecordsSuppliersSettlementsChange
		|		INNER JOIN AccumulationRegister.AccountsPayable.Balance(&ControlTime, ) AS AccountsPayableBalances
		|		ON RegisterRecordsSuppliersSettlementsChange.Company = AccountsPayableBalances.Company
		|			AND RegisterRecordsSuppliersSettlementsChange.Counterparty = AccountsPayableBalances.Counterparty
		|			AND RegisterRecordsSuppliersSettlementsChange.Contract = AccountsPayableBalances.Contract
		|			AND RegisterRecordsSuppliersSettlementsChange.Document = AccountsPayableBalances.Document
		|			AND RegisterRecordsSuppliersSettlementsChange.Order = AccountsPayableBalances.Order
		|			AND RegisterRecordsSuppliersSettlementsChange.SettlementsType = AccountsPayableBalances.SettlementsType
		|			AND (CASE
		|				WHEN RegisterRecordsSuppliersSettlementsChange.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)
		|					THEN ISNULL(AccountsPayableBalances.AmountCurBalance, 0) > 0
		|				ELSE ISNULL(AccountsPayableBalances.AmountCurBalance, 0) < 0
		|			END)");
		
		Query.Text = Query.Text + DriveClientServer.GetQueryDelimeter();
		Query.Text = Query.Text + AccumulationRegisters.VATIncurred.BalancesControlQueryText();
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.SetParameter("ControlTime", AdditionalProperties.ForPosting.ControlTime);
		
		ResultsArray = Query.ExecuteBatch();
		
		If Not ResultsArray[0].IsEmpty()
			OR Not ResultsArray[1].IsEmpty()
			OR Not ResultsArray[2].IsEmpty()
			OR Not ResultsArray[4].IsEmpty() Then
			DocumentObjectDebitNote = DocumentRefDebitNote.GetObject()
		EndIf;
		
		// Negative balance of inventory in the warehouse.
		If Not ResultsArray[0].IsEmpty() Then
			QueryResultSelection = ResultsArray[0].Select();
			DriveServer.ShowMessageAboutPostingToInventoryInWarehousesRegisterErrors(DocumentObjectDebitNote, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance of inventory.
		If Not ResultsArray[1].IsEmpty() Then
			QueryResultSelection = ResultsArray[1].Select();
			DriveServer.ShowMessageAboutPostingToInventoryRegisterErrors(DocumentObjectDebitNote, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance on accounts payable.
		If Not ResultsArray[2].IsEmpty() Then
			QueryResultSelection = ResultsArray[2].Select();
			DriveServer.ShowMessageAboutPostingToAccountsPayableRegisterErrors(DocumentObjectDebitNote, QueryResultSelection, Cancel);
		EndIf;
		
		If Not ResultsArray[4].IsEmpty() Then
			QueryResultSelection = ResultsArray[3].Select();
			DriveServer.ShowMessageAboutPostingToVATIncurredRegisterErrors(DocumentObjectDebitNote, QueryResultSelection, Cancel);
		EndIf;
		
	EndIf;
	
EndProcedure

#Region PrintInterface

Function PrintForm(ObjectsArray, PrintObjects, TemplateName)
	
	If TemplateName = "DebitNote" Then
		Return PrintDebitNote(ObjectsArray, PrintObjects, TemplateName)
	EndIf;
	
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
	
	If PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "DebitNote") Then
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection, "DebitNote", "Debit note", PrintForm(ObjectsArray, PrintObjects, "DebitNote"));
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
	PrintCommand.ID							= "DebitNote";
	PrintCommand.Presentation				= NStr("en = 'Debit note'");
	PrintCommand.CheckPostingBeforePrint	= False;
	PrintCommand.Order						= 1;
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID							= "Requisition";
	PrintCommand.Presentation				= NStr("en = 'Requisition'");
	PrintCommand.CheckPostingBeforePrint	= False;
	PrintCommand.Order						= 2;
	
EndProcedure

Function PrintDebitNote(ObjectsArray, PrintObjects, TemplateName)
	
	SpreadsheetDocument = New SpreadsheetDocument;
	SpreadsheetDocument.PrintParametersKey = "PrintParameters_DebitNote";
	
	Query = New Query();
	Query.SetParameter("ObjectsArray", ObjectsArray);
	
	#Region PrintDebitNoteQueryText
	
	Query.Text = 
	"SELECT
	|	DebitNote.Ref AS Ref,
	|	DebitNote.Number AS Number,
	|	DebitNote.Date AS Date,
	|	DebitNote.Company AS Company,
	|	DebitNote.Counterparty AS Counterparty,
	|	DebitNote.Contract AS Contract,
	|	DebitNote.AmountIncludesVAT AS AmountIncludesVAT,
	|	DebitNote.DocumentCurrency AS DocumentCurrency,
	|	CAST(DebitNote.Comment AS STRING(1024)) AS Comment,
	|	DebitNote.BasisDocument AS BasisDocument,
	|	DebitNote.OperationKind AS OperationKind,
	|	DebitNote.AdjustmentAmount AS DocumentAmount,
	|	DebitNote.VATRate AS VATRate,
	|	DebitNote.VATAmount AS VATAmount
	|INTO DebitNotes
	|FROM
	|	Document.DebitNote AS DebitNote
	|WHERE
	|	DebitNote.Ref IN(&ObjectsArray)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DebitNoteInventory.Ref AS Ref,
	|	DebitNoteInventory.LineNumber AS LineNumber,
	|	DebitNoteInventory.Amount AS Amount,
	|	DebitNoteInventory.Batch AS Batch,
	|	DebitNoteInventory.Characteristic AS Characteristic,
	|	DebitNoteInventory.ConnectionKey AS ConnectionKey,
	|	DebitNoteInventory.MeasurementUnit AS MeasurementUnit,
	|	CASE
	|		WHEN DebitNoteInventory.Quantity = 0
	|			THEN 0
	|		ELSE DebitNoteInventory.Amount / DebitNoteInventory.Quantity
	|	END AS Price,
	|	DebitNoteInventory.Products AS Products,
	|	DebitNoteInventory.Quantity AS Quantity,
	|	DebitNoteInventory.Total AS Total,
	|	DebitNoteInventory.VATAmount AS VATAmount,
	|	DebitNoteInventory.VATRate AS VATRate
	|INTO FilteredInventory
	|FROM
	|	Document.DebitNote.Inventory AS DebitNoteInventory
	|WHERE
	|	DebitNoteInventory.Ref IN(&ObjectsArray)
	|	AND (DebitNoteInventory.Quantity <> 0
	|			OR DebitNoteInventory.Amount <> 0)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DebitNote.Ref AS Ref,
	|	DebitNote.Number AS DocumentNumber,
	|	DebitNote.Date AS DocumentDate,
	|	DebitNote.Company AS Company,
	|	Companies.LogoFile AS CompanyLogoFile,
	|	DebitNote.Counterparty AS Counterparty,
	|	DebitNote.Contract AS Contract,
	|	CASE
	|		WHEN CounterpartyContracts.ContactPerson = VALUE(Catalog.ContactPersons.EmptyRef)
	|			THEN Counterparties.ContactPerson
	|		ELSE CounterpartyContracts.ContactPerson
	|	END AS CounterpartyContactPerson,
	|	CAST(CASE
	|			WHEN DebitNote.BasisDocument REFS Document.GoodsReturn
	|				THEN DebitNote.BasisDocument.SupplierInvoice
	|			ELSE DebitNote.BasisDocument
	|		END AS Document.SupplierInvoice) AS Invoice,
	|	DebitNote.AmountIncludesVAT AS AmountIncludesVAT,
	|	DebitNote.DocumentCurrency AS DocumentCurrency,
	|	DebitNote.Comment AS Comment,
	|	DebitNote.OperationKind AS OperationKind,
	|	DebitNote.DocumentAmount AS DocumentAmount,
	|	DebitNote.VATRate AS VATRate,
	|	DebitNote.VATAmount AS VATAmount
	|INTO Header
	|FROM
	|	DebitNotes AS DebitNote
	|		LEFT JOIN Catalog.Companies AS Companies
	|		ON DebitNote.Company = Companies.Ref
	|		LEFT JOIN Catalog.Counterparties AS Counterparties
	|		ON DebitNote.Counterparty = Counterparties.Ref
	|		LEFT JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
	|		ON DebitNote.Contract = CounterpartyContracts.Ref
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
	|	SUM(FilteredInventory.Amount) AS Amount,
	|	FilteredInventory.VATRate AS VATRate,
	|	SUM(FilteredInventory.VATAmount) AS VATAmount,
	|	SUM(FilteredInventory.Total) AS Total,
	|	SUM(CASE
	|			WHEN Header.AmountIncludesVAT
	|				THEN FilteredInventory.Amount - FilteredInventory.VATAmount
	|			ELSE FilteredInventory.Amount
	|		END) AS Subtotal,
	|	CatalogProducts.Description AS ProductDescription,
	|	FALSE AS ContentUsed,
	|	Header.Invoice AS Invoice,
	|	Header.OperationKind AS OperationKind,
	|	FilteredInventory.Batch AS Batch,
	|	FilteredInventory.Characteristic AS Characteristic,
	|	FilteredInventory.Products AS Products,
	|	FilteredInventory.MeasurementUnit AS MeasurementUnit,
	|	SupplierInvoice.IncomingDocumentNumber AS IncomingNumber,
	|	SupplierInvoice.IncomingDocumentDate AS IncomingDate
	|INTO Inventory
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
	|		LEFT JOIN Document.SupplierInvoice AS SupplierInvoice
	|		ON Header.Invoice = SupplierInvoice.Ref
	|
	|GROUP BY
	|	CatalogProducts.Description,
	|	Header.OperationKind,
	|	FilteredInventory.Batch,
	|	Header.DocumentNumber,
	|	CatalogProducts.UseSerialNumbers,
	|	Header.Ref,
	|	Header.CounterpartyContactPerson,
	|	FilteredInventory.Characteristic,
	|	FilteredInventory.Products,
	|	CASE
	|		WHEN CatalogProducts.UseBatches
	|			THEN CatalogBatches.Description
	|		ELSE """"
	|	END,
	|	FilteredInventory.MeasurementUnit,
	|	Header.Invoice,
	|	Header.Counterparty,
	|	Header.DocumentCurrency,
	|	FilteredInventory.VATRate,
	|	Header.Comment,
	|	Header.DocumentDate,
	|	Header.Contract,
	|	Header.CompanyLogoFile,
	|	CatalogProducts.SKU,
	|	Header.Company,
	|	CASE
	|		WHEN CatalogProducts.UseCharacteristics
	|			THEN CatalogCharacteristics.Description
	|		ELSE """"
	|	END,
	|	Header.AmountIncludesVAT,
	|	ISNULL(CatalogUOM.Description, CatalogUOMClassifier.Description),
	|	FilteredInventory.Price,
	|	SupplierInvoice.IncomingDocumentNumber,
	|	SupplierInvoice.IncomingDocumentDate
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CASE
	|		WHEN Header.AmountIncludesVAT
	|			THEN Header.DocumentAmount - Header.VATAmount
	|		ELSE Header.DocumentAmount
	|	END AS Amount,
	|	Header.VATRate AS VATRate,
	|	Header.Ref AS Ref,
	|	Header.CompanyLogoFile AS CompanyLogoFile,
	|	Header.DocumentDate AS DocumentDate,
	|	Header.DocumentNumber AS DocumentNumber,
	|	Header.Comment AS Comment,
	|	Header.Company AS Company,
	|	Header.Counterparty AS Counterparty,
	|	CASE
	|		WHEN Header.AmountIncludesVAT
	|			THEN Header.DocumentAmount
	|		ELSE Header.DocumentAmount + Header.VATAmount
	|	END AS Total,
	|	1 AS LineNumber,
	|	Header.DocumentCurrency AS DocumentCurrency,
	|	Header.VATAmount AS VATAmount,
	|	CASE
	|		WHEN Header.AmountIncludesVAT
	|			THEN Header.DocumentAmount - Header.VATAmount
	|		ELSE Header.DocumentAmount
	|	END AS SubTotal,
	|	DebitNoteDebitedTransactions.Document AS Document,
	|	Header.DocumentNumber AS IncomingNumber,
	|	Header.DocumentDate AS IncomingDate
	|FROM
	|	Header AS Header
	|		INNER JOIN Document.DebitNote.DebitedTransactions AS DebitNoteDebitedTransactions
	|		ON Header.Ref = DebitNoteDebitedTransactions.Ref
	|			AND (DebitNoteDebitedTransactions.Document REFS Document.DebitNote
	|				OR DebitNoteDebitedTransactions.Document REFS Document.ExpenseReport)
	|WHERE
	|	Header.OperationKind <> VALUE(Enum.OperationTypesDebitNote.PurchaseReturn)
	|
	|UNION ALL
	|
	|SELECT
	|	CASE
	|		WHEN Header.AmountIncludesVAT
	|			THEN Header.DocumentAmount - Header.VATAmount
	|		ELSE Header.DocumentAmount
	|	END,
	|	Header.VATRate,
	|	Header.Ref,
	|	Header.CompanyLogoFile,
	|	Header.DocumentDate,
	|	Header.DocumentNumber,
	|	Header.Comment,
	|	Header.Company,
	|	Header.Counterparty,
	|	CASE
	|		WHEN Header.AmountIncludesVAT
	|			THEN Header.DocumentAmount
	|		ELSE Header.DocumentAmount + Header.VATAmount
	|	END,
	|	1,
	|	Header.DocumentCurrency,
	|	Header.VATAmount,
	|	CASE
	|		WHEN Header.AmountIncludesVAT
	|			THEN Header.DocumentAmount - Header.VATAmount
	|		ELSE Header.DocumentAmount
	|	END,
	|	DebitNoteDebitedTransactions.Document,
	|	AdditionalExpenses.IncomingDocumentNumber,
	|	AdditionalExpenses.IncomingDocumentDate
	|FROM
	|	Header AS Header
	|		INNER JOIN Document.DebitNote.DebitedTransactions AS DebitNoteDebitedTransactions
	|			INNER JOIN Document.AdditionalExpenses AS AdditionalExpenses
	|			ON DebitNoteDebitedTransactions.Document = AdditionalExpenses.Ref
	|		ON Header.Ref = DebitNoteDebitedTransactions.Ref
	|			AND (DebitNoteDebitedTransactions.Document REFS Document.AdditionalExpenses)
	|WHERE
	|	Header.OperationKind <> VALUE(Enum.OperationTypesDebitNote.PurchaseReturn)
	|
	|UNION ALL
	|
	|SELECT
	|	CASE
	|		WHEN Header.AmountIncludesVAT
	|			THEN Header.DocumentAmount - Header.VATAmount
	|		ELSE Header.DocumentAmount
	|	END,
	|	Header.VATRate,
	|	Header.Ref,
	|	Header.CompanyLogoFile,
	|	Header.DocumentDate,
	|	Header.DocumentNumber,
	|	Header.Comment,
	|	Header.Company,
	|	Header.Counterparty,
	|	CASE
	|		WHEN Header.AmountIncludesVAT
	|			THEN Header.DocumentAmount
	|		ELSE Header.DocumentAmount + Header.VATAmount
	|	END,
	|	1,
	|	Header.DocumentCurrency,
	|	Header.VATAmount,
	|	CASE
	|		WHEN Header.AmountIncludesVAT
	|			THEN Header.DocumentAmount - Header.VATAmount
	|		ELSE Header.DocumentAmount
	|	END,
	|	DebitNoteDebitedTransactions.Document,
	|	SupplierInvoice.IncomingDocumentNumber,
	|	SupplierInvoice.IncomingDocumentDate
	|FROM
	|	Header AS Header
	|		INNER JOIN Document.DebitNote.DebitedTransactions AS DebitNoteDebitedTransactions
	|			INNER JOIN Document.SupplierInvoice AS SupplierInvoice
	|			ON DebitNoteDebitedTransactions.Document = SupplierInvoice.Ref
	|		ON Header.Ref = DebitNoteDebitedTransactions.Ref
	|			AND (DebitNoteDebitedTransactions.Document REFS Document.SupplierInvoice)
	|WHERE
	|	Header.OperationKind <> VALUE(Enum.OperationTypesDebitNote.PurchaseReturn)
	|TOTALS
	|	MAX(Amount),
	|	MAX(VATRate),
	|	MAX(CompanyLogoFile),
	|	MAX(DocumentDate),
	|	MAX(DocumentNumber),
	|	MAX(Comment),
	|	MAX(Company),
	|	MAX(Counterparty),
	|	MAX(Total),
	|	MAX(LineNumber),
	|	MAX(DocumentCurrency),
	|	MAX(VATAmount),
	|	MAX(SubTotal)
	|BY
	|	Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Inventory.Ref AS Ref,
	|	Inventory.DocumentNumber AS DocumentNumber,
	|	Inventory.DocumentDate AS DocumentDate,
	|	Inventory.Company AS Company,
	|	Inventory.CompanyLogoFile AS CompanyLogoFile,
	|	Inventory.Counterparty AS Counterparty,
	|	Inventory.Contract AS Contract,
	|	Inventory.CounterpartyContactPerson AS CounterpartyContactPerson,
	|	Inventory.AmountIncludesVAT AS AmountIncludesVAT,
	|	Inventory.DocumentCurrency AS DocumentCurrency,
	|	Inventory.Comment AS Comment,
	|	Inventory.LineNumber AS LineNumber,
	|	Inventory.SKU AS SKU,
	|	Inventory.UseSerialNumbers AS UseSerialNumbers,
	|	Inventory.UOM AS UOM,
	|	Inventory.Quantity AS Quantity,
	|	CASE
	|		WHEN Inventory.AmountIncludesVAT
	|				AND Inventory.Price > 0
	|			THEN Inventory.Price - Inventory.VATAmount / Inventory.Quantity
	|		ELSE Inventory.Price
	|	END AS Price,
	|	Inventory.Amount AS Amount,
	|	Inventory.VATRate AS VATRate,
	|	Inventory.VATAmount AS VATAmount,
	|	Inventory.Total AS Total,
	|	Inventory.Subtotal AS Subtotal,
	|	Inventory.Subtotal - Inventory.Amount AS DiscountAmount,
	|	Inventory.ProductDescription AS ProductDescription,
	|	Inventory.ContentUsed AS ContentUsed,
	|	Inventory.Invoice AS Invoice,
	|	Inventory.OperationKind AS OperationKind,
	|	Inventory.ConnectionKey AS ConnectionKey,
	|	Inventory.Batch AS Batch,
	|	Inventory.Characteristic AS Characteristic,
	|	Inventory.MeasurementUnit AS MeasurementUnit,
	|	Inventory.CharacteristicDescription AS CharacteristicDescription,
	|	Inventory.BatchDescription AS BatchDescription,
	|	Inventory.IncomingNumber AS IncomingNumber,
	|	Inventory.IncomingDate AS IncomingDate
	|FROM
	|	Inventory AS Inventory
	|
	|ORDER BY
	|	Inventory.DocumentNumber
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
	|	MAX(Invoice),
	|	MAX(OperationKind),
	|	MAX(IncomingNumber),
	|	MAX(IncomingDate)
	|BY
	|	Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Inventory.Ref AS Ref,
	|	Inventory.VATRate AS VATRate,
	|	SUM(Inventory.Subtotal) AS Amount,
	|	SUM(Inventory.VATAmount) AS VATAmount
	|FROM
	|	Inventory AS Inventory
	|
	|GROUP BY
	|	Inventory.Ref,
	|	Inventory.VATRate
	|TOTALS BY
	|	Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Inventory.ConnectionKey AS ConnectionKey,
	|	Inventory.Ref AS Ref,
	|	SerialNumbers.Description AS SerialNumber
	|FROM
	|	FilteredInventory AS FilteredInventory
	|		INNER JOIN Inventory AS Inventory
	|		ON FilteredInventory.Products = Inventory.Products
	|			AND FilteredInventory.Price = Inventory.Price
	|			AND FilteredInventory.VATRate = Inventory.VATRate
	|			AND (NOT Inventory.ContentUsed)
	|			AND FilteredInventory.Ref = Inventory.Ref
	|			AND FilteredInventory.Characteristic = Inventory.Characteristic
	|			AND FilteredInventory.Batch = Inventory.Batch
	|			AND FilteredInventory.MeasurementUnit = Inventory.MeasurementUnit
	|		INNER JOIN Document.CreditNote.SerialNumbers AS CreditNoteSerialNumbers
	|			LEFT JOIN Catalog.SerialNumbers AS SerialNumbers
	|			ON CreditNoteSerialNumbers.SerialNumber = SerialNumbers.Ref
	|		ON (CreditNoteSerialNumbers.ConnectionKey = FilteredInventory.ConnectionKey)
	|			AND FilteredInventory.Ref = CreditNoteSerialNumbers.Ref";
	
	#EndRegion
	
	ResultArray = Query.ExecuteBatch();
	
	FirstDocument = True;
	SpreadsheetDocument.PrintParametersName = "PRINT_PARAMETERS_DebitNote";
	Template = PrintManagement.PrintedFormsTemplate("Document.DebitNote.PF_MXL_DebitNote");
	
	Header				= ResultArray[4].Select(QueryResultIteration.ByGroupsWithHierarchy);
	Inventory			= ResultArray[5].Select(QueryResultIteration.ByGroupsWithHierarchy);
	TaxesHeaderSel		= ResultArray[6].Select(QueryResultIteration.ByGroupsWithHierarchy);
	SerialNumbersSel	= ResultArray[7].Select(QueryResultIteration.ByGroupsWithHierarchy);
	
	While Header.Next() Do

		If Not FirstDocument Then
			SpreadsheetDocument.PutHorizontalPageBreak();
		EndIf;
		FirstDocument = False;
		
		FirstLineNumber = SpreadsheetDocument.TableHeight + 1;
		
		TitleArea = GetArea("Title", Template, Header);
		SpreadsheetDocument.Put(TitleArea);
		
		CompanyInfoArea = GetArea("CompanyInfo", Template, Header);
		SpreadsheetDocument.Put(CompanyInfoArea);

		Transactions = "";
		
		TabSelection = Header.Select();
		While TabSelection.Next() Do
			If ValueIsFilled(TabSelection.IncomingNumber) Then
				Transactions = TrimAll(Transactions) + ?(IsBlankString(Transactions), "", "; ");
				Presentation = StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = '%1 dated %2'"),
					ObjectPrefixationClientServer.GetNumberForPrinting(TabSelection.IncomingNumber, True, True),
					Format(TabSelection.IncomingDate, "DLF=D"));
				Transactions = Transactions + Presentation;
			EndIf;
		EndDo;
		
		CounterpartyInfoArea = GetArea("CounterpartyInfo", Template, Header);
		CounterpartyInfoArea.Parameters.Invoice = Transactions;
		SpreadsheetDocument.Put(CounterpartyInfoArea);
		
		CommentArea = GetArea("Comment", Template, Header);
		SpreadsheetDocument.Put(CommentArea);
		
		#Region PrintDebitNoteLinesArea
		
		LineHeaderArea = Template.GetArea("LineHeaderDiscAllowed");
		SpreadsheetDocument.Put(LineHeaderArea);
		
		LineSectionArea	= Template.GetArea("LineSectionDiscAllowed");
		LineSectionArea.Parameters.Fill(Header);
		LineSectionArea.Parameters.ReasonForCorrection = CommonUse.ObjectAttributeValue(Header.Ref, "ReasonForCorrection");
		SpreadsheetDocument.Put(LineSectionArea);
		
		#EndRegion
		
		#Region PrintDebitNoteTotalsArea
		
		LineTotalArea = Template.GetArea("LineTotal");
		LineTotalArea.Parameters.Fill(Header);
		SpreadsheetDocument.Put(LineTotalArea);
		
		PageNumber = 1;
		
		EmptyLineArea	= Template.GetArea("EmptyLine");
		PageNumberArea	= Template.GetArea("PageNumber");
		
		AreasToBeChecked = New Array;
		AreasToBeChecked.Add(EmptyLineArea);
		AreasToBeChecked.Add(PageNumberArea);
		
		For i = 1 To 50 Do
			
			If Not CommonUse.SpreadsheetDocumentFitsPage(SpreadsheetDocument, AreasToBeChecked)
				Or i = 50 Then
				
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
	
	While Inventory.Next() Do
		
		If Not FirstDocument Then
			SpreadsheetDocument.PutHorizontalPageBreak();
		EndIf;
		FirstDocument = False;
		
		FirstLineNumber = SpreadsheetDocument.TableHeight + 1;
		
		TitleArea = GetArea("Title", Template, Inventory);
		SpreadsheetDocument.Put(TitleArea);
		
		CompanyInfoArea = GetArea("CompanyInfo", Template, Inventory);
		SpreadsheetDocument.Put(CompanyInfoArea);

		CounterpartyInfoArea = GetArea("CounterpartyInfo", Template, Inventory);
		If ValueIsFilled(Inventory.IncomingNumber) Then
			Invoice = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = '%1 dated %2'"),
				ObjectPrefixationClientServer.GetNumberForPrinting(Inventory.IncomingNumber, True, True),
				Format(Inventory.IncomingDate, "DLF=D"));
		EndIf;
		CounterpartyInfoArea.Parameters.Invoice = Invoice;
		SpreadsheetDocument.Put(CounterpartyInfoArea);
		
		#Region PrintDebitNoteReasonForCorrectionArea
		
		ReasonForCorrectionArea = Template.GetArea("ReasonForCorrection");
		ReasonForCorrectionArea.Parameters.ReasonForCorrection = CommonUse.ObjectAttributeValue(Inventory.Ref,
																								"ReasonForCorrection");
		SpreadsheetDocument.Put(ReasonForCorrectionArea);
		
		#EndRegion
		
		CommentArea = GetArea("Comment", Template, Inventory);
		SpreadsheetDocument.Put(CommentArea);
		
		#Region PrintDebitNoteTotalsAndTaxesAreaPrefill
		
		TotalsAndTaxesAreasArray = New Array;
		
		LineTotalArea = Template.GetArea("LineTotal");
		LineTotalArea.Parameters.Fill(Inventory);
		
		TotalsAndTaxesAreasArray.Add(LineTotalArea);
		
		TaxesHeaderSel.Reset();
		If TaxesHeaderSel.FindNext(New Structure("Ref", Inventory.Ref)) Then
			
			TaxSectionHeaderArea = Template.GetArea("TaxSectionHeader");
			TotalsAndTaxesAreasArray.Add(TaxSectionHeaderArea);
			
			TaxesSel = TaxesHeaderSel.Select();
			While TaxesSel.Next() Do
				
				TaxSectionLineArea = Template.GetArea("TaxSectionLine");
				TaxSectionLineArea.Parameters.Fill(TaxesSel);
				TotalsAndTaxesAreasArray.Add(TaxSectionLineArea);
				
			EndDo;
			
		EndIf;
		
		#EndRegion
		
		#Region PrintDebitNoteLinesArea
		
		LineHeaderArea = Template.GetArea("LineHeader");
		SpreadsheetDocument.Put(LineHeaderArea);
		
		LineSectionArea	= Template.GetArea("LineSection");
		SeeNextPageArea	= Template.GetArea("SeeNextPage");
		EmptyLineArea	= Template.GetArea("EmptyLine");
		PageNumberArea	= Template.GetArea("PageNumber");
		
		PageNumber = 0;
		
		TabSelection = Inventory.Select();
		While TabSelection.Next() Do
			
			LineSectionArea.Parameters.Fill(TabSelection);
			
			PrintManagement.ComplimentProductDescription(LineSectionArea.Parameters.ProductDescription, TabSelection, SerialNumbersSel);
			
			AreasToBeChecked = New Array;
			AreasToBeChecked.Add(LineSectionArea);
			For Each Area In TotalsAndTaxesAreasArray Do
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
		
		#Region PrintDebitNoteTotalsAndTaxesArea
		
		For Each Area In TotalsAndTaxesAreasArray Do
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
		
		PrintManagement.SetDocumentPrintArea(SpreadsheetDocument, FirstLineNumber, PrintObjects, Inventory.Ref);
		
	EndDo;
	
	SpreadsheetDocument.FitToPage = True;
	
	Return SpreadsheetDocument;
	
EndFunction

Function GetArea(AreaName, Template, Selection)
	
	Area = Template.GetArea(AreaName);
	
	If AreaName = "Title" Then
		
		Area.Parameters.Fill(Selection);
		If ValueIsFilled(Selection.CompanyLogoFile) Then
			PictureData = AttachedFiles.GetFileBinaryData(Selection.CompanyLogoFile);
			
			If ValueIsFilled(PictureData) Then
				Area.Drawings.Logo.Picture = New Picture(PictureData);
			EndIf;
		Else
			Area.Drawings.Delete(Area.Drawings.Logo);
		EndIf;
		
	ElsIf AreaName = "CompanyInfo" Then
		
		InfoAboutCompany = DriveServer.InfoAboutLegalEntityIndividual(Selection.Company, Selection.DocumentDate, ,);
		Area.Parameters.Fill(InfoAboutCompany);
		
	ElsIf AreaName = "CounterpartyInfo" Then
		
		InfoAboutCounterparty = DriveServer.InfoAboutLegalEntityIndividual(Selection.Counterparty, Selection.DocumentDate, ,);
		Area.Parameters.Fill(InfoAboutCounterparty);
		
	ElsIf AreaName = "Comment" Then
		
		Area.Parameters.Fill(Selection);
		
	EndIf;
		
	Return Area;
	
EndFunction

#EndRegion

#Region InfobaseUpdate

Procedure FillingInventoryTotal() Export
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	DebitNote.Ref AS Ref,
	|	DebitNote.OperationKind AS OperationKind,
	|	DebitNote.BasisDocument AS BasisDocument
	|FROM
	|	Document.DebitNote AS DebitNote
	|WHERE
	|	DebitNote.DocumentAmount = 0
	|	AND DebitNote.AdjustmentAmount <> 0";
	
	QueryResult = Query.Execute();
	Selection	= QueryResult.Select();
	
	While Selection.Next() Do
		DocObject = Selection.Ref.GetObject();
		If Selection.OperationKind = Enums.OperationTypesDebitNote.PurchaseReturn Then
			If TypeOf(Selection.BasisDocument) = Type("DocumentRef.GoodsReturn") 
				AND DocObject.AmountIncludesVAT <> Selection.BasisDocument.AmountIncludesVAT Then
				DocObject.AmountIncludesVAT = Selection.BasisDocument.AmountIncludesVAT;
			EndIf;
			
			For Each Row In DocObject.Inventory Do
				If Row.Total = 0 Then
					Row.Total = Row.Amount + ?(DocObject.AmountIncludesVAT, 0, Row.VATAmount);
				EndIf;
			EndDo;
			DocObject.AdjustmentAmount = DocObject.Inventory.Total("Total");
		Else
			If DocObject.AmountIncludesVAT Then
				DocObject.DocumentAmount = DocObject.AdjustmentAmount;
			Else
				DocObject.DocumentAmount = DocObject.AdjustmentAmount + DocObject.VATAmount;
				DocObject.FillAmountAllocation();
			EndIf;
		EndIf;
		
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

Procedure FillNewGLAccounts() Export
	
	DocumentName = "DebitNote";
	
	Tables = New Array();
	TableDecription = New Structure("Name, Conditions", "Inventory", New Array());
	
	GLAccountFields = ChartsOfAccounts.PrimaryChartOfAccounts.GLAccountFields();
	GLAccountFields.Source = "Products.InventoryGLAccount";
	GLAccountFields.Receiver = "InventoryGLAccount";
	TableDecription.Conditions.Add(GLAccountFields);
	
	GLAccountFields = ChartsOfAccounts.PrimaryChartOfAccounts.GLAccountFields();
	GLAccountFields.Source = "&VATInputGLAccount";
	GLAccountFields.Receiver = "VATInputGLAccount";
	GLAccountFields.Parameter = Catalogs.DefaultGLAccounts.GetDefaultGLAccount("VATInput");
	TableDecription.Conditions.Add(GLAccountFields);
	
	GLAccountFields = ChartsOfAccounts.PrimaryChartOfAccounts.GLAccountFields();
	GLAccountFields.Source = "Ref.GLAccount";
	GLAccountFields.Receiver = "PurchaseReturnGLAccount";
	TableDecription.Conditions.Add(GLAccountFields);
	
	Tables.Add(TableDecription);
	
	ChartsOfAccounts.PrimaryChartOfAccounts.FillNewGLAccounts(DocumentName, Tables);
	
EndProcedure

#EndRegion

#EndIf