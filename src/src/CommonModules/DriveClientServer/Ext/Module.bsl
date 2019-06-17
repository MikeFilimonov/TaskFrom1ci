
// Function returns the label text "Prices and currency".
//
Function GenerateLabelPricesAndCurrency(LabelStructure) Export
	
	LabelText = "";
	
	If LabelStructure.Property("ForeignExchangeAccounting") And LabelStructure.ForeignExchangeAccounting Then
		If LabelStructure.Property("DocumentCurrency") And ValueIsFilled(LabelStructure.DocumentCurrency) Then
			LabelText = TrimAll(String(LabelStructure.DocumentCurrency));
		EndIf;
	EndIf;
	
	If LabelStructure.Property("PriceKind") And ValueIsFilled(LabelStructure.PriceKind) Then
		If IsBlankString(LabelText) Then
			LabelText = LabelText + "%1";
		Else
			LabelText = LabelText + " • %1";
		EndIf;
		LabelText = StringFunctionsClientServer.SubstituteParametersInString(LabelText, TrimAll(String(LabelStructure.PriceKind)));
	EndIf;
	
	If LabelStructure.Property("DiscountKind") And ValueIsFilled(LabelStructure.DiscountKind) Then
		If IsBlankString(LabelText) Then
			LabelText = LabelText + "%1";
		Else
			LabelText = LabelText + " • %1";
		EndIf;
		LabelText = StringFunctionsClientServer.SubstituteParametersInString(LabelText, TrimAll(String(LabelStructure.DiscountKind)));
	EndIf;
	
	If LabelStructure.Property("DiscountPercentByDiscountCard")
		And LabelStructure.Property("DiscountCard")
		And ValueIsFilled(LabelStructure.DiscountCard) Then
		
		If IsBlankString(LabelText) Then
			LabelText = LabelText + "%1";
		Else
			LabelText = LabelText + " • %1";
		EndIf;
		
		LabelText = StringFunctionsClientServer.SubstituteParametersInString(
			LabelText, 
			String(LabelStructure.DiscountPercentByDiscountCard)
				+ NStr("en = '% by card'"));
		
	EndIf;
	
	If LabelStructure.Property("SupplierPriceTypes") And ValueIsFilled(LabelStructure.SupplierPriceTypes) Then
		If IsBlankString(LabelText) Then
			LabelText = LabelText + "%1";
		Else
			LabelText = LabelText + " • %1";
		EndIf;
		LabelText = StringFunctionsClientServer.SubstituteParametersInString(LabelText, TrimAll(String(LabelStructure.SupplierPriceTypes)));
	EndIf;
	
	If LabelStructure.Property("VATTaxation")
		And (Not LabelStructure.Property("RegisteredForVAT")
			Or LabelStructure.RegisteredForVAT
			Or LabelStructure.VATTaxation = PredefinedValue("Enum.VATTaxationTypes.ReverseChargeVAT")
			Or LabelStructure.VATTaxation = PredefinedValue("Enum.VATTaxationTypes.ForExport")) Then
		
		If ValueIsFilled(LabelStructure.VATTaxation) Then
			If IsBlankString(LabelText) Then
				LabelText = LabelText + "%1";
			Else
				LabelText = LabelText + " • %1";
			EndIf;
			LabelText = StringFunctionsClientServer.SubstituteParametersInString(LabelText, TrimAll(String(LabelStructure.VATTaxation)));
		EndIf;
		
	EndIf;
	
	If LabelStructure.Property("AmountIncludesVAT")
		And LabelStructure.Property("VATTaxation")
		And LabelStructure.VATTaxation = PredefinedValue("Enum.VATTaxationTypes.SubjectToVAT") Then
		
		If IsBlankString(LabelText) Then
			LabelText = LabelText + "%1";
		Else
			LabelText = LabelText + " • %1";
		EndIf;
		
		If LabelStructure.AmountIncludesVAT Then
			LabelText = StringFunctionsClientServer.SubstituteParametersInString(LabelText,
				NStr("en = 'VAT inclusive'"));
		Else
			LabelText = StringFunctionsClientServer.SubstituteParametersInString(LabelText,
				NStr("en = 'VAT exclusive'"));
		EndIf;
		
	EndIf;
	
	Return LabelText;
	
EndFunction

// Fills in the values list Receiver from the values list Source
//
Procedure FillListByList(Source,Receiver) Export

	Receiver.Clear();
	For Each ListIt In Source Do
		Receiver.Add(ListIt.Value, ListIt.Presentation);
	EndDo;

