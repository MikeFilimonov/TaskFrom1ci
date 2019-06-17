#Region InfobaseUpdate

Procedure ProcessDataToUpgradeToNewVersion() Export
	
	Query = New Query;
	Query.TempTablesManager = New TempTablesManager;
	Query.Text = 
	"SELECT
	|	CreditNote.Ref AS Ref,
	|	CreditNote.GLAccount AS GLAccount,
	|	CreditNote.AdjustmentAmount AS AdjustmentAmount,
	|	CreditNote.VATAmount AS VATAmount,
	|	CreditNote.DocumentCurrency AS DocumentCurrency,
	|	CreditNote.ExchangeRate AS ExchangeRate,
	|	CreditNote.Multiplicity AS Multiplicity
	|INTO CreditNotes_Adjustments
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
	|	DebitNote.Ref AS Ref,
	|	DebitNote.GLAccount AS GLAccount,
	|	DebitNote.AdjustmentAmount AS AdjustmentAmount,
	|	DebitNote.VATAmount AS VATAmount,
	|	DebitNote.DocumentCurrency AS DocumentCurrency,
	|	DebitNote.ExchangeRate AS ExchangeRate,
	|	DebitNote.Multiplicity AS Multiplicity
	|INTO DebitNotes_Adjustments
	|FROM
	|	Document.DebitNote AS DebitNote
	|		LEFT JOIN Constant.FunctionalOptionUseVAT AS FunctionalOptionUseVAT
	|		ON (TRUE)
	|WHERE
	|	DebitNote.Posted
	|	AND NOT DebitNote.AmountIncludesVAT
	|	AND DebitNote.VATTaxation <> VALUE(Enum.VATTaxationTypes.NotSubjectToVAT)
	|	AND FunctionalOptionUseVAT.Value
	|	AND DebitNote.OperationKind <> VALUE(Enum.OperationTypesDebitNote.PurchaseReturn)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CreditNote.Ref AS Ref,
	|	CreditNote.GLAccount AS GLAccount,
	|	CreditNote.DocumentCurrency AS DocumentCurrency,
	|	CreditNote.ExchangeRate AS ExchangeRate,
	|	CreditNote.Multiplicity AS Multiplicity,
	|	CreditNote.AmountIncludesVAT AS AmountIncludesVAT
	|INTO CreditNotes_Return
	|FROM
	|	Document.CreditNote AS CreditNote
	|		LEFT JOIN Constant.FunctionalOptionUseVAT AS FunctionalOptionUseVAT
	|		ON (TRUE)
	|WHERE
	|	CreditNote.Posted
	|	AND NOT CreditNote.AmountIncludesVAT
	|	AND CreditNote.VATTaxation <> VALUE(Enum.VATTaxationTypes.NotSubjectToVAT)
	|	AND FunctionalOptionUseVAT.Value
	|	AND CreditNote.OperationKind = VALUE(Enum.OperationTypesCreditNote.SalesReturn)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DebitNote.Ref AS Ref,
	|	DebitNote.GLAccount AS GLAccount,
	|	DebitNote.DocumentCurrency AS DocumentCurrency,
	|	DebitNote.ExchangeRate AS ExchangeRate,
	|	DebitNote.Multiplicity AS Multiplicity,
	|	DebitNote.AmountIncludesVAT AS AmountIncludesVAT
	|INTO DebitNotes_Return
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
	|	SUM(CreditNoteInventory.Amount + CreditNoteInventory.VATAmount) AS Total,
	|	CreditNotes_Return.GLAccount AS GLAccount,
	|	SUM(CreditNoteInventory.VATAmount) AS VATAmount,
	|	CreditNotes_Return.DocumentCurrency AS DocumentCurrency,
	|	CreditNotes_Return.ExchangeRate AS ExchangeRate,
	|	CreditNotes_Return.Multiplicity AS Multiplicity
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
	|	CreditNotes_Return.GLAccount,
	|	CreditNotes_Return.DocumentCurrency,
	|	CreditNotes_Return.ExchangeRate,
	|	CreditNotes_Return.Multiplicity
	|
	|UNION ALL
	|
	|SELECT
	|	DebitNotes_Return.Ref,
	|	SUM(CASE
	|			WHEN DebitNotes_Return.AmountIncludesVAT
	|				THEN DebitNoteInventory.Amount
	|			ELSE DebitNoteInventory.Amount + DebitNoteInventory.VATAmount
	|		END),
	|	DebitNotes_Return.GLAccount,
	|	SUM(DebitNoteInventory.VATAmount),
	|	DebitNotes_Return.DocumentCurrency,
	|	DebitNotes_Return.ExchangeRate,
	|	DebitNotes_Return.Multiplicity
	|FROM
	|	DebitNotes_Return AS DebitNotes_Return
	|		LEFT JOIN Document.DebitNote.Inventory AS DebitNoteInventory
	|		ON DebitNotes_Return.Ref = DebitNoteInventory.Ref
	|WHERE
	|	DebitNoteInventory.VATAmount <> 0
	|
	|GROUP BY
	|	DebitNotes_Return.Ref,
	|	DebitNotes_Return.GLAccount,
	|	DebitNotes_Return.DocumentCurrency,
	|	DebitNotes_Return.ExchangeRate,
	|	DebitNotes_Return.Multiplicity
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccountingJournalEntries.Recorder AS Ref,
	|	AccountingJournalEntries.Period AS Date
	|FROM
	|	CreditNotes_Adjustments AS CreditNotes_Adjustments
	|		INNER JOIN AccountingRegister.AccountingJournalEntries AS AccountingJournalEntries
	|		ON CreditNotes_Adjustments.Ref = AccountingJournalEntries.Recorder
	|			AND CreditNotes_Adjustments.GLAccount = AccountingJournalEntries.AccountDr
	|			AND CreditNotes_Adjustments.AdjustmentAmount <> AccountingJournalEntries.Amount
	|
	|UNION ALL
	|
	|SELECT
	|	AccountingJournalEntries.Recorder,
	|	AccountingJournalEntries.Period
	|FROM
	|	DebitNotes_Adjustments AS DebitNotes_Adjustments
	|		INNER JOIN AccountingRegister.AccountingJournalEntries AS AccountingJournalEntries
	|		ON DebitNotes_Adjustments.Ref = AccountingJournalEntries.Recorder
	|			AND DebitNotes_Adjustments.GLAccount = AccountingJournalEntries.AccountCr
	|			AND DebitNotes_Adjustments.AdjustmentAmount <> AccountingJournalEntries.Amount
	|
	|UNION ALL
	|
	|SELECT
	|	AccountingJournalEntries.Recorder,
	|	AccountingJournalEntries.Period
	|FROM
	|	InventoryTotal AS InventoryTotal
	|		INNER JOIN AccountingRegister.AccountingJournalEntries AS AccountingJournalEntries
	|		ON InventoryTotal.Ref = AccountingJournalEntries.Recorder
	|			AND InventoryTotal.Total = AccountingJournalEntries.Amount";
	
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
		|	CreditNotes_Adjustments.Ref AS Ref,
		|	CreditNotes_Adjustments.GLAccount AS GLAccount,
		|	CAST(CASE
		|			WHEN CreditNotes_Adjustments.DocumentCurrency = &FunctionalCurrency
		|				THEN CreditNotes_Adjustments.VATAmount * RegExchangeRates.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * RegExchangeRates.Multiplicity)
		|			ELSE CreditNotes_Adjustments.VATAmount * CreditNotes_Adjustments.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * CreditNotes_Adjustments.Multiplicity)
		|		END AS NUMBER(15, 2)) AS VATAmount,
		|	CAST(CASE
		|			WHEN CreditNotes_Adjustments.DocumentCurrency = &FunctionalCurrency
		|				THEN CreditNotes_Adjustments.VATAmount * RegExchangeRates.ExchangeRate * CreditNotes_Adjustments.Multiplicity / (CreditNotes_Adjustments.ExchangeRate * RegExchangeRates.Multiplicity)
		|			ELSE CreditNotes_Adjustments.VATAmount
		|		END AS NUMBER(15, 2)) AS VATAmountCur
		|INTO CreditNotesRecalculated
		|FROM
		|	CreditNotes_Adjustments AS CreditNotes_Adjustments
		|		LEFT JOIN ExchangeRatesSliceLatest AS ManagExchangeRates
		|		ON (ManagExchangeRates.Currency = &PresentationCurrency)
		|		LEFT JOIN ExchangeRatesSliceLatest AS RegExchangeRates
		|		ON (RegExchangeRates.Currency = &FunctionalCurrency)
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	DebitNotes_Adjustments.Ref AS Ref,
		|	DebitNotes_Adjustments.GLAccount AS GLAccount,
		|	CAST(CASE
		|			WHEN DebitNotes_Adjustments.DocumentCurrency = &FunctionalCurrency
		|				THEN DebitNotes_Adjustments.VATAmount * RegExchangeRates.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * RegExchangeRates.Multiplicity)
		|			ELSE DebitNotes_Adjustments.VATAmount * DebitNotes_Adjustments.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * DebitNotes_Adjustments.Multiplicity)
		|		END AS NUMBER(15, 2)) AS VATAmount,
		|	CAST(CASE
		|			WHEN DebitNotes_Adjustments.DocumentCurrency = &FunctionalCurrency
		|				THEN DebitNotes_Adjustments.VATAmount * RegExchangeRates.ExchangeRate * DebitNotes_Adjustments.Multiplicity / (DebitNotes_Adjustments.ExchangeRate * RegExchangeRates.Multiplicity)
		|			ELSE DebitNotes_Adjustments.VATAmount
		|		END AS NUMBER(15, 2)) AS VATAmountCur
		|INTO DebitNotesRecalculated
		|FROM
		|	DebitNotes_Adjustments AS DebitNotes_Adjustments
		|		LEFT JOIN ExchangeRatesSliceLatest AS ManagExchangeRates
		|		ON (ManagExchangeRates.Currency = &PresentationCurrency)
		|		LEFT JOIN ExchangeRatesSliceLatest AS RegExchangeRates
		|		ON (RegExchangeRates.Currency = &FunctionalCurrency)
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	InventoryTotal.Ref AS Ref,
		|	InventoryTotal.GLAccount AS GLAccount,
		|	CAST(CASE
		|			WHEN InventoryTotal.DocumentCurrency = &FunctionalCurrency
		|				THEN InventoryTotal.VATAmount * RegExchangeRates.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * RegExchangeRates.Multiplicity)
		|			ELSE InventoryTotal.VATAmount * InventoryTotal.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * InventoryTotal.Multiplicity)
		|		END AS NUMBER(15, 2)) AS VATAmount,
		|	CAST(CASE
		|			WHEN InventoryTotal.DocumentCurrency = &FunctionalCurrency
		|				THEN InventoryTotal.VATAmount * RegExchangeRates.ExchangeRate * InventoryTotal.Multiplicity / (InventoryTotal.ExchangeRate * RegExchangeRates.Multiplicity)
		|			ELSE InventoryTotal.VATAmount
		|		END AS NUMBER(15, 2)) AS VATAmountCur,
		|	CAST(CASE
		|			WHEN InventoryTotal.DocumentCurrency = &FunctionalCurrency
		|				THEN InventoryTotal.Total * RegExchangeRates.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * RegExchangeRates.Multiplicity)
		|			ELSE InventoryTotal.Total * InventoryTotal.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * InventoryTotal.Multiplicity)
		|		END AS NUMBER(15, 2)) AS Total,
		|	CAST(CASE
		|			WHEN InventoryTotal.DocumentCurrency = &FunctionalCurrency
		|				THEN InventoryTotal.Total * RegExchangeRates.ExchangeRate * InventoryTotal.Multiplicity / (InventoryTotal.ExchangeRate * RegExchangeRates.Multiplicity)
		|			ELSE InventoryTotal.Total
		|		END AS NUMBER(15, 2)) AS TotalCur
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
		|	AccountingJournalEntries.Period AS Period,
		|	AccountingJournalEntries.Recorder AS Recorder,
		|	AccountingJournalEntries.AccountDr AS AccountDr,
		|	AccountingJournalEntries.AccountCr AS AccountCr,
		|	AccountingJournalEntries.Company AS Company,
		|	AccountingJournalEntries.PlanningPeriod AS PlanningPeriod,
		|	AccountingJournalEntries.CurrencyDr AS CurrencyDr,
		|	AccountingJournalEntries.CurrencyCr AS CurrencyCr,
		|	CAST(CASE
		|			WHEN AccountingJournalEntries.AccountDr = CreditNotesRecalculated.GLAccount
		|				THEN AccountingJournalEntries.Amount + CreditNotesRecalculated.VATAmount
		|			ELSE AccountingJournalEntries.Amount
		|		END AS NUMBER(15, 2)) AS Amount,
		|	AccountingJournalEntries.AmountCurDr AS AmountCurDr,
		|	CAST(CASE
		|			WHEN VALUETYPE(CreditNotesRecalculated.Ref) = TYPE(Document.CreditNote)
		|					AND AccountingJournalEntries.AccountDr = CreditNotesRecalculated.GLAccount
		|				THEN AccountingJournalEntries.AmountCurCr + CreditNotesRecalculated.VATAmountCur
		|			ELSE AccountingJournalEntries.AmountCurCr
		|		END AS NUMBER(15, 2)) AS AmountCurCr,
		|	AccountingJournalEntries.Content AS Content
		|FROM
		|	AccountingRegister.AccountingJournalEntries AS AccountingJournalEntries
		|		INNER JOIN CreditNotesRecalculated AS CreditNotesRecalculated
		|		ON AccountingJournalEntries.Recorder = CreditNotesRecalculated.Ref
		|WHERE
		|	AccountingJournalEntries.Recorder = &Ref
		|
		|UNION ALL
		|
		|SELECT
		|	AccountingJournalEntries.Period,
		|	AccountingJournalEntries.Recorder,
		|	AccountingJournalEntries.AccountDr,
		|	AccountingJournalEntries.AccountCr,
		|	AccountingJournalEntries.Company,
		|	AccountingJournalEntries.PlanningPeriod,
		|	AccountingJournalEntries.CurrencyDr,
		|	AccountingJournalEntries.CurrencyCr,
		|	CAST(CASE
		|			WHEN AccountingJournalEntries.AccountCr = DebitNotesRecalculated.GLAccount
		|				THEN AccountingJournalEntries.Amount + DebitNotesRecalculated.VATAmount
		|			ELSE AccountingJournalEntries.Amount
		|		END AS NUMBER(15, 2)),
		|	CAST(CASE
		|			WHEN VALUETYPE(DebitNotesRecalculated.Ref) = TYPE(Document.DebitNote)
		|					AND AccountingJournalEntries.AccountCr = DebitNotesRecalculated.GLAccount
		|				THEN AccountingJournalEntries.AmountCurDr + DebitNotesRecalculated.VATAmountCur
		|			ELSE AccountingJournalEntries.AmountCurDr
		|		END AS NUMBER(15, 2)),
		|	AccountingJournalEntries.AmountCurCr,
		|	AccountingJournalEntries.Content
		|FROM
		|	AccountingRegister.AccountingJournalEntries AS AccountingJournalEntries
		|		INNER JOIN DebitNotesRecalculated AS DebitNotesRecalculated
		|		ON AccountingJournalEntries.Recorder = DebitNotesRecalculated.Ref
		|WHERE
		|	AccountingJournalEntries.Recorder = &Ref
		|
		|UNION ALL
		|
		|SELECT
		|	AccountingJournalEntries.Period,
		|	AccountingJournalEntries.Recorder,
		|	AccountingJournalEntries.AccountDr,
		|	AccountingJournalEntries.AccountCr,
		|	AccountingJournalEntries.Company,
		|	AccountingJournalEntries.PlanningPeriod,
		|	AccountingJournalEntries.CurrencyDr,
		|	AccountingJournalEntries.CurrencyCr,
		|	CAST(CASE
		|			WHEN (AccountingJournalEntries.AccountDr = InventoryTotalRecalculated.GLAccount
		|					OR AccountingJournalEntries.AccountCr = InventoryTotalRecalculated.GLAccount)
		|					AND AccountingJournalEntries.Amount = InventoryTotalRecalculated.Total
		|				THEN AccountingJournalEntries.Amount - InventoryTotalRecalculated.VATAmount
		|			ELSE AccountingJournalEntries.Amount
		|		END AS NUMBER(15, 2)),
		|	CAST(CASE
		|			WHEN AccountingJournalEntries.AccountCr = InventoryTotalRecalculated.GLAccount
		|					AND AccountingJournalEntries.AmountCurDr = InventoryTotalRecalculated.TotalCur
		|				THEN AccountingJournalEntries.AmountCurDr - InventoryTotalRecalculated.VATAmountCur
		|			ELSE AccountingJournalEntries.AmountCurDr
		|		END AS NUMBER(15, 2)),
		|	CAST(CASE
		|			WHEN AccountingJournalEntries.AccountDr = InventoryTotalRecalculated.GLAccount
		|					AND AccountingJournalEntries.AmountCurCr = InventoryTotalRecalculated.TotalCur
		|				THEN AccountingJournalEntries.AmountCurCr - InventoryTotalRecalculated.VATAmountCur
		|			ELSE AccountingJournalEntries.AmountCurCr
		|		END AS NUMBER(15, 2)),
		|	AccountingJournalEntries.Content
		|FROM
		|	AccountingRegister.AccountingJournalEntries AS AccountingJournalEntries
		|		INNER JOIN InventoryTotalRecalculated AS InventoryTotalRecalculated
		|		ON AccountingJournalEntries.Recorder = InventoryTotalRecalculated.Ref
		|WHERE
		|	AccountingJournalEntries.Recorder = &Ref
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|DROP ExchangeRatesSliceLatest
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|DROP CreditNotesRecalculated
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|DROP DebitNotesRecalculated
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|DROP InventoryTotalRecalculated";
		
		Query.SetParameter("Ref", 	Selection.Ref);
		Query.SetParameter("Date", 	Selection.Date);
		Query.SetParameter("FunctionalCurrency",	Constants.FunctionalCurrency.Get());
		Query.SetParameter("PresentationCurrency",	Constants.PresentationCurrency.Get());
		
		RegisterRecords = AccountingRegisters.AccountingJournalEntries.CreateRecordSet();
		RegisterRecords.Filter.Recorder.Set(Selection.Ref);
		RegisterRecords.Load(Query.Execute().Unload());
		RegisterRecords.Write();
	EndDo;
	
EndProcedure

#EndRegion
