
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
			SetCurrentVariant("ClosingDatesOfDataImportBySectionsObjectsForUsers");
			
		ElsIf Properties.AllSectionsWithoutObjects Then
			SetCurrentVariant("ClosingDatesOfDataImportBySectionsForUsers");
		Else
			SetCurrentVariant("ClosingDatesOfDataImportByObjectsForUsers");
		EndIf;
	Else
		If Properties.ShowSections AND Not Properties.AllSectionsWithoutObjects Then
			SetCurrentVariant("ClosingDatesOfDataImportByUsers");
			
		ElsIf Properties.AllSectionsWithoutObjects Then
			SetCurrentVariant("ClosingDatesOfDataImportByUsersWithoutObjects");
		Else
			SetCurrentVariant("ClosingDatesOfDataImportByUsersWithoutSections");
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion
