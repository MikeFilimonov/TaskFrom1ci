#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

Procedure Filling(FillingData, FillingText, StandardProcessing)
	
	If TypeOf(FillingData) = Type("CatalogRef.Counterparties") Or TypeOf(FillingData) = Type("CatalogRef.Companies") Then
		
		StandardProcessing = False;
		
		Owner				= FillingData;
		CashCurrency		= Constants.FunctionalCurrency.Get();
		AccountType			= "Transactional";
		MonthOutputOption	= Enums.MonthOutputTypesInDocumentDate.Number;
		
	EndIf;
	
	GLAccount = Catalogs.DefaultGLAccounts.GetDefaultGLAccount("BankAccount");
	
EndProcedure

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If TypeOf(Owner) = Type("CatalogRef.Companies") Then
		CheckedAttributes.Add("GLAccount");
	EndIf;
	
	If IsBlankString(IBAN)
		AND IsBlankString(AccountNo) Then
		
		CommonUseClientServer.MessageToUser(
			NStr("en = 'At least one of the fields must be filled in: IBAN, Account number'"),,,,
			Cancel);
		
	EndIf;
	
	If NOT IsBlankString(IBAN) Then
		
		MessageText = "";
		
		If NOT StringFunctionsClientServer.OnlyRomanInString(IBAN,, "0123456789") Then
			MessageText = NStr("en = 'This field can contain only latin letters and numbers.'");
		EndIf;
		
		If StrLen(IBAN) < 12 Then
			
			If NOT IsBlankString(MessageText) Then
				MessageText = MessageText + Chars.LF;
			EndIf;
			
			MessageText = MessageText + NStr("en = 'The minimum length of IBAN is 12 chars.'");
			
		EndIf;
		
		If NOT StringFunctionsClientServer.OnlyRomanInString(Left(IBAN, 2)) Then
			
			If NOT IsBlankString(MessageText) Then
				MessageText = MessageText + Chars.LF;
			EndIf;
			
			MessageText = MessageText + NStr("en = 'The first two IBAN chars must be latin letters.'");
			
		EndIf;
		
		If NOT StringFunctionsClientServer.OnlyNumbersInString(Mid(IBAN, 3, 2)) Then
			
			If NOT IsBlankString(MessageText) Then
				MessageText = MessageText + Chars.LF;
			EndIf;
			
			MessageText = MessageText + NStr("en = 'The third and the fourth IBAN chars must be numbers.'");
			
		EndIf;
		
		If NOT IsBlankString(MessageText) Then
			
			MessageText = NStr("en = 'IBAN is not valid.'")
							+ " " + MessageText;
							
			CommonUseClientServer.MessageToUser(
				MessageText,,
				"IBAN",
				"Object",
				Cancel);
		
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure BeforeDelete(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	ClearAttributeMainBankAccount();
	
EndProcedure

Procedure BeforeWrite(Cancel)
	
	IsCompanyAccount = TypeOf(Owner) = Type("CatalogRef.Companies");
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

Procedure GenerateDescription() Export
	
	Description = StrTemplate(
		NStr("en = '%1, in %2'"),
		TrimAll(AccountNo),
		Bank);
	
EndProcedure

Procedure ClearAttributeMainBankAccount()
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	Counterparties.Ref AS Ref
		|FROM
		|	Catalog.Counterparties AS Counterparties
		|WHERE
		|	Counterparties.BankAccountByDefault = &BankAccount
		|
		|UNION ALL
		|
		|SELECT
		|	Companies.Ref
		|FROM
		|	Catalog.Companies AS Companies
		|WHERE
		|	Companies.BankAccountByDefault = &BankAccount";
	
	Query.SetParameter("BankAccount", Ref);
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		CatalogObject = Selection.Ref.GetObject();
		CatalogObject.BankAccountByDefault = Undefined;
		CatalogObject.Write();
		
	EndDo;
	
EndProcedure

#EndRegion

#EndIf