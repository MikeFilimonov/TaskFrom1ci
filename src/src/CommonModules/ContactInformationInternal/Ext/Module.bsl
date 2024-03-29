﻿////////////////////////////////////////////////////////////////////////////////////////////////////
// Contact information subsystem
// 
////////////////////////////////////////////////////////////////////////////////////////////////////

#Region InternalInterface

//  Returns a structure wich the ChoiceData field containing the list
//  used for settlement autocompletion by superiority-based hierarchical presentation.
//
//  Parameters:
//      Text                  - String - autocompletion text. 
//      HideObsoleteAddresses - Boolean - flag specifying that obsolete addresses must be excluded
//                                        from the autocompletion list. 
//      WarnObsolete - Boolean - result structure flag. When True, the return value
//                               list contains structures with obsolete data warnings. 
//                               When False, it contains a normal value list.
// Returns:
//      Structure - data search result. Contains fields:
//         * TooMuchData - Boolean - flag specifying that the some of the data
//                                   is not included in the resulting list. 
//         * ChoiceData  - ValueList - autocompletion data.
//
Function SettlementAutoCompleteResults(Text, HideObsoleteAddresses = False, WarnObsolete = True) Export
	
	// Address classifier is not available
	Return New Structure("TooMuchData, ChoiceData", False, New ValueList);
	
EndFunction

//  Returns a structure wich the ChoiceData field containing the
//  list used for street autocompletion by superiority-based hierarchical presentation.
//
//  Parameters:
//      SettlementCode        - Number  - classifier code used to limit the autocompletion.
//      Text                  - String - autocompletion text. 
//      HideObsoleteAddresses - Boolean - flag specifying that obsolete addresses must be excluded
//                                        from the autocompletion list. 
//      WarnObsolete - Boolean - result structure flag. When True, the returned value
//                               list contains structures with obsolete data warnings. 
//                               When False, it contains a normal value list.
//
// Returns:
//      Structure - data search result. Contains fields:
//         * TooMuchData - Boolean   - flag specifying that the some
//                                     of the data is not included in the resulting list. 
//         * ChoiceData  - ValueList - autocompletion data.
//
Function StreetAutoCompleteResults(SettlementCode, Text, HideObsoleteAddresses = False, WarnObsolete = True) Export
	
	// Address classifier is not available
	Return New Structure("TooMuchData, ChoiceData", False, New ValueList);
	
EndFunction

// Returns a structure wich the ChoiceData field containing the
// list of settlement options by superiority-based hierarchical presentation.
//
//  Parameters:
//      Text                  - String - autocompletion text. 
//      HideObsoleteAddresses - Boolean - flag specifying that obsolete addresses must be excluded
//                                        from the autocompletion list. 
//      NumberOfRowsToSelect  - Number  - result number limit.
//      StreetClarification   - String - street clarification presentation.
//
// Returns:
//      Structure - data search result. Contains the following fields:
//         * TooMuchData - Boolean - flag specifying that the some of the data is not included in the resulting list. 
//         * ChoiceData  - ValueList - autocompletion data.
//
Function SettlementsByPresentation(Val Text, Val HideObsoleteAddresses = False, Val NumberOfRowsToSelect = 50, Val StreetClarification = "") Export
	
	// Address classifier is not available
	Return New Structure("TooMuchData, ChoiceData", False, New ValueList);
	
EndFunction

// Returns a structure wich the ChoiceData field containing the
// list of settlement options by superiority-based hierarchical presentation.
//
//  Parameters:
//      SettlementCode        - Number  - classifier code used to limit the autocompletion. 
//      Text                  - Text    - autocompletion string. 
//      HideObsoleteAddresses - Boolean - flag specifying that obsolete addresses must be excluded from the
//                                        autocompletion list.
//      NumberOfRowsToSelect  - Number  - result number limit.
//
// Returns:
//      Structure - data search result. Contains fields:
//         * TooMuchData - Boolean - flag specifying that the some of the data is not included in the resulting list. 
//         * ChoiceData  - ValueList - autocompletion data.
//
Function StreetsByPresentation(SettlementCode, Text, HideObsoleteAddresses = False, NumberOfRowsToSelect = 50) Export
	
	// Address classifier is not available
	Return New Structure("TooMuchData, ChoiceData", False, New ValueList);
	
EndFunction
	
//  Returns state name by its code.
//
//  Parameters:
//      Code - String, Number - state code.
//
// Returns:
//      String - full name of the state, including abbreviation. 
//      Undefined - if no address classifier subsystems are available.
// 
Function CodeState(Val Code) Export
	
	// Address classifier is not available
	Return Undefined;
	
EndFunction

#Region CommonInternal
//

// Transforms XDTO contact information to XML string.
//
//  Parameters:
//      XDTOInformationObject - XDTODataObject - contact information.
//
// Returns:
//      String - conversion result.
//
Function ContactInformationSerialization(XDTOInformationObject) Export
	Write = New XMLWriter;
	Write.SetString(New XMLWriterSettings(, , False, False, ""));
	
	If XDTOInformationObject <> Undefined Then
		XDTOFactory.WriteXML(Write, XDTOInformationObject);
	EndIf;
	
	Return StrReplace(Write.Close(), Chars.LF, "&#10;");
EndFunction

// Transforms an XML string to XDTO contact information object.
//
//  Parameters:
//      Text          - String - XML string. 
//      ExpectedKind  - CatalogRef.ContactInformationTypes, EnumRef.ContactInformationTypes, Structure. 
//      ReadResults   - Structure - target for additional fields:
//                          * ErrorText - String - description of read procedure errors. Value returned by the
//                             function is of valid type but unfilled.
//
Function ContactInformationDeserialization(Val Text, Val ExpectedKind = Undefined, ReadResults = Undefined) Export
	
	ExpectedType = ContactInformationManagement.ContactInformationKindType(ExpectedKind);
	
	EnumAddress      = Enums.ContactInformationTypes.Address;
	EnumEmailAddress = Enums.ContactInformationTypes.EmailAddress;
	EnumWebpage      = Enums.ContactInformationTypes.WebPage;
	EnumPhone        = Enums.ContactInformationTypes.Phone;
	EnumFax          = Enums.ContactInformationTypes.Fax;
	EnumOther        = Enums.ContactInformationTypes.Other;
	EnumSkype        = Enums.ContactInformationTypes.Skype;
	
	Namespace = ContactInformationClientServerCached.Namespace();
	If ContactInformationClientServer.IsXMLContactInformation(Text) Then
		XMLReader = New XMLReader;
		XMLReader.SetString(Text);
		
		ErrorText = Undefined;
		Try
			Result = XDTOFactory.ReadXML(XMLReader, XDTOFactory.Type(Namespace, "ContactInformation"));
		Except
			// Invalid XML format
			WriteLogEvent(ContactInformationManagementService.EventLogMessageText(),
				EventLogLevel.Error, , Text, DetailErrorDescription(ErrorInfo())
			);
			
			If TypeOf(ExpectedKind) = Type("CatalogRef.ContactInformationTypes") Then
				ErrorText = StrReplace(NStr("en = 'Incorrect XML format of contact information for ""%1"". Field values were cleared.'"),
					"%1", String(ExpectedKind));
			Else
				ErrorText = NStr("en = 'Incorrect XML format of contact information. Field values were cleared.'");
			EndIf;
		EndTry;
		
		If ErrorText = Undefined Then
			// Checking for type match
			TypeFound = ?(Result.Content = Undefined, Undefined, Result.Content.Type());
			If ExpectedType = EnumAddress AND TypeFound <> XDTOFactory.Type(Namespace, "Address") Then
				ErrorText = NStr("en = 'An error occurred when deserializing the contact information, address is expected'");
			ElsIf ExpectedType = EnumEmailAddress AND TypeFound <> XDTOFactory.Type(Namespace, "Email") Then
				ErrorText = NStr("en = 'An error occurred when deserializing the contact information, email address is expected'");
			ElsIf ExpectedType = EnumWebpage AND TypeFound <> XDTOFactory.Type(Namespace, "Website") Then
				ErrorText = NStr("en = 'An error occurred when deserializing the contact information, web page is expected'");
			ElsIf ExpectedType = EnumPhone AND TypeFound <> XDTOFactory.Type(Namespace, "PhoneNumber") Then
				ErrorText = NStr("en = 'An error occurred when deserializing the contact information, phone number is expected'");
			ElsIf ExpectedType = EnumFax AND TypeFound <> XDTOFactory.Type(Namespace, "FaxNumber") Then
				ErrorText = NStr("en = 'An error occurred when deserializing the contact information, phone number is expected'");
			ElsIf ExpectedType = EnumOther AND TypeFound <> XDTOFactory.Type(Namespace, "Others") Then
				ErrorText = NStr("en = 'Contact information deserialization error. Other data is expected.'");
			ElsIf ExpectedType = EnumSkype AND TypeFound <> XDTOFactory.Type(Namespace, "Skype") Then
				ErrorText = NStr("en = 'Contact information deserialization error. Skype is expected.'");
			EndIf;
		EndIf;
		
		If ErrorText = Undefined Then
			// Reading was successful
			Return Result;
		EndIf;
		
		// Checking for errors, returning detailed information
		If ReadResults = Undefined Then
			Raise ErrorText;
		ElsIf TypeOf(ReadResults) <> Type("Structure") Then
			ReadResults = New Structure;
		EndIf;
		ReadResults.Insert("ErrorText", ErrorText);
		
		// Returning an empty object
		Text = "";
	EndIf;
	
	If TypeOf(Text) = Type("ValueList") Then
		Presentation = "";
		IsNew = Text.Count() = 0;
	Else
		Presentation = String(Text);
		IsNew = IsBlankString(Text);
	EndIf;
	
	Result = XDTOFactory.Create(XDTOFactory.Type(Namespace, "ContactInformation"));
	
	// Parsing
	If ExpectedType = EnumAddress Then
		If IsNew Then
			Result.Content = XDTOFactory.Create(XDTOFactory.Type(Namespace, "Address"));
		Else
			Result = AddressDeserialization(Text, Presentation, ExpectedType);
		EndIf;
		
	ElsIf ExpectedType = EnumPhone Then
		If IsNew Then
			Result.Content = XDTOFactory.Create(XDTOFactory.Type(Namespace, "PhoneNumber"));
		Else
			Result = PhoneDeserialization(Text, Presentation, ExpectedType)
		EndIf;
		
	ElsIf ExpectedType = EnumFax Then
		If IsNew Then
			Result.Content = XDTOFactory.Create(XDTOFactory.Type(Namespace, "FaxNumber"));
		Else
			Result = FaxDeserialization(Text, Presentation, ExpectedType)
		EndIf;
		
	ElsIf ExpectedType = EnumEmailAddress Then
		If IsNew Then
			Result.Content = XDTOFactory.Create(XDTOFactory.Type(Namespace, "Email"));
		Else
			Result = OtherContactInformationDeserialization(Text, Presentation, ExpectedType)
		EndIf;
		
	ElsIf ExpectedType = EnumWebpage Then
		If IsNew Then
			Result.Content = XDTOFactory.Create(XDTOFactory.Type(Namespace, "Website"));
		Else
			Result = OtherContactInformationDeserialization(Text, Presentation, ExpectedType)
		EndIf;
		
	ElsIf ExpectedType = EnumOther Then
		If IsNew Then
			Result.Content = XDTOFactory.Create(XDTOFactory.Type(Namespace, "Others"));
		Else
			Result = OtherContactInformationDeserialization(Text, Presentation, ExpectedType)    
		EndIf;
		
	ElsIf ExpectedType = EnumSkype Then
		If IsNew Then
			Result.Content = XDTOFactory.Create(XDTOFactory.Type(Namespace, "Skype"));
		Else
			Result = OtherContactInformationDeserialization(Text, Presentation, ExpectedType)    
		EndIf;
		
	Else
		Raise NStr("en = 'An error occurred while deserializing contact information, the expected type is not specified'");
	EndIf;
	
	Return Result;
