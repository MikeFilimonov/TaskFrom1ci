#Region ProcedureFormEventHandlers

&AtServer
// Procedure - event handler OnCreateAtServer of the form.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	If Not ValueIsFilled(Record.SourceRecordKey.Products) Then
		SettingValue = DriveReUse.GetValueByDefaultUser(Users.CurrentUser(), "MainCompany");
		If ValueIsFilled(SettingValue) Then
			Record.Company = SettingValue;
		Else
			Record.Company = Catalogs.Companies.MainCompany;		
		EndIf;
	EndIf;
	
	If Constants.AccountingBySubsidiaryCompany.Get() Then
		Record.Company = Constants.ParentCompany.Get();
		Items.Company.ReadOnly = True;
	EndIf; 
	
EndProcedure

#EndRegion
