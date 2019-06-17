
#Region Public

Procedure FillTabSectionFromProductGLAccounts(DocumentObject, FillingData = Undefined) Export
	
	ObjectMetadata = DocumentObject.Metadata();
	If CommonUse.IsReference(TypeOf(FillingData)) Then
		
		FillingMetadata = FillingData.Metadata();
		
	ElsIf TypeOf(FillingData) = Type("Structure") Then
		
		For Each Item In FillingData Do
			Array = Item.Value;
			If Array.Count() > 0
				And	CommonUse.IsReference(TypeOf(Array[0])) Then
				FillingData = Array[0];
				FillingMetadata = FillingData.Metadata();
			EndIf;
		EndDo;
		
	EndIf;
	TabularSectionsMetadata = ObjectMetadata.TabularSections;
	ObjectParameters = New Structure;	
	If ObjectMetadata.Attributes.Find("Company") <> Undefined Then
		ObjectParameters.Insert("Company", DocumentObject.Company);
	EndIf;
	
	If ObjectMetadata.Attributes.Find("StructuralUnit") <> Undefined Then
		ObjectParameters.Insert("StructuralUnit", DocumentObject.StructuralUnit);
	ElsIf ObjectMetadata.Attributes.Find("StructuralUnitReserve") <> Undefined Then
		ObjectParameters.Insert("StructuralUnit", DocumentObject.StructuralUnitReserve);
	EndIf;
	
	If ObjectMetadata.Attributes.Find("StructuralUnitPayee") <> Undefined Then
		ObjectParameters.Insert("StructuralUnitPayee", DocumentObject.StructuralUnitPayee);
	EndIf;
	
	StructureData = New Structure;
	StructureData.Insert("ObjectParameters", ObjectParameters);
	
	For Each TabSectionMetadata In TabularSectionsMetadata Do
		
		If TabSectionMetadata.Attributes.Find("Products") <> Undefined Then
			
			TabSectionName = TabSectionMetadata.Name;
			TabSection = DocumentObject[TabSectionName];
			StructureData.Insert("Products", TabSection.Unload(, "Products").UnloadColumn(("Products")));
			ProductGLAccounts = GetProductListGLAccounts(StructureData);
			
			For Each Row In TabSection Do
				
				If FillingMetadata <> Undefined
					And FillingMetadata.TabularSections.Find(TabSectionName) <> Undefined Then
					FilterStructure = New Structure("LineNumber, Products", Row.LineNumber, Row.Products);
					FoundRow = FillingData[TabSectionName].FindRows(FilterStructure);
					
					If FoundRow.Count() > 0 Then
						FillPropertyValues(Row, FoundRow);
					EndIf;
				EndIf;
				
				GLAccounts = ProductGLAccounts[Row.Products];
				For Each GLAccount In GLAccounts Do
					GLAccountInRow = TabSectionMetadata.Attributes.Find(GLAccount.Key);
					If GLAccountInRow <> Undefined 
						And Not ValueIsFilled(Row[GLAccount.Key]) Then
						Row[GLAccount.Key] = GLAccount.Value;	
					EndIf;
				EndDo;
			EndDo;
		EndIf;
	EndDo;
	
EndProcedure

Function GetProductListGLAccounts(StructureData) Export
	
	ObjectParameters = StructureData.ObjectParameters;	
	Products		= StructureData.Products;
	
	EmptyWarehouse = Catalogs.BusinessUnits.EmptyRef();
	
	If StructureData.Property("StructuralUnit") Then
		StructuralUnit = StructureData.StructuralUnit;
	Else
		StructuralUnit = EmptyWarehouse;
	EndIf;
	
	If Not ValueIsFilled(StructuralUnit)
		And ObjectParameters.Property("StructuralUnit") Then 
		StructuralUnit = ObjectParameters.StructuralUnit;
	EndIf;
	
	If ObjectParameters.Property("StructuralUnitPayee") Then
		StructuralUnitPayee = ObjectParameters.StructuralUnitPayee;
	Else
		StructuralUnitPayee = EmptyWarehouse;
	EndIf;
	
	Result	= New Map;
	
	If CommonUse.ReferenceTypeValue(Products) Then
		ProductList = New Array;
		ProductList.Add(Products);
	Else
		If Products.Count() = 0 Then
			Return Result;
		EndIf;
		
		ProductList = Products;
	EndIf;
	
	If Not AccessRight("Read", Metadata.InformationRegisters.ProductGLAccounts) Then
		Return Result;
	EndIf;
	
	EmptyProduct = Catalogs.Products.EmptyRef();
	EmptyGLAccount = ChartsOfAccounts.PrimaryChartOfAccounts.EmptyRef();
	
	For Each Products In ProductList Do
		If Products = Undefined Then
			Continue;
		EndIf;
		ReturnStructure = New Structure();
		ReturnStructure.Insert("InventoryGLAccount",					EmptyGLAccount);
		ReturnStructure.Insert("InventoryTransferredGLAccount",			EmptyGLAccount);
		ReturnStructure.Insert("UnearnedRevenueGLAccount",				EmptyGLAccount);
		ReturnStructure.Insert("VATInputGLAccount",						EmptyGLAccount);
		ReturnStructure.Insert("VATOutputGLAccount",					EmptyGLAccount);
		ReturnStructure.Insert("RevenueGLAccount",						EmptyGLAccount);
		ReturnStructure.Insert("COGSGLAccount",							EmptyGLAccount);
		ReturnStructure.Insert("ConsumptionGLAccount",					EmptyGLAccount);
		ReturnStructure.Insert("SalesReturnGLAccount",					EmptyGLAccount);
		ReturnStructure.Insert("PurchaseReturnGLAccount",				EmptyGLAccount);
		ReturnStructure.Insert("InventoryReceivedGLAccount",			EmptyGLAccount);
		ReturnStructure.Insert("GoodsShippedNotInvoicedGLAccount",		EmptyGLAccount);
		ReturnStructure.Insert("GoodsReceivedNotInvoicedGLAccount",		EmptyGLAccount);
		ReturnStructure.Insert("GoodsInvoicedNotDeliveredGLAccount",	EmptyGLAccount);
		ReturnStructure.Insert("SignedOutEquipmentGLAccount",			EmptyGLAccount);
		
		Result.Insert(Products, ReturnStructure);
	EndDo;

	CompanyArray = New Array();
	CompanyArray.Add(Catalogs.Companies.EmptyRef());
	CompanyArray.Add(ObjectParameters.Company);
	
	WarehouseArray = New Array();
	WarehouseArray.Add(Catalogs.BusinessUnits.EmptyRef());
	
	If ValueIsFilled(StructuralUnit) Then
		WarehouseArray.Add(StructuralUnit);
	EndIf;
	
	If ValueIsFilled(StructuralUnitPayee) Then
		WarehouseArray.Add(StructuralUnitPayee);
	EndIf;
	
	Query = New Query();
	Query.Text = 
	"SELECT TOP 1
	|	ProductGLAccounts.Product AS Product
	|FROM
	|	InformationRegister.ProductGLAccounts AS ProductGLAccounts
	|WHERE
	|	ProductGLAccounts.Product.IsFolder";
	
	ThereIsProduct = NOT Query.Execute().IsEmpty();
	
	HierarchyTable = New ValueTable;
	HierarchyTable.Columns.Add("Item",		New TypeDescription("CatalogRef.Products"));
	HierarchyTable.Columns.Add("Parent",	New TypeDescription("CatalogRef.Products"));
	HierarchyTable.Columns.Add("Level",		CommonUse.TypeDescriptionNumber(10, 0));
	
	If ThereIsProduct Then
				
		ItemAndGroupMap = GetHigherItemGroupList(ProductList);
		
		For Each Products In ProductList Do
			
			NewRow = HierarchyTable.Add();
			NewRow.Item		= Products;
			
			NewRow = HierarchyTable.Add();
			NewRow.Item		= Products;
			NewRow.Parent	= Products;
			
			GroupList = ItemAndGroupMap.Get(Products);
			If GroupList = Undefined Then
				NewRow.Level = 1;
				Continue;
			EndIf;
			
			HigherGroupCount = GroupList.Count();
			
			NewRow.Level = HigherGroupCount + 1;
			
			For Index = 1 To HigherGroupCount Do
				NewRow = HierarchyTable.Add();
				NewRow.Item	= Products;
				NewRow.Parent= GroupList[Index - 1];
				NewRow.Level	= HigherGroupCount - Index + 1;
			EndDo;						
		EndDo;
	Else
		
		For Each Products In ProductList Do
			ProductsCategory = CommonUse.ObjectAttributesValues(Products, "ProductsCategory");
			
			NewRow = HierarchyTable.Add();
			NewRow.Item		= Products;
			
			NewRow = HierarchyTable.Add();
			NewRow.Item		= Products;
			NewRow.Parent	= Products;
			NewRow.Level = 1;
			
		EndDo;
		
	EndIf;
	
	NewRow = HierarchyTable.Add();
	
	ProductArray = CommonUse.UnloadColumn(HierarchyTable, "Parent", True);
	
	Query = New Query();
	Query.Text =
	"SELECT
	|	HierarchyTable.Item AS Item,
	|	HierarchyTable.Parent AS Parent,
	|	HierarchyTable.Level AS Level
	|INTO HierarchyTable
	|FROM
	|	&HierarchyTable AS HierarchyTable
	|
	|INDEX BY
	|	Parent
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	HierarchyTable.Item AS Item,
	|	HierarchyTable.Parent AS Parent,
	|	HierarchyTable.Level AS Level,
	|	Products.ProductsCategory AS ProductsCategory
	|INTO HierarchyTableWithCategories
	|FROM
	|	HierarchyTable AS HierarchyTable
	|		LEFT JOIN Catalog.Products AS Products
	|		ON HierarchyTable.Item = Products.Ref
	|
	|INDEX BY
	|	Parent
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	HierarchyTable.Item AS Products,
	|	HierarchyTable.Parent AS Parent,
	|	HierarchyTable.Level AS Level,
	|	ProductGLAccounts.ProductCategory AS ProductsCategory,
	|	ProductGLAccounts.Company AS Company,
	|	ProductGLAccounts.StructuralUnit AS StructuralUnit,
	|	ProductGLAccounts.Inventory AS InventoryGLAccount,
	|	ProductGLAccounts.InventoryTransferred AS InventoryTransferredGLAccount,
	|	ProductGLAccounts.InventoryReceived AS InventoryReceivedGLAccount,
	|	ProductGLAccounts.GoodsShippedNotInvoiced AS GoodsShippedNotInvoicedGLAccount,
	|	ProductGLAccounts.GoodsReceivedNotInvoiced AS GoodsReceivedNotInvoicedGLAccount,
	|	ProductGLAccounts.GoodsInvoicedNotDelivered AS GoodsInvoicedNotDeliveredGLAccount,
	|	ProductGLAccounts.SignedOutEquipment AS SignedOutEquipmentGLAccount,
	|	ProductGLAccounts.UnearnedRevenue AS UnearnedRevenueGLAccount,
	|	ProductGLAccounts.VATInput AS VATInputGLAccount,
	|	ProductGLAccounts.VATOutput AS VATOutputGLAccount,
	|	ProductGLAccounts.Revenue AS RevenueGLAccount,
	|	ProductGLAccounts.COGS AS COGSGLAccount,
	|	ProductGLAccounts.Consumption AS ConsumptionGLAccount,
	|	ProductGLAccounts.SalesReturn AS SalesReturnGLAccount,
	|	ProductGLAccounts.PurchaseReturn AS PurchaseReturnGLAccount
	|FROM
	|	HierarchyTableWithCategories AS HierarchyTable
	|		LEFT JOIN InformationRegister.ProductGLAccounts AS ProductGLAccounts
	|		ON HierarchyTable.Parent = ProductGLAccounts.Product
	|			AND HierarchyTable.ProductsCategory = ProductGLAccounts.ProductCategory
	|WHERE
	|	ProductGLAccounts.Company IN(&CompanyArray)
	|	AND ProductGLAccounts.Product IN(&ProductArray)
	|	AND ProductGLAccounts.StructuralUnit IN(&WarehouseArray)
	|
	|UNION ALL
	|
	|SELECT
	|	HierarchyTable.Item,
	|	HierarchyTable.Parent,
	|	HierarchyTable.Level,
	|	ProductGLAccounts.ProductCategory,
	|	ProductGLAccounts.Company,
	|	ProductGLAccounts.StructuralUnit,
	|	ProductGLAccounts.Inventory,
	|	ProductGLAccounts.InventoryTransferred,
	|	ProductGLAccounts.InventoryReceived,
	|	ProductGLAccounts.GoodsShippedNotInvoiced,
	|	ProductGLAccounts.GoodsReceivedNotInvoiced,
	|	ProductGLAccounts.GoodsInvoicedNotDelivered,
	|	ProductGLAccounts.SignedOutEquipment,
	|	ProductGLAccounts.UnearnedRevenue,
	|	ProductGLAccounts.VATInput,
	|	ProductGLAccounts.VATOutput,
	|	ProductGLAccounts.Revenue,
	|	ProductGLAccounts.COGS,
	|	ProductGLAccounts.Consumption,
	|	ProductGLAccounts.SalesReturn,
	|	ProductGLAccounts.PurchaseReturn
	|FROM
	|	HierarchyTableWithCategories AS HierarchyTable
	|		LEFT JOIN InformationRegister.ProductGLAccounts AS ProductGLAccounts
	|		ON HierarchyTable.Parent = ProductGLAccounts.Product
	|WHERE
	|	ProductGLAccounts.Company IN(&CompanyArray)
	|	AND ProductGLAccounts.Product IN(&ProductArray)
	|	AND ProductGLAccounts.StructuralUnit IN(&WarehouseArray)
	|	AND ProductGLAccounts.ProductCategory = VALUE(Catalog.ProductsCategories.EmptyRef)
	|
	|ORDER BY
	|	Level DESC,
	|	ProductsCategory DESC,
	|	StructuralUnit DESC,
	|	Company DESC";
	
	Query.SetParameter("CompanyArray",		CompanyArray);
	Query.SetParameter("ProductList",		ProductList);
	Query.SetParameter("ProductArray",		ProductArray);
	Query.SetParameter("HierarchyTable",	HierarchyTable);
	Query.SetParameter("WarehouseArray",	WarehouseArray);
	Query.SetParameter("EmptyGLAccount",	ChartsOfAccounts.PrimaryChartOfAccounts.EmptyRef());
			
	GLAccountsTable = Query.Execute().Unload();
	GLAccountsTable.Indexes.Add("Products");
	
	GLAccountFilter = New Structure("Products");
	
	For Each Products In ProductList Do
		
		ReturnStructure = Result.Get(Products);
		
		GLAccountFilter = New Structure("Products");
		GLAccountFilter.Products = Products;
		
		FoundStrings = GLAccountsTable.FindRows(GLAccountFilter);
		
		If FoundStrings.Count() > 0 Then
			If ValueIsFilled(StructuralUnitPayee) Then
				
				For Each Item In FoundStrings Do
					If Item.StructuralUnit = StructuralUnit
						Or Not ValueIsFilled(Item.StructuralUnit) Then
						FillPropertyValues(ReturnStructure, Item);
						Break;
					EndIf;
				EndDo;
				
			Else
				FillPropertyValues(ReturnStructure, FoundStrings[0]);
			EndIf;
			
		Else
			GLAccountFilter.Products = EmptyProduct;
			
			FoundStrings = GLAccountsTable.FindRows(GLAccountFilter);
			If FoundStrings.Count() > 0 Then
				FillPropertyValues(ReturnStructure, FoundStrings[0]);
			EndIf;
			
		EndIf;
		
		If ValueIsFilled(StructuralUnitPayee) Then
			GLAccountFilter.Insert("StructuralUnit", StructuralUnitPayee);
			FoundStrings = GLAccountsTable.FindRows(GLAccountFilter);
			
			If FoundStrings.Count() > 0 Then
				ReturnStructure.Insert("InventoryToGLAccount", FoundStrings[0].InventoryGLAccount);
				ReturnStructure.Insert("ConsumptionGLAccount", FoundStrings[0].ConsumptionGLAccount);
				ReturnStructure.Insert("SignedOutEquipmentGLAccount", FoundStrings[0].SignedOutEquipmentGLAccount);
			Else
				GLAccountFilter.StructuralUnit = EmptyWarehouse;
				
				FoundStrings = GLAccountsTable.FindRows(GLAccountFilter);
				If FoundStrings.Count() > 0 Then
					ReturnStructure.Insert("InventoryToGLAccount", FoundStrings[0].InventoryGLAccount);
					ReturnStructure.Insert("ConsumptionGLAccount", FoundStrings[0].ConsumptionGLAccount);
					ReturnStructure.Insert("SignedOutEquipmentGLAccount", FoundStrings[0].SignedOutEquipmentGLAccount);
				Else
					
					GLAccountFilter.Products = EmptyProduct;
					
					FoundStrings = GLAccountsTable.FindRows(GLAccountFilter);
					If FoundStrings.Count() > 0 Then
						FillPropertyValues(ReturnStructure, FoundStrings[0]);
					EndIf;
				EndIf;
			EndIf;
		EndIf;
		
	EndDo;
	
	Return Result;

