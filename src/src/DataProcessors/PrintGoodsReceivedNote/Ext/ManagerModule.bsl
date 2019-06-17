#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region PrintInterface

Function PrintForm(ObjectsArray, PrintObjects, TemplateName) Export
	
	If TemplateName = "GoodsReceivedNote" Then
		
		Return PrintGoodsReceivedNote(ObjectsArray, PrintObjects, TemplateName);
		
	EndIf;
	
EndFunction

Function GetSupplierInvoiceQuery()
	
	Return
	"SELECT
	|	SupplierInvoice.Ref AS Ref,
	|	SupplierInvoice.Number AS Number,
	|	SupplierInvoice.Date AS Date,
	|	SupplierInvoice.Company AS Company,
	|	SupplierInvoice.Counterparty AS FieldFrom,
	|	SupplierInvoice.Contract AS Contract,
	|	CAST(SupplierInvoice.Comment AS STRING(1024)) AS Comment,
	|	SupplierInvoice.Order AS Order,
	|	SupplierInvoice.PurchaseOrderPosition AS PurchaseOrderPosition,
	|	SupplierInvoice.StructuralUnit AS FieldTo
	|INTO SupplierInvoice
	|FROM
	|	Document.SupplierInvoice AS SupplierInvoice
	|WHERE
	|	SupplierInvoice.Ref IN(&ObjectsArray)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SupplierInvoice.Ref AS Ref,
	|	SupplierInvoice.Number AS DocumentNumber,
	|	SupplierInvoice.Date AS DocumentDate,
	|	SupplierInvoice.Company AS Company,
	|	Companies.LogoFile AS CompanyLogoFile,
	|	SupplierInvoice.Contract AS Contract,
	|	SupplierInvoice.Comment AS Comment,
	|	SupplierInvoice.FieldFrom AS FieldFrom,
	|	SupplierInvoice.FieldTo AS FieldTo
	|INTO Header
	|FROM
	|	SupplierInvoice AS SupplierInvoice
	|		LEFT JOIN Catalog.Companies AS Companies
	|		ON SupplierInvoice.Company = Companies.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SupplierInvoiceInventory.Ref AS Ref,
	|	SupplierInvoiceInventory.LineNumber AS LineNumber,
	|	SupplierInvoiceInventory.Products AS Products,
	|	SupplierInvoiceInventory.Characteristic AS Characteristic,
	|	SupplierInvoiceInventory.Batch AS Batch,
	|	SupplierInvoiceInventory.Quantity AS Quantity,
	|	SupplierInvoiceInventory.MeasurementUnit AS MeasurementUnit,
	|	SupplierInvoiceInventory.Order AS Order,
	|	SupplierInvoiceInventory.ConnectionKey AS ConnectionKey
	|INTO FilteredInventory
	|FROM
	|	Header AS Header
	|		INNER JOIN Document.SupplierInvoice.Inventory AS SupplierInvoiceInventory
	|		ON Header.Ref = SupplierInvoiceInventory.Ref
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
	|		INNER JOIN Document.SupplierInvoice.SerialNumbers AS SupplierInvoiceSerialNumbers
	|		ON Tabular.Ref = SupplierInvoiceSerialNumbers.Ref
	|			AND Tabular.ConnectionKey = SupplierInvoiceSerialNumbers.ConnectionKey
	|		INNER JOIN Catalog.SerialNumbers AS SerialNumbers
	|		ON (SupplierInvoiceSerialNumbers.SerialNumber = SerialNumbers.Ref)";

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

