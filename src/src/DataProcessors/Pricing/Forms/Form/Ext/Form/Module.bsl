
#Region ServiceProceduresAndFunctions

&AtServer
Procedure FillPricesFirstTime(Period, ParameterPriceKind, ParameterPriceGroup, ParameterProducts)
	
	If ValueIsFilled(ParameterPriceKind) Then
	
		Query = New Query();
		Query.Text = 
		"SELECT
		|	PricesSliceLast.Products,
		|	PricesSliceLast.Characteristic,
		|	PricesSliceLast.Price AS OriginalPrice,
		|	PricesSliceLast.Price,
		|	PricesSliceLast.MeasurementUnit,
		|	TRUE AS Check
		|FROM
		|	InformationRegister.Prices.SliceLast(
		|			&Period,
		|			PriceKind = &PriceKind
		|				AND CASE
		|					WHEN &Products = UNDEFINED
		|							OR Products = &Products
		|						THEN TRUE
		|					ELSE FALSE
		|				END
		|				AND CASE
		|					WHEN &PriceGroup = UNDEFINED
		|							OR Products.PriceGroup = &PriceGroup
		|						THEN TRUE
		|					ELSE FALSE
		|				END AND Actuality) AS PricesSliceLast
		|
		|ORDER BY
		|	PricesSliceLast.Products.Description";
			
		Query.SetParameter("Period", Period);
		Query.SetParameter("PriceKind", ParameterPriceKind);
		Query.SetParameter("Products", ParameterProducts);
		Query.SetParameter("PriceGroup", ParameterPriceGroup);
		Prices.Load(Query.Execute().Unload());	
	
	Else
	
		If ValueIsFilled(ParameterProducts) OR ValueIsFilled(ParameterPriceGroup) Then
		
			Query = New Query();
			Query.Text = 
			"SELECT
			|	CatalogProducts.Ref AS Products,
			|	TRUE AS Check,
			|	CatalogProducts.MeasurementUnit
			|FROM
			|	Catalog.Products AS CatalogProducts
			|WHERE
			|	CASE
			|			WHEN &PriceGroup = UNDEFINED
			|					OR CatalogProducts.PriceGroup = &PriceGroup
			|				THEN TRUE
			|			ELSE FALSE
			|		END
			|	AND CASE
			|			WHEN &Products = UNDEFINED
			|					OR CatalogProducts.Ref = &Products
			|				THEN TRUE
			|			ELSE FALSE
			|		END
			|
			|ORDER BY
			|	CatalogProducts.Description";
				
			Query.SetParameter("Products", ParameterProducts);
			Query.SetParameter("PriceGroup", ParameterPriceGroup);
			Prices.Load(Query.Execute().Unload());		
		
		EndIf; 	
	
	EndIf;		
	
EndProcedure

&AtServer
Function GetProductsTable(Briefly = False)
	
	ProductsTable = New ValueTable;
	
	Array = New Array;
	
	Array.Add(Type("CatalogRef.Products"));
	TypeDescription = New TypeDescription(Array, ,);
	Array.Clear();

	ProductsTable.Columns.Add("Products", TypeDescription);
	
	Array.Add(Type("CatalogRef.ProductsCharacteristics"));
	TypeDescription = New TypeDescription(Array, ,);
	Array.Clear();

	ProductsTable.Columns.Add("Characteristic", TypeDescription);
	
	If Not Briefly Then
	
		Array.Add(Type("Boolean"));
		TypeDescription = New TypeDescription(Array, ,);
		Array.Clear();

		ProductsTable.Columns.Add("Check", TypeDescription);
		
		Array.Add(Type("CatalogRef.UOM"));
		Array.Add(Type("CatalogRef.UOMClassifier"));
		TypeDescription = New TypeDescription(Array, ,);
		Array.Clear();

		ProductsTable.Columns.Add("MeasurementUnit", TypeDescription);
		
		NQ = New NumberQualifiers(15,2);
		Array.Add(Type("Number"));
		TypeDescription = New TypeDescription(Array, , , NQ);

		ProductsTable.Columns.Add("Price", TypeDescription);
		
		Array.Add(Type("Number"));
		TypeDescription = New TypeDescription(Array, , );

		ProductsTable.Columns.Add("Factor", TypeDescription);	
	
	EndIf; 
	
	For Each TSRow In Prices Do
		
		If Not ValueIsFilled(TSRow.Products) Then
			
			Continue;
			
		EndIf; 
		
		NewRow = ProductsTable.Add();
		FillPropertyValues(NewRow, TSRow);
		
		If Not Briefly Then
			
			If TypeOf(TSRow.MeasurementUnit) = Type("CatalogRef.UOMClassifier") Then
				NewRow.Factor = 1;
			Else
				NewRow.Factor = TSRow.MeasurementUnit.Factor;
			EndIf;
			
		EndIf; 
		
	EndDo;
	
	Return ProductsTable;

EndFunction

&AtServer
Procedure AddProducts(ProductsTable)
	
	For Each TableRow In ProductsTable Do
		
		NewRow = Prices.Add();
		FillPropertyValues(NewRow, TableRow);
		NewRow.OriginalPrice = TableRow.Price;
		
	EndDo;
	
EndProcedure

&AtServer
Procedure AddByPriceTypesAtServer(ValueSelected, ToDate, PriceFilled, UseCharacteristics = False)
	
	DynamicPriceKind	= ValueSelected.CalculatesDynamically;
	ParameterPriceKind		= ?(DynamicPriceKind, ValueSelected.PricesBaseKind, ValueSelected);
	
	Query = New Query();
	
	Query.Text = DataProcessors.Pricing.QueryTextForAddingByPriceKind(PriceFilled, UseCharacteristics);
	
	CurrencySource = ?(ValueIsFilled(ParameterPriceKind.PriceCurrency), ValueSelected.PriceCurrency, FunctionalCurrency);
	CurrencyOfReceiver = ?(ValueIsFilled(PriceKindInstallation.PriceCurrency), PriceKindInstallation.PriceCurrency, FunctionalCurrency);
	
	Query.SetParameter("ToDate", ToDate);
	Query.SetParameter("PriceKind", ParameterPriceKind);
	Query.SetParameter("CurrencySource",CurrencySource);
	Query.SetParameter("CurrencyOfReceiver",CurrencyOfReceiver);
	Query.SetParameter("ProductsTable", GetProductsTable(True));
	
	ResultTable = Query.Execute().Unload();
	
	If DynamicPriceKind AND ResultTable.Count() > 0 Then
		
		Markup 					= ValueSelected.Percent;
		RoundingOrder			= ValueSelected.RoundingOrder;
		RoundUp	= ValueSelected.RoundUp;
	
		For Each TableRow In ResultTable Do
			
			TableRow.Price = TableRow.Price * (1 + Markup / 100);
			
		EndDo; 
	
	EndIf; 
	
	AddProducts(ResultTable);
	
EndProcedure

