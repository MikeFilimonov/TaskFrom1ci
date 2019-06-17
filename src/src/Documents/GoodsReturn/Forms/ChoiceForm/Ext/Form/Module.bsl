
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then 
		Return;
	EndIf;
	
	AdditionalCreateParameters = New Structure;
	AdditionalCreateParameters.Insert("HideOperationKind", True);
	
	If Parameters.PurposeUseKey = "ToSupplier" Then
		AdditionalCreateParameters.Insert("OperationKind", Enums.OperationTypesGoodsReturn.ToSupplier);
	ElsIf Parameters.PurposeUseKey = "FromCustomer" Then
		AdditionalCreateParameters.Insert("OperationKind", Enums.OperationTypesGoodsReturn.FromCustomer);
	EndIf;
	
	Items.List.AdditionalCreateParameters = New FixedStructure(AdditionalCreateParameters);

	UseGoodsReturnFromCustomer	= GetFunctionalOption("UseGoodsReturnFromCustomer");
	UseGoodsReturnToSupplier	= GetFunctionalOption("UseGoodsReturnToSupplier");
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisForm, Items.ImportantCommandsGroup);
	// End StandardSubsystems.Printing
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	FormManagement();
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// StandardSubsystems.Printing
&AtClient
Procedure Attachable_ExecutePrintCommand(Command)
	
	PrintManagementClient.ExecuteConnectedPrintCommand(Command, ThisObject, Items.List);
	
EndProcedure

// End StandardSubsystems.Printing

&AtClient
Procedure FormManagement()
	
	CommonUseClientServer.SetFormItemProperty(Items, "SalesDocument", "Visible",	UseGoodsReturnFromCustomer);
	CommonUseClientServer.SetFormItemProperty(Items, "SupplierInvoice", "Visible",	UseGoodsReturnToSupplier);
	
EndProcedure

#EndRegion