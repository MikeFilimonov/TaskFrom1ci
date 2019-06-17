#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableCashAssets(DocumentRefCashReceipt, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();

	Query.SetParameter("Ref",						DocumentRefCashReceipt);
	Query.SetParameter("PointInTime",				New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod",				StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("Company",					StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("CashFundsReceipt",			NStr("en = 'Cash received'", MainLanguageCode));
	Query.SetParameter("RevenueInRetailReceipt",	NStr("en = 'Cash withdrawal from cash register'", MainLanguageCode));
	Query.SetParameter("ExchangeDifference",		NStr("en = 'Foreign currency exchange gains and losses'", MainLanguageCode));
	
	Query.Text =
	"SELECT
	|	1 AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	DocumentTable.Date AS Date,
	|	DocumentTable.Company AS Company,
	|	VALUE(Enum.CashAssetTypes.Cash) AS CashAssetsType,
	|	DocumentTable.Item AS Item,
	|	DocumentTable.PettyCash AS BankAccountPettyCash,
	|	DocumentTable.CashCurrency AS Currency,
	|	SUM(DocumentTable.Amount) AS Amount,
	|	SUM(DocumentTable.AmountCur) AS AmountCur,
	|	SUM(DocumentTable.Amount) AS AmountForBalance,
	|	SUM(DocumentTable.AmountCur) AS AmountCurForBalance,
	|	DocumentTable.PettyCashGLAccount AS GLAccount,
	|	CASE
	|		WHEN DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashReceipt.RetailIncome)
	|				OR DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashReceipt.RetailIncomeEarningAccounting)
	|			THEN &RevenueInRetailReceipt
	|		ELSE &CashFundsReceipt
	|	END AS ContentOfAccountingRecord
	|INTO TemporaryTableCashAssets
	|FROM
	|	TemporaryTableHeader AS DocumentTable
	|WHERE
	|	(DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashReceipt.FromAdvanceHolder)
	|			OR DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashReceipt.Other)
	|			OR DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashReceipt.OtherSettlements)
	|			OR DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashReceipt.LoanSettlements)
	|			OR DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashReceipt.LoanRepaymentByEmployee)
	|			OR DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashReceipt.CurrencyPurchase)
	|			OR DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashReceipt.RetailIncome)
	|			OR DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashReceipt.RetailIncomeEarningAccounting))
	|
	|GROUP BY
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	DocumentTable.Item,
	|	DocumentTable.PettyCash,
	|	DocumentTable.CashCurrency,
	|	DocumentTable.PettyCashGLAccount,
	|	CASE
	|		WHEN DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashReceipt.RetailIncome)
	|				OR DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashReceipt.RetailIncomeEarningAccounting)
	|			THEN &RevenueInRetailReceipt
	|		ELSE &CashFundsReceipt
	|	END
	|
	|UNION ALL
	|
	|SELECT
	|	TemporaryTablePaymentDetails.LineNumber,
	|	VALUE(AccumulationRecordType.Receipt),
	|	TemporaryTablePaymentDetails.Date,
	|	&Company,
	|	VALUE(Enum.CashAssetTypes.Cash),
	|	TemporaryTablePaymentDetails.Item,
	|	TemporaryTablePaymentDetails.PettyCash,
	|	TemporaryTablePaymentDetails.CashCurrency,
	|	SUM(TemporaryTablePaymentDetails.AccountingAmount),
	|	SUM(TemporaryTablePaymentDetails.PaymentAmount),
	|	SUM(TemporaryTablePaymentDetails.AccountingAmount),
	|	SUM(TemporaryTablePaymentDetails.PaymentAmount),
	|	TemporaryTablePaymentDetails.BankAccountCashGLAccount,
	|	&CashFundsReceipt
	|FROM
	|	TemporaryTablePaymentDetails AS TemporaryTablePaymentDetails
	|WHERE
	|	(TemporaryTablePaymentDetails.OperationKind = VALUE(Enum.OperationTypesCashReceipt.FromCustomer)
	|			OR TemporaryTablePaymentDetails.OperationKind = VALUE(Enum.OperationTypesCashReceipt.FromVendor))
	|
	|GROUP BY
	|	TemporaryTablePaymentDetails.LineNumber,
	|	TemporaryTablePaymentDetails.Date,
	|	TemporaryTablePaymentDetails.Item,
	|	TemporaryTablePaymentDetails.PettyCash,
	|	TemporaryTablePaymentDetails.CashCurrency,
	|	TemporaryTablePaymentDetails.BankAccountCashGLAccount
	|
	|INDEX BY
	|	Company,
	|	CashAssetsType,
	|	BankAccountPettyCash,
	|	Currency,
	|	GLAccount";
	
	Query.Execute();
	
	// Setting of the exclusive lock of the cash funds controlled balances.
	Query.Text =
	"SELECT
	|	TemporaryTableCashAssets.Company AS Company,
	|	TemporaryTableCashAssets.CashAssetsType AS CashAssetsType,
	|	TemporaryTableCashAssets.BankAccountPettyCash AS BankAccountPettyCash,
	|	TemporaryTableCashAssets.Currency AS Currency
	|FROM
	|	TemporaryTableCashAssets";
	
	QueryResult = Query.Execute();
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.CashAssets");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;
	
	For Each ColumnQueryResult In QueryResult.Columns Do
		LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
	EndDo;
	Block.Lock();
	
	QueryNumber = 0;
	Query.Text = DriveServer.GetQueryTextExchangeRateDifferencesCashAssets(Query.TempTablesManager, QueryNumber);
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableCashAssets", ResultsArray[QueryNumber].Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableCashAssetsInCashRegisters(DocumentRefCashReceipt, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	
	"SELECT
	|	1 AS LineNumber,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	DocumentTable.Date AS Date,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.CashCR AS CashCR,
	|	DocumentTable.CashCurrency AS Currency,
	|	SUM(DocumentTable.Amount) AS Amount,
	|	SUM(DocumentTable.AmountCur) AS AmountCur,
	|	SUM(DocumentTable.Amount) AS AmountForBalance,
	|	SUM(DocumentTable.AmountCur) AS AmountCurForBalance,
	|	DocumentTable.CashCRGLAccount AS GLAccount,
	|	&CashExpense AS ContentOfAccountingRecord
	|INTO TemporaryTableCashAssetsInRetailCashes
	|FROM
	|	TemporaryTableHeader AS DocumentTable
	|WHERE
	|	DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashReceipt.RetailIncome)
	|
	|GROUP BY
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	DocumentTable.CashCR,
	|	DocumentTable.CashCurrency,
	|	DocumentTable.CashCRGLAccount
	|
	|INDEX BY
	|	Company,
	|	CashCR,
	|	Currency,
	|	GLAccount";
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();

	Query.SetParameter("Company",				StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("Ref",					DocumentRefCashReceipt);
	Query.SetParameter("PointInTime",			New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod",			StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("CashExpense",			NStr("en = 'Cash withdrawal fron cash register'", MainLanguageCode));
	Query.SetParameter("ExchangeDifference",	NStr("en = 'Foreign currency exchange gains and losses'", MainLanguageCode));
	
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
Procedure GenerateAdvanceHoldersTable(DocumentRefCashReceipt, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();

	Query.SetParameter("Ref",							DocumentRefCashReceipt);
	Query.SetParameter("PointInTime",					New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod",					StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("Company",						StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("RepaymentOfAdvanceHolderDebt",	NStr("en = 'Refund from advance holder'", MainLanguageCode));
	Query.SetParameter("ExchangeDifference",			NStr("en = 'Foreign currency exchange gains and losses'", MainLanguageCode));
	
	Query.Text =
	"SELECT
	|	1 AS LineNumber,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	DocumentTable.PettyCash AS PettyCash,
	|	DocumentTable.Document AS Document,
	|	DocumentTable.AdvanceHolder AS Employee,
	|	DocumentTable.Date AS Date,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.CashCurrency AS Currency,
	|	SUM(DocumentTable.Amount) AS Amount,
	|	SUM(DocumentTable.AmountCur) AS AmountCur,
	|	-SUM(DocumentTable.Amount) AS AmountForBalance,
	|	-SUM(DocumentTable.AmountCur) AS AmountCurForBalance,
	|	DocumentTable.AdvanceHolderAdvanceHoldersGLAccount AS GLAccount,
	|	&RepaymentOfAdvanceHolderDebt AS ContentOfAccountingRecord
	|INTO TemporaryTableAdvanceHolders
	|FROM
	|	TemporaryTableHeader AS DocumentTable
	|WHERE
	|	DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashReceipt.FromAdvanceHolder)
	|
	|GROUP BY
	|	DocumentTable.PettyCash,
	|	DocumentTable.Document,
	|	DocumentTable.AdvanceHolder,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	DocumentTable.CashCurrency,
	|	DocumentTable.AdvanceHolderAdvanceHoldersGLAccount
	|
	|INDEX BY
	|	Company,
	|	Employee,
	|	Currency,
	|	Document,
	|	GLAccount";
	
	Query.Execute();
	
	// Setting the exclusive lock of controlled balances of payments to accountable persons.
	Query.Text =
	"SELECT
	|	TemporaryTableAdvanceHolders.Company AS Company,
	|	TemporaryTableAdvanceHolders.Employee AS Employee,
	|	TemporaryTableAdvanceHolders.Currency AS Currency,
	|	TemporaryTableAdvanceHolders.Document AS Document
	|FROM
	|	TemporaryTableAdvanceHolders";
	
	QueryResult = Query.Execute();
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.AdvanceHolders");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;
	
	For Each ColumnQueryResult In QueryResult.Columns Do
		LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
	EndDo;
	Block.Lock();
	
	QueryNumber = 0;
	Query.Text = DriveServer.GetQueryTextCurrencyExchangeRateAdvanceHolders(Query.TempTablesManager, QueryNumber);
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSettlementsWithAdvanceHolders", ResultsArray[QueryNumber].Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableCustomerAccounts(DocumentRefCashReceipt, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();

	Query.SetParameter("Ref",							DocumentRefCashReceipt);
	Query.SetParameter("PointInTime",					New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod",					StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("Company",						StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("AppearenceOfCustomerAdvance",	NStr("en = 'Advance payment from customer'", MainLanguageCode));
	Query.SetParameter("CustomerObligationsRepayment",	NStr("en = 'Payment from customer'", MainLanguageCode));
	Query.SetParameter("EarlyPaymentDiscount",			NStr("en = 'Early payment discount'", MainLanguageCode));
	Query.SetParameter("ExchangeDifference",			NStr("en = 'Foreign currency exchange gains and losses'", MainLanguageCode));
	
	Query.Text =
	"SELECT
	|	FALSE AS IsEPD,
	|	TemporaryTablePaymentDetails.LineNumber AS LineNumber,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.DoOperationsByDocuments
	|			THEN CASE
	|					WHEN TemporaryTablePaymentDetails.AdvanceFlag
	|						THEN &Ref
	|					ELSE TemporaryTablePaymentDetails.Document
	|				END
	|		ELSE UNDEFINED
	|	END AS Document,
	|	&Company AS Company,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TemporaryTablePaymentDetails.PettyCash AS PettyCash,
	|	TemporaryTablePaymentDetails.Counterparty AS Counterparty,
	|	TemporaryTablePaymentDetails.Contract AS Contract,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.DoOperationsByOrders
	|			THEN TemporaryTablePaymentDetails.Order
	|		ELSE UNDEFINED
	|	END AS Order,
	|	TemporaryTablePaymentDetails.Date AS Date,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.AdvanceFlag
	|			THEN VALUE(Enum.SettlementsTypes.Advance)
	|		ELSE VALUE(Enum.SettlementsTypes.Debt)
	|	END AS SettlementsType,
	|	SUM(TemporaryTablePaymentDetails.PaymentAmount) AS PaymentAmount,
	|	SUM(TemporaryTablePaymentDetails.AccountingAmount) AS Amount,
	|	SUM(TemporaryTablePaymentDetails.SettlementsAmount) AS AmountCur,
	|	-SUM(TemporaryTablePaymentDetails.AccountingAmount) AS AmountForBalance,
	|	-SUM(TemporaryTablePaymentDetails.SettlementsAmount) AS AmountCurForBalance,
	|	SUM(TemporaryTablePaymentDetails.AccountingAmount) AS AmountForPayment,
	|	SUM(TemporaryTablePaymentDetails.SettlementsAmount) AS AmountForPaymentCur,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.AdvanceFlag
	|			THEN TemporaryTablePaymentDetails.CustomerAdvancesGLAccount
	|		ELSE TemporaryTablePaymentDetails.GLAccountCustomerSettlements
	|	END AS GLAccount,
	|	TemporaryTablePaymentDetails.SettlementsCurrency AS Currency,
	|	TemporaryTablePaymentDetails.CashCurrency AS CashCurrency,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.AdvanceFlag
	|			THEN &AppearenceOfCustomerAdvance
	|		ELSE &CustomerObligationsRepayment
	|	END AS ContentOfAccountingRecord
	|INTO TemporaryTableAccountsReceivable
	|FROM
	|	TemporaryTablePaymentDetails AS TemporaryTablePaymentDetails
	|WHERE
	|	TemporaryTablePaymentDetails.OperationKind = VALUE(Enum.OperationTypesCashReceipt.FromCustomer)
	|
	|GROUP BY
	|	TemporaryTablePaymentDetails.LineNumber,
	|	TemporaryTablePaymentDetails.PettyCash,
	|	TemporaryTablePaymentDetails.Counterparty,
	|	TemporaryTablePaymentDetails.Contract,
	|	TemporaryTablePaymentDetails.Date,
	|	TemporaryTablePaymentDetails.SettlementsCurrency,
	|	TemporaryTablePaymentDetails.CashCurrency,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.DoOperationsByDocuments
	|			THEN CASE
	|					WHEN TemporaryTablePaymentDetails.AdvanceFlag
	|						THEN &Ref
	|					ELSE TemporaryTablePaymentDetails.Document
	|				END
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.AdvanceFlag
	|			THEN VALUE(Enum.SettlementsTypes.Advance)
	|		ELSE VALUE(Enum.SettlementsTypes.Debt)
	|	END,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.AdvanceFlag
	|			THEN TemporaryTablePaymentDetails.CustomerAdvancesGLAccount
	|		ELSE TemporaryTablePaymentDetails.GLAccountCustomerSettlements
	|	END,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.AdvanceFlag
	|			THEN &AppearenceOfCustomerAdvance
	|		ELSE &CustomerObligationsRepayment
	|	END,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.DoOperationsByOrders
	|			THEN TemporaryTablePaymentDetails.Order
	|		ELSE UNDEFINED
	|	END
	|
	|UNION ALL
	|
	|SELECT
	|	TRUE,
	|	TemporaryTablePaymentDetails.LineNumber,
	|	TemporaryTablePaymentDetails.Document,
	|	&Company,
	|	VALUE(AccumulationRecordType.Receipt),
	|	TemporaryTablePaymentDetails.PettyCash,
	|	TemporaryTablePaymentDetails.Counterparty,
	|	TemporaryTablePaymentDetails.Contract,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.DoOperationsByOrders
	|			THEN TemporaryTablePaymentDetails.Order
	|		ELSE UNDEFINED
	|	END,
	|	TemporaryTablePaymentDetails.Date,
	|	VALUE(Enum.SettlementsTypes.Debt),
	|	-SUM(TemporaryTablePaymentDetails.EPDAmount),
	|	-SUM(TemporaryTablePaymentDetails.AccountingEPDAmount),
	|	-SUM(TemporaryTablePaymentDetails.SettlementsEPDAmount),
	|	SUM(TemporaryTablePaymentDetails.AccountingEPDAmount),
	|	SUM(TemporaryTablePaymentDetails.SettlementsEPDAmount),
	|	-SUM(TemporaryTablePaymentDetails.AccountingEPDAmount),
	|	-SUM(TemporaryTablePaymentDetails.SettlementsEPDAmount),
	|	TemporaryTablePaymentDetails.GLAccountCustomerSettlements,
	|	TemporaryTablePaymentDetails.SettlementsCurrency,
	|	TemporaryTablePaymentDetails.CashCurrency,
	|	&EarlyPaymentDiscount
	|FROM
	|	TemporaryTablePaymentDetails AS TemporaryTablePaymentDetails
	|		INNER JOIN Document.SalesInvoice AS SalesInvoice
	|		ON TemporaryTablePaymentDetails.Document = SalesInvoice.Ref
	|WHERE
	|	TemporaryTablePaymentDetails.OperationKind = VALUE(Enum.OperationTypesCashReceipt.FromCustomer)
	|	AND TemporaryTablePaymentDetails.DoOperationsByDocuments
	|	AND NOT TemporaryTablePaymentDetails.AdvanceFlag
	|	AND TemporaryTablePaymentDetails.EPDAmount > 0
	|	AND (SalesInvoice.ProvideEPD = VALUE(Enum.VariantsOfProvidingEPD.PaymentDocument)
	|			OR SalesInvoice.ProvideEPD = VALUE(Enum.VariantsOfProvidingEPD.PaymentDocumentWithVATAdjustment))
	|
	|GROUP BY
	|	TemporaryTablePaymentDetails.LineNumber,
	|	TemporaryTablePaymentDetails.PettyCash,
	|	TemporaryTablePaymentDetails.Counterparty,
	|	TemporaryTablePaymentDetails.Contract,
	|	TemporaryTablePaymentDetails.SettlementsCurrency,
	|	TemporaryTablePaymentDetails.CashCurrency,
	|	TemporaryTablePaymentDetails.Date,
	|	TemporaryTablePaymentDetails.Document,
	|	TemporaryTablePaymentDetails.GLAccountCustomerSettlements,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.DoOperationsByOrders
	|			THEN TemporaryTablePaymentDetails.Order
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
	
	// Setting the exclusive lock for the controlled balances of accounts receivable.
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
Procedure GenerateTableAccountsPayable(DocumentRefCashReceipt, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();

	Query.SetParameter("Ref",							DocumentRefCashReceipt);
	Query.SetParameter("PointInTime",					New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod",					StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("Company",						StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("VendorAdvanceRepayment",		NStr("en = 'Advance payment refund from supplier'", MainLanguageCode));
	Query.SetParameter("AppearenceOfLiabilityToVendor",	NStr("en = 'Payment from supplier'", MainLanguageCode));
	Query.SetParameter("ExchangeDifference",			NStr("en = 'Foreign currency exchange gains and losses'", MainLanguageCode));
	
	Query.Text =
	"SELECT
	|	TemporaryTablePaymentDetails.LineNumber AS LineNumber,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.DoOperationsByDocuments
	|			THEN TemporaryTablePaymentDetails.Document
	|		ELSE UNDEFINED
	|	END AS Document,
	|	&Company AS Company,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TemporaryTablePaymentDetails.PettyCash AS PettyCash,
	|	TemporaryTablePaymentDetails.Counterparty AS Counterparty,
	|	TemporaryTablePaymentDetails.Contract AS Contract,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.DoOperationsByOrders
	|			THEN TemporaryTablePaymentDetails.Order
	|		ELSE VALUE(Document.PurchaseOrder.EmptyRef)
	|	END AS Order,
	|	TemporaryTablePaymentDetails.Date AS Date,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.AdvanceFlag
	|			THEN VALUE(Enum.SettlementsTypes.Advance)
	|		ELSE VALUE(Enum.SettlementsTypes.Debt)
	|	END AS SettlementsType,
	|	SUM(TemporaryTablePaymentDetails.PaymentAmount) AS PaymentAmount,
	|	SUM(TemporaryTablePaymentDetails.AccountingAmount) AS Amount,
	|	SUM(TemporaryTablePaymentDetails.SettlementsAmount) AS AmountCur,
	|	SUM(TemporaryTablePaymentDetails.AccountingAmount) AS AmountForBalance,
	|	SUM(TemporaryTablePaymentDetails.SettlementsAmount) AS AmountCurForBalance,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.AdvanceFlag
	|			THEN TemporaryTablePaymentDetails.VendorAdvancesGLAccount
	|		ELSE TemporaryTablePaymentDetails.GLAccountVendorSettlements
	|	END AS GLAccount,
	|	TemporaryTablePaymentDetails.SettlementsCurrency AS Currency,
	|	TemporaryTablePaymentDetails.CashCurrency AS CashCurrency,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.AdvanceFlag
	|			THEN &VendorAdvanceRepayment
	|		ELSE &AppearenceOfLiabilityToVendor
	|	END AS ContentOfAccountingRecord,
	|	SUM(TemporaryTablePaymentDetails.AccountingAmount) AS AmountForPayment,
	|	SUM(TemporaryTablePaymentDetails.SettlementsAmount) AS AmountForPaymentCur
	|INTO TemporaryTableAccountsPayable
	|FROM
	|	TemporaryTablePaymentDetails AS TemporaryTablePaymentDetails
	|WHERE
	|	TemporaryTablePaymentDetails.OperationKind = VALUE(Enum.OperationTypesCashReceipt.FromVendor)
	|
	|GROUP BY
	|	TemporaryTablePaymentDetails.LineNumber,
	|	TemporaryTablePaymentDetails.PettyCash,
	|	TemporaryTablePaymentDetails.Counterparty,
	|	TemporaryTablePaymentDetails.Contract,
	|	TemporaryTablePaymentDetails.Date,
	|	TemporaryTablePaymentDetails.SettlementsCurrency,
	|	TemporaryTablePaymentDetails.CashCurrency,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.DoOperationsByDocuments
	|			THEN TemporaryTablePaymentDetails.Document
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.DoOperationsByOrders
	|			THEN TemporaryTablePaymentDetails.Order
	|		ELSE VALUE(Document.PurchaseOrder.EmptyRef)
	|	END,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.AdvanceFlag
	|			THEN VALUE(Enum.SettlementsTypes.Advance)
	|		ELSE VALUE(Enum.SettlementsTypes.Debt)
	|	END,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.AdvanceFlag
	|			THEN TemporaryTablePaymentDetails.VendorAdvancesGLAccount
	|		ELSE TemporaryTablePaymentDetails.GLAccountVendorSettlements
	|	END,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.AdvanceFlag
	|			THEN &VendorAdvanceRepayment
	|		ELSE &AppearenceOfLiabilityToVendor
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
Procedure GenerateTableIncomeAndExpenses(DocumentRefCashReceipt, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();

	Query.SetParameter("Ref",							DocumentRefCashReceipt);
	Query.SetParameter("Company",						StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PointInTime",					New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("IncomeReflection",				NStr("en = 'Other income'", MainLanguageCode));
	Query.SetParameter("CostsReflection",				NStr("en = 'Expenses incurred'", MainLanguageCode));
	Query.SetParameter("ExchangeDifference",			NStr("en = 'Foreign currency exchange gains and losses'", MainLanguageCode));
	Query.SetParameter("EarlyPaymentDiscount",			NStr("en = 'Early payment discount'", MainLanguageCode));
	Query.SetParameter("ForeignCurrencyExchangeGain",	Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeGain")); 
	Query.SetParameter("ForeignCurrencyExchangeLoss",	Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeLoss"));
	
	Query.Text =
	"SELECT
	|	1 AS Ordering,
	|	1 AS LineNumber,
	|	DocumentTable.Date AS Period,
	|	DocumentTable.Company AS Company,
	|	UNDEFINED AS StructuralUnit,
	|	UNDEFINED AS SalesOrder,
	|	VALUE(Catalog.LinesOfBusiness.Other) AS BusinessLine,
	|	DocumentTable.Correspondence AS GLAccount,
	|	&IncomeReflection AS ContentOfAccountingRecord,
	|	DocumentTable.Amount AS AmountIncome,
	|	0 AS AmountExpense,
	|	FALSE AS OfflineRecord
	|FROM
	|	TemporaryTableHeader AS DocumentTable
	|WHERE
	|	(DocumentTable.CorrespondenceGLAccountType = VALUE(Enum.GLAccountsTypes.Revenue)
	|			OR DocumentTable.CorrespondenceGLAccountType = VALUE(Enum.GLAccountsTypes.OtherIncome))
	|	AND (DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashReceipt.Other)
	|			OR DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashReceipt.OtherSettlements)
	|			OR DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashReceipt.CurrencyPurchase))
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	1,
	|	DocumentTable.Date,
	|	&Company,
	|	DocumentTable.Department,
	|	UNDEFINED,
	|	DocumentTable.BusinessLine,
	|	DocumentTable.BusinessLineGLAccountOfRevenueFromSales,
	|	&IncomeReflection,
	|	DocumentTable.Amount,
	|	0,
	|	FALSE
	|FROM
	|	TemporaryTableHeader AS DocumentTable
	|WHERE
	|	DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashReceipt.RetailIncomeEarningAccounting)
	|
	|UNION ALL
	|
	|SELECT
	|	3,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	UNDEFINED,
	|	UNDEFINED,
	|	VALUE(Catalog.LinesOfBusiness.Other),
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN &ForeignCurrencyExchangeGain
	|		ELSE &ForeignCurrencyExchangeLoss
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
	|	TemporaryTableExchangeRateLossesBanking AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	4,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	UNDEFINED,
	|	UNDEFINED,
	|	VALUE(Catalog.LinesOfBusiness.Other),
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN &ForeignCurrencyExchangeGain
	|		ELSE &ForeignCurrencyExchangeLoss
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
	|	TemporaryTableExchangeDifferencesCalculationWithAdvanceHolder AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	5,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	UNDEFINED,
	|	UNDEFINED,
	|	VALUE(Catalog.LinesOfBusiness.Other),
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN &ForeignCurrencyExchangeGain
	|		ELSE &ForeignCurrencyExchangeLoss
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
	|	6,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	UNDEFINED,
	|	UNDEFINED,
	|	VALUE(Catalog.LinesOfBusiness.Other),
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN &ForeignCurrencyExchangeLoss
	|		ELSE &ForeignCurrencyExchangeGain
	|	END,
	|	&ExchangeDifference,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN 0
	|		ELSE -DocumentTable.AmountOfExchangeDifferences
	|	END,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN DocumentTable.AmountOfExchangeDifferences
	|		ELSE 0
	|	END,
	|	FALSE
	|FROM
	|	TemporaryTableOfExchangeRateDifferencesAccountsPayable AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	7,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	UNDEFINED,
	|	UNDEFINED,
	|	VALUE(Catalog.LinesOfBusiness.Other),
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN &ForeignCurrencyExchangeGain
	|		ELSE &ForeignCurrencyExchangeLoss
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
	|
	|UNION ALL
	|
	|SELECT
	|	8,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	UNDEFINED,
	|	UNDEFINED,
	|	VALUE(Catalog.LinesOfBusiness.Other),
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN &ForeignCurrencyExchangeGain
	|		ELSE &ForeignCurrencyExchangeLoss
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
	|	TemporaryTableCurrencyExchangeRateDifferencesPOSSummary AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	9,
	|	1,
	|	DocumentTable.Date,
	|	&Company,
	|	DocumentTable.Department,
	|	UNDEFINED,
	|	DocumentTable.BusinessLine,
	|	DocumentTable.BusinessLineGLAccountOfSalesCost,
	|	&CostsReflection,
	|	0,
	|	DocumentTable.Cost,
	|	FALSE
	|FROM
	|	TemporaryTableCost AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	10,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	UNDEFINED,
	|	UNDEFINED,
	|	VALUE(Catalog.LinesOfBusiness.Other),
	|	CASE
	|		WHEN DocumentTable.ExchangeRateDifferenceAmount > 0
	|			THEN &ForeignCurrencyExchangeGain
	|		ELSE &ForeignCurrencyExchangeLoss
	|	END,
	|	&ExchangeDifference,
	|	CASE
	|		WHEN DocumentTable.ExchangeRateDifferenceAmount > 0
	|			THEN DocumentTable.ExchangeRateDifferenceAmount
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.ExchangeRateDifferenceAmount > 0
	|			THEN 0
	|		ELSE -DocumentTable.ExchangeRateDifferenceAmount
	|	END,
	|	FALSE
	|FROM
	|	ExchangeDifferencesTemporaryTableOtherSettlements AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	11,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	UNDEFINED,
	|	UNDEFINED,
	|	VALUE(Catalog.LinesOfBusiness.Other),
	|	CASE
	|		WHEN DocumentTable.ExchangeRateDifferenceAmount > 0
	|			THEN &ForeignCurrencyExchangeGain
	|		ELSE &ForeignCurrencyExchangeLoss
	|	END,
	|	&ExchangeDifference,
	|	CASE
	|		WHEN DocumentTable.ExchangeRateDifferenceAmount > 0
	|			THEN DocumentTable.ExchangeRateDifferenceAmount
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.ExchangeRateDifferenceAmount > 0
	|			THEN 0
	|		ELSE -DocumentTable.ExchangeRateDifferenceAmount
	|	END,
	|	FALSE
	|FROM
	|	TemporaryTableExchangeRateDifferencesLoanSettlements AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	12,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	&Company,
	|	SalesInvoice.Department,
	|	CASE
	|		WHEN DocumentTable.Order = VALUE(Document.SalesOrder.EmptyRef)
	|				OR DocumentTable.Order = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE DocumentTable.Order
	|	END,
	|	UNDEFINED,
	|	DefaultGLAccounts.GLAccount,
	|	&EarlyPaymentDiscount,
	|	0,
	|	SUM(CASE
	|			WHEN SalesInvoice.ProvideEPD = VALUE(Enum.VariantsOfProvidingEPD.PaymentDocumentWithVATAdjustment)
	|				THEN DocumentTable.AccountingEPDAmountExclVAT
	|			ELSE DocumentTable.AccountingEPDAmount
	|		END),
	|	FALSE
	|FROM
	|	TemporaryTablePaymentDetails AS DocumentTable
	|		INNER JOIN Catalog.DefaultGLAccounts AS DefaultGLAccounts
	|		ON (DefaultGLAccounts.Ref = VALUE(Catalog.DefaultGLAccounts.DiscountAllowed))
	|		INNER JOIN Document.SalesInvoice AS SalesInvoice
	|		ON DocumentTable.Document = SalesInvoice.Ref
	|WHERE
	|	DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashReceipt.FromCustomer)
	|	AND DocumentTable.EPDAmount > 0
	|	AND (SalesInvoice.ProvideEPD = VALUE(Enum.VariantsOfProvidingEPD.PaymentDocument)
	|			OR SalesInvoice.ProvideEPD = VALUE(Enum.VariantsOfProvidingEPD.PaymentDocumentWithVATAdjustment))
	|
	|GROUP BY
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	SalesInvoice.Department,
	|	DocumentTable.Order,
	|	DefaultGLAccounts.GLAccount
	|
	|ORDER BY
	|	Ordering,
	|	LineNumber";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpenses", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableAccountingJournalEntries(DocumentRefCashReceipt, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();

	Query.SetParameter("Ref",							DocumentRefCashReceipt);
	Query.SetParameter("Company",						StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PointInTime",					New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ExchangeDifference",			NStr("en = 'Foreign currency exchange gains and losses'", MainLanguageCode));
	Query.SetParameter("Content",						NStr("en = 'Other income'", MainLanguageCode));
	Query.SetParameter("ContentCurrencyPurchase",		NStr("en = 'Foreign currency purchase'", MainLanguageCode));
	Query.SetParameter("ContentRetailIncome",			NStr("en = 'Cash withdrawal from cash register'", MainLanguageCode));
	Query.SetParameter("ContentCost",					NStr("en = 'Cost of goods sold'", MainLanguageCode));
	Query.SetParameter("ContentMarkup",					NStr("en = 'Retail markup'", MainLanguageCode));
	Query.SetParameter("ContentVAT",					NStr("en = 'VAT'", MainLanguageCode));
	Query.SetParameter("EarlyPaymentDiscount",			NStr("en = 'Early payment discount'", MainLanguageCode));
	Query.SetParameter("ForeignCurrencyExchangeGain",	Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeGain")); 
	Query.SetParameter("ForeignCurrencyExchangeLoss",	Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeLoss"));
	Query.SetParameter("ContentVATOnAdvance",			NStr("en = 'VAT charged on advance payment'", MainLanguageCode));
	Query.SetParameter("VATAdvancesFromCustomers",		Catalogs.DefaultGLAccounts.GetDefaultGLAccount("VATAdvancesFromCustomers"));
	Query.SetParameter("VATOutput",						Catalogs.DefaultGLAccounts.GetDefaultGLAccount("VATOutput"));
	Query.SetParameter("PostAdvancePaymentsBySourceDocuments", StructureAdditionalProperties.AccountingPolicy.PostAdvancePaymentsBySourceDocuments);
	
	Query.Text =
	"SELECT
	|	1 AS Ordering,
	|	1 AS LineNumber,
	|	DocumentTable.Date AS Period,
	|	&Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	DocumentTable.PettyCashGLAccount AS AccountDr,
	|	DocumentTable.Correspondence AS AccountCr,
	|	CASE
	|		WHEN DocumentTable.PettyCashGLAccount.Currency
	|			THEN DocumentTable.CashCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN DocumentTable.Correspondence.Currency
	|			THEN DocumentTable.CashCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	CASE
	|		WHEN DocumentTable.PettyCashGLAccount.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END AS AmountCurDr,
	|	CASE
	|		WHEN DocumentTable.Correspondence.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END AS AmountCurCr,
	|	DocumentTable.Amount AS Amount,
	|	CAST(CASE
	|			WHEN DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashReceipt.CurrencyPurchase)
	|				THEN &ContentCurrencyPurchase
	|			ELSE &Content
	|		END AS STRING(100)) AS Content,
	|	FALSE AS OfflineRecord
	|FROM
	|	TemporaryTableHeader AS DocumentTable
	|WHERE
	|	(DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashReceipt.Other)
	|			OR DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashReceipt.CurrencyPurchase))
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	1,
	|	DocumentTable.Date,
	|	&Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.PettyCashGLAccount,
	|	DocumentTable.CashCRGLAccount,
	|	CASE
	|		WHEN DocumentTable.PettyCashGLAccount.Currency
	|			THEN DocumentTable.CashCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.CashCRGLAccount.Currency
	|			THEN DocumentTable.CashCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.PettyCashGLAccount.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.CashCRGLAccount.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END,
	|	DocumentTable.Amount,
	|	CAST(&ContentRetailIncome AS STRING(100)),
	|	FALSE
	|FROM
	|	TemporaryTableHeader AS DocumentTable
	|WHERE
	|	DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashReceipt.RetailIncome)
	|
	|UNION ALL
	|
	|SELECT
	|	3,
	|	1,
	|	DocumentTable.Date,
	|	&Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.PettyCashGLAccount,
	|	DocumentTable.BusinessLineGLAccountOfRevenueFromSales,
	|	CASE
	|		WHEN DocumentTable.PettyCashGLAccount.Currency
	|			THEN DocumentTable.CashCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.BusinessLineGLAccountOfRevenueFromSales.Currency
	|			THEN DocumentTable.CashCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.PettyCashGLAccount.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.BusinessLineGLAccountOfRevenueFromSales.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END,
	|	DocumentTable.Amount,
	|	CAST(&ContentRetailIncome AS STRING(100)),
	|	FALSE
	|FROM
	|	TemporaryTableHeader AS DocumentTable
	|WHERE
	|	DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashReceipt.RetailIncomeEarningAccounting)
	|
	|UNION ALL
	|
	|SELECT
	|	4,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.PettyCash.GLAccount,
	|	DocumentTable.GLAccount,
	|	CASE
	|		WHEN DocumentTable.PettyCash.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.PettyCash.GLAccount.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END,
	|	DocumentTable.Amount,
	|	DocumentTable.ContentOfAccountingRecord,
	|	FALSE
	|FROM
	|	TemporaryTableAdvanceHolders AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	5,
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
	|			THEN &ForeignCurrencyExchangeGain
	|		ELSE DocumentTable.GLAccount
	|	END,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|				AND DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences < 0
	|				AND DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	0,
	|	0,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN DocumentTable.AmountOfExchangeDifferences
	|		ELSE -DocumentTable.AmountOfExchangeDifferences
	|	END,
	|	&ExchangeDifference,
	|	FALSE
	|FROM
	|	TemporaryTableExchangeDifferencesCalculationWithAdvanceHolder AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	6,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.PettyCash.GLAccount,
	|	DocumentTable.GLAccount,
	|	CASE
	|		WHEN DocumentTable.PettyCash.GLAccount.Currency
	|			THEN DocumentTable.CashCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.PettyCash.GLAccount.Currency
	|			THEN DocumentTable.PaymentAmount
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END,
	|	DocumentTable.Amount,
	|	DocumentTable.ContentOfAccountingRecord,
	|	FALSE
	|FROM
	|	TemporaryTableAccountsReceivable AS DocumentTable
	|WHERE
	|	NOT DocumentTable.isEPD
	|
	|UNION ALL
	|
	|SELECT
	|	7,
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
	|			THEN &ForeignCurrencyExchangeGain
	|		ELSE DocumentTable.GLAccount
	|	END,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|				AND DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences < 0
	|				AND DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	0,
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
	|	8,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.PettyCash.GLAccount,
	|	DocumentTable.GLAccount,
	|	CASE
	|		WHEN DocumentTable.PettyCash.GLAccount.Currency
	|			THEN DocumentTable.CashCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.PettyCash.GLAccount.Currency
	|			THEN DocumentTable.PaymentAmount
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END,
	|	DocumentTable.Amount,
	|	DocumentTable.ContentOfAccountingRecord,
	|	FALSE
	|FROM
	|	TemporaryTableAccountsPayable AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	9,
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
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN DocumentTable.GLAccount
	|		ELSE &ForeignCurrencyExchangeGain
	|	END,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences < 0
	|				AND DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|				AND DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	0,
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
	|UNION ALL
	|
	|SELECT
	|	10,
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
	|			THEN &ForeignCurrencyExchangeGain
	|		ELSE DocumentTable.GLAccount
	|	END,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|				AND DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences < 0
	|				AND DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	0,
	|	0,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN DocumentTable.AmountOfExchangeDifferences
	|		ELSE -DocumentTable.AmountOfExchangeDifferences
	|	END,
	|	&ExchangeDifference,
	|	FALSE
	|FROM
	|	TemporaryTableExchangeRateLossesBanking AS DocumentTable
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
	|			THEN &ForeignCurrencyExchangeGain
	|		ELSE DocumentTable.GLAccount
	|	END,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|				AND DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences < 0
	|				AND DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	0,
	|	0,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN DocumentTable.AmountOfExchangeDifferences
	|		ELSE -DocumentTable.AmountOfExchangeDifferences
	|	END,
	|	&ExchangeDifference,
	|	FALSE
	|FROM
	|	TemporaryTableExchangeRateLossesCashAssetsInRetailCashes AS DocumentTable
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
	|			THEN DocumentTable.GLAccount
	|		ELSE &ForeignCurrencyExchangeLoss
	|	END,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN &ForeignCurrencyExchangeGain
	|		ELSE DocumentTable.GLAccount
	|	END,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|				AND DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences < 0
	|				AND DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	0,
	|	0,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN DocumentTable.AmountOfExchangeDifferences
	|		ELSE -DocumentTable.AmountOfExchangeDifferences
	|	END,
	|	&ExchangeDifference,
	|	FALSE
	|FROM
	|	TemporaryTableCurrencyExchangeRateDifferencesPOSSummary AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	13,
	|	1,
	|	DocumentTable.Date,
	|	&Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.BusinessLineGLAccountOfSalesCost,
	|	DocumentTable.StructuralUnitGLAccountInRetail,
	|	CASE
	|		WHEN DocumentTable.BusinessLineGLAccountOfSalesCost.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.StructuralUnitGLAccountInRetail.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.BusinessLineGLAccountOfSalesCost.Currency
	|			THEN 0
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.StructuralUnitGLAccountInRetail.Currency
	|			THEN 0
	|		ELSE 0
	|	END,
	|	DocumentTable.Cost,
	|	CAST(&ContentCost AS STRING(100)),
	|	FALSE
	|FROM
	|	TemporaryTableCost AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	14,
	|	1,
	|	DocumentTable.Date,
	|	&Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.StructuralUnitGLAccountInRetail,
	|	DocumentTable.StructuralUnitGLAccountMarkup,
	|	CASE
	|		WHEN DocumentTable.StructuralUnitGLAccountInRetail.Currency
	|			THEN DocumentTable.CashCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.StructuralUnitGLAccountMarkup.Currency
	|			THEN DocumentTable.CashCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.StructuralUnitGLAccountInRetail.Currency
	|			THEN 0
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.StructuralUnitGLAccountMarkup.Currency
	|			THEN 0
	|		ELSE 0
	|	END,
	|	-(DocumentTable.Amount - TableCost.Cost),
	|	CAST(&ContentMarkup AS STRING(100)),
	|	FALSE
	|FROM
	|	TemporaryTableHeader AS DocumentTable
	|		LEFT JOIN TemporaryTableCost AS TableCost
	|		ON DocumentTable.Company = TableCost.Company
	|WHERE
	|	DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashReceipt.RetailIncomeEarningAccounting)
	|
	|UNION ALL
	|
	|SELECT
	|	15,
	|	1,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	CASE
	|		WHEN DocumentTable.ExchangeRateDifferenceAmount > 0
	|			THEN DocumentTable.GLAccount
	|		ELSE &ForeignCurrencyExchangeLoss
	|	END,
	|	CASE
	|		WHEN DocumentTable.ExchangeRateDifferenceAmount > 0
	|			THEN &ForeignCurrencyExchangeGain
	|		ELSE DocumentTable.GLAccount
	|	END,
	|	CASE
	|		WHEN DocumentTable.ExchangeRateDifferenceAmount > 0
	|				AND DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.ExchangeRateDifferenceAmount < 0
	|				AND DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	0,
	|	0,
	|	CASE
	|		WHEN DocumentTable.ExchangeRateDifferenceAmount > 0
	|			THEN DocumentTable.ExchangeRateDifferenceAmount
	|		ELSE -DocumentTable.ExchangeRateDifferenceAmount
	|	END,
	|	&ExchangeDifference,
	|	FALSE
	|FROM
	|	ExchangeDifferencesTemporaryTableOtherSettlements AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	16,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.PettyCash.GLAccount,
	|	DocumentTable.GLAccount,
	|	CASE
	|		WHEN DocumentTable.PettyCash.GLAccount.Currency
	|			THEN DocumentTable.CashCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.PettyCash.GLAccount.Currency
	|			THEN DocumentTable.PaymentAmount
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END,
	|	DocumentTable.Amount,
	|	DocumentTable.PostingContent,
	|	FALSE
	|FROM
	|	TemporaryTableOtherSettlements AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	17,
	|	1,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.PettyCash.GLAccount,
	|	DocumentTable.GLAccount,
	|	CASE
	|		WHEN DocumentTable.PettyCash.GLAccount.Currency
	|			THEN DocumentTable.CashCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.PettyCash.GLAccount.Currency
	|			THEN DocumentTable.PaymentAmount
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END,
	|	DocumentTable.Amount,
	|	DocumentTable.PostingContent,
	|	FALSE
	|FROM
	|	TemporaryTableLoanSettlements AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	18,
	|	1,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	CASE
	|		WHEN DocumentTable.ExchangeRateDifferenceAmount > 0
	|			THEN DocumentTable.GLAccount
	|		ELSE &ForeignCurrencyExchangeLoss
	|	END,
	|	CASE
	|		WHEN DocumentTable.ExchangeRateDifferenceAmount > 0
	|			THEN &ForeignCurrencyExchangeGain
	|		ELSE DocumentTable.GLAccount
	|	END,
	|	CASE
	|		WHEN DocumentTable.ExchangeRateDifferenceAmount > 0
	|				AND DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.ExchangeRateDifferenceAmount < 0
	|				AND DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	0,
	|	0,
	|	CASE
	|		WHEN DocumentTable.ExchangeRateDifferenceAmount > 0
	|			THEN DocumentTable.ExchangeRateDifferenceAmount
	|		ELSE -DocumentTable.ExchangeRateDifferenceAmount
	|	END,
	|	&ExchangeDifference,
	|	FALSE
	|FROM
	|	TemporaryTableExchangeRateDifferencesLoanSettlements AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	19,
	|	1,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	&VATAdvancesFromCustomers,
	|	&VATOutput,
	|	UNDEFINED,
	|	UNDEFINED,
	|	0,
	|	0,
	|	SUM(DocumentTable.VATAmount),
	|	&ContentVATOnAdvance,
	|	FALSE
	|FROM
	|	TemporaryTablePaymentDetails AS DocumentTable
	|WHERE
	|	DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashReceipt.FromCustomer)
	|	AND &PostAdvancePaymentsBySourceDocuments
	|	AND DocumentTable.AdvanceFlag
	|
	|GROUP BY
	|	DocumentTable.Date,
	|	DocumentTable.Company
	|
	|UNION ALL
	|
	|SELECT
	|	20,
	|	1,
	|	TemporaryTablePaymentDetails.Date,
	|	&Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DefaultGLAccounts.GLAccount,
	|	TemporaryTablePaymentDetails.GLAccountCustomerSettlements,
	|	CASE
	|		WHEN DefaultGLAccounts.GLAccount.Currency
	|			THEN TemporaryTablePaymentDetails.CashCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.GLAccountCustomerSettlements.Currency
	|			THEN TemporaryTablePaymentDetails.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	SUM(CASE
	|			WHEN DefaultGLAccounts.GLAccount.Currency
	|				THEN CASE
	|						WHEN SalesInvoice.ProvideEPD = VALUE(Enum.VariantsOfProvidingEPD.PaymentDocumentWithVATAdjustment)
	|							THEN TemporaryTablePaymentDetails.EPDAmountExclVAT
	|						ELSE TemporaryTablePaymentDetails.EPDAmount
	|					END
	|			ELSE 0
	|		END),
	|	SUM(CASE
	|			WHEN TemporaryTablePaymentDetails.GLAccountCustomerSettlements.Currency
	|				THEN CASE
	|						WHEN SalesInvoice.ProvideEPD = VALUE(Enum.VariantsOfProvidingEPD.PaymentDocumentWithVATAdjustment)
	|							THEN TemporaryTablePaymentDetails.SettlementsEPDAmountExclVAT
	|						ELSE TemporaryTablePaymentDetails.SettlementsEPDAmount
	|					END
	|			ELSE 0
	|		END),
	|	SUM(CASE
	|			WHEN SalesInvoice.ProvideEPD = VALUE(Enum.VariantsOfProvidingEPD.PaymentDocumentWithVATAdjustment)
	|				THEN TemporaryTablePaymentDetails.AccountingEPDAmountExclVAT
	|			ELSE TemporaryTablePaymentDetails.AccountingEPDAmount
	|		END),
	|	&EarlyPaymentDiscount,
	|	FALSE
	|FROM
	|	TemporaryTablePaymentDetails AS TemporaryTablePaymentDetails
	|		INNER JOIN Document.SalesInvoice AS SalesInvoice
	|		ON TemporaryTablePaymentDetails.Document = SalesInvoice.Ref
	|		INNER JOIN Catalog.DefaultGLAccounts AS DefaultGLAccounts
	|		ON (DefaultGLAccounts.Ref = VALUE(Catalog.DefaultGLAccounts.DiscountAllowed))
	|WHERE
	|	TemporaryTablePaymentDetails.OperationKind = VALUE(Enum.OperationTypesCashReceipt.FromCustomer)
	|	AND TemporaryTablePaymentDetails.DoOperationsByDocuments
	|	AND NOT TemporaryTablePaymentDetails.AdvanceFlag
	|	AND TemporaryTablePaymentDetails.EPDAmount > 0
	|	AND (SalesInvoice.ProvideEPD = VALUE(Enum.VariantsOfProvidingEPD.PaymentDocument)
	|			OR SalesInvoice.ProvideEPD = VALUE(Enum.VariantsOfProvidingEPD.PaymentDocumentWithVATAdjustment))
	|
	|GROUP BY
	|	TemporaryTablePaymentDetails.Date,
	|	DefaultGLAccounts.GLAccount,
	|	TemporaryTablePaymentDetails.GLAccountCustomerSettlements,
	|	CASE
	|		WHEN DefaultGLAccounts.GLAccount.Currency
	|			THEN TemporaryTablePaymentDetails.CashCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.GLAccountCustomerSettlements.Currency
	|			THEN TemporaryTablePaymentDetails.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END
	|
	|UNION ALL
	|
	|SELECT
	|	21,
	|	1,
	|	TemporaryTablePaymentDetails.Date,
	|	&Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	&VATOutput,
	|	TemporaryTablePaymentDetails.GLAccountCustomerSettlements,
	|	UNDEFINED,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.GLAccountCustomerSettlements.Currency
	|			THEN TemporaryTablePaymentDetails.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	0,
	|	SUM(CASE
	|			WHEN TemporaryTablePaymentDetails.GLAccountCustomerSettlements.Currency
	|				THEN TemporaryTablePaymentDetails.SettlementsEPDAmount - TemporaryTablePaymentDetails.SettlementsEPDAmountExclVAT
	|			ELSE 0
	|		END),
	|	SUM(TemporaryTablePaymentDetails.AccountingEPDAmount - TemporaryTablePaymentDetails.AccountingEPDAmountExclVAT),
	|	&ContentVAT,
	|	FALSE
	|FROM
	|	TemporaryTablePaymentDetails AS TemporaryTablePaymentDetails
	|		INNER JOIN Document.SalesInvoice AS SalesInvoice
	|		ON TemporaryTablePaymentDetails.Document = SalesInvoice.Ref
	|			AND (SalesInvoice.ProvideEPD = VALUE(Enum.VariantsOfProvidingEPD.PaymentDocumentWithVATAdjustment))
	|WHERE
	|	TemporaryTablePaymentDetails.OperationKind = VALUE(Enum.OperationTypesCashReceipt.FromCustomer)
	|	AND TemporaryTablePaymentDetails.DoOperationsByDocuments
	|	AND NOT TemporaryTablePaymentDetails.AdvanceFlag
	|	AND TemporaryTablePaymentDetails.EPDAmount > 0
	|
	|GROUP BY
	|	TemporaryTablePaymentDetails.Date,
	|	TemporaryTablePaymentDetails.GLAccountCustomerSettlements,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.GLAccountCustomerSettlements.Currency
	|			THEN TemporaryTablePaymentDetails.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END
	|
	|ORDER BY
	|	Ordering,
	|	LineNumber";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountingJournalEntries", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableIncomeAndExpensesCashMethod(DocumentRefCashReceipt, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefCashReceipt);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("IncomeAndExpensesAccountingCashMethod", StructureAdditionalProperties.AccountingPolicy.IncomeAndExpensesAccountingCashMethod);
	
	Query.Text =
	"SELECT
	|	DocumentTable.Date AS Period,
	|	&Company AS Company,
	|	UNDEFINED AS BusinessLine,
	|	DocumentTable.Item AS Item,
	|	DocumentTable.AccountingAmount AS AmountIncome,
	|	0 AS AmountExpense
	|FROM
	|	TemporaryTablePaymentDetails AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashReceipt.FromCustomer)
	|	AND DocumentTable.AdvanceFlag
	|
	|UNION ALL
	|
	|SELECT
	|	Table.Period,
	|	Table.Company,
	|	Table.BusinessLine,
	|	Table.Item,
	|	Table.AmountIncome,
	|	0
	|FROM
	|	TemporaryTableTableDeferredIncomeAndExpenditure AS Table
	|WHERE
	|	Table.AmountIncome > 0
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentTable.Date,
	|	&Company,
	|	VALUE(Catalog.LinesOfBusiness.Other),
	|	DocumentTable.Item,
	|	DocumentTable.Amount,
	|	0
	|FROM
	|	TemporaryTableHeader AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND (DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashReceipt.Other)
	|			OR DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashReceipt.OtherSettlements)
	|			OR DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashReceipt.LoanSettlements)
	|			OR DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashReceipt.LoanRepaymentByEmployee)
	|			OR DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashReceipt.CurrencyPurchase))
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentTable.Date,
	|	&Company,
	|	UNDEFINED,
	|	DocumentTable.Item,
	|	0,
	|	-DocumentTable.AccountingAmount
	|FROM
	|	TemporaryTablePaymentDetails AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashReceipt.FromVendor)
	|	AND DocumentTable.AdvanceFlag
	|
	|UNION ALL
	|
	|SELECT
	|	Table.Period,
	|	Table.Company,
	|	Table.BusinessLine,
	|	Table.Item,
	|	0,
	|	-Table.AmountExpense
	|FROM
	|	TemporaryTableTableDeferredIncomeAndExpenditure AS Table
	|WHERE
	|	Table.AmountExpense > 0";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpensesCashMethod", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableUnallocatedExpenses(DocumentRefCashReceipt, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefCashReceipt);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("IncomeAndExpensesAccountingCashMethod", StructureAdditionalProperties.AccountingPolicy.IncomeAndExpensesAccountingCashMethod);
	
	Query.Text =
	"SELECT
	|	1 AS Ordering,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Date AS Period,
	|	&Company AS Company,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByDocuments
	|			THEN &Ref
	|		ELSE UNDEFINED
	|	END AS Document,
	|	DocumentTable.Item AS Item,
	|	DocumentTable.AccountingAmount AS AmountIncome,
	|	0 AS AmountExpense
	|FROM
	|	TemporaryTablePaymentDetails AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashReceipt.FromCustomer)
	|	AND DocumentTable.AdvanceFlag
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	VALUE(AccumulationRecordType.Receipt),
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	&Company,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByDocuments
	|			THEN &Ref
	|		ELSE UNDEFINED
	|	END,
	|	DocumentTable.Item,
	|	0,
	|	-DocumentTable.AccountingAmount
	|FROM
	|	TemporaryTablePaymentDetails AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashReceipt.FromVendor)
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
Procedure GenerateTableIncomeAndExpensesRetained(DocumentRefCashReceipt, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefCashReceipt);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("IncomeAndExpensesAccountingCashMethod", StructureAdditionalProperties.AccountingPolicy.IncomeAndExpensesAccountingCashMethod);
	Query.SetParameter("Period", StructureAdditionalProperties.ForPosting.Date);
	
	// Generating the table with charge amounts.
	Query.Text =
	"SELECT
	|	&Company AS Company,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByDocuments
	|			THEN DocumentTable.Document
	|		ELSE UNDEFINED
	|	END AS Document,
	|	DocumentTable.Item AS Item,
	|	SUM(DocumentTable.AccountingAmount) AS AmountToBeWrittenOff
	|FROM
	|	TemporaryTablePaymentDetails AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashReceipt.FromCustomer)
	|	AND Not DocumentTable.AdvanceFlag
	|
	|GROUP BY
	|	CASE
	|		WHEN DocumentTable.DoOperationsByDocuments
	|			THEN DocumentTable.Document
	|		ELSE UNDEFINED
	|	END,
	|	DocumentTable.Item";
	
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
	|	VALUE(Catalog.CashFlowItems.EmptyRef) AS Item,
	|	0 AS AmountIncome,
	|	0 AS AmountExpense,
	|	SUM(IncomeAndExpensesRetainedBalances.AmountIncomeBalance) AS AmountIncomeBalance,
	|	-SUM(IncomeAndExpensesRetainedBalances.AmountExpenseBalance) AS AmountExpenseBalance
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
	|							TemporaryTablePaymentDetails AS DocumentTable
	|						WHERE
	|							(DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashReceipt.FromCustomer)
	|								OR DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashReceipt.FromVendor)))) AS IncomeAndExpensesRetainedBalances
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
				AmountRowBalances.Item = StringSumToBeWrittenOff.Item; 
				AmountToBeWrittenOff = AmountToBeWrittenOff - AmountRowBalances.AmountIncomeBalance;
			ElsIf AmountRowBalances.AmountIncomeBalance >= AmountToBeWrittenOff Then
				AmountRowBalances.AmountIncome = AmountToBeWrittenOff;
				AmountRowBalances.Item = StringSumToBeWrittenOff.Item;
				AmountToBeWrittenOff = 0;
			EndIf;
		EndDo;
	EndDo;
	
	// Generating the table with charge amounts.
	Query.Text =
	"SELECT
	|	&Company AS Company,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByDocuments
	|			THEN DocumentTable.Document
	|		ELSE UNDEFINED
	|	END AS Document,
	|	DocumentTable.Item AS Item,
	|	SUM(DocumentTable.AccountingAmount) AS AmountToBeWrittenOff
	|FROM
	|	TemporaryTablePaymentDetails AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashReceipt.FromVendor)
	|	AND Not DocumentTable.AdvanceFlag
	|
	|GROUP BY
	|	CASE
	|		WHEN DocumentTable.DoOperationsByDocuments
	|			THEN DocumentTable.Document
	|		ELSE UNDEFINED
	|	END,
	|	DocumentTable.Item"; 
	
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
				AmountRowBalances.Item = StringSumToBeWrittenOff.Item;
				AmountToBeWrittenOff = AmountToBeWrittenOff - AmountRowBalances.AmountExpenseBalance;
			ElsIf AmountRowBalances.AmountExpenseBalance >= AmountToBeWrittenOff Then
				AmountRowBalances.AmountExpense = AmountToBeWrittenOff;
				AmountRowBalances.Item = StringSumToBeWrittenOff.Item;
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
	|	Table.Item AS Item,
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
	|	Table.Item AS Item,
	|	Table.AmountIncome AS AmountIncome,
	|	- Table.AmountExpense AS AmountExpense,
	|	Table.BusinessLine AS BusinessLine
	|FROM
	|	TemporaryTableTableDeferredIncomeAndExpenditure AS Table";

	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpensesRetained", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTablePaymentCalendar(DocumentRefCashReceipt, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefCashReceipt);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("UsePaymentCalendar", Constants.UsePaymentCalendar.Get());
	
	Query.Text =
	"SELECT DISTINCT
	|	DocumentTable.Document AS Document,
	|	DocumentTable.Date AS Period
	|INTO SalesInvoiceTable
	|FROM
	|	TemporaryTablePaymentDetails AS DocumentTable
	|		INNER JOIN Document.SalesInvoice AS SalesInvoice
	|		ON DocumentTable.Document = SalesInvoice.Ref
	|WHERE
	|	&UsePaymentCalendar
	|	AND DocumentTable.EPDAmount > 0
	|	AND (SalesInvoice.ProvideEPD = VALUE(Enum.VariantsOfProvidingEPD.PaymentDocument)
	|			OR SalesInvoice.ProvideEPD = VALUE(Enum.VariantsOfProvidingEPD.PaymentDocumentWithVATAdjustment))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccountsReceivable.AmountCur AS AmountCur,
	|	AccountsReceivable.Document AS Document
	|INTO PaymentsAmountsDocument
	|FROM
	|	AccumulationRegister.AccountsReceivable AS AccountsReceivable
	|		INNER JOIN SalesInvoiceTable AS SalesInvoiceTable
	|		ON AccountsReceivable.Document = SalesInvoiceTable.Document
	|WHERE
	|	AccountsReceivable.RecordType = VALUE(AccumulationRecordType.Expense)
	|	AND AccountsReceivable.SettlementsType = VALUE(Enum.SettlementsTypes.Debt)
	|	AND AccountsReceivable.Recorder <> AccountsReceivable.Document
	|	AND AccountsReceivable.Recorder <> &Ref
	|
	|UNION ALL
	|
	|SELECT
	|	TemporaryTablePaymentDetails.SettlementsAmount,
	|	TemporaryTablePaymentDetails.Document
	|FROM
	|	TemporaryTablePaymentDetails AS TemporaryTablePaymentDetails
	|		INNER JOIN SalesInvoiceTable AS SalesInvoiceTable
	|		ON TemporaryTablePaymentDetails.Document = SalesInvoiceTable.Document
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SUM(PaymentsAmountsDocument.AmountCur) AS AmountCur,
	|	PaymentsAmountsDocument.Document AS Document
	|INTO PaymentsAmounts
	|FROM
	|	PaymentsAmountsDocument AS PaymentsAmountsDocument
	|
	|GROUP BY
	|	PaymentsAmountsDocument.Document
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	PaymentCalendar.Company AS Company,
	|	PaymentCalendar.Currency AS Currency,
	|	PaymentCalendar.Item AS Item,
	|	PaymentCalendar.CashAssetsType AS CashAssetsType,
	|	PaymentCalendar.BankAccountPettyCash AS BankAccountPettyCash,
	|	PaymentCalendar.Quote AS Quote,
	|	PaymentCalendar.PaymentConfirmationStatus AS PaymentConfirmationStatus,
	|	SUM(PaymentCalendar.Amount) AS Amount,
	|	SalesInvoiceTable.Document AS Document,
	|	SalesInvoiceTable.Period AS Period
	|INTO SalesInvoicePaymentCalendar
	|FROM
	|	AccumulationRegister.PaymentCalendar AS PaymentCalendar
	|		INNER JOIN SalesInvoiceTable AS SalesInvoiceTable
	|		ON PaymentCalendar.Recorder = SalesInvoiceTable.Document
	|
	|GROUP BY
	|	PaymentCalendar.CashAssetsType,
	|	PaymentCalendar.Currency,
	|	PaymentCalendar.Item,
	|	PaymentCalendar.Company,
	|	PaymentCalendar.BankAccountPettyCash,
	|	PaymentCalendar.PaymentConfirmationStatus,
	|	PaymentCalendar.Quote,
	|	SalesInvoiceTable.Document,
	|	SalesInvoiceTable.Period
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SalesInvoicePaymentCalendar.Company AS Company,
	|	SalesInvoicePaymentCalendar.Currency AS Currency,
	|	SalesInvoicePaymentCalendar.Item AS Item,
	|	SalesInvoicePaymentCalendar.CashAssetsType AS CashAssetsType,
	|	SalesInvoicePaymentCalendar.BankAccountPettyCash AS BankAccountPettyCash,
	|	SalesInvoicePaymentCalendar.Quote AS Quote,
	|	SalesInvoicePaymentCalendar.PaymentConfirmationStatus AS PaymentConfirmationStatus,
	|	ISNULL(PaymentsAmounts.AmountCur, 0) - SalesInvoicePaymentCalendar.Amount AS Amount,
	|	SalesInvoicePaymentCalendar.Document AS Document,
	|	SalesInvoicePaymentCalendar.Period AS Period
	|INTO Tabular
	|FROM
	|	SalesInvoicePaymentCalendar AS SalesInvoicePaymentCalendar
	|		LEFT JOIN PaymentsAmounts AS PaymentsAmounts
	|		ON SalesInvoicePaymentCalendar.Document = PaymentsAmounts.Document
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	1 AS Ordering,
	|	MAX(DocumentTable.LineNumber) AS LineNumber,
	|	DocumentTable.Date AS Period,
	|	&Company AS Company,
	|	DocumentTable.Item AS Item,
	|	VALUE(Enum.CashAssetTypes.Cash) AS CashAssetsType,
	|	VALUE(Enum.PaymentApprovalStatuses.Approved) AS PaymentConfirmationStatus,
	|	DocumentTable.PettyCash AS BankAccountPettyCash,
	|	CASE
	|		WHEN DocumentTable.Contract.SettlementsInStandardUnits
	|			THEN DocumentTable.SettlementsCurrency
	|		ELSE DocumentTable.CashCurrency
	|	END AS Currency,
	|	DocumentTable.QuoteToPaymentCalendar AS Quote,
	|	SUM(CASE
	|			WHEN DocumentTable.Contract.SettlementsInStandardUnits
	|				THEN DocumentTable.SettlementsAmount
	|			ELSE DocumentTable.PaymentAmount
	|		END) AS PaymentAmount,
	|	0 AS Amount
	|FROM
	|	TemporaryTablePaymentDetails AS DocumentTable
	|WHERE
	|	&UsePaymentCalendar
	|
	|GROUP BY
	|	DocumentTable.Date,
	|	DocumentTable.PettyCash,
	|	CASE
	|		WHEN DocumentTable.Contract.SettlementsInStandardUnits
	|			THEN DocumentTable.SettlementsCurrency
	|		ELSE DocumentTable.CashCurrency
	|	END,
	|	DocumentTable.QuoteToPaymentCalendar,
	|	DocumentTable.Item
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	1,
	|	DocumentTable.Date,
	|	&Company,
	|	DocumentTable.Item,
	|	VALUE(Enum.CashAssetTypes.Cash),
	|	VALUE(Enum.PaymentApprovalStatuses.Approved),
	|	DocumentTable.PettyCash,
	|	DocumentTable.CashCurrency,
	|	UNDEFINED,
	|	DocumentTable.DocumentAmount,
	|	0
	|FROM
	|	Document.CashVoucher AS DocumentTable
	|		LEFT JOIN (SELECT
	|			COUNT(ISNULL(TemporaryTablePaymentDetails.LineNumber, 0)) AS Quantity
	|		FROM
	|			TemporaryTablePaymentDetails AS TemporaryTablePaymentDetails) AS NestedSelect
	|		ON (TRUE)
	|WHERE
	|	&UsePaymentCalendar
	|	AND DocumentTable.Ref = &Ref
	|	AND NestedSelect.Quantity = 0
	|
	|UNION ALL
	|
	|SELECT
	|	3,
	|	1,
	|	Tabular.Period,
	|	Tabular.Company,
	|	Tabular.Item,
	|	Tabular.CashAssetsType,
	|	Tabular.PaymentConfirmationStatus,
	|	Tabular.BankAccountPettyCash,
	|	Tabular.Currency,
	|	Tabular.Quote,
	|	0,
	|	Tabular.Amount
	|FROM
	|	Tabular AS Tabular
	|WHERE
	|	Tabular.Amount < 0
	|
	|ORDER BY
	|	Ordering,
	|	LineNumber";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TablePaymentCalendar", QueryResult.Unload());
	
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
	|	DocumentTable.Order AS Quote,
	|	SUM(CASE
	|			WHEN NOT DocumentTable.AdvanceFlag
	|				THEN 0
	|			WHEN DocumentTable.CashCurrency = DocumentTable.Order.DocumentCurrency
	|				THEN DocumentTable.PaymentAmount
	|			WHEN DocumentTable.SettlementsCurrency = DocumentTable.Order.DocumentCurrency
	|				THEN DocumentTable.SettlementsAmount
	|			ELSE CAST(DocumentTable.PaymentAmount * ExchangeRatesOfPettyCashe.ExchangeRate * ExchangeRatesOfAccount.Multiplicity / (ExchangeRatesOfAccount.ExchangeRate * ExchangeRatesOfPettyCashe.Multiplicity) AS NUMBER(15, 2))
	|		END) * CASE
	|		WHEN DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashReceipt.FromVendor)
	|			THEN -1
	|		ELSE 1
	|	END AS AdvanceAmount,
	|	SUM(CASE
	|			WHEN DocumentTable.AdvanceFlag
	|				THEN 0
	|			WHEN DocumentTable.CashCurrency = DocumentTable.Order.DocumentCurrency
	|				THEN DocumentTable.PaymentAmount
	|			WHEN DocumentTable.SettlementsCurrency = DocumentTable.Order.DocumentCurrency
	|				THEN DocumentTable.SettlementsAmount
	|			ELSE CAST(DocumentTable.PaymentAmount * ExchangeRatesOfPettyCashe.ExchangeRate * ExchangeRatesOfAccount.Multiplicity / (ExchangeRatesOfAccount.ExchangeRate * ExchangeRatesOfPettyCashe.Multiplicity) AS NUMBER(15, 2))
	|		END) * CASE
	|		WHEN DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashReceipt.FromVendor)
	|			THEN -1
	|		ELSE 1
	|	END AS PaymentAmount
	|FROM
	|	TemporaryTablePaymentDetails AS DocumentTable
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&PointInTime, ) AS ExchangeRatesOfAccount
	|		ON DocumentTable.Order.DocumentCurrency = ExchangeRatesOfAccount.Currency
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&PointInTime, ) AS ExchangeRatesOfPettyCashe
	|		ON DocumentTable.CashCurrency = ExchangeRatesOfPettyCashe.Currency
	|WHERE
	|	(VALUETYPE(DocumentTable.Order) = TYPE(Document.SalesOrder)
	|				AND DocumentTable.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|			OR VALUETYPE(DocumentTable.Order) = TYPE(Document.PurchaseOrder)
	|				AND DocumentTable.Order <> VALUE(Document.PurchaseOrder.EmptyRef))
	|	AND (DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashReceipt.FromCustomer)
	|			OR DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashReceipt.FromVendor))
	|
	|GROUP BY
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	DocumentTable.Order,
	|	DocumentTable.OperationKind
	|
	|ORDER BY
	|	LineNumber";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInvoicesAndOrdersPayment", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTablePOSSummary(DocumentRefCashReceipt, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();

	Query.SetParameter("Ref",					DocumentRefCashReceipt);
	Query.SetParameter("PointInTime",			New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod",			StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("Company",				StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("RetailIncome",			NStr("en = 'Revenue'", MainLanguageCode));
	Query.SetParameter("Cost",					NStr("en = 'Cost of goods sold'", MainLanguageCode));
	Query.SetParameter("ExchangeDifference",	NStr("en = 'Foreign currency exchange gains and losses'", MainLanguageCode));
	
	Query.Text =
	"SELECT
	|	1 AS LineNumber,
	|	DocumentTable.Date AS Date,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.Department AS Department,
	|	DocumentTable.StructuralUnitGLAccountInRetail AS StructuralUnitGLAccountInRetail,
	|	DocumentTable.BusinessLine AS BusinessLine,
	|	DocumentTable.BusinessLineGLAccountOfSalesCost AS BusinessLineGLAccountOfSalesCost,
	|	DocumentTable.StructuralUnit AS StructuralUnit,
	|	DocumentTable.CashCurrency AS Currency,
	|	SUM(DocumentTable.Amount) AS Amount,
	|	SUM(DocumentTable.AmountCur) AS AmountCur,
	|	-SUM(DocumentTable.Amount) AS AmountForBalance,
	|	-SUM(DocumentTable.AmountCur) AS AmountCurForBalance,
	|	DocumentTable.StructuralUnitGLAccountInRetail AS GLAccount,
	|	0 AS Cost,
	|	&RetailIncome AS ContentOfAccountingRecord
	|INTO TemporaryTablePOSSummary
	|FROM
	|	TemporaryTableHeader AS DocumentTable
	|WHERE
	|	DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashReceipt.RetailIncomeEarningAccounting)
	|
	|GROUP BY
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	DocumentTable.Department,
	|	DocumentTable.StructuralUnitGLAccountInRetail,
	|	DocumentTable.BusinessLine,
	|	DocumentTable.BusinessLineGLAccountOfSalesCost,
	|	DocumentTable.StructuralUnit,
	|	DocumentTable.CashCurrency,
	|	DocumentTable.StructuralUnitGLAccountInRetail
	|
	|INDEX BY
	|	Company,
	|	StructuralUnit,
	|	Currency,
	|	GLAccount
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	1 AS LineNumber,
	|	DocumentTable.Date AS Date,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.StructuralUnit AS StructuralUnit,
	|	DocumentTable.Department AS Department,
	|	DocumentTable.Currency AS Currency,
	|	DocumentTable.BusinessLine AS BusinessLine,
	|	DocumentTable.BusinessLineGLAccountOfSalesCost AS BusinessLineGLAccountOfSalesCost,
	|	DocumentTable.StructuralUnitGLAccountInRetail AS StructuralUnitGLAccountInRetail,
	|	CASE
	|		WHEN POSSummaryBalances.AmountCurBalance - DocumentTable.AmountCur = 0
	|			THEN POSSummaryBalances.CostBalance
	|		WHEN POSSummaryBalances.AmountCurBalance <> 0
	|			THEN CAST(POSSummaryBalances.CostBalance * DocumentTable.AmountCur / POSSummaryBalances.AmountCurBalance AS NUMBER(15, 2))
	|		ELSE 0
	|	END AS Cost
	|INTO TemporaryTableCost
	|FROM
	|	TemporaryTablePOSSummary AS DocumentTable
	|		LEFT JOIN (SELECT
	|			POSSummaryBalances.Company AS Company,
	|			POSSummaryBalances.StructuralUnit AS StructuralUnit,
	|			POSSummaryBalances.Currency AS Currency,
	|			SUM(POSSummaryBalances.AmountBalance) AS AmountBalance,
	|			SUM(POSSummaryBalances.AmountCurBalance) AS AmountCurBalance,
	|			SUM(POSSummaryBalances.CostBalance) AS CostBalance
	|		FROM
	|			(SELECT
	|				POSSummaryBalances.Company AS Company,
	|				POSSummaryBalances.StructuralUnit AS StructuralUnit,
	|				POSSummaryBalances.Currency AS Currency,
	|				ISNULL(POSSummaryBalances.AmountBalance, 0) AS AmountBalance,
	|				ISNULL(POSSummaryBalances.AmountCurBalance, 0) AS AmountCurBalance,
	|				ISNULL(POSSummaryBalances.CostBalance, 0) AS CostBalance
	|			FROM
	|				AccumulationRegister.POSSummary.Balance(
	|						&PointInTime,
	|						(Company, StructuralUnit, Currency) In
	|							(SELECT DISTINCT
	|								TemporaryTablePOSSummary.Company,
	|								TemporaryTablePOSSummary.StructuralUnit,
	|								TemporaryTablePOSSummary.Currency
	|							FROM
	|								TemporaryTablePOSSummary)) AS POSSummaryBalances
	|			
	|			UNION ALL
	|			
	|			SELECT
	|				DocumentRegisterRecordsPOSSummary.Company,
	|				DocumentRegisterRecordsPOSSummary.StructuralUnit,
	|				DocumentRegisterRecordsPOSSummary.Currency,
	|				CASE
	|					WHEN DocumentRegisterRecordsPOSSummary.RecordType = VALUE(AccumulationRecordType.Receipt)
	|						THEN -ISNULL(DocumentRegisterRecordsPOSSummary.Amount, 0)
	|					ELSE ISNULL(DocumentRegisterRecordsPOSSummary.Amount, 0)
	|				END,
	|				CASE
	|					WHEN DocumentRegisterRecordsPOSSummary.RecordType = VALUE(AccumulationRecordType.Receipt)
	|						THEN -ISNULL(DocumentRegisterRecordsPOSSummary.AmountCur, 0)
	|					ELSE ISNULL(DocumentRegisterRecordsPOSSummary.AmountCur, 0)
	|				END,
	|				CASE
	|					WHEN DocumentRegisterRecordsPOSSummary.RecordType = VALUE(AccumulationRecordType.Receipt)
	|						THEN -ISNULL(DocumentRegisterRecordsPOSSummary.Cost, 0)
	|					ELSE ISNULL(DocumentRegisterRecordsPOSSummary.Cost, 0)
	|				END
	|			FROM
	|				AccumulationRegister.POSSummary AS DocumentRegisterRecordsPOSSummary
	|			WHERE
	|				DocumentRegisterRecordsPOSSummary.Recorder = &Ref
	|				AND DocumentRegisterRecordsPOSSummary.Period <= &ControlPeriod) AS POSSummaryBalances
	|		
	|		GROUP BY
	|			POSSummaryBalances.Company,
	|			POSSummaryBalances.StructuralUnit,
	|			POSSummaryBalances.Currency) AS POSSummaryBalances
	|		ON DocumentTable.Company = POSSummaryBalances.Company
	|			AND DocumentTable.StructuralUnit = POSSummaryBalances.StructuralUnit
	|			AND DocumentTable.Currency = POSSummaryBalances.Currency
	|WHERE
	|	(CASE
	|				WHEN POSSummaryBalances.AmountCurBalance - DocumentTable.AmountCur = 0
	|					THEN POSSummaryBalances.CostBalance
	|				WHEN POSSummaryBalances.AmountCurBalance <> 0
	|					THEN CAST(POSSummaryBalances.CostBalance * DocumentTable.AmountCur / POSSummaryBalances.AmountCurBalance AS NUMBER(15, 2))
	|				ELSE 0
	|			END > 0.005
	|			OR CASE
	|				WHEN POSSummaryBalances.AmountCurBalance - DocumentTable.AmountCur = 0
	|					THEN POSSummaryBalances.CostBalance
	|				WHEN POSSummaryBalances.AmountCurBalance <> 0
	|					THEN CAST(POSSummaryBalances.CostBalance * DocumentTable.AmountCur / POSSummaryBalances.AmountCurBalance AS NUMBER(15, 2))
	|				ELSE 0
	|			END < -0.005)";
	
	Query.Execute();
	
	// Setting of the exclusive lock of the cash funds controlled balances.
	Query.Text =
	"SELECT
	|	TemporaryTablePOSSummary.Company AS Company,
	|	TemporaryTablePOSSummary.StructuralUnit AS StructuralUnit,
	|	TemporaryTablePOSSummary.Currency AS Currency
	|FROM
	|	TemporaryTablePOSSummary AS TemporaryTablePOSSummary";
	
	QueryResult = Query.Execute();
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.POSSummary");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;
	
	For Each ColumnQueryResult In QueryResult.Columns Do
		LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
	EndDo;
	Block.Lock();
	
	Query.Text =
	"SELECT
	|	POSSummaryBalances.Company AS Company,
	|	POSSummaryBalances.StructuralUnit AS StructuralUnit,
	|	POSSummaryBalances.GLAccount AS GLAccount,
	|	POSSummaryBalances.Currency AS Currency,
	|	SUM(POSSummaryBalances.AmountBalance) AS AmountBalance,
	|	SUM(POSSummaryBalances.AmountCurBalance) AS AmountCurBalance
	|INTO TemporaryTableBalancesAfterPosting
	|FROM
	|	(SELECT
	|		TemporaryTable.Company AS Company,
	|		TemporaryTable.StructuralUnit AS StructuralUnit,
	|		TemporaryTable.Currency AS Currency,
	|		TemporaryTable.GLAccount AS GLAccount,
	|		TemporaryTable.AmountForBalance AS AmountBalance,
	|		TemporaryTable.AmountCurForBalance AS AmountCurBalance
	|	FROM
	|		TemporaryTablePOSSummary AS TemporaryTable
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		TableBalances.Company,
	|		TableBalances.StructuralUnit,
	|		TableBalances.Currency,
	|		TableBalances.StructuralUnit.GLAccountInRetail,
	|		ISNULL(TableBalances.AmountBalance, 0),
	|		ISNULL(TableBalances.AmountCurBalance, 0)
	|	FROM
	|		AccumulationRegister.POSSummary.Balance(
	|				&PointInTime,
	|				(Company, StructuralUnit, Currency) IN
	|					(SELECT DISTINCT
	|						TemporaryTablePOSSummary.Company,
	|						TemporaryTablePOSSummary.StructuralUnit,
	|						TemporaryTablePOSSummary.Currency
	|					FROM
	|						TemporaryTablePOSSummary)) AS TableBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecords.Company,
	|		DocumentRegisterRecords.StructuralUnit,
	|		DocumentRegisterRecords.Currency,
	|		DocumentRegisterRecords.StructuralUnit.GLAccountInRetail,
	|		CASE
	|			WHEN DocumentRegisterRecords.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -ISNULL(DocumentRegisterRecords.Amount, 0)
	|			ELSE ISNULL(DocumentRegisterRecords.Amount, 0)
	|		END,
	|		CASE
	|			WHEN DocumentRegisterRecords.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -ISNULL(DocumentRegisterRecords.AmountCur, 0)
	|			ELSE ISNULL(DocumentRegisterRecords.AmountCur, 0)
	|		END
	|	FROM
	|		AccumulationRegister.POSSummary AS DocumentRegisterRecords
	|	WHERE
	|		DocumentRegisterRecords.Recorder = &Ref
	|		AND DocumentRegisterRecords.Period <= &ControlPeriod) AS POSSummaryBalances
	|
	|GROUP BY
	|	POSSummaryBalances.Company,
	|	POSSummaryBalances.StructuralUnit,
	|	POSSummaryBalances.Currency,
	|	POSSummaryBalances.GLAccount
	|
	|INDEX BY
	|	Company,
	|	StructuralUnit,
	|	Currency,
	|	GLAccount
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	1 AS LineNumber,
	|	&ControlPeriod AS Date,
	|	TablePOSSummary.Company AS Company,
	|	TablePOSSummary.StructuralUnit AS StructuralUnit,
	|	ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyExchangeRateCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRateCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) AS AmountOfExchangeDifferences,
	|	TablePOSSummary.Currency AS Currency,
	|	TablePOSSummary.GLAccount AS GLAccount
	|INTO TemporaryTableCurrencyExchangeRateDifferencesPOSSummary
	|FROM
	|	TemporaryTablePOSSummary AS TablePOSSummary
	|		LEFT JOIN TemporaryTableBalancesAfterPosting AS TableBalances
	|		ON TablePOSSummary.Company = TableBalances.Company
	|			AND TablePOSSummary.StructuralUnit = TableBalances.StructuralUnit
	|			AND TablePOSSummary.Currency = TableBalances.Currency
	|			AND TablePOSSummary.GLAccount = TableBalances.GLAccount
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(
	|				&PointInTime,
	|				Currency IN
	|					(SELECT
	|						ConstantAccountingCurrency.Value
	|					FROM
	|						Constant.PresentationCurrency AS ConstantAccountingCurrency)) AS AccountingExchangeRatesSliceLast
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(
	|				&PointInTime,
	|				Currency IN
	|					(SELECT DISTINCT
	|						TemporaryTablePOSSummary.Currency
	|					FROM
	|						TemporaryTablePOSSummary)) AS CurrencyExchangeRateCashSliceLast
	|		ON TablePOSSummary.Currency = CurrencyExchangeRateCashSliceLast.Currency
	|WHERE
	|	(ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyExchangeRateCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRateCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) >= 0.005
	|			OR ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyExchangeRateCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRateCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) <= -0.005)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	1 AS Ordering,
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.RecordType AS RecordType,
	|	DocumentTable.Date AS Period,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.StructuralUnit AS StructuralUnit,
	|	DocumentTable.Currency AS Currency,
	|	DocumentTable.Amount AS Amount,
	|	DocumentTable.AmountCur AS AmountCur,
	|	0 AS Cost,
	|	DocumentTable.ContentOfAccountingRecord AS ContentOfAccountingRecord,
	|	UNDEFINED AS SalesDocument,
	|	FALSE AS OfflineRecord
	|FROM
	|	TemporaryTablePOSSummary AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	DocumentTable.LineNumber,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN VALUE(AccumulationRecordType.Receipt)
	|		ELSE VALUE(AccumulationRecordType.Expense)
	|	END,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	DocumentTable.StructuralUnit,
	|	DocumentTable.Currency,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN DocumentTable.AmountOfExchangeDifferences
	|		ELSE -DocumentTable.AmountOfExchangeDifferences
	|	END,
	|	0,
	|	0,
	|	&ExchangeDifference,
	|	UNDEFINED,
	|	FALSE
	|FROM
	|	TemporaryTableCurrencyExchangeRateDifferencesPOSSummary AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	3,
	|	DocumentTable.LineNumber,
	|	VALUE(AccumulationRecordType.Expense),
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	DocumentTable.StructuralUnit,
	|	DocumentTable.Currency,
	|	0,
	|	0,
	|	DocumentTable.Cost,
	|	&Cost,
	|	&Ref,
	|	FALSE
	|FROM
	|	TemporaryTableCost AS DocumentTable
	|
	|ORDER BY
	|	Ordering,
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP TemporaryTableBalancesAfterPosting";
	
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TablePOSSummary", ResultsArray[2].Unload());
	