EndFunction

Procedure FillProductGLAccountsInStructure(StructureData) Export

	GLAccounts = GLAccountsInDocuments.GetProductListGLAccounts(StructureData);
	GLAccountsInDocumentsServerCall.FillProductGLAccounts(StructureData, GLAccounts);
	
EndProcedure

Function GetHigherItemGroupListQuery(CatalogName) Export

	Query = New Query;
	QueryText =
	"SELECT
	|	Catalog.Ref AS Item,
	|	Catalog.Parent AS Parent1,
	|	Catalog2.Parent AS Parent2,
	|	Catalog3.Parent AS Parent3,
	|	Catalog4.Parent AS Parent4,
	|	Catalog5.Parent AS Parent5
	|FROM
	|	Catalog.Product AS Catalog
	|		LEFT JOIN Catalog.Product AS Catalog2
	|		ON (Catalog2.Ref = Catalog.Parent)
	|		LEFT JOIN Catalog.Product AS Catalog3
	|		ON (Catalog3.Ref = Catalog2.Parent)
	|		LEFT JOIN Catalog.Product AS Catalog4
	|		ON (Catalog4.Ref = Catalog3.Parent)
	|		LEFT JOIN Catalog.Product AS Catalog5
	|		ON (Catalog5.Ref = Catalog4.Parent)
	|WHERE
	|	Catalog.Ref IN(&RefArray)";
	
	Query.Text = StrReplace(QueryText, "Product", CatalogName);
	
	Return Query;

