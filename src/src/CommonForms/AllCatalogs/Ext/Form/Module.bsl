
#Region ProcedureFormEventHandlers

// Procedure - event handler OnCreateAtServer of the form.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	FOMultipleCompaniesAccounting = GetFunctionalOption("UseSeveralCompanies");
	Items.LabelCompany.Title = ?(FOMultipleCompaniesAccounting, NStr("en = 'Companies'"), NStr("en = 'Company'"));
	
	FOAccountingBySeveralWarehouses = GetFunctionalOption("UseSeveralWarehouses");
	Items.LabelWarehouses.Title = ?(FOAccountingBySeveralWarehouses, NStr("en = 'Warehouses'"), NStr("en = 'Warehouse'"));
	
	FOAccountingBySeveralDepartments = GetFunctionalOption("UseSeveralDepartments");
	Items.LabelDepartments.Title = ?(FOAccountingBySeveralDepartments, NStr("en = 'Departments'"), NStr("en = 'Department'"));
	
	FOAccountingBySeveralLinesOfBusiness = GetFunctionalOption("AccountingBySeveralLinesOfBusiness");
	Items.LabelLinesOfBusiness.Title = ?(FOAccountingBySeveralLinesOfBusiness, NStr("en = 'Business activities'"), NStr("en = 'Business area'"));
	
EndProcedure

// Procedure - event handler of the form NotificationProcessing.
//
&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "Record_ConstantsSet" Then 
		
		If Source = "UseSeveralCompanies" Then
			
			FOMultipleCompaniesAccounting = GetFOServer("UseSeveralCompanies");
			Items.LabelCompany.Title = ?(FOMultipleCompaniesAccounting, NStr("en = 'Companies'"), NStr("en = 'Company'"));
			
		ElsIf Source = "UseSeveralWarehouses" Then
			
			FOAccountingBySeveralWarehouses = GetFOServer("UseSeveralWarehouses");
			Items.LabelWarehouses.Title = ?(FOAccountingBySeveralWarehouses, NStr("en = 'Warehouses'"), NStr("en = 'Warehouse'"));
			
		ElsIf Source = "UseSeveralDepartments" Then
			
			FOAccountingBySeveralDepartments = GetFOServer("UseSeveralDepartments");
			Items.LabelDepartments.Title = ?(FOAccountingBySeveralDepartments, NStr("en = 'Departments'"), NStr("en = 'Department'"));
			
		ElsIf Source = "UseSeveralLinesOfBusiness" Then
			
			FOAccountingBySeveralLinesOfBusiness = GetFOServer("AccountingBySeveralLinesOfBusiness");
			Items.LabelLinesOfBusiness.Title = ?(FOAccountingBySeveralLinesOfBusiness, NStr("en = 'Line of business'"), NStr("en = 'Line of business'"));
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region ProcedureEventHandlersOfFormAttributes

// Procedure - command handler CompanyCatalog.
//
&AtClient
Procedure LabelCompaniesClick(Item)
	
	If FOMultipleCompaniesAccounting Then
		OpenForm("Catalog.Companies.ListForm");
	Else
		ParemeterCompany = New Structure("Key", PredefinedValue("Catalog.Companies.MainCompany"));
		OpenForm("Catalog.Companies.ObjectForm", ParemeterCompany);
	EndIf;
	
EndProcedure

// Procedure - command handler CatalogWarehouses.
//
&AtClient
Procedure LableWarehousesClick(Item)
	
	If FOAccountingBySeveralWarehouses Then
		
		FilterArray = New Array;
		FilterArray.Add(PredefinedValue("Enum.BusinessUnitsTypes.Warehouse"));
		FilterArray.Add(PredefinedValue("Enum.BusinessUnitsTypes.Retail"));
		FilterArray.Add(PredefinedValue("Enum.BusinessUnitsTypes.RetailEarningAccounting"));
		
		FilterStructure = New Structure("StructuralUnitType", FilterArray);
		
		OpenForm("Catalog.BusinessUnits.ListForm", New Structure("Filter", FilterStructure));
		
	Else
		
		ParameterWarehouse = New Structure("Key", PredefinedValue("Catalog.BusinessUnits.MainWarehouse"));
		OpenForm("Catalog.BusinessUnits.ObjectForm", ParameterWarehouse);
		
	EndIf;
	
EndProcedure

// Procedure - command handler CatalogDepartments.
//
&AtClient
Procedure LabelDepartmentClick(Item)
	
	If FOAccountingBySeveralDepartments Then
		
		FilterStructure = New Structure("StructuralUnitType", PredefinedValue("Enum.BusinessUnitsTypes.Department"));
		
		OpenForm("Catalog.BusinessUnits.ListForm", New Structure("Filter", FilterStructure));
	
	Else
		
		ParameterDepartment = New Structure("Key", PredefinedValue("Catalog.BusinessUnits.MainDepartment"));
		OpenForm("Catalog.BusinessUnits.ObjectForm", ParameterDepartment);
		
	EndIf;
	
EndProcedure

// Procedure - command handler CatalogLinesOfBusiness.
//
&AtClient
Procedure LableLinesOfBusinessClick(Item)
	
	If FOAccountingBySeveralLinesOfBusiness Then
		OpenForm("Catalog.LinesOfBusiness.ListForm");
	Else
		
		ParameterBusinessLine = New Structure("Key", PredefinedValue("Catalog.LinesOfBusiness.MainLine"));
		OpenForm("Catalog.LinesOfBusiness.ObjectForm", ParameterBusinessLine);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions
	
&AtServerNoContext
Function GetFOServer(NameFunctionalOption)
	
	Return GetFunctionalOption(NameFunctionalOption);
	
EndFunction

#EndRegion
