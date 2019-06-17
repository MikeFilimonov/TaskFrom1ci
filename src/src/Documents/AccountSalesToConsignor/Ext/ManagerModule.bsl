#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region PostingProcedures

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableAccountingJournalEntries(DocumentRefReportToCommissioner, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	SUM(TemporaryTable.VATAmount) AS VATAmount,
	|	SUM(TemporaryTable.BrokerageVATAmount) AS BrokerageVATAmount,
	|	SUM(TemporaryTable.VATAmountCur) AS VATAmountCur,
	|	SUM(TemporaryTable.BrokerageVATAmountCur) AS BrokerageVATAmountCur,
	|	SUM(TemporaryTable.CostVAT) AS CostVAT,
	|	SUM(TemporaryTable.CostVATCur) AS CostVATCur
	|FROM
	|	TemporaryTableInventory AS TemporaryTable
	|
	|GROUP BY
	|	TemporaryTable.Period,
	|	TemporaryTable.Company";
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	
	VATAmount = 0;
	VATAmountCur = 0;
	BrokerageVATAmount=0;
	BrokerageVATAmountCur = 0;
	CostVAT = 0;
	CostVATCur = 0;
	
	While Selection.Next() Do  
		VATAmount = Selection.VATAmount;
		VATAmountCur = Selection.VATAmountCur;
		BrokerageVATAmount = Selection.BrokerageVATAmount;
		BrokerageVATAmountCur = Selection.BrokerageVATAmountCur;
		CostVAT = Selection.CostVAT;
		CostVATCur = Selection.CostVATCur;
	EndDo;

	
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	1 AS Ordering,
	|	TableAccountingJournalEntries.LineNumber AS LineNumber,
	|	TableAccountingJournalEntries.Period AS Period,
	|	TableAccountingJournalEntries.Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	TableAccountingJournalEntries.GLAccountVendorSettlements AS AccountDr,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccountVendorSettlements.Currency
	|			THEN &PresentationCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccountVendorSettlements.Currency
	|			THEN CASE
	|					WHEN TableAccountingJournalEntries.KeepBackComissionFee
	|						THEN TableAccountingJournalEntries.Amount - TableAccountingJournalEntries.VATAmount - (TableAccountingJournalEntries.Cost - TableAccountingJournalEntries.CostVAT) + (TableAccountingJournalEntries.BrokerageAmount - TableAccountingJournalEntries.BrokerageVATAmount)
	|					ELSE TableAccountingJournalEntries.Amount - TableAccountingJournalEntries.VATAmount - (TableAccountingJournalEntries.Cost - TableAccountingJournalEntries.CostVAT)
	|				END
	|		ELSE 0
	|	END AS AmountCurDr,
	|	TableAccountingJournalEntries.AccountStatementSales AS AccountCr,
	|	UNDEFINED AS CurrencyCr,
	|	0 AS AmountCurCr,
	|	CASE
	|		WHEN TableAccountingJournalEntries.KeepBackComissionFee
	|			THEN TableAccountingJournalEntries.Amount - TableAccountingJournalEntries.VATAmount - (TableAccountingJournalEntries.Cost - TableAccountingJournalEntries.CostVAT) + (TableAccountingJournalEntries.BrokerageAmount - TableAccountingJournalEntries.BrokerageVATAmount)
	|		ELSE TableAccountingJournalEntries.Amount - TableAccountingJournalEntries.VATAmount - (TableAccountingJournalEntries.Cost - TableAccountingJournalEntries.CostVAT)
	|	END AS Amount,
	|	&IncomeReflection AS Content,
	|	FALSE AS OfflineRecord
	|FROM
	|	TemporaryTableInventory AS TableAccountingJournalEntries
	|WHERE
	|	TableAccountingJournalEntries.BrokerageAmount > 0
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	TableAccountingJournalEntries.LineNumber,
	|	TableAccountingJournalEntries.Period,
	|	TableAccountingJournalEntries.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	TableAccountingJournalEntries.GLAccountVendorSettlements,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccountVendorSettlements.Currency
	|			THEN &PresentationCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccountVendorSettlements.Currency
	|			THEN CASE
	|					WHEN TableAccountingJournalEntries.KeepBackComissionFee
	|						THEN TableAccountingJournalEntries.Cost - TableAccountingJournalEntries.CostVAT - (TableAccountingJournalEntries.BrokerageAmount - TableAccountingJournalEntries.BrokerageVATAmount)
	|					ELSE TableAccountingJournalEntries.Cost - TableAccountingJournalEntries.CostVAT
	|				END
	|		ELSE 0
	|	END,
	|	TableAccountingJournalEntries.GLAccountVendorSettlements,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccountVendorSettlements.Currency
	|			THEN TableAccountingJournalEntries.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccountVendorSettlements.Currency
	|			THEN TableAccountingJournalEntries.CostPriceCur - TableAccountingJournalEntries.CostVATCur - (TableAccountingJournalEntries.BrokerageAmountCur - TableAccountingJournalEntries.BrokerageVATAmountCur)
	|		ELSE TableAccountingJournalEntries.CostPriceCur - TableAccountingJournalEntries.CostVATCur
	|	END,
	|	CASE
	|		WHEN TableAccountingJournalEntries.KeepBackComissionFee
	|			THEN TableAccountingJournalEntries.Cost - TableAccountingJournalEntries.CostVAT - (TableAccountingJournalEntries.BrokerageAmount - TableAccountingJournalEntries.BrokerageVATAmount)
	|		ELSE TableAccountingJournalEntries.Cost - TableAccountingJournalEntries.CostVAT
	|	END,
	|	&ComitentDebt,
	|	FALSE
	|FROM
	|	TemporaryTableInventory AS TableAccountingJournalEntries
	|
	|UNION ALL
	|
	|SELECT
	|	3,
	|	1,
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.GLAccountVendorSettlements,
	|	CASE
	|		WHEN DocumentTable.GLAccountVendorSettlementsCurrency
	|			THEN DocumentTable.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.GLAccountVendorSettlementsCurrency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END,
	|	DocumentTable.VendorAdvancesGLAccount,
	|	CASE
	|		WHEN DocumentTable.VendorAdvancesGLAccountCurrency
	|			THEN DocumentTable.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.VendorAdvancesGLAccountCurrency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END,
	|	DocumentTable.Amount,
	|	&SetOffAdvancePayment,
	|	FALSE
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
	|	4,
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
	|SELECT TOP 1
	|	5,
	|	TableAccountingJournalEntries.LineNumber,
	|	TableAccountingJournalEntries.Period,
	|	TableAccountingJournalEntries.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	TableAccountingJournalEntries.GLAccountVendorSettlements,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccountVendorSettlements.Currency
	|			THEN &PresentationCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccountVendorSettlements.Currency
	|			THEN CASE
	|					WHEN TableAccountingJournalEntries.KeepBackComissionFee
	|						THEN &VATAmount - &CostVAT + &BrokerageVATAmount
	|					ELSE &VATAmount - &CostVAT
	|				END
	|		ELSE 0
	|	END,
	|	&TextVAT,
	|	UNDEFINED,
	|	0,
	|	CASE
	|		WHEN TableAccountingJournalEntries.KeepBackComissionFee
	|			THEN &VATAmount - &CostVAT + &BrokerageVATAmount
	|		ELSE &VATAmount - &CostVAT
	|	END,
	|	&VAT,
	|	FALSE
	|FROM
	|	TemporaryTableInventory AS TableAccountingJournalEntries
	|WHERE
	|	&BrokerageVATAmount > 0
	|
	|UNION ALL
	|
	|SELECT TOP 1
	|	6,
	|	TableAccountingJournalEntries.LineNumber,
	|	TableAccountingJournalEntries.Period,
	|	TableAccountingJournalEntries.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	&TextVAT,
	|	UNDEFINED,
	|	0,
	|	TableAccountingJournalEntries.GLAccountVendorSettlements,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccountVendorSettlements.Currency
	|			THEN TableAccountingJournalEntries.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccountVendorSettlements.Currency
	|			THEN &CostVATCur - &BrokerageVATAmountCur
	|		ELSE &CostVATCur
	|	END,
	|	CASE
	|		WHEN TableAccountingJournalEntries.KeepBackComissionFee
	|			THEN &CostVAT - &BrokerageVATAmount
	|		ELSE &CostVAT
	|	END,
	|	&VAT,
	|	FALSE
	|FROM
	|	TemporaryTableInventory AS TableAccountingJournalEntries
	|WHERE
	|	&CostVAT - &BrokerageVATAmount > 0
	|
	|UNION ALL
	|
	|SELECT
	|	7,
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
	|
	|ORDER BY
	|	Ordering,
	|	LineNumber";
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();
	
	Query.SetParameter("ExchangeDifference",							NStr("en = 'Foreign currency exchange gains and losses'", MainLanguageCode));
	Query.SetParameter("SetOffAdvancePayment",							NStr("en = 'Advance payment clearing'", MainLanguageCode));
	Query.SetParameter("IncomeReflection",								NStr("en = 'Revenue'", MainLanguageCode));
	Query.SetParameter("ComitentDebt",									NStr("en = 'Accounts payable recognition'", MainLanguageCode));
	Query.SetParameter("PresentationCurrency",							Constants.PresentationCurrency.Get());
	Query.SetParameter("PositiveExchangeDifferenceGLAccount",			Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeGain"));
	Query.SetParameter("NegativeExchangeDifferenceAccountOfAccounting", Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeLoss"));
	Query.SetParameter("VAT",											NStr("en = 'VAT'", MainLanguageCode));
	Query.SetParameter("TextVAT",										Catalogs.DefaultGLAccounts.GetDefaultGLAccount("VATInput"));
	Query.SetParameter("VATAmount",										VATAmount);
	Query.SetParameter("VATAmountCur",									VATAmountCur);
	Query.SetParameter("BrokerageVATAmount",							BrokerageVATAmount);
	Query.SetParameter("BrokerageVATAmountCur",							BrokerageVATAmountCur);
	Query.SetParameter("CostVATCur",									CostVATCur);
	Query.SetParameter("CostVAT",										CostVAT);
	Query.SetParameter("Ref",											DocumentRefReportToCommissioner);

	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	
	While Selection.Next() Do
		NewEntry = StructureAdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries.Add();
		FillPropertyValues(NewEntry, Selection);
	EndDo;
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableStockReceivedFromThirdParties(DocumentRefReportToCommissioner, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	1 AS Ordering,
	|	MIN(TableStockReceivedFromThirdParties.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableStockReceivedFromThirdParties.Period AS Period,
	|	TableStockReceivedFromThirdParties.Company AS Company,
	|	TableStockReceivedFromThirdParties.Products AS Products,
	|	TableStockReceivedFromThirdParties.Characteristic AS Characteristic,
	|	TableStockReceivedFromThirdParties.Batch AS Batch,
	|	TableStockReceivedFromThirdParties.Counterparty AS Counterparty,
	|	TableStockReceivedFromThirdParties.Contract AS Contract,
	|	CASE
	|		WHEN TableStockReceivedFromThirdParties.PurchaseOrder <> VALUE(Document.PurchaseOrder.EmptyRef)
	|			THEN TableStockReceivedFromThirdParties.PurchaseOrder
	|		ELSE UNDEFINED
	|	END AS Order,
	|	TableStockReceivedFromThirdParties.GLAccount AS GLAccount,
	|	SUM(TableStockReceivedFromThirdParties.Quantity) AS Quantity,
	|	&InventoryReception AS ContentOfAccountingRecord
	|FROM
	|	TemporaryTableInventory AS TableStockReceivedFromThirdParties,
	|	Constant.FunctionalCurrency AS ConstantNationalCurrency
	|
	|GROUP BY
	|	TableStockReceivedFromThirdParties.Period,
	|	TableStockReceivedFromThirdParties.Company,
	|	TableStockReceivedFromThirdParties.Products,
	|	TableStockReceivedFromThirdParties.Characteristic,
	|	TableStockReceivedFromThirdParties.Batch,
	|	TableStockReceivedFromThirdParties.Counterparty,
	|	TableStockReceivedFromThirdParties.Contract,
	|	CASE
	|		WHEN TableStockReceivedFromThirdParties.PurchaseOrder <> VALUE(Document.PurchaseOrder.EmptyRef)
	|			THEN TableStockReceivedFromThirdParties.PurchaseOrder
	|		ELSE UNDEFINED
	|	END,
	|	TableStockReceivedFromThirdParties.GLAccount,
	|	ConstantNationalCurrency.Value";
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();
	
	Query.SetParameter("InventoryReception", "");
	Query.SetParameter("InventoryreceptionPostponedIncome", NStr("en = 'Inventory increase'", MainLanguageCode));
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableStockReceivedFromThirdParties", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableSales(DocumentRefReportToCommissioner, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	TableSales.Period AS Period,
	|	TableSales.Company AS Company,
	|	TableSales.Products AS Products,
	|	TableSales.Characteristic AS Characteristic,
	|	TableSales.Batch AS Batch,
	|	CASE
	|		WHEN TableSales.SalesOrder <> VALUE(Document.SalesOrder.EmptyRef)
	|				AND TableSales.SalesOrder <> VALUE(Document.WorkOrder.EmptyRef)
	|			THEN TableSales.SalesOrder
	|		ELSE UNDEFINED
	|	END AS SalesOrder,
	|	TableSales.SalesRep AS SalesRep,
	|	TableSales.Document AS Document,
	|	TableSales.VATRate AS VATRate,
	|	TableSales.DepartmentSales AS Department,
	|	TableSales.Responsible AS Responsible,
	|	0 AS Quantity,
	|	0 AS Amount,
	|	0 AS VATAmount,
	|	SUM(CASE
	|			WHEN TableSales.KeepBackComissionFee
	|				THEN TableSales.Cost - TableSales.BrokerageAmount
	|			ELSE TableSales.Cost
	|		END) AS Cost,
	|	FALSE AS OfflineRecord
	|INTO TableSales
	|FROM
	|	TemporaryTableInventory AS TableSales
	|
	|GROUP BY
	|	TableSales.Period,
	|	TableSales.Company,
	|	TableSales.Products,
	|	TableSales.Characteristic,
	|	TableSales.Batch,
	|	CASE
	|		WHEN TableSales.SalesOrder <> VALUE(Document.SalesOrder.EmptyRef)
	|				AND TableSales.SalesOrder <> VALUE(Document.WorkOrder.EmptyRef)
	|			THEN TableSales.SalesOrder
	|		ELSE UNDEFINED
	|	END,
	|	TableSales.SalesRep,
	|	TableSales.Document,
	|	TableSales.VATRate,
	|	TableSales.DepartmentSales,
	|	TableSales.Responsible
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableSales.Period AS Period,
	|	TableSales.Company AS Company,
	|	TableSales.Products AS Products,
	|	TableSales.Characteristic AS Characteristic,
	|	TableSales.Batch AS Batch,
	|	TableSales.SalesOrder AS SalesOrder,
	|	TableSales.SalesRep AS SalesRep,
	|	TableSales.Document AS Document,
	|	TableSales.VATRate AS VATRate,
	|	TableSales.Department AS Department,
	|	TableSales.Responsible AS Responsible,
	|	TableSales.Quantity AS Quantity,
	|	TableSales.Amount AS Amount,
	|	TableSales.VATAmount AS VATAmount,
	|	TableSales.Cost AS Cost,
	|	TableSales.OfflineRecord AS OfflineRecord
	|FROM
	|	TableSales AS TableSales
	|WHERE
	|	TableSales.Cost > 0
	|
	|UNION ALL
	|
	|SELECT
	|	OfflineRecords.Period,
	|	OfflineRecords.Company,
	|	OfflineRecords.Products,
	|	OfflineRecords.Characteristic,
	|	OfflineRecords.Batch,
	|	OfflineRecords.SalesOrder,
	|	OfflineRecords.SalesRep,
	|	OfflineRecords.Document,
	|	OfflineRecords.VATRate,
	|	OfflineRecords.Department,
	|	OfflineRecords.Responsible,
	|	OfflineRecords.Quantity,
	|	OfflineRecords.Amount,
	|	OfflineRecords.VATAmount,
	|	OfflineRecords.Cost,
	|	OfflineRecords.OfflineRecord
	|FROM
	|	AccumulationRegister.Sales AS OfflineRecords
	|WHERE
	|	OfflineRecords.Recorder = &Ref
	|	AND OfflineRecords.OfflineRecord";
	
	Query.SetParameter("Ref", DocumentRefReportToCommissioner);
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSales", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableIncomeAndExpenses(DocumentRefReportToCommissioner, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	1 AS Ordering,
	|	MAX(TableIncomeAndExpenses.LineNumber) AS LineNumber,
	|	TableIncomeAndExpenses.Period AS Period,
	|	TableIncomeAndExpenses.Company AS Company,
	|	TableIncomeAndExpenses.DepartmentSales AS StructuralUnit,
	|	TableIncomeAndExpenses.BusinessLineSales AS BusinessLine,
	|	CASE
	|		WHEN TableIncomeAndExpenses.SalesOrder = VALUE(Document.SalesOrder.EmptyRef)
	|				OR TableIncomeAndExpenses.SalesOrder = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE TableIncomeAndExpenses.SalesOrder
	|	END AS SalesOrder,
	|	TableIncomeAndExpenses.AccountStatementSales AS GLAccount,
	|	&IncomeReflection AS ContentOfAccountingRecord,
	|	SUM(CASE
	|			WHEN TableIncomeAndExpenses.KeepBackComissionFee
	|				THEN TableIncomeAndExpenses.Amount - TableIncomeAndExpenses.VATAmount - (TableIncomeAndExpenses.Cost - TableIncomeAndExpenses.CostVAT) + (TableIncomeAndExpenses.BrokerageAmount - TableIncomeAndExpenses.BrokerageVATAmount)
	|			ELSE TableIncomeAndExpenses.Amount - TableIncomeAndExpenses.VATAmount - (TableIncomeAndExpenses.Cost - TableIncomeAndExpenses.CostVAT)
	|		END) AS AmountIncome,
	|	0 AS AmountExpense,
	|	FALSE AS OfflineRecord
	|FROM
	|	TemporaryTableInventory AS TableIncomeAndExpenses
	|WHERE
	|	(TableIncomeAndExpenses.KeepBackComissionFee
	|				AND TableIncomeAndExpenses.Amount - TableIncomeAndExpenses.Cost + TableIncomeAndExpenses.BrokerageAmount > 0
	|			OR NOT TableIncomeAndExpenses.KeepBackComissionFee
	|				AND TableIncomeAndExpenses.Amount - TableIncomeAndExpenses.Cost > 0)
	|
	|GROUP BY
	|	TableIncomeAndExpenses.Period,
	|	TableIncomeAndExpenses.Company,
	|	TableIncomeAndExpenses.DepartmentSales,
	|	TableIncomeAndExpenses.BusinessLineSales,
	|	TableIncomeAndExpenses.SalesOrder,
	|	TableIncomeAndExpenses.AccountStatementSales
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	1,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	UNDEFINED,
	|	VALUE(Catalog.LinesOfBusiness.Other),
	|	UNDEFINED,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN &NegativeExchangeDifferenceAccountOfAccounting
	|		ELSE &PositiveExchangeDifferenceGLAccount
	|	END,
	|	&ExchangeDifference,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN 0
	|		ELSE -DocumentTable.AmountOfExchangeDifferences
	|	END,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN DocumentTable.AmountOfExchangeDifferences
	|		ELSE 0
	|	END,
	|	FALSE
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
	|			OR SUM(TableOfExchangeRateDifferencesAccountsPayable.AmountOfExchangeDifferences) <= -0.005)) AS DocumentTable";

	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();
	
	Query.SetParameter("PositiveExchangeDifferenceGLAccount",			Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeGain"));
	Query.SetParameter("NegativeExchangeDifferenceAccountOfAccounting", Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeLoss"));
	Query.SetParameter("IncomeReflection",								NStr("en = 'Revenue'", MainLanguageCode));
	Query.SetParameter("ExchangeDifference",							NStr("en = 'Foreign currency exchange gains and losses'", MainLanguageCode));
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpenses", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableAccountsPayable(DocumentRefReportToCommissioner, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();
	
	Query.SetParameter("Ref",							DocumentRefReportToCommissioner);
	Query.SetParameter("PointInTime",					New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod",					StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("Company",						StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("AppearenceOfLiabilityToVendor",	NStr("en = 'Accounts payable recognition'", MainLanguageCode));
	Query.SetParameter("AdvanceCredit",					NStr("en = 'Advance payment clearing'", MainLanguageCode));
	Query.SetParameter("ExchangeDifference",			NStr("en = 'Foreign currency exchange gains and losses'", MainLanguageCode));
	Query.SetParameter("ExpectedPayments",				NStr("en = 'Expected payment'", MainLanguageCode));
	
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
	|			THEN DocumentTable.PurchaseOrder
	|		ELSE VALUE(Document.PurchaseOrder.EmptyRef)
	|	END AS Order,
	|	DocumentTable.SettlementsCurrency AS Currency,
	|	VALUE(Enum.SettlementsTypes.Debt) AS SettlementsType,
	|	SUM(CASE
	|			WHEN DocumentTable.KeepBackComissionFee
	|				THEN DocumentTable.Cost - DocumentTable.BrokerageAmount
	|			ELSE DocumentTable.Cost
	|		END) AS Amount,
	|	SUM(CASE
	|			WHEN DocumentTable.KeepBackComissionFee
	|				THEN DocumentTable.CostPriceCur - DocumentTable.BrokerageAmountCur
	|			ELSE DocumentTable.CostPriceCur
	|		END) AS AmountCur,
	|	SUM(CASE
	|			WHEN DocumentTable.KeepBackComissionFee
	|				THEN DocumentTable.Cost - DocumentTable.BrokerageAmount
	|			ELSE DocumentTable.Cost
	|		END) AS AmountForBalance,
	|	SUM(CASE
	|			WHEN DocumentTable.KeepBackComissionFee
	|				THEN DocumentTable.CostPriceCur - DocumentTable.BrokerageAmountCur
	|			ELSE DocumentTable.CostPriceCur
	|		END) AS AmountCurForBalance,
	|	SUM(CASE
	|			WHEN DocumentTable.SetPaymentTerms
	|				THEN 0
	|			ELSE CASE
	|					WHEN DocumentTable.KeepBackComissionFee
	|						THEN DocumentTable.Cost - DocumentTable.BrokerageAmount
	|					ELSE DocumentTable.Cost
	|				END
	|		END) AS AmountForPayment,
	|	SUM(CASE
	|			WHEN DocumentTable.SetPaymentTerms
	|				THEN 0
	|			ELSE CASE
	|					WHEN DocumentTable.KeepBackComissionFee
	|						THEN DocumentTable.CostPriceCur - DocumentTable.BrokerageAmountCur
	|					ELSE DocumentTable.CostPriceCur
	|				END
	|		END) AS AmountForPaymentCur,
	|	CAST(&AppearenceOfLiabilityToVendor AS STRING(100)) AS ContentOfAccountingRecord
	|INTO TemporaryTableAccountsPayable
	|FROM
	|	TemporaryTableInventory AS DocumentTable
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
	|			THEN DocumentTable.PurchaseOrder
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
	|	SUM(DocumentTable.Amount),
	|	SUM(DocumentTable.AmountCur),
	|	CAST(&AdvanceCredit AS STRING(100))
	|FROM
	|	TemporaryTablePrepayment AS DocumentTable
	|
	|GROUP BY
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	DocumentTable.Counterparty,
	|	DocumentTable.DoOperationsByDocuments,
	|	DocumentTable.VendorAdvancesGLAccount,
	|	DocumentTable.Contract,
	|	DocumentTable.SettlementsCurrency,
	|	DocumentTable.SettlementsType,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByDocuments
	|			THEN DocumentTable.Document
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByOrders
	|			THEN DocumentTable.Order
	|		ELSE VALUE(Document.PurchaseOrder.EmptyRef)
	|	END
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
	|	SUM(DocumentTable.Amount),
	|	SUM(DocumentTable.AmountCur),
	|	CAST(&AdvanceCredit AS STRING(100))
	|FROM
	|	TemporaryTablePrepayment AS DocumentTable
	|
	|GROUP BY
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	DocumentTable.Counterparty,
	|	DocumentTable.DoOperationsByDocuments,
	|	DocumentTable.GLAccountVendorSettlements,
	|	DocumentTable.Contract,
	|	DocumentTable.SettlementsCurrency,
	|	DocumentTable.SettlemensTypeWhere,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByDocuments
	|			THEN DocumentTable.DocumentWhere
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByOrders
	|			THEN DocumentTable.Order
	|		ELSE VALUE(Document.PurchaseOrder.EmptyRef)
	|	END
	|
	|UNION ALL
	|
	|SELECT
	|	VALUE(AccumulationRecordType.Receipt),
	|	Calendar.Period,
	|	Calendar.Company,
	|	Calendar.Counterparty,
	|	Calendar.DoOperationsByDocuments,
	|	Calendar.GLAccountCustomerSettlements,
	|	Calendar.Contract,
	|	CASE
	|		WHEN Calendar.DoOperationsByDocuments
	|			THEN Calendar.DocumentWhere
	|		ELSE UNDEFINED
	|	END,
	|	Calendar.Order,
	|	Calendar.SettlementsCurrency,
	|	Calendar.SettlemensTypeWhere,
	|	0,
	|	0,
	|	0,
	|	0,
	|	Calendar.Amount,
	|	Calendar.AmountCur,
	|	CAST(&ExpectedPayments AS STRING(100))
	|FROM
	|	TemporaryTablePaymentCalendar AS Calendar
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
	|	TemporaryTableAccountsPayable";

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
Procedure GenerateTableIncomeAndExpensesRetained(DocumentRefReportToCommissioner, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefReportToCommissioner);
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
	|	DocumentTable.BusinessLineSales AS BusinessLine,
	|	CASE
	|		WHEN DocumentTable.KeepBackComissionFee
	|			THEN DocumentTable.Cost - DocumentTable.CostVAT - (DocumentTable.BrokerageAmount - DocumentTable.BrokerageVATAmount)
	|		ELSE DocumentTable.Cost - DocumentTable.CostVAT
	|	END AS AmountExpense
	|FROM
	|	TemporaryTableInventory AS DocumentTable
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
Procedure GenerateTableUnallocatedExpenses(DocumentRefReportToCommissioner, StructureAdditionalProperties)
	
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
Procedure GenerateTableIncomeAndExpensesCashMethod(DocumentRefReportToCommissioner, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefReportToCommissioner);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("IncomeAndExpensesAccountingCashMethod", StructureAdditionalProperties.AccountingPolicy.IncomeAndExpensesAccountingCashMethod);
	
	Query.Text =
	"SELECT
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

// Payment calendar table formation procedure.
//
// Parameters:
// DocumentRef - DocumentRef.CashInflowForecast - Current
// document AdditionalProperties - AdditionalProperties - Additional properties of the document
//
Procedure GenerateTablePaymentCalendar(DocumentRefReportToCommissioner, StructureAdditionalProperties)
	
	Query = New Query;
	
	Query.SetParameter("Ref", DocumentRefReportToCommissioner);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	
	Query.Text =
	"SELECT
	|	AccountSalesToConsignor.Ref AS Ref,
	|	AccountSalesToConsignor.AmountIncludesVAT AS AmountIncludesVAT,
	|	AccountSalesToConsignor.Date AS Date,
	|	AccountSalesToConsignor.CashAssetsType AS CashAssetsType,
	|	AccountSalesToConsignor.Contract AS Contract,
	|	AccountSalesToConsignor.PettyCash AS PettyCash,
	|	AccountSalesToConsignor.DocumentCurrency AS DocumentCurrency,
	|	AccountSalesToConsignor.BankAccount AS BankAccount
	|INTO Document
	|FROM
	|	Document.AccountSalesToConsignor AS AccountSalesToConsignor
	|WHERE
	|	AccountSalesToConsignor.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccountSalesToConsignorPaymentCalendar.PaymentDate AS Period,
	|	Document.CashAssetsType AS CashAssetsType,
	|	Document.Ref AS Quote,
	|	CounterpartyContracts.SettlementsCurrency AS SettlementsCurrency,
	|	CounterpartyContracts.SettlementsInStandardUnits AS SettlementsInStandardUnits,
	|	Document.PettyCash AS PettyCash,
	|	Document.DocumentCurrency AS DocumentCurrency,
	|	Document.BankAccount AS BankAccount,
	|	Document.Ref AS Ref,
	|	CASE
	|		WHEN Document.AmountIncludesVAT
	|			THEN AccountSalesToConsignorPaymentCalendar.PaymentAmount
	|		ELSE AccountSalesToConsignorPaymentCalendar.PaymentAmount + AccountSalesToConsignorPaymentCalendar.PaymentVATAmount
	|	END AS PaymentAmount
	|INTO PaymentCalendar
	|FROM
	|	Document AS Document
	|		INNER JOIN Document.AccountSalesToConsignor.PaymentCalendar AS AccountSalesToConsignorPaymentCalendar
	|		ON Document.Ref = AccountSalesToConsignorPaymentCalendar.Ref
	|			AND (AccountSalesToConsignorPaymentCalendar.PaymentDate > Document.Date)
	|		LEFT JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
	|		ON Document.Contract = CounterpartyContracts.Ref
	|		INNER JOIN Constant.UsePaymentCalendar AS UsePaymentCalendar
	|		ON (UsePaymentCalendar.Value)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	PaymentCalendar.Period AS Period,
	|	&Company AS Company,
	|	PaymentCalendar.CashAssetsType AS CashAssetsType,
	|	VALUE(Enum.PaymentApprovalStatuses.Approved) AS PaymentConfirmationStatus,
	|	PaymentCalendar.Quote AS Quote,
	|	VALUE(Catalog.CashFlowItems.PaymentToVendor) AS Item,
	|	CASE
	|		WHEN PaymentCalendar.CashAssetsType = VALUE(Enum.CashAssetTypes.Cash)
	|			THEN PaymentCalendar.PettyCash
	|		WHEN PaymentCalendar.CashAssetsType = VALUE(Enum.CashAssetTypes.Noncash)
	|			THEN PaymentCalendar.BankAccount
	|		ELSE UNDEFINED
	|	END AS BankAccountPettyCash,
	|	CASE
	|		WHEN PaymentCalendar.SettlementsInStandardUnits
	|			THEN PaymentCalendar.SettlementsCurrency
	|		ELSE PaymentCalendar.DocumentCurrency
	|	END AS Currency,
	|	CASE
	|		WHEN PaymentCalendar.SettlementsInStandardUnits
	|			THEN CAST(-PaymentCalendar.PaymentAmount * CASE
	|						WHEN SettlementsExchangeRates.ExchangeRate <> 0
	|								AND ExchangeRatesOfDocument.Multiplicity <> 0
	|							THEN ExchangeRatesOfDocument.ExchangeRate * SettlementsExchangeRates.Multiplicity / (ISNULL(SettlementsExchangeRates.ExchangeRate, 1) * ISNULL(ExchangeRatesOfDocument.Multiplicity, 1))
	|						ELSE 1
	|					END AS NUMBER(15, 2))
	|		ELSE -PaymentCalendar.PaymentAmount
	|	END AS Amount
	|FROM
	|	PaymentCalendar AS PaymentCalendar
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&PointInTime, ) AS ExchangeRatesOfDocument
	|		ON PaymentCalendar.DocumentCurrency = ExchangeRatesOfDocument.Currency
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&PointInTime, ) AS SettlementsExchangeRates
	|		ON PaymentCalendar.SettlementsCurrency = SettlementsExchangeRates.Currency";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TablePaymentCalendar", QueryResult.Unload());
	
EndProcedure

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefReportToCommissioner, StructureAdditionalProperties) Export

	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	AccountSalesToConsignorInventory.LineNumber AS LineNumber,
	|	AccountSalesToConsignorInventory.ConnectionKey AS ConnectionKey,
	|	AccountSalesToConsignorInventory.Ref AS Ref,
	|	AccountSalesToConsignorInventory.Ref AS Document,
	|	AccountSalesToConsignorInventory.Ref.Date AS Period,
	|	&Company AS Company,
	|	AccountSalesToConsignorInventory.Ref.Counterparty AS Counterparty,
	|	AccountSalesToConsignorInventory.Ref.Counterparty.DoOperationsByContracts AS DoOperationsByContracts,
	|	AccountSalesToConsignorInventory.Ref.Counterparty.DoOperationsByDocuments AS DoOperationsByDocuments,
	|	AccountSalesToConsignorInventory.Ref.Counterparty.DoOperationsByOrders AS DoOperationsByOrders,
	|	AccountSalesToConsignorInventory.Ref.Counterparty.GLAccountVendorSettlements AS GLAccountVendorSettlements,
	|	AccountSalesToConsignorInventory.Ref.Contract AS Contract,
	|	AccountSalesToConsignorInventory.Ref.Contract.SettlementsCurrency AS SettlementsCurrency,
	|	AccountSalesToConsignorInventory.Ref.KeepBackComissionFee AS KeepBackComissionFee,
	|	AccountSalesToConsignorInventory.Ref.Department AS DepartmentSales,
	|	AccountSalesToConsignorInventory.Ref.Responsible AS Responsible,
	|	AccountSalesToConsignorInventory.Products.BusinessLine AS BusinessLineSales,
	|	AccountSalesToConsignorInventory.Products.BusinessLine.GLAccountRevenueFromSales AS AccountStatementSales,
	|	AccountSalesToConsignorInventory.Products.InventoryGLAccount AS GLAccount,
	|	AccountSalesToConsignorInventory.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN AccountSalesToConsignorInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseBatches
	|			THEN AccountSalesToConsignorInventory.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS Batch,
	|	CASE
	|		WHEN VALUETYPE(AccountSalesToConsignorInventory.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN AccountSalesToConsignorInventory.Quantity
	|		ELSE AccountSalesToConsignorInventory.Quantity * AccountSalesToConsignorInventory.MeasurementUnit.Factor
	|	END AS Quantity,
	|	AccountSalesToConsignorInventory.VATRate AS VATRate,
	|	CAST(CASE
	|			WHEN AccountSalesToConsignorInventory.Ref.IncludeVATInPrice
	|				THEN 0
	|			ELSE CASE
	|					WHEN AccountSalesToConsignorInventory.Ref.DocumentCurrency = ConstantNationalCurrency.Value
	|						THEN AccountSalesToConsignorInventory.VATAmount * RegExchangeRates.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * RegExchangeRates.Multiplicity)
	|					ELSE AccountSalesToConsignorInventory.VATAmount * AccountSalesToConsignorInventory.Ref.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * AccountSalesToConsignorInventory.Ref.Multiplicity)
	|				END
	|		END AS NUMBER(15, 2)) AS VATAmount,
	|	CAST(CASE
	|			WHEN AccountSalesToConsignorInventory.Ref.DocumentCurrency = ConstantNationalCurrency.Value
	|				THEN AccountSalesToConsignorInventory.VATAmount * RegExchangeRates.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * RegExchangeRates.Multiplicity)
	|			ELSE AccountSalesToConsignorInventory.VATAmount * AccountSalesToConsignorInventory.Ref.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * AccountSalesToConsignorInventory.Ref.Multiplicity)
	|		END AS NUMBER(15, 2)) AS VATAmountSales,
	|	CAST(CASE
	|			WHEN AccountSalesToConsignorInventory.Ref.DocumentCurrency = ConstantNationalCurrency.Value
	|				THEN AccountSalesToConsignorInventory.Total * RegExchangeRates.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * RegExchangeRates.Multiplicity)
	|			ELSE AccountSalesToConsignorInventory.Total * AccountSalesToConsignorInventory.Ref.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * AccountSalesToConsignorInventory.Ref.Multiplicity)
	|		END AS NUMBER(15, 2)) AS Amount,
	|	CAST(CASE
	|			WHEN AccountSalesToConsignorInventory.Ref.IncludeVATInPrice
	|				THEN 0
	|			ELSE CASE
	|					WHEN AccountSalesToConsignorInventory.Ref.DocumentCurrency = ConstantNationalCurrency.Value
	|						THEN AccountSalesToConsignorInventory.ReceiptVATAmount * RegExchangeRates.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * RegExchangeRates.Multiplicity)
	|					ELSE AccountSalesToConsignorInventory.ReceiptVATAmount * AccountSalesToConsignorInventory.Ref.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * AccountSalesToConsignorInventory.Ref.Multiplicity)
	|				END
	|		END AS NUMBER(15, 2)) AS CostVAT,
	|	CAST(CASE
	|			WHEN AccountSalesToConsignorInventory.Ref.DocumentCurrency = ConstantNationalCurrency.Value
	|				THEN AccountSalesToConsignorInventory.ReceiptVATAmount * RegExchangeRates.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * RegExchangeRates.Multiplicity)
	|			ELSE AccountSalesToConsignorInventory.ReceiptVATAmount * AccountSalesToConsignorInventory.Ref.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * AccountSalesToConsignorInventory.Ref.Multiplicity)
	|		END AS NUMBER(15, 2)) AS CostVATSale,
	|	CAST(CASE
	|			WHEN AccountSalesToConsignorInventory.Ref.DocumentCurrency = ConstantNationalCurrency.Value
	|				THEN CASE
	|						WHEN AccountSalesToConsignorInventory.Ref.AmountIncludesVAT
	|							THEN AccountSalesToConsignorInventory.AmountReceipt * RegExchangeRates.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * RegExchangeRates.Multiplicity)
	|						ELSE (AccountSalesToConsignorInventory.AmountReceipt + AccountSalesToConsignorInventory.ReceiptVATAmount) * RegExchangeRates.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * RegExchangeRates.Multiplicity)
	|					END
	|			ELSE CASE
	|					WHEN AccountSalesToConsignorInventory.Ref.AmountIncludesVAT
	|						THEN AccountSalesToConsignorInventory.AmountReceipt * AccountSalesToConsignorInventory.Ref.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * AccountSalesToConsignorInventory.Ref.Multiplicity)
	|					ELSE (AccountSalesToConsignorInventory.AmountReceipt + AccountSalesToConsignorInventory.ReceiptVATAmount) * AccountSalesToConsignorInventory.Ref.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * AccountSalesToConsignorInventory.Ref.Multiplicity)
	|				END
	|		END AS NUMBER(15, 2)) AS Cost,
	|	CAST(CASE
	|			WHEN AccountSalesToConsignorInventory.Ref.IncludeVATInPrice
	|				THEN 0
	|			ELSE CASE
	|					WHEN AccountSalesToConsignorInventory.Ref.DocumentCurrency = ConstantNationalCurrency.Value
	|						THEN AccountSalesToConsignorInventory.BrokerageVATAmount * RegExchangeRates.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * RegExchangeRates.Multiplicity)
	|					ELSE AccountSalesToConsignorInventory.BrokerageVATAmount * AccountSalesToConsignorInventory.Ref.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * AccountSalesToConsignorInventory.Ref.Multiplicity)
	|				END
	|		END AS NUMBER(15, 2)) AS BrokerageVATAmount,
	|	CAST(CASE
	|			WHEN AccountSalesToConsignorInventory.Ref.DocumentCurrency = ConstantNationalCurrency.Value
	|				THEN AccountSalesToConsignorInventory.BrokerageVATAmount * RegExchangeRates.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * RegExchangeRates.Multiplicity)
	|			ELSE AccountSalesToConsignorInventory.BrokerageVATAmount * AccountSalesToConsignorInventory.Ref.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * AccountSalesToConsignorInventory.Ref.Multiplicity)
	|		END AS NUMBER(15, 2)) AS AmountVATSaleBrokerages,
	|	CAST(CASE
	|			WHEN AccountSalesToConsignorInventory.Ref.DocumentCurrency = ConstantNationalCurrency.Value
	|				THEN CASE
	|						WHEN AccountSalesToConsignorInventory.Ref.AmountIncludesVAT
	|							THEN AccountSalesToConsignorInventory.BrokerageAmount * RegExchangeRates.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * RegExchangeRates.Multiplicity)
	|						ELSE (AccountSalesToConsignorInventory.BrokerageAmount + AccountSalesToConsignorInventory.BrokerageVATAmount) * RegExchangeRates.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * RegExchangeRates.Multiplicity)
	|					END
	|			ELSE CASE
	|					WHEN AccountSalesToConsignorInventory.Ref.AmountIncludesVAT
	|						THEN AccountSalesToConsignorInventory.BrokerageAmount * AccountSalesToConsignorInventory.Ref.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * AccountSalesToConsignorInventory.Ref.Multiplicity)
	|					ELSE (AccountSalesToConsignorInventory.BrokerageAmount + AccountSalesToConsignorInventory.BrokerageVATAmount) * AccountSalesToConsignorInventory.Ref.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * AccountSalesToConsignorInventory.Ref.Multiplicity)
	|				END
	|		END AS NUMBER(15, 2)) AS BrokerageAmount,
	|	CAST(CASE
	|			WHEN AccountSalesToConsignorInventory.Ref.IncludeVATInPrice
	|				THEN 0
	|			ELSE CASE
	|					WHEN AccountSalesToConsignorInventory.Ref.DocumentCurrency = ConstantNationalCurrency.Value
	|						THEN AccountSalesToConsignorInventory.BrokerageVATAmount * RegExchangeRates.ExchangeRate * AccountSalesToConsignorInventory.Ref.Multiplicity / (AccountSalesToConsignorInventory.Ref.ExchangeRate * RegExchangeRates.Multiplicity)
	|					ELSE AccountSalesToConsignorInventory.BrokerageVATAmount
	|				END
	|		END AS NUMBER(15, 2)) AS BrokerageVATAmountCur,
	|	CAST(CASE
	|			WHEN AccountSalesToConsignorInventory.Ref.IncludeVATInPrice
	|				THEN 0
	|			ELSE CASE
	|					WHEN AccountSalesToConsignorInventory.Ref.DocumentCurrency = ConstantNationalCurrency.Value
	|						THEN AccountSalesToConsignorInventory.ReceiptVATAmount * RegExchangeRates.ExchangeRate * AccountSalesToConsignorInventory.Ref.Multiplicity / (AccountSalesToConsignorInventory.Ref.ExchangeRate * RegExchangeRates.Multiplicity)
	|					ELSE AccountSalesToConsignorInventory.ReceiptVATAmount
	|				END
	|		END AS NUMBER(15, 2)) AS CostVATCur,
	|	CAST(CASE
	|			WHEN AccountSalesToConsignorInventory.Ref.IncludeVATInPrice
	|				THEN 0
	|			ELSE CASE
	|					WHEN AccountSalesToConsignorInventory.Ref.DocumentCurrency = ConstantNationalCurrency.Value
	|						THEN AccountSalesToConsignorInventory.VATAmount * RegExchangeRates.ExchangeRate * AccountSalesToConsignorInventory.Ref.Multiplicity / (AccountSalesToConsignorInventory.Ref.ExchangeRate * RegExchangeRates.Multiplicity)
	|					ELSE AccountSalesToConsignorInventory.VATAmount
	|				END
	|		END AS NUMBER(15, 2)) AS VATAmountCur,
	|	CAST(CASE
	|			WHEN AccountSalesToConsignorInventory.Ref.DocumentCurrency = ConstantNationalCurrency.Value
	|				THEN CASE
	|						WHEN AccountSalesToConsignorInventory.Ref.AmountIncludesVAT
	|							THEN AccountSalesToConsignorInventory.BrokerageAmount * RegExchangeRates.ExchangeRate * AccountSalesToConsignorInventory.Ref.Multiplicity / (AccountSalesToConsignorInventory.Ref.ExchangeRate * RegExchangeRates.Multiplicity)
	|						ELSE (AccountSalesToConsignorInventory.BrokerageAmount + AccountSalesToConsignorInventory.BrokerageVATAmount) * RegExchangeRates.ExchangeRate * AccountSalesToConsignorInventory.Ref.Multiplicity / (AccountSalesToConsignorInventory.Ref.ExchangeRate * RegExchangeRates.Multiplicity)
	|					END
	|			ELSE CASE
	|					WHEN AccountSalesToConsignorInventory.Ref.AmountIncludesVAT
	|						THEN AccountSalesToConsignorInventory.BrokerageAmount
	|					ELSE AccountSalesToConsignorInventory.BrokerageAmount + AccountSalesToConsignorInventory.BrokerageVATAmount
	|				END
	|		END AS NUMBER(15, 2)) AS BrokerageAmountCur,
	|	AccountSalesToConsignorInventory.ReceiptVATAmount AS ReceiptVATAmount,
	|	AccountSalesToConsignorInventory.SalesOrder AS SalesOrder,
	|	AccountSalesToConsignorInventory.SalesRep AS SalesRep,
	|	AccountSalesToConsignorInventory.PurchaseOrder AS PurchaseOrder,
	|	AccountSalesToConsignorInventory.Ref.VATCommissionFeePercent AS VATCommissionFeePercent,
	|	CAST(CASE
	|			WHEN AccountSalesToConsignorInventory.Ref.DocumentCurrency = ConstantNationalCurrency.Value
	|				THEN CASE
	|						WHEN AccountSalesToConsignorInventory.Ref.AmountIncludesVAT
	|							THEN AccountSalesToConsignorInventory.AmountReceipt * RegExchangeRates.ExchangeRate * AccountSalesToConsignorInventory.Ref.Multiplicity / (AccountSalesToConsignorInventory.Ref.ExchangeRate * RegExchangeRates.Multiplicity)
	|						ELSE (AccountSalesToConsignorInventory.AmountReceipt + AccountSalesToConsignorInventory.ReceiptVATAmount) * RegExchangeRates.ExchangeRate * AccountSalesToConsignorInventory.Ref.Multiplicity / (AccountSalesToConsignorInventory.Ref.ExchangeRate * RegExchangeRates.Multiplicity)
	|					END
	|			ELSE CASE
	|					WHEN AccountSalesToConsignorInventory.Ref.AmountIncludesVAT
	|						THEN AccountSalesToConsignorInventory.AmountReceipt
	|					ELSE AccountSalesToConsignorInventory.AmountReceipt + AccountSalesToConsignorInventory.ReceiptVATAmount
	|				END
	|		END AS NUMBER(15, 2)) AS CostPriceCur,
	|	CAST(CASE
	|			WHEN AccountSalesToConsignorInventory.Ref.AmountIncludesVAT
	|				THEN AccountSalesToConsignorInventory.AmountReceipt
	|			ELSE AccountSalesToConsignorInventory.AmountReceipt + AccountSalesToConsignorInventory.ReceiptVATAmount
	|		END AS NUMBER(15, 2)) AS SettlementsAmountTakenPassed,
	|	AccountSalesToConsignorInventory.Ref.SetPaymentTerms AS SetPaymentTerms
	|INTO TemporaryTableInventory
	|FROM
	|	Document.AccountSalesToConsignor.Inventory AS AccountSalesToConsignorInventory
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
	|	AccountSalesToConsignorInventory.Ref = &Ref
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
	|	DocumentTable.Order AS Order,
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
	|	SUM(DocumentTable.SettlementsAmount) AS AmountCur,
	|	DocumentTable.Ref.SetPaymentTerms AS SetPaymentTerms
	|INTO TemporaryTablePrepayment
	|FROM
	|	Document.AccountSalesToConsignor.Prepayment AS DocumentTable
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
	|	DocumentTable.Order,
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
	|	DocumentTable.Ref.Counterparty.DoOperationsByOrders,
	|	DocumentTable.Ref.SetPaymentTerms
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccountSalesToConsignorSerialNumbers.ConnectionKey AS ConnectionKey,
	|	AccountSalesToConsignorSerialNumbers.SerialNumber AS SerialNumber
	|INTO TemporaryTableSerialNumbers
	|FROM
	|	Document.AccountSalesToConsignor.SerialNumbers AS AccountSalesToConsignorSerialNumbers
	|WHERE
	|	AccountSalesToConsignorSerialNumbers.Ref = &Ref
	|	AND &UseSerialNumbers
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Calendar.LineNumber AS LineNumber,
	|	Calendar.Ref AS Ref,
	|	Calendar.PaymentDate AS PaymentDate,
	|	Calendar.PaymentAmount AS PaymentAmount,
	|	Calendar.PaymentVATAmount AS PaymentVATAmount
	|INTO TemporaryTablePaymentCalendarWithoutGroup
	|FROM
	|	Document.AccountSalesToConsignor.PaymentCalendar AS Calendar
	|WHERE
	|	Calendar.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Calendar.LineNumber AS LineNumber,
	|	Calendar.PaymentDate AS Period,
	|	&Company AS Company,
	|	Header.Counterparty AS Counterparty,
	|	CounterpartyRef.DoOperationsByContracts AS DoOperationsByContracts,
	|	CounterpartyRef.DoOperationsByDocuments AS DoOperationsByDocuments,
	|	CounterpartyRef.DoOperationsByOrders AS DoOperationsByOrders,
	|	CounterpartyRef.GLAccountCustomerSettlements AS GLAccountCustomerSettlements,
	|	Header.Contract AS Contract,
	|	CounterpartyContractsRef.SettlementsCurrency AS SettlementsCurrency,
	|	&Ref AS DocumentWhere,
	|	VALUE(Enum.SettlementsTypes.Debt) AS SettlemensTypeWhere,
	|	VALUE(Document.PurchaseOrder.EmptyRef) AS Order,
	|	CASE
	|		WHEN Header.AmountIncludesVAT
	|			THEN CAST(Calendar.PaymentAmount * Header.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * Header.Multiplicity) AS NUMBER(15, 2))
	|		ELSE CAST((Calendar.PaymentAmount + Calendar.PaymentVATAmount) * Header.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * Header.Multiplicity) AS NUMBER(15, 2))
	|	END AS Amount,
	|	CASE
	|		WHEN Header.AmountIncludesVAT
	|			THEN Calendar.PaymentAmount
	|		ELSE Calendar.PaymentAmount + Calendar.PaymentVATAmount
	|	END AS AmountCur
	|INTO TemporaryTablePaymentCalendarWithoutGroupWithHeader
	|FROM
	|	TemporaryTablePaymentCalendarWithoutGroup AS Calendar
	|		INNER JOIN Document.AccountSalesToConsignor AS Header
	|		ON (Header.Ref = Calendar.Ref)
	|		LEFT JOIN Catalog.Counterparties AS CounterpartyRef
	|		ON (CounterpartyRef.Ref = Header.Counterparty)
	|		LEFT JOIN Catalog.CounterpartyContracts AS CounterpartyContractsRef
	|		ON (CounterpartyContractsRef.Ref = Header.Contract)
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(
	|				&PointInTime,
	|				Currency IN
	|					(SELECT
	|						ConstantAccountingCurrency.Value
	|					FROM
	|						Constant.PresentationCurrency AS ConstantAccountingCurrency)) AS AccountingExchangeRatesSliceLast
	|		ON (TRUE)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MAX(Calendar.LineNumber) AS LineNumber,
	|	Calendar.Period AS Period,
	|	Calendar.Company AS Company,
	|	Calendar.Counterparty AS Counterparty,
	|	Calendar.DoOperationsByContracts AS DoOperationsByContracts,
	|	Calendar.DoOperationsByDocuments AS DoOperationsByDocuments,
	|	Calendar.DoOperationsByOrders AS DoOperationsByOrders,
	|	Calendar.GLAccountCustomerSettlements AS GLAccountCustomerSettlements,
	|	Calendar.Contract AS Contract,
	|	Calendar.SettlementsCurrency AS SettlementsCurrency,
	|	Calendar.DocumentWhere AS DocumentWhere,
	|	Calendar.SettlemensTypeWhere AS SettlemensTypeWhere,
	|	Calendar.Order AS Order,
	|	SUM(Calendar.Amount) AS Amount,
	|	SUM(Calendar.AmountCur) AS AmountCur
	|INTO TemporaryTablePaymentCalendar
	|FROM
	|	TemporaryTablePaymentCalendarWithoutGroupWithHeader AS Calendar
	|
	|GROUP BY
	|	Calendar.Period,
	|	Calendar.Company,
	|	Calendar.Counterparty,
	|	Calendar.DoOperationsByContracts,
	|	Calendar.DoOperationsByDocuments,
	|	Calendar.DoOperationsByOrders,
	|	Calendar.GLAccountCustomerSettlements,
	|	Calendar.Contract,
	|	Calendar.SettlementsCurrency,
	|	Calendar.DocumentWhere,
	|	Calendar.SettlemensTypeWhere,
	|	Calendar.Order
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP TemporaryTablePaymentCalendarWithoutGroup
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP TemporaryTablePaymentCalendarWithoutGroupWithHeader";
	
	Query.SetParameter("Ref", DocumentRefReportToCommissioner);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("UseCharacteristics", StructureAdditionalProperties.AccountingPolicy.UseCharacteristics);
	Query.SetParameter("UseBatches", StructureAdditionalProperties.AccountingPolicy.UseBatches);
	
	Query.SetParameter("UseSerialNumbers", StructureAdditionalProperties.AccountingPolicy.UseSerialNumbers);
	
	Query.ExecuteBatch();
	
	// Creation of document postings.
	DriveServer.GenerateTransactionsTable(DocumentRefReportToCommissioner, StructureAdditionalProperties);

	GenerateTableStockReceivedFromThirdParties(DocumentRefReportToCommissioner, StructureAdditionalProperties);
	GenerateTableSales(DocumentRefReportToCommissioner, StructureAdditionalProperties);
	GenerateTableAccountsPayable(DocumentRefReportToCommissioner, StructureAdditionalProperties);
	GenerateTableIncomeAndExpenses(DocumentRefReportToCommissioner, StructureAdditionalProperties);
	GenerateTableIncomeAndExpensesRetained(DocumentRefReportToCommissioner, StructureAdditionalProperties);
	GenerateTableUnallocatedExpenses(DocumentRefReportToCommissioner, StructureAdditionalProperties);
	GenerateTableIncomeAndExpensesCashMethod(DocumentRefReportToCommissioner, StructureAdditionalProperties);
	GenerateTablePaymentCalendar(DocumentRefReportToCommissioner, StructureAdditionalProperties);
	
	// Serial numbers
	GenerateTableSerialNumbers(DocumentRefReportToCommissioner, StructureAdditionalProperties);
	
	GenerateTableAccountingJournalEntries(DocumentRefReportToCommissioner, StructureAdditionalProperties);
	
