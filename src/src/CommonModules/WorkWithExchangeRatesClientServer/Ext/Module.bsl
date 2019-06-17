////////////////////////////////////////////////////////////////////////////////
// Subsystem "Currencies"
// 
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Converts the Amount from Current currency to New currency according to the parameters of their exchange rates. 
//   You can use the function to get the exchange rates parameters.
//   WorkWithExchangeRates.GetCurrencyRate(Currency, ExchangeRateDate).
//
// Parameters:
//   Amount                - Number                - The amount to be converted.
//   CurrentRateParameters - Structure             - Exchange rate parameters of the source currency.
//       * Currency        - CatalogRef.Currencies - Ref of the source currency.
//       * ExchangeRate    - Number                - The exchange rate of the source currency.
//       * Multiplicity    - Number                - The exchange rate multiplier of the source currency.
//   NewRateParameters     - Structure             - Exchange rate parameters of the target currency.
//       * Currency        - CatalogRef.Currencies - Ref of the target currency.
//       * ExchangeRate    - Number                - The exchange rate of the target currency.
//       * Multiplicity    - Number                - The exchange rate multiplier of the target currency.
//
// Returns: 
//   Number - The amount converted according to new exchange rate.
//
Function RecalculateByRate(Amount, CurrentRateParameters, NewRateParameters) Export
	If CurrentRateParameters.Currency = NewRateParameters.Currency
		OR (CurrentRateParameters.ExchangeRate = NewRateParameters.ExchangeRate 
			AND CurrentRateParameters.Multiplicity = NewRateParameters.Multiplicity) Then
		
		Return Amount;
		
	EndIf;
	
	If CurrentRateParameters.ExchangeRate = 0
		OR CurrentRateParameters.Multiplicity = 0
		OR NewRateParameters.ExchangeRate = 0
		OR NewRateParameters.Multiplicity = 0 Then
		
		CommonUseClientServer.MessageToUser(
			StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'When converting into currency %1, sum %2 was set to null because the currency rate was not specified.'"), 
				NewRateParameters.Currency, 
				Format(Amount, "NFD=2; NZ=0")));
		
		Return 0;
		
	EndIf;
	
	Return Round((Amount * CurrentRateParameters.ExchangeRate * NewRateParameters.Multiplicity) / (NewRateParameters.ExchangeRate * CurrentRateParameters.Multiplicity), 2);
	
EndFunction

// Obsolete: You should use the ConvertByRate function.
//
// Calculates the amount of the CurrencyBeg currency at the rate of ByRateBeg in the CurrencyEnd currency at the rate of
// ByRateEnd.
//
// Parameters:
//   Amount          - Number                - the amount to be converted.
//   CurrencyBeg     - CatalogRef.Currencies - the source currency.
//   CurrencyEnd     - CatalogRef.Currencies - the target currency.
//   ByRateBeg       - Number                - the exchange rate of the source currency.
//   ByRateEnd       - Number                - the exchange rate of the target currency.
//   ByRepetitionBeg - Number                - the exchange rate multiplier of the source currency.
//                                             The default value is 1.
//   ByRepetitionEnd - Number                - the exchange rate multiplier of the target currency.
//                                             The default value is 1.
//
// Returns: 
//   Number - The amount converted to another currency.
//
Function RecalculateFromCurrencyToCurrency(Amount, CurrencyBeg, CurrencyEnd, ByRateBeg, ByRateEnd, 
	ByRepetitionBeg = 1, ByRepetitionEnd = 1) Export
	
	Return RecalculateByRate(
		Amount, 
		New Structure("Currency, ExchangeRate, Multiplicity", CurrencyBeg, ByRateBeg, ByRepetitionBeg),
		New Structure("Currency, ExchangeRate, Multiplicity", CurrencyEnd, ByRateEnd, ByRepetitionEnd));
	
EndFunction

#EndRegion
