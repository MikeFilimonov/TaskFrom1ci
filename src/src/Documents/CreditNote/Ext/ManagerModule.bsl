#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableSales(DocumentRefCreditNote, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	TableSales.Period AS Period,
	|	TableSales.Recorder AS Recorder,
	|	TableSales.Products AS Products,
	|	TableSales.Characteristic AS Characteristic,
	|	TableSales.Batch AS Batch,
	|	CASE
	|		WHEN VALUETYPE(TableSales.BasisDocument) = TYPE(Document.GoodsReturn)
	|			THEN TableSales.SalesInvoice
	|		WHEN VALUETYPE(TableSales.BasisDocument) = TYPE(Document.SalesSlip)
	|				AND TableSales.Archival
	|			THEN TableSales.ShiftClosure
	|		ELSE TableSales.BasisDocument
	|	END AS Document,
	|	TableSales.Company AS Company,
	|	CASE
	|		WHEN TableSales.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|				AND TableSales.Order <> VALUE(Document.WorkOrder.EmptyRef)
	|			THEN TableSales.Order
	|		ELSE UNDEFINED
	|	END AS SalesOrder,
	|	TableSales.SalesRep AS SalesRep,
	|	TableSales.Department AS Department,
	|	-TableSales.ReturnQuantity AS Quantity,
	|	-TableSales.AdjustmentAmount AS Amount,
	|	TableSales.VATRate AS VATRate,
	|	-TableSales.VATAmount AS VATAmount,
	|	CASE
	|		WHEN VALUETYPE(TableSales.BasisDocument) = TYPE(Document.SalesSlip)
	|			THEN 0
	|		WHEN &FillAmount
	|			THEN -TableSales.CostOfGoodsSold
	|	END AS Cost,
	|	TableSales.Responsible AS Responsible,
	|	FALSE AS OfflineRecord
	|FROM
	|	TemporaryTableInventory AS TableSales
	|
	|UNION ALL
	|
	|SELECT
	|	TableSales.Period,
	|	TableSales.Recorder,
	|	TableSales.Products,
	|	TableSales.Characteristic,
	|	TableSales.Batch,
	|	TableSales.ShiftClosure,
	|	TableSales.Company,
	|	CASE
	|		WHEN TableSales.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|				AND TableSales.Order <> VALUE(Document.WorkOrder.EmptyRef)
	|			THEN TableSales.Order
	|		ELSE UNDEFINED
	|	END,
	|	TableSales.SalesRep,
	|	TableSales.Department,
	|	0,
	|	0,
	|	TableSales.VATRate,
	|	0,
	|	-TableSales.CostOfGoodsSold,
	|	TableSales.Responsible,
	|	FALSE
	|FROM
	|	TemporaryTableInventory AS TableSales
	|WHERE
	|	VALUETYPE(TableSales.BasisDocument) = TYPE(Document.SalesSlip)
	|	AND TableSales.CostOfGoodsSold <> 0
	|	AND &FillAmount
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
	|	OfflineRecords.SalesRep,
	|	OfflineRecords.Department,
	|	OfflineRecords.Quantity,
	|	OfflineRecords.Amount,
	|	OfflineRecords.VATRate,
	|	OfflineRecords.VATAmount,
	|	OfflineRecords.Cost,
	|	OfflineRecords.Responsible,
	|	OfflineRecords.OfflineRecord
	|FROM
	|	AccumulationRegister.Sales AS OfflineRecords
	|WHERE
	|	OfflineRecords.Recorder = &Ref
	|	AND OfflineRecords.OfflineRecord";
	
	Query.SetParameter("Ref", DocumentRefCreditNote);
	FillAmount = (StructureAdditionalProperties.AccountingPolicy.InventoryValuationMethod = Enums.InventoryValuationMethods.WeightedAverage);
	Query.SetParameter("FillAmount", FillAmount);
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSales", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableAccountsReceivable(DocumentRefCreditNote, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref",					DocumentRefCreditNote);
	Query.SetParameter("PointInTime",			New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod",			StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("ExchangeDifference",	NStr("en = 'Foreign currency exchange gains and losses'",
													CommonUseClientServer.MainLanguageCode()));
	Query.Text =
	"SELECT
	|	TableAccountsReceivable.Period AS Date,
	|	TableAccountsReceivable.LineNumber AS LineNumber,
	|	TableAccountsReceivable.Recorder AS Recorder,
	|	TableAccountsReceivable.Company AS Company,
	|	CASE
	|		WHEN TableAccountsReceivable.AdvanceFlag
	|			THEN VALUE(Enum.SettlementsTypes.Advance)
	|		ELSE VALUE(Enum.SettlementsTypes.Debt)
	|	END AS SettlementsType,
	|	TableAccountsReceivable.Currency AS Currency,
	|	TableAccountsReceivable.Counterparty AS Counterparty,
	|	TableAccountsReceivable.Contract AS Contract,
	|	TableAccountsReceivable.Document AS Document,
	|	CASE
	|		WHEN TableAccountsReceivable.Order = VALUE(Document.SalesOrder.EmptyRef)
	|				OR TableAccountsReceivable.Order = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE TableAccountsReceivable.Order
	|	END AS Order,
	|	CASE
	|		WHEN TableAccountsReceivable.AdvanceFlag
	|			THEN TableAccountsReceivable.CustomerAdvancesGLAccount
	|		ELSE TableAccountsReceivable.GLAccountCustomerSettlements
	|	END AS GLAccount,
	|	TableAccountsReceivable.Amount AS Amount,
	|	TableAccountsReceivable.OffsetAmount AS PaymentAmount,
	|	TableAccountsReceivable.OffsetAmount AS AmountCur,
	|	TableAccountsReceivable.Amount AS AmountForPayment,
	|	TableAccountsReceivable.OffsetAmount AS AmountForPaymentCur,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableAccountsReceivable.OperationKind AS ContentOfAccountingRecord,
	|	-TableAccountsReceivable.Amount AS AmountForBalance,
	|	-TableAccountsReceivable.OffsetAmount AS AmountCurForBalance
	|INTO TemporaryTableAccountsReceivable
	|FROM
	|	TemporaryTableAmountAllocation AS TableAccountsReceivable";
	
	QueryResult = Query.Execute();
	
	QueryNumber = 0;
	Query.Text = DriveServer.GetQueryTextCurrencyExchangeRateAccountsReceivable(Query.TempTablesManager, False, QueryNumber);
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountsReceivable", ResultsArray[QueryNumber].Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableIncomeAndExpenses(DocumentRefCreditNote, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.SetParameter("Ref", 											DocumentRefCreditNote);
	Query.SetParameter("PositiveExchangeDifferenceGLAccount",			Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeGain"));
	Query.SetParameter("NegativeExchangeDifferenceAccountOfAccounting", Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeLoss"));
	Query.SetParameter("ExchangeDifference",							NStr("en = 'Foreign currency exchange gains and losses'",
																			CommonUseClientServer.MainLanguageCode()));
	FillAmount = (StructureAdditionalProperties.AccountingPolicy.InventoryValuationMethod = Enums.InventoryValuationMethods.WeightedAverage);
	Query.SetParameter("FillAmount", FillAmount);
	
	Query.Text =
	"SELECT
	|	TableIncomeAndExpenses.Period AS Period,
	|	TableIncomeAndExpenses.Recorder AS Recorder,
	|	TableIncomeAndExpenses.Company AS Company,
	|	TableIncomeAndExpenses.Department AS StructuralUnit,
	|	TableIncomeAndExpenses.BusinessLine AS BusinessLine,
	|	TableIncomeAndExpenses.Order AS SalesOrder,
	|	CASE
	|		WHEN TableIncomeAndExpenses.OperationKind = VALUE(Enum.OperationTypesCreditNote.SalesReturn)
	|			THEN TemporaryTableInventory.GLAccount
	|		ELSE TableIncomeAndExpenses.GLAccount
	|	END AS GLAccount,
	|	CASE
	|		WHEN TableIncomeAndExpenses.OperationKind = VALUE(Enum.OperationTypesCreditNote.SalesReturn)
	|			THEN -TableIncomeAndExpenses.Amount
	|		ELSE 0
	|	END AS AmountIncome,
	|	CASE
	|		WHEN TableIncomeAndExpenses.OperationKind = VALUE(Enum.OperationTypesCreditNote.SalesReturn)
	|			THEN 0
	|		ELSE TableIncomeAndExpenses.Amount
	|	END AS AmountExpense,
	|	TableIncomeAndExpenses.OperationKind AS ContentOfAccountingRecord
	|INTO TableIncomeAndExpenses
	|FROM
	|	TemporaryTableHeader AS TableIncomeAndExpenses
	|		LEFT JOIN TemporaryTableInventory AS TemporaryTableInventory
	|		ON TableIncomeAndExpenses.Recorder = TemporaryTableInventory.Recorder
	|
	|UNION ALL
	|
	|SELECT
	|	Cost.Period,
	|	Cost.Recorder,
	|	Cost.Company,
	|	Cost.Department,
	|	Cost.BusinessLine,
	|	Cost.Order,
	|	Cost.GLAccountCostOfSales,
	|	0,
	|	-Cost.CostOfGoodsSold,
	|	Cost.OperationKind
	|FROM
	|	TemporaryTableInventory AS Cost
	|WHERE
	|	Cost.CostOfGoodsSold > 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DocumentTable.Date AS Date,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.AmountOfExchangeDifferences AS AmountOfExchangeDifferences
	|INTO TableExchangeRateDifferencesAccountsReceivable
	|FROM
	|	TemporaryTableExchangeRateDifferencesAccountsReceivable AS DocumentTable
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
	|	TemporaryTableExchangeRateDifferencesAccountsReceivable AS DocumentTable
	|WHERE
	|	DocumentTable.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableExchangeRateDifferencesAccountsReceivable.Date AS Date,
	|	TableExchangeRateDifferencesAccountsReceivable.Company AS Company,
	|	&Ref AS Ref,
	|	SUM(TableExchangeRateDifferencesAccountsReceivable.AmountOfExchangeDifferences) AS AmountOfExchangeDifferences
	|INTO GroupedTableExchangeRateDifferencesAccountsReceivable
	|FROM
	|	TableExchangeRateDifferencesAccountsReceivable AS TableExchangeRateDifferencesAccountsReceivable
	|
	|GROUP BY
	|	TableExchangeRateDifferencesAccountsReceivable.Date,
	|	TableExchangeRateDifferencesAccountsReceivable.Company
	|
	|HAVING
	|	(SUM(TableExchangeRateDifferencesAccountsReceivable.AmountOfExchangeDifferences) >= 0.005
	|		OR SUM(TableExchangeRateDifferencesAccountsReceivable.AmountOfExchangeDifferences) <= -0.005)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableIncomeAndExpenses.Period AS Period,
	|	TableIncomeAndExpenses.Recorder AS Recorder,
	|	TableIncomeAndExpenses.Company AS Company,
	|	TableIncomeAndExpenses.StructuralUnit AS StructuralUnit,
	|	TableIncomeAndExpenses.BusinessLine AS BusinessLine,
	|	CASE
	|		WHEN TableIncomeAndExpenses.SalesOrder = VALUE(Document.SalesOrder.EmptyRef)
	|				OR TableIncomeAndExpenses.SalesOrder = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE TableIncomeAndExpenses.SalesOrder
	|	END AS SalesOrder,
	|	TableIncomeAndExpenses.GLAccount AS GLAccount,
	|	SUM(TableIncomeAndExpenses.AmountIncome) AS AmountIncome,
	|	SUM(TableIncomeAndExpenses.AmountExpense) AS AmountExpense,
	|	TableIncomeAndExpenses.ContentOfAccountingRecord AS ContentOfAccountingRecord,
	|	FALSE AS OfflineRecord
	|FROM
	|	TableIncomeAndExpenses AS TableIncomeAndExpenses
	|WHERE
	|	(TableIncomeAndExpenses.AmountIncome <> 0
	|			OR &FillAmount)
	|
	|GROUP BY
	|	TableIncomeAndExpenses.Company,
	|	TableIncomeAndExpenses.StructuralUnit,
	|	TableIncomeAndExpenses.Recorder,
	|	TableIncomeAndExpenses.SalesOrder,
	|	TableIncomeAndExpenses.GLAccount,
	|	TableIncomeAndExpenses.ContentOfAccountingRecord,
	|	TableIncomeAndExpenses.BusinessLine,
	|	TableIncomeAndExpenses.Period
	|
	|UNION ALL
	|
	|SELECT
	|	GroupedTableExchangeRateDifferencesAccountsReceivable.Date,
	|	GroupedTableExchangeRateDifferencesAccountsReceivable.Ref,
	|	GroupedTableExchangeRateDifferencesAccountsReceivable.Company,
	|	TableDocument.Department,
	|	TableDocument.BusinessLine,
	|	CASE
	|		WHEN TableDocument.Order = VALUE(Document.SalesOrder.EmptyRef)
	|				OR TableDocument.Order = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE TableDocument.Order
	|	END,
	|	CASE
	|		WHEN GroupedTableExchangeRateDifferencesAccountsReceivable.AmountOfExchangeDifferences > 0
	|			THEN &PositiveExchangeDifferenceGLAccount
	|		ELSE &NegativeExchangeDifferenceAccountOfAccounting
	|	END,
	|	CASE
	|		WHEN GroupedTableExchangeRateDifferencesAccountsReceivable.AmountOfExchangeDifferences > 0
	|			THEN GroupedTableExchangeRateDifferencesAccountsReceivable.AmountOfExchangeDifferences
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN GroupedTableExchangeRateDifferencesAccountsReceivable.AmountOfExchangeDifferences > 0
	|			THEN 0
	|		ELSE -GroupedTableExchangeRateDifferencesAccountsReceivable.AmountOfExchangeDifferences
	|	END,
	|	&ExchangeDifference,
	|	FALSE
	|FROM
	|	GroupedTableExchangeRateDifferencesAccountsReceivable AS GroupedTableExchangeRateDifferencesAccountsReceivable
	|		INNER JOIN TemporaryTableHeader AS TableDocument
	|		ON (TableDocument.Recorder = GroupedTableExchangeRateDifferencesAccountsReceivable.Ref)
	|WHERE
	|	&FillAmount
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
	|DROP TableExchangeRateDifferencesAccountsReceivable";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpenses", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableAccountingJournalEntries(DocumentRefCreditNote, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.SetParameter("Ref", 							DocumentRefCreditNote);
	Query.SetParameter("ForeignCurrencyExchangeGain",	Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeGain")); 
	Query.SetParameter("ForeignCurrencyExchangeLoss",	Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeLoss"));
	Query.SetParameter("ExchangeDifference",			NStr("en = 'Foreign currency exchange gains and losses'",
															CommonUseClientServer.MainLanguageCode()));
	FillAmount = (StructureAdditionalProperties.AccountingPolicy.InventoryValuationMethod = Enums.InventoryValuationMethods.WeightedAverage);
	Query.SetParameter("FillAmount", FillAmount);
	
	Query.Text =
	"SELECT
	|	TableAccountingJournalEntries.Period AS Period,
	|	TableAccountingJournalEntries.Recorder AS Recorder,
	|	TableAccountingJournalEntries.Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	CASE
	|		WHEN TableAccountingJournalEntries.OperationKind = VALUE(Enum.OperationTypesCreditNote.SalesReturn)
	|			THEN TemporaryTableInventory.GLAccount
	|		ELSE TableAccountingJournalEntries.GLAccount
	|	END AS AccountDr,
	|	CASE
	|		WHEN TableAccountingJournalEntries.OperationKind = VALUE(Enum.OperationTypesCreditNote.SalesReturn)
	|					AND TemporaryTableInventory.GLAccount.Currency
	|				OR TableAccountingJournalEntries.GLAccount.Currency
	|			THEN TableAccountingJournalEntries.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN TableAccountingJournalEntries.OperationKind = VALUE(Enum.OperationTypesCreditNote.SalesReturn)
	|				AND TemporaryTableInventory.GLAccount.Currency
	|			THEN TemporaryTableInventory.AmountCur
	|		WHEN TableAccountingJournalEntries.GLAccount.Currency
	|			THEN TableAccountingJournalEntries.AmountCur
	|		ELSE 0
	|	END AS AmountCurDr,
	|	TableAccountingJournalEntries.GLAccountCustomerSettlements AS AccountCr,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccountCustomerSettlements.Currency
	|			THEN TableAccountingJournalEntries.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccountCustomerSettlements.Currency
	|			THEN TableAccountingJournalEntries.AmountCur
	|		ELSE 0
	|	END AS AmountCurCr,
	|	CASE
	|		WHEN TableAccountingJournalEntries.OperationKind = VALUE(Enum.OperationTypesCreditNote.SalesReturn)
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
	|	CASE
	|		WHEN TableAccountingJournalEntries.OperationKind = VALUE(Enum.OperationTypesCreditNote.SalesReturn)
	|			THEN TemporaryTableInventory.VATOutputGLAccount
	|		ELSE DefaultGLAccounts.GLAccount
	|	END,
	|	UNDEFINED,
	|	0,
	|	TableAccountingJournalEntries.GLAccountCustomerSettlements,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccountCustomerSettlements.Currency
	|			THEN TableAccountingJournalEntries.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccountCustomerSettlements.Currency
	|			THEN TableAccountingJournalEntries.VATAmountCur
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN TableAccountingJournalEntries.OperationKind = VALUE(Enum.OperationTypesCreditNote.SalesReturn)
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
	|	UngroupedTable.CurrencyDr,
	|	UngroupedTable.PlanningPeriod,
	|	UngroupedTable.AccountDr,
	|	UngroupedTable.OfflineRecord,
	|	UngroupedTable.AccountCr,
	|	UngroupedTable.CurrencyCr,
	|	UngroupedTable.Period,
	|	UngroupedTable.Recorder,
	|	UngroupedTable.Company,
	|	UngroupedTable.Content";
	
	If DocumentRefCreditNote.OperationKind = Enums.OperationTypesCreditNote.SalesReturn 
		AND Not StructureAdditionalProperties.AccountingPolicy.UseGoodsReturnFromCustomer Then
		
		Query.Text = Query.Text + DriveClientServer.GetQueryUnion() +
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
		|	TableAccountingJournalEntries.OperationKind AS Content,
		|	FALSE AS OfflineRecord
		|FROM
		|	TemporaryTableInventory AS TableAccountingJournalEntries
		|WHERE
		|	TableAccountingJournalEntries.ThisIsInventoryItem
		|	AND TableAccountingJournalEntries.CostOfGoodsSold <> 0
		|	AND &FillAmount
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
		|	TableAccountingJournalEntries.InventoryGLAccount,
		|	TableAccountingJournalEntries.OperationKind";
	EndIf;
	
	Query.Text = Query.Text + DriveClientServer.GetQueryUnion() + 
	"SELECT
	|	GroupedTableExchangeRateDifferencesAccountsReceivable.Date AS Period,
	|	GroupedTableExchangeRateDifferencesAccountsReceivable.Ref AS Recorder,
	|	GroupedTableExchangeRateDifferencesAccountsReceivable.Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	CASE
	|		WHEN GroupedTableExchangeRateDifferencesAccountsReceivable.AmountOfExchangeDifferences > 0
	|			THEN TableDocument.GLAccountCustomerSettlements
	|		ELSE &ForeignCurrencyExchangeLoss
	|	END AS AccountDr,
	|	CASE
	|		WHEN GroupedTableExchangeRateDifferencesAccountsReceivable.AmountOfExchangeDifferences > 0
	|				AND TableDocument.GLAccountCustomerSettlementsCurrency
	|			THEN TableDocument.DocumentCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	0 AS AmountCurDr,
	|	CASE
	|		WHEN GroupedTableExchangeRateDifferencesAccountsReceivable.AmountOfExchangeDifferences > 0
	|			THEN &ForeignCurrencyExchangeGain
	|		ELSE TableDocument.GLAccountCustomerSettlements
	|	END AS AccountCr,
	|	CASE
	|		WHEN GroupedTableExchangeRateDifferencesAccountsReceivable.AmountOfExchangeDifferences < 0
	|				AND TableDocument.GLAccountCustomerSettlementsCurrency
	|			THEN TableDocument.DocumentCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	0 AS AmountCurCr,
	|	CASE
	|		WHEN GroupedTableExchangeRateDifferencesAccountsReceivable.AmountOfExchangeDifferences > 0
	|			THEN GroupedTableExchangeRateDifferencesAccountsReceivable.AmountOfExchangeDifferences
	|		ELSE -GroupedTableExchangeRateDifferencesAccountsReceivable.AmountOfExchangeDifferences
	|	END AS Amount,
	|	&ExchangeDifference AS ExchangeDifference,
	|	FALSE AS OfflineRecord
	|FROM
	|	GroupedTableExchangeRateDifferencesAccountsReceivable AS GroupedTableExchangeRateDifferencesAccountsReceivable
	|		INNER JOIN TemporaryTableHeader AS TableDocument
	|		ON (TableDocument.Recorder = GroupedTableExchangeRateDifferencesAccountsReceivable.Ref)";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountingJournalEntries", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventoryInWarehouses(DocumentRefCreditNote, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	TableInventoryInWarehouses.Period AS Period,
	|	TableInventoryInWarehouses.Recorder AS Recorder,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
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
Procedure GenerateTableInventory(DocumentRefCreditNote, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	TableInventory.Period AS Period,
	|	TableInventory.Recorder AS Recorder,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TableInventory.Company AS Company,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.InventoryGLAccount AS GLAccount,
	|	TableInventory.ReturnQuantity AS Quantity,
	|	CASE
	|		WHEN NOT &FillAmount
	|			THEN 0
	|		ELSE TableInventory.CostOfGoodsSold
	|	END AS Amount,
	|	TableInventory.OperationKind AS ContentOfAccountingRecord,
	|	CASE
	|		WHEN TableInventory.Order = VALUE(Document.SalesOrder.EmptyRef)
	|				OR TableInventory.Order = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE TableInventory.Order
	|	END AS CorrSalesOrder,
	|	CASE
	|		WHEN VALUETYPE(TableInventory.BasisDocument) = TYPE(Document.SalesSlip)
	|			THEN TableInventory.ShiftClosure
	|		ELSE TableInventory.BasisDocument
	|	END AS SourceDocument,
	|	TableInventory.Department AS Department,
	|	TableInventory.Responsible AS Responsible,
	|	TableInventory.VATRate AS VATRate,
	|	TRUE AS Return,
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
	
	FillAmount = StructureAdditionalProperties.AccountingPolicy.InventoryValuationMethod = Enums.InventoryValuationMethods.WeightedAverage;
	Query.SetParameter("FillAmount", FillAmount);
	Query.SetParameter("Ref", DocumentRefCreditNote);
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventory", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableSerialNumbers(DocumentRefCreditNote, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	TableSerialNumbersBalance.Period AS Period,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TableSerialNumbersBalance.Period AS EventDate,
	|	TableSerialNumbersBalance.Company AS Company,
	|	VALUE(Enum.SerialNumbersOperations.Receipt) AS Operation,
	|	TableSerialNumbersBalance.StructuralUnit AS StructuralUnit,
	|	TableSerialNumbersBalance.Products AS Products,
	|	TableSerialNumbersBalance.Characteristic AS Characteristic,
	|	TableSerialNumbersBalance.Batch AS Batch,
	|	TableSerialNumbersBalance.Cell AS Cell,
	|	CreditNoteSerialNumbers.SerialNumber AS SerialNumber,
	|	1 AS Quantity
	|FROM
	|	TemporaryTableInventory AS TableSerialNumbersBalance
	|		INNER JOIN Document.CreditNote.SerialNumbers AS CreditNoteSerialNumbers
	|		ON TableSerialNumbersBalance.Recorder = CreditNoteSerialNumbers.Ref
	|			AND TableSerialNumbersBalance.ConnectionKey = CreditNoteSerialNumbers.ConnectionKey
	|WHERE
	|	TableSerialNumbersBalance.ThisIsInventoryItem
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
	|	CreditNoteSerialNumbers.SerialNumber,
	|	TableSerialNumbersBalance.Period";
	
	Query.SetParameter("UseSerialNumbers", GetFunctionalOption("UseSerialNumbers"));
	
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
Function GenerateTableVATOutput(Query, DocumentRefCreditNote, StructureAdditionalProperties)
	
	If DocumentRefCreditNote.OperationKind = Enums.OperationTypesCreditNote.SalesReturn Then
		Query.Text = 
		"SELECT
		|	CreditNoteInventory.Date AS Period,
		|	CreditNoteInventory.Ref AS Recorder,
		|	&Company AS Company,
		|	CreditNoteInventory.Counterparty AS Customer,
		|	CASE
		|		WHEN VALUETYPE(CreditNoteInventory.BasisDocument) = TYPE(Document.GoodsReturn)
		|			THEN CreditNoteInventory.SalesInvoice
		|		WHEN VALUETYPE(CreditNoteInventory.BasisDocument) = TYPE(Document.SalesSlip)
		|			THEN CreditNoteInventory.ShiftClosure
		|		ELSE CreditNoteInventory.BasisDocument
		|	END AS ShipmentDocument,
		|	CreditNoteInventory.VATRate AS VATRate,
		|	CASE
		|		WHEN CreditNoteInventory.VATTaxation = VALUE(Enum.VATTaxationTypes.ForExport)
		|				OR CreditNoteInventory.VATTaxation = VALUE(Enum.VATTaxationTypes.ReverseChargeVAT)
		|			THEN VALUE(Enum.VATOperationTypes.Export)
		|		ELSE VALUE(Enum.VATOperationTypes.SalesReturn)
		|	END AS OperationType,
		|	CatalogProducts.ProductsType AS ProductType,
		|	SUM(-(CAST(CASE
		|				WHEN CreditNoteInventory.DocumentCurrency = &PresentationCurrency
		|					THEN CreditNoteInventory.Amount * ManagExchangeRates.ExchangeRate * RegExchangeRates.Multiplicity / (RegExchangeRates.ExchangeRate * ManagExchangeRates.Multiplicity)
		|				ELSE CreditNoteInventory.Amount * CreditNoteInventory.ExchangeRate * RegExchangeRates.Multiplicity / (RegExchangeRates.ExchangeRate * CreditNoteInventory.Multiplicity)
		|			END AS NUMBER(15, 2)))) AS AmountExcludesVAT,
		|	SUM(-(CAST(CASE
		|				WHEN CreditNoteInventory.DocumentCurrency = &PresentationCurrency
		|					THEN CreditNoteInventory.VATAmount * ManagExchangeRates.ExchangeRate * RegExchangeRates.Multiplicity / (RegExchangeRates.ExchangeRate * ManagExchangeRates.Multiplicity)
		|				ELSE CreditNoteInventory.VATAmount * CreditNoteInventory.ExchangeRate * RegExchangeRates.Multiplicity / (RegExchangeRates.ExchangeRate * CreditNoteInventory.Multiplicity)
		|			END AS NUMBER(15, 2)))) AS VATAmount
		|FROM
		|	TemporaryTableDocInventory AS CreditNoteInventory
		|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS ManagExchangeRates
		|		ON (ManagExchangeRates.Currency = &PresentationCurrency)
		|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS RegExchangeRates
		|		ON (RegExchangeRates.Currency = &CurrencyNational)
		|		LEFT JOIN Catalog.Products AS CatalogProducts
		|		ON CreditNoteInventory.Products = CatalogProducts.Ref
		|WHERE
		|	CreditNoteInventory.Ref = &Ref
		|	AND NOT CreditNoteInventory.VATRate.NotTaxable
		|
		|GROUP BY
		|	CreditNoteInventory.VATRate,
		|	CreditNoteInventory.VATTaxation,
		|	CatalogProducts.ProductsType,
		|	CreditNoteInventory.Date,
		|	CreditNoteInventory.Counterparty,
		|	CASE
		|		WHEN VALUETYPE(CreditNoteInventory.BasisDocument) = TYPE(Document.GoodsReturn)
		|			THEN CreditNoteInventory.SalesInvoice
		|		WHEN VALUETYPE(CreditNoteInventory.BasisDocument) = TYPE(Document.SalesSlip)
		|			THEN CreditNoteInventory.ShiftClosure
		|		ELSE CreditNoteInventory.BasisDocument
		|	END,
		|	CreditNoteInventory.Ref";
	Else
		Query.Text = 
		"SELECT
		|	CreditNoteAmountAllocation.Date AS Period,
		|	CreditNoteAmountAllocation.Ref AS Recorder,
		|	&Company AS Company,
		|	CreditNoteAmountAllocation.Counterparty AS Customer,
		|	CreditNoteAmountAllocation.Ref AS ShipmentDocument,
		|	CreditNoteAmountAllocation.VATRate AS VATRate,
		|	CASE
		|		WHEN CreditNoteAmountAllocation.VATTaxation = VALUE(Enum.VATTaxationTypes.ForExport)
		|				OR CreditNoteAmountAllocation.VATTaxation = VALUE(Enum.VATTaxationTypes.ReverseChargeVAT)
		|			THEN VALUE(Enum.VATOperationTypes.Export)
		|		WHEN CreditNoteAmountAllocation.OperationKind = VALUE(Enum.OperationTypesCreditNote.Adjustments)
		|			THEN VALUE(Enum.VATOperationTypes.OtherAdjustments)
		|		WHEN CreditNoteAmountAllocation.OperationKind = VALUE(Enum.OperationTypesCreditNote.DiscountAllowed)
		|			THEN VALUE(Enum.VATOperationTypes.DiscountAllowed)
		|	END AS OperationType,
		|	VALUE(Enum.ProductsTypes.EmptyRef) AS ProductType,
		|	SUM(-(CAST(CASE
		|				WHEN CreditNoteAmountAllocation.DocumentCurrency = &PresentationCurrency
		|					THEN (CreditNoteAmountAllocation.OffsetAmount - CreditNoteAmountAllocation.VATAmount) * ManagExchangeRates.ExchangeRate * RegExchangeRates.Multiplicity / (RegExchangeRates.ExchangeRate * ManagExchangeRates.Multiplicity)
		|				ELSE (CreditNoteAmountAllocation.OffsetAmount - CreditNoteAmountAllocation.VATAmount) * CreditNoteAmountAllocation.ExchangeRate * RegExchangeRates.Multiplicity / (RegExchangeRates.ExchangeRate * CreditNoteAmountAllocation.Multiplicity)
		|			END AS NUMBER(15, 2)))) AS AmountExcludesVAT,
		|	SUM(-(CAST(CASE
		|				WHEN CreditNoteAmountAllocation.DocumentCurrency = &PresentationCurrency
		|					THEN CreditNoteAmountAllocation.VATAmount * ManagExchangeRates.ExchangeRate * RegExchangeRates.Multiplicity / (RegExchangeRates.ExchangeRate * ManagExchangeRates.Multiplicity)
		|				ELSE CreditNoteAmountAllocation.VATAmount * CreditNoteAmountAllocation.ExchangeRate * RegExchangeRates.Multiplicity / (RegExchangeRates.ExchangeRate * CreditNoteAmountAllocation.Multiplicity)
		|			END AS NUMBER(15, 2)))) AS VATAmount,
		|	CreditNoteAmountAllocation.OperationKind AS OperationKind
		|FROM
		|	TemporaryTableDocAmountAllocation AS CreditNoteAmountAllocation
		|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS ManagExchangeRates
		|		ON (ManagExchangeRates.Currency = &PresentationCurrency)
		|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS RegExchangeRates
		|		ON (RegExchangeRates.Currency = &CurrencyNational)
		|WHERE
		|	CreditNoteAmountAllocation.Ref = &Ref
		|	AND NOT CreditNoteAmountAllocation.VATRate.NotTaxable
		|
		|GROUP BY
		|	CreditNoteAmountAllocation.VATRate,
		|	CreditNoteAmountAllocation.VATTaxation,
		|	CreditNoteAmountAllocation.Date,
		|	CreditNoteAmountAllocation.Ref,
		|	CreditNoteAmountAllocation.Counterparty,
		|	CreditNoteAmountAllocation.Contract,
		|	CreditNoteAmountAllocation.OperationKind,
		|	CreditNoteAmountAllocation.Ref";
	EndIf;
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableVATOutput", QueryResult.Unload());
	
EndFunction

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefCreditNote, StructureAdditionalProperties) Export

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
	|	CreditNote.Date AS Date,
	|	CreditNote.Ref AS Ref,
	|	CreditNote.Contract AS Contract,
	|	CreditNote.ExchangeRate AS ExchangeRate,
	|	CreditNote.Multiplicity AS Multiplicity,
	|	CreditNote.VATAmount AS VATAmount,
	|	CreditNote.GLAccount AS GLAccount,
	|	CreditNote.OperationKind AS OperationKind,
	|	CreditNote.DocumentCurrency AS DocumentCurrency,
	|	CreditNote.VATTaxation AS VATTaxation,
	|	CreditNote.AdjustmentAmount AS DocumentAmount,
	|	CreditNote.BasisDocument AS BasisDocument,
	|	CreditNote.Counterparty AS Counterparty,
	|	CreditNote.Department AS Department,
	|	CreditNote.Cell AS Cell,
	|	CreditNote.StructuralUnit AS StructuralUnit,
	|	CreditNote.Responsible AS Responsible,
	|	CreditNote.AmountIncludesVAT AS AmountIncludesVAT,
	|	CASE
	|		WHEN CreditNote.AmountIncludesVAT
	|				OR CreditNote.OperationKind = VALUE(Enum.OperationTypesCreditNote.SalesReturn)
	|			THEN CreditNote.AdjustmentAmount - CreditNote.VATAmount
	|		ELSE CreditNote.AdjustmentAmount
	|	END AS Subtotal
	|INTO TemporaryTableDocument
	|FROM
	|	Document.CreditNote AS CreditNote
	|WHERE
	|	CreditNote.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TemporaryTableDocument.Date AS Period,
	|	TemporaryTableDocument.Ref AS Recorder,
	|	TemporaryTableDocument.AmountIncludesVAT AS AmountIncludesVAT,
	|	TemporaryTableDocument.Cell AS Cell,
	|	TemporaryTableDocument.StructuralUnit AS StructuralUnit,
	|	TemporaryTableDocument.Responsible AS Responsible,
	|	TemporaryTableDocument.Date AS Date,
	|	TemporaryTableDocument.Contract AS Contract,
	|	TemporaryTableDocument.ExchangeRate AS ExchangeRate,
	|	TemporaryTableDocument.Multiplicity AS Multiplicity,
	|	TemporaryTableDocument.Counterparty AS Counterparty,
	|	&Company AS Company,
	|	CAST(CASE
	|			WHEN TemporaryTableDocument.DocumentCurrency = &CurrencyNational
	|				THEN TemporaryTableDocument.VATAmount * RegExchangeRates.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * RegExchangeRates.Multiplicity)
	|			ELSE TemporaryTableDocument.VATAmount * TemporaryTableDocument.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * TemporaryTableDocument.Multiplicity)
	|		END AS NUMBER(15, 2)) AS VATAmount,
	|	TemporaryTableDocument.GLAccount AS GLAccount,
	|	TemporaryTableDocument.OperationKind AS OperationKind,
	|	TemporaryTableDocument.Contract.BusinessLine AS BusinessLine,
	|	TemporaryTableDocument.Contract.SettlementsCurrency AS SettlementsCurrency,
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
	|	TemporaryTableDocument.Department AS Department,
	|	CASE
	|		WHEN TemporaryTableDocument.BasisDocument REFS Document.GoodsReturn
	|			THEN TemporaryTableDocument.BasisDocument.SalesDocument.Order
	|		ELSE TemporaryTableDocument.BasisDocument.Order
	|	END AS Order,
	|	TemporaryTableDocument.VATTaxation AS VATTaxation,
	|	Counterparties.GLAccountCustomerSettlements AS GLAccountCustomerSettlements,
	|	TemporaryTableDocument.DocumentCurrency AS DocumentCurrency,
	|	PrimaryChartOfAccounts.Currency AS GLAccountCustomerSettlementsCurrency,
	|	TemporaryTableDocument.BasisDocument AS BasisDocument,
	|	CASE
	|		WHEN VALUETYPE(TemporaryTableDocument.BasisDocument) = TYPE(Document.SalesSlip)
	|			THEN SalesSlip.CashCRSession
	|		ELSE VALUE(Document.ShiftClosure.EmptyRef)
	|	END AS ShiftClosure,
	|	CASE
	|		WHEN VALUETYPE(TemporaryTableDocument.BasisDocument) = TYPE(Document.GoodsReturn)
	|			THEN GoodsReturn.SalesDocument
	|		WHEN VALUETYPE(TemporaryTableDocument.BasisDocument) = TYPE(Document.SalesInvoice)
	|			THEN TemporaryTableDocument.BasisDocument
	|		ELSE VALUE(Document.SalesInvoice.EmptyRef)
	|	END AS SalesInvoice,
	|	ISNULL(SalesSlip.Archival, FALSE) AS Archival
	|INTO TemporaryTableHeader
	|FROM
	|	TemporaryTableDocument AS TemporaryTableDocument
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS ManagExchangeRates
	|		ON (ManagExchangeRates.Currency = &PresentationCurrency)
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS RegExchangeRates
	|		ON (RegExchangeRates.Currency = &CurrencyNational)
	|		LEFT JOIN Catalog.Counterparties AS Counterparties
	|		ON TemporaryTableDocument.Counterparty = Counterparties.Ref
	|		LEFT JOIN ChartOfAccounts.PrimaryChartOfAccounts AS PrimaryChartOfAccounts
	|		ON (Counterparties.GLAccountCustomerSettlements = PrimaryChartOfAccounts.Ref)
	|		LEFT JOIN Document.GoodsReturn AS GoodsReturn
	|		ON TemporaryTableDocument.BasisDocument = GoodsReturn.Ref
	|		LEFT JOIN Document.SalesSlip AS SalesSlip
	|		ON TemporaryTableDocument.BasisDocument = SalesSlip.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CreditNoteInventory.Ref AS Ref,
	|	CASE
	|		WHEN TemporaryTableHeader.AmountIncludesVAT
	|			THEN CreditNoteInventory.Amount - CreditNoteInventory.VATAmount
	|		ELSE CreditNoteInventory.Amount
	|	END AS AdjustmentAmount,
	|	CreditNoteInventory.Batch AS Batch,
	|	CreditNoteInventory.Characteristic AS Characteristic,
	|	CreditNoteInventory.CostOfGoodsSold AS CostOfGoodsSold,
	|	CreditNoteInventory.MeasurementUnit AS MeasurementUnit,
	|	CreditNoteInventory.InitialQuantity AS Quantity,
	|	CreditNoteInventory.InitialPrice AS Price,
	|	CreditNoteInventory.Products AS Products,
	|	CreditNoteInventory.Quantity AS ReturnQuantity,
	|	CreditNoteInventory.Total AS Total,
	|	CreditNoteInventory.VATAmount AS VATAmount,
	|	CreditNoteInventory.VATRate AS VATRate,
	|	CreditNoteInventory.ConnectionKey AS ConnectionKey,
	|	CreditNoteInventory.SalesReturnGLAccount AS GLAccount,
	|	CreditNoteInventory.InventoryGLAccount AS InventoryGLAccount,
	|	CreditNoteInventory.VATOutputGLAccount AS VATOutputGLAccount,
	|	CreditNoteInventory.COGSGLAccount AS COGSGLAccount,
	|	CASE
	|		WHEN TemporaryTableHeader.AmountIncludesVAT
	|			THEN CreditNoteInventory.Amount - CreditNoteInventory.VATAmount
	|		ELSE CreditNoteInventory.Amount
	|	END AS Amount,
	|	CreditNoteInventory.Order AS Order,
	|	CreditNoteInventory.SalesRep AS SalesRep,
	|	TemporaryTableHeader.Cell AS Cell,
	|	TemporaryTableHeader.StructuralUnit AS StructuralUnit,
	|	TemporaryTableHeader.Responsible AS Responsible,
	|	TemporaryTableHeader.Date AS Date,
	|	TemporaryTableHeader.Contract AS Contract,
	|	TemporaryTableHeader.OperationKind AS OperationKind,
	|	TemporaryTableHeader.DocumentCurrency AS DocumentCurrency,
	|	TemporaryTableHeader.ExchangeRate AS ExchangeRate,
	|	TemporaryTableHeader.Multiplicity AS Multiplicity,
	|	TemporaryTableHeader.AmountIncludesVAT AS AmountIncludesVAT,
	|	TemporaryTableHeader.VATTaxation AS VATTaxation,
	|	TemporaryTableHeader.Department AS Department,
	|	TemporaryTableHeader.BasisDocument AS BasisDocument,
	|	TemporaryTableHeader.Counterparty AS Counterparty,
	|	TemporaryTableHeader.ShiftClosure AS ShiftClosure,
	|	TemporaryTableHeader.SalesInvoice AS SalesInvoice,
	|	TemporaryTableHeader.Archival AS Archival,
	|	TemporaryTableHeader.BusinessLine AS BusinessLine
	|INTO TemporaryTableDocInventory
	|FROM
	|	TemporaryTableHeader AS TemporaryTableHeader
	|		INNER JOIN Document.CreditNote.Inventory AS CreditNoteInventory
	|		ON TemporaryTableHeader.Recorder = CreditNoteInventory.Ref
	|WHERE
	|	CreditNoteInventory.Amount <> 0
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
	|			WHEN NOT &UseGoodsReturnFromCustomer
	|					OR TemporaryTableDocInventory.Products.ProductsType <> VALUE(Enum.ProductsTypes.InventoryItem)
	|				THEN TemporaryTableDocInventory.CostOfGoodsSold
	|			ELSE 0
	|		END) AS CostOfGoodsSold,
	|	TemporaryTableDocInventory.MeasurementUnit AS MeasurementUnit,
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
	|	TemporaryTableDocInventory.BasisDocument AS BasisDocument,
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
	|	TemporaryTableDocInventory.BusinessLine AS BusinessLine,
	|	TemporaryTableDocInventory.GLAccount AS GLAccount,
	|	TemporaryTableDocInventory.Order AS Order,
	|	TemporaryTableDocInventory.SalesRep AS SalesRep,
	|	TemporaryTableDocInventory.OperationKind AS OperationKind,
	|	TemporaryTableDocInventory.StructuralUnit AS StructuralUnit,
	|	TemporaryTableDocInventory.Cell AS Cell,
	|	TemporaryTableDocInventory.ConnectionKey AS ConnectionKey,
	|	TemporaryTableDocInventory.Products.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem) AS ThisIsInventoryItem,
	|	TemporaryTableDocInventory.InventoryGLAccount AS InventoryGLAccount,
	|	CounterpartyContracts.SettlementsCurrency AS SettlementsCurrency,
	|	CAST(CASE
	|			WHEN TemporaryTableDocInventory.DocumentCurrency = &CurrencyNational
	|				THEN TemporaryTableDocInventory.Amount * RegExchangeRates.ExchangeRate * TemporaryTableDocInventory.Multiplicity / (TemporaryTableDocInventory.ExchangeRate * RegExchangeRates.Multiplicity)
	|			ELSE TemporaryTableDocInventory.Amount
	|		END AS NUMBER(15, 2)) AS AmountCur,
	|	TemporaryTableDocInventory.COGSGLAccount AS GLAccountCostOfSales,
	|	TemporaryTableDocInventory.AdjustmentAmount + TemporaryTableDocInventory.VATAmount AS Total,
	|	CAST(CASE
	|			WHEN TemporaryTableDocInventory.DocumentCurrency = &CurrencyNational
	|				THEN (TemporaryTableDocInventory.AdjustmentAmount + TemporaryTableDocInventory.VATAmount) * RegExchangeRates.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * RegExchangeRates.Multiplicity)
	|			ELSE (TemporaryTableDocInventory.AdjustmentAmount + TemporaryTableDocInventory.VATAmount) * TemporaryTableDocInventory.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * TemporaryTableDocInventory.Multiplicity)
	|		END AS NUMBER(15, 2)) AS TotalCur,
	|	TemporaryTableDocInventory.ShiftClosure AS ShiftClosure,
	|	TemporaryTableDocInventory.SalesInvoice AS SalesInvoice,
	|	TemporaryTableDocInventory.Archival AS Archival,
	|	TemporaryTableDocInventory.VATOutputGLAccount AS VATOutputGLAccount
	|INTO TemporaryTableInventory
	|FROM
	|	TemporaryTableDocInventory AS TemporaryTableDocInventory
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS ManagExchangeRates
	|		ON (ManagExchangeRates.Currency = &PresentationCurrency)
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS RegExchangeRates
	|		ON (RegExchangeRates.Currency = &CurrencyNational)
	|		LEFT JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
	|		ON TemporaryTableDocInventory.Contract = CounterpartyContracts.Ref
	|
	|GROUP BY
	|	TemporaryTableDocInventory.Batch,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN TemporaryTableDocInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END,
	|	TemporaryTableDocInventory.MeasurementUnit,
	|	TemporaryTableDocInventory.VATRate,
	|	TemporaryTableDocInventory.Products,
	|	TemporaryTableDocInventory.Ref,
	|	TemporaryTableDocInventory.Date,
	|	TemporaryTableDocInventory.Department,
	|	TemporaryTableDocInventory.GLAccount,
	|	TemporaryTableDocInventory.OperationKind,
	|	TemporaryTableDocInventory.StructuralUnit,
	|	TemporaryTableDocInventory.Cell,
	|	TemporaryTableDocInventory.ConnectionKey,
	|	TemporaryTableDocInventory.Products.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem),
	|	CounterpartyContracts.SettlementsCurrency,
	|	TemporaryTableDocInventory.Responsible,
	|	CAST(CASE
	|			WHEN TemporaryTableDocInventory.DocumentCurrency = &CurrencyNational
	|				THEN TemporaryTableDocInventory.Amount * RegExchangeRates.ExchangeRate * TemporaryTableDocInventory.Multiplicity / (TemporaryTableDocInventory.ExchangeRate * RegExchangeRates.Multiplicity)
	|			ELSE TemporaryTableDocInventory.Amount
	|		END AS NUMBER(15, 2)),
	|	TemporaryTableDocInventory.Order,
	|	TemporaryTableDocInventory.SalesRep,
	|	CAST(CASE
	|			WHEN TemporaryTableDocInventory.DocumentCurrency = &CurrencyNational
	|				THEN (TemporaryTableDocInventory.AdjustmentAmount + TemporaryTableDocInventory.VATAmount) * RegExchangeRates.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * RegExchangeRates.Multiplicity)
	|			ELSE (TemporaryTableDocInventory.AdjustmentAmount + TemporaryTableDocInventory.VATAmount) * TemporaryTableDocInventory.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * TemporaryTableDocInventory.Multiplicity)
	|		END AS NUMBER(15, 2)),
	|	TemporaryTableDocInventory.AdjustmentAmount + TemporaryTableDocInventory.VATAmount,
	|	TemporaryTableDocInventory.BasisDocument,
	|	TemporaryTableDocInventory.ShiftClosure,
	|	TemporaryTableDocInventory.SalesInvoice,
	|	TemporaryTableDocInventory.Archival,
	|	TemporaryTableDocInventory.InventoryGLAccount,
	|	TemporaryTableDocInventory.VATOutputGLAccount,
	|	TemporaryTableDocInventory.COGSGLAccount,
	|	TemporaryTableDocInventory.BusinessLine
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CreditNoteAmountAllocation.Ref AS Ref,
	|	CreditNoteAmountAllocation.Contract AS Contract,
	|	CreditNoteAmountAllocation.AdvanceFlag AS AdvanceFlag,
	|	CreditNoteAmountAllocation.Document AS Document,
	|	CreditNoteAmountAllocation.OffsetAmount AS OffsetAmount,
	|	CreditNoteAmountAllocation.Order AS Order,
	|	TemporaryTableDocument.Date AS Date,
	|	TemporaryTableDocument.ExchangeRate AS ExchangeRate,
	|	TemporaryTableDocument.Multiplicity AS Multiplicity,
	|	TemporaryTableDocument.Counterparty AS Counterparty,
	|	TemporaryTableDocument.DocumentCurrency AS DocumentCurrency,
	|	TemporaryTableDocument.OperationKind AS OperationKind,
	|	TemporaryTableDocument.VATTaxation AS VATTaxation,
	|	CreditNoteAmountAllocation.VATRate AS VATRate,
	|	CreditNoteAmountAllocation.VATAmount AS VATAmount,
	|	Counterparties.CustomerAdvancesGLAccount AS CustomerAdvancesGLAccount,
	|	Counterparties.GLAccountCustomerSettlements AS GLAccountCustomerSettlements,
	|	CreditNoteAmountAllocation.LineNumber AS LineNumber
	|INTO TemporaryTableDocAmountAllocation
	|FROM
	|	TemporaryTableDocument AS TemporaryTableDocument
	|		INNER JOIN Document.CreditNote.AmountAllocation AS CreditNoteAmountAllocation
	|		ON TemporaryTableDocument.Ref = CreditNoteAmountAllocation.Ref
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
	|	TemporaryTableDocAmountAllocation.CustomerAdvancesGLAccount AS CustomerAdvancesGLAccount,
	|	TemporaryTableDocAmountAllocation.GLAccountCustomerSettlements AS GLAccountCustomerSettlements,
	|	TemporaryTableDocAmountAllocation.DocumentCurrency AS Currency,
	|	TemporaryTableDocAmountAllocation.OffsetAmount AS OffsetAmount
	|INTO TemporaryTableAmountAllocation
	|FROM
	|	TemporaryTableDocAmountAllocation AS TemporaryTableDocAmountAllocation
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS ManagExchangeRates
	|		ON (ManagExchangeRates.Currency = &PresentationCurrency)
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS RegExchangeRates
	|		ON (RegExchangeRates.Currency = &CurrencyNational)";
	
	Query.SetParameter("Ref", DocumentRefCreditNote);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("UseCharacteristics", StructureAdditionalProperties.AccountingPolicy.UseCharacteristics);
	Query.SetParameter("UseGoodsReturnFromCustomer", StructureAdditionalProperties.AccountingPolicy.UseGoodsReturnFromCustomer);
	Query.SetParameter("PresentationCurrency", Constants.PresentationCurrency.Get());
	Query.SetParameter("CurrencyNational", Constants.FunctionalCurrency.Get());
	Query.SetParameter("DocumentCurrency", DocumentRefCreditNote.DocumentCurrency);
	
	ResultsArray = Query.ExecuteBatch();
	
	// Creation of document postings.
	DriveServer.GenerateTransactionsTable(DocumentRefCreditNote, StructureAdditionalProperties);
	
	PerformanceEstimationClientServer.StartTimeMeasurement("DocumentCreditNoteGenerateTables");
	
	GenerateTableSales(DocumentRefCreditNote, StructureAdditionalProperties);
	GenerateTableAccountsReceivable(DocumentRefCreditNote, StructureAdditionalProperties);
	GenerateTableIncomeAndExpenses(DocumentRefCreditNote, StructureAdditionalProperties);
	
	If DocumentRefCreditNote.OperationKind = Enums.OperationTypesCreditNote.SalesReturn Then 
		If NOT StructureAdditionalProperties.AccountingPolicy.UseGoodsReturnFromCustomer Then
			GenerateTableInventoryInWarehouses(DocumentRefCreditNote, StructureAdditionalProperties);
			GenerateTableInventory(DocumentRefCreditNote, StructureAdditionalProperties);
			GenerateTableSerialNumbers(DocumentRefCreditNote, StructureAdditionalProperties);	
		EndIf;
	EndIf;
	
	GenerateTableAccountingJournalEntries(DocumentRefCreditNote, StructureAdditionalProperties);
	
	If GetFunctionalOption("UseVAT")
		AND NOT WorkWithVAT.GetUseTaxInvoiceForPostingVAT(DocumentRefCreditNote.Date, DocumentRefCreditNote.Company) 
		AND DocumentRefCreditNote.VATTaxation <> Enums.VATTaxationTypes.NotSubjectToVAT Then
		
		GenerateTableVATOutput(Query, DocumentRefCreditNote, StructureAdditionalProperties);
	
	EndIf;
	
