#If Server OR ThickClientOrdinaryApplication OR ExternalConnection Then

// Generates the value table containing data to post for the register.
// Saves value tables to properties of the "AdditionalProperties" structure.
//
Procedure GenerateTableLoanSettlements(DocumentRefAccrualsForLoans, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();

	Query.SetParameter("Company",					StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("CreditInterestAccrued",		NStr("en = '(Received) loan interest is accrued'", MainLanguageCode));
	Query.SetParameter("CreditCommissionAccrued",	NStr("en = '(Received) loan commission is accrued'", MainLanguageCode));
	Query.SetParameter("LoanInterestAccrued",		NStr("en = '(Issued) loan interest is accrued'", MainLanguageCode));
	Query.SetParameter("LoanCommissionAccrued",		NStr("en = '(Issued) loan commission is accrued'", MainLanguageCode));
	Query.SetParameter("Ref",						DocumentRefAccrualsForLoans);
	Query.SetParameter("PointInTime",				New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, 
		BoundaryType.Including));	
	Query.SetParameter("PresentationCurrency",		Constants.PresentationCurrency.Get());
	
	Query.Text =
	"SELECT
	|	&Company AS Company,
	|	CASE
	|		WHEN AccrualsForLoansAccruals.Ref.OperationType = VALUE(Enum.LoanAccrualTypes.AccrualsForLoansBorrowed)
	|			THEN VALUE(AccumulationRecordType.Expense)
	|		ELSE VALUE(AccumulationRecordType.Receipt)
	|	END AS RecordType,
	|	CASE
	|		WHEN AccrualsForLoansAccruals.Ref.OperationType = VALUE(Enum.LoanAccrualTypes.AccrualsForLoansBorrowed)
	|			THEN AccrualsForLoansAccruals.Lender
	|		ELSE AccrualsForLoansAccruals.Employee
	|	END AS Counterparty,
	|	CASE
	|		WHEN AccrualsForLoansAccruals.Ref.OperationType = VALUE(Enum.LoanAccrualTypes.AccrualsForLoansBorrowed)
	|			THEN VALUE(Enum.LoanContractTypes.Borrowed)
	|		ELSE VALUE(Enum.LoanContractTypes.EmployeeLoanAgreement)
	|	END AS LoanKind,
	|	AccrualsForLoansAccruals.LoanContract AS LoanContract,
	|	AccrualsForLoansAccruals.Date AS Period,
	|	CASE
	|		WHEN AccrualsForLoansAccruals.AmountType = VALUE(Enum.LoanScheduleAmountTypes.Interest)
	|			THEN AccrualsForLoansAccruals.Total
	|		ELSE 0
	|	END AS InterestCur,
	|	CASE
	|		WHEN AccrualsForLoansAccruals.AmountType = VALUE(Enum.LoanScheduleAmountTypes.Commission)
	|			THEN AccrualsForLoansAccruals.Total
	|		ELSE 0
	|	END AS CommissionCur,
	|	CASE
	|		WHEN AccrualsForLoansAccruals.AmountType = VALUE(Enum.LoanScheduleAmountTypes.Interest)
	|			THEN CAST(AccrualsForLoansAccruals.Total * AccountingExchangeRates.Multiplicity * SettlementExchangeRates.ExchangeRate / (AccountingExchangeRates.ExchangeRate * SettlementExchangeRates.Multiplicity) AS NUMBER(15, 2))
	|		ELSE 0
	|	END AS Interest,
	|	CASE
	|		WHEN AccrualsForLoansAccruals.AmountType = VALUE(Enum.LoanScheduleAmountTypes.Commission)
	|			THEN CAST(AccrualsForLoansAccruals.Total * AccountingExchangeRates.Multiplicity * SettlementExchangeRates.ExchangeRate / (AccountingExchangeRates.ExchangeRate * SettlementExchangeRates.Multiplicity) AS NUMBER(15, 2))
	|		ELSE 0
	|	END AS Commission,
	|	CASE
	|		WHEN AccrualsForLoansAccruals.Ref.OperationType = VALUE(Enum.LoanAccrualTypes.AccrualsForLoansBorrowed)
	|			THEN CASE
	|					WHEN AccrualsForLoansAccruals.AmountType = VALUE(Enum.LoanScheduleAmountTypes.Commission)
	|						THEN &CreditCommissionAccrued
	|					ELSE &CreditInterestAccrued
	|				END
	|		ELSE CASE
	|				WHEN AccrualsForLoansAccruals.AmountType = VALUE(Enum.LoanScheduleAmountTypes.Commission)
	|					THEN &LoanCommissionAccrued
	|				ELSE &LoanInterestAccrued
	|			END
	|	END AS PostingContent
	|FROM
	|	Document.LoanInterestCommissionAccruals.Accruals AS AccrualsForLoansAccruals
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&PointInTime, ) AS SettlementExchangeRates
	|		ON AccrualsForLoansAccruals.SettlementsCurrency = SettlementExchangeRates.Currency
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&PointInTime, Currency = &PresentationCurrency) AS AccountingExchangeRates
	|		ON (AccountingExchangeRates.Currency = &PresentationCurrency)
	|WHERE
	|	AccrualsForLoansAccruals.Ref = &Ref";
	
	RequestResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableLoanSettlements", RequestResult.Unload());
	
