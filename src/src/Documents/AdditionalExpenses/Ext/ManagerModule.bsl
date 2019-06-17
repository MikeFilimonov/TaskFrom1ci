#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventory(DocumentRefAdditionalExpenses, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	MIN(TableInventory.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TableInventory.Period AS Period,
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
	|	END AS SalesOrder,
	|	TRUE AS FixedCost,
	|	&InventoryIncrease AS ContentOfAccountingRecord,
	|	0 AS Quantity,
	|	SUM(TableInventory.AmountExpense) AS Amount
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|
	|GROUP BY
	|	TableInventory.Period,
	|	TableInventory.Company,
	|	TableInventory.StructuralUnit,
	|	TableInventory.GLAccount,
	|	TableInventory.Products,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	TableInventory.SalesOrder";
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();
	Query.SetParameter("InventoryIncrease", NStr("en = 'Landed costs'", MainLanguageCode));
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventory", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableAccountsPayable(DocumentRefAdditionalExpenses, StructureAdditionalProperties)
	
    Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
    "SELECT
	|	Sum(TemporaryTable.Amount) AS AmountWithVAT ,
	|	Sum(TemporaryTable.AmountCur) AS AmountWithVATCur 
	|FROM
	|	TemporaryTableExpenses AS TemporaryTable
	|GROUP BY
	|TemporaryTable.Period,
	|TemporaryTable.Company	";
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	AmountWithVAT = 0;
	AmountWithVATCur = 0;
	
	While Selection.Next() Do  
		AmountWithVAT		= Selection.AmountWithVAT;
		AmountWithVATCur	= Selection.AmountWithVATCur;
	EndDo;
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref",							DocumentRefAdditionalExpenses);
	Query.SetParameter("PointInTime",					New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod",					StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("Company",						StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("AppearenceOfLiabilityToVendor",	NStr("en = 'Accounts payable recognition'", MainLanguageCode));
	Query.SetParameter("AdvanceCredit",					NStr("en = 'Advance payment clearing'", MainLanguageCode));
	Query.SetParameter("ExchangeDifference",			NStr("en = 'Foreign currency exchange gains and losses'", MainLanguageCode));
	Query.SetParameter("AmountWithVAT",					AmountWithVAT);
	Query.SetParameter("AmountWithVATCur",				AmountWithVATCur);
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
	|			THEN &Ref
	|		ELSE UNDEFINED
	|	END AS Document,
	|	CASE
	|		WHEN DocumentTable.PurchaseOrder REFS Document.PurchaseOrder
	|				AND DocumentTable.PurchaseOrder <> VALUE(Document.PurchaseOrder.EmptyRef)
	|				AND DocumentTable.DoOperationsByOrders
	|			THEN DocumentTable.PurchaseOrder
	|		ELSE VALUE(Document.PurchaseOrder.EmptyRef)
	|	END AS Order,
	|	DocumentTable.SettlementsCurrency AS Currency,
	|	VALUE(Enum.SettlementsTypes.Debt) AS SettlementsType,
	|	&AmountWithVAT AS Amount,
	|	&AmountWithVATCur AS AmountCur,
	|	&AmountWithVAT AS AmountForBalance,
	|	&AmountWithVATCur AS AmountCurForBalance,
	|	CAST(&AppearenceOfLiabilityToVendor AS STRING(100)) AS ContentOfAccountingRecord,
	|	CASE
	|		WHEN DocumentTable.SetPaymentTerms
	|			THEN 0
	|		ELSE &AmountWithVAT
	|	END AS AmountForPayment,
	|	CASE
	|		WHEN DocumentTable.SetPaymentTerms
	|			THEN 0
	|		ELSE &AmountWithVATCur
	|	END AS AmountForPaymentCur
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
	|		WHEN DocumentTable.PurchaseOrder REFS Document.PurchaseOrder
	|				AND DocumentTable.PurchaseOrder <> VALUE(Document.PurchaseOrder.EmptyRef)
	|				AND DocumentTable.DoOperationsByOrders
	|			THEN DocumentTable.PurchaseOrder
	|		ELSE VALUE(Document.PurchaseOrder.EmptyRef)
	|	END,
	|	DocumentTable.SettlementsCurrency,
	|	DocumentTable.GLAccountVendorSettlements,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByDocuments
	|			THEN &Ref
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.SetPaymentTerms
	|			THEN 0
	|		ELSE &AmountWithVAT
	|	END,
	|	CASE
	|		WHEN DocumentTable.SetPaymentTerms
	|			THEN 0
	|		ELSE &AmountWithVATCur
	|	END
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
	|		WHEN DocumentTable.Order REFS Document.PurchaseOrder
	|				AND DocumentTable.Order <> VALUE(Document.PurchaseOrder.EmptyRef)
	|				AND DocumentTable.DoOperationsByOrders
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
	|	SUM(CASE
	|			WHEN DocumentTable.SetPaymentTerms
	|				THEN 0
	|			ELSE DocumentTable.Amount
	|		END),
	|	SUM(CASE
	|			WHEN DocumentTable.SetPaymentTerms
	|				THEN 0
	|			ELSE DocumentTable.AmountCur
	|		END)
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
	|		WHEN DocumentTable.Order REFS Document.PurchaseOrder
	|				AND DocumentTable.Order <> VALUE(Document.PurchaseOrder.EmptyRef)
	|				AND DocumentTable.DoOperationsByOrders
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
	|		WHEN DocumentTable.Order REFS Document.PurchaseOrder
	|				AND DocumentTable.Order <> VALUE(Document.PurchaseOrder.EmptyRef)
	|				AND DocumentTable.DoOperationsByOrders
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
	|	SUM(CASE
	|			WHEN DocumentTable.SetPaymentTerms
	|				THEN 0
	|			ELSE DocumentTable.Amount
	|		END),
	|	SUM(CASE
	|			WHEN DocumentTable.SetPaymentTerms
	|				THEN 0
	|			ELSE DocumentTable.AmountCur
	|		END)
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
	|		WHEN DocumentTable.Order REFS Document.PurchaseOrder
	|				AND DocumentTable.Order <> VALUE(Document.PurchaseOrder.EmptyRef)
	|				AND DocumentTable.DoOperationsByOrders
	|			THEN DocumentTable.Order
	|		ELSE VALUE(Document.PurchaseOrder.EmptyRef)
	|	END,
	|	DocumentTable.GLAccountVendorSettlements,
	|	DocumentTable.SettlementsCurrency,
	|	DocumentTable.SettlemensTypeWhere
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
	|	CAST(&ExpectedPayments AS STRING(100)),
	|	Calendar.Amount,
	|	Calendar.AmountCur
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
Procedure GenerateTablePurchases(DocumentRefAdditionalExpenses, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	TablePurchases.Period AS Period,
	|	TablePurchases.Company AS Company,
	|	TablePurchases.Products AS Products,
	|	TablePurchases.Characteristic AS Characteristic,
	|	TablePurchases.Batch AS Batch,
	|	TablePurchases.PurchaseOrder AS PurchaseOrder,
	|	TablePurchases.Document AS Document,
	|	TablePurchases.VATRate AS VATRate,
	|	SUM(TablePurchases.Quantity) AS Quantity,
	|	SUM(TablePurchases.AmountVATPurchase) AS VATAmount,
	|	SUM(TablePurchases.Amount - TablePurchases.AmountVATPurchase) AS Amount
	|FROM
	|	TemporaryTableExpenses AS TablePurchases
	|
	|GROUP BY
	|	TablePurchases.Period,
	|	TablePurchases.Company,
	|	TablePurchases.Products,
	|	TablePurchases.Characteristic,
	|	TablePurchases.Batch,
	|	TablePurchases.PurchaseOrder,
	|	TablePurchases.Document,
	|	TablePurchases.VATRate";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TablePurchases", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTablePurchaseOrders(DocumentRefAdditionalExpenses, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	MIN(TablePurchaseOrders.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TablePurchaseOrders.Period AS Period,
	|	TablePurchaseOrders.Company AS Company,
	|	TablePurchaseOrders.Products AS Products,
	|	TablePurchaseOrders.Characteristic AS Characteristic,
	|	TablePurchaseOrders.PurchaseOrder AS PurchaseOrder,
	|	SUM(TablePurchaseOrders.Quantity) AS Quantity
	|FROM
	|	TemporaryTableExpenses AS TablePurchaseOrders
	|WHERE
	|	TablePurchaseOrders.PurchaseOrder <> VALUE(Document.PurchaseOrder.EmptyRef)
	|
	|GROUP BY
	|	TablePurchaseOrders.Period,
	|	TablePurchaseOrders.Company,
	|	TablePurchaseOrders.Products,
	|	TablePurchaseOrders.Characteristic,
	|	TablePurchaseOrders.PurchaseOrder";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TablePurchaseOrders", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableIncomeAndExpenses(DocumentRefAdditionalExpenses, StructureAdditionalProperties)
	
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
	|	False AS OfflineRecord
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
	|	2,
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

	Query.SetParameter("PositiveExchangeDifferenceGLAccount",			Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeGain"));
	Query.SetParameter("NegativeExchangeDifferenceAccountOfAccounting",	Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeLoss"));
	Query.SetParameter("ExchangeDifference",							NStr("en = 'Foreign currency exchange gains and losses'", MainLanguageCode));
	Query.SetParameter("Ref",											DocumentRefAdditionalExpenses);
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpenses", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableIncomeAndExpensesRetained(DocumentRefAdditionalExpenses, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefAdditionalExpenses);
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
	|	TemporaryTableExpenses AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|
	|ORDER BY
	|	DocumentTable.LineNumber
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
	
	TableInventoryIncomeAndExpensesRetained =  ResultsArray[0].Unload();
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
Procedure GenerateTableUnallocatedExpenses(DocumentRefAdditionalExpenses, StructureAdditionalProperties)
	
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
Procedure GenerateTableIncomeAndExpensesCashMethod(DocumentRefAdditionalExpenses, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefAdditionalExpenses);
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

// Payment calendar table formation procedure.
//
// Parameters:
// DocumentRef - DocumentRef.CashInflowForecast - Current
// document AdditionalProperties - AdditionalProperties - Additional properties of the document
//
Procedure GenerateTablePaymentCalendar(DocumentRefAdditionalExpenses, StructureAdditionalProperties)
	
	Query = New Query;
	
	Query.SetParameter("Ref", DocumentRefAdditionalExpenses);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	
	Query.Text =
	"SELECT
	|	AdditionalExpenses.Ref AS Ref,
	|	AdditionalExpenses.AmountIncludesVAT AS AmountIncludesVAT,
	|	AdditionalExpenses.Date AS Date,
	|	AdditionalExpenses.CashAssetsType AS CashAssetsType,
	|	AdditionalExpenses.Contract AS Contract,
	|	AdditionalExpenses.PettyCash AS PettyCash,
	|	AdditionalExpenses.DocumentCurrency AS DocumentCurrency,
	|	AdditionalExpenses.BankAccount AS BankAccount
	|INTO Document
	|FROM
	|	Document.AdditionalExpenses AS AdditionalExpenses
	|WHERE
	|	AdditionalExpenses.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AdditionalExpensesPaymentCalendar.PaymentDate AS Period,
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
	|			THEN AdditionalExpensesPaymentCalendar.PaymentAmount
	|		ELSE AdditionalExpensesPaymentCalendar.PaymentAmount + AdditionalExpensesPaymentCalendar.PaymentVATAmount
	|	END AS PaymentAmount
	|INTO PaymentCalendar
	|FROM
	|	Document AS Document
	|		INNER JOIN Document.AdditionalExpenses.PaymentCalendar AS AdditionalExpensesPaymentCalendar
	|		ON Document.Ref = AdditionalExpensesPaymentCalendar.Ref
	|			AND (AdditionalExpensesPaymentCalendar.PaymentDate > Document.Date)
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

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableAccountingJournalEntries(DocumentRefAdditionalExpenses, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	1 AS Order,
	|	TableAccountingJournalEntries.Period AS Period,
	|	TableAccountingJournalEntries.Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	TableAccountingJournalEntries.GLAccount AS AccountDr,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccount.Currency
	|			THEN TableAccountingJournalEntries.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccount.Currency
	|			THEN TableAccountingJournalEntries.AmountExpenseCur
	|		ELSE 0
	|	END AS AmountCurDr,
	|	TableAccountingJournalEntries.GLAccountVendorSettlements AS AccountCr,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccountVendorSettlements.Currency
	|			THEN TableAccountingJournalEntries.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccountVendorSettlements.Currency
	|			THEN TableAccountingJournalEntries.AmountExpenseCur
	|		ELSE 0
	|	END AS AmountCurCr,
	|	TableAccountingJournalEntries.AmountExpense AS Amount,
	|	&InventoryIncrease AS Content,
	|	FALSE AS OfflineRecord
	|FROM
	|	TemporaryTableInventory AS TableAccountingJournalEntries
	|
	|UNION ALL
	|
	|SELECT
	|	2,
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
	|	3,
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
	|	4,
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
	|	TemporaryTableExpenses AS TableAccountingJournalEntries
	|WHERE
	|	TableAccountingJournalEntries.VATAmount > 0
	|
	|GROUP BY
	|	TableAccountingJournalEntries.Period,
	|	TableAccountingJournalEntries.Company,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccountVendorSettlements.Currency
	|			THEN TableAccountingJournalEntries.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	TableAccountingJournalEntries.GLAccountVendorSettlements,
	|	TableAccountingJournalEntries.VATInputGLAccount
	|
	|UNION ALL
	|
	|SELECT
	|	5,
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
	|	Order";
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();
	
	Query.SetParameter("InventoryIncrease",								NStr("en = 'Landed costs allocated to inventory'", MainLanguageCode));
	Query.SetParameter("SetOffAdvancePayment",							NStr("en = 'Advance payment clearing'", MainLanguageCode));
	Query.SetParameter("ExchangeDifference",							NStr("en = 'Foreign currency exchange gains and losses'", MainLanguageCode));
	Query.SetParameter("PositiveExchangeDifferenceGLAccount",			Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeGain"));
	Query.SetParameter("NegativeExchangeDifferenceAccountOfAccounting",	Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeLoss"));
	Query.SetParameter("VAT",											NStr("en = 'VAT'", MainLanguageCode));
	Query.SetParameter("Ref",											DocumentRefAdditionalExpenses);
	
	QueryResult = Query.Execute();
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountingJournalEntries", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableLandedCosts(DocumentRefAdditionalExpenses, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	MIN(TableInventory.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TableInventory.Period AS Period,
	|	TableInventory.Company AS Company,
	|	TableInventory.Products AS Products,
	|	CASE
	|		WHEN TableInventory.SalesOrder <> VALUE(Document.SalesOrder.EmptyRef)
	|				AND TableInventory.SalesOrder <> VALUE(Document.WorkOrder.EmptyRef)
	|			THEN TableInventory.SalesOrder
	|		ELSE UNDEFINED
	|	END AS SalesOrder,
	|	TableInventory.ReceiptDocument AS CostLayer,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	TableInventory.GLAccount AS GLAccount,
	|	SUM(TableInventory.AmountExpense) AS Amount,
	|	TRUE AS SourceRecord
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|WHERE
	|	NOT &FillAmount
	|	AND VALUETYPE(TableInventory.ReceiptDocument) = TYPE(Document.SupplierInvoice)
	|
	|GROUP BY
	|	TableInventory.Period,
	|	TableInventory.Company,
	|	TableInventory.Products,
	|	CASE
	|		WHEN TableInventory.SalesOrder <> VALUE(Document.SalesOrder.EmptyRef)
	|				AND TableInventory.SalesOrder <> VALUE(Document.WorkOrder.EmptyRef)
	|			THEN TableInventory.SalesOrder
	|		ELSE UNDEFINED
	|	END,
	|	TableInventory.ReceiptDocument,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	TableInventory.StructuralUnit,
	|	TableInventory.GLAccount";
	
	FillAmount = (StructureAdditionalProperties.AccountingPolicy.InventoryValuationMethod = Enums.InventoryValuationMethods.WeightedAverage);
	Query.SetParameter("FillAmount", FillAmount);
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableLandedCosts", QueryResult.Unload());
	
EndProcedure

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefAdditionalExpenses, StructureAdditionalProperties) Export
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	AdditionalExpensesInventory.LineNumber AS LineNumber,
	|	AdditionalExpensesInventory.Ref.Date AS Period,
	|	&Company AS Company,
	|	AdditionalExpensesInventory.Ref.Counterparty AS Counterparty,
	|	AdditionalExpensesInventory.Ref.Counterparty.DoOperationsByContracts AS DoOperationsByContracts,
	|	AdditionalExpensesInventory.Ref.Counterparty.DoOperationsByDocuments AS DoOperationsByDocuments,
	|	AdditionalExpensesInventory.Ref.Counterparty.DoOperationsByOrders AS DoOperationsByOrders,
	|	AdditionalExpensesInventory.Ref.Counterparty.GLAccountCustomerSettlements AS GLAccountCustomerSettlements,
	|	AdditionalExpensesInventory.Ref.Counterparty.GLAccountVendorSettlements AS GLAccountVendorSettlements,
	|	AdditionalExpensesInventory.Ref.Contract AS Contract,
	|	AdditionalExpensesInventory.Ref.Contract.SettlementsCurrency AS SettlementsCurrency,
	|	AdditionalExpensesInventory.Ref.PurchaseOrder AS PurchaseOrder,
	|	AdditionalExpensesInventory.Ref.StructuralUnit AS StructuralUnit,
	|	AdditionalExpensesInventory.InventoryGLAccount AS GLAccount,
	|	AdditionalExpensesInventory.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN AdditionalExpensesInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseBatches
	|			THEN AdditionalExpensesInventory.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS Batch,
	|	AdditionalExpensesInventory.SalesOrder AS SalesOrder,
	|	CASE
	|		WHEN VALUETYPE(AdditionalExpensesInventory.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN AdditionalExpensesInventory.Quantity
	|		ELSE AdditionalExpensesInventory.Quantity * AdditionalExpensesInventory.MeasurementUnit.Factor
	|	END AS Quantity,
	|	CAST(CASE
	|			WHEN AdditionalExpensesInventory.Ref.DocumentCurrency = ConstantNationalCurrency.Value
	|				THEN AdditionalExpensesInventory.Total * RegExchangeRates.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * RegExchangeRates.Multiplicity)
	|			ELSE AdditionalExpensesInventory.Total * AdditionalExpensesInventory.Ref.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * AdditionalExpensesInventory.Ref.Multiplicity)
	|		END AS NUMBER(15, 2)) AS Amount,
	|	CAST(CASE
	|			WHEN AdditionalExpensesInventory.Ref.DocumentCurrency = ConstantNationalCurrency.Value
	|				THEN AdditionalExpensesInventory.AmountExpense * RegExchangeRates.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * RegExchangeRates.Multiplicity)
	|			ELSE AdditionalExpensesInventory.AmountExpense * AdditionalExpensesInventory.Ref.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * AdditionalExpensesInventory.Ref.Multiplicity)
	|		END AS NUMBER(15, 2)) AS AmountExpense,
	|	CAST(CASE
	|			WHEN AdditionalExpensesInventory.Ref.DocumentCurrency = ConstantNationalCurrency.Value
	|				THEN AdditionalExpensesInventory.AmountExpense * RegExchangeRates.ExchangeRate * AdditionalExpensesInventory.Ref.Multiplicity / (AdditionalExpensesInventory.Ref.ExchangeRate * RegExchangeRates.Multiplicity)
	|			ELSE AdditionalExpensesInventory.AmountExpense
	|		END AS NUMBER(15, 2)) AS AmountExpenseCur,
	|	AdditionalExpensesInventory.Ref.SetPaymentTerms AS SetPaymentTerms,
	|	AdditionalExpensesInventory.ReceiptDocument AS ReceiptDocument
	|INTO TemporaryTableInventory
	|FROM
	|	Document.AdditionalExpenses.Inventory AS AdditionalExpensesInventory
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
	|	AdditionalExpensesInventory.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AdditionalExpensesExpenses.LineNumber AS LineNumber,
	|	AdditionalExpensesExpenses.Ref.Counterparty.DoOperationsByContracts AS DoOperationsByContracts,
	|	AdditionalExpensesExpenses.Ref.Counterparty.DoOperationsByDocuments AS DoOperationsByDocuments,
	|	AdditionalExpensesExpenses.Ref.Counterparty.DoOperationsByOrders AS DoOperationsByOrders,
	|	AdditionalExpensesExpenses.Ref.Date AS Period,
	|	AdditionalExpensesExpenses.Ref AS Document,
	|	AdditionalExpensesExpenses.Products.BusinessLine AS BusinessLine,
	|	&Company AS Company,
	|	AdditionalExpensesExpenses.Products AS Products,
	|	VALUE(Catalog.ProductsCharacteristics.EmptyRef) AS Characteristic,
	|	VALUE(Catalog.ProductsBatches.EmptyRef) AS Batch,
	|	AdditionalExpensesExpenses.Ref.PurchaseOrder AS PurchaseOrder,
	|	AdditionalExpensesExpenses.VATRate AS VATRate,
	|	CASE
	|		WHEN VALUETYPE(AdditionalExpensesExpenses.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN AdditionalExpensesExpenses.Quantity
	|		ELSE AdditionalExpensesExpenses.Quantity * AdditionalExpensesExpenses.MeasurementUnit.Factor
	|	END AS Quantity,
	|	CAST(CASE
	|			WHEN AdditionalExpensesExpenses.Ref.IncludeVATInPrice
	|				THEN 0
	|			ELSE CASE
	|					WHEN AdditionalExpensesExpenses.Ref.DocumentCurrency = ConstantNationalCurrency.Value
	|						THEN AdditionalExpensesExpenses.VATAmount * RegExchangeRates.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * RegExchangeRates.Multiplicity)
	|					ELSE AdditionalExpensesExpenses.VATAmount * AdditionalExpensesExpenses.Ref.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * AdditionalExpensesExpenses.Ref.Multiplicity)
	|				END
	|		END AS NUMBER(15, 2)) AS VATAmount,
	|	CAST(CASE
	|			WHEN AdditionalExpensesExpenses.Ref.DocumentCurrency = ConstantNationalCurrency.Value
	|				THEN AdditionalExpensesExpenses.VATAmount * RegExchangeRates.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * RegExchangeRates.Multiplicity)
	|			ELSE AdditionalExpensesExpenses.VATAmount * AdditionalExpensesExpenses.Ref.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * AdditionalExpensesExpenses.Ref.Multiplicity)
	|		END AS NUMBER(15, 2)) AS AmountVATPurchase,
	|	CAST(CASE
	|			WHEN AdditionalExpensesExpenses.Ref.DocumentCurrency = ConstantNationalCurrency.Value
	|				THEN AdditionalExpensesExpenses.Total * RegExchangeRates.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * RegExchangeRates.Multiplicity)
	|			ELSE AdditionalExpensesExpenses.Total * AdditionalExpensesExpenses.Ref.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * AdditionalExpensesExpenses.Ref.Multiplicity)
	|		END AS NUMBER(15, 2)) AS Amount,
	|	CAST(CASE
	|			WHEN AdditionalExpensesExpenses.Ref.DocumentCurrency = ConstantNationalCurrency.Value
	|				THEN AdditionalExpensesExpenses.VATAmount * RegExchangeRates.ExchangeRate * AdditionalExpensesExpenses.Ref.Multiplicity / (AdditionalExpensesExpenses.Ref.ExchangeRate * RegExchangeRates.Multiplicity)
	|			ELSE AdditionalExpensesExpenses.VATAmount
	|		END AS NUMBER(15, 2)) AS VATAmountCur,
	|	CAST(CASE
	|			WHEN AdditionalExpensesExpenses.Ref.DocumentCurrency = ConstantNationalCurrency.Value
	|				THEN AdditionalExpensesExpenses.Total * RegExchangeRates.ExchangeRate * AdditionalExpensesExpenses.Ref.Multiplicity / (AdditionalExpensesExpenses.Ref.ExchangeRate * RegExchangeRates.Multiplicity)
	|			ELSE AdditionalExpensesExpenses.Total
	|		END AS NUMBER(15, 2)) AS AmountCur,
	|	AdditionalExpensesExpenses.Ref.SetPaymentTerms AS SetPaymentTerms,
	|	AdditionalExpensesExpenses.Ref.Counterparty.GLAccountVendorSettlements AS GLAccountVendorSettlements,
	|	AdditionalExpensesExpenses.Ref.Contract.SettlementsCurrency AS SettlementsCurrency,
	|	AdditionalExpensesExpenses.VATInputGLAccount AS VATInputGLAccount
	|INTO TemporaryTableExpenses
	|FROM
	|	Document.AdditionalExpenses.Expenses AS AdditionalExpensesExpenses
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
	|	AdditionalExpensesExpenses.Ref = &Ref
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
	|	DocumentTable.Ref.PurchaseOrder AS Order,
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
	|	Document.AdditionalExpenses.Prepayment AS DocumentTable
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(
	|				&PointInTime,
	|				Currency IN
	|					(SELECT
	|						Constants.PresentationCurrency
	|					FROM
	|						Constants AS Constants)) AS AccountingExchangeRatesSliceLast
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
	|	DocumentTable.Ref.PurchaseOrder,
	|	DocumentTable.Ref.Counterparty.DoOperationsByContracts,
	|	DocumentTable.Ref.Counterparty.DoOperationsByDocuments,
	|	DocumentTable.Ref.Counterparty.DoOperationsByOrders,
	|	DocumentTable.Ref.SetPaymentTerms
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AdditionalExpensesPaymentCalendar.LineNumber AS LineNumber,
	|	AdditionalExpensesPaymentCalendar.Ref AS Ref,
	|	AdditionalExpensesPaymentCalendar.PaymentDate AS PaymentDate,
	|	AdditionalExpensesPaymentCalendar.PaymentAmount AS PaymentAmount,
	|	AdditionalExpensesPaymentCalendar.PaymentVATAmount AS PaymentVATAmount
	|INTO TemporaryTablePaymentCalendarWithoutGroup
	|FROM
	|	Document.AdditionalExpenses.PaymentCalendar AS AdditionalExpensesPaymentCalendar
	|WHERE
	|	AdditionalExpensesPaymentCalendar.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Calendar.LineNumber AS LineNumber,
	|	Calendar.PaymentDate AS Period,
	|	&Company AS Company,
	|	AdditionalExpenses.Counterparty AS Counterparty,
	|	CounterpartyRef.DoOperationsByContracts AS DoOperationsByContracts,
	|	CounterpartyRef.DoOperationsByDocuments AS DoOperationsByDocuments,
	|	CounterpartyRef.DoOperationsByOrders AS DoOperationsByOrders,
	|	CounterpartyRef.GLAccountCustomerSettlements AS GLAccountCustomerSettlements,
	|	AdditionalExpenses.Contract AS Contract,
	|	CounterpartyContractsRef.SettlementsCurrency AS SettlementsCurrency,
	|	&Ref AS DocumentWhere,
	|	VALUE(Enum.SettlementsTypes.Debt) AS SettlemensTypeWhere,
	|	VALUE(Document.PurchaseOrder.EmptyRef) AS Order,
	|	CASE
	|		WHEN AdditionalExpenses.AmountIncludesVAT
	|			THEN CAST(Calendar.PaymentAmount * AdditionalExpenses.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * AdditionalExpenses.Multiplicity) AS NUMBER(15, 2))
	|		ELSE CAST((Calendar.PaymentAmount + Calendar.PaymentVATAmount) * AdditionalExpenses.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * AdditionalExpenses.Multiplicity) AS NUMBER(15, 2))
	|	END AS Amount,
	|	CASE
	|		WHEN AdditionalExpenses.AmountIncludesVAT
	|			THEN Calendar.PaymentAmount
	|		ELSE Calendar.PaymentAmount + Calendar.PaymentVATAmount
	|	END AS AmountCur
	|INTO TemporaryTablePaymentCalendarWithoutGroupWithHeader
	|FROM
	|	TemporaryTablePaymentCalendarWithoutGroup AS Calendar
	|		INNER JOIN Document.AdditionalExpenses AS AdditionalExpenses
	|		ON (AdditionalExpenses.Ref = Calendar.Ref)
	|		LEFT JOIN Catalog.Counterparties AS CounterpartyRef
	|		ON (CounterpartyRef.Ref = AdditionalExpenses.Counterparty)
	|		LEFT JOIN Catalog.CounterpartyContracts AS CounterpartyContractsRef
	|		ON (CounterpartyContractsRef.Ref = AdditionalExpenses.Contract)
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
	
	Query.SetParameter("Ref", DocumentRefAdditionalExpenses);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("UseCharacteristics", StructureAdditionalProperties.AccountingPolicy.UseCharacteristics);
	Query.SetParameter("UseBatches", StructureAdditionalProperties.AccountingPolicy.UseBatches);
	
	Query.ExecuteBatch();
	
	GenerateTableInventory(DocumentRefAdditionalExpenses, StructureAdditionalProperties);
	GenerateTablePurchases(DocumentRefAdditionalExpenses, StructureAdditionalProperties);
	GenerateTablePurchaseOrders(DocumentRefAdditionalExpenses, StructureAdditionalProperties);
	GenerateTableAccountsPayable(DocumentRefAdditionalExpenses, StructureAdditionalProperties);
	GenerateTableIncomeAndExpenses(DocumentRefAdditionalExpenses, StructureAdditionalProperties);
	GenerateTableIncomeAndExpensesRetained(DocumentRefAdditionalExpenses, StructureAdditionalProperties);
	GenerateTableUnallocatedExpenses(DocumentRefAdditionalExpenses, StructureAdditionalProperties);
	GenerateTableIncomeAndExpensesCashMethod(DocumentRefAdditionalExpenses, StructureAdditionalProperties);
	GenerateTablePaymentCalendar(DocumentRefAdditionalExpenses, StructureAdditionalProperties);
	GenerateTableLandedCosts(DocumentRefAdditionalExpenses, StructureAdditionalProperties);
	GenerateTableAccountingJournalEntries(DocumentRefAdditionalExpenses, StructureAdditionalProperties);
	