EndFunction

Function GetHigherGroupList(CatalogItem) Export

	Result = New Array;
	
	If Not ValueIsFilled(CatalogItem) Then
		Return Result;
	EndIf;
	
	CatalogMetadata = CatalogItem.Metadata();
	If Not CatalogMetadata.Hierarchical Then
		Return Result;
	EndIf;
	
	CatalogName = CatalogMetadata.Name;
	Query = GetHigherItemGroupListQuery(CatalogName);
	
	CurrentItem = CatalogItem;
	
	While ValueIsFilled(CurrentItem) Do
		
		RefArray = New Array;
		RefArray.Add(CurrentItem);
		Query.SetParameter("RefArray", RefArray);
		Selection = Query.Execute().Select();
		
		If Selection.Next() Then
			
			For Index = 1 To 5 Do
				
				Parent = Selection["Parent" + Index];
				
				If Parent = CurrentItem Then
					MessageCyclicLinkInObject(CatalogMetadata, CatalogItem);
					CurrentItem = Undefined;
					Break;
				EndIf;
				
				CurrentItem = Parent;
				If ValueIsFilled(CurrentItem) Then
					Result.Add(CurrentItem);
				Else
					Break;
				EndIf;
			EndDo;
		EndIf;
	EndDo;
	
	Return Result;
	
