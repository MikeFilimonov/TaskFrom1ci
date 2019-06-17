#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region InfobaseUpdate

Procedure FillPredefinedItemsData() Export
	
	PredefinedItems = New Array;
	
	ItemAttributes = "Ref, Rate, NotTaxable, Calculated";
	
	PredefinedItems.Add(New Structure(ItemAttributes, Exempt, 0, True, False));
	PredefinedItems.Add(New Structure(ItemAttributes, ZeroRate, 0, False, False));
	
	For Each ItemRequiredData In PredefinedItems Do
		
		ItemActualData = CommonUse.ObjectAttributesValues(ItemRequiredData.Ref, ItemAttributes);
		
		If Not CommonUse.DataMatch(ItemRequiredData, ItemActualData) Then
			
			ItemObj = ItemRequiredData.Ref.GetObject();
			
			FillPropertyValues(ItemObj, ItemRequiredData, , "Ref");
			
			ItemObj.Write();
			
		EndIf;
		
	EndDo;
	
EndProcedure

#EndRegion

#EndIf