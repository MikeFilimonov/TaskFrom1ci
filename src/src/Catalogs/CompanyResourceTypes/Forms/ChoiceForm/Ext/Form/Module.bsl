
#Region ProcedureFormEventHandlers

// Procedure - event handler OnCreateAtServer of the form.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	AllResources = Catalogs.CompanyResourceTypes.AllResources;
	DriveClientServer.SetListFilterItem(List, "Ref", AllResources, True, DataCompositionComparisonType.NotEqual);
	
EndProcedure

#EndRegion
