
#Region GeneralPurposeProceduresAndFunctions

&AtClient
// Generate a filter structure according to passed parameters
//
// DetailsMatch - map received from details
//
Function GetSupplierPriceTypesChoiceList(DetailsMatch, CopyChangeDelete = FALSE)
	
	ChoiceList = New ValueList;
	
	If TypeOf(DetailsMatch) = Type("Map") Then
		
		For Each MapItem In DetailsMatch Do
			
			If (CopyChangeDelete
					AND Not TypeOf(MapItem.Value) = Type("Structure"))
				OR (TypeOf(MapItem.Value) = Type("Structure")
					AND MapItem.Value.Property("Price")
					AND Not ValueIsFilled(MapItem.Value.Price)) Then
				
				Continue;
				
			EndIf;
			
			ChoiceList.Add(MapItem.Key, TrimAll(MapItem.Key));
			
		EndDo;
		
	EndIf;
	
	Return ChoiceList;
	
EndFunction

&AtServer
// Creates price kind map for the tabular document fields details
//
Function CreateMapPattern()
	
	MapForDetail = New Map;
	
	For Each TableRow In TableSupplierPriceTypes Do
		
		If ValueIsFilled(TableRow.SupplierPriceTypes) Then
			
			MapForDetail.Insert(TableRow.SupplierPriceTypes, Catalogs.PriceTypes.EmptyRef());
			
		EndIf;
		
	EndDo;
	
	Return MapForDetail;
	
EndFunction

&AtServer
// Procedure updates the form title
//
Procedure UpdateFormTitleAtServer()
	
	If ValueIsFilled(ToDate) Then 
		Title = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Supplier price lists on %1'"),
			Format(ToDate, "DLF=DD"));
	Else
		Title = NStr("en = 'Supplier price lists.'")
	EndIf;
	
EndProcedure

