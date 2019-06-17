#Region Variables

&AtClient
Var FormIsClosing;

#EndRegion

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	Var InformationAboutDocument;
	
	DataProcessors.ProductsSelection.CheckParametersFilling(Parameters, Cancel);
	
	FillObjectData();
	FillInformationAboutDocument(InformationAboutDocument);
	
	SetDynamicListParameters();
	
	If ValueIsFilled(Parameters.Title) Then
		
		AutoTitle = False;
		Title = Parameters.Title;
		
	EndIf;
	
	If Object.TotalAmount > 0 Then
		
		Items.CartInfoLabel.ToolTip = NStr(
			"en = 'Total items = ""number of items in the document"" + ""number of items in the cart""
		    	|Grand total = ""cost of items in the document"" + ""cost of items in the cart""'");
		
	EndIf;
	
	EnableFulltextSearchOnOpenSelection();
	
	// fix the Warehouse balance list flicker
	CommonUseClientServer.AddCompositionItem(ListWarehouseBalances.Filter, "Products", DataCompositionComparisonType.Equal, Catalogs.Products.EmptyRef());
	CommonUseClientServer.SetDynamicListParameter(ListWarehouseBalances, "Factor", 1);
	
	SelectionSettingsCache = New Structure;
	
	SelectionSettingsCache.Insert("CurrentUser", Users.CurrentUser());
	
	SelectionSettingsCache.Insert("RequestQuantity", DriveReUse.GetValueByDefaultUser(SelectionSettingsCache.CurrentUser, "RequestQuantity", True));
	SelectionSettingsCache.Insert("RequestPrice", DriveReUse.GetValueByDefaultUser(SelectionSettingsCache.CurrentUser, "RequestPrice", True));
	SelectionSettingsCache.Insert("ShowCart", DriveReUse.GetValueByDefaultUser(SelectionSettingsCache.CurrentUser, "ShowCart", True));
	
	StockStatusFilter = DriveReUse.GetValueByDefaultUser(SelectionSettingsCache.CurrentUser, "StockStatusFilter", Enums.StockStatusFilters.All);
	If StockStatusFilter = Enums.StockStatusFilters.InStock Then
		CommonUseClientServer.AddCompositionItem(ListInventory.SettingsComposer.FixedSettings.Filter, "InStock", DataCompositionComparisonType.Greater, 0);
		CommonUseClientServer.AddCompositionItem(ListCharacteristics.SettingsComposer.FixedSettings.Filter, "InStock", DataCompositionComparisonType.Greater, 0);
		CommonUseClientServer.AddCompositionItem(ListBatches.SettingsComposer.FixedSettings.Filter, "InStock", DataCompositionComparisonType.Greater, 0);
	ElsIf StockStatusFilter = Enums.StockStatusFilters.Available Then
		CommonUseClientServer.AddCompositionItem(ListInventory.SettingsComposer.FixedSettings.Filter, "Available", DataCompositionComparisonType.Greater, 0);
		CommonUseClientServer.AddCompositionItem(ListCharacteristics.SettingsComposer.FixedSettings.Filter, "Available", DataCompositionComparisonType.Greater, 0);
		CommonUseClientServer.AddCompositionItem(ListBatches.SettingsComposer.FixedSettings.Filter, "Available", DataCompositionComparisonType.Greater, 0);
	EndIf;
	ShowItemsWithPriceOnly = DriveReUse.GetValueByDefaultUser(SelectionSettingsCache.CurrentUser, "ShowItemsWithPriceOnly");
	If ShowItemsWithPriceOnly Then
		CommonUseClientServer.AddCompositionItem(ListInventory.SettingsComposer.FixedSettings.Filter, "Price", DataCompositionComparisonType.Filled, 0);
		CommonUseClientServer.AddCompositionItem(ListCharacteristics.SettingsComposer.FixedSettings.Filter, "Price", DataCompositionComparisonType.Filled, 0);
		CommonUseClientServer.AddCompositionItem(ListBatches.SettingsComposer.FixedSettings.Filter, "Price", DataCompositionComparisonType.Filled, 0);
	EndIf;
	
	StockWarehouse = Object.StructuralUnit;
	CommonUseClientServer.SetDynamicListParameter(ListInventory,		"StockWarehouse", StockWarehouse);
	CommonUseClientServer.SetDynamicListParameter(ListCharacteristics,	"StockWarehouse", StockWarehouse);
	CommonUseClientServer.SetDynamicListParameter(ListBatches,			"StockWarehouse", StockWarehouse);
	
	SelectionSettingsCache.Insert("PricesKindPriceIncludesVAT",
		?(ValueIsFilled(Object.PriceKind),
			CommonUse.ObjectAttributeValue(Object.PriceKind, "PriceIncludesVAT"),
			Object.AmountIncludesVAT));
	SelectionSettingsCache.Insert("DiscountsMarkupsVisible", Parameters.DiscountsMarkupsVisible);
	SelectionSettingsCache.Insert("DiscountMarkupPercent",
		?(ValueIsFilled(Object.DiscountMarkupKind),
			CommonUse.ObjectAttributeValue(Object.DiscountMarkupKind, "Percent"),
			0));
	SelectionSettingsCache.Insert("InformationAboutDocument", InformationAboutDocument);
	
	SelectionSettingsCache.Insert("DiscountPercentByDiscountCard", Object.DiscountPercentByDiscountCard);
	SelectionSettingsCache.Insert("DiscountCardVisible", Parameters.DiscountCardVisible);
	
	SelectionSettingsCache.Insert("InaccessibleDataColor", StyleColors.InaccessibleDataColor);
	
	// Manually changing of the price is invalid for the CRReceipt document with a retail warehouse
	AllowedToChangeAmount = True;
	If Parameters.Property("IsCRReceipt") Then
		If ValueIsFilled(Object.StructuralUnit) Then
			AllowedToChangeAmount = Not CommonUse.ObjectAttributeValue(Object.StructuralUnit, "StructuralUnitType") = Enums.BusinessUnitsTypes.Retail;
		EndIf;
	EndIf;
	
	SelectionSettingsCache.Insert("AllowedToChangeAmount", AllowedToChangeAmount
		AND DriveAccessManagementReUse.AllowedEditDocumentPrices());
		
	ShowBatch = False;
	If Parameters.Property("ShowBatch") Then
		ShowBatch = Parameters.ShowBatch;
	EndIf;
	SelectionSettingsCache.Insert("ShowBatch", ShowBatch);
	
	ShowPrice = False;
	If Parameters.Property("ShowPrice") Then
		ShowPrice = Parameters.ShowPrice;
	EndIf;
	SelectionSettingsCache.Insert("ShowPrice", ShowPrice);
	
	ShowAvailable = False;
	If Parameters.Property("ShowAvailable") Then
		ShowAvailable = Parameters.ShowAvailable;
	EndIf;
	SelectionSettingsCache.Insert("ShowAvailable", ShowAvailable);
	
	SetFormItemsProperties();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	AttachIdleHandler("SetListWarehouseBalancesFilters", 0.2, True);
	SetCartInfoLabelText();
	SetCartShowHideLabelText()
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, MessageText, StandardProcessing)
	If Not FormIsClosing AND Not Exit Then
		If Object.ShoppingCart.Count() Then
			Cancel = True;
			ShowQueryBox(New NotifyDescription("BeforeClosingQueryBoxHandler", ThisObject),
					NStr("en = 'Add selected rows to document?'"),
					QuestionDialogMode.YesNoCancel);
		EndIf;
	EndIf;
EndProcedure

&AtClient
Procedure OnClose(Exit)
	
	If Exit Then
		Return;
	EndIf;
	
	UserSettingsToBeSaved = New Structure;
	UserSettingsToBeSaved.Insert("RequestQuantity", SelectionSettingsCache.RequestQuantity);
	UserSettingsToBeSaved.Insert("RequestPrice", SelectionSettingsCache.RequestPrice);
	UserSettingsToBeSaved.Insert("ShowCart", SelectionSettingsCache.ShowCart);
	UserSettingsToBeSaved.Insert("StockStatusFilter", StockStatusFilter);
	UserSettingsToBeSaved.Insert("ShowItemsWithPriceOnly", ShowItemsWithPriceOnly);
	UserSettingsSaving(UserSettingsToBeSaved);
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandler

&AtClient
Procedure StockStatusFilterOnChange(Item)
	
	FilterData = New Structure;
	
	FilterData.Insert("InStock",	StockStatusFilter = PredefinedValue("Enum.StockStatusFilters.InStock"));
	FilterData.Insert("Available",	StockStatusFilter = PredefinedValue("Enum.StockStatusFilters.Available"));
	
	ListFiltersChangeHandler(FilterData, DataCompositionComparisonType.Greater);
	
EndProcedure

