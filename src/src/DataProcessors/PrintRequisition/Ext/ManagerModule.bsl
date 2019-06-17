#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region PrintInterface

Function PrintForm(ObjectsArray, PrintObjects, TemplateName) Export
	
	If TemplateName = "Requisition" Then
		
		Return PrintRequisition(ObjectsArray, PrintObjects, TemplateName);
		
	EndIf;
	
EndFunction

Function GetSalesInvoiceQuery()
	
	Return
	"SELECT
	|	SalesInvoice.Ref AS Ref,
	|	SalesInvoice.Number AS Number,
	|	SalesInvoice.Date AS Date,
	|	SalesInvoice.Company AS Company,
	|	SalesInvoice.Counterparty AS FieldTo,
	|	SalesInvoice.Contract AS Contract,
	|	CAST(SalesInvoice.Comment AS STRING(1024)) AS Comment,
	|	SalesInvoice.Order AS Order,
	|	SalesInvoice.SalesOrderPosition AS SalesOrderPosition,
	|	SalesInvoice.StructuralUnit AS FieldFrom
	|INTO SalesInvoice
	|FROM
	|	Document.SalesInvoice AS SalesInvoice
	|WHERE
	|	SalesInvoice.Ref IN(&ObjectsArray)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SalesInvoice.Ref AS Ref,
	|	SalesInvoice.Number AS DocumentNumber,
	|	SalesInvoice.Date AS DocumentDate,
	|	SalesInvoice.Company AS Company,
	|	Companies.LogoFile AS CompanyLogoFile,
	|	SalesInvoice.Contract AS Contract,
	|	SalesInvoice.Comment AS Comment,
	|	SalesInvoice.FieldFrom AS FieldFrom,
	|	SalesInvoice.FieldTo AS FieldTo
	|INTO Header
	|FROM
	|	SalesInvoice AS SalesInvoice
	|		LEFT JOIN Catalog.Companies AS Companies
	|		ON SalesInvoice.Company = Companies.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SalesInvoiceInventory.Ref AS Ref,
	|	SalesInvoiceInventory.LineNumber AS LineNumber,
	|	SalesInvoiceInventory.Products AS Products,
	|	SalesInvoiceInventory.Characteristic AS Characteristic,
	|	SalesInvoiceInventory.Batch AS Batch,
	|	SalesInvoiceInventory.Quantity AS Quantity,
	|	SalesInvoiceInventory.MeasurementUnit AS MeasurementUnit,
	|	SalesInvoiceInventory.Order AS Order,
	|	SalesInvoiceInventory.ConnectionKey AS ConnectionKey
	|INTO FilteredInventory
	|FROM
	|	Header AS Header
	|		INNER JOIN Document.SalesInvoice.Inventory AS SalesInvoiceInventory
	|		ON Header.Ref = SalesInvoiceInventory.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Header.Ref AS Ref,
	|	Header.DocumentNumber AS DocumentNumber,
	|	Header.DocumentDate AS DocumentDate,
	|	Header.Company AS Company,
	|	Header.CompanyLogoFile AS CompanyLogoFile,
	|	Header.Contract AS Contract,
	|	Header.Comment AS Comment,
	|	MIN(FilteredInventory.LineNumber) AS LineNumber,
	|	CatalogProducts.SKU AS SKU,
	|	CASE
	|		WHEN (CAST(CatalogProducts.DescriptionFull AS STRING(1024))) <> """"
	|			THEN CAST(CatalogProducts.DescriptionFull AS STRING(1024))
	|		ELSE CatalogProducts.Description
	|	END AS ProductDescription,
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
	|	FilteredInventory.Products AS Products,
	|	FilteredInventory.Characteristic AS Characteristic,
	|	FilteredInventory.MeasurementUnit AS MeasurementUnit,
	|	FilteredInventory.Batch AS Batch,
	|	Header.FieldFrom AS FieldFrom,
	|	Header.FieldTo AS FieldTo
	|INTO Tabular
	|FROM
	|	Header AS Header
	|		INNER JOIN FilteredInventory AS FilteredInventory
	|		ON Header.Ref = FilteredInventory.Ref
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
	|	Header.CompanyLogoFile,
	|	Header.Contract,
	|	Header.Comment,
	|	CatalogProducts.SKU,
	|	CASE
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
	|	ISNULL(CatalogUOM.Description, CatalogUOMClassifier.Description),
	|	FilteredInventory.Products,
	|	CASE
	|		WHEN CatalogProducts.UseBatches
	|			THEN CatalogBatches.Description
	|		ELSE """"
	|	END,
	|	FilteredInventory.Characteristic,
	|	FilteredInventory.MeasurementUnit,
	|	FilteredInventory.Batch,
	|	Header.FieldFrom,
	|	Header.FieldTo
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Tabular.Ref AS Ref,
	|	Tabular.DocumentNumber AS DocumentNumber,
	|	Tabular.DocumentDate AS DocumentDate,
	|	Tabular.Company AS Company,
	|	Tabular.CompanyLogoFile AS CompanyLogoFile,
	|	Tabular.Contract AS Contract,
	|	Tabular.Comment AS Comment,
	|	Tabular.LineNumber AS LineNumber,
	|	Tabular.SKU AS SKU,
	|	Tabular.ProductDescription AS ProductDescription,
	|	Tabular.UseSerialNumbers AS UseSerialNumbers,
	|	Tabular.Quantity AS Quantity,
	|	Tabular.Products AS Products,
	|	Tabular.CharacteristicDescription AS CharacteristicDescription,
	|	Tabular.BatchDescription AS BatchDescription,
	|	Tabular.ConnectionKey AS ConnectionKey,
	|	Tabular.Characteristic AS Characteristic,
	|	Tabular.MeasurementUnit AS MeasurementUnit,
	|	Tabular.Batch AS Batch,
	|	Tabular.UOM AS UOM,
	|	FALSE AS ContentUsed,
	|	Tabular.FieldFrom AS FieldFrom,
	|	Tabular.FieldTo AS FieldTo
	|FROM
	|	Tabular AS Tabular
	|
	|ORDER BY
	|	Tabular.DocumentNumber,
	|	LineNumber
	|TOTALS
	|	MAX(DocumentNumber),
	|	MAX(DocumentDate),
	|	MAX(Company),
	|	MAX(CompanyLogoFile),
	|	MAX(Contract),
	|	MAX(Comment),
	|	COUNT(LineNumber),
	|	SUM(Quantity),
	|	MAX(FieldFrom),
	|	MAX(FieldTo)
	|BY
	|	Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Tabular.ConnectionKey AS ConnectionKey,
	|	Tabular.Ref AS Ref,
	|	SerialNumbers.Description AS SerialNumber
	|FROM
	|	Tabular AS Tabular
	|		INNER JOIN Document.SalesInvoice.SerialNumbers AS SalesInvoiceSerialNumbers
	|		ON Tabular.Ref = SalesInvoiceSerialNumbers.Ref
	|			AND Tabular.ConnectionKey = SalesInvoiceSerialNumbers.ConnectionKey
	|		INNER JOIN Catalog.SerialNumbers AS SerialNumbers
	|		ON SalesInvoiceSerialNumbers.SerialNumber = SerialNumbers.Ref";

EndFunction

Function GetInventoryTransferQuery()
	
	Return
	"SELECT
	|	InventoryTransfer.Ref AS Ref,
	|	InventoryTransfer.Number AS Number,
	|	InventoryTransfer.Date AS Date,
	|	InventoryTransfer.Company AS Company,
	|	InventoryTransfer.StructuralUnit AS FieldFrom,
	|	InventoryTransfer.StructuralUnitPayee AS Contract,
	|	CAST(InventoryTransfer.Comment AS STRING(1024)) AS Comment,
	|	InventoryTransfer.SalesOrderPosition AS SalesOrderPosition,
	|	InventoryTransfer.StructuralUnitPayee AS FieldTo
	|INTO InventoryTransfer
	|FROM
	|	Document.InventoryTransfer AS InventoryTransfer
	|WHERE
	|	InventoryTransfer.Ref IN(&ObjectsArray)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	InventoryTransfer.Ref AS Ref,
	|	InventoryTransfer.Number AS DocumentNumber,
	|	InventoryTransfer.Date AS DocumentDate,
	|	InventoryTransfer.Company AS Company,
	|	Companies.LogoFile AS CompanyLogoFile,
	|	InventoryTransfer.Contract AS Contract,
	|	InventoryTransfer.Comment AS Comment,
	|	InventoryTransfer.FieldTo AS FieldTo,
	|	InventoryTransfer.FieldFrom AS FieldFrom
	|INTO Header
	|FROM
	|	InventoryTransfer AS InventoryTransfer
	|		LEFT JOIN Catalog.Companies AS Companies
	|		ON InventoryTransfer.Company = Companies.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	InventoryTransferInventory.Ref AS Ref,
	|	InventoryTransferInventory.LineNumber AS LineNumber,
	|	InventoryTransferInventory.Products AS Products,
	|	InventoryTransferInventory.Characteristic AS Characteristic,
	|	InventoryTransferInventory.Batch AS Batch,
	|	InventoryTransferInventory.Quantity AS Quantity,
	|	InventoryTransferInventory.MeasurementUnit AS MeasurementUnit,
	|	InventoryTransferInventory.ConnectionKey AS ConnectionKey
	|INTO FilteredInventory
	|FROM
	|	Header AS Header
	|		INNER JOIN Document.InventoryTransfer.Inventory AS InventoryTransferInventory
	|		ON Header.Ref = InventoryTransferInventory.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Header.Ref AS Ref,
	|	Header.DocumentNumber AS DocumentNumber,
	|	Header.DocumentDate AS DocumentDate,
	|	Header.Company AS Company,
	|	Header.CompanyLogoFile AS CompanyLogoFile,
	|	Header.Contract AS Contract,
	|	Header.Comment AS Comment,
	|	MIN(FilteredInventory.LineNumber) AS LineNumber,
	|	CatalogProducts.SKU AS SKU,
	|	CASE
	|		WHEN (CAST(CatalogProducts.DescriptionFull AS STRING(1024))) <> """"
	|			THEN CAST(CatalogProducts.DescriptionFull AS STRING(1024))
	|		ELSE CatalogProducts.Description
	|	END AS ProductDescription,
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
	|	FilteredInventory.Products AS Products,
	|	FilteredInventory.Characteristic AS Characteristic,
	|	FilteredInventory.MeasurementUnit AS MeasurementUnit,
	|	FilteredInventory.Batch AS Batch,
	|	Header.FieldTo AS FieldTo,
	|	Header.FieldFrom AS FieldFrom
	|INTO Tabular
	|FROM
	|	Header AS Header
	|		INNER JOIN FilteredInventory AS FilteredInventory
	|		ON Header.Ref = FilteredInventory.Ref
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
	|	Header.CompanyLogoFile,
	|	Header.Contract,
	|	Header.Comment,
	|	CatalogProducts.SKU,
	|	CASE
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
	|	ISNULL(CatalogUOM.Description, CatalogUOMClassifier.Description),
	|	FilteredInventory.Products,
	|	CASE
	|		WHEN CatalogProducts.UseBatches
	|			THEN CatalogBatches.Description
	|		ELSE """"
	|	END,
	|	FilteredInventory.Characteristic,
	|	FilteredInventory.MeasurementUnit,
	|	FilteredInventory.Batch,
	|	Header.FieldTo,
	|	Header.FieldFrom
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Tabular.Ref AS Ref,
	|	Tabular.DocumentNumber AS DocumentNumber,
	|	Tabular.DocumentDate AS DocumentDate,
	|	Tabular.Company AS Company,
	|	Tabular.CompanyLogoFile AS CompanyLogoFile,
	|	Tabular.Contract AS Contract,
	|	Tabular.Comment AS Comment,
	|	Tabular.LineNumber AS LineNumber,
	|	Tabular.SKU AS SKU,
	|	Tabular.ProductDescription AS ProductDescription,
	|	Tabular.UseSerialNumbers AS UseSerialNumbers,
	|	Tabular.Quantity AS Quantity,
	|	Tabular.Products AS Products,
	|	Tabular.CharacteristicDescription AS CharacteristicDescription,
	|	Tabular.BatchDescription AS BatchDescription,
	|	Tabular.ConnectionKey AS ConnectionKey,
	|	Tabular.Characteristic AS Characteristic,
	|	Tabular.MeasurementUnit AS MeasurementUnit,
	|	Tabular.Batch AS Batch,
	|	Tabular.UOM AS UOM,
	|	FALSE AS ContentUsed,
	|	Tabular.FieldTo AS FieldTo,
	|	Tabular.FieldFrom AS FieldFrom
	|FROM
	|	Tabular AS Tabular
	|
	|ORDER BY
	|	Tabular.DocumentNumber,
	|	LineNumber
	|TOTALS
	|	MAX(DocumentNumber),
	|	MAX(DocumentDate),
	|	MAX(Company),
	|	MAX(CompanyLogoFile),
	|	MAX(Contract),
	|	MAX(Comment),
	|	COUNT(LineNumber),
	|	SUM(Quantity),
	|	MAX(FieldTo),
	|	MAX(FieldFrom)
	|BY
	|	Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Tabular.ConnectionKey AS ConnectionKey,
	|	Tabular.Ref AS Ref,
	|	SerialNumbers.Description AS SerialNumber
	|FROM
	|	Tabular AS Tabular
	|		INNER JOIN Document.InventoryTransfer.SerialNumbers AS InventoryTransferSerialNumbers
	|		ON Tabular.Ref = InventoryTransferSerialNumbers.Ref
	|			AND Tabular.ConnectionKey = InventoryTransferSerialNumbers.ConnectionKey
	|		INNER JOIN Catalog.SerialNumbers AS SerialNumbers
	|		ON (InventoryTransferSerialNumbers.SerialNumber = SerialNumbers.Ref)";

EndFunction