EndProcedure

// Controls the occurrence of negative balances.
//
Procedure RunControl(DocumentRefCreditNote, AdditionalProperties, Cancel, PostingDelete = False) Export
	
	If Not DriveServer.RunBalanceControl() Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	If StructureTemporaryTables.RegisterRecordsInventoryChange
		OR StructureTemporaryTables.RegisterRecordsInventoryInWarehousesChange
		OR StructureTemporaryTables.RegisterRecordsAccountsReceivableChange Then
		
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
		|	RegisterRecordsAccountsReceivableChange.LineNumber AS LineNumber,
		|	RegisterRecordsAccountsReceivableChange.Company AS CompanyPresentation,
		|	RegisterRecordsAccountsReceivableChange.Counterparty AS CounterpartyPresentation,
		|	RegisterRecordsAccountsReceivableChange.Contract AS ContractPresentation,
		|	RegisterRecordsAccountsReceivableChange.Contract.SettlementsCurrency AS CurrencyPresentation,
		|	RegisterRecordsAccountsReceivableChange.Document AS DocumentPresentation,
		|	RegisterRecordsAccountsReceivableChange.Order AS OrderPresentation,
		|	RegisterRecordsAccountsReceivableChange.SettlementsType AS CalculationsTypesPresentation,
		|	FALSE AS RegisterRecordsOfCashDocuments,
		|	RegisterRecordsAccountsReceivableChange.SumBeforeWrite AS SumBeforeWrite,
		|	RegisterRecordsAccountsReceivableChange.AmountOnWrite AS AmountOnWrite,
		|	RegisterRecordsAccountsReceivableChange.AmountChange AS AmountChange,
		|	RegisterRecordsAccountsReceivableChange.AmountCurBeforeWrite AS AmountCurBeforeWrite,
		|	RegisterRecordsAccountsReceivableChange.SumCurOnWrite AS SumCurOnWrite,
		|	RegisterRecordsAccountsReceivableChange.SumCurChange AS SumCurChange,
		|	RegisterRecordsAccountsReceivableChange.SumCurOnWrite - ISNULL(AccountsReceivableBalances.AmountCurBalance, 0) AS AdvanceAmountsReceived,
		|	RegisterRecordsAccountsReceivableChange.SumCurChange + ISNULL(AccountsReceivableBalances.AmountCurBalance, 0) AS AmountOfOutstandingDebt,
		|	ISNULL(AccountsReceivableBalances.AmountBalance, 0) AS AmountBalance,
		|	ISNULL(AccountsReceivableBalances.AmountCurBalance, 0) AS AmountCurBalance,
		|	RegisterRecordsAccountsReceivableChange.SettlementsType AS SettlementsType
		|FROM
		|	RegisterRecordsAccountsReceivableChange AS RegisterRecordsAccountsReceivableChange
		|		INNER JOIN AccumulationRegister.AccountsReceivable.Balance(&ControlTime, ) AS AccountsReceivableBalances
		|		ON RegisterRecordsAccountsReceivableChange.Company = AccountsReceivableBalances.Company
		|			AND RegisterRecordsAccountsReceivableChange.Counterparty = AccountsReceivableBalances.Counterparty
		|			AND RegisterRecordsAccountsReceivableChange.Contract = AccountsReceivableBalances.Contract
		|			AND RegisterRecordsAccountsReceivableChange.Document = AccountsReceivableBalances.Document
		|			AND RegisterRecordsAccountsReceivableChange.Order = AccountsReceivableBalances.Order
		|			AND RegisterRecordsAccountsReceivableChange.SettlementsType = AccountsReceivableBalances.SettlementsType
		|			AND (CASE
		|				WHEN RegisterRecordsAccountsReceivableChange.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)
		|					THEN ISNULL(AccountsReceivableBalances.AmountCurBalance, 0) > 0
		|				ELSE ISNULL(AccountsReceivableBalances.AmountCurBalance, 0) < 0
		|			END)
		|
		|ORDER BY
		|	LineNumber");
		
		Query.Text = Query.Text + DriveClientServer.GetQueryDelimeter();
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.SetParameter("ControlTime", AdditionalProperties.ForPosting.ControlTime);
		
		ResultsArray = Query.ExecuteBatch();
		
		If Not ResultsArray[0].IsEmpty()
			OR Not ResultsArray[1].IsEmpty()
			OR Not ResultsArray[2].IsEmpty() Then
			DocumentObjectCreditNote = DocumentRefCreditNote.GetObject()
		EndIf;
		
		// Negative balance of inventory in the warehouse.
		If Not ResultsArray[0].IsEmpty() Then
			QueryResultSelection = ResultsArray[0].Select();
			DriveServer.ShowMessageAboutPostingToInventoryInWarehousesRegisterErrors(DocumentObjectCreditNote, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance of inventory.
		If Not ResultsArray[1].IsEmpty() Then
			QueryResultSelection = ResultsArray[1].Select();
			DriveServer.ShowMessageAboutPostingToInventoryRegisterErrors(DocumentObjectCreditNote, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance on accounts receivable.
		If Not ResultsArray[2].IsEmpty() Then
			QueryResultSelection = ResultsArray[2].Select();
			DriveServer.ShowMessageAboutPostingToAccountsReceivableRegisterErrors(DocumentObjectCreditNote, QueryResultSelection, Cancel);
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
	
	If PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "CreditNote") Then
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection, "CreditNote", "Credit note", PrintForm(ObjectsArray, PrintObjects, "CreditNote"));
	EndIf;
	
	If PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "TaxInvoice") Then
		If ObjectsArray.Count() > 0 Then
			PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection, "TaxInvoice", "Tax invoice", DataProcessors.PrintTaxInvoice.PrintForm(ObjectsArray, PrintObjects, "TaxInvoice"));
		EndIf;
	ElsIf PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "GoodsReceivedNote") Then
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection,
															"GoodsReceivedNote",
															NStr("en = 'Goods received note'"),
															DataProcessors.PrintGoodsReceivedNote.PrintForm(ObjectsArray, PrintObjects, "GoodsReceivedNote"));
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
	PrintCommand.ID							= "CreditNote";
	PrintCommand.Presentation				= NStr("en = 'Credit note'");
	PrintCommand.CheckPostingBeforePrint	= False;
	PrintCommand.Order						= 1;
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID							= "GoodsReceivedNote";
	PrintCommand.Presentation				= NStr("en = 'Goods received note'");
	PrintCommand.CheckPostingBeforePrint	= False;
	PrintCommand.Order						= 2;

	If GetFunctionalOption("UseVAT") Then
		PrintCommand = PrintCommands.Add();
		PrintCommand.ID							= "TaxInvoice";
		PrintCommand.Presentation				= NStr("en = 'Tax invoice'");
		PrintCommand.CheckPostingBeforePrint	= True;
		PrintCommand.Order						= 3;
	EndIf;
	
