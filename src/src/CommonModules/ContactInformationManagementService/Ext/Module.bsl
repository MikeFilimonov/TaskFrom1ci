////////////////////////////////////////////////////////////////////////////////////////////////////
// The Contact information subsystem.
// 
////////////////////////////////////////////////////////////////////////////////////////////////////

#Region ServiceProgramInterface

// Returns enumeration value type of the contact information kind.
//
//  Parameters:
//    InformationKind - CatalogRef.ContactInformationTypes, Structure - data source.
//
Function TypeKindContactInformation(Val InformationKind) Export
	Result = Undefined;
	
	Type = TypeOf(InformationKind);
	If Type = Type("EnumRef.ContactInformationTypes") Then
		Result = InformationKind;
	ElsIf Type = Type("CatalogRef.ContactInformationTypes") Then
		Result = InformationKind.Type;
	ElsIf InformationKind <> Undefined Then
		Data = New Structure("Type");
		FillPropertyValues(Data, InformationKind);
		Result = Data.Type;
	EndIf;
	
	Return Result;
EndFunction

// Define the list of catalogs available for import using the Import data from file subsystem.
//
// Parameters:
//  Handlers - ValueTable - list of catalogs, to which the data can be imported.
//      * FullName          - String - full name of the catalog (as in the metadata).
//      * Presentation      - String - presentation of the catalog in the selection list.
//      *AppliedImport - Boolean - if True, then the catalog uses its own
//                                      importing algorithm and the functions are defined in the catalog manager module.
//
Procedure OnDetermineCatalogsForDataImport(ImportedCatalogs) Export
	
	// Import to Countries classifier is denied.
	TableRow = ImportedCatalogs.Find(Metadata.Catalogs.Countries.FullName(), "FullName");
	If TableRow <> Undefined Then 
		ImportedCatalogs.Delete(TableRow);
	EndIf;
	
EndProcedure

// Define metadata objects in the managers modules of which
// the ability to edit attributes is restricted using the GetLockedOjectAttributes export function.
//
// Parameters:
//   Objects - Map - specify the full name of the metadata
//                            object as a key connected to the Deny editing objects attributes subsystem. 
//                            As a value - empty row.
//
Procedure OnDetermineObjectsWithLockedAttributes(Objects) Export
	
	Objects.Insert(Metadata.Catalogs.ContactInformationTypes.FullName(), "");
	
EndProcedure

// Define metadata objects in which modules managers it is restricted to edit attributes on bulk edit.
//
// Parameters:
//   Objects - Map - as a key specify the full name
//                            of the metadata object that is connected to the "Group object change" subsystem. 
//                            Additionally, names of export functions can be listed in the value:
//                            "UneditableAttributesInGroupProcessing",
//                            "EditableAttributesInGroupProcessing".
//                            Each name shall begin with a new row.
//                            If an empty row is specified, then both functions are defined in the manager module.
//
Procedure WhenDefiningObjectsWithEditableAttributes(Objects) Export
	Objects.Insert(Metadata.Catalogs.ContactInformationTypes.FullName(), "NotEditableInGroupProcessingAttributes");
EndProcedure

// Returns an event name for recording to the contact information event log.
//
Function EventLogMessageText() Export
	Return NStr("en = 'Contact information'", 
		CommonUseClientServer.MainLanguageCode());
EndFunction

#EndRegion

#Region ServiceProceduresAndFunctions

#Region ServiceProceduresAndFunctionsForCompatibility

// Parameters: Owner - XDTOObject, Undefined
//
Function HasFilledPropertiesXDTOContactInformation(Val Owner)
	
	If Owner = Undefined Then
		Return False;
	EndIf;
	
	// List of the ignored on comparing properties of the current owner - BillsOfMaterials of contact information.
	Ignored = New Map;
	
	TargetNamespace = ContactInformationManagementClientServerReUse.TargetNamespace();
	OwnerType     = Owner.Type();
	
	If OwnerType = XDTOFactory.Type(TargetNamespace, "Address") Then
		// Country does not affect the filling in if the remainings are empty. Ignore.
		Ignored.Insert(Owner.Properties().Get("Country"), True);
		
	ElsIf OwnerType = XDTOFactory.Type(TargetNamespace, "AddressRF") Then
		// Ignore list with empty values and possibly not empty types.
		List = Owner.GetList("AddEMailAddress");
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
				For Each ItemOfList In List Do
					If Ignored[ItemOfList] = Undefined 
						AND HasFilledPropertiesXDTOContactInformation(ItemOfList) 
					Then
						Return True;
					EndIf;
				EndDo;
			EndIf;
			
			Continue;
		EndIf;
		
		Value = Owner.Get(Property);
		If TypeOf(Value) = Type("XDTODataObject") Then
			If HasFilledPropertiesXDTOContactInformation(Value) Then
				Return True;
			EndIf;
			
		ElsIf Not IsBlankString(Value) Then
			Return True;
			
		EndIf;
		
	EndDo;
		
	Return False;
EndFunction

#EndRegion

// Converts XML to XDTO object of contact information.
//
//  Parameters:
//      Text            - String - XML row of a contact information.
//      ExpectedKind     - CatalogRef.ContactInformationTypes, EnumRef.ContactInformationTypes,
//      Structure ConversionResult - Structure - if it is specified, then the information is written to properties:
//        * ErrorText - String - reading errors description. In this case the return value
// of the function will be of a correct type but unfilled.
//
// Returns:
//      XDTODataObject - contact information corresponding to the ContactInformation XDTO-pack.
//   
Function ContactInformationFromXML(Val Text, Val ExpectedKind = Undefined, ConvertingResult = Undefined) Export
	
	ExpectedType = TypeKindContactInformation(ExpectedKind);
	
	EnumerationAddress                 = Enums.ContactInformationTypes.Address;
	EnumEmailAddress = Enums.ContactInformationTypes.EmailAddress;
	EnumerationWebPage           = Enums.ContactInformationTypes.WebPage;
	EnumerationPhone               = Enums.ContactInformationTypes.Phone;
	EnumFax                  = Enums.ContactInformationTypes.Fax;
	EnumerationAnother                = Enums.ContactInformationTypes.Other;
	
	TargetNamespace = ContactInformationManagementClientServerReUse.TargetNamespace();
	If ContactInformationManagementClientServer.IsContactInformationInXML(Text) Then
		XMLReader = New XMLReader;
		XMLReader.SetString(Text);
		
		ErrorText = Undefined;
		Try
			Result = XDTOFactory.ReadXML(XMLReader, XDTOFactory.Type(TargetNamespace, "ContactInformation"));
		Except
			// Incorrect XML format
			WriteLogEvent(EventLogMonitorEvent(),
				EventLogLevel.Error, , Text, DetailErrorDescription(ErrorInfo()));
			
			If TypeOf(ExpectedKind) = Type("CatalogRef.ContactInformationTypes") Then
				ErrorText = StrReplace(NStr("en = 'Incorrect XML format of the %1 contact information, fields values were cleared.'"),
					"%1", String(ExpectedKind));
			Else
				ErrorText = NStr("en = 'Incorrect XML contact information format, the field values have been cleared.'");
			EndIf;
		EndTry;
		
		If ErrorText = Undefined Then
			// Control types match.
			IsFoundType = ?(Result.Content = Undefined, Undefined, Result.Content.Type());
			If ExpectedType = EnumerationAddress AND IsFoundType <> XDTOFactory.Type(TargetNamespace, "Address") Then
				ErrorText = NStr("en = 'Contact information deserialize error, address is awaited'");
			ElsIf ExpectedType = EnumEmailAddress AND IsFoundType <> XDTOFactory.Type(TargetNamespace, "Email") Then
				ErrorText = NStr("en = 'Contact information deserialize error, email address is expected'");
			ElsIf ExpectedType = EnumerationWebPage AND IsFoundType <> XDTOFactory.Type(TargetNamespace, "WebSite") Then
				ErrorText = NStr("en = 'Contact information deserialize error, waiting for the web page'");
			ElsIf ExpectedType = EnumerationPhone AND IsFoundType <> XDTOFactory.Type(TargetNamespace, "PhoneNumber") Then
				ErrorText = NStr("en = 'Contact information deserialize error, phone is awaited'");
			ElsIf ExpectedType = EnumFax AND IsFoundType <> XDTOFactory.Type(TargetNamespace, "FaxNumber") Then
				ErrorText = NStr("en = 'Contact information deserialize error, phone is awaited'");
			ElsIf ExpectedType = EnumerationAnother AND IsFoundType <> XDTOFactory.Type(TargetNamespace, "Other") Then
				ErrorText = NStr("en = 'An error occurred while deserializing the contact information, other is expected'");
			EndIf;
		EndIf;
		
		If ErrorText = Undefined Then
			// Read successfully
			Return Result;
		EndIf;
		
		// Check a mistake and return an extended information.
		If ConvertingResult = Undefined Then
			Raise ErrorText;
		ElsIf TypeOf(ConvertingResult) <> Type("Structure") Then
			ConvertingResult = New Structure;
		EndIf;
		ConvertingResult.Insert("ErrorText", ErrorText);
		
		// An empty object will be returned.
		Text = "";
	EndIf;
	
	If TypeOf(Text) = Type("ValueList") Then
		Presentation = "";
		IsNew = Text.Count() = 0;
	Else
		Presentation = String(Text);
		IsNew = IsBlankString(Text);
	EndIf;
	
	Result = XDTOFactory.Create(XDTOFactory.Type(TargetNamespace, "ContactInformation"));
	
	// Parsing
	If ExpectedType = EnumerationPhone Then
		If IsNew Then
			Result.Content = XDTOFactory.Create(XDTOFactory.Type(TargetNamespace, "PhoneNumber"));
		Else
			Result = DeserializationPhone(Text, Presentation, ExpectedType)
		EndIf;
		
	ElsIf ExpectedType = EnumFax Then
		If IsNew Then
			Result.Content = XDTOFactory.Create(XDTOFactory.Type(TargetNamespace, "FaxNumber"));
		Else
			Result = DeserializingFax(Text, Presentation, ExpectedType)
		EndIf;
		
	ElsIf ExpectedType = EnumEmailAddress Then
		If IsNew Then
			Result.Content = XDTOFactory.Create(XDTOFactory.Type(TargetNamespace, "Email"));
		Else
			Result = DeserializationOfOtherContactInformation(Text, Presentation, ExpectedType)
		EndIf;
		
	ElsIf ExpectedType = EnumerationWebPage Then
		If IsNew Then
			Result.Content = XDTOFactory.Create(XDTOFactory.Type(TargetNamespace, "WebSite"));
		Else
			Result = DeserializationOfOtherContactInformation(Text, Presentation, ExpectedType)
		EndIf;
		
	ElsIf ExpectedType = EnumerationAnother Then
		If IsNew Then
			Result.Content = XDTOFactory.Create(XDTOFactory.Type(TargetNamespace, "Other"));
		Else
			Result = DeserializationOfOtherContactInformation(Text, Presentation, ExpectedType)    
		EndIf;
		
	Else
		Raise NStr("en = 'Error of the contact information deserialize, the expected type is not specified'");
	EndIf;
	
	Return Result;