EndProcedure

// Controls the occurrence of negative balances.
//
Procedure RunControl(DocumentRefAdditionalExpenses, AdditionalProperties, Cancel, PostingDelete = False) Export
	
	If Not DriveServer.RunBalanceControl() Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// If the temporary tables "RegisterRecordsSuppliersSettlementsChange", "RegisterRecordsPurchaseOrdersChange" contain records, 
	// it is required to execute the implementation products control.
	
	If StructureTemporaryTables.RegisterRecordsSuppliersSettlementsChange
	 OR StructureTemporaryTables.RegisterRecordsPurchaseOrdersChange Then
		
		Query = New Query(
		"SELECT
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
		|				(Company, PurchaseOrder, Products, Characteristic) In
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
		|				(Company, Counterparty, Contract, Document, Order, SettlementsType) In
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
			DocumentObjectAdditionalExpenses = DocumentRefAdditionalExpenses.GetObject()
		EndIf;
		
		// Negative balance by the purchase order.
		If Not ResultsArray[0].IsEmpty() Then
			QueryResultSelection = ResultsArray[0].Select();
			DriveServer.ShowMessageAboutPostingToPurchaseOrdersRegisterErrors(DocumentObjectAdditionalExpenses, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance on accounts payable.
		If Not ResultsArray[1].IsEmpty() Then
			QueryResultSelection = ResultsArray[1].Select();
			DriveServer.ShowMessageAboutPostingToAccountsPayableRegisterErrors(DocumentObjectAdditionalExpenses, QueryResultSelection, Cancel);
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

#Region InfobaseUpdate

Procedure FillNewGLAccounts() Export
	
	DocumentName = "AdditionalExpenses";
	
	Tables = New Array();
	
	// Table "Inventory"
	TableDecription = New Structure("Name, Conditions", "Inventory", New Array());
	
	GLAccountFields = ChartsOfAccounts.PrimaryChartOfAccounts.GLAccountFields();
	GLAccountFields.Source = "Products.InventoryGLAccount";
	GLAccountFields.Receiver = "InventoryGLAccount";
	TableDecription.Conditions.Add(GLAccountFields);
	
	Tables.Add(TableDecription);
	
	// Table "Expenses"
	TableDecription = New Structure("Name, Conditions", "Expenses", New Array());
	
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