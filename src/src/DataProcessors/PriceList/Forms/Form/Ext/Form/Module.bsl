#Region Variables

&AtClient
Var InterruptIfNotCompleted;

#EndRegion

#Region GeneralPurposeProceduresAndFunctions

&AtClient
// Generate a filter structure according to passed parameters
//
// DetailsMatch - map received from details
//
Function GetPriceTypesChoiceList(DetailsMatch, CopyChangeDelete = FALSE)
	
	ChoiceList = New ValueList;
	
	If TypeOf(DetailsMatch) = Type("Map") Then
		
		For Each MapItem In DetailsMatch Do
			
			If CopyChangeDelete 
				AND Not TypeOf(MapItem.Value) = Type("Structure") Then
				
				Continue;
				
			EndIf;
			
			If CopyChangeDelete
				AND TypeOf(MapItem.Value) = Type("Structure")
				AND MapItem.Value.Property("Price")
				AND Not ValueIsFilled(MapItem.Value.Price) Then
				
				Continue;
				
			EndIf;
			
			If CopyChangeDelete
				AND MapItem.Value.Dynamic Then
				
				Continue;
				
			EndIf;
			
			ChoiceList.Add(MapItem.Key, TrimAll(MapItem.Key));
			
		EndDo;
		
	EndIf;
	
	Return ChoiceList;
	
EndFunction

&AtServer
// Procedure updates the form title
//
Procedure UpdateFormTitleAtServer()
	
	Title = NStr("en = 'Company Price-list'") + 
		?(ValueIsFilled(ToDate), NStr("en = ' on '") + Format(ToDate, "DLF=DD"), ".");
	
EndProcedure

&AtServer
// Procedure updates the constant values (global pricelist settings)
//
Procedure UpdateValuesOfConstantsOnServer()
	
	Constants.DisplayItemNumberInThePriceList.Set(OutputCode);
	Constants.DisplayDetailedDescriptionInThePriceList.Set(OutputFullDescr);
	Constants.GeneratePriceListAccordingToProductsHierarchy.Set(ItemHierarchy);
	Constants.GeneratePriceListForInStockProductsOnly.Set(FormateByAvailabilityInWarehouses);
	
EndProcedure

&AtServer
// Procedure fills tabular document.
//
Procedure UpdateAtServer()
	
	UpdateFormTitleAtServer();
	
	UpdateValuesOfConstantsOnServer();
	
	If CommonUse.FileInfobase() Then 
		
		DataProcessors.PriceList.PrepareSpreadsheetDocument(GetParametersStructureFormation(), SpreadsheetDocument);
		Completed = True;
		
	Else
		
		PrepareSpreadsheetDocumentInLongActions();
		
	EndIf;
	
EndProcedure

&AtServerNoContext
// Function returns the key of the register record.
//
Function GetRecordKey(ParametersStructure, ActualOnly = False)
	
	Query = New Query;
	Query.Text = 
	"SELECT TOP 1
	|	MAX(PricesSliceLast.Period) AS Period,
	|	PricesSliceLast.Price
	|FROM
	|	InformationRegister.Prices.SliceLast(
	|			,
	|			Period <= &ToDate
	|				AND PriceKind = &PriceKind
	|				AND Products = &Products
	|				AND Characteristic = &Characteristic
	|				AND &ActualOnly) AS PricesSliceLast
	|
	|GROUP BY
	|	PricesSliceLast.Price";
	
	If ActualOnly Then
		Query.Text = StrReplace(Query.Text, "&ActualOnly", "Actuality");
	Else
		Query.Text = StrReplace(Query.Text, "&ActualOnly", "True");
	EndIf;
	
	Query.SetParameter("ToDate", 
		?(ValueIsFilled(ParametersStructure.Period), BegOfDay(ParametersStructure.Period), CurrentDate()));
	Query.SetParameter("Products", 	ParametersStructure.Products);
	Query.SetParameter("Characteristic", ParametersStructure.Characteristic);
	Query.SetParameter("PriceKind", 		ParametersStructure.PriceKind);
	
	ReturnStructure = New Structure("CreateNewRecord, Period, PriceKind, Products, Characteristic, Price", True);
	FillPropertyValues(ReturnStructure, ParametersStructure);
	
	ResultTable = Query.Execute().Unload();
	If ResultTable.Count() > 0 Then
		
		ReturnStructure.Period			= ResultTable[0].Period;
		ReturnStructure.Price			= ResultTable[0].Price;
		ReturnStructure.CreateNewRecord	= False;
		
	EndIf; 
	
	Return ReturnStructure;
	
EndFunction

