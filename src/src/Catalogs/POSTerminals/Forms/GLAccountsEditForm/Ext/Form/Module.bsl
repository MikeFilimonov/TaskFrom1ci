
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	GLAccount = Parameters.GLAccount;
	
	If CancelGLAccountChange(Parameters.Ref) Then
		Items.GLAccountsGroup.ToolTip = NStr("en = 'Records are registered for this POS terminal in the infobase. Cannot change the GL account.'");
		Items.GLAccountsGroup.Enabled = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure Default(Command)
	
	GLAccount = GetDefaultGLAccount();
	NotifyAboutSettlementAccountChange();
	
EndProcedure

&AtClient
Procedure GLAccountOnChange(Item)
	
	If NOT ValueIsFilled(GLAccount) Then
		GLAccount = GetDefaultGLAccount();
	EndIf;
	
	NotifyAboutSettlementAccountChange();
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Function CancelGLAccountChange(Ref)
	
	If Not ValueIsFilled(Ref) Then
		Return False;
	EndIf;
	
	Query = New Query(
	"SELECT TOP 1
	|	ShiftClosurePaymentWithPaymentCards.Ref AS Ref
	|FROM
	|	Document.ShiftClosure.PaymentWithPaymentCards AS ShiftClosurePaymentWithPaymentCards
	|WHERE
	|	ShiftClosurePaymentWithPaymentCards.Ref.Posted
	|	AND ShiftClosurePaymentWithPaymentCards.POSTerminal = &POSTerminal");
	
	Query.SetParameter("POSTerminal", Ref);
	
	Result = Query.Execute();
	
	Return Not Result.IsEmpty();
	
EndFunction

&AtServerNoContext
Function GetDefaultGLAccount()
	Return Catalogs.DefaultGLAccounts.GetDefaultGLAccount("CreditCardSalesReceivedAtALaterDate");	
EndFunction

&AtClient
Procedure NotifyAboutSettlementAccountChange()
	
	ParameterStructure = New Structure(
		"GLAccount",
		GLAccount);
	
	Notify("GLAccountChangedPOSTerminals", ParameterStructure);
	
EndProcedure

#EndRegion
