
#Region FormHandlers

&AtServer
// Procedure - OnCreateAtServer event handler.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisForm, Items.ImportantCommandsGroup);
	// End StandardSubsystems.Printing
	
EndProcedure

// Procedure - form event handler "OnLoadDataFromSettingsAtServer".
//
&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	FilterEmployee			= Settings.Get("FilterEmployee");
	FilterCompany 		= Settings.Get("FilterCompany");
	FilterDepartment 		= Settings.Get("FilterDepartment");
	
	DriveClientServer.SetListFilterItem(List, "Employees.Employee", FilterEmployee, ValueIsFilled(FilterEmployee));
	DriveClientServer.SetListFilterItem(List, "Company", FilterCompany, ValueIsFilled(FilterCompany));
	DriveClientServer.SetListFilterItem(List, "Employees.StructuralUnit", FilterDepartment, ValueIsFilled(FilterDepartment));
	
EndProcedure

#EndRegion

#Region AttributeHandlers

// Procedure - event handler OnChange input field FilterEmployee
//
&AtClient
Procedure FilterEmployeeOnChange(Item)
	
	DriveClientServer.SetListFilterItem(List, "Employees.Employee", FilterEmployee, ValueIsFilled(FilterEmployee));
	
EndProcedure

// Procedure - event handler OnChange input field FilterCompany 
// In procedure the situation is defined, when on change its
// date document is in another document numbering period, and in
// this case appropriates for document new unique number.
// Overrides the corresponding form parameter.
//
&AtClient
Procedure FilterCompanyOnChange(Item)
	
	DriveClientServer.SetListFilterItem(List, "Company", FilterCompany, ValueIsFilled(FilterCompany));
	
EndProcedure

// Procedure - event handler OnChange input field FilterDepartment
// In procedure the situation is defined, when on change its
// date document is in another document numbering period, and in
// this case appropriates for document new unique number.
// Overrides the corresponding form parameter.
//
&AtClient
Procedure FilterDepartmentOnChange(Item)
	
	DriveClientServer.SetListFilterItem(List, "Employees.StructuralUnit", FilterDepartment, ValueIsFilled(FilterDepartment));
	
EndProcedure

#EndRegion

#Region LibrariesHandlers

// StandardSubsystems.Printing
&AtClient
Procedure Attachable_ExecutePrintCommand(Command)
	PrintManagementClient.ExecuteConnectedPrintCommand(Command, ThisObject, Items.List);
EndProcedure
// End StandardSubsystems.Printing

#EndRegion