EndProcedure

// Function receives items present in each array
//
// Parameters:
//  Array1	 - array	 - first
//  array Array2	 - array	 - second
// array Return value:
//  array - array of values that are contained in two arrays
Function GetMatchingArraysItems(Array1, Array2) Export
	
	Result = New Array;
	
	For Each Value In Array1 Do
		If Array2.Find(Value) <> Undefined Then
			Result.Add(Value);
		EndIf;
	EndDo;
	
	Return Result;
	
EndFunction

Function GetQueryUnion() Export
	
	Return "
	|
	|UNION ALL
	|
	|";
	
EndFunction

Procedure SetPictureForComment(GroupAdditional, Comment) Export
	
	If ValueIsFilled(Comment) Then
		GroupAdditional.Picture = PictureLib.WriteSMS;
	Else
		GroupAdditional.Picture = New Picture;
	EndIf;
	
EndProcedure

Function PluralForm(Word1, Word2, Word3, Val IntegerNumber) Export
	
	// Change the sign of an integer, otherwise negative numbers will be incorrectly converted
	If IntegerNumber < 0 Then
		IntegerNumber = -1 * IntegerNumber;
	EndIf;
	
	If IntegerNumber <> Int(IntegerNumber) Then 
		// For non-integer numbers - always the second form
		Return Word2;
	EndIf;
	
	// remainder
	Remainder = IntegerNumber%10;
	If (IntegerNumber >10) AND (IntegerNumber<20) Then
		// For the second ten - always the third form
		Return Word3;
	ElsIf Remainder=1 Then
		Return Word1;
	ElsIf (Remainder>1) AND (Remainder<5) Then
		Return Word2;
	Else
		Return Word3;
	EndIf;

EndFunction

// Fills the connection key of the
// document table or data processor.
Procedure FillConnectionKey(TabularSection, TabularSectionRow, ConnectionAttributeName, TempConnectionKey = 0) Export
	
	If NOT ValueIsFilled(TabularSectionRow[ConnectionAttributeName]) Then
		If TempConnectionKey = 0 Then
			For Each TSRow In TabularSection Do
				If TempConnectionKey < TSRow[ConnectionAttributeName] Then
					TempConnectionKey = TSRow[ConnectionAttributeName];
				EndIf;
			EndDo;
		EndIf;
		TabularSectionRow[ConnectionAttributeName] = TempConnectionKey + 1;
	EndIf;
	
EndProcedure

// Deletes the rows on the connection key in the
// document table or data processors.
Procedure DeleteRowsByConnectionKey(TabularSection, TabularSectionRow, ConnectionAttributeName = "ConnectionKey") Export
	
	If TabularSectionRow = Undefined Then
		Return;
	EndIf;
	
	TheStructureOfTheSearch = New Structure;
	TheStructureOfTheSearch.Insert(ConnectionAttributeName, TabularSectionRow[ConnectionAttributeName]);
	
	RowsToDelete = TabularSection.FindRows(TheStructureOfTheSearch);
	For Each TableRow In RowsToDelete Do
		
		TabularSection.Delete(TableRow);
		
	EndDo;
	
EndProcedure

// Rounds a number according to a specified order.
//
// Parameters:
//  Number        - Number required
//  to be rounded RoundingOrder - Enums.RoundingMethods - round
//  order RoundUpward - Boolean - rounding upward.
//
// Returns:
//  Number        - rounding result.
//
Function RoundPrice(Number, RoundRule, RoundUp) Export
	
	Var Result; // Returned result.
	
	// Transform order of numbers rounding.
	// If null order value is passed, then round to cents.
	If Not ValueIsFilled(RoundRule) Then
		RoundingOrder = PredefinedValue("Enum.RoundingMethods.Round0_01"); 
	Else
		RoundingOrder = RoundRule;
	EndIf;
	Order = NumberByRoundingOrder(RoundingOrder);
	
	// calculate quantity of intervals included in number
	QuantityInterval = Number / Order;
	
	// calculate an integer quantity of intervals.
	NumberOfEntireIntervals = Int(QuantityInterval);
	
	If QuantityInterval = NumberOfEntireIntervals Then
		
		// Numbers are divided integrally. No need to round.
		Result = Number;
	Else
		If RoundUp Then
			
			// During 0.05 rounding 0.371 must be rounded to 0.4
			Result = Order * (NumberOfEntireIntervals + 1);
		Else
			
			// During 0.05 rounding 0.371 must be rounded to 0.35 and 0.376 to 0.4
			Result = Order * Round(QuantityInterval, 0, RoundMode.Round15as20);
		EndIf;
	EndIf;
	
	Return Result;
	
