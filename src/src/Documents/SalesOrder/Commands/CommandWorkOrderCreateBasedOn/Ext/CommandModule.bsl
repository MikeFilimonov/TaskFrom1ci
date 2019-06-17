
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	FillStructure = New Structure();
	FillStructure.Insert("Company", CommandExecuteParameters.Source.Object.Company);
	FillStructure.Insert("PriceKind", CommandExecuteParameters.Source.Object.PriceKind);
	FillStructure.Insert("WorkKind", CommandExecuteParameters.Source.Object.WorkKind);
	FillStructure.Insert("StructuralUnit", CommandExecuteParameters.Source.Object.SalesStructuralUnit);
	
	InventoryCurrentRow = CommandExecuteParameters.Source.Items.Inventory.CurrentData;
	
	If InventoryCurrentRow <> Undefined AND Not InventoryCurrentRow.ProductsTypeInventory Then
		
		StructureRow = New Structure;
		StructureRow.Insert("Products", InventoryCurrentRow.Products);
		StructureRow.Insert("Characteristic", InventoryCurrentRow.Characteristic);
		StructureRow.Insert("Day", InventoryCurrentRow.ShipmentDate);
		StructureRow.Insert("Price", InventoryCurrentRow.Price);
		StructureRow.Insert("Amount", InventoryCurrentRow.Amount);
		StructureRow.Insert("Customer", CommandExecuteParameters.Source.Object.Ref);
		
		Array = New Array;
		Array.Add(StructureRow);
		
		FillStructure.Insert("Works", Array);
		
	Else
		
		StructureRow = New Structure;
		StructureRow.Insert("Customer", CommandExecuteParameters.Source.Object.Ref);
		
		Array = New Array;
		Array.Add(StructureRow);
		
		FillStructure.Insert("Works", Array);
		
	EndIf;
	
	OpenForm("Document.ObsoleteWorkOrder.ObjectForm", New Structure("Basis", FillStructure));
	
EndProcedure
