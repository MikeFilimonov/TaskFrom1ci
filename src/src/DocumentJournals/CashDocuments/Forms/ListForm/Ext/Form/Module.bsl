#Region HelperProceduresAndFunctions

&AtServerNoContext
Function GetDataByPettyCash(Period, PettyCash, Currency)
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	CashAssetsBalanceAndTurnovers.AmountCurOpeningBalance AS InformationAmountCurOpeningBalance,
	|	CashAssetsBalanceAndTurnovers.AmountCurReceipt AS InformationAmountCurReceipt,
	|	CashAssetsBalanceAndTurnovers.AmountCurExpense AS InformationAmountCurExpense,
	|	CashAssetsBalanceAndTurnovers.AmountCurClosingBalance AS InformationAmountCurClosingBalance
	|FROM
	|	AccumulationRegister.CashAssets.BalanceAndTurnovers(
	|			&BeginOfPeriod,
	|			&EndOfPeriod,
	|			Day,
	|			,
	|			BankAccountPettyCash = &PettyCash
	|				AND Currency = &Currency) AS CashAssetsBalanceAndTurnovers";
	
	Query.SetParameter("BeginOfPeriod", BegOfDay(Period));
	Query.SetParameter("EndOfPeriod", EndOfDay(Period));
	Query.SetParameter("PettyCash", PettyCash);
	Query.SetParameter("Currency", ?(ValueIsFilled(Currency), Currency, Constants.FunctionalCurrency.Get()));
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

&AtClient
Procedure Attachable_HandleListRowActivation()
	
	CurrentRow = Items.CashDocuments.CurrentData;
	If CurrentRow <> Undefined Then
		StructureData = GetDataByPettyCash(CurrentRow.Date, CurrentRow.PettyCash, CurrentRow.Currency);
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

#EndRegion

#Region EventsHandlers

&AtServer
Procedure BeforeLoadDataFromSettingsAtServer(Settings)
	
	Company	 = Settings.Get("Company");
	Counterparty	 = Settings.Get("Counterparty");
	PettyCash		 = Settings.Get("PettyCash");
	
	DriveClientServer.SetListFilterItem(CashDocuments, "CompanyForFiltering", Company, ValueIsFilled(Company));
	DriveClientServer.SetListFilterItem(CashDocuments, "Counterparty", Counterparty, ValueIsFilled(Counterparty));
	DriveClientServer.SetListFilterItem(CashDocuments, "PettyCash", PettyCash, ValueIsFilled(PettyCash));
	
EndProcedure

&AtClient
Procedure PettyCashOnChange(Item)
	
	DriveClientServer.SetListFilterItem(CashDocuments, "PettyCash", PettyCash, ValueIsFilled(PettyCash));
	
EndProcedure

&AtClient
Procedure CounterpartyOnChange(Item)
	
	DriveClientServer.SetListFilterItem(CashDocuments, "Counterparty", Counterparty, ValueIsFilled(Counterparty));
	
EndProcedure

&AtClient
Procedure CompanyOnChange(Item)
	
	DriveClientServer.SetListFilterItem(CashDocuments, "CompanyForFiltering", Company, ValueIsFilled(Company));
	
EndProcedure

&AtClient
Procedure CashDocumentsOnActivateRow(Item)
	
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