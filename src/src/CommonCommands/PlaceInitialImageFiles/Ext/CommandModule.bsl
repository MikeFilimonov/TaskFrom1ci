&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	If Not AreFilesInVolumes() Then
		ShowMessageBox(, NStr("en = 'No files in volumes.'"));
		Return;
	EndIf;
	
	OpenForm("CommonForm.SelectInitialImageFileLocation", , CommandExecuteParameters.Source);
	
EndProcedure

&AtServer
Function AreFilesInVolumes()
	
	Return FileFunctionsService.AreFilesInVolumes();
	
EndFunction
