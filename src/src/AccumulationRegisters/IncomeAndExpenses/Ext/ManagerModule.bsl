#Region InfobaseUpdate

Procedure ProcessDataToUpgradeToNewVersion() Export
	
	Query = New Query;
	Query.TempTablesManager = New TempTablesManager;
	Query.Text = 
	"SELECT
	|	CreditNote.Ref AS Ref,
	|	CreditNote.AdjustmentAmount AS AdjustmentAmount
	|INTO CreditNotes
	|FROM
	|	Document.CreditNote AS CreditNote
	|		LEFT JOIN Constant.FunctionalOptionUseVAT AS FunctionalOptionUseVAT
	|		ON (TRUE)
	|WHERE
	|	CreditNote.Posted
	|	AND NOT CreditNote.AmountIncludesVAT
	|	AND CreditNote.VATTaxation <> VALUE(Enum.VATTaxationTypes.NotSubjectToVAT)
	|	AND FunctionalOptionUseVAT.Value
	|	AND CreditNote.OperationKind <> VALUE(Enum.OperationTypesCreditNote.SalesReturn)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CreditNote.Ref AS Ref,
	|	CreditNote.DocumentCurrency AS DocumentCurrency,
	|	CreditNote.ExchangeRate AS ExchangeRate,
	|	CreditNote.Multiplicity AS Multiplicity,
	|	CreditNote.GLAccount AS GLAccount,
	|	CreditNote.AmountIncludesVAT AS AmountIncludesVAT
	|INTO CreditNotes_Return
	|FROM
	|	Document.CreditNote AS CreditNote
	|		LEFT JOIN Constant.FunctionalOptionUseVAT AS FunctionalOptionUseVAT
	|		ON (TRUE)
	|WHERE
	|	CreditNote.Posted
	|	AND CreditNote.VATTaxation <> VALUE(Enum.VATTaxationTypes.NotSubjectToVAT)
	|	AND FunctionalOptionUseVAT.Value
	|	AND CreditNote.OperationKind = VALUE(Enum.OperationTypesCreditNote.SalesReturn)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DebitNote.Ref AS Ref,
	|	DebitNote.DocumentCurrency AS DocumentCurrency,
	|	DebitNote.ExchangeRate AS ExchangeRate,
	|	DebitNote.Multiplicity AS Multiplicity,
	|	DebitNote.GLAccount AS GLAccount,
	|	DebitNote.AmountIncludesVAT AS AmountIncludesVAT
	|INTO DebitNotes
	|FROM
	|	Document.DebitNote AS DebitNote
	|		LEFT JOIN Constant.FunctionalOptionUseVAT AS FunctionalOptionUseVAT
	|		ON (TRUE)
	|WHERE
	|	DebitNote.Posted
	|	AND DebitNote.VATTaxation <> VALUE(Enum.VATTaxationTypes.NotSubjectToVAT)
	|	AND FunctionalOptionUseVAT.Value
	|	AND DebitNote.OperationKind = VALUE(Enum.OperationTypesDebitNote.PurchaseReturn)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CreditNotes_Return.Ref AS Ref,
	|	SUM(-CASE
	|			WHEN CreditNotes_Return.AmountIncludesVAT
	|				THEN CreditNoteInventory.Amount
	|			ELSE CreditNoteInventory.Amount + CreditNoteInventory.VATAmount
	|		END) AS Total,
	|	SUM(CreditNoteInventory.VATAmount) AS VATAmount,
	|	CreditNotes_Return.DocumentCurrency AS DocumentCurrency,
	|	CreditNotes_Return.ExchangeRate AS ExchangeRate,
	|	CreditNotes_Return.Multiplicity AS Multiplicity,
	|	CreditNotes_Return.GLAccount AS GLAccount
	|INTO InventoryTotal
	|FROM
	|	CreditNotes_Return AS CreditNotes_Return
	|		LEFT JOIN Document.CreditNote.Inventory AS CreditNoteInventory
	|		ON CreditNotes_Return.Ref = CreditNoteInventory.Ref
	|WHERE
	|	CreditNoteInventory.VATAmount <> 0
	|
	|GROUP BY
	|	CreditNotes_Return.Ref,
	|	CreditNotes_Return.DocumentCurrency,
	|	CreditNotes_Return.ExchangeRate,
	|	CreditNotes_Return.Multiplicity,
	|	CreditNotes_Return.GLAccount
	|
	|UNION ALL
	|
	|SELECT
	|	DebitNotes.Ref,
	|	SUM(CASE
	|			WHEN DebitNotes.AmountIncludesVAT
	|				THEN DebitNoteInventory.Amount
	|			ELSE DebitNoteInventory.Amount + DebitNoteInventory.VATAmount
	|		END),
	|	SUM(DebitNoteInventory.VATAmount),
	|	DebitNotes.DocumentCurrency,
	|	DebitNotes.ExchangeRate,
	|	DebitNotes.Multiplicity,
	|	DebitNotes.GLAccount
	|FROM
	|	DebitNotes AS DebitNotes
	|		LEFT JOIN Document.DebitNote.Inventory AS DebitNoteInventory
	|		ON DebitNotes.Ref = DebitNoteInventory.Ref
	|WHERE
	|	DebitNoteInventory.VATAmount <> 0
	|
	|GROUP BY
	|	DebitNotes.Ref,
	|	DebitNotes.DocumentCurrency,
	|	DebitNotes.ExchangeRate,
	|	DebitNotes.Multiplicity,
	|	DebitNotes.GLAccount
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	IncomeAndExpenses.Recorder AS Ref,
	|	IncomeAndExpenses.Period AS Date
	|FROM
	|	InventoryTotal AS InventoryTotal
	|		INNER JOIN AccumulationRegister.IncomeAndExpenses AS IncomeAndExpenses
	|		ON InventoryTotal.Ref = IncomeAndExpenses.Recorder
	|			AND (InventoryTotal.Total = IncomeAndExpenses.AmountIncome
	|				OR InventoryTotal.Total = IncomeAndExpenses.AmountExpense)
	|
	|GROUP BY
	|	IncomeAndExpenses.Recorder,
	|	IncomeAndExpenses.Period
	|
	|UNION ALL
	|
	|SELECT
	|	IncomeAndExpenses.Recorder,
	|	IncomeAndExpenses.Period
	|FROM
	|	AccumulationRegister.IncomeAndExpenses AS IncomeAndExpenses
	|		INNER JOIN CreditNotes AS CreditNotes
	|		ON IncomeAndExpenses.Recorder = CreditNotes.Ref
	|			AND IncomeAndExpenses.AmountExpense <> CreditNotes.AdjustmentAmount
	|
	|GROUP BY
	|	IncomeAndExpenses.Recorder,
	|	IncomeAndExpenses.Period";
	
	QueryResult = Query.Execute();
	Selection	= QueryResult.Select();
	
	While Selection.Next() Do
		Query.Text = 
		"SELECT
		|	ExchangeRatesSliceLast.Currency AS Currency,
		|	ExchangeRatesSliceLast.ExchangeRate AS ExchangeRate,
		|	ExchangeRatesSliceLast.Multiplicity AS Multiplicity
		|INTO ExchangeRatesSliceLatest
		|FROM
		|	InformationRegister.ExchangeRates.SliceLast(&Date, Currency IN (&PresentationCurrency, &FunctionalCurrency)) AS ExchangeRatesSliceLast
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	InventoryTotal.Ref AS Ref,
		|	InventoryTotal.GLAccount AS GLAccount,
		|	CAST(CASE
		|			WHEN InventoryTotal.DocumentCurrency = &FunctionalCurrency
		|				THEN InventoryTotal.Total * RegExchangeRates.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * RegExchangeRates.Multiplicity)
		|			ELSE InventoryTotal.Total * InventoryTotal.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * InventoryTotal.Multiplicity)
		|		END AS NUMBER(15, 2)) AS Total,
		|	CAST(CASE
		|			WHEN InventoryTotal.DocumentCurrency = &FunctionalCurrency
		|				THEN InventoryTotal.VATAmount * RegExchangeRates.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * RegExchangeRates.Multiplicity)
		|			ELSE InventoryTotal.VATAmount * InventoryTotal.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * InventoryTotal.Multiplicity)
		|		END AS NUMBER(15, 2)) AS VATAmount
		|INTO InventoryTotalRecalculated
		|FROM
		|	InventoryTotal AS InventoryTotal
		|		LEFT JOIN ExchangeRatesSliceLatest AS ManagExchangeRates
		|		ON (ManagExchangeRates.Currency = &PresentationCurrency)
		|		LEFT JOIN ExchangeRatesSliceLatest AS RegExchangeRates
		|		ON (RegExchangeRates.Currency = &FunctionalCurrency)
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	IncomeAndExpenses.Period AS Period,
		|	IncomeAndExpenses.Recorder AS Recorder,
		|	IncomeAndExpenses.Company AS Company,
		|	IncomeAndExpenses.StructuralUnit AS StructuralUnit,
		|	IncomeAndExpenses.BusinessLine AS BusinessLine,
		|	IncomeAndExpenses.SalesOrder AS SalesOrder,
		|	IncomeAndExpenses.GLAccount AS GLAccount,
		|	CASE
		|		WHEN IncomeAndExpenses.AmountIncome > 0
		|				AND IncomeAndExpenses.AmountIncome = InventoryTotalRecalculated.Total
		|			THEN IncomeAndExpenses.AmountIncome - InventoryTotalRecalculated.VATAmount
		|		WHEN IncomeAndExpenses.AmountIncome < 0
		|				AND IncomeAndExpenses.AmountIncome = InventoryTotalRecalculated.Total
		|			THEN IncomeAndExpenses.AmountIncome + InventoryTotalRecalculated.VATAmount
		|		ELSE IncomeAndExpenses.AmountIncome
		|	END AS AmountIncome,
		|	CASE
		|		WHEN IncomeAndExpenses.AmountExpense <> 0
		|				AND IncomeAndExpenses.AmountExpense = InventoryTotalRecalculated.Total
		|			THEN IncomeAndExpenses.AmountExpense - InventoryTotalRecalculated.VATAmount
		|		ELSE IncomeAndExpenses.AmountExpense
		|	END AS AmountExpense,
		|	IncomeAndExpenses.ContentOfAccountingRecord AS ContentOfAccountingRecord
		|FROM
		|	AccumulationRegister.IncomeAndExpenses AS IncomeAndExpenses
		|		INNER JOIN InventoryTotalRecalculated AS InventoryTotalRecalculated
		|		ON IncomeAndExpenses.Recorder = InventoryTotalRecalculated.Ref
		|WHERE
		|	IncomeAndExpenses.Recorder = &Ref
		|
		|UNION ALL
		|
		|SELECT
		|	IncomeAndExpenses.Period,
		|	IncomeAndExpenses.Recorder,
		|	IncomeAndExpenses.Company,
		|	IncomeAndExpenses.StructuralUnit,
		|	IncomeAndExpenses.BusinessLine,
		|	IncomeAndExpenses.SalesOrder,
		|	IncomeAndExpenses.GLAccount,
		|	IncomeAndExpenses.AmountIncome,
		|	CASE
		|		WHEN IncomeAndExpenses.AmountExpense > 0
		|			THEN CreditNotes.AdjustmentAmount
		|		ELSE IncomeAndExpenses.AmountExpense
		|	END,
		|	IncomeAndExpenses.ContentOfAccountingRecord
		|FROM
		|	AccumulationRegister.IncomeAndExpenses AS IncomeAndExpenses
		|		INNER JOIN CreditNotes AS CreditNotes
		|		ON IncomeAndExpenses.Recorder = CreditNotes.Ref
		|WHERE
		|	IncomeAndExpenses.Recorder = &Ref
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|DROP ExchangeRatesSliceLatest
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|DROP InventoryTotalRecalculated";
		
		Query.SetParameter("Ref",	Selection.Ref);
		Query.SetParameter("Date", 	Selection.Date);
		Query.SetParameter("FunctionalCurrency",	Constants.FunctionalCurrency.Get());
		Query.SetParameter("PresentationCurrency",	Constants.PresentationCurrency.Get());
		
		RegisterRecords = AccumulationRegisters.IncomeAndExpenses.CreateRecordSet();
		RegisterRecords.Filter.Recorder.Set(Selection.Ref);
		RegisterRecords.Load(Query.Execute().Unload());
		RegisterRecords.Write();
	EndDo;
	
