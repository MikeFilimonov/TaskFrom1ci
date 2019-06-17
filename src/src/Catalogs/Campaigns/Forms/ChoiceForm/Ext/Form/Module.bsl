#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	List.Parameters.SetParameterValue("CurrentDate", CurrentSessionDate());
EndProcedure

#EndRegion