
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	GLAccount	= Parameters.GLAccount;
	Ref			= Parameters.Ref;
	
	If IsAnyUsesThisCR(Ref) Then
		Items.GLAccountsGroup.ToolTip	= NStr("en = 'Records are registered for this cash register in the infobase. Cannot change the GL account.'");
		Items.GLAccountsGroup.Enabled	= False;
		Items.Default.Visible			= False;
	EndIf;
	
EndProcedure

&AtClient
Procedure GLAccountOnChange(Item)
	
	If NOT ValueIsFilled(GLAccount) Then
		GLAccount = GetDefaultGLAccount();
	EndIf;
	
	NotifyAccountChange();
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure Default(Command)
	
	GLAccount = GetDefaultGLAccount();
	NotifyAccountChange();
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Function IsAnyUsesThisCR(Ref)
	
	Query = New Query(
	"SELECT TOP 1
	|	CashInCashRegistersTurnovers.CashCR AS CashCR
	|FROM
	|	AccumulationRegister.CashInCashRegisters.Turnovers(, , Recorder, CashCR = &CashCR) AS CashInCashRegistersTurnovers");
	
	Query.SetParameter("CashCR", ?(ValueIsFilled(Ref), Ref, Undefined));
	
	Result = Query.Execute();
	
	Return Not Result.IsEmpty();
	
EndFunction

&AtServerNoContext
Function GetDefaultGLAccount()
	Return Catalogs.DefaultGLAccounts.GetDefaultGLAccount("PettyCashAccount");
EndFunction

&AtClient
Procedure NotifyAccountChange()
	
	ParameterStructure = New Structure(
		"GLAccount",
		GLAccount);
	
	Notify("CashRegisterAccountsChanged", ParameterStructure);
	
EndProcedure

#EndRegion