Function GetDebitNoteQuery()
	
	Return
	"SELECT
	|	DebitNote.Ref AS Ref,
	|	DebitNote.Number AS Number,
	|	DebitNote.Date AS Date,
	|	DebitNote.Company AS Company,
	|	CAST(DebitNote.Comment AS STRING(1024)) AS Comment,
	|	DebitNote.StructuralUnit AS FieldFrom,
	|	DebitNote.Counterparty AS FieldTo
	|INTO DebitNote
	|FROM
	|	Document.DebitNote AS DebitNote
	|WHERE
	|	DebitNote.Ref IN(&ObjectsArray)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DebitNote.Ref AS Ref,
	|	DebitNote.Number AS DocumentNumber,
	|	DebitNote.Date AS DocumentDate,
	|	DebitNote.Company AS Company,
	|	Companies.LogoFile AS CompanyLogoFile,
	|	DebitNote.Comment AS Comment,
	|	DebitNote.FieldFrom AS FieldFrom,
	|	DebitNote.FieldTo AS FieldTo
	|INTO Header
	|FROM
	|	DebitNote AS DebitNote
	|		LEFT JOIN Catalog.Companies AS Companies
	|		ON DebitNote.Company = Companies.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DebitNoteInventory.Ref AS Ref,
	|	DebitNoteInventory.LineNumber AS LineNumber,
	|	DebitNoteInventory.Products AS Products,
	|	DebitNoteInventory.Characteristic AS Characteristic,
	|	DebitNoteInventory.Batch AS Batch,
	|	DebitNoteInventory.Quantity AS Quantity,
	|	DebitNoteInventory.MeasurementUnit AS MeasurementUnit,
	|	DebitNoteInventory.ConnectionKey AS ConnectionKey
	|INTO FilteredInventory
	|FROM
	|	DebitNote AS DebitNote
	|		INNER JOIN Document.DebitNote.Inventory AS DebitNoteInventory
	|		ON DebitNote.Ref = DebitNoteInventory.Ref
	|WHERE
	|	DebitNoteInventory.Quantity > 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Header.Ref AS Ref,
	|	Header.DocumentNumber AS DocumentNumber,
	|	Header.DocumentDate AS DocumentDate,
	|	Header.Company AS Company,
	|	Header.CompanyLogoFile AS CompanyLogoFile,
	|	Header.Comment AS Comment,
	|	MIN(FilteredInventory.LineNumber) AS LineNumber,
	|	CatalogProducts.SKU AS SKU,
	|	CASE
	|		WHEN (CAST(CatalogProducts.DescriptionFull AS STRING(1024))) <> """"
	|			THEN CAST(CatalogProducts.DescriptionFull AS STRING(1024))
	|		ELSE CatalogProducts.Description
	|	END AS ProductDescription,
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
	|	FilteredInventory.Products AS Products,
	|	FilteredInventory.Characteristic AS Characteristic,
	|	FilteredInventory.MeasurementUnit AS MeasurementUnit,
	|	FilteredInventory.Batch AS Batch,
	|	Header.FieldFrom AS FieldFrom,
	|	Header.FieldTo AS FieldTo
	|INTO Tabular
	|FROM
	|	Header AS Header
	|		INNER JOIN FilteredInventory AS FilteredInventory
	|		ON Header.Ref = FilteredInventory.Ref
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
	|	Header.CompanyLogoFile,
	|	Header.Comment,
	|	CatalogProducts.SKU,
	|	CASE
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
	|	ISNULL(CatalogUOM.Description, CatalogUOMClassifier.Description),
	|	FilteredInventory.Products,
	|	CASE
	|		WHEN CatalogProducts.UseBatches
	|			THEN CatalogBatches.Description
	|		ELSE """"
	|	END,
	|	FilteredInventory.Characteristic,
	|	FilteredInventory.MeasurementUnit,
	|	FilteredInventory.Batch,
	|	Header.FieldFrom,
	|	Header.FieldTo
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Tabular.Ref AS Ref,
	|	Tabular.DocumentNumber AS DocumentNumber,
	|	Tabular.DocumentDate AS DocumentDate,
	|	Tabular.Company AS Company,
	|	Tabular.CompanyLogoFile AS CompanyLogoFile,
	|	Tabular.Comment AS Comment,
	|	Tabular.LineNumber AS LineNumber,
	|	Tabular.SKU AS SKU,
	|	Tabular.ProductDescription AS ProductDescription,
	|	Tabular.UseSerialNumbers AS UseSerialNumbers,
	|	Tabular.Quantity AS Quantity,
	|	Tabular.Products AS Products,
	|	Tabular.CharacteristicDescription AS CharacteristicDescription,
	|	Tabular.BatchDescription AS BatchDescription,
	|	Tabular.ConnectionKey AS ConnectionKey,
	|	Tabular.Characteristic AS Characteristic,
	|	Tabular.MeasurementUnit AS MeasurementUnit,
	|	Tabular.Batch AS Batch,
	|	Tabular.UOM AS UOM,
	|	FALSE AS ContentUsed,
	|	Tabular.FieldFrom AS FieldFrom,
	|	Tabular.FieldTo AS FieldTo
	|FROM
	|	Tabular AS Tabular
	|
	|ORDER BY
	|	Tabular.DocumentNumber,
	|	LineNumber
	|TOTALS
	|	MAX(DocumentNumber),
	|	MAX(DocumentDate),
	|	MAX(Company),
	|	MAX(CompanyLogoFile),
	|	MAX(Comment),
	|	COUNT(LineNumber),
	|	SUM(Quantity),
	|	MAX(FieldFrom),
	|	MAX(FieldTo)
	|BY
	|	Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Tabular.ConnectionKey AS ConnectionKey,
	|	Tabular.Ref AS Ref,
	|	SerialNumbers.Description AS SerialNumber
	|FROM
	|	Tabular AS Tabular
	|		INNER JOIN Document.DebitNote.SerialNumbers AS DebitNoteSerialNumbers
	|		ON Tabular.Ref = DebitNoteSerialNumbers.Ref
	|			AND Tabular.ConnectionKey = DebitNoteSerialNumbers.ConnectionKey
	|		INNER JOIN Catalog.SerialNumbers AS SerialNumbers
	|		ON (DebitNoteSerialNumbers.SerialNumber = SerialNumbers.Ref)";

EndFunction