EndProcedure

// Replaces an empty sales order reference with an undefined
//
Procedure ChangeSalesOrderEmptyRefToUndefined() Export
	
	Query = New Query;
	Query.Text = 
	"SELECT DISTINCT
	|	IncomeAndExpenses.Recorder AS Ref
	|FROM
	|	AccumulationRegister.IncomeAndExpenses AS IncomeAndExpenses
	|WHERE
	|	IncomeAndExpenses.SalesOrder = VALUE(Document.SalesOrder.EmptyRef)";
	
	QueryResult = Query.Execute();
	Selection	= QueryResult.Select();
	
	While Selection.Next() Do
		
		Query.Text = 
		"SELECT
		|	IncomeAndExpenses.Period AS Period,
		|	IncomeAndExpenses.Recorder AS Recorder,
		|	IncomeAndExpenses.LineNumber AS LineNumber,
		|	IncomeAndExpenses.Active AS Active,
		|	IncomeAndExpenses.Company AS Company,
		|	IncomeAndExpenses.StructuralUnit AS StructuralUnit,
		|	IncomeAndExpenses.BusinessLine AS BusinessLine,
		|	CASE
		|		WHEN IncomeAndExpenses.SalesOrder = VALUE(Document.SalesOrder.EmptyRef)
		|			THEN UNDEFINED
		|		ELSE IncomeAndExpenses.SalesOrder
		|	END AS SalesOrder,
		|	IncomeAndExpenses.GLAccount AS GLAccount,
		|	IncomeAndExpenses.AmountIncome AS AmountIncome,
		|	IncomeAndExpenses.AmountExpense AS AmountExpense,
		|	IncomeAndExpenses.ContentOfAccountingRecord AS ContentOfAccountingRecord,
		|	IncomeAndExpenses.OfflineRecord AS OfflineRecord
		|FROM
		|	AccumulationRegister.IncomeAndExpenses AS IncomeAndExpenses
		|WHERE
		|	IncomeAndExpenses.Recorder = &Ref";
		
		Query.SetParameter("Ref", Selection.Ref);
		
		RegisterRecords = AccumulationRegisters.IncomeAndExpenses.CreateRecordSet();
		RegisterRecords.Filter.Recorder.Set(Selection.Ref);
		RegisterRecords.Load(Query.Execute().Unload());
		
		Try
			
			RegisterRecords.Write();
			
		Except
			
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Error on write document %1: %2'"),
				Selection.Ref,
				BriefErrorDescription(ErrorInfo()));
				
			WriteLogEvent(
				NStr("en = 'InfobaseUpdate'", CommonUseClientServer.MainLanguageCode()),
				EventLogLevel.Error,
				Metadata.AccumulationRegisters.IncomeAndExpenses,
				,
				ErrorDescription);
				
		EndTry;
			
	EndDo;
	
EndProcedure

#EndRegion
