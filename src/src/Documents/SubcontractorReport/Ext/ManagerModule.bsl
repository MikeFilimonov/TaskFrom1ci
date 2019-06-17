#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions

#Region AccountingRecords

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableAccountingJournalEntries(DocumentRefSubcontractorReport, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();
	
	Query.SetParameter("SetOffAdvancePayment",							NStr("en = 'Advance payment clearing'", MainLanguageCode));
	Query.SetParameter("ExchangeDifference",							NStr("en = 'Foreign currency exchange gains and losses'", MainLanguageCode));
	Query.SetParameter("PositiveExchangeDifferenceGLAccount",			Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeGain"));
	Query.SetParameter("NegativeExchangeDifferenceAccountOfAccounting",	Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeLoss"));
	
	Query.Text =
	"SELECT
	|	1 AS Ordering,
	|	1 AS LineNumber,
	|	DocumentTable.Period AS Period,
	|	DocumentTable.Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	DocumentTable.GLAccountVendorSettlements AS AccountDr,
	|	CASE
	|		WHEN DocumentTable.GLAccountVendorSettlementsCurrency
	|			THEN DocumentTable.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN DocumentTable.GLAccountVendorSettlementsCurrency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END AS AmountCurDr,
	|	DocumentTable.VendorAdvancesGLAccount AS AccountCr,
	|	CASE
	|		WHEN DocumentTable.VendorAdvancesGLAccountCurrency
	|			THEN DocumentTable.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	CASE
	|		WHEN DocumentTable.VendorAdvancesGLAccountCurrency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END AS AmountCurCr,
	|	DocumentTable.Amount AS Amount,
	|	&SetOffAdvancePayment AS Content,
	|	FALSE AS OfflineRecord
	|FROM
	|	(SELECT
	|		DocumentTable.Period AS Period,
	|		DocumentTable.Company AS Company,
	|		DocumentTable.VendorAdvancesGLAccount AS VendorAdvancesGLAccount,
	|		DocumentTable.VendorAdvancesGLAccountCurrency AS VendorAdvancesGLAccountCurrency,
	|		DocumentTable.GLAccountVendorSettlements AS GLAccountVendorSettlements,
	|		DocumentTable.GLAccountVendorSettlementsCurrency AS GLAccountVendorSettlementsCurrency,
	|		DocumentTable.SettlementsCurrency AS SettlementsCurrency,
	|		SUM(DocumentTable.AmountCur) AS AmountCur,
	|		SUM(DocumentTable.Amount) AS Amount
	|	FROM
	|		(SELECT
	|			DocumentTable.Period AS Period,
	|			DocumentTable.Company AS Company,
	|			DocumentTable.VendorAdvancesGLAccount AS VendorAdvancesGLAccount,
	|			DocumentTable.VendorAdvancesGLAccount.Currency AS VendorAdvancesGLAccountCurrency,
	|			DocumentTable.GLAccountVendorSettlements AS GLAccountVendorSettlements,
	|			DocumentTable.GLAccountVendorSettlements.Currency AS GLAccountVendorSettlementsCurrency,
	|			DocumentTable.SettlementsCurrency AS SettlementsCurrency,
	|			DocumentTable.AmountCur AS AmountCur,
	|			DocumentTable.Amount AS Amount
	|		FROM
	|			TemporaryTablePrepayment AS DocumentTable
	|		
	|		UNION ALL
	|		
	|		SELECT
	|			DocumentTable.Date,
	|			DocumentTable.Company,
	|			DocumentTable.Counterparty.VendorAdvancesGLAccount,
	|			DocumentTable.Counterparty.VendorAdvancesGLAccount.Currency,
	|			DocumentTable.Counterparty.GLAccountVendorSettlements,
	|			DocumentTable.Counterparty.GLAccountVendorSettlements.Currency,
	|			DocumentTable.Currency,
	|			0,
	|			DocumentTable.AmountOfExchangeDifferences
	|		FROM
	|			TemporaryTableOfExchangeRateDifferencesAccountsPayable AS DocumentTable
	|		WHERE
	|			DocumentTable.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)) AS DocumentTable
	|	
	|	GROUP BY
	|		DocumentTable.Period,
	|		DocumentTable.Company,
	|		DocumentTable.VendorAdvancesGLAccount,
	|		DocumentTable.VendorAdvancesGLAccountCurrency,
	|		DocumentTable.GLAccountVendorSettlements,
	|		DocumentTable.GLAccountVendorSettlementsCurrency,
	|		DocumentTable.SettlementsCurrency
	|	
	|	HAVING
	|		(SUM(DocumentTable.Amount) >= 0.005
	|			OR SUM(DocumentTable.Amount) <= -0.005
	|			OR SUM(DocumentTable.AmountCur) >= 0.005
	|			OR SUM(DocumentTable.AmountCur) <= -0.005)) AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	1,
	|	TableAccountingJournalEntries.Date,
	|	TableAccountingJournalEntries.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	CASE
	|		WHEN TableAccountingJournalEntries.AmountOfExchangeDifferences > 0
	|			THEN &NegativeExchangeDifferenceAccountOfAccounting
	|		ELSE TableAccountingJournalEntries.GLAccount
	|	END,
	|	CASE
	|		WHEN TableAccountingJournalEntries.AmountOfExchangeDifferences < 0
	|				AND TableAccountingJournalEntries.GLAccountForeignCurrency
	|			THEN TableAccountingJournalEntries.Currency
	|		ELSE UNDEFINED
	|	END,
	|	0,
	|	CASE
	|		WHEN TableAccountingJournalEntries.AmountOfExchangeDifferences > 0
	|			THEN TableAccountingJournalEntries.GLAccount
	|		ELSE &PositiveExchangeDifferenceGLAccount
	|	END,
	|	CASE
	|		WHEN TableAccountingJournalEntries.AmountOfExchangeDifferences > 0
	|				AND TableAccountingJournalEntries.GLAccountForeignCurrency
	|			THEN TableAccountingJournalEntries.Currency
	|		ELSE UNDEFINED
	|	END,
	|	0,
	|	CASE
	|		WHEN TableAccountingJournalEntries.AmountOfExchangeDifferences > 0
	|			THEN TableAccountingJournalEntries.AmountOfExchangeDifferences
	|		ELSE -TableAccountingJournalEntries.AmountOfExchangeDifferences
	|	END,
	|	&ExchangeDifference,
	|	FALSE
	|FROM
	|	(SELECT
	|		TableOfExchangeRateDifferencesAccountsPayable.Date AS Date,
	|		TableOfExchangeRateDifferencesAccountsPayable.Company AS Company,
	|		TableOfExchangeRateDifferencesAccountsPayable.GLAccount AS GLAccount,
	|		TableOfExchangeRateDifferencesAccountsPayable.GLAccountForeignCurrency AS GLAccountForeignCurrency,
	|		TableOfExchangeRateDifferencesAccountsPayable.Currency AS Currency,
	|		SUM(TableOfExchangeRateDifferencesAccountsPayable.AmountOfExchangeDifferences) AS AmountOfExchangeDifferences
	|	FROM
	|		(SELECT
	|			DocumentTable.Date AS Date,
	|			DocumentTable.Company AS Company,
	|			DocumentTable.GLAccount AS GLAccount,
	|			DocumentTable.GLAccount.Currency AS GLAccountForeignCurrency,
	|			DocumentTable.Currency AS Currency,
	|			DocumentTable.AmountOfExchangeDifferences AS AmountOfExchangeDifferences
	|		FROM
	|			TemporaryTableOfExchangeRateDifferencesAccountsPayable AS DocumentTable
	|		WHERE
	|			DocumentTable.SettlementsType = VALUE(Enum.SettlementsTypes.Debt)
	|		
	|		UNION ALL
	|		
	|		SELECT
	|			DocumentTable.Date,
	|			DocumentTable.Company,
	|			DocumentTable.GLAccount,
	|			DocumentTable.GLAccount.Currency,
	|			DocumentTable.Currency,
	|			DocumentTable.AmountOfExchangeDifferences
	|		FROM
	|			TemporaryTableOfExchangeRateDifferencesAccountsPayable AS DocumentTable
	|		WHERE
	|			DocumentTable.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)) AS TableOfExchangeRateDifferencesAccountsPayable
	|	
	|	GROUP BY
	|		TableOfExchangeRateDifferencesAccountsPayable.Date,
	|		TableOfExchangeRateDifferencesAccountsPayable.Company,
	|		TableOfExchangeRateDifferencesAccountsPayable.GLAccount,
	|		TableOfExchangeRateDifferencesAccountsPayable.GLAccountForeignCurrency,
	|		TableOfExchangeRateDifferencesAccountsPayable.Currency
	|	
	|	HAVING
	|		(SUM(TableOfExchangeRateDifferencesAccountsPayable.AmountOfExchangeDifferences) >= 0.005
	|			OR SUM(TableOfExchangeRateDifferencesAccountsPayable.AmountOfExchangeDifferences) <= -0.005)) AS TableAccountingJournalEntries
	|
	|UNION ALL
	|
	|SELECT
	|	3,
	|	TableAccountingJournalEntries.LineNumber,
	|	TableAccountingJournalEntries.Period,
	|	TableAccountingJournalEntries.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	TableAccountingJournalEntries.VATInputGLAccount,
	|	UNDEFINED,
	|	0,
	|	TableAccountingJournalEntries.GLAccountVendorSettlements,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccountVendorSettlements.Currency
	|			THEN TableAccountingJournalEntries.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	SUM(CASE
	|			WHEN TableAccountingJournalEntries.GLAccountVendorSettlements.Currency
	|				THEN TableAccountingJournalEntries.VATAmountCur
	|			ELSE 0
	|		END),
	|	SUM(TableAccountingJournalEntries.VATAmount),
	|	&VAT,
	|	FALSE
	|FROM
	|	TemporaryTableForCalculationOfReserves AS TableAccountingJournalEntries
	|WHERE
	|	TableAccountingJournalEntries.VATAmount <> 0
	|
	|GROUP BY
	|	TableAccountingJournalEntries.VATInputGLAccount,
	|	TableAccountingJournalEntries.Period,
	|	TableAccountingJournalEntries.Company,
	|	TableAccountingJournalEntries.GLAccountVendorSettlements,
	|	TableAccountingJournalEntries.LineNumber,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccountVendorSettlements.Currency
	|			THEN TableAccountingJournalEntries.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END
	|
	|UNION ALL
	|
	|SELECT
	|	4,
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
	|	AND OfflineRecords.OfflineRecord";

	Query.SetParameter("VAT",				NStr("en = 'VAT'", MainLanguageCode));
	Query.SetParameter("Ref",				DocumentRefSubcontractorReport);
		
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	While Selection.Next() Do
		NewEntry = StructureAdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries.Add();
		FillPropertyValues(NewEntry, Selection);
	EndDo;
	
EndProcedure

#EndRegion

#Region Services

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventoryService(DocumentRefSubcontractorReport, StructureAdditionalProperties, ServicesAmount)
	
	For n = 0 To StructureAdditionalProperties.TableForRegisterRecords.TableServiceSupplies.Count() - 1 Do
		
		RowTableInventory = StructureAdditionalProperties.TableForRegisterRecords.TableServiceSupplies[n];
		
		// Generate postings.
		If RowTableInventory.Amount > 0 Then
			RowTableAccountingJournalEntries = StructureAdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries.Add();
			FillPropertyValues(RowTableAccountingJournalEntries, RowTableInventory);
		EndIf;
		
		// If this is a production, then assign WIP received costs to products cost.
		If RowTableInventory.StructuralUnitType = Enums.BusinessUnitsTypes.Department Then
				
			// Service receipt to WIP.
			TableRowReceipt = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
			FillPropertyValues(TableRowReceipt, RowTableInventory);
				
			TableRowReceipt.RecordType = AccumulationRecordType.Receipt;
			
			TableRowReceipt.StructuralUnitCorr = Undefined;
			TableRowReceipt.CorrGLAccount = Undefined;
			TableRowReceipt.ProductsCorr = Undefined;
			TableRowReceipt.CharacteristicCorr = Undefined;
			TableRowReceipt.BatchCorr = Undefined;
			TableRowReceipt.SpecificationCorr = Undefined;
			TableRowReceipt.CustomerCorrOrder  = Undefined;
			TableRowReceipt.FixedCost = True;
			
			// Costs writeoff.
			// Generate postings.
			If RowTableInventory.Amount > 0 Then
				RowTableAccountingJournalEntries = StructureAdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries.Add();
				FillPropertyValues(RowTableAccountingJournalEntries, RowTableInventory);
				RowTableAccountingJournalEntries.AccountCr = RowTableAccountingJournalEntries.AccountDr;
				RowTableAccountingJournalEntries.CurrencyCr = Undefined;
				RowTableAccountingJournalEntries.AmountCurCr = 0;
				RowTableAccountingJournalEntries.AccountDr = RowTableInventory.CorrGLAccount;
			EndIf;
		
			TableRowExpense = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
			FillPropertyValues(TableRowExpense, RowTableInventory);
				
			TableRowExpense.RecordType = AccumulationRecordType.Expense;
			
			TableRowExpense.CorrOrganization = RowTableInventory.CorrOrganization;
			TableRowExpense.StructuralUnitCorr = RowTableInventory.StructuralUnitCorr;
			TableRowExpense.CorrGLAccount = RowTableInventory.CorrGLAccount;
			TableRowExpense.ProductsCorr = RowTableInventory.ProductsCorr;
			TableRowExpense.CharacteristicCorr = RowTableInventory.CharacteristicCorr;
			TableRowExpense.BatchCorr = RowTableInventory.BatchCorr;
			TableRowExpense.SpecificationCorr = RowTableInventory.SpecificationCorr;
			
 			TableRowExpense.CustomerCorrOrder = RowTableInventory.CustomerCorrOrder;
				
			TableRowExpense.GLAccount = RowTableInventory.GLAccount;
		    TableRowExpense.FixedCost = False;
			TableRowExpense.ProductionExpenses = True;
				
			// Assign costs to prime cost.
			TableRowReceipt = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
			FillPropertyValues(TableRowReceipt, RowTableInventory);
				
			TableRowReceipt.RecordType = AccumulationRecordType.Receipt;
						
			TableRowReceipt.Company = RowTableInventory.CorrOrganization;
			TableRowReceipt.StructuralUnit = RowTableInventory.StructuralUnitCorr;
			TableRowReceipt.GLAccount = RowTableInventory.CorrGLAccount;
			TableRowReceipt.Products = RowTableInventory.ProductsCorr;
			TableRowReceipt.Characteristic = RowTableInventory.CharacteristicCorr;
			TableRowReceipt.Batch = RowTableInventory.BatchCorr;
			TableRowReceipt.Specification = RowTableInventory.SpecificationCorr;
			
			TableRowReceipt.SalesOrder = RowTableInventory.CustomerCorrOrder;
			
			TableRowReceipt.CorrOrganization = RowTableInventory.Company;
			TableRowReceipt.StructuralUnitCorr = RowTableInventory.StructuralUnit;
			TableRowReceipt.CorrGLAccount = RowTableInventory.GLAccount;
			TableRowReceipt.ProductsCorr = RowTableInventory.Products;
			TableRowReceipt.CharacteristicCorr = RowTableInventory.Characteristic;
			TableRowReceipt.BatchCorr = RowTableInventory.Batch;
			TableRowReceipt.SpecificationCorr = RowTableInventory.Specification;
			
			TableRowReceipt.GLAccount = RowTableInventory.CorrGLAccount;
		    TableRowReceipt.FixedCost = False;
			
			ServicesAmount = ServicesAmount + RowTableInventory.Amount;
				
		Else
			
			// Assign costs to prime cost.
			TableRowReceipt = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
			FillPropertyValues(TableRowReceipt, RowTableInventory);
				
			TableRowReceipt.RecordType = AccumulationRecordType.Receipt;
			
			
			TableRowReceipt.Company = RowTableInventory.CorrOrganization;
			TableRowReceipt.StructuralUnit = RowTableInventory.StructuralUnitCorr;
			TableRowReceipt.GLAccount = RowTableInventory.CorrGLAccount;
			TableRowReceipt.Products = RowTableInventory.ProductsCorr;
			TableRowReceipt.Characteristic = RowTableInventory.CharacteristicCorr;
			TableRowReceipt.Batch = RowTableInventory.BatchCorr;
			TableRowReceipt.Specification = RowTableInventory.SpecificationCorr;
			TableRowReceipt.SalesOrder = RowTableInventory.CustomerCorrOrder;
			
			TableRowReceipt.StructuralUnitCorr = Undefined;
			TableRowReceipt.CorrGLAccount = Undefined;
			TableRowReceipt.ProductsCorr = Undefined;
			TableRowReceipt.CharacteristicCorr = Undefined;
			TableRowReceipt.BatchCorr = Undefined;
			TableRowReceipt.SpecificationCorr = Undefined;
		    TableRowReceipt.CustomerCorrOrder  = Undefined;
		    TableRowReceipt.FixedCost = True;
			
			TableRowReceipt.GLAccount = RowTableInventory.CorrGLAccount;
			
			ServicesAmount = ServicesAmount + RowTableInventory.Amount;
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure DataInitializationByService(DocumentRefSubcontractorReport, StructureAdditionalProperties, ServicesAmount) Export

	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	SUM(TemporaryTable.VATAmount) AS VATExpenses,
	|	SUM(TemporaryTable.VATAmountCur) AS VATExpensesCur
	|FROM
	|	TemporaryTableForCalculationOfReserves AS TemporaryTable
	|
	|GROUP BY
	|	TemporaryTable.Period,
	|	TemporaryTable.Company";
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	VATExpenses = 0;
	VATExpensesCur = 0;
	
	While Selection.Next() Do
		VATExpenses		= Selection.VATExpenses;
		VATExpensesCur	= Selection.VATExpensesCur;
	EndDo;
	
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	0 AS LineNumber,
	|	SubcontractorReport.Date AS Period,
	|	SubcontractorReport.StructuralUnit.StructuralUnitType AS StructuralUnitType,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	&Company AS Company,
	|	&Company AS CorrOrganization,
	|	SubcontractorReport.StructuralUnit AS StructuralUnit,
	|	SubcontractorReport.StructuralUnit AS StructuralUnitCorr,
	|	SubcontractorReport.Expense.ExpensesGLAccount AS GLAccount,
	|	SubcontractorReport.InventoryGLAccount AS CorrGLAccount,
	|	VALUE(Catalog.Products.EmptyRef) AS Products,
	|	SubcontractorReport.Products AS ProductsCorr,
	|	VALUE(Catalog.ProductsCharacteristics.EmptyRef) AS Characteristic,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN SubcontractorReport.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS CharacteristicCorr,
	|	VALUE(Catalog.ProductsBatches.EmptyRef) AS Batch,
	|	CASE
	|		WHEN &UseBatches
	|			THEN SubcontractorReport.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS BatchCorr,
	|	VALUE(Catalog.BillsOfMaterials.EmptyRef) AS Specification,
	|	SubcontractorReport.Specification AS SpecificationCorr,
	|	SubcontractorReport.SalesOrder AS SalesOrder,
	|	SubcontractorReport.SalesOrder AS CustomerCorrOrder,
	|	0 AS Quantity,
	|	CAST(CASE
	|			WHEN SubcontractorReport.DocumentCurrency = ConstantNationalCurrency.Value
	|				THEN SubcontractorReport.Total * RegExchangeRates.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * RegExchangeRates.Multiplicity) - &VATExpenses
	|			ELSE SubcontractorReport.Total * SubcontractorReport.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * SubcontractorReport.Multiplicity) - &VATExpenses
	|		END AS NUMBER(15, 2)) AS Amount,
	|	CAST(CASE
	|			WHEN SubcontractorReport.DocumentCurrency = ConstantNationalCurrency.Value
	|				THEN SubcontractorReport.Total * RegExchangeRates.ExchangeRate * SubcontractorReport.Ref.Multiplicity / (SubcontractorReport.Ref.ExchangeRate * RegExchangeRates.Multiplicity) - &VATExpensesCur
	|			ELSE SubcontractorReport.Total - &VATExpensesCur
	|		END AS NUMBER(15, 2)) AS AmountCur,
	|	CASE
	|		WHEN SubcontractorReport.StructuralUnit.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Department)
	|			THEN SubcontractorReport.ConsumptionGLAccount
	|		ELSE SubcontractorReport.InventoryGLAccount
	|	END AS AccountDr,
	|	UNDEFINED AS CurrencyDr,
	|	0 AS AmountCurDr,
	|	SubcontractorReport.Counterparty.GLAccountVendorSettlements AS AccountCr,
	|	CASE
	|		WHEN SubcontractorReport.Counterparty.GLAccountVendorSettlements.Currency
	|			THEN SubcontractorReport.Contract.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	CASE
	|		WHEN SubcontractorReport.Counterparty.GLAccountVendorSettlements.Currency
	|			THEN CAST(CASE
	|						WHEN SubcontractorReport.DocumentCurrency = ConstantNationalCurrency.Value
	|							THEN SubcontractorReport.Total * RegExchangeRates.ExchangeRate * SubcontractorReport.Ref.Multiplicity / (SubcontractorReport.Ref.ExchangeRate * RegExchangeRates.Multiplicity) - &VATExpensesCur
	|						ELSE SubcontractorReport.Total - &VATExpensesCur
	|					END AS NUMBER(15, 2))
	|		ELSE 0
	|	END AS AmountCurCr,
	|	&ReflectionCostsOnProcessing AS Content,
	|	&ReflectionCostsOnProcessing AS ContentOfAccountingRecord
	|FROM
	|	Document.SubcontractorReport AS SubcontractorReport
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(
	|				&PointInTime,
	|				Currency IN
	|					(SELECT
	|						ConstantAccountingCurrency.Value
	|					FROM
	|						Constant.PresentationCurrency AS ConstantAccountingCurrency)) AS ManagExchangeRates
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(
	|				&PointInTime,
	|				Currency IN
	|					(SELECT
	|						ConstantNationalCurrency.Value
	|					FROM
	|						Constant.FunctionalCurrency AS ConstantNationalCurrency)) AS RegExchangeRates
	|		ON (TRUE),
	|	Constant.FunctionalCurrency AS ConstantNationalCurrency
	|WHERE
	|	SubcontractorReport.Ref = &Ref
	|	AND SubcontractorReport.Total > 0";
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();
	
	Query.SetParameter("Ref", DocumentRefSubcontractorReport);
	Query.SetParameter("ControlTime", StructureAdditionalProperties.ForPosting.ControlTime);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("UseCharacteristics", StructureAdditionalProperties.AccountingPolicy.UseCharacteristics);
	Query.SetParameter("UseBatches", StructureAdditionalProperties.AccountingPolicy.UseBatches);
	Query.SetParameter("ReflectionCostsOnProcessing", NStr("en = 'Record processing expenses'", MainLanguageCode));
	Query.SetParameter("VATExpenses", VATExpenses);
	Query.SetParameter("VATExpensesCur", VATExpensesCur);

	Result = Query.Execute();
	
	// Determine table for inventory accounting.
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableServiceSupplies", Result.Unload());

	// Generate table for inventory accounting.
	GenerateTableInventoryService(DocumentRefSubcontractorReport, StructureAdditionalProperties, ServicesAmount);
	
