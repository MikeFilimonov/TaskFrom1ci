
#Region ProcedureFormEventHandlers

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
	FilterRegistrationPeriod 	= Settings.Get("FilterRegistrationPeriod"); 
	
	DriveClientServer.SetListFilterItem(List, "EarningsDeductions.Employee", FilterEmployee, ValueIsFilled(FilterEmployee));
	DriveClientServer.SetListFilterItem(List, "Company", FilterCompany, ValueIsFilled(FilterCompany));
	DriveClientServer.SetListFilterItem(List, "StructuralUnit", FilterDepartment, ValueIsFilled(FilterDepartment));
	DriveClientServer.SetListFilterItem(List, "RegistrationPeriod", FilterRegistrationPeriod, ValueIsFilled(FilterRegistrationPeriod));
	
	RegistrationPeriodPresentation = Format(FilterRegistrationPeriod, "DF='MMMM yyyy'");
	
EndProcedure

&AtClient
// Procedure - form event handler ChoiceProcessing
//
Procedure ChoiceProcessing(ValueSelected, ChoiceSource)
	
	If TypeOf(ChoiceSource) = Type("ManagedForm")
		AND Find(ChoiceSource.FormName, "Calendar") > 0 Then
		
		FilterRegistrationPeriod = EndOfDay(ValueSelected);
		DriveClient.OnChangeRegistrationPeriod(ThisForm);
		DriveClientServer.SetListFilterItem(List, "RegistrationPeriod", FilterRegistrationPeriod, ValueIsFilled(FilterRegistrationPeriod));
		
	EndIf;
	
EndProcedure

#Region EventHandlersOfHeaderAttributes

&AtClient
Procedure FilterEmployeeOnChange(Item)
	DriveClientServer.SetListFilterItem(List, "EarningsDeductions.Employee", FilterEmployee, ValueIsFilled(FilterEmployee));
EndProcedure

&AtClient
// Procedure - event handler OnChange input field FilterCompany.
// The procedure determines the situation when after changing the date
// of a document this document is found in another period
// of documents enumeration, and in this case the procedure assigns new unique number to the document.
// Overrides the corresponding form parameter.
//
Procedure FilterCompanyOnChange(Item)
	DriveClientServer.SetListFilterItem(List, "Company", FilterCompany, ValueIsFilled(FilterCompany));
EndProcedure

&AtClient
// Procedure - event handler OnChange input field FilterDepartment.
// The procedure determines the situation when after changing the date
// of a document this document is found in another period
// of documents enumeration, and in this case the procedure assigns new unique number to the document.
// Overrides the corresponding form parameter.
//
Procedure FilterDepartmentOnChange(Item)
	DriveClientServer.SetListFilterItem(List, "StructuralUnit", FilterDepartment, ValueIsFilled(FilterDepartment));
EndProcedure

&AtClient
// Procedure event handler of field management RegistrationPeriod
//
Procedure FilterRegistrationPeriodTuning(Item, Direction, StandardProcessing)
	
	DriveClient.OnRegistrationPeriodRegulation(ThisForm, Direction);
	DriveClient.OnChangeRegistrationPeriod(ThisForm);
	DriveClientServer.SetListFilterItem(List, "RegistrationPeriod", FilterRegistrationPeriod, ValueIsFilled(FilterRegistrationPeriod));
	
EndProcedure

&AtClient
// Procedure event handler of field choice start RegistrationPeriod
//
Procedure FilterRegistrationPeriodStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing	 = False;
	
	CalendarDateOnOpen = ?(ValueIsFilled(FilterRegistrationPeriod), FilterRegistrationPeriod, DriveReUse.GetSessionCurrentDate());
	
	OpenForm("CommonForm.Calendar", DriveClient.GetCalendarGenerateFormOpeningParameters(CalendarDateOnOpen), ThisForm);
	
EndProcedure

&AtClient
// Procedure event handler of field data cleaning RegistrationPeriod
//
Procedure FilterRegistrationPeriodClearing(Item, StandardProcessing)
	
	FilterRegistrationPeriod = Undefined;
	DriveClient.OnChangeRegistrationPeriod(ThisForm);
	DriveClientServer.SetListFilterItem(List, "RegistrationPeriod", FilterRegistrationPeriod, ValueIsFilled(FilterRegistrationPeriod));
	
EndProcedure

#Region LibrariesHandlers

// StandardSubsystems.AdditionalReportsAndDataProcessors
&AtClient
Procedure Attachable_ExecuteAssignedCommand(Command)
	If Not AdditionalReportsAndDataProcessorsClient.ExecuteAllocatedCommandAtClient(ThisForm, Command.Name) Then
		ExecutionResult = Undefined;
		AdditionalReportsAndProcessingsExecuteAllocatedCommandAtServer(Command.Name, ExecutionResult);
		AdditionalReportsAndDataProcessorsClient.ShowCommandExecutionResult(ThisForm, ExecutionResult);
	EndIf;
EndProcedure

&AtServer
Procedure AdditionalReportsAndProcessingsExecuteAllocatedCommandAtServer(ItemName, ExecutionResult)
	AdditionalReportsAndDataProcessors.ExecuteAllocatedCommandAtServer(ThisForm, ItemName, ExecutionResult);
EndProcedure
// End StandardSubsystems.AdditionalReportsAndDataProcessors

// StandardSubsystems.Printing
&AtClient
Procedure Attachable_ExecutePrintCommand(Command)
	PrintManagementClient.ExecuteConnectedPrintCommand(Command, ThisObject, Items.List);
EndProcedure
// End StandardSubsystems.Printing

#EndRegion

#EndRegion

#EndRegion