Function GetSubcontractorReportIssuedQuery()
	
	Return
	"SELECT
	|	SubcontractorReportIssued.Ref AS Ref,
	|	SubcontractorReportIssued.Number AS Number,
	|	SubcontractorReportIssued.Date AS Date,
	|	SubcontractorReportIssued.Company AS Company,
	|	CAST(SubcontractorReportIssued.Comment AS STRING(1024)) AS Comment,
	|	SubcontractorReportIssued.StructuralUnit AS FieldFrom,
	|	SubcontractorReportIssued.Counterparty AS FieldTo
	|INTO SubcontractorReportIssued
	|FROM
	|	Document.SubcontractorReportIssued AS SubcontractorReportIssued
	|WHERE
	|	SubcontractorReportIssued.Ref IN(&ObjectsArray)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SubcontractorReportIssued.Ref AS Ref,
	|	SubcontractorReportIssued.Number AS DocumentNumber,
	|	SubcontractorReportIssued.Date AS DocumentDate,
	|	SubcontractorReportIssued.Company AS Company,
	|	Companies.LogoFile AS CompanyLogoFile,
	|	SubcontractorReportIssued.Comment AS Comment,
	|	SubcontractorReportIssued.FieldFrom AS FieldFrom,
	|	SubcontractorReportIssued.FieldTo AS FieldTo
	|INTO Header
	|FROM
	|	SubcontractorReportIssued AS SubcontractorReportIssued
	|		LEFT JOIN Catalog.Companies AS Companies
	|		ON SubcontractorReportIssued.Company = Companies.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SubcontractorReportIssuedProducts.Ref AS Ref,
	|	SubcontractorReportIssuedProducts.LineNumber AS LineNumber,
	|	SubcontractorReportIssuedProducts.Products AS Products,
	|	SubcontractorReportIssuedProducts.Characteristic AS Characteristic,
	|	SubcontractorReportIssuedProducts.Batch AS Batch,
	|	SubcontractorReportIssuedProducts.Quantity AS Quantity,
	|	SubcontractorReportIssuedProducts.MeasurementUnit AS MeasurementUnit,
	|	SubcontractorReportIssuedProducts.ConnectionKey AS ConnectionKey
	|INTO FilteredInventory
	|FROM
	|	SubcontractorReportIssued AS SubcontractorReportIssued
	|		INNER JOIN Document.SubcontractorReportIssued.Products AS SubcontractorReportIssuedProducts
	|		ON SubcontractorReportIssued.Ref = SubcontractorReportIssuedProducts.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Header.Ref AS Ref,
	|	Header.DocumentNumber AS DocumentNumber,
	|	Header.DocumentDate AS DocumentDate,
	|	Header.Company AS Company,
	|	Header.CompanyLogoFile AS CompanyLogoFile,
	|	Header.Comment AS Comment,
	|	MIN(FilteredInventory.LineNumber) AS LineNumber,
	|	CatalogProducts.SKU AS SKU,
	|	CASE
	|		WHEN (CAST(CatalogProducts.DescriptionFull AS STRING(1024))) <> """"
	|			THEN CAST(CatalogProducts.DescriptionFull AS STRING(1024))
	|		ELSE CatalogProducts.Description
	|	END AS ProductDescription,
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
	|	FilteredInventory.Products AS Products,
	|	FilteredInventory.Characteristic AS Characteristic,
	|	FilteredInventory.MeasurementUnit AS MeasurementUnit,
	|	FilteredInventory.Batch AS Batch,
	|	Header.FieldFrom AS FieldFrom,
	|	Header.FieldTo AS FieldTo
	|INTO Tabular
	|FROM
	|	Header AS Header
	|		INNER JOIN FilteredInventory AS FilteredInventory
	|		ON Header.Ref = FilteredInventory.Ref
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
	|	Header.CompanyLogoFile,
	|	Header.Comment,
	|	CatalogProducts.SKU,
	|	CASE
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
	|	ISNULL(CatalogUOM.Description, CatalogUOMClassifier.Description),
	|	FilteredInventory.Products,
	|	CASE
	|		WHEN CatalogProducts.UseBatches
	|			THEN CatalogBatches.Description
	|		ELSE """"
	|	END,
	|	FilteredInventory.Characteristic,
	|	FilteredInventory.MeasurementUnit,
	|	FilteredInventory.Batch,
	|	Header.FieldFrom,
	|	Header.FieldTo
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Tabular.Ref AS Ref,
	|	Tabular.DocumentNumber AS DocumentNumber,
	|	Tabular.DocumentDate AS DocumentDate,
	|	Tabular.Company AS Company,
	|	Tabular.CompanyLogoFile AS CompanyLogoFile,
	|	Tabular.Comment AS Comment,
	|	Tabular.LineNumber AS LineNumber,
	|	Tabular.SKU AS SKU,
	|	Tabular.ProductDescription AS ProductDescription,
	|	Tabular.UseSerialNumbers AS UseSerialNumbers,
	|	Tabular.Quantity AS Quantity,
	|	Tabular.Products AS Products,
	|	Tabular.CharacteristicDescription AS CharacteristicDescription,
	|	Tabular.BatchDescription AS BatchDescription,
	|	Tabular.ConnectionKey AS ConnectionKey,
	|	Tabular.Characteristic AS Characteristic,
	|	Tabular.MeasurementUnit AS MeasurementUnit,
	|	Tabular.Batch AS Batch,
	|	Tabular.UOM AS UOM,
	|	FALSE AS ContentUsed,
	|	Tabular.FieldFrom AS FieldFrom,
	|	Tabular.FieldTo AS FieldTo
	|FROM
	|	Tabular AS Tabular
	|
	|ORDER BY
	|	Tabular.DocumentNumber,
	|	LineNumber
	|TOTALS
	|	MAX(DocumentNumber),
	|	MAX(DocumentDate),
	|	MAX(Company),
	|	MAX(CompanyLogoFile),
	|	MAX(Comment),
	|	COUNT(LineNumber),
	|	SUM(Quantity),
	|	MAX(FieldFrom),
	|	MAX(FieldTo)
	|BY
	|	Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Tabular.ConnectionKey AS ConnectionKey,
	|	Tabular.Ref AS Ref,
	|	SerialNumbers.Description AS SerialNumber
	|FROM
	|	Tabular AS Tabular
	|		INNER JOIN Document.SubcontractorReportIssued.SerialNumbers AS SubcontractorReportIssuedSerialNumbers
	|		ON Tabular.Ref = SubcontractorReportIssuedSerialNumbers.Ref
	|			AND Tabular.ConnectionKey = SubcontractorReportIssuedSerialNumbers.ConnectionKey
	|		INNER JOIN Catalog.SerialNumbers AS SerialNumbers
	|		ON (SubcontractorReportIssuedSerialNumbers.SerialNumber = SerialNumbers.Ref)";

EndFunction

