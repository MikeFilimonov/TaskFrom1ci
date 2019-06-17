
//////////////////////////////////////////////////////////////////////////////// 
// EVENT HANDLERS

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

&AtServer
// Procedure - form event handler "OnLoadDataFromSettingsAtServer".
//
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	Company		= Settings.Get("Company");
	Counterparty		= Settings.Get("Counterparty");
	Department	= Settings.Get("Department");
	
	DriveClientServer.SetListFilterItem(List, "Company", Company, ValueIsFilled(Company));
	DriveClientServer.SetListFilterItem(List, "Counterparty", Counterparty, ValueIsFilled(Counterparty));
	DriveClientServer.SetListFilterItem(List, "Department", Department, ValueIsFilled(Department));
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of attribute department.
// 
Procedure DepartmentOnChange(Item)
	
	DriveClientServer.SetListFilterItem(List, "Department", Department, ValueIsFilled(Department));
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of attribute Counterparty.
// 
Procedure CounterpartyOnChange(Item)
	
	DriveClientServer.SetListFilterItem(List, "Counterparty", Counterparty, ValueIsFilled(Counterparty));
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of the Company attribute.
// 
Procedure CompanyOnChange(Item)
	
	DriveClientServer.SetListFilterItem(List, "Company", Company, ValueIsFilled(Company));
	
EndProcedure

#Region LibrariesHandlers

// StandardSubsystems.Printing
&AtClient
Procedure Attachable_ExecutePrintCommand(Command)
	PrintManagementClient.ExecuteConnectedPrintCommand(Command, ThisObject, Items.List);
EndProcedure
// End StandardSubsystems.Printing

#EndRegion
