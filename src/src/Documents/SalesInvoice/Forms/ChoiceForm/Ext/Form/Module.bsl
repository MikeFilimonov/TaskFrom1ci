#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	DriveServer.OverrideStandartGenerateGoodsIssueCommand(ThisObject);
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure Attachable_GenerateGoodsIssue(Command)
	DriveClient.GoodsIssueGenerationBasedOnSalesInvoice(Items.List);
EndProcedure

#EndRegion