EndProcedure

Function PrintForm(ObjectsArray, PrintObjects, TemplateName)
	
	If TemplateName = "CreditNote" Then
		Return PrintCreditNote(ObjectsArray, PrintObjects, TemplateName)
	EndIf;
	
EndFunction

Function PrintCreditNote(ObjectsArray, PrintObjects, TemplateName)
	
	SpreadsheetDocument = New SpreadsheetDocument;
	SpreadsheetDocument.PrintParametersKey = "PrintParameters_CreditNote";
	
	Query = New Query();
	Query.SetParameter("ObjectsArray", ObjectsArray);
	
	#Region PrintCreditNoteQueryText
	
	Query.Text = 
	"SELECT
	|	CreditNote.Ref AS Ref,
	|	CreditNote.Number AS Number,
	|	CreditNote.Date AS Date,
	|	CreditNote.Company AS Company,
	|	CreditNote.Counterparty AS Counterparty,
	|	CreditNote.Contract AS Contract,
	|	CreditNote.AmountIncludesVAT AS AmountIncludesVAT,
	|	CreditNote.DocumentCurrency AS DocumentCurrency,
	|	CreditNote.BasisDocument AS BasisDocument,
	|	CreditNote.OperationKind AS OperationKind,
	|	CreditNote.ReasonForCorrection AS ReasonForCorrection,
	|	CreditNote.AdjustmentAmount AS DocumentAmount,
	|	CreditNote.VATRate AS VATRate,
	|	CreditNote.VATAmount AS VATAmount
	|INTO CreditNotes
	|FROM
	|	Document.CreditNote AS CreditNote
	|WHERE
	|	CreditNote.Ref IN(&ObjectsArray)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CreditNoteInventory.Ref AS Ref,
	|	CreditNoteInventory.LineNumber AS LineNumber,
	|	CreditNoteInventory.Amount AS Amount,
	|	CreditNoteInventory.Batch AS Batch,
	|	CreditNoteInventory.Characteristic AS Characteristic,
	|	CreditNoteInventory.ConnectionKey AS ConnectionKey,
	|	CreditNoteInventory.DiscountMarkupPercent AS DiscountMarkupPercent,
	|	CreditNoteInventory.MeasurementUnit AS MeasurementUnit,
	|	CASE
	|		WHEN CreditNoteInventory.Quantity = 0
	|			THEN 0
	|		ELSE CreditNoteInventory.Amount / CreditNoteInventory.Quantity
	|	END AS Price,
	|	CreditNoteInventory.Products AS Products,
	|	CreditNoteInventory.Quantity AS Quantity,
	|	CreditNoteInventory.Total AS Total,
	|	CreditNoteInventory.VATAmount AS VATAmount,
	|	CreditNoteInventory.VATRate AS VATRate
	|INTO FilteredInventory
	|FROM
	|	Document.CreditNote.Inventory AS CreditNoteInventory
	|WHERE
	|	CreditNoteInventory.Ref IN(&ObjectsArray)
	|	AND (CreditNoteInventory.Quantity <> 0
	|			OR CreditNoteInventory.Amount <> 0)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CreditNote.Ref AS Ref,
	|	CreditNote.Number AS DocumentNumber,
	|	CreditNote.Date AS DocumentDate,
	|	CreditNote.Company AS Company,
	|	Companies.LogoFile AS CompanyLogoFile,
	|	CreditNote.Counterparty AS Counterparty,
	|	CreditNote.Contract AS Contract,
	|	CASE
	|		WHEN CounterpartyContracts.ContactPerson = VALUE(Catalog.ContactPersons.EmptyRef)
	|			THEN Counterparties.ContactPerson
	|		ELSE CounterpartyContracts.ContactPerson
	|	END AS CounterpartyContactPerson,
	|	CASE
	|		WHEN CreditNote.BasisDocument REFS Document.GoodsReturn
	|			THEN CreditNote.BasisDocument.SalesDocument
	|		ELSE CreditNote.BasisDocument
	|	END AS Invoice,
	|	CreditNote.AmountIncludesVAT AS AmountIncludesVAT,
	|	CreditNote.DocumentCurrency AS DocumentCurrency,
	|	CreditNote.OperationKind AS OperationKind,
	|	CreditNote.ReasonForCorrection AS ReasonForCorrection,
	|	CreditNote.DocumentAmount AS DocumentAmount,
	|	CreditNote.VATRate AS VATRate,
	|	CreditNote.VATAmount AS VATAmount
	|INTO Header
	|FROM
	|	CreditNotes AS CreditNote
	|		LEFT JOIN Catalog.Companies AS Companies
	|		ON CreditNote.Company = Companies.Ref
	|		LEFT JOIN Catalog.Counterparties AS Counterparties
	|		ON CreditNote.Counterparty = Counterparties.Ref
	|		LEFT JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
	|		ON CreditNote.Contract = CounterpartyContracts.Ref
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
	|	FilteredInventory.DiscountMarkupPercent AS DiscountRate,
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
	|	CAST(Header.ReasonForCorrection AS STRING(1000)) AS ReasonForCorrection,
	|	FilteredInventory.Products AS Products,
	|	FilteredInventory.Batch AS Batch,
	|	FilteredInventory.Characteristic AS Characteristic,
	|	FilteredInventory.MeasurementUnit AS MeasurementUnit
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
	|
	|GROUP BY
	|	Header.DocumentCurrency,
	|	CASE
	|		WHEN CatalogProducts.UseCharacteristics
	|			THEN CatalogCharacteristics.Description
	|		ELSE """"
	|	END,
	|	ISNULL(CatalogUOM.Description, CatalogUOMClassifier.Description),
	|	Header.Company,
	|	CatalogProducts.UseSerialNumbers,
	|	FilteredInventory.VATRate,
	|	Header.DocumentNumber,
	|	Header.OperationKind,
	|	Header.CompanyLogoFile,
	|	CASE
	|		WHEN CatalogProducts.UseBatches
	|			THEN CatalogBatches.Description
	|		ELSE """"
	|	END,
	|	CatalogProducts.SKU,
	|	Header.CounterpartyContactPerson,
	|	CatalogProducts.Description,
	|	Header.Ref,
	|	Header.Contract,
	|	Header.AmountIncludesVAT,
	|	Header.Counterparty,
	|	Header.Invoice,
	|	Header.DocumentDate,
	|	CAST(Header.ReasonForCorrection AS STRING(1000)),
	|	FilteredInventory.Products,
	|	FilteredInventory.Batch,
	|	FilteredInventory.Characteristic,
	|	FilteredInventory.MeasurementUnit,
	|	FilteredInventory.DiscountMarkupPercent,
	|	FilteredInventory.Price
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Header.ReasonForCorrection AS ReasonForCorrection,
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
	|	ISNULL(CreditNoteCreditedTransactions.Document, UNDEFINED) AS Document
	|FROM
	|	Header AS Header
	|		LEFT JOIN Document.CreditNote.CreditedTransactions AS CreditNoteCreditedTransactions
	|		ON Header.Ref = CreditNoteCreditedTransactions.Ref
	|WHERE
	|	Header.OperationKind <> VALUE(Enum.OperationTypesCreditNote.SalesReturn)
	|TOTALS
	|	MAX(ReasonForCorrection),
	|	MAX(Amount),
	|	MAX(VATRate),
	|	MAX(CompanyLogoFile),
	|	MAX(DocumentDate),
	|	MAX(DocumentNumber),
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
	|	Inventory.LineNumber AS LineNumber,
	|	Inventory.SKU AS SKU,
	|	Inventory.UseSerialNumbers AS UseSerialNumbers,
	|	Inventory.Quantity AS Quantity,
	|	CASE
	|		WHEN Inventory.AmountIncludesVAT
	|				AND Inventory.Price > 0
	|			THEN Inventory.VATAmount / Inventory.Quantity
	|		ELSE Inventory.Price
	|	END AS Price,
	|	Inventory.Amount AS Amount,
	|	Inventory.VATRate AS VATRate,
	|	Inventory.VATAmount AS VATAmount,
	|	Inventory.Total AS Total,
	|	Inventory.Subtotal AS Subtotal,
	|	Inventory.ProductDescription AS ProductDescription,
	|	Inventory.ContentUsed AS ContentUsed,
	|	Inventory.Invoice AS Invoice,
	|	Inventory.OperationKind AS OperationKind,
	|	CAST(Inventory.ReasonForCorrection AS STRING(1000)) AS ReasonForCorrection,
	|	Inventory.Products AS Products,
	|	Inventory.Batch AS Batch,
	|	Inventory.Characteristic AS Characteristic,
	|	Inventory.CharacteristicDescription AS CharacteristicDescription,
	|	Inventory.BatchDescription AS BatchDescription,
	|	Inventory.ConnectionKey AS ConnectionKey,
	|	Inventory.UOM AS UOM
	|FROM
	|	Inventory AS Inventory
	|
	|ORDER BY
	|	Inventory.DocumentNumber,
	|	Inventory.LineNumber
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
	|	COUNT(LineNumber),
	|	SUM(Quantity),
	|	SUM(VATAmount),
	|	SUM(Total),
	|	SUM(Subtotal),
	|	MAX(Invoice),
	|	MAX(OperationKind)
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
	|			AND FilteredInventory.DiscountMarkupPercent = Inventory.DiscountRate
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
	SpreadsheetDocument.PrintParametersName = "PRINT_PARAMETERS_CreditNote";
	Template = PrintManagement.PrintedFormsTemplate("Document.CreditNote.PF_MXL_CreditNote");
	
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
			Transactions = TrimAll(Transactions) + ?(IsBlankString(Transactions), "", "; ");
			Transactions = Transactions + String(TabSelection.Document);
		EndDo;
		
		CounterpartyInfoArea = GetArea("CounterpartyInfo", Template, Header);
		CounterpartyInfoArea.Parameters.Invoice = Transactions;
		SpreadsheetDocument.Put(CounterpartyInfoArea);
		
		CommentArea = GetArea("Comment", Template, Header);
		SpreadsheetDocument.Put(CommentArea);
		
		#Region PrintCreditNoteLinesArea
		
		LineHeaderArea = Template.GetArea("LineHeaderDiscAllowed");
		SpreadsheetDocument.Put(LineHeaderArea);
		
		LineSectionArea	= Template.GetArea("LineSectionDiscAllowed");
		LineSectionArea.Parameters.Fill(Header);
		LineSectionArea.Parameters.ReasonForCorrection = CommonUse.ObjectAttributeValue(Header.Ref, "ReasonForCorrection");
		SpreadsheetDocument.Put(LineSectionArea);
		
		#EndRegion
		
		#Region PrintCreditNoteTotalsArea
		
		LineTotalArea = Template.GetArea("LineTotal");
		LineTotalArea.Parameters.Fill(Header);
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
		SpreadsheetDocument.Put(CounterpartyInfoArea);
		
		#Region PrintCreditNoteReasonForCorrectionArea
		
		ReasonForCorrectionArea = Template.GetArea("ReasonForCorrection");
		ReasonForCorrectionArea.Parameters.ReasonForCorrection = CommonUse.ObjectAttributeValue(Inventory.Ref,
																								"ReasonForCorrection");
		SpreadsheetDocument.Put(ReasonForCorrectionArea);
		
		#EndRegion
		
		CommentArea = GetArea("Comment", Template, Inventory);
		SpreadsheetDocument.Put(CommentArea);
		
		#Region PrintCreditNoteTotalsAndTaxesAreaPrefill
		
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
		
		#Region PrintCreditNoteLinesArea
		
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
		
		#Region PrintCreditNoteTotalsAndTaxesArea
		
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
		
		Area.Parameters.Fill(Selection);
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
	|	CreditNote.Ref AS Ref,
	|	CreditNote.OperationKind AS OperationKind,
	|	CreditNote.BasisDocument AS BasisDocument
	|FROM
	|	Document.CreditNote AS CreditNote
	|WHERE
	|	CreditNote.DocumentAmount = 0
	|	AND CreditNote.AdjustmentAmount <> 0";
	
	QueryResult = Query.Execute();
	Selection	= QueryResult.Select();
	
	While Selection.Next() Do
		DocObject = Selection.Ref.GetObject();
		If Selection.OperationKind = Enums.OperationTypesCreditNote.SalesReturn Then
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