EndProcedure

// Initializes value tables containing data of the document tabular sections.
// Saves value tables to properties of the "AdditionalProperties" structure.
//
Procedure InitializeDocumentData(DocumentRefAccrualsForLoans, StructureAdditionalProperties) Export

	Query = New Query(
	"SELECT
	|	AccrualsForLoansAccruals.Ref AS Ref,
	|	AccrualsForLoansAccruals.LineNumber AS LineNumber,
	|	AccrualsForLoansAccruals.AmountType AS AmountType,
	|	AccrualsForLoansAccruals.Date AS Date,
	|	AccrualsForLoansAccruals.Employee AS Employee,
	|	AccrualsForLoansAccruals.Lender AS Lender,
	|	AccrualsForLoansAccruals.LoanContract AS LoanContract,
	|	AccrualsForLoansAccruals.SettlementsCurrency AS SettlementsCurrency,
	|	AccrualsForLoansAccruals.Total AS AmountCur,
	|	CAST(AccrualsForLoansAccruals.Total * AccountingExchangeRates.Multiplicity * SettlementExchangeRates.ExchangeRate / (AccountingExchangeRates.ExchangeRate * SettlementExchangeRates.Multiplicity) AS NUMBER(15, 2)) AS Amount,
	|	CASE
	|		WHEN AccrualsForLoansAccruals.Ref.OperationType = &AccrualsForLoans
	|			THEN AccrualsForLoansAccruals.LoanContract.CostAccount
	|		ELSE CASE
	|				WHEN AccrualsForLoansAccruals.AmountType = VALUE(Enum.LoanScheduleAmountTypes.Interest)
	|					THEN AccrualsForLoansAccruals.LoanContract.InterestGLAccount
	|				ELSE AccrualsForLoansAccruals.LoanContract.CommissionGLAccount
	|			END
	|	END AS CostAccount,
	|	AccrualsForLoansAccruals.LoanContract.CostAccount AS GLAccountOfIncomeAndExpenses,
	|	AccrualsForLoansAccruals.LoanContract.StructuralUnit AS StructuralUnit,
	|	AccrualsForLoansAccruals.LoanContract.Order AS SalesOrder,
	|	CASE
	|		WHEN AccrualsForLoansAccruals.Ref.OperationType = &AccrualsForLoans
	|			THEN CASE
	|					WHEN AccrualsForLoansAccruals.AmountType = VALUE(Enum.LoanScheduleAmountTypes.Interest)
	|						THEN AccrualsForLoansAccruals.LoanContract.InterestGLAccount
	|					ELSE AccrualsForLoansAccruals.LoanContract.CommissionGLAccount
	|				END
	|		ELSE AccrualsForLoansAccruals.LoanContract.CostAccount
	|	END AS Correspondence
	|INTO Accruals
	|FROM
	|	Document.LoanInterestCommissionAccruals.Accruals AS AccrualsForLoansAccruals
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&PointInTime, ) AS SettlementExchangeRates
	|		ON AccrualsForLoansAccruals.SettlementsCurrency = SettlementExchangeRates.Currency
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&PointInTime, Currency = &PresentationCurrency) AS AccountingExchangeRates
	|		ON (AccountingExchangeRates.Currency = &PresentationCurrency)
	|WHERE
	|	AccrualsForLoansAccruals.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Accruals.LineNumber AS LineNumber,
	|	Accruals.Date AS Period,
	|	&Company AS Company,
	|	CASE
	|		WHEN Accruals.CostAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherExpenses)
	|				OR Accruals.CostAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.LoanInterest)
	|			THEN VALUE(Catalog.LinesOfBusiness.Other)
	|		ELSE Accruals.LoanContract.BusinessArea
	|	END AS BusinessLine,
	|	CASE
	|		WHEN Accruals.CostAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherExpenses)
	|				OR Accruals.CostAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.LoanInterest)
	|			THEN VALUE(Catalog.BusinessUnits.EmptyRef)
	|		ELSE Accruals.StructuralUnit
	|	END AS StructuralUnit,
	|	Accruals.GLAccountOfIncomeAndExpenses AS GLAccount,
	|	CASE
	|		WHEN Accruals.CostAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherExpenses)
	|				OR Accruals.CostAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.LoanInterest)
	|				OR Accruals.SalesOrder = VALUE(Document.SalesOrder.EmptyRef)
	|				OR Accruals.SalesOrder = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE Accruals.SalesOrder
	|	END AS SalesOrder,
	|	0 AS AmountIncome,
	|	Accruals.Amount AS AmountExpense,
	|	&OtherIncomeAndExpensePostingContent AS ContentOfAccountingRecord,
	|	FALSE AS OfflineRecord
	|FROM
	|	Accruals AS Accruals
	|WHERE
	|	Accruals.Ref.OperationType = &AccrualsForLoans
	|
	|UNION ALL
	|
	|SELECT
	|	OfflineRecords.LineNumber,
	|	OfflineRecords.Period,
	|	OfflineRecords.Company,
	|	OfflineRecords.BusinessLine,
	|	OfflineRecords.StructuralUnit,
	|	OfflineRecords.GLAccount,
	|	OfflineRecords.SalesOrder,
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
	|	Accruals.LineNumber AS LineNumber,
	|	Accruals.Ref.Date AS Period,
	|	&Company AS Company,
	|	CASE
	|		WHEN Accruals.CostAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherExpenses)
	|				OR Accruals.CostAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.LoanInterest)
	|			THEN VALUE(Catalog.LinesOfBusiness.Other)
	|		ELSE Accruals.LoanContract.BusinessArea
	|	END AS BusinessArea,
	|	CASE
	|		WHEN Accruals.CostAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherExpenses)
	|				OR Accruals.CostAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.LoanInterest)
	|			THEN VALUE(Catalog.BusinessUnits.EmptyRef)
	|		ELSE Accruals.StructuralUnit
	|	END AS StructuralUnit,
	|	Accruals.GLAccountOfIncomeAndExpenses AS GLAccount,
	|	CASE
	|		WHEN Accruals.Ref.OperationType = VALUE(Enum.LoanAccrualTypes.AccrualsForLoansLent)
	|			THEN Accruals.Employee
	|		ELSE Accruals.Lender
	|	END AS Dimension,
	|	CASE
	|		WHEN Accruals.CostAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherExpenses)
	|				OR Accruals.CostAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.LoanInterest)
	|				OR Accruals.SalesOrder = VALUE(Document.SalesOrder.EmptyRef)
	|				OR Accruals.SalesOrder = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE Accruals.SalesOrder
	|	END AS SalesOrder,
	|	Accruals.Amount AS AmountIncome,
	|	0 AS AmountExpense,
	|	Accruals.Amount AS Amount,
	|	&OtherIncomeAndExpensePostingContent AS ContentOfAccountingRecord
	|FROM
	|	Accruals AS Accruals
	|WHERE
	|	Accruals.Ref.OperationType <> &AccrualsForLoans
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Accruals.LineNumber AS LineNumber,
	|	Accruals.Date AS Period,
	|	&Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	Accruals.CostAccount AS AccountDr,
	|	CASE
	|		WHEN Accruals.CostAccount.Currency
	|			THEN Accruals.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN Accruals.CostAccount.Currency
	|			THEN Accruals.AmountCur
	|		ELSE 0
	|	END AS AmountCurDr,
	|	Accruals.Correspondence AS AccountCr,
	|	CASE
	|		WHEN Accruals.Correspondence.Currency
	|			THEN Accruals.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	CASE
	|		WHEN Accruals.Correspondence.Currency
	|			THEN Accruals.AmountCur
	|		ELSE 0
	|	END AS AmountCurCr,
	|	Accruals.Amount AS Amount,
	|	&OtherIncomeAndExpensePostingContent AS Content,
	|	FALSE AS OfflineRecord
	|FROM
	|	Accruals AS Accruals
	|WHERE
	|	Accruals.Ref.OperationType = &AccrualsForLoans
	|
	|UNION ALL
	|
	|SELECT
	|	Accruals.LineNumber,
	|	Accruals.Date,
	|	&Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	Accruals.CostAccount,
	|	CASE
	|		WHEN Accruals.CostAccount.Currency
	|			THEN Accruals.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN Accruals.CostAccount.Currency
	|			THEN Accruals.AmountCur
	|		ELSE 0
	|	END,
	|	Accruals.Correspondence,
	|	CASE
	|		WHEN Accruals.Correspondence.Currency
	|			THEN Accruals.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN Accruals.Correspondence.Currency
	|			THEN Accruals.AmountCur
	|		ELSE 0
	|	END,
	|	Accruals.Amount,
	|	&OtherIncomeAndExpensePostingContent,
	|	FALSE
	|FROM
	|	Accruals AS Accruals
	|WHERE
	|	Accruals.Ref.OperationType <> &AccrualsForLoans
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
	|	AND OfflineRecords.OfflineRecord");
	
	Query.SetParameter("Ref",					DocumentRefAccrualsForLoans);
	Query.SetParameter("Company",				StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency",	Constants.PresentationCurrency.Get());
	Query.SetParameter("PointInTime",			New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("AccrualsForLoans",		Enums.LoanAccrualTypes.AccrualsForLoansBorrowed);
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();

	Query.SetParameter("OtherIncomeAndExpensePostingContent", NStr("en = 'Loans'", MainLanguageCode));
	
	ResultArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpenses", ResultArray[1].Unload());
	
	If StructureAdditionalProperties.TableForRegisterRecords.TableIncomeAndExpenses.Count() = 0 Then
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpenses", ResultArray[2].Unload());
	Else
		
		Selection = ResultArray[2].Select();
		While Selection.Next() Do
			
			NewRow = StructureAdditionalProperties.TableForRegisterRecords.TableIncomeAndExpenses.Add();
			FillPropertyValues(NewRow, Selection);
			
		EndDo;
		
	EndIf;
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountingJournalEntries", ResultArray[3].Unload());
	
	// LoanSettlements
	GenerateTableLoanSettlements(DocumentRefAccrualsForLoans, StructureAdditionalProperties);
	
EndProcedure

#Region PrintInterface

// Fills the list of printing commands.
// 
// Parameters:
//   PrintCommands - ValueTable - see field content in the PrintManagement.CreatePrintCommandCollection function.
//
Procedure AddPrintCommands(PrintCommands) Export
		
EndProcedure

#EndRegion

#EndIf
