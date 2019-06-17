
Procedure Filling(FillingData, FillingText, StandardProcessing)
	
	GLAccount					= Catalogs.DefaultGLAccounts.GetDefaultGLAccount("TaxPayable");
	GLAccountForReimbursement	= Catalogs.DefaultGLAccounts.GetDefaultGLAccount("TaxRefund");	
	
EndProcedure