EndFunction

Function GetHigherItemGroupList(CatalogItemArray) Export

	Result = New Map;
	
	If CatalogItemArray.Count() = 0 Then
		Return Result;
	EndIf;
	
	For Each CatalogItem In CatalogItemArray Do
		Result.Insert(CatalogItem, New Array);
	EndDo;
	
	CatalogMetadata = CatalogItemArray[0].Metadata();
	If Not CatalogMetadata.Hierarchical Then
		Return Result;
	EndIf;
	
	CatalogName = CatalogMetadata.Name;
	Query = GetHigherItemGroupListQuery(CatalogName);
	
	GroupsAndItemsMap = New ValueTable;
	GroupsAndItemsMap.Columns.Add("Parent",	New TypeDescription("CatalogRef." + CatalogName));
	GroupsAndItemsMap.Columns.Add("Item",	New TypeDescription("CatalogRef." + CatalogName));
	GroupsAndItemsMap.Indexes.Add("Parent");
	For Each CatalogItem In CatalogItemArray Do
		NewMap = GroupsAndItemsMap.Add();
		NewMap.Parent	= CatalogItem;
		NewMap.Item	= CatalogItem;
	EndDo;
	
	Filter	= New Structure("Parent");
	
	RefCurrentArray = CatalogItemArray;
	
	While RefCurrentArray.Count() > 0 Do
		
		Query.SetParameter("RefArray", DeleteDuplicateArrayItems(RefCurrentArray));
		Selection = Query.Execute().Select();
		
		RefCurrentArray	= New Array;
		
		While Selection.Next() Do
			
			Filter.Parent = Selection.Item;
			
			FoundRows = GroupsAndItemsMap.FindRows(Filter);
			For Each GroupAndItemMap In FoundRows Do
				
				CatalogItem	= GroupAndItemMap.Item;
				
				HigherGroupArray = Result.Get(CatalogItem);
				
				For Index = 1 To 5 Do
					
					Parent = Selection["Parent" + Index];

					If Parent = CatalogItem Then
						MessageCyclicLinkInObject(CatalogMetadata, CatalogItem);
						Break;
					EndIf;
					
					If ValueIsFilled(Parent) Then
						
						HigherGroupArray.Add(Parent);
						If Index = 5 Then
							RefCurrentArray.Add(Parent);
							NewMap = GroupsAndItemsMap.Add();
							NewMap.Parent	= Parent;
							NewMap.Item		= CatalogItem;
						EndIf;
						
					Else
						Break;
					EndIf;
				EndDo;
			EndDo;
		EndDo;
	EndDo;
	
	Return Result;

