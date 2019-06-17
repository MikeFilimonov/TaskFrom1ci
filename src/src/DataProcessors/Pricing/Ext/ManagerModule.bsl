#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions

// Get and read the corresponding layout (text document)
//
Function QueryText_ProductsWithSetPrice(UseCharacteristics)
	
	Template = GetTemplate("QueryText_ProductsWithSetPrice");
	
	QueryText = Template.GetText();
	
	Return StrReplace(QueryText, "&CharacteristicCondition",
		?(UseCharacteristics, "TRUE", "Characteristic = VALUE(Catalog.ProductsCharacteristics.EmptyRef)"));
	
EndFunction

// Get and read the corresponding layout (text document)
//
Function QueryText_ProductsWithoutSetPrice(UseCharacteristics)
	
	Template = GetTemplate("QueryText_ProductsWithoutSetPrice");
	
	QueryText = Template.GetText();
	
	Return StrReplace(QueryText, "&CharacteristicCondition",
		?(UseCharacteristics, "TRUE", "Characteristic = VALUE(Catalog.ProductsCharacteristics.EmptyRef)"));
	
EndFunction

// Function returns the corresponding query text
//
Function QueryTextForAddingByPriceKind(PriceFilled, UseCharacteristics) Export
	
	Return ?(PriceFilled,
		QueryText_ProductsWithSetPrice(UseCharacteristics),
		QueryText_ProductsWithoutSetPrice(UseCharacteristics)
		);
	
EndFunction

#EndRegion

#EndIf