&AtClient
Procedure StockWarehouseOnChange(Item)
	
	CommonUseClientServer.SetDynamicListParameter(ListInventory,		"StockWarehouse", StockWarehouse);
	CommonUseClientServer.SetDynamicListParameter(ListCharacteristics,	"StockWarehouse", StockWarehouse);
	CommonUseClientServer.SetDynamicListParameter(ListBatches,			"StockWarehouse", StockWarehouse);
	
EndProcedure

&AtClient
Procedure ShowItemsWithPriceOnlyOnChange(Item)
	
	ListFiltersChangeHandler(New Structure("Price", ShowItemsWithPriceOnly), DataCompositionComparisonType.Filled);
	
EndProcedure

&AtClient
Procedure SearchTextClearing(Item, StandardProcessing)
	
	SearchAndSetFilter("");
	
EndProcedure

&AtClient
Procedure SearchTextEditTextChange(Item, Text, StandardProcessing)
	
	SearchAndSetFilter(Text);
	
EndProcedure

&AtClient
Procedure CartShowHideLabelClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	SelectionSettingsCache.ShowCart = Not SelectionSettingsCache.ShowCart;
	SetCartShowHideLabelText();
	
	CommonUseClientServer.SetFormItemProperty(Items, "ShoppingCart", "Visible", SelectionSettingsCache.ShowCart);
	
EndProcedure

#EndRegion

#Region FormTableEventHandlersOfListInventoryTable