EndFunction

Function EventLogMonitorEvent() Export
	
	Return NStr("en = 'Contact information'", CommonUseClientServer.MainLanguageCode());
	
EndFunction

// Converts a row to XDTO phone contact information.
//
//      FieldsValues - String - serialized information, fields values.
//      Presentation - String - junior-senior presentation used to try parsing
//                               if FieldValues is empty.
//      ExpectedType  - EnumRef.ContactInformationTypes - optional type for control.
//
//  Returns:
//      XDTODataObject  - contact information.
//
Function DeserializationPhone(FieldsValues, Presentation = "", ExpectedType = Undefined) Export
	Return DeserializationPhoneFax(FieldsValues, Presentation, ExpectedType);
EndFunction

// Converts a row to XDTO Fax contact information.
//
//      FieldsValues - String - serialized information, fields values.
//      Presentation - String - junior-senior presentation used to try parsing
//                               if FieldValues is empty.
//      ExpectedType  - EnumRef.ContactInformationTypes - optional type for control.
//
//  Returns:
//      XDTODataObject  - contact information.
//
Function DeserializingFax(FieldsValues, Presentation = "", ExpectedType = Undefined) Export
	Return DeserializationPhoneFax(FieldsValues, Presentation, ExpectedType);
EndFunction

Function DeserializationPhoneFax(FieldsValues, Presentation = "", ExpectedType = Undefined)
	
	If ContactInformationManagementClientServer.IsContactInformationInXML(FieldsValues) Then
		// General format of a contact information.
		Return ContactInformationFromXML(FieldsValues, ExpectedType);
	EndIf;
	
	TargetNamespace = ContactInformationManagementClientServerReUse.TargetNamespace();
	
	If ExpectedType = Enums.ContactInformationTypes.Phone Then
		Data = XDTOFactory.Create(XDTOFactory.Type(TargetNamespace, "PhoneNumber"));
		
	ElsIf ExpectedType=Enums.ContactInformationTypes.Fax Then
		Data = XDTOFactory.Create(XDTOFactory.Type(TargetNamespace, "FaxNumber"));
		
	ElsIf ExpectedType=Undefined Then
		// Count as phone
		Data = XDTOFactory.Create(XDTOFactory.Type(TargetNamespace, "PhoneNumber"));
		
	Else
		Raise NStr("en = 'Contact information deserialize error, waiting for the phone or fax'");
	EndIf;
	
	Result = XDTOFactory.Create(XDTOFactory.Type(TargetNamespace, "ContactInformation"));
	Result.Content        = Data;
	
	// From the key-value pairs
	ValueListFields = Undefined;
	If TypeOf(FieldsValues)=Type("ValueList") Then
		ValueListFields = FieldsValues;
	ElsIf Not IsBlankString(FieldsValues) Then
		ValueListFields = ContactInformationManagementClientServer.ConvertStringToFieldList(FieldsValues);
	EndIf;
	
	PresentationField = "";
	If ValueListFields <> Undefined Then
		For Each FieldValue In ValueListFields Do
			Field = Upper(FieldValue.Presentation);
			
			If Field = "COUNTRYCODE" Then
				Data.CountryCode = FieldValue.Value;
				
			ElsIf Field = "CITYCODE" Then
				Data.CityCode = FieldValue.Value;
				
			ElsIf Field = "PHONENUMBER" Then
				Data.Number = FieldValue.Value;
				
			ElsIf Field = "Supplementary" Then
				Data.Supplementary = FieldValue.Value;
				
			ElsIf Field = "PRESENTATION" Then
				PresentationField = TrimAll(FieldValue.Value);
				
			EndIf;
			
		EndDo;
		
		// Presentation with priorities.
		If Not IsBlankString(Presentation) Then
			Result.Presentation = Presentation;
		Else
			Result.Presentation = PresentationField;
		EndIf;
		
		Return Result;
	EndIf;
	
	// Disassemble from presentation.
	
	// Digits groups separated by characters - not in figures: county, city, number, extension. 
	// The additional includes nonblank characters on the left and right.
	Position = 1;
	Data.CountryCode  = FindSubstringOfDigits(Presentation, Position);
	BeginCity = Position;
	
	Data.CityCode  = FindSubstringOfDigits(Presentation, Position);
	Data.Number      = FindSubstringOfDigits(Presentation, Position, " -");
	
	Supplementary = TrimAll(Mid(Presentation, Position));
	If Left(Supplementary, 1) = "," Then
		Supplementary = TrimL(Mid(Supplementary, 2));
	EndIf;
	If Upper(Left(Supplementary, 3 ))= "EXT" Then
		Supplementary = TrimL(Mid(Supplementary, 4));
	EndIf;
	If Upper(Left(Supplementary, 1 ))= "." Then
		Supplementary = TrimL(Mid(Supplementary, 2));
	EndIf;
	Data.Supplementary = TrimAll(Supplementary);
	
	// Correct possible errors.
	If IsBlankString(Data.Number) Then
		If Left(TrimL(Presentation),1)="+" Then
			// There was an attempt to explicitly specify country code, leave the country.
			Data.CityCode  = "";
			Data.Number      = ReduceDigits(Mid(Presentation, BeginCity));
			Data.Supplementary = "";
		Else
			Data.CountryCode  = "";
			Data.CityCode  = "";
			Data.Number      = Presentation;
			Data.Supplementary = "";
		EndIf;
	EndIf;
	
	Result.Presentation = Presentation;
	Return Result;
