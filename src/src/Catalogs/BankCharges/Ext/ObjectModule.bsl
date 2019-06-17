#Region EventHandlers

Procedure Filling(FillingData, FillingText, StandardProcessing)
	
	GLAccount			= Catalogs.DefaultGLAccounts.GetDefaultGLAccount("BankAccount");
	GLExpenseAccount	= Catalogs.DefaultGLAccounts.GetDefaultGLAccount("Expenses");

EndProcedure

#EndRegion