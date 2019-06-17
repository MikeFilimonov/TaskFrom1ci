#If Server OR ThickClientOrdinaryApplication OR ExternalConnection Then

#Region Interface

Function StandardPeriodsByIndicators(IndicatorArray) Export
	
	Result = New Array;
	SessionDate = CurrentSessionDate();
	
	Boundaries = IndicatorCalculationLimits(IndicatorArray);
	For Each Item In Boundaries Do
		
		MinDate = Item.Value.StartDate;
		If MinDate < BegOfMonth(SessionDate) Then
			
			PeriodStructure = New Structure;
			
			Period		= New StandardPeriod;
			Period.Mode = StandardPeriodVariant.FromBeginningOfThisYear;
			
			PeriodStructure.Insert("Indicator", Item.Key);
			PeriodStructure.Insert("Period", Period);
			Result.Add(PeriodStructure);
			
		EndIf;
		
		If MinDate < BegOfWeek(SessionDate) Then
			
			PeriodStructure = New Structure;
			
			Period		= New StandardPeriod;
			Period.Mode = StandardPeriodVariant.FromBeginningOfThisMonth;
			
			PeriodStructure.Insert("Indicator", Item.Key);
			PeriodStructure.Insert("Period", Period);
			Result.Add(PeriodStructure);
			
		EndIf; 
		
		If MinDate < BegOfDay(SessionDate) Then
			
			PeriodStructure = New Structure;
			
			Period		= New StandardPeriod;
			Period.Mode = StandardPeriodVariant.FromBeginningOfThisWeek;
			
			PeriodStructure.Insert("Indicator", Item.Key);
			PeriodStructure.Insert("Period", Period);
			Result.Add(PeriodStructure);
			
		EndIf; 
		
		PeriodStructure = New Structure;
		
		Period		= New StandardPeriod;
		Period.Mode = StandardPeriodVariant.Today;
		
		PeriodStructure.Insert("Indicator", Item.Key);
		PeriodStructure.Insert("Period", Period);
		Result.Add(PeriodStructure);
	EndDo;
	
	Return Result;
	
EndFunction

Procedure MergeFilters(Filters, Field, ComparisonType, Value, Presentation) Export
	
	ExactMatch = Undefined;
	FoundFilterArray = New Array;
	
	For Each FilterDescription In Filters Do
		
		If Not FilterDescription.Field = Field Then
			Continue;
		EndIf;
		
		If FilterDescription.ComparisonType = ComparisonType AND ExactMatch = Undefined Then
			ExactMatch = FilterDescription;
		EndIf; 
		
		FoundFilterArray.Add(FilterDescription);
		
	EndDo; 
	
	// Merge filters with similar comparison kinds
	If Not ExactMatch = Undefined Then
		
		If TypeOf(Value) = Type("ValueList") AND TypeOf(ExactMatch.Value) = Type("ValueList") Then
			// Merge values-lists
			For Each ItemValue In Value Do
				If ExactMatch.Value.FindByValue(ItemValue.Value) = Undefined Then
					ExactMatch.Value.Add(ItemValue.Value);
				EndIf; 
			EndDo;
			
			Return;
			
		ElsIf ComparisonType = DataCompositionComparisonType.Equal OR
			ComparisonType = DataCompositionComparisonType.NotEqual Then
			// Convert in the filter by list of values for equal/not equal comparison kind
			If ComparisonType = DataCompositionComparisonType.Equal Then
				ExactMatch.ComparisonType = DataCompositionComparisonType.InList;
			ElsIf ComparisonType = DataCompositionComparisonType.NotEqual Then
				ExactMatch.ComparisonType = DataCompositionComparisonType.NotInList;
			EndIf; 
			
			OldValue = ExactMatch.Value;
			ExactMatch.Value = New ValueList;
			ExactMatch.Value.Add(OldValue);
			ExactMatch.Value.Add(Value);
			
			Return;
			
		ElsIf ComparisonType = DataCompositionComparisonType.Contains 
			OR ComparisonType = DataCompositionComparisonType.NotContains 
			OR ComparisonType = DataCompositionComparisonType.BeginsWith 
			OR ComparisonType = DataCompositionComparisonType.NotBeginsWith 
			OR ComparisonType = DataCompositionComparisonType.Like 
			OR ComparisonType = DataCompositionComparisonType.NotLike Then
				// Do not merge filters by lines
				FilterStructure = New Structure;
				FilterStructure.Insert("Field", Field);
				FilterStructure.Insert("Value", Value);
				FilterStructure.Insert("ComparisonType", ComparisonType);
				FilterStructure.Insert("Presentation", Presentation);
				Filters.Add(FilterStructure);
				
				Return;
		Else
			ExactMatch.Value = Value;
		EndIf;
	EndIf;
	
	// Add new filter
	If FoundFilterArray.Count()=0 Then
		
		FilterStructure = New Structure;
		FilterStructure.Insert("Field",				Field);
		FilterStructure.Insert("Value",				Value);
		FilterStructure.Insert("ComparisonType",	ComparisonType);
		FilterStructure.Insert("Presentation",		Presentation);
		Filters.Add(FilterStructure);
		
		Return;
		
	EndIf; 
	
	// Main part of mechanism of merging filters with different comparison kinds
	FilterProcessed = False;
	For Each FilterDescription In FoundFilterArray Do
		If (ComparisonType = DataCompositionComparisonType.Equal AND FilterDescription.ComparisonType = DataCompositionComparisonType.InList) 
			OR (ComparisonType = DataCompositionComparisonType.NotEqual AND FilterDescription.ComparisonType = DataCompositionComparisonType.NotInList) Then
				FilterDescription.Value.Add(Value);
				FilterProcessed = True;
		ElsIf (ComparisonType = DataCompositionComparisonType.InList AND FilterDescription.ComparisonType = DataCompositionComparisonType.Equal)
			OR (ComparisonType = DataCompositionComparisonType.NotInList AND FilterDescription.ComparisonType = DataCompositionComparisonType.NotEqual) Then
			
			FilterDescription.ComparisonType = ComparisonType;
			OldValue = FilterDescription.Value;
			FilterDescription.Value = Value;
			FilterDescription.Value.Add(OldValue);
			FilterProcessed = True;
				
		ElsIf (ComparisonType = DataCompositionComparisonType.Greater AND FilterDescription.ComparisonType = DataCompositionComparisonType.GreaterOrEqual) 
			OR (ComparisonType = DataCompositionComparisonType.GreaterOrEqual AND FilterDescription.ComparisonType = DataCompositionComparisonType.Greater) 
			OR (ComparisonType = DataCompositionComparisonType.Less AND FilterDescription.ComparisonType = DataCompositionComparisonType.LessOrEqual) 
			OR (ComparisonType = DataCompositionComparisonType.LessOrEqual AND FilterDescription.ComparisonType = DataCompositionComparisonType.Less) Then
				FilterDescription.ComparisonType = ComparisonType;
				FilterDescription.Value = Value;
				FilterProcessed = True;
		EndIf; 
	EndDo; 
	
	// In other cases, add another one filter
	If Not FilterProcessed Then
		
		FilterStructure = New Structure;
		FilterStructure.Insert("Field",				Field);
		FilterStructure.Insert("Value",				Value);
		FilterStructure.Insert("ComparisonType",	ComparisonType);
		FilterStructure.Insert("Presentation",		Presentation);
		Filters.Add(FilterStructure);
		
	EndIf; 
	
EndProcedure

#EndRegion 

#Region GenerateData

// Procedure calculates data for the "Business Pulse"
// desktop Called in background job from the BusinessPulse form.
//
// Parameters:
//  Parameters - Structure - Parameters used for calculation, required keys:
//										* Indicators - table of indicator calculation parameters,
//										* Charts - table of chart
//  parameter calculation, TemporaryResultStorage - String - Parameter returned to the parent session. Contains
//  correspondence of widgets and prepared data structures.
//
Procedure ReceiveData(Parameters, TemporaryResultStorage) Export
	
	Result = New Structure;
	
	SetPrivilegedMode(True);
	
	Result.Insert("Indicators", CalculateIndicators(Parameters));
	Result.Insert("Charts", CalculateCharts(Parameters));
	If Parameters.Property("Section") Then
		Result.Insert("Section", Parameters.Section);
	Else
		Result.Insert("Section", "");
	EndIf; 
	
	SetPrivilegedMode(False);
	
	PutToTempStorage(Result, TemporaryResultStorage);
	
EndProcedure

Function CalculateIndicators(Parameters)
	
	Result	= New Map;
	Query	= New Query;
	
	For Each Str In Parameters.Indicators Do
		
		If Parameters.Property("Section") 
			AND ((Parameters.Section = "Balance" AND Not Str.Balance) 
				OR (Parameters.Section = "Turnovers" AND Str.Balance)) Then
					Continue;
		EndIf; 
				
		Index = Parameters.Indicators.IndexOf(Str);
		
		If IsBlankString(Str.Resource) Then
			Continue;
		EndIf; 
		
		// Call the procedure of generating the indicator calculation query
		Execute("Attachable_" + Str.Indicator + "Calculation(Query, Str, Index, Parameters)");
		
		If Index % 50 = 0 AND Not IsBlankString(Query.Text) Then
			ExecuteQueryIndicators(Query, Parameters, Result);
		EndIf; 
	EndDo; 
	
	If Not IsBlankString(Query.Text) Then
		ExecuteQueryIndicators(Query, Parameters, Result); 
	EndIf;
	
	Return Result;
	
EndFunction
 
Procedure ExecuteQueryIndicators(Query, Parameters, Result)
	
	Query.SetParameter("Period", Parameters.Date.Date);
	
	If ValueIsFilled(Parameters.ComparisonDate) Then
		Query.SetParameter("PeriodComparisons", Parameters.ComparisonDate.Date);
	EndIf; 
	
	If TypeOf(Parameters.Period) = Type("StandardPeriod") OR TypeOf(Parameters.Period) = Type("Structure") Then
		Query.SetParameter("StartDate",	Parameters.Period.StartDate);
		Query.SetParameter("EndDate",	Parameters.Period.EndDate);
	Else
		Query.SetParameter("StartDate",	'0001-01-01');
		Query.SetParameter("EndDate",	'0001-01-01');
	EndIf; 
	
	If TypeOf(Parameters.ComparisonPeriod) = Type("StandardPeriod") OR TypeOf(Parameters.ComparisonPeriod) = Type("Structure") Then
		Query.SetParameter("StartDateComparisons",	Parameters.ComparisonPeriod.StartDate);
		Query.SetParameter("EndDateComparisons",	Parameters.ComparisonPeriod.EndDate);
	EndIf;
	
	Try
		Selection = Query.Execute().Select();
	Except
		WriteLogEvent(
			NStr("en = 'Business pulse: an error occurred while calculating the indicator'",
				CommonUseClientServer.MainLanguageCode()),
			EventLogLevel.Error,,,
			ErrorDescription());
		Return;
	EndTry;
	
	While Selection.Next() Do
		
		Str = Parameters.Indicators[Selection.Index];
		
		If Result.Get(Selection.Index) = Undefined Then
			Result.Insert(Selection.Index, New Structure("Value, ComparisonValue", 0, 0));
		EndIf; 
		
		ResultStructure = Result[Selection.Index];
		
		If Selection.ToCompare Then
			
			If Not Selection.Separator = Undefined Then
				Continue;
			EndIf;
			
			ResultStructure.Insert("ComparisonValue", ?(Selection.Value = Null, 0, Selection.Value));
			
		ElsIf Selection.Separator = Undefined Then
			ResultStructure.Insert("Value", ?(Selection.Value = Null, 0, Selection.Value));
		Else
			
			If Not TypeOf(ResultStructure.Value) = Type("Map") Then
				ResultStructure.Insert("Value", New Map);
			EndIf; 
			
			ResultStructure.Value.Insert(Selection.Separator, Selection.Value);
			
		EndIf; 
	EndDo;
	
	Query = New Query;
	
EndProcedure

Function CalculateCharts(Parameters)
	
	Result = New Map;
	
	Query			= New Query;
	QueryParameters = New Array; 
	
	For Each Str In Parameters.Charts Do
		
		If Parameters.Property("Section") Then
			Continue;
		EndIf; 
		
		If IsBlankString(Str.Series) OR IsBlankString(Str.Point) Then
			Continue;
		EndIf;
		
		Index = Parameters.Charts.IndexOf(Str);
		
		// Custom handlers
		If Str.Chart = "AssetDynamics" Then
			Attachable_AssetDynamicsChart(Result, Str, Index);
		Else
			// Call the procedure of generating the query to get chart data
			Execute("Attachable_" + Str.Chart + "Chart(Query, QueryParameters, Str, Index)");
		EndIf; 
		
		If Index % 50 = 0 AND Not IsBlankString(Query.Text) Then
			ExecuteQueryCharts(Query, QueryParameters, Result);
		EndIf; 
		
	EndDo;
	
	If Not IsBlankString(Query.Text) Then
		ExecuteQueryCharts(Query, QueryParameters, Result); 
	EndIf;
	
	Return Result;
	
EndFunction

Procedure ExecuteQueryCharts(Query, QueryParameters, Result)
	
	Try
		Results = Query.ExecuteBatch();
	Except
		
		WriteLogEvent(
			NStr("en = 'Business pulse: an error occurred when receiving chart data'",
				CommonUseClientServer.MainLanguageCode()),
			EventLogLevel.Error,,,
			ErrorDescription());
			
		Return;
		
	EndTry; 
	
	For Each QueryResult In Results Do
		
		Index = Results.Find(QueryResult);
		ParametersStructure = QueryParameters[Index];
		
		If Result.Get(ParametersStructure.Index)=Undefined Then
			Result.Insert(ParametersStructure.Index, New Array);
		EndIf; 
		
		If ParametersStructure.QueryWithResults Then
			Selection = QueryResult.Select(QueryResultIteration.ByGroups, "Point", "All");
		Else
			Selection = QueryResult.Select();
		EndIf; 
		
		Order = 0;
		
		While Selection.Next() Do
			
			ValueStructure = New Structure;
			ColumnIndex = 1;
			
			While Not QueryResult.Columns.Find("Series" + ColumnIndex) = Undefined Do
				
				Value = Selection["Series" + ColumnIndex];
				ValueStructure.Insert("Series" + ColumnIndex, Value);
				ColumnIndex = ColumnIndex + 1;
				
			EndDo; 
			
			ValueStructure.Insert("SeriesCount", ColumnIndex-1);
			ValueStructure.Insert("Point", Selection.Point);
			ValueStructure.Insert("ToCompare", ParametersStructure.ToCompare);
			ValueStructure.Insert("Order", Order);
			Order = Order + 1;
			Result[ParametersStructure.Index].Add(ValueStructure);
			
		EndDo;
		
	EndDo; 
	
	Query = New Query;
	QueryParameters = New Array;
	
EndProcedure

#EndRegion

#Region Calculation

#Region IndicatorCalculation

Procedure Attachable_SalesCalculation(Query, Str, Index, Parameters)
	
	If Str.Resource = "Revenue" Then
		ResourceText = "SUM(Reg.AmountTurnover)";
	ElsIf Str.Resource = "Quantity" Then
		ResourceText = "SUM(Reg.QuantityTurnover)";
	ElsIf Str.Resource = "NumberOfDocuments" Then	
		ResourceText = "COUNT(DISTINCT Reg.Recorder)";		
	ElsIf Str.Resource = "Cost" Then
		ResourceText = "SUM(Reg.CostTurnover)";
	ElsIf Str.Resource = "Profit" Then
		ResourceText = "SUM(Reg.AmountTurnover - Reg.CostTurnover)";
	ElsIf Str.Resource = "Margin" Then
		
		ResourceText = "CAST(CASE 
			|	WHEN SUM(Reg.CostTurnover) = 0 THEN 0 
			|		ELSE 100 * SUM(Reg.AmountTurnover - Reg.CostTurnover) / SUM(Reg.CostTurnover) 
			|	END AS Number(10, 2))";
		
	ElsIf Str.Resource = "Profitability" Then
		
		ResourceText = "CAST(CASE 
			|	WHEN SUM(Reg.AmountTurnover) = 0 THEN 0                    
			|		ELSE 100 * SUM(Reg.AmountTurnover - Reg.CostTurnover) / SUM(Reg.AmountTurnover) 
			|	END AS Number(10, 2))";
		
	ElsIf Str.Resource = "ReturnsAmount" Then
		
		ResourceText = "SUM(CASE 
			|	WHEN Reg.Recorder REFS Document.RefundReceipt 
			|		THEN -Reg.AmountTurnover 
			|		ELSE 0 
			|	END)";
		
	ElsIf Str.Resource = "ReturnsQuantity" Then
		
		ResourceText = "SUM(CASE 
			|	WHEN Reg.Recorder REFS Document.RefundReceipt 
			|		THEN -Reg.QuantityTurnover 
			|		ELSE 0 
			|	END)";
		
	Else
		Return;
	EndIf; 
	
	ItemText = StrReplace(
		"SELECT
		|   &ToCompare AS ToCompare, 
		|   &Index AS Index, 
		|   &Separator AS Separator, 
		|	&Resource AS Value
		|FROM
		|	AccumulationRegister.Sales.Turnovers(&StartDate, &EndDate, Auto, ) AS Reg
		|WHERE &Filters
		|GROUP BY &Groups",
		"&Resource",
		ResourceText);
	AddItemToQueryIndicators(Query, ItemText, Str, Index, Parameters);
	
EndProcedure

