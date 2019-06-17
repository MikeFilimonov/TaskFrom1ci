#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Print

Function PrintForm(ObjectsArray, PrintObjects, TemplateName) Export
	
	If TemplateName = "DeliveryNote" Then
		
		Return PrintDeliveryNote(ObjectsArray, PrintObjects, TemplateName);
		
	EndIf;
	
EndFunction

Function GetGoodsIssueQuery()
	
	Return
	"SELECT
	|	GoodsIssue.Ref AS Ref,
	|	GoodsIssue.Number AS Number,
	|	GoodsIssue.Date AS Date,
	|	GoodsIssue.Company AS Company,
	|	GoodsIssue.Counterparty AS Counterparty,
	|	GoodsIssue.Contract AS Contract,
	|	CAST(GoodsIssue.Comment AS STRING(1024)) AS Comment,
	|	GoodsIssue.Order AS Order,
	|	GoodsIssue.SalesOrderPosition AS SalesOrderPosition,
	|	GoodsIssue.ContactPerson AS ContactPerson,
	|	GoodsIssue.ShippingAddress AS ShippingAddress,
	|	GoodsIssue.DeliveryOption AS DeliveryOption,
	|	GoodsIssue.StructuralUnit AS StructuralUnit
	|INTO GoodsIssues
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
	|	GoodsIssue.Counterparty AS Counterparty,
	|	GoodsIssue.Contract AS Contract,
	|	CASE
	|		WHEN GoodsIssue.ContactPerson <> VALUE(Catalog.ContactPersons.EmptyRef)
	|			THEN GoodsIssue.ContactPerson
	|		WHEN CounterpartyContracts.ContactPerson <> VALUE(Catalog.ContactPersons.EmptyRef)
	|			THEN CounterpartyContracts.ContactPerson
	|		ELSE Counterparties.ContactPerson
	|	END AS CounterpartyContactPerson,
	|	SalesOrder.Ref AS SalesOrder,
	|	ISNULL(SalesOrder.Number, """") AS SalesOrderNumber,
	|	ISNULL(SalesOrder.Date, DATETIME(1, 1, 1)) AS SalesOrderDate,
	|	GoodsIssue.Comment AS Comment,
	|	GoodsIssue.ShippingAddress AS ShippingAddress,
	|	GoodsIssue.DeliveryOption AS DeliveryOption,
	|	GoodsIssue.StructuralUnit AS StructuralUnit
	|INTO Header
	|FROM
	|	GoodsIssues AS GoodsIssue
	|		LEFT JOIN Catalog.Companies AS Companies
	|		ON GoodsIssue.Company = Companies.Ref
	|		LEFT JOIN Catalog.Counterparties AS Counterparties
	|		ON GoodsIssue.Counterparty = Counterparties.Ref
	|		LEFT JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
	|		ON GoodsIssue.Contract = CounterpartyContracts.Ref
	|			AND (GoodsIssue.SalesOrderPosition = VALUE(Enum.AttributeStationing.InHeader))
	|		LEFT JOIN Document.SalesOrder AS SalesOrder
	|		ON GoodsIssue.Order = SalesOrder.Ref
	|			AND (GoodsIssue.SalesOrderPosition = VALUE(Enum.AttributeStationing.InHeader))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	GoodsIssueInventory.Ref AS Ref,
	|	GoodsIssueInventory.LineNumber AS LineNumber,
	|	GoodsIssueInventory.Products AS Products,
	|	GoodsIssueInventory.Characteristic AS Characteristic,
	|	GoodsIssueInventory.Batch AS Batch,
	|	GoodsIssueInventory.Quantity AS Quantity,
	|	GoodsIssueInventory.MeasurementUnit AS MeasurementUnit,
	|	GoodsIssueInventory.Order AS Order,
	|	GoodsIssueInventory.ConnectionKey AS ConnectionKey,
	|	GoodsIssueInventory.Contract AS Contract
	|INTO FilteredInventory
	|FROM
	|	Document.GoodsIssue.Products AS GoodsIssueInventory
	|WHERE
	|	GoodsIssueInventory.Ref IN(&ObjectsArray)
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
	|	ISNULL(CounterpartyContracts.Ref, Header.Contract) AS Contract,
	|	Header.CounterpartyContactPerson AS CounterpartyContactPerson,
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
	|	ISNULL(SalesOrders.Ref, Header.SalesOrder) AS SalesOrder,
	|	ISNULL(SalesOrders.Number, Header.SalesOrderNumber) AS SalesOrderNumber,
	|	ISNULL(SalesOrders.Date, Header.SalesOrderDate) AS SalesOrderDate,
	|	FilteredInventory.Products AS Products,
	|	FilteredInventory.Characteristic AS Characteristic,
	|	FilteredInventory.MeasurementUnit AS MeasurementUnit,
	|	FilteredInventory.Batch AS Batch,
	|	Header.ShippingAddress AS ShippingAddress,
	|	Header.DeliveryOption AS DeliveryOption,
	|	Header.StructuralUnit AS StructuralUnit
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
	|		LEFT JOIN Document.SalesOrder AS SalesOrders
	|		ON (FilteredInventory.Order = SalesOrders.Ref)
	|			AND (Header.SalesOrderNumber = """")
	|		LEFT JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
	|		ON (FilteredInventory.Contract = CounterpartyContracts.Ref)
	|
	|GROUP BY
	|	Header.DocumentNumber,
	|	Header.DocumentDate,
	|	Header.Company,
	|	Header.Ref,
	|	Header.Counterparty,
	|	Header.CompanyLogoFile,
	|	ISNULL(SalesOrders.Ref, Header.SalesOrder),
	|	ISNULL(CounterpartyContracts.Ref, Header.Contract),
	|	Header.CounterpartyContactPerson,
	|	Header.Comment,
	|	CatalogProducts.SKU,
	|	CASE
	|		WHEN (CAST(CatalogProducts.DescriptionFull AS STRING(1024))) <> """"
	|			THEN CAST(CatalogProducts.DescriptionFull AS STRING(1024))
	|		ELSE CatalogProducts.Description
	|	END,
	|	ISNULL(SalesOrders.Date, Header.SalesOrderDate),
	|	CASE
	|		WHEN CatalogProducts.UseCharacteristics
	|			THEN CatalogCharacteristics.Description
	|		ELSE """"
	|	END,
	|	ISNULL(SalesOrders.Number, Header.SalesOrderNumber),
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
	|	Header.ShippingAddress,
	|	Header.DeliveryOption,
	|	Header.StructuralUnit
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
	|	Tabular.CounterpartyContactPerson AS CounterpartyContactPerson,
	|	Tabular.Comment AS Comment,
	|	Tabular.LineNumber AS LineNumber,
	|	Tabular.SKU AS SKU,
	|	Tabular.ProductDescription AS ProductDescription,
	|	Tabular.UseSerialNumbers AS UseSerialNumbers,
	|	Tabular.Quantity AS Quantity,
	|	SalesOrdersTurnovers.QuantityReceipt AS QuantityOrdered,
	|	Tabular.Products AS Products,
	|	Tabular.CharacteristicDescription AS CharacteristicDescription,
	|	Tabular.BatchDescription AS BatchDescription,
	|	Tabular.ConnectionKey AS ConnectionKey,
	|	Tabular.Characteristic AS Characteristic,
	|	Tabular.MeasurementUnit AS MeasurementUnit,
	|	Tabular.Batch AS Batch,
	|	Tabular.UOM AS UOM,
	|	FALSE AS ContentUsed,
	|	Tabular.ShippingAddress AS ShippingAddress,
	|	Tabular.DeliveryOption AS DeliveryOption,
	|	Tabular.StructuralUnit AS StructuralUnit
	|FROM
	|	Tabular AS Tabular
	|		LEFT JOIN AccumulationRegister.SalesOrders.Turnovers(
	|				,
	|				,
	|				,
	|				(SalesOrder, Products, Characteristic) IN
	|					(SELECT
	|						Tabular.SalesOrder,
	|						Tabular.Products,
	|						Tabular.Characteristic
	|					FROM
	|						Tabular)) AS SalesOrdersTurnovers
	|		ON Tabular.SalesOrder = SalesOrdersTurnovers.SalesOrder
	|			AND Tabular.Products = SalesOrdersTurnovers.Products
	|			AND Tabular.Characteristic = SalesOrdersTurnovers.Characteristic
	|
	|ORDER BY
	|	Tabular.DocumentNumber,
	|	LineNumber
	|TOTALS
	|	MAX(DocumentNumber),
	|	MAX(DocumentDate),
	|	MAX(Company),
	|	MAX(CompanyLogoFile),
	|	MAX(Counterparty),
	|	MAX(Contract),
	|	MAX(CounterpartyContactPerson),
	|	MAX(Comment),
	|	MAX(LineNumber),
	|	SUM(Quantity),
	|	SUM(QuantityOrdered),
	|	MAX(ShippingAddress),
	|	MAX(DeliveryOption),
	|	MAX(StructuralUnit)
	|BY
	|	Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	Tabular.Ref AS Ref,
	|	Tabular.SalesOrderNumber AS Number,
	|	Tabular.SalesOrderDate AS Date
	|FROM
	|	Tabular AS Tabular
	|WHERE
	|	Tabular.SalesOrderNumber <> """"
	|
	|ORDER BY
	|	Tabular.SalesOrderNumber
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
	|			AND FilteredInventory.Ref = Tabular.Ref
	|			AND FilteredInventory.Characteristic = Tabular.Characteristic
	|			AND FilteredInventory.MeasurementUnit = Tabular.MeasurementUnit
	|			AND FilteredInventory.Batch = Tabular.Batch
	|		INNER JOIN Document.GoodsIssue.SerialNumbers AS GoodsIssueSerialNumbers
	|			LEFT JOIN Catalog.SerialNumbers AS SerialNumbers
	|			ON GoodsIssueSerialNumbers.SerialNumber = SerialNumbers.Ref
	|		ON FilteredInventory.Ref = GoodsIssueSerialNumbers.Ref
	|			AND FilteredInventory.ConnectionKey = GoodsIssueSerialNumbers.ConnectionKey";

EndFunction

Function GetSalesInvoiceQuery()
	
	Return
	"SELECT
	|	SalesInvoice.Ref AS Ref,
	|	SalesInvoice.Number AS Number,
	|	SalesInvoice.Date AS Date,
	|	SalesInvoice.Company AS Company,
	|	SalesInvoice.Counterparty AS Counterparty,
	|	SalesInvoice.Contract AS Contract,
	|	CAST(SalesInvoice.Comment AS STRING(1024)) AS Comment,
	|	SalesInvoice.Order AS Order,
	|	SalesInvoice.SalesOrderPosition AS SalesOrderPosition,
	|	SalesInvoice.ContactPerson AS ContactPerson,
	|	SalesInvoice.ShippingAddress AS ShippingAddress,
	|	SalesInvoice.DeliveryOption AS DeliveryOption,
	|	SalesInvoice.StructuralUnit AS StructuralUnit
	|INTO SalesInvoice
	|FROM
	|	Document.SalesInvoice AS SalesInvoice
	|WHERE
	|	SalesInvoice.Ref IN(&ObjectsArray)
	|	AND NOT SalesInvoice.AdvanceInvoicing
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SalesInvoice.Ref AS Ref,
	|	SalesInvoice.Number AS DocumentNumber,
	|	SalesInvoice.Date AS DocumentDate,
	|	SalesInvoice.Company AS Company,
	|	Companies.LogoFile AS CompanyLogoFile,
	|	SalesInvoice.Counterparty AS Counterparty,
	|	SalesInvoice.Contract AS Contract,
	|	CASE
	|		WHEN SalesInvoice.ContactPerson <> VALUE(Catalog.ContactPersons.EmptyRef)
	|			THEN SalesInvoice.ContactPerson
	|		WHEN CounterpartyContracts.ContactPerson <> VALUE(Catalog.ContactPersons.EmptyRef)
	|			THEN CounterpartyContracts.ContactPerson
	|		ELSE Counterparties.ContactPerson
	|	END AS CounterpartyContactPerson,
	|	SalesOrder.Ref AS SalesOrder,
	|	ISNULL(SalesOrder.Number, """") AS SalesOrderNumber,
	|	ISNULL(SalesOrder.Date, DATETIME(1, 1, 1)) AS SalesOrderDate,
	|	SalesInvoice.Comment AS Comment,
	|	SalesInvoice.ShippingAddress AS ShippingAddress,
	|	SalesInvoice.DeliveryOption AS DeliveryOption,
	|	SalesInvoice.StructuralUnit AS StructuralUnit
	|INTO Header
	|FROM
	|	SalesInvoice AS SalesInvoice
	|		LEFT JOIN Catalog.Companies AS Companies
	|		ON SalesInvoice.Company = Companies.Ref
	|		LEFT JOIN Catalog.Counterparties AS Counterparties
	|		ON SalesInvoice.Counterparty = Counterparties.Ref
	|		LEFT JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
	|		ON SalesInvoice.Contract = CounterpartyContracts.Ref
	|		LEFT JOIN Document.SalesOrder AS SalesOrder
	|		ON SalesInvoice.Order = SalesOrder.Ref
	|			AND (SalesInvoice.SalesOrderPosition = VALUE(Enum.AttributeStationing.InHeader))
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
	|	Document.SalesInvoice.Inventory AS SalesInvoiceInventory
	|WHERE
	|	SalesInvoiceInventory.Ref IN(&ObjectsArray)
	|	AND SalesInvoiceInventory.ProductsTypeInventory
	|	AND SalesInvoiceInventory.GoodsIssue = VALUE(Document.GoodsIssue.EmptyRef)
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
	|	Header.CounterpartyContactPerson AS CounterpartyContactPerson,
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
	|	ISNULL(SalesOrders.Ref, Header.SalesOrder) AS SalesOrder,
	|	ISNULL(SalesOrders.Number, Header.SalesOrderNumber) AS SalesOrderNumber,
	|	ISNULL(SalesOrders.Date, Header.SalesOrderDate) AS SalesOrderDate,
	|	FilteredInventory.Products AS Products,
	|	FilteredInventory.Characteristic AS Characteristic,
	|	FilteredInventory.MeasurementUnit AS MeasurementUnit,
	|	FilteredInventory.Batch AS Batch,
	|	Header.ShippingAddress AS ShippingAddress,
	|	Header.DeliveryOption AS DeliveryOption,
	|	Header.StructuralUnit AS StructuralUnit
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
	|		LEFT JOIN Document.SalesOrder AS SalesOrders
	|		ON (FilteredInventory.Order = SalesOrders.Ref)
	|			AND (Header.SalesOrderNumber = """")
	|
	|GROUP BY
	|	Header.DocumentNumber,
	|	Header.DocumentDate,
	|	Header.Company,
	|	Header.Ref,
	|	Header.Counterparty,
	|	Header.CompanyLogoFile,
	|	Header.Contract,
	|	Header.CounterpartyContactPerson,
	|	Header.Comment,
	|	CatalogProducts.SKU,
	|	CASE
	|		WHEN (CAST(CatalogProducts.DescriptionFull AS STRING(1024))) <> """"
	|			THEN CAST(CatalogProducts.DescriptionFull AS STRING(1024))
	|		ELSE CatalogProducts.Description
	|	END,
	|	ISNULL(SalesOrders.Ref, Header.SalesOrder),
	|	ISNULL(SalesOrders.Date, Header.SalesOrderDate),
	|	CASE
	|		WHEN CatalogProducts.UseCharacteristics
	|			THEN CatalogCharacteristics.Description
	|		ELSE """"
	|	END,
	|	ISNULL(SalesOrders.Number, Header.SalesOrderNumber),
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
	|	Header.ShippingAddress,
	|	Header.DeliveryOption,
	|	Header.StructuralUnit
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
	|	Tabular.CounterpartyContactPerson AS CounterpartyContactPerson,
	|	Tabular.Comment AS Comment,
	|	Tabular.LineNumber AS LineNumber,
	|	Tabular.SKU AS SKU,
	|	Tabular.ProductDescription AS ProductDescription,
	|	Tabular.UseSerialNumbers AS UseSerialNumbers,
	|	Tabular.Quantity AS Quantity,
	|	SalesOrdersTurnovers.QuantityReceipt AS QuantityOrdered,
	|	Tabular.Products AS Products,
	|	Tabular.CharacteristicDescription AS CharacteristicDescription,
	|	Tabular.BatchDescription AS BatchDescription,
	|	Tabular.ConnectionKey AS ConnectionKey,
	|	Tabular.Characteristic AS Characteristic,
	|	Tabular.MeasurementUnit AS MeasurementUnit,
	|	Tabular.Batch AS Batch,
	|	Tabular.UOM AS UOM,
	|	FALSE AS ContentUsed,
	|	Tabular.ShippingAddress AS ShippingAddress,
	|	Tabular.DeliveryOption AS DeliveryOption,
	|	Tabular.StructuralUnit AS StructuralUnit
	|FROM
	|	Tabular AS Tabular
	|		LEFT JOIN AccumulationRegister.SalesOrders.Turnovers(
	|				,
	|				,
	|				,
	|				(SalesOrder, Products, Characteristic) IN
	|					(SELECT
	|						Tabular.SalesOrder,
	|						Tabular.Products,
	|						Tabular.Characteristic
	|					FROM
	|						Tabular)) AS SalesOrdersTurnovers
	|		ON Tabular.SalesOrder = SalesOrdersTurnovers.SalesOrder
	|			AND Tabular.Products = SalesOrdersTurnovers.Products
	|			AND Tabular.Characteristic = SalesOrdersTurnovers.Characteristic
	|
	|ORDER BY
	|	Tabular.DocumentNumber,
	|	LineNumber
	|TOTALS
	|	MAX(DocumentNumber),
	|	MAX(DocumentDate),
	|	MAX(Company),
	|	MAX(CompanyLogoFile),
	|	MAX(Counterparty),
	|	MAX(Contract),
	|	MAX(CounterpartyContactPerson),
	|	MAX(Comment),
	|	MAX(LineNumber),
	|	SUM(Quantity),
	|	SUM(QuantityOrdered),
	|	MAX(ShippingAddress),
	|	MAX(DeliveryOption),
	|	MAX(StructuralUnit)
	|BY
	|	Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	Tabular.Ref AS Ref,
	|	Tabular.SalesOrderNumber AS Number,
	|	Tabular.SalesOrderDate AS Date
	|FROM
	|	Tabular AS Tabular
	|WHERE
	|	Tabular.SalesOrderNumber <> """"
	|
	|ORDER BY
	|	Tabular.SalesOrderNumber
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
	|			AND FilteredInventory.Ref = Tabular.Ref
	|			AND FilteredInventory.Characteristic = Tabular.Characteristic
	|			AND FilteredInventory.MeasurementUnit = Tabular.MeasurementUnit
	|			AND FilteredInventory.Batch = Tabular.Batch
	|		INNER JOIN Document.SalesInvoice.SerialNumbers AS GoodsIssueSerialNumbers
	|			LEFT JOIN Catalog.SerialNumbers AS SerialNumbers
	|			ON GoodsIssueSerialNumbers.SerialNumber = SerialNumbers.Ref
	|		ON FilteredInventory.Ref = GoodsIssueSerialNumbers.Ref
	|			AND FilteredInventory.ConnectionKey = GoodsIssueSerialNumbers.ConnectionKey";

EndFunction

Function PrintDeliveryNote(ObjectsArray, PrintObjects, TemplateName)
	
	SpreadsheetDocument = New SpreadsheetDocument;
	SpreadsheetDocument.PrintParametersKey = "PrintParameters_DeliveryNote";
	
	Query = New Query();
	Query.SetParameter("ObjectsArray", ObjectsArray);

	Query.Text = ?(TypeOf(ObjectsArray[0]) = Type("DocumentRef.GoodsIssue"), GetGoodsIssueQuery(), GetSalesInvoiceQuery());
	
	ResultArray = Query.ExecuteBatch();
	
	FirstDocument = True;
	
	Header						= ResultArray[4].Select(QueryResultIteration.ByGroupsWithHierarchy);
	SalesOrdersNumbersHeaderSel	= ResultArray[5].Select(QueryResultIteration.ByGroupsWithHierarchy);
	SerialNumbersSel			= ResultArray[6].Select();
	
	While Header.Next() Do
		
		If Not FirstDocument Then
			SpreadsheetDocument.PutHorizontalPageBreak();
		EndIf;
		
		FirstDocument = False;
		
		FirstLineNumber = SpreadsheetDocument.TableHeight + 1;
		
		SpreadsheetDocument.PrintParametersName = "PRINT_PARAMETERS_DeliveryNote";
		
		Template = PrintManagement.PrintedFormsTemplate("DataProcessor.PrintDeliveryNote.PF_MXL_DeliveryNote");
		
		#Region PrintDeliveryNoteTitleArea
		
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
		
		#Region PrintDeliveryNoteCompanyInfoArea
		
		CompanyInfoArea = Template.GetArea("CompanyInfo");
		
		InfoAboutCompany = DriveServer.InfoAboutLegalEntityIndividual(Header.Company, Header.DocumentDate, ,);
		CompanyInfoArea.Parameters.Fill(InfoAboutCompany);
		
		SpreadsheetDocument.Put(CompanyInfoArea);
		
		#EndRegion
		
		#Region PrintDeliveryNoteCounterpartyInfoArea
		
		CounterpartyInfoArea = Template.GetArea("CounterpartyInfo");
		CounterpartyInfoArea.Parameters.Fill(Header);
		
		InfoAboutCounterparty = DriveServer.InfoAboutLegalEntityIndividual(Header.Counterparty, Header.DocumentDate, ,);
		CounterpartyInfoArea.Parameters.Fill(InfoAboutCounterparty);
		
		TitleParameters = New Structure;
		TitleParameters.Insert("TitleShipTo", NStr("en = 'Ship to'"));
		TitleParameters.Insert("TitleShipDate", NStr("en = 'Ship date'"));
		
		If Header.DeliveryOption = Enums.DeliveryOptions.SelfPickup Then
			
			InfoAboutPickupLocation	= DriveServer.InfoAboutLegalEntityIndividual(Header.StructuralUnit, Header.DocumentDate);
			ResponsibleEmployee		= InfoAboutPickupLocation.ResponsibleEmployee;
			
			If NOT IsBlankString(InfoAboutPickupLocation.FullDescr) Then
				CounterpartyInfoArea.Parameters.FullDescrShipTo = InfoAboutPickupLocation.FullDescr;
			EndIf;
			
			If NOT IsBlankString(InfoAboutPickupLocation.DeliveryAddress) Then
				CounterpartyInfoArea.Parameters.DeliveryAddress = InfoAboutPickupLocation.DeliveryAddress;
			EndIf;
			
			If ValueIsFilled(ResponsibleEmployee) Then
				CounterpartyInfoArea.Parameters.CounterpartyContactPerson = ResponsibleEmployee.Description;
			EndIf;
			
			If NOT IsBlankString(InfoAboutPickupLocation.PhoneNumbers) Then
				CounterpartyInfoArea.Parameters.PhoneNumbers = InfoAboutPickupLocation.PhoneNumbers;
			EndIf;
			
			TitleParameters.TitleShipTo		= NStr("en = 'Pickup location'");
			TitleParameters.TitleShipDate	= NStr("en = 'Pickup date'");
			
		Else
			
			InfoAboutShippingAddress	= DriveServer.InfoAboutShippingAddress(Header.ShippingAddress);
			InfoAboutContactPerson		= DriveServer.InfoAboutContactPerson(Header.CounterpartyContactPerson);
		
			If NOT IsBlankString(InfoAboutShippingAddress.DeliveryAddress) Then
				CounterpartyInfoArea.Parameters.DeliveryAddress = InfoAboutShippingAddress.DeliveryAddress;
			EndIf;
			
			If NOT IsBlankString(InfoAboutContactPerson.PhoneNumbers) Then
				CounterpartyInfoArea.Parameters.PhoneNumbers = InfoAboutContactPerson.PhoneNumbers;
			EndIf;
			
		EndIf;
		
		CounterpartyInfoArea.Parameters.Fill(TitleParameters);
		
		If IsBlankString(CounterpartyInfoArea.Parameters.DeliveryAddress) Then
			
			If Not IsBlankString(InfoAboutCounterparty.ActualAddress) Then
				CounterpartyInfoArea.Parameters.DeliveryAddress = InfoAboutCounterparty.ActualAddress;
			Else
				CounterpartyInfoArea.Parameters.DeliveryAddress = InfoAboutCounterparty.LegalAddress;
			EndIf;
			
		EndIf;
		
		SalesOrdersNumbersHeaderSel.Reset();
		If SalesOrdersNumbersHeaderSel.FindNext(New Structure("Ref", Header.Ref)) Then
			
			SalesOrdersNumbersArray = New Array;
			
			SalesOrdersNumbersSel = SalesOrdersNumbersHeaderSel.Select();
			While SalesOrdersNumbersSel.Next() Do
				
				SalesOrdersNumbersArray.Add(
					SalesOrdersNumbersSel.Number
					+ StringFunctionsClientServer.SubstituteParametersInString(
						" %1 ", NStr("en = 'dated'"))
					+ Format(SalesOrdersNumbersSel.Date, "DLF=D"));
				
			EndDo;
			
			CounterpartyInfoArea.Parameters.SalesOrders = StringFunctionsClientServer.GetStringFromSubstringArray(SalesOrdersNumbersArray, ", ");
			
		EndIf;
		
		SpreadsheetDocument.Put(CounterpartyInfoArea);
		
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

#EndRegion

#EndIf