EndFunction

// Converts a contact information to XML kind.
//
// Parameters:
//    Data - String     - contact information description.
//           - XDTOObject - contact information description.
//           - Structure  - contact information description. Fields are expected:
//                 * FieldValues - String, Structure, ValuesList, Map - contact information fields.
//                 * Presentation - String - Presentation. It is used if you are
// unable to compute presentation from FieldValues (the Presentation field is absent in them).
//                 * Comment - String - comment. It is used in case it
//                                          was impossible to compute a comment from FieldValues
//                 * ContactInformationKind - CatalogRef.ContactInformationTypes, EnumRef.ContactInformationTypes,
//                                             Structure It is used in case you did not manage to compute the type from FieldValues.
//
// Returns:
//     Structure - contains fields:
//        * ContactInformationType - Listing.ContactInformationTypes
//        * DataXML               - String - text XML.
//
Function CastContactInformationXML(Val Data) Export
	If ItIsXMLString(Data) Then
		Return New Structure("DataXML, ContactInformationType",
			Data, ValueFromXMLString( XSLT_ContactInformationTypeByXMLString(Data) ));
		
	ElsIf TypeOf(Data) = Type("XDTODataObject") Then
		DataXML = ContactInformationXDTOVXML(Data);
		Return New Structure("DataXML, ContactInformationType",
			DataXML, ValueFromXMLString( XSLT_ContactInformationTypeByXMLString(DataXML) ));
		
	EndIf;
		
	// Wait for the structure
	Comment = Undefined;
	Data.Property("Comment", Comment);
	
	FieldsValues = Data.FieldsValues;
	If ItIsXMLString(FieldsValues) Then 
		// Perhaps you will need to predefine the comment.
		If Not IsBlankString(Comment) Then
			ContactInformationManagement.SetContactInformationComment(FieldsValues, Comment);
		EndIf;
		
		Return New Structure("DataXML, ContactInformationType",
			FieldsValues, ValueFromXMLString( XSLT_ContactInformationTypeByXMLString(FieldsValues) ));
		
	EndIf;
	
	// Collate FieldValues, ContactInformationKind, Presentation.
	TypeValuesFields = TypeOf(FieldsValues);
	If TypeValuesFields = Type("String") Then
		// Text from the key-value pairs
		XMLStringStructure = XSLT_KeyValueStringToStructure(FieldsValues)
		
	ElsIf TypeValuesFields = Type("ValueList") Then
		// Values list
		XMLStringStructure = XSLT_ValueListToStructure( ValueToXMLString(FieldsValues) );
		
	ElsIf TypeValuesFields = Type("Map") Then
		// Map
		XMLStringStructure = XSLT_MapToStructure( ValueToXMLString(FieldsValues) );
		
	Else
		// Wait for the structure
		XMLStringStructure = ValueToXMLString(FieldsValues);
		
	EndIf;
	
	// Collate by ContactInformationKind.
	ContactInformationType = TypeKindContactInformation(Data.ContactInformationKind);
	
	Result = New Structure("ContactInformationType, DataXML", ContactInformationType);
	
	AllTypes = Enums.ContactInformationTypes;
	If ContactInformationType = AllTypes.EmailAddress Then
		Result.DataXML = XSLT_StructureToEmailAddress(XMLStringStructure, Data.Presentation, Comment);
		
	ElsIf ContactInformationType = AllTypes.WebPage Then
		Result.DataXML = XSLT_StructureToWebPage(XMLStringStructure, Data.Presentation, Comment);
		
	ElsIf ContactInformationType = AllTypes.Phone Then
		Result.DataXML = XSLT_StructureToPhone(XMLStringStructure, Data.Presentation, Comment);
		
	ElsIf ContactInformationType = AllTypes.Fax Then
		Result.DataXML = XSLT_StructureToFax(XMLStringStructure, Data.Presentation, Comment);
		
	ElsIf ContactInformationType = AllTypes.Other Then
		Result.DataXML = XSLT_StructureToOther(XMLStringStructure, Data.Presentation, Comment);
		
	Else
		Raise NStr("en = 'Transformation parameters error, contact information type is not defined'");
		
	EndIf;
	
	Return Result;
EndFunction

