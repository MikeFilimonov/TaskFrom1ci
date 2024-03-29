﻿#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Variables

Var RateCalculationErrorByFormula;

#EndRegion

#Region EventsHandlers

// Exchange rates of subordinate currencies are controlled when writing.
//
Procedure OnWrite(Cancel, Replacing)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If AdditionalProperties.Property("DisableDependentCurrenciesControl") Then
		Return;
	EndIf;
		
	AdditionalProperties.Insert("DependentCurrencies", New Map);
	
	If Count() > 0 Then
		UpdateSubordinatedExchangeRates();
	Else
		DeleteExchangeRatesSlaveExchange();
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// Finds all dependent currencies and changes their exchange rate.
//
Procedure UpdateSubordinatedExchangeRates()
	
	DependentCurrency = Undefined;
	AdditionalProperties.Property("UpdateDependentCurrencyRate", DependentCurrency);
	If DependentCurrency <> Undefined Then
		DependentCurrency = CommonUse.ObjectAttributesValues(DependentCurrency, 
			"Ref,Markup,SetRateMethod,RateCalculationFormula");
	EndIf;
	
	For Each RecordMainCurrency In ThisObject Do

		If DependentCurrency <> Undefined Then // You need to update the exchange rate of the specified currency only.
			UpdatedPeriods = Undefined;
			If Not AdditionalProperties.Property("UpdatedPeriods", UpdatedPeriods) Then
				UpdatedPeriods = New Map;
				AdditionalProperties.Insert("UpdatedPeriods", UpdatedPeriods);
			EndIf;
			// We do not re-update the exchange rate within the same period.
			If UpdatedPeriods[RecordMainCurrency.Period] = Undefined Then
				UpdateDependentCurrencyRate(DependentCurrency, RecordMainCurrency); 
				UpdatedPeriods.Insert(RecordMainCurrency.Period, True);
			EndIf;
		Else	// Update the exchange rate of all dependent currencies.
			DependentCurrencies = WorkWithExchangeRates.DependentCurrenciesList(RecordMainCurrency.Currency, AdditionalProperties);
			For Each DependentCurrency In DependentCurrencies Do
				UpdateDependentCurrencyRate(DependentCurrency, RecordMainCurrency); 
			EndDo;
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure UpdateDependentCurrencyRate(DependentCurrency, RecordMainCurrency)
	
	RecordSet = InformationRegisters.ExchangeRates.CreateRecordSet();
	RecordSet.Filter.Currency.Set(DependentCurrency.Ref, True);
	RecordSet.Filter.Period.Set(RecordMainCurrency.Period, True);
	
	WriteCoursesOfCurrency = RecordSet.Add();
	WriteCoursesOfCurrency.Currency = DependentCurrency.Ref;
	WriteCoursesOfCurrency.Period = RecordMainCurrency.Period;
	If DependentCurrency.SetRateMethod = Enums.ExchangeRateSetupMethod.MarkupOnExchangeRateOfOtherCurrencies Then
		WriteCoursesOfCurrency.ExchangeRate = RecordMainCurrency.ExchangeRate + RecordMainCurrency.ExchangeRate * DependentCurrency.Markup / 100;
		WriteCoursesOfCurrency.Multiplicity = RecordMainCurrency.Multiplicity;
	Else // by formula
		ExchangeRate = CurrencyRateAccordingToFormula(DependentCurrency.Ref, DependentCurrency.RateCalculationFormula, RecordMainCurrency.Period);
		If ExchangeRate <> Undefined Then
			WriteCoursesOfCurrency.ExchangeRate = ExchangeRate;
			WriteCoursesOfCurrency.Multiplicity = 1;
		EndIf;
	EndIf;
		
	RecordSet.AdditionalProperties.Insert("DisableDependentCurrenciesControl", True);
	
	If WriteCoursesOfCurrency.ExchangeRate > 0 Then
		RecordSet.Write();
	EndIf;
	
EndProcedure

// Clears the exchange rates of dependent currencies.
//
Procedure DeleteExchangeRatesSlaveExchange()
	
	CurrencyOwner = Filter.Currency.Value;
	Period = Filter.Period;
	
	DependentCurrency = Undefined;
	If AdditionalProperties.Property("UpdateDependentCurrencyRate", DependentCurrency) Then
		DeleteExchangeRates(DependentCurrency, Period);
	Else
		DependentCurrencies = WorkWithExchangeRates.DependentCurrenciesList(CurrencyOwner, AdditionalProperties);
		For Each DependentCurrency In DependentCurrencies Do
			DeleteExchangeRates(DependentCurrency.Ref, Period);
		EndDo;
	EndIf;
	
EndProcedure

Procedure DeleteExchangeRates(CurrencyRef, Period)
	RecordSet = InformationRegisters.ExchangeRates.CreateRecordSet();
	RecordSet.Filter.Currency.Set(CurrencyRef);
	RecordSet.Filter.Period.Set(Period);
	RecordSet.AdditionalProperties.Insert("DisableDependentCurrenciesControl", True);
	RecordSet.Write();
EndProcedure
	
Function CurrencyRateAccordingToFormula(Currency, Formula, Period)
	QueryText =
	"SELECT
	|	Currencies.Description AS SymbolicCode,
	|	ExchangeRatesSliceLast.ExchangeRate / ExchangeRatesSliceLast.Multiplicity AS ExchangeRate
	|FROM
	|	Catalog.Currencies AS Currencies
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&Period, ) AS ExchangeRatesSliceLast
	|		ON ExchangeRatesSliceLast.Currency = Currencies.Ref
	|WHERE
	|	Currencies.SetRateMethod <> VALUE(Enum.ExchangeRateSetupMethod.MarkupOnExchangeRateOfOtherCurrencies)
	|	AND Currencies.SetRateMethod <> VALUE(Enum.ExchangeRateSetupMethod.CalculationByFormula)";
	
	Query = New Query(QueryText);
	Query.SetParameter("Period", Period);
	Expression = StrReplace(Formula, ",", ".");
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		Expression = StrReplace(Expression, Selection.SymbolicCode, Format(Selection.ExchangeRate, "NDS=.; NG=0"));
	EndDo;
	
	Try
		Result = WorkInSafeMode.EvalInSafeMode(Expression);
	Except
		If RateCalculationErrorByFormula = Undefined Then
			RateCalculationErrorByFormula = New Map;
		EndIf;
		If RateCalculationErrorByFormula[Currency] = Undefined Then
			RateCalculationErrorByFormula.Insert(Currency, True);
			ErrorInfo = ErrorInfo();
			ErrorText = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Calculation of exchange rate ""%1"" using formula ""%2"" is not executed:'", CommonUseClientServer.MainLanguageCode()), Currency, Formula);
			CommonUseClientServer.MessageToUser(ErrorText + Chars.LF + BriefErrorDescription(ErrorInfo), Currency, "Object.RateCalculationFormula");
			If AdditionalProperties.Property("UpdateDependentCurrencyRate") Then
				Raise ErrorText + Chars.LF + BriefErrorDescription(ErrorInfo);
			Else
				WriteLogEvent(NStr("en = 'Currency.Exchange rates import'", CommonUseClientServer.MainLanguageCode()),
					EventLogLevel.Error, Currency.Metadata(), Currency, 
					ErrorText + Chars.LF + DetailErrorDescription(ErrorInfo));
			EndIf;
		EndIf;
		Result = Undefined;
	EndTry;
	
	Return Result;
EndFunction

#EndRegion

#EndIf