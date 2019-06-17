#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

// Procedure - event handler ChoiceDataReceivingProcessing.
//
Procedure ChoiceDataGetProcessing(ChoiceData, Parameters, StandardProcessing)
	
	If Not Parameters.Property("Recursion")
		AND Parameters.Filter.Property("Owner") AND TypeOf(Parameters.Filter.Owner) = Type("CatalogRef.Products") Then
		// When first entering if selection parameter link is set by
		// products value then add selection parameters by the selection on owner - products categories according to the hierarchy.
		
		StandardProcessing = False;
		
		Products 		 = Parameters.Filter.Owner;
		ProductsCategory = Parameters.Filter.Owner.ProductsCategory;
		
		FilterArray = New Array;
		FilterArray.Add(Products);
		FilterArray.Add(ProductsCategory);
		
		Parent = ProductsCategory.Parent;
		While ValueIsFilled(Parent) Do
			FilterArray.Add(Parent);
			Parent = Parent.Parent;
		EndDo;
		
		Parameters.Filter.Insert("Owner", FilterArray);
		
		// Flag of repeated logon.
		Parameters.Insert("Recursion");
		
		// Get standard selection list with respect to added filter.
		StandardList = GetChoiceData(Parameters);
		
		If Not (Parameters.Property("DontUseClassifier") AND Parameters.DontUseClassifier = True) Then
			If ValueIsFilled(Parameters.Filter.Owner) Then
			// Add standard list by basic products UOM according to the classifier.
				PresentationUOM = StringFunctionsClientServer.SubstituteParametersInString(NStr("en = '%1 (storage unit)'"),
					Products.MeasurementUnit.Description);
				StandardList.Insert(0, Products.MeasurementUnit, 
					New FormattedString(PresentationUOM, New Font(,,True)));
			Else
				CommonUseClientServer.MessageToUser(NStr("en = 'Products are not filled in.'"));
			EndIf;
		EndIf;
		
		ChoiceData = StandardList;
		
	EndIf;
	
EndProcedure

#EndRegion

#EndIf