&AtServer
Procedure AddByPriceGroupsAtServer(ValueSelected, UseCharacteristics = False)
	
	Query = New Query();
	Query.Text = 
	"SELECT
	|	ProductsTable.Products AS Products,
	|	ProductsTable.Characteristic AS Characteristic,
	|	ProductsTable.MeasurementUnit AS MeasurementUnit,
	|	TRUE AS IsInTable
	|INTO ProductsTable
	|FROM
	|	&ProductsTable AS ProductsTable
	|
	|INDEX BY
	|	ProductsTable.Products,
	|	ProductsTable.Characteristic
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CatalogProducts.Ref AS Products,
	|	VALUE(Catalog.ProductsCharacteristics.EmptyRef) AS Characteristic,
	|	CatalogProducts.MeasurementUnit AS MeasurementUnit,
	|	FALSE AS IsInTable
	|INTO NewProducts
	|FROM
	|	Catalog.Products AS CatalogProducts
	|WHERE
	|	CatalogProducts.PriceGroup IN(&PriceGroups)
	|
	|INDEX BY
	|	CatalogProducts.Ref,
	|	VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ProductsCharacteristics.Owner AS Products,
	|	ProductsCharacteristics.Ref AS Characteristic,
	|	ProductsCharacteristics.Owner.MeasurementUnit AS MeasurementUnit,
	|	FALSE AS IsInTable
	|INTO NewCharacteristics
	|FROM
	|	Catalog.ProductsCharacteristics AS ProductsCharacteristics
	|WHERE
	|	ProductsCharacteristics.Owner.PriceGroup IN(&PriceGroups)
	|	AND &UseCharacteristics
	|
	|INDEX BY
	|	ProductsCharacteristics.Owner,
	|	ProductsCharacteristics.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ProductsTable.Products,
	|	ProductsTable.Characteristic,
	|	ProductsTable.MeasurementUnit,
	|	ProductsTable.IsInTable
	|INTO TemporaryTableOfAllProducts
	|FROM
	|	ProductsTable AS ProductsTable
	|
	|UNION ALL
	|
	|SELECT
	|	NewProducts.Products,
	|	NewProducts.Characteristic,
	|	NewProducts.MeasurementUnit,
	|	NewProducts.IsInTable
	|FROM
	|	NewProducts AS NewProducts
	|
	|UNION ALL
	|
	|SELECT
	|	NewCharacteristics.Products,
	|	NewCharacteristics.Characteristic,
	|	NewCharacteristics.MeasurementUnit,
	|	NewCharacteristics.IsInTable
	|FROM
	|	NewCharacteristics AS NewCharacteristics
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TRUE AS Check,
	|	ProductsTableWithPrices.Products,
	|	ProductsTableWithPrices.Characteristic,
	|	ProductsTableWithPrices.MeasurementUnit,
	|	Prices.Price AS Price,
	|	MAX(ProductsTableWithPrices.IsInTable) AS IsInTable
	|FROM
	|	TemporaryTableOfAllProducts AS ProductsTableWithPrices
	|		LEFT JOIN InformationRegister.Prices.SliceLast(
	|				&Period,
	|				Actuality
	|					AND PriceKind = &PriceKind) AS Prices
	|		ON ProductsTableWithPrices.Products = Prices.Products
	|			AND ProductsTableWithPrices.Characteristic = Prices.Characteristic
	|
	|GROUP BY
	|	ProductsTableWithPrices.Products,
	|	ProductsTableWithPrices.Characteristic,
	|	ProductsTableWithPrices.MeasurementUnit,
	|	Prices.Price
	|
	|HAVING
	|	MAX(ProductsTableWithPrices.IsInTable) = FALSE
	|
	|ORDER BY
	|	ProductsTableWithPrices.Products.Description,
	|	ProductsTableWithPrices.Characteristic.Description";
	
	Query.SetParameter("Period",					InstallationPeriod);
	Query.SetParameter("PriceKind",					PriceKindInstallation);
	Query.SetParameter("PriceGroups",			ValueSelected);
	Query.SetParameter("ProductsTable",	GetProductsTable(False));
	Query.SetParameter("UseCharacteristics", UseCharacteristics);
	
	AddProducts(Query.Execute().Unload());
	
EndProcedure

&AtServer
Procedure AddByProductsCategoriesAtServer(ValueSelected, UseCharacteristics = False)
	
	Query = New Query();
	Query.Text = 
	"SELECT
	|	ProductsTable.Products AS Products,
	|	ProductsTable.Characteristic AS Characteristic,
	|	ProductsTable.MeasurementUnit AS MeasurementUnit,
	|	TRUE AS IsInTable
	|INTO ProductsTable
	|FROM
	|	&ProductsTable AS ProductsTable
	|
	|INDEX BY
	|	ProductsTable.Products,
	|	ProductsTable.Characteristic
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CatalogProducts.Ref AS Products,
	|	VALUE(Catalog.ProductsCharacteristics.EmptyRef) AS Characteristic,
	|	CatalogProducts.MeasurementUnit AS MeasurementUnit,
	|	FALSE AS IsInTable
	|INTO NewProducts
	|FROM
	|	Catalog.Products AS CatalogProducts
	|WHERE
	|	CatalogProducts.Ref IN HIERARCHY(&ProductsGroup)
	|	AND Not CatalogProducts.IsFolder
	|
	|INDEX BY
	|	CatalogProducts.Ref,
	|	VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ProductsCharacteristics.Owner AS Products,
	|	ProductsCharacteristics.Ref AS Characteristic,
	|	ProductsCharacteristics.Owner.MeasurementUnit AS MeasurementUnit,
	|	FALSE AS IsInTable
	|INTO NewCharacteristics
	|FROM
	|	Catalog.ProductsCharacteristics AS ProductsCharacteristics
	|WHERE
	|	ProductsCharacteristics.Owner IN HIERARCHY(&ProductsGroup)
	|	AND &UseCharacteristics
	|
	|INDEX BY
	|	ProductsCharacteristics.Owner,
	|	ProductsCharacteristics.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ProductsTable.Products,
	|	ProductsTable.Characteristic,
	|	ProductsTable.MeasurementUnit,
	|	ProductsTable.IsInTable
	|INTO TemporaryTableOfAllProducts
	|FROM
	|	ProductsTable AS ProductsTable
	|
	|UNION ALL
	|
	|SELECT
	|	NewProducts.Products,
	|	NewProducts.Characteristic,
	|	NewProducts.MeasurementUnit,
	|	NewProducts.IsInTable
	|FROM
	|	NewProducts AS NewProducts
	|
	|UNION ALL
	|
	|SELECT
	|	NewCharacteristics.Products,
	|	NewCharacteristics.Characteristic,
	|	NewCharacteristics.MeasurementUnit,
	|	NewCharacteristics.IsInTable
	|FROM
	|	NewCharacteristics AS NewCharacteristics
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TRUE AS Check,
	|	ProductsTableWithPrices.Products,
	|	ProductsTableWithPrices.Characteristic,
	|	ProductsTableWithPrices.MeasurementUnit,
	|	Prices.Price AS Price,
	|	MAX(ProductsTableWithPrices.IsInTable) AS IsInTable
	|FROM
	|	TemporaryTableOfAllProducts AS ProductsTableWithPrices
	|		LEFT JOIN InformationRegister.Prices.SliceLast(
	|				&Period,
	|				Actuality
	|					AND PriceKind = &PriceKind) AS Prices
	|		ON ProductsTableWithPrices.Products = Prices.Products
	|			AND ProductsTableWithPrices.Characteristic = Prices.Characteristic
	|
	|GROUP BY
	|	ProductsTableWithPrices.Products,
	|	ProductsTableWithPrices.Characteristic,
	|	ProductsTableWithPrices.MeasurementUnit,
	|	Prices.Price
	|
	|HAVING
	|	MAX(ProductsTableWithPrices.IsInTable) = FALSE
	|
	|ORDER BY
	|	ProductsTableWithPrices.Products.Description,
	|	ProductsTableWithPrices.Characteristic.Description";
	
	Query.SetParameter("Period",					InstallationPeriod);
	Query.SetParameter("PriceKind",					PriceKindInstallation);
	Query.SetParameter("ProductsGroup",		ValueSelected);
	Query.SetParameter("ProductsTable",	GetProductsTable(False));
	Query.SetParameter("UseCharacteristics", UseCharacteristics);
	
	AddProducts(Query.Execute().Unload());
	
