#Region EventHandlers

Procedure Filling(FillingData, FillingText, StandardProcessing)
	
	If Not IsFolder Then
		GLAccount			= Catalogs.DefaultGLAccounts.GetDefaultGLAccount("FixedAssets");
		DepreciationAccount = Catalogs.DefaultGLAccounts.GetDefaultGLAccount("FixedAssetsDepreciation");
	EndIf;
	
EndProcedure

#EndRegion