EndFunction

Function NumberByRoundingOrder(RoundingOrder) Export
	
	If RoundingOrder = PredefinedValue("Enum.RoundingMethods.Round0_01") Then
		Result = 0.01;
	ElsIf RoundingOrder = PredefinedValue("Enum.RoundingMethods.Round0_05") Then
		Result = 0.05;
	ElsIf RoundingOrder = PredefinedValue("Enum.RoundingMethods.Round1") Then
		Result = 1;
	ElsIf RoundingOrder = PredefinedValue("Enum.RoundingMethods.Round5") Then
		Result = 5;
	ElsIf RoundingOrder = PredefinedValue("Enum.RoundingMethods.Round10") Then
		Result = 10;
	ElsIf RoundingOrder = PredefinedValue("Enum.RoundingMethods.Round50") Then
		Result = 50;
	ElsIf RoundingOrder = PredefinedValue("Enum.RoundingMethods.Round100") Then
		Result = 100;
	ElsIf RoundingOrder = PredefinedValue("Enum.RoundingMethods.Round0_1") Then
		Result = 0.1;
	ElsIf RoundingOrder = PredefinedValue("Enum.RoundingMethods.Round0_5") Then
		Result = 0.5;
	EndIf;
	
	Return Result;
	
EndFunction

#Region WorkWithQuery

Function GetQueryDelimeter() Export
	
	Return "
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|";
	
EndFunction

// Add delimeter to query text.
//
// Parameters:
//	QueryText - String - Query text
//
Procedure AddDelimeter(QueryText) Export
	
	If ValueIsFilled(QueryText) Then
		QueryText = QueryText + GetQueryDelimeter();
	EndIf;
	
EndProcedure

#EndRegion

#Region WorkWithArray

// Create array from item.
//
// Parameters:
//	Item - Array, ValueList, FixedArray - Value will convert to array.
//	IgnoreEmptyValue - Boolean - Ignore empty Item (no value)
//
// Returned value:
//	Array
//
Function ArrayFromItem(Item, IgnoreEmptyValue = True) Export
	
	If TypeOf(Item) = Type("Array") Then
		Array = Item;
	ElsIf TypeOf(Item) = Type("ValueList") Then
		Array = Item.UnloadValues();
	ElsIf TypeOf(Item) = Type("FixedArray") Then
		Array = New Array(Item);
	Else
		Array = New Array;
		If Not IgnoreEmptyValue Or ValueIsFilled(Item) Then
			Array.Add(Item);
		EndIf;
	EndIf;
	
	Return Array;
	
EndFunction

// Add new value into array.
//
// Parameters:
//	Array - Array - Source array
//	Value - Any value - Value for add into array
//
// Returned value:
//	Array
//
Function AddNewValueInArray(Array, Value) Export
	
	ValueIsAdded = False;
	
	If Array.Find(Value) = Undefined Then
		Array.Add(Value);
		ValueIsAdded = True;
	EndIf;
	
	Return ValueIsAdded;
EndFunction

// Return the intersecrion of two arrays.
//
// Parameters:
//	Array1 - Array - The first array
//	Array2 - Array - The second array
//
// Returned value:
//	Array
//
Function IntersecrionOfArrays(Array1, Array2) Export
	
	Intersecrion = New Array;
	
	For Each CurrentItem In Array1 Do
		If Array2.Find(CurrentItem) <> Undefined Then
			AddNewValueInArray(Intersecrion, CurrentItem);
		EndIf;
	EndDo;
	
	Return Intersecrion;
EndFunction

#EndRegion

#Region WorkWithStructure

// Checks that not elements in structure with empty values
//
// Parameters:
//	Data - Structure
//
// Returned value:
//	Boolean - If not empty values in structure is True.
//
Function ValuesInStructureNotFilled(Data) Export
	
	EmptyValues = True;
	
	For Each KeyAndValue In Data Do
		
		If (TypeOf(KeyAndValue.Value) = Type("Boolean") AND KeyAndValue.Value)
			OR (TypeOf(KeyAndValue.Value) <> Type("Boolean") AND ValueIsFilled(KeyAndValue.Key)) Then
			EmptyValues = False;
			Break;
		EndIf;
		
	EndDo;
	
	Return EmptyValues;
EndFunction

#EndRegion

#Region InteractionProceduresAndFunctions

