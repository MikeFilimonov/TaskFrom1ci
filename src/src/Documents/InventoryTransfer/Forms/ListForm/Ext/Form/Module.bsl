
#Region ProcedureFormEventHandlers

// Procedure - Form event handler "OnCreateAtServer".
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Setting the method of Business unit selection depending on FO.
	If Not Constants.UseSeveralDepartments.Get()
		AND Not Constants.UseSeveralWarehouses.Get() Then
		
		Items.FilterRecipient.ListChoiceMode = True;
		Items.FilterRecipient.ChoiceList.Add(Catalogs.BusinessUnits.MainWarehouse);
		Items.FilterRecipient.ChoiceList.Add(Catalogs.BusinessUnits.MainDepartment);
		
		Items.FilterWarehouse.ListChoiceMode = True;
		Items.FilterWarehouse.ChoiceList.Add(Catalogs.BusinessUnits.MainDepartment);
		Items.FilterWarehouse.ChoiceList.Add(Catalogs.BusinessUnits.MainWarehouse);
		
	EndIf;
	
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
	FilterWarehouse 				= Settings.Get("FilterWarehouse");
	FilterRecipient 		= Settings.Get("FilterRecipient");
	
	DriveClientServer.SetListFilterItem(List, "Company", FilterCompany, ValueIsFilled(FilterCompany));
	DriveClientServer.SetListFilterItem(List, "StructuralUnit", FilterWarehouse, ValueIsFilled(FilterWarehouse));
	DriveClientServer.SetListFilterItem(List, "StructuralUnitPayee", FilterRecipient, ValueIsFilled(FilterRecipient));
	
EndProcedure

#Region AttributeEventHandlers

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
// Procedure - event handler OnChange input field FilterWarehouse.
// The procedure determines the situation when after changing the date
// of a document this document is found in another period
// of documents enumeration, and in this case the procedure assigns new unique number to the document.
// Overrides the corresponding form parameter.
//
Procedure FilterWarehouseOnChange(Item)
	DriveClientServer.SetListFilterItem(List, "StructuralUnit", FilterWarehouse, ValueIsFilled(FilterWarehouse));
EndProcedure

&AtClient
// Procedure - event handler OnChange input field FilterRecipient.
// The procedure determines the situation when after changing the date
// of a document this document is found in another period
// of documents enumeration, and in this case the procedure assigns new unique number to the document.
// Overrides the corresponding form parameter.
//
Procedure FilterRecipientOnChange(Item)
	DriveClientServer.SetListFilterItem(List, "StructuralUnitPayee", FilterRecipient, ValueIsFilled(FilterRecipient));
EndProcedure

#Region PerformanceMeasurements

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	KeyOperation = "FormCreatingInventoryTransfer";
	PerformanceEstimationClientServer.StartTimeMeasurement(KeyOperation);
	
EndProcedure

&AtClient
Procedure ListBeforeRowChange(Item, Cancel)
	
	KeyOperation = "FormOpeningInventoryTransfer";
	PerformanceEstimationClientServer.StartTimeMeasurement(KeyOperation);
	
EndProcedure

#EndRegion

#EndRegion

#Region LibrariesHandlers

// StandardSubsystems.Printing
&AtClient
Procedure Attachable_ExecutePrintCommand(Command)
	PrintManagementClient.ExecuteConnectedPrintCommand(Command, ThisObject, Items.List);
EndProcedure
// End StandardSubsystems.Printing

#EndRegion

#EndRegion