Procedure Attachable_CashCalculation(Query, Str, Index, Parameters)
	
	If Str.Resource = "AmountBalance" Then
		ResourceText = "SUM(Reg.AmountBalance)";
	ElsIf Str.Resource = "CashFlow" Then
		
		ResourceText = 
		"SUM(CASE 
		|	WHEN Reg.Recorder REFS Document.CashTransfer Then 0 
		|	WHEN Reg.RecordType = VALUE(AccumulationRecordType.Receipt) THEN Reg.Amount 
		|	WHEN Reg.RecordType = VALUE(AccumulationRecordType.Expense) THEN -Reg.Amount Else 0 END)";
		
	ElsIf Str.Resource = "Receipts" Then
		
		ResourceText = 
		"SUM(CASE 
		|	WHEN Reg.RecordType = VALUE(AccumulationRecordType.Receipt) 
		|	AND Not Reg.Recorder REFS Document.CashTransfer Then Reg.Amount Else 0 END)";
		
	ElsIf Str.Resource = "Payments" Then
		
		ResourceText = 
		"SUM(CASE 
		|	WHEN Reg.RecordType = VALUE(AccumulationRecordType.Expense) 
		|	AND Not Reg.Recorder REFS Document.CashTransfer Then Reg.Amount Else 0 END)";
		
	ElsIf Str.Resource = "ReceiptsPlan" Then
		
		ResourceText = 
		"SUM(CAST(CASE WHEN Reg.AmountTurnover > 0 THEN Reg.AmountTurnover ELSE 0 END
		|	* ExchangeRatesDocument.ExchangeRate / ExchangeRatesDocument.Multiplicity 
		|	/ ExchangeRatesAccounting.ExchangeRate * ExchangeRatesAccounting.Multiplicity AS Number(15,2)))";
		
	ElsIf Str.Resource = "PaymentsPlan" Then
		
		ResourceText = 
		"SUM(CAST(CASE WHEN Reg.AmountTurnover < 0 THEN -Reg.AmountTurnover ELSE 0 END
		|	* ExchangeRatesDocument.ExchangeRate / ExchangeRatesDocument.Multiplicity
		|	/ ExchangeRatesAccounting.ExchangeRate * ExchangeRatesAccounting.Multiplicity AS Number(15,2)))";
		
	Else
		Return;
	EndIf; 
	
	If Str.Resource = "AmountBalance" Then
		
		ItemText =  
		"SELECT
		|	&ToCompare AS ToCompare,
		|	&Index AS Index,
		|	&Separator AS Separator,
		|	&Resource AS Value
		|FROM
		|	AccumulationRegister.CashAssets.Balance(&Period, ) AS Reg
		|WHERE
		|	&Filters";
		
	ElsIf Str.Resource = "ReceiptsPlan" OR Str.Resource = "PaymentsPlan" Then
		
		ItemText =  
		"SELECT
		|	&ToCompare AS ToCompare,
		|	&Index AS Index,
		|	&Separator AS Separator,
		|	&Resource AS Value
		|FROM
		|	AccumulationRegister.PaymentCalendar.Turnovers(&StartDate, &EndDate, Recorder, PaymentConfirmationStatus = VALUE(Enum.PaymentApprovalStatuses.Approved)) AS Reg
		|		LEFT JOIN (SELECT
		|			PaymentCalendar.Recorder AS Recorder,
		|			PaymentCalendar.Currency AS Currency,
		|			MAX(ISNULL(ExchangeRatesAccounting.Period, DATETIME(1, 1, 1))) AS RatePeriodAccounting,
		|			MAX(ISNULL(ExchangeRatesDocument.Period, DATETIME(1, 1, 1))) AS RatePeriodDocument
		|		FROM
		|			AccumulationRegister.PaymentCalendar.Turnovers(&StartDate, &EndDate, Auto, PaymentConfirmationStatus = VALUE(Enum.PaymentApprovalStatuses.Approved)) AS PaymentCalendar
		|				LEFT JOIN InformationRegister.ExchangeRates AS ExchangeRatesAccounting
		|				ON PaymentCalendar.SecondPeriod >= ExchangeRatesAccounting.Period
		|					AND (ExchangeRatesAccounting.Currency IN
		|						(SELECT
		|							Constant.PresentationCurrency.Value
		|						FROM
		|							Constant.PresentationCurrency))
		|				LEFT JOIN InformationRegister.ExchangeRates AS ExchangeRatesDocument
		|				ON PaymentCalendar.SecondPeriod >= ExchangeRatesDocument.Period
		|					AND (ExchangeRatesDocument.Currency = PaymentCalendar.Currency)
		|		
		|		GROUP BY
		|			PaymentCalendar.Recorder,
		|			PaymentCalendar.Currency) AS NestedQuery
		|			LEFT JOIN InformationRegister.ExchangeRates AS ExchangeRatesAccounting
		|			ON NestedQuery.RatePeriodAccounting = ExchangeRatesAccounting.Period
		|				AND (ExchangeRatesAccounting.Currency IN
		|					(SELECT
		|						Constant.PresentationCurrency.Value
		|					FROM
		|						Constant.PresentationCurrency))
		|			LEFT JOIN InformationRegister.ExchangeRates AS ExchangeRatesDocument
		|			ON NestedQuery.RatePeriodDocument = ExchangeRatesDocument.Period
		|				AND (ExchangeRatesDocument.Currency = NestedQuery.Currency)
		|		ON Reg.Recorder = NestedQuery.Recorder
		|WHERE
		|	&Filters";
		
	Else

		ItemText =  
		"SELECT
		|	&ToCompare AS ToCompare,
		|	&Index AS Index,
		|	&Separator AS Separator,
		|	&Resource AS Value
		|FROM
		|	(SELECT
		|		Reg.Company AS Company,
		|		Reg.CashAssetsType AS CashAssetsType,
		|		Reg.BankAccountPettyCash AS BankAccountPettyCash,
		|		Reg.Currency AS Currency,
		|		Reg.Item AS Item,
		|		Reg.RecordType AS RecordType,
		|		Reg.Recorder AS Recorder,
		|		Reg.Amount AS Amount
		|	FROM
		|		AccumulationRegister.CashAssets AS Reg
		|	WHERE
		|		(Reg.Period >= &StartDate
		|				OR &StartDate = DATETIME(1, 1, 1))
		|		AND (Reg.Period <= &EndDate
		|				OR &EndDate = DATETIME(1, 1, 1))
		|		AND &Filters) AS Reg";
		
	EndIf; 
	
	ItemText = StrReplace(ItemText,	"&Resource", ResourceText);
		
	AddItemToQueryIndicators(Query, ItemText, Str, Index, Parameters);
	
EndProcedure

Procedure Attachable_ProductsCalculation(Query, Str, Index, Parameters)
	
	If Str.Resource = "AmountBalance" Then
		ResourceText = "SUM(Reg.AmountBalance)";
	ElsIf Str.Resource = "QuantityBalance" Then
		ResourceText = "SUM(Reg.QuantityBalance)";
	ElsIf Str.Resource = "AmountReceipt" Then
		ResourceText = "SUM(Reg.AmountReceipt)";
	ElsIf Str.Resource = "AmountExpense" Then
		ResourceText = "SUM(Reg.AmountExpense)";
	ElsIf Str.Resource = "QuantityReceipt" Then
		ResourceText = "SUM(Reg.QuantityReceipt)";
	ElsIf Str.Resource = "QuantityExpense" Then
		ResourceText = "SUM(Reg.QuantityExpense)";
	Else
		Return;
	EndIf; 
	
	If Str.Resource = "AmountBalance" OR Str.Resource = "QuantityBalance" Then
		
		ItemText =  
		"SELECT
		|   &ToCompare AS ToCompare, 
		|   &Index AS Index, 
		|   &Separator AS Separator, 
		|	&Resource AS Value
		|FROM
		|	AccumulationRegister.Inventory.Balance(&Period, GLAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.Inventory)) AS Reg
		|WHERE &Filters
		|GROUP BY &Groups";
		
	Else
		
		ItemText =  
		"SELECT
		|   &ToCompare AS ToCompare, 
		|   &Index AS Index, 
		|   &Separator AS Separator, 
		|	&Resource AS Value
		|FROM
		|	AccumulationRegister.Inventory.Turnovers(&StartDate, &EndDate, Period, GLAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.Inventory)) AS Reg
		|WHERE &Filters
		|GROUP BY &Groups";
		
	EndIf; 
	
	ItemText = StrReplace(
		ItemText,
		"&Resource",
		ResourceText);
	AddItemToQueryIndicators(Query, ItemText, Str, Index, Parameters);
	
EndProcedure

Procedure Attachable_PurchasesCalculation(Query, Str, Index, Parameters)
	
	If Str.Resource = "Purchases" Then
		ResourceText = "SUM(Reg.AmountTurnover)";
	Else
		Return;
	EndIf; 
	
	ItemText = StrReplace(
		"SELECT
		|   &ToCompare AS ToCompare, 
		|   &Index AS Index, 
		|   &Separator AS Separator, 
		|	&Resource AS Value
		|FROM
		|	AccumulationRegister.Purchases.Turnovers(&StartDate, &EndDate, Period, ) AS Reg
		|WHERE &Filters
		|GROUP BY &Groups",
		"&Resource",
		ResourceText);
	AddItemToQueryIndicators(Query, ItemText, Str, Index, Parameters);
	
EndProcedure

Procedure Attachable_DebtsCalculation(Query, Str, Index, Parameters)
	
	If Str.Resource = "OurDebts" Then
		ResourceText = "SUM(CASE WHEN Reg.AmountBalance < 0 THEN -Reg.AmountBalance ELSE 0 END)";
	ElsIf Str.Resource = "DebtsToUs" Then 
		ResourceText = "SUM(CASE WHEN Reg.AmountBalance > 0 THEN Reg.AmountBalance ELSE 0 END)";
	ElsIf Str.Resource = "TotalDebts" Then
		ResourceText = "SUM(Reg.AmountBalance)";
	Else
		Return;
	EndIf; 
	
	ItemText =  
	"SELECT
	|	&ToCompare AS ToCompare,
	|	&Index AS Index,
	|	Reg.Separator AS Separator,
	|	&Resource AS Value
	|FROM
	|	(SELECT
	|		Reg.Counterparty AS Counterparty,
	|		Reg.PaymentType AS PaymentType,
	|		&Separator AS Separator,
	|		SUM(Reg.AmountBalance) AS AmountBalance
	|	FROM
	|		AccumulationRegister.AccountsReceivable.Balance(&Period, ) AS Reg
	|	WHERE
	|		&Filters
	|	
	|	GROUP BY
	|		Reg.Counterparty,
	|		Reg.PaymentType,
	|		&Separator
	|
	|	UNION ALL
	|	
	|	SELECT
	|		Reg.Counterparty,
	|		Reg.PaymentType,
	|		&Separator,
	|		SUM(-Reg.AmountBalance)
	|	FROM
	|		AccumulationRegister.AccountsPayable.Balance(&Period, ) AS Reg
	|	WHERE
	|		&Filters
	|	
	|	GROUP BY
	|		Reg.Counterparty,
	|		Reg.PaymentType,
	|		&Separator) AS Reg
	|
	|GROUP BY
	|	Reg.Separator";
	
	ItemText = StrReplace(
		ItemText,
		"&Resource",
		ResourceText);
	AddItemToQueryIndicators(Query, ItemText, Str, Index, Parameters);
	
EndProcedure

Procedure Attachable_FinAnalysisCalculation(Query, Str, Index, Parameters)
	
	If Str.Resource = "NetAssets" Then
		ResourceText = "SUM(Reg.AmountBalance)";
	Else
		Return;
	EndIf; 
	
	ItemText =  
	"SELECT
	|	&ToCompare AS ToCompare,
	|	&Index AS Index,
	|	&Separator AS Separator,
	|	&Resource AS Value
	|FROM
	|	AccountingRegister.AccountingJournalEntries.Balance(
	|			&Period,
	|			Account.TypeOfAccount = VALUE(Enum.GLAccountsTypes.CashAndCashEquivalents)
	|				OR Account.TypeOfAccount = VALUE(Enum.GLAccountsTypes.FixedAssets)
	|				OR Account.TypeOfAccount = VALUE(Enum.GLAccountsTypes.Depreciation)
	|				OR Account.TypeOfAccount = VALUE(Enum.GLAccountsTypes.AccountsReceivable)
	|				OR Account.TypeOfAccount = VALUE(Enum.GLAccountsTypes.Inventory)
	|				OR Account.TypeOfAccount = VALUE(Enum.GLAccountsTypes.AccountsPayable)
	|				OR Account.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherFixedAssets)
	|				OR Account.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherCurrentAssets),
	|			PlanningPeriod = VALUE(Catalog.PlanningPeriods.Actual)) AS Reg
	|WHERE
	|	&Filters";
		                 
	ItemText = StrReplace(
		ItemText,
		"&Resource",
		ResourceText);
	AddItemToQueryIndicators(Query, ItemText, Str, Index, Parameters);
	
EndProcedure

Procedure Attachable_RetailCalculation(Query, Str, Index, Parameters)
	
	If Str.Resource = "RetailDocuments" Then
		ResourceText = "SUM(Reg.AmountTurnover)";
	ElsIf Str.Resource = "ReceiptQuantity" Then
		ResourceText = "SUM(Reg.ReceiptQuantity)";
	ElsIf Str.Resource = "AverageReceipt" Then
		ResourceText = "CASE WHEN SUM(Reg.ReceiptQuantity) = 0 THEN 0 ELSE SUM(Reg.SalesAmount) / SUM(Reg.ReceiptQuantity) END";
	ElsIf Str.Resource = "ReceivedInCash" Then
		ResourceText = "SUM(Reg.ReceivedInCash)";
	ElsIf Str.Resource = "ReceivedByCards" Then
		ResourceText = "SUM(Reg.ReceivedByCards)";
	ElsIf Str.Resource = "AmountBalance" Then
		ResourceText = "SUM(Reg.AmountBalance)";
	Else
		Return;
	EndIf; 
	
	If Str.Resource = "RetailDocuments" Then
		
		QueryText = 
		"SELECT
		|   &ToCompare AS ToCompare, 
		|   &Index AS Index, 
		|   &Separator AS Separator, 
		|	&Resource AS Value
		|FROM
		|	AccumulationRegister.Sales.Turnovers(&StartDate, &EndDate, Auto, ) AS Reg
		|WHERE &Filters
		|GROUP BY &Groups";
		
	ElsIf Str.Resource = "ReceiptQuantity" OR Str.Resource = "AverageReceipt" Then
		
		QueryText = 
		"SELECT
		|	&ToCompare AS ToCompare,
		|	&Index AS Index,
		|	Reg.Separator AS Separator,
		|	&Resource AS Value
		|FROM
		|	(SELECT
		|		&Separator AS Separator,
		|		SalesTurnovers.Document.CashCR AS CashCR,
		|		SalesTurnovers.Company AS Company,
		|		SalesTurnovers.Document.Counterparty AS Counterparty,
		|		SalesTurnovers.Department AS Department,
		|		SalesTurnovers.Document.StructuralUnit AS Warehouse,
		|		SalesTurnovers.Responsible AS ResponsiblePerson,
		|		COUNT(DISTINCT CASE
		|				WHEN SalesTurnovers.Recorder REFS Document.SalesSlip
		|						OR SalesTurnovers.Recorder REFS Document.ProductReturn
		|					THEN SalesTurnovers.Recorder
		|				WHEN DocumentCashReceipt.Ref REFS Document.SalesSlip
		|					THEN DocumentCashReceipt.Ref
		|				WHEN DocumentRefundReceipt.Ref REFS Document.ProductReturn
		|					THEN DocumentRefundReceipt.Ref
		|			END) AS ReceiptQuantity,
		|		0 AS SalesAmount
		|	FROM
		|		AccumulationRegister.Sales.Turnovers(&StartDate, &EndDate, Auto, ) AS SalesTurnovers
		|			LEFT JOIN Document.SalesSlip AS DocumentCashReceipt
		|			ON SalesTurnovers.Recorder = DocumentCashReceipt.CashCRSession
		|			LEFT JOIN Document.ProductReturn AS DocumentRefundReceipt
		|			ON SalesTurnovers.Recorder = DocumentRefundReceipt.CashCRSession
		|	WHERE
		|		(SalesTurnovers.Recorder REFS Document.ShiftClosure
		|				OR SalesTurnovers.Recorder REFS Document.SalesSlip
		|				OR SalesTurnovers.Recorder REFS Document.ProductReturn)
		|	
		|	GROUP BY
		|		SalesTurnovers.Responsible,
		|		SalesTurnovers.Department,
		|		SalesTurnovers.Document.CashCR,
		|		SalesTurnovers.Company,
		|		SalesTurnovers.Document.StructuralUnit,
		|		SalesTurnovers.Document.Counterparty
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		&Separator,
		|		SalesTurnovers.Document.CashCR,
		|		SalesTurnovers.Company,
		|		SalesTurnovers.Document.Counterparty,
		|		SalesTurnovers.Document.Department,
		|		SalesTurnovers.Document.StructuralUnit,
		|		SalesTurnovers.Responsible,
		|		0,
		|		SUM(SalesTurnovers.AmountTurnover)
		|	FROM
		|		AccumulationRegister.Sales.Turnovers(&StartDate, &EndDate, Auto, ) AS SalesTurnovers
		|	
		|	GROUP BY
		|		SalesTurnovers.Document.Department,
		|		SalesTurnovers.Responsible,
		|		SalesTurnovers.Document.CashCR,
		|		SalesTurnovers.Document.Counterparty,
		|		SalesTurnovers.Company,
		|		SalesTurnovers.Document.StructuralUnit) AS Reg
		|WHERE
		|	&Filters
		|
		|GROUP BY
		|	Reg.Separator";
		
	ElsIf Str.Resource = "ReceivedInCash" OR Str.Resource = "ReceivedByCards" Then
		
		QueryText = 
		"SELECT
		|	&ToCompare
		|	AS ToCompare, &Index
		|	AS Index, Reg.Separator
		|	AS Separator, &Resource
		|AS
		|	Value
		|		FROM (SELECT &Separator
		|		AS Separator, SalesTurnovers.Company
		|		AS Company, SalesTurnovers.Document.Counterparty
		|		AS Counterparty, SalesTurnovers.Department
		|		AS Department, SalesTurnovers.Document.StructuralUnit
		|		AS Warehouse, SalesTurnovers.ResponsiblePerson
		|		AS ResponsiblePerson, SalesTurnovers.Document.CashCR
		|		AS CashCR, SalesTurnovers.AmountTurnover
		|		AS ReceivedInCash,
		|	0
		|		AS ReceivedByCards FROM AccumulationRegister.Sales.Turnovers(&StartDate, &EndDate,
		|	Auto,
		|		) AS SalesTurnovers
		|				WHERE (SalesTurnovers.Recorder REFS Document.ShiftClosure
		|				OR SalesTurnovers.Recorder REFS Document.SalesSlip
		|	OR
		|	SalesTurnovers.Recorder REFS
		|	Document.RefundReceipt)
		|	UNION
		|		ALL
		|		SELECT
		|		&Separator,
		|		PaymentByPaymentCardsTurnovers.Company,
		|		PaymentByPaymentCardsTurnovers.Counterparty,
		|		PaymentByPaymentCardsTurnovers.Recorder.Department,
		|		PaymentByPaymentCardsTurnovers.StructuralUnit,
		|		PaymentByPaymentCardsTurnovers.Recorder.ResponsiblePerson,
		|		PaymentByPaymentCardsTurnovers.POSTerminal.CashFund,
		|	-PaymentByPaymentCardsTurnovers.AmountTurnover,
		|		PaymentByPaymentCardsTurnovers.AmountTurnover FROM AccumulationRegister.PaymentByPaymentCards.Turnovers(&StartDate, &EndDate,
		|	Auto,
		|		) AS PaymentByPaymentCardsTurnovers
		|				WHERE (PaymentByPaymentCardsTurnovers.Recorder REFS Document.RetailSalesReport
		|				OR PaymentByPaymentCardsTurnovers.Recorder REFS Document.CashReceipt OR PaymentByPaymentCardsTurnovers.Recorder
		|REFS
		|	Document.RefundReceipt))
		|AS
		|Reg WHERE
		|	&Filters GROUP BY Reg.Separator";
		
	ElsIf Str.Resource = "AmountBalance" Then
		
		QueryText =  
		"SELECT
		|	&ToCompare AS ToCompare,
		|	&Index AS Index,
		|	&Separator AS Separator,
		|	&Resource AS Value
		|FROM
		|	AccumulationRegister.CashInCashRegisters.Balance(&Period, ) AS Reg
		|WHERE
		|	&Filters";
		
	EndIf; 
	
	ItemText = StrReplace(QueryText, "&Resource", ResourceText);
	AddItemToQueryIndicators(Query, ItemText, Str, Index, Parameters);
	
EndProcedure

#EndRegion

#Region ChartCalculation