&AtClient
// Procedure opens the register record.
//
Procedure OpenRegisterRecordForm(ParametersStructure)
	
	RecordKey = GetRecordKey(ParametersStructure, Actuality);
	
	If ValueIsFilled(RecordKey) 
		AND TypeOf(RecordKey) = Type("Structure") 
		AND Not RecordKey.CreateNewRecord Then
		
		RecordKey.Delete("CreateNewRecord");
		RecordKey.Delete("Price");
		
		ParametersArray = New Array;
		ParametersArray.Add(RecordKey);
		
		RecordKeyRegister = New("InformationRegisterRecordKey.Prices", ParametersArray);
		OpenForm("InformationRegister.Prices.RecordForm", New Structure("Key", RecordKeyRegister));
		
	Else
		
		OpenForm("InformationRegister.Prices.RecordForm", New Structure("FillingValues", RecordKey));
		
	EndIf; 
	
EndProcedure

&AtServerNoContext
// Procedure saves the form settings.
//
Procedure SaveFormSettings(SettingsStructure)
	
	FormDataSettingsStorage.Save("DataProcessorPriceListForm", "SettingsStructure", SettingsStructure);
	
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
// Fills out the specified tabular section with values from the passed array on the client
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
// Procedure analyses executed specified filters
//
Procedure AnalyzeChoice(TabularSectionName)
	
	ItemCount = Object[TabularSectionName].Count();
	
	ChangeFilterPage(TabularSectionName, ItemCount > 0);
	
EndProcedure

&AtServerNoContext
// Additionally analyses the specified filter when executing the Add command
//
Function PickPriceKindForNewRecord(PriceKind)
	
	Return ?(PriceKind.CalculatesDynamically, PriceKind.PricesBaseKind, PriceKind);
	
EndFunction

&AtServer
// Procedure fills the filters with the values from the saved settings
//
Procedure RestoreValuesOfFilters(SettingsStructure, TSNamesStructure)
	
	For Each NamesStructureItem In TSNamesStructure Do
		
		TabularSectionName	= NamesStructureItem.Key;
		If SettingsStructure.Property(NamesStructureItem.Value) Then
			ItemArray = SettingsStructure[NamesStructureItem.Value];
		EndIf;
		
		If Not TypeOf(ItemArray) = Type("Array") OR ItemArray.Count() < 1 Then
			Continue;
		EndIf;
		
		Object[TabularSectionName].Clear();
		
		For Each ArrayElement In ItemArray Do
			
			NewRow		= Object[TabularSectionName].Add();
			NewRow.Ref	= ArrayElement;
			
		EndDo;
	
	EndDo;
	
	If Object.PriceTypes.Count() < 1 Then
		
		PriceKind = SettingsStructure.PriceKind;
		
	EndIf;
	
	If Object.PriceGroups.Count() < 1 Then 
		
		PriceGroup = SettingsStructure.PriceGroup;
	
	EndIf;
	
	If Object.Products.Count() < 1 Then
		SettingsStructure.Property("Products", Products);
	EndIf;
	
	If SettingsStructure.Property("Actuality") Then
		
		Actuality = SettingsStructure.Actuality;
		
	EndIf;
	
	If SettingsStructure.Property("EnableAutoCreation") Then
		
		EnableAutoCreation = SettingsStructure.EnableAutoCreation;
		
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
	
	SettingsStructure = FormDataSettingsStorage.Load("DataProcessorPriceListForm", "SettingsStructure");
	
	If TypeOf(SettingsStructure) = Type("Structure") Then
		
		TSNamesStructure = New Structure("PriceTypes, PriceGroups, Products", "CWT_PriceTypes", "CWT_PriceGroups", "CWT_Products");
		RestoreValuesOfFilters(SettingsStructure, TSNamesStructure);
		
	Else
		
		PriceKind			= Catalogs.PriceTypes.Wholesale;
		Actuality			= True;
		EnableAutoCreation	= True;
		
	EndIf;
	
	ToDate 					= Undefined;
	OutputCode				= Constants.DisplayItemNumberInThePriceList.Get();
	OutputFullDescr			= Constants.DisplayDetailedDescriptionInThePriceList.Get();
	ItemHierarchy			= Constants.GeneratePriceListAccordingToProductsHierarchy.Get();
	FormateByAvailabilityInWarehouses	= Constants.GeneratePriceListForInStockProductsOnly.Get();
	UseCharacteristics		= GetFunctionalOption("UseCharacteristics");
	Items.ShowTitle.Check	= False;
	
	Items.AbortPriceListBackGroundFormation.Visible = Not CommonUse.FileInfobase();
	
	UpdateFormTitleAtServer();
	
	CurrentArea = "R1C1";
	
	// Price accessibility setup for editing.
	AllowedEditDocumentPrices = DriveAccessManagementReUse.AllowedEditDocumentPrices();
	
	Items.Add.Visible		= AllowedEditDocumentPrices;
	Items.Copy.Visible		= AllowedEditDocumentPrices;
	Items.Change.Visible	= AllowedEditDocumentPrices;
	Items.History.Visible	= AllowedEditDocumentPrices;
	Items.Pricing.Visible	= AllowedEditDocumentPrices;
	
	// StandardSubsystems.DataImportFromExternalSources
	DataImportFromExternalSources.OnCreateAtServer(Metadata.InformationRegisters.Prices, DataLoadSettings, ThisObject, False);
	// End StandardSubsystems.DataImportFromExternalSource
	
	Items.ImportPricesFromExternalSource.Visible =
		AccessRight("Use", Metadata.DataProcessors.DataImportFromExternalSources);
	
EndProcedure

&AtClient
// Procedure - OnOpen form event handler
//
Procedure OnOpen(Cancel)
	
	// Set current form pages depending on the saved filters
	AnalyzeChoice("PriceTypes");
	AnalyzeChoice("PriceGroups");
	AnalyzeChoice("Products");
	
	StatePresentation = Items.SpreadsheetDocument.StatePresentation;
	StatePresentation.Visible = True;
	StatePresentation.AdditionalShowMode = AdditionalShowMode.DontUse;
	StatePresentation.Text = NStr("en = 'Click the Update command to generate a price list.'");
	
EndProcedure

&AtClient
// Procedure - event handler OnClose form.
//
Procedure OnClose(Exit)
	
	If Exit Then
		Return;
	EndIf;

	SettingsStructure = New Structure;
	
	SettingsStructure.Insert("PriceKind",		PriceKind);
	SettingsStructure.Insert("CWT_PriceTypes",	FillArrayByTabularSectionAtClient("PriceTypes"));
	
	SettingsStructure.Insert("PriceGroup",		PriceGroup);
	SettingsStructure.Insert("CWT_PriceGroups",	FillArrayByTabularSectionAtClient("PriceGroups"));
	
	SettingsStructure.Insert("Products",		Products);
	SettingsStructure.Insert("CWT_Products",	FillArrayByTabularSectionAtClient("Products"));
	
	SettingsStructure.Insert("ToDate",				ToDate);
	SettingsStructure.Insert("Actuality",			Actuality);
	SettingsStructure.Insert("EnableAutoCreation",	EnableAutoCreation);
	
	SaveFormSettings(SettingsStructure);
	
EndProcedure

&AtClient
Function GetDecorationTitleContent(TabularSectionName) 
	
	If Object[TabularSectionName].Count() < 1 Then
		DecorationTitle = NStr("en = 'Multiple filter is not filled'");
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
// Procedure - handler of form notification.
//
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	// StandardSubsystems.PerformanceMeasurement
	PerformanceEstimationClientServer.StartTimeMeasurement("DataProcessorPriceListGenerating");
	// StandardSubsystems.PerformanceMeasurement
	
	If EventName = "PriceChanged" Then
		If Parameter Then
			InitializeDataRefresh();
		EndIf;
		
	ElsIf EventName = "MultipleFilters" AND TypeOf(Parameter) = Type("Structure") Then
		
		ToDate				= Parameter.ToDate;
		Actuality 			= Parameter.Actuality;
		EnableAutoCreation	= Parameter.EnableAutoCreation;
		OutputCode			= Parameter.OutputCode;
		OutputFullDescr		= Parameter.OutputFullDescr;
		ItemHierarchy		= Parameter.ItemHierarchy;
		FormateByAvailabilityInWarehouses = Parameter.FormateByAvailabilityInWarehouses;
		
		// Price types
		ThisIsMultipleFilter = (TypeOf(Parameter.PriceKind) = Type("Array"));
		If ThisIsMultipleFilter Then
			
			FillTabularSectionFromArrayItemsAtClient("PriceTypes", Parameter.PriceKind, True);
			PriceKind = Undefined;
			
		Else
			
			PriceKind = Parameter.PriceKind;
			Object.PriceTypes.Clear();
			
		EndIf;
		
		ChangeFilterPage("PriceTypes", ThisIsMultipleFilter);
		
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
		
		InitializeDataRefresh();
		
	EndIf;
	
EndProcedure

