#Region HelperProceduresAndFunctions

&AtClient
Procedure Attachable_HandleListRowActivation()
	
	CurrentRow = Items.BankStatements.CurrentData;
	If CurrentRow <> Undefined Then
		StructureData = GetDataOnBankAccount(CurrentRow.Date, CurrentRow.BankAccount);
		FillPropertyValues(ThisForm, StructureData);
		Date = Format(CurrentRow.Date, "DLF=D");
		If StructureData.ForeignExchangeAccounting Then
			Date = Date + " (" + CurrentRow.Currency + ")";
		EndIf;
	Else
		InformationAmountCurClosingBalance = 0;
		InformationAmountCurOpeningBalance = 0;
		InformationAmountCurReceipt = 0;
		InformationAmountCurExpense = 0;
		Date = "";
	EndIf;
	
EndProcedure

&AtServerNoContext
Function GetDataOnBankAccount(Period, BankAccount)
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	CashAssetsBalanceAndTurnovers.AmountCurOpeningBalance AS InformationAmountCurOpeningBalance,
	|	CashAssetsBalanceAndTurnovers.AmountCurReceipt AS InformationAmountCurReceipt,
	|	CashAssetsBalanceAndTurnovers.AmountCurExpense AS InformationAmountCurExpense,
	|	CashAssetsBalanceAndTurnovers.AmountCurClosingBalance AS InformationAmountCurClosingBalance
	|FROM
	|	AccumulationRegister.CashAssets.BalanceAndTurnovers(&BeginOfPeriod, &EndOfPeriod, Day, , BankAccountPettyCash = &BankAccount) AS CashAssetsBalanceAndTurnovers";
	
	Query.SetParameter("BeginOfPeriod", BegOfDay(Period));
	Query.SetParameter("EndOfPeriod", EndOfDay(Period));
	Query.SetParameter("BankAccount", BankAccount);
	ResultSelection = Query.Execute().Select();
	
	If ResultSelection.Next() Then
		ReturnStructure = New Structure("InformationAmountCurOpeningBalance, InformationAmountCurClosingBalance, InformationAmountCurReceipt, InformationAmountCurExpense, ForeignExchangeAccounting");
		FillPropertyValues(ReturnStructure, ResultSelection);
		ReturnStructure.ForeignExchangeAccounting = GetFunctionalOption("ForeignExchangeAccounting");
		Return ReturnStructure;
	Else
		Return New Structure(
			"InformationAmountCurClosingBalance, InformationAmountCurOpeningBalance, InformationAmountCurReceipt, InformationAmountCurExpense, ForeignExchangeAccounting",
			0,0,0,0,False
		);
	EndIf;
	
EndFunction

#EndRegion

#Region EventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Not CommonUse.OnCreateAtServer(ThisForm, Cancel, StandardProcessing) Then
		Return;
	EndIf;
	
	ValueList = New ValueList;
	CompaniesSelection = Catalogs.Companies.Select();
	While CompaniesSelection.Next() Do
		ValueList.Add(CompaniesSelection.Ref);
	EndDo;
	CompaniesList = ValueList;
	
EndProcedure

&AtServer
Procedure BeforeLoadDataFromSettingsAtServer(Settings)
	
	Company = Settings.Get("Company");
	BankAccount = Settings.Get("BankAccount");
	Counterparty = Settings.Get("Counterparty");
	
	If ValueIsFilled(Company) Then
		NewParameter = New ChoiceParameter("Filter.Owner", Company);
		NewArray = New Array();
		NewArray.Add(NewParameter);
		NewParameters = New FixedArray(NewArray);
		Items.BankAccount.ChoiceParameters = NewParameters;
	Else
		NewArray = New Array();
		For Each Item In CompaniesList Do
			NewArray.Add(Item.Value);
		EndDo;
		FixedArrayCompanies = New FixedArray(NewArray);
		NewParameter = New ChoiceParameter("Filter.Owner", FixedArrayCompanies);
		NewArray = New Array();
		NewArray.Add(NewParameter);
		NewParameters = New FixedArray(NewArray);
		Items.BankAccount.ChoiceParameters = NewParameters;
	EndIf;
	
	DriveClientServer.SetListFilterItem(BankStatements, "CompanyForFiltering", Company, ValueIsFilled(Company));
	DriveClientServer.SetListFilterItem(BankStatements, "Counterparty", Counterparty, ValueIsFilled(Counterparty));
	DriveClientServer.SetListFilterItem(BankStatements, "BankAccount", BankAccount, ValueIsFilled(BankAccount));
	
EndProcedure

&AtClient
Procedure BankAccountOnChange(Item)
	
	DriveClientServer.SetListFilterItem(BankStatements, "BankAccount", BankAccount, ValueIsFilled(BankAccount));
	
EndProcedure

&AtClient
Procedure CounterpartyOnChange(Item)
	
	DriveClientServer.SetListFilterItem(BankStatements, "Counterparty", Counterparty, ValueIsFilled(Counterparty));
	
EndProcedure

&AtClient
Procedure CompanyOnChange(Item)
	
	If ValueIsFilled(Company) Then
		
		NewParameter = New ChoiceParameter("Filter.Owner", Company);
		NewArray = New Array();
		NewArray.Add(NewParameter);
		NewParameters = New FixedArray(NewArray);
		Items.BankAccount.ChoiceParameters = NewParameters;
		
	Else
		
		NewArray = New Array();
		For Each Item In CompaniesList Do
			NewArray.Add(Item.Value);
		EndDo;
		FixedArrayCompanies = New FixedArray(NewArray);
		NewParameter = New ChoiceParameter("Filter.Owner", FixedArrayCompanies);
		NewArray = New Array();
		NewArray.Add(NewParameter);
		NewParameters = New FixedArray(NewArray);
		Items.BankAccount.ChoiceParameters = NewParameters;
		
	EndIf;
	
	DriveClientServer.SetListFilterItem(BankStatements, "CompanyForFiltering", Company, ValueIsFilled(Company));
	
EndProcedure

&AtClient
Procedure BankStatementsOnActivateRow(Item)
	
	AttachIdleHandler("Attachable_HandleListRowActivation", 0.2, True);
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "NotificationAboutChangingDebt" Then
		Attachable_HandleListRowActivation();
	EndIf;
	
EndProcedure

&AtClient
Procedure StatementGoTo(Command)
	
	OpenForm("Report.CashBalance.Form", New Structure("VariantKey", "Statement"));
	
EndProcedure

#EndRegion