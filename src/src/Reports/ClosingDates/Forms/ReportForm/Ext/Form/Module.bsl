
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	Properties = ClosingDatesServiceReUse.SectionsProperties();
	
	// Report version setting.
	If Parameters.BySectionsObjects = True Then
		
		If Properties.ShowSections AND Not Properties.AllSectionsWithoutObjects Then
			SetCurrentVariant("ProhibitionDateChangeBySectionsObjectsForUsers");
			
		ElsIf Properties.AllSectionsWithoutObjects Then
			SetCurrentVariant("ClosingDatesBySectionsForUsers");
		Else
			SetCurrentVariant("ClosingDatesByObjectsForUsers");
		EndIf;
	Else
		If Properties.ShowSections AND Not Properties.AllSectionsWithoutObjects Then
			SetCurrentVariant("ClosingDatesByUsers");
			
		ElsIf Properties.AllSectionsWithoutObjects Then
			SetCurrentVariant("ClosingDatesByUsersWithoutObjects");
		Else
			SetCurrentVariant("ClosingDatesByUsersWithoutSections");
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion
