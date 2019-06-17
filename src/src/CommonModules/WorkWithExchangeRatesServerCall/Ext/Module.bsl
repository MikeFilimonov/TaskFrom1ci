////////////////////////////////////////////////////////////////////////////////
// Subsystem "Currencies"
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProceduresAndFunctions

// Checks the exchange rates relevance of all the currencies.
//
Function ExchangeRatesAreRelevant() Export
	Return WorkWithExchangeRates.ExchangeRatesAreRelevant();
EndFunction

// Returns value of ExchangeRatesImportProcessor constant and fill check
// 
Function GetConstantExchangeRatesImportProcessor() Export
	Return WorkWithExchangeRates.GetConstantExchangeRatesImportProcessor();
EndFunction
	
#EndRegion
