#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ProgramInterface

// Price list generating procedure
//
Procedure Generate(ParametersStructure, BackgroundJobStorageAddress = "") Export
	
	If Not IsBlankString(BackgroundJobStorageAddress) Then
		
		SpreadsheetDocument = New SpreadsheetDocument;
		PrepareSpreadsheetDocument(ParametersStructure, SpreadsheetDocument);
		PutToTempStorage(SpreadsheetDocument, BackgroundJobStorageAddress);
		
	EndIf;
	
EndProcedure

// Function prepares the tabular document with the data
//
Procedure PrepareSpreadsheetDocument(ParametersStructure, SpreadsheetDocument) Export
	
	ItemHierarchy = ParametersStructure.ItemHierarchy;
	If ItemHierarchy Then
		
		SpreadsheetDocument_ItemHierarchy(ParametersStructure, SpreadsheetDocument);
		
	Else
		
		SpreadsheetDocument_PriceGroupsHierarchy(ParametersStructure, SpreadsheetDocument);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// Procedure of generating the dynamic price kinds mapping to their basic kinds
//
Function CreateMapPattern(TablePriceTypes)
	
	MapForDetail = New Map;
	
	For Each TableRow In TablePriceTypes Do
		
		If ValueIsFilled(TableRow.PriceKind) 
			AND Not TableRow.PriceKind.CalculatesDynamically Then
			
			MapForDetail.Insert(TableRow.PriceKind, Catalogs.PriceTypes.EmptyRef());
			
		EndIf;
		
	EndDo;
	
	Return MapForDetail;
	
EndFunction

