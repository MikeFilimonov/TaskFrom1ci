
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	FilterStructure = New Structure;
	
	If TypeOf(CommandParameter) = Type("DocumentRef.SalesOrder")
		OR TypeOf(CommandParameter) = Type("DocumentRef.SalesInvoice") Then
		
		ProductsList = GetProductsListOfDocument(CommandParameter);
		FilterStructure.Insert("Products", ProductsList);
	Else
		FilterStructure.Insert("Products", CommandParameter);
	EndIf;
	
	FormParameters = New Structure("VariantKey, Filter, GenerateOnOpen, ReportVariantsCommandsVisible", "AvailableBalanceContext", FilterStructure, True, False);
	
	OpenForm("Report.AvailableStock.Form", FormParameters, CommandExecuteParameters.Source, CommandExecuteParameters.Uniqueness, CommandExecuteParameters.Window);
	
EndProcedure

&AtServer
Function GetProductsListOfDocument(Document)
	
	ProductsList = Document.Inventory.UnloadColumn("Products");
	
	Return ProductsList;
	
EndFunction
