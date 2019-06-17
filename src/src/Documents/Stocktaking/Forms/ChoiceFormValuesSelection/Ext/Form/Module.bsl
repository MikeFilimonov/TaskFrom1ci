
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	FilterKind = Parameters.FilterKind;
	ListValueSelection 	   = Parameters.ListValueSelection;
	
	TypeArray = New Array();
	If FilterKind = "FilterByProducts" Then
		Title = NStr("en = 'Select products'");
		Items.ProductsGroupValue.ChoiceFoldersAndItems = FoldersAndItems.Items;
		TypeArray.Add(Type("CatalogRef.Products"));
	ElsIf FilterKind = "FilterByProductsGroups" Then
		Title = NStr("en = 'Select product groups'");
		Items.ProductsGroupValue.ChoiceFoldersAndItems = FoldersAndItems.Folders;
		TypeArray.Add(Type("CatalogRef.Products"));
	Else
		Title = NStr("en = 'Select product groups'");
		Items.ProductsGroupValue.ChoiceFoldersAndItems = FoldersAndItems.Items;
		TypeArray.Add(Type("CatalogRef.ProductsCategories"));
	EndIf;
	
	NewDetails = New TypeDescription(TypeArray);
	ListValueSelection.ValueType = NewDetails;
	
EndProcedure

// Fills item presentations and delete empty values.
//
&AtServerNoContext
Procedure FillPresentationOfListItemsServerNoContext(ListValueSelection)
	
	ArrayOfItemsForDeletion = New Array;
	
	For Each ItemOfList In ListValueSelection Do
	
		If Not ValueIsFilled(ItemOfList.Value) Then
			
			ArrayOfItemsForDeletion.Add(ItemOfList);
			Continue;
			
		EndIf;
		
		ItemOfList.Presentation = ItemOfList.Value.Description;
	
	EndDo;
	
	For Each ArrayElement In ArrayOfItemsForDeletion Do
	
		ListValueSelection.Delete(ArrayElement);
	
	EndDo;
	
EndProcedure

&AtClient
Procedure CommandOK(Command)
	
	FillPresentationOfListItemsServerNoContext(ListValueSelection);
	
	SelectionResult = New Structure;
	SelectionResult.Insert("FilterKind", FilterKind);
	SelectionResult.Insert("SelectionValueListAddress", PutToTempStorage(ListValueSelection));
	
	Close(SelectionResult);
	
EndProcedure

