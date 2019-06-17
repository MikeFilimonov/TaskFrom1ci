#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region PredeterminedProceduresEventsHandlers

// Procedure - BeforeWrite event handler.
//
Procedure BeforeWrite(Cancel)
	
	If DiscountKindForDiscountCards = Enums.DiscountTypeForDiscountCards.FixedDiscount Then
		DiscountsShortContent = "" + Discount + "%";
		PeriodKind = Enums.PeriodTypeForCumulativeDiscounts.EmptyRef();
		Periodicity = Enums.Periodicity.EmptyRef();
	Else
		FirstPass = True;
		CurContent = "";
		For Each CurRow In ProgressiveDiscountLimits Do
		
			If FirstPass Then
				FirstPass = False;
			Else
				CurContent = CurContent + "; ";
			EndIf;
			CurContent = CurContent + CurRow.LowerBound + " - " + CurRow.Discount + "%";
		
		EndDo;
		
		DiscountsShortContent = CurContent;
		
		If PeriodKind = Enums.PeriodTypeForCumulativeDiscounts.EntirePeriod Then
			Periodicity = Enums.Periodicity.EmptyRef();
		EndIf;
	EndIf;
	
EndProcedure

// Procedure - FillCheckProcessing event handler.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If DiscountKindForDiscountCards <> Enums.DiscountTypeForDiscountCards.ProgressiveDiscount OR PeriodKind = Enums.PeriodTypeForCumulativeDiscounts.EntirePeriod Then
		CheckedAttributes.Delete(CheckedAttributes.Find("Periodicity"));
	EndIf;
	
	If DiscountKindForDiscountCards <> Enums.DiscountTypeForDiscountCards.ProgressiveDiscount Then
		CheckedAttributes.Delete(CheckedAttributes.Find("PeriodKind"));
	EndIf;
	
EndProcedure

#EndRegion

#EndIf