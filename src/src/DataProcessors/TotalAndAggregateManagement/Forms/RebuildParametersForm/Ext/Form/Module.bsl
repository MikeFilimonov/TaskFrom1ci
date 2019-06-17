
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	RelativeSize = Parameters.RelativeSize;
	MinimalEffect = Parameters.MinimalEffect;
	Items.MinimalEffect.Visible = Parameters.RebuildingMode;
	Title = ?(Parameters.RebuildingMode,
	              NStr("en = 'Rebuild parameters'"),
	              NStr("en = 'Parameter of optimal aggregate calculation'"));
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure OK(Command)
	
	ChoiceResult = New Structure("RelativeSize, MinimalEffect");
	FillPropertyValues(ChoiceResult, ThisObject);
	
	NotifyChoice(ChoiceResult);
	
EndProcedure

#EndRegion