EndFunction

Function DeleteDuplicateArrayItems(ProcessedArray, DoNotUseUndefined = False, AnalyzeRefsAsIDs = False) Export

	If TypeOf(ProcessedArray) <> Type("Array") Then
		Return ProcessedArray;
	EndIf;
	
	AlreadyInArray = New Map;
	If AnalyzeRefsAsIDs Then 
		
		ReferenceTypeDescription = CommonUse.TypeDescriptionAllReferences();
		
	 	ThereWasUndefined = False;
		ItemCountInArray  = ProcessedArray.Count();

		For ReverseIndex = 1 To ItemCountInArray Do
			
			ArrayItem = ProcessedArray[ItemCountInArray - ReverseIndex];
			ItemType = TypeOf(ArrayItem);
			If ArrayItem = Undefined Then
				If ThereWasUndefined Or DoNotUseUndefined Then
					ProcessedArray.Delete(ItemCountInArray - ReverseIndex);
				Else
					ThereWasUndefined = True;
				EndIf;
				Continue;
			ElsIf ReferenceTypeDescription.ContainsType(ItemType) Then

				ItemID = String(ArrayItem.UUID());

			Else

				ItemID = ArrayItem;

			EndIf;

			If AlreadyInArray[ItemID] = True Then
				ProcessedArray.Delete(ItemCountInArray - ReverseIndex);
			Else
				AlreadyInArray[ItemID] = True;
			EndIf;
			
		EndDo;

	Else
		
		ItemIndex = 0;
		ItemCount = ProcessedArray.Count();
		While ItemIndex < ItemCount Do
			
			ArrayItem = ProcessedArray[ItemIndex];
			If DoNotUseUndefined AND ArrayItem = Undefined
			 Or AlreadyInArray[ArrayItem] = True Then
			 
			 	ProcessedArray.Delete(ItemIndex);
				ItemCount = ItemCount - 1;
				
			Else
				
				AlreadyInArray.Insert(ArrayItem, True);
				ItemIndex = ItemIndex + 1;
				
			EndIf;
		EndDo;
	EndIf;

	Return ProcessedArray;