&AtServer
// Procedure fills tabular document.
//
Procedure UpdateAtServer()
	
	UpdateFormTitleAtServer();
	
	SpreadsheetDocument.Clear();
	
	Query = New Query;
	
	VirtualTableParameters = "&Period, Products.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem) ";
	
	Conjunction = "AND ";
	
	If ValueIsFilled(SupplierPriceTypes) Then
		VirtualTableParameters = VirtualTableParameters + "
		|						" + Conjunction + " SupplierPriceTypes = &SupplierPriceTypes ";
		Conjunction = "AND ";
		
		Query.SetParameter("SupplierPriceTypes", SupplierPriceTypes);
		
	ElsIf Object.SupplierPriceTypes.Count() > 0 Then
		VirtualTableParameters = VirtualTableParameters + "
		|						" + Conjunction + " SupplierPriceTypes IN (&ArraySupplierPriceTypes) ";
		Conjunction = "AND ";
		
		Query.SetParameter("ArraySupplierPriceTypes", Object.SupplierPriceTypes.Unload(,"Ref"));
		
	EndIf;
	
	If ValueIsFilled(PriceGroup) Then
		VirtualTableParameters = VirtualTableParameters + "
		|						" + Conjunction + "Products.PriceGroup IN HIERARCHY (&PriceGroup) ";
		Conjunction = "AND ";	
		
		Query.SetParameter("PriceGroup",  	PriceGroup);
		
	ElsIf Object.PriceGroups.Count() > 0 Then
		VirtualTableParameters = VirtualTableParameters + "
		|						" + Conjunction + "Products.PriceGroup IN HIERARCHY (&ArrayPriceGroup) ";
		Conjunction = "AND ";	
		
		Query.SetParameter("ArrayPriceGroup", Object.PriceGroups.Unload(,"Ref"));
		
	EndIf; 
	
	If ValueIsFilled(Products) Then
		VirtualTableParameters = VirtualTableParameters + "
		|						" + Conjunction + "Products IN HIERARCHY (&Products) ";
		
		Query.SetParameter("Products", Products);
		
	ElsIf Object.Products.Count() > 0 Then
		VirtualTableParameters = VirtualTableParameters + "
		|						" + Conjunction + "Products IN HIERARCHY (&ArrayProducts) ";
		
		Query.SetParameter("ArrayProducts", Object.Products.Unload(,"Ref"));
		
	EndIf; 
	
	Condition = "";
	If Actuality Then
		Condition = "
		|WHERE
		|	CounterpartyPricesSliceLast.Actuality";	
	EndIf;
		
	Query.SetParameter("Period", ToDate);
	
	Query.Text =
	"SELECT
	|	Groups.Products AS Products,
	|	Groups.PriceGroup AS PriceGroup,
	|	Groups.Parent AS Parent,
	|	Groups.Characteristic AS Characteristic,
	|	Groups.SupplierPriceTypes AS SupplierPriceTypes,
	|	Groups.SupplierPriceTypes.Owner AS Counterparty,
	|	CounterpartyPricesSliceLast.MeasurementUnit,
	|	CounterpartyPricesSliceLast.Actuality,
	|	CounterpartyPricesSliceLast.Price,
	|	Groups.SupplierPriceTypes.PriceCurrency AS Currency
	|FROM
	|	(SELECT
	|		ProductsCharacteristic.Products AS Products,
	|		ProductsCharacteristic.Characteristic AS Characteristic,
	|		Columns.SupplierPriceTypes AS SupplierPriceTypes,
	|		ProductsCharacteristic.PriceGroup AS PriceGroup,
	|		ProductsCharacteristic.Parent AS Parent,
	|		ProductsCharacteristic.Order AS Order,
	|		ProductsCharacteristic.ParentOrder AS ParentOrder
	|	FROM
	|		(SELECT DISTINCT
	|			CounterpartyPricesSliceLast.SupplierPriceTypes AS SupplierPriceTypes
	|		FROM
	|			InformationRegister.CounterpartyPrices.SliceLast(
	|					" + VirtualTableParameters + ") AS CounterpartyPricesSliceLast) AS Columns,
	|		(SELECT DISTINCT
	|			CounterpartyPricesSliceLast.Products AS Products,
	|			CounterpartyPricesSliceLast.Characteristic AS Characteristic,
	|			CounterpartyPricesSliceLast.Products.PriceGroup AS PriceGroup,
	|			CASE
	|				WHEN CounterpartyPricesSliceLast.Products.PriceGroup.Parent = VALUE(Catalog.PriceGroups.EmptyRef)
	|					THEN CounterpartyPricesSliceLast.Products.PriceGroup
	|				ELSE CounterpartyPricesSliceLast.Products.PriceGroup.Parent
	|			END AS Parent,
	|			CounterpartyPricesSliceLast.Products.PriceGroup.Order AS Order,
	|			CASE
	|				WHEN CounterpartyPricesSliceLast.Products.PriceGroup.Parent = VALUE(Catalog.PriceGroups.EmptyRef)
	|					THEN CounterpartyPricesSliceLast.Products.PriceGroup.Order
	|				ELSE CounterpartyPricesSliceLast.Products.PriceGroup.Parent.Order
	|			END AS ParentOrder
	|		FROM
	|			InformationRegister.CounterpartyPrices.SliceLast(
	|					" + VirtualTableParameters + ") AS CounterpartyPricesSliceLast) AS ProductsCharacteristic) AS Groups 
	|		LEFT JOIN InformationRegister.CounterpartyPrices.SliceLast(
	|					" + VirtualTableParameters + ") AS CounterpartyPricesSliceLast 
	|		ON Groups.Products = CounterpartyPricesSliceLast.Products 
	|			AND Groups.Characteristic = CounterpartyPricesSliceLast.Characteristic
	|			AND Groups.SupplierPriceTypes = CounterpartyPricesSliceLast.SupplierPriceTypes" + Condition + "
	|
	|ORDER BY
	|	Groups.ParentOrder,
	|	Groups.Order,
	|	Groups.Products.Description,
	|	Groups.Characteristic.Description,
	|	SupplierPriceTypes,
	|	Counterparty 
	|TOTALS BY
	|	Parent,
	|	PriceGroup,
	|	Products,
	|	Characteristic,
	|	SupplierPriceTypes";
	
	ResultQuery = Query.Execute();
	
	Template = DataProcessors.SupplierPriceLists.GetTemplate("Template");
	
	AreaIndent						= Template.GetArea("Indent|Products");
	HeaderArea						= Template.GetArea("Title|Products");
	AreaHeaderProducts	= Template.GetArea("Header|Products");
	AreaHeaderCharacteristic		= Template.GetArea("Header|Characteristic");
	AreaPriceGroup					= Template.GetArea("PriceGroup|Products");
	AreaHeaderPriceKindCounterparty	= Template.GetArea("Header|SupplierPriceTypes");
		
	Line = New Line(SpreadsheetDocumentCellLineType.Solid, 1);
	
	If ResultQuery.IsEmpty() Then
		Return;
	EndIf; 
	
	SpreadsheetDocument.Put(AreaIndent);
	
	If Items.ShowTitle.Check Then
	
		HeaderArea.Parameters.Title		= NStr("en = 'Price list'");
		HeaderArea.Parameters.ToDate	= Format(ToDate, "DLF=D");
		SpreadsheetDocument.Put(HeaderArea);
		
	EndIf;	
		
	SpreadsheetDocument.Put(AreaHeaderProducts);
	If UseCharacteristics Then
		SpreadsheetDocument.Join(AreaHeaderCharacteristic);
	EndIf;
	
	NPP = 0;
	TableSupplierPriceTypes.Clear();
	
	SelectionSupplierPriceTypes = ResultQuery.Select(QueryResultIteration.ByGroups, "SupplierPriceTypes");
	While SelectionSupplierPriceTypes.Next() Do
		
		AreaHeaderPriceKindCounterparty.Parameters.SupplierPriceTypes	= SelectionSupplierPriceTypes.SupplierPriceTypes;
		AreaHeaderPriceKindCounterparty.Parameters.Counterparty				= SelectionSupplierPriceTypes.Counterparty;
		AreaHeaderPriceKindCounterparty.Parameters.Currency					= SelectionSupplierPriceTypes.Currency;
		SpreadsheetDocument.Join(AreaHeaderPriceKindCounterparty);
		
		NewRow = TableSupplierPriceTypes.Add();
		NewRow.SupplierPriceTypes	= SelectionSupplierPriceTypes.SupplierPriceTypes;
		NewRow.NPP						= NPP;
		
		NPP = NPP + 1;
		
	EndDo;
	
	SelectionParent = ResultQuery.Select(QueryResultIteration.ByGroups, "Parent");
	While SelectionParent.Next() Do
		
		If ValueIsFilled(SelectionParent.Parent) Then
				
			AreaPriceGroup.Parameters.PriceGroup = SelectionParent.Parent;
			SpreadsheetDocument.Put(AreaPriceGroup);
			
			CurrentAreaPriceGroup = SpreadsheetDocument.Area(SpreadsheetDocument.TableHeight, 2, SpreadsheetDocument.TableHeight, SpreadsheetDocument.TableWidth);
			CurrentAreaPriceGroup.Merge();
			CurrentAreaPriceGroup.BackColor	= StyleColors.BackgroundRelatedDocuments;
			CurrentAreaPriceGroup.Details	= SelectionParent.Parent;
			
			SpreadsheetDocument.StartRowGroup();
			
			SelectionPriceGroup = SelectionParent.Select(QueryResultIteration.ByGroups, "PriceGroup");
			While SelectionPriceGroup.Next() Do
				
				If SelectionPriceGroup.PriceGroup = SelectionPriceGroup.Parent Then
					OutputDetails(SelectionPriceGroup.Select(QueryResultIteration.ByGroups, "Products"), UseCharacteristics, False, Template);
				Else
					
					AreaPriceGroup.Parameters.PriceGroup = SelectionPriceGroup.PriceGroup;
					SpreadsheetDocument.Put(AreaPriceGroup);
					
					CurrentAreaPriceGroup			= SpreadsheetDocument.Area(SpreadsheetDocument.TableHeight, 2, SpreadsheetDocument.TableHeight, SpreadsheetDocument.TableWidth);
					CurrentAreaPriceGroup.Merge();
					CurrentAreaPriceGroup.BackColor	= New Color(252, 249, 226);
					CurrentAreaPriceGroup.Details	= SelectionPriceGroup.PriceGroup;
					
					SpreadsheetDocument.StartRowGroup();
					
					OutputDetails(SelectionPriceGroup.Select(QueryResultIteration.ByGroups, "Products"), UseCharacteristics, True, Template);
					
					SpreadsheetDocument.EndRowGroup();
					
				EndIf;
			
			EndDo;
			
			SpreadsheetDocument.EndRowGroup();
			
		Else
			
			SelectionPriceGroup = SelectionParent.Select(QueryResultIteration.ByGroups, "PriceGroup");
			While SelectionPriceGroup.Next() Do
				OutputDetails(SelectionPriceGroup.Select(QueryResultIteration.ByGroups, "Products"), UseCharacteristics, False, Template);
			EndDo;
				
		EndIf;
	
	EndDo;
	
	AreaTable = SpreadsheetDocument.Area(?(Items.ShowTitle.Check, 5, 2), 2, SpreadsheetDocument.TableHeight, SpreadsheetDocument.TableWidth);
 
	AreaTable.TopBorder		= Line;
	AreaTable.BottomBorder	= Line;
	AreaTable.LeftBorder	= Line;
	AreaTable.RightBorder	= Line;
	