EndProcedure

&AtServer
Procedure AddByReceiptInvoiceAtServer(ValueSelected)
	
	Query = New Query();
	Query.Text = 
	"SELECT
	|	ProductsTable.Products AS Products,
	|	ProductsTable.Characteristic AS Characteristic
	|INTO ProductsTable
	|FROM
	|	&ProductsTable AS ProductsTable
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MAX(ExchangeRates.Period) AS Period,
	|	ExchangeRates.ExchangeRate AS ExchangeRate,
	|	ExchangeRates.Multiplicity AS Multiplicity
	|INTO PriceKindCurrencyRate
	|FROM
	|	InformationRegister.ExchangeRates.SliceLast(&Period, Currency = &CurrencyPriceKind) AS ExchangeRates
	|
	|GROUP BY
	|	ExchangeRates.ExchangeRate,
	|	ExchangeRates.Multiplicity
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TRUE AS Check,
	|	SupplierInvoiceInventory.Products AS Products,
	|	SupplierInvoiceInventory.Characteristic AS Characteristic,
	|	SupplierInvoiceInventory.MeasurementUnit,
	|	CASE
	|		WHEN &CurrencyPriceKind <> SupplierInvoiceInventory.Ref.DocumentCurrency
	|			THEN SupplierInvoiceInventory.Price * SupplierInvoiceInventory.Ref.ExchangeRate * PriceKindCurrencyRate.Multiplicity / PriceKindCurrencyRate.ExchangeRate * SupplierInvoiceInventory.Ref.Multiplicity
	|		ELSE SupplierInvoiceInventory.Price
	|	END AS Price
	|FROM
	|	Document.SupplierInvoice.Inventory AS SupplierInvoiceInventory,
	|	PriceKindCurrencyRate AS PriceKindCurrencyRate
	|WHERE
	|	SupplierInvoiceInventory.Ref = &SupplierInvoice
	|	AND Not (SupplierInvoiceInventory.Products, SupplierInvoiceInventory.Characteristic) In
	|				(SELECT
	|					Table.Products,
	|					Table.Characteristic
	|				FROM
	|					ProductsTable AS Table)
	|
	|ORDER BY
	|	SupplierInvoiceInventory.LineNumber";
	
	CurrencyPriceKind = ?(ValueIsFilled(PriceKindInstallation.PriceCurrency), PriceKindInstallation.PriceCurrency, FunctionalCurrency);
	
	Query.SetParameter("CurrencyPriceKind", CurrencyPriceKind);
	Query.SetParameter("Period", ValueSelected.Date);
	Query.SetParameter("SupplierInvoice", ValueSelected);
	Query.SetParameter("ProductsTable", GetProductsTable(True));
	
	AddProducts(Query.Execute().Unload());
	
EndProcedure

#Region FillingPrices

&AtServer
Procedure PlacePrices(PricesTable)

	For Each TabularSectionRow In Prices Do
		
		If Not TabularSectionRow.Check Then
			Continue;		
		EndIf; 
		
		SearchStructure = New Structure;
		SearchStructure.Insert("Products",	 TabularSectionRow.Products);
		SearchStructure.Insert("Characteristic",	 TabularSectionRow.Characteristic);
		SearchStructure.Insert("MeasurementUnit", TabularSectionRow.MeasurementUnit);
		
		SearchResult = PricesTable.FindRows(SearchStructure);
		If SearchResult.Count() > 0 Then			
			TabularSectionRow.Price = SearchResult[0].Price;
		EndIf;
		
	EndDo;	

EndProcedure

&AtServer
Procedure FillPricesByPriceKindAtServer()
	
	Query = New Query();
	Query.Text = 
	"SELECT
	|	ProductsTable.Products AS Products,
	|	ProductsTable.Characteristic AS Characteristic,
	|	ProductsTable.MeasurementUnit AS MeasurementUnit,
	|	ProductsTable.Factor AS Factor,
	|	ProductsTable.Check AS Check
	|INTO ProductsTable
	|FROM
	|	&ProductsTable AS ProductsTable
	|WHERE
	|	ProductsTable.Check
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ProductsTable.Products AS Products,
	|	ProductsTable.Characteristic AS Characteristic,
	|	CASE
	|		WHEN PricesSliceLast.Actuality
	|			THEN ISNULL(PricesSliceLast.Price * RateCurrencyTypePrices.ExchangeRate * CurrencyRateOfPriceKindInstallation.Multiplicity / (CurrencyRateOfPriceKindInstallation.ExchangeRate * RateCurrencyTypePrices.Multiplicity) * ISNULL(ProductsTable.Factor, 1) / ISNULL(PricesSliceLast.MeasurementUnit.Factor, 1), 0)
	|		ELSE 0
	|	END AS Price,
	|	ProductsTable.MeasurementUnit
	|FROM
	|	ProductsTable AS ProductsTable
	|		LEFT JOIN InformationRegister.Prices.SliceLast(
	|				&ToDate,
	|				PriceKind = &PriceKind
	|					AND (Products, Characteristic) In
	|						(SELECT
	|							Table.Products,
	|							Table.Characteristic
	|						FROM
	|							ProductsTable AS Table)) AS PricesSliceLast
	|		ON ProductsTable.Products = PricesSliceLast.Products
	|			AND ProductsTable.Characteristic = PricesSliceLast.Characteristic
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&ToDate, ) AS RateCurrencyTypePrices
	|		ON (PricesSliceLast.PriceKind.PriceCurrency = RateCurrencyTypePrices.Currency),
	|	InformationRegister.ExchangeRates.SliceLast(&ToDate, Currency = &Currency) AS CurrencyRateOfPriceKindInstallation";
		
	Query.SetParameter("ToDate", Period);
	Query.SetParameter("PriceKind", PriceKind);
	Query.SetParameter("Currency", PriceKindInstallation.PriceCurrency);
	Query.SetParameter("ProductsTable", GetProductsTable());
	PlacePrices(Query.Execute().Unload());	
	
EndProcedure

