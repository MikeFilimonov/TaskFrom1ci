
#Region GeneralPurposeProceduresAndFunctions

&AtClient
Procedure RadioButtonFilterMode(TabularSectionName)
	
	If Items[TabularSectionName + "List"].Check Then
		
		Items["DecorationMultipleFilter" + TabularSectionName].Title = GetDecorationTitleContent(TabularSectionName);
		
	Else
		
		If Object[TabularSectionName].Count() > 0 Then
		
			QuestionText = NStr("en = 'Multiple filter will be cleared. Continue?'");
			ShowQueryBox(New NotifyDescription("RadioButtonFilterModeEnd", ThisObject, New Structure("TabularSectionName", TabularSectionName)), QuestionText, QuestionDialogMode.YesNo);
            Return;
			
		EndIf;
		
	EndIf;
	
	RadioButtonFilterModeFragment(TabularSectionName);
EndProcedure

&AtClient
Procedure RadioButtonFilterModeEnd(Result, AdditionalParameters) Export
    
    TabularSectionName = AdditionalParameters.TabularSectionName;
    
    
    If Result = DialogReturnCode.Yes Then
        
        Object[TabularSectionName].Clear();
        
    Else
        
        Items[TabularSectionName + "List"].Check = Not Items[TabularSectionName + "List"].Check;
        
    EndIf;
    
    
    RadioButtonFilterModeFragment(TabularSectionName);

EndProcedure

&AtClient
Procedure RadioButtonFilterModeFragment(Val TabularSectionName)
    
    ChangeFilterPage(TabularSectionName, Items[TabularSectionName + "List"].Check);

EndProcedure

&AtClient
Function GetDecorationTitleContent(TabularSectionName) 
	
	If Object[TabularSectionName].Count() < 1 Then
		
		DecorationTitle = "Multiple filter is not filled";
		
	ElsIf Object[TabularSectionName].Count() > 1 Then
		
		DecorationTitle = "Selected items: " + String(Object[TabularSectionName][0].Ref) + "; " + String(Object[TabularSectionName][1].Ref) + "...";
		
	Else
		
		DecorationTitle = "Selected item: " + String(Object[TabularSectionName][0].Ref);
		
	EndIf;
	
	Return DecorationTitle;
	
EndFunction

&AtClient
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
Function FillArrayByTabularSectionAtClient(TabularSectionName)
	
	ValueArray = New Array;
	
	For Each TableRow In Object[TabularSectionName] Do
		
		ValueArray.Add(TableRow.Ref);
		
	EndDo;
	
	Return ValueArray;
	
EndFunction

&AtClient
Procedure FillTabularSectionFromArrayItemsAtClient(TabularSectionName, ItemArray, ClearTable)
	
	If ClearTable Then
		
		Object[TabularSectionName].Clear();
		
	EndIf;
	
	For Each ArrayElement In ItemArray Do
		
		NewRow 		= Object[TabularSectionName].Add();
		NewRow.Ref	= ArrayElement;
		
	EndDo;
	
EndProcedure

&AtServer
Procedure FillTabularSectionFromArrayItemsAtServer(TabularSectionName, ItemArray, ClearTable = True)
	
	If ClearTable Then
		
		Object[TabularSectionName].Clear();
		
	EndIf;
	
	For Each ArrayElement In ItemArray Do
		
		NewRow 		= Object[TabularSectionName].Add();
		NewRow.Ref	= ArrayElement;
		
	EndDo;
	
EndProcedure

&AtClient
Procedure AnalyzeChoice(TabularSectionName)
	
	ItemCount = Object[TabularSectionName].Count();
	
	Items[TabularSectionName + "List"].Check = (ItemCount > 0);
	
	ChangeFilterPage(TabularSectionName, Items[TabularSectionName + "List"].Check);
	
EndProcedure

#EndRegion

#Region ProcedureFormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	ToDate 					= Parameters.ToDate;
	Actuality			= Parameters.Actuality;
	FullDescr		= Parameters.FullDescr;
	
	If TypeOf(Parameters.SupplierPriceTypes) = Type("Array") Then
		
		FillTabularSectionFromArrayItemsAtServer("SupplierPriceTypes", Parameters.SupplierPriceTypes, True);
		
	Else
		
		SupplierPriceTypes = Parameters.SupplierPriceTypes;
		
	EndIf;
	
	If TypeOf(Parameters.PriceGroup) = Type("Array") Then
		
		FillTabularSectionFromArrayItemsAtServer("PriceGroups", Parameters.PriceGroup, True);
		
	Else
		
		PriceGroup = Parameters.PriceGroup;
		
	EndIf;
	
	If TypeOf(Parameters.Products) = Type("Array") Then
		
		FillTabularSectionFromArrayItemsAtServer("Products", Parameters.Products, True);
		
	Else
		
		Products = Parameters.Products;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	Items.SupplierPriceTypesList.Check = (Object.SupplierPriceTypes.Count() > 0);
	ChangeFilterPage("SupplierPriceTypes", Items.SupplierPriceTypesList.Check);
	
	Items.PriceGroupsList.Check = (Object.PriceGroups.Count() > 0);
	ChangeFilterPage("PriceGroups", Items.PriceGroupsList.Check);
	
	Items.ProductsList.Check = (Object.Products.Count() > 0);
	ChangeFilterPage("Products", Items.ProductsList.Check);
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(ValueSelected, ChoiceSource)
	
	If TypeOf(ValueSelected) = Type("Array") Then
		
		ClearTable = (Find(ChoiceSource.FormName, "DataProcessor.SupplierPriceLists") > 0);
		
		If ChoiceSource.FormName = "Catalog.SupplierPriceTypes.Form.QuickChoiceForm" 
			OR ChoiceSource.FormName = "DataProcessor.SupplierPriceLists.Form.SupplierPriceTypesEditForm" Then
			
			FillTabularSectionFromArrayItemsAtClient("SupplierPriceTypes", ValueSelected, ClearTable);
			AnalyzeChoice("SupplierPriceTypes");
			
		ElsIf ChoiceSource.FormName = "Catalog.PriceGroups.Form.ChoiceForm" 
			OR ChoiceSource.FormName = "DataProcessor.SupplierPriceLists.Form.PriceGroupsEditForm" Then
			
			FillTabularSectionFromArrayItemsAtClient("PriceGroups", ValueSelected, ClearTable);
			AnalyzeChoice("PriceGroups");
			
		ElsIf ChoiceSource.FormName = "Catalog.Products.Form.ChoiceForm" 
			OR ChoiceSource.FormName = "DataProcessor.SupplierPriceLists.Form.ProductsEditForm" Then
			
			FillTabularSectionFromArrayItemsAtClient("Products", ValueSelected, ClearTable);
			AnalyzeChoice("Products");
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region ProcedureCommandHandlers

