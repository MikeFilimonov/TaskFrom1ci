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
	|	TaxInvoiceIssuedHeader.Ref AS Ref,
	|	TaxInvoiceIssuedHeader.Date AS Date,
	|	TaxInvoiceIssuedHeader.Number AS Number,
	|	TaxInvoiceIssuedHeader.Company AS Company,
	|	TaxInvoiceIssuedHeader.Counterparty AS Counterparty,
	|	TaxInvoiceIssuedHeader.Currency AS Currency,
	|	CASE
	|		WHEN TaxInvoiceIssuedHeader.DateOfSupply = DATETIME(1, 1, 1)
	|			THEN TaxInvoiceIssuedHeader.Date
	|		ELSE TaxInvoiceIssuedHeader.DateOfSupply
	|	END AS Period,
	|	TaxInvoiceIssuedHeader.Department AS Department,
	|	TaxInvoiceIssuedHeader.Responsible AS Responsible,
	|	TaxInvoiceIssuedHeader.OperationKind AS OperationKind
	|INTO TaxInvoiceIssuedHeader
	|FROM
	|	Document.TaxInvoiceIssued AS TaxInvoiceIssuedHeader
	|WHERE
	|	TaxInvoiceIssuedHeader.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	BasisDocuments.BasisDocument AS BasisDocument,
	|	Header.OperationKind AS OperationKind
	|INTO BasisDocuments
	|FROM
	|	TaxInvoiceIssuedHeader AS Header
	|		INNER JOIN Document.TaxInvoiceIssued.BasisDocuments AS BasisDocuments
	|		ON Header.Ref = BasisDocuments.Ref
	|
	|INDEX BY
	|	BasisDocument
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	BasisDocuments.BasisDocument AS BasisDocument,
	|	BasisDocuments.OperationKind AS OperationKind,
	|	CreditNoteHeader.IncludeVATInPrice AS IncludeVATInPrice,
	|	CreditNoteHeader.BasisDocument AS SourceDocument,
	|	CreditNoteHeader.VATRate AS VATRate,
	|	CreditNoteHeader.DocumentCurrency AS DocumentCurrency,
	|	CreditNoteHeader.VATTaxation AS VATTaxation,
	|	CreditNoteHeader.Date AS Date,
	|	CreditNoteHeader.VATAmount AS VATAmount,
	|	CreditNoteHeader.DocumentAmount AS DocumentAmount,
	|	CreditNoteHeader.Multiplicity AS Multiplicity,
	|	CreditNoteHeader.ExchangeRate AS ExchangeRate
	|INTO BasisDocumentsCreditNotes
	|FROM
	|	BasisDocuments AS BasisDocuments
	|		INNER JOIN Document.CreditNote AS CreditNoteHeader
	|		ON BasisDocuments.BasisDocument = CreditNoteHeader.Ref
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
	|	FALSE AS IncludeVATInPrice,
	|	Payments.VATRate AS VATRate,
	|	CashReceiptHeader.CashCurrency AS CashCurrency,
	|	CashReceiptHeader.Date AS Date,
	|	CashReceiptHeader.Company AS Company,
	|	CashReceiptHeader.Counterparty AS Counterparty,
	|	Payments.VATAmount * ExchangeRatesOfPettyCashe.ExchangeRate / AccountingExchangeRates.Multiplicity AS VATAmount,
	|	(Payments.PaymentAmount - Payments.VATAmount) * ExchangeRatesOfPettyCashe.ExchangeRate / AccountingExchangeRates.Multiplicity AS PaymentAmount,
	|	BasisDocuments.OperationKind AS OperationKind
	|INTO BasisDocumentsCashReceipt
	|FROM
	|	BasisDocuments AS BasisDocuments
	|		INNER JOIN Document.CashReceipt.PaymentDetails AS Payments
	|		ON BasisDocuments.BasisDocument = Payments.Ref
	|		INNER JOIN Document.CashReceipt AS CashReceiptHeader
	|		ON BasisDocuments.BasisDocument = CashReceiptHeader.Ref
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS AccountingExchangeRates
	|		ON (AccountingExchangeRates.Currency = &PresentationCurrency)
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS ExchangeRatesOfPettyCashe
	|		ON (ExchangeRatesOfPettyCashe.Currency = &CashCurrency)
	|WHERE
	|	BasisDocuments.OperationKind = VALUE(Enum.OperationTypesTaxInvoiceIssued.AdvancePayment)
	|	AND Payments.AdvanceFlag
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	BasisDocuments.BasisDocument AS BasisDocument,
	|	FALSE AS IncludeVATInPrice,
	|	Payments.VATRate AS VATRate,
	|	PaymentReceiptHeader.CashCurrency AS CashCurrency,
	|	PaymentReceiptHeader.Date AS Date,
	|	PaymentReceiptHeader.Company AS Company,
	|	PaymentReceiptHeader.Counterparty AS Counterparty,
	|	Payments.VATAmount * ExchangeRatesOfPettyCashe.ExchangeRate / AccountingExchangeRates.Multiplicity AS VATAmount,
	|	(Payments.PaymentAmount - Payments.VATAmount) * ExchangeRatesOfPettyCashe.ExchangeRate / AccountingExchangeRates.Multiplicity AS PaymentAmount,
	|	BasisDocuments.OperationKind AS OperationKind
	|INTO BasisDocumentsPaymentReceipt
	|FROM
	|	BasisDocuments AS BasisDocuments
	|		INNER JOIN Document.PaymentReceipt.PaymentDetails AS Payments
	|		ON BasisDocuments.BasisDocument = Payments.Ref
	|		INNER JOIN Document.PaymentReceipt AS PaymentReceiptHeader
	|		ON BasisDocuments.BasisDocument = PaymentReceiptHeader.Ref
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS AccountingExchangeRates
	|		ON (AccountingExchangeRates.Currency = &PresentationCurrency)
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS ExchangeRatesOfPettyCashe
	|		ON (ExchangeRatesOfPettyCashe.Currency = &CashCurrency)
	|WHERE
	|	BasisDocuments.OperationKind = VALUE(Enum.OperationTypesTaxInvoiceIssued.AdvancePayment)
	|	AND Payments.AdvanceFlag
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	BasisDocuments.BasisDocument AS BasisDocument,
	|	BasisDocuments.OperationKind AS OperationKind,
	|	SalesInvoiceHeader.IncludeVATInPrice AS IncludeVATInPrice,
	|	SalesInvoiceHeader.DocumentCurrency AS DocumentCurrency,
	|	SalesInvoiceHeader.VATTaxation AS VATTaxation,
	|	SalesInvoiceHeader.Date AS Date,
	|	SalesInvoiceHeader.Company AS Company,
	|	SalesInvoiceHeader.Counterparty AS Counterparty,
	|	SalesInvoiceHeader.Multiplicity AS Multiplicity,
	|	SalesInvoiceHeader.ExchangeRate AS ExchangeRate
	|INTO BasisDocumentsSalesInvoices
	|FROM
	|	BasisDocuments AS BasisDocuments
	|		INNER JOIN Document.SalesInvoice AS SalesInvoiceHeader
	|		ON BasisDocuments.BasisDocument = SalesInvoiceHeader.Ref
	|WHERE
	|	BasisDocuments.OperationKind = VALUE(Enum.OperationTypesTaxInvoiceIssued.Sale)
	|
	|INDEX BY
	|	BasisDocument
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Prepayment.Ref AS Ref,
	|	Prepayment.Document AS ShipmentDocument,
	|	Prepayment.VATRate AS VATRate,
	|	SalesInvoices.DocumentCurrency AS DocumentCurrency,
	|	SalesInvoices.Date AS Date,
	|	SalesInvoices.Company AS Company,
	|	SalesInvoices.Counterparty AS Counterparty,
	|	SalesInvoices.OperationKind AS OperationKind,
	|	SUM(Prepayment.VATAmount) AS VATAmount,
	|	SUM(Prepayment.AmountExcludesVAT) AS AmountExcludesVAT,
	|	1 AS Multiplicity,
	|	1 AS ExchangeRate
	|INTO SalesInvoicesPrepaymentVAT
	|FROM
	|	BasisDocumentsSalesInvoices AS SalesInvoices
	|		INNER JOIN Document.SalesInvoice.PrepaymentVAT AS Prepayment
	|		ON SalesInvoices.BasisDocument = Prepayment.Ref
	|WHERE
	|	SalesInvoices.OperationKind = VALUE(Enum.OperationTypesTaxInvoiceIssued.Sale)
	|
	|GROUP BY
	|	Prepayment.Ref,
	|	Prepayment.Document,
	|	Prepayment.VATRate,
	|	SalesInvoices.DocumentCurrency,
	|	SalesInvoices.Date,
	|	SalesInvoices.Company,
	|	SalesInvoices.Counterparty,
	|	SalesInvoices.OperationKind
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Inventory.Ref AS BasisRef,
	|	Inventory.VATRate AS VATRate,
	|	SalesInvoices.DocumentCurrency AS DocumentCurrency,
	|	SalesInvoices.Date AS Date,
	|	CAST(Inventory.VATAmount * SalesInvoices.ExchangeRate / SalesInvoices.Multiplicity AS NUMBER(15, 2)) AS VATAmount,
	|	CAST(CASE
	|			WHEN SalesInvoices.IncludeVATInPrice
	|				THEN Inventory.Total
	|			ELSE Inventory.Total - Inventory.VATAmount
	|		END * SalesInvoices.ExchangeRate / SalesInvoices.Multiplicity AS NUMBER(15, 2)) AS AmountExcludesVAT,
	|	TaxInvoiceIssuedHeader.Company AS Company,
	|	TaxInvoiceIssuedHeader.Counterparty AS Customer,
	|	CASE
	|		WHEN SalesInvoices.VATTaxation = VALUE(Enum.VATTaxationTypes.ForExport)
	|				OR SalesInvoices.VATTaxation = VALUE(Enum.VATTaxationTypes.ReverseChargeVAT)
	|			THEN VALUE(Enum.VATOperationTypes.Export)
	|		ELSE VALUE(Enum.VATOperationTypes.Sales)
	|	END AS OperationType,
	|	CatalogProducts.ProductsType AS ProductType,
	|	TaxInvoiceIssuedHeader.Period AS Period
	|INTO BasisDocumentsData
	|FROM
	|	BasisDocumentsSalesInvoices AS SalesInvoices
	|		INNER JOIN Document.SalesInvoice.Inventory AS Inventory
	|		ON SalesInvoices.BasisDocument = Inventory.Ref
	|		LEFT JOIN Catalog.Products AS CatalogProducts
	|		ON (Inventory.Products = CatalogProducts.Ref)
	|		INNER JOIN TaxInvoiceIssuedHeader AS TaxInvoiceIssuedHeader
	|		ON (TRUE)
	|
	|UNION ALL
	|
	|SELECT
	|	CASE
	|		WHEN VALUETYPE(CreditNoteHeader.SourceDocument) = TYPE(Document.GoodsReturn)
	|			THEN CAST(CreditNoteHeader.SourceDocument AS Document.GoodsReturn).SalesDocument
	|		ELSE CreditNoteHeader.SourceDocument
	|	END,
	|	CreditNoteInventory.VATRate,
	|	CreditNoteHeader.DocumentCurrency,
	|	CreditNoteHeader.Date,
	|	-(CAST(CreditNoteInventory.VATAmount * CreditNoteHeader.ExchangeRate / CreditNoteHeader.Multiplicity AS NUMBER(15, 2))),
	|	-(CAST((CreditNoteInventory.Total - CreditNoteInventory.VATAmount) * CreditNoteHeader.ExchangeRate / CreditNoteHeader.Multiplicity AS NUMBER(15, 2))),
	|	TaxInvoiceIssuedHeader.Company,
	|	TaxInvoiceIssuedHeader.Counterparty,
	|	CASE
	|		WHEN CreditNoteHeader.VATTaxation = VALUE(Enum.VATTaxationTypes.ForExport)
	|				OR CreditNoteHeader.VATTaxation = VALUE(Enum.VATTaxationTypes.ReverseChargeVAT)
	|			THEN VALUE(Enum.VATOperationTypes.Export)
	|		ELSE VALUE(Enum.VATOperationTypes.SalesReturn)
	|	END,
	|	CatalogProducts.ProductsType,
	|	TaxInvoiceIssuedHeader.Period
	|FROM
	|	BasisDocumentsCreditNotes AS CreditNoteHeader
	|		INNER JOIN Document.CreditNote.Inventory AS CreditNoteInventory
	|		ON CreditNoteHeader.BasisDocument = CreditNoteInventory.Ref
	|		LEFT JOIN Catalog.Products AS CatalogProducts
	|		ON (CreditNoteInventory.Products = CatalogProducts.Ref)
	|		INNER JOIN TaxInvoiceIssuedHeader AS TaxInvoiceIssuedHeader
	|		ON (TRUE)
	|WHERE
	|	CreditNoteHeader.OperationKind = VALUE(Enum.OperationTypesTaxInvoiceIssued.SalesReturn)
	|	AND (CreditNoteInventory.VATAmount <> 0
	|			OR CreditNoteInventory.Amount <> 0)
	|
	|UNION ALL
	|
	|SELECT
	|	CreditNote.BasisDocument,
	|	CreditNote.VATRate,
	|	CreditNote.DocumentCurrency,
	|	CreditNote.Date,
	|	-(CAST(CreditNote.VATAmount * CreditNote.ExchangeRate / CreditNote.Multiplicity AS NUMBER(15, 2))),
	|	-(CAST((CreditNote.DocumentAmount - CreditNote.VATAmount) * CreditNote.ExchangeRate / CreditNote.Multiplicity AS NUMBER(15, 2))),
	|	TaxInvoiceIssuedHeader.Company,
	|	TaxInvoiceIssuedHeader.Counterparty,
	|	CASE
	|		WHEN CreditNote.VATTaxation = VALUE(Enum.VATTaxationTypes.ForExport)
	|				OR CreditNote.VATTaxation = VALUE(Enum.VATTaxationTypes.ReverseChargeVAT)
	|			THEN VALUE(Enum.VATOperationTypes.Export)
	|		ELSE VALUE(Enum.VATOperationTypes.OtherAdjustments)
	|	END,
	|	VALUE(Enum.ProductsTypes.EmptyRef),
	|	TaxInvoiceIssuedHeader.Period
	|FROM
	|	BasisDocumentsCreditNotes AS CreditNote
	|		INNER JOIN TaxInvoiceIssuedHeader AS TaxInvoiceIssuedHeader
	|		ON (TRUE)
	|WHERE
	|	CreditNote.OperationKind = VALUE(Enum.OperationTypesTaxInvoiceIssued.Adjustments)
	|
	|UNION ALL
	|
	|SELECT
	|	CreditNote.BasisDocument,
	|	CreditNote.VATRate,
	|	CreditNote.DocumentCurrency,
	|	CreditNote.Date,
	|	-(CAST(CreditNote.VATAmount * CreditNote.ExchangeRate / CreditNote.Multiplicity AS NUMBER(15, 2))),
	|	-(CAST((CreditNote.DocumentAmount - CreditNote.VATAmount) * CreditNote.ExchangeRate / CreditNote.Multiplicity AS NUMBER(15, 2))),
	|	TaxInvoiceIssuedHeader.Company,
	|	TaxInvoiceIssuedHeader.Counterparty,
	|	CASE
	|		WHEN CreditNote.VATTaxation = VALUE(Enum.VATTaxationTypes.ForExport)
	|				OR CreditNote.VATTaxation = VALUE(Enum.VATTaxationTypes.ReverseChargeVAT)
	|			THEN VALUE(Enum.VATOperationTypes.Export)
	|		ELSE VALUE(Enum.VATOperationTypes.DiscountAllowed)
	|	END,
	|	VALUE(Enum.ProductsTypes.EmptyRef),
	|	TaxInvoiceIssuedHeader.Period
	|FROM
	|	BasisDocumentsCreditNotes AS CreditNote
	|		INNER JOIN TaxInvoiceIssuedHeader AS TaxInvoiceIssuedHeader
	|		ON (TRUE)
	|WHERE
	|	CreditNote.OperationKind = VALUE(Enum.OperationTypesTaxInvoiceIssued.DiscountAllowed)";
	
	Query.ExecuteBatch();
	
	GenerateTableVATOutput(DocumentRef, StructureAdditionalProperties);
	GenerateTableAccountingJournalEntries(DocumentRef, StructureAdditionalProperties);
	
