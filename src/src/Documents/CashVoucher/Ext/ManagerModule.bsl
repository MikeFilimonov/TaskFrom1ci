#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableCashAssets(DocumentRefCashVoucher, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();

	Query.SetParameter("Ref",					DocumentRefCashVoucher);
	Query.SetParameter("PointInTime",			New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod",			StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("Company",				StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("CashExpense",			NStr("en = 'Cash payment'", MainLanguageCode));
	Query.SetParameter("ExchangeDifference",	NStr("en = 'Foreign currency exchange gains and losses'", MainLanguageCode));
	
	Query.Text =
	"SELECT
	|	1 AS LineNumber,
	|	&CashExpense AS ContentOfAccountingRecord,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	DocumentTable.Date AS Date,
	|	DocumentTable.Company AS Company,
	|	VALUE(Enum.CashAssetTypes.Cash) AS CashAssetsType,
	|	DocumentTable.Item AS Item,
	|	DocumentTable.PettyCash AS BankAccountPettyCash,
	|	DocumentTable.CashCurrency AS Currency,
	|	SUM(DocumentTable.Amount) AS Amount,
	|	SUM(DocumentTable.AmountCur) AS AmountCur,
	|	-SUM(DocumentTable.Amount) AS AmountForBalance,
	|	-SUM(DocumentTable.AmountCur) AS AmountCurForBalance,
	|	DocumentTable.PettyCashGLAccount AS GLAccount
	|INTO TemporaryTableCashAssets
	|FROM
	|	TemporaryTableHeader AS DocumentTable
	|WHERE
	|	(DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashVoucher.ToAdvanceHolder)
	|			OR DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashVoucher.Other)
	|			OR DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashVoucher.OtherSettlements)
	|			OR DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashVoucher.LoanSettlements)
	|			OR DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashVoucher.IssueLoanToEmployee)
	|			OR DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashVoucher.TransferToCashCR)
	|			OR DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashVoucher.Taxes)
	|			OR DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashVoucher.SalaryForEmployee))
	|
	|GROUP BY
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	DocumentTable.Item,
	|	DocumentTable.PettyCash,
	|	DocumentTable.CashCurrency,
	|	DocumentTable.PettyCashGLAccount
	|
	|UNION ALL
	|
	|SELECT
	|	TemporaryTablePaymentDetails.LineNumber,
	|	&CashExpense,
	|	VALUE(AccumulationRecordType.Expense),
	|	TemporaryTablePaymentDetails.Date,
	|	&Company,
	|	VALUE(Enum.CashAssetTypes.Cash),
	|	TemporaryTablePaymentDetails.Item,
	|	TemporaryTablePaymentDetails.PettyCash,
	|	TemporaryTablePaymentDetails.CashCurrency,
	|	SUM(TemporaryTablePaymentDetails.AccountingAmount),
	|	SUM(TemporaryTablePaymentDetails.PaymentAmount),
	|	-SUM(TemporaryTablePaymentDetails.AccountingAmount),
	|	-SUM(TemporaryTablePaymentDetails.PaymentAmount),
	|	TemporaryTablePaymentDetails.BankAccountCashGLAccount
	|FROM
	|	TemporaryTablePaymentDetails AS TemporaryTablePaymentDetails
	|		LEFT JOIN Constants AS Constants
	|		ON (TRUE)
	|WHERE
	|	(TemporaryTablePaymentDetails.OperationKind = VALUE(Enum.OperationTypesCashVoucher.Vendor)
	|			OR TemporaryTablePaymentDetails.OperationKind = VALUE(Enum.OperationTypesCashVoucher.ToCustomer))
	|
	|GROUP BY
	|	TemporaryTablePaymentDetails.LineNumber,
	|	TemporaryTablePaymentDetails.Date,
	|	TemporaryTablePaymentDetails.Item,
	|	TemporaryTablePaymentDetails.PettyCash,
	|	TemporaryTablePaymentDetails.CashCurrency,
	|	TemporaryTablePaymentDetails.BankAccountCashGLAccount
	|
	|UNION ALL
	|
	|SELECT
	|	MAX(PayrollPayment.LineNumber),
	|	&CashExpense,
	|	VALUE(AccumulationRecordType.Expense),
	|	PayrollPayment.Ref.Date,
	|	&Company,
	|	VALUE(Enum.CashAssetTypes.Cash),
	|	PayrollPayment.Ref.Item,
	|	PayrollPayment.Ref.PettyCash,
	|	PayrollPayment.Ref.CashCurrency,
	|	SUM(CAST(PayrollSheetEmployees.PaymentAmount * ExchangeRatesOfPettyCashe.ExchangeRate * AccountingExchangeRates.Multiplicity / (AccountingExchangeRates.ExchangeRate * ExchangeRatesOfPettyCashe.Multiplicity) AS NUMBER(15, 2))),
	|	MIN(PayrollPayment.Ref.DocumentAmount),
	|	-SUM(CAST(PayrollSheetEmployees.PaymentAmount * ExchangeRatesOfPettyCashe.ExchangeRate * AccountingExchangeRates.Multiplicity / (AccountingExchangeRates.ExchangeRate * ExchangeRatesOfPettyCashe.Multiplicity) AS NUMBER(15, 2))),
	|	-MIN(PayrollPayment.Ref.DocumentAmount),
	|	PayrollPayment.Ref.PettyCash.GLAccount
	|FROM
	|	Document.PayrollSheet.Employees AS PayrollSheetEmployees
	|		INNER JOIN Document.CashVoucher.PayrollPayment AS PayrollPayment
	|			LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&PointInTime, ) AS ExchangeRatesOfPettyCashe
	|			ON PayrollPayment.Ref.CashCurrency = ExchangeRatesOfPettyCashe.Currency
	|		ON PayrollSheetEmployees.Ref = PayrollPayment.Statement
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(
	|				&PointInTime,
	|				Currency In
	|					(SELECT
	|						Constants.PresentationCurrency
	|					FROM
	|						Constants AS Constants)) AS AccountingExchangeRates
	|		ON (TRUE)
	|		LEFT JOIN Constants AS Constants
	|		ON (TRUE)
	|WHERE
	|	PayrollPayment.Ref = &Ref
	|	AND PayrollPayment.Ref.OperationKind = VALUE(Enum.OperationTypesCashVoucher.Salary)
	|
	|GROUP BY
	|	PayrollPayment.Ref.Date,
	|	PayrollPayment.Ref.Item,
	|	PayrollPayment.Ref.PettyCash,
	|	PayrollPayment.Ref.CashCurrency,
	|	PayrollPayment.Ref.PettyCash.GLAccount
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
	|	TemporaryTableCashAssets AS TemporaryTableCashAssets";
	
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
Procedure GenerateTableCashAssetsInCashRegisters(DocumentRefCashVoucher, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	
	"SELECT
	|	1 AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	DocumentTable.Date AS Date,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.CashCR AS CashCR,
	|	DocumentTable.CashCurrency AS Currency,
	|	SUM(DocumentTable.Amount) AS Amount,
	|	SUM(DocumentTable.AmountCur) AS AmountCur,
	|	SUM(DocumentTable.Amount) AS AmountForBalance,
	|	SUM(DocumentTable.AmountCur) AS AmountCurForBalance,
	|	DocumentTable.CashCRGLAccount AS GLAccount,
	|	&CashFundsReceipt AS ContentOfAccountingRecord
	|INTO TemporaryTableCashAssetsInRetailCashes
	|FROM
	|	TemporaryTableHeader AS DocumentTable
	|WHERE
	|	DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashVoucher.TransferToCashCR)
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
	Query.SetParameter("Ref",					DocumentRefCashVoucher);
	Query.SetParameter("PointInTime",			New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod",			StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("CashFundsReceipt",		NStr("en = 'Cash transfer to cash register'", MainLanguageCode));
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
Procedure GenerateAdvanceHoldersTable(DocumentRefCashVoucher, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();

	Query.SetParameter("Ref",							DocumentRefCashVoucher);
	Query.SetParameter("PointInTime",					New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod",					StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("Company",						StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("AdvanceHolderDebtEmergence",	NStr("en = 'Payment to advance holder'", MainLanguageCode));
	Query.SetParameter("ExchangeDifference",			NStr("en = 'Foreign currency exchange gains and losses'", MainLanguageCode));
	
	Query.Text =
	"SELECT
	|	1 AS LineNumber,
	|	&AdvanceHolderDebtEmergence AS ContentOfAccountingRecord,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	DocumentTable.PettyCash AS PettyCash,
	|	CASE
	|		WHEN DocumentTable.Document = VALUE(Document.ExpenseReport.EmptyRef)
	|			THEN &Ref
	|		ELSE DocumentTable.Document
	|	END AS Document,
	|	DocumentTable.AdvanceHolder AS Employee,
	|	DocumentTable.Date AS Date,
	|	&Company AS Company,
	|	DocumentTable.CashCurrency AS Currency,
	|	SUM(DocumentTable.Amount) AS Amount,
	|	SUM(DocumentTable.AmountCur) AS AmountCur,
	|	SUM(DocumentTable.Amount) AS AmountForBalance,
	|	SUM(DocumentTable.AmountCur) AS AmountCurForBalance,
	|	CASE
	|		WHEN DocumentTable.Document = VALUE(Document.ExpenseReport.EmptyRef)
	|			THEN DocumentTable.AdvanceHolder.AdvanceHoldersGLAccount
	|		ELSE DocumentTable.AdvanceHolder.OverrunGLAccount
	|	END AS GLAccount
	|INTO TemporaryTableAdvanceHolders
	|FROM
	|	TemporaryTableHeader AS DocumentTable
	|WHERE
	|	DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashVoucher.ToAdvanceHolder)
	|
	|GROUP BY
	|	DocumentTable.PettyCash,
	|	DocumentTable.AdvanceHolder,
	|	DocumentTable.Date,
	|	DocumentTable.CashCurrency,
	|	CASE
	|		WHEN DocumentTable.Document = VALUE(Document.ExpenseReport.EmptyRef)
	|			THEN &Ref
	|		ELSE DocumentTable.Document
	|	END,
	|	CASE
	|		WHEN DocumentTable.Document = VALUE(Document.ExpenseReport.EmptyRef)
	|			THEN DocumentTable.AdvanceHolder.AdvanceHoldersGLAccount
	|		ELSE DocumentTable.AdvanceHolder.OverrunGLAccount
	|	END
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
	|	TemporaryTableAdvanceHolders AS TemporaryTableAdvanceHolders";
	
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
Procedure GenerateTableAccountsPayable(DocumentRefCashVoucher, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();

	Query.SetParameter("Ref",							DocumentRefCashVoucher);
	Query.SetParameter("PointInTime",					New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod",					StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("Company",						StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("AppearenceOfVendorAdvance",		NStr("en = 'Advance payment to supplier'", MainLanguageCode));
	Query.SetParameter("VendorObligationsRepayment",	NStr("en = 'Payment to supplier'", MainLanguageCode));
	Query.SetParameter("ExchangeDifference",			NStr("en = 'Foreign currency exchange gains and losses'", MainLanguageCode));
	Query.SetParameter("EarlyPaymentDiscount",			NStr("en = 'Early payment discount'", MainLanguageCode));
	
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
	|		ELSE VALUE(Document.PurchaseOrder.EmptyRef)
	|	END AS Order,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.AdvanceFlag
	|			THEN VALUE(Enum.SettlementsTypes.Advance)
	|		ELSE VALUE(Enum.SettlementsTypes.Debt)
	|	END AS SettlementsType,
	|	TemporaryTablePaymentDetails.Date AS Date,
	|	SUM(TemporaryTablePaymentDetails.PaymentAmount) AS PaymentAmount,
	|	SUM(TemporaryTablePaymentDetails.AccountingAmount) AS Amount,
	|	SUM(TemporaryTablePaymentDetails.SettlementsAmount) AS AmountCur,
	|	-SUM(TemporaryTablePaymentDetails.AccountingAmount) AS AmountForBalance,
	|	-SUM(TemporaryTablePaymentDetails.SettlementsAmount) AS AmountCurForBalance,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.AdvanceFlag
	|			THEN TemporaryTablePaymentDetails.VendorAdvancesGLAccount
	|		ELSE TemporaryTablePaymentDetails.GLAccountVendorSettlements
	|	END AS GLAccount,
	|	TemporaryTablePaymentDetails.SettlementsCurrency AS Currency,
	|	TemporaryTablePaymentDetails.CashCurrency AS CashCurrency,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.AdvanceFlag
	|			THEN &AppearenceOfVendorAdvance
	|		ELSE &VendorObligationsRepayment
	|	END AS ContentOfAccountingRecord,
	|	SUM(TemporaryTablePaymentDetails.AccountingAmount) AS AmountForPayment,
	|	SUM(TemporaryTablePaymentDetails.SettlementsAmount) AS AmountForPaymentCur
	|INTO TemporaryTableAccountsPayable
	|FROM
	|	TemporaryTablePaymentDetails AS TemporaryTablePaymentDetails
	|WHERE
	|	TemporaryTablePaymentDetails.OperationKind = VALUE(Enum.OperationTypesCashVoucher.Vendor)
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
	|			THEN &AppearenceOfVendorAdvance
	|		ELSE &VendorObligationsRepayment
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
	|		ELSE VALUE(Document.PurchaseOrder.EmptyRef)
	|	END,
	|	VALUE(Enum.SettlementsTypes.Debt),
	|	TemporaryTablePaymentDetails.Date,
	|	-SUM(TemporaryTablePaymentDetails.EPDAmount),
	|	-SUM(TemporaryTablePaymentDetails.AccountingEPDAmount),
	|	-SUM(TemporaryTablePaymentDetails.SettlementsEPDAmount),
	|	SUM(TemporaryTablePaymentDetails.AccountingEPDAmount),
	|	SUM(TemporaryTablePaymentDetails.SettlementsEPDAmount),
	|	TemporaryTablePaymentDetails.GLAccountVendorSettlements,
	|	TemporaryTablePaymentDetails.SettlementsCurrency,
	|	TemporaryTablePaymentDetails.CashCurrency,
	|	&EarlyPaymentDiscount,
	|	-SUM(TemporaryTablePaymentDetails.AccountingEPDAmount),
	|	-SUM(TemporaryTablePaymentDetails.SettlementsEPDAmount)
	|FROM
	|	TemporaryTablePaymentDetails AS TemporaryTablePaymentDetails
	|		INNER JOIN Document.SupplierInvoice AS SupplierInvoice
	|		ON TemporaryTablePaymentDetails.Document = SupplierInvoice.Ref
	|WHERE
	|	TemporaryTablePaymentDetails.OperationKind = VALUE(Enum.OperationTypesCashVoucher.Vendor)
	|	AND TemporaryTablePaymentDetails.DoOperationsByDocuments
	|	AND NOT TemporaryTablePaymentDetails.AdvanceFlag
	|	AND TemporaryTablePaymentDetails.EPDAmount > 0
	|	AND (SupplierInvoice.ProvideEPD = VALUE(Enum.VariantsOfProvidingEPD.PaymentDocument)
	|			OR SupplierInvoice.ProvideEPD = VALUE(Enum.VariantsOfProvidingEPD.PaymentDocumentWithVATAdjustment))
	|
	|GROUP BY
	|	TemporaryTablePaymentDetails.LineNumber,
	|	TemporaryTablePaymentDetails.PettyCash,
	|	TemporaryTablePaymentDetails.Counterparty,
	|	TemporaryTablePaymentDetails.Contract,
	|	TemporaryTablePaymentDetails.Date,
	|	TemporaryTablePaymentDetails.SettlementsCurrency,
	|	TemporaryTablePaymentDetails.CashCurrency,
	|	TemporaryTablePaymentDetails.Document,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.DoOperationsByOrders
	|			THEN TemporaryTablePaymentDetails.Order
	|		ELSE VALUE(Document.PurchaseOrder.EmptyRef)
	|	END,
	|	TemporaryTablePaymentDetails.GLAccountVendorSettlements
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
Procedure GenerateTableCustomerAccounts(DocumentRefCashVoucher, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();

	Query.SetParameter("Ref",							DocumentRefCashVoucher);
	Query.SetParameter("PointInTime",					New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod",					StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("Company",						StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("CustomerAdvanceRepayment",		NStr("en = 'Refund to customer'", MainLanguageCode));
	Query.SetParameter("AppearenceOfCustomerLiability",	NStr("en = 'Payment to customer'", MainLanguageCode));
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
	|			AND TemporaryTablePaymentDetails.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|			AND TemporaryTablePaymentDetails.Order <> VALUE(Document.WorkOrder.EmptyRef)
	|			THEN TemporaryTablePaymentDetails.Order
	|		ELSE UNDEFINED
	|	END AS Order,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.AdvanceFlag
	|			THEN VALUE(Enum.SettlementsTypes.Advance)
	|		ELSE VALUE(Enum.SettlementsTypes.Debt)
	|	END AS SettlementsType,
	|	TemporaryTablePaymentDetails.Date AS Date,
	|	SUM(TemporaryTablePaymentDetails.PaymentAmount) AS PaymentAmount,
	|	SUM(TemporaryTablePaymentDetails.AccountingAmount) AS Amount,
	|	SUM(TemporaryTablePaymentDetails.SettlementsAmount) AS AmountCur,
	|	SUM(TemporaryTablePaymentDetails.AccountingAmount) AS AmountForBalance,
	|	SUM(TemporaryTablePaymentDetails.SettlementsAmount) AS AmountCurForBalance,
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
	|			THEN &CustomerAdvanceRepayment
	|		ELSE &AppearenceOfCustomerLiability
	|	END AS ContentOfAccountingRecord
	|INTO TemporaryTableAccountsReceivable
	|FROM
	|	TemporaryTablePaymentDetails AS TemporaryTablePaymentDetails
	|WHERE
	|	TemporaryTablePaymentDetails.OperationKind = VALUE(Enum.OperationTypesCashVoucher.ToCustomer)
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
	|			AND TemporaryTablePaymentDetails.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|			AND TemporaryTablePaymentDetails.Order <> VALUE(Document.WorkOrder.EmptyRef)
	|			THEN TemporaryTablePaymentDetails.Order
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
	|			THEN &CustomerAdvanceRepayment
	|		ELSE &AppearenceOfCustomerLiability
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
Procedure GenerateTablePayroll(DocumentRefCashVoucher, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();

	Query.SetParameter("Ref",								DocumentRefCashVoucher);
	Query.SetParameter("PointInTime",						New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod",						StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("Company",							StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("RepaymentLiabilitiesToEmployees",	NStr("en = 'Payroll payment'", MainLanguageCode));
	Query.SetParameter("ExchangeDifference",				NStr("en = 'Foreign currency exchange gains and losses'", MainLanguageCode));
	
	Query.Text =
	"SELECT
	|	PayrollSheet.Ref
	|FROM
	|	Document.PayrollSheet AS PayrollSheet
	|WHERE
	|	PayrollSheet.Ref In
	|			(SELECT
	|				PayrollPayment.Statement
	|			FROM
	|				Document.CashVoucher.PayrollPayment AS PayrollPayment
	|			WHERE
	|				PayrollPayment.Ref = &Ref
	|				AND PayrollPayment.Ref.OperationKind = VALUE(Enum.OperationTypesCashVoucher.Salary))";
	
	QueryResult = Query.Execute();
	
	Block = New DataLock;
	LockItem = Block.Add("Document.PayrollSheet");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;
	
	For Each ColumnQueryResult In QueryResult.Columns Do
		LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
	EndDo;
	Block.Lock();
	
	Query.Text =
	"SELECT
	|	MAX(PayrollPayment.LineNumber) AS LineNumber,
	|	&Company AS Company,
	|	PayrollPayment.Ref.Date AS Date,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	PayrollSheetEmployees.Ref.StructuralUnit AS StructuralUnit,
	|	PayrollSheetEmployees.Employee AS Employee,
	|	PayrollSheetEmployees.Ref.SettlementsCurrency AS Currency,
	|	PayrollSheetEmployees.Ref.RegistrationPeriod AS RegistrationPeriod,
	|	SUM(CAST(PayrollSheetEmployees.PaymentAmount * ExchangeRatesOfPettyCashe.ExchangeRate * AccountingExchangeRates.Multiplicity / (AccountingExchangeRates.ExchangeRate * ExchangeRatesOfPettyCashe.Multiplicity) AS NUMBER(15, 2))) AS Amount,
	|	SUM(PayrollSheetEmployees.SettlementsAmount) AS AmountCur,
	|	-SUM(CAST(PayrollSheetEmployees.PaymentAmount * ExchangeRatesOfPettyCashe.ExchangeRate * AccountingExchangeRates.Multiplicity / (AccountingExchangeRates.ExchangeRate * ExchangeRatesOfPettyCashe.Multiplicity) AS NUMBER(15, 2))) AS AmountForBalance,
	|	-SUM(PayrollSheetEmployees.SettlementsAmount) AS AmountCurForBalance,
	|	PayrollSheetEmployees.Employee.SettlementsHumanResourcesGLAccount AS GLAccount,
	|	&RepaymentLiabilitiesToEmployees AS ContentOfAccountingRecord,
	|	PayrollPayment.Ref.PettyCash.GLAccount AS PettyCashGLAccount
	|INTO TemporaryTablePayroll
	|FROM
	|	Document.PayrollSheet.Employees AS PayrollSheetEmployees
	|		INNER JOIN Document.CashVoucher.PayrollPayment AS PayrollPayment
	|			LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&PointInTime, ) AS ExchangeRatesOfPettyCashe
	|			ON PayrollPayment.Ref.CashCurrency = ExchangeRatesOfPettyCashe.Currency
	|		ON PayrollSheetEmployees.Ref = PayrollPayment.Statement
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(
	|				&PointInTime,
	|				Currency In
	|					(SELECT
	|						Constants.PresentationCurrency
	|					FROM
	|						Constants AS Constants)) AS AccountingExchangeRates
	|		ON (TRUE)
	|WHERE
	|	PayrollPayment.Ref = &Ref
	|	AND PayrollPayment.Ref.OperationKind = VALUE(Enum.OperationTypesCashVoucher.Salary)
	|
	|GROUP BY
	|	PayrollPayment.Ref.Date,
	|	PayrollSheetEmployees.Ref.StructuralUnit,
	|	PayrollSheetEmployees.Employee,
	|	PayrollSheetEmployees.Ref.SettlementsCurrency,
	|	PayrollSheetEmployees.Ref.RegistrationPeriod,
	|	PayrollSheetEmployees.Employee.SettlementsHumanResourcesGLAccount,
	|	PayrollPayment.Ref.PettyCash,
	|	PayrollPayment.Ref.PettyCash.GLAccount
	|
	|UNION ALL
	|
	|SELECT
	|	1,
	|	&Company,
	|	DocumentTable.Date,
	|	VALUE(AccumulationRecordType.Expense),
	|	DocumentTable.Department,
	|	DocumentTable.AdvanceHolder,
	|	DocumentTable.CashCurrency,
	|	DocumentTable.RegistrationPeriod,
	|	SUM(DocumentTable.Amount),
	|	SUM(DocumentTable.AmountCur),
	|	-SUM(DocumentTable.Amount),
	|	-SUM(DocumentTable.AmountCur),
	|	DocumentTable.AdvanceHolderPersonnelGLAccount,
	|	&RepaymentLiabilitiesToEmployees,
	|	DocumentTable.PettyCashGLAccount
	|FROM
	|	TemporaryTableHeader AS DocumentTable
	|WHERE
	|	DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashVoucher.SalaryForEmployee)
	|
	|GROUP BY
	|	DocumentTable.Date,
	|	DocumentTable.Department,
	|	DocumentTable.AdvanceHolder,
	|	DocumentTable.CashCurrency,
	|	DocumentTable.RegistrationPeriod,
	|	DocumentTable.AdvanceHolderPersonnelGLAccount,
	|	DocumentTable.PettyCashGLAccount
	|
	|INDEX BY
	|	Company,
	|	StructuralUnit,
	|	Employee,
	|	Currency,
	|	RegistrationPeriod,
	|	GLAccount";
	
	Query.Execute();
	
	// Setting the exclusive lock for the controlled balances of salary payable.
	Query.Text =
	"SELECT
	|	TemporaryTablePayroll.Company AS Company,
	|	TemporaryTablePayroll.StructuralUnit AS StructuralUnit,
	|	TemporaryTablePayroll.Employee AS Employee,
	|	TemporaryTablePayroll.Currency AS Currency,
	|	TemporaryTablePayroll.RegistrationPeriod AS RegistrationPeriod
	|FROM
	|	TemporaryTablePayroll AS TemporaryTablePayroll";
	
	QueryResult = Query.Execute();
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.Payroll");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;
	
	For Each ColumnQueryResult In QueryResult.Columns Do
		LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
	EndDo;
	Block.Lock();
	
	QueryNumber = 0;
	Query.Text = DriveServer.GetQueryTextExchangeRateDifferencesPayroll(Query.TempTablesManager, QueryNumber);
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TablePayroll", ResultsArray[QueryNumber].Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableIncomeAndExpenses(DocumentRefCashVoucher, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();

	Query.SetParameter("Ref",							DocumentRefCashVoucher);
	Query.SetParameter("Company",						StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PointInTime",					New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("CostsReflection",				NStr("en = 'Expenses incurred'", MainLanguageCode));
	Query.SetParameter("ExchangeDifference",			NStr("en = 'Foreign currency exchange gains and losses'", MainLanguageCode));
	Query.SetParameter("EarlyPaymentDiscount",			NStr("en = 'Early payment discount'", MainLanguageCode));
	Query.SetParameter("ForeignCurrencyExchangeGain",	Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeGain")); 
	Query.SetParameter("ForeignCurrencyExchangeLoss",	Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeLoss"));
	
	Query.Text =
	"SELECT
	|	1 AS Order,
	|	2 AS LineNumber,
	|	DocumentTable.Date AS Period,
	|	&Company AS Company,
	|	CASE
	|		WHEN DocumentTable.CorrespondenceGLAccountType = VALUE(Enum.GLAccountsTypes.Expenses)
	|			THEN DocumentTable.Department
	|		ELSE UNDEFINED
	|	END AS StructuralUnit,
	|	CASE
	|		WHEN DocumentTable.CorrespondenceGLAccountType = VALUE(Enum.GLAccountsTypes.Expenses)
	|				AND DocumentTable.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|				AND DocumentTable.Order <> VALUE(Document.WorkOrder.EmptyRef)
	|			THEN DocumentTable.Order
	|		ELSE UNDEFINED
	|	END AS SalesOrder,
	|	CASE
	|		WHEN DocumentTable.CorrespondenceGLAccountType = VALUE(Enum.GLAccountsTypes.Expenses)
	|			THEN DocumentTable.BusinessLine
	|		ELSE VALUE(Catalog.LinesOfBusiness.Other)
	|	END AS BusinessLine,
	|	DocumentTable.Correspondence AS GLAccount,
	|	&CostsReflection AS ContentOfAccountingRecord,
	|	0 AS AmountIncome,
	|	DocumentTable.Amount AS AmountExpense,
	|	FALSE AS OfflineRecord
	|FROM
	|	TemporaryTableHeader AS DocumentTable
	|WHERE
	|	(DocumentTable.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.Expenses)
	|			OR DocumentTable.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherExpenses))
	|	AND (DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashVoucher.Other)
	|			OR DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashVoucher.OtherSettlements))
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
	|	TemporaryTableExchangeDifferencesCalculationWithAdvanceHolder AS DocumentTable
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
	|	TemporaryTableExchangeDifferencesPayroll AS DocumentTable
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
	|	9,
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
	|	10,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	&Company,
	|	SupplierInvoice.Department,
	|	CASE
	|		WHEN DocumentTable.Order = VALUE(Document.SalesOrder.EmptyRef)
	|				OR DocumentTable.Order = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE DocumentTable.Order
	|	END,
	|	UNDEFINED,
	|	DefaultGLAccounts.GLAccount,
	|	&EarlyPaymentDiscount,
	|	SUM(CASE
	|			WHEN SupplierInvoice.ProvideEPD = VALUE(Enum.VariantsOfProvidingEPD.PaymentDocumentWithVATAdjustment)
	|				THEN DocumentTable.AccountingEPDAmountExclVAT
	|			ELSE DocumentTable.AccountingEPDAmount
	|		END),
	|	0,
	|	FALSE
	|FROM
	|	TemporaryTablePaymentDetails AS DocumentTable
	|		INNER JOIN Catalog.DefaultGLAccounts AS DefaultGLAccounts
	|		ON (DefaultGLAccounts.Ref = VALUE(Catalog.DefaultGLAccounts.DiscountReceived))
	|		INNER JOIN Document.SupplierInvoice AS SupplierInvoice
	|		ON DocumentTable.Document = SupplierInvoice.Ref
	|WHERE
	|	DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashVoucher.Vendor)
	|	AND DocumentTable.EPDAmount > 0
	|	AND (SupplierInvoice.ProvideEPD = VALUE(Enum.VariantsOfProvidingEPD.PaymentDocument)
	|			OR SupplierInvoice.ProvideEPD = VALUE(Enum.VariantsOfProvidingEPD.PaymentDocumentWithVATAdjustment))
	|
	|GROUP BY
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	SupplierInvoice.Department,
	|	DocumentTable.Order,
	|	DefaultGLAccounts.GLAccount
	|
	|ORDER BY
	|	Order,
	|	LineNumber";
		
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpenses", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableAccountingJournalEntries(DocumentRefCashVoucher, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();

	Query.SetParameter("Ref",							DocumentRefCashVoucher);
	Query.SetParameter("Company",						StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PointInTime",					New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ExchangeDifference",			NStr("en = 'Foreign currency exchange gains and losses'", MainLanguageCode));
	Query.SetParameter("Content",						NStr("en = 'Expenses incurred'", MainLanguageCode));
	Query.SetParameter("ContentTransferToCashCR",		NStr("en = 'Cash transfer to cash register'", MainLanguageCode));
	Query.SetParameter("TaxPay",						NStr("en = 'Tax payment'", MainLanguageCode));
	Query.SetParameter("ContentVAT",					NStr("en = 'VAT'", MainLanguageCode));
	Query.SetParameter("EarlyPaymentDiscount",			NStr("en = 'Early payment discount'", MainLanguageCode));
	Query.SetParameter("ForeignCurrencyExchangeGain",	Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeGain"));
	Query.SetParameter("ForeignCurrencyExchangeLoss",	Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeLoss"));
	Query.SetParameter("ContentVATOnAdvance",			NStr("en = 'VAT charged on advance payment'", MainLanguageCode));
	Query.SetParameter("VATAdvancesToSuppliers",		Catalogs.DefaultGLAccounts.GetDefaultGLAccount("VATAdvancesToSuppliers"));
	Query.SetParameter("VATInput",						Catalogs.DefaultGLAccounts.GetDefaultGLAccount("VATInput"));
	Query.SetParameter("PostAdvancePaymentsBySourceDocuments", StructureAdditionalProperties.AccountingPolicy.PostAdvancePaymentsBySourceDocuments);
	
	Query.Text =
	"SELECT
	|	1 AS Order,
	|	1 AS LineNumber,
	|	DocumentTable.Date AS Period,
	|	&Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	DocumentTable.Correspondence AS AccountDr,
	|	DocumentTable.PettyCashGLAccount AS AccountCr,
	|	CASE
	|		WHEN DocumentTable.Correspondence.Currency
	|			THEN DocumentTable.CashCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN DocumentTable.PettyCash.GLAccount.Currency
	|			THEN DocumentTable.CashCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	CASE
	|		WHEN DocumentTable.Correspondence.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END AS AmountCurDr,
	|	CASE
	|		WHEN DocumentTable.PettyCash.GLAccount.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END AS AmountCurCr,
	|	DocumentTable.Amount AS Amount,
	|	CAST(&Content AS STRING(100)) AS Content,
	|	FALSE AS OfflineRecord
	|FROM
	|	TemporaryTableHeader AS DocumentTable
	|WHERE
	|	DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashVoucher.Other)
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	1,
	|	DocumentTable.Date,
	|	&Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.CashCRGLAccount,
	|	DocumentTable.PettyCashGLAccount,
	|	CASE
	|		WHEN DocumentTable.CashCRGLAccount.Currency
	|			THEN DocumentTable.CashCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.PettyCashGLAccount.Currency
	|			THEN DocumentTable.CashCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.CashCRGLAccount.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.PettyCashGLAccount.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END,
	|	DocumentTable.Amount,
	|	CAST(&ContentTransferToCashCR AS STRING(100)),
	|	FALSE
	|FROM
	|	TemporaryTableHeader AS DocumentTable
	|WHERE
	|	DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashVoucher.TransferToCashCR)
	|
	|UNION ALL
	|
	|SELECT
	|	3,
	|	1,
	|	DocumentTable.Date,
	|	&Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.TaxKindGLAccount,
	|	DocumentTable.PettyCashGLAccount,
	|	CASE
	|		WHEN DocumentTable.TaxKind.GLAccount.Currency
	|			THEN DocumentTable.CashCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.PettyCash.GLAccount.Currency
	|			THEN DocumentTable.CashCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.TaxKind.GLAccount.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.PettyCash.GLAccount.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END,
	|	DocumentTable.Amount,
	|	CAST(&TaxPay AS STRING(100)),
	|	FALSE
	|FROM
	|	TemporaryTableHeader AS DocumentTable
	|WHERE
	|	DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashVoucher.Taxes)
	|
	|UNION ALL
	|
	|SELECT
	|	4,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.GLAccount,
	|	DocumentTable.PettyCash.GLAccount,
	|	CASE
	|		WHEN DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.PettyCash.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.PettyCash.GLAccount.Currency
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
	|	DocumentTable.GLAccount,
	|	DocumentTable.PettyCash.GLAccount,
	|	CASE
	|		WHEN DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.PettyCash.GLAccount.Currency
	|			THEN DocumentTable.CashCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.PettyCash.GLAccount.Currency
	|			THEN DocumentTable.PaymentAmount
	|		ELSE 0
	|	END,
	|	DocumentTable.Amount,
	|	DocumentTable.ContentOfAccountingRecord,
	|	FALSE
	|FROM
	|	TemporaryTableAccountsReceivable AS DocumentTable
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
	|	DocumentTable.GLAccount,
	|	DocumentTable.PettyCash.GLAccount,
	|	CASE
	|		WHEN DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.PettyCash.GLAccount.Currency
	|			THEN DocumentTable.CashCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.PettyCash.GLAccount.Currency
	|			THEN DocumentTable.PaymentAmount
	|		ELSE 0
	|	END,
	|	DocumentTable.Amount,
	|	DocumentTable.ContentOfAccountingRecord,
	|	FALSE
	|FROM
	|	TemporaryTableAccountsPayable AS DocumentTable
	|WHERE
	|	NOT DocumentTable.isEPD
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
	|	DocumentTable.GLAccount,
	|	DocumentTable.PettyCashGLAccount,
	|	CASE
	|		WHEN DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.PettyCashGLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.PettyCashGLAccount.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END,
	|	DocumentTable.Amount,
	|	DocumentTable.ContentOfAccountingRecord,
	|	FALSE
	|FROM
	|	TemporaryTablePayroll AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	13,
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
	|	TemporaryTableExchangeDifferencesPayroll AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	14,
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
	|	15,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.GLAccount,
	|	DocumentTable.PettyCash.GLAccount,
	|	CASE
	|		WHEN DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.PettyCash.GLAccount.Currency
	|			THEN DocumentTable.CashCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.PettyCash.GLAccount.Currency
	|			THEN DocumentTable.PaymentAmount
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
	|	16,
	|	1,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.GLAccount,
	|	DocumentTable.PettyCash.GLAccount,
	|	CASE
	|		WHEN DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.PettyCash.GLAccount.Currency
	|			THEN DocumentTable.CashCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.PettyCash.GLAccount.Currency
	|			THEN DocumentTable.PaymentAmount
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
	|	17,
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
	|	&VATInput,
	|	&VATAdvancesToSuppliers,
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
	|	DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashVoucher.Vendor)
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
	|	TemporaryTablePaymentDetails.GLAccountVendorSettlements,
	|	DefaultGLAccounts.GLAccount,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.GLAccountVendorSettlements.Currency
	|			THEN TemporaryTablePaymentDetails.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DefaultGLAccounts.GLAccount.Currency
	|			THEN TemporaryTablePaymentDetails.CashCurrency
	|		ELSE UNDEFINED
	|	END,
	|	SUM(CASE
	|			WHEN TemporaryTablePaymentDetails.GLAccountVendorSettlements.Currency
	|				THEN CASE
	|						WHEN SupplierInvoice.ProvideEPD = VALUE(Enum.VariantsOfProvidingEPD.PaymentDocumentWithVATAdjustment)
	|							THEN TemporaryTablePaymentDetails.SettlementsEPDAmountExclVAT
	|						ELSE TemporaryTablePaymentDetails.SettlementsEPDAmount
	|					END
	|			ELSE 0
	|		END),
	|	SUM(CASE
	|			WHEN DefaultGLAccounts.GLAccount.Currency
	|				THEN CASE
	|						WHEN SupplierInvoice.ProvideEPD = VALUE(Enum.VariantsOfProvidingEPD.PaymentDocumentWithVATAdjustment)
	|							THEN TemporaryTablePaymentDetails.EPDAmountExclVAT
	|						ELSE TemporaryTablePaymentDetails.EPDAmount
	|					END
	|			ELSE 0
	|		END),
	|	SUM(CASE
	|			WHEN SupplierInvoice.ProvideEPD = VALUE(Enum.VariantsOfProvidingEPD.PaymentDocumentWithVATAdjustment)
	|				THEN TemporaryTablePaymentDetails.AccountingEPDAmountExclVAT
	|			ELSE TemporaryTablePaymentDetails.AccountingEPDAmount
	|		END),
	|	&EarlyPaymentDiscount,
	|	FALSE
	|FROM
	|	TemporaryTablePaymentDetails AS TemporaryTablePaymentDetails
	|		INNER JOIN Document.SupplierInvoice AS SupplierInvoice
	|		ON TemporaryTablePaymentDetails.Document = SupplierInvoice.Ref
	|		INNER JOIN Catalog.DefaultGLAccounts AS DefaultGLAccounts
	|		ON (DefaultGLAccounts.Ref = VALUE(Catalog.DefaultGLAccounts.DiscountReceived))
	|WHERE
	|	TemporaryTablePaymentDetails.OperationKind = VALUE(Enum.OperationTypesCashVoucher.Vendor)
	|	AND TemporaryTablePaymentDetails.DoOperationsByDocuments
	|	AND NOT TemporaryTablePaymentDetails.AdvanceFlag
	|	AND TemporaryTablePaymentDetails.EPDAmount > 0
	|	AND (SupplierInvoice.ProvideEPD = VALUE(Enum.VariantsOfProvidingEPD.PaymentDocument)
	|			OR SupplierInvoice.ProvideEPD = VALUE(Enum.VariantsOfProvidingEPD.PaymentDocumentWithVATAdjustment))
	|
	|GROUP BY
	|	TemporaryTablePaymentDetails.Date,
	|	DefaultGLAccounts.GLAccount,
	|	TemporaryTablePaymentDetails.GLAccountVendorSettlements,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.GLAccountVendorSettlements.Currency
	|			THEN TemporaryTablePaymentDetails.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DefaultGLAccounts.GLAccount.Currency
	|			THEN TemporaryTablePaymentDetails.CashCurrency
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
	|	TemporaryTablePaymentDetails.GLAccountVendorSettlements,
	|	&VATInput,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.GLAccountVendorSettlements.Currency
	|			THEN TemporaryTablePaymentDetails.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	UNDEFINED,
	|	SUM(CASE
	|			WHEN TemporaryTablePaymentDetails.GLAccountVendorSettlements.Currency
	|				THEN TemporaryTablePaymentDetails.SettlementsEPDAmount - TemporaryTablePaymentDetails.SettlementsEPDAmountExclVAT
	|			ELSE 0
	|		END),
	|	0,
	|	SUM(TemporaryTablePaymentDetails.AccountingEPDAmount - TemporaryTablePaymentDetails.AccountingEPDAmountExclVAT),
	|	&ContentVAT,
	|	FALSE
	|FROM
	|	TemporaryTablePaymentDetails AS TemporaryTablePaymentDetails
	|		INNER JOIN Document.SupplierInvoice AS SupplierInvoice
	|		ON TemporaryTablePaymentDetails.Document = SupplierInvoice.Ref
	|			AND (SupplierInvoice.ProvideEPD = VALUE(Enum.VariantsOfProvidingEPD.PaymentDocumentWithVATAdjustment))
	|WHERE
	|	TemporaryTablePaymentDetails.OperationKind = VALUE(Enum.OperationTypesCashVoucher.Vendor)
	|	AND TemporaryTablePaymentDetails.DoOperationsByDocuments
	|	AND NOT TemporaryTablePaymentDetails.AdvanceFlag
	|	AND TemporaryTablePaymentDetails.EPDAmount > 0
	|
	|GROUP BY
	|	TemporaryTablePaymentDetails.Date,
	|	TemporaryTablePaymentDetails.GLAccountVendorSettlements,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.GLAccountVendorSettlements.Currency
	|			THEN TemporaryTablePaymentDetails.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END
	|
	|ORDER BY
	|	Order,
	|	LineNumber";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountingJournalEntries", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableIncomeAndExpensesCashMethod(DocumentRefCashVoucher, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefCashVoucher);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("IncomeAndExpensesAccountingCashMethod", StructureAdditionalProperties.AccountingPolicy.IncomeAndExpensesAccountingCashMethod);
	
	Query.Text =
	"SELECT
	|	DocumentTable.Date AS Period,
	|	&Company AS Company,
	|	UNDEFINED AS BusinessLine,
	|	DocumentTable.Item AS Item,
	|	0 AS AmountIncome,
	|	DocumentTable.AccountingAmount AS AmountExpense
	|FROM
	|	TemporaryTablePaymentDetails AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashVoucher.Vendor)
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
	|	Table.AmountExpense
	|FROM
	|	TemporaryTableTableDeferredIncomeAndExpenditure AS Table
	|WHERE
	|	Table.AmountExpense > 0
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentTable.Date,
	|	&Company,
	|	CASE
	|		WHEN DocumentTable.BusinessLine <> VALUE(Catalog.LinesOfBusiness.EmptyRef)
	|			THEN DocumentTable.BusinessLine
	|		ELSE VALUE(Catalog.LinesOfBusiness.Other)
	|	END,
	|	DocumentTable.Item,
	|	0,
	|	DocumentTable.Amount
	|FROM
	|	TemporaryTableHeader AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND (DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashVoucher.Other)
	|			OR DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashVoucher.OtherSettlements)
	|			OR DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashVoucher.LoanSettlements)
	|			OR DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashVoucher.IssueLoanToEmployee)
	|			OR DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashVoucher.Salary)
	|			OR DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashVoucher.SalaryForEmployee)
	|			OR DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashVoucher.Taxes))
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentTable.Date,
	|	&Company,
	|	UNDEFINED,
	|	DocumentTable.Item,
	|	-DocumentTable.AccountingAmount,
	|	0
	|FROM
	|	TemporaryTablePaymentDetails AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashVoucher.ToCustomer)
	|	AND DocumentTable.AdvanceFlag
	|
	|UNION ALL
	|
	|SELECT
	|	Table.Period,
	|	Table.Company,
	|	Table.BusinessLine,
	|	Table.Item,
	|	-Table.AmountIncome,
	|	0
	|FROM
	|	TemporaryTableTableDeferredIncomeAndExpenditure AS Table
	|WHERE
	|	Table.AmountIncome > 0";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpensesCashMethod", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableUnallocatedExpenses(DocumentRefCashVoucher, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefCashVoucher);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("IncomeAndExpensesAccountingCashMethod", StructureAdditionalProperties.AccountingPolicy.IncomeAndExpensesAccountingCashMethod);
	
	Query.Text =
	"SELECT
	|	1 AS Order,
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
	|	0 AS AmountIncome,
	|	DocumentTable.AccountingAmount AS AmountExpense
	|FROM
	|	TemporaryTablePaymentDetails AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashVoucher.Vendor)
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
	|	-DocumentTable.AccountingAmount,
	|	0
	|FROM
	|	TemporaryTablePaymentDetails AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashVoucher.ToCustomer)
	|	AND DocumentTable.AdvanceFlag
	|
	|ORDER BY
	|	Order,
	|	LineNumber";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableUnallocatedExpenses", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableIncomeAndExpensesRetained(DocumentRefCashVoucher, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefCashVoucher);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("IncomeAndExpensesAccountingCashMethod", StructureAdditionalProperties.AccountingPolicy.IncomeAndExpensesAccountingCashMethod);
	Query.SetParameter("Period", StructureAdditionalProperties.ForPosting.PointInTime.Date);
	
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
	|	AND DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashVoucher.Vendor)
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
	|	-SUM(IncomeAndExpensesRetainedBalances.AmountIncomeBalance) AS AmountIncomeBalance,
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
	|							TemporaryTablePaymentDetails AS DocumentTable
	|						WHERE
	|							(DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashVoucher.Vendor)
	|								OR DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashVoucher.ToCustomer)))) AS IncomeAndExpensesRetainedBalances
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
	|	AND DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashVoucher.ToCustomer)
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
	|	-Table.AmountIncome AS AmountIncome,
	|	Table.AmountExpense AS AmountExpense,
	|	Table.BusinessLine AS BusinessLine
	|FROM
	|	TemporaryTableTableDeferredIncomeAndExpenditure AS Table";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpensesRetained", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableTaxesSettlements(DocumentRefCashVoucher, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();

	Query.SetParameter("Ref",			DocumentRefCashVoucher);
	Query.SetParameter("Company",		StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PointInTime",	New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("TaxPay",		NStr("en = 'Tax payment'", MainLanguageCode));
	
	Query.Text =
	"SELECT
	|	DocumentTable.Date AS Period,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	&Company AS Company,
	|	DocumentTable.TaxKind AS TaxKind,
	|	DocumentTable.Amount AS Amount,
	|	DocumentTable.TaxKindGLAccount AS GLAccount,
	|	&TaxPay AS ContentOfAccountingRecord
	|FROM
	|	TemporaryTableHeader AS DocumentTable
	|WHERE
	|	DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashVoucher.Taxes)";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableTaxAccounting", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTablePaymentCalendar(DocumentRefCashVoucher, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefCashVoucher);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("UsePaymentCalendar", Constants.UsePaymentCalendar.Get());
	
	Query.Text =
	"SELECT
	|	1 AS Order,
	|	MAX(DocumentTable.LineNumber) AS LineNumber,
	|	DocumentTable.Date AS Period,
	|	&Company AS Company,
	|	DocumentTable.Item AS Item,
	|	VALUE(Enum.CashAssetTypes.Cash) AS CashAssetTypes,
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
	|				THEN -DocumentTable.SettlementsAmount
	|			ELSE -DocumentTable.PaymentAmount
	|		END) AS PaymentAmount
	|FROM
	|	TemporaryTablePaymentDetails AS DocumentTable
	|WHERE
	|	&UsePaymentCalendar
	|	AND DocumentTable.OperationKind <> VALUE(Enum.OperationTypesCashVoucher.Salary)
	|
	|GROUP BY
	|	DocumentTable.Item,
	|	DocumentTable.Date,
	|	DocumentTable.PettyCash,
	|	CASE
	|		WHEN DocumentTable.Contract.SettlementsInStandardUnits
	|			THEN DocumentTable.SettlementsCurrency
	|		ELSE DocumentTable.CashCurrency
	|	END,
	|	DocumentTable.QuoteToPaymentCalendar
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	MAX(DocumentTable.LineNumber),
	|	DocumentTable.Ref.Date,
	|	&Company,
	|	DocumentTable.Ref.Item,
	|	VALUE(Enum.CashAssetTypes.Cash),
	|	VALUE(Enum.PaymentApprovalStatuses.Approved),
	|	DocumentTable.Ref.PettyCash,
	|	DocumentTable.Ref.CashCurrency,
	|	DocumentTable.PlanningDocument,
	|	SUM(-DocumentTable.PaymentAmount)
	|FROM
	|	Document.CashVoucher.PayrollPayment AS DocumentTable
	|WHERE
	|	&UsePaymentCalendar
	|	AND DocumentTable.Ref = &Ref
	|	AND DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesCashVoucher.Salary)
	|
	|GROUP BY
	|	DocumentTable.Ref,
	|	DocumentTable.PlanningDocument,
	|	DocumentTable.Ref.Date,
	|	DocumentTable.Ref.Item,
	|	DocumentTable.Ref.PettyCash,
	|	DocumentTable.Ref.CashCurrency
	|
	|UNION ALL
	|
	|SELECT
	|	3,
	|	1,
	|	DocumentTable.Date,
	|	&Company,
	|	DocumentTable.Item,
	|	VALUE(Enum.CashAssetTypes.Cash),
	|	VALUE(Enum.PaymentApprovalStatuses.Approved),
	|	DocumentTable.PettyCash,
	|	DocumentTable.CashCurrency,
	|	UNDEFINED,
	|	-DocumentTable.DocumentAmount
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
	|ORDER BY
	|	Order,
	|	LineNumber";
	
	Query.SetParameter("Ref", DocumentRefCashVoucher);
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TablePaymentCalendar", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInvoicesAndOrdersPayment(DocumentRefCashVoucher, StructureAdditionalProperties)
	
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
	|		WHEN DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashVoucher.ToCustomer)
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
	|		WHEN DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashVoucher.ToCustomer)
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
	|	AND (DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashVoucher.Vendor)
	|			OR DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashVoucher.ToCustomer))
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