// Output procedure of the price list detail sections
//
Procedure OutputDetails(SelectionProducts, UseCharacteristics, UsePriceGroups, SpreadsheetDocument, Template, ParametersStructure, TablePriceTypes)
	
	ToDate = ParametersStructure.ToDate;
	PriceKind = ParametersStructure.PriceKind;
	TSPriceTypes = ParametersStructure.TSPriceTypes;
	PriceGroup = ParametersStructure.PriceGroup;
	TSPriceGroups = ParametersStructure.TSPriceGroups;
	Products = ParametersStructure.Products;
	ProductsTS = ParametersStructure.ProductsTS;
	Actuality = ParametersStructure.Actuality;
	OutputCode = ParametersStructure.OutputCode;
	OutputFullDescr = ParametersStructure.OutputFullDescr;
	ShowTitle = ParametersStructure.ShowTitle;
	UseCharacteristics = ParametersStructure.UseCharacteristics;
	FormateByAvailabilityInWarehouses = ParametersStructure.FormateByAvailabilityInWarehouses;
	
	AreaDetailsProducts 	= Template.GetArea("Details|Products");
	AreaDetailsCharacteristic = Template.GetArea("Details|Characteristic");
	AreaDetailsPriceKind 		= Template.GetArea("Details|PriceKind");
	
	EnumValueYes		= Enums.YesNo.Yes;
	
	While SelectionProducts.Next() Do
		
		SelectionCharacteristic = SelectionProducts.Select(QueryResultIteration.ByGroups, "Characteristic");
		While SelectionCharacteristic.Next() Do
			
			ProductsCharacteristicDetailsStructure = New Structure;
			ProductsCharacteristicDetailsStructure.Insert("Products",				SelectionProducts.Products);
			ProductsCharacteristicDetailsStructure.Insert("Characteristic",			Catalogs.ProductsCharacteristics.EmptyRef());
			ProductsCharacteristicDetailsStructure.Insert("DetailsMatch",	CreateMapPattern(TablePriceTypes));
			
			TableHeight = SpreadsheetDocument.TableHeight;
			TableWidth = ?(UseCharacteristics, 4, 3);
			
			SpreadsheetDocument.Put(AreaDetailsProducts);
			
			If UseCharacteristics Then
				
				ProductsCharacteristicDetailsStructure.Insert("Characteristic", SelectionCharacteristic.Characteristic);
				
				AreaDetailsCharacteristic.Parameters.Characteristic = SelectionCharacteristic.Characteristic;
				SpreadsheetDocument.Join(AreaDetailsCharacteristic);
				
			EndIf;
			
			// Remember the used prices in the values list
			UsedPrices = New ValueList;
			
			SelectionPriceKind = SelectionCharacteristic.Select(QueryResultIteration.ByGroups, "PriceKind");
			While SelectionPriceKind.Next() Do
				
				Selection = SelectionPriceKind.Select();
				While Selection.Next() Do
					
					DetailsStructure = New Structure;
					DetailsStructure.Insert("Products", 		SelectionProducts.Products);
					DetailsStructure.Insert("Characteristic", 	SelectionCharacteristic.Characteristic);
					DetailsStructure.Insert("PriceKind", 			Selection.PriceKind);
					DetailsStructure.Insert("Dynamic",		Selection.PriceKind.CalculatesDynamically);
					DetailsStructure.Insert("PricesBaseKind",		Selection.PriceKind.PricesBaseKind);
					DetailsStructure.Insert("Period", 			ToDate);
					DetailsStructure.Insert("Period", 			Selection.Period);
					DetailsStructure.Insert("Price", 				Selection.Price);
					DetailsStructure.Insert("Actuality", 		Selection.Actuality);
					DetailsStructure.Insert("MeasurementUnit", 	Selection.MeasurementUnit);
					
					NPP = TablePriceTypes.FindRows(New Structure("PriceKind", Selection.PriceKind))[0].NPP;
					AreaUnit	= SpreadsheetDocument.Area(TableHeight + 1, TableWidth + NPP*2 + 1);
					AreaPrice 	= SpreadsheetDocument.Area(TableHeight + 1, TableWidth + NPP*2 + 2);
					
					AreaUnit.Text 		= Selection.MeasurementUnit;
					AreaUnit.TextPlacement = SpreadsheetDocumentTextPlacementType.Cut;
					
					If (Selection.PriceKind.CalculatesDynamically) Then //on query of all prices
						
						If ValueIsFilled(Selection.Price) Then
							
							Price = Selection.Price * (1 + Selection.PriceKind.Percent / 100);
							
						Else
							
							Price = 0;
							
						EndIf;
						
						Price = DriveClientServer.RoundPrice(Price, Selection.PriceKind.RoundingOrder, Selection.PriceKind.RoundUp);
						AreaPrice.Text = Format(Price, Selection.PriceKind.PriceFormat);
						
					ElsIf ValueIsFilled(PriceKind) AND PriceKind.CalculatesDynamically Then//on query of dynamic price type
						
						If ValueIsFilled(Selection.Price) Then
							
							Price = Selection.Price * (1 + PriceKind.Percent / 100);
							
						Else
							
							Price = 0;
							
						EndIf;
						
						Price = DriveClientServer.RoundPrice(Price, PriceKind.RoundingOrder, PriceKind.RoundUp);
						AreaPrice.Text = Format(Price, PriceKind.PriceFormat);
						
					Else
						
						AreaPrice.Text = Format(Selection.Price, Selection.PriceFormat);
						
					EndIf; 
					
					AreaUnit.Details	= DetailsStructure;
					AreaPrice.Details 	= DetailsStructure;
						
					If Not Selection.PriceKind.CalculatesDynamically Then
						
						ProductsCharacteristicDetailsStructure.DetailsMatch.Insert(Selection.PriceKind, DetailsStructure);
						
					EndIf;
					
					UsedPrices.Add(Selection.PriceKind);
					
				EndDo;
				
			EndDo;
			
			// Fill out explanation for other price kinds.
			For Each PriceTypesTableRow In TablePriceTypes Do
				
				If UsedPrices.FindByValue(PriceTypesTableRow.PriceKind) = Undefined Then
					
					AreaUnit	= SpreadsheetDocument.Area(TableHeight + 1, TableWidth + PriceTypesTableRow.NPP*2 + 1);
					AreaPrice 	= SpreadsheetDocument.Area(TableHeight + 1, TableWidth + PriceTypesTableRow.NPP*2 + 2);
					
					DetailsStructure = New Structure;
					DetailsStructure.Insert("Products", 		SelectionProducts.Products);
					DetailsStructure.Insert("Characteristic", 	SelectionCharacteristic.Characteristic);
					DetailsStructure.Insert("PriceKind", 			PriceTypesTableRow.PriceKind);
					DetailsStructure.Insert("Dynamic",		PriceTypesTableRow.PriceKind.CalculatesDynamically);
					DetailsStructure.Insert("PricesBaseKind",		PriceTypesTableRow.PriceKind.PricesBaseKind);
					DetailsStructure.Insert("Period", 			Selection.Period);
					DetailsStructure.Insert("MeasurementUnit", 	SelectionProducts.ProductsMeasurementUnit);
					
					AreaUnit.Details	= DetailsStructure;
					AreaPrice.Details 	= DetailsStructure;
					
				EndIf;
				
			EndDo;
			
			AreaSKUCode 				= SpreadsheetDocument.Area(TableHeight + 1, 2);
			AreaSKUCode.Text			= ?(OutputCode = EnumValueYes, SelectionProducts.ProductsCode, SelectionProducts.ProductsSKU);
			AreaSKUCode.Details	= ProductsCharacteristicDetailsStructure;
			
			AreaProducts 			= SpreadsheetDocument.Area(TableHeight + 1, 3);
			AreaProducts.Text		= ?(OutputFullDescr = EnumValueYes, SelectionProducts.DescriptionFull, SelectionProducts.ProductsDescription);
			AreaProducts.Details	= ProductsCharacteristicDetailsStructure;
			
			If UseCharacteristics Then
				
				AreaCharacteristic 				= SpreadsheetDocument.Area(TableHeight + 1, TableWidth);
				AreaCharacteristic.Details 	= ProductsCharacteristicDetailsStructure;
				
			EndIf;
			
		EndDo;
	
	EndDo;
	
EndProcedure

