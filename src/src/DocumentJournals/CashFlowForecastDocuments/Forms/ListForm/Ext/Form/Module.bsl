#Region EventHandlers

// Procedure - form event handler "OnLoadDataFromSettingsAtServer".
//
&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	Company				  = Settings.Get("Company");
	Counterparty				  = Settings.Get("Counterparty");
	BankAccountPettyCash		  = Settings.Get("BankAccountPettyCash");
	
	DriveClientServer.SetListFilterItem(List, "Company", Company, ValueIsFilled(Company));
		DriveClientServer.SetListFilterItem(List, "Counterparty", Counterparty, ValueIsFilled(Counterparty));
	If TypeOf(BankAccountPettyCash) = Type("CatalogRef.CashAccounts") Then
		DriveClientServer.SetListFilterItem(List, "PettyCash", BankAccountPettyCash, ValueIsFilled(BankAccountPettyCash));
	ElsIf TypeOf(BankAccountPettyCash) = Type("CatalogRef.BankAccounts") Then
		DriveClientServer.SetListFilterItem(List, "BankAccount", BankAccountPettyCash, ValueIsFilled(BankAccountPettyCash));
	Else
		DriveClientServer.SetListFilterItem(List, "PettyCash", BankAccountPettyCash, ValueIsFilled(BankAccountPettyCash));
		DriveClientServer.SetListFilterItem(List, "BankAccount", BankAccountPettyCash, ValueIsFilled(BankAccountPettyCash));
	EndIf;
	
EndProcedure

// Procedure - event handler OnChange of attribute BankAccountPettyCash.
//
&AtClient
Procedure BankAccountPettyCashOnChange(Item)
	
	If TypeOf(BankAccountPettyCash) = Type("CatalogRef.CashAccounts") Then
		DriveClientServer.SetListFilterItem(List, "PettyCash", BankAccountPettyCash, ValueIsFilled(BankAccountPettyCash));
	ElsIf TypeOf(BankAccountPettyCash) = Type("CatalogRef.BankAccounts") Then
		DriveClientServer.SetListFilterItem(List, "BankAccount", BankAccountPettyCash, ValueIsFilled(BankAccountPettyCash));
	Else
		DriveClientServer.SetListFilterItem(List, "PettyCash", BankAccountPettyCash, ValueIsFilled(BankAccountPettyCash));
		DriveClientServer.SetListFilterItem(List, "BankAccount", BankAccountPettyCash, ValueIsFilled(BankAccountPettyCash));
	EndIf;
	
EndProcedure

// Procedure - event handler OnChange of attribute Counterparty.
//
&AtClient
Procedure CounterpartyOnChange(Item)
	
	DriveClientServer.SetListFilterItem(List, "Counterparty", Counterparty, ValueIsFilled(Counterparty));
	
EndProcedure

// Procedure - event handler OnChange of the Company attribute.
//
&AtClient
Procedure CompanyOnChange(Item)
	
	DriveClientServer.SetListFilterItem(List, "Company", Company, ValueIsFilled(Company));
	
EndProcedure

&AtClient
Procedure ListOnActivateRow(Item)
	
	CurrentRow = Items.List.CurrentData;
	If CurrentRow <> Undefined Then
		Items.Information.Title = Format(CurrentRow.Date, "DLF=D");
	EndIf;
	
EndProcedure

#EndRegion
