﻿#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableCashAssets(DocumentRef, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();

	Query.SetParameter("Ref",					DocumentRef);
	Query.SetParameter("PointInTime",			New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod",			StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("Company",				StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("CashTransfering",		NStr("en = 'Cash transfer'", MainLanguageCode));
	Query.SetParameter("ExchangeDifference",	NStr("en = 'Foreign currency exchange gains and losses'", MainLanguageCode));
	
	Query.Text =
	"SELECT
	|	1 AS LineNumber,
	|	CAST(&CashTransfering AS String(100)) AS ContentOfAccountingRecord,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	DocumentTable.Date AS Date,
	|	&Company AS Company,
	|	DocumentTable.CashAssetsType AS CashAssetsType,
	|	DocumentTable.Item AS Item,
	|	CASE
	|		WHEN DocumentTable.CashAssetsType = VALUE(Enum.CashAssetTypes.Cash)
	|			THEN DocumentTable.PettyCash
	|		ELSE DocumentTable.BankAccount
	|	END AS BankAccountPettyCash,
	|	DocumentTable.CashCurrency AS Currency,
	|	SUM(CAST(DocumentTable.DocumentAmount * ExchangeRatesOfPettyCashe.ExchangeRate * AccountingExchangeRates.Multiplicity / (AccountingExchangeRates.ExchangeRate * ExchangeRatesOfPettyCashe.Multiplicity) AS NUMBER(15, 2))) AS Amount,
	|	SUM(DocumentTable.DocumentAmount) AS AmountCur,
	|	-SUM((CAST(DocumentTable.DocumentAmount * ExchangeRatesOfPettyCashe.ExchangeRate * AccountingExchangeRates.Multiplicity / (AccountingExchangeRates.ExchangeRate * ExchangeRatesOfPettyCashe.Multiplicity) AS NUMBER(15, 2)))) AS AmountForBalance,
	|	-SUM(DocumentTable.DocumentAmount) AS AmountCurForBalance,
	|	CASE
	|		WHEN DocumentTable.CashAssetsType = VALUE(Enum.CashAssetTypes.Cash)
	|			THEN DocumentTable.PettyCash.GLAccount
	|		ELSE DocumentTable.BankAccount.GLAccount
	|	END AS GLAccount
	|INTO TemporaryTableCashAssets
	|FROM
	|	Document.CashTransfer AS DocumentTable
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(
	|				&PointInTime,
	|				Currency In
	|					(SELECT
	|						Constants.PresentationCurrency
	|					FROM
	|						Constants AS Constants)) AS AccountingExchangeRates
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&PointInTime, ) AS ExchangeRatesOfPettyCashe
	|		ON DocumentTable.CashCurrency = ExchangeRatesOfPettyCashe.Currency
	|WHERE
	|	DocumentTable.Ref = &Ref
	|
	|GROUP BY
	|	DocumentTable.Date,
	|	DocumentTable.CashAssetsType,
	|	DocumentTable.Item,
	|	DocumentTable.CashCurrency,
	|	CASE
	|		WHEN DocumentTable.CashAssetsType = VALUE(Enum.CashAssetTypes.Cash)
	|			THEN DocumentTable.PettyCash
	|		ELSE DocumentTable.BankAccount
	|	END,
	|	CASE
	|		WHEN DocumentTable.CashAssetsType = VALUE(Enum.CashAssetTypes.Cash)
	|			THEN DocumentTable.PettyCash.GLAccount
	|		ELSE DocumentTable.BankAccount.GLAccount
	|	END
	|
	|UNION ALL
	|
	|SELECT
	|	1,
	|	CAST(&CashTransfering AS String(100)),
	|	VALUE(AccumulationRecordType.Receipt),
	|	DocumentTable.Date,
	|	&Company,
	|	DocumentTable.CashAssetsTypePayee,
	|	DocumentTable.Item,
	|	CASE
	|		WHEN DocumentTable.CashAssetsTypePayee = VALUE(Enum.CashAssetTypes.Cash)
	|			THEN DocumentTable.PettyCashPayee
	|		ELSE DocumentTable.BankAccountPayee
	|	END,
	|	DocumentTable.CashCurrency,
	|	SUM(CAST(DocumentTable.DocumentAmount * ExchangeRatesOfPettyCashe.ExchangeRate * AccountingExchangeRates.Multiplicity / (AccountingExchangeRates.ExchangeRate * ExchangeRatesOfPettyCashe.Multiplicity) AS NUMBER(15, 2))),
	|	SUM(DocumentTable.DocumentAmount),
	|	SUM(CAST(DocumentTable.DocumentAmount * ExchangeRatesOfPettyCashe.ExchangeRate * AccountingExchangeRates.Multiplicity / (AccountingExchangeRates.ExchangeRate * ExchangeRatesOfPettyCashe.Multiplicity) AS NUMBER(15, 2))),
	|	SUM(DocumentTable.DocumentAmount),
	|	CASE
	|		WHEN DocumentTable.CashAssetsType = VALUE(Enum.CashAssetTypes.Cash)
	|			THEN DocumentTable.PettyCashPayee.GLAccount
	|		ELSE DocumentTable.BankAccountPayee.GLAccount
	|	END
	|FROM
	|	Document.CashTransfer AS DocumentTable
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(
	|				&PointInTime,
	|				Currency In
	|					(SELECT
	|						Constants.PresentationCurrency
	|					FROM
	|						Constants AS Constants)) AS AccountingExchangeRates
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&PointInTime, ) AS ExchangeRatesOfPettyCashe
	|		ON DocumentTable.CashCurrency = ExchangeRatesOfPettyCashe.Currency
	|WHERE
	|	DocumentTable.Ref = &Ref
	|
	|GROUP BY
	|	DocumentTable.Date,
	|	DocumentTable.CashAssetsTypePayee,
	|	DocumentTable.Item,
	|	DocumentTable.CashCurrency,
	|	CASE
	|		WHEN DocumentTable.CashAssetsTypePayee = VALUE(Enum.CashAssetTypes.Cash)
	|			THEN DocumentTable.PettyCashPayee
	|		ELSE DocumentTable.BankAccountPayee
	|	END,
	|	CASE
	|		WHEN DocumentTable.CashAssetsType = VALUE(Enum.CashAssetTypes.Cash)
	|			THEN DocumentTable.PettyCashPayee.GLAccount
	|		ELSE DocumentTable.BankAccountPayee.GLAccount
	|	END
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
Procedure GenerateTableIncomeAndExpenses(DocumentRef, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();

	Query.SetParameter("ExchangeDifference",			NStr("en = 'Foreign currency exchange gains and losses'", MainLanguageCode));
	Query.SetParameter("ForeignCurrencyExchangeGain",	Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeGain")); 
	Query.SetParameter("ForeignCurrencyExchangeLoss",	Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeLoss"));
	
	Query.Text =
	"SELECT
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Date AS Period,
	|	DocumentTable.Company AS Company,
	|	UNDEFINED AS StructuralUnit,
	|	UNDEFINED AS SalesOrder,
	|	VALUE(Catalog.LinesOfBusiness.Other) AS BusinessLine,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN &ForeignCurrencyExchangeGain
	|		ELSE &ForeignCurrencyExchangeLoss
	|	END AS GLAccount,
	|	&ExchangeDifference AS ContentOfAccountingRecord,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN DocumentTable.AmountOfExchangeDifferences
	|		ELSE 0
	|	END AS AmountIncome,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN 0
	|		ELSE -DocumentTable.AmountOfExchangeDifferences
	|	END AS AmountExpense,
	|	FALSE AS OfflineRecord
	|FROM
	|	TemporaryTableExchangeRateLossesBanking AS DocumentTable
	|
	|ORDER BY
	|	LineNumber";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpenses", QueryResult.Unload());
	
EndProcedure

// Payment calendar table formation procedure.
//
// Parameters:
//  DocumentRef - DocumentRef.CashInflowForecast - Current document 
//  AdditionalProperties - AdditionalProperties - Additional properties of the document
//
Procedure GenerateTablePaymentCalendar(DocumentRef, StructureAdditionalProperties)
	
	Query = New Query;
	
	Query.SetParameter("Ref", DocumentRef);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("UsePaymentCalendar", Constants.UsePaymentCalendar.Get());
	
	Query.Text =
	"SELECT
	|	DocumentTable.Date AS Period,
	|	&Company AS Company,
	|	DocumentTable.Item AS Item,
	|	DocumentTable.CashAssetsType AS CashAssetsType,
	|	VALUE(Enum.PaymentApprovalStatuses.Approved) AS PaymentConfirmationStatus,
	|	CASE
	|		WHEN DocumentTable.CashAssetsType = VALUE(Enum.CashAssetTypes.Cash)
	|			THEN DocumentTable.PettyCash
	|		WHEN DocumentTable.CashAssetsType = VALUE(Enum.CashAssetTypes.Noncash)
	|			THEN DocumentTable.BankAccount
	|		ELSE UNDEFINED
	|	END AS BankAccountPettyCash,
	|	DocumentTable.CashCurrency AS Currency,
	|	DocumentTable.BasisDocument AS Quote,
	|	-DocumentTable.DocumentAmount AS PaymentAmount
	|FROM
	|	Document.CashTransfer AS DocumentTable
	|WHERE
	|	&UsePaymentCalendar
	|	AND DocumentTable.Ref = &Ref
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentTable.Date,
	|	&Company,
	|	DocumentTable.Item,
	|	DocumentTable.CashAssetsTypePayee,
	|	VALUE(Enum.PaymentApprovalStatuses.Approved),
	|	CASE
	|		WHEN DocumentTable.CashAssetsTypePayee = VALUE(Enum.CashAssetTypes.Cash)
	|			THEN DocumentTable.PettyCashPayee
	|		WHEN DocumentTable.CashAssetsTypePayee = VALUE(Enum.CashAssetTypes.Noncash)
	|			THEN DocumentTable.BankAccountPayee
	|		ELSE UNDEFINED
	|	END,
	|	DocumentTable.CashCurrency,
	|	DocumentTable.BasisDocument,
	|	DocumentTable.DocumentAmount
	|FROM
	|	Document.CashTransfer AS DocumentTable
	|WHERE
	|	&UsePaymentCalendar
	|	AND DocumentTable.Ref = &Ref";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TablePaymentCalendar", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableAccountingJournalEntries(DocumentRef, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();
	
	Query.SetParameter("Ref",							DocumentRef);
	Query.SetParameter("Company",						StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PointInTime",					New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ExchangeDifference",			NStr("en = 'Foreign currency exchange gains and losses'", MainLanguageCode));
	Query.SetParameter("Content",						NStr("en = 'Cash transfer'", MainLanguageCode));
	Query.SetParameter("TaxPay",						NStr("en = 'Tax payment'", MainLanguageCode));
	Query.SetParameter("ForeignCurrencyExchangeGain",	Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeGain")); 
	Query.SetParameter("ForeignCurrencyExchangeLoss",	Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeLoss"));
	
	Query.Text =
	"SELECT
	|	1 AS Order,
	|	1 AS LineNumber,
	|	DocumentTable.Date AS Period,
	|	&Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	CASE
	|		WHEN DocumentTable.CashAssetsTypePayee = VALUE(Enum.CashAssetTypes.Cash)
	|			THEN DocumentTable.PettyCashPayee.GLAccount
	|		ELSE DocumentTable.BankAccountPayee.GLAccount
	|	END AS AccountDr,
	|	CASE
	|		WHEN DocumentTable.CashAssetsType = VALUE(Enum.CashAssetTypes.Cash)
	|			THEN DocumentTable.PettyCash.GLAccount
	|		ELSE DocumentTable.BankAccount.GLAccount
	|	END AS AccountCr,
	|	CASE
	|		WHEN DocumentTable.CashAssetsTypePayee = VALUE(Enum.CashAssetTypes.Cash)
	|			THEN CASE
	|					WHEN DocumentTable.PettyCashPayee.GLAccount.Currency
	|						THEN DocumentTable.CashCurrency
	|					ELSE UNDEFINED
	|				END
	|		ELSE CASE
	|				WHEN DocumentTable.BankAccountPayee.GLAccount.Currency
	|					THEN DocumentTable.CashCurrency
	|				ELSE UNDEFINED
	|			END
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN DocumentTable.CashAssetsType = VALUE(Enum.CashAssetTypes.Cash)
	|			THEN CASE
	|					WHEN DocumentTable.PettyCash.GLAccount.Currency
	|						THEN DocumentTable.CashCurrency
	|					ELSE UNDEFINED
	|				END
	|		ELSE CASE
	|				WHEN DocumentTable.BankAccount.GLAccount.Currency
	|					THEN DocumentTable.CashCurrency
	|				ELSE UNDEFINED
	|			END
	|	END AS CurrencyCr,
	|	CASE
	|		WHEN DocumentTable.CashAssetsTypePayee = VALUE(Enum.CashAssetTypes.Cash)
	|			THEN CASE
	|					WHEN DocumentTable.PettyCashPayee.GLAccount.Currency
	|						THEN DocumentTable.DocumentAmount
	|					ELSE 0
	|				END
	|		ELSE CASE
	|				WHEN DocumentTable.BankAccountPayee.GLAccount.Currency
	|					THEN DocumentTable.DocumentAmount
	|				ELSE 0
	|			END
	|	END AS AmountCurDr,
	|	CASE
	|		WHEN DocumentTable.CashAssetsType = VALUE(Enum.CashAssetTypes.Cash)
	|			THEN CASE
	|					WHEN DocumentTable.PettyCash.GLAccount.Currency
	|						THEN DocumentTable.DocumentAmount
	|					ELSE 0
	|				END
	|		ELSE CASE
	|				WHEN DocumentTable.BankAccount.GLAccount.Currency
	|					THEN DocumentTable.DocumentAmount
	|				ELSE 0
	|			END
	|	END AS AmountCurCr,
	|	CAST(DocumentTable.DocumentAmount * SettlementsExchangeRates.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * SettlementsExchangeRates.Multiplicity) AS NUMBER(15, 2)) AS Amount,
	|	CAST(&Content AS STRING(100)) AS Content,
	|	FALSE AS OfflineRecord
	|FROM
	|	Document.CashTransfer AS DocumentTable
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(
	|				&PointInTime,
	|				Currency IN
	|					(SELECT
	|						Constants.PresentationCurrency
	|					FROM
	|						Constants AS Constants)) AS AccountingExchangeRatesSliceLast
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&PointInTime, ) AS SettlementsExchangeRates
	|		ON DocumentTable.CashCurrency = SettlementsExchangeRates.Currency
	|WHERE
	|	DocumentTable.Ref = &Ref
	|
	|UNION ALL
	|
	|SELECT
	|	2,
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
	|ORDER BY
	|	Order,
	|	LineNumber";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountingJournalEntries", QueryResult.Unload());
	
EndProcedure

// Creates a document data table.
//
// Parameters:
//  DocumentRef - DocumentRef.CashInflowForecast - Current document
//  StructureAdditionalProperties - AdditionalProperties - Additional properties of the document
//	
Procedure InitializeDocumentData(DocumentRef, StructureAdditionalProperties) Export
	
	GenerateTableCashAssets(DocumentRef, StructureAdditionalProperties);
	GenerateTableIncomeAndExpenses(DocumentRef, StructureAdditionalProperties);
	GenerateTablePaymentCalendar(DocumentRef, StructureAdditionalProperties);
	GenerateTableAccountingJournalEntries(DocumentRef, StructureAdditionalProperties);
	
EndProcedure

// Controls the occurrence of negative balances.
//
Procedure RunControl(DocumentRef, AdditionalProperties, Cancel, PostingDelete = False) Export
	
	If Not Constants.CheckStockBalanceOnPosting.Get() Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// If temporary tables contain records, it is
	// necessary to execute negative balance control.
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
		
		ResultsArray = Query.ExecuteBatch();
		
		If Not ResultsArray[0].IsEmpty() Then
			DocumentObjectCashVoucher = DocumentRef.GetObject();
		EndIf;
		
		// Negative balance on cash.
		If Not ResultsArray[0].IsEmpty() Then
			QueryResultSelection = ResultsArray[0].Select();
			DriveServer.ShowMessageAboutPostingToCashAssetsRegisterErrors(DocumentObjectCashVoucher, QueryResultSelection, Cancel);
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

#EndIf