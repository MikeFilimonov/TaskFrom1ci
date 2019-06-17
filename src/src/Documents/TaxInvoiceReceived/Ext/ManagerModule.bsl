#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceFunctionsAndProcedures

#Region Posting

Procedure InitializeDocumentData(DocumentRef, AdditionalProperties, Registers = Undefined) Export
	
	FillInitializationParameters(DocumentRef, AdditionalProperties);
	
EndProcedure

Procedure FillInitializationParameters(DocumentRef, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.SetParameter("Ref", DocumentRef);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("PresentationCurrency", Constants.PresentationCurrency.Get());
	Query.SetParameter("CashCurrency", DocumentRef.Currency);
	
	Query.Text =
	"SELECT
	|	TaxInvoiceReceivedHeader.Ref AS Ref,
	|	CASE
	|		WHEN TaxInvoiceReceivedHeader.DateOfSupply = DATETIME(1, 1, 1)
	|			THEN TaxInvoiceReceivedHeader.Date
	|		ELSE TaxInvoiceReceivedHeader.DateOfSupply
	|	END AS Period,
	|	TaxInvoiceReceivedHeader.Date AS Recieved,
	|	TaxInvoiceReceivedHeader.Company AS Company,
	|	TaxInvoiceReceivedHeader.Counterparty AS Counterparty,
	|	TaxInvoiceReceivedHeader.Number AS Number,
	|	TaxInvoiceReceivedHeader.Currency AS Currency,
	|	TaxInvoiceReceivedHeader.Department AS Department,
	|	TaxInvoiceReceivedHeader.Responsible AS Responsible,
	|	TaxInvoiceReceivedHeader.OperationKind AS OperationKind
	|INTO TaxInvoiceReceivedHeader
	|FROM
	|	Document.TaxInvoiceReceived AS TaxInvoiceReceivedHeader
	|WHERE
	|	TaxInvoiceReceivedHeader.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	BasisDocuments.BasisDocument AS BasisDocument,
	|	Header.OperationKind AS OperationKind
	|INTO BasisDocuments
	|FROM
	|	TaxInvoiceReceivedHeader AS Header
	|		INNER JOIN Document.TaxInvoiceReceived.BasisDocuments AS BasisDocuments
	|		ON Header.Ref = BasisDocuments.Ref
	|
	|INDEX BY
	|	BasisDocument
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ExchangeRates.Currency AS Currency,
	|	ExchangeRates.ExchangeRate AS ExchangeRate,
	|	ExchangeRates.Multiplicity AS Multiplicity
	|INTO TemporaryTableExchangeRatesSliceLatest
	|FROM
	|	InformationRegister.ExchangeRates.SliceLast(&PointInTime, Currency IN (&PresentationCurrency, &CashCurrency)) AS ExchangeRates
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	BasisDocuments.BasisDocument AS BasisDocument,
	|	BasisDocuments.OperationKind AS OperationKind,
	|	DebitNoteHeader.IncludeVATInPrice AS IncludeVATInPrice,
	|	DebitNoteHeader.BasisDocument AS SourceDocument,
	|	DebitNoteHeader.VATRate AS VATRate,
	|	DebitNoteHeader.DocumentCurrency AS DocumentCurrency,
	|	DebitNoteHeader.Date AS Date,
	|	DebitNoteHeader.VATAmount AS VATAmount,
	|	DebitNoteHeader.DocumentAmount AS DocumentAmount,
	|	DebitNoteHeader.Multiplicity AS Multiplicity,
	|	DebitNoteHeader.ExchangeRate AS ExchangeRate
	|INTO BasisDocumentsDebitNotes
	|FROM
	|	BasisDocuments AS BasisDocuments
	|		INNER JOIN Document.DebitNote AS DebitNoteHeader
	|		ON BasisDocuments.BasisDocument = DebitNoteHeader.Ref
	|WHERE
	|	DebitNoteHeader.VATTaxation = VALUE(Enum.VATTaxationTypes.SubjectToVAT)
	|
	|INDEX BY
	|	BasisDocument
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	BasisDocuments.BasisDocument AS BasisDocument,
	|	FALSE AS IncludeVATInPrice,
	|	Payments.VATRate AS VATRate,
	|	CashVoucherHeader.CashCurrency AS CashCurrency,
	|	CashVoucherHeader.Date AS Date,
	|	CashVoucherHeader.Company AS Company,
	|	CashVoucherHeader.Counterparty AS Counterparty,
	|	Payments.VATAmount * ExchangeRatesOfPettyCashe.ExchangeRate / AccountingExchangeRates.Multiplicity AS VATAmount,
	|	(Payments.PaymentAmount - Payments.VATAmount) * ExchangeRatesOfPettyCashe.ExchangeRate / AccountingExchangeRates.Multiplicity AS PaymentAmount,
	|	BasisDocuments.OperationKind AS OperationKind
	|INTO BasisDocumentsCashVoucher
	|FROM
	|	BasisDocuments AS BasisDocuments
	|		INNER JOIN Document.CashVoucher.PaymentDetails AS Payments
	|		ON BasisDocuments.BasisDocument = Payments.Ref
	|		INNER JOIN Document.CashVoucher AS CashVoucherHeader
	|		ON BasisDocuments.BasisDocument = CashVoucherHeader.Ref
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS AccountingExchangeRates
	|		ON (AccountingExchangeRates.Currency = &PresentationCurrency)
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS ExchangeRatesOfPettyCashe
	|		ON (ExchangeRatesOfPettyCashe.Currency = &CashCurrency)
	|WHERE
	|	BasisDocuments.OperationKind = VALUE(Enum.OperationTypesTaxInvoiceReceived.AdvancePayment)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	BasisDocuments.BasisDocument AS BasisDocument,
	|	FALSE AS IncludeVATInPrice,
	|	Payments.VATRate AS VATRate,
	|	PaymentExpenseHeader.CashCurrency AS CashCurrency,
	|	PaymentExpenseHeader.Date AS Date,
	|	PaymentExpenseHeader.Company AS Company,
	|	PaymentExpenseHeader.Counterparty AS Counterparty,
	|	Payments.VATAmount * ExchangeRatesOfPettyCashe.ExchangeRate / AccountingExchangeRates.Multiplicity AS VATAmount,
	|	(Payments.PaymentAmount - Payments.VATAmount) * ExchangeRatesOfPettyCashe.ExchangeRate / AccountingExchangeRates.Multiplicity AS PaymentAmount,
	|	BasisDocuments.OperationKind AS OperationKind
	|INTO BasisDocumentsPaymentExpense
	|FROM
	|	BasisDocuments AS BasisDocuments
	|		INNER JOIN Document.PaymentExpense.PaymentDetails AS Payments
	|		ON BasisDocuments.BasisDocument = Payments.Ref
	|		INNER JOIN Document.PaymentExpense AS PaymentExpenseHeader
	|		ON BasisDocuments.BasisDocument = PaymentExpenseHeader.Ref
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS AccountingExchangeRates
	|		ON (AccountingExchangeRates.Currency = &PresentationCurrency)
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS ExchangeRatesOfPettyCashe
	|		ON (ExchangeRatesOfPettyCashe.Currency = &CashCurrency)
	|WHERE
	|	BasisDocuments.OperationKind = VALUE(Enum.OperationTypesTaxInvoiceReceived.AdvancePayment)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	BasisDocuments.BasisDocument AS BasisDocument,
	|	BasisDocuments.OperationKind AS OperationKind,
	|	SupplierInvoiceHeader.IncludeVATInPrice AS IncludeVATInPrice,
	|	SupplierInvoiceHeader.DocumentCurrency AS DocumentCurrency,
	|	SupplierInvoiceHeader.Date AS Date,
	|	SupplierInvoiceHeader.Company AS Company,
	|	SupplierInvoiceHeader.Counterparty AS Counterparty,
	|	SupplierInvoiceHeader.Multiplicity AS Multiplicity,
	|	SupplierInvoiceHeader.ExchangeRate AS ExchangeRate
	|INTO BasisDocumentsSupplierInvoices
	|FROM
	|	BasisDocuments AS BasisDocuments
	|		INNER JOIN Document.SupplierInvoice AS SupplierInvoiceHeader
	|		ON BasisDocuments.BasisDocument = SupplierInvoiceHeader.Ref
	|WHERE
	|	BasisDocuments.OperationKind = VALUE(Enum.OperationTypesTaxInvoiceReceived.Purchase)
	|		AND SupplierInvoiceHeader.VATTaxation = VALUE(Enum.VATTaxationTypes.SubjectToVAT)
	|
	|INDEX BY
	|	BasisDocument,
	|	OperationKind
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Prepayment.Ref AS Ref,
	|	Prepayment.Document AS ShipmentDocument,
	|	Prepayment.VATRate AS VATRate,
	|	SupplierInvoices.DocumentCurrency AS DocumentCurrency,
	|	SupplierInvoices.Date AS Date,
	|	SupplierInvoices.Company AS Company,
	|	SupplierInvoices.Counterparty AS Counterparty,
	|	SupplierInvoices.OperationKind AS OperationKind,
	|	SUM(Prepayment.VATAmount) AS VATAmount,
	|	SUM(Prepayment.AmountExcludesVAT) AS AmountExcludesVAT,
	|	1 AS Multiplicity,
	|	1 AS ExchangeRate
	|INTO SupplierInvoicesPrepaymentVAT
	|FROM
	|	BasisDocumentsSupplierInvoices AS SupplierInvoices
	|		INNER JOIN Document.SupplierInvoice.PrepaymentVAT AS Prepayment
	|		ON SupplierInvoices.BasisDocument = Prepayment.Ref
	|WHERE
	|	SupplierInvoices.OperationKind = VALUE(Enum.OperationTypesTaxInvoiceReceived.Purchase)
	|
	|GROUP BY
	|	Prepayment.Ref,
	|	Prepayment.Document,
	|	Prepayment.VATRate,
	|	SupplierInvoices.DocumentCurrency,
	|	SupplierInvoices.Date,
	|	SupplierInvoices.Company,
	|	SupplierInvoices.Counterparty,
	|	SupplierInvoices.OperationKind
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Inventory.Ref AS SourceRef,
	|	Inventory.Ref AS BasisRef,
	|	Inventory.VATRate AS VATRate,
	|	SupplierInvoices.DocumentCurrency AS DocumentCurrency,
	|	SupplierInvoices.Date AS Date,
	|	CAST(Inventory.VATAmount * SupplierInvoices.ExchangeRate / SupplierInvoices.Multiplicity AS NUMBER(15, 2)) AS VATAmount,
	|	CAST(CASE
	|			WHEN SupplierInvoices.IncludeVATInPrice
	|				THEN Inventory.Total
	|			ELSE Inventory.Total - Inventory.VATAmount
	|		END * SupplierInvoices.ExchangeRate / SupplierInvoices.Multiplicity AS NUMBER(15, 2)) AS AmountExcludesVAT,
	|	TaxInvoiceReceivedHeader.Company AS Company,
	|	TaxInvoiceReceivedHeader.Counterparty AS Customer,
	|	VALUE(Enum.VATOperationTypes.Purchases) AS OperationType,
	|	CatalogProducts.ProductsType AS ProductType,
	|	TaxInvoiceReceivedHeader.Period AS Period
	|INTO BasisDocumentsData
	|FROM
	|	BasisDocumentsSupplierInvoices AS SupplierInvoices
	|		INNER JOIN Document.SupplierInvoice.Inventory AS Inventory
	|		ON SupplierInvoices.BasisDocument = Inventory.Ref
	|		LEFT JOIN Catalog.Products AS CatalogProducts
	|		ON (Inventory.Products = CatalogProducts.Ref)
	|		INNER JOIN TaxInvoiceReceivedHeader AS TaxInvoiceReceivedHeader
	|		ON (TRUE)
	|
	|UNION ALL
	|
	|SELECT
	|	Expenses.Ref,
	|	Expenses.Ref,
	|	Expenses.VATRate,
	|	SupplierInvoices.DocumentCurrency,
	|	SupplierInvoices.Date,
	|	CAST(Expenses.VATAmount * SupplierInvoices.ExchangeRate / SupplierInvoices.Multiplicity AS NUMBER(15, 2)),
	|	CAST(CASE
	|			WHEN SupplierInvoices.IncludeVATInPrice
	|				THEN Expenses.Total
	|			ELSE Expenses.Total - Expenses.VATAmount
	|		END * SupplierInvoices.ExchangeRate / SupplierInvoices.Multiplicity AS NUMBER(15, 2)),
	|	TaxInvoiceReceivedHeader.Company,
	|	TaxInvoiceReceivedHeader.Counterparty,
	|	VALUE(Enum.VATOperationTypes.Purchases),
	|	CatalogProducts.ProductsType,
	|	TaxInvoiceReceivedHeader.Period
	|FROM
	|	BasisDocumentsSupplierInvoices AS SupplierInvoices
	|		INNER JOIN Document.SupplierInvoice.Expenses AS Expenses
	|		ON SupplierInvoices.BasisDocument = Expenses.Ref
	|		LEFT JOIN Catalog.Products AS CatalogProducts
	|		ON (Expenses.Products = CatalogProducts.Ref)
	|		INNER JOIN TaxInvoiceReceivedHeader AS TaxInvoiceReceivedHeader
	|		ON (TRUE)
	|
	|UNION ALL
	|
	|SELECT
	|	CASE
	|		WHEN VALUETYPE(DebitNote.SourceDocument) = TYPE(Document.GoodsReturn)
	|			THEN CAST(DebitNote.SourceDocument AS Document.GoodsReturn).SupplierInvoice
	|		ELSE DebitNote.SourceDocument
	|	END,
	|	DebitNote.BasisDocument,
	|	DebitNoteInventory.VATRate,
	|	DebitNote.DocumentCurrency,
	|	DebitNote.Date,
	|	-(CAST(DebitNoteInventory.VATAmount * DebitNote.ExchangeRate / DebitNote.Multiplicity AS NUMBER(15, 2))),
	|	-(CAST((DebitNoteInventory.Total - DebitNoteInventory.VATAmount) * DebitNote.ExchangeRate / DebitNote.Multiplicity AS NUMBER(15, 2))),
	|	TaxInvoiceReceivedHeader.Company,
	|	TaxInvoiceReceivedHeader.Counterparty,
	|	VALUE(Enum.VATOperationTypes.PurchasesReturn),
	|	CatalogProducts.ProductsType,
	|	TaxInvoiceReceivedHeader.Period
	|FROM
	|	BasisDocumentsDebitNotes AS DebitNote
	|		INNER JOIN Document.DebitNote.Inventory AS DebitNoteInventory
	|		ON DebitNote.BasisDocument = DebitNoteInventory.Ref
	|		LEFT JOIN Catalog.Products AS CatalogProducts
	|		ON (DebitNoteInventory.Products = CatalogProducts.Ref)
	|		INNER JOIN TaxInvoiceReceivedHeader AS TaxInvoiceReceivedHeader
	|		ON (TRUE)
	|WHERE
	|	DebitNote.OperationKind = VALUE(Enum.OperationTypesTaxInvoiceReceived.PurchaseReturn)
	|	AND (DebitNoteInventory.VATAmount <> 0
	|			OR DebitNoteInventory.Amount <> 0)
	|
	|UNION ALL
	|
	|SELECT
	|	DebitNote.BasisDocument,
	|	DebitNote.BasisDocument,
	|	DebitNote.VATRate,
	|	DebitNote.DocumentCurrency,
	|	DebitNote.Date,
	|	-(CAST(DebitNote.VATAmount * DebitNote.ExchangeRate / DebitNote.Multiplicity AS NUMBER(15, 2))),
	|	-(CAST((DebitNote.DocumentAmount - DebitNote.VATAmount) * DebitNote.ExchangeRate / DebitNote.Multiplicity AS NUMBER(15, 2))),
	|	TaxInvoiceReceivedHeader.Company,
	|	TaxInvoiceReceivedHeader.Counterparty,
	|	VALUE(Enum.VATOperationTypes.OtherAdjustments),
	|	VALUE(Enum.ProductsTypes.EmptyRef),
	|	TaxInvoiceReceivedHeader.Period
	|FROM
	|	BasisDocumentsDebitNotes AS DebitNote
	|		INNER JOIN TaxInvoiceReceivedHeader AS TaxInvoiceReceivedHeader
	|		ON (TRUE)
	|WHERE
	|	DebitNote.OperationKind = VALUE(Enum.OperationTypesTaxInvoiceReceived.Adjustments)
	|
	|UNION ALL
	|
	|SELECT
	|	DebitNote.BasisDocument,
	|	DebitNote.BasisDocument,
	|	DebitNote.VATRate,
	|	DebitNote.DocumentCurrency,
	|	DebitNote.Date,
	|	-(CAST(DebitNote.VATAmount * DebitNote.ExchangeRate / DebitNote.Multiplicity AS NUMBER(15, 2))),
	|	-(CAST((DebitNote.DocumentAmount - DebitNote.VATAmount) * DebitNote.ExchangeRate / DebitNote.Multiplicity AS NUMBER(15, 2))),
	|	TaxInvoiceReceivedHeader.Company,
	|	TaxInvoiceReceivedHeader.Counterparty,
	|	VALUE(Enum.VATOperationTypes.DiscountReceived),
	|	VALUE(Enum.ProductsTypes.EmptyRef),
	|	TaxInvoiceReceivedHeader.Period
	|FROM
	|	BasisDocumentsDebitNotes AS DebitNote
	|		INNER JOIN TaxInvoiceReceivedHeader AS TaxInvoiceReceivedHeader
	|		ON (TRUE)
	|WHERE
	|	DebitNote.OperationKind = VALUE(Enum.OperationTypesTaxInvoiceReceived.DiscountReceived)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	PrepaymentVAT.ShipmentDocument AS ShipmentDocument
	|INTO PrepaymentWithoutInvoice
	|FROM
	|	SupplierInvoicesPrepaymentVAT AS PrepaymentVAT
	|		LEFT JOIN Document.TaxInvoiceReceived.BasisDocuments AS PrepaymentDocuments
	|		ON PrepaymentVAT.ShipmentDocument = PrepaymentDocuments.BasisDocument
	|WHERE
	|	PrepaymentDocuments.BasisDocument IS NULL";
	
	Query.ExecuteBatch();
	
	GenerateTableVATInput(DocumentRef, StructureAdditionalProperties);
	GenerateTableVATIncurred(DocumentRef, StructureAdditionalProperties);
	GenerateTableAccountingJournalEntries(DocumentRef, StructureAdditionalProperties);
	
EndProcedure

Procedure GenerateTableVATInput(DocumentRefTaxInvoiceReceived, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.Text = 
	"SELECT
	|	BasisDocuments.SourceRef AS ShipmentDocument,
	|	BasisDocuments.VATRate AS VATRate,
	|	SUM(BasisDocuments.VATAmount) AS VATAmount,
	|	SUM(BasisDocuments.AmountExcludesVAT) AS AmountExcludesVAT,
	|	BasisDocuments.Company AS Company,
	|	BasisDocuments.Customer AS Supplier,
	|	BasisDocuments.OperationType AS OperationType,
	|	BasisDocuments.ProductType AS ProductType,
	|	BasisDocuments.Period AS Period
	|FROM
	|	BasisDocumentsData AS BasisDocuments
	|
	|GROUP BY
	|	BasisDocuments.SourceRef,
	|	BasisDocuments.VATRate,
	|	BasisDocuments.OperationType,
	|	BasisDocuments.ProductType,
	|	BasisDocuments.Company,
	|	BasisDocuments.Customer,
	|	BasisDocuments.Period
	|
	|UNION ALL
	|
	|SELECT
	|	CashVoucherPayments.BasisDocument,
	|	CashVoucherPayments.VATRate,
	|	CashVoucherPayments.VATAmount,
	|	CashVoucherPayments.PaymentAmount,
	|	CashVoucherPayments.Company,
	|	CashVoucherPayments.Counterparty,
	|	VALUE(Enum.VATOperationTypes.AdvancePayment),
	|	VALUE(Enum.ProductsTypes.EmptyRef),
	|	CashVoucherPayments.Date
	|FROM
	|	BasisDocumentsCashVoucher AS CashVoucherPayments
	|
	|UNION ALL
	|
	|SELECT
	|	PaymentExpensePayments.BasisDocument,
	|	PaymentExpensePayments.VATRate,
	|	PaymentExpensePayments.VATAmount,
	|	PaymentExpensePayments.PaymentAmount,
	|	PaymentExpensePayments.Company,
	|	PaymentExpensePayments.Counterparty,
	|	VALUE(Enum.VATOperationTypes.AdvancePayment),
	|	VALUE(Enum.ProductsTypes.EmptyRef),
	|	PaymentExpensePayments.Date
	|FROM
	|	BasisDocumentsPaymentExpense AS PaymentExpensePayments
	|
	|UNION ALL
	|
	|SELECT
	|	PrepaymentVAT.ShipmentDocument,
	|	PrepaymentVAT.VATRate,
	|	-PrepaymentVAT.VATAmount,
	|	-PrepaymentVAT.AmountExcludesVAT,
	|	PrepaymentVAT.Company,
	|	PrepaymentVAT.Counterparty,
	|	VALUE(Enum.VATOperationTypes.AdvanceCleared),
	|	VALUE(Enum.ProductsTypes.EmptyRef),
	|	PrepaymentVAT.Date
	|FROM
	|	SupplierInvoicesPrepaymentVAT AS PrepaymentVAT
	|		LEFT JOIN PrepaymentWithoutInvoice AS PrepaymentWithoutInvoice
	|		ON PrepaymentVAT.ShipmentDocument = PrepaymentWithoutInvoice.ShipmentDocument
	|WHERE
	|	PrepaymentWithoutInvoice.ShipmentDocument IS NULL";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableVATInput", QueryResult.Unload());
	
EndProcedure

Procedure GenerateTableVATIncurred(DocumentRefTaxInvoiceReceived, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.Text = 
	"SELECT
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	BasisDocuments.BasisRef AS ShipmentDocument,
	|	BasisDocuments.VATRate AS VATRate,
	|	SUM(BasisDocuments.VATAmount) AS VATAmount,
	|	SUM(BasisDocuments.AmountExcludesVAT) AS AmountExcludesVAT,
	|	BasisDocuments.Company AS Company,
	|	BasisDocuments.Customer AS Supplier,
	|	BasisDocuments.Period AS Period
	|FROM
	|	BasisDocumentsData AS BasisDocuments
	|
	|GROUP BY
	|	BasisDocuments.BasisRef,
	|	BasisDocuments.VATRate,
	|	BasisDocuments.Company,
	|	BasisDocuments.Customer,
	|	BasisDocuments.Period
	|
	|UNION ALL
	|
	|SELECT
	|	VALUE(AccumulationRecordType.Expense),
	|	CashVoucherPayments.BasisDocument,
	|	CashVoucherPayments.VATRate,
	|	CashVoucherPayments.VATAmount,
	|	CashVoucherPayments.PaymentAmount,
	|	CashVoucherPayments.Company,
	|	CashVoucherPayments.Counterparty,
	|	CashVoucherPayments.Date
	|FROM
	|	BasisDocumentsCashVoucher AS CashVoucherPayments
	|
	|UNION ALL
	|
	|SELECT
	|	VALUE(AccumulationRecordType.Expense),
	|	PaymentExpensePayments.BasisDocument,
	|	PaymentExpensePayments.VATRate,
	|	PaymentExpensePayments.VATAmount,
	|	PaymentExpensePayments.PaymentAmount,
	|	PaymentExpensePayments.Company,
	|	PaymentExpensePayments.Counterparty,
	|	PaymentExpensePayments.Date
	|FROM
	|	BasisDocumentsPaymentExpense AS PaymentExpensePayments
	|";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableVATIncurred", QueryResult.Unload());
	
EndProcedure

Procedure GenerateTableAccountingJournalEntries(DocumentRefTaxInvoiceReceived, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();
	
	Query.SetParameter("Company",					StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("Date",						StructureAdditionalProperties.ForPosting.Date);
	Query.SetParameter("ContentVATOnAdvance",		NStr("en = 'VAT on advance'", MainLanguageCode));
	Query.SetParameter("ContentVATRevenue",			NStr("en = 'Advance recognized as payment'", MainLanguageCode));
	Query.SetParameter("VATAdvancesToSuppliers",	Catalogs.DefaultGLAccounts.GetDefaultGLAccount("VATAdvancesToSuppliers"));
	Query.SetParameter("VATInput",					Catalogs.DefaultGLAccounts.GetDefaultGLAccount("VATInput"));
	
	Query.SetParameter("PostAdvancePaymentsBySourceDocuments", StructureAdditionalProperties.AccountingPolicy.PostAdvancePaymentsBySourceDocuments);
	Query.SetParameter("PostVATEntriesBySourceDocuments", StructureAdditionalProperties.AccountingPolicy.PostVATEntriesBySourceDocuments);
	
	Query.Text =
	"SELECT
	|	DocumentTable.Date AS Period,
	|	DocumentTable.Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	&VATInput AS AccountDr,
	|	&VATAdvancesToSuppliers AS AccountCr,
	|	UNDEFINED AS CurrencyDr,
	|	UNDEFINED AS CurrencyCr,
	|	0 AS AmountCurDr,
	|	0 AS AmountCurCr,
	|	SUM(DocumentTable.VATAmount) AS Amount,
	|	&ContentVATOnAdvance AS Content,
	|	FALSE AS OfflineRecord
	|FROM
	|	BasisDocumentsCashVoucher AS DocumentTable
	|WHERE
	|	DocumentTable.OperationKind = VALUE(Enum.OperationTypesTaxInvoiceReceived.AdvancePayment)
	|	AND NOT &PostAdvancePaymentsBySourceDocuments
	|
	|GROUP BY
	|	DocumentTable.Date,
	|	DocumentTable.Company
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	&VATInput,
	|	&VATAdvancesToSuppliers,
	|	UNDEFINED,
	|	UNDEFINED,
	|	0,
	|	0,
	|	SUM(DocumentTable.VATAmount),
	|	&ContentVATOnAdvance,
	|	FALSE
	|FROM
	|	BasisDocumentsPaymentExpense AS DocumentTable
	|WHERE
	|	DocumentTable.OperationKind = VALUE(Enum.OperationTypesTaxInvoiceReceived.AdvancePayment)
	|	AND NOT &PostAdvancePaymentsBySourceDocuments
	|
	|GROUP BY
	|	DocumentTable.Date,
	|	DocumentTable.Company
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	&VATAdvancesToSuppliers,
	|	&VATInput,
	|	UNDEFINED,
	|	UNDEFINED,
	|	0,
	|	0,
	|	SUM(DocumentTable.VATAmount),
	|	&ContentVATRevenue,
	|	FALSE
	|FROM
	|	SupplierInvoicesPrepaymentVAT AS DocumentTable
	|		LEFT JOIN PrepaymentWithoutInvoice AS PrepaymentWithoutInvoice
	|		ON DocumentTable.ShipmentDocument = PrepaymentWithoutInvoice.ShipmentDocument
	|WHERE
	|	DocumentTable.OperationKind = VALUE(Enum.OperationTypesTaxInvoiceReceived.Purchase)
	|	AND NOT &PostVATEntriesBySourceDocuments
	|	AND PrepaymentWithoutInvoice.ShipmentDocument IS NULL
	|
	|GROUP BY
	|	DocumentTable.Date,
	|	DocumentTable.Company";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountingJournalEntries", QueryResult.Unload());
	
EndProcedure

// Controls the occurrence of negative balances.
//
Procedure RunControl(DocumentRefTaxInvoiceReceived, AdditionalProperties, Cancel, PostingDelete = False) Export
	
	If Not DriveServer.RunBalanceControl() Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	If StructureTemporaryTables.RegisterRecordsVATIncurredChange Then
		
		Query = New Query;
		
		Query.Text = AccumulationRegisters.VATIncurred.BalancesControlQueryText();
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.SetParameter("ControlTime", AdditionalProperties.ForPosting.ControlTime);
		
		Result = Query.Execute();
		
		If Not Result.IsEmpty() Then
			DocumentObjectTaxInvoiceReceived = DocumentRefTaxInvoiceReceived.GetObject();
			QueryResultSelection = Result.Select();
			DriveServer.ShowMessageAboutPostingToVATIncurredRegisterErrors(DocumentObjectTaxInvoiceReceived, QueryResultSelection, Cancel);
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region Print

// Fills printing commands list
// 
// Parameters:
//   PrintCommands - ValueTable - see fields' content in the PrintManagement.CreatePrintCommandsCollection function.
//
Procedure AddPrintCommands(PrintCommands) Export
	
EndProcedure

// Generate printed forms of objects
//
// Incoming:
//   TemplateNames    - String    - Names of layouts separated
//   by commas ObjectsArray  - Array    - Array of refs to objects that
//   need to be printed PrintParameters - Structure - Structure of additional printing parameters
//
// Outgoing:
//   PrintFormsCollection - Values table - Generated
//   table documents OutputParameters       - Structure        - Parameters of generated table documents
//
Procedure Print(ObjectsArray, PrintParameters, PrintFormsCollection, PrintObjects, OutputParameters) Export
		
EndProcedure

#EndRegion

#Region Presentation

Procedure PresentationGetProcessing(Data, Presentation, StandardProcessing, OperationKind = Undefined) Export
	
	DataStructure = CommonUse.ObjectAttributesValues(Data.Ref, "Number, Posted, DeletionMark, OperationKind");
	
	If Data.Number = Null
		OR Not ValueIsFilled(DataStructure.Number)
		OR Not ValueIsFilled(Data.Ref) Then
		
		If ValueIsFilled(DataStructure.OperationKind) Then
			Presentation = GetTitle(DataStructure.OperationKind);
		EndIf;
		
		Return;
	EndIf;
	
	StandardProcessing = False;
	
	If DataStructure.Posted Then
		State = "";
	ElsIf DataStructure.DeletionMark Then
		State = NStr("en = '(deleted)'");
	EndIf;
	
	If ValueIsFilled(OperationKind) Then
		TitlePresentation = GetTitle(OperationKind);
	Else
		TitlePresentation = GetTitle(DataStructure.OperationKind);
	EndIf;
	
	Presentation = StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en = '%1 %2 dated %3 %4'"),
		TitlePresentation,
		?(Data.Property("Number"), ObjectPrefixationClientServer.GetNumberForPrinting(Data.Number, True, True), ""),
		Format(Data.Date, "DLF=D"),
		State);
	
EndProcedure

// Function returns the Title for invoice.
//
// Parameters:
//	OperationKind - Enum.OperationTypesTaxInvoiceReceived - Operation in invoice.
//	ThisIsNewInvoice - Boolean - Shows what this is a new invoice.
//
// ReturnedValue:
//	String - Title for Tax invoice.
//
Function GetTitle(OperationKind, ThisIsNewInvoice = False) Export
	
	If OperationKind = Enums.OperationTypesTaxInvoiceReceived.AdvancePayment Then
		TitlePresentation = NStr("en = 'Advance payment invoice'");
	Else
		TitlePresentation = NStr("en = 'Tax invoice received'");
	EndIf;
	
	If ThisIsNewInvoice Then
		TitlePresentation = TitlePresentation + " " + NStr("en = '(create)'");
	EndIf;
	
	Return TitlePresentation;
EndFunction

#EndRegion

#EndRegion

#Region InfobaseUpdate

Procedure ProcessDataToUpgradeToNewVersion() Export
	
	Query = New Query;
	Query.Text =
	"SELECT DISTINCT
	|	TaxInvoiceReceivedBasisDocuments.Ref AS Ref
	|FROM
	|	Document.TaxInvoiceReceived.BasisDocuments AS TaxInvoiceReceivedBasisDocuments
	|		INNER JOIN Document.DebitNote AS DebitNote
	|		ON TaxInvoiceReceivedBasisDocuments.BasisDocument = DebitNote.Ref
	|			AND (DebitNote.OperationKind = VALUE(Enum.OperationTypesDebitNote.DiscountReceived))
	|		INNER JOIN Document.TaxInvoiceReceived AS TaxInvoiceReceived
	|		ON TaxInvoiceReceivedBasisDocuments.Ref = TaxInvoiceReceived.Ref
	|			AND (NOT TaxInvoiceReceived.OperationKind = VALUE(Enum.OperationTypesTaxInvoiceReceived.DiscountReceived))";
	
	Sel = Query.Execute().Select();
	
	While Sel.Next() Do
		
		DocObj = Sel.Ref.GetObject();
		DocObj.OperationKind = Enums.OperationTypesTaxInvoiceReceived.DiscountReceived;
		DocObj.DataExchange.Load = True;
		DocObj.Write(DocumentWriteMode.Write);
		
	EndDo;
	
EndProcedure

#EndRegion

#EndIf
