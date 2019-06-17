#Region InfobaseUpdate

Procedure ExcludeVATAmount() Export
	
	Query = New Query;
	Query.SetParameter("PresentationCurrency",	Constants.PresentationCurrency.Get());
	Query.SetParameter("FunctionalCurrency",	Constants.FunctionalCurrency.Get());
	
	Query.Text =
	"SELECT DISTINCT
	|	Sales.Recorder AS Recorder,
	|	Sales.Period AS Date
	|FROM
	|	AccumulationRegister.Sales AS Sales
	|WHERE
	|	Sales.ObsoleteAmount <> 0
	|	AND Sales.Amount = 0";
	
	Sel = Query.Execute().Select();
	
	While Sel.Next() Do
		
		Query.SetParameter("Recorder",	Sel.Recorder);
		Query.SetParameter("Date",		Sel.Date);
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
		|	CreditNote.Ref AS Ref,
		|	CreditNote.DocumentCurrency AS DocumentCurrency,
		|	CreditNote.ExchangeRate AS ExchangeRate,
		|	CreditNote.Multiplicity AS Multiplicity,
		|	CreditNote.AmountIncludesVAT AS AmountIncludesVAT
		|INTO CreditNote
		|FROM
		|	Document.CreditNote AS CreditNote
		|WHERE
		|	CreditNote.Ref = &Recorder
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	CreditNoteInventory.Products AS Products,
		|	CreditNoteInventory.Characteristic AS Characteristic,
		|	CreditNoteInventory.Batch AS Batch,
		|	CreditNoteInventory.VATRate AS VATRate,
		|	CreditNoteInventory.Order AS Order,
		|	CAST(CASE
		|			WHEN CreditNote.DocumentCurrency = &FunctionalCurrency
		|					AND CreditNote.AmountIncludesVAT
		|				THEN (CreditNoteInventory.Amount - CreditNoteInventory.VATAmount) * RegExchangeRates.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * RegExchangeRates.Multiplicity)
		|			WHEN CreditNote.DocumentCurrency = &FunctionalCurrency
		|					AND NOT CreditNote.AmountIncludesVAT
		|				THEN CreditNoteInventory.Amount * RegExchangeRates.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * RegExchangeRates.Multiplicity)
		|			WHEN CreditNote.DocumentCurrency <> &FunctionalCurrency
		|					AND CreditNote.AmountIncludesVAT
		|				THEN (CreditNoteInventory.Amount - CreditNoteInventory.VATAmount) * CreditNote.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * CreditNote.Ref.Multiplicity)
		|			WHEN CreditNote.DocumentCurrency <> &FunctionalCurrency
		|					AND NOT CreditNote.AmountIncludesVAT
		|				THEN CreditNoteInventory.Amount * CreditNote.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * CreditNote.Ref.Multiplicity)
		|		END AS NUMBER(15, 2)) AS Amount,
		|	CreditNote.Ref AS Ref
		|INTO Inventory
		|FROM
		|	CreditNote AS CreditNote
		|		INNER JOIN Document.CreditNote.Inventory AS CreditNoteInventory
		|		ON CreditNote.Ref = CreditNoteInventory.Ref
		|		LEFT JOIN ExchangeRatesSliceLatest AS ManagExchangeRates
		|		ON (ManagExchangeRates.Currency = &FunctionalCurrency)
		|		LEFT JOIN ExchangeRatesSliceLatest AS RegExchangeRates
		|		ON (RegExchangeRates.Currency = &PresentationCurrency)
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	Sales.Period AS Period,
		|	Sales.Active AS Active,
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
		|	CASE
		|		WHEN Inventory.Amount IS NULL
		|			THEN Sales.ObsoleteAmount - Sales.VATAmount
		|		ELSE Inventory.Amount
		|	END AS Amount,
		|	Sales.VATAmount AS VATAmount,
		|	Sales.Cost AS Cost,
		|	Sales.ObsoleteAmount AS ObsoleteAmount
		|FROM
		|	AccumulationRegister.Sales AS Sales
		|		LEFT JOIN Inventory AS Inventory
		|		ON Sales.Recorder = Inventory.Ref
		|			AND Sales.Products = Inventory.Products
		|			AND Sales.Characteristic = Inventory.Characteristic
		|			AND Sales.Batch = Inventory.Batch
		|			AND Sales.VATRate = Inventory.VATRate
		|			AND Sales.SalesOrder = Inventory.Order
		|WHERE
		|	Sales.Recorder = &Recorder
		|
		|ORDER BY
		|	Sales.LineNumber";
		
		RecordSet = AccumulationRegisters.Sales.CreateRecordSet();
		RecordSet.Filter.Recorder.Set(Sel.Recorder);
		RecordSet.Load(Query.Execute().Unload());
		RecordSet.Write();
		
	EndDo;
	
EndProcedure

// Replaces an empty sales order reference with an undefined
//
Procedure ChangeSalesOrderEmptyRefToUndefined() Export
	
	Query = New Query;
	Query.Text = 
	"SELECT DISTINCT
	|	Sales.Recorder AS Ref
	|FROM
	|	AccumulationRegister.Sales AS Sales
	|WHERE
	|	Sales.SalesOrder = VALUE(Document.SalesOrder.EmptyRef)";
	
	QueryResult = Query.Execute();
	Selection	= QueryResult.Select();
	
	While Selection.Next() Do
		
		Query.Text = 
		"SELECT
		|	Sales.Period AS Period,
		|	Sales.Recorder AS Recorder,
		|	Sales.LineNumber AS LineNumber,
		|	Sales.Active AS Active,
		|	Sales.Products AS Products,
		|	Sales.Characteristic AS Characteristic,
		|	Sales.Batch AS Batch,
		|	Sales.Document AS Document,
		|	Sales.VATRate AS VATRate,
		|	Sales.Company AS Company,
		|	CASE
		|		WHEN Sales.SalesOrder = VALUE(Document.SalesOrder.EmptyRef)
		|			THEN UNDEFINED
		|		ELSE Sales.SalesOrder
		|	END AS SalesOrder,
		|	Sales.Department AS Department,
		|	Sales.Responsible AS Responsible,
		|	Sales.Quantity AS Quantity,
		|	Sales.Amount AS Amount,
		|	Sales.VATAmount AS VATAmount,
		|	Sales.Cost AS Cost,
		|	Sales.ObsoleteAmount AS ObsoleteAmount,
		|	Sales.OfflineRecord AS OfflineRecord
		|FROM
		|	AccumulationRegister.Sales AS Sales
		|WHERE
		|	Sales.Recorder = &Ref";
		
		Query.SetParameter("Ref", Selection.Ref);
		
		RegisterRecords = AccumulationRegisters.Sales.CreateRecordSet();
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
				Metadata.AccumulationRegisters.Sales,
				,
				ErrorDescription);
				
		EndTry;
		
	EndDo;
	
EndProcedure

#EndRegion