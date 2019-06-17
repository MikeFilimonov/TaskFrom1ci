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
	|	AccountsReceivable.LineNumber AS LineNumber,
	|	AccountsReceivable.Company AS Company,
	|	AccountsReceivable.Counterparty AS Counterparty,
	|	AccountsReceivable.Contract AS Contract,
	|	AccountsReceivable.Document AS Document,
	|	AccountsReceivable.Order AS Order,
	|	AccountsReceivable.SettlementsType AS SettlementsType,
	|	AccountsReceivable.Amount AS SumBeforeWrite,
	|	AccountsReceivable.Amount AS AmountChange,
	|	AccountsReceivable.Amount AS AmountOnWrite,
	|	AccountsReceivable.AmountCur AS AmountCurBeforeWrite,
	|	AccountsReceivable.AmountCur AS SumCurChange,
	|	AccountsReceivable.AmountCur AS SumCurOnWrite
	|INTO RegisterRecordsAccountsReceivableChange
	|FROM
	|	AccumulationRegister.AccountsReceivable AS AccountsReceivable");
	
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	QueryResult = Query.Execute();
	
	StructureTemporaryTables.Insert("RegisterRecordsAccountsReceivableChange", False);
	
EndProcedure

#EndRegion

#Region UpdateHandlers

Procedure ProcessDataToUpgradeToNewVersion() Export
	
	Query = New Query;
	Query.TempTablesManager = New TempTablesManager;
	Query.Text = 
	"SELECT
	|	Records.Recorder AS Recorder,
	|	SUM(Records.AmountForPayment) AS AmountForPayment,
	|	SUM(Records.AmountForPaymentCur) AS AmountForPaymentCur,
	|	SUM(Records.Amount) AS Amount,
	|	Records.Period AS Period
	|INTO TempAccountsReceivable
	|FROM
	|	AccumulationRegister.AccountsReceivable AS Records
	|
	|GROUP BY
	|	Records.Recorder,
	|	Records.Period
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CreditNote.Ref AS Ref,
	|	CreditNote.AdjustmentAmount + CreditNote.VATAmount AS Total,
	|	CreditNote.DocumentCurrency AS DocumentCurrency,
	|	CreditNote.ExchangeRate AS ExchangeRate,
	|	CreditNote.Multiplicity AS Multiplicity,
	|	CreditNote.Date AS Date
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
	|	Table.Recorder AS Ref,
	|	Table.Period AS Date
	|FROM
	|	TempAccountsReceivable AS Table
	|WHERE
	|	Table.AmountForPayment = 0
	|	AND Table.AmountForPaymentCur = 0
	|
	|UNION ALL
	|
	|SELECT
	|	Table.Recorder,
	|	CreditNotes.Date
	|FROM
	|	TempAccountsReceivable AS Table
	|		INNER JOIN CreditNotes AS CreditNotes
	|		ON Table.Recorder = CreditNotes.Ref
	|WHERE
	|	CreditNotes.Total <> Table.Amount";
	
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
		|	CreditNotes.Ref AS Ref,
		|	CAST(CASE
		|			WHEN CreditNotes.DocumentCurrency = &FunctionalCurrency
		|				THEN CreditNotes.Total * RegExchangeRates.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * RegExchangeRates.Multiplicity)
		|			ELSE CreditNotes.Total * CreditNotes.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * CreditNotes.Multiplicity)
		|		END AS NUMBER(15, 2)) AS Total,
		|	CAST(CASE
		|			WHEN CreditNotes.DocumentCurrency = &FunctionalCurrency
		|				THEN CreditNotes.Total * RegExchangeRates.ExchangeRate * CreditNotes.Multiplicity / (CreditNotes.ExchangeRate * RegExchangeRates.Multiplicity)
		|			ELSE CreditNotes.Total
		|		END AS NUMBER(15, 2)) AS TotalCur
		|INTO CreditNotesRecalculated
		|FROM
		|	CreditNotes AS CreditNotes
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
		|	Table.Amount AS Amount,
		|	Table.AmountCur AS AmountCur,
		|	Table.Amount AS AmountForPayment,
		|	Table.AmountCur AS AmountForPaymentCur,
		|	Table.ContentOfAccountingRecord AS ContentOfAccountingRecord
		|FROM
		|	AccumulationRegister.AccountsReceivable AS Table
		|WHERE
		|	Table.Recorder = &Ref
		|	AND Table.AmountForPayment = 0
		|	AND Table.AmountForPaymentCur = 0
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
		|	CreditNotesRecalculated.Total,
		|	CreditNotesRecalculated.TotalCur,
		|	CreditNotesRecalculated.Total,
		|	CreditNotesRecalculated.TotalCur,
		|	Table.ContentOfAccountingRecord
		|FROM
		|	AccumulationRegister.AccountsReceivable AS Table
		|		INNER JOIN CreditNotesRecalculated AS CreditNotesRecalculated
		|		ON Table.Recorder = CreditNotesRecalculated.Ref
		|		LEFT JOIN ExchangeRatesSliceLatest AS ManagExchangeRates
		|		ON (ManagExchangeRates.Currency = &PresentationCurrency)
		|		LEFT JOIN ExchangeRatesSliceLatest AS RegExchangeRates
		|		ON (RegExchangeRates.Currency = &FunctionalCurrency)
		|WHERE
		|	Table.Recorder = &Ref
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|DROP ExchangeRatesSliceLatest
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|DROP CreditNotesRecalculated";
		
		Query.SetParameter("Ref",	DataSelection.Ref);
		Query.SetParameter("Date", 	DataSelection.Date);
		Query.SetParameter("FunctionalCurrency",	Constants.FunctionalCurrency.Get());
		Query.SetParameter("PresentationCurrency",	Constants.PresentationCurrency.Get());
		
		RegisterRecords = AccumulationRegisters.AccountsReceivable.CreateRecordSet();
		RegisterRecords.Filter.Recorder.Set(DataSelection.Ref);
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
	|	AccountsReceivable.Recorder AS Ref
	|FROM
	|	AccumulationRegister.AccountsReceivable AS AccountsReceivable
	|WHERE
	|	AccountsReceivable.Order = VALUE(Document.SalesOrder.EmptyRef)";
	
	QueryResult = Query.Execute();
	Selection	= QueryResult.Select();
	
	While Selection.Next() Do
		
		Query.Text = 
		"SELECT
		|	AccountsReceivable.Period AS Period,
		|	AccountsReceivable.Recorder AS Recorder,
		|	AccountsReceivable.LineNumber AS LineNumber,
		|	AccountsReceivable.Active AS Active,
		|	AccountsReceivable.RecordType AS RecordType,
		|	AccountsReceivable.Company AS Company,
		|	AccountsReceivable.SettlementsType AS SettlementsType,
		|	AccountsReceivable.Counterparty AS Counterparty,
		|	AccountsReceivable.Contract AS Contract,
		|	AccountsReceivable.Document AS Document,
		|	CASE
		|		WHEN AccountsReceivable.Order = VALUE(Document.SalesOrder.EmptyRef)
		|			THEN UNDEFINED
		|		ELSE AccountsReceivable.Order
		|	END AS Order,
		|	AccountsReceivable.Amount AS Amount,
		|	AccountsReceivable.AmountCur AS AmountCur,
		|	AccountsReceivable.AmountForPayment AS AmountForPayment,
		|	AccountsReceivable.AmountForPaymentCur AS AmountForPaymentCur,
		|	AccountsReceivable.ContentOfAccountingRecord AS ContentOfAccountingRecord
		|FROM
		|	AccumulationRegister.AccountsReceivable AS AccountsReceivable
		|WHERE
		|	AccountsReceivable.Recorder = &Ref";
		
		Query.SetParameter("Ref", Selection.Ref);
		
		RegisterRecords = AccumulationRegisters.AccountsReceivable.CreateRecordSet();
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
				Metadata.AccumulationRegisters.AccountsReceivable,
				,
				ErrorDescription);
				
		EndTry;
			
	EndDo;
	
EndProcedure

#EndRegion

#EndIf