Function GetCreditNoteQuery()
	
	Return
	"SELECT
	|	CreditNote.Ref AS Ref,
	|	CreditNote.Number AS Number,
	|	CreditNote.Date AS Date,
	|	CreditNote.Company AS Company,
	|	CAST(CreditNote.Comment AS STRING(1024)) AS Comment,
	|	CreditNote.StructuralUnit AS FieldTo,
	|	CreditNote.Counterparty AS FieldFrom
	|INTO CreditNote
	|FROM
	|	Document.CreditNote AS CreditNote
	|WHERE
	|	CreditNote.Ref IN(&ObjectsArray)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CreditNote.Ref AS Ref,
	|	CreditNote.Number AS DocumentNumber,
	|	CreditNote.Date AS DocumentDate,
	|	CreditNote.Company AS Company,
	|	Companies.LogoFile AS CompanyLogoFile,
	|	CreditNote.Comment AS Comment,
	|	CreditNote.FieldFrom AS FieldFrom,
	|	CreditNote.FieldTo AS FieldTo
	|INTO Header
	|FROM
	|	CreditNote AS CreditNote
	|		LEFT JOIN Catalog.Companies AS Companies
	|		ON CreditNote.Company = Companies.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CreditNoteInventory.Ref AS Ref,
	|	CreditNoteInventory.LineNumber AS LineNumber,
	|	CreditNoteInventory.Products AS Products,
	|	CreditNoteInventory.Characteristic AS Characteristic,
	|	CreditNoteInventory.Batch AS Batch,
	|	CreditNoteInventory.Quantity AS Quantity,
	|	CreditNoteInventory.MeasurementUnit AS MeasurementUnit,
	|	CreditNoteInventory.ConnectionKey AS ConnectionKey
	|INTO FilteredInventory
	|FROM
	|	CreditNote AS CreditNote
	|		INNER JOIN Document.CreditNote.Inventory AS CreditNoteInventory
	|		ON CreditNote.Ref = CreditNoteInventory.Ref
	|WHERE
	|	CreditNoteInventory.Quantity > 0
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
	|WHERE
	|	CatalogProducts.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
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
	|		INNER JOIN Document.CreditNote.SerialNumbers AS CreditNoteSerialNumbers
	|		ON Tabular.Ref = CreditNoteSerialNumbers.Ref
	|			AND Tabular.ConnectionKey = CreditNoteSerialNumbers.ConnectionKey
	|		INNER JOIN Catalog.SerialNumbers AS SerialNumbers
	|		ON (CreditNoteSerialNumbers.SerialNumber = SerialNumbers.Ref)";

EndFunction

Function GetSubcontractorReportQuery()
	
	Return
	"SELECT
	|	SubcontractorReport.Ref AS Ref,
	|	SubcontractorReport.Number AS Number,
	|	SubcontractorReport.Date AS Date,
	|	SubcontractorReport.Company AS Company,
	|	CAST(SubcontractorReport.Comment AS STRING(1024)) AS Comment,
	|	SubcontractorReport.StructuralUnit AS FieldTo,
	|	SubcontractorReport.Counterparty AS FieldFrom,
	|	SubcontractorReport.Products AS Products,
	|	SubcontractorReport.Characteristic AS Characteristic,
	|	1 AS LineNumber,
	|	SubcontractorReport.MeasurementUnit AS MeasurementUnit,
	|	SubcontractorReport.Quantity AS Quantity,
	|	SubcontractorReport.Batch AS Batch
	|INTO SubcontractorReport
	|FROM
	|	Document.SubcontractorReport AS SubcontractorReport
	|WHERE
	|	SubcontractorReport.Ref IN(&ObjectsArray)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SubcontractorReport.Ref AS Ref,
	|	SubcontractorReport.Number AS DocumentNumber,
	|	SubcontractorReport.Date AS DocumentDate,
	|	SubcontractorReport.Company AS Company,
	|	Companies.LogoFile AS CompanyLogoFile,
	|	SubcontractorReport.Comment AS Comment,
	|	SubcontractorReport.FieldFrom AS FieldFrom,
	|	SubcontractorReport.FieldTo AS FieldTo
	|INTO Header
	|FROM
	|	SubcontractorReport AS SubcontractorReport
	|		LEFT JOIN Catalog.Companies AS Companies
	|		ON SubcontractorReport.Company = Companies.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SubcontractorReportProducts.Ref AS Ref,
	|	SubcontractorReportProducts.LineNumber AS LineNumber,
	|	SubcontractorReportProducts.Products AS Products,
	|	SubcontractorReportProducts.Characteristic AS Characteristic,
	|	SubcontractorReportProducts.Batch AS Batch,
	|	SubcontractorReportProducts.Quantity AS Quantity,
	|	SubcontractorReportProducts.MeasurementUnit AS MeasurementUnit
	|INTO FilteredInventory
	|FROM
	|	SubcontractorReport AS SubcontractorReport
	|		INNER JOIN Document.SubcontractorReport.Disposals AS SubcontractorReportProducts
	|		ON SubcontractorReport.Ref = SubcontractorReportProducts.Ref
	|
	|UNION ALL
	|
	|SELECT
	|	SubcontractorReport.Ref,
	|	SubcontractorReport.LineNumber,
	|	SubcontractorReport.Products,
	|	SubcontractorReport.Characteristic,
	|	SubcontractorReport.Batch,
	|	SubcontractorReport.Quantity,
	|	SubcontractorReport.MeasurementUnit
	|FROM
	|	SubcontractorReport AS SubcontractorReport
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
	|	Ref";

