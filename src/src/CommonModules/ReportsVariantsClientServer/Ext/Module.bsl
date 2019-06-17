////////////////////////////////////////////////////////////////////////////////
// Subsystem "Report options" (client, server).
// 
// Ecxecuted on client and server.
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProceduresAndFunctions

// Presentation of the subsystem. Used when recording into the event log and in other places.
Function SubsystemDescription(LanguageCode) Export
	Return NStr("en = 'Report options'", ?(LanguageCode = Undefined, CommonUseClientServer.MainLanguageCode(), LanguageCode));
EndFunction

// Presentation of the importance group.
Function PresentationSeeAlso() Export
	Return NStr("en = 'See also'");
EndFunction

// Presentation of the importance group.
Function PresentationImportant() Export
	Return NStr("en = 'Important'");
EndFunction

// Name of the notification event for changing the report option.
Function EventNameOptionChanging() Export
	Return SubsystemFullName() + ".OptionChanging";
EndFunction

// Full name of the subsystem.
Function SubsystemFullName() Export
	Return "StandardSubsystems.ReportsVariants";
EndFunction

// Delimiter that is used when storing several items in one string attribute.
Function StorageDelimiter() Export
	Return Chars.LF;
EndFunction

// Delimiter that is used to display some items in the interface.
Function SeparatorPresentation() Export
	Return ", ";
EndFunction

// Converts a search string into words array with unique values and sorted by descending length.
Function DecomposeSearchStringIntoWordsArray(SearchString) Export
	WordsAndTheirLength = New ValueList;
	StringLength = StrLen(SearchString);
	
	Word = "";
	WordLength = 0;
	QuoteIsOpen = False;
	For CharacterNumber = 1 To StringLength Do
		CharCode = CharCode(SearchString, CharacterNumber);
		If CharCode = 34 Then // 34 - double quote "".
			QuoteIsOpen = Not QuoteIsOpen;
		ElsIf QuoteIsOpen
			Or (CharCode >= 48 AND CharCode <= 57) // Digits
			Or (CharCode >= 65 AND CharCode <= 90) // upper case Latin characters
			Or (CharCode >= 97 AND CharCode <= 122) // lower case Latin characters
			Or (CharCode >= 1040 AND CharCode <= 1103) // Cyrillic alphabet
			Or CharCode = 95 Then // Character "_"
			Word = Word + Char(CharCode);
			WordLength = WordLength + 1;
		ElsIf Word <> "" Then
			If WordsAndTheirLength.FindByValue(Word) = Undefined Then
				WordsAndTheirLength.Add(Word, Format(WordLength, "ND=3; NLZ="));
			EndIf;
			Word = "";
			WordLength = 0;
		EndIf;
	EndDo;
	
	If Word <> "" AND WordsAndTheirLength.FindByValue(Word) = Undefined Then
		WordsAndTheirLength.Add(Word, Format(WordLength, "ND=3; NLZ="));
	EndIf;
	
	WordsAndTheirLength.SortByPresentation(SortDirection.Desc);
	
	Return WordsAndTheirLength.UnloadValues();
EndFunction

#EndRegion

#Region InternalInterface

// Adds Key to Structure if it is missing.
//
// Parameters:
//   Structure - Structure - Added structure.
//   Key      - String - Property name.
//   Value  - Arbitrary - Optional. Property value if it is missing in the structure.
//
Procedure AddKeyToStructure(Structure, Key, Value = Undefined) Export
	If Not Structure.Property(Key) Then
		Structure.Insert(Key, Value);
	EndIf;
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

// Turns report type into string ID.
Function ReportTypeAsString(Val ReportType, Val Report = Undefined) Export
	
	ReportTypeType = TypeOf(ReportType);
	
	If ReportTypeType = Type("String") Then
		Return ReportType;
	ElsIf ReportTypeType = Type("EnumRef.ReportsTypes") Then
		
		If ReportType = PredefinedValue("Enum.ReportsTypes.Internal") Then
			Return "Internal";
		ElsIf ReportType = PredefinedValue("Enum.ReportsTypes.Additional") Then
			Return "Additional";
		ElsIf ReportType = PredefinedValue("Enum.ReportsTypes.External") Then
			Return "External";
		Else
			Return Undefined;
		EndIf;
		
	Else
		If ReportTypeType <> Type("Type") Then
			ReportType = TypeOf(Report);
		EndIf;
		
		If ReportType = Type("CatalogRef.MetadataObjectIDs") Then
			Return "Internal";	
		ElsIf ReportType = Type("String") Then
			Return "External";
		Else
			Return "Additional";
		EndIf;
		
	EndIf;
	
EndFunction

// Returns an additional report reference type.
Function AdditionalReportRefType() Export
	#If Server OR ThickClientOrdinaryApplication OR ExternalConnection Then
		Exist = CommonUse.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors");
	#Else
		Exist = CommonUseClient.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors");
	#EndIf
	
	If Exist Then
		Name = "AdditionalReportsAndDataProcessors";
		
		Return Type("CatalogRef." + Name);
	EndIf;
	
	Return Undefined;
	
EndFunction

#EndRegion