// Converts XDTO contact information to XML.
//
//  Parameters:
//      XDTOObjectInformation - XDTODataObject - contact information.
//
// Returns:
//      String - result of converting in the XML format.
//
Function ContactInformationXDTOVXML(XDTOObjectInformation) Export
	
	Record = New XMLWriter;
	Record.SetString(New XMLWriterSettings(, , False, False, ""));
	
	If XDTOObjectInformation <> Undefined Then
		XDTOFactory.WriteXML(Record, XDTOObjectInformation);
	EndIf;
	
	Result = StrReplace(Record.Close(), Chars.LF, "&#10;");
	
	Return Result;
	
EndFunction

// Returns presentation of the contact information generated from the address in the XML format.
//
// Parameters:
//   XMLString    -  String - Address in the XML format.
//   ContactInformationFormat  - String             - If ADDRCLASS is specified, then district
// and urban district are not included in the addresses presentation.
//    ContactInformationKind - Structure - additional parameters of forming presentation for addresses:
//      * Type - String - The contact information type;
//      * IncludeCountriesToPresentation - Boolean - address country will be included to the presentation;
//      * AddressFormat                 - String - If ADDRCLASS is specified, then district
// and urban district are not included in the addresses presentation.
// Returns:
//      String - generated presentation.
//
Function PresentationContactInformation(Val XMLString, Val ContactInformationFormat) Export
	
	IsRow = TypeOf(XMLString) = Type("String");
	If IsRow AND Not ContactInformationManagementClientServer.IsContactInformationInXML(XMLString) Then
		// The previous format of fields values, return the row itself.
		Return XMLString;
	EndIf;
	
	Kind = New Structure("Type,IncludeCountryInPresentation,AddressFormat", "", False, "AC");
	If ContactInformationFormat = Undefined Then
		Kind.Type = ContactInformationType(?(IsRow, XMLString, ContactInformationFromXML(XMLString)));
	Else
		FillPropertyValues(Kind, ContactInformationFormat);
	EndIf;
	
	XDTODataObject = ?(IsRow, ContactInformationFromXML(XMLString), XMLString);
	
	Return GeneratePresentationContactInformation(XDTODataObject, Kind);
	
EndFunction

// Generates and returns a contact information presentation.
//
// Parameters:
//   Information    - XDTOObject, Row - contact information.
//   InformationKind - CatalogRef.ContactInformationTypes, Structure - parameters to generate a presentation.
//   AddressFormat  - String             - If ADDRCLASS is specified, then district
// and urban district are not included in the addresses presentation.
//
// Returns:
//      String - generated presentation.
//
Function GeneratePresentationContactInformation(Information, InformationKind) Export
	
	If TypeOf(Information) = Type("XDTODataObject") Then
		If Information.Content = Undefined Then
			Return Information.Presentation;
		EndIf;
		
		TargetNamespace = ContactInformationManagementClientServerReUse.TargetNamespace();
		InformationType    = Information.Content.Type();
		If InformationType = XDTOFactory.Type(TargetNamespace, "PhoneNumber") Then
			PresentationPhone = PresentationPhone(Information.Content);
			Return ?(IsBlankString(PresentationPhone), Information.Presentation, PresentationPhone);
			
		ElsIf InformationType = XDTOFactory.Type(TargetNamespace, "FaxNumber") Then
			FaxPresentation = PresentationPhone(Information.Content);
			Return ?(IsBlankString(PresentationPhone), Information.Presentation, FaxPresentation);
			
		ElsIf InformationType = XDTOFactory.Type(TargetNamespace, "Email") Then
			Return String(Information.Content.Value);
		EndIf;
		
		// Endcap for other types
		If TypeOf(InformationType) = Type("XDTODataObject") AND InformationType.Properties.Get("Value") <> Undefined Then
			Return String(Information.Content.Value);
		EndIf;
		
		Return String(Information.Content);
	EndIf;
	
	Return TrimAll(Information);
EndFunction

Function PresentationPhone(XDTOData) Export
	
	Return ContactInformationManagementClientServer.GeneratePhonePresentation(
		ReduceDigits(XDTOData.CountryCode), 
		XDTOData.AreaCode,
		XDTOData.Number,
		XDTOData.Extension,
		"");
		
EndFunction

//  Returns fax presentation.
//
//  Parameters:
//      XDTOData    - XDTODataObject - contact information.
//      InformationKind - CatalogRef.ContactInformationTypes - ref to the corresponding contact information kind.
//
// Returns:
//      String - presentation.
//
Function FaxPresentation(XDTOData, InformationKind = Undefined) Export
	Return ContactInformationManagementClientServer.GeneratePhonePresentation(
		ReduceDigits(XDTOData.CountryCode), 
		XDTOData.CityCode,
		XDTOData.Number,
		XDTOData.Supplementary,
		"");
EndFunction

// Returns the first subrow from digits in the row. The BeginningPosition parameter is substituted for the first non-digit.
//
Function FindSubstringOfDigits(Text, BeginningPosition = Undefined, PermissibleExceptDigits = "")
	
	If BeginningPosition = Undefined Then
		BeginningPosition = 1;
	EndIf;
	
	Result = "";
	PositionEnd = StrLen(Text);
	SearchBeginning  = True;
	
	While BeginningPosition <= PositionEnd Do
		Char = Mid(Text, BeginningPosition, 1);
		IsDigit = Char >= "0" AND Char <= "9";
		
		If SearchBeginning Then
			If IsDigit Then
				Result = Result + Char;
				SearchBeginning = False;
			EndIf;
		Else
			If IsDigit Or Find(PermissibleExceptDigits, Char) > 0 Then
				Result = Result + Char;    
			Else
				Break;
			EndIf;
		EndIf;
		
		BeginningPosition = BeginningPosition + 1;
	EndDo;
	
	// Remove possible pending delimiters left.
	Return ReduceDigits(Result, PermissibleExceptDigits, False);
	
