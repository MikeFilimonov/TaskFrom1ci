#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableFixedAssets(DocumentRefFixedAssetDepreciationChanges, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();

	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("FixedAssetAcceptanceForAccounting", NStr("en = 'Change parameters'", MainLanguageCode));
	
	Query.Text =
	"SELECT
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Period AS Period,
	|	CASE
	|		WHEN DocumentTable.CostForDepreciationCalculation - DocumentTable.CostForDepreciationCalculationBeforeChanging > 0
	|			THEN VALUE(AccumulationRecordType.Receipt)
	|		ELSE VALUE(AccumulationRecordType.Expense)
	|	END AS RecordType,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.FixedAsset AS FixedAsset,
	|	CASE
	|		WHEN DocumentTable.CostForDepreciationCalculation - DocumentTable.CostForDepreciationCalculationBeforeChanging > 0
	|			THEN DocumentTable.CostForDepreciationCalculation - DocumentTable.CostForDepreciationCalculationBeforeChanging
	|		ELSE DocumentTable.CostForDepreciationCalculationBeforeChanging - DocumentTable.CostForDepreciationCalculation
	|	END AS Cost,
	|	0 AS Depreciation,
	|	&FixedAssetAcceptanceForAccounting AS ContentOfAccountingRecord
	|FROM
	|	TemporaryTableFixedAssetDepreciationChanges AS DocumentTable
	|WHERE
	|	DocumentTable.CostForDepreciationCalculationBeforeChanging <> 0
	|
	|ORDER BY
	|	LineNumber";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableFixedAssets", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableIncomeAndExpenses(DocumentRefFixedAssetDepreciationChanges, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();

	Query.SetParameter("IncomeReflection", NStr("en = 'Income'", MainLanguageCode));
	Query.SetParameter("CostsReflection", NStr("en = 'Expenses incurred'", MainLanguageCode));
	
	Query.Text =
	"SELECT
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Period AS Period,
	|	DocumentTable.Company AS Company,
	|	UNDEFINED AS StructuralUnit,
	|	UNDEFINED AS SalesOrder,
	|	VALUE(Catalog.LinesOfBusiness.Other) AS BusinessLine,
	|	DocumentTable.RevaluationAccount AS GLAccount,
	|	CASE
	|		WHEN DocumentTable.CostForDepreciationCalculation - DocumentTable.CostForDepreciationCalculationBeforeChanging > 0
	|			THEN &IncomeReflection
	|		ELSE &CostsReflection
	|	END AS ContentOfAccountingRecord,
	|	CASE
	|		WHEN DocumentTable.CostForDepreciationCalculation - DocumentTable.CostForDepreciationCalculationBeforeChanging > 0
	|			THEN DocumentTable.CostForDepreciationCalculation - DocumentTable.CostForDepreciationCalculationBeforeChanging
	|		ELSE 0
	|	END AS AmountIncome,
	|	CASE
	|		WHEN DocumentTable.CostForDepreciationCalculation - DocumentTable.CostForDepreciationCalculationBeforeChanging > 0
	|			THEN 0
	|		ELSE DocumentTable.CostForDepreciationCalculationBeforeChanging - DocumentTable.CostForDepreciationCalculation
	|	END AS AmountExpense,
	|	FALSE AS OfflineRecord
	|FROM
	|	TemporaryTableFixedAssetDepreciationChanges AS DocumentTable
	|WHERE
	|	DocumentTable.CostForDepreciationCalculationBeforeChanging <> 0
	|
	|ORDER BY
	|	LineNumber";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpenses", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableAccountingJournalEntries(DocumentRefFixedAssetDepreciationChanges, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();

	Query.SetParameter("IncomeReflection", NStr("en = 'Income'", MainLanguageCode));
	Query.SetParameter("CostsReflection", NStr("en = 'Expenses incurred'", MainLanguageCode));
	Query.SetParameter("Ref", DocumentRefFixedAssetDepreciationChanges);
	
	Query.Text =
	"SELECT
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Period AS Period,
	|	DocumentTable.Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	CASE
	|		WHEN DocumentTable.CostForDepreciationCalculation - DocumentTable.CostForDepreciationCalculationBeforeChanging > 0
	|			THEN DocumentTable.GLAccount
	|		ELSE DocumentTable.RevaluationAccount
	|	END AS AccountDr,
	|	CASE
	|		WHEN DocumentTable.CostForDepreciationCalculation - DocumentTable.CostForDepreciationCalculationBeforeChanging > 0
	|			THEN DocumentTable.RevaluationAccount
	|		ELSE DocumentTable.GLAccount
	|	END AS AccountCr,
	|	UNDEFINED AS CurrencyDr,
	|	UNDEFINED AS CurrencyCr,
	|	0 AS AmountCurDr,
	|	0 AS AmountCurCr,
	|	CASE
	|		WHEN DocumentTable.CostForDepreciationCalculation - DocumentTable.CostForDepreciationCalculationBeforeChanging > 0
	|			THEN DocumentTable.CostForDepreciationCalculation - DocumentTable.CostForDepreciationCalculationBeforeChanging
	|		ELSE DocumentTable.CostForDepreciationCalculationBeforeChanging - DocumentTable.CostForDepreciationCalculation
	|	END AS Amount,
	|	CASE
	|		WHEN DocumentTable.CostForDepreciationCalculation - DocumentTable.CostForDepreciationCalculationBeforeChanging > 0
	|			THEN &IncomeReflection
	|		ELSE &CostsReflection
	|	END AS Content,
	|	FALSE AS OfflineRecord
	|FROM
	|	TemporaryTableFixedAssetDepreciationChanges AS DocumentTable
	|WHERE
	|	DocumentTable.CostForDepreciationCalculation - DocumentTable.CostForDepreciationCalculationBeforeChanging <> 0
	|
	|UNION ALL
	|
	|SELECT
	|	OfflineRecords.LineNumber,
	|	OfflineRecords.Period,
	|	OfflineRecords.Company,
	|	OfflineRecords.PlanningPeriod,
	|	OfflineRecords.AccountDr,
	|	OfflineRecords.AccountCr,
	|	OfflineRecords.CurrencyDr,
	|	OfflineRecords.CurrencyCr,
	|	OfflineRecords.AmountCurDr,
	|	OfflineRecords.AmountCurCr,
	|	OfflineRecords.Amount,
	|	OfflineRecords.Content,
	|	OfflineRecords.OfflineRecord
	|FROM
	|	AccountingRegister.AccountingJournalEntries AS OfflineRecords
	|WHERE
	|	OfflineRecords.Recorder = &Ref
	|	AND OfflineRecords.OfflineRecord
	|
	|ORDER BY
	|	LineNumber";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountingJournalEntries", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableFixedAssetParameters(DocumentRefFixedAssetDepreciationChanges, StructureAdditionalProperties) Export
	
	Query = New Query;
	
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefFixedAssetDepreciationChanges);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	
	Query.Text =
	"SELECT
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Period AS Period,
	|	DocumentTable.FixedAsset AS FixedAsset,
	|	&Company AS Company,
	|	DocumentTable.AmountOfProductsServicesForDepreciationCalculation AS AmountOfProductsServicesForDepreciationCalculation,
	|	DocumentTable.CostForDepreciationCalculation AS CostForDepreciationCalculation,
	|	DocumentTable.ApplyInCurrentMonth AS ApplyInCurrentMonth,
	|	DocumentTable.UsagePeriodForDepreciationCalculation AS UsagePeriodForDepreciationCalculation,
	|	DocumentTable.GLExpenseAccount AS GLExpenseAccount,
	|	DocumentTable.StructuralUnit AS StructuralUnit,
	|	DocumentTable.BusinessLine AS BusinessLine
	|FROM
	|	TemporaryTableFixedAssetDepreciationChanges AS DocumentTable
	|
	|ORDER BY
	|	LineNumber";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableFixedAssetParameters", QueryResult.Unload());
	
