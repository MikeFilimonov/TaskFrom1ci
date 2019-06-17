
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	// StandardSubsystems.PerformanceMeasurement
	PerformanceEstimationClientServer.StartTimeMeasurement("DocumentUpdatingRegistersOpen");
	// End StandardSubsystems.PerformanceMeasurement
	
	OpenForm("Document.RegistersCorrection.Form.DocumentForm", , CommandExecuteParameters.Source, CommandExecuteParameters.Uniqueness, CommandExecuteParameters.Window);
	
EndProcedure
