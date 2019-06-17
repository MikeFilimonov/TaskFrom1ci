#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions

Procedure AddErrorIntoTable(ErrorDescription, OperationKind, ErrorsTable, Analytics = Undefined)
	
	If Analytics = Undefined Then
		Analytics = Documents.SalesOrder.EmptyRef()
	EndIf;
	
	NewRow = ErrorsTable.Add();
	NewRow.Period = Date;
	NewRow.Company = AdditionalProperties.ForPosting.Company;
	NewRow.OperationKind = OperationKind;
	NewRow.Analytics = Analytics;
	NewRow.ErrorDescription = ErrorDescription;
	NewRow.Recorder = Ref;
	NewRow.Active = True;
	
EndProcedure

Function GenerateErrorDescriptionCostAllocation(GLAccount, MethodOfDistribution, FilterByOrder, Amount)
	
	ErrorDescription = NStr("en = 'The ""%GLAccount%"" cost in the %Amount% amount allocated for production release by %AllocationMethod% can not be allocated as in the calculated period there was no %AdditionalDetails%.'"
	);
	
	ErrorDescription = StrReplace(
		ErrorDescription,
		"%GLAccount%",
		String(GLAccount)
	);
	
	ErrorDescription = StrReplace(
		ErrorDescription,
		"%Amount%",
		String(Amount) + " " + TrimAll(String(Constants.PresentationCurrency.Get()))
	);
	
	ErrorDescription = StrReplace(
		ErrorDescription,
		"%AllocationMethod%",
		?(MethodOfDistribution = Enums.CostAllocationMethod.ProductionVolume,
			NStr("en = 'release volume'"),
			NStr("en = 'direct costs'")
		)
	);
	
	ErrorDescription = StrReplace(
		ErrorDescription,
		"%AdditionalDetails%",
		?(MethodOfDistribution = Enums.CostAllocationMethod.ProductionVolume,
			NStr("en = 'production release %Order%'"),
			NStr("en = 'allocation of direct costs%Order% specified in the allocation setting'")
		)
	);
	
	ErrorDescription = StrReplace(
		ErrorDescription,
		"%Order%",
		?(ValueIsFilled(FilterByOrder),
			NStr("en = ' to '") + String(FilterByOrder),
			""
		)
	);
	
	Return ErrorDescription;
	
EndFunction

Function GenerateErrorDescriptionExpensesDistribution(GLAccount, MethodOfDistribution, Amount)
	
	ErrorDescription = NStr("en = 'The ""%GLAccount%"" expense in the %Amount% amount allocated for a financial result by %AllocationMethod% can not be allocated as in the calculated period there was no %AdditionalDetails%.'"
	);
	
	ErrorDescription = StrReplace(
		ErrorDescription,
		"%GLAccount%",
		String(GLAccount)
	);
	
	ErrorDescription = StrReplace(
		ErrorDescription,
		"%Amount%",
		String(Amount) + " " + TrimAll(String(Constants.PresentationCurrency.Get()))
	);
	
	If MethodOfDistribution = Enums.CostAllocationMethod.SalesVolume Then
		TextMethodOfDistribution = NStr("en = 'quantity'");
	ElsIf MethodOfDistribution = Enums.CostAllocationMethod.SalesRevenue Then
		TextMethodOfDistribution = NStr("en = 'revenue'");
	ElsIf MethodOfDistribution = Enums.CostAllocationMethod.CostOfGoodsSold Then
		TextMethodOfDistribution = NStr("en = 'cost of goods sold'");
	ElsIf MethodOfDistribution = Enums.CostAllocationMethod.GrossProfit Then
		TextMethodOfDistribution = NStr("en = 'gross profit'");
	EndIf;
		
	ErrorDescription = StrReplace(
		ErrorDescription,
		"%AllocationMethod%",
		TextMethodOfDistribution
	);
	
	If MethodOfDistribution = Enums.CostAllocationMethod.SalesVolume Then
		TextAdditionalDetails = NStr("en = 'quantity'");
	ElsIf MethodOfDistribution = Enums.CostAllocationMethod.SalesRevenue Then
		TextAdditionalDetails = NStr("en = 'revenue'");
	ElsIf MethodOfDistribution = Enums.CostAllocationMethod.CostOfGoodsSold Then
		TextAdditionalDetails = NStr("en = 'cost of goods sold'");
	ElsIf MethodOfDistribution = Enums.CostAllocationMethod.GrossProfit Then
		TextAdditionalDetails = NStr("en = 'gross profit'");
	EndIf;
	
	ErrorDescription = StrReplace(
		ErrorDescription,
		"%AdditionalDetails%",
		TextAdditionalDetails
	);
	
	Return ErrorDescription;
	
EndFunction

#Region VerifyTaxInvoices

Procedure VerifyTaxInvoices(ErrorsTable)
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	SalesInvoice.Ref AS Ref
	|INTO Docs
	|FROM
	|	Document.SalesInvoice AS SalesInvoice
	|WHERE
	|	SalesInvoice.Date BETWEEN &BeginOfPeriod AND &EndOfPeriod
	|	AND SalesInvoice.Company = &Company
	|	AND SalesInvoice.Posted
	|	AND SalesInvoice.VATTaxation <> VALUE(Enum.VATTaxationTypes.NotSubjectToVAT)
	|
	|UNION ALL
	|
	|SELECT
	|	CreditNote.Ref
	|FROM
	|	Document.CreditNote AS CreditNote
	|WHERE
	|	CreditNote.Date BETWEEN &BeginOfPeriod AND &EndOfPeriod
	|	AND CreditNote.Company = &Company
	|	AND CreditNote.Posted
	|	AND CreditNote.VATTaxation <> VALUE(Enum.VATTaxationTypes.NotSubjectToVAT)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Docs.Ref AS Ref,
	|	PRESENTATION(Docs.Ref) AS RefPresentation
	|FROM
	|	Docs AS Docs
	|		LEFT JOIN AccumulationRegister.VATOutput.Turnovers(&BeginOfPeriod, &EndOfPeriod, Period, Company = &Company) AS VATOutputTurnovers
	|		ON Docs.Ref = VATOutputTurnovers.ShipmentDocument
	|WHERE
	|	VATOutputTurnovers.ShipmentDocument IS NULL";
	Query.SetParameter("Company",		Company);
	Query.SetParameter("BeginOfPeriod",	BegOfMonth(Date));
	Query.SetParameter("EndOfPeriod",	EndOfMonth(Date));
	Result = Query.Execute();
	
	If Not Result.IsEmpty() Then 
		
		Selection = Result.Select();
		
		While Selection.Next() Do
			
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Tax invoice should be generated for %1'"),
				Selection.RefPresentation
			);
			AddErrorIntoTable(ErrorDescription, "Verify tax invoices", ErrorsTable, Selection.Ref);
			
		EndDo;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region CalculateReleaseActualCost

// Function generates movements on the WriteOffCostCorrectionNodes information register.
//
// Parameters:
//  Cancel        - Boolean - check box of document posting canceling.
//
// Returns:
//  Number - number of a written node.
//
Function MakeRegisterRecordsByRegisterWriteOffCostAdjustment(Cancel)
	
	Query = New Query();
	
	Query.TempTablesManager = AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.SetParameter("DateBeg", AdditionalProperties.ForPosting.BeginOfPeriodningDate);
	Query.SetParameter("DateEnd", AdditionalProperties.ForPosting.EndDatePeriod);
	Query.SetParameter("Recorder", Ref);
	Query.SetParameter("EmptyAccount", AdditionalProperties.ForPosting.EmptyAccount);
	Query.SetParameter("Company", AdditionalProperties.ForPosting.Company);
	
	// Receive a new nodes table, each node is
	// defined by the combination of all accounting dimensions. An average price is put to the
	// Amount column according to the corresponding InventoryAndCostAccounting register resource by the external receipt
	// for each node. These columns are the right parts in the linear equations system. The
	// total quantity of receipt to each node is put to the Quantity columns. If
	// there are no movements on quantity in this node but there are
	// only movements on cost, then the cost
	// is used instead of the quantity (the node corresponds to the non material expenses). If there is a writeoff
	// by the fixed cost from the node, then reduce
	// the quantity and the cost of Earning to this node on the quantity and the cost by the fixed operation.
	Query.Text =
	"SELECT
	|	Receipts.Company AS Company,
	|	Receipts.StructuralUnit AS StructuralUnit,
	|	Receipts.GLAccount AS GLAccount,
	|	Receipts.Products AS Products,
	|	Receipts.Characteristic AS Characteristic,
	|	Receipts.Batch AS Batch,
	|	Receipts.SalesOrder AS SalesOrder,
	|	Receipts.Quantity AS Quantity,
	|	Receipts.Amount AS SumForQuantity,
	|	CASE WHEN Receipts.FixedCost
	|		THEN Receipts.Amount
	|		ELSE 0
	|	END AS Amount
	|INTO ReceiptsAndBalanceWithoutFixedCosts
	|FROM
	|	AccumulationRegister.Inventory AS Receipts
	|WHERE
	|	Receipts.Period BETWEEN &DateBeg AND &DateEnd
	|	AND Receipts.RecordType = VALUE(AccumulationRecordType.Receipt)
	|	AND Receipts.Company = &Company
	|	
	|UNION ALL
	|	
	|SELECT
	|	FixedCostExpense.Company,
	|	FixedCostExpense.StructuralUnit,
	|	FixedCostExpense.GLAccount,
	|	FixedCostExpense.Products,
	|	FixedCostExpense.Characteristic,
	|	FixedCostExpense.Batch,
	|	FixedCostExpense.SalesOrder,
	|	-FixedCostExpense.Quantity,
	|	-FixedCostExpense.Amount,
	|	-FixedCostExpense.Amount
	|FROM
	|	AccumulationRegister.Inventory AS FixedCostExpense
	|WHERE
	|	FixedCostExpense.Period BETWEEN &DateBeg AND &DateEnd
	|	AND FixedCostExpense.RecordType = VALUE(AccumulationRecordType.Expense)
	|	AND FixedCostExpense.FixedCost
	|	AND FixedCostExpense.Company = &Company
	|	
	|UNION ALL
	|	
	|SELECT
	|	Balance.Company,
	|	Balance.StructuralUnit,
	|	Balance.GLAccount,
	|	Balance.Products,
	|	Balance.Characteristic,
	|	Balance.Batch,
	|	Balance.SalesOrder,
	|	Balance.QuantityBalance,
	|	Balance.AmountBalance,
	|	Balance.AmountBalance
	|FROM
	|	AccumulationRegister.Inventory.Balance(&DateBeg, Company = &Company) AS Balance
	|;
	|//////////////////////////////////////////////////////////////////
	|SELECT
	|	Balance.Company AS Company,
	|	Balance.StructuralUnit AS StructuralUnit,
	|	Balance.GLAccount AS GLAccount,
	|	Balance.Products AS Products,
	|	Balance.Characteristic AS Characteristic,
	|	Balance.Batch AS Batch,
	|	Balance.SalesOrder AS SalesOrder,
	|	SUM(Balance.Quantity) AS Quantity,
	|	SUM(Balance.Amount) AS SumForQuantity,
	|	SUM(Balance.Amount) AS Amount
	|INTO Balance
	|FROM
	|	ReceiptsAndBalanceWithoutFixedCosts AS Balance
	|
	|GROUP BY
	|	Balance.Company,
	|	Balance.StructuralUnit,
	|	Balance.GLAccount,
	|	Balance.Products,
	|	Balance.Characteristic,
	|	Balance.Batch,
	|	Balance.SalesOrder
	|;
	|//////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	FilledRecords.Company AS Company,
	|	FilledRecords.StructuralUnit AS StructuralUnit,
	|	FilledRecords.GLAccount AS GLAccount,
	|	FilledRecords.Products AS Products,
	|	FilledRecords.Characteristic AS Characteristic,
	|	FilledRecords.Batch AS Batch,
	|	FilledRecords.SalesOrder AS SalesOrder
	|INTO FilledRecords
	|FROM
	|	AccumulationRegister.Inventory AS FilledRecords
	|WHERE
	|	FilledRecords.Period BETWEEN &DateBeg AND &DateEnd
	|	AND FilledRecords.Company = &Company
	|	AND (FilledRecords.Quantity <> 0
	|			OR FilledRecords.Amount <> 0)
	|;
	|//////////////////////////////////////////////////////////////////
	|SELECT
	|	Records.Company AS Company,
	|	Records.StructuralUnit AS StructuralUnit,
	|	Records.GLAccount AS GLAccount,
	|	Records.Products AS Products,
	|	Records.Characteristic AS Characteristic,
	|	Records.Batch AS Batch,
	|	Records.SalesOrder AS SalesOrder,
	|	CASE
	|		WHEN SUM(NestedSelect.Quantity) = 0
	|			THEN SUM(NestedSelect.SumForQuantity)
	|		ELSE SUM(NestedSelect.Quantity)
	|	END AS Quantity,
	|	CASE
	|		WHEN SUM(NestedSelect.Quantity) = 0
	|				AND SUM(NestedSelect.SumForQuantity) = 0
	|			THEN 0
	|		ELSE CAST(SUM(NestedSelect.Amount) / CASE
	|					WHEN SUM(NestedSelect.Quantity) = 0
	|						THEN SUM(NestedSelect.SumForQuantity)
	|					ELSE SUM(NestedSelect.Quantity)
	|				END AS NUMBER(23, 10))
	|	END AS Amount
	|FROM
	|	FilledRecords AS Records
	|		
	|	LEFT JOIN Balance AS NestedSelect
	|	ON Records.Company = NestedSelect.Company
	|		AND Records.StructuralUnit = NestedSelect.StructuralUnit
	|		AND Records.GLAccount = NestedSelect.GLAccount
	|		AND Records.Products = NestedSelect.Products
	|		AND Records.Characteristic = NestedSelect.Characteristic
	|		AND Records.Batch = NestedSelect.Batch
	|		AND Records.SalesOrder = NestedSelect.SalesOrder
	|
	|	LEFT JOIN Catalog.Products AS ProductsRef
	|	ON ProductsRef.Ref = Records.Products
	|WHERE
	|	(Records.Products.AccountingMethod = VALUE(Enum.InventoryValuationMethods.WeightedAverage)
	|		OR ProductsRef.AccountingMethod = VALUE(Enum.InventoryValuationMethods.EmptyRef)
	|		OR Records.Products = VALUE(Catalog.Products.EmptyRef))
	|
	|GROUP BY
	|	Records.Company,
	|	Records.StructuralUnit,
	|	Records.GLAccount,
	|	Records.Products,
	|	Records.Characteristic,
	|	Records.Batch,
	|	Records.SalesOrder
	|";
	
	NodeNo = 0;
	Result = Query.Execute();
	
	If Not Result.IsEmpty() Then
		RecordSet = InformationRegisters.WriteOffCostAdjustment.CreateRecordSet();
		RecordSet.Filter.Recorder.Set(Ref);
		RecordSet.Write(True);
		Selection = Result.Select();
		While Selection.Next() Do
			NodeNo = NodeNo + 1;
			NewNode = RecordSet.Add();
			NewNode.NodeNo = NodeNo;
			NewNode.Recorder = Ref;
			NewNode.Period = Date;
			FillPropertyValues(NewNode, Selection);
		EndDo;
		RecordSet.Write(False);
	EndIf;
	
	// The first approximation (solution on the first iteration).
	Query.Text =
	"SELECT
	|	WriteOffCostAdjustment.NodeNo,
	|	WriteOffCostAdjustment.Amount
	|INTO SolutionsTable
	|FROM
	|	InformationRegister.WriteOffCostAdjustment AS WriteOffCostAdjustment
	|WHERE
	|	WriteOffCostAdjustment.Recorder = &Recorder
	|
	|INDEX BY
	|	NodeNo
	|";
	Query.Execute();
	
	Return NodeNo;
	
EndFunction

// Solve the linear equations system
//
// Parameters:
// No.
//
// Returns:
//  Boolean - check box of finding a solution.
//
Function SolveLES()
	
	Query = New Query();
	Query.TempTablesManager = AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.SetParameter("DateBeg", AdditionalProperties.ForPosting.BeginOfPeriodningDate);
	Query.SetParameter("DateEnd", AdditionalProperties.ForPosting.EndDatePeriod);
	Query.SetParameter("Recorder", Ref);
	Query.SetParameter("EmptyAccount", AdditionalProperties.ForPosting.EmptyAccount);
	Query.SetParameter("Company", AdditionalProperties.ForPosting.Company);
	
	CurrentVariance = 1;
	RequiredPrecision = 0.00001;
	IterationsQuantity = 0;
	
	// Prepare the table of movements and writeoffs for the report period. The
	// current period returns are processed as usual movements.
	Query.Text =
	"SELECT
	|	InventoryAndCostAccounting.Company AS Company,
	|	InventoryAndCostAccounting.StructuralUnit AS StructuralUnit,
	|	InventoryAndCostAccounting.GLAccount AS GLAccount,
	|	InventoryAndCostAccounting.Products AS Products,
	|	InventoryAndCostAccounting.Characteristic AS Characteristic,
	|	InventoryAndCostAccounting.Batch AS Batch,
	|	InventoryAndCostAccounting.SalesOrder AS SalesOrder,
	|	InventoryAndCostAccounting.CorrSalesOrder AS CorrSalesOrder,
	|	InventoryAndCostAccounting.SourceDocument AS SourceDocument,
	|	SUM(InventoryAndCostAccounting.Quantity) AS Quantity,
	|	SUM(InventoryAndCostAccounting.Amount) AS Amount
	|INTO CostAccountingReturnsCurPeriod
	|FROM
	|	AccumulationRegister.Inventory AS InventoryAndCostAccounting
	|WHERE
	|	InventoryAndCostAccounting.Company = &Company
	|	AND InventoryAndCostAccounting.Period between &DateBeg AND &DateEnd
	|	AND InventoryAndCostAccounting.RecordType = VALUE(AccumulationRecordType.Receipt)
	|	AND InventoryAndCostAccounting.Return
	|	AND Not InventoryAndCostAccounting.FixedCost
	|	AND InventoryAndCostAccounting.SourceDocument <> UNDEFINED
	|	AND ENDOFPERIOD(InventoryAndCostAccounting.SourceDocument.Date, MONTH) = ENDOFPERIOD(InventoryAndCostAccounting.Period, MONTH)
	|
	|GROUP BY
	|	InventoryAndCostAccounting.Company,
	|	InventoryAndCostAccounting.StructuralUnit,
	|	InventoryAndCostAccounting.GLAccount,
	|	InventoryAndCostAccounting.Products,
	|	InventoryAndCostAccounting.Characteristic,
	|	InventoryAndCostAccounting.Batch,
	|	InventoryAndCostAccounting.SalesOrder,
	|	InventoryAndCostAccounting.CorrSalesOrder,
	|	InventoryAndCostAccounting.SourceDocument
	|
	|INDEX BY
	|	SourceDocument,
	|	Company,
	|	StructuralUnit,
	|	GLAccount,
	|	Products,
	|	Characteristic,
	|	Batch,
	|	SalesOrder,
	|	CorrSalesOrder
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CostAccountingReturnsCurPeriod.Company AS Company,
	|	CostAccountingReturnsCurPeriod.StructuralUnit AS StructuralUnit,
	|	CostAccountingReturnsCurPeriod.GLAccount AS GLAccount,
	|	CostAccountingReturnsCurPeriod.Products AS Products,
	|	CostAccountingReturnsCurPeriod.Characteristic AS Characteristic,
	|	CostAccountingReturnsCurPeriod.Batch AS Batch,
	|	CostAccountingReturnsCurPeriod.SalesOrder AS SalesOrder,
	|	WriteOffCostAdjustment.NodeNo AS NodeNo,
	|	SUM(ISNULL(InventoryAndCostAccounting.Quantity, 0)) AS QuantitySold,
	|	SUM(ISNULL(InventoryAndCostAccounting.Amount, 0)) AS AmountSold,
	|	CostAccountingReturnsCurPeriod.Quantity AS QuantityReturn,
	|	CostAccountingReturnsCurPeriod.Amount AS AmountReturn,
	|	CostAccountingReturnsCurPeriod.SourceDocument AS SourceDocument
	|INTO CostAccountingReturnsOnReserves
	|FROM
	|	CostAccountingReturnsCurPeriod AS CostAccountingReturnsCurPeriod
	|		LEFT JOIN AccumulationRegister.Inventory AS InventoryAndCostAccounting
	|		ON CostAccountingReturnsCurPeriod.SourceDocument = InventoryAndCostAccounting.SourceDocument
	|			AND CostAccountingReturnsCurPeriod.Company = InventoryAndCostAccounting.Company
	|			AND CostAccountingReturnsCurPeriod.Products = InventoryAndCostAccounting.Products
	|			AND CostAccountingReturnsCurPeriod.Characteristic = InventoryAndCostAccounting.Characteristic
	|			AND CostAccountingReturnsCurPeriod.Batch = InventoryAndCostAccounting.Batch
	|			AND CostAccountingReturnsCurPeriod.CorrSalesOrder = InventoryAndCostAccounting.CorrSalesOrder
	|			AND CostAccountingReturnsCurPeriod.SalesOrder = InventoryAndCostAccounting.SalesOrder
	|			AND (NOT InventoryAndCostAccounting.Return)
	|		LEFT JOIN InformationRegister.WriteOffCostAdjustment AS WriteOffCostAdjustment
	|		ON (WriteOffCostAdjustment.Recorder = &Recorder)
	|			AND (InventoryAndCostAccounting.Company = WriteOffCostAdjustment.Company)
	|			AND (InventoryAndCostAccounting.StructuralUnit = WriteOffCostAdjustment.StructuralUnit)
	|			AND (InventoryAndCostAccounting.GLAccount = WriteOffCostAdjustment.GLAccount)
	|			AND (InventoryAndCostAccounting.Products = WriteOffCostAdjustment.Products)
	|			AND (InventoryAndCostAccounting.Characteristic = WriteOffCostAdjustment.Characteristic)
	|			AND (InventoryAndCostAccounting.Batch = WriteOffCostAdjustment.Batch)
	|			AND (InventoryAndCostAccounting.SalesOrder = WriteOffCostAdjustment.SalesOrder)
	|
	|GROUP BY
	|	CostAccountingReturnsCurPeriod.Company,
	|	CostAccountingReturnsCurPeriod.StructuralUnit,
	|	CostAccountingReturnsCurPeriod.GLAccount,
	|	CostAccountingReturnsCurPeriod.Products,
	|	CostAccountingReturnsCurPeriod.Characteristic,
	|	CostAccountingReturnsCurPeriod.Batch,
	|	CostAccountingReturnsCurPeriod.SalesOrder,
	|	WriteOffCostAdjustment.NodeNo,
	|	CostAccountingReturnsCurPeriod.Quantity,
	|	CostAccountingReturnsCurPeriod.Amount,
	|	CostAccountingReturnsCurPeriod.SourceDocument
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CostAccountingReturnsCurPeriod.Company AS Company,
	|	CostAccountingReturnsCurPeriod.StructuralUnit AS StructuralUnit,
	|	CostAccountingReturnsCurPeriod.GLAccount AS GLAccount,
	|	CostAccountingReturnsCurPeriod.Products AS Products,
	|	CostAccountingReturnsCurPeriod.Characteristic AS Characteristic,
	|	CostAccountingReturnsCurPeriod.Batch AS Batch,
	|	CostAccountingReturnsCurPeriod.SalesOrder AS SalesOrder,
	|	WriteOffCostAdjustment.NodeNo AS NodeNo,
	|	SUM(ISNULL(InventoryAndCostAccounting.Quantity, 0)) AS QuantitySold,
	|	SUM(ISNULL(InventoryAndCostAccounting.Amount, 0)) AS AmountSold,
	|	CostAccountingReturnsCurPeriod.Quantity AS QuantityReturn,
	|	CostAccountingReturnsCurPeriod.Amount AS AmountReturn,
	|	CostAccountingReturnsCurPeriod.SourceDocument AS SourceDocument
	|INTO CostAccountingReturnsFree
	|FROM
	|	CostAccountingReturnsCurPeriod AS CostAccountingReturnsCurPeriod
	|		LEFT JOIN AccumulationRegister.Inventory AS InventoryAndCostAccounting
	|		ON CostAccountingReturnsCurPeriod.SourceDocument = InventoryAndCostAccounting.SourceDocument
	|			AND CostAccountingReturnsCurPeriod.Company = InventoryAndCostAccounting.Company
	|			AND CostAccountingReturnsCurPeriod.Products = InventoryAndCostAccounting.Products
	|			AND CostAccountingReturnsCurPeriod.Characteristic = InventoryAndCostAccounting.Characteristic
	|			AND CostAccountingReturnsCurPeriod.Batch = InventoryAndCostAccounting.Batch
	|			AND CostAccountingReturnsCurPeriod.CorrSalesOrder = InventoryAndCostAccounting.CorrSalesOrder
	|			AND (InventoryAndCostAccounting.SalesOrder = UNDEFINED)
	|			AND (NOT InventoryAndCostAccounting.Return)
	|		LEFT JOIN InformationRegister.WriteOffCostAdjustment AS WriteOffCostAdjustment
	|		ON (WriteOffCostAdjustment.Recorder = &Recorder)
	|			AND (InventoryAndCostAccounting.Company = WriteOffCostAdjustment.Company)
	|			AND (InventoryAndCostAccounting.StructuralUnit = WriteOffCostAdjustment.StructuralUnit)
	|			AND (InventoryAndCostAccounting.GLAccount = WriteOffCostAdjustment.GLAccount)
	|			AND (InventoryAndCostAccounting.Products = WriteOffCostAdjustment.Products)
	|			AND (InventoryAndCostAccounting.Characteristic = WriteOffCostAdjustment.Characteristic)
	|			AND (InventoryAndCostAccounting.Batch = WriteOffCostAdjustment.Batch)
	|			AND (InventoryAndCostAccounting.SalesOrder = WriteOffCostAdjustment.SalesOrder)
	|
	|GROUP BY
	|	CostAccountingReturnsCurPeriod.Company,
	|	CostAccountingReturnsCurPeriod.StructuralUnit,
	|	CostAccountingReturnsCurPeriod.GLAccount,
	|	CostAccountingReturnsCurPeriod.Products,
	|	CostAccountingReturnsCurPeriod.Characteristic,
	|	CostAccountingReturnsCurPeriod.Batch,
	|	CostAccountingReturnsCurPeriod.SalesOrder,
	|	WriteOffCostAdjustment.NodeNo,
	|	CostAccountingReturnsCurPeriod.Quantity,
	|	CostAccountingReturnsCurPeriod.Amount,
	|	CostAccountingReturnsCurPeriod.SourceDocument
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CostAccountingReturns.Company AS Company,
	|	CostAccountingReturns.StructuralUnit AS StructuralUnit,
	|	CostAccountingReturns.GLAccount AS GLAccount,
	|	CostAccountingReturns.Products AS Products,
	|	CostAccountingReturns.Characteristic AS Characteristic,
	|	CostAccountingReturns.Batch AS Batch,
	|	CostAccountingReturns.SalesOrder AS SalesOrder,
	|	CostAccountingReturns.NodeNo AS NodeNo,
	|	CostAccountingReturns.QuantitySold AS QuantitySold,
	|	CostAccountingReturns.AmountSold AS AmountSold,
	|	CostAccountingReturns.QuantityReturn AS QuantityReturn,
	|	CostAccountingReturns.AmountReturn AS AmountReturn,
	|	0 AS QuantityDistributed,
	|	0 AS SumIsDistributed,
	|	CostAccountingReturns.SourceDocument AS SourceDocument
	|FROM
	|	(SELECT
	|		CostAccountingReturns.Company AS Company,
	|		CostAccountingReturns.StructuralUnit AS StructuralUnit,
	|		CostAccountingReturns.GLAccount AS GLAccount,
	|		CostAccountingReturns.Products AS Products,
	|		CostAccountingReturns.Characteristic AS Characteristic,
	|		CostAccountingReturns.Batch AS Batch,
	|		CostAccountingReturns.SalesOrder AS SalesOrder,
	|		CostAccountingReturns.NodeNo AS NodeNo,
	|		CostAccountingReturns.QuantitySold AS QuantitySold,
	|		CostAccountingReturns.AmountSold AS AmountSold,
	|		CostAccountingReturns.QuantityReturn AS QuantityReturn,
	|		CostAccountingReturns.AmountReturn AS AmountReturn,
	|		CostAccountingReturns.SourceDocument AS SourceDocument
	|	FROM
	|		CostAccountingReturnsFree AS CostAccountingReturns
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		CostAccountingReturns.Company,
	|		CostAccountingReturns.StructuralUnit,
	|		CostAccountingReturns.GLAccount,
	|		CostAccountingReturns.Products,
	|		CostAccountingReturns.Characteristic,
	|		CostAccountingReturns.Batch,
	|		CostAccountingReturns.SalesOrder,
	|		CostAccountingReturns.NodeNo,
	|		CostAccountingReturns.QuantitySold,
	|		CostAccountingReturns.AmountSold,
	|		CostAccountingReturns.QuantityReturn,
	|		CostAccountingReturns.AmountReturn,
	|		CostAccountingReturns.SourceDocument
	|	FROM
	|		CostAccountingReturnsOnReserves AS CostAccountingReturns) AS CostAccountingReturns
	|
	|ORDER BY
	|	NodeNo
	|TOTALS BY
	|	Company,
	|	StructuralUnit,
	|	GLAccount,
	|	Products,
	|	Characteristic,
	|	Batch,
	|	SourceDocument,
	|	AmountReturn,
	|	QuantityReturn";
	
	QueryResult = Query.ExecuteBatch();
	
	ReturnsTable = QueryResult[3].Unload();
	ReturnsTable.Clear();
	
	BypassOnCounterparty = QueryResult[3].Select(QueryResultIteration.ByGroups);
	While BypassOnCounterparty.Next() Do
		BypassByStructuralUnit = BypassOnCounterparty.Select(QueryResultIteration.ByGroups);
		While BypassByStructuralUnit.Next() Do
			BypassingByAccountStatement = BypassByStructuralUnit.Select(QueryResultIteration.ByGroups);
			While BypassingByAccountStatement.Next() Do
				BypassOnProducts = BypassingByAccountStatement.Select(QueryResultIteration.ByGroups);
				While BypassOnProducts.Next() Do
					BypassByCharacteristic = BypassOnProducts.Select(QueryResultIteration.ByGroups);
					While BypassByCharacteristic.Next() Do
						CrawlByBatch = BypassByCharacteristic.Select(QueryResultIteration.ByGroups);
						While CrawlByBatch.Next() Do
							BypassBySourceDocument = CrawlByBatch.Select(QueryResultIteration.ByGroups);
							While BypassBySourceDocument.Next() Do
								BypassOnSumReturn = BypassBySourceDocument.Select(QueryResultIteration.ByGroups);
								While BypassOnSumReturn.Next() Do
									BypassByQuantityReturn = BypassOnSumReturn.Select(QueryResultIteration.ByGroups);
									While BypassByQuantityReturn.Next() Do
										QuantityLeftToDistribute = BypassByQuantityReturn.QuantityReturn;
										AmountLeftToDistribute = BypassByQuantityReturn.AmountReturn;
										SelectionDetailRecords = BypassByQuantityReturn.Select();
										While SelectionDetailRecords.Next() Do
											If QuantityLeftToDistribute > 0 Then
												If QuantityLeftToDistribute <= SelectionDetailRecords.QuantitySold Then
													NewRow = ReturnsTable.Add();
													FillPropertyValues(NewRow, SelectionDetailRecords);
													NewRow.QuantityDistributed = QuantityLeftToDistribute;
													QuantityLeftToDistribute = 0;
													NewRow.SumIsDistributed = AmountLeftToDistribute;
													AmountLeftToDistribute = 0;
												Else
													NewRow = ReturnsTable.Add();
													FillPropertyValues(NewRow, SelectionDetailRecords);
													NewRow.QuantityDistributed = SelectionDetailRecords.QuantitySold;
													QuantityLeftToDistribute = QuantityLeftToDistribute - SelectionDetailRecords.QuantitySold;
													NewRow.SumIsDistributed = SelectionDetailRecords.AmountSold;
													AmountLeftToDistribute = AmountLeftToDistribute - SelectionDetailRecords.AmountSold;
												EndIf;
											EndIf;
										EndDo;
									EndDo;
								EndDo;
							EndDo;
						EndDo;
					EndDo;
				EndDo;
			EndDo;
		EndDo;
	EndDo;
	
	Query.SetParameter("ReturnsTable", ReturnsTable);
	
	Query.Text =
	"SELECT DISTINCT
	|	ReturnsTable.Company AS Company,
	|	ReturnsTable.StructuralUnit AS StructuralUnit,
	|	ReturnsTable.GLAccount AS GLAccount,
	|	ReturnsTable.Products AS Products,
	|	ReturnsTable.Characteristic AS Characteristic,
	|	ReturnsTable.Batch AS Batch,
	|	ReturnsTable.SalesOrder AS SalesOrder,
	|	ReturnsTable.NodeNo AS NodeNo,
	|	ReturnsTable.QuantityDistributed AS Quantity,
	|	ReturnsTable.SumIsDistributed AS Amount
	|INTO CostAccountingReturns
	|FROM
	|	&ReturnsTable AS ReturnsTable
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	InventoryAndCostAccounting.Company AS Company,
	|	InventoryAndCostAccounting.StructuralUnitCorr AS StructuralUnit,
	|	InventoryAndCostAccounting.CorrGLAccount AS GLAccount,
	|	InventoryAndCostAccounting.ProductsCorr AS Products,
	|	InventoryAndCostAccounting.CharacteristicCorr AS Characteristic,
	|	InventoryAndCostAccounting.BatchCorr AS Batch,
	|	InventoryAndCostAccounting.CustomerCorrOrder AS SalesOrder,
	|	WriteOffCostAdjustment.NodeNo AS NodeNo,
	|	SUM(CASE
	|			WHEN InventoryAndCostAccounting.RecordType = VALUE(AccumulationRecordType.Expense)
	|					AND Not InventoryAndCostAccounting.Return
	|				THEN InventoryAndCostAccounting.Quantity
	|			ELSE 0
	|		END) AS Quantity,
	|	SUM(CAST(CASE
	|				WHEN InventoryAndCostAccounting.RecordType = VALUE(AccumulationRecordType.Expense)
	|						AND Not InventoryAndCostAccounting.Return
	|					THEN InventoryAndCostAccounting.Amount
	|				WHEN InventoryAndCostAccounting.RecordType = VALUE(AccumulationRecordType.Receipt)
	|						AND InventoryAndCostAccounting.Return
	|					THEN -InventoryAndCostAccounting.Amount
	|				ELSE 0
	|			END AS NUMBER(23, 10))) AS Amount
	|INTO CostAccountingWithoutReturnAccounting
	|FROM
	|	AccumulationRegister.Inventory AS InventoryAndCostAccounting
	|		LEFT JOIN InformationRegister.WriteOffCostAdjustment AS WriteOffCostAdjustment
	|		ON (WriteOffCostAdjustment.Recorder = &Recorder)
	|			AND InventoryAndCostAccounting.Company = WriteOffCostAdjustment.Company
	|			AND InventoryAndCostAccounting.StructuralUnit = WriteOffCostAdjustment.StructuralUnit
	|			AND InventoryAndCostAccounting.GLAccount = WriteOffCostAdjustment.GLAccount
	|			AND InventoryAndCostAccounting.Products = WriteOffCostAdjustment.Products
	|			AND InventoryAndCostAccounting.Characteristic = WriteOffCostAdjustment.Characteristic
	|			AND InventoryAndCostAccounting.Batch = WriteOffCostAdjustment.Batch
	|			AND InventoryAndCostAccounting.SalesOrder = WriteOffCostAdjustment.SalesOrder
	|WHERE
	|	InventoryAndCostAccounting.Period between &DateBeg AND &DateEnd
	|	AND InventoryAndCostAccounting.Company = &Company
	|	AND InventoryAndCostAccounting.RecordType = VALUE(AccumulationRecordType.Expense)
	|	AND Not InventoryAndCostAccounting.FixedCost
	|
	|GROUP BY
	|	InventoryAndCostAccounting.Company,
	|	InventoryAndCostAccounting.StructuralUnitCorr,
	|	InventoryAndCostAccounting.CorrGLAccount,
	|	InventoryAndCostAccounting.ProductsCorr,
	|	InventoryAndCostAccounting.CharacteristicCorr,
	|	InventoryAndCostAccounting.BatchCorr,
	|	InventoryAndCostAccounting.CustomerCorrOrder,
	|	WriteOffCostAdjustment.NodeNo
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CostAccounting.Company AS Company,
	|	CostAccounting.StructuralUnit AS StructuralUnit,
	|	CostAccounting.GLAccount AS GLAccount,
	|	CostAccounting.Products AS Products,
	|	CostAccounting.Characteristic AS Characteristic,
	|	CostAccounting.Batch AS Batch,
	|	CostAccounting.SalesOrder AS SalesOrder,
	|	CostAccounting.NodeNo AS NodeNo,
	|	SUM(CostAccounting.Quantity) AS Quantity,
	|	SUM(CostAccounting.Amount) AS Amount
	|INTO CostAccounting
	|FROM
	|	(SELECT
	|		CostAccountingNetOfRefunds.Company AS Company,
	|		CostAccountingNetOfRefunds.StructuralUnit AS StructuralUnit,
	|		CostAccountingNetOfRefunds.GLAccount AS GLAccount,
	|		CostAccountingNetOfRefunds.Products AS Products,
	|		CostAccountingNetOfRefunds.Characteristic AS Characteristic,
	|		CostAccountingNetOfRefunds.Batch AS Batch,
	|		CostAccountingNetOfRefunds.SalesOrder AS SalesOrder,
	|		CostAccountingNetOfRefunds.NodeNo AS NodeNo,
	|		CostAccountingNetOfRefunds.Quantity AS Quantity,
	|		CostAccountingNetOfRefunds.Amount AS Amount
	|	FROM
	|		CostAccountingWithoutReturnAccounting AS CostAccountingNetOfRefunds
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		CostAccountingReturns.Company,
	|		CostAccountingReturns.StructuralUnit,
	|		CostAccountingReturns.GLAccount,
	|		CostAccountingReturns.Products,
	|		CostAccountingReturns.Characteristic,
	|		CostAccountingReturns.Batch,
	|		CostAccountingReturns.SalesOrder,
	|		CostAccountingReturns.NodeNo,
	|		CostAccountingReturns.Quantity,
	|		CostAccountingReturns.Amount
	|	FROM
	|		CostAccountingReturns AS CostAccountingReturns
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		CostAccountingReturns.Company,
	|		UNDEFINED,
	|		VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef),
	|		VALUE(Catalog.Products.EmptyRef),
	|		VALUE(Catalog.ProductsCharacteristics.EmptyRef),
	|		VALUE(Catalog.ProductsBatches.EmptyRef),
	|		UNDEFINED,
	|		CostAccountingReturns.NodeNo,
	|		-CostAccountingReturns.Quantity,
	|		-CostAccountingReturns.Amount
	|	FROM
	|		CostAccountingReturns AS CostAccountingReturns) AS CostAccounting
	|
	|GROUP BY
	|	CostAccounting.Company,
	|	CostAccounting.StructuralUnit,
	|	CostAccounting.GLAccount,
	|	CostAccounting.Products,
	|	CostAccounting.Characteristic,
	|	CostAccounting.Batch,
	|	CostAccounting.SalesOrder,
	|	CostAccounting.NodeNo
	|
	|INDEX BY
	|	Company,
	|	StructuralUnit,
	|	GLAccount,
	|	Products,
	|	Characteristic,
	|	Batch,
	|	SalesOrder,
	|	NodeNo";
	
	
	Query.ExecuteBatch();
	
	// Iteratively search for the solution of linear
	// equations system until the deviation is less than the required one or 100 calculation iterations are not executed.
	While (CurrentVariance > RequiredPrecision * RequiredPrecision) AND (IterationsQuantity < 100) Do
		
		IterationsQuantity = IterationsQuantity + 1;
		
		// The next settlement iteration.
		Query.Text = 
		"SELECT
		|	WriteOffCostAdjustment.NodeNo AS NodeNo,
		|	SUM(
		|		CAST(
		|			CASE WHEN WriteOffCostAdjustment.Quantity <> 0
		|					THEN SolutionsTable.Amount * CASE
		|				WHEN CostAccounting.Quantity = 0
		|					THEN CostAccounting.Amount
		|					ELSE CostAccounting.Quantity
		|					END / WriteOffCostAdjustment.Quantity
		|				ELSE 0
		|			END AS NUMBER(23, 10)
		|	)) AS Amount
		|INTO TemporaryTableSolutions
		|FROM
		|	InformationRegister.WriteOffCostAdjustment AS WriteOffCostAdjustment
		|		LEFT JOIN CostAccounting AS CostAccounting
		|		ON WriteOffCostAdjustment.Company = CostAccounting.Company
		|			AND WriteOffCostAdjustment.StructuralUnit = CostAccounting.StructuralUnit
		|			AND WriteOffCostAdjustment.GLAccount = CostAccounting.GLAccount
		|			AND WriteOffCostAdjustment.Products = CostAccounting.Products
		|			AND WriteOffCostAdjustment.Characteristic = CostAccounting.Characteristic
		|			AND WriteOffCostAdjustment.Batch = CostAccounting.Batch
		|			AND WriteOffCostAdjustment.SalesOrder = CostAccounting.SalesOrder
		|		LEFT JOIN SolutionsTable AS SolutionsTable
		|			ON CostAccounting.NodeNo = SolutionsTable.NodeNo
		|WHERE
		|	WriteOffCostAdjustment.Recorder = &Recorder
		|
		|GROUP BY
		|	WriteOffCostAdjustment.NodeNo
		|
		|INDEX BY
		|	NodeNo
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	SUM((ISNULL(SolutionsTable.Amount, 0) - (WriteOffCostAdjustment.Amount + ISNULL(TemporaryTableSolutions.Amount, 0)))
		|		* (ISNULL(SolutionsTable.Amount, 0) - (WriteOffCostAdjustment.Amount + ISNULL(TemporaryTableSolutions.Amount, 0)))
		|	) AS AmountOfSquaresOfRejections
		|FROM
		|	InformationRegister.WriteOffCostAdjustment AS WriteOffCostAdjustment
		|		LEFT JOIN TemporaryTableSolutions AS TemporaryTableSolutions
		|		ON (TemporaryTableSolutions.NodeNo = WriteOffCostAdjustment.NodeNo)
		|		LEFT JOIN SolutionsTable AS SolutionsTable
		|		ON (SolutionsTable.NodeNo = WriteOffCostAdjustment.NodeNo)
		|WHERE
		|	WriteOffCostAdjustment.Recorder = &Recorder";
		
		ResultsArray = Query.ExecuteBatch();
		Result = ResultsArray[1];
		
		OldRejection = CurrentVariance;
		If Result.IsEmpty() Then
			CurrentVariance = 0; // there are no deviations
		Else
			Selection = Result.Select();
			Selection.Next();
			
			// Determine the current solution variance.
			CurrentVariance = ?(Selection.AmountOfSquaresOfRejections = NULL, 0, Selection.AmountOfSquaresOfRejections);
		EndIf;
		
		Query.Text =
		"DROP SolutionsTable
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	WriteOffCostAdjustment.NodeNo AS NodeNo,
		|	WriteOffCostAdjustment.Amount + ISNULL(TemporaryTableSolutions.Amount, 0) AS Amount
		|INTO SolutionsTable
		|FROM
		|	InformationRegister.WriteOffCostAdjustment AS WriteOffCostAdjustment
		|		LEFT JOIN TemporaryTableSolutions AS TemporaryTableSolutions
		|		ON (TemporaryTableSolutions.NodeNo = WriteOffCostAdjustment.NodeNo)
		|WHERE
		|	WriteOffCostAdjustment.Recorder = &Recorder
		|
		|INDEX BY
		|	NodeNo
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|DROP TemporaryTableSolutions";
		
		Query.ExecuteBatch();
		
	EndDo;

	Return True;
	