Function GetGoodsIssueQuery()
	
	Return
	"SELECT
	|	GoodsIssue.Ref AS Ref,
	|	GoodsIssue.Number AS Number,
	|	GoodsIssue.Date AS Date,
	|	GoodsIssue.Company AS Company,
	|	CAST(GoodsIssue.Comment AS STRING(1024)) AS Comment,
	|	GoodsIssue.StructuralUnit AS FieldFrom,
	|	GoodsIssue.Counterparty AS FieldTo
	|INTO GoodsIssue
	|FROM
	|	Document.GoodsIssue AS GoodsIssue
	|WHERE
	|	GoodsIssue.Ref IN(&ObjectsArray)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	GoodsIssue.Ref AS Ref,
	|	GoodsIssue.Number AS DocumentNumber,
	|	GoodsIssue.Date AS DocumentDate,
	|	GoodsIssue.Company AS Company,
	|	Companies.LogoFile AS CompanyLogoFile,
	|	GoodsIssue.Comment AS Comment,
	|	GoodsIssue.FieldFrom AS FieldFrom,
	|	GoodsIssue.FieldTo AS FieldTo
	|INTO Header
	|FROM
	|	GoodsIssue AS GoodsIssue
	|		LEFT JOIN Catalog.Companies AS Companies
	|		ON GoodsIssue.Company = Companies.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	GoodsIssueProducts.Ref AS Ref,
	|	GoodsIssueProducts.LineNumber AS LineNumber,
	|	GoodsIssueProducts.Products AS Products,
	|	GoodsIssueProducts.Characteristic AS Characteristic,
	|	GoodsIssueProducts.Batch AS Batch,
	|	GoodsIssueProducts.Quantity AS Quantity,
	|	GoodsIssueProducts.MeasurementUnit AS MeasurementUnit,
	|	GoodsIssueProducts.ConnectionKey AS ConnectionKey
	|INTO FilteredInventory
	|FROM
	|	GoodsIssue AS GoodsIssue
	|		INNER JOIN Document.GoodsIssue.Products AS GoodsIssueProducts
	|		ON GoodsIssue.Ref = GoodsIssueProducts.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Header.Ref AS Ref,
	|	Header.DocumentNumber AS DocumentNumber,
	|	Header.DocumentDate AS DocumentDate,
	|	Header.Company AS Company,
	|	Header.CompanyLogoFile AS CompanyLogoFile,
	|	Header.Comment AS Comment,
	|	MIN(FilteredInventory.LineNumber) AS LineNumber,
	|	CatalogProducts.SKU AS SKU,
	|	CASE
	|		WHEN (CAST(CatalogProducts.DescriptionFull AS STRING(1024))) <> """"
	|			THEN CAST(CatalogProducts.DescriptionFull AS STRING(1024))
	|		ELSE CatalogProducts.Description
	|	END AS ProductDescription,
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
	|	FilteredInventory.Products AS Products,
	|	FilteredInventory.Characteristic AS Characteristic,
	|	FilteredInventory.MeasurementUnit AS MeasurementUnit,
	|	FilteredInventory.Batch AS Batch,
	|	Header.FieldFrom AS FieldFrom,
	|	Header.FieldTo AS FieldTo
	|INTO Tabular
	|FROM
	|	Header AS Header
	|		INNER JOIN FilteredInventory AS FilteredInventory
	|		ON Header.Ref = FilteredInventory.Ref
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
	|	Header.CompanyLogoFile,
	|	Header.Comment,
	|	CatalogProducts.SKU,
	|	CASE
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
	|	ISNULL(CatalogUOM.Description, CatalogUOMClassifier.Description),
	|	FilteredInventory.Products,
	|	CASE
	|		WHEN CatalogProducts.UseBatches
	|			THEN CatalogBatches.Description
	|		ELSE """"
	|	END,
	|	FilteredInventory.Characteristic,
	|	FilteredInventory.MeasurementUnit,
	|	FilteredInventory.Batch,
	|	Header.FieldFrom,
	|	Header.FieldTo
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Tabular.Ref AS Ref,
	|	Tabular.DocumentNumber AS DocumentNumber,
	|	Tabular.DocumentDate AS DocumentDate,
	|	Tabular.Company AS Company,
	|	Tabular.CompanyLogoFile AS CompanyLogoFile,
	|	Tabular.Comment AS Comment,
	|	Tabular.LineNumber AS LineNumber,
	|	Tabular.SKU AS SKU,
	|	Tabular.ProductDescription AS ProductDescription,
	|	Tabular.UseSerialNumbers AS UseSerialNumbers,
	|	Tabular.Quantity AS Quantity,
	|	Tabular.Products AS Products,
	|	Tabular.CharacteristicDescription AS CharacteristicDescription,
	|	Tabular.BatchDescription AS BatchDescription,
	|	Tabular.ConnectionKey AS ConnectionKey,
	|	Tabular.Characteristic AS Characteristic,
	|	Tabular.MeasurementUnit AS MeasurementUnit,
	|	Tabular.Batch AS Batch,
	|	Tabular.UOM AS UOM,
	|	FALSE AS ContentUsed,
	|	Tabular.FieldFrom AS FieldFrom,
	|	Tabular.FieldTo AS FieldTo
	|FROM
	|	Tabular AS Tabular
	|
	|ORDER BY
	|	Tabular.DocumentNumber,
	|	LineNumber
	|TOTALS
	|	MAX(DocumentNumber),
	|	MAX(DocumentDate),
	|	MAX(Company),
	|	MAX(CompanyLogoFile),
	|	MAX(Comment),
	|	COUNT(LineNumber),
	|	SUM(Quantity),
	|	MAX(FieldFrom),
	|	MAX(FieldTo)
	|BY
	|	Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Tabular.ConnectionKey AS ConnectionKey,
	|	Tabular.Ref AS Ref,
	|	SerialNumbers.Description AS SerialNumber
	|FROM
	|	Tabular AS Tabular
	|		INNER JOIN Document.GoodsIssue.SerialNumbers AS GoodsIssueSerialNumbers
	|		ON Tabular.Ref = GoodsIssueSerialNumbers.Ref
	|			AND Tabular.ConnectionKey = GoodsIssueSerialNumbers.ConnectionKey
	|		INNER JOIN Catalog.SerialNumbers AS SerialNumbers
	|		ON (GoodsIssueSerialNumbers.SerialNumber = SerialNumbers.Ref)";

EndFunction

Function GetWorkOrderQuery()
	
	Return
	"SELECT
	|	SalesOrder.Ref AS Ref,
	|	SalesOrder.Number AS Number,
	|	SalesOrder.Date AS Date,
	|	SalesOrder.Company AS Company,
	|	CAST(SalesOrder.Comment AS STRING(1024)) AS Comment,
	|	SalesOrder.StructuralUnitReserve AS FieldFrom,
	|	SalesOrder.Counterparty AS FieldTo
	|INTO WorkOrder
	|FROM
	|	Document.SalesOrder AS SalesOrder
	|WHERE
	|	SalesOrder.Ref IN(&ObjectsArray)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	WorkOrder.Ref AS Ref,
	|	WorkOrder.Number AS DocumentNumber,
	|	WorkOrder.Date AS DocumentDate,
	|	WorkOrder.Company AS Company,
	|	Companies.LogoFile AS CompanyLogoFile,
	|	WorkOrder.Comment AS Comment,
	|	WorkOrder.FieldFrom AS FieldFrom,
	|	WorkOrder.FieldTo AS FieldTo
	|INTO Header
	|FROM
	|	WorkOrder AS WorkOrder
	|		LEFT JOIN Catalog.Companies AS Companies
	|		ON WorkOrder.Company = Companies.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SalesOrderMaterials.Ref AS Ref,
	|	SalesOrderMaterials.LineNumber AS LineNumber,
	|	SalesOrderMaterials.Products AS Products,
	|	SalesOrderMaterials.Characteristic AS Characteristic,
	|	SalesOrderMaterials.Batch AS Batch,
	|	SalesOrderMaterials.Quantity AS Quantity,
	|	SalesOrderMaterials.MeasurementUnit AS MeasurementUnit,
	|	SalesOrderMaterials.ConnectionKey AS ConnectionKey
	|INTO FilteredInventory
	|FROM
	|	WorkOrder AS WorkOrder
	|		INNER JOIN Document.SalesOrder.Materials AS SalesOrderMaterials
	|		ON WorkOrder.Ref = SalesOrderMaterials.Ref
	|
	|UNION ALL
	|
	|SELECT
	|	SalesOrderInventory.Ref,
	|	SalesOrderInventory.LineNumber,
	|	SalesOrderInventory.Products,
	|	SalesOrderInventory.Characteristic,
	|	SalesOrderInventory.Batch,
	|	SalesOrderInventory.Quantity,
	|	SalesOrderInventory.MeasurementUnit,
	|	SalesOrderInventory.ConnectionKey
	|FROM
	|	WorkOrder AS WorkOrder
	|		INNER JOIN Document.SalesOrder.Inventory AS SalesOrderInventory
	|		ON WorkOrder.Ref = SalesOrderInventory.Ref
	|WHERE
	|	SalesOrderInventory.ProductsTypeInventory
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Header.Ref AS Ref,
	|	Header.DocumentNumber AS DocumentNumber,
	|	Header.DocumentDate AS DocumentDate,
	|	Header.Company AS Company,
	|	Header.CompanyLogoFile AS CompanyLogoFile,
	|	Header.Comment AS Comment,
	|	MIN(FilteredInventory.LineNumber) AS LineNumber,
	|	CatalogProducts.SKU AS SKU,
	|	CASE
	|		WHEN (CAST(CatalogProducts.DescriptionFull AS STRING(1024))) <> """"
	|			THEN CAST(CatalogProducts.DescriptionFull AS STRING(1024))
	|		ELSE CatalogProducts.Description
	|	END AS ProductDescription,
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
	|	FilteredInventory.Products AS Products,
	|	FilteredInventory.Characteristic AS Characteristic,
	|	FilteredInventory.MeasurementUnit AS MeasurementUnit,
	|	FilteredInventory.Batch AS Batch,
	|	Header.FieldFrom AS FieldFrom,
	|	Header.FieldTo AS FieldTo
	|INTO Tabular
	|FROM
	|	Header AS Header
	|		INNER JOIN FilteredInventory AS FilteredInventory
	|		ON Header.Ref = FilteredInventory.Ref
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
	|	Header.CompanyLogoFile,
	|	Header.Comment,
	|	CatalogProducts.SKU,
	|	CASE
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
	|	ISNULL(CatalogUOM.Description, CatalogUOMClassifier.Description),
	|	FilteredInventory.Products,
	|	CASE
	|		WHEN CatalogProducts.UseBatches
	|			THEN CatalogBatches.Description
	|		ELSE """"
	|	END,
	|	FilteredInventory.Characteristic,
	|	FilteredInventory.MeasurementUnit,
	|	FilteredInventory.Batch,
	|	Header.FieldFrom,
	|	Header.FieldTo
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Tabular.Ref AS Ref,
	|	Tabular.DocumentNumber AS DocumentNumber,
	|	Tabular.DocumentDate AS DocumentDate,
	|	Tabular.Company AS Company,
	|	Tabular.CompanyLogoFile AS CompanyLogoFile,
	|	Tabular.Comment AS Comment,
	|	Tabular.LineNumber AS LineNumber,
	|	Tabular.SKU AS SKU,
	|	Tabular.ProductDescription AS ProductDescription,
	|	Tabular.UseSerialNumbers AS UseSerialNumbers,
	|	Tabular.Quantity AS Quantity,
	|	Tabular.Products AS Products,
	|	Tabular.CharacteristicDescription AS CharacteristicDescription,
	|	Tabular.BatchDescription AS BatchDescription,
	|	Tabular.ConnectionKey AS ConnectionKey,
	|	Tabular.Characteristic AS Characteristic,
	|	Tabular.MeasurementUnit AS MeasurementUnit,
	|	Tabular.Batch AS Batch,
	|	Tabular.UOM AS UOM,
	|	FALSE AS ContentUsed,
	|	Tabular.FieldFrom AS FieldFrom,
	|	Tabular.FieldTo AS FieldTo
	|FROM
	|	Tabular AS Tabular
	|
	|ORDER BY
	|	Tabular.DocumentNumber,
	|	LineNumber
	|TOTALS
	|	MAX(DocumentNumber),
	|	MAX(DocumentDate),
	|	MAX(Company),
	|	MAX(CompanyLogoFile),
	|	MAX(Comment),
	|	COUNT(LineNumber),
	|	SUM(Quantity),
	|	MAX(FieldFrom),
	|	MAX(FieldTo)
	|BY
	|	Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Tabular.ConnectionKey AS ConnectionKey,
	|	Tabular.Ref AS Ref,
	|	SerialNumbers.Description AS SerialNumber
	|FROM
	|	Tabular AS Tabular
	|		INNER JOIN Document.SalesOrder.SerialNumbers AS SalesOrderSerialNumbers
	|			INNER JOIN Catalog.SerialNumbers AS SerialNumbers
	|			ON SalesOrderSerialNumbers.SerialNumber = SerialNumbers.Ref
	|		ON Tabular.Ref = SalesOrderSerialNumbers.Ref
	|			AND Tabular.ConnectionKey = SalesOrderSerialNumbers.ConnectionKey
	|
	|UNION ALL
	|
	|SELECT
	|	Tabular.ConnectionKey,
	|	Tabular.Ref,
	|	SerialNumbers.Description
	|FROM
	|	Tabular AS Tabular
	|		INNER JOIN Document.SalesOrder.SerialNumbersMaterials AS SalesOrderSerialNumbersMaterials
	|		ON Tabular.Ref = SalesOrderSerialNumbersMaterials.Ref
	|			AND Tabular.ConnectionKey = SalesOrderSerialNumbersMaterials.ConnectionKey
	|		INNER JOIN Catalog.SerialNumbers AS SerialNumbers
	|		ON (SalesOrderSerialNumbersMaterials.SerialNumber = SerialNumbers.Ref)";

