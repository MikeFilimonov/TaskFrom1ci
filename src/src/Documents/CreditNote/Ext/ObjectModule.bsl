#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

Procedure CheckReturnedQuantity(Cancel)
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	CreditNoteInventory.Products AS Products,
		|	CreditNoteInventory.Characteristic AS Characteristic,
		|	CreditNoteInventory.Batch AS Batch,
		|	CreditNoteInventory.MeasurementUnit AS MeasurementUnit,
		|	CreditNoteInventory.Quantity AS Quantity
		|INTO CreditNoteInventory
		|FROM
		|	Document.CreditNote.Inventory AS CreditNoteInventory
		|WHERE
		|	CreditNoteInventory.Ref = &Ref
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	Inventory.Products AS Products,
		|	Inventory.Characteristic AS Characteristic,
		|	Inventory.Batch AS Batch,
		|	SUM(Inventory.Quantity) AS Quantity,
		|	Inventory.MeasurementUnit AS MeasurementUnit
		|INTO SalesDocument
		|FROM
		|	Document.SalesInvoice.Inventory AS Inventory
		|WHERE
		|	Inventory.Ref = &BasisDocument
		|
		|GROUP BY
		|	Inventory.Products,
		|	Inventory.Characteristic,
		|	Inventory.Batch,
		|	Inventory.MeasurementUnit
		|
		|UNION ALL
		|
		|SELECT
		|	SalesSlipInventory.Products,
		|	SalesSlipInventory.Characteristic,
		|	SalesSlipInventory.Batch,
		|	SUM(SalesSlipInventory.Quantity),
		|	SalesSlipInventory.MeasurementUnit
		|FROM
		|	Document.SalesSlip.Inventory AS SalesSlipInventory
		|WHERE
		|	SalesSlipInventory.Ref = &BasisDocument
		|
		|GROUP BY
		|	SalesSlipInventory.Products,
		|	SalesSlipInventory.Characteristic,
		|	SalesSlipInventory.Batch,
		|	SalesSlipInventory.MeasurementUnit
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	CreditNoteInventory.Batch AS Batch,
		|	CreditNoteInventory.Characteristic AS Characteristic,
		|	CreditNoteInventory.Products AS Products,
		|	-CreditNoteInventory.Quantity AS Quantity,
		|	CreditNoteInventory.Quantity AS ReturnedQuantity,
		|	0 AS InitialQuantity,
		|	CreditNoteInventory.MeasurementUnit AS MeasurementUnit
		|INTO UnionResult
		|FROM
		|	Document.CreditNote.Inventory AS CreditNoteInventory
		|WHERE
		|	CreditNoteInventory.Ref.BasisDocument = &BasisDocument
		|	AND CreditNoteInventory.Ref.Posted
		|	AND CreditNoteInventory.Ref <> &Ref
		|
		|UNION ALL
		|
		|SELECT
		|	CreditNoteInventory.Batch,
		|	CreditNoteInventory.Characteristic,
		|	CreditNoteInventory.Products,
		|	-CreditNoteInventory.Quantity,
		|	CreditNoteInventory.Quantity,
		|	0,
		|	CreditNoteInventory.MeasurementUnit
		|FROM
		|	Document.CreditNote.Inventory AS CreditNoteInventory
		|		INNER JOIN Document.GoodsReturn AS GoodsReturn
		|		ON (GoodsReturn.SalesDocument = &BasisDocument)
		|			AND CreditNoteInventory.Ref.BasisDocument = GoodsReturn.Ref
		|WHERE
		|	CreditNoteInventory.Ref <> &Ref
		|	AND CreditNoteInventory.Ref.Posted
		|
		|UNION ALL
		|
		|SELECT
		|	SalesDocument.Batch,
		|	SalesDocument.Characteristic,
		|	SalesDocument.Products,
		|	SalesDocument.Quantity,
		|	0,
		|	SalesDocument.Quantity,
		|	SalesDocument.MeasurementUnit
		|FROM
		|	SalesDocument AS SalesDocument
		|
		|UNION ALL
		|
		|SELECT
		|	CreditNoteInventory.Batch,
		|	CreditNoteInventory.Characteristic,
		|	CreditNoteInventory.Products,
		|	-CreditNoteInventory.Quantity,
		|	0,
		|	0,
		|	CreditNoteInventory.MeasurementUnit
		|FROM
		|	CreditNoteInventory AS CreditNoteInventory
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	UnionResult.Products.Presentation AS Products,
		|	UnionResult.Characteristic.Presentation AS Characteristic,
		|	UnionResult.Batch.Presentation AS Batch,
		|	SUM(UnionResult.Quantity) AS Quantity,
		|	SUM(UnionResult.ReturnedQuantity) AS ReturnedQuantity,
		|	SUM(UnionResult.InitialQuantity - UnionResult.ReturnedQuantity) AS AvailableQuantity,
		|	UnionResult.MeasurementUnit AS MeasurementUnit
		|INTO GroupedResult
		|FROM
		|	UnionResult AS UnionResult
		|
		|GROUP BY
		|	UnionResult.Characteristic.Presentation,
		|	UnionResult.Products.Presentation,
		|	UnionResult.MeasurementUnit,
		|	UnionResult.Batch.Presentation
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	GroupedResult.Products AS Products,
		|	GroupedResult.Characteristic AS Characteristic,
		|	GroupedResult.Batch AS Batch,
		|	GroupedResult.Quantity AS Quantity,
		|	GroupedResult.ReturnedQuantity AS ReturnedQuantity,
		|	GroupedResult.AvailableQuantity AS AvailableQuantity,
		|	GroupedResult.MeasurementUnit AS MeasurementUnit
		|FROM
		|	GroupedResult AS GroupedResult
		|WHERE
		|	GroupedResult.Quantity < 0";;
	
	Query.SetParameter("BasisDocument",	?(TypeOf(BasisDocument) = Type("DocumentRef.GoodsReturn"),
										BasisDocument.SalesDocument, BasisDocument));
	Query.SetParameter("Ref",			Ref);
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	
	While Selection.Next() Do
		If Selection.ReturnedQuantity > 0 Then
			MessageToUser = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = '%1 %2 of %3 was previously returned by other Credit note documents.
				     |You have only %4 %2 left to return. See subordinate structure of initial Sales invoice for details.'"),
				Selection.ReturnedQuantity, 
				Selection.MeasurementUnit,
				Selection.Products + ?(ValueIsFilled(Selection.Characteristic), ", " + Selection.Characteristic, "")
				 + ?(ValueIsFilled(Selection.Batch), ", " + Selection.Batch, ""),
				Selection.AvailableQuantity,);
		Else
			MessageToUser = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'There is more quantity of returned goods ""%1"" than in initial Sales Invoice.'"),
				Selection.Products + ?(ValueIsFilled(Selection.Characteristic), ", " + Selection.Characteristic, "")
				 + ?(ValueIsFilled(Selection.Batch), ", " + Selection.Batch, ""));
		EndIf;
			
		CommonUseClientServer.MessageToUser(MessageToUser,,,,Cancel);
	EndDo;
	
