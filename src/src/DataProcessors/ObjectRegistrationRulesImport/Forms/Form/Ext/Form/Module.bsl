
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	Raise NStr("en = 'Data processor is not intended for direct usage.'");
	
EndProcedure

#EndRegion