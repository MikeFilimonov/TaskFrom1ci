﻿
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	AdditionalReportsAndDataProcessorsClient.OpenFormOfCommandsOfAdditionalReportsAndDataProcessors(
			CommandParameter,
			CommandExecuteParameters,
			AdditionalReportsAndDataProcessorsClientServer.DataProcessorKindAdditionalInformationProcessor(),
			"Services");
	
EndProcedure