// Generates a structure of contact info fields of type Telephone or MobilePhone by a telephone presentation
//
// Parameters
//  Presentation  - String - String info with a telephone number
//
// Returns:
//   Structure   - generated structure
//
Function ConvertNumberForSMSSending(val Number) Export
	
	// Clear user separators
	CharsToReplace = "()- ";
	For CharacterNumber = 1 To StrLen(CharsToReplace) Do
		Number = StrReplace(Number, Mid(CharsToReplace, CharacterNumber, 1), "");
	EndDo;
	
	Return Number;
	
EndFunction

// PROCEDURES AND FUNCTIONS OF WORK WITH DYNAMIC LISTS

// Procedure sets filter in dynamic list for equality.
//
Procedure SetDynamicListFilterToEquality(Filter, LeftValue, RightValue) Export
	
	FilterItem = Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterItem.LeftValue	 = LeftValue;
	FilterItem.ComparisonType	 = DataCompositionComparisonType.Equal;
	FilterItem.RightValue = RightValue;
	FilterItem.Use  = True;
	
EndProcedure

// Deletes dynamic list filter item
//
// Parameters:
// List  - processed dynamic
// list, FieldName - layout field name filter by which should be deleted
//
Procedure DeleteListFilterItem(List, FieldName) Export
	
	SetElements = List.SettingsComposer.Settings.Filter;
	CommonUseClientServer.DeleteItemsOfFilterGroup(SetElements,FieldName);
	
EndProcedure

// Sets dynamic list filter item
//
// Parameters:
// List			- processed dynamic
// list, FieldName			- layout field name filter on which
// should be set, ComparisonKind		- filter comparison kind, by default - Equal,
// RightValue 	- filter value
//
Procedure SetListFilterItem(List, FieldName, RightValue, Use = True, ComparisonType = Undefined) Export
	
	SetElements = List.SettingsComposer.Settings.Filter;
	CommonUseClientServer.SetFilterItem(SetElements,FieldName,RightValue,ComparisonType,,Use);
	
EndProcedure

// Changes dynamic list filter item
//
// Parameters:
// List         - processed dynamic
// list, FieldName        - layout field name filter on which
// should be set, ComparisonKind   - filter comparison kind, by default - Equal,
// RightValue - filter
// value, Set     - shows that it is required to set filter
//
Procedure ChangeListFilterElement(List, FieldName, RightValue = Undefined, Set = False, ComparisonType = Undefined, FilterByPeriod = False, QuickAccess = False) Export
	
	SetElements = List.SettingsComposer.Settings.Filter;
	CommonUseClientServer.ChangeFilterItems(SetElements,FieldName,,RightValue,ComparisonType,Set);
	
EndProcedure

#Region BusinessPulse

Function ChartSeriesColors() Export
	
	ColorsArray = New Array;
	
	ColorsArray.Add(New Color(245, 152, 150));
	ColorsArray.Add(New Color(142, 201, 249));
	ColorsArray.Add(New Color(255, 202, 125));
	ColorsArray.Add(New Color(178, 154, 218));
	ColorsArray.Add(New Color(163, 214, 166));
	ColorsArray.Add(New Color(244, 140, 175));
	ColorsArray.Add(New Color(125, 221, 233));
	ColorsArray.Add(New Color(255, 242, 128));
	ColorsArray.Add(New Color(205, 145, 215));
	ColorsArray.Add(New Color(125, 202, 194));
	
	Return ColorsArray;
	
EndFunction

Function PreviousFloatingPeriod(Period) Export
	
	If TypeOf(Period) = Type("Structure") 
		AND Period.Variant = "Last7Days" Then
			StartDate = BegOfDay(CurrentDate());
			Return New StandardPeriod(StartDate - 14 * 86400, StartDate - 7 * 86400 - 1); 
	ElsIf Period.Variant = StandardPeriodVariant.Today Then
		Return New StandardPeriod(StandardPeriodVariant.Yesterday);
	ElsIf Period.Variant = StandardPeriodVariant.FromBeginningOfThisWeek Then
		Return New StandardPeriod(StandardPeriodVariant.LastWeekTillSameWeekDay);
	ElsIf Period.Variant = StandardPeriodVariant.FromBeginningOfThisMonth Then
		Return New StandardPeriod(StandardPeriodVariant.LastMonthTillSameDate);
	ElsIf Period.Variant = StandardPeriodVariant.FromBeginningOfThisQuarter Then
		Return New StandardPeriod(StandardPeriodVariant.LastQuarterTillSameDate);
	ElsIf Period.Variant = StandardPeriodVariant.FromBeginningOfThisHalfYear Then
		Return New StandardPeriod(StandardPeriodVariant.LastHalfYearTillSameDate);
	ElsIf Period.Variant = StandardPeriodVariant.FromBeginningOfThisYear Then
		Return New StandardPeriod(StandardPeriodVariant.LastYearTillSameDate);
	Else
		SecondsCount = (EndOfDay(Period.EndDate) - Period.StartDate + 1);
		Return New StandardPeriod(Period.StartDate - SecondsCount, Period.StartDate - 1); 
	EndIf; 
	