EndProcedure

// Generates a table of values that contains the data for the SerialNumbersInWarranty information register.
// Tables of values saves into the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableSerialNumbers(DocumentRef, StructureAdditionalProperties)
	
	If DocumentRef.SerialNumbers.Count()=0 Then
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbersInWarranty", New ValueTable);
		Return;
	EndIf;
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	TemporaryTableInventory.Period AS Period,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TemporaryTableInventory.Period AS EventDate,
	|	VALUE(Enum.SerialNumbersOperations.Expense) AS Operation,		
	|	SerialNumbers.SerialNumber AS SerialNumber,
	|	TemporaryTableInventory.Products AS Products,
	|	TemporaryTableInventory.Characteristic AS Characteristic,
	|	1 AS Quantity
	|FROM
	|	TemporaryTableInventory AS TemporaryTableInventory
	|		INNER JOIN TemporaryTableSerialNumbers AS SerialNumbers
	|		ON TemporaryTableInventory.ConnectionKey = SerialNumbers.ConnectionKey";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbersInWarranty", QueryResult.Unload());
	
EndProcedure

// Controls the occurrence of negative balances.
//
Procedure RunControl(DocumentRefReportToCommissioner, AdditionalProperties, Cancel, PostingDelete = False) Export
	
	If Not DriveServer.RunBalanceControl() Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// If temporary tables "RegisterRecordsStockReceivedFromThirdPartiesChange" contain records,
	// control products implementation.
	If StructureTemporaryTables.RegisterRecordsStockReceivedFromThirdPartiesChange
	 OR StructureTemporaryTables.RegisterRecordsSuppliersSettlementsChange Then
	
		Query = New Query(
		"SELECT
		|	RegisterRecordsStockReceivedFromThirdPartiesChange.LineNumber AS LineNumber,
		|	REFPRESENTATION(RegisterRecordsStockReceivedFromThirdPartiesChange.Company) AS CompanyPresentation,
		|	REFPRESENTATION(RegisterRecordsStockReceivedFromThirdPartiesChange.Products) AS ProductsPresentation,
		|	REFPRESENTATION(RegisterRecordsStockReceivedFromThirdPartiesChange.Characteristic) AS CharacteristicPresentation,
		|	REFPRESENTATION(RegisterRecordsStockReceivedFromThirdPartiesChange.Batch) AS BatchPresentation,
		|	REFPRESENTATION(RegisterRecordsStockReceivedFromThirdPartiesChange.Counterparty) AS CounterpartyPresentation,
		|	REFPRESENTATION(RegisterRecordsStockReceivedFromThirdPartiesChange.Contract) AS ContractPresentation,
		|	REFPRESENTATION(RegisterRecordsStockReceivedFromThirdPartiesChange.Order) AS OrderPresentation,
		|	REFPRESENTATION(StockReceivedFromThirdPartiesBalances.Products.MeasurementUnit) AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsStockReceivedFromThirdPartiesChange.QuantityChange, 0) + ISNULL(StockReceivedFromThirdPartiesBalances.QuantityBalance, 0) AS BalanceStockReceivedFromThirdParties,
		|	ISNULL(StockReceivedFromThirdPartiesBalances.QuantityBalance, 0) AS QuantityBalanceStockReceivedFromThirdParties
		|FROM
		|	RegisterRecordsStockReceivedFromThirdPartiesChange AS RegisterRecordsStockReceivedFromThirdPartiesChange
		|		LEFT JOIN AccumulationRegister.StockReceivedFromThirdParties.Balance(
		|				&ControlTime,
		|				(Company, Products, Characteristic, Batch, Counterparty, Contract, Order) IN
		|					(SELECT
		|						RegisterRecordsStockReceivedFromThirdPartiesChange.Company AS Company,
		|						RegisterRecordsStockReceivedFromThirdPartiesChange.Products AS Products,
		|						RegisterRecordsStockReceivedFromThirdPartiesChange.Characteristic AS Characteristic,
		|						RegisterRecordsStockReceivedFromThirdPartiesChange.Batch AS Batch,
		|						RegisterRecordsStockReceivedFromThirdPartiesChange.Counterparty AS Counterparty,
		|						RegisterRecordsStockReceivedFromThirdPartiesChange.Contract AS Contract,
		|						RegisterRecordsStockReceivedFromThirdPartiesChange.Order AS Order
		|					FROM
		|						RegisterRecordsStockReceivedFromThirdPartiesChange AS RegisterRecordsStockReceivedFromThirdPartiesChange)) AS StockReceivedFromThirdPartiesBalances
		|		ON RegisterRecordsStockReceivedFromThirdPartiesChange.Company = StockReceivedFromThirdPartiesBalances.Company
		|			AND RegisterRecordsStockReceivedFromThirdPartiesChange.Products = StockReceivedFromThirdPartiesBalances.Products
		|			AND RegisterRecordsStockReceivedFromThirdPartiesChange.Characteristic = StockReceivedFromThirdPartiesBalances.Characteristic
		|			AND RegisterRecordsStockReceivedFromThirdPartiesChange.Batch = StockReceivedFromThirdPartiesBalances.Batch
		|			AND RegisterRecordsStockReceivedFromThirdPartiesChange.Counterparty = StockReceivedFromThirdPartiesBalances.Counterparty
		|			AND RegisterRecordsStockReceivedFromThirdPartiesChange.Contract = StockReceivedFromThirdPartiesBalances.Contract
		|			AND RegisterRecordsStockReceivedFromThirdPartiesChange.Order = StockReceivedFromThirdPartiesBalances.Order
		|WHERE
		|	ISNULL(StockReceivedFromThirdPartiesBalances.QuantityBalance, 0) < 0
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
			OR Not ResultsArray[1].IsEmpty() Then
			DocumentObjectAccountSalesToConsignor = DocumentRefReportToCommissioner.GetObject();
		EndIf;
		
		// Negative balance of inventory received.
		If Not ResultsArray[0].IsEmpty() Then
			QueryResultSelection = ResultsArray[0].Select();
			DriveServer.ShowMessageAboutPostingToStockReceivedFromThirdPartiesRegisterErrors(DocumentObjectAccountSalesToConsignor, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance on accounts payable.
		If Not ResultsArray[1].IsEmpty() Then
			QueryResultSelection = ResultsArray[1].Select();
			DriveServer.ShowMessageAboutPostingToAccountsPayableRegisterErrors(DocumentObjectAccountSalesToConsignor, QueryResultSelection, Cancel);
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region PrintInterface

// Function generates tabular document as certificate of
// services provided to the amount of reward
// 
Function PrintCertificate(ObjectsArray, PrintObjects)
	
	SpreadsheetDocument = New SpreadsheetDocument;
	SpreadsheetDocument.PrintParametersName = "PRINT_PARAMETERS_SalesAccountSalesToConsignor_ServicesReport";
	
	Query = New Query;
	
	Query.SetParameter("ObjectsArray", ObjectsArray);
	
	Query.Text =
	"SELECT
	|	SalesAccountSalesToConsignor.Ref,
	|	SalesAccountSalesToConsignor.Number,
	|	SalesAccountSalesToConsignor.Date,
	|	SalesAccountSalesToConsignor.Contract,
	|	SalesAccountSalesToConsignor.Counterparty AS Recipient,
	|	SalesAccountSalesToConsignor.Company AS Company,
	|	SalesAccountSalesToConsignor.Company AS Vendor,
	|	SalesAccountSalesToConsignor.DocumentAmount,
	|	SalesAccountSalesToConsignor.DocumentCurrency,
	|	SalesAccountSalesToConsignor.VATCommissionFeePercent,
	|	SUM(AccountSalesToConsignorInventory.BrokerageAmount) AS Amount
	|FROM
	|	Document.AccountSalesToConsignor.Inventory AS AccountSalesToConsignorInventory
	|		LEFT JOIN Document.AccountSalesToConsignor AS SalesAccountSalesToConsignor
	|		ON AccountSalesToConsignorInventory.Ref = SalesAccountSalesToConsignor.Ref
	|WHERE
	|	SalesAccountSalesToConsignor.Ref IN(&ObjectsArray)
	|
	|GROUP BY
	|	SalesAccountSalesToConsignor.Ref,
	|	SalesAccountSalesToConsignor.DocumentCurrency,
	|	SalesAccountSalesToConsignor.VATCommissionFeePercent,
	|	SalesAccountSalesToConsignor.Number,
	|	SalesAccountSalesToConsignor.Date,
	|	SalesAccountSalesToConsignor.Contract,
	|	SalesAccountSalesToConsignor.Counterparty,
	|	SalesAccountSalesToConsignor.Company,
	|	SalesAccountSalesToConsignor.DocumentAmount,
	|	SalesAccountSalesToConsignor.Company";

	Header = Query.Execute().Select();
	
	FirstDocument = True;
	
	While Header.Next() Do
		
		If Not FirstDocument Then
			SpreadsheetDocument.PutHorizontalPageBreak();
		EndIf;
		
		FirstDocument	= False;
		FirstLineNumber	= SpreadsheetDocument.TableHeight + 1;
		
		Template = GetTemplate("ServicesReport");
		
		TemplateArea = Template.GetArea("Header");
		TemplateArea.Parameters.Fill(Header);
		
		InfoAboutCompany	= DriveServer.InfoAboutLegalEntityIndividual(Header.Company, Header.Date);
		CompanyPresentation	= DriveServer.CompaniesDescriptionFull(InfoAboutCompany, "FullDescr");
		
		InfoAboutCounterparty		= DriveServer.InfoAboutLegalEntityIndividual(Header.Recipient, Header.Date);
		PresentationOfCounterparty	= DriveServer.CompaniesDescriptionFull(InfoAboutCounterparty, "FullDescr");
		
		TemplateArea.Parameters.VendorPresentation		= CompanyPresentation;
		TemplateArea.Parameters.RecipientPresentation	= PresentationOfCounterparty;
		
		TemplateArea.Parameters.HeaderText			= NStr("en = 'Acceptance note'");
		TemplateArea.Parameters.TextAboutSumInWords	= StringFunctionsClientServer.SubstituteParametersInString(
														NStr("en = 'Commission fee amount is %1, including VAT %2'"),
														DriveServer.FormatPaymentDocumentAmountInWords(
															Header.Amount,
															Header.DocumentCurrency.InWordParametersInHomeLanguage),
														Header.VATCommissionFeePercent);
		SpreadsheetDocument.Put(TemplateArea);
		PrintManagement.SetDocumentPrintArea(SpreadsheetDocument, FirstLineNumber, PrintObjects, Header.Ref);
		
	EndDo;
	
	Return SpreadsheetDocument;

EndFunction

// Function generates tabular document with invoice
// printing form developed by coordinator
//
// Returns:
//  Spreadsheet document - invoice printing form
//
Function AccountSalesToConsignorPrinting(ObjectsArray, PrintObjects)
	
	SpreadsheetDocument	= New SpreadsheetDocument;
	SpreadsheetDocument.PrintParametersName = "PRINT_PARAMETERS_SalesAccountSalesToConsignor_SalesAccountSalesToConsignor";
	Template				= GetTemplate("SalesAccountSalesToConsignor");
	
	Query = New Query;
	
	Query.SetParameter("ObjectsArray", ObjectsArray);
	
	Query.Text =
	"SELECT
	|	SalesAccountSalesToConsignor.Ref,
	|	SalesAccountSalesToConsignor.Number,
	|	SalesAccountSalesToConsignor.Date,
	|	SalesAccountSalesToConsignor.Contract,
	|	SalesAccountSalesToConsignor.Counterparty AS Recipient,
	|	SalesAccountSalesToConsignor.Company AS Company,
	|	SalesAccountSalesToConsignor.Company AS Vendor,
	|	SalesAccountSalesToConsignor.DocumentAmount,
	|	SalesAccountSalesToConsignor.DocumentCurrency,
	|	SalesAccountSalesToConsignor.AmountIncludesVAT,
	|	SalesAccountSalesToConsignor.VATCommissionFeePercent,
	|	SUM(AccountSalesToConsignorInventory.BrokerageAmount) AS BrokerageAmount
	|FROM
	|	Document.AccountSalesToConsignor.Inventory AS AccountSalesToConsignorInventory
	|		LEFT JOIN Document.AccountSalesToConsignor AS SalesAccountSalesToConsignor
	|		ON AccountSalesToConsignorInventory.Ref = SalesAccountSalesToConsignor.Ref
	|WHERE
	|	SalesAccountSalesToConsignor.Ref IN(&ObjectsArray)
	|
	|GROUP BY
	|	SalesAccountSalesToConsignor.Ref,
	|	SalesAccountSalesToConsignor.DocumentCurrency,
	|	SalesAccountSalesToConsignor.VATCommissionFeePercent,
	|	SalesAccountSalesToConsignor.Number,
	|	SalesAccountSalesToConsignor.Date,
	|	SalesAccountSalesToConsignor.Contract,
	|	SalesAccountSalesToConsignor.Counterparty,
	|	SalesAccountSalesToConsignor.Company,
	|	SalesAccountSalesToConsignor.DocumentAmount,
	|	SalesAccountSalesToConsignor.Company";

	Header = Query.Execute().Select();
	
	FirstDocument = True;
	
	While Header.Next() Do
		
		Template		= GetTemplate("SalesAccountSalesToConsignor");
		
		If Not FirstDocument Then
			
			SpreadsheetDocument.PutHorizontalPageBreak();
			
		EndIf;
		FirstDocument = False;
		
		FirstLineNumber = SpreadsheetDocument.TableHeight + 1;
		
		Query = New Query;
		
		Query.SetParameter("CurrentDocument", Header.Ref);
		
		Query.Text =
		"SELECT
		|	SalesAccountSalesToConsignorInventory.Products AS InventoryItem,
		|	SalesAccountSalesToConsignorInventory.Characteristic AS Characteristic,
		|	SalesAccountSalesToConsignorInventory.Products.Code AS Code,
		|	SalesAccountSalesToConsignorInventory.Products.SKU AS SKU,
		|	SalesAccountSalesToConsignorInventory.MeasurementUnit,
		|	SalesAccountSalesToConsignorInventory.Products.MeasurementUnit AS StorageUnit,
		|	SalesAccountSalesToConsignorInventory.Quantity AS Quantity,
		|	SalesAccountSalesToConsignorInventory.Price,
		|	SalesAccountSalesToConsignorInventory.Amount AS Amount,
		|	SalesAccountSalesToConsignorInventory.VATAmount AS VATAmount,
		|	SalesAccountSalesToConsignorInventory.Total AS Total,
		|	SalesAccountSalesToConsignorInventory.Customer AS Customer,
		|	SalesAccountSalesToConsignorInventory.DateOfSale AS SaleDate
		|FROM
		|	Document.AccountSalesToConsignor.Inventory AS SalesAccountSalesToConsignorInventory
		|WHERE
		|	SalesAccountSalesToConsignorInventory.Ref = &CurrentDocument
		|
		|ORDER BY
		|	Customer,
		|	SalesAccountSalesToConsignorInventory.LineNumber
		|TOTALS
		|	SUM(Quantity),
		|	SUM(Amount),
		|	SUM(VATAmount)
		|BY
		|	Customer";
		
		CustomersSelection = Query.Execute().Select(QueryResultIteration.ByGroups, "Customer");
		
		Total	= 0;
		SerialNumber = 1;
		
		// Displaying invoice header
		TemplateArea = Template.GetArea("Title");
		TemplateArea.Parameters.HeaderText = NStr("en = 'Account sales to consignor'");
		SpreadsheetDocument.Put(TemplateArea);

		InfoAboutCompany    = DriveServer.InfoAboutLegalEntityIndividual(Header.Company, Header.Date);
		CompanyPresentation = DriveServer.CompaniesDescriptionFull(InfoAboutCompany, "FullDescr,");
		
		InfoAboutCounterparty     = DriveServer.InfoAboutLegalEntityIndividual(Header.Recipient, Header.Date);
		PresentationOfCounterparty = DriveServer.CompaniesDescriptionFull(InfoAboutCounterparty, "FullDescr,");
		
		TemplateArea = Template.GetArea("Vendor");
		TemplateArea.Parameters.Fill(Header);
		TemplateArea.Parameters.VendorPresentation = PresentationOfCounterparty;
		TemplateArea.Parameters.Vendor               = Header.Recipient;
		SpreadsheetDocument.Put(TemplateArea);

		TemplateArea = Template.GetArea("Customer");
		TemplateArea.Parameters.Fill(Header);
		TemplateArea.Parameters.RecipientPresentation = CompanyPresentation;
		TemplateArea.Parameters.Recipient              = Header.Company;
		SpreadsheetDocument.Put(TemplateArea);

		TemplateArea = Template.GetArea("TableHeader");
		SpreadsheetDocument.Put(TemplateArea);

		While CustomersSelection.Next() Do
			
			InfoAboutCustomer = DriveServer.InfoAboutLegalEntityIndividual(CustomersSelection.Customer, CustomersSelection.SaleDate);
			TextCustomer = "Customer: " + DriveServer.CompaniesDescriptionFull(InfoAboutCustomer, "FullDescr,LegalAddress,TIN,");

			TemplateArea = Template.GetArea("RowCustomer");
			TemplateArea.Parameters.CustomerPresentation = TextCustomer;
			SpreadsheetDocument.Put(TemplateArea);
			
			TemplateArea = Template.GetArea("String");
			
			TotalByCounterparty = 0;
			
			StringSelectionProducts = CustomersSelection.Select();
			While StringSelectionProducts.Next() Do
				
				TemplateArea.Parameters.Fill(StringSelectionProducts);
				
				TemplateArea.Parameters.InventoryItem = DriveServer.GetProductsPresentationForPrinting(StringSelectionProducts.InventoryItem, 
					StringSelectionProducts.Characteristic, StringSelectionProducts.SKU);
					
				TemplateArea.Parameters.LineNumber = SerialNumber;
				
				If Not Header.AmountIncludesVAT Then
					
					AmountByRow 					= StringSelectionProducts.Total;
					TemplateArea.Parameters.Price	= ?(StringSelectionProducts.Quantity <> 0, Round(AmountByRow/StringSelectionProducts.Quantity, 2), 0);
					TemplateArea.Parameters.Amount	= AmountByRow;
					
				Else
					
					AmountByRow = StringSelectionProducts.Amount;
					
				EndIf;
				
				SpreadsheetDocument.Put(TemplateArea);
				
				SerialNumber		= SerialNumber			+ 1;
				Total				= Total 				+ AmountByRow;
				TotalByCounterparty	= TotalByCounterparty	+ AmountByRow;
				
			EndDo;
			
			TemplateArea = Template.GetArea("RowCustomerTotal");
			TemplateArea.Parameters.Fill(CustomersSelection);
			TemplateArea.Parameters.Amount = TotalByCounterparty;
			
			SpreadsheetDocument.Put(TemplateArea);
			
		EndDo;
		
		TemplateArea = Template.GetArea("Total");
		TemplateArea.Parameters.Total = Total;
		SpreadsheetDocument.Put(TemplateArea);
		
		TemplateArea = Template.GetArea("AmountInWords");
		TemplateArea.Parameters.AmountInWords	= DriveServer.FormatPaymentDocumentAmountInWords(Total,
													Header.DocumentCurrency.InWordParametersInHomeLanguage);
		TemplateArea.Parameters.BrokerageAmount	= StringFunctionsClientServer.SubstituteParametersInString(
													NStr("en = 'Commission fee amount is %1'"),
													DriveServer.FormatPaymentDocumentAmountInWords(
														Header.BrokerageAmount,
														Header.DocumentCurrency.InWordParametersInHomeLanguage));
		TemplateArea.Parameters.TotalRow		= StringFunctionsClientServer.SubstituteParametersInString(
													NStr("en = 'Total titles %1, in the amount of %2'"),
													StringSelectionProducts.Count(),
													DriveServer.AmountsFormat(Total, Header.DocumentCurrency));
		SpreadsheetDocument.Put(TemplateArea);
		
		TemplateArea = Template.GetArea("Signatures");
		TemplateArea.Parameters.Fill(Header);
		SpreadsheetDocument.Put(TemplateArea);
		
		PrintManagement.SetDocumentPrintArea(SpreadsheetDocument, FirstLineNumber, PrintObjects, Header.Ref);
		
	EndDo;
		
	Return SpreadsheetDocument;

EndFunction

// Procedure prints document. You can send printing to the screen or printer and print required number of copies.
//
//  Printing layout name is passed
// as a parameter, find layout name by the passed name in match.
//
// Parameters:
//  TemplateName - String, layout name.
//
Procedure Print(ObjectsArray, PrintParameters, PrintFormsCollection, PrintObjects, OutputParameters) Export
	
	If PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "ServicesAcceptanceCertificate") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection, "ServicesAcceptanceCertificate", "Services acceptance note", PrintCertificate(ObjectsArray, PrintObjects));
		
	EndIf;
	
	If PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "AccountSalesToConsignor") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection, "AccountSalesToConsignor", "Principal report", AccountSalesToConsignorPrinting(ObjectsArray, PrintObjects));
		
	EndIf;
	
	// parameters of sending printing forms by email
	DriveServer.FillSendingParameters(OutputParameters.SendingParameters, ObjectsArray, PrintFormsCollection);
	
EndProcedure

// Fills in the list of printing commands.
// 
// Parameters:
//   PrintCommands - ValueTable - see fields' content in the PrintManagement.CreatePrintCommandsCollection function.
//
Procedure AddPrintCommands(PrintCommands) Export
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID = "ServicesAcceptanceCertificate,AccountSalesToConsignor";
	PrintCommand.Presentation = NStr("en = 'Customizable document set'");
	PrintCommand.FormsList = "DocumentForm,ListForm";
	PrintCommand.CheckPostingBeforePrint = False;
	PrintCommand.Order = 1;
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID = "ServicesAcceptanceCertificate";
	PrintCommand.Presentation = NStr("en = 'Acceptance note'");
	PrintCommand.FormsList = "DocumentForm,ListForm";
	PrintCommand.CheckPostingBeforePrint = False;
	PrintCommand.Order = 4;
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID = "AccountSalesToConsignor";
	PrintCommand.Presentation = NStr("en = 'Account sales statement'");
	PrintCommand.FormsList = "DocumentForm,ListForm";
	PrintCommand.CheckPostingBeforePrint = False;
	PrintCommand.Order = 7;
	
EndProcedure

#EndRegion

#EndIf