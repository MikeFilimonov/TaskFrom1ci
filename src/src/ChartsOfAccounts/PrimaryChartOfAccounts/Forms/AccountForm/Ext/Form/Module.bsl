
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	UseBudgeting = Constants.UseBudgeting.Get();
	
	If Not ValueIsFilled(Object.Ref) Then
		
		If Object.TypeOfAccount = PredefinedValue("Enum.GLAccountsTypes.FixedAssets")
			OR Object.TypeOfAccount = PredefinedValue("Enum.GLAccountsTypes.AccountsReceivable")
			OR Object.TypeOfAccount = PredefinedValue("Enum.GLAccountsTypes.CashAndCashEquivalents") 
			OR Object.TypeOfAccount = PredefinedValue("Enum.GLAccountsTypes.Inventory")
			OR Object.TypeOfAccount = PredefinedValue("Enum.GLAccountsTypes.LoanInterest")
			OR Object.TypeOfAccount = PredefinedValue("Enum.GLAccountsTypes.OtherFixedAssets")
			OR Object.TypeOfAccount = PredefinedValue("Enum.GLAccountsTypes.OtherExpenses")
			OR Object.TypeOfAccount = PredefinedValue("Enum.GLAccountsTypes.CostOfSales") Then
				Object.Type = AccountType.Active;
		EndIf;
		
		If Object.TypeOfAccount = PredefinedValue("Enum.GLAccountsTypes.Depreciation")
			OR Object.TypeOfAccount = PredefinedValue("Enum.GLAccountsTypes.LongtermLiabilities")
			OR Object.TypeOfAccount = PredefinedValue("Enum.GLAccountsTypes.Revenue")
			OR Object.TypeOfAccount = PredefinedValue("Enum.GLAccountsTypes.Capital") 
			OR Object.TypeOfAccount = PredefinedValue("Enum.GLAccountsTypes.AccountsPayable")
			OR Object.TypeOfAccount = PredefinedValue("Enum.GLAccountsTypes.LoansBorrowed")
			OR Object.TypeOfAccount = PredefinedValue("Enum.GLAccountsTypes.OtherIncome")
			OR Object.TypeOfAccount = PredefinedValue("Enum.GLAccountsTypes.ReserveAndAdditionalCapital")
			OR Object.TypeOfAccount = PredefinedValue("Enum.GLAccountsTypes.RetailMarkup") Then
				Object.Type = AccountType.Passive;
		EndIf;
		
		If Object.TypeOfAccount = PredefinedValue("Enum.GLAccountsTypes.IncomeTax")
			OR Object.TypeOfAccount = PredefinedValue("Enum.GLAccountsTypes.RetainedEarnings")
			OR Object.TypeOfAccount = PredefinedValue("Enum.GLAccountsTypes.ProfitLosses") Then
				Object.Type = AccountType.ActivePassive;
		EndIf;
		
	EndIf;
	
	TypeOfAccount = Object.TypeOfAccount;
	
	Items.Type.ChoiceList.Clear();
	Items.Type.ChoiceList.Add(AccountType.Active,			NStr("en = 'Dr'"));
	Items.Type.ChoiceList.Add(AccountType.Passive,			NStr("en = '(Cr)'"));
	Items.Type.ChoiceList.Add(AccountType.ActivePassive,	NStr("en = 'Dr/(Cr)'"));
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	FormManagement();
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	Notify("Write_PrimaryChartOfAccounts", Object.Ref);
	
EndProcedure

#EndRegion

#Region FormItemsEventsHandlers

// Procedure - OnChange event handler of the DistributionMethod entry field.
//
&AtClient
Procedure DistributionModeOnChange(Item)
	
	If Object.MethodOfDistribution = PredefinedValue("Enum.CostAllocationMethod.DirectCost") Then
		Items.Filter.Visible = True;
	Else
		Items.Filter.Visible = False;
		Object.GLAccounts.Clear();
	EndIf;