Procedure SpreadsheetDocument_ItemHierarchy(ParametersStructure, SpreadsheetDocument)
	
	ToDate = ParametersStructure.ToDate;
	PriceKind = ParametersStructure.PriceKind;
	TSPriceTypes = ParametersStructure.TSPriceTypes;
	PriceGroup = ParametersStructure.PriceGroup;
	TSPriceGroups = ParametersStructure.TSPriceGroups;
	Products = ParametersStructure.Products;
	ProductsTS = ParametersStructure.ProductsTS;
	Actuality = ParametersStructure.Actuality;
	OutputCode = ParametersStructure.OutputCode;
	OutputFullDescr = ParametersStructure.OutputFullDescr;
	ShowTitle = ParametersStructure.ShowTitle;
	UseCharacteristics = ParametersStructure.UseCharacteristics;
	FormateByAvailabilityInWarehouses = ParametersStructure.FormateByAvailabilityInWarehouses;
	
	TablePriceTypes = New ValueTable;
	TablePriceTypes.Columns.Add("NPP");
	TablePriceTypes.Columns.Add("PriceKind");
	
	VirtualTableParameters = "&Period, ";
	
	TextSelectionOnPricesKinds		= " TRUE";
	Conjunction 			= "";
	PriceKindConditions 	= " TRUE";
	
	Query = New Query;
	
	If ValueIsFilled(PriceKind) Then
		
		VirtualTableParameters = VirtualTableParameters + Conjunction + "
		|						PriceKind = (&PriceKind) ";
		Conjunction = "AND ";
		
		If PriceKind.CalculatesDynamically Then
			
			Query.SetParameter("PriceKind",  PriceKind.PricesBaseKind);
			Query.SetParameter("PricesKindsCatalogSelection",  PriceKind);
			
			TextSelectionOnPricesKinds = "CatalogPricesKind.Ref = &PricesKindsCatalogSelection";
			
		Else
			
			Query.SetParameter("PriceKind",  PriceKind);
			
			TextSelectionOnPricesKinds = "CatalogPricesKind.Ref = &PriceKind";
			
		EndIf;
		
	ElsIf TSPriceTypes.Count() > 0 Then
		
		VirtualTableParameters = VirtualTableParameters + Conjunction + "
		|						PriceKind IN HIERARCHY (&ArrayPriceKind)";
		Conjunction = "AND ";
		
		PriceTypesArray = New Array;
		PriceTypesArrayCatalogSelection = TSPriceTypes.UnloadColumn("Ref");
		For Each FilterPricesKind In TSPriceTypes Do
			
			If FilterPricesKind.Ref.CalculatesDynamically Then
				PriceTypesArray.Add(FilterPricesKind.Ref.PricesBaseKind);
			Else
				PriceTypesArray.Add(FilterPricesKind.Ref);
			EndIf;
			
		EndDo;
		
		TextSelectionOnPricesKinds = "CatalogPricesKind.Ref IN(&PriceTypesArrayCatalogSelection)";
		
		Query.SetParameter("ArrayPriceKind", PriceTypesArray);
		Query.SetParameter("PriceTypesArrayCatalogSelection", PriceTypesArrayCatalogSelection);
		
	EndIf;
	
	If ValueIsFilled(PriceGroup) Then
		
		VirtualTableParameters = VirtualTableParameters + Conjunction + "
		|						Products.PriceGroup IN HIERARCHY (&PriceGroup) ";
		Conjunction = "AND ";
		
		Query.SetParameter("PriceGroup",  PriceGroup);
		
	ElsIf TSPriceGroups.Count() > 0 Then
		
		VirtualTableParameters = VirtualTableParameters + Conjunction + "
		|						Products.PriceGroup IN HIERARCHY (&ArrayPriceGroup) ";
		Conjunction = "AND ";
		
		Query.SetParameter("ArrayPriceGroup", TSPriceGroups.UnloadColumn("Ref"));
		
	EndIf; 
	
	If ValueIsFilled(Products) Then
		
		VirtualTableParameters = VirtualTableParameters + Conjunction + "
		|						" + "Products IN HIERARCHY (&Products)";
		Conjunction = "AND ";
		
		Query.SetParameter("Products",  	Products);
		
	ElsIf ProductsTS.Count() > 0 Then
		
		VirtualTableParameters = VirtualTableParameters + Conjunction + "
		|						" + "Products IN HIERARCHY (&ArrayProducts)";
		Conjunction = "AND ";
		
		Query.SetParameter("ArrayProducts", ProductsTS.UnloadColumn("Ref"));
		
	EndIf; 
	
	If Actuality Then
		
		VirtualTableParameters = VirtualTableParameters + Conjunction + " Actuality";
		
	EndIf;
	
	Query.SetParameter("Period", ToDate);
	
	Query.Text =
	"SELECT
	|	CatalogPricesKind.Ref AS PriceKind
	|	,CASE
	|		WHEN CatalogPricesKind.CalculatesDynamically
	|			THEN CatalogPricesKind.PricesBaseKind
	|		ELSE UNDEFINED
	|	END AS PricesBaseKind
	|	,CatalogPricesKind.PriceCurrency
	|	,CatalogPricesKind.PriceFormat
	|	,CASE
	|		WHEN Not CatalogPricesKind.CalculatesDynamically
	|			THEN CatalogPricesKind.Ref
	|		ELSE CatalogPricesKind.PricesBaseKind
	|	END AS FieldForConnection
	|INTO TU_PriceTypes
	|FROM
	|	Catalog.PriceTypes AS CatalogPricesKind
	|WHERE
	|	&TextSelectionOnPricesKinds
	|
	|INDEX BY
	|	FieldForConnection
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	PricesSliceLast.Products AS Products
	|	,PricesSliceLast.Products.DescriptionFull AS DescriptionFull
	|	,PricesSliceLast.Products.Code AS ProductsCode
	|	,PricesSliceLast.Products.SKU AS ProductsSKU
	|	,PricesSliceLast.Products.MeasurementUnit AS ProductsMeasurementUnit
	|	,PricesSliceLast.Products.Description AS ProductsDescription
	|	,ISNULL(PricesSliceLast.Products.Parent, VALUE(Catalog.Products.EmptyRef)) AS Parent
	|	,CASE
	|		WHEN PricesSliceLast.Products.PriceGroup.Parent = VALUE(Catalog.PriceGroups.EmptyRef)
	|			THEN PricesSliceLast.Products.PriceGroup
	|		ELSE PricesSliceLast.Products.PriceGroup.Parent
	|	END AS PriceGroup
	|	,PricesSliceLast.Characteristic AS Characteristic
	|	,PricesSliceLast.Period
	|	,PricesSliceLast.MeasurementUnit
	|	,PricesSliceLast.Actuality
	|	,PricesSliceLast.Price AS Price
	|	,PriceTypes.PriceCurrency AS Currency
	|	,PriceTypes.PriceFormat AS PriceFormat
	|	,PricesSliceLast.Characteristic.Description AS CharacteristicDescription
	|	,PriceTypes.PriceKind AS PriceKind
	|	,PriceTypes.PricesBaseKind AS PricesBaseKind
	|FROM
	|	TU_PriceTypes AS PriceTypes
	|		LEFT JOIN InformationRegister.Prices.SliceLast(&VirtualTableParameters) AS PricesSliceLast
	|		ON PriceTypes.FieldForConnection = PricesSliceLast.PriceKind
	|	,&TextAvailabilityAtWarehouses AS TextAvailabilityAtWarehouses
	|WHERE
	|	Not PricesSliceLast.Products.DeletionMark
	|	AND &FilterConditionByActuality
	|	AND &ConditionByBalance
	|
	|ORDER BY
	|	ProductsDescription
	|	,CharacteristicDescription
	|	,PriceKind
	|TOTALS BY
	|	Parent
	|	,Products
	|	,Characteristic
	|	,PriceKind
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Products.Ref AS Ref
	|FROM
	|	Catalog.Products AS Products
	|WHERE
	|	Products.IsFolder
	|
	|ORDER BY
	|	Ref HIERARCHY";
	
	If TrimAll(VirtualTableParameters) = "&Period," Then
		
		VirtualTableParameters = "&Period";
		
	EndIf;
	
	TextAvailabilityAtWarehouses = " 
	|			INNER JOIN AccumulationRegister.Inventory.Balance(&Period, ) AS InventoryBalances ON (InventoryBalances.Products = PricesSliceLast.Products) And (InventoryBalances.Characteristic = PricesSliceLast.Characteristic) And (InventoryBalances.SalesOrder = UNDEFINED)";
	
	If Not ValueIsFilled(ToDate) Then
		
		VirtualTableParameters = StrReplace(VirtualTableParameters, "&Period", "");
		TextAvailabilityAtWarehouses = StrReplace(TextAvailabilityAtWarehouses, "&Period", "");
		
	EndIf;
	
	Query.Text = StrReplace(Query.Text, "&FilterConditionByActuality",	?(Actuality, "PricesSliceLast.Actuality", "True"));
	Query.Text = StrReplace(Query.Text, "&TextSelectionOnPricesKinds",			TextSelectionOnPricesKinds);
	Query.Text = StrReplace(Query.Text, "&VirtualTableParameters",	VirtualTableParameters);
	Query.Text = StrReplace(Query.Text, "&ConditionByBalance", 				?(FormateByAvailabilityInWarehouses, "InventoryBalances.QuantityBalance > 0", "True"));
	Query.Text = StrReplace(Query.Text, ",&TextAvailabilityAtWarehouses AS TextAvailabilityAtWarehouses", ?(FormateByAvailabilityInWarehouses, TextAvailabilityAtWarehouses, ""));
	
	ArrayQueryResult		= Query.ExecuteBatch();
	ResultQuery				= ArrayQueryResult[1];
	ResultHierarchy			= ArrayQueryResult[2];
	
	Template 						= DataProcessors.PriceList.GetTemplate("Template");
	
	AreaIndent	 			= Template.GetArea("Indent|Products");
	HeaderArea 			= Template.GetArea("Title|Products");
	AreaHeaderProducts	= Template.GetArea("Header|Products");
	AreaHeaderCharacteristic	= Template.GetArea("Header|Characteristic");
	AreaPriceGroup 		= Template.GetArea("PriceGroup|Products");
	AreaHeaderPriceKind 			= Template.GetArea("Header|PriceKind");
		
	Line = New Line(SpreadsheetDocumentCellLineType.Solid, 1);
	
	SpreadsheetDocument.Clear();
	
	If ResultQuery.IsEmpty() Then
		
		Return;
		
	EndIf; 
	
	SpreadsheetDocument.Put(AreaIndent);
	
	If ShowTitle Then
	
		HeaderArea.Parameters.Title = NStr("en = 'Price list'");
		HeaderArea.Parameters.ToDate		 = Format(ToDate, "DLF=D");
		SpreadsheetDocument.Put(HeaderArea);	
		
	EndIf;	
		
	AreaHeaderProducts.Parameters.SKUCode = ?(OutputCode = Enums.YesNo.Yes, "Code", "SKU");
	
	SpreadsheetDocument.Put(AreaHeaderProducts);
	If UseCharacteristics Then
		
		SpreadsheetDocument.Join(AreaHeaderCharacteristic);
		
	EndIf;
	
	NPP = 0;
	TablePriceTypes.Clear();
	SelectionPriceKind = ResultQuery.Select(QueryResultIteration.ByGroups, "PriceKind");
	While SelectionPriceKind.Next() Do
		
		AreaHeaderPriceKind.Parameters.PriceKind = SelectionPriceKind.PriceKind;
		AreaHeaderPriceKind.Parameters.Currency = SelectionPriceKind.PriceKind.PriceCurrency;
		
		SpreadsheetDocument.Join(AreaHeaderPriceKind);
		
		NewRow 		= TablePriceTypes.Add();
		NewRow.PriceKind	= SelectionPriceKind.PriceKind;
		NewRow.NPP		= NPP;
		
		NPP					= NPP + 1;
		
	EndDo; 
	
	OutputDataOnProductAndServicesParent(Catalogs.Products.EmptyRef(), SpreadsheetDocument, ResultQuery, TablePriceTypes, UseCharacteristics, ParametersStructure, Template, AreaPriceGroup);
	
	ProductsParentSelection = ResultHierarchy.Select(QueryResultIteration.ByGroupsWithHierarchy);
	While ProductsParentSelection.Next() Do
		
		OutputDataOnProductAndServicesParent(ProductsParentSelection, SpreadsheetDocument, ResultQuery, TablePriceTypes, UseCharacteristics, ParametersStructure, Template, AreaPriceGroup);
		
	EndDo;
	
	AreaTable = SpreadsheetDocument.Area(?(ShowTitle, 5, 2), 2, SpreadsheetDocument.TableHeight, SpreadsheetDocument.TableWidth);
 
	AreaTable.TopBorder 	= Line;
	AreaTable.BottomBorder 	= Line;
	AreaTable.LeftBorder 	= Line;
	AreaTable.RightBorder 	= Line;
	
