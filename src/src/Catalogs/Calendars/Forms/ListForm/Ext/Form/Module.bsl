
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	If Parameters.ChoiceMode Then
		Items.List.ChoiceMode = True;
	EndIf;
	
	CommonUseClientServer.SetFilterDynamicListItem(
		List, "ScheduleOwner", , DataCompositionComparisonType.NotFilled, , ,
		DataCompositionSettingsItemViewMode.Normal);
EndProcedure

#EndRegion
