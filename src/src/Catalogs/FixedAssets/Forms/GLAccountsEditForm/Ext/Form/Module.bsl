
#Region GeneralPurposeProceduresAndFunctions

// Function checks GL account change option.
//
&AtServer
Function CancelGLAccountChange(MessageText)
	
	Query = New Query(
	"SELECT
	|	FixedAssets.Period,
	|	FixedAssets.Recorder,
	|	FixedAssets.LineNumber,
	|	FixedAssets.Active,
	|	FixedAssets.RecordType,
	|	FixedAssets.Company,
	|	FixedAssets.FixedAsset,
	|	FixedAssets.Cost,
	|	FixedAssets.Depreciation,
	|	FixedAssets.ContentOfAccountingRecord
	|FROM
	|	AccumulationRegister.FixedAssets AS FixedAssets
	|WHERE
	|	FixedAssets.FixedAsset = &FixedAsset");
	
	Query.SetParameter("FixedAsset", ?(ValueIsFilled(Ref), Ref, Undefined));
	
	Result = Query.Execute();
	
	Return Not Result.IsEmpty();
	
EndFunction

&AtClient
Procedure NotifyAboutSettlementAccountChange()
	
	ParameterStructure = New Structure("GLAccount, DepreciationAccount", GLAccount, DepreciationAccount);
	Notify("AccountsChangedFixedAssets", ParameterStructure);
	
EndProcedure

#EndRegion

#Region ProcedureFormEventHandlers

// Procedure - event handler OnCreateAtServer of the form.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	GLAccount = Parameters.GLAccount;
	DepreciationAccount = Parameters.DepreciationAccount;
	
	If CancelGLAccountChange(Ref) Then
		Items.GLAccountsGroup.ToolTip = NStr("en = 'Records are registered for this capital asset in the infobase. Cannot change the GL account.'");
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
	NotifyAboutSettlementAccountChange();
	
EndProcedure

&AtServer
Procedure DefaultAtServer()
	
	GLAccount			= GetDefaultGLAccount("FixedAssets");
	DepreciationAccount	= GetDefaultGLAccount("FixedAssetsDepreciation");
	
EndProcedure

&AtServerNoContext
Function GetDefaultGLAccount(Account)
	Return Catalogs.DefaultGLAccounts.GetDefaultGLAccount(Account);
EndFunction

&AtClient
Procedure GLAccountOnChange(Item)
	
	If NOT ValueIsFilled(GLAccount) Then
		GLAccount = GetDefaultGLAccount("FixedAssets");
	EndIf;
	
	NotifyAboutSettlementAccountChange();
	
EndProcedure

&AtClient
Procedure DepreciationAccountOnChange(Item)

	If NOT ValueIsFilled(DepreciationAccount) Then
		DepreciationAccount = GetDefaultGLAccount("FixedAssetsDepreciation");
	EndIf;
	
	NotifyAboutSettlementAccountChange();
	
EndProcedure

#EndRegion
