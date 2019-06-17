////////////////////////////////////////////////////////////////////////////////////////////////////
// Contact information subsystem
// 
////////////////////////////////////////////////////////////////////////////////////////////////////

#Region InternalInterface

//  Returns code of the additional address part for serialization 
//
//  Parameters:
//      ValueRow - String - search value (Building, Unit, etc)
//
// Returns:
//      Number - code
// 
Function AddressingObjectSerializationCode(ValueRow) Export
	KeyValue = Upper(TrimAll(ValueRow));
	For Each Item In AddressingObjectTypesNationalAddresses() Do
		If Item.Key = KeyValue Then
			Return Item.Code;
		EndIf;
	EndDo;
	
	Return Undefined;
EndFunction

//  Returns code of the additional address part for postal code
//
// Returns:
//      String - code
//
Function PostalCodeSerializationCode() Export
	Return AddressingObjectSerializationCode(NStr("en = 'Zip code'"));
EndFunction

//  Returns postal code XPath
//
// Returns:
//      String - XPath
//
Function PostalCodeXPath() Export
	Return "AdditionalAddressItem[AddressItemType='" + PostalCodeSerializationCode() + "']";
EndFunction

//  Returns county XPath
//
// Returns:
//      String - XPath
//
Function CountyXPath() Export
	Return "CountyMunicipalEntity/County";
EndFunction

//  Returns additional addressing object XPath
//
//  Parameters;
//      ValueRow - String - required type (Building, Unit, etc)
//
// Returns:
//      String - XPath
//
Function AdditionalAddressingObjectNumberXPath(ValueRow) Export
	Code = AddressingObjectSerializationCode(ValueRow);
	If Code = Undefined Then
		Code = StrReplace(ValueRow, "'", "");
	EndIf;
	Return "AdditionalAddressItem/Number[Type='" + Code + "']";
EndFunction

//  Returns string containing type description based on the address part code.
//  Opposite of AddressingObjectSerializationCode
//
// Parameters:
//      Code - String - code
//
// Returns:
//      Number - Type
//
Function ObjectTypeBySerializationCode(Code) Export
	For Each Item In AddressingObjectTypesNationalAddresses() Do
		If Item.Code = Code Then
			Return Item;
		EndIf;
	EndDo;
	
	Return Undefined;
EndFunction

// Returns namespace for contact information XDTO management
//
// Returns:
//      String - namespace
//
Function Namespace() Export
	Return "http://www.v8.1c.ru/ssl/contactinfo";
EndFunction

// Returns name of form used to edit contact information type
//
// Parameters:
//      InformationKind - EnumRef.ContactInformationTypes, CatalogRef.ContactInformationTypes 
//       - requested type
//
// Returns:
//      String - full form name
//
Function ContactInformationInputFormName(Val InformationKind) Export
	InformationType = ContactInformationInternalServerCall.ContactInformationKindType(InformationKind);
	
	AllTypes = "Enum.ContactInformationTypes.";
	If InformationType = PredefinedValue(AllTypes + "Address") Then
		Return "DataProcessor.ContactInformationInput.Form.AddressInput";
		
	ElsIf InformationType = PredefinedValue(AllTypes + "Phone") Then
		Return "DataProcessor.ContactInformationInput.Form.PhoneInput";
		
	ElsIf InformationType = PredefinedValue(AllTypes + "Fax") Then
		Return "DataProcessor.ContactInformationInput.Form.PhoneInput";
		
	EndIf;
	
	Return Undefined;
EndFunction

//  Returns array of structures containing address part information
//
// Returns:
//      Array - contains structures with descriptions
//
Function AddressingObjectTypesNationalAddresses() Export
	
	Result = New Array;
	
	// Code, Description, Type, Order 
	
	Result.Add(AddressingObjectString("1010", NStr("en = 'Building'"),  1, 1));
	Result.Add(AddressingObjectString("1050", NStr("en = 'Unit'"),      2, 1));;
	Result.Add(AddressingObjectString("2010", NStr("en = 'Apartment'"), 3, 1));
	Result.Add(AddressingObjectString("2030", NStr("en = 'Office'"),    3, 2));
	Result.Add(AddressingObjectString("2050", NStr("en = 'Room'"),      3, 5));

	//  Abbreviations required for backward compatibility during parsing
	Result.Add(AddressingObjectString("2010", NStr("en = 'app'"),       3, 6));
	Result.Add(AddressingObjectString("2030", NStr("en = 'off'"),       3, 7));
	
	// Additional information objects
	Result.Add(AddressingObjectString("10100000", NStr("en = 'Zip code'")));
	
	Return Result;
EndFunction

#EndRegion

#Region InternalProceduresAndFunctions

Function AddressingObjectString(Code, Description, Type = 0, Order = 0)
	Return New Structure("Code, Description, Type, Order, Abbr, Key",
		Code, Description, Type, Order, Lower(Description), Upper(Description));
EndFunction

#EndRegion
