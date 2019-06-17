
#Region ProcedureFormEventHandlers

&AtServer
// Procedure-handler of the OnCreateAtServer event.
// Performs initial attributes forms filling.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("Filter") AND Parameters.Filter.Property("Products") Then
		
		Products = Parameters.Filter.Products;
		
		If Products.ProductsType <> Enums.ProductsTypes.InventoryItem Then
			
			AutoTitle = False;
			Title = NStr("en = 'Supplier prices can be entered only for products with the Inventory type'");
			
			Items.List.ReadOnly = True;
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion
