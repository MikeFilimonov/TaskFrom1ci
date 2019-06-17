
#Region FormEventsHandlers

&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	FilterSendingMethod = Settings.Get("FilterSendingMethod");
	FilterState = Settings.Get("FilterState");
	FilterResponsible = Settings.Get("FilterResponsible");
	
	DriveClientServer.SetListFilterItem(List, "SendingMethod", FilterSendingMethod, ValueIsFilled(FilterSendingMethod));
	DriveClientServer.SetListFilterItem(List, "Status", FilterState, ValueIsFilled(FilterState));
	DriveClientServer.SetListFilterItem(List, "Responsible", FilterResponsible, ValueIsFilled(FilterResponsible));
	
EndProcedure

#EndRegion

#Region FormAttributesEventsHandlers

&AtClient
Procedure FilterSendingMethodOnChange(Item)
	
	DriveClientServer.SetListFilterItem(List, "SendingMethod", FilterSendingMethod, ValueIsFilled(FilterSendingMethod));
	
EndProcedure

&AtClient
Procedure FilterStateOnChange(Item)
	
	DriveClientServer.SetListFilterItem(List, "State", FilterState, ValueIsFilled(FilterState));
	
EndProcedure

&AtClient
Procedure FilterResponsibleOnChange(Item)
	
	DriveClientServer.SetListFilterItem(List, "Responsible", FilterResponsible, ValueIsFilled(FilterResponsible));
	
EndProcedure

#EndRegion