EndProcedure

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefFixedAssetDepreciationChanges, StructureAdditionalProperties) Export
	
	Query = New Query;
	
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefFixedAssetDepreciationChanges);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	
	Query.Text =
	"SELECT
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Ref.Date AS Period,
	|	DocumentTable.FixedAsset AS FixedAsset,
	|	DocumentTable.FixedAsset.GLAccount AS GLAccount,
	|	&Company AS Company,
	|	DocumentTable.AmountOfProductsServicesForDepreciationCalculation AS AmountOfProductsServicesForDepreciationCalculation,
	|	DocumentTable.CostForDepreciationCalculation AS CostForDepreciationCalculation,
	|	DocumentTable.CostForDepreciationCalculationBeforeChanging AS CostForDepreciationCalculationBeforeChanging,
	|	DocumentTable.RevaluationAccount AS RevaluationAccount,
	|	DocumentTable.ApplyInCurrentMonth AS ApplyInCurrentMonth,
	|	DocumentTable.UsagePeriodForDepreciationCalculation AS UsagePeriodForDepreciationCalculation,
	|	DocumentTable.GLExpenseAccount AS GLExpenseAccount,
	|	DocumentTable.StructuralUnit AS StructuralUnit,
	|	DocumentTable.BusinessLine AS BusinessLine
	|INTO TemporaryTableFixedAssetDepreciationChanges
	|FROM
	|	Document.FixedAssetDepreciationChanges.FixedAssets AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref";
	
	QueryResult = Query.Execute();
	
	GenerateTableFixedAssetParameters(DocumentRefFixedAssetDepreciationChanges, StructureAdditionalProperties);
	GenerateTableFixedAssets(DocumentRefFixedAssetDepreciationChanges, StructureAdditionalProperties);
	GenerateTableIncomeAndExpenses(DocumentRefFixedAssetDepreciationChanges, StructureAdditionalProperties);
	GenerateTableAccountingJournalEntries(DocumentRefFixedAssetDepreciationChanges, StructureAdditionalProperties);
	
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