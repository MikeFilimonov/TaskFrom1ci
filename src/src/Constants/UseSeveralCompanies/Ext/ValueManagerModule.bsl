#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

Procedure OnWrite(Cancel)
	
	SetPrivilegedMode(True);
	
	Constants.UseOneCompany.Set(NOT Value);
	
EndProcedure

#EndRegion

#EndIf
