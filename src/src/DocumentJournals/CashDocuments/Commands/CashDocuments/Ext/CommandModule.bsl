
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	// StandardSubsystems.PerformanceMeasurement
	PerformanceEstimationClientServer.StartTimeMeasurement("DocumentJournalCashDocuments");
	// End StandardSubsystems.PerformanceMeasurement
	
	OpenForm("DocumentJournal.CashDocuments.ListForm", , CommandExecuteParameters.Source, CommandExecuteParameters.Uniqueness, CommandExecuteParameters.Window);
	
EndProcedure
