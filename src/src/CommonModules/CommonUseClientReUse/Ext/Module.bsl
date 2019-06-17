////////////////////////////////////////////////////////////////////////////////
// The subsystem "Basic functionality".
// Client procedures and functions of the general purpose.
// 
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Returns True if it is a web client in Mac OS.
Function ThisIsMacOSWebClient() Export

//  TODO  we need to analyse it !
#If Not WebClient Then
	Return False;  // This code works only in web client.
#EndIf
	
	SystemInfo = New SystemInfo;
	If Find(SystemInfo.UserAgentInformation, "Macintosh") <> 0 Then
		Return True;
	EndIf;
	
	Return False;
	
EndFunction

// Returns the platform type of the client.
Function ClientPlatformType() Export
	SystemInfo = New SystemInfo;
	Return SystemInfo.PlatformType;
EndFunction

#EndRegion

#Region ServiceProceduresAndFunctions

// Function receives the style color by the name of style item.
//
// Parameters:
// StyleColorName - String -  Name of the style item.
//
// Returns:
// Color.
//
Function StyleColor(StyleColorName) Export
	
	Return CommonUseServerCall.StyleColor(StyleColorName);
	
EndFunction

// Function receives the style font by the name of style item.
//
// Parameters:
// StyleFontName - String - Name of the style font.
//
// Returns:
// Font.
//
Function StyleFont(StyleFontName) Export
	
	Return CommonUseServerCall.StyleFont(StyleFontName);
	
EndFunction

#EndRegion

#Region MessageTextsFrequentlyUse

// Method recalculate exchange rate text.
//
// Parameters:
// CurrencyRateInLetters	  - String -  Exchange rate for Document's date (ex."1 USD = 0,8315 EUR")
// RateNewCurrenciesInLetters - String -  Exchange rate for new date (ex."1 USD = 0,8432 EUR")
//
// Returns:
// RecalculateExchangeRateText - message text
//
Function RecalculateExchangeRateText(CurrencyRateInLetters, RateNewCurrenciesInLetters) Export
	
	Return StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en = 'Exchange rate of the transaction currency for this Document was set to %1.
		     |Do you wish to update exchange rate according to the new date? (%2)'"),
		CurrencyRateInLetters,
		RateNewCurrenciesInLetters);
		
EndFunction

#EndRegion
