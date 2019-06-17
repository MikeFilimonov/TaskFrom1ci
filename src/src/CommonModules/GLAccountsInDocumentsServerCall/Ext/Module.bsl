
#Region Public

Procedure FillProductGLAccounts(StructureData, GLAccounts, GLAccountsForFilling = Undefined) Export

	If GLAccountsForFilling = Undefined Then
		GLAccountsForFilling = GLAccountsInDocumentsClientServer.GetGLAccountsStructure(StructureData);
	EndIf;
	FillPropertyValues(GLAccountsForFilling, GLAccounts[StructureData.Products]);
	GLAccountsInDocumentsClientServer.FillProductGLAccountsDescription(StructureData, GLAccountsForFilling);
	
EndProcedure

Function GetGLAccountsDescription(FillingData) Export

	GLAccounts = "";
	GLAccountsFilled = True;
	
	UnfilledAccountPresentation = GLAccountsInDocumentsClientServer.GetEmptyGLAccountPresentation();
	FirstAccount = True;
	For Each Account In FillingData Do
		If ValueIsFilled(Account.Value) Then
			GLAccountPresentation = CommonUse.ObjectAttributeValue(Account.Value, "Code");
			GLAccounts = GLAccounts + ?(FirstAccount, "", ", ") + GLAccountPresentation;
		Else
			GLAccounts		= GLAccounts + UnfilledAccountPresentation;
			GLAccountsFilled	= False;
		EndIf;
		
		If FirstAccount Then
			FirstAccount = False;
			UnfilledAccountPresentation = ", " + UnfilledAccountPresentation;
		EndIf;
		
	EndDo;
	
	FillingData.Insert("GLAccounts",		GLAccounts);
	FillingData.Insert("GLAccountsFilled",	GLAccountsFilled);
	
	Return FillingData;
	
EndFunction

#EndRegion
