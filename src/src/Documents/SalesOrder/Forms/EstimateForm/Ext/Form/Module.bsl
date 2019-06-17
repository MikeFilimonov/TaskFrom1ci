
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	RefreshFormParameters();
	
	SetConditionalAppearance();
	
	DataStructure = GetFromTempStorage(Parameters.DataAddress);
	DataStructure.Property("ReadOnly",	ReadOnly);
	DataStructure.Property("Ref",		OrderRef); 
	
	FillPropertyValues(DataOrder, DataStructure.DataOrder);
	
	If NOT ValueIsFilled(DataOrder.EstimateCostPriceCalculationMethod) Then
		DataOrder.EstimateCostPriceCalculationMethod = Enums.EstimateCostPriceCalculationMethods.LatestPurchasePrice;
	ElsIf TypeOf(DataOrder.EstimateCostPriceCalculationMethod) = Type("CatalogRef.PriceTypes") Then
		PriceKind = DataOrder.EstimateCostPriceCalculationMethod;
		DataOrder.EstimateCostPriceCalculationMethod = Enums.EstimateCostPriceCalculationMethods.Prices;
	EndIf;
	
	If DataOrder.EstimateCostPriceCalculationMethod = Enums.EstimateCostPriceCalculationMethods.CounterpartiesPrices Then
		SupplierPriceTypes.LoadValues(DataStructure.PriceTypes);
	ElsIf DataOrder.EstimateCostPriceCalculationMethod = Enums.EstimateCostPriceCalculationMethods.Prices 
		AND DataStructure.PriceTypes.Count() > 0 Then
		
		PriceKind = DataStructure.PriceTypes[0];
		DataOrder.EstimateCostPriceCalculationMethod = PriceKind;
		
	EndIf;
	
	DataOrder.Inventory.Load(DataStructure.Inventory);
	DataOrder.Estimate.Load(DataStructure.Estimate);
	
	FillEstimatePriceTypes();
	StatusShowCost = SystemSettingsStorage.Load("SalesOrder", "ShowCost");
	ShowCost = (StatusShowCost = True OR StatusShowCost = Undefined);
	ShowCostServer();
	
	ReadTemplateData();
	FillProductsList();
	CurrentContentRow = -1;
	
	If NOT DataOrder.EstimateIsCalculated Then
		RefreshEstimateServer();
	Else
		RefreshActualData();
		EstimateOutput();
	EndIf;
	
	RefreshBillsOfMaterialsComments();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If NOT DataOrder.EstimateIsCalculated Then
		RecalculateFormulasByTemplate();
	EndIf; 
	
	DisplayComment();
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	 
	If ReadOnly AND Modified Then
		Modified = False;
	EndIf;
	
	If Modified Then
		Cancel = True;
		
		Notification = New NotifyDescription("BeforeCloseCompletion", ThisObject);
		ShowQueryBox(
			Notification, 
			NStr("en = 'Do you want to save the changes?'"), 
			QuestionDialogMode.YesNoCancel, , 
			DialogReturnCode.Yes, NStr("en = 'Profit estimation'"));
	EndIf;
		
EndProcedure

&AtClient
Procedure BeforeCloseCompletion(Answer, AdditionalParameters) Export
	
	If Answer = DialogReturnCode.Yes Then
		PutEstimateDataInStorage();
		ClosingStructure = New Structure;
		ClosingStructure.Insert("DataAddress", DataAddress); 
		
		Close(ClosingStructure);
	ElsIf Answer = DialogReturnCode.No Then
		Modified = False;
		
		Close();
	EndIf; 		
	
EndProcedure

#EndRegion 

#Region FormsItemEventHandlers

&AtClient
Procedure DiscountPercentOnChange(Item)
	
	Modified = True;
	
	If DiscountPercent > 100 Then
		DiscountPercent = 100;
	EndIf;
	
	For Each TabularSectionRow In DataOrder.Inventory Do
		TabularSectionRow.DiscountMarkupPercent = DiscountPercent;
		CalculateAmountInTabularSectionLine(TabularSectionRow);
	EndDo; 
	
	If CurrentContentRow < 0 Then
		RefreshAmountDiscountsOnForm();
	EndIf;
	
	CalculateAmountAndDiscountPercent(DataOrder.Inventory, DiscountAmount, DiscountPercent);
	RecalculateFormulasByTemplate();
	
EndProcedure

&AtClient
Procedure DiscountAmountOnChange(Item)
	
	Modified = True;
	DistributeAmountToDiscounts(DiscountAmount);
	CalculateAmountAndDiscountPercent(DataOrder.Inventory, DiscountAmount, DiscountPercent);
	RecalculateFormulasByTemplate();
	
EndProcedure

&AtClient
Procedure ProductsListOnChange(Item)
	
	If CurrentContentRow = -1 Then
		EstimateOutputClient();
	Else
		EstimateOutputClient(CurrentContentRow);
	EndIf; 
	
EndProcedure

&AtClient
Procedure EstimateCostPriceCalculationMethodOnChange(Item)
	
	Modified = True;
	EstimateCostPriceCalculationMethodOnChangeServer();
	
EndProcedure

&AtServer
Procedure EstimateCostPriceCalculationMethodOnChangeServer()
	
	SetVisibleAndEnabled();
	RefreshEstimateServer(False);
	
EndProcedure

&AtClient
Procedure EstimateCostPriceCalculationMethodChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	If SelectedValue = Undefined Then
		Return;
	EndIf;
	
	Items.EstimateCostPriceCalculationMethod.Tooltip = "";
	
	If SelectedValue = PredefinedValue("Enum.EstimateCostPriceCalculationMethods.CounterpartiesPrices") Then
		StandardProcessing = False;
		OpeningStructure = New Structure;
		OpeningStructure.Insert("ChoiceMode", True);
		OpeningStructure.Insert("CloseOnChoice", True);
		OpeningStructure.Insert("PriceTypes", SupplierPriceTypes.UnloadValues());
		OpenForm("Catalog.SupplierPriceTypes.Form.MultipleSelectionForm", OpeningStructure, Items.EstimateCostPriceCalculationMethod);
		
		Return;
		
	EndIf;
	
	If TypeOf(SelectedValue) = Type("CatalogRef.PriceTypes") Then
		PriceKind = SelectedValue;
	EndIf; 
	
	If TypeOf(SelectedValue) = Type("Array") Then
		StandardProcessing = False;
		Modified = True;
		SupplierPriceTypes.LoadValues(SelectedValue);
		DataOrder.EstimateCostPriceCalculationMethod = PredefinedValue("Enum.EstimateCostPriceCalculationMethods.CounterpartiesPrices");
		RefreshEstimateServer(False);
		ChoiceItem = Items.EstimateCostPriceCalculationMethod.ChoiceList.FindByValue(DataOrder.EstimateCostPriceCalculationMethod);
		
		If NOT ChoiceItem = Undefined Then
			ChoiceItem.Presentation = ItemPresentationSupplierPriceTypes(SupplierPriceTypes);
		EndIf;
		
	EndIf; 
	
EndProcedure

#Region FormTableItemsEventsHandlersEstimate

&AtClient
Procedure EstimateOnFormSelection(Item, SelectedRow, Field, StandardProcessing)
	
	TabularSectionRow = Item.CurrentData;
	
	If CurrentContentRow = -1
		AND TabularSectionRow.Source = PredefinedValue("Enum.EstimateRowsSources.InventoryItem")
		AND (Field = Items.EstimateOnFormProducts
			OR Field = Items.EstimateOnFormCharacteristic
			OR Field = Items.EstimateOnFormBatch) Then
			
		StringSupplies = StringByKey(DataOrder.Inventory, TabularSectionRow.ConnectionKey);
		
		If StringSupplies = Undefined Then
			Return;
		EndIf;
		
		ID = StringSupplies.GetID();
		
		If Items.CurrentContentRow.ChoiceList.FindByValue(ID) = Undefined Then
			Return;
		EndIf;
		
		StandardProcessing = False;
		CurrentContentRow = ID;
		EstimateOutputClient(CurrentContentRow);
		
	EndIf; 	
	
EndProcedure

&AtClient
Procedure EstimateOnFormBeforeAddingBegin(Item, Cancel, Clone, Parent, Group, Parameter)
	
	If NOT Clone Then
		Cancel = True;	
		StartAddingProducts();
	EndIf;
	
	TabularSectionRow = Item.CurrentData;
	If Clone AND TabularSectionRow.Source = PredefinedValue("Enum.EstimateRowsSources.InventoryItem") Then
		Cancel = True;	
	EndIf; 
	
EndProcedure

&AtClient
Procedure EstimateOnFormChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	If TypeOf(SelectedValue) = Type("CatalogRef.Products") Then
		TabularSectionRow = EstimateOnForm.Add();
		TabularSectionRow.Products = SelectedValue;
		TabularSectionRow.Quantity = 1;
		FactsStructure = HeaderDataStructure();
		FactsStructure.Insert("Products", TabularSectionRow.Products);
		FactsStructure.Insert("Characteristic", PredefinedValue("Catalog.ProductsCharacteristics.EmptyRef"));
		
		FactsStructure = ReceiveDataProductsOnChange(FactsStructure);
		
		FillPropertyValues(TabularSectionRow, FactsStructure, "Characteristic, Specification, MeasurementUnit, ReplenishmentMethod, ProductsType, UseCharacteristics, UseBatches");
		TabularSectionRow.UnitCost = FactsStructure.UnitCost;
		RecalculateCost(TabularSectionRow);
		MakeChangesToEstimate();
		RecalculateFormulasByTemplate();
		
		If FactsStructure.UseCharacteristics Then
			TableItem = Items.EstimateOnFormCharacteristic;
		ElsIf FactsStructure.UseBatches Then
			TableItem = Items.EstimateOnFormBatch;
		ElsIf FactsStructure.ReplenishmentMethod=PredefinedValue("Enum.InventoryReplenishmentMethods.Production") Then
			TableItem = Items.EstimateOnFormSpecification;
		Else
			TableItem = Items.EstimateOnFormQuantity;
		EndIf;
		
	ElsIf TypeOf(SelectedValue) = Type("ChartOfAccountsRef.PrimaryChartOfAccounts") Then 
		TabularSectionRow = EstimateOnForm.Add();
		TabularSectionRow.Products = SelectedValue;
		MakeChangesToEstimate();
		TableItem = Items.EstimateOnFormCost;
	Else
		
		Return;
		
	EndIf;
	
	TabularSectionRow.Source = PredefinedValue("Enum.EstimateRowsSources.Others");
	
	Items.EstimateOnForm.CurrentRow = TabularSectionRow.GetID();
	Items.EstimateOnForm.CurrentItem = TableItem;
	Items.EstimateOnForm.ChangeRow();
	
	RefreshRowsNumbers(EstimateOnForm);
	
EndProcedure

&AtClient
Procedure EstimateOnFormOnStartEdit(Item, NewRow, Clone)
	
	TabularSectionRow = Item.CurrentData;
	If NewRow Then
		TabularSectionRow.ConnectionKey = 0;
		TabularSectionRow.Source = PredefinedValue("Enum.EstimateRowsSources.Others");
		TabularSectionRow.ManualEdit = True;
		
		If NOT Clone Then
			
			If CurrentContentRow = -1 AND TypeOf(TabularSectionRow.Products) <> Type("ChartOfAccountsRef.PrimaryChartOfAccounts") Then
				TabularSectionRow.Products = PredefinedValue("ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef");
			ElsIf CurrentContentRow >= 0 AND TypeOf(TabularSectionRow.Products) <> Type("CatalogRef.Products") Then 
				TabularSectionRow.Products = PredefinedValue("Catalog.Products.EmptyRef");
			EndIf;
			
		EndIf;
		
		RefreshRowsNumbers(EstimateOnForm);
	EndIf; 
	
EndProcedure

&AtClient
Procedure EstimateOnFormOnEditEnd(Item, NewRow, CancelEdit)
	
	If CancelEdit Then
		Return;
	EndIf;
	
	TabularSectionRow = Item.CurrentData;
	TabularSectionRow.ManualEdit = True;
	TabularSectionRow.DontSave = False;
	MakeChangesToEstimate();
	RecalculateFormulasByTemplate();
	Modified = True;
	
EndProcedure

&AtClient
Procedure EstimateOnFormAfterDeleteRow(Item)
	
	MakeChangesToEstimate();
	RecalculateFormulasByTemplate();
	Modified = True;
	RefreshRowsNumbers(EstimateOnForm);
	
EndProcedure

&AtClient
Procedure EstimateOnFormProductsClear(Item, StandardProcessing)
	
	StandardProcessing = False;
	TabularSectionRow = Items.EstimateOnForm.CurrentData;
	
	If CurrentContentRow = -1 Then
		TabularSectionRow.Products = PredefinedValue("ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef");
	Else 
		TabularSectionRow.Products = PredefinedValue("Catalog.Products.EmptyRef");
	EndIf;
	
	TabularSectionRow.Cost = 0;
	TabularSectionRow.UnitCost = 0;
	TabularSectionRow.Profit = TabularSectionRow.Amount;
	
EndProcedure

&AtClient
Procedure EstimateOnFormProductsOnChange(Item)
	
	TabularSectionRow = Items.EstimateOnForm.CurrentData;
	
	If TabularSectionRow = Undefined Then
		Return;
	EndIf;
	
	If TypeOf(TabularSectionRow.Products) <> Type("CatalogRef.Products") Then
		Return;
	EndIf; 
	
	FactsStructure = HeaderDataStructure();
	FactsStructure.Insert("Products", TabularSectionRow.Products);
	FactsStructure.Insert("Characteristic", PredefinedValue("Catalog.ProductsCharacteristics.EmptyRef"));
	
	FactsStructure = ReceiveDataProductsOnChange(FactsStructure);
	
	FillPropertyValues(TabularSectionRow, FactsStructure, "Characteristic, Specification, MeasurementUnit, ReplenishmentMethod, ProductsType, UseCharacteristics, UseBatches");
	TabularSectionRow.UnitCost = FactsStructure.UnitCost;
	RecalculateCost(TabularSectionRow);
	
EndProcedure

&AtClient
Procedure EstimateOnFormCharacteristicOnChange(Item)
	
	TabularSectionRow = Items.EstimateOnForm.CurrentData;
	
	If TabularSectionRow = Undefined Then
		Return;
	EndIf;
	
	FactsStructure = HeaderDataStructure();
	FactsStructure.Insert("Products", TabularSectionRow.Products);
	FactsStructure.Insert("Characteristic", TabularSectionRow.Characteristic);
	FactsStructure.Insert("MeasurementUnit", TabularSectionRow.MeasurementUnit);
	
	FactsStructure = ReceiveDataProductsOnChange(FactsStructure);
	
	TabularSectionRow.Specification = FactsStructure.Specification;
	TabularSectionRow.UnitCost = FactsStructure.UnitCost;
	RecalculateCost(TabularSectionRow);
	
EndProcedure

&AtClient
Procedure EstimateOnFormSpecificationOnChange(Item)
	
	TabularSectionRow = Items.EstimateOnForm.CurrentData;
	
	If TabularSectionRow = Undefined Then
		Return;
	EndIf;
	
	ReplaceSpecification(TabularSectionRow.GetID());
	
	StringComment = StringByKey(BillsOfMaterialsComments, TabularSectionRow.ConnectionKey);
	
	If StringComment <> Undefined Then
		BillsOfMaterialsComments.Delete(StringComment);
	EndIf; 
	
EndProcedure

&AtClient
Procedure EstimateOnFormMeasurementUnitOnChange(Item)
	
	TabularSectionRow = Items.EstimateOnForm.CurrentData;
	
	If TabularSectionRow = Undefined Then
		Return;
	EndIf;
	
	FactsStructure = HeaderDataStructure();
	FactsStructure.Insert("Products", TabularSectionRow.Products);
	FactsStructure.Insert("Characteristic", TabularSectionRow.Characteristic);
	FactsStructure.Insert("Specification", TabularSectionRow.Specification);
	FactsStructure.Insert("MeasurementUnit", TabularSectionRow.MeasurementUnit);
	
	FactsStructure = ReceiveDataProductsOnChange(FactsStructure);
	
	TabularSectionRow.UnitCost = FactsStructure.UnitCost;
	RecalculateCost(TabularSectionRow);
	
EndProcedure

&AtClient
Procedure EstimateOnFormQuantityOnChange(Item)
	
	TabularSectionRow = Items.EstimateOnForm.CurrentData;
	
	If TabularSectionRow = Undefined Then
		Return;
	EndIf;
	
	RecalculateCost(TabularSectionRow);
	
EndProcedure

&AtClient
Procedure EstimateOnFormCostOnChange(Item)
	
	TabularSectionRow = Items.EstimateOnForm.CurrentData;
	
	If TabularSectionRow = Undefined Then
		Return;
	EndIf;
	
	TabularSectionRow.Profit = TabularSectionRow.Amount-TabularSectionRow.Cost;
	
	If TypeOf(TabularSectionRow.Products) = Type("CatalogRef.Products") Then
		
		If TabularSectionRow.Quantity = 0 Then
			TabularSectionRow.Quantity = 1;
		EndIf;
		
		TabularSectionRow.UnitCost = TabularSectionRow.Cost/TabularSectionRow.Quantity;
	EndIf;
	
EndProcedure

&AtClient
Procedure EstimateOnFormDiscountMarkupPercentOnChange(Item)
	
	TabularSectionRow = Items.EstimateOnForm.CurrentData;
	
	If TabularSectionRow = Undefined Then
		Return;
	EndIf;
	
	RefreshInventoriesDiscount(TabularSectionRow);
	CalculateAmountAndDiscountPercent(DataOrder.Inventory, DiscountAmount, DiscountPercent);

EndProcedure

&AtClient
Procedure EstimateOnFormBeforeDelete(Item, Cancel)
	
	TabularSectionRow = Item.CurrentData;
	
	If TabularSectionRow.Source = PredefinedValue("Enum.EstimateRowsSources.InventoryItem")
		OR TabularSectionRow.Source = PredefinedValue("Enum.EstimateRowsSources.Delivery") Then
			Cancel = True;
	EndIf; 
	
