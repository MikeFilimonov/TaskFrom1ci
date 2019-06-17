#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentDataCashBudget(DocumentRefBudget, StructureAdditionalProperties)
	
	Query = New Query;
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();

	Query.SetParameter("Ref",					DocumentRefBudget);
	Query.SetParameter("Company",				StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("IncomeContent",			NStr("en = 'Forecast of funds receipt'", MainLanguageCode));
	Query.SetParameter("ExpenceContent",		NStr("en = 'Forecast of funds outflow'", MainLanguageCode));
	Query.SetParameter("PresentationCurrency",	Constants.PresentationCurrency.Get());
	
	Query.Text =
	"SELECT
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.PlanningDate AS Period,
	|	&Company AS Company,
	|	DocumentTable.Ref.PlanningPeriod AS PlanningPeriod,
	|	DocumentTable.Account AS GLAccount,
	|	&PresentationCurrency AS Currency,
	|	DocumentTable.Item AS Item,
	|	DocumentTable.Amount AS AmountReceiptCur,
	|	DocumentTable.Amount AS AmountReceipt,
	|	0 AS AmountExpenseCur,
	|	0 AS AmountExpense,
	|	&IncomeContent AS ContentOfAccountingRecord
	|FROM
	|	Document.Budget.Receipts AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentTable.LineNumber,
	|	DocumentTable.PlanningDate,
	|	&Company,
	|	DocumentTable.Ref.PlanningPeriod,
	|	DocumentTable.Account,
	|	&PresentationCurrency,
	|	DocumentTable.Item,
	|	0,
	|	0,
	|	DocumentTable.Amount,
	|	DocumentTable.Amount,
	|	&ExpenceContent
	|FROM
	|	Document.Budget.Disposal AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|
	|ORDER BY
	|	LineNumber";
	
	Result = Query.Execute().Unload();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableCashBudget", Result);
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentDataIncomeAndExpensesBudget(DocumentRefBudget, StructureAdditionalProperties)
	
	Query = New Query;
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();

	Query.SetParameter("Ref",				DocumentRefBudget);
	Query.SetParameter("Company",			StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("IncomeContent",		NStr("en = 'Income forecast'", MainLanguageCode));
	Query.SetParameter("ExpenceContent",	NStr("en = 'Expense forecast'", MainLanguageCode));
	
	Query.Text =
	"SELECT
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.PlanningDate AS Period,
	|	&Company AS Company,
	|	DocumentTable.Ref.PlanningPeriod AS PlanningPeriod,
	|	CASE
	|		WHEN DocumentTable.Account.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherIncome)
	|			THEN UNDEFINED
	|		ELSE DocumentTable.StructuralUnit
	|	END AS StructuralUnit,
	|	CASE
	|		WHEN DocumentTable.Account.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherIncome)
	|			THEN VALUE(Catalog.LinesOfBusiness.Other)
	|		ELSE DocumentTable.BusinessLine
	|	END AS BusinessLine,
	|	CASE
	|		WHEN DocumentTable.Account.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherIncome)
	|			THEN UNDEFINED
	|		ELSE DocumentTable.SalesOrder
	|	END AS SalesOrder,
	|	DocumentTable.Account AS GLAccount,
	|	DocumentTable.Amount AS AmountIncome,
	|	0 AS AmountExpense,
	|	&IncomeContent AS ContentOfAccountingRecord
	|FROM
	|	Document.Budget.Incomings AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentTable.LineNumber,
	|	DocumentTable.PlanningDate,
	|	&Company,
	|	DocumentTable.Ref.PlanningPeriod,
	|	CASE
	|		WHEN DocumentTable.Account.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherIncome)
	|				OR DocumentTable.Account.TypeOfAccount = VALUE(Enum.GLAccountsTypes.LoanInterest)
	|			THEN UNDEFINED
	|		ELSE DocumentTable.StructuralUnit
	|	END,
	|	CASE
	|		WHEN DocumentTable.Account.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherIncome)
	|				OR DocumentTable.Account.TypeOfAccount = VALUE(Enum.GLAccountsTypes.LoanInterest)
	|			THEN VALUE(Catalog.LinesOfBusiness.Other)
	|		ELSE DocumentTable.BusinessLine
	|	END,
	|	CASE
	|		WHEN DocumentTable.Account.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherIncome)
	|			THEN UNDEFINED
	|		ELSE DocumentTable.SalesOrder
	|	END,
	|	DocumentTable.Account,
	|	0,
	|	DocumentTable.Amount,
	|	&ExpenceContent
	|FROM
	|	Document.Budget.Expenses AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref";
			
	Result = Query.Execute().Unload();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpensesBudget", Result);
	