EndFunction

Function GetInventoryWriteOffQuery()
	
	Return
	"SELECT
	|	InventoryWriteOff.Ref AS Ref,
	|	InventoryWriteOff.Number AS Number,
	|	InventoryWriteOff.Date AS Date,
	|	InventoryWriteOff.Company AS Company,
	|	CAST(InventoryWriteOff.Comment AS STRING(1024)) AS Comment,
	|	InventoryWriteOff.Correspondence AS FieldTo,
	|	InventoryWriteOff.StructuralUnit AS FieldFrom
	|INTO InventoryWriteOff
	|FROM
	|	Document.InventoryWriteOff AS InventoryWriteOff
	|WHERE
	|	InventoryWriteOff.Ref IN(&ObjectsArray)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	InventoryWriteOff.Ref AS Ref,
	|	InventoryWriteOff.Number AS DocumentNumber,
	|	InventoryWriteOff.Date AS DocumentDate,
	|	InventoryWriteOff.Company AS Company,
	|	Companies.LogoFile AS CompanyLogoFile,
	|	InventoryWriteOff.Comment AS Comment,
	|	InventoryWriteOff.FieldTo AS FieldTo,
	|	InventoryWriteOff.FieldFrom AS FieldFrom
	|INTO Header
	|FROM
	|	InventoryWriteOff AS InventoryWriteOff
	|		LEFT JOIN Catalog.Companies AS Companies
	|		ON InventoryWriteOff.Company = Companies.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	InventoryWriteOffInventory.Ref AS Ref,
	|	InventoryWriteOffInventory.LineNumber AS LineNumber,
	|	InventoryWriteOffInventory.Products AS Products,
	|	InventoryWriteOffInventory.Characteristic AS Characteristic,
	|	InventoryWriteOffInventory.Batch AS Batch,
	|	InventoryWriteOffInventory.Quantity AS Quantity,
	|	InventoryWriteOffInventory.MeasurementUnit AS MeasurementUnit,
	|	InventoryWriteOffInventory.ConnectionKey AS ConnectionKey
	|INTO FilteredInventory
	|FROM
	|	InventoryWriteOff AS InventoryWriteOff
	|		INNER JOIN Document.InventoryWriteOff.Inventory AS InventoryWriteOffInventory
	|		ON InventoryWriteOff.Ref = InventoryWriteOffInventory.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Header.Ref AS Ref,
	|	Header.DocumentNumber AS DocumentNumber,
	|	Header.DocumentDate AS DocumentDate,
	|	Header.Company AS Company,
	|	Header.CompanyLogoFile AS CompanyLogoFile,
	|	Header.Comment AS Comment,
	|	MIN(FilteredInventory.LineNumber) AS LineNumber,
	|	CatalogProducts.SKU AS SKU,
	|	CASE
	|		WHEN (CAST(CatalogProducts.DescriptionFull AS STRING(1024))) <> """"
	|			THEN CAST(CatalogProducts.DescriptionFull AS STRING(1024))
	|		ELSE CatalogProducts.Description
	|	END AS ProductDescription,
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
	|	FilteredInventory.Products AS Products,
	|	FilteredInventory.Characteristic AS Characteristic,
	|	FilteredInventory.MeasurementUnit AS MeasurementUnit,
	|	FilteredInventory.Batch AS Batch,
	|	Header.FieldTo AS FieldTo,
	|	Header.FieldFrom AS FieldFrom
	|INTO Tabular
	|FROM
	|	Header AS Header
	|		INNER JOIN FilteredInventory AS FilteredInventory
	|		ON Header.Ref = FilteredInventory.Ref
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
	|	Header.CompanyLogoFile,
	|	Header.Comment,
	|	CatalogProducts.SKU,
	|	CASE
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
	|	ISNULL(CatalogUOM.Description, CatalogUOMClassifier.Description),
	|	FilteredInventory.Products,
	|	CASE
	|		WHEN CatalogProducts.UseBatches
	|			THEN CatalogBatches.Description
	|		ELSE """"
	|	END,
	|	FilteredInventory.Characteristic,
	|	FilteredInventory.MeasurementUnit,
	|	FilteredInventory.Batch,
	|	Header.FieldTo,
	|	Header.FieldFrom
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Tabular.Ref AS Ref,
	|	Tabular.DocumentNumber AS DocumentNumber,
	|	Tabular.DocumentDate AS DocumentDate,
	|	Tabular.Company AS Company,
	|	Tabular.CompanyLogoFile AS CompanyLogoFile,
	|	Tabular.Comment AS Comment,
	|	Tabular.LineNumber AS LineNumber,
	|	Tabular.SKU AS SKU,
	|	Tabular.ProductDescription AS ProductDescription,
	|	Tabular.UseSerialNumbers AS UseSerialNumbers,
	|	Tabular.Quantity AS Quantity,
	|	Tabular.Products AS Products,
	|	Tabular.CharacteristicDescription AS CharacteristicDescription,
	|	Tabular.BatchDescription AS BatchDescription,
	|	Tabular.ConnectionKey AS ConnectionKey,
	|	Tabular.Characteristic AS Characteristic,
	|	Tabular.MeasurementUnit AS MeasurementUnit,
	|	Tabular.Batch AS Batch,
	|	Tabular.UOM AS UOM,
	|	FALSE AS ContentUsed,
	|	Tabular.FieldTo AS FieldTo,
	|	Tabular.FieldFrom AS FieldFrom
	|FROM
	|	Tabular AS Tabular
	|
	|ORDER BY
	|	Tabular.DocumentNumber,
	|	LineNumber
	|TOTALS
	|	MAX(DocumentNumber),
	|	MAX(DocumentDate),
	|	MAX(Company),
	|	MAX(CompanyLogoFile),
	|	MAX(Comment),
	|	COUNT(LineNumber),
	|	SUM(Quantity),
	|	MAX(FieldTo),
	|	MAX(FieldFrom)
	|BY
	|	Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Tabular.ConnectionKey AS ConnectionKey,
	|	Tabular.Ref AS Ref,
	|	SerialNumbers.Description AS SerialNumber
	|FROM
	|	Tabular AS Tabular
	|		INNER JOIN Document.InventoryWriteOff.SerialNumbers AS InventoryWriteOffSerialNumbers
	|		ON Tabular.Ref = InventoryWriteOffSerialNumbers.Ref
	|			AND Tabular.ConnectionKey = InventoryWriteOffSerialNumbers.ConnectionKey
	|		INNER JOIN Catalog.SerialNumbers AS SerialNumbers
	|		ON (InventoryWriteOffSerialNumbers.SerialNumber = SerialNumbers.Ref)";

