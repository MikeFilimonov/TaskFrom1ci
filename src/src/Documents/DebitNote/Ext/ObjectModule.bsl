#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

Procedure CheckReturnedQuantity(Cancel)
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	DebitNoteInventory.Products AS Products,
		|	DebitNoteInventory.Characteristic AS Characteristic,
		|	DebitNoteInventory.Batch AS Batch,
		|	DebitNoteInventory.MeasurementUnit AS MeasurementUnit,
		|	DebitNoteInventory.Quantity AS Quantity
		|INTO DebitNoteInventory
		|FROM
		|	Document.DebitNote.Inventory AS DebitNoteInventory
		|WHERE
		|	DebitNoteInventory.Ref = &Ref
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	SupplierInvoiceInventory.Products AS Products,
		|	SupplierInvoiceInventory.Characteristic AS Characteristic,
		|	SupplierInvoiceInventory.Batch AS Batch,
		|	SUM(SupplierInvoiceInventory.Quantity) AS Quantity,
		|	SupplierInvoiceInventory.MeasurementUnit AS MeasurementUnit
		|INTO SupplierInvoice
		|FROM
		|	Document.SupplierInvoice.Inventory AS SupplierInvoiceInventory
		|WHERE
		|	SupplierInvoiceInventory.Ref = &BasisDocument
		|
		|GROUP BY
		|	SupplierInvoiceInventory.Products,
		|	SupplierInvoiceInventory.Characteristic,
		|	SupplierInvoiceInventory.Batch,
		|	SupplierInvoiceInventory.MeasurementUnit
		|
		|UNION ALL
		|
		|SELECT
		|	SupplierInvoiceExpenses.Products,
		|	VALUE(Catalog.ProductsCharacteristics.EmptyRef),
		|	VALUE(Catalog.ProductsBatches.EmptyRef),
		|	SUM(SupplierInvoiceExpenses.Quantity),
		|	SupplierInvoiceExpenses.MeasurementUnit
		|FROM
		|	Document.SupplierInvoice.Expenses AS SupplierInvoiceExpenses
		|WHERE
		|	SupplierInvoiceExpenses.Ref = &BasisDocument
		|
		|GROUP BY
		|	SupplierInvoiceExpenses.Products,
		|	SupplierInvoiceExpenses.MeasurementUnit
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	DebitNoteInventory.Batch AS Batch,
		|	DebitNoteInventory.Characteristic AS Characteristic,
		|	DebitNoteInventory.Products AS Products,
		|	-DebitNoteInventory.Quantity AS Quantity,
		|	DebitNoteInventory.Quantity AS ReturnedQuantity,
		|	0 AS InitialQuantity,
		|	DebitNoteInventory.MeasurementUnit AS MeasurementUnit
		|INTO UnionResult
		|FROM
		|	Document.DebitNote.Inventory AS DebitNoteInventory
		|WHERE
		|	DebitNoteInventory.Ref.BasisDocument = &BasisDocument
		|	AND DebitNoteInventory.Ref.Posted
		|	AND DebitNoteInventory.Ref <> &Ref
		|
		|UNION ALL
		|
		|SELECT
		|	DebitNoteInventory.Batch,
		|	DebitNoteInventory.Characteristic,
		|	DebitNoteInventory.Products,
		|	-DebitNoteInventory.Quantity,
		|	DebitNoteInventory.Quantity,
		|	0,
		|	DebitNoteInventory.MeasurementUnit
		|FROM
		|	Document.DebitNote.Inventory AS DebitNoteInventory
		|		INNER JOIN Document.GoodsReturn AS GoodsReturn
		|		ON (GoodsReturn.SalesDocument = &BasisDocument)
		|			AND DebitNoteInventory.Ref.BasisDocument = GoodsReturn.Ref
		|WHERE
		|	DebitNoteInventory.Ref <> &Ref
		|	AND DebitNoteInventory.Ref.Posted
		|
		|UNION ALL
		|
		|SELECT
		|	SupplierInvoice.Batch,
		|	SupplierInvoice.Characteristic,
		|	SupplierInvoice.Products,
		|	SUM(SupplierInvoice.Quantity),
		|	0,
		|	SUM(SupplierInvoice.Quantity),
		|	SupplierInvoice.MeasurementUnit
		|FROM
		|	SupplierInvoice AS SupplierInvoice
		|
		|GROUP BY
		|	SupplierInvoice.Characteristic,
		|	SupplierInvoice.MeasurementUnit,
		|	SupplierInvoice.Products,
		|	SupplierInvoice.Batch
		|
		|UNION ALL
		|
		|SELECT
		|	DebitNoteInventory.Batch,
		|	DebitNoteInventory.Characteristic,
		|	DebitNoteInventory.Products,
		|	-DebitNoteInventory.Quantity,
		|	0,
		|	0,
		|	DebitNoteInventory.MeasurementUnit
		|FROM
		|	DebitNoteInventory AS DebitNoteInventory
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
	
	Query.SetParameter("BasisDocument",	?(TypeOf(BasisDocument) = Type("DocumentRef.SupplierInvoice"),
										BasisDocument, BasisDocument.SupplierInvoice));
	Query.SetParameter("Ref",			Ref);
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	
	While Selection.Next() Do
		If Selection.ReturnedQuantity > 0 Then
			MessageToUser = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = '%1 %2 of %3 was previously returned by other Debit note documents.
				     |You have only %4 %2 left to return. See subordinate structure of initial Supplier invoice for details.'"),
				Selection.ReturnedQuantity, 
				Selection.MeasurementUnit,
				Selection.Products + ?(ValueIsFilled(Selection.Characteristic), ", " + Selection.Characteristic, "")
				 + ?(ValueIsFilled(Selection.Batch), ", " + Selection.Batch, ""),
				Selection.AvailableQuantity,);
		Else
			MessageToUser = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'There is more quantity of returned goods ""%1"" than in initial Supplier Invoice.'"),
				Selection.Products + ?(ValueIsFilled(Selection.Characteristic), ", " + Selection.Characteristic, "")
				 + ?(ValueIsFilled(Selection.Batch), ", " + Selection.Batch, ""));
		EndIf;
			
		CommonUseClientServer.MessageToUser(MessageToUser,,,,Cancel);
	EndDo;
	