Procedure Attachable_SalesDynamicsChart(Query, QueryParameters, Str, Index)
	
	// Series
	SeriesText2 = "0";
	If Str.Series = "Total" Then
		SeriesText1 = "SUM(Reg.AmountTurnover)";
	ElsIf Str.Series = "Quantity" Then
		SeriesText1 = "SUM(Reg.QuantityTurnover)";
	ElsIf Str.Series = "NumberOfDocuments" Then
		SeriesText1 = "COUNT(DISTINCT Reg.Recorder)";
	ElsIf Str.Series = "Profit" Then
		SeriesText1 = "SUM(Reg.AmountTurnover - Reg.CostTurnover)";
	ElsIf Str.Series = "ProfitAndCost" Then
		SeriesText1 = "SUM(Reg.CostTurnover)";
		SeriesText2 = "SUM(Reg.AmountTurnover - Reg.CostTurnover)";
	ElsIf Str.Series = "ReturnsAmount" Then
		SeriesText1 = "SUM(CASE WHEN Reg.Recorder REFS Document.SupplierInvoice OR Reg.Recorder REFS Document.ProductReturn THEN -Reg.AmountTurnover ELSE 0 END)";
	ElsIf Str.Series = "ReturnsQuantity" Then
		SeriesText1 = "SUM(CASE WHEN Reg.Recorder REFS Document.SupplierInvoice OR Reg.Recorder REFS Document.ProductReturn THEN -Reg.QuantityTurnover ELSE 0 END)";
	Else
		Return;
	EndIf;
	
	// Dots
	If Str.Point = "Day" Then
	    PointText = "Reg.DayPeriod";
	ElsIf Str.Point = "Week" Then
	    PointText = "Reg.WeekPeriod";
	ElsIf Str.Point = "Month" Then
	    PointText = "Reg.MonthPeriod";
	Else
		Return;
	EndIf;
	
	ItemText = 
	"SELECT
	|	&Series1 AS Series1,
	|	&Series2 AS Series2,
	|	&Point AS Point
	|FROM
	|	AccumulationRegister.Sales.Turnovers(&StartDate, &EndDate, Auto, ) AS Reg
	|WHERE &Filters
	|GROUP BY &Point
	|ORDER BY Point
	|TOTALS SUM(Series1), SUM(Series2) BY Point PERIODS(" + Str.Point + ", &StartDate, &EndDate)";
	ItemText = StrReplace(ItemText, "&Series1", SeriesText1);
	ItemText = StrReplace(ItemText, "&Series2", SeriesText2);
	ItemText = StrReplace(ItemText, "&Point", PointText);
	AddItemToQueryCharts(Query, QueryParameters, ItemText, Str, Index);
	Query.SetParameter("Index", Index);
	
EndProcedure

Procedure Attachable_SalesStructureChart(Query, QueryParameters, Str, Index)
	
	// Series
	If Str.Series = "ProductsParent" Then
	    SeriesText = "Reg.Products.Parent";
	ElsIf Str.Series = "ProductsCategory" Then
	    SeriesText = "Reg.Products.ProductsCategory";
	ElsIf Str.Series = "Warehouse" Then
	    SeriesText = "Reg.Document.StructuralUnit";
	ElsIf Str.Series = "Products" Then
	    SeriesText = "Reg.Products";
	ElsIf Str.Series = "Counterparty" Then
	    SeriesText = "Reg.Document.Counterparty";
	ElsIf Str.Series = "Company" Then
	    SeriesText = "Reg.Company";
	ElsIf Str.Series = "Department" Then
	    SeriesText = "Reg.Department";
	ElsIf Str.Series = "Currency" Then
	    SeriesText = "Reg.Document.DocumentCurrency";
	ElsIf Str.Series = "Responsible" Then
	    SeriesText = "Reg.Responsible";
	ElsIf Str.Series = "ProductsProperty" OR Str.Series = "CustomerProperty" Then
	    SeriesText = "IsNull(AdditionalAttributes.Value, UNDEFINED)";
	Else
		Return;
	EndIf;
	
	// Dots
	If Str.Point = "Total" Then
		PointText = "SUM(Reg.AmountTurnover)";
	ElsIf Str.Point = "Quantity" Then
		PointText = "SUM(Reg.QuantityTurnover)";
	ElsIf Str.Point = "NumberOfDocuments" Then
		PointText = "COUNT(DISTINCT Reg.Recorder)";
	ElsIf Str.Point = "Profit" Then
		PointText = "SUM(Reg.AmountTurnover - Reg.CostTurnover)";
	ElsIf Str.Point = "ReturnsAmount" Then
		PointText = "SUM(CASE WHEN  Reg.Recorder REFS Document.RefundReceipt THEN -Reg.AmountTurnover ELSE 0 END)";
	ElsIf Str.Point = "ReturnsQuantity" Then
		PointText = "SUM(CASE WHEN Reg.Recorder REFS Document.RefundReceipt THEN -Reg.QuantityTurnover ELSE 0 END)";
	Else
		Return;
	EndIf;
	
	If Str.Series = "ProductsProperty" Then
		
		ItemText = 
		"SELECT
		|	Reg.Series1 AS Series1,
		|	Reg.Series2 AS Series2,
		|	Reg.Point AS Point
		|FROM
		|	(SELECT
		|		ISNULL(AdditionalAttributes.Property, UNDEFINED) AS ProductsProperty,
		|		&Series AS Series1,
		|		0 AS Series2,
		|		&Point AS Point
		|	FROM
		|		AccumulationRegister.Sales.Turnovers(&StartDate, &EndDate, Auto, ) AS Reg
		|			LEFT JOIN Catalog.Products.AdditionalAttributes AS AdditionalAttributes
		|			ON Reg.Products = AdditionalAttributes.Ref
		|	
		|	GROUP BY
		|		AdditionalAttributes.Property) AS Reg
		|WHERE
		|	&Filters
		|
		|ORDER BY
		|	Point DESC";
		
	ElsIf Str.Series = "CustomerProperty" Then
		
		ItemText = 
		"SELECT
		|	Reg.Series1 AS Series1,
		|	Reg.Series2 AS Series2,
		|	Reg.Point AS Point
		|FROM
		|	(SELECT
		|		ISNULL(AdditionalAttributes.Property, UNDEFINED) AS CustomerProperty,
		|		&Series AS Series1,
		|		0 AS Series2,
		|		&Point AS Point
		|	FROM
		|		AccumulationRegister.Sales.Turnovers(&StartDate, &EndDate, Auto, ) AS Reg
		|			LEFT JOIN Catalog.Counterparties.AdditionalAttributes AS AdditionalAttributes
		|			ON Reg.Document.Counterparty = AdditionalAttributes.Ref
		|	
		|	GROUP BY
		|		AdditionalAttributes.Property) AS Reg
		|WHERE
		|	&Filters
		|
		|ORDER BY
		|	Point DESC";
		
	Else
		
		ItemText = 
		"SELECT
		|	&Series AS Series1,
		|	0 AS Series2,
		|	&Point AS Point
		|FROM
		|	AccumulationRegister.Sales.Turnovers(&StartDate, &EndDate, Auto, ) AS Reg
		|WHERE &Filters
		|GROUP BY &Series
		|ORDER BY Point DESC";
		
	EndIf;
	
	ItemText = StrReplace(ItemText, "&Series", SeriesText);
	ItemText = StrReplace(ItemText, "&Point", PointText);
	AddItemToQueryCharts(Query, QueryParameters, ItemText, Str, Index);
	
EndProcedure

Procedure Attachable_RetailSalesStructureChart(Query, QueryParameters, Str, Index)
	
	// Series
	If Str.Series = "ProductsParent" Then
	    SeriesText = "Reg.Products.Parent";
	ElsIf Str.Series = "ProductsCategory" Then
	    SeriesText = "Reg.Products.ProductsCategory";
	ElsIf Str.Series = "Warehouse" Then
	    SeriesText = "Reg.Document.StructuralUnit";
	ElsIf Str.Series = "Products" Then
	    SeriesText = "Reg.Products";
	ElsIf Str.Series = "Counterparty" Then
	    SeriesText = "Reg.Document.Counterparty";
	ElsIf Str.Series = "Company" Then
	    SeriesText = "Reg.Company";
	ElsIf Str.Series = "Department" Then
	    SeriesText = "Reg.Department";
	ElsIf Str.Series = "CashCR" Then
	    SeriesText = "Reg.Document.CashCR";
	ElsIf Str.Series = "Currency" Then
	    SeriesText = "Reg.Document.DocumentCurrency";
	ElsIf Str.Series = "Responsible" Then
	    SeriesText = "Reg.ResponsiblePerson";
	ElsIf Str.Series = "ProductsProperty" OR Str.Series="CustomerProperty" Then
	    SeriesText = "IsNull(AdditionalAttributes.Value, UNDEFINED)";
	Else
		Return;
	EndIf;
	
	// Dots
	If Str.Point = "Total" Then
		PointText = "SUM(Reg.AmountTurnover)";
	ElsIf Str.Point = "Quantity" Then
		PointText = "SUM(Reg.QuantityTurnover)";
	ElsIf Str.Point = "NumberOfDocuments" Then
		PointText = "COUNT(DISTINCT Reg.Recorder)";
	ElsIf Str.Point = "Profit" Then
		PointText = "SUM(Reg.AmountTurnover - Reg.CostTurnover)";
	ElsIf Str.Point = "ReturnsAmount" Then
		PointText = "SUM(CASE WHEN Reg.Recorder REFS Document.RefundReceipt THEN -Reg.AmountTurnover ELSE 0 END)";
	ElsIf Str.Point = "ReturnsQuantity" Then
		PointText = "SUM(CASE WHEN Reg.Recorder REFS Document.RefundReceipt THEN -Reg.QuantityTurnover ELSE 0 END)";
	ElsIf Str.Point = "ReceiptQuantity" Then
		PointText = "MAX(NestedQueryReceipts.ReceiptQuantity)";
	ElsIf Str.Point = "AverageReceipt" Then
		PointText = "CASE WHEN MAX(NestedQueryReceipts.ReceiptQuantity) = 0 THEN 0 ELSE SUM(Reg.AmountTurnover) / MAX(NestedQueryReceipts.ReceiptQuantity) END";
	Else
		Return;
	EndIf;
	
	If Str.Series = "ProductsProperty" Then
		
		ItemText = 
		"SELECT
		|	Reg.Series1 AS Series1,
		|	Reg.Series2 AS Series2,
		|	Reg.Point AS Point 
		|FROM (SELECT
		|		IsNull(AdditionalAttributes.Property, UNDEFINED) AS ProductsProperty,
		|		&Series AS Series1,
		|		0 AS Series2,
		|		&Point AS Point
		|	FROM
		|		AccumulationRegister.Sales.Turnovers(&StartDate, &EndDate, Auto, ) AS Reg
		|		LEFT JOIN Catalog.Products.AdditionalAttributes AS AdditionalAttributes
		|			ON Reg.Products = AdditionalAttributes.Ref
		|	WHERE (Reg.Document REFS Document.RetailSalesReport OR Reg.Document REFS Document.CashReceipt)
		|	GROUP BY AdditionalAttributes.Property, &Series) AS Reg 
		|WHERE &Filters
		|ORDER BY Point DESC";
		
	ElsIf Str.Series = "CustomerProperty" Then
		
		ItemText = 
		"SELECT
		|	Reg.Series1 AS Series1,
		|	Reg.Series2 AS Series2,
		|	Reg.Point AS Point 
		|FROM (SELECT
		|		IsNull(AdditionalAttributes.Property, UNDEFINED) AS CustomerProperty,
		|		&Series AS Series1,
		|		0 AS Series2,
		|		&Point AS Point
		|	FROM
		|		AccumulationRegister.Sales.Turnovers(&StartDate, &EndDate, Auto, ) AS Reg
		|		LEFT JOIN Catalog.Counterparties.AdditionalAttributes AS AdditionalAttributes
		|			ON Reg.Counterparty = AdditionalAttributes.Ref
		|	WHERE (Reg.Document REFS Document.RetailSalesReport OR Reg.Document REFS Document.CashReceipt)
		|	GROUP BY AdditionalAttributes.Property, &Series) AS Reg 
		|WHERE &Filters
		|ORDER BY Point DESC";
		
	Else
		
		ItemText = 
		"SELECT
		|	&Series AS Series1,
		|	0 AS Series2,
		|	&Point AS Point
		|FROM
		|	AccumulationRegister.Sales.Turnovers(&StartDate, &EndDate, Auto, ) AS Reg
		|WHERE &Filters
		|	AND (Reg.Document REFS Document.RetailSalesReport OR Reg.Document REFS Document.CashReceipt)
		|GROUP BY &Series
		|ORDER BY Point DESC";
		
	EndIf;
	
	If Str.Point = "ReceiptQuantity" OR Str.Point = "AverageReceipt" Then
		
		TextConnection =
		"	LEFT JOIN (
		|		SELECT
		|			&Series AS Series1,
		|			0 AS Series2,
		|			COUNT(DISTINCT CASE
		|				WHEN Reg.Recorder REFS Document.CashReceipt
		|						OR Reg.Recorder REFS Document.RefundReceipt
		|					THEN Reg.Recorder
		|				WHEN DocumentCashReceipt.Ref REFS Document.CashReceipt
		|					THEN DocumentCashReceipt.Ref
		|				WHEN DocumentRefundReceipt.Ref REFS Document.RefundReceipt
		|					THEN DocumentRefundReceipt.Ref
		|			END) AS ReceiptQuantity
		|		FROM
		|			AccumulationRegister.Sales.Turnovers(&StartDate, &EndDate, Auto, ) AS Reg
		|				LEFT JOIN Document.CashReceipt AS DocumentCashReceipt
		|				ON Reg.Recorder = DocumentCashReceipt.RegisterShift
		|				LEFT JOIN Document.RefundReceipt AS DocumentRefundReceipt
		|				ON Reg.Recorder = DocumentRefundReceipt.RegisterShift
		|		WHERE
		|			(Reg.Recorder REFS Document.RetailSalesReport
		|					OR Reg.Recorder REFS Document.CashReceipt
		|					OR Reg.Recorder REFS Document.RefundReceipt)
		|		GROUP BY &Series) AS NestedQueryReceipts
		|	ON &Series=NestedQueryReceipts.Series1
		|WHERE &Filters";
		
		ItemText = StrReplace(ItemText, "WHERE &Filters", TextConnection);
		
	EndIf; 
	
	ItemText = StrReplace(ItemText, "&Series", SeriesText);
	ItemText = StrReplace(ItemText, "&Point", PointText);
	AddItemToQueryCharts(Query, QueryParameters, ItemText, Str, Index);
	
