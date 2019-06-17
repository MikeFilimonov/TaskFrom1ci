
// Custom settings. Initial filling.

// The procedure allows you to override the initial filling of the custom settings
//
Procedure OverrideInitialSelectionSettingsFilling(User, StandardProcessing) Export
	
	
	
EndProcedure

// End Custom settings. Initial filling.

// Usage table

// The procedure describes the table of using selection forms by documents and tabular sections
//
// Table form UsageTable:
//
// -		DocumentName, Row (100), Document name;
// -	TabularSectionName, Row (100), Document tabular section name;
// - ChoiceForm, Row (100), Full name of the selection form which should be used as a selection form;
//
Procedure ChoiceFormsUsageTable(UsageTable) Export
	
	// Implementation
	ChoiceFormFullName = DataProcessors.ProductsSelection.ChoiceFormFullName();
	
	AddSelectionUsageRow(UsageTable, Metadata.Documents.Quote.Name, Metadata.Documents.Quote.TabularSections.Inventory.Name, ChoiceFormFullName);
	AddSelectionUsageRow(UsageTable, Metadata.Documents.SalesOrder.Name, Metadata.Documents.SalesOrder.TabularSections.Inventory.Name, ChoiceFormFullName);
	AddSelectionUsageRow(UsageTable, Metadata.Documents.SalesInvoice.Name, Metadata.Documents.SalesInvoice.TabularSections.Inventory.Name, ChoiceFormFullName);
	AddSelectionUsageRow(UsageTable, Metadata.Documents.SalesSlip.Name, Metadata.Documents.SalesSlip.TabularSections.Inventory.Name, ChoiceFormFullName);
	
EndProcedure

// The procedure adds a new row to the usage table
//
Procedure AddSelectionUsageRow(UsageTable, DocumentName, TabularSectionName, ChoiceFormFullName)
	
	NewRow = UsageTable.Add();
	
	NewRow.DocumentName 		= DocumentName;
	NewRow.TabularSectionName	= TabularSectionName;
	NewRow.PickForm		= ChoiceFormFullName;
	
EndProcedure

// End Usage table

// Full-text search

Function FullTextSearchProducts(SearchString, SearchResult)
	
	BarcodesArray = New Array;
	
	// Search data
	PortionSize = 200;
	SearchArea = New Array;
	SearchArea.Add(Metadata.Catalogs.Products);
	SearchArea.Add(Metadata.Catalogs.ProductsCharacteristics);
	SearchArea.Add(Metadata.InformationRegisters.AdditionalInformation);
	SearchArea.Add(Metadata.InformationRegisters.Barcodes);
	
	SearchList = FullTextSearch.CreateList(SearchString, PortionSize);
	SearchList.GetDescription = False;
	SearchList.SearchArea = SearchArea;
	SearchList.FirstPart();
	
	If SearchList.TooManyResults() Then
		Return "TooManyResults";
	EndIf;
	
	FoundItemsQuantity = SearchList.TotalCount();
	If FoundItemsQuantity = 0 Then
		Return "FoundNothing";
	EndIf;
	
	// Data processing
	StartPosition	= 0;
	EndPosition		= ?(FoundItemsQuantity > PortionSize, PortionSize, FoundItemsQuantity) - 1;
	IsNextPortion = True;

	While IsNextPortion Do
		
		For CountElements = 0 To EndPosition Do
			
			Item = SearchList.Get(CountElements);
			
			If Item.Metadata = Metadata.Catalogs.Products Then
				
				SearchResult.Products.Add(Item.Value);
				
			ElsIf Item.Metadata = Metadata.Catalogs.ProductsCharacteristics Then
				
				SearchResult.ProductsCharacteristics.Add(Item.Value);
				
			ElsIf Item.Metadata = Metadata.InformationRegisters.AdditionalInformation Then
				
				If TypeOf(Item.Value.Object) = Type("CatalogRef.Products") Then
					
					SearchResult.Products.Add(Item.Value.Object);
					
				EndIf;
				
			ElsIf Item.Metadata = Metadata.InformationRegisters.Barcodes Then
				
				BarcodesArray.Add(Item.Value.Barcode);
				
			Else
				
				Raise NStr("en = 'Unknown error'");
				
			EndIf;
			
		EndDo;
		
		StartPosition    = StartPosition + PortionSize;
		IsNextPortion = (StartPosition < FoundItemsQuantity - 1);
		
		If IsNextPortion Then
			
			EndPosition = ?(FoundItemsQuantity > StartPosition + PortionSize,
			                    PortionSize,
			                    FoundItemsQuantity - StartPosition
			                    ) - 1;
			SearchList.NextPart();
			
		EndIf;
		
	EndDo;
	
	If BarcodesArray.Count() > 0 Then
		
		Query = New Query;
		Query.Text = 
		"SELECT
		|	Barcodes.Products AS Products,
		|	Barcodes.Characteristic AS Characteristic
		|FROM
		|	InformationRegister.Barcodes AS Barcodes
		|WHERE
		|	Barcodes.Barcode IN(&BarcodesArray)
		|	AND Barcodes.Products REFS Catalog.Products";
		
		Query.SetParameter("BarcodesArray", BarcodesArray);
		
		Selection = Query.Execute().Select();
		While Selection.Next() Do
			
			SearchResult.Products.Add(Selection.Products);
			
		EndDo;
		
	EndIf;
	
	Return "CompletedSuccessfully";
	
EndFunction

Function SearchGoods(SearchString, ErrorDescription) Export
	
	SearchResult = New Structure;
	SearchResult.Insert("Products", New Array);
	SearchResult.Insert("ProductsCharacteristics", New Array);
	
	Result = FullTextSearchProducts(SearchString, SearchResult);
	
	If Result = "CompletedSuccessfully" Then
		
		Return SearchResult;
		
	ElsIf Result = "TooManyResults" Then
		
		ErrorDescription = NStr("en = 'Too many results. Refine your search.'");
		Return SearchResult;
		
	ElsIf Result = "FoundNothing" Then
		
		ErrorDescription = NStr("en = 'No results found'");
		Return SearchResult;
		
	Else
		
		Raise NStr("en = 'Unknown error'");
		
	EndIf;
	
EndFunction

// End Full-text search