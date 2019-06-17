
#Region GeneralPurposeProceduresAndFunctions

// Function checks account change option.
//
&AtServer
Function CancelPersonnelGLAccountChange(Ref)
	
	Query = New Query(
	"SELECT
	|	Payroll.Period,
	|	Payroll.Recorder,
	|	Payroll.LineNumber,
	|	Payroll.Active,
	|	Payroll.RecordType,
	|	Payroll.Company,
	|	Payroll.StructuralUnit,
	|	Payroll.Employee,
	|	Payroll.Currency,
	|	Payroll.RegistrationPeriod,
	|	Payroll.Amount,
	|	Payroll.AmountCur,
	|	Payroll.ContentOfAccountingRecord
	|FROM
	|	AccumulationRegister.Payroll AS Payroll
	|WHERE
	|	Payroll.Employee = &Employee");
	
	Query.SetParameter("Employee", ?(ValueIsFilled(Ref), Ref, Undefined));
	
	Result = Query.Execute();
	
	Return Not Result.IsEmpty();
	
EndFunction

// Function checks account change option.
//
&AtServer
Function CancelAdvanceHoldersGLAccountChange(Ref)
	
	Query = New Query(
	"SELECT
	|	AdvanceHolders.Period,
	|	AdvanceHolders.Recorder,
	|	AdvanceHolders.LineNumber,
	|	AdvanceHolders.Active,
	|	AdvanceHolders.RecordType,
	|	AdvanceHolders.Company,
	|	AdvanceHolders.Employee,
	|	AdvanceHolders.Currency,
	|	AdvanceHolders.Document,
	|	AdvanceHolders.Amount,
	|	AdvanceHolders.AmountCur,
	|	AdvanceHolders.ContentOfAccountingRecord
	|FROM
	|	AccumulationRegister.AdvanceHolders AS AdvanceHolders
	|WHERE
	|	AdvanceHolders.Employee = &Employee");
	
	Query.SetParameter("Employee", ?(ValueIsFilled(Ref), Ref, Undefined));
	
	Result = Query.Execute();
	
	Return Not Result.IsEmpty();
	
EndFunction

#EndRegion

#Region ProcedureFormEventHandlers

// Procedure - event handler OnCreateAtServer of the form.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SettlementsHumanResourcesGLAccount = Parameters.SettlementsHumanResourcesGLAccount;
	AdvanceHoldersGLAccount = Parameters.AdvanceHoldersGLAccount;
	OverrunGLAccount = Parameters.OverrunGLAccount;
	Ref = Parameters.Ref;
	
	If CancelPersonnelGLAccountChange(Ref) Then
		Items.WithStaff.ToolTip = NStr("en = 'Records are registered for this employee in the infobase. Cannot change the GL account.'");
		Items.WithStaff.Enabled = False;
	EndIf;

	If CancelAdvanceHoldersGLAccountChange(Ref) Then
		Items.WithAdvanceHolder.ToolTip = NStr("en = 'Records are registered for this advance holder in the infobase. Cannot change the GL account.'");
		Items.WithAdvanceHolder.Enabled = False;
	EndIf;
	
	If Not Items.WithStaff.Enabled
		AND Not Items.WithAdvanceHolder.Enabled Then
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
	NotifyAboutSettlementAccountChange();
	
EndProcedure

&AtServer
Procedure DefaultAtServer()
	
	SettlementsHumanResourcesGLAccount	= GetDefaultGLAccount("PayrollPayable");
	AdvanceHoldersGLAccount				= GetDefaultGLAccount("AdvanceHoldersPayable");
	OverrunGLAccount					= GetDefaultGLAccount("AdvanceHolders");
	
EndProcedure

&AtServerNoContext
Function GetDefaultGLAccount(Account)
	Return Catalogs.DefaultGLAccounts.GetDefaultGLAccount(Account);
EndFunction

&AtClient
Procedure NotifyAboutSettlementAccountChange()
	
	ParameterStructure = New Structure(
		"SettlementsHumanResourcesGLAccount, AdvanceHoldersGLAccount, OverrunGLAccount",
		SettlementsHumanResourcesGLAccount, AdvanceHoldersGLAccount, OverrunGLAccount
	);
	
	Notify("AccountsChangedEmployees", ParameterStructure);
	
EndProcedure

&AtClient
Procedure SettlementsHumanResourcesGLAccountOnChange(Item)
	
	If NOT ValueIsFilled(SettlementsHumanResourcesGLAccount) Then
		SettlementsHumanResourcesGLAccount = GetDefaultGLAccount("PayrollPayable");
	EndIf;
	
	NotifyAboutSettlementAccountChange();
	
EndProcedure

&AtClient
Procedure AdvanceHoldersGLAccountOnChange(Item)
	
	If NOT ValueIsFilled(AdvanceHoldersGLAccount) Then
		AdvanceHoldersGLAccount = GetDefaultGLAccount("AdvanceHoldersPayable");
	EndIf;
	
	NotifyAboutSettlementAccountChange();
	
EndProcedure

&AtClient
Procedure OverrunGLAccountOnChange(Item)
	
	If NOT ValueIsFilled(OverrunGLAccount) Then
		OverrunGLAccount = GetDefaultGLAccount("AdvanceHolders");
	EndIf;
	
	NotifyAboutSettlementAccountChange();
	
EndProcedure

#EndRegion