EndProcedure

#EndRegion

#Region Disposals

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventoryDisposals(DocumentRefSubcontractorReport, StructureAdditionalProperties)
	
	For n = 0 To StructureAdditionalProperties.TableForRegisterRecords.TableInventoryDisposals.Count() - 1 Do
		
		RowTableInventory = StructureAdditionalProperties.TableForRegisterRecords.TableInventoryDisposals[n];
				
		TableRowReceipt = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
		FillPropertyValues(TableRowReceipt, RowTableInventory);
		
	EndDo;
	
EndProcedure

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure DataInitializationByDisposals(DocumentRefSubcontractorReport, StructureAdditionalProperties) Export

	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	SubcontractorReportDisposals.LineNumber AS LineNumber,
	|	SubcontractorReportDisposals.Ref.Date AS Period,
	|	&Company AS Company,
	|	SubcontractorReportDisposals.Ref.StructuralUnit AS StructuralUnit,
	|	CASE
	|		WHEN &UseStorageBins
	|			THEN SubcontractorReportDisposals.Ref.Cell
	|		ELSE VALUE(Catalog.Cells.EmptyRef)
	|	END AS Cell,
	|	SubcontractorReportDisposals.InventoryGLAccount AS GLAccount,
	|	SubcontractorReportDisposals.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN SubcontractorReportDisposals.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseBatches
	|			THEN SubcontractorReportDisposals.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS Batch,
	|	CASE
	|		WHEN VALUETYPE(SubcontractorReportDisposals.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN SubcontractorReportDisposals.Quantity
	|		ELSE SubcontractorReportDisposals.Quantity * SubcontractorReportDisposals.MeasurementUnit.Factor
	|	END AS Quantity,
	|	0 AS Amount,
	|	&ReturnWaste AS ContentOfAccountingRecord
	|FROM
	|	Document.SubcontractorReport.Disposals AS SubcontractorReportDisposals
	|WHERE
	|	SubcontractorReportDisposals.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SubcontractorReportDisposals.LineNumber AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	SubcontractorReportDisposals.Ref.Date AS Period,
	|	&Company AS Company,
	|	SubcontractorReportDisposals.Ref.StructuralUnit AS StructuralUnit,
	|	CASE
	|		WHEN &UseStorageBins
	|			THEN SubcontractorReportDisposals.Ref.Cell
	|		ELSE UNDEFINED
	|	END AS Cell,
	|	SubcontractorReportDisposals.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN SubcontractorReportDisposals.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseBatches
	|			THEN SubcontractorReportDisposals.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS Batch,
	|	CASE
	|		WHEN VALUETYPE(SubcontractorReportDisposals.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN SubcontractorReportDisposals.Quantity
	|		ELSE SubcontractorReportDisposals.Quantity * SubcontractorReportDisposals.MeasurementUnit.Factor
	|	END AS Quantity
	|FROM
	|	Document.SubcontractorReport.Disposals AS SubcontractorReportDisposals
	|WHERE
	|	SubcontractorReportDisposals.Ref = &Ref";
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();
	
	Query.SetParameter("Ref", DocumentRefSubcontractorReport);
	Query.SetParameter("ControlTime", StructureAdditionalProperties.ForPosting.ControlTime);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("UseCharacteristics", StructureAdditionalProperties.AccountingPolicy.UseCharacteristics);
	Query.SetParameter("UseBatches", StructureAdditionalProperties.AccountingPolicy.UseBatches);
	Query.SetParameter("UseStorageBins", StructureAdditionalProperties.AccountingPolicy.UseStorageBins);
	Query.SetParameter("ReturnWaste", NStr("en = 'Recyclable waste'", MainLanguageCode));
	
	ResultsArray = Query.ExecuteBatch();
	
	// Determine table for inventory accounting.
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryDisposals", ResultsArray[0].Unload());

	// Generate table for inventory accounting.
	GenerateTableInventoryDisposals(DocumentRefSubcontractorReport, StructureAdditionalProperties);

	// Expand table for inventory.
	ResultsSelection = ResultsArray[1].Select();
	While ResultsSelection.Next() Do
		TableRowExpense = StructureAdditionalProperties.TableForRegisterRecords.TableInventoryInWarehouses.Add();
		FillPropertyValues(TableRowExpense, ResultsSelection);
	EndDo;

EndProcedure

#EndRegion

#Region Inventory

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventoryInventory(DocumentRefSubcontractorReport, StructureAdditionalProperties, AssemblyAmount)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	// Setting the exclusive lock for the controlled inventory balances.
	Query.Text = 
	"SELECT
	|	TableInventory.Company AS Company,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	TableInventory.GLAccount AS GLAccount,
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	CASE
	|		WHEN TableInventory.SalesOrder = VALUE(Document.SalesOrder.EmptyRef)
	|				OR TableInventory.SalesOrder = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE TableInventory.SalesOrder
	|	END AS SalesOrder
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|
	|GROUP BY
	|	TableInventory.Company,
	|	TableInventory.StructuralUnit,
	|	TableInventory.GLAccount,
	|	TableInventory.Products,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	TableInventory.SalesOrder";
	
	QueryResult = Query.Execute();
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.Inventory");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;

	For Each ColumnQueryResult In QueryResult.Columns Do
		LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
	EndDo;
	Block.Lock();
	
	// Receiving inventory balances by cost.
	Query.Text = 	
	"SELECT
	|	InventoryBalances.Company AS Company,
	|	InventoryBalances.StructuralUnit AS StructuralUnit,
	|	InventoryBalances.GLAccount AS GLAccount,
	|	InventoryBalances.Products AS Products,
	|	InventoryBalances.Characteristic AS Characteristic,
	|	InventoryBalances.Batch AS Batch,
	|	InventoryBalances.SalesOrder AS SalesOrder,
	|	SUM(InventoryBalances.QuantityBalance) AS QuantityBalance,
	|	SUM(InventoryBalances.AmountBalance) AS AmountBalance
	|FROM
	|	(SELECT
	|		InventoryBalances.Company AS Company,
	|		InventoryBalances.StructuralUnit AS StructuralUnit,
	|		InventoryBalances.GLAccount AS GLAccount,
	|		InventoryBalances.Products AS Products,
	|		InventoryBalances.Characteristic AS Characteristic,
	|		InventoryBalances.Batch AS Batch,
	|		InventoryBalances.SalesOrder AS SalesOrder,
	|		SUM(InventoryBalances.QuantityBalance) AS QuantityBalance,
	|		SUM(InventoryBalances.AmountBalance) AS AmountBalance
	|	FROM
	|		AccumulationRegister.Inventory.Balance(
	|				&ControlTime,
	|				(Company, StructuralUnit, GLAccount, Products, Characteristic, Batch, SalesOrder) IN
	|					(SELECT
	|						TableInventory.Company,
	|						TableInventory.StructuralUnit,
	|						TableInventory.GLAccount,
	|						TableInventory.Products,
	|						TableInventory.Characteristic,
	|						TableInventory.Batch,
	|						CASE
	|							WHEN TableInventory.SalesOrder = VALUE(Document.SalesOrder.EmptyRef)
	|									OR TableInventory.SalesOrder = VALUE(Document.WorkOrder.EmptyRef)
	|								THEN UNDEFINED
	|							ELSE TableInventory.SalesOrder
	|						END AS SalesOrder
	|					FROM
	|						TemporaryTableInventory AS TableInventory)) AS InventoryBalances
	|	
	|	GROUP BY
	|		InventoryBalances.Company,
	|		InventoryBalances.StructuralUnit,
	|		InventoryBalances.GLAccount,
	|		InventoryBalances.Products,
	|		InventoryBalances.Characteristic,
	|		InventoryBalances.Batch,
	|		InventoryBalances.SalesOrder
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsInventory.Company,
	|		DocumentRegisterRecordsInventory.StructuralUnit,
	|		DocumentRegisterRecordsInventory.GLAccount,
	|		DocumentRegisterRecordsInventory.Products,
	|		DocumentRegisterRecordsInventory.Characteristic,
	|		DocumentRegisterRecordsInventory.Batch,
	|		DocumentRegisterRecordsInventory.SalesOrder,
	|		CASE
	|			WHEN DocumentRegisterRecordsInventory.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN ISNULL(DocumentRegisterRecordsInventory.Quantity, 0)
	|			ELSE -ISNULL(DocumentRegisterRecordsInventory.Quantity, 0)
	|		END,
	|		CASE
	|			WHEN DocumentRegisterRecordsInventory.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN ISNULL(DocumentRegisterRecordsInventory.Amount, 0)
	|			ELSE -ISNULL(DocumentRegisterRecordsInventory.Amount, 0)
	|		END
	|	FROM
	|		AccumulationRegister.Inventory AS DocumentRegisterRecordsInventory
	|	WHERE
	|		DocumentRegisterRecordsInventory.Recorder = &Ref
	|		AND DocumentRegisterRecordsInventory.Period <= &ControlPeriod) AS InventoryBalances
	|
	|GROUP BY
	|	InventoryBalances.Company,
	|	InventoryBalances.StructuralUnit,
	|	InventoryBalances.GLAccount,
	|	InventoryBalances.Products,
	|	InventoryBalances.Characteristic,
	|	InventoryBalances.Batch,
	|	InventoryBalances.SalesOrder";
	
	Query.SetParameter("Ref", DocumentRefSubcontractorReport);
	Query.SetParameter("ControlTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.PointInTime.Date);
	
	QueryResult = Query.Execute();
	
	TableInventoryBalances = QueryResult.Unload();
	TableInventoryBalances.Indexes.Add("Company,StructuralUnit,GLAccount,Products,Characteristic,Batch,SalesOrder");
	
	For n = 0 To StructureAdditionalProperties.TableForRegisterRecords.TableInventoryInventory.Count() - 1 Do
		
		RowTableInventory = StructureAdditionalProperties.TableForRegisterRecords.TableInventoryInventory[n];
		
		StructureForSearch = New Structure;
		StructureForSearch.Insert("Company", RowTableInventory.Company);
		StructureForSearch.Insert("StructuralUnit", RowTableInventory.StructuralUnit);
		StructureForSearch.Insert("GLAccount", RowTableInventory.GLAccount);
		StructureForSearch.Insert("Products", RowTableInventory.Products);
		StructureForSearch.Insert("Characteristic", RowTableInventory.Characteristic);
		StructureForSearch.Insert("Batch", RowTableInventory.Batch);
		StructureForSearch.Insert("SalesOrder", RowTableInventory.SalesOrder);
		
		QuantityRequiredAvailableBalance = RowTableInventory.Quantity;
						
		If QuantityRequiredAvailableBalance > 0 Then
								
			BalanceRowsArray = TableInventoryBalances.FindRows(StructureForSearch);
			
			QuantityBalance = 0;
			AmountBalance = 0;
			
			If BalanceRowsArray.Count() > 0 Then
				QuantityBalance = BalanceRowsArray[0].QuantityBalance;
				AmountBalance = BalanceRowsArray[0].AmountBalance;
			EndIf;
			
			If QuantityBalance > 0 AND QuantityBalance > QuantityRequiredAvailableBalance Then

				AmountToBeWrittenOff = Round(AmountBalance * QuantityRequiredAvailableBalance / QuantityBalance , 2, 1);

				BalanceRowsArray[0].QuantityBalance = BalanceRowsArray[0].QuantityBalance - QuantityRequiredAvailableBalance;
				BalanceRowsArray[0].AmountBalance = BalanceRowsArray[0].AmountBalance - AmountToBeWrittenOff;

			ElsIf QuantityBalance = QuantityRequiredAvailableBalance Then

				AmountToBeWrittenOff = AmountBalance;

				BalanceRowsArray[0].QuantityBalance = 0;
				BalanceRowsArray[0].AmountBalance = 0;

			Else
				AmountToBeWrittenOff = 0;	
			EndIf;
			
			AssemblyAmount = AssemblyAmount + AmountToBeWrittenOff;
	
			// Expense.
			TableRowExpense = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
			FillPropertyValues(TableRowExpense, RowTableInventory);
			
			TableRowExpense.Amount = AmountToBeWrittenOff;
			TableRowExpense.Quantity = QuantityRequiredAvailableBalance;
			TableRowExpense.ProductionExpenses = True;
			
			// Receipt.
			If Round(AmountToBeWrittenOff, 2, 1) <> 0 Then
				
				TableRowReceipt = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
				FillPropertyValues(TableRowReceipt, RowTableInventory);
					
				TableRowReceipt.RecordType = AccumulationRecordType.Receipt;
								
				TableRowReceipt.Company = RowTableInventory.CorrOrganization;
				TableRowReceipt.StructuralUnit = RowTableInventory.StructuralUnitCorr;
				TableRowReceipt.GLAccount = RowTableInventory.CorrGLAccount;
				TableRowReceipt.Products = RowTableInventory.ProductsCorr;
				TableRowReceipt.Characteristic = RowTableInventory.CharacteristicCorr;
				TableRowReceipt.Batch = RowTableInventory.BatchCorr;
				TableRowReceipt.Specification = RowTableInventory.SpecificationCorr;
				
				TableRowReceipt.SalesOrder = RowTableInventory.CustomerCorrOrder;
				
				TableRowReceipt.CorrOrganization = RowTableInventory.Company;
				TableRowReceipt.StructuralUnitCorr = RowTableInventory.StructuralUnit;
				TableRowReceipt.CorrGLAccount = RowTableInventory.GLAccount;
				TableRowReceipt.ProductsCorr = RowTableInventory.Products;
				TableRowReceipt.CharacteristicCorr = RowTableInventory.Characteristic;
				TableRowReceipt.BatchCorr = RowTableInventory.Batch;
				TableRowReceipt.SpecificationCorr = RowTableInventory.Specification;
 						
				TableRowReceipt.Amount = AmountToBeWrittenOff;
				TableRowReceipt.Quantity = 0;
					
				TableRowReceipt.GLAccount = RowTableInventory.CorrGLAccount;
				
				// Generate postings.
				If Round(AmountToBeWrittenOff, 2, 1) <> 0 Then
					RowTableAccountingJournalEntries = StructureAdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries.Add();
					FillPropertyValues(RowTableAccountingJournalEntries, TableRowReceipt);
				EndIf;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure DataInitializationByInventory(DocumentRefSubcontractorReport, StructureAdditionalProperties, AssemblyAmount) Export

	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text = 
	"SELECT
	|	ProcesserReportInventory.LineNumber AS LineNumber,
	|	ProcesserReportInventory.Ref.Date AS Period,
	|	&Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	&Company AS CorrOrganization,
	|	ProcesserReportInventory.Ref.Counterparty AS StructuralUnit,
	|	ProcesserReportInventory.Ref.StructuralUnit AS StructuralUnitCorr,
	|	CASE
	|		WHEN &UseStorageBins
	|			THEN ProcesserReportInventory.Ref.Cell
	|		ELSE VALUE(Catalog.Cells.EmptyRef)
	|	END AS Cell,
	|	ProcesserReportInventory.InventoryTransferredGLAccount AS GLAccount,
	|	ProcesserReportInventory.Ref.InventoryGLAccount AS CorrGLAccount,
	|	ProcesserReportInventory.Products AS Products,
	|	ProcesserReportInventory.Ref.Products AS ProductsCorr,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN ProcesserReportInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN ProcesserReportInventory.Ref.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS CharacteristicCorr,
	|	CASE
	|		WHEN &UseBatches
	|			THEN ProcesserReportInventory.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS Batch,
	|	CASE
	|		WHEN &UseBatches
	|			THEN ProcesserReportInventory.Ref.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS BatchCorr,
	|	ProcesserReportInventory.Specification AS Specification,
	|	ProcesserReportInventory.Ref.Specification AS SpecificationCorr,
	|	ProcesserReportInventory.Ref.SalesOrder AS SalesOrder,
	|	ProcesserReportInventory.Ref.SalesOrder AS CustomerCorrOrder,
	|	ProcesserReportInventory.Ref.BasisDocument AS TransmissionOrder,
	|	ProcesserReportInventory.Ref.Counterparty AS Counterparty,
	|	ProcesserReportInventory.Ref.Contract AS Contract,
	|	CASE
	|		WHEN VALUETYPE(ProcesserReportInventory.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN ProcesserReportInventory.Quantity
	|		ELSE ProcesserReportInventory.Quantity * ProcesserReportInventory.MeasurementUnit.Factor
	|	END AS Quantity,
	|	0 AS Amount,
	|	CAST(CASE
	|			WHEN ProcesserReportInventory.Ref.DocumentCurrency = ConstantNationalCurrency.Value
	|				THEN ProcesserReportInventory.Amount * RegExchangeRates.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * RegExchangeRates.Multiplicity)
	|			ELSE ProcesserReportInventory.Amount * ProcesserReportInventory.Ref.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * ProcesserReportInventory.Ref.Multiplicity)
	|		END AS NUMBER(15, 2)) AS SettlementsAmount,
	|	ProcesserReportInventory.Amount AS SettlementsAmountTransferred,
	|	&InventoryDistribution AS ContentOfAccountingRecord
	|INTO TemporaryTableInventory
	|FROM
	|	Document.SubcontractorReport.Inventory AS ProcesserReportInventory
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(
	|				&PointInTime,
	|				Currency IN
	|					(SELECT
	|						ConstantAccountingCurrency.Value
	|					FROM
	|						Constant.PresentationCurrency AS ConstantAccountingCurrency)) AS ManagExchangeRates
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(
	|				&PointInTime,
	|				Currency IN
	|					(SELECT
	|						ConstantNationalCurrency.Value
	|					FROM
	|						Constant.FunctionalCurrency AS ConstantNationalCurrency)) AS RegExchangeRates
	|		ON (TRUE),
	|	Constant.FunctionalCurrency AS ConstantNationalCurrency
	|WHERE
	|	ProcesserReportInventory.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(TableInventory.LineNumber) AS LineNumber,
	|	TableInventory.Period AS Period,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableInventory.Company AS Company,
	|	TableInventory.PlanningPeriod AS PlanningPeriod,
	|	TableInventory.CorrOrganization AS CorrOrganization,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	TableInventory.StructuralUnitCorr AS StructuralUnitCorr,
	|	TableInventory.GLAccount AS GLAccount,
	|	TableInventory.CorrGLAccount AS CorrGLAccount,
	|	TableInventory.Products AS Products,
	|	TableInventory.ProductsCorr AS ProductsCorr,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.CharacteristicCorr AS CharacteristicCorr,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.BatchCorr AS BatchCorr,
	|	TableInventory.Specification AS Specification,
	|	TableInventory.SpecificationCorr AS SpecificationCorr,
	|	CASE
	|		WHEN TableInventory.SalesOrder = VALUE(Document.SalesOrder.EmptyRef)
	|				OR TableInventory.SalesOrder = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE TableInventory.SalesOrder
	|	END AS SalesOrder,
	|	CASE
	|		WHEN TableInventory.CustomerCorrOrder = VALUE(Document.SalesOrder.EmptyRef)
	|				OR TableInventory.CustomerCorrOrder = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE TableInventory.CustomerCorrOrder
	|	END AS CustomerCorrOrder,
	|	TableInventory.CorrGLAccount AS AccountDr,
	|	TableInventory.GLAccount AS AccountCr,
	|	TableInventory.ContentOfAccountingRecord AS Content,
	|	TableInventory.ContentOfAccountingRecord AS ContentOfAccountingRecord,
	|	FALSE AS ProductionExpenses,
	|	SUM(TableInventory.Quantity) AS Quantity,
	|	0 AS Amount
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|
	|GROUP BY
	|	TableInventory.Period,
	|	TableInventory.Company,
	|	TableInventory.PlanningPeriod,
	|	TableInventory.CorrOrganization,
	|	TableInventory.StructuralUnit,
	|	TableInventory.StructuralUnitCorr,
	|	TableInventory.GLAccount,
	|	TableInventory.CorrGLAccount,
	|	TableInventory.Products,
	|	TableInventory.ProductsCorr,
	|	TableInventory.Characteristic,
	|	TableInventory.CharacteristicCorr,
	|	TableInventory.Batch,
	|	TableInventory.BatchCorr,
	|	TableInventory.Specification,
	|	TableInventory.SpecificationCorr,
	|	TableInventory.SalesOrder,
	|	TableInventory.CustomerCorrOrder,
	|	TableInventory.ContentOfAccountingRecord,
	|	TableInventory.CorrGLAccount,
	|	TableInventory.GLAccount,
	|	TableInventory.ContentOfAccountingRecord
	|
	|ORDER BY
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(TableStockTransferredToThirdParties.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableStockTransferredToThirdParties.Period AS Period,
	|	TableStockTransferredToThirdParties.Company AS Company,
	|	TableStockTransferredToThirdParties.Products AS Products,
	|	TableStockTransferredToThirdParties.Characteristic AS Characteristic,
	|	TableStockTransferredToThirdParties.Batch AS Batch,
	|	TableStockTransferredToThirdParties.Counterparty AS Counterparty,
	|	TableStockTransferredToThirdParties.Contract AS Contract,
	|	CASE
	|		WHEN TableStockTransferredToThirdParties.TransmissionOrder <> VALUE(Document.PurchaseOrder.EmptyRef)
	|			THEN TableStockTransferredToThirdParties.TransmissionOrder
	|		ELSE UNDEFINED
	|	END AS Order,
	|	SUM(TableStockTransferredToThirdParties.Quantity) AS Quantity
	|FROM
	|	TemporaryTableInventory AS TableStockTransferredToThirdParties
	|
	|GROUP BY
	|	TableStockTransferredToThirdParties.Period,
	|	TableStockTransferredToThirdParties.Company,
	|	TableStockTransferredToThirdParties.Products,
	|	TableStockTransferredToThirdParties.Characteristic,
	|	TableStockTransferredToThirdParties.Batch,
	|	TableStockTransferredToThirdParties.Counterparty,
	|	TableStockTransferredToThirdParties.Contract,
	|	CASE
	|		WHEN TableStockTransferredToThirdParties.TransmissionOrder <> VALUE(Document.PurchaseOrder.EmptyRef)
	|			THEN TableStockTransferredToThirdParties.TransmissionOrder
	|		ELSE UNDEFINED
	|	END";
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();
	
	Query.SetParameter("Ref", DocumentRefSubcontractorReport);
	Query.SetParameter("ControlTime", StructureAdditionalProperties.ForPosting.ControlTime);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("UseCharacteristics", StructureAdditionalProperties.AccountingPolicy.UseCharacteristics);
	Query.SetParameter("UseBatches", StructureAdditionalProperties.AccountingPolicy.UseBatches);
	Query.SetParameter("UseStorageBins", StructureAdditionalProperties.AccountingPolicy.UseStorageBins);
	Query.SetParameter("InventoryDistribution", NStr("en = 'Inventory allocation'", MainLanguageCode));
	
	ResultsArray = Query.ExecuteBatch();
	
	// Determine table for inventory accounting.
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryInventory", ResultsArray[1].Unload());
	
	// Generate table for inventory accounting.
	GenerateTableInventoryInventory(DocumentRefSubcontractorReport, StructureAdditionalProperties, AssemblyAmount);
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableStockTransferredToThirdParties", ResultsArray[2].Unload());
	
EndProcedure

#EndRegion

#Region Products

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventoryProducts(DocumentRefSubcontractorReport, StructureAdditionalProperties, AssemblyAmount)
	
	For n = 0 To StructureAdditionalProperties.TableForRegisterRecords.TableInventoryGoods.Count() - 1 Do
		
		RowTableInventoryProducts = StructureAdditionalProperties.TableForRegisterRecords.TableInventoryGoods[n];
		
		// Generate products release in terms of quantity. If sales order is specified - customer
		// customised if not - then for an empty order.
		TableRowReceipt = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
		FillPropertyValues(TableRowReceipt, RowTableInventoryProducts);
		
		// If production order is filled in and there is no
		// customer, check whether there are located sales orders in the order to vendor.
		If Not ValueIsFilled(RowTableInventoryProducts.SalesOrder) 
		   AND ValueIsFilled(RowTableInventoryProducts.PurchaseOrder) Then
		 
			// Then there is a receipt either to available balance, or to purchase orders placed in order.
			OutputCost = AssemblyAmount;
			OutputQuantity = RowTableInventoryProducts.Quantity;
			
			OutputAmountToReserve = StructureAdditionalProperties.TableForRegisterRecords.TableBackorders.Total("Quantity");

			If OutputQuantity = OutputAmountToReserve Then
				OutputCostInReserve = OutputCost;
			Else
				OutputCostInReserve = Round(OutputCost * OutputAmountToReserve / OutputQuantity, 2, 1);
			EndIf;

			If OutputAmountToReserve > 0 Then	

				TotalToWriteOffByOrder = 0;
					
				For IndexOf = 0 To StructureAdditionalProperties.TableForRegisterRecords.TableBackorders.Count() - 1 Do

					StringTablePlacedOrders = StructureAdditionalProperties.TableForRegisterRecords.TableBackorders[IndexOf];
						
					AmountToBeWrittenOffByOrder = Round(OutputCostInReserve * StringTablePlacedOrders.Quantity / OutputAmountToReserve, 2, 1);
					TotalToWriteOffByOrder = TotalToWriteOffByOrder + AmountToBeWrittenOffByOrder;
						
					If IndexOf = StructureAdditionalProperties.TableForRegisterRecords.TableBackorders.Count() - 1 Then // It is the last string, it is required to correct amount.
						AmountToBeWrittenOffByOrder = AmountToBeWrittenOffByOrder + (OutputCostInReserve - TotalToWriteOffByOrder);
					EndIf;

					TableRowExpense = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
					FillPropertyValues(TableRowExpense, RowTableInventoryProducts);
					
					TableRowExpense.RecordType = AccumulationRecordType.Expense;
					
					TableRowExpense.CorrOrganization = RowTableInventoryProducts.Company;
					TableRowExpense.StructuralUnitCorr = RowTableInventoryProducts.StructuralUnit;
					TableRowExpense.CorrGLAccount = RowTableInventoryProducts.GLAccount;
					TableRowExpense.ProductsCorr = RowTableInventoryProducts.Products;
					TableRowExpense.CharacteristicCorr = RowTableInventoryProducts.Characteristic;
					TableRowExpense.BatchCorr = RowTableInventoryProducts.Batch;
					TableRowExpense.SpecificationCorr = RowTableInventoryProducts.Specification;
 									
					TableRowExpense.CustomerCorrOrder = StringTablePlacedOrders.SalesOrder;
					TableRowExpense.Quantity = StringTablePlacedOrders.Quantity;
					TableRowExpense.Amount = AmountToBeWrittenOffByOrder;
					
					TableRowReceipt = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
					FillPropertyValues(TableRowReceipt, RowTableInventoryProducts);
									
					TableRowReceipt.RecordType = AccumulationRecordType.Receipt;
									
					TableRowReceipt.SalesOrder = StringTablePlacedOrders.SalesOrder;
									
					TableRowExpense.CorrOrganization = RowTableInventoryProducts.Company;
					TableRowExpense.StructuralUnitCorr = RowTableInventoryProducts.StructuralUnit;
					TableRowExpense.CorrGLAccount = RowTableInventoryProducts.GLAccount;
					TableRowExpense.ProductsCorr = RowTableInventoryProducts.Products;
					TableRowExpense.CharacteristicCorr = RowTableInventoryProducts.Characteristic;
					TableRowExpense.BatchCorr = RowTableInventoryProducts.Batch;
					TableRowExpense.SpecificationCorr = RowTableInventoryProducts.Specification;

					TableRowReceipt.CustomerCorrOrder = RowTableInventoryProducts.SalesOrder;
					TableRowReceipt.Quantity = StringTablePlacedOrders.Quantity;
					TableRowReceipt.Amount = AmountToBeWrittenOffByOrder;
					
				EndDo;
			
			EndIf;

		EndIf;

	EndDo;

EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableBackorders(DocumentRefSubcontractorReport, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	// Set exclusive lock of the controlled orders placement.
	Query.Text = 
	"SELECT
	|	TableProduction.Company AS Company,
	|	TableProduction.Products AS Products,
	|	TableProduction.Characteristic AS Characteristic,
	|	TableProduction.SupplySource AS SupplySource
	|FROM
	|	TemporaryTableProduction AS TableProduction
	|WHERE
	|	TableProduction.SupplySource <> Undefined
	|
	|GROUP BY
	|	TableProduction.Company,
	|	TableProduction.Products,
	|	TableProduction.Characteristic,
	|	TableProduction.SupplySource";
	
	QueryResult = Query.Execute();
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.Backorders");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;

	For Each ColumnQueryResult In QueryResult.Columns Do
		LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
	EndDo;
	Block.Lock();
	
	// Receive balance.
	Query.Text = 	
	"SELECT
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableProduction.Period AS Period,
	|	TableProduction.Company AS Company,
	|	BackordersBalances.SalesOrder AS SalesOrder,
	|	TableProduction.Products AS Products,
	|	TableProduction.Characteristic AS Characteristic,
	|	TableProduction.SupplySource AS SupplySource,
	|	CASE
	|		WHEN TableProduction.Quantity > ISNULL(BackordersBalances.Quantity, 0)
	|			THEN ISNULL(BackordersBalances.Quantity, 0)
	|		WHEN TableProduction.Quantity <= ISNULL(BackordersBalances.Quantity, 0)
	|			THEN TableProduction.Quantity
	|	END AS Quantity
	|FROM
	|	TemporaryTableProduction AS TableProduction
	|		LEFT JOIN (SELECT
	|			BackordersBalances.Company AS Company,
	|			BackordersBalances.Products AS Products,
	|			BackordersBalances.Characteristic AS Characteristic,
	|			BackordersBalances.SalesOrder AS SalesOrder,
	|			BackordersBalances.SupplySource AS SupplySource,
	|			SUM(BackordersBalances.QuantityBalance) AS Quantity
	|		FROM
	|			(SELECT
	|				BackordersBalances.Company AS Company,
	|				BackordersBalances.Products AS Products,
	|				BackordersBalances.Characteristic AS Characteristic,
	|				BackordersBalances.SalesOrder AS SalesOrder,
	|				BackordersBalances.SupplySource AS SupplySource,
	|				BackordersBalances.QuantityBalance AS QuantityBalance
	|			FROM
	|				AccumulationRegister.Backorders.Balance(
	|						&ControlTime,
	|						(Company, Products, Characteristic, SupplySource) In
	|							(SELECT
	|								TableProduction.Company AS Company,
	|								TableProduction.Products AS Products,
	|								TableProduction.Characteristic AS Characteristic,
	|								TableProduction.SupplySource AS SupplySource
	|							FROM
	|								TemporaryTableProduction AS TableProduction
	|							WHERE
	|								TableProduction.SupplySource <> UNDEFINED)) AS BackordersBalances
			
	|			UNION ALL
			
	|			SELECT
	|				DocumentRegisterRecordsBackorders.Company,
	|				DocumentRegisterRecordsBackorders.Products,
	|				DocumentRegisterRecordsBackorders.Characteristic,
	|				DocumentRegisterRecordsBackorders.SalesOrder,
	|				DocumentRegisterRecordsBackorders.SupplySource,
	|				CASE
	|					WHEN DocumentRegisterRecordsBackorders.RecordType = VALUE(AccumulationRecordType.Expense)
	|						THEN ISNULL(DocumentRegisterRecordsBackorders.Quantity, 0)
	|					ELSE -ISNULL(DocumentRegisterRecordsBackorders.Quantity, 0)
	|				END
	|			FROM
	|				AccumulationRegister.Backorders AS DocumentRegisterRecordsBackorders
	|			WHERE
	|				DocumentRegisterRecordsBackorders.Recorder = &Ref
	|				AND DocumentRegisterRecordsBackorders.Period <= &ControlPeriod) AS BackordersBalances
		
	|		GROUP BY
	|			BackordersBalances.Company,
	|			BackordersBalances.Products,
	|			BackordersBalances.Characteristic,
	|			BackordersBalances.SalesOrder,
	|			BackordersBalances.SupplySource) AS BackordersBalances
	|		ON TableProduction.Company = BackordersBalances.Company
	|			AND TableProduction.Products = BackordersBalances.Products
	|			AND TableProduction.Characteristic = BackordersBalances.Characteristic
	|			AND TableProduction.SupplySource = BackordersBalances.SupplySource
	|WHERE
	|	TableProduction.SupplySource <> UNDEFINED
	|	AND BackordersBalances.SalesOrder IS Not NULL ";
	
	Query.SetParameter("Ref", DocumentRefSubcontractorReport);
	Query.SetParameter("ControlTime", StructureAdditionalProperties.ForPosting.ControlTime);
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.ControlPeriod);
	
	QueryResult = Query.Execute();

	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableBackorders", QueryResult.Unload());
	
EndProcedure

#EndRegion

#Region AccountsPayable

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableAccountsPayable(DocumentRefPurchaseInvoice, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();
	
	Query.SetParameter("Ref", DocumentRefPurchaseInvoice);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("AppearenceOfLiabilityToVendor", NStr("en = 'Accounts payable recognition'", MainLanguageCode));
	Query.SetParameter("AdvanceCredit", NStr("en = 'Advance payment clearing'", MainLanguageCode));
	Query.SetParameter("ExchangeDifference", NStr("en = 'Foreign currency exchange gains and losses'", MainLanguageCode));
	
	Query.Text =
	"SELECT
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	DocumentTable.Period AS Date,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.Counterparty AS Counterparty,
	|	DocumentTable.DoOperationsByDocuments AS DoOperationsByDocuments,
	|	DocumentTable.GLAccountVendorSettlements AS GLAccount,
	|	DocumentTable.Contract AS Contract,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByDocuments
	|			THEN DocumentTable.Document
	|		ELSE UNDEFINED
	|	END AS Document,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByOrders
	|			THEN DocumentTable.Order
	|		ELSE VALUE(Document.PurchaseOrder.EmptyRef)
	|	END AS Order,
	|	DocumentTable.SettlementsCurrency AS Currency,
	|	VALUE(Enum.SettlementsTypes.Debt) AS SettlementsType,
	|	SUM(DocumentTable.Amount) AS Amount,
	|	SUM(DocumentTable.AmountCur) AS AmountCur,
	|	SUM(DocumentTable.Amount) AS AmountForBalance,
	|	SUM(DocumentTable.AmountCur) AS AmountCurForBalance,
	|	CAST(&AppearenceOfLiabilityToVendor AS STRING(100)) AS ContentOfAccountingRecord,
	|	SUM(DocumentTable.Amount) AS AmountForPayment,
	|	SUM(DocumentTable.AmountCur) AS AmountForPaymentCur
	|INTO TemporaryTableAccountsPayable
	|FROM
	|	TemporaryTableForCalculationOfReserves AS DocumentTable
	|
	|GROUP BY
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	DocumentTable.Counterparty,
	|	DocumentTable.DoOperationsByDocuments,
	|	DocumentTable.Contract,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByDocuments
	|			THEN DocumentTable.Document
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByOrders
	|			THEN DocumentTable.Order
	|		ELSE VALUE(Document.PurchaseOrder.EmptyRef)
	|	END,
	|	DocumentTable.SettlementsCurrency,
	|	DocumentTable.GLAccountVendorSettlements
	|
	|UNION ALL
	|
	|SELECT
	|	VALUE(AccumulationRecordType.Receipt),
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	DocumentTable.Counterparty,
	|	DocumentTable.DoOperationsByDocuments,
	|	DocumentTable.VendorAdvancesGLAccount,
	|	DocumentTable.Contract,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByDocuments
	|			THEN DocumentTable.Document
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByOrders
	|			THEN DocumentTable.Order
	|		ELSE VALUE(Document.PurchaseOrder.EmptyRef)
	|	END,
	|	DocumentTable.SettlementsCurrency,
	|	DocumentTable.SettlementsType,
	|	SUM(DocumentTable.Amount),
	|	SUM(DocumentTable.AmountCur),
	|	SUM(DocumentTable.Amount),
	|	SUM(DocumentTable.AmountCur),
	|	CAST(&AdvanceCredit AS STRING(100)),
	|	SUM(DocumentTable.Amount),
	|	SUM(DocumentTable.AmountCur)
	|FROM
	|	TemporaryTablePrepayment AS DocumentTable
	|
	|GROUP BY
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	DocumentTable.Counterparty,
	|	DocumentTable.DoOperationsByDocuments,
	|	DocumentTable.Contract,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByDocuments
	|			THEN DocumentTable.Document
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByOrders
	|			THEN DocumentTable.Order
	|		ELSE VALUE(Document.PurchaseOrder.EmptyRef)
	|	END,
	|	DocumentTable.SettlementsType,
	|	DocumentTable.SettlementsCurrency,
	|	DocumentTable.VendorAdvancesGLAccount
	|
	|UNION ALL
	|
	|SELECT
	|	VALUE(AccumulationRecordType.Expense),
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	DocumentTable.Counterparty,
	|	DocumentTable.DoOperationsByDocuments,
	|	DocumentTable.GLAccountVendorSettlements,
	|	DocumentTable.Contract,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByDocuments
	|			THEN DocumentTable.DocumentWhere
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByOrders
	|			THEN DocumentTable.Order
	|		ELSE VALUE(Document.PurchaseOrder.EmptyRef)
	|	END,
	|	DocumentTable.SettlementsCurrency,
	|	DocumentTable.SettlemensTypeWhere,
	|	SUM(DocumentTable.Amount),
	|	SUM(DocumentTable.AmountCur),
	|	-SUM(DocumentTable.Amount),
	|	-SUM(DocumentTable.AmountCur),
	|	CAST(&AdvanceCredit AS STRING(100)),
	|	SUM(DocumentTable.Amount),
	|	SUM(DocumentTable.AmountCur)
	|FROM
	|	TemporaryTablePrepayment AS DocumentTable
	|
	|GROUP BY
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	DocumentTable.Counterparty,
	|	DocumentTable.DoOperationsByDocuments,
	|	DocumentTable.Contract,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByDocuments
	|			THEN DocumentTable.DocumentWhere
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByOrders
	|			THEN DocumentTable.Order
	|		ELSE VALUE(Document.PurchaseOrder.EmptyRef)
	|	END,
	|	DocumentTable.GLAccountVendorSettlements,
	|	DocumentTable.SettlementsCurrency,
	|	DocumentTable.SettlemensTypeWhere
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
	|	TemporaryTableAccountsPayable AS TemporaryTableAccountsPayable";
	
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
	Query.Text = DriveServer.GetQueryTextExchangeRatesDifferencesAccountsPayable(Query.TempTablesManager, True, QueryNumber);
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountsPayable", ResultsArray[QueryNumber].Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableIncomeAndExpenses(DocumentRefSubcontractorReport, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.Text =
	"SELECT
	|	1 AS LineNumber,
	|	DocumentTable.Date AS Period,
	|	DocumentTable.Company AS Company,
	|	UNDEFINED AS StructuralUnit,
	|	VALUE(Catalog.LinesOfBusiness.Other) AS BusinessLine,
	|	UNDEFINED AS SalesOrder,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN &NegativeExchangeDifferenceAccountOfAccounting
	|		ELSE &PositiveExchangeDifferenceGLAccount
	|	END AS GLAccount,
	|	&ExchangeDifference AS ContentOfAccountingRecord,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN 0
	|		ELSE -DocumentTable.AmountOfExchangeDifferences
	|	END AS AmountIncome,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN DocumentTable.AmountOfExchangeDifferences
	|		ELSE 0
	|	END AS AmountExpense,
	|	FALSE AS OfflineRecord
	|FROM
	|	(SELECT
	|		TableOfExchangeRateDifferencesAccountsPayable.Date AS Date,
	|		TableOfExchangeRateDifferencesAccountsPayable.Company AS Company,
	|		SUM(TableOfExchangeRateDifferencesAccountsPayable.AmountOfExchangeDifferences) AS AmountOfExchangeDifferences
	|	FROM
	|		(SELECT
	|			DocumentTable.Date AS Date,
	|			DocumentTable.Company AS Company,
	|			DocumentTable.AmountOfExchangeDifferences AS AmountOfExchangeDifferences
	|		FROM
	|			TemporaryTableOfExchangeRateDifferencesAccountsPayable AS DocumentTable
	|		WHERE
	|			DocumentTable.SettlementsType = VALUE(Enum.SettlementsTypes.Debt)
	|		
	|		UNION ALL
	|		
	|		SELECT
	|			DocumentTable.Date,
	|			DocumentTable.Company,
	|			DocumentTable.AmountOfExchangeDifferences
	|		FROM
	|			TemporaryTableOfExchangeRateDifferencesAccountsPayable AS DocumentTable
	|		WHERE
	|			DocumentTable.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)) AS TableOfExchangeRateDifferencesAccountsPayable
	|	
	|	GROUP BY
	|		TableOfExchangeRateDifferencesAccountsPayable.Date,
	|		TableOfExchangeRateDifferencesAccountsPayable.Company
	|	
	|	HAVING
	|		(SUM(TableOfExchangeRateDifferencesAccountsPayable.AmountOfExchangeDifferences) >= 0.005
	|			OR SUM(TableOfExchangeRateDifferencesAccountsPayable.AmountOfExchangeDifferences) <= -0.005)) AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	OfflineRecords.LineNumber,
	|	OfflineRecords.Period,
	|	OfflineRecords.Company,
	|	OfflineRecords.StructuralUnit,
	|	OfflineRecords.BusinessLine,
	|	OfflineRecords.SalesOrder,
	|	OfflineRecords.GLAccount,
	|	OfflineRecords.ContentOfAccountingRecord,
	|	OfflineRecords.AmountIncome,
	|	OfflineRecords.AmountExpense,
	|	OfflineRecords.OfflineRecord
	|FROM
	|	AccumulationRegister.IncomeAndExpenses AS OfflineRecords
	|WHERE
	|	OfflineRecords.Recorder = &Ref
	|	AND OfflineRecords.OfflineRecord
	|
	|ORDER BY
	|	LineNumber";
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();
	
	Query.SetParameter("Ref",											DocumentRefSubcontractorReport);
	Query.SetParameter("Company",										StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PointInTime",									New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("PositiveExchangeDifferenceGLAccount",			Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeGain"));
	Query.SetParameter("NegativeExchangeDifferenceAccountOfAccounting",	Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeLoss"));
	Query.SetParameter("ExchangeDifference",							NStr("en = 'Foreign currency exchange gains and losses'", MainLanguageCode));
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpenses", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableIncomeAndExpensesRetained(DocumentRefSubcontractorReport, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefSubcontractorReport);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("IncomeAndExpensesAccountingCashMethod", StructureAdditionalProperties.AccountingPolicy.IncomeAndExpensesAccountingCashMethod);
	
	Query.Text =
	"SELECT
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Period AS Period,
	|	DocumentTable.Company AS Company,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByDocuments
	|			THEN &Ref
	|		ELSE UNDEFINED
	|	END AS Document,
	|	DocumentTable.BusinessLine AS BusinessLine,
	|	DocumentTable.Amount - DocumentTable.VATAmount AS AmountExpense
	|FROM
	|	TemporaryTableForCalculationOfReserves AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|
	|ORDER BY
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DocumentTable.Company AS Company,
	|	SUM(DocumentTable.Amount) AS AmountToBeWrittenOff
	|FROM
	|	TemporaryTablePrepayment AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|
	|GROUP BY
	|	DocumentTable.Company
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Item AS Item
	|FROM
	|	TemporaryTablePrepayment AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|
	|ORDER BY
	|	LineNumber";
	
	ResultsArray = Query.ExecuteBatch();
	
	TableInventoryIncomeAndExpensesRetained = ResultsArray[0].Unload();
	SelectionOfQueryResult = ResultsArray[1].Select();
	
	TablePrepaymentIncomeAndExpensesRetained = TableInventoryIncomeAndExpensesRetained.Copy();
	TablePrepaymentIncomeAndExpensesRetained.Clear();
	
	If SelectionOfQueryResult.Next() Then
		AmountToBeWrittenOff = SelectionOfQueryResult.AmountToBeWrittenOff;
		For Each StringInventoryIncomeAndExpensesRetained In TableInventoryIncomeAndExpensesRetained Do
			If AmountToBeWrittenOff = 0 Then
				Continue
			ElsIf StringInventoryIncomeAndExpensesRetained.AmountExpense <= AmountToBeWrittenOff Then
				StringPrepaymentIncomeAndExpensesRetained = TablePrepaymentIncomeAndExpensesRetained.Add();
				FillPropertyValues(StringPrepaymentIncomeAndExpensesRetained, StringInventoryIncomeAndExpensesRetained);
				AmountToBeWrittenOff = AmountToBeWrittenOff - StringInventoryIncomeAndExpensesRetained.AmountExpense;
			ElsIf StringInventoryIncomeAndExpensesRetained.AmountExpense > AmountToBeWrittenOff Then
				StringPrepaymentIncomeAndExpensesRetained = TablePrepaymentIncomeAndExpensesRetained.Add();
				FillPropertyValues(StringPrepaymentIncomeAndExpensesRetained, StringInventoryIncomeAndExpensesRetained);
				StringPrepaymentIncomeAndExpensesRetained.AmountExpense = AmountToBeWrittenOff;
				AmountToBeWrittenOff = 0;
			EndIf;
		EndDo;
	EndIf;
	
	For Each StringPrepaymentIncomeAndExpensesRetained In TablePrepaymentIncomeAndExpensesRetained Do
		StringInventoryIncomeAndExpensesRetained = TableInventoryIncomeAndExpensesRetained.Add();
		FillPropertyValues(StringInventoryIncomeAndExpensesRetained, StringPrepaymentIncomeAndExpensesRetained);
		StringInventoryIncomeAndExpensesRetained.RecordType = AccumulationRecordType.Expense;
	EndDo;
	
	SelectionOfQueryResult = ResultsArray[2].Select();
	
	If SelectionOfQueryResult.Next() Then
		Item = SelectionOfQueryResult.Item;
	Else
		Item = Catalogs.CashFlowItems.PaymentToVendor;
	EndIf;
	
	Query.Text =
	"SELECT
	|	Table.LineNumber AS LineNumber,
	|	Table.Period AS Period,
	|	Table.Company AS Company,
	|	Table.Document AS Document,
	|	&Item AS Item,
	|	Table.BusinessLine AS BusinessLine,
	|	Table.AmountExpense AS AmountExpense
	|INTO TemporaryTablePrepaidIncomeAndExpensesRetained
	|FROM
	|	&Table AS Table";
	Query.SetParameter("Table", TablePrepaymentIncomeAndExpensesRetained);
	Query.SetParameter("Item", Item);
	
	Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpensesRetained", TableInventoryIncomeAndExpensesRetained);
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableUnallocatedExpenses(DocumentRefSubcontractorReport, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("IncomeAndExpensesAccountingCashMethod", StructureAdditionalProperties.AccountingPolicy.IncomeAndExpensesAccountingCashMethod);
	
	Query.Text =
	"SELECT
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	DocumentTable.Period AS Period,
	|	DocumentTable.Company AS Company,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByDocuments
	|			THEN DocumentTable.Document
	|		ELSE UNDEFINED
	|	END AS Document,
	|	DocumentTable.Item AS Item,
	|	DocumentTable.Amount AS AmountExpense
	|FROM
	|	TemporaryTablePrepayment AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableUnallocatedExpenses", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableIncomeAndExpensesCashMethod(DocumentRefSubcontractorReport, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefSubcontractorReport);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("IncomeAndExpensesAccountingCashMethod", StructureAdditionalProperties.AccountingPolicy.IncomeAndExpensesAccountingCashMethod);
	
	Query.Text =
	"SELECT
	|	DocumentTable.DocumentDate AS Period,
	|	DocumentTable.Company AS Company,
	|	UNDEFINED AS BusinessLine,
	|	DocumentTable.Item AS Item,
	|	-DocumentTable.Amount AS AmountExpense
	|FROM
	|	TemporaryTablePrepayment AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|
	|UNION ALL
	|
	|SELECT
	|	Table.Period,
	|	Table.Company,
	|	Table.BusinessLine,
	|	Table.Item,
	|	Table.AmountExpense
	|FROM
	|	TemporaryTablePrepaidIncomeAndExpensesRetained AS Table";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpensesCashMethod", QueryResult.Unload());
	
EndProcedure

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure DataInitializationAccountsPayable(DocumentRefSubcontractorReport, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	SubcontractorReportCosts.Date AS Period,
	|	1 AS LineNumber,
	|	&Company AS Company,
	|	SubcontractorReportCosts.Counterparty AS Counterparty,
	|	SubcontractorReportCosts.Counterparty.DoOperationsByContracts AS DoOperationsByContracts,
	|	SubcontractorReportCosts.Counterparty.DoOperationsByDocuments AS DoOperationsByDocuments,
	|	SubcontractorReportCosts.Counterparty.DoOperationsByOrders AS DoOperationsByOrders,
	|	SubcontractorReportCosts.Counterparty.GLAccountVendorSettlements AS GLAccountVendorSettlements,
	|	SubcontractorReportCosts.Contract AS Contract,
	|	SubcontractorReportCosts.Expense.ExpensesGLAccount AS GLAccount,
	|	SubcontractorReportCosts.Expense.BusinessLine AS BusinessLine,
	|	SubcontractorReportCosts.Contract.SettlementsCurrency AS SettlementsCurrency,
	|	&Ref AS Document,
	|	SubcontractorReportCosts.BasisDocument AS Order,
	|	CAST(CASE
	|			WHEN SubcontractorReportCosts.IncludeVATInPrice
	|				THEN 0
	|			ELSE CASE
	|					WHEN SubcontractorReportCosts.DocumentCurrency = ConstantNationalCurrency.Value
	|						THEN SubcontractorReportCosts.VATAmount * RegExchangeRates.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * RegExchangeRates.Multiplicity)
	|					ELSE SubcontractorReportCosts.VATAmount * SubcontractorReportCosts.Ref.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * SubcontractorReportCosts.Ref.Multiplicity)
	|				END
	|		END AS NUMBER(15, 2)) AS VATAmount,
	|	CAST(CASE
	|			WHEN SubcontractorReportCosts.DocumentCurrency = ConstantNationalCurrency.Value
	|				THEN SubcontractorReportCosts.Total * RegExchangeRates.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * RegExchangeRates.Multiplicity)
	|			ELSE SubcontractorReportCosts.Total * SubcontractorReportCosts.Ref.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * SubcontractorReportCosts.Ref.Multiplicity)
	|		END AS NUMBER(15, 2)) AS Amount,
	|	CAST(CASE
	|			WHEN SubcontractorReportCosts.IncludeVATInPrice
	|				THEN 0
	|			ELSE CASE
	|					WHEN SubcontractorReportCosts.DocumentCurrency = ConstantNationalCurrency.Value
	|						THEN SubcontractorReportCosts.VATAmount * RegExchangeRates.ExchangeRate * SubcontractorReportCosts.Ref.Multiplicity / (SubcontractorReportCosts.Ref.ExchangeRate * RegExchangeRates.Multiplicity)
	|					ELSE SubcontractorReportCosts.VATAmount
	|				END
	|		END AS NUMBER(15, 2)) AS VATAmountCur,
	|	CAST(CASE
	|			WHEN SubcontractorReportCosts.DocumentCurrency = ConstantNationalCurrency.Value
	|				THEN SubcontractorReportCosts.Total * RegExchangeRates.ExchangeRate * SubcontractorReportCosts.Ref.Multiplicity / (SubcontractorReportCosts.Ref.ExchangeRate * RegExchangeRates.Multiplicity)
	|			ELSE SubcontractorReportCosts.Total
	|		END AS NUMBER(15, 2)) AS AmountCur,
	|	SubcontractorReportCosts.VATInputGLAccount AS VATInputGLAccount
	|INTO TemporaryTableForCalculationOfReserves
	|FROM
	|	Document.SubcontractorReport AS SubcontractorReportCosts
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(
	|				&PointInTime,
	|				Currency IN
	|					(SELECT
	|						ConstantAccountingCurrency.Value
	|					FROM
	|						Constant.PresentationCurrency AS ConstantAccountingCurrency)) AS ManagExchangeRates
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(
	|				&PointInTime,
	|				Currency IN
	|					(SELECT
	|						ConstantNationalCurrency.Value
	|					FROM
	|						Constant.FunctionalCurrency AS ConstantNationalCurrency)) AS RegExchangeRates
	|		ON (TRUE),
	|	Constant.FunctionalCurrency AS ConstantNationalCurrency
	|WHERE
	|	SubcontractorReportCosts.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MAX(DocumentTable.LineNumber) AS LineNumber,
	|	DocumentTable.Ref.Date AS Period,
	|	&Company AS Company,
	|	DocumentTable.Ref.Counterparty AS Counterparty,
	|	DocumentTable.Ref.Counterparty.DoOperationsByContracts AS DoOperationsByContracts,
	|	DocumentTable.Ref.Counterparty.DoOperationsByDocuments AS DoOperationsByDocuments,
	|	DocumentTable.Ref.Counterparty.DoOperationsByOrders AS DoOperationsByOrders,
	|	DocumentTable.Ref.Counterparty.GLAccountCustomerSettlements AS GLAccountCustomerSettlements,
	|	DocumentTable.Ref.Counterparty.CustomerAdvancesGLAccount AS CustomerAdvancesGLAccount,
	|	DocumentTable.Ref.Counterparty.GLAccountVendorSettlements AS GLAccountVendorSettlements,
	|	DocumentTable.Ref.Counterparty.VendorAdvancesGLAccount AS VendorAdvancesGLAccount,
	|	DocumentTable.Ref.Contract AS Contract,
	|	DocumentTable.Ref.Contract.SettlementsCurrency AS SettlementsCurrency,
	|	DocumentTable.Ref.BasisDocument AS Order,
	|	VALUE(Catalog.LinesOfBusiness.Other) AS BusinessLineSales,
	|	VALUE(Enum.SettlementsTypes.Advance) AS SettlementsType,
	|	VALUE(Enum.SettlementsTypes.Debt) AS SettlemensTypeWhere,
	|	&Ref AS DocumentWhere,
	|	DocumentTable.Document AS Document,
	|	CASE
	|		WHEN NOT DocumentTable.Ref.Counterparty.DoOperationsByDocuments
	|				OR VALUETYPE(DocumentTable.Document) = TYPE(Document.ExpenseReport)
	|				OR VALUETYPE(DocumentTable.Document) = TYPE(Document.ArApAdjustments)
	|			THEN VALUE(Catalog.CashFlowItems.PaymentToVendor)
	|		ELSE DocumentTable.Document.Item
	|	END AS Item,
	|	CASE
	|		WHEN DocumentTable.Ref.Counterparty.DoOperationsByDocuments
	|			THEN DocumentTable.Document.Date
	|		ELSE DocumentTable.Ref.Date
	|	END AS DocumentDate,
	|	SUM(CAST(DocumentTable.SettlementsAmount * DocumentTable.Ref.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * DocumentTable.Ref.Multiplicity) AS NUMBER(15, 2))) AS Amount,
	|	SUM(DocumentTable.SettlementsAmount) AS AmountCur
	|INTO TemporaryTablePrepayment
	|FROM
	|	Document.SubcontractorReport.Prepayment AS DocumentTable
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(
	|				&PointInTime,
	|				Currency IN
	|					(SELECT
	|						ConstantAccountingCurrency.Value
	|					FROM
	|						Constant.PresentationCurrency AS ConstantAccountingCurrency)) AS AccountingExchangeRatesSliceLast
	|		ON (TRUE)
	|WHERE
	|	DocumentTable.Ref = &Ref
	|
	|GROUP BY
	|	DocumentTable.Ref,
	|	DocumentTable.Document,
	|	DocumentTable.Ref.Date,
	|	DocumentTable.Ref.Counterparty,
	|	DocumentTable.Ref.Contract,
	|	DocumentTable.Ref.BasisDocument,
	|	DocumentTable.Ref.Contract.SettlementsCurrency,
	|	DocumentTable.Ref.Counterparty.GLAccountCustomerSettlements,
	|	DocumentTable.Ref.Counterparty.CustomerAdvancesGLAccount,
	|	DocumentTable.Ref.Counterparty.GLAccountVendorSettlements,
	|	DocumentTable.Ref.Counterparty.VendorAdvancesGLAccount,
	|	CASE
	|		WHEN NOT DocumentTable.Ref.Counterparty.DoOperationsByDocuments
	|				OR VALUETYPE(DocumentTable.Document) = TYPE(Document.ExpenseReport)
	|				OR VALUETYPE(DocumentTable.Document) = TYPE(Document.ArApAdjustments)
	|			THEN VALUE(Catalog.CashFlowItems.PaymentToVendor)
	|		ELSE DocumentTable.Document.Item
	|	END,
	|	CASE
	|		WHEN DocumentTable.Ref.Counterparty.DoOperationsByDocuments
	|			THEN DocumentTable.Document.Date
	|		ELSE DocumentTable.Ref.Date
	|	END,
	|	DocumentTable.Ref.Counterparty.DoOperationsByContracts,
	|	DocumentTable.Ref.Counterparty.DoOperationsByDocuments,
	|	DocumentTable.Ref.Counterparty.DoOperationsByOrders";
	
	Query.SetParameter("Ref", DocumentRefSubcontractorReport);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	
	Query.ExecuteBatch();
	
	GenerateTableAccountsPayable(DocumentRefSubcontractorReport, StructureAdditionalProperties);
	GenerateTableIncomeAndExpenses(DocumentRefSubcontractorReport, StructureAdditionalProperties);
	GenerateTableIncomeAndExpensesRetained(DocumentRefSubcontractorReport, StructureAdditionalProperties);
	GenerateTableUnallocatedExpenses(DocumentRefSubcontractorReport, StructureAdditionalProperties);
	GenerateTableIncomeAndExpensesCashMethod(DocumentRefSubcontractorReport, StructureAdditionalProperties);
	
