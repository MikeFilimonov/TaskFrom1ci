////////////////////////////////////////////////////////////////////////////////////////////////////
// Contact information subsystem
// 
////////////////////////////////////////////////////////////////////////////////////////////////////

#Region InternalInterface

// Parses contact information presentation, returns XML string containing parsed field values
//
//  Parameters:
//      Text         - String - XML
//      ExpectedType - CatalogRef.ContactInformationTypes, EnumRef.ContactInformationTypes 
//                   - used for type control purposes
//
//  Returns:
//      String - XML
//
Function ContactInformationParsingXML(Val Text, Val ExpectedKind) Export
	Return ContactInformationInternal.ContactInformationParsingXML(Text, ExpectedKind);
EndFunction

//  Returns enum value of contact information kind type
//
//  Parameters:
//      InformationKind - CatalogRef.ContactInformationTypes, Structure - initial data
//
//  Returns:
//      EnumRef.ContactInformationTypes - value of Type field
//
Function ContactInformationKindType(Val InformationKind) Export
	Return ContactInformationManagement.ContactInformationKindType(InformationKind);
EndFunction

// Returns string containing contact information content value.
//
//  Parameters:
//      XMLData - String - contact information XML data
//
//  Returns:
//      String - content
//      Undefined - if content value is composite
//
Function ContactInformationContentString(Val XMLData) Export;
	Return ContactInformationXML.ContactInformationContentString(XMLData);
EndFunction

// Converts all incoming contact information formats to XML
//
Function TransformContactInformationXML(Val Data) Export
	Return ContactInformationXML.TransformContactInformationXML(Data);
EndFunction

// Returns the found country reference, or creates a new Country record and returns reference to it
//
Function CountriesByClassifier(Val CountryCode) Export
	Return Catalogs.Countries.RefByClassifier(
		New Structure("Code", CountryCode));
EndFunction

// Fills collection with references to the found or created Country records
//
Procedure CountryCollectionByClassifier(Collection) Export
	For Each KeyValue In Collection Do
		Collection[KeyValue.Key] = Catalogs.Countries.RefByClassifier(
			New Structure("Code", KeyValue.Value.Code));
	EndDo;
EndProcedure

#EndRegion