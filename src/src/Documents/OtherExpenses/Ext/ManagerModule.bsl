#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region OtherSettlements

Procedure GenerateTableMiscellaneousPayable(DocumentRefOtherExpenses, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();

	Query.SetParameter("Company",						StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("AccountingForOtherOperations",	NStr("en = 'Accounting for other operations'",	MainLanguageCode));
	Query.SetParameter("CommentReceipt",				NStr("en = 'Increase in counterparty debt'", MainLanguageCode));
	Query.SetParameter("CommentExpense",				NStr("en = 'Decrease in counterparty debt'", MainLanguageCode));
	Query.SetParameter("Ref",							DocumentRefOtherExpenses);
	Query.SetParameter("PointInTime",					New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod",					StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("ExchangeRateDifference",		NStr("en = 'Foreign currency exchange gains and losses'", MainLanguageCode));
	Query.SetParameter("PresentationCurrency",			Constants.PresentationCurrency.Get());
	
	Query.Text =
	"SELECT
	|	OtherExpensesExpenses.LineNumber AS LineNumber,
	|	&Company AS Company,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	OtherExpensesExpenses.Counterparty AS Counterparty,
	|	OtherExpensesExpenses.Contract AS Contract,
	|	OtherExpensesExpenses.Contract.SettlementsCurrency AS Currency,
	|	CASE
	|		WHEN OtherExpensesExpenses.Counterparty.DoOperationsByOrders
	|			THEN OtherExpensesExpenses.SalesOrder
	|		ELSE VALUE(Document.SalesOrder.EmptyRef)
	|	END AS Order,
	|	OtherExpensesExpenses.Ref.Date AS Period,
	|	SUM(OtherExpensesExpenses.Amount) AS Amount,
	|	&AccountingForOtherOperations AS PostingContent,
	|	&CommentReceipt AS Comment,
	|	OtherExpensesExpenses.GLExpenseAccount AS GLAccount,
	|	CAST(OtherExpensesExpenses.Amount * ExchangeRatesSettlements.Multiplicity * ExchangeRatesAccounting.ExchangeRate / (ExchangeRatesSettlements.ExchangeRate * ExchangeRatesAccounting.Multiplicity) AS NUMBER(15, 2)) AS AmountCur
	|FROM
	|	Document.OtherExpenses.Expenses AS OtherExpensesExpenses
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&PointInTime, ) AS ExchangeRatesSettlements
	|		ON OtherExpensesExpenses.Contract.SettlementsCurrency = ExchangeRatesSettlements.Currency
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&PointInTime, Currency = &PresentationCurrency) AS ExchangeRatesAccounting
	|		ON (ExchangeRatesAccounting.Currency = &PresentationCurrency)
	|WHERE
	|	OtherExpensesExpenses.Ref = &Ref
	|	AND OtherExpensesExpenses.Ref.OtherSettlementsAccounting
	|	AND OtherExpensesExpenses.Counterparty <> VALUE(Catalog.Counterparties.EmptyRef)
	|	AND (OtherExpensesExpenses.GLExpenseAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.AccountsReceivable)
	|			OR OtherExpensesExpenses.GLExpenseAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.AccountsPayable))
	|
	|GROUP BY
	|	OtherExpensesExpenses.LineNumber,
	|	OtherExpensesExpenses.Counterparty,
	|	OtherExpensesExpenses.Contract,
	|	OtherExpensesExpenses.Contract.SettlementsCurrency,
	|	OtherExpensesExpenses.Ref.Date,
	|	CASE
	|		WHEN OtherExpensesExpenses.Counterparty.DoOperationsByOrders
	|			THEN OtherExpensesExpenses.SalesOrder
	|		ELSE VALUE(Document.SalesOrder.EmptyRef)
	|	END,
	|	OtherExpensesExpenses.GLExpenseAccount,
	|	CAST(OtherExpensesExpenses.Amount * ExchangeRatesSettlements.Multiplicity * ExchangeRatesAccounting.ExchangeRate / (ExchangeRatesSettlements.ExchangeRate * ExchangeRatesAccounting.Multiplicity) AS NUMBER(15, 2))
	|
	|UNION ALL
	|
	|SELECT
	|	OtherExpensesExpenses.LineNumber,
	|	&Company,
	|	VALUE(AccumulationRecordType.Expense),
	|	OtherExpenses.Counterparty,
	|	OtherExpenses.Contract,
	|	OtherExpenses.Contract.SettlementsCurrency,
	|	UNDEFINED,
	|	OtherExpenses.Date,
	|	SUM(OtherExpensesExpenses.Amount),
	|	&AccountingForOtherOperations,
	|	&CommentExpense,
	|	OtherExpenses.Correspondence,
	|	CAST(OtherExpensesExpenses.Amount * ExchangeRatesSettlements.Multiplicity * ExchangeRatesAccounting.ExchangeRate / (ExchangeRatesSettlements.ExchangeRate * ExchangeRatesAccounting.Multiplicity) AS NUMBER(15, 2))
	|FROM
	|	Document.OtherExpenses.Expenses AS OtherExpensesExpenses
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&PointInTime, Currency = &PresentationCurrency) AS ExchangeRatesAccounting
	|		ON (ExchangeRatesAccounting.Currency = &PresentationCurrency)
	|		INNER JOIN Document.OtherExpenses AS OtherExpenses
	|			LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&PointInTime, ) AS ExchangeRatesSettlements
	|			ON OtherExpenses.Contract.SettlementsCurrency = ExchangeRatesSettlements.Currency
	|		ON OtherExpensesExpenses.Ref = OtherExpenses.Ref
	|WHERE
	|	OtherExpensesExpenses.Ref = &Ref
	|	AND OtherExpenses.Ref = &Ref
	|	AND OtherExpensesExpenses.Ref.OtherSettlementsAccounting
	|	AND OtherExpenses.Counterparty <> VALUE(Catalog.Counterparties.EmptyRef)
	|	AND (OtherExpenses.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.AccountsReceivable)
	|			OR OtherExpenses.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.AccountsPayable))
	|
	|GROUP BY
	|	OtherExpensesExpenses.LineNumber,
	|	OtherExpenses.Counterparty,
	|	OtherExpenses.Contract,
	|	OtherExpenses.Contract.SettlementsCurrency,
	|	OtherExpenses.Date,
	|	OtherExpenses.Correspondence,
	|	CAST(OtherExpensesExpenses.Amount * ExchangeRatesSettlements.Multiplicity * ExchangeRatesAccounting.ExchangeRate / (ExchangeRatesSettlements.ExchangeRate * ExchangeRatesAccounting.Multiplicity) AS NUMBER(15, 2))";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableMiscellaneousPayable", QueryResult.Unload());
	
