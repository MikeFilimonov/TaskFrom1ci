
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("Products") Then
		DriveClientServer.SetListFilterItem(List, "Products", Parameters.Products);
		If Parameters.Products.ProductsType <> Enums.ProductsTypes.InventoryItem Then
			AutoTitle = False;
			Title = NStr("en = 'Barcodes are stored only for inventories'");
			Items.List.ReadOnly = True;
		EndIf;
	EndIf;
	
EndProcedure
