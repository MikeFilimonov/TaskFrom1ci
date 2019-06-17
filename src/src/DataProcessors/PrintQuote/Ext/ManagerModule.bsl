#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region PrintInterface

Function GetQueryText(ObjectsArray, TemplateName)
	
	QueryText = "";
	If ObjectsArray.Count() > 0 Then
		If TypeOf(ObjectsArray[0]) = Type("DocumentRef.Quote") And TemplateName = "Quote" Then
			QueryText = GetQuoteQueryTextForQuote(False);
		ElsIf TypeOf(ObjectsArray[0]) = Type("DocumentRef.Quote") And TemplateName = "QuoteAllVariants" Then
			QueryText = GetQuoteQueryTextForQuote(True);
		ElsIf TypeOf(ObjectsArray[0]) = Type("DocumentRef.Quote") And TemplateName = "ProformaInvoice" Then
			QueryText = GetProformaInvoiceQueryTextForQuote(False);
		ElsIf TypeOf(ObjectsArray[0]) = Type("DocumentRef.Quote") And TemplateName = "ProformaInvoiceAllVariants" Then
			QueryText = GetProformaInvoiceQueryTextForQuote(True);
		ElsIf TypeOf(ObjectsArray[0]) = Type("DocumentRef.SalesOrder") And TemplateName = "Quote" Then
			QueryText = GetQuoteQueryTextForSalesOrder();
		ElsIf TypeOf(ObjectsArray[0]) = Type("DocumentRef.SalesOrder") And TemplateName = "ProformaInvoice" Then
			QueryText = GetProformaInvoiceQueryTextForSalesOrder();
		EndIf;
	EndIf;
	
	Return QueryText;
	
EndFunction

Function GetProformaInvoiceQueryTextForQuote(AllVariants)
	
	QueryText = 
	"SELECT
	|	Quote.Ref AS Ref,
	|	Quote.Number AS Number,
	|	Quote.Date AS Date,
	|	Quote.Company AS Company,
	|	Quote.Counterparty AS Counterparty,
	|	Quote.Contract AS Contract,
	|	Quote.BankAccount AS BankAccount,
	|	Quote.AmountIncludesVAT AS AmountIncludesVAT,
	|	Quote.DocumentCurrency AS DocumentCurrency,
	|	Quote.PreferredVariant AS PreferredVariant
	|INTO Quotes
	|FROM
	|	Document.Quote AS Quote
	|WHERE
	|	Quote.Ref IN(&ObjectsArray)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Quote.Ref AS Ref,
	|	Quote.Number AS DocumentNumber,
	|	Quote.Date AS DocumentDate,
	|	Quote.Company AS Company,
	|	Companies.LogoFile AS CompanyLogoFile,
	|	Quote.Counterparty AS Counterparty,
	|	Quote.Contract AS Contract,
	|	Quote.BankAccount AS BankAccount,
	|	CASE
	|		WHEN CounterpartyContracts.ContactPerson = VALUE(Catalog.ContactPersons.EmptyRef)
	|			THEN Counterparties.ContactPerson
	|		ELSE CounterpartyContracts.ContactPerson
	|	END AS CounterpartyContactPerson,
	|	Quote.AmountIncludesVAT AS AmountIncludesVAT,
	|	Quote.DocumentCurrency AS DocumentCurrency,
	|	Quote.PreferredVariant AS PreferredVariant
	|INTO Header
	|FROM
	|	Quotes AS Quote
	|		LEFT JOIN Catalog.Companies AS Companies
	|		ON Quote.Company = Companies.Ref
	|		LEFT JOIN Catalog.Counterparties AS Counterparties
	|		ON Quote.Counterparty = Counterparties.Ref
	|		LEFT JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
	|		ON Quote.Contract = CounterpartyContracts.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	QuoteInventory.Ref AS Ref,
	|	QuoteInventory.LineNumber AS LineNumber,
	|	QuoteInventory.Products AS Products,
	|	QuoteInventory.Characteristic AS Characteristic,
	|	VALUE(Catalog.ProductsBatches.EmptyRef) AS Batch,
	|	QuoteInventory.Quantity AS Quantity,
	|	QuoteInventory.MeasurementUnit AS MeasurementUnit,
	|	QuoteInventory.Price * (QuoteInventory.Total - QuoteInventory.VATAmount) / QuoteInventory.Amount AS Price,
	|	QuoteInventory.DiscountMarkupPercent AS DiscountMarkupPercent,
	|	QuoteInventory.Total - QuoteInventory.VATAmount AS Amount,
	|	QuoteInventory.VATRate AS VATRate,
	|	QuoteInventory.VATAmount AS VATAmount,
	|	QuoteInventory.Total AS Total,
	|	QuoteInventory.Content AS Content,
	|	QuoteInventory.AutomaticDiscountsPercent AS AutomaticDiscountsPercent,
	|	QuoteInventory.AutomaticDiscountAmount AS AutomaticDiscountAmount,
	|	QuoteInventory.ConnectionKey AS ConnectionKey,
	|	QuoteInventory.Variant AS Variant
	|INTO FilteredInventory
	|FROM
	|	Document.Quote.Inventory AS QuoteInventory
	|WHERE
	|	QuoteInventory.Ref IN(&ObjectsArray)
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
	|	Header.BankAccount AS BankAccount,
	|	Header.AmountIncludesVAT AS AmountIncludesVAT,
	|	Header.DocumentCurrency AS DocumentCurrency,
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
	|	FilteredInventory.Price AS Price,
	|	FilteredInventory.DiscountMarkupPercent AS DiscountRate,
	|	SUM(FilteredInventory.AutomaticDiscountAmount) AS AutomaticDiscountAmount,
	|	SUM(FilteredInventory.Amount) AS Amount,
	|	FilteredInventory.VATRate AS VATRate,
	|	SUM(FilteredInventory.VATAmount) AS VATAmount,
	|	FilteredInventory.Price * SUM(CASE
	|			WHEN CatalogProducts.IsFreightService
	|				THEN FilteredInventory.Quantity
	|			ELSE 0
	|		END) AS Freight,
	|	SUM(FilteredInventory.Total) AS Total,
	|	FilteredInventory.Price * SUM(CASE
	|			WHEN CatalogProducts.IsFreightService
	|				THEN 0
	|			ELSE FilteredInventory.Quantity
	|		END) AS Subtotal,
	|	FilteredInventory.Products AS Products,
	|	FilteredInventory.Characteristic AS Characteristic,
	|	FilteredInventory.MeasurementUnit AS MeasurementUnit,
	|	FilteredInventory.Batch AS Batch,
	|	FilteredInventory.Variant AS Variant,
	|	CatalogProducts.IsFreightService AS IsFreightService
	|INTO Tabular
	|FROM
	|	Header AS Header
	|		INNER JOIN FilteredInventory AS FilteredInventory
	|		ON Header.Ref = FilteredInventory.Ref
	|			AND (Header.PreferredVariant = FilteredInventory.Variant
	|				OR &AllVariants)
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
	|	Header.CounterpartyContactPerson,
	|	Header.BankAccount,
	|	Header.AmountIncludesVAT,
	|	Header.DocumentCurrency,
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
	|	FilteredInventory.Price,
	|	FilteredInventory.DiscountMarkupPercent,
	|	FilteredInventory.Characteristic,
	|	FilteredInventory.MeasurementUnit,
	|	FilteredInventory.Batch,
	|	FilteredInventory.Variant,
	|	CatalogProducts.IsFreightService
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
	|	Tabular.BankAccount AS BankAccount,
	|	Tabular.AmountIncludesVAT AS AmountIncludesVAT,
	|	Tabular.DocumentCurrency AS DocumentCurrency,
	|	Tabular.LineNumber AS LineNumber,
	|	Tabular.SKU AS SKU,
	|	Tabular.ProductDescription AS ProductDescription,
	|	Tabular.ContentUsed AS ContentUsed,
	|	Tabular.UseSerialNumbers AS UseSerialNumbers,
	|	Tabular.Quantity AS Quantity,
	|	Tabular.Price AS Price,
	|	Tabular.Amount AS Amount,
	|	Tabular.VATRate AS VATRate,
	|	Tabular.VATAmount AS VATAmount,
	|	Tabular.Total AS Total,
	|	Tabular.Subtotal AS Subtotal,
	|	Tabular.Freight AS FreightTotal,
	|	CAST(Tabular.Quantity * Tabular.Price - Tabular.Amount AS NUMBER(15, 2)) AS DiscountAmount,
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
	|	VALUE(Catalog.ShippingAddresses.EmptyRef) AS ShippingAddress,
	|	VALUE(Catalog.BusinessUnits.EmptyRef) AS StructuralUnit,
	|	VALUE(Enum.DeliveryOptions.EmptyRef) AS DeliveryOption,
	|	Tabular.Variant AS Variant,
	|	Tabular.IsFreightService AS IsFreightService
	|FROM
	|	Tabular AS Tabular
	|
	|ORDER BY
	|	Tabular.DocumentNumber,
	|	Variant,
	|	LineNumber
	|TOTALS
	|	MAX(DocumentNumber),
	|	MAX(DocumentDate),
	|	MAX(Company),
	|	MAX(CompanyLogoFile),
	|	MAX(Counterparty),
	|	MAX(Contract),
	|	MAX(CounterpartyContactPerson),
	|	MAX(BankAccount),
	|	MAX(AmountIncludesVAT),
	|	MAX(DocumentCurrency),
	|	COUNT(LineNumber),
	|	SUM(Quantity),
	|	SUM(VATAmount),
	|	SUM(Total),
	|	SUM(Subtotal),
	|	SUM(FreightTotal),
	|	SUM(DiscountAmount),
	|	MAX(ShippingAddress),
	|	MAX(StructuralUnit),
	|	MAX(DeliveryOption)
	|BY
	|	Ref,
	|	Variant
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Tabular.Ref AS Ref,
	|	Tabular.Variant AS Variant,
	|	Tabular.VATRate AS VATRate,
	|	SUM(Tabular.Amount) AS Amount,
	|	SUM(Tabular.VATAmount) AS VATAmount
	|FROM
	|	Tabular AS Tabular
	|
	|GROUP BY
	|	Tabular.Ref,
	|	Tabular.Variant,
	|	Tabular.VATRate
	|TOTALS BY
	|	Ref,
	|	Variant
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	COUNT(Tabular.LineNumber) AS LineNumber,
	|	Tabular.Ref AS Ref,
	|	SUM(Tabular.Quantity) AS Quantity,
	|	Tabular.Variant AS Variant
	|FROM
	|	Tabular AS Tabular
	|WHERE
	|	NOT Tabular.IsFreightService
	|
	|GROUP BY
	|	Tabular.Ref,
	|	Tabular.Variant";
	
	Return QueryText;
	
EndFunction

Function GetProformaInvoiceQueryTextForSalesOrder()
	
	QueryText = 
	"SELECT
	|	SalesOrder.Ref AS Ref,
	|	SalesOrder.Number AS Number,
	|	SalesOrder.Date AS Date,
	|	SalesOrder.Company AS Company,
	|	SalesOrder.Counterparty AS Counterparty,
	|	SalesOrder.Contract AS Contract,
	|	SalesOrder.BankAccount AS BankAccount,
	|	SalesOrder.AmountIncludesVAT AS AmountIncludesVAT,
	|	SalesOrder.DocumentCurrency AS DocumentCurrency,
	|	SalesOrder.EstimateIsCalculated AS EstimateIsCalculated,
	|	SalesOrder.ContactPerson AS ContactPerson,
	|	SalesOrder.ShippingAddress AS ShippingAddress,
	|	SalesOrder.StructuralUnitReserve AS StructuralUnit,
	|	SalesOrder.DeliveryOption AS DeliveryOption
	|INTO SalesOrders
	|FROM
	|	Document.SalesOrder AS SalesOrder
	|WHERE
	|	SalesOrder.Ref IN(&ObjectsArray)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SalesOrder.Ref AS Ref,
	|	SalesOrder.Number AS DocumentNumber,
	|	SalesOrder.Date AS DocumentDate,
	|	SalesOrder.Company AS Company,
	|	Companies.LogoFile AS CompanyLogoFile,
	|	SalesOrder.Counterparty AS Counterparty,
	|	SalesOrder.Contract AS Contract,
	|	CASE
	|		WHEN SalesOrder.ContactPerson <> VALUE(Catalog.ContactPersons.EmptyRef)
	|			THEN SalesOrder.ContactPerson
	|		WHEN CounterpartyContracts.ContactPerson <> VALUE(Catalog.ContactPersons.EmptyRef)
	|			THEN CounterpartyContracts.ContactPerson
	|		ELSE Counterparties.ContactPerson
	|	END AS CounterpartyContactPerson,
	|	SalesOrder.BankAccount AS BankAccount,
	|	SalesOrder.AmountIncludesVAT AS AmountIncludesVAT,
	|	SalesOrder.DocumentCurrency AS DocumentCurrency,
	|	SalesOrder.ShippingAddress AS ShippingAddress,
	|	SalesOrder.StructuralUnit AS StructuralUnit,
	|	SalesOrder.DeliveryOption AS DeliveryOption
	|INTO Header
	|FROM
	|	SalesOrders AS SalesOrder
	|		LEFT JOIN Catalog.Companies AS Companies
	|		ON SalesOrder.Company = Companies.Ref
	|		LEFT JOIN Catalog.Counterparties AS Counterparties
	|		ON SalesOrder.Counterparty = Counterparties.Ref
	|		LEFT JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
	|		ON SalesOrder.Contract = CounterpartyContracts.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SalesOrderInventory.Ref AS Ref,
	|	SalesOrderInventory.LineNumber AS LineNumber,
	|	SalesOrderInventory.Products AS Products,
	|	SalesOrderInventory.Characteristic AS Characteristic,
	|	SalesOrderInventory.Batch AS Batch,
	|	SalesOrderInventory.Quantity AS Quantity,
	|	SalesOrderInventory.Reserve AS Reserve,
	|	SalesOrderInventory.MeasurementUnit AS MeasurementUnit,
	|	SalesOrderInventory.Price * (SalesOrderInventory.Total - SalesOrderInventory.VATAmount) / SalesOrderInventory.Amount AS Price,
	|	SalesOrderInventory.DiscountMarkupPercent AS DiscountMarkupPercent,
	|	SalesOrderInventory.Total - SalesOrderInventory.VATAmount AS Amount,
	|	SalesOrderInventory.VATRate AS VATRate,
	|	SalesOrderInventory.VATAmount AS VATAmount,
	|	SalesOrderInventory.Total AS Total,
	|	SalesOrderInventory.Content AS Content,
	|	SalesOrderInventory.AutomaticDiscountsPercent AS AutomaticDiscountsPercent,
	|	SalesOrderInventory.AutomaticDiscountAmount AS AutomaticDiscountAmount,
	|	SalesOrderInventory.ConnectionKey AS ConnectionKey
	|INTO FilteredInventory
	|FROM
	|	Document.SalesOrder.Inventory AS SalesOrderInventory
	|WHERE
	|	SalesOrderInventory.Ref IN(&ObjectsArray)
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
	|	Header.BankAccount AS BankAccount,
	|	Header.AmountIncludesVAT AS AmountIncludesVAT,
	|	Header.DocumentCurrency AS DocumentCurrency,
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
	|	FilteredInventory.Price AS Price,
	|	FilteredInventory.DiscountMarkupPercent AS DiscountRate,
	|	SUM(FilteredInventory.AutomaticDiscountAmount) AS AutomaticDiscountAmount,
	|	SUM(FilteredInventory.Amount) AS Amount,
	|	FilteredInventory.VATRate AS VATRate,
	|	SUM(FilteredInventory.VATAmount) AS VATAmount,
	|	FilteredInventory.Price * SUM(CASE
	|			WHEN CatalogProducts.IsFreightService
	|				THEN FilteredInventory.Quantity
	|			ELSE 0
	|		END) AS Freight,
	|	SUM(FilteredInventory.Total) AS Total,
	|	FilteredInventory.Price * SUM(CASE
	|			WHEN CatalogProducts.IsFreightService
	|				THEN 0
	|			ELSE FilteredInventory.Quantity
	|		END) AS Subtotal,
	|	FilteredInventory.Products AS Products,
	|	FilteredInventory.Characteristic AS Characteristic,
	|	FilteredInventory.MeasurementUnit AS MeasurementUnit,
	|	FilteredInventory.Batch AS Batch,
	|	Header.ShippingAddress AS ShippingAddress,
	|	Header.StructuralUnit AS StructuralUnit,
	|	Header.DeliveryOption AS DeliveryOption,
	|	CatalogProducts.IsFreightService AS IsFreightService
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
	|	Header.Counterparty,
	|	Header.CompanyLogoFile,
	|	Header.Contract,
	|	Header.CounterpartyContactPerson,
	|	Header.BankAccount,
	|	Header.AmountIncludesVAT,
	|	Header.DocumentCurrency,
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
	|	FilteredInventory.Price,
	|	FilteredInventory.DiscountMarkupPercent,
	|	FilteredInventory.Characteristic,
	|	FilteredInventory.MeasurementUnit,
	|	FilteredInventory.Batch,
	|	Header.ShippingAddress,
	|	Header.StructuralUnit,
	|	Header.DeliveryOption,
	|	CatalogProducts.IsFreightService
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
	|	Tabular.BankAccount AS BankAccount,
	|	Tabular.AmountIncludesVAT AS AmountIncludesVAT,
	|	Tabular.DocumentCurrency AS DocumentCurrency,
	|	Tabular.LineNumber AS LineNumber,
	|	Tabular.SKU AS SKU,
	|	Tabular.ProductDescription AS ProductDescription,
	|	Tabular.ContentUsed AS ContentUsed,
	|	Tabular.UseSerialNumbers AS UseSerialNumbers,
	|	Tabular.Quantity AS Quantity,
	|	Tabular.Price AS Price,
	|	Tabular.Amount AS Amount,
	|	Tabular.VATRate AS VATRate,
	|	Tabular.VATAmount AS VATAmount,
	|	Tabular.Total AS Total,
	|	Tabular.Subtotal AS Subtotal,
	|	Tabular.Freight AS FreightTotal,
	|	CAST(Tabular.Quantity * Tabular.Price - Tabular.Amount AS NUMBER(15, 2)) AS DiscountAmount,
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
	|	Tabular.ShippingAddress AS ShippingAddress,
	|	Tabular.StructuralUnit AS StructuralUnit,
	|	Tabular.DeliveryOption AS DeliveryOption,
	|	0 AS Variant,
	|	Tabular.IsFreightService AS IsFreightService
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
	|	MAX(Counterparty),
	|	MAX(Contract),
	|	MAX(CounterpartyContactPerson),
	|	MAX(BankAccount),
	|	MAX(AmountIncludesVAT),
	|	MAX(DocumentCurrency),
	|	COUNT(LineNumber),
	|	SUM(Quantity),
	|	SUM(VATAmount),
	|	SUM(Total),
	|	SUM(Subtotal),
	|	SUM(FreightTotal),
	|	SUM(DiscountAmount),
	|	MAX(ShippingAddress),
	|	MAX(StructuralUnit),
	|	MAX(DeliveryOption)
	|BY
	|	Ref,
	|	Variant
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Tabular.Ref AS Ref,
	|	0 AS Variant,
	|	Tabular.VATRate AS VATRate,
	|	SUM(Tabular.Amount) AS Amount,
	|	SUM(Tabular.VATAmount) AS VATAmount
	|FROM
	|	Tabular AS Tabular
	|
	|GROUP BY
	|	Tabular.Ref,
	|	Tabular.VATRate
	|TOTALS BY
	|	Ref,
	|	Variant
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	COUNT(Tabular.LineNumber) AS LineNumber,
	|	Tabular.Ref AS Ref,
	|	SUM(Tabular.Quantity) AS Quantity,
	|	0 AS Variant
	|FROM
	|	Tabular AS Tabular
	|WHERE
	|	NOT Tabular.IsFreightService
	|
	|GROUP BY
	|	Tabular.Ref";
	
	Return QueryText;
	