&AtServer
Procedure FillPricesBySupplierPriceTypesAtServer()
	
	Query = New Query();
	Query.Text = 
	"SELECT
	|	ProductsTable.Products AS Products,
	|	ProductsTable.Characteristic AS Characteristic,
	|	ProductsTable.MeasurementUnit AS MeasurementUnit,
	|	ProductsTable.Factor AS Factor,
	|	ProductsTable.Check AS Check
	|INTO ProductsTable
	|FROM
	|	&ProductsTable AS ProductsTable
	|WHERE
	|	ProductsTable.Check
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ProductsTable.Products AS Products,
	|	ProductsTable.Characteristic AS Characteristic,
	|	CASE
	|		WHEN CounterpartyPricesSliceLast.Actuality
	|			THEN ISNULL(CounterpartyPricesSliceLast.Price * RateCurrencyTypePrices.ExchangeRate * CurrencyRateOfPriceKindInstallation.Multiplicity / (CurrencyRateOfPriceKindInstallation.ExchangeRate * RateCurrencyTypePrices.Multiplicity) * ISNULL(ProductsTable.Factor, 1) / ISNULL(CounterpartyPricesSliceLast.MeasurementUnit.Factor, 1), 0)
	|		ELSE 0
	|	END AS Price,
	|	ProductsTable.MeasurementUnit
	|FROM
	|	ProductsTable AS ProductsTable
	|		LEFT JOIN InformationRegister.CounterpartyPrices.SliceLast(
	|				&ToDate,
	|				SupplierPriceTypes = &SupplierPriceTypes
	|					AND (Products, Characteristic) In
	|						(SELECT
	|							Table.Products,
	|							Table.Characteristic
	|						FROM
	|							ProductsTable AS Table)) AS CounterpartyPricesSliceLast
	|		ON ProductsTable.Products = CounterpartyPricesSliceLast.Products
	|			AND ProductsTable.Characteristic = CounterpartyPricesSliceLast.Characteristic
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&ToDate, ) AS RateCurrencyTypePrices
	|		ON (CounterpartyPricesSliceLast.SupplierPriceTypes.PriceCurrency = RateCurrencyTypePrices.Currency),
	|	InformationRegister.ExchangeRates.SliceLast(&ToDate, Currency = &Currency) AS CurrencyRateOfPriceKindInstallation";
		
	Query.SetParameter("ToDate", Period);
	Query.SetParameter("SupplierPriceTypes", SupplierPriceTypes);
	Query.SetParameter("Currency", PriceKindInstallation.PriceCurrency);
	Query.SetParameter("ProductsTable", GetProductsTable());
	PlacePrices(Query.Execute().Unload());	
	
EndProcedure

&AtServer
Procedure FillPricesByReceiptInvoiceAtServer()
	
	Query = New Query();
	Query.Text = 
	"SELECT
	|	ProductsTable.Products AS Products,
	|	ProductsTable.Characteristic AS Characteristic,
	|	ProductsTable.MeasurementUnit AS MeasurementUnit,
	|	ProductsTable.Factor AS Factor,
	|	ProductsTable.Check AS Check
	|INTO ProductsTable
	|FROM
	|	&ProductsTable AS ProductsTable
	|WHERE
	|	ProductsTable.Check
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ProductsTable.Products AS Products,
	|	ProductsTable.Characteristic AS Characteristic,
	|	ISNULL(SupplierInvoiceInventory.Price * RateCurrencyTypePrices.ExchangeRate * CurrencyRateOfPriceKindInstallation.Multiplicity / (CurrencyRateOfPriceKindInstallation.ExchangeRate * RateCurrencyTypePrices.Multiplicity) * ISNULL(ProductsTable.Factor, 1) / ISNULL(SupplierInvoiceInventory.MeasurementUnit.Factor, 1), 0) AS Price,
	|	ProductsTable.MeasurementUnit
	|FROM
	|	ProductsTable AS ProductsTable
	|		LEFT JOIN Document.SupplierInvoice.Inventory AS SupplierInvoiceInventory
	|		ON ProductsTable.Products = SupplierInvoiceInventory.Products
	|			AND ProductsTable.Characteristic = SupplierInvoiceInventory.Characteristic
	|			AND (SupplierInvoiceInventory.Ref = &SupplierInvoice)
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&ToDate, ) AS RateCurrencyTypePrices
	|		ON (SupplierInvoiceInventory.Ref.DocumentCurrency = RateCurrencyTypePrices.Currency),
	|	InformationRegister.ExchangeRates.SliceLast(&ToDate, Currency = &Currency) AS CurrencyRateOfPriceKindInstallation";
		
	Query.SetParameter("ToDate", Period);
	Query.SetParameter("SupplierInvoice", SupplierInvoice);
	Query.SetParameter("Currency", PriceKindInstallation.PriceCurrency);
	Query.SetParameter("ProductsTable", GetProductsTable());
	PlacePrices(Query.Execute().Unload());
	
EndProcedure

&AtServer
Procedure CalculateByBasicPriceKindAtServer()
	
	Query = New Query();
	Query.Text = 
	"SELECT
	|	ProductsTable.Products AS Products,
	|	ProductsTable.Characteristic AS Characteristic,
	|	ProductsTable.MeasurementUnit AS MeasurementUnit,
	|	ProductsTable.Factor AS Factor,
	|	ProductsTable.Check AS Check
	|INTO ProductsTable
	|FROM
	|	&ProductsTable AS ProductsTable
	|WHERE
	|	ProductsTable.Check
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ProductsTable.Products AS Products,
	|	ProductsTable.Characteristic AS Characteristic,
	|	CASE
	|		WHEN PricesSliceLast.Actuality
	|			THEN ISNULL(PricesSliceLast.Price * (1 + &Markup / 100) * RateCurrencyTypePrices.ExchangeRate * CurrencyRateOfPriceKindInstallation.Multiplicity / (CurrencyRateOfPriceKindInstallation.ExchangeRate * RateCurrencyTypePrices.Multiplicity) * ISNULL(ProductsTable.Factor, 1) / ISNULL(PricesSliceLast.MeasurementUnit.Factor, 1), 0)
	|		ELSE 0
	|	END AS Price,
	|	ProductsTable.MeasurementUnit
	|FROM
	|	ProductsTable AS ProductsTable
	|		LEFT JOIN InformationRegister.Prices.SliceLast(
	|				&ToDate,
	|				PriceKind = &PriceKind
	|					AND (Products, Characteristic) In
	|						(SELECT
	|							Table.Products,
	|							Table.Characteristic
	|						FROM
	|							ProductsTable AS Table)) AS PricesSliceLast
	|		ON ProductsTable.Products = PricesSliceLast.Products
	|			AND ProductsTable.Characteristic = PricesSliceLast.Characteristic
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&ToDate, ) AS RateCurrencyTypePrices
	|		ON (PricesSliceLast.PriceKind.PriceCurrency = RateCurrencyTypePrices.Currency),
	|	InformationRegister.ExchangeRates.SliceLast(&ToDate, Currency = &Currency) AS CurrencyRateOfPriceKindInstallation";
		
	Query.SetParameter("ToDate", Period);
	Query.SetParameter("PriceKind", PricesBaseKind);
	Query.SetParameter("Currency", PriceKindInstallation.PriceCurrency);
	Query.SetParameter("Markup", Markup);
	Query.SetParameter("ProductsTable", GetProductsTable());
	PlacePrices(Query.Execute().Unload());	
	
EndProcedure

&AtClient
Procedure ChangeForPercentAtClient()
	
	For Each TSRow In Prices Do
		
		If TSRow.Check Then
			
			If PlusMinus = "+" Then
				Price = TSRow.Price * (1 + Percent / 100);
			Else
				Price = TSRow.Price * (1 - Percent / 100);
			EndIf;
			
			TSRow.Price = Price;
			
		EndIf;
	
	EndDo;
	
EndProcedure

&AtClient
Procedure ChangeForAmountAtClient()
	
	For Each TSRow In Prices Do
		
		If TSRow.Check Then
			
			If PlusMinus = "+" Then
				Price = TSRow.Price + Amount;
			Else
				Price = TSRow.Price - Amount;
			EndIf;
			
			TSRow.Price = Price;
			
		EndIf;
	
	EndDo;
	
EndProcedure