EndProcedure

Procedure Attachable_FundsDynamicsChart(Query, QueryParameters, Str, Index)
	
	// Series
	If Str.Series = "AmountBalance" Then
		SeriesText = "SUM(Reg.AmountClosingBalance)";
	ElsIf Str.Series = "AmountReceipt" Then
		SeriesText = "SUM(Reg.AmountReceipt)";
	ElsIf Str.Series = "AmountExpense" Then
		SeriesText = "SUM(Reg.AmountExpense)";
	Else
		Return;
	EndIf;
	
	// Dots
	If Str.Point = "Day" Then
	    PointText = "Reg.DayPeriod";
	ElsIf Str.Point = "Week" Then
	    PointText = "Reg.WeekPeriod";
	ElsIf Str.Point = "Month" Then
	    PointText = "Reg.MonthPeriod";
	Else
		Return;
	EndIf;
		
	ItemText = 
	"SELECT
	|	&Series AS Series1,
	|	0 AS Series2,
	|	&Point AS Point
	|FROM
	|	AccumulationRegister.CashAssets.BalanceAndTurnovers(&StartDate, &EndDate, Auto, RegisterRecordsAndPeriodBoundaries, ) AS Reg
	|WHERE &Filters
	|GROUP BY &Point
	|ORDER BY Point
	|TOTALS SUM(Series1), SUM(Series2) BY Point PERIODS(" + Str.Point + ", &StartDate, &EndDate)";
	ItemText = StrReplace(ItemText, "&Series", SeriesText);
	ItemText = StrReplace(ItemText, "&Point", PointText);
	AddItemToQueryCharts(Query, QueryParameters, ItemText, Str, Index);
	Query.SetParameter("Index", Index);
	
EndProcedure

Procedure Attachable_FundsStructureChart(Query, QueryParameters, Str, Index)
	
	// Series
	If Str.Series = "BankAccountCashFund" Then
	    SeriesText = "Reg.BankAccountCashFund";
	ElsIf Str.Series = "Currency" Then
	    SeriesText = "Reg.Currency";
	ElsIf Str.Series = "Company" Then
	    SeriesText = "Reg.Company";
	ElsIf Str.Series = "FundsType" Then
	    SeriesText = "Reg.FundsType";
	ElsIf Str.Series = "Dimension" Then
	    SeriesText = "Reg.Dimension";
	ElsIf Str.Series = "Item" Then
	    SeriesText = "Reg.Item";
	Else
		Return;
	EndIf;
	
	If Str.Series = "Dimension" OR Str.Series = "Item" Then
		// Dots
		If Str.Point = "AmountReceipt" Then
			PointText = "SUM(CASE WHEN Reg.RecordType = VALUE(AccumulationRecordType.Receipt) THEN Reg.Total ELSE 0 END)";
		ElsIf Str.Point = "AmountExpense" Then
			PointText = "SUM(CASE WHEN Reg.RecordType = VALUE(AccumulationRecordType.Expense) THEN Reg.Total ELSE 0 END)";
		Else
			Return;
		EndIf;
		
		ItemText = 
		"SELECT
		|	&Series AS Series1,
		|	0 AS Series2,
		|	&Point AS Point
		|FROM
		|	AccumulationRegister.CashAssets AS Reg
		|WHERE
		|	Reg.Period BETWEEN &StartDate AND &EndDate
		|	AND &Filters
		|
		|ORDER BY
		|	Point DESC";
	Else
		// Dots
		If Str.Point = "AmountBalance" Then
			PointText = "COSUMUNT(Reg.AmountClosingBalance)";
		ElsIf Str.Point = "AmountReceipt" Then
			PointText = "SUM(Reg.AmountReceipt)";
		ElsIf Str.Point = "AmountExpense" Then
			PointText = "SUM(Reg.AmountExpense)";
		Else
			Return;
		EndIf;
		
		ItemText = 
		"SELECT
		|	&Series AS Series1,
		|	0 AS Series2,
		|	&Point AS Point
		|FROM
		|	AccumulationRegister.CashAssets.BalanceAndTurnovers(&StartDate, &EndDate, Auto, RegisterRecordsAndPeriodBoundaries, ) AS Reg
		|WHERE
		|	&Filters
		|
		|ORDER BY
		|	Point DESC";
	EndIf; 
	
	ItemText = StrReplace(ItemText, "&Series", SeriesText);
	ItemText = StrReplace(ItemText, "&Point", PointText);
	AddItemToQueryCharts(Query, QueryParameters, ItemText, Str, Index);
	
EndProcedure