EndFunction

// Parses a contact information presentation and returns an XDTO object.
//
//  Parameters:
//      Text         - String - XML string. 
//      ExpectedKind - CatalogRef.ContactInformationTypes, EnumRef.ContactInformationTypes, Structure.
//
// Returns:
//      XDTODataObject - contact information.
//
Function ContactInformationParsing(Text, ExpectedKind) Export
	
	ExpectedType = ContactInformationManagement.ContactInformationKindType(ExpectedKind);
	
	If ExpectedType = Enums.ContactInformationTypes.Address Then
		Return AddressDeserialization("", Text, ExpectedType);
		
	ElsIf ExpectedType = Enums.ContactInformationTypes.EmailAddress Then
		Return OtherContactInformationDeserialization("", Text, ExpectedType);
		
	ElsIf ExpectedType = Enums.ContactInformationTypes.WebPage Then
		Return OtherContactInformationDeserialization("", Text, ExpectedType);
		
	ElsIf ExpectedType = Enums.ContactInformationTypes.Phone Then
		Return PhoneDeserialization("", Text, ExpectedType);
		
	ElsIf ExpectedType = Enums.ContactInformationTypes.Fax Then
		Return FaxDeserialization("", Text, ExpectedType);
		
	ElsIf ExpectedType = Enums.ContactInformationTypes.Skype Then
		Return OtherContactInformationDeserialization("", Text, ExpectedType);
		
	ElsIf ExpectedType = Enums.ContactInformationTypes.Other Then
		Return OtherContactInformationDeserialization("", Text, ExpectedType);
		
	EndIf;
	
	Return Undefined;
EndFunction

// Parses a contact information presentation and returns an XML string.
//
//  Parameters:
//      Text         - String - XML string. 
//      ExpectedKind - CatalogRef.ContactInformationTypes, EnumRef.ContactInformationTypes, Structure.
//
// Returns:
//      String - contact information in XML format.
//
Function ContactInformationParsingXML(Text, ExpectedKind) Export
	Return ContactInformationSerialization(
		ContactInformationParsing(Text, ExpectedKind));
EndFunction

// Transforms a string to an XDTO contact information address object.
//
//  Parameters:
//      FieldValues  - String - serialized information, field values. 
//      Presentation - String - superiority-based presentation. 
//                      Used for parsing purposes if FieldValues is empty. 
//      ExpectedType - EnumRef.ContactInformationTypes - optional type used for control purposes.
//
//  Returns:
//      XDTODataObject  - contact information.
//
Function AddressDeserialization(Val FieldValues, Val Presentation = "", Val ExpectedType = Undefined) Export
	ValueType = TypeOf(FieldValues);
	
	ParseByFields = ValueType = Type("ValueList") Or ValueType = Type("Structure") 
	                   Or ( ValueType = Type("String") AND Not IsBlankString(FieldValues) );
	
	If ParseByFields Then
		// Parsing the field values
		Return AddressDeserializationCommon(FieldValues, Presentation, ExpectedType);
	EndIf;
	
	// Address classifier is not available
	
	// Empty object with presentation
	Namespace = ContactInformationClientServerCached.Namespace();
	Result = XDTOFactory.Create(XDTOFactory.Type(Namespace, "ContactInformation"));
	Result.Content = XDTOFactory.Create(XDTOFactory.Type(Namespace, "Address"));
	Result.Presentation = Presentation;
	
	Return Result;
EndFunction

// Transforms a string to an XDTO phone number contact information.
//
//      FieldValues  - String - serialized information, field values. 
//      Presentation - String - superiority-based presentation. 
//                      Used for parsing purposes if FieldValues is empty. 
//      ExpectedType - EnumRef.ContactInformationTypes - optional type used for control purposes.
//
//  Returns:
//      XDTODataObject  - contact information.
//
Function PhoneDeserialization(FieldValues, Presentation = "", ExpectedType = Undefined) Export
	Return PhoneFaxDeserialization(FieldValues, Presentation, ExpectedType);
EndFunction

// Transforms a string to an XDTO fax number contact information.
//
//      FieldValues  - String - serialized information, field values. 
//      Presentation - String - superiority-based presentation. 
//                      Used for parsing purposes if FieldValues is empty.
//      ExpectedType - EnumRef.ContactInformationTypes - optional type used for control purposes.
//
//  Returns:
//      XDTODataObject  - contact information.
//
Function FaxDeserialization(FieldValues, Presentation = "", ExpectedType = Undefined) Export
	Return PhoneFaxDeserialization(FieldValues, Presentation, ExpectedType);
EndFunction

// Transforms a string to other XDTO contact information.
//
//      FieldValues  - String - serialized information, field values. 
//      Presentation - String - superiority-based presentation. 
//                      Used for parsing purposes if FieldValues is empty. 
//      ExpectedType - EnumRef.ContactInformationTypes - optional type used for control purposes.
//
//  Returns:
//      XDTODataObject  - contact information.
//
Function OtherContactInformationDeserialization(FieldValues, Presentation = "", ExpectedType = Undefined) Export
	
	If ContactInformationClientServer.IsXMLContactInformation(FieldValues) Then
		// Common format of contact information
		Return ContactInformationDeserialization(FieldValues, ExpectedType);
	EndIf;
	
	Namespace = ContactInformationClientServerCached.Namespace();
	Result = XDTOFactory.Create(XDTOFactory.Type(Namespace, "ContactInformation"));
	Result.Presentation = Presentation;
	
	If ExpectedType = Enums.ContactInformationTypes.EmailAddress Then
		Result.Content = XDTOFactory.Create(XDTOFactory.Type(Namespace, "Email"));
		
	ElsIf ExpectedType = Enums.ContactInformationTypes.WebPage Then
		Result.Content = XDTOFactory.Create(XDTOFactory.Type(Namespace, "Website"));
		
	ElsIf ExpectedType = Enums.ContactInformationTypes.Skype Then
		Result.Content = XDTOFactory.Create(XDTOFactory.Type(Namespace, "Skype"));
		
	ElsIf ExpectedType = Enums.ContactInformationTypes.Other Then
		Result.Content = XDTOFactory.Create(XDTOFactory.Type(Namespace, "Others"));
		
	ElsIf ExpectedType <> Undefined Then
		Raise NStr("en = 'An error occurred when deserializing the contact information, another type is expected'");
		
	EndIf;
	
	Result.Content.Value = Presentation;
	
	Return Result;
	
EndFunction

//  Reads and sets the contact information presentation. The object may vary.
//
//  Parameters:
//      XDTOInformation - XDTODataObject, String - contact information. 
//      NewValue        - String - new presentation to be set in XDTOInformation (optional).
//
//  Returns:
//      String - new value.
Function ContactInformationPresentation(XDTOInformation, NewValue = Undefined) Export
	SerializationRequired = TypeOf(XDTOInformation) = Type("String");
	If SerializationRequired AND Not ContactInformationClientServer.IsXMLContactInformation(XDTOInformation) Then
		// Old version of field values. Returning the string.
		Return XDTOInformation;
	EndIf;
	
	XDTODataObject = ?(SerializationRequired, ContactInformationDeserialization(XDTOInformation), XDTOInformation);
	If NewValue <> Undefined Then
		XDTODataObject.Presentation = NewValue;
		If SerializationRequired Then
			XDTOInformation = ContactInformationSerialization(XDTODataObject);
		EndIf;
	EndIf;
	
	Return XDTODataObject.Presentation