Procedure GenerateTableVATInput(DocumentRefCashVoucher, StructureAdditionalProperties)
	
	If StructureAdditionalProperties.AccountingPolicy.RegisteredForVAT
		AND DocumentRefCashVoucher.OperationKind = Enums.OperationTypesCashVoucher.Vendor Then
		
		PostAdvancePayments = StructureAdditionalProperties.AccountingPolicy.PostAdvancePaymentsBySourceDocuments;
		
		Query = New Query;
		Query.SetParameter("PostAdvancePayments", PostAdvancePayments);
		Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
		Query.Text =
		"SELECT
		|	Payment.Period AS Period,
		|	Payment.Company AS Company,
		|	Payment.Supplier AS Supplier,
		|	Payment.ShipmentDocument AS ShipmentDocument,
		|	Payment.VATRate AS VATRate,
		|	VALUE(Enum.VATOperationTypes.AdvancePayment) AS OperationType,
		|	VALUE(Enum.ProductsTypes.EmptyRef) AS ProductType,
		|	Payment.AmountExcludesVAT AS AmountExcludesVAT,
		|	Payment.VATAmount AS VATAmount
		|FROM
		|	VAT AS Payment
		|WHERE
		|	&PostAdvancePayments
		|
		|UNION ALL
		|
		|SELECT
		|	Payment.Date,
		|	Payment.Company,
		|	Payment.Counterparty,
		|	SupplierInvoice.Ref,
		|	Payment.VATRate,
		|	VALUE(Enum.VATOperationTypes.DiscountReceived),
		|	VALUE(Enum.ProductsTypes.EmptyRef),
		|	-SUM(Payment.AccountingEPDAmountExclVAT),
		|	-SUM(Payment.AccountingEPDAmount - Payment.AccountingEPDAmountExclVAT)
		|FROM
		|	TemporaryTablePaymentDetails AS Payment
		|		INNER JOIN Document.SupplierInvoice AS SupplierInvoice
		|		ON Payment.Document = SupplierInvoice.Ref
		|			AND (SupplierInvoice.ProvideEPD = VALUE(Enum.VariantsOfProvidingEPD.PaymentDocumentWithVATAdjustment))
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
		|	SupplierInvoice.Ref,
		|	Payment.VATRate";
		
		QueryResult = Query.Execute();
		
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableVATInput", QueryResult.Unload());
		
	Else
	
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableVATInput", New ValueTable);
	
	EndIf;
	