EndFunction

Function GetQuoteQueryTextForQuote(AllVariants)
	
	QueryText = 
	"SELECT
	|	Quote.Ref AS Ref,
	|	Quote.Number AS Number,
	|	Quote.Date AS Date,
	|	Quote.Company AS Company,
	|	Quote.Counterparty AS Counterparty,
	|	Quote.Contract AS Contract,
	|	Quote.BankAccount AS BankAccount,
	|	Quote.AmountIncludesVAT AS AmountIncludesVAT,
	|	Quote.DocumentCurrency AS DocumentCurrency,
	|	Quote.ValidUntil AS ValidUntil,
	|	CASE
	|		WHEN Quote.VATTaxation = VALUE(Enum.VATTaxationTypes.ReverseChargeVAT)
	|			THEN &ReverseChargeAppliesRate
	|		ELSE """"
	|	END AS ReverseChargeApplies,
	|	Quote.PreferredVariant AS PreferredVariant
	|INTO Quotes
	|FROM
	|	Document.Quote AS Quote
	|WHERE
	|	Quote.Ref IN(&ObjectsArray)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Quote.Ref AS Ref,
	|	Quote.Number AS DocumentNumber,
	|	Quote.Date AS DocumentDate,
	|	Quote.Company AS Company,
	|	Companies.LogoFile AS CompanyLogoFile,
	|	Quote.Counterparty AS Counterparty,
	|	Quote.Contract AS Contract,
	|	Quote.BankAccount AS BankAccount,
	|	CASE
	|		WHEN CounterpartyContracts.ContactPerson = VALUE(Catalog.ContactPersons.EmptyRef)
	|			THEN Counterparties.ContactPerson
	|		ELSE CounterpartyContracts.ContactPerson
	|	END AS CounterpartyContactPerson,
	|	Quote.AmountIncludesVAT AS AmountIncludesVAT,
	|	Quote.DocumentCurrency AS DocumentCurrency,
	|	Quote.ValidUntil AS ValidUntil,
	|	Quote.ReverseChargeApplies AS ReverseChargeApplies,
	|	Quote.PreferredVariant AS PreferredVariant
	|INTO Header
	|FROM
	|	Quotes AS Quote
	|		LEFT JOIN Catalog.Companies AS Companies
	|		ON Quote.Company = Companies.Ref
	|		LEFT JOIN Catalog.Counterparties AS Counterparties
	|		ON Quote.Counterparty = Counterparties.Ref
	|		LEFT JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
	|		ON Quote.Contract = CounterpartyContracts.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	QuoteInventory.Ref AS Ref,
	|	QuoteInventory.LineNumber AS LineNumber,
	|	QuoteInventory.Products AS Products,
	|	QuoteInventory.Characteristic AS Characteristic,
	|	VALUE(Catalog.ProductsBatches.EmptyRef) AS Batch,
	|	QuoteInventory.Quantity AS Quantity,
	|	QuoteInventory.MeasurementUnit AS MeasurementUnit,
	|	QuoteInventory.Price * (QuoteInventory.Total - QuoteInventory.VATAmount) / QuoteInventory.Amount AS Price,
	|	QuoteInventory.DiscountMarkupPercent AS DiscountMarkupPercent,
	|	QuoteInventory.Total - QuoteInventory.VATAmount AS Amount,
	|	QuoteInventory.VATRate AS VATRate,
	|	QuoteInventory.VATAmount AS VATAmount,
	|	QuoteInventory.Total AS Total,
	|	QuoteInventory.Content AS Content,
	|	QuoteInventory.AutomaticDiscountsPercent AS AutomaticDiscountsPercent,
	|	QuoteInventory.AutomaticDiscountAmount AS AutomaticDiscountAmount,
	|	QuoteInventory.ConnectionKey AS ConnectionKey,
	|	QuoteInventory.Variant AS Variant
	|INTO FilteredInventory
	|FROM
	|	Document.Quote.Inventory AS QuoteInventory
	|WHERE
	|	QuoteInventory.Ref IN(&ObjectsArray)
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
	|	Header.BankAccount AS BankAccount,
	|	Header.AmountIncludesVAT AS AmountIncludesVAT,
	|	Header.DocumentCurrency AS DocumentCurrency,
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
	|	FilteredInventory.Price AS Price,
	|	SUM(FilteredInventory.AutomaticDiscountAmount) AS AutomaticDiscountAmount,
	|	FilteredInventory.DiscountMarkupPercent AS DiscountMarkupPercent,
	|	SUM(FilteredInventory.Amount) AS Amount,
	|	FilteredInventory.VATRate AS VATRate,
	|	SUM(FilteredInventory.VATAmount) AS VATAmount,
	|	SUM(FilteredInventory.Total) AS Total,
	|	FilteredInventory.Price * SUM(FilteredInventory.Quantity) AS Subtotal,
	|	FilteredInventory.Products AS Products,
	|	FilteredInventory.Characteristic AS Characteristic,
	|	FilteredInventory.Batch AS Batch,
	|	FilteredInventory.MeasurementUnit AS MeasurementUnit,
	|	Header.ValidUntil AS ValidUntil,
	|	Header.ReverseChargeApplies AS ReverseChargeApplies,
	|	FilteredInventory.Variant AS Variant
	|INTO Tabular
	|FROM
	|	Header AS Header
	|		INNER JOIN FilteredInventory AS FilteredInventory
	|		ON Header.Ref = FilteredInventory.Ref
	|			AND (Header.PreferredVariant = FilteredInventory.Variant
	|				OR &AllVariants)
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
	|	FilteredInventory.VATRate,
	|	Header.Company,
	|	Header.Counterparty,
	|	Header.Contract,
	|	CatalogProducts.SKU,
	|	Header.CounterpartyContactPerson,
	|	Header.BankAccount,
	|	Header.AmountIncludesVAT,
	|	CASE
	|		WHEN (CAST(FilteredInventory.Content AS STRING(1024))) <> """"
	|			THEN CAST(FilteredInventory.Content AS STRING(1024))
	|		WHEN (CAST(CatalogProducts.DescriptionFull AS STRING(1024))) <> """"
	|			THEN CAST(CatalogProducts.DescriptionFull AS STRING(1024))
	|		ELSE CatalogProducts.Description
	|	END,
	|	(CAST(FilteredInventory.Content AS STRING(1024))) <> """",
	|	Header.CompanyLogoFile,
	|	Header.DocumentNumber,
	|	Header.DocumentCurrency,
	|	Header.Ref,
	|	Header.DocumentDate,
	|	CASE
	|		WHEN CatalogProducts.UseCharacteristics
	|			THEN CatalogCharacteristics.Description
	|		ELSE """"
	|	END,
	|	CASE
	|		WHEN CatalogProducts.UseBatches
	|			THEN CatalogBatches.Description
	|		ELSE """"
	|	END,
	|	CatalogProducts.UseSerialNumbers,
	|	ISNULL(CatalogUOM.Description, CatalogUOMClassifier.Description),
	|	FilteredInventory.DiscountMarkupPercent,
	|	FilteredInventory.Products,
	|	FilteredInventory.Characteristic,
	|	FilteredInventory.Batch,
	|	FilteredInventory.MeasurementUnit,
	|	Header.ValidUntil,
	|	Header.ReverseChargeApplies,
	|	FilteredInventory.Variant,
	|	FilteredInventory.Price
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
	|	Tabular.BankAccount AS BankAccount,
	|	Tabular.AmountIncludesVAT AS AmountIncludesVAT,
	|	Tabular.DocumentCurrency AS DocumentCurrency,
	|	Tabular.LineNumber AS LineNumber,
	|	Tabular.SKU AS SKU,
	|	Tabular.ProductDescription AS ProductDescription,
	|	Tabular.ContentUsed AS ContentUsed,
	|	Tabular.UseSerialNumbers AS UseSerialNumbers,
	|	Tabular.ConnectionKey AS ConnectionKey,
	|	Tabular.Quantity AS Quantity,
	|	Tabular.Price AS Price,
	|	CASE
	|		WHEN Tabular.AutomaticDiscountAmount = 0
	|			THEN Tabular.DiscountMarkupPercent
	|		WHEN Tabular.Subtotal = 0
	|			THEN 0
	|		ELSE CAST((Tabular.Subtotal - Tabular.Amount) / Tabular.Subtotal * 100 AS NUMBER(15, 2))
	|	END AS DiscountRate,
	|	Tabular.Amount AS Amount,
	|	Tabular.VATRate AS VATRate,
	|	Tabular.VATAmount AS VATAmount,
	|	Tabular.Total AS Total,
	|	Tabular.Subtotal AS Subtotal,
	|	CAST(Tabular.Quantity * Tabular.Price - Tabular.Amount AS NUMBER(15, 2)) AS DiscountAmount,
	|	Tabular.CharacteristicDescription AS CharacteristicDescription,
	|	Tabular.BatchDescription AS BatchDescription,
	|	Tabular.Characteristic AS Characteristic,
	|	Tabular.Batch AS Batch,
	|	Tabular.UOM AS UOM,
	|	Tabular.ValidUntil AS ValidUntil,
	|	Tabular.ReverseChargeApplies AS ReverseChargeApplies,
	|	Tabular.Variant AS Variant
	|FROM
	|	Tabular AS Tabular
	|
	|ORDER BY
	|	DocumentNumber,
	|	Variant,
	|	LineNumber
	|TOTALS
	|	MAX(DocumentNumber),
	|	MAX(DocumentDate),
	|	MAX(Company),
	|	MAX(CompanyLogoFile),
	|	MAX(Counterparty),
	|	MAX(Contract),
	|	MAX(CounterpartyContactPerson),
	|	MAX(BankAccount),
	|	MAX(AmountIncludesVAT),
	|	MAX(DocumentCurrency),
	|	COUNT(LineNumber),
	|	SUM(Quantity),
	|	SUM(VATAmount),
	|	SUM(Total),
	|	SUM(Subtotal),
	|	SUM(DiscountAmount),
	|	MAX(ValidUntil),
	|	MAX(ReverseChargeApplies)
	|BY
	|	Ref,
	|	Variant";
	
	Return QueryText;
	