EndProcedure

#EndRegion

#Region DataInitialization

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefSubcontractorReport, StructureAdditionalProperties) Export
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	0 AS LineNumber,
	|	SubcontractorReport.Date AS Period,
	|	&Company AS Company,
	|	VALUE(Catalog.Companies.EmptyRef) AS CorrOrganization,
	|	ISNULL(SubcontractorReport.StructuralUnit, VALUE(Catalog.Counterparties.EmptyRef)) AS StructuralUnit,
	|	ISNULL(VALUE(Catalog.BusinessUnits.EmptyRef), VALUE(Catalog.Counterparties.EmptyRef)) AS StructuralUnitCorr,
	|	SubcontractorReport.StructuralUnit.StructuralUnitType AS StructuralUnitType,
	|	CASE
	|		WHEN &UseStorageBins
	|			THEN SubcontractorReport.Cell
	|		ELSE VALUE(Catalog.Cells.EmptyRef)
	|	END AS Cell,
	|	SubcontractorReport.Specification AS Specification,
	|	VALUE(Catalog.BillsOfMaterials.EmptyRef) AS SpecificationCorr,
	|	SubcontractorReport.InventoryGLAccount AS GLAccount,
	|	VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef) AS CorrGLAccount,
	|	SubcontractorReport.Products AS Products,
	|	VALUE(Catalog.Products.EmptyRef) AS ProductsCorr,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN SubcontractorReport.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	VALUE(Catalog.ProductsCharacteristics.EmptyRef) AS CharacteristicCorr,
	|	CASE
	|		WHEN &UseBatches
	|			THEN SubcontractorReport.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS Batch,
	|	VALUE(Catalog.ProductsBatches.EmptyRef) AS BatchCorr,
	|	SubcontractorReport.SalesOrder AS SalesOrder,
	|	SubcontractorReport.BasisDocument AS PurchaseOrder,
	|	CASE
	|		WHEN SubcontractorReport.BasisDocument = VALUE(Document.PurchaseOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE SubcontractorReport.BasisDocument
	|	END AS SupplySource,
	|	CASE
	|		WHEN VALUETYPE(SubcontractorReport.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN SubcontractorReport.Quantity
	|		ELSE SubcontractorReport.Quantity * SubcontractorReport.MeasurementUnit.Factor
	|	END AS Quantity,
	|	0 AS Amount,
	|	UNDEFINED AS CustomerCorrOrder,
	|	&Production AS ContentOfAccountingRecord
	|INTO TemporaryTableProduction
	|FROM
	|	Document.SubcontractorReport AS SubcontractorReport
	|WHERE
	|	SubcontractorReport.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(TableInventory.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TableInventory.Period AS Period,
	|	TableInventory.Company AS Company,
	|	UNDEFINED AS PlanningPeriod,
	|	TableInventory.CorrOrganization AS CorrOrganization,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	TableInventory.StructuralUnitCorr AS StructuralUnitCorr,
	|	TableInventory.GLAccount AS GLAccount,
	|	TableInventory.CorrGLAccount AS CorrGLAccount,
	|	TableInventory.Products AS Products,
	|	TableInventory.ProductsCorr AS ProductsCorr,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.CharacteristicCorr AS CharacteristicCorr,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.BatchCorr AS BatchCorr,
	|	TableInventory.Specification AS Specification,
	|	TableInventory.SpecificationCorr AS SpecificationCorr,
	|	CASE
	|		WHEN TableInventory.SalesOrder = VALUE(Document.SalesOrder.EmptyRef)
	|				OR TableInventory.SalesOrder = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE TableInventory.SalesOrder
	|	END AS SalesOrder,
	|	TableInventory.PurchaseOrder AS PurchaseOrder,
	|	CASE
	|		WHEN TableInventory.CustomerCorrOrder = VALUE(Document.SalesOrder.EmptyRef)
	|				OR TableInventory.CustomerCorrOrder = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE TableInventory.CustomerCorrOrder
	|	END AS CustomerCorrOrder,
	|	UNDEFINED AS AccountDr,
	|	UNDEFINED AS AccountCr,
	|	UNDEFINED AS Content,
	|	TableInventory.ContentOfAccountingRecord AS ContentOfAccountingRecord,
	|	FALSE AS ProductionExpenses,
	|	SUM(TableInventory.Quantity) AS Quantity,
	|	SUM(TableInventory.Amount) AS Amount,
	|	FALSE AS FixedCost
	|FROM
	|	TemporaryTableProduction AS TableInventory
	|
	|GROUP BY
	|	TableInventory.Period,
	|	TableInventory.Company,
	|	TableInventory.CorrOrganization,
	|	TableInventory.StructuralUnit,
	|	TableInventory.StructuralUnitCorr,
	|	TableInventory.GLAccount,
	|	TableInventory.CorrGLAccount,
	|	TableInventory.Products,
	|	TableInventory.ProductsCorr,
	|	TableInventory.Characteristic,
	|	TableInventory.CharacteristicCorr,
	|	TableInventory.Batch,
	|	TableInventory.BatchCorr,
	|	TableInventory.Specification,
	|	TableInventory.SpecificationCorr,
	|	TableInventory.SalesOrder,
	|	TableInventory.PurchaseOrder,
	|	TableInventory.CustomerCorrOrder,
	|	TableInventory.ContentOfAccountingRecord
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(TableInventoryInWarehouses.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TableInventoryInWarehouses.Period AS Period,
	|	TableInventoryInWarehouses.Company AS Company,
	|	TableInventoryInWarehouses.Products AS Products,
	|	TableInventoryInWarehouses.Characteristic AS Characteristic,
	|	TableInventoryInWarehouses.Batch AS Batch,
	|	TableInventoryInWarehouses.StructuralUnit AS StructuralUnit,
	|	TableInventoryInWarehouses.Cell AS Cell,
	|	SUM(TableInventoryInWarehouses.Quantity) AS Quantity
	|FROM
	|	TemporaryTableProduction AS TableInventoryInWarehouses
	|
	|GROUP BY
	|	TableInventoryInWarehouses.Period,
	|	TableInventoryInWarehouses.Company,
	|	TableInventoryInWarehouses.Products,
	|	TableInventoryInWarehouses.Characteristic,
	|	TableInventoryInWarehouses.Batch,
	|	TableInventoryInWarehouses.StructuralUnit,
	|	TableInventoryInWarehouses.Cell
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(TablePurchaseOrders.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TablePurchaseOrders.Period AS Period,
	|	TablePurchaseOrders.Company AS Company,
	|	TablePurchaseOrders.Products AS Products,
	|	TablePurchaseOrders.Characteristic AS Characteristic,
	|	TablePurchaseOrders.PurchaseOrder AS PurchaseOrder,
	|	SUM(TablePurchaseOrders.Quantity) AS Quantity
	|FROM
	|	TemporaryTableProduction AS TablePurchaseOrders
	|WHERE
	|	TablePurchaseOrders.PurchaseOrder <> VALUE(Document.PurchaseOrder.EmptyRef)
	|
	|GROUP BY
	|	TablePurchaseOrders.Period,
	|	TablePurchaseOrders.Company,
	|	TablePurchaseOrders.Products,
	|	TablePurchaseOrders.Characteristic,
	|	TablePurchaseOrders.PurchaseOrder
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(TableProductRelease.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TableProductRelease.Period AS Period,
	|	TableProductRelease.Company AS Company,
	|	TableProductRelease.StructuralUnit AS StructuralUnit,
	|	TableProductRelease.Products AS Products,
	|	TableProductRelease.Characteristic AS Characteristic,
	|	TableProductRelease.Batch AS Batch,
	|	CASE
	|		WHEN TableProductRelease.SalesOrder <> VALUE(Document.SalesOrder.EmptyRef)
	|			THEN TableProductRelease.SalesOrder
	|		ELSE UNDEFINED
	|	END AS SalesOrder,
	|	TableProductRelease.Specification AS Specification,
	|	SUM(TableProductRelease.Quantity) AS Quantity
	|FROM
	|	TemporaryTableProduction AS TableProductRelease
	|
	|GROUP BY
	|	TableProductRelease.Period,
	|	TableProductRelease.Company,
	|	TableProductRelease.StructuralUnit,
	|	TableProductRelease.Products,
	|	TableProductRelease.Characteristic,
	|	TableProductRelease.Batch,
	|	CASE
	|		WHEN TableProductRelease.SalesOrder <> VALUE(Document.SalesOrder.EmptyRef)
	|			THEN TableProductRelease.SalesOrder
	|		ELSE UNDEFINED
	|	END,
	|	TableProductRelease.Specification
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SubcontractorReportSerialNumbers.Ref.Date AS Period,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	SubcontractorReportSerialNumbers.Ref.Date AS EventDate,
	|	VALUE(Enum.SerialNumbersOperations.Receipt) AS Operation,
	|	&Company AS Company,
	|	SubcontractorReportSerialNumbers.SerialNumber AS SerialNumber,
	|	SubcontractorReportSerialNumbers.Ref.Products AS Products,
	|	SubcontractorReportSerialNumbers.Ref.Characteristic AS Characteristic,
	|	SubcontractorReportSerialNumbers.Ref.Batch AS Batch,
	|	SubcontractorReportSerialNumbers.Ref.StructuralUnit AS StructuralUnit,
	|	SubcontractorReportSerialNumbers.Ref.Cell AS Cell,
	|	1 AS Quantity
	|FROM
	|	Document.SubcontractorReport.SerialNumbers AS SubcontractorReportSerialNumbers
	|WHERE
	|	SubcontractorReportSerialNumbers.Ref = &Ref
	|	AND &UseSerialNumbers";
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();
	
	Query.SetParameter("Ref", DocumentRefSubcontractorReport);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("UseCharacteristics", StructureAdditionalProperties.AccountingPolicy.UseCharacteristics);
	Query.SetParameter("UseBatches",  StructureAdditionalProperties.AccountingPolicy.UseBatches);
	Query.SetParameter("UseStorageBins",  StructureAdditionalProperties.AccountingPolicy.UseStorageBins);
	
	Query.SetParameter("UseSerialNumbers", StructureAdditionalProperties.AccountingPolicy.UseSerialNumbers);
	
	Query.SetParameter("Production", NStr("en = 'Production'", MainLanguageCode));

	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryGoods", ResultsArray[1].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventory", StructureAdditionalProperties.TableForRegisterRecords.TableInventoryGoods.CopyColumns());
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryInWarehouses", ResultsArray[2].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TablePurchaseOrders", ResultsArray[3].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableProductRelease", ResultsArray[4].Unload());
	
	// Serial numbers
	ResultOfAQuery5 = ResultsArray[5].Unload();
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbersInWarranty", ResultOfAQuery5);
	If StructureAdditionalProperties.AccountingPolicy.SerialNumbersBalance Then
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbersBalance", ResultOfAQuery5);
	Else
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbersBalance", New ValueTable);
	EndIf;
	
	// Creation of document postings.
	DriveServer.GenerateTransactionsTable(DocumentRefSubcontractorReport, StructureAdditionalProperties);
	
	// Generate table by orders placement.
	GenerateTableBackorders(DocumentRefSubcontractorReport, StructureAdditionalProperties);
	
	// Inventory.
	AssemblyAmount = 0;
	DataInitializationByInventory(DocumentRefSubcontractorReport, StructureAdditionalProperties, AssemblyAmount);
	
	// Accounts payable.
	DataInitializationAccountsPayable(DocumentRefSubcontractorReport, StructureAdditionalProperties);
	
	// Services.
	ServicesAmount = 0;
	DataInitializationByService(DocumentRefSubcontractorReport, StructureAdditionalProperties, ServicesAmount);
	
	// Products.
	AssemblyAmount = AssemblyAmount + ServicesAmount;
	GenerateTableInventoryProducts(DocumentRefSubcontractorReport, StructureAdditionalProperties, AssemblyAmount);
	
	// Disposals.
	DataInitializationByDisposals(DocumentRefSubcontractorReport, StructureAdditionalProperties);
	
	GenerateTableAccountingJournalEntries(DocumentRefSubcontractorReport, StructureAdditionalProperties);
	
EndProcedure

// Controls the occurrence of negative balances.
//
Procedure RunControl(DocumentRefSubcontractorReport, AdditionalProperties, Cancel, PostingDelete = False) Export
	
	If Not DriveServer.RunBalanceControl() Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// If temporary tables "RegisterRecordsInventoryChange", "MovementsInventoryInWarehousesChange",
	// "MovementsInventoryPassedChange", "RegisterRecordsPurchaseOrdersChange", "RegisterRecordsBackordersChange", contain
	// records, it is required to control goods implementation.
	If StructureTemporaryTables.RegisterRecordsInventoryChange
	 OR StructureTemporaryTables.RegisterRecordsInventoryInWarehousesChange
	 OR StructureTemporaryTables.RegisterRecordsStockTransferredToThirdPartiesChange 
	 OR StructureTemporaryTables.RegisterRecordsPurchaseOrdersChange
	 OR StructureTemporaryTables.RegisterRecordsBackordersChange
	 OR StructureTemporaryTables.RegisterRecordsSuppliersSettlementsChange Then
		
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
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	RegisterRecordsStockTransferredToThirdPartiesChange.LineNumber AS LineNumber,
		|	REFPRESENTATION(RegisterRecordsStockTransferredToThirdPartiesChange.Company) AS CompanyPresentation,
		|	REFPRESENTATION(RegisterRecordsStockTransferredToThirdPartiesChange.Products) AS ProductsPresentation,
		|	REFPRESENTATION(RegisterRecordsStockTransferredToThirdPartiesChange.Characteristic) AS CharacteristicPresentation,
		|	REFPRESENTATION(RegisterRecordsStockTransferredToThirdPartiesChange.Batch) AS BatchPresentation,
		|	REFPRESENTATION(RegisterRecordsStockTransferredToThirdPartiesChange.Counterparty) AS CounterpartyPresentation,
		|	REFPRESENTATION(RegisterRecordsStockTransferredToThirdPartiesChange.Contract) AS ContractPresentation,
		|	REFPRESENTATION(RegisterRecordsStockTransferredToThirdPartiesChange.Order) AS OrderPresentation,
		|	REFPRESENTATION(StockTransferredToThirdPartiesBalances.Products.MeasurementUnit) AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsStockTransferredToThirdPartiesChange.QuantityChange, 0) + ISNULL(StockTransferredToThirdPartiesBalances.QuantityBalance, 0) AS BalanceStockTransferredToThirdParties,
		|	ISNULL(StockTransferredToThirdPartiesBalances.QuantityBalance, 0) AS QuantityBalanceStockTransferredToThirdParties
		|FROM
		|	RegisterRecordsStockTransferredToThirdPartiesChange AS RegisterRecordsStockTransferredToThirdPartiesChange
		|		LEFT JOIN AccumulationRegister.StockTransferredToThirdParties.Balance(
		|				&ControlTime,
		|				(Company, Products, Characteristic, Batch, Counterparty, Contract, Order) IN
		|					(SELECT
		|						RegisterRecordsStockTransferredToThirdPartiesChange.Company AS Company,
		|						RegisterRecordsStockTransferredToThirdPartiesChange.Products AS Products,
		|						RegisterRecordsStockTransferredToThirdPartiesChange.Characteristic AS Characteristic,
		|						RegisterRecordsStockTransferredToThirdPartiesChange.Batch AS Batch,
		|						RegisterRecordsStockTransferredToThirdPartiesChange.Counterparty AS Counterparty,
		|						RegisterRecordsStockTransferredToThirdPartiesChange.Contract AS Contract,
		|						RegisterRecordsStockTransferredToThirdPartiesChange.Order AS Order
		|					FROM
		|						RegisterRecordsStockTransferredToThirdPartiesChange AS RegisterRecordsStockTransferredToThirdPartiesChange)) AS StockTransferredToThirdPartiesBalances
		|		ON RegisterRecordsStockTransferredToThirdPartiesChange.Company = StockTransferredToThirdPartiesBalances.Company
		|			AND RegisterRecordsStockTransferredToThirdPartiesChange.Products = StockTransferredToThirdPartiesBalances.Products
		|			AND RegisterRecordsStockTransferredToThirdPartiesChange.Characteristic = StockTransferredToThirdPartiesBalances.Characteristic
		|			AND RegisterRecordsStockTransferredToThirdPartiesChange.Batch = StockTransferredToThirdPartiesBalances.Batch
		|			AND RegisterRecordsStockTransferredToThirdPartiesChange.Counterparty = StockTransferredToThirdPartiesBalances.Counterparty
		|			AND RegisterRecordsStockTransferredToThirdPartiesChange.Contract = StockTransferredToThirdPartiesBalances.Contract
		|			AND RegisterRecordsStockTransferredToThirdPartiesChange.Order = StockTransferredToThirdPartiesBalances.Order
		|WHERE
		|	(ISNULL(StockTransferredToThirdPartiesBalances.QuantityBalance, 0) < 0)
		|
		|ORDER BY
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	RegisterRecordsPurchaseOrdersChange.LineNumber AS LineNumber,
		|	REFPRESENTATION(RegisterRecordsPurchaseOrdersChange.Company) AS CompanyPresentation,
		|	REFPRESENTATION(RegisterRecordsPurchaseOrdersChange.PurchaseOrder) AS PurchaseOrderPresentation,
		|	REFPRESENTATION(RegisterRecordsPurchaseOrdersChange.Products) AS ProductsPresentation,
		|	REFPRESENTATION(RegisterRecordsPurchaseOrdersChange.Characteristic) AS CharacteristicPresentation,
		|	REFPRESENTATION(PurchaseOrdersBalances.Products.MeasurementUnit) AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsPurchaseOrdersChange.QuantityChange, 0) + ISNULL(PurchaseOrdersBalances.QuantityBalance, 0) AS BalancePurchaseOrders,
		|	ISNULL(PurchaseOrdersBalances.QuantityBalance, 0) AS QuantityBalancePurchaseOrders
		|FROM
		|	RegisterRecordsPurchaseOrdersChange AS RegisterRecordsPurchaseOrdersChange
		|		LEFT JOIN AccumulationRegister.PurchaseOrders.Balance(
		|				&ControlTime,
		|				(Company, PurchaseOrder, Products, Characteristic) IN
		|					(SELECT
		|						RegisterRecordsPurchaseOrdersChange.Company AS Company,
		|						RegisterRecordsPurchaseOrdersChange.PurchaseOrder AS PurchaseOrder,
		|						RegisterRecordsPurchaseOrdersChange.Products AS Products,
		|						RegisterRecordsPurchaseOrdersChange.Characteristic AS Characteristic
		|					FROM
		|						RegisterRecordsPurchaseOrdersChange AS RegisterRecordsPurchaseOrdersChange)) AS PurchaseOrdersBalances
		|		ON RegisterRecordsPurchaseOrdersChange.Company = PurchaseOrdersBalances.Company
		|			AND RegisterRecordsPurchaseOrdersChange.PurchaseOrder = PurchaseOrdersBalances.PurchaseOrder
		|			AND RegisterRecordsPurchaseOrdersChange.Products = PurchaseOrdersBalances.Products
		|			AND RegisterRecordsPurchaseOrdersChange.Characteristic = PurchaseOrdersBalances.Characteristic
		|WHERE
		|	ISNULL(PurchaseOrdersBalances.QuantityBalance, 0) < 0
		|
		|ORDER BY
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	RegisterRecordsBackordersChange.LineNumber AS LineNumber,
		|	REFPRESENTATION(RegisterRecordsBackordersChange.Company) AS CompanyPresentation,
		|	REFPRESENTATION(RegisterRecordsBackordersChange.SalesOrder) AS SalesOrderPresentation,
		|	REFPRESENTATION(RegisterRecordsBackordersChange.Products) AS ProductsPresentation,
		|	REFPRESENTATION(RegisterRecordsBackordersChange.Characteristic) AS CharacteristicPresentation,
		|	REFPRESENTATION(RegisterRecordsBackordersChange.SupplySource) AS SupplySourcePresentation,
		|	REFPRESENTATION(BackordersBalances.Products.MeasurementUnit) AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsBackordersChange.QuantityChange, 0) + ISNULL(BackordersBalances.QuantityBalance, 0) AS BalanceBackorders,
		|	ISNULL(BackordersBalances.QuantityBalance, 0) AS QuantityBalanceBackorders
		|FROM
		|	RegisterRecordsBackordersChange AS RegisterRecordsBackordersChange
		|		LEFT JOIN AccumulationRegister.Backorders.Balance(
		|				&ControlTime,
		|				(Company, SalesOrder, Products, Characteristic, SupplySource) IN
		|					(SELECT
		|						RegisterRecordsBackordersChange.Company AS Company,
		|						RegisterRecordsBackordersChange.SalesOrder AS SalesOrder,
		|						RegisterRecordsBackordersChange.Products AS Products,
		|						RegisterRecordsBackordersChange.Characteristic AS Characteristic,
		|						RegisterRecordsBackordersChange.SupplySource AS SupplySource
		|					FROM
		|						RegisterRecordsBackordersChange AS RegisterRecordsBackordersChange)) AS BackordersBalances
		|		ON RegisterRecordsBackordersChange.Company = BackordersBalances.Company
		|			AND RegisterRecordsBackordersChange.SalesOrder = BackordersBalances.SalesOrder
		|			AND RegisterRecordsBackordersChange.Products = BackordersBalances.Products
		|			AND RegisterRecordsBackordersChange.Characteristic = BackordersBalances.Characteristic
		|			AND RegisterRecordsBackordersChange.SupplySource = BackordersBalances.SupplySource
		|WHERE
		|	ISNULL(BackordersBalances.QuantityBalance, 0) < 0
		|
		|ORDER BY
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
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
		|				(Company, Counterparty, Contract, Document, Order, SettlementsType) IN
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
		
		ResultsArray = Query.ExecuteBatch();
		
		If Not ResultsArray[0].IsEmpty()
			OR Not ResultsArray[1].IsEmpty()
			OR Not ResultsArray[2].IsEmpty()
			OR Not ResultsArray[3].IsEmpty()
			OR Not ResultsArray[4].IsEmpty() 
			OR Not ResultsArray[5].IsEmpty() Then
			DocumentObjectSubcontractorReport = DocumentRefSubcontractorReport.GetObject();
		EndIf;
		
		// Negative balance of inventory in the warehouse.
		If Not ResultsArray[0].IsEmpty() Then
			QueryResultSelection = ResultsArray[0].Select();
			DriveServer.ShowMessageAboutPostingToInventoryInWarehousesRegisterErrors(DocumentObjectSubcontractorReport, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance of inventory.
		If Not ResultsArray[1].IsEmpty() Then
			QueryResultSelection = ResultsArray[1].Select();
			DriveServer.ShowMessageAboutPostingToInventoryRegisterErrors(DocumentObjectSubcontractorReport, QueryResultSelection, Cancel);
		EndIf;
		
		// The negative balance of transferred inventory.
		If Not ResultsArray[2].IsEmpty() Then
			QueryResultSelection = ResultsArray[2].Select();
			DriveServer.ShowMessageAboutPostingToStockTransferredToThirdPartiesRegisterErrors(DocumentObjectSubcontractorReport, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance on the order to the vendor.
		If Not ResultsArray[3].IsEmpty() Then
			QueryResultSelection = ResultsArray[3].Select();
			DriveServer.ShowMessageAboutPostingToPurchaseOrdersRegisterErrors(DocumentObjectSubcontractorReport, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance on the inventories placement.
		If Not ResultsArray[4].IsEmpty() Then
			QueryResultSelection = ResultsArray[4].Select();
			DriveServer.ShowMessageAboutPostingToBackordersRegisterErrors(DocumentObjectSubcontractorReport, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance on accounts payable.
		If Not ResultsArray[5].IsEmpty() Then
			QueryResultSelection = ResultsArray[5].Select();
			DriveServer.ShowMessageAboutPostingToAccountsPayableRegisterErrors(DocumentObjectSubcontractorReport, QueryResultSelection, Cancel);
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#EndRegion

#Region PrintInterface

Procedure Print(ObjectsArray, PrintParameters, PrintFormsCollection, PrintObjects, OutputParameters) Export
	
	If PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "GoodsReceivedNote") Then
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection,
															"GoodsReceivedNote",
															NStr("en = 'Goods received note'"),
															DataProcessors.PrintGoodsReceivedNote.PrintForm(ObjectsArray, PrintObjects, "GoodsReceivedNote"));
	EndIf;
	
	// parameters of sending printing forms by email
	DriveServer.FillSendingParameters(OutputParameters.SendingParameters, ObjectsArray, PrintFormsCollection);
	
EndProcedure

Procedure AddPrintCommands(PrintCommands) Export
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID							= "GoodsReceivedNote";
	PrintCommand.Presentation				= NStr("en = 'Goods received note'");
	PrintCommand.CheckPostingBeforePrint	= False;
	PrintCommand.Order						= 1;
	
EndProcedure

#EndRegion

#Region InfobaseUpdate

Procedure FillNewGLAccounts() Export
	
	DocumentName = "SubcontractorReport";
	
	Tables = New Array();
	
	// Table "Disposals"
	TableDecription = New Structure("Name, Conditions", "Disposals", New Array());
	
	GLAccountFields = ChartsOfAccounts.PrimaryChartOfAccounts.GLAccountFields();
	GLAccountFields.Source = "Products.InventoryGLAccount";
	GLAccountFields.Receiver = "InventoryGLAccount";
	TableDecription.Conditions.Add(GLAccountFields);
	
	Tables.Add(TableDecription);
	
	// Table "Inventory"
	TableDecription = New Structure("Name, Conditions", "Inventory", New Array());
	
	GLAccountFields = ChartsOfAccounts.PrimaryChartOfAccounts.GLAccountFields();
	GLAccountFields.Source = "Products.InventoryGLAccount";
	GLAccountFields.Receiver = "InventoryTransferredGLAccount";
	TableDecription.Conditions.Add(GLAccountFields);
	
	Tables.Add(TableDecription);
	
	// Header
	TableDecription = New Structure("Name, Conditions", "", New Array());
	
	GLAccountFields = ChartsOfAccounts.PrimaryChartOfAccounts.GLAccountFields();
	GLAccountFields.Source = "Products.InventoryGLAccount";
	GLAccountFields.Receiver = "InventoryGLAccount";
	TableDecription.Conditions.Add(GLAccountFields);
	
	GLAccountFields = ChartsOfAccounts.PrimaryChartOfAccounts.GLAccountFields();
	GLAccountFields.Source = "&VATInputGLAccount";
	GLAccountFields.Receiver = "VATInputGLAccount";
	GLAccountFields.Parameter = Catalogs.DefaultGLAccounts.GetDefaultGLAccount("VATInput");
	TableDecription.Conditions.Add(GLAccountFields);
	
	Tables.Add(TableDecription);
	
	ChartsOfAccounts.PrimaryChartOfAccounts.FillNewGLAccounts(DocumentName, Tables);
	
EndProcedure

#EndRegion

#EndIf