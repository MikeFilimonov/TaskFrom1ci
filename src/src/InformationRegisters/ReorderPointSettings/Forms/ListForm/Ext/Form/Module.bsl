#Region ProcedureFormEventHandlers

&AtServer
// Procedure-handler of the OnCreateAtServer event.
// Performs initial attributes forms filling.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("Filter") AND Parameters.Filter.Property("Products") Then
		
		Products = Parameters.Filter.Products;
		
		If Not Products.ProductsType = Enums.ProductsTypes.InventoryItem Then
			
			AutoTitle = False;
			Title = NStr("en = 'Reorder point settings is used only for inventories'");
			
			Items.List.ReadOnly = True;
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion
