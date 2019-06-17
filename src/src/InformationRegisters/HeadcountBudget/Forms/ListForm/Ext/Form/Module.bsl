#Region CommonUseProcedures

&AtClient
// Filters for the staff list tabular section are set to the procedure
//
Procedure SetFilter()
	
	
	DriveClientServer.SetListFilterItem(List,"Company",Company);

	If Not UseSeveralDepartments Then
		
		DriveClientServer.SetListFilterItem(List,"StructuralUnit",MainDepartment);
		
	ElsIf Items.Departments.CurrentData <> Undefined Then
		
		DriveClientServer.SetListFilterItem(List,"StructuralUnit",Items.Departments.CurrentData.Ref);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region ProcedureFormEventHandlers

&AtServer
// Procedure - event handler OnCreateAtServer of the form.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	If Constants.AccountingBySubsidiaryCompany.Get() Then
		
		Company = Constants.ParentCompany.Get();
		Items.Company.Visible = False;
		
	ElsIf Parameters.Filter.Property("Company") Then
		
		Company = Parameters.Filter.Company;
		Items.Company.Enabled = False;
		
	Else
		
		SettingValue = DriveReUse.GetValueByDefaultUser(Users.CurrentUser(), "MainCompany");
		
		If ValueIsFilled(SettingValue) Then
			
			Company = SettingValue;
			
		Else
			
			Company = Catalogs.Companies.MainCompany;
			
		EndIf;
		
	EndIf;
	
	If Parameters.Filter.Property("StructuralUnit") Then
		Items.Departments.Visible = False;
	EndIf;
	
	UseSeveralDepartments = Constants.UseSeveralDepartments.Get();
	MainDepartment = Catalogs.BusinessUnits.MainDepartment;
	If Not UseSeveralDepartments Then
		
		Items.Departments.Visible = False;
		DriveClientServer.SetListFilterItem(List,"Company",Company);
		DriveClientServer.SetListFilterItem(List,"StructuralUnit",MainDepartment);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region ProcedureEventHandlersOfHeaderAttributes

&AtClient
// Procedure - event handler OnChange attribute Company
//
Procedure CompanyOnChange(Item)
	
	SetFilter();
	
EndProcedure

&AtClient
// Procedure - OnActivateRow event processor of the Subdepartments table.
//
Procedure DepartmentsOnActivateRow(Item)
	
	SetFilter();
	
EndProcedure

#EndRegion