EndFunction

Procedure GenerateRegisterRecordsByExpensesRegister(RecordSet, RecordSetAccountingJournalEntries, RegisterRecordRow, Amount, FixedCost, ContentOfAccountingRecord = Undefined, IsReturn = False, Recorder = Undefined)
	
	If Recorder = Undefined Then
		Recorder = Ref;
	EndIf;
	
	If ContentOfAccountingRecord = Undefined Then
		If RegisterRecordRow.GLAccountGLAccountType = Enums.GLAccountsTypes.Inventory Then
			ContentOfAccountingRecord = NStr("en = 'Write off warehouse inventory'");
		Else
			If ValueIsFilled(RegisterRecordRow.Products) Then
				ContentOfAccountingRecord = NStr("en = 'Expense write-off'");
			Else
				ContentOfAccountingRecord = NStr("en = 'Inventory write-off from Production'");
			EndIf;
		EndIf;
	EndIf;
	
	// Expense by the register Inventory and costs accounting.
	NewRow = RecordSet.Add();
	FillPropertyValues(NewRow, RegisterRecordRow);
	If IsReturn Then
		NewRow.RecordType = AccumulationRecordType.Receipt;
	Else
		NewRow.RecordType = AccumulationRecordType.Expense;
	EndIf;
	NewRow.Recorder = Recorder;
	NewRow.Period = ?(ValueIsFilled(NewRow.Period), NewRow.Period, Date); // period will be filled in for returns, this is required for FIFO
	NewRow.FixedCost = FixedCost;
	NewRow.Quantity = 0;
	NewRow.Amount = Amount;
	NewRow.ContentOfAccountingRecord = ContentOfAccountingRecord;
	NewRow.SalesOrder = ?(ValueIsFilled(NewRow.SalesOrder), NewRow.SalesOrder, Undefined);
	NewRow.CustomerCorrOrder = ?(ValueIsFilled(NewRow.CustomerCorrOrder), NewRow.CustomerCorrOrder, Undefined);
	NewRow.CorrSalesOrder = ?(ValueIsFilled(NewRow.CorrSalesOrder), NewRow.CorrSalesOrder, Undefined);
	
	If RegisterRecordRow.CorrGLAccount = AdditionalProperties.ForPosting.EmptyAccount Then
		Return;
	EndIf;
	
	If RegisterRecordRow.CorrAccountFinancialAccountType = Enums.GLAccountsTypes.Inventory Then
		ContentOfAccountingRecord = NStr("en = 'Inventory increase to warehouse'");
	Else
		If ValueIsFilled(RegisterRecordRow.Products) Then
			ContentOfAccountingRecord = NStr("en = 'Expense receipt'");
		Else
			ContentOfAccountingRecord = NStr("en = 'Inventory increase in production'");
		EndIf;
	EndIf;
		
	// Receipt by the register Inventory and costs accounting.
	NewRow = RecordSet.Add();
	NewRow.RecordType = AccumulationRecordType.Receipt;
	NewRow.Period = Date;
	NewRow.Recorder = Recorder;
	NewRow.Company = RegisterRecordRow.Company;
	NewRow.StructuralUnit = RegisterRecordRow.StructuralUnitCorr;
	NewRow.GLAccount = RegisterRecordRow.CorrGLAccount;
	NewRow.Products = RegisterRecordRow.ProductsCorr;
	NewRow.Characteristic = RegisterRecordRow.CharacteristicCorr;
	NewRow.Batch = RegisterRecordRow.BatchCorr;
	NewRow.SalesOrder = RegisterRecordRow.CustomerCorrOrder;	
	NewRow.Specification = RegisterRecordRow.SpecificationCorr;
	NewRow.SpecificationCorr = RegisterRecordRow.Specification;
	NewRow.StructuralUnitCorr = RegisterRecordRow.StructuralUnit;
	NewRow.CorrGLAccount = RegisterRecordRow.GLAccount;
	NewRow.ProductsCorr = RegisterRecordRow.Products;
	NewRow.CharacteristicCorr = RegisterRecordRow.Characteristic;
	NewRow.BatchCorr = RegisterRecordRow.Batch;
	NewRow.CustomerCorrOrder = RegisterRecordRow.SalesOrder;
	NewRow.FixedCost = FixedCost;
	NewRow.Amount = Amount;
	NewRow.ContentOfAccountingRecord = ContentOfAccountingRecord;
	NewRow.SalesOrder = ?(ValueIsFilled(NewRow.SalesOrder), NewRow.SalesOrder, Undefined);
	NewRow.CustomerCorrOrder = ?(ValueIsFilled(NewRow.CustomerCorrOrder), NewRow.CustomerCorrOrder, Undefined);
	NewRow.CorrSalesOrder = ?(ValueIsFilled(NewRow.CorrSalesOrder), NewRow.CorrSalesOrder, Undefined);
	
	// Movements by register AccountingJournalEntries.
	NewRow = RecordSetAccountingJournalEntries.Add();
	NewRow.Period = Date;
	NewRow.Recorder = Recorder;
	NewRow.Company = RegisterRecordRow.Company;
	NewRow.PlanningPeriod = Catalogs.PlanningPeriods.Actual;
	NewRow.AccountDr = RegisterRecordRow.CorrGLAccount;
	NewRow.AccountCr = RegisterRecordRow.GLAccount;
	NewRow.Amount = Amount; 
	NewRow.Content = ContentOfAccountingRecord;
	
EndProcedure

// Generates correcting movements on the expenses accounting register.
//
// Parameters:
//  No.
//
Procedure GenerateCorrectiveRegisterRecordsByExpensesRegister()
	
	DateBeg = AdditionalProperties.ForPosting.BeginOfPeriodningDate;
	DateEnd = AdditionalProperties.ForPosting.EndDatePeriod;
	
	Query = New Query();
	
	Query.Text =
	"SELECT
	|	CASE
	|		WHEN VALUETYPE(CostAccounting.SourceDocument) = TYPE(Document.InventoryWriteOff)
	|			THEN CostAccounting.SourceDocument.Correspondence
	|		WHEN VALUETYPE(CostAccounting.SourceDocument) = TYPE(Document.InventoryTransfer)
	|			THEN InventoryTransferInventory.ConsumptionGLAccount
	|		ELSE UNDEFINED
	|	END AS GLAccountWriteOff,
	|	CASE
	|		WHEN CostAccounting.RetailTransferEarningAccounting
	|			THEN CASE
	|					WHEN VALUETYPE(CostAccounting.SourceDocument) = TYPE(Document.SupplierInvoice)
	|						THEN CostAccounting.SourceDocument.StructuralUnit
	|					WHEN VALUETYPE(CostAccounting.SourceDocument) = TYPE(Document.InventoryTransfer)
	|						THEN CostAccounting.SourceDocument.StructuralUnitPayee
	|					ELSE UNDEFINED
	|				END
	|		ELSE UNDEFINED
	|	END AS RetailStructuralUnit,
	|	CASE
	|		WHEN VALUETYPE(CostAccounting.SourceDocument) = TYPE(Document.InventoryWriteOff)
	|			THEN CostAccounting.SourceDocument.Correspondence.TypeOfAccount
	|		WHEN VALUETYPE(CostAccounting.SourceDocument) = TYPE(Document.InventoryTransfer)
	|			THEN CostAccounting.SourceDocument.GLExpenseAccount.TypeOfAccount
	|		ELSE UNDEFINED
	|	END AS GLAccountWriteOffAccountType,
	|	CASE
	|		WHEN VALUETYPE(CostAccounting.SourceDocument) = TYPE(Document.InventoryTransfer)
	|			THEN CostAccounting.SourceDocument.BusinessLine
	|		ELSE UNDEFINED
	|	END AS ActivityDirectionWriteOff,
	|	CostAccounting.Company AS Company,
	|	CostAccounting.StructuralUnit AS StructuralUnit,
	|	CASE
	|		WHEN VALUETYPE(CostAccounting.SourceDocument) = TYPE(Document.InventoryTransfer)
	|			THEN CostAccounting.SourceDocument.StructuralUnitPayee
	|		ELSE CostAccounting.SourceDocument.StructuralUnit
	|	END AS StructuralUnitPayee,
	|	CostAccounting.GLAccount AS GLAccount,
	|	CostAccounting.Products AS Products,
	|	CostAccounting.Characteristic AS Characteristic,
	|	CostAccounting.Batch AS Batch,
	|	CostAccounting.SalesOrder AS SalesOrder,
	|	CostAccounting.Specification AS Specification,
	|	CostAccounting.SpecificationCorr AS SpecificationCorr,
	|	CostAccounting.StructuralUnitCorr AS StructuralUnitCorr,
	|	CostAccounting.CorrGLAccount AS CorrGLAccount,
	|	CostAccounting.ProductsCorr AS ProductsCorr,
	|	CostAccounting.CharacteristicCorr AS CharacteristicCorr,
	|	CostAccounting.BatchCorr AS BatchCorr,
	|	CostAccounting.CustomerCorrOrder AS CustomerCorrOrder,
	|	SUM(CASE
	|			WHEN CostAccounting.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN CostAccounting.Quantity
	|			ELSE -CostAccounting.Quantity
	|		END) AS Quantity,
	|	SUM(CASE
	|			WHEN CostAccounting.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN CostAccounting.Amount
	|			ELSE -CostAccounting.Amount
	|		END) AS Amount,
	|	CostAccounting.Products.ProductsCategory AS ProductsProductsCategory,
	|	CostAccounting.Products.BusinessLine AS BusinessLineSales,
	|	CostAccounting.Products.BusinessLine.GLAccountCostOfSales AS BusinessLineSalesGLAccountOfSalesCost,
	|	CostAccounting.Products.BusinessLine.GLAccountCostOfSales.TypeOfAccount AS BusinessLineSalesSalesCostGLAccountAccountType,
	|	CostAccounting.SourceDocument AS SourceDocument,
	|	CostAccounting.CorrSalesOrder AS CorrSalesOrder,
	|	CostAccounting.Department AS Department,
	|	CostAccounting.Responsible AS Responsible,
	|	CostAccounting.VATRate AS VATRate,
	|	CostAccounting.ProductionExpenses AS ProductionExpenses,
	|	CostAccounting.RetailTransferEarningAccounting AS RetailTransferEarningAccounting
	|INTO CostAccountingWriteOff
	|FROM
	|	AccumulationRegister.Inventory AS CostAccounting
	|		LEFT JOIN Document.InventoryTransfer.Inventory AS InventoryTransferInventory
	|		ON CostAccounting.SourceDocument = InventoryTransferInventory.Ref
	|WHERE
	|	CostAccounting.Period BETWEEN &DateBeg AND &DateEnd
	|	AND CostAccounting.RecordType = VALUE(AccumulationRecordType.Expense)
	|	AND NOT CostAccounting.Return
	|	AND CostAccounting.Company = &Company
	|	AND NOT CostAccounting.FixedCost
	|
	|GROUP BY
	|	CASE
	|		WHEN CostAccounting.RetailTransferEarningAccounting
	|			THEN CASE
	|					WHEN VALUETYPE(CostAccounting.SourceDocument) = TYPE(Document.SupplierInvoice)
	|						THEN CostAccounting.SourceDocument.StructuralUnit
	|					WHEN VALUETYPE(CostAccounting.SourceDocument) = TYPE(Document.InventoryTransfer)
	|						THEN CostAccounting.SourceDocument.StructuralUnitPayee
	|					ELSE UNDEFINED
	|				END
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN VALUETYPE(CostAccounting.SourceDocument) = TYPE(Document.InventoryWriteOff)
	|			THEN CostAccounting.SourceDocument.Correspondence.TypeOfAccount
	|		WHEN VALUETYPE(CostAccounting.SourceDocument) = TYPE(Document.InventoryTransfer)
	|			THEN CostAccounting.SourceDocument.GLExpenseAccount.TypeOfAccount
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN VALUETYPE(CostAccounting.SourceDocument) = TYPE(Document.InventoryTransfer)
	|			THEN CostAccounting.SourceDocument.BusinessLine
	|		ELSE UNDEFINED
	|	END,
	|	CostAccounting.Company,
	|	CostAccounting.StructuralUnit,
	|	CASE
	|		WHEN VALUETYPE(CostAccounting.SourceDocument) = TYPE(Document.InventoryTransfer)
	|			THEN CostAccounting.SourceDocument.StructuralUnitPayee
	|		ELSE CostAccounting.SourceDocument.StructuralUnit
	|	END,
	|	CostAccounting.GLAccount,
	|	CostAccounting.Products,
	|	CostAccounting.Characteristic,
	|	CostAccounting.Batch,
	|	CostAccounting.SalesOrder,
	|	CostAccounting.Specification,
	|	CostAccounting.SpecificationCorr,
	|	CostAccounting.StructuralUnitCorr,
	|	CostAccounting.CorrGLAccount,
	|	CostAccounting.ProductsCorr,
	|	CostAccounting.CharacteristicCorr,
	|	CostAccounting.BatchCorr,
	|	CostAccounting.CustomerCorrOrder,
	|	CostAccounting.Products.ProductsCategory,
	|	CostAccounting.Products.BusinessLine,
	|	CostAccounting.Products.BusinessLine.GLAccountCostOfSales,
	|	CostAccounting.Products.BusinessLine.GLAccountCostOfSales.TypeOfAccount,
	|	CostAccounting.SourceDocument,
	|	CostAccounting.CorrSalesOrder,
	|	CostAccounting.Department,
	|	CostAccounting.Responsible,
	|	CostAccounting.VATRate,
	|	CostAccounting.ProductionExpenses,
	|	CostAccounting.RetailTransferEarningAccounting,
	|	CASE
	|		WHEN VALUETYPE(CostAccounting.SourceDocument) = TYPE(Document.InventoryWriteOff)
	|			THEN CostAccounting.SourceDocument.Correspondence
	|		WHEN VALUETYPE(CostAccounting.SourceDocument) = TYPE(Document.InventoryTransfer)
	|			THEN InventoryTransferInventory.ConsumptionGLAccount
	|		ELSE UNDEFINED
	|	END
	|
	|INDEX BY
	|	Company,
	|	StructuralUnit,
	|	GLAccount,
	|	Products,
	|	Characteristic,
	|	Batch,
	|	SalesOrder
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	WriteOffCostAdjustment.Company AS Company,
	|	WriteOffCostAdjustment.StructuralUnit AS StructuralUnit,
	|	CostAccounting.StructuralUnitPayee AS StructuralUnitPayee,
	|	WriteOffCostAdjustment.GLAccount AS GLAccount,
	|	WriteOffCostAdjustment.GLAccount.TypeOfAccount AS GLAccountGLAccountType,
	|	WriteOffCostAdjustment.Products AS Products,
	|	WriteOffCostAdjustment.Characteristic AS Characteristic,
	|	WriteOffCostAdjustment.Batch AS Batch,
	|	WriteOffCostAdjustment.SalesOrder AS SalesOrder,
	|	WriteOffCostAdjustment.NodeNo AS NodeNo,
	|	CostAccounting.Specification AS Specification,
	|	CostAccounting.SpecificationCorr AS SpecificationCorr,
	|	CostAccounting.GLAccountWriteOff AS GLAccountWriteOff,
	|	CostAccounting.GLAccountWriteOffAccountType AS GLAccountWriteOffAccountType,
	|	CostAccounting.StructuralUnitCorr AS StructuralUnitCorr,
	|	CostAccounting.CorrGLAccount AS CorrGLAccount,
	|	CostAccounting.CorrGLAccount.TypeOfAccount AS CorrAccountFinancialAccountType,
	|	CostAccounting.ProductsCorr AS ProductsCorr,
	|	CostAccounting.CharacteristicCorr AS CharacteristicCorr,
	|	CostAccounting.BatchCorr AS BatchCorr,
	|	CostAccounting.CustomerCorrOrder AS CustomerCorrOrder,
	|	CASE
	|		WHEN ISNULL(CostAccounting.Quantity, 0) = 0
	|			THEN ISNULL(CostAccounting.Amount, 0)
	|		ELSE ISNULL(CostAccounting.Quantity, 0)
	|	END AS Quantity,
	|	ISNULL(CostAccounting.Amount, 0) AS Amount,
	|	ISNULL(SolutionsTable.Amount, 0) AS Price,
	|	CostAccounting.ProductsProductsCategory AS ProductsProductsCategory,
	|	CostAccounting.BusinessLineSales AS BusinessLineSales,
	|	CostAccounting.BusinessLineSalesGLAccountOfSalesCost AS BusinessLineSalesGLAccountOfSalesCost,
	|	CostAccounting.BusinessLineSalesSalesCostGLAccountAccountType AS BusinessLineSalesSalesCostGLAccountAccountType,
	|	CostAccounting.SourceDocument AS SourceDocument,
	|	CostAccounting.CorrSalesOrder AS CorrSalesOrder,
	|	CostAccounting.Department AS Department,
	|	CostAccounting.Responsible AS Responsible,
	|	CostAccounting.VATRate AS VATRate,
	|	CostAccounting.ProductionExpenses AS ProductionExpenses,
	|	CostAccounting.ActivityDirectionWriteOff AS ActivityDirectionWriteOff,
	|	CostAccounting.RetailTransferEarningAccounting AS RetailTransferEarningAccounting,
	|	CostAccounting.RetailStructuralUnit AS RetailStructuralUnit
	|FROM
	|	InformationRegister.WriteOffCostAdjustment AS WriteOffCostAdjustment
	|		LEFT JOIN CostAccountingWriteOff AS CostAccounting
	|		ON WriteOffCostAdjustment.Company = CostAccounting.Company
	|			AND WriteOffCostAdjustment.StructuralUnit = CostAccounting.StructuralUnit
	|			AND WriteOffCostAdjustment.GLAccount = CostAccounting.GLAccount
	|			AND WriteOffCostAdjustment.Products = CostAccounting.Products
	|			AND WriteOffCostAdjustment.Characteristic = CostAccounting.Characteristic
	|			AND WriteOffCostAdjustment.Batch = CostAccounting.Batch
	|			AND WriteOffCostAdjustment.SalesOrder = CostAccounting.SalesOrder
	|		LEFT JOIN SolutionsTable AS SolutionsTable
	|		ON (SolutionsTable.NodeNo = WriteOffCostAdjustment.NodeNo)
	|WHERE
	|	WriteOffCostAdjustment.Recorder = &Recorder
	|
	|ORDER BY
	|	NodeNo DESC";
	
	Query.TempTablesManager = AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.SetParameter("DateBeg",	DateBeg);
	Query.SetParameter("DateEnd",	DateEnd);
	Query.SetParameter("Recorder",	Ref);
	Query.SetParameter("Company",	AdditionalProperties.ForPosting.Company);
	
	Result = Query.ExecuteBatch();
	
	If Result[1].IsEmpty() Then
		Return;
	EndIf;
	
	RecordSetInventory = AccumulationRegisters.Inventory.CreateRecordSet();
	RecordSetInventory.Filter.Recorder.Set(Ref);
	
	RecordSetSales = AccumulationRegisters.Sales.CreateRecordSet();
	RecordSetSales.Filter.Recorder.Set(Ref);
	
	RecordSetIncomeAndExpenses = AccumulationRegisters.IncomeAndExpenses.CreateRecordSet();
	RecordSetIncomeAndExpenses.Filter.Recorder.Set(Ref);
	
	RecordSetPOSSummary = AccumulationRegisters.POSSummary.CreateRecordSet();
	RecordSetPOSSummary.Filter.Recorder.Set(Ref);
	
	RecordSetAccountingJournalEntries = AccountingRegisters.AccountingJournalEntries.CreateRecordSet();
	RecordSetAccountingJournalEntries.Filter.Recorder.Set(Ref);
	
	SelectionDetailRecords = Result[1].Select();
	
	While SelectionDetailRecords.Next() Do
		
		// Calculate amounts of transfer and correction.
		SumOfMovement = SelectionDetailRecords.Price * SelectionDetailRecords.Quantity;
		CorrectionAmount = SumOfMovement - SelectionDetailRecords.Amount;
		
		If Round(CorrectionAmount, 2) <> 0 Then
			
			// Movements on the register Inventory and costs accounting.
			GenerateRegisterRecordsByExpensesRegister(
				RecordSetInventory,
				RecordSetAccountingJournalEntries,
				SelectionDetailRecords,
				CorrectionAmount,
				False);
			
			If SelectionDetailRecords.CorrGLAccount = AdditionalProperties.ForPosting.EmptyAccount Then
				
				If ValueIsFilled(SelectionDetailRecords.SourceDocument)
					AND ((TypeOf(SelectionDetailRecords.SourceDocument) = Type("DocumentRef.SalesInvoice")
							AND SelectionDetailRecords.GLAccountWriteOffAccountType <> Enums.GLAccountsTypes.OtherIncome)
						OR TypeOf(SelectionDetailRecords.SourceDocument) = Type("DocumentRef.ShiftClosure")
						OR TypeOf(SelectionDetailRecords.SourceDocument) = Type("DocumentRef.AccountSalesFromConsignee")
						OR TypeOf(SelectionDetailRecords.SourceDocument) = Type("DocumentRef.SalesOrder")
						OR TypeOf(SelectionDetailRecords.SourceDocument) = Type("DocumentRef.SubcontractorReportIssued")) Then
					
					// Movements on the register Sales.
					NewRow = RecordSetSales.Add();
					NewRow.Period				= Date;
					NewRow.Recorder				= Ref;
					NewRow.Company				= SelectionDetailRecords.Company;
					NewRow.SalesOrder			= SelectionDetailRecords.CorrSalesOrder;
					NewRow.Department			= SelectionDetailRecords.Department;
					NewRow.Responsible			= SelectionDetailRecords.Responsible;
					NewRow.Products				= SelectionDetailRecords.Products;
					NewRow.Characteristic		= SelectionDetailRecords.Characteristic;
					NewRow.Batch				= SelectionDetailRecords.Batch;
					NewRow.Document				= SelectionDetailRecords.SourceDocument;
					NewRow.VATRate				= SelectionDetailRecords.VATRate;
					NewRow.Cost					= CorrectionAmount;
					
					// Movements on the register IncomeAndExpenses.
					NewRow = RecordSetIncomeAndExpenses.Add();
					NewRow.Period						= Date;
					NewRow.Recorder						= Ref;
					NewRow.Company						= SelectionDetailRecords.Company;
					NewRow.StructuralUnit				= SelectionDetailRecords.Department;
					NewRow.SalesOrder					= SelectionDetailRecords.CorrSalesOrder;
					If Not ValueIsFilled(NewRow.SalesOrder) Then
						NewRow.SalesOrder = Undefined;
					EndIf;
					NewRow.BusinessLine					= SelectionDetailRecords.BusinessLineSales;
					NewRow.GLAccount					= SelectionDetailRecords.BusinessLineSalesGLAccountOfSalesCost;
					NewRow.AmountExpense				= CorrectionAmount;
					NewRow.ContentOfAccountingRecord	= NStr("en = 'Record expenses'");
					
					// Movements by register AccountingJournalEntries.
					NewRow = RecordSetAccountingJournalEntries.Add();
					NewRow.Period = Date;
					NewRow.Recorder = Ref;
					NewRow.Company = SelectionDetailRecords.Company;
					NewRow.PlanningPeriod	= Catalogs.PlanningPeriods.Actual;
					NewRow.AccountDr		= SelectionDetailRecords.BusinessLineSalesGLAccountOfSalesCost;
					NewRow.AccountCr		= SelectionDetailRecords.GLAccount;
					NewRow.Content			= NStr("en = 'Record expenses'");
					NewRow.Amount			= CorrectionAmount;
					
				ElsIf ValueIsFilled(SelectionDetailRecords.SourceDocument)
						AND SelectionDetailRecords.GLAccountWriteOffAccountType = Enums.GLAccountsTypes.OtherIncome Then
						
					// Movements on the register Income and expenses.
					NewRow = RecordSetIncomeAndExpenses.Add();
					NewRow.Period = AdditionalProperties.ForPosting.Date;
					NewRow.Recorder = Ref;
					NewRow.Company = SelectionDetailRecords.Company;
					NewRow.StructuralUnit = SelectionDetailRecords.StructuralUnitPayee;
					NewRow.BusinessLine = Catalogs.LinesOfBusiness.Other;
					
					NewRow.GLAccount = SelectionDetailRecords.GLAccountWriteOff;
					NewRow.AmountExpense = CorrectionAmount;
					NewRow.ContentOfAccountingRecord = NStr("en = 'Other expenses'");
					
					// Movements by register AccountingJournalEntries.
					NewRow = RecordSetAccountingJournalEntries.Add();
					NewRow.Period = Date;
					NewRow.Recorder = Ref;
					NewRow.Company = SelectionDetailRecords.Company;
					NewRow.PlanningPeriod = Catalogs.PlanningPeriods.Actual;
					NewRow.AccountDr = SelectionDetailRecords.GLAccountWriteOff;
					NewRow.AccountCr = SelectionDetailRecords.GLAccount;
					NewRow.Content = NStr("en = 'Other expenses'");
					NewRow.Amount = CorrectionAmount;
					
				ElsIf SelectionDetailRecords.RetailTransferEarningAccounting Then
					
					// Movements on the register POSSummary.
					NewRow = RecordSetPOSSummary.Add();
					NewRow.Period = Date;
					NewRow.RecordType = AccumulationRecordType.Receipt;
					NewRow.Recorder = Ref;
					NewRow.Company = SelectionDetailRecords.Company;
					NewRow.StructuralUnit = SelectionDetailRecords.RetailStructuralUnit;
					NewRow.Currency = SelectionDetailRecords.RetailStructuralUnit.RetailPriceKind.PriceCurrency;
					NewRow.ContentOfAccountingRecord = NStr("en = 'Move to retail'");
					NewRow.Cost = CorrectionAmount;
					
					// Movements by register AccountingJournalEntries.
					NewRow = RecordSetAccountingJournalEntries.Add();
					NewRow.Period = Date;
					NewRow.Recorder = Ref;
					NewRow.Company = SelectionDetailRecords.Company;
					NewRow.PlanningPeriod = Catalogs.PlanningPeriods.Actual;
					NewRow.AccountDr = SelectionDetailRecords.RetailStructuralUnit.GLAccountInRetail;
					NewRow.AccountCr = SelectionDetailRecords.GLAccount;
					NewRow.Content = NStr("en = 'Move to retail'");
					NewRow.Amount = CorrectionAmount; 
					
				ElsIf SelectionDetailRecords.GLAccountWriteOffAccountType = Enums.GLAccountsTypes.OtherExpenses
					  OR SelectionDetailRecords.GLAccountWriteOffAccountType = Enums.GLAccountsTypes.Expenses Then
					
					// Movements on the register Income and expenses.
					NewRow = RecordSetIncomeAndExpenses.Add();
					NewRow.Period = AdditionalProperties.ForPosting.Date;
					NewRow.Recorder = Ref;
					NewRow.Company = SelectionDetailRecords.Company;
					NewRow.StructuralUnit = SelectionDetailRecords.StructuralUnitPayee;
					
					If TypeOf(SelectionDetailRecords.SourceDocument) = Type("DocumentRef.InventoryTransfer")
					   AND SelectionDetailRecords.GLAccountWriteOffAccountType = Enums.GLAccountsTypes.Expenses Then
						NewRow.BusinessLine = SelectionDetailRecords.ActivityDirectionWriteOff;
						NewRow.SalesOrder = SelectionDetailRecords.SalesOrder;
						If Not ValueIsFilled(NewRow.SalesOrder) Then
							NewRow.SalesOrder = Undefined;
						EndIf;
					Else
						NewRow.BusinessLine = Catalogs.LinesOfBusiness.Other;
					EndIf;
					
					NewRow.GLAccount = SelectionDetailRecords.GLAccountWriteOff;
					NewRow.AmountExpense = CorrectionAmount;
					NewRow.ContentOfAccountingRecord = NStr("en = 'Other expenses'");
					
					// Movements by register AccountingJournalEntries.
					NewRow = RecordSetAccountingJournalEntries.Add();
					NewRow.Period = Date;
					NewRow.Recorder = Ref;
					NewRow.Company = SelectionDetailRecords.Company;
					NewRow.PlanningPeriod = Catalogs.PlanningPeriods.Actual;
					NewRow.AccountDr = SelectionDetailRecords.GLAccountWriteOff;
					NewRow.AccountCr = SelectionDetailRecords.GLAccount;
					NewRow.Content = NStr("en = 'Other expenses'");
					NewRow.Amount = CorrectionAmount;
					
				Else
					
					// Movements by register AccountingJournalEntries.
					NewRow = RecordSetAccountingJournalEntries.Add();
					NewRow.Period = Date;
					NewRow.Recorder = Ref;
					NewRow.Company = SelectionDetailRecords.Company;
					NewRow.PlanningPeriod = Catalogs.PlanningPeriods.Actual;
					NewRow.AccountDr = SelectionDetailRecords.GLAccountWriteOff;
					NewRow.AccountCr = SelectionDetailRecords.GLAccount;
					NewRow.Content = NStr("en = 'Inventory write-off'");
					NewRow.Amount = CorrectionAmount;
					
				EndIf;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	RecordSetInventory.Write(False);
	RecordSetSales.Write(False);
	RecordSetIncomeAndExpenses.Write(False);
	RecordSetPOSSummary.Write(False);
	RecordSetAccountingJournalEntries.Write(False);
	