EndProcedure

Procedure GenerateTableVATOutput(DocumentRefTaxInvoiceIssued, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.Text = 
	"SELECT
	|	DocumentsData.BasisRef AS ShipmentDocument,
	|	DocumentsData.VATRate AS VATRate,
	|	SUM(DocumentsData.VATAmount) AS VATAmount,
	|	SUM(DocumentsData.AmountExcludesVAT) AS AmountExcludesVAT,
	|	DocumentsData.Company AS Company,
	|	DocumentsData.Customer AS Customer,
	|	DocumentsData.OperationType AS OperationType,
	|	DocumentsData.ProductType AS ProductType,
	|	DocumentsData.Period AS Period
	|FROM
	|	BasisDocumentsData AS DocumentsData
	|
	|GROUP BY
	|	DocumentsData.Customer,
	|	DocumentsData.OperationType,
	|	DocumentsData.ProductType,
	|	DocumentsData.VATRate,
	|	DocumentsData.Period,
	|	DocumentsData.Company,
	|	DocumentsData.BasisRef
	|
	|UNION ALL
	|
	|SELECT
	|	CashReceiptPayments.BasisDocument,
	|	CashReceiptPayments.VATRate,
	|	CashReceiptPayments.VATAmount,
	|	CashReceiptPayments.PaymentAmount,
	|	CashReceiptPayments.Company,
	|	CashReceiptPayments.Counterparty,
	|	VALUE(Enum.VATOperationTypes.AdvancePayment),
	|	VALUE(Enum.ProductsTypes.EmptyRef),
	|	CashReceiptPayments.Date
	|FROM
	|	BasisDocumentsCashReceipt AS CashReceiptPayments
	|
	|UNION ALL
	|
	|SELECT
	|	PaymentReceiptPayments.BasisDocument,
	|	PaymentReceiptPayments.VATRate,
	|	PaymentReceiptPayments.VATAmount,
	|	PaymentReceiptPayments.PaymentAmount,
	|	PaymentReceiptPayments.Company,
	|	PaymentReceiptPayments.Counterparty,
	|	VALUE(Enum.VATOperationTypes.AdvancePayment),
	|	VALUE(Enum.ProductsTypes.EmptyRef),
	|	PaymentReceiptPayments.Date
	|FROM
	|	BasisDocumentsPaymentReceipt AS PaymentReceiptPayments
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
	|	SalesInvoicesPrepaymentVAT AS PrepaymentVAT";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableVATOutput", QueryResult.Unload());
	
