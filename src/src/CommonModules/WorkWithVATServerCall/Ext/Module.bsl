#Region ProgramInterface 

Function GetSubordinateTaxInvoice(BasisDocument, Received = False,  Advance = False) Export
	Return WorkWithVAT.GetSubordinateTaxInvoice(BasisDocument, Received,  Advance);
EndFunction

Function CheckForTaxInvoiceUse(Date, Company, Cancel = False) Export
	
	Policy = InformationRegisters.AccountingPolicy.GetAccountingPolicy(Date, Company);
	If Policy.PostVATEntriesBySourceDocuments Then
		CommonUseClientServer.MessageToUser(
			StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Company %1 doesn''t use tax invoices at %2 (specify this option in accounting policy)'"),
				Company,
				Format(Date, "DLF=D")),,,,
			Cancel);
	EndIf;
	
EndFunction

// Check the ability to enter the Advance payment invoice
//
// Parameters:
//	Date - Date - Check date
//	Company - CatalogRef.Companies - Company for check
//	Cancel - Boolean - For cancel posting document
//	
Procedure CheckForAdvancePaymentInvoiceUse(Date, Company, Cancel = False) Export
	
	Policy = InformationRegisters.AccountingPolicy.GetAccountingPolicy(Date, Company);
	If Policy.PostAdvancePaymentsBySourceDocuments Then
		CommonUseClientServer.MessageToUser(
			StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Company %1 doesn''t use Advance payment invoices at %2 (specify this option in accounting policy)'"),
				Company,
				Format(Date, "DLF=D")),,,,
			Cancel);
	EndIf;
	
EndProcedure

#EndRegion