EndProcedure

&AtServer
// Procedure displays detailed records in tabular document.
//
Procedure OutputDetails(SelectionProducts, UseCharacteristics, UsePriceGroups, Template)
	
	AreaDetailsProducts		= Template.GetArea("Details|Products");
	AreaDetailsCharacteristic			= Template.GetArea("Details|Characteristic");
	AreaDetailsPriceKindCounterparty	= Template.GetArea("Details|SupplierPriceTypes");
		
	While SelectionProducts.Next() Do
			
		SelectionCharacteristic = SelectionProducts.Select(QueryResultIteration.ByGroups, "Characteristic");
		While SelectionCharacteristic.Next() Do
			
			ProductsCharacteristicDetailsStructure = New Structure;
			ProductsCharacteristicDetailsStructure.Insert("Products",		SelectionProducts.Products);
			ProductsCharacteristicDetailsStructure.Insert("Characteristic",			Catalogs.ProductsCharacteristics.EmptyRef());
			ProductsCharacteristicDetailsStructure.Insert("DetailsMatch",			CreateMapPattern());
			
			TableHeight = SpreadsheetDocument.TableHeight;
			TableWidth = ?(UseCharacteristics, 3, 2);
			
			AreaDetailsProducts.Parameters.Products = SelectionCharacteristic.Products;
			SpreadsheetDocument.Put(AreaDetailsProducts);
			
			If UseCharacteristics Then
				AreaDetailsCharacteristic.Parameters.Characteristic = SelectionCharacteristic.Characteristic;
				SpreadsheetDocument.Join(AreaDetailsCharacteristic);
			EndIf;
			
			// Remember the used prices in the values list
			UsedPrices = New ValueList;
			
			SelectionSupplierPriceTypes = SelectionCharacteristic.Select(QueryResultIteration.ByGroups, "SupplierPriceTypes");
			While SelectionSupplierPriceTypes.Next() Do
				
				Selection = SelectionSupplierPriceTypes.Select();
				While Selection.Next() Do	
					
					DetailsStructure = New Structure;
					DetailsStructure.Insert("Products",		Selection.Products);
					DetailsStructure.Insert("Characteristic",			Selection.Characteristic);
					DetailsStructure.Insert("SupplierPriceTypes",	Selection.SupplierPriceTypes);
					DetailsStructure.Insert("Period",					ToDate);
					DetailsStructure.Insert("Price",					Selection.Price);
					DetailsStructure.Insert("Actuality",				Selection.Actuality);
					DetailsStructure.Insert("MeasurementUnit",			Selection.MeasurementUnit);
					
					NPP = TableSupplierPriceTypes.FindRows(New Structure("SupplierPriceTypes", Selection.SupplierPriceTypes))[0].NPP;
					
					AreaUnit = SpreadsheetDocument.Area(TableHeight + 1, TableWidth + NPP * 2 + 1);
					AreaUnit.Text			= Selection.MeasurementUnit;
					AreaUnit.Details		= DetailsStructure;
					AreaUnit.TextPlacement	= SpreadsheetDocumentTextPlacementType.Cut;
					
					AreaPrice = SpreadsheetDocument.Area(TableHeight + 1, TableWidth + NPP * 2 + 2);
					AreaPrice.Text 			= Format(Selection.Price, "ND=15; NFD=2");
					AreaPrice.Details		= DetailsStructure;
					
					ProductsCharacteristicDetailsStructure.DetailsMatch.Insert(Selection.SupplierPriceTypes, DetailsStructure);
					UsedPrices.Add(Selection.SupplierPriceTypes);
					
				EndDo;
				
			EndDo;
			
			// Fill out explanation for other price kinds.
			For Each SupplierPriceTypesTableRow In TableSupplierPriceTypes Do
				
				If UsedPrices.FindByValue(SupplierPriceTypesTableRow.SupplierPriceTypes) = Undefined Then
					
					AreaUnit	= SpreadsheetDocument.Area(TableHeight + 1, TableWidth + SupplierPriceTypesTableRow.NPP * 2 + 1);
					AreaPrice 	= SpreadsheetDocument.Area(TableHeight + 1, TableWidth + SupplierPriceTypesTableRow.NPP * 2 + 2);
					
					DetailsStructure = New Structure;
					DetailsStructure.Insert("Products",		SelectionProducts.Products);
					DetailsStructure.Insert("Characteristic",			SelectionCharacteristic.Characteristic);
					DetailsStructure.Insert("SupplierPriceTypes",	SupplierPriceTypesTableRow.SupplierPriceTypes);
					DetailsStructure.Insert("Period",					ToDate);
					DetailsStructure.Insert("MeasurementUnit",			SelectionProducts.Products.MeasurementUnit);
					
					AreaUnit.Details	= DetailsStructure;
					AreaPrice.Details 	= DetailsStructure;
					
				EndIf;
				
			EndDo;
			
			AreaProducts = SpreadsheetDocument.Area(TableHeight + 1, 2);
			AreaProducts.Text	= ?(FullDescr, SelectionProducts.Products.DescriptionFull, SelectionProducts.Products.Description);
			AreaProducts.Details	= ProductsCharacteristicDetailsStructure;
			
			If UseCharacteristics Then
				
				AreaCharacteristic = SpreadsheetDocument.Area(TableHeight + 1, 3);
				AreaCharacteristic.Details = ProductsCharacteristicDetailsStructure;
				
			EndIf;
			
			SpreadsheetDocument.Area(TableHeight + 1, 2, SpreadsheetDocument.TableHeight, 2).Merge();
			
			If UseCharacteristics Then			
				SpreadsheetDocument.Area(TableHeight + 1, 3, SpreadsheetDocument.TableHeight, 3).Merge();				
			EndIf;
			
		EndDo;
	
	EndDo;
		
EndProcedure

