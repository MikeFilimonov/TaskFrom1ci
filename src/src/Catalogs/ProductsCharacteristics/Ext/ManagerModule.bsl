#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

// Event handler procedure ChoiceDataGetProcessor.
//
Procedure ChoiceDataGetProcessing(ChoiceData, Parameters, StandardProcessing)
	
	If Parameters.Filter.Property("Owner") AND TypeOf(Parameters.Filter.Owner) = Type("CatalogRef.Products") Then
		// If selection parameter link by products and
		// services value is set, then add selection parameters by the owner filter - product group.
		
		Products 		 = Parameters.Filter.Owner;
		ProductsCategory = Parameters.Filter.Owner.ProductsCategory;
		
		MessageText = "";
		If Not ValueIsFilled(Products) Then
			MessageText = NStr("en = 'Product is not filled in.'");
		ElsIf Parameters.Property("ThisIsReceiptDocument") AND Products.ProductsType = Enums.ProductsTypes.Service Then
			MessageText = NStr("en = 'Accounting by characteristics is not kept for services of external counterparties.'");
		ElsIf Not Products.UseCharacteristics Then
			MessageText = NStr("en = 'Accounting by characteristics is not kept for the product.'");
		EndIf;
		
		If Not IsBlankString(MessageText) Then
			CommonUseClientServer.MessageToUser(MessageText);
			StandardProcessing = False;
			Return;
		EndIf;
		
		FilterArray = New Array;
		FilterArray.Add(Products);
		FilterArray.Add(ProductsCategory);
		
		Parameters.Filter.Insert("Owner", FilterArray);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region PrintInterface

// Fills in the list of printing commands.
// 
// Parameters:
//   PrintCommands - ValueTable - see the fields content in the PrintManagement.CreatePrintCommandsCollection function
//
Procedure AddPrintCommands(PrintCommands) Export
	
	
	
EndProcedure

#EndRegion

#EndIf