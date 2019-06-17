
#Region InternalInterface

Procedure AssignPickForm(SelectionOpenParameters, DocumentFullName, TabularSectionName) Export
	
	If TypeOf(SelectionOpenParameters) <> Type("Structure") Then
		
		SelectionOpenParameters = New Structure;
		
	EndIf;
	
	SelectionOpenParameters.Insert(TabularSectionName, DataProcessors.ProductsSelection.ChoiceFormFullName());
	
EndProcedure

// Gets price and products measurement unit by the specified prices kind
//
// Returns:
//  Structure:
// 	- Price (Number). Obtained price of products by the pricelist.
// 	- MeasurementUnit (Catalog MeasurementUnits and MeasurementUnitsClassifier). Measurement unit specified in the price.
//
Function GetPriceAndProductsMeasurementUnitByCounterpartyPricesKind(DataStructure) Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	CounterpartyPricesSliceLast.SupplierPriceTypes.PriceCurrency AS PricesCurrency,
	|	CounterpartyPricesSliceLast.SupplierPriceTypes.PriceIncludesVAT AS PriceIncludesVAT,
	|	CounterpartyPricesSliceLast.MeasurementUnit AS MeasurementUnit,
	|	ISNULL(CounterpartyPricesSliceLast.Price * RateCurrencyTypePrices.ExchangeRate * DocumentCurrencyRate.Multiplicity / (DocumentCurrencyRate.ExchangeRate * RateCurrencyTypePrices.Multiplicity) * ISNULL(&Factor, 1) / ISNULL(CounterpartyPricesSliceLast.MeasurementUnit.Factor, 1), 0) AS Price
	|FROM
	|	InformationRegister.CounterpartyPrices.SliceLast(
	|			&ProcessingDate,
	|			Products = &Products
	|				AND Characteristic = &Characteristic
	|				AND SupplierPriceTypes = &SupplierPriceTypes) AS CounterpartyPricesSliceLast
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&ProcessingDate, ) AS RateCurrencyTypePrices
	|		ON CounterpartyPricesSliceLast.SupplierPriceTypes.PriceCurrency = RateCurrencyTypePrices.Currency,
	|	InformationRegister.ExchangeRates.SliceLast(&ProcessingDate, Currency = &DocumentCurrency) AS DocumentCurrencyRate
	|WHERE
	|	CounterpartyPricesSliceLast.Actuality";
	
	Query.SetParameter("ProcessingDate",		DataStructure.ProcessingDate);
	Query.SetParameter("Products",		DataStructure.Products);
	Query.SetParameter("Characteristic",		DataStructure.Characteristic);
	Query.SetParameter("Factor",		DataStructure.Factor);
	Query.SetParameter("DocumentCurrency",	DataStructure.DocumentCurrency);
	Query.SetParameter("SupplierPriceTypes",	DataStructure.SupplierPriceTypes);
	
	Selection = Query.Execute().Select();
	
	Price			= 0;
	MeasurementUnit= Undefined;
	While Selection.Next() Do
		
		Price			= Selection.Price;
		MeasurementUnit= Selection.MeasurementUnit;
		
		If DataStructure.AmountIncludesVAT <> Selection.PriceIncludesVAT Then
			
			Price = DriveServer.RecalculateAmountOnVATFlagsChange(Price, DataStructure.AmountIncludesVAT, DataStructure.VATRate);
			
		EndIf;
		
	EndDo;
	
	Return New Structure("MeasurementUnit, Price", MeasurementUnit, Price);
	
EndFunction

// Transform types

// Converts a data set with the ValuesList type into Array
// 
Function ValueListIntoArray(IncValueList) Export
	
	ArrayOfData = New Array;
	
	For Each ValueListItem In IncValueList Do
		
		ArrayOfData.Add(ValueListItem.Value);
		
	EndDo;
	
	Return ArrayOfData;
	
EndFunction

// The function defines if the received variable has the ValuesList type
//
Function IsValuesList(IncomingValue) Export
	
	Return (TypeOf(IncomingValue) = Type("ValueList"));
	
EndFunction

// Transform types End

// The procedure initially fills user settings
//
Procedure InitialSelectionSettingsFilling(User = Undefined, StandardProcessing = True) Export
	
	PickProductsInDocumentsOverridable.OverrideInitialSelectionSettingsFilling(User, StandardProcessing);
	
EndProcedure

// The procedure sets selection parameters by the transferred structure/array with product types.
//
Procedure SetChoiceParameters(Item, Val ProductsType) Export
	
	If IsValuesList(ProductsType) Then
		
		ProductsType = ValueListIntoArray(ProductsType);
		
	EndIf;
	
	If TypeOf(Item) <> Type("FormField")
		OR TypeOf(ProductsType) <> Type("Array")
		OR ProductsType.Count() < 1 Then
		
		Return;
		
	EndIf;
	
	NewParameter = New ChoiceParameter("Filter.ProductsType", New FixedArray(ProductsType));
	
	SelectionParametersArray = New Array;
	SelectionParametersArray.Add(NewParameter);
	Item.ChoiceParameters = New FixedArray(SelectionParametersArray);
	
EndProcedure

#EndRegion
