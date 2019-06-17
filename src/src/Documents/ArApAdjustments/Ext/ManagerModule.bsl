#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableCustomerAccounts(DocumentRefArApAdjustments, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();

	Query.SetParameter("Ref",					DocumentRefArApAdjustments);
	Query.SetParameter("PointInTime",			New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod",			StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("Company",				StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("ExchangeDifference",	NStr("en = 'Foreign currency exchange gains and losses'", MainLanguageCode));
	
	Query.Text =
	"SELECT
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.ContentOfAccountingRecord AS ContentOfAccountingRecord,
	|	&Company AS Company,
	|	DocumentTable.RecordType AS RecordType,
	|	DocumentTable.Counterparty AS Counterparty,
	|	DocumentTable.Contract AS Contract,
	|	DocumentTable.Currency AS Currency,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByDocuments
	|			THEN DocumentTable.Document
	|		ELSE UNDEFINED
	|	END AS Document,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByOrders
	|			AND DocumentTable.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|			AND DocumentTable.Order <> VALUE(Document.WOrkOrder.EmptyRef)
	|			THEN DocumentTable.Order
	|		ELSE UNDEFINED
	|	END AS Order,
	|	DocumentTable.SettlementsType AS SettlementsType,
	|	DocumentTable.GLAccount AS GLAccount,
	|	DocumentTable.Date AS Date,
	|	SUM(DocumentTable.AccountingAmount) AS Amount,
	|	SUM(DocumentTable.SettlementsAmount) AS AmountCur,
	|	SUM(DocumentTable.AccountingAmountBalance) AS AmountForBalance,
	|	SUM(DocumentTable.SettlementsAmountBalance) AS AmountCurForBalance,
	|	SUM(DocumentTable.AccountingAmount) AS AmountForPayment,
	|	SUM(DocumentTable.SettlementsAmount) AS AmountForPaymentCur
	|INTO TemporaryTableAccountsReceivable
	|FROM
	|	TemporaryTableCustomers AS DocumentTable
	|
	|GROUP BY
	|	DocumentTable.LineNumber,
	|	DocumentTable.ContentOfAccountingRecord,
	|	DocumentTable.RecordType,
	|	DocumentTable.Counterparty,
	|	DocumentTable.Contract,
	|	DocumentTable.Currency,
	|	DocumentTable.SettlementsType,
	|	DocumentTable.GLAccount,
	|	DocumentTable.Date,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByDocuments
	|			THEN DocumentTable.Document
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByOrders
	|			AND DocumentTable.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|			AND DocumentTable.Order <> VALUE(Document.WOrkOrder.EmptyRef)
	|			THEN DocumentTable.Order
	|		ELSE UNDEFINED
	|	END
	|
	|INDEX BY
	|	Company,
	|	Counterparty,
	|	Contract,
	|	Currency,
	|	Document,
	|	Order,
	|	SettlementsType,
	|	GLAccount";
	
	Query.Execute();
	
	// Setting the exclusive lock for the controlled balances of accounts payable.
	Query.Text =
	"SELECT
	|	TemporaryTableAccountsReceivable.Company AS Company,
	|	TemporaryTableAccountsReceivable.Counterparty AS Counterparty,
	|	TemporaryTableAccountsReceivable.Contract AS Contract,
	|	TemporaryTableAccountsReceivable.Document AS Document,
	|	TemporaryTableAccountsReceivable.Order AS Order,
	|	TemporaryTableAccountsReceivable.SettlementsType AS SettlementsType
	|FROM
	|	TemporaryTableAccountsReceivable";
	
	QueryResult = Query.Execute();
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.AccountsReceivable");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;
	
	For Each ColumnQueryResult In QueryResult.Columns Do
		LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
	EndDo;
	Block.Lock();
	
	QueryNumber = 0;
	Query.Text = DriveServer.GetQueryTextCurrencyExchangeRateAccountsReceivable(Query.TempTablesManager, False, QueryNumber);
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountsReceivable", ResultsArray[QueryNumber].Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableAccountsPayable(DocumentRefArApAdjustments, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();

	Query.SetParameter("Ref",					DocumentRefArApAdjustments);
	Query.SetParameter("PointInTime",			New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod",			StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("Company",				StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("ExchangeDifference",	NStr("en = 'Foreign currency exchange gains and losses'", MainLanguageCode));
	
	Query.Text =
	"SELECT
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.ContentOfAccountingRecord AS ContentOfAccountingRecord,
	|	&Company AS Company,
	|	DocumentTable.RecordType AS RecordType,
	|	DocumentTable.Counterparty AS Counterparty,
	|	DocumentTable.Contract AS Contract,
	|	DocumentTable.Currency AS Currency,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByDocuments
	|			THEN DocumentTable.Document
	|		ELSE UNDEFINED
	|	END AS Document,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByOrders
	|			THEN DocumentTable.Order
	|		ELSE VALUE(Document.PurchaseOrder.EmptyRef)
	|	END AS Order,
	|	DocumentTable.SettlementsType AS SettlementsType,
	|	DocumentTable.GLAccount AS GLAccount,
	|	DocumentTable.Date AS Date,
	|	SUM(DocumentTable.AccountingAmount) AS Amount,
	|	SUM(DocumentTable.SettlementsAmount) AS AmountCur,
	|	SUM(DocumentTable.AccountingAmountBalance) AS AmountForBalance,
	|	SUM(DocumentTable.SettlementsAmountBalance) AS AmountCurForBalance,
	|	SUM(DocumentTable.AccountingAmount) AS AmountForPayment,
	|	SUM(DocumentTable.SettlementsAmount) AS AmountForPaymentCur
	|INTO TemporaryTableAccountsPayable
	|FROM
	|	TemporaryTableVendors AS DocumentTable
	|
	|GROUP BY
	|	DocumentTable.LineNumber,
	|	DocumentTable.ContentOfAccountingRecord,
	|	DocumentTable.RecordType,
	|	DocumentTable.Counterparty,
	|	DocumentTable.Contract,
	|	DocumentTable.Currency,
	|	DocumentTable.SettlementsType,
	|	DocumentTable.GLAccount,
	|	DocumentTable.Date,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByDocuments
	|			THEN DocumentTable.Document
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByOrders
	|			THEN DocumentTable.Order
	|		ELSE VALUE(Document.PurchaseOrder.EmptyRef)
	|	END
	|
	|INDEX BY
	|	Company,
	|	Counterparty,
	|	Contract,
	|	Currency,
	|	Document,
	|	Order,
	|	SettlementsType,
	|	GLAccount";
	
	Query.Execute();
	
	// Setting the exclusive lock for the controlled balances of accounts payable.
	Query.Text =
	"SELECT
	|	TemporaryTableAccountsPayable.Company AS Company,
	|	TemporaryTableAccountsPayable.Counterparty AS Counterparty,
	|	TemporaryTableAccountsPayable.Contract AS Contract,
	|	TemporaryTableAccountsPayable.Document AS Document,
	|	TemporaryTableAccountsPayable.Order AS Order,
	|	TemporaryTableAccountsPayable.SettlementsType AS SettlementsType
	|FROM
	|	TemporaryTableAccountsPayable";
	
	QueryResult = Query.Execute();
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.AccountsPayable");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;
	
	For Each ColumnQueryResult In QueryResult.Columns Do
		LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
	EndDo;
	Block.Lock();
	
	QueryNumber = 0;
	Query.Text = DriveServer.GetQueryTextExchangeRatesDifferencesAccountsPayable(Query.TempTablesManager, False, QueryNumber);
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountsPayable", ResultsArray[QueryNumber].Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInvoicesAndOrdersPayment(DocumentRefPaymentReceipt, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	
	Query.Text =
	"SELECT
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Date AS Period,
	|	&Company AS Company,
	|	DocumentTable.Order AS Order,
	|	SUM(CASE
	|			WHEN NOT DocumentTable.AdvanceFlag
	|				THEN 0
	|			ELSE CAST(DocumentTable.SettlementsAmount * SettlementsExchangeRates.ExchangeRate * ExchangeRatesOfAccount.Multiplicity / (ExchangeRatesOfAccount.ExchangeRate * SettlementsExchangeRates.Multiplicity) AS NUMBER(15, 2))
	|		END) * CASE
	|		WHEN DocumentTable.RecordType = VALUE(AccumulationRecordType.Receipt)
	|			THEN -1
	|		ELSE 1
	|	END AS AdvanceAmount,
	|	SUM(CASE
	|			WHEN DocumentTable.AdvanceFlag
	|				THEN 0
	|			ELSE CAST(DocumentTable.SettlementsAmount * SettlementsExchangeRates.ExchangeRate * ExchangeRatesOfAccount.Multiplicity / (ExchangeRatesOfAccount.ExchangeRate * SettlementsExchangeRates.Multiplicity) AS NUMBER(15, 2))
	|		END) * CASE
	|		WHEN DocumentTable.RecordType = VALUE(AccumulationRecordType.Receipt)
	|			THEN -1
	|		ELSE 1
	|	END AS PaymentAmount
	|FROM
	|	TemporaryTableCustomers AS DocumentTable
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&PointInTime, ) AS ExchangeRatesOfAccount
	|		ON DocumentTable.Order.DocumentCurrency = ExchangeRatesOfAccount.Currency
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&PointInTime, ) AS SettlementsExchangeRates
	|		ON DocumentTable.Currency = SettlementsExchangeRates.Currency
	|		LEFT JOIN Constants AS Constants
	|		ON (TRUE)
	|WHERE
	|	VALUETYPE(DocumentTable.Order) = TYPE(Document.SalesOrder)
	|	AND DocumentTable.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|
	|GROUP BY
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	DocumentTable.Order,
	|	DocumentTable.RecordType
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	&Company,
	|	DocumentTable.Order,
	|	SUM(CASE
	|			WHEN NOT DocumentTable.AdvanceFlag
	|				THEN 0
	|			ELSE CAST(DocumentTable.SettlementsAmount * SettlementsExchangeRates.ExchangeRate * ExchangeRatesOfAccount.Multiplicity / (ExchangeRatesOfAccount.ExchangeRate * SettlementsExchangeRates.Multiplicity) AS NUMBER(15, 2))
	|		END) * CASE
	|		WHEN DocumentTable.RecordType = VALUE(AccumulationRecordType.Receipt)
	|			THEN -1
	|		ELSE 1
	|	END,
	|	SUM(CASE
	|			WHEN DocumentTable.AdvanceFlag
	|				THEN 0
	|			ELSE CAST(DocumentTable.SettlementsAmount * SettlementsExchangeRates.ExchangeRate * ExchangeRatesOfAccount.Multiplicity / (ExchangeRatesOfAccount.ExchangeRate * SettlementsExchangeRates.Multiplicity) AS NUMBER(15, 2))
	|		END) * CASE
	|		WHEN DocumentTable.RecordType = VALUE(AccumulationRecordType.Receipt)
	|			THEN -1
	|		ELSE 1
	|	END
	|FROM
	|	TemporaryTableVendors AS DocumentTable
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&PointInTime, ) AS ExchangeRatesOfAccount
	|		ON DocumentTable.Order.DocumentCurrency = ExchangeRatesOfAccount.Currency
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&PointInTime, ) AS SettlementsExchangeRates
	|		ON DocumentTable.Currency = SettlementsExchangeRates.Currency
	|		LEFT JOIN Constants AS Constants
	|		ON (TRUE)
	|WHERE
	|	VALUETYPE(DocumentTable.Order) = TYPE(Document.PurchaseOrder)
	|	AND DocumentTable.Order <> VALUE(Document.PurchaseOrder.EmptyRef)
	|
	|GROUP BY
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	DocumentTable.Order,
	|	DocumentTable.RecordType
	|
	|ORDER BY
	|	LineNumber";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInvoicesAndOrdersPayment", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableIncomeAndExpensesCashMethod(DocumentRefArApAdjustments, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefArApAdjustments);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("IncomeAndExpensesAccountingCashMethod", StructureAdditionalProperties.AccountingPolicy.IncomeAndExpensesAccountingCashMethod);
	
	Query.Text =
	"SELECT
	|	1 AS Ordering,
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Ref.Date AS Period,
	|	&Company AS Company,
	|	UNDEFINED AS BusinessLine,
	|	DocumentTable.Document.Item AS Item,
	|	0 AS AmountIncome,
	|	-DocumentTable.AccountingAmount AS AmountExpense
	|FROM
	|	Document.ArApAdjustments.Creditor AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.Ref = &Ref
	|	AND (DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.ArApAdjustments)
	|			OR DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.CustomerDebtAssignment)
	|			OR DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.DebtAssignmentToVendor))
	|	AND DocumentTable.AdvanceFlag
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Ref.Date,
	|	&Company,
	|	UNDEFINED,
	|	VALUE(Catalog.CashFlowItems.PaymentToVendor),
	|	0,
	|	DocumentTable.AccountingAmount
	|FROM
	|	Document.ArApAdjustments.Creditor AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.Ref = &Ref
	|	AND (DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.ArApAdjustments)
	|			OR DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.CustomerDebtAssignment)
	|			OR DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.DebtAssignmentToVendor))
	|	AND DocumentTable.AdvanceFlag
	|
	|UNION ALL
	|
	|SELECT
	|	3,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Ref.Date,
	|	&Company,
	|	UNDEFINED,
	|	DocumentTable.Document.Item,
	|	0,
	|	CASE
	|		WHEN DocumentTable.Ref.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherIncome)
	|			THEN DocumentTable.AccountingAmount
	|		ELSE -DocumentTable.AccountingAmount
	|	END
	|FROM
	|	Document.ArApAdjustments.Creditor AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.Ref = &Ref
	|	AND DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.VendorDebtAdjustment)
	|	AND DocumentTable.AdvanceFlag
	|
	|UNION ALL
	|
	|SELECT
	|	4,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Ref.Date,
	|	&Company,
	|	UNDEFINED,
	|	DocumentTable.Document.Item,
	|	-DocumentTable.AccountingAmount,
	|	0
	|FROM
	|	Document.ArApAdjustments.Debitor AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.Ref = &Ref
	|	AND (DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.ArApAdjustments)
	|			OR DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.CustomerDebtAssignment)
	|			OR DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.DebtAssignmentToVendor))
	|	AND DocumentTable.AdvanceFlag
	|
	|UNION ALL
	|
	|SELECT
	|	5,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Ref.Date,
	|	&Company,
	|	UNDEFINED,
	|	VALUE(Catalog.CashFlowItems.PaymentToVendor),
	|	DocumentTable.AccountingAmount,
	|	0
	|FROM
	|	Document.ArApAdjustments.Debitor AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.Ref = &Ref
	|	AND (DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.ArApAdjustments)
	|			OR DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.CustomerDebtAssignment)
	|			OR DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.DebtAssignmentToVendor))
	|	AND DocumentTable.AdvanceFlag
	|
	|UNION ALL
	|
	|SELECT
	|	6,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Ref.Date,
	|	&Company,
	|	UNDEFINED,
	|	DocumentTable.Document.Item,
	|	CASE
	|		WHEN DocumentTable.Ref.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherExpenses)
	|			THEN DocumentTable.AccountingAmount
	|		ELSE -DocumentTable.AccountingAmount
	|	END,
	|	0
	|FROM
	|	Document.ArApAdjustments.Debitor AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.Ref = &Ref
	|	AND DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.CustomerDebtAdjustment)
	|	AND DocumentTable.AdvanceFlag
	|
	|ORDER BY
	|	Ordering,
	|	LineNumber";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpensesCashMethod", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableUnallocatedExpenses(DocumentRefArApAdjustments, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefArApAdjustments);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("IncomeAndExpensesAccountingCashMethod", StructureAdditionalProperties.AccountingPolicy.IncomeAndExpensesAccountingCashMethod);
	
	Query.Text =
	"SELECT
	|	1 AS Ordering,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Ref.Date AS Period,
	|	&Company AS Company,
	|	CASE
	|		WHEN DocumentTable.Ref.CounterpartySource.DoOperationsByDocuments
	|			THEN DocumentTable.Document
	|		ELSE UNDEFINED
	|	END AS Document,
	|	CASE
	|		WHEN DocumentTable.Ref.CounterpartySource.DoOperationsByDocuments
	|			THEN DocumentTable.Document.Item
	|		ELSE CASE
	|				WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.ArApAdjustments)
	|						OR DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.CustomerDebtAssignment)
	|					THEN VALUE(Catalog.CashFlowItems.PaymentFromCustomers)
	|				ELSE VALUE(Catalog.CashFlowItems.PaymentToVendor)
	|			END
	|	END AS Item,
	|	0 AS AmountIncome,
	|	DocumentTable.AccountingAmount AS AmountExpense
	|FROM
	|	Document.ArApAdjustments.Creditor AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.Ref = &Ref
	|	AND (DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.ArApAdjustments)
	|			OR DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.CustomerDebtAssignment)
	|			OR DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.DebtAssignmentToVendor))
	|	AND DocumentTable.AdvanceFlag
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	VALUE(AccumulationRecordType.Receipt),
	|	DocumentTable.LineNumber,
	|	DocumentTable.Ref.Date,
	|	&Company,
	|	CASE
	|		WHEN DocumentTable.Ref.Counterparty.DoOperationsByDocuments
	|			THEN &Ref
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.Counterparty.DoOperationsByDocuments
	|			THEN DocumentTable.Document.Item
	|		ELSE CASE
	|				WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.ArApAdjustments)
	|						OR DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.DebtAssignmentToVendor)
	|					THEN VALUE(Catalog.CashFlowItems.PaymentToVendor)
	|				ELSE VALUE(Catalog.CashFlowItems.PaymentFromCustomers)
	|			END
	|	END,
	|	0,
	|	DocumentTable.AccountingAmount
	|FROM
	|	Document.ArApAdjustments.Creditor AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.Ref = &Ref
	|	AND (DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.ArApAdjustments)
	|			OR DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.CustomerDebtAssignment)
	|			OR DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.DebtAssignmentToVendor))
	|	AND DocumentTable.AdvanceFlag
	|
	|UNION ALL
	|
	|SELECT
	|	3,
	|	VALUE(AccumulationRecordType.Expense),
	|	DocumentTable.LineNumber,
	|	DocumentTable.Ref.Date,
	|	&Company,
	|	CASE
	|		WHEN DocumentTable.Ref.CounterpartySource.DoOperationsByDocuments
	|			THEN DocumentTable.Document
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.CounterpartySource.DoOperationsByDocuments
	|			THEN DocumentTable.Document.Item
	|		ELSE CASE
	|				WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.ArApAdjustments)
	|						OR DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.CustomerDebtAssignment)
	|					THEN VALUE(Catalog.CashFlowItems.PaymentFromCustomers)
	|				ELSE VALUE(Catalog.CashFlowItems.PaymentToVendor)
	|			END
	|	END,
	|	DocumentTable.AccountingAmount,
	|	0
	|FROM
	|	Document.ArApAdjustments.Debitor AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.Ref = &Ref
	|	AND (DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.ArApAdjustments)
	|			OR DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.CustomerDebtAssignment)
	|			OR DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.DebtAssignmentToVendor))
	|	AND DocumentTable.AdvanceFlag
	|
	|UNION ALL
	|
	|SELECT
	|	4,
	|	VALUE(AccumulationRecordType.Receipt),
	|	DocumentTable.LineNumber,
	|	DocumentTable.Ref.Date,
	|	&Company,
	|	CASE
	|		WHEN DocumentTable.Ref.Counterparty.DoOperationsByDocuments
	|			THEN &Ref
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.Counterparty.DoOperationsByDocuments
	|			THEN DocumentTable.Document.Item
	|		ELSE CASE
	|				WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.ArApAdjustments)
	|						OR DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.DebtAssignmentToVendor)
	|					THEN VALUE(Catalog.CashFlowItems.PaymentToVendor)
	|				ELSE VALUE(Catalog.CashFlowItems.PaymentFromCustomers)
	|			END
	|	END,
	|	DocumentTable.AccountingAmount,
	|	0
	|FROM
	|	Document.ArApAdjustments.Debitor AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.Ref = &Ref
	|	AND (DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.ArApAdjustments)
	|			OR DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.CustomerDebtAssignment)
	|			OR DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.DebtAssignmentToVendor))
	|	AND DocumentTable.AdvanceFlag
	|
	|UNION ALL
	|
	|SELECT
	|	5,
	|	VALUE(AccumulationRecordType.Receipt),
	|	DocumentTable.LineNumber,
	|	DocumentTable.Ref.Date,
	|	&Company,
	|	CASE
	|		WHEN DocumentTable.Ref.CounterpartySource.DoOperationsByDocuments
	|			THEN DocumentTable.Document
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.CounterpartySource.DoOperationsByDocuments
	|			THEN DocumentTable.Document.Item
	|		ELSE VALUE(Catalog.CashFlowItems.PaymentFromCustomers)
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherExpenses)
	|			THEN DocumentTable.AccountingAmount
	|		ELSE -DocumentTable.AccountingAmount
	|	END,
	|	0
	|FROM
	|	Document.ArApAdjustments.Debitor AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.Ref = &Ref
	|	AND DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.CustomerDebtAdjustment)
	|	AND DocumentTable.AdvanceFlag
	|
	|UNION ALL
	|
	|SELECT
	|	6,
	|	VALUE(AccumulationRecordType.Receipt),
	|	DocumentTable.LineNumber,
	|	DocumentTable.Ref.Date,
	|	&Company,
	|	CASE
	|		WHEN DocumentTable.Ref.Counterparty.DoOperationsByDocuments
	|			THEN DocumentTable.Document
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.Counterparty.DoOperationsByDocuments
	|			THEN DocumentTable.Document.Item
	|		ELSE VALUE(Catalog.CashFlowItems.PaymentToVendor)
	|	END,
	|	0,
	|	CASE
	|		WHEN DocumentTable.Ref.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherIncome)
	|			THEN DocumentTable.AccountingAmount
	|		ELSE -DocumentTable.AccountingAmount
	|	END
	|FROM
	|	Document.ArApAdjustments.Creditor AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.Ref = &Ref
	|	AND DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.VendorDebtAdjustment)
	|	AND DocumentTable.AdvanceFlag
	|
	|ORDER BY
	|	Ordering,
	|	LineNumber";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableUnallocatedExpenses", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableIncomeAndExpensesRetained(DocumentRefArApAdjustments, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefArApAdjustments);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("IncomeAndExpensesAccountingCashMethod", StructureAdditionalProperties.AccountingPolicy.IncomeAndExpensesAccountingCashMethod);
	Query.SetParameter("Period", StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("DocumentArray", StructureAdditionalProperties.ForPosting.PointInTime.Date);
	
	// Generating the table with charge amounts.
	Query.Text =
	"SELECT
	|	&Company AS Company,
	|	CASE
	|		WHEN DocumentTable.Ref.CounterpartySource.DoOperationsByDocuments
	|			THEN DocumentTable.Document
	|		ELSE UNDEFINED
	|	END AS Document,
	|	DocumentTable.Ref.OperationKind AS OperationKind,
	|	SUM(DocumentTable.AccountingAmount) AS AmountToBeWrittenOff
	|FROM
	|	Document.ArApAdjustments.Debitor AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.Ref = &Ref
	|	AND DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.CustomerDebtAssignment)
	|	AND Not DocumentTable.AdvanceFlag
	|
	|GROUP BY
	|	DocumentTable.Document,
	|	DocumentTable.Ref,
	|	DocumentTable.Ref.OperationKind,
	|	CASE
	|		WHEN DocumentTable.Ref.CounterpartySource.DoOperationsByDocuments
	|			THEN DocumentTable.Document
	|		ELSE UNDEFINED
	|	END";
	
	QueryResult = Query.Execute();
	
	// Setting of the exclusive lock of the cash funds controlled balances.
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.IncomeAndExpensesRetained");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;
	LockItem.UseFromDataSource("Company", "Company");
	LockItem.UseFromDataSource("Document", "Document");
	Block.Lock();
	
	TableAmountForWriteOff = QueryResult.Unload();
	
	// Generating the table with remaining balance.
	Query.Text =
	"SELECT
	|	&Period AS Period,
	|	IncomeAndExpensesRetainedBalances.Company AS Company,
	|	IncomeAndExpensesRetainedBalances.Document AS Document,
	|	IncomeAndExpensesRetainedBalances.BusinessLine AS BusinessLine,
	|	0 AS AmountIncome,
	|	0 AS AmountExpense,
	|	SUM(IncomeAndExpensesRetainedBalances.AmountIncomeBalance) AS AmountIncomeBalance,
	|	SUM(IncomeAndExpensesRetainedBalances.AmountExpenseBalance) AS AmountExpenseBalance
	|FROM
	|	(SELECT
	|		IncomeAndExpensesRetainedBalances.Company AS Company,
	|		IncomeAndExpensesRetainedBalances.Document AS Document,
	|		IncomeAndExpensesRetainedBalances.BusinessLine AS BusinessLine,
	|		IncomeAndExpensesRetainedBalances.AmountIncomeBalance AS AmountIncomeBalance,
	|		IncomeAndExpensesRetainedBalances.AmountExpenseBalance AS AmountExpenseBalance
	|	FROM
	|		AccumulationRegister.IncomeAndExpensesRetained.Balance(
	|				,
	|				Company = &Company
	|					AND Document In
	|						(SELECT
	|							DocumentTable.Document
	|						FROM
	|							Document.ArApAdjustments.Debitor AS DocumentTable
	|						WHERE
	|							DocumentTable.Ref = &Ref
	|				
	|						UNION ALL
	|				
	|						SELECT
	|							DocumentTable.Document
	|						FROM
	|							Document.ArApAdjustments.Creditor AS DocumentTable
	|						WHERE
	|							DocumentTable.Ref = &Ref)) AS IncomeAndExpensesRetainedBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsOfIncomeAndExpensesPending.Company,
	|		DocumentRegisterRecordsOfIncomeAndExpensesPending.Document,
	|		DocumentRegisterRecordsOfIncomeAndExpensesPending.BusinessLine,
	|		CASE
	|			WHEN DocumentRegisterRecordsOfIncomeAndExpensesPending.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -ISNULL(DocumentRegisterRecordsOfIncomeAndExpensesPending.AmountIncome, 0)
	|			ELSE ISNULL(DocumentRegisterRecordsOfIncomeAndExpensesPending.AmountIncome, 0)
	|		END,
	|		CASE
	|			WHEN DocumentRegisterRecordsOfIncomeAndExpensesPending.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -ISNULL(DocumentRegisterRecordsOfIncomeAndExpensesPending.AmountExpense, 0)
	|			ELSE ISNULL(DocumentRegisterRecordsOfIncomeAndExpensesPending.AmountExpense, 0)
	|		END
	|	FROM
	|		AccumulationRegister.IncomeAndExpensesRetained AS DocumentRegisterRecordsOfIncomeAndExpensesPending
	|	WHERE
	|		DocumentRegisterRecordsOfIncomeAndExpensesPending.Recorder = &Ref) AS IncomeAndExpensesRetainedBalances
	|
	|GROUP BY
	|	IncomeAndExpensesRetainedBalances.Company,
	|	IncomeAndExpensesRetainedBalances.Document,
	|	IncomeAndExpensesRetainedBalances.BusinessLine
	|
	|ORDER BY
	|	Document";
	
	TableSumBalance = Query.Execute().Unload();
	
	TableSumBalance.Indexes.Add("Document");
	
	// Calculation of the write-off amounts.
	For Each StringSumToBeWrittenOff In TableAmountForWriteOff Do
		AmountToBeWrittenOff = StringSumToBeWrittenOff.AmountToBeWrittenOff;
		Filter = New Structure("Document", StringSumToBeWrittenOff.Document);
		RowsArrayAmountsBalances = TableSumBalance.FindRows(Filter);
		For Each AmountRowBalances In RowsArrayAmountsBalances Do
			If AmountToBeWrittenOff = 0 Then
				Continue
			ElsIf AmountRowBalances.AmountIncomeBalance < AmountToBeWrittenOff Then
				AmountRowBalances.AmountIncome = AmountRowBalances.AmountIncomeBalance;
				AmountToBeWrittenOff = AmountToBeWrittenOff - AmountRowBalances.AmountIncomeBalance;
			ElsIf AmountRowBalances.AmountIncomeBalance >= AmountToBeWrittenOff Then
				AmountRowBalances.AmountIncome = AmountToBeWrittenOff;
				AmountToBeWrittenOff = 0;
			EndIf;
		EndDo;
	EndDo;
	
	// Generating the table with charge amounts.
	Query.Text =
	"SELECT
	|	&Company AS Company,
	|	CASE
	|		WHEN DocumentTable.Ref.CounterpartySource.DoOperationsByDocuments
	|			THEN DocumentTable.Document
	|		ELSE UNDEFINED
	|	END AS Document,
	|	DocumentTable.Ref.OperationKind AS OperationKind,
	|	SUM(DocumentTable.AccountingAmount) AS AmountToBeWrittenOff
	|FROM
	|	Document.ArApAdjustments.Creditor AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.Ref = &Ref
	|	AND DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.DebtAssignmentToVendor)
	|	AND Not DocumentTable.AdvanceFlag
	|
	|GROUP BY
	|	DocumentTable.Document,
	|	DocumentTable.Ref,
	|	DocumentTable.Ref.OperationKind,
	|	CASE
	|		WHEN DocumentTable.Ref.CounterpartySource.DoOperationsByDocuments
	|			THEN DocumentTable.Document
	|		ELSE UNDEFINED
	|	END"; 
	
	TableAmountForWriteOff = Query.Execute().Unload();
	
	For Each StringSumToBeWrittenOff In TableAmountForWriteOff Do
		AmountToBeWrittenOff = StringSumToBeWrittenOff.AmountToBeWrittenOff;
		Filter = New Structure("Document", StringSumToBeWrittenOff.Document);
		RowsArrayAmountsBalances = TableSumBalance.FindRows(Filter);
		For Each AmountRowBalances In RowsArrayAmountsBalances Do
			If AmountToBeWrittenOff = 0 Then
				Continue
			ElsIf AmountRowBalances.AmountExpenseBalance < AmountToBeWrittenOff Then
				AmountRowBalances.AmountExpense = AmountRowBalances.AmountExpenseBalance;
				AmountToBeWrittenOff = AmountToBeWrittenOff - AmountRowBalances.AmountExpenseBalance;
			ElsIf AmountRowBalances.AmountExpenseBalance >= AmountToBeWrittenOff Then
				AmountRowBalances.AmountExpense = AmountToBeWrittenOff;
				AmountToBeWrittenOff = 0;
			EndIf;
		EndDo;
	EndDo;

	
	// Generating a temporary table with amounts,
	// items and directions of activities. Required to generate movements of income
	// and expenses by cash method.
	Query.Text =
	"SELECT
	|	Table.Period AS Period,
	|	Table.Company AS Company,
	|	Table.Document AS Document,
	|	Table.AmountIncome AS AmountIncome,
	|	Table.AmountExpense AS AmountExpense,
	|	Table.BusinessLine AS BusinessLine
	|INTO TemporaryTableTableDeferredIncomeAndExpenditure
	|FROM
	|	&Table AS Table
	|WHERE
	|	(Table.AmountIncome > 0
	|			OR Table.AmountExpense > 0)";
	
	Query.SetParameter("Table", TableSumBalance);
	
	Query.Execute();
	
	// Generating the table for recording in the register.
	Query.Text =
	"SELECT
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	Table.Period AS Period,
	|	Table.Company AS Company,
	|	Table.Document AS Document,
	|	Table.AmountIncome AS AmountIncome,
	|	Table.AmountExpense AS AmountExpense,
	|	Table.BusinessLine AS BusinessLine
	|FROM
	|	TemporaryTableTableDeferredIncomeAndExpenditure AS Table
	|
	|UNION ALL
	|
	|SELECT
	|	VALUE(AccumulationRecordType.Receipt),
	|	Table.Period,
	|	Table.Company,
	|	&Ref,
	|	Table.AmountIncome,
	|	Table.AmountExpense,
	|	Table.BusinessLine
	|FROM
	|	TemporaryTableTableDeferredIncomeAndExpenditure AS Table";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpensesRetained", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableIncomeAndExpenses(DocumentRefArApAdjustments, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.Text =
	"SELECT
	|	1 AS Ordering,
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Date AS Period,
	|	DocumentTable.Company AS Company,
	|	UNDEFINED AS StructuralUnit,
	|	UNDEFINED AS Order,
	|	VALUE(Catalog.LinesOfBusiness.Other) AS BusinessLine,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN &NegativeExchangeDifferenceAccountOfAccounting
	|		ELSE &PositiveExchangeDifferenceGLAccount
	|	END AS GLAccount,
	|	&ExchangeDifference AS ContentOfAccountingRecord,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN 0
	|		ELSE -DocumentTable.AmountOfExchangeDifferences
	|	END AS AmountIncome,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN DocumentTable.AmountOfExchangeDifferences
	|		ELSE 0
	|	END AS AmountExpense,
	|	FALSE AS OfflineRecord
	|FROM
	|	TemporaryTableOfExchangeRateDifferencesAccountsPayable AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	UNDEFINED,
	|	UNDEFINED,
	|	VALUE(Catalog.LinesOfBusiness.Other),
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
	|	TemporaryTableExchangeRateDifferencesAccountsReceivable AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	3,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	&Company,
	|	UNDEFINED,
	|	UNDEFINED,
	|	VALUE(Catalog.LinesOfBusiness.Other),
	|	DocumentTable.Correspondence,
	|	&DebtAdjustment,
	|	CASE
	|		WHEN DocumentTable.CorrespondenceGLAccountType = VALUE(Enum.GLAccountsTypes.OtherIncome)
	|			THEN DocumentTable.AccountingAmount
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.CorrespondenceGLAccountType = VALUE(Enum.GLAccountsTypes.OtherExpenses)
	|			THEN DocumentTable.AccountingAmount
	|		ELSE 0
	|	END,
	|	FALSE
	|FROM
	|	TemporaryTableCustomers AS DocumentTable
	|WHERE
	|	DocumentTable.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.CustomerDebtAdjustment)
	|
	|UNION ALL
	|
	|SELECT
	|	4,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	&Company,
	|	UNDEFINED,
	|	UNDEFINED,
	|	VALUE(Catalog.LinesOfBusiness.Other),
	|	DocumentTable.Correspondence,
	|	&DebtAdjustment,
	|	CASE
	|		WHEN DocumentTable.CorrespondenceGLAccountType = VALUE(Enum.GLAccountsTypes.OtherIncome)
	|			THEN DocumentTable.AccountingAmount
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.CorrespondenceGLAccountType = VALUE(Enum.GLAccountsTypes.OtherExpenses)
	|			THEN DocumentTable.AccountingAmount
	|		ELSE 0
	|	END,
	|	FALSE
	|FROM
	|	TemporaryTableVendors AS DocumentTable
	|WHERE
	|	DocumentTable.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.VendorDebtAdjustment)
	|
	|ORDER BY
	|	Ordering,
	|	LineNumber";
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();

	Query.SetParameter("Ref",											DocumentRefArApAdjustments);
	Query.SetParameter("Company",										StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PointInTime",									New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ExchangeDifference",							NStr("en = 'Foreign currency exchange gains and losses'", MainLanguageCode));
	Query.SetParameter("DebtAdjustment",								NStr("en = 'AR/AP Adjustments'", MainLanguageCode));
	Query.SetParameter("PositiveExchangeDifferenceGLAccount",			Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeGain"));
	Query.SetParameter("NegativeExchangeDifferenceAccountOfAccounting",	Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeLoss"));

	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpenses", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableAccountingJournalEntries(DocumentRefArApAdjustments, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();

	Query.SetParameter("Company",						StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("Ref",							DocumentRefArApAdjustments);
	Query.SetParameter("ArApAdjustments",				"ArApAdjustments");
	Query.SetParameter("Novation",						NStr("en = 'Novation'", MainLanguageCode));
	Query.SetParameter("DebtAdjustment",				NStr("en = 'AR/AP Adjustments'", MainLanguageCode));
	Query.SetParameter("ExchangeDifference",			NStr("en = 'Foreign currency exchange gains and losses'", MainLanguageCode));
	Query.SetParameter("ForeignCurrencyExchangeGain",	Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeGain")); 
	Query.SetParameter("ForeignCurrencyExchangeLoss",	Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeLoss"));
	
	Query.Text =
	"SELECT
	|	1 AS Ordering,
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Ref.Date AS Period,
	|	&Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	&FundsTransfersBeingProcessed AS AccountDr,
	|	UNDEFINED AS CurrencyDr,
	|	0 AS AmountCurDr,
	|	DocumentTable.Ref.CounterpartySource.GLAccountCustomerSettlements AS AccountCr,
	|	CASE
	|		WHEN DocumentTable.Ref.CounterpartySource.GLAccountCustomerSettlements.Currency
	|			THEN DocumentTable.Contract.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	CASE
	|		WHEN DocumentTable.Ref.CounterpartySource.GLAccountCustomerSettlements.Currency
	|			THEN DocumentTable.SettlementsAmount
	|		ELSE 0
	|	END AS AmountCurCr,
	|	DocumentTable.AccountingAmount AS Amount,
	|	CASE
	|		WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.ArApAdjustments)
	|			THEN &ArApAdjustments
	|		ELSE &Novation
	|	END AS Content,
	|	FALSE AS Offlinerecord
	|FROM
	|	Document.ArApAdjustments.Debitor AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|	AND DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.ArApAdjustments)
	|	AND NOT DocumentTable.AdvanceFlag
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Ref.Date,
	|	&Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.Ref.CounterpartySource.CustomerAdvancesGLAccount,
	|	CASE
	|		WHEN DocumentTable.Ref.CounterpartySource.CustomerAdvancesGLAccount.Currency
	|			THEN DocumentTable.Contract.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.CounterpartySource.CustomerAdvancesGLAccount.Currency
	|			THEN DocumentTable.SettlementsAmount
	|		ELSE 0
	|	END,
	|	&FundsTransfersBeingProcessed,
	|	UNDEFINED,
	|	0,
	|	DocumentTable.AccountingAmount,
	|	CASE
	|		WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.ArApAdjustments)
	|			THEN &ArApAdjustments
	|		ELSE &Novation
	|	END,
	|	FALSE
	|FROM
	|	Document.ArApAdjustments.Debitor AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|	AND DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.ArApAdjustments)
	|	AND DocumentTable.AdvanceFlag
	|
	|UNION ALL
	|
	|SELECT
	|	3,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Ref.Date,
	|	&Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	CASE
	|		WHEN DocumentTable.Ref.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherExpenses)
	|			THEN DocumentTable.Ref.Correspondence
	|		ELSE DocumentTable.Ref.CounterpartySource.GLAccountCustomerSettlements
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherIncome)
	|				AND DocumentTable.Ref.CounterpartySource.GLAccountCustomerSettlements.Currency
	|			THEN DocumentTable.Contract.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherIncome)
	|				AND DocumentTable.Ref.CounterpartySource.GLAccountCustomerSettlements.Currency
	|			THEN DocumentTable.SettlementsAmount
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherExpenses)
	|			THEN DocumentTable.Ref.CounterpartySource.GLAccountCustomerSettlements
	|		ELSE DocumentTable.Ref.Correspondence
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherExpenses)
	|				AND DocumentTable.Ref.CounterpartySource.GLAccountCustomerSettlements.Currency
	|			THEN DocumentTable.Contract.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherExpenses)
	|				AND DocumentTable.Ref.CounterpartySource.GLAccountCustomerSettlements.Currency
	|			THEN DocumentTable.SettlementsAmount
	|		ELSE 0
	|	END,
	|	DocumentTable.AccountingAmount,
	|	&DebtAdjustment,
	|	FALSE
	|FROM
	|	Document.ArApAdjustments.Debitor AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|	AND DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.CustomerDebtAdjustment)
	|	AND NOT DocumentTable.AdvanceFlag
	|
	|UNION ALL
	|
	|SELECT
	|	4,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Ref.Date,
	|	&Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	CASE
	|		WHEN DocumentTable.Ref.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherIncome)
	|			THEN DocumentTable.Ref.CounterpartySource.CustomerAdvancesGLAccount
	|		ELSE DocumentTable.Ref.Correspondence
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherIncome)
	|				AND DocumentTable.Ref.CounterpartySource.CustomerAdvancesGLAccount.Currency
	|			THEN DocumentTable.Contract.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherIncome)
	|				AND DocumentTable.Ref.CounterpartySource.CustomerAdvancesGLAccount.Currency
	|			THEN DocumentTable.SettlementsAmount
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherExpenses)
	|			THEN DocumentTable.Ref.CounterpartySource.CustomerAdvancesGLAccount
	|		ELSE DocumentTable.Ref.Correspondence
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherExpenses)
	|				AND DocumentTable.Ref.CounterpartySource.CustomerAdvancesGLAccount.Currency
	|			THEN DocumentTable.Contract.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherExpenses)
	|				AND DocumentTable.Ref.CounterpartySource.CustomerAdvancesGLAccount.Currency
	|			THEN DocumentTable.SettlementsAmount
	|		ELSE 0
	|	END,
	|	DocumentTable.AccountingAmount,
	|	&DebtAdjustment,
	|	FALSE
	|FROM
	|	Document.ArApAdjustments.Debitor AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|	AND DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.CustomerDebtAdjustment)
	|	AND DocumentTable.AdvanceFlag
	|
	|UNION ALL
	|
	|SELECT
	|	5,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Ref.Date,
	|	&Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.Ref.Counterparty.GLAccountVendorSettlements,
	|	CASE
	|		WHEN DocumentTable.Ref.Counterparty.GLAccountVendorSettlements.Currency
	|			THEN DocumentTable.Contract.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.Counterparty.GLAccountVendorSettlements.Currency
	|			THEN DocumentTable.SettlementsAmount
	|		ELSE 0
	|	END,
	|	&FundsTransfersBeingProcessed,
	|	UNDEFINED,
	|	0,
	|	DocumentTable.AccountingAmount,
	|	CASE
	|		WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.ArApAdjustments)
	|			THEN &ArApAdjustments
	|		ELSE &Novation
	|	END,
	|	FALSE
	|FROM
	|	Document.ArApAdjustments.Creditor AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|	AND DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.ArApAdjustments)
	|	AND NOT DocumentTable.AdvanceFlag
	|
	|UNION ALL
	|
	|SELECT
	|	3,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Ref.Date,
	|	&Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	CASE
	|		WHEN DocumentTable.Ref.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherExpenses)
	|			THEN DocumentTable.Ref.Correspondence
	|		ELSE DocumentTable.Ref.Counterparty.GLAccountVendorSettlements
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherIncome)
	|				AND DocumentTable.Ref.Counterparty.GLAccountVendorSettlements.Currency
	|			THEN DocumentTable.Contract.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherIncome)
	|				AND DocumentTable.Ref.Counterparty.GLAccountVendorSettlements.Currency
	|			THEN DocumentTable.SettlementsAmount
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherExpenses)
	|			THEN DocumentTable.Ref.Counterparty.GLAccountVendorSettlements
	|		ELSE DocumentTable.Ref.Correspondence
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherExpenses)
	|				AND DocumentTable.Ref.Counterparty.GLAccountVendorSettlements.Currency
	|			THEN DocumentTable.Contract.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherExpenses)
	|				AND DocumentTable.Ref.Counterparty.GLAccountVendorSettlements.Currency
	|			THEN DocumentTable.SettlementsAmount
	|		ELSE 0
	|	END,
	|	DocumentTable.AccountingAmount,
	|	&DebtAdjustment,
	|	FALSE
	|FROM
	|	Document.ArApAdjustments.Creditor AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|	AND DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.VendorDebtAdjustment)
	|	AND NOT DocumentTable.AdvanceFlag
	|
	|UNION ALL
	|
	|SELECT
	|	4,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Ref.Date,
	|	&Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	CASE
	|		WHEN DocumentTable.Ref.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherIncome)
	|			THEN DocumentTable.Ref.Counterparty.VendorAdvancesGLAccount
	|		ELSE DocumentTable.Ref.Correspondence
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherIncome)
	|				AND DocumentTable.Ref.Counterparty.VendorAdvancesGLAccount.Currency
	|			THEN DocumentTable.Contract.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherIncome)
	|				AND DocumentTable.Ref.Counterparty.VendorAdvancesGLAccount.Currency
	|			THEN DocumentTable.SettlementsAmount
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherExpenses)
	|			THEN DocumentTable.Ref.Counterparty.VendorAdvancesGLAccount
	|		ELSE DocumentTable.Ref.Correspondence
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherExpenses)
	|				AND DocumentTable.Ref.Counterparty.VendorAdvancesGLAccount.Currency
	|			THEN DocumentTable.Contract.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherExpenses)
	|				AND DocumentTable.Ref.CounterpartySource.VendorAdvancesGLAccount.Currency
	|			THEN DocumentTable.SettlementsAmount
	|		ELSE 0
	|	END,
	|	DocumentTable.AccountingAmount,
	|	&DebtAdjustment,
	|	FALSE
	|FROM
	|	Document.ArApAdjustments.Creditor AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|	AND DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.VendorDebtAdjustment)
	|	AND DocumentTable.AdvanceFlag
	|
	|UNION ALL
	|
	|SELECT
	|	6,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Ref.Date,
	|	&Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	&FundsTransfersBeingProcessed,
	|	UNDEFINED,
	|	0,
	|	DocumentTable.Ref.Counterparty.VendorAdvancesGLAccount,
	|	CASE
	|		WHEN DocumentTable.Ref.Counterparty.VendorAdvancesGLAccount.Currency
	|			THEN DocumentTable.Contract.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.Counterparty.VendorAdvancesGLAccount.Currency
	|			THEN DocumentTable.SettlementsAmount
	|		ELSE 0
	|	END,
	|	DocumentTable.AccountingAmount,
	|	CASE
	|		WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.ArApAdjustments)
	|			THEN &ArApAdjustments
	|		ELSE &Novation
	|	END,
	|	FALSE
	|FROM
	|	Document.ArApAdjustments.Creditor AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|	AND DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.ArApAdjustments)
	|	AND DocumentTable.AdvanceFlag
	|
	|UNION ALL
	|
	|SELECT
	|	7,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Ref.Date,
	|	&Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.Ref.Counterparty.GLAccountCustomerSettlements,
	|	CASE
	|		WHEN DocumentTable.Ref.Counterparty.GLAccountCustomerSettlements.Currency
	|			THEN DocumentTable.Ref.Contract.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.Counterparty.GLAccountCustomerSettlements.Currency
	|			THEN DocumentTable.AccountingAmount / DocumentTable.Ref.AccountingAmount * DocumentTable.Ref.SettlementsAmount
	|		ELSE 0
	|	END,
	|	DocumentTable.Ref.CounterpartySource.GLAccountCustomerSettlements,
	|	CASE
	|		WHEN DocumentTable.Ref.CounterpartySource.GLAccountCustomerSettlements.Currency
	|			THEN DocumentTable.Contract.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.CounterpartySource.GLAccountCustomerSettlements.Currency
	|			THEN DocumentTable.SettlementsAmount
	|		ELSE 0
	|	END,
	|	DocumentTable.AccountingAmount,
	|	CASE
	|		WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.ArApAdjustments)
	|			THEN &ArApAdjustments
	|		ELSE &Novation
	|	END,
	|	FALSE
	|FROM
	|	Document.ArApAdjustments.Debitor AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|	AND DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.CustomerDebtAssignment)
	|	AND NOT DocumentTable.AdvanceFlag
	|
	|UNION ALL
	|
	|SELECT
	|	8,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Ref.Date,
	|	&Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.Ref.CounterpartySource.CustomerAdvancesGLAccount,
	|	CASE
	|		WHEN DocumentTable.Ref.CounterpartySource.CustomerAdvancesGLAccount.Currency
	|			THEN DocumentTable.Contract.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.CounterpartySource.CustomerAdvancesGLAccount.Currency
	|			THEN DocumentTable.SettlementsAmount
	|		ELSE 0
	|	END,
	|	DocumentTable.Ref.Counterparty.CustomerAdvancesGLAccount,
	|	CASE
	|		WHEN DocumentTable.Ref.Counterparty.CustomerAdvancesGLAccount.Currency
	|			THEN DocumentTable.Ref.Contract.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.Counterparty.CustomerAdvancesGLAccount.Currency
	|			THEN DocumentTable.AccountingAmount / DocumentTable.Ref.AccountingAmount * DocumentTable.Ref.SettlementsAmount
	|		ELSE 0
	|	END,
	|	DocumentTable.AccountingAmount,
	|	CASE
	|		WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.ArApAdjustments)
	|			THEN &ArApAdjustments
	|		ELSE &Novation
	|	END,
	|	FALSE
	|FROM
	|	Document.ArApAdjustments.Debitor AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|	AND DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.CustomerDebtAssignment)
	|	AND DocumentTable.AdvanceFlag
	|
	|UNION ALL
	|
	|SELECT
	|	9,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Ref.Date,
	|	&Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.Ref.CounterpartySource.GLAccountVendorSettlements,
	|	CASE
	|		WHEN DocumentTable.Ref.CounterpartySource.GLAccountVendorSettlements.Currency
	|			THEN DocumentTable.Contract.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.CounterpartySource.GLAccountVendorSettlements.Currency
	|			THEN DocumentTable.SettlementsAmount
	|		ELSE 0
	|	END,
	|	DocumentTable.Ref.Counterparty.GLAccountVendorSettlements,
	|	CASE
	|		WHEN DocumentTable.Ref.Counterparty.GLAccountVendorSettlements.Currency
	|			THEN DocumentTable.Ref.Contract.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.Counterparty.GLAccountVendorSettlements.Currency
	|			THEN DocumentTable.AccountingAmount / DocumentTable.Ref.AccountingAmount * DocumentTable.Ref.SettlementsAmount
	|		ELSE 0
	|	END,
	|	DocumentTable.AccountingAmount,
	|	CASE
	|		WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.ArApAdjustments)
	|			THEN &ArApAdjustments
	|		ELSE &Novation
	|	END,
	|	FALSE
	|FROM
	|	Document.ArApAdjustments.Creditor AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|	AND DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.DebtAssignmentToVendor)
	|	AND NOT DocumentTable.AdvanceFlag
	|
	|UNION ALL
	|
	|SELECT
	|	10,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Ref.Date,
	|	&Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.Ref.Counterparty.VendorAdvancesGLAccount,
	|	CASE
	|		WHEN DocumentTable.Ref.Counterparty.VendorAdvancesGLAccount.Currency
	|			THEN DocumentTable.Ref.Contract.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.Counterparty.VendorAdvancesGLAccount.Currency
	|			THEN DocumentTable.AccountingAmount / DocumentTable.Ref.AccountingAmount * DocumentTable.Ref.SettlementsAmount
	|		ELSE 0
	|	END,
	|	DocumentTable.Ref.CounterpartySource.VendorAdvancesGLAccount,
	|	CASE
	|		WHEN DocumentTable.Ref.CounterpartySource.VendorAdvancesGLAccount.Currency
	|			THEN DocumentTable.Contract.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.CounterpartySource.VendorAdvancesGLAccount.Currency
	|			THEN DocumentTable.SettlementsAmount
	|		ELSE 0
	|	END,
	|	DocumentTable.AccountingAmount,
	|	CASE
	|		WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.ArApAdjustments)
	|			THEN &ArApAdjustments
	|		ELSE &Novation
	|	END,
	|	FALSE
	|FROM
	|	Document.ArApAdjustments.Creditor AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|	AND DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.DebtAssignmentToVendor)
	|	AND DocumentTable.AdvanceFlag
	|
	|UNION ALL
	|
	|SELECT
	|	11,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN DocumentTable.GLAccount
	|		ELSE &ForeignCurrencyExchangeLoss
	|	END,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|				AND DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	0,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN &ForeignCurrencyExchangeGain
	|		ELSE DocumentTable.GLAccount
	|	END,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences < 0
	|				AND DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	0,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN DocumentTable.AmountOfExchangeDifferences
	|		ELSE -DocumentTable.AmountOfExchangeDifferences
	|	END,
	|	&ExchangeDifference,
	|	FALSE
	|FROM
	|	TemporaryTableExchangeRateDifferencesAccountsReceivable AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	12,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN &ForeignCurrencyExchangeLoss
	|		ELSE DocumentTable.GLAccount
	|	END,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences < 0
	|				AND DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	0,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN DocumentTable.GLAccount
	|		ELSE &ForeignCurrencyExchangeGain
	|	END,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|				AND DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	0,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN DocumentTable.AmountOfExchangeDifferences
	|		ELSE -DocumentTable.AmountOfExchangeDifferences
	|	END,
	|	&ExchangeDifference,
	|	FALSE
	|FROM
	|	TemporaryTableOfExchangeRateDifferencesAccountsPayable AS DocumentTable
	|
	|ORDER BY
	|	Ordering,
	|	LineNumber";

	Query.SetParameter("FundsTransfersBeingProcessed", Catalogs.DefaultGLAccounts.GetDefaultGLAccount("FundsTransfersBeingProcessed"));
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountingJournalEntries", QueryResult.Unload());
	
