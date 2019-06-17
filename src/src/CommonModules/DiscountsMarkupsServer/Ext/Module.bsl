#Region ServiceProceduresAndFunctions

// The function returns the picture index depending on value of the SharedUsageVariant field of the analyzed group
Function GetPictureIndexForGroup(TreeRow) Export
	
	IndexOf = 0;
	If TreeRow.SharedUsageVariant = Enums.DiscountsApplyingRules.Max Then
		IndexOf = 8
	ElsIf TreeRow.SharedUsageVariant = Enums.DiscountsApplyingRules.Minimum Then
		IndexOf = 16
	ElsIf TreeRow.SharedUsageVariant = Enums.DiscountsApplyingRules.Addition Then
		IndexOf = 0
	ElsIf TreeRow.SharedUsageVariant = Enums.DiscountsApplyingRules.Multiplication Then
		IndexOf = 4
	ElsIf TreeRow.SharedUsageVariant = Enums.DiscountsApplyingRules.Exclusion Then
		IndexOf = 12
	EndIf;
	
	If TreeRow.DeletionMark Then
		IndexOf = IndexOf + 3;
	EndIf;
	
	Return IndexOf;
	
EndFunction

// The function returns an image index depending on the value of the AssignmentMethod and DeletionMark fields of the
// analyzed discount
Function GetPictureIndexForDiscount(TreeRow) Export
	
	IndexOf = 0;
	If TreeRow.AssignmentMethod = Enums.DiscountValueType.Percent Then
		If TreeRow.DiscountMarkupValue < 0 Then
			IndexOf = 32;
		Else
			IndexOf = 28;
		EndIf;
	ElsIf TreeRow.AssignmentMethod = Enums.DiscountValueType.Amount Then
		If TreeRow.DiscountMarkupValue < 0 Then
			IndexOf = 40;
		Else
			IndexOf = 44;
		EndIf;
	EndIf;
	
	If TreeRow.DeletionMark Then
		IndexOf = IndexOf + 3;
	EndIf;
	
	Return IndexOf;
	
EndFunction

// The function creates a table of values.
//
// Returns:
// ValueTable
//
Function GetEmptyDiscountsTableWithDetails(Parameters)
	
	If Parameters.EmptyDiscountsTableWithDetails = Undefined Then
		Table = New ValueTable;
		Table.Columns.Add("ConnectionKey",   New TypeDescription("Number"));
		Table.Columns.Add("Details", New TypeDescription("ValueTable"));
		Table.Columns.Add("Amount",       New TypeDescription("Number"));
		Table.Columns.Add("Acts",   New TypeDescription("Boolean"));
		Parameters.EmptyDiscountsTableWithDetails = Table;
	Else
		Return Parameters.EmptyDiscountsTableWithDetails.CopyColumns();
	EndIf;
	
	Return Table;
	
EndFunction

// The function unites subordinate data tables.
//
// Returns:
// DataTable - united data table.
//
Function UniteSubordinateRowsDataTables(TreeRow)
	
	DataTable = New ValueTable;
	DataTable.Columns.Add("ConnectionKey",                 New TypeDescription("Number"));
	DataTable.Columns.Add("Amount",                     New TypeDescription("Number"));
	DataTable.Columns.Add("Details",               New TypeDescription("ValueTable"));
	DataTable.Columns.Add("AdditionalOrderingAttribute", New TypeDescription("Number"));
	
	For Each SubordinatedRow In TreeRow.Rows Do
		
		If Not SubordinatedRow.IsFolder Then // This is discount, not a group
			
			If Not SubordinatedRow.ConditionsParameters.ConditionsFulfilled Then
				Continue;
			EndIf;
			
		EndIf;
		
		AdditionalOrderingAttribute = SubordinatedRow.AdditionalOrderingAttribute;
		
		For Each TableRow In SubordinatedRow.DataTable Do
			If SubordinatedRow.IsFolder Then
				NewRow = DataTable.Add();
				FillPropertyValues(NewRow, TableRow);
				NewRow.AdditionalOrderingAttribute = AdditionalOrderingAttribute;
			Else
				If TableRow.Acts Then
					NewRow = DataTable.Add();
					FillPropertyValues(NewRow, TableRow);
					NewRow.AdditionalOrderingAttribute = AdditionalOrderingAttribute;
				EndIf;
			EndIf;
		EndDo;
		
	EndDo;
	
	Return DataTable;
	
EndFunction

// The function creates a table of values with discount details and adds the sent values to it.
//
// Returns:
// ValueTable - Details of discounts.
//
Function GetDiscountDetails(TreeRow, Amount, Parameters)
	
	Details = Parameters.EmptyTableDecryption.CopyColumns();
	
	RowOfDetails = Details.Add();
	RowOfDetails.DiscountMarkup = TreeRow.DiscountMarkup;
	RowOfDetails.Amount         = Amount;
	
	Return Details;
	
EndFunction

// The function fills the connection keys in spreadsheet parts "Products" of the document.
//
Procedure FillLinkingKeysInSpreadsheetPartProducts(Object, TSName, NameSP2 = Undefined) Export
	
	IndexOf = 0;
	For Each TSRow In Object[TSName] Do
		IndexOf = IndexOf + 1;
		TSRow.ConnectionKey = IndexOf;
	EndDo;
	
	If Not NameSP2 = Undefined Then
		For Each TSRow In Object[NameSP2] Do
			IndexOf = IndexOf + 1;
			TSRow.ConnectionKeyForMarkupsDiscounts = IndexOf;
		EndDo;
	EndIf;
	
EndProcedure

// The function receives current time of the object
//
// Parameters
//  Object  - DocumentObject - object for which you need to get the current time
//
// Returns:
//   Date   - Current time of the object
//
Function GetObjectCurrentTime(Object) Export
	
	CurrentDate = ?(ValueIsFilled(Object.Ref), Object.Date, CurrentSessionDate());
	CurrentTime = '00010101' + (CurrentDate - BegOfDay(CurrentDate));
	
	Return CurrentTime;
	
EndFunction

// The function gets current date object time
//
// Parameters
//  Object  - DocumentObject - object for which you need to get the current time
//
// Returns:
//   Date   - Current time of the object
//
Function GetObjectCurrentDate(Object) Export
	
	CurrentDate = ?(ValueIsFilled(Object.Ref), Object.Date, CurrentSessionDate());
	
	Return CurrentDate;
	
EndFunction

// The function checks if recalculation of automatic discounts is necessary depending on the action that led to the
// function call.
//
Function CheckNeedToRecalculateAutomaticDiscounts(Action, ColumnTS) Export
	
	AutomaticDiscountsRecalculationIsRequired = True;
	
	// If the sum or price has changed and there is no discount which
	// depends on the price, then there is no need to recalculate automatic discounts.
	If Find(Action, "Date") > 0 Then
		RecordManager = InformationRegisters.ServiceAutomaticDiscounts.CreateRecordManager();
		RecordManager.Read();
		If RecordManager.ScheduleDiscountsAvailable Then
			AutomaticDiscountsRecalculationIsRequired = True;
		Else
			AutomaticDiscountsRecalculationIsRequired = False;
		EndIf;
	// If counterparty was changed and there are no discounts that depend
	// on recipient-counterparty, then there is no need to recalculate automatic discounts.
	ElsIf Find(Action, "Counterparty") > 0 Then
		RecordManager = InformationRegisters.ServiceAutomaticDiscounts.CreateRecordManager();
		RecordManager.Read();
		If RecordManager.CounterpartyRecipientDiscountsAvailable Then
			AutomaticDiscountsRecalculationIsRequired = True;
		Else
			AutomaticDiscountsRecalculationIsRequired = False;
		EndIf;
	// If counterparty has changed and there are no discounts that depend
	// on the recipient warehouse, then there is no need to recalculate the automatic discounts.
	ElsIf Find(Action, "Warehouse") > 0 Then
		RecordManager = InformationRegisters.ServiceAutomaticDiscounts.CreateRecordManager();
		RecordManager.Read();
		If RecordManager.WarehouseRecipientDiscountsAvailable Then
			AutomaticDiscountsRecalculationIsRequired = True;
		Else
			AutomaticDiscountsRecalculationIsRequired = False;
		EndIf;
	Else
		AutomaticDiscountsRecalculationIsRequired = True;
	EndIf;
	
	Return AutomaticDiscountsRecalculationIsRequired;
	
EndFunction

// Function clears checkbox "DiscountsAreCalculated" if it is necessary and returns True if it is required to
// recalculate discounts.
//
Function ResetFlagDiscountsAreCalculated(Form, Action, SPColumn, CWT = "Inventory", SP2 = Undefined) Export
	
	Object = Form.Object;
	Items = Form.Items;
	
	AutomaticDiscountsRecalculationIsRequired = True;
	
	If Object[CWT].Count() = 0 AND (SP2 = Undefined OR Object[SP2].Count() = 0) Then
		Form.InstalledGrayColor = True;
		Items[CWT+"CalculateDiscountsMarkups"].Picture = PictureLib.UpdateGray;
		If SP2 <> Undefined Then
			Items[SP2+"CalculateDiscountsMarkups"].Picture = PictureLib.UpdateGray;
		EndIf;
		AutomaticDiscountsRecalculationIsRequired = False;
	Else
		AutomaticDiscountsRecalculationIsRequired = CheckNeedToRecalculateAutomaticDiscounts(Action, SPColumn);
		
		If AutomaticDiscountsRecalculationIsRequired Then
			Items[CWT+"CalculateDiscountsMarkups"].Picture = PictureLib.UpdateRed;
			
			If SP2 <> Undefined Then
				Items[SP2+"CalculateDiscountsMarkups"].Picture = PictureLib.UpdateRed;
			EndIf;
			
			Form.InstalledGrayColor = False;
		EndIf;
	EndIf;
	
	If AutomaticDiscountsRecalculationIsRequired AND Object.DiscountsAreCalculated Then
		Object.DiscountsAreCalculated = False;
	EndIf;
	Return AutomaticDiscountsRecalculationIsRequired;
	
EndFunction

#EndRegion

#Region ServiceQueries

// Generates a query text for the table of discounts by price group.
//
// Returns:
// Structure - Query text
//
Function QueryTextTableExchangeRates() Export
	
	QueryText =
	"SELECT
	|	ExchangeRatesSliceLast.Currency    AS Currency,
	|	ExchangeRatesSliceLast.ExchangeRate      AS ExchangeRate,
	|	ExchangeRatesSliceLast.Multiplicity AS Multiplicity
	|INTO ExchangeRates
	|FROM
	|	InformationRegister.ExchangeRates.SliceLast(&CurrentDate, ) AS ExchangeRatesSliceLast
	|
	|INDEX BY
	|	Currency";
	
	QueryText = QueryText + "
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|";
	
	Return New Structure("QueryText, TablesCount, ResultTableNumber, TableName", QueryText, 1, 1, "ExchangeRates");
	
EndFunction