EndProcedure

Procedure FillBySalesInvoice(FillingData) Export
	
	BasisDocument = FillingData.Ref;

	FillPropertyValues(ThisObject, FillingData,, "Ref, Number, Date, Author, Posted, DeletionMark");
	DocumentAmount		= 0;
	OperationKind		= Enums.OperationTypesCreditNote.SalesReturn;
	VATRate				= InformationRegisters.AccountingPolicy.GetDefaultVATRate(Date, Company);
	
	FillInventory(FillingData);
	
EndProcedure

Procedure FillBySalesSlip(FillingData) Export
	
	OperationKind = Enums.OperationTypesCreditNote.SalesReturn;
	
	BasisDocument = FillingData.Ref;
	FillPropertyValues(ThisObject, FillingData,, "Number, Date, Author");
	If Not ValueIsFilled(Counterparty) Then
		Counterparty = Catalogs.Counterparties.RetailCustomer;
		Contract = DriveServer.GetContractByDefault(ThisObject, Counterparty, Company, OperationKind);
	EndIf;
	
	DocumentAmount = 0;
	ExchangeRate = 1; 
	Multiplicity = 1;
	
	FillInventory(FillingData);

EndProcedure

Procedure FillByGoodsReturn(FillingData) Export
	
	BasisDocument = FillingData.Ref;

	FillPropertyValues(ThisObject, FillingData,, "Ref, Number, Date, Posted, DeletionMark");
	AdjustmentAmount	= FillingData.DocumentAmount;
	OperationKind		= Enums.OperationTypesCreditNote.SalesReturn;
	VATRate 			= InformationRegisters.AccountingPolicy.GetDefaultVATRate(Date, Company);
	VATAmount			= 0;
	
	If ValueIsFilled(FillingData.SalesDocument) Then
		AmountIncludesVAT = FillingData.SalesDocument.AmountIncludesVAT;
	EndIf;
	
	FillInventory(FillingData);

EndProcedure

Procedure FillByCashOrBankReceipt(FillingData, QueryText)
	
	BasisDocument = FillingData;
	
	FillPropertyValues(ThisObject, FillingData,, "Ref, Number, Date, Posted, DeletionMark, BasisDocument, Comment, OperationKind");
	
	OperationKind		= Enums.OperationTypesCreditNote.DiscountAllowed;
	AmountIncludesVAT	= True;
	
	DateParameter = EndOfDay(?(ValueIsFilled(Date), Date, CurrentSessionDate()));
	
	Query = New Query;
	Query.SetParameter("Ref", FillingData);
	Query.SetParameter("DocumentDate", DateParameter);
	
	Query.Text = QueryText;
	
	ResultArray		= Query.ExecuteBatch();
	QueryResult1	= ResultArray[4];
	QueryResult2	= ResultArray[5];
	
	If NOT QueryResult1.IsEmpty() Then
		
		ResultTable	= QueryResult1.Unload();
		FirstRow	= ResultTable[0];
		
		CreditedTransactions.Load(QueryResult2.Unload());
		
		DocumentCurrency	= FirstRow.SettlementsCurrency;
		ExchangeRate		= FirstRow.ExchangeRate;
		Multiplicity		= FirstRow.Multiplicity;
		Contract			= FirstRow.Contract;
		ProvideEPD			= FirstRow.ProvideEPD;
		
		If ProvideEPD = Enums.VariantsOfProvidingEPD.CreditDebitNote Then
			VATTaxation = Enums.VATTaxationTypes.NotSubjectToVAT;
			VATRate = Catalogs.VATRates.Exempt;
		Else
			VATTaxation = Enums.VATTaxationTypes.SubjectToVAT;
			VATRate = InformationRegisters.AccountingPolicy.GetDefaultVATRate(Date, Company);
		EndIf;
		
		AmountAllocation.Clear();
		
		ReasonForCorrectionArray = New Array;
		
		For each Row In ResultTable Do
			
			NewAllocation = AmountAllocation.Add();
			
			FillPropertyValues(NewAllocation, Row, "Contract, Document, OffsetAmount, Order");
			
			NewAllocation.VATRate = VATRate;
			
			If VATTaxation = Enums.VATTaxationTypes.NotSubjectToVAT Then
				
				NewAllocation.VATAmount = 0;
				
			Else
				
				VATRateForCalc = DriveReUse.GetVATRateValue(NewAllocation.VATRate);
				NewAllocation.VATAmount = NewAllocation.OffsetAmount - NewAllocation.OffsetAmount / (100 + VATRateForCalc) * 100;
				
			EndIf;
			
			ReasonForCorrectionArray.Add(
				Row.Number
				+ StringFunctionsClientServer.SubstituteParametersInString(" %1 ", NStr("en = 'dated'"))
				+ Format(Row.Date, "DLF=D"));
			
		EndDo;
		
		If ReasonForCorrectionArray.Count() > 0 Then
			
			Reason = StringFunctionsClientServer.GetStringFromSubstringArray(ReasonForCorrectionArray, ", ");
			
			ReasonForCorrection = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Early payment discount provided against invoices %1'"),
				Reason);
			
			
		EndIf;
		
	EndIf;
	
	AdjustmentAmount	= AmountAllocation.Total("OffsetAmount");
	VATAmount			= AmountAllocation.Total("VATAmount");
	