Procedure Attachable_AssetDynamicsChart(Result, Str, Index) Export
	
	// Series
	If Not Str.Series = "Total" Then
		Return;
	EndIf;
	
	// Dots
	If Not Str.Point = "Time" Then
		Return;
	EndIf;
	
	DataCompositionSchema = DataProcessors.BusinessPulse.GetTemplate("DCS_NetAssets");
	ReportSettings = DataCompositionSchema.DefaultSettings;
	
	ExternalDataSets = New Structure;
	
	If Not DataCompositionSchema.DataSets.Find("PeriodTable") = Undefined Then
		
		DataTable = New ValueTable;
		DataTable.Columns.Add("BalancePeriod", New TypeDescription("Date", New DateQualifiers(DateFractions.Date)));
		
		EndOfPeriod		= ?(ValueIsFilled(Str.Period.EndDate), EndOfMonth(Str.Period.EndDate), EndOfMonth(CurrentSessionDate()));
		BeginOfPeriod	= ?(ValueIsFilled(Str.Period.StartDate), Str.Period.StartDate, BegOfYear(CurrentSessionDate()));
		DayCount		= Round((EndOfPeriod - BeginOfPeriod) / (3600 * 24));
		DaysForPeriod	= Round(DayCount / 10); 
		If DaysForPeriod = 0 Then
			DaysForPeriod = 1;
		EndIf; 
		
		Position = BeginOfPeriod;
		While Position < EndOfPeriod Do
			DataTable.Add().BalancePeriod = Position;
			Position = Position + DaysForPeriod * 24 * 3600;
		EndDo;
		
		ExternalDataSets.Insert("PeriodTable", DataTable);
	EndIf;
	
	If TypeOf(Str.Filters) = Type("FixedArray") AND Str.Filters.Count()>0 Then
		For Each Filter In Str.Filters Do
			FilterItem					= ReportSettings.Filter.Items.Add(Type("DataCompositionFilterItem"));
			FilterItem.LeftValue		= New DataCompositionField(Filter.Field);
			FilterItem.ComparisonType	= Filter.ComparisonType;
			FilterItem.RightValue		= Filter.Value;
			FilterItem.Use				= True;
		EndDo;
	EndIf;
	
	TemplateComposer = New DataCompositionTemplateComposer;
	CompositionTemplate = TemplateComposer.Execute(DataCompositionSchema, ReportSettings,,, Type("DataCompositionValueCollectionTemplateGenerator"));

	// We will create and initialize the composition processor
	CompositionProcessor = New DataCompositionProcessor;
	CompositionProcessor.Initialize(CompositionTemplate, ExternalDataSets,, True);

	// We will create and initialize the result display processor
	OutputProcessor = New DataCompositionResultValueCollectionOutputProcessor;
	Tree = New ValueTree;
	OutputProcessor.SetObject(Tree);
	OutputProcessor.Output(CompositionProcessor);

	If Result.Get(Index) = Undefined Then
		Result.Insert(Index, New Array);
	EndIf;
	
	Order = 0;
	
	For Each StrPeriod In Tree.Strings Do
		
		If StrPeriod.Strings.Count() = 0 Then
			Continue;
		EndIf; 
		
		ValueStructure = New Structure("Series1, Series2, Series3, Series4, Series5", 0, 0, 0, 0, 0);
		For Each StrDetails In StrPeriod.Strings Do
			
			If StrDetails.AccountType = Enums.GLAccountsTypes.AccountsReceivable 
				OR StrDetails.AccountType = Enums.GLAccountsTypes.AccountsPayable Then
					If StrDetails.AmountBalance < 0 Then
						ValueStructure.Series1 = ValueStructure.Series1 + StrDetails.AmountBalance;
					Else
						ValueStructure.Series2 = ValueStructure.Series2 + StrDetails.AmountBalance;
					EndIf; 
			ElsIf StrDetails.AccountType = Enums.GLAccountsTypes.CashAndCashEquivalents Then
				ValueStructure.Series3 = ValueStructure.Series3 + StrDetails.AmountBalance;
			ElsIf StrDetails.AccountType = Enums.GLAccountsTypes.Inventory Then
				ValueStructure.Series4 = ValueStructure.Series4 + StrDetails.AmountBalance;
			ElsIf StrDetails.AccountType = Enums.GLAccountsTypes.FixedAssets 
				OR StrDetails.AccountType = Enums.GLAccountsTypes.OtherFixedAssets 
				OR StrDetails.AccountType = Enums.GLAccountsTypes.Depreciation 
				OR StrDetails.AccountType = Enums.GLAccountsTypes.OtherCurrentAssets Then
					ValueStructure.Series5 = ValueStructure.Series5 + StrDetails.AmountBalance;
			EndIf;
			
		EndDo;
		
		MinValue = Min(ValueStructure.Series1, ValueStructure.Series2, ValueStructure.Series3, ValueStructure.Series4, ValueStructure.Series5);
		ValueStructure.Insert("BaseValue", ?(MinValue < 0, MinValue, 0));
		
		For s = 1 To 5 Do
			If ValueStructure["Series" + s] < 0 Then
				ValueStructure["Series" + s] = -ValueStructure["Series" + s];
			EndIf; 
		EndDo; 
		
		ValueStructure.Insert("SeriesCount", 	5);
		ValueStructure.Insert("Point",			StrPeriod.BalancePeriod);
		ValueStructure.Insert("ToCompare",		False);
		ValueStructure.Insert("Order",			Order);
		
		Order = Order + 1;
		Result[Index].Add(ValueStructure);
	EndDo; 
	
EndProcedure

#EndRegion 

#EndRegion 

#Region InternalProceduresAndFunctions

#Region Indicators

Procedure AddItemToQueryIndicators(Query, ItemText, Str, Index, Parameters)
	
	Item = ItemText;
	Item = StrReplace(Item, "&ToCompare", "FALSE");
	ProcessQueryItemIndicators(Str, Query, Item, Index);
	
	// Comparison mode
	If (Parameters.ComparisonPeriod <> Undefined AND Not Str.Balance) 
		OR (Parameters.ComparisonDate <> Undefined AND Str.Balance) Then
			Item = ItemText;
			Item = StrReplace(Item, "&ToCompare", "TRUE");
			ProcessQueryItemIndicators(Str, Query, Item, Index, "Comparisons");
	EndIf; 
	
EndProcedure

Procedure ProcessQueryItemIndicators(Str, Query, Item, Index, Suffix = "")
	
	If Not IsBlankString(Suffix) Then
		Item = StrReplace(Item, "&StartDate", "&StartDate" + Suffix);
		Item = StrReplace(Item, "&EndDate", "&EndDate" + Suffix);
		Item = StrReplace(Item, "&Period", "&Period" + Suffix);
	EndIf; 
	
	Item = StrReplace(Item, "&Index", String(Index));
	
	If TypeOf(Str.Settings) = Type("FixedArray") AND Str.Settings.Count() > 0 Then
		For Each Setting In Str.Settings Do
			If Not Setting.Value Then
				Continue;
			EndIf; 
			
			If Setting.Name = "ByCurrencies" Then				
				Separator = "Currency";
				
				Item = StrReplace(Item, "Reg.Amount",	"Reg.AmountCur");
				Item = StrReplace(Item, "AS Amount",	"AS AmountCur");				
			Else
				Continue;
			EndIf;
			
			Item = StrReplace(Item, "&Separator", "Reg." + Separator);
		EndDo; 
	EndIf;
	
	Item = StrReplace(Item, "&Separator", "UNDEFINED");
	
	If TypeOf(Str.Filters) = Type("FixedArray") AND Str.Filters.Count() > 0 Then
		Filters = "";
		
		For Each Filter In Str.Filters Do
			ParameterName = "Value" + StrReplace(String(New UUID), "-", "");
			
			FilterText = FilterRow(Filter, ParameterName);
			If IsBlankString(FilterText) Then
				Continue;
			EndIf; 
			
			Filters = Filters + Chars.LF + ?(IsBlankString(Filters), "", "AND ");
			Filters = Filters + FilterText;		
			Query.SetParameter(ParameterName, ?(TypeOf(Filter.Value) = Type("ValueList"), Filter.Value.UnloadValues(), Filter.Value));
		EndDo;
		
	EndIf;
	
	If IsBlankString(Filters) Then
		Filters = "TRUE";
	EndIf;
	
	Item = StrReplace(Item, "&Filters", Filters);
	
	If ValueIsFilled(Separator) Then
		Groups = "Reg." + Separator;
	Else
		Groups = "UNDEFINED";
	EndIf;
	
	Item = StrReplace(Item, "&Groups", Groups);
	Query.Text = Query.Text + ?(IsBlankString(Query.Text), "", Chars.LF + "UNION ALL" + Chars.LF);
	Query.Text = Query.Text + Item;
	
EndProcedure

#EndRegion 

#Region Charts

Procedure AddItemToQueryCharts(Query, QueryParameters, ItemText, Str, Index)
	
	Item = ItemText;
	ProcessQueryItemCharts(Str, Query, QueryParameters, Item, Index);
	
	// Comparison mode
	If ValueIsFilled(Str.ComparisonPeriod) Then
		Item = ItemText;
		ProcessQueryItemCharts(Str, Query, QueryParameters, Item, Index, True);
	EndIf; 
	
EndProcedure

Procedure ProcessQueryItemCharts(Str, Query, QueryParameters, Item, Index, ToCompare = False)
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("Index", Index);
	ParametersStructure.Insert("ToCompare", ToCompare);
	ParametersStructure.Insert("QueryWithResults", Find(Item, "TOTALS ") > 0);
	QueryParameters.Add(ParametersStructure);
	
	Suffix = ?(ToCompare, "Comparison", "");
	
	Item = StrReplace(Item, "&StartDate",	"&StartDate" + Suffix + Index);
	Item = StrReplace(Item, "&EndDate",		"&EndDate" + Suffix + Index);
	Item = StrReplace(Item, "&Period",		"&Period" + Suffix + Index);
	Item = StrReplace(Item, "&Index",		String(Index));
	PeriodValue = Str[Suffix + "Period"];
	
	If TypeOf(PeriodValue) = Type("StandardPeriod") Then
		
		Query.SetParameter("StartDate" + Suffix + Index, PeriodValue.StartDate);
		Query.SetParameter("EndDate" + Suffix + Index, 
			?(ValueIsFilled(PeriodValue.EndDate), EndOfDay(PeriodValue.EndDate), EndOfDay(CurrentSessionDate()))
		);
		
	ElsIf TypeOf(PeriodValue) = Type("StandardBeginningDate") Then
		Query.SetParameter("Period" + Suffix + Index, Str["Period" + Suffix].Date);
	ElsIf TypeOf(PeriodValue) = Type("Structure") Then
		
		If PeriodValue.Mode = "SameDayLastWeek" Then
			
			Period = CalculationDate(Str.Period) - 7 * 86400;
			Query.SetParameter("Period" + Suffix + Index, Period);
			
		ElsIf PeriodValue.Mode = "SameDayLastMonth" Then
			
			Period = AddMonth(CalculationDate(Str.Period), -1);
			Query.SetParameter("Period" + Suffix + Index, Period);
			
		ElsIf PeriodValue.Mode = "SameDayLastYear" Then
			
			CalculationDate = CalculationDate(Str.Period);
			Period = Date(
				Year(CalculationDate) - 1, 
				Month(CalculationDate), 
				Day(CalculationDate), 
				Hour(CalculationDate), 
				Minute(CalculationDate), 
				Second(CalculationDate)
			);
			Query.SetParameter("Period" + Suffix + Index, Period);
			
		ElsIf PeriodValue.Mode = "PreviousFloatingPeriod" Then
			
			Period = DriveClientServer.PreviousFloatingPeriod(Str.Period);
			Query.SetParameter("StartDate" + Suffix + Index, Period.StartDate);
			Query.SetParameter("EndDate" + Suffix + Index, 
				?(ValueIsFilled(Period.EndDate), EndOfDay(Period.EndDate), EndOfDay(CurrentSessionDate()))
			);
			
		ElsIf PeriodValue.Mode = "ForLastYear" Then
			
			Period = DriveClientServer.SamePeriodOfLastYear(Str.Period);
			
			If Not Period = Undefined Then
				
				Query.SetParameter("StartDate" + Suffix + Index, Period.StartDate);
				Query.SetParameter("EndDate" + Suffix + Index, 
					?(ValueIsFilled(Period.EndDate), EndOfDay(Period.EndDate), EndOfDay(CurrentSessionDate()))
				);
				
			EndIf;
			
		ElsIf PeriodValue.Mode = "Last7DaysExceptForCurrentDay" Then
			
			CalculationDate = BegOfDay(CurrentSessionDate());
			Query.SetParameter("StartDate" + Suffix + Index, CalculationDate - 7 * 86400);
			Query.SetParameter("EndDate" + Suffix + Index, CalculationDate - 1);
			
		EndIf;
		
	Else
		
		Query.SetParameter("Period" + Suffix + Index, '0001-01-01');
		Query.SetParameter("StartDate" + Suffix + Index, '0001-01-01');
		Query.SetParameter("EndDate" + Suffix + Index, '0001-01-01');
		
	EndIf;
	
	If TypeOf(Str.Filters) = Type("FixedArray") AND Str.Filters.Count() > 0 Then
		
		Filters = "";
		
		For Each Filter In Str.Filters Do
			
			ParameterName = "Value" + StrReplace(String(New UUID), "-", "");
			FilterText = FilterRow(Filter, ParameterName);
			
			If IsBlankString(FilterText) Then
				Continue;
			EndIf; 
			
			Filters = Filters + Chars.LF + ?(IsBlankString(Filters), "", "AND ");
			Filters = Filters + FilterText;
			Query.SetParameter(ParameterName, ?(TypeOf(Filter.Value) = Type("ValueList"), Filter.Value.UnloadValues(), Filter.Value));
			
		EndDo;
		
	EndIf;
	
	If IsBlankString(Filters) Then
		Filters = "TRUE";
	EndIf; 
	
	Item = StrReplace(Item, "&Filters", Filters);
	Query.Text = Query.Text + ?(IsBlankString(Query.Text), "", ";" + Chars.LF);
	Query.Text = Query.Text + Item;
	
