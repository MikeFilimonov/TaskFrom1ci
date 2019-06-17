
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	User = Users.CurrentUser();
	SettingValue = DriveReUse.GetValueByDefaultUser(User, "MainCompany");
	If ValueIsFilled(SettingValue) Then
		MainCompany = SettingValue;
	Else
		MainCompany = DriveServer.GetPredefinedCompany();
	EndIf;
	
EndProcedure

&AtServer
Procedure BeforeImportDataFromSettingsAtServer(Settings)
	
	Company = Settings.Get("Company");
	DriveClientServer.SetListFilterItem(List, "Owner", Company, ValueIsFilled(Company));
	
EndProcedure

#EndRegion

#Region FormItemsEventsHandlers

&AtClient
Procedure CompanyOnChange(Item)
	
	DriveClientServer.SetListFilterItem(List, "Owner", Company, ValueIsFilled(Company));
	
EndProcedure

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	Cancel = True;
	
	ParametersStructure = New Structure();
	If ValueIsFilled(Company) Then
		ParametersStructure.Insert("Owner", Company);
	Else
		ParametersStructure.Insert("Owner", MainCompany);
	EndIf;
	
	OpenForm("Catalog.BankAccounts.Form.ItemForm", New Structure("FillingValues", ParametersStructure));
	
EndProcedure

#EndRegion