EndProcedure

Procedure FillByCashReceipt(FillingData) Export
	
	QueryText =
	"SELECT
	|	ExchangeRatesSliceLast.Currency AS Currency,
	|	ExchangeRatesSliceLast.ExchangeRate AS ExchangeRate,
	|	ExchangeRatesSliceLast.Multiplicity AS Multiplicity
	|INTO TempExchangeRates
	|FROM
	|	InformationRegister.ExchangeRates.SliceLast(&DocumentDate, ) AS ExchangeRatesSliceLast
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CashReceiptPaymentDetails.Contract AS Contract,
	|	CashReceiptPaymentDetails.Document AS Document,
	|	CashReceiptPaymentDetails.Order AS Order,
	|	CashReceiptPaymentDetails.SettlementsEPDAmount AS OffsetAmount
	|INTO TempPaymentDelails
	|FROM
	|	Document.CashReceipt.PaymentDetails AS CashReceiptPaymentDetails
	|WHERE
	|	CashReceiptPaymentDetails.Ref = &Ref
	|	AND CashReceiptPaymentDetails.SettlementsEPDAmount > 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TempPaymentDelails.Contract AS Contract,
	|	TempPaymentDelails.Document AS Document,
	|	TempPaymentDelails.Order AS Order,
	|	TempPaymentDelails.OffsetAmount AS OffsetAmount,
	|	SalesInvoice.ProvideEPD AS ProvideEPD,
	|	SalesInvoice.Number AS Number,
	|	SalesInvoice.Date AS Date,
	|	ISNULL(Contracts.SettlementsCurrency, VALUE(Catalog.Currencies.EmptyRef)) AS SettlementsCurrency
	|INTO TempPaymentDelailsWithInvoice
	|FROM
	|	TempPaymentDelails AS TempPaymentDelails
	|		INNER JOIN Document.SalesInvoice AS SalesInvoice
	|		ON TempPaymentDelails.Document = SalesInvoice.Ref
	|		LEFT JOIN Catalog.CounterpartyContracts AS Contracts
	|		ON TempPaymentDelails.Contract = Contracts.Ref
	|WHERE
	|	(SalesInvoice.ProvideEPD = VALUE(Enum.VariantsOfProvidingEPD.CreditDebitNote)
	|			OR SalesInvoice.ProvideEPD = VALUE(Enum.VariantsOfProvidingEPD.CreditDebitNoteWithVATAdjustment))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	TempPaymentDelailsWithInvoice.Document AS Document
	|INTO SalesInvoiceTable
	|FROM
	|	TempPaymentDelailsWithInvoice AS TempPaymentDelailsWithInvoice
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TempPaymentDelailsWithInvoice.Contract AS Contract,
	|	TempPaymentDelailsWithInvoice.Document AS Document,
	|	TempPaymentDelailsWithInvoice.Order AS Order,
	|	TempPaymentDelailsWithInvoice.OffsetAmount AS OffsetAmount,
	|	TempPaymentDelailsWithInvoice.ProvideEPD AS ProvideEPD,
	|	TempPaymentDelailsWithInvoice.Number AS Number,
	|	TempPaymentDelailsWithInvoice.Date AS Date,
	|	ISNULL(TempExchangeRates.ExchangeRate, 1) AS ExchangeRate,
	|	ISNULL(TempExchangeRates.Multiplicity, 1) AS Multiplicity,
	|	TempPaymentDelailsWithInvoice.SettlementsCurrency AS SettlementsCurrency
	|FROM
	|	TempPaymentDelailsWithInvoice AS TempPaymentDelailsWithInvoice
	|		LEFT JOIN TempExchangeRates AS TempExchangeRates
	|		ON TempPaymentDelailsWithInvoice.SettlementsCurrency = TempExchangeRates.Currency
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SalesTurnovers.Recorder AS Document,
	|	SalesTurnovers.VATRate AS VATRate,
	|	CASE
	|		WHEN SalesTurnovers.AmountTurnover + SalesTurnovers.VATAmountTurnover > 0
	|			THEN SalesTurnovers.AmountTurnover + SalesTurnovers.VATAmountTurnover
	|		ELSE -(SalesTurnovers.AmountTurnover + SalesTurnovers.VATAmountTurnover)
	|	END AS Amount,
	|	CASE
	|		WHEN SalesTurnovers.VATAmountTurnover > 0
	|			THEN SalesTurnovers.VATAmountTurnover
	|		ELSE -SalesTurnovers.VATAmountTurnover
	|	END AS VATAmount
	|FROM
	|	AccumulationRegister.Sales.Turnovers(, , Recorder, ) AS SalesTurnovers
	|		INNER JOIN SalesInvoiceTable AS SalesInvoiceTable
	|		ON SalesTurnovers.Recorder = SalesInvoiceTable.Document";
	
	FillByCashOrBankReceipt(FillingData, QueryText);
	
EndProcedure

