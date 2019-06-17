#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefPayroll, StructureAdditionalProperties) Export
	
	Query = New Query(
	"SELECT
	|	&Company AS Company,
	|	PayrollEarningRetention.LineNumber AS LineNumber,
	|	PayrollEarningRetention.Ref.Date AS Period,
	|	PayrollEarningRetention.Ref.RegistrationPeriod AS RegistrationPeriod,
	|	PayrollEarningRetention.Ref.DocumentCurrency AS Currency,
	|	PayrollEarningRetention.Ref.StructuralUnit AS StructuralUnit,
	|	PayrollEarningRetention.Employee AS Employee,
	|	PayrollEarningRetention.GLExpenseAccount AS GLExpenseAccount,
	|	PayrollEarningRetention.SalesOrder AS SalesOrder,
	|	PayrollEarningRetention.BusinessLine AS BusinessLine,
	|	PayrollEarningRetention.StartDate AS StartDate,
	|	PayrollEarningRetention.EndDate AS EndDate,
	|	PayrollEarningRetention.DaysWorked AS DaysWorked,
	|	PayrollEarningRetention.HoursWorked AS HoursWorked,
	|	PayrollEarningRetention.Size AS Size,
	|	PayrollEarningRetention.EarningAndDeductionType AS EarningAndDeductionType,
	|	CAST(PayrollEarningRetention.Amount * SettlementsExchangeRates.ExchangeRate * AccountingExchangeRates.Multiplicity / (AccountingExchangeRates.ExchangeRate * SettlementsExchangeRates.Multiplicity) AS NUMBER(15, 2)) AS Amount,
	|	PayrollEarningRetention.Amount AS AmountCur
	|INTO TableEarning
	|FROM
	|	Document.Payroll.EarningsDeductions AS PayrollEarningRetention
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(
	|				&PointInTime,
	|				Currency IN
	|					(SELECT
	|						Constants.PresentationCurrency
	|					FROM
	|						Constants AS Constants)) AS AccountingExchangeRates
	|		ON (TRUE)
	|		LEFT JOIN Constants AS Constants
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&PointInTime, ) AS SettlementsExchangeRates
	|		ON PayrollEarningRetention.Ref.DocumentCurrency = SettlementsExchangeRates.Currency
	|WHERE
	|	PayrollEarningRetention.Ref = &Ref
	|
	|UNION ALL
	|
	|SELECT
	|	&Company,
	|	PayrollEarningRetention.LineNumber,
	|	PayrollEarningRetention.Ref.Date,
	|	PayrollEarningRetention.Ref.RegistrationPeriod,
	|	PayrollEarningRetention.Ref.DocumentCurrency,
	|	PayrollEarningRetention.Ref.StructuralUnit,
	|	PayrollEarningRetention.Employee,
	|	PayrollEarningRetention.EarningAndDeductionType.TaxKind.GLAccount,
	|	VALUE(Document.SalesOrder.EmptyRef),
	|	VALUE(Catalog.LinesOfBusiness.EmptyRef),
	|	PayrollEarningRetention.Ref.RegistrationPeriod,
	|	ENDOFPERIOD(PayrollEarningRetention.Ref.RegistrationPeriod, MONTH),
	|	0,
	|	0,
	|	0,
	|	PayrollEarningRetention.EarningAndDeductionType,
	|	CAST(PayrollEarningRetention.Amount * SettlementsExchangeRates.ExchangeRate * AccountingExchangeRates.Multiplicity / (AccountingExchangeRates.ExchangeRate * SettlementsExchangeRates.Multiplicity) AS NUMBER(15, 2)),
	|	PayrollEarningRetention.Amount
	|FROM
	|	Document.Payroll.IncomeTaxes AS PayrollEarningRetention
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(
	|				&PointInTime,
	|				Currency IN
	|					(SELECT
	|						Constants.PresentationCurrency
	|					FROM
	|						Constants AS Constants)) AS AccountingExchangeRates
	|		ON (TRUE)
	|		LEFT JOIN Constants AS Constants
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&PointInTime, ) AS SettlementsExchangeRates
	|		ON PayrollEarningRetention.Ref.DocumentCurrency = SettlementsExchangeRates.Currency
	|WHERE
	|	PayrollEarningRetention.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	&Company AS Company,
	|	PayrollEarningRetention.Period AS Period,
	|	PayrollEarningRetention.RegistrationPeriod AS RegistrationPeriod,
	|	PayrollEarningRetention.Currency AS Currency,
	|	PayrollEarningRetention.StructuralUnit AS StructuralUnit,
	|	PayrollEarningRetention.Employee AS Employee,
	|	PayrollEarningRetention.StartDate AS StartDate,
	|	PayrollEarningRetention.EndDate AS EndDate,
	|	PayrollEarningRetention.DaysWorked AS DaysWorked,
	|	PayrollEarningRetention.HoursWorked AS HoursWorked,
	|	PayrollEarningRetention.Size AS Size,
	|	PayrollEarningRetention.EarningAndDeductionType AS EarningAndDeductionType,
	|	PayrollEarningRetention.Amount AS Amount,
	|	PayrollEarningRetention.AmountCur AS AmountCur
	|FROM
	|	TableEarning AS PayrollEarningRetention
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	&Company AS Company,
	|	PayrollEarningRetention.Period AS Period,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	PayrollEarningRetention.RegistrationPeriod AS RegistrationPeriod,
	|	PayrollEarningRetention.Currency AS Currency,
	|	PayrollEarningRetention.StructuralUnit AS StructuralUnit,
	|	PayrollEarningRetention.Employee AS Employee,
	|	CASE
	|		WHEN PayrollEarningRetention.EarningAndDeductionType.Type = VALUE(Enum.EarningAndDeductionTypes.Earning)
	|			THEN PayrollEarningRetention.AmountCur
	|		ELSE -1 * PayrollEarningRetention.AmountCur
	|	END AS AmountCur,
	|	CASE
	|		WHEN PayrollEarningRetention.EarningAndDeductionType.Type = VALUE(Enum.EarningAndDeductionTypes.Earning)
	|			THEN PayrollEarningRetention.Amount
	|		ELSE -1 * PayrollEarningRetention.Amount
	|	END AS Amount,
	|	PayrollEarningRetention.Employee.SettlementsHumanResourcesGLAccount AS GLAccount,
	|	VALUE(AccountingRecordType.Credit) AS RecordKindAccountingJournalEntries,
	|	CASE
	|		WHEN PayrollEarningRetention.EarningAndDeductionType.Type = VALUE(Enum.EarningAndDeductionTypes.Tax)
	|			THEN CAST(&AddedTax AS STRING(100))
	|		ELSE CAST(&Payroll AS STRING(100))
	|	END AS ContentOfAccountingRecord
	|FROM
	|	TableEarning AS PayrollEarningRetention
	|WHERE
	|	PayrollEarningRetention.AmountCur <> 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	PayrollEarningRetention.LineNumber AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	PayrollEarningRetention.RegistrationPeriod AS Period,
	|	&Company AS Company,
	|	PayrollEarningRetention.StructuralUnit AS StructuralUnit,
	|	PayrollEarningRetention.GLExpenseAccount AS GLExpenseAccount,
	|	PayrollEarningRetention.GLExpenseAccount AS GLAccount,
	|	CASE
	|		WHEN PayrollEarningRetention.SalesOrder <> VALUE(Document.SalesOrder.EmptyRef)
	|				AND PayrollEarningRetention.SalesOrder <> VALUE(Document.WorkOrder.EmptyRef)
	|			THEN PayrollEarningRetention.SalesOrder
	|		ELSE UNDEFINED
	|	END AS SalesOrder,
	|	CASE
	|		WHEN PayrollEarningRetention.EarningAndDeductionType.Type = VALUE(Enum.EarningAndDeductionTypes.Deduction)
	|			THEN -1 * PayrollEarningRetention.Amount
	|		ELSE PayrollEarningRetention.Amount
	|	END AS Amount,
	|	VALUE(AccountingRecordType.Debit) AS RecordKindAccountingJournalEntries,
	|	TRUE AS FixedCost,
	|	CAST(&Payroll AS STRING(100)) AS ContentOfAccountingRecord
	|FROM
	|	TableEarning AS PayrollEarningRetention
	|WHERE
	|	PayrollEarningRetention.EarningAndDeductionType.Type <> VALUE(Enum.EarningAndDeductionTypes.Tax)
	|	AND (PayrollEarningRetention.GLExpenseAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.WorkInProcess)
	|			OR PayrollEarningRetention.GLExpenseAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.IndirectExpenses))
	|	AND PayrollEarningRetention.AmountCur <> 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	PayrollEarningRetention.LineNumber AS LineNumber,
	|	PayrollEarningRetention.RegistrationPeriod AS Period,
	|	&Company AS Company,
	|	CASE
	|		WHEN PayrollEarningRetention.GLExpenseAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.Expenses)
	|			THEN PayrollEarningRetention.BusinessLine
	|		ELSE VALUE(Catalog.LinesOfBusiness.Other)
	|	END AS BusinessLine,
	|	CASE
	|		WHEN PayrollEarningRetention.GLExpenseAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.Expenses)
	|			THEN PayrollEarningRetention.StructuralUnit
	|		ELSE UNDEFINED
	|	END AS StructuralUnit,
	|	PayrollEarningRetention.GLExpenseAccount AS GLAccount,
	|	CASE
	|		WHEN PayrollEarningRetention.EarningAndDeductionType.Type = VALUE(Enum.EarningAndDeductionTypes.Earning)
	|			THEN PayrollEarningRetention.Amount
	|		ELSE 0
	|	END AS AmountExpense,
	|	CASE
	|		WHEN PayrollEarningRetention.EarningAndDeductionType.Type = VALUE(Enum.EarningAndDeductionTypes.Deduction)
	|			THEN PayrollEarningRetention.Amount
	|		ELSE 0
	|	END AS AmountIncome,
	|	CASE
	|		WHEN PayrollEarningRetention.GLExpenseAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.Expenses)
	|				AND NOT PayrollEarningRetention.SalesOrder = VALUE(Document.SalesOrder.EmptyRef)
	|				AND NOT PayrollEarningRetention.SalesOrder = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN PayrollEarningRetention.SalesOrder
	|		ELSE UNDEFINED
	|	END AS SalesOrder,
	|	CAST(&Payroll AS STRING(100)) AS ContentOfAccountingRecord,
	|	FALSE AS OfflineRecord
	|FROM
	|	TableEarning AS PayrollEarningRetention
	|WHERE
	|	PayrollEarningRetention.EarningAndDeductionType.Type <> VALUE(Enum.EarningAndDeductionTypes.Tax)
	|	AND PayrollEarningRetention.GLExpenseAccount.TypeOfAccount IN (VALUE(Enum.GLAccountsTypes.Expenses), VALUE(Enum.GLAccountsTypes.OtherExpenses), VALUE(Enum.GLAccountsTypes.Revenue), VALUE(Enum.GLAccountsTypes.OtherIncome))
	|	AND PayrollEarningRetention.AmountCur <> 0
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
	|	OfflineRecords.AmountExpense,
	|	OfflineRecords.AmountIncome,
	|	OfflineRecords.SalesOrder,
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
	|	&Company AS Company,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	PayrollEarningRetention.RegistrationPeriod AS Period,
	|	PayrollEarningRetention.EarningAndDeductionType.TaxKind AS TaxKind,
	|	PayrollEarningRetention.EarningAndDeductionType.TaxKind.GLAccount AS GLAccount,
	|	PayrollEarningRetention.Amount AS Amount,
	|	CAST(&AddedTax AS STRING(100)) AS ContentOfAccountingRecord
	|FROM
	|	TableEarning AS PayrollEarningRetention
	|WHERE
	|	PayrollEarningRetention.EarningAndDeductionType.Type = VALUE(Enum.EarningAndDeductionTypes.Tax)
	|	AND PayrollEarningRetention.AmountCur <> 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	PayrollEarningRetention.LineNumber AS LineNumber,
	|	PayrollEarningRetention.RegistrationPeriod AS Period,
	|	&Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	CASE
	|		WHEN PayrollEarningRetention.EarningAndDeductionType.Type = VALUE(Enum.EarningAndDeductionTypes.Earning)
	|			THEN PayrollEarningRetention.GLExpenseAccount
	|		ELSE PayrollEarningRetention.Employee.SettlementsHumanResourcesGLAccount
	|	END AS AccountDr,
	|	CASE
	|		WHEN (PayrollEarningRetention.EarningAndDeductionType.Type = VALUE(Enum.EarningAndDeductionTypes.Deduction)
	|					OR PayrollEarningRetention.EarningAndDeductionType.Type = VALUE(Enum.EarningAndDeductionTypes.Tax))
	|					AND PayrollEarningRetention.Employee.SettlementsHumanResourcesGLAccount.Currency
	|				OR PayrollEarningRetention.EarningAndDeductionType.Type = VALUE(Enum.EarningAndDeductionTypes.Earning)
	|					AND PayrollEarningRetention.GLExpenseAccount.Currency
	|			THEN PayrollEarningRetention.Currency
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN (PayrollEarningRetention.EarningAndDeductionType.Type = VALUE(Enum.EarningAndDeductionTypes.Deduction)
	|					OR PayrollEarningRetention.EarningAndDeductionType.Type = VALUE(Enum.EarningAndDeductionTypes.Tax))
	|					AND PayrollEarningRetention.Employee.SettlementsHumanResourcesGLAccount.Currency
	|				OR PayrollEarningRetention.EarningAndDeductionType.Type = VALUE(Enum.EarningAndDeductionTypes.Earning)
	|					AND PayrollEarningRetention.GLExpenseAccount.Currency
	|			THEN PayrollEarningRetention.AmountCur
	|		ELSE 0
	|	END AS AmountCurDr,
	|	CASE
	|		WHEN PayrollEarningRetention.EarningAndDeductionType.Type = VALUE(Enum.EarningAndDeductionTypes.Earning)
	|			THEN PayrollEarningRetention.Employee.SettlementsHumanResourcesGLAccount
	|		ELSE PayrollEarningRetention.GLExpenseAccount
	|	END AS AccountCr,
	|	CASE
	|		WHEN (PayrollEarningRetention.EarningAndDeductionType.Type = VALUE(Enum.EarningAndDeductionTypes.Deduction)
	|					OR PayrollEarningRetention.EarningAndDeductionType.Type = VALUE(Enum.EarningAndDeductionTypes.Tax))
	|					AND PayrollEarningRetention.GLExpenseAccount.Currency
	|				OR PayrollEarningRetention.EarningAndDeductionType.Type = VALUE(Enum.EarningAndDeductionTypes.Earning)
	|					AND PayrollEarningRetention.Employee.SettlementsHumanResourcesGLAccount.Currency
	|			THEN PayrollEarningRetention.Currency
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	CASE
	|		WHEN (PayrollEarningRetention.EarningAndDeductionType.Type = VALUE(Enum.EarningAndDeductionTypes.Deduction)
	|					OR PayrollEarningRetention.EarningAndDeductionType.Type = VALUE(Enum.EarningAndDeductionTypes.Tax))
	|					AND PayrollEarningRetention.GLExpenseAccount.Currency
	|				OR PayrollEarningRetention.EarningAndDeductionType.Type = VALUE(Enum.EarningAndDeductionTypes.Earning)
	|					AND PayrollEarningRetention.Employee.SettlementsHumanResourcesGLAccount.Currency
	|			THEN PayrollEarningRetention.AmountCur
	|		ELSE 0
	|	END AS AmountCurCr,
	|	PayrollEarningRetention.Amount AS Amount,
	|	CAST(CASE
	|			WHEN PayrollEarningRetention.EarningAndDeductionType.Type = VALUE(Enum.EarningAndDeductionTypes.Tax)
	|				THEN &AddedTax
	|			ELSE &Payroll
	|		END AS STRING(100)) AS Content
	|FROM
	|	TableEarning AS PayrollEarningRetention
	|WHERE
	|	PayrollEarningRetention.AmountCur <> 0");
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();
	
	Query.SetParameter("Ref", DocumentRefPayroll);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("Payroll", NStr("en = 'Payroll'", MainLanguageCode));
	Query.SetParameter("AddedTax", NStr("en = 'Tax accrued'", MainLanguageCode));

	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableEarningsAndDeductions", ResultsArray[1].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TablePayroll", ResultsArray[2].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventory", ResultsArray[3].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpenses", ResultsArray[4].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableTaxAccounting", ResultsArray[5].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountingJournalEntries", ResultsArray[6].Unload());
	
	GenerateTableLoanSettlements(DocumentRefPayroll, StructureAdditionalProperties);
	GenerateTableAccountOfLoans(DocumentRefPayroll, StructureAdditionalProperties);
	