EndProcedure

Procedure GenerateTableVATOutput(DocumentRefCashReceipt, StructureAdditionalProperties)
	
	If StructureAdditionalProperties.AccountingPolicy.RegisteredForVAT
		AND DocumentRefCashReceipt.OperationKind = Enums.OperationTypesCashReceipt.FromCustomer Then
		
		PostAdvancePayments = StructureAdditionalProperties.AccountingPolicy.PostAdvancePaymentsBySourceDocuments;
		
		Query = New Query;
		Query.SetParameter("PostAdvancePayments", PostAdvancePayments);
		Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
		Query.Text =
		"SELECT
		|	Payment.Date AS Period,
		|	Payment.Company AS Company,
		|	Payment.Counterparty AS Customer,
		|	Payment.Ref AS ShipmentDocument,
		|	Payment.VATRate AS VATRate,
		|	VALUE(Enum.VATOperationTypes.AdvancePayment) AS OperationType,
		|	VALUE(Enum.ProductsTypes.EmptyRef) AS ProductType,
		|	SUM(Payment.AmountExcludesVAT) AS AmountExcludesVAT,
		|	SUM(Payment.VATAmount) AS VATAmount
		|FROM
		|	TemporaryTablePaymentDetails AS Payment
		|WHERE
		|	NOT Payment.VATRate.NotTaxable
		|	AND Payment.AdvanceFlag
		|	AND Payment.VATAmount > 0
		|	AND &PostAdvancePayments
		|
		|GROUP BY
		|	Payment.Date,
		|	Payment.Company,
		|	Payment.Counterparty,
		|	Payment.Ref,
		|	Payment.VATRate
		|
		|UNION ALL
		|
		|SELECT
		|	Payment.Date,
		|	Payment.Company,
		|	Payment.Counterparty,
		|	SalesInvoice.Ref,
		|	Payment.VATRate,
		|	VALUE(Enum.VATOperationTypes.DiscountAllowed),
		|	VALUE(Enum.ProductsTypes.EmptyRef),
		|	-SUM(Payment.AccountingEPDAmountExclVAT),
		|	-SUM(Payment.AccountingEPDAmount - Payment.AccountingEPDAmountExclVAT)
		|FROM
		|	TemporaryTablePaymentDetails AS Payment
		|		INNER JOIN Document.SalesInvoice AS SalesInvoice
		|		ON Payment.Document = SalesInvoice.Ref
		|			AND (SalesInvoice.ProvideEPD = VALUE(Enum.VariantsOfProvidingEPD.PaymentDocumentWithVATAdjustment))
		|		LEFT JOIN Catalog.VATRates AS VATRates
		|		ON (VATRates.Ref = Payment.VATRate)
		|WHERE
		|	NOT Payment.VATRate.NotTaxable
		|	AND NOT Payment.AdvanceFlag
		|	AND Payment.AccountingEPDAmount > 0
		|
		|GROUP BY
		|	Payment.Date,
		|	Payment.Company,
		|	Payment.Counterparty,
		|	SalesInvoice.Ref,
		|	Payment.VATRate";
		
		QueryResult = Query.Execute();
		
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableVATOutput", QueryResult.Unload());
		
	Else
		
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableVATOutput", New ValueTable);
		
	EndIf;
	