EndProcedure

// Generates correcting movements on the expenses accounting register.
//
// Parameters:
//  No.
//
Procedure GenerateCorrectiveRegisterRecordsByFIFO()
	
	DateBeg = AdditionalProperties.ForPosting.BeginOfPeriodningDate;
	DateEnd = AdditionalProperties.ForPosting.EndDatePeriod;
	Company = AdditionalProperties.ForPosting.Company;
	
	FIFO.CalculateAll(EndOfMonth(DateEnd), Company);
	
	Query = New Query();
	
	Query.Text =
	"SELECT
	|	CostLayers.Recorder AS Recorder,
	|	CostLayers.Period AS Period,
	|	CostLayers.RecordType AS RecordType,
	|	CostLayers.Company AS Company,
	|	CostLayers.Products AS Products,
	|	CostLayers.SalesOrder AS SalesOrder,
	|	CostLayers.Characteristic AS Characteristic,
	|	CostLayers.Batch AS Batch,
	|	CostLayers.StructuralUnit AS StructuralUnit,
	|	CostLayers.GLAccount AS GLAccount,
	|	0 AS Quantity,
	|	SUM(CostLayers.Amount) AS Amount,
	|	CostLayers.VATRate AS VATRate,
	|	CostLayers.Responsible AS Responsible,
	|	CostLayers.Department AS Department,
	|	CostLayers.SourceDocument AS SourceDocument,
	|	CostLayers.CorrSalesOrder AS CorrSalesOrder,
	|	CostLayers.CorrStructuralUnit AS CorrStructuralUnit,
	|	CostLayers.CorrGLAccount AS CorrGLAccount,
	|	CostLayers.RIMTransfer AS RetailTransferEarningAccounting,
	|	CostLayers.SalesRep AS SalesRep
	|INTO Costslayers
	|FROM
	|	AccumulationRegister.InventoryCostLayer AS CostLayers
	|WHERE
	|	CostLayers.Period BETWEEN &DateBeg AND &DateEnd
	|	AND CostLayers.Company = &Company
	|	AND NOT CostLayers.SourceRecord
	|
	|GROUP BY
	|	CostLayers.Recorder,
	|	CostLayers.Period,
	|	CostLayers.RecordType,
	|	CostLayers.Company,
	|	CostLayers.StructuralUnit,
	|	CostLayers.GLAccount,
	|	CostLayers.Products,
	|	CostLayers.Characteristic,
	|	CostLayers.Batch,
	|	CostLayers.SalesOrder,
	|	CostLayers.CorrStructuralUnit,
	|	CostLayers.CorrSalesOrder,
	|	CostLayers.CorrGLAccount,
	|	CostLayers.SourceDocument,
	|	CostLayers.Department,
	|	CostLayers.Responsible,
	|	CostLayers.VATRate,
	|	CostLayers.RIMTransfer,
	|	CostLayers.SalesRep
	|
	|UNION ALL
	|
	|SELECT
	|	LandedCosts.Recorder AS Recorder,
	|	LandedCosts.Period AS Period,
	|	LandedCosts.RecordType AS RecordType,
	|	LandedCosts.Company AS Company,
	|	LandedCosts.Products AS Products,
	|	LandedCosts.SalesOrder AS SalesOrder,
	|	LandedCosts.Characteristic AS Characteristic,
	|	LandedCosts.Batch AS Batch,
	|	LandedCosts.StructuralUnit AS StructuralUnit,
	|	LandedCosts.GLAccount AS GLAccount,
	|	0 AS Quantity,
	|	SUM(LandedCosts.Amount) AS Amount,
	|	LandedCosts.VATRate AS VATRate,
	|	LandedCosts.Responsible AS Responsible,
	|	LandedCosts.Department AS Department,
	|	LandedCosts.SourceDocument AS SourceDocument,
	|	LandedCosts.CorrSalesOrder AS CorrSalesOrder,
	|	LandedCosts.CorrStructuralUnit AS CorrStructuralUnit,
	|	LandedCosts.CorrGLAccount AS CorrGLAccount,
	|	LandedCosts.RIMTransfer AS RetailTransferEarningAccounting,
	|	LandedCosts.SalesRep AS SalesRep
	|FROM
	|	AccumulationRegister.LandedCosts AS LandedCosts
	|WHERE
	|	LandedCosts.Period BETWEEN &DateBeg AND &DateEnd
	|	AND LandedCosts.Company = &Company
	|	AND NOT LandedCosts.SourceRecord
	|
	|GROUP BY
	|	LandedCosts.Recorder,
	|	LandedCosts.Period,
	|	LandedCosts.RecordType,
	|	LandedCosts.Company,
	|	LandedCosts.StructuralUnit,
	|	LandedCosts.GLAccount,
	|	LandedCosts.Products,
	|	LandedCosts.Characteristic,
	|	LandedCosts.Batch,
	|	LandedCosts.SalesOrder,
	|	LandedCosts.CorrStructuralUnit,
	|	LandedCosts.CorrSalesOrder,
	|	LandedCosts.CorrGLAccount,
	|	LandedCosts.SourceDocument,
	|	LandedCosts.Department,
	|	LandedCosts.Responsible,
	|	LandedCosts.VATRate,
	|	LandedCosts.RIMTransfer,
	|	LandedCosts.SalesRep
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CostLayers.Recorder AS Recorder,
	|	CostLayers.Period AS Period,
	|	CostLayers.RecordType AS RecordType,
	|	CostLayers.Company AS Company,
	|	CostLayers.Products AS Products,
	|	CostLayers.SalesOrder AS SalesOrder,
	|	CostLayers.Characteristic AS Characteristic,
	|	CostLayers.Batch AS Batch,
	|	CostLayers.StructuralUnit AS StructuralUnit,
	|	CostLayers.GLAccount AS GLAccount,
	|	CostLayers.Quantity AS Quantity,
	|	SUM(CostLayers.Amount) AS Amount,
	|	CostLayers.VATRate AS VATRate,
	|	CostLayers.Responsible AS Responsible,
	|	CostLayers.Department AS Department,
	|	CostLayers.SourceDocument AS SourceDocument,
	|	CostLayers.CorrSalesOrder AS CorrSalesOrder,
	|	CostLayers.CorrStructuralUnit AS CorrStructuralUnit,
	|	CostLayers.CorrGLAccount AS CorrGLAccount,
	|	CostLayers.RetailTransferEarningAccounting AS RetailTransferEarningAccounting,
	|	CostLayers.SalesRep AS SalesRep
	|INTO FullCostslayers
	|FROM
	|	Costslayers AS CostLayers
	|
	|GROUP BY
	|	CostLayers.Recorder,
	|	CostLayers.Period,
	|	CostLayers.RecordType,
	|	CostLayers.Company,
	|	CostLayers.Products,
	|	CostLayers.SalesOrder,
	|	CostLayers.Characteristic,
	|	CostLayers.Batch,
	|	CostLayers.StructuralUnit,
	|	CostLayers.GLAccount,
	|	CostLayers.Quantity,
	|	CostLayers.VATRate,
	|	CostLayers.Responsible,
	|	CostLayers.Department,
	|	CostLayers.SourceDocument,
	|	CostLayers.CorrSalesOrder,
	|	CostLayers.CorrStructuralUnit,
	|	CostLayers.CorrGLAccount,
	|	CostLayers.RetailTransferEarningAccounting,
	|	CostLayers.SalesRep
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CostLayers.Recorder AS Ref,
	|	CostLayers.Period AS Period,
	|	CostLayers.RecordType AS RecordType,
	|	CostLayers.Company AS Company,
	|	CostLayers.StructuralUnit AS StructuralUnit,
	|	CostLayers.GLAccount AS GLAccount,
	|	CostLayers.Products AS Products,
	|	CostLayers.Characteristic AS Characteristic,
	|	CostLayers.Batch AS Batch,
	|	CostLayers.SalesOrder AS SalesOrder,
	|	CostLayers.Quantity AS Quantity,
	|	CostLayers.Amount AS Amount,
	|	CostLayers.CorrStructuralUnit AS StructuralUnitCorr,
	|	CostLayers.CorrGLAccount AS CorrGLAccount,
	|	UNDEFINED AS ProductsCorr,
	|	UNDEFINED AS CharacteristicCorr,
	|	UNDEFINED AS BatchCorr,
	|	UNDEFINED AS CustomerCorrOrder,
	|	UNDEFINED AS Specification,
	|	UNDEFINED AS SpecificationCorr,
	|	CostLayers.CorrSalesOrder AS CorrSalesOrder,
	|	CostLayers.SourceDocument AS SourceDocument,
	|	CostLayers.Department AS Department,
	|	CostLayers.Responsible AS Responsible,
	|	CostLayers.VATRate AS VATRate,
	|	FALSE AS FixedCost,
	|	FALSE AS ProductionExpenses,
	|	CASE
	|		WHEN VALUETYPE(CostLayers.Recorder) = TYPE(Document.CreditNote)
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS Return,
	|	UNDEFINED AS ContentOfAccountingRecord,
	|	CostLayers.RetailTransferEarningAccounting AS RetailTransferEarningAccounting,
	|	LineOfBusiness.GLAccountCostOfSales AS GLAccountCostOfSales,
	|	CASE
	|		WHEN CostLayers.RetailTransferEarningAccounting
	|			THEN ISNULL(SupplierInvoice.StructuralUnit, InventoryTransfer.StructuralUnit)
	|		ELSE UNDEFINED
	|	END AS StructuralUnitPayee,
	|	RetailPriceTypes.PriceCurrency AS RetailPriceCurrency,
	|	RetailBusinessUnits.GLAccountInRetail AS GLAccountInRetail,
	|	Products.BusinessLine AS BusinessLine,
	|	DebitNote.GLAccount AS GLAccountPurchaseReturns,
	|	CostLayers.SalesRep AS SalesRep
	|FROM
	|	FullCostslayers AS CostLayers
	|		LEFT JOIN Catalog.Products AS Product
	|		ON CostLayers.Products = Product.Ref
	|		LEFT JOIN Catalog.LinesOfBusiness AS LineOfBusiness
	|		ON (Product.BusinessLine = LineOfBusiness.Ref)
	|		LEFT JOIN ChartOfAccounts.PrimaryChartOfAccounts AS PrimaryGLAccountCostOfSales
	|		ON (LineOfBusiness.GLAccountCostOfSales = PrimaryGLAccountCostOfSales.Ref)
	|		LEFT JOIN Document.SupplierInvoice AS SupplierInvoice
	|		ON CostLayers.SourceDocument = SupplierInvoice.Ref
	|		LEFT JOIN Document.InventoryTransfer AS InventoryTransfer
	|		ON CostLayers.Recorder = InventoryTransfer.Ref
	|		LEFT JOIN Catalog.BusinessUnits AS RetailBusinessUnits
	|		ON CostLayers.CorrStructuralUnit = RetailBusinessUnits.Ref
	|		LEFT JOIN Catalog.PriceTypes AS RetailPriceTypes
	|		ON (RetailBusinessUnits.RetailPriceKind = RetailPriceTypes.Ref)
	|		LEFT JOIN Document.DebitNote AS DebitNote
	|		ON CostLayers.Recorder = DebitNote.Ref
	|TOTALS BY
	|	Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP Costslayers
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP FullCostslayers";
	
	Query.TempTablesManager = AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.SetParameter("DateBeg", DateBeg);
	Query.SetParameter("DateEnd", DateEnd);
	Query.SetParameter("Company", AdditionalProperties.ForPosting.Company);
	
	Result = Query.Execute();
	
	If Result.IsEmpty() Then
		Return;
	EndIf;
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();
	
	Selection = Result.Select(QueryResultIteration.ByGroups);
	While Selection.Next() Do
	
		RecordSetInventory = AccumulationRegisters.Inventory.CreateRecordSet();
		RecordSetInventory.Filter.Recorder.Set(Selection.Ref);
	
		RecordSetSales = AccumulationRegisters.Sales.CreateRecordSet();
		RecordSetSales.Filter.Recorder.Set(Selection.Ref);
		
		RecordSetIncomeAndExpenses = AccumulationRegisters.IncomeAndExpenses.CreateRecordSet();
		RecordSetIncomeAndExpenses.Filter.Recorder.Set(Selection.Ref);
	
		RecordSetPOSSummary = AccumulationRegisters.POSSummary.CreateRecordSet();
		RecordSetPOSSummary.Filter.Recorder.Set(Selection.Ref);
		
		RecordSetAccountingJournalEntries = AccountingRegisters.AccountingJournalEntries.CreateRecordSet();
		RecordSetAccountingJournalEntries.Filter.Recorder.Set(Selection.Ref);
	
		SelectionDetailRecords = Selection.Select();
	
		While SelectionDetailRecords.Next() Do
			
			Record = RecordSetInventory.Add();
			FillPropertyValues(Record, SelectionDetailRecords);
			
			If SelectionDetailRecords.RecordType = AccumulationRecordType.Receipt
				And Not TypeOf(SelectionDetailRecords.Ref) = Type("DocumentRef.CreditNote") Then
				Continue;
			EndIf;
			
			If TypeOf(SelectionDetailRecords.Ref) = Type("DocumentRef.CreditNote") Then
				Denominator = -1;
			Else
				Denominator = 1;
			EndIf;
				
			If ValueIsFilled(SelectionDetailRecords.SourceDocument)
				AND (TypeOf(SelectionDetailRecords.SourceDocument) = Type("DocumentRef.SalesInvoice")
					OR TypeOf(SelectionDetailRecords.SourceDocument) = Type("DocumentRef.ShiftClosure")
					OR TypeOf(SelectionDetailRecords.SourceDocument) = Type("DocumentRef.AccountSalesFromConsignee")
					OR TypeOf(SelectionDetailRecords.SourceDocument) = Type("DocumentRef.SalesOrder")
					OR TypeOf(SelectionDetailRecords.SourceDocument) = Type("DocumentRef.SubcontractorReportIssued"))
				AND TypeOf(SelectionDetailRecords.Ref) <> Type("DocumentRef.SalesOrder") Then
					
				// Movements on the register Sales.
				Record = RecordSetSales.Add();
				FillPropertyValues(Record, SelectionDetailRecords);
				Record.Document  = SelectionDetailRecords.SourceDocument;
				Record.Amount    = 0;
				Record.VATAmount = 0;
				Record.Quantity  = 0;
				Record.Cost      = SelectionDetailRecords.Amount * Denominator;
				
				// Movements on the register IncomeAndExpenses.
				Record = RecordSetIncomeAndExpenses.Add();
				FillPropertyValues(Record, SelectionDetailRecords);
				Record.GLAccount     = SelectionDetailRecords.GLAccountCostOfSales;
				Record.AmountIncome  = 0;
				Record.AmountExpense = SelectionDetailRecords.Amount * Denominator;
				Record.ContentOfAccountingRecord = NStr("en = 'Record expenses'", MainLanguageCode);
				If Not ValueIsFilled(Record.SalesOrder) Then
					Record.SalesOrder = Undefined;
				EndIf;
				
				// Movements by register AccountingJournalEntries.
				Record = RecordSetAccountingJournalEntries.Add();
				Record.Period         = SelectionDetailRecords.Period;
				Record.Company        = SelectionDetailRecords.Company;
				Record.PlanningPeriod = Catalogs.PlanningPeriods.Actual;
				If Denominator < 1 Then
					Record.AccountDr      = SelectionDetailRecords.GLAccount;
					Record.AccountCr      = SelectionDetailRecords.GLAccountCostOfSales;
				Else
					Record.AccountDr      = SelectionDetailRecords.GLAccountCostOfSales;
					Record.AccountCr      = SelectionDetailRecords.GLAccount;
				EndIf;
				Record.Content        = NStr("en = 'Record expenses'", MainLanguageCode);
				Record.Amount         = SelectionDetailRecords.Amount;
					
			ElsIf ValueIsFilled(SelectionDetailRecords.SourceDocument)
					AND SelectionDetailRecords.CorrGLAccount = Enums.GLAccountsTypes.OtherIncome Then
					
				// Movements on the register Income and expenses.
				Record = RecordSetIncomeAndExpenses.Add();
				Record.Period         = SelectionDetailRecords.Period;
				Record.Company        = SelectionDetailRecords.Company;
				Record.StructuralUnit = SelectionDetailRecords.StructuralUnitCorr;
				Record.BusinessLine   = Catalogs.LinesOfBusiness.Other;
				Record.GLAccount      = SelectionDetailRecords.CorrGLAccount;
				Record.AmountExpense  = SelectionDetailRecords.Amount * Denominator;
				Record.ContentOfAccountingRecord = NStr("en = 'Other expenses'", MainLanguageCode);
				
				// Movements by register AccountingJournalEntries.
				Record = RecordSetAccountingJournalEntries.Add();
				Record.Period         = SelectionDetailRecords.Period;
				Record.Company        = SelectionDetailRecords.Company;
				Record.PlanningPeriod = Catalogs.PlanningPeriods.Actual;
				Record.AccountDr      = SelectionDetailRecords.CorrGLAccount;
				Record.AccountCr      = SelectionDetailRecords.GLAccount;
				Record.Amount         = SelectionDetailRecords.Amount * Denominator;
				Record.Content        = NStr("en = 'Other expenses'", MainLanguageCode);
				
			ElsIf SelectionDetailRecords.RetailTransferEarningAccounting Then
				
				// Movements on the register POSSummary.
				Record = RecordSetPOSSummary.Add();
				Record.Period         = SelectionDetailRecords.Period;
				Record.RecordType     = AccumulationRecordType.Receipt;
				Record.Company        = SelectionDetailRecords.Company;
				Record.StructuralUnit = SelectionDetailRecords.StructuralUnitCorr;
				Record.Currency       = SelectionDetailRecords.RetailPriceCurrency;
				Record.Cost           = SelectionDetailRecords.Amount * Denominator;
				Record.ContentOfAccountingRecord = NStr("en = 'Move to retail'", MainLanguageCode);
				
				// Movements by register AccountingJournalEntries.
				Record = RecordSetAccountingJournalEntries.Add();
				Record.Period         = SelectionDetailRecords.Period;
				Record.Company        = SelectionDetailRecords.Company;
				Record.PlanningPeriod = Catalogs.PlanningPeriods.Actual;
				Record.AccountDr      = SelectionDetailRecords.GLAccountInRetail;
				Record.AccountCr      = SelectionDetailRecords.GLAccount;
				Record.Amount         = SelectionDetailRecords.Amount * Denominator;
				Record.Content        = NStr("en = 'Move to retail'", MainLanguageCode);
				
				
			ElsIf SelectionDetailRecords.CorrGLAccount = Enums.GLAccountsTypes.OtherExpenses
					OR SelectionDetailRecords.CorrGLAccount = Enums.GLAccountsTypes.Expenses Then
				
				// Movements on the register Income and expenses.
				Record = RecordSetIncomeAndExpenses.Add();
				Record.Period         = SelectionDetailRecords.Period;
				Record.Company        = SelectionDetailRecords.Company;
				Record.StructuralUnit = SelectionDetailRecords.StructuralUnitPayee;
				Record.GLAccount      = SelectionDetailRecords.CorrGLAccount;
				Record.AmountExpense  = SelectionDetailRecords.Amount * Denominator;
				
				If TypeOf(SelectionDetailRecords.SourceDocument) = Type("DocumentRef.InventoryTransfer")
					AND SelectionDetailRecords.CorrGLAccount = Enums.GLAccountsTypes.Expenses Then
					Record.BusinessLine = SelectionDetailRecords.ActivityDirectionWriteOff;
					Record.SalesOrder = SelectionDetailRecords.SalesOrder;
					If Not ValueIsFilled(Record.SalesOrder) Then
						Record.SalesOrder = Undefined;
					EndIf;
				Else
					Record.BusinessLine = Catalogs.LinesOfBusiness.Other;
				EndIf;
				Record.ContentOfAccountingRecord = NStr("en = 'Other expenses'", MainLanguageCode);
				
				// Movements by register AccountingJournalEntries.
				Record = RecordSetAccountingJournalEntries.Add();
				Record.Period         = SelectionDetailRecords.Period;
				Record.Company        = SelectionDetailRecords.Company;
				Record.PlanningPeriod = Catalogs.PlanningPeriods.Actual;
				Record.AccountDr      = SelectionDetailRecords.CorrGLAccount;
				Record.AccountCr      = SelectionDetailRecords.GLAccount;
				Record.Amount         = SelectionDetailRecords.Amount * Denominator;
				Record.Content = NStr("en = 'Other expenses'", MainLanguageCode);
				
			ElsIf TypeOf(SelectionDetailRecords.Ref) = Type("DocumentRef.DebitNote") Then
				
				// Movements on the register Income and expenses.
				Record = RecordSetIncomeAndExpenses.Add();
				Record.Period         = SelectionDetailRecords.Period;
				Record.Company        = SelectionDetailRecords.Company;
				Record.StructuralUnit = SelectionDetailRecords.Department;
				Record.BusinessLine   = SelectionDetailRecords.BusinessLine;
				Record.GLAccount      = SelectionDetailRecords.GLAccountPurchaseReturns;
				Record.AmountExpense  = SelectionDetailRecords.Amount * Denominator;
				Record.ContentOfAccountingRecord = NStr("en = 'Purchase return'", MainLanguageCode);
				
			Else
				
				If ValueIsFilled(SelectionDetailRecords.GLAccount)
					And ValueIsFilled(SelectionDetailRecords.CorrGLAccount) Then
					
					// Movements by register AccountingJournalEntries.
					Record = RecordSetAccountingJournalEntries.Add();
					Record.Period         = SelectionDetailRecords.Period;
					Record.Company        = SelectionDetailRecords.Company;
					Record.PlanningPeriod = Catalogs.PlanningPeriods.Actual;
					Record.AccountDr      = SelectionDetailRecords.CorrGLAccount;
					Record.AccountCr      = SelectionDetailRecords.GLAccount;
					Record.Amount         = SelectionDetailRecords.Amount * Denominator;
					Record.Content = NStr("en = 'Inventory write-off'", MainLanguageCode);
						
				EndIf;
				
			EndIf;
				
		EndDo;
		
		WriteInventoryRegister(Selection.Ref,RecordSetInventory, AdditionalProperties.ForPosting);
		WriteSalesRegister(Selection.Ref, RecordSetSales, AdditionalProperties.ForPosting);
		WriteIncomeAndExpensesRegister(Selection.Ref, RecordSetIncomeAndExpenses, AdditionalProperties.ForPosting);
		WriteAccountingJournalEntriesRegister(Selection.Ref, RecordSetAccountingJournalEntries, AdditionalProperties.ForPosting);
		WritePOSSummaryRegister(Selection.Ref, RecordSetPOSSummary, AdditionalProperties.ForPosting);
		
	EndDo;
	
EndProcedure