EndProcedure

// Controls the occurrence of negative balances.
//
Procedure RunControl(DocumentRefPayroll, AdditionalProperties, Cancel, PostingDelete = False) Export
	
	If Not DriveServer.RunBalanceControl() Then
		Return;
	EndIf;

	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
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

#Region LoanSettlements

Procedure GenerateTableLoanSettlements(DocumentRefPayroll, StructureAdditionalProperties)

	If DocumentRefPayroll.LoanRepayment.Count() = 0 Then
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableLoanSettlements", New ValueTable);
		Return;
	EndIf;
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();
	
	Query.SetParameter("Company",					StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("InterestOfEarningOnLoan",	NStr("en = 'Interest of Earning on loan'", MainLanguageCode));
	Query.SetParameter("InterestOfChargeOnLoan",	NStr("en = 'Interest of charge on loan'", MainLanguageCode));
	Query.SetParameter("PrincipalOfChargeOnLoan",	NStr("en = 'Principal of charge on loan'", MainLanguageCode));
	Query.SetParameter("Ref",						DocumentRefPayroll);
	Query.SetParameter("PointInTime",				New Boundary(StructureAdditionalProperties.ForPosting.PointInTime,BoundaryType.Including));
	Query.SetParameter("ControlPeriod",				StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("ExchangeRateDifference",	NStr("en = 'Exchange difference'", MainLanguageCode));
	Query.SetParameter("PresentationCurrency", 		Constants.FunctionalCurrency.Get());
	Query.SetParameter("CurrencyDR",				DocumentRefPayroll.DocumentCurrency);
	
	Query.Text = 
	"SELECT
	|	&Company,
	|	PayrollLoanRepayment.LineNumber,
	|	PayrollLoanRepayment.Ref,
	|	PayrollLoanRepayment.Ref.Date AS Period,
	|	PayrollLoanRepayment.Ref.StructuralUnit,
	|	PayrollLoanRepayment.Ref.RegistrationPeriod,
	|	PayrollLoanRepayment.Ref.DocumentCurrency AS Currency,
	|	PayrollLoanRepayment.Employee,
	|	PayrollLoanRepayment.Employee.SettlementsHumanResourcesGLAccount AS SettlementsHumanResourcesGLAccount,
	|	PayrollLoanRepayment.LoanContract,
	|	PayrollLoanRepayment.LoanContract.GLAccount AS GLAccountLoanContract,
	|	PayrollLoanRepayment.LoanContract.SettlementsCurrency AS CurrencyLoanContract,
	|	PayrollLoanRepayment.LoanContract.InterestGLAccount AS InterestGLAccount,
	|	PayrollLoanRepayment.LoanContract.CostAccount AS CostAccount,
	|	PayrollLoanRepayment.LoanContract.BusinessArea AS BusinessArea,
	|	PayrollLoanRepayment.PrincipalCharged + PayrollLoanRepayment.InterestCharged AS AmountCur,
	|	CAST((PayrollLoanRepayment.PrincipalCharged + PayrollLoanRepayment.InterestCharged) * SettlementsExchangeRates.ExchangeRate * AcoountExchangeRates.Multiplicity / (AcoountExchangeRates.ExchangeRate * SettlementsExchangeRates.Multiplicity) AS NUMBER(15, 2)) AS Amount,
	|	CAST((PayrollLoanRepayment.PrincipalCharged + PayrollLoanRepayment.InterestCharged) * SettlementsExchangeRates.ExchangeRate * LoanContractExchangeRates.Multiplicity / (LoanContractExchangeRates.ExchangeRate * SettlementsExchangeRates.Multiplicity) AS NUMBER(15, 2)) AS ContractAmountCur,
	|	PayrollLoanRepayment.PrincipalCharged AS PrincipalChargedCur,
	|	CAST(PayrollLoanRepayment.PrincipalCharged * SettlementsExchangeRates.ExchangeRate * AcoountExchangeRates.Multiplicity / (AcoountExchangeRates.ExchangeRate * SettlementsExchangeRates.Multiplicity) AS NUMBER(15, 2)) AS PrincipalCharged,
	|	CAST(PayrollLoanRepayment.PrincipalCharged * LoanContractExchangeRates.ExchangeRate * AcoountExchangeRates.Multiplicity / (AcoountExchangeRates.ExchangeRate * LoanContractExchangeRates.Multiplicity) AS NUMBER(15, 2)) AS ContractPrincipalChargedCur,
	|	PayrollLoanRepayment.InterestCharged AS InterestChargedCur,
	|	CAST(PayrollLoanRepayment.InterestCharged * SettlementsExchangeRates.ExchangeRate * AcoountExchangeRates.Multiplicity / (AcoountExchangeRates.ExchangeRate * SettlementsExchangeRates.Multiplicity) AS NUMBER(15, 2)) AS InterestCharged,
	|	CAST(PayrollLoanRepayment.InterestCharged * LoanContractExchangeRates.ExchangeRate * AcoountExchangeRates.Multiplicity / (AcoountExchangeRates.ExchangeRate * LoanContractExchangeRates.Multiplicity) AS NUMBER(15, 2)) AS ContractInterestChargedCur,
	|	PayrollLoanRepayment.InterestAccrued AS InterestAccruedCur,
	|	CAST(PayrollLoanRepayment.InterestAccrued * SettlementsExchangeRates.ExchangeRate * AcoountExchangeRates.Multiplicity / (AcoountExchangeRates.ExchangeRate * SettlementsExchangeRates.Multiplicity) AS NUMBER(15, 2)) AS InterestAccrued,
	|	CAST(PayrollLoanRepayment.InterestAccrued * LoanContractExchangeRates.ExchangeRate * AcoountExchangeRates.Multiplicity / (AcoountExchangeRates.ExchangeRate * LoanContractExchangeRates.Multiplicity) AS NUMBER(15, 2)) AS ContractInterestAccruedCur
	|INTO TableLoans
	|FROM
	|	Document.Payroll.LoanRepayment AS PayrollLoanRepayment
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(
	|				&PointInTime,
	|				Currency IN
	|					(SELECT
	|						Constants.FunctionalCurrency
	|					FROM
	|						Constants AS Constants)) AS AcoountExchangeRates
	|		ON (TRUE)
	|		LEFT JOIN Constants AS Constants
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&PointInTime, ) AS SettlementsExchangeRates
	|		ON PayrollLoanRepayment.Ref.DocumentCurrency = SettlementsExchangeRates.Currency
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&PointInTime, ) AS LoanContractExchangeRates
	|		ON PayrollLoanRepayment.LoanContract.SettlementsCurrency = LoanContractExchangeRates.Currency
	|WHERE
	|	PayrollLoanRepayment.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	&Company,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableLoans.Period AS Date,
	|	TableLoans.Period AS Period,
	|	&PrincipalOfChargeOnLoan AS PostingContent,
	|	TableLoans.Employee AS Counterparty,
	|	TableLoans.ContractPrincipalChargedCur AS PrincipalDebtCur,
	|	TableLoans.PrincipalCharged AS PrincipalDebt,
	|	TableLoans.ContractPrincipalChargedCur AS PrincipalChargedCurForBalance,
	|	TableLoans.PrincipalCharged AS PrincipalChargedForBalance,
	|	0 AS InterestCur,
	|	0 AS Interest,
	|	0 AS InterestCurForBalance,
	|	0 AS InterestForBalance,
	|	0 AS CommissionCur,
	|	0 AS Commission,
	|	0 AS CommissionCurForBalance,
	|	0 AS CommissionForBalance,
	|	TableLoans.LoanContract AS LoanContract,
	|	TableLoans.Currency,
	|	TableLoans.GLAccountLoanContract AS GLAccount,
	|	TRUE AS DeductedFromSalary,
	|	TableLoans.LoanContract.LoanKind AS LoanKind,
	|	TableLoans.StructuralUnit,
	|	TableLoans.ContractPrincipalChargedCur AS AmountCur,
	|	TableLoans.PrincipalCharged AS Amount
	|INTO TemporaryTableLoanSettlements
	|FROM
	|	TableLoans AS TableLoans
	|WHERE
	|	TableLoans.PrincipalChargedCur <> 0
	|
	|UNION ALL
	|
	|SELECT
	|	&Company,
	|	VALUE(AccumulationRecordType.Expense),
	|	TableLoans.Period,
	|	TableLoans.Period,
	|	&InterestOfChargeOnLoan,
	|	TableLoans.Employee,
	|	0,
	|	0,
	|	0,
	|	0,
	|	TableLoans.ContractInterestChargedCur,
	|	TableLoans.InterestCharged,
	|	TableLoans.ContractInterestChargedCur,
	|	TableLoans.InterestCharged,
	|	0,
	|	0,
	|	0,
	|	0,
	|	TableLoans.LoanContract,
	|	TableLoans.Currency,
	|	TableLoans.InterestGLAccount,
	|	TRUE,
	|	TableLoans.LoanContract.LoanKind,
	|	TableLoans.StructuralUnit,
	|	TableLoans.ContractInterestChargedCur,
	|	TableLoans.InterestCharged
	|FROM
	|	TableLoans AS TableLoans
	|WHERE
	|	TableLoans.PrincipalChargedCur <> 0
	|
	|UNION ALL
	|
	|SELECT
	|	&Company,
	|	VALUE(AccumulationRecordType.Receipt),
	|	TableLoans.Period,
	|	TableLoans.Period,
	|	&InterestOfEarningOnLoan,
	|	TableLoans.Employee,
	|	0,
	|	0,
	|	0,
	|	0,
	|	TableLoans.ContractInterestAccruedCur,
	|	TableLoans.InterestAccrued,
	|	-TableLoans.ContractInterestAccruedCur,
	|	-TableLoans.InterestAccrued,
	|	0,
	|	0,
	|	0,
	|	0,
	|	TableLoans.LoanContract,
	|	TableLoans.Currency,
	|	TableLoans.InterestGLAccount,
	|	FALSE,
	|	TableLoans.LoanContract.LoanKind,
	|	TableLoans.StructuralUnit,
	|	TableLoans.ContractInterestAccruedCur,
	|	TableLoans.InterestAccrued
	|FROM
	|	TableLoans AS TableLoans
	|WHERE
	|	TableLoans.PrincipalChargedCur <> 0";
	
	QueryResult = Query.Execute();
	
	Query.Text = 
	"SELECT
	|	TemporaryTableLoanSettlements.Company,
	|	TemporaryTableLoanSettlements.Counterparty,
	|	TemporaryTableLoanSettlements.LoanContract
	|FROM
	|	TemporaryTableLoanSettlements AS TemporaryTableLoanSettlements";
	
	QueryResult = Query.Execute();
	
	Blocking = New DataLock;
	LockItem = Blocking.Add("AccumulationRegister.LoanSettlements");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;
	
	For Each QueryResultColumn In QueryResult.Columns Do
		LockItem.UseFromDataSource(QueryResultColumn.Name, QueryResultColumn.Name);
	EndDo;
	Blocking.Lock();
	
	QueryNumber = 0;
	
	IsBusinessUnit = True;
	Query.Text = DriveServer.GetQueryTextExchangeRateDifferencesLoanSettlements(Query.TempTablesManager, QueryNumber, IsBusinessUnit);
	ResultsArray = Query.ExecuteBatch();
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableLoanSettlements", ResultsArray[QueryNumber].Unload());
	
