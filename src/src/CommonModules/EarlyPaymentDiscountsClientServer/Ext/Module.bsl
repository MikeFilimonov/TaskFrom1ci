#Region Public

// Generates hyperlink label on Credit note
//
Function CreditNotePresentation(Date, Number) Export
	
	Return StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en = 'Credit note No. %1 dated %2'"),
		ObjectPrefixationClientServer.GetNumberForPrinting(Number, True, True),
		Format(Date, "DLF=D"));
	
EndFunction
	
// Generates hyperlink label on Debit note
//
Function DebitNotePresentation(Date, Number) Export
	
	Return StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en = 'Debit note No. %1 dated %2'"),
		ObjectPrefixationClientServer.GetNumberForPrinting(Number, True, True),
		Format(Date, "DLF=D"));
	
EndFunction

#EndRegion