&AtClient
// Procedure - event handler ChoiceProcessing of form.
//
Procedure ChoiceProcessing(ValueSelected, ChoiceSource)
	
	If TypeOf(ValueSelected) = Type("Array") Then
		
		ClearTable = True;
		
		If ChoiceSource.FormName = "DataProcessor.PriceList.Form.PricesKindsEditForm" Then
			
			FillTabularSectionFromArrayItemsAtClient("PriceTypes", ValueSelected, ClearTable);
			AnalyzeChoice("PriceTypes");
			
		ElsIf ChoiceSource.FormName = "DataProcessor.PriceList.Form.PriceGroupsEditForm" Then
			
			FillTabularSectionFromArrayItemsAtClient("PriceGroups", ValueSelected, ClearTable);
			AnalyzeChoice("PriceGroups");
			
		ElsIf ChoiceSource.FormName = "DataProcessor.PriceList.Form.ProductsEditForm" Then
			
			FillTabularSectionFromArrayItemsAtClient("Products", ValueSelected, ClearTable);
			AnalyzeChoice("Products");
			
		EndIf;
		
		InitializeDataRefresh();
		
	EndIf;
	
EndProcedure

#EndRegion

#Region ProcedureCommandHandlers

&AtClient
// Procedure - Refresh command handler.
//
Procedure Refresh(Command)
	
	InitializeDataRefresh(True);
	
EndProcedure

&AtClient
// Procedure - handler of the Add command.
//
Procedure Add(Command)
	
	DetailFromArea = SpreadsheetDocument.Area(CurrentArea).Details;
	
	If Not TypeOf(DetailFromArea) = Type("Structure") Then
		
		FillingValues = New Structure("Products", Products);
		
		If ValueIsFilled(PriceKind) Then
			
			FillingValues.Insert("PriceKind", PickPriceKindForNewRecord(PriceKind));
			
		ElsIf Object.PriceTypes.Count() = 1 Then
			
			FillingValues.Insert("PriceKind", PickPriceKindForNewRecord(Object.PriceTypes[0].Ref));
			
		EndIf;
		
		OpenForm("InformationRegister.Prices.RecordForm", New Structure("FillingValues",FillingValues));
		Return;
		
	ElsIf DetailFromArea.Property("Dynamic")
		AND DetailFromArea.Dynamic Then
		
		CommonUseClientServer.MessageToUser(
			NStr("en = 'Impossible to add the price. Perhaps, dynamic price type is selected.'"));
		Return;
		
	ElsIf DetailFromArea.Property("DetailsMatch") Then
		
		AvailablePriceTypesList = GetPriceTypesChoiceList(DetailFromArea.DetailsMatch);
		
		If AvailablePriceTypesList.Count() > 0 Then
			
			SelectedPriceKind = AvailablePriceTypesList[0].Value;
			Details 	= DetailFromArea.DetailsMatch.Get(SelectedPriceKind);
			
		Else
			
			Details 	= Undefined;
			
		EndIf;
			
	Else
		
		Details = DetailFromArea;
		
	EndIf;
	
	FillingValues = New Structure("Actuality", True);
	
	If Details = Undefined 
		OR Not TypeOf(Details) = Type("Structure") Then
		
		If Object.PriceTypes.Count() < 1 
			AND ValueIsFilled(PriceKind) Then
			
			FillingValues.Insert("PriceKind", PickPriceKindForNewRecord(PriceKind));
			
		ElsIf Object.PriceTypes.Count() = 1 Then
			
			FillingValues.Insert("PriceKind", PickPriceKindForNewRecord(Object.PriceTypes[0].Ref));
			
		ElsIf TypeOf(SelectedPriceKind) = Type("ValueListItem") Then
			
			FillingValues.Insert("PriceKind", SelectedPriceKind.Value);
			
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
			
		ElsIf TypeOf(Details) = Type("CatalogRef.ProductsCharacteristics") Then
			
			FillingValues.Insert("Products", Details.Owner);
			
		EndIf;
		
		OpenForm("InformationRegister.Prices.RecordForm", New Structure("FillingValues", FillingValues));
		Return;
		
	EndIf;
	
	FillingValues.Insert("PriceKind", 			Details.PriceKind);
	FillingValues.Insert("Products",		Details.Products);
	FillingValues.Insert("Characteristic",	Details.Characteristic);
	
	If Details.Property("Price") Then
		
		FillingValues.Insert("Price", 		Details.Price);
		
	EndIf;
	
	
	OpenForm("InformationRegister.Prices.RecordForm", New Structure("FillingValues", FillingValues),,,,, New NotifyDescription("AddEnd", ThisObject));
	
EndProcedure

&AtClient
Procedure AddEnd(Result, AdditionalParameters) Export
	
	InitializeDataRefresh();
	
EndProcedure

