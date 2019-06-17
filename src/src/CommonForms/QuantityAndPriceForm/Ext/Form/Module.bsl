
&AtClient
Procedure OK(Command)
	
	Close(New Structure("MeasurementUnit, Quantity, Price", MeasurementUnit, Quantity, Price));
	
EndProcedure

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	FillPropertyValues(ThisForm, Parameters.FillValue);
	
	If Parameters.FillValue.Property("UOMOwner") Then
		
		Products 		= Parameters.FillValue.UOMOwner;
		MeasurementUnit	= ?(ValueIsFilled(Products), Products.MeasurementUnit, Catalogs.UOM.EmptyRef());
		
	EndIf;
	
	Items.Price.Enabled = PriceAvailable;
	
EndProcedure