EndProcedure

#EndRegion 

&AtClient
Procedure CommentOnChange(Item)
	
	OnChangeComment();
	
EndProcedure

&AtClient
Procedure CommentStartChoice(Item, ChoiceData, StandardProcessing)
	
	Notification = New NotifyDescription("CommentEndEntering", ThisObject);
	CommonUseClient.ShowMultilineTextEditForm(Notification, Items.Comment.EditText, NStr("en = 'Comment'"));
	
EndProcedure

#EndRegion 

#Region FormCommandHandlers

&AtClient
Procedure RepresentationEstimateCost(Command)
	
	ShowCost = NOT ShowCost;
	RepresentationEstimateCostServer();
	
EndProcedure

&AtServer
Procedure RepresentationEstimateCostServer()
	
	ShowCostServer();
	
	If CurrentContentRow < 0 Then
		EstimateOutput();
	Else
		EstimateOutput(CurrentContentRow);
	EndIf; 
	
EndProcedure

&AtClient
Procedure AddProducts(Command)
	
	StartAddingProducts();	
	
EndProcedure

&AtClient
Procedure StartAddingProducts()
	
	OpenParameters = New Structure;
	OpenParameters.Insert("ChoiceMode", True);
	
	FilterStructure = New Structure;
	ProductsType = New ValueList;
	
	For Each ArrayElement In Items.EstimateOnFormProducts.ChoiceParameters Do
		
		If ArrayElement.Name = "Filter.ProductsType" Then
			
			If TypeOf(ArrayElement.Value) = Type("FixedArray") Then
				
				For Each FixArrayItem In ArrayElement.Value Do
					ProductsType.Add(FixArrayItem);
				EndDo;
				
			Else
				ProductsType.Add(ArrayElement.Value);
			EndIf;
			
		EndIf;
		
	EndDo;
	FilterStructure.Insert("ProductsType", ProductsType);
	FilterStructure.Insert("IsSet", False);
	
	OpenParameters.Insert("Filter", FilterStructure);
	OpenForm("Catalog.Products.ChoiceForm", OpenParameters, Items.EstimateOnForm,,,,, FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtClient
Procedure AddExpense(Command)
	
	OpenParameters = New Structure;
	OpenParameters.Insert("ChoiceMode", True);
	FilterStructure = New Structure;
	GLAccountsTypes = New Array;
	GLAccountsTypes.Add(PredefinedValue("Enum.GLAccountsTypes.Expenses"));
	GLAccountsTypes.Add(PredefinedValue("Enum.GLAccountsTypes.OtherExpenses"));
	GLAccountsTypes.Add(PredefinedValue("Enum.GLAccountsTypes.WorkInProcess"));
	FilterStructure.Insert("TypeOfAccount", New FixedArray(GLAccountsTypes));
	OpenParameters.Insert("Filter", FilterStructure);
	OpenForm("ChartOfAccounts.PrimaryChartOfAccounts.ChoiceForm", OpenParameters, Items.EstimateOnForm,,,,, FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtClient
Procedure RefreshEstimate(Command)
	
	Modified = True;
	RefreshEstimateServer();
	
EndProcedure

&AtClient
Procedure WriteAndClose(Command)
	
	If ReadOnly Then
		Modified = False;
		Close();
	Else
		PutEstimateDataInStorage();
		ClosingStructure = New Structure;
		ClosingStructure.Insert("DataAddress", DataAddress); 
		Close(ClosingStructure);
	EndIf; 
	
EndProcedure

&AtClient
Procedure FillByTemplate(Command)
	
	Notification = New NotifyDescription("FillByTemplateEnd", ThisObject);
	OpenParameters = New Structure;
	
	If ValueIsFilled(DataOrder.EstimateTemplate) Then
		OpenParameters.Insert("CurrentRow", DataOrder.EstimateTemplate);
	EndIf;
	
	OpenForm("Catalog.EstimatesTemplates.ChoiceForm", OpenParameters, ThisObject, , , , Notification, FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtClient
Procedure FillByTemplateEnd(Template, AdditionalParameters) Export
	
	If ValueIsFilled(Template) Then
		DataOrder.EstimateTemplate = Template;
		FillByTemplateEndServer();
		Modified = True;
	EndIf; 	
	
EndProcedure

&AtServer
Procedure FillByTemplateEndServer()
	
	ChangeEstimateProhibited = False;
	FillByTemplateServer();
	
	If CurrentContentRow < 0 Then
		EstimateOutput();
	Else
		EstimateOutput(CurrentContentRow);
	EndIf; 
	
EndProcedure
 
&AtClient
Procedure Print(Command)
	
	ClosingStructure = New Structure;
	
	If NOT ReadOnly AND (Modified OR NOT DataOrder.EstimateIsCalculated) Then
		PutEstimateDataInStorage();
		ClosingStructure.Insert("DataAddress", DataAddress); 
	EndIf;
	
	ClosingStructure.Insert("Print", True);
	FormOwner.OnChangeEstimate(ClosingStructure, Undefined);
	
EndProcedure

&AtClient
Procedure GoToBackOrderEstimate(Command)
	
	CurrentContentRow = -1;
	EstimateOutputClient();
	
EndProcedure

&AtClient
Procedure OpenProductsCard(Command)
	
	TabularSectionRow = Items.EstimateOnForm.CurrentData;
	
	If TabularSectionRow = Undefined Then
		Return;
	EndIf;
	
	If ValueIsFilled(TabularSectionRow.Products) Then
		ShowValue(, TabularSectionRow.Products);
	EndIf; 
	
EndProcedure

#EndRegion 

#Region InternalProceduresAndFunctions

&AtServer
Procedure RefreshFormParameters()
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("FullRightsAvailable", IsInRole(Metadata.Roles.FullRights));
	ParametersStructure.Insert("UseCharacteristics", GetFunctionalOption("UseCharacteristics"));
	ParametersStructure.Insert("UseBatches", GetFunctionalOption("UseBatches") AND FilledTPAttribute(DataOrder.Inventory, "Batch"));
	FormParameters = New FixedStructure(ParametersStructure);
	
EndProcedure

&AtServer
Procedure SetConditionalAppearance()
	
	// Conditional appearance of inventories
	
	NewConditionalAppearance = ConditionalAppearance.Items.Add();
	
	Appearance = NewConditionalAppearance.Appearance.Items.Find("ReadOnly");
	Appearance.Value = True;
	Appearance.Use = True;
	
	Filter = NewConditionalAppearance.Filter.Items.Add(Type("DataCompositionFilterItem"));
	Filter.ComparisonType = DataCompositionComparisonType.Equal;
	Filter.Use = True;
	Filter.LeftValue = New DataCompositionField("EstimateOnForm.ProductsType");
	Filter.RightValue = Enums.ProductsTypes.InventoryItem;
	
	Field = NewConditionalAppearance.Fields.Items.Add();
	Field.Use = True;
	Field.Field = New DataCompositionField("EstimateOnFormCost");
	
	NewConditionalAppearance = ConditionalAppearance.Items.Add();
	
	Appearance = NewConditionalAppearance.Appearance.Items.Find("ReadOnly");
	Appearance.Value = True;
	Appearance.Use = True;
	
	Filter = NewConditionalAppearance.Filter.Items.Add(Type("DataCompositionFilterItem"));
	Filter.ComparisonType = DataCompositionComparisonType.Equal;
	Filter.Use = True;
	Filter.LeftValue = New DataCompositionField("EstimateOnForm.UseCharacteristics");
	Filter.RightValue = False;
	
	Field = NewConditionalAppearance.Fields.Items.Add();
	Field.Use = True;
	Field.Field = New DataCompositionField("EstimateOnFormCharacteristic");
	
	NewConditionalAppearance = ConditionalAppearance.Items.Add();
	
	Appearance = NewConditionalAppearance.Appearance.Items.Find("ReadOnly");
	Appearance.Value = True;
	Appearance.Use = True;
	
	Filter = NewConditionalAppearance.Filter.Items.Add(Type("DataCompositionFilterItem"));
	Filter.ComparisonType = DataCompositionComparisonType.Equal;
	Filter.Use 	= True;
	Filter.LeftValue = New DataCompositionField("EstimateOnForm.UseBatches");
	Filter.RightValue = False;
	
	Field = NewConditionalAppearance.Fields.Items.Add();
	Field.Use = True;
	Field.Field = New DataCompositionField("EstimateOnFormBatch");
	
	NewConditionalAppearance = ConditionalAppearance.Items.Add();
	
	Appearance = NewConditionalAppearance.Appearance.Items.Find("ReadOnly");
	Appearance.Value = True;
	Appearance.Use = True;
	
	Filter = NewConditionalAppearance.Filter.Items.Add(Type("DataCompositionFilterItem"));
	Filter.ComparisonType = DataCompositionComparisonType.NotEqual;
	Filter.Use 	= True;
	Filter.LeftValue = New DataCompositionField("EstimateOnForm.ReplenishmentMethod");
	Filter.RightValue = Enums.InventoryReplenishmentMethods.Production;
	
	Field = NewConditionalAppearance.Fields.Items.Add();
	Field.Use = True;
	Field.Field = New DataCompositionField("EstimateOnFormSpecification");
	
	// Conditional appearance of services
	
	NewConditionalAppearance = ConditionalAppearance.Items.Add();
	
	Appearance = NewConditionalAppearance.Appearance.Items.Find("ReadOnly");
	Appearance.Value = True;
	Appearance.Use = True;
	
	Filter = NewConditionalAppearance.Filter.Items.Add(Type("DataCompositionFilterItem"));
	Filter.ComparisonType = DataCompositionComparisonType.Equal;
	Filter.Use = True;
	Filter.LeftValue = New DataCompositionField("EstimateOnForm.ProductsType");
	Filter.RightValue = Enums.ProductsTypes.Service;
	
	Field = NewConditionalAppearance.Fields.Items.Add();
	Field.Use = True;
	Field.Field = New DataCompositionField("EstimateOnFormSpecification");
	
	// Conditional appearance of costs
	
	NewConditionalAppearance = ConditionalAppearance.Items.Add();
	
	Appearance = NewConditionalAppearance.Appearance.Items.Find("ReadOnly");
	Appearance.Value = True;
	Appearance.Use = True;
	
	Filter = NewConditionalAppearance.Filter.Items.Add(Type("DataCompositionFilterItem"));
	Filter.ComparisonType = DataCompositionComparisonType.Equal;
	Filter.Use = True;
	Filter.LeftValue = New DataCompositionField("EstimateOnForm.ProductsType");
	Filter.RightValue = Enums.ProductsTypes.EmptyRef();
	
	Field = NewConditionalAppearance.Fields.Items.Add();
	Field.Use = True;
	Field.Field = New DataCompositionField("EstimateOnFormSpecification");
	Field = NewConditionalAppearance.Fields.Items.Add();
	Field.Use = True;
	Field.Field = New DataCompositionField("EstimateOnFormCharacteristic");
	Field = NewConditionalAppearance.Fields.Items.Add();
	Field.Use = True;
	Field.Field = New DataCompositionField("EstimateOnFormBatch");
	Field = NewConditionalAppearance.Fields.Items.Add();
	Field.Use = True;
	Field.Field = New DataCompositionField("EstimateOnFormQuantity");
	Field = NewConditionalAppearance.Fields.Items.Add();
	Field.Use = True;
	Field.Field = New DataCompositionField("EstimateOnFormMeasurementUnit");
	
	// Inventories rows
	
	NewConditionalAppearance = ConditionalAppearance.Items.Add();
	
	Appearance = NewConditionalAppearance.Appearance.Items.Find("ReadOnly");
	Appearance.Value = True;
	Appearance.Use = True;
	Appearance = NewConditionalAppearance.Appearance.Items.Find("TextColor");
	Appearance.Value = StyleColors.UnavailableTabularSectionTextColor;
	Appearance.Use = True;
	
	Filter = NewConditionalAppearance.Filter.Items.Add(Type("DataCompositionFilterItem"));
	Filter.ComparisonType = DataCompositionComparisonType.Equal;
	Filter.Use = True;
	Filter.LeftValue = New DataCompositionField("EstimateOnForm.Source");
	Filter.RightValue = Enums.EstimateRowsSources.InventoryItem;
	
	Field = NewConditionalAppearance.Fields.Items.Add();
	Field.Use = True;
	Field.Field = New DataCompositionField("EstimateOnFormProducts");
	Field = NewConditionalAppearance.Fields.Items.Add();
	Field.Use = True;
	Field.Field = New DataCompositionField("EstimateOnFormCharacteristic");
	Field = NewConditionalAppearance.Fields.Items.Add();
	Field.Use = True;
	Field.Field = New DataCompositionField("EstimateOnFormBatch");
	Field = NewConditionalAppearance.Fields.Items.Add();
	Field.Use = True;
	Field.Field = New DataCompositionField("EstimateOnFormQuantity");
	Field = NewConditionalAppearance.Fields.Items.Add();
	Field.Use = True;
	Field.Field = New DataCompositionField("EstimateOnFormMeasurementUnit");
	Field = NewConditionalAppearance.Fields.Items.Add();
	Field.Use = True;
	Field.Field = New DataCompositionField("EstimateOnFormAutomaticDiscountsPercent");
	Field = NewConditionalAppearance.Fields.Items.Add();
	Field.Use = True;
	Field.Field = New DataCompositionField("EstimateOnFormCost");
	Field = NewConditionalAppearance.Fields.Items.Add();
	Field.Use = True;
	Field.Field = New DataCompositionField("EstimateOnFormAmount");
	Field = NewConditionalAppearance.Fields.Items.Add();
	Field.Use = True;
	Field.Field = New DataCompositionField("EstimateOnFormProfit");
	Field = NewConditionalAppearance.Fields.Items.Add();
	Field.Use = True;
	Field.Field = New DataCompositionField("EstimateOnFormCostReal");
	Field = NewConditionalAppearance.Fields.Items.Add();
	Field.Use = True;
	Field.Field = New DataCompositionField("EstimateOnFormCostFact");
	Field = NewConditionalAppearance.Fields.Items.Add();
	Field.Use = True;
	Field.Field = New DataCompositionField("EstimateOnFormProfitFact");
	
	NewConditionalAppearance = ConditionalAppearance.Items.Add();
	
	Appearance = NewConditionalAppearance.Appearance.Items.Find("ReadOnly");
	Appearance.Value = True;
	Appearance.Use = True;
	
	Filter = NewConditionalAppearance.Filter.Items.Add(Type("DataCompositionFilterItem"));
	Filter.ComparisonType = DataCompositionComparisonType.NotEqual;
	Filter.Use = True;
	Filter.LeftValue = New DataCompositionField("EstimateOnForm.Source");
	Filter.RightValue = Enums.EstimateRowsSources.InventoryItem;
	
	Field = NewConditionalAppearance.Fields.Items.Add();
	Field.Use = True;
	Field.Field = New DataCompositionField("EstimateOnFormDiscountMarkupPercent");
	
	// Delivery strings
	
	NewConditionalAppearance = ConditionalAppearance.Items.Add();
	
	Appearance = NewConditionalAppearance.Appearance.Items.Find("ReadOnly");
	Appearance.Value = True;
	Appearance.Use = True;
	Appearance = NewConditionalAppearance.Appearance.Items.Find("TextColor");
	Appearance.Value = StyleColors.UnavailableTabularSectionTextColor;
	Appearance.Use = True;
	
	Filter = NewConditionalAppearance.Filter.Items.Add(Type("DataCompositionFilterItem"));
	Filter.ComparisonType = DataCompositionComparisonType.Equal;
	Filter.Use = True;
	Filter.LeftValue = New DataCompositionField("EstimateOnForm.Source");
	Filter.RightValue = Enums.EstimateRowsSources.Delivery;
	
	Field = NewConditionalAppearance.Fields.Items.Add();
	Field.Use = True;
	Field.Field = New DataCompositionField("EstimateOnFormProducts");
	Field = NewConditionalAppearance.Fields.Items.Add();
	Field.Use = True;
	Field.Field = New DataCompositionField("EstimateOnFormCharacteristic");
	Field = NewConditionalAppearance.Fields.Items.Add();
	Field.Use = True;
	Field.Field = New DataCompositionField("EstimateOnFormBatch");
	Field = NewConditionalAppearance.Fields.Items.Add();
	Field.Use = True;
	Field.Field = New DataCompositionField("EstimateOnFormQuantity");
	Field = NewConditionalAppearance.Fields.Items.Add();
	Field.Use = True;
	Field.Field = New DataCompositionField("EstimateOnFormMeasurementUnit");
	Field = NewConditionalAppearance.Fields.Items.Add();
	Field.Use = True;
	Field.Field = New DataCompositionField("EstimateOnFormAutomaticDiscountsPercent");
	Field = NewConditionalAppearance.Fields.Items.Add();
	Field.Use = True;
	
EndProcedure

&AtServer
Procedure SetVisibleAndEnabled()
	
	FullEstimateMode	= (CurrentContentRow < 0);
	HasActualData		= (ActualData.Count() > 0);
	
	Items.EstimateCostPriceCalculationMethod.Visible		= ShowCost;
	Items.EstimateOnFormCharacteristic.Visible				= FormParameters.UseCharacteristics;
	Items.EstimateOnFormBatch.Visible						= FullEstimateMode AND FormParameters.UseBatches;
	Items.EstimateOnFormCost.Visible						= ShowCost;
	Items.EstimateOnFormAmount.Visible						= FullEstimateMode;
	Items.EstimateOnFormDiscountMarkupPercent.Visible		= FullEstimateMode;
	Items.EstimateOnFormAutomaticDiscountsPercent.Visible	= FullEstimateMode;
	Items.EstimateOnFormProfit.Visible						= FullEstimateMode AND ShowCost;
	Items.EstimateOnFormAddExpense.Visible					= FullEstimateMode;
	Items.EstimateOnFormFillByTemplate.Visible				= FullEstimateMode;
	Items.EstimateOnFormCostReal.Visible					= FullEstimateMode AND HasActualData AND ShowCost;
	Items.EstimateOnFormProfitFact.Visible					= FullEstimateMode AND HasActualData AND ShowCost;
	Items.EstimateOnFormCostFact.Visible					= FullEstimateMode AND HasActualData;	
	Items.FooterGroupDiscounts.Visible						= FullEstimateMode;
	Items.DecorationHeaderCost.Visible						= ShowCost;
	Items.TotalPrimeCost.Visible							= ShowCost;
	Items.TotalPrimeCostReal.Visible						= ShowCost;
	Items.DecorationHeaderProfit.Visible					= ShowCost;
	Items.TotalProfit.Visible								= ShowCost;
	Items.TotalProfitReal.Visible							= ShowCost;
	
	Items.RepresentationEstimateCost.Picture = ?(ShowCost, PictureLib.VisibilityAllowed, PictureLib.VisibilityDenied);
	
	Items.EstimateOnForm.ReadOnly						= ChangeEstimateProhibited OR ReadOnly;
	Items.EstimateOnFormAddProducts.Enabled	= NOT ChangeEstimateProhibited AND NOT ReadOnly;
	Items.EstimateOnFormAddProducts.Title	= ?(CurrentContentRow < 0, 
		NStr("en = 'Add a product as cost'"), 
		NStr("en = 'Add'"));
	Items.EstimateOnFormAddExpense.Enabled				= NOT ChangeEstimateProhibited AND NOT ReadOnly;
	Items.EstimateOnFormPickup.Enabled					= NOT ChangeEstimateProhibited AND NOT ReadOnly;
	
	If Items.Find("EstimateOnFormDataImportFromExternalSource") <> Undefined Then
		Items.EstimateOnFormDataImportFromExternalSource.Enabled = NOT ChangeEstimateProhibited AND NOT ReadOnly;
	EndIf;
	
	Items.EstimateOnFormFillByTemplate.Enabled			= NOT ReadOnly;
	Items.EstimateOnForm.TextColor						= ?(ChangeEstimateProhibited AND NOT ReadOnly, 
		StyleColors.UnavailableTabularSectionTextColor, 
		New Color);
	Items.EstimateCostPriceCalculationMethod.Enabled	= NOT ReadOnly;
	Items.EstimateOnFormRefreshEstimate.Enabled			= NOT ReadOnly;
	Items.DiscountPercent.Enabled						= NOT ReadOnly;
	Items.DiscountAmount.Enabled						= NOT ReadOnly;
	Items.Comment.ReadOnly								= ReadOnly OR ChangeEstimateProhibited;
	Items.SaveChanges.Title								= ?(ReadOnly, 
		NStr("en = 'Close'"), 
		NStr("en = 'Save and close'"));
	
	Items.GoToBackOrderEstimate.Visible = (CurrentContentRow >= 0);
	
	Items.EstimateOnFormFillByTemplate.Title = ?(ValueIsFilled(DataOrder.EstimateTemplate),
		NStr("en = 'Use another template'"),
		NStr("en = 'Apply template'"));
	
	Items.TotalsGroupFact.Visible			= HasActualData;
	Items.DecorationFactTitle.Visible		= HasActualData;
	Items.DecorationDiscountsMargin.Visible	= HasActualData;
	
	// Products choice parameters
	TypeArray = New Array();
	TypeArray.Add(Enums.ProductsTypes.InventoryItem);
	TypeArray.Add(Enums.ProductsTypes.Service);
	TypeArray.Add(Enums.ProductsTypes.Operation);
	
	If CurrentContentRow < 0 Then
		TypeArray.Add(Enums.ProductsTypes.Work);
	EndIf;
	
	ParameterArray = New Array;
	ParameterArray.Add(New ChoiceParameter("Filter.ProductsType", New FixedArray(TypeArray)));
	ParameterArray.Add(New ChoiceParameter("Filter.IsSet", False));
	Items.EstimateOnFormProducts.ChoiceParameters = New FixedArray(ParameterArray);
	
EndProcedure
 
&AtServer
Procedure FillEstimatePriceTypes()
	
	Items.EstimateCostPriceCalculationMethod.ChoiceList.Clear();
	Items.EstimateCostPriceCalculationMethod.ChoiceList.Add(Enums.EstimateCostPriceCalculationMethods.LatestPurchasePrice, 
		NStr("en = 'Latest purchase price'"));
	
	If GetFunctionalOption("UseCounterpartiesPricesTracking") Then
		Items.EstimateCostPriceCalculationMethod.ChoiceList.Add(Enums.EstimateCostPriceCalculationMethods.CounterpartiesPrices, 
			ItemPresentationSupplierPriceTypes(SupplierPriceTypes));
	EndIf; 
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	PriceTypes.Ref,
	|	PriceTypes.Description AS Description
	|FROM
	|	Catalog.PriceTypes AS PriceTypes
	|WHERE
	|	NOT PriceTypes.DeletionMark
	|	AND NOT PriceTypes.CalculatesDynamically
	|
	|ORDER BY
	|	Description";
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		Items.EstimateCostPriceCalculationMethod.ChoiceList.Add(Selection.Ref, 
			StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Price list %1'"), 
				TrimAll(Selection.Description)));	
	EndDo; 
	
EndProcedure

&AtClientAtServerNoContext
Function ItemPresentationSupplierPriceTypes(SupplierPriceTypes)
	
	Result = NStr("en = 'Supplier''s price list'") + 
		?(SupplierPriceTypes.Count() = 0, "", " (" + String(SupplierPriceTypes) + ")");
	
	If StrLen(Result) > 60 Then
		Result = Left(Result, 58) + "...";
	EndIf;
	
	Return Result;
	
EndFunction

&AtServer
Procedure FillProductsList()
	
	Items.CurrentContentRow.ChoiceList.Clear();
	Items.CurrentContentRow.ChoiceList.Add(-1, NStr("en = 'Entire order'"));
	
	InventoryTable = New ValueTable;
	InventoryTable.Columns.Add("Products",	New TypeDescription("CatalogRef.Products"));
	InventoryTable.Columns.Add("Specification",			New TypeDescription("CatalogRef.BillsOfMaterials"));
	InventoryTable.Columns.Add("Presentation",			New TypeDescription("String", New StringQualifiers(0)));
	InventoryTable.Columns.Add("ID",					New TypeDescription("Number", New NumberQualifiers(10, 0)));
	InventoryTable.Columns.Add("Amount",				New TypeDescription("Number", New NumberQualifiers(15, 2)));
	
	For Each Str In DataOrder.Inventory Do
		
		RowID = Str.GetID();
		
		NewRow = InventoryTable.Add();
		FillPropertyValues(NewRow, Str);
		NewRow.ID			= RowID;
		NewRow.Amount		= Str.Amount;  
		NewRow.Presentation	= DriveServer.GetProductsPresentationForPrinting(Str.Products, Str.Characteristic);
		
	EndDo;                                                                                                                                                                                                      
	
	Query = New Query;
	Query.SetParameter("Inventory", InventoryTable);
	Query.Text = 
	"SELECT
	|	Inventory.ID,
	|	Inventory.Amount,
	|	Inventory.Presentation,
	|	CAST(Inventory.Products AS Catalog.Products) AS Products,
	|	CAST(Inventory.Specification AS Catalog.BillsOfMaterials) AS Specification
	|INTO Inventory
	|FROM
	|	&Inventory AS Inventory
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Inventory.ID,
	|	Inventory.Amount,
	|	Inventory.Presentation,
	|	Inventory.Specification
	|FROM
	|	Inventory AS Inventory
	|WHERE
	|	(Inventory.Products.ReplenishmentMethod = VALUE(Enum.InventoryReplenishmentMethods.Production)
	|			OR NOT Inventory.Specification = VALUE(Catalog.BillsOfMaterials.EmptyRef))";
	Result = Query.ExecuteBatch();
	Selection = Result.Get(1).Select();
	
	While Selection.Next() Do
		Items.CurrentContentRow.ChoiceList.Add(Selection.ID, Selection.Presentation);
	EndDo;
	
	Items.CurrentContentRow.Visible = (Items.CurrentContentRow.ChoiceList.Count() > 1);
	
	If NOT Items.CurrentContentRow.Visible Then
		CurrentContentRow = -1;
	EndIf; 
	
EndProcedure

#Region Totals

&AtClient
Procedure RefreshTotalsClient()
	
	If CurrentContentRow < 0 Then
		TotalCost = 0;
		
		For Each Row In DataOrder.Inventory Do
			TotalCost = TotalCost + Row.Amount;
		EndDo;

		TotalPrimeCost = 0;
		
		For Each Row In DataOrder.Estimate Do
			TotalPrimeCost = TotalPrimeCost + Row.Cost;
		EndDo;
		
		TotalPrimeCostReal	= 0;
		TotalCostFact		= 0;
		TotalProfitReal		= 0;
		
		For Each Row In EstimateOnForm Do
			TotalPrimeCostReal	= TotalPrimeCostReal + Row.CostReal;
			TotalCostFact		= TotalCostFact + Row.CostFact;
			TotalProfitReal		= TotalProfitReal + Row.ProfitReal;
		EndDo;
		
	Else
		StringInventory	= DataOrder.Inventory.FindByID(CurrentContentRow);
		TotalCost		= StringInventory.Amount; 
		TotalPrimeCost	= 0;
		
		For Each Row In EstimateOnForm Do
			TotalPrimeCost = TotalPrimeCost + Row.Cost;
		EndDo;
		
		FilterStructure = New Structure;
		FilterStructure.Insert("Products", StringInventory.Products);
		RowsFact = ActualData.FindRows(FilterStructure);
		BaseRows = DataOrder.Inventory.FindRows(FilterStructure);
		
		BaseQuantity = 0;
		
		For Each InfobaseString In BaseRows Do
			BaseQuantity = BaseQuantity + InfobaseString.Quantity;
		EndDo;
		
		If RowsFact.Count() > 0 Then
			RowFact				= RowsFact[0];
			TotalPrimeCostReal	= ?(BaseQuantity = 0, 0, RowFact.CostReal / BaseQuantity * StringInventory.Quantity);
			TotalCostFact		= ?(BaseQuantity = 0, 0, RowFact.CostFact / BaseQuantity * StringInventory.Quantity);
		Else
			TotalPrimeCostReal	= 0;
			TotalCostFact		= 0;
		EndIf;
		
		TotalProfitReal = TotalCostFact - TotalPrimeCostReal;
	EndIf;
	
	TotalProfit = TotalCost - TotalPrimeCost;	
	
EndProcedure
 
&AtServer
Procedure RefreshTotalsServer()
	
	If CurrentContentRow < 0 Then
		TotalCost = 0;
		
		For Each Row In DataOrder.Inventory Do			
			TotalCost = TotalCost + Row.Amount;
		EndDo;
		
		TotalPrimeCost		= DataOrder.Estimate.Total("Cost");	
		TotalPrimeCostReal	= EstimateOnForm.Total("CostReal");
		TotalCostFact		= EstimateOnForm.Total("CostFact");
		TotalProfitReal		= EstimateOnForm.Total("ProfitReal");		
	Else
		StringInventory	= DataOrder.Inventory.FindByID(CurrentContentRow);
		TotalCost		= StringInventory.Amount;
		TotalPrimeCost	= EstimateOnForm.Total("Cost");
		
		FilterStructure = New Structure;
		FilterStructure.Insert("Products", StringInventory.Products);
		RowsFact = ActualData.FindRows(FilterStructure);
		BaseRows = DataOrder.Inventory.FindRows(FilterStructure);
		
		BaseQuantity = 0;
		
		For Each InfobaseString In BaseRows Do
			BaseQuantity = BaseQuantity + InfobaseString.Quantity;
		EndDo;
		
		If RowsFact.Count() > 0 Then
			RowFact				= RowsFact[0];
			TotalPrimeCostReal	= ?(BaseQuantity = 0, 0, RowFact.CostReal / BaseQuantity * StringInventory.Quantity);
			TotalCostFact		= ?(BaseQuantity = 0, 0, RowFact.CostFact / BaseQuantity * StringInventory.Quantity);
		Else
			TotalPrimeCostReal	= 0;
			TotalCostFact		= 0;
		EndIf;
		
		TotalProfitReal = TotalCostFact - TotalPrimeCostReal;
	EndIf;
	
	TotalProfit = TotalCost - TotalPrimeCost;	
	
EndProcedure

#EndRegion 

#Region Discounts

&AtClientAtServerNoContext
Procedure CalculateAmountAndDiscountPercent(Inventory, DiscountAmount, DiscountPercent)
	
	ManualDiscountTotalAmount	= 0;
	AmountWithoutDiscounts		= 0;
	
	For Each Row In Inventory Do
		
		AmountWithoutDiscounts = AmountWithoutDiscounts + Row.Price * Row.Quantity;
		
		If Row.DiscountMarkupPercent = 0 Then
			Continue;
		ElsIf Row.Property("AutomaticDiscountsPercent") Then
			ManualDiscountTotalAmount = ManualDiscountTotalAmount + Row.Price * Row.Quantity * (1 - Row.AutomaticDiscountsPercent / 100) - Row.Amount;
		Else
			ManualDiscountTotalAmount = ManualDiscountTotalAmount + Row.Price * Row.Quantity - Row.Amount;
		EndIf; 
		
	EndDo;
	
	DiscountAmount	= ManualDiscountTotalAmount;
	DiscountPercent	= ?(AmountWithoutDiscounts = 0, 0, ManualDiscountTotalAmount / AmountWithoutDiscounts * 100);
	
EndProcedure

&AtClient
Procedure RefreshInventoriesDiscount(TabularSectionRow)
	
	SupplyRow = StringByKey(DataOrder.Inventory, TabularSectionRow.ConnectionKey);
	SupplyRow.DiscountMarkupPercent = TabularSectionRow.DiscountMarkupPercent;
	
	CalculateAmountInTabularSectionLine(SupplyRow);
	
	TabularSectionRow.Amount = SupplyRow.Amount;
	TabularSectionRow.Profit = TabularSectionRow.Amount-TabularSectionRow.Cost;

EndProcedure

&AtClient
Procedure DistributeAmountToDiscounts(DistributionAmount)
	
	CommonAmount = 0;
	
	For Each TabularSectionRow In DataOrder.Inventory Do
		CommonAmount = CommonAmount + TabularSectionRow.Price * TabularSectionRow.Quantity;
	EndDo;
	
	If CommonAmount = 0 Then
		Return;
	EndIf;
	
	PercentDiscount = DistributionAmount / CommonAmount * 100;
	
	CommonDiscountAmount	= 0;
	AmountWithoutDiscounts	= 0;
	LastRow					= Undefined;
	
	For Each TabularSectionRow In DataOrder.Inventory Do
		
		TabularSectionRow.DiscountMarkupPercent = PercentDiscount;
		TabularSectionRow.Amount = (TabularSectionRow.Price * TabularSectionRow.Quantity) * (1 - TabularSectionRow.DiscountMarkupPercent / 100);
		
		CommonDiscountAmount = CommonDiscountAmount + (TabularSectionRow.Price * TabularSectionRow.Quantity - TabularSectionRow.Amount);
		
		TabularSectionRow.Amount = TabularSectionRow.Amount - TabularSectionRow.AutomaticDiscountAmount;
		
		LastRow = TabularSectionRow;
	EndDo;
	
	OutstandingTotal = DistributionAmount - CommonDiscountAmount;
	
	If OutstandingTotal <> 0 Then
		RowAmountWithoutDiscount = TabularSectionRow.Price * TabularSectionRow.Quantity;
		LastRow.DiscountMarkupPercent = (TabularSectionRow.Price * TabularSectionRow.Quantity * TabularSectionRow.DiscountMarkupPercent/100 
			+ OutstandingTotal) / RowAmountWithoutDiscount * 100;
			
		LastRow.Amount = LastRow.Amount - OutstandingTotal;
	EndIf;
	
	For Each TabularSectionRow In DataOrder.Inventory Do
				
		VATRate = DriveReUse.GetVATRateValue(TabularSectionRow.VATRate);
		TabularSectionRow.VATAmount = ?(DataOrder.AmountIncludesVAT, 
										  TabularSectionRow.Amount - (TabularSectionRow.Amount) / ((VATRate + 100) / 100),
										  TabularSectionRow.Amount * VATRate / 100);
		TabularSectionRow.Total = TabularSectionRow.Amount + ?(DataOrder.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	EndDo; 
	
	If CurrentContentRow < 0 Then
		RefreshAmountDiscountsOnForm();
	EndIf; 
	
EndProcedure

&AtClient
Procedure RefreshAmountDiscountsOnForm()
	
	For Each TabularSectionRow In EstimateOnForm Do
		
		If TabularSectionRow.Source <> PredefinedValue("Enum.EstimateRowsSources.InventoryItem") Then
			Continue;
		EndIf;
		
		SupplyRow = StringByKey(DataOrder.Inventory, TabularSectionRow.ConnectionKey);
		
		If SupplyRow = Undefined Then
			Continue;
		EndIf;
		
		TabularSectionRow.DiscountMarkupPercent = SupplyRow.DiscountMarkupPercent;
		TabularSectionRow.Amount = SupplyRow.Amount;
		TabularSectionRow.Profit = TabularSectionRow.Amount - TabularSectionRow.Cost;
		
	EndDo; 
	
EndProcedure

&AtClient
Procedure CalculateAmountInTabularSectionLine(TabularSectionRow)
	
	TabularSectionRow.Amount = TabularSectionRow.Quantity * TabularSectionRow.Price;
	TabularSectionRow.Amount = TabularSectionRow.Amount * 
		(1 - (TabularSectionRow.DiscountMarkupPercent + TabularSectionRow.AutomaticDiscountsPercent) / 100);
		
	VATRate = DriveReUse.GetVATRateValue(TabularSectionRow.VATRate);
	TabularSectionRow.VATAmount = ?(DataOrder.AmountIncludesVAT, 
									  TabularSectionRow.Amount - (TabularSectionRow.Amount) / ((VATRate + 100) / 100),
									  TabularSectionRow.Amount * VATRate / 100);
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(DataOrder.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
EndProcedure
 
#EndRegion 

&AtServer
Procedure RefreshEstimateServer(UpdateByTemplate = True)
	
	If DataOrder.EstimateCostPriceCalculationMethod = Enums.EstimateCostPriceCalculationMethods.Prices 
		AND NOT ValueIsFilled(PriceKind) Then
			Return;
	ElsIf DataOrder.EstimateCostPriceCalculationMethod = Enums.EstimateCostPriceCalculationMethods.CounterpartiesPrices 
		AND NOT ValueIsFilled(SupplierPriceTypes) Then
			Return;
	EndIf; 
	
	ChangeEstimateProhibited	= False;
	Buffer						= CurrentContentRow;
	CurrentContentRow			= -1;
	
	FillEstimate();
	RefreshActualData();
	
	If UpdateByTemplate Then
		FillByTemplateServer();
	EndIf; 
	
	CurrentContentRow = Buffer;
	
	If CurrentContentRow < 0 Then
		EstimateOutput();
	Else
		EstimateOutput(CurrentContentRow);
	EndIf; 
	
EndProcedure

&AtServer
Procedure FillEstimate()
	
	// Creation inventories internal tables
	InventoryTable = DataOrder.Inventory.Unload(, "Products, Characteristic, Specification, MeasurementUnit, Quantity").CopyColumns();
	InventoryTable.Columns.Add("ID", New TypeDescription("Number", New NumberQualifiers(10, 0)));
	
	For Each Row In DataOrder.Inventory Do
				
		RowID = Row.GetID();
		NewRow = InventoryTable.Add();
		FillPropertyValues(NewRow, Row);
		NewRow.ID = RowID;
		
	EndDo;
	
	MaterialsTable = EmptyMaterialsTable();
	FillMaterialsTable(MaterialsTable);
	FilterPriceKind = FilterByPricesKind();
	CalculateCost(MaterialsTable, FilterPriceKind, DataOrder.ExchangeRate, DataOrder.Multiplicity, DataOrder.Date, OrderRef);
	
	StringsToDelete = New Array;
	
	For Each Row In DataOrder.Estimate Do
		
		If ValueIsFilled(Row.ProductsProduct) Then
			StringsToDelete.Add(Row);
		ElsIf TypeOf(Row.Products) = Type("CatalogRef.Products") Then
			
			FactsStructure = New Structure;
			FactsStructure.Insert("Order",					OrderRef);
			FactsStructure.Insert("Date",					DataOrder.Date);
			FactsStructure.Insert("Rate",					DataOrder.ExchangeRate);
			FactsStructure.Insert("Multiplicity",			DataOrder.Multiplicity);
			FactsStructure.Insert("PriceTypes",				FilterPriceKind);
			FactsStructure.Insert("Products",	Row.Products);
			FactsStructure.Insert("Characteristic",			Row.Characteristic);
			FactsStructure.Insert("Specification",			Row.Specification);
			FactsStructure.Insert("MeasurementUnit",		Row.MeasurementUnit);
			FactsStructure = ReceiveDataProductsOnChange(FactsStructure);
			
			Row.UnitCost	= FactsStructure.UnitCost;
			Row.Cost		= Row.UnitCost * Row.Quantity;
			
		EndIf;
		
	EndDo;
	
	For Each Row In StringsToDelete Do
		DataOrder.Estimate.Delete(Row);
	EndDo; 
	
	For Each Row In MaterialsTable Do
		
		SupplyRow = DataOrder.Inventory.FindByID(Row.ID);
		
		If SupplyRow = Undefined Then
			Continue;
		EndIf;
		
		NewRow = DataOrder.Estimate.Add();
		FillPropertyValues(NewRow, Row, "Products, Characteristic, Specification, MeasurementUnit, Quantity, UnitCost, Cost");
		NewRow.ProductsProduct	= SupplyRow.Products;
		NewRow.CharacteristicProduct		= SupplyRow.Characteristic;
		NewRow.SpecificationProduct			= SupplyRow.Specification;
		NewRow.Source						= Enums.EstimateRowsSources.InventoryItem;
		NewRow.ConnectionKey				= SupplyRow.ConnectionKey;
		
	EndDo; 
		
EndProcedure

&AtServer
Procedure ReplaceSpecification(RowID)
	
	TabularSectionRow = EstimateOnForm.FindByID(RowID);
	
	MaterialsTable = EmptyMaterialsTable();
	FillMaterialsTable(MaterialsTable, RowID);
	
	If DataOrder.EstimateCostPriceCalculationMethod = Enums.EstimateCostPriceCalculationMethods.LatestPurchasePrice Then
		FilterPriceKind = Undefined;
	ElsIf DataOrder.EstimateCostPriceCalculationMethod = Enums.EstimateCostPriceCalculationMethods.Prices 
		OR TypeOf(DataOrder.EstimateCostPriceCalculationMethod) = Type("CatalogRef.PriceTypes") Then
			FilterPriceKind = PriceKind;
	ElsIf DataOrder.EstimateCostPriceCalculationMethod = Enums.EstimateCostPriceCalculationMethods.CounterpartiesPrices Then
		FilterPriceKind = SupplierPriceTypes;
	Else
		FilterPriceKind = Undefined;
	EndIf; 
	
	CalculateCost(MaterialsTable, FilterPriceKind, DataOrder.ExchangeRate, DataOrder.Multiplicity, DataOrder.Date, OrderRef);
	
	If CurrentContentRow < 0 Then
		
		SupplyRow = StringByKey(DataOrder.Inventory, TabularSectionRow.ConnectionKey);
		
		If SupplyRow <> Undefined Then
			SupplyRow.Specification = TabularSectionRow.Specification;
			
			FilterStructure = New Structure;
			FilterStructure.Insert("ConnectionKey", TabularSectionRow.ConnectionKey);
			StringsToDelete = DataOrder.Estimate.FindRows(FilterStructure);
			
			For Each Row In StringsToDelete Do
				DataOrder.Estimate.Delete(Row);
			EndDo;
			
			For Each Row In MaterialsTable Do
				
				NewRow = DataOrder.Estimate.Add();
				FillPropertyValues(NewRow, Row, "Products, Characteristic, Specification, MeasurementUnit, Quantity, UnitCost, Cost");
				
				NewRow.ProductsProduct	= SupplyRow.Products;
				NewRow.CharacteristicProduct		= SupplyRow.Characteristic;
				NewRow.SpecificationProduct			= SupplyRow.Specification;
				NewRow.Source						= Enums.EstimateRowsSources.InventoryItem;
				NewRow.ConnectionKey				= SupplyRow.ConnectionKey;
				
			EndDo;			
		EndIf;
		
		TabularSectionRow.Cost		= MaterialsTable.Total("Cost");
		TabularSectionRow.UnitCost	= ?(TabularSectionRow.Quantity = 0, 0, TabularSectionRow.Cost / TabularSectionRow.Quantity);
		TabularSectionRow.Profit	= TabularSectionRow.Amount - TabularSectionRow.Cost;
		
	Else		
		TabularSectionRow.Cost		= MaterialsTable.Total("Cost");
		TabularSectionRow.UnitCost	= ?(TabularSectionRow.Quantity = 0, 0, TabularSectionRow.Cost / TabularSectionRow.Quantity);		
	EndIf;
 
	RefreshTotalsServer();
	Modified = True;
	
EndProcedure

&AtServerNoContext
Procedure CalculateCost(MaterialsTable, PriceTypes, Rate, Multiplicity, Date, Ref, OutputErrors = True)
	
	If TypeOf(PriceTypes) = Type("ValueList") Then
		ParameterPriceTypes = PriceTypes.UnloadValues();
		CalculationMethod = Enums.EstimateCostPriceCalculationMethods.CounterpartiesPrices;
	ElsIf TypeOf(PriceTypes) = Type("CatalogRef.PriceTypes") Then
		ParameterPriceTypes = New Array;
		ParameterPriceTypes.Add(PriceTypes);
		CalculationMethod = Enums.EstimateCostPriceCalculationMethods.Prices;
	Else
		ParameterPriceTypes = New Array;
		CalculationMethod = Enums.EstimateCostPriceCalculationMethods.LatestPurchasePrice;
	EndIf; 
	
	// Calculation primecost and expenses cost
	Query = New Query;
	Query.SetParameter("PriceTypes",		ParameterPriceTypes);
	Query.SetParameter("CalculationMethod",	CalculationMethod);
	Query.SetParameter("MaterialsTable",	MaterialsTable);
	Query.SetParameter("Rate",				Rate);
	Query.SetParameter("Multiplicity",		Multiplicity);

	If Ref.IsEmpty() Then
		Query.SetParameter("Period", EndOfDay(Date));
	Else
		Query.SetParameter("Period", Date);
	EndIf;
	
	Query.SetParameter("TableRoundingOrders", DriveServer.TableRoundingOrders());
	Query.Text = 
	"SELECT
	|	TableRoundingOrders.Order,
	|	TableRoundingOrders.Value
	|INTO TableRoundingOrders
	|FROM
	|	&TableRoundingOrders AS TableRoundingOrders
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MaterialsTable.ID,
	|	CAST(MaterialsTable.Products AS Catalog.Products) AS Products,
	|	MaterialsTable.Characteristic,
	|	MaterialsTable.Specification,
	|	MaterialsTable.MeasurementUnit,
	|	MaterialsTable.Quantity,
	|	CAST(MaterialsTable.ProductsCost AS Catalog.Products) AS ProductsCost,
	|	MaterialsTable.CharacteristicCost,
	|	MaterialsTable.MeasurementUnitCost,
	|	MaterialsTable.QuantityCost
	|INTO MaterialsTable
	|FROM
	|	&MaterialsTable AS MaterialsTable
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MaterialsTable.ID,
	|	MaterialsTable.Products,
	|	MaterialsTable.Products.ProductsType AS ProductsType,
	|	MaterialsTable.Characteristic,
	|	MaterialsTable.Specification,
	|	MaterialsTable.MeasurementUnit,
	|	MaterialsTable.Quantity,
	|	MaterialsTable.ProductsCost,
	|	MaterialsTable.ProductsCost.ProductsType AS ProductsTypeCost,
	|	MaterialsTable.CharacteristicCost,
	|	MaterialsTable.MeasurementUnitCost,
	|	MaterialsTable.QuantityCost
	|INTO Inventory
	|FROM
	|	MaterialsTable AS MaterialsTable
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	Inventory.ID,
	|	Inventory.Products,
	|	Inventory.ProductsType,
	|	Inventory.Products.ReplenishmentMethod AS ReplenishmentMethod,
	|	Inventory.Characteristic,
	|	Inventory.Specification,
	|	Inventory.MeasurementUnit,
	|	Inventory.Quantity,
	|	SUM(ISNULL(Prices.Price / &Rate * &Multiplicity, 0) * CASE
	|			WHEN VALUETYPE(Inventory.MeasurementUnitCost) = TYPE(Catalog.UOM)
	|				THEN CAST(Inventory.MeasurementUnitCost AS Catalog.UOM).Factor
	|			ELSE 1
	|		END * Inventory.QuantityCost) AS Cost,
	|	Inventory.ProductsCost,
	|	Inventory.CharacteristicCost
	|INTO MaterialsCost
	|FROM
	|	Inventory AS Inventory
	|		LEFT JOIN (SELECT
	|			Purchases.Products AS Products,
	|			Purchases.Characteristic AS Characteristic,
	|			MIN(CAST(CASE
	|						WHEN Purchases.Quantity = 0
	|							THEN 0
	|						ELSE Purchases.Amount * ExchangeRatesSliceLast.ExchangeRate / ExchangeRatesSliceLast.Multiplicity / Purchases.Quantity
	|					END AS NUMBER(15, 2))) AS Price
	|		FROM
	|			(SELECT
	|				Purchases.Products AS Products,
	|				Purchases.Characteristic AS Characteristic,
	|				MAX(Purchases.Period) AS Period
	|			FROM
	|				AccumulationRegister.Purchases AS Purchases
	|			WHERE
	|				Purchases.Period < &Period
	|				AND (Purchases.Products, Purchases.Characteristic) IN
	|						(SELECT
	|							Inventory.ProductsCost,
	|							Inventory.CharacteristicCost
	|						FROM
	|							Inventory AS Inventory
	|						WHERE
	|							&CalculationMethod = VALUE(Enum.EstimateCostPriceCalculationMethods.LatestPurchasePrice)
	|							AND NOT Inventory.ProductsTypeCost = VALUE(Enum.ProductsTypes.Operation))
	|			
	|			GROUP BY
	|				Purchases.Products,
	|				Purchases.Characteristic) AS LastPurchases
	|				LEFT JOIN AccumulationRegister.Purchases AS Purchases
	|				ON (Purchases.Products = LastPurchases.Products)
	|					AND (Purchases.Characteristic = LastPurchases.Characteristic)
	|					AND (Purchases.Period = LastPurchases.Period),
	|			InformationRegister.ExchangeRates.SliceLast(
	|					&Period,
	|					Currency IN
	|						(SELECT
	|							AccountCurrency.Value
	|						FROM
	|							Constant.PresentationCurrency AS AccountCurrency)) AS ExchangeRatesSliceLast
	|		
	|		GROUP BY
	|			Purchases.Products,
	|			Purchases.Characteristic
	|		
	|		UNION ALL
	|		
	|		SELECT
	|			PricesSliceLast.Products,
	|			PricesSliceLast.Characteristic,
	|			(CAST(PricesSliceLast.Price / CASE
	|					WHEN VALUETYPE(PricesSliceLast.MeasurementUnit) = TYPE(Catalog.UOM)
	|						THEN CAST(PricesSliceLast.MeasurementUnit AS Catalog.UOM).Factor
	|					ELSE 1
	|				END * ExchangeRatesSliceLast.ExchangeRate / ExchangeRatesSliceLast.Multiplicity / ISNULL(TableRoundingOrders.Value, 0.01) AS NUMBER(15, 0))) * ISNULL(TableRoundingOrders.Value, 0.01)
	|		FROM
	|			InformationRegister.Prices.SliceLast(
	|					&Period,
	|					(&CalculationMethod = VALUE(Enum.EstimateCostPriceCalculationMethods.Prices)
	|							AND PriceKind IN (&PriceTypes)
	|						OR Products.ProductsType = VALUE(Enum.ProductsTypes.Operation)
	|							AND PriceKind = VALUE(Catalog.PriceTypes.Accounting))
	|						AND (Products, Characteristic) IN
	|							(SELECT
	|								Inventory.ProductsCost,
	|								Inventory.CharacteristicCost
	|							FROM
	|								Inventory AS Inventory
	|							WHERE
	|								(&CalculationMethod = VALUE(Enum.EstimateCostPriceCalculationMethods.Prices)
	|									OR Inventory.ProductsCost.ProductsType = VALUE(Enum.ProductsTypes.Operation)))) AS PricesSliceLast
	|				LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&Period, ) AS ExchangeRatesSliceLast
	|				ON PricesSliceLast.PriceKind.PriceCurrency = ExchangeRatesSliceLast.Currency
	|				LEFT JOIN TableRoundingOrders AS TableRoundingOrders
	|				ON PricesSliceLast.PriceKind.RoundingOrder = TableRoundingOrders.Order
	|		
	|		UNION ALL
	|		
	|		SELECT
	|			CounterpartyPricesSliceLast.Products,
	|			CounterpartyPricesSliceLast.Characteristic,
	|			MIN(CounterpartyPricesSliceLast.Price / CASE
	|					WHEN VALUETYPE(CounterpartyPricesSliceLast.MeasurementUnit) = TYPE(Catalog.UOM)
	|						THEN CAST(CounterpartyPricesSliceLast.MeasurementUnit AS Catalog.UOM).Factor
	|					ELSE 1
	|				END * ExchangeRatesSliceLast.ExchangeRate / ExchangeRatesSliceLast.Multiplicity)
	|		FROM
	|			(SELECT
	|				CounterpartyPricesSliceLast.Products AS Products,
	|				CounterpartyPricesSliceLast.Characteristic AS Characteristic,
	|				MAX(CounterpartyPricesSliceLast.Period) AS Period
	|			FROM
	|				InformationRegister.CounterpartyPrices.SliceLast(
	|						&Period,
	|						&CalculationMethod = VALUE(Enum.EstimateCostPriceCalculationMethods.CounterpartiesPrices)
	|							AND SupplierPriceTypes IN (&PriceTypes)
	|							AND (Products, Characteristic) IN
	|								(SELECT
	|									Inventory.ProductsCost,
	|									Inventory.CharacteristicCost
	|								FROM
	|									Inventory AS Inventory
	|								WHERE
	|									&CalculationMethod = VALUE(Enum.EstimateCostPriceCalculationMethods.CounterpartiesPrices)
	|									AND NOT Inventory.ProductsTypeCost = VALUE(Enum.ProductsTypes.Operation))) AS CounterpartyPricesSliceLast
	|			
	|			GROUP BY
	|				CounterpartyPricesSliceLast.Products,
	|				CounterpartyPricesSliceLast.Characteristic) AS LastPrices
	|				LEFT JOIN InformationRegister.CounterpartyPrices.SliceLast(
	|						&Period,
	|						&CalculationMethod = VALUE(Enum.EstimateCostPriceCalculationMethods.CounterpartiesPrices)
	|							AND SupplierPriceTypes IN (&PriceTypes)
	|							AND (Products, Characteristic) IN
	|								(SELECT
	|									Inventory.ProductsCost,
	|									Inventory.CharacteristicCost
	|								FROM
	|									Inventory AS Inventory
	|								WHERE
	|									&CalculationMethod = VALUE(Enum.EstimateCostPriceCalculationMethods.CounterpartiesPrices)
	|									AND NOT Inventory.ProductsTypeCost = VALUE(Enum.ProductsTypes.Operation))) AS CounterpartyPricesSliceLast
	|					LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&Period, ) AS ExchangeRatesSliceLast
	|					ON CounterpartyPricesSliceLast.SupplierPriceTypes.PriceCurrency = ExchangeRatesSliceLast.Currency
	|				ON (CounterpartyPricesSliceLast.Products = LastPrices.Products)
	|					AND (CounterpartyPricesSliceLast.Characteristic = LastPrices.Characteristic)
	|					AND (CounterpartyPricesSliceLast.Period = LastPrices.Period)
	|		
	|		GROUP BY
	|			CounterpartyPricesSliceLast.Products,
	|			CounterpartyPricesSliceLast.Characteristic) AS Prices
	|		ON Inventory.ProductsCost = Prices.Products
	|			AND Inventory.CharacteristicCost = Prices.Characteristic
	|
	|GROUP BY
	|	Inventory.ID,
	|	Inventory.Products,
	|	Inventory.ProductsType,
	|	Inventory.Products.ReplenishmentMethod,
	|	Inventory.Characteristic,
	|	Inventory.Specification,
	|	Inventory.MeasurementUnit,
	|	Inventory.Quantity,
	|	Inventory.ProductsCost,
	|	Inventory.CharacteristicCost
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MaterialsCost.ProductsCost,
	|	MaterialsCost.CharacteristicCost
	|FROM
	|	MaterialsCost AS MaterialsCost
	|WHERE
	|	MaterialsCost.Cost = 0
	|	AND MaterialsCost.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
	|
	|GROUP BY
	|	MaterialsCost.ProductsCost,
	|	MaterialsCost.CharacteristicCost
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MaterialsCost.ID,
	|	MaterialsCost.Products AS Products,
	|	MaterialsCost.ProductsType,
	|	MaterialsCost.ReplenishmentMethod,
	|	MaterialsCost.Characteristic,
	|	MaterialsCost.Specification,
	|	MaterialsCost.MeasurementUnit,
	|	MaterialsCost.Quantity,
	|	SUM(MaterialsCost.Cost) AS Cost,
	|	CASE
	|		WHEN MaterialsCost.Quantity = 0
	|			THEN 0
	|		ELSE SUM(MaterialsCost.Cost) / MaterialsCost.Quantity
	|	END AS UnitCost
	|FROM
	|	MaterialsCost AS MaterialsCost
	|
	|GROUP BY
	|	MaterialsCost.Quantity,
	|	MaterialsCost.Specification,
	|	MaterialsCost.ProductsType,
	|	MaterialsCost.Products,
	|	MaterialsCost.MeasurementUnit,
	|	MaterialsCost.Characteristic,
	|	MaterialsCost.ReplenishmentMethod,
	|	MaterialsCost.ID
	|
	|ORDER BY
	|	Products";
	
	Result = Query.ExecuteBatch();
	MaterialsTable = Result.Get(5).Unload();
	ErrorTable = Result.Get(4).Unload();
	
	// Displaying the calculation errors
	If OutputErrors Then
		
		For Each Str In ErrorTable Do
			MessageText = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Cannot determine the cost of inventory item: %1'"),
				DriveServer.GetProductsPresentationForPrinting(Str.ProductsCost, Str.CharacteristicCost));
				
			CommonUseClientServer.MessageToUser(MessageText, Str.ProductsCost);
		EndDo;
		
	EndIf; 
	
EndProcedure

&AtServer
Procedure ReadTemplateData()
	
	If NOT ValueIsFilled(DataOrder.EstimateTemplate) Then		
		TemplateContent.Clear();		
		Return;		
	EndIf;
	
	Query = New Query;
	Query.SetParameter("EstimateTemplate", DataOrder.EstimateTemplate);
	Query.Text = 
	"SELECT ALLOWED
	|	""InventoryItem"" AS RowType,
	|	EstimatesTemplatesInventory.Products AS Products,
	|	EstimatesTemplatesInventory.Characteristic AS Characteristic,
	|	EstimatesTemplatesInventory.Specification AS Specification,
	|	EstimatesTemplatesInventory.Quantity AS Quantity,
	|	EstimatesTemplatesInventory.MeasurementUnit AS MeasurementUnit,
	|	UNDEFINED AS CalculationMethod,
	|	UNDEFINED AS Value,
	|	UNDEFINED AS Currency,
	|	EstimatesTemplatesInventory.ConnectionKey AS ConnectionKey
	|FROM
	|	Catalog.EstimatesTemplates.Inventory AS EstimatesTemplatesInventory
	|WHERE
	|	EstimatesTemplatesInventory.Ref = &EstimateTemplate
	|
	|UNION ALL
	|
	|SELECT
	|	""Expense"",
	|	EstimatesTemplatesExpenses.Expense,
	|	VALUE(Catalog.ProductsCharacteristics.EmptyRef),
	|	VALUE(Catalog.BillsOfMaterials.EmptyRef),
	|	0,
	|	UNDEFINED,
	|	EstimatesTemplatesExpenses.CalculationMethod,
	|	EstimatesTemplatesExpenses.Value,
	|	EstimatesTemplatesExpenses.Currency,
	|	EstimatesTemplatesExpenses.ConnectionKey
	|FROM
	|	Catalog.EstimatesTemplates.Expenses AS EstimatesTemplatesExpenses
	|WHERE
	|	EstimatesTemplatesExpenses.Ref = &EstimateTemplate";
	TemplateContent.Load(Query.Execute().Unload());
	
EndProcedure

&AtServer
Procedure FillByTemplateServer()
	
	FilterStructure = New Structure;
	FilterStructure.Insert("Source", Enums.EstimateRowsSources.Template);
	Rows = DataOrder.Estimate.FindRows(FilterStructure);
	
	For Each TabularSectionRow In Rows Do
		DataOrder.Estimate.Delete(TabularSectionRow);
	EndDo;
	
	If NOT ValueIsFilled(DataOrder.EstimateTemplate) Then
		Return;
	EndIf;
	
	Cost = 0;
	
	For Each Row In DataOrder.Inventory Do		
		Cost = Cost + Row.Total;
	EndDo;
	
	CostWithoutTemplates = 0;
	
	For Each Row In DataOrder.Estimate Do
		
		If Row.Source = PredefinedValue("Enum.EstimateRowsSources.Template") Then
			Continue;
		EndIf;
		
		CostWithoutTemplates = CostWithoutTemplates + Row.Cost;
	EndDo;
	
	Profit			= Cost - CostWithoutTemplates;
	AccountCurrency = Constants.PresentationCurrency.Get();
	FilterPriceKind = FilterByPricesKind();
	
	ReadTemplateData();
	
	For Each ContentRow In TemplateContent Do
		
		NewRow = DataOrder.Estimate.Add();
		FillPropertyValues(NewRow, ContentRow, "Products, Characteristic, Specification, Quantity, MeasurementUnit, ConnectionKey");
		NewRow.Source = Enums.EstimateRowsSources.Template;
		
		If ContentRow.RowType = "Expense" Then
			
			If ContentRow.CalculationMethod = Enums.CostsAmountCalculationMethods.FixedAmount Then
				TemplateCurrency = ?(ValueIsFilled(ContentRow.Currency), ContentRow.Currency, AccountCurrency);
				Rates = WorkWithExchangeRates.GetCurrencyRate(TemplateCurrency, DataOrder.Date);
				
				NewRow.Cost = ContentRow.Value * Rates.ExchangeRate / Rates.Multiplicity / DataOrder.ExchangeRate * DataOrder.Multiplicity;
			ElsIf ContentRow.CalculationMethod = Enums.CostsAmountCalculationMethods.PercentageSalesAmount Then
				NewRow.Cost = Cost * ContentRow.Value / 100;
			ElsIf ContentRow.CalculationMethod = Enums.CostsAmountCalculationMethods.PercentageProfit Then
				NewRow.Cost = Profit * ContentRow.Value / 100;
			EndIf;
			
		ElsIf ContentRow.RowType = "InventoryItem" Then
			
			FactsStructure = New Structure;
			FactsStructure.Insert("Order",					OrderRef);
			FactsStructure.Insert("Date",					DataOrder.Date);
			FactsStructure.Insert("Rate",					DataOrder.ExchangeRate);
			FactsStructure.Insert("Multiplicity",			DataOrder.Multiplicity);
			FactsStructure.Insert("PriceTypes",				FilterPriceKind);
			FactsStructure.Insert("Products",	NewRow.Products);
			FactsStructure.Insert("Characteristic",			NewRow.Characteristic);
			FactsStructure.Insert("Specification",			NewRow.Specification);
			FactsStructure.Insert("MeasurementUnit",		NewRow.MeasurementUnit);
			
			FactsStructure = ReceiveDataProductsOnChange(FactsStructure);
			FillPropertyValues(NewRow, FactsStructure, "UnitCost");
			NewRow.Cost = NewRow.UnitCost * NewRow.Quantity;
			
		EndIf;		
	EndDo;
	
EndProcedure

&AtClient
Procedure RecalculateFormulasByTemplate()
	
	If NOT ValueIsFilled(DataOrder.EstimateTemplate) Then
		RefreshTotalsClient();
		Return;
	EndIf;
	
	Cost = 0;
	For Each Row In DataOrder.Inventory Do		
		Cost = Cost + Row.Total;
	EndDo;
	
	CostWithoutTemplates = 0;
	
	For Each Row In DataOrder.Estimate Do
		
		If Row.Source = PredefinedValue("Enum.EstimateRowsSources.Template") Then
			Continue;
		EndIf;
		
		CostWithoutTemplates = CostWithoutTemplates + Row.Cost;
	EndDo; 
	
	TemplatesCost = 0;
	
	For Each Row In DataOrder.Estimate Do
		
		If Row.Source <> PredefinedValue("Enum.EstimateRowsSources.Template") Then
			Continue;
		EndIf;
		
		If Row.ManualEdit Then
			TemplatesCost = TemplatesCost + Row.Cost;
			Continue;
		EndIf;
		
		FilterStructure = New Structure;
		FilterStructure.Insert("ConnectionKey", Row.ConnectionKey);
		RowsContent = TemplateContent.FindRows(FilterStructure);
		
		If RowsContent.Count() = 0 Then
			Continue;
		EndIf;
		
		ContentRow = RowsContent[0];
		
		If ContentRow.CalculationMethod = PredefinedValue("Enum.CostsAmountCalculationMethods.PercentageSalesAmount") Then
			Row.Cost = Cost * ContentRow.Value / 100;
		ElsIf ContentRow.CalculationMethod = PredefinedValue("Enum.CostsAmountCalculationMethods.PercentageProfit") Then
			Row.Cost = (Cost - CostWithoutTemplates) * ContentRow.Value / 100;
		Else
			TemplatesCost = TemplatesCost + Row.Cost;
			Continue;
		EndIf;
		
		TemplatesCost = TemplatesCost + Row.Cost;
		
		If CurrentContentRow < 0 Then
			FilterStructure = New Structure;
			FilterStructure.Insert("Source",		PredefinedValue("Enum.EstimateRowsSources.Template"));
			FilterStructure.Insert("ConnectionKey",	ContentRow.ConnectionKey);
			RowsOnForm = EstimateOnForm.FindRows(FilterStructure);
			
			For Each StringOnForm In RowsOnForm Do
				StringOnForm.Cost	= Row.Cost;
				StringOnForm.Profit	= StringOnForm.CostFact - Row.Cost;
			EndDo;
			
		EndIf;
		
	EndDo;
	
	If CurrentContentRow < 0 Then
		RefreshTotalsClient();
	EndIf; 
	
EndProcedure

&AtServer
Procedure RefreshActualData()
	
	ActualData.Clear();
	
	If NOT ValueIsFilled(OrderRef) OR NOT FormParameters.FullRightsAvailable Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.SetParameter("SalesOrder",	OrderRef);
	Query.SetParameter("Rate",			DataOrder.ExchangeRate);
	Query.SetParameter("Multiplicity",	DataOrder.Multiplicity);
	Query.SetParameter("Period",		DataOrder.Date);
	Query.Text = 
	"SELECT ALLOWED
	|	NestedQuery.Products,
	|	SUM(NestedQuery.CostFact * ExchangeRatesSliceLast.ExchangeRate / ExchangeRatesSliceLast.Multiplicity / &Rate * &Multiplicity) AS CostFact,
	|	SUM(NestedQuery.CostReal * ExchangeRatesSliceLast.ExchangeRate / ExchangeRatesSliceLast.Multiplicity / &Rate * &Multiplicity) AS CostReal,
	|	SUM(NestedQuery.CostFact * ExchangeRatesSliceLast.ExchangeRate / ExchangeRatesSliceLast.Multiplicity / &Rate * &Multiplicity) - SUM(NestedQuery.CostReal * ExchangeRatesSliceLast.ExchangeRate / ExchangeRatesSliceLast.Multiplicity / &Rate * &Multiplicity) AS ProfitReal
	|FROM
	|	(SELECT
	|		SalesTurnovers.Products AS Products,
	|		SalesTurnovers.CostTurnover AS CostReal,
	|		SalesTurnovers.AmountTurnover AS CostFact
	|	FROM
	|		AccumulationRegister.Sales.Turnovers(, , Period, SalesOrder = &SalesOrder) AS SalesTurnovers
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		IncomeAndExpenses.GLAccount,
	|		IncomeAndExpenses.AmountExpenseTurnover,
	|		IncomeAndExpenses.AmountIncomeTurnover
	|	FROM
	|		AccumulationRegister.IncomeAndExpenses.Turnovers(
	|				,
	|				,
	|				Period,
	|				SalesOrder = &SalesOrder
	|					AND (BusinessLine = VALUE(Catalog.LinesOfBusiness.EmptyRef)
	|						OR BusinessLine.GLAccountCostOfSales <> GLAccount
	|							AND BusinessLine.GLAccountRevenueFromSales <> GLAccount)) AS IncomeAndExpenses
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		IncomeAndExpenses.GLAccount,
	|		-IncomeAndExpenses.AmountExpenseTurnover,
	|		-IncomeAndExpenses.AmountIncomeTurnover
	|	FROM
	|		AccumulationRegister.IncomeAndExpenses.Turnovers(
	|				,
	|				,
	|				Month,
	|				SalesOrder = &SalesOrder
	|					AND (BusinessLine = VALUE(Catalog.LinesOfBusiness.EmptyRef)
	|						OR BusinessLine.GLAccountCostOfSales <> GLAccount
	|							AND BusinessLine.GLAccountRevenueFromSales <> GLAccount)
	|					AND (GLAccount.MethodOfDistribution <> VALUE(Enum.CostAllocationMethod.DoNotDistribute)
	|						OR BusinessLine = VALUE(Catalog.LinesOfBusiness.Other)
	|						OR BusinessLine = VALUE(Catalog.LinesOfBusiness.EmptyRef))) AS IncomeAndExpenses
	|			LEFT JOIN Document.MonthEndClosing AS MonthEndClosing
	|			ON (BEGINOFPERIOD(IncomeAndExpenses.Period, MONTH) = BEGINOFPERIOD(MonthEndClosing.Date, MONTH))
	|				AND (MonthEndClosing.Posted)
	|				AND (MonthEndClosing.FinancialResultCalculation)
	|	WHERE
	|		NOT MonthEndClosing.Ref IS NULL
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		FinancialResult.GLAccount,
	|		FinancialResult.AmountExpenseTurnover,
	|		FinancialResult.AmountIncomeTurnover
	|	FROM
	|		AccumulationRegister.FinancialResult.Turnovers(
	|				,
	|				,
	|				Period,
	|				SalesOrder = &SalesOrder
	|					AND GLAccount.MethodOfDistribution <> VALUE(Enum.CostAllocationMethod.DoNotDistribute)
	|					AND (BusinessLine.GLAccountCostOfSales <> GLAccount
	|							AND BusinessLine.GLAccountRevenueFromSales <> GLAccount
	|						OR BusinessLine = VALUE(Catalog.LinesOfBusiness.Other)
	|						OR BusinessLine = VALUE(Catalog.LinesOfBusiness.EmptyRef))) AS FinancialResult
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		InventoryBalanceAndTurnovers.GLAccount,
	|		InventoryBalanceAndTurnovers.AmountReceipt - InventoryBalanceAndTurnovers.AmountExpense,
	|		0
	|	FROM
	|		AccumulationRegister.Inventory.BalanceAndTurnovers(
	|				,
	|				,
	|				Period,
	|				RegisterRecords,
	|				SalesOrder = &SalesOrder
	|					AND Products = VALUE(Catalog.Products.EmptyRef)
	|					AND GLAccount IN
	|						(SELECT
	|							InventoryBalances.GLAccount
	|						FROM
	|							AccumulationRegister.Inventory.Balance(, SalesOrder = &SalesOrder
	|								AND Products = VALUE(Catalog.Products.EmptyRef)) AS InventoryBalances
	|						WHERE
	|							InventoryBalances.QuantityBalance = 0
	|							AND InventoryBalances.AmountBalance <> 0)) AS InventoryBalanceAndTurnovers) AS NestedQuery,
	|	InformationRegister.ExchangeRates.SliceLast(
	|			&Period,
	|			Currency IN
	|				(SELECT
	|					AccountCurrency.Value
	|				FROM
	|					Constant.PresentationCurrency AS AccountCurrency)) AS ExchangeRatesSliceLast
	|
	|GROUP BY
	|	NestedQuery.Products";
	ActualData.Load(Query.Execute().Unload());
	
EndProcedure

&AtServer
Function CompareEstimateAndSpecification(ID)
	
	SupplyRow = DataOrder.Inventory.FindByID(ID);
	FilterStructure = New Structure;
	FilterStructure.Insert("ConnectionKey", SupplyRow.ConnectionKey);
	ModifiedRows = BillsOfMaterialsContents.FindRows(FilterStructure);
	
	If ModifiedRows.Count() > 0 Then
		// BillsOfMaterials with unsaved changes are skipped
		Return True;
		
	EndIf;
	
	ContentTable = DataOrder.Estimate.Unload().CopyColumns("Products, Characteristic, Specification, MeasurementUnit, Quantity");
	EstimateTable = DataOrder.Estimate.Unload(FilterStructure);
	For Each RowEstimate In EstimateTable Do
		
		If RowEstimate.Products = RowEstimate.ProductsProduct 
			AND RowEstimate.Characteristic = RowEstimate.CharacteristicProduct Then
				Continue;
		EndIf;
		
		NewRow = ContentTable.Add();
		FillPropertyValues(NewRow, RowEstimate);
		
		If SupplyRow.Quantity <> 0 AND SupplyRow.Quantity <> 1 Then
			
			For Each Str In EstimateTable Do
				NewRow.Quantity = NewRow.Quantity;
			EndDo;
			
		EndIf;
		
	EndDo; 
	
	Query = New Query;
	Query.SetParameter("ContentTable",		ContentTable);
	Query.SetParameter("Specification",		SupplyRow.Specification);
	Query.SetParameter("CountInventory",	SupplyRow.Quantity);
	
	Query.Text =
	"SELECT
	|	ContentTable.Products,
	|	ContentTable.Characteristic,
	|	ContentTable.Specification,
	|	ContentTable.MeasurementUnit,
	|	ContentTable.Quantity
	|INTO ContentTable
	|FROM
	|	&ContentTable AS ContentTable
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	NestedQuery.Products,
	|	NestedQuery.Characteristic,
	|	NestedQuery.Specification,
	|	NestedQuery.MeasurementUnit,
	|	CASE
	|		WHEN SUM(NestedQuery.Quantity) <> 0
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS QuantityDifferent,
	|	MAX(NestedQuery.PresentInEstimate) AS PresentInEstimate,
	|	MAX(NestedQuery.PresentInBillsOfMaterials) AS PresentInBillsOfMaterials,
	|	SUM(NestedQuery.Quantity) AS Quantity
	|FROM
	|	(SELECT
	|		ContentTable.Products AS Products,
	|		ContentTable.Characteristic AS Characteristic,
	|		ContentTable.Specification AS Specification,
	|		ContentTable.MeasurementUnit AS MeasurementUnit,
	|		ContentTable.Quantity AS Quantity,
	|		TRUE AS PresentInEstimate,
	|		FALSE AS PresentInBillsOfMaterials
	|	FROM
	|		ContentTable AS ContentTable
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		BillsOfMaterialsContent.Products,
	|		BillsOfMaterialsContent.Characteristic,
	|		BillsOfMaterialsContent.Specification,
	|		BillsOfMaterialsContent.MeasurementUnit,
	|		-(CAST(BillsOfMaterialsContent.Quantity / BillsOfMaterialsContent.ProductsQuantity * &CountInventory AS NUMBER(15, 3))),
	|		FALSE,
	|		TRUE
	|	FROM
	|		Catalog.BillsOfMaterials.Content AS BillsOfMaterialsContent
	|	WHERE
	|		BillsOfMaterialsContent.Ref = &Specification
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		OperationBillsOfMaterials.Operation,
	|		VALUE(Catalog.ProductsCharacteristics.EmptyRef),
	|		VALUE(Catalog.BillsOfMaterials.EmptyRef),
	|		VALUE(Catalog.UOMClassifier.h),
	|		-(CAST(&CountInventory * CASE
	|				WHEN NOT OperationBillsOfMaterials.Operation.FixedCost
	|					THEN OperationBillsOfMaterials.TimeNorm
	|				ELSE 1
	|			END / OperationBillsOfMaterials.ProductsQuantity AS NUMBER(15, 3))),
	|		FALSE,
	|		TRUE
	|	FROM
	|		Catalog.BillsOfMaterials.Operations AS OperationBillsOfMaterials
	|	WHERE
	|		OperationBillsOfMaterials.Ref = &Specification) AS NestedQuery
	|
	|GROUP BY
	|	NestedQuery.Products,
	|	NestedQuery.Characteristic,
	|	NestedQuery.Specification,
	|	NestedQuery.MeasurementUnit";
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		If NOT Selection.PresentInEstimate 
			OR NOT Selection.PresentInBillsOfMaterials 
			OR Selection.QuantityDifferent Then
				Return False;
		EndIf;
		
	EndDo;
	
	Return True;
	
EndFunction

&AtClient
Procedure EstimateOutputClient(ID = Undefined)
	
	ChangeEstimateProhibited = False;
	
	If NOT ReadOnly 
		AND ID <> Undefined 
		AND NOT CompareEstimateAndSpecification(ID) Then
		
		Notification = New NotifyDescription("EstimateOutputClientCompletion", ThisObject, ID);
		ShowQueryBox(
			Notification, 
			NStr("en = 'The BOM сontent was changed. Do you want to refresh the profit estimation?'"), 
			QuestionDialogMode.YesNo, 
			0, 
			DialogReturnCode.No);
		
		Return;
		
	EndIf;
	
	EstimateOutputClientCompletion(Undefined, ID);
	
	DisplayComment();
	
EndProcedure

&AtClient
Procedure EstimateOutputClientCompletion(Answer, ID) Export
	
	If Answer = DialogReturnCode.No Then
		ChangeEstimateProhibited = True;
	ElsIf Answer = DialogReturnCode.Yes Then
		
		EstimateRowID		= Items.EstimateOnForm.CurrentRow;
		Buffer				= CurrentContentRow;
		CurrentContentRow	= -1;
		ReplaceSpecification(EstimateRowID);
		
		CurrentContentRow = Buffer;
		
	EndIf;
	
	EstimateOutput(ID);	
	
EndProcedure

&AtServer
Procedure EstimateOutput(ID = Undefined)
	
	SetVisibleAndEnabled();
	
	EstimateOnForm.Clear();
	
	If ID = Undefined Then
		
		TableCost = DataOrder.Estimate.Unload();
		TableCost.GroupBy("ProductsProduct, CharacteristicProduct, SpecificationProduct, ConnectionKey, Source", "Cost");
		
		InventoryTable = DataOrder.Inventory.Unload();
		InventoryTable.Columns.Add("Source", New TypeDescription("EnumRef.EstimateRowsSources"));
		InventoryTable.FillValues(Enums.EstimateRowsSources.InventoryItem, "Source");
		
		Query = New Query;
		Query.SetParameter("TableCost",			TableCost);
		Query.SetParameter("InventoryTable",	InventoryTable);
		Query.SetParameter("ActualData",		ActualData.Unload());
		EstimateProducts = New Array;
		
		For Each Row In DataOrder.Estimate Do
			
			If Row.Source = Enums.EstimateRowsSources.InventoryItem Then
				Continue;
			EndIf;
			
			EstimateProducts.Add(Row.Products);
		EndDo;
		
		Query.SetParameter("EstimateProducts", EstimateProducts);
		Query.Text =
		"SELECT
		|	TableCost.ConnectionKey,
		|	TableCost.Source,
		|	TableCost.Cost
		|INTO TableCost
		|FROM
		|	&TableCost AS TableCost
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	CAST(InventoryTable.Products AS Catalog.Products) AS Products,
		|	CAST(InventoryTable.Characteristic AS Catalog.ProductsCharacteristics) AS Characteristic,
		|	CAST(InventoryTable.Batch AS Catalog.ProductsBatches) AS Batch,
		|	CAST(InventoryTable.Specification AS Catalog.BillsOfMaterials) AS Specification,
		|	InventoryTable.Source,
		|	InventoryTable.ConnectionKey,
		|	InventoryTable.MeasurementUnit,
		|	InventoryTable.Quantity,
		|	InventoryTable.Price AS Price,
		|	InventoryTable.DiscountMarkupPercent AS DiscountMarkupPercent,
		|	InventoryTable.AutomaticDiscountsPercent AS AutomaticDiscountsPercent,
		|	InventoryTable.Amount AS Amount
		|INTO InventoryTable
		|FROM
		|	&InventoryTable AS InventoryTable
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	ActualData.Products AS Products,
		|	ActualData.CostReal,
		|	ActualData.CostFact,
		|	ActualData.ProfitReal
		|INTO ActualData
		|FROM
		|	&ActualData AS ActualData
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	InventoryTable.Products,
		|	SUM(InventoryTable.Quantity) AS Quantity
		|INTO DistributionBase
		|FROM
		|	InventoryTable AS InventoryTable
		|
		|GROUP BY
		|	InventoryTable.Products
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	InventoryTable.Products,
		|	InventoryTable.Characteristic,
		|	InventoryTable.Batch,
		|	InventoryTable.Specification,
		|	InventoryTable.Source,
		|	InventoryTable.ConnectionKey,
		|	InventoryTable.MeasurementUnit,
		|	InventoryTable.Products.MeasurementUnit AS UnitOfMeasurementBasic,
		|	InventoryTable.Quantity,
		|	CASE
		|		WHEN InventoryTable.MeasurementUnit REFS Catalog.UOM
		|			THEN InventoryTable.Quantity * CAST(InventoryTable.MeasurementUnit AS Catalog.UOM).Factor
		|		ELSE InventoryTable.Quantity
		|	END AS BasisQuantity,
		|	CASE
		|		WHEN InventoryTable.DiscountMarkupPercent = 100
		|			THEN InventoryTable.Price * InventoryTable.Quantity * (100 - InventoryTable.AutomaticDiscountsPercent) / 100
		|		ELSE InventoryTable.Amount / (1 - InventoryTable.DiscountMarkupPercent / 100)
		|	END AS AmountWithoutDiscount,
		|	InventoryTable.Amount AS Amount,
		|	InventoryTable.DiscountMarkupPercent,
		|	InventoryTable.AutomaticDiscountsPercent,
		|	InventoryTable.Products.ReplenishmentMethod AS ReplenishmentMethod,
		|	InventoryTable.Products.ProductsType AS ProductsType,
		|	InventoryTable.Products.UseCharacteristics AS UseCharacteristics,
		|	InventoryTable.Products.UseBatches AS UseBatches
		|INTO InventoryForCalculation
		|FROM
		|	InventoryTable AS InventoryTable
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	InventoryForCalculation.Products AS Products,
		|	InventoryForCalculation.Characteristic AS Characteristic,
		|	InventoryForCalculation.Batch AS Batch,
		|	InventoryForCalculation.Specification AS Specification,
		|	InventoryForCalculation.ConnectionKey,
		|	InventoryForCalculation.MeasurementUnit,
		|	InventoryForCalculation.Quantity,
		|	InventoryForCalculation.Amount,
		|	InventoryForCalculation.AmountWithoutDiscount,
		|	InventoryForCalculation.DiscountMarkupPercent,
		|	InventoryForCalculation.AutomaticDiscountsPercent,
		|	InventoryForCalculation.ReplenishmentMethod,
		|	InventoryForCalculation.ProductsType,
		|	InventoryForCalculation.UseCharacteristics,
		|	InventoryForCalculation.UseBatches,
		|	ISNULL(TableCost.Cost, 0) AS Cost,
		|	CASE
		|		WHEN InventoryForCalculation.Quantity = 0
		|			THEN 0
		|		ELSE ISNULL(TableCost.Cost, 0) / InventoryForCalculation.Quantity
		|	END AS UnitCost,
		|	InventoryForCalculation.Amount - ISNULL(TableCost.Cost, 0) AS Profit,
		|	InventoryForCalculation.Source,
		|	ISNULL(CASE
		|			WHEN DistributionBase.Quantity = 0
		|				THEN 0
		|			ELSE ActualData.CostReal * InventoryForCalculation.Quantity / DistributionBase.Quantity
		|		END, 0) AS CostReal,
		|	ISNULL(CASE
		|			WHEN DistributionBase.Quantity = 0
		|				THEN 0
		|			ELSE ActualData.CostFact * InventoryForCalculation.Quantity / DistributionBase.Quantity
		|		END, 0) AS CostFact,
		|	ISNULL(CASE
		|			WHEN DistributionBase.Quantity = 0
		|				THEN 0
		|			ELSE ActualData.ProfitReal * InventoryForCalculation.Quantity / DistributionBase.Quantity
		|		END, 0) AS ProfitReal,
		|	FALSE AS DontSave
		|FROM
		|	InventoryForCalculation AS InventoryForCalculation
		|		LEFT JOIN TableCost AS TableCost
		|		ON InventoryForCalculation.ConnectionKey = TableCost.ConnectionKey
		|			AND (TableCost.Source = VALUE(Enum.EstimateRowsSources.InventoryItem))
		|		LEFT JOIN ActualData AS ActualData
		|		ON InventoryForCalculation.Products = ActualData.Products
		|		LEFT JOIN DistributionBase AS DistributionBase
		|		ON InventoryForCalculation.Products = DistributionBase.Products
		|
		|UNION ALL
		|
		|SELECT
		|	ActualData.Products,
		|	VALUE(Catalog.ProductsCharacteristics.EmptyRef),
		|	VALUE(Catalog.ProductsBatches.EmptyRef),
		|	VALUE(Catalog.BillsOfMaterials.EmptyRef),
		|	0,
		|	UNDEFINED,
		|	0,
		|	0,
		|	0,
		|	0,
		|	0,
		|	CASE
		|		WHEN ActualData.Products REFS Catalog.Products
		|			THEN CAST(ActualData.Products AS Catalog.Products).ReplenishmentMethod
		|		ELSE UNDEFINED
		|	END,
		|	CASE
		|		WHEN ActualData.Products REFS Catalog.Products
		|			THEN CAST(ActualData.Products AS Catalog.Products).ProductsType
		|		ELSE VALUE(Enum.ProductsTypes.EmptyRef)
		|	END,
		|	CASE
		|		WHEN ActualData.Products REFS Catalog.Products
		|			THEN CAST(ActualData.Products AS Catalog.Products).UseCharacteristics
		|		ELSE FALSE
		|	END,
		|	CASE
		|		WHEN ActualData.Products REFS Catalog.Products
		|			THEN CAST(ActualData.Products AS Catalog.Products).UseBatches
		|		ELSE FALSE
		|	END,
		|	0,
		|	0,
		|	0,
		|	VALUE(Enum.EstimateRowsSources.Others),
		|	ActualData.CostReal,
		|	ActualData.CostFact,
		|	ActualData.ProfitReal,
		|	TRUE
		|FROM
		|	ActualData AS ActualData
		|WHERE
		|	NOT ActualData.Products IN
		|				(SELECT
		|					DistributionBase.Products
		|				FROM
		|					DistributionBase AS DistributionBase)
		|	AND NOT ActualData.Products IN (&EstimateProducts)";
		Selection = Query.Execute().Select();
		
		While Selection.Next() Do
			
			If Selection.DontSave AND Selection.CostFact = 0 AND NOT ShowCost Then
				Continue;
			EndIf;
			
			NewRow = EstimateOnForm.Add();
			FillPropertyValues(NewRow, Selection);
		EndDo;
		
		Rows = New Array;
		
		For Each Row In DataOrder.Estimate Do
			
			If Row.Source = Enums.EstimateRowsSources.InventoryItem Then
				Continue;
			EndIf;
			
			Rows.Add(Row);
		EndDo;
		
	Else
		InventoryRow = DataOrder.Inventory.FindByID(ID);
		
		If InventoryRow = Undefined Then
			Return;
		EndIf;
		
		FilterStructure = New Structure;
		FilterStructure.Insert("ConnectionKey",	InventoryRow.ConnectionKey);
		FilterStructure.Insert("Source",		Enums.EstimateRowsSources.InventoryItem);
		Rows = DataOrder.Estimate.FindRows(FilterStructure);
	EndIf;
	
	For Each Row In Rows Do
		
		If Row.Products = Row.ProductsProduct AND Row.Characteristic = Row.CharacteristicProduct Then
			Continue;
		EndIf;
		
		NewRow = EstimateOnForm.Add();
		FillPropertyValues(NewRow, Row, "Products, Characteristic, Specification, Quantity, 
			|MeasurementUnit, UnitCost, Cost, Source, ConnectionKey, ManualEdit");
		
		If ID <> Undefined Then
			NewRow.Source = Enums.EstimateRowsSources.Others;
		EndIf;
		
		NewRow.Profit = -Row.Cost;
		
		If ID = Undefined Then
			FilterStructure = New Structure;
			FilterStructure.Insert("Products", Row.Products);
			RowsFact = ActualData.FindRows(FilterStructure);
			RowsInventory = DataOrder.Inventory.FindRows(FilterStructure);
			
			If RowsFact.Count() > 0 AND RowsInventory.Count() = 0 Then
				FillPropertyValues(NewRow, RowsFact[0], "CostReal, CostFact, ProfitReal");
			EndIf;
			
		EndIf;
		
	EndDo;
	
	CalculateAmountAndDiscountPercent(DataOrder.Inventory, DiscountAmount, DiscountPercent);	
	
	RefreshRowsNumbers(EstimateOnForm);	
	RefreshAdditionalAttributes();	
	RefreshTotalsServer();
	
EndProcedure

&AtClientAtServerNoContext
Procedure RefreshRowsNumbers(Table)
	
	LineNumber = 0;
	
	For Each Row In Table Do
		LineNumber = LineNumber + 1;
		Row.LineNumber = LineNumber;
	EndDo; 	
	
EndProcedure

&AtServer
Procedure RefreshAdditionalAttributes()
	
	ProductsTable = New ValueTable;
	ProductsTable.Columns.Add("ID", New TypeDescription("Number", New NumberQualifiers(10, 0)));
	ProductsTable.Columns.Add("Products", New TypeDescription("CatalogRef.Products"));
	
	For Each TabularSectionRow In EstimateOnForm Do
		
		If TypeOf(TabularSectionRow.Products) = Type("CatalogRef.Products") 
			AND NOT ValueIsFilled(TabularSectionRow.ProductsType) Then
			
			NewRow = ProductsTable.Add();
			NewRow.Products = TabularSectionRow.Products;
			NewRow.ID = TabularSectionRow.GetID();
			
		EndIf;
		
	EndDo;
	
	If ProductsTable.Count() = 0 Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.SetParameter("ProductsTable", ProductsTable);
	Query.Text =
	"SELECT
	|	ProductsTable.ID,
	|	CAST(ProductsTable.Products AS Catalog.Products) AS Products
	|INTO ProductsTable
	|FROM
	|	&ProductsTable AS ProductsTable
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ProductsTable.ID,
	|	ProductsTable.Products,
	|	ProductsTable.Products.ProductsType AS ProductsType,
	|	ProductsTable.Products.ReplenishmentMethod AS ReplenishmentMethod,
	|	ProductsTable.Products.UseCharacteristics AS UseCharacteristics,
	|	ProductsTable.Products.UseBatches AS UseBatches
	|FROM
	|	ProductsTable AS ProductsTable";
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		TabularSectionRow = EstimateOnForm.FindByID(Selection.ID);
		FillPropertyValues(TabularSectionRow, Selection, "ProductsType, ReplenishmentMethod, UseCharacteristics, UseBatches");
	EndDo;
	
	For Each TabularSectionRow In EstimateOnForm Do
		
		If TabularSectionRow.Source <> Enums.EstimateRowsSources.Template Then
			Continue;
		EndIf;
		
		TemplateRow = StringByKey(TemplateContent, TabularSectionRow.ConnectionKey);
		
		If TemplateRow = Undefined OR TemplateRow.RowType <> "Expense" Then
			Continue;
		EndIf;
		
		TabularSectionRow.CalculationMethod = TemplateRow.CalculationMethod;
	EndDo; 
	
EndProcedure

&AtServerNoContext
Function EmptyMaterialsTable()
	
	MaterialsTable = New ValueTable;
	MaterialsTable.Columns.Add("ConnectionKey",				New TypeDescription("Number", New NumberQualifiers(5, 0)));
	MaterialsTable.Columns.Add("ID",						New TypeDescription("Number", New NumberQualifiers(10, 0)));
	MaterialsTable.Columns.Add("Products",		New TypeDescription("CatalogRef.Products"));
	MaterialsTable.Columns.Add("Characteristic",			New TypeDescription("CatalogRef.ProductsCharacteristics"));
	MaterialsTable.Columns.Add("Specification",				New TypeDescription("CatalogRef.BillsOfMaterials"));
	MaterialsTable.Columns.Add("MeasurementUnit",			New TypeDescription("CatalogRef.UOM,CatalogRef.UOMClassifier"));
	MaterialsTable.Columns.Add("Quantity",					New TypeDescription("Number", New NumberQualifiers(15, 3)));
	MaterialsTable.Columns.Add("ProductsCost",	New TypeDescription("CatalogRef.Products"));
	MaterialsTable.Columns.Add("CharacteristicCost",		New TypeDescription("CatalogRef.ProductsCharacteristics"));
	MaterialsTable.Columns.Add("SpecificationCost",			New TypeDescription("CatalogRef.BillsOfMaterials"));
	MaterialsTable.Columns.Add("MeasurementUnitCost",		New TypeDescription("CatalogRef.UOM,CatalogRef.UOMClassifier"));
	MaterialsTable.Columns.Add("QuantityCost",				New TypeDescription("Number", New NumberQualifiers(15, 3)));
	MaterialsTable.Columns.Add("CheckLooping",				New TypeDescription("Array"));
	
	Return MaterialsTable;
	
EndFunction

&AtServer
Procedure FillMaterialsTable(MaterialsTable, EstimateRowID = Undefined)
	
	If EstimateRowID = Undefined Then
		Rows = DataOrder.Inventory;
	Else
		EstimateRow = EstimateOnForm.FindByID(EstimateRowID);
		Rows = New Array;
		Rows.Add(EstimateRow);
	EndIf;
	
	For Each Row In Rows Do
		
		StringSupplies = StringByKey(DataOrder.Inventory, Row.ConnectionKey);
		NewRow = MaterialsTable.Add();
		FillPropertyValues(NewRow, Row, "ConnectionKey, Products, Characteristic, Specification, MeasurementUnit");
		NewRow.Quantity = Row.Quantity;
		
		If StringSupplies <> Undefined Then
			NewRow.ID = StringSupplies.GetID();
		EndIf;
		
		If ValueIsFilled(Row.Specification) Then
			NewRow.CheckLooping.Add(Row.Specification);
		EndIf;
		
		NewRow.ProductsCost	= NewRow.Products;
		NewRow.CharacteristicCost		= NewRow.Characteristic;
		NewRow.SpecificationCost		= NewRow.Specification;
		NewRow.MeasurementUnitCost		= NewRow.MeasurementUnit;
		NewRow.QuantityCost				= Row.Quantity;
		
	EndDo; 
	
	Level = ?(CurrentContentRow < 0, 0, 1);
	
	While AreNestedBillsOfMaterials(MaterialsTable) Do
		Level = Level + 1;
		Result = ProductsNodeExplode(MaterialsTable, BillsOfMaterialsContents, Level);
		
		If NOT Result Then
			// Node exploding error
			MaterialsTable.Clear();
			
			Return;
			
		EndIf;
		
	EndDo;
	
	MaterialsTable.GroupBy("ID, Products, Characteristic, Specification, MeasurementUnit, 
		|ProductsCost, CharacteristicCost, MeasurementUnitCost", "Quantity, QuantityCost");
	
EndProcedure

&AtServerNoContext
Function ProductsNodeExplode(MaterialsTable, BillsOfMaterialsContents = Undefined, Level = 0)
	
	BillsOfMaterialsStrings = New Array;
	
	For Each Row In MaterialsTable Do
		
		If ValueIsFilled(Row.SpecificationCost) Then
			BillsOfMaterialsStrings.Add(Row);
		EndIf;
		
	EndDo;
	
	ContentTable = BillsOfMaterialsContentTable(BillsOfMaterialsStrings, BillsOfMaterialsContents, Level);
	
	For Each MaterialRow In BillsOfMaterialsStrings Do
		FilterStructure = New Structure;
		FilterStructure.Insert("SpecificationNode", MaterialRow.SpecificationCost);
		RowsContent = ContentTable.FindRows(FilterStructure);
		
		For Each RowContent In RowsContent Do
			
			If ValueIsFilled(RowContent.Specification) AND MaterialRow.CheckLooping.Find(RowContent.Specification)<>Undefined Then
				TextMessage = StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = 'Specification looping % 1 when product manufacturing % 2'"),
					RowContent.Specification,
					MaterialRow.Products);
				CommonUseClientServer.MessageToUser(TextMessage);
				Return False;
				
			EndIf;
			
			NewRow = MaterialsTable.Add();
			FillPropertyValues(NewRow, MaterialRow, "ID, CheckLooping");
			
			If Level = 1 Then
				// Store the first level of the BillsOfMaterials nesting
				FillPropertyValues(NewRow, RowContent, "Products, Characteristic, Specification, MeasurementUnit");
				NewRow.Quantity = RowContent.Quantity * MaterialRow.QuantityCost
					* ?(TypeOf(MaterialRow.MeasurementUnit) = Type("CatalogRef.UOM"), 
						CommonUse.ObjectAttributeValue(MaterialRow.MeasurementUnit, "Factor"),
						1);
			Else
				FillPropertyValues(NewRow, MaterialRow, "Products, Characteristic, Specification, MeasurementUnit, Quantity");
			EndIf; 
			
			NewRow.CheckLooping.Add(MaterialRow.SpecificationCost);
			NewRow.ProductsCost	= RowContent.Products;
			NewRow.CharacteristicCost		= RowContent.Characteristic;
			NewRow.SpecificationCost		= RowContent.Specification;
			NewRow.MeasurementUnitCost		= RowContent.MeasurementUnit;
			NewRow.QuantityCost				= RowContent.Quantity * MaterialRow.QuantityCost
				* ?(TypeOf(MaterialRow.MeasurementUnit) = Type("CatalogRef.UOM"), 
					CommonUse.ObjectAttributeValue(MaterialRow.MeasurementUnit, "Factor"), 
					1);
		EndDo;
		
		MaterialsTable.Delete(MaterialRow);
	EndDo;
	
	Return True;
	
EndFunction

&AtServerNoContext
Function BillsOfMaterialsContentTable(BillsOfMaterialsStrings, BillsOfMaterialsContents, Level)
	
	ModifiedRows = New Array;
	BillsOfMaterials = New Array;
	
	For Each Str In BillsOfMaterialsStrings Do
		
		If Level = 1 AND BillsOfMaterialsContents<>Undefined Then
			FilterStructure = New Structure;
			FilterStructure.Insert("ConnectionKey", Str.ConnectionKey);
			
			If BillsOfMaterialsContents.FindRows(FilterStructure).Count()>0 Then
				ModifiedRows.Add(Str);
				Continue;
			EndIf;
			
		EndIf; 
		BillsOfMaterials.Add(Str.Specification);
	EndDo; 
	
	Query = New Query;
	Query.SetParameter("BillsOfMaterials", BillsOfMaterials);
	Query.Text =
	"SELECT ALLOWED
	|	BillsOfMaterialsContent.Ref AS SpecificationNode,
	|	BillsOfMaterialsContent.ContentRowType,
	|	BillsOfMaterialsContent.Products,
	|	BillsOfMaterialsContent.Characteristic,
	|	BillsOfMaterialsContent.MeasurementUnit,
	|	BillsOfMaterialsContent.Specification,
	|	BillsOfMaterialsContent.Quantity / BillsOfMaterialsContent.ProductsQuantity AS Quantity
	|FROM
	|	Catalog.BillsOfMaterials.Content AS BillsOfMaterialsContent
	|WHERE
	|	BillsOfMaterialsContent.Ref IN(&BillsOfMaterials)
	|
	|UNION ALL
	|
	|SELECT
	|	OperationBillsOfMaterials.Ref,
	|	VALUE(Enum.BOMLineType.EmptyRef),
	|	OperationBillsOfMaterials.Operation,
	|	VALUE(Catalog.ProductsCharacteristics.EmptyRef),
	|	VALUE(Catalog.UOMClassifier.h),
	|	VALUE(Catalog.BillsOfMaterials.EmptyRef),
	|	CASE
	|		WHEN NOT OperationBillsOfMaterials.Operation.FixedCost
	|			THEN OperationBillsOfMaterials.TimeNorm
	|		ELSE 1
	|	END / OperationBillsOfMaterials.ProductsQuantity
	|FROM
	|	Catalog.BillsOfMaterials.Operations AS OperationBillsOfMaterials
	|WHERE
	|	OperationBillsOfMaterials.Ref IN(&BillsOfMaterials)";
	ContentTable = Query.Execute().Unload();
	ContentTable.Indexes.Add("SpecificationNode");
	
	If Level = 1 AND BillsOfMaterialsContents <> Undefined Then
		
		For Each Str In ModifiedRows Do
			
			FilterStructure = New Structure;
			FilterStructure.Insert("ConnectionKey", Str.ConnectionKey);
			RowsContent = BillsOfMaterialsContents.FindRows(FilterStructure);
			
			For Each RowContent In RowsContent Do
				NewRow = ContentTable.Add();
				FillPropertyValues(NewRow, RowContent);
				NewRow.SpecificationNode = Str.Specification;
				NewRow.Quantity = RowContent.Quantity / ?(RowContent.ProductsQuantity = 0, 1, RowContent.ProductsQuantity);
			EndDo;
			
		EndDo;
		
	EndIf; 
	
	Return ContentTable;
	
EndFunction

&AtServerNoContext
Function AreNestedBillsOfMaterials(MaterialsTable)
	
	For Each Row In MaterialsTable Do
		
		If ValueIsFilled(Row.SpecificationCost) Then
			Return True;
		EndIf;
		
	EndDo;
	
	Return False;
	
EndFunction

&AtClient
Function HeaderDataStructure()
	
	FactsStructure = New Structure;
	FactsStructure.Insert("Order",			OrderRef);
	FactsStructure.Insert("Date",			DataOrder.Date);
	FactsStructure.Insert("Rate",			DataOrder.ExchangeRate);
	FactsStructure.Insert("Multiplicity",	DataOrder.Multiplicity);
	
	If DataOrder.EstimateCostPriceCalculationMethod = PredefinedValue("Enum.EstimateCostPriceCalculationMethods.LatestPurchasePrice") Then
		FilterPriceKind = Undefined;
	ElsIf DataOrder.EstimateCostPriceCalculationMethod = PredefinedValue("Enum.EstimateCostPriceCalculationMethods.Prices")
		OR TypeOf(DataOrder.EstimateCostPriceCalculationMethod) = Type("CatalogRef.PriceTypes") Then
		FilterPriceKind = PriceKind;
	ElsIf DataOrder.EstimateCostPriceCalculationMethod = PredefinedValue("Enum.EstimateCostPriceCalculationMethods.CounterpartiesPrices") Then
		FilterPriceKind = SupplierPriceTypes;
	Else
		FilterPriceKind = Undefined;
	EndIf;
	
	FactsStructure.Insert("PriceTypes", FilterPriceKind);
	
	Return FactsStructure;
	
EndFunction

&AtServer
Function ReceiveDataProductsOnChange(FactsStructure)
	
	AttributeValues = CommonUse.ObjectAttributeValues(FactsStructure.Products, "MeasurementUnit, ReplenishmentMethod, ProductsType, UseCharacteristics, UseBatches");
	
	FactsStructure.Insert("ReplenishmentMethod",		AttributeValues.ReplenishmentMethod);
	FactsStructure.Insert("ProductsType",	AttributeValues.ProductsType);
	FactsStructure.Insert("UseCharacteristics",			AttributeValues.UseCharacteristics);
	FactsStructure.Insert("UseBatches",					AttributeValues.UseBatches);
	
	If NOT FactsStructure.Property("MeasurementUnit") OR NOT ValueIsFilled(FactsStructure.MeasurementUnit) Then
		FactsStructure.Insert("MeasurementUnit", AttributeValues.MeasurementUnit);
	EndIf;
	
	If NOT FactsStructure.Property("Specification") Then
		
		If FactsStructure.Property("Characteristic") Then
			FactsStructure.Insert("Specification", DriveServer.GetDefaultSpecification(FactsStructure.Products, FactsStructure.Characteristic));
		Else
			FactsStructure.Insert("Specification", DriveServer.GetDefaultSpecification(FactsStructure.Products));
		EndIf;
		
	EndIf; 
	
	MaterialsTable = EmptyMaterialsTable();
	RowMaterial = MaterialsTable.Add();
	RowMaterial.Products		= FactsStructure.Products;
	RowMaterial.Characteristic			= FactsStructure.Characteristic;
	RowMaterial.Specification			= FactsStructure.Specification;
	RowMaterial.MeasurementUnit			= FactsStructure.MeasurementUnit;
	RowMaterial.Quantity				= 1;
	RowMaterial.ProductsCost	= FactsStructure.Products;
	RowMaterial.CharacteristicCost		= FactsStructure.Characteristic;
	RowMaterial.SpecificationCost		= FactsStructure.Specification;
	RowMaterial.MeasurementUnitCost		= FactsStructure.MeasurementUnit;
	RowMaterial.QuantityCost			= 1;
	
	While AreNestedBillsOfMaterials(MaterialsTable) Do
		Result = ProductsNodeExplode(MaterialsTable);
		
		If NOT Result Then
			// Node exploding error
			FactsStructure.Insert("UnitCost", 0);
			
			Return FactsStructure;
			
		EndIf;
		
	EndDo;
	
	CalculateCost(MaterialsTable, FactsStructure.PriceTypes, FactsStructure.Rate, FactsStructure.Multiplicity, FactsStructure.Date, FactsStructure.Order, False);
	
	FactsStructure.Insert("UnitCost", MaterialsTable.Total("Cost"));
 
	Return FactsStructure;
	
EndFunction

&AtServer
Function FilterByPricesKind()
	
	If DataOrder.EstimateCostPriceCalculationMethod = PredefinedValue("Enum.EstimateCostPriceCalculationMethods.LatestPurchasePrice") Then
		Return Undefined;
	ElsIf DataOrder.EstimateCostPriceCalculationMethod = PredefinedValue("Enum.EstimateCostPriceCalculationMethods.Prices")
		OR TypeOf(DataOrder.EstimateCostPriceCalculationMethod) = Type("CatalogRef.PriceTypes") Then
		Return PriceKind;
	ElsIf DataOrder.EstimateCostPriceCalculationMethod = PredefinedValue("Enum.EstimateCostPriceCalculationMethods.CounterpartiesPrices") Then
		Return SupplierPriceTypes;
	Else
		Return Undefined;
	EndIf;
	
EndFunction

&AtClient
Procedure RecalculateCost(TabularSectionRow)
	
	TabularSectionRow.Cost = TabularSectionRow.UnitCost * TabularSectionRow.Quantity;
	TabularSectionRow.Profit = TabularSectionRow.Amount - TabularSectionRow.Cost;
	
	RefreshTotalsClient();
	
EndProcedure

&AtServer
Procedure ShowCostServer()
	
	SetVisibleAndEnabled();
	
	SystemSettingsStorage.Save("SalesOrder", "ShowCost", ShowCost);
	
EndProcedure

&AtServer
Procedure MakeChangesToEstimate()
	
	If CurrentContentRow >= 0 Then
		// Mode: change BillsOfMaterials of products
		
		RowInventories = DataOrder.Inventory.FindByID(CurrentContentRow);
		
		FilterStructure = New Structure;
		FilterStructure.Insert("ConnectionKey", RowInventories.ConnectionKey);
		Rows = BillsOfMaterialsContents.FindRows(FilterStructure);
		
		For Each Row In Rows Do
			BillsOfMaterialsContents.Delete(Row);
		EndDo;
		
		For Each Row In EstimateOnForm Do
			NewRow = BillsOfMaterialsContents.Add();
			NewRow.ConnectionKey = RowInventories.ConnectionKey;
			NewRow.ProductsProduct = RowInventories.Products;
			NewRow.CharacteristicProduct = RowInventories.Characteristic;
			NewRow.SpecificationProduct = RowInventories.Specification;
			FillPropertyValues(NewRow, Row, "Products, Characteristic, Specification, MeasurementUnit, Quantity");
			NewRow.ProductsQuantity = ?(RowInventories.Quantity=0, 1, RowInventories.Quantity);
			
			If Row.ProductsType = PredefinedValue("Enum.ProductsTypes.InventoryItem") 
				AND Row.ReplenishmentMethod = PredefinedValue("Enum.InventoryReplenishmentMethods.Purchase") Then
				NewRow.ContentRowType = PredefinedValue("Enum.BOMLineType.Material");
			ElsIf Row.ProductsType = PredefinedValue("Enum.ProductsTypes.InventoryItem") Then
				NewRow.ContentRowType = PredefinedValue("Enum.BOMLineType.Assembly");
			ElsIf Row.ProductsType = PredefinedValue("Enum.ProductsTypes.Operation") Then
				NewRow.ContentRowType = PredefinedValue("Enum.BOMLineType.EmptyRef");
			Else
				NewRow.ContentRowType = PredefinedValue("Enum.BOMLineType.Expense");
			EndIf;
			
		EndDo;
		
		// Update estimate
		
		FilterStructure = New Structure;
		FilterStructure.Insert("ConnectionKey", RowInventories.ConnectionKey);
		FilterStructure.Insert("Source", Enums.EstimateRowsSources.InventoryItem);
		Rows = DataOrder.Estimate.FindRows(FilterStructure);
		
		For Each Row In Rows Do
			DataOrder.Estimate.Delete(Row);
		EndDo;
		
		For Each Row In EstimateOnForm Do
			NewRow = DataOrder.Estimate.Add();
			FillPropertyValues(NewRow, Row, "Products, Characteristic, Specification, MeasurementUnit, Quantity, Cost, UnitCost");
			NewRow.ProductsProduct = RowInventories.Products;
			NewRow.CharacteristicProduct = RowInventories.Characteristic;
			NewRow.SpecificationProduct = RowInventories.Specification;
			NewRow.Source = Enums.EstimateRowsSources.InventoryItem;
			NewRow.ConnectionKey = RowInventories.ConnectionKey;
		EndDo;
		
	Else
		
		RowsToDelete = New Array;
		
		For Each Row In DataOrder.Estimate Do
			
			If Row.Source = Enums.EstimateRowsSources.InventoryItem Then
				Continue;
			EndIf;
			
			RowsToDelete.Add(Row);
		EndDo;
		
		For Each Row In RowsToDelete Do
			DataOrder.Estimate.Delete(Row);
		EndDo; 
		
		For Each Row In EstimateOnForm Do
			
			If Row.Source = Enums.EstimateRowsSources.InventoryItem Then
				Continue;
			EndIf;
			
			If Row.DontSave Then
				// Actual data row
				Continue;
			EndIf;
			
			NewRow = DataOrder.Estimate.Add();
			FillPropertyValues(NewRow, Row, "Products, Characteristic, Specification, MeasurementUnit, Quantity, Cost, Cost, Source, ConnectionKey, ManualEdit");
		EndDo;
		
	EndIf;
	
	RefreshTotalsServer();	
	
EndProcedure

&AtServer
Procedure PutEstimateDataInStorage()
	
	RefreshBillsOfMaterials();
	
	DataStructure = New Structure;
	InventoryTable = DataOrder.Inventory.Unload();
	DataStructure.Insert("Inventory", InventoryTable);
	
	EstimateTable = DataOrder.Estimate.Unload();
	DataStructure.Insert("Estimate", EstimateTable);
	
	If TypeOf(DataOrder.EstimateCostPriceCalculationMethod) = Type("CatalogRef.PriceTypes") Then
		DataStructure.Insert("EstimateCostPriceCalculationMethod", Enums.EstimateCostPriceCalculationMethods.Prices);
	Else
		DataStructure.Insert("EstimateCostPriceCalculationMethod", DataOrder.EstimateCostPriceCalculationMethod);
	EndIf;
	
	If DataOrder.EstimateCostPriceCalculationMethod = Enums.EstimateCostPriceCalculationMethods.CounterpartiesPrices Then
		DataStructure.Insert("PriceTypes", SupplierPriceTypes.UnloadValues());
	ElsIf DataOrder.EstimateCostPriceCalculationMethod = Enums.EstimateCostPriceCalculationMethods.Prices
		OR TypeOf(DataOrder.EstimateCostPriceCalculationMethod) = Type("CatalogRef.PriceTypes") Then
		
		PricesArray = New Array;
		PricesArray.Add(PriceKind);
		DataStructure.Insert("PriceTypes", PricesArray);
		
	Else
		DataStructure.Insert("PriceTypes", New Array);
	EndIf;
	
	DataStructure.Insert("EstimateTemplate",	DataOrder.EstimateTemplate);
	DataStructure.Insert("EstimateComment",		DataOrder.EstimateComment);
	
	DataAddress = PutToTempStorage(DataStructure, DataAddress);
	Modified = False;
	
EndProcedure

&AtServer
Procedure RefreshBillsOfMaterials()
	
	IDTable = BillsOfMaterialsContents.Unload(, "ConnectionKey, ProductsProduct, CharacteristicProduct, SpecificationProduct");
	IDTable.GroupBy("ConnectionKey, ProductsProduct, CharacteristicProduct, SpecificationProduct");
	
	For Each RowIdentifier In IDTable Do
		StrInventoryitem = StringByKey(DataOrder.Inventory, RowIdentifier.ConnectionKey);
		FilterStructure = New Structure;
		FilterStructure.Insert("ConnectionKey", RowIdentifier.ConnectionKey);
		Rows = BillsOfMaterialsContents.FindRows(FilterStructure);
		
		If StrInventoryitem = Undefined
			OR NOT ValueIsFilled(StrInventoryitem.Products)
			OR StrInventoryitem.Products <> RowIdentifier.ProductsProduct
			OR StrInventoryitem.Characteristic <> RowIdentifier.CharacteristicProduct
			OR StrInventoryitem.Specification <> RowIdentifier.SpecificationProduct Then
			// Outdated information
			For Each Row In Rows Do
				BillsOfMaterialsContents.Delete(Row);
			EndDo;
			
			Continue;
		EndIf;
		
		BillsOfMaterialsOrder = CommonUse.ObjectAttributeValue(StrInventoryitem.Specification, "SalesOrder");
		
		If NOT ValueIsFilled(StrInventoryitem.Specification) 
			OR BillsOfMaterialsOrder <> OrderRef Then
			Specification = Catalogs.BillsOfMaterials.CreateItem();
			Specification.Owner = StrInventoryitem.Products;
			Specification.ProductCharacteristic = StrInventoryitem.Characteristic;
			Specification.SalesOrder = OrderRef;
			Specification.Description = TrimAll(StrInventoryitem.Products)+
			" ("+OrderPresentation(DataOrder.Number, DataOrder.Date)+")";
			MessageText = NStr("en = 'Created automatically from the estimate'");
			
			If ValueIsFilled(StrInventoryitem.Specification) Then
				SpecificationByString = String(StrInventoryitem.Specification);
				HyperlinkText = "<A HREF='"+GetURL(StrInventoryitem.Specification)+"'>"+SpecificationByString+"</A>";
				MessageText = MessageText+StrTemplate(NStr("en = 'based on the bill of materials %1'"), HyperlinkText);
			EndIf;
			
			Specification.AdditionalProperties.Insert("DiscussionWrited", True);
		Else
			Specification = StrInventoryitem.Specification.GetObject();
			Specification.Content.Clear();
			Specification.Operations.Clear();
			Specification.AdditionalProperties.Insert("DiscussionWrited", True);
		EndIf;
		
		For Each Row In Rows Do
			
			If ValueIsFilled(Row.ContentRowType) Then
				NewRow = Specification.Content.Add();
				FillPropertyValues(NewRow, Row);
			Else
				NewRow = Specification.Operations.Add();
				FillPropertyValues(NewRow, Row, "ProductsQuantity");
				NewRow.Operation = Row.Products;
				NewRow.TimeNorm = 1;
			EndIf;
			
		EndDo;
		Specification.Write();
		StrInventoryitem.Specification = Specification.Ref;
		
		For Each Row In Rows Do
			BillsOfMaterialsContents.Delete(Row);
		EndDo;
		
	EndDo;
	
	FilterStructure = New Structure;
	FilterStructure.Insert("Changed", True);
	CommentsStrings = BillsOfMaterialsComments.FindRows(FilterStructure);
	
	For Each CommentStr In CommentsStrings Do
		StrInventoryitem = StringByKey(DataOrder.Inventory, CommentStr.ConnectionKey);
		
		If StrInventoryitem = Undefined 
			OR NOT ValueIsFilled(StrInventoryitem.Products) 
			OR NOT ValueIsFilled(StrInventoryitem.Specification) Then
			BillsOfMaterialsComments.Delete(CommentStr);
			Continue;
		EndIf;
		
		Specification = StrInventoryitem.Specification.GetObject();
		Specification.Comment = CommentStr.Comment;
		Specification.Write();
		CommentStr.Changed = False;
	EndDo; 
	
EndProcedure

&AtServer
Function OrderPresentation(Number, Date)
	
	Return StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en = '%1 %2 dated %3'"),
		NStr("en = 'Sales order'"),
		?(ValueIsFilled(Number), ObjectPrefixationClientServer.GetNumberForPrinting(Number, True, True), ""),
		Format(Date, "DLF=D"));
	
EndFunction

&AtClientAtServerNoContext
Function StringByKey(Table, ConnectionKey)
	
	FilterStructure = New Structure;
	FilterStructure.Insert("ConnectionKey", ConnectionKey);
	Rows = Table.FindRows(FilterStructure);
	
	If Rows.Count() = 0 Then
		Return Undefined;
	Else
		Return Rows[0];
	EndIf; 
	
EndFunction

&AtClientAtServerNoContext
Function FilledTPAttribute(Table, AttributeName)
	
	For Each Row In Table Do
				
		If ValueIsFilled(Row.Batch) Then
			Return True;
		EndIf;
		
	EndDo;
	
	Return False;
	
EndFunction

#Region Comments

&AtClient
Procedure CommentEndEntering(CommentText, AdditionalParameters) Export
	
	If CommentText = Undefined Then
		Return;
	EndIf;
	
	Comment = CommentText;
	OnChangeComment();
	
EndProcedure

&AtClient
Procedure OnChangeComment()
	
	If CurrentContentRow = -1 Then
		DataOrder.EstimateComment = Comment;
	Else
		InventoryRow = DataOrder.Inventory.FindByID(CurrentContentRow);
		
		If InventoryRow = Undefined Then
			Return;
		EndIf;
		
		StringComment = StringByKey(BillsOfMaterialsComments, InventoryRow.ConnectionKey);
		
		If StringComment = Undefined Then
			StringComment = BillsOfMaterialsComments.Add();
			StringComment.ConnectionKey = CurrentContentRow;
		EndIf;
		
		StringComment.Comment = Comment;
		StringComment.Changed = True;
	EndIf; 
	
EndProcedure

&AtServer
Procedure RefreshBillsOfMaterialsComments()
	
	Query = New Query;
	Query.SetParameter("ModifiedComments", ModifiedComments());
	Query.SetParameter("Inventory", DataOrder.Inventory.Unload());
	Query.Text =
	"SELECT
	|	ModifiedComments.ConnectionKey AS ConnectionKey,
	|	ModifiedComments.Comment AS Comment
	|INTO ModifiedComments
	|FROM
	|	&ModifiedComments AS ModifiedComments
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CAST(Inventory.Specification AS Catalog.BillsOfMaterials) AS Specification,
	|	Inventory.ConnectionKey AS ConnectionKey
	|INTO Inventory
	|FROM
	|	&Inventory AS Inventory
	|WHERE
	|	Inventory.Specification <> VALUE(Catalog.BillsOfMaterials.EmptyRef)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Inventory.ConnectionKey AS ConnectionKey,
	|	ISNULL(ModifiedComments.Comment, Inventory.Specification.Comment) AS Comment,
	|	CASE
	|		WHEN ModifiedComments.ConnectionKey IS NULL
	|			THEN FALSE
	|		ELSE TRUE
	|	END AS Changed
	|FROM
	|	Inventory AS Inventory
	|		LEFT JOIN ModifiedComments AS ModifiedComments
	|		ON Inventory.ConnectionKey = ModifiedComments.ConnectionKey";
	
	BillsOfMaterialsComments.Load(Query.Execute().Unload());
	
EndProcedure

&AtServer
Function ModifiedComments()
	
	FilterStructure = New Structure;
	FilterStructure.Insert("Changed", True);
	
	Return BillsOfMaterialsComments.Unload(FilterStructure);
	
EndFunction
 
&AtClient
Procedure DisplayComment()
	
	Comment = "";
	If CurrentContentRow = -1 Then
		Comment = DataOrder.EstimateComment;
		Items.Comment.InputHint = NStr("en = 'Profit estimation comment'");
	Else
		InventoryRow = DataOrder.Inventory.FindByID(CurrentContentRow);
		
		If InventoryRow = Undefined Then
			Return;
		EndIf;
		
		StringComment = StringByKey(BillsOfMaterialsComments, InventoryRow.ConnectionKey);
		
		If StringComment = Undefined Then
			Comment = BillsOfMaterialsComment(InventoryRow.Specification);
			
			If ValueIsFilled(InventoryRow.Specification) Then
				StringComment = BillsOfMaterialsComments.Add();
				StringComment.ConnectionKey = InventoryRow.ConnectionKey;
				StringComment.Comment = InventoryRow.Comment;
			EndIf;
			
		Else
			Comment = StringComment.Comment;
		EndIf;
		
		Items.Comment.InputHint = NStr("en = 'BOM comment'");
	EndIf; 		
	
EndProcedure

&AtServerNoContext
Function BillsOfMaterialsComment(Specification)
	
	If NOT ValueIsFilled(Specification) OR TypeOf(Specification) <> Type("CatalogRef.BillsOfMaterials") Then
		Return "";
	EndIf;
	
	Return CommonUse.ObjectAttributeValue(Specification, "Comment");
	
EndFunction
 
#EndRegion 

#EndRegion 

#Region WorkWithTheSelection

&AtClient
Procedure Pick(Command)
	
	TabularSectionName	= "Estimate";
	MarkerSelection		= "Estimate";
	DocumentPresentaion	= NStr("en = 'profit estimation'");
	
	SelectionParameters	= DriveClient.GetSelectionParameters(ThisObject, TabularSectionName, DocumentPresentaion, True, False, True);
	ProductsType = New ValueList;
	For Each ArrayElement In Items["EstimateOnFormProducts"].ChoiceParameters Do
		If ArrayElement.Name = "Filter.ProductsType" Then
			If TypeOf(ArrayElement.Value) = Type("FixedArray") Then
				For Each FixArrayItem In ArrayElement.Value Do
					ProductsType.Add(FixArrayItem);
				EndDo; 
			Else
				ProductsType.Add(ArrayElement.Value);
			EndIf;
		EndIf;
	EndDo;
	SelectionParameters.Insert("ProductsType",	ProductsType); 
	SelectionParameters.Insert("Date",			DataOrder.Date);
	SelectionParameters.Insert("PricePeriod",	DataOrder.Date);
	SelectionParameters.Insert("Company",		DataOrder.Company);
	SelectionParameters.Insert("VATTaxation",	DataOrder.VATTaxation);
	
	NotificationDescriptionOnCloseSelection = New NotifyDescription("OnCloseSelection", ThisObject);
	OpenForm("DataProcessor.ProductsSelection.Form.MainForm",
			SelectionParameters,
			ThisObject,
			True,
			,
			,
			NotificationDescriptionOnCloseSelection,
			FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtClient
Procedure WriteErrorReadingDataFromStorage()
	
	EventLogMonitorClient.AddMessageForEventLogMonitor("Error", , EventLogMonitorErrorText);
	
EndProcedure

&AtServer
Procedure GetInventoryFromStorage(InventoryAddressInStorage, TabularSectionName, HasCharacteristics, AreBatches)
	
	TableForImport = GetFromTempStorage(InventoryAddressInStorage);
	
	If NOT (TypeOf(TableForImport) = Type("ValueTable")
		OR TypeOf(TableForImport) = Type("Array")) Then
		
		EventLogMonitorErrorText = "Mismatch of type transferred to document from selection" + TypeOf(TableForImport) + "].
				|Address of inventories in storage: " + TrimAll(InventoryAddressInStorage) + "
				|Tabular section name: " + TrimAll(TabularSectionName);
		
		Return;
		
	Else
		
		EventLogMonitorErrorText = "";
		
	EndIf;
	
	FactsStructure = New Structure;
	FactsStructure.Insert("Order",			OrderRef);
	FactsStructure.Insert("Date",			DataOrder.Date);
	FactsStructure.Insert("Rate",			DataOrder.ExchangeRate);
	FactsStructure.Insert("Multiplicity",	DataOrder.Multiplicity);
	FactsStructure.Insert("PriceTypes",		FilterByPricesKind());
	
	For Each RowDownload In TableForImport Do
		
		NewRow = EstimateOnForm.Add();
		FillPropertyValues(NewRow, RowDownload);
		
		NewRow.Source = Enums.EstimateRowsSources.Others;
		NewRow.ManualEdit = True;
		
		FactsStructure.Insert("Products",	NewRow.Products);
		FactsStructure.Insert("Characteristic",			NewRow.Characteristic);
		FactsStructure.Insert("Specification",			NewRow.Specification);
		FactsStructure.Insert("MeasurementUnit",		NewRow.MeasurementUnit);
		
		FactsStructure = ReceiveDataProductsOnChange(FactsStructure);
		FillPropertyValues(NewRow, FactsStructure, "UnitCost,ReplenishmentMethod, ProductsType, UseCharacteristics, UseBatches");
		NewRow.Cost = NewRow.UnitCost * NewRow.Quantity;
	    NewRow.Profit = NewRow.Amount - NewRow.Cost;
	EndDo;
	
	MakeChangesToEstimate();
		
EndProcedure

// Procedure of processing the results of selection closing
//
&AtClient
Procedure OnCloseSelection(ClosingResult, AdditionalParameters) Export
	
	If TypeOf(ClosingResult) = Type("Structure") Then
		
		If Not IsBlankString(ClosingResult.CartAddressInStorage) Then
			
			InventoryAddressInStorage = ClosingResult.CartAddressInStorage;
			
			HasCharacteristics			= True;
			AreBatches					= False;
			
			If MarkerSelection = "Estimate" Then
				
				If NOT IsBlankString(EventLogMonitorErrorText) Then
					WriteErrorReadingDataFromStorage();
				EndIf;
				
				TabularSectionName = "Estimate";
				GetInventoryFromStorage(InventoryAddressInStorage, TabularSectionName, HasCharacteristics, AreBatches);
				
				RecalculateFormulasByTemplate();
				Modified = True;
				RefreshRowsNumbers(EstimateOnForm);
				
			EndIf;
			
			MarkerSelection = "";

		EndIf;
		
	EndIf;
	
EndProcedure
#EndRegion
