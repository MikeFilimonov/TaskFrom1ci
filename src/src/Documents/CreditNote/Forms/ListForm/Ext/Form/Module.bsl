
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then 
		Return;
	EndIf;
	
	UseGoodsReturnFromCustomer = GetFunctionalOption("UseGoodsReturnFromCustomer");
	CommonUseClientServer.SetFormItemProperty(Items, "FormDocumentGoodsReturnCreateBasedOn", "Visible", UseGoodsReturnFromCustomer);
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisForm, Items.ImportantCommandsGroup);
	// End StandardSubsystems.Printing
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// StandardSubsystems.Printing
&AtClient
Procedure Attachable_ExecutePrintCommand(Command)
	
	PrintManagementClient.ExecuteConnectedPrintCommand(Command, ThisObject, Items.List);
	
EndProcedure
// End StandardSubsystems.Printing

#EndRegion