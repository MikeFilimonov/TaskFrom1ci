
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	// StandardSubsystems.PerformanceMeasurement
	PerformanceEstimationClientServer.StartTimeMeasurement("DocumentJournalBankDocuments");
	// End StandardSubsystems.PerformanceMeasurement
	
	OpenForm("DocumentJournal.BankDocuments.ListForm", , CommandExecuteParameters.Source, CommandExecuteParameters.Uniqueness, CommandExecuteParameters.Window);
	
EndProcedure