EndProcedure

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefCashReceipt, StructureAdditionalProperties) Export
	
	Query = New Query;
	
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefCashReceipt);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	
	Query.SetParameter("PresentationCurrency", Constants.PresentationCurrency.Get());
	Query.SetParameter("CashCurrency", DocumentRefCashReceipt.CashCurrency);
	Query.SetParameter("LoanContractCurrency", DocumentRefCashReceipt.LoanContract.SettlementsCurrency);

	MainLanguageCode = CommonUseClientServer.MainLanguageCode();
	Query.SetParameter("LoanPrincipalDebtPayment",	NStr("en = 'Loan principal debt payment'",
													MainLanguageCode));
	Query.SetParameter("LoanInterestPayment",		NStr("en = 'Loan interest payment'",
													MainLanguageCode));
	Query.SetParameter("LoanComissionPayment",		NStr("en = 'Loan comission payment'",
													MainLanguageCode));
	Query.Text =
	"SELECT
	|	ExchangeRatesSliceLast.Currency AS Currency,
	|	ExchangeRatesSliceLast.ExchangeRate AS ExchangeRate,
	|	ExchangeRatesSliceLast.Multiplicity AS Multiplicity
	|INTO TemporaryTableExchangeRatesSliceLatest
	|FROM
	|	InformationRegister.ExchangeRates.SliceLast(&PointInTime, Currency IN (&PresentationCurrency, &CashCurrency, &LoanContractCurrency)) AS ExchangeRatesSliceLast
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MAX(DocumentTable.LineNumber) AS LineNumber,
	|	DocumentTable.Ref.CashCurrency AS CashCurrency,
	|	DocumentTable.Document AS Document,
	|	DocumentTable.Ref.OperationKind AS OperationKind,
	|	DocumentTable.Ref.Counterparty AS Counterparty,
	|	DocumentTable.Ref.Counterparty.DoOperationsByContracts AS DoOperationsByContracts,
	|	DocumentTable.Ref.Counterparty.DoOperationsByDocuments AS DoOperationsByDocuments,
	|	DocumentTable.Ref.Counterparty.DoOperationsByOrders AS DoOperationsByOrders,
	|	DocumentTable.Contract AS Contract,
	|	DocumentTable.Contract.SettlementsCurrency AS SettlementsCurrency,
	|	DocumentTable.Ref.PettyCash AS PettyCash,
	|	DocumentTable.Ref.PettyCash.GLAccount AS BankAccountCashGLAccount,
	|	DocumentTable.Ref.Item AS Item,
	|	DocumentTable.Ref.Correspondence AS Correspondence,
	|	CASE
	|		WHEN DocumentTable.Order = UNDEFINED
	|				AND DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesCashReceipt.FromCustomer)
	|			THEN VALUE(Document.SalesOrder.EmptyRef)
	|		WHEN DocumentTable.Order = UNDEFINED
	|				AND DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesCashReceipt.FromVendor)
	|			THEN VALUE(Document.PurchaseOrder.EmptyRef)
	|		WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesCashReceipt.FromVendor)
	|				AND DocumentTable.Order = VALUE(Document.SalesOrder.EmptyRef)
	|			THEN VALUE(Document.PurchaseOrder.EmptyRef)
	|		WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesCashReceipt.FromCustomer)
	|				AND DocumentTable.Order = VALUE(Document.PurchaseOrder.EmptyRef)
	|			THEN VALUE(Document.SalesOrder.EmptyRef)
	|		ELSE DocumentTable.Order
	|	END AS Order,
	|	DocumentTable.AdvanceFlag AS AdvanceFlag,
	|	DocumentTable.Ref AS Ref,
	|	DocumentTable.Ref.Date AS Date,
	|	SUM(CAST(DocumentTable.PaymentAmount * ExchangeRatesOfPettyCashe.ExchangeRate * AccountingExchangeRates.Multiplicity / (AccountingExchangeRates.ExchangeRate * ExchangeRatesOfPettyCashe.Multiplicity) AS NUMBER(15, 2))) AS AccountingAmount,
	|	SUM(DocumentTable.SettlementsAmount) AS SettlementsAmount,
	|	SUM(DocumentTable.PaymentAmount) AS PaymentAmount,
	|	SUM(CAST(DocumentTable.EPDAmount * ExchangeRatesOfPettyCashe.ExchangeRate * AccountingExchangeRates.Multiplicity / (AccountingExchangeRates.ExchangeRate * ExchangeRatesOfPettyCashe.Multiplicity) AS NUMBER(15, 2))) AS AccountingEPDAmount,
	|	SUM(DocumentTable.SettlementsEPDAmount) AS SettlementsEPDAmount,
	|	SUM(DocumentTable.EPDAmount) AS EPDAmount,
	|	CASE
	|		WHEN VALUETYPE(DocumentTable.PlanningDocument) = TYPE(Document.CashInflowForecast)
	|				AND DocumentTable.PlanningDocument <> VALUE(Document.CashInflowForecast.EmptyRef)
	|			THEN DocumentTable.PlanningDocument
	|		WHEN VALUETYPE(DocumentTable.PlanningDocument) = TYPE(Document.CashTransferPlan)
	|				AND DocumentTable.PlanningDocument <> VALUE(Document.CashTransferPlan.EmptyRef)
	|			THEN DocumentTable.PlanningDocument
	|		WHEN DocumentTable.Order.SetPaymentTerms
	|			THEN DocumentTable.Order
	|		ELSE UNDEFINED
	|	END AS QuoteToPaymentCalendar,
	|	DocumentTable.Ref.Counterparty.GLAccountCustomerSettlements AS GLAccountCustomerSettlements,
	|	DocumentTable.Ref.Counterparty.CustomerAdvancesGLAccount AS CustomerAdvancesGLAccount,
	|	DocumentTable.Ref.Counterparty.GLAccountVendorSettlements AS GLAccountVendorSettlements,
	|	DocumentTable.Ref.Counterparty.VendorAdvancesGLAccount AS VendorAdvancesGLAccount,
	|	DocumentTable.Ref.LoanContract AS LoanContract,
	|	DocumentTable.TypeOfAmount AS TypeOfAmount,
	|	DocumentTable.Ref.AdvanceHolder AS Employee,
	|	CASE
	|		WHEN DocumentTable.TypeOfAmount = VALUE(Enum.LoanScheduleAmountTypes.Principal)
	|			THEN DocumentTable.Ref.LoanContract.GLAccount
	|		WHEN DocumentTable.TypeOfAmount = VALUE(Enum.LoanScheduleAmountTypes.Interest)
	|			THEN DocumentTable.Ref.LoanContract.InterestGLAccount
	|		WHEN DocumentTable.TypeOfAmount = VALUE(Enum.LoanScheduleAmountTypes.Commission)
	|			THEN DocumentTable.Ref.LoanContract.CommissionGLAccount
	|	END AS GLAccountByTypeOfAmount,
	|	CASE
	|		WHEN DocumentTable.TypeOfAmount = VALUE(Enum.LoanScheduleAmountTypes.Principal)
	|			THEN &LoanPrincipalDebtPayment
	|		WHEN DocumentTable.TypeOfAmount = VALUE(Enum.LoanScheduleAmountTypes.Interest)
	|			THEN &LoanInterestPayment
	|		WHEN DocumentTable.TypeOfAmount = VALUE(Enum.LoanScheduleAmountTypes.Commission)
	|			THEN &LoanComissionPayment
	|	END AS ContentByTypeOfAmount,
	|	DocumentTable.VATRate AS VATRate,
	|	SUM(DocumentTable.VATAmount * ExchangeRatesOfPettyCashe.ExchangeRate / AccountingExchangeRates.Multiplicity) AS VATAmount,
	|	SUM((DocumentTable.PaymentAmount - DocumentTable.VATAmount) * ExchangeRatesOfPettyCashe.ExchangeRate / AccountingExchangeRates.Multiplicity) AS AmountExcludesVAT,
	|	DocumentTable.Ref.Company AS Company
	|INTO TemporaryTablePaymentDetailsPre
	|FROM
	|	Document.CashReceipt.PaymentDetails AS DocumentTable
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS AccountingExchangeRates
	|		ON (AccountingExchangeRates.Currency = &PresentationCurrency)
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS ExchangeRatesOfPettyCashe
	|		ON (ExchangeRatesOfPettyCashe.Currency = &CashCurrency)
	|WHERE
	|	DocumentTable.Ref = &Ref
	|
	|GROUP BY
	|	DocumentTable.Ref.CashCurrency,
	|	DocumentTable.Document,
	|	DocumentTable.Ref.OperationKind,
	|	DocumentTable.Ref.Counterparty,
	|	DocumentTable.Contract,
	|	DocumentTable.Ref.PettyCash,
	|	DocumentTable.Ref.Item,
	|	CASE
	|		WHEN DocumentTable.Order = UNDEFINED
	|				AND DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesCashReceipt.FromCustomer)
	|			THEN VALUE(Document.SalesOrder.EmptyRef)
	|		WHEN DocumentTable.Order = UNDEFINED
	|				AND DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesCashReceipt.FromVendor)
	|			THEN VALUE(Document.PurchaseOrder.EmptyRef)
	|		WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesCashReceipt.FromVendor)
	|				AND DocumentTable.Order = VALUE(Document.SalesOrder.EmptyRef)
	|			THEN VALUE(Document.PurchaseOrder.EmptyRef)
	|		WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesCashReceipt.FromCustomer)
	|				AND DocumentTable.Order = VALUE(Document.PurchaseOrder.EmptyRef)
	|			THEN VALUE(Document.SalesOrder.EmptyRef)
	|		ELSE DocumentTable.Order
	|	END,
	|	DocumentTable.AdvanceFlag,
	|	DocumentTable.Ref,
	|	DocumentTable.Ref.Date,
	|	DocumentTable.Contract.SettlementsCurrency,
	|	DocumentTable.Ref.PettyCash.GLAccount,
	|	DocumentTable.Ref.Counterparty.GLAccountCustomerSettlements,
	|	DocumentTable.Ref.Counterparty.CustomerAdvancesGLAccount,
	|	DocumentTable.Ref.Counterparty.GLAccountVendorSettlements,
	|	DocumentTable.Ref.Counterparty.VendorAdvancesGLAccount,
	|	DocumentTable.Ref.Correspondence,
	|	DocumentTable.Ref.Counterparty.DoOperationsByContracts,
	|	DocumentTable.Ref.Counterparty.DoOperationsByDocuments,
	|	DocumentTable.Ref.Counterparty.DoOperationsByOrders,
	|	DocumentTable.Ref.LoanContract,
	|	DocumentTable.TypeOfAmount,
	|	DocumentTable.Ref.AdvanceHolder,
	|	CASE
	|		WHEN DocumentTable.TypeOfAmount = VALUE(Enum.LoanScheduleAmountTypes.Principal)
	|			THEN DocumentTable.Ref.LoanContract.GLAccount
	|		WHEN DocumentTable.TypeOfAmount = VALUE(Enum.LoanScheduleAmountTypes.Interest)
	|			THEN DocumentTable.Ref.LoanContract.InterestGLAccount
	|		WHEN DocumentTable.TypeOfAmount = VALUE(Enum.LoanScheduleAmountTypes.Commission)
	|			THEN DocumentTable.Ref.LoanContract.CommissionGLAccount
	|	END,
	|	CASE
	|		WHEN DocumentTable.TypeOfAmount = VALUE(Enum.LoanScheduleAmountTypes.Principal)
	|			THEN &LoanPrincipalDebtPayment
	|		WHEN DocumentTable.TypeOfAmount = VALUE(Enum.LoanScheduleAmountTypes.Interest)
	|			THEN &LoanInterestPayment
	|		WHEN DocumentTable.TypeOfAmount = VALUE(Enum.LoanScheduleAmountTypes.Commission)
	|			THEN &LoanComissionPayment
	|	END,
	|	DocumentTable.VATRate,
	|	DocumentTable.Ref.Company,
	|	CASE
	|		WHEN VALUETYPE(DocumentTable.PlanningDocument) = TYPE(Document.CashInflowForecast)
	|				AND DocumentTable.PlanningDocument <> VALUE(Document.CashInflowForecast.EmptyRef)
	|			THEN DocumentTable.PlanningDocument
	|		WHEN VALUETYPE(DocumentTable.PlanningDocument) = TYPE(Document.CashTransferPlan)
	|				AND DocumentTable.PlanningDocument <> VALUE(Document.CashTransferPlan.EmptyRef)
	|			THEN DocumentTable.PlanningDocument
	|		WHEN DocumentTable.Order.SetPaymentTerms
	|			THEN DocumentTable.Order
	|		ELSE UNDEFINED
	|	END
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TemporaryTable.LineNumber AS LineNumber,
	|	TemporaryTable.CashCurrency AS CashCurrency,
	|	TemporaryTable.Document AS Document,
	|	TemporaryTable.OperationKind AS OperationKind,
	|	TemporaryTable.Counterparty AS Counterparty,
	|	TemporaryTable.DoOperationsByContracts AS DoOperationsByContracts,
	|	TemporaryTable.DoOperationsByDocuments AS DoOperationsByDocuments,
	|	TemporaryTable.DoOperationsByOrders AS DoOperationsByOrders,
	|	TemporaryTable.Contract AS Contract,
	|	TemporaryTable.SettlementsCurrency AS SettlementsCurrency,
	|	TemporaryTable.PettyCash AS PettyCash,
	|	TemporaryTable.BankAccountCashGLAccount AS BankAccountCashGLAccount,
	|	TemporaryTable.Item AS Item,
	|	TemporaryTable.Correspondence AS Correspondence,
	|	TemporaryTable.Order AS Order,
	|	TemporaryTable.AdvanceFlag AS AdvanceFlag,
	|	TemporaryTable.Ref AS Ref,
	|	TemporaryTable.Date AS Date,
	|	TemporaryTable.AccountingAmount AS AccountingAmount,
	|	TemporaryTable.SettlementsAmount AS SettlementsAmount,
	|	TemporaryTable.PaymentAmount AS PaymentAmount,
	|	TemporaryTable.AccountingEPDAmount AS AccountingEPDAmount,
	|	TemporaryTable.SettlementsEPDAmount AS SettlementsEPDAmount,
	|	TemporaryTable.EPDAmount AS EPDAmount,
	|	CAST(TemporaryTable.AccountingEPDAmount / (ISNULL(VATRates.Rate, 0) + 100) * 100 AS NUMBER(15, 2)) AS AccountingEPDAmountExclVAT,
	|	CAST(TemporaryTable.SettlementsEPDAmount / (ISNULL(VATRates.Rate, 0) + 100) * 100 AS NUMBER(15, 2)) AS SettlementsEPDAmountExclVAT,
	|	CAST(TemporaryTable.EPDAmount / (ISNULL(VATRates.Rate, 0) + 100) * 100 AS NUMBER(15, 2)) AS EPDAmountExclVAT,
	|	TemporaryTable.QuoteToPaymentCalendar AS QuoteToPaymentCalendar,
	|	TemporaryTable.GLAccountCustomerSettlements AS GLAccountCustomerSettlements,
	|	TemporaryTable.CustomerAdvancesGLAccount AS CustomerAdvancesGLAccount,
	|	TemporaryTable.GLAccountVendorSettlements AS GLAccountVendorSettlements,
	|	TemporaryTable.VendorAdvancesGLAccount AS VendorAdvancesGLAccount,
	|	TemporaryTable.LoanContract AS LoanContract,
	|	TemporaryTable.TypeOfAmount AS TypeOfAmount,
	|	TemporaryTable.Employee AS Employee,
	|	TemporaryTable.GLAccountByTypeOfAmount AS GLAccountByTypeOfAmount,
	|	TemporaryTable.ContentByTypeOfAmount AS ContentByTypeOfAmount,
	|	TemporaryTable.VATRate AS VATRate,
	|	TemporaryTable.VATAmount AS VATAmount,
	|	TemporaryTable.AmountExcludesVAT AS AmountExcludesVAT,
	|	TemporaryTable.Company AS Company
	|INTO TemporaryTablePaymentDetails
	|FROM
	|	TemporaryTablePaymentDetailsPre AS TemporaryTable
	|		LEFT JOIN Catalog.VATRates AS VATRates
	|		ON TemporaryTable.VATRate = VATRates.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	1 AS LineNumber,
	|	DocumentTable.OperationKind AS OperationKind,
	|	DocumentTable.Date AS Date,
	|	&Company AS Company,
	|	DocumentTable.Item AS Item,
	|	DocumentTable.PettyCash AS PettyCash,
	|	DocumentTable.CashCR AS CashCR,
	|	DocumentTable.CashCurrency AS CashCurrency,
	|	CASE
	|		WHEN DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashReceipt.CurrencyPurchase)
	|			THEN DocumentTable.AccountingAmount
	|		ELSE CAST(DocumentTable.DocumentAmount * ExchangeRatesOfPettyCashe.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * ExchangeRatesOfPettyCashe.Multiplicity) AS NUMBER(15, 2))
	|	END AS Amount,
	|	DocumentTable.DocumentAmount AS AmountCur,
	|	DocumentTable.PettyCash.GLAccount AS PettyCashGLAccount,
	|	DocumentTable.CashCR.GLAccount AS CashCRGLAccount,
	|	DocumentTable.StructuralUnit AS StructuralUnit,
	|	DocumentTable.StructuralUnit.GLAccountInRetail AS StructuralUnitGLAccountInRetail,
	|	DocumentTable.StructuralUnit.MarkupGLAccount AS StructuralUnitGLAccountMarkup,
	|	DocumentTable.Department AS Department,
	|	DocumentTable.BusinessLine AS BusinessLine,
	|	DocumentTable.BusinessLine.GLAccountRevenueFromSales AS BusinessLineGLAccountOfRevenueFromSales,
	|	DocumentTable.BusinessLine.GLAccountCostOfSales AS BusinessLineGLAccountOfSalesCost,
	|	DocumentTable.Correspondence AS Correspondence,
	|	DocumentTable.Correspondence.TypeOfAccount AS CorrespondenceGLAccountType,
	|	DocumentTable.AdvanceHolder AS AdvanceHolder,
	|	DocumentTable.AdvanceHolder.AdvanceHoldersGLAccount AS AdvanceHolderAdvanceHoldersGLAccount,
	|	DocumentTable.Document AS Document
	|INTO TemporaryTableHeader
	|FROM
	|	Document.CashReceipt AS DocumentTable
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS AccountingExchangeRatesSliceLast
	|		ON (AccountingExchangeRatesSliceLast.Currency = &PresentationCurrency)
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS ExchangeRatesOfPettyCashe
	|		ON (ExchangeRatesOfPettyCashe.Currency = &CashCurrency)
	|WHERE
	|	DocumentTable.Ref = &Ref";
	
	Query.ExecuteBatch();
	
	// Register record table creation by account sections.
	GenerateTableCashAssets(DocumentRefCashReceipt, StructureAdditionalProperties);
	GenerateTableCashAssetsInCashRegisters(DocumentRefCashReceipt, StructureAdditionalProperties);
	GenerateAdvanceHoldersTable(DocumentRefCashReceipt, StructureAdditionalProperties);
	GenerateTableCustomerAccounts(DocumentRefCashReceipt, StructureAdditionalProperties);
	GenerateTableAccountsPayable(DocumentRefCashReceipt, StructureAdditionalProperties);
	// Miscellaneous payable
	GenerateTableMiscellaneousPayable(DocumentRefCashReceipt, StructureAdditionalProperties);
	GenerateTableLoanSettlements(DocumentRefCashReceipt, StructureAdditionalProperties);
	// End Miscellaneous payable
	GenerateTablePOSSummary(DocumentRefCashReceipt, StructureAdditionalProperties);
	GenerateTableIncomeAndExpenses(DocumentRefCashReceipt, StructureAdditionalProperties);
	GenerateTableUnallocatedExpenses(DocumentRefCashReceipt, StructureAdditionalProperties);
	GenerateTableIncomeAndExpensesRetained(DocumentRefCashReceipt, StructureAdditionalProperties);
	GenerateTableIncomeAndExpensesCashMethod(DocumentRefCashReceipt, StructureAdditionalProperties);
	GenerateTablePaymentCalendar(DocumentRefCashReceipt, StructureAdditionalProperties);
	GenerateTableInvoicesAndOrdersPayment(DocumentRefCashReceipt, StructureAdditionalProperties);
	GenerateTableAccountingJournalEntries(DocumentRefCashReceipt, StructureAdditionalProperties);
	GenerateTableVATOutput(DocumentRefCashReceipt, StructureAdditionalProperties);
	