&AtClient
Procedure RoundAtClient()
	
	For Each TSRow In Prices Do
		
		TSRow.Price = DriveClientServer.RoundPrice(TSRow.Price, RoundingOrder, RoundUp);
		
	EndDo;	
	
EndProcedure

&AtServer
Procedure RemoveActualityAtServer()
	
	SetupAtServer(True);
	
EndProcedure

&AtServer
Procedure DeletePriceListRecordsAtServer()
	
	Query = New Query();
	Query.Text = "SELECT
	               |	ProductsTable.Products AS Products,
	               |	ProductsTable.Characteristic AS Characteristic,
	               |	ProductsTable.Check AS Check
	               |INTO ProductsTable
	               |FROM
	               |	&ProductsTable AS ProductsTable
	               |WHERE
	               |	ProductsTable.Check
	               |;
	               |
	               |////////////////////////////////////////////////////////////////////////////////
	               |SELECT
	               |	PricesSliceLast.Products AS Products,
	               |	PricesSliceLast.Characteristic AS Characteristic,
	               |	PricesSliceLast.Period
	               |FROM
	               |	InformationRegister.Prices.SliceLast(
	               |			&ToDate,
	               |			PriceKind = &PriceKind
	               |				AND (Products, Characteristic) IN
	               |					(SELECT
	               |						Table.Products,
	               |						Table.Characteristic
	               |					FROM
	               |						ProductsTable AS Table)) AS PricesSliceLast";
		
	Query.SetParameter("PriceKind", PriceKindInstallation);
	Query.SetParameter("ToDate", InstallationPeriod);
	Query.SetParameter("ProductsTable", GetProductsTable());
	
	Selection = Query.Execute().Select();
    	
	While Selection.Next() Do
	
		RecordSet = InformationRegisters.Prices.CreateRecordSet();
		RecordSet.Filter.Period.Set(Selection.Period);
		RecordSet.Filter.PriceKind.Set(PriceKindInstallation);
		RecordSet.Filter.Products.Set(Selection.Products);
		RecordSet.Filter.Characteristic.Set(Selection.Characteristic);
		
		RecordSet.Write();
		
		FilterStructure = New Structure;
		FilterStructure.Insert("Products", Selection.Products);
		FilterStructure.Insert("Characteristic", Selection.Characteristic);
		FilterStructure.Insert("Check", True);
		RowArray = Prices.FindRows(FilterStructure);
		
		For Each FoundString In RowArray Do			
			FoundString.Picture = 1;
		EndDo;
			
	EndDo;	
	
EndProcedure

#EndRegion

#Region PricesSettings

&AtServer
Procedure SetupAtServer(RemoveActuality = False)
	
	Query = New Query();
	
	Query.Text = 
	"SELECT
	|	ProductsTable.Products AS Products,
	|	ProductsTable.Characteristic AS Characteristic,
	|	ProductsTable.MeasurementUnit AS MeasurementUnit,
	|	ProductsTable.Price AS Price,
	|	ProductsTable.Check AS Check
	|INTO ProductsTable
	|FROM
	|	&ProductsTable AS ProductsTable
	|;
	|	
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ProductsTable.Products AS Products,
	|	ProductsTable.Characteristic AS Characteristic,
	|	ProductsTable.MeasurementUnit AS MeasurementUnit,
	|	ProductsTable.Price AS Price,
	|	CASE
	|		WHEN Prices.PriceKind IS NULL 
	|			THEN FALSE
	|		ELSE TRUE
	|	END AS double,
	|	MAX(ProductAndServicesPricesPeriods.Period) AS ProductsPricePeriod
	|FROM
	|	ProductsTable AS ProductsTable
	|		LEFT JOIN InformationRegister.Prices AS Prices
	|		ON ProductsTable.Products = Prices.Products
	|			AND ProductsTable.Characteristic = Prices.Characteristic
	|			AND (Prices.PriceKind = &PriceKind)
	|			AND (Prices.Period = &ToDate)
	|		LEFT JOIN InformationRegister.Prices AS ProductAndServicesPricesPeriods
	|		ON ProductsTable.Products = ProductAndServicesPricesPeriods.Products
	|			AND ProductsTable.Characteristic = ProductAndServicesPricesPeriods.Characteristic
	|			AND (ProductAndServicesPricesPeriods.PriceKind = &PriceKind)
	|			AND (ProductAndServicesPricesPeriods.Period < &ToDate)
	|WHERE
	|	ProductsTable.Check
	|	
	|GROUP BY
	|	ProductsTable.Products,
	|	ProductsTable.Characteristic,
	|	ProductsTable.MeasurementUnit,
	|	ProductsTable.Price,
	|	CASE
	|		WHEN Prices.PriceKind IS NULL 
	|			THEN FALSE
	|		ELSE TRUE
	|	END
	|;
	|	
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	NestedSelect.Products,
	|	NestedSelect.Characteristic,
	|	NestedSelect.Counter
	|FROM
	|	(SELECT
	|		ProductsTable.Products AS Products,
	|		ProductsTable.Characteristic AS Characteristic,
	|		SUM(1) AS Counter
	|	FROM
	|		ProductsTable AS ProductsTable
	|	WHERE
	|		ProductsTable.Check
	|	
	|	GROUP BY
	|		ProductsTable.Characteristic,
	|		ProductsTable.Products) AS NestedSelect
	|WHERE
	|	NestedSelect.Counter > 1";
		
	Query.SetParameter("PriceKind", PriceKindInstallation);
	Query.SetParameter("ToDate", InstallationPeriod);
	Query.SetParameter("ProductsTable", GetProductsTable());
	
	ResultsArray = Query.ExecuteBatch();
	
	// Duplication check. If duplicates exist - cancel!
	Selection = ResultsArray[2].Select();
	Cancel = False;
	
	While Selection.Next() Do
		
		Message = New UserMessage();
		Message.Text = NStr("en = 'The string %Products%%Charachteristic% is duplicated.'");
		Message.Text = StrReplace(Message.Text, "%Products%", Selection.Products);
		Message.Text = StrReplace(Message.Text, "%Characteristic%", ?(ValueIsFilled(Selection.Characteristic), 
										(" (" + Selection.Characteristic + ")"), ""));
		Message.Message();
		Cancel = True;
		
	EndDo;
	
	If Cancel Then
		Message = New UserMessage();
		Message.Text = NStr("en = 'Price setup canceled.'");
		Message.Message();
		Return;
	EndIf;
	
	// Price setting
	Selection = ResultsArray[1].Select();
	
	While Selection.Next() Do
		
		If Selection.double Then
			
			Message = New UserMessage();
			Message.Text = NStr("en = 'Price for products %Products%%Characteristic% on %ToDate% is already set. The new price is not written.'");
			Message.Text = StrReplace(Message.Text, "%ToDate%", Format(InstallationPeriod, "DF=dd.MM.yy"));
			Message.Text = StrReplace(Message.Text, "%Products%", Selection.Products);
			Message.Text = StrReplace(Message.Text, "%Characteristic%", ?(ValueIsFilled(Selection.Characteristic), 
										 (" (" + Selection.Characteristic + ")"), ""));
			Message.Message();
			
			FilterStructure = New Structure;
			FilterStructure.Insert("Products", Selection.Products);
			FilterStructure.Insert("Characteristic", Selection.Characteristic);
			FilterStructure.Insert("Check", True);
			RowArray = Prices.FindRows(FilterStructure);
			
			For Each FoundString In RowArray Do
				FoundString.Picture = 2;
			EndDo;
		
		ElsIf Not ValueIsFilled(Selection.Price) AND (NOT RemoveActuality) Then
			
			Message = New UserMessage();
			Message.Text = NStr("en = 'Price for products %Products%%Characteristic% is not specified.'");
			Message.Text = StrReplace(Message.Text, "%Products%", Selection.Products);
			Message.Text = StrReplace(Message.Text, "%Characteristic%", ?(ValueIsFilled(Selection.Characteristic), 
										 (" (" + Selection.Characteristic + ")"), ""));
			Message.Message();
			
			FilterStructure = New Structure;
			FilterStructure.Insert("Products", Selection.Products);
			FilterStructure.Insert("Characteristic", Selection.Characteristic);
			FilterStructure.Insert("Check", True);
			RowArray = Prices.FindRows(FilterStructure);
			
			For Each FoundString In RowArray Do
				FoundString.Picture = 2;
			EndDo;
			
		ElsIf RemoveActuality Then
			
			RecordManager = InformationRegisters.Prices.CreateRecordManager();
			RecordManager.Author = Users.AuthorizedUser();
			RecordManager.Actuality = False;
			RecordManager.PriceKind = PriceKindInstallation;
			RecordManager.MeasurementUnit = Selection.MeasurementUnit;
			RecordManager.Products = Selection.Products;
			
			If ValueIsFilled(Selection.ProductsPricePeriod) Then
				
				RecordManager.Period = Selection.ProductsPricePeriod;
				
			Else
				
				RecordManager.Period = InstallationPeriod;
				
			EndIf;
			
			RecordManager.Characteristic = Selection.Characteristic;
			RecordManager.Price = Selection.Price;
			RecordManager.Write(True);
			
			FilterStructure = New Structure;
			FilterStructure.Insert("Products", Selection.Products);
			FilterStructure.Insert("Characteristic", Selection.Characteristic);
			FilterStructure.Insert("Check", True);
			RowArray = Prices.FindRows(FilterStructure);
			
			For Each FoundString In RowArray Do
				
				FoundString.Picture = 1;
				FoundString.Price = Selection.Price;
				
			EndDo; 
			
		Else
		
			RecordSet = InformationRegisters.Prices.CreateRecordSet();
			RecordSet.Filter.Period.Set(InstallationPeriod);
			RecordSet.Filter.PriceKind.Set(PriceKindInstallation);
			RecordSet.Filter.Products.Set(Selection.Products);
			RecordSet.Filter.Characteristic.Set(Selection.Characteristic);
			
			NewRecord = RecordSet.Add();
			FillPropertyValues(NewRecord, Selection);
			NewRecord.Period = InstallationPeriod;
			NewRecord.PriceKind = PriceKindInstallation;
			
			NewRecord.Actuality = True;
			NewRecord.Price = DriveClientServer.RoundPrice(NewRecord.Price, SetupRoundingOrder, RoundUpToInstallation);
			
			NewRecord.Author = Author;
			RecordSet.Write();
			
			FilterStructure = New Structure;
			FilterStructure.Insert("Products", Selection.Products);
			FilterStructure.Insert("Characteristic", Selection.Characteristic);
			FilterStructure.Insert("Check", True);
			RowArray = Prices.FindRows(FilterStructure);
			
			For Each FoundString In RowArray Do
				
				FoundString.Picture = 1;
				FoundString.Price = NewRecord.Price;
				
			EndDo; 
			
		EndIf;
	
	EndDo; 
	