Procedure FillByPaymentReceipt(FillingData) Export
	
	QueryText =
	"SELECT
	|	ExchangeRatesSliceLast.Currency AS Currency,
	|	ExchangeRatesSliceLast.ExchangeRate AS ExchangeRate,
	|	ExchangeRatesSliceLast.Multiplicity AS Multiplicity
	|INTO TempExchangeRates
	|FROM
	|	InformationRegister.ExchangeRates.SliceLast(&DocumentDate, ) AS ExchangeRatesSliceLast
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	PaymentReceiptPaymentDetails.Contract AS Contract,
	|	PaymentReceiptPaymentDetails.Document AS Document,
	|	PaymentReceiptPaymentDetails.Order AS Order,
	|	PaymentReceiptPaymentDetails.SettlementsEPDAmount AS OffsetAmount
	|INTO TempPaymentDelails
	|FROM
	|	Document.PaymentReceipt.PaymentDetails AS PaymentReceiptPaymentDetails
	|WHERE
	|	PaymentReceiptPaymentDetails.Ref = &Ref
	|	AND PaymentReceiptPaymentDetails.SettlementsEPDAmount > 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TempPaymentDelails.Contract AS Contract,
	|	TempPaymentDelails.Document AS Document,
	|	TempPaymentDelails.Order AS Order,
	|	TempPaymentDelails.OffsetAmount AS OffsetAmount,
	|	SalesInvoice.ProvideEPD AS ProvideEPD,
	|	SalesInvoice.Number AS Number,
	|	SalesInvoice.Date AS Date,
	|	ISNULL(Contracts.SettlementsCurrency, VALUE(Catalog.Currencies.EmptyRef)) AS SettlementsCurrency
	|INTO TempPaymentDelailsWithInvoice
	|FROM
	|	TempPaymentDelails AS TempPaymentDelails
	|		INNER JOIN Document.SalesInvoice AS SalesInvoice
	|		ON TempPaymentDelails.Document = SalesInvoice.Ref
	|		LEFT JOIN Catalog.CounterpartyContracts AS Contracts
	|		ON TempPaymentDelails.Contract = Contracts.Ref
	|WHERE
	|	(SalesInvoice.ProvideEPD = VALUE(Enum.VariantsOfProvidingEPD.CreditDebitNote)
	|			OR SalesInvoice.ProvideEPD = VALUE(Enum.VariantsOfProvidingEPD.CreditDebitNoteWithVATAdjustment))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	TempPaymentDelailsWithInvoice.Document AS Document
	|INTO SalesInvoiceTable
	|FROM
	|	TempPaymentDelailsWithInvoice AS TempPaymentDelailsWithInvoice
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TempPaymentDelailsWithInvoice.Contract AS Contract,
	|	TempPaymentDelailsWithInvoice.Document AS Document,
	|	TempPaymentDelailsWithInvoice.Order AS Order,
	|	TempPaymentDelailsWithInvoice.OffsetAmount AS OffsetAmount,
	|	TempPaymentDelailsWithInvoice.ProvideEPD AS ProvideEPD,
	|	TempPaymentDelailsWithInvoice.Number AS Number,
	|	TempPaymentDelailsWithInvoice.Date AS Date,
	|	ISNULL(TempExchangeRates.ExchangeRate, 1) AS ExchangeRate,
	|	ISNULL(TempExchangeRates.Multiplicity, 1) AS Multiplicity,
	|	TempPaymentDelailsWithInvoice.SettlementsCurrency AS SettlementsCurrency
	|FROM
	|	TempPaymentDelailsWithInvoice AS TempPaymentDelailsWithInvoice
	|		LEFT JOIN TempExchangeRates AS TempExchangeRates
	|		ON TempPaymentDelailsWithInvoice.SettlementsCurrency = TempExchangeRates.Currency
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SalesTurnovers.Recorder AS Document,
	|	SalesTurnovers.VATRate AS VATRate,
	|	CASE
	|		WHEN SalesTurnovers.AmountTurnover + SalesTurnovers.VATAmountTurnover > 0
	|			THEN SalesTurnovers.AmountTurnover + SalesTurnovers.VATAmountTurnover
	|		ELSE -(SalesTurnovers.AmountTurnover + SalesTurnovers.VATAmountTurnover)
	|	END AS Amount,
	|	CASE
	|		WHEN SalesTurnovers.VATAmountTurnover > 0
	|			THEN SalesTurnovers.VATAmountTurnover
	|		ELSE -SalesTurnovers.VATAmountTurnover
	|	END AS VATAmount
	|FROM
	|	AccumulationRegister.Sales.Turnovers(, , Recorder, ) AS SalesTurnovers
	|		INNER JOIN SalesInvoiceTable AS SalesInvoiceTable
	|		ON SalesTurnovers.Recorder = SalesInvoiceTable.Document";
	
	FillByCashOrBankReceipt(FillingData, QueryText);
	
EndProcedure