EndProcedure

// Controls the occurrence of negative balances.
//
Procedure RunControl(DocumentRefCashReceipt, AdditionalProperties, Cancel, PostingDelete = False) Export
	
	If Not Constants.CheckStockBalanceOnPosting.Get() Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// If temporary tables contain records, it is
	// necessary to execute negative balance control.
	If StructureTemporaryTables.RegisterRecordsCashAssetsChange
	 OR StructureTemporaryTables.RegisterRecordsAdvanceHoldersChange
	 OR StructureTemporaryTables.RegisterRecordsAccountsReceivableChange
	 OR StructureTemporaryTables.RegisterRecordsPOSSummaryUpdate
	 OR StructureTemporaryTables.RegisterRecordsCashInCashRegistersChange Then
		
		Query = New Query(
		"SELECT
		|	RegisterRecordsCashAssetsChange.LineNumber AS LineNumber,
		|	RegisterRecordsCashAssetsChange.Company AS CompanyPresentation,
		|	RegisterRecordsCashAssetsChange.BankAccountPettyCash AS BankAccountCashPresentation,
		|	RegisterRecordsCashAssetsChange.Currency AS CurrencyPresentation,
		|	RegisterRecordsCashAssetsChange.CashAssetsType AS CashAssetsTypeRepresentation,
		|	RegisterRecordsCashAssetsChange.CashAssetsType AS CashAssetsType,
		|	ISNULL(CashAssetsBalances.AmountBalance, 0) AS AmountBalance,
		|	ISNULL(CashAssetsBalances.AmountCurBalance, 0) AS AmountCurBalance,
		|	RegisterRecordsCashAssetsChange.SumCurChange + ISNULL(CashAssetsBalances.AmountCurBalance, 0) AS BalanceCashAssets,
		|	RegisterRecordsCashAssetsChange.SumBeforeWrite AS SumBeforeWrite,
		|	RegisterRecordsCashAssetsChange.AmountOnWrite AS AmountOnWrite,
		|	RegisterRecordsCashAssetsChange.AmountChange AS AmountChange,
		|	RegisterRecordsCashAssetsChange.AmountCurBeforeWrite AS AmountCurBeforeWrite,
		|	RegisterRecordsCashAssetsChange.SumCurOnWrite AS SumCurOnWrite,
		|	RegisterRecordsCashAssetsChange.SumCurChange AS SumCurChange
		|FROM
		|	RegisterRecordsCashAssetsChange AS RegisterRecordsCashAssetsChange
		|		LEFT JOIN AccumulationRegister.CashAssets.Balance(&ControlTime, ) AS CashAssetsBalances
		|		ON RegisterRecordsCashAssetsChange.Company = CashAssetsBalances.Company
		|			AND RegisterRecordsCashAssetsChange.CashAssetsType = CashAssetsBalances.CashAssetsType
		|			AND RegisterRecordsCashAssetsChange.BankAccountPettyCash = CashAssetsBalances.BankAccountPettyCash
		|			AND RegisterRecordsCashAssetsChange.Currency = CashAssetsBalances.Currency
		|WHERE
		|	ISNULL(CashAssetsBalances.AmountCurBalance, 0) < 0
		|
		|ORDER BY
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	RegisterRecordsAdvanceHoldersChange.LineNumber AS LineNumber,
		|	RegisterRecordsAdvanceHoldersChange.Company AS CompanyPresentation,
		|	RegisterRecordsAdvanceHoldersChange.Employee AS EmployeePresentation,
		|	RegisterRecordsAdvanceHoldersChange.Currency AS CurrencyPresentation,
		|	RegisterRecordsAdvanceHoldersChange.Document AS DocumentPresentation,
		|	ISNULL(AdvanceHoldersBalances.AmountBalance, 0) AS AmountBalance,
		|	ISNULL(AdvanceHoldersBalances.AmountCurBalance, 0) AS AmountCurBalance,
		|	RegisterRecordsAdvanceHoldersChange.SumCurChange + ISNULL(AdvanceHoldersBalances.AmountCurBalance, 0) AS AccountablePersonBalance,
		|	RegisterRecordsAdvanceHoldersChange.SumBeforeWrite AS SumBeforeWrite,
		|	RegisterRecordsAdvanceHoldersChange.AmountOnWrite AS AmountOnWrite,
		|	RegisterRecordsAdvanceHoldersChange.AmountChange AS AmountChange,
		|	RegisterRecordsAdvanceHoldersChange.AmountCurBeforeWrite AS AmountCurBeforeWrite,
		|	RegisterRecordsAdvanceHoldersChange.SumCurOnWrite AS SumCurOnWrite,
		|	RegisterRecordsAdvanceHoldersChange.SumCurChange AS SumCurChange
		|FROM
		|	RegisterRecordsAdvanceHoldersChange AS RegisterRecordsAdvanceHoldersChange
		|		LEFT JOIN AccumulationRegister.AdvanceHolders.Balance(&ControlTime, ) AS AdvanceHoldersBalances
		|		ON RegisterRecordsAdvanceHoldersChange.Company = AdvanceHoldersBalances.Company
		|			AND RegisterRecordsAdvanceHoldersChange.Employee = AdvanceHoldersBalances.Employee
		|			AND RegisterRecordsAdvanceHoldersChange.Currency = AdvanceHoldersBalances.Currency
		|			AND RegisterRecordsAdvanceHoldersChange.Document = AdvanceHoldersBalances.Document
		|WHERE
		|	(VALUETYPE(AdvanceHoldersBalances.Document) = Type(Document.ExpenseReport)
		|				AND ISNULL(AdvanceHoldersBalances.AmountCurBalance, 0) > 0
		|			OR VALUETYPE(AdvanceHoldersBalances.Document) <> Type(Document.ExpenseReport)
		|				AND ISNULL(AdvanceHoldersBalances.AmountCurBalance, 0) < 0)
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
		|	TRUE AS RegisterRecordsOfCashDocuments,
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
		|		LEFT JOIN AccumulationRegister.AccountsReceivable.Balance(&ControlTime, ) AS AccountsReceivableBalances
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
		|	RegisterRecordsPOSSummaryUpdate.LineNumber AS LineNumber,
		|	RegisterRecordsPOSSummaryUpdate.Company AS CompanyPresentation,
		|	RegisterRecordsPOSSummaryUpdate.StructuralUnit AS StructuralUnitPresentation,
		|	RegisterRecordsPOSSummaryUpdate.StructuralUnit.RetailPriceKind.PriceCurrency AS CurrencyPresentation,
		|	ISNULL(POSSummaryBalances.AmountBalance, 0) AS AmountBalance,
		|	RegisterRecordsPOSSummaryUpdate.SumCurChange + ISNULL(POSSummaryBalances.AmountCurBalance, 0) AS BalanceInRetail,
		|	RegisterRecordsPOSSummaryUpdate.SumBeforeWrite AS SumBeforeWrite,
		|	RegisterRecordsPOSSummaryUpdate.AmountOnWrite AS AmountOnWrite,
		|	RegisterRecordsPOSSummaryUpdate.AmountChange AS AmountChange,
		|	RegisterRecordsPOSSummaryUpdate.AmountCurBeforeWrite AS AmountCurBeforeWrite,
		|	RegisterRecordsPOSSummaryUpdate.SumCurOnWrite AS SumCurOnWrite,
		|	RegisterRecordsPOSSummaryUpdate.SumCurChange AS SumCurChange,
		|	RegisterRecordsPOSSummaryUpdate.CostBeforeWrite AS CostBeforeWrite,
		|	RegisterRecordsPOSSummaryUpdate.CostOnWrite AS CostOnWrite,
		|	RegisterRecordsPOSSummaryUpdate.CostUpdate AS CostUpdate
		|FROM
		|	RegisterRecordsPOSSummaryUpdate AS RegisterRecordsPOSSummaryUpdate
		|		LEFT JOIN AccumulationRegister.POSSummary.Balance(&ControlTime, ) AS POSSummaryBalances
		|		ON RegisterRecordsPOSSummaryUpdate.Company = POSSummaryBalances.Company
		|			AND RegisterRecordsPOSSummaryUpdate.StructuralUnit = POSSummaryBalances.StructuralUnit
		|WHERE
		|	ISNULL(POSSummaryBalances.AmountCurBalance, 0) < 0
		|
		|ORDER BY
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	RegisterRecordsCashInCashRegistersChange.LineNumber AS LineNumber,
		|	RegisterRecordsCashInCashRegistersChange.Company AS CompanyPresentation,
		|	RegisterRecordsCashInCashRegistersChange.CashCR AS CashCRDescription,
		|	RegisterRecordsCashInCashRegistersChange.CashCR.CashCurrency AS CurrencyPresentation,
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
		|		LEFT JOIN AccumulationRegister.CashInCashRegisters.Balance(&ControlTime, ) AS CashAssetsInRetailCashesBalances
		|		ON RegisterRecordsCashInCashRegistersChange.Company = CashAssetsInRetailCashesBalances.Company
		|			AND RegisterRecordsCashInCashRegistersChange.CashCR = CashAssetsInRetailCashesBalances.CashCR
		|WHERE
		|	ISNULL(CashAssetsInRetailCashesBalances.AmountCurBalance, 0) < 0
		|
		|ORDER BY
		|	LineNumber");
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.SetParameter("ControlTime", AdditionalProperties.ForPosting.ControlTime);
		
		ResultsArray = Query.ExecuteBatch();
		
		If Not ResultsArray[0].IsEmpty()
			OR Not ResultsArray[1].IsEmpty()
			OR Not ResultsArray[2].IsEmpty()
			OR Not ResultsArray[3].IsEmpty()
			OR Not ResultsArray[4].IsEmpty() Then
			DocumentObjectCashReceipt = DocumentRefCashReceipt.GetObject()
		EndIf;
		
		// Negative balance on cash.
		If Not ResultsArray[0].IsEmpty() Then
			QueryResultSelection = ResultsArray[0].Select();
			DriveServer.ShowMessageAboutPostingToCashAssetsRegisterErrors(DocumentObjectCashReceipt, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance on advance holder payments.
		If Not ResultsArray[1].IsEmpty() Then
			QueryResultSelection = ResultsArray[1].Select();
			DriveServer.ShowMessageAboutPostingToAdvanceHoldersRegisterErrors(DocumentObjectCashReceipt, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance on accounts receivable.
		If Not ResultsArray[2].IsEmpty() Then
			QueryResultSelection = ResultsArray[2].Select();
			DriveServer.ShowMessageAboutPostingToAccountsReceivableRegisterErrors(DocumentObjectCashReceipt, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance according to the amount-based account in retail.
		If Not ResultsArray[3].IsEmpty() Then
			QueryResultSelection = ResultsArray[3].Select();
			DriveServer.ShowMessageAboutPostingToPOSSummaryRegisterErrors(DocumentObjectCashReceipt, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance in cash CR.
		If Not ResultsArray[4].IsEmpty() Then
			QueryResultSelection = ResultsArray[4].Select();
			DriveServer.ErrorMessageOfPostingOnRegisterOfCashAtCashRegisters(DocumentObjectCashReceipt, QueryResultSelection, Cancel);
		EndIf;
		
	EndIf;
	
EndProcedure

#Region PrintInterface

// Function generates document printing form by specified layout.
//
// Parameters:
// SpreadsheetDocument - TabularDocument in which
// 			   printing form will be displayed.
//  TemplateName    - String, printing form layout name.
//
Function PrintForm(ObjectsArray, PrintObjects)
	
	Var Errors;
	
	SpreadsheetDocument = New SpreadsheetDocument;
	SpreadsheetDocument.PrintParametersKey = "PrintParameters_CashReceipt";
	
	FirstDocument = True;
	
	For Each CurrentDocument In ObjectsArray Do
		
		If Not FirstDocument Then
			SpreadsheetDocument.PutHorizontalPageBreak();
		EndIf;
		
		FirstDocument = False;
		
		FirstLineNumber = SpreadsheetDocument.TableHeight + 1;
		
		Query = New Query();
		Query.SetParameter("CurrentDocument", CurrentDocument);
		
		Query.Text = 
		"SELECT
		|	CashReceipt.Ref AS Ref,
		|	CashReceipt.Number AS DocumentNumber,
		|	CashReceipt.Date AS DocumentDate,
		|	CashReceipt.Company AS Company,
		|	CashReceipt.Company.LegalEntityIndividual AS LegalEntityIndividual,
		|	CashReceipt.Company.Prefix AS Prefix,
		|	CashReceipt.Company.DescriptionFull AS CompanyPresentation,
		|	CashReceipt.CashCurrency AS CashCurrency,
		|	PRESENTATION(CashReceipt.CashCurrency) AS CurrencyPresentation,
		|	CashReceipt.AcceptedFrom AS AcceptedFrom,
		|	CashReceipt.Basis AS Basis,
		|	CashReceipt.DocumentAmount AS DocumentAmount,
		|	CASE
		|		WHEN CashReceipt.OperationKind = VALUE(Enum.OperationTypesCashReceipt.FromCustomer)
		|				OR CashReceipt.OperationKind = VALUE(Enum.OperationTypesCashReceipt.FromVendor)
		|				OR CashReceipt.OperationKind = VALUE(Enum.OperationTypesCashReceipt.OtherSettlements)
		|			THEN CashReceipt.Counterparty.DescriptionFull
		|		WHEN CashReceipt.OperationKind = VALUE(Enum.OperationTypesCashReceipt.FromAdvanceHolder)
		|			THEN CashReceipt.AdvanceHolder.Description
		|		ELSE CashReceipt.AcceptedFrom
		|	END AS Payer
		|FROM
		|	Document.CashReceipt AS CashReceipt
		|WHERE
		|	CashReceipt.Ref = &CurrentDocument";
		
		Header = Query.Execute().Select();
		Header.Next();
		
		SpreadsheetDocument.PrintParametersKey = "PRINT_PARAMETERS_CashReceipt_CashReceiptVoucher";
		Template = GetTemplate("PF_MXL_CashReceiptVoucher");
		
		If Template.Areas.Find("TitleWithLogo") <> Undefined
			AND Template.Areas.Find("TitleWithoutLogo") <> Undefined Then
			
			If ValueIsFilled(Header.Company.LogoFile) Then
				
				TemplateArea = Template.GetArea("TitleWithLogo");
				TemplateArea.Parameters.Fill(Header);
				
				PictureData = AttachedFiles.GetFileBinaryData(Header.Company.LogoFile);
				If ValueIsFilled(PictureData) Then
					
					TemplateArea.Drawings.Logo.Picture = New Picture(PictureData);
					
				EndIf;
				
			Else // If images are not selected, print regular header
				
				TemplateArea = Template.GetArea("TitleWithoutLogo");
				TemplateArea.Parameters.Fill(Header);
				
			EndIf;
			
			SpreadsheetDocument.Put(TemplateArea);
			
		Else
			
			MessageText = NStr("en = 'Maybe, custom template is being used. Default procedures of account printing may work incorrectly.'");
			CommonUseClientServer.AddUserError(Errors, , MessageText, Undefined);
			
		EndIf;
	
		InfoAboutCompany	= DriveServer.InfoAboutLegalEntityIndividual(Header.Company, Header.DocumentDate, ,);
		
		TemplateArea = Template.GetArea("HeaderRecipient");
		
		TemplateArea.Parameters.Fill(Header);
		
		RecipientPresentation	= DriveServer.CompaniesDescriptionFull(InfoAboutCompany, "FullDescr");
		
		TemplateArea.Parameters.RecipientPresentation	= RecipientPresentation;
		TemplateArea.Parameters.RecipientAddress		= DriveServer.CompaniesDescriptionFull(InfoAboutCompany, "LegalAddress");
		TemplateArea.Parameters.RecipientPhoneFax		= DriveServer.CompaniesDescriptionFull(InfoAboutCompany, "PhoneNumbers,Fax");
		TemplateArea.Parameters.RecipientEmail			= DriveServer.CompaniesDescriptionFull(InfoAboutCompany, "Email");
		
		SpreadsheetDocument.Put(TemplateArea);
		
		TemplateArea = Template.GetArea("HeaderPayer");
		
		TemplateArea.Parameters.Payer	= TrimAll(Header.Payer);
		If ValueIsFilled(Header.AcceptedFrom)
			AND TrimAll(Header.AcceptedFrom) <> TrimAll(Header.Payer) Then
		
			TemplateArea.Parameters.AcceptedFrom	= TrimAll(Header.AcceptedFrom);
		
		EndIf;
		
		SpreadsheetDocument.Put(TemplateArea);
		
		TemplateArea = Template.GetArea("PaymentBasis");
		TemplateArea.Parameters.Fill(Header);
		SpreadsheetDocument.Put(TemplateArea);
		
		TemplateArea = Template.GetArea("TotalAmount");
		TemplateArea.Parameters.Total	= Format(Header.DocumentAmount,"NFD=2") + " " + Header.CashCurrency;
		SpreadsheetDocument.Put(TemplateArea);
		
		TemplateArea = Template.GetArea("Footer");
		SpreadsheetDocument.Put(TemplateArea);
		
		PrintManagement.SetDocumentPrintArea(SpreadsheetDocument, FirstLineNumber, PrintObjects, Header.Ref);
	EndDo;
	
	SpreadsheetDocument.FitToPage = True;
	
	Return SpreadsheetDocument;
	
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
	
	Var Errors;
	
	If PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "CashReceiptVoucher") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection, "CashReceiptVoucher", 
		    NStr("en = 'Cash receipt'"), PrintForm(ObjectsArray, PrintObjects));
		
	ElsIf PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "AdvancePaymentInvoice") Then
		
		CashReceiptArray	= New Array;
		TaxInvoiceArray		= New Array;
		
		For Each PrintObject In ObjectsArray Do
			
			If NOT WorkWithVAT.GetPostAdvancePaymentsBySourceDocuments(PrintObject.Date, PrintObject.Company) Then
				
				TaxInvoice = Documents.TaxInvoiceIssued.GetTaxInvoiceIssued(PrintObject);
				If ValueIsFilled(TaxInvoice) Then
					
					TaxInvoiceArray.Add(TaxInvoice);
					
				Else
					
					PrintManagement.OutputSpreadsheetDocumentToCollection(
						PrintFormsCollection,
						"AdvancePaymentInvoice",
						NStr("en = 'Advance payment invoice'"), 
						New SpreadsheetDocument);
						
					MessageText = StringFunctionsClientServer.SubstituteParametersInString(
						NStr("en = 'Generate an ""Advance payment invoice"" based on the %1 before printing.'"),
						PrintObject);
					
					CommonUseClientServer.AddUserError(Errors,, MessageText, Undefined);
					
					Continue;
					
				EndIf;
				
			Else
				
				CashReceiptArray.Add(PrintObject);
				
			EndIf;
			
		EndDo;
		
		If CashReceiptArray.Count() > 0 Then
			
			SpreadsheetDocument = DataProcessors.PrintAdvancePaymentInvoice.PrintForm(
				CashReceiptArray,
				PrintObjects, 
				"AdvancePaymentInvoice");
			
		EndIf;
		
		If TaxInvoiceArray.Count() > 0 Then
			
			SpreadsheetDocument = DataProcessors.PrintAdvancePaymentInvoice.PrintForm(
				TaxInvoiceArray,
				PrintObjects, 
				"AdvancePaymentInvoice",
				SpreadsheetDocument);
			
		EndIf;
		
		If CashReceiptArray.Count() > 0 OR TaxInvoiceArray.Count() > 0 Then
			
			PrintManagement.OutputSpreadsheetDocumentToCollection(
				PrintFormsCollection,
				"AdvancePaymentInvoice",
				NStr("en = 'Advance payment invoice'"),
				SpreadsheetDocument);
			
		EndIf;
		
	EndIf;
	
	If Errors <> Undefined Then
		CommonUseClientServer.ShowErrorsToUser(Errors);
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
	PrintCommand.ID							= "CashReceiptVoucher";
	PrintCommand.Presentation				= NStr("en = 'Cash receipt'");
	PrintCommand.CheckPostingBeforePrint	= False;
	PrintCommand.Order						= 1;
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID							= "AdvancePaymentInvoice";
	PrintCommand.Presentation				= NStr("en = 'Advance payment invoice'");
	PrintCommand.CheckPostingBeforePrint	= False;
	PrintCommand.Order						= 2;
	
EndProcedure

#EndRegion

#Region OtherSettlements

Procedure GenerateTableMiscellaneousPayable(DocumentRefCashReceipt, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Company",						StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("AccountingForOtherOperations",	NStr("en = 'Miscellaneous receivables'",	Metadata.DefaultLanguage.LanguageCode));
	Query.SetParameter("Comment",						NStr("en = 'Payment from other accounts'", Metadata.DefaultLanguage.LanguageCode));
	Query.SetParameter("Ref",							DocumentRefCashReceipt);
	Query.SetParameter("PointInTime",					New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod",					StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("ExchangeRateDifference",		NStr("en = 'Foreign currency exchange gains and losses'", Metadata.DefaultLanguage.LanguageCode));
	
	Query.Text =
	"SELECT
	|	TemporaryTablePaymentDetails.LineNumber AS LineNumber,
	|	&Company AS Company,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TemporaryTablePaymentDetails.Counterparty AS Counterparty,
	|	TemporaryTablePaymentDetails.Contract AS Contract,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.DoOperationsByDocuments
	|			THEN CASE
	|					WHEN TemporaryTablePaymentDetails.Document = VALUE(Document.SalesOrder.EmptyRef)
	|							OR TemporaryTablePaymentDetails.Document = VALUE(Document.PurchaseOrder.EmptyRef)
	|							OR TemporaryTablePaymentDetails.Document = UNDEFINED
	|						THEN &Ref
	|					ELSE TemporaryTablePaymentDetails.Document
	|				END
	|		ELSE UNDEFINED
	|	END AS Document,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.DoOperationsByOrders
	|			THEN TemporaryTablePaymentDetails.Order
	|		ELSE VALUE(Document.SalesOrder.EmptyRef)
	|	END AS Order,
	|	TemporaryTablePaymentDetails.SettlementsCurrency AS Currency,
	|	TemporaryTableHeader.CashCurrency AS CashCurrency,
	|	TemporaryTablePaymentDetails.Date AS Date,
	|	SUM(TemporaryTablePaymentDetails.PaymentAmount) AS PaymentAmount,
	|	SUM(TemporaryTablePaymentDetails.AccountingAmount) AS Amount,
	|	SUM(TemporaryTablePaymentDetails.SettlementsAmount) AS AmountCur,
	|	SUM(TemporaryTablePaymentDetails.AccountingAmount) AS AmountForBalance,
	|	SUM(TemporaryTablePaymentDetails.SettlementsAmount) AS AmountCurForBalance,
	|	&AccountingForOtherOperations AS PostingContent,
	|	&Comment AS Comment,
	|	TemporaryTableHeader.Correspondence AS GLAccount,
	|	TemporaryTableHeader.PettyCash AS PettyCash,
	|	TemporaryTablePaymentDetails.Date AS Period
	|INTO TemporaryTableOtherSettlements
	|FROM
	|	TemporaryTablePaymentDetails AS TemporaryTablePaymentDetails
	|		INNER JOIN TemporaryTableHeader AS TemporaryTableHeader
	|		ON (TRUE)
	|WHERE
	|	TemporaryTablePaymentDetails.OperationKind = VALUE(Enum.OperationTypesCashReceipt.OtherSettlements)
	|
	|GROUP BY
	|	TemporaryTablePaymentDetails.LineNumber,
	|	TemporaryTablePaymentDetails.Counterparty,
	|	TemporaryTablePaymentDetails.Contract,
	|	TemporaryTablePaymentDetails.SettlementsCurrency,
	|	TemporaryTableHeader.CashCurrency,
	|	TemporaryTablePaymentDetails.Date,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.DoOperationsByDocuments
	|			THEN CASE
	|					WHEN TemporaryTablePaymentDetails.Document = VALUE(Document.SalesOrder.EmptyRef)
	|							OR TemporaryTablePaymentDetails.Document = VALUE(Document.PurchaseOrder.EmptyRef)
	|							OR TemporaryTablePaymentDetails.Document = UNDEFINED
	|						THEN &Ref
	|					ELSE TemporaryTablePaymentDetails.Document
	|				END
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.DoOperationsByOrders
	|			THEN TemporaryTablePaymentDetails.Order
	|		ELSE VALUE(Document.SalesOrder.EmptyRef)
	|	END,
	|	TemporaryTableHeader.Correspondence,
	|	TemporaryTableHeader.PettyCash,
	|	TemporaryTablePaymentDetails.Date";
	
	QueryResult = Query.Execute();
	
	Query.Text =
	"SELECT
	|	TemporaryTableOtherSettlements.GLAccount AS GLAccount,
	|	TemporaryTableOtherSettlements.Company AS Company,
	|	TemporaryTableOtherSettlements.Counterparty AS Counterparty,
	|	TemporaryTableOtherSettlements.Contract AS Contract
	|FROM
	|	TemporaryTableOtherSettlements AS TemporaryTableOtherSettlements";
	
	QueryResult = Query.Execute();
	
	DataLock 			= New DataLock;
	LockItem 			= DataLock.Add("AccumulationRegister.MiscellaneousPayable");
	LockItem.Mode 		= DataLockMode.Exclusive;
	LockItem.DataSource	= QueryResult;
	
	For Each QueryResultColumn In QueryResult.Columns Do
		LockItem.UseFromDataSource(QueryResultColumn.Name, QueryResultColumn.Name);
	EndDo;
	DataLock.Lock();
	
	QueryNumber = 0;
	
	Query.Text = DriveServer.GetQueryTextExchangeRateDifferencesAccountingForOtherOperations(Query.TempTablesManager, QueryNumber);
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableMiscellaneousPayable", ResultsArray[QueryNumber].Unload());
	
EndProcedure

Procedure GenerateTableLoanSettlements(DocumentRefCashReceipt, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Company",						StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("LoanSettlements",				NStr("en = 'Credit payment receipt'"));
	Query.SetParameter("Ref",							DocumentRefCashReceipt);
	Query.SetParameter("PointInTime",					New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod",					StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("ExchangeRateDifference",		NStr("en = 'Foreign currency exchange gains and losses'"));	
	Query.SetParameter("PresentationCurrency",			Constants.PresentationCurrency.Get());
	Query.SetParameter("CashCurrency",					DocumentRefCashReceipt.CashCurrency);
	
	Query.Text =
	"SELECT
	|	&Company AS Company,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	CASE
	|		WHEN CashReceipt.OperationKind = VALUE(Enum.OperationTypesCashReceipt.LoanSettlements)
	|			THEN VALUE(Enum.LoanContractTypes.Borrowed)
	|		ELSE VALUE(Enum.LoanContractTypes.EmployeeLoanAgreement)
	|	END AS LoanKind,
	|	CashReceipt.Date AS Date,
	|	CashReceipt.Date AS Period,
	|	&LoanSettlements AS PostingContent,
	|	CashReceipt.Counterparty AS Counterparty,
	|	CashReceipt.DocumentAmount AS PaymentAmount,
	|	CAST(CashReceipt.DocumentAmount * ExchangeRatesOfPettyCashe.ExchangeRate * ExchangeRatesOfContract.Multiplicity / (ExchangeRatesOfContract.ExchangeRate * ExchangeRatesOfPettyCashe.Multiplicity) AS NUMBER(15, 2)) AS PrincipalDebtCur,
	|	CAST(CashReceipt.DocumentAmount * ExchangeRatesOfPettyCashe.ExchangeRate * ExchangeRatesOfAccount.Multiplicity / (ExchangeRatesOfAccount.ExchangeRate * ExchangeRatesOfPettyCashe.Multiplicity) AS NUMBER(15, 2)) AS PrincipalDebt,
	|	CAST(CashReceipt.DocumentAmount * ExchangeRatesOfPettyCashe.ExchangeRate * ExchangeRatesOfContract.Multiplicity / (ExchangeRatesOfContract.ExchangeRate * ExchangeRatesOfPettyCashe.Multiplicity) AS NUMBER(15, 2)) AS PrincipalDebtCurForBalance,
	|	CAST(CashReceipt.DocumentAmount * ExchangeRatesOfPettyCashe.ExchangeRate * ExchangeRatesOfAccount.Multiplicity / (ExchangeRatesOfAccount.ExchangeRate * ExchangeRatesOfPettyCashe.Multiplicity) AS NUMBER(15, 2)) AS PrincipalDebtForBalance,
	|	0 AS InterestCur,
	|	0 AS Interest,
	|	0 AS InterestCurForBalance,
	|	0 AS InterestForBalance,
	|	0 AS CommissionCur,
	|	0 AS Commission,
	|	0 AS CommissionCurForBalance,
	|	0 AS CommissionForBalance,
	|	CAST(CashReceipt.DocumentAmount * ExchangeRatesOfPettyCashe.ExchangeRate * ExchangeRatesOfContract.Multiplicity / (ExchangeRatesOfContract.ExchangeRate * ExchangeRatesOfPettyCashe.Multiplicity) AS NUMBER(15, 2)) AS AmountCur,
	|	CAST(CashReceipt.DocumentAmount * ExchangeRatesOfPettyCashe.ExchangeRate * ExchangeRatesOfAccount.Multiplicity / (ExchangeRatesOfAccount.ExchangeRate * ExchangeRatesOfPettyCashe.Multiplicity) AS NUMBER(15, 2)) AS Amount,
	|	CashReceipt.LoanContract AS LoanContract,
	|	CashReceipt.LoanContract.SettlementsCurrency AS Currency,
	|	CashReceipt.CashCurrency AS CashCurrency,
	|	CashReceipt.LoanContract.GLAccount AS GLAccount,
	|	CashReceipt.PettyCash,
	|	FALSE AS DeductedFromSalary
	|INTO TemporaryTableLoanSettlements
	|FROM
	|	Document.CashReceipt AS CashReceipt
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS ExchangeRatesOfAccount
	|		ON (ExchangeRatesOfAccount.Currency = &PresentationCurrency)
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS ExchangeRatesOfPettyCashe
	|		ON (ExchangeRatesOfPettyCashe.Currency = &CashCurrency)
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS ExchangeRatesOfContract
	|		ON (ExchangeRatesOfContract.Currency = CashReceipt.LoanContract.SettlementsCurrency)
	|WHERE
	|	CashReceipt.OperationKind = VALUE(Enum.OperationTypesCashReceipt.LoanSettlements)
	|	AND CashReceipt.Ref = &Ref
	|
	|UNION ALL
	|
	|SELECT
	|	&Company,
	|	VALUE(AccumulationRecordType.Expense),
	|	CASE
	|		WHEN DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashReceipt.LoanSettlements)
	|			THEN VALUE(Enum.LoanContractTypes.Borrowed)
	|		ELSE VALUE(Enum.LoanContractTypes.EmployeeLoanAgreement)
	|	END,
	|	DocumentTable.Date,
	|	DocumentTable.Date,
	|	DocumentTable.ContentByTypeOfAmount,
	|	DocumentTable.Employee,
	|	DocumentTable.PaymentAmount,
	|	CASE
	|		WHEN DocumentTable.TypeOfAmount = VALUE(Enum.LoanScheduleAmountTypes.Principal)
	|			THEN DocumentTable.SettlementsAmount
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.TypeOfAmount = VALUE(Enum.LoanScheduleAmountTypes.Principal)
	|			THEN DocumentTable.AccountingAmount
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.TypeOfAmount = VALUE(Enum.LoanScheduleAmountTypes.Principal)
	|			THEN DocumentTable.SettlementsAmount
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.TypeOfAmount = VALUE(Enum.LoanScheduleAmountTypes.Principal)
	|			THEN DocumentTable.AccountingAmount
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.TypeOfAmount = VALUE(Enum.LoanScheduleAmountTypes.Interest)
	|			THEN DocumentTable.SettlementsAmount
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.TypeOfAmount = VALUE(Enum.LoanScheduleAmountTypes.Interest)
	|			THEN DocumentTable.AccountingAmount
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.TypeOfAmount = VALUE(Enum.LoanScheduleAmountTypes.Interest)
	|			THEN DocumentTable.SettlementsAmount
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.TypeOfAmount = VALUE(Enum.LoanScheduleAmountTypes.Interest)
	|			THEN DocumentTable.AccountingAmount
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.TypeOfAmount = VALUE(Enum.LoanScheduleAmountTypes.Commission)
	|			THEN DocumentTable.SettlementsAmount
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.TypeOfAmount = VALUE(Enum.LoanScheduleAmountTypes.Commission)
	|			THEN DocumentTable.AccountingAmount
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.TypeOfAmount = VALUE(Enum.LoanScheduleAmountTypes.Commission)
	|			THEN DocumentTable.SettlementsAmount
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.TypeOfAmount = VALUE(Enum.LoanScheduleAmountTypes.Commission)
	|			THEN DocumentTable.AccountingAmount
	|		ELSE 0
	|	END,
	|	DocumentTable.SettlementsAmount,
	|	DocumentTable.AccountingAmount,
	|	DocumentTable.LoanContract,
	|	DocumentTable.LoanContract.SettlementsCurrency,
	|	DocumentTable.CashCurrency,
	|	DocumentTable.GLAccountByTypeOfAmount,
	|	DocumentTable.PettyCash,
	|	FALSE
	|FROM
	|	TemporaryTablePaymentDetails AS DocumentTable
	|WHERE
	|	DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashReceipt.LoanRepaymentByEmployee)";
	
	QueryResult = Query.Execute();
	
	Query.Text =
	"SELECT
	|	TemporaryTableLoanSettlements.Company AS Company,
	|	TemporaryTableLoanSettlements.Counterparty AS Counterparty,
	|	TemporaryTableLoanSettlements.LoanContract AS LoanContract
	|FROM
	|	TemporaryTableLoanSettlements AS TemporaryTableLoanSettlements";
	
	QueryResult = Query.Execute();
	
	Locker = New DataLock;
	LockerItem = Locker.Add("AccumulationRegister.LoanSettlements");
	LockerItem.Mode = DataLockMode.Exclusive;
	LockerItem.DataSource = QueryResult;
	
	For Each QueryResultColumn In QueryResult.Columns Do
		LockerItem.UseFromDataSource(QueryResultColumn.Name, QueryResultColumn.Name);
	EndDo;
	Locker.Lock();
	
	QueryNumber = 0;
	
	Query.Text = DriveServer.GetQueryTextExchangeRateDifferencesLoanSettlements(Query.TempTablesManager, QueryNumber);
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableLoanSettlements", ResultsArray[QueryNumber].Unload());
	
EndProcedure

#EndRegion

#EndIf
