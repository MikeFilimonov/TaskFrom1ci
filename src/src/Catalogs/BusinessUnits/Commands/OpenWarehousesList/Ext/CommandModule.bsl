
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	FilterArray	= New Array;
	FilterArray.Add(PredefinedValue("Enum.BusinessUnitsTypes.Warehouse"));
	FilterArray.Add(PredefinedValue("Enum.BusinessUnitsTypes.Retail"));
	FilterArray.Add(PredefinedValue("Enum.BusinessUnitsTypes.RetailEarningAccounting"));
	
	FilterStructure	= New Structure("StructuralUnitType", FilterArray);
	
	FormParameters	= New Structure;
	FormParameters.Insert("Filter", FilterStructure);
	FormParameters.Insert("PurposeUseKey", "Warehouses");
	
	OpenForm("Catalog.BusinessUnits.ListForm",
		FormParameters,
		CommandExecuteParameters.Source,
		CommandExecuteParameters.Uniqueness,
		CommandExecuteParameters.Window,
		CommandExecuteParameters.URL
	);
	
EndProcedure
