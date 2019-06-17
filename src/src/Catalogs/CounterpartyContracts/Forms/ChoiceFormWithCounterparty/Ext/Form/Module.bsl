
&AtServer
// Procedure - OnCreateAtServer event handler.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Not Drivereuse.CounterpartyContractsControlNeeded() Then
		
		Items.ListCompanies.Visible = False;
		
	EndIf;
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisForm, CommandBar);
	// End StandardSubsystems.Printing
	
EndProcedure

&AtClient
Procedure ValueChoiceList(Item, Value, StandardProcessing)
	
	Close(Value);
	
EndProcedure

#Region FormCommandHandlers

// StandardSubsystems.Printing
&AtClient
Procedure Attachable_ExecutePrintCommand(Command)
	PrintManagementClient.ExecuteConnectedPrintCommand(Command, ThisObject, Items.List.CurrentData);
EndProcedure
// End StandardSubsystems.Printing

#EndRegion
