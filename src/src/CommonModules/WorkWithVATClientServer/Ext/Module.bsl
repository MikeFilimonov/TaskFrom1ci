#Region ProgramInterface

// Generates hyperlink label on Sales invoice note
//
Function TaxInvoicePresentation(Date, Number) Export

	Return StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en = 'Tax invoice No. %1 dated %2'"),
		ObjectPrefixationClientServer.GetNumberForPrinting(Number, True, True),
		Format(Date, "DLF=D"));

EndFunction
	
// Generates hyperlink label on documents
//
Function AdvancePaymentInvoicePresentation(Date, Number) Export

	Return StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en = 'Advance payment invoice No. %1 dated %2'"),
		ObjectPrefixationClientServer.GetNumberForPrinting(Number, True, True),
		Format(Date, "DLF=D"));

EndFunction

#EndRegion