&AtServerNoContext
// Function returns the key of the register record.
//
Function GetRecordKey(ParametersStructure, ActualOnly = False)

	Query = New Query;
	Query.Text = 
	"SELECT TOP 1
	|	CounterpartyPricesSliceLast.Period
	|FROM
	|	InformationRegister.CounterpartyPrices.SliceLast(
	|			&ToDate,
	|			SupplierPriceTypes = &SupplierPriceTypes
	|				AND Products = &Products
	|				AND Characteristic = &Characteristic
	|				AND &ActualOnly) AS CounterpartyPricesSliceLast";
	
	If ActualOnly Then		
		Query.Text = StrReplace(Query.Text, "&ActualOnly", "Actuality");		
	Else		
		Query.Text = StrReplace(Query.Text, "&ActualOnly", "True");		
	EndIf;
	
	
	Query.SetParameter("ToDate",				ParametersStructure.Period);
	Query.SetParameter("Products",	ParametersStructure.Products);
	Query.SetParameter("Characteristic",		ParametersStructure.Characteristic);
	Query.SetParameter("SupplierPriceTypes",	ParametersStructure.SupplierPriceTypes);

	ReturnStructure = New Structure("NewRegisterRecord, Period, SupplierPriceTypes, Products, Characteristic", True);
	FillPropertyValues(ReturnStructure, ParametersStructure);
	
	ResultTable = Query.Execute().Unload();
	If ResultTable.Count() > 0 Then
		
		ReturnStructure.Period 				= ResultTable[0].Period;
		ReturnStructure.NewRegisterRecord	= False;
		
	EndIf; 

	Return ReturnStructure;

EndFunction

&AtClient
// Creates a decoration title by the first items values of the specified tabular section
//
Function GetDecorationTitleContent(TabularSectionName) 
	
	If Object[TabularSectionName].Count() < 1 Then
		
		DecorationTitle = Nstr("en = 'Multiple filter is not filled'");
		
	ElsIf Object[TabularSectionName].Count() = 2 Then
		
		DecorationTitle = String(Object[TabularSectionName][0].Ref) + "; " + String(Object[TabularSectionName][1].Ref);
		
	ElsIf Object[TabularSectionName].Count() > 2 Then
		
		DecorationTitle = String(Object[TabularSectionName][0].Ref) + "; " + String(Object[TabularSectionName][1].Ref) + "...";
		
	Else
		
		DecorationTitle = String(Object[TabularSectionName][0].Ref);
		
	EndIf;
	
	Return DecorationTitle;
	
EndFunction

&AtClient
// Procedure analyses executed specified filters
//
Procedure AnalyzeChoice(TabularSectionName)
	
	ItemCount = Object[TabularSectionName].Count();
	
	ChangeFilterPage(TabularSectionName, ItemCount > 0);
	
EndProcedure

&AtClient
// Procedure opens the register record.
//
Procedure OpenRegisterRecordForm(ParametersStructure)

	RecordKey = GetRecordKey(ParametersStructure, Actuality);
	If ValueIsFilled(RecordKey)
		AND TypeOf(RecordKey) = Type("Structure") 
		AND Not RecordKey.NewRegisterRecord Then
		
		RecordKey.Delete("NewRegisterRecord");
		
		ParametersArray = New Array;
		ParametersArray.Add(RecordKey);
		RecordKeyRegister = New("InformationRegisterRecordKey.CounterpartyPrices", ParametersArray);
		OpenForm("InformationRegister.CounterpartyPrices.RecordForm", New Structure("Key", RecordKeyRegister));
		
	Else
		
		OpenForm("InformationRegister.CounterpartyPrices.RecordForm", New Structure("FillingValues", RecordKey));
		
	EndIf; 
	
EndProcedure

&AtServer
// Procedure removes register record.
//
Procedure DeleteAtServer(ParametersStructure)

	RecordKey = GetRecordKey(ParametersStructure);

	If Not ValueIsFilled(RecordKey) 
		OR TypeOf(RecordKey) <> Type("Structure") 
		OR RecordKey.NewRegisterRecord Then
		
		Return;
		
	EndIf; 
	
	RecordKey.Delete("NewRegisterRecord");
	
	RecordSet = InformationRegisters.CounterpartyPrices.CreateRecordSet();
	
	For Each StructureItem In RecordKey Do
		
		RecordSet.Filter[StructureItem.Key].Set(StructureItem.Value);
		
	EndDo; 
	
	RecordSet.Write();

EndProcedure

&AtServerNoContext
// Procedure saves the form settings.
//
Procedure SaveFormSettings(SettingsStructure)
	
	FormDataSettingsStorage.Save("DatProcessorCounterpartyPriceListsForm", "SettingsStructure", SettingsStructure);
	
EndProcedure

&AtClient
// Function returns the value array containing tabular section units
//
// TabularSectionName - tabular section ID,the units of which fill the array
//
Function FillArrayByTabularSectionAtClient(TabularSectionName)
	
	ValueArray = New Array;
	
	For Each TableRow In Object[TabularSectionName] Do
		
		ValueArray.Add(TableRow.Ref);
		
	EndDo;
	
	Return ValueArray;
	
EndFunction

&AtClient
// Fills the specified tabular section by values from the passed array
//
Procedure FillTabularSectionFromArrayItemsAtClient(TabularSectionName, ItemArray, ClearTable)
	
	If ClearTable Then
		
		Object[TabularSectionName].Clear();
		
	EndIf;
	
	For Each ArrayElement In ItemArray Do
		
		NewRow 		= Object[TabularSectionName].Add();
		NewRow.Ref	= ArrayElement;
		
	EndDo;
	
EndProcedure

&AtClient
// Toggling pages with filters(Quick/Multiple)
//
Procedure ChangeFilterPage(TabularSectionName, List)
	
	GroupPages = Items["FilterPages" + TabularSectionName];
	
	SetAsCurrentPage = Undefined;
	
	For Each PageOfGroup In GroupPages.ChildItems Do
		
		If List Then
			
			If Find(PageOfGroup.Name, "MultipleFilter") > 0 Then
			
				SetAsCurrentPage = PageOfGroup;
				Break;
			
			EndIf;
			
		Else
			
			If Find(PageOfGroup.Name, "QuickFilter") > 0 Then
			
				SetAsCurrentPage = PageOfGroup;
				Break;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	Items["DecorationMultipleFilter" + TabularSectionName].Title = GetDecorationTitleContent(TabularSectionName);
	
	GroupPages.CurrentPage = SetAsCurrentPage;
	
EndProcedure

