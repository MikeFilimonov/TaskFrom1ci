#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	AttachedFiles.OnCreateAtServerAttachedFile(ThisForm);
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure Attachable_GoToFileForm(Command)
	
	AttachedFilesClient.GoToAttachedFileForm(ThisForm);
	
EndProcedure

#EndRegion