EndFunction

Function GetGoodsReceiptQuery()
	
	Return
	"SELECT
	|	GoodsReceipt.Ref AS Ref,
	|	GoodsReceipt.Number AS Number,
	|	GoodsReceipt.Date AS Date,
	|	GoodsReceipt.Company AS Company,
	|	CAST(GoodsReceipt.Comment AS STRING(1024)) AS Comment,
	|	GoodsReceipt.StructuralUnit AS FieldTo,
	|	GoodsReceipt.Counterparty AS FieldFrom
	|INTO GoodsReceipt
	|FROM
	|	Document.GoodsReceipt AS GoodsReceipt
	|WHERE
	|	GoodsReceipt.Ref IN(&ObjectsArray)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	GoodsReceipt.Ref AS Ref,
	|	GoodsReceipt.Number AS DocumentNumber,
	|	GoodsReceipt.Date AS DocumentDate,
	|	GoodsReceipt.Company AS Company,
	|	Companies.LogoFile AS CompanyLogoFile,
	|	GoodsReceipt.Comment AS Comment,
	|	GoodsReceipt.FieldFrom AS FieldFrom,
	|	GoodsReceipt.FieldTo AS FieldTo
	|INTO Header
	|FROM
	|	GoodsReceipt AS GoodsReceipt
	|		LEFT JOIN Catalog.Companies AS Companies
	|		ON GoodsReceipt.Company = Companies.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	GoodsReceiptProducts.Ref AS Ref,
	|	GoodsReceiptProducts.LineNumber AS LineNumber,
	|	GoodsReceiptProducts.Products AS Products,
	|	GoodsReceiptProducts.Characteristic AS Characteristic,
	|	GoodsReceiptProducts.Batch AS Batch,
	|	GoodsReceiptProducts.Quantity AS Quantity,
	|	GoodsReceiptProducts.MeasurementUnit AS MeasurementUnit,
	|	GoodsReceiptProducts.ConnectionKey AS ConnectionKey
	|INTO FilteredInventory
	|FROM
	|	GoodsReceipt AS GoodsReceipt
	|		INNER JOIN Document.GoodsReceipt.Products AS GoodsReceiptProducts
	|		ON GoodsReceipt.Ref = GoodsReceiptProducts.Ref
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
	|		INNER JOIN Document.GoodsReceipt.SerialNumbers AS GoodsReceiptSerialNumbers
	|		ON Tabular.Ref = GoodsReceiptSerialNumbers.Ref
	|			AND Tabular.ConnectionKey = GoodsReceiptSerialNumbers.ConnectionKey
	|		INNER JOIN Catalog.SerialNumbers AS SerialNumbers
	|		ON (GoodsReceiptSerialNumbers.SerialNumber = SerialNumbers.Ref)";

EndFunction