EndFunction
 
Function SamePeriodOfLastYear(Period) Export
	
	If TypeOf(Period) = Type("Structure")
		AND Period.Variant = "Last7Days" Then
			StartDate	= BegOfDay(CurrentDate()) - 7 * 86400;
			EndDate		= BegOfDay(CurrentDate()) - 1;
	Else
		StartDate	= Period.StartDate;
		EndDate		= Period.EndDate;
	EndIf;
	
	Year	= Year(StartDate);
	Month	= Month(StartDate);
	Day		= Day(StartDate);
	
	If Year % 4 = 0 AND Month = 2 AND Day = 29 Then
		Day = 28;
	ElsIf (Year - 1) % 4 = 0 AND Month = 2 AND Day = 28 Then
		Day = 29;
	EndIf; 
	
	YearEnd		= Year(EndDate);
	MonthEndClosing	= Month(EndDate);
	DayEnd		= Day(EndDate);
	
	If YearEnd % 4 > 0 AND MonthEndClosing = 2 AND DayEnd = 29 Then
		DayEnd = 28;
	ElsIf (YearEnd - 1) % 4 = 0 AND MonthEndClosing = 2 AND DayEnd = 28 Then
		DayEnd = 29;
	EndIf; 
	
	If Period.Variant = StandardPeriodVariant.Today Then
		Date = Date(Year - 1, Month, Day);
		Return New StandardPeriod(BegOfDay(Date), EndOfDay(Date));
	ElsIf Period.Variant=StandardPeriodVariant.FromBeginningOfThisWeek Then
		
		SecondsCount	= BegOfDay(EndDate) - BegOfWeek(EndDate);
		Week			= WeekOfYear(StartDate);
		WeekDay			= WeekDay(Date(Year - 1, 1, 1));
		DayNumber		= 7 * (Week - 1) - WeekDay + 1;
		Date			= Date(Year - 1, 1, 1) + DayNumber * 86400;
		
		Return New StandardPeriod(BegOfWeek(Date), EndOfDay(Date + SecondsCount));
		
	ElsIf Period.Variant = StandardPeriodVariant.FromBeginningOfThisMonth Then
		Return New StandardPeriod(Date(Year - 1, Month, 1), EndOfDay(Date(YearEnd - 1, MonthEndClosing, DayEnd)));
	ElsIf Period.Variant = StandardPeriodVariant.FromBeginningOfThisQuarter Then
		Date = AddMonth(Date(Year - 1, 1, 1), Month - 1);
		Return New StandardPeriod(BegOfQuarter(Date), EndOfDay(Date(YearEnd - 1, MonthEndClosing, DayEnd)));
	ElsIf Period.Variant = StandardPeriodVariant.FromBeginningOfThisHalfYear Then
		
		If Month < 7 Then
			Return New StandardPeriod(Date(Year - 1, 1, 1), EndOfDay(Date(YearEnd - 1, MonthEndClosing, DayEnd)));
		Else
			Return New StandardPeriod(AddMonth(Date(Year - 1, 1, 1), 6), EndOfDay(Date(YearEnd - 1, MonthEndClosing, DayEnd)));
		EndIf;
		
	ElsIf Period.Variant = StandardPeriodVariant.FromBeginningOfThisYear Then
		Return New StandardPeriod(Date(Year - 1, 1, 1), EndOfDay(Date(YearEnd - 1, MonthEndClosing, DayEnd)));
	Else
		Return New StandardPeriod(Date(Year - 1, Month, Day), EndOfDay(Date(YearEnd - 1, MonthEndClosing, DayEnd)));
	EndIf; 
	
EndFunction

Function Last7DaysExceptForCurrentDay() Export
	
	StartDate = BegOfDay(CurrentDate());
	Return New StandardPeriod(StartDate - 7 * 86400, StartDate - 1); 
	
EndFunction

#EndRegion

#EndRegion