// Replaces an empty sales order reference with an undefined
//
Procedure ChangeSalesOrderReference() Export
	
	Query = New Query;
	Query.Text = 
	"SELECT DISTINCT
	|	CreditNoteAmountAllocation.Ref AS Ref
	|FROM
	|	Document.CreditNote.AmountAllocation AS CreditNoteAmountAllocation
	|WHERE
	|	CreditNoteAmountAllocation.Order = VALUE(Document.SalesOrder.EmptyRef)";
	
	QueryResult = Query.Execute();
	Selection	= QueryResult.Select();
	
	SalesOrderEmptyRef = Documents.SalesOrder.EmptyRef();
	
	While Selection.Next() Do
		
		Try
			
			CreditNoteObject = Selection.Ref.GetObject();
			
			For Each Row In CreditNoteObject.AmountAllocation Do
				
				If Row.Order = SalesOrderEmptyRef Then
					Row.Order = Undefined;
				EndIf;
				
			EndDo;
			
			CreditNoteObject.Write();
			
		Except
			
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Error on write document %1: %2'"),
				Selection.Ref,
				BriefErrorDescription(ErrorInfo()));
				
			WriteLogEvent(
				NStr("en = 'InfobaseUpdate'", CommonUseClientServer.MainLanguageCode()),
				EventLogLevel.Error,
				Metadata.Documents.CreditNote,
				,
				ErrorDescription);
				
		EndTry;
		
	EndDo;
	
