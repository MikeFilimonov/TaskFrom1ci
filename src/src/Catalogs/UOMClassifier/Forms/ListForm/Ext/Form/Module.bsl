#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Items.List.ChoiceMode = Parameters.ChoiceMode;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure ListNewWriteProcessing(NewObject, Source, StandardProcessing)	
	Items.List.CurrentRow = NewObject;	
EndProcedure

#EndRegion