EndProcedure

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentDataDirectCost(DocumentRefBudget, StructureAdditionalProperties)
	
	Query = New Query(
	"SELECT
	|	DocumentTable.PlanningDate AS Period,
	|	&Company AS Company,
	|	DocumentTable.Ref.PlanningPeriod AS PlanningPeriod,
	|	DocumentTable.Amount AS Amount,
	|	DocumentTable.Account AS AccountDr,
	|	CASE
	|		WHEN DocumentTable.Account.Currency
	|			THEN &PresentationCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN DocumentTable.Account.Currency
	|			THEN DocumentTable.Amount
	|		ELSE 0
	|	END AS AmountCurDr,
	|	DocumentTable.CorrAccount AS AccountCr,
	|	CASE
	|		WHEN DocumentTable.CorrAccount.Currency
	|			THEN &PresentationCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	CASE
	|		WHEN DocumentTable.CorrAccount.Currency
	|			THEN DocumentTable.Amount
	|		ELSE 0
	|	END AS AmountCurCr,
	|	CAST(DocumentTable.Comment AS String(100)) AS Content
	|FROM
	|	Document.Budget.DirectCost AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentTable.PlanningDate,
	|	&Company,
	|	DocumentTable.Ref.PlanningPeriod,
	|	DocumentTable.Amount,
	|	DocumentTable.Account.ClosingAccount,
	|	CASE
	|		WHEN DocumentTable.Account.ClosingAccount.Currency
	|			THEN &PresentationCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.Account.ClosingAccount.Currency
	|			THEN DocumentTable.Amount
	|		ELSE 0
	|	END,
	|	DocumentTable.Account,
	|	CASE
	|		WHEN DocumentTable.Account.Currency
	|			THEN &PresentationCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.Account.Currency
	|			THEN DocumentTable.Amount
	|		ELSE 0
	|	END,
	|	CAST(&DistributionOfDirectCost AS String(100))
	|FROM
	|	Document.Budget.DirectCost AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentTable.PlanningDate,
	|	&Company,
	|	DocumentTable.Ref.PlanningPeriod,
	|	DocumentTable.Amount,
	|	DocumentTable.Account.ClosingAccount.ClosingAccount,
	|	CASE
	|		WHEN DocumentTable.Account.ClosingAccount.ClosingAccount.Currency
	|			THEN &PresentationCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.Account.ClosingAccount.ClosingAccount.Currency
	|			THEN DocumentTable.Amount
	|		ELSE 0
	|	END,
	|	DocumentTable.Account.ClosingAccount,
	|	CASE
	|		WHEN DocumentTable.Account.ClosingAccount.Currency
	|			THEN &PresentationCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.Account.ClosingAccount.Currency
	|			THEN DocumentTable.Amount
	|		ELSE 0
	|	END,
	|	CAST(&TransferOfFinishedProducts AS String(100))
	|FROM
	|	Document.Budget.DirectCost AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|	AND DocumentTable.Account.ClosingAccount.ClosingAccount <> VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)");
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();
	
	Query.SetParameter("Ref",							DocumentRefBudget);
	Query.SetParameter("Company",						StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("DistributionOfDirectCost",		NStr("en = 'Direct costs allocating'", MainLanguageCode));
	Query.SetParameter("TransferOfFinishedProducts",	NStr("en = 'Finished products delivery'", MainLanguageCode));
	Query.SetParameter("PresentationCurrency",			Constants.PresentationCurrency.Get());
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	
	While Selection.Next() Do
		NewRow = StructureAdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries.Add();
		FillPropertyValues(NewRow, Selection);
	EndDo;
	
EndProcedure

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentDataIndirectExpenses(DocumentRefBudget, StructureAdditionalProperties)
	
	Query = New Query(
	"SELECT
	|	DocumentTable.PlanningDate AS Period,
	|	&Company AS Company,
	|	DocumentTable.Ref.PlanningPeriod AS PlanningPeriod,
	|	DocumentTable.Amount AS Amount,
	|	DocumentTable.Account AS AccountDr,
	|	CASE
	|		WHEN DocumentTable.Account.Currency
	|			THEN &PresentationCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN DocumentTable.Account.Currency
	|			THEN DocumentTable.Amount
	|		ELSE 0
	|	END AS AmountCurDr,
	|	DocumentTable.CorrAccount AS AccountCr,
	|	CASE
	|		WHEN DocumentTable.CorrAccount.Currency
	|			THEN &PresentationCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	CASE
	|		WHEN DocumentTable.CorrAccount.Currency
	|			THEN DocumentTable.Amount
	|		ELSE 0
	|	END AS AmountCurCr,
	|	CAST(DocumentTable.Comment AS String(100)) AS Content
	|FROM
	|	Document.Budget.IndirectExpenses AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentTable.PlanningDate,
	|	&Company,
	|	DocumentTable.Ref.PlanningPeriod,
	|	DocumentTable.Amount,
	|	DocumentTable.Account.ClosingAccount,
	|	CASE
	|		WHEN DocumentTable.Account.ClosingAccount.Currency
	|			THEN &PresentationCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.Account.ClosingAccount.Currency
	|			THEN DocumentTable.Amount
	|		ELSE 0
	|	END,
	|	DocumentTable.Account,
	|	CASE
	|		WHEN DocumentTable.Account.Currency
	|			THEN &PresentationCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.Account.Currency
	|			THEN DocumentTable.Amount
	|		ELSE 0
	|	END,
	|	CAST(&DistributionOfIndirectCost AS String(100))
	|FROM
	|	Document.Budget.IndirectExpenses AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentTable.PlanningDate,
	|	&Company,
	|	DocumentTable.Ref.PlanningPeriod,
	|	DocumentTable.Amount,
	|	DocumentTable.Account.ClosingAccount.ClosingAccount,
	|	CASE
	|		WHEN DocumentTable.Account.ClosingAccount.ClosingAccount.Currency
	|			THEN &PresentationCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.Account.ClosingAccount.ClosingAccount.Currency
	|			THEN DocumentTable.Amount
	|		ELSE 0
	|	END,
	|	DocumentTable.Account.ClosingAccount,
	|	CASE
	|		WHEN DocumentTable.Account.ClosingAccount.Currency
	|			THEN &PresentationCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.Account.ClosingAccount.Currency
	|			THEN DocumentTable.Amount
	|		ELSE 0
	|	END,
	|	CAST(&DistributionOfDirectCost AS String(100))
	|FROM
	|	Document.Budget.IndirectExpenses AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|	AND DocumentTable.Account.ClosingAccount.ClosingAccount <> VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentTable.PlanningDate,
	|	&Company,
	|	DocumentTable.Ref.PlanningPeriod,
	|	DocumentTable.Amount,
	|	DocumentTable.Account.ClosingAccount.ClosingAccount.ClosingAccount,
	|	CASE
	|		WHEN DocumentTable.Account.ClosingAccount.ClosingAccount.ClosingAccount.Currency
	|			THEN &PresentationCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.Account.ClosingAccount.ClosingAccount.ClosingAccount.Currency
	|			THEN DocumentTable.Amount
	|		ELSE 0
	|	END,
	|	DocumentTable.Account.ClosingAccount.ClosingAccount,
	|	CASE
	|		WHEN DocumentTable.Account.ClosingAccount.ClosingAccount.Currency
	|			THEN &PresentationCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.Account.ClosingAccount.ClosingAccount.Currency
	|			THEN DocumentTable.Amount
	|		ELSE 0
	|	END,
	|	CAST(&TransferOfFinishedProducts AS String(100))
	|FROM
	|	Document.Budget.IndirectExpenses AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|	AND DocumentTable.Account.ClosingAccount.ClosingAccount.ClosingAccount <> VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)");
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();

	Query.SetParameter("Ref",							DocumentRefBudget);
	Query.SetParameter("Company",						StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("DistributionOfIndirectCost",	NStr("en = 'Indirect costs allocating'", MainLanguageCode));
	Query.SetParameter("DistributionOfDirectCost",		NStr("en = 'Direct costs allocating'", MainLanguageCode));
	Query.SetParameter("TransferOfFinishedProducts",	NStr("en = 'Finished products delivery'", MainLanguageCode));
	Query.SetParameter("PresentationCurrency",			Constants.PresentationCurrency.Get());
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	
	While Selection.Next() Do
		NewRow = StructureAdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries.Add();
		FillPropertyValues(NewRow, Selection);
	EndDo;
	
EndProcedure

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentDataExpenses(DocumentRefBudget, StructureAdditionalProperties)
	
	Query = New Query(
	"SELECT
	|	DocumentTable.PlanningDate AS Period,
	|	&Company AS Company,
	|	DocumentTable.Ref.PlanningPeriod AS PlanningPeriod,
	|	DocumentTable.Amount AS Amount,
	|	DocumentTable.Account AS AccountDr,
	|	CASE
	|		WHEN DocumentTable.Account.Currency
	|			THEN &PresentationCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN DocumentTable.Account.Currency
	|			THEN DocumentTable.Amount
	|		ELSE 0
	|	END AS AmountCurDr,
	|	DocumentTable.CorrAccount AS AccountCr,
	|	CASE
	|		WHEN DocumentTable.CorrAccount.Currency
	|			THEN &PresentationCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	CASE
	|		WHEN DocumentTable.CorrAccount.Currency
	|			THEN DocumentTable.Amount
	|		ELSE 0
	|	END AS AmountCurCr,
	|	CAST(DocumentTable.Comment AS String(100)) AS Content
	|FROM
	|	Document.Budget.Expenses AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref");
	
	Query.SetParameter("Ref", DocumentRefBudget);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency", Constants.PresentationCurrency.Get());
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	
	While Selection.Next() Do
		NewRow = StructureAdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries.Add();
		FillPropertyValues(NewRow, Selection);
	EndDo;
	
EndProcedure

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentDataIncome(DocumentRefBudget, StructureAdditionalProperties)
	
	Query = New Query(
	"SELECT
	|	DocumentTable.PlanningDate AS Period,
	|	&Company AS Company,
	|	DocumentTable.Ref.PlanningPeriod AS PlanningPeriod,
	|	DocumentTable.Amount AS Amount,
	|	DocumentTable.CorrAccount AS AccountDr,
	|	CASE
	|		WHEN DocumentTable.CorrAccount.Currency
	|			THEN &PresentationCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN DocumentTable.CorrAccount.Currency
	|			THEN DocumentTable.Amount
	|		ELSE 0
	|	END AS AmountCurDr,
	|	DocumentTable.Account AS AccountCr,
	|	CASE
	|		WHEN DocumentTable.Account.Currency
	|			THEN &PresentationCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	CASE
	|		WHEN DocumentTable.Account.Currency
	|			THEN DocumentTable.Amount
	|		ELSE 0
	|	END AS AmountCurCr,
	|	CAST(DocumentTable.Comment AS String(100)) AS Content
	|FROM
	|	Document.Budget.Incomings AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref");
	
	Query.SetParameter("Ref", DocumentRefBudget);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency", Constants.PresentationCurrency.Get());
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	
	While Selection.Next() Do
		NewRow = StructureAdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries.Add();
		FillPropertyValues(NewRow, Selection);
	EndDo;
	
EndProcedure

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentDataOutflows(DocumentRefBudget, StructureAdditionalProperties)
	
	Query = New Query(
	"SELECT
	|	DocumentTable.PlanningDate AS Period,
	|	&Company AS Company,
	|	DocumentTable.Ref.PlanningPeriod AS PlanningPeriod,
	|	DocumentTable.Amount AS Amount,
	|	DocumentTable.CorrAccount AS AccountDr,
	|	CASE
	|		WHEN DocumentTable.CorrAccount.Currency
	|			THEN &PresentationCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN DocumentTable.CorrAccount.Currency
	|			THEN DocumentTable.Amount
	|		ELSE 0
	|	END AS AmountCurDr,
	|	DocumentTable.Account AS AccountCr,
	|	CASE
	|		WHEN DocumentTable.Account.Currency
	|			THEN &PresentationCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	CASE
	|		WHEN DocumentTable.Account.Currency
	|			THEN DocumentTable.Amount
	|		ELSE 0
	|	END AS AmountCurCr,
	|	CAST(DocumentTable.Comment AS String(100)) AS Content
	|FROM
	|	Document.Budget.Disposal AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref");
	
	Query.SetParameter("Ref", DocumentRefBudget);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency", Constants.PresentationCurrency.Get());
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	
	While Selection.Next() Do
		NewRow = StructureAdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries.Add();
		FillPropertyValues(NewRow, Selection);
	EndDo;
	
EndProcedure

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentDataReceipts(DocumentRefBudget, StructureAdditionalProperties)
	
	Query = New Query(
	"SELECT
	|	DocumentTable.PlanningDate AS Period,
	|	&Company AS Company,
	|	DocumentTable.Ref.PlanningPeriod AS PlanningPeriod,
	|	DocumentTable.Amount AS Amount,
	|	DocumentTable.Account AS AccountDr,
	|	CASE
	|		WHEN DocumentTable.Account.Currency
	|			THEN &PresentationCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN DocumentTable.Account.Currency
	|			THEN DocumentTable.Amount
	|		ELSE 0
	|	END AS AmountCurDr,
	|	DocumentTable.CorrAccount AS AccountCr,
	|	CASE
	|		WHEN DocumentTable.CorrAccount.Currency
	|			THEN &PresentationCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	CASE
	|		WHEN DocumentTable.CorrAccount.Currency
	|			THEN DocumentTable.Amount
	|		ELSE 0
	|	END AS AmountCurCr,
	|	CAST(DocumentTable.Comment AS String(100)) AS Content
	|FROM
	|	Document.Budget.Receipts AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref");
	
	Query.SetParameter("Ref", DocumentRefBudget);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency", Constants.PresentationCurrency.Get());
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	
	While Selection.Next() Do
		NewRow = StructureAdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries.Add();
		FillPropertyValues(NewRow, Selection);
	EndDo;
	
EndProcedure

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentDataAccountingRecords(DocumentRefBudget, StructureAdditionalProperties)
	
	Query = New Query(
	"SELECT
	|	DocumentTable.PlanningDate AS Period,
	|	&Company AS Company,
	|	DocumentTable.Ref.PlanningPeriod AS PlanningPeriod,
	|	DocumentTable.Amount AS Amount,
	|	DocumentTable.AccountDr AS AccountDr,
	|	CASE
	|		WHEN DocumentTable.AccountDr.Currency
	|			THEN &PresentationCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN DocumentTable.AccountDr.Currency
	|			THEN DocumentTable.Amount
	|		ELSE 0
	|	END AS AmountCurDr,
	|	DocumentTable.AccountCr AS AccountCr,
	|	CASE
	|		WHEN DocumentTable.AccountCr.Currency
	|			THEN &PresentationCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	CASE
	|		WHEN DocumentTable.AccountCr.Currency
	|			THEN DocumentTable.Amount
	|		ELSE 0
	|	END AS AmountCurCr,
	|	CAST(DocumentTable.Comment AS STRING(100)) AS Content,
	|	FALSE AS OfflineRecord
	|FROM
	|	Document.Budget.Operations AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref");
	
	Query.SetParameter("Ref", DocumentRefBudget);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency", Constants.PresentationCurrency.Get());
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	
	While Selection.Next() Do
		NewRow = StructureAdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries.Add();
		FillPropertyValues(NewRow, Selection);
	EndDo;
	
EndProcedure

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentDataBalances(DocumentRefBudget, StructureAdditionalProperties)
	
	Query = New Query(
	"SELECT
	|	DATEADD(DocumentTable.Ref.PlanningPeriod.StartDate, Second, -1) AS Period,
	|	&Company AS Company,
	|	DocumentTable.Ref.PlanningPeriod AS PlanningPeriod,
	|	DocumentTable.Amount AS Amount,
	|	&OBEAccount AS AccountDr,
	|	UNDEFINED AS CurrencyDr,
	|	0 AS AmountCurDr,
	|	DocumentTable.Account AS AccountCr,
	|	CASE
	|		WHEN DocumentTable.Account.Currency
	|			THEN &PresentationCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	CASE
	|		WHEN DocumentTable.Account.Currency
	|			THEN DocumentTable.Amount
	|		ELSE 0
	|	END AS AmountCurCr,
	|	CAST(&Content AS String(100)) AS Content
	|FROM
	|	Document.Budget.Balance AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|	AND DocumentTable.Account.TypeOfAccount IN(&CreditAccountTypes)
	|
	|UNION ALL
	|
	|SELECT
	|	DATEADD(DocumentTable.Ref.PlanningPeriod.StartDate, Second, -1),
	|	&Company,
	|	DocumentTable.Ref.PlanningPeriod,
	|	DocumentTable.Amount,
	|	DocumentTable.Account,
	|	CASE
	|		WHEN DocumentTable.Account.Currency
	|			THEN &PresentationCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.Account.Currency
	|			THEN DocumentTable.Amount
	|		ELSE 0
	|	END,
	|	&OBEAccount,
	|	UNDEFINED,
	|	0,
	|	CAST(&Content AS String(100))
	|FROM
	|	Document.Budget.Balance AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|	AND DocumentTable.Account.TypeOfAccount IN(&DebetAccountTypes)");
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();

	Query.SetParameter("OBEAccount",			Catalogs.DefaultGLAccounts.GetDefaultGLAccount("OpeningBalanceEquity"));
	Query.SetParameter("Ref",					DocumentRefBudget);
	Query.SetParameter("Company",				StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency",	Constants.PresentationCurrency.Get());
	Query.SetParameter("Content",				NStr("en = 'Opening balance forecast'", MainLanguageCode));
	
	DebetAccountTypes = New ValueList;
	DebetAccountTypes.Add(Enums.GLAccountsTypes.FixedAssets);
	DebetAccountTypes.Add(Enums.GLAccountsTypes.AccountsReceivable);
	DebetAccountTypes.Add(Enums.GLAccountsTypes.CashAndCashEquivalents);
	DebetAccountTypes.Add(Enums.GLAccountsTypes.Inventory);
	DebetAccountTypes.Add(Enums.GLAccountsTypes.IndirectExpenses);
	DebetAccountTypes.Add(Enums.GLAccountsTypes.ShorttermInvestments);
	DebetAccountTypes.Add(Enums.GLAccountsTypes.WorkInProcess);
	DebetAccountTypes.Add(Enums.GLAccountsTypes.OtherFixedAssets);
	DebetAccountTypes.Add(Enums.GLAccountsTypes.OtherCurrentAssets);
	DebetAccountTypes.Add(Enums.GLAccountsTypes.OtherExpenses);
	DebetAccountTypes.Add(Enums.GLAccountsTypes.Expenses);
	DebetAccountTypes.Add(Enums.GLAccountsTypes.CostOfSales);
	DebetAccountTypes.Add(Enums.GLAccountsTypes.LoanInterest);
	DebetAccountTypes.Add(Enums.GLAccountsTypes.IncomeTax);
	
	CreditAccountTypes = New ValueList;
	CreditAccountTypes.Add(Enums.GLAccountsTypes.Depreciation);
	CreditAccountTypes.Add(Enums.GLAccountsTypes.LongtermLiabilities);
	CreditAccountTypes.Add(Enums.GLAccountsTypes.Revenue);
	CreditAccountTypes.Add(Enums.GLAccountsTypes.Capital);
	CreditAccountTypes.Add(Enums.GLAccountsTypes.AccountsPayable);
	CreditAccountTypes.Add(Enums.GLAccountsTypes.LoansBorrowed);
	CreditAccountTypes.Add(Enums.GLAccountsTypes.RetainedEarnings);
	CreditAccountTypes.Add(Enums.GLAccountsTypes.ProfitLosses);
	CreditAccountTypes.Add(Enums.GLAccountsTypes.OtherIncome);
	CreditAccountTypes.Add(Enums.GLAccountsTypes.OtherShorttermObligations);
	CreditAccountTypes.Add(Enums.GLAccountsTypes.ReserveAndAdditionalCapital);
	
	Query.SetParameter("DebetAccountTypes", DebetAccountTypes);
	Query.SetParameter("CreditAccountTypes", CreditAccountTypes);
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountingJournalEntries", QueryResult.Unload());
	
EndProcedure

// Generates allocation base table.
//
// Parameters:
// DistributionBase - Enums.CostAllocationMethod
// GLAccountsArray - Array containing filter by
// GL accounts FilterByStructuralUnit - filer by
// structural units FilterByOrder - Filter by goods orders
//
// Returns:
//  ValuesTable containing allocation base.
//
Function GenerateFinancialResultDistributionBaseTable(DistributionBase, PlanningPeriod, StartDate, EndDate, FilterByStructuralUnit, FilterByBusinessLine, FilterByOrder, AdditionalProperties)
	
	ResultTable = New ValueTable;
	
	If DistributionBase = Enums.CostAllocationMethod.SalesVolume Then
		
		QueryText = 
		"SELECT
		|	SalesTurnovers.Company AS Company,
		|	SalesTurnovers.Products.BusinessLine AS BusinessLine,
		|	SalesTurnovers.SalesOrder AS Order,
		|	SalesTurnovers.Products.BusinessLine.GLAccountRevenueFromSales AS GLAccountRevenueFromSales,
		|	SalesTurnovers.Products.BusinessLine.GLAccountCostOfSales AS GLAccountCostOfSales,
		|	SalesTurnovers.Products.BusinessLine.ProfitGLAccount AS ProfitGLAccount,
		|	SalesTurnovers.StructuralUnit AS StructuralUnit,
		|	SalesTurnovers.QuantityTurnover AS Base
		|FROM
		|	AccumulationRegister.SalesTarget.Turnovers(
		|			&StartDate,
		|			&EndDate,
		|			Auto,
		|			Company = &Company
		|			AND PlanningPeriod = &PlanningPeriod
		|				// FilterByStructuralUnit
		|				// FilterByBusinessLine
		|				// FilterByOrder
		|			) AS SalesTurnovers";
		
		QueryText = StrReplace(QueryText, "// FilterByStructuralUnit", ?(ValueIsFilled(FilterByStructuralUnit), "AND StructuralUnit IN (&BusinessUnitsArray)", ""));
		QueryText = StrReplace(QueryText, "// FilterByBusinessLine", ?(ValueIsFilled(FilterByBusinessLine), "And Products.BusinessLine IN (&ActivityDirectionsArray)", ""));
		QueryText = StrReplace(QueryText, "// FilterByOrder", ?(ValueIsFilled(FilterByOrder), "And SalesOrder IN (&OrdersArray)", ""));
				
	ElsIf DistributionBase = Enums.CostAllocationMethod.SalesRevenue Then
		
		QueryText = 
		"SELECT
		|	&Company AS Company,
		|	Budget.BusinessLine AS BusinessLine,
		|	Budget.SalesOrder AS Order,
		|	Budget.BusinessLine.GLAccountRevenueFromSales AS GLAccountRevenueFromSales,
		|	Budget.BusinessLine.GLAccountCostOfSales AS GLAccountCostOfSales,
		|	Budget.BusinessLine.ProfitGLAccount AS ProfitGLAccount,
		|	Budget.StructuralUnit AS StructuralUnit,
		|	Budget.Amount AS Base
		|FROM
		|	Document.Budget.Incomings AS Budget
		|WHERE
		|	Budget.Ref = &Ref
		|	AND Budget.Account.TypeOfAccount = VALUE(Enum.GLAccountsTypes.Revenue)
		|	AND Budget.PlanningDate between &StartDate AND &EndDate
		|	// FilterByStructuralUnit
		|	// FilterByBusinessLine
		|	// FilterByOrder
		|";
		
		QueryText = StrReplace(QueryText, "// FilterByStructuralUnit", ?(ValueIsFilled(FilterByStructuralUnit), "AND Budget.StructuralUnit IN (&BusinessUnitsArray)", ""));
		QueryText = StrReplace(QueryText, "// FilterByBusinessLine", ?(ValueIsFilled(FilterByBusinessLine), "And Budget.BusinessArea IN (&BusinessAreaArray)", ""));
		QueryText = StrReplace(QueryText, "// FilterByOrder", ?(ValueIsFilled(FilterByOrder), "AND Budget.SalesOrder IN (&OdersArray)", ""));
		
	ElsIf DistributionBase = Enums.CostAllocationMethod.CostOfGoodsSold Then
		
		QueryText = 
		"SELECT
		|	&Company AS Company,
		|	Budget.BusinessLine AS BusinessLine,
		|	Budget.SalesOrder AS Order,
		|	Budget.BusinessLine.GLAccountRevenueFromSales AS GLAccountRevenueFromSales,
		|	Budget.BusinessLine.GLAccountCostOfSales AS GLAccountCostOfSales,
		|	Budget.BusinessLine.ProfitGLAccount AS ProfitGLAccount,
		|	Budget.StructuralUnit AS StructuralUnit,
		|	Budget.Amount AS Base
		|FROM
		|	Document.Budget.Expenses AS Budget
		|WHERE
		|	Budget.Ref = &Ref
		|	AND Budget.Account.TypeOfAccount = VALUE(Enum.GLAccountsTypes.CostOfSales)
		|	AND Budget.PlanningDate between &StartDate AND &EndDate
		|	// FilterByStructuralUnit
		|	// FilterByBusinessLine
		|	// FilterByOrder
		|";
		
		QueryText = StrReplace(QueryText, "// FilterByStructuralUnit", ?(ValueIsFilled(FilterByStructuralUnit), "AND Budget.StructuralUnit IN (&BusinessUnitsArray)", ""));
		QueryText = StrReplace(QueryText, "// FilterByBusinessLine", ?(ValueIsFilled(FilterByBusinessLine), "And Budget.BusinessArea IN (&BusinessAreaArray)", ""));
		QueryText = StrReplace(QueryText, "// FilterByOrder", ?(ValueIsFilled(FilterByOrder), "AND Budget.SalesOrder IN (&OdersArray)", ""));
		
	ElsIf DistributionBase = Enums.CostAllocationMethod.GrossProfit Then
		
		QueryText =
		"SELECT
		|	Table.Company AS Company,
		|	Table.BusinessLine AS BusinessLine,
		|	Table.Order AS Order,
		|	Table.GLAccountRevenueFromSales AS GLAccountRevenueFromSales,
		|	Table.GLAccountCostOfSales AS GLAccountCostOfSales,
		|	Table.ProfitGLAccount AS ProfitGLAccount,
		|	Table.StructuralUnit AS StructuralUnit,
		|	SUM(Table.Base) AS Base
		|     |FROM
		|	(SELECT
		|		&Company AS Company,
		|		Budget.BusinessLine AS BusinessLine,
		|		Budget.SalesOrder AS Order,
		|		Budget.BusinessLine.GLAccountRevenueFromSales AS GLAccountRevenueFromSales,
		|		Budget.BusinessLine.GLAccountCostOfSales AS GLAccountCostOfSales,
		|		Budget.BusinessLine.ProfitGLAccount AS ProfitGLAccount,
		|		Budget.StructuralUnit AS StructuralUnit,
		|		Budget.Amount AS Base
		|	FROM
		|		Document.Budget.Incomings AS Budget
		|	WHERE
		|		Budget.Ref = &Ref
		|		AND Budget.Account.TypeOfAccount = VALUE(Enum.GLAccountsTypes.Revenue)
		|		AND Budget.PlanningDate between &StartDate AND &EndDate
		|		// FilterByStructuralUnit
		|		// FilterByBusinessLine
		|		// FilterByOrder
		|
		|	UNION ALL
		|
		|	SELECT
		|		&Company,
		|		Budget.BusinessLine,
		|		Budget.SalesOrder,
		|		Budget.BusinessLine.GLAccountRevenueFromSales,
		|		Budget.BusinessLine.GLAccountCostOfSales,
		|		Budget.BusinessLine.ProfitGLAccount,
		|		Budget.StructuralUnit,
		|		- Budget.Amount AS Base
		|	FROM
		|		Document.Budget.Expenses AS Budget
		|	WHERE
		|		Budget.Ref = &Ref
		|		AND Budget.PlanningDate between &StartDate AND &EndDate
		|		AND Budget.Account.TypeOfAccount = VALUE(Enum.GLAccountsTypes.CostOfSales)
		|		// FilterByStructuralUnit
		|		// FilterByBusinessLine
		|		// FilterByOrder
		|	) AS Table
		|
		|GROUP BY
		|	Table.Company,
		|	Table.BusinessLine,
		|	Table.Order,
		|	Table.GLAccountRevenueFromSales,
		|	Table.GLAccountCostOfSales,
		|	Table.ProfitGLAccount,
		|	Table.StructuralUnit";
			
	Else
		
		Return ResultTable;
		
	EndIf;
	
	Query = New Query;
	Query.Text = QueryText;
	
	Query.SetParameter("StartDate"		  , StartDate);
	Query.SetParameter("EndDate"	  , EndDate);
	Query.SetParameter("Ref"			  , AdditionalProperties.ForPosting.Ref);
	Query.SetParameter("Company"		  , AdditionalProperties.ForPosting.Company);
	Query.SetParameter("PlanningPeriod", PlanningPeriod);
			
	If ValueIsFilled(FilterByOrder) Then
		If TypeOf(FilterByOrder) = Type("Array") Then
			Query.SetParameter("OrdersArray", FilterByOrder);
		Else
			ArrayForSelection = New Array;
			ArrayForSelection.Add(FilterByOrder);
			Query.SetParameter("OrdersArray", ArrayForSelection);
		EndIf;
	EndIf;
	
	If ValueIsFilled(FilterByStructuralUnit) Then
		If TypeOf(FilterByStructuralUnit) = Type("Array") Then
			Query.SetParameter("BusinessUnitsArray", FilterByStructuralUnit);
		Else
			ArrayForSelection = New Array;
			ArrayForSelection.Add(FilterByStructuralUnit);
			Query.SetParameter("BusinessUnitsArray", ArrayForSelection);
		EndIf;
	EndIf;
	
	If ValueIsFilled(FilterByBusinessLine) Then
		If TypeOf(FilterByBusinessLine) = Type("Array") Then
			Query.SetParameter("ActivityDirectionsArray", FilterByBusinessLine);
		Else
			ArrayForSelection = New Array;
			ArrayForSelection.Add(FilterByBusinessLine);
			Query.SetParameter("ActivityDirectionsArray", FilterByBusinessLine);
		EndIf;
	EndIf;
	
	ResultTable = Query.Execute().Unload();
	
	Return ResultTable;
	
EndFunction

// Distributing financial result throughtout the base.
//
Procedure DistributeFinancialResultThroughoutBase(DocumentRefBudget, StructureAdditionalProperties, StartDate, EndDate)
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	IncomeAndExpenses.Company AS Company,
	|	IncomeAndExpenses.Date AS Date,
	|	IncomeAndExpenses.PlanningPeriod AS PlanningPeriod,
	|	IncomeAndExpenses.StructuralUnit AS StructuralUnit,
	|	IncomeAndExpenses.BusinessLine AS BusinessLine,
	|	IncomeAndExpenses.ProfitGLAccount AS ProfitGLAccount,
	|	IncomeAndExpenses.Order AS Order,
	|	IncomeAndExpenses.GLAccount AS GLAccount,
	|	IncomeAndExpenses.MethodOfDistribution AS GLAccountMethodOfDistribution,
	|	SUM(IncomeAndExpenses.AmountIncome) AS AmountIncome,
	|	SUM(IncomeAndExpenses.AmountExpense) AS AmountExpense
	|FROM
	|	(SELECT
	|		&Company AS Company,
	|		DocumentTable.PlanningDate AS Date,
	|		DocumentTable.Ref.PlanningPeriod AS PlanningPeriod,
	|		DocumentTable.StructuralUnit AS StructuralUnit,
	|		DocumentTable.BusinessLine AS BusinessLine,
	|		DocumentTable.BusinessLine.ProfitGLAccount AS ProfitGLAccount,
	|		DocumentTable.SalesOrder AS Order,
	|		DocumentTable.Account AS GLAccount,
	|		DocumentTable.Account.MethodOfDistribution AS MethodOfDistribution,
	|		DocumentTable.Amount AS AmountIncome,
	|		0 AS AmountExpense
	|	FROM
	|		Document.Budget.Incomings AS DocumentTable
	|	WHERE
	|		DocumentTable.PlanningDate between &StartDate AND &EndDate
	|		AND DocumentTable.Ref = &Ref
	|		AND (DocumentTable.Account.MethodOfDistribution <> VALUE(Enum.CostAllocationMethod.DoNotDistribute)
	|				OR (DocumentTable.BusinessLine.GLAccountCostOfSales <> DocumentTable.Account
	|						AND DocumentTable.BusinessLine.GLAccountRevenueFromSales <> DocumentTable.Account
	|					OR DocumentTable.BusinessLine = VALUE(Catalog.LinesOfBusiness.Other)
	|					OR DocumentTable.BusinessLine = VALUE(Catalog.LinesOfBusiness.EmptyRef)))
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		&Company,
	|		DocumentTable.PlanningDate,
	|		DocumentTable.Ref.PlanningPeriod,
	|		DocumentTable.StructuralUnit,
	|		DocumentTable.BusinessLine,
	|		DocumentTable.BusinessLine.ProfitGLAccount,
	|		DocumentTable.SalesOrder,
	|		DocumentTable.Account,
	|		DocumentTable.Account.MethodOfDistribution,
	|		0,
	|		DocumentTable.Amount
	|	FROM
	|		Document.Budget.Expenses AS DocumentTable
	|	WHERE
	|		DocumentTable.PlanningDate between &StartDate AND &EndDate
	|		AND DocumentTable.Ref = &Ref
	|		AND (DocumentTable.Account.MethodOfDistribution <> VALUE(Enum.CostAllocationMethod.DoNotDistribute)
	|				OR (DocumentTable.BusinessLine.GLAccountCostOfSales <> DocumentTable.Account
	|						AND DocumentTable.BusinessLine.GLAccountRevenueFromSales <> DocumentTable.Account
	|					OR DocumentTable.BusinessLine = VALUE(Catalog.LinesOfBusiness.Other)
	|					OR DocumentTable.BusinessLine = VALUE(Catalog.LinesOfBusiness.EmptyRef)))) AS IncomeAndExpenses
	|
	|GROUP BY
	|	IncomeAndExpenses.Company,
	|	IncomeAndExpenses.Date,
	|	IncomeAndExpenses.PlanningPeriod,
	|	IncomeAndExpenses.StructuralUnit,
	|	IncomeAndExpenses.BusinessLine,
	|	IncomeAndExpenses.ProfitGLAccount,
	|	IncomeAndExpenses.Order,
	|	IncomeAndExpenses.GLAccount,
	|	IncomeAndExpenses.MethodOfDistribution
	|
	|ORDER BY
	|	GLAccountMethodOfDistribution,
	|	StructuralUnit,
	|	BusinessLine,
	|	Order
	|TOTALS
	|	SUM(AmountIncome),
	|	SUM(AmountExpense)
	|BY
	|	GLAccountMethodOfDistribution,
	|	StructuralUnit,
	|	BusinessLine,
	|	Order";
	
	Query.SetParameter("Ref", DocumentRefBudget);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("StartDate", StartDate);
	Query.SetParameter("EndDate", EndDate);
	
	QueryResult = Query.Execute();
	
	If QueryResult.IsEmpty() Then
		Return;
	EndIf;
	
	BypassByDistributionMethod = QueryResult.Select(QueryResultIteration.ByGroups);
	
	While BypassByDistributionMethod.Next() Do
		
		BypassByStructuralUnit = BypassByDistributionMethod.Select(QueryResultIteration.ByGroups);
		
		// Bypass on departments.
		While BypassByStructuralUnit.Next() Do
			
			FilterByStructuralUnit = BypassByStructuralUnit.StructuralUnit;
			
			BypassByActivityDirection = BypassByStructuralUnit.Select(QueryResultIteration.ByGroups);
			
			While BypassByActivityDirection.Next() Do
				
				FilterByBusinessLine = BypassByActivityDirection.BusinessLine;
				
				BypassByOrder = BypassByActivityDirection.Select(QueryResultIteration.ByGroups);
				
				// Bypass on orders.
				While BypassByOrder.Next() Do
				
					FilterByOrder = BypassByOrder.Order;
					
					If BypassByOrder.GLAccountMethodOfDistribution = Enums.CostAllocationMethod.DoNotDistribute Then
						Continue;
					EndIf;
					
					// Generate allocation base table.
					BaseTable = GenerateFinancialResultDistributionBaseTable(
						BypassByOrder.GLAccountMethodOfDistribution,
						StructureAdditionalProperties.ForPosting.PlanningPeriod,
						StartDate,
						EndDate,
						FilterByStructuralUnit,
						FilterByBusinessLine,
						FilterByOrder,
						StructureAdditionalProperties
					);
					
					If BaseTable.Count() = 0 Then
						BaseTable = GenerateFinancialResultDistributionBaseTable(
							BypassByOrder.GLAccountMethodOfDistribution,
							StructureAdditionalProperties.ForPosting.PlanningPeriod,
							StartDate,
							EndDate,
							FilterByStructuralUnit,
							FilterByBusinessLine,
							Undefined,
							StructureAdditionalProperties
						);
					EndIf;
					
					If BaseTable.Count() = 0 Then
						BaseTable = GenerateFinancialResultDistributionBaseTable(
							BypassByOrder.GLAccountMethodOfDistribution,
							StructureAdditionalProperties.ForPosting.PlanningPeriod,
							StartDate,
							EndDate,
							FilterByStructuralUnit,
							Undefined,
							Undefined,
							StructureAdditionalProperties
						);
					EndIf;
					
					If BaseTable.Count() = 0 Then
						BaseTable = GenerateFinancialResultDistributionBaseTable(
							BypassByOrder.GLAccountMethodOfDistribution,
							StructureAdditionalProperties.ForPosting.PlanningPeriod,
							StartDate,
							EndDate,
							Undefined,
							Undefined,
							Undefined,
							StructureAdditionalProperties
						);
					EndIf;
					
					TotalBaseDistribution = BaseTable.Total("Base");
					DirectionsQuantity  = BaseTable.Count() - 1;
					
					BypassByGLAccounts = BypassByOrder.Select(QueryResultIteration.ByGroups);
					
					// Bypass on the expenses accounts.
					While BypassByGLAccounts.Next() Do
						
						If BaseTable.Count() = 0
						 OR TotalBaseDistribution = 0 Then
							BaseTable = New ValueTable;
							BaseTable.Columns.Add("Company");
							BaseTable.Columns.Add("StructuralUnit");
							BaseTable.Columns.Add("BusinessLine");
							BaseTable.Columns.Add("Order");
							BaseTable.Columns.Add("GLAccountRevenueFromSales");
							BaseTable.Columns.Add("GLAccountCostOfSales");
							BaseTable.Columns.Add("ProfitGLAccount");
							BaseTable.Columns.Add("Base");
							TableRow = BaseTable.Add();
							TableRow.Company = BypassByGLAccounts.Company;
							TableRow.StructuralUnit = BypassByGLAccounts.StructuralUnit;
							TableRow.BusinessLine = Catalogs.LinesOfBusiness.MainLine;
							TableRow.Order = BypassByGLAccounts.Order;
							TableRow.GLAccountRevenueFromSales = BypassByGLAccounts.GLAccount;
							TableRow.GLAccountCostOfSales = BypassByGLAccounts.GLAccount;
							TableRow.ProfitGLAccount = Catalogs.LinesOfBusiness.MainLine.ProfitGLAccount;
							TableRow.Base = 1;
							TotalBaseDistribution = 1;
						EndIf;
					
						// Allocate amount.
						If BypassByGLAccounts.AmountIncome <> 0 
						 OR BypassByGLAccounts.AmountExpense <> 0 Then
						 
						 	If BypassByGLAccounts.AmountIncome <> 0 Then
								SumDistribution = BypassByGLAccounts.AmountIncome;
							ElsIf BypassByGLAccounts.AmountExpense <> 0 Then
								SumDistribution = BypassByGLAccounts.AmountExpense;
							EndIf;
								
							SumWasDistributed = 0;
						
							For Each DistributionDirection In BaseTable Do
							
								CostAmount = ?(SumDistribution = 0, 0, Round(DistributionDirection.Base / TotalBaseDistribution * SumDistribution, 2, 1));
								SumWasDistributed = SumWasDistributed + CostAmount;
							
								// If it is the last string - , correct amount in it to the rounding error.
								If BaseTable.IndexOf(DistributionDirection) = DirectionsQuantity Then
									CostAmount	= CostAmount + SumDistribution - SumWasDistributed;
								EndIf;
							
								If CostAmount <> 0 Then
									
									// Movements by register Financial result.
									NewRow	= StructureAdditionalProperties.TableForRegisterRecords.TableFinancialResultForecast.Add();
									NewRow.Period = BypassByGLAccounts.Date;
									NewRow.PlanningPeriod = BypassByGLAccounts.PlanningPeriod;
									NewRow.Recorder	= DocumentRefBudget;
									NewRow.Company	= DistributionDirection.Company;
									NewRow.StructuralUnit = DistributionDirection.StructuralUnit;
									NewRow.BusinessLine	= DistributionDirection.BusinessLine;
									
									NewRow.GLAccount = BypassByGLAccounts.GLAccount;
									If BypassByGLAccounts.AmountIncome <> 0 Then
										NewRow.AmountIncome = CostAmount;
									ElsIf BypassByGLAccounts.AmountExpense <> 0 Then
										NewRow.AmountExpense = CostAmount;
									EndIf;
									
									// Movements by register AccountingJournalEntries.
									NewRow = StructureAdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries.Add();
									NewRow.Period = BypassByGLAccounts.Date;
									NewRow.Company = StructureAdditionalProperties.ForPosting.Company;
									NewRow.PlanningPeriod = BypassByGLAccounts.PlanningPeriod;
									
									If BypassByGLAccounts.AmountIncome <> 0 Then
										NewRow.AccountDr = BypassByGLAccounts.GLAccount;
										NewRow.AccountCr = DistributionDirection.ProfitGLAccount;
										NewRow.Amount = CostAmount; 
									ElsIf BypassByGLAccounts.AmountExpense <> 0 Then
										NewRow.AccountDr = DistributionDirection.ProfitGLAccount;
										NewRow.AccountCr = BypassByGLAccounts.GLAccount;
										NewRow.Amount = CostAmount;
									EndIf;
									
									NewRow.Content = "Financial result (forecast)";
									
								EndIf;
								
							EndDo;
						
							If SumWasDistributed = 0 Then
								
								MessageText = NStr("en = 'Financial result calculation: The ""%GLAccount%"" GL account has no distribution base.'");
								MessageText = StrReplace(MessageText, "%GLAccount%", String(BypassByGLAccounts.GLAccount));
								DriveServer.ShowMessageAboutError(DocumentRefBudget, MessageText); 
								Continue;
								
							EndIf;
						
						EndIf
					
					EndDo;
				
				EndDo;
				
			EndDo;
			
		EndDo;
		
	EndDo;
	
EndProcedure

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentDataFinancialResultForecast(DocumentRefBudget, StructureAdditionalProperties)
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	&Company AS Company,
	|	DocumentTable.PlanningDate AS Date,
	|	DocumentTable.Ref.PlanningPeriod AS PlanningPeriod,
	|	DocumentTable.StructuralUnit AS StructuralUnit,
	|	DocumentTable.BusinessLine AS BusinessLine,
	|	DocumentTable.BusinessLine.ProfitGLAccount AS ProfitGLAccount,
	|	DocumentTable.SalesOrder AS Order,
	|	DocumentTable.Account AS GLAccount,
	|	DocumentTable.Amount AS AmountIncome,
	|	0 AS AmountExpense
	|FROM
	|	Document.Budget.Incomings AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|	AND (DocumentTable.Account.MethodOfDistribution = VALUE(Enum.CostAllocationMethod.DoNotDistribute)
	|			OR (DocumentTable.BusinessLine.GLAccountCostOfSales = DocumentTable.Account
	|				OR DocumentTable.BusinessLine.GLAccountRevenueFromSales = DocumentTable.Account)
	|				AND DocumentTable.BusinessLine <> VALUE(Catalog.LinesOfBusiness.Other))
	|
	|UNION ALL
	|
	|SELECT
	|	&Company,
	|	DocumentTable.PlanningDate,
	|	DocumentTable.Ref.PlanningPeriod,
	|	DocumentTable.StructuralUnit,
	|	DocumentTable.BusinessLine,
	|	DocumentTable.BusinessLine.ProfitGLAccount,
	|	DocumentTable.SalesOrder,
	|	DocumentTable.Account,
	|	0,
	|	DocumentTable.Amount
	|FROM
	|	Document.Budget.Expenses AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|	AND (DocumentTable.Account.MethodOfDistribution = VALUE(Enum.CostAllocationMethod.DoNotDistribute)
	|			OR (DocumentTable.BusinessLine.GLAccountCostOfSales = DocumentTable.Account
	|				OR DocumentTable.BusinessLine.GLAccountRevenueFromSales = DocumentTable.Account)
	|				AND DocumentTable.BusinessLine <> VALUE(Catalog.LinesOfBusiness.Other))";
	
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("Ref", DocumentRefBudget);
	
	QueryResult = Query.Execute();
	
	TableFinancialResultForecast = New ValueTable;
	
	TableFinancialResultForecast.Columns.Add("LineNumber");
	TableFinancialResultForecast.Columns.Add("Recorder");
	TableFinancialResultForecast.Columns.Add("Period");
	TableFinancialResultForecast.Columns.Add("Company");
	TableFinancialResultForecast.Columns.Add("PlanningPeriod");
	TableFinancialResultForecast.Columns.Add("StructuralUnit");
	TableFinancialResultForecast.Columns.Add("BusinessLine");
	TableFinancialResultForecast.Columns.Add("GLAccount");
	TableFinancialResultForecast.Columns.Add("AmountIncome");
	TableFinancialResultForecast.Columns.Add("AmountExpense");
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableFinancialResultForecast", TableFinancialResultForecast);
	
	SelectionQueryResult = QueryResult.Select();
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();

	While SelectionQueryResult.Next() Do
		
		// Movements by register Financial result.
		NewRow = StructureAdditionalProperties.TableForRegisterRecords.TableFinancialResultForecast.Add();
		NewRow.Period = SelectionQueryResult.Date;
		NewRow.Recorder = DocumentRefBudget;
		NewRow.PlanningPeriod = SelectionQueryResult.PlanningPeriod;
		NewRow.Company = SelectionQueryResult.Company;
		NewRow.StructuralUnit = SelectionQueryResult.StructuralUnit;
		NewRow.BusinessLine = ?(
			ValueIsFilled(SelectionQueryResult.BusinessLine), SelectionQueryResult.BusinessLine, Catalogs.LinesOfBusiness.MainLine
		);

		NewRow.GLAccount = SelectionQueryResult.GLAccount;
		
		If SelectionQueryResult.AmountIncome <> 0 Then
			NewRow.AmountIncome = SelectionQueryResult.AmountIncome;
		ElsIf SelectionQueryResult.AmountExpense <> 0 Then
			NewRow.AmountExpense = SelectionQueryResult.AmountExpense;
		EndIf;
		
		// Movements by register AccountingJournalEntries.
		NewRow = StructureAdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries.Add();
		NewRow.Period = SelectionQueryResult.Date;
		NewRow.Company = SelectionQueryResult.Company;
		NewRow.PlanningPeriod = SelectionQueryResult.PlanningPeriod;
		
		If SelectionQueryResult.AmountIncome <> 0 Then
			NewRow.AccountDr = SelectionQueryResult.GLAccount;
			NewRow.AccountCr = ?(
				ValueIsFilled(SelectionQueryResult.BusinessLine),
				SelectionQueryResult.ProfitGLAccount,
				Catalogs.LinesOfBusiness.MainLine.ProfitGLAccount
			);
			NewRow.Amount = SelectionQueryResult.AmountIncome; 
		ElsIf SelectionQueryResult.AmountExpense <> 0 Then
			NewRow.AccountDr = ?(
				ValueIsFilled(SelectionQueryResult.BusinessLine),
				SelectionQueryResult.ProfitGLAccount,
				Catalogs.LinesOfBusiness.MainLine.ProfitGLAccount
			);
			NewRow.AccountCr = SelectionQueryResult.GLAccount;
			NewRow.Amount = SelectionQueryResult.AmountExpense;
		EndIf;
		
		NewRow.Content = NStr("en = 'Financial result (forecast)'", MainLanguageCode);
		
	EndDo;
	
	StartDate = StructureAdditionalProperties.ForPosting.StartDate;
	EndDate = StructureAdditionalProperties.ForPosting.EndDate;
	
	While StartDate < EndDate Do
		DistributeFinancialResultThroughoutBase(DocumentRefBudget, StructureAdditionalProperties, StartDate, EndOfMonth(StartDate));
		StartDate = EndOfMonth(StartDate) + 1;;
	EndDo;
	
EndProcedure

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefBudget, StructureAdditionalProperties) Export
	
	InitializeDocumentDataBalances(DocumentRefBudget, StructureAdditionalProperties);
	InitializeDocumentDataDirectCost(DocumentRefBudget, StructureAdditionalProperties);
	InitializeDocumentDataIndirectExpenses(DocumentRefBudget, StructureAdditionalProperties);
	InitializeDocumentDataAccountingRecords(DocumentRefBudget, StructureAdditionalProperties);
	InitializeDocumentDataReceipts(DocumentRefBudget, StructureAdditionalProperties);
	InitializeDocumentDataOutflows(DocumentRefBudget, StructureAdditionalProperties);
	InitializeDocumentDataIncome(DocumentRefBudget, StructureAdditionalProperties);
	InitializeDocumentDataExpenses(DocumentRefBudget, StructureAdditionalProperties);
	InitializeDocumentDataIncomeAndExpensesBudget(DocumentRefBudget, StructureAdditionalProperties);
	InitializeDocumentDataCashBudget(DocumentRefBudget, StructureAdditionalProperties);
	InitializeDocumentDataFinancialResultForecast(DocumentRefBudget, StructureAdditionalProperties);
	
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