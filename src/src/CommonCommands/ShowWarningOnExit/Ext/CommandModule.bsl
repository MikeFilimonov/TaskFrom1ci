
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	Parameters = New Structure;
	
	Parameters.Insert("Cancel",						False);
	Parameters.Insert("Warnings",					StandardSubsystemsClient.ClientParameter("ShowWarningOnExit"));
	Parameters.Insert("InteractiveDataProcessor",	Undefined); // NotifyDescription.
	Parameters.Insert("ContinuationProcessor",		Undefined); // NotifyDescription.
	Parameters.Insert("ContinuousExecution",		True);
	Parameters.Insert("CompletionAlert",			Undefined);
	Parameters.Insert("CompletionProcessor", 		New NotifyDescription(
		"ActionsBeforeExitCompletionProcessor", StandardSubsystemsClient, Parameters));
	
	StandardSubsystemsClient.ActionsBeforeSystemExit(Parameters);
	
EndProcedure