&AtClient
// Procedure - the Copy commands.
//
Procedure Copy(Command)

	DetailFromArea = SpreadsheetDocument.Area(CurrentArea).Details;
	
	If Not TypeOf(DetailFromArea) = Type("Structure") 
		OR (DetailFromArea.Property("Dynamic")
		AND DetailFromArea.Dynamic) Then
		
		CommonUseClientServer.MessageToUser(
			NStr("en = 'Impossible to copy the price. Perhaps, dynamic price type or the blank cell has been selected.'"));
		Return;
		
	ElsIf DetailFromArea.Property("DetailsMatch") Then
		
		AvailablePriceTypesList = GetPriceTypesChoiceList(DetailFromArea.DetailsMatch, TRUE);
		If AvailablePriceTypesList.Count() < 1 Then
			
			CommonUseClientServer.MessageToUser(
				NStr("en = 'No prices available for copying exist for the current products item in the current price list.'"));
						
			Return;
			
		ElsIf AvailablePriceTypesList.Count() > 0 Then
			
			SelectedPriceKind = AvailablePriceTypesList[0].Value;
			Details 	= DetailFromArea.DetailsMatch.Get(SelectedPriceKind);
			
		EndIf;
		
	Else
		
		Details = DetailFromArea;
		
	EndIf;
	
	
	If Details = Undefined OR Not TypeOf(Details) = Type("Structure") //no details
		OR Not Details.Property("Price") //There are no price details
		OR (Details.Property("Price") AND Not ValueIsFilled(Details.Price)) //there is a price but it is not filled out
		Then
		
		CommonUseClientServer.MessageToUser(
			NStr("en = 'Dynamic price or empty cell is specified. Copying is not possible.'"));
				
		Return;
		
	EndIf;
	
	FillingValues = New Structure("PricesKind, Products, Characteristic, MeasurementUnit, Price, Actuality",
		Details.PriceKind,
		Details.Products,
		Details.Characteristic,
		Details.MeasurementUnit,
		Details.Price,
		True);
	
	OpenForm("InformationRegister.Prices.RecordForm", New Structure("FillingValues", FillingValues));
	
	InitializeDataRefresh();
	
EndProcedure

&AtClient
// Procedure - the Change commands.
//
Procedure Change(Command)

	DetailFromArea = SpreadsheetDocument.Area(CurrentArea).Details;
	
	If Not TypeOf(DetailFromArea) = Type("Structure")
		OR (DetailFromArea.Property("Dynamic")
		AND DetailFromArea.Dynamic) Then
		
		CommonUseClientServer.MessageToUser(
			NStr("en = 'Impossible to change the price. Perhaps, dynamic price type or the blank cell has been selected.'"));
		Return;
		
	ElsIf DetailFromArea.Property("DetailsMatch") Then
		
		AvailablePriceTypesList = GetPriceTypesChoiceList(DetailFromArea.DetailsMatch, TRUE);
		If AvailablePriceTypesList.Count() < 1 Then
			
			CommonUseClientServer.MessageToUser(
				NStr("en = 'No prices available for editing exist for the current products item in the current price list.'"));
						
			Return;
			
		ElsIf AvailablePriceTypesList.Count() > 0 Then
			
			SelectedPriceKind = AvailablePriceTypesList[0].Value;
			Details 	= DetailFromArea.DetailsMatch.Get(SelectedPriceKind);
			
		EndIf;
		
	Else
		
		Details = DetailFromArea;
		
	EndIf;
	
	OpenRegisterRecordForm(Details);
	
	InitializeDataRefresh();
	
EndProcedure

&AtClient
// Procedure - handler of the History command.
//
Procedure History(Command)
	
	DetailFromArea = SpreadsheetDocument.Area(CurrentArea).Details;
	
	If Not TypeOf(DetailFromArea) = Type("Structure")
		OR (DetailFromArea.Property("Dynamic")
		AND DetailFromArea.Dynamic) Then
		
		CommonUseClientServer.MessageToUser(
			NStr("en = 'Cannot open price generation history.'"));
		Return;
		
	ElsIf DetailFromArea.Property("DetailsMatch") Then
		
		AvailablePriceTypesList = GetPriceTypesChoiceList(DetailFromArea.DetailsMatch, TRUE);
		If AvailablePriceTypesList.Count() < 1 Then
			CommonUseClientServer.MessageToUser(
				NStr("en = 'Cannot show price history for the current inventory.'"));
			Return;
		ElsIf AvailablePriceTypesList.Count() > 0 Then
			SelectedPriceKind = AvailablePriceTypesList[0].Value;
			Details 	= DetailFromArea.DetailsMatch.Get(SelectedPriceKind);
		EndIf;
	Else
		Details = DetailFromArea;
	EndIf;
	
	StructureFilter = New Structure;

	If TypeOf(Details) = Type("Structure") Then
		
		StructureFilter.Insert("Characteristic", Details.Characteristic);
		StructureFilter.Insert("Products", Details.Products);
		
		If ValueIsFilled(Details.PriceKind) Then
			
			StructureFilter.Insert("PriceKind", Details.PriceKind);
			
		EndIf;
		
		OpenForm("InformationRegister.Prices.ListForm", New Structure("Filter", StructureFilter),,,,, New NotifyDescription("HistoryEnd", ThisObject));
		
	EndIf; 
	