EndFunction

Function GetGoodsReturnQuery()
	
	Return
	"SELECT
	|	GoodsReturn.Ref AS Ref,
	|	GoodsReturn.Number AS Number,
	|	GoodsReturn.Date AS Date,
	|	GoodsReturn.Company AS Company,
	|	GoodsReturn.Counterparty AS FieldTo,
	|	GoodsReturn.Contract AS Contract,
	|	CAST(GoodsReturn.Comment AS STRING(1024)) AS Comment,
	|	GoodsReturn.StructuralUnit AS FieldFrom
	|INTO GoodsReturn
	|FROM
	|	Document.GoodsReturn AS GoodsReturn
	|WHERE
	|	GoodsReturn.Ref IN(&ObjectsArray)
	|	AND GoodsReturn.OperationKind = VALUE(Enum.OperationTypesGoodsReturn.ToSupplier)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	GoodsReturn.Ref AS Ref,
	|	GoodsReturn.Number AS DocumentNumber,
	|	GoodsReturn.Date AS DocumentDate,
	|	GoodsReturn.Company AS Company,
	|	Companies.LogoFile AS CompanyLogoFile,
	|	GoodsReturn.Contract AS Contract,
	|	GoodsReturn.Comment AS Comment,
	|	GoodsReturn.FieldFrom AS FieldFrom,
	|	GoodsReturn.FieldTo AS FieldTo
	|INTO Header
	|FROM
	|	GoodsReturn AS GoodsReturn
	|		LEFT JOIN Catalog.Companies AS Companies
	|		ON GoodsReturn.Company = Companies.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	GoodsReturnInventory.Ref AS Ref,
	|	GoodsReturnInventory.LineNumber AS LineNumber,
	|	GoodsReturnInventory.Products AS Products,
	|	GoodsReturnInventory.Characteristic AS Characteristic,
	|	GoodsReturnInventory.Batch AS Batch,
	|	GoodsReturnInventory.Quantity AS Quantity,
	|	GoodsReturnInventory.MeasurementUnit AS MeasurementUnit,
	|	GoodsReturnInventory.Order AS Order,
	|	GoodsReturnInventory.ConnectionKey AS ConnectionKey
	|INTO FilteredInventory
	|FROM
	|	GoodsReturn AS GoodsReturn
	|		INNER JOIN Document.GoodsReturn.Inventory AS GoodsReturnInventory
	|		ON GoodsReturn.Ref = GoodsReturnInventory.Ref
	|WHERE
	|	GoodsReturnInventory.Quantity > 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Header.Ref AS Ref,
	|	Header.DocumentNumber AS DocumentNumber,
	|	Header.DocumentDate AS DocumentDate,
	|	Header.Company AS Company,
	|	Header.CompanyLogoFile AS CompanyLogoFile,
	|	Header.Contract AS Contract,
	|	Header.Comment AS Comment,
	|	MIN(FilteredInventory.LineNumber) AS LineNumber,
	|	CatalogProducts.SKU AS SKU,
	|	CASE
	|		WHEN (CAST(CatalogProducts.DescriptionFull AS STRING(1024))) <> """"
	|			THEN CAST(CatalogProducts.DescriptionFull AS STRING(1024))
	|		ELSE CatalogProducts.Description
	|	END AS ProductDescription,
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
	|	FilteredInventory.Products AS Products,
	|	FilteredInventory.Characteristic AS Characteristic,
	|	FilteredInventory.MeasurementUnit AS MeasurementUnit,
	|	FilteredInventory.Batch AS Batch,
	|	Header.FieldFrom AS FieldFrom,
	|	Header.FieldTo AS FieldTo
	|INTO Tabular
	|FROM
	|	Header AS Header
	|		INNER JOIN FilteredInventory AS FilteredInventory
	|		ON Header.Ref = FilteredInventory.Ref
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
	|	Header.CompanyLogoFile,
	|	Header.Contract,
	|	Header.Comment,
	|	CatalogProducts.SKU,
	|	CASE
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
	|	ISNULL(CatalogUOM.Description, CatalogUOMClassifier.Description),
	|	FilteredInventory.Products,
	|	CASE
	|		WHEN CatalogProducts.UseBatches
	|			THEN CatalogBatches.Description
	|		ELSE """"
	|	END,
	|	FilteredInventory.Characteristic,
	|	FilteredInventory.MeasurementUnit,
	|	FilteredInventory.Batch,
	|	Header.FieldFrom,
	|	Header.FieldTo
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Tabular.Ref AS Ref,
	|	Tabular.DocumentNumber AS DocumentNumber,
	|	Tabular.DocumentDate AS DocumentDate,
	|	Tabular.Company AS Company,
	|	Tabular.CompanyLogoFile AS CompanyLogoFile,
	|	Tabular.Contract AS Contract,
	|	Tabular.Comment AS Comment,
	|	Tabular.LineNumber AS LineNumber,
	|	Tabular.SKU AS SKU,
	|	Tabular.ProductDescription AS ProductDescription,
	|	Tabular.UseSerialNumbers AS UseSerialNumbers,
	|	Tabular.Quantity AS Quantity,
	|	Tabular.Products AS Products,
	|	Tabular.CharacteristicDescription AS CharacteristicDescription,
	|	Tabular.BatchDescription AS BatchDescription,
	|	Tabular.ConnectionKey AS ConnectionKey,
	|	Tabular.Characteristic AS Characteristic,
	|	Tabular.MeasurementUnit AS MeasurementUnit,
	|	Tabular.Batch AS Batch,
	|	Tabular.UOM AS UOM,
	|	FALSE AS ContentUsed,
	|	Tabular.FieldFrom AS FieldFrom,
	|	Tabular.FieldTo AS FieldTo
	|FROM
	|	Tabular AS Tabular
	|
	|ORDER BY
	|	Tabular.DocumentNumber,
	|	LineNumber
	|TOTALS
	|	MAX(DocumentNumber),
	|	MAX(DocumentDate),
	|	MAX(Company),
	|	MAX(CompanyLogoFile),
	|	MAX(Contract),
	|	MAX(Comment),
	|	COUNT(LineNumber),
	|	SUM(Quantity),
	|	MAX(FieldFrom),
	|	MAX(FieldTo)
	|BY
	|	Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Tabular.ConnectionKey AS ConnectionKey,
	|	Tabular.Ref AS Ref,
	|	SerialNumbers.Description AS SerialNumber
	|FROM
	|	Tabular AS Tabular
	|		INNER JOIN Document.GoodsReturn.SerialNumbers AS GoodsReturnSerialNumbers
	|		ON Tabular.Ref = GoodsReturnSerialNumbers.Ref
	|			AND Tabular.ConnectionKey = GoodsReturnSerialNumbers.ConnectionKey
	|		INNER JOIN Catalog.SerialNumbers AS SerialNumbers
	|		ON GoodsReturnSerialNumbers.SerialNumber = SerialNumbers.Ref";