EndProcedure

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefArApAdjustments, StructureAdditionalProperties) Export
	
	Query = New Query;
	
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();

	Query.SetParameter("Ref",				DocumentRefArApAdjustments);
	Query.SetParameter("PointInTime",		New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ArApAdjustments",	NStr("en = 'Setoff'", MainLanguageCode));
	Query.SetParameter("Novation",			NStr("en = 'Debt assignment'", MainLanguageCode));
	Query.SetParameter("DebtAdjustment",	NStr("en = 'AR/AP Adjustments'", MainLanguageCode));
	
	Query.Text =
	"SELECT
	|	DocumentTable.AdvanceFlag AS AdvanceFlag,
	|	CASE
	|		WHEN DocumentTable.AdvanceFlag
	|			THEN VALUE(Enum.SettlementsTypes.Advance)
	|		ELSE VALUE(Enum.SettlementsTypes.Debt)
	|	END AS SettlementsType,
	|	CASE
	|		WHEN DocumentTable.AdvanceFlag
	|			THEN VALUE(AccumulationRecordType.Receipt)
	|		ELSE VALUE(AccumulationRecordType.Expense)
	|	END AS RecordType,
	|	MAX(DocumentTable.LineNumber) AS LineNumber,
	|	DocumentTable.Document AS Document,
	|	DocumentTable.Ref.OperationKind AS OperationKind,
	|	DocumentTable.Ref.CounterpartySource AS Counterparty,
	|	DocumentTable.Ref.CounterpartySource.DoOperationsByContracts AS DoOperationsByContracts,
	|	DocumentTable.Ref.CounterpartySource.DoOperationsByDocuments AS DoOperationsByDocuments,
	|	DocumentTable.Ref.CounterpartySource.DoOperationsByOrders AS DoOperationsByOrders,
	|	DocumentTable.Contract AS Contract,
	|	DocumentTable.Contract.SettlementsCurrency AS Currency,
	|	DocumentTable.Order AS Order,
	|	DocumentTable.Ref.Correspondence AS Correspondence,
	|	DocumentTable.Ref.Correspondence.TypeOfAccount AS CorrespondenceGLAccountType,
	|	CASE
	|		WHEN DocumentTable.AdvanceFlag
	|			THEN DocumentTable.Ref.CounterpartySource.CustomerAdvancesGLAccount
	|		ELSE DocumentTable.Ref.CounterpartySource.GLAccountCustomerSettlements
	|	END AS GLAccount,
	|	DocumentTable.Ref.Date AS Date,
	|	SUM(DocumentTable.SettlementsAmount) AS SettlementsAmount,
	|	SUM(DocumentTable.AccountingAmount) AS AccountingAmount,
	|	CASE
	|		WHEN DocumentTable.AdvanceFlag
	|			THEN SUM(DocumentTable.SettlementsAmount)
	|		ELSE -SUM(DocumentTable.SettlementsAmount)
	|	END AS SettlementsAmountBalance,
	|	CASE
	|		WHEN DocumentTable.AdvanceFlag
	|			THEN SUM(DocumentTable.AccountingAmount)
	|		ELSE -SUM(DocumentTable.AccountingAmount)
	|	END AS AccountingAmountBalance,
	|	CASE
	|		WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.ArApAdjustments)
	|			THEN &ArApAdjustments
	|		ELSE &Novation
	|	END AS ContentOfAccountingRecord
	|INTO TemporaryTableCustomers
	|FROM
	|	Document.ArApAdjustments.Debitor AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|	AND (DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.ArApAdjustments)
	|			OR DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.CustomerDebtAssignment))
	|
	|GROUP BY
	|	CASE
	|		WHEN DocumentTable.AdvanceFlag
	|			THEN VALUE(Enum.SettlementsTypes.Advance)
	|		ELSE VALUE(Enum.SettlementsTypes.Debt)
	|	END,
	|	DocumentTable.Document,
	|	DocumentTable.Ref,
	|	DocumentTable.Contract,
	|	DocumentTable.Order,
	|	DocumentTable.AdvanceFlag,
	|	DocumentTable.Ref.OperationKind,
	|	DocumentTable.Ref.CounterpartySource,
	|	DocumentTable.Contract.SettlementsCurrency,
	|	CASE
	|		WHEN DocumentTable.AdvanceFlag
	|			THEN DocumentTable.Ref.CounterpartySource.CustomerAdvancesGLAccount
	|		ELSE DocumentTable.Ref.CounterpartySource.GLAccountCustomerSettlements
	|	END,
	|	DocumentTable.Ref.Date,
	|	DocumentTable.Ref.Correspondence,
	|	DocumentTable.Ref.Correspondence.TypeOfAccount,
	|	DocumentTable.Ref.CounterpartySource.DoOperationsByContracts,
	|	DocumentTable.Ref.CounterpartySource.DoOperationsByDocuments,
	|	DocumentTable.Ref.CounterpartySource.DoOperationsByOrders
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentTable.AdvanceFlag,
	|	CASE
	|		WHEN DocumentTable.AdvanceFlag
	|			THEN VALUE(Enum.SettlementsTypes.Advance)
	|		ELSE VALUE(Enum.SettlementsTypes.Debt)
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherIncome)
	|			THEN VALUE(AccumulationRecordType.Receipt)
	|		ELSE VALUE(AccumulationRecordType.Expense)
	|	END,
	|	MAX(DocumentTable.LineNumber),
	|	CASE
	|		WHEN DocumentTable.Document = UNDEFINED
	|			THEN &Ref
	|		ELSE DocumentTable.Document
	|	END,
	|	DocumentTable.Ref.OperationKind,
	|	DocumentTable.Ref.CounterpartySource,
	|	DocumentTable.Ref.CounterpartySource.DoOperationsByContracts,
	|	DocumentTable.Ref.CounterpartySource.DoOperationsByDocuments,
	|	DocumentTable.Ref.CounterpartySource.DoOperationsByOrders,
	|	DocumentTable.Contract,
	|	DocumentTable.Contract.SettlementsCurrency,
	|	DocumentTable.Order,
	|	DocumentTable.Ref.Correspondence,
	|	DocumentTable.Ref.Correspondence.TypeOfAccount,
	|	CASE
	|		WHEN DocumentTable.AdvanceFlag
	|			THEN DocumentTable.Ref.CounterpartySource.CustomerAdvancesGLAccount
	|		ELSE DocumentTable.Ref.CounterpartySource.GLAccountCustomerSettlements
	|	END,
	|	DocumentTable.Ref.Date,
	|	SUM(DocumentTable.SettlementsAmount),
	|	SUM(DocumentTable.AccountingAmount),
	|	CASE
	|		WHEN DocumentTable.Ref.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherIncome)
	|			THEN SUM(DocumentTable.SettlementsAmount)
	|		ELSE -SUM(DocumentTable.SettlementsAmount)
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherIncome)
	|			THEN SUM(DocumentTable.AccountingAmount)
	|		ELSE -SUM(DocumentTable.AccountingAmount)
	|	END,
	|	&DebtAdjustment
	|FROM
	|	Document.ArApAdjustments.Debitor AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|	AND DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.CustomerDebtAdjustment)
	|
	|GROUP BY
	|	CASE
	|		WHEN DocumentTable.AdvanceFlag
	|			THEN VALUE(Enum.SettlementsTypes.Advance)
	|		ELSE VALUE(Enum.SettlementsTypes.Debt)
	|	END,
	|	DocumentTable.AdvanceFlag,
	|	DocumentTable.Document,
	|	DocumentTable.Ref,
	|	DocumentTable.Contract,
	|	DocumentTable.Order,
	|	DocumentTable.Ref.OperationKind,
	|	DocumentTable.Ref.CounterpartySource,
	|	DocumentTable.Contract.SettlementsCurrency,
	|	CASE
	|		WHEN DocumentTable.AdvanceFlag
	|			THEN DocumentTable.Ref.CounterpartySource.CustomerAdvancesGLAccount
	|		ELSE DocumentTable.Ref.CounterpartySource.GLAccountCustomerSettlements
	|	END,
	|	DocumentTable.Ref.Date,
	|	DocumentTable.Ref.Correspondence,
	|	DocumentTable.Ref.Correspondence.TypeOfAccount,
	|	DocumentTable.Ref.CounterpartySource.DoOperationsByContracts,
	|	DocumentTable.Ref.CounterpartySource.DoOperationsByDocuments,
	|	DocumentTable.Ref.CounterpartySource.DoOperationsByOrders
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentTable.AdvanceFlag,
	|	CASE
	|		WHEN DocumentTable.Ref.AccountsDocument = UNDEFINED
	|				AND DocumentTable.Ref.Counterparty.DoOperationsByDocuments
	|			THEN CASE
	|					WHEN DocumentTable.AdvanceFlag
	|						THEN VALUE(Enum.SettlementsTypes.Advance)
	|					ELSE VALUE(Enum.SettlementsTypes.Debt)
	|				END
	|		ELSE CASE
	|				WHEN DocumentTable.Ref.AdvanceFlag
	|					THEN VALUE(Enum.SettlementsTypes.Advance)
	|				ELSE VALUE(Enum.SettlementsTypes.Debt)
	|			END
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.AccountsDocument = UNDEFINED
	|			THEN CASE
	|					WHEN DocumentTable.AdvanceFlag
	|						THEN VALUE(AccumulationRecordType.Expense)
	|					ELSE VALUE(AccumulationRecordType.Receipt)
	|				END
	|		ELSE CASE
	|				WHEN DocumentTable.Ref.AdvanceFlag
	|					THEN VALUE(AccumulationRecordType.Expense)
	|				ELSE VALUE(AccumulationRecordType.Receipt)
	|			END
	|	END,
	|	MAX(DocumentTable.LineNumber),
	|	CASE
	|		WHEN DocumentTable.Ref.AccountsDocument = UNDEFINED
	|			THEN &Ref
	|		ELSE DocumentTable.Ref.AccountsDocument
	|	END,
	|	DocumentTable.Ref.OperationKind,
	|	DocumentTable.Ref.Counterparty,
	|	DocumentTable.Ref.Counterparty.DoOperationsByContracts,
	|	DocumentTable.Ref.Counterparty.DoOperationsByDocuments,
	|	DocumentTable.Ref.Counterparty.DoOperationsByOrders,
	|	DocumentTable.Ref.Contract,
	|	DocumentTable.Ref.Contract.SettlementsCurrency,
	|	DocumentTable.Ref.Order,
	|	DocumentTable.Ref.Correspondence,
	|	DocumentTable.Ref.Correspondence.TypeOfAccount,
	|	CASE
	|		WHEN DocumentTable.AdvanceFlag
	|			THEN DocumentTable.Ref.Counterparty.CustomerAdvancesGLAccount
	|		ELSE DocumentTable.Ref.Counterparty.GLAccountCustomerSettlements
	|	END,
	|	DocumentTable.Ref.Date,
	|	SUM(CASE
	|			WHEN DocumentTable.Ref.AccountingAmount = 0
	|				THEN 0
	|			ELSE DocumentTable.AccountingAmount / DocumentTable.Ref.AccountingAmount * DocumentTable.Ref.SettlementsAmount
	|		END),
	|	SUM(DocumentTable.AccountingAmount),
	|	CASE
	|		WHEN DocumentTable.Ref.AccountsDocument = UNDEFINED
	|			THEN CASE
	|					WHEN DocumentTable.AdvanceFlag
	|						THEN -1
	|					ELSE 1
	|				END
	|		ELSE CASE
	|				WHEN DocumentTable.Ref.AdvanceFlag
	|					THEN -1
	|				ELSE 1
	|			END
	|	END * SUM(CASE
	|			WHEN DocumentTable.Ref.AccountingAmount = 0
	|				THEN 0
	|			ELSE DocumentTable.AccountingAmount / DocumentTable.Ref.AccountingAmount * DocumentTable.Ref.SettlementsAmount
	|		END),
	|	CASE
	|		WHEN DocumentTable.Ref.AccountsDocument = UNDEFINED
	|			THEN CASE
	|					WHEN DocumentTable.AdvanceFlag
	|						THEN -SUM(DocumentTable.AccountingAmount)
	|					ELSE SUM(DocumentTable.AccountingAmount)
	|				END
	|		ELSE CASE
	|				WHEN DocumentTable.Ref.AdvanceFlag
	|					THEN -SUM(DocumentTable.AccountingAmount)
	|				ELSE SUM(DocumentTable.AccountingAmount)
	|			END
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.ArApAdjustments)
	|			THEN &ArApAdjustments
	|		ELSE &Novation
	|	END
	|FROM
	|	Document.ArApAdjustments.Debitor AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|	AND DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.CustomerDebtAssignment)
	|
	|GROUP BY
	|	DocumentTable.AdvanceFlag,
	|	CASE
	|		WHEN DocumentTable.Ref.AccountsDocument = UNDEFINED
	|				AND DocumentTable.Ref.Counterparty.DoOperationsByDocuments
	|			THEN CASE
	|					WHEN DocumentTable.AdvanceFlag
	|						THEN VALUE(Enum.SettlementsTypes.Advance)
	|					ELSE VALUE(Enum.SettlementsTypes.Debt)
	|				END
	|		ELSE CASE
	|				WHEN DocumentTable.Ref.AdvanceFlag
	|					THEN VALUE(Enum.SettlementsTypes.Advance)
	|				ELSE VALUE(Enum.SettlementsTypes.Debt)
	|			END
	|	END,
	|	DocumentTable.Document,
	|	DocumentTable.Ref,
	|	DocumentTable.Contract,
	|	DocumentTable.Order,
	|	DocumentTable.Ref.OperationKind,
	|	DocumentTable.Ref.Counterparty,
	|	CASE
	|		WHEN DocumentTable.AdvanceFlag
	|			THEN DocumentTable.Ref.Counterparty.CustomerAdvancesGLAccount
	|		ELSE DocumentTable.Ref.Counterparty.GLAccountCustomerSettlements
	|	END,
	|	DocumentTable.Ref.Date,
	|	DocumentTable.Ref.Contract,
	|	DocumentTable.Ref.Contract.SettlementsCurrency,
	|	DocumentTable.Ref.Correspondence,
	|	DocumentTable.Ref.Correspondence.TypeOfAccount,
	|	CASE
	|		WHEN DocumentTable.Ref.AccountsDocument = UNDEFINED
	|			THEN &Ref
	|		ELSE DocumentTable.Ref.AccountsDocument
	|	END,
	|	DocumentTable.Ref.Order,
	|	DocumentTable.Ref.Counterparty.DoOperationsByContracts,
	|	DocumentTable.Ref.Counterparty.DoOperationsByDocuments,
	|	DocumentTable.Ref.Counterparty.DoOperationsByOrders,
	|	CASE
	|		WHEN DocumentTable.Ref.AccountsDocument = UNDEFINED
	|			THEN CASE
	|					WHEN DocumentTable.AdvanceFlag
	|						THEN VALUE(AccumulationRecordType.Expense)
	|					ELSE VALUE(AccumulationRecordType.Receipt)
	|				END
	|		ELSE CASE
	|				WHEN DocumentTable.Ref.AdvanceFlag
	|					THEN VALUE(AccumulationRecordType.Expense)
	|				ELSE VALUE(AccumulationRecordType.Receipt)
	|			END
	|	END,
	|	DocumentTable.Ref.AdvanceFlag,
	|	DocumentTable.Ref.AccountsDocument
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DocumentTable.AdvanceFlag AS AdvanceFlag,
	|	CASE
	|		WHEN DocumentTable.AdvanceFlag
	|			THEN VALUE(Enum.SettlementsTypes.Advance)
	|		ELSE VALUE(Enum.SettlementsTypes.Debt)
	|	END AS SettlementsType,
	|	CASE
	|		WHEN DocumentTable.AdvanceFlag
	|			THEN VALUE(AccumulationRecordType.Receipt)
	|		ELSE VALUE(AccumulationRecordType.Expense)
	|	END AS RecordType,
	|	MAX(DocumentTable.LineNumber) AS LineNumber,
	|	DocumentTable.Document AS Document,
	|	DocumentTable.Ref.OperationKind AS OperationKind,
	|	CASE
	|		WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.ArApAdjustments)
	|			THEN DocumentTable.Ref.Counterparty
	|		ELSE DocumentTable.Ref.CounterpartySource
	|	END AS Counterparty,
	|	CASE
	|		WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.ArApAdjustments)
	|			THEN DocumentTable.Ref.Counterparty.DoOperationsByContracts
	|		ELSE DocumentTable.Ref.CounterpartySource.DoOperationsByContracts
	|	END AS DoOperationsByContracts,
	|	CASE
	|		WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.ArApAdjustments)
	|			THEN DocumentTable.Ref.Counterparty.DoOperationsByDocuments
	|		ELSE DocumentTable.Ref.CounterpartySource.DoOperationsByDocuments
	|	END AS DoOperationsByDocuments,
	|	CASE
	|		WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.ArApAdjustments)
	|			THEN DocumentTable.Ref.Counterparty.DoOperationsByOrders
	|		ELSE DocumentTable.Ref.CounterpartySource.DoOperationsByOrders
	|	END AS DoOperationsByOrders,
	|	DocumentTable.Contract AS Contract,
	|	DocumentTable.Contract.SettlementsCurrency AS Currency,
	|	DocumentTable.Order AS Order,
	|	DocumentTable.Ref.Correspondence AS Correspondence,
	|	DocumentTable.Ref.Correspondence.TypeOfAccount AS CorrespondenceGLAccountType,
	|	CASE
	|		WHEN DocumentTable.AdvanceFlag
	|			THEN CASE
	|					WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.ArApAdjustments)
	|						THEN DocumentTable.Ref.Counterparty.VendorAdvancesGLAccount
	|					ELSE DocumentTable.Ref.CounterpartySource.VendorAdvancesGLAccount
	|				END
	|		ELSE CASE
	|				WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.ArApAdjustments)
	|					THEN DocumentTable.Ref.Counterparty.GLAccountVendorSettlements
	|				ELSE DocumentTable.Ref.CounterpartySource.GLAccountVendorSettlements
	|			END
	|	END AS GLAccount,
	|	DocumentTable.Ref.Date AS Date,
	|	SUM(DocumentTable.SettlementsAmount) AS SettlementsAmount,
	|	SUM(DocumentTable.AccountingAmount) AS AccountingAmount,
	|	CASE
	|		WHEN DocumentTable.AdvanceFlag
	|			THEN SUM(DocumentTable.SettlementsAmount)
	|		ELSE -SUM(DocumentTable.SettlementsAmount)
	|	END AS SettlementsAmountBalance,
	|	CASE
	|		WHEN DocumentTable.AdvanceFlag
	|			THEN SUM(DocumentTable.AccountingAmount)
	|		ELSE -SUM(DocumentTable.AccountingAmount)
	|	END AS AccountingAmountBalance,
	|	CASE
	|		WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.ArApAdjustments)
	|			THEN &ArApAdjustments
	|		ELSE &Novation
	|	END AS ContentOfAccountingRecord
	|INTO TemporaryTableVendors
	|FROM
	|	Document.ArApAdjustments.Creditor AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|	AND (DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.ArApAdjustments)
	|			OR DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.DebtAssignmentToVendor))
	|
	|GROUP BY
	|	DocumentTable.AdvanceFlag,
	|	CASE
	|		WHEN DocumentTable.AdvanceFlag
	|			THEN VALUE(Enum.SettlementsTypes.Advance)
	|		ELSE VALUE(Enum.SettlementsTypes.Debt)
	|	END,
	|	DocumentTable.Document,
	|	DocumentTable.Ref,
	|	DocumentTable.Contract,
	|	DocumentTable.Order,
	|	DocumentTable.Ref.OperationKind,
	|	DocumentTable.Contract.SettlementsCurrency,
	|	CASE
	|		WHEN DocumentTable.AdvanceFlag
	|			THEN CASE
	|					WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.ArApAdjustments)
	|						THEN DocumentTable.Ref.Counterparty.VendorAdvancesGLAccount
	|					ELSE DocumentTable.Ref.CounterpartySource.VendorAdvancesGLAccount
	|				END
	|		ELSE CASE
	|				WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.ArApAdjustments)
	|					THEN DocumentTable.Ref.Counterparty.GLAccountVendorSettlements
	|				ELSE DocumentTable.Ref.CounterpartySource.GLAccountVendorSettlements
	|			END
	|	END,
	|	DocumentTable.Ref.Date,
	|	CASE
	|		WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.ArApAdjustments)
	|			THEN DocumentTable.Ref.Counterparty
	|		ELSE DocumentTable.Ref.CounterpartySource
	|	END,
	|	DocumentTable.Ref.Correspondence,
	|	DocumentTable.Ref.Correspondence.TypeOfAccount,
	|	CASE
	|		WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.ArApAdjustments)
	|			THEN DocumentTable.Ref.Counterparty.DoOperationsByContracts
	|		ELSE DocumentTable.Ref.CounterpartySource.DoOperationsByContracts
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.ArApAdjustments)
	|			THEN DocumentTable.Ref.Counterparty.DoOperationsByDocuments
	|		ELSE DocumentTable.Ref.CounterpartySource.DoOperationsByDocuments
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.ArApAdjustments)
	|			THEN DocumentTable.Ref.Counterparty.DoOperationsByOrders
	|		ELSE DocumentTable.Ref.CounterpartySource.DoOperationsByOrders
	|	END
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentTable.AdvanceFlag,
	|	CASE
	|		WHEN DocumentTable.AdvanceFlag
	|			THEN VALUE(Enum.SettlementsTypes.Advance)
	|		ELSE VALUE(Enum.SettlementsTypes.Debt)
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherIncome)
	|			THEN VALUE(AccumulationRecordType.Expense)
	|		ELSE VALUE(AccumulationRecordType.Receipt)
	|	END,
	|	MAX(DocumentTable.LineNumber),
	|	CASE
	|		WHEN DocumentTable.Document = UNDEFINED
	|			THEN &Ref
	|		ELSE DocumentTable.Document
	|	END,
	|	DocumentTable.Ref.OperationKind,
	|	DocumentTable.Ref.Counterparty,
	|	DocumentTable.Ref.Counterparty.DoOperationsByContracts,
	|	DocumentTable.Ref.Counterparty.DoOperationsByDocuments,
	|	DocumentTable.Ref.Counterparty.DoOperationsByOrders,
	|	DocumentTable.Contract,
	|	DocumentTable.Contract.SettlementsCurrency,
	|	DocumentTable.Order,
	|	DocumentTable.Ref.Correspondence,
	|	DocumentTable.Ref.Correspondence.TypeOfAccount,
	|	CASE
	|		WHEN DocumentTable.AdvanceFlag
	|			THEN DocumentTable.Ref.Counterparty.VendorAdvancesGLAccount
	|		ELSE DocumentTable.Ref.Counterparty.GLAccountVendorSettlements
	|	END,
	|	DocumentTable.Ref.Date,
	|	SUM(DocumentTable.SettlementsAmount),
	|	SUM(DocumentTable.AccountingAmount),
	|	CASE
	|		WHEN DocumentTable.Ref.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherIncome)
	|			THEN -SUM(DocumentTable.SettlementsAmount)
	|		ELSE SUM(DocumentTable.SettlementsAmount)
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherIncome)
	|			THEN -SUM(DocumentTable.AccountingAmount)
	|		ELSE SUM(DocumentTable.AccountingAmount)
	|	END,
	|	&DebtAdjustment
	|FROM
	|	Document.ArApAdjustments.Creditor AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|	AND DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.VendorDebtAdjustment)
	|	AND DocumentTable.SettlementsAmount <> 0
	|
	|GROUP BY
	|	DocumentTable.AdvanceFlag,
	|	CASE
	|		WHEN DocumentTable.AdvanceFlag
	|			THEN VALUE(Enum.SettlementsTypes.Advance)
	|		ELSE VALUE(Enum.SettlementsTypes.Debt)
	|	END,
	|	DocumentTable.Document,
	|	DocumentTable.Ref,
	|	DocumentTable.Contract,
	|	DocumentTable.Order,
	|	DocumentTable.Ref.OperationKind,
	|	DocumentTable.Contract.SettlementsCurrency,
	|	CASE
	|		WHEN DocumentTable.AdvanceFlag
	|			THEN DocumentTable.Ref.Counterparty.VendorAdvancesGLAccount
	|		ELSE DocumentTable.Ref.Counterparty.GLAccountVendorSettlements
	|	END,
	|	DocumentTable.Ref.Date,
	|	CASE
	|		WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.ArApAdjustments)
	|			THEN DocumentTable.Ref.Counterparty
	|		ELSE DocumentTable.Ref.CounterpartySource
	|	END,
	|	DocumentTable.Ref.Counterparty,
	|	DocumentTable.Ref.Correspondence,
	|	DocumentTable.Ref.Correspondence.TypeOfAccount,
	|	DocumentTable.Ref.Counterparty.DoOperationsByContracts,
	|	DocumentTable.Ref.Counterparty.DoOperationsByDocuments,
	|	DocumentTable.Ref.Counterparty.DoOperationsByOrders
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentTable.AdvanceFlag,
	|	CASE
	|		WHEN DocumentTable.Ref.AccountsDocument = UNDEFINED
	|				AND DocumentTable.Ref.Counterparty.DoOperationsByDocuments
	|			THEN CASE
	|					WHEN DocumentTable.AdvanceFlag
	|						THEN VALUE(Enum.SettlementsTypes.Advance)
	|					ELSE VALUE(Enum.SettlementsTypes.Debt)
	|				END
	|		ELSE CASE
	|				WHEN DocumentTable.Ref.AdvanceFlag
	|					THEN VALUE(Enum.SettlementsTypes.Advance)
	|				ELSE VALUE(Enum.SettlementsTypes.Debt)
	|			END
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.AccountsDocument = UNDEFINED
	|			THEN CASE
	|					WHEN DocumentTable.AdvanceFlag
	|						THEN VALUE(AccumulationRecordType.Expense)
	|					ELSE VALUE(AccumulationRecordType.Receipt)
	|				END
	|		ELSE CASE
	|				WHEN DocumentTable.Ref.AdvanceFlag
	|					THEN VALUE(AccumulationRecordType.Expense)
	|				ELSE VALUE(AccumulationRecordType.Receipt)
	|			END
	|	END,
	|	MAX(DocumentTable.LineNumber),
	|	CASE
	|		WHEN DocumentTable.Ref.AccountsDocument = UNDEFINED
	|			THEN &Ref
	|		ELSE DocumentTable.Ref.AccountsDocument
	|	END,
	|	DocumentTable.Ref.OperationKind,
	|	DocumentTable.Ref.Counterparty,
	|	DocumentTable.Ref.Counterparty.DoOperationsByContracts,
	|	DocumentTable.Ref.Counterparty.DoOperationsByDocuments,
	|	DocumentTable.Ref.Counterparty.DoOperationsByOrders,
	|	DocumentTable.Ref.Contract,
	|	DocumentTable.Ref.Contract.SettlementsCurrency,
	|	DocumentTable.Ref.Order,
	|	DocumentTable.Ref.Correspondence,
	|	DocumentTable.Ref.Correspondence.TypeOfAccount,
	|	CASE
	|		WHEN DocumentTable.AdvanceFlag
	|			THEN DocumentTable.Ref.Counterparty.VendorAdvancesGLAccount
	|		ELSE DocumentTable.Ref.Counterparty.GLAccountVendorSettlements
	|	END,
	|	DocumentTable.Ref.Date,
	|	SUM(CASE
	|			WHEN DocumentTable.Ref.AccountingAmount = 0
	|				THEN 0
	|			ELSE DocumentTable.AccountingAmount / DocumentTable.Ref.AccountingAmount * DocumentTable.Ref.SettlementsAmount
	|		END),
	|	SUM(DocumentTable.AccountingAmount),
	|	CASE
	|		WHEN DocumentTable.Ref.AccountsDocument = UNDEFINED
	|			THEN CASE
	|					WHEN DocumentTable.AdvanceFlag
	|						THEN -1
	|					ELSE 1
	|				END
	|		ELSE CASE
	|				WHEN DocumentTable.Ref.AdvanceFlag
	|					THEN -1
	|				ELSE 1
	|			END
	|	END * SUM(CASE
	|			WHEN DocumentTable.Ref.AccountingAmount = 0
	|				THEN 0
	|			ELSE DocumentTable.AccountingAmount / DocumentTable.Ref.AccountingAmount * DocumentTable.Ref.SettlementsAmount
	|		END),
	|	CASE
	|		WHEN DocumentTable.Ref.AccountsDocument = UNDEFINED
	|			THEN CASE
	|					WHEN DocumentTable.AdvanceFlag
	|						THEN -SUM(DocumentTable.AccountingAmount)
	|					ELSE SUM(DocumentTable.AccountingAmount)
	|				END
	|		ELSE CASE
	|				WHEN DocumentTable.Ref.AdvanceFlag
	|					THEN -SUM(DocumentTable.AccountingAmount)
	|				ELSE SUM(DocumentTable.AccountingAmount)
	|			END
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.ArApAdjustments)
	|			THEN &ArApAdjustments
	|		ELSE &Novation
	|	END
	|FROM
	|	Document.ArApAdjustments.Creditor AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|	AND DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesArApAdjustments.DebtAssignmentToVendor)
	|
	|GROUP BY
	|	DocumentTable.AdvanceFlag,
	|	DocumentTable.Ref.AccountingAmount,
	|	CASE
	|		WHEN DocumentTable.Ref.AccountsDocument = UNDEFINED
	|				AND DocumentTable.Ref.Counterparty.DoOperationsByDocuments
	|			THEN CASE
	|					WHEN DocumentTable.AdvanceFlag
	|						THEN VALUE(Enum.SettlementsTypes.Advance)
	|					ELSE VALUE(Enum.SettlementsTypes.Debt)
	|				END
	|		ELSE CASE
	|				WHEN DocumentTable.Ref.AdvanceFlag
	|					THEN VALUE(Enum.SettlementsTypes.Advance)
	|				ELSE VALUE(Enum.SettlementsTypes.Debt)
	|			END
	|	END,
	|	DocumentTable.Contract,
	|	DocumentTable.Ref.OperationKind,
	|	DocumentTable.Ref.Counterparty,
	|	CASE
	|		WHEN DocumentTable.AdvanceFlag
	|			THEN DocumentTable.Ref.Counterparty.VendorAdvancesGLAccount
	|		ELSE DocumentTable.Ref.Counterparty.GLAccountVendorSettlements
	|	END,
	|	DocumentTable.Ref.Date,
	|	DocumentTable.Ref.Contract,
	|	DocumentTable.Ref.Contract.SettlementsCurrency,
	|	DocumentTable.Ref.Correspondence,
	|	DocumentTable.Ref.Correspondence.TypeOfAccount,
	|	DocumentTable.Ref.Order,
	|	CASE
	|		WHEN DocumentTable.Ref.AccountsDocument = UNDEFINED
	|			THEN &Ref
	|		ELSE DocumentTable.Ref.AccountsDocument
	|	END,
	|	DocumentTable.Ref.Counterparty.DoOperationsByContracts,
	|	DocumentTable.Ref.Counterparty.DoOperationsByDocuments,
	|	DocumentTable.Ref.Counterparty.DoOperationsByOrders,
	|	DocumentTable.Ref.AdvanceFlag,
	|	DocumentTable.Ref.AccountsDocument";
	
	Query.ExecuteBatch();
	
	// Register record table creation by account sections.
	GenerateTableCustomerAccounts(DocumentRefArApAdjustments, StructureAdditionalProperties);
	GenerateTableAccountsPayable(DocumentRefArApAdjustments, StructureAdditionalProperties);
	GenerateTableInvoicesAndOrdersPayment(DocumentRefArApAdjustments, StructureAdditionalProperties);
	GenerateTableIncomeAndExpenses(DocumentRefArApAdjustments, StructureAdditionalProperties);
	GenerateTableIncomeAndExpensesRetained(DocumentRefArApAdjustments, StructureAdditionalProperties);
	GenerateTableUnallocatedExpenses(DocumentRefArApAdjustments, StructureAdditionalProperties);
	GenerateTableIncomeAndExpensesCashMethod(DocumentRefArApAdjustments, StructureAdditionalProperties);
	GenerateTableAccountingJournalEntries(DocumentRefArApAdjustments, StructureAdditionalProperties);
	
