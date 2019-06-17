#Region FormEventsHandlers

&AtClient
Procedure AfterWrite(WriteParameters)
	
	Notify("Write_SMSSendingSettings", WriteParameters, ThisObject);
	
EndProcedure

#EndRegion
