
#Region GeneralPurposeProceduresAndFunctions

// Function checks account change option.
//
&AtServer
Function CancelGLAccountChange(Ref)
	
	Query = New Query(
	"SELECT
	|	POSSummary.Period,
	|	POSSummary.Recorder,
	|	POSSummary.LineNumber,
	|	POSSummary.Active,
	|	POSSummary.RecordType,
	|	POSSummary.Company,
	|	POSSummary.StructuralUnit,
	|	POSSummary.Currency,
	|	POSSummary.Amount,
	|	POSSummary.AmountCur,
	|	POSSummary.Cost,
	|	POSSummary.ContentOfAccountingRecord,
	|	POSSummary.SalesDocument
	|FROM
	|	AccumulationRegister.POSSummary AS POSSummary
	|WHERE
	|	POSSummary.StructuralUnit = &StructuralUnit");
	
	Query.SetParameter("StructuralUnit", ?(ValueIsFilled(Ref), Ref, Undefined));
	
	Result = Query.Execute();
	
	Return Not Result.IsEmpty();
	
EndFunction

#EndRegion

#Region ProcedureFormEventHandlers

// Procedure - event handler OnCreateAtServer of the form.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	GLAccountInRetail = Parameters.GLAccountInRetail;
	MarkupGLAccount = Parameters.MarkupGLAccount;
	Ref = Parameters.Ref;
	
	If CancelGLAccountChange(Ref) Then
		Items.GLAccountsGroup.ToolTip = NStr("en = 'Records are registered for this retail outlet in the infobase. Cannot change the GL account.'");
		Items.GLAccountsGroup.Enabled = False;
		Items.Default.Visible = False;
	EndIf;
	
	ThisIsRetailEarningAccounting = Ref.StructuralUnitType = Enums.BusinessUnitsTypes.RetailEarningAccounting;
	
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
	
	GLAccountInRetail	= GetDefaultGLAccount("Inventory");
	MarkupGLAccount		= GetDefaultGLAccount("RetailMarkup");
		
EndProcedure

&AtServerNoContext
Function GetDefaultGLAccount(Account)
	Return Catalogs.DefaultGLAccounts.GetDefaultGLAccount(Account);
EndFunction

&AtClient
Procedure NotifyAboutSettlementAccountChange()
	
	ParameterStructure = New Structure(
		"GLAccountInRetail, MarkupGLAccount",
		GLAccountInRetail, MarkupGLAccount
	);
	
	Notify("AccountsChangedBusinessUnits", ParameterStructure);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If Not ThisIsRetailEarningAccounting Then
		Cancel = True;
		ShowMessageBox(, NStr("en = 'You can edit GL accounts only for POS with retail inventory method (RIM).'"));
	EndIf;

EndProcedure

&AtClient
Procedure GLAccountInRetailOnChange(Item)
	
	If NOT ValueIsFilled(GLAccountInRetail) Then
		GLAccountInRetail = GetDefaultGLAccount("Inventory");
	EndIf;
	
	NotifyAboutSettlementAccountChange();
	
EndProcedure

&AtClient
Procedure MarkupGLAccountOnChange(Item)
	
	If NOT ValueIsFilled(MarkupGLAccount) Then
		MarkupGLAccount = GetDefaultGLAccount("RetailMarkup");
	EndIf;
	
	NotifyAboutSettlementAccountChange();
	
EndProcedure

#EndRegion
