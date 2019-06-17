
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	FilterStructure = New Structure("StructuralUnitType", PredefinedValue("Enum.BusinessUnitsTypes.Department"));
	
	FormParameters = New Structure;
	FormParameters.Insert("Filter", FilterStructure);
	FormParameters.Insert("PurposeUseKey", "Departments");
	
	OpenForm("Catalog.BusinessUnits.ListForm",
		FormParameters,
		CommandExecuteParameters.Source,
		CommandExecuteParameters.Uniqueness,
		CommandExecuteParameters.Window,
		CommandExecuteParameters.URL
	);
	
EndProcedure