EndProcedure
	
Procedure FillBySupplierInvoice(FillingData) Export
	
	BasisDocument = FillingData.Ref;

	FillPropertyValues(ThisObject, FillingData,, "Ref, Number, Date, Author, Posted, DeletionMark");
	DocumentAmount	= 0;
	OperationKind	= Enums.OperationTypesDebitNote.PurchaseReturn;
	VATRate 		= InformationRegisters.AccountingPolicy.GetDefaultVATRate(Date, Company);
	
	FillInventory(FillingData);

EndProcedure

Procedure FillByGoodsReturn(FillingData) Export
	
	BasisDocument = FillingData.Ref;

	FillPropertyValues(ThisObject, FillingData,, "Ref, Number, Date, Posted, DeletionMark");
	AdjustmentAmount	= FillingData.DocumentAmount;
	OperationKind		= Enums.OperationTypesDebitNote.PurchaseReturn;
	VATRate 			= InformationRegisters.AccountingPolicy.GetDefaultVATRate(Date, Company);
	VATAmount			= 0;
	
	If ValueIsFilled(FillingData.SupplierInvoice) Then
		AmountIncludesVAT = FillingData.SupplierInvoice.AmountIncludesVAT;
	EndIf;
	
	FillInventory(FillingData);

EndProcedure