Procedure FillInventory(BasisDocument) Export
	
	If BasisDocument = Undefined Then 
		Return;
	EndIf;
	
	DocumentType = BasisDocument.Metadata().Name;
	If TypeOf(BasisDocument) = Type("DocumentRef.SalesSlip") Then
		BasisDocumentAttributes = CommonUse.ObjectAttributeValues(BasisDocument, "Archival, CashCRSession");
		SalesDocument = ?(BasisDocumentAttributes.Archival,	BasisDocumentAttributes.CashCRSession, BasisDocument);
	Else
		SalesDocument = BasisDocument;
	EndIf;
	
	Query = New Query;
	Query.SetParameter("AmountIncludesVAT", BasisDocument.AmountIncludesVAT);
	Query.SetParameter("BasisDocument", 	BasisDocument);
	Query.SetParameter("SalesDocument", 	SalesDocument);
	Query.SetParameter("Ref", 				Ref);
	
	If TypeOf(BasisDocument) = Type("DocumentRef.GoodsReturn") Then
		Query.Text = 
		"SELECT
		|	GoodsReturnProducts.Price AS Price,
		|	GoodsReturnProducts.MeasurementUnit AS MeasurementUnit,
		|	GoodsReturnProducts.Characteristic AS Characteristic,
		|	GoodsReturnProducts.Batch AS Batch,
		|	SUM(GoodsReturnProducts.InitialQuantity) AS InitialQuantity,
		|	SUM(GoodsReturnProducts.InitialAmount) AS InitialAmount,
		|	GoodsReturnProducts.Ref.SalesDocument AS Document,
		|	SUM(GoodsReturnProducts.Quantity) AS Quantity,
		|	GoodsReturnProducts.VATRate AS VATRate,
		|	GoodsReturnProducts.Products AS Products,
		|	SUM(GoodsReturnProducts.Amount) AS Amount,
		|	GoodsReturnProducts.VATAmount AS VATAmount,
		|	SUM(GoodsReturnProducts.CostOfGoodsSold) AS CostOfGoodsSold,
		|	GoodsReturnProducts.SerialNumbers AS SerialNumbers,
		|	GoodsReturnProducts.ConnectionKey AS ConnectionKey,
		|	GoodsReturnProducts.Price AS InitialPrice,
		|	GoodsReturnProducts.LineNumber AS LineNumber,
		|	GoodsReturnProducts.Order AS Order,
		|	GoodsReturnProducts.SalesRep AS SalesRep,
		|	CASE
		|		WHEN &AmountIncludesVAT
		|			THEN GoodsReturnProducts.Amount
		|		ELSE GoodsReturnProducts.Amount + GoodsReturnProducts.VATAmount
		|	END AS Total
		|FROM
		|	Document.GoodsReturn.Inventory AS GoodsReturnProducts
		|WHERE
		|	GoodsReturnProducts.Ref = &BasisDocument
		|
		|GROUP BY
		|	GoodsReturnProducts.MeasurementUnit,
		|	GoodsReturnProducts.Characteristic,
		|	GoodsReturnProducts.Batch,
		|	GoodsReturnProducts.Price,
		|	GoodsReturnProducts.VATRate,
		|	GoodsReturnProducts.Ref.SalesDocument,
		|	GoodsReturnProducts.Products,
		|	GoodsReturnProducts.SerialNumbers,
		|	GoodsReturnProducts.ConnectionKey,
		|	GoodsReturnProducts.LineNumber,
		|	GoodsReturnProducts.Order,
		|	GoodsReturnProducts.SalesRep,
		|	GoodsReturnProducts.VATAmount,
		|	CASE
		|		WHEN &AmountIncludesVAT
		|			THEN GoodsReturnProducts.Amount
		|		ELSE GoodsReturnProducts.Amount + GoodsReturnProducts.VATAmount
		|	END,
		|	GoodsReturnProducts.Price
		|
		|ORDER BY
		|	LineNumber";
	Else
		Query.Text = 
		"SELECT
		|	Inventory.Price AS Price,
		|	Inventory.MeasurementUnit AS MeasurementUnit,
		|	Inventory.Products AS Products,
		|	Inventory.Characteristic AS Characteristic,
		|	Inventory.Batch AS Batch,
		|	SUM(Inventory.Quantity) AS Quantity,
		|	SUM(Inventory.Amount) AS Amount,
		|	Inventory.VATRate AS VATRate,
		|	Inventory.DiscountMarkupPercent AS DiscountMarkupPercent,
		|	Inventory.SerialNumbers AS SerialNumbers,
		|	Inventory.ConnectionKey AS ConnectionKey,
		|	Inventory.Order AS Order,
		|	Inventory.SalesRep AS SalesRep
		|INTO SalesDocument
		|FROM
		|	Document.SalesInvoice.Inventory AS Inventory
		|WHERE
		|	Inventory.Ref = &BasisDocument
		|
		|GROUP BY
		|	Inventory.MeasurementUnit,
		|	Inventory.Products,
		|	Inventory.Characteristic,
		|	Inventory.VATRate,
		|	Inventory.SerialNumbers,
		|	Inventory.Batch,
		|	Inventory.DiscountMarkupPercent,
		|	Inventory.ConnectionKey,
		|	Inventory.Price,
		|	Inventory.Order,
		|	Inventory.SalesRep
		|
		|UNION ALL
		|
		|SELECT
		|	SalesSlipInventory.Price,
		|	SalesSlipInventory.MeasurementUnit,
		|	SalesSlipInventory.Products,
		|	SalesSlipInventory.Characteristic,
		|	SalesSlipInventory.Batch,
		|	SUM(SalesSlipInventory.Quantity),
		|	SUM(SalesSlipInventory.Amount),
		|	SalesSlipInventory.VATRate,
		|	SalesSlipInventory.DiscountMarkupPercent,
		|	SalesSlipInventory.SerialNumbers,
		|	SalesSlipInventory.ConnectionKey,
		|	VALUE(Document.SalesOrder.EmptyRef),
		|	VALUE(Catalog.Employees.EmptyRef)
		|FROM
		|	Document.SalesSlip.Inventory AS SalesSlipInventory
		|WHERE
		|	SalesSlipInventory.Ref = &BasisDocument
		|
		|GROUP BY
		|	SalesSlipInventory.MeasurementUnit,
		|	SalesSlipInventory.Products,
		|	SalesSlipInventory.Characteristic,
		|	SalesSlipInventory.VATRate,
		|	SalesSlipInventory.SerialNumbers,
		|	SalesSlipInventory.Batch,
		|	SalesSlipInventory.DiscountMarkupPercent,
		|	SalesSlipInventory.ConnectionKey,
		|	SalesSlipInventory.Price
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	SalesTurnovers.Products AS Products,
		|	SalesTurnovers.Characteristic AS Characteristic,
		|	SalesTurnovers.Batch AS Batch,
		|	SUM(SalesTurnovers.QuantityTurnover) AS QuantityBalance,
		|	SalesTurnovers.VATRate AS VATRate
		|INTO Sales
		|FROM
		|	AccumulationRegister.Sales.Turnovers(, , Recorder, Document = &SalesDocument) AS SalesTurnovers
		|WHERE
		|	SalesTurnovers.Recorder <> &Ref
		|
		|GROUP BY
		|	SalesTurnovers.Products,
		|	SalesTurnovers.VATRate,
		|	SalesTurnovers.Characteristic,
		|	SalesTurnovers.Batch
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	Sales.Products AS Products,
		|	Sales.Characteristic AS Characteristic,
		|	Sales.Batch AS Batch,
		|	Sales.QuantityBalance AS QuantityBalance,
		|	Sales.VATRate AS VATRate
		|INTO Balances
		|FROM
		|	Sales AS Sales
		|WHERE
		|	Sales.QuantityBalance > 0
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	SalesDocument.MeasurementUnit AS MeasurementUnit,
		|	SalesDocument.Products AS Products,
		|	SalesDocument.Characteristic AS Characteristic,
		|	SalesDocument.Batch AS Batch,
		|	SalesDocument.VATRate AS VATRate,
		|	SalesDocument.DiscountMarkupPercent AS DiscountMarkupPercent,
		|	SalesDocument.SerialNumbers AS SerialNumbers,
		|	SalesDocument.ConnectionKey AS ConnectionKey,
		|	SalesDocument.Order AS Order,
		|	SalesDocument.SalesRep AS SalesRep,
		|	SalesDocument.Quantity AS InitialQuantity,
		|	SalesDocument.Amount AS InitialAmount,
		|	SalesDocument.Price AS InitialPrice,
		|	SalesDocument.Price AS Price
		|FROM
		|	Balances AS Balances
		|		INNER JOIN SalesDocument AS SalesDocument
		|		ON Balances.Products = SalesDocument.Products
		|			AND Balances.Characteristic = SalesDocument.Characteristic
		|			AND Balances.Batch = SalesDocument.Batch
		|			AND Balances.VATRate = SalesDocument.VATRate
		|";
	EndIf;
	
	QueryResult = Query.Execute();
	Inventory.Load(QueryResult.Unload());
	
	AccountingPolicy = InformationRegisters.AccountingPolicy.GetAccountingPolicy(Date, Company);
	UseGoodsReturnFromCustomer = AccountingPolicy.UseGoodsReturnFromCustomer;
	
	For Each Row In Inventory Do
		Rate = DriveReUse.GetVATRateValue(Row.VATRate);
		VATAmount = VATAmount + Row.Amount * Rate / 100;
		If UseGoodsReturnFromCustomer Then
			Row.SerialNumbers = "";
		EndIf;
	EndDo;
	
	If Not UseGoodsReturnFromCustomer Then
		WorkWithSerialNumbers.FillTSSerialNumbersByConnectionKey(ThisObject, BasisDocument);
	EndIf;
	