&AtClient
Procedure ListInventorySelection(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	
	If CurrentProductUseCharacteristics
		Or CurrentProductUseBatches Then
		
		If CurrentProductUseCharacteristics Then
			ShowCharacteristicsList();
		Else
			CurrentCharacteristic = PredefinedValue("Catalog.ProductsCharacteristics.EmptyRef");
			ShowBatchesList();
		EndIf;
		
	Else
		
		AddProductsToCart();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ListInventoryOnActivateRow(Item)
	
	DataCurrentRows = Items.ListInventory.CurrentData;
	
	If DataCurrentRows <> Undefined Then
		
		CurrentProduct = DataCurrentRows.ProductsRef;
		CurrentProductUseCharacteristics = DataCurrentRows.UseCharacteristics;
		CurrentProductUseBatches = DataCurrentRows.UseBatches AND SelectionSettingsCache.ShowBatch;
		
	EndIf;
		
	AttachIdleHandler("SetListWarehouseBalancesFilters", 0.2, True);
	
EndProcedure

&AtClient
Procedure ListInventoryDragEnd(Item, DragParameters, StandardProcessing)
	
	StandardProcessing = False;
	
	AddProductsToCart();
	
EndProcedure

#EndRegion

#Region FormTableEventHandlersOfListCharacteristicsTable

&AtClient
Procedure ListCharacteristicsSelection(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	
	If CurrentProductUseBatches Then
		
		ShowBatchesList();
		
	Else
		
		AddProductsToCart();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ListCharacteristicsOnActivateRow(Item)
	
	DataCurrentRows = Items.ListCharacteristics.CurrentData;
	
	If DataCurrentRows <> Undefined Then
		
		CurrentCharacteristic = DataCurrentRows.CharacteristicRef;
		
	EndIf;
	
	AttachIdleHandler("SetListWarehouseBalancesFilters", 0.2, True);
	
EndProcedure

&AtClient
Procedure ListCharacteristicsDragEnd(Item, DragParameters, StandardProcessing)
	
	StandardProcessing = False;
	
	AddProductsToCart();
	
EndProcedure

#EndRegion

#Region FormTableEventHandlersOfListBatchesTable

&AtClient
Procedure ListBatchesSelection(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	
	AddProductsToCart();
	
EndProcedure

&AtClient
Procedure ListBatchesOnActivateRow(Item)
	
	AttachIdleHandler("SetListWarehouseBalancesFilters", 0.2, True);
	
EndProcedure

&AtClient
Procedure ListBatchesDragEnd(Item, DragParameters, StandardProcessing)
	
	StandardProcessing = False;
	
	AddProductsToCart();
	
EndProcedure

#EndRegion

#Region FormTableEventHandlersOfListWarehouseBalancesTable

&AtClient
Procedure ListWarehouseBalancesSelection(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	
	AddProductsToCart();
	
EndProcedure

&AtClient
Procedure ListWarehouseBalancesDragEnd(Item, DragParameters, StandardProcessing)
	
	StandardProcessing = False;
	
	AddProductsToCart();
	
EndProcedure

#EndRegion

#Region FormTableEventHandlersOfListProductsHierarchyTable

&AtClient
Procedure ListProductsHierarchyOnActivateRow(Item)
	
	AttachIdleHandler("SetListInventoryParentFilter", 0.2, True);
	
EndProcedure

#EndRegion

#Region FormTableEventHandlersOfShoppingCartTable

&AtClient
Procedure ShoppingCartOnChange(Item)
	
	SetCartInfoLabelText();
	
EndProcedure

&AtClient
Procedure ShoppingCartProductsOnChange(Item)
	
	CartRow = Items.ShoppingCart.CurrentData;
	
	DataStructure = New Structure();
	DataStructure.Insert("Company", Object.Company);
	DataStructure.Insert("Products", CartRow.Products);
	DataStructure.Insert("Characteristic", CartRow.Characteristic);
	
	If ValueIsFilled(Object.PriceKind) Then
		DataStructure.Insert("PriceKind", Object.PriceKind);
		DataStructure.Insert("ProcessingDate", Object.Date);
		DataStructure.Insert("DocumentCurrency", Object.DocumentCurrency);
		DataStructure.Insert("AmountIncludesVAT", Object.AmountIncludesVAT);
	EndIf;
	
	GetDataProductsOnChange(DataStructure);
	
	CartRow.MeasurementUnit = DataStructure.MeasurementUnit;
	CartRow.Factor = DataStructure.Factor;
	CartRow.Price = DataStructure.Price;
	CartRow.VATRate = GetVATRate(DataStructure.VATRate);
	
	CalculateAmountInTabularSectionLine(CartRow);
	
EndProcedure

&AtClient
Procedure ShoppingCartCharacteristicOnChange(Item)
	
	CartRow = Items.ShoppingCart.CurrentData;
	
	If ValueIsFilled(Object.PriceKind) Then
		
		DataStructure = New Structure();
		DataStructure.Insert("Products",			CartRow.Products);
		DataStructure.Insert("Characteristic",		CartRow.Characteristic);
		DataStructure.Insert("PriceKind",			Object.PriceKind);
		DataStructure.Insert("ProcessingDate",		Object.Date);
		DataStructure.Insert("DocumentCurrency",	Object.DocumentCurrency);
		DataStructure.Insert("Factor",				CartRow.Factor);
		DataStructure.Insert("AmountIncludesVAT",	Object.AmountIncludesVAT);
		
		GetDataCharacteristicOnChange(DataStructure);
		
		CartRow.Price = DataStructure.Price;
		
		CalculateAmountInTabularSectionLine(CartRow);

	EndIf;
	
EndProcedure

&AtClient
Procedure ShoppingCartQuantityOnChange(Item)
	
	StringCart = Items.ShoppingCart.CurrentData;
	
	CalculateAmountInTabularSectionLine(StringCart);
	
EndProcedure

&AtClient
Procedure ShoppingCartReserveOnChange(Item)
	
	StringCart = Items.ShoppingCart.CurrentData;
	
	If StringCart.Reserve > StringCart.Quantity Then
		
		StringCart.Reserve = StringCart.Quantity;
		
	EndIf;
	
	CalculateAmountInTabularSectionLine(StringCart);
	
EndProcedure

&AtClient
Procedure ShoppingCartMeasurementUnitOnChange(Item)
	
	CartRow = Items.ShoppingCart.CurrentData;
	
	If TypeOf(CartRow.MeasurementUnit) = Type("CatalogRef.UOM")
		AND ValueIsFilled(CartRow.MeasurementUnit) Then
		
		NewFactor = GetUOMFactor(CartRow.MeasurementUnit);
		
	Else
		
		NewFactor = 1;
		
	EndIf;
	
	If CartRow.Factor <> 0 AND CartRow.Price <> 0 Then
		
		CartRow.Price = CartRow.Price * NewFactor / CartRow.Factor;
		
	EndIf;
	
	CartRow.Factor = NewFactor;
	
	CalculateAmountInTabularSectionLine(CartRow);
	
EndProcedure

&AtClient
Procedure ShoppingCartPriceOnChange(Item)
	
	StringCart = Items.ShoppingCart.CurrentData;
	
	CalculateAmountInTabularSectionLine(StringCart);
	
EndProcedure

&AtClient
Procedure ShoppingCartDiscountMarkupPercentOnChange(Item)
	
	StringCart = Items.ShoppingCart.CurrentData;
	
	CalculateAmountInTabularSectionLine(StringCart);
	
EndProcedure

&AtClient
Procedure ShoppingCartAmountOnChange(Item)
	
	StringCart = Items.ShoppingCart.CurrentData;
	
	If StringCart.DiscountMarkupPercent = 100 Then
		
		StringCart.Amount = 0;
		
	ElsIf StringCart.Quantity <> 0 Then
		
		StringCart.Price = StringCart.Amount / (1 - StringCart.DiscountMarkupPercent / 100) / StringCart.Quantity;
		
	EndIf;
	
	CalculateVATSUM(StringCart);
	
	StringCart.Total = StringCart.Amount + ?(Object.AmountIncludesVAT, 0, StringCart.VATAmount);
	
EndProcedure

&AtClient
Procedure ShoppingCartVATRateOnChange(Item)
	
	StringCart = Items.ShoppingCart.CurrentData;
	
	CalculateVATSUM(StringCart);
	
	StringCart.Total = StringCart.Amount + ?(Object.AmountIncludesVAT, 0, StringCart.VATAmount);
	
EndProcedure

&AtClient
Procedure ShoppingCartVATAmountOnChange(Item)
	
	StringCart = Items.ShoppingCart.CurrentData;
	
	StringCart.Total = StringCart.Amount + ?(Object.AmountIncludesVAT, 0, StringCart.VATAmount);
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure MoveToDocument(Command)
	
	MoveToDocumentAndClose();
	
EndProcedure

&AtClient
Procedure TransitionSearch(Command)
	
	If Items.PagesProductsCharacteristics.CurrentPage = Items.PageProducts Then
		SetCurrentFormItem(Items.ListInventorySearchText);
	ElsIf Items.PagesProductsCharacteristics.CurrentPage = Items.PageCharacteristics Then
		SetCurrentFormItem(Items.ListCharacteristicsSearchText);
	ElsIf Items.PagesProductsCharacteristics.CurrentPage = Items.PageBatches Then
		SetCurrentFormItem(Items.ListBatchesSearchText);
	EndIf;
	
EndProcedure

&AtClient
Procedure TransitionProductsList(Command)
	
	If Items.PagesProductsCharacteristics.CurrentPage = Items.PageProducts Then
		SetCurrentFormItem(Items.ListInventory);
	ElsIf Items.PagesProductsCharacteristics.CurrentPage = Items.PageCharacteristics Then
		SetCurrentFormItem(Items.ListCharacteristics);
	ElsIf Items.PagesProductsCharacteristics.CurrentPage = Items.PageBatches Then
		SetCurrentFormItem(Items.ListBatches);
	EndIf;
	
EndProcedure

&AtClient
Procedure TransitionHierarchy(Command)
	
	SetCurrentFormItem(Items.ListProductsHierarchy);
	
EndProcedure

&AtClient
Procedure TransitionCart(Command)
	
	If Not SelectionSettingsCache.ShowCart Then
		
		SelectionSettingsCache.ShowCart = True;
		SetCartShowHideLabelText();
		CommonUseClientServer.SetFormItemProperty(Items, "ShoppingCart", "Visible", SelectionSettingsCache.ShowCart);
		
	EndIf;
	
	SetCurrentFormItem(Items.ShoppingCart);
	
EndProcedure

&AtClient
Procedure RequestQuantity(Command)
	
	SelectionSettingsCache.RequestQuantity = Not SelectionSettingsCache.RequestQuantity;
	CommonUseClientServer.SetFormItemProperty(Items, "FormCommandsSettingsRequestQuantity", "Check", SelectionSettingsCache.RequestQuantity);
	
EndProcedure

&AtClient
Procedure RequestPrice(Command)
	
	SelectionSettingsCache.RequestPrice = Not SelectionSettingsCache.RequestPrice;
	CommonUseClientServer.SetFormItemProperty(Items, "FormCommandsSettingsRequestPrice", "Check", SelectionSettingsCache.RequestPrice);
	
EndProcedure

&AtClient
Procedure InformationAboutDocument(Command)
	
	OpenForm("DataProcessor.ProductsSelection.Form.InformationAboutDocument",
		SelectionSettingsCache.InformationAboutDocument,
		ThisObject, True, , , Undefined, FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtClient
Procedure AddToCart(Command)
	
	AddProductsToCart();
	
EndProcedure

&AtClient
Procedure SubstituteGoods(Command)
	
	If Items.ListInventorySubstituteGoods.Check Then
		
		CommonUseClientServer.DeleteGroupsSelectionDynamicListItems(ListInventory, "ProductsRef");
		Items.ListInventorySubstituteGoods.Check = False;
		
		Return;
		
	EndIf;
	
	DataCurrentRows = Items.ListInventory.CurrentData;
	If DataCurrentRows <> Undefined Then
		
		FilterBySubstituteGoods(DataCurrentRows.ProductsRef);
		
		Items.ListInventorySubstituteGoods.Check = True;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure GoToParent(Command)
	
	CurrentListCurrentData = GetCurrentListCurrentData();
	
	If CurrentListCurrentData <> Undefined Then
		
		Items.ListProductsHierarchy.CurrentRow = CurrentListCurrentData.Parent;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ReservationDetails(Command)
	
	CurrentListCurrentData = GetCurrentListCurrentData();
	If CurrentListCurrentData = Undefined Then
		Return;
	EndIf;
	
	DetailsParameters = New Structure;
	DetailsParameters.Insert("Company", Object.Company);
	DetailsParameters.Insert("Products", CurrentListCurrentData.ProductsRef);
	DetailsParameters.Insert("Characteristic", CurrentListCurrentData.CharacteristicRef);
	DetailsParameters.Insert("Batch", CurrentListCurrentData.BatchRef);
	
	OpenForm("DataProcessor.ProductsSelection.Form.ReservationDetails",
		DetailsParameters, ThisObject, True, , , Undefined, FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtClient
// Command is temporarily disabled
Procedure ChangePrice(Command)
	
	CurrentListCurrentData = GetCurrentListCurrentData();
	
	If CurrentListCurrentData <> Undefined Then
		
		ParametersStructure = New Structure;
		ParametersStructure.Insert("Period", Object.PricePeriod);
		ParametersStructure.Insert("PriceKind", Object.PriceKind);
		ParametersStructure.Insert("Products", CurrentListCurrentData.ProductsRef);
		ParametersStructure.Insert("Characteristic", CurrentListCurrentData.CharacteristicRef);
		ParametersStructure.Insert("MeasurementUnit", CurrentListCurrentData.MeasurementUnit);
		
		NotifyDescription = New NotifyDescription("UpdateListAfterPriceChange", ThisObject);
		
		RecordKey = GetPricesRecordKey(ParametersStructure);
		
		If RecordKey.RecordExists Then
			
			RecordKey.Delete("RecordExists");
			
			ParametersArray = New Array;
			ParametersArray.Add(RecordKey);
			
			RecordKeyRegister = New("InformationRegisterRecordKey.Prices", ParametersArray);
			
			OpenForm(
				"InformationRegister.Prices.RecordForm",
				New Structure("Key", RecordKeyRegister),
				ThisObject,
				,
				,
				,
				NotifyDescription,
				FormWindowOpeningMode.LockOwnerWindow);
			
		Else
			
			OpenForm(
				"InformationRegister.Prices.RecordForm",
				New Structure("FillingValues", ParametersStructure),
				ThisObject,
				,
				,
				,
				NotifyDescription,
				FormWindowOpeningMode.LockOwnerWindow);
			
		EndIf; 
		
	EndIf;
	
EndProcedure

&AtClient
Procedure Back(Command)
	
	If Items.PagesProductsCharacteristics.CurrentPage = Items.PageBatches
		AND CurrentProductUseCharacteristics Then
		
		ShowCharacteristicsList();
		
	Else
		
		ShowInventoryList();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure BackToProducts(Command)
	ShowInventoryList();
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

#Region FormInitialization

&AtServer
Procedure FillObjectData()
	
	FillPropertyValues(Object, Parameters);
	
	PriceKindAttributesValues = CommonUse.ObjectAttributesValues(
		Object.PriceKind,
		"PriceCurrency,
		|RoundingOrder,
		|RoundUp,
		|CalculatesDynamically,
		|PricesBaseKind,
		|Percent");
	
	Object.PriceKindCurrency = PriceKindAttributesValues.PriceCurrency;
	Object.RoundingOrder = PriceKindAttributesValues.RoundingOrder;
	Object.RoundUp = PriceKindAttributesValues.RoundUp;
	
	If PriceKindAttributesValues.CalculatesDynamically = True Then
		
		Object.DynamicPriceKindBasic = PriceKindAttributesValues.PricesBaseKind;
		Object.DynamicPriceKindPercent = PriceKindAttributesValues.Percent;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure FillInformationAboutDocument(InformationAboutDocument)
	
	DataProcessors.ProductsSelection.InformationAboutDocumentStructure(InformationAboutDocument);
	FillPropertyValues(InformationAboutDocument, Object);
	InformationAboutDocument.Insert("DiscountsMarkupsVisible", Parameters.DiscountsMarkupsVisible);
	
EndProcedure

&AtServer
Procedure SetDynamicListParameters()
	
	ListsArray = New Array;
	ListsArray.Add(ListInventory);
	ListsArray.Add(ListCharacteristics);
	ListsArray.Add(ListBatches);
	
	ExchangeRates = DriveServer.GetExchangeRates(Object.PriceKindCurrency, Object.DocumentCurrency, Object.Date);
	
	For Each DynamicList In ListsArray Do
		
		DynamicList.Parameters.SetParameterValue("PriceKindCurrencyRate",			ExchangeRates.InitRate);
		DynamicList.Parameters.SetParameterValue("PriceKindCurrencyMultiplicity",	ExchangeRates.RepetitionBeg);
		DynamicList.Parameters.SetParameterValue("DocumentCurrencyRate",			ExchangeRates.ExchangeRate);
		DynamicList.Parameters.SetParameterValue("DocumentCurrencyMultiplicity",	ExchangeRates.Multiplicity);
		// Percent = 0 for the dynamical prices kinds, therefore the price does not change.
		DynamicList.Parameters.SetParameterValue("DynamicPriceKindPercent", 		Object.DynamicPriceKindPercent);
		
	EndDo;
	
	ListsArray.Add(ListProductsHierarchy);
	ListsArray.Add(ListWarehouseBalances);
	
	// Parameters filled in a special way
	ParemeterCompany = New DataCompositionParameter("Company");
	ParemeterPriceKind = New DataCompositionParameter("PriceKind");
	
	For Each DynamicList In ListsArray Do
		For Each ListParameter In DynamicList.Parameters.Items Do
			
			ObjectAttributeValue = Undefined;
			If ListParameter.Parameter = ParemeterCompany Then
				
				DynamicList.Parameters.SetParameterValue(ListParameter.Parameter, DriveServer.GetCompany(Object.Company));
				
			ElsIf ListParameter.Parameter = ParemeterPriceKind Then
				
				If ValueIsFilled(Object.DynamicPriceKindBasic) Then
					DynamicList.Parameters.SetParameterValue("PriceKind", Object.DynamicPriceKindBasic);
				Else
					DynamicList.Parameters.SetParameterValue("PriceKind", Object.PriceKind);
				EndIf;
				
			ElsIf Object.Property(ListParameter.Parameter, ObjectAttributeValue) Then
				
				If PickProductsInDocuments.IsValuesList(ObjectAttributeValue) Then
					ObjectAttributeValue = PickProductsInDocuments.ValueListIntoArray(ObjectAttributeValue);
				EndIf;
				
				DynamicList.Parameters.SetParameterValue(ListParameter.Parameter, ObjectAttributeValue);
				
			EndIf;
			
		EndDo;
	EndDo;
	
EndProcedure

&AtServer
Procedure SetFormItemsProperties()
	
	PickProductsInDocuments.SetChoiceParameters(Items.ShoppingCartProducts, Object.ProductsType);
	
	CommonUseClientServer.SetFormItemProperty(Items, "FormCommandsSettingsRequestQuantity", "Check", SelectionSettingsCache.RequestQuantity);
	CommonUseClientServer.SetFormItemProperty(Items, "FormCommandsSettingsRequestPrice", "Check", SelectionSettingsCache.RequestPrice);
	
	CommonUseClientServer.SetFormItemProperty(Items, "ShoppingCart", "Visible", SelectionSettingsCache.ShowCart);
	
	UseSeveralUnitsForProduct = GetFunctionalOption("UseSeveralUnitsForProduct");
	CommonUseClientServer.SetFormItemProperty(Items, "ListInventoryMeasurementUnit", "Visible", UseSeveralUnitsForProduct);
	CommonUseClientServer.SetFormItemProperty(Items, "ListCharacteristicsMeasurementUnit", "Visible", UseSeveralUnitsForProduct);
	CommonUseClientServer.SetFormItemProperty(Items, "ShoppingCartMeasurementUnit", "Visible", UseSeveralUnitsForProduct);
	
	PriceKindIsFilled = ValueIsFilled(Object.PriceKind);
	CommonUseClientServer.SetFormItemProperty(Items, "ProductsListContextMenuChangePrice", "Enabled", PriceKindIsFilled);
	CommonUseClientServer.SetFormItemProperty(Items, "ListCharacteristicsContextMenuPriceSetNew", "Enabled", PriceKindIsFilled);
	
	DiscountMarkupPercentVisible = SelectionSettingsCache.DiscountsMarkupsVisible Or SelectionSettingsCache.DiscountCardVisible;
	CommonUseClientServer.SetFormItemProperty(Items, "ShoppingCartDiscountMarkupPercent", "Visible", DiscountMarkupPercentVisible);
	
	AllowedToChangeAmount = SelectionSettingsCache.AllowedToChangeAmount;
	CommonUseClientServer.SetFormItemProperty(Items, "ShoppingCartPrice", "Enabled", AllowedToChangeAmount);
	CommonUseClientServer.SetFormItemProperty(Items, "ShoppingCartAmount", "Enabled", AllowedToChangeAmount);
	CommonUseClientServer.SetFormItemProperty(Items, "ShoppingCartVATAmount", "Enabled", AllowedToChangeAmount);
	CommonUseClientServer.SetFormItemProperty(Items, "ShoppingCartTotal", "Enabled", AllowedToChangeAmount);
	CommonUseClientServer.SetFormItemProperty(Items, "ProductsListContextMenuChangePrice", "Enabled", AllowedToChangeAmount);
	CommonUseClientServer.SetFormItemProperty(Items, "ListCharacteristicsContextMenuPriceSetNew", "Enabled", AllowedToChangeAmount);
	
	ReservationEnabled = GetFunctionalOption("UseInventoryReservation");
	CommonUseClientServer.SetFormItemProperty(Items, "ListInventoryReserve", "Visible", ReservationEnabled);
	CommonUseClientServer.SetFormItemProperty(Items, "ListWarehouseBalancesReserve", "Visible", ReservationEnabled);
	CommonUseClientServer.SetFormItemProperty(Items, "ShoppingCartReserve", "Visible", ReservationEnabled);
	
	CommonUseClientServer.SetFormItemProperty(Items, "ShoppingCartBatch", "Visible", SelectionSettingsCache.ShowBatch);
	
	CommonUseClientServer.SetFormItemProperty(Items, "ShoppingCartGroupPrice", "Visible", SelectionSettingsCache.ShowPrice);
	CommonUseClientServer.SetFormItemProperty(Items, "ListInventoryPrice", "Visible", SelectionSettingsCache.ShowPrice);
	CommonUseClientServer.SetFormItemProperty(Items, "ListInventoryPriceGroup", "Visible", SelectionSettingsCache.ShowPrice);
	CommonUseClientServer.SetFormItemProperty(Items, "ListInventoryShowItemsWithPriceOnly", "Visible", SelectionSettingsCache.ShowPrice);
	CommonUseClientServer.SetFormItemProperty(Items, "ListCharacteristicsShowItemsWithPriceOnly", "Visible", SelectionSettingsCache.ShowPrice);
	CommonUseClientServer.SetFormItemProperty(Items, "ListCharacteristicsPrice", "Visible", SelectionSettingsCache.ShowPrice);
	CommonUseClientServer.SetFormItemProperty(Items, "ListBatchesShowItemsWithPriceOnly", "Visible", SelectionSettingsCache.ShowPrice);
	CommonUseClientServer.SetFormItemProperty(Items, "ListBatchesPrice", "Visible", SelectionSettingsCache.ShowPrice);
	
	CommonUseClientServer.SetFormItemProperty(Items, "ListInventoryStockStatusFilter", "Visible", SelectionSettingsCache.ShowAvailable);
	CommonUseClientServer.SetFormItemProperty(Items, "ListInventoryStockWarehouse", "Visible", SelectionSettingsCache.ShowAvailable);
	CommonUseClientServer.SetFormItemProperty(Items, "ListInventoryGroupAvailable", "Visible", SelectionSettingsCache.ShowAvailable);
	CommonUseClientServer.SetFormItemProperty(Items, "ListInventoryInStock", "Visible", SelectionSettingsCache.ShowAvailable);
	CommonUseClientServer.SetFormItemProperty(Items, "ListCharacteristicsStockStatusFilter", "Visible", SelectionSettingsCache.ShowAvailable);
	CommonUseClientServer.SetFormItemProperty(Items, "ListCharacteristicsStockWarehouse", "Visible", SelectionSettingsCache.ShowAvailable);
	CommonUseClientServer.SetFormItemProperty(Items, "ListCharacteristicsGroupAvailable", "Visible", SelectionSettingsCache.ShowAvailable);
	CommonUseClientServer.SetFormItemProperty(Items, "ListCharacteristicsInStock", "Visible", SelectionSettingsCache.ShowAvailable);
	CommonUseClientServer.SetFormItemProperty(Items, "ListBatchesStockStatusFilter", "Visible", SelectionSettingsCache.ShowAvailable);
	CommonUseClientServer.SetFormItemProperty(Items, "ListBatchesStockWarehouse", "Visible", SelectionSettingsCache.ShowAvailable);
	CommonUseClientServer.SetFormItemProperty(Items, "ListBatchesGroupAvailable", "Visible", SelectionSettingsCache.ShowAvailable);
	CommonUseClientServer.SetFormItemProperty(Items, "ListBatchesInStock", "Visible", SelectionSettingsCache.ShowAvailable);
	CommonUseClientServer.SetFormItemProperty(Items, "ShoppingCartReserve", "Visible", SelectionSettingsCache.ShowAvailable);
	
EndProcedure

#EndRegion

#Region FormCompletion

&AtClient
Procedure MoveToDocumentAndClose()
	FormIsClosing = True;
	Close(PutCartToTempStorage());
EndProcedure

&AtServer
Function PutCartToTempStorage() 
	
	CartAddressInStorage = PutToTempStorage(Object.ShoppingCart.Unload(), Object.OwnerFormUUID);
	Return New Structure("CartAddressInStorage, OwnerFormUUID", CartAddressInStorage, Object.OwnerFormUUID);
	
EndFunction

&AtClient
Procedure BeforeClosingQueryBoxHandler(QueryResult, AdditionalParameters) Export
	
	If QueryResult = DialogReturnCode.Yes Then
		MoveToDocumentAndClose();
	ElsIf QueryResult = DialogReturnCode.No Then
		FormIsClosing = True;
		Close();
	КонецЕсли;

EndProcedure

&AtServerNoContext
Procedure UserSettingsSaving(UserSettingsToBeSaved)
	For Each UserSetting In UserSettingsToBeSaved Do
		DriveServer.SetUserSetting(UserSetting.Value, UserSetting.Key);
	EndDo;
EndProcedure

#EndRegion

#Region FullTextAndContextSearch

&AtServer
Procedure EnableFulltextSearchOnOpenSelection()
	
	// temporarily disabled
	UseFullTextSearch = False;
	
	If UseFullTextSearch Then
		
		RelevancyFullTextSearchIndex = FullTextSearch.IndexTrue();
		
		If Not RelevancyFullTextSearchIndex Then
			
			If CommonUseReUse.DataSeparationEnabled()
				AND CommonUseReUse.CanUseSeparatedData() Then
				
				// in the separated IB, the index is considered recent within 2 days
				RelevancyFullTextSearchIndex = FullTextSearch.UpdateDate() >= (CurrentSessionDate()-(2*24*60*60));
				
			Else
				
				// in the unseparated IB, the index is considered recent within a day
				RelevancyFullTextSearchIndex = FullTextSearch.UpdateDate() >= (CurrentSessionDate() - (1*24*60*60));
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	SetSearchStringInputHintOnServer();
	
EndProcedure

&AtServer
Procedure SetSearchStringInputHintOnServer()
	
	FulltextSearchSetPartially = (UseFullTextSearch AND Not RelevancyFullTextSearchIndex);
	
	InputHint = ?(FulltextSearchSetPartially,
		NStr("en = 'Update the full-text search index...'"),
		NStr("en = '(ALT+1) Enter search text ...'"));
		
	Items.ListInventorySearchText.InputHint = InputHint;
	Items.ListCharacteristicsSearchText.InputHint = InputHint;
	Items.ListBatchesSearchText.InputHint = InputHint;
	
EndProcedure

&AtClient
Procedure SearchAndSetFilter(Text)
	
	If UseFullTextSearch Then
		FulltextSearchOnClient(Text);
	Else
		ContextSearchOnClient(Text);
	EndIf;
	
EndProcedure

&AtClient
Procedure FulltextSearchOnClient(Text)
	
	If IsBlankString(Text) Then
		
		DriveClient.DeleteListFilterItem(ListInventory, "ProductsRef");
		DriveClient.DeleteListFilterItem(ListCharacteristics, "CharacteristicRef");
		
	Else
		
		SearchResult = Undefined;
		ErrorDescription = FullTextSearchOnServerWithoutContext(Text, SearchResult);
		
		If IsBlankString(ErrorDescription) Then
			
			// Products
			Use = SearchResult.Products.Count() > 0;
			
			ItemArray = CommonUseClientServer.FindFilterItemsAndGroups(
				ListInventory.SettingsComposer.FixedSettings.Filter,
				"ProductsRef");
				
			If ItemArray.Count() = 0 Then
				CommonUseClientServer.AddCompositionItem(
					ListInventory.SettingsComposer.FixedSettings.Filter,
					"ProductsRef",
					DataCompositionComparisonType.InList,
					SearchResult.Products,
					,
					Use);
			Else
				CommonUseClientServer.ChangeFilterItems(
					ListInventory.SettingsComposer.FixedSettings.Filter,
					"ProductsRef",
					,
					SearchResult.Products,
					DataCompositionComparisonType.InList,
					Use);
			EndIf;
			
			// Characteristics
			Use = SearchResult.ProductsCharacteristics.Count() > 0;
			
			CharacteristicItemsArray = CommonUseClientServer.FindFilterItemsAndGroups(
				ListCharacteristics.SettingsComposer.FixedSettings.Filter,
				"CharacteristicRef");
				
			If CharacteristicItemsArray.Count() = 0 Then
				CommonUseClientServer.AddCompositionItem(
					ListCharacteristics.SettingsComposer.FixedSettings.Filter,
					"CharacteristicRef",
					DataCompositionComparisonType.InList,
					SearchResult.ProductsCharacteristics,
					,
					Use);
			Else
				CommonUseClientServer.ChangeFilterItems(
					ListCharacteristics.SettingsComposer.FixedSettings.Filter,
					"CharacteristicRef",
					,
					SearchResult.ProductsCharacteristics,
					DataCompositionComparisonType.InList,
					Use);
			EndIf;
			
		Else
			
			ShowMessageBox(Undefined,
				ErrorDescription,
				5,
				NStr("en = 'Search...'"));
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Function FullTextSearchOnServerWithoutContext(SearchString, SearchResult)
	
	ErrorDescription = "";
	SearchResult = PickProductsInDocumentsOverridable.SearchGoods(SearchString, ErrorDescription);
	
	Return ErrorDescription;
	
EndFunction

&AtClient
Procedure ContextSearchOnClient(Text)
	
	If Items.PagesProductsCharacteristics.CurrentPage = Items.PageProducts Then
		
		FieldsArray = New Array;
		FieldsArray.Add("ProductsRef.Description");
		FieldsArray.Add("ProductsRef.DescriptionFull");
		FieldsArray.Add("ProductsRef.SKU");
		FieldsArray.Add("ProductsCategory.Description");
		FieldsArray.Add("PriceGroup.Description");
		
		ContextSearchFilterSetting(ListInventory, FieldsArray, Text);
		
	ElsIf Items.PagesProductsCharacteristics.CurrentPage = Items.PageCharacteristics Then
		
		FieldsArray = New Array;
		FieldsArray.Add("CharacteristicRef.Description");
		
		ContextSearchFilterSetting(ListCharacteristics, FieldsArray, Text);
		
	ElsIf Items.PagesProductsCharacteristics.CurrentPage = Items.PageBatches Then
		
		FieldsArray = New Array;
		FieldsArray.Add("BatchRef.Description");
		
		ContextSearchFilterSetting(ListBatches, FieldsArray, Text);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ContextSearchFilterSetting(ListAttribute, FieldsArray, SearchText)
	
	FieldsGroupPresentation = "Context search";
	
	If IsBlankString(SearchText) Then
		
		CommonUseClientServer.DeleteGroupsSelectionDynamicListItems(
			ListAttribute,
			,
			FieldsGroupPresentation);
		
	Else
		
		ItemArray = CommonUseClientServer.FindFilterItemsAndGroups(
			ListAttribute.SettingsComposer.FixedSettings.Filter,
			,
			FieldsGroupPresentation);
			
		If ItemArray.Count() = 0 Then
			
			FilterGroup = CommonUseClientServer.CreateGroupOfFilterItems(
				ListAttribute.SettingsComposer.FixedSettings.Filter.Items,
				FieldsGroupPresentation,
				DataCompositionFilterItemsGroupType.OrGroup);
			
			For Each FilterField In FieldsArray Do
				CommonUseClientServer.AddCompositionItem(
					FilterGroup,
					FilterField,
					DataCompositionComparisonType.Contains,
					SearchText,
					,
					True);
			EndDo;
			
		Else
			
			For Each FilterField In FieldsArray Do
				CommonUseClientServer.ChangeFilterItems(
					ItemArray[0],
					FilterField,
					,
					SearchText,
					DataCompositionComparisonType.Contains,
					True);
			EndDo;
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region CartAddingProductAndCalculations

&AtClient
Procedure AddProductsToCart()
	
	CurrentListCurrentDataArray = GetCurrentListCurrentDataArray();
	
	If CurrentListCurrentDataArray = Undefined Then
		Return;
	EndIf;
	
	IsOneRow = CurrentListCurrentDataArray.Count() = 1;
	
	For Each CurrentListCurrentData In CurrentListCurrentDataArray Do
		
		CartRowData = New Structure;
		
		CartRowData.Insert("Products", CurrentListCurrentData.ProductsRef);
		CartRowData.Insert("Characteristic", CurrentListCurrentData.CharacteristicRef);
		CartRowData.Insert("Batch", CurrentListCurrentData.BatchRef);
		CartRowData.Insert("MeasurementUnit", CurrentListCurrentData.MeasurementUnit);
		CartRowData.Insert("Factor", CurrentListCurrentData.Factor);
		CartRowData.Insert("VATRate", GetVATRate(CurrentListCurrentData.VATRate));
		CartRowData.Insert("AvailableBasicUOM", CurrentListCurrentData.AvailableBasicUOM);
		
		CartRowData.Insert("Price", CalculateProductsPrice(CartRowData.VATRate, CurrentListCurrentData.Price));
		CartRowData.Price = DriveClientServer.RoundPrice(CartRowData.Price, Object.RoundingOrder, Object.RoundUp);
		
		CartRowData.Insert("DiscountMarkupPercent", SelectionSettingsCache.DiscountMarkupPercent + SelectionSettingsCache.DiscountPercentByDiscountCard);
		CartRowData.Insert("Quantity", 1);
		
		If (SelectionSettingsCache.RequestQuantity Or SelectionSettingsCache.RequestPrice) AND IsOneRow Then
			
			CartRowData.Insert("SelectionSettingsCache", SelectionSettingsCache);
			
			NotificationDescriptionOnCloseSelection = New NotifyDescription("AfterSelectionQuantityAndPrice", ThisObject, CartRowData);
			OpenForm("DataProcessor.ProductsSelection.Form.QuantityAndPrice",
				CartRowData, ThisObject, True, , ,NotificationDescriptionOnCloseSelection , FormWindowOpeningMode.LockOwnerWindow);
			
		Else
			
			AddProductsToCartCompletion(CartRowData);
			
			If Not SelectionSettingsCache.ShowCart Then
				ShowUserNotification(
					Nstr("en = 'Item added to cart'"),
					,
					StringFunctionsClientServer.SubstituteParametersInString("%1 %2 %3",
						CartRowData.Products,
						CartRowData.Characteristic,
						CartRowData.Batch));
			EndIf;
			
		EndIf;
	EndDo;
	
EndProcedure

&AtClient
Procedure AfterSelectionQuantityAndPrice(ClosingResult, CartRowData) Export
	
	If TypeOf(ClosingResult) = Type("Structure") Then
		
		CartRowData.Quantity = ClosingResult.Quantity;
		CartRowData.Price = ClosingResult.Price;
		CartRowData.MeasurementUnit = ClosingResult.MeasurementUnit;
		CartRowData.Factor = ClosingResult.Factor;
		
		AddProductsToCartCompletion(CartRowData);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure AddProductsToCartCompletion(CartRowData)
	
	FilterStructure = New Structure;
	FilterStructure.Insert("Products", CartRowData.Products);
	FilterStructure.Insert("Characteristic", CartRowData.Characteristic);
	FilterStructure.Insert("Batch", CartRowData.Batch);
	FilterStructure.Insert("MeasurementUnit", CartRowData.MeasurementUnit);
	FilterStructure.Insert("Price", CartRowData.Price);
	
	FoundRows = Object.ShoppingCart.FindRows(FilterStructure);
		
	If FoundRows.Count() = 0 Then
		
		CartRow = Object.ShoppingCart.Add();
		FillPropertyValues(CartRow, CartRowData);
		
	Else
		
		CartRow = FoundRows[0];
		CartRow.Quantity = CartRow.Quantity + CartRowData.Quantity;
		
	EndIf;
	
	If ReservationEnabled
		AND CartRow.Factor <> 0
		AND (ValueIsFilled(CartRow.Characteristic)
			Or Not CurrentProductUseCharacteristics)
		AND (ValueIsFilled(CartRow.Batch)
			Or Not CurrentProductUseBatches) Then
		
		AlreadyReservedBasicUOM = 0;
		
		FilterStructure = New Structure;
		FilterStructure.Insert("Products", CartRowData.Products);
		FilterStructure.Insert("Characteristic", CartRowData.Characteristic);
		FilterStructure.Insert("Batch", CartRowData.Batch);
		
		FoundRows = Object.ShoppingCart.FindRows(FilterStructure);
		
		For Each DifferentCartRow In FoundRows Do 
			
			If DifferentCartRow = CartRow Then
				Continue;
			EndIf;
			
			AlreadyReservedBasicUOM = AlreadyReservedBasicUOM + DifferentCartRow.Reserve * DifferentCartRow.Factor;
			
		EndDo;
		
		AvailableReserve = (CartRowData.AvailableBasicUOM - AlreadyReservedBasicUOM) / CartRow.Factor;
		
		CartRow.Reserve = Min(CartRow.Quantity, Max(AvailableReserve, 0));
		
	Else
		
		CartRow.Reserve = 0;
		
	EndIf;
	
	CalculateAmountInTabularSectionLine(CartRow);
	
	SetCartInfoLabelText();
	
EndProcedure

&AtServerNoContext
Procedure GetDataProductsOnChange(DataStructure)
	
	DataStructure.Insert("MeasurementUnit", DataStructure.Products.MeasurementUnit);
	DataStructure.Insert("Factor", 1);
	
	If ValueIsFilled(DataStructure.PriceKind) Then
		DataStructure.Insert("Price", DriveServer.GetProductsPriceByPriceKind(DataStructure));
	Else
		DataStructure.Insert("Price", 0);
	EndIf;
	
	DataStructure.Insert("VATRate", DataStructure.Products.VATRate);
	
EndProcedure

&AtServerNoContext
Procedure GetDataCharacteristicOnChange(DataStructure)
	
	If ValueIsFilled(DataStructure.PriceKind) Then
		DataStructure.Insert("Price", DriveServer.GetProductsPriceByPriceKind(DataStructure));
	Else
		DataStructure.Insert("Price", 0);
	EndIf;
	
EndProcedure

&AtClient
Procedure CalculateAmountInTabularSectionLine(StringCart)
	
	StringCart.Amount = StringCart.Quantity * StringCart.Price;
	
	If StringCart.DiscountMarkupPercent <> 0
		AND StringCart.Quantity <> 0 Then
		
		StringCart.Amount = StringCart.Amount * (1 - StringCart.DiscountMarkupPercent / 100);
		
	EndIf;
	
	CalculateVATSUM(StringCart);
	
	StringCart.Total = StringCart.Amount + ?(Object.AmountIncludesVAT, 0, StringCart.VATAmount);
	
EndProcedure

&AtClient
Procedure CalculateVATSUM(StringCart)
	
	VATRate = DriveReUse.GetVATRateValue(StringCart.VATRate);
	
	StringCart.VATAmount = ?(Object.AmountIncludesVAT, 
									StringCart.Amount - (StringCart.Amount) / ((VATRate + 100) / 100),
									StringCart.Amount * VATRate / 100);
	
EndProcedure

&AtClient
Function CalculateProductsPrice(VATRate, Price)
	
	PricesKindPriceIncludesVAT = SelectionSettingsCache.PricesKindPriceIncludesVAT;
	
	If Object.AmountIncludesVAT = PricesKindPriceIncludesVAT Then
		
		Return Price;
		
	ElsIf Object.AmountIncludesVAT > PricesKindPriceIncludesVAT Then
		
		VATRateValue = DriveReUse.GetVATRateValue(VATRate);
		Return Price * (100 + VATRateValue) / 100;
		
	Else
		
		VATRateValue = DriveReUse.GetVATRateValue(VATRate);
		Return Price * 100 / (100 + VATRateValue);
		
	EndIf;
	
EndFunction

&AtServerNoContext
Function GetUOMFactor(MeasurementUnit)
	
	Return CommonUse.ObjectAttributeValue(MeasurementUnit, "Factor");
	
EndFunction

&AtClient
Function GetVATRate(VATRate)
	
	If Object.VATTaxation = PredefinedValue("Enum.VATTaxationTypes.SubjectToVAT") Then
		
		If ValueIsFilled(VATRate) Then
			
			Return VATRate;
			
		Else
			
			Return GetCompanyVATRate(Object.Company);
		
		EndIf;
		
	Else
		
		If Object.VATTaxation = PredefinedValue("Enum.VATTaxationTypes.NotSubjectToVAT") Then
			
			Return PredefinedValue("Catalog.VATRates.Exempt");
			
		Else
			
			Return PredefinedValue("Catalog.VATRates.ZeroRate");
			
		EndIf;
		
	EndIf;
	
EndFunction

&AtServerNoContext
Function GetCompanyVATRate(Company)
	
	Return InformationRegisters.AccountingPolicy.GetDefaultVATRate(, Company);
	
EndFunction

#EndRegion

#Region ListsManagement

&AtClient
Procedure FilterBySubstituteGoods(Products)
	
	ListSubstituteGoods = New ValueList;
	GetSubstituteGoods(Products, ListSubstituteGoods);
	
	ItemArray = CommonUseClientServer.FindFilterItemsAndGroups(
		ListInventory.SettingsComposer.FixedSettings.Filter,
		"ProductsRef");
	
	If ItemArray.Count() = 0 Then
		CommonUseClientServer.AddCompositionItem(
			ListInventory.SettingsComposer.FixedSettings.Filter,
			"ProductsRef",
			DataCompositionComparisonType.InList,
			ListSubstituteGoods);
	Else
		CommonUseClientServer.ChangeFilterItems(
			ListInventory.SettingsComposer.FixedSettings.Filter,
			"ProductsRef",
			,
			ListSubstituteGoods,
			DataCompositionComparisonType.InList);
	EndIf;
	
EndProcedure

&AtServerNoContext
Procedure GetSubstituteGoods(Products, ListSubstituteGoods)
	
	ListSubstituteGoods.Clear();
	
	QueryText = "SELECT
	|	Analogs.Products AS Products,
	|	Analogs.Analog AS Analog,
	|	Analogs.Priority AS Priority,
	|	Analogs.Comment AS Comment
	|FROM
	|	InformationRegister.SubstituteGoods AS Analogs
	|WHERE
	|	Analogs.Products = &Products
	|
	|ORDER BY
	|	Analogs.Priority";
	
	Query = New Query(QueryText);
	Query.SetParameter("Products", Products);
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		ListSubstituteGoods.Add(Selection.Analog);
		
	EndDo;
	
	ListSubstituteGoods.Insert(0, Products);
	
EndProcedure

&AtClient
Procedure ShowInventoryList()
	
	CommonUseClientServer.SetFormItemProperty(Items, "ListProductsHierarchy", "Enabled", True);
	
	Items.ListProductsHierarchy.TextColor = New Color();
	
	Items.PagesProductsCharacteristics.CurrentPage = Items.PageProducts;
	SetCurrentFormItem(Items.ListInventory);
	
	AttachIdleHandler("SetListWarehouseBalancesFilters", 0.2, True);
	
EndProcedure

&AtClient
Procedure ShowCharacteristicsList()
	
	ItemArray = CommonUseClientServer.FindFilterItemsAndGroups(
		ListCharacteristics.SettingsComposer.FixedSettings.Filter, "Owner");
		
	If ItemArray.Count() = 0 Then
		CommonUseClientServer.AddCompositionItem(
			ListCharacteristics.SettingsComposer.FixedSettings.Filter,
			"Owner",
			DataCompositionComparisonType.Equal,
			CurrentProduct);
	Else
		CommonUseClientServer.ChangeFilterItems(
			ListCharacteristics.SettingsComposer.FixedSettings.Filter,
			"Owner",
			,
			CurrentProduct,
			DataCompositionComparisonType.Equal);
	EndIf;
	
	If Items.PagesProductsCharacteristics.CurrentPage = Items.PageProducts Then
		CommonUseClientServer.SetFormItemProperty(Items, "ListProductsHierarchy", "Enabled", False);
		Items.ListProductsHierarchy.TextColor = SelectionSettingsCache.InaccessibleDataColor;
	EndIf;
	
	Items.PagesProductsCharacteristics.CurrentPage = Items.PageCharacteristics;
	SetCurrentFormItem(Items.ListCharacteristics);
	
	AttachIdleHandler("SetListWarehouseBalancesFilters", 0.2, True);
	
EndProcedure

&AtClient
Procedure ShowBatchesList()
	
	ItemArray = CommonUseClientServer.FindFilterItemsAndGroups(
		ListBatches.SettingsComposer.FixedSettings.Filter,
		"Owner");
		
	If ItemArray.Count() = 0 Then
		CommonUseClientServer.AddCompositionItem(
			ListBatches.SettingsComposer.FixedSettings.Filter,
			"Owner",
			DataCompositionComparisonType.Equal,
			CurrentProduct);
	Else
		CommonUseClientServer.ChangeFilterItems(
		ListBatches.SettingsComposer.FixedSettings.Filter,
		"Owner",
		,
		CurrentProduct,
		DataCompositionComparisonType.Equal);
	EndIf;
	
	CommonUseClientServer.SetDynamicListParameter(ListBatches, "Characteristic", CurrentCharacteristic);
	
	If Items.PagesProductsCharacteristics.CurrentPage = Items.PageProducts Then
		
		CommonUseClientServer.SetFormItemProperty(Items, "ListProductsHierarchy", "Enabled", False);
		Items.ListProductsHierarchy.TextColor = SelectionSettingsCache.InaccessibleDataColor;
		
		CommonUseClientServer.SetFormItemProperty(Items, "ListBatchesBackToProducts", "Visible", False);
		
	Else
		
		CommonUseClientServer.SetFormItemProperty(Items, "ListBatchesBackToProducts", "Visible", True);
		
	EndIf;
	
	Items.PagesProductsCharacteristics.CurrentPage = Items.PageBatches;
	SetCurrentFormItem(Items.ListBatches);
	
	AttachIdleHandler("SetListWarehouseBalancesFilters", 0.2, True);
	
EndProcedure

&AtClient
Procedure SetListWarehouseBalancesFilters()
	
	FilterValueProduct = Undefined;
	FilterValueCharacteristic = Undefined;
	FilterValueBatch = Undefined;
	
	If Items.PagesProductsCharacteristics.CurrentPage = Items.PageProducts Then
		
		CurrentRowData = Items.ListInventory.CurrentData;
		If CurrentRowData <> Undefined Then
			FilterValueProduct = CurrentRowData.ProductsRef;
		EndIf;
		
		CommonUseClientServer.DeleteItemsOfFilterGroup(ListWarehouseBalances.Filter, "Characteristic");
		CommonUseClientServer.DeleteItemsOfFilterGroup(ListWarehouseBalances.Filter, "Batch");
		
	ElsIf Items.PagesProductsCharacteristics.CurrentPage = Items.PageCharacteristics Then
		
		FilterValueProduct = CurrentProduct;
		
		CurrentRowData = Items.ListCharacteristics.CurrentData;
		If CurrentRowData <> Undefined Then
			FilterValueCharacteristic = CurrentRowData.CharacteristicRef;
		EndIf;
		
		CommonUseClientServer.DeleteItemsOfFilterGroup(ListWarehouseBalances.Filter, "Batch");
		
	ElsIf Items.PagesProductsCharacteristics.CurrentPage = Items.PageBatches Then
		
		FilterValueProduct = CurrentProduct;
		FilterValueCharacteristic = CurrentCharacteristic;
		
		CurrentRowData = Items.ListBatches.CurrentData;
		If CurrentRowData <> Undefined Then
			FilterValueBatch = CurrentRowData.BatchRef;
		EndIf;
		
	Else
		Return;
	EndIf;
	
	FiltersProducts = CommonUseClientServer.FindFilterItemsAndGroups(
		ListWarehouseBalances.Filter, "Products");
		
	If FiltersProducts.Count() = 0 Then
		CommonUseClientServer.AddCompositionItem(
			ListWarehouseBalances.Filter,
			"Products",
			DataCompositionComparisonType.Equal,
			FilterValueProduct);
	Else
		CommonUseClientServer.ChangeFilterItems(
			ListWarehouseBalances.Filter,
			"Products",
			,
			FilterValueProduct,
			DataCompositionComparisonType.Equal);
	EndIf;
	
	If FilterValueCharacteristic <> Undefined Then
		
		FiltersCharacteristic = CommonUseClientServer.FindFilterItemsAndGroups(
			ListWarehouseBalances.Filter, "Characteristic");
			
		If FiltersCharacteristic.Count() = 0 Then
			CommonUseClientServer.AddCompositionItem(
				ListWarehouseBalances.Filter,
				"Characteristic",
				DataCompositionComparisonType.Equal,
				FilterValueCharacteristic);
		Else
			CommonUseClientServer.ChangeFilterItems(
				ListWarehouseBalances.Filter,
				"Characteristic",
				,
				FilterValueCharacteristic,
				DataCompositionComparisonType.Equal);
		EndIf;
		
	EndIf;
	
	If FilterValueBatch <> Undefined Then
		
		FiltersBatch = CommonUseClientServer.FindFilterItemsAndGroups(
			ListWarehouseBalances.Filter, "Batch");
			
		If FiltersBatch.Count() = 0 Then
			CommonUseClientServer.AddCompositionItem(
				ListWarehouseBalances.Filter,
				"Batch",
				DataCompositionComparisonType.Equal,
				FilterValueBatch);
		Else
			CommonUseClientServer.ChangeFilterItems(
				ListWarehouseBalances.Filter,
				"Batch",
				,
				FilterValueBatch,
				DataCompositionComparisonType.Equal);
		EndIf;
		
	EndIf;
	
	CommonUseClientServer.SetDynamicListParameter(
		ListWarehouseBalances,
		"Factor",
		?(CurrentRowData = Undefined
			Or CurrentRowData.Factor = 0,
			1,
			CurrentRowData.Factor));
	
EndProcedure

&AtClient
Procedure SetListInventoryParentFilter()
	
	SelectedGroups = Items.ListProductsHierarchy.SelectedRows;
	
	SelectedGroupsCount = SelectedGroups.Count();
	
	If SelectedGroupsCount = 0
		Or SelectedGroupsCount = 1
			AND Not ValueIsFilled(SelectedGroups[0]) Then
		
		CommonUseClientServer.DeleteGroupsSelectionDynamicListItems(ListInventory, "Parent");
		
	Else
		
		ItemArray = CommonUseClientServer.FindFilterItemsAndGroups(
			ListInventory.SettingsComposer.FixedSettings.Filter, "Parent");
			
		If ItemArray.Count() = 0 Then
			CommonUseClientServer.AddCompositionItem(
				ListInventory.SettingsComposer.FixedSettings.Filter,
				"Parent",
				DataCompositionComparisonType.InHierarchy,
				SelectedGroups);
		Else
			CommonUseClientServer.ChangeFilterItems(
				ListInventory.SettingsComposer.FixedSettings.Filter,
				"Parent",
				,
				SelectedGroups,
				DataCompositionComparisonType.InHierarchy);
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ListFiltersChangeHandler(FilterData, DataCompositionComparisonType)
	
	ListsArray = New Array;
	ListsArray.Add(ListInventory);
	ListsArray.Add(ListCharacteristics);
	ListsArray.Add(ListBatches);
	
	For Each CurrentList In ListsArray Do
		
		For Each FilterItem In FilterData Do
		
			If FilterItem.Value Then
				
				ItemArray = CommonUseClientServer.FindFilterItemsAndGroups(
					CurrentList.SettingsComposer.FixedSettings.Filter,
					FilterItem.Key);
				
				If ItemArray.Count() = 0 Then
					CommonUseClientServer.AddCompositionItem(
						CurrentList.SettingsComposer.FixedSettings.Filter,
						FilterItem.Key,
						DataCompositionComparisonType,
						0);
				Else
					CommonUseClientServer.ChangeFilterItems(
						CurrentList.SettingsComposer.FixedSettings.Filter,
						FilterItem.Key,
						,
						0,
						DataCompositionComparisonType);
				EndIf;
				
			Else
				
				CommonUseClientServer.DeleteGroupsSelectionDynamicListItems(CurrentList, FilterItem.Key);
				
			EndIf;
			
		EndDo;
		
	EndDo;
	
EndProcedure

#EndRegion

#Region CommonUse

&AtClient
Function GetCurrentListCurrentDataArray()
	
	CurrentListCurrentData = New Array;
	
	If Items.PagesProductsCharacteristics.CurrentPage = Items.PageProducts Then
		
		SelectedRows = Items.ListInventory.SelectedRows;
		For Each SelectedRow In SelectedRows Do
			CurrentListCurrentData.Add(Items.ListInventory.RowData(SelectedRow));
		EndDo;
		
	ElsIf Items.PagesProductsCharacteristics.CurrentPage = Items.PageCharacteristics Then
		
		SelectedRows = Items.ListCharacteristics.SelectedRows;
		For Each SelectedRow In SelectedRows Do
			CurrentListCurrentData.Add(Items.ListCharacteristics.RowData(SelectedRow));
		EndDo;
		
	ElsIf Items.PagesProductsCharacteristics.CurrentPage = Items.PageBatches Then
		
		SelectedRows = Items.ListBatches.SelectedRows;
		For Each SelectedRow In SelectedRows Do
			CurrentListCurrentData.Add(Items.ListBatches.RowData(SelectedRow));
		EndDo;
		
	EndIf;
	
	Return CurrentListCurrentData;
	
EndFunction

&AtClient
Function GetCurrentListCurrentData()
	
	CurrentListCurrentData = Undefined;
	
	If Items.PagesProductsCharacteristics.CurrentPage = Items.PageProducts Then
		
		CurrentListCurrentData = Items.ListInventory.CurrentData;
		
	ElsIf Items.PagesProductsCharacteristics.CurrentPage = Items.PageCharacteristics Then
		
		CurrentListCurrentData = Items.ListCharacteristics.CurrentData;
		
	ElsIf Items.PagesProductsCharacteristics.CurrentPage = Items.PageBatches Then
		
		CurrentListCurrentData = Items.ListBatches.CurrentData;
		
	EndIf;
	
	Return CurrentListCurrentData;
	
EndFunction

&AtClient
Procedure SetCurrentFormItem(Item)
	CurrentItem = Item;
EndProcedure

&AtClient
Procedure SetCartInfoLabelText()
	
	If Object.TotalAmount > 0 Then
		If SelectionSettingsCache.ShowPrice Then
		
			CartInfoLabelPattern  = 
				NStr("en = 'Cart items: %1
					|Total: %2 %3
					|Total items: %4
					|Grand total: %5 %6'");
			
			CartInfoLabel = StringFunctionsClientServer.SubstituteParametersInString(
				CartInfoLabelPattern,
				Format(Object.ShoppingCart.Count(), "NZ="),
				Format(Object.ShoppingCart.Total("Total"), "ND=15; NFD=2; NZ="),
				Object.DocumentCurrency,
				Format(Object.ShoppingCart.Count() + Object.TotalItems, "NZ="),
				Format(Object.ShoppingCart.Total("Total") + Object.TotalAmount, "ND=15; NFD=2; NZ="),
				Object.DocumentCurrency);
			
		Else
			
			CartInfoLabelPattern  = 
				NStr("en = 'Cart items: %1
					|Total items: %2'");
			
			CartInfoLabel = StringFunctionsClientServer.SubstituteParametersInString(
				CartInfoLabelPattern,
				Format(Object.ShoppingCart.Count(), "NZ="),
				Format(Object.ShoppingCart.Count() + Object.TotalItems, "NZ="));
			
		EndIf;
	Else
		If SelectionSettingsCache.ShowPrice Then
		
			CartInfoLabelPattern = 
				NStr("en = 'Cart items: %1
					|Total: %2 %3'");
		
			CartInfoLabel = StringFunctionsClientServer.SubstituteParametersInString(
				CartInfoLabelPattern,
				Format(Object.ShoppingCart.Count(), "NZ="),
				Format(Object.ShoppingCart.Total("Total"), "ND=15; NFD=2; NZ="),
				Object.DocumentCurrency);
		Else
			
			CartInfoLabelPattern = NStr("en = 'Cart items: %1'");
		
			CartInfoLabel = StringFunctionsClientServer.SubstituteParametersInString(
				CartInfoLabelPattern,
				Format(Object.ShoppingCart.Count(), "NZ="));
			
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure SetCartShowHideLabelText()
	
	If SelectionSettingsCache.ShowCart Then
		CartShowHideLabel = Nstr("en = 'Hide cart content'");
	Else
		CartShowHideLabel = Nstr("en = 'Show cart content'");
	EndIf;
	
EndProcedure

#EndRegion

#Region Other

&AtServerNoContext
Function GetPricesRecordKey(ParametersStructure)
	
	Return InformationRegisters.Prices.GetRecordKey(ParametersStructure);
	
EndFunction

&AtClient
Procedure UpdateListAfterPriceChange(ClosingResult, AdditionalParameters)
	
	If Items.PagesProductsCharacteristics.CurrentPage = Items.PageProducts Then
		
		Items.ListInventory.Refresh();
		
	Else
		
		Items.ListCharacteristics.Refresh();
		
	EndIf;
	
EndProcedure

#EndRegion

#EndRegion

#Region Initialize

FormIsClosing = False;

#EndRegion