// Generates a query text for the table of available discounts.
//
// Returns:
// Structure - Query text
//
Function QueryTextDiscountsMarkupsTable(OnlyPreliminaryCalculation)
	
	QueryText =
	"SELECT ALLOWED
	|	DiscountsMarkups.DiscountMarkup AS Ref
	|INTO TemporaryTable
	|FROM
	|	&DiscountsMarkups AS DiscountsMarkups
	|
	|INDEX BY
	|	Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	DiscountsMarkups.Ref AS Ref,
	|	DiscountsMarkups.SharedUsageVariant AS SharedUsageVariant,
	|	DiscountsMarkups.AdditionalOrderingAttribute AS AdditionalOrderingAttribute,
	|	DiscountsMarkups.AssignmentArea AS AssignmentArea,
	|	DiscountsMarkups.AssignmentMethod AS AssignmentMethod,
	|	CASE
	|		WHEN DiscountsMarkups.AssignmentMethod = VALUE(Enum.DiscountValueType.Amount)
	|			THEN DiscountsMarkups.DiscountMarkupValue * ISNULL(ExchangeRatesProvisions.ExchangeRate, 1) * ISNULL(ExchangeRatesOfDocument.Multiplicity, 1) / (ISNULL(ExchangeRatesOfDocument.ExchangeRate, 1) * ISNULL(ExchangeRatesProvisions.Multiplicity, 1))
	|		ELSE DiscountsMarkups.DiscountMarkupValue
	|	END AS DiscountMarkupValue,
	|	DiscountsMarkups.AssignmentCurrency AS AssignmentCurrency
	|INTO TemporaryDiscountMarkupTable
	|FROM
	|	TemporaryTable AS TemporaryDiscountTable
	|		INNER JOIN Catalog.AutomaticDiscountTypes AS DiscountsMarkups
	|		ON TemporaryDiscountTable.Ref = DiscountsMarkups.Ref
	|		LEFT JOIN ExchangeRates AS ExchangeRatesProvisions
	|		ON (ExchangeRatesProvisions.Currency = DiscountsMarkups.AssignmentCurrency)
	|		LEFT JOIN ExchangeRates AS ExchangeRatesOfDocument
	|		ON (ExchangeRatesOfDocument.Currency = &DocumentCurrency)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	TemporaryDiscountMarkupTable.Ref AS DiscountMarkup,
	|	TemporaryDiscountMarkupTable.AssignmentMethod AS AssignmentMethod,
	|	TemporaryDiscountMarkupTable.AssignmentArea AS AssignmentArea,
	|	TemporaryDiscountMarkupTable.DiscountMarkupValue AS DiscountMarkupValue
	|FROM
	|	TemporaryDiscountMarkupTable AS TemporaryDiscountMarkupTable
	|		INNER JOIN Catalog.AutomaticDiscountTypes AS DiscountsMarkups
	|		ON TemporaryDiscountMarkupTable.Ref = DiscountsMarkups.Ref";
	
	QueryText = QueryText + "
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|";
	
	Return New Structure("QueryText, TablesCount, ResultTableNumber, TableName", QueryText, 3, 3, "DiscountsMarkups");
	
EndFunction

// Generates a query text for the table of available discounts.
//
// Returns:
// Structure - Query text
//
Function QueryTextTableAssignmentCondition()
	
	// IN the query all DISTINCT are selected as Different discounts may have same conditions.
	// Later this table is used to define the fullfilled conditions with the help of an internal connection.
	// There shall be no duplicates in this table!
	//
	QueryText =
	"SELECT ALLOWED DISTINCT
	|	Conditions.AssignmentCondition AS Ref,
	|	Conditions.AssignmentCondition.AssignmentCondition AS AssignmentCondition,
	|	Conditions.AssignmentCondition.ComparisonType AS ComparisonType,
	|	Conditions.AssignmentCondition.RestrictionCurrency AS RestrictionCurrency,
	|	Conditions.AssignmentCondition.UseRestrictionCriterionForSalesVolume AS UseRestrictionCriterionForSalesVolume,
	|	Conditions.AssignmentCondition.RestrictionArea AS RestrictionArea,
	|	CASE
	|		WHEN Conditions.AssignmentCondition.AssignmentCondition = VALUE(Enum.DiscountCondition.ForOneTimeSalesVolume)
	|				AND Conditions.AssignmentCondition.UseRestrictionCriterionForSalesVolume = VALUE(Enum.DiscountSalesAmountLimit.Amount)
	|			THEN Conditions.AssignmentCondition.RestrictionConditionValue * ISNULL(ExchangeRatesRestriction.ExchangeRate, 1) * ISNULL(ExchangeRatesOfDocument.Multiplicity, 1) / (ISNULL(ExchangeRatesOfDocument.ExchangeRate, 1) * ISNULL(ExchangeRatesRestriction.Multiplicity, 1))
	|		ELSE Conditions.AssignmentCondition.RestrictionConditionValue
	|	END AS RestrictionConditionValue,
	|	Conditions.AssignmentCondition.TakeIntoAccountSaleOfOnlyParticularProductsList AS ThereIsFilterByProducts
	|INTO ConditionsOfAssignment
	|FROM
	|	TemporaryTable AS DiscountsMarkups
	|		INNER JOIN Catalog.AutomaticDiscountTypes.ConditionsOfAssignment AS Conditions
	|		ON DiscountsMarkups.Ref = Conditions.Ref
	|		LEFT JOIN ExchangeRates AS ExchangeRatesRestriction
	|		ON (ExchangeRatesRestriction.Currency = Conditions.AssignmentCondition.RestrictionCurrency)
	|		LEFT JOIN ExchangeRates AS ExchangeRatesOfDocument
	|		ON (ExchangeRatesOfDocument.Currency = &DocumentCurrency)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	ConditionsOfAssignment.Ref AS Ref,
	|	ConditionsOfAssignment.AssignmentCondition AS AssignmentCondition,
	|	ConditionsOfAssignment.RestrictionCurrency AS RestrictionCurrency,
	|	ConditionsOfAssignment.ComparisonType AS ComparisonType,
	|	ConditionsOfAssignment.UseRestrictionCriterionForSalesVolume AS UseRestrictionCriterionForSalesVolume,
	|	ConditionsOfAssignment.RestrictionArea AS RestrictionArea,
	|	ConditionsOfAssignment.RestrictionConditionValue AS RestrictionConditionValue,
	|	ConditionsOfAssignment.ThereIsFilterByProducts
	|FROM
	|	ConditionsOfAssignment AS ConditionsOfAssignment";
	
	QueryText = QueryText + "
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|";
	
	Return New Structure("QueryText, TablesCount, ResultTableNumber, TableName", QueryText, 2, 2, "ConditionsOfAssignment");
	
EndFunction

// Generates a query text for the table of discounts by price group.
//
// Returns:
// Structure - Query text
//
Function QueryTextDiscountMarkupTableByPriceGroups()
	
	QueryText =
	"SELECT ALLOWED
	|	PriceGroups.Ref AS DiscountMarkup,
	|	PriceGroups.ValueClarification AS ValueClarification,
	|	CASE
	|		WHEN DiscountsMarkups.AssignmentMethod = VALUE(Enum.DiscountValueType.Amount)
	|			THEN PriceGroups.DiscountMarkupValue * ISNULL(ExchangeRatesProvisions.ExchangeRate, 1) * ISNULL(ExchangeRatesOfDocument.Multiplicity, 1) / (ISNULL(ExchangeRatesOfDocument.ExchangeRate, 1) * ISNULL(ExchangeRatesProvisions.Multiplicity, 1))
	|		ELSE PriceGroups.DiscountMarkupValue
	|	END AS DiscountMarkupValue
	|FROM
	|	TemporaryDiscountMarkupTable AS DiscountsMarkups
	|		LEFT JOIN ExchangeRates AS ExchangeRatesProvisions
	|		ON (ExchangeRatesProvisions.Currency = DiscountsMarkups.AssignmentCurrency)
	|		LEFT JOIN ExchangeRates AS ExchangeRatesOfDocument
	|		ON (ExchangeRatesOfDocument.Currency = &DocumentCurrency)
	|		INNER JOIN Catalog.AutomaticDiscountTypes.ProductsGroupsPriceGroups AS PriceGroups
	|		ON DiscountsMarkups.Ref = PriceGroups.Ref
	|			AND (PriceGroups.Ref.IsClarificationByPriceGroups)
	|WHERE
	|	PriceGroups.Ref.RestrictionByProductsVariant = VALUE(Enum.DiscountApplyingFilterType.ByPriceGroups)";
	
	QueryText = QueryText + "
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|";
	
	Return New Structure("QueryText, TablesCount, ResultTableNumber, TableName", QueryText, 1, 1, "DiscountsMarkupsByPriceGroups");
	
EndFunction

// Generates a query text for the table of discounts by product groups.
//
// Returns:
// Structure - Query text
//
Function QueryTextDiscountsMarkupsTableByProductsGroups()
	
	QueryText =
	"SELECT ALLOWED
	|	ProductsCategories.Ref AS DiscountMarkup,
	|	ProductsCategories.ValueClarification AS ValueClarification,
	|	CASE
	|		WHEN DiscountsMarkups.AssignmentMethod = VALUE(Enum.DiscountValueType.Amount)
	|			THEN ProductsCategories.DiscountMarkupValue * ISNULL(ExchangeRatesProvisions.ExchangeRate, 1) * ISNULL(ExchangeRatesOfDocument.Multiplicity, 1) / (ISNULL(ExchangeRatesOfDocument.ExchangeRate, 1) * ISNULL(ExchangeRatesProvisions.Multiplicity, 1))
	|		ELSE ProductsCategories.DiscountMarkupValue
	|	END AS DiscountMarkupValue
	|FROM
	|	TemporaryDiscountMarkupTable AS DiscountsMarkups
	|		LEFT JOIN ExchangeRates AS ExchangeRatesProvisions
	|		ON (ExchangeRatesProvisions.Currency = DiscountsMarkups.AssignmentCurrency)
	|		LEFT JOIN ExchangeRates AS ExchangeRatesOfDocument
	|		ON (ExchangeRatesOfDocument.Currency = &DocumentCurrency)
	|		INNER JOIN Catalog.AutomaticDiscountTypes.ProductsGroupsPriceGroups AS ProductsCategories
	|		ON DiscountsMarkups.Ref = ProductsCategories.Ref
	|			AND (ProductsCategories.Ref.IsClarificationByProductsCategories)
	|WHERE
	|	ProductsCategories.Ref.RestrictionByProductsVariant = VALUE(Enum.DiscountApplyingFilterType.ByProductsCategories)";
	
	QueryText = QueryText + "
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|";
	
	Return New Structure("QueryText, TablesCount, ResultTableNumber, TableName", QueryText, 1, 1, "DiscountsMarkupsByProductsGroups");
	
EndFunction

// Generates a query text for the table of discounts by product.
//
// Returns:
// Structure - Query text
//
Function QueryTextTableDiscountsMarkupsByProducts()
	
	QueryText =
	"SELECT ALLOWED
	|	Products.Ref AS DiscountMarkup,
	|	Products.ValueClarification AS ValueClarification,
	|	CASE
	|		WHEN DiscountsMarkups.AssignmentMethod = VALUE(Enum.DiscountValueType.Amount)
	|			THEN Products.DiscountMarkupValue * ISNULL(ExchangeRatesProvisions.ExchangeRate, 1) * ISNULL(ExchangeRatesOfDocument.Multiplicity, 1) / (ISNULL(ExchangeRatesOfDocument.ExchangeRate, 1) * ISNULL(ExchangeRatesProvisions.Multiplicity, 1))
	|		ELSE Products.DiscountMarkupValue
	|	END AS DiscountMarkupValue,
	|	Products.ValueClarification.IsFolder AS IsFolder,
	|	Products.Characteristic
	|FROM
	|	TemporaryDiscountMarkupTable AS DiscountsMarkups
	|		LEFT JOIN ExchangeRates AS ExchangeRatesProvisions
	|		ON (ExchangeRatesProvisions.Currency = DiscountsMarkups.AssignmentCurrency)
	|		LEFT JOIN ExchangeRates AS ExchangeRatesOfDocument
	|		ON (ExchangeRatesOfDocument.Currency = &DocumentCurrency)
	|		INNER JOIN Catalog.AutomaticDiscountTypes.ProductsGroupsPriceGroups AS Products
	|		ON DiscountsMarkups.Ref = Products.Ref
	|			AND (Products.Ref.IsClarificationByProducts)
	|WHERE
	|	Products.Ref.RestrictionByProductsVariant = VALUE(Enum.DiscountApplyingFilterType.ByProducts)";
	
	QueryText = QueryText + "
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|";
	
	Return New Structure("QueryText, TablesCount, ResultTableNumber, TableName", QueryText, 1, 1, "DiscountsMarkupsByProducts");
	
EndFunction

#EndRegion

#Region RequestPartsByDiscountsAssignmentCondition

// The function generates parameter name by the link to provision condition.
//
// Returns:
// String - ParameterName
//
Function GetQueryParameterFromRef(RefOnAssignmentCondition)
	
	Return StrReplace("P"+RefOnAssignmentCondition.UUID(), "-", "_");
	
EndFunction

// The function generates text of query to search discounts for a one-time sale which fit to the condition of provision.
//
// Returns:
// String - Query text
//
Function QueryTextDiscountForOneTimeSaleWithConditionByLine(QueryBatch, RefOnAssignmentCondition)
	
	QueryText =
	"SELECT
	|	DiscountConditionsSalesFilterByProducts.Products AS Products
	|INTO SalesByProductsFilterGroups
	|FROM
	|	Catalog.DiscountConditions.SalesFilterByProducts AS DiscountConditionsSalesFilterByProducts
	|WHERE
	|	DiscountConditionsSalesFilterByProducts.Ref = &ParameterName
	|	AND DiscountConditionsSalesFilterByProducts.Products.IsFolder
	|
	|INDEX BY
	|	Products
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DiscountConditionsSalesFilterByProducts.Products AS Products,
	|	DiscountConditionsSalesFilterByProducts.Characteristic
	|INTO SalesFilterByProducts
	|FROM
	|	Catalog.DiscountConditions.SalesFilterByProducts AS DiscountConditionsSalesFilterByProducts
	|WHERE
	|	DiscountConditionsSalesFilterByProducts.Ref = &ParameterName
	|	AND Not DiscountConditionsSalesFilterByProducts.Products.IsFolder
	|	AND DiscountConditionsSalesFilterByProducts.Characteristic = VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|
	|INDEX BY
	|	Products
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DiscountConditionsSalesFilterByProducts.Products AS Products,
	|	DiscountConditionsSalesFilterByProducts.Characteristic AS Characteristic
	|INTO FilterSalesByProductsWithCharacteristics
	|FROM
	|	Catalog.DiscountConditions.SalesFilterByProducts AS DiscountConditionsSalesFilterByProducts
	|WHERE
	|	DiscountConditionsSalesFilterByProducts.Ref = &ParameterName
	|	AND Not DiscountConditionsSalesFilterByProducts.Products.IsFolder
	|	AND DiscountConditionsSalesFilterByProducts.Characteristic <> VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|
	|INDEX BY
	|	Products,
	|	Characteristic
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED DISTINCT
	|	ConditionsOfAssignment.Ref AS Ref,
	|	TemporaryTableProducts.ConnectionKey AS ConnectionKey
	|FROM
	|	ConditionsOfAssignment AS ConditionsOfAssignment
	|		INNER JOIN TemporaryTableProducts AS TemporaryTableProducts
	|		ON (ConditionsOfAssignment.Ref = &ParameterName)
	|WHERE
	|	CASE
	|			WHEN ConditionsOfAssignment.UseRestrictionCriterionForSalesVolume = VALUE(Enum.DiscountSalesAmountLimit.Amount)
	|				THEN CASE
	|						WHEN ConditionsOfAssignment.ComparisonType = VALUE(Enum.DiscountValuesComparisonTypes.GreaterOrEqual)
	|							THEN TemporaryTableProducts.Amount >= ConditionsOfAssignment.RestrictionConditionValue
	|						WHEN ConditionsOfAssignment.ComparisonType = VALUE(Enum.DiscountValuesComparisonTypes.Greater)
	|							THEN TemporaryTableProducts.Amount > ConditionsOfAssignment.RestrictionConditionValue
	|						WHEN ConditionsOfAssignment.ComparisonType = VALUE(Enum.DiscountValuesComparisonTypes.LessOrEqual)
	|							THEN TemporaryTableProducts.Amount <= ConditionsOfAssignment.RestrictionConditionValue
	|						ELSE TemporaryTableProducts.Amount < ConditionsOfAssignment.RestrictionConditionValue
	|					END
	|			WHEN ConditionsOfAssignment.UseRestrictionCriterionForSalesVolume = VALUE(Enum.DiscountSalesAmountLimit.Quantity)
	|				THEN CASE
	|						WHEN ConditionsOfAssignment.ComparisonType = VALUE(Enum.DiscountValuesComparisonTypes.GreaterOrEqual)
	|							THEN TemporaryTableProducts.Quantity >= ConditionsOfAssignment.RestrictionConditionValue
	|						WHEN ConditionsOfAssignment.ComparisonType = VALUE(Enum.DiscountValuesComparisonTypes.Greater)
	|							THEN TemporaryTableProducts.Quantity > ConditionsOfAssignment.RestrictionConditionValue
	|						WHEN ConditionsOfAssignment.ComparisonType = VALUE(Enum.DiscountValuesComparisonTypes.LessOrEqual)
	|							THEN TemporaryTableProducts.Quantity <= ConditionsOfAssignment.RestrictionConditionValue
	|						ELSE TemporaryTableProducts.Quantity < ConditionsOfAssignment.RestrictionConditionValue
	|					END
	|			ELSE FALSE
	|		END
	|	AND (NOT ConditionsOfAssignment.ThereIsFilterByProducts
	|			OR TemporaryTableProducts.Products IN HIERARCHY
	|				(SELECT DISTINCT
	|					SalesByProductsFilterGroups.Products
	|				FROM
	|					SalesByProductsFilterGroups AS SalesByProductsFilterGroups)
	|			OR TemporaryTableProducts.Products IN
	|				(SELECT DISTINCT
	|					SalesFilterByProducts.Products
	|				FROM
	|					SalesFilterByProducts AS SalesFilterByProducts)
	|			OR (TemporaryTableProducts.Products, TemporaryTableProducts.Characteristic) IN
	|				(SELECT DISTINCT
	|					FilterSalesByProductsWithCharacteristics.Products,
	|					FilterSalesByProductsWithCharacteristics.Characteristic
	|				FROM
	|					FilterSalesByProductsWithCharacteristics AS FilterSalesByProductsWithCharacteristics))
	|
	|ORDER BY
	|	Ref,
	|	ConnectionKey
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP SalesFilterByProducts
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP SalesByProductsFilterGroups
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP FilterSalesByProductsWithCharacteristics";
	
	ParameterName = GetQueryParameterFromRef(RefOnAssignmentCondition);
	QueryText = StrReplace(QueryText, "ParameterName", ParameterName);
	QueryBatch.Query.SetParameter(ParameterName, RefOnAssignmentCondition);
	
	QueryText = QueryText + "
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|";
	
	Return New Structure(
		"QueryText,
		|TablesCount,
		|ResultTableNumber,
		|TableName",
		QueryText,
		7,
		4,
		"DiscountForOneTimeSaleWithConditionByLine" + ParameterName
	);
	
EndFunction

// The function generates text of a query for the table of calculated discounts for one-time sale.
//
// Returns:
// String - Query text
//
Function QueryTextDiscountForOneTimeSaleWithConditionByDocument(QueryBatch, RefOnAssignmentCondition)

	QueryText =
	"SELECT
	|	DiscountConditionsSalesFilterByProducts.Products AS Products
	|INTO SalesByProductsFilterGroups
	|FROM
	|	Catalog.DiscountConditions.SalesFilterByProducts AS DiscountConditionsSalesFilterByProducts
	|WHERE
	|	DiscountConditionsSalesFilterByProducts.Ref = &ParameterName
	|	AND DiscountConditionsSalesFilterByProducts.Products.IsFolder
	|
	|INDEX BY
	|	Products
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DiscountConditionsSalesFilterByProducts.Products AS Products,
	|	DiscountConditionsSalesFilterByProducts.Characteristic
	|INTO SalesFilterByProducts
	|FROM
	|	Catalog.DiscountConditions.SalesFilterByProducts AS DiscountConditionsSalesFilterByProducts
	|WHERE
	|	DiscountConditionsSalesFilterByProducts.Ref = &ParameterName
	|	AND Not DiscountConditionsSalesFilterByProducts.Products.IsFolder
	|	AND DiscountConditionsSalesFilterByProducts.Characteristic = VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|
	|INDEX BY
	|	Products
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DiscountConditionsSalesFilterByProducts.Products AS Products,
	|	DiscountConditionsSalesFilterByProducts.Characteristic AS Characteristic
	|INTO FilterSalesByProductsWithCharacteristics
	|FROM
	|	Catalog.DiscountConditions.SalesFilterByProducts AS DiscountConditionsSalesFilterByProducts
	|WHERE
	|	DiscountConditionsSalesFilterByProducts.Ref = &ParameterName
	|	AND Not DiscountConditionsSalesFilterByProducts.Products.IsFolder
	|	AND DiscountConditionsSalesFilterByProducts.Characteristic <> VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|
	|INDEX BY
	|	Products,
	|	Characteristic
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ConditionsOfAssignment.Ref,
	|	ConditionsOfAssignment.UseRestrictionCriterionForSalesVolume,
	|	ConditionsOfAssignment.ComparisonType,
	|	ConditionsOfAssignment.RestrictionConditionValue,
	|	SUM(TemporaryTableProducts.Quantity) AS Quantity,
	|	SUM(TemporaryTableProducts.Amount) AS Amount
	|INTO ResultsByDocument
	|FROM
	|	ConditionsOfAssignment AS ConditionsOfAssignment
	|		INNER JOIN TemporaryTableProducts AS TemporaryTableProducts
	|		ON (ConditionsOfAssignment.Ref = &ParameterName)
	|			AND (NOT ConditionsOfAssignment.ThereIsFilterByProducts
	|				OR TemporaryTableProducts.Products IN HIERARCHY
	|					(SELECT DISTINCT
	|						SalesByProductsFilterGroups.Products
	|					FROM
	|						SalesByProductsFilterGroups AS SalesByProductsFilterGroups)
	|				OR TemporaryTableProducts.Products IN
	|					(SELECT DISTINCT
	|						SalesFilterByProducts.Products
	|					FROM
	|						SalesFilterByProducts AS SalesFilterByProducts)
	|				OR (TemporaryTableProducts.Products, TemporaryTableProducts.Characteristic) IN
	|					(SELECT DISTINCT
	|						FilterSalesByProductsWithCharacteristics.Products,
	|						FilterSalesByProductsWithCharacteristics.Characteristic
	|					FROM
	|						FilterSalesByProductsWithCharacteristics AS FilterSalesByProductsWithCharacteristics))
	|
	|GROUP BY
	|	ConditionsOfAssignment.UseRestrictionCriterionForSalesVolume,
	|	ConditionsOfAssignment.Ref,
	|	ConditionsOfAssignment.RestrictionConditionValue,
	|	ConditionsOfAssignment.ComparisonType
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED DISTINCT
	|	ResultsByDocument.Ref AS Ref,
	|	-1 AS ConnectionKey
	|FROM
	|	ResultsByDocument AS ResultsByDocument
	|WHERE
	|	CASE
	|			WHEN ResultsByDocument.UseRestrictionCriterionForSalesVolume = VALUE(Enum.DiscountSalesAmountLimit.Amount)
	|				THEN CASE
	|						WHEN ResultsByDocument.ComparisonType = VALUE(Enum.DiscountValuesComparisonTypes.GreaterOrEqual)
	|							THEN ResultsByDocument.Amount >= ResultsByDocument.RestrictionConditionValue
	|						WHEN ResultsByDocument.ComparisonType = VALUE(Enum.DiscountValuesComparisonTypes.Greater)
	|							THEN ResultsByDocument.Amount > ResultsByDocument.RestrictionConditionValue
	|						WHEN ResultsByDocument.ComparisonType = VALUE(Enum.DiscountValuesComparisonTypes.LessOrEqual)
	|							THEN ResultsByDocument.Amount <= ResultsByDocument.RestrictionConditionValue
	|						ELSE ResultsByDocument.Amount < ResultsByDocument.RestrictionConditionValue
	|					END
	|			WHEN ResultsByDocument.UseRestrictionCriterionForSalesVolume = VALUE(Enum.DiscountSalesAmountLimit.Quantity)
	|				THEN CASE
	|						WHEN ResultsByDocument.ComparisonType = VALUE(Enum.DiscountValuesComparisonTypes.GreaterOrEqual)
	|							THEN ResultsByDocument.Quantity >= ResultsByDocument.RestrictionConditionValue
	|						WHEN ResultsByDocument.ComparisonType = VALUE(Enum.DiscountValuesComparisonTypes.Greater)
	|							THEN ResultsByDocument.Quantity > ResultsByDocument.RestrictionConditionValue
	|						WHEN ResultsByDocument.ComparisonType = VALUE(Enum.DiscountValuesComparisonTypes.LessOrEqual)
	|							THEN ResultsByDocument.Quantity <= ResultsByDocument.RestrictionConditionValue
	|						ELSE ResultsByDocument.Quantity < ResultsByDocument.RestrictionConditionValue
	|					END
	|			ELSE FALSE
	|		END
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP ResultsByDocument
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP SalesByProductsFilterGroups
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP SalesFilterByProducts
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP FilterSalesByProductsWithCharacteristics";
	
	ParameterName = GetQueryParameterFromRef(RefOnAssignmentCondition);
	QueryText = StrReplace(QueryText, "ParameterName", ParameterName);
	QueryBatch.Query.SetParameter(ParameterName, RefOnAssignmentCondition);
	
	QueryText = QueryText + "
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|";
	
	Return New Structure(
		"QueryText,
		|TablesCount,
		|ResultTableNumber,
		|TableName",
		QueryText,
		9,
		5,
		"DiscountForOneTimeSaleWithConditionByDocument" + ParameterName
	);
	
EndFunction

// The function generates a text of query for the products table by segments.
//
// Returns:
// Structure - Query text
//
Function QueryTextTableProducts() 
	
	QueryText =
	"SELECT ALLOWED
	|	ProductsTable.ConnectionKey AS ConnectionKey,
	|	CAST(ProductsTable.Products AS Catalog.Products) AS Products,
	|	ProductsTable.Characteristic AS Characteristic,
	|	ProductsTable.MeasurementUnit AS MeasurementUnit,
	|	ProductsTable.Quantity AS Quantity,
	|	ProductsTable.Price AS PricePerPack,
	|	ProductsTable.Quantity * ProductsTable.Price AS Amount
	|INTO TemporaryTableProducts
	|FROM
	|	&Products AS ProductsTable
	|
	|INDEX BY
	|	Products,
	|	Characteristic
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TemporaryTableProducts.ConnectionKey,
	|	TemporaryTableProducts.Products,
	|	TemporaryTableProducts.Characteristic,
	|	TemporaryTableProducts.MeasurementUnit,
	|	TemporaryTableProducts.Quantity,
	|	TemporaryTableProducts.PricePerPack,
	|	TemporaryTableProducts.Amount,
	|	TemporaryTableProducts.Products.PriceGroup AS PriceGroup,
	|	TemporaryTableProducts.Products.ProductsCategory AS ProductsCategory
	|FROM
	|	TemporaryTableProducts AS TemporaryTableProducts";
	
	
	QueryText = QueryText + "
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|";
	
	Return New Structure("QueryText, TablesCount, ResultTableNumber, TableName", QueryText, 2, 2, "Products");
	
EndFunction

// The function generates text of a query for the table of calculated discounts for one-time sale.
//
// Returns:
// String - Query text
//
Function QueryTextDiscountForPurchaseKit(QueryBatch, RefOnAssignmentCondition)

	QueryText =
	"SELECT
	|	TemporaryTableProducts.Products AS Products,
	|	TemporaryTableProducts.Characteristic AS Characteristic,
	|	SUM(TemporaryTableProducts.Quantity) AS Quantity
	|INTO GoodsQuantity
	|FROM
	|	TemporaryTableProducts AS TemporaryTableProducts
	|
	|GROUP BY
	|	TemporaryTableProducts.Products,
	|	TemporaryTableProducts.Characteristic
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DiscountConditionsPurchaseKit.Products,
	|	DiscountConditionsPurchaseKit.Characteristic,
	|	SUM(DiscountConditionsPurchaseKit.Quantity) AS Quantity
	|INTO PurchaseKit
	|FROM
	|	Catalog.DiscountConditions.PurchaseKit AS DiscountConditionsPurchaseKit
	|WHERE
	|	DiscountConditionsPurchaseKit.Ref = &ParameterName
	|
	|GROUP BY
	|	DiscountConditionsPurchaseKit.Products,
	|	DiscountConditionsPurchaseKit.Characteristic
	|
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	PurchaseKit.Products,
	|	PurchaseKit.Characteristic,
	|	CASE
	|		WHEN ISNULL(GoodsQuantity.Quantity, 0) = 0
	|				OR ISNULL(PurchaseKit.Quantity, 0) = 0
	|			THEN 0
	|		ELSE CASE
	|				WHEN (CAST(GoodsQuantity.Quantity / PurchaseKit.Quantity AS NUMBER(15, 0))) = (CAST(GoodsQuantity.Quantity / PurchaseKit.Quantity AS NUMBER(15, 3)))
	|					THEN CAST(GoodsQuantity.Quantity / PurchaseKit.Quantity AS NUMBER(15, 0))
	|				ELSE CASE
	|						WHEN (CAST(GoodsQuantity.Quantity / PurchaseKit.Quantity AS NUMBER(15, 0))) * PurchaseKit.Quantity - GoodsQuantity.Quantity >= 0
	|							THEN (CAST(GoodsQuantity.Quantity / PurchaseKit.Quantity AS NUMBER(15, 0))) - 1
	|						ELSE CAST(GoodsQuantity.Quantity / PurchaseKit.Quantity AS NUMBER(15, 0))
	|					END
	|			END
	|	END AS SetsNumber
	|INTO SetsTable
	|FROM
	|	PurchaseKit AS PurchaseKit
	|		LEFT JOIN GoodsQuantity AS GoodsQuantity
	|		ON PurchaseKit.Products = GoodsQuantity.Products
	|			AND PurchaseKit.Characteristic = GoodsQuantity.Characteristic
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(SetsTable.SetsNumber) AS SetsNumber,
	|	-1 AS ConnectionKey,
	|	&ParameterName AS Ref
	|INTO MinimumSetsNumberTable
	|FROM
	|	SetsTable AS SetsTable
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MinimumSetsNumberTable.SetsNumber AS SetsNumber,
	|	MinimumSetsNumberTable.ConnectionKey AS ConnectionKey,
	|	MinimumSetsNumberTable.Ref AS Ref
	|FROM
	|	MinimumSetsNumberTable AS MinimumSetsNumberTable
	|WHERE
	|	MinimumSetsNumberTable.SetsNumber >= 1
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP GoodsQuantity
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP PurchaseKit
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP SetsTable
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP MinimumSetsNumberTable";
	
	ParameterName = GetQueryParameterFromRef(RefOnAssignmentCondition);
	QueryText = StrReplace(QueryText, "ParameterName", ParameterName);
	QueryBatch.Query.SetParameter(ParameterName, RefOnAssignmentCondition);
	
	QueryText = QueryText + "
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|";
	
	Return New Structure(
		"QueryText,
		|TablesCount,
		|ResultTableNumber,
		|TableName",
		QueryText,
		9,
		5,
		"DiscountForForPurchaseKit" + ParameterName
	);
	
EndFunction

#EndRegion

#Region QueryBatchFunctions

// Function creates a package of queries.
//
// Returns:
// Structure - package of queries.
//
Function QueryBatchCreate()
	
	QueryBatch = New Structure;
	QueryBatch.Insert("CommonTablesCount", 0);
	QueryBatch.Insert("StructureQueryNameAndResultTableNumber", New Structure);
	QueryBatch.Insert("Query", New Query);
	QueryBatch.Insert("QueryResult", Undefined);
	QueryBatch.Insert("QueryNamesArray", New Array);
	
	Return QueryBatch;
	
EndFunction

// UniteSubordinateRowsDataTables adds a query to a package of queries.
//
// Returns:
// No
//
Procedure QueryBatchInsertQueryIntoPackage(QueryParameters, QueryBatch, Add = False)
	
	// Check for queries duplicate.
	If QueryBatch.QueryNamesArray.Find(QueryParameters.TableName) <> Undefined Then
		Return;
	EndIf;
	
	QueryBatch.CommonTablesCount = QueryBatch.CommonTablesCount + QueryParameters.TablesCount;
	SpreadsheetNumber = QueryBatch.CommonTablesCount - QueryParameters.TablesCount + QueryParameters.ResultTableNumber;
	QueryBatch.Query.Text = QueryBatch.Query.Text +
	"// Result table number: "+SpreadsheetNumber + "
	|";
	QueryBatch.Query.Text = QueryBatch.Query.Text + QueryParameters.QueryText;
	
	If Add Then
		
		QueryBatch.StructureQueryNameAndResultTableNumber.Insert(QueryParameters.TableName, SpreadsheetNumber);
		
	EndIf;
	
	QueryBatch.QueryNamesArray.Add(QueryParameters.TableName);
	
EndProcedure

// The function executes a package of queries.
//
// Returns:
// Boolean - True if the request was completed successfully.
//
Function QueryBatchExecute(QueryBatch)
	
	If ValueIsFilled(QueryBatch.Query.Text) Then
		QueryBatch.QueryResult = QueryBatch.Query.ExecuteBatch();
		Return True;
	Else
		Return False;
	EndIf;
	
EndFunction

// The function gets the query result from queries package by query name.
//
// Returns:
// QueryResult - Result of the query included in the package.
//
Function QueryBatchGetQueryResultByTableName(QueryName, QueryBatch)
	
	Return QueryBatch.QueryResult[QueryBatch.StructureQueryNameAndResultTableNumber[QueryName] - 1];
	
EndFunction

