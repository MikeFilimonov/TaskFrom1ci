&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	OpenForm(
		"Report.FixedAssetUsage.Form",
		New Structure("UsePurposeKey, Filter, GenerateOnOpen", CommandParameter, New Structure("FixedAsset", CommandParameter), True),
		,
		"FixedAsset=" + CommandParameter,
		CommandExecuteParameters.Window
	);
	
EndProcedure