EndFunction

Function GetQuoteQueryTextForSalesOrder()
	
	QueryText = 
	"SELECT
	|	SalesOrder.Ref AS Ref,
	|	SalesOrder.Number AS Number,
	|	SalesOrder.Date AS Date,
	|	SalesOrder.Company AS Company,
	|	SalesOrder.Counterparty AS Counterparty,
	|	SalesOrder.Contract AS Contract,
	|	SalesOrder.BankAccount AS BankAccount,
	|	SalesOrder.AmountIncludesVAT AS AmountIncludesVAT,
	|	SalesOrder.DocumentCurrency AS DocumentCurrency,
	|	SalesOrder.ShipmentDate AS ShipmentDate,
	|	CASE
	|		WHEN SalesOrder.VATTaxation = VALUE(Enum.VATTaxationTypes.ReverseChargeVAT)
	|			THEN &ReverseChargeAppliesRate
	|		ELSE """"
	|	END AS ReverseChargeApplies
	|INTO SalesOrders
	|FROM
	|	Document.SalesOrder AS SalesOrder
	|WHERE
	|	SalesOrder.Ref IN(&ObjectsArray)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SalesOrder.Ref AS Ref,
	|	SalesOrder.Number AS DocumentNumber,
	|	SalesOrder.Date AS DocumentDate,
	|	SalesOrder.Company AS Company,
	|	Companies.LogoFile AS CompanyLogoFile,
	|	SalesOrder.Counterparty AS Counterparty,
	|	SalesOrder.Contract AS Contract,
	|	CASE
	|		WHEN CounterpartyContracts.ContactPerson = VALUE(Catalog.ContactPersons.EmptyRef)
	|			THEN Counterparties.ContactPerson
	|		ELSE CounterpartyContracts.ContactPerson
	|	END AS CounterpartyContactPerson,
	|	SalesOrder.BankAccount AS BankAccount,
	|	SalesOrder.AmountIncludesVAT AS AmountIncludesVAT,
	|	SalesOrder.DocumentCurrency AS DocumentCurrency,
	|	SalesOrder.ShipmentDate AS ShipmentDate,
	|	SalesOrder.ReverseChargeApplies AS ReverseChargeApplies
	|INTO Header
	|FROM
	|	SalesOrders AS SalesOrder
	|		LEFT JOIN Catalog.Companies AS Companies
	|		ON SalesOrder.Company = Companies.Ref
	|		LEFT JOIN Catalog.Counterparties AS Counterparties
	|		ON SalesOrder.Counterparty = Counterparties.Ref
	|		LEFT JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
	|		ON SalesOrder.Contract = CounterpartyContracts.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SalesOrderInventory.Ref AS Ref,
	|	SalesOrderInventory.LineNumber AS LineNumber,
	|	SalesOrderInventory.Products AS Products,
	|	SalesOrderInventory.Characteristic AS Characteristic,
	|	SalesOrderInventory.Batch AS Batch,
	|	SalesOrderInventory.Quantity AS Quantity,
	|	SalesOrderInventory.MeasurementUnit AS MeasurementUnit,
	|	SalesOrderInventory.Price * (SalesOrderInventory.Total - SalesOrderInventory.VATAmount) / SalesOrderInventory.Amount AS Price,
	|	SalesOrderInventory.DiscountMarkupPercent AS DiscountMarkupPercent,
	|	SalesOrderInventory.Total - SalesOrderInventory.VATAmount AS Amount,
	|	SalesOrderInventory.VATRate AS VATRate,
	|	SalesOrderInventory.VATAmount AS VATAmount,
	|	SalesOrderInventory.Total AS Total,
	|	SalesOrderInventory.Content AS Content,
	|	SalesOrderInventory.AutomaticDiscountsPercent AS AutomaticDiscountsPercent,
	|	SalesOrderInventory.AutomaticDiscountAmount AS AutomaticDiscountAmount,
	|	SalesOrderInventory.ConnectionKey AS ConnectionKey
	|INTO FilteredInventory
	|FROM
	|	Document.SalesOrder.Inventory AS SalesOrderInventory
	|WHERE
	|	SalesOrderInventory.Ref IN(&ObjectsArray)
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
	|	Header.BankAccount AS BankAccount,
	|	Header.AmountIncludesVAT AS AmountIncludesVAT,
	|	Header.DocumentCurrency AS DocumentCurrency,
	|	Header.ShipmentDate AS ShipmentDate,
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
	|	FilteredInventory.Price AS Price,
	|	SUM(FilteredInventory.AutomaticDiscountAmount) AS AutomaticDiscountAmount,
	|	FilteredInventory.DiscountMarkupPercent AS DiscountMarkupPercent,
	|	SUM(FilteredInventory.Amount) AS Amount,
	|	FilteredInventory.VATRate AS VATRate,
	|	SUM(FilteredInventory.VATAmount) AS VATAmount,
	|	SUM(FilteredInventory.Total) AS Total,
	|	FilteredInventory.Price * SUM(FilteredInventory.Quantity) AS Subtotal,
	|	FilteredInventory.Products AS Products,
	|	FilteredInventory.Characteristic AS Characteristic,
	|	FilteredInventory.Batch AS Batch,
	|	FilteredInventory.MeasurementUnit AS MeasurementUnit,
	|	Header.ReverseChargeApplies AS ReverseChargeApplies
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
	|	FilteredInventory.VATRate,
	|	Header.Company,
	|	Header.Counterparty,
	|	Header.Contract,
	|	CatalogProducts.SKU,
	|	Header.CounterpartyContactPerson,
	|	Header.BankAccount,
	|	Header.AmountIncludesVAT,
	|	CASE
	|		WHEN (CAST(FilteredInventory.Content AS STRING(1024))) <> """"
	|			THEN CAST(FilteredInventory.Content AS STRING(1024))
	|		WHEN (CAST(CatalogProducts.DescriptionFull AS STRING(1024))) <> """"
	|			THEN CAST(CatalogProducts.DescriptionFull AS STRING(1024))
	|		ELSE CatalogProducts.Description
	|	END,
	|	Header.ShipmentDate,
	|	(CAST(FilteredInventory.Content AS STRING(1024))) <> """",
	|	Header.CompanyLogoFile,
	|	Header.DocumentNumber,
	|	Header.DocumentCurrency,
	|	Header.Ref,
	|	Header.DocumentDate,
	|	CASE
	|		WHEN CatalogProducts.UseCharacteristics
	|			THEN CatalogCharacteristics.Description
	|		ELSE """"
	|	END,
	|	CASE
	|		WHEN CatalogProducts.UseBatches
	|			THEN CatalogBatches.Description
	|		ELSE """"
	|	END,
	|	CatalogProducts.UseSerialNumbers,
	|	ISNULL(CatalogUOM.Description, CatalogUOMClassifier.Description),
	|	FilteredInventory.DiscountMarkupPercent,
	|	FilteredInventory.Products,
	|	FilteredInventory.Characteristic,
	|	FilteredInventory.Batch,
	|	FilteredInventory.MeasurementUnit,
	|	Header.ReverseChargeApplies,
	|	FilteredInventory.Price
	|
	|UNION ALL
	|
	|SELECT
	|	Header.Ref,
	|	Header.DocumentNumber,
	|	Header.DocumentDate,
	|	Header.Company,
	|	Header.CompanyLogoFile,
	|	Header.Counterparty,
	|	Header.Contract,
	|	Header.CounterpartyContactPerson,
	|	Header.BankAccount,
	|	Header.AmountIncludesVAT,
	|	Header.DocumentCurrency,
	|	Header.ShipmentDate,
	|	SalesOrderWorks.LineNumber,
	|	CatalogProducts.SKU,
	|	CASE
	|		WHEN (CAST(SalesOrderWorks.Content AS STRING(1024))) <> """"
	|			THEN CAST(SalesOrderWorks.Content AS STRING(1024))
	|		WHEN (CAST(CatalogProducts.DescriptionFull AS STRING(1024))) <> """"
	|			THEN CAST(CatalogProducts.DescriptionFull AS STRING(1024))
	|		ELSE CatalogProducts.Description
	|	END,
	|	(CAST(SalesOrderWorks.Content AS STRING(1024))) <> """",
	|	CASE
	|		WHEN CatalogProducts.UseCharacteristics
	|			THEN CatalogCharacteristics.Description
	|		ELSE """"
	|	END,
	|	"""",
	|	CatalogProducts.UseSerialNumbers,
	|	SalesOrderWorks.ConnectionKey,
	|	CatalogUOMClassifier.Description,
	|	CAST(SalesOrderWorks.Quantity * SalesOrderWorks.Factor * SalesOrderWorks.Multiplicity AS NUMBER(15, 3)),
	|	SalesOrderWorks.Price,
	|	SalesOrderWorks.AutomaticDiscountAmount,
	|	SalesOrderWorks.DiscountMarkupPercent,
	|	SalesOrderWorks.Amount,
	|	SalesOrderWorks.VATRate,
	|	SalesOrderWorks.VATAmount,
	|	SalesOrderWorks.Total,
	|	CAST(SalesOrderWorks.Quantity * SalesOrderWorks.Price AS NUMBER(15, 2)),
	|	CatalogProducts.Ref,
	|	CatalogCharacteristics.Ref,
	|	VALUE(Catalog.ProductsBatches.EmptyRef),
	|	CatalogUOMClassifier.Ref,
	|	NULL
	|FROM
	|	Header AS Header
	|		INNER JOIN Document.SalesOrder.Works AS SalesOrderWorks
	|		ON Header.Ref = SalesOrderWorks.Ref
	|		LEFT JOIN Catalog.Products AS CatalogProducts
	|		ON (SalesOrderWorks.Products = CatalogProducts.Ref)
	|		LEFT JOIN Catalog.ProductsCharacteristics AS CatalogCharacteristics
	|		ON (SalesOrderWorks.Characteristic = CatalogCharacteristics.Ref)
	|		LEFT JOIN Catalog.UOMClassifier AS CatalogUOMClassifier
	|		ON (CatalogProducts.MeasurementUnit = CatalogUOMClassifier.Ref)
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
	|	Tabular.BankAccount AS BankAccount,
	|	Tabular.AmountIncludesVAT AS AmountIncludesVAT,
	|	Tabular.DocumentCurrency AS DocumentCurrency,
	|	Tabular.ShipmentDate AS ValidUntil,
	|	Tabular.LineNumber AS LineNumber,
	|	Tabular.SKU AS SKU,
	|	Tabular.ProductDescription AS ProductDescription,
	|	Tabular.ContentUsed AS ContentUsed,
	|	Tabular.UseSerialNumbers AS UseSerialNumbers,
	|	Tabular.ConnectionKey AS ConnectionKey,
	|	Tabular.Quantity AS Quantity,
	|	Tabular.Price AS Price,
	|	CASE
	|		WHEN Tabular.AutomaticDiscountAmount = 0
	|			THEN Tabular.DiscountMarkupPercent
	|		WHEN Tabular.Subtotal = 0
	|			THEN 0
	|		ELSE CAST((Tabular.Subtotal - Tabular.Amount) / Tabular.Subtotal * 100 AS NUMBER(15, 2))
	|	END AS DiscountRate,
	|	Tabular.Amount AS Amount,
	|	Tabular.VATRate AS VATRate,
	|	Tabular.VATAmount AS VATAmount,
	|	Tabular.Total AS Total,
	|	Tabular.Subtotal AS Subtotal,
	|	CAST(Tabular.Quantity * Tabular.Price - Tabular.Amount AS NUMBER(15, 2)) AS DiscountAmount,
	|	Tabular.CharacteristicDescription AS CharacteristicDescription,
	|	Tabular.BatchDescription AS BatchDescription,
	|	Tabular.Characteristic AS Characteristic,
	|	Tabular.Batch AS Batch,
	|	Tabular.UOM AS UOM,
	|	Tabular.ReverseChargeApplies AS ReverseChargeApplies,
	|	0 AS Variant
	|FROM
	|	Tabular AS Tabular
	|
	|ORDER BY
	|	DocumentNumber,
	|	LineNumber
	|TOTALS
	|	MAX(DocumentNumber),
	|	MAX(DocumentDate),
	|	MAX(Company),
	|	MAX(CompanyLogoFile),
	|	MAX(Counterparty),
	|	MAX(Contract),
	|	MAX(CounterpartyContactPerson),
	|	MAX(BankAccount),
	|	MAX(AmountIncludesVAT),
	|	MAX(DocumentCurrency),
	|	MAX(ValidUntil),
	|	COUNT(LineNumber),
	|	SUM(Quantity),
	|	SUM(VATAmount),
	|	SUM(Total),
	|	SUM(Subtotal),
	|	SUM(DiscountAmount),
	|	MAX(ReverseChargeApplies)
	|BY
	|	Ref,
	|	Variant";
	
	Return QueryText;
	
EndFunction

// Document printing procedure.
//
Function PrintQuote(ObjectsArray, PrintObjects, TemplateName) Export
	
	SpreadsheetDocument = New SpreadsheetDocument;
	SpreadsheetDocument.PrintParametersKey = "PrintParameters_Quote";
	
	Query = New Query();
	Query.SetParameter("ObjectsArray", ObjectsArray);
	Query.SetParameter("ReverseChargeAppliesRate", NStr("en = 'Reverse charge applies'"));
	Query.SetParameter("AllVariants", StrFind(TemplateName, "AllVariants") > 0);
	
	Query.Text = GetQueryText(ObjectsArray, TemplateName);
	ResultArray = Query.ExecuteBatch();
	
	FirstDocument = True;
	
	HeaderVariants = ResultArray[4].Select(QueryResultIteration.ByGroups);
	
	While HeaderVariants.Next() Do
		
		Header = HeaderVariants.Select(QueryResultIteration.ByGroups);
		While Header.Next() Do
			
			If Not FirstDocument Then
				SpreadsheetDocument.PutHorizontalPageBreak();
			EndIf;
			FirstDocument = False;
			
			FirstLineNumber = SpreadsheetDocument.TableHeight + 1;
			
			SpreadsheetDocument.PrintParametersName = "PRINT_PARAMETERS_Quote";
			
			Template = GetTemplate("PF_MXL_Quote");
			
			#Region PrintQuoteTitleArea
			
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
			
			#Region PrintQuoteCompanyInfoArea
			
			CompanyInfoArea = Template.GetArea("CompanyInfo");
			
			InfoAboutCompany = DriveServer.InfoAboutLegalEntityIndividual(Header.Company, Header.DocumentDate, ,Header.BankAccount);
			CompanyInfoArea.Parameters.Fill(InfoAboutCompany);
			
			SpreadsheetDocument.Put(CompanyInfoArea);
			
			#EndRegion
			
			#Region PrintQuoteCounterpartyInfoArea
			
			CounterpartyInfoArea = Template.GetArea("CounterpartyInfo");
			CounterpartyInfoArea.Parameters.Fill(Header);
			
			InfoAboutCounterparty = DriveServer.InfoAboutLegalEntityIndividual(Header.Counterparty, Header.DocumentDate, ,);
			CounterpartyInfoArea.Parameters.Fill(InfoAboutCounterparty);
			
			CounterpartyInfoArea.Parameters.PaymentTerms = PaymentTermsServer.TitlePaymentTerms(Header.Ref);
			
			SpreadsheetDocument.Put(CounterpartyInfoArea);
			
			#EndRegion
			
			#Region PrintQuoteCommentArea
			
			CommentArea = Template.GetArea("Comment");
			If CommonUse.IsObjectAttribute("TermsAndConditions", Header.Ref.Metadata()) Then
				CommentArea.Parameters.TermsAndConditions = CommonUse.ObjectAttributeValue(Header.Ref, "TermsAndConditions");
			Else
				CommentArea.Parameters.TermsAndConditions = CommonUse.ObjectAttributeValue(Header.Ref, "Comment");
			EndIf;
			
			SpreadsheetDocument.Put(CommentArea);
			
			#EndRegion
			
			#Region PrintQuoteTotalsAreaPrefill
			
			TotalsAreasArray = New Array;
			
			LineTotalArea = Template.GetArea("LineTotal");
			LineTotalArea.Parameters.Fill(Header);
			
			TotalsAreasArray.Add(LineTotalArea);
			
			#EndRegion
			
			#Region PrintQuoteLinesArea
			
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
				
				PrintManagement.ComplimentProductDescription(LineSectionArea.Parameters.ProductDescription, TabSelection);
				
				AreasToBeChecked = New Array;
				AreasToBeChecked.Add(LineSectionArea);
				For Each Area In TotalsAreasArray Do
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
			
			#EndRegion
			
			#Region PrintQuoteTotalsArea
			
			For Each Area In TotalsAreasArray Do
				
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
		
	EndDo;
	
	SpreadsheetDocument.FitToPage = True;
	
	Return SpreadsheetDocument;
	
EndFunction

// Document printing procedure
//
Function PrintProformaInvoice(ObjectsArray, PrintObjects, TemplateName) Export
	
	SpreadsheetDocument = New SpreadsheetDocument;
	SpreadsheetDocument.PrintParametersKey = "PrintParameters_ProformaInvoice";
	
	Query = New Query();
	Query.SetParameter("ObjectsArray", ObjectsArray);
	Query.SetParameter("AllVariants", StrFind(TemplateName, "AllVariants") > 0);
	
	Query.Text = GetQueryText(ObjectsArray, TemplateName);
	ResultArray = Query.ExecuteBatch();
	
	FirstDocument = True;
	
	HeaderVariants			= ResultArray[4].Select(QueryResultIteration.ByGroups);
	TaxesHeaderSelVariants	= ResultArray[5].Select(QueryResultIteration.ByGroups);
	TotalLineNumber			= ResultArray[6].Unload();
	
	While HeaderVariants.Next() Do
		
		Header = HeaderVariants.Select(QueryResultIteration.ByGroups);
		While Header.Next() Do
			
			If Not FirstDocument Then
				SpreadsheetDocument.PutHorizontalPageBreak();
			EndIf;
			FirstDocument = False;
			
			FirstLineNumber = SpreadsheetDocument.TableHeight + 1;
			
			SpreadsheetDocument.PrintParametersName = "PRINT_PARAMETERS_ProformaInvoice";
			
			Template = GetTemplate("PF_MXL_ProformaInvoice");
			
			#Region PrintProformaInvoiceTitleArea
			
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
			
			#Region PrintProformaInvoiceCompanyInfoArea
			
			CompanyInfoArea = Template.GetArea("CompanyInfo");
			
			InfoAboutCompany = DriveServer.InfoAboutLegalEntityIndividual(Header.Company, Header.DocumentDate, , Header.BankAccount);
			CompanyInfoArea.Parameters.Fill(InfoAboutCompany);
			
			SpreadsheetDocument.Put(CompanyInfoArea);
			
			#EndRegion
			
			#Region PrintProformaInvoiceCounterpartyInfoArea
			
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
			
			CounterpartyInfoArea.Parameters.PaymentTerms = PaymentTermsServer.TitlePaymentTerms(Header.Ref);
			
			SpreadsheetDocument.Put(CounterpartyInfoArea);
			
			#EndRegion
			
			#Region PrintProformaInvoiceCommentArea
			
			CommentArea = Template.GetArea("Comment");
			CommentArea.Parameters.Comment = CommonUse.ObjectAttributeValue(Header.Ref, "Comment");
			SpreadsheetDocument.Put(CommentArea);
			
			#EndRegion
			
			#Region PrintProformaInvoiceTotalsAndTaxesAreaPrefill
			
			TotalsAndTaxesAreasArray = New Array;
			
			LineTotalArea = Template.GetArea("LineTotal");
			LineTotalArea.Parameters.Fill(Header);
			
			LineTotalArea.Parameters.DiscountAmount = Header.Subtotal + Header.FreightTotal + Header.VATAmount - Header.Total;
			
			SearchStructure = New Structure("Ref, Variant", Header.Ref, Header.Variant);
			
			SearchArray = TotalLineNumber.FindRows(SearchStructure);
			If SearchArray.Count() > 0 Then
				LineTotalArea.Parameters.Quantity	= SearchArray[0].Quantity;
				LineTotalArea.Parameters.LineNumber	= SearchArray[0].LineNumber;
			Else
				LineTotalArea.Parameters.Quantity	= 0;
				LineTotalArea.Parameters.LineNumber	= 0;
			EndIf;
			
			TotalsAndTaxesAreasArray.Add(LineTotalArea);
			
			TaxesHeaderSelVariants.Reset();
			If TaxesHeaderSelVariants.FindNext(New Structure("Ref", Header.Ref)) Then
				
				TaxesHeaderSel = TaxesHeaderSelVariants.Select(QueryResultIteration.ByGroups);
				If TaxesHeaderSel.FindNext(New Structure("Variant", Header.Variant)) Then
					
					TaxSectionHeaderArea = Template.GetArea("TaxSectionHeader");
					TotalsAndTaxesAreasArray.Add(TaxSectionHeaderArea);
					
					TaxesSel = TaxesHeaderSel.Select();
					While TaxesSel.Next() Do
						
						TaxSectionLineArea = Template.GetArea("TaxSectionLine");
						TaxSectionLineArea.Parameters.Fill(TaxesSel);
						TotalsAndTaxesAreasArray.Add(TaxSectionLineArea);
						
					EndDo;
					
				EndIf;
				
			EndIf;
			
			#EndRegion
			
			#Region PrintProformaInvoiceLinesArea
			
			LineHeaderArea = Template.GetArea("LineHeader");
			SpreadsheetDocument.Put(LineHeaderArea);
			
			LineSectionArea	= Template.GetArea("LineSection");
			SeeNextPageArea	= Template.GetArea("SeeNextPage");
			EmptyLineArea	= Template.GetArea("EmptyLine");
			PageNumberArea	= Template.GetArea("PageNumber");
			
			PageNumber = 0;
			AreasToBeChecked = New Array;
			
			TabSelection = Header.Select();
			While TabSelection.Next() Do
				
				If TabSelection.IsFreightService Then
					Continue;
				EndIf;
				
				LineSectionArea.Parameters.Fill(TabSelection);
				
				PrintManagement.ComplimentProductDescription(LineSectionArea.Parameters.ProductDescription, TabSelection);
				
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
			
			#EndRegion
			
			#Region PrintProformaInvoiceTotalsAndTaxesArea
			
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
		
	EndDo;
	
	SpreadsheetDocument.FitToPage = True;
	
	Return SpreadsheetDocument;

EndFunction

#EndRegion

#EndIf