Procedure FillInventory(BasisDocument) Export
	
	If BasisDocument = Undefined Then 
		Return;
	EndIf;
	
	DocumentType = BasisDocument.Metadata().Name;
	
	Query = New Query;
	Query.SetParameter("AmountIncludesVAT",	BasisDocument.AmountIncludesVAT);
	Query.SetParameter("BasisDocument",		BasisDocument);
	Query.SetParameter("Ref",				Ref);
	
	If TypeOf(BasisDocument) = Type("DocumentRef.GoodsReturn") Then
		Query.Text = 
		"SELECT
		|	GoodsReturnProducts.Price AS Price,
		|	GoodsReturnProducts.MeasurementUnit AS MeasurementUnit,
		|	GoodsReturnProducts.Characteristic AS Characteristic,
		|	GoodsReturnProducts.Batch AS Batch,
		|	SUM(GoodsReturnProducts.InitialQuantity) AS InitialQuantity,
		|	SUM(GoodsReturnProducts.Amount) AS InitialAmount,
		|	GoodsReturnProducts.Ref.SupplierInvoice AS Document,
		|	SUM(GoodsReturnProducts.Quantity) AS Quantity,
		|	GoodsReturnProducts.VATRate AS VATRate,
		|	GoodsReturnProducts.Products AS Products,
		|	SUM(GoodsReturnProducts.Amount) AS Amount,
		|	SUM(GoodsReturnProducts.VATAmount) AS VATAmount,
		|	GoodsReturnProducts.SerialNumbers AS SerialNumbers,
		|	GoodsReturnProducts.ConnectionKey AS ConnectionKey,
		|	GoodsReturnProducts.Price AS InitialPrice,
		|	GoodsReturnProducts.LineNumber AS LineNumber,
		|	GoodsReturnProducts.Order AS Order,
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
		|	GoodsReturnProducts.Ref.SupplierInvoice,
		|	GoodsReturnProducts.Products,
		|	GoodsReturnProducts.SerialNumbers,
		|	GoodsReturnProducts.ConnectionKey,
		|	GoodsReturnProducts.LineNumber,
		|	GoodsReturnProducts.Order,
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
		|	SupplierInvoiceInventory.Price AS Price,
		|	SupplierInvoiceInventory.MeasurementUnit AS MeasurementUnit,
		|	SupplierInvoiceInventory.Products AS Products,
		|	SupplierInvoiceInventory.Characteristic AS Characteristic,
		|	SupplierInvoiceInventory.Batch AS Batch,
		|	SUM(SupplierInvoiceInventory.Quantity) AS Quantity,
		|	SUM(SupplierInvoiceInventory.Amount) AS Amount,
		|	SupplierInvoiceInventory.VATRate AS VATRate,
		|	SupplierInvoiceInventory.SerialNumbers AS SerialNumbers,
		|	SupplierInvoiceInventory.ConnectionKey AS ConnectionKey,
		|	SupplierInvoiceInventory.Order AS Order
		|INTO SupplierInvoice
		|FROM
		|	Document.SupplierInvoice.Inventory AS SupplierInvoiceInventory
		|WHERE
		|	SupplierInvoiceInventory.Ref = &BasisDocument
		|
		|GROUP BY
		|	SupplierInvoiceInventory.SerialNumbers,
		|	SupplierInvoiceInventory.Products,
		|	SupplierInvoiceInventory.MeasurementUnit,
		|	SupplierInvoiceInventory.Characteristic,
		|	SupplierInvoiceInventory.Batch,
		|	SupplierInvoiceInventory.VATRate,
		|	SupplierInvoiceInventory.ConnectionKey,
		|	SupplierInvoiceInventory.Price,
		|	SupplierInvoiceInventory.Order
		|
		|UNION ALL
		|
		|SELECT
		|	SupplierInvoiceExpenses.Price,
		|	SupplierInvoiceExpenses.MeasurementUnit,
		|	SupplierInvoiceExpenses.Products,
		|	VALUE(Catalog.ProductsCharacteristics.EmptyRef),
		|	VALUE(Catalog.ProductsBatches.EmptyRef),
		|	SUM(SupplierInvoiceExpenses.Quantity),
		|	SUM(SupplierInvoiceExpenses.Amount),
		|	SupplierInvoiceExpenses.VATRate,
		|	VALUE(Catalog.SerialNumbers.EmptyRef),
		|	0,
		|	SupplierInvoiceExpenses.Order
		|FROM
		|	Document.SupplierInvoice.Expenses AS SupplierInvoiceExpenses
		|WHERE
		|	SupplierInvoiceExpenses.Ref = &BasisDocument
		|
		|GROUP BY
		|	SupplierInvoiceExpenses.VATRate,
		|	SupplierInvoiceExpenses.Products,
		|	SupplierInvoiceExpenses.MeasurementUnit,
		|	SupplierInvoiceExpenses.Price,
		|	SupplierInvoiceExpenses.Order
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	PurchasesTurnovers.Products AS Products,
		|	PurchasesTurnovers.Characteristic AS Characteristic,
		|	PurchasesTurnovers.Batch AS Batch,
		|	PurchasesTurnovers.VATRate AS VATRate,
		|	SUM(PurchasesTurnovers.QuantityTurnover) AS QuantityBalance
		|INTO Purchases
		|FROM
		|	AccumulationRegister.Purchases.Turnovers(, , Recorder, Document = &BasisDocument) AS PurchasesTurnovers
		|WHERE
		|	PurchasesTurnovers.Recorder <> &Ref
		|
		|GROUP BY
		|	PurchasesTurnovers.Products,
		|	PurchasesTurnovers.Characteristic,
		|	PurchasesTurnovers.Batch,
		|	PurchasesTurnovers.VATRate
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	Purchases.Products AS Products,
		|	Purchases.Characteristic AS Characteristic,
		|	Purchases.Batch AS Batch,
		|	Purchases.VATRate AS VATRate,
		|	Purchases.QuantityBalance AS QuantityBalance
		|INTO Balances
		|FROM
		|	Purchases AS Purchases
		|WHERE
		|	Purchases.QuantityBalance > 0
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	SupplierInvoice.Price AS InitialPrice,
		|	SupplierInvoice.MeasurementUnit AS MeasurementUnit,
		|	SupplierInvoice.Products AS Products,
		|	SupplierInvoice.Characteristic AS Characteristic,
		|	SupplierInvoice.Batch AS Batch,
		|	SupplierInvoice.Quantity AS InitialQuantity,
		|	SupplierInvoice.Amount AS InitialAmount,
		|	SupplierInvoice.VATRate AS VATRate,
		|	SupplierInvoice.SerialNumbers AS SerialNumbers,
		|	SupplierInvoice.ConnectionKey AS ConnectionKey,
		|	SupplierInvoice.Order AS Order,
		|	SupplierInvoice.Price AS Price
		|FROM
		|	SupplierInvoice AS SupplierInvoice
		|		INNER JOIN Balances AS Balances
		|		ON SupplierInvoice.Products = Balances.Products
		|			AND SupplierInvoice.Characteristic = Balances.Characteristic
		|			AND SupplierInvoice.Batch = Balances.Batch
		|			AND SupplierInvoice.VATRate = Balances.VATRate";
	EndIf;
	
	QueryResult = Query.Execute();
	Inventory.Load(QueryResult.Unload());
	
	AccountingPolicy = InformationRegisters.AccountingPolicy.GetAccountingPolicy(Date, Company);
	UseGoodsReturnToSupplier = AccountingPolicy.UseGoodsReturnToSupplier;
	
	For Each Row In Inventory Do
		Rate = DriveReUse.GetVATRateValue(Row.VATRate);
		VATAmount = VATAmount + Row.Amount * Rate / 100;
		If UseGoodsReturnToSupplier Then
			Row.SerialNumbers = "";
		EndIf;
	EndDo;
	
	If Not UseGoodsReturnToSupplier Then
		WorkWithSerialNumbers.FillTSSerialNumbersByConnectionKey(ThisObject, BasisDocument);
	EndIf;
	