EndProcedure

Procedure GenerateTableAccountingJournalEntries(DocumentRefTaxInvoiceIssued, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();
	
	Query.SetParameter("Company",					StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("Date",						StructureAdditionalProperties.ForPosting.Date);
	Query.SetParameter("ContentVATOnAdvance",		NStr("en = 'VAT on advance'", MainLanguageCode));
	Query.SetParameter("ContentVATRevenue",			NStr("en = 'Deduction of VAT on advance payment'", MainLanguageCode));
	Query.SetParameter("VATAdvancesFromCustomers",	Catalogs.DefaultGLAccounts.GetDefaultGLAccount("VATAdvancesFromCustomers"));
	Query.SetParameter("VATOutput",					Catalogs.DefaultGLAccounts.GetDefaultGLAccount("VATOutput"));
	
	Query.SetParameter("PostAdvancePaymentsBySourceDocuments", StructureAdditionalProperties.AccountingPolicy.PostAdvancePaymentsBySourceDocuments);
	Query.SetParameter("PostVATEntriesBySourceDocuments", StructureAdditionalProperties.AccountingPolicy.PostVATEntriesBySourceDocuments);
	
	Query.Text =
	"SELECT
	|	DocumentTable.Date AS Period,
	|	DocumentTable.Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	&VATAdvancesFromCustomers AS AccountDr,
	|	&VATOutput AS AccountCr,
	|	UNDEFINED AS CurrencyDr,
	|	UNDEFINED AS CurrencyCr,
	|	0 AS AmountCurDr,
	|	0 AS AmountCurCr,
	|	SUM(DocumentTable.VATAmount) AS Amount,
	|	&ContentVATOnAdvance AS Content,
	|	FALSE AS OfflineRecord
	|FROM
	|	BasisDocumentsCashReceipt AS DocumentTable
	|WHERE
	|	DocumentTable.OperationKind = VALUE(Enum.OperationTypesTaxInvoiceIssued.AdvancePayment)
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
	|	&VATAdvancesFromCustomers,
	|	&VATOutput,
	|	UNDEFINED,
	|	UNDEFINED,
	|	0,
	|	0,
	|	SUM(DocumentTable.VATAmount),
	|	&ContentVATOnAdvance,
	|	FALSE
	|FROM
	|	BasisDocumentsPaymentReceipt AS DocumentTable
	|WHERE
	|	DocumentTable.OperationKind = VALUE(Enum.OperationTypesTaxInvoiceIssued.AdvancePayment)
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
	|	&VATOutput,
	|	&VATAdvancesFromCustomers,
	|	UNDEFINED,
	|	UNDEFINED,
	|	0,
	|	0,
	|	SUM(DocumentTable.VATAmount),
	|	&ContentVATRevenue,
	|	FALSE
	|FROM
	|	SalesInvoicesPrepaymentVAT AS DocumentTable
	|WHERE
	|	DocumentTable.OperationKind = VALUE(Enum.OperationTypesTaxInvoiceIssued.Sale)
	|	AND NOT &PostVATEntriesBySourceDocuments
	|
	|GROUP BY
	|	DocumentTable.Date,
	|	DocumentTable.Company";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountingJournalEntries", QueryResult.Unload());
	
EndProcedure

#EndRegion

#Region Print

// Fills printing commands list
// 
// Parameters:
//   PrintCommands - ValueTable - see fields' content in the PrintManagement.CreatePrintCommandsCollection function.
//
Procedure AddPrintCommands(PrintCommands) Export
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID = "TaxInvoice";
	PrintCommand.Presentation = NStr("en = 'Tax invoice'");
	PrintCommand.FormsList = "DocumentForm,ListForm";
	PrintCommand.CheckPostingBeforePrint = True;
	PrintCommand.Order = 1;
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID							= "AdvancePaymentInvoice";
	PrintCommand.Presentation				= NStr("en = 'Advance payment invoice'");
	PrintCommand.CheckPostingBeforePrint	= False;
	PrintCommand.Order						= 2;
	
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
		
	If PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "TaxInvoice") Then
		
		SpreadsheetDocument = DataProcessors.PrintTaxInvoice.PrintForm(ObjectsArray, PrintObjects, "TaxInvoice");
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(
			PrintFormsCollection,
			"TaxInvoice",
			NStr("en = 'Tax invoice'"),
			SpreadsheetDocument);
			
	ElsIf PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "AdvancePaymentInvoice") Then
			
		SpreadsheetDocument = DataProcessors.PrintAdvancePaymentInvoice.PrintForm(
			ObjectsArray,
			PrintObjects,
			"AdvancePaymentInvoice");
			
		PrintManagement.OutputSpreadsheetDocumentToCollection(
			PrintFormsCollection,
			"AdvancePaymentInvoice",
			NStr("en = 'Advance payment invoice'"),
			SpreadsheetDocument);
			
	EndIf;
		
	// parameters of sending printing forms by email
	DriveServer.FillSendingParameters(OutputParameters.SendingParameters, ObjectsArray, PrintFormsCollection);
	
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
	
	If OperationKind = Enums.OperationTypesTaxInvoiceIssued.AdvancePayment Then
		TitlePresentation = NStr("en = 'Advance payment invoice'");
	Else
		TitlePresentation = NStr("en = 'Tax invoice issued'");
	EndIf;
	
	If ThisIsNewInvoice Then
		TitlePresentation = TitlePresentation + " " + NStr("en = '(create)'");
	EndIf;
	
	Return TitlePresentation;
	