EndProcedure

Procedure GenerateTableVATIncurred(DocumentRefCashVoucher, StructureAdditionalProperties)
	
	If NOT StructureAdditionalProperties.AccountingPolicy.RegisteredForVAT
		OR StructureAdditionalProperties.AccountingPolicy.PostAdvancePaymentsBySourceDocuments
		OR DocumentRefCashVoucher.OperationKind <> Enums.OperationTypesCashVoucher.Vendor Then
		
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableVATIncurred", New ValueTable);
		Return;
		
	EndIf;
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	Payment.Period AS Period,
	|	Payment.Company AS Company,
	|	Payment.Supplier AS Supplier,
	|	Payment.ShipmentDocument AS ShipmentDocument,
	|	Payment.VATRate AS VATRate,
	|	Payment.AmountExcludesVAT AS AmountExcludesVAT,
	|	Payment.VATAmount AS VATAmount
	|FROM
	|	VAT AS Payment";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableVATIncurred", QueryResult.Unload());
	
EndProcedure

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefCashVoucher, StructureAdditionalProperties) Export
	
	Query = New Query;
	
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefCashVoucher);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	
	Query.SetParameter("PresentationCurrency", Constants.PresentationCurrency.Get());
	Query.SetParameter("CashCurrency", DocumentRefCashVoucher.CashCurrency);
	Query.SetParameter("LoanContractCurrency", DocumentRefCashVoucher.LoanContract.SettlementsCurrency);

	MainLanguageCode = CommonUseClientServer.MainLanguageCode();
	Query.SetParameter("CreditPrincipalDebtPayment",	NStr("en = 'Loan principal repayment'",
														MainLanguageCode));
	Query.SetParameter("CreditInterestPayment",			NStr("en = 'Loan interest repayment'",
														MainLanguageCode));
	Query.SetParameter("CreditComissionPayment",		NStr("en = 'Loan comission repayment'",
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
	|	DocumentTable.Ref.Correspondence AS Correspondence,
	|	DocumentTable.Ref.Item AS Item,
	|	CASE
	|		WHEN DocumentTable.Order = UNDEFINED
	|				AND DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesCashVoucher.ToCustomer)
	|			THEN VALUE(Document.SalesOrder.EmptyRef)
	|		WHEN DocumentTable.Order = UNDEFINED
	|				AND DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesCashVoucher.Vendor)
	|			THEN VALUE(Document.PurchaseOrder.EmptyRef)
	|		WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesCashVoucher.ToCustomer)
	|				AND DocumentTable.Order = VALUE(Document.PurchaseOrder.EmptyRef)
	|			THEN VALUE(Document.SalesOrder.EmptyRef)
	|		WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesCashVoucher.Vendor)
	|				AND DocumentTable.Order = VALUE(Document.SalesOrder.EmptyRef)
	|			THEN VALUE(Document.PurchaseOrder.EmptyRef)
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
	|		WHEN VALUETYPE(DocumentTable.PlanningDocument) = TYPE(Document.ExpenditureRequest)
	|				AND DocumentTable.PlanningDocument <> VALUE(Document.ExpenditureRequest.EmptyRef)
	|			THEN DocumentTable.PlanningDocument
	|		WHEN VALUETYPE(DocumentTable.PlanningDocument) = TYPE(Document.CashTransferPlan)
	|				AND DocumentTable.PlanningDocument <> VALUE(Document.CashTransferPlan.EmptyRef)
	|			THEN DocumentTable.PlanningDocument
	|		WHEN DocumentTable.Order.SetPaymentTerms
	|			THEN DocumentTable.Order
	|		ELSE UNDEFINED
	|	END AS QuoteToPaymentCalendar,
	|	DocumentTable.Ref.PettyCash.GLAccount AS BankAccountCashGLAccount,
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
	|			THEN &CreditPrincipalDebtPayment
	|		WHEN DocumentTable.TypeOfAmount = VALUE(Enum.LoanScheduleAmountTypes.Interest)
	|			THEN &CreditInterestPayment
	|		WHEN DocumentTable.TypeOfAmount = VALUE(Enum.LoanScheduleAmountTypes.Commission)
	|			THEN &CreditComissionPayment
	|	END AS ContentByTypeOfAmount,
	|	DocumentTable.VATRate AS VATRate,
	|	SUM(DocumentTable.VATAmount * ExchangeRatesOfPettyCashe.ExchangeRate / AccountingExchangeRates.Multiplicity) AS VATAmount,
	|	SUM((DocumentTable.PaymentAmount - DocumentTable.VATAmount) * ExchangeRatesOfPettyCashe.ExchangeRate / AccountingExchangeRates.Multiplicity) AS AmountExcludesVAT,
	|	DocumentTable.Ref.Company AS Company
	|INTO TemporaryTablePaymentDetailsPre
	|FROM
	|	Document.CashVoucher.PaymentDetails AS DocumentTable
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
	|	DocumentTable.Ref.Correspondence,
	|	CASE
	|		WHEN DocumentTable.Order = UNDEFINED
	|				AND DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesCashVoucher.ToCustomer)
	|			THEN VALUE(Document.SalesOrder.EmptyRef)
	|		WHEN DocumentTable.Order = UNDEFINED
	|				AND DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesCashVoucher.Vendor)
	|			THEN VALUE(Document.PurchaseOrder.EmptyRef)
	|		WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesCashVoucher.ToCustomer)
	|				AND DocumentTable.Order = VALUE(Document.PurchaseOrder.EmptyRef)
	|			THEN VALUE(Document.SalesOrder.EmptyRef)
	|		WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesCashVoucher.Vendor)
	|				AND DocumentTable.Order = VALUE(Document.SalesOrder.EmptyRef)
	|			THEN VALUE(Document.PurchaseOrder.EmptyRef)
	|		ELSE DocumentTable.Order
	|	END,
	|	DocumentTable.AdvanceFlag,
	|	DocumentTable.Ref.Date,
	|	DocumentTable.Contract.SettlementsCurrency,
	|	DocumentTable.Order,
	|	DocumentTable.Ref.Counterparty.GLAccountCustomerSettlements,
	|	DocumentTable.Ref.Counterparty.CustomerAdvancesGLAccount,
	|	DocumentTable.Ref.Counterparty.GLAccountVendorSettlements,
	|	DocumentTable.Ref.Counterparty.VendorAdvancesGLAccount,
	|	DocumentTable.Ref.PettyCash.GLAccount,
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
	|			THEN &CreditPrincipalDebtPayment
	|		WHEN DocumentTable.TypeOfAmount = VALUE(Enum.LoanScheduleAmountTypes.Interest)
	|			THEN &CreditInterestPayment
	|		WHEN DocumentTable.TypeOfAmount = VALUE(Enum.LoanScheduleAmountTypes.Commission)
	|			THEN &CreditComissionPayment
	|	END,
	|	DocumentTable.Ref,
	|	DocumentTable.VATRate,
	|	DocumentTable.Ref.Company,
	|	CASE
	|		WHEN VALUETYPE(DocumentTable.PlanningDocument) = TYPE(Document.ExpenditureRequest)
	|				AND DocumentTable.PlanningDocument <> VALUE(Document.ExpenditureRequest.EmptyRef)
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
	|	TemporaryTable.Correspondence AS Correspondence,
	|	TemporaryTable.Item AS Item,
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
	|	TemporaryTable.BankAccountCashGLAccount AS BankAccountCashGLAccount,
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
	|	CAST(DocumentTable.DocumentAmount * ExchangeRatesOfPettyCashe.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * ExchangeRatesOfPettyCashe.Multiplicity) AS NUMBER(15, 2)) AS Amount,
	|	DocumentTable.DocumentAmount AS AmountCur,
	|	DocumentTable.PettyCash.GLAccount AS PettyCashGLAccount,
	|	DocumentTable.CashCR.GLAccount AS CashCRGLAccount,
	|	DocumentTable.TaxKind AS TaxKind,
	|	DocumentTable.TaxKind.GLAccount AS TaxKindGLAccount,
	|	DocumentTable.Department AS Department,
	|	DocumentTable.BusinessLine AS BusinessLine,
	|	DocumentTable.BusinessLine.GLAccountRevenueFromSales AS BusinessLineGLAccountOfRevenueFromSales,
	|	DocumentTable.BusinessLine.GLAccountCostOfSales AS BusinessLineGLAccountOfSalesCost,
	|	DocumentTable.Order AS Order,
	|	DocumentTable.Correspondence AS Correspondence,
	|	DocumentTable.Correspondence.TypeOfAccount AS CorrespondenceGLAccountType,
	|	DocumentTable.AdvanceHolder AS AdvanceHolder,
	|	DocumentTable.AdvanceHolder.SettlementsHumanResourcesGLAccount AS AdvanceHolderPersonnelGLAccount,
	|	DocumentTable.RegistrationPeriod AS RegistrationPeriod,
	|	DocumentTable.AdvanceHolder.AdvanceHoldersGLAccount AS AdvanceHolderAdvanceHoldersGLAccount,
	|	DocumentTable.Document AS Document,
	|	CASE
	|		WHEN DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashVoucher.OtherSettlements)
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS AccountingOtherSettlements
	|INTO TemporaryTableHeader
	|FROM
	|	Document.CashVoucher AS DocumentTable
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS AccountingExchangeRatesSliceLast
	|		ON (AccountingExchangeRatesSliceLast.Currency = &PresentationCurrency)
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS ExchangeRatesOfPettyCashe
	|		ON (ExchangeRatesOfPettyCashe.Currency = &CashCurrency)
	|WHERE
	|	DocumentTable.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Payment.Date AS Period,
	|	Payment.Company AS Company,
	|	Payment.Counterparty AS Supplier,
	|	Payment.Ref AS ShipmentDocument,
	|	Payment.VATRate AS VATRate,
	|	SUM(Payment.AmountExcludesVAT) AS AmountExcludesVAT,
	|	SUM(Payment.VATAmount) AS VATAmount
	|INTO VAT
	|FROM
	|	TemporaryTablePaymentDetails AS Payment
	|WHERE
	|	NOT Payment.VATRate.NotTaxable
	|	AND Payment.AdvanceFlag
	|	AND Payment.VATAmount > 0
	|
	|GROUP BY
	|	Payment.Date,
	|	Payment.Company,
	|	Payment.Counterparty,
	|	Payment.Ref,
	|	Payment.VATRate";
	
	Query.Execute();
	
	// Register record table creation by account sections.
	GenerateTableCashAssets(DocumentRefCashVoucher, StructureAdditionalProperties);
	GenerateTableCashAssetsInCashRegisters(DocumentRefCashVoucher, StructureAdditionalProperties);
	GenerateAdvanceHoldersTable(DocumentRefCashVoucher, StructureAdditionalProperties);
	GenerateTableAccountsPayable(DocumentRefCashVoucher, StructureAdditionalProperties);
	GenerateTableCustomerAccounts(DocumentRefCashVoucher, StructureAdditionalProperties);
	GenerateTablePayroll(DocumentRefCashVoucher, StructureAdditionalProperties);
	GenerateTableMiscellaneousPayable(DocumentRefCashVoucher, StructureAdditionalProperties);
	GenerateTableLoanSettlements(DocumentRefCashVoucher, StructureAdditionalProperties);
	GenerateTableIncomeAndExpenses(DocumentRefCashVoucher, StructureAdditionalProperties);
	GenerateTableTaxesSettlements(DocumentRefCashVoucher, StructureAdditionalProperties);
	GenerateTableAccountingJournalEntries(DocumentRefCashVoucher, StructureAdditionalProperties);
	GenerateTableUnallocatedExpenses(DocumentRefCashVoucher, StructureAdditionalProperties);
	GenerateTableIncomeAndExpensesRetained(DocumentRefCashVoucher, StructureAdditionalProperties);
	GenerateTableIncomeAndExpensesCashMethod(DocumentRefCashVoucher, StructureAdditionalProperties);
	GenerateTablePaymentCalendar(DocumentRefCashVoucher, StructureAdditionalProperties);
	GenerateTableInvoicesAndOrdersPayment(DocumentRefCashVoucher, StructureAdditionalProperties);
	GenerateTableVATIncurred(DocumentRefCashVoucher, StructureAdditionalProperties);
	GenerateTableVATInput(DocumentRefCashVoucher, StructureAdditionalProperties);
	
