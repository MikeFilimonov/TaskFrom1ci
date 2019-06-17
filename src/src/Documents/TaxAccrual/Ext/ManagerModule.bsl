#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefTaxAccrual, StructureAdditionalProperties) Export
	
	Query = New Query(
	"SELECT
	|	&Company AS Company,
	|	CASE
	|		WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesTaxAccrual.Accrual)
	|			THEN VALUE(AccumulationRecordType.Receipt)
	|		ELSE VALUE(AccumulationRecordType.Expense)
	|	END AS RecordType,
	|	DocumentTable.Ref.Date AS Period,
	|	DocumentTable.TaxKind AS TaxKind,
	|	DocumentTable.TaxKind.GLAccount AS GLAccount,
	|	DocumentTable.Amount AS Amount,
	|	CASE
	|		WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesTaxAccrual.Accrual)
	|			THEN &AddedTax
	|		ELSE &RecoveredTax
	|	END AS ContentOfAccountingRecord
	|FROM
	|	Document.TaxAccrual.Taxes AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	&Company AS Company,
	|	DocumentTable.Ref.Date AS Period,
	|	CASE
	|		WHEN DocumentTable.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherExpenses)
	|				OR DocumentTable.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherIncome)
	|			THEN VALUE(Catalog.LinesOfBusiness.Other)
	|		ELSE DocumentTable.BusinessLine
	|	END AS BusinessLine,
	|	CASE
	|		WHEN DocumentTable.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherExpenses)
	|				OR DocumentTable.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherIncome)
	|			THEN VALUE(Catalog.BusinessUnits.EmptyRef)
	|		ELSE DocumentTable.Department
	|	END AS StructuralUnit,
	|	DocumentTable.Correspondence AS GLAccount,
	|	CASE
	|		WHEN DocumentTable.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherExpenses)
	|				OR DocumentTable.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherIncome)
	|				OR DocumentTable.SalesOrder = VALUE(Document.SalesOrder.EmptyRef)
	|				OR DocumentTable.SalesOrder = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE DocumentTable.SalesOrder
	|	END AS SalesOrder,
	|	CASE
	|		WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesTaxAccrual.Accrual)
	|			THEN &Expenses
	|		ELSE &Incomings
	|	END AS ContentOfAccountingRecord,
	|	CASE
	|		WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesTaxAccrual.Accrual)
	|			THEN 0
	|		ELSE DocumentTable.Amount
	|	END AS AmountIncome,
	|	CASE
	|		WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesTaxAccrual.Accrual)
	|			THEN DocumentTable.Amount
	|		ELSE 0
	|	END AS AmountExpense,
	|	FALSE AS OfflineRecord
	|FROM
	|	Document.TaxAccrual.Taxes AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|	AND DocumentTable.Correspondence.TypeOfAccount IN (VALUE(Enum.GLAccountsTypes.Expenses), VALUE(Enum.GLAccountsTypes.OtherExpenses), VALUE(Enum.GLAccountsTypes.Revenue), VALUE(Enum.GLAccountsTypes.OtherIncome))
	|
	|UNION ALL
	|
	|SELECT
	|	OfflineRecords.Company,
	|	OfflineRecords.Period,
	|	OfflineRecords.BusinessLine,
	|	OfflineRecords.StructuralUnit,
	|	OfflineRecords.GLAccount,
	|	OfflineRecords.SalesOrder,
	|	OfflineRecords.ContentOfAccountingRecord,
	|	OfflineRecords.AmountIncome,
	|	OfflineRecords.AmountExpense,
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
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Ref.Date AS Period,
	|	&Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	CASE
	|		WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesTaxAccrual.Accrual)
	|			THEN DocumentTable.Correspondence
	|		ELSE DocumentTable.TaxKind.GLAccountForReimbursement
	|	END AS AccountDr,
	|	UNDEFINED AS CurrencyDr,
	|	0 AS AmountCurDr,
	|	CASE
	|		WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesTaxAccrual.Accrual)
	|			THEN DocumentTable.TaxKind.GLAccount
	|		ELSE DocumentTable.Correspondence
	|	END AS AccountCr,
	|	UNDEFINED AS CurrencyCr,
	|	0 AS AmountCurCr,
	|	DocumentTable.Amount AS Amount,
	|	CASE
	|		WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesTaxAccrual.Accrual)
	|			THEN &AddedTax
	|		ELSE &RecoveredTax
	|	END AS Content,
	|	FALSE AS OfflineRecord
	|FROM
	|	Document.TaxAccrual.Taxes AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
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
	|	DocumentTable.LineNumber AS LineNumber,
	|	CASE
	|		WHEN DocumentTable.Ref.OperationKind = VALUE(Enum.OperationTypesTaxAccrual.Accrual)
	|			THEN VALUE(AccumulationRecordType.Receipt)
	|		ELSE VALUE(AccumulationRecordType.Expense)
	|	END AS RecordType,
	|	DocumentTable.Ref.Date AS Period,
	|	&Company AS Company,
	|	DocumentTable.Department AS StructuralUnit,
	|	DocumentTable.Correspondence AS GLAccount,
	|	CASE
	|		WHEN DocumentTable.SalesOrder = VALUE(Document.SalesOrder.EmptyRef)
	|				OR DocumentTable.SalesOrder = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE DocumentTable.SalesOrder
	|	END AS SalesOrder,
	|	DocumentTable.Amount AS Amount,
	|	TRUE AS FixedCost,
	|	&AddedTax AS ContentOfAccountingRecord,
	|	FALSE AS OfflineRecord
	|FROM
	|	Document.TaxAccrual.Taxes AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|	AND (DocumentTable.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.WorkInProcess)
	|			OR DocumentTable.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.IndirectExpenses))
	|
	|UNION ALL
	|
	|SELECT
	|	OfflineRecords.LineNumber,
	|	OfflineRecords.RecordType,
	|	OfflineRecords.Period,
	|	OfflineRecords.Company,
	|	OfflineRecords.StructuralUnit,
	|	OfflineRecords.GLAccount,
	|	OfflineRecords.SalesOrder,
	|	OfflineRecords.Amount,
	|	OfflineRecords.FixedCost,
	|	OfflineRecords.ContentOfAccountingRecord,
	|	OfflineRecords.OfflineRecord
	|FROM
	|	AccumulationRegister.Inventory AS OfflineRecords
	|WHERE
	|	OfflineRecords.Recorder = &Ref
	|	AND OfflineRecords.OfflineRecord");
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();
	
	Query.SetParameter("Ref", DocumentRefTaxAccrual);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("AddedTax", NStr("en = 'Tax accrued'", MainLanguageCode));
	Query.SetParameter("RecoveredTax", NStr("en = 'Tax reimbursed'", MainLanguageCode));
	Query.SetParameter("Incomings", NStr("en = 'Income'", MainLanguageCode));
	Query.SetParameter("Expenses", NStr("en = 'Expenses'", MainLanguageCode));
	
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableTaxAccounting", ResultsArray[0].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpenses", ResultsArray[1].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountingJournalEntries", ResultsArray[2].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventory", ResultsArray[3].Unload());
	
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