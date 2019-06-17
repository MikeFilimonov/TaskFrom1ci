#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// Generating procedure for the table of invoices for payment.
//
// Parameters:
// DocumentRefOpeningBalanceEntry - DocumentRef.OpeningBalanceEntry - Current document
// StructureAdditionalProperties - Structure - Additional properties of the document
//
Procedure InitializeInvoicesAndOrdersPaymentDocumentData(DocumentRefOpeningBalanceEntry, StructureAdditionalProperties)
	
	Query = New Query;
	
	Query.SetParameter("Ref", DocumentRefOpeningBalanceEntry);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	
	Query.Text =
	"SELECT
	|	AccountsReceivable.Ref.Date AS Period,
	|	&Company AS Company,
	|	AccountsReceivable.SalesOrder AS Quote,
	|	AccountsReceivable.AmountCur AS AdvanceAmount
	|FROM
	|	Document.OpeningBalanceEntry.AccountsReceivable AS AccountsReceivable
	|WHERE
	|	AccountsReceivable.Ref = &Ref
	|	AND AccountsReceivable.SalesOrder <> VALUE(Document.SalesOrder.EmptyRef)
	|	AND AccountsReceivable.AdvanceFlag
	|
	|UNION ALL
	|
	|SELECT
	|	AccountsPayable.Ref.Date,
	|	&Company,
	|	AccountsPayable.PurchaseOrder,
	|	AccountsPayable.AmountCur
	|FROM
	|	Document.OpeningBalanceEntry.AccountsPayable AS AccountsPayable
	|WHERE
	|	AccountsPayable.Ref = &Ref
	|	AND AccountsPayable.PurchaseOrder <> VALUE(Document.PurchaseOrder.EmptyRef)
	|	AND AccountsPayable.AdvanceFlag
	|
	|UNION ALL
	|
	|SELECT
	|	AccountsPayable.Ref.Date,
	|	&Company,
	|	AccountsPayable.Quote,
	|	AccountsPayable.AmountCur
	|FROM
	|	Document.OpeningBalanceEntry.AccountsPayable AS AccountsPayable
	|WHERE
	|	AccountsPayable.Ref = &Ref
	|	AND AccountsPayable.Quote <> VALUE(Document.SupplierQuote.EmptyRef)
	|	AND AccountsPayable.AdvanceFlag";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInvoicesAndOrdersPayment", QueryResult.Unload());
	