Procedure WriteOfLandedCostsFromSoldOutProducts()
	
	DateEnd = AdditionalProperties.ForPosting.EndDatePeriod;
	Company = AdditionalProperties.ForPosting.Company;
	
	Query = New Query("
	|SELECT
	|	Balance.Company AS Company,
	|	Balance.StructuralUnit AS StructuralUnit,
	|	Balance.GLAccount AS GLAccount,
	|	Balance.CostLayer AS CostLayer,
	|	Balance.Products AS Products,
	|	Balance.Characteristic AS Characteristic,
	|	Balance.Batch AS Batch,
	|	Balance.SalesOrder AS SalesOrder
	|INTO CostLayerBalance
	|FROM
	|	AccumulationRegister.InventoryCostLayer.Balance(&Period, Company = &Company) AS Balance
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	&EndOfMonth AS Period,
	|	Balance.Company AS Company,
	|	Balance.StructuralUnit AS StructuralUnit,
	|	Balance.GLAccount AS GLAccount,
	|	Balance.CostLayer AS CostLayer,
	|	Balance.Products AS Products,
	|	Balance.Characteristic AS Characteristic,
	|	Balance.Batch AS Batch,
	|	Balance.SalesOrder AS SalesOrder,
	|	Balance.AmountBalance AS Amount,
	|	CatalogLinesOfBusiness.GLAccountCostOfSales AS GLAccountCostOfSales,
	|	CatalogLinesOfBusiness.Ref AS BusinessLine
	|FROM
	|	AccumulationRegister.LandedCosts.Balance(&Period, Company = &Company) AS Balance
	|		LEFT JOIN CostLayerBalance AS CostLayerBalance
	|		ON Balance.Company = CostLayerBalance.Company
	|			AND Balance.StructuralUnit = CostLayerBalance.StructuralUnit
	|			AND Balance.GLAccount = CostLayerBalance.GLAccount
	|			AND Balance.CostLayer = CostLayerBalance.CostLayer
	|			AND Balance.Products = CostLayerBalance.Products
	|			AND Balance.Characteristic = CostLayerBalance.Characteristic
	|			AND Balance.Batch = CostLayerBalance.Batch
	|			AND Balance.SalesOrder = CostLayerBalance.SalesOrder
	|		INNER JOIN Catalog.Products AS CatalogProducts
	|		ON Balance.Products = CatalogProducts.Ref
	|		INNER JOIN Catalog.LinesOfBusiness AS CatalogLinesOfBusiness
	|		ON (CatalogProducts.BusinessLine = CatalogLinesOfBusiness.Ref)
	|WHERE
	|	CostLayerBalance.Company IS NULL
	|");
	
	EndOfMonth = EndOfMonth(DateEnd);
	Query.SetParameter("EndOfMonth", EndOfMonth);
	Query.SetParameter("Period", New Boundary(EndOfMonth, BoundaryType.Including));
	Query.SetParameter("Company", Company);
	
	Result = Query.Execute();
	Selection = Result.Select();
	
	RecordSetLandedCosts = AccumulationRegisters.LandedCosts.CreateRecordSet();
	RecordSetLandedCosts.Filter.Recorder.Set(Ref);
	
	RecordSetAccountingJournalEntries = AccountingRegisters.AccountingJournalEntries.CreateRecordSet();
	RecordSetAccountingJournalEntries.Filter.Recorder.Set(Ref);
	
	RecordSetIncomeAndExpenses = AccumulationRegisters.IncomeAndExpenses.CreateRecordSet();
	RecordSetIncomeAndExpenses.Filter.Recorder.Set(Ref);
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();
	
	While Selection.Next() Do
		
		LandedCostsRecord = RecordSetLandedCosts.Add();
		FillPropertyValues(LandedCostsRecord, Selection);
		
		Record = RecordSetAccountingJournalEntries.Add();
		Record.Period         = EndOfMonth;
		Record.Company        = Selection.Company;
		Record.PlanningPeriod = Catalogs.PlanningPeriods.Actual;
		Record.AccountDr      = Selection.GLAccountCostOfSales;
		Record.AccountCr      = Selection.GLAccount;
		Record.Amount         = Selection.Amount;
		Record.Content        = NStr("en = 'Landed costs allocated'", MainLanguageCode);
		
		IncomeAndExpensesRecord = RecordSetIncomeAndExpenses.Add();
		FillPropertyValues(IncomeAndExpensesRecord, Selection);
		IncomeAndExpensesRecord.GLAccount = Selection.GLAccountCostOfSales;
		IncomeAndExpensesRecord.AmountExpense = Selection.Amount;
		If Not ValueIsFilled(IncomeAndExpensesRecord.SalesOrder) Then
			IncomeAndExpensesRecord.SalesOrder = Undefined;
		EndIf;
		
	EndDo;
	
	RecordSetLandedCosts.Write(True);
	RecordSetIncomeAndExpenses.Write(False);
	RecordSetAccountingJournalEntries.Write(False);
	
EndProcedure

Procedure WriteCorrectiveRecordsInInventory()
	
	Query = New Query(
	"SELECT
	|	Inventory.Company AS Company,
	|	Inventory.StructuralUnit AS StructuralUnit,
	|	Inventory.GLAccount AS GLAccount,
	|	Inventory.Products AS Products,
	|	Inventory.Characteristic AS Characteristic,
	|	Inventory.Batch AS Batch,
	|	Inventory.SalesOrder AS SalesOrder,
	|	Inventory.QuantityBalance AS Quantity,
	|	Inventory.AmountBalance AS Amount
	|INTO InventoryCostLayerBalance
	|FROM
	|	AccumulationRegister.InventoryCostLayer.Balance(&AtBoundary, Company = &Company ) AS Inventory
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	Filter.Company AS Company,
	|	Filter.StructuralUnit AS StructuralUnit,
	|	Filter.GLAccount AS GLAccount,
	|	Filter.Products AS Products,
	|	Filter.Characteristic AS Characteristic,
	|	Filter.Batch AS Batch,
	|	Filter.SalesOrder AS SalesOrder
	|INTO BalanceFilter
	|FROM
	|	InventoryCostLayerBalance AS Filter
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	&BeginOfMonth AS Period,
	|	InventoryCostLayer.Company AS Company,
	|	InventoryCostLayer.StructuralUnit AS StructuralUnit,
	|	InventoryCostLayer.GLAccount AS GLAccount,
	|	InventoryCostLayer.Products AS Products,
	|	InventoryCostLayer.Characteristic AS Characteristic,
	|	InventoryCostLayer.Batch AS Batch,
	|	InventoryCostLayer.SalesOrder AS SalesOrder,
	|	0 AS Quantity,
	|	InventoryCostLayer.AmountBalance AS Amount
	|FROM
	|	AccumulationRegister.Inventory.Balance(
	|			&AtBoundary,
	|			(Company, StructuralUnit, GLAccount, Products, Characteristic, Batch, SalesOrder) IN
	|				(SELECT
	|					Filter.Company AS Company,
	|					Filter.StructuralUnit AS StructuralUnit,
	|					Filter.GLAccount AS GLAccount,
	|					Filter.Products AS Products,
	|					Filter.Characteristic AS Characteristic,
	|					Filter.Batch AS Batch,
	|					Filter.SalesOrder AS SalesOrder
	|				FROM
	|					BalanceFilter AS Filter)) AS InventoryCostLayer
	|
	|UNION ALL
	|
	|SELECT
	|	VALUE(AccumulationRecordType.Receipt),
	|	&BeginOfMonth,
	|	Inventory.Company,
	|	Inventory.StructuralUnit,
	|	Inventory.GLAccount,
	|	Inventory.Products,
	|	Inventory.Characteristic,
	|	Inventory.Batch,
	|	Inventory.SalesOrder,
	|	0,
	|	Inventory.Amount
	|FROM
	|	InventoryCostLayerBalance AS Inventory");
	
	BeginOfMonth = BegOfMonth(Date);
	Query.SetParameter("BeginOfMonth", BeginOfMonth);
	Query.SetParameter("AtBoundary", New Boundary(BeginOfMonth, BoundaryType.Excluding));
	Query.SetParameter("Company", AdditionalProperties.ForPosting.Company);
	
	Result = Query.Execute();
	
	RecordSetInventory = AccumulationRegisters.Inventory.CreateRecordSet();
	RecordSetInventory.Filter.Recorder.Set(Ref);
	RecordSetInventory.Load(Result.Unload());
	
	WriteRegisterRecords(RecordSetInventory, True);
	
EndProcedure

Procedure WriteInventoryRegister(Ref, InventoryRecords, WriteParameters)
	
	Query = New Query(
	"SELECT
	|	Inventory.RecordType AS RecordType,
	|	Inventory.Period AS Period,
	|	Inventory.Company AS Company,
	|	Inventory.StructuralUnit AS StructuralUnit,
	|	Inventory.GLAccount AS GLAccount,
	|	Inventory.Products AS Products,
	|	Inventory.Characteristic AS Characteristic,
	|	Inventory.Batch AS Batch,
	|	Inventory.SalesOrder AS SalesOrder,
	|	Inventory.Quantity AS Quantity,
	|	Inventory.Amount AS Amount,
	|	Inventory.StructuralUnitCorr AS StructuralUnitCorr,
	|	Inventory.CorrGLAccount AS CorrGLAccount,
	|	Inventory.ProductsCorr AS ProductsCorr,
	|	Inventory.CharacteristicCorr AS CharacteristicCorr,
	|	Inventory.BatchCorr AS BatchCorr,
	|	Inventory.CustomerCorrOrder AS CustomerCorrOrder,
	|	Inventory.Specification AS Specification,
	|	Inventory.SpecificationCorr AS SpecificationCorr,
	|	Inventory.CorrSalesOrder AS CorrSalesOrder,
	|	Inventory.SourceDocument AS SourceDocument,
	|	Inventory.Department AS Department,
	|	Inventory.Responsible AS Responsible,
	|	Inventory.VATRate AS VATRate,
	|	Inventory.FixedCost AS FixedCost,
	|	Inventory.ProductionExpenses AS ProductionExpenses,
	|	Inventory.Return AS Return,
	|	Inventory.ContentOfAccountingRecord AS ContentOfAccountingRecord,
	|	Inventory.RetailTransferEarningAccounting AS RetailTransferEarningAccounting,
	|	TRUE AS OfflineRecord
	|INTO NewRecords
	|FROM
	|	&RegisterRecords AS Inventory
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	OnlineRecords.RecordType AS RecordType,
	|	OnlineRecords.Period AS Period,
	|	OnlineRecords.Company AS Company,
	|	OnlineRecords.StructuralUnit AS StructuralUnit,
	|	OnlineRecords.GLAccount AS GLAccount,
	|	OnlineRecords.Products AS Products,
	|	OnlineRecords.Characteristic AS Characteristic,
	|	OnlineRecords.Batch AS Batch,
	|	OnlineRecords.SalesOrder AS SalesOrder,
	|	OnlineRecords.Quantity AS Quantity,
	|	OnlineRecords.Amount AS Amount,
	|	OnlineRecords.StructuralUnitCorr AS StructuralUnitCorr,
	|	OnlineRecords.CorrGLAccount AS CorrGLAccount,
	|	OnlineRecords.ProductsCorr AS ProductsCorr,
	|	OnlineRecords.CharacteristicCorr AS CharacteristicCorr,
	|	OnlineRecords.BatchCorr AS BatchCorr,
	|	OnlineRecords.CustomerCorrOrder AS CustomerCorrOrder,
	|	OnlineRecords.Specification AS Specification,
	|	OnlineRecords.SpecificationCorr AS SpecificationCorr,
	|	OnlineRecords.CorrSalesOrder AS CorrSalesOrder,
	|	OnlineRecords.SourceDocument AS SourceDocument,
	|	OnlineRecords.Department AS Department,
	|	OnlineRecords.Responsible AS Responsible,
	|	OnlineRecords.VATRate AS VATRate,
	|	OnlineRecords.FixedCost AS FixedCost,
	|	OnlineRecords.ProductionExpenses AS ProductionExpenses,
	|	OnlineRecords.Return AS Return,
	|	OnlineRecords.ContentOfAccountingRecord AS ContentOfAccountingRecord,
	|	OnlineRecords.RetailTransferEarningAccounting AS RetailTransferEarningAccounting,
	|	OnlineRecords.OfflineRecord AS OfflineRecord
	|FROM
	|	AccumulationRegister.Inventory AS OnlineRecords
	|WHERE
	|	OnlineRecords.Recorder = &Ref
	|	AND OnlineRecords.Period BETWEEN &DateBeg AND &DateEnd
	|	AND OnlineRecords.Company = &Company
	|	AND NOT OnlineRecords.OfflineRecord
	|
	|UNION ALL
	|
	|SELECT
	|	OfflineRecords.RecordType,
	|	OfflineRecords.Period,
	|	OfflineRecords.Company,
	|	OfflineRecords.StructuralUnit,
	|	OfflineRecords.GLAccount,
	|	OfflineRecords.Products,
	|	OfflineRecords.Characteristic,
	|	OfflineRecords.Batch,
	|	OfflineRecords.SalesOrder,
	|	OfflineRecords.Quantity,
	|	OfflineRecords.Amount,
	|	OfflineRecords.StructuralUnitCorr,
	|	OfflineRecords.CorrGLAccount,
	|	OfflineRecords.ProductsCorr,
	|	OfflineRecords.CharacteristicCorr,
	|	OfflineRecords.BatchCorr,
	|	OfflineRecords.CustomerCorrOrder,
	|	OfflineRecords.Specification,
	|	OfflineRecords.SpecificationCorr,
	|	OfflineRecords.CorrSalesOrder,
	|	OfflineRecords.SourceDocument,
	|	OfflineRecords.Department,
	|	OfflineRecords.Responsible,
	|	OfflineRecords.VATRate,
	|	OfflineRecords.FixedCost,
	|	OfflineRecords.ProductionExpenses,
	|	OfflineRecords.Return,
	|	OfflineRecords.ContentOfAccountingRecord,
	|	OfflineRecords.RetailTransferEarningAccounting,
	|	OfflineRecords.OfflineRecord
	|FROM
	|	NewRecords AS OfflineRecords");
	
	Query.SetParameter("RegisterRecords", InventoryRecords);
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("DateBeg", WriteParameters.BeginOfPeriodningDate);
	Query.SetParameter("DateEnd", WriteParameters.EndDatePeriod);
	Query.SetParameter("Company", WriteParameters.Company);
	
	Query.TempTablesManager = New TempTablesManager;
	
	Result = Query.Execute();
	
	If Not Result.IsEmpty() Then
		InventoryRecords.Load(Result.Unload());
		InventoryRecords.Write();
	EndIf;
	
EndProcedure

Procedure WriteSalesRegister(Ref, SalesRecords, WriteParameters)
	
	Query = New Query(
	"SELECT
	|	Sales.Period AS Period,
	|	Sales.Products AS Products,
	|	Sales.Characteristic AS Characteristic,
	|	Sales.Batch AS Batch,
	|	Sales.Document AS Document,
	|	Sales.VATRate AS VATRate,
	|	Sales.Company AS Company,
	|	Sales.SalesOrder AS SalesOrder,
	|	Sales.Department AS Department,
	|	Sales.Responsible AS Responsible,
	|	Sales.Quantity AS Quantity,
	|	Sales.Amount AS Amount,
	|	Sales.VATAmount AS VATAmount,
	|	Sales.Cost AS Cost,
	|	True AS OfflineRecord
	|INTO NewRecords
	|FROM
	|	&RegisterRecords AS Sales
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	OnlineRecords.Period AS Period,
	|	OnlineRecords.Products AS Products,
	|	OnlineRecords.Characteristic AS Characteristic,
	|	OnlineRecords.Batch AS Batch,
	|	OnlineRecords.Document AS Document,
	|	OnlineRecords.VATRate AS VATRate,
	|	OnlineRecords.Company AS Company,
	|	OnlineRecords.SalesOrder AS SalesOrder,
	|	OnlineRecords.Department AS Department,
	|	OnlineRecords.Responsible AS Responsible,
	|	OnlineRecords.Quantity AS Quantity,
	|	OnlineRecords.Amount AS Amount,
	|	OnlineRecords.VATAmount AS VATAmount,
	|	OnlineRecords.Cost AS Cost,
	|	OnlineRecords.OfflineRecord AS OfflineRecord
	|FROM
	|	AccumulationRegister.Sales AS OnlineRecords
	|WHERE
	|	OnlineRecords.Recorder = &Ref
	|	AND OnlineRecords.Period BETWEEN &DateBeg AND &DateEnd
	|	AND OnlineRecords.Company = &Company
	|	AND NOT OnlineRecords.OfflineRecord
	|
	|UNION ALL
	|
	|SELECT
	|	OfflineRecords.Period,
	|	OfflineRecords.Products,
	|	OfflineRecords.Characteristic,
	|	OfflineRecords.Batch,
	|	OfflineRecords.Document,
	|	OfflineRecords.VATRate,
	|	OfflineRecords.Company,
	|	OfflineRecords.SalesOrder,
	|	OfflineRecords.Department,
	|	OfflineRecords.Responsible,
	|	OfflineRecords.Quantity,
	|	OfflineRecords.Amount,
	|	OfflineRecords.VATAmount,
	|	OfflineRecords.Cost,
	|	OfflineRecords.OfflineRecord
	|FROM
	|	NewRecords AS OfflineRecords");
	
	Query.SetParameter("RegisterRecords", SalesRecords);
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("DateBeg", WriteParameters.BeginOfPeriodningDate);
	Query.SetParameter("DateEnd", WriteParameters.EndDatePeriod);
	Query.SetParameter("Company", WriteParameters.Company);
	
	Query.TempTablesManager = New TempTablesManager;
	
	Result = Query.Execute();
	
	If Not Result.IsEmpty() Then
		SalesRecords.Load(Result.Unload());
		SalesRecords.Write();
	EndIf;
	
EndProcedure

Procedure WriteIncomeAndExpensesRegister(Ref, IncomeAndExpensesRecords, WriteParameters)
	
	Query = New Query(
	"SELECT
	|	NewRecords.Period AS Period,
	|	NewRecords.Company AS Company,
	|	NewRecords.StructuralUnit AS StructuralUnit,
	|	NewRecords.BusinessLine AS BusinessLine,
	|	NewRecords.SalesOrder AS SalesOrder,
	|	NewRecords.GLAccount AS GLAccount,
	|	NewRecords.AmountIncome AS AmountIncome,
	|	NewRecords.AmountExpense AS AmountExpense,
	|	NewRecords.ContentOfAccountingRecord AS ContentOfAccountingRecord,
	|	TRUE AS OfflineRecord
	|INTO NewRecords
	|FROM
	|	&RegisterRecords AS NewRecords
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	OnlineRecords.Period AS Period,
	|	OnlineRecords.Company AS Company,
	|	OnlineRecords.StructuralUnit AS StructuralUnit,
	|	OnlineRecords.BusinessLine AS BusinessLine,
	|	OnlineRecords.SalesOrder AS SalesOrder,
	|	OnlineRecords.GLAccount AS GLAccount,
	|	OnlineRecords.AmountIncome AS AmountIncome,
	|	OnlineRecords.AmountExpense AS AmountExpense,
	|	OnlineRecords.ContentOfAccountingRecord AS ContentOfAccountingRecord,
	|	OnlineRecords.OfflineRecord AS OfflineRecord
	|FROM
	|	AccumulationRegister.IncomeAndExpenses AS OnlineRecords
	|WHERE
	|	OnlineRecords.Recorder = &Ref
	|	AND OnlineRecords.Period BETWEEN &DateBeg AND &DateEnd
	|	AND OnlineRecords.Company = &Company
	|	AND NOT OnlineRecords.OfflineRecord
	|
	|UNION ALL
	|
	|SELECT
	|	OfflineRecords.Period,
	|	OfflineRecords.Company,
	|	OfflineRecords.StructuralUnit,
	|	OfflineRecords.BusinessLine,
	|	OfflineRecords.SalesOrder,
	|	OfflineRecords.GLAccount,
	|	OfflineRecords.AmountIncome,
	|	OfflineRecords.AmountExpense,
	|	OfflineRecords.ContentOfAccountingRecord,
	|	OfflineRecords.OfflineRecord
	|FROM
	|	NewRecords AS OfflineRecords");
	
	Query.SetParameter("RegisterRecords", IncomeAndExpensesRecords);
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("DateBeg", WriteParameters.BeginOfPeriodningDate);
	Query.SetParameter("DateEnd", WriteParameters.EndDatePeriod);
	Query.SetParameter("Company", WriteParameters.Company);
	
	Query.TempTablesManager = New TempTablesManager;
	
	Result = Query.Execute();
	
	If Not Result.IsEmpty() Then
		IncomeAndExpensesRecords.Load(Result.Unload());
		IncomeAndExpensesRecords.Write();
	EndIf;
	
EndProcedure

Procedure WriteAccountingJournalEntriesRegister(Ref, AccountingJournalEntriesRecords, WriteParameters)
	
	Query = New Query(
	"SELECT
	|	NewRecords.Period AS Period,
	|	NewRecords.AccountDr AS AccountDr,
	|	NewRecords.AccountCr AS AccountCr,
	|	NewRecords.Company AS Company,
	|	NewRecords.PlanningPeriod AS PlanningPeriod,
	|	NewRecords.CurrencyDr AS CurrencyDr,
	|	NewRecords.CurrencyCr AS CurrencyCr,
	|	NewRecords.Amount AS Amount,
	|	NewRecords.AmountCurDr AS AmountCurDr,
	|	NewRecords.AmountCurCr AS AmountCurCr,
	|	NewRecords.Content AS Content,
	|	TRUE AS OfflineRecord
	|INTO NewRecords
	|FROM
	|	&RegisterRecords AS NewRecords
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	OnlineRecords.Period AS Period,
	|	OnlineRecords.AccountDr AS AccountDr,
	|	OnlineRecords.AccountCr AS AccountCr,
	|	OnlineRecords.Company AS Company,
	|	OnlineRecords.PlanningPeriod AS PlanningPeriod,
	|	OnlineRecords.CurrencyDr AS CurrencyDr,
	|	OnlineRecords.CurrencyCr AS CurrencyCr,
	|	OnlineRecords.Amount AS Amount,
	|	OnlineRecords.AmountCurDr AS AmountCurDr,
	|	OnlineRecords.AmountCurCr AS AmountCurCr,
	|	OnlineRecords.Content AS Content,
	|	OnlineRecords.OfflineRecord AS OfflineRecord
	|FROM
	|	AccountingRegister.AccountingJournalEntries AS OnlineRecords
	|WHERE
	|	OnlineRecords.Recorder = &Ref
	|	AND OnlineRecords.Period BETWEEN &DateBeg AND &DateEnd
	|	AND OnlineRecords.Company = &Company
	|	AND NOT OnlineRecords.OfflineRecord
	|
	|UNION ALL
	|
	|SELECT
	|	OfflineRecords.Period,
	|	OfflineRecords.AccountDr,
	|	OfflineRecords.AccountCr,
	|	OfflineRecords.Company,
	|	OfflineRecords.PlanningPeriod,
	|	OfflineRecords.CurrencyDr,
	|	OfflineRecords.CurrencyCr,
	|	OfflineRecords.Amount,
	|	OfflineRecords.AmountCurDr,
	|	OfflineRecords.AmountCurCr,
	|	OfflineRecords.Content,
	|	OfflineRecords.OfflineRecord
	|FROM
	|	NewRecords AS OfflineRecords");
	
	Query.SetParameter("RegisterRecords", AccountingJournalEntriesRecords);
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("DateBeg", WriteParameters.BeginOfPeriodningDate);
	Query.SetParameter("DateEnd", WriteParameters.EndDatePeriod);
	Query.SetParameter("Company", WriteParameters.Company);
	
	Query.TempTablesManager = New TempTablesManager;
	
	Result = Query.Execute();
	
	If Not Result.IsEmpty() Then
		AccountingJournalEntriesRecords.Load(Result.Unload());
		AccountingJournalEntriesRecords.Write();
	EndIf;
	
EndProcedure

Procedure WritePOSSummaryRegister(Ref, POSSummaryRecords, WriteParameters)
	
	Query = New Query(
	"SELECT
	|	POS.Period AS Period,
	|	POS.Company AS Company,
	|	POS.StructuralUnit AS StructuralUnit,
	|	POS.Currency AS Currency,
	|	POS.Amount AS Amount,
	|	POS.AmountCur AS AmountCur,
	|	POS.Cost AS Cost,
	|	POS.ContentOfAccountingRecord AS ContentOfAccountingRecord,
	|	POS.SalesDocument AS SalesDocument,
	|	TRUE AS OfflineRecord
	|INTO NewRecords
	|FROM
	|	&RegisterRecords AS POS
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	OnlineRecords.Period AS Period,
	|	OnlineRecords.Company AS Company,
	|	OnlineRecords.StructuralUnit AS StructuralUnit,
	|	OnlineRecords.Currency AS Currency,
	|	OnlineRecords.Amount AS Amount,
	|	OnlineRecords.AmountCur AS AmountCur,
	|	OnlineRecords.Cost AS Cost,
	|	OnlineRecords.ContentOfAccountingRecord AS ContentOfAccountingRecord,
	|	OnlineRecords.SalesDocument AS SalesDocument,
	|	OnlineRecords.OfflineRecord AS OfflineRecord
	|FROM
	|	AccumulationRegister.POSSummary AS OnlineRecords
	|WHERE
	|	OnlineRecords.Recorder = &Ref
	|	AND OnlineRecords.Period BETWEEN &DateBeg AND &DateEnd
	|	AND OnlineRecords.Company = &Company
	|	AND NOT OnlineRecords.OfflineRecord
	|
	|UNION ALL
	|
	|SELECT
	|	OfflineRecords.Period,
	|	OfflineRecords.Company,
	|	OfflineRecords.StructuralUnit,
	|	OfflineRecords.Currency,
	|	OfflineRecords.Amount,
	|	OfflineRecords.AmountCur,
	|	OfflineRecords.Cost,
	|	OfflineRecords.ContentOfAccountingRecord,
	|	OfflineRecords.SalesDocument,
	|	OfflineRecords.OfflineRecord
	|FROM
	|	NewRecords AS OfflineRecords");
	
	Query.SetParameter("RegisterRecords", POSSummaryRecords);
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("DateBeg", WriteParameters.BeginOfPeriodningDate);
	Query.SetParameter("DateEnd", WriteParameters.EndDatePeriod);
	Query.SetParameter("Company", WriteParameters.Company);
	
	Query.TempTablesManager = New TempTablesManager;
	
	Result = Query.Execute();
	
	If Not Result.IsEmpty() Then
		POSSummaryRecords.Load(Result.Unload());
		POSSummaryRecords.Write();
	EndIf;
	
EndProcedure

Procedure WriteRegisterRecords(RegisterRecords, Replace = True)
	
	If RegisterRecords.Count() = 0 Then
		Return;
	EndIf;
	
	RegisterRecords.Write(Replace);
	
EndProcedure

// Procedure of hung amounts distribution without quantity (rounding errors while solving SLU).
//
//
Procedure DistributeAmountsWithoutQuantity(OperationKind, ErrorsTable)
	
	ListOfProcessedNodes = New Array();
	ListOfProcessedNodes.Add("");
	
	DateBeg = AdditionalProperties.ForPosting.BeginOfPeriodningDate;
	DateEnd = AdditionalProperties.ForPosting.EndDatePeriod;
	
	Query = New Query();
	Query.TempTablesManager = AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.SetParameter("Company", AdditionalProperties.ForPosting.Company);
	
	// Movements table is being prepared.
	Query.Text =
	"SELECT
	|	CostAccounting.Company AS Company,
	|	CostAccounting.StructuralUnit AS StructuralUnit,
	|	CostAccounting.GLAccount AS GLAccount,
	|	CostAccounting.GLAccount.TypeOfAccount AS GLAccountGLAccountType,
	|	CostAccounting.Products AS Products,
	|	CostAccounting.Characteristic AS Characteristic,
	|	CostAccounting.Batch AS Batch,
	|	CostAccounting.SalesOrder AS SalesOrder,
	|	CostAccounting.StructuralUnitCorr AS StructuralUnitCorr,
	|	CostAccounting.CorrGLAccount AS CorrGLAccount,
	|	CostAccounting.CorrGLAccount.TypeOfAccount AS CorrAccountFinancialAccountType,
	|	CostAccounting.ProductsCorr AS ProductsCorr,
	|	CostAccounting.CharacteristicCorr AS CharacteristicCorr,
	|	CostAccounting.BatchCorr AS BatchCorr,
	|	CostAccounting.CustomerCorrOrder AS CustomerCorrOrder,
	|	CostAccounting.SourceDocument AS SourceDocument,
	|	CostAccounting.CorrSalesOrder AS CorrSalesOrder,
	|	CostAccounting.Department AS Department,
	|	CostAccounting.Responsible AS Responsible,
	|	CostAccounting.VATRate AS VATRate,
	|	CostAccounting.ProductionExpenses AS ProductionExpenses,
	|	CASE
	|		WHEN VALUETYPE(CostAccounting.SourceDocument) = Type(Document.InventoryWriteOff)
	|			THEN CostAccounting.SourceDocument.Correspondence
	|		WHEN VALUETYPE(CostAccounting.SourceDocument) = Type(Document.InventoryTransfer)
	|			THEN CostAccounting.SourceDocument.GLExpenseAccount
	|		ELSE UNDEFINED
	|	END AS GLAccountWriteOff,
	|	CASE
	|		WHEN VALUETYPE(CostAccounting.SourceDocument) = Type(Document.InventoryWriteOff)
	|			THEN CostAccounting.SourceDocument.Correspondence.TypeOfAccount
	|		WHEN VALUETYPE(CostAccounting.SourceDocument) = Type(Document.InventoryTransfer)
	|			THEN CostAccounting.SourceDocument.GLExpenseAccount.TypeOfAccount
	|		ELSE UNDEFINED
	|	END AS GLAccountWriteOffAccountType,
	|	CASE
	|		WHEN VALUETYPE(CostAccounting.SourceDocument) = Type(Document.InventoryTransfer)
	|			THEN CostAccounting.SourceDocument.BusinessLine
	|		ELSE UNDEFINED
	|	END AS ActivityDirectionWriteOff,
	|	CASE
	|		WHEN VALUETYPE(CostAccounting.SourceDocument) = Type(Document.InventoryTransfer)
	|			THEN CostAccounting.SourceDocument.StructuralUnitPayee
	|		ELSE CostAccounting.SourceDocument.StructuralUnit
	|	END AS StructuralUnitPayee,
	|	CASE
	|		WHEN CostAccounting.RetailTransferEarningAccounting
	|			THEN CASE
	|					WHEN VALUETYPE(CostAccounting.SourceDocument) = Type(Document.SupplierInvoice)
	|						THEN CostAccounting.SourceDocument.StructuralUnit
	|					WHEN VALUETYPE(CostAccounting.SourceDocument) = Type(Document.InventoryTransfer)
	|						THEN CostAccounting.SourceDocument.StructuralUnitPayee
	|					ELSE UNDEFINED
	|				END
	|		ELSE UNDEFINED
	|	END AS RetailStructuralUnit,
	|	CostAccounting.RetailTransferEarningAccounting AS RetailTransferEarningAccounting,
	|	CostAccounting.Products.ProductsCategory AS ProductsProductsCategory,
	|	CostAccounting.Products.BusinessLine AS BusinessLineSales,
	|	CostAccounting.Products.BusinessLine.GLAccountCostOfSales AS BusinessLineSalesGLAccountOfSalesCost,
	|	CostAccounting.Products.BusinessLine.GLAccountCostOfSales.TypeOfAccount AS BusinessLineSalesSalesCostGLAccountAccountType,
	|	SUM(CASE
	|			WHEN CostAccounting.RecordType = VALUE(AccumulationRecordType.Expense)
	|						AND Not CostAccounting.Return
	|					OR CostAccounting.RecordType = VALUE(AccumulationRecordType.Receipt)
	|						AND CostAccounting.Return
	|				THEN CostAccounting.Amount
	|			ELSE 0
	|		END) AS Amount
	|INTO CostAccountingExpenseRecordsRegister
	|FROM
	|	AccumulationRegister.Inventory AS CostAccounting
	|WHERE
	|	CostAccounting.Period between &DateBeg AND &DateEnd
	|	AND CostAccounting.Company = &Company
	|	AND Not CostAccounting.FixedCost
	|
	|GROUP BY
	|	CostAccounting.Company,
	|	CostAccounting.StructuralUnit,
	|	CostAccounting.GLAccount,
	|	CostAccounting.Products,
	|	CostAccounting.Characteristic,
	|	CostAccounting.Batch,
	|	CostAccounting.SalesOrder,
	|	CostAccounting.StructuralUnitCorr,
	|	CostAccounting.CorrGLAccount,
	|	CostAccounting.ProductsCorr,
	|	CostAccounting.CharacteristicCorr,
	|	CostAccounting.BatchCorr,
	|	CostAccounting.CustomerCorrOrder,
	|	CostAccounting.SourceDocument,
	|	CostAccounting.CorrSalesOrder,
	|	CostAccounting.Department,
	|	CostAccounting.Responsible,
	|	CostAccounting.VATRate,
	|	CostAccounting.ProductionExpenses,
	|	CASE
	|		WHEN VALUETYPE(CostAccounting.SourceDocument) = Type(Document.InventoryWriteOff)
	|			THEN CostAccounting.SourceDocument.Correspondence
	|		WHEN VALUETYPE(CostAccounting.SourceDocument) = Type(Document.InventoryTransfer)
	|			THEN CostAccounting.SourceDocument.GLExpenseAccount
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN VALUETYPE(CostAccounting.SourceDocument) = Type(Document.InventoryWriteOff)
	|			THEN CostAccounting.SourceDocument.Correspondence.TypeOfAccount
	|		WHEN VALUETYPE(CostAccounting.SourceDocument) = Type(Document.InventoryTransfer)
	|			THEN CostAccounting.SourceDocument.GLExpenseAccount.TypeOfAccount
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN VALUETYPE(CostAccounting.SourceDocument) = Type(Document.InventoryTransfer)
	|			THEN CostAccounting.SourceDocument.BusinessLine
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN VALUETYPE(CostAccounting.SourceDocument) = Type(Document.InventoryTransfer)
	|			THEN CostAccounting.SourceDocument.StructuralUnitPayee
	|		ELSE CostAccounting.SourceDocument.StructuralUnit
	|	END,
	|	CASE
	|		WHEN CostAccounting.RetailTransferEarningAccounting
	|			THEN CASE
	|					WHEN VALUETYPE(CostAccounting.SourceDocument) = Type(Document.SupplierInvoice)
	|						THEN CostAccounting.SourceDocument.StructuralUnit
	|					WHEN VALUETYPE(CostAccounting.SourceDocument) = Type(Document.InventoryTransfer)
	|						THEN CostAccounting.SourceDocument.StructuralUnitPayee
	|					ELSE UNDEFINED
	|				END
	|		ELSE UNDEFINED
	|	END,
	|	CostAccounting.RetailTransferEarningAccounting,
	|	CostAccounting.Products.ProductsCategory,
	|	CostAccounting.Products.BusinessLine,
	|	CostAccounting.Products.BusinessLine.GLAccountCostOfSales,
	|	CostAccounting.Products.BusinessLine.GLAccountCostOfSales.TypeOfAccount,
	|	CostAccounting.GLAccount.TypeOfAccount,
	|	CostAccounting.CorrGLAccount.TypeOfAccount
	|
	|INDEX BY
	|	StructuralUnit,
	|	GLAccount,
	|	Products,
	|	Characteristic,
	|	Batch,
	|	SalesOrder,
	|	StructuralUnitCorr,
	|	CorrGLAccount,
	|	ProductsCorr,
	|	CharacteristicCorr,
	|	BatchCorr,
	|	CustomerCorrOrder";
	
	Query.SetParameter("DateBeg", DateBeg);
	Query.SetParameter("DateEnd", DateEnd);
	
	Query.Execute();
	
	// Writeoff directions of all amounts less than a ruble are
	// determined for nodes by which there is balance by amounts and without quantity.
	Query.Text =
	"SELECT DISTINCT
	|	""DistributeAmountsWithoutQuantity"" AS Field1,
	|	AccountingCostBalance.Company AS Company,
	|	AccountingCostBalance.StructuralUnit AS StructuralUnit,
	|	AccountingCostBalance.GLAccount AS GLAccount,
	|	AccountingCostBalance.GLAccount.TypeOfAccount AS GLAccountGLAccountType,
	|	AccountingCostBalance.Products AS Products,
	|	AccountingCostBalance.Characteristic AS Characteristic,
	|	AccountingCostBalance.Batch AS Batch,
	|	AccountingCostBalance.SalesOrder AS SalesOrder,
	|	CASE
	|		WHEN AccountingCostBalance.QuantityBalance = 0
	|				AND NestedSelect.Amount <> 0
	|				AND (AccountingCostBalance.AmountBalance between -1 AND 1
	|					OR AccountingCostBalance.Products <> VALUE(Catalog.Products.EmptyRef))
	|			THEN AccountingCostBalance.AmountBalance
	|		ELSE 0
	|	END AS Amount,
	|	NestedSelect.StructuralUnitCorr AS StructuralUnitCorr,
	|	UNDEFINED AS Specification,
	|	UNDEFINED AS SpecificationCorr,
	|	NestedSelect.CorrGLAccount AS CorrGLAccount,
	|	NestedSelect.CorrAccountFinancialAccountType AS CorrAccountFinancialAccountType,
	|	NestedSelect.ProductsCorr AS ProductsCorr,
	|	NestedSelect.CharacteristicCorr AS CharacteristicCorr,
	|	NestedSelect.BatchCorr AS BatchCorr,
	|	NestedSelect.CustomerCorrOrder AS CustomerCorrOrder,
	|	NestedSelect.SourceDocument AS SourceDocument,
	|	NestedSelect.CorrSalesOrder AS CorrSalesOrder,
	|	NestedSelect.Department AS Department,
	|	NestedSelect.Responsible AS Responsible,
	|	NestedSelect.VATRate AS VATRate,
	|	NestedSelect.ProductionExpenses AS ProductionExpenses,
	|	NestedSelect.ProductsProductsCategory AS ProductsProductsCategory,
	|	NestedSelect.BusinessLineSales AS BusinessLineSales,
	|	NestedSelect.ActivityDirectionWriteOff AS ActivityDirectionWriteOff,
	|	NestedSelect.BusinessLineSalesGLAccountOfSalesCost AS BusinessLineSalesGLAccountOfSalesCost,
	|	NestedSelect.BusinessLineSalesSalesCostGLAccountAccountType AS BusinessLineSalesSalesCostGLAccountAccountType,
	|	WriteOffCostAdjustment.NodeNo AS NodeNo,
	|	CostAdjustmentsNodesWriteOffSource.NodeNo AS NumberNodeSource,
	|	NestedSelect.GLAccountWriteOff AS GLAccountWriteOff,
	|	NestedSelect.GLAccountWriteOffAccountType AS GLAccountWriteOffAccountType,
	|	NestedSelect.StructuralUnitPayee AS StructuralUnitPayee,
	|	NestedSelect.RetailTransferEarningAccounting AS RetailTransferEarningAccounting,
	|	NestedSelect.RetailStructuralUnit AS RetailStructuralUnit,
	|	AccountingCostBalanceCorr.QuantityBalance AS QuantityBalance
	|FROM
	|	AccumulationRegister.Inventory.Balance(&BoundaryDateEnd, Company = &Company) AS AccountingCostBalance
	|		LEFT JOIN CostAccountingExpenseRecordsRegister AS NestedSelect
	|			LEFT JOIN AccumulationRegister.Inventory.Balance(&BoundaryDateEnd, ) AS AccountingCostBalanceCorr
	|			ON NestedSelect.Company = AccountingCostBalanceCorr.Company
	|				AND NestedSelect.StructuralUnitCorr = AccountingCostBalanceCorr.StructuralUnit
	|				AND NestedSelect.CorrGLAccount = AccountingCostBalanceCorr.GLAccount
	|				AND NestedSelect.ProductsCorr = AccountingCostBalanceCorr.Products
	|				AND NestedSelect.CharacteristicCorr = AccountingCostBalanceCorr.Characteristic
	|				AND NestedSelect.BatchCorr = AccountingCostBalanceCorr.Batch
	|				AND NestedSelect.CustomerCorrOrder = AccountingCostBalanceCorr.SalesOrder
	|			LEFT JOIN InformationRegister.WriteOffCostAdjustment AS WriteOffCostAdjustment
	|			ON NestedSelect.Company = WriteOffCostAdjustment.Company
	|				AND NestedSelect.StructuralUnitCorr = WriteOffCostAdjustment.StructuralUnit
	|				AND NestedSelect.CorrGLAccount = WriteOffCostAdjustment.GLAccount
	|				AND NestedSelect.ProductsCorr = WriteOffCostAdjustment.Products
	|				AND NestedSelect.CharacteristicCorr = WriteOffCostAdjustment.Characteristic
	|				AND NestedSelect.BatchCorr = WriteOffCostAdjustment.Batch
	|				AND NestedSelect.CustomerCorrOrder = WriteOffCostAdjustment.SalesOrder
	|				AND (WriteOffCostAdjustment.Recorder = &Recorder)
	|		ON AccountingCostBalance.Company = NestedSelect.Company
	|			AND AccountingCostBalance.StructuralUnit = NestedSelect.StructuralUnit
	|			AND AccountingCostBalance.GLAccount = NestedSelect.GLAccount
	|			AND AccountingCostBalance.Products = NestedSelect.Products
	|			AND AccountingCostBalance.Characteristic = NestedSelect.Characteristic
	|			AND AccountingCostBalance.Batch = NestedSelect.Batch
	|			AND AccountingCostBalance.SalesOrder = NestedSelect.SalesOrder
	|		LEFT JOIN InformationRegister.WriteOffCostAdjustment AS CostAdjustmentsNodesWriteOffSource
	|		ON (CostAdjustmentsNodesWriteOffSource.Recorder = &Recorder)
	|			AND AccountingCostBalance.Company = CostAdjustmentsNodesWriteOffSource.Company
	|			AND AccountingCostBalance.StructuralUnit = CostAdjustmentsNodesWriteOffSource.StructuralUnit
	|			AND AccountingCostBalance.GLAccount = CostAdjustmentsNodesWriteOffSource.GLAccount
	|			AND AccountingCostBalance.Products = CostAdjustmentsNodesWriteOffSource.Products
	|			AND AccountingCostBalance.Characteristic = CostAdjustmentsNodesWriteOffSource.Characteristic
	|			AND AccountingCostBalance.Batch = CostAdjustmentsNodesWriteOffSource.Batch
	|			AND AccountingCostBalance.SalesOrder = CostAdjustmentsNodesWriteOffSource.SalesOrder
	|WHERE
	|	AccountingCostBalance.AmountBalance <> 0
	|	AND AccountingCostBalance.QuantityBalance = 0
	|	AND NestedSelect.Amount <> 0
	|	AND (AccountingCostBalance.AmountBalance between -1 AND 1
	|			OR AccountingCostBalance.Products <> VALUE(Catalog.Products.EmptyRef))
	|	AND AccountingCostBalance.AmountBalance <> 0
	|	AND Not NestedSelect.GLAccount IS NULL 
	|	AND Not ISNULL(CostAdjustmentsNodesWriteOffSource.NodeNo, 0) = ISNULL(WriteOffCostAdjustment.NodeNo, 0)
	|
	|ORDER BY
	|	QuantityBalance DESC,
	|	CASE
	|		WHEN WriteOffCostAdjustment.NodeNo IN (&ListOfProcessedNodes)
	|			THEN 0
	|		ELSE 1
	|	END DESC";
	
	Query.SetParameter("BoundaryDateEnd", New Boundary(DateEnd, BoundaryType.Including));
	Query.SetParameter("Recorder", Ref);
	Query.SetParameter("ListOfProcessedNodes", ListOfProcessedNodes);
	
	RecordSetInventory = AccumulationRegisters.Inventory.CreateRecordSet();
	RecordSetInventory.Filter.Recorder.Set(Ref);
	
	RecordSetSales = AccumulationRegisters.Sales.CreateRecordSet();
	RecordSetSales.Filter.Recorder.Set(Ref);
	
	RecordSetIncomeAndExpenses = AccumulationRegisters.IncomeAndExpenses.CreateRecordSet();
	RecordSetIncomeAndExpenses.Filter.Recorder.Set(Ref);
	
	RecordSetPOSSummary = AccumulationRegisters.POSSummary.CreateRecordSet();
	RecordSetPOSSummary.Filter.Recorder.Set(Ref);
	
	RecordSetAccountingJournalEntries = AccountingRegisters.AccountingJournalEntries.CreateRecordSet();
	RecordSetAccountingJournalEntries.Filter.Recorder.Set(Ref);
	
	IterationsQuantity = 0;
	
	Result = Query.Execute();
	
	While Not Result.IsEmpty() Do
		
		IterationsQuantity = IterationsQuantity + 1;
		If IterationsQuantity > 60 Then
			ErrorDescription = NStr("en = 'Cannot adjust cost balance values.'");
			AddErrorIntoTable(ErrorDescription, OperationKind, ErrorsTable);
			Break;
		EndIf;
		
		RecordSetInventory.Clear();
		RecordSetSales.Clear();
		RecordSetIncomeAndExpenses.Clear();
		RecordSetPOSSummary.Clear();
		RecordSetAccountingJournalEntries.Clear();
		
		SelectionDetailRecords = Result.Select();
		ListOfNodesProcessedSources = New Array();
		
		While SelectionDetailRecords.Next() Do
			
			If ListOfNodesProcessedSources.Find(SelectionDetailRecords.NumberNodeSource) = Undefined Then
				ListOfNodesProcessedSources.Add(SelectionDetailRecords.NumberNodeSource);
			Else
				Continue; // This source is already corrected.
			EndIf;
			
			If ListOfProcessedNodes.Find(SelectionDetailRecords.NodeNo) = Undefined Then
				ListOfProcessedNodes.Add(SelectionDetailRecords.NodeNo);
			EndIf;
			
			CorrectionAmount = SelectionDetailRecords.Amount;
			
			GenerateRegisterRecordsByExpensesRegister(
				RecordSetInventory,
				RecordSetAccountingJournalEntries,
				SelectionDetailRecords,
				CorrectionAmount,
				False,
			);
			
			If SelectionDetailRecords.CorrGLAccount = AdditionalProperties.ForPosting.EmptyAccount Then
				
				If ValueIsFilled(SelectionDetailRecords.SourceDocument)
					AND (TypeOf(SelectionDetailRecords.SourceDocument) = Type("DocumentRef.SalesInvoice")
						OR TypeOf(SelectionDetailRecords.SourceDocument) = Type("DocumentRef.ShiftClosure")
						OR TypeOf(SelectionDetailRecords.SourceDocument) = Type("DocumentRef.AccountSalesFromConsignee")
						OR TypeOf(SelectionDetailRecords.SourceDocument) = Type("DocumentRef.SalesOrder")
						OR TypeOf(SelectionDetailRecords.SourceDocument) = Type("DocumentRef.SubcontractorReportIssued")) Then
					
					// Movements on the register Sales.
					NewRow = RecordSetSales.Add();
					NewRow.Period				= Date;
					NewRow.Recorder				= Ref;
					NewRow.Company				= SelectionDetailRecords.Company;
					NewRow.SalesOrder			= SelectionDetailRecords.CorrSalesOrder;
					NewRow.Department			= SelectionDetailRecords.Department;
					NewRow.Responsible			= SelectionDetailRecords.Responsible;
					NewRow.Products	= SelectionDetailRecords.Products;
					NewRow.Characteristic		= SelectionDetailRecords.Characteristic;
					NewRow.Batch				= SelectionDetailRecords.Batch;
					NewRow.Document				= SelectionDetailRecords.SourceDocument;
					NewRow.VATRate				= SelectionDetailRecords.VATRate;
					NewRow.Cost					= CorrectionAmount;
					
					// Movements on the register IncomeAndExpenses.
					NewRow = RecordSetIncomeAndExpenses.Add();
					NewRow.Period						= Date;
					NewRow.Recorder						= Ref;
					NewRow.Company						= SelectionDetailRecords.Company;
					NewRow.StructuralUnit				= SelectionDetailRecords.Department;
					NewRow.SalesOrder					= SelectionDetailRecords.CorrSalesOrder;
					If Not ValueIsFilled(NewRow.SalesOrder) Then
						NewRow.SalesOrder = Undefined;
					EndIf;
					NewRow.BusinessLine				= SelectionDetailRecords.BusinessLineSales;
					NewRow.GLAccount					= SelectionDetailRecords.BusinessLineSalesGLAccountOfSalesCost;
					NewRow.AmountExpense				= CorrectionAmount;
					NewRow.ContentOfAccountingRecord	= NStr("en = 'Record sale expenses'");
					
					// Movements by register AccountingJournalEntries.
					NewRow = RecordSetAccountingJournalEntries.Add();
					NewRow.Period			= Date;
					NewRow.Recorder			= Ref;
					NewRow.Company			= SelectionDetailRecords.Company;
					NewRow.PlanningPeriod	= Catalogs.PlanningPeriods.Actual;
					NewRow.AccountDr		= SelectionDetailRecords.BusinessLineSalesGLAccountOfSalesCost;
					NewRow.AccountCr		= SelectionDetailRecords.GLAccount;
					NewRow.Content			= NStr("en = 'Record sale expenses'");
					NewRow.Amount			= CorrectionAmount;
					
				ElsIf SelectionDetailRecords.RetailTransferEarningAccounting Then
					
					// Movements on the register POSSummary.
					NewRow = RecordSetPOSSummary.Add();
					NewRow.Period = Date;
					NewRow.RecordType = AccumulationRecordType.Receipt;
					NewRow.Recorder = Ref;
					NewRow.Company = SelectionDetailRecords.Company;
					NewRow.StructuralUnit = SelectionDetailRecords.RetailStructuralUnit;
					NewRow.Currency = SelectionDetailRecords.RetailStructuralUnit.RetailPriceKind.PriceCurrency;
					NewRow.ContentOfAccountingRecord = NStr("en = 'Move to retail'");
					NewRow.Cost = CorrectionAmount;
					
					// Movements by register AccountingJournalEntries.
					NewRow = RecordSetAccountingJournalEntries.Add();
					NewRow.Period = Date;
					NewRow.Recorder = Ref;
					NewRow.Company = SelectionDetailRecords.Company;
					NewRow.PlanningPeriod = Catalogs.PlanningPeriods.Actual;
					NewRow.AccountDr = SelectionDetailRecords.RetailStructuralUnit.GLAccountInRetail;
					NewRow.AccountCr = SelectionDetailRecords.GLAccount;
					NewRow.Content = NStr("en = 'Move to retail'");
					NewRow.Amount = CorrectionAmount; 
					
				ElsIf SelectionDetailRecords.GLAccountWriteOffAccountType = Enums.GLAccountsTypes.OtherExpenses
					  OR SelectionDetailRecords.GLAccountWriteOffAccountType = Enums.GLAccountsTypes.Expenses Then
					
					// Movements on the register Income and expenses.
					NewRow = RecordSetIncomeAndExpenses.Add();
					NewRow.Period = AdditionalProperties.ForPosting.Date;
					NewRow.Recorder = Ref;
					NewRow.Company = SelectionDetailRecords.Company;
					NewRow.StructuralUnit = SelectionDetailRecords.StructuralUnitPayee;
					
					If TypeOf(SelectionDetailRecords.SourceDocument) = Type("DocumentRef.InventoryTransfer")
					   AND SelectionDetailRecords.GLAccountWriteOffAccountType = Enums.GLAccountsTypes.Expenses Then
						NewRow.BusinessLine = SelectionDetailRecords.ActivityDirectionWriteOff;
						NewRow.SalesOrder = SelectionDetailRecords.SalesOrder;
						If Not ValueIsFilled(NewRow.SalesOrder) Then
							NewRow.SalesOrder = Undefined;
						EndIf;
					Else
						NewRow.BusinessLine = Catalogs.LinesOfBusiness.Other;
					EndIf;
					
					NewRow.GLAccount = SelectionDetailRecords.GLAccountWriteOff;
					NewRow.AmountExpense = CorrectionAmount;
					NewRow.ContentOfAccountingRecord = NStr("en = 'Other expenses'");
					
					// Movements by register AccountingJournalEntries.
					NewRow = RecordSetAccountingJournalEntries.Add();
					NewRow.Period = Date;
					NewRow.Recorder = Ref;
					NewRow.Company = SelectionDetailRecords.Company;
					NewRow.PlanningPeriod = Catalogs.PlanningPeriods.Actual;
					NewRow.AccountDr = SelectionDetailRecords.GLAccountWriteOff;
					NewRow.AccountCr = SelectionDetailRecords.GLAccount;
					NewRow.Content = NStr("en = 'Other expenses'");
					NewRow.Amount = CorrectionAmount;
					
				Else
					
					// Movements by register AccountingJournalEntries.
					NewRow = RecordSetAccountingJournalEntries.Add();
					NewRow.Period = Date;
					NewRow.Recorder = Ref;
					NewRow.Company = SelectionDetailRecords.Company;
					NewRow.PlanningPeriod = Catalogs.PlanningPeriods.Actual;
					NewRow.AccountDr = SelectionDetailRecords.GLAccountWriteOff;
					NewRow.AccountCr = SelectionDetailRecords.GLAccount;
					NewRow.Content = NStr("en = 'Inventory write-off to arbitrary account'");
					NewRow.Amount = CorrectionAmount;
					
				EndIf;
				
			EndIf;
			
		EndDo;
		
		RecordSetInventory.Write(False);
		RecordSetSales.Write(False);
		RecordSetIncomeAndExpenses.Write(False);
		RecordSetPOSSummary.Write(False);
		RecordSetAccountingJournalEntries.Write(False);
		
		If IterationsQuantity = 15 OR IterationsQuantity = 30 OR IterationsQuantity = 45 Then
			// Clear processed nodes list.
			ListOfProcessedNodes.Clear();
			ListOfProcessedNodes.Add("");
		EndIf;
		
		Query.SetParameter("ListOfProcessedNodes", ListOfProcessedNodes);
		Result = Query.Execute();
		
	EndDo;
	
	Query.Text = "DROP CostAccountingExpenseRecordsRegister";
	Query.Execute();
	
EndProcedure

// Corrects expenses accounting writeoff.
//
// Parameters:
//  Cancel        - Boolean - check box of document posting canceling.
//
Procedure WriteOffCorrectionAccountingCost(OperationKind, InventoryValuationMethod,  ErrorsTable, Cancel)
	
	If InventoryValuationMethod = Enums.InventoryValuationMethods.FIFO Then
		
		PreviousMonth = AddMonth(EndOfMonth(Date), -1);
		If ThereAreRecordsInPerviousPeriods(PreviousMonth, Company) Then
			PreviousInventoryValuationMethod = InformationRegisters.AccountingPolicy.InventoryValuationMethod(PreviousMonth, Company);
			If PreviousInventoryValuationMethod <> InventoryValuationMethod
				AND PreviousInventoryValuationMethod = Enums.InventoryValuationMethods.WeightedAverage Then
				WriteCorrectiveRecordsInInventory();
			EndIf;
		EndIf;
		
		GenerateCorrectiveRegisterRecordsByFIFO();
		WriteOfLandedCostsFromSoldOutProducts();
		
	Else
		
		// Generate states list.
		CountEquationsSLE = MakeRegisterRecordsByRegisterWriteOffCostAdjustment(Cancel);
	
		If CountEquationsSLE > 0 Then
		
			// Solve SLU and determine the average price in each state.
			SolutionIsFound = SolveLES();
		
			If Not SolutionIsFound Then
				Return;
			EndIf;
		
			// Correct movements by states.
			GenerateCorrectiveRegisterRecordsByExpensesRegister();
			
			// Allocate kopecks left in the states (rounding errors result).
			DistributeAmountsWithoutQuantity(OperationKind, ErrorsTable);
			
		Else
			
			Query = New Query(
				"SELECT
				|	""There are no equations"" AS Field1
				|INTO CostAccounting
				|;
				|
				|////////////////////////////////////////////////////////////////////////////////
				|SELECT
				|	""There are no equations"" AS Field1
				|INTO CostAccountingReturnsCurPeriod
				|;
				|
				|////////////////////////////////////////////////////////////////////////////////
				|SELECT
				|	""There are no equations"" AS Field1
				|INTO CostAccountingWriteOff
				|;
				|
				|////////////////////////////////////////////////////////////////////////////////
				|SELECT
				|	""There are no equations"" AS Field1
				|INTO CostAccountingReturnsOnReserves
				|;
				|
				|////////////////////////////////////////////////////////////////////////////////
				|SELECT
				|	""There are no equations"" AS Field1
				|INTO CostAccountingReturnsFree
				|;
				|
				|////////////////////////////////////////////////////////////////////////////////
				|SELECT
				|	""There are no equations"" AS Field1
				|INTO CostAccountingReturns
				|;
				|
				|////////////////////////////////////////////////////////////////////////////////
				|SELECT
				|	""There are no equations"" AS Field1
				|INTO CostAccountingWithoutReturnAccounting"
			);
			
			Query.TempTablesManager = AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
			
			Query.Execute();
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Procedure corrects the cost of returns from client.
//
Procedure CalculateCostOfReturns()
	
	Query = New Query(
	"SELECT
	|	Inventory.Period AS Period,
	|	Inventory.Company AS Company,
	|	Inventory.StructuralUnit AS StructuralUnit,
	|	Inventory.GLAccount AS GLAccount,
	|	Inventory.Products AS Products,
	|	Inventory.Characteristic AS Characteristic,
	|	Inventory.Batch AS Batch,
	|	Inventory.SalesOrder AS SalesOrder,
	|	Inventory.CorrSalesOrder AS CorrSalesOrder,
	|	Inventory.VATRate AS VATRate,
	|	Inventory.SourceDocument AS SourceDocument,
	|	Inventory.Department AS Department,
	|	Inventory.CorrGLAccount AS CorrGLAccount,
	|	Inventory.Responsible AS Responsible,
	|	CASE
	|		WHEN ENDOFPERIOD(Inventory.SourceDocument.Date, MONTH) < ENDOFPERIOD(Inventory.Period, MONTH)
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS ItsReturnOfLastPeriod,
	|	SUM(Inventory.Quantity) AS Quantity,
	|	SUM(Inventory.Amount) AS Amount
	|INTO TtReturns
	|FROM
	|	AccumulationRegister.Inventory AS Inventory
	|WHERE
	|	Inventory.Period between &BeginOfPeriod AND &EndOfPeriod
	|	AND Inventory.RecordType = VALUE(AccumulationRecordType.Receipt)
	|	AND Inventory.Return
	|	AND Inventory.Company = &Company
	|	AND Inventory.CorrGLAccount = &EmptyAccount
	|	AND Inventory.SourceDocument <> UNDEFINED
	|
	|GROUP BY
	|	Inventory.Period,
	|	CASE
	|		WHEN ENDOFPERIOD(Inventory.SourceDocument.Date, MONTH) < ENDOFPERIOD(Inventory.Period, MONTH)
	|			THEN TRUE
	|		ELSE FALSE
	|	END,
	|	Inventory.Company,
	|	Inventory.StructuralUnit,
	|	Inventory.GLAccount,
	|	Inventory.Products,
	|	Inventory.Characteristic,
	|	Inventory.Batch,
	|	Inventory.SalesOrder,
	|	Inventory.CorrSalesOrder,
	|	Inventory.VATRate,
	|	Inventory.SourceDocument,
	|	Inventory.Department,
	|	Inventory.CorrGLAccount,
	|	Inventory.Responsible
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ReturnsTable.Period AS Period,
	|	TRUE AS Return,
	|	&Company AS Company,
	|	ReturnsTable.StructuralUnit AS StructuralUnit,
	|	ReturnsTable.GLAccount AS GLAccount,
	|	ReturnsTable.Products AS Products,
	|	ReturnsTable.Products.BusinessLine AS BusinessLineSales,
	|	ReturnsTable.Products.BusinessLine.GLAccountCostOfSales AS BusinessLineSalesGLAccountOfSalesCost,
	|	ReturnsTable.Characteristic AS Characteristic,
	|	ReturnsTable.Batch AS Batch,
	|	ReturnsTable.SalesOrder AS SalesOrder,
	|	ReturnsTable.CorrSalesOrder AS CorrSalesOrder,
	|	ReturnsTable.Quantity AS ReturnQuantity,
	|	ReturnsTable.Amount AS AmountOfRefunds,
	|	ReturnsTable.SourceDocument AS SourceDocument,
	|	ReturnsTable.Department AS Department,
	|	ReturnsTable.VATRate AS VATRate,
	|	ReturnsTable.Responsible AS Responsible,
	|	ReturnsTable.ItsReturnOfLastPeriod AS ItsReturnOfLastPeriod,
	|	&EmptyAccount AS CorrGLAccount,
	|	SUM(TableSales.Quantity) AS SalesQuantity,
	|	SUM(TableSales.Amount) AS SalesAmount
	|FROM
	|	TtReturns AS ReturnsTable
	|		LEFT JOIN AccumulationRegister.Inventory AS TableSales
	|		ON (TableSales.Company = &Company)
	|			AND ReturnsTable.GLAccount = TableSales.GLAccount
	|			AND ReturnsTable.Products = TableSales.Products
	|			AND ReturnsTable.Characteristic = TableSales.Characteristic
	|			AND ReturnsTable.Batch = TableSales.Batch
	|			AND ReturnsTable.SalesOrder = TableSales.SalesOrder
	|			AND ReturnsTable.SourceDocument = TableSales.SourceDocument
	|			AND ReturnsTable.VATRate = TableSales.VATRate
	|			AND (TableSales.CorrGLAccount = &EmptyAccount)
	|			AND (TableSales.RecordType = VALUE(AccumulationRecordType.Expense))
	|			AND (NOT TableSales.Return)
	|			AND (NOT TableSales.Recorder Refs Document.MonthEndClosing)
	|
	|GROUP BY
	|	ReturnsTable.Period,
	|	ReturnsTable.StructuralUnit,
	|	ReturnsTable.GLAccount,
	|	ReturnsTable.Products,
	|	ReturnsTable.Characteristic,
	|	ReturnsTable.Batch,
	|	ReturnsTable.SalesOrder,
	|	ReturnsTable.CorrSalesOrder,
	|	ReturnsTable.Quantity,
	|	ReturnsTable.Amount,
	|	ReturnsTable.SourceDocument,
	|	ReturnsTable.Department,
	|	ReturnsTable.VATRate,
	|	ReturnsTable.Responsible,
	|	ReturnsTable.ItsReturnOfLastPeriod,
	|	ReturnsTable.Products.BusinessLine,
	|	ReturnsTable.Products.BusinessLine.GLAccountCostOfSales
	|
	|HAVING
	|	(CAST(SUM(TableSales.Amount) - ReturnsTable.Amount AS NUMBER(15, 2))) <> 0
	|");
	
	Query.TempTablesManager = New TempTablesManager;
	Query.SetParameter("EmptyAccount", AdditionalProperties.ForPosting.EmptyAccount);
	Query.SetParameter("Company", AdditionalProperties.ForPosting.Company);
	Query.SetParameter("BeginOfPeriod", AdditionalProperties.ForPosting.BeginOfPeriodningDate);
	Query.SetParameter("EndOfPeriod", AdditionalProperties.ForPosting.EndDatePeriod);
	
	Result = Query.Execute();
	If Result.IsEmpty() Then
		Return;
	EndIf;
	
	// Cost correction.
	
	RecordSetInventory = AccumulationRegisters.Inventory.CreateRecordSet();
	RecordSetInventory.Filter.Recorder.Set(Ref);
	
	RecordSetSales = AccumulationRegisters.Sales.CreateRecordSet();
	RecordSetSales.Filter.Recorder.Set(Ref);
	
	RecordSetIncomeAndExpenses = AccumulationRegisters.IncomeAndExpenses.CreateRecordSet();
	RecordSetIncomeAndExpenses.Filter.Recorder.Set(Ref);
	
	RecordSetAccountingJournalEntries = AccountingRegisters.AccountingJournalEntries.CreateRecordSet();
	RecordSetAccountingJournalEntries.Filter.Recorder.Set(Ref);
	
	SelectionDetailRecords = Result.Select();
	
	While SelectionDetailRecords.Next() Do
		
		If SelectionDetailRecords.SalesQuantity = 0 Then
			CorrectionAmount = 0;
		Else
			SalePrice = SelectionDetailRecords.SalesAmount / SelectionDetailRecords.SalesQuantity;
			AmountOfRefunds = SalePrice * SelectionDetailRecords.ReturnQuantity;
			If SelectionDetailRecords.AmountOfRefunds = 0 Then
				CorrectionAmount = SalePrice * SelectionDetailRecords.ReturnQuantity;
			Else
				CorrectionAmount = SelectionDetailRecords.AmountOfRefunds - SalePrice * SelectionDetailRecords.ReturnQuantity;
			EndIf;
		EndIf;
		
		If (NOT Round(CorrectionAmount, 2) = 0) Then
			
			// Movements on the register Inventory and costs accounting.
			GenerateRegisterRecordsByExpensesRegister(
				RecordSetInventory,
				RecordSetAccountingJournalEntries,
				SelectionDetailRecords,
				CorrectionAmount,
				SelectionDetailRecords.ItsReturnOfLastPeriod, // returns of the last year period by the fixed cost
				NStr("en = 'Cost of return from customer'"),
				True);
			
			// Movements on the register Sales.
			NewRow = RecordSetSales.Add();
			NewRow.Period = Date;
			NewRow.Recorder = Ref;
			NewRow.Company = SelectionDetailRecords.Company;
			NewRow.SalesOrder = SelectionDetailRecords.CorrSalesOrder;
			NewRow.Department = SelectionDetailRecords.Department;
			NewRow.Responsible = SelectionDetailRecords.Responsible;
			NewRow.Products = SelectionDetailRecords.Products;
			NewRow.Characteristic = SelectionDetailRecords.Characteristic;
			NewRow.Batch = SelectionDetailRecords.Batch;
			NewRow.Document = SelectionDetailRecords.SourceDocument;
			NewRow.VATRate = SelectionDetailRecords.VATRate;
			NewRow.Cost = CorrectionAmount;
			
			// Movements on the register IncomeAndExpenses.
			NewRow = RecordSetIncomeAndExpenses.Add();
			NewRow.Period = Date;
			NewRow.Recorder = Ref;
			NewRow.Company = SelectionDetailRecords.Company;
			NewRow.StructuralUnit = SelectionDetailRecords.Department;
			NewRow.SalesOrder = SelectionDetailRecords.CorrSalesOrder;
			If Not ValueIsFilled(NewRow.SalesOrder) Then
				NewRow.SalesOrder = Undefined;
			EndIf;
			NewRow.BusinessLine = SelectionDetailRecords.BusinessLineSales;
			NewRow.GLAccount = SelectionDetailRecords.BusinessLineSalesGLAccountOfSalesCost;
			NewRow.AmountExpense = CorrectionAmount;
			NewRow.ContentOfAccountingRecord = NStr("en = 'Record expenses'");
			
			// Movements by register AccountingJournalEntries.
			NewRow = RecordSetAccountingJournalEntries.Add();
			NewRow.Period = Date;
			NewRow.Recorder = Ref;
			NewRow.Company = SelectionDetailRecords.Company;
			NewRow.PlanningPeriod = Catalogs.PlanningPeriods.Actual;
			NewRow.AccountDr = SelectionDetailRecords.BusinessLineSalesGLAccountOfSalesCost;
			NewRow.AccountCr = SelectionDetailRecords.GLAccount;
			NewRow.Content = NStr("en = 'Record expenses'");
			NewRow.Amount = CorrectionAmount;
			
		EndIf;
		
	EndDo;
	
	RecordSetInventory.Write(False);
	RecordSetSales.Write(False);
	RecordSetIncomeAndExpenses.Write(False);
	RecordSetAccountingJournalEntries.Write(False);

EndProcedure

// The procedure calculates the release actual primecost.
//
// Parameters:
//  Cancel        - Boolean - check box of document posting canceling.
//
Procedure CalculateActualOutputCostPrice(Cancel, OperationKind, ErrorsTable, InventoryValuationMethod)
	
	WriteOffCorrectionAccountingCost(OperationKind, InventoryValuationMethod, ErrorsTable, Cancel);
	
	If InventoryValuationMethod = Enums.InventoryValuationMethods.WeightedAverage Then
		
		DeleteTempTables();
	
		// Clear records set WriteOffCostCorrectionNodes.
		RecordSet = InformationRegisters.WriteOffCostAdjustment.CreateRecordSet();
		RecordSet.Filter.Recorder.Set(Ref);
		RecordSet.Write(True);
		
	EndIf;
	
EndProcedure

Procedure DeleteTempTables()
	
	// Delete temporary tables.
	Query = New Query();
	Query.Text = 
	"DROP SolutionsTable
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP CostAccounting
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP CostAccountingReturnsCurPeriod
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP CostAccountingWriteOff
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP CostAccountingReturnsOnReserves
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP CostAccountingReturnsFree
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP CostAccountingReturns
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP CostAccountingWithoutReturnAccounting";
	
	Query.TempTablesManager = AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.ExecuteBatch();
	
EndProcedure

#EndRegion

#Region Distribution

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
Function GenerateDistributionBaseTable(DistributionBase, AccountingCountsArray, FilterByStructuralUnit, FilterByOrder) Export
	
	ResultTable = New ValueTable;
	
	Query = New Query;
	
	If DistributionBase = Enums.CostAllocationMethod.ProductionVolume Then
		
		QueryText =
		"SELECT
		|	ProductReleaseTurnovers.Company AS Company,
		|	ProductReleaseTurnovers.StructuralUnit AS StructuralUnit,
		|	ProductReleaseTurnovers.Products AS Products,
		|	ProductReleaseTurnovers.Characteristic AS Characteristic,
		|	ProductReleaseTurnovers.Batch AS Batch,
		|	ProductReleaseTurnovers.SalesOrder AS SalesOrder,
		|	ProductReleaseTurnovers.Specification AS Specification,
		|	ProductReleaseTurnovers.Products.ExpensesGLAccount AS GLAccount,
		|	ProductReleaseTurnovers.Products.ExpensesGLAccount.TypeOfAccount AS GLAccountGLAccountType,
		|	ProductReleaseTurnovers.QuantityTurnover AS Base
		|FROM
		|	AccumulationRegister.ProductRelease.Turnovers(
		|			&BegDate,
		|			&EndDate,
		|			,
		|			Company = &Company
		|			// FilterByOrder
		|			// FilterByStructuralUnit
		|	) AS ProductReleaseTurnovers
		|WHERE
		|	ProductReleaseTurnovers.Company = &Company
		|	AND ProductReleaseTurnovers.StructuralUnit.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Department)
		|	AND ProductReleaseTurnovers.Products.ProductsType <> VALUE(Enum.ProductsTypes.Service)";
		
		QueryText = StrReplace(QueryText, "// FilterByOrder", ?(ValueIsFilled(FilterByOrder), "And SalesOrder IN (&OrdersArray)", ""));
		QueryText = StrReplace(QueryText, "// FilterByStructuralUnit", ?(ValueIsFilled(FilterByStructuralUnit), "AND StructuralUnit IN (&BusinessUnitsArray)", ""));
		
	ElsIf DistributionBase = Enums.CostAllocationMethod.DirectCost Then
		
		QueryText =
		"SELECT
		|	CostAccounting.Company AS Company,
		|	CostAccounting.StructuralUnit AS StructuralUnit,
		|	UNDEFINED AS Products,
		|	UNDEFINED AS Characteristic,
		|	UNDEFINED AS Batch,
		|	UNDEFINED AS SalesOrder,
		|	UNDEFINED AS Specification,
		|	CostAccounting.GLAccount AS GLAccount,
		|	CostAccounting.GLAccount.TypeOfAccount AS GLAccountGLAccountType,
		|	CostAccounting.AmountClosingBalance AS Base
		|FROM
		|	AccumulationRegister.Inventory.BalanceAndTurnovers(
		|			&BegDate,
		|			&EndDate,
		|			,
		|			,
		|			Company = &Company
		|				AND GLAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.WorkInProcess)
		|				AND GLAccount IN (&AccountingCountsArray)
		|			// FilterByStructuralUnitTurnovers
		|			// FilterByOrderTurnovers
		|	) AS CostAccounting
		|
		|UNION ALL
		|
		|SELECT
		|	CostAccounting.Company,
		|	CostAccounting.StructuralUnitCorr,
		|	CostAccounting.ProductsCorr,
		|	CostAccounting.CharacteristicCorr,
		|	CostAccounting.BatchCorr,
		|	CostAccounting.CustomerCorrOrder,
		|	CostAccounting.SpecificationCorr,
		|	CostAccounting.CorrGLAccount,
		|	CostAccounting.CorrGLAccount.TypeOfAccount,
		|	SUM(CostAccounting.Amount)
		|FROM
		|	AccumulationRegister.Inventory AS CostAccounting
		|WHERE
		|	CostAccounting.Period between &BegDate AND &EndDate
		|	AND CostAccounting.RecordType = VALUE(AccumulationRecordType.Expense)
		|	AND CostAccounting.Company = &Company
		|	AND CostAccounting.GLAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.WorkInProcess)
		|	AND CostAccounting.GLAccount IN(&AccountingCountsArray)
		|	AND CostAccounting.ProductionExpenses
		|	// FilterByStructuralUnit
		|	// FilterByOrder
		|
		|GROUP BY
		|	CostAccounting.Company,
		|	CostAccounting.StructuralUnitCorr,
		|	CostAccounting.ProductsCorr,
		|	CostAccounting.CharacteristicCorr,
		|	CostAccounting.BatchCorr,
		|	CostAccounting.CustomerCorrOrder,
		|	CostAccounting.SpecificationCorr,
		|	CostAccounting.CorrGLAccount,
		|	CostAccounting.CorrGLAccount.TypeOfAccount";
		
		QueryText = StrReplace(QueryText, "// FilterByStructuralUnitTurnovers", ?(ValueIsFilled(FilterByStructuralUnit), "AND StructuralUnit IN (&BusinessUnitsArray)", ""));
		QueryText = StrReplace(QueryText, "// FilterByOrderTurnovers", ?(ValueIsFilled(FilterByOrder), "And SalesOrder IN (&OrdersArray)", ""));
		QueryText = StrReplace(QueryText, "// FilterByStructuralUnit", ?(ValueIsFilled(FilterByStructuralUnit), "AND CostAccounting.StructuralUnitCorr IN (&BusinessUnitsArray)", ""));
		QueryText = StrReplace(QueryText, "// FilterByOrder", ?(ValueIsFilled(FilterByOrder), "And CostAccounting.CorrSalesOrder IN (&OrdersArray)", ""));
		
		Query.SetParameter("AccountingCountsArray", AccountingCountsArray);
		
	Else
		Return ResultTable;
	EndIf;
	
	Query.Text = QueryText;
	
	Query.SetParameter("BegDate"    , AdditionalProperties.ForPosting.BeginOfPeriodningDate);
	Query.SetParameter("EndDate"    , AdditionalProperties.ForPosting.EndDatePeriod);
	Query.SetParameter("Company", AdditionalProperties.ForPosting.Company);
	
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
	
	ResultTable = Query.Execute().Unload();
	
	Return ResultTable;
	
EndFunction

// Distributes costs.
//
// Parameters:
//  Cancel        - Boolean - check box of document posting canceling.
//
Procedure DistributeCosts(Cancel, ErrorsTable)
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	InventoryAndCostAccounting.Company AS Company,
	|	InventoryAndCostAccounting.StructuralUnit AS StructuralUnit,
	|	InventoryAndCostAccounting.GLAccount AS GLAccount,
	|	InventoryAndCostAccounting.GLAccount.TypeOfAccount AS GLAccountGLAccountType,
	|	InventoryAndCostAccounting.GLAccount.MethodOfDistribution AS GLAccountMethodOfDistribution,
	|	InventoryAndCostAccounting.GLAccount.ClosingAccount AS GLAccountClosingAccount,
	|	InventoryAndCostAccounting.GLAccount.ClosingAccount.TypeOfAccount AS GLAccountClosingAccountAccountType,
	|	InventoryAndCostAccounting.Products AS Products,
	|	InventoryAndCostAccounting.Characteristic AS Characteristic,
	|	InventoryAndCostAccounting.Batch AS Batch,
	|	InventoryAndCostAccounting.SalesOrder AS SalesOrder,
	|	InventoryAndCostAccounting.AmountBalance AS Amount
	|FROM
	|	AccumulationRegister.Inventory.Balance(
	|			&EndDate,
	|			Company = &Company
	|				AND GLAccount.MethodOfDistribution <> VALUE(Enum.CostAllocationMethod.DoNotDistribute)
	|				AND (GLAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.IndirectExpenses)
	|					OR GLAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.WorkInProcess)
	|						AND Products = VALUE(Catalog.Products.EmptyRef))) AS InventoryAndCostAccounting
	|
	|ORDER BY
	|	GLAccountMethodOfDistribution,
	|	StructuralUnit,
	|	SalesOrder
	|TOTALS
	|	SUM(Amount)
	|BY
	|	GLAccountMethodOfDistribution,
	|	StructuralUnit,
	|	SalesOrder";
	
	Query.SetParameter("Company", AdditionalProperties.ForPosting.Company);
	Query.SetParameter("BegDate"    , AdditionalProperties.ForPosting.BeginOfPeriodningDate);
	Query.SetParameter("EndDate"    , AdditionalProperties.ForPosting.LastBoundaryPeriod);
	
	QueryResult = Query.Execute();
	
	If QueryResult.IsEmpty() Then
		Return;
	EndIf;
	
	// Create the accumulation register records set Inventory and expenses accounting.
	RecordSetInventory = AccumulationRegisters.Inventory.CreateRecordSet();
	RecordSetInventory.Filter.Recorder.Set(AdditionalProperties.ForPosting.Ref);
	
	// Create the accumulation register records set Income and expenses accounting.
	RecordSetAccountingJournalEntries = AccountingRegisters.AccountingJournalEntries.CreateRecordSet();
	RecordSetAccountingJournalEntries.Filter.Recorder.Set(Ref);
	
	BypassByDistributionMethod = QueryResult.Select(QueryResultIteration.ByGroups);
	
	While BypassByDistributionMethod.Next() Do
		
		BypassByStructuralUnit = BypassByDistributionMethod.Select(QueryResultIteration.ByGroups);
		
		// Bypass on departments.
		While BypassByStructuralUnit.Next() Do
			
			FilterByStructuralUnit = BypassByStructuralUnit.StructuralUnit;
			BypassByOrder = BypassByStructuralUnit.Select(QueryResultIteration.ByGroups);
			
			// Bypass on orders.
			While BypassByOrder.Next() Do
				
				FilterByOrder = BypassByOrder.SalesOrder;
				
				If BypassByOrder.GLAccountMethodOfDistribution = Enums.CostAllocationMethod.DoNotDistribute Then
					Continue;
				EndIf;
				
				BypassByGLAccounts = BypassByOrder.Select(QueryResultIteration.ByGroups);
				
				// Bypass on the expenses accounts.
				While BypassByGLAccounts.Next() Do
					
					// Generate allocation base table.
					BaseTable = GenerateDistributionBaseTable(
						BypassByGLAccounts.GLAccountMethodOfDistribution,
						BypassByGLAccounts.GLAccount.GLAccounts.UnloadColumn("GLAccount"),
						FilterByStructuralUnit,
						FilterByOrder
					);
					
					If BaseTable.Count() = 0 Then
						BaseTable = GenerateDistributionBaseTable(
							BypassByGLAccounts.GLAccountMethodOfDistribution,
							BypassByGLAccounts.GLAccount.GLAccounts.UnloadColumn("GLAccount"),
							Undefined,
							FilterByOrder
						);
					EndIf;
				
					// Check distribution base table.
					If BaseTable.Count() = 0 Then
						ErrorDescription = GenerateErrorDescriptionCostAllocation(
							BypassByGLAccounts.GLAccount,
							BypassByGLAccounts.GLAccountMethodOfDistribution,
							FilterByOrder,
							BypassByGLAccounts.Amount
						);
						AddErrorIntoTable(ErrorDescription, "CostAllocation", ErrorsTable, FilterByOrder);
						Continue;
					EndIf;
					
					TotalBaseDistribution = BaseTable.Total("Base");
					DirectionsQuantity  = BaseTable.Count() - 1;
					
					// Allocate amount.
					If BypassByGLAccounts.Amount <> 0 Then
						
						SumDistribution = BypassByGLAccounts.Amount;
						SumWasDistributed = 0;
					
						For Each DistributionDirection In BaseTable Do
							
							CostAmount = ?(SumDistribution = 0, 0, Round(DistributionDirection.Base / TotalBaseDistribution * SumDistribution, 2, 1));
							SumWasDistributed = SumWasDistributed + CostAmount;
							
							// If it is the last string - , correct amount in it to the rounding error.
							If BaseTable.IndexOf(DistributionDirection) = DirectionsQuantity Then
								CostAmount = CostAmount + SumDistribution - SumWasDistributed;
								SumWasDistributed = SumWasDistributed + CostAmount;
							EndIf;
							
							If CostAmount <> 0 Then
								
								If BypassByGLAccounts.GLAccountGLAccountType = Enums.GLAccountsTypes.IndirectExpenses Then // the indirect ones are allocated via the closing account
								
									RegisterRecordRow = New Structure;
									RegisterRecordRow.Insert("Company"           , BypassByGLAccounts.Company);
									RegisterRecordRow.Insert("StructuralUnit"    , BypassByGLAccounts.StructuralUnit);
									RegisterRecordRow.Insert("GLAccount"             , BypassByGLAccounts.GLAccount);
									RegisterRecordRow.Insert("GLAccountGLAccountType"     , BypassByGLAccounts.GLAccountGLAccountType);
									RegisterRecordRow.Insert("Products"          , BypassByGLAccounts.Products);
									RegisterRecordRow.Insert("Characteristic"        , BypassByGLAccounts.Characteristic);
									RegisterRecordRow.Insert("Batch"                , BypassByGLAccounts.Batch);
									RegisterRecordRow.Insert("SalesOrder"       , BypassByGLAccounts.SalesOrder);
									RegisterRecordRow.Insert("StructuralUnitCorr", DistributionDirection.StructuralUnit);
									RegisterRecordRow.Insert("CorrGLAccount"         , BypassByGLAccounts.GLAccountClosingAccount);
									RegisterRecordRow.Insert("CorrAccountFinancialAccountType" , BypassByGLAccounts.GLAccountClosingAccountAccountType);
									RegisterRecordRow.Insert("ProductsCorr"      , Catalogs.Products.EmptyRef());
									RegisterRecordRow.Insert("CharacteristicCorr"    , Catalogs.ProductsCharacteristics.EmptyRef());
									RegisterRecordRow.Insert("BatchCorr"            , Catalogs.ProductsBatches.EmptyRef());
									RegisterRecordRow.Insert("CustomerCorrOrder"   , Undefined);
									RegisterRecordRow.Insert("SourceDocument"       , Undefined);
									RegisterRecordRow.Insert("ProductionExpenses"       , False);
									RegisterRecordRow.Insert("Specification"          , Catalogs.BillsOfMaterials.EmptyRef());
									RegisterRecordRow.Insert("SpecificationCorr"      , Catalogs.BillsOfMaterials.EmptyRef());
									RegisterRecordRow.Insert("VATRate"             , Catalogs.VATRates.EmptyRef());
									
									// Movements on the register Inventory and costs accounting.
									GenerateRegisterRecordsByExpensesRegister(
										RecordSetInventory,
										RecordSetAccountingJournalEntries,
										RegisterRecordRow,
										CostAmount,
										True
									);
									
									If ValueIsFilled(DistributionDirection.Products) Then
										
										RegisterRecordRow = New Structure;
										RegisterRecordRow.Insert("Company"           , BypassByGLAccounts.Company);
										RegisterRecordRow.Insert("StructuralUnit"    , DistributionDirection.StructuralUnit);
										RegisterRecordRow.Insert("GLAccount"             , BypassByGLAccounts.GLAccountClosingAccount);
										RegisterRecordRow.Insert("GLAccountGLAccountType"     , BypassByGLAccounts.GLAccountClosingAccountAccountType);
										RegisterRecordRow.Insert("Products"          , Catalogs.Products.EmptyRef());
										RegisterRecordRow.Insert("Characteristic"        , Catalogs.ProductsCharacteristics.EmptyRef());
										RegisterRecordRow.Insert("Batch"                , Catalogs.ProductsBatches.EmptyRef());
										RegisterRecordRow.Insert("SalesOrder"       , Undefined);
										RegisterRecordRow.Insert("StructuralUnitCorr", DistributionDirection.StructuralUnit);
										RegisterRecordRow.Insert("CorrGLAccount"         , DistributionDirection.GLAccount);
										RegisterRecordRow.Insert("CorrAccountFinancialAccountType" , DistributionDirection.GLAccountGLAccountType);
										RegisterRecordRow.Insert("ProductsCorr"      , DistributionDirection.Products);
										RegisterRecordRow.Insert("CharacteristicCorr"    , DistributionDirection.Characteristic);
										RegisterRecordRow.Insert("BatchCorr"            , DistributionDirection.Batch);
										RegisterRecordRow.Insert("CustomerCorrOrder"   , DistributionDirection.SalesOrder);
										RegisterRecordRow.Insert("SourceDocument"       , Undefined);
										RegisterRecordRow.Insert("ProductionExpenses"       , True);
										RegisterRecordRow.Insert("Specification"          , Catalogs.BillsOfMaterials.EmptyRef());
										RegisterRecordRow.Insert("SpecificationCorr"      , DistributionDirection.Specification);
										RegisterRecordRow.Insert("VATRate"             , Catalogs.VATRates.EmptyRef());
									
										// Movements on the register Inventory and costs accounting.
										GenerateRegisterRecordsByExpensesRegister(
											RecordSetInventory,
											RecordSetAccountingJournalEntries,
											RegisterRecordRow,
											CostAmount,
											True
										);
										
									EndIf;
									
								ElsIf ValueIsFilled(DistributionDirection.Products) Then // allocation of the direct ones
									
									RegisterRecordRow = New Structure;
									RegisterRecordRow.Insert("Company"           , BypassByGLAccounts.Company);
									RegisterRecordRow.Insert("StructuralUnit"    , BypassByGLAccounts.StructuralUnit);
									RegisterRecordRow.Insert("GLAccount"             , BypassByGLAccounts.GLAccount);
									RegisterRecordRow.Insert("GLAccountGLAccountType"     , BypassByGLAccounts.GLAccountGLAccountType);
									RegisterRecordRow.Insert("Products"          , BypassByGLAccounts.Products);
									RegisterRecordRow.Insert("Characteristic"        , BypassByGLAccounts.Characteristic);
									RegisterRecordRow.Insert("Batch"                , BypassByGLAccounts.Batch);
									RegisterRecordRow.Insert("SalesOrder"       , BypassByGLAccounts.SalesOrder);
									RegisterRecordRow.Insert("StructuralUnitCorr", DistributionDirection.StructuralUnit);
									RegisterRecordRow.Insert("CorrGLAccount"         , DistributionDirection.GLAccount);
									RegisterRecordRow.Insert("CorrAccountFinancialAccountType" , DistributionDirection.GLAccountGLAccountType);
									RegisterRecordRow.Insert("ProductsCorr"      , DistributionDirection.Products);
									RegisterRecordRow.Insert("CharacteristicCorr"    , DistributionDirection.Characteristic);
									RegisterRecordRow.Insert("BatchCorr"            , DistributionDirection.Batch);
									RegisterRecordRow.Insert("CustomerCorrOrder"   , DistributionDirection.SalesOrder);
									RegisterRecordRow.Insert("SourceDocument"       , Undefined);
									RegisterRecordRow.Insert("ProductionExpenses"       , True);
									RegisterRecordRow.Insert("Specification"          , Catalogs.BillsOfMaterials.EmptyRef());
									RegisterRecordRow.Insert("SpecificationCorr"      , DistributionDirection.Specification);
									RegisterRecordRow.Insert("VATRate"             , Catalogs.VATRates.EmptyRef());
									
									// Movements on the register Inventory and costs accounting.
									GenerateRegisterRecordsByExpensesRegister(
										RecordSetInventory,
										RecordSetAccountingJournalEntries,
										RegisterRecordRow,
										CostAmount,
										True
									);
									
								EndIf;
								
							EndIf;
							
						EndDo;
						
						If SumWasDistributed = 0 Then
							ErrorDescription = GenerateErrorDescriptionCostAllocation(
								BypassByGLAccounts.GLAccount,
								BypassByGLAccounts.GLAccountMethodOfDistribution,
								FilterByOrder,
								BypassByGLAccounts.Amount
							);
							AddErrorIntoTable(ErrorDescription, "CostAllocation", ErrorsTable, FilterByOrder);
							Continue;
						EndIf;
						
					EndIf
					
				EndDo;
				
			EndDo;
			
		EndDo;
		
	EndDo;
	
	RecordSetInventory.Write(False);
	RecordSetAccountingJournalEntries.Write(False);
	
EndProcedure

#EndRegion

#Region FinancialResultCalculation

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
Function GenerateFinancialResultDistributionBaseTable(DistributionBase, FilterByStructuralUnit, FilterByBusinessLine, FilterByOrder) Export
	
	ResultTable = New ValueTable;
	
	Query = New Query;
	
	If DistributionBase = Enums.CostAllocationMethod.SalesRevenue
	 OR DistributionBase = Enums.CostAllocationMethod.CostOfGoodsSold
	 OR DistributionBase = Enums.CostAllocationMethod.SalesVolume
	 OR DistributionBase = Enums.CostAllocationMethod.GrossProfit Then
		
		If DistributionBase = Enums.CostAllocationMethod.SalesRevenue Then
			TextOfDatabase = "SalesTurnovers.AmountTurnover";
		ElsIf DistributionBase = Enums.CostAllocationMethod.CostOfGoodsSold Then 
			TextOfDatabase = "SalesTurnovers.CostTurnover";
		ElsIf DistributionBase = Enums.CostAllocationMethod.GrossProfit Then 
			TextOfDatabase = "SalesTurnovers.AmountTurnover - SalesTurnovers.CostTurnover";
		Else
			TextOfDatabase = "SalesTurnovers.QuantityTurnover";
		EndIf; 
		
		QueryText = 
		"SELECT
		|	SalesTurnovers.Company AS Company,
		|	SalesTurnovers.Products.BusinessLine AS BusinessLine,
		|	SalesTurnovers.SalesOrder AS Order,
		|	SalesTurnovers.Products.BusinessLine.GLAccountRevenueFromSales AS GLAccountRevenueFromSales,
		|	SalesTurnovers.Products.BusinessLine.GLAccountCostOfSales AS GLAccountCostOfSales,
		|	SalesTurnovers.Products.BusinessLine.ProfitGLAccount AS ProfitGLAccount,
		|	// TextOfDatabase AS Base,
		|	SalesTurnovers.Department AS StructuralUnit
		|FROM
		|	AccumulationRegister.Sales.Turnovers(
		|			&BegDate,
		|			&EndDate,
		|			Auto,
		|			Company = &Company
		|				// FilterByStructuralUnit
		|				// FilterByBusinessLine
		|				// FilterByOrder
		|			) AS SalesTurnovers
		|WHERE
		|	SalesTurnovers.Products.BusinessLine <> VALUE(Catalog.LinesOfBusiness.Other)";
		
		QueryText = StrReplace(QueryText, "// FilterByStructuralUnit", ?(ValueIsFilled(FilterByStructuralUnit), "AND Department IN (&BusinessUnitsArray)", ""));
		QueryText = StrReplace(QueryText, "// FilterByBusinessLine", ?(ValueIsFilled(FilterByBusinessLine), "And Products.BusinessLine IN (&BusinessLineArray)", ""));
		QueryText = StrReplace(QueryText, "// FilterByOrder", ?(ValueIsFilled(FilterByOrder), "And SalesOrder IN (&OrdersArray)", ""));
		QueryText = StrReplace(QueryText, "// TextOfDatabase", TextOfDatabase);
		
	Else
		Return ResultTable;
	EndIf;
	
	Query.Text = QueryText;
	
	Query.SetParameter("BegDate"    , AdditionalProperties.ForPosting.BeginOfPeriodningDate);
	Query.SetParameter("EndDate"    , AdditionalProperties.ForPosting.EndDatePeriod);
	Query.SetParameter("Company", AdditionalProperties.ForPosting.Company);
		
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
			Query.SetParameter("BusinessLineArray", FilterByBusinessLine);
		Else
			ArrayForSelection = New Array;
			ArrayForSelection.Add(FilterByBusinessLine);
			Query.SetParameter("BusinessLineArray", FilterByBusinessLine);
		EndIf;
	EndIf;
	
	ResultTable = Query.Execute().Unload();
	
	Return ResultTable;
	
EndFunction

// Calculates the financial result.
//
// Parameters:
//  Cancel        - Boolean - check box of document posting canceling.
//
Procedure CalculateFinancialResult(Cancel, ErrorsTable)
	
	// 1) Direct allocation.
	Query = New Query;
	Query.Text =
	"SELECT
	|	IncomeAndExpencesTurnOvers.Company AS Company,
	|	IncomeAndExpencesTurnOvers.StructuralUnit AS StructuralUnit,
	|	IncomeAndExpencesTurnOvers.BusinessLine AS BusinessLine,
	|	IncomeAndExpencesTurnOvers.BusinessLine.ProfitGLAccount AS ProfitGLAccount,
	|	IncomeAndExpencesTurnOvers.SalesOrder AS Order,
	|	IncomeAndExpencesTurnOvers.GLAccount AS GLAccount,
	|	IncomeAndExpencesTurnOvers.AmountIncomeTurnover AS AmountIncome,
	|	IncomeAndExpencesTurnOvers.AmountExpenseTurnover AS AmountExpense
	|FROM
	|	AccumulationRegister.IncomeAndExpenses.Turnovers(
	|			&BegDate,
	|			&EndDate,
	|			Auto,
	|			Company = &Company
	|				AND (GLAccount.MethodOfDistribution = VALUE(Enum.CostAllocationMethod.DoNotDistribute)
	|					OR (BusinessLine.GLAccountCostOfSales = GLAccount
	|						OR BusinessLine.GLAccountRevenueFromSales = GLAccount)
	|						AND BusinessLine <> VALUE(Catalog.LinesOfBusiness.Other))) AS IncomeAndExpencesTurnOvers";
	
	Query.SetParameter("Company", AdditionalProperties.ForPosting.Company);
	Query.SetParameter("BegDate"    , AdditionalProperties.ForPosting.BeginOfPeriodningDate);
	Query.SetParameter("EndDate"    , AdditionalProperties.ForPosting.LastBoundaryPeriod);
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then

		RecordSetFinancialResult = AccumulationRegisters.FinancialResult.CreateRecordSet();
		RecordSetFinancialResult.Filter.Recorder.Set(AdditionalProperties.ForPosting.Ref);
		
		RecordSetAccountingJournalEntries = AccountingRegisters.AccountingJournalEntries.CreateRecordSet();
		RecordSetAccountingJournalEntries.Filter.Recorder.Set(Ref);
		
	EndIf;
	
	SelectionQueryResult = QueryResult.Select();

	While SelectionQueryResult.Next() Do
		
		NewRow = RecordSetFinancialResult.Add();
		NewRow.Period = Date;
		NewRow.Recorder = Ref;
		NewRow.Company = SelectionQueryResult.Company;
		NewRow.StructuralUnit = SelectionQueryResult.StructuralUnit;
		NewRow.BusinessLine = ?(
			ValueIsFilled(SelectionQueryResult.BusinessLine), SelectionQueryResult.BusinessLine, Catalogs.LinesOfBusiness.MainLine);
		NewRow.SalesOrder = SelectionQueryResult.Order;
		NewRow.GLAccount = SelectionQueryResult.GLAccount;
		
		If SelectionQueryResult.AmountIncome <> 0 Then
			NewRow.AmountIncome = SelectionQueryResult.AmountIncome;
		ElsIf SelectionQueryResult.AmountExpense <> 0 Then
			NewRow.AmountExpense = SelectionQueryResult.AmountExpense;
		EndIf;
		
		NewRow.ContentOfAccountingRecord = NStr("en = 'Financial result'", CommonUseClientServer.MainLanguageCode());
		
		// Movements by register AccountingJournalEntries.
		NewRow = RecordSetAccountingJournalEntries.Add();
		NewRow.Period = Date;
		NewRow.Recorder = Ref;
		NewRow.Company = SelectionQueryResult.Company;
		NewRow.PlanningPeriod = Catalogs.PlanningPeriods.Actual;
		
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
		
		NewRow.Content = "Financial result";
		
	EndDo;
	
	If Not QueryResult.IsEmpty() Then
		
		RecordSetFinancialResult.Write(False);
		RecordSetAccountingJournalEntries.Write(False);
		
	EndIf;
	
	// 2) Allocation by the allocation base.
	Query.Text =
	"SELECT
	|	IncomeAndExpencesTurnOvers.Company AS Company,
	|	IncomeAndExpencesTurnOvers.StructuralUnit AS StructuralUnit,
	|	IncomeAndExpencesTurnOvers.BusinessLine AS BusinessLine,
	|	IncomeAndExpencesTurnOvers.BusinessLine.ProfitGLAccount AS ProfitGLAccount,
	|	IncomeAndExpencesTurnOvers.SalesOrder AS Order,
	|	IncomeAndExpencesTurnOvers.GLAccount AS GLAccount,
	|	IncomeAndExpencesTurnOvers.GLAccount.MethodOfDistribution AS GLAccountMethodOfDistribution,
	|	IncomeAndExpencesTurnOvers.AmountIncomeTurnover AS AmountIncome,
	|	IncomeAndExpencesTurnOvers.AmountExpenseTurnover AS AmountExpense
	|FROM
	|	AccumulationRegister.IncomeAndExpenses.Turnovers(
	|			&BegDate,
	|			&EndDate,
	|			Auto,
	|			Company = &Company
	|				AND GLAccount.MethodOfDistribution <> VALUE(Enum.CostAllocationMethod.DoNotDistribute)
	|				AND (BusinessLine.GLAccountCostOfSales <> GLAccount
	|						AND BusinessLine.GLAccountRevenueFromSales <> GLAccount
	|					OR BusinessLine = VALUE(Catalog.LinesOfBusiness.Other)
	|					OR BusinessLine = VALUE(Catalog.LinesOfBusiness.EmptyRef))) AS IncomeAndExpencesTurnOvers
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
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		
		// Create the accumulation register records set Inventory and expenses accounting.
		RecordSetFinancialResult = AccumulationRegisters.FinancialResult.CreateRecordSet();
		RecordSetFinancialResult.Filter.Recorder.Set(AdditionalProperties.ForPosting.Ref);
		
		// Create the accumulation register records set Income and expenses accounting.
		RecordSetAccountingJournalEntries = AccountingRegisters.AccountingJournalEntries.CreateRecordSet();
		RecordSetAccountingJournalEntries.Filter.Recorder.Set(Ref);
		
	Else
		
		Return;
		
	EndIf;
	
	BypassByDistributionMethod = QueryResult.Select(QueryResultIteration.ByGroups);
	
	// Bypass by the allocation methods.
	While BypassByDistributionMethod.Next() Do
		
		BypassByStructuralUnit = BypassByDistributionMethod.Select(QueryResultIteration.ByGroups);
		
		// Bypass on departments.
		While BypassByStructuralUnit.Next() Do
			
			FilterByStructuralUnit = BypassByStructuralUnit.StructuralUnit;
			
			BypassByActivityDirection = BypassByStructuralUnit.Select(QueryResultIteration.ByGroups);
			
			// Bypass by the activity directions.
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
						FilterByStructuralUnit,
						Undefined,
						Undefined
					);
					
					If BaseTable.Count() > 0 Then
						
						BaseTable = GenerateFinancialResultDistributionBaseTable(
							BypassByOrder.GLAccountMethodOfDistribution,
							FilterByStructuralUnit,
							FilterByBusinessLine,
							FilterByOrder
						);
						
						If BaseTable.Count() = 0 Then
							BaseTable = GenerateFinancialResultDistributionBaseTable(
								BypassByOrder.GLAccountMethodOfDistribution,
								FilterByStructuralUnit,
								FilterByBusinessLine,
								Undefined
							);
						EndIf;
						
						If BaseTable.Count() = 0 Then
							BaseTable = GenerateFinancialResultDistributionBaseTable(
								BypassByOrder.GLAccountMethodOfDistribution,
								FilterByStructuralUnit,
								Undefined,
								Undefined
							);
						EndIf;
						
					Else
						
						BaseTable = GenerateFinancialResultDistributionBaseTable(
							BypassByOrder.GLAccountMethodOfDistribution,
							Undefined,
							FilterByBusinessLine,
							FilterByOrder
						);
						
						If BaseTable.Count() = 0 Then
							BaseTable = GenerateFinancialResultDistributionBaseTable(
								BypassByOrder.GLAccountMethodOfDistribution,
								Undefined,
								FilterByBusinessLine,
								Undefined
							);
						EndIf;
						
						If BaseTable.Count() = 0 Then
							BaseTable = GenerateFinancialResultDistributionBaseTable(
								BypassByOrder.GLAccountMethodOfDistribution,
								Undefined,
								Undefined,
								Undefined
							);
						EndIf;
					
					EndIf;
					
					If BaseTable.Count() > 0 Then
						TotalBaseDistribution = BaseTable.Total("Base");
						DirectionsQuantity  = BaseTable.Count() - 1;
					Else
						TotalBaseDistribution = 0;
						DirectionsQuantity  = 0;
					EndIf;
					
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
									CostAmount = CostAmount + SumDistribution - SumWasDistributed;
									SumWasDistributed = SumWasDistributed + CostAmount;
								EndIf;
								
								If CostAmount <> 0 Then
									
									// Movements by register Financial result.
									NewRow	= RecordSetFinancialResult.Add();
									NewRow.Period = Date;
									NewRow.Recorder	= Ref;
									NewRow.Company	= DistributionDirection.Company;
									NewRow.StructuralUnit = DistributionDirection.StructuralUnit;
									NewRow.BusinessLine	= DistributionDirection.BusinessLine;
									NewRow.SalesOrder	= DistributionDirection.Order;
									
									NewRow.GLAccount = BypassByGLAccounts.GLAccount;
									If BypassByGLAccounts.AmountIncome <> 0 Then
										NewRow.AmountIncome = CostAmount;
									ElsIf BypassByGLAccounts.AmountExpense <> 0 Then
										NewRow.AmountExpense = CostAmount;
									EndIf;
									
									NewRow.ContentOfAccountingRecord = NStr("en = 'Financial result'");
									
									// Movements by register AccountingJournalEntries.
									NewRow = RecordSetAccountingJournalEntries.Add();
									NewRow.Period = Date;
									NewRow.Recorder = Ref;
									NewRow.Company = DistributionDirection.Company;
									NewRow.PlanningPeriod = Catalogs.PlanningPeriods.Actual;
									
									If BypassByGLAccounts.AmountIncome <> 0 Then
										If CostAmount > 0 Then
											NewRow.AccountDr = BypassByGLAccounts.GLAccount;
											NewRow.AccountCr = DistributionDirection.ProfitGLAccount;
											NewRow.Amount = CostAmount;
										Else
											NewRow.AccountDr = DistributionDirection.ProfitGLAccount;
											NewRow.AccountCr = BypassByGLAccounts.GLAccount;
											NewRow.Amount = -CostAmount;
										EndIf;
									ElsIf BypassByGLAccounts.AmountExpense <> 0 Then
										If CostAmount > 0 Then 
											NewRow.AccountDr = DistributionDirection.ProfitGLAccount;
											NewRow.AccountCr = BypassByGLAccounts.GLAccount;
											NewRow.Amount = CostAmount;
										Else
											NewRow.AccountDr = BypassByGLAccounts.GLAccount;
											NewRow.AccountCr = DistributionDirection.ProfitGLAccount;
											NewRow.Amount = -CostAmount;
										EndIf;
									EndIf;
									
									NewRow.Content = NStr("en = 'Financial result'");
									
								EndIf;
								
							EndDo;
							
							If SumWasDistributed = 0 Then
								
								ErrorDescription = GenerateErrorDescriptionExpensesDistribution(
									BypassByGLAccounts.GLAccount,
									BypassByOrder.GLAccountMethodOfDistribution,
									?(BypassByGLAccounts.AmountIncome <> 0,
										BypassByGLAccounts.AmountIncome,
										BypassByGLAccounts.AmountExpense)
								);
								AddErrorIntoTable(ErrorDescription, "FinancialResultCalculation", ErrorsTable);
								Continue;
								
							EndIf;
							
						EndIf
						
					EndDo;
					
				EndDo;
				
			EndDo;
			
		EndDo;
		
	EndDo;

	RecordSetFinancialResult.Write(False);
	RecordSetFinancialResult.Clear();
	
	RecordSetAccountingJournalEntries.Write(False);
	RecordSetAccountingJournalEntries.Clear();
	
EndProcedure

#EndRegion

#Region PrimecostInRetailCalculationEarningAccounting

Procedure CalculateCostPriceInRetailEarningAccounting(Cancel, ErrorsTable)
	
	Query = New Query;
	
	Query.SetParameter("DateBeg", AdditionalProperties.ForPosting.BeginOfPeriodningDate);
	Query.SetParameter("DateEnd", AdditionalProperties.ForPosting.EndDatePeriod);
	Query.SetParameter("Company", AdditionalProperties.ForPosting.Company);
	
	Query.Text =
	"SELECT
	|	POSSummaryTurnovers.Company AS Company,
	|	POSSummaryTurnovers.StructuralUnit AS StructuralUnit,
	|	POSSummaryTurnovers.Currency AS Currency,
	|	POSSummaryTurnovers.AmountCurReceipt AS AmountCurReceipt,
	|	POSSummaryTurnovers.AmountCurExpense AS AmountCurExpense,
	|	POSSummaryTurnovers.CostReceipt AS CostReceipt,
	|	POSSummaryTurnovers.CostExpense AS CostExpense,
	|	CASE
	|		WHEN POSSummaryTurnovers.AmountCurReceipt <> 0
	|			THEN CAST(POSSummaryTurnovers.AmountCurExpense * POSSummaryTurnovers.CostReceipt / POSSummaryTurnovers.AmountCurReceipt AS NUMBER(15, 2)) - POSSummaryTurnovers.CostExpense
	|		ELSE 0
	|	END AS TotalCorrectionAmount
	|INTO TemporaryTableCorrectionAmount
	|FROM
	|	AccumulationRegister.POSSummary.Turnovers(, &DateEnd, , Company = &Company) AS POSSummaryTurnovers
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	POSSummary.Company AS Company,
	|	POSSummary.StructuralUnit AS StructuralUnit,
	|	POSSummary.Currency AS Currency,
	|	SUM(POSSummary.Cost) AS CostExpense
	|INTO TemporaryTableTotalCostPriceExpense
	|FROM
	|	AccumulationRegister.POSSummary AS POSSummary
	|WHERE
	|	POSSummary.Period between &DateBeg AND &DateEnd
	|	AND POSSummary.RecordType = VALUE(AccumulationRecordType.Expense)
	|	AND POSSummary.Cost <> 0
	|	AND POSSummary.Company = &Company
	|	AND POSSummary.SalesDocument <> VALUE(Document.CashReceipt.EmptyRef)
	|
	|GROUP BY
	|	POSSummary.Company,
	|	POSSummary.StructuralUnit,
	|	POSSummary.Currency
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	POSSummary.Company AS Company,
	|	POSSummary.StructuralUnit AS StructuralUnit,
	|	POSSummary.Currency AS Currency,
	|	POSSummary.SalesDocument AS SalesDocument,
	|	POSSummary.SalesDocument.Department AS DocumentSalesUnit,
	|	POSSummary.SalesDocument.StructuralUnit.RetailPriceKind.PriceCurrency AS SalesDocumentStructuralUnitPriceTypeRetailCurrencyPrices,
	|	POSSummary.SalesDocument.BusinessLine AS DocumentSalesBusinessLine,
	|	POSSummary.SalesDocument.BusinessLine.GLAccountCostOfSales AS DocumentSalesBusinessLineGLAccountCost,
	|	POSSummary.SalesDocument.StructuralUnit.GLAccountInRetail AS DocumentSalesUnitAccountStructureInRetail,
	|	POSSummary.SalesDocument.StructuralUnit.MarkupGLAccount AS DocumentSalesUnitStructureMarkupAccount,
	|	CASE
	|		WHEN ISNULL(TemporaryTableTotalCostPriceExpense.CostExpense, 0) <> 0
	|			THEN CAST(POSSummary.Cost / TemporaryTableTotalCostPriceExpense.CostExpense * TemporaryTableCorrectionAmount.TotalCorrectionAmount AS NUMBER(15, 2))
	|		ELSE 0
	|	END AS CorrectionAmount
	|FROM
	|	AccumulationRegister.POSSummary AS POSSummary
	|		LEFT JOIN TemporaryTableCorrectionAmount AS TemporaryTableCorrectionAmount
	|		ON POSSummary.Company = TemporaryTableCorrectionAmount.Company
	|			AND POSSummary.StructuralUnit = TemporaryTableCorrectionAmount.StructuralUnit
	|			AND POSSummary.Currency = TemporaryTableCorrectionAmount.Currency
	|		LEFT JOIN TemporaryTableTotalCostPriceExpense AS TemporaryTableTotalCostPriceExpense
	|		ON POSSummary.Company = TemporaryTableTotalCostPriceExpense.Company
	|			AND POSSummary.StructuralUnit = TemporaryTableTotalCostPriceExpense.StructuralUnit
	|			AND POSSummary.Currency = TemporaryTableTotalCostPriceExpense.Currency
	|WHERE
	|	POSSummary.Period between &DateBeg AND &DateEnd
	|	AND POSSummary.RecordType = VALUE(AccumulationRecordType.Expense)
	|	AND POSSummary.Cost <> 0
	|	AND POSSummary.Company = &Company
	|	AND POSSummary.SalesDocument <> VALUE(Document.CashReceipt.EmptyRef)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP TemporaryTableCorrectionAmount
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP TemporaryTableTotalCostPriceExpense";
	
	QueryResult = Query.ExecuteBatch();
	
	SelectionDetailRecords = QueryResult[2].Select();
	
	// Create the accumulation register records set POSSummary.
	RecordSetPOSSummary = AccumulationRegisters.POSSummary.CreateRecordSet();
	RecordSetPOSSummary.Filter.Recorder.Set(Ref);
	
	// Create the accumulation register records set IncomeAndExpensesAccounting.
	RecordSetIncomeAndExpenses = AccumulationRegisters.IncomeAndExpenses.CreateRecordSet();
	RecordSetIncomeAndExpenses.Filter.Recorder.Set(Ref);
	
	RecordSetAccountingJournalEntries = AccountingRegisters.AccountingJournalEntries.CreateRecordSet();
	RecordSetAccountingJournalEntries.Filter.Recorder.Set(Ref);
	
	While SelectionDetailRecords.Next() Do
		
		If Round(SelectionDetailRecords.CorrectionAmount, 2) = 0 Then
			Continue;
		EndIf;
		
		// Movements on the register POSSummary.
		NewRow = RecordSetPOSSummary.Add();
		NewRow.Period = Date;
		NewRow.RecordType = AccumulationRecordType.Expense;
		NewRow.Recorder = Ref;
		NewRow.Company = SelectionDetailRecords.Company;
		NewRow.StructuralUnit = SelectionDetailRecords.StructuralUnit;
		NewRow.Currency = SelectionDetailRecords.SalesDocumentStructuralUnitPriceTypeRetailCurrencyPrices;
		NewRow.ContentOfAccountingRecord = NStr("en = 'Cost'");
		NewRow.Cost = SelectionDetailRecords.CorrectionAmount;
		
		// Movements on the register IncomeAndExpenses.
		NewRow = RecordSetIncomeAndExpenses.Add();
		NewRow.Period = Date;
		NewRow.Recorder = Ref;
		NewRow.Company = SelectionDetailRecords.Company;
		NewRow.StructuralUnit = SelectionDetailRecords.DocumentSalesUnit;
		NewRow.BusinessLine = SelectionDetailRecords.DocumentSalesBusinessLine;
		NewRow.GLAccount = SelectionDetailRecords.DocumentSalesBusinessLineGLAccountCost;
		NewRow.AmountExpense = SelectionDetailRecords.CorrectionAmount;
		NewRow.ContentOfAccountingRecord = NStr("en = 'Record expenses'");
		
		// Movements by register AccountingJournalEntries.
		NewRow = RecordSetAccountingJournalEntries.Add();
		NewRow.Period = Date;
		NewRow.Recorder = Ref;
		NewRow.Company = SelectionDetailRecords.Company;
		NewRow.PlanningPeriod = Catalogs.PlanningPeriods.Actual;
		NewRow.AccountDr = SelectionDetailRecords.DocumentSalesBusinessLineGLAccountCost;
		NewRow.AccountCr = SelectionDetailRecords.DocumentSalesUnitAccountStructureInRetail;
		NewRow.Content = NStr("en = 'Cost'");
		NewRow.Amount = SelectionDetailRecords.CorrectionAmount;
		
		// Movements by register AccountingJournalEntries.
		NewRow = RecordSetAccountingJournalEntries.Add();
		NewRow.Period = Date;
		NewRow.Recorder = Ref;
		NewRow.Company = SelectionDetailRecords.Company;
		NewRow.PlanningPeriod = Catalogs.PlanningPeriods.Actual;
		NewRow.AccountDr = SelectionDetailRecords.DocumentSalesUnitAccountStructureInRetail;
		NewRow.AccountCr = SelectionDetailRecords.DocumentSalesUnitStructureMarkupAccount;
		NewRow.Content = NStr("en = 'Markup'");
		NewRow.Amount = - SelectionDetailRecords.CorrectionAmount;
		
	EndDo;
	
	RecordSetIncomeAndExpenses.Write(False);
	RecordSetPOSSummary.Write(False);
	RecordSetAccountingJournalEntries.Write(False);
	
EndProcedure

#EndRegion

#Region ExchangeDifferencesCalculation

Procedure CalculateExchangeDifferences(Cancel, ErrorsTable)
	
	RecordSetCashAssets = AccumulationRegisters.CashAssets.CreateRecordSet();
	RecordSetCashAssets.Filter.Recorder.Set(Ref);
	
	RecordSetCashAssetsInCashRegisters = AccumulationRegisters.CashInCashRegisters.CreateRecordSet();
	RecordSetCashAssetsInCashRegisters.Filter.Recorder.Set(Ref);
	
	RecordSetPayroll = AccumulationRegisters.Payroll.CreateRecordSet();
	RecordSetPayroll.Filter.Recorder.Set(Ref);
	
	RecordSetSettlementsWithAdvanceHolders = AccumulationRegisters.AdvanceHolders.CreateRecordSet();
	RecordSetSettlementsWithAdvanceHolders.Filter.Recorder.Set(Ref);
	
	RecordSetSettlementsWithBuyers = AccumulationRegisters.AccountsReceivable.CreateRecordSet();
	RecordSetSettlementsWithBuyers.Filter.Recorder.Set(Ref);
	
	RecordSetSettlementsWithSuppliers = AccumulationRegisters.AccountsPayable.CreateRecordSet();
	RecordSetSettlementsWithSuppliers.Filter.Recorder.Set(Ref);
	
	RecordSetIncomeAndExpenses = AccumulationRegisters.IncomeAndExpenses.CreateRecordSet();
	RecordSetIncomeAndExpenses.Filter.Recorder.Set(Ref);
	
	RecordSetForeignExchangeGainsAndLosses = InformationRegisters.ForeignExchangeGainsAndLosses.CreateRecordSet();
	RecordSetForeignExchangeGainsAndLosses.Filter.Recorder.Set(Ref);
	
	RecordSetAccountingJournalEntries = AccountingRegisters.AccountingJournalEntries.CreateRecordSet();
	RecordSetAccountingJournalEntries.Filter.Recorder.Set(Ref);
	
	Query = New Query;
	
	Query.SetParameter("Date",							Date);
	Query.SetParameter("Ref",							Ref);
	Query.SetParameter("DateEnd",						AdditionalProperties.ForPosting.EndDatePeriod);
	Query.SetParameter("Company",						AdditionalProperties.ForPosting.Company);
	Query.SetParameter("ExchangeDifference",			NStr("en = 'Foreign currency exchange gains and losses'"));
	Query.SetParameter("ForeignCurrencyExchangeGain",	Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeGain")); 
	Query.SetParameter("ForeignCurrencyExchangeLoss",	Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeLoss"));
	
	// Cash assets.
	Query.Text =
	"SELECT
	|	TableBalances.Company AS Company,
	|	&Date AS Period,
	|	&Ref AS Recorder,
	|	TableBalances.CashAssetsType AS CashAssetsType,
	|	TableBalances.BankAccountPettyCash AS BankAccountPettyCash,
	|	TableBalances.Currency AS Currency,
	|	TableBalances.AmountBalance AS AmountBalance,
	|	TableBalances.AmountCurBalance AS AmountCurBalance,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyExchangeRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN VALUE(AccumulationRecordType.Receipt)
	|		ELSE VALUE(AccumulationRecordType.Expense)
	|	END AS RecordKindAccountingJournalEntries,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyExchangeRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyExchangeRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0)
	|		ELSE -(ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyExchangeRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0))
	|	END AS Amount,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyExchangeRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN VALUE(Catalog.CashFlowItems.PositiveExchangeDifference)
	|		ELSE VALUE(Catalog.CashFlowItems.NegativeExchangeDifference)
	|	END AS Item,
	|	&ExchangeDifference AS ContentOfAccountingRecord,
	|	UNDEFINED AS StructuralUnit,
	|	VALUE(Catalog.LinesOfBusiness.Other) AS BusinessLine,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyExchangeRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyExchangeRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0)
	|		ELSE 0
	|	END AS AmountIncome,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyExchangeRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN 0
	|		ELSE -(ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyExchangeRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0))
	|	END AS AmountExpense,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyExchangeRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN &ForeignCurrencyExchangeGain
	|		ELSE &ForeignCurrencyExchangeLoss
	|	END AS GLAccount,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyExchangeRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN TableBalances.BankAccountPettyCash.GLAccount
	|		ELSE &ForeignCurrencyExchangeLoss
	|	END AS AccountDr,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyExchangeRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN &ForeignCurrencyExchangeGain
	|		ELSE TableBalances.BankAccountPettyCash.GLAccount
	|	END AS AccountCr,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyExchangeRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) > 0
	|				AND TableBalances.BankAccountPettyCash.GLAccount.Currency
	|			THEN TableBalances.Currency
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyExchangeRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) < 0
	|				AND TableBalances.BankAccountPettyCash.GLAccount.Currency
	|			THEN TableBalances.Currency
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	&ExchangeDifference AS Content
	|FROM
	|	AccumulationRegister.CashAssets.Balance(&DateEnd, Company = &Company) AS TableBalances
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(
	|				&DateEnd,
	|				Currency In
	|					(SELECT
	|						Constants.PresentationCurrency
	|					FROM
	|						Constants AS Constants)) AS AccountingExchangeRatesSliceLast
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&DateEnd, ) AS CurrencyExchangeRatesBankAccountPettyCashSliceLast
	|		ON TableBalances.Currency = CurrencyExchangeRatesBankAccountPettyCashSliceLast.Currency
	|WHERE
	|	TableBalances.AmountCurBalance * CurrencyExchangeRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRatesBankAccountPettyCashSliceLast.Multiplicity) <> TableBalances.AmountBalance
	|	AND (TableBalances.AmountCurBalance * CurrencyExchangeRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRatesBankAccountPettyCashSliceLast.Multiplicity) - TableBalances.AmountBalance >= 0.005
	|			OR TableBalances.AmountCurBalance * CurrencyExchangeRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRatesBankAccountPettyCashSliceLast.Multiplicity) - TableBalances.AmountBalance <= -0.005)";
 
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	While SelectionDetailRecords.Next() Do
		
		If Round(SelectionDetailRecords.Amount, 2) = 0 Then
			Continue;
		EndIf;
		
		// Movements by registers.
		NewRow = RecordSetCashAssets.Add();
		FillPropertyValues(NewRow, SelectionDetailRecords);
		NewRow.RecordType = SelectionDetailRecords.RecordKindAccountingJournalEntries;
		NewRow = RecordSetIncomeAndExpenses.Add();
		FillPropertyValues(NewRow, SelectionDetailRecords);
		NewRow = RecordSetAccountingJournalEntries.Add();
		FillPropertyValues(NewRow, SelectionDetailRecords);
		NewRow = RecordSetForeignExchangeGainsAndLosses.Add();
		FillPropertyValues(NewRow, SelectionDetailRecords);
		NewRow.Amount = ?(SelectionDetailRecords.RecordKindAccountingJournalEntries = AccumulationRecordType.Receipt, NewRow.Amount, -NewRow.Amount);
		NewRow.Analytics = "" + SelectionDetailRecords.BankAccountPettyCash;
		NewRow.Section = "Cash assets";
		
	EndDo;
	
	// Cash assets in CR receipts.
	Query.Text =
	"SELECT
	|	TableBalances.Company AS Company,
	|	&Date AS Period,
	|	&Ref AS Recorder,
	|	TableBalances.CashCR AS CashCR,
	|	TableBalances.CashCR.CashCurrency AS Currency,
	|	TableBalances.AmountBalance AS AmountBalance,
	|	TableBalances.AmountCurBalance AS AmountCurBalance,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyExchangeRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN VALUE(AccumulationRecordType.Receipt)
	|		ELSE VALUE(AccumulationRecordType.Expense)
	|	END AS RecordKindAccountingJournalEntries,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyExchangeRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyExchangeRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0)
	|		ELSE -(ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyExchangeRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0))
	|	END AS Amount,
	|	&ExchangeDifference AS ContentOfAccountingRecord,
	|	UNDEFINED AS StructuralUnit,
	|	VALUE(Catalog.LinesOfBusiness.Other) AS BusinessLine,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyExchangeRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyExchangeRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0)
	|		ELSE 0
	|	END AS AmountIncome,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyExchangeRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN 0
	|		ELSE -(ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyExchangeRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0))
	|	END AS AmountExpense,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyExchangeRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN &ForeignCurrencyExchangeGain
	|		ELSE &ForeignCurrencyExchangeLoss
	|	END AS GLAccount,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyExchangeRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN TableBalances.CashCR.GLAccount
	|		ELSE &ForeignCurrencyExchangeLoss
	|	END AS AccountDr,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyExchangeRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN &ForeignCurrencyExchangeGain
	|		ELSE TableBalances.CashCR.GLAccount
	|	END AS AccountCr,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyExchangeRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) > 0
	|				AND TableBalances.CashCR.GLAccount.Currency
	|			THEN TableBalances.CashCR.CashCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyExchangeRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) < 0
	|				AND TableBalances.CashCR.GLAccount.Currency
	|			THEN TableBalances.CashCR.CashCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	&ExchangeDifference AS Content
	|FROM
	|	AccumulationRegister.CashInCashRegisters.Balance(&DateEnd, Company = &Company) AS TableBalances
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(
	|				&DateEnd,
	|				Currency In
	|					(SELECT
	|						Constants.PresentationCurrency
	|					FROM
	|						Constants AS Constants)) AS AccountingExchangeRatesSliceLast
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&DateEnd, ) AS CurrencyExchangeRatesBankAccountPettyCashSliceLast
	|		ON TableBalances.CashCR.CashCurrency = CurrencyExchangeRatesBankAccountPettyCashSliceLast.Currency
	|WHERE
	|	TableBalances.AmountCurBalance * CurrencyExchangeRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRatesBankAccountPettyCashSliceLast.Multiplicity) <> TableBalances.AmountBalance
	|	AND (TableBalances.AmountCurBalance * CurrencyExchangeRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRatesBankAccountPettyCashSliceLast.Multiplicity) - TableBalances.AmountBalance >= 0.005
	|			OR TableBalances.AmountCurBalance * CurrencyExchangeRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRatesBankAccountPettyCashSliceLast.Multiplicity) - TableBalances.AmountBalance <= -0.005)";
	
	Query.SetParameter("ForeignCurrencyExchangeGain", Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeGain")); 
	Query.SetParameter("ForeignCurrencyExchangeLoss", Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeLoss")); 

	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	While SelectionDetailRecords.Next() Do
		
		If Round(SelectionDetailRecords.Amount, 2) = 0 Then
			Continue;
		EndIf;
		
		// Movements by registers.
		NewRow = RecordSetCashAssetsInCashRegisters.Add();
		FillPropertyValues(NewRow, SelectionDetailRecords);
		NewRow.RecordType = SelectionDetailRecords.RecordKindAccountingJournalEntries;
		NewRow = RecordSetIncomeAndExpenses.Add();
		FillPropertyValues(NewRow, SelectionDetailRecords);
		NewRow = RecordSetAccountingJournalEntries.Add();
		FillPropertyValues(NewRow, SelectionDetailRecords);
		NewRow = RecordSetForeignExchangeGainsAndLosses.Add();
		FillPropertyValues(NewRow, SelectionDetailRecords);
		NewRow.Amount = ?(SelectionDetailRecords.RecordKindAccountingJournalEntries = AccumulationRecordType.Receipt, NewRow.Amount, -NewRow.Amount);
		NewRow.Analytics = "" + SelectionDetailRecords.CashCR;
		NewRow.Section = "Cash in cash registers";
		
	EndDo;
	
	// Staff payables.
	Query.Text =
	"SELECT
	|	TableBalances.Company AS Company,
	|	&Date AS Period,
	|	&Ref AS Recorder,
	|	TableBalances.StructuralUnit AS StructuralUnit,
	|	TableBalances.Employee AS Employee,
	|	TableBalances.Employee.Code AS EmployeeCode,
	|	TableBalances.Currency AS Currency,
	|	TableBalances.RegistrationPeriod AS RegistrationPeriod,
	|	TableBalances.AmountBalance AS AmountBalance,
	|	TableBalances.AmountCurBalance AS AmountCurBalance,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyExchangeRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN VALUE(AccumulationRecordType.Receipt)
	|		ELSE VALUE(AccumulationRecordType.Expense)
	|	END AS RecordKindAccountingJournalEntries,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyExchangeRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyExchangeRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0)
	|		ELSE -(ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyExchangeRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0))
	|	END AS Amount,
	|	&ExchangeDifference AS ContentOfAccountingRecord,
	|	VALUE(Catalog.LinesOfBusiness.Other) AS BusinessLine,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyExchangeRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN 0
	|		ELSE -(ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyExchangeRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0))
	|	END AS AmountIncome,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyExchangeRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyExchangeRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0)
	|		ELSE 0
	|	END AS AmountExpense,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyExchangeRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN &ForeignCurrencyExchangeLoss
	|		ELSE &ForeignCurrencyExchangeGain
	|	END AS GLAccount,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyExchangeRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN &ForeignCurrencyExchangeLoss
	|		ELSE TableBalances.Employee.SettlementsHumanResourcesGLAccount
	|	END AS AccountDr,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyExchangeRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN TableBalances.Employee.SettlementsHumanResourcesGLAccount
	|		ELSE &ForeignCurrencyExchangeGain
	|	END AS AccountCr,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyExchangeRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) < 0
	|				AND TableBalances.Employee.SettlementsHumanResourcesGLAccount.Currency
	|			THEN TableBalances.Currency
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyExchangeRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) > 0
	|				AND TableBalances.Employee.SettlementsHumanResourcesGLAccount.Currency
	|			THEN TableBalances.Currency
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	&ExchangeDifference AS Content
	|FROM
	|	AccumulationRegister.Payroll.Balance(&DateEnd, Company = &Company) AS TableBalances
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(
	|				&DateEnd,
	|				Currency In
	|					(SELECT
	|						Constants.PresentationCurrency
	|					FROM
	|						Constants AS Constants)) AS AccountingExchangeRatesSliceLast
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&DateEnd, ) AS CurrencyExchangeRatesBankAccountPettyCashSliceLast
	|		ON TableBalances.Currency = CurrencyExchangeRatesBankAccountPettyCashSliceLast.Currency
	|WHERE
	|	TableBalances.AmountCurBalance * CurrencyExchangeRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRatesBankAccountPettyCashSliceLast.Multiplicity) <> TableBalances.AmountBalance
	|	AND (TableBalances.AmountCurBalance * CurrencyExchangeRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRatesBankAccountPettyCashSliceLast.Multiplicity) - TableBalances.AmountBalance >= 0.005
	|			OR TableBalances.AmountCurBalance * CurrencyExchangeRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRatesBankAccountPettyCashSliceLast.Multiplicity) - TableBalances.AmountBalance <= -0.005)";
	
	Query.SetParameter("ForeignCurrencyExchangeGain", Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeGain")); 
	Query.SetParameter("ForeignCurrencyExchangeLoss", Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeLoss"));
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	While SelectionDetailRecords.Next() Do
		
		If Round(SelectionDetailRecords.Amount, 2) = 0 Then
			Continue;
		EndIf;
		
		// Movements by registers.
		NewRow = RecordSetPayroll.Add();
		FillPropertyValues(NewRow, SelectionDetailRecords);
		NewRow.RecordType = SelectionDetailRecords.RecordKindAccountingJournalEntries;
		NewRow = RecordSetIncomeAndExpenses.Add();
		FillPropertyValues(NewRow, SelectionDetailRecords);
		NewRow.StructuralUnit = Undefined;
		NewRow = RecordSetAccountingJournalEntries.Add();
		FillPropertyValues(NewRow, SelectionDetailRecords);
		NewRow = RecordSetForeignExchangeGainsAndLosses.Add();
		FillPropertyValues(NewRow, SelectionDetailRecords);
		NewRow.Amount = ?(SelectionDetailRecords.RecordKindAccountingJournalEntries = AccumulationRecordType.Receipt, NewRow.Amount, -NewRow.Amount);
		NewRow.Analytics = 
			""
		  + SelectionDetailRecords.Employee + " (" + SelectionDetailRecords.EmployeeCode + ")"
		  + " / "
		  + SelectionDetailRecords.StructuralUnit
		  + " / "
		  + Format(SelectionDetailRecords.RegistrationPeriod, "DF='MMMM yyyy'")+ " g.";
		NewRow.Section = "Personnel settlements";
		
	EndDo;
	
	// Advance holder payments.
	Query.Text =
	"SELECT
	|	TableBalances.Company AS Company,
	|	&Date AS Period,
	|	&Ref AS Recorder,
	|	TableBalances.Employee AS Employee,
	|	TableBalances.Document AS Document,
	|	TableBalances.Currency AS Currency,
	|	TableBalances.AmountBalance AS AmountBalance,
	|	TableBalances.AmountCurBalance AS AmountCurBalance,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyExchangeRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN VALUE(AccumulationRecordType.Receipt)
	|		ELSE VALUE(AccumulationRecordType.Expense)
	|	END AS RecordKindAccountingJournalEntries,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyExchangeRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyExchangeRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0)
	|		ELSE -(ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyExchangeRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0))
	|	END AS Amount,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyExchangeRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN VALUE(Catalog.CashFlowItems.PositiveExchangeDifference)
	|		ELSE VALUE(Catalog.CashFlowItems.NegativeExchangeDifference)
	|	END AS Item,
	|	&ExchangeDifference AS ContentOfAccountingRecord,
	|	UNDEFINED AS StructuralUnit,
	|	VALUE(Catalog.LinesOfBusiness.Other) AS BusinessLine,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyExchangeRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyExchangeRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0)
	|		ELSE 0
	|	END AS AmountIncome,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyExchangeRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN 0
	|		ELSE -(ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyExchangeRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0))
	|	END AS AmountExpense,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyExchangeRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN &ForeignCurrencyExchangeGain
	|		ELSE &ForeignCurrencyExchangeLoss
	|	END AS GLAccount,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyExchangeRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN CASE
	|					WHEN ISNULL(TableBalances.AmountCurBalance, 0) > 0
	|						THEN TableBalances.Employee.AdvanceHoldersGLAccount
	|					ELSE TableBalances.Employee.OverrunGLAccount
	|				END
	|		ELSE &ForeignCurrencyExchangeLoss
	|	END AS AccountDr,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyExchangeRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN &ForeignCurrencyExchangeGain
	|		ELSE CASE
	|				WHEN ISNULL(TableBalances.AmountCurBalance, 0) > 0
	|					THEN TableBalances.Employee.AdvanceHoldersGLAccount
	|				ELSE TableBalances.Employee.OverrunGLAccount
	|			END
	|	END AS AccountCr,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyExchangeRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) > 0
	|				AND CASE
	|					WHEN ISNULL(TableBalances.AmountCurBalance, 0) > 0
	|						THEN TableBalances.Employee.AdvanceHoldersGLAccount.Currency
	|					ELSE TableBalances.Employee.OverrunGLAccount.Currency
	|				END
	|			THEN TableBalances.Currency
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyExchangeRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) < 0
	|				AND CASE
	|					WHEN ISNULL(TableBalances.AmountCurBalance, 0) > 0
	|						THEN TableBalances.Employee.AdvanceHoldersGLAccount.Currency
	|					ELSE TableBalances.Employee.OverrunGLAccount.Currency
	|				END
	|			THEN TableBalances.Currency
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	&ExchangeDifference AS Content
	|FROM
	|	AccumulationRegister.AdvanceHolders.Balance(&DateEnd, Company = &Company) AS TableBalances
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(
	|				&DateEnd,
	|				Currency In
	|					(SELECT
	|						Constants.PresentationCurrency
	|					FROM
	|						Constants AS Constants)) AS AccountingExchangeRatesSliceLast
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&DateEnd, ) AS CurrencyExchangeRatesBankAccountPettyCashSliceLast
	|		ON TableBalances.Currency = CurrencyExchangeRatesBankAccountPettyCashSliceLast.Currency
	|WHERE
	|	TableBalances.AmountCurBalance * CurrencyExchangeRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRatesBankAccountPettyCashSliceLast.Multiplicity) <> TableBalances.AmountBalance
	|	AND (TableBalances.AmountCurBalance * CurrencyExchangeRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRatesBankAccountPettyCashSliceLast.Multiplicity) - TableBalances.AmountBalance >= 0.005
	|			OR TableBalances.AmountCurBalance * CurrencyExchangeRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRatesBankAccountPettyCashSliceLast.Multiplicity) - TableBalances.AmountBalance <= -0.005)";
	
	Query.SetParameter("ForeignCurrencyExchangeGain", Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeGain")); 
	Query.SetParameter("ForeignCurrencyExchangeLoss", Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeLoss"));

	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	While SelectionDetailRecords.Next() Do
		
		If Round(SelectionDetailRecords.Amount, 2) = 0 Then
			Continue;
		EndIf;
		
		// Movements by registers.
		NewRow = RecordSetSettlementsWithAdvanceHolders.Add();
		FillPropertyValues(NewRow, SelectionDetailRecords);
		NewRow.RecordType = SelectionDetailRecords.RecordKindAccountingJournalEntries;
		NewRow = RecordSetIncomeAndExpenses.Add();
		FillPropertyValues(NewRow, SelectionDetailRecords);
		NewRow = RecordSetAccountingJournalEntries.Add();
		FillPropertyValues(NewRow, SelectionDetailRecords);
		NewRow = RecordSetForeignExchangeGainsAndLosses.Add();
		FillPropertyValues(NewRow, SelectionDetailRecords);
		NewRow.Amount = ?(SelectionDetailRecords.RecordKindAccountingJournalEntries = AccumulationRecordType.Receipt, NewRow.Amount, -NewRow.Amount);
		NewRow.Analytics =
			""
		  + SelectionDetailRecords.Employee
		  + " / "
		  + SelectionDetailRecords.Document;
		NewRow.Section = "Settlements with advance holders";
		
	EndDo;
	
	// Accounts receivable.
	Query.Text =
	"SELECT
	|	TableBalances.Company AS Company,
	|	&Date AS Period,
	|	&Ref AS Recorder,
	|	TableBalances.SettlementsType AS SettlementsType,
	|	TableBalances.Counterparty AS Counterparty,
	|	TableBalances.Contract AS Contract,
	|	TableBalances.Document AS Document,
	|	TableBalances.Order AS Order,
	|	TableBalances.AmountBalance AS AmountBalance,
	|	TableBalances.AmountCurBalance AS AmountCurBalance,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyExchangeRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN VALUE(AccumulationRecordType.Receipt)
	|		ELSE VALUE(AccumulationRecordType.Expense)
	|	END AS RecordKindAccountingJournalEntries,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyExchangeRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyExchangeRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0)
	|		ELSE -(ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyExchangeRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0))
	|	END AS Amount,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyExchangeRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN VALUE(Catalog.CashFlowItems.PositiveExchangeDifference)
	|		ELSE VALUE(Catalog.CashFlowItems.NegativeExchangeDifference)
	|	END AS Item,
	|	&ExchangeDifference AS ContentOfAccountingRecord,
	|	UNDEFINED AS StructuralUnit,
	|	VALUE(Catalog.LinesOfBusiness.Other) AS BusinessLine,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyExchangeRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyExchangeRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0)
	|		ELSE 0
	|	END AS AmountIncome,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyExchangeRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN 0
	|		ELSE -(ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyExchangeRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0))
	|	END AS AmountExpense,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyExchangeRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN &ForeignCurrencyExchangeGain
	|		ELSE &ForeignCurrencyExchangeLoss
	|	END AS GLAccount,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyExchangeRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN CASE
	|					WHEN TableBalances.SettlementsType = VALUE(Enum.SettlementsTypes.Debt)
	|						THEN TableBalances.Counterparty.GLAccountCustomerSettlements
	|					ELSE TableBalances.Counterparty.CustomerAdvancesGLAccount
	|				END
	|		ELSE &ForeignCurrencyExchangeLoss
	|	END AS AccountDr,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyExchangeRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN &ForeignCurrencyExchangeGain
	|		ELSE CASE
	|				WHEN TableBalances.SettlementsType = VALUE(Enum.SettlementsTypes.Debt)
	|					THEN TableBalances.Counterparty.GLAccountCustomerSettlements
	|				ELSE TableBalances.Counterparty.CustomerAdvancesGLAccount
	|			END
	|	END AS AccountCr,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyExchangeRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) > 0
	|				AND CASE
	|					WHEN TableBalances.SettlementsType = VALUE(Enum.SettlementsTypes.Debt)
	|						THEN TableBalances.Counterparty.GLAccountCustomerSettlements.Currency
	|					ELSE TableBalances.Counterparty.CustomerAdvancesGLAccount.Currency
	|				END
	|			THEN TableBalances.Contract.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyExchangeRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) < 0
	|				AND CASE
	|					WHEN TableBalances.SettlementsType = VALUE(Enum.SettlementsTypes.Debt)
	|						THEN TableBalances.Counterparty.GLAccountCustomerSettlements.Currency
	|					ELSE TableBalances.Counterparty.CustomerAdvancesGLAccount.Currency
	|				END
	|			THEN TableBalances.Contract.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	&ExchangeDifference AS Content
	|FROM
	|	AccumulationRegister.AccountsReceivable.Balance(
	|			&DateEnd,
	|			Company = &Company
	|				AND SettlementsType = VALUE(Enum.SettlementsTypes.Debt)) AS TableBalances
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(
	|				&DateEnd,
	|				Currency In
	|					(SELECT
	|						Constants.PresentationCurrency
	|					FROM
	|						Constants AS Constants)) AS AccountingExchangeRatesSliceLast
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&DateEnd, ) AS CurrencyExchangeRatesBankAccountPettyCashSliceLast
	|		ON TableBalances.Contract.SettlementsCurrency = CurrencyExchangeRatesBankAccountPettyCashSliceLast.Currency
	|WHERE
	|	TableBalances.AmountCurBalance * CurrencyExchangeRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRatesBankAccountPettyCashSliceLast.Multiplicity) <> TableBalances.AmountBalance
	|	AND (TableBalances.AmountCurBalance * CurrencyExchangeRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRatesBankAccountPettyCashSliceLast.Multiplicity) - TableBalances.AmountBalance >= 0.005
	|			OR TableBalances.AmountCurBalance * CurrencyExchangeRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRatesBankAccountPettyCashSliceLast.Multiplicity) - TableBalances.AmountBalance <= -0.005)";
	
	Query.SetParameter("ForeignCurrencyExchangeGain", Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeGain")); 
	Query.SetParameter("ForeignCurrencyExchangeLoss", Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeLoss"));
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	While SelectionDetailRecords.Next() Do
		
		If Round(SelectionDetailRecords.Amount, 2) = 0 Then
			Continue;
		EndIf;
		
		// Movements by registers.
		NewRow = RecordSetSettlementsWithBuyers.Add();
		FillPropertyValues(NewRow, SelectionDetailRecords);
		If Not ValueIsFilled(NewRow.Order) Then
			NewRow.Order = Undefined;
		EndIf;
		NewRow.RecordType = SelectionDetailRecords.RecordKindAccountingJournalEntries;
		
		NewRow = RecordSetIncomeAndExpenses.Add();
		FillPropertyValues(NewRow, SelectionDetailRecords);
		
		NewRow = RecordSetAccountingJournalEntries.Add();
		FillPropertyValues(NewRow, SelectionDetailRecords);
		
		NewRow = RecordSetForeignExchangeGainsAndLosses.Add();
		FillPropertyValues(NewRow, SelectionDetailRecords);
		NewRow.Currency = SelectionDetailRecords.Contract.SettlementsCurrency;
		NewRow.Amount = ?(SelectionDetailRecords.RecordKindAccountingJournalEntries = AccumulationRecordType.Receipt, NewRow.Amount, - NewRow.Amount);
		NewRow.Analytics =
			""
		  + SelectionDetailRecords.Counterparty
		  + " / "
		  + SelectionDetailRecords.Contract
		  + " / "
		  + SelectionDetailRecords.Document
		  + " / "
		  + SelectionDetailRecords.Order;
		NewRow.Section = NStr("en = 'Accounts receivable'");
		
	EndDo;
	
	// Accounts payable.
	Query.Text =
	"SELECT
	|	TableBalances.Company AS Company,
	|	&Date AS Period,
	|	&Ref AS Recorder,
	|	TableBalances.SettlementsType AS SettlementsType,
	|	TableBalances.Counterparty AS Counterparty,
	|	TableBalances.Contract AS Contract,
	|	TableBalances.Document AS Document,
	|	TableBalances.Order AS Order,
	|	TableBalances.AmountBalance AS AmountBalance,
	|	TableBalances.AmountCurBalance AS AmountCurBalance,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyExchangeRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN VALUE(AccumulationRecordType.Receipt)
	|		ELSE VALUE(AccumulationRecordType.Expense)
	|	END AS RecordKindAccountingJournalEntries,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyExchangeRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyExchangeRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0)
	|		ELSE -(ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyExchangeRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0))
	|	END AS Amount,
	|	&ExchangeDifference AS ContentOfAccountingRecord,
	|	VALUE(Catalog.LinesOfBusiness.Other) AS BusinessLine,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyExchangeRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN 0
	|		ELSE -(ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyExchangeRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0))
	|	END AS AmountIncome,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyExchangeRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyExchangeRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0)
	|		ELSE 0
	|	END AS AmountExpense,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyExchangeRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN &ForeignCurrencyExchangeLoss
	|		ELSE &ForeignCurrencyExchangeGain
	|	END AS GLAccount,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyExchangeRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN &ForeignCurrencyExchangeLoss
	|		ELSE CASE
	|				WHEN TableBalances.SettlementsType = VALUE(Enum.SettlementsTypes.Debt)
	|					THEN TableBalances.Counterparty.GLAccountVendorSettlements
	|				ELSE TableBalances.Counterparty.VendorAdvancesGLAccount
	|			END
	|	END AS AccountDr,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyExchangeRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN CASE
	|					WHEN TableBalances.SettlementsType = VALUE(Enum.SettlementsTypes.Debt)
	|						THEN TableBalances.Counterparty.GLAccountVendorSettlements
	|					ELSE TableBalances.Counterparty.VendorAdvancesGLAccount
	|				END
	|		ELSE &ForeignCurrencyExchangeGain
	|	END AS AccountCr,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyExchangeRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) < 0
	|				AND CASE
	|					WHEN TableBalances.SettlementsType = VALUE(Enum.SettlementsTypes.Debt)
	|						THEN TableBalances.Counterparty.GLAccountVendorSettlements.Currency
	|					ELSE TableBalances.Counterparty.VendorAdvancesGLAccount.Currency
	|				END
	|			THEN TableBalances.Contract.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyExchangeRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) > 0
	|				AND CASE
	|					WHEN TableBalances.SettlementsType = VALUE(Enum.SettlementsTypes.Debt)
	|						THEN TableBalances.Counterparty.GLAccountVendorSettlements.Currency
	|					ELSE TableBalances.Counterparty.VendorAdvancesGLAccount.Currency
	|				END
	|			THEN TableBalances.Contract.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	&ExchangeDifference AS Content,
	|	CASE
	|		WHEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyExchangeRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) > 0
	|			THEN ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyExchangeRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0)
	|		ELSE -(ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyExchangeRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0))
	|	END AS AmountForPayment
	|FROM
	|	AccumulationRegister.AccountsPayable.Balance(
	|			&DateEnd,
	|			Company = &Company
	|				AND SettlementsType = VALUE(Enum.SettlementsTypes.Debt)) AS TableBalances
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(
	|				&DateEnd,
	|				Currency IN
	|					(SELECT
	|						Constants.PresentationCurrency
	|					FROM
	|						Constants AS Constants)) AS AccountingExchangeRatesSliceLast
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&DateEnd, ) AS CurrencyExchangeRatesBankAccountPettyCashSliceLast
	|		ON TableBalances.Contract.SettlementsCurrency = CurrencyExchangeRatesBankAccountPettyCashSliceLast.Currency
	|WHERE
	|	TableBalances.AmountCurBalance * CurrencyExchangeRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRatesBankAccountPettyCashSliceLast.Multiplicity) <> TableBalances.AmountBalance
	|	AND (TableBalances.AmountCurBalance * CurrencyExchangeRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRatesBankAccountPettyCashSliceLast.Multiplicity) - TableBalances.AmountBalance >= 0.005
	|			OR TableBalances.AmountCurBalance * CurrencyExchangeRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRatesBankAccountPettyCashSliceLast.Multiplicity) - TableBalances.AmountBalance <= -0.005)";
	
	Query.SetParameter("ForeignCurrencyExchangeGain", Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeGain")); 
	Query.SetParameter("ForeignCurrencyExchangeLoss", Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeLoss"));
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	While SelectionDetailRecords.Next() Do
		
		If Round(SelectionDetailRecords.Amount, 2) = 0 Then
			Continue;
		EndIf;
		
		// Movements by registers.
		NewRow = RecordSetSettlementsWithSuppliers.Add();
		FillPropertyValues(NewRow, SelectionDetailRecords);
		NewRow.RecordType = SelectionDetailRecords.RecordKindAccountingJournalEntries;
		NewRow = RecordSetIncomeAndExpenses.Add();
		FillPropertyValues(NewRow, SelectionDetailRecords);
		NewRow = RecordSetAccountingJournalEntries.Add();
		FillPropertyValues(NewRow, SelectionDetailRecords);
		NewRow = RecordSetForeignExchangeGainsAndLosses.Add();
		FillPropertyValues(NewRow, SelectionDetailRecords);
		NewRow.Currency = SelectionDetailRecords.Contract.SettlementsCurrency;
		NewRow.Amount = ?(SelectionDetailRecords.RecordKindAccountingJournalEntries = AccumulationRecordType.Receipt, NewRow.Amount, -NewRow.Amount);
		NewRow.Analytics =
			""
		  + SelectionDetailRecords.Counterparty
		  + " / "
		  + SelectionDetailRecords.Contract
		  + " / "
		  + SelectionDetailRecords.Document
		  + " / "
		  + SelectionDetailRecords.Order;
		NewRow.Section = "Accounts payable";
		
	EndDo;
	
	// Write the rest of the records.
	RecordSetCashAssets.Write(False);
	RecordSetCashAssetsInCashRegisters.Write(False);
	RecordSetPayroll.Write(False);
	RecordSetSettlementsWithAdvanceHolders.Write(False);
	RecordSetSettlementsWithBuyers.Write(False);
	RecordSetSettlementsWithSuppliers.Write(False);
	RecordSetIncomeAndExpenses.Write(False);
	RecordsTable = RecordSetForeignExchangeGainsAndLosses.Unload();
	RecordsTable.GroupBy("Period, Active, Company, Analytics, Currency, Section", "Amount, AmountIncome, AmountExpense, AmountBalance, AmountCurBalance");
	RecordSetForeignExchangeGainsAndLosses.Load(RecordsTable);
	RecordSetForeignExchangeGainsAndLosses.Write(False);
	RecordSetAccountingJournalEntries.Write(False);
	
EndProcedure

#EndRegion

#Region VATPayableCalculation

// Calculates the VAT payable.
//
// Parameters:
//  Cancel			- Boolean - check box of document posting canceling.
//  ErrorsTable		- ValueTable - table of errors of document posting
//
Procedure CalculateVATPayable(Cancel, ErrorsTable)
	
	AccountVATOutput	= Catalogs.DefaultGLAccounts.GetDefaultGLAccount("VATOutput");
	AccountVATInput		= Catalogs.DefaultGLAccounts.GetDefaultGLAccount("VATInput");
	AccountVATPayable	= Catalogs.DefaultGLAccounts.GetDefaultGLAccount("TaxPayable");
	
	If ValueIsFilled(AccountVATOutput) AND ValueIsFilled(AccountVATInput) AND ValueIsFilled(AccountVATPayable) Then
		
		// 1) Balances of VAT Input and VAT Output
		
		Query = New Query;
		Query.Text =
		"SELECT
		|	AccountingJournalEntriesBalance.Account AS Account,
		|	AccountingJournalEntriesBalance.AmountBalance AS AmountBalance
		|FROM
		|	AccountingRegister.AccountingJournalEntries.Balance(&EndDate, Account IN (&VATInput, &VATOutput), Company = &Company) AS AccountingJournalEntriesBalance";
		
		Query.SetParameter("VATOutput",	AccountVATOutput);
		Query.SetParameter("VATInput",	AccountVATInput);
		Query.SetParameter("Company",	AdditionalProperties.ForPosting.Company);
		Query.SetParameter("EndDate",	AdditionalProperties.ForPosting.EndDatePeriod);
		
		QueryResult				= Query.Execute();
		SelectionQueryResult	= QueryResult.Select();
		
		BalanceVATInput	= 0;
		SearchStructure = New Structure("Account", AccountVATInput);
		If SelectionQueryResult.FindNext(SearchStructure) Then
			BalanceVATInput = SelectionQueryResult.AmountBalance;
		EndIf;
		
		BalanceVATOutput = 0;
		SearchStructure.Account = AccountVATOutput;
		SelectionQueryResult.Reset();
		If SelectionQueryResult.FindNext(SearchStructure) Then
			BalanceVATOutput = -SelectionQueryResult.AmountBalance;
		EndIf;
		
		// 2) Movements by registers AccountingJournalEntries and TaxPayable
		
		RecordSetAccountingJournalEntries = AccountingRegisters.AccountingJournalEntries.CreateRecordSet();
		RecordSetAccountingJournalEntries.Filter.Recorder.Set(Ref);
		
		RecordSetTaxPayable = AccumulationRegisters.TaxPayable.CreateRecordSet();
		RecordSetTaxPayable.Filter.Recorder.Set(Ref);
		
		If BalanceVATInput AND BalanceVATOutput Then
			
			NewRow					= RecordSetAccountingJournalEntries.Add();
			NewRow.Period			= Date;
			NewRow.Recorder			= Ref;
			NewRow.Company			= AdditionalProperties.ForPosting.Company;
			NewRow.PlanningPeriod	= Catalogs.PlanningPeriods.Actual;
			NewRow.AccountDr		= AccountVATOutput;
			NewRow.AccountCr		= AccountVATInput;
			NewRow.Amount			= Min(BalanceVATInput, BalanceVATOutput);
			NewRow.Content			= NStr("en = 'VAT payable'",CommonUseClientServer.MainLanguageCode());
			
		EndIf;
		
		If (BalanceVATOutput - BalanceVATInput) > 0 Then
			
			//AccountingJournalEntries
			NewRow					= RecordSetAccountingJournalEntries.Add();
			NewRow.Period			= Date;
			NewRow.Recorder			= Ref;
			NewRow.Company			= AdditionalProperties.ForPosting.Company;
			NewRow.PlanningPeriod	= Catalogs.PlanningPeriods.Actual;
			NewRow.AccountDr		= AccountVATOutput;
			NewRow.AccountCr		= AccountVATPayable;
			NewRow.Amount			= BalanceVATOutput - BalanceVATInput;
			NewRow.Content			= NStr("en = 'VAT due'",CommonUseClientServer.MainLanguageCode());
			
			//TaxPayable
			NewRow								= RecordSetTaxPayable.Add();
			NewRow.RecordType					= AccumulationRecordType.Receipt;
			NewRow.Period						= Date;
			NewRow.Company						= AdditionalProperties.ForPosting.Company;
			NewRow.TaxKind						= Catalogs.TaxTypes.VAT;
			NewRow.Amount						= BalanceVATOutput - BalanceVATInput;
			NewRow.ContentOfAccountingRecord	= NStr("en = 'VAT payable accrued'",CommonUseClientServer.MainLanguageCode());
		
		ElsIf (BalanceVATInput - BalanceVATOutput) > 0 Then
			
			//AccountingJournalEntries
			NewRow					= RecordSetAccountingJournalEntries.Add();
			NewRow.Period			= Date;
			NewRow.Recorder			= Ref;
			NewRow.Company			= AdditionalProperties.ForPosting.Company;
			NewRow.PlanningPeriod	= Catalogs.PlanningPeriods.Actual;
			NewRow.AccountDr		= AccountVATPayable;
			NewRow.AccountCr		= AccountVATInput;
			NewRow.Amount			= BalanceVATInput - BalanceVATOutput;
			NewRow.Content			= NStr("en = 'VAT due'",CommonUseClientServer.MainLanguageCode());
			
			//TaxPayable
			NewRow								= RecordSetTaxPayable.Add();
			NewRow.RecordType					= AccumulationRecordType.Expense;
			NewRow.Period						= Date;
			NewRow.Company						= AdditionalProperties.ForPosting.Company;
			NewRow.TaxKind						= Catalogs.TaxTypes.VAT;
			NewRow.Amount						= BalanceVATInput - BalanceVATOutput;
			NewRow.ContentOfAccountingRecord	= NStr("en = 'VAT payable accrued'",CommonUseClientServer.MainLanguageCode());
			
		EndIf;
		
		RecordSetAccountingJournalEntries.Write(False);
		
		RecordSetTaxPayable.Write();
		RecordSetTaxPayable.Clear();
		
	EndIf;
	
EndProcedure

#EndRegion

#Region Posting

// Adds additional attributes necessary for document
// posting to passed structure.
//
// Parameters:
//  StructureAdditionalProperties - Structure of additional document properties.
//
Procedure AddAttributesToAdditionalPropertiesForPosting(StructureAdditionalProperties)
	
	InitialPeriodBoundary	= New Boundary(BegOfMonth(Date), BoundaryType.Including);
	LastBoundaryPeriod		= New Boundary(EndOfMonth (Date), BoundaryType.Including);
	BeginOfPeriodningDate	= BegOfMonth(Date);
	EndDatePeriod			= EndOfMonth (Date);
	
	StructureAdditionalProperties.ForPosting.Insert("EmptyAccount",				ChartsOfAccounts.PrimaryChartOfAccounts.EmptyRef());	
	StructureAdditionalProperties.ForPosting.Insert("InitialPeriodBoundary",	InitialPeriodBoundary);
	StructureAdditionalProperties.ForPosting.Insert("LastBoundaryPeriod",		LastBoundaryPeriod);
	StructureAdditionalProperties.ForPosting.Insert("BeginOfPeriodningDate",	BeginOfPeriodningDate);
	StructureAdditionalProperties.ForPosting.Insert("EndDatePeriod",			EndDatePeriod);
	
EndProcedure

// Sets property of writing document records to
// the passed value for sets.
//
// Parameters:
//  RecordFlag   - Boolean, check box of permission to write record sets.
//
Procedure SetPropertiesOfDocumentRecordSets(RecordFlag)
	
	RegisterRecords.WriteOffCostAdjustment.Write = RecordFlag;
	RegisterRecords.Inventory.Write = RecordFlag;
	RegisterRecords.Sales.Write = RecordFlag;
	RegisterRecords.IncomeAndExpenses.Write = RecordFlag;
	RegisterRecords.AccountingJournalEntries.Write = RecordFlag;
	RegisterRecords.MonthEndErrors.Write = RecordFlag;
	RegisterRecords.ForeignExchangeGainsAndLosses.Write = RecordFlag;
	
EndProcedure

// Collapses the records set Income and expenses.
//
Procedure GroupRecordSetIncomeAndExpenses(RegisterRecordSet)
	
	Query = New Query();
	Query.Text = 
	"SELECT
	|	IncomeAndExpenses.Period,
	|	IncomeAndExpenses.Active,
	|	IncomeAndExpenses.Company,
	|	IncomeAndExpenses.StructuralUnit,
	|	IncomeAndExpenses.BusinessLine,
	|	IncomeAndExpenses.SalesOrder,
	|	IncomeAndExpenses.GLAccount,
	|	SUM(IncomeAndExpenses.AmountIncome) AS AmountIncome,
	|	SUM(IncomeAndExpenses.AmountExpense) AS AmountExpense,
	|	IncomeAndExpenses.ContentOfAccountingRecord
	|FROM
	|	AccumulationRegister.IncomeAndExpenses AS IncomeAndExpenses
	|WHERE
	|	IncomeAndExpenses.Recorder = &Recorder
	|
	|GROUP BY
	|	IncomeAndExpenses.Period,
	|	IncomeAndExpenses.Active,
	|	IncomeAndExpenses.Company,
	|	IncomeAndExpenses.StructuralUnit,
	|	IncomeAndExpenses.BusinessLine,
	|	IncomeAndExpenses.SalesOrder,
	|	IncomeAndExpenses.GLAccount,
	|	IncomeAndExpenses.ContentOfAccountingRecord
	|
	|HAVING
	|	(SUM(IncomeAndExpenses.AmountIncome) <> 0
	|		OR SUM(IncomeAndExpenses.AmountExpense) <> 0)";
	
	Query.SetParameter("Recorder", Ref);
	
	RecordsTableRegister = Query.Execute().Unload();
	
	RegisterRecordSet.Load(RecordsTableRegister);
	
EndProcedure

// Collapses the records set Inventory.
//
Procedure GroupRecordSetInventory(RegisterRecordSet)
	
	Query = New Query();
	Query.Text = 
	"SELECT
	|	Inventory.Period AS Period,
	|	Inventory.Active AS Active,
	|	Inventory.RecordType AS RecordType,
	|	Inventory.Company AS Company,
	|	Inventory.StructuralUnit AS StructuralUnit,
	|	Inventory.GLAccount AS GLAccount,
	|	Inventory.Products AS Products,
	|	Inventory.Characteristic AS Characteristic,
	|	Inventory.Batch AS Batch,
	|	Inventory.SalesOrder AS SalesOrder,
	|	SUM(Inventory.Quantity) AS Quantity,
	|	SUM(Inventory.Amount) AS Amount,
	|	Inventory.StructuralUnitCorr AS StructuralUnitCorr,
	|	Inventory.CorrGLAccount AS CorrGLAccount,
	|	Inventory.ProductsCorr AS ProductsCorr,
	|	Inventory.CharacteristicCorr AS CharacteristicCorr,
	|	Inventory.BatchCorr AS BatchCorr,
	|	Inventory.CustomerCorrOrder AS CustomerCorrOrder,
	|	Inventory.Specification AS Specification,
	|	Inventory.SpecificationCorr AS SpecificationCorr,
	|	Inventory.CorrSalesOrder AS CorrSalesOrder,
	|	Inventory.Department AS Department,
	|	Inventory.Responsible AS Responsible,
	|	Inventory.SourceDocument AS SourceDocument,
	|	Inventory.VATRate AS VATRate,
	|	Inventory.FixedCost AS FixedCost,
	|	Inventory.ProductionExpenses AS ProductionExpenses,
	|	Inventory.Return AS Return,
	|	Inventory.ContentOfAccountingRecord AS ContentOfAccountingRecord,
	|	Inventory.RetailTransferEarningAccounting AS RetailTransferEarningAccounting
	|FROM
	|	AccumulationRegister.Inventory AS Inventory
	|WHERE
	|	Inventory.Recorder = &Recorder
	|
	|GROUP BY
	|	Inventory.Period,
	|	Inventory.Active,
	|	Inventory.RecordType,
	|	Inventory.Company,
	|	Inventory.StructuralUnit,
	|	Inventory.GLAccount,
	|	Inventory.Products,
	|	Inventory.Characteristic,
	|	Inventory.Batch,
	|	Inventory.SalesOrder,
	|	Inventory.StructuralUnitCorr,
	|	Inventory.CorrGLAccount,
	|	Inventory.ProductsCorr,
	|	Inventory.CharacteristicCorr,
	|	Inventory.BatchCorr,
	|	Inventory.CustomerCorrOrder,
	|	Inventory.Specification,
	|	Inventory.SpecificationCorr,
	|	Inventory.CorrSalesOrder,
	|	Inventory.Department,
	|	Inventory.Responsible,
	|	Inventory.SourceDocument,
	|	Inventory.VATRate,
	|	Inventory.FixedCost,
	|	Inventory.ProductionExpenses,
	|	Inventory.Return,
	|	Inventory.ContentOfAccountingRecord,
	|	Inventory.RetailTransferEarningAccounting
	|
	|HAVING
	|	(SUM(Inventory.Quantity) <> 0
	|		OR SUM(Inventory.Amount) <> 0)";
	
	Query.SetParameter("Recorder", Ref);
	
	RecordsTableRegister = Query.Execute().Unload();
	
	RegisterRecordSet.Load(RecordsTableRegister); 
	
EndProcedure

// Collapses the records set Sales.
//
Procedure GroupRecordSetSales(RegisterRecordSet)
	
	Query = New Query();
	Query.Text = 
	"SELECT
	|	Sales.Period,
	|	Sales.Active,
	|	Sales.Products,
	|	Sales.Characteristic,
	|	Sales.Batch,
	|	Sales.Document,
	|	Sales.VATRate,
	|	Sales.Company,
	|	Sales.SalesOrder,
	|	Sales.Department,
	|	Sales.Responsible,
	|	SUM(Sales.Quantity) AS Quantity,
	|	SUM(Sales.Amount) AS Amount,
	|	SUM(Sales.VATAmount) AS VATAmount,
	|	SUM(Sales.Cost) AS Cost
	|FROM
	|	AccumulationRegister.Sales AS Sales
	|WHERE
	|	Sales.Recorder = &Recorder
	|
	|GROUP BY
	|	Sales.Period,
	|	Sales.Active,
	|	Sales.Products,
	|	Sales.Characteristic,
	|	Sales.Batch,
	|	Sales.Document,
	|	Sales.VATRate,
	|	Sales.Company,
	|	Sales.SalesOrder,
	|	Sales.Department,
	|	Sales.Responsible
	|
	|HAVING
	|	(SUM(Sales.Quantity) <> 0
	|		OR SUM(Sales.Amount) <> 0
	|		OR SUM(Sales.VATAmount) <> 0
	|		OR SUM(Sales.Cost) <> 0)";
	
	Query.SetParameter("Recorder", Ref);

	RecordsTableRegister = Query.Execute().Unload();
	
	RegisterRecordSet.Load(RecordsTableRegister);
	
EndProcedure

// Collapses the records set FinancialResult.
//
Procedure GroupRecordSetFinancialResult(RegisterRecordSet)
			
	Query = New Query();
	Query.Text = 
	"SELECT
	|	FinancialResult.Period,
	|	FinancialResult.Active,
	|	FinancialResult.Company,
	|	FinancialResult.StructuralUnit,
	|	FinancialResult.BusinessLine,
	|	FinancialResult.SalesOrder,
	|	FinancialResult.GLAccount,
	|	SUM(FinancialResult.AmountIncome) AS AmountIncome,
	|	SUM(FinancialResult.AmountExpense) AS AmountExpense,
	|	FinancialResult.ContentOfAccountingRecord
	|FROM
	|	AccumulationRegister.FinancialResult AS FinancialResult
	|WHERE
	|	FinancialResult.Recorder = &Recorder
	|
	|GROUP BY
	|	FinancialResult.Period,
	|	FinancialResult.Active,
	|	FinancialResult.Company,
	|	FinancialResult.StructuralUnit,
	|	FinancialResult.BusinessLine,
	|	FinancialResult.SalesOrder,
	|	FinancialResult.GLAccount,
	|	FinancialResult.ContentOfAccountingRecord
	|
	|HAVING
	|	(SUM(FinancialResult.AmountIncome) <> 0
	|		OR SUM(FinancialResult.AmountExpense) <> 0)";

	Query.SetParameter("Recorder", Ref);

	RecordsTableRegister = Query.Execute().Unload();
	
	RegisterRecordSet.Load(RecordsTableRegister);

EndProcedure

Procedure GroupRecordSetAccountingJournalEntries(RegisterRecordSet)
	
	Query = New Query();
	Query.Text = 
	"SELECT
	|	AccountingJournalEntries.Period AS Period,
	|	AccountingJournalEntries.Active AS Active,
	|	AccountingJournalEntries.AccountDr AS AccountDr,
	|	AccountingJournalEntries.AccountCr AS AccountCr,
	|	AccountingJournalEntries.Company AS Company,
	|	AccountingJournalEntries.PlanningPeriod AS PlanningPeriod,
	|	AccountingJournalEntries.CurrencyDr AS CurrencyDr,
	|	AccountingJournalEntries.CurrencyCr AS CurrencyCr,
	|	SUM(AccountingJournalEntries.Amount) AS Amount,
	|	SUM(AccountingJournalEntries.AmountCurDr) AS AmountCurDr,
	|	SUM(AccountingJournalEntries.AmountCurCr) AS AmountCurCr,
	|	AccountingJournalEntries.Content AS Content
	|FROM
	|	AccountingRegister.AccountingJournalEntries AS AccountingJournalEntries
	|WHERE
	|	AccountingJournalEntries.Recorder = &Recorder
	|
	|GROUP BY
	|	AccountingJournalEntries.Period,
	|	AccountingJournalEntries.Active,
	|	AccountingJournalEntries.AccountDr,
	|	AccountingJournalEntries.AccountCr,
	|	AccountingJournalEntries.Company,
	|	AccountingJournalEntries.PlanningPeriod,
	|	AccountingJournalEntries.CurrencyDr,
	|	AccountingJournalEntries.CurrencyCr,
	|	AccountingJournalEntries.Content
	|
	|HAVING
	|	(SUM(AccountingJournalEntries.Amount) <> 0
	|		OR SUM(AccountingJournalEntries.AmountCurDr) <> 0
	|		OR SUM(AccountingJournalEntries.AmountCurCr) <> 0)"; 

	Query.SetParameter("Recorder", Ref);

	RecordsTableRegister = Query.Execute().Unload();
	
	RegisterRecordSet.Load(RecordsTableRegister);
	
EndProcedure

#EndRegion

Procedure FindExistDocumentsInCurrentPeriod(Cancel)
	
	Query = New Query(
	"SELECT
	|	MonthEndClosing.Ref AS Ref,
	|	MonthEndClosing.DirectCostCalculation AS DirectCostCalculation,
	|	MonthEndClosing.CostAllocation AS CostAllocation,
	|	MonthEndClosing.ActualCostCalculation AS ActualCostCalculation,
	|	MonthEndClosing.FinancialResultCalculation AS FinancialResultCalculation,
	|	MonthEndClosing.ExchangeDifferencesCalculation AS ExchangeDifferencesCalculation,
	|	MonthEndClosing.RetailCostCalculationEarningAccounting AS RetailCostCalculationEarningAccounting,
	|	MonthEndClosing.VerifyTaxInvoices AS VerifyTaxInvoices,
	|	MonthEndClosing.VATPayableCalculation AS VATPayableCalculation
	|INTO ExistingDocuments
	|FROM
	|	Document.MonthEndClosing AS MonthEndClosing
	|WHERE
	|	MonthEndClosing.Posted
	|	AND ENDOFPERIOD(MonthEndClosing.Date, MONTH) = &Date
	|	AND MonthEndClosing.Company = &Company
	|	AND MonthEndClosing.Ref <> &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	TRUE
	|FROM
	|	ExistingDocuments AS MonthEndClosing
	|WHERE
	|	(MonthEndClosing.DirectCostCalculation = &DirectCostCalculation
	|				AND MonthEndClosing.DirectCostCalculation
	|			OR MonthEndClosing.CostAllocation = &CostAllocation
	|				AND MonthEndClosing.CostAllocation
	|			OR MonthEndClosing.ActualCostCalculation = &ActualCostCalculation
	|				AND MonthEndClosing.ActualCostCalculation
	|			OR MonthEndClosing.FinancialResultCalculation = &FinancialResultCalculation
	|				AND MonthEndClosing.FinancialResultCalculation
	|			OR MonthEndClosing.ExchangeDifferencesCalculation = &ExchangeDifferencesCalculation
	|				AND MonthEndClosing.ExchangeDifferencesCalculation
	|			OR MonthEndClosing.RetailCostCalculationEarningAccounting = &RetailCostCalculationEarningAccounting
	|				AND MonthEndClosing.RetailCostCalculationEarningAccounting
	|			OR MonthEndClosing.VerifyTaxInvoices = &VerifyTaxInvoices
	|				AND MonthEndClosing.VerifyTaxInvoices
	|			OR MonthEndClosing.VATPayableCalculation = &VATPayableCalculation
	|				AND MonthEndClosing.VATPayableCalculation)");
	
	Query.SetParameter("Date", Date);
	Query.SetParameter("Company", Company);
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("DirectCostCalculation", DirectCostCalculation);
	Query.SetParameter("CostAllocation", CostAllocation);
	Query.SetParameter("ActualCostCalculation", ActualCostCalculation);
	Query.SetParameter("FinancialResultCalculation", FinancialResultCalculation);
	Query.SetParameter("ExchangeDifferencesCalculation", ExchangeDifferencesCalculation);
	Query.SetParameter("RetailCostCalculationEarningAccounting", RetailCostCalculationEarningAccounting);
	Query.SetParameter("VerifyTaxInvoices", VerifyTaxInvoices);
	Query.SetParameter("VATPayableCalculation", VATPayableCalculation);
	
	ExistDocuments = Query.Execute().Select();
	If ExistDocuments.Next() Then
		ExceptionText = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'The document ""Month-end closing"" in month %1 is already exist in infobase.'"),
			Format(Date, "DF='MMMM yyyy'"));
		CommonUseClientServer.MessageToUser(ExceptionText, , , , Cancel);
	EndIf;
	
EndProcedure

Function ThereAreRecordsInPerviousPeriods(Period, Company)
	
	Query = New Query("
	|SELECT TOP 1
	|	1
	|FROM
	|	AccumulationRegister.Inventory AS Inventory
	|WHERE
	|	Inventory.Period < &Period
	|	AND Inventory.Company = &Company
	|");
	
	Query.SetParameter("Period", Period);
	Query.SetParameter("Company", Company);
	
	Result = Query.Execute();
	
	Return Not Result.IsEmpty();
EndFunction

#EndRegion

#Region EventHandlers

Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	Date = EndOfMonth(Date);
	
	FindExistDocumentsInCurrentPeriod(Cancel);
	
EndProcedure

// Procedure - event handler Posting(). Creates
// a document movement by accumulation registers and accounting register.
//
Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting.
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	AddAttributesToAdditionalPropertiesForPosting(AdditionalProperties);
	
	// Allow to write record sets.
	SetPropertiesOfDocumentRecordSets(True);
	
	RecordSetMonthEndErrors = InformationRegisters.MonthEndErrors.CreateRecordSet();
	RecordSetMonthEndErrors.Filter.Recorder.Set(Ref);
	ErrorsTable = RecordSetMonthEndErrors.UnloadColumns();
	
	// Verify tax invoices
	If VerifyTaxInvoices Then
		VerifyTaxInvoices(ErrorsTable);
	EndIf;
	
	InventoryValuationMethod = InformationRegisters.AccountingPolicy.InventoryValuationMethod(Date, Company);
	
	// Direct cost calculation
	If DirectCostCalculation And Not ActualCostCalculation Then
		If InventoryValuationMethod =Enums.InventoryValuationMethods.FIFO Then
			CalculateActualOutputCostPrice(Cancel, "DirectCostCalculation", ErrorsTable, InventoryValuationMethod);
		Else
			CalculateCostOfReturns(); // refunds cost precalculation.
			CalculateActualOutputCostPrice(Cancel, "DirectCostCalculation", ErrorsTable, InventoryValuationMethod);
			CalculateCostOfReturns(); // refunds cost final calculation.
		EndIf;
	EndIf;
	
	// Costs allocation.
	If CostAllocation Then
		DistributeCosts(Cancel, ErrorsTable);
	EndIf;
	
	// Primecost calculation.
	If ActualCostCalculation Then
		If InventoryValuationMethod =Enums.InventoryValuationMethods.FIFO Then
			CalculateActualOutputCostPrice(Cancel, "ActualCostCalculation", ErrorsTable, InventoryValuationMethod);
		Else
			CalculateCostOfReturns(); // refunds cost precalculation.
			CalculateActualOutputCostPrice(Cancel, "ActualCostCalculation", ErrorsTable, InventoryValuationMethod);
			CalculateCostOfReturns(); // refunds cost final calculation.
		EndIf;
	EndIf;
	
	// Primecost in retail calculation Earning accounting.
	If RetailCostCalculationEarningAccounting Then
		CalculateCostPriceInRetailEarningAccounting(Cancel, ErrorsTable);
	EndIf;
	
	// Exchange differences calculation.
	If ExchangeDifferencesCalculation Then
		CalculateExchangeDifferences(Cancel, ErrorsTable);
	EndIf;
	
	// Financial result calculation.
	If FinancialResultCalculation Then
		CalculateFinancialResult(Cancel, ErrorsTable);
	EndIf;
	
	// VAT payable calculation.
	If VATPayableCalculation Then
		CalculateVATPayable(Cancel, ErrorsTable);
	EndIf;
	
	If ErrorsTable.Count() > 0 Then
		MessageText = NStr("en = 'Warnings were generated on month-end closing. For more information, see the month-end closing report.'");
		CommonUseClientServer.MessageToUser(MessageText);
	EndIf;
	
	// Collapse register record sets.
	RecordSetInventory = AccumulationRegisters.Inventory.CreateRecordSet();
	RecordSetInventory.Filter.Recorder.Set(Ref);
	GroupRecordSetInventory(RecordSetInventory);
	RecordSetInventory.Write(True);
	
	RecordSetIncomeAndExpenses = AccumulationRegisters.IncomeAndExpenses.CreateRecordSet();
	RecordSetIncomeAndExpenses.Filter.Recorder.Set(Ref);
	GroupRecordSetIncomeAndExpenses(RecordSetIncomeAndExpenses);
	RecordSetIncomeAndExpenses.Write(True);
	
	RecordSetSales = AccumulationRegisters.Sales.CreateRecordSet();
	RecordSetSales.Filter.Recorder.Set(Ref);
	GroupRecordSetSales(RecordSetSales);
	RecordSetSales.Write(True);
	
	RecordSetFinancialResult = AccumulationRegisters.FinancialResult.CreateRecordSet();
	RecordSetFinancialResult.Filter.Recorder.Set(Ref);
	GroupRecordSetFinancialResult(RecordSetFinancialResult);
	RecordSetFinancialResult.Write(True);
	
	RecordSetAccountingJournalEntries = AccountingRegisters.AccountingJournalEntries.CreateRecordSet();
	RecordSetAccountingJournalEntries.Filter.Recorder.Set(Ref);
	GroupRecordSetAccountingJournalEntries(RecordSetAccountingJournalEntries);
	RecordSetAccountingJournalEntries.Write(True);
	
	ErrorsTable.GroupBy("Period, Recorder, Active, Company, OperationKind, ErrorDescription, Analytics");
	RecordSetMonthEndErrors.Load(ErrorsTable);
	RecordSetMonthEndErrors.Write(True);
	
	// Prohibit writing record sets.
	SetPropertiesOfDocumentRecordSets(False);
	
	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
EndProcedure

#EndRegion

#EndIf