EndProcedure

Procedure FillByCashOrBankPayment(FillingData, QueryText)
	
	BasisDocument = FillingData;
	
	FillPropertyValues(ThisObject, FillingData,, "Ref, Number, Date, Posted, DeletionMark, BasisDocument, Comment, OperationKind");
	
	OperationKind		= Enums.OperationTypesDebitNote.DiscountReceived;
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
		
		DebitedTransactions.Load(QueryResult2.Unload());
		
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

Procedure FillByCashVoucher(FillingData) Export
	
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
	|	CashVoucherPaymentDetails.Contract AS Contract,
	|	CashVoucherPaymentDetails.Document AS Document,
	|	CashVoucherPaymentDetails.Order AS Order,
	|	CashVoucherPaymentDetails.SettlementsEPDAmount AS OffsetAmount
	|INTO TempPaymentDelails
	|FROM
	|	Document.CashVoucher.PaymentDetails AS CashVoucherPaymentDetails
	|WHERE
	|	CashVoucherPaymentDetails.Ref = &Ref
	|	AND CashVoucherPaymentDetails.SettlementsEPDAmount > 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TempPaymentDelails.Contract AS Contract,
	|	TempPaymentDelails.Document AS Document,
	|	TempPaymentDelails.Order AS Order,
	|	TempPaymentDelails.OffsetAmount AS OffsetAmount,
	|	SupplierInvoice.ProvideEPD AS ProvideEPD,
	|	SupplierInvoice.Number AS Number,
	|	SupplierInvoice.Date AS Date,
	|	ISNULL(Contracts.SettlementsCurrency, VALUE(Catalog.Currencies.EmptyRef)) AS SettlementsCurrency
	|INTO TempPaymentDelailsWithInvoice
	|FROM
	|	TempPaymentDelails AS TempPaymentDelails
	|		INNER JOIN Document.SupplierInvoice AS SupplierInvoice
	|		ON TempPaymentDelails.Document = SupplierInvoice.Ref
	|		LEFT JOIN Catalog.CounterpartyContracts AS Contracts
	|		ON TempPaymentDelails.Contract = Contracts.Ref
	|WHERE
	|	(SupplierInvoice.ProvideEPD = VALUE(Enum.VariantsOfProvidingEPD.CreditDebitNote)
	|			OR SupplierInvoice.ProvideEPD = VALUE(Enum.VariantsOfProvidingEPD.CreditDebitNoteWithVATAdjustment))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	TempPaymentDelailsWithInvoice.Document AS Document
	|INTO SupplierInvoiceTable
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
	|	PurchasesTurnovers.Recorder AS Document,
	|	PurchasesTurnovers.VATRate AS VATRate,
	|	CASE
	|		WHEN PurchasesTurnovers.AmountTurnover + PurchasesTurnovers.VATAmountTurnover > 0
	|			THEN PurchasesTurnovers.AmountTurnover + PurchasesTurnovers.VATAmountTurnover
	|		ELSE -(PurchasesTurnovers.AmountTurnover + PurchasesTurnovers.VATAmountTurnover)
	|	END AS Amount,
	|	CASE
	|		WHEN PurchasesTurnovers.VATAmountTurnover > 0
	|			THEN PurchasesTurnovers.VATAmountTurnover
	|		ELSE -PurchasesTurnovers.VATAmountTurnover
	|	END AS VATAmount
	|FROM
	|	AccumulationRegister.Purchases.Turnovers(, , Recorder, ) AS PurchasesTurnovers
	|		INNER JOIN SupplierInvoiceTable AS SupplierInvoiceTable
	|		ON PurchasesTurnovers.Recorder = SupplierInvoiceTable.Document";
	
	FillByCashOrBankPayment(FillingData, QueryText);
	
