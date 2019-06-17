
#Region GeneralPurposeProceduresAndFunctions

// Function checks GL account change option.
//
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

#EndRegion

#Region ProcedureFormEventHandlers

// Procedure - event handler OnCreateAtServer of the form.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	GLAccount = Parameters.GLAccount;
	Ref = Parameters.Ref;
	
	If CancelGLAccountChange(Ref) Then
		Items.GLAccountsGroup.ToolTip = NStr("en = 'Records are registered for this cash fund in the infobase. Cannot change the GL account.'");
		Items.GLAccountsGroup.Enabled = False;
		Items.Default.Visible = False;
	EndIf;
	
EndProcedure

#EndRegion

#Region ProcedureActionsOfTheFormCommandPanels

// Procedure - command click handler Default.
//
&AtClient
Procedure Default(Command)
	
	GLAccount = GetDefaultGLAccount();
	NotifyAccountChange();
	
EndProcedure

&AtServerNoContext
Function GetDefaultGLAccount()
	Return Catalogs.DefaultGLAccounts.GetDefaultGLAccount("PettyCashAccount");	
EndFunction

&AtClient
Procedure NotifyAccountChange()
	
	ParameterStructure = New Structure(
		"GLAccount",
		GLAccount
	);
	
	Notify("PettyCashAccountsChanged", ParameterStructure);
	
EndProcedure

&AtClient
Procedure GLAccountOnChange(Item)
	
	If NOT ValueIsFilled(GLAccount) Then
		GLAccount = GetDefaultGLAccount();
	EndIf;
	
	NotifyAccountChange();
	
EndProcedure

#EndRegion