EndProcedure

Procedure GenerateTableAccountOfLoans(DocumentRefPayroll, StructureAdditionalProperties)

	If DocumentRefPayroll.LoanRepayment.Count() = 0 Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();
	
	Query.SetParameter("Ref",										DocumentRefPayroll);
	Query.SetParameter("PointInTime",								New Boundary(StructureAdditionalProperties.ForPosting.PointInTime,BoundaryType.Including));
	Query.SetParameter("Company",									StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("ExchangeRateDifference",					NStr("en = 'Exchange difference'", MainLanguageCode));
	Query.SetParameter("Payroll",									NStr("en = 'Payroll'", MainLanguageCode));
	Query.SetParameter("TaxAccrued",								NStr("en = 'Tax accrued'", MainLanguageCode));
	Query.SetParameter("ChargeForRepaymentPrincipalAndInterest",	NStr("en = 'Charge for repayment principal and interest'", MainLanguageCode));
	Query.SetParameter("InterestOfChargeOnLoan",					NStr("en = 'Interest of charge on loan'", MainLanguageCode));
	Query.Text = 
	"SELECT
	|	&Company,
	|	TableLoans.Period,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TableLoans.RegistrationPeriod,
	|	TableLoans.Currency,
	|	TableLoans.StructuralUnit,
	|	TableLoans.Employee,
	|	-TableLoans.AmountCur AS AmountCur,
	|	-TableLoans.Amount AS Amount,
	|	TableLoans.GLAccountLoanContract,
	|	VALUE(AccountingRecordType.Credit) AS AccountingJournalEntriesRecordType,
	|	CAST(&ChargeForRepaymentPrincipalAndInterest AS STRING(100)) AS ContentOfAccountingRecord
	|FROM
	|	TableLoans AS TableLoans
	|WHERE
	|	TableLoans.Amount <> 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableLoans.LineNumber,
	|	TableLoans.RegistrationPeriod AS Period,
	|	TableLoans.Company,
	|	CASE
	|		WHEN TableLoans.InterestGLAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.Expenses)
	|			THEN TableLoans.BusinessArea
	|		ELSE VALUE(Catalog.LinesOfBusiness.Other)
	|	END AS BusinessLine,
	|	CASE
	|		WHEN TableLoans.InterestGLAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.Expenses)
	|			THEN TableLoans.StructuralUnit
	|		ELSE UNDEFINED
	|	END AS StructuralUnit,
	|	TableLoans.CostAccount AS GLAccount,
	|	TableLoans.Employee AS Analytics,
	|	0 AS AmountExpense,
	|	TableLoans.InterestAccrued AS AmountIncome,
	|	CAST(&InterestOfChargeOnLoan AS STRING(100)) AS ContentOfAccountingRecord
	|FROM
	|	TableLoans AS TableLoans
	|WHERE
	|	TableLoans.InterestAccrued <> 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	CAST(CASE
	|			WHEN DocumentTable.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN DocumentTable.Counterparty.SettlementsHumanResourcesGLAccount
	|			ELSE DocumentTable.LoanContract.GLAccount
	|		END AS ChartOfAccounts.PrimaryChartOfAccounts) AS AccountDr,
	|	CAST(CASE
	|			WHEN DocumentTable.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN DocumentTable.GLAccount
	|			ELSE DocumentTable.LoanContract.CostAccount
	|		END AS ChartOfAccounts.PrimaryChartOfAccounts) AS AccountCr,
	|	DocumentTable.Currency,
	|	DocumentTable.AmountCur,
	|	DocumentTable.Amount,
	|	CAST(DocumentTable.PostingContent AS STRING(100)) AS PostingContent
	|INTO TemporaryTableLoanSettlementsForRegisterRecord
	|FROM
	|	TemporaryTableLoanSettlements AS DocumentTable
	|WHERE
	|	DocumentTable.Amount <> 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	1 AS LineNumber,
	|	DocumentTable.Date AS Period,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	DocumentTable.AccountDr,
	|	DocumentTable.AccountCr,
	|	CASE
	|		WHEN DocumentTable.AccountDr.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN DocumentTable.AccountCr.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	CASE
	|		WHEN DocumentTable.AccountDr.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END AS AmountCurDr,
	|	CASE
	|		WHEN DocumentTable.AccountCr.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END AS AmountCurСr,
	|	DocumentTable.Amount,
	|	CAST(DocumentTable.PostingContent AS STRING(100)) AS Content
	|FROM
	|	TemporaryTableLoanSettlementsForRegisterRecord AS DocumentTable
	|WHERE
	|	DocumentTable.Amount <> 0
	|
	|UNION ALL
	|
	|SELECT
	|	1,
	|	TemporaryTableExchangeRateDifferencesLoanSettlements.Date,
	|	TemporaryTableExchangeRateDifferencesLoanSettlements.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	CASE
	|		WHEN TemporaryTableExchangeRateDifferencesLoanSettlements.ExchangeRateDifferenceAmount > 0
	|			THEN TemporaryTableExchangeRateDifferencesLoanSettlements.GLAccount
	|		ELSE &ForeignCurrencyExchangeLoss
	|	END,
	|	CASE
	|		WHEN TemporaryTableExchangeRateDifferencesLoanSettlements.ExchangeRateDifferenceAmount > 0
	|			THEN &ForeignCurrencyExchangeLoss
	|		ELSE TemporaryTableExchangeRateDifferencesLoanSettlements.GLAccount
	|	END,
	|	CASE
	|		WHEN TemporaryTableExchangeRateDifferencesLoanSettlements.ExchangeRateDifferenceAmount > 0
	|				AND TemporaryTableExchangeRateDifferencesLoanSettlements.GLAccount.Currency
	|			THEN TemporaryTableExchangeRateDifferencesLoanSettlements.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN TemporaryTableExchangeRateDifferencesLoanSettlements.ExchangeRateDifferenceAmount < 0
	|				AND TemporaryTableExchangeRateDifferencesLoanSettlements.GLAccount.Currency
	|			THEN TemporaryTableExchangeRateDifferencesLoanSettlements.Currency
	|		ELSE UNDEFINED
	|	END,
	|	0,
	|	0,
	|	CASE
	|		WHEN TemporaryTableExchangeRateDifferencesLoanSettlements.ExchangeRateDifferenceAmount > 0
	|			THEN TemporaryTableExchangeRateDifferencesLoanSettlements.ExchangeRateDifferenceAmount
	|		ELSE -TemporaryTableExchangeRateDifferencesLoanSettlements.ExchangeRateDifferenceAmount
	|	END,
	|	CAST(&ExchangeRateDifference AS STRING(100))
	|FROM
	|	TemporaryTableExchangeRateDifferencesLoanSettlements AS TemporaryTableExchangeRateDifferencesLoanSettlements
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	&Company,
	|	PayrollLoanRepayment.LineNumber,
	|	PayrollLoanRepayment.Ref.Date AS Period,
	|	PayrollLoanRepayment.Ref.RegistrationPeriod,
	|	PayrollLoanRepayment.Ref.DocumentCurrency AS Currency,
	|	PayrollLoanRepayment.Ref.StructuralUnit,
	|	PayrollLoanRepayment.Employee,
	|	PayrollLoanRepayment.LoanContract.GLAccount AS CostAccount,
	|	VALUE(Document.SalesOrder.EmptyRef) AS SalesOrder,
	|	VALUE(Catalog.LinesOfBusiness.EmptyRef) AS BusinessArea,
	|	PayrollLoanRepayment.Ref.RegistrationPeriod AS StartDate,
	|	ENDOFPERIOD(PayrollLoanRepayment.Ref.RegistrationPeriod, MONTH) AS EndDate,
	|	0 AS DaysWorked,
	|	0 AS HoursWorked,
	|	0 AS Size,
	|	CASE
	|		WHEN PayrollLoanRepayment.LoanContract.DeductionPrincipalDebt = UNDEFINED
	|				OR PayrollLoanRepayment.LoanContract.DeductionPrincipalDebt = VALUE(Catalog.EarningAndDeductionTypes.EmptyRef)
	|			THEN VALUE(Catalog.EarningAndDeductionTypes.RepaymentOfLoanFromSalary)
	|		ELSE PayrollLoanRepayment.LoanContract.DeductionPrincipalDebt
	|	END AS EarningAndDeductionType,
	|	CAST(PayrollLoanRepayment.PrincipalCharged * SettlementsExchangeRates.ExchangeRate * AccountingExchangeRates.Multiplicity / (AccountingExchangeRates.ExchangeRate * SettlementsExchangeRates.Multiplicity) AS NUMBER(15, 2)) AS Amount,
	|	PayrollLoanRepayment.PrincipalCharged AS AmountCur
	|FROM
	|	Document.Payroll.LoanRepayment AS PayrollLoanRepayment
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(
	|				&PointInTime,
	|				Currency IN
	|					(SELECT
	|						Constants.FunctionalCurrency
	|					FROM
	|						Constants AS Constants)) AS AccountingExchangeRates
	|		ON (TRUE)
	|		LEFT JOIN Constants AS Constants
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast AS SettlementsExchangeRates
	|		ON PayrollLoanRepayment.Ref.DocumentCurrency = SettlementsExchangeRates.Currency
	|WHERE
	|	PayrollLoanRepayment.Ref = &Ref
	|	AND PayrollLoanRepayment.PrincipalCharged > 0
	|
	|UNION ALL
	|
	|SELECT
	|	&Company,
	|	PayrollLoanRepayment.LineNumber,
	|	PayrollLoanRepayment.Ref.Date,
	|	PayrollLoanRepayment.Ref.RegistrationPeriod,
	|	PayrollLoanRepayment.Ref.DocumentCurrency,
	|	PayrollLoanRepayment.Ref.StructuralUnit,
	|	PayrollLoanRepayment.Employee,
	|	PayrollLoanRepayment.LoanContract.GLAccount,
	|	VALUE(Document.SalesOrder.EmptyRef),
	|	VALUE(Catalog.LinesOfBusiness.EmptyRef),
	|	PayrollLoanRepayment.Ref.RegistrationPeriod,
	|	ENDOFPERIOD(PayrollLoanRepayment.Ref.RegistrationPeriod, MONTH),
	|	0,
	|	0,
	|	0,
	|	CASE
	|		WHEN PayrollLoanRepayment.LoanContract.DeductionInterest = UNDEFINED
	|				OR PayrollLoanRepayment.LoanContract.DeductionInterest = VALUE(Catalog.EarningAndDeductionTypes.EmptyRef)
	|			THEN VALUE(Catalog.EarningAndDeductionTypes.InterestOnLoan)
	|		ELSE PayrollLoanRepayment.LoanContract.DeductionInterest
	|	END,
	|	CAST(PayrollLoanRepayment.InterestCharged * SettlementsExchangeRates.ExchangeRate * AccountingExchangeRates.Multiplicity / (AccountingExchangeRates.ExchangeRate * SettlementsExchangeRates.Multiplicity) AS NUMBER(15, 2)),
	|	PayrollLoanRepayment.InterestCharged
	|FROM
	|	Document.Payroll.LoanRepayment AS PayrollLoanRepayment
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(
	|				&PointInTime,
	|				Currency IN
	|					(SELECT
	|						Constants.FunctionalCurrency
	|					FROM
	|						Constants AS Constants)) AS AccountingExchangeRates
	|		ON (TRUE)
	|		LEFT JOIN Constants AS Constants
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast AS SettlementsExchangeRates
	|		ON PayrollLoanRepayment.Ref.DocumentCurrency = SettlementsExchangeRates.Currency
	|WHERE
	|	PayrollLoanRepayment.Ref = &Ref
	|	AND PayrollLoanRepayment.InterestCharged > 0";
	
	Query.SetParameter("ForeignCurrencyExchangeLoss", Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeLoss"));
	
	ResultsArray = Query.ExecuteBatch();
	
	CurrentTable = ResultsArray[0].Unload();
	If ValueIsFilled(StructureAdditionalProperties.TableForRegisterRecords.TablePayroll) Then
		For Each CurrentRow In CurrentTable Do
			NewRow = StructureAdditionalProperties.TableForRegisterRecords.TablePayroll.Add();
			FillPropertyValues(NewRow, CurrentRow);
		EndDo;
	Else
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TablePayroll", CurrentTable);
	EndIf;
	
	CurrentTable = ResultsArray[1].Unload();
	If ValueIsFilled(StructureAdditionalProperties.TableForRegisterRecords.TableIncomeAndExpenses) Then
		For Each CurrentRow In CurrentTable Do
			NewRow = StructureAdditionalProperties.TableForRegisterRecords.TableIncomeAndExpenses.Add();
			FillPropertyValues(NewRow, CurrentRow);
		EndDo;
	Else
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpenses", CurrentTable);
	EndIf;
	
	CurrentTable = ResultsArray[3].Unload();
	If ValueIsFilled(StructureAdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries) Then
		For Each CurrentRow In CurrentTable Do
			NewRow = StructureAdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries.Add();
			FillPropertyValues(NewRow, CurrentRow);
		EndDo;
	Else
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountingJournalEntries", CurrentTable);
	EndIf;
	
	CurrentTable = ResultsArray[4].Unload();
	If ValueIsFilled(StructureAdditionalProperties.TableForRegisterRecords.TableEarningsAndDeductions) Then
		For Each CurrentRow In CurrentTable Do
			NewRow = StructureAdditionalProperties.TableForRegisterRecords.TableEarningsAndDeductions.Add();
			FillPropertyValues(NewRow, CurrentRow);
		EndDo;
	Else
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableEarningsAndDeductions", CurrentTable);
	EndIf;

EndProcedure

#EndRegion

#EndIf