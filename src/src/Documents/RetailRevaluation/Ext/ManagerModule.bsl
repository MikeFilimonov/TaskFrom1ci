#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTablePOSSummary(DocumentRefRetailRevaluation, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();
	
	Query.SetParameter("Ref", DocumentRefRetailRevaluation);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("RetailRevaluation", NStr("en = 'Revaluation in retail'", MainLanguageCode));
	Query.SetParameter("ExchangeDifference", NStr("en = 'Foreign currency exchange gains and losses'", MainLanguageCode));
	
	Query.Text =
	"SELECT
	|	DocumentTable.Date AS Date,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.StructuralUnit AS StructuralUnit,
	|	DocumentTable.DocumentCurrency AS Currency,
	|	DocumentTable.StructuralUnitGLAccountInRetail AS GLAccount,
	|	DocumentTable.StructuralUnitGLAccountInRetail AS StructuralUnitGLAccountInRetail,
	|	DocumentTable.StructuralUnitGLAccountMarkup AS StructuralUnitGLAccountMarkup,
	|	DocumentTable.SalesOrder AS SalesOrder,
	|	SUM(DocumentTable.Amount) AS Amount,
	|	SUM(DocumentTable.AmountCur) AS AmountCur,
	|	SUM(DocumentTable.Amount) AS AmountForBalance,
	|	SUM(DocumentTable.AmountCur) AS AmountCurForBalance,
	|	0 AS Cost,
	|	&RetailRevaluation AS ContentOfAccountingRecord
	|INTO TemporaryTablePOSSummary
	|FROM
	|	TemporaryTableInventory AS DocumentTable
	|
	|GROUP BY
	|	DocumentTable.Date,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Company,
	|	DocumentTable.StructuralUnit,
	|	DocumentTable.DocumentCurrency,
	|	DocumentTable.StructuralUnitGLAccountInRetail,
	|	DocumentTable.StructuralUnitGLAccountInRetail,
	|	DocumentTable.StructuralUnitGLAccountMarkup,
	|	DocumentTable.SalesOrder
	|
	|INDEX BY
	|	Company,
	|	StructuralUnit,
	|	Currency,
	|	GLAccount";
	
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
	
	QueryNumber = 0;
	Query.Text = DriveServer.GetQueryTextExchangeRateDifferencesPOSSummary(Query.TempTablesManager, QueryNumber);
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TablePOSSummary", ResultsArray[QueryNumber].Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableIncomeAndExpenses(DocumentRefRetailRevaluation, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();
	
	Query.SetParameter("IncomeReflection", NStr("en = 'Record income'", MainLanguageCode));
	Query.SetParameter("CostsReflection", NStr("en = 'Record expenses'", MainLanguageCode));
	Query.SetParameter("ExchangeDifference", NStr("en = 'Foreign currency exchange gains and losses'", MainLanguageCode));
	Query.SetParameter("ForeignCurrencyExchangeGain", Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeGain")); 
	Query.SetParameter("ForeignCurrencyExchangeLoss", Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeLoss"));
	
	Query.Text =
	"SELECT
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Date AS Period,
	|	DocumentTable.Company AS Company,
	|	VALUE(Catalog.BusinessUnits.EmptyRef) AS StructuralUnit,
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
	|	TemporaryTableCurrencyExchangeRateDifferencesPOSSummary AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	DocumentTable.StructuralUnit,
	|	UNDEFINED,
	|	VALUE(Catalog.LinesOfBusiness.Other),
	|	DocumentTable.StructuralUnitGLAccountMarkup,
	|	&CostsReflection,
	|	0,
	|	-DocumentTable.Amount,
	|	FALSE
	|FROM
	|	TemporaryTableInventory AS DocumentTable
	|WHERE
	|	DocumentTable.StructuralUnitGLAccountMarkup.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherExpenses)
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	DocumentTable.StructuralUnit,
	|	UNDEFINED,
	|	VALUE(Catalog.LinesOfBusiness.Other),
	|	DocumentTable.StructuralUnitGLAccountMarkup,
	|	&IncomeReflection,
	|	DocumentTable.Amount,
	|	0,
	|	FALSE
	|FROM
	|	TemporaryTableInventory AS DocumentTable
	|WHERE
	|	DocumentTable.StructuralUnitGLAccountMarkup.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherIncome)";
		
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpenses", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableAccountingJournalEntries(DocumentRefRetailRevaluation, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();
	
	Query.SetParameter("TradeMarkup", NStr("en = 'Retail markup'", MainLanguageCode));
	Query.SetParameter("ExchangeDifference", NStr("en = 'Foreign currency exchange gains and losses'", MainLanguageCode));
	Query.SetParameter("IncomeReflection", NStr("en = 'Record income'", MainLanguageCode));
	Query.SetParameter("CostsReflection", NStr("en = 'Record expenses'", MainLanguageCode));
	Query.SetParameter("ForeignCurrencyExchangeGain", Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeGain")); 
	Query.SetParameter("ForeignCurrencyExchangeLoss", Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeLoss"));
	Query.SetParameter("Ref", DocumentRefRetailRevaluation);
		
	Query.Text =
	"SELECT
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Date AS Period,
	|	DocumentTable.Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	DocumentTable.StructuralUnitGLAccountInRetail AS AccountDr,
	|	DocumentTable.StructuralUnitGLAccountMarkup AS AccountCr,
	|	CASE
	|		WHEN DocumentTable.StructuralUnitGLAccountInRetail.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN DocumentTable.StructuralUnitGLAccountMarkup.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	CASE
	|		WHEN DocumentTable.StructuralUnitGLAccountInRetail.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE UNDEFINED
	|	END AS AmountCurDr,
	|	CASE
	|		WHEN DocumentTable.StructuralUnitGLAccountMarkup.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE UNDEFINED
	|	END AS AmountCurCr,
	|	DocumentTable.Amount AS Amount,
	|	CASE
	|		WHEN DocumentTable.StructuralUnitGLAccountMarkup.TypeOfAccount = VALUE(Enum.GLAccountsTypes.RetailMarkup)
	|			THEN &TradeMarkup
	|		ELSE &IncomeReflection
	|	END AS Content,
	|	FALSE AS OfflineRecord
	|FROM
	|	TemporaryTablePOSSummary AS DocumentTable
	|WHERE
	|	DocumentTable.StructuralUnitGLAccountMarkup.TypeOfAccount <> VALUE(Enum.GLAccountsTypes.OtherExpenses)
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.StructuralUnitGLAccountMarkup,
	|	DocumentTable.StructuralUnitGLAccountInRetail,
	|	CASE
	|		WHEN DocumentTable.StructuralUnitGLAccountMarkup.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.StructuralUnitGLAccountInRetail.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.StructuralUnitGLAccountMarkup.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.StructuralUnitGLAccountInRetail.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE UNDEFINED
	|	END,
	|	-DocumentTable.Amount,
	|	&CostsReflection,
	|	FALSE
	|FROM
	|	TemporaryTablePOSSummary AS DocumentTable
	|WHERE
	|	DocumentTable.StructuralUnitGLAccountMarkup.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherExpenses)
	|
	|UNION ALL
	|
	|SELECT
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

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefRetailRevaluation, StructureAdditionalProperties) Export
	
	Query = New Query;
	
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefRetailRevaluation);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	
	Query.Text =
	"SELECT
	|	MAX(DocumentTable.LineNumber) AS LineNumber,
	|	DocumentTable.Ref.Date AS Date,
	|	UNDEFINED AS SalesOrder,
	|	DocumentTable.Ref.DocumentCurrency AS DocumentCurrency,
	|	DocumentTable.Ref.StructuralUnit AS StructuralUnit,
	|	DocumentTable.Ref.StructuralUnit.GLAccountInRetail AS StructuralUnitGLAccountInRetail,
	|	DocumentTable.Ref.Correspondence AS StructuralUnitGLAccountMarkup,
	|	&Company AS Company,
	|	SUM(CAST(DocumentTable.Amount * ExchangeRatesOfDocument.ExchangeRate * AccountingExchangeRates.Multiplicity / (AccountingExchangeRates.ExchangeRate * ExchangeRatesOfDocument.Multiplicity) AS NUMBER(15, 2))) AS Amount,
	|	SUM(DocumentTable.Amount) AS AmountCur
	|INTO TemporaryTableInventory
	|FROM
	|	Document.RetailRevaluation.Inventory AS DocumentTable
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(
	|				&PointInTime,
	|				Currency In
	|					(SELECT
	|						Constants.PresentationCurrency
	|					FROM
	|						Constants AS Constants)) AS AccountingExchangeRates
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&PointInTime, ) AS ExchangeRatesOfDocument
	|		ON DocumentTable.Ref.DocumentCurrency = ExchangeRatesOfDocument.Currency
	|WHERE
	|	DocumentTable.Ref = &Ref
	|
	|GROUP BY
	|	DocumentTable.Ref,
	|	DocumentTable.Ref.DocumentCurrency,
	|	DocumentTable.Ref.StructuralUnit,
	|	DocumentTable.Ref.StructuralUnit.GLAccountInRetail,
	|	DocumentTable.Ref.Date,
	|	DocumentTable.Ref.Correspondence";
	
	Query.ExecuteBatch();
	
	// Register record table creation by account sections.
	GenerateTablePOSSummary(DocumentRefRetailRevaluation, StructureAdditionalProperties);
	GenerateTableIncomeAndExpenses(DocumentRefRetailRevaluation, StructureAdditionalProperties);
	GenerateTableAccountingJournalEntries(DocumentRefRetailRevaluation, StructureAdditionalProperties);
	