EndFunction

Function ReduceDigits(Text, PermissibleExceptDigits = "", Direction = True)
	
	Length = StrLen(Text);
	If Direction Then
		// Abbreviation left
		IndexOf = 1;
		End  = 1 + Length;
		Step    = 1;
	Else
		// Abbreviation right    
		IndexOf = Length;
		End  = 0;
		Step    = -1;
	EndIf;
	
	While IndexOf <> End Do
		Char = Mid(Text, IndexOf, 1);
		IsDigit = (Char >= "0" AND Char <= "9") Or Find(PermissibleExceptDigits, Char) = 0;
		If IsDigit Then
			Break;
		EndIf;
		IndexOf = IndexOf + Step;
	EndDo;
	
	If Direction Then
		// Abbreviation left
		Return Right(Text, Length - IndexOf + 1);
	EndIf;
	
	// Abbreviation right
	Return Left(Text, IndexOf);
	
EndFunction

// Converts a row to XDTO other contact information.
//
// Parameters:
//   FieldsValues - String - serialized information, fields values.
//   Presentation - String - junior-senior presentation used to try parsing if FieldValues is empty.
//   ExpectedType  - EnumRef.ContactInformationTypes - optional type for control.
//
// Returns:
//   XDTODataObject  - contact information.
//
Function DeserializationOfOtherContactInformation(FieldsValues, Presentation = "", ExpectedType = Undefined) Export
	
	If ContactInformationManagementClientServer.IsContactInformationInXML(FieldsValues) Then
		// General format of a contact information.
		Return ContactInformationFromXML(FieldsValues, ExpectedType);
	EndIf;
	
	TargetNamespace = ContactInformationManagementClientServerReUse.TargetNamespace();
	Result = XDTOFactory.Create(XDTOFactory.Type(TargetNamespace, "ContactInformation"));
	Result.Presentation = Presentation;
	
	If ExpectedType = Enums.ContactInformationTypes.EmailAddress Then
		Result.Content = XDTOFactory.Create(XDTOFactory.Type(TargetNamespace, "Email"));
		
	ElsIf ExpectedType = Enums.ContactInformationTypes.WebPage Then
		Result.Content = XDTOFactory.Create(XDTOFactory.Type(TargetNamespace, "WebSite"));
		
	ElsIf ExpectedType = Enums.ContactInformationTypes.Other Then
		Result.Content = XDTOFactory.Create(XDTOFactory.Type(TargetNamespace, "Other"));
		
	ElsIf ExpectedType <> Undefined Then
		Raise NStr("en = 'Contact information deserialize error, another type is awaited'");
		
	EndIf;
	
	Result.Content.Value = Presentation;
	
	Return Result;
	
EndFunction

#Region ServiceProceduresAndFunctionsBySXSLTWork

// Converts text with Key = Value pairs divided by line breaks (see address format) in XML.
// In case there are repeated keys, they are all included into the result, but the last one will be used during
// deserialization (a special feature of a platform serializer).
//
// Parameters:
//    Text - String - Key = Value pairs.
//
// Returns:
//     String  - XML of a serialized structure.
//
Function XSLT_KeyValueStringToStructure(Val Text) 
	
	Converter = ContactInformationManagementServiceReUse.XSLT_KeyValueStringToStructure();
	Return Converter.TransformFromString(XSLT_NodeParameterRows(Text));
	
EndFunction

// Converts values list to structure. Presentation is converted to key.
//
// Parameters:
//    Text - String - serialized values list.
//
// Returns:
//    String - conversion result
//
Function XSLT_ValueListToStructure(Text)
	
	Converter = ContactInformationManagementServiceReUse.XSLT_ValueListToStructure();
	Return Converter.TransformFromString(Text);
	
EndFunction

// Converts match to structure. Key is converted to key, value - in value.
//
// Parameters:
//    Text - String - serialized match.
//
// Returns:
//    String - conversion result
//
Function XSLT_MapToStructure(Text)
	
	Converter = ContactInformationManagementServiceReUse.XSLT_MapToStructure();
	Return Converter.TransformFromString(Text);
	
EndFunction

// Converts structure to XML of contact information.
//
// Parameters:
//    Text         - String - serialized structure.
//    Presentation - String - optional presentation. Used only if the structure does
//                             not contain a presentation field.
//    Comment   - String - optional comment. Used only if the structure does not contain a comment field.
//
// Returns:
//    String - Contact information XML.
//
Function XSLT_StructureToEmailAddress(Val Text, Val Presentation = Undefined, Val Comment = Undefined)
	
	Converter = ContactInformationManagementServiceReUse.XSLT_StructureToEmailAddress();
	Return XSLT_PresentationAndCommentControl(
		XSLT_RowSimpleTypeValueControl(Converter.TransformFromString(Text), Presentation), 
		Presentation, Comment);
		
EndFunction