EndFunction

//  Determines and sets the flag specifying whether the address is entered in free format. 
//  Non-empty value of Address_to_document field is used as the flag value.
//
//  Parameters:
//      XDTOInformation - XDTODataObject, String - Contact information. 
//      NewValue        - Boolean - new value to be set (optional).
//
//  Returns:
//      Boolean - new value.
//
Function AddressEnteredInFreeFormat(XDTOInformation, NewValue = Undefined) Export
	SerializationRequired = TypeOf(XDTOInformation) = Type("String");
	If SerializationRequired AND Not ContactInformationClientServer.IsXMLContactInformation(XDTOInformation) Then
		// Old version of field values. Not supported.
		Return False;
	EndIf;
	
	XDTODataObject = ?(SerializationRequired, ContactInformationDeserialization(XDTOInformation), XDTOInformation);
	If Not IsDomesticAddress(XDTODataObject) Then
		// Not supported
		Return False;
	EndIf;
	
	AddressUS = XDTODataObject.Content.Content;
	If TypeOf(NewValue) <> Type("Boolean") Then
		// Reading
		Return Not IsBlankString(AddressUS.Address_by_document);
	EndIf;
		
	// Setting values
	If NewValue Then
		AddressUS.Address_to_document = XDTODataObject.Presentation;
	Else
		AddressUS.Unset("Address_by_document");
	EndIf;
	
	If SerializationRequired Then
		XDTOInformation = ContactInformationSerialization(XDTODataObject);
	EndIf;
	Return NewValue;
EndFunction

//  Reads and sets the contact information comment.
//
//  Parameters:
//      XDTOInformation - XDTODataObject, String - contact information. 
//      NewValue  - String - new comment to be set in XDTOInformation (optional).
//
//  Returns:
//      String - new value.
//
Function ContactInformationComment(XDTOInformation, NewValue = Undefined) Export
	SerializationRequired = TypeOf(XDTOInformation) = Type("String");
	If SerializationRequired AND Not ContactInformationClientServer.IsXMLContactInformation(XDTOInformation) Then
		// Old version of field values. The comment is not supported.
		Return "";
	EndIf;
	
	XDTODataObject = ?(SerializationRequired, ContactInformationDeserialization(XDTOInformation), XDTOInformation);
	If NewValue <> Undefined Then
		XDTODataObject.Comment = NewValue;
		If SerializationRequired Then
			XDTOInformation = ContactInformationSerialization(XDTODataObject);
		EndIf;
	EndIf;
	
	Return XDTODataObject.Comment;
EndFunction

//  Generates and returns a contact information presentation.
//
//  Parameters:
//      Information     - XDTODataObject, String - contact information. 
//      InformationKind - CatalogRef.ContactInformationTypes, Structure - presentation generation parameters.
//
//  Returns:
//      String - generated presentation.
//
Function GenerateContactInformationPresentation(Information, InformationKind) Export
	
	If TypeOf(Information) = Type("XDTODataObject") Then
		If Information.Content = Undefined Then
			// Using available information "as is"
			Return Information.Presentation;
		EndIf;
		
		Namespace = ContactInformationClientServerCached.Namespace();
		InformationType    = Information.Content.Type();
		If InformationType = XDTOFactory.Type(Namespace, "Address") Then
			Return AddressPresentation(Information.Content, InformationKind);
			
		ElsIf InformationType = XDTOFactory.Type(Namespace, "PhoneNumber") Then
			Return PhonePresentation(Information.Content, InformationKind);
			
		ElsIf InformationType = XDTOFactory.Type(Namespace, "FaxNumber") Then
			Return PhonePresentation(Information.Content, InformationKind);
			
		EndIf;
		
		// Placeholder for other types
		If TypeOf(InformationType) = Type("XDTODataObject") AND InformationType.Properties.Get("Value") <> Undefined Then
			Return String(Information.Content.Value);
		EndIf;
		
		Return String(Information.Content);
	EndIf;
	
	// Old format, or new deserialized format
	If InformationKind.Type = Enums.ContactInformationTypes.Address Then
		NewInfo = AddressDeserialization(Information,,Enums.ContactInformationTypes.Address);
		Return GenerateContactInformationPresentation(NewInfo, InformationKind);
	EndIf;
	
	Return TrimAll(Information);
EndFunction

//  Returns the flag specifying whether the passed address is domestic.
//
//  Parameters:
//      XDTOAddress - XDTODataObject - contact information or address XDTO object.
//
//  Returns:
//      Boolean - check result.
//
Function IsDomesticAddress(XDTOAddress) Export
	Return HomeCountryAddress(XDTOAddress) <> Undefined;
EndFunction

//  Returns an extracted XDTO object for domestic addresses, or Undefined for foreign addresses.
//
//  Parameters:
//      InformationObject - XDTODataObject - contact information or address XDTO object.
//
//  Returns:
//      XDTODataObject - domestic address.
//      Undefined - foreign address
//
Function HomeCountryAddress(InformationObject) Export
	Result = Undefined;
	XDTOType   = Type("XDTODataObject");
	
	If TypeOf(InformationObject) = XDTOType Then
		Namespace = ContactInformationClientServerCached.Namespace();
		
		If InformationObject.Type() = XDTOFactory.Type(Namespace, "ContactInformation") Then
			Address = InformationObject.Content;
		Else
			Address = InformationObject;
		EndIf;
		
		If TypeOf(Address) = XDTOType AND Address.Type() = XDTOFactory.Type(Namespace, "Address") Then
			Address = Address.Content;
		EndIf;
		
		If TypeOf(Address) = XDTOType AND Address.Type() = XDTOFactory.Type(Namespace, "AddressUS") Then
			Result = Address;
		EndIf;
	EndIf;
	
	Return Result;
EndFunction

//  Reads and sets the address postal code.
//
//  Parameters:
//      XDTOAddress - XDTODataObject - contact information or address XDTO object. 
//      NewValue    - String - value to be set.
//
//  Returns:
//      String - postal code.
//
Function AddressPostalCode(XDTOAddress, NewValue = Undefined) Export
	
	If XDTOAddress.Type().Name = "Address" AND XDTOAddress.AddressLine1	<> Undefined AND XDTOAddress.AddressLine2 <> Undefined Then
		Return XDTOAddress.PostalCode;
	EndIf;	
	
	AddressUS = HomeCountryAddress(XDTOAddress);
	If AddressUS = Undefined Then
		Return Undefined;
	EndIf;
	
	If NewValue = Undefined Then
		// Reading
		Result = AddressUS.Get( ContactInformationClientServerCached.PostalCodeXPath() );
		If Result <> Undefined Then
			Result = Result.Value;
		EndIf;
		Return Result;
	EndIf;
	
	// Writing
	PostalCodeCode = ContactInformationClientServerCached.PostalCodeSerializationCode();
	
	PostalCodeRecord = AddressUS.Get( ContactInformationClientServerCached.PostalCodeXPath() );
	If PostalCodeRecord = Undefined Then
		PostalCodeRecord = AddressUS.AdditionalAddressItem.Add( XDTOFactory.Create(XDTOAddress.AdditionalAddressItem.OwningProperty.Type) );
		PostalCodeRecord.AddressItemType = PostalCodeCode;
	EndIf;
	
	PostalCodeRecord.Value = NewValue;
	Return NewValue;
EndFunction

Function AddressAddressLine1(XDTOAddress) Export
	Return XDTOAddress.AddressLine1;
EndFunction

Function AddressAddressLine2(XDTOAddress) Export
	Return XDTOAddress.AddressLine2;
EndFunction

Function AddressCity(XDTOAddress) Export
	Return XDTOAddress.City;
EndFunction

Function AddressState(XDTOAddress) Export
	Return XDTOAddress.State;
EndFunction

//  Reads and sets the address county.
//
//  Parameters:
//      XDTOAddress - XDTODataObject - Contact information or address XDTO object. 
//      NewValue    - String - value to be set.
//
//  Returns:
//      String - new value.
//
Function AddressCounty(XDTOAddress, NewValue = Undefined) Export
	
	If NewValue = Undefined Then
		// Reading
		Result = Undefined;
		Namespace = ContactInformationClientServerCached.Namespace();
		
		XDTOType = XDTOAddress.Type();
		If XDTOType = XDTOFactory.Type(Namespace, "AddressUS") Then
			AddressUS = XDTOAddress;
		Else
			AddressUS = XDTOAddress.Content;
		EndIf;
		
		If TypeOf(AddressUS) = Type("XDTODataObject") Then
			Return PropertyByXPathValue(AddressUS, ContactInformationClientServerCached.CountyXPath() );
		EndIf;
		
		Return Undefined;
	EndIf;
	
	// Writing
	Write = CountyMunicipalEntity(XDTOAddress);
	Write.County = NewValue;
	Return NewValue;
EndFunction

//  Reads and sets address unit numbers.
//
//  Parameters:
//      XDTOAddress     - XDTODataObject - Contact information or address XDTO object. 
//      NewValue - Structure  - value to be set. The following fields are expected:
//                          * Units - ValueTable with the following columns:
//                                ** Type  - String - internal classifier type for additional address objects. 
//                                   Example: Unit.
//                                ** Value - String  - building number, apartment number, and so on.
//
//  Returns:
//      Structure - current data. Contains fields:
//          * Units - ValueTable with the following columns:
//                        ** Type         - String - internal classifier type for additional address objects. 
//                                          Example: Unit. 
//                        ** Abbreviation - String - abbreviated name to be used in presentations.
//                        ** Value        - String - building number, apartment number, and so on.
//                        ** XPath        - String - path to object value.
//
Function BuildingAddresses(XDTOAddress, NewValue = Undefined) Export
	
	Result = New Structure("Buildings", 
		ValueTable("Type, Value, Abbr, XPath, Kind", "Type, Kind"));
	
	AddressUS = HomeCountryAddress(XDTOAddress);
	If AddressUS = Undefined Then
		Return Result;
	EndIf;
	
	If NewValue <> Undefined Then
		// Writing
		If NewValue.Property("Buildings") Then
			For Each Row In NewValue.Buildings Do
				InsertUnit(XDTOAddress, Row.Type, Row.Value);
			EndDo;
		EndIf;
		Return NewValue
	EndIf;
	
	// Reading
	For Each AdditionalItem In AddressUS.AdditionalAddressItem Do
		If AdditionalItem.Number <> Undefined Then
			ObjectCode = AdditionalItem.Number.Type;
			ObjectType = ContactInformationClientServerCached.ObjectTypeBySerializationCode(ObjectCode);
			If ObjectType <> Undefined Then
				Kind = ObjectType.Type;
				If Kind = 1 Or Kind = 2 Then
					NewRow = Result.Buildings.Add();
				Else
					NewRow = Undefined;
				EndIf;
				If NewRow <> Undefined Then
					NewRow.Type        = ObjectType.Description;
					NewRow.Value   = AdditionalItem.Number.Value;
					NewRow.Abbr = ObjectType.Abbr;
					NewRow.XPath  = ContactInformationClientServerCached.AdditionalAddressingObjectNumberXPath(NewRow.Type);
					NewRow.Kind        = Kind;
				EndIf;
			EndIf;
		EndIf;
	EndDo;
	
	Result.Buildings.Sort("Kind");
	
	Return Result;
EndFunction

//  Returns the superiority-based presentation for a settlement.
//
//  Parameters:
//      AddressObj - XDTODataObject - domestic address.
//
//  Returns:
//      String - presentation.
//
Function SettlementPresentation(AddressObj) Export
	
	AddressUS = HomeCountryAddress(AddressObj);
	If AddressUS = Undefined Then
		Return "";
	EndIf;
	
	If AddressUS.CountyMunicipalEntity = Undefined Then
		County = "";
	ElsIf AddressUS.CountyMunicipalEntity.County <> Undefined Then
		County = AddressUS.CountyMunicipalEntity.County;
	ElsIf AddressUS.CountyMunicipalEntity.MunicipalEntity <> Undefined Then
		County = ContactInformationClientServer.FullDescr(
			AddressUS.CountyMunicipalEntity.MunicipalEntity.MunicipalEntity2, "",
			AddressUS.CountyMunicipalEntity.MunicipalEntity.MunicipalEntity1, "");
	Else
		County = "";;
	EndIf;
	
	Return ContactInformationClientServer.FullDescr(
		AddressUS.Settlement, "",
		AddressUS.City,  "",
		County, "",
		AddressUS.Region, "");
	
EndFunction

//  Returns the address presentation.
//
//  Parameters:
//      AddressObj - XDTODataObject - address.
//      InformationKind - CatalogRef.ContactInformationTypes, Structure - description used to generate the presentation.
//
//  Returns:
//      String - presentation.
//
Function AddressPresentation(XDTOAddress, InformationKind) Export
	
	FormationParameters = New Structure("IncludeCountryInPresentation", False);
	FillPropertyValues(FormationParameters, InformationKind);
	
	If XDTOAddress.AddressLine1 <> Undefined AND  XDTOAddress.AddressLine2 <> Undefined Then // Data is passed from the first address input form.
		Return ContactInformationClientServer.FullDescr(TrimAll(XDTOAddress.AddressLine1), "", TrimAll(XDTOAddress.AddressLine2), "", TrimAll(XDTOAddress.City), "",
			TrimAll(XDTOAddress.State), "", TrimAll(XDTOAddress.PostalCode), "", ?(FormationParameters.IncludeCountryInPresentation, TrimAll(XDTOAddress.Country), ""));
	EndIf;
	
	// 1) Country, if necessary.
	// 2) Postal code, state, county, city, settlement, street
	// 3) Building, unit
	
	Namespace = ContactInformationClientServerCached.Namespace();
	AddressUS         = XDTOAddress.Content;
	Country           = TrimAll(XDTOAddress.Country);
	If IsDomesticAddress(AddressUS) Then
		// This address is domestic; examining the settings
		If Not FormationParameters.IncludeCountryInPresentation Then
			Country = "";
		EndIf;
		
		// Key parts
		Presentation = ContactInformationClientServer.FullDescr(
			AddressPostalCode(AddressUS), "",
			AddressUS.Region, "",
			AddressCounty(AddressUS), "",
			AddressUS.City, "",
			AddressUS.District, "",
			AddressUS.Settlement, "",
			AddressUS.Street, "");
			
		// Building units
		NumberNotDisplayed = True;
		Data = BuildingAddresses(AddressUS);
		For Each Row In Data.Buildings Do
			Presentation =  ContactInformationClientServer.FullDescr(
				Presentation, "",
				TrimAll(Row.Abbr + ?(NumberNotDisplayed, " № ", " ") + Row.Value), "");
			NumberNotDisplayed = False;
		EndDo;
			
		// If the presentation is empty, there is no point in displaying the country
		If IsBlankString(Presentation) Then
			Country = "";
		EndIf;
	Else
		// This address is foreign
		Presentation = TrimAll(AddressUS);
	EndIf;
	
	Return ContactInformationClientServer.FullDescr(Country, "", Presentation, "");
EndFunction

//  Returns the list of address errors.
//
// Parameters:
//     XDTOAddress         - XDTODataObject, ValueList, String - address
//     description InformationKind     - CatalogRef.ContactInformationTypes - reference to a related contact
// information kind. ResultByGroups - Boolean - if True, returns an array of error groups, otherwise - value list.
//
// Returns:
//     ValueList - if ResultByGroups = False. Contains a presentation - error text, value - error field
//     XPath. Array         - if ResultByGroups = True. Contains structures with fields:
//                         ** ErrorType - String - error group (type) name. Allowed values:
//                               "PresentationNotMatchingFieldSet"
//                               "MandatoryFieldsNotFilled"
//                               "FieldAbbreviationsNotSpecified"
//                               "InvalidFieldCharacters"
//                               "FieldLengthsNotMatching"
//                               "ClassifierErrors"
//                         ** Message - String - detailed
//                         error text. ** Fields      - Array - contains the error field description structures. Each
//                         structure has attributes:
//                               *** FieldName   - String - internal ID invalid item addresses 
//                               *** Message - String - detailed error text for this field
//
Function AddressFillErrors(Val XDTOAddress, Val InformationKind, Val ResultByGroups = False) Export
		
	If TypeOf(XDTOAddress) = Type("XDTODataObject") Then
		AddressUS = XDTOAddress.Content;
	Else
		XTDOContactInformation = AddressDeserialization(XDTOAddress);
		Address = XTDOContactInformation.Content;
		AddressUS = ?(Address = Undefined, Undefined, Address.Content);
	EndIf;
	
	// Check flags
	If TypeOf(InformationKind) = Type("CatalogRef.ContactInformationTypes") Then
		CheckFlags = ContactInformationManagement.ContactInformationTypestructure(InformationKind);
	Else
		CheckFlags = InformationKind;
	EndIf;
	
	Namespace = ContactInformationClientServerCached.Namespace();
	If TypeOf(AddressUS) <> Type("XDTODataObject") Or AddressUS.Type() <> XDTOFactory.Type(Namespace, "AddressUS") Then
		// Foreign address
		Result = ?(ResultByGroups, New Array, New ValueList);
		
		If CheckFlags.DomesticAddressOnly Then
			ErrorText = NStr("en = 'Only domestic addresses are allowed.'");
			If ResultByGroups Then
				Result.Add(New Structure("Fields, ErrorType, Message", New Array,
					"MandatoryFieldsNotFilled", ErrorText
				)); 
			Else
				Result.Add("/", ErrorText);
			EndIf;
		EndIf;
		
		Return Result;
	EndIf;
	
	// Address classified is not available
	Return ?(ResultByGroups, New Array, New ValueList);
	
	// Checking the empty address separately if it has to be filled
	If Not XDTOContactInformationFilled(AddressUS) Then
		// The address is empty
		If CheckFlags.Mandatory Then
			// But it is mandatory to fill
			ErrorText = NStr("en = 'Address is not filled in.'");
			
			If ResultByGroups Then
				Result = New Array;
				Result.Add(New Structure("Fields, ErrorType, Message", New Array,
					"MandatoryFieldsNotFilled", ErrorText
				)); 
			Else
				Result = New ValueList;
				Result.Add("/", ErrorText);
			EndIf;
			
			Return Result
		EndIf;
		
		// The address is empty but it is not mandatory to fill; therefore it is valid
		Return ?(ResultByGroups, New Array, New ValueList);
	EndIf;
			
	AllErrors = AddressFillErrorsCommonGroups(AddressUS, CheckFlags);
	CheckClassifier = True;
	
	For Each Group In AllErrors Do
		If Find("FieldAbbreviationsNotSpecified, InvalidFieldCharacters", Group.ErrorType) > 0 Then
			// Invalid field data; there is no point in validating it by classifier
			CheckClassifier = False;
			Break;
		EndIf
	EndDo;
	
	ClassifierErrors = New ValueList;
	If CheckClassifier Then
		// Address classifier is not available		
	EndIf;
	
	If ResultByGroups Then
		ErrorGroupDescription = "ErrorsByClassifier";
		ErrorsCount = ClassifierErrors.Count();
		
		If ErrorsCount = 1 AND ClassifierErrors[0].Value <> Undefined
			AND ClassifierErrors[0].Value.XPath = Undefined 
		Then
			AllErrors.Add(AddressErrorGroup(ErrorGroupDescription,
				ClassifierErrors[0].Presentation));
			
		ElsIf ErrorsCount > 0 Then
			// Detailed error description
			AllErrors.Add(AddressErrorGroup(ErrorGroupDescription,
				NStr("en = 'Parts of the address do not correspond to the address classifier:'")));
				
			ClassifierErrorGroup = AllErrors[AllErrors.UBound()];
			
			EntityList = "";
			For Each Item In ClassifierErrors Do
				ErrorItem = Item.Value;
				If ErrorItem = Undefined Then
					// Abstract error
					AddAddressFillError(ClassifierErrorGroup, 
						"", Item.Presentation);
				Else
					AddAddressFillError(ClassifierErrorGroup, 
						ErrorItem.XPath, Item.Presentation);
					EntityList = EntityList + ", " + ErrorItem.FieldEntity;
				EndIf;
			EndDo;
			
			ClassifierErrorGroup.Message = ClassifierErrorGroup.Message + Mid(EntityList, 2);
		EndIf;
		
		Return AllErrors;
	EndIf;
	
	// Adding all data to a list
	Result = New ValueList;
	For Each Group In AllErrors Do
		For Each Field In Group.Fields Do
			Result.Add(Field.FieldName, Field.Message);
		EndDo;
	EndDo;
	For Each ListItem In ClassifierErrors Do
		Result.Add(ListItem.Value.XPath, ListItem.Presentation);
	EndDo;
	
	Return Result;
