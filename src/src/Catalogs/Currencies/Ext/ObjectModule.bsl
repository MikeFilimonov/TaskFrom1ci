#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If SetRateMethod = Enums.ExchangeRateSetupMethod.CalculationByFormula Then
		QueryText =
		"SELECT
		|	Currencies.Description AS SymbolicCode
		|FROM
		|	Catalog.Currencies AS Currencies
		|WHERE
		|	(Currencies.SetRateMethod = VALUE(Enum.ExchangeRateSetupMethod.MarkupOnExchangeRateOfOtherCurrencies)
		|			OR Currencies.SetRateMethod = VALUE(Enum.ExchangeRateSetupMethod.CalculationByFormula))";
		
		Query = New Query(QueryText);
		DependentCurrencies = Query.Execute().Unload().UnloadColumn("SymbolicCode");
		
		For Each Currency In DependentCurrencies Do
			If Find(RateCalculationFormula, Currency) > 0 Then
				Cancel = True;
			EndIf;
		EndDo;
	EndIf;
	
	If ValueIsFilled(MainCurrency.MainCurrency) Then
		Cancel = True;
	EndIf;
	
	If Cancel Then
		CommonUseClientServer.MessageToUser(
			NStr("en = 'Exchange rates can be linked to the rate of independent currency only.'"));
	EndIf;
	
	If SetRateMethod <> Enums.ExchangeRateSetupMethod.MarkupOnExchangeRateOfOtherCurrencies Then
		AttributesToExclude = New Array;
		AttributesToExclude.Add("MainCurrency");
		AttributesToExclude.Add("Markup");
		CommonUse.DeleteUnverifiableAttributesFromArray(CheckedAttributes, AttributesToExclude);
	EndIf;
	
	If SetRateMethod <> Enums.ExchangeRateSetupMethod.CalculationByFormula Then
		AttributesToExclude = New Array;
		AttributesToExclude.Add("RateCalculationFormula");
		CommonUse.DeleteUnverifiableAttributesFromArray(CheckedAttributes, AttributesToExclude);
	EndIf;
	
	If Not IsNew()
		AND SetRateMethod = Enums.ExchangeRateSetupMethod.MarkupOnExchangeRateOfOtherCurrencies
		AND WorkWithExchangeRates.DependentCurrenciesList(Ref).Count() > 0 Then
		CommonUseClientServer.MessageToUser(
			NStr("en = 'The currency cannot be subordinate as it is the main one for other currencies.'"));
		Cancel = True;
	EndIf;
	
EndProcedure

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	WorkWithExchangeRates.CheckRateOn01Correctness_01_1980(Ref);
	
	If AdditionalProperties.Property("UpdateRates") Then
		If CommonUseReUse.DataSeparationEnabled() Then
			WorkWithExchangeRates.OnUpdatingExchangeRatesSaaS(ThisObject);
		Else
			UpdateExchangeRate(ThisObject);
		EndIf;
	EndIf;
	
EndProcedure

Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If IsNew() Then
		AdditionalProperties.Insert("UpdateRates");
	Else
		PreviousValues = CommonUse.ObjectAttributesValues(Ref, "Code,SetRateMethod,MainCurrency,Markup,RateCalculationFormula");
		If (PreviousValues.SetRateMethod <> SetRateMethod)
			Or (SetRateMethod = Enums.ExchangeRateSetupMethod.ExportFromInternet 
				AND PreviousValues.Code <> Code)
			Or (SetRateMethod = Enums.ExchangeRateSetupMethod.MarkupOnExchangeRateOfOtherCurrencies
				AND (PreviousValues.MainCurrency <> MainCurrency Or PreviousValues.Markup <> Markup))
			Or (SetRateMethod = Enums.ExchangeRateSetupMethod.CalculationByFormula
				AND PreviousValues.RateCalculationFormula <> RateCalculationFormula) Then
			AdditionalProperties.Insert("UpdateRates");
		EndIf;
	EndIf;
	
	If SetRateMethod <> Enums.ExchangeRateSetupMethod.MarkupOnExchangeRateOfOtherCurrencies Then
		MainCurrency = Catalogs.Currencies.EmptyRef();
		Markup = 0;
	EndIf;
	
	If SetRateMethod <> Enums.ExchangeRateSetupMethod.CalculationByFormula Then
		RateCalculationFormula = "";
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

Procedure UpdateExchangeRate(SubordinateCurrency) 
	
	If SetRateMethod = Enums.ExchangeRateSetupMethod.MarkupOnExchangeRateOfOtherCurrencies Then
		
		Query = New Query;
		Query.Text = 
		"SELECT
		|	ExchangeRates.Period,
		|	ExchangeRates.Currency,
		|	ExchangeRates.ExchangeRate,
		|	ExchangeRates.Multiplicity
		|FROM
		|	InformationRegister.ExchangeRates AS ExchangeRates
		|WHERE
		|	ExchangeRates.Currency = &CurrencySource";
		Query.SetParameter("CurrencySource", SubordinateCurrency.MainCurrency);
		
		Selection = Query.Execute().Select();
		
		RecordSet = InformationRegisters.ExchangeRates.CreateRecordSet();
		RecordSet.Filter.Currency.Set(SubordinateCurrency.Ref);
		
		Markup = SubordinateCurrency.Markup;
		
		While Selection.Next() Do
			
			NewCurrencySetRecord = RecordSet.Add();
			NewCurrencySetRecord.Currency		= SubordinateCurrency.Ref;
			NewCurrencySetRecord.Multiplicity	= Selection.Multiplicity;
			NewCurrencySetRecord.ExchangeRate	= Selection.ExchangeRate + Selection.ExchangeRate * Markup / 100;
			NewCurrencySetRecord.Period			= Selection.Period;
			
		EndDo;
		
		RecordSet.AdditionalProperties.Insert("DisableDependentCurrenciesControl", True);
		RecordSet.Write();
		
	ElsIf SetRateMethod = Enums.ExchangeRateSetupMethod.CalculationByFormula Then
		
		// Receive the main currencies for the SubordinateCurrency.
		Query = New Query;
		Query.Text = 
		"SELECT
		|	Currencies.Ref AS Ref
		|FROM
		|	Catalog.Currencies AS Currencies
		|WHERE
		|	&RateCalculationFormula LIKE ""%"" + Currencies.Description + ""%""";
		
		Query.SetParameter("RateCalculationFormula", SubordinateCurrency.RateCalculationFormula);
		MainCurrencies = Query.Execute().Unload();
		
		If MainCurrencies.Count() = 0 Then
			ErrorText = NStr("en = 'At least one main currency is to be used in the formula.'");
			CommonUseClientServer.MessageToUser(ErrorText, , "Object.RateCalculationFormula");
			Raise ErrorText;
		EndIf;
		
		UpdatedPeriods = New Map; // Cache for single recalculation of exchange rate within the same period.
		// Rewrite the exchange rates of the main currencies to update the exchange rate of the SubordinateCurrency.
		For Each RecordMainCurrency In MainCurrencies Do
			RecordSet = InformationRegisters.ExchangeRates.CreateRecordSet();
			RecordSet.Filter.Currency.Set(RecordMainCurrency.Ref);
			RecordSet.Read();
			RecordSet.AdditionalProperties.Insert("UpdateDependentCurrencyRate",	SubordinateCurrency.Ref);
			RecordSet.AdditionalProperties.Insert("UpdatedPeriods",					UpdatedPeriods);
			RecordSet.Write();
		EndDo
		
	EndIf;
	
EndProcedure

#EndRegion

#EndIf
