&AtServer
Procedure FillDetails(TemplateName)
	
	Description = DataProcessors.DataImportFromExternalSources.GetTemplate(TemplateName).GetText();
	
EndProcedure

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	FillDetails("QuickStart");
	
EndProcedure

&AtClient
Procedure ShortDescriptionOnClick(Item, EventData, StandardProcessing)
	
	If ValueIsFilled(EventData.Element.id) Then
		
		StandardProcessing = False;
		
		CommandID = EventData.Element.id;
		If Find(CommandID, "Counterparties") > 0 Then
			
			OpenForm("Catalog.Counterparties.ListForm");
			
		ElsIf Find(CommandID, "Products") > 0 Then
			
			OpenForm("Catalog.Products.ListForm");
			
		ElsIf Find(CommandID, "Prices") > 0 Then
			
			OpenForm("DataProcessor.PriceList.Form");
			
		ElsIf Find(CommandID, "ShortAbbreviation") > 0 Then
			
			FillDetails("ShortDescription");
			
		ElsIf Find(CommandID, "QuickStart") > 0 Then
			
			FillDetails("QuickStart");
			
		EndIf;
		
	EndIf;
	
EndProcedure