EndFunction

// General address validation
//
//  Parameters:
//      AddressData  - String, ValueList - XML, XDTO with domestic
//      address data. InformationKind - CatalogRef.ContactInformationTypes - reference to a related contact information kind 
//
// Returns:
//      Array - contains structures with fields:
//         * ErrorType - String - error group ID. Can take on values:
//              "PresentationNotMatchingFieldSet"
//              "MandatoryFieldsNotFilled"
//              "FieldAbbreviationsNotSpecified"
//              "InvalidFieldCharacters"
//              "FieldLengthsNotMatching"
//         * Message - String - detailed error text.
//         * Fields - array of structures with fields:
//             ** FieldName - internal ID of the invalid field. 
//             ** Message - detailed error text for the field.
//
Function AddressFillErrorsCommonGroups(Val AddressData, Val InformationKind) Export
	
	Result = New Array;
		
	If TypeOf(AddressData) = Type("XDTODataObject") Then
		AddressUS = AddressData;
		
	Else
		XTDOContactInformation = AddressDeserialization(AddressData);
		Address = XTDOContactInformation.Content;
		If Not IsDomesticAddress(Address) Then
			Return Result;
		EndIf;
		AddressUS = Address.Content;
		
		// 1) presentation must match the data set
		Presentation = AddressPresentation(AddressUS, InformationKind);
		If XTDOContactInformation.Presentation <> Presentation Then
			Result.Add(AddressErrorGroup("PresentationNotMatchingFieldSet",
				NStr("en = 'The address does not match the field set values.'")));
			AddAddressFillError(Result[0], "",
				StringFunctionsClientServer.SubstituteParametersInString( 
					NStr("en = 'Address presentation for contact information kind ""%1"" is different from address data.'"),
					String(InformationKind.Description)));
		EndIf;
	EndIf;
	
	MandatoryFieldsNotFilled = AddressErrorGroup("MandatoryFieldsNotFilled",
		NStr("en = 'Required fields are not entered:'"));
	Result.Add(MandatoryFieldsNotFilled);
	
	FieldAbbreviationsNotSpecified = AddressErrorGroup("FieldAbbreviationsNotSpecified",
		NStr("en = 'Abbreviations are not specified for fields:'"));
	Result.Add(FieldAbbreviationsNotSpecified);
	
	InvalidFieldCharacters = AddressErrorGroup("InvalidFieldCharacters",
		NStr("en = 'Invalid characters are found in fields:'"));
	Result.Add(InvalidFieldCharacters);
	
	FieldLengthsNotMatching = AddressErrorGroup("FieldLengthsNotMatching",
		NStr("en = 'Field length does not match the predefined value for fields:'"));
	Result.Add(FieldLengthsNotMatching);
	
	// 2) PostalCode, State, Building fields must be filled
	PostalCode = AddressPostalCode(AddressUS);
	If IsBlankString(PostalCode) Then
		AddAddressFillError(MandatoryFieldsNotFilled, ContactInformationClientServerCached.PostalCodeXPath(),
			NStr("en = 'Zip code is not specified.'"), "PostalCode");
	EndIf;
	
	State = AddressUS.Region;
	If IsBlankString(State) Then
		AddAddressFillError(MandatoryFieldsNotFilled, "Region",
			NStr("en = 'Region is not specified.'"), "State");
	EndIf;
	
	BuildingsUnits = BuildingAddresses(AddressUS);
	If SkipBuildingAddressCheck(AddressUS) Then
		// Any building unit data must be filled
		
		UnitNotSpecified = True;
		For Each BuildingData In BuildingsUnits.Buildings Do
			If Not IsBlankString(BuildingData.Value) Then
				UnitNotSpecified = False;
				Break;
			EndIf;
		EndDo;
		If UnitNotSpecified Then
			AddAddressFillError(MandatoryFieldsNotFilled, 
				ContactInformationClientServerCached.AdditionalAddressingObjectNumberXPath("Building"),
				NStr("en = 'House or block is not specified.'"), 
				NStr("en = 'Building'")
			);
		EndIf;
			
	Else
		// Building number is mandatory; unit number is optional.
		
		BuildingData = BuildingsUnits.Buildings.Find(1, "Kind");	// 1 - kind by ownership
		If BuildingData = Undefined Then
			AddAddressFillError(MandatoryFieldsNotFilled, 
				ContactInformationClientServerCached.AdditionalAddressingObjectNumberXPath("Building"),
				NStr("en = 'House or estate is not specified.'"),
				NStr("en = 'Building'")
			);
		ElsIf IsBlankString(BuildingData.Value) Then
			AddAddressFillError(MandatoryFieldsNotFilled, BuildingData.XPath,
				NStr("en = 'Value of the house or estate is not entered.'"),
				NStr("en = 'Building'")
			);
		EndIf;
		
	EndIf;
	
	// 3) State, County, City, Settlement, Street must:    
	//      - have abbreviations
	//      - be under 50 characters
	//      - contain Latin letters only
	
	AllowedBesidesLatin = "/,-. 0123456789_";
	
	// State
	If Not IsBlankString(State) Then
		Field = "Region";
		If IsBlankString(ContactInformationClientServer.Abbr(State)) Then
			AddAddressFillError(FieldAbbreviationsNotSpecified, "Region",
				StringFunctionsClientServer.SubstituteParametersInString( 
					NStr("en = 'Abbreviation is not specified in the name of region ""%1"".'"), State), NStr("en = 'Region'"));
		EndIf;
		If StrLen(State) > 50 Then
			AddAddressFillError(FieldLengthsNotMatching, Field,
				StringFunctionsClientServer.SubstituteParametersInString( 
					NStr("en = 'Name of region ""%1"" should be less than 50 characters.'"), State), NStr("en = 'Region'"));
		EndIf;
		If Not StringFunctionsClientServer.OnlyLatinInString(State, False, AllowedBesidesLatin) Then
			AddAddressFillError(InvalidFieldCharacters, Field,
				StringFunctionsClientServer.SubstituteParametersInString( 
					NStr("en = 'The name of state ""%1"" contains non-Latin characters.'"), State), NStr("en = 'Region'"));
		EndIf
	EndIf;
	
	// County
	County = AddressCounty(AddressUS);
	If Not IsBlankString(County) Then
		Field = ContactInformationClientServerCached.CountyXPath();
		If IsBlankString(ContactInformationClientServer.Abbr(County)) Then
			AddAddressFillError(FieldAbbreviationsNotSpecified, Field,
				StringFunctionsClientServer.SubstituteParametersInString( 
					NStr("en = 'Abbreviation is not specified for county ""%1"".'"),
					County),
				NStr("en = 'District'"));
		EndIf;
		If StrLen(County) > 50 Then
			AddAddressFillError(FieldLengthsNotMatching, Field,
				StringFunctionsClientServer.SubstituteParametersInString( 
					NStr("en = 'Name of district ""%1"" should be less than 50 characters.'"), County), NStr("en = 'District'"));
		EndIf;
		If Not StringFunctionsClientServer.OnlyLatinInString(County, False, AllowedBesidesLatin) Then
			AddAddressFillError(InvalidFieldCharacters, Field,
				StringFunctionsClientServer.SubstituteParametersInString( 
					NStr("en = 'The name of county ""%1"" contains non-Latin characters.'"), County), NStr("en = 'District'"));
		EndIf;
	EndIf;
	
	// City
	City = AddressUS.City;
	If Not IsBlankString(City) Then
		Field = "City";
		If IsBlankString(ContactInformationClientServer.Abbr(City)) Then
			AddAddressFillError(FieldAbbreviationsNotSpecified, Field,
				StringFunctionsClientServer.SubstituteParametersInString( 
					NStr("en = 'Abbreviation is not specified in the name of city ""%1"".'"), City), NStr("en = 'City'"));
		EndIf;
		If StrLen(City) > 50 Then
			AddAddressFillError(FieldLengthsNotMatching, Field,
				StringFunctionsClientServer.SubstituteParametersInString( 
					NStr("en = 'City name ""%1"" should be less than 50 characters.'"), City), NStr("en = 'City'"));
		EndIf;
		If Not StringFunctionsClientServer.OnlyLatinInString(City, False, AllowedBesidesLatin) Then
			AddAddressFillError(InvalidFieldCharacters, Field,
				StringFunctionsClientServer.SubstituteParametersInString( 
					NStr("en = 'City name ""%1"" contains non-Latin characters.'"), City), NStr("en = 'City'"));
		EndIf;
	EndIf;
	
	// Settlement
	Settlement = AddressUS.Settlement;
	If Not IsBlankString(Settlement) Then
		Field = "Settlement";
		If IsBlankString(ContactInformationClientServer.Abbr(Settlement)) Then
			AddAddressFillError(FieldAbbreviationsNotSpecified, Field,
				StringFunctionsClientServer.SubstituteParametersInString( 
					NStr("en = 'Abbreviation is not specified in the settlement name ""%1"".'"), Settlement
				), NStr("en = 'Settlement'"));
		EndIf;
		If StrLen(Settlement) > 50 Then
			AddAddressFillError(FieldLengthsNotMatching, Field,
				StringFunctionsClientServer.SubstituteParametersInString( 
					NStr("en = 'Name of settlement ""%1"" should be less than 50 characters.'"), Settlement
				), NStr("en = 'Settlement'"));
		EndIf;
		If Not StringFunctionsClientServer.OnlyLatinInString(Settlement, False, AllowedBesidesLatin) Then
			AddAddressFillError(InvalidFieldCharacters, Field,
				StringFunctionsClientServer.SubstituteParametersInString( 
					NStr("en = 'Settlement name ""%1"" contains non-Latin characters.'"), Settlement
				), NStr("en = 'Settlement'"));
		EndIf;
	EndIf;
	
	// Street
	Street = AddressUS.Street;
	If Not IsBlankString(Street) Then
		Field = "Street";
		If IsBlankString(ContactInformationClientServer.Abbr(Street)) Then
			AddAddressFillError(FieldAbbreviationsNotSpecified, Field,
				StringFunctionsClientServer.SubstituteParametersInString( 
					NStr("en = 'Abbreviation is not specified in the name of street ""%1"".'"), Street
				), NStr("en = 'Street'"));
		EndIf;
		If StrLen(County) > 50 Then
			AddAddressFillError(FieldLengthsNotMatching, Field,
				StringFunctionsClientServer.SubstituteParametersInString( 
					NStr("en = 'Name of street ""%1"" should be less than 50 characters.'"), Street
				), NStr("en = 'Street'"));
		EndIf;
		If Not StringFunctionsClientServer.OnlyLatinInString(Street, False, AllowedBesidesLatin) Then
			AddAddressFillError(InvalidFieldCharacters, Field,
				StringFunctionsClientServer.SubstituteParametersInString( 
					NStr("en = 'The name of street ""%1"" contains non-Latin characters.'"), Street
				), NStr("en = 'Street'"));
		EndIf;
	EndIf;
	
	// 4) Postal code - must contain 6 digits, if any
	If Not IsBlankString(PostalCode) Then
		Field = ContactInformationClientServerCached.PostalCodeXPath();
		If StrLen(PostalCode) <> 6 Or Not StringFunctionsClientServer.OnlyNumbersInString(PostalCode) Then
			AddAddressFillError(FieldLengthsNotMatching, Field,
				NStr("en = 'Postal code should contain 6 digits.'"),
				NStr("en = 'Postal code'")
			);
		EndIf;
	EndIf;
	
	// 5) Building, Unit, Apartment must be under 10 characters
	For Each UnitData In BuildingsUnits.Buildings Do
		If StrLen(UnitData.Value) > 10 Then
			AddAddressFillError(FieldLengthsNotMatching, UnitData.XPath,
				StringFunctionsClientServer.SubstituteParametersInString( 
					NStr("en = 'Value of field ""%1"" must be shorter than 10 characters.'"), UnitData.Type
				), UnitData.Type);
		EndIf;
	EndDo;

    // 6) City and Settlement fields cannot both be empty	
	If IsBlankString(City) AND IsBlankString(Settlement) Then
			AddAddressFillError(MandatoryFieldsNotFilled, NStr("en = 'City and Settlement fields cannot both be empty'"),
				NStr("en = 'Settlement'")
			);
	EndIf;
	
	// 7) Street name cannot be empty if Settlement name is empty
	If Not SkipStreetAddressCheck(AddressUS) Then
			
		If IsBlankString(Settlement) AND IsBlankString(Street) Then
			AddAddressFillError(MandatoryFieldsNotFilled, "Street",
				NStr("en = 'If the settlement is undefined, the street is mandatory.'"), 
				NStr("en = 'Street'")
			);
		EndIf;
		
	EndIf;
	
	// Final step - removing the empty results, modifying the group message
	For Index = 1-Result.Count() To 0 Do
		Group = Result[-Index];
		Fields = Group.Fields;
		EntityList = "";
		For FieldIndex = 1-Fields.Count() To 0 Do
			Field = Fields[-FieldIndex];
			If IsBlankString(Field.Message) Then
				Fields.Delete(-FieldIndex);
			Else
				EntityList = ", " + Field.FieldEntity + EntityList;
				Field.Delete("FieldEntity");
			EndIf;
		EndDo;
		If Fields.Count() = 0 Then
			Result.Delete(-Index);
		ElsIf Not IsBlankString(EntityList) Then
			Group.Message = Group.Message + Mid(EntityList, 2);
		EndIf;
	EndDo;
	
	Return Result;
EndFunction

// Local exceptions allowed during address validation
//
Function SkipBuildingAddressCheck(Val AddressUS)
	Result = False;
	Return Result;
EndFunction
	
// Local exceptions allowed during address validation
//
Function SkipStreetAddressCheck(Val AddressUS)
	Result = False;
	
	Return Result;
EndFunction

//  Returns a phone number presentation.
//
//  Parameters:
//      XDTOData        - XDTODataObject - contact information. 
//      InformationKind - CatalogRef.ContactInformationTypes - reference to a related contact information kind 
//
// Returns:
//      String - presentation.
//
Function PhonePresentation(XDTOData, InformationKind = Undefined) Export
	Return ContactInformationManagementClientServer.GeneratePhonePresentation(
		RemoveNonDigitCharacters(XDTOData.CountryCode), 
		XDTOData.AreaCode,
		XDTOData.Number,
		XDTOData.Extension,
		"");
EndFunction

//  Returns a fax number presentation.
//
//  Parameters:
//      XDTOData    - XDTODataObject - contact information. 
//      InformationKind - CatalogRef.ContactInformationTypes - reference to a related contact information kind.
//
// Returns:
//      String - presentation.
//
Function FaxPresentation(XDTOData, InformationKind = Undefined) Export
	Return ContactInformationManagementClientServer.GeneratePhonePresentation(
		RemoveNonDigitCharacters(XDTOData.CountryCode), 
		XDTOData.AreaCode,
		XDTOData.Number,
		XDTOData.Extension,
		"");
EndFunction

#EndRegion

#Region Compatibility
//

Function AddressErrorGroup(ErrorType, Message)
	Return New Structure("ErrorType, Message, Fields", ErrorType, Message, New Array);
EndFunction

Procedure AddAddressFillError(Group, FieldName = "", Message = "", FieldEntity = "")
	Group.Fields.Add(New Structure("FieldName, Message, FieldEntity", FieldName, Message, FieldEntity));
EndProcedure

#EndRegion

#Region AddressClassifierImplementation
//

// Value table constructor
Function ValueTable(ColumnList, IndexList = "")
	ResultTable = New ValueTable;
	
	For Each KeyValue In (New Structure(ColumnList)) Do
		ResultTable.Columns.Add(KeyValue.Key);
	EndDo;
	
	IndexRows = StrReplace(IndexList, "|", Chars.LF);
	For PostalCodeNumber = 1 To StrLineCount(IndexRows) Do
		IndexColumns = TrimAll(StrGetLine(IndexRows, PostalCodeNumber));
		For Each KeyValue In (New Structure(IndexColumns)) Do
			ResultTable.Indexes.Add(KeyValue.Key);
		EndDo;
	EndDo;
	
	Return ResultTable;
EndFunction

