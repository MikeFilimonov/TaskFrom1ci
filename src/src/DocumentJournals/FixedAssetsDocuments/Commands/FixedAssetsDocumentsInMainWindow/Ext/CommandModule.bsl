&AtClient
Function MainWindow()
	
	MainWindow = Undefined;
	
	Windows = GetWindows();
	If Windows <> Undefined Then
		For Each Window In Windows Do
			If Window.IsMain Then
				MainWindow = Window;
				Break;
			EndIf;
		EndDo;
	EndIf;
	
	Return MainWindow;
	
EndFunction

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	FormParameters = New Structure("FixedAsset", CommandParameter);
	OpenForm("DocumentJournal.FixedAssetsDocuments.ListForm", FormParameters, CommandExecuteParameters.Source, CommandExecuteParameters.Uniqueness, MainWindow());
	
EndProcedure