EndProcedure

&AtClient
Procedure HistoryEnd(Result, AdditionalParameters) Export
    
    InitializeDataRefresh();

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
// Procedure - the PricesGenerating commands.
//
Procedure Pricing(Command)
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("PriceKind", PriceKind);
	ParametersStructure.Insert("PriceGroup", PriceGroup);
	ParametersStructure.Insert("Products", Products);
	ParametersStructure.Insert("ToDate", ToDate);
	Result = Undefined;

	OpenForm("DataProcessor.Pricing.Form", ParametersStructure,,,,, New NotifyDescription("PricesGeneratingEnd", ThisObject)); 
	
EndProcedure

&AtClient
Procedure PricesGeneratingEnd(Result1, AdditionalParameters) Export
    
    Result = Result1;
    
    If ValueIsFilled(Result) Then
        
        InitializeDataRefresh();
        
    EndIf;

EndProcedure

&AtClient
// Procedure changes the ShowTitle button mark.
//
Procedure ShowTitle(Command)
	
	Items.ShowTitle.Check = Not Items.ShowTitle.Check;
	
	InitializeDataRefresh();
	
EndProcedure

&AtClient
// Procedure - event handler of the GoToMultipleFilters clicking button
Procedure GoToMultipleFilters(Command)
	
	FormParameters = New Structure;
	
	// Pass filled filters
	FormParameters.Insert("ToDate", 							ToDate);
	FormParameters.Insert("Actuality",						Actuality);
	FormParameters.Insert("EnableAutoCreation", 		EnableAutoCreation);
	
	ParameterValue = ?(Object.PriceTypes.Count() > 0, FillArrayByTabularSectionAtClient("PriceTypes"), PriceKind);
	FormParameters.Insert("PriceKind", ParameterValue);
	
	ParameterValue = ?(Object.PriceGroups.Count() > 0, FillArrayByTabularSectionAtClient("PriceGroups"), PriceGroup);
	FormParameters.Insert("PriceGroup", ParameterValue);
	
	ParameterValue = ?(Object.Products.Count() > 0, FillArrayByTabularSectionAtClient("Products"), Products);
	FormParameters.Insert("Products", ParameterValue);
	
	OpenForm("DataProcessor.PriceList.Form.MultipleFiltersForm", FormParameters, ThisForm);
	
EndProcedure

&AtClient
// Procedure-handler of the Abort command of the price list generated in the background
//
Procedure AbortPriceListBackGroundFormation(Command)
	
	InterruptIfNotCompleted = True;
	CheckExecution();
	 
EndProcedure

#EndRegion

#Region ProcedureEventHandlersOfFormAttributes

&AtClient
// Procedure - handler of the Selection event of the TabularDocument attribute.
//
Procedure SpreadsheetDocumentSelection(Item, Area, StandardProcessing)
	
	If TypeOf(Area.Details) = Type("Structure") Then
		
		StandardProcessing = False;
		If Area.Left = 3 Or Area.Left = 2 Then //Expand the SKU as Products
			OpeningStructure = New Structure("Key", Area.Details.Products);
			OpenForm("Catalog.Products.ObjectForm", OpeningStructure);
		ElsIf UseCharacteristics AND Area.Left = 4 Then
			OpeningStructure = New Structure("Key", Area.Details.Characteristic);
			OpenForm("Catalog.ProductsCharacteristics.ObjectForm", OpeningStructure);
		Else
			ParametersStructure = Area.Details;
			
			If ParametersStructure.Property("Period") Then
				ParametersStructure.Period = CurrentDate();
			EndIf;
			
			OpenRegisterRecordForm(ParametersStructure);
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
// Procedure - handler of the OnChange event of the PricesKind attribute.
//
Procedure PricesKindOnChange(Item)
	
	InitializeDataRefresh();
	
EndProcedure

&AtClient
// Procedure - handler of the OnChange event of the PriceGroup attribute.
//
Procedure PriceGroupOnChange(Item)
	
	InitializeDataRefresh();
	
EndProcedure

&AtClient
// Procedure - handler of the OnChange event of the Products attribute.
//
Procedure ProductsOnChange(Item)
	
	InitializeDataRefresh();
	