EndFunction

#EndRegion

// Gets Tax invoice for basis document
//
// Parameters:
//	BasisDocument - DocumentRef - basis document of tax invoice.
//
// Returns:
//	DocumentRef.TaxInvoiceIssue - an empty reference if there is no Tax Invoice.
//
Function GetTaxInvoiceIssued(BasisDocument) Export
	
	TaxInvoice = Documents.TaxInvoiceIssued.EmptyRef();
	
	Query = New Query;
	Query.Text = 
	"SELECT DISTINCT
	|	TaxInvoiceIssuedBasisDocuments.Ref AS Ref
	|INTO TaxInvoiceTempTable
	|FROM
	|	Document.TaxInvoiceIssued.BasisDocuments AS TaxInvoiceIssuedBasisDocuments
	|WHERE
	|	TaxInvoiceIssuedBasisDocuments.BasisDocument = &BasisDocument
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TaxInvoiceIssued.Ref AS Ref
	|FROM
	|	Document.TaxInvoiceIssued AS TaxInvoiceIssued
	|		INNER JOIN TaxInvoiceTempTable AS TaxInvoiceTempTable
	|		ON TaxInvoiceIssued.Ref = TaxInvoiceTempTable.Ref
	|WHERE
	|	NOT TaxInvoiceIssued.DeletionMark";
	
	Query.SetParameter("BasisDocument", BasisDocument);
	
	QueryResult = Query.Execute();
	If NOT QueryResult.IsEmpty() Then
		SelectionResult = QueryResult.Select();
		If SelectionResult.Next() Then
			TaxInvoice = SelectionResult.Ref;
		EndIf;
	EndIf;
	
	Return TaxInvoice;
	
