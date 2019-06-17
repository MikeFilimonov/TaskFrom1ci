
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Products = Parameters.Products;
	Quantity = Parameters.Quantity;
	MeasurementUnit = Parameters.MeasurementUnit;
	Factor = Parameters.Factor;
	Price = Parameters.Price;
	
	SetFormItemsProperties(Parameters.SelectionSettingsCache);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	AmountCalculation();
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandler

&AtClient
Procedure QuantityOnChange(Item)
	
	AmountCalculation();
	
EndProcedure

&AtClient
Procedure MeasurementUnitOnChange(Item)
	
	If TypeOf(MeasurementUnit) = Type("CatalogRef.UOM")
		AND ValueIsFilled(MeasurementUnit) Then
		
		NewFactor = GetUOMFactor(MeasurementUnit);
		
	Else
		
		NewFactor = 1;
		
	EndIf;
	
	If Factor <> 0 AND Price <> 0 Then
		
		Price = Price * NewFactor / Factor;
		
	EndIf;
	
	Factor = NewFactor;
	
	AmountCalculation();
	
EndProcedure

&AtClient
Procedure PriceOnChange(Item)
	
	AmountCalculation();
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure OK(Command)
	
	Result = New Structure;
	
	Result.Insert("Quantity", Quantity);
	Result.Insert("MeasurementUnit", MeasurementUnit);
	Result.Insert("Factor", Factor);
	Result.Insert("Price", Price);
	
	Close(Result);
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtServer
Procedure SetFormItemsProperties(SelectionSettingsCache)
	
	CommonUseClientServer.SetFormItemProperty(Items, "QuantityGroup", "Enabled", SelectionSettingsCache.RequestQuantity);
	CommonUseClientServer.SetFormItemProperty(Items, "Price", "Enabled",
											SelectionSettingsCache.RequestPrice AND SelectionSettingsCache.AllowedToChangeAmount AND SelectionSettingsCache.ShowPrice);
	
	If SelectionSettingsCache.RequestQuantity Then
		If SelectionSettingsCache.RequestPrice AND SelectionSettingsCache.AllowedToChangeAmount Then	
			TitleText = NStr("en = 'Input quantity and price'");	
		Else
			TitleText = NStr("en = 'Input quantity'");
		EndIf;
	Else
		TitleText = NStr("en = 'Input price'");
	EndIf;
	
	Title = TitleText;
	
EndProcedure

&AtClient
Procedure AmountCalculation()
	Amount = Quantity * Price;
EndProcedure

&AtServerNoContext
Function GetUOMFactor(MeasurementUnit)
	
	Return MeasurementUnit.Factor;
	
EndFunction

#EndRegion