// Internal, for serialization purposes
Function AddressDeserializationCommon(Val FieldValues, Val Presentation, Val ExpectedType = Undefined)
	
	If ContactInformationClientServer.IsXMLContactInformation(FieldValues) Then
		// Common format of contact information
		Return ContactInformationDeserialization(FieldValues, ExpectedType);
	EndIf;
	
	If ExpectedType <> Undefined Then
		If ExpectedType <> Enums.ContactInformationTypes.Address Then
			Raise NStr("en = 'An error occurred when deserializing the contact information, address is expected'");
		EndIf;
	EndIf;
	
	// Old format, with string separator and exact match
	Namespace = ContactInformationClientServerCached.Namespace();
	
	Result = XDTOFactory.Create(XDTOFactory.Type(Namespace, "ContactInformation"));
	
	Result.Comment = "";
	Result.Content      = XDTOFactory.Create(XDTOFactory.Type(Namespace, "Address"));
	
	AddressDomestic = True;
	HomeCountry		= Constants.HomeCountry.Get();
	HomeCountryName	= Upper(HomeCountry.Description);
	
	ApartmentItem = Undefined;
	UnitItem   = Undefined;
	BuildingItem      = Undefined;
	
	// Domestic
	AddressUS = XDTOFactory.Create(XDTOFactory.Type(Namespace, "AddressUS"));
	
	// Common content
	Address = Result.Content;
	
	FieldValueType = TypeOf(FieldValues);
	If FieldValueType = Type("ValueList") Then
		FieldList = FieldValues;
	ElsIf FieldValueType = Type("Structure") Then
		FieldList = ContactInformationManagementClientServer.ConvertStringToFieldList(
			ContactInformationManagementClientServer.FieldRow(FieldValues, False));
	Else
		// Already transformed to a string
		FieldList = ContactInformationManagementClientServer.ConvertStringToFieldList(FieldValues);
	EndIf;
	
	ApartmentTypeUndefined = True;
	UnitTypeUndefined  = True;
	BuildingTypeUndefined     = True;
	PresentationField      = "";
	
	For Each ListItem In FieldList Do
		FieldName = Upper(ListItem.Presentation);
		
		If FieldName="POSTALCODE" Then
			PostalCodeItem = CreateAdditionalAddressItem(AddressUS);
			PostalCodeItem.AddressItemType = ContactInformationClientServerCached.PostalCodeSerializationCode();
			PostalCodeItem.Value = ListItem.Value;
			
		ElsIf FieldName = "COUNTRY" Then
			Address.Country = ListItem.Value;
			If Upper(ListItem.Value) <> HomeCountryName Then
				AddressDomestic = False;
			EndIf;
			
		ElsIf FieldName = "COUNTRYCODE" Then
			;
			
		ElsIf FieldName = "STATECODE" Then
			AddressUS.Region = CodeState(ListItem.Value);
			
		ElsIf FieldName = "STATE" Then
			AddressUS.Region = ListItem.Value;
			
		ElsIf FieldName = "COUNTY" Then
			If AddressUS.CountyMunicipalEntity = Undefined Then
				AddressUS.CountyMunicipalEntity = XDTOFactory.Create( AddressUS.Type().Properties.Get("CountyMunicipalEntity").Type )
			EndIf;
			AddressUS.CountyMunicipalEntity.County = ListItem.Value;
			
		ElsIf FieldName = "CITY" Then
			AddressUS.City = ListItem.Value;
			
		ElsIf FieldName = "SETTLEMENT" Then
			AddressUS.Settlement = ListItem.Value;
			
		ElsIf FieldName = "STREET" Then
			AddressUS.Street = ListItem.Value;
			
		ElsIf FieldName = "BUILDINGTYPE" Then
			If BuildingItem = Undefined Then
				BuildingItem = CreateAdditionalAddressItemNumber(AddressUS);
			EndIf;
			BuildingItem.Type = ContactInformationClientServerCached.AddressingObjectSerializationCode(ListItem.Value);
			BuildingTypeUndefined = False;
			
		ElsIf FieldName = "BUILDING" Then
			If BuildingItem = Undefined Then
				BuildingItem = CreateAdditionalAddressItemNumber(AddressUS);
			EndIf;
			BuildingItem.Value = ListItem.Value;
			
		ElsIf FieldName = "UNITTYPE" Then
			If UnitItem = Undefined Then
				UnitItem = CreateAdditionalAddressItemNumber(AddressUS);
			EndIf;
			UnitItem.Type = ContactInformationClientServerCached.AddressingObjectSerializationCode(ListItem.Value);
			UnitTypeUndefined = False;
			
		ElsIf FieldName = "UNIT" Then
			If UnitItem = Undefined Then
				UnitItem = CreateAdditionalAddressItemNumber(AddressUS);
			EndIf;
			UnitItem.Value = ListItem.Value;
			
		ElsIf FieldName = "APARTMENTTYPE" Then
			If ApartmentItem = Undefined Then
				ApartmentItem = CreateAdditionalAddressItemNumber(AddressUS);
			EndIf;
			ApartmentItem.Type = ContactInformationClientServerCached.AddressingObjectSerializationCode(ListItem.Value);
			ApartmentTypeUndefined = False;
			
		ElsIf FieldName = "APARTMENT" Then
			If ApartmentItem = Undefined Then
				ApartmentItem = CreateAdditionalAddressItemNumber(AddressUS);
			EndIf;
			ApartmentItem.Value = ListItem.Value;
			
		ElsIf FieldName = "PRESENTATION" Then
			PresentationField = TrimAll(ListItem.Value);
			
		EndIf;
		
	EndDo;
	
	// Default preferences
	If BuildingTypeUndefined AND BuildingItem <> Undefined Then
		BuildingItem.Type = ContactInformationClientServerCached.AddressingObjectSerializationCode("Building");
	EndIf;
	
	If UnitTypeUndefined AND UnitItem <> Undefined Then
		UnitItem.Type = ContactInformationClientServerCached.AddressingObjectSerializationCode("Unit");
	EndIf;
	
	If ApartmentTypeUndefined AND ApartmentItem <> Undefined Then
		ApartmentItem.Type = ContactInformationClientServerCached.AddressingObjectSerializationCode("Apartment");
	EndIf;
	
	// Presentation with priorities
	If Not IsBlankString(Presentation) Then
		Result.Presentation = Presentation;
	Else
		Result.Presentation = PresentationField;
	EndIf;
	
	Address.Content = ?(AddressDomestic, AddressUS, Result.Presentation);
	
	Return Result;
EndFunction

// Returns a flag specifying whether the passed contact information object contains data.
//
// Parameters:
//     XDTOData - XDTODataObject - contact information data to be checked.
//
// Returns:
//     Boolean - data availability flag.
//
Function XDTOContactInformationFilled(Val XDTOData) Export
	
	Return HasFilledXDTOContactInformationProperies(XDTOData);
	
EndFunction

// Parameters: Owner - XDTODataObject, Undefined
//
Function HasFilledXDTOContactInformationProperies(Val Owner)
	
	If Owner = Undefined Then
		Return False;
	EndIf;
	
	// List of the current owner properties to be ignored during comparison - contact information specifics
	Ignored = New Map;
	
	Namespace = ContactInformationClientServerCached.Namespace();
	OwnerType     = Owner.Type();
	
	If OwnerType = XDTOFactory.Type(Namespace, "Address") Then
		// The country is irrelevant if other fields are empty. Ignoring
		Ignored.Insert(Owner.Properties().Get("Country"), True);
		
	ElsIf OwnerType = XDTOFactory.Type(Namespace, "AddressUS") Then
		// Ignoring lists with empty values and possibly non-empty types
		List = Owner.GetList("AdditionalAddressItem");
		If List <> Undefined Then
			For Each ListProperty In List Do
				If IsBlankString(ListProperty.Value) Then
					Ignored.Insert(ListProperty, True);
				EndIf;
			EndDo;
		EndIf;
		
	EndIf;
	
	For Each Property In Owner.Properties() Do
		
		If Not Owner.IsSet(Property) Or Ignored[Property] <> Undefined Then
			Continue;
		EndIf;
		
		If Property.UpperBound > 1 Or Property.UpperBound < 0 Then
			List = Owner.GetList(Property);
			
			If List <> Undefined Then
				For Each ListItem In List Do
					If Ignored[ListItem] = Undefined 
						AND HasFilledXDTOContactInformationProperies(ListItem) 
					Then
						Return True;
					EndIf;
				EndDo;
			EndIf;
			
			Continue;
		EndIf;
		
		Value = Owner.Get(Property);
		If TypeOf(Value) = Type("XDTODataObject") Then
			If HasFilledXDTOContactInformationProperies(Value) Then
				Return True;
			EndIf;
			
		ElsIf Not IsBlankString(Value) Then
			Return True;
			
		EndIf;
		
	EndDo;
		
	Return False;
EndFunction

Procedure InsertUnit(XDTOAddress, Type, Value)
	If IsBlankString(Value) Then
		Return;
	EndIf;
	
	Write = XDTOAddress.Get( ContactInformationClientServerCached.AdditionalAddressingObjectNumberXPath(Type) );
	If Write = Undefined Then
		Write = XDTOAddress.AdditionalAddressItem.Add( XDTOFactory.Create(XDTOAddress.AdditionalAddressItem.OwningProperty.Type) );
		Write.Number = XDTOFactory.Create(Write.Properties().Get("Number").Type);
		Write.Number.Value = Value;
		
		TypeCode = ContactInformationClientServerCached.AddressingObjectSerializationCode(Type);
		If TypeCode = Undefined Then
			TypeCode = Type;
		EndIf;
		Write.Number.Type = TypeCode
	Else        
		Write.Value = Value;
	EndIf;
	
EndProcedure