EndFunction

#EndRegion

#Region InfobaseUpdate

Procedure ProcessDataToUpgradeToNewVersion() Export
	
	Query = New Query;
	Query.Text =
	"SELECT DISTINCT
	|	TaxInvoiceIssuedBasisDocuments.Ref AS Ref
	|FROM
	|	Document.TaxInvoiceIssued.BasisDocuments AS TaxInvoiceIssuedBasisDocuments
	|		INNER JOIN Document.CreditNote AS CreditNote
	|		ON TaxInvoiceIssuedBasisDocuments.BasisDocument = CreditNote.Ref
	|			AND (CreditNote.OperationKind = VALUE(Enum.OperationTypesCreditNote.DiscountAllowed))
	|		INNER JOIN Document.TaxInvoiceIssued AS TaxInvoiceIssued
	|		ON TaxInvoiceIssuedBasisDocuments.Ref = TaxInvoiceIssued.Ref
	|			AND (NOT TaxInvoiceIssued.OperationKind = VALUE(Enum.OperationTypesTaxInvoiceIssued.DiscountAllowed))";
	
	Sel = Query.Execute().Select();
	
	While Sel.Next() Do
		
		DocObj = Sel.Ref.GetObject();
		DocObj.OperationKind = Enums.OperationTypesTaxInvoiceIssued.DiscountAllowed;
		DocObj.DataExchange.Load = True;
		DocObj.Write(DocumentWriteMode.Write);
		
	EndDo;
	
EndProcedure

#EndRegion

#EndIf