// Converts structure to XML of contact information.
//
// Parameters:
//    Text         - String - serialized structure.
//    Presentation - String - optional presentation. Used only if the structure does
//                             not contain a presentation field.
//    Comment   - String - optional comment. Used only if the structure does not contain a comment field.
//
// Returns:
//    String - Contact information XML.
//
Function XSLT_StructureToWebPage(Val Text, Val Presentation = Undefined, Val Comment = Undefined)
	Converter = ContactInformationManagementServiceReUse.XSLT_StructureToWebPage();
	
	Return XSLT_PresentationAndCommentControl(
		XSLT_RowSimpleTypeValueControl( Converter.TransformFromString(Text), Presentation),
		Presentation, Comment);
		
EndFunction

// Converts structure to XML of contact information.
//
// Parameters:
//    Text         - String - serialized structure.
//    Presentation - String - optional presentation. Used only if the structure does
//                             not contain a presentation field.
//    Comment   - String - optional comment. Used only if the structure does not contain a comment field.
//
// Returns:
//    String - Contact information XML.
//
Function XSLT_StructureToPhone(Val Text, Val Presentation = Undefined, Val Comment = Undefined)
	Converter = ContactInformationManagementServiceReUse.XSLT_StructureToPhone();
	Return XSLT_PresentationAndCommentControl(
		Converter.TransformFromString(Text),
		Presentation, Comment);
EndFunction

// Converts structure to XML of contact information.
//
// Parameters:
//    Text         - String - serialized structure.
//    Presentation - String - optional presentation. Used only if the structure does
//                             not contain a presentation field.
//    Comment   - String - optional comment. Used only if the structure does not contain a comment field.
//
// Returns:
//    String - Contact information XML.
//
Function XSLT_StructureToFax(Val Text, Val Presentation = Undefined, Val Comment = Undefined)
	
	Converter = ContactInformationManagementServiceReUse.XSLT_StructureToFax();
	Return XSLT_PresentationAndCommentControl(
		Converter.TransformFromString(Text),
		Presentation, Comment);
		
EndFunction

// Converts structure to XML of contact information.
//
// Parameters:
//    Text         - String - serialized structure.
//    Presentation - String - optional presentation. Used only if the structure does
//                             not contain a presentation field.
//    Comment   - String - optional comment. Used only if the structure does not contain a comment field.
//
// Returns:
//    String - Contact information XML.
//
Function XSLT_StructureToOther(Val Text, Val Presentation = Undefined, Val Comment = Undefined)
	
	Converter = ContactInformationManagementServiceReUse.XSLT_StructureToOther();
	Return XSLT_PresentationAndCommentControl(
		XSLT_RowSimpleTypeValueControl( Converter.TransformFromString(Text), Presentation),
		Presentation, Comment);
		
EndFunction