EndProcedure

Function CalculationDate(Period)
	
	Return ?(Period.Mode = StandardBeginningDateVariant.BeginningOfNextDay, EndOfDay(CurrentSessionDate()), BegOfDay(Period.Date));
	
EndFunction

#EndRegion 

Function FilterRow(Filter, ParameterName)
	                                          
	If Find(Filter.Field, "DataParameters.") > 0 Then
		Return "";
	EndIf;
	
	Result = "";
	If Filter.ComparisonType = DataCompositionComparisonType.NotInHierarchy
		OR Filter.ComparisonType = DataCompositionComparisonType.NotInList
		OR Filter.ComparisonType = DataCompositionComparisonType.NotInListByHierarchy
		OR Filter.ComparisonType = DataCompositionComparisonType.NotBeginsWith
		OR Filter.ComparisonType = DataCompositionComparisonType.NotLike
		OR Filter.ComparisonType = DataCompositionComparisonType.NotEqual
		OR Filter.ComparisonType = DataCompositionComparisonType.NotFilled
		OR Filter.ComparisonType = DataCompositionComparisonType.NotContains Then
			Result = Result + "Not ";
	EndIf;
	
	If Filter.Field = "RetailDocuments" Then
		
		Result = Result + "Reg.Document REFS Document.ShiftClosure";
		
	ElsIf Find(Filter.Field, "[") > 0 Then 
		
		Position		= Find(Filter.Field, "[");
		EndPosition		= Find(Filter.Field, "]");
		PropertyName	= StrReplace(Mid(Filter.Field, Position + 1, EndPosition - Position - 1), """", """""");
		Path			= Left(Filter.Field, Position - 1);
		Result			= Result + "(" + Path + 
			"AdditionalAttributes.Property IN (SELECT Property.Ref FROM ChartOfCharacteristicTypes.AdditionalDataAndAttributes AS Property 
			|WHERE Property.Description = """ + PropertyName + """) AND " + 
			Path + "AdditionalAttributes.Value = &" + ParameterName + ")";
		
	Else
		
		// Standard register dimension	
		ThisProperty = Find(Filter.Field, "Property") > 0;
		
		FieldName = "Reg." + Filter.Field;
		Result = Result + ?(ThisProperty, "(", "") + FieldName;
		
		If Filter.ComparisonType = DataCompositionComparisonType.NotInHierarchy
			OR Filter.ComparisonType = DataCompositionComparisonType.InHierarchy
			OR Filter.ComparisonType = DataCompositionComparisonType.NotInListByHierarchy
			OR Filter.ComparisonType = DataCompositionComparisonType.InListByHierarchy Then
				Result = Result + " IN HIERARCHY (&" + ParameterName + ")";
		ElsIf Filter.ComparisonType = DataCompositionComparisonType.NotInList
			OR Filter.ComparisonType = DataCompositionComparisonType.InList Then
				Result = Result + " IN (&" + ParameterName + ")";
		ElsIf Filter.ComparisonType = DataCompositionComparisonType.NotBeginsWith
			OR Filter.ComparisonType = DataCompositionComparisonType.BeginsWith Then
				Result = Result + " LIKE &" + ParameterName + "+""%""";
		ElsIf Filter.ComparisonType = DataCompositionComparisonType.NotLike
			OR Filter.ComparisonType = DataCompositionComparisonType.Like Then
				Result = Result + " LIKE &" + ParameterName;
		ElsIf Filter.ComparisonType = DataCompositionComparisonType.NotContains
			OR Filter.ComparisonType = DataCompositionComparisonType.Contains Then
				Result = Result + " LIKE ""%""+&" + ParameterName + "+""%""";
		ElsIf Filter.ComparisonType = DataCompositionComparisonType.NotEqual
			OR Filter.ComparisonType = DataCompositionComparisonType.Equal Then
				Result = Result + " = &" + ParameterName;
		ElsIf Filter.ComparisonType = DataCompositionComparisonType.Greater Then 
			Result = Result + " > &" + ParameterName;
		ElsIf Filter.ComparisonType = DataCompositionComparisonType.GreaterOrEqual Then 
			Result = Result + " >= &" + ParameterName;
		ElsIf Filter.ComparisonType = DataCompositionComparisonType.Less Then 
			Result = Result + " < &" + ParameterName;
		ElsIf Filter.ComparisonType = DataCompositionComparisonType.LessOrEqual Then 
			Result = Result + " <= &" + ParameterName;
		EndIf;
		
		If ThisProperty Then
			Result = Result + " OR " + FieldName + " = UNDEFINED)";
		EndIf; 
		
	EndIf; 
	
	Return Result;
	
EndFunction

Function IndicatorCalculationLimits(IndicatorArray)
	
	Result = New Structure;
	Query = New Query;
	
	If Not IndicatorArray.Find("Sales") = Undefined Then
		Query.Text = Query.Text +
		?(IsBlankString(Query.Text), "", Chars.LF + "UNION ALL" + Chars.LF) +
		"SELECT
		|	""Sales"" AS Indicator,
		|	MIN(Sales.Period) AS StartDate,
		|	MAX(Sales.Period) AS EndDate
		|FROM
		|	AccumulationRegister.Sales AS Sales";
	EndIf;
	
	If Not IndicatorArray.Find("Products") = Undefined Then
		Query.Text = Query.Text +
		?(IsBlankString(Query.Text), "", Chars.LF + "UNION ALL" + Chars.LF)+
		"SELECT
		|	""Inventory"" AS Indicator,
		|	MIN(Inventory.Period) AS StartDate,
		|	MAX(Inventory.Period) AS EndDate
		|FROM
		|	AccumulationRegister.Inventory AS Inventory";
	EndIf;
	
	If Not IndicatorArray.Find("Funds") = Undefined Then
		Query.Text = Query.Text +
		?(IsBlankString(Query.Text), "", Chars.LF + "UNION ALL" + Chars.LF) +
		"SELECT
		|	""Funds"" AS Indicator,
		|	MIN(Funds.Period) AS StartDate,
		|	MAX(Funds.Period) AS EndDate
		|FROM
		|	AccumulationRegister.Funds AS Funds";
	EndIf;
	
	If Not IndicatorArray.Find("TaxInvoicesOrders") = Undefined Then
		Query.Text = Query.Text +
		?(IsBlankString(Query.Text), "", Chars.LF + "UNION ALL" + Chars.LF) +
		"SELECT
		|	""TaxInvoicesOrders"" AS Indicator,
		|	MIN(TaxInvoiceAndOrderPayment.Period) AS StartDate,
		|	MAX(TaxInvoiceAndOrderPayment.Period) AS EndDate
		|FROM
		|	AccumulationRegister.TaxInvoiceAndOrderPayment AS TaxInvoiceAndOrderPayment";
	EndIf;
	
	If Not IndicatorArray.Find("Purchases") = Undefined Then
		Query.Text = Query.Text +
		?(IsBlankString(Query.Text), "", Chars.LF + "UNION ALL" + Chars.LF) +
		"SELECT
		|	""Purchases"" AS Indicator,
		|	MIN(Purchases.Period) AS StartDate,
		|	MAX(Purchases.Period) AS EndDate
		|FROM
		|	AccumulationRegister.Purchases AS Purchases";
	EndIf;
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		Period				= New StandardPeriod;
		Period.StartDate	= ?(ValueIsFilled(Selection.StartDate), Selection.StartDate, '0001-01-01');
		Period.EndDate		= ?(ValueIsFilled(Selection.EndDate), Selection.EndDate, '0001-01-01');
		
		Result.Insert(Selection.Indicator, Period);
	EndDo; 
	
	Return Result;
	
EndFunction

#EndRegion 
 
#EndIf