// The function unites all results of package queries in one table.
//
// Returns:
// QueryResult - Result of the query included in the package.
//
Function QueryBatchUniteResults(QueryBatch)
	
	VT = New ValueTable;
	VT.Columns.Add("Ref", New TypeDescription("CatalogRef.DiscountConditions"));
	VT.Columns.Add("ConnectionKey", New TypeDescription("Number"));
	VT.Columns.Add("SetsNumber", New TypeDescription("Number"));
	
	For Each KeyAndValue In QueryBatch.StructureQueryNameAndResultTableNumber Do
		
		Selection = QueryBatch.QueryResult[KeyAndValue.Value-1].Select();
		While Selection.Next() Do
			FillPropertyValues(VT.Add(), Selection);
		EndDo;
		
	EndDo;
	
	Return VT;
	
EndFunction

#EndRegion

#Region DiscountsMarkupsCalculationFunctionsByDiscountsMarkupsTree

Procedure ProcessDiscountsTree(DiscountsTree)
	
	For Each TreeRow In DiscountsTree.Rows Do
		
		If TreeRow.IsFolder Then
			
			ProcessDiscountsTree(TreeRow);
			
		Else
			
			LineCount = TreeRow.Rows.Count();
			If LineCount > 1 Then
				Raise NStr("en = 'An error occurred while generating discount tree'");
			EndIf;
			If LineCount > 0 Then
				FillPropertyValues(TreeRow, TreeRow.Rows[0]);
				//
				TreeRow.Rows.Delete(TreeRow.Rows[0]);
			EndIf;
			
		EndIf;
		
	EndDo;
	
EndProcedure

// The function gets the tree of applied discounts.
//
// Returns:
// ValueTree - tree of applied discounts.
//
Function GetDiscountsTree(DiscountsArray) Export
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	DiscountsMarkups.Ref                       AS DiscountMarkup,
	|	DiscountsMarkups.AdditionalOrderingAttribute    AS AdditionalOrderingAttribute,
	|	DiscountsMarkups.SharedUsageVariant AS SharedUsageVariant,
	|	DiscountsMarkups.RestrictionByProductsVariant AS RestrictionByProductsVariant,
	|	DiscountsMarkups.IsClarificationByProducts AS IsClarificationByProducts,
	|	DiscountsMarkups.IsClarificationByProductsCategories AS IsClarificationByProductsCategories,
	|	DiscountsMarkups.IsClarificationByPriceGroups AS IsClarificationByPriceGroups,
	|	DiscountsMarkups.ThereAreFoldersToBeClarifiedByProducts AS ThereAreFoldersToBeClarifiedByProducts,
	|
	// Required for display icons
	|	DiscountsMarkups.DeletionMark              AS DeletionMark,
	|	DiscountsMarkups.AssignmentMethod         AS AssignmentMethod,
	|	DiscountsMarkups.DiscountMarkupValue        AS DiscountMarkupValue,
	|	
	|	DiscountsMarkups.IsFolder                    AS IsFolder,
	|	
	|	DiscountsMarkups.ConditionsOfAssignment.(
	|		AssignmentCondition                    AS AssignmentCondition,
	|		AssignmentCondition.RestrictionArea AS RestrictionArea
	|	) AS ConditionsOfAssignment
	|FROM
	|	Catalog.AutomaticDiscountTypes AS DiscountsMarkups
	|WHERE
	|	DiscountsMarkups.Ref IN(&DiscountsArray)
	|	AND DiscountsMarkups.Acts
	|
	|ORDER BY
	|	DiscountsMarkups.AdditionalOrderingAttribute
	|Totals BY
	|	DiscountMarkup HIERARCHY";
	
	Query.SetParameter("DiscountsArray", DiscountsArray);
	Query.SetParameter("SharedUsageVariant", Constants.DefaultDiscountsApplyingRule.Get());
	
	DiscountsTree = Query.Execute().Unload(QueryResultIteration.ByGroupsWithHierarchy);
	
	ProcessDiscountsTree(DiscountsTree);
	
	Return DiscountsTree;
	
EndFunction

// The procedure calculates the discount by the shared usage group.
//
// Returns:
// No.
//
Procedure CalculateDiscountsByJointApplicationGroup(TreeRow, Parameters, TopLevel = False, FinalDataTable = Undefined)
	
	DataTable = UniteSubordinateRowsDataTables(TreeRow);
	
	Addition = False;
	If TopLevel Then
		SharedUsageVariant = Constants.DefaultDiscountsApplyingRule.Get();
	Else 
		// This option is required if during implementation it will be necessary to adjust the mechanism to indicate the
		// shared usage option in groups.
		SharedUsageVariant = TreeRow.SharedUsageVariant;
	EndIf;
	
	If SharedUsageVariant = Enums.DiscountsApplyingRules.Exclusion Then
		DataTable.Sort("ConnectionKey, AdditionalOrderingAttribute");
	ElsIf SharedUsageVariant = Enums.DiscountsApplyingRules.Max Then
		DataTable.Sort("ConnectionKey, Amount Desc, AdditionalOrderingAttribute");
	ElsIf SharedUsageVariant = Enums.DiscountsApplyingRules.Minimum Then
		DataTable.Sort("ConnectionKey, Amount Asc, AdditionalOrderingAttribute");
	ElsIf SharedUsageVariant = Enums.DiscountsApplyingRules.Addition
		OR SharedUsageVariant = Enums.DiscountsApplyingRules.Multiplication Then
		DataTable.Sort("ConnectionKey");
		Addition = True;
	Else
		DataTable.Sort("ConnectionKey");
		Addition = True;
	EndIf;
	
	VT = GetEmptyDiscountsTableWithDetails(Parameters);
	
	ConnectionKey = -1;
	For Each TableRow In DataTable Do
		
		If TableRow.ConnectionKey <> ConnectionKey Then
			
			NewRowVT = VT.Add();
			NewRowVT.ConnectionKey = TableRow.ConnectionKey;
			NewRowVT.Amount = TableRow.Amount;
			NewRowVT.Acts = True;
			
			// Discount details.
			NewRowVT.Details = Parameters.EmptyTableDecryption.CopyColumns();
			For Each RowOfDetails In TableRow.Details Do
				FillPropertyValues(NewRowVT.Details.Add(), RowOfDetails);
			EndDo;
			
			ConnectionKey = TableRow.ConnectionKey;
			
		Else
			
			If Addition Then
				NewRowVT.Amount = NewRowVT.Amount + TableRow.Amount;
				For Each RowOfDetails In TableRow.Details Do
					FillPropertyValues(NewRowVT.Details.Add(), RowOfDetails);
				EndDo;
			EndIf;
			
		EndIf;
		
	EndDo;
	
	If TopLevel Then
		FinalDataTable = VT;
	Else
		TreeRow.DataTable = VT;
	EndIf;
	
EndProcedure