EndProcedure

#Region EventHandlers

Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If ValueIsFilled(AdjustmentAmount)
		AND AmountAllocation.Count() = 0 Then
		FillAmountAllocation();
	EndIf;
	
	DocumentAmount = AdjustmentAmount;
	If OperationKind <> Enums.OperationTypesCreditNote.SalesReturn Then
		DocumentAmount = DocumentAmount + ?(AmountIncludesVAT, 0, VATAmount);
	EndIf;
	
	FillSalesRep();
	
	AdditionalProperties.Insert("WriteMode", WriteMode);
	
EndProcedure

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	AccountingPolicy = InformationRegisters.AccountingPolicy.GetAccountingPolicy(Date, Company);
	If OperationKind <> Enums.OperationTypesCreditNote.SalesReturn 
		Or AccountingPolicy.UseGoodsReturnFromCustomer Then
		CheckedAttributes.Delete(CheckedAttributes.Find("StructuralUnit"));
	EndIf;
	
	If OperationKind = Enums.OperationTypesCreditNote.SalesReturn Then
		CheckedAttributes.Delete(CheckedAttributes.Find("AdjustmentAmount"));
	Else
		CheckedAttributes.Delete(CheckedAttributes.Find("Inventory"));
	EndIf;
	
	If Not AccountingPolicy.UseGoodsReturnFromCustomer Then
		WorkWithSerialNumbers.FillCheckingSerialNumbers(Cancel, Inventory, SerialNumbers, StructuralUnit, ThisObject);
	EndIf;
	
EndProcedure

// Procedure - handler of the FillingProcessor event.
//
Procedure Filling(FillingData, StandardProcessing) Export
		
	FillingStrategy = New Map;
	FillingStrategy[Type("DocumentRef.SalesInvoice")]	= "FillBySalesInvoice";
	FillingStrategy[Type("DocumentRef.SalesSlip")]		= "FillBySalesSlip";
	FillingStrategy[Type("DocumentRef.GoodsReturn")]	= "FillByGoodsReturn";
	FillingStrategy[Type("DocumentRef.CashReceipt")]	= "FillByCashReceipt";
	FillingStrategy[Type("DocumentRef.PaymentReceipt")]	= "FillByPaymentReceipt";
	
	If TypeOf(FillingData) = Type("DocumentRef.CashReceipt")
		OR TypeOf(FillingData) = Type("DocumentRef.PaymentReceipt") Then
		
		ObjectFillingDrive.FillDocument(ThisObject, FillingData, FillingStrategy, "AmountIncludesVAT");
		
	Else
		
		ObjectFillingDrive.FillDocument(ThisObject, FillingData, FillingStrategy);
		
		If DocumentCurrency <> Constants.FunctionalCurrency.Get() Then
			StructureByCurrency = InformationRegisters.ExchangeRates.GetLast(Date, New Structure("Currency", Contract.SettlementsCurrency));
			ExchangeRate		= StructureByCurrency.ExchangeRate;
			Multiplicity		= StructureByCurrency.Multiplicity;
		EndIf;
		
		AmountAllocation.Clear();
		
	EndIf;
	
EndProcedure

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	// Subordinate tax invoice
	If Not Cancel And AdditionalProperties.WriteMode = DocumentWriteMode.Write Then
		WorkWithVAT.SubordinatedTaxInvoiceControl(AdditionalProperties.WriteMode, Ref, DeletionMark);
	EndIf;
	
EndProcedure