// Sets a presentation and a comment in the contact information if they are not filled in.
//
// Parameters:
//    Text         - String - serialized structure.
//    Presentation - String - optional presentation. Used only if the structure does
//                             not contain a presentation field.
//    Comment   - String - optional comment. Used only if the structure does not contain a comment field.
//
// Returns:
//    String - Contact information XML.
//
Function XSLT_PresentationAndCommentControl(Val Text, Val Presentation = Undefined, Val Comment = Undefined)
	
	If Presentation = Undefined AND Comment = Undefined Then
		Return Text;
	EndIf;
	
	XSLT_Text = New TextDocument;
	XSLT_Text.AddLine("
		|<xsl:stylesheet version=""1.0"" xmlns:xsl=""http://www.w3.org/1999/XSL/Transform""
		|  xmlns:tns=""http://www.v8.1c.ru/ssl/contactinfo""
		|  xmlns=""http://www.v8.1c.ru/ssl/contactinfo"" 
		|>
		|  <xsl:output method=""xml"" omit-xml-declaration=""yes"" indent=""yes"" encoding=""utf-8""/>
		|
		|  <xsl:template match=""node() | @*"">
		|    <xsl:copy>
		|      <xsl:apply-templates select=""node() | @*"" />
		|    </xsl:copy>
		|  </xsl:template>
		|");
		
	If Presentation <> Undefined Then
		XSLT_Text.AddLine("
		|  <xsl:template match=""tns:ContactInformation/@Presentation"">
		|    <xsl:attribute name=""Presentation"">
		|      <xsl:choose>
		|        <xsl:when test="".=''"">" + NormalizedXMLRow(Presentation) + "</xsl:when>
		|        <xsl:otherwise>
		|          <xsl:value-of select="".""/>
		|        </xsl:otherwise>
		|      </xsl:choose>
		|    </xsl:attribute>
		|  </xsl:template>
		|");
	EndIf;
	
	If Comment <> Undefined Then
		XSLT_Text.AddLine("
		|  <xsl:template match=""tns:ContactInformation/tns:Comment"">
		|    <xsl:element name=""Comment"">
		|      <xsl:choose>
		|        <xsl:when test="".=''"">" + NormalizedXMLRow(Comment) + "</xsl:when>
		|        <xsl:otherwise>
		|          <xsl:value-of select="".""/>
		|        </xsl:otherwise>
		|      </xsl:choose>
		|    </xsl:element>
		|  </xsl:template>
		|");
	EndIf;
		XSLT_Text.AddLine("
		|</xsl:stylesheet>
		|");
		
	Converter = New XSLTransform;
	Converter.LoadFromString( XSLT_Text.GetText() );
	
	Return Converter.TransformFromString(Text);
EndFunction

// Sets to the Content contact information.Value to passed presentation.
// If Presentation equals to undefined, then it does nothing. Otherwise, checks for emptiness.
// Content. If there is nothing there and attribute Content.Value empty, then set the presentation value to the content.
//
// Parameters:
//    Text         - String - Contact information XML.
//    Presentation - String - set presentation.
//
// Returns:
//    String - Contact information XML.
//
Function XSLT_RowSimpleTypeValueControl(Val Text, Val Presentation)
	
	If Presentation = Undefined Then
		Return Text;
	EndIf;
	
	Converter = New XSLTransform;
	Converter.LoadFromString("
		|<xsl:stylesheet version=""1.0"" xmlns:xsl=""http://www.w3.org/1999/XSL/Transform""
		|  xmlns:tns=""http://www.v8.1c.ru/ssl/contactinfo""
		|>
		|  <xsl:output method=""xml"" omit-xml-declaration=""yes"" indent=""yes"" encoding=""utf-8""/>
		|  
		|  <xsl:template match=""node() | @*"">
		|    <xsl:copy>
		|      <xsl:apply-templates select=""node() | @*"" />
		|    </xsl:copy>
		|  </xsl:template>
		|  
		|  <xsl:template match=""tns:ContactInformation/tns:Content/@Value"">
		|    <xsl:attribute name=""Value"">
		|      <xsl:choose>
		|        <xsl:when test="".=''"">" + NormalizedXMLRow(Presentation) + "</xsl:when>
		|        <xsl:otherwise>
		|          <xsl:value-of select="".""/>
		|        </xsl:otherwise>
		|      </xsl:choose>
		|    </xsl:attribute>
		|  </xsl:template>
		|
		|</xsl:stylesheet>
		|");
	
	Return Converter.TransformFromString(Text);
EndFunction

// Returns the XML fragment to substitute the <Node>Row<Node> row.
//
// Parameters:
//    Text       - String - insert into XML.
//    ItemName - String - optional name for an external node.
//
// Returns:
//    String - resulting XML.
//
Function XSLT_NodeParameterRows(Val Text, Val ItemName = "ExternalParamNode")
	
	// Through xml record for special character masking.
	Record = New XMLWriter;
	Record.SetString();
	Record.WriteStartElement(ItemName);
	Record.WriteText(Text);
	Record.WriteEndElement();
	Return Record.Close();
	
EndFunction

// Converts the XML text of the contact information to the type enumeration.
//
// Parameters:
//    Text - String - source XML.
//
// Returns:
//    String - serialized value of the ContactInformation enumeration.
//
Function XSLT_ContactInformationTypeByXMLString(Val Text)
	
	Converter = ContactInformationManagementServiceReUse.XSLT_ContactInformationTypeByXMLString();
	Return Converter.TransformFromString(TrimL(Text));
	
EndFunction

//  Returns a flag showing whether it is an XML text
//
//  Parameters:
//      Text - String - checked text.
//
// Returns:
//      Boolean - checking result.
//
Function ItIsXMLString(Text)
	
	Return TypeOf(Text) = Type("String") AND Left(TrimL(Text),1) = "<";
	
EndFunction

// Deserializer of types known to platform.
Function ValueFromXMLString(Val Text)
	
	XMLReader = New XMLReader;
	XMLReader.SetString(Text);
	Return XDTOSerializer.ReadXML(XMLReader);
	
EndFunction

// Serializer of types known to platform.
Function ValueToXMLString(Val Value)
	
	XMLWriter = New XMLWriter;
	XMLWriter.SetString(New XMLWriterSettings(, , False, False, ""));
	XDTOSerializer.WriteXML(XMLWriter, Value, XMLTypeAssignment.Explicit);
	// Platform serializer helps to write a line break to the attributes value.
	Return StrReplace(XMLWriter.Close(), Chars.LF, "&#10;");
	
EndFunction

// Returns the corresponding ContactInformationTypes enumeration value by the XML row.
//
// Parameters:
//    XMLString - Row describing a contact information.
//
// Returns:
//     EnumRef.ContactInformationTypes - result.
//
Function ContactInformationType(Val XMLString) Export
	Return ValueFromXMLString( XSLT_ContactInformationTypeByXMLString(XMLString) );
EndFunction

// To work with attributes containing line breaks.
//
// Parameters:
//     Text - String - Corrected XML row.
//
// Returns:
//     String - Normalized row.
//
Function MultipageXMLRow(Val Text)
	
	Return StrReplace(Text, Chars.LF, "&#10;");
	
EndFunction

// Prepares the structure to include it in the XML text removing special characters.
//
// Parameters:
//     Text - String - Corrected XML row.
//
// Returns:
//     String - Normalized row.
//
Function NormalizedXMLRow(Val Text)
	
	Result = StrReplace(Text,     """", "&quot;");
	Result = StrReplace(Result, "&",  "&amp;");
	Result = StrReplace(Result, "'",  "&apos;");
	Result = StrReplace(Result, "<",  "&lt;");
	Result = StrReplace(Result, ">",  "&gt;");
	Return MultipageXMLRow(Result);
	
EndFunction

#EndRegion

#EndRegion
