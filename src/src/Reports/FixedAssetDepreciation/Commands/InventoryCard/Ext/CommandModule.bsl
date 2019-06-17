&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	OpenForm(
		"Report.FixedAssetDepreciation.Form",
		New Structure("PurposeUseKey, Filter, GenerateOnOpen, VariantKey", CommandParameter, New Structure("FixedAsset", CommandParameter), True, "Card"),
		,
		"FixedAsset=" + CommandParameter,
		CommandExecuteParameters.Window
	);
	
EndProcedure
