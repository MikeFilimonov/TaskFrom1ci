﻿#Region EventsHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	AdditionalReportsAndDataProcessorsClient.OpenFormOfCommandsOfAdditionalReportsAndDataProcessors(
		CommandParameter,
		CommandExecuteParameters,
		AdditionalReportsAndDataProcessorsClientServer.DataProcessorKindAdditionalReport(),
		"SetupAndAdministration");
	
EndProcedure

#EndRegion