Function GetExpenseReportQuery()
	
	Return
	"SELECT
	|	ExpenseReport.Ref AS Ref,
	|	ExpenseReport.Number AS Number,
	|	ExpenseReport.Date AS Date,
	|	ExpenseReport.Company AS Company,
	|	CAST(ExpenseReport.Comment AS STRING(1024)) AS Comment,
	|	ExpenseReport.Employee AS Employee
	|INTO ExpenseReport
	|FROM
	|	Document.ExpenseReport AS ExpenseReport
	|WHERE
	|	ExpenseReport.Ref IN(&ObjectsArray)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ExpenseReport.Ref AS Ref,
	|	ExpenseReport.Number AS DocumentNumber,
	|	ExpenseReport.Date AS DocumentDate,
	|	ExpenseReport.Company AS Company,
	|	Companies.LogoFile AS CompanyLogoFile,
	|	ExpenseReport.Comment AS Comment,
	|	Employees.Ind AS FieldFrom
	|INTO Header
	|FROM
	|	ExpenseReport AS ExpenseReport
	|		LEFT JOIN Catalog.Companies AS Companies
	|		ON ExpenseReport.Company = Companies.Ref
	|		LEFT JOIN Catalog.Employees AS Employees
	|		ON ExpenseReport.Employee = Employees.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ExpenseReportMaterials.Ref AS Ref,
	|	ExpenseReportMaterials.LineNumber AS LineNumber,
	|	ExpenseReportMaterials.Products AS Products,
	|	ExpenseReportMaterials.Characteristic AS Characteristic,
	|	ExpenseReportMaterials.Batch AS Batch,
	|	ExpenseReportMaterials.Quantity AS Quantity,
	|	ExpenseReportMaterials.MeasurementUnit AS MeasurementUnit,
	|	ExpenseReportMaterials.StructuralUnit AS StructuralUnit
	|INTO FilteredInventory
	|FROM
	|	ExpenseReport AS ExpenseReport
	|		INNER JOIN Document.ExpenseReport.Inventory AS ExpenseReportMaterials
	|		ON ExpenseReport.Ref = ExpenseReportMaterials.Ref
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
	|	ISNULL(CatalogUOM.Description, CatalogUOMClassifier.Description) AS UOM,
	|	SUM(FilteredInventory.Quantity) AS Quantity,
	|	FilteredInventory.Products AS Products,
	|	FilteredInventory.Characteristic AS Characteristic,
	|	FilteredInventory.MeasurementUnit AS MeasurementUnit,
	|	FilteredInventory.Batch AS Batch,
	|	Header.FieldFrom AS FieldFrom,
	|	FilteredInventory.StructuralUnit AS FieldTo
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
	|	FilteredInventory.StructuralUnit
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
	|	MAX(FieldFrom)
	|BY
	|	Ref,
	|	FieldTo";

EndFunction

Function GetInventoryIncreaseQuery()
	
	Return
	"SELECT
	|	InventoryIncrease.Ref AS Ref,
	|	InventoryIncrease.Number AS Number,
	|	InventoryIncrease.Date AS Date,
	|	InventoryIncrease.Company AS Company,
	|	CAST(InventoryIncrease.Comment AS STRING(1024)) AS Comment,
	|	InventoryIncrease.Correspondence AS FieldFrom,
	|	InventoryIncrease.StructuralUnit AS FieldTo
	|INTO InventoryIncrease
	|FROM
	|	Document.InventoryIncrease AS InventoryIncrease
	|WHERE
	|	InventoryIncrease.Ref IN(&ObjectsArray)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	InventoryIncrease.Ref AS Ref,
	|	InventoryIncrease.Number AS DocumentNumber,
	|	InventoryIncrease.Date AS DocumentDate,
	|	InventoryIncrease.Company AS Company,
	|	Companies.LogoFile AS CompanyLogoFile,
	|	InventoryIncrease.Comment AS Comment,
	|	InventoryIncrease.FieldTo AS FieldTo,
	|	InventoryIncrease.FieldFrom AS FieldFrom
	|INTO Header
	|FROM
	|	InventoryIncrease AS InventoryIncrease
	|		LEFT JOIN Catalog.Companies AS Companies
	|		ON InventoryIncrease.Company = Companies.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	InventoryIncreaseInventory.Ref AS Ref,
	|	InventoryIncreaseInventory.LineNumber AS LineNumber,
	|	InventoryIncreaseInventory.Products AS Products,
	|	InventoryIncreaseInventory.Characteristic AS Characteristic,
	|	InventoryIncreaseInventory.Batch AS Batch,
	|	InventoryIncreaseInventory.Quantity AS Quantity,
	|	InventoryIncreaseInventory.MeasurementUnit AS MeasurementUnit,
	|	InventoryIncreaseInventory.ConnectionKey AS ConnectionKey
	|INTO FilteredInventory
	|FROM
	|	InventoryIncrease AS InventoryIncrease
	|		INNER JOIN Document.InventoryIncrease.Inventory AS InventoryIncreaseInventory
	|		ON InventoryIncrease.Ref = InventoryIncreaseInventory.Ref
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
	|		INNER JOIN Document.InventoryIncrease.SerialNumbers AS InventoryIncreaseSerialNumbers
	|		ON Tabular.Ref = InventoryIncreaseSerialNumbers.Ref
	|			AND Tabular.ConnectionKey = InventoryIncreaseSerialNumbers.ConnectionKey
	|		INNER JOIN Catalog.SerialNumbers AS SerialNumbers
	|		ON (InventoryIncreaseSerialNumbers.SerialNumber = SerialNumbers.Ref)";

