
#Region FormCommandsHandlers

// Procedure form event handler OnCreateAtServer
//
&AtServer
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

// Predefined procedure OnOpen
//
&AtClient
Procedure OnOpen(Cancel)
	
	DriveClientServer.SetListFilterItem(List, "Counterparty", Counterparty, ValueIsFilled(Counterparty));
	DriveClientServer.SetListFilterItem(List, "Responsible", Responsible, ValueIsFilled(Responsible));
	DriveClientServer.SetListFilterItem(List, "Status", Status, ValueIsFilled(Status));
	
EndProcedure

#EndRegion

#Region FormAttributesEventsHandlers

// Procedure - event handler "OnChange" field "CounterpartyFilter"
//
&AtClient
Procedure CounterpartyFilterOnChange(Item)
	
	DriveClientServer.SetListFilterItem(List, "Counterparty", Counterparty, ValueIsFilled(Counterparty));
	
EndProcedure

// Procedure - event handler "OnChange" field "ResponsibleFilter"
//
&AtClient
Procedure ResponsibleFilterOnChange(Item)
	
	DriveClientServer.SetListFilterItem(List, "Responsible", Responsible, ValueIsFilled(Responsible));
	
EndProcedure

// Procedure - event handler "OnChange" field "StatusFilter"
//
&AtClient
Procedure StatusFilterOnChange(Item)
	
	DriveClientServer.SetListFilterItem(List, "Status", Status, ValueIsFilled(Status));
	
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