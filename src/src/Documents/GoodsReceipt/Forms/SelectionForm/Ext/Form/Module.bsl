
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	DriveServer.OverrideStandartGenerateSupplierInvoiceCommand(ThisForm);
	
	OrderFilter = Undefined;
	Parameters.Property("OrderFilter", OrderFilter);
	List.Parameters.SetParameterValue("OrderFilter", OrderFilter);
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.Printing
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure Attachable_GenerateSupplierInvoice(Command)
	DriveClient.SupplierInvoiceGenerationBasedOnGoodsReceipt(Items.List);
EndProcedure

#Region LibrariesHandlers

// StandardSubsystems.Printing
&AtClient
Procedure Attachable_ExecutePrintCommand(Command)
	PrintManagementClient.ExecuteConnectedPrintCommand(Command, ThisObject, Items.List);
EndProcedure
// End StandardSubsystems.Printing

#EndRegion

#EndRegion