EndProcedure

// Procedure - OnChange event handler of the AccountType entry field.
//
&AtClient
Procedure GLAccountTypeOnChange(Item)
	
	If TypeOfAccount = Object.TypeOfAccount Then
		Return;
	EndIf;
	
	Object.GLAccounts.Clear();
	
	FormManagement();
	
	If Object.TypeOfAccount = PredefinedValue("Enum.GLAccountsTypes.WorkInProcess") Then
		Object.MethodOfDistribution = PredefinedValue("Enum.CostAllocationMethod.DoNotDistribute");
	ElsIf Object.TypeOfAccount = PredefinedValue("Enum.GLAccountsTypes.IndirectExpenses") Then
		Object.MethodOfDistribution = PredefinedValue("Enum.CostAllocationMethod.ProductionVolume");
	ElsIf Object.TypeOfAccount = PredefinedValue("Enum.GLAccountsTypes.Expenses")
		  OR Object.TypeOfAccount = PredefinedValue("Enum.GLAccountsTypes.Revenue")
		  OR Object.TypeOfAccount = PredefinedValue("Enum.GLAccountsTypes.OtherIncome")
		  OR Object.TypeOfAccount = PredefinedValue("Enum.GLAccountsTypes.OtherExpenses") Then
		Object.MethodOfDistribution = PredefinedValue("Enum.CostAllocationMethod.SalesVolume");
	Else
		Object.MethodOfDistribution = PredefinedValue("Enum.CostAllocationMethod.DoNotDistribute");
	EndIf;
	
	Items.Filter.Visible = Object.MethodOfDistribution = PredefinedValue("Enum.CostAllocationMethod.DirectCost");
	
	TypeOfAccount = Object.TypeOfAccount;
	
EndProcedure

#EndRegion

#Region CommandHandlers

// Procedure - command handler Filter.
//
&AtClient
Procedure Filter(Command)
	
	GLAccountsInStorageAddress = PlaceGLAccountsToStorage();
	
	FormParameters = New Structure(
		"GLAccountsInStorageAddress",
		GLAccountsInStorageAddress
	);
	
	Notification = New NotifyDescription("FilterCompletion",ThisForm,GLAccountsInStorageAddress);
	OpenForm("ChartOfAccounts.PrimaryChartOfAccounts.Form.FilterForm", FormParameters,,,,,Notification);
	
EndProcedure

&AtClient
Procedure FilterCompletion(Result,GLAccountsInStorageAddress) Export
	
	If Result = DialogReturnCode.OK Then
		GetGLAccountsFromStorage(GLAccountsInStorageAddress);
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// The function moves the GLAccounts tabular section
// to the temporary storage and returns the address
//
&AtServer
Function PlaceGLAccountsToStorage()
	
	Return PutToTempStorage(
		Object.GLAccounts.Unload(,
			"GLAccount"
		),
		UUID
	);
	
EndFunction

// The function receives the tabular section of GLAccounts from the temporary storage.
//
&AtServer
Procedure GetGLAccountsFromStorage(GLAccountsInStorageAddress)
	
	TableAccountsAccounting = GetFromTempStorage(GLAccountsInStorageAddress);
	Object.GLAccounts.Clear();
	For Each TableRow In TableAccountsAccounting Do
		String = Object.GLAccounts.Add();
		FillPropertyValues(String, TableRow);
	EndDo;
	
EndProcedure