EndFunction

Function PrintRequisition(ObjectsArray, PrintObjects, TemplateName)
	
	SpreadsheetDocument = New SpreadsheetDocument;
	SpreadsheetDocument.PrintParametersKey = "PrintParameters_Requisition";
	
	Query = New Query();
	Query.SetParameter("ObjectsArray", ObjectsArray);
	
	IsInventoryWriteOff = False;
	
	If TypeOf(ObjectsArray[0]) = Type("DocumentRef.GoodsIssue") Then
		Query.Text = GetGoodsIssueQuery();
	ElsIf TypeOf(ObjectsArray[0]) = Type("DocumentRef.SalesInvoice") Then
		Query.Text = GetSalesInvoiceQuery();
	ElsIf TypeOf(ObjectsArray[0]) = Type("DocumentRef.InventoryTransfer") Then
		Query.Text = GetInventoryTransferQuery();
	ElsIf TypeOf(ObjectsArray[0]) = Type("DocumentRef.DebitNote") Then
		Query.Text = GetDebitNoteQuery();
	ElsIf TypeOf(ObjectsArray[0]) = Type("DocumentRef.SubcontractorReportIssued") Then
		Query.Text = GetSubcontractorReportIssuedQuery();
	ElsIf TypeOf(ObjectsArray[0]) = Type("DocumentRef.InventoryWriteOff") Then
		Query.Text = GetInventoryWriteOffQuery();
		IsInventoryWriteOff = True;
	ElsIf TypeOf(ObjectsArray[0]) = Type("DocumentRef.SalesOrder") Then
		Query.Text = GetWorkOrderQuery();
	ElsIf TypeOf(ObjectsArray[0]) = Type("DocumentRef.GoodsReturn") Then
		Query.Text = GetGoodsReturnQuery();
	EndIf;
	
	ResultArray = Query.ExecuteBatch();
	
	FirstDocument = True;
	
	Header = ResultArray[4].Select(QueryResultIteration.ByGroupsWithHierarchy);
	
	SerialNumbersSel = ResultArray[5].Select();
	
	While Header.Next() Do
		
		If Not FirstDocument Then
			SpreadsheetDocument.PutHorizontalPageBreak();
		EndIf;
		
		FirstDocument = False;
		
		FirstLineNumber = SpreadsheetDocument.TableHeight + 1;
		
		SpreadsheetDocument.PrintParametersName = "PRINT_PARAMETERS_Requisition";
		
		Template = PrintManagement.PrintedFormsTemplate("DataProcessor.PrintRequisition.PF_MXL_Requisition");
		
		#Region PrintDeliveryNoteTitleArea
		
		TitleArea = Template.GetArea("Title");
		TitleArea.Parameters.Fill(Header);
		TitleArea.Parameters.DocumentType = Header.Ref.Metadata().Synonym;
		
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
		
		#Region PrintDeliveryNoteCompanyInfoArea
		
		CompanyInfoArea = Template.GetArea("CompanyInfo");
		
		InfoAboutCompany = DriveServer.InfoAboutLegalEntityIndividual(Header.Company, Header.DocumentDate);
		CompanyInfoArea.Parameters.Fill(InfoAboutCompany);
		
		SpreadsheetDocument.Put(CompanyInfoArea);
		
		#EndRegion
		
		#Region PrintDeliveryNoteFromToInfoArea
		
		FromToInfoArea = Template.GetArea("FromTo");
		FromToInfoArea.Parameters.FullDescrFrom = GetFullDecription(Header.FieldFrom, Header.DocumentDate);
		If IsInventoryWriteOff Then
			FromToInfoArea.Parameters.FullDescrTo = Header.FieldTo;
		Else
			FromToInfoArea.Parameters.FullDescrTo = GetFullDecription(Header.FieldTo, Header.DocumentDate);
		EndIf;
		SpreadsheetDocument.Put(FromToInfoArea);
		
		#EndRegion
		
		#Region PrintDeliveryNoteCommentArea
		
		CommentArea = Template.GetArea("Comment");
		CommentArea.Parameters.Fill(Header);
		SpreadsheetDocument.Put(CommentArea);
		
		#EndRegion
		
		#Region PrintDeliveryNoteLinesArea
		
		LineHeaderArea = Template.GetArea("LineHeader");
		SpreadsheetDocument.Put(LineHeaderArea);
		
		LineSectionArea	= Template.GetArea("LineSection");
		SeeNextPageArea	= Template.GetArea("SeeNextPage");
		EmptyLineArea	= Template.GetArea("EmptyLine");
		PageNumberArea	= Template.GetArea("PageNumber");
		
		PageNumber = 0;
		
		TabSelection = Header.Select();
		While TabSelection.Next() Do
			
			LineSectionArea.Parameters.Fill(TabSelection);
			
			PrintManagement.ComplimentProductDescription(LineSectionArea.Parameters.ProductDescription, TabSelection, SerialNumbersSel);
			
			AreasToBeChecked = New Array;
			AreasToBeChecked.Add(LineSectionArea);
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
		
		#EndRegion
		
		#Region PrintDeliveryNoteTotalsArea
		
		LineTotalArea = Template.GetArea("LineTotal");
		LineTotalArea.Parameters.Fill(Header);
		SpreadsheetDocument.Put(LineTotalArea);
		
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
	
	SpreadsheetDocument.FitToPage = True;
	
	Return SpreadsheetDocument;
	
EndFunction

Function GetFullDecription(Field, DocumentDate)
	Return DriveServer.InfoAboutLegalEntityIndividual(Field, DocumentDate).FullDescr;
EndFunction

#EndRegion

#EndIf