EndProcedure

#EndRegion

#Region Other

&AtClient
Procedure ClearTabularSection()
	
	If Prices.Count() = 0 Then
		
		Return;
		
	EndIf;
	
	QuestionText = NStr("en = 'Tabular section will be cleared.
	                    |Continue?'");
	
	NotifyDescription = New NotifyDescription("DetermineNecessityForTabularSectionClearing", ThisObject);
	ShowQueryBox(NotifyDescription, QuestionText, QuestionDialogMode.YesNo);
	
EndProcedure

&AtServerNoContext
// Receives the set of data from the server for the ProductsOnChange procedure.
//
Function GetDataProductsOnChange(StructureData)
	
	StructureData.Insert("MeasurementUnit", StructureData.Products.MeasurementUnit);
	
	If StructureData.Property("PriceKind") Then
		
		StructureData.Insert("Characteristic", Catalogs.ProductsCharacteristics.EmptyRef());
		StructureData.Insert("DocumentCurrency", StructureData.PriceKind.PriceCurrency);
		StructureData.Insert("Factor", 1);
		
		PriceByPriceKind = DriveServer.GetProductsPriceByPriceKind(StructureData);
		StructureData.Insert("Price", PriceByPriceKind);
		
	Else
		
		StructureData.Insert("Price", 0);
		
	EndIf;
	
	Return StructureData;
	
EndFunction

&AtServerNoContext
// It receives data set from server for the CharacteristicOnChange procedure.
//
Function GetDataCharacteristicOnChange(StructureData)
	
	StructureData.Insert("DocumentCurrency", StructureData.PriceKind.PriceCurrency);
	
	If TypeOf(StructureData.MeasurementUnit) = Type("CatalogRef.UOMClassifier") Then
		StructureData.Insert("Factor", 1);
	Else
		StructureData.Insert("Factor", StructureData.MeasurementUnit.Factor);
	EndIf;
	
	PriceByPriceKind = DriveServer.GetProductsPriceByPriceKind(StructureData);
	StructureData.Insert("Price", PriceByPriceKind);
	
	Return StructureData;
	
EndFunction

&AtServerNoContext
// Gets the data set from the server for procedure MeasurementUnitOnChange.
//
Function GetDataMeasurementUnitOnChange(CurrentMeasurementUnit = Undefined, MeasurementUnit = Undefined)
	
	StructureData = New Structure;
	
	If CurrentMeasurementUnit = Undefined Then
		StructureData.Insert("CurrentFactor", 1);
	Else
		StructureData.Insert("CurrentFactor", CurrentMeasurementUnit.Factor);
	EndIf;
	
	If MeasurementUnit = Undefined Then
		StructureData.Insert("Factor", 1);
	Else
		StructureData.Insert("Factor", MeasurementUnit.Factor);
	EndIf;
	
	Return StructureData;
	
EndFunction

&AtServerNoContext
Procedure GetPriceKindAttributesAtServer(StructurePriceKind)
	
    StructurePriceKind.Insert("RoundUp", StructurePriceKind.PriceKind.RoundUp);
	StructurePriceKind.Insert("RoundingOrder", StructurePriceKind.PriceKind.RoundingOrder);
	StructurePriceKind.Insert("PricesBaseKind", StructurePriceKind.PriceKind.PricesBaseKind);
	StructurePriceKind.Insert("Markup", StructurePriceKind.PriceKind.Percent);  	

EndProcedure

#EndRegion

#EndRegion

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	ValueDates 	= ?(Parameters.Property("ToDate") AND ValueIsFilled(Parameters.ToDate), Parameters.ToDate, CurrentDate());
	Period 			= ValueDates;
	InstallationPeriod = ValueDates;
	
	If Parameters.Property("PriceKind") AND ValueIsFilled(Parameters.PriceKind) Then
		
		ParameterPriceKind = Parameters.PriceKind;
		
		If ParameterPriceKind.CalculatesDynamically Then
			
			MessageText = NStr("en = 'Cannot generate dynamic price kinds.'");
			DriveServer.ShowMessageAboutError(Object, MessageText, , , , Cancel);
			
		EndIf;
		
		PriceKindInstallation		= Parameters.PriceKind;
		
	Else
		
		ParameterPriceKind		= Undefined;
		//PriceKindInstallation 	= Catalogs.PriceTypes.GetMainKindOfSalePrices();
		
	EndIf;
	
	SetupRoundingOrder			= PriceKindInstallation.RoundingOrder;
	RoundUpToInstallation	= PriceKindInstallation.RoundUp;
	RoundingOrder 					= PriceKindInstallation.RoundingOrder;
	RoundUp 			= PriceKindInstallation.RoundUp;
	PricesBaseKind						= PriceKindInstallation.PricesBaseKind;
	Markup								= PriceKindInstallation.Percent;
	
	If Parameters.Property("PriceGroup") AND ValueIsFilled(Parameters.PriceGroup) Then
		ParameterPriceGroup = Parameters.PriceGroup;
	Else
		ParameterPriceGroup = Undefined;
	EndIf;
	
	If Parameters.Property("Products") AND ValueIsFilled(Parameters.Products) Then
		ParameterProducts = Parameters.Products;
	Else
		ParameterProducts = Undefined;
	EndIf;
	
	If Parameters.Property("AddressInventoryInStorage") Then
		Prices.Load(GetFromTempStorage(Parameters.AddressInventoryInStorage));
		For Each CurRow In Prices Do
			CurRow.Check = True;
		EndDo;
	EndIf;
	
	FillPricesFirstTime(Period, ParameterPriceKind, ParameterPriceGroup, ParameterProducts);
	
	FillingPrices = "Choose action...";
	CurrentAction = "";
	CurrentActionFill = "";
	Author = Users.CurrentUser();
	
	Items.PageSetup.CurrentPage = Items.Page0; 
	
	FunctionalCurrency = Constants.FunctionalCurrency.Get();
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(ValueSelected, ChoiceSource)
	
	If ValueSelected.FillVariant = "AddOnPrice" Then
		
		AddByPriceTypesAtServer(ValueSelected.ValueSelected, ValueSelected.ToDate, True, ValueSelected.UseCharacteristics);
		
	ElsIf ValueSelected.FillVariant = "AddBlankPricesByPriceKind" Then
		
		AddByPriceTypesAtServer(ValueSelected.ValueSelected, ValueSelected.ToDate, False, ValueSelected.UseCharacteristics);
		
	ElsIf ValueSelected.FillVariant = "AddOnPriceToFolders" Then
		
		AddByPriceGroupsAtServer(ValueSelected.ValueSelected, ValueSelected.UseCharacteristics);
		
	ElsIf ValueSelected.FillVariant = "AddOnToFoldersProducts" Then
		
		AddByProductsCategoriesAtServer(ValueSelected.ValueSelected, ValueSelected.UseCharacteristics);
		
	ElsIf ValueSelected.FillVariant = "AddToInvoiceReceipt" Then
		
		AddByReceiptInvoiceAtServer(ValueSelected.ValueSelected);
		
	EndIf; 
	
EndProcedure

&AtClient
Procedure ExecuteActions(Command)
	
	If CurrentAction = "FillPricesByPriceKind" Then
		
		FillPricesByPriceKindAtServer();
		
	ElsIf CurrentAction = "FillPricesBySupplierPriceTypes" Then
		
		FillPricesBySupplierPriceTypesAtServer();
		
	ElsIf CurrentAction = "CalculateByBasicPriceKind" Then
		
		CalculateByBasicPriceKindAtServer()
		
	ElsIf CurrentAction = "ChangeForPercent" Then
		
		ChangeForPercentAtClient();
		RoundAtClient();
		
	ElsIf CurrentAction = "ChangeForAmount" Then
		
		ChangeForAmountAtClient();
		RoundAtClient();
		
	ElsIf CurrentAction = "Round" Then
		
		RoundAtClient();
		
	ElsIf CurrentAction = "FillPricesByReceiptInvoice" Then
		
		FillPricesByReceiptInvoiceAtServer();
		
	ElsIf CurrentAction = "RemoveActuality" Then
		
		RemoveActualityAtServer();
		
	ElsIf CurrentAction = "DeletePriceListRecords" Then
		
		DeletePriceListRecordsAtServer();
		
	EndIf; 
	
EndProcedure

&AtClient
Procedure Set(Command)
	
	If Not ValueIsFilled(PriceKindInstallation) Then
	
		Message = New UserMessage();
		Message.Text = NStr("en = 'Step 1: The price kind is not selected.'");
		Message.Field = "PriceKindInstallation";
		Message.Message();
		Return;
	
	EndIf; 
	
	If Not ValueIsFilled(InstallationPeriod) Then
	
		Message = New UserMessage();
		Message.Text = NStr("en = 'Step 4: Price set date is not selected.'");
		Message.Field = "InstallationPeriod";
		Message.Message();
		Return;
	
	EndIf; 
	
	SetupAtServer();
	
EndProcedure

&AtClient
Procedure CloseForm(Command)
	
	Close(True);
	
EndProcedure

#Region TableFillingMechanisms

&AtClient
Procedure FillPriceTabularSection(Command)
	
	OpenForm("DataProcessor.Pricing.Form.FillingSettingsForm", , ThisForm);
	
EndProcedure

&AtClient
Procedure ClearPriceTabularSection(Command)
	
	ClearTabularSection();
	
EndProcedure

#EndRegion

#Region PagesAndActionsAttributesProcessingsSwitching

&AtClient
Procedure FillingPricesOnChange(Item)
	
	If FillingPrices = "Choose action..." Then
		
		CurrentAction = "";
		Items.PageSetup.CurrentPage = Items.Page0;
		
	ElsIf FillingPrices = "FillPricesByPriceKind" Then
		
		FillPricesByPriceKind(Undefined);
		
	ElsIf FillingPrices = "FillPricesBySupplierPriceTypes" Then
		
		FillPricesBySupplierPriceTypes(Undefined);
		
	ElsIf FillingPrices = "FillPricesByReceiptInvoice" Then
		
		FillPricesByReceiptInvoice(Undefined);
		
	ElsIf FillingPrices = "CalculateByBasicPriceKind" Then
		
		CalculateByBasicPriceKind(Undefined);
		
	ElsIf FillingPrices = "RemoveActuality" Then
		
		RemoveActuality(Undefined);
		
	ElsIf FillingPrices = "DeletePriceListRecords" Then
		
		DeletePriceListRecords(Undefined);
		
	ElsIf FillingPrices = "Round" Then
		
		Rounding(Undefined);
		
	ElsIf FillingPrices = "ChangeForAmount" Then
		
		ChangeForAmount(Undefined);
		
	ElsIf FillingPrices = "ChangeForPercent" Then
		
		ChangeForPercent(Undefined);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure FillPricesByPriceKind(Command)
	
	If CurrentAction = "FillPricesByPriceKind" Then
		Return;
	EndIf;
	CurrentAction = "FillPricesByPriceKind";
	
	Items.PageSetup.CurrentPage = Items.Page1;
	PriceKind = PriceKindInstallation;
	Period = CurrentDate();
	Items.Step4.Enabled = True;
	
EndProcedure

&AtClient
Procedure FillPricesBySupplierPriceTypes(Command)
	
	If CurrentAction = "FillPricesBySupplierPriceTypes" Then
		Return;
	EndIf;
	CurrentAction = "FillPricesBySupplierPriceTypes";
	
	Items.PageSetup.CurrentPage = Items.Page2;
	Items.Step4.Enabled = True;	
	
EndProcedure

&AtClient
Procedure CalculateByBasicPriceKind(Command)
	
	If CurrentAction = "CalculateByBasicPriceKind" Then
		Return;
	EndIf;
	CurrentAction = "CalculateByBasicPriceKind";
	
	Items.PageSetup.CurrentPage = Items.Page3;
	Items.Step4.Enabled = True;
	
EndProcedure

&AtClient
Procedure ChangeForPercent(Command)
	
	If CurrentAction = "ChangeForPercent" Then
		Return;
	EndIf;
	CurrentAction = "ChangeForPercent";
	
	Items.PageSetup.CurrentPage = Items.Page4;
	PlusMinus = "+";
	Items.Step4.Enabled = True;
	
EndProcedure

&AtClient
Procedure ChangeForAmount(Command)
	
	If CurrentAction = "ChangeForAmount" Then
		Return;
	EndIf;
	CurrentAction = "ChangeForAmount";
	
	Items.PageSetup.CurrentPage = Items.Page5;
	PlusMinus = "+";
	Items.Step4.Enabled = True;
	
EndProcedure

&AtClient
Procedure Rounding(Command)
	
	If CurrentAction = "Rounding" Then
		Return;
	EndIf;
	CurrentAction = "Rounding";
	
	Items.PageSetup.CurrentPage = Items.Page6;
	Items.Step4.Enabled = True;
	
EndProcedure

&AtClient
Procedure FillPricesByReceiptInvoice(Command)
	
	If CurrentAction = "FillPricesByReceiptInvoice" Then
		Return;
	EndIf;
	CurrentAction = "FillPricesByReceiptInvoice";
	
	Items.PageSetup.CurrentPage = Items.Page7;
	Items.Step4.Enabled = True;
	
EndProcedure

&AtClient
Procedure RemoveActuality(Command)
	
	If CurrentAction = "RemoveActuality" Then
		Return;
	EndIf;
	CurrentAction = "RemoveActuality";
	
	Items.PageSetup.CurrentPage = Items.Page8;
	Items.Step4.Enabled = False;
	
EndProcedure

&AtClient
Procedure DeletePriceListRecords(Command)
	
	If CurrentAction = "DeletePriceListRecords" Then
		Return;
	EndIf;
	CurrentAction = "DeletePriceListRecords";
	
	Items.PageSetup.CurrentPage = Items.Page9;
	Items.Step4.Enabled = False;
	
EndProcedure

&AtClient
Procedure MarkAll(Command)
	
	For Each TableRow In Prices Do
		TableRow.Check = True;
	EndDo;  
	
EndProcedure

&AtClient
Procedure UncheckMarks(Command)
	For Each TableRow In Prices Do
		TableRow.Check = False;
	EndDo;
EndProcedure

&AtClient
// Procedure - event handler OnChange of the Products input field.
//
Procedure PricesProductsOnChange(Item)
	
	TabularSectionRow = Items.Prices.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("Products", TabularSectionRow.Products);
	
	If ValueIsFilled(PriceKindInstallation) Then
		StructureData.Insert("PriceKind", PriceKindInstallation);
		StructureData.Insert("ProcessingDate", InstallationPeriod);
	EndIf;
	
	StructureData = GetDataProductsOnChange(StructureData);
	
	TabularSectionRow.MeasurementUnit = StructureData.MeasurementUnit;
	TabularSectionRow.Check = True;
	
	TabularSectionRow.OriginalPrice = StructureData.Price;
	TabularSectionRow.Price = StructureData.Price;
	
EndProcedure

&AtClient
Procedure PricesCharacteristicOnChange(Item)
	
	If ValueIsFilled(PriceKindInstallation) Then
		
		TabularSectionRow = Items.Prices.CurrentData;
		
		StructureData = New Structure;
		StructureData.Insert("PriceKind", PriceKindInstallation);
		StructureData.Insert("ProcessingDate", InstallationPeriod);
		StructureData.Insert("Products", TabularSectionRow.Products);
		StructureData.Insert("Characteristic", TabularSectionRow.Characteristic);
		StructureData.Insert("MeasurementUnit", TabularSectionRow.MeasurementUnit);
		
		StructureData = GetDataCharacteristicOnChange(StructureData);
		
		TabularSectionRow.OriginalPrice = StructureData.Price;
		TabularSectionRow.Price = StructureData.Price;
		
	EndIf;
	
EndProcedure

&AtClient
// Procedure - event handler ChoiceProcessing of the MeasurementUnit input field.
//
Procedure PricesMeasurementUnitChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	TabularSectionRow = Items.Prices.CurrentData;
	
	If TabularSectionRow.MeasurementUnit = ValueSelected 
	 OR TabularSectionRow.Price = 0 Then
		Return;
	EndIf;
	
	CurrentFactor = 0;
	If TypeOf(TabularSectionRow.MeasurementUnit) = Type("CatalogRef.UOMClassifier") Then
		CurrentFactor = 1;
	EndIf;
	
	Factor = 0;
	If TypeOf(ValueSelected) = Type("CatalogRef.UOMClassifier") Then
		Factor = 1;
	EndIf;
	
	If CurrentFactor = 0 AND Factor = 0 Then
		StructureData = GetDataMeasurementUnitOnChange(TabularSectionRow.MeasurementUnit, ValueSelected);
	ElsIf CurrentFactor = 0 Then
		StructureData = GetDataMeasurementUnitOnChange(TabularSectionRow.MeasurementUnit);
	ElsIf Factor = 0 Then
		StructureData = GetDataMeasurementUnitOnChange(,ValueSelected);
	ElsIf CurrentFactor = 1 AND Factor = 1 Then
		StructureData = New Structure("CurrentFactor, Factor", 1, 1);
	EndIf;
	
	If StructureData.CurrentFactor <> 0 Then
		TabularSectionRow.Price = TabularSectionRow.Price * StructureData.Factor / StructureData.CurrentFactor;
	EndIf;
		
EndProcedure

&AtClient
Procedure PriceKindInstallationOnChange(Item)
	
	If Not ValueIsFilled(PriceKindInstallation) Then
		Return;
	EndIf; 
	
	StructurePriceKind = New Structure("PriceKind", PriceKindInstallation);
	
	GetPriceKindAttributesAtServer(StructurePriceKind);
	
	RoundUpToInstallation = StructurePriceKind.RoundUp;
	RoundUp = StructurePriceKind.RoundUp;
	SetupRoundingOrder = StructurePriceKind.RoundingOrder;
	RoundingOrder = StructurePriceKind.RoundingOrder;
	PricesBaseKind = StructurePriceKind.PricesBaseKind;
	Markup = StructurePriceKind.Markup;
	
EndProcedure

#EndRegion

#Region InteractiveActionResultHandlers

&AtClient
// Procedure-handler of the question result document form filling by a basis document
//
//
Procedure DetermineNecessityForTabularSectionClearing(ClosingResult, AdditionalParameters) Export
	
	If ClosingResult = DialogReturnCode.Yes Then
		
		Prices.Clear();
		
	EndIf;
	
EndProcedure

#EndRegion

#EndRegion