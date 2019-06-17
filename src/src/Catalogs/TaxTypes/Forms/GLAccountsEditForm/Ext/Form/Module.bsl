
#Region GeneralPurposeProceduresAndFunctions

// Function checks GL account change option.
//
&AtServer
Function CancelGLAccountChange(Ref)
	
	Query = New Query(
	"SELECT
	|	TaxPayable.Period,
	|	TaxPayable.Recorder,
	|	TaxPayable.LineNumber,
	|	TaxPayable.Active,
	|	TaxPayable.RecordType,
	|	TaxPayable.Company,
	|	TaxPayable.TaxKind,
	|	TaxPayable.Amount,
	|	TaxPayable.ContentOfAccountingRecord
	|FROM
	|	AccumulationRegister.TaxPayable AS TaxPayable
	|WHERE
	|	TaxPayable.TaxKind = &TaxKind");
	
	Query.SetParameter("TaxKind", ?(ValueIsFilled(Ref), Ref, Undefined));
	
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
	GLAccountForReimbursement = Parameters.GLAccountForReimbursement;
	Ref = Parameters.Ref;
	
	If CancelGLAccountChange(Ref) Then
		Items.GLAccountsGroup.ToolTip = NStr("en = 'Records are registered for this tax kind in the infobase. Cannot change the GL account.'");
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
	
	DefaultAtServer();
	NotifyAccountChange();
	
EndProcedure

&AtServer
Procedure DefaultAtServer()
	
	GLAccount					= GetDefaultGLAccount("TaxPayable");
	GLAccountForReimbursement	= GetDefaultGLAccount("TaxRefund");	
		
EndProcedure

&AtServerNoContext
Function GetDefaultGLAccount(Account)
	Return Catalogs.DefaultGLAccounts.GetDefaultGLAccount(Account);
EndFunction

&AtClient
Procedure NotifyAccountChange()
	
	ParameterStructure = New Structure(
		"GLAccount, GLAccountForReimbursement",
		GLAccount, GLAccountForReimbursement
	);
	
	Notify("AccountsTaxTypesChanged", ParameterStructure);
	
EndProcedure

&AtClient
Procedure GLAccountOnChange(Item)
	
	If NOT ValueIsFilled(GLAccount) Then
		GLAccount = GetDefaultGLAccount("TaxPayable");
	EndIf;
	
	NotifyAccountChange();
	
EndProcedure

&AtClient
Procedure GLAccountForReimbursementOnChange(Item)
	
	If NOT ValueIsFilled(GLAccountForReimbursement) Then
		GLAccountForReimbursement = GetDefaultGLAccount("TaxRefund");
	EndIf;
	
	NotifyAccountChange();
	
EndProcedure

#EndRegion