EndProcedure

Procedure FillByPaymentExpense(FillingData) Export
	
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
	|	PaymentExpensePaymentDetails.Contract AS Contract,
	|	PaymentExpensePaymentDetails.Document AS Document,
	|	PaymentExpensePaymentDetails.Order AS Order,
	|	PaymentExpensePaymentDetails.SettlementsEPDAmount AS OffsetAmount
	|INTO TempPaymentDelails
	|FROM
	|	Document.PaymentExpense.PaymentDetails AS PaymentExpensePaymentDetails
	|WHERE
	|	PaymentExpensePaymentDetails.Ref = &Ref
	|	AND PaymentExpensePaymentDetails.SettlementsEPDAmount > 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TempPaymentDelails.Contract AS Contract,
	|	TempPaymentDelails.Document AS Document,
	|	TempPaymentDelails.Order AS Order,
	|	TempPaymentDelails.OffsetAmount AS OffsetAmount,
	|	SupplierInvoice.ProvideEPD AS ProvideEPD,
	|	SupplierInvoice.Number AS Number,
	|	SupplierInvoice.Date AS Date,
	|	ISNULL(Contracts.SettlementsCurrency, VALUE(Catalog.Currencies.EmptyRef)) AS SettlementsCurrency
	|INTO TempPaymentDelailsWithInvoice
	|FROM
	|	TempPaymentDelails AS TempPaymentDelails
	|		INNER JOIN Document.SupplierInvoice AS SupplierInvoice
	|		ON TempPaymentDelails.Document = SupplierInvoice.Ref
	|		LEFT JOIN Catalog.CounterpartyContracts AS Contracts
	|		ON TempPaymentDelails.Contract = Contracts.Ref
	|WHERE
	|	(SupplierInvoice.ProvideEPD = VALUE(Enum.VariantsOfProvidingEPD.CreditDebitNote)
	|			OR SupplierInvoice.ProvideEPD = VALUE(Enum.VariantsOfProvidingEPD.CreditDebitNoteWithVATAdjustment))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	TempPaymentDelailsWithInvoice.Document AS Document
	|INTO SupplierInvoiceTable
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
	|	PurchasesTurnovers.Recorder AS Document,
	|	PurchasesTurnovers.VATRate AS VATRate,
	|	CASE
	|		WHEN PurchasesTurnovers.AmountTurnover + PurchasesTurnovers.VATAmountTurnover > 0
	|			THEN PurchasesTurnovers.AmountTurnover + PurchasesTurnovers.VATAmountTurnover
	|		ELSE -(PurchasesTurnovers.AmountTurnover + PurchasesTurnovers.VATAmountTurnover)
	|	END AS Amount,
	|	CASE
	|		WHEN PurchasesTurnovers.VATAmountTurnover > 0
	|			THEN PurchasesTurnovers.VATAmountTurnover
	|		ELSE -PurchasesTurnovers.VATAmountTurnover
	|	END AS VATAmount
	|FROM
	|	AccumulationRegister.Purchases.Turnovers(, , Recorder, ) AS PurchasesTurnovers
	|		INNER JOIN SupplierInvoiceTable AS SupplierInvoiceTable
	|		ON PurchasesTurnovers.Recorder = SupplierInvoiceTable.Document";
	
	FillByCashOrBankPayment(FillingData, QueryText);
	
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
	If OperationKind <> Enums.OperationTypesDebitNote.PurchaseReturn Then
		DocumentAmount = DocumentAmount + ?(AmountIncludesVAT, 0, VATAmount);
	EndIf;
	
	AdditionalProperties.Insert("WriteMode", WriteMode);
	