// The procedure calculates the discount of the discount tree.
//
// Returns:
// No.
//
Procedure CalculateDiscount(TreeRow, Parameters)
	
	If Not TreeRow.ConditionsParameters.ConditionsFulfilled Then
		Return;
	EndIf;
	
	DiscountParameters = Parameters.DiscountsMarkups.Find(TreeRow.DiscountMarkup, "DiscountMarkup");
	
	Products = TreeRow.ProductsTable;
	
	DiscountsMarkupsByPriceGroups = Parameters.DiscountsMarkupsByPriceGroups.FindRows(New Structure("DiscountMarkup", TreeRow.DiscountMarkup));
	DiscountsMarkupsByProductsGroups = Parameters.DiscountsMarkupsByProductsGroups.FindRows(New Structure("DiscountMarkup", TreeRow.DiscountMarkup));
	DiscountsMarkupsByProducts = Parameters.DiscountsMarkupsByProducts.FindRows(New Structure("DiscountMarkup", TreeRow.DiscountMarkup));
	
	If TreeRow.Parent = Undefined Then
		ThisIsMultiplication = Constants.DefaultDiscountsApplyingRule.Get() = Enums.DiscountsApplyingRules.Multiplication;
	Else
		ThisIsMultiplication = TreeRow.Parent.SharedUsageVariant = Enums.DiscountsApplyingRules.Multiplication;
	EndIf;
	
	DataTable = GetEmptyDiscountsTableWithDetails(Parameters);
	
	AppliedUnconditionally = TreeRow.ConditionsParameters.ConditionsFulfilled AND TreeRow.ConditionsParameters.TableConditions.Count() = 0;
	
	If DiscountParameters.AssignmentMethod = Enums.DiscountValueType.Percent Then
		
		For Each Product In Products Do
			
			NewRow           = DataTable.Add();
			NewRow.ConnectionKey = Product.ConnectionKey;
			NewRow.Acts = True;
			
			// If the discount is not valid for the given row - skip.
			If Not AppliedUnconditionally Then
				If TreeRow.ConditionsParameters.TableConditions.FindRows(New Structure("RestrictionArea", Enums.DiscountApplyingArea.AtRow)).Count() > 0 Then
					If TreeRow.ConditionsParameters.LinesCodes.Find(Product.ConnectionKey) = Undefined Then
						NewRow.Acts = False;
					EndIf;
				EndIf;
			EndIf;
			
			Amount = Product.Amount;

			DiscountMarkupValue = DiscountParameters.DiscountMarkupValue;
			
			// Searching for discount values by price group.
			If TreeRow.IsClarificationByPriceGroups Then
				For Each TSRow In DiscountsMarkupsByPriceGroups Do
					If TSRow.ValueClarification = Product.PriceGroup Then
						DiscountMarkupValue = TSRow.DiscountMarkupValue;
						Break;
					EndIf;
				EndDo;
			// Searching for discount values by product group.
			ElsIf TreeRow.IsClarificationByProductsCategories Then
				For Each TSRow In DiscountsMarkupsByProductsGroups Do
					If TSRow.ValueClarification = Product.ProductsCategory Then
						DiscountMarkupValue = TSRow.DiscountMarkupValue;
						Break;
					EndIf;
				EndDo;
			// Searching for discount values by product.
			ElsIf TreeRow.IsClarificationByProducts Then
				If Not TreeRow.ThereAreFoldersToBeClarifiedByProducts Then
					If Product.Characteristic.IsEmpty() Then
						For Each TSRow In DiscountsMarkupsByProducts Do
							If TSRow.ValueClarification = Product.Products AND TSRow.Characteristic.IsEmpty() Then
								DiscountMarkupValue = TSRow.DiscountMarkupValue;
								Break;
							EndIf;
						EndDo;
					Else
						ThereIsValueForCharacteristic = False;
						ValueForCharacteristics = 0;
						For Each TSRow In DiscountsMarkupsByProducts Do
							If TSRow.ValueClarification = Product.Products AND TSRow.Characteristic = Product.Characteristic Then
								DiscountMarkupValue = TSRow.DiscountMarkupValue;
								ThereIsValueForCharacteristic = True;
								ValueForCharacteristics = DiscountMarkupValue;
								Break;
							ElsIf TSRow.ValueClarification = Product.Products AND TSRow.Characteristic.IsEmpty() Then
								DiscountMarkupValue = TSRow.DiscountMarkupValue;
							EndIf;
						EndDo;
						
						If ThereIsValueForCharacteristic Then
							DiscountMarkupValue = ValueForCharacteristics;
						EndIf;
					EndIf;
				Else
					// Search including the hierarchy.
					CurAdjustmentValue = GetClarificationValueIncludingHierarchy(DiscountsMarkupsByProducts, Product.Products, Product.Characteristic);
					If CurAdjustmentValue <> Undefined Then
						DiscountMarkupValue = CurAdjustmentValue;
					EndIf;
				EndIf;
			EndIf;
		    
			DiscountAmount = Round((DiscountMarkupValue / 100) * Amount, 2);
			
			NewRow.Amount = DiscountAmount;
			
			NewRow.Details = GetDiscountDetails(TreeRow, NewRow.Amount, Parameters);
			
		EndDo;
		
	ElsIf DiscountParameters.AssignmentMethod = Enums.DiscountValueType.Amount Then
		
		DiscountAmountForDistribution = DiscountParameters.DiscountMarkupValue;
		
		If DiscountParameters.AssignmentArea = Enums.DiscountApplyingArea.InDocument Then
			
			// Calculation of segment products total amount.
			SegmentProductsTotalAmount = 0;
			For Each Product In Products Do
				SegmentProductsTotalAmount = SegmentProductsTotalAmount + Product.Amount;
			EndDo;
			
			DiscountRowForDistribution = Undefined;
			MaximumAmountInDistribution = 0;
			// Distribution of discount by segment products.
			For Each Product In Products Do
				
				NewRow           = DataTable.Add();
				NewRow.ConnectionKey = Product.ConnectionKey;
				NewRow.Acts = True;
				
				Amount = Product.Amount;
				
				If Amount > MaximumAmountInDistribution Then
					MaximumAmountInDistribution = Amount;
					DiscountRowForDistribution = NewRow;
				EndIf;
				
				If SegmentProductsTotalAmount <> 0 Then
					NewRow.Amount = Round(Amount * (DiscountAmountForDistribution / SegmentProductsTotalAmount), 2);
				Else
					NewRow.Amount = 0;
				EndIf;
				
				DiscountAmountForDistribution = DiscountAmountForDistribution - NewRow.Amount;
				SegmentProductsTotalAmount = SegmentProductsTotalAmount - Amount;

				NewRow.Details = GetDiscountDetails(TreeRow, NewRow.Amount, Parameters);
				
			EndDo;
			
			If DiscountAmountForDistribution <> 0 AND DiscountRowForDistribution <> Undefined Then
				DiscountRowForDistribution.Amount = DiscountRowForDistribution.Amount + DiscountAmountForDistribution;
			EndIf;
			
		ElsIf DiscountParameters.AssignmentArea = Enums.DiscountApplyingArea.AtRow Then
			
			ThereAreConditionsByLine = TreeRow.ConditionsParameters.TableConditions.FindRows(New Structure("RestrictionArea", Enums.DiscountApplyingArea.AtRow)).Count() > 0;
			
			For Each Product In Products Do
				
				DiscountMarkupValue = DiscountParameters.DiscountMarkupValue;
				
				// Searching for discount values by price group.
				If TreeRow.IsClarificationByPriceGroups Then
					For Each TSRow In DiscountsMarkupsByPriceGroups Do
						If TSRow.ValueClarification = Product.PriceGroup Then
							DiscountMarkupValue = TSRow.DiscountMarkupValue;
							Break;
						EndIf;
					EndDo;
				// Searching for discount values by product group.
				ElsIf TreeRow.IsClarificationByProductsCategories Then
					For Each TSRow In DiscountsMarkupsByProductsGroups Do
						If TSRow.ValueClarification = Product.ProductsCategory Then
							DiscountMarkupValue = TSRow.DiscountMarkupValue;
						EndIf;
					EndDo;
				// Searching for discount values by product.
				ElsIf TreeRow.IsClarificationByProducts Then
					If Not TreeRow.ThereAreFoldersToBeClarifiedByProducts Then
						If Product.Characteristic.IsEmpty() Then
							For Each TSRow In DiscountsMarkupsByProducts Do
								If TSRow.ValueClarification = Product.Products AND TSRow.Characteristic.IsEmpty() Then
									DiscountMarkupValue = TSRow.DiscountMarkupValue;
									Break;
								EndIf;
							EndDo;
						Else
							ThereIsValueForCharacteristic = False;
							ValueForCharacteristics = 0;
							For Each TSRow In DiscountsMarkupsByProducts Do
								If TSRow.ValueClarification = Product.Products AND TSRow.Characteristic = Product.Characteristic Then
									DiscountMarkupValue = TSRow.DiscountMarkupValue;
									ThereIsValueForCharacteristic = True;
									ValueForCharacteristics = DiscountMarkupValue;
									Break;
								ElsIf TSRow.ValueClarification = Product.Products AND TSRow.Characteristic.IsEmpty() Then
									DiscountMarkupValue = TSRow.DiscountMarkupValue;
								EndIf;
							EndDo;
							
							If ThereIsValueForCharacteristic Then
								DiscountMarkupValue = ValueForCharacteristics;
							EndIf;
						EndIf;
					Else
						// Search including the hierarchy.
						CurAdjustmentValue = GetClarificationValueIncludingHierarchy(DiscountsMarkupsByProducts, Product.Products, Product.Characteristic);
						If CurAdjustmentValue <> Undefined Then
							DiscountMarkupValue = CurAdjustmentValue;
						EndIf;
					EndIf;
				EndIf;
			    				
				NewRow = DataTable.Add();
				
				If Not ThereAreConditionsByLine OR AppliedUnconditionally OR TreeRow.ConditionsParameters.LinesCodes.Find(Product.ConnectionKey) <> Undefined Then
					NewRow.Acts = True;
				EndIf;
				
				NewRow.ConnectionKey   = Product.ConnectionKey;
				NewRow.Amount       = DiscountMarkupValue;
				NewRow.Details = GetDiscountDetails(TreeRow, NewRow.Amount, Parameters);
				
			EndDo;
			
		EndIf;
		
	EndIf;
	
	TreeRow.DataTable   = DataTable;
	
	
EndProcedure

// Returns the adjusted value of an automatic discount for the specified product with
// regard to its characteristic and hierarchy.
//
Function GetClarificationValueIncludingHierarchy(DiscountsMarkupsByProducts, Products, Characteristic)
	
	// Example. IN SP Product0 is selected, Product1 (10%), Product2 (20%) and Group1 (15%) are selected in the adjustment.
	// Product0 can be equal to Product1 or Product2 or can be in the hierarchy of Group1.
	
	QueryTextPattern = "SELECT
	                      |	&DiscountMarkupValue AS DiscountMarkupValue
	                      |FROM
	                      |	Catalog.Products AS Products
	                      |WHERE
	                      |	Products.Ref = &Ref
	                      |	AND Products.Ref IN HIERARCHY(&ValueClarification)";

	CtQueries = 0;
	QueryText = "";
	Query = New Query;
	Query.SetParameter("Ref", Products);
	
	ThereIsValueWithoutCharacteristic = False;
	ValueWithoutCharacteristic = 0;
	For Each CurAdjustment In DiscountsMarkupsByProducts Do
		If Not CurAdjustment.IsFolder AND Characteristic.IsEmpty() Then
			If CurAdjustment.ValueClarification = Products AND CurAdjustment.Characteristic.IsEmpty() Then
				Return CurAdjustment.DiscountMarkupValue;
			EndIf;
		ElsIf Not CurAdjustment.IsFolder Then
			If CurAdjustment.ValueClarification = Products AND CurAdjustment.Characteristic = Characteristic Then
				Return CurAdjustment.DiscountMarkupValue;
			ElsIf CurAdjustment.ValueClarification = Products AND CurAdjustment.Characteristic.IsEmpty() Then
				ThereIsValueWithoutCharacteristic = True;
				ValueWithoutCharacteristic = CurAdjustment.DiscountMarkupValue;
			EndIf;
		ElsIf CurAdjustment.IsFolder Then
			CtQueries = CtQueries + 1;
			
			TemplateProcessedText = StrReplace(QueryTextPattern, "&ValueClarification", "&ValueClarification"+CtQueries);
			TemplateProcessedText = StrReplace(TemplateProcessedText, "&DiscountMarkupValue", "&DiscountMarkupValue"+CtQueries);
			
			Query.SetParameter("ValueClarification"+CtQueries, CurAdjustment.ValueClarification);
			Query.SetParameter("DiscountMarkupValue"+CtQueries, CurAdjustment.DiscountMarkupValue);
			
			Query.Text = Query.Text + TemplateProcessedText+Chars.LF+"
				|;
				|
				|////////////////////////////////////////////////////////////////////////////////
				|";
		EndIf;
	EndDo;
	
	If ThereIsValueWithoutCharacteristic Then
		Return ValueWithoutCharacteristic;
	EndIf;
	
	If CtQueries > 0 Then
	
		MClarificationResults = Query.ExecuteBatch();
		
		CtQueries = 0;
		While CtQueries < MClarificationResults.Count() Do
			If Not MClarificationResults[CtQueries].IsEmpty() Then
				Return MClarificationResults[CtQueries].Unload()[0].DiscountMarkupValue;
			EndIf;
			CtQueries = CtQueries + 1;
		EndDo;
		
	EndIf;
	
	Return Undefined;
	
EndFunction

// The procedure recursively avoids the
// tree and calculates discounts bottom-up: from subordinate tree item to the parent.
//
// Returns:
// No.
//
Procedure CalculateDiscountsRecursively(DiscountsTree, Parameters)
	
	For Each TreeRow In DiscountsTree.Rows Do
		
		If TreeRow.Parent = Undefined Then
			// this is the top level
			NQ = New NumberQualifiers(15,2);
			Array = New Array;
			Array.Add(Type("Number"));
			TypeDescriptionNumber = New TypeDescription(Array, , ,NQ);
			TreeRow.ProductsTable = Parameters.Products.Copy();
		Else
			TreeRow.ProductsTable = TreeRow.Parent.ProductsTable.Copy();
		EndIf;
		
		If TreeRow.IsFolder Then
			
			CalculateDiscountsRecursively(TreeRow, Parameters);
			
			// Discounts by subordinate elements are calculated.
			// Calculation of discounts by shared usage group (parent).
			CalculateDiscountsByJointApplicationGroup(TreeRow, Parameters);
			
			If TreeRow.Parent <> Undefined
				AND TreeRow.Parent.SharedUsageVariant = Enums.DiscountsApplyingRules.Multiplication Then
				// You should reduce the amount in the parent row of the products
				// table by the current amount of the discounts as subsequent usage of the groups also assumes that all subsequent
				// discounts will be calculated from the amount with inclusion of already provided discounts of this group
				For Each ParentProductRow In TreeRow.Parent.ProductsTable Do
					SearchStructure = New Structure;
					SearchStructure.Insert("ConnectionKey", ParentProductRow.ConnectionKey);
					SearchStructure.Insert("Acts", True);
					CalculatedDiscountsRows = TreeRow.DataTable.FindRows(SearchStructure);
					For Each FoundString In CalculatedDiscountsRows Do
						ParentProductRow.Amount = ParentProductRow.Amount - FoundString.Amount;
						ParentProductRow.DiscountAmount = ParentProductRow.DiscountAmount + FoundString.Amount;
					EndDo;
				EndDo;
			ElsIf TreeRow.Parent = Undefined
				AND Constants.DefaultDiscountsApplyingRule.Get() = Enums.DiscountsApplyingRules.Multiplication Then
				// You should reduce the amount in the parent row of the products
				// table by the current amount of the discounts as consistent application assumes that all
				// subsequent discounts will be calculated from the amount inclusive of already provided discounts of this group
				For Each ParentProductRow In Parameters.Products Do
					SearchStructure = New Structure;
					SearchStructure.Insert("ConnectionKey", ParentProductRow.ConnectionKey);
					SearchStructure.Insert("Acts", True);
					CalculatedDiscountsRows = TreeRow.DataTable.FindRows(SearchStructure);
					For Each FoundString In CalculatedDiscountsRows Do
						ParentProductRow.Amount = ParentProductRow.Amount - FoundString.Amount;
						ParentProductRow.DiscountAmount = ParentProductRow.DiscountAmount + FoundString.Amount;
					EndDo;
				EndDo;
			EndIf;
			
		Else
			
			CalculateDiscount(TreeRow, Parameters);
			
			If TreeRow.Parent <> Undefined
				AND TreeRow.Parent.SharedUsageVariant = Enums.DiscountsApplyingRules.Multiplication
				AND TreeRow.ConditionsParameters.ConditionsFulfilled Then
				// You should reduce the amount in the parent row of the products
				// table by the current amount of the discounts as consistent application assumes that all
				// subsequent discounts will be calculated from the amount inclusive of already provided discounts of this group
				For Each ParentProductRow In TreeRow.Parent.ProductsTable Do
					SearchStructure = New Structure;
					SearchStructure.Insert("ConnectionKey", ParentProductRow.ConnectionKey);
					SearchStructure.Insert("Acts", True);
					CalculatedDiscountsRows = TreeRow.DataTable.FindRows(SearchStructure);
					For Each FoundString In CalculatedDiscountsRows Do
						ParentProductRow.Amount = ParentProductRow.Amount - FoundString.Amount;
						ParentProductRow.DiscountAmount = ParentProductRow.DiscountAmount + FoundString.Amount;
					EndDo;
				EndDo;
			ElsIf TreeRow.Parent = Undefined
				AND Constants.DefaultDiscountsApplyingRule.Get() = Enums.DiscountsApplyingRules.Multiplication
				AND TreeRow.ConditionsParameters.ConditionsFulfilled Then
				// You should reduce the amount in the parent row of the products
				// table by the current amount of the discounts as consistent application assumes that all
				// subsequent discounts will be calculated from the amount inclusive of already provided discounts of this group
				For Each ParentProductRow In Parameters.Products Do
					SearchStructure = New Structure;
					SearchStructure.Insert("ConnectionKey", ParentProductRow.ConnectionKey);
					SearchStructure.Insert("Acts", True);
					CalculatedDiscountsRows = TreeRow.DataTable.FindRows(SearchStructure);
					For Each FoundString In CalculatedDiscountsRows Do
						ParentProductRow.Amount = ParentProductRow.Amount - FoundString.Amount;
						ParentProductRow.DiscountAmount = ParentProductRow.DiscountAmount + FoundString.Amount;
					EndDo;
				EndDo;
			EndIf;
			
		EndIf;
		
	EndDo;
	