EndFunction

Function GetProductionQuery()
	
	Return
	"SELECT
	|	Production.Ref AS Ref,
	|	Production.Number AS Number,
	|	Production.Date AS Date,
	|	Production.Company AS Company,
	|	Production.ProductsStructuralUnit AS ProductsStructuralUnit,
	|	Production.DisposalsStructuralUnit AS DisposalsStructuralUnit,
	|	CAST(Production.Comment AS STRING(1024)) AS Comment,
	|	Production.StructuralUnit AS FieldFrom
	|INTO Production
	|FROM
	|	Document.Production AS Production
	|WHERE
	|	Production.Ref IN(&ObjectsArray)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Production.Ref AS Ref,
	|	Production.Number AS DocumentNumber,
	|	Production.Date AS DocumentDate,
	|	Production.Company AS Company,
	|	Companies.LogoFile AS CompanyLogoFile,
	|	Production.Comment AS Comment,
	|	Production.FieldFrom AS FieldFrom
	|INTO Header
	|FROM
	|	Production AS Production
	|		LEFT JOIN Catalog.Companies AS Companies
	|		ON Production.Company = Companies.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ProductionInventory.Ref AS Ref,
	|	ProductionInventory.LineNumber AS LineNumber,
	|	ProductionInventory.Products AS Products,
	|	ProductionInventory.Characteristic AS Characteristic,
	|	ProductionInventory.Batch AS Batch,
	|	ProductionInventory.Quantity AS Quantity,
	|	ProductionInventory.MeasurementUnit AS MeasurementUnit,
	|	ProductionInventory.ConnectionKey AS ConnectionKey,
	|	Production.ProductsStructuralUnit AS FieldTo
	|INTO FilteredInventory
	|FROM
	|	Production AS Production
	|		INNER JOIN Document.Production.Products AS ProductionInventory
	|		ON Production.Ref = ProductionInventory.Ref
	|WHERE
	|	ProductionInventory.Quantity > 0
	|
	|UNION ALL
	|
	|SELECT
	|	ProductionInventory.Ref,
	|	ProductionInventory.LineNumber,
	|	ProductionInventory.Products,
	|	ProductionInventory.Characteristic,
	|	ProductionInventory.Batch,
	|	ProductionInventory.Quantity,
	|	ProductionInventory.MeasurementUnit,
	|	UNDEFINED,
	|	Production.DisposalsStructuralUnit
	|FROM
	|	Production AS Production
	|		INNER JOIN Document.Production.Disposals AS ProductionInventory
	|		ON Production.Ref = ProductionInventory.Ref
	|WHERE
	|	ProductionInventory.Quantity > 0
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
	|	FilteredInventory.FieldTo AS FieldTo
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
	|	FilteredInventory.FieldTo
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
	|	MAX(FieldFrom)
	|BY
	|	Ref,
	|	FieldTo
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Tabular.ConnectionKey AS ConnectionKey,
	|	Tabular.Ref AS Ref,
	|	SerialNumbers.Description AS SerialNumber
	|FROM
	|	Tabular AS Tabular
	|		INNER JOIN Document.Production.SerialNumbersProducts AS ProductionSerialNumbers
	|		ON Tabular.Ref = ProductionSerialNumbers.Ref
	|			AND Tabular.ConnectionKey = ProductionSerialNumbers.ConnectionKey
	|		INNER JOIN Catalog.SerialNumbers AS SerialNumbers
	|		ON (ProductionSerialNumbers.SerialNumber = SerialNumbers.Ref)";

EndFunction