&AtClient
Procedure PricesKindList(Command)
	
	Items.SupplierPriceTypesList.Check = Not Items.SupplierPriceTypesList.Check;
	
	If ValueIsFilled(SupplierPriceTypes) 
		AND Items.SupplierPriceTypesList.Check Then
		
		NewRow 		= Object.SupplierPriceTypes.Add();
		NewRow.Ref	= SupplierPriceTypes;
		
		SupplierPriceTypes	= Undefined;
		
	EndIf;
	
	RadioButtonFilterMode("SupplierPriceTypes");
	
EndProcedure

&AtClient
Procedure PriceGroupsList(Command)
	
	Items.PriceGroupsList.Check = Not Items.PriceGroupsList.Check;
	
	If ValueIsFilled(PriceGroup) 
		AND Items.PriceGroupsList.Check Then
		
		NewRow 		= Object.PriceGroups.Add();
		NewRow.Ref	= PriceGroup;
		
		PriceGroup		= Undefined;
		
	EndIf;
	
	RadioButtonFilterMode("PriceGroups");
	
EndProcedure

&AtClient
Procedure ProductsList(Command)
	
	Items.ProductsList.Check = Not Items.ProductsList.Check;
	
	If ValueIsFilled(Products) 
		AND Items.ProductsList.Check Then
		
		NewRow 		= Object.Products.Add();
		NewRow.Ref	= Products;
		
		Products		= Undefined;
		
	EndIf;
	
	RadioButtonFilterMode("Products");
	
EndProcedure

&AtClient
Procedure DecorationMultipleFilterCouterpartyPriceTypesClick(Item)
	
	If Object.SupplierPriceTypes.Count() > 0 Then
		
		OpenForm("DataProcessor.SupplierPriceLists.Form.SupplierPriceTypesEditForm", New Structure("ArraySupplierPriceTypes", FillArrayByTabularSectionAtClient("SupplierPriceTypes")), ThisForm);
		
	Else
		
		OpenForm("Catalog.SupplierPriceTypes.Form.QuickChoiceForm", New Structure("MultipleChoice", True), ThisForm);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure DecorationMultipleFilterPriceGroupsClick(Item)
	
	If Object.PriceGroups.Count() > 0 Then
		
		OpenForm("DataProcessor.SupplierPriceLists.Form.PriceGroupsEditForm", New Structure("ArrayPriceGroups", FillArrayByTabularSectionAtClient("PriceGroups")), ThisForm);
		
	Else
		
		OpenForm("Catalog.PriceGroups.Form.ChoiceForm", New Structure("Multiselect", True), ThisForm);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure DecorationMultipleFilterPriceProductsClick(Item)
	
	If Object.Products.Count() > 0 Then
		
		OpenForm("DataProcessor.SupplierPriceLists.Form.ProductsEditForm", New Structure("ProductsArray", FillArrayByTabularSectionAtClient("Products")), ThisForm);
		
	Else
		
		OpenForm("Catalog.Products.Form.ChoiceForm", New Structure("Multiselect, GroupsAndItemsChoice", True, FoldersAndItemsUse.FoldersAndItems), ThisForm);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OK(Command)
	
	FormParameters = New Structure;
	
	// Pass filled filters
	FormParameters.Insert("ToDate", 				ToDate);
	FormParameters.Insert("Actuality",			Actuality);
	FormParameters.Insert("FullDescr",	FullDescr);
	
	ParameterValue = ?(Items.SupplierPriceTypesList.Check, FillArrayByTabularSectionAtClient("SupplierPriceTypes"), SupplierPriceTypes);
	FormParameters.Insert("SupplierPriceTypes", ParameterValue);
	
	ParameterValue = ?(Items.PriceGroupsList.Check, FillArrayByTabularSectionAtClient("PriceGroups"), PriceGroup);
	FormParameters.Insert("PriceGroup", ParameterValue);
	
	ParameterValue = ?(Items.ProductsList.Check, FillArrayByTabularSectionAtClient("Products"), Products);
	FormParameters.Insert("Products", ParameterValue);
	
	Notify("MultipleFiltersCounterpartyPriceLists", FormParameters);
	Close();
	
EndProcedure

#EndRegion
