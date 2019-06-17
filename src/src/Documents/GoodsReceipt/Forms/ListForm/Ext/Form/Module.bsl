
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	DriveServer.OverrideStandartGenerateSupplierInvoiceCommand(ThisForm);
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisObject, Items.GroupImportantCommandsGoodsReceipt);
	// End StandardSubsystems.Printing
	
EndProcedure

#EndRegion

#Region FormItemEventHandlers

&AtClient
Procedure FilterWarehouseStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	Filter = New Structure("StructuralUnitType", PredefinedValue("Enum.BusinessUnitsTypes.Warehouse"));
	ParametersStructure = New Structure("ChoiceMode, Filter", True, Filter);
	OpenForm("Catalog.BusinessUnits.ChoiceForm", ParametersStructure, Item);
	
EndProcedure

&AtClient
Procedure FilterStatusOnChange(Item)
	DriveClientServer.SetListFilterItem(List, "Status", FilterStatus, ValueIsFilled(FilterStatus));
EndProcedure

&AtClient
Procedure FilterCounterpartyOnChange(Item)
	DriveClientServer.SetListFilterItem(List, "Counterparty", FilterCounterparty, ValueIsFilled(FilterCounterparty));
EndProcedure

&AtClient
Procedure FilterWarehouseOnChange(Item)
	DriveClientServer.SetListFilterItem(List, "StructuralUnit", FilterWarehouse, ValueIsFilled(FilterWarehouse));
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
