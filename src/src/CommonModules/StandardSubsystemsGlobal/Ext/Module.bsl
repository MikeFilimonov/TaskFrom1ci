////////////////////////////////////////////////////////////////////////////////
// The subsystem "Basic functionality".
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProceduresAndFunctions

// Continues to complete in the mode
// of interaction with user after configuring Cancel = True.
//
Procedure WaitHandlerInteractiveProcessingBeforeExit() Export
	
	StandardSubsystemsClient.StartInteractiveProcessingBeforeExit();
	
EndProcedure

// Continues to launch in the mode of interaction with user.
Procedure WaitAtSystemStartHandler() Export
	
	StandardSubsystemsClient.OnStart(, False);
	
EndProcedure

Procedure ShowNotificationOnExit() Export
	
	Warnings = StandardSubsystemsClient.ClientParameter("ShowWarningOnExit");
	
	Explanation = NStr("en = 'and make additional actions'");
	If Warnings.Count() = 1 
		AND NOT IsBlankString(Warnings[0].HyperlinkText) Then
			Explanation = Warnings[0].HyperlinkText;
	EndIf;
	
	ShowUserNotification(NStr("en = 'Click to exit'"), 
		"e1cib/command/CommonCommand.ShowWarningOnExit",
		Explanation);
		
EndProcedure

#EndRegion
