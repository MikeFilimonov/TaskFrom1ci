#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	AttachedFiles.CallFormOpeningException(ThisForm);
	
EndProcedure

#EndRegion