EndProcedure

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	AccountingPolicy = InformationRegisters.AccountingPolicy.GetAccountingPolicy(Date, Company);
	If OperationKind <> Enums.OperationTypesDebitNote.PurchaseReturn 
		Or AccountingPolicy.UseGoodsReturnToSupplier Then
		CheckedAttributes.Delete(CheckedAttributes.Find("StructuralUnit"));
	EndIf;
	
	If OperationKind = Enums.OperationTypesDebitNote.PurchaseReturn Then 
		CheckedAttributes.Delete(CheckedAttributes.Find("AdjustmentAmount"));
		CheckedAttributes.Delete(CheckedAttributes.Find("GLAccount"));
	Else
		CheckedAttributes.Delete(CheckedAttributes.Find("Inventory"));
	EndIf;
	
	If Not AccountingPolicy.UseGoodsReturnToSupplier Then
		WorkWithSerialNumbers.FillCheckingSerialNumbers(Cancel, Inventory, SerialNumbers, StructuralUnit, ThisObject);
	EndIf;
	
EndProcedure

// Procedure - handler of the FillingProcessor event.
//
Procedure Filling(FillingData, StandardProcessing) Export
		
	FillingStrategy = New Map;
	FillingStrategy[Type("DocumentRef.SupplierInvoice")]	= "FillBySupplierInvoice";
	FillingStrategy[Type("DocumentRef.GoodsReturn")]		= "FillByGoodsReturn";
	FillingStrategy[Type("DocumentRef.CashVoucher")]		= "FillByCashVoucher";
	FillingStrategy[Type("DocumentRef.PaymentExpense")]		= "FillByPaymentExpense";
	
	If TypeOf(FillingData) = Type("DocumentRef.CashVoucher")
		OR TypeOf(FillingData) = Type("DocumentRef.PaymentExpense") Then
		
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
	
	If OperationKind = Enums.OperationTypesDebitNote.PurchaseReturn Then
		CheckReturnedQuantity(Cancel);
	EndIf;
	
	// Initialization of additional properties for document posting
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Document data initialization.
	PerformanceEstimationClientServer.StartTimeMeasurement("DebitNoteDocumentPostingInitialization");
	
	// Initialization of document data
	Documents.DebitNote.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Preparation of record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Account for in accounting sections.
	PerformanceEstimationClientServer.StartTimeMeasurement("DebitNoteDocumentPostingMovementsCreation");
	
	DriveServer.ReflectPurchases(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountsPayable(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectIncomeAndExpenses(AdditionalProperties, RegisterRecords, Cancel);
	
	If OperationKind = Enums.OperationTypesDebitNote.PurchaseReturn Then 
		If NOT AdditionalProperties.AccountingPolicy.UseGoodsReturnToSupplier Then
			DriveServer.ReflectInventoryInWarehouses(AdditionalProperties, RegisterRecords, Cancel);
			DriveServer.ReflectInventory(AdditionalProperties, RegisterRecords, Cancel);
			DriveServer.ReflectTheSerialNumbersOfTheGuarantee(AdditionalProperties, RegisterRecords, Cancel);
			DriveServer.ReflectTheSerialNumbersBalance(AdditionalProperties, RegisterRecords, Cancel);
		EndIf;
	EndIf;
	
	If GetFunctionalOption("UseVAT")
		AND VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then
		
		If WorkWithVAT.GetUseTaxInvoiceForPostingVAT(Date, Company) Then
			DriveServer.ReflectVATIncurred(AdditionalProperties, RegisterRecords, Cancel);
		Else
			DriveServer.ReflectVATInput(AdditionalProperties, RegisterRecords, Cancel);
		EndIf;
		
	EndIf;
	
	DriveServer.ReflectAccountingJournalEntries(AdditionalProperties, RegisterRecords, Cancel);
	
	// Record of the records sets.
	PerformanceEstimationClientServer.StartTimeMeasurement("DebitNoteDocumentPostingMovementsRecord");
		
	// Writing of record sets
	DriveServer.WriteRecordSets(ThisObject);
	
	// Subordinate tax invoice
	If Not Cancel Then
		WorkWithVAT.SubordinatedTaxInvoiceControl(DocumentWriteMode.Posting, Ref, DeletionMark);
	EndIf;
	
	// Control of occurrence of a negative balance.
	PerformanceEstimationClientServer.StartTimeMeasurement("DebitNoteDocumentPostingControl");
	Documents.DebitNote.RunControl(Ref, AdditionalProperties, Cancel);
	
	DriveServer.CreateRecordsInTasksRegisters(ThisObject, Cancel);
	
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
	PerformanceEstimationClientServer.StartTimeMeasurement("DebitNoteDocumentPostingControl");
	Documents.DebitNote.RunControl(Ref, AdditionalProperties, Cancel);
	
EndProcedure

// Procedure is filling the allocation amount.
//
Procedure FillAmountAllocation() Export
	
	ParentCompany = DriveServer.GetCompany(Company);
	
	// Filling default payment details.
	Query = New Query;
	Query.Text =
	"SELECT
	|	AccountsPayableBalances.Company AS Company,
	|	AccountsPayableBalances.Counterparty AS Counterparty,
	|	AccountsPayableBalances.Contract AS Contract,
	|	AccountsPayableBalances.Document AS Document,
	|	AccountsPayableBalances.Order AS Order,
	|	AccountsPayableBalances.SettlementsType AS SettlementsType,
	|	ISNULL(AccountsPayableBalances.AmountBalance, 0) AS AmountBalance,
	|	ISNULL(AccountsPayableBalances.AmountCurBalance, 0) AS AmountCurBalance
	|INTO AccountsPayableBalances
	|FROM
	|	AccumulationRegister.AccountsPayable.Balance(
	|			&Period,
	|			Company = &Company
	|				AND Counterparty = &Counterparty
	|				AND &ContractTypesList
	|				AND SettlementsType = VALUE(Enum.SettlementsTypes.Debt)) AS AccountsPayableBalances
	|
	|UNION ALL
	|
	|SELECT
	|	AccountsPayableBalanceAndTurnovers.Company,
	|	AccountsPayableBalanceAndTurnovers.Counterparty,
	|	AccountsPayableBalanceAndTurnovers.Contract,
	|	AccountsPayableBalanceAndTurnovers.Document,
	|	AccountsPayableBalanceAndTurnovers.Order,
	|	AccountsPayableBalanceAndTurnovers.SettlementsType,
	|	-AccountsPayableBalanceAndTurnovers.AmountTurnover,
	|	-AccountsPayableBalanceAndTurnovers.AmountCurTurnover
	|FROM
	|	AccumulationRegister.AccountsPayable AS DocumentRegisterRecordsVendorSettlements,
	|	AccumulationRegister.AccountsPayable.BalanceAndTurnovers(
	|			,
	|			&Period,
	|			Recorder,
	|			,
	|			Company = &Company
	|				AND Counterparty = &Counterparty
	|				AND SettlementsType = VALUE(Enum.SettlementsTypes.Debt)) AS AccountsPayableBalanceAndTurnovers
	|WHERE
	|	AccountsPayableBalanceAndTurnovers.Recorder = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccountsPayableBalances.Company AS Company,
	|	AccountsPayableBalances.Counterparty AS Counterparty,
	|	AccountsPayableBalances.Contract AS Contract,
	|	CASE
	|		WHEN AccountsPayableBalances.Counterparty.DoOperationsByDocuments
	|			THEN AccountsPayableBalances.Document
	|		ELSE UNDEFINED
	|	END AS Document,
	|	CASE
	|		WHEN AccountsPayableBalances.Counterparty.DoOperationsByOrders
	|			THEN AccountsPayableBalances.Order
	|		ELSE VALUE(Document.PurchaseOrder.EmptyRef)
	|	END AS Order,
	|	AccountsPayableBalances.SettlementsType AS SettlementsType,
	|	SUM(AccountsPayableBalances.AmountBalance) AS AmountBalance,
	|	SUM(AccountsPayableBalances.AmountCurBalance) AS AmountCurrDocument,
	|	AccountsPayableBalances.Document.Date AS DocumentDate,
	|	ExchangeRatesOfDocument.ExchangeRate AS CashAssetsRate,
	|	ExchangeRatesOfDocument.Multiplicity AS CashMultiplicity,
	|	SettlementsExchangeRates.ExchangeRate AS ExchangeRate,
	|	SettlementsExchangeRates.Multiplicity AS Multiplicity
	|FROM
	|	AccountsPayableBalances AS AccountsPayableBalances
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&Period, Currency = &Currency) AS ExchangeRatesOfDocument
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&Period, ) AS SettlementsExchangeRates
	|		ON AccountsPayableBalances.Contract.SettlementsCurrency = SettlementsExchangeRates.Currency
	|WHERE
	|	AccountsPayableBalances.AmountCurBalance > 0
	|
	|GROUP BY
	|	AccountsPayableBalances.Company,
	|	AccountsPayableBalances.Counterparty,
	|	AccountsPayableBalances.Contract,
	|	AccountsPayableBalances.Document,
	|	AccountsPayableBalances.Order,
	|	AccountsPayableBalances.SettlementsType,
	|	AccountsPayableBalances.Document.Date,
	|	ExchangeRatesOfDocument.ExchangeRate,
	|	ExchangeRatesOfDocument.Multiplicity,
	|	SettlementsExchangeRates.ExchangeRate,
	|	SettlementsExchangeRates.Multiplicity,
	|	CASE
	|		WHEN AccountsPayableBalances.Counterparty.DoOperationsByDocuments
	|			THEN AccountsPayableBalances.Document
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN AccountsPayableBalances.Counterparty.DoOperationsByOrders
	|			THEN AccountsPayableBalances.Order
	|		ELSE VALUE(Document.PurchaseOrder.EmptyRef)
	|	END
	|
	|ORDER BY
	|	DocumentDate";
		
	Query.SetParameter("Company", 		ParentCompany);
	Query.SetParameter("Counterparty",	Counterparty);
	Query.SetParameter("Period", 		New Boundary(Date, BoundaryType.Excluding));
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
	If OperationKind <> PredefinedValue("Enum.OperationTypesDebitNote.PurchaseReturn")
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

#EndRegion

#EndIf
