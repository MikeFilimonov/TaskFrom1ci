#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Print

Function GetQueryText()
	
	QueryText = 
	"SELECT
	|	TaxInvoiceIssued.Ref AS Ref
	|INTO TaxInvoices
	|FROM
	|	Document.TaxInvoiceIssued AS TaxInvoiceIssued
	|WHERE
	|	TaxInvoiceIssued.Ref IN(&ObjectsArray)
	|
	|UNION ALL
	|
	|SELECT
	|	TaxInvoiceIssuedBasisDocuments.Ref
	|FROM
	|	Document.TaxInvoiceIssued.BasisDocuments AS TaxInvoiceIssuedBasisDocuments
	|WHERE
	|	TaxInvoiceIssuedBasisDocuments.BasisDocument IN(&ObjectsArray)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TaxInvoiceIssuedBasisDocuments.BasisDocument AS BasisDocument,
	|	TaxInvoiceIssued.Number AS Number,
	|	TaxInvoiceIssued.Date AS Date,
	|	TaxInvoices.Ref AS Ref
	|INTO BasisDocumentsWithTaxInvoice
	|FROM
	|	TaxInvoices AS TaxInvoices
	|		INNER JOIN Document.TaxInvoiceIssued.BasisDocuments AS TaxInvoiceIssuedBasisDocuments
	|		ON TaxInvoices.Ref = TaxInvoiceIssuedBasisDocuments.Ref
	|		INNER JOIN Document.TaxInvoiceIssued AS TaxInvoiceIssued
	|		ON TaxInvoices.Ref = TaxInvoiceIssued.Ref
	|			AND (TaxInvoiceIssued.Posted)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SalesInvoice.Ref AS Ref,
	|	SalesInvoice.Number AS Number,
	|	SalesInvoice.Date AS Date,
	|	SalesInvoice.Company AS Company,
	|	SalesInvoice.Counterparty AS Counterparty,
	|	SalesInvoice.Contract AS Contract,
	|	SalesInvoice.AmountIncludesVAT AS AmountIncludesVAT,
	|	SalesInvoice.DocumentCurrency AS DocumentCurrency,
	|	CAST(SalesInvoice.Comment AS STRING(1024)) AS Comment,
	|	SalesInvoice.VATTaxation = VALUE(Enum.VATTaxationTypes.ReverseChargeVAT) AS ReverseCharge,
	|	SalesInvoice.StructuralUnit AS StructuralUnit,
	|	SalesInvoice.Ref AS BasisDocument,
	|	TRUE AS RegisterVATEntriesBySourceDocuments,
	|	SalesInvoice.Number AS ReferenceNumber,
	|	SalesInvoice.Date AS ReferenceDate,
	|	SalesInvoice.DocumentCurrency AS ReferenceCurrency,
	|	SalesInvoice.ExchangeRate AS ReferenceRate
	|INTO Documents
	|FROM
	|	Document.SalesInvoice AS SalesInvoice
	|WHERE
	|	SalesInvoice.Ref IN(&ObjectsArray)
	|
	|UNION ALL
	|
	|SELECT
	|	CreditNote.Ref,
	|	CreditNote.Number,
	|	CreditNote.Date,
	|	CreditNote.Company,
	|	CreditNote.Counterparty,
	|	CreditNote.Contract,
	|	CreditNote.AmountIncludesVAT,
	|	CreditNote.DocumentCurrency,
	|	CAST(CreditNote.Comment AS STRING(1024)),
	|	CreditNote.VATTaxation = VALUE(Enum.VATTaxationTypes.ReverseChargeVAT),
	|	CreditNote.StructuralUnit,
	|	CreditNote.Ref,
	|	TRUE,
	|	CreditNote.Number,
	|	CreditNote.Date,
	|	CreditNote.DocumentCurrency,
	|	CreditNote.ExchangeRate
	|FROM
	|	Document.CreditNote AS CreditNote
	|WHERE
	|	CreditNote.Ref IN(&ObjectsArray)
	|
	|UNION ALL
	|
	|SELECT
	|	BasisDocumentsWithTaxInvoice.Ref,
	|	BasisDocumentsWithTaxInvoice.Number,
	|	BasisDocumentsWithTaxInvoice.Date,
	|	SalesInvoice.Company,
	|	SalesInvoice.Counterparty,
	|	SalesInvoice.Contract,
	|	SalesInvoice.AmountIncludesVAT,
	|	SalesInvoice.DocumentCurrency,
	|	CAST(SalesInvoice.Comment AS STRING(1024)),
	|	SalesInvoice.VATTaxation = VALUE(Enum.VATTaxationTypes.ReverseChargeVAT),
	|	SalesInvoice.StructuralUnit,
	|	SalesInvoice.Ref,
	|	FALSE,
	|	SalesInvoice.Number,
	|	SalesInvoice.Date,
	|	SalesInvoice.DocumentCurrency,
	|	SalesInvoice.ExchangeRate
	|FROM
	|	BasisDocumentsWithTaxInvoice AS BasisDocumentsWithTaxInvoice
	|		INNER JOIN Document.SalesInvoice AS SalesInvoice
	|		ON BasisDocumentsWithTaxInvoice.BasisDocument = SalesInvoice.Ref
	|
	|UNION ALL
	|
	|SELECT
	|	BasisDocumentsWithTaxInvoice.Ref,
	|	BasisDocumentsWithTaxInvoice.Number,
	|	BasisDocumentsWithTaxInvoice.Date,
	|	CreditNote.Company,
	|	CreditNote.Counterparty,
	|	CreditNote.Contract,
	|	CreditNote.AmountIncludesVAT,
	|	CreditNote.DocumentCurrency,
	|	CAST(CreditNote.Comment AS STRING(1024)),
	|	CreditNote.VATTaxation = VALUE(Enum.VATTaxationTypes.ReverseChargeVAT),
	|	CreditNote.StructuralUnit,
	|	CreditNote.Ref,
	|	FALSE,
	|	CreditNote.Number,
	|	CreditNote.Date,
	|	CreditNote.DocumentCurrency,
	|	CreditNote.ExchangeRate
	|FROM
	|	BasisDocumentsWithTaxInvoice AS BasisDocumentsWithTaxInvoice
	|		INNER JOIN Document.CreditNote AS CreditNote
	|		ON BasisDocumentsWithTaxInvoice.BasisDocument = CreditNote.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Documents.Ref AS Ref,
	|	Documents.Number AS Number,
	|	Documents.Date AS Date,
	|	Documents.Company AS Company,
	|	Documents.Counterparty AS Counterparty,
	|	Documents.Contract AS Contract,
	|	Documents.AmountIncludesVAT AS AmountIncludesVAT,
	|	Documents.DocumentCurrency AS DocumentCurrency,
	|	Documents.Comment AS Comment,
	|	Documents.ReverseCharge AS ReverseCharge,
	|	Documents.StructuralUnit AS StructuralUnit,
	|	Documents.BasisDocument AS BasisDocument,
	|	Documents.RegisterVATEntriesBySourceDocuments AS RegisterVATEntriesBySourceDocuments,
	|	MAX(AccountingPolicy.Period) AS Period,
	|	Documents.ReferenceDate AS ReferenceDate,
	|	Documents.ReferenceNumber AS ReferenceNumber,
	|	Documents.ReferenceCurrency AS ReferenceCurrency,
	|	Documents.ReferenceRate AS ReferenceRate,
	|	MAX(ExchangeRates.Period) AS PeriodExchangeRate
	|INTO DocumentsMaxAccountingPolicy
	|FROM
	|	Documents AS Documents
	|		LEFT JOIN InformationRegister.AccountingPolicy AS AccountingPolicy
	|		ON Documents.Company = AccountingPolicy.Company
	|			AND Documents.Date >= AccountingPolicy.Period
	|		LEFT JOIN InformationRegister.ExchangeRates AS ExchangeRates
	|		ON Documents.DocumentCurrency = ExchangeRates.Currency
	|			AND Documents.Date >= ExchangeRates.Period
	|
	|GROUP BY
	|	Documents.Counterparty,
	|	Documents.DocumentCurrency,
	|	Documents.RegisterVATEntriesBySourceDocuments,
	|	Documents.ReverseCharge,
	|	Documents.Comment,
	|	Documents.AmountIncludesVAT,
	|	Documents.StructuralUnit,
	|	Documents.Contract,
	|	Documents.BasisDocument,
	|	Documents.Ref,
	|	Documents.Number,
	|	Documents.Company,
	|	Documents.Date,
	|	Documents.ReferenceDate,
	|	Documents.ReferenceNumber,
	|	Documents.ReferenceCurrency,
	|	Documents.ReferenceRate
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DocumentsMaxAccountingPolicy.Ref AS Ref,
	|	DocumentsMaxAccountingPolicy.Number AS Number,
	|	DocumentsMaxAccountingPolicy.Date AS Date,
	|	DocumentsMaxAccountingPolicy.Company AS Company,
	|	DocumentsMaxAccountingPolicy.Counterparty AS Counterparty,
	|	DocumentsMaxAccountingPolicy.Contract AS Contract,
	|	DocumentsMaxAccountingPolicy.AmountIncludesVAT AS AmountIncludesVAT,
	|	DocumentsMaxAccountingPolicy.DocumentCurrency AS DocumentCurrency,
	|	DocumentsMaxAccountingPolicy.Comment AS Comment,
	|	DocumentsMaxAccountingPolicy.ReverseCharge AS ReverseCharge,
	|	DocumentsMaxAccountingPolicy.StructuralUnit AS StructuralUnit,
	|	DocumentsMaxAccountingPolicy.BasisDocument AS BasisDocument,
	|	DocumentsMaxAccountingPolicy.RegisterVATEntriesBySourceDocuments AS RegisterVATEntriesBySourceDocuments,
	|	DocumentsMaxAccountingPolicy.ReferenceNumber AS ReferenceNumber,
	|	DocumentsMaxAccountingPolicy.ReferenceDate AS ReferenceDate,
	|	DocumentsMaxAccountingPolicy.ReferenceCurrency AS ReferenceCurrency,
	|	DocumentsMaxAccountingPolicy.ReferenceRate AS ReferenceRate,
	|	ExchangeRates.ExchangeRate AS ExchangeRate,
	|	ExchangeRates.Multiplicity AS Multiplicity
	|INTO FilteredDocuments
	|FROM
	|	DocumentsMaxAccountingPolicy AS DocumentsMaxAccountingPolicy
	|		INNER JOIN InformationRegister.AccountingPolicy AS AccountingPolicy
	|		ON DocumentsMaxAccountingPolicy.Company = AccountingPolicy.Company
	|			AND DocumentsMaxAccountingPolicy.Period = AccountingPolicy.Period
	|			AND (DocumentsMaxAccountingPolicy.RegisterVATEntriesBySourceDocuments = AccountingPolicy.PostVATEntriesBySourceDocuments)
	|		INNER JOIN InformationRegister.ExchangeRates AS ExchangeRates
	|		ON DocumentsMaxAccountingPolicy.DocumentCurrency = ExchangeRates.Currency
	|			AND DocumentsMaxAccountingPolicy.PeriodExchangeRate = ExchangeRates.Period
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	FilteredDocuments.Ref AS Ref,
	|	FilteredDocuments.Number AS DocumentNumber,
	|	FilteredDocuments.Date AS DocumentDate,
	|	FilteredDocuments.Company AS Company,
	|	Companies.LogoFile AS CompanyLogoFile,
	|	FilteredDocuments.Counterparty AS Counterparty,
	|	FilteredDocuments.Contract AS Contract,
	|	FilteredDocuments.AmountIncludesVAT AS AmountIncludesVAT,
	|	FilteredDocuments.DocumentCurrency AS DocumentCurrency,
	|	FilteredDocuments.Comment AS Comment,
	|	FilteredDocuments.ReverseCharge AS ReverseCharge,
	|	FilteredDocuments.StructuralUnit AS StructuralUnit,
	|	FilteredDocuments.BasisDocument AS BasisDocument,
	|	FilteredDocuments.ReferenceNumber AS ReferenceNumber,
	|	FilteredDocuments.ReferenceDate AS ReferenceDate,
	|	FilteredDocuments.ReferenceCurrency AS ReferenceCurrency,
	|	FilteredDocuments.ReferenceRate AS ReferenceRate,
	|	PresentationCurrency.Value AS PresentationCurrency,
	|	FilteredDocuments.ExchangeRate AS ExchangeRate,
	|	FilteredDocuments.Multiplicity AS Multiplicity
	|INTO Header
	|FROM
	|	FilteredDocuments AS FilteredDocuments
	|		LEFT JOIN Catalog.Companies AS Companies
	|		ON FilteredDocuments.Company = Companies.Ref
	|		LEFT JOIN Catalog.Counterparties AS Counterparties
	|		ON FilteredDocuments.Counterparty = Counterparties.Ref
	|		LEFT JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
	|		ON FilteredDocuments.Contract = CounterpartyContracts.Ref
	|		LEFT JOIN Constant.PresentationCurrency AS PresentationCurrency
	|		ON (TRUE)
	|
	|GROUP BY
	|	FilteredDocuments.Number,
	|	FilteredDocuments.Date,
	|	FilteredDocuments.Counterparty,
	|	FilteredDocuments.Company,
	|	Companies.LogoFile,
	|	FilteredDocuments.Ref,
	|	FilteredDocuments.Comment,
	|	FilteredDocuments.DocumentCurrency,
	|	FilteredDocuments.AmountIncludesVAT,
	|	FilteredDocuments.ReverseCharge,
	|	FilteredDocuments.Contract,
	|	FilteredDocuments.StructuralUnit,
	|	FilteredDocuments.BasisDocument,
	|	FilteredDocuments.ReferenceNumber,
	|	FilteredDocuments.ReferenceDate,
	|	FilteredDocuments.ReferenceCurrency,
	|	PresentationCurrency.Value,
	|	FilteredDocuments.ReferenceRate,
	|	FilteredDocuments.ExchangeRate,
	|	FilteredDocuments.Multiplicity
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	FilteredDocuments.Ref AS Ref,
	|	SalesInvoiceInventory.LineNumber AS LineNumber,
	|	SalesInvoiceInventory.Products AS Products,
	|	SalesInvoiceInventory.Characteristic AS Characteristic,
	|	SalesInvoiceInventory.Batch AS Batch,
	|	SalesInvoiceInventory.Quantity AS Quantity,
	|	SalesInvoiceInventory.Reserve AS Reserve,
	|	SalesInvoiceInventory.MeasurementUnit AS MeasurementUnit,
	|	SalesInvoiceInventory.Price AS Price,
	|	SalesInvoiceInventory.DiscountMarkupPercent AS DiscountMarkupPercent,
	|	SalesInvoiceInventory.Amount AS Amount,
	|	SalesInvoiceInventory.VATRate AS VATRate,
	|	SalesInvoiceInventory.VATAmount AS VATAmount,
	|	SalesInvoiceInventory.Total AS Total,
	|	SalesInvoiceInventory.Order AS Order,
	|	SalesInvoiceInventory.Content AS Content,
	|	SalesInvoiceInventory.AutomaticDiscountsPercent AS AutomaticDiscountsPercent,
	|	SalesInvoiceInventory.AutomaticDiscountAmount AS AutomaticDiscountAmount,
	|	SalesInvoiceInventory.ConnectionKey AS ConnectionKey,
	|	FilteredDocuments.BasisDocument AS BasisDocument,
	|	CAST(SalesInvoiceInventory.Quantity * SalesInvoiceInventory.Price - SalesInvoiceInventory.Amount AS NUMBER(15, 2)) AS DiscountAmount
	|INTO FilteredInventory
	|FROM
	|	Document.SalesInvoice.Inventory AS SalesInvoiceInventory
	|		INNER JOIN FilteredDocuments AS FilteredDocuments
	|		ON SalesInvoiceInventory.Ref = FilteredDocuments.BasisDocument
	|
	|UNION ALL
	|
	|SELECT
	|	FilteredDocuments.Ref,
	|	CreditNoteInventory.LineNumber,
	|	CreditNoteInventory.Products,
	|	CreditNoteInventory.Characteristic,
	|	CreditNoteInventory.Batch,
	|	CreditNoteInventory.Quantity,
	|	0,
	|	CreditNoteInventory.MeasurementUnit,
	|	CASE
	|		WHEN CreditNoteInventory.Quantity = 0
	|			THEN 0
	|		ELSE CreditNoteInventory.Amount / CreditNoteInventory.Quantity
	|	END,
	|	0,
	|	CreditNoteInventory.Amount,
	|	CreditNoteInventory.VATRate,
	|	CreditNoteInventory.VATAmount,
	|	CreditNoteInventory.Total,
	|	CreditNoteInventory.Order,
	|	"""",
	|	0,
	|	0,
	|	CreditNoteInventory.ConnectionKey,
	|	FilteredDocuments.BasisDocument,
	|	0
	|FROM
	|	Document.CreditNote.Inventory AS CreditNoteInventory
	|		INNER JOIN FilteredDocuments AS FilteredDocuments
	|		ON CreditNoteInventory.Ref = FilteredDocuments.BasisDocument
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Header.Ref AS Ref,
	|	Header.DocumentNumber AS DocumentNumber,
	|	Header.DocumentDate AS DocumentDate,
	|	Header.Company AS Company,
	|	Header.CompanyLogoFile AS CompanyLogoFile,
	|	Header.Counterparty AS Counterparty,
	|	Header.Contract AS Contract,
	|	Header.AmountIncludesVAT AS AmountIncludesVAT,
	|	Header.DocumentCurrency AS DocumentCurrency,
	|	Header.Comment AS Comment,
	|	Header.ReverseCharge AS ReverseCharge,
	|	MIN(FilteredInventory.LineNumber) AS LineNumber,
	|	CatalogProducts.SKU AS SKU,
	|	CASE
	|		WHEN (CAST(FilteredInventory.Content AS STRING(1024))) <> """"
	|			THEN CAST(FilteredInventory.Content AS STRING(1024))
	|		WHEN (CAST(CatalogProducts.DescriptionFull AS STRING(1024))) <> """"
	|			THEN CAST(CatalogProducts.DescriptionFull AS STRING(1024))
	|		ELSE CatalogProducts.Description
	|	END AS ProductDescription,
	|	(CAST(FilteredInventory.Content AS STRING(1024))) <> """" AS ContentUsed,
	|	CASE
	|		WHEN CatalogProducts.UseCharacteristics
	|			THEN CatalogCharacteristics.Description
	|		ELSE """"
	|	END AS CharacteristicDescription,
	|	CASE
	|		WHEN CatalogProducts.UseBatches
	|			THEN CatalogBatches.Description
	|		ELSE """"
	|	END AS BatchDescription,
	|	CatalogProducts.UseSerialNumbers AS UseSerialNumbers,
	|	MIN(FilteredInventory.ConnectionKey) AS ConnectionKey,
	|	ISNULL(CatalogUOM.Description, CatalogUOMClassifier.Description) AS UOM,
	|	SUM(FilteredInventory.Quantity) AS Quantity,
	|	CAST(FilteredInventory.Price * Header.ExchangeRate / Header.Multiplicity AS NUMBER(15, 2)) AS Price,
	|	FilteredInventory.DiscountMarkupPercent AS DiscountRate,
	|	SUM(FilteredInventory.AutomaticDiscountAmount) AS AutomaticDiscountAmount,
	|	SUM(CAST(FilteredInventory.Amount * Header.ExchangeRate / Header.Multiplicity AS NUMBER(15, 2))) AS Amount,
	|	FilteredInventory.VATRate AS VATRate,
	|	SUM(CAST(FilteredInventory.VATAmount * Header.ExchangeRate / Header.Multiplicity AS NUMBER(15, 2))) AS VATAmount,
	|	SUM(CAST(FilteredInventory.Total * Header.ExchangeRate / Header.Multiplicity AS NUMBER(15, 2))) AS Total,
	|	SUM(CASE
	|			WHEN Header.AmountIncludesVAT
	|				THEN CAST((FilteredInventory.Amount - FilteredInventory.VATAmount + FilteredInventory.DiscountAmount) * Header.ExchangeRate / Header.Multiplicity AS NUMBER(15, 2))
	|			ELSE CAST(FilteredInventory.Quantity * FilteredInventory.Price * Header.ExchangeRate / Header.Multiplicity AS NUMBER(15, 2))
	|		END) AS Subtotal,
	|	FilteredInventory.Products AS Products,
	|	FilteredInventory.Characteristic AS Characteristic,
	|	FilteredInventory.MeasurementUnit AS MeasurementUnit,
	|	FilteredInventory.Batch AS Batch,
	|	Header.StructuralUnit AS StructuralUnit,
	|	Header.BasisDocument AS BasisDocument,
	|	Header.ReferenceNumber AS ReferenceNumber,
	|	Header.ReferenceDate AS ReferenceDate,
	|	Header.ReferenceCurrency AS ReferenceCurrency,
	|	Header.ReferenceRate AS ReferenceRate,
	|	SUM(CAST(FilteredInventory.DiscountAmount * Header.ExchangeRate / Header.Multiplicity AS NUMBER(15, 2))) AS DiscountAmount,
	|	Header.PresentationCurrency AS PresentationCurrency,
	|	FilteredInventory.Total AS TotalCur
	|INTO Tabular
	|FROM
	|	Header AS Header
	|		INNER JOIN FilteredInventory AS FilteredInventory
	|		ON Header.BasisDocument = FilteredInventory.BasisDocument
	|		LEFT JOIN Catalog.Products AS CatalogProducts
	|		ON (FilteredInventory.Products = CatalogProducts.Ref)
	|		LEFT JOIN Catalog.ProductsCharacteristics AS CatalogCharacteristics
	|		ON (FilteredInventory.Characteristic = CatalogCharacteristics.Ref)
	|		LEFT JOIN Catalog.ProductsBatches AS CatalogBatches
	|		ON (FilteredInventory.Batch = CatalogBatches.Ref)
	|		LEFT JOIN Catalog.UOM AS CatalogUOM
	|		ON (FilteredInventory.MeasurementUnit = CatalogUOM.Ref)
	|		LEFT JOIN Catalog.UOMClassifier AS CatalogUOMClassifier
	|		ON (FilteredInventory.MeasurementUnit = CatalogUOMClassifier.Ref)
	|
	|GROUP BY
	|	Header.DocumentNumber,
	|	Header.DocumentDate,
	|	Header.Company,
	|	Header.Ref,
	|	Header.Counterparty,
	|	Header.CompanyLogoFile,
	|	Header.Contract,
	|	Header.AmountIncludesVAT,
	|	Header.DocumentCurrency,
	|	Header.Comment,
	|	Header.ReverseCharge,
	|	CatalogProducts.SKU,
	|	CASE
	|		WHEN (CAST(FilteredInventory.Content AS STRING(1024))) <> """"
	|			THEN CAST(FilteredInventory.Content AS STRING(1024))
	|		WHEN (CAST(CatalogProducts.DescriptionFull AS STRING(1024))) <> """"
	|			THEN CAST(CatalogProducts.DescriptionFull AS STRING(1024))
	|		ELSE CatalogProducts.Description
	|	END,
	|	CASE
	|		WHEN CatalogProducts.UseCharacteristics
	|			THEN CatalogCharacteristics.Description
	|		ELSE """"
	|	END,
	|	CatalogProducts.UseSerialNumbers,
	|	FilteredInventory.VATRate,
	|	ISNULL(CatalogUOM.Description, CatalogUOMClassifier.Description),
	|	FilteredInventory.Products,
	|	CASE
	|		WHEN CatalogProducts.UseBatches
	|			THEN CatalogBatches.Description
	|		ELSE """"
	|	END,
	|	(CAST(FilteredInventory.Content AS STRING(1024))) <> """",
	|	FilteredInventory.DiscountMarkupPercent,
	|	FilteredInventory.Characteristic,
	|	FilteredInventory.MeasurementUnit,
	|	FilteredInventory.Batch,
	|	Header.StructuralUnit,
	|	Header.BasisDocument,
	|	Header.ReferenceNumber,
	|	Header.ReferenceDate,
	|	Header.ReferenceCurrency,
	|	Header.PresentationCurrency,
	|	Header.ReferenceRate,
	|	CAST(FilteredInventory.Price * Header.ExchangeRate / Header.Multiplicity AS NUMBER(15, 2)),
	|	FilteredInventory.Total
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Tabular.Ref AS Ref,
	|	SUM(Tabular.Total) AS TotalForCount
	|INTO TotalTable
	|FROM
	|	Tabular AS Tabular
	|
	|GROUP BY
	|	Tabular.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Tabular.Ref AS Ref,
	|	Tabular.DocumentNumber AS DocumentNumber,
	|	Tabular.DocumentDate AS DocumentDate,
	|	Tabular.Company AS Company,
	|	Tabular.CompanyLogoFile AS CompanyLogoFile,
	|	Tabular.Counterparty AS Counterparty,
	|	Tabular.Contract AS Contract,
	|	Tabular.AmountIncludesVAT AS AmountIncludesVAT,
	|	Tabular.DocumentCurrency AS DocumentCurrency,
	|	Tabular.Comment AS Comment,
	|	Tabular.LineNumber AS LineNumber,
	|	Tabular.SKU AS SKU,
	|	Tabular.ProductDescription AS ProductDescription,
	|	Tabular.ContentUsed AS ContentUsed,
	|	Tabular.UseSerialNumbers AS UseSerialNumbers,
	|	Tabular.Quantity AS Quantity,
	|	Tabular.Price AS Price,
	|	Tabular.Amount AS TaxableAmount,
	|	Tabular.VATRate AS VATRate,
	|	Tabular.VATAmount AS VATAmount,
	|	Tabular.Total AS Total,
	|	Tabular.Subtotal AS Subtotal,
	|	Tabular.DiscountAmount AS DiscountAmount,
	|	CASE
	|		WHEN Tabular.AutomaticDiscountAmount = 0
	|			THEN Tabular.DiscountRate
	|		WHEN Tabular.Subtotal = 0
	|			THEN 0
	|		ELSE CAST((Tabular.Subtotal - Tabular.Amount) / Tabular.Subtotal * 100 AS NUMBER(15, 2))
	|	END AS DiscountRate,
	|	Tabular.Products AS Products,
	|	Tabular.CharacteristicDescription AS CharacteristicDescription,
	|	Tabular.BatchDescription AS BatchDescription,
	|	Tabular.ConnectionKey AS ConnectionKey,
	|	Tabular.Characteristic AS Characteristic,
	|	Tabular.MeasurementUnit AS MeasurementUnit,
	|	Tabular.Batch AS Batch,
	|	Tabular.UOM AS UOM,
	|	Tabular.StructuralUnit AS StructuralUnit,
	|	Tabular.BasisDocument AS BasisDocument,
	|	Tabular.ReferenceNumber AS ReferenceNumber,
	|	Tabular.ReferenceDate AS ReferenceDate,
	|	Tabular.ReferenceCurrency AS ReferenceCurrency,
	|	Tabular.ReferenceRate AS ReferenceRate,
	|	Tabular.PresentationCurrency AS PresentationCurrency,
	|	Tabular.TotalCur AS TotalCur
	|FROM
	|	Tabular AS Tabular
	|		LEFT JOIN TotalTable AS TotalTable
	|		ON Tabular.Ref = TotalTable.Ref
	|
	|ORDER BY
	|	Tabular.DocumentNumber,
	|	ReferenceNumber,
	|	LineNumber
	|TOTALS
	|	MAX(DocumentNumber),
	|	MAX(DocumentDate),
	|	MAX(Company),
	|	MAX(CompanyLogoFile),
	|	MAX(Counterparty),
	|	MAX(Contract),
	|	MAX(AmountIncludesVAT),
	|	MAX(DocumentCurrency),
	|	MAX(Comment),
	|	COUNT(LineNumber),
	|	SUM(Quantity),
	|	SUM(VATAmount),
	|	SUM(Total),
	|	SUM(Subtotal),
	|	SUM(DiscountAmount),
	|	MAX(StructuralUnit),
	|	MAX(ReferenceNumber),
	|	MAX(ReferenceDate),
	|	MAX(ReferenceCurrency),
	|	MAX(ReferenceRate),
	|	MAX(PresentationCurrency),
	|	SUM(TotalCur)
	|BY
	|	Ref,
	|	BasisDocument
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Tabular.Ref AS Ref,
	|	CASE
	|		WHEN Tabular.ReverseCharge
	|				AND Tabular.VATRate = VALUE(Catalog.VATRates.ZeroRate)
	|			THEN &ReverseChargeAppliesRate
	|		ELSE Tabular.VATRate
	|	END AS VATRate,
	|	SUM(Tabular.Amount) AS TaxableAmount,
	|	SUM(Tabular.VATAmount) AS VATAmount
	|FROM
	|	Tabular AS Tabular
	|
	|GROUP BY
	|	Tabular.Ref,
	|	CASE
	|		WHEN Tabular.ReverseCharge
	|				AND Tabular.VATRate = VALUE(Catalog.VATRates.ZeroRate)
	|			THEN &ReverseChargeAppliesRate
	|		ELSE Tabular.VATRate
	|	END
	|TOTALS BY
	|	Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Tabular.ConnectionKey AS ConnectionKey,
	|	Tabular.Ref AS Ref,
	|	SerialNumbers.Description AS SerialNumber
	|FROM
	|	FilteredInventory AS FilteredInventory
	|		INNER JOIN Tabular AS Tabular
	|		ON FilteredInventory.Products = Tabular.Products
	|			AND FilteredInventory.DiscountMarkupPercent = Tabular.DiscountRate
	|			AND FilteredInventory.Price = Tabular.Price
	|			AND FilteredInventory.VATRate = Tabular.VATRate
	|			AND (NOT Tabular.ContentUsed)
	|			AND FilteredInventory.Ref = Tabular.Ref
	|			AND FilteredInventory.Characteristic = Tabular.Characteristic
	|			AND FilteredInventory.MeasurementUnit = Tabular.MeasurementUnit
	|			AND FilteredInventory.Batch = Tabular.Batch
	|		INNER JOIN Document.SalesInvoice.SerialNumbers AS SalesInvoiceSerialNumbers
	|			LEFT JOIN Catalog.SerialNumbers AS SerialNumbers
	|			ON SalesInvoiceSerialNumbers.SerialNumber = SerialNumbers.Ref
	|		ON (SalesInvoiceSerialNumbers.ConnectionKey = FilteredInventory.ConnectionKey)
	|			AND FilteredInventory.Ref = SalesInvoiceSerialNumbers.Ref";
	
	Return QueryText;
	
EndFunction

// Procedure of generating printed form Tax invoice
//
Function PrintTaxInvoice(ObjectsArray, PrintObjects, TemplateName)
	
	SpreadsheetDocument = New SpreadsheetDocument;
	SpreadsheetDocument.PrintParametersKey = "PrintParameters_TaxInvoice";
	
	Query = New Query(GetQueryText());
	Query.SetParameter("ObjectsArray", ObjectsArray);
	Query.SetParameter("ReverseChargeAppliesRate", NStr("en = 'Reverse charge applies'"));
	
	ResultArray = Query.ExecuteBatch();
	
	FirstDocument = True;
	PrintableDocuments = New Array;
	
	Header				= ResultArray[9].Select(QueryResultIteration.ByGroups);
	TaxesHeaderSel		= ResultArray[10].Select(QueryResultIteration.ByGroups);
	SerialNumbersSel	= ResultArray[11].Select();
	
	While Header.Next() Do
		
		If Not FirstDocument Then
			SpreadsheetDocument.PutHorizontalPageBreak();
		EndIf;
		FirstDocument = False;
		
		FirstLineNumber = SpreadsheetDocument.TableHeight + 1;
		
		SpreadsheetDocument.PrintParametersName = "PRINT_PARAMETERS_TaxInvoice";
		
		Template = PrintManagement.PrintedFormsTemplate("DataProcessor.PrintTaxInvoice.PF_MXL_TaxInvoice");
		
		#Region PrintTaxInvoiceTitleArea
		
		TitleArea = Template.GetArea("Title");
		TitleArea.Parameters.Fill(Header);
		
		If ValueIsFilled(Header.CompanyLogoFile) Then
			
			PictureData = AttachedFiles.GetFileBinaryData(Header.CompanyLogoFile);
			If ValueIsFilled(PictureData) Then
				
				TitleArea.Drawings.Logo.Picture = New Picture(PictureData);
				
			EndIf;
			
		Else
			
			TitleArea.Drawings.Delete(TitleArea.Drawings.Logo);
			
		EndIf;
		
		SpreadsheetDocument.Put(TitleArea);
		
		#EndRegion
		
		#Region PrintTaxInvoiceCompanyInfoArea
		
		CompanyInfoArea = Template.GetArea("CompanyInfo");
		
		InfoAboutCompany = DriveServer.InfoAboutLegalEntityIndividual(Header.Company, Header.DocumentDate, ,);
		CompanyInfoArea.Parameters.Fill(InfoAboutCompany);
		
		SpreadsheetDocument.Put(CompanyInfoArea);
		
		#EndRegion
		
		#Region PrintTaxInvoiceCounterpartyInfoArea
		
		CounterpartyInfoArea = Template.GetArea("CounterpartyInfo");
		CounterpartyInfoArea.Parameters.Fill(Header);
		
		InfoAboutCounterparty = DriveServer.InfoAboutLegalEntityIndividual(Header.Counterparty, Header.DocumentDate, ,);
		CounterpartyInfoArea.Parameters.Fill(InfoAboutCounterparty);
		
		SpreadsheetDocument.Put(CounterpartyInfoArea);
		
		#EndRegion
		
		#Region PrintTaxInvoiceCommentArea
		
		CommentArea = Template.GetArea("Comment");
		CommentArea.Parameters.Fill(Header);
		SpreadsheetDocument.Put(CommentArea);
		
		#EndRegion
		
		#Region PrintTaxInvoiceTotalsAndTaxesAreaPrefill
		
		TotalsAndTaxesAreasArray = New Array;
		
		LineTotalArea = Template.GetArea("LineTotal");
		LineTotalArea.Parameters.Fill(Header);
		
		TotalsAndTaxesAreasArray.Add(LineTotalArea);
		
		TaxesHeaderSel.Reset();
		If TaxesHeaderSel.FindNext(New Structure("Ref", Header.Ref)) Then
			
			TaxSectionHeaderArea = Template.GetArea("TaxSectionHeader");
			TotalsAndTaxesAreasArray.Add(TaxSectionHeaderArea);
			
			TaxesSel = TaxesHeaderSel.Select();
			While TaxesSel.Next() Do
				
				TaxSectionLineArea = Template.GetArea("TaxSectionLine");
				TaxSectionLineArea.Parameters.Fill(TaxesSel);
				TotalsAndTaxesAreasArray.Add(TaxSectionLineArea);
				
			EndDo;
			
		EndIf;
		
		#EndRegion
		
		#Region PrintTaxInvoiceLinesArea
		
		LineHeaderArea = Template.GetArea("LineHeader");
		SpreadsheetDocument.Put(LineHeaderArea);
		
		InvoiceSectionArea	= Template.GetArea("InvoiceSection");
		LineSectionArea		= Template.GetArea("LineSection");
		SeeNextPageArea		= Template.GetArea("SeeNextPage");
		EmptyLineArea		= Template.GetArea("EmptyLine");
		PageNumberArea		= Template.GetArea("PageNumber");
		
		PageNumber = 0;
		
		DocumentSelection = Header.Select(QueryResultIteration.ByGroups);
		While DocumentSelection.Next() Do
			
			InvoiceSectionArea.Parameters.Fill(DocumentSelection);
			InvoiceSectionArea.Parameters.ReferenceType = DocumentSelection.BasisDocument.Metadata().Synonym;
			InvoiceSectionArea.Parameters.ReferenceAmount = DocumentSelection.TotalCur;
			InvoiceSectionArea.Parameters.ReferenceDate = Format(DocumentSelection.ReferenceDate, "DLF=D");
			
			If DocumentSelection.DocumentCurrency <> DocumentSelection.PresentationCurrency Then
				InvoiceSectionArea.Parameters.ReferenceExchangeRate = StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = 'Exchange rate %1.'"), DocumentSelection.ReferenceRate);
			EndIf;

			AreasToBeChecked = New Array;
			AreasToBeChecked.Add(InvoiceSectionArea);
			For Each Area In TotalsAndTaxesAreasArray Do
				AreasToBeChecked.Add(Area);
			EndDo;
			AreasToBeChecked.Add(PageNumberArea);
			
			If CommonUse.SpreadsheetDocumentFitsPage(SpreadsheetDocument, AreasToBeChecked) Then
				SpreadsheetDocument.Put(InvoiceSectionArea);
			Else
				SpreadsheetDocument.Put(SeeNextPageArea);
				
				AreasToBeChecked.Clear();
				AreasToBeChecked.Add(EmptyLineArea);
				AreasToBeChecked.Add(PageNumberArea);
				
				For i = 1 To 50 Do
					If Not CommonUse.SpreadsheetDocumentFitsPage(SpreadsheetDocument, AreasToBeChecked)
						Or i = 50 Then
						
						PageNumber = PageNumber + 1;
						PageNumberArea.Parameters.PageNumber = PageNumber;
						SpreadsheetDocument.Put(PageNumberArea);
						Break;
						
					Else
						SpreadsheetDocument.Put(EmptyLineArea);
					EndIf;
				EndDo;
				
				SpreadsheetDocument.PutHorizontalPageBreak();
				SpreadsheetDocument.Put(TitleArea);
				SpreadsheetDocument.Put(LineHeaderArea);
				SpreadsheetDocument.Put(LineSectionArea);
			EndIf;
			
			TabSelection = DocumentSelection.Select();
			While TabSelection.Next() Do
				LineSectionArea.Parameters.Fill(TabSelection);
				
				PrintManagement.ComplimentProductDescription(LineSectionArea.Parameters.ProductDescription, TabSelection, SerialNumbersSel);
				
				AreasToBeChecked.Clear();
				AreasToBeChecked.Add(LineSectionArea);
				For Each Area In TotalsAndTaxesAreasArray Do
					AreasToBeChecked.Add(Area);
				EndDo;
				AreasToBeChecked.Add(PageNumberArea);
				
				If CommonUse.SpreadsheetDocumentFitsPage(SpreadsheetDocument, AreasToBeChecked) Then
					SpreadsheetDocument.Put(LineSectionArea);
				Else
					SpreadsheetDocument.Put(SeeNextPageArea);
					
					AreasToBeChecked.Clear();
					AreasToBeChecked.Add(EmptyLineArea);
					AreasToBeChecked.Add(PageNumberArea);
					
					For i = 1 To 50 Do
						If Not CommonUse.SpreadsheetDocumentFitsPage(SpreadsheetDocument, AreasToBeChecked)
							Or i = 50 Then
							
							PageNumber = PageNumber + 1;
							PageNumberArea.Parameters.PageNumber = PageNumber;
							SpreadsheetDocument.Put(PageNumberArea);
							Break;
							
						Else
							SpreadsheetDocument.Put(EmptyLineArea);
						EndIf;
					EndDo;
					
					SpreadsheetDocument.PutHorizontalPageBreak();
					SpreadsheetDocument.Put(TitleArea);
					SpreadsheetDocument.Put(LineHeaderArea);
					SpreadsheetDocument.Put(LineSectionArea);
				EndIf;
			EndDo;
			
			PrintableDocuments.Add(DocumentSelection.BasisDocument);
		EndDo;
		#EndRegion
		
		#Region PrintTaxInvoiceTotalsAndTaxesArea
		
		For Each Area In TotalsAndTaxesAreasArray Do
			SpreadsheetDocument.Put(Area);
		EndDo;
		
		AreasToBeChecked.Clear();
		AreasToBeChecked.Add(EmptyLineArea);
		AreasToBeChecked.Add(PageNumberArea);
		
		For i = 1 To 50 Do
			If Not CommonUse.SpreadsheetDocumentFitsPage(SpreadsheetDocument, AreasToBeChecked)
				Or i = 50 Then
				
				PageNumber = PageNumber + 1;
				PageNumberArea.Parameters.PageNumber = PageNumber;
				SpreadsheetDocument.Put(PageNumberArea);
				Break;
				
			Else
				SpreadsheetDocument.Put(EmptyLineArea);
			EndIf;
		EndDo;
		
		#EndRegion
		
		PrintManagement.SetDocumentPrintArea(SpreadsheetDocument, FirstLineNumber, PrintObjects, Header.Ref);
		
	EndDo;
	
	If ObjectsArray.Count() <> PrintableDocuments.Count() Then
		Errors = Undefined;
		For Each Document In ObjectsArray Do
			If PrintableDocuments.Find(Document) = Undefined Then
				MessageText = StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = 'Generate Tax invoice document for %1 before printing.'"), Document);
				CommonUseClientServer.AddUserError(Errors,, MessageText, Undefined);
			EndIf;
		EndDo;
		
		CommonUseClientServer.ShowErrorsToUser(Errors);
	EndIf;
	
	SpreadsheetDocument.FitToPage = True;
	
	Return SpreadsheetDocument;
	
EndFunction

// Generate printed forms of objects
//
Function PrintForm(ObjectsArray, PrintObjects, TemplateName) Export
	
	If TemplateName = "TaxInvoice" Then
		
		Return PrintTaxInvoice(ObjectsArray, PrintObjects, TemplateName)
		
	EndIf;
	
EndFunction

#EndRegion

#EndIf
