
#Region GeneralPurposeProceduresAndFunctions

// Function checks account change option.
//
&AtServer
Function DenialChangeGLAccounts(BusinessLine)
	
	Query = New Query(
	"SELECT TOP 1
	|	IncomeAndExpenses.Period,
	|	IncomeAndExpenses.Recorder,
	|	IncomeAndExpenses.LineNumber,
	|	IncomeAndExpenses.Active,
	|	IncomeAndExpenses.Company,
	|	IncomeAndExpenses.StructuralUnit,
	|	IncomeAndExpenses.BusinessLine,
	|	IncomeAndExpenses.SalesOrder,
	|	IncomeAndExpenses.GLAccount,
	|	IncomeAndExpenses.AmountIncome,
	|	IncomeAndExpenses.AmountExpense,
	|	IncomeAndExpenses.ContentOfAccountingRecord
	|FROM
	|	AccumulationRegister.IncomeAndExpenses AS IncomeAndExpenses
	|WHERE
	|	IncomeAndExpenses.BusinessLine = &BusinessLine");
	
	Query.SetParameter("BusinessLine", BusinessLine);
	
	Result = Query.Execute();
	
	Return Not Result.IsEmpty();
	
EndFunction

#EndRegion

#Region ProcedureFormEventHandlers

// Procedure - event handler OnCreateAtServer of the form.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	GLAccountDeferredRevenueFromSales = Parameters.GLAccountDeferredRevenueFromSales;
	ProfitGLAccount = Parameters.ProfitGLAccount;
	BusinessLine = Parameters.Ref;
	
	If DenialChangeGLAccounts(BusinessLine) Then
		Items.GLAccountsGroup.ToolTip = NStr("en = 'There is income or expenses for this area in the infobase. Cannot change GL accounts of sales revenue.'");
		
		Items.GLAccountDeferredRevenueFromSales.Enabled	= Not ValueIsFilled(GLAccountDeferredRevenueFromSales);
		Items.ProfitGLAccount.Enabled					= Not ValueIsFilled(ProfitGLAccount);
		
		Items.Default.Visible = False;
		
	EndIf;
	
	If Parameters.Ref = Catalogs.LinesOfBusiness.Other Then
		
		NewParameter = New ChoiceParameter("Filter.TypeOfAccount", Enums.GLAccountsTypes.OtherIncome);
		NewArray = New Array();
		NewArray.Add(NewParameter);
		NewParameters = New FixedArray(NewArray);
		
		NewParameter = New ChoiceParameter("Filter.TypeOfAccount", Enums.GLAccountsTypes.OtherExpenses);
		NewArray = New Array();
		NewArray.Add(NewParameter);
		NewParameters = New FixedArray(NewArray);
		
	Else
		
		NewParameter = New ChoiceParameter("Filter.TypeOfAccount", Enums.GLAccountsTypes.Revenue);
		NewArray = New Array();
		NewArray.Add(NewParameter);
		NewParameters = New FixedArray(NewArray);
		
		NewParameter = New ChoiceParameter("Filter.TypeOfAccount", Enums.GLAccountsTypes.CostOfSales);
		NewArray = New Array();
		NewArray.Add(NewParameter);
		NewParameters = New FixedArray(NewArray);
		
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
	
	GLAccountDeferredRevenueFromSales	= GetDefaultGLAccount("DeferredRevenue");
	ProfitGLAccount						= GetDefaultGLAccount("RetainedEarnings");
	
EndProcedure

&AtServerNoContext
Function GetDefaultGLAccount(Account)
	Return Catalogs.DefaultGLAccounts.GetDefaultGLAccount(Account);
EndFunction

&AtClient
Procedure NotifyAccountChange()
	
	ParameterStructure = New Structure;
	ParameterStructure.Insert("GLAccountDeferredRevenueFromSales",	GLAccountDeferredRevenueFromSales);
	ParameterStructure.Insert("ProfitGLAccount",					ProfitGLAccount);
	
	Notify("ActivityAccountsChanged", ParameterStructure);
	
EndProcedure

&AtClient
Procedure GLAccountDeferredRevenueFromSalesOnChange(Item)
	
	If NOT ValueIsFilled(GLAccountDeferredRevenueFromSales) Then
		GLAccountDeferredRevenueFromSales = GetDefaultGLAccount("DeferredRevenue");
	EndIf;
	
	NotifyAccountChange();
	
EndProcedure

&AtClient
Procedure ProfitGLAccountOnChange(Item)
	
	If NOT ValueIsFilled(ProfitGLAccount) Then
		ProfitGLAccount = GetDefaultGLAccount("RetainedEarnings");
	EndIf;
	
	NotifyAccountChange();
	
EndProcedure

#EndRegion