EndProcedure

// The function makes a complete calculation of discounts in the tree.
//
// Returns:
// ValueTable - Table with calculated discounts.
//
Function CalculatedDiscountsStructure(DiscountsTree, Parameters)
	
	ReturnedData = New Structure;
	
	NQ = New NumberQualifiers(15,2);
	Array = New Array;
	Array.Add(Type("Number"));
	TypeDescriptionNumber = New TypeDescription(Array, , ,NQ);
	Parameters.Products.Columns.Add("DiscountAmount", TypeDescriptionNumber);
	CalculateDiscountsRecursively(DiscountsTree, Parameters);
	
	// On top level...
	DataTable = Undefined;
	CalculateDiscountsByJointApplicationGroup(DiscountsTree, Parameters, True, DataTable);
	
	VT = New ValueTable;
	VT.Columns.Add("ConnectionKey",					New TypeDescription("Number"));
	VT.Columns.Add("DiscountMarkup",				New TypeDescription("CatalogRef.AutomaticDiscountTypes"));
	VT.Columns.Add("Amount",						New TypeDescription("Number"));
	VT.Columns.Add("LimitedByMinimumPrice",	New TypeDescription("Boolean"));
	
	For Each TableRow In DataTable Do
		If Not TableRow.ConnectionKey = 0  Then
			For Each RowDiscountsMarkups In TableRow.Details Do
				NewRow								= VT.Add();
				NewRow.ConnectionKey					= TableRow.ConnectionKey;
				NewRow.DiscountMarkup				= RowDiscountsMarkups.DiscountMarkup;
				NewRow.Amount						= RowDiscountsMarkups.Amount;
				NewRow.LimitedByMinimumPrice	= RowDiscountsMarkups.LimitedByMinimumPrice;
			EndDo;
		Else
			For Each RowDiscountsMarkups In TableRow.Details Do
				SearchStructure = New Structure;
				SearchStructure.Insert("DiscountMarkup", RowDiscountsMarkups.DiscountMarkup);
			EndDo;
		EndIf;
	EndDo;
	
	VT.GroupBy("ConnectionKey, DiscountMarkup, LimitedByMinimumPrice", "Amount");
	
	ReturnedData.Insert("DiscountsTree", 		DiscountsTree);
	ReturnedData.Insert("TableDiscountsMarkups", VT);
	
	Return ReturnedData;
	
EndFunction

#EndRegion

#Region CheckProceduresForDiscountsMarkupsConditions

// The function checks the fullfillment of discount conditions.
//
Function CheckConditions(TreeRow, FullfilledConditions)
	
	TreeRow.ConditionsParameters.Insert("ConditionsFulfilled", True);
	TreeRow.ConditionsParameters.Insert("LinesCodes",        New Array);
	TreeRow.ConditionsParameters.Insert("ConditionsByLine",  New Structure);
	TreeRow.ConditionsParameters.Insert("TableConditions",   New ValueTable);
	
	// Service table for temporary storage of results of provision terms check
	TreeRow.ConditionsParameters.TableConditions.Columns.Add("AssignmentCondition", New TypeDescription("CatalogRef.DiscountConditions"));
	TreeRow.ConditionsParameters.TableConditions.Columns.Add("RestrictionArea",    New TypeDescription("EnumRef.DiscountApplyingArea"));
	TreeRow.ConditionsParameters.TableConditions.Columns.Add("Completed");
	
	// The table is applied to check fullfillment of the conditions by the line.
	// If a discount has conditions by the line, then a new column will be created in the table for these conditions
	TreeRow.ConditionsParameters.ConditionsByLine.Insert("ConditionsCheckingTable", New ValueTable);
	TreeRow.ConditionsParameters.ConditionsByLine.ConditionsCheckingTable.Columns.Add("ConnectionKey");
	TreeRow.ConditionsParameters.ConditionsByLine.ConditionsCheckingTable.Indexes.Add("ConnectionKey");
	
	TreeRow.ConditionsParameters.ConditionsByLine.Insert("MatchConditionTableColumnsWithConditionsCheckingTable", New Map);
	
	// Service parameters
	ConditionsCheckingTableIsUsed      = False;
	ThisIsFirstConditionForConditionsCheckTable  = True;
	ConditionsCheckTableColumnsNumber = 0;
	
	// We bypass all conditions of one discount.
	For Each Condition In TreeRow.ConditionsOfAssignment Do
		
		RowConditionsTable = TreeRow.ConditionsParameters.TableConditions.Add();
		RowConditionsTable.AssignmentCondition = Condition.AssignmentCondition;
		RowConditionsTable.RestrictionArea    = Condition.RestrictionArea;
		
		FoundStrings = FullfilledConditions.FindRows(New Structure("Ref", Condition.AssignmentCondition));
		
		If FoundStrings.Count() = 0 Then
			
			// Condition is not completed.
			RowConditionsTable.Completed = False;
			
			TreeRow.ConditionsParameters.ConditionsFulfilled = False;
			
		ElsIf FoundStrings.Count() = 1 AND FoundStrings[0].ConnectionKey = -1 Then
			
			RowConditionsTable.Completed = True;
			// The condition is fullfilled. The condition does not depend on specific lines.
			
		Else
			
			RowConditionsTable.Completed = True;
			// The condition is fullfilled. Several rows were found which passed conditions check.
			
			ConditionsCheckTableColumnsNumber = ConditionsCheckTableColumnsNumber + 1;
			ColumnsTitle = "Condition" + ConditionsCheckTableColumnsNumber;
			
			TreeRow.ConditionsParameters.ConditionsByLine.MatchConditionTableColumnsWithConditionsCheckingTable.Insert(Condition.AssignmentCondition, ColumnsTitle);
			TreeRow.ConditionsParameters.ConditionsByLine.ConditionsCheckingTable.Columns.Add(ColumnsTitle, New TypeDescription("Boolean"));
			
			For Each FoundString In FoundStrings Do
				
				ConditionsCheckingTableIsUsed = True;
				
				FoundConditionsCheckingTableRows = TreeRow.ConditionsParameters.ConditionsByLine.ConditionsCheckingTable.Find(FoundString.ConnectionKey, "ConnectionKey");
				If FoundConditionsCheckingTableRows <> Undefined Then
					FoundConditionsCheckingTableRows[ColumnsTitle] = True;
				Else
					If ThisIsFirstConditionForConditionsCheckTable Then
						NewRow1 = TreeRow.ConditionsParameters.ConditionsByLine.ConditionsCheckingTable.Add();
						NewRow1.ConnectionKey = FoundString.ConnectionKey;
						NewRow1[ColumnsTitle] = True;
					EndIf;
				EndIf;
				
			EndDo;
			
		EndIf;
		
		If ConditionsCheckingTableIsUsed Then
			ThisIsFirstConditionForConditionsCheckTable = False;
		EndIf;
		
	EndDo;
	
	// We will fill codes lines...
	If TreeRow.ConditionsParameters.ConditionsFulfilled Then
		
		If TreeRow.ConditionsParameters.ConditionsByLine.MatchConditionTableColumnsWithConditionsCheckingTable.Count() > 0 Then
			
			Filter = New Structure;
			For Each KeyAndValue In TreeRow.ConditionsParameters.ConditionsByLine.MatchConditionTableColumnsWithConditionsCheckingTable Do
				Filter.Insert(KeyAndValue.Value, True);
			EndDo;
			
			FoundStrings = TreeRow.ConditionsParameters.ConditionsByLine.ConditionsCheckingTable.FindRows(Filter);
			For Each VTRow In FoundStrings Do
				TreeRow.ConditionsParameters.LinesCodes.Add(VTRow.ConnectionKey);
			EndDo;
			
		EndIf;
		
	EndIf;

EndFunction

// The function fills service attribultes in rows of discounts tree.
//
Procedure CheckConditionsRecursively(DiscountsTree, FullfilledConditions)
	
	For Each TreeRow In DiscountsTree.Rows Do
		
		If TreeRow.IsFolder Then
			
			CheckConditionsRecursively(TreeRow, FullfilledConditions);
			
		Else
			
			CheckConditions(TreeRow, FullfilledConditions);
			
		EndIf;
		
	EndDo;
	
EndProcedure

#EndRegion

#Region ProceduresForDiscountsMarkupsCalculationByDocuments