EndProcedure

Procedure FillNewGLAccounts() Export
	
	DocumentName = "CreditNote";
	
	Tables = New Array();
	TableDecription = New Structure("Name, Conditions", "Inventory", New Array());
	
	GLAccountFields = ChartsOfAccounts.PrimaryChartOfAccounts.GLAccountFields();
	GLAccountFields.Source = "Products.InventoryGLAccount";
	GLAccountFields.Receiver = "InventoryGLAccount";
	TableDecription.Conditions.Add(GLAccountFields);
	
	GLAccountFields = ChartsOfAccounts.PrimaryChartOfAccounts.GLAccountFields();
	GLAccountFields.Source = "&VATOutputGLAccount";
	GLAccountFields.Receiver = "VATOutputGLAccount";
	GLAccountFields.Parameter = Catalogs.DefaultGLAccounts.GetDefaultGLAccount("VATOutput");
	TableDecription.Conditions.Add(GLAccountFields);
	
	GLAccountFields = ChartsOfAccounts.PrimaryChartOfAccounts.GLAccountFields();
	GLAccountFields.Source = "Products.BusinessLine.GLAccountCostOfSales";
	GLAccountFields.Receiver = "COGSGLAccount";
	TableDecription.Conditions.Add(GLAccountFields);
	
	GLAccountFields = ChartsOfAccounts.PrimaryChartOfAccounts.GLAccountFields();
	GLAccountFields.Source = "Ref.GLAccount";
	GLAccountFields.Receiver = "SalesReturnGLAccount";
	TableDecription.Conditions.Add(GLAccountFields);
	
	Tables.Add(TableDecription);
	
	ChartsOfAccounts.PrimaryChartOfAccounts.FillNewGLAccounts(DocumentName, Tables);
	
EndProcedure

#EndRegion

#EndIf