&AtServer
// Procedure fills the filters with the values from the saved settings
//
Procedure RestoreValuesOfFilters(SettingsStructure, TSNamesStructure)
	
	For Each NamesStructureItem In TSNamesStructure Do
		
		TabularSectionName	= NamesStructureItem.Key;
		If SettingsStructure.Property(NamesStructureItem.Value) Then
			
			ItemArray = SettingsStructure[NamesStructureItem.Value];
			
		EndIf;
		
		If Not TypeOf(ItemArray) = Type("Array") 
			OR ItemArray.Count() < 1 Then
			
			Continue;
			
		EndIf;
		
		Object[TabularSectionName].Clear();
		
		For Each ArrayElement In ItemArray Do
			
			NewRow 		= Object[TabularSectionName].Add();
			NewRow.Ref	= ArrayElement;
			
		EndDo;
	
	EndDo;
	
	If Object.SupplierPriceTypes.Count() < 1 Then
		
		SupplierPriceTypes = SettingsStructure.SupplierPriceTypes;
		
	EndIf;
	
	If Object.PriceGroups.Count() < 1 Then 
		
		PriceGroup = SettingsStructure.PriceGroup;
	
	EndIf;
	
	If Object.Products.Count() < 1 Then
		
		Products = SettingsStructure.Products;
		
	EndIf;
	
	If SettingsStructure.Property("ToDate") Then
		
		ToDate = SettingsStructure.ToDate;
		
	EndIf;
	
	If SettingsStructure.Property("Actuality") Then
		
		Actuality = SettingsStructure.Actuality;
		
	EndIf;
	
	If SettingsStructure.Property("FullDescr") Then
		
		FullDescr = SettingsStructure.FullDescr;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region ProcedureFormEventHandlers

&AtServer
// Procedure - event handler OnCreateAtServer of the form.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SettingsStructure = FormDataSettingsStorage.Load("DatProcessorCounterpartyPriceListsForm", "SettingsStructure");
	
	If TypeOf(SettingsStructure) = Type("Structure") Then
		
		TSNamesStructure = New Structure("SupplierPriceTypes, PriceGroups, Products", "TS_SupplierPriceTypes", "CWT_PriceGroups", "CWT_Products");
		RestoreValuesOfFilters(SettingsStructure, TSNamesStructure);
		
	Else
		
		ToDate		= CurrentSessionDate();
		Actuality	= True;
		
	EndIf;	
	
	UseCharacteristics		= Constants.UseCharacteristics.Get();
	Items.ShowTitle.Check	= False;
	
	UpdateFormTitleAtServer();
	
	UpdateAtServer();
	
	CurrentArea = "R1C1";
	
EndProcedure

&AtClient
// Procedure - OnOpen form event handler
//
Procedure OnOpen(Cancel)
	
	// Set current form pages depending on the saved filters
	AnalyzeChoice("SupplierPriceTypes");
	AnalyzeChoice("PriceGroups");
	AnalyzeChoice("Products");
	
EndProcedure

&AtClient
// Procedure - event handler OnClose form.
//
Procedure OnClose(Exit)
	
	If Exit Then
		Return;
	EndIf;
	
	SettingsStructure = New Structure;
	
	SettingsStructure.Insert("TS_SupplierPriceTypes",	FillArrayByTabularSectionAtClient("SupplierPriceTypes"));
	SettingsStructure.Insert("SupplierPriceTypes",		SupplierPriceTypes);
	
	SettingsStructure.Insert("CWT_PriceGroups",	FillArrayByTabularSectionAtClient("PriceGroups"));
	SettingsStructure.Insert("PriceGroup",		PriceGroup);
	
	SettingsStructure.Insert("CWT_Products",	FillArrayByTabularSectionAtClient("Products"));
	SettingsStructure.Insert("Products",		Products);
	
	SettingsStructure.Insert("ToDate",		ToDate);
	SettingsStructure.Insert("Actuality",	Actuality);
	SettingsStructure.Insert("FullDescr",	FullDescr);
	
	SaveFormSettings(SettingsStructure);
	
EndProcedure

&AtClient
// Procedure - handler of form notification.
//
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	// StandardSubsystems.PerformanceMeasurement
	PerformanceEstimationClientServer.StartTimeMeasurement("DataProcessorCounterpartyPriceListGeneration");
	// StandardSubsystems.PerformanceMeasurement
	
	If EventName = "CounterpartyPriceChanged" Then
		
		If Parameter Then
			
			UpdateAtServer();
			
		EndIf;
		
	ElsIf EventName = "MultipleFiltersCounterpartyPriceLists" AND TypeOf(Parameter) = Type("Structure") Then
		
		ToDate		= Parameter.ToDate;
		Actuality	= Parameter.Actuality;
		FullDescr	= Parameter.FullDescr;
		
		// Counterparty price kinds
		ThisIsMultipleFilter = (TypeOf(Parameter.SupplierPriceTypes) = Type("Array"));
		If ThisIsMultipleFilter Then
			
			FillTabularSectionFromArrayItemsAtClient("SupplierPriceTypes", Parameter.SupplierPriceTypes, True);
			SupplierPriceTypes = Undefined;
			
		Else
			
			SupplierPriceTypes = Parameter.SupplierPriceTypes;
			Object.SupplierPriceTypes.Clear();
			
		EndIf;
		
		ChangeFilterPage("SupplierPriceTypes", ThisIsMultipleFilter);
		
		// Price groups
		ThisIsMultipleFilter = (TypeOf(Parameter.PriceGroup) = Type("Array"));
		If ThisIsMultipleFilter Then
			
			FillTabularSectionFromArrayItemsAtClient("PriceGroups", Parameter.PriceGroup, True);
			PriceGroup = Undefined;
			
		Else
			
			PriceGroup = Parameter.PriceGroup;
			Object.PriceGroups.Clear();
			
		EndIf;
		
		ChangeFilterPage("PriceGroups", ThisIsMultipleFilter);
		
		// Products
		ThisIsMultipleFilter = (TypeOf(Parameter.Products) = Type("Array"));
		If ThisIsMultipleFilter Then
			
			FillTabularSectionFromArrayItemsAtClient("Products", Parameter.Products, True);
			Products = Undefined;
			
		Else
			
			Products = Parameter.Products;
			Object.Products.Clear();
			
		EndIf;
		
		ChangeFilterPage("Products", ThisIsMultipleFilter);
		
		UpdateAtServer();
		
	EndIf;
	
EndProcedure