EndProcedure

// Controls the occurrence of negative balances.
//
Procedure RunControl(DocumentRefArApAdjustments, AdditionalProperties, Cancel, PostingDelete = False) Export
	
	If Not DriveServer.RunBalanceControl() Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// If temporary tables contain records, it is
	// necessary to execute negative balance control.
	If StructureTemporaryTables.RegisterRecordsAccountsReceivableChange
	 OR StructureTemporaryTables.RegisterRecordsSuppliersSettlementsChange Then
		
		Query = New Query(
		"SELECT
		|	RegisterRecordsAccountsReceivableChange.LineNumber AS LineNumber,
		|	REFPRESENTATION(RegisterRecordsAccountsReceivableChange.Company) AS CompanyPresentation,
		|	REFPRESENTATION(RegisterRecordsAccountsReceivableChange.Counterparty) AS CounterpartyPresentation,
		|	REFPRESENTATION(RegisterRecordsAccountsReceivableChange.Contract) AS ContractPresentation,
		|	REFPRESENTATION(RegisterRecordsAccountsReceivableChange.Contract.SettlementsCurrency) AS CurrencyPresentation,
		|	REFPRESENTATION(RegisterRecordsAccountsReceivableChange.Document) AS DocumentPresentation,
		|	REFPRESENTATION(RegisterRecordsAccountsReceivableChange.Order) AS OrderPresentation,
		|	REFPRESENTATION(RegisterRecordsAccountsReceivableChange.SettlementsType) AS CalculationsTypesPresentation,
		|	RegisterRecordsAccountsReceivableChange.SumBeforeWrite AS SumBeforeWrite,
		|	RegisterRecordsAccountsReceivableChange.AmountOnWrite AS AmountOnWrite,
		|	RegisterRecordsAccountsReceivableChange.AmountChange AS AmountChange,
		|	RegisterRecordsAccountsReceivableChange.AmountCurBeforeWrite AS AmountCurBeforeWrite,
		|	RegisterRecordsAccountsReceivableChange.SumCurOnWrite AS SumCurOnWrite,
		|	RegisterRecordsAccountsReceivableChange.SumCurChange AS SumCurChange,
		|	RegisterRecordsAccountsReceivableChange.SumCurChange + ISNULL(AccountsReceivableBalances.AmountCurBalance, 0) AS DebtBalanceAmount,
		|	-(RegisterRecordsAccountsReceivableChange.SumCurChange + ISNULL(AccountsReceivableBalances.AmountCurBalance, 0)) AS AmountOfOutstandingAdvances,
		|	ISNULL(AccountsReceivableBalances.AmountBalance, 0) AS AmountBalance,
		|	ISNULL(AccountsReceivableBalances.AmountCurBalance, 0) AS AmountCurBalance,
		|	RegisterRecordsAccountsReceivableChange.SettlementsType AS SettlementsType
		|FROM
		|	RegisterRecordsAccountsReceivableChange AS RegisterRecordsAccountsReceivableChange
		|		LEFT JOIN AccumulationRegister.AccountsReceivable.Balance(
		|				&ControlTime,
		|				(Company, Counterparty, Contract, Document, Order, SettlementsType) In
		|					(SELECT
		|						RegisterRecordsAccountsReceivableChange.Company AS Company,
		|						RegisterRecordsAccountsReceivableChange.Counterparty AS Counterparty,
		|						RegisterRecordsAccountsReceivableChange.Contract AS Contract,
		|						RegisterRecordsAccountsReceivableChange.Document AS Document,
		|						RegisterRecordsAccountsReceivableChange.Order AS Order,
		|						RegisterRecordsAccountsReceivableChange.SettlementsType AS SettlementsType
		|					FROM
		|						RegisterRecordsAccountsReceivableChange AS RegisterRecordsAccountsReceivableChange)) AS AccountsReceivableBalances
		|		ON RegisterRecordsAccountsReceivableChange.Company = AccountsReceivableBalances.Company
		|			AND RegisterRecordsAccountsReceivableChange.Counterparty = AccountsReceivableBalances.Counterparty
		|			AND RegisterRecordsAccountsReceivableChange.Contract = AccountsReceivableBalances.Contract
		|			AND RegisterRecordsAccountsReceivableChange.Document = AccountsReceivableBalances.Document
		|			AND RegisterRecordsAccountsReceivableChange.Order = AccountsReceivableBalances.Order
		|			AND RegisterRecordsAccountsReceivableChange.SettlementsType = AccountsReceivableBalances.SettlementsType
		|WHERE
		|	CASE
		|			WHEN RegisterRecordsAccountsReceivableChange.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)
		|				THEN ISNULL(AccountsReceivableBalances.AmountCurBalance, 0) > 0
		|			ELSE ISNULL(AccountsReceivableBalances.AmountCurBalance, 0) < 0
		|		END
		|
		|ORDER BY
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	RegisterRecordsSuppliersSettlementsChange.LineNumber AS LineNumber,
		|	REFPRESENTATION(RegisterRecordsSuppliersSettlementsChange.Company) AS CompanyPresentation,
		|	REFPRESENTATION(RegisterRecordsSuppliersSettlementsChange.Counterparty) AS CounterpartyPresentation,
		|	REFPRESENTATION(RegisterRecordsSuppliersSettlementsChange.Contract) AS ContractPresentation,
		|	REFPRESENTATION(RegisterRecordsSuppliersSettlementsChange.Contract.SettlementsCurrency) AS CurrencyPresentation,
		|	REFPRESENTATION(RegisterRecordsSuppliersSettlementsChange.Document) AS DocumentPresentation,
		|	REFPRESENTATION(RegisterRecordsSuppliersSettlementsChange.Order) AS OrderPresentation,
		|	REFPRESENTATION(RegisterRecordsSuppliersSettlementsChange.SettlementsType) AS CalculationsTypesPresentation,
		|	RegisterRecordsSuppliersSettlementsChange.SumBeforeWrite AS SumBeforeWrite,
		|	RegisterRecordsSuppliersSettlementsChange.AmountOnWrite AS AmountOnWrite,
		|	RegisterRecordsSuppliersSettlementsChange.AmountChange AS AmountChange,
		|	RegisterRecordsSuppliersSettlementsChange.AmountCurBeforeWrite AS AmountCurBeforeWrite,
		|	RegisterRecordsSuppliersSettlementsChange.SumCurOnWrite AS SumCurOnWrite,
		|	RegisterRecordsSuppliersSettlementsChange.SumCurChange AS SumCurChange,
		|	RegisterRecordsSuppliersSettlementsChange.SumCurChange + ISNULL(AccountsPayableBalances.AmountCurBalance, 0) AS DebtBalanceAmount,
		|	-(RegisterRecordsSuppliersSettlementsChange.SumCurChange + ISNULL(AccountsPayableBalances.AmountCurBalance, 0)) AS AmountOfOutstandingAdvances,
		|	ISNULL(AccountsPayableBalances.AmountBalance, 0) AS AmountBalance,
		|	ISNULL(AccountsPayableBalances.AmountCurBalance, 0) AS AmountCurBalance,
		|	RegisterRecordsSuppliersSettlementsChange.SettlementsType AS SettlementsType
		|FROM
		|	RegisterRecordsSuppliersSettlementsChange AS RegisterRecordsSuppliersSettlementsChange
		|		LEFT JOIN AccumulationRegister.AccountsPayable.Balance(
		|				&ControlTime,
		|				(Company, Counterparty, Contract, Document, Order, SettlementsType) In
		|					(SELECT
		|						RegisterRecordsSuppliersSettlementsChange.Company AS Company,
		|						RegisterRecordsSuppliersSettlementsChange.Counterparty AS Counterparty,
		|						RegisterRecordsSuppliersSettlementsChange.Contract AS Contract,
		|						RegisterRecordsSuppliersSettlementsChange.Document AS Document,
		|						RegisterRecordsSuppliersSettlementsChange.Order AS Order,
		|						RegisterRecordsSuppliersSettlementsChange.SettlementsType AS SettlementsType
		|					FROM
		|						RegisterRecordsSuppliersSettlementsChange AS RegisterRecordsSuppliersSettlementsChange)) AS AccountsPayableBalances
		|		ON RegisterRecordsSuppliersSettlementsChange.Company = AccountsPayableBalances.Company
		|			AND RegisterRecordsSuppliersSettlementsChange.Counterparty = AccountsPayableBalances.Counterparty
		|			AND RegisterRecordsSuppliersSettlementsChange.Contract = AccountsPayableBalances.Contract
		|			AND RegisterRecordsSuppliersSettlementsChange.Document = AccountsPayableBalances.Document
		|			AND RegisterRecordsSuppliersSettlementsChange.Order = AccountsPayableBalances.Order
		|			AND RegisterRecordsSuppliersSettlementsChange.SettlementsType = AccountsPayableBalances.SettlementsType
		|WHERE
		|	CASE
		|			WHEN RegisterRecordsSuppliersSettlementsChange.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)
		|				THEN ISNULL(AccountsPayableBalances.AmountCurBalance, 0) > 0
		|			ELSE ISNULL(AccountsPayableBalances.AmountCurBalance, 0) < 0
		|		END
		|
		|ORDER BY
		|	LineNumber");
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.SetParameter("ControlTime", AdditionalProperties.ForPosting.ControlTime);
		
		ResultsArray = Query.ExecuteBatch();
		
		If Not ResultsArray[0].IsEmpty()
			OR Not ResultsArray[1].IsEmpty() Then
			DocumentObjectArApAdjustments = DocumentRefArApAdjustments.GetObject()
		EndIf;
		
		// Negative balance on accounts receivable.
		If Not ResultsArray[0].IsEmpty() Then
			
			ErrorTitle = NStr("en = 'Error:'");
			MessageTitleText = ErrorTitle + Chars.LF + NStr("en = 'Cannot record accounts receivable'");
			DriveServer.ShowMessageAboutError(
				DocumentObjectArApAdjustments,
				MessageTitleText,
				Undefined,
				Undefined,
				"",
				Cancel
			);
			
			QueryResultSelection = ResultsArray[0].Select();
			While QueryResultSelection.Next() Do
				If QueryResultSelection.SettlementsType = Enums.SettlementsTypes.Debt Then
					MessageText = NStr("en = '%CounterpartyPresentation% - customer debt balance by billing document is less than written amount.
					                   |Written-off amount: %SumCurOnWrite% %CurrencyPresentation%.
					                   |Remaining customer debt: %RemainingDebtAmount% %CurrencyPresentation%.'"
					);
				EndIf;
				If QueryResultSelection.SettlementsType = Enums.SettlementsTypes.Advance Then
					If QueryResultSelection.AmountOfOutstandingAdvances = 0 Then
						MessageText = NStr("en = '%PresentationOfCounterparty% - perhaps the advances of the customer have not been received or they have been completely set off in the trade documents.'"
						);
					Else
						MessageText = NStr("en = '%CounterpartyPresentation% - advances received from customer are already partially set off in commercial documents.
						                   |Balance of non-offset advances: %UnpaidAdvancesAmount% %CurrencyPresentation%.'"
						);
						MessageText = StrReplace(MessageText, "%UnpaidAdvancesAmount%", String(QueryResultSelection.AmountOfOutstandingAdvances));
					EndIf;
				EndIf;
				MessageText = StrReplace(MessageText, "%CounterpartyPresentation%", DriveServer.CounterpartyPresentation(QueryResultSelection.CounterpartyPresentation, QueryResultSelection.ContractPresentation, QueryResultSelection.DocumentPresentation, QueryResultSelection.OrderPresentation, QueryResultSelection.CalculationsTypesPresentation));
				MessageText = StrReplace(MessageText, "%CurrencyPresentation%", QueryResultSelection.CurrencyPresentation);
				MessageText = StrReplace(MessageText, "%SumCurOnWrite%", String(QueryResultSelection.SumCurOnWrite));
				MessageText = StrReplace(MessageText, "%RemainingDebtAmount%", String(QueryResultSelection.DebtBalanceAmount));
				DriveServer.ShowMessageAboutError(
					DocumentObjectArApAdjustments,
					MessageText,
					Undefined,
					Undefined,
					"",
					Cancel
				);
			EndDo;
		EndIf;
		
		// Negative balance on accounts payable.
		If Not ResultsArray[1].IsEmpty() Then
			
			ErrorTitle = NStr("en = 'Error:'");
			MessageTitleText = ErrorTitle + Chars.LF + NStr("en = 'Cannot record accounts payable'");
			DriveServer.ShowMessageAboutError(
				DocumentObjectArApAdjustments,
				MessageTitleText,
				Undefined,
				Undefined,
				"",
				Cancel
			);
			
			QueryResultSelection = ResultsArray[1].Select();
			While QueryResultSelection.Next() Do
				If QueryResultSelection.SettlementsType = Enums.SettlementsTypes.Debt Then
					MessageText = NStr("en = '%CounterpartyPresentation% - debt to vendor balance by billing document is less than written amount.
					                   |Written-off amount: %SumCurOnWrite% %CurrencyPresentation%.
					                   |Debt before the balance provider:%RemainingDebtAmount% CurrencyPresentation%.'"
					);
				EndIf;
				If QueryResultSelection.SettlementsType = Enums.SettlementsTypes.Advance Then
					If QueryResultSelection.AmountOfOutstandingAdvances = 0 Then
						MessageText = NStr("en = '%CounterpartyPresentation% - perhaps the vendor didn''t get the advances or they have been completely set off in the trade documents .'"
						);
					Else
						MessageText = NStr("en = '%CounterpartyPresentation% - advances issued to vendors are already partially set off in commercial documents.
						                   |Balance of non-offset advances: %RemainingDebtAmount% %CurrencyPresentation%.'"
						);
						MessageText = StrReplace(MessageText, "%UnpaidAdvancesAmount%", String(QueryResultSelection.AmountOfOutstandingAdvances));
					EndIf;
				EndIf;
				MessageText = StrReplace(MessageText, "%CounterpartyPresentation%", DriveServer.CounterpartyPresentation(QueryResultSelection.CounterpartyPresentation, QueryResultSelection.ContractPresentation, QueryResultSelection.DocumentPresentation, QueryResultSelection.OrderPresentation, QueryResultSelection.CalculationsTypesPresentation));
				MessageText = StrReplace(MessageText, "%CurrencyPresentation%", QueryResultSelection.CurrencyPresentation);
				MessageText = StrReplace(MessageText, "%SumCurOnWrite%", String(QueryResultSelection.SumCurOnWrite));
				MessageText = StrReplace(MessageText, "%RemainingDebtAmount%", String(QueryResultSelection.DebtBalanceAmount));
				DriveServer.ShowMessageAboutError(
					DocumentObjectArApAdjustments,
					MessageText,
					Undefined,
					Undefined,
					"",
					Cancel
				);
			EndDo;
		EndIf;
		
	EndIf;
	