EndProcedure

// Controls the occurrence of negative balances.
//
Procedure RunControl(DocumentRefCashVoucher, AdditionalProperties, Cancel, PostingDelete = False) Export
	
	If Not Constants.CheckStockBalanceOnPosting.Get() Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// If temporary tables contain records, it is
	// necessary to execute negative balance control.
	If StructureTemporaryTables.RegisterRecordsCashAssetsChange
		OR StructureTemporaryTables.RegisterRecordsAdvanceHoldersChange
		OR StructureTemporaryTables.RegisterRecordsSuppliersSettlementsChange
		OR StructureTemporaryTables.RegisterRecordsCashInCashRegistersChange
		OR StructureTemporaryTables.RegisterRecordsVATIncurredChange Then
		
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
		|	RegisterRecordsSuppliersSettlementsChange.LineNumber AS LineNumber,
		|	RegisterRecordsSuppliersSettlementsChange.Company AS CompanyPresentation,
		|	RegisterRecordsSuppliersSettlementsChange.Counterparty AS CounterpartyPresentation,
		|	RegisterRecordsSuppliersSettlementsChange.Contract AS ContractPresentation,
		|	RegisterRecordsSuppliersSettlementsChange.Contract.SettlementsCurrency AS CurrencyPresentation,
		|	RegisterRecordsSuppliersSettlementsChange.Document AS DocumentPresentation,
		|	RegisterRecordsSuppliersSettlementsChange.Order AS OrderPresentation,
		|	RegisterRecordsSuppliersSettlementsChange.SettlementsType AS CalculationsTypesPresentation,
		|	TRUE AS RegisterRecordsOfCashDocuments,
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
		|		LEFT JOIN AccumulationRegister.AccountsPayable.Balance(&ControlTime, ) AS AccountsPayableBalances
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
		
		Query.Text = Query.Text + DriveClientServer.GetQueryDelimeter();
		Query.Text = Query.Text + AccumulationRegisters.VATIncurred.BalancesControlQueryText();
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.SetParameter("ControlTime", AdditionalProperties.ForPosting.ControlTime);
		
		ResultsArray = Query.ExecuteBatch();
		
		If Not ResultsArray[0].IsEmpty()
			OR Not ResultsArray[1].IsEmpty()
			OR Not ResultsArray[2].IsEmpty()
			OR Not ResultsArray[3].IsEmpty()
			OR Not ResultsArray[5].IsEmpty() Then
			DocumentObjectCashVoucher = DocumentRefCashVoucher.GetObject()
		EndIf;
		
		// Negative balance on cash.
		If Not ResultsArray[0].IsEmpty() Then
			QueryResultSelection = ResultsArray[0].Select();
			DriveServer.ShowMessageAboutPostingToCashAssetsRegisterErrors(DocumentObjectCashVoucher, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance on advance holder payments.
		If Not ResultsArray[1].IsEmpty() Then
			QueryResultSelection = ResultsArray[1].Select();
			DriveServer.ShowMessageAboutPostingToAdvanceHoldersRegisterErrors(DocumentObjectCashVoucher, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance on accounts payable.
		If Not ResultsArray[2].IsEmpty() Then
			QueryResultSelection = ResultsArray[2].Select();
			DriveServer.ShowMessageAboutPostingToAccountsPayableRegisterErrors(DocumentObjectCashVoucher, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance in cash CR.
		If Not ResultsArray[3].IsEmpty() Then
			QueryResultSelection = ResultsArray[3].Select();
			DriveServer.ErrorMessageOfPostingOnRegisterOfCashAtCashRegisters(DocumentObjectCashVoucher, QueryResultSelection, Cancel);
		EndIf;
		
		If Not ResultsArray[5].IsEmpty() Then
			QueryResultSelection = ResultsArray[5].Select();
			DriveServer.ShowMessageAboutPostingToVATIncurredRegisterErrors(DocumentObjectCashVoucher, QueryResultSelection, Cancel);
		EndIf;
		
	EndIf;
	
EndProcedure

#Region PrintInterface

// Procedure forms and displays a printable document form by the specified layout.
//
// Parameters:
// SpreadsheetDocument - TabularDocument in which
// 			   printing form will be displayed.
//  TemplateName    - String, printing form layout name.
//
Function PrintForm(ObjectsArray, PrintObjects)
	
	Var Errors;
	
	SpreadsheetDocument = New SpreadsheetDocument;
	SpreadsheetDocument.PrintParametersKey = "PrintParameters_CashVoucher";
	
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
		|	CashVoucher.Number AS DocumentNumber,
		|	CashVoucher.Date AS DocumentDate,
		|	CashVoucher.Company AS Company,
		|	CashVoucher.Company.LegalEntityIndividual AS LegalEntityIndividual,
		|	CashVoucher.Company.Prefix AS Prefix,
		|	CashVoucher.Company.DescriptionFull AS CompanyPresentation,
		|	CashVoucher.Issue AS Issue,
		|	CashVoucher.Basis AS Basis,
		|	CashVoucher.DocumentAmount AS DocumentAmount,
		|	CashVoucher.ByDocument AS DocumentAttributesWhichIdentifiesPerson,
		|	CashVoucher.PettyCash.GLAccount.Code AS CreditSubAccount,
		|	CashVoucher.CashCurrency AS CashCurrency,
		|	CASE
		|		WHEN CashVoucher.OperationKind = VALUE(Enum.OperationTypesCashVoucher.ToCustomer)
		|				OR CashVoucher.OperationKind = VALUE(Enum.OperationTypesCashVoucher.Vendor)
		|				OR CashVoucher.OperationKind = VALUE(Enum.OperationTypesCashVoucher.OtherSettlements)
		|			THEN CashVoucher.Counterparty.DescriptionFull
		|		WHEN CashVoucher.OperationKind = VALUE(Enum.OperationTypesCashVoucher.ToAdvanceHolder)
		|				OR CashVoucher.OperationKind = VALUE(Enum.OperationTypesCashVoucher.SalaryForEmployee)
		|			THEN CashVoucher.AdvanceHolder.Description
		|		ELSE CashVoucher.Issue
		|	END AS Recipient
		|FROM
		|	Document.CashVoucher AS CashVoucher
		|WHERE
		|	CashVoucher.Ref = &CurrentDocument";
		
		Header = Query.Execute().Select();
		
		Header.Next();
		
		SpreadsheetDocument.PrintParametersKey = "PRINT_PARAMETERS_CashVoucher_CashExpenseVoucher";
		Template = GetTemplate("PF_MXL_CashExpenseVoucher");
		
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
		
		TemplateArea = Template.GetArea("HeaderPayer");
		
		TemplateArea.Parameters.Fill(Header);
		
		PayerPresentation	= DriveServer.CompaniesDescriptionFull(InfoAboutCompany, "FullDescr");
		
		TemplateArea.Parameters.PayerPresentation	= PayerPresentation;
		TemplateArea.Parameters.PayerAddress		= DriveServer.CompaniesDescriptionFull(InfoAboutCompany, "LegalAddress");
		TemplateArea.Parameters.PayerPhoneFax		= DriveServer.CompaniesDescriptionFull(InfoAboutCompany, "PhoneNumbers,Fax");
		TemplateArea.Parameters.PayerEmail			= DriveServer.CompaniesDescriptionFull(InfoAboutCompany, "Email");
		
		SpreadsheetDocument.Put(TemplateArea);
		
		TemplateArea = Template.GetArea("HeaderRecipient");
		
		TemplateArea.Parameters.Recipient	= TrimAll(Header.Recipient);
		If ValueIsFilled(Header.Issue)
			AND TrimAll(Header.Issue) <> TrimAll(Header.Recipient) Then
		
			TemplateArea.Parameters.Issue	= TrimAll(Header.Issue);
		
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
		
		PrintManagement.SetDocumentPrintArea(SpreadsheetDocument, FirstLineNumber, PrintObjects, CurrentDocument.Ref);
		
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
	
	If PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "CashExpenseVoucher") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection, "CashExpenseVoucher", NStr("en = 'Cash voucher'"), PrintForm(ObjectsArray, PrintObjects));
		
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
	PrintCommand.ID							= "CashExpenseVoucher";
	PrintCommand.Presentation				= NStr("en = 'Cash voucher'");
	PrintCommand.FormsList					= "DocumentForm,ListForm";
	PrintCommand.CheckPostingBeforePrint	= False;
	PrintCommand.Order						= 1;
	
EndProcedure

#EndRegion

#Region OtherSettlements

Procedure GenerateTableMiscellaneousPayable(DocumentRefCashVoucher, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Company",						StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("AccountingForOtherOperations",	NStr("en = 'Miscellaneous payables'",	Metadata.DefaultLanguage.LanguageCode));
	Query.SetParameter("Comment",						NStr("en = 'Payment to other accounts'", Metadata.DefaultLanguage.LanguageCode));
	Query.SetParameter("Ref",							DocumentRefCashVoucher);
	Query.SetParameter("PointInTime",					New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod",					StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("ExchangeRateDifference",		NStr("en = 'Foreign currency exchange gains and losses'", Metadata.DefaultLanguage.LanguageCode));
	
	Query.Text =
	"SELECT
	|	TemporaryTablePaymentDetails.LineNumber AS LineNumber,
	|	&Company AS Company,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
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
	|		ON (TemporaryTableHeader.AccountingOtherSettlements)
	|WHERE
	|	TemporaryTablePaymentDetails.OperationKind = VALUE(Enum.OperationTypesCashVoucher.OtherSettlements)
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

Procedure GenerateTableLoanSettlements(DocumentRefCashVoucher, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Company", 					StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("AccountingForWorkersLoans",	NStr("en = 'Loan issue to employee'"));
	Query.SetParameter("Ref",						DocumentRefCashVoucher);
	Query.SetParameter("PointInTime",				New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod",				StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("ExchangeRateDifference",	NStr("en = 'Foreign currency exchange gains and losses'"));	
	Query.SetParameter("PresentationCurrency",		Constants.PresentationCurrency.Get());
	Query.SetParameter("CashCurrency",				DocumentRefCashVoucher.CashCurrency);
	
	Query.Text =
	"SELECT
	|	&Company AS Company,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	CASE
	|		WHEN CashVoucher.OperationKind = VALUE(Enum.OperationTypesCashVoucher.LoanSettlements)
	|			THEN VALUE(Enum.LoanContractTypes.Borrowed)
	|		ELSE VALUE(Enum.LoanContractTypes.EmployeeLoanAgreement)
	|	END AS LoanKind,
	|	CashVoucher.Date AS Date,
	|	CashVoucher.Date AS Period,
	|	&AccountingForWorkersLoans AS PostingContent,
	|	CashVoucher.AdvanceHolder AS Counterparty,
	|	CashVoucher.DocumentAmount AS PaymentAmount,
	|	CAST(CashVoucher.DocumentAmount * ExchangeRatesOfPettyCashe.ExchangeRate * ExchangeRatesOfContract.Multiplicity / (ExchangeRatesOfContract.ExchangeRate * ExchangeRatesOfPettyCashe.Multiplicity) AS NUMBER(15, 2)) AS PrincipalDebtCur,
	|	CAST(CashVoucher.DocumentAmount * ExchangeRatesOfPettyCashe.ExchangeRate * ExchangeRatesOfAccount.Multiplicity / (ExchangeRatesOfAccount.ExchangeRate * ExchangeRatesOfPettyCashe.Multiplicity) AS NUMBER(15, 2)) AS PrincipalDebt,
	|	CAST(CashVoucher.DocumentAmount * ExchangeRatesOfPettyCashe.ExchangeRate * ExchangeRatesOfContract.Multiplicity / (ExchangeRatesOfContract.ExchangeRate * ExchangeRatesOfPettyCashe.Multiplicity) AS NUMBER(15, 2)) AS PrincipalDebtCurForBalance,
	|	CAST(CashVoucher.DocumentAmount * ExchangeRatesOfPettyCashe.ExchangeRate * ExchangeRatesOfAccount.Multiplicity / (ExchangeRatesOfAccount.ExchangeRate * ExchangeRatesOfPettyCashe.Multiplicity) AS NUMBER(15, 2)) AS PrincipalDebtForBalance,
	|	0 AS InterestCur,
	|	0 AS Interest,
	|	0 AS InterestCurForBalance,
	|	0 AS InterestForBalance,
	|	0 AS CommissionCur,
	|	0 AS Commission,
	|	0 AS CommissionCurForBalance,
	|	0 AS CommissionForBalance,
	|	CAST(CashVoucher.DocumentAmount * ExchangeRatesOfPettyCashe.ExchangeRate * ExchangeRatesOfContract.Multiplicity / (ExchangeRatesOfContract.ExchangeRate * ExchangeRatesOfPettyCashe.Multiplicity) AS NUMBER(15, 2)) AS AmountCur,
	|	CAST(CashVoucher.DocumentAmount * ExchangeRatesOfPettyCashe.ExchangeRate * ExchangeRatesOfAccount.Multiplicity / (ExchangeRatesOfAccount.ExchangeRate * ExchangeRatesOfPettyCashe.Multiplicity) AS NUMBER(15, 2)) AS Amount,
	|	CashVoucher.LoanContract AS LoanContract,
	|	CashVoucher.LoanContract.SettlementsCurrency AS Currency,
	|	CashVoucher.CashCurrency AS CashCurrency,
	|	CashVoucher.LoanContract.GLAccount AS GLAccount,
	|	CashVoucher.PettyCash,
	|	FALSE AS DeductedFromSalary
	|INTO TemporaryTableLoanSettlements
	|FROM
	|	Document.CashVoucher AS CashVoucher
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS ExchangeRatesOfAccount
	|		ON (ExchangeRatesOfAccount.Currency = &PresentationCurrency)
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS ExchangeRatesOfPettyCashe
	|		ON (ExchangeRatesOfPettyCashe.Currency = &CashCurrency)
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS ExchangeRatesOfContract
	|		ON (ExchangeRatesOfContract.Currency = CashVoucher.LoanContract.SettlementsCurrency)
	|WHERE
	|	CashVoucher.OperationKind = VALUE(Enum.OperationTypesCashVoucher.IssueLoanToEmployee)
	|	AND CashVoucher.Ref = &Ref
	|
	|UNION ALL
	|
	|SELECT
	|	&Company,
	|	VALUE(AccumulationRecordType.Receipt),
	|	CASE
	|		WHEN DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashVoucher.LoanSettlements)
	|			THEN VALUE(Enum.LoanContractTypes.Borrowed)
	|		ELSE VALUE(Enum.LoanContractTypes.EmployeeLoanAgreement)
	|	END,
	|	DocumentTable.Date,
	|	DocumentTable.Date,
	|	DocumentTable.ContentByTypeOfAmount,
	|	DocumentTable.Counterparty,
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
	|	CASE
	|		WHEN DocumentTable.TypeOfAmount = VALUE(Enum.LoanScheduleAmountTypes.Principal)
	|			THEN DocumentTable.LoanContract.GLAccount
	|		WHEN DocumentTable.TypeOfAmount = VALUE(Enum.LoanScheduleAmountTypes.Interest)
	|			THEN DocumentTable.LoanContract.InterestGLAccount
	|		WHEN DocumentTable.TypeOfAmount = VALUE(Enum.LoanScheduleAmountTypes.Commission)
	|			THEN DocumentTable.LoanContract.CommissionGLAccount
	|		ELSE 0
	|	END,
	|	DocumentTable.PettyCash,
	|	FALSE
	|FROM
	|	TemporaryTablePaymentDetails AS DocumentTable
	|WHERE
	|	DocumentTable.OperationKind = VALUE(Enum.OperationTypesCashVoucher.LoanSettlements)";
	
	QueryResult = Query.Execute();
	
	Query.Text =
	"SELECT
	|	TemporaryTableLoanSettlements.Company AS Company,
	|	TemporaryTableLoanSettlements.Counterparty AS Counterparty,
	|	TemporaryTableLoanSettlements.LoanContract AS LoanContract
	|FROM
	|	TemporaryTableLoanSettlements AS TemporaryTableLoanSettlements";
	
	QueryResult = Query.Execute();
	
	DataLock			= New DataLock;
	LockItem			= DataLock.Add("AccumulationRegister.LoanSettlements");
	LockItem.Mode		= DataLockMode.Exclusive;
	LockItem.DataSource	= QueryResult;
	
	For Each Column In QueryResult.Columns Do
		LockItem.UseFromDataSource(Column.Name, Column.Name);
	EndDo;
	
	DataLock.Lock();
	
	QueryNumber = 0;
	
	Query.Text = DriveServer.GetQueryTextExchangeRateDifferencesLoanSettlements(Query.TempTablesManager, QueryNumber);
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableLoanSettlements", ResultsArray[QueryNumber].Unload());
	
EndProcedure

#EndRegion

#EndIf