EndFunction

Function FillGLAccountsInTable(DocObject, Tables, GetGLAccounts) Export
	
	For Each Table In Tables Do
		
		If DocObject.Property(Table.TabName) Then 
			TableProducts = DocObject[Table.TabName].Unload(, Table.ProductName);
			ProductsArray = TableProducts.UnloadColumn(Table.ProductName);
			
			If GetGLAccounts Then
				Table.Insert("Products", ProductsArray);
				GLAccounts = GetProductListGLAccounts(Table);
			EndIf;
			
			For Each Row In DocObject[Table.TabName] Do
				
				FillPropertyValues(Table, Row);
				GLAccountsInDocumentsClientServer.FillGLAccountsInStructure(Table, GLAccounts, GetGLAccounts);
				FillPropertyValues(Row, Table);
				
			EndDo;
		
		Else
			
			If GetGLAccounts Then
				GLAccounts = GetProductListGLAccounts(Table);
			EndIf;
		
			GLAccountsInDocumentsClientServer.FillGLAccountsInStructure(Table, GLAccounts, GetGLAccounts);
			
		EndIf;
		
	EndDo;
	
EndFunction

#EndRegion

#Region Private

Procedure MessageCyclicLinkInObject(ObjectMetadata, DataItem)

	ObjectType = "";
	If CommonUse.ThisIsCatalog(ObjectMetadata) Then
		ObjectType = NStr("en = 'In the catalog'");
	ElsIf CommonUse.ThisIsChartOfCharacteristicTypes(ObjectMetadata) Then
		ObjectType = NStr("en = 'In the chart of characteristic types'");
	EndIf;
	
	MessageText = StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en = '%1 %2 the %3 element in the %4 field contains a cyclical reference to itself. You should specify the correct group.'"),
		ObjectType,
		ObjectMetadata.Synonym,
		DataItem,
		ObjectMetadata.StandardAttributes.Parent.Synonym);
	WriteLogEvent(
		NStr("en = 'CyclicLink'", CommonUseClientServer.MainLanguageCode()),
		EventLogLevel.Warning,
		ObjectMetadata,
		DataItem,
		MessageText);
	CommonUseClientServer.MessageToUser(MessageText, DataItem, "Parent", "Object");

EndProcedure

#EndRegion