&AtClient
// Procedure - event handler ChoiceProcessing of form.
//
Procedure ChoiceProcessing(ValueSelected, ChoiceSource)
	
	If TypeOf(ValueSelected) = Type("Array") Then
		
		ClearTable = True;
		
		If ChoiceSource.FormName = "DataProcessor.SupplierPriceLists.Form.SupplierPriceTypesEditForm" Then
			
			FillTabularSectionFromArrayItemsAtClient("SupplierPriceTypes", ValueSelected, ClearTable);
			AnalyzeChoice("SupplierPriceTypes");
			
		ElsIf ChoiceSource.FormName = "DataProcessor.SupplierPriceLists.Form.PriceGroupsEditForm" Then
			
			FillTabularSectionFromArrayItemsAtClient("PriceGroups", ValueSelected, ClearTable);
			AnalyzeChoice("PriceGroups");
			
		ElsIf ChoiceSource.FormName = "DataProcessor.SupplierPriceLists.Form.ProductsEditForm" Then
			
			FillTabularSectionFromArrayItemsAtClient("Products", ValueSelected, ClearTable);
			AnalyzeChoice("Products");
			
		EndIf;
		
		UpdateAtServer();
		
	EndIf;
	
EndProcedure

#EndRegion

#Region ProcedureCommandHandlers

&AtClient
// Procedure - Refresh command handler.
//
Procedure Refresh(Command)
	
	// StandardSubsystems.PerformanceMeasurement
	PerformanceEstimationClientServer.StartTimeMeasurement("DataProcessorCounterpartyPriceListGeneration");
	// StandardSubsystems.PerformanceMeasurement
	
	UpdateAtServer();
	
EndProcedure

&AtClient
// Procedure - handler of the Add command.
//
Procedure Add(Command)
	
	DetailFromArea = SpreadsheetDocument.Area(CurrentArea).Details;
	
	If Not TypeOf(DetailFromArea) = Type("Structure") Then
		
		FillingValues = New Structure("Products", Products);
		
		If ValueIsFilled(SupplierPriceTypes) Then
			
			FillingValues.Insert("SupplierPriceTypes", SupplierPriceTypes);
			
		ElsIf Object.SupplierPriceTypes.Count() = 1 Then
			
			FillingValues.Insert("SupplierPriceTypes", Object.SupplierPriceTypes[0].Ref);
			
		EndIf;
		
		OpenForm("InformationRegister.CounterpartyPrices.RecordForm", New Structure("FillingValues", FillingValues));
		Return;
		
	ElsIf DetailFromArea.Property("DetailsMatch") Then
		
		AvailablePriceTypesList = GetSupplierPriceTypesChoiceList(DetailFromArea.DetailsMatch);
		
		If AvailablePriceTypesList.Count() > 0 Then		
			SelectedPriceKind	= AvailablePriceTypesList[0].Value;
			Details				= DetailFromArea.DetailsMatch.Get(SelectedPriceKind);
			
		Else			
			Details = Undefined;			
		EndIf;
			
	Else		
		Details = DetailFromArea;		
	EndIf;
	
	FillingValues = New Structure("Counterparty, SupplierPriceTypes, Products, Characteristic, Actuality", , , , , True);
	
	If Details = Undefined
		OR Not TypeOf(Details) = Type("Structure") Then
		
		If Object.SupplierPriceTypes.Count() < 1 
			AND ValueIsFilled(SupplierPriceTypes) Then
			
			FillingValues.Insert("SupplierPriceTypes", SupplierPriceTypes);
			
		ElsIf TypeOf(SelectedPriceKind) = Type("ValueListItem") Then
			
			FillingValues.Insert("SupplierPriceTypes", SelectedPriceKind.Value);
			
		EndIf;
		
		If Object.Products.Count() < 1 
			AND ValueIsFilled(Products) Then
			
			FillingValues.Insert("Products", Products);
			
		ElsIf DetailFromArea.Property("Products")
			AND ValueIsFilled(DetailFromArea.Products) Then
			
			FillingValues.Insert("Products", DetailFromArea.Products);
			
			If DetailFromArea.Property("Characteristic")
				AND ValueIsFilled(DetailFromArea.Characteristic) Then
				
				FillingValues.Insert("Characteristic", DetailFromArea.Characteristic);
				
			EndIf;
			
		ElsIf TypeOf(Details) = Type("CatalogRef.Products") Then
			
			FillingValues.Insert("Products", Details);
			
		ElsIf TypeOf(Details) = Type("CatalogRef.ProductsCharacteristics") Then
			
			FillingValues.Insert("Products", DriveClient.ReadAttributeValue_Owner(Details));
			
		EndIf;
		
		OpenForm("InformationRegister.CounterpartyPrices.RecordForm", New Structure("FillingValues", FillingValues));
		Return;
		
	EndIf;
	
	If TypeOf(Details) = Type("Structure") Then
		
		FillingValues.Counterparty			= DriveClient.ReadAttributeValue_Owner(Details.SupplierPriceTypes);
		FillingValues.SupplierPriceTypes	= Details.SupplierPriceTypes;
		FillingValues.Products	= Details.Products;
		FillingValues.Characteristic		= Details.Characteristic;
		
	EndIf;
	
	OpenForm("InformationRegister.CounterpartyPrices.RecordForm", New Structure("FillingValues", FillingValues),,,,, New NotifyDescription("AddEnd", ThisObject));

EndProcedure

&AtClient
Procedure AddEnd(Result, AdditionalParameters) Export
    
    // StandardSubsystems.PerformanceMeasurement
    PerformanceEstimationClientServer.StartTimeMeasurement("DataProcessorCounterpartyPriceListGeneration");
    // StandardSubsystems.PerformanceMeasurement
    
    UpdateAtServer();

EndProcedure

&AtClient
// Procedure - the Copy commands.
//
Procedure Copy(Command)
	
	DetailFromArea = SpreadsheetDocument.Area(CurrentArea).Details;
	
	If Not TypeOf(DetailFromArea) = Type("Structure") Then
		
		CommonUseClientServer.MessageToUser(
			NStr("en = 'Impossible to copy the price. Perhaps, empty cell is selected.'"));
		Return;
		
	ElsIf DetailFromArea.Property("DetailsMatch") Then
		
		AvailablePriceTypesList = GetSupplierPriceTypesChoiceList(DetailFromArea.DetailsMatch, TRUE);
		If AvailablePriceTypesList.Count() < 1 Then
			
			CommonUseClientServer.MessageToUser(
				NStr("en = 'No prices available for copying exist for the current products item in the current price list.'"));
						
			Return;
			
		ElsIf AvailablePriceTypesList.Count() > 0 Then
			SelectedPriceKind	= AvailablePriceTypesList[0].Value;
			Details				= DetailFromArea.DetailsMatch.Get(SelectedPriceKind);			
		EndIf;
		
	Else		
		Details = DetailFromArea;		
	EndIf;

	If Details = Undefined 
		OR Not TypeOf(Details) = Type("Structure") 
		OR Not Details.Property("Price") //There are no price details
		OR (Details.Property("Price") AND Not ValueIsFilled(Details.Price)) //there is a price but it is not filled out
		Then
		
		CommonUseClientServer.MessageToUser(
			NStr("en = 'Perhaps a blank cell is selected. Copying is not possible.'"));
				
		Return;
		
	EndIf;
	
	OpenForm("InformationRegister.CounterpartyPrices.RecordForm", New Structure("FillingValues", Details));
	
	// StandardSubsystems.PerformanceMeasurement
	PerformanceEstimationClientServer.StartTimeMeasurement("DataProcessorCounterpartyPriceListGeneration");
	// StandardSubsystems.PerformanceMeasurement
	
	UpdateAtServer();
	