Function CreateAdditionalAddressItemNumber(AddressUS)
	AdditionalAddressItem = CreateAdditionalAddressItem(AddressUS);
	AdditionalAddressItem.Number = XDTOFactory.Create(AdditionalAddressItem.Type().Properties.Get("Number").Type);
	Return AdditionalAddressItem.Number;
EndFunction

Function CreateAdditionalAddressItem(AddressUS)
	AdditionalAddressItemProperty = AddressUS.AdditionalAddressItem.OwningProperty;
	AdditionalAddressItem = XDTOFactory.Create(AdditionalAddressItemProperty.Type);
	AddressUS.AdditionalAddressItem.Add(AdditionalAddressItem);
	Return AdditionalAddressItem;
EndFunction

Function CountyMunicipalEntity(AddressUS)
	If AddressUS.CountyMunicipalEntity <> Undefined Then
		Return AddressUS.CountyMunicipalEntity;
	EndIf;
	
	AddressUS.CountyMunicipalEntity = XDTOFactory.Create( AddressUS.Properties().Get("CountyMunicipalEntity").Type );
	Return AddressUS.CountyMunicipalEntity;
EndFunction

Function PhoneFaxDeserialization(FieldValues, Presentation = "", ExpectedType = Undefined)
	
	If ContactInformationClientServer.IsXMLContactInformation(FieldValues) Then
		// Common format of contact information
		Return ContactInformationDeserialization(FieldValues, ExpectedType);
	EndIf;
	
	Namespace = ContactInformationClientServerCached.Namespace();
	
	If ExpectedType=Enums.ContactInformationTypes.Phone Then
		Data = XDTOFactory.Create(XDTOFactory.Type(Namespace, "PhoneNumber"));
		
	ElsIf ExpectedType=Enums.ContactInformationTypes.Fax Then
		Data = XDTOFactory.Create(XDTOFactory.Type(Namespace, "FaxNumber"));
		
	ElsIf ExpectedType=Undefined Then
		// This data is considered to be a phone number
		Data = XDTOFactory.Create(XDTOFactory.Type(Namespace, "PhoneNumber"));
		
	Else
		Raise NStr("en = 'An error occurred when deserializing the contact information, phone number or fax is expected'");
	EndIf;
	
	Result = XDTOFactory.Create(XDTOFactory.Type(Namespace, "ContactInformation"));
	Result.Content        = Data;
	
	// From key-value pairs
	FieldValueList = Undefined;
	If TypeOf(FieldValues)=Type("ValueList") Then
		FieldValueList = FieldValues;
	ElsIf Not IsBlankString(FieldValues) Then
		FieldValueList = ContactInformationManagementClientServer.ConvertStringToFieldList(FieldValues);
	EndIf;
	
	PresentationField = "";
	If FieldValueList <> Undefined Then
		For Each AttributeValue In FieldValueList Do
			Field = Upper(AttributeValue.Presentation);
			
			If Field = "COUNTRYCODE" Then
				Data.CountryCode = AttributeValue.Value;
				
			ElsIf Field = "AREACODE" Then
				Data.AreaCode = AttributeValue.Value;
				
			ElsIf Field = "PHONENUMBER" Then
				Data.Number = AttributeValue.Value;
				
			ElsIf Field = "EXTENSION" Then
				Data.Extension = AttributeValue.Value;
				
			ElsIf Field = "PRESENTATION" Then
				PresentationField = TrimAll(AttributeValue.Value);
				
			EndIf;
			
		EndDo;
		
		// Presentation with priorities
		If Not IsBlankString(Presentation) Then
			Result.Presentation = Presentation;
		Else
			Result.Presentation = PresentationField;
		EndIf;
		
		Return Result;
	EndIf;
	
	// Parsing the presentation
	
	// Digit groups separated by non-digit characters - country, city, number, extension. 
	// The extension is bracketed by non-whitespace characters.
	Position = 1;
	Data.CountryCode  = FindDigitSubstring(Presentation, Position);
	CityBeginning = Position;
	
	Data.AreaCode  = FindDigitSubstring(Presentation, Position);
	Data.Number      = FindDigitSubstring(Presentation, Position, " -");
	
	Extension = TrimAll(Mid(Presentation, Position));
	If Left(Extension, 1) = "," Then
		Extension = TrimL(Mid(Extension, 2));
	EndIf;
	If Upper(Left(Extension, 3 ))= "EXT" Then
		Extension = TrimL(Mid(Extension, 4));
	EndIf;
	If Upper(Left(Extension, 1 ))= "." Then
		Extension = TrimL(Mid(Extension, 2));
	EndIf;
	Data.Extension = TrimAll(Extension);
	
	// Fixing possible errors
	If IsBlankString(Data.Number) Then
		If Left(TrimL(Presentation),1)="+" Then
			// An attempt to specify the area code explicitly is detected. Leaving the area code "as is"
			Data.AreaCode  = "";
			Data.Number      = RemoveNonDigitCharacters(Mid(Presentation, CityBeginning));
			Data.Extension = "";
		Else
			Data.CountryCode  = "";
			Data.AreaCode  = "";
			Data.Number      = Presentation;
			Data.Extension = "";
		EndIf;
	EndIf;
	
	Result.Presentation = Presentation;
	Return Result;
EndFunction

// Returns the first digit substring found in a string. 
// The StartPosition parameter is set to the position of the first non-digit character.
Function FindDigitSubstring(Text, StartPosition = Undefined, AllowedBesidesDigits = "")
	
	If StartPosition = Undefined Then
		StartPosition = 1;
	EndIf;
	
	Result = "";
	EndPosition = StrLen(Text);
	BeginningSearch  = True;
	
	While StartPosition <= EndPosition Do
		Char = Mid(Text, StartPosition, 1);
		IsDigit = Char >= "0" AND Char <= "9";
		
		If BeginningSearch Then
			If IsDigit Then
				Result = Result + Char;
				BeginningSearch = False;
			EndIf;
		Else
			If IsDigit Or Find(AllowedBesidesDigits, Char) > 0 Then
				Result = Result + Char;    
			Else
				Break;
			EndIf;
		EndIf;
		
		StartPosition = StartPosition + 1;
	EndDo;
	
	// Discarding possible hanging separators to the right
	Return RemoveNonDigitCharacters(Result, AllowedBesidesDigits, False);
	
EndFunction

Function RemoveNonDigitCharacters(Text, AllowedBesidesDigits = "", Direction = True)
	
	Length = StrLen(Text);
	If Direction Then
		// Abbreviation on the left
		Index = 1;
		End  = 1 + Length;
		Step    = 1;
	Else
		// Abbreviation to the right    
		Index = Length;
		End  = 0;
		Step    = -1;
	EndIf;
	
	While Index <> End Do
		Char = Mid(Text, Index, 1);
		IsDigit = (Char >= "0" AND Char <= "9") Or Find(AllowedBesidesDigits, Char) = 0;
		If IsDigit Then
			Break;
		EndIf;
		Index = Index + Step;
	EndDo;
	
	If Direction Then
		// Abbreviation on the left
		Return Right(Text, Length - Index + 1);
	EndIf;
	
	// Abbreviation to the right
	Return Left(Text, Index);
	
EndFunction

// Gets a deep property of the object.
Function PropertyByXPathValue(XTDOObject, XPath) Export
	
	// Line breaks are not expected in XPath
	PropertyString = StrReplace(StrReplace(XPath, "/", Chars.LF), Chars.LF + Chars.LF, "/");
	
	PropertyCount = StrLineCount(PropertyString);
	If PropertyCount = 1 Then
		Return XTDOObject.Get(PropertyString);
	EndIf;
	
	Result = ?(PropertyCount = 0, Undefined, XTDOObject);
	For Index = 1 To PropertyCount Do
		Result = Result.Get(StrGetLine(PropertyString, Index));     
		If Result = Undefined Then 
			Break;
		EndIf;
	EndDo;
	
	Return Result;
EndFunction

// Sets a deep property of the object.
Procedure SetPropertyByXPath(XTDOObject, XPath, Value) Export
	
	// Line breaks are not expected in XPath
	PropertyString = StrReplace(StrReplace(XPath, "/", Chars.LF), Chars.LF + Chars.LF, "/");
	
	PropertyCount = StrLineCount(PropertyString);
	If PropertyCount = 1 Then
		XTDOObject.Set(PropertyString, Value);
		Return;
	ElsIf PropertyCount < 1 Then
		Return;
	EndIf;
		
	ParentObject = Undefined;
	CurrentObject      = XTDOObject;
	For Index = 1 To PropertyCount Do
		
		CurrentName = StrGetLine(PropertyString, Index);
		If CurrentObject.IsSet(CurrentName) Then
			ParentObject = CurrentObject;
			CurrentObject = CurrentObject.GetXDTO(CurrentName);
		Else
			NewType = CurrentObject.Properties().Get(CurrentName).Type;
			TypeType = TypeOf(NewType);
			If TypeType = Type("XDTOObjectType") Then
				NewObject = XDTOFactory.Create(NewType);
				CurrentObject.Set(CurrentName, NewObject);
				ParentObject = CurrentObject;
				CurrentObject = NewObject; 
			ElsIf TypeType = Type("XDTOValueType") Then
				// Immediate value
				CurrentObject.Set(CurrentName, Value);
				ParentObject = Undefined;
				Break;
			EndIf;
		EndIf;
	EndDo;
	
	If ParentObject <> Undefined Then
		ParentObject.Set(CurrentName, Value);
	EndIf;
	
EndProcedure

#EndRegion

#EndRegion