EndProcedure

// Controls the occurrence of negative balances.
//
Procedure RunControl(DocumentRefRetailRevaluation, AdditionalProperties, Cancel, PostingDelete = False) Export
	
	If Not Constants.CheckStockBalanceOnPosting.Get() Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// If temporary tables contain records, it is
	// necessary to execute negative balance control.
	If StructureTemporaryTables.RegisterRecordsPOSSummaryUpdate Then
		
		Query = New Query(
		"SELECT
		|	RegisterRecordsPOSSummaryUpdate.LineNumber AS LineNumber,
		|	REFPRESENTATION(RegisterRecordsPOSSummaryUpdate.Company) AS CompanyPresentation,
		|	REFPRESENTATION(RegisterRecordsPOSSummaryUpdate.StructuralUnit) AS StructuralUnitPresentation,
		|	REFPRESENTATION(RegisterRecordsPOSSummaryUpdate.StructuralUnit.RetailPriceKind.PriceCurrency) AS CurrencyPresentation,
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
		|		LEFT JOIN AccumulationRegister.POSSummary.Balance(
		|				&ControlTime,
		|				(Company, StructuralUnit) In
		|					(SELECT
		|						RegisterRecordsPOSSummaryUpdate.Company AS Company,
		|						RegisterRecordsPOSSummaryUpdate.StructuralUnit AS StructuralUnit
		|					FROM
		|						RegisterRecordsPOSSummaryUpdate AS RegisterRecordsPOSSummaryUpdate)) AS POSSummaryBalances
		|		ON RegisterRecordsPOSSummaryUpdate.Company = POSSummaryBalances.Company
		|			AND RegisterRecordsPOSSummaryUpdate.StructuralUnit = POSSummaryBalances.StructuralUnit
		|WHERE
		|	ISNULL(POSSummaryBalances.AmountCurBalance, 0) < 0
		|
		|ORDER BY
		|	LineNumber");
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.SetParameter("ControlTime", AdditionalProperties.ForPosting.ControlTime);
		
		ResultsArray = Query.ExecuteBatch();
		
		If Not ResultsArray[0].IsEmpty() Then
			DocumentObjectRetailRevaluation = DocumentRefRetailRevaluation.GetObject()
		EndIf;
		
		// Negative balance according to the amount-based account in retail.
		If Not ResultsArray[0].IsEmpty() Then
			QueryResultSelection = ResultsArray[0].Select();
			DriveServer.ShowMessageAboutPostingToPOSSummaryRegisterErrors(DocumentObjectRetailRevaluation, QueryResultSelection, Cancel);
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