EndProcedure

&AtClient
// Procedure - the Change commands.
//
Procedure Change(Command)
	
	DetailFromArea = SpreadsheetDocument.Area(CurrentArea).Details;
	
	If Not TypeOf(DetailFromArea) = Type("Structure")
		OR (NOT DetailFromArea.Property("DetailsMatch")
		AND Not DetailFromArea.Property("Price")) //There are no price details
		Then
		
		CommonUseClientServer.MessageToUser(
			NStr("en = 'Impossible to change the price. Perhaps, empty cell is selected.'"));
		Return;
		
	ElsIf DetailFromArea.Property("DetailsMatch") Then
		
		AvailablePriceTypesList = GetSupplierPriceTypesChoiceList(DetailFromArea.DetailsMatch, TRUE);
		If AvailablePriceTypesList.Count() < 1 Then
			
			CommonUseClientServer.MessageToUser(
				NStr("en = 'No prices available for editing exist for the current products item in the current price list.'"));
						
			Return;
			
		ElsIf AvailablePriceTypesList.Count() > 0 Then
			
			SelectedPriceKind	= AvailablePriceTypesList[0].Value;
			Details				= DetailFromArea.DetailsMatch.Get(SelectedPriceKind);
			
		EndIf;
		
	Else		
		Details = DetailFromArea;		
	EndIf;
	
	OpenRegisterRecordForm(Details);
	
	// StandardSubsystems.PerformanceMeasurement
	PerformanceEstimationClientServer.StartTimeMeasurement("DataProcessorCounterpartyPriceListGeneration");
	// StandardSubsystems.PerformanceMeasurement
	
	UpdateAtServer();
	
EndProcedure

&AtClient
// Procedure - The Delete command handler.
//
Procedure Delete(Command)
	
	DetailFromArea = SpreadsheetDocument.Area(CurrentArea).Details;
	
	If Not TypeOf(DetailFromArea) = Type("Structure") 
		OR (NOT DetailFromArea.Property("DetailsMatch")
		AND Not DetailFromArea.Property("Price")) //There are no price details
		Then
		
		CommonUseClientServer.MessageToUser(
			NStr("en = 'It is impossible to delete the price. Perhaps, empty cell is selected.'"));
			
		Return;
		
	ElsIf DetailFromArea.Property("DetailsMatch") Then
		
		AvailablePriceTypesList = GetSupplierPriceTypesChoiceList(DetailFromArea.DetailsMatch, TRUE);
		If AvailablePriceTypesList.Count() < 1 Then
			
			CommonUseClientServer.MessageToUser(
				NStr("en = 'No prices available for deletion exist for the current products item in the current price list.'"));
						
			Return;
			
		ElsIf AvailablePriceTypesList.Count() > 0 Then
			
			SelectedPriceKind	= AvailablePriceTypesList[0].Value;
			Details				= DetailFromArea.DetailsMatch.Get(SelectedPriceKind);
			
		EndIf;
		
	Else		
		Details = DetailFromArea;		
	EndIf;
	
	DeleteAtServer(Details);
	
	// StandardSubsystems.PerformanceMeasurement
	PerformanceEstimationClientServer.StartTimeMeasurement("DataProcessorCounterpartyPriceListGeneration");
	// StandardSubsystems.PerformanceMeasurement
	
	UpdateAtServer();
	
EndProcedure

&AtClient
// Procedure - handler of the History command.
//
Procedure History(Command)
	
	DetailFromArea = SpreadsheetDocument.Area(CurrentArea).Details;
	
	If Not TypeOf(DetailFromArea) = Type("Structure")
		OR (NOT DetailFromArea.Property("DetailsMatch")
		AND Not DetailFromArea.Property("Price")) //There are no price details
		Then
		
		CommonUseClientServer.MessageToUser(
			NStr("en = 'Cannot show price generation history.'"));
			
		Return;
		
	ElsIf DetailFromArea.Property("DetailsMatch") Then
		
		AvailablePriceTypesList = GetSupplierPriceTypesChoiceList(DetailFromArea.DetailsMatch, TRUE);
		If AvailablePriceTypesList.Count() < 1 Then
			
			CommonUseClientServer.MessageToUser(
				NStr("en = 'Cannot show history of price generation for the current products item.'"));
						
			Return;
			
		ElsIf AvailablePriceTypesList.Count() > 0 Then
			
			SelectedPriceKind	= AvailablePriceTypesList[0].Value;
			Details				= DetailFromArea.DetailsMatch.Get(SelectedPriceKind);
			
		EndIf;
		
	Else		
		Details = DetailFromArea;		
	EndIf;
	
	StructureFilter = New Structure;
	
	If TypeOf(Details) = Type("Structure") Then
		
		StructureFilter.Insert("Characteristic",		Details.Characteristic);
		StructureFilter.Insert("Products",	Details.Products);
		
		If ValueIsFilled(Details.SupplierPriceTypes) Then		
			StructureFilter.Insert("SupplierPriceTypes", Details.SupplierPriceTypes);		
		EndIf;
		
		OpenForm("InformationRegister.CounterpartyPrices.ListForm", New Structure("Filter", StructureFilter),,,,, New NotifyDescription("HistoryEnd", ThisObject));
		
	EndIf; 

EndProcedure

&AtClient
Procedure HistoryEnd(Result, AdditionalParameters) Export
    
    // StandardSubsystems.PerformanceMeasurement
    PerformanceEstimationClientServer.StartTimeMeasurement("DataProcessorCounterpartyPriceListGeneration");
    // StandardSubsystems.PerformanceMeasurement
    
    UpdateAtServer();

EndProcedure

&AtClient
// Procedure - the Print commands.
//
Procedure Print(Command)
	
	If SpreadsheetDocument = Undefined Then
		Return;
	EndIf;

	SpreadsheetDocument.Copies = 1;

	If Not ValueIsFilled(SpreadsheetDocument.PrinterName) Then
		SpreadsheetDocument.FitToPage = True;
	EndIf;
	
	SpreadsheetDocument.Print(False);