// Procedure - event handler Posting object.
//
Procedure Posting(Cancel, PostingMode)
	
	If OperationKind = Enums.OperationTypesCreditNote.SalesReturn Then
		CheckReturnedQuantity(Cancel);
	EndIf;
	
	// Initialization of additional properties for document posting
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Document data initialization.
	PerformanceEstimationClientServer.StartTimeMeasurement("CreditNoteDocumentPostingInitialization");
	
	// Initialization of document data
	Documents.CreditNote.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Preparation of record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Account for in accounting sections.
	PerformanceEstimationClientServer.StartTimeMeasurement("CreditNoteDocumentPostingMovementsCreation");
	
	DriveServer.ReflectSales(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountsReceivable(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectIncomeAndExpenses(AdditionalProperties, RegisterRecords, Cancel);
	
	If OperationKind = Enums.OperationTypesCreditNote.SalesReturn Then 
		If NOT AdditionalProperties.AccountingPolicy.UseGoodsReturnFromCustomer Then
			DriveServer.ReflectInventoryInWarehouses(AdditionalProperties, RegisterRecords, Cancel);
			DriveServer.ReflectInventory(AdditionalProperties, RegisterRecords, Cancel);
			DriveServer.ReflectTheSerialNumbersOfTheGuarantee(AdditionalProperties, RegisterRecords, Cancel);
			DriveServer.ReflectTheSerialNumbersBalance(AdditionalProperties, RegisterRecords, Cancel);
		EndIf;
	EndIf;
	
	If GetFunctionalOption("UseVAT")
		AND NOT WorkWithVAT.GetUseTaxInvoiceForPostingVAT(Date, Company) 
		AND VATTaxation <> Enums.VATTaxationTypes.NotSubjectToVAT
		AND VATTaxation <> Enums.VATTaxationTypes.ReverseChargeVAT Then
		
		DriveServer.ReflectVATOutput(AdditionalProperties, RegisterRecords, Cancel);
		
	EndIf;
	
	DriveServer.ReflectAccountingJournalEntries(AdditionalProperties, RegisterRecords, Cancel);
	
	// Record of the records sets.
	PerformanceEstimationClientServer.StartTimeMeasurement("CreditNoteDocumentPostingMovementsRecord");
	
	// Writing of record sets
	DriveServer.WriteRecordSets(ThisObject);
	
	DriveServer.CreateRecordsInTasksRegisters(ThisObject, Cancel);
	
	// Subordinate tax invoice
	If Not Cancel Then
		WorkWithVAT.SubordinatedTaxInvoiceControl(DocumentWriteMode.Posting, Ref, DeletionMark);
	EndIf;
	
	// Control of occurrence of a negative balance.
	PerformanceEstimationClientServer.StartTimeMeasurement("CreditNoteDocumentPostingControl");
	Documents.CreditNote.RunControl(Ref, AdditionalProperties, Cancel);
	
	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
EndProcedure

// Procedure - event handler UndoPosting object.
//
Procedure UndoPosting(Cancel)
	
	// Initialization of additional properties for document posting
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Preparation of record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Writing of record sets
	DriveServer.WriteRecordSets(ThisObject);
	
	// Subordinate tax invoice
	If Not Cancel Then
		WorkWithVAT.SubordinatedTaxInvoiceControl(DocumentWriteMode.UndoPosting, Ref, DeletionMark);
	EndIf;
	
	DriveServer.CreateRecordsInTasksRegisters(ThisObject, Cancel);
	
	// Control of occurrence of a negative balance.
	PerformanceEstimationClientServer.StartTimeMeasurement("CreditNoteDocumentPostingControl");
	Documents.CreditNote.RunControl(Ref, AdditionalProperties, Cancel);

EndProcedure

// Procedure is filling the allocation amount.
//
Procedure FillAmountAllocation() Export
	
	ParentCompany = DriveServer.GetCompany(Company);
	
	// Filling default payment details.
	Query = New Query;
	Query.Text =
	"SELECT
	|	AccountsReceivableBalances.Company AS Company,
	|	AccountsReceivableBalances.Counterparty AS Counterparty,
	|	AccountsReceivableBalances.Contract AS Contract,
	|	AccountsReceivableBalances.Document AS Document,
	|	AccountsReceivableBalances.Order AS Order,
	|	AccountsReceivableBalances.SettlementsType AS SettlementsType,
	|	ISNULL(AccountsReceivableBalances.AmountBalance, 0) AS AmountBalance,
	|	ISNULL(AccountsReceivableBalances.AmountCurBalance, 0) AS AmountCurBalance
	|INTO AccountsReceivableBalances
	|FROM
	|	AccumulationRegister.AccountsReceivable.Balance(
	|			,
	|			Company = &Company
	|				AND Counterparty = &Counterparty
	|				AND &ContractTypesList
	|				AND SettlementsType = VALUE(Enum.SettlementsTypes.Debt)) AS AccountsReceivableBalances
	|
	|UNION ALL
	|
	|SELECT
	|	AccountsReceivableBalanceAndTurnovers.Company,
	|	AccountsReceivableBalanceAndTurnovers.Counterparty,
	|	AccountsReceivableBalanceAndTurnovers.Contract,
	|	AccountsReceivableBalanceAndTurnovers.Document,
	|	AccountsReceivableBalanceAndTurnovers.Order,
	|	AccountsReceivableBalanceAndTurnovers.SettlementsType,
	|	-AccountsReceivableBalanceAndTurnovers.AmountTurnover,
	|	-AccountsReceivableBalanceAndTurnovers.AmountCurTurnover
	|FROM
	|	AccumulationRegister.AccountsReceivable AS DocumentRegisterRecordsAccountsReceivable,
	|	AccumulationRegister.AccountsReceivable.BalanceAndTurnovers(
	|			,
	|			,
	|			Recorder,
	|			,
	|			Company = &Company
	|				AND Counterparty = &Counterparty
	|				AND SettlementsType = VALUE(Enum.SettlementsTypes.Debt)) AS AccountsReceivableBalanceAndTurnovers
	|WHERE
	|	AccountsReceivableBalanceAndTurnovers.Recorder = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccountsReceivableBalances.Company AS Company,
	|	AccountsReceivableBalances.Counterparty AS Counterparty,
	|	AccountsReceivableBalances.Contract AS Contract,
	|	CASE
	|		WHEN AccountsReceivableBalances.Counterparty.DoOperationsByDocuments
	|			THEN AccountsReceivableBalances.Document
	|		ELSE UNDEFINED
	|	END AS Document,
	|	CASE
	|		WHEN AccountsReceivableBalances.Counterparty.DoOperationsByOrders
	|			THEN AccountsReceivableBalances.Order
	|		ELSE UNDEFINED
	|	END AS Order,
	|	AccountsReceivableBalances.SettlementsType AS SettlementsType,
	|	SUM(AccountsReceivableBalances.AmountBalance) AS AmountBalance,
	|	SUM(AccountsReceivableBalances.AmountCurBalance) AS AmountCurrDocument,
	|	AccountsReceivableBalances.Document.Date AS DocumentDate,
	|	ExchangeRatesOfDocument.ExchangeRate AS CashAssetsRate,
	|	ExchangeRatesOfDocument.Multiplicity AS CashMultiplicity,
	|	SettlementsExchangeRates.ExchangeRate AS ExchangeRate,
	|	SettlementsExchangeRates.Multiplicity AS Multiplicity
	|FROM
	|	AccountsReceivableBalances AS AccountsReceivableBalances
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&Period, Currency = &Currency) AS ExchangeRatesOfDocument
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&Period, ) AS SettlementsExchangeRates
	|		ON AccountsReceivableBalances.Contract.SettlementsCurrency = SettlementsExchangeRates.Currency
	|WHERE
	|	AccountsReceivableBalances.AmountCurBalance > 0
	|
	|GROUP BY
	|	AccountsReceivableBalances.Company,
	|	AccountsReceivableBalances.Counterparty,
	|	AccountsReceivableBalances.Contract,
	|	AccountsReceivableBalances.Document,
	|	AccountsReceivableBalances.Order,
	|	AccountsReceivableBalances.SettlementsType,
	|	AccountsReceivableBalances.Document.Date,
	|	ExchangeRatesOfDocument.ExchangeRate,
	|	ExchangeRatesOfDocument.Multiplicity,
	|	SettlementsExchangeRates.ExchangeRate,
	|	SettlementsExchangeRates.Multiplicity,
	|	CASE
	|		WHEN AccountsReceivableBalances.Counterparty.DoOperationsByDocuments
	|			THEN AccountsReceivableBalances.Document
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN AccountsReceivableBalances.Counterparty.DoOperationsByOrders
	|			THEN AccountsReceivableBalances.Order
	|		ELSE UNDEFINED
	|	END
	|
	|ORDER BY
	|	DocumentDate";
		
	Query.SetParameter("Company", 		ParentCompany);
	Query.SetParameter("Counterparty",	Counterparty);
	Query.SetParameter("Period", 		New Boundary(Date, BoundaryType.Including));
	Query.SetParameter("Currency", 		DocumentCurrency);
	Query.SetParameter("Ref", 			Ref);
	
	NeedFilterByContracts	= DriveReUse.CounterpartyContractsControlNeeded();
	ContractTypesList 		= Catalogs.CounterpartyContracts.GetContractKindsListForDocument(Ref, OperationKind);
	
	If NeedFilterByContracts
	   AND Counterparty.DoOperationsByContracts Then
		Query.Text = StrReplace(Query.Text, "&ContractTypesList", "Contract.ContractType IN (&ContractTypesList)");
		Query.SetParameter("ContractTypesList", ContractTypesList);
	Else
		Query.Text = StrReplace(Query.Text, "&ContractTypesList", "TRUE");
	EndIf;
	
	SelectionOfQueryResult = Query.Execute().Select();
	
	AmountAllocation.Clear();
	If OperationKind <> PredefinedValue("Enum.OperationTypesCreditNote.SalesReturn")
		AND NOT AmountIncludesVAT Then
		InitialAmountLeftToDistribute = AdjustmentAmount + VATAmount;
	Else
		InitialAmountLeftToDistribute = AdjustmentAmount;
	EndIf;
	AmountLeftToDistribute = InitialAmountLeftToDistribute; 
	
	While AmountLeftToDistribute > 0 Do
		
		NewRow = AmountAllocation.Add();
		
		If SelectionOfQueryResult.Next() Then
			
			FillPropertyValues(NewRow, SelectionOfQueryResult);
			
			If SelectionOfQueryResult.AmountCurrDocument <= AmountLeftToDistribute Then // balance amount is less or equal than it is necessary to distribute
				
				NewRow.OffsetAmount		= SelectionOfQueryResult.AmountCurrDocument;
				AmountLeftToDistribute	= AmountLeftToDistribute - SelectionOfQueryResult.AmountCurrDocument;
				
			Else // Balance amount is greater than it is necessary to distribute
				
				NewRow.OffsetAmount 	= AmountLeftToDistribute;
				AmountLeftToDistribute	= 0;
				
			EndIf;
			
			NewRow.VATRate = VATRate;
			NewRow.VATAmount = NewRow.OffsetAmount - (NewRow.OffsetAmount) / ((VATRate.Rate + 100) / 100);
			
		Else
			
			NewRow.Contract		= Contract;
			NewRow.AdvanceFlag	= True;
			NewRow.OffsetAmount	= AmountLeftToDistribute;
			NewRow.VATRate		= VATRate;
			NewRow.VATAmount = NewRow.OffsetAmount - (NewRow.OffsetAmount) / ((VATRate.Rate + 100) / 100);
			
			AmountLeftToDistribute	= 0;
			
		EndIf;
		
	EndDo;
	
	AmountLeftToDistribute = InitialAmountLeftToDistribute - AmountAllocation.Total("OffsetAmount");
	If AmountLeftToDistribute <> 0 Then
		AmountAllocation[AmountAllocation.Count()-1].OffsetAmount = AmountAllocation[AmountAllocation.Count()-1].OffsetAmount + AmountLeftToDistribute;
	EndIf;
	
	VATAmountLeftToDistribute = VATAmount - AmountAllocation.Total("VATAmount");
	If VATAmountLeftToDistribute <> 0 Then
		AmountAllocation[AmountAllocation.Count()-1].VATAmount = AmountAllocation[AmountAllocation.Count()-1].VATAmount + VATAmountLeftToDistribute;
	EndIf;
	
	If AmountAllocation.Count() = 0 Then
		AmountAllocation.Add();
		AmountAllocation[0].OffsetAmount = AdjustmentAmount;
	EndIf;
	
EndProcedure

Procedure FillSalesRep()
	
	SalesRep = Undefined;
	If Not ValueIsFilled(SalesRep) Then
		SalesRep = CommonUse.ObjectAttributeValue(Counterparty, "SalesRep");
	EndIf;
	
	For Each CurrentRow In Inventory Do
		Order = Undefined;
		If ValueIsFilled(CurrentRow.SalesRep) Then
			Continue;
		ElsIf ValueIsFilled(CurrentRow.Order)
			And CurrentRow.Order <> Order Then
			CurrentRow.SalesRep = CommonUse.ObjectAttributeValue(CurrentRow.Order, "SalesRep");
			Order = CurrentRow.SalesRep;
		Else
			CurrentRow.SalesRep = SalesRep;
		EndIf;
	EndDo;
	
EndProcedure

#EndRegion

#EndIf