Function PrintGoodsReceivedNote(ObjectsArray, PrintObjects, TemplateName)
	
	SpreadsheetDocument = New SpreadsheetDocument;
	SpreadsheetDocument.PrintParametersKey = "PrintParameters_GoodsReceivedNote";
	
	Query = New Query();
	Query.SetParameter("ObjectsArray", ObjectsArray);
	
	IsInventoryIncrease = False;
	SeveralWarehouses = False;
	DoNotUseSerialNumbers = False;
	
	If TypeOf(ObjectsArray[0]) = Type("DocumentRef.GoodsReceipt") Then
		Query.Text = GetGoodsReceiptQuery();
	ElsIf TypeOf(ObjectsArray[0]) = Type("DocumentRef.SupplierInvoice") Then
		Query.Text = GetSupplierInvoiceQuery();
	ElsIf TypeOf(ObjectsArray[0]) = Type("DocumentRef.InventoryTransfer") Then
		Query.Text = GetInventoryTransferQuery();
	ElsIf TypeOf(ObjectsArray[0]) = Type("DocumentRef.CreditNote") Then
		Query.Text = GetCreditNoteQuery();
	ElsIf TypeOf(ObjectsArray[0]) = Type("DocumentRef.SubcontractorReport") Then
		Query.Text = GetSubcontractorReportQuery();
		DoNotUseSerialNumbers = True;
	ElsIf TypeOf(ObjectsArray[0]) = Type("DocumentRef.InventoryIncrease") Then
		Query.Text = GetInventoryIncreaseQuery();
		IsInventoryIncrease = True;
	ElsIf TypeOf(ObjectsArray[0]) = Type("DocumentRef.ExpenseReport") Then
		Query.Text = GetExpenseReportQuery();
		SeveralWarehouses = True;
		DoNotUseSerialNumbers = True;
	ElsIf TypeOf(ObjectsArray[0]) = Type("DocumentRef.Production") Then
		Query.Text = GetProductionQuery();
		SeveralWarehouses = True;
	EndIf;
	
	ResultArray = Query.ExecuteBatch();
	
	FirstDocument = True;
	
	If DoNotUseSerialNumbers Then
		SerialNumbersSel = Undefined;
	Else
		SerialNumbersSel = ResultArray[5].Select();
	EndIf;
	
	If SeveralWarehouses Then
		
		DocumentsSelection = ResultArray[4].Select(QueryResultIteration.ByGroupsWithHierarchy);
		
		While DocumentsSelection.Next() Do
			Header = DocumentsSelection.Select(QueryResultIteration.ByGroupsWithHierarchy);
			OutputSpreadsheetDocument(PrintObjects, SpreadsheetDocument, Header, SerialNumbersSel, FirstDocument, IsInventoryIncrease);
		EndDo;
		
	Else
		Header = ResultArray[4].Select(QueryResultIteration.ByGroupsWithHierarchy);
		OutputSpreadsheetDocument(PrintObjects, SpreadsheetDocument, Header, SerialNumbersSel, FirstDocument, IsInventoryIncrease);
	EndIf;
	
	SpreadsheetDocument.FitToPage = True;
	
	Return SpreadsheetDocument;
	
EndFunction

Procedure OutputSpreadsheetDocument(PrintObjects, SpreadsheetDocument, Header, SerialNumbersSel, FirstDocument, IsInventoryIncrease)

	While Header.Next() Do
		
		If Not FirstDocument Then
			SpreadsheetDocument.PutHorizontalPageBreak();
		EndIf;
		
		FirstDocument = False;
		
		FirstLineNumber = SpreadsheetDocument.TableHeight + 1;
		
		SpreadsheetDocument.PrintParametersName = "PRINT_PARAMETERS_GoodsReceivedNote";
		
		Template = PrintManagement.PrintedFormsTemplate("DataProcessor.PrintGoodsReceivedNote.PF_MXL_GoodsReceivedNote");
		
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
		FromToInfoArea.Parameters.FullDescrTo = GetFullDecription(Header.FieldTo, Header.DocumentDate);
		If IsInventoryIncrease Then
			FromToInfoArea.Parameters.FullDescrFrom = Header.FieldFrom;
		Else
			FromToInfoArea.Parameters.FullDescrFrom = GetFullDecription(Header.FieldFrom, Header.DocumentDate);
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

EndProcedure

Function GetFullDecription(Field, DocumentDate)
	Return DriveServer.InfoAboutLegalEntityIndividual(Field, DocumentDate).FullDescr;
EndFunction

#EndRegion

#EndIf