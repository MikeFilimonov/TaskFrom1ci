#If Server OR ThickClientOrdinaryApplication OR ExternalConnection Then

#Region EventHandlers

Procedure Filling(FillingData, StandardProcessing)
	
	If TypeOf(FillingData) = Type("Structure") Then
		
		For Each SetRow In ThisObject Do
			FillPropertyValues(SetRow,FillingData);
		EndDo;
		
	EndIf;
	
EndProcedure

#EndRegion

#EndIf