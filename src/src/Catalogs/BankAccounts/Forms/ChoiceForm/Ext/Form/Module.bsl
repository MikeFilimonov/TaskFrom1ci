
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("SettlementsInStandardUnits")
		AND Parameters.SettlementsInStandardUnits Then
		
		DriveClientServer.SetListFilterItem(List, "Owner", Parameters.Owner);
		DriveClientServer.SetListFilterItem(List, "CashCurrency", Parameters.CurrenciesList, True, DataCompositionComparisonType.InList);
		
	EndIf;
	
EndProcedure

#EndRegion
