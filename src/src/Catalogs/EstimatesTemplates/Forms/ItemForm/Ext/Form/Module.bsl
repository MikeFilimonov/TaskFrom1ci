
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	AccountCurrency = Constants.PresentationCurrency.Get();
	
	SetConditionalAppearance();
	RefreshAdditionalAttributes();
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	RefreshAdditionalAttributes();	
	
EndProcedure

#EndRegion 

#Region FormsItemEventHandlers

&AtClient
Procedure InventoryOnStartEdit(Item, NewRow, Clone)
	
	If NewRow AND Clone Then
		TabularSectionRow = Item.CurrentData;
		TabularSectionRow.ConnectionKey = 0;
	EndIf; 	
	
EndProcedure

&AtClient
Procedure InventoryProductsOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	If TabularSectionRow = Undefined Then
		Return;
	EndIf;
	
	TabularSectionRow.Quantity = 1;
	
	FactsStructure = New Structure;
	FactsStructure.Insert("Products", TabularSectionRow.Products);
	FactsStructure.Insert("Characteristic", PredefinedValue("Catalog.ProductsCharacteristics.EmptyRef"));
	
	FactsStructure = ReceiveDataProductsOnChange(FactsStructure);
	
	FillPropertyValues(TabularSectionRow, FactsStructure, "Characteristic, Specification, MeasurementUnit, ReplenishmentMethod, ProductsType, UseCharacteristics");
	
EndProcedure

&AtClient
Procedure InventoryCharacteristicOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	If TabularSectionRow = Undefined Then
		Return;
	EndIf;
	
	FactsStructure = New Structure;
	FactsStructure.Insert("Products", TabularSectionRow.Products);
	FactsStructure.Insert("Characteristic", TabularSectionRow.Characteristic);
	
	FactsStructure = ReceiveDataProductsOnChange(FactsStructure);
	
	FillPropertyValues(TabularSectionRow, FactsStructure, "Specification");
	
EndProcedure

&AtClient
Procedure ExpensesOnStartEdit(Item, NewRow, Clone)
	
	If NewRow AND Clone Then
		TabularSectionRow = Item.CurrentData;
		TabularSectionRow.ConnectionKey = 0;
	EndIf; 	
	
EndProcedure

&AtClient
Procedure ExpensesCalculationMethodOnChange(Item)
	
	TabularSectionRow = Items.Expenses.CurrentData;
	
	If TabularSectionRow = Undefined Then
		Return;
	EndIf;
	
	If ValueIsFilled(TabularSectionRow.Currency) AND TabularSectionRow.CalculationMethod <> PredefinedValue("Enum.CostsAmountCalculationMethods.FixedAmount") Then
		TabularSectionRow.Currency = Undefined;
	ElsIf Not ValueIsFilled(TabularSectionRow.Currency) AND TabularSectionRow.CalculationMethod = PredefinedValue("Enum.CostsAmountCalculationMethods.FixedAmount") Then
		TabularSectionRow.Currency = AccountCurrency;
	EndIf; 
	
EndProcedure

#EndRegion 

#Region InternalProceduresAndFunctions

&AtServer
Procedure SetConditionalAppearance()
	
	// Inventory
	
	NewConditionalAppearance = ConditionalAppearance.Items.Add();
	
	Appearance = NewConditionalAppearance.Appearance.Items.Find("ReadOnly");
	Appearance.Value = True;
	Appearance.Use = True;
	
	Filter = NewConditionalAppearance.Filter.Items.Add(Type("DataCompositionFilterItem"));
	Filter.ComparisonType = DataCompositionComparisonType.Equal;
	Filter.Use 	= True;
	Filter.LeftValue = New DataCompositionField("Object.Inventory.UseCharacteristics");
	Filter.RightValue = False;
	
	Field = NewConditionalAppearance.Fields.Items.Add();
	Field.Use = True;
	Field.Field = New DataCompositionField("InventoryCharacteristic");
	
	NewConditionalAppearance = ConditionalAppearance.Items.Add();
	
	Appearance = NewConditionalAppearance.Appearance.Items.Find("ReadOnly");
	Appearance.Value = True;
	Appearance.Use = True;
	
	Filter = NewConditionalAppearance.Filter.Items.Add(Type("DataCompositionFilterItem"));
	Filter.ComparisonType = DataCompositionComparisonType.NotEqual;
	Filter.Use = True;
	Filter.LeftValue = New DataCompositionField("Object.Inventory.ReplenishmentMethod");
	Filter.RightValue = Enums.InventoryReplenishmentMethods.Production;
	
	Field = NewConditionalAppearance.Fields.Items.Add();
	Field.Use = True;
	Field.Field = New DataCompositionField("InventorySpecification");
	
	// Service Providers
	
	NewConditionalAppearance = ConditionalAppearance.Items.Add();
	
	Appearance = NewConditionalAppearance.Appearance.Items.Find("ReadOnly");
	Appearance.Value = True;
	Appearance.Use = True;
	Appearance = NewConditionalAppearance.Appearance.Items.Find("Text");
	Appearance.Value = "%";
	Appearance.Use = True;
	
	Filter = NewConditionalAppearance.Filter.Items.Add(Type("DataCompositionFilterItem"));
	Filter.ComparisonType = DataCompositionComparisonType.NotEqual;
	Filter.Use = True;
	Filter.LeftValue = New DataCompositionField("Object.Expenses.CalculationMethod");
	Filter.RightValue = Enums.CostsAmountCalculationMethods.FixedAmount;
	
	Field = NewConditionalAppearance.Fields.Items.Add();
	Field.Use = True;
	Field.Field = New DataCompositionField("ExpensesCurrency");
	
EndProcedure

&AtServer
Procedure RefreshAdditionalAttributes()
	
	ProductsTable = New ValueTable;
	ProductsTable.Columns.Add("ID", New TypeDescription("Number", New NumberQualifiers(10, 0)));
	ProductsTable.Columns.Add("Products", New TypeDescription("CatalogRef.Products"));
	
	For Each TabularSectionRow In Object.Inventory Do
		
		If Not ValueIsFilled(TabularSectionRow.ProductsType) Then
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
	|	ProductsTable.Products.UseCharacteristics AS UseCharacteristics
	|FROM
	|	ProductsTable AS ProductsTable";
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		TabularSectionRow = Object.Inventory.FindByID(Selection.ID);
		FillPropertyValues(TabularSectionRow, Selection, "ProductsType, ReplenishmentMethod, UseCharacteristics");
	EndDo; 
	
EndProcedure

&AtServerNoContext
Function ReceiveDataProductsOnChange(FactsStructure)
	
	AttributeValues = CommonUse.ObjectAttributeValues(FactsStructure.Products, "MeasurementUnit, ReplenishmentMethod, ProductsType, UseCharacteristics");
	
	FactsStructure.Insert("ReplenishmentMethod",		AttributeValues.ReplenishmentMethod);
	FactsStructure.Insert("ProductsType",	AttributeValues.ProductsType);
	FactsStructure.Insert("UseCharacteristics",			AttributeValues.UseCharacteristics);
	
	If Not FactsStructure.Property("MeasurementUnit") Or Not ValueIsFilled(FactsStructure.MeasurementUnit) Then
		FactsStructure.Insert("MeasurementUnit", AttributeValues.MeasurementUnit);
	EndIf;
	
	If FactsStructure.Property("Characteristic") Then
		FactsStructure.Insert("Specification", DriveServer.GetDefaultSpecification(FactsStructure.Products, FactsStructure.Characteristic));
	Else
		FactsStructure.Insert("Specification", DriveServer.GetDefaultSpecification(FactsStructure.Products));
	EndIf;
	
	Return FactsStructure;
	
EndFunction

#EndRegion
 
#Region WorkWithTheSelection

&AtClient
Procedure Select(Command)
	
	TabularSectionName	= "Inventory";
	MarkerSelection		= "Inventory";
	DocumentPresentaion	= NStr("en = 'estimation templates'");
	SelectionParameters	= DriveClient.GetSelectionParameters(ThisObject, TabularSectionName, DocumentPresentaion, False, False, False);
	SelectionParameters.Insert("Company", GetDefaultCompany());
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

&AtServerNoContext
Function GetDefaultCompany() 
	Return Catalogs.Companies.CompanyByDefault()
EndFunction

&AtClient
Procedure WriteErrorReadingDataFromStorage()
	
	EventLogMonitorClient.AddMessageForEventLogMonitor("Error", , EventLogMonitorErrorText);
	
EndProcedure

&AtServer
Procedure GetInventoryFromStorage(InventoryAddressInStorage, TabularSectionName, HasCharacteristics, AreBatches)
	
	TableForImport = GetFromTempStorage(InventoryAddressInStorage);
	
	If Not (TypeOf(TableForImport) = Type("ValueTable")
		Or TypeOf(TableForImport) = Type("Array")) Then
		
		EventLogMonitorErrorText = "Mismatch of type transferred to document from selection" + TypeOf(TableForImport) + "].
				|Address of inventories in storage: " + TrimAll(InventoryAddressInStorage) + "
				|Tabular section name: " + TrimAll(TabularSectionName);
		
		Return;
		
	Else		
		EventLogMonitorErrorText = "";		
	EndIf;
	
	For Each RowDownload In TableForImport Do
		
		NewRow = Object[TabularSectionName].Add();
		FillPropertyValues(NewRow, RowDownload);
		
	EndDo;
	
EndProcedure

// Procedure of processing the results of selection closing
//
&AtClient
Procedure OnCloseSelection(ClosingResult, AdditionalParameters) Export
	
	If TypeOf(ClosingResult) = Type("Structure") Then
		
		If Not IsBlankString(ClosingResult.CartAddressInStorage) Then
			
			InventoryAddressInStorage = ClosingResult.CartAddressInStorage;
			HasCharacteristics 	= True;
			AreBatches = False;
			
			If MarkerSelection = "Inventory" Then
				
				If Not IsBlankString(EventLogMonitorErrorText) Then
					WriteErrorReadingDataFromStorage();
				EndIf;
				
				TabularSectionName	= "Inventory";
				GetInventoryFromStorage(InventoryAddressInStorage, TabularSectionName, HasCharacteristics, AreBatches);
				
				Modified = True;
				
			EndIf;
			
			MarkerSelection = "";
				
		EndIf;
		
	EndIf;
	
EndProcedure
#EndRegion