EndProcedure

Procedure SpreadsheetDocument_PriceGroupsHierarchy(ParametersStructure, SpreadsheetDocument)
	
	ToDate = ParametersStructure.ToDate;
	PriceKind = ParametersStructure.PriceKind;
	TSPriceTypes = ParametersStructure.TSPriceTypes;
	PriceGroup = ParametersStructure.PriceGroup;
	TSPriceGroups = ParametersStructure.TSPriceGroups;
	Products = ParametersStructure.Products;
	ProductsTS = ParametersStructure.ProductsTS;
	Actuality = ParametersStructure.Actuality;
	OutputCode = ParametersStructure.OutputCode;
	OutputFullDescr = ParametersStructure.OutputFullDescr;
	ShowTitle = ParametersStructure.ShowTitle;
	UseCharacteristics = ParametersStructure.UseCharacteristics;
	FormateByAvailabilityInWarehouses = ParametersStructure.FormateByAvailabilityInWarehouses;
	
	TablePriceTypes = New ValueTable;
	TablePriceTypes.Columns.Add("NPP");
	TablePriceTypes.Columns.Add("PriceKind");
	
	VirtualTableParameters = "&Period, ";
	TextSelectionOnPricesKinds		= " TRUE";
	Conjunction 						= "";
	
	Query = New Query;	
	
	If ValueIsFilled(PriceKind) Then
		
		VirtualTableParameters = VirtualTableParameters + Conjunction + "
		|						PriceKind = (&PriceKind) ";
		Conjunction = "AND ";
		
		If PriceKind.CalculatesDynamically Then
			
			Query.SetParameter("PriceKind",  PriceKind.PricesBaseKind);
			Query.SetParameter("PricesKindsCatalogSelection",  PriceKind);
			
			TextSelectionOnPricesKinds = "CatalogPricesKind.Ref = &PricesKindsCatalogSelection";
			
		Else
			
			Query.SetParameter("PriceKind",  PriceKind);
			
			TextSelectionOnPricesKinds = "CatalogPricesKind.Ref = &PriceKind";
			
		EndIf;
		
	ElsIf TSPriceTypes.Count() > 0 Then
		
		VirtualTableParameters = VirtualTableParameters + Conjunction + "
		|						PriceKind IN HIERARCHY (&ArrayPriceKind)";
		Conjunction = "AND ";
		
		PriceTypesArray = New Array;
		PriceTypesArrayCatalogSelection = TSPriceTypes.UnloadColumn("Ref");
		For Each FilterPricesKind In TSPriceTypes Do
			
			If FilterPricesKind.Ref.CalculatesDynamically Then
				
				PriceTypesArray.Add(FilterPricesKind.Ref.PricesBaseKind);
				
			Else
				
				PriceTypesArray.Add(FilterPricesKind.Ref);
				
			EndIf;
			
		EndDo;
		
		TextSelectionOnPricesKinds = "CatalogPricesKind.Ref IN(&PriceTypesArrayCatalogSelection)";
		
		Query.SetParameter("ArrayPriceKind", PriceTypesArray);
		Query.SetParameter("PriceTypesArrayCatalogSelection", PriceTypesArrayCatalogSelection);
		
	EndIf;
	
	If ValueIsFilled(PriceGroup) Then
		
		VirtualTableParameters = VirtualTableParameters + Conjunction + "
		|						Products.PriceGroup IN HIERARCHY (&PriceGroup) ";
		Conjunction = "AND ";
		
		Query.SetParameter("PriceGroup",  PriceGroup);
		
	ElsIf TSPriceGroups.Count() > 0 Then
		
		VirtualTableParameters = VirtualTableParameters + Conjunction + "
		|						Products.PriceGroup IN HIERARCHY (&ArrayPriceGroup) ";
		Conjunction = "AND ";
		
		Query.SetParameter("ArrayPriceGroup", TSPriceGroups.UnloadColumn("Ref"));
		
	EndIf; 
	
	If ValueIsFilled(Products) Then
		
		VirtualTableParameters = VirtualTableParameters + Conjunction + "
		|						Products IN HIERARCHY (&Products)";
		Conjunction = "AND ";
		
		Query.SetParameter("Products",  	Products);
		
	ElsIf ProductsTS.Count() > 0 Then
		
		VirtualTableParameters = VirtualTableParameters + Conjunction + "
		|						Products IN HIERARCHY (&ArrayProducts)";
		Conjunction = "AND ";
		
		Query.SetParameter("ArrayProducts", ProductsTS.UnloadColumn("Ref"));
		
	EndIf; 
	
	Query.SetParameter("Period", ToDate);
	
	// ATTENTION! After the use of the query designer,
	// make sure that in the
	// string LEFT JOIN InformationRegister.Prices.SliceLast(&VirtualTableParameters) AS PricesSliceLast, there is no comma
	// remained (added automatically) after "&VirtualTableParameters"
	//
	// IN the same way, the comma is added to the &TextAvailabilityAtWarehouses AS TextAvailabilityAtWarehouses string
	
	Query.Text	= 
	"SELECT
	|	CatalogPricesKind.Ref AS PriceKind
	|	,CatalogPricesKind.PricesBaseKind AS PricesBaseKind
	|	,PricesSliceLast.Products AS Products
	|	,PricesSliceLast.Products.DescriptionFull AS DescriptionFull
	|	,PricesSliceLast.Products.Description AS ProductsDescription
	|	,PricesSliceLast.Products.PriceGroup AS PriceGroup
	|	,CASE
	|		WHEN PricesSliceLast.Products.PriceGroup.Parent = VALUE(Catalog.PriceGroups.EmptyRef)
	|			THEN PricesSliceLast.Products.PriceGroup
	|		ELSE PricesSliceLast.Products.PriceGroup.Parent
	|	END AS Parent
	|	,CASE
	|		WHEN PricesSliceLast.Products.PriceGroup.Parent = VALUE(Catalog.PriceGroups.EmptyRef)
	|			THEN PricesSliceLast.Products.PriceGroup.Order
	|		ELSE PricesSliceLast.Products.PriceGroup.Parent.Order
	|	END AS ParentOrder
	|	,PricesSliceLast.Products.PriceGroup.Order AS Order
	|	,PricesSliceLast.Characteristic AS Characteristic
	|	,PricesSliceLast.Characteristic.Description AS CharacteristicDescription
	|	,PricesSliceLast.Period
	|	,PricesSliceLast.MeasurementUnit
	|	,PricesSliceLast.Actuality
	|	,PricesSliceLast.Price AS Price
	|	,PricesSliceLast.PriceKind.PriceCurrency AS Currency
	|	,PricesSliceLast.PriceKind.PriceFormat AS PriceFormat
	|	,PricesSliceLast.Products.Code AS ProductsCode
	|	,PricesSliceLast.Products.SKU AS ProductsSKU
	|	,PricesSliceLast.Products.MeasurementUnit AS ProductsMeasurementUnit
	|FROM
	|	Catalog.PriceTypes AS CatalogPricesKind
	|		LEFT JOIN InformationRegister.Prices.SliceLast(&VirtualTableParameters) AS PricesSliceLast 
	|		ON CASE
	|				WHEN Not CatalogPricesKind.CalculatesDynamically
	|					THEN CatalogPricesKind.Ref = PricesSliceLast.PriceKind
	|				ELSE CatalogPricesKind.PricesBaseKind = PricesSliceLast.PriceKind
	|			END
	|	,&TextAvailabilityAtWarehouses AS TextAvailabilityAtWarehouses
	|WHERE
	|	&FilterConditionByActuality
	|	AND &TextSelectionOnPricesKinds
	|	AND &ConditionByBalance
	|	
	|ORDER BY
	|	ParentOrder
	|	,Order
	|	,ProductsDescription
	|	,CharacteristicDescription
	|	
	|TOTALS BY
	|	Parent
	|	,PriceGroup
	|	,Products
	|	,Characteristic
	|	,PriceKind";
	
	If TrimAll(VirtualTableParameters) = "&Period," Then
	
		VirtualTableParameters = "&Period";
	
	EndIf;
	
	TextAvailabilityAtWarehouses = " 
	|			INNER JOIN AccumulationRegister.Inventory.Balance(&Period, ) AS InventoryBalances ON (InventoryBalances.Products = PricesSliceLast.Products) And (InventoryBalances.Characteristic = PricesSliceLast.Characteristic) And (InventoryBalances.SalesOrder = UNDEFINED)";
	
	If Not ValueIsFilled(ToDate) Then
		
		VirtualTableParameters = StrReplace(VirtualTableParameters, "&Period", "");
		TextAvailabilityAtWarehouses = StrReplace(TextAvailabilityAtWarehouses, "&Period", "");
		
	EndIf;
	
	Query.Text = StrReplace(Query.Text, "&FilterConditionByActuality",	?(Actuality, "PricesSliceLast.Actuality", "True"));
	Query.Text = StrReplace(Query.Text, "&TextSelectionOnPricesKinds",			TextSelectionOnPricesKinds);
	Query.Text = StrReplace(Query.Text, "&VirtualTableParameters",	VirtualTableParameters);
	Query.Text = StrReplace(Query.Text, "&ConditionByBalance", 				?(FormateByAvailabilityInWarehouses, "InventoryBalances.QuantityBalance > 0", "True"));
	Query.Text = StrReplace(Query.Text, ",&TextAvailabilityAtWarehouses AS TextAvailabilityAtWarehouses", ?(FormateByAvailabilityInWarehouses, TextAvailabilityAtWarehouses, ""));
	
	ResultQuery 			= Query.Execute();
	
	Template 						= DataProcessors.PriceList.GetTemplate("Template");
	
	AreaIndent	 			= Template.GetArea("Indent|Products");
	HeaderArea 			= Template.GetArea("Title|Products");
	AreaHeaderProducts	= Template.GetArea("Header|Products");
	AreaHeaderCharacteristic	= Template.GetArea("Header|Characteristic");
	AreaPriceGroup 		= Template.GetArea("PriceGroup|Products");
	AreaHeaderPriceKind 			= Template.GetArea("Header|PriceKind");
		
	Line = New Line(SpreadsheetDocumentCellLineType.Solid, 1);
	
	SpreadsheetDocument.Clear();
	
	If ResultQuery.IsEmpty() Then
		
		Return;
		
	EndIf; 
	
	SpreadsheetDocument.Put(AreaIndent);
	
	If ShowTitle Then
	
		HeaderArea.Parameters.Title = NStr("en = 'Price list'");
		HeaderArea.Parameters.ToDate		 = Format(ToDate, "DLF=D");
		SpreadsheetDocument.Put(HeaderArea);	
		
	EndIf;	
		
	AreaHeaderProducts.Parameters.SKUCode = ?(OutputCode = Enums.YesNo.Yes, "Code", "SKU");
	
	SpreadsheetDocument.Put(AreaHeaderProducts);
	If UseCharacteristics Then
		
		SpreadsheetDocument.Join(AreaHeaderCharacteristic);
		
	EndIf;
	
	NPP = 0;
	TablePriceTypes.Clear();
	SelectionPriceKind = ResultQuery.Select(QueryResultIteration.ByGroups, "PriceKind");
	While SelectionPriceKind.Next() Do
		
		AreaHeaderPriceKind.Parameters.PriceKind = SelectionPriceKind.PriceKind;
		AreaHeaderPriceKind.Parameters.Currency = SelectionPriceKind.PriceKind.PriceCurrency;
		
		SpreadsheetDocument.Join(AreaHeaderPriceKind);
		
		NewRow 		= TablePriceTypes.Add();
		NewRow.PriceKind	= SelectionPriceKind.PriceKind;
		NewRow.NPP		= NPP;
		
		NPP					= NPP + 1;
		
	EndDo; 
	
	SelectionParent = ResultQuery.Select(QueryResultIteration.ByGroups, "Parent");
	While SelectionParent.Next() Do
		
		If ValueIsFilled(SelectionParent.Parent) Then
			
			AreaPriceGroup.Parameters.PriceGroup = SelectionParent.Parent;
			SpreadsheetDocument.Put(AreaPriceGroup);
			
			CurrentAreaPriceGroup = SpreadsheetDocument.Area(SpreadsheetDocument.TableHeight, 2, SpreadsheetDocument.TableHeight, SpreadsheetDocument.TableWidth);
			CurrentAreaPriceGroup.Merge();
			
			CurrentAreaPriceGroup.BackColor 	= New Color(252, 249, 226);
			CurrentAreaPriceGroup.Details = SelectionParent.Parent;
			SpreadsheetDocument.StartRowGroup();
			
			SelectionPriceGroup = SelectionParent.Select(QueryResultIteration.ByGroups, "PriceGroup");
			While SelectionPriceGroup.Next() Do
			
				If SelectionPriceGroup.PriceGroup = SelectionPriceGroup.Parent Then
					
					OutputDetails(SelectionPriceGroup.Select(QueryResultIteration.ByGroups, "Products"), UseCharacteristics, False, SpreadsheetDocument, Template, ParametersStructure, TablePriceTypes);
					
				Else
					
					AreaPriceGroup.Parameters.PriceGroup = SelectionPriceGroup.PriceGroup;
					SpreadsheetDocument.Put(AreaPriceGroup);
					
					CurrentAreaPriceGroup = SpreadsheetDocument.Area(SpreadsheetDocument.TableHeight, 2, SpreadsheetDocument.TableHeight, SpreadsheetDocument.TableWidth);
					CurrentAreaPriceGroup.Merge();
					
					CurrentAreaPriceGroup.BackColor 	= New Color(252, 249, 226);
					CurrentAreaPriceGroup.Details = SelectionPriceGroup.PriceGroup;
					SpreadsheetDocument.StartRowGroup();
					
					OutputDetails(SelectionPriceGroup.Select(QueryResultIteration.ByGroups, "Products"), UseCharacteristics, True, SpreadsheetDocument, Template, ParametersStructure, TablePriceTypes);
					
					SpreadsheetDocument.EndRowGroup();
					
				EndIf;
			
			EndDo;
			
			SpreadsheetDocument.EndRowGroup();
			
		Else
			
			SelectionPriceGroup = SelectionParent.Select(QueryResultIteration.ByGroups, "PriceGroup");
			While SelectionPriceGroup.Next() Do
				
				OutputDetails(SelectionPriceGroup.Select(QueryResultIteration.ByGroups, "Products"), UseCharacteristics, False, SpreadsheetDocument, Template, ParametersStructure, TablePriceTypes);
				
			EndDo;
				
		EndIf;
	
	EndDo;
	
	AreaTable = SpreadsheetDocument.Area(?(ShowTitle, 5, 2), 2, SpreadsheetDocument.TableHeight, SpreadsheetDocument.TableWidth);
 
	AreaTable.TopBorder 	= Line;
	AreaTable.BottomBorder 	= Line;
	AreaTable.LeftBorder 	= Line;
	AreaTable.RightBorder 	= Line;
	
