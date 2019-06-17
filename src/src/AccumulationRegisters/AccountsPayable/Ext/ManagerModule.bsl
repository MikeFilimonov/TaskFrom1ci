#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ProgramInterface

// Procedure creates an empty temporary table of records change.
//
Procedure CreateEmptyTemporaryTableChange(AdditionalProperties) Export
	
	If Not AdditionalProperties.Property("ForPosting")
	 OR Not AdditionalProperties.ForPosting.Property("StructureTemporaryTables") Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	Query = New Query(
	"SELECT TOP 0
	|	AccountsPayable.LineNumber AS LineNumber,
	|	AccountsPayable.Company AS Company,
	|	AccountsPayable.Counterparty AS Counterparty,
	|	AccountsPayable.Contract AS Contract,
	|	AccountsPayable.Document AS Document,
	|	AccountsPayable.Order AS Order,
	|	AccountsPayable.SettlementsType AS SettlementsType,
	|	AccountsPayable.Amount AS SumBeforeWrite,
	|	AccountsPayable.Amount AS AmountChange,
	|	AccountsPayable.Amount AS AmountOnWrite,
	|	AccountsPayable.AmountCur AS AmountCurBeforeWrite,
	|	AccountsPayable.AmountCur AS SumCurChange,
	|	AccountsPayable.AmountCur AS SumCurOnWrite
	|INTO RegisterRecordsSuppliersSettlementsChange
	|FROM
	|	AccumulationRegister.AccountsPayable AS AccountsPayable");
	
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	QueryResult = Query.Execute();
	
	StructureTemporaryTables.Insert("RegisterRecordsSuppliersSettlementsChange", False);
	
EndProcedure

#EndRegion

#Region UpdateHandlers

Procedure ProcessDataToUpgradeToNewVersion() Export
	
	Query = New Query;
	Query.TempTablesManager = New TempTablesManager;
	Query.Text = 
	"SELECT
	|	Records.Recorder AS Recorder,
	|	SUM(Records.Amount) AS Amount,
	|	Records.Period AS Period,
	|	SUM(Records.AmountForPayment) AS AmountForPayment,
	|	SUM(Records.AmountForPaymentCur) AS AmountForPaymentCur
	|INTO TempAccountsReceivable
	|FROM
	|	AccumulationRegister.AccountsPayable AS Records
	|
	|GROUP BY
	|	Records.Recorder,
	|	Records.Period
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DebitNote.Ref AS Ref,
	|	DebitNote.AdjustmentAmount + DebitNote.VATAmount AS Total,
	|	DebitNote.DocumentCurrency AS DocumentCurrency,
	|	DebitNote.ExchangeRate AS ExchangeRate,
	|	DebitNote.Multiplicity AS Multiplicity,
	|	DebitNote.Date AS Date
	|INTO DebitNotes
	|FROM
	|	Document.DebitNote AS DebitNote
	|		LEFT JOIN Constant.FunctionalOptionUseVAT AS FunctionalOptionUseVAT
	|		ON (TRUE)
	|WHERE
	|	DebitNote.Posted
	|	AND NOT DebitNote.AmountIncludesVAT
	|	AND DebitNote.VATTaxation <> VALUE(Enum.VATTaxationTypes.NotSubjectToVAT)
	|	AND DebitNote.OperationKind <> VALUE(Enum.OperationTypesDebitNote.PurchaseReturn)
	|	AND FunctionalOptionUseVAT.Value
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Table.Recorder AS Ref,
	|	DebitNotes.Date AS Date
	|FROM
	|	TempAccountsReceivable AS Table
	|		INNER JOIN DebitNotes AS DebitNotes
	|		ON Table.Recorder = DebitNotes.Ref
	|WHERE
	|	DebitNotes.Total <> Table.Amount
	|
	|UNION ALL
	|
	|SELECT
	|	Table.Recorder,
	|	Table.Period
	|FROM
	|	TempAccountsReceivable AS Table
	|WHERE
	|	Table.AmountForPayment = 0
	|	AND Table.AmountForPaymentCur = 0";
	
	DataSelection = Query.Execute().Select();
	While DataSelection.Next() Do
		
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
		|	DebitNotes.Ref AS Ref,
		|	CAST(CASE
		|			WHEN DebitNotes.DocumentCurrency = &FunctionalCurrency
		|				THEN DebitNotes.Total * RegExchangeRates.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * RegExchangeRates.Multiplicity)
		|			ELSE DebitNotes.Total * DebitNotes.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * DebitNotes.Multiplicity)
		|		END AS NUMBER(15, 2)) AS Total,
		|	CAST(CASE
		|			WHEN DebitNotes.DocumentCurrency = &FunctionalCurrency
		|				THEN DebitNotes.Total * RegExchangeRates.ExchangeRate * DebitNotes.Multiplicity / (DebitNotes.ExchangeRate * RegExchangeRates.Multiplicity)
		|			ELSE DebitNotes.Total
		|		END AS NUMBER(15, 2)) AS TotalCur
		|INTO DebitNotesRecalculated
		|FROM
		|	DebitNotes AS DebitNotes
		|		LEFT JOIN ExchangeRatesSliceLatest AS ManagExchangeRates
		|		ON (ManagExchangeRates.Currency = &PresentationCurrency)
		|		LEFT JOIN ExchangeRatesSliceLatest AS RegExchangeRates
		|		ON (RegExchangeRates.Currency = &FunctionalCurrency)
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	Table.Period AS Period,
		|	Table.Recorder AS Recorder,
		|	Table.RecordType AS RecordType,
		|	Table.Company AS Company,
		|	Table.SettlementsType AS SettlementsType,
		|	Table.Counterparty AS Counterparty,
		|	Table.Contract AS Contract,
		|	Table.Document AS Document,
		|	Table.Order AS Order,
		|	DebitNotesRecalculated.Total AS Amount,
		|	DebitNotesRecalculated.TotalCur AS AmountCur,
		|	DebitNotesRecalculated.Total AS AmountForPayment,
		|	DebitNotesRecalculated.TotalCur AS AmountForPaymentCur,
		|	Table.ContentOfAccountingRecord AS ContentOfAccountingRecord
		|FROM
		|	AccumulationRegister.AccountsPayable AS Table
		|		INNER JOIN DebitNotesRecalculated AS DebitNotesRecalculated
		|		ON Table.Recorder = DebitNotesRecalculated.Ref
		|		LEFT JOIN ExchangeRatesSliceLatest AS ManagExchangeRates
		|		ON (ManagExchangeRates.Currency = &PresentationCurrency)
		|		LEFT JOIN ExchangeRatesSliceLatest AS RegExchangeRates
		|		ON (RegExchangeRates.Currency = &FunctionalCurrency)
		|WHERE
		|	Table.Recorder = &Ref
		|
		|UNION ALL
		|
		|SELECT
		|	Table.Period,
		|	Table.Recorder,
		|	Table.RecordType,
		|	Table.Company,
		|	Table.SettlementsType,
		|	Table.Counterparty,
		|	Table.Contract,
		|	Table.Document,
		|	Table.Order,
		|	Table.Amount,
		|	Table.AmountCur,
		|	Table.Amount,
		|	Table.AmountCur,
		|	Table.ContentOfAccountingRecord
		|FROM
		|	AccumulationRegister.AccountsPayable AS Table
		|WHERE
		|	Table.Recorder = &Ref
		|	AND Table.AmountForPayment = 0
		|	AND Table.AmountForPaymentCur = 0
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|DROP ExchangeRatesSliceLatest
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|DROP DebitNotesRecalculated";
		
		Query.SetParameter("Ref", 	DataSelection.Ref);
		Query.SetParameter("Date", 	DataSelection.Date);
		Query.SetParameter("FunctionalCurrency",	Constants.FunctionalCurrency.Get());
		Query.SetParameter("PresentationCurrency",	Constants.PresentationCurrency.Get());
		
		RegisterRecords = AccumulationRegisters.AccountsPayable.CreateRecordSet();
		RegisterRecords.Filter.Recorder.Set(DataSelection.Ref);
		RegisterRecords.Load(Query.Execute().Unload());
		
		RegisterRecords.Write();
		
	EndDo;
	
EndProcedure

#EndRegion

#EndIf