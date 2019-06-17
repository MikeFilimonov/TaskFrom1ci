#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

Procedure GenerateTableGoodsAwaitingCustomsClearance(DocumentRef, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	MIN(TemporaryTableInventory.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TemporaryTableInventory.Period AS Period,
	|	TemporaryTableInventory.Company AS Company,
	|	TemporaryTableInventory.Supplier AS Counterparty,
	|	TemporaryTableInventory.SupplierContract AS Contract,
	|	TemporaryTableInventory.Invoice AS SupplierInvoice,
	|	TemporaryTableInventory.Products AS Products,
	|	TemporaryTableInventory.Characteristic AS Characteristic,
	|	TemporaryTableInventory.Batch AS Batch,
	|	SUM(TemporaryTableInventory.Quantity) AS Quantity
	|FROM
	|	TemporaryTableInventory AS TemporaryTableInventory
	|
	|GROUP BY
	|	TemporaryTableInventory.SupplierContract,
	|	TemporaryTableInventory.Characteristic,
	|	TemporaryTableInventory.Company,
	|	TemporaryTableInventory.Batch,
	|	TemporaryTableInventory.Period,
	|	TemporaryTableInventory.Invoice,
	|	TemporaryTableInventory.Supplier,
	|	TemporaryTableInventory.Products";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableGoodsAwaitingCustomsClearance", QueryResult.Unload());
	
EndProcedure

Procedure GenerateTableInventory(DocumentRef, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	TableInventory.LineNumber AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TableInventory.Period AS Period,
	|	TableInventory.Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	UNDEFINED AS CorrOrganization,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	UNDEFINED AS StructuralUnitCorr,
	|	TableInventory.GLAccount AS GLAccount,
	|	UNDEFINED AS CorrGLAccount,
	|	TableInventory.Products AS Products,
	|	UNDEFINED AS ProductsCorr,
	|	TableInventory.Characteristic AS Characteristic,
	|	UNDEFINED AS CharacteristicCorr,
	|	TableInventory.Batch AS Batch,
	|	UNDEFINED AS BatchCorr,
	|	TableInventory.VATRate AS VATRate,
	|	UNDEFINED AS Responsible,
	|	TableInventory.Invoice AS SalesDocument,
	|	CASE
	|		WHEN TableInventory.SalesOrder = VALUE(Document.SalesOrder.EmptyRef)
	|				OR TableInventory.SalesOrder = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE TableInventory.SalesOrder
	|	END AS SalesOrder,
	|	VALUE(Catalog.BusinessUnits.EmptyRef) AS Department,
	|	UNDEFINED AS SupplySource,
	|	UNDEFINED AS CustomerCorrOrder,
	|	CAST(&InventoryIncrease AS STRING(100)) AS ContentOfAccountingRecord,
	|	TRUE AS FixedCost,
	|	0 AS Quantity,
	|	TableInventory.Amount AS Amount
	|FROM
	|	TemporaryTableGroupedInventory AS TableInventory
	|WHERE
	|	TableInventory.Amount > 0
	|	AND &FillAmount";
	
	Query.SetParameter("RegisteredForVAT", StructureAdditionalProperties.AccountingPolicy.RegisteredForVAT);
	Query.SetParameter("InventoryIncrease", NStr("en = 'Customs fees'", StructureAdditionalProperties.DefaultLanguageCode));
	FillAmount = (StructureAdditionalProperties.AccountingPolicy.InventoryValuationMethod = Enums.InventoryValuationMethods.WeightedAverage);
	Query.SetParameter("FillAmount", FillAmount);
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventory", QueryResult.Unload());
	
EndProcedure

Procedure GenerateTableIncomeAndExpenses(DocumentRef, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	1 AS Ordering,
	|	MIN(TableIncomeAndExpenses.LineNumber) AS LineNumber,
	|	TableIncomeAndExpenses.Period AS Period,
	|	TableIncomeAndExpenses.Company AS Company,
	|	TableIncomeAndExpenses.StructuralUnit AS StructuralUnit,
	|	TableIncomeAndExpenses.BusinessLine AS BusinessLine,
	|	UNDEFINED AS SalesOrder,
	|	TableIncomeAndExpenses.OtherDutyGLAccount AS GLAccount,
	|	0 AS AmountIncome,
	|	SUM(TableIncomeAndExpenses.OtherDutyAmount) AS AmountExpense,
	|	SUM(TableIncomeAndExpenses.OtherDutyAmount) AS Amount,
	|	CAST(&OtherDutyExpenses AS STRING(100)) AS ContentOfAccountingRecord
	|FROM
	|	TemporaryTableInventory AS TableIncomeAndExpenses
	|WHERE
	|	TableIncomeAndExpenses.OtherDutyToExpenses
	|	AND TableIncomeAndExpenses.OtherDutyAmount > 0
	|
	|GROUP BY
	|	TableIncomeAndExpenses.StructuralUnit,
	|	TableIncomeAndExpenses.OtherDutyGLAccount,
	|	TableIncomeAndExpenses.BusinessLine,
	|	TableIncomeAndExpenses.Company,
	|	TableIncomeAndExpenses.Period
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	UNDEFINED,
	|	VALUE(Catalog.LinesOfBusiness.Other),
	|	UNDEFINED,
	|	CASE
	|		WHEN DocumentTable.ExchangeRateDifferenceAmount > 0
	|			THEN &ForeignCurrencyExchangeGain
	|		ELSE &ForeignCurrencyExchangeLoss
	|	END,
	|	CASE
	|		WHEN DocumentTable.ExchangeRateDifferenceAmount > 0
	|			THEN DocumentTable.ExchangeRateDifferenceAmount
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.ExchangeRateDifferenceAmount > 0
	|			THEN 0
	|		ELSE -DocumentTable.ExchangeRateDifferenceAmount
	|	END,
	|	CASE
	|		WHEN DocumentTable.ExchangeRateDifferenceAmount > 0
	|			THEN DocumentTable.ExchangeRateDifferenceAmount
	|		ELSE -DocumentTable.ExchangeRateDifferenceAmount
	|	END,
	|	&ExchangeDifference
	|FROM
	|	ExchangeDifferencesTemporaryTableOtherSettlements AS DocumentTable
	|
	|ORDER BY
	|	Ordering,
	|	LineNumber";
	
	Query.SetParameter("ForeignCurrencyExchangeGain",	Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeGain")); 
	Query.SetParameter("ForeignCurrencyExchangeLoss",	Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeLoss"));
	
	Query.SetParameter("OtherDutyExpenses",
		NStr("en = 'Other duty expenses'",
			StructureAdditionalProperties.DefaultLanguageCode));
			
	Query.SetParameter("ExchangeDifference",
		NStr("en = 'Foreign currency exchange gains and losses'",
			StructureAdditionalProperties.DefaultLanguageCode));

	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpenses", QueryResult.Unload());
	
EndProcedure

Procedure GenerateTableMiscellaneousPayable(DocumentRef, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Company",						StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("AccountingForOtherOperations",	NStr("en = 'Miscellaneous payables'",	StructureAdditionalProperties.DefaultLanguageCode));
	Query.SetParameter("Comment",						NStr("en = 'Payment to other accounts'", StructureAdditionalProperties.DefaultLanguageCode));
	Query.SetParameter("Ref",							DocumentRef);
	Query.SetParameter("PointInTime",					New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod",					StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("ExchangeRateDifference",		NStr("en = 'Foreign currency exchange gains and losses'", StructureAdditionalProperties.DefaultLanguageCode));
	Query.SetParameter("RegisteredForVAT",				StructureAdditionalProperties.AccountingPolicy.RegisteredForVAT);
	
	Query.Text =
	"SELECT
	|	TemporaryTablePaymentDetails.LineNumber AS LineNumber,
	|	TemporaryTablePaymentDetails.Counterparty AS Counterparty,
	|	TemporaryTablePaymentDetails.Contract AS Contract,
	|	TemporaryTablePaymentDetails.SettlementsCurrency AS Currency,
	|	TemporaryTablePaymentDetails.DutyAmount + TemporaryTablePaymentDetails.OtherDutyAmount + TemporaryTablePaymentDetails.ExciseAmount AS Amount,
	|	TemporaryTablePaymentDetails.DutyAmountCur + TemporaryTablePaymentDetails.OtherDutyAmountCur + TemporaryTablePaymentDetails.ExciseAmountCur AS AmountCur,
	|	TemporaryTablePaymentDetails.GLAccountVendorSettlements AS GLAccount,
	|	TemporaryTablePaymentDetails.Period AS Period
	|INTO TemporaryTableOtherSettlementsPre
	|FROM
	|	TemporaryTableInventory AS TemporaryTablePaymentDetails
	|
	|UNION ALL
	|
	|SELECT
	|	TemporaryTablePaymentDetails.LineNumber,
	|	TemporaryTablePaymentDetails.Counterparty,
	|	TemporaryTablePaymentDetails.Contract,
	|	TemporaryTablePaymentDetails.SettlementsCurrency,
	|	TemporaryTablePaymentDetails.VATAmount,
	|	TemporaryTablePaymentDetails.VATAmountCur,
	|	TemporaryTablePaymentDetails.GLAccountVendorSettlements,
	|	TemporaryTablePaymentDetails.Period
	|FROM
	|	TemporaryTableInventory AS TemporaryTablePaymentDetails
	|WHERE
	|	(TemporaryTablePaymentDetails.VATisDue = VALUE(Enum.VATDueOnCustomsClearance.OnTheSupply)
	|			OR NOT &RegisteredForVAT)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(TemporaryTablePaymentDetails.LineNumber) AS LineNumber,
	|	&Company AS Company,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TemporaryTablePaymentDetails.Counterparty AS Counterparty,
	|	TemporaryTablePaymentDetails.Contract AS Contract,
	|	TemporaryTablePaymentDetails.Currency AS Currency,
	|	TemporaryTablePaymentDetails.Period AS Date,
	|	SUM(TemporaryTablePaymentDetails.Amount) AS Amount,
	|	SUM(TemporaryTablePaymentDetails.AmountCur) AS AmountCur,
	|	SUM(TemporaryTablePaymentDetails.Amount) AS AmountForBalance,
	|	SUM(TemporaryTablePaymentDetails.AmountCur) AS AmountCurForBalance,
	|	&AccountingForOtherOperations AS PostingContent,
	|	&Comment AS Comment,
	|	TemporaryTablePaymentDetails.GLAccount AS GLAccount,
	|	TemporaryTablePaymentDetails.Period AS Period
	|INTO TemporaryTableOtherSettlements
	|FROM
	|	TemporaryTableOtherSettlementsPre AS TemporaryTablePaymentDetails
	|
	|GROUP BY
	|	TemporaryTablePaymentDetails.Counterparty,
	|	TemporaryTablePaymentDetails.Contract,
	|	TemporaryTablePaymentDetails.Currency,
	|	TemporaryTablePaymentDetails.GLAccount,
	|	TemporaryTablePaymentDetails.Period";
	
	QueryResult = Query.Execute();
	
	Query.Text =
	"SELECT
	|	TemporaryTableOtherSettlements.GLAccount AS GLAccount,
	|	TemporaryTableOtherSettlements.Company AS Company,
	|	TemporaryTableOtherSettlements.Counterparty AS Counterparty,
	|	TemporaryTableOtherSettlements.Contract AS Contract
	|FROM
	|	TemporaryTableOtherSettlements AS TemporaryTableOtherSettlements";
	
	QueryResult = Query.Execute();
	
	DataLock 			= New DataLock;
	LockItem 			= DataLock.Add("AccumulationRegister.MiscellaneousPayable");
	LockItem.Mode 		= DataLockMode.Exclusive;
	LockItem.DataSource	= QueryResult;
	
	For Each QueryResultColumn In QueryResult.Columns Do
		LockItem.UseFromDataSource(QueryResultColumn.Name, QueryResultColumn.Name);
	EndDo;
	
	DataLock.Lock();
	
	QueryNumber = 0;
	
	Query.Text = DriveServer.GetQueryTextExchangeRateDifferencesAccountingForOtherOperations(Query.TempTablesManager, QueryNumber);
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableMiscellaneousPayable", ResultsArray[QueryNumber].Unload());
	
EndProcedure

Procedure GenerateTableVATInput(DocumentRef, StructureAdditionalProperties)
	
	If Not StructureAdditionalProperties.AccountingPolicy.RegisteredForVAT Then
		
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableVATInput", New ValueTable);
		Return;
		
	EndIf;
	
	QueryText =
	"SELECT
	|	TemporaryTableInventory.Period AS Period,
	|	TemporaryTableInventory.Company AS Company,
	|	TemporaryTableInventory.Counterparty AS Supplier,
	|	TemporaryTableInventory.Document AS ShipmentDocument,
	|	TemporaryTableInventory.VATRate AS VATRate,
	|	SUM((TemporaryTableInventory.CustomsValueCur
	|		+ TemporaryTableInventory.DutyAmountCur
	|		+ TemporaryTableInventory.OtherDutyAmountCur
	|		+ TemporaryTableInventory.ExciseAmountCur
	|		+ TemporaryTableInventory.VATAmountCur) * TemporaryTableInventory.ExchangeRate / TemporaryTableInventory.Multiplicity) AS AmountExcludesVAT,
	|	SUM(TemporaryTableInventory.VATAmountCur * TemporaryTableInventory.ExchangeRate / TemporaryTableInventory.Multiplicity) AS VATAmount,
	|	CASE
	|		WHEN TemporaryTableInventory.VATisDue = VALUE(Enum.VATDueOnCustomsClearance.OnTheSupply)
	|			THEN VALUE(Enum.VATOperationTypes.Import)
	|		ELSE VALUE(Enum.VATOperationTypes.ReverseChargeApplied)
	|	END AS OperationType,
	|	TemporaryTableInventory.ProductsType AS ProductType
	|FROM
	|	TemporaryTableInventory AS TemporaryTableInventory
	|
	|GROUP BY
	|	TemporaryTableInventory.VATRate,
	|	CASE
	|		WHEN TemporaryTableInventory.VATisDue = VALUE(Enum.VATDueOnCustomsClearance.OnTheSupply)
	|			THEN VALUE(Enum.VATOperationTypes.Import)
	|		ELSE VALUE(Enum.VATOperationTypes.ReverseChargeApplied)
	|	END,
	|	TemporaryTableInventory.ProductsType,
	|	TemporaryTableInventory.Counterparty,
	|	TemporaryTableInventory.Company,
	|	TemporaryTableInventory.Period,
	|	TemporaryTableInventory.Document";
	
	Query = New Query(QueryText);
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableVATInput", QueryResult.Unload());
	
EndProcedure

Procedure GenerateTableVATOutput(DocumentRef, StructureAdditionalProperties)
	
	If Not StructureAdditionalProperties.AccountingPolicy.RegisteredForVAT Then
		
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableVATOutput", New ValueTable);
		Return;
		
	EndIf;
	
	QueryText =
	"SELECT
	|	TemporaryTableInventory.Period AS Period,
	|	TemporaryTableInventory.Company AS Company,
	|	TemporaryTableInventory.Counterparty AS Customer,
	|	TemporaryTableInventory.Document AS ShipmentDocument,
	|	TemporaryTableInventory.VATRate AS VATRate,
	|	SUM((TemporaryTableInventory.CustomsValueCur + TemporaryTableInventory.DutyAmountCur + TemporaryTableInventory.OtherDutyAmountCur + TemporaryTableInventory.ExciseAmountCur + TemporaryTableInventory.VATAmountCur) * TemporaryTableInventory.ExchangeRate / TemporaryTableInventory.Multiplicity) AS AmountExcludesVAT,
	|	SUM(TemporaryTableInventory.VATAmountCur * TemporaryTableInventory.ExchangeRate / TemporaryTableInventory.Multiplicity) AS VATAmount,
	|	VALUE(Enum.VATOperationTypes.ReverseChargeApplied) AS OperationType,
	|	TemporaryTableInventory.ProductsType AS ProductType
	|FROM
	|	TemporaryTableInventory AS TemporaryTableInventory
	|WHERE
	|	TemporaryTableInventory.VATisDue = VALUE(Enum.VATDueOnCustomsClearance.InTheVATReturn)
	|
	|GROUP BY
	|	TemporaryTableInventory.VATRate,
	|	TemporaryTableInventory.ProductsType,
	|	TemporaryTableInventory.Counterparty,
	|	TemporaryTableInventory.Company,
	|	TemporaryTableInventory.Period,
	|	TemporaryTableInventory.Document";
		
	Query = New Query(QueryText);
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableVATOutput", QueryResult.Unload());
	
EndProcedure

Procedure GenerateTableAccountingJournalEntries(DocumentRef, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	ISNULL(SUM(TemporaryTable.VATAmount), 0) AS VATAmount,
	|	ISNULL(SUM(TemporaryTable.VATAmountCur), 0) AS VATAmountCur,
	|	ISNULL(SUM(TemporaryTable.OtherDutyAmount), 0) AS OtherDutyAmount,
	|	ISNULL(SUM(TemporaryTable.OtherDutyAmountCur), 0) AS OtherDutyAmountCur
	|FROM
	|	TemporaryTableInventory AS TemporaryTable";
	
	Selection = Query.Execute().Select();
	Selection.Next();
	
	VATAmount			= Selection.VATAmount;
	VATAmountCur		= Selection.VATAmountCur;
	OtherDutyAmount		= Selection.OtherDutyAmount;
	OtherDutyAmountCur	= Selection.OtherDutyAmountCur;

	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	1 AS Ordering,
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
	|			THEN TableAccountingJournalEntries.DutyAmountCur + TableAccountingJournalEntries.OtherDutyAmountCur + TableAccountingJournalEntries.ExciseAmountCur
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
	|			THEN TableAccountingJournalEntries.DutyAmountCur + TableAccountingJournalEntries.OtherDutyAmountCur + TableAccountingJournalEntries.ExciseAmountCur
	|		ELSE 0
	|	END AS AmountCurCr,
	|	TableAccountingJournalEntries.DutyAmount + TableAccountingJournalEntries.OtherDutyAmount + TableAccountingJournalEntries.ExciseAmount AS Amount,
	|	&LandedСostsАccrued AS Content
	|FROM
	|	TemporaryTableInventory AS TableAccountingJournalEntries
	|WHERE
	|	NOT TableAccountingJournalEntries.OtherDutyToExpenses
	|	AND TableAccountingJournalEntries.DutyAmount + TableAccountingJournalEntries.OtherDutyAmount + TableAccountingJournalEntries.ExciseAmount > 0
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	TableAccountingJournalEntries.Period,
	|	TableAccountingJournalEntries.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	TableAccountingJournalEntries.GLAccount,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccount.Currency
	|			THEN TableAccountingJournalEntries.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccount.Currency
	|			THEN TableAccountingJournalEntries.DutyAmountCur + TableAccountingJournalEntries.ExciseAmountCur
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
	|			THEN TableAccountingJournalEntries.DutyAmountCur + TableAccountingJournalEntries.ExciseAmountCur
	|		ELSE 0
	|	END,
	|	TableAccountingJournalEntries.DutyAmount + TableAccountingJournalEntries.ExciseAmount,
	|	&LandedСostsАccrued
	|FROM
	|	TemporaryTableInventory AS TableAccountingJournalEntries
	|WHERE
	|	TableAccountingJournalEntries.OtherDutyToExpenses
	|	AND TableAccountingJournalEntries.DutyAmount + TableAccountingJournalEntries.ExciseAmount > 0
	|
	|UNION ALL
	|
	|SELECT
	|	3,
	|	TableAccountingJournalEntries.Period,
	|	TableAccountingJournalEntries.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	TableAccountingJournalEntries.GLAccount,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccount.Currency
	|			THEN TableAccountingJournalEntries.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccount.Currency
	|			THEN TableAccountingJournalEntries.VATAmountCur
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
	|			THEN TableAccountingJournalEntries.VATAmountCur
	|		ELSE 0
	|	END,
	|	TableAccountingJournalEntries.VATAmount,
	|	&VATIncludedInCost
	|FROM
	|	TemporaryTableInventory AS TableAccountingJournalEntries
	|WHERE
	|	NOT &RegisteredForVAT
	|	AND TableAccountingJournalEntries.VATAmount > 0
	|
	|UNION ALL
	|
	|SELECT TOP 1
	|	4,
	|	TableAccountingJournalEntries.Period,
	|	TableAccountingJournalEntries.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	TableAccountingJournalEntries.OtherDutyGLAccount,
	|	CASE
	|		WHEN TableAccountingJournalEntries.OtherDutyGLAccount.Currency
	|			THEN TableAccountingJournalEntries.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN TableAccountingJournalEntries.OtherDutyGLAccount.Currency
	|			THEN &OtherDutyAmountCur
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
	|			THEN &OtherDutyAmountCur
	|		ELSE 0
	|	END,
	|	&OtherDutyAmount,
	|	&ExpensesAccrued
	|FROM
	|	TemporaryTableInventory AS TableAccountingJournalEntries
	|WHERE
	|	TableAccountingJournalEntries.OtherDutyToExpenses
	|	AND &OtherDutyAmount > 0
	|
	|UNION ALL
	|
	|SELECT
	|	5,
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
	|	&VATDue
	|FROM
	|	TemporaryTableInventory AS TableAccountingJournalEntries
	|WHERE
	|	&RegisteredForVAT
	|	AND TableAccountingJournalEntries.VATIsDue = VALUE(Enum.VATDueOnCustomsClearance.OnTheSupply)
	|	AND TableAccountingJournalEntries.VATAmount > 0
	|
	|GROUP BY
	|	TableAccountingJournalEntries.VATInputGLAccount,
	|	TableAccountingJournalEntries.Company,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccountVendorSettlements.Currency
	|			THEN TableAccountingJournalEntries.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	TableAccountingJournalEntries.GLAccountVendorSettlements,
	|	TableAccountingJournalEntries.Period
	|
	|UNION ALL
	|
	|SELECT
	|	6,
	|	TableAccountingJournalEntries.Period,
	|	TableAccountingJournalEntries.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	&GLAccountVATReverseCharge,
	|	UNDEFINED,
	|	0,
	|	TableAccountingJournalEntries.VATOutputGLAccount,
	|	UNDEFINED,
	|	0,
	|	SUM(TableAccountingJournalEntries.VATAmount),
	|	&ReverseChargeVAT
	|FROM
	|	TemporaryTableInventory AS TableAccountingJournalEntries
	|WHERE
	|	&RegisteredForVAT
	|	AND TableAccountingJournalEntries.VATIsDue = VALUE(Enum.VATDueOnCustomsClearance.InTheVATReturn)
	|	AND &VATAmount > 0
	|
	|GROUP BY
	|	TableAccountingJournalEntries.VATOutputGLAccount,
	|	TableAccountingJournalEntries.Period,
	|	TableAccountingJournalEntries.Company
	|
	|UNION ALL
	|
	|SELECT TOP 1
	|	7,
	|	TableAccountingJournalEntries.Period,
	|	TableAccountingJournalEntries.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	TableAccountingJournalEntries.VATInputGLAccount,
	|	UNDEFINED,
	|	0,
	|	&GLAccountVATReverseCharge,
	|	UNDEFINED,
	|	0,
	|	SUM(TableAccountingJournalEntries.VATAmount),
	|	&ReverseChargeVATReclaimed
	|FROM
	|	TemporaryTableInventory AS TableAccountingJournalEntries
	|WHERE
	|	&RegisteredForVAT
	|	AND TableAccountingJournalEntries.VATIsDue = VALUE(Enum.VATDueOnCustomsClearance.InTheVATReturn)
	|	AND &VATAmount > 0
	|
	|GROUP BY
	|	TableAccountingJournalEntries.Period,
	|	TableAccountingJournalEntries.Company,
	|	TableAccountingJournalEntries.VATInputGLAccount
	|
	|UNION ALL
	|
	|SELECT
	|	8,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	CASE
	|		WHEN DocumentTable.ExchangeRateDifferenceAmount > 0
	|			THEN DocumentTable.GLAccount
	|		ELSE &ForeignCurrencyExchangeLoss
	|	END,
	|	CASE
	|		WHEN DocumentTable.ExchangeRateDifferenceAmount > 0
	|				AND DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	0,
	|	CASE
	|		WHEN DocumentTable.ExchangeRateDifferenceAmount > 0
	|			THEN &ForeignCurrencyExchangeGain
	|		ELSE DocumentTable.GLAccount
	|	END,
	|	CASE
	|		WHEN DocumentTable.ExchangeRateDifferenceAmount < 0
	|				AND DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	0,
	|	CASE
	|		WHEN DocumentTable.ExchangeRateDifferenceAmount > 0
	|			THEN DocumentTable.ExchangeRateDifferenceAmount
	|		ELSE -DocumentTable.ExchangeRateDifferenceAmount
	|	END,
	|	&ExchangeDifference
	|FROM
	|	ExchangeDifferencesTemporaryTableOtherSettlements AS DocumentTable
	|
	|ORDER BY
	|	Ordering";
	
	Query.SetParameter("ForeignCurrencyExchangeGain",	Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeGain"));
	Query.SetParameter("ForeignCurrencyExchangeLoss",	Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeLoss"));
	
	Query.SetParameter("GLAccountVATInput",			Catalogs.DefaultGLAccounts.GetDefaultGLAccount("VATInput"));
	Query.SetParameter("GLAccountVATOutput",		Catalogs.DefaultGLAccounts.GetDefaultGLAccount("VATOutput"));
	Query.SetParameter("GLAccountVATReverseCharge",	Catalogs.DefaultGLAccounts.GetDefaultGLAccount("VATReverseCharge"));
	Query.SetParameter("VATAmount",					VATAmount);
	Query.SetParameter("VATAmountCur",				VATAmountCur);
	Query.SetParameter("OtherDutyAmount",			OtherDutyAmount);
	Query.SetParameter("OtherDutyAmountCur",		OtherDutyAmountCur);
	Query.SetParameter("RegisteredForVAT",			StructureAdditionalProperties.AccountingPolicy.RegisteredForVAT);
	
	Query.SetParameter("LandedСostsАccrued",
		NStr("en = 'Landed costs accrued'",
			StructureAdditionalProperties.DefaultLanguageCode));
	
	Query.SetParameter("VATIncludedInCost",
		NStr("en = 'VAT included in cost'",
			StructureAdditionalProperties.DefaultLanguageCode));
	
	Query.SetParameter("ExpensesAccrued",
		NStr("en = 'Expenses accrued'",
			StructureAdditionalProperties.DefaultLanguageCode));
	
	Query.SetParameter("VATDue",
		NStr("en = 'VAT due'",
			StructureAdditionalProperties.DefaultLanguageCode));
	
	Query.SetParameter("ReverseChargeVAT",
		NStr("en = 'Reverse charge VAT'",
			StructureAdditionalProperties.DefaultLanguageCode));
	
	Query.SetParameter("ReverseChargeVATReclaimed",
		NStr("en = 'Reverse charge VAT reclaimed'",
			StructureAdditionalProperties.DefaultLanguageCode));
	
	Query.SetParameter("ExchangeDifference",
		NStr("en = 'Foreign currency exchange gains and losses'",
			StructureAdditionalProperties.DefaultLanguageCode));
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	
	While Selection.Next() Do
		NewEntry = StructureAdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries.Add();
		FillPropertyValues(NewEntry, Selection);
	EndDo;
	
EndProcedure

Procedure GenerateTableLandedCosts(DocumentRef, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	TableInventory.LineNumber AS LineNumber,
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
	|	TableInventory.Invoice AS CostLayer,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	TableInventory.GLAccount AS GLAccount,
	|	TableInventory.Amount AS Amount,
	|	TRUE AS SourceRecord
	|FROM
	|	TemporaryTableGroupedInventory AS TableInventory
	|WHERE
	|	TableInventory.Amount > 0
	|	AND NOT &FillAmount";
	
	FillAmount = (StructureAdditionalProperties.AccountingPolicy.InventoryValuationMethod = Enums.InventoryValuationMethods.WeightedAverage);
	Query.SetParameter("FillAmount", FillAmount);
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableLandedCosts", QueryResult.Unload());
	
EndProcedure

Procedure InitializeDocumentData(DocumentRef, StructureAdditionalProperties) Export
	
	StructureAdditionalProperties.Insert("DefaultLanguageCode", Metadata.DefaultLanguage.LanguageCode);
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	Header.Ref AS Ref,
	|	Header.Date AS Date,
	|	&Company AS Company,
	|	Header.Counterparty AS Counterparty,
	|	CatalogCounterparties.DoOperationsByContracts AS DoOperationsByContracts,
	|	CatalogCounterparties.DoOperationsByDocuments AS DoOperationsByDocuments,
	|	CatalogCounterparties.DoOperationsByOrders AS DoOperationsByOrders,
	|	CatalogCounterparties.GLAccountCustomerSettlements AS GLAccountCustomerSettlements,
	|	CatalogCounterparties.GLAccountVendorSettlements AS GLAccountVendorSettlements,
	|	Header.Contract AS Contract,
	|	CatalogCounterpartyContracts.SettlementsCurrency AS SettlementsCurrency,
	|	Header.Supplier AS Supplier,
	|	Header.SupplierContract AS SupplierContract,
	|	Header.DocumentCurrency AS DocumentCurrency,
	|	Header.ExchangeRate AS ExchangeRate,
	|	Header.Multiplicity AS Multiplicity,
	|	Header.VATIsDue AS VATIsDue,
	|	Header.OtherDutyToExpenses AS OtherDutyToExpenses,
	|	Header.OtherDutyGLAccount AS OtherDutyGLAccount
	|INTO TT_Header
	|FROM
	|	Document.CustomsDeclaration AS Header
	|		LEFT JOIN Catalog.Counterparties AS CatalogCounterparties
	|		ON Header.Counterparty = CatalogCounterparties.Ref
	|		LEFT JOIN Catalog.CounterpartyContracts AS CatalogCounterpartyContracts
	|		ON Header.Contract = CatalogCounterpartyContracts.Ref
	|WHERE
	|	Header.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ExchangeRatesSliceLast.Currency AS Currency,
	|	ExchangeRatesSliceLast.ExchangeRate AS ExchangeRate,
	|	ExchangeRatesSliceLast.Multiplicity AS Multiplicity
	|INTO TT_ExchangeRates
	|FROM
	|	InformationRegister.ExchangeRates.SliceLast(&PointInTime, Currency IN (&PresentationCurrency, &CurrencyNational)) AS ExchangeRatesSliceLast
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CustomsDeclarationInventory.LineNumber AS LineNumber,
	|	CustomsDeclarationInventory.Ref AS Document,
	|	Header.Date AS Period,
	|	Header.Company AS Company,
	|	Header.Counterparty AS Counterparty,
	|	Header.DoOperationsByContracts AS DoOperationsByContracts,
	|	Header.DoOperationsByDocuments AS DoOperationsByDocuments,
	|	Header.DoOperationsByOrders AS DoOperationsByOrders,
	|	Header.GLAccountCustomerSettlements AS GLAccountCustomerSettlements,
	|	Header.GLAccountVendorSettlements AS GLAccountVendorSettlements,
	|	Header.Contract AS Contract,
	|	Header.SettlementsCurrency AS SettlementsCurrency,
	|	Header.Supplier AS Supplier,
	|	Header.SupplierContract AS SupplierContract,
	|	Header.VATIsDue AS VATIsDue,
	|	Header.OtherDutyToExpenses AS OtherDutyToExpenses,
	|	Header.OtherDutyGLAccount AS OtherDutyGLAccount,
	|	CustomsDeclarationInventory.Products AS Products,
	|	CustomsDeclarationInventory.InventoryGLAccount AS GLAccount,
	|	CatalogProducts.ProductsType AS ProductsType,
	|	CatalogProducts.BusinessLine AS BusinessLine,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN CustomsDeclarationInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseBatches
	|			THEN CustomsDeclarationInventory.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS Batch,
	|	CustomsDeclarationInventory.Invoice AS Invoice,
	|	CustomsDeclarationInventory.StructuralUnit AS StructuralUnit,
	|	CatalogBusinessUnits.RetailPriceKind AS RetailPriceKind,
	|	CatalogPriceTypes.PriceCurrency AS PriceCurrency,
	|	CustomsDeclarationInventory.Quantity AS Quantity,
	|	CustomsDeclarationCommodityGroups.VATRate AS VATRate,
	|	CAST(CASE
	|			WHEN Header.DocumentCurrency = &CurrencyNational
	|				THEN CustomsDeclarationInventory.CustomsValue * RegExchangeRates.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * RegExchangeRates.Multiplicity)
	|			ELSE CustomsDeclarationInventory.CustomsValue * Header.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * Header.Multiplicity)
	|		END AS NUMBER(15, 2)) AS CustomsValue,
	|	CAST(CASE
	|			WHEN Header.DocumentCurrency = &CurrencyNational
	|				THEN CustomsDeclarationInventory.CustomsValue * RegExchangeRates.ExchangeRate * Header.Multiplicity / (Header.ExchangeRate * RegExchangeRates.Multiplicity)
	|			ELSE CustomsDeclarationInventory.CustomsValue
	|		END AS NUMBER(15, 2)) AS CustomsValueCur,
	|	CAST(CASE
	|			WHEN Header.DocumentCurrency = &CurrencyNational
	|				THEN CustomsDeclarationInventory.DutyAmount * RegExchangeRates.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * RegExchangeRates.Multiplicity)
	|			ELSE CustomsDeclarationInventory.DutyAmount * Header.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * Header.Multiplicity)
	|		END AS NUMBER(15, 2)) AS DutyAmount,
	|	CAST(CASE
	|			WHEN Header.DocumentCurrency = &CurrencyNational
	|				THEN CustomsDeclarationInventory.DutyAmount * RegExchangeRates.ExchangeRate * Header.Multiplicity / (Header.ExchangeRate * RegExchangeRates.Multiplicity)
	|			ELSE CustomsDeclarationInventory.DutyAmount
	|		END AS NUMBER(15, 2)) AS DutyAmountCur,
	|	CAST(CASE
	|			WHEN Header.DocumentCurrency = &CurrencyNational
	|				THEN CustomsDeclarationInventory.OtherDutyAmount * RegExchangeRates.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * RegExchangeRates.Multiplicity)
	|			ELSE CustomsDeclarationInventory.OtherDutyAmount * Header.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * Header.Multiplicity)
	|		END AS NUMBER(15, 2)) AS OtherDutyAmount,
	|	CAST(CASE
	|			WHEN Header.DocumentCurrency = &CurrencyNational
	|				THEN CustomsDeclarationInventory.OtherDutyAmount * RegExchangeRates.ExchangeRate * Header.Multiplicity / (Header.ExchangeRate * RegExchangeRates.Multiplicity)
	|			ELSE CustomsDeclarationInventory.OtherDutyAmount
	|		END AS NUMBER(15, 2)) AS OtherDutyAmountCur,
	|	CAST(CASE
	|			WHEN Header.DocumentCurrency = &CurrencyNational
	|				THEN CustomsDeclarationInventory.ExciseAmount * RegExchangeRates.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * RegExchangeRates.Multiplicity)
	|			ELSE CustomsDeclarationInventory.ExciseAmount * Header.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * Header.Multiplicity)
	|		END AS NUMBER(15, 2)) AS ExciseAmount,
	|	CAST(CASE
	|			WHEN Header.DocumentCurrency = &CurrencyNational
	|				THEN CustomsDeclarationInventory.ExciseAmount * RegExchangeRates.ExchangeRate * Header.Multiplicity / (Header.ExchangeRate * RegExchangeRates.Multiplicity)
	|			ELSE CustomsDeclarationInventory.ExciseAmount
	|		END AS NUMBER(15, 2)) AS ExciseAmountCur,
	|	CAST(CASE
	|			WHEN Header.DocumentCurrency = &CurrencyNational
	|				THEN CustomsDeclarationInventory.VATAmount * RegExchangeRates.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * RegExchangeRates.Multiplicity)
	|			ELSE CustomsDeclarationInventory.VATAmount * Header.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * Header.Multiplicity)
	|		END AS NUMBER(15, 2)) AS VATAmount,
	|	CAST(CASE
	|			WHEN Header.DocumentCurrency = &CurrencyNational
	|				THEN CustomsDeclarationInventory.VATAmount * RegExchangeRates.ExchangeRate * Header.Multiplicity / (Header.ExchangeRate * RegExchangeRates.Multiplicity)
	|			ELSE CustomsDeclarationInventory.VATAmount
	|		END AS NUMBER(15, 2)) AS VATAmountCur,
	|	Header.ExchangeRate AS ExchangeRate,
	|	Header.Multiplicity AS Multiplicity,
	|	CustomsDeclarationInventory.VATInputGLAccount AS VATInputGLAccount,
	|	CustomsDeclarationInventory.VATOutputGLAccount AS VATOutputGLAccount
	|INTO TemporaryTableInventory
	|FROM
	|	TT_Header AS Header
	|		INNER JOIN Document.CustomsDeclaration.CommodityGroups AS CustomsDeclarationCommodityGroups
	|		ON Header.Ref = CustomsDeclarationCommodityGroups.Ref
	|		INNER JOIN Document.CustomsDeclaration.Inventory AS CustomsDeclarationInventory
	|		ON Header.Ref = CustomsDeclarationInventory.Ref
	|			AND (CustomsDeclarationCommodityGroups.CommodityGroup = CustomsDeclarationInventory.CommodityGroup)
	|		LEFT JOIN Catalog.Products AS CatalogProducts
	|		ON (CustomsDeclarationInventory.Products = CatalogProducts.Ref)
	|		LEFT JOIN Catalog.LinesOfBusiness AS CatalogLinesOfBusiness
	|		ON (CatalogProducts.BusinessLine = CatalogLinesOfBusiness.Ref)
	|		LEFT JOIN Catalog.BusinessUnits AS CatalogBusinessUnits
	|		ON (CustomsDeclarationInventory.StructuralUnit = CatalogBusinessUnits.Ref)
	|		LEFT JOIN Catalog.PriceTypes AS CatalogPriceTypes
	|		ON (CatalogBusinessUnits.RetailPriceKind = CatalogPriceTypes.Ref)
	|		LEFT JOIN TT_ExchangeRates AS ManagExchangeRates
	|		ON (ManagExchangeRates.Currency = &PresentationCurrency)
	|		LEFT JOIN TT_ExchangeRates AS RegExchangeRates
	|		ON (RegExchangeRates.Currency = &CurrencyNational)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(TableInventory.LineNumber) AS LineNumber,
	|	TableInventory.Period AS Period,
	|	TableInventory.Company AS Company,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	TableInventory.GLAccount AS GLAccount,
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.VATRate AS VATRate,
	|	TableInventory.Invoice AS Invoice,
	|	VALUE(Document.SalesOrder.EmptyRef) AS SalesOrder,
	|	SUM(TableInventory.DutyAmount + TableInventory.ExciseAmount + CASE
	|			WHEN TableInventory.OtherDutyToExpenses
	|				THEN 0
	|			ELSE TableInventory.OtherDutyAmount
	|		END + CASE
	|			WHEN &RegisteredForVAT
	|				THEN 0
	|			ELSE TableInventory.VATAmount
	|		END) AS Amount
	|INTO TemporaryTableGroupedInventory
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
	|	TableInventory.VATRate,
	|	TableInventory.Invoice";
	
	Query.SetParameter("Ref",					DocumentRef);
	Query.SetParameter("Company",				StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PointInTime",			New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("UseCharacteristics",	StructureAdditionalProperties.AccountingPolicy.UseCharacteristics);
	Query.SetParameter("UseBatches",			StructureAdditionalProperties.AccountingPolicy.UseBatches);
	
	Query.SetParameter("PresentationCurrency",	Constants.PresentationCurrency.Get());
	Query.SetParameter("CurrencyNational",		Constants.FunctionalCurrency.Get());
	
	Query.SetParameter("RegisteredForVAT",		StructureAdditionalProperties.AccountingPolicy.RegisteredForVAT);
	
	Query.ExecuteBatch();
	
	// Creation of document postings.
	DriveServer.GenerateTransactionsTable(DocumentRef, StructureAdditionalProperties);
	
	GenerateTableGoodsAwaitingCustomsClearance(DocumentRef, StructureAdditionalProperties);
	GenerateTableInventory(DocumentRef, StructureAdditionalProperties);
	GenerateTableMiscellaneousPayable(DocumentRef, StructureAdditionalProperties);
	GenerateTableIncomeAndExpenses(DocumentRef, StructureAdditionalProperties);
	GenerateTableVATInput(DocumentRef, StructureAdditionalProperties);
	GenerateTableVATOutput(DocumentRef, StructureAdditionalProperties);
	GenerateTableAccountingJournalEntries(DocumentRef, StructureAdditionalProperties);
	GenerateTableLandedCosts(DocumentRef, StructureAdditionalProperties);
	
EndProcedure

Procedure RunControl(DocumentRef, AdditionalProperties, Cancel, PostingDelete = False) Export
	
	If Not DriveServer.RunBalanceControl() Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	If StructureTemporaryTables.RegisterRecordsInventoryChange
		OR StructureTemporaryTables.RegisterRecordsGoodsAwaitingCustomsClearanceChange Then
		
		Query = New Query(
		"SELECT
		|	RegisterRecordsInventoryChange.LineNumber AS LineNumber,
		|	RegisterRecordsInventoryChange.Company AS CompanyPresentation,
		|	RegisterRecordsInventoryChange.StructuralUnit AS StructuralUnitPresentation,
		|	RegisterRecordsInventoryChange.GLAccount AS GLAccountPresentation,
		|	RegisterRecordsInventoryChange.Products AS ProductsPresentation,
		|	RegisterRecordsInventoryChange.Characteristic AS CharacteristicPresentation,
		|	RegisterRecordsInventoryChange.Batch AS BatchPresentation,
		|	RegisterRecordsInventoryChange.SalesOrder AS SalesOrderPresentation,
		|	InventoryBalances.StructuralUnit.StructuralUnitType AS StructuralUnitType,
		|	InventoryBalances.Products.MeasurementUnit AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsInventoryChange.QuantityChange, 0) + ISNULL(InventoryBalances.QuantityBalance, 0) AS BalanceInventory,
		|	ISNULL(InventoryBalances.QuantityBalance, 0) AS QuantityBalanceInventory,
		|	ISNULL(InventoryBalances.AmountBalance, 0) AS AmountBalanceInventory
		|FROM
		|	RegisterRecordsInventoryChange AS RegisterRecordsInventoryChange
		|		INNER JOIN AccumulationRegister.Inventory.Balance(&ControlTime, ) AS InventoryBalances
		|		ON RegisterRecordsInventoryChange.Company = InventoryBalances.Company
		|			AND RegisterRecordsInventoryChange.StructuralUnit = InventoryBalances.StructuralUnit
		|			AND RegisterRecordsInventoryChange.GLAccount = InventoryBalances.GLAccount
		|			AND RegisterRecordsInventoryChange.Products = InventoryBalances.Products
		|			AND RegisterRecordsInventoryChange.Characteristic = InventoryBalances.Characteristic
		|			AND RegisterRecordsInventoryChange.Batch = InventoryBalances.Batch
		|			AND RegisterRecordsInventoryChange.SalesOrder = InventoryBalances.SalesOrder
		|			AND (ISNULL(InventoryBalances.QuantityBalance, 0) < 0)
		|
		|ORDER BY
		|	LineNumber");
		
		Query.Text = Query.Text + DriveClientServer.GetQueryDelimeter();
		Query.Text = Query.Text + AccumulationRegisters.GoodsAwaitingCustomsClearance.BalancesControlQueryText();
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.SetParameter("ControlTime", AdditionalProperties.ForPosting.ControlTime);
		
		ResultsArray = Query.ExecuteBatch();
		
		If Not ResultsArray[0].IsEmpty()
			OR Not ResultsArray[1].IsEmpty() Then
			DocumentObjectSupplierInvoice = DocumentRef.GetObject()
		EndIf;
		
		If Not ResultsArray[0].IsEmpty() Then
			QueryResultSelection = ResultsArray[0].Select();
			DriveServer.ShowMessageAboutPostingToInventoryRegisterErrors(DocumentObjectSupplierInvoice, QueryResultSelection, Cancel);
		EndIf;
		
		If Not ResultsArray[1].IsEmpty() Then
			QueryResultSelection = ResultsArray[1].Select();
			DriveServer.ShowMessageAboutPostingToGoodsAwaitingCustomsClearanceRegisterErrors(DocumentObjectSupplierInvoice, QueryResultSelection, Cancel);
		EndIf;
		
	EndIf;
	
EndProcedure

#Region InfobaseUpdate

Procedure FillNewGLAccounts() Export
	
	DocumentName = "CustomsDeclaration";
	
	Tables = New Array();
	
	TableDecription = New Structure("Name, Conditions", "Inventory", New Array());
	
	GLAccountFields = ChartsOfAccounts.PrimaryChartOfAccounts.GLAccountFields();
	GLAccountFields.Source = "Products.InventoryGLAccount";
	GLAccountFields.Receiver = "InventoryGLAccount";
	TableDecription.Conditions.Add(GLAccountFields);
	
	GLAccountFields = ChartsOfAccounts.PrimaryChartOfAccounts.GLAccountFields();
	GLAccountFields.Source = "&VATInputGLAccount";
	GLAccountFields.Receiver = "VATInputGLAccount";
	GLAccountFields.Parameter = Catalogs.DefaultGLAccounts.GetDefaultGLAccount("VATInput");
	TableDecription.Conditions.Add(GLAccountFields);
	
	GLAccountFields = ChartsOfAccounts.PrimaryChartOfAccounts.GLAccountFields();
	GLAccountFields.Source = "&VATOutputGLAccount";
	GLAccountFields.Receiver = "VATOutputGLAccount";
	GLAccountFields.Parameter = Catalogs.DefaultGLAccounts.GetDefaultGLAccount("VATOutput");
	TableDecription.Conditions.Add(GLAccountFields);
	
	Tables.Add(TableDecription);
	
	ChartsOfAccounts.PrimaryChartOfAccounts.FillNewGLAccounts(DocumentName, Tables);
	
EndProcedure

#EndRegion

#EndIf