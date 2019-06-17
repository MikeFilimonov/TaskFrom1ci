#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

// Procedure - FillCheckProcessing event handler.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	UsedCurrencies = GetFunctionalOption("ForeignExchangeAccounting");
	
	If AssignmentCondition = Enums.DiscountCondition.ForOneTimeSalesVolume Then
		
		CheckedAttributes.Clear();
		CheckedAttributes.Add("RestrictionArea");
		CheckedAttributes.Add("UseRestrictionCriterionForSalesVolume");
		CheckedAttributes.Add("ComparisonType");
		If  UseRestrictionCriterionForSalesVolume = Enums.DiscountSalesAmountLimit.Amount 
			AND UsedCurrencies 
		Then
			CheckedAttributes.Add("RestrictionCurrency");
		EndIf;
		
	ElsIf AssignmentCondition = Enums.DiscountCondition.ForKitPurchase Then
		
		CheckedAttributes.Clear();
		CheckedAttributes.Add("PurchaseKit");
		CheckedAttributes.Add("PurchaseKit.Products");
		CheckedAttributes.Add("PurchaseKit.PackingsQuantity");
		CheckedAttributes.Add("PurchaseKit.Quantity");
		
	EndIf;
	
	CheckedAttributes.Add("Description");
	CheckedAttributes.Add("AssignmentCondition");
	
EndProcedure

// Procedure - BeforeWrite event handler.
//
Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Not IsFolder Then
		TakeIntoAccountSaleOfOnlyParticularProductsList = AssignmentCondition = Enums.DiscountCondition.ForOneTimeSalesVolume AND 
																(SalesFilterByProducts.Count() > 0);
															EndIf;
	
	If AssignmentCondition = Enums.DiscountCondition.ForKitPurchase Then
		SalesFilterByProducts.Clear();
	ElsIf AssignmentCondition = Enums.DiscountCondition.ForOneTimeSalesVolume Then
		PurchaseKit.Clear();
	EndIf;
	
EndProcedure

// Procedure - FillingProcessor event handler.
//
Procedure Filling(FillingData, StandardProcessing)
	
	If Not IsFolder Then
		RestrictionCurrency = Constants.PresentationCurrency.Get();
	EndIf;
	
EndProcedure

#EndRegion

#EndIf
