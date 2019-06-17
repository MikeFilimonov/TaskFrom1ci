#Region EventsHandlers

&AtServer
// Procedure - OnCreateAtServer event handler.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// StandardSubsystems.ObjectVersioning
	ObjectVersioning.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.ObjectVersioning
	
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
	
	FilterCompany 		= Settings.Get("FilterCompany");
	PettyCashFilter 				= Settings.Get("PettyCashFilter");
	FilterTypeOperations 		= Settings.Get("FilterTypeOperations"); 
	
	DriveClientServer.SetListFilterItem(List, "Company", FilterCompany, ValueIsFilled(FilterCompany));
	DriveClientServer.SetListFilterItem(List, "PettyCash", PettyCashFilter, ValueIsFilled(PettyCashFilter));
	DriveClientServer.SetListFilterItem(List, "OperationKind", FilterTypeOperations, ValueIsFilled(FilterTypeOperations));
	
EndProcedure

&AtClient
Procedure FilterCompanyOnChange(Item)
	DriveClientServer.SetListFilterItem(List, "Company", FilterCompany, ValueIsFilled(FilterCompany));
EndProcedure

&AtClient
Procedure FilterPettyCashOnChange(Item)
	DriveClientServer.SetListFilterItem(List, "PettyCash", PettyCashFilter, ValueIsFilled(PettyCashFilter));
EndProcedure

&AtClient
Procedure FilterOperationKindOnChange(Item)
	DriveClientServer.SetListFilterItem(List, "OperationKind", FilterTypeOperations, ValueIsFilled(FilterTypeOperations));
EndProcedure

#EndRegion

#Region PerformanceMeasurements

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	KeyOperation = "FormCreatingCashVoucher";
	PerformanceEstimationClientServer.StartTimeMeasurement(KeyOperation);
	
EndProcedure

&AtClient
Procedure ListBeforeRowChange(Item, Cancel)
	
	KeyOperation = "FormOpeningCashVoucher";
	PerformanceEstimationClientServer.StartTimeMeasurement(KeyOperation);
	
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