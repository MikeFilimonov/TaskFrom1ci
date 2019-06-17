
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Form opening from work order (PM Performers).
	If Parameters.Property("MultiselectList") Then
		Items.List.MultipleChoice  = True;
	EndIf;
	
EndProcedure

#EndRegion