EndProcedure

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentDataAccountingJournalEntries(DocumentRefOpeningBalanceEntry, StructureAdditionalProperties) Export

	Query = New Query(
	"SELECT
	|	AccountingJournalEntries.Ref.Date AS Period,
	|	&Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	AccountingJournalEntries.Amount AS Amount,
	|	CASE
	|		WHEN AccountingJournalEntries.RecordType = VALUE(Enum.DebitCredit.Dr)
	|			THEN AccountingJournalEntries.Account
	|		ELSE &OBEAccount
	|	END AS AccountDr,
	|	CASE
	|		WHEN AccountingJournalEntries.RecordType = VALUE(Enum.DebitCredit.Dr)
	|			THEN CASE
	|					WHEN AccountingJournalEntries.Account.Currency
	|						THEN AccountingJournalEntries.Currency
	|					ELSE UNDEFINED
	|				END
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN AccountingJournalEntries.RecordType = VALUE(Enum.DebitCredit.Dr)
	|			THEN CASE
	|					WHEN AccountingJournalEntries.Account.Currency
	|						THEN AccountingJournalEntries.AmountCur
	|					ELSE 0
	|				END
	|		ELSE 0
	|	END AS AmountCurDr,
	|	CASE
	|		WHEN AccountingJournalEntries.RecordType = VALUE(Enum.DebitCredit.Dr)
	|			THEN &OBEAccount
	|		ELSE AccountingJournalEntries.Account
	|	END AS AccountCr,
	|	CASE
	|		WHEN AccountingJournalEntries.RecordType = VALUE(Enum.DebitCredit.Dr)
	|			THEN UNDEFINED
	|		ELSE CASE
	|				WHEN AccountingJournalEntries.Account.Currency
	|					THEN AccountingJournalEntries.Currency
	|				ELSE UNDEFINED
	|			END
	|	END AS CurrencyCr,
	|	CASE
	|		WHEN AccountingJournalEntries.RecordType = VALUE(Enum.DebitCredit.Dr)
	|			THEN 0
	|		ELSE CASE
	|				WHEN AccountingJournalEntries.Account.Currency
	|					THEN AccountingJournalEntries.AmountCur
	|				ELSE 0
	|			END
	|	END AS AmountCurCr,
	|	&Content AS Content,
	|	FALSE AS OfflineRecord
	|FROM
	|	Document.OpeningBalanceEntry.OtherSections AS AccountingJournalEntries
	|WHERE
	|	AccountingJournalEntries.Ref = &Ref
	|
	|UNION ALL
	|
	|SELECT
	|	OfflineRecords.Period,
	|	OfflineRecords.Company,
	|	OfflineRecords.PlanningPeriod,
	|	OfflineRecords.Amount,
	|	OfflineRecords.AccountDr,
	|	OfflineRecords.CurrencyDr,
	|	OfflineRecords.AmountCurDr,
	|	OfflineRecords.AccountCr,
	|	OfflineRecords.CurrencyCr,
	|	OfflineRecords.AmountCurCr,
	|	OfflineRecords.Content,
	|	OfflineRecords.OfflineRecord
	|FROM
	|	AccountingRegister.AccountingJournalEntries AS OfflineRecords
	|WHERE
	|	OfflineRecords.Recorder = &Ref
	|	AND OfflineRecords.OfflineRecord");
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();

	Query.SetParameter("OBEAccount",	Catalogs.DefaultGLAccounts.GetDefaultGLAccount("OpeningBalanceEquity"));
	Query.SetParameter("Ref",			DocumentRefOpeningBalanceEntry);
	Query.SetParameter("Company",		StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("Content",		NStr("en = 'Entry of opening balance'", MainLanguageCode));
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountingJournalEntries", QueryResult.Unload());
	
EndProcedure

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentDataAdvanceHolders(DocumentRefOpeningBalanceEntry, StructureAdditionalProperties) Export

	Query = New Query(
	"SELECT
	|	AdvanceHolders.Ref AS Ref,
	|	AdvanceHolders.Ref.Date AS Period,
	|	CASE
	|		WHEN AdvanceHolders.Overrun = TRUE
	|			THEN VALUE(AccumulationRecordType.Expense)
	|		WHEN AdvanceHolders.Overrun = FALSE
	|			THEN VALUE(AccumulationRecordType.Receipt)
	|	END AS RecordType,
	|	MIN(AdvanceHolders.LineNumber) AS LineNumber,
	|	&Company AS Company,
	|	AdvanceHolders.Employee AS Employee,
	|	CASE
	|		WHEN AdvanceHolders.Overrun = TRUE
	|			THEN AdvanceHolders.Employee.OverrunGLAccount
	|		WHEN AdvanceHolders.Overrun = FALSE
	|			THEN AdvanceHolders.Employee.AdvanceHoldersGLAccount
	|	END AS GLAccount,
	|	AdvanceHolders.Currency AS Currency,
	|	AdvanceHolders.Document AS Document,
	|	CASE
	|		WHEN AdvanceHolders.Overrun = TRUE
	|			THEN VALUE(AccountingRecordType.Credit)
	|		WHEN AdvanceHolders.Overrun = FALSE
	|			THEN VALUE(AccountingRecordType.Debit)
	|	END AS RecordKindAccountingJournalEntries,
	|	CASE
	|		WHEN AdvanceHolders.Overrun = TRUE
	|			THEN &DebtRepaymentToAdvanceHolder
	|		WHEN AdvanceHolders.Overrun = FALSE
	|			THEN &AdvanceHolderDebtEmergence
	|	END AS ContentOfAccountingRecord,
	|	SUM(AdvanceHolders.AmountCur) AS AmountCur,
	|	SUM(AdvanceHolders.Amount) AS Amount
	|FROM
	|	Document.OpeningBalanceEntry.AdvanceHolders AS AdvanceHolders
	|		LEFT JOIN Constants AS Constants
	|		ON (TRUE)
	|WHERE
	|	AdvanceHolders.Ref = &Ref
	|
	|GROUP BY
	|	Constants.PresentationCurrency,
	|	AdvanceHolders.Ref,
	|	AdvanceHolders.Employee,
	|	AdvanceHolders.Currency,
	|	AdvanceHolders.Document,
	|	AdvanceHolders.Overrun,
	|	AdvanceHolders.Ref.Date,
	|	CASE
	|		WHEN AdvanceHolders.Overrun = TRUE
	|			THEN AdvanceHolders.Employee.OverrunGLAccount
	|		WHEN AdvanceHolders.Overrun = FALSE
	|			THEN AdvanceHolders.Employee.AdvanceHoldersGLAccount
	|	END
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	1 AS Order,
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Ref.Date AS Period,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	&Company AS Company,
	|	DocumentTable.Amount AS Amount,
	|	DocumentTable.Employee.AdvanceHoldersGLAccount AS AccountDr,
	|	CASE
	|		WHEN DocumentTable.Employee.AdvanceHoldersGLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN DocumentTable.Employee.AdvanceHoldersGLAccount.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END AS AmountCurDr,
	|	&OBEAccount AS AccountCr,
	|	UNDEFINED AS CurrencyCr,
	|	0 AS AmountCurCr,
	|	&AdvanceHolderDebtEmergence AS Content
	|FROM
	|	Document.OpeningBalanceEntry.AdvanceHolders AS DocumentTable
	|WHERE
	|	DocumentTable.Amount <> 0
	|	AND DocumentTable.Ref = &Ref
	|	AND DocumentTable.Overrun = FALSE
	|
	|UNION ALL
	|
	|SELECT
	|	1,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Ref.Date,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	&Company,
	|	DocumentTable.Amount,
	|	&OBEAccount,
	|	UNDEFINED,
	|	0,
	|	DocumentTable.Employee.OverrunGLAccount,
	|	CASE
	|		WHEN DocumentTable.Employee.OverrunGLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.Employee.OverrunGLAccount.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END,
	|	&DebtRepaymentToAdvanceHolder
	|FROM
	|	Document.OpeningBalanceEntry.AdvanceHolders AS DocumentTable
	|WHERE
	|	DocumentTable.Amount <> 0
	|	AND DocumentTable.Ref = &Ref
	|	AND DocumentTable.Overrun = TRUE
	|
	|ORDER BY
	|	Order,
	|	LineNumber");
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();

	Query.SetParameter("OBEAccount",					Catalogs.DefaultGLAccounts.GetDefaultGLAccount("OpeningBalanceEquity"));
	Query.SetParameter("Ref",							DocumentRefOpeningBalanceEntry);
	Query.SetParameter("Company",						StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("AdvanceHolderDebtEmergence",	NStr("en = 'Enter remaining debt of advance holder'", MainLanguageCode));
	Query.SetParameter("DebtRepaymentToAdvanceHolder",	NStr("en = 'Enter remaining debt to advance holder'", MainLanguageCode));
	
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSettlementsWithAdvanceHolders", ResultsArray[0].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountingJournalEntries", ResultsArray[1].Unload());
	
EndProcedure

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentDataPayroll(DocumentRefOpeningBalanceEntry, StructureAdditionalProperties) Export

	Query = New Query(
	"SELECT
	|	Payroll.Ref AS Ref,
	|	Payroll.Ref.Date AS Period,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	MIN(Payroll.LineNumber) AS LineNumber,
	|	&Company AS Company,
	|	Payroll.StructuralUnit AS StructuralUnit,
	|	Payroll.Employee AS Employee,
	|	Payroll.Employee.SettlementsHumanResourcesGLAccount AS GLAccount,
	|	Payroll.Currency AS Currency,
	|	BEGINOFPERIOD(Payroll.RegistrationPeriod, MONTH) AS RegistrationPeriod,
	|	VALUE(AccountingRecordType.Credit) AS RecordKindAccountingJournalEntries,
	|	&OccurrenceOfObligationsToStaff AS ContentOfAccountingRecord,
	|	SUM(Payroll.AmountCur) AS AmountCur,
	|	SUM(Payroll.Amount) AS Amount
	|FROM
	|	Document.OpeningBalanceEntry.Payroll AS Payroll
	|WHERE
	|	Payroll.Ref = &Ref
	|
	|GROUP BY
	|	Payroll.Ref,
	|	Payroll.Employee,
	|	Payroll.StructuralUnit,
	|	Payroll.Currency,
	|	Payroll.RegistrationPeriod,
	|	Payroll.Ref.Date,
	|	Payroll.Employee.SettlementsHumanResourcesGLAccount
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Ref.Date AS Period,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	&Company AS Company,
	|	DocumentTable.Amount AS Amount,
	|	&OBEAccount AS AccountDr,
	|	UNDEFINED AS CurrencyDr,
	|	0 AS AmountCurDr,
	|	DocumentTable.Employee.SettlementsHumanResourcesGLAccount AS AccountCr,
	|	CASE
	|		WHEN DocumentTable.Employee.SettlementsHumanResourcesGLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	CASE
	|		WHEN DocumentTable.Employee.SettlementsHumanResourcesGLAccount.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END AS AmountCurCr,
	|	&OccurrenceOfObligationsToStaff AS Content
	|FROM
	|	Document.OpeningBalanceEntry.Payroll AS DocumentTable
	|WHERE
	|	DocumentTable.Amount <> 0
	|	AND DocumentTable.Ref = &Ref");
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();

	Query.SetParameter("OBEAccount",						Catalogs.DefaultGLAccounts.GetDefaultGLAccount("OpeningBalanceEquity"));
	Query.SetParameter("Ref",								DocumentRefOpeningBalanceEntry);
	Query.SetParameter("Company",							StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("OccurrenceOfObligationsToStaff",	NStr("en = 'Incurrence of liabilities to personnel'", MainLanguageCode));
	
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TablePayroll", ResultsArray[0].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountingJournalEntries", ResultsArray[1].Unload());
	
EndProcedure

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentDataTaxesSettlements(DocumentRefOpeningBalanceEntry, StructureAdditionalProperties) Export

	Query = New Query(
	"SELECT
	|	TaxesSettlements.Ref.Date AS Period,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	MIN(TaxesSettlements.LineNumber) AS LineNumber,
	|	&Company AS Company,
	|	TaxesSettlements.TaxKind AS TaxKind,
	|	TaxesSettlements.TaxKind.GLAccount AS GLAccount,
	|	VALUE(AccountingRecordType.Credit) AS RecordKindAccountingJournalEntries,
	|	&TaxAccrual AS ContentOfAccountingRecord,
	|	SUM(TaxesSettlements.Amount) AS Amount
	|FROM
	|	Document.OpeningBalanceEntry.TaxesSettlements AS TaxesSettlements
	|WHERE
	|	TaxesSettlements.Ref = &Ref
	|
	|GROUP BY
	|	TaxesSettlements.Ref,
	|	TaxesSettlements.TaxKind,
	|	TaxesSettlements.Ref.Date,
	|	TaxesSettlements.TaxKind.GLAccount
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Ref.Date AS Period,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	&Company AS Company,
	|	DocumentTable.Amount AS Amount,
	|	&OBEAccount AS AccountDr,
	|	UNDEFINED AS CurrencyDr,
	|	0 AS AmountCurDr,
	|	DocumentTable.TaxKind.GLAccount AS AccountCr,
	|	UNDEFINED AS CurrencyCr,
	|	0 AS AmountCurCr,
	|	&TaxAccrual AS Content
	|FROM
	|	Document.OpeningBalanceEntry.TaxesSettlements AS DocumentTable
	|WHERE
	|	DocumentTable.Amount <> 0
	|	AND DocumentTable.Ref = &Ref");
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();

	Query.SetParameter("OBEAccount",	Catalogs.DefaultGLAccounts.GetDefaultGLAccount("OpeningBalanceEquity"));
	Query.SetParameter("Ref",			DocumentRefOpeningBalanceEntry);
	Query.SetParameter("Company",		StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("TaxAccrual",	NStr("en = 'Enter remaining debt to budget'", MainLanguageCode));
	
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableTaxAccounting", ResultsArray[0].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountingJournalEntries", ResultsArray[1].Unload());
	
EndProcedure

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentDataAccountsReceivable(DocumentRefOpeningBalanceEntry, StructureAdditionalProperties) Export

	Query = New Query(
	"SELECT
	|	AccountsReceivable.Ref.Date AS Period,
	|	CASE
	|		WHEN AccountsReceivable.AdvanceFlag
	|			THEN VALUE(AccumulationRecordType.Expense)
	|		ELSE VALUE(AccumulationRecordType.Receipt)
	|	END AS RecordType,
	|	MIN(AccountsReceivable.LineNumber) AS LineNumber,
	|	&Company AS Company,
	|	AccountsReceivable.Counterparty AS Counterparty,
	|	AccountsReceivable.Contract AS Contract,
	|	CASE
	|		WHEN AccountsReceivable.Counterparty.DoOperationsByOrders
	|			AND AccountsReceivable.SalesOrder <> VALUE(Document.SalesOrder.EmptyRef)
	|			AND AccountsReceivable.SalesOrder <> VALUE(Document.WOrkOrder.EmptyRef)
	|			THEN AccountsReceivable.SalesOrder
	|		ELSE UNDEFINED
	|	END AS Order,
	|	CASE
	|		WHEN AccountsReceivable.Counterparty.DoOperationsByDocuments
	|			THEN AccountsReceivable.Document
	|		ELSE UNDEFINED
	|	END AS Document,
	|	AccountsReceivable.Contract.SettlementsCurrency AS Currency,
	|	CASE
	|		WHEN Not AccountsReceivable.AdvanceFlag
	|			THEN VALUE(Enum.SettlementsTypes.Debt)
	|		WHEN AccountsReceivable.AdvanceFlag
	|			THEN VALUE(Enum.SettlementsTypes.Advance)
	|	END AS SettlementsType,
	|	CASE
	|		WHEN Not AccountsReceivable.AdvanceFlag
	|			THEN VALUE(AccountingRecordType.Debit)
	|		WHEN AccountsReceivable.AdvanceFlag
	|			THEN VALUE(AccountingRecordType.Credit)
	|	END AS RecordKindAccountingJournalEntries,
	|	CASE
	|		WHEN Not AccountsReceivable.AdvanceFlag
	|			THEN &AppearenceOfCustomerLiability
	|		WHEN AccountsReceivable.AdvanceFlag
	|			THEN &CustomerObligationsRepayment
	|	END AS ContentOfAccountingRecord,
	|	CASE
	|		WHEN Not AccountsReceivable.AdvanceFlag
	|			THEN AccountsReceivable.Counterparty.GLAccountCustomerSettlements
	|		WHEN AccountsReceivable.AdvanceFlag
	|			THEN AccountsReceivable.Counterparty.CustomerAdvancesGLAccount
	|	END AS GLAccount,
	|	SUM(AccountsReceivable.AmountCur) AS AmountCur,
	|	SUM(AccountsReceivable.Amount) AS Amount,
	|	SUM(AccountsReceivable.AmountCur) AS AmountForPaymentCur,
	|	SUM(AccountsReceivable.Amount) AS AmountForPayment
	|FROM
	|	Document.OpeningBalanceEntry.AccountsReceivable AS AccountsReceivable
	|WHERE
	|	AccountsReceivable.Ref = &Ref
	|
	|GROUP BY
	|	AccountsReceivable.Counterparty,
	|	AccountsReceivable.Contract,
	|	AccountsReceivable.AdvanceFlag,
	|	AccountsReceivable.SalesOrder,
	|	AccountsReceivable.Document,
	|	AccountsReceivable.Ref,
	|	AccountsReceivable.Ref.Date,
	|	CASE
	|		WHEN Not AccountsReceivable.AdvanceFlag
	|			THEN AccountsReceivable.Counterparty.GLAccountCustomerSettlements
	|		WHEN AccountsReceivable.AdvanceFlag
	|			THEN AccountsReceivable.Counterparty.CustomerAdvancesGLAccount
	|	END,
	|	AccountsReceivable.Contract.SettlementsCurrency,
	|	CASE
	|		WHEN AccountsReceivable.Counterparty.DoOperationsByOrders
	|			AND AccountsReceivable.SalesOrder <> VALUE(Document.SalesOrder.EmptyRef)
	|			AND AccountsReceivable.SalesOrder <> VALUE(Document.WOrkOrder.EmptyRef)
	|			THEN AccountsReceivable.SalesOrder
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN AccountsReceivable.Counterparty.DoOperationsByDocuments
	|			THEN AccountsReceivable.Document
	|		ELSE UNDEFINED
	|	END
	|
	|ORDER BY
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	1 AS Order,
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Ref.Date AS Period,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	&Company AS Company,
	|	DocumentTable.Amount AS Amount,
	|	DocumentTable.Counterparty.GLAccountCustomerSettlements AS AccountDr,
	|	CASE
	|		WHEN DocumentTable.Counterparty.GLAccountCustomerSettlements.Currency
	|			THEN DocumentTable.Contract.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN DocumentTable.Counterparty.GLAccountCustomerSettlements.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END AS AmountCurDr,
	|	&OBEAccount AS AccountCr,
	|	UNDEFINED AS CurrencyCr,
	|	0 AS AmountCurCr,
	|	&AppearenceOfCustomerLiability AS Content
	|FROM
	|	Document.OpeningBalanceEntry.AccountsReceivable AS DocumentTable
	|WHERE
	|	DocumentTable.Amount <> 0
	|	AND DocumentTable.Ref = &Ref
	|	AND Not DocumentTable.AdvanceFlag
	|
	|UNION ALL
	|
	|SELECT
	|	1,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Ref.Date,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	&Company,
	|	DocumentTable.Amount,
	|	&OBEAccount,
	|	UNDEFINED,
	|	0,
	|	DocumentTable.Counterparty.CustomerAdvancesGLAccount,
	|	CASE
	|		WHEN DocumentTable.Counterparty.CustomerAdvancesGLAccount.Currency
	|			THEN DocumentTable.Contract.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.Counterparty.CustomerAdvancesGLAccount.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END,
	|	&CustomerObligationsRepayment
	|FROM
	|	Document.OpeningBalanceEntry.AccountsReceivable AS DocumentTable
	|WHERE
	|	DocumentTable.Amount <> 0
	|	AND DocumentTable.Ref = &Ref
	|	AND DocumentTable.AdvanceFlag
	|
	|ORDER BY
	|	Order,
	|	LineNumber");
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();

	Query.SetParameter("OBEAccount",					Catalogs.DefaultGLAccounts.GetDefaultGLAccount("OpeningBalanceEquity"));
	Query.SetParameter("Ref",							DocumentRefOpeningBalanceEntry);
	Query.SetParameter("Company",						StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("AppearenceOfCustomerLiability",	NStr("en = 'Enter remaining customer debt'", MainLanguageCode));
	Query.SetParameter("CustomerObligationsRepayment",	NStr("en = 'Enter advance balance from customers'", MainLanguageCode));
	
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountsReceivable", ResultsArray[0].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountingJournalEntries", ResultsArray[1].Unload());
	
EndProcedure

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentDataAccountsPayable(DocumentRefOpeningBalanceEntry, StructureAdditionalProperties) Export

	Query = New Query(
	"SELECT
	|	AccountsPayable.Ref.Date AS Period,
	|	CASE
	|		WHEN AccountsPayable.AdvanceFlag
	|			THEN VALUE(AccumulationRecordType.Expense)
	|		ELSE VALUE(AccumulationRecordType.Receipt)
	|	END AS RecordType,
	|	MIN(AccountsPayable.LineNumber) AS LineNumber,
	|	&Company AS Company,
	|	AccountsPayable.Counterparty AS Counterparty,
	|	AccountsPayable.Contract AS Contract,
	|	CASE
	|		WHEN AccountsPayable.Counterparty.DoOperationsByOrders
	|			THEN AccountsPayable.PurchaseOrder
	|		ELSE VALUE(Document.PurchaseOrder.EmptyRef)
	|	END AS Order,
	|	CASE
	|		WHEN AccountsPayable.Counterparty.DoOperationsByDocuments
	|			THEN AccountsPayable.Document
	|		ELSE UNDEFINED
	|	END AS Document,
	|	AccountsPayable.Contract.SettlementsCurrency AS Currency,
	|	CASE
	|		WHEN NOT AccountsPayable.AdvanceFlag
	|			THEN VALUE(Enum.SettlementsTypes.Debt)
	|		WHEN AccountsPayable.AdvanceFlag
	|			THEN VALUE(Enum.SettlementsTypes.Advance)
	|	END AS SettlementsType,
	|	CASE
	|		WHEN NOT AccountsPayable.AdvanceFlag
	|			THEN VALUE(AccountingRecordType.Credit)
	|		WHEN AccountsPayable.AdvanceFlag
	|			THEN VALUE(AccountingRecordType.Debit)
	|	END AS RecordKindAccountingJournalEntries,
	|	CASE
	|		WHEN NOT AccountsPayable.AdvanceFlag
	|			THEN &AppearenceOfLiabilityToVendor
	|		WHEN AccountsPayable.AdvanceFlag
	|			THEN &VendorObligationsRepayment
	|	END AS ContentOfAccountingRecord,
	|	CASE
	|		WHEN NOT AccountsPayable.AdvanceFlag
	|			THEN AccountsPayable.Counterparty.GLAccountVendorSettlements
	|		WHEN AccountsPayable.AdvanceFlag
	|			THEN AccountsPayable.Counterparty.VendorAdvancesGLAccount
	|	END AS GLAccount,
	|	SUM(AccountsPayable.AmountCur) AS AmountCur,
	|	SUM(AccountsPayable.Amount) AS Amount,
	|	SUM(AccountsPayable.Amount) AS AmountForPayment,
	|	SUM(AccountsPayable.AmountCur) AS AmountForPaymentCur
	|FROM
	|	Document.OpeningBalanceEntry.AccountsPayable AS AccountsPayable
	|WHERE
	|	AccountsPayable.Ref = &Ref
	|
	|GROUP BY
	|	AccountsPayable.Counterparty,
	|	AccountsPayable.Contract,
	|	AccountsPayable.AdvanceFlag,
	|	AccountsPayable.PurchaseOrder,
	|	AccountsPayable.Document,
	|	AccountsPayable.Ref,
	|	AccountsPayable.Ref.Date,
	|	CASE
	|		WHEN NOT AccountsPayable.AdvanceFlag
	|			THEN AccountsPayable.Counterparty.GLAccountVendorSettlements
	|		WHEN AccountsPayable.AdvanceFlag
	|			THEN AccountsPayable.Counterparty.VendorAdvancesGLAccount
	|	END,
	|	AccountsPayable.Contract.SettlementsCurrency,
	|	CASE
	|		WHEN AccountsPayable.Counterparty.DoOperationsByOrders
	|			THEN AccountsPayable.PurchaseOrder
	|		ELSE VALUE(Document.PurchaseOrder.EmptyRef)
	|	END,
	|	CASE
	|		WHEN AccountsPayable.Counterparty.DoOperationsByDocuments
	|			THEN AccountsPayable.Document
	|		ELSE UNDEFINED
	|	END
	|
	|ORDER BY
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	1 AS Order,
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Ref.Date AS Period,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	&Company AS Company,
	|	DocumentTable.Amount AS Amount,
	|	&OBEAccount AS AccountDr,
	|	UNDEFINED AS CurrencyDr,
	|	0 AS AmountCurDr,
	|	DocumentTable.Counterparty.GLAccountVendorSettlements AS AccountCr,
	|	CASE
	|		WHEN DocumentTable.Counterparty.GLAccountVendorSettlements.Currency
	|			THEN DocumentTable.Contract.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	CASE
	|		WHEN DocumentTable.Counterparty.GLAccountVendorSettlements.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END AS AmountCurCr,
	|	&AppearenceOfLiabilityToVendor AS Content
	|FROM
	|	Document.OpeningBalanceEntry.AccountsPayable AS DocumentTable
	|WHERE
	|	DocumentTable.Amount <> 0
	|	AND DocumentTable.Ref = &Ref
	|	AND NOT DocumentTable.AdvanceFlag
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Ref.Date,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	&Company,
	|	DocumentTable.Amount,
	|	DocumentTable.Counterparty.VendorAdvancesGLAccount,
	|	CASE
	|		WHEN DocumentTable.Counterparty.VendorAdvancesGLAccount.Currency
	|			THEN DocumentTable.Contract.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.Counterparty.VendorAdvancesGLAccount.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END,
	|	&OBEAccount,
	|	UNDEFINED,
	|	0,
	|	&VendorObligationsRepayment
	|FROM
	|	Document.OpeningBalanceEntry.AccountsPayable AS DocumentTable
	|WHERE
	|	DocumentTable.Amount <> 0
	|	AND DocumentTable.Ref = &Ref
	|	AND DocumentTable.AdvanceFlag
	|
	|ORDER BY
	|	Order,
	|	LineNumber");
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();

	Query.SetParameter("OBEAccount",					Catalogs.DefaultGLAccounts.GetDefaultGLAccount("OpeningBalanceEquity"));
	Query.SetParameter("Ref",							DocumentRefOpeningBalanceEntry);
	Query.SetParameter("Company",						StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("AppearenceOfLiabilityToVendor",	NStr("en = 'Enter remaining debt to suppliers'", MainLanguageCode));
	Query.SetParameter("VendorObligationsRepayment",	NStr("en = 'Enter balance of advances to suppliers'", MainLanguageCode));
	
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountsPayable", ResultsArray[0].Unload());
	
	If StructureAdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries.Count() > 0 Then
		Selection = ResultsArray[1].Select();
		While Selection.Next() Do
			NewRow = StructureAdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries.Add();
			FillPropertyValues(NewRow, Selection);
		EndDo;
	Else
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountingJournalEntries", ResultsArray[1].Unload());
	EndIf;
	
EndProcedure

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentDataUnallocatedExpenses(DocumentRefOpeningBalanceEntry, StructureAdditionalProperties) Export

	Query = New Query(
	"SELECT
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Ref.Date AS Period,
	|	&Company AS Company,
	|	DocumentTable.Document AS Document,
	|	CASE
	|		WHEN VALUETYPE(DocumentTable.Document) = Type(Document.ExpenseReport)
	|			THEN VALUE(Catalog.CashFlowItems.PaymentToVendor)
	|		ELSE DocumentTable.Document.Item
	|	END AS Item,
	|	0 AS AmountIncome,
	|	DocumentTable.Amount AS AmountExpense
	|FROM
	|	Document.OpeningBalanceEntry.AccountsPayable AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.Ref = &Ref
	|	AND DocumentTable.AdvanceFlag
	|
	|UNION ALL
	|
	|SELECT
	|	VALUE(AccumulationRecordType.Receipt),
	|	DocumentTable.LineNumber,
	|	DocumentTable.Ref.Date,
	|	&Company,
	|	DocumentTable.Document,
	|	DocumentTable.Document.Item,
	|	DocumentTable.Amount,
	|	0
	|FROM
	|	Document.OpeningBalanceEntry.AccountsReceivable AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.Ref = &Ref
	|	AND DocumentTable.AdvanceFlag
	|
	|ORDER BY
	|	LineNumber");
 
	Query.SetParameter("Ref", DocumentRefOpeningBalanceEntry);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("IncomeAndExpensesAccountingCashMethod", StructureAdditionalProperties.AccountingPolicy.IncomeAndExpensesAccountingCashMethod);
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableUnallocatedExpenses", QueryResult.Unload());
	
EndProcedure

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentDataIncomeAndExpensesCashMethod(DocumentRefOpeningBalanceEntry, StructureAdditionalProperties) Export

	Query = New Query(
	"SELECT
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Ref.Date AS Period,
	|	&Company AS Company,
	|	UNDEFINED AS BusinessLine,
	|	CASE
	|		WHEN VALUETYPE(DocumentTable.Document) = Type(Document.ExpenseReport)
	|			THEN VALUE(Catalog.CashFlowItems.PaymentToVendor)
	|		ELSE DocumentTable.Document.Item
	|	END AS Item,
	|	0 AS AmountIncome,
	|	DocumentTable.Amount AS AmountExpense
	|FROM
	|	Document.OpeningBalanceEntry.AccountsPayable AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.Ref = &Ref
	|	AND DocumentTable.AdvanceFlag
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentTable.LineNumber,
	|	DocumentTable.Ref.Date,
	|	&Company,
	|	UNDEFINED,
	|	DocumentTable.Document.Item,
	|	DocumentTable.Amount,
	|	0
	|FROM
	|	Document.OpeningBalanceEntry.AccountsReceivable AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.Ref = &Ref
	|	AND DocumentTable.AdvanceFlag
	|
	|ORDER BY
	|	DocumentTable.LineNumber");
 
	Query.SetParameter("Ref", DocumentRefOpeningBalanceEntry);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("IncomeAndExpensesAccountingCashMethod", StructureAdditionalProperties.AccountingPolicy.IncomeAndExpensesAccountingCashMethod);
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpensesCashMethod", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentDataIncomeAndExpensesRetained(DocumentRefOpeningBalanceEntry, StructureAdditionalProperties)
	
	Query = New Query(
	"SELECT
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Ref.Date AS Period,
	|	&Company AS Company,
	|	DocumentTable.Document AS Document,
	|	VALUE(Catalog.LinesOfBusiness.MainLine) AS BusinessLine,
	|	0 AS AmountIncome,
	|	DocumentTable.Amount AS AmountExpense
	|FROM
	|	Document.OpeningBalanceEntry.AccountsPayable AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.Ref = &Ref
	|	AND (NOT DocumentTable.AdvanceFlag)
	|
	|UNION ALL
	|
	|SELECT
	|	VALUE(AccumulationRecordType.Receipt),
	|	DocumentTable.LineNumber,
	|	DocumentTable.Ref.Date,
	|	&Company,
	|	DocumentTable.Document,
	|	VALUE(Catalog.LinesOfBusiness.MainLine),
	|	DocumentTable.Amount,
	|	0
	|FROM
	|	Document.OpeningBalanceEntry.AccountsReceivable AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND DocumentTable.Ref = &Ref
	|	AND (NOT DocumentTable.AdvanceFlag)
	|
	|ORDER BY
	|	LineNumber");

	Query.SetParameter("Ref", DocumentRefOpeningBalanceEntry);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("IncomeAndExpensesAccountingCashMethod", StructureAdditionalProperties.AccountingPolicy.IncomeAndExpensesAccountingCashMethod);
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpensesRetained", QueryResult.Unload());
	
EndProcedure

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure DocumentDataInitializationCashAssets(DocumentRefOpeningBalanceEntry, StructureAdditionalProperties) Export

	Query = New Query(
	"SELECT
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	CashAssets.Ref.Date AS Period,
	|	MIN(CashAssets.LineNumber) AS LineNumber,
	|	&Company AS Company,
	|	CASE
	|		WHEN VALUETYPE(CashAssets.BankAccountPettyCash) = Type(Catalog.CashAccounts)
	|			THEN VALUE(Enum.CashAssetTypes.Cash)
	|		ELSE VALUE(Enum.CashAssetTypes.Noncash)
	|	END AS CashAssetsType,
	|	CashAssets.BankAccountPettyCash AS BankAccountPettyCash,
	|	CashAssets.CashCurrency AS Currency,
	|	CashAssets.BankAccountPettyCash.GLAccount AS GLAccount,
	|	&ContentOfAccountingRecord AS ContentOfAccountingRecord,
	|	SUM(CashAssets.AmountCur) AS AmountCur,
	|	SUM(CashAssets.Amount) AS Amount
	|FROM
	|	Document.OpeningBalanceEntry.CashAssets AS CashAssets
	|WHERE
	|	CashAssets.Ref = &Ref
	|
	|GROUP BY
	|	CashAssets.Ref,
	|	CashAssets.CashCurrency,
	|	CASE
	|		WHEN VALUETYPE(CashAssets.BankAccountPettyCash) = Type(Catalog.CashAccounts)
	|			THEN VALUE(Enum.CashAssetTypes.Cash)
	|		ELSE VALUE(Enum.CashAssetTypes.Noncash)
	|	END,
	|	CashAssets.BankAccountPettyCash,
	|	CashAssets.Ref.Date,
	|	CashAssets.BankAccountPettyCash.GLAccount
	|
	|ORDER BY
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	1 AS Order,
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Ref.Date AS Period,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	&Company AS Company,
	|	DocumentTable.Amount AS Amount,
	|	DocumentTable.BankAccountPettyCash.GLAccount AS AccountDr,
	|	CASE
	|		WHEN DocumentTable.BankAccountPettyCash.GLAccount.Currency
	|			THEN DocumentTable.CashCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN DocumentTable.BankAccountPettyCash.GLAccount.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END AS AmountCurDr,
	|	&OBEAccount AS AccountCr,
	|	UNDEFINED AS CurrencyCr,
	|	0 AS AmountCurCr,
	|	&ContentOfAccountingRecord AS Content
	|FROM
	|	Document.OpeningBalanceEntry.CashAssets AS DocumentTable
	|WHERE
	|	DocumentTable.Amount <> 0
	|	AND DocumentTable.Ref = &Ref");
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();

	Query.SetParameter("OBEAccount",				Catalogs.DefaultGLAccounts.GetDefaultGLAccount("OpeningBalanceEquity"));
	Query.SetParameter("Ref",						DocumentRefOpeningBalanceEntry);
	Query.SetParameter("Company",					StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("ContentOfAccountingRecord",	NStr("en = 'Enter cash balance'", MainLanguageCode));
	
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableCashAssets", ResultsArray[0].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountingJournalEntries", ResultsArray[1].Unload());
	
EndProcedure

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeInventoryDocumentData(DocumentRefOpeningBalanceEntry, StructureAdditionalProperties) Export

	Query = New Query(
	"SELECT
	|	Header.Ref AS Ref,
	|	Header.Date AS Date,
	|	&Company AS Company
	|INTO Header
	|FROM
	|	Document.OpeningBalanceEntry AS Header
	|WHERE
	|	Header.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	OpeningBalanceEntryInventory.Order AS Order,
	|	OpeningBalanceEntryInventory.LineNumber AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	OpeningBalanceEntryInventory.Period AS Period,
	|	OpeningBalanceEntryInventory.Company AS Company,
	|	OpeningBalanceEntryInventory.StructuralUnit AS StructuralUnit,
	|	OpeningBalanceEntryInventory.GLAccount AS GLAccount,
	|	OpeningBalanceEntryInventory.Products AS Products,
	|	OpeningBalanceEntryInventory.Characteristic AS Characteristic,
	|	OpeningBalanceEntryInventory.Batch AS Batch,
	|	OpeningBalanceEntryInventory.SalesOrder AS SalesOrder,
	|	OpeningBalanceEntryInventory.Quantity AS Quantity,
	|	OpeningBalanceEntryInventory.Amount AS Amount,
	|	TRUE AS FixedCost,
	|	OpeningBalanceEntryInventory.ContentOfAccountingRecord AS ContentOfAccountingRecord,
	|	FALSE AS OfflineRecord
	|FROM
	|	(SELECT
	|		0 AS Order,
	|		OpeningBalanceEntryInventory.LineNumber AS LineNumber,
	|		OpeningBalanceEntryInventory.Ref.Date AS Period,
	|		&Company AS Company,
	|		OpeningBalanceEntryInventory.StructuralUnit AS StructuralUnit,
	|		OpeningBalanceEntryInventory.InventoryGLAccount AS GLAccount,
	|		OpeningBalanceEntryInventory.Products AS Products,
	|		CASE
	|			WHEN &UseCharacteristics
	|				THEN OpeningBalanceEntryInventory.Characteristic
	|			ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|		END AS Characteristic,
	|		CASE
	|			WHEN &UseBatches
	|				THEN OpeningBalanceEntryInventory.Batch
	|			ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|		END AS Batch,
	|		CASE
	|			WHEN OpeningBalanceEntryInventory.SalesOrder = VALUE(Document.SalesOrder.EmptyRef)
	|					OR OpeningBalanceEntryInventory.SalesOrder = VALUE(Document.WorkOrder.EmptyRef)
	|				THEN UNDEFINED
	|			ELSE OpeningBalanceEntryInventory.SalesOrder
	|		END AS SalesOrder,
	|		CASE
	|			WHEN VALUETYPE(OpeningBalanceEntryInventory.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|				THEN OpeningBalanceEntryInventory.Quantity
	|			ELSE OpeningBalanceEntryInventory.Quantity * OpeningBalanceEntryInventory.MeasurementUnit.Factor
	|		END AS Quantity,
	|		OpeningBalanceEntryInventory.Amount AS Amount,
	|		VALUE(AccountingRecordType.Debit) AS RecordKindAccountingJournalEntries,
	|		&InventoryIncrease AS ContentOfAccountingRecord
	|	FROM
	|		Document.OpeningBalanceEntry.Inventory AS OpeningBalanceEntryInventory
	|	WHERE
	|		OpeningBalanceEntryInventory.Ref = &Ref
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		1,
	|		EnteringOpeningBalancesDirectCost.LineNumber,
	|		EnteringOpeningBalancesDirectCost.Ref.Date,
	|		&Company,
	|		EnteringOpeningBalancesDirectCost.StructuralUnit,
	|		EnteringOpeningBalancesDirectCost.GLExpenseAccount,
	|		VALUE(Catalog.Products.EmptyRef),
	|		VALUE(Catalog.ProductsCharacteristics.EmptyRef),
	|		VALUE(Catalog.ProductsBatches.EmptyRef),
	|		EnteringOpeningBalancesDirectCost.SalesOrder,
	|		0,
	|		EnteringOpeningBalancesDirectCost.Amount,
	|		VALUE(AccountingRecordType.Debit),
	|		&ExpediturePosting
	|	FROM
	|		Document.OpeningBalanceEntry.DirectCost AS EnteringOpeningBalancesDirectCost
	|	WHERE
	|		EnteringOpeningBalancesDirectCost.Ref = &Ref) AS OpeningBalanceEntryInventory
	|
	|UNION ALL
	|
	|SELECT
	|	4,
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
	|	OfflineRecords.FixedCost,
	|	OfflineRecords.ContentOfAccountingRecord,
	|	OfflineRecords.OfflineRecord
	|FROM
	|	AccumulationRegister.Inventory AS OfflineRecords
	|WHERE
	|	OfflineRecords.Recorder = &Ref
	|	AND OfflineRecords.OfflineRecord
	|
	|ORDER BY
	|	Order,
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	0 AS Order,
	|	OpeningBalanceEntryInventory.LineNumber AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	OpeningBalanceEntryInventory.Ref.Date AS Period,
	|	&Company AS Company,
	|	OpeningBalanceEntryInventory.StructuralUnit AS StructuralUnit,
	|	CASE
	|		WHEN &UseStorageBins
	|			THEN OpeningBalanceEntryInventory.Cell
	|		ELSE UNDEFINED
	|	END AS Cell,
	|	OpeningBalanceEntryInventory.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN OpeningBalanceEntryInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseBatches
	|			THEN OpeningBalanceEntryInventory.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS Batch,
	|	CASE
	|		WHEN VALUETYPE(OpeningBalanceEntryInventory.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN OpeningBalanceEntryInventory.Quantity
	|		ELSE OpeningBalanceEntryInventory.Quantity * OpeningBalanceEntryInventory.MeasurementUnit.Factor
	|	END AS Quantity
	|FROM
	|	Document.OpeningBalanceEntry.Inventory AS OpeningBalanceEntryInventory
	|WHERE
	|	OpeningBalanceEntryInventory.Ref = &Ref
	|
	|ORDER BY
	|	Order,
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	1 AS Order,
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Ref.Date AS Period,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	&Company AS Company,
	|	DocumentTable.Amount AS Amount,
	|	DocumentTable.InventoryGLAccount AS AccountDr,
	|	UNDEFINED AS CurrencyDr,
	|	0 AS AmountCurDr,
	|	&OBEAccount AS AccountCr,
	|	UNDEFINED AS CurrencyCr,
	|	0 AS AmountCurCr,
	|	&InventoryIncrease AS Content
	|FROM
	|	Document.OpeningBalanceEntry.Inventory AS DocumentTable
	|WHERE
	|	DocumentTable.Amount <> 0
	|	AND DocumentTable.Ref = &Ref
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Ref.Date,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	&Company,
	|	DocumentTable.Amount,
	|	DocumentTable.GLExpenseAccount,
	|	UNDEFINED,
	|	0,
	|	&OBEAccount,
	|	UNDEFINED,
	|	0,
	|	&ExpediturePosting
	|FROM
	|	Document.OpeningBalanceEntry.DirectCost AS DocumentTable
	|WHERE
	|	DocumentTable.Amount <> 0
	|	AND DocumentTable.Ref = &Ref
	|
	|ORDER BY
	|	Order,
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	0 AS Order,
	|	MIN(Inventory.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	Header.Date AS Period,
	|	Header.Company AS Company,
	|	Inventory.StructuralUnit AS StructuralUnit,
	|	Inventory.Products AS Products,
	|	CASE
	|		WHEN Inventory.SalesOrder <> VALUE(Document.SalesOrder.EmptyRef)
	|				AND Inventory.SalesOrder <> VALUE(Document.WorkOrder.EmptyRef)
	|			THEN Inventory.SalesOrder
	|		ELSE UNDEFINED
	|	END AS SalesOrder,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN Inventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	Header.Ref AS CostLayer,
	|	CASE
	|		WHEN &UseBatches
	|			THEN Inventory.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS Batch,
	|	Inventory.InventoryGLAccount AS GLAccount,
	|	SUM(CASE
	|			WHEN VALUETYPE(Inventory.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|				THEN Inventory.Quantity
	|			ELSE Inventory.Quantity * Inventory.MeasurementUnit.Factor
	|		END) AS Quantity,
	|	SUM(Inventory.Amount) AS Amount,
	|	TRUE AS SourceRecord
	|FROM
	|	Header AS Header
	|		INNER JOIN Document.OpeningBalanceEntry.Inventory AS Inventory
	|		ON (Inventory.Ref = Header.Ref)
	|		INNER JOIN Catalog.BusinessUnits AS BusinessUnits
	|		ON (Inventory.StructuralUnit = BusinessUnits.Ref)
	|WHERE
	|	&UseFIFO
	|
	|GROUP BY
	|	Header.Date,
	|	Header.Company,
	|	Inventory.StructuralUnit,
	|	Inventory.Products,
	|	CASE
	|		WHEN Inventory.SalesOrder <> VALUE(Document.SalesOrder.EmptyRef)
	|				AND Inventory.SalesOrder <> VALUE(Document.WorkOrder.EmptyRef)
	|			THEN Inventory.SalesOrder
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN Inventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END,
	|	Header.Ref,
	|	CASE
	|		WHEN &UseBatches
	|			THEN Inventory.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END,
	|	Inventory.InventoryGLAccount
	|
	|ORDER BY
	|	Order,
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableInventory.Ref.Date AS Period,
	|	TableInventory.Ref.Date AS EventDate,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	VALUE(Enum.SerialNumbersOperations.Receipt) AS Operation,
	|	TableSerialNumbers.SerialNumber AS SerialNumber,
	|	&Company AS Company,
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	TableInventory.Cell AS Cell,
	|	1 AS Quantity
	|FROM
	|	Document.OpeningBalanceEntry.Inventory AS TableInventory
	|		INNER JOIN Document.OpeningBalanceEntry.SerialNumbers AS TableSerialNumbers
	|		ON TableInventory.Ref = TableSerialNumbers.Ref
	|			AND TableInventory.ConnectionKey = TableSerialNumbers.ConnectionKey
	|WHERE
	|	TableInventory.Ref = &Ref
	|	AND TableSerialNumbers.Ref = &Ref
	|	AND &UseSerialNumbers");
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();

	Query.SetParameter("OBEAccount", Catalogs.DefaultGLAccounts.GetDefaultGLAccount("OpeningBalanceEquity"));
	Query.SetParameter("Ref", DocumentRefOpeningBalanceEntry);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("UseCharacteristics", StructureAdditionalProperties.AccountingPolicy.UseCharacteristics);
	Query.SetParameter("UseBatches", StructureAdditionalProperties.AccountingPolicy.UseBatches);
	Query.SetParameter("UseStorageBins", StructureAdditionalProperties.AccountingPolicy.UseStorageBins);
	Query.SetParameter("UseReservation", Constants.UseInventoryReservation.Get());
	Query.SetParameter("InventoryIncrease", NStr("en = 'Inventory receipt'", MainLanguageCode));
	Query.SetParameter("ExpediturePosting", NStr("en = 'Costs capitalization'", MainLanguageCode));
	Query.SetParameter("InventoryReception", NStr("en = 'Inventory receipt'", MainLanguageCode));
	Query.SetParameter("UseSerialNumbers", StructureAdditionalProperties.AccountingPolicy.UseSerialNumbers);
	Query.SetParameter("UseFIFO", StructureAdditionalProperties.AccountingPolicy.UseFIFO);
	
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventory", ResultsArray[1].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryInWarehouses", ResultsArray[2].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountingJournalEntries", ResultsArray[3].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryCostLayer", ResultsArray[4].Unload());
	
	// Serial numbers
	QueryResult = ResultsArray[5].Unload();
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbersInWarranty", QueryResult);
	If StructureAdditionalProperties.AccountingPolicy.SerialNumbersBalance Then
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbersBalance", QueryResult);
	Else
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbersBalance", New ValueTable);
	EndIf;

EndProcedure

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure DataInitializationFixedAssetsDataInitialization(DocumentRefOpeningBalanceEntry, StructureAdditionalProperties)

	Query = New Query(
	"SELECT
	|	DocumentTable.Ref.Date AS Date,
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.FixedAsset AS FixedAsset,
	|	DocumentTable.FixedAsset.DepreciationMethod AS DepreciationMethod,
	|	DocumentTable.FixedAsset.InitialCost AS OriginalCost,
	|	DocumentTable.FixedAssetCurrentCondition AS FixedAssetCurrentCondition,
	|	DocumentTable.CurrentOutputQuantity AS CurrentOutputQuantity,
	|	DocumentTable.CurrentDepreciationAccrued AS CurrentDepreciationAccrued,
	|	DocumentTable.AmountOfProductsServicesForDepreciationCalculation AS AmountOfProductsServicesForDepreciationCalculation,
	|	DocumentTable.StructuralUnit AS StructuralUnit,
	|	TRUE AS EnterIntoService,
	|	DocumentTable.AccrueDepreciation AS AccrueDepreciation,
	|	CASE
	|		WHEN DocumentTable.CurrentDepreciationAccrued <> 0
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS AccrueDepreciationInCurrentMonth,
	|	DocumentTable.UsagePeriodForDepreciationCalculation AS UsagePeriodForDepreciationCalculation,
	|	DocumentTable.GLExpenseAccount AS GLExpenseAccount,
	|	DocumentTable.BusinessLine AS BusinessLine
	|INTO TemporaryTableFixedAssets
	|FROM
	|	Document.OpeningBalanceEntry.FixedAssets AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Date AS Period,
	|	DocumentTable.FixedAsset AS FixedAsset,
	|	&Company AS Company,
	|	DocumentTable.FixedAssetCurrentCondition AS State,
	|	DocumentTable.AccrueDepreciation AS AccrueDepreciation,
	|	DocumentTable.AccrueDepreciationInCurrentMonth AS AccrueDepreciationInCurrentMonth
	|FROM
	|	TemporaryTableFixedAssets AS DocumentTable
	|
	|ORDER BY
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Date AS Period,
	|	DocumentTable.FixedAsset AS FixedAsset,
	|	&Company AS Company,
	|	DocumentTable.AmountOfProductsServicesForDepreciationCalculation AS AmountOfProductsServicesForDepreciationCalculation,
	|	DocumentTable.OriginalCost AS CostForDepreciationCalculation,
	|	DocumentTable.AccrueDepreciationInCurrentMonth AS ApplyInCurrentMonth,
	|	DocumentTable.UsagePeriodForDepreciationCalculation AS UsagePeriodForDepreciationCalculation,
	|	DocumentTable.GLExpenseAccount AS GLExpenseAccount,
	|	DocumentTable.StructuralUnit AS StructuralUnit,
	|	DocumentTable.BusinessLine AS BusinessLine
	|FROM
	|	TemporaryTableFixedAssets AS DocumentTable
	|
	|ORDER BY
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	1 AS Order,
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Date AS Period,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	&Company AS Company,
	|	DocumentTable.FixedAsset AS FixedAsset,
	|	DocumentTable.OriginalCost AS Cost,
	|	0 AS Depreciation,
	|	&FixedAssetAcceptanceForAccounting AS ContentOfAccountingRecord
	|FROM
	|	TemporaryTableFixedAssets AS DocumentTable
	|WHERE
	|	DocumentTable.OriginalCost > 0
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	VALUE(AccumulationRecordType.Receipt),
	|	&Company,
	|	DocumentTable.FixedAsset,
	|	0,
	|	DocumentTable.CurrentDepreciationAccrued,
	|	&AccrueDepreciation
	|FROM
	|	TemporaryTableFixedAssets AS DocumentTable
	|WHERE
	|	DocumentTable.CurrentDepreciationAccrued > 0
	|
	|ORDER BY
	|	Order,
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Date AS Period,
	|	&Company AS Company,
	|	DocumentTable.FixedAsset AS FixedAsset,
	|	DocumentTable.CurrentOutputQuantity AS Quantity
	|FROM
	|	TemporaryTableFixedAssets AS DocumentTable
	|WHERE
	|	DocumentTable.DepreciationMethod = VALUE(Enum.FixedAssetDepreciationMethods.ProportionallyToProductsVolume)
	|
	|ORDER BY
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	1 AS Order,
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Date AS Period,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	&Company AS Company,
	|	DocumentTable.OriginalCost AS Amount,
	|	DocumentTable.FixedAsset.GLAccount AS AccountDr,
	|	CASE
	|		WHEN DocumentTable.FixedAsset.GLAccount.Currency
	|			THEN UNDEFINED
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN DocumentTable.FixedAsset.GLAccount.Currency
	|			THEN 0
	|		ELSE 0
	|	END AS AmountCurDr,
	|	&OBEAccount AS AccountCr,
	|	UNDEFINED AS CurrencyCr,
	|	0 AS AmountCurCr,
	|	&FixedAssetAcceptanceForAccounting AS Content
	|FROM
	|	TemporaryTableFixedAssets AS DocumentTable
	|WHERE
	|	DocumentTable.OriginalCost > 0
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	&Company,
	|	DocumentTable.CurrentDepreciationAccrued,
	|	&OBEAccount,
	|	UNDEFINED,
	|	0,
	|	DocumentTable.FixedAsset.DepreciationAccount,
	|	CASE
	|		WHEN DocumentTable.FixedAsset.DepreciationAccount.Currency
	|			THEN UNDEFINED
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.FixedAsset.DepreciationAccount.Currency
	|			THEN 0
	|		ELSE 0
	|	END,
	|	&AccrueDepreciation
	|FROM
	|	TemporaryTableFixedAssets AS DocumentTable
	|WHERE
	|	DocumentTable.CurrentDepreciationAccrued > 0
	|
	|ORDER BY
	|	Order,
	|	LineNumber");
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();

	Query.SetParameter("OBEAccount", Catalogs.DefaultGLAccounts.GetDefaultGLAccount("OpeningBalanceEquity"));
	Query.SetParameter("Ref", DocumentRefOpeningBalanceEntry);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("FixedAssetAcceptanceForAccounting", NStr("en = 'Enter opening balance of capital assets'", MainLanguageCode));
	Query.SetParameter("AccrueDepreciation", NStr("en = 'Enter opening balance for depreciation'", MainLanguageCode));
	
	ResultsArray = Query.ExecuteBatch();

	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableFixedAssetsStates", ResultsArray[1].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableFixedAssetParameters", ResultsArray[2].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableFixedAssets", ResultsArray[3].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableFixedAssetUsage", ResultsArray[4].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountingJournalEntries", ResultsArray[5].Unload());

EndProcedure

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefOpeningBalanceEntry, StructureAdditionalProperties) Export

	AccountingSection = DocumentRefOpeningBalanceEntry.AccountingSection;

	If AccountingSection = "Property" Then

		DataInitializationFixedAssetsDataInitialization(DocumentRefOpeningBalanceEntry, StructureAdditionalProperties);

	ElsIf AccountingSection = "Inventory" Then

		InitializeInventoryDocumentData(DocumentRefOpeningBalanceEntry, StructureAdditionalProperties);

	ElsIf AccountingSection = "Cash assets" Then

		DocumentDataInitializationCashAssets(DocumentRefOpeningBalanceEntry, StructureAdditionalProperties);

	ElsIf AccountingSection = "Accounts payable and customers" Then

		InitializeDocumentDataAccountsReceivable(DocumentRefOpeningBalanceEntry, StructureAdditionalProperties);
		InitializeDocumentDataAccountsPayable(DocumentRefOpeningBalanceEntry, StructureAdditionalProperties);
		InitializeDocumentDataUnallocatedExpenses(DocumentRefOpeningBalanceEntry, StructureAdditionalProperties);
		InitializeDocumentDataIncomeAndExpensesCashMethod(DocumentRefOpeningBalanceEntry, StructureAdditionalProperties);
		InitializeDocumentDataIncomeAndExpensesRetained(DocumentRefOpeningBalanceEntry, StructureAdditionalProperties);
		InitializeInvoicesAndOrdersPaymentDocumentData(DocumentRefOpeningBalanceEntry, StructureAdditionalProperties);
		
	ElsIf AccountingSection = "Tax settlements" Then

		InitializeDocumentDataTaxesSettlements(DocumentRefOpeningBalanceEntry, StructureAdditionalProperties);

	ElsIf AccountingSection = "Personnel settlements" Then

		InitializeDocumentDataPayroll(DocumentRefOpeningBalanceEntry, StructureAdditionalProperties);

	ElsIf AccountingSection = "Settlements with advance holders" Then
		
		InitializeDocumentDataAdvanceHolders(DocumentRefOpeningBalanceEntry, StructureAdditionalProperties);

	ElsIf AccountingSection = "Other sections" Then

		InitializeDocumentDataAccountingJournalEntries(DocumentRefOpeningBalanceEntry, StructureAdditionalProperties);

	EndIf;

EndProcedure

// Control

// Control of the accounting section CashAssets.
//
Procedure RunControlCashAssets(DocumentRefOpeningBalanceEntry, AdditionalProperties, Cancel, PostingDelete = False)
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// If temporary tables
	// "RegisterRecordsCashAssetsChange" contain entries, it is necessary to perform control of negative balances.
	
	If StructureTemporaryTables.RegisterRecordsCashAssetsChange Then
		
		Query = New Query(
		"SELECT
		|	RegisterRecordsCashAssetsChange.LineNumber AS LineNumber,
		|	REFPRESENTATION(RegisterRecordsCashAssetsChange.Company) AS CompanyPresentation,
		|	REFPRESENTATION(RegisterRecordsCashAssetsChange.BankAccountPettyCash) AS BankAccountCashPresentation,
		|	REFPRESENTATION(RegisterRecordsCashAssetsChange.Currency) AS CurrencyPresentation,
		|	REFPRESENTATION(RegisterRecordsCashAssetsChange.CashAssetsType) AS CashAssetsTypeRepresentation,
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
		|		LEFT JOIN AccumulationRegister.CashAssets.Balance(
		|				&ControlTime,
		|				(Company, CashAssetsType, BankAccountPettyCash, Currency) In
		|					(SELECT
		|						RegisterRecordsCashAssetsChange.Company AS Company,
		|						RegisterRecordsCashAssetsChange.CashAssetsType AS CashAssetsType,
		|						RegisterRecordsCashAssetsChange.BankAccountPettyCash AS BankAccountPettyCash,
		|						RegisterRecordsCashAssetsChange.Currency AS Currency
		|					FROM
		|						RegisterRecordsCashAssetsChange AS RegisterRecordsCashAssetsChange)) AS CashAssetsBalances
		|		ON RegisterRecordsCashAssetsChange.Company = CashAssetsBalances.Company
		|			AND RegisterRecordsCashAssetsChange.CashAssetsType = CashAssetsBalances.CashAssetsType
		|			AND RegisterRecordsCashAssetsChange.BankAccountPettyCash = CashAssetsBalances.BankAccountPettyCash
		|			AND RegisterRecordsCashAssetsChange.Currency = CashAssetsBalances.Currency
		|WHERE
		|	ISNULL(CashAssetsBalances.AmountCurBalance, 0) < 0
		|
		|ORDER BY
		|	LineNumber");
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.SetParameter("ControlTime", AdditionalProperties.ForPosting.ControlTime);
		
		ResultsArray = Query.Execute();
		
		// Negative balance on cash.
		If Not ResultsArray.IsEmpty() Then
			
			DocumentObjectOpeningBalanceEntry = DocumentRefOpeningBalanceEntry.GetObject();
			
			QueryResultSelection = ResultsArray.Select();
			DriveServer.ShowMessageAboutPostingToCashAssetsRegisterErrors(DocumentObjectOpeningBalanceEntry, QueryResultSelection, Cancel);
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Control of the accounting section AccountsReceivable.
//
Procedure RunControlCustomerAccounts(DocumentRefOpeningBalanceEntry, AdditionalProperties, Cancel, PostingDelete = False)
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// If temporary tables
	// "RegisterRecordsAccountsReceivableChange" contain entries, it is necessary to perform control of negative balances.
	
	If StructureTemporaryTables.RegisterRecordsAccountsReceivableChange Then
		
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
		|	LineNumber");
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.SetParameter("ControlTime", AdditionalProperties.ForPosting.ControlTime);
		
		ResultsArray = Query.Execute();
		
		// Negative balance on accounts receivable.
		If Not ResultsArray.IsEmpty() Then
			
			DocumentObjectOpeningBalanceEntry = DocumentRefOpeningBalanceEntry.GetObject();
			
			QueryResultSelection = ResultsArray.Select();
			DriveServer.ShowMessageAboutPostingToAccountsReceivableRegisterErrors(DocumentObjectOpeningBalanceEntry, QueryResultSelection, Cancel);
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Control of the accounting section AccountsPayable.
//
Procedure RunControlAccountsPayable(DocumentRefOpeningBalanceEntry, AdditionalProperties, Cancel, PostingDelete = False)
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// If temporary tables
	// "TransferAccountsPayableChange" contain entries, it is necessary to perform control of negative balances.
	
	If StructureTemporaryTables.RegisterRecordsSuppliersSettlementsChange Then
		
		Query = New Query(
		"SELECT
		|	RegisterRecordsSuppliersSettlementsChange.LineNumber AS LineNumber,
		|	REFPRESENTATION(RegisterRecordsSuppliersSettlementsChange.Company) AS CompanyPresentation,
		|	REFPRESENTATION(RegisterRecordsSuppliersSettlementsChange.Counterparty) AS CounterpartyPresentation,
		|	REFPRESENTATION(RegisterRecordsSuppliersSettlementsChange.Contract) AS ContractPresentation,
		|	REFPRESENTATION(RegisterRecordsSuppliersSettlementsChange.Contract.SettlementsCurrency) AS CurrencyPresentation,
		|	REFPRESENTATION(RegisterRecordsSuppliersSettlementsChange.Document) AS DocumentPresentation,
		|	REFPRESENTATION(RegisterRecordsSuppliersSettlementsChange.Order) AS OrderPresentation,
		|	REFPRESENTATION(RegisterRecordsSuppliersSettlementsChange.SettlementsType) AS CalculationsTypesPresentation,
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
		
		ResultsArray = Query.Execute();
		
		// Negative balance on accounts payable.
		If Not ResultsArray.IsEmpty() Then
			
			DocumentObjectOpeningBalanceEntry = DocumentRefOpeningBalanceEntry.GetObject();
			
			QueryResultSelection = ResultsArray.Select();
			DriveServer.ShowMessageAboutPostingToAccountsPayableRegisterErrors(DocumentObjectOpeningBalanceEntry, QueryResultSelection, Cancel);
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Control of the accounting section AdvanceHolders.
//
Procedure RunControlAdvanceHolders(DocumentRefOpeningBalanceEntry, AdditionalProperties, Cancel, PostingDelete = False)
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// If temporary tables
	// "RegisterRecordsAdvanceHoldersChange" contain entries, it is necessary to perform control of negative balances.
	
	If StructureTemporaryTables.RegisterRecordsAdvanceHoldersChange Then
		
		Query = New Query(
		"SELECT
		|	RegisterRecordsAdvanceHoldersChange.LineNumber AS LineNumber,
		|	REFPRESENTATION(RegisterRecordsAdvanceHoldersChange.Company) AS CompanyPresentation,
		|	REFPRESENTATION(RegisterRecordsAdvanceHoldersChange.Employee) AS EmployeePresentation,
		|	REFPRESENTATION(RegisterRecordsAdvanceHoldersChange.Currency) AS CurrencyPresentation,
		|	REFPRESENTATION(RegisterRecordsAdvanceHoldersChange.Document) AS DocumentPresentation,
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
		|		LEFT JOIN AccumulationRegister.AdvanceHolders.Balance(
		|				&ControlTime,
		|				(Company, Employee, Currency, Document) In
		|					(SELECT
		|						RegisterRecordsAdvanceHoldersChange.Company AS Company,
		|						RegisterRecordsAdvanceHoldersChange.Employee AS Employee,
		|						RegisterRecordsAdvanceHoldersChange.Currency AS Currency,
		|						RegisterRecordsAdvanceHoldersChange.Document AS Document
		|					FROM
		|						RegisterRecordsAdvanceHoldersChange AS RegisterRecordsAdvanceHoldersChange)) AS AdvanceHoldersBalances
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
		|	LineNumber");
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.SetParameter("ControlTime", AdditionalProperties.ForPosting.ControlTime);
		
		ResultsArray = Query.Execute();
		
		// Negative balance on advance holder payments.
		If Not ResultsArray.IsEmpty() Then
			
			DocumentObjectOpeningBalanceEntry = DocumentRefOpeningBalanceEntry.GetObject();
			
			QueryResultSelection = ResultsArray.Select();
			DriveServer.ShowMessageAboutPostingToAdvanceHoldersRegisterErrors(DocumentObjectOpeningBalanceEntry, QueryResultSelection, Cancel);
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Control of the accounting section Inventory.
//
Procedure RunControlInventory(DocumentRefOpeningBalanceEntry, AdditionalProperties, Cancel, PostingDelete = False)
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;

	If StructureTemporaryTables.RegisterRecordsInventoryInWarehousesChange
		OR StructureTemporaryTables.RegisterRecordsInventoryChange  Then

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
		|	LineNumber");
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.SetParameter("ControlTime", AdditionalProperties.ForPosting.ControlTime);
		
		ResultsArray = Query.ExecuteBatch();
		
		If Not ResultsArray[0].IsEmpty()
			OR Not ResultsArray[1].IsEmpty() Then
			
			DocumentObjectOpeningBalanceEntry = DocumentRefOpeningBalanceEntry.GetObject()
			
		EndIf;
		
		// Negative balance of inventory in the warehouse.
		If Not ResultsArray[0].IsEmpty() Then
			QueryResultSelection = ResultsArray[0].Select();
			DriveServer.ShowMessageAboutPostingToInventoryInWarehousesRegisterErrorsAsList(DocumentObjectOpeningBalanceEntry, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance of inventory and cost accounting.
		If Not ResultsArray[1].IsEmpty() Then
			QueryResultSelection = ResultsArray[1].Select();
			DriveServer.ShowMessageAboutPostingToInventoryRegisterErrorsAsList(DocumentObjectOpeningBalanceEntry, QueryResultSelection, Cancel);
		EndIf;
		
	EndIf;

EndProcedure

// Control of the accounting section FixedAssets.
//
Procedure RunControlFixedAssets(DocumentRefOpeningBalanceEntry, AdditionalProperties, Cancel, PostingDelete = False)
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;

	// If temporary tables
	// "RegisterRecordsFixedAssetsChange" contain entries, it is necessary to perform control of negative balances.
	
	If StructureTemporaryTables.RegisterRecordsFixedAssetsChange Then

		Query = New Query(
		"SELECT
		|	RegisterRecordsFixedAssetsChange.LineNumber AS LineNumber,
		|	REFPRESENTATION(RegisterRecordsFixedAssetsChange.Company) AS CompanyPresentation,
		|	REFPRESENTATION(RegisterRecordsFixedAssetsChange.FixedAsset) AS FixedAssetPresentation,
		|	ISNULL(FixedAssetsBalance.CostBalance, 0) AS CostBalance,
		|	ISNULL(FixedAssetsBalance.DepreciationBalance, 0) AS DepreciationBalance,
		|	RegisterRecordsFixedAssetsChange.CostBeforeWrite AS CostBeforeWrite,
		|	RegisterRecordsFixedAssetsChange.CostOnWrite AS CostOnWrite,
		|	RegisterRecordsFixedAssetsChange.CostChanging AS CostChanging,
		|	RegisterRecordsFixedAssetsChange.CostChanging + ISNULL(FixedAssetsBalance.CostBalance, 0) AS DepreciatedCost,
		|	RegisterRecordsFixedAssetsChange.DepreciationBeforeWrite AS DepreciationBeforeWrite,
		|	RegisterRecordsFixedAssetsChange.DepreciationOnWrite AS DepreciationOnWrite,
		|	RegisterRecordsFixedAssetsChange.DepreciationUpdate AS DepreciationUpdate,
		|	RegisterRecordsFixedAssetsChange.DepreciationUpdate + ISNULL(FixedAssetsBalance.DepreciationBalance, 0) AS AccuredDepreciation
		|FROM
		|	RegisterRecordsFixedAssetsChange AS RegisterRecordsFixedAssetsChange
		|		LEFT JOIN AccumulationRegister.FixedAssets.Balance(
		|				&ControlTime,
		|				(Company, FixedAsset) In
		|					(SELECT
		|						RegisterRecordsFixedAssetsChange.Company AS Company,
		|						RegisterRecordsFixedAssetsChange.FixedAsset AS FixedAsset
		|					FROM
		|						RegisterRecordsFixedAssetsChange AS RegisterRecordsFixedAssetsChange)) AS FixedAssetsBalance
		|		ON (RegisterRecordsFixedAssetsChange.Company = RegisterRecordsFixedAssetsChange.Company)
		|			AND (RegisterRecordsFixedAssetsChange.FixedAsset = RegisterRecordsFixedAssetsChange.FixedAsset)
		|WHERE
		|	(ISNULL(FixedAssetsBalance.CostBalance, 0) < 0
		|			OR ISNULL(FixedAssetsBalance.DepreciationBalance, 0) < 0)
		|
		|ORDER BY
		|	LineNumber");
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.SetParameter("ControlTime", AdditionalProperties.ForPosting.ControlTime);
		
		QueryResult = Query.Execute();
		
		// Negative balance of property depriciation.
		If Not QueryResult.IsEmpty() Then
			
			DocumentObjectOpeningBalanceEntry = DocumentRefOpeningBalanceEntry.GetObject();
			
			QueryResultSelection = QueryResult.Select();
			DriveServer.ShowMessageAboutPostingToFixedAssetsRegisterErrors(DocumentObjectOpeningBalanceEntry, QueryResultSelection, Cancel);
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Controls the occurrence of negative balances.
//
Procedure RunControl(DocumentRefOpeningBalanceEntry, AdditionalProperties, Cancel, PostingDelete = False) Export
	
	If Not DriveServer.RunBalanceControl() Then
		Return;
	EndIf;

	AccountingSection = DocumentRefOpeningBalanceEntry.AccountingSection;

	If AccountingSection = "Property" Then

		RunControlFixedAssets(DocumentRefOpeningBalanceEntry, AdditionalProperties, Cancel, PostingDelete);

	ElsIf AccountingSection = "Inventory" Then

		RunControlInventory(DocumentRefOpeningBalanceEntry, AdditionalProperties, Cancel, PostingDelete);

	ElsIf AccountingSection = "Cash assets" Then

		RunControlCashAssets(DocumentRefOpeningBalanceEntry, AdditionalProperties, Cancel, PostingDelete);

	ElsIf AccountingSection = "Accounts payable and customers" Then

		RunControlCustomerAccounts(DocumentRefOpeningBalanceEntry, AdditionalProperties, Cancel, PostingDelete);
		RunControlAccountsPayable(DocumentRefOpeningBalanceEntry, AdditionalProperties, Cancel, PostingDelete);

	ElsIf AccountingSection = "Settlements with advance holders" Then
		
		RunControlAdvanceHolders(DocumentRefOpeningBalanceEntry, AdditionalProperties, Cancel, PostingDelete);

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

Procedure FillNewGLAccounts() Export
	
	DocumentName = "OpeningBalanceEntry";
	
	Tables = New Array();
	
	// Table "Inventory"
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
