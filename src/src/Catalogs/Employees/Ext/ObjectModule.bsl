#Region EventHandlers

Procedure Filling(FillingData, FillingText, StandardProcessing)
	
	If Not IsFolder	Then
		
		SettlementsHumanResourcesGLAccount	= Catalogs.DefaultGLAccounts.GetDefaultGLAccount("PayrollPayable");
		AdvanceHoldersGLAccount				= Catalogs.DefaultGLAccounts.GetDefaultGLAccount("AdvanceHoldersPayable");
		OverrunGLAccount					= Catalogs.DefaultGLAccounts.GetDefaultGLAccount("AdvanceHolders");
		
	EndIf;
	
EndProcedure

#EndRegion