&AtServer
Procedure FormManagement()
	
	UseBudgeting = Constants.UseBudgeting.Get();
	If Object.TypeOfAccount = Enums.GLAccountsTypes.IndirectExpenses Then
		Items.ClosingAccount.Visible = True;
		Items.MethodOfDistribution.Visible = True;
		Items.MethodOfDistribution.ChoiceList.Clear();
		Items.MethodOfDistribution.ChoiceList.Add(Enums.CostAllocationMethod.ProductionVolume);
		Items.MethodOfDistribution.ChoiceList.Add(Enums.CostAllocationMethod.DirectCost);
		Items.MethodOfDistribution.ChoiceList.Add(Enums.CostAllocationMethod.DoNotDistribute);
		Items.ClosingAccount.ToolTip = ?(
			UseBudgeting,
			NStr("en = 'Auto closing account on month closing and budgeting'"),
			NStr("en = 'Auto closing account on month closing'")
		);
		Items.MethodOfDistribution.ToolTip = NStr("en = 'Method of automatic allocation to the cost of released products on month-end closing'"
		);
	ElsIf Object.TypeOfAccount =  Enums.GLAccountsTypes.WorkInProcess Then
		Items.ClosingAccount.Visible = True;
		Items.MethodOfDistribution.Visible = True;
		Items.MethodOfDistribution.ChoiceList.Clear();
		Items.MethodOfDistribution.ChoiceList.Add(Enums.CostAllocationMethod.ProductionVolume);
		Items.MethodOfDistribution.ChoiceList.Add(Enums.CostAllocationMethod.DirectCost);
		Items.MethodOfDistribution.ChoiceList.Add(Enums.CostAllocationMethod.DoNotDistribute);
		Items.ClosingAccount.ToolTip = ?(
			UseBudgeting,
			NStr("en = 'Auto closing account on month closing and budgeting'"),
			NStr("en = 'Auto closing account on month closing'")
		);
		Items.MethodOfDistribution.ToolTip = NStr("en = 'Method of automatic allocation to the cost of released products at month-end closing for intangible costs'"
		);
	ElsIf (TypeOfAccount <>  Enums.GLAccountsTypes.OtherIncome
		   OR TypeOfAccount <>  Enums.GLAccountsTypes.OtherExpenses
		   OR TypeOfAccount <>  Enums.GLAccountsTypes.Expenses
		   OR TypeOfAccount <>  Enums.GLAccountsTypes.LoanInterest
		   OR TypeOfAccount <>  Enums.GLAccountsTypes.Revenue)
			AND (Object.TypeOfAccount =  Enums.GLAccountsTypes.OtherIncome
		   OR Object.TypeOfAccount =  Enums.GLAccountsTypes.OtherExpenses
		   OR Object.TypeOfAccount =  Enums.GLAccountsTypes.Expenses
		   OR Object.TypeOfAccount =  Enums.GLAccountsTypes.LoanInterest
		   OR Object.TypeOfAccount =  Enums.GLAccountsTypes.Revenue) Then
		Items.ClosingAccount.Visible = False;
		Items.MethodOfDistribution.Visible = True;
		Items.MethodOfDistribution.ChoiceList.Clear();
		Items.MethodOfDistribution.ChoiceList.Add(Enums.CostAllocationMethod.SalesVolume);
		Items.MethodOfDistribution.ChoiceList.Add(Enums.CostAllocationMethod.SalesRevenue);
		Items.MethodOfDistribution.ChoiceList.Add(Enums.CostAllocationMethod.CostOfGoodsSold);
		Items.MethodOfDistribution.ChoiceList.Add(Enums.CostAllocationMethod.GrossProfit);
		Items.MethodOfDistribution.ChoiceList.Add(Enums.CostAllocationMethod.DoNotDistribute, NStr("en = 'Direct allocation'"));
		Items.MethodOfDistribution.ToolTip = ?(
			UseBudgeting,
			NStr("en = 'Method of automatic allocation to the financial result on month-end closing and budgeting'"),
			NStr("en = 'Method of automatic allocation to the financial result on month-end closing'")
		);
	Else
		Items.MethodOfDistribution.Visible = False;
		Items.ClosingAccount.Visible = False;
	EndIf;
	
	Items.Filter.Visible = Object.MethodOfDistribution = Enums.CostAllocationMethod.DirectCost;
	
EndProcedure

#EndRegion