EndProcedure

&AtClient
// Procedure changes the ShowTitle button mark.
//
Procedure ShowTitle(Command)
	
	// StandardSubsystems.PerformanceMeasurement
	PerformanceEstimationClientServer.StartTimeMeasurement("DataProcessorCounterpartyPriceListGeneration");
	// StandardSubsystems.PerformanceMeasurement
	
	Items.ShowTitle.Check = Not Items.ShowTitle.Check;
	
	UpdateAtServer();
	
EndProcedure

#EndRegion

#Region ProcedureEventHandlersOfFormAttributes

&AtClient
// Procedure - handler of the Selection event of the TabularDocument attribute.
//
Procedure SpreadsheetDocumentSelection(Item, Area, StandardProcessing)
	
	If TypeOf(Area.Details) = Type("Structure") Then
		
		StandardProcessing = False;
		
		If Area.Left = 2 Then
			OpeningStructure = New Structure("Key", Area.Details.Products);
			OpenForm("Catalog.Products.ObjectForm", OpeningStructure);
		ElsIf UseCharacteristics AND Area.Left = 3 Then
			OpeningStructure = New Structure("Key", Area.Details.Characteristic);
			OpenForm("Catalog.ProductsCharacteristics.ObjectForm", OpeningStructure);
		Else
			OpenRegisterRecordForm(Area.Details);
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
// Procedure - handler of the OnActivateArea event of the TabularDocument attribute.
//
Procedure SpreadsheetDocumentOnActivateArea(Item)
	
	CurrentArea = Item.CurrentArea.Name;

EndProcedure

&AtClient
// Procedure - The OnChange event handler of the SupplierPriceTypes attribute.
//
Procedure SupplierPriceTypesOnChange(Item)
	
	// StandardSubsystems.PerformanceMeasurement
	PerformanceEstimationClientServer.StartTimeMeasurement("DataProcessorCounterpartyPriceListGeneration");
	// StandardSubsystems.PerformanceMeasurement
	
	UpdateAtServer();
	
EndProcedure

&AtClient
// Procedure - handler of the OnChange event of the PriceGroup attribute.
//
Procedure PriceGroupOnChange(Item)
	
	// StandardSubsystems.PerformanceMeasurement
	PerformanceEstimationClientServer.StartTimeMeasurement("DataProcessorCounterpartyPriceListGeneration");
	// StandardSubsystems.PerformanceMeasurement
	
	UpdateAtServer();
	
EndProcedure

&AtClient
// Procedure - handler of the OnChange event of the Products attribute.
//
Procedure ProductsOnChange(Item)
	
	// StandardSubsystems.PerformanceMeasurement
	PerformanceEstimationClientServer.StartTimeMeasurement("DataProcessorCounterpartyPriceListGeneration");
	// StandardSubsystems.PerformanceMeasurement
	
	UpdateAtServer();
	
EndProcedure

&AtClient
// Procedure - handler of the Clearing event of the PricesKind attribute.
//
Procedure PriceKindClear(Item, StandardProcessing)
	
	// StandardSubsystems.PerformanceMeasurement
	PerformanceEstimationClientServer.StartTimeMeasurement("DataProcessorCounterpartyPriceListGeneration");
	// StandardSubsystems.PerformanceMeasurement
	
	UpdateAtServer();
	
EndProcedure

&AtClient
// Procedure - handler of the Clearing event of the PriceGroup attribute.
//
Procedure PriceGroupClear(Item, StandardProcessing)
	
	// StandardSubsystems.PerformanceMeasurement
	PerformanceEstimationClientServer.StartTimeMeasurement("DataProcessorCounterpartyPriceListGeneration");
	// StandardSubsystems.PerformanceMeasurement
	
	UpdateAtServer();
	
EndProcedure

&AtClient
// Procedure - handler of the Clearing event of the Products attribute.
//
Procedure ProductsClear(Item, StandardProcessing)
	
	// StandardSubsystems.PerformanceMeasurement
	PerformanceEstimationClientServer.StartTimeMeasurement("DataProcessorCounterpartyPriceListGeneration");
	// StandardSubsystems.PerformanceMeasurement
	
	UpdateAtServer();
	
EndProcedure

&AtClient
// Procedure - event handler of the GoToMultipleFilters clicking button
Procedure GoToMultipleFilters(Command)
	
	FormParameters = New Structure;
	
	// Pass filled filters
	FormParameters.Insert("ToDate",		ToDate);
	FormParameters.Insert("Actuality",	Actuality);
	FormParameters.Insert("FullDescr",	FullDescr);
	
	ParameterValue = ?(Object.SupplierPriceTypes.Count() > 0, FillArrayByTabularSectionAtClient("SupplierPriceTypes"), SupplierPriceTypes);
	FormParameters.Insert("SupplierPriceTypes", ParameterValue);
	
	ParameterValue = ?(Object.PriceGroups.Count() > 0, FillArrayByTabularSectionAtClient("PriceGroups"), PriceGroup);
	FormParameters.Insert("PriceGroup", ParameterValue);
	
	ParameterValue = ?(Object.Products.Count() > 0, FillArrayByTabularSectionAtClient("Products"), Products);
	FormParameters.Insert("Products", ParameterValue);
	
	OpenForm("DataProcessor.SupplierPriceLists.Form.MultipleFiltersForm", FormParameters, ThisForm);
	
EndProcedure

&AtClient
// Procedure - event handler of the the MultipleFilterByPricesKind decoration clicking
//
Procedure MultipleFilterByPriceKindClick(Item)
	
	OpenForm("DataProcessor.SupplierPriceLists.Form.SupplierPriceTypesEditForm", New Structure("ArraySupplierPriceTypes", FillArrayByTabularSectionAtClient("SupplierPriceTypes")), ThisForm);
	
EndProcedure

&AtClient
// Procedure - event handler of the MultipleFilterByPriceGroup decoration clicking
//
Procedure MultipleFilterByPriceGroupClick(Item)
	
	OpenForm("DataProcessor.SupplierPriceLists.Form.PriceGroupsEditForm", New Structure("ArrayPriceGroups", FillArrayByTabularSectionAtClient("PriceGroups")), ThisForm);
	
EndProcedure

&AtClient
// Procedure - event handler of the MultipleFilterOnProducts decoration clicking
//
Procedure MultipleFilterByProductsClick(Item)
	
	OpenForm("DataProcessor.SupplierPriceLists.Form.ProductsEditForm", New Structure("ProductsArray", FillArrayByTabularSectionAtClient("Products")), ThisForm);
	
EndProcedure

#EndRegion
