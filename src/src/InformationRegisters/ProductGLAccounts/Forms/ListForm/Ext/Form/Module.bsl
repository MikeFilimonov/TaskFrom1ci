
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("Filter") Then
		Items.ShowRelevantSettings.Visible = Parameters.Filter.Count();
	EndIf;
	Parameters.Filter.Property("Product", Product);
	
EndProcedure

&AtClient
Procedure ShowRelevantSettingsOnChange(Item)
	ShowRelevantSettingsOnChangeAtServer();
EndProcedure

&AtServer
Procedure ShowRelevantSettingsOnChangeAtServer()
	
	FilterItems = List.Filter.Items;
	FilterItems.Clear();
	
	If ShowRelevantSettings Then
		ProductArray = New Array();
		ProductArray.Add(Catalogs.Products.EmptyRef());
		ProductArray.Add(Product);
		
		ProductCategoryArray = New Array();
		ProductCategoryArray.Add(Catalogs.ProductsCategories.EmptyRef());
		ProductCategoryArray.Add(CommonUse.ObjectAttributeValue(Product, "ProductsCategory"));
		
		GroupList = GLAccountsInDocuments.GetHigherGroupList(Product);
		For Each Item In GroupList Do
			ProductArray.Add(Item);
		EndDo;
		
		FilterItem = FilterItems.Add(Type("DataCompositionFilterItem"));
		FilterItem.LeftValue = New DataCompositionField("Product");
		FilterItem.ComparisonType = DataCompositionComparisonType.InList;
		FilterItem.RightValue = ProductArray;
		
		FilterItem = FilterItems.Add(Type("DataCompositionFilterItem"));
		FilterItem.LeftValue = New DataCompositionField("ProductCategory");
		FilterItem.ComparisonType = DataCompositionComparisonType.InList;
		FilterItem.RightValue = ProductCategoryArray
	Else
		FilterItem = FilterItems.Add(Type("DataCompositionFilterItem"));
		FilterItem.LeftValue = New DataCompositionField("Product");
		FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
		FilterItem.RightValue = Product;
	EndIf;
	
EndProcedure

#EndRegion