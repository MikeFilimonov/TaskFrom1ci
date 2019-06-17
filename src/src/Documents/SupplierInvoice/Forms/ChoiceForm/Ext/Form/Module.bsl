#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	DriveServer.OverrideStandartGenerateCustomsDeclarationCommand(ThisObject);
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Attachable_GenerateCustomsDeclaration(Command)
	DriveClient.CustomsDeclarationGenerationBasedOnSupplierInvoice(Items.List);
EndProcedure

#EndRegion