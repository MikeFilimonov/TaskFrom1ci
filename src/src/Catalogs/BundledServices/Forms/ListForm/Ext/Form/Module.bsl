#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("Product") Then
		
		DriveClientServer.SetListFilterItem(List, "WorksAndServices.Products", Parameters.Product, ValueIsFilled(Parameters.Product));
		
	EndIf;
	
EndProcedure

#EndRegion