EndProcedure

Procedure OutputDataOnProductAndServicesParent(ProductsParentSelection, SpreadsheetDocument, ResultQuery, TablePriceTypes, UseCharacteristics, ParametersStructure, Template, AreaPriceGroup)
	
	If Not ValueIsFilled(ProductsParentSelection) Then
		
		AreaPriceGroup.Parameters.PriceGroup = "<...>";
		SpreadsheetDocument.Put(AreaPriceGroup);
		
		CurrentAreaPriceGroup = SpreadsheetDocument.Area(SpreadsheetDocument.TableHeight, 2, SpreadsheetDocument.TableHeight, SpreadsheetDocument.TableWidth);
		CurrentAreaPriceGroup.Merge();
		
		CurrentAreaPriceGroup.BackColor 	= New Color(252, 249, 226);
		
		SpreadsheetDocument.StartRowGroup();
		
		Filter = New Structure("Parent", ProductsParentSelection);
		
		Selection = ResultQuery.Select(QueryResultIteration.ByGroups, "Parent");
		While Selection.FindNext(Filter) Do
			
			OutputDetails(Selection.Select(QueryResultIteration.ByGroups, "Products"), UseCharacteristics, False, SpreadsheetDocument, Template, ParametersStructure, TablePriceTypes);
			
		EndDo;
		
		SpreadsheetDocument.EndRowGroup();
		
	Else
		
		AreaPriceGroup.Parameters.PriceGroup = ProductsParentSelection.Ref;
		SpreadsheetDocument.Put(AreaPriceGroup);
		
		CurrentAreaPriceGroup = SpreadsheetDocument.Area(SpreadsheetDocument.TableHeight, 2, SpreadsheetDocument.TableHeight, SpreadsheetDocument.TableWidth);
		CurrentAreaPriceGroup.Merge();
		
		CurrentAreaPriceGroup.BackColor 	= New Color(252, 249, 226);
		CurrentAreaPriceGroup.Details = ProductsParentSelection.Ref;
		
		SpreadsheetDocument.StartRowGroup();
		
		ProductsParentSubordinateSelection = ProductsParentSelection.Select(QueryResultIteration.ByGroupsWithHierarchy);
		While ProductsParentSubordinateSelection.Next() Do
			
			OutputDataOnProductAndServicesParent(ProductsParentSubordinateSelection, SpreadsheetDocument, ResultQuery, TablePriceTypes, UseCharacteristics, ParametersStructure, Template, AreaPriceGroup)
			
		EndDo;
		
		Filter = New Structure("Parent", ProductsParentSelection.Ref);
		Selection = ResultQuery.Select(QueryResultIteration.ByGroups, "Parent");
		While Selection.FindNext(Filter) Do
			
			OutputDetails(Selection.Select(QueryResultIteration.ByGroups, "Products"), UseCharacteristics, False, SpreadsheetDocument, Template, ParametersStructure, TablePriceTypes);
			
		EndDo;
		
		SpreadsheetDocument.EndRowGroup();
		
	EndIf;
	
EndProcedure

#EndRegion

#EndIf