EndProcedure

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

// Replaces an empty sales order reference with an undefined
//
Procedure ChangeSalesOrderReference() Export
	
	Query = New Query;
	Query.Text = 
	"SELECT DISTINCT
	|	ArApAdjustmentsDebitor.Ref AS Ref
	|FROM
	|	Document.ArApAdjustments.Debitor AS ArApAdjustmentsDebitor
	|WHERE
	|	ArApAdjustmentsDebitor.Order = VALUE(Document.SalesOrder.EmptyRef)";
	
	QueryResult = Query.Execute();
	Selection	= QueryResult.Select();
	
	SalesOrderEmptyRef = Documents.SalesOrder.EmptyRef();
	
	While Selection.Next() Do
		
		Try
			
			ArApAdjustmentsObject = Selection.Ref.GetObject();
			
			For Each Row In ArApAdjustmentsObject.Debitor Do
				
				If Row.Order = SalesOrderEmptyRef Then
					Row.Order = Undefined;
				EndIf;
				
			EndDo;
			
			ArApAdjustmentsObject.Write();
			
		Except
			
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Error on write document %1: %2'"),
				Selection.Ref,
				BriefErrorDescription(ErrorInfo()));
				
			WriteLogEvent(
				NStr("en = 'InfobaseUpdate'", CommonUseClientServer.MainLanguageCode()),
				EventLogLevel.Error,
				Metadata.Documents.ArApAdjustments,
				,
				ErrorDescription);
				
		EndTry;
		
	EndDo;
	
EndProcedure

#EndRegion

#EndIf