EndProcedure

&AtClient
// Procedure - handler of the Clearing event of the PricesKind attribute.
//
Procedure PriceKindClear(Item, StandardProcessing)
	
	InitializeDataRefresh();
	
EndProcedure

&AtClient
// Procedure - handler of the Clearing event of the PriceGroup attribute.
//
Procedure PriceGroupClear(Item, StandardProcessing)
	
	InitializeDataRefresh();
	
EndProcedure

&AtClient
// Procedure - handler of the Clearing event of the Products attribute.
//
Procedure ProductsClear(Item, StandardProcessing)
	
	InitializeDataRefresh();
	
EndProcedure

&AtClient
// Procedure - event handler of the the MultipleFilterByPricesKind decoration clicking
//
Procedure MultipleFilterByPriceKindClick(Item)
	
	OpenForm("DataProcessor.PriceList.Form.PricesKindsEditForm", New Structure("ArrayPriceTypes", FillArrayByTabularSectionAtClient("PriceTypes")), ThisForm);
	
EndProcedure

&AtClient
// Procedure - event handler of the MultipleFilterByPriceGroup decoration clicking
//
Procedure MultipleFilterByPriceGroupClick(Item)
	
	OpenForm("DataProcessor.PriceList.Form.PriceGroupsEditForm", New Structure("ArrayPriceGroups", FillArrayByTabularSectionAtClient("PriceGroups")), ThisForm);
	
EndProcedure

&AtClient
// Procedure - event handler of the MultipleFilterOnProducts decoration clicking
//
Procedure MultipleFilterByProductsClick(Item)
	
	OpenForm("DataProcessor.PriceList.Form.ProductsEditForm", New Structure("ProductsArray", FillArrayByTabularSectionAtClient("Products")), ThisForm);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
// Function returns the parameter structure to generate the price list
//
Function GetParametersStructureFormation()
	
	BackgroundJobLaunchParameters = New Structure;
	
	BackgroundJobLaunchParameters.Insert("ToDate", ToDate);
	BackgroundJobLaunchParameters.Insert("PriceKind", PriceKind);
	BackgroundJobLaunchParameters.Insert("TSPriceTypes", Object.PriceTypes.Unload());
	BackgroundJobLaunchParameters.Insert("PriceGroup", PriceGroup);
	BackgroundJobLaunchParameters.Insert("TSPriceGroups", Object.PriceGroups.Unload());
	BackgroundJobLaunchParameters.Insert("Products", Products);
	BackgroundJobLaunchParameters.Insert("ProductsTS", Object.Products.Unload());
	BackgroundJobLaunchParameters.Insert("Actuality", Actuality);
	BackgroundJobLaunchParameters.Insert("EnableAutoCreation", EnableAutoCreation);
	BackgroundJobLaunchParameters.Insert("OutputCode", OutputCode);
	BackgroundJobLaunchParameters.Insert("OutputFullDescr", OutputFullDescr);
	BackgroundJobLaunchParameters.Insert("ShowTitle", Items.ShowTitle.Check);
	BackgroundJobLaunchParameters.Insert("UseCharacteristics", UseCharacteristics);
	BackgroundJobLaunchParameters.Insert("ItemHierarchy", ItemHierarchy);
	BackgroundJobLaunchParameters.Insert("FormateByAvailabilityInWarehouses", FormateByAvailabilityInWarehouses);
	
	Return BackgroundJobLaunchParameters;
	
EndFunction

&AtClient
// Procedure initializes the tabular document filling
// 
Procedure InitializeDataRefresh(ThisIsManualCall = False)
	
	If Not EnableAutoCreation AND Not ThisIsManualCall Then
		Return;
	EndIf;
	
	StatePresentation = Items.SpreadsheetDocument.StatePresentation;
	StatePresentation.Visible = False;
	
	//StandardSubsystems.PerformanceMeasurement
	OperationsStartTime = PerformanceEstimationClientServer.TimerValue();
	//End StandardSubsystems.PerformanceMeasurement
	
	Completed = False;
	
	UpdateAtServer();
	
	If Completed Then
		
		PerformanceEstimationClientServer.EndTimeMeasurement(
			"DataProcessorPriceListGenerating", 
			OperationsStartTime);
	Else
		
		InterruptIfNotCompleted = False;
		
		AttachIdleHandler("CheckExecution", 0.1, True);
		
	EndIf;
	
EndProcedure

