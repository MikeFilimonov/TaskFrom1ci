
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Items.List.ChoiceMode = Parameters.ChoiceMode;
	
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisObject);
	
	PrintManagement.OnCreateAtServer(ThisObject);
	
EndProcedure

#EndRegion

#Region Private

#Region LibrariesHandlers

&AtClient
Procedure Attachable_ExecutePrintCommand(Command)
	PrintManagementClient.ExecuteConnectedPrintCommand(Command, ThisObject, Items.List);
EndProcedure

#EndRegion

#EndRegion
