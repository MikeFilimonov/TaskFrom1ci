#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions

// Procedure fills out the tabular section with the list of currencies. Only the currencies with rate that does not
// depend on the other currencies' rate are included into the list.
// 
Procedure FillCurrencyList() Export
	
	CurrenciesList.Clear();
	
	ExportableCurrencies = WorkWithExchangeRates.GetImportCurrenciesArray();
	
	For Each CurrencyItem In ExportableCurrencies Do
		NewRow = CurrenciesList.Add();
		NewRow.CurrencyCode = CurrencyItem.Code;
		NewRow.Currency    = CurrencyItem;
	EndDo;
	
EndProcedure

#EndRegion

#EndIf