EndProcedure

#EndRegion

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefOtherExpenses, StructureAdditionalProperties) Export

	Query = New Query(
	"SELECT
	|	OtherExpensesCosts.LineNumber AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	OtherExpensesCosts.Ref.Date AS Period,
	|	&Company AS Company,
	|	OtherExpensesCosts.Ref.StructuralUnit AS StructuralUnit,
	|	OtherExpensesCosts.GLExpenseAccount AS GLAccount,
	|	CASE
	|		WHEN OtherExpensesCosts.SalesOrder = VALUE(Document.SalesOrder.EmptyRef)
	|				OR OtherExpensesCosts.SalesOrder = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE OtherExpensesCosts.SalesOrder
	|	END AS SalesOrder,
	|	OtherExpensesCosts.Amount AS Amount,
	|	TRUE AS FixedCost,
	|	&OtherExpenses AS ContentOfAccountingRecord
	|FROM
	|	Document.OtherExpenses.Expenses AS OtherExpensesCosts
	|WHERE
	|	OtherExpensesCosts.Ref = &Ref
	|	AND (OtherExpensesCosts.GLExpenseAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.WorkInProcess)
	|			OR OtherExpensesCosts.GLExpenseAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.IndirectExpenses))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	OtherExpensesCosts.LineNumber AS LineNumber,
	|	OtherExpensesCosts.Ref.Date AS Period,
	|	&Company AS Company,
	|	CASE
	|		WHEN OtherExpensesCosts.GLExpenseAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherExpenses)
	|				OR OtherExpensesCosts.GLExpenseAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.LoanInterest)
	|			THEN VALUE(Catalog.LinesOfBusiness.Other)
	|		ELSE OtherExpensesCosts.BusinessLine
	|	END AS BusinessLine,
	|	CASE
	|		WHEN OtherExpensesCosts.GLExpenseAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherExpenses)
	|				OR OtherExpensesCosts.GLExpenseAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.LoanInterest)
	|			THEN VALUE(Catalog.BusinessUnits.EmptyRef)
	|		ELSE OtherExpensesCosts.Ref.StructuralUnit
	|	END AS StructuralUnit,
	|	OtherExpensesCosts.GLExpenseAccount AS GLAccount,
	|	CASE
	|		WHEN OtherExpensesCosts.GLExpenseAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherExpenses)
	|				OR OtherExpensesCosts.GLExpenseAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.LoanInterest)
	|				OR OtherExpensesCosts.SalesOrder = VALUE(Document.SalesOrder.EmptyRef)
	|				OR OtherExpensesCosts.SalesOrder = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE OtherExpensesCosts.SalesOrder
	|	END AS SalesOrder,
	|	0 AS AmountIncome,
	|	OtherExpensesCosts.Amount AS AmountExpense,
	|	OtherExpensesCosts.Amount AS Amount,
	|	&OtherExpenses AS ContentOfAccountingRecord
	|FROM
	|	Document.OtherExpenses.Expenses AS OtherExpensesCosts
	|WHERE
	|	OtherExpensesCosts.Ref = &Ref
	|	AND (OtherExpensesCosts.GLExpenseAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.Expenses)
	|			OR OtherExpensesCosts.GLExpenseAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherExpenses)
	|			OR OtherExpensesCosts.GLExpenseAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.LoanInterest))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	OtherExpensesCosts.Ref.Date AS Period,
	|	&Company AS Company,
	|	OtherExpensesCosts.Ref.StructuralUnit AS StructuralUnit,
	|	VALUE(Catalog.LinesOfBusiness.Other) AS BusinessLine,
	|	UNDEFINED AS SalesOrder,
	|	OtherExpensesCosts.Ref.Correspondence AS GLAccount,
	|	SUM(OtherExpensesCosts.Amount) AS AmountIncome,
	|	0 AS AmountExpense,
	|	&RevenueIncomes AS ContentOfAccountingRecord,
	|	FALSE AS OfflineRecord
	|FROM
	|	Document.OtherExpenses.Expenses AS OtherExpensesCosts
	|WHERE
	|	OtherExpensesCosts.Ref = &Ref
	|	AND OtherExpensesCosts.Ref.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherIncome)
	|	AND OtherExpensesCosts.Amount > 0
	|
	|GROUP BY
	|	OtherExpensesCosts.Ref,
	|	OtherExpensesCosts.Ref.Date,
	|	OtherExpensesCosts.Ref.Correspondence,
	|	OtherExpensesCosts.Ref.StructuralUnit
	|
	|UNION ALL
	|
	|SELECT
	|	OfflineRecords.Period,
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
	|SELECT
	|	OtherExpensesCosts.LineNumber AS LineNumber,
	|	OtherExpensesCosts.Ref.Date AS Period,
	|	&Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	OtherExpensesCosts.GLExpenseAccount AS AccountDr,
	|	CASE
	|		WHEN OtherExpensesCosts.GLExpenseAccount.Currency
	|			THEN UNDEFINED
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN OtherExpensesCosts.GLExpenseAccount.Currency
	|			THEN 0
	|		ELSE 0
	|	END AS AmountCurDr,
	|	OtherExpensesCosts.Ref.Correspondence AS AccountCr,
	|	CASE
	|		WHEN OtherExpensesCosts.Ref.Correspondence.Currency
	|			THEN UNDEFINED
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	CASE
	|		WHEN OtherExpensesCosts.Ref.Correspondence.Currency
	|			THEN 0
	|		ELSE 0
	|	END AS AmountCurCr,
	|	OtherExpensesCosts.Amount AS Amount,
	|	&OtherIncome AS Content,
	|	FALSE AS OfflineRecord
	|FROM
	|	Document.OtherExpenses.Expenses AS OtherExpensesCosts
	|WHERE
	|	OtherExpensesCosts.Ref = &Ref
	|	AND OtherExpensesCosts.Amount > 0
	|
	|UNION ALL
	|
	|SELECT
	|	OfflineRecords.LineNumber,
	|	OfflineRecords.Period,
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
	|	1 AS LineNumber,
	|	OtherExpensesExpenses.Ref.Date AS Period,
	|	&Company AS Company,
	|	VALUE(Catalog.LinesOfBusiness.Other) AS BusinessLine,
	|	VALUE(Catalog.BusinessUnits.EmptyRef) AS StructuralUnit,
	|	OtherExpensesExpenses.Ref.Correspondence AS GLAccount,
	|	UNDEFINED AS SalesOrder,
	|	0 AS AmountIncome,
	|	SUM(OtherExpensesExpenses.Amount) AS AmountExpense,
	|	SUM(OtherExpensesExpenses.Amount) AS Amount,
	|	&OtherExpenses AS PostingContent
	|FROM
	|	Document.OtherExpenses.Expenses AS OtherExpensesExpenses
	|WHERE
	|	OtherExpensesExpenses.Ref = &Ref
	|	AND (OtherExpensesExpenses.Ref.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.AccountsPayable)
	|			OR OtherExpensesExpenses.Ref.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.AccountsReceivable))
	|	AND OtherExpensesExpenses.Ref.OtherSettlementsAccounting
	|	AND OtherExpensesExpenses.GLExpenseAccount.TypeOfAccount <> VALUE(Enum.GLAccountsTypes.Expenses)
	|	AND OtherExpensesExpenses.GLExpenseAccount.TypeOfAccount <> VALUE(Enum.GLAccountsTypes.OtherExpenses)
	|	AND OtherExpensesExpenses.GLExpenseAccount.TypeOfAccount <> VALUE(Enum.GLAccountsTypes.LoanInterest)
	|	AND OtherExpensesExpenses.GLExpenseAccount.TypeOfAccount <> VALUE(Enum.GLAccountsTypes.RetainedEarnings)
	|
	|GROUP BY
	|	OtherExpensesExpenses.Ref.Date,
	|	OtherExpensesExpenses.Ref.Correspondence
	|
	|UNION ALL
	|
	|SELECT
	|	OtherExpensesExpenses.LineNumber,
	|	OtherExpensesExpenses.Ref.Date,
	|	&Company,
	|	VALUE(Catalog.LinesOfBusiness.Other),
	|	VALUE(Catalog.BusinessUnits.EmptyRef),
	|	OtherExpensesExpenses.Ref.Correspondence,
	|	UNDEFINED,
	|	OtherExpensesExpenses.Amount,
	|	0,
	|	OtherExpensesExpenses.Amount,
	|	&RevenueIncomes
	|FROM
	|	Document.OtherExpenses.Expenses AS OtherExpensesExpenses
	|WHERE
	|	OtherExpensesExpenses.Ref = &Ref
	|	AND (OtherExpensesExpenses.GLExpenseAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.AccountsPayable)
	|			OR OtherExpensesExpenses.GLExpenseAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.AccountsReceivable))
	|	AND OtherExpensesExpenses.Ref.OtherSettlementsAccounting
	|	AND (OtherExpensesExpenses.Ref.Correspondence.TypeOfAccount <> VALUE(Enum.GLAccountsTypes.OtherIncome)
	|			OR OtherExpensesExpenses.Amount < 0)");
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();

	Query.SetParameter("Ref",				DocumentRefOtherExpenses);
	Query.SetParameter("Company",			StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("OtherExpenses",		NStr("en = 'Expenses incurred'", MainLanguageCode));
	Query.SetParameter("RevenueIncomes",	NStr("en = 'Other income'", MainLanguageCode));
	Query.SetParameter("OtherIncome",		NStr("en = 'Other expenses'", MainLanguageCode));
	
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventory", ResultsArray[0].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpenses", ResultsArray[1].Unload());
	
	If StructureAdditionalProperties.TableForRegisterRecords.TableIncomeAndExpenses.Count() = 0 Then
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpenses", ResultsArray[2].Unload());
	Else
		
		Selection = ResultsArray[2].Select();
		While Selection.Next() Do
			
			NewRow = StructureAdditionalProperties.TableForRegisterRecords.TableIncomeAndExpenses.Add();
			FillPropertyValues(NewRow, Selection);
			
		EndDo;
		
	EndIf;
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountingJournalEntries", ResultsArray[3].Unload());
	
	If StructureAdditionalProperties.TableForRegisterRecords.TableIncomeAndExpenses.Count() = 0 Then
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpenses", ResultsArray[4].Unload());
	Else
		
		Selection = ResultsArray[4].Select();
		While Selection.Next() Do
			
			NewRow = StructureAdditionalProperties.TableForRegisterRecords.TableIncomeAndExpenses.Add();
			FillPropertyValues(NewRow, Selection);
			
		EndDo;
		
	EndIf;
	
	GenerateTableMiscellaneousPayable(DocumentRefOtherExpenses, StructureAdditionalProperties);
	
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