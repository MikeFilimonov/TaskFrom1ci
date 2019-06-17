
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	GLAccount = Parameters.GLAccount;
	Ref = Parameters.Ref;
	CompanyOwner = TypeOf(Ref.Owner) = Type("CatalogRef.Companies");
	
	If CancelGLAccountChange(Ref) Then
		Items.GLAccountsGroup.ToolTip = NStr("en = 'Records are registered for this bank account in the infobase. Cannot change the GL account.'");
		Items.GLAccountsGroup.Enabled = False;
		Items.ByDefault.Visible = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If Not CompanyOwner Then
		Cancel = True;
		ShowMessageBox(, NStr("en = 'GL accounts are edited only for company bank accounts.'"));
	EndIf;

EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure ByDefault(Command)
	
	GLAccount = GetDefaultGLAccount();
	NotifyAccountChange();
	
EndProcedure

&AtServerNoContext
Function GetDefaultGLAccount()	
	Return Catalogs.DefaultGLAccounts.GetDefaultGLAccount("BankAccount");	
EndFunction

#EndRegion

#Region FormItemsEventsHandlers

&AtClient
Procedure GLAccountOnChange(Item)
	
	If NOT ValueIsFilled(GLAccount) Then
		GLAccount = GetDefaultGLAccount();
	EndIf;
	
	NotifyAccountChange();
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Function CancelGLAccountChange(Ref)
	
	Query = New Query(
	"SELECT
	|	CashAssets.Period,
	|	CashAssets.Recorder,
	|	CashAssets.LineNumber,
	|	CashAssets.Active,
	|	CashAssets.RecordType,
	|	CashAssets.Company,
	|	CashAssets.CashAssetsType,
	|	CashAssets.BankAccountPettyCash,
	|	CashAssets.Currency,
	|	CashAssets.Amount,
	|	CashAssets.AmountCur,
	|	CashAssets.ContentOfAccountingRecord,
	|	CashAssets.Item
	|FROM
	|	AccumulationRegister.CashAssets AS CashAssets
	|WHERE
	|	CashAssets.BankAccountPettyCash = &BankAccountPettyCash");
	
	Query.SetParameter("BankAccountPettyCash", ?(ValueIsFilled(Ref), Ref, Undefined));
	
	Result = Query.Execute();
	
	Return Not Result.IsEmpty();

EndFunction

&AtClient
Procedure NotifyAccountChange()
	
	ParameterStructure = New Structure(
		"GLAccount",
		GLAccount
	);
	
	Notify("AccountsChangedBankAccounts", ParameterStructure);
	
EndProcedure

#EndRegion