// Calculates discounts.
//
Function CalculateDiscountsMarkupsTree(CalculationParameters, InputParameters) Export
	
	FirstQueryBatch = QueryBatchCreate();
	SecondQueryBatch = QueryBatchCreate();
	
	For Each PackageParameter In CalculationParameters Do
		FirstQueryBatch.Query.SetParameter(PackageParameter.Key, PackageParameter.Value);
		SecondQueryBatch.Query.SetParameter(PackageParameter.Key, PackageParameter.Value);
	EndDo;
	
	TempTablesManager = New TempTablesManager;
	FirstQueryBatch.Query.TempTablesManager = TempTablesManager;
	SecondQueryBatch.Query.TempTablesManager = TempTablesManager;
	
	// Preparation and execution of the first package.
	QueryBatchInsertQueryIntoPackage(DiscountsMarkupsServerOverridable.QueryTextTableExchangeRates(),				FirstQueryBatch);
	QueryBatchInsertQueryIntoPackage(QueryTextDiscountsMarkupsTable(InputParameters.OnlyPreliminaryCalculation), 	FirstQueryBatch, True);
	QueryBatchInsertQueryIntoPackage(QueryTextTableAssignmentCondition(),         								FirstQueryBatch, True);
	QueryBatchInsertQueryIntoPackage(QueryTextDiscountMarkupTableByPriceGroups(), 								FirstQueryBatch, True);
	QueryBatchInsertQueryIntoPackage(QueryTextDiscountsMarkupsTableByProductsGroups(), 						FirstQueryBatch, True);
	QueryBatchInsertQueryIntoPackage(QueryTextTableDiscountsMarkupsByProducts(), 						FirstQueryBatch, True);
	QueryBatchInsertQueryIntoPackage(QueryTextTableProducts(),											FirstQueryBatch, True);
	
	QueryBatchExecute(FirstQueryBatch);
	
	// Preparation and execution of the second package.
	// IN the second package values of provision conditions are calculated.
	// A separate package request is formed for each condition of provision.
	SelectionAssignmentConditions = QueryBatchGetQueryResultByTableName("ConditionsOfAssignment", FirstQueryBatch).Select();
	While SelectionAssignmentConditions.Next() Do
		If SelectionAssignmentConditions.AssignmentCondition = Enums.DiscountCondition.ForOneTimeSalesVolume Then
			If SelectionAssignmentConditions.RestrictionArea = Enums.DiscountApplyingArea.AtRow Then
				QueryParameters = QueryTextDiscountForOneTimeSaleWithConditionByLine(SecondQueryBatch, SelectionAssignmentConditions.Ref);
				QueryBatchInsertQueryIntoPackage(QueryParameters, SecondQueryBatch, True);
			Else
				QueryParameters = QueryTextDiscountForOneTimeSaleWithConditionByDocument(SecondQueryBatch, SelectionAssignmentConditions.Ref);
				QueryBatchInsertQueryIntoPackage(QueryParameters, SecondQueryBatch, True);
			EndIf;
		EndIf;
		
		If SelectionAssignmentConditions.AssignmentCondition = Enums.DiscountCondition.ForKitPurchase Then
			QueryParameters = QueryTextDiscountForPurchaseKit(SecondQueryBatch, SelectionAssignmentConditions.Ref);
			QueryBatchInsertQueryIntoPackage(QueryParameters, SecondQueryBatch, True);
		EndIf;
	EndDo;
	
	QueryBatchExecute(SecondQueryBatch);
	
	TableFullfilledConditions = QueryBatchUniteResults(SecondQueryBatch);
	
	TableDiscountsMarkups      = QueryBatchGetQueryResultByTableName("DiscountsMarkups", FirstQueryBatch).Unload();
	
	DiscountsTree = GetDiscountsTree(TableDiscountsMarkups.UnloadColumn("DiscountMarkup"));
	DiscountsTree.Columns.Add("DataTable"    , New TypeDescription("ValueTable"));
	DiscountsTree.Columns.Add("ProductsTable"	 , New TypeDescription("ValueTable"));
	DiscountsTree.Columns.Add("ConditionsParameters" , New TypeDescription("Structure"));
	
	CheckConditionsRecursively(DiscountsTree, TableFullfilledConditions);
	DiscountsTree.Columns.Delete(DiscountsTree.Columns.ConditionsOfAssignment);
	
	If InputParameters.OnlyPreliminaryCalculation Then
		
		VT = New ValueTable;
		VT.Columns.Add("ConnectionKey",     New TypeDescription("Number"));
		VT.Columns.Add("DiscountMarkup", New TypeDescription("CatalogRef.DiscountsMarkups"));
		VT.Columns.Add("Amount",         New TypeDescription("Number"));
		
		ReturnedData = New Structure;
		ReturnedData.Insert("DiscountsTree", DiscountsTree);
		ReturnedData.Insert("TableDiscountsMarkups", VT);
		
		Return ReturnedData;
		
	EndIf;
	
	
	// Preparation of parameters for discounts calculation.
	Parameters = New Structure;
	// Adjustment of discount amount by price group, product group or products. By products - with account of the hierarchy.
	Parameters.Insert("DiscountsMarkupsByPriceGroups", QueryBatchGetQueryResultByTableName("DiscountsMarkupsByPriceGroups", FirstQueryBatch).Unload());
	Parameters.Insert("DiscountsMarkupsByProductsGroups", QueryBatchGetQueryResultByTableName("DiscountsMarkupsByProductsGroups", FirstQueryBatch).Unload());
	Parameters.Insert("DiscountsMarkupsByProducts", QueryBatchGetQueryResultByTableName("DiscountsMarkupsByProducts", FirstQueryBatch).Unload());
	Parameters.Insert("Products"            , QueryBatchGetQueryResultByTableName("Products"            , FirstQueryBatch).Unload());
	Parameters.Insert("DiscountsMarkups"                , TableDiscountsMarkups);
	
	Details = New ValueTable;
	Details.Columns.Add("DiscountMarkup",				New TypeDescription("CatalogRef.AutomaticDiscountTypes"));
	Details.Columns.Add("Amount",				        New TypeDescription("Number"));
	Details.Columns.Add("LimitedByMinimumPrice",	New TypeDescription("Boolean"));
	
	// Empty spreadsheets.
	Parameters.Insert("EmptyDiscountsTableWithDetails", Undefined);
	Parameters.Insert("EmptyTableDecryption"        , Details);
	
	Parameters.Insert("CurrentDate", CalculationParameters.CurrentDate);
	
	// Tables indexing
	Parameters.DiscountsMarkups.Indexes.Add("DiscountMarkup");
	
	DiscountsStructure = CalculatedDiscountsStructure(DiscountsTree, Parameters);
	
	Return DiscountsStructure;
	
EndFunction

// Applies the result of discount calculation to an object.
// Appears from document forms.
//
Procedure ApplyDiscountCalculationResultToObject(Object, TSName, DiscountsMarkupsCalculationResult, SalesExceedingOrder = False, GoodsBeyondOrder = Undefined, NameSP2 = Undefined) Export
	
	If SalesExceedingOrder AND ValueIsFilled(GoodsBeyondOrder) Then
		For Each CurrentDiscountMarkup In DiscountsMarkupsCalculationResult Do
			If GoodsBeyondOrder.Find(CurrentDiscountMarkup.ConnectionKey) <> Undefined Then
				NewRowDiscountsMarkups = Object.DiscountsMarkups.Add();
				FillPropertyValues(NewRowDiscountsMarkups, CurrentDiscountMarkup);
			EndIf;
		EndDo;
	Else
		If TypeOf(Object.DiscountsMarkups) = Type("ValueTable") Then
			Object.DiscountsMarkups = DiscountsMarkupsCalculationResult.Copy();
		Else
			Object.DiscountsMarkups.Load(DiscountsMarkupsCalculationResult);
		EndIf;
	EndIf;
	AutomaticDiscountsMarkups = DiscountsMarkupsCalculationResult.Copy();
	
	// Filling of discounts in spreadshet part "Products"
	AutomaticDiscountsMarkups.GroupBy("ConnectionKey", "Amount");
	AutomaticDiscountsMarkups.Indexes.Add("ConnectionKey");
	
	FillDiscountAmount = False;
	If TypeOf(Object.Ref) = Type("DocumentRef.SalesSlip") Then
		FillDiscountAmount = True;
	EndIf;
	AttributeSPOrder = "Order";
	
	SPConformity = New Map;
	SPConformity.Insert(TSName, "ConnectionKey");
	If Not NameSP2 = Undefined Then // For purchase order which has 2 SP: "Works" and "Inventory".
		SPConformity.Insert(NameSP2, "ConnectionKeyForMarkupsDiscounts");
	EndIf;
	ThereIsAttributeDiscountPercentByDiscountCard = Not (Object.Ref.Metadata().Attributes.Find("DiscountPercentByDiscountCard") = Undefined);
	
	For Each CurCorrespondenceItem In SPConformity Do
		AttributeConnectionKey = CurCorrespondenceItem.Value;
		For Each TSRow In Object[CurCorrespondenceItem.Key] Do
			
			If SalesExceedingOrder AND ValueIsFilled(TSRow[AttributeSPOrder]) Then
				Continue;
			EndIf;
			
			TableRow = AutomaticDiscountsMarkups.Find(TSRow[AttributeConnectionKey], "ConnectionKey");
			If TableRow = Undefined Then
				TSRow.AutomaticDiscountAmount = 0;
				AutomaticDiscountAmount          = 0; // For precise calculation of automatic discount percent
			Else
				TSRow.AutomaticDiscountAmount = TableRow.Amount;
				AutomaticDiscountAmount          = TableRow.Amount; // For precise calculation of automatic discount percent
			EndIf;
			
			// Application of automatic discount.
			AmountWithoutDiscount = Round(TSRow.Quantity * TSRow.Price, 2);
			
			If TSRow.Property("StandardHours") Then
				AmountWithoutDiscount = AmountWithoutDiscount * TSRow.StandardHours;
			EndIf;
			
			// Discounts.
			If AmountWithoutDiscount <> 0 Then
				If TSRow.DiscountMarkupPercent = 100 Then
					AmountAfterManualDiscountsMarkupsApplication = 0;
				ElsIf (TSRow.DiscountMarkupPercent <> 0 OR (ThereIsAttributeDiscountPercentByDiscountCard AND Object.DiscountPercentByDiscountCard) <> 0) AND TSRow.Quantity <> 0 Then
					AmountAfterManualDiscountsMarkupsApplication = Round(AmountWithoutDiscount * (1 - (TSRow.DiscountMarkupPercent) / 100), 2);
				Else
					AmountAfterManualDiscountsMarkupsApplication = AmountWithoutDiscount;
				EndIf;
			Else
				AmountAfterManualDiscountsMarkupsApplication = AmountWithoutDiscount;
			EndIf;
			
			If FillDiscountAmount Then
				ManualDiscountAmount = TSRow.AmountDiscountsMarkups;
			Else
				ManualDiscountAmount = AmountWithoutDiscount - AmountAfterManualDiscountsMarkupsApplication;
			EndIf;
			
			DiscountAmount = AutomaticDiscountAmount + ManualDiscountAmount;
			
			TSRow.AutomaticDiscountsPercent = ?(AmountWithoutDiscount = 0, 0 , 100 * AutomaticDiscountAmount / AmountWithoutDiscount);
			
			TSRow.Amount    = AmountWithoutDiscount - ?(DiscountAmount > AmountWithoutDiscount, AmountWithoutDiscount, DiscountAmount);
			
			// VAT amount.
			VATRate = Drivereuse.GetVATRateValue(TSRow.VATRate);
		
			TSRow.VATAmount = ?(Object.AmountIncludesVAT, 
											  TSRow.Amount - (TSRow.Amount) / ((VATRate + 100) / 100),
											  TSRow.Amount * VATRate / 100);

			// Total.
			TSRow.Total = TSRow.Amount + ?(Object.AmountIncludesVAT, 0, TSRow.VATAmount);

			If FillDiscountAmount Then
				TSRow.DiscountAmount = AmountWithoutDiscount - TSRow.Amount;
				TSRow.AmountDiscountsMarkups = ManualDiscountAmount;
			EndIf;
			
		EndDo;
	EndDo;
	
	Object.DiscountsAreCalculated = True;
	
EndProcedure

#EndRegion