&AtServer
// Procedure generates a price list using a background job
//
Procedure PrepareSpreadsheetDocumentInLongActions()
	
	Items.AbortPriceListBackGroundFormation.Enabled = True;
	
	BackgroundJobLaunchParameters = GetParametersStructureFormation();
	
	AssignmentResult = LongActions.ExecuteInBackground(
		UUID,
		"DataProcessors.PriceList.Generate",
		BackgroundJobLaunchParameters,
		NStr("en = 'Prepare price list data'")
	);
	
	Completed = AssignmentResult.JobCompleted;
	
	If Completed Then
		
		Result = GetFromTempStorage(AssignmentResult.StorageAddress);
		
		If TypeOf(Result) = Type("SpreadsheetDocument") Then
			
			SpreadsheetDocument = Result;
			
		EndIf;
		
		Items.AbortPriceListBackGroundFormation.Enabled = False;
		
	Else
		
		BackgroundJobID  = AssignmentResult.JobID;
		BackgroundJobStorageAddress = AssignmentResult.StorageAddress;
		
		DriveServer.StateDocumentsTableLongOperation(
			Items.SpreadsheetDocument,
			NStr("en = 'Generating the report...'")
			);
		
	EndIf;
	
EndProcedure

&AtClient
// Procedure checks the tabular document filling end
//
Procedure CheckExecution()
	
	CheckResult = CheckExecutionAtServer(BackgroundJobID, BackgroundJobStorageAddress, InterruptIfNotCompleted);
	
	If CheckResult.JobCompleted Then
		
		StatePresentation = Items.SpreadsheetDocument.StatePresentation;
		StatePresentation.Visible = False;
		StatePresentation.AdditionalShowMode = AdditionalShowMode.DontUse;
		StatePresentation.Picture = New Picture;
		StatePresentation.Text = "";
		
		Items.AbortPriceListBackGroundFormation.Enabled = False;
		
		PerformanceEstimationClientServer.EndTimeMeasurement(
			"DataProcessorPriceListGenerating", 
			OperationsStartTime
			);
		
	ElsIf InterruptIfNotCompleted Then
		
		StatePresentation = Items.SpreadsheetDocument.StatePresentation;
		StatePresentation.Visible = True;
		StatePresentation.AdditionalShowMode = AdditionalShowMode.DontUse;
		StatePresentation.Picture = New Picture;
		StatePresentation.Text = NStr("en = 'Data is not relevant'");
		
		Items.AbortPriceListBackGroundFormation.Enabled = False;
		
		DetachIdleHandler("CheckExecution");
		
		PerformanceEstimationClientServer.EndTimeMeasurement(
			"DataProcessorPriceListGenerating", 
			OperationsStartTime
			);
		
	Else
		
		If BackgroundJobIntervalChecks < 15 Then
			
			BackgroundJobIntervalChecks = BackgroundJobIntervalChecks + 0.7;
			
		EndIf;
		
		InterruptIfNotCompleted = False;
		AttachIdleHandler("CheckExecution", BackgroundJobIntervalChecks, True);
		
	EndIf;
	
EndProcedure

&AtServer
// Procedure checks the tabular document filling end on server
//
Function CheckExecutionAtServer(BackgroundJobID, BackgroundJobStorageAddress, InterruptIfNotCompleted)
	
	CheckResult = New Structure("JobCompleted, Value", False, Undefined);
	
	If LongActions.JobCompleted(BackgroundJobID) Then
		
		CheckResult.JobCompleted	= True;
		SpreadsheetDocument					= GetFromTempStorage(BackgroundJobStorageAddress);
		CheckResult.Value			= SpreadsheetDocument;
		
	ElsIf InterruptIfNotCompleted Then
		
		LongActions.CancelJobExecution(BackgroundJobID);
		
	EndIf;
	
	Return CheckResult;
	
EndFunction

#Region DataImportFromExternalSources

&AtClient
Procedure ImportPricesFromExternalSource(Command)
	
	NotifyDescription = New NotifyDescription("ImportDataFromExternalSourceResultDataProcessor", ThisObject, DataLoadSettings);
	
	DataImportFromExternalSourcesClient.ShowDataImportFormFromExternalSource(DataLoadSettings, NotifyDescription, ThisObject);
	
EndProcedure

&AtClient
Procedure ImportDataFromExternalSourceResultDataProcessor(ImportResult, AdditionalParameters) Export
	
	If TypeOf(ImportResult) = Type("Structure") Then
		ProcessPreparedData(ImportResult);
		ShowMessageBox(,NStr("en = 'Data import is complete.'"));
	EndIf;
	
EndProcedure

&AtServer
Procedure ProcessPreparedData(ImportResult)
	
	DataImportFromExternalSourcesOverridable.ImportDataFromExternalSourceResultDataProcessor(ImportResult);
	
EndProcedure

#EndRegion

#EndRegion
