
Function MaximumOfUsefulColumnsTableDocument() Export
	
	// Most attributes contains catalog Counterparties (30 useful) + 10 CI + Additional attributes.
	// The remaining cells are checked in DataImportFromExternalSources.OptimizeSpreadsheetDocument();
	
	Return 30 + 10 + MaximumOfAdditionalAttributesTableDocument();
	
EndFunction

Function MaximumOfAdditionalAttributesTableDocument() Export
	
	Return 10;
	
EndFunction

Procedure AddConditionalMatchTablesDesign(ThisObject, AttributePath, DataLoadSettings) Export
	
	If DataLoadSettings.IsTabularSectionImport Then
		
		Return;
		
	ElsIf DataLoadSettings.IsCatalogImport Then
		
		If DataLoadSettings.FillingObjectFullName = "Catalog.Products" Then
			
			FieldName = "Products";
			
		ElsIf DataLoadSettings.FillingObjectFullName = "Catalog.Counterparties" Then
			
			FieldName = "Counterparty";
			
		ElsIf DataLoadSettings.FillingObjectFullName = "Catalog.Leads" Then
			
			FieldName = "Lead";
			
		EndIf;
		
		TextNewItem	= NStr("en = '<New item will be created>'");
		TextSkipped	= NStr("en = '<Data will be skipped>'");
		ConditionalAppearanceText = ?(DataLoadSettings.CreateIfNotMatched, TextNewItem, TextSkipped);
		
	ElsIf DataLoadSettings.IsInformationRegisterImport Then
		
		If DataLoadSettings.FillingObjectFullName = "InformationRegister.Prices" Then
			
			FieldName = "Products";
			
		EndIf;
		
		ConditionalAppearanceText = NStr("en = '<Row will be skipped...>'");
		
	EndIf;
	
	DCConditionalAppearanceItem = ThisObject.ConditionalAppearance.Items.Add();
	DCConditionalAppearanceItem.Use = True;
	
	DCFilterItem = DCConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	DCFilterItem.LeftValue = New DataCompositionField(AttributePath + "." + FieldName);
	DCFilterItem.ComparisonType = DataCompositionComparisonType.NotFilled;
	
	DCConditionalAppearanceItem.Appearance.SetParameterValue(New DataCompositionParameter("Text"), ConditionalAppearanceText);
	DCConditionalAppearanceItem.Appearance.SetParameterValue(New DataCompositionParameter("TextColor"), New Color(175, 175, 175));
	
	FormedFieldKD = DCConditionalAppearanceItem.Fields.Items.Add();
	FormedFieldKD.Field = New DataCompositionField(FieldName);
	
EndProcedure

Procedure ChangeConditionalDesignText(ConditionalAppearance, DataLoadSettings) Export
	
	If DataLoadSettings.IsTabularSectionImport Then
		
		Return;
		
	ElsIf DataLoadSettings.IsInformationRegisterImport Then
		
		Return;
		
	ElsIf DataLoadSettings.IsCatalogImport Then
		
		If DataLoadSettings.FillingObjectFullName = "Catalog.Products" Then
			
			FieldName = "Products";
			
		ElsIf DataLoadSettings.FillingObjectFullName = "Catalog.Counterparties" Then
			
			FieldName = "Counterparty";
			
		EndIf;
		
		TextNewItem	= NStr("en = '<New item will be created>'");
		TextSkipped	= NStr("en = '<Data will be skipped>'");
		ConditionalAppearanceText = ?(DataLoadSettings.CreateIfNotMatched, TextNewItem, TextSkipped);
		
	EndIf;
	
	SearchItem = New DataCompositionField(FieldName);
	For Each ConditionalAppearanceItem In ConditionalAppearance.Items Do
		
		ThisIsTargetFormat = False;
		For Each MadeOutField In ConditionalAppearanceItem.Fields.Items Do
			
			If MadeOutField.Field = SearchItem Then
				
				ThisIsTargetFormat = True;
				Break;
				
			EndIf;
			
		EndDo;
		
		If ThisIsTargetFormat Then
			
			ConditionalAppearanceItem.Appearance.SetParameterValue(New DataCompositionParameter("Text"), ConditionalAppearanceText);
			
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure WhenDeterminingDataImportForm(DataImportFormNameFromExternalSources, FillingObjectFullName, FilledObject) Export
	
	
	
EndProcedure

Procedure OverrideDataImportFieldsFilling(ImportFieldsTable, DataLoadSettings) Export
	
	
	
EndProcedure

Procedure WhenAddingServiceFields(ServiceFieldsGroup, FillingObjectFullName) Export
	
	
	
EndProcedure

Procedure AfterAddingItemsToMatchesTables(ThisObject, DataLoadSettings) Export
	
	If DataLoadSettings.FillingObjectFullName = "Catalog.Products" Then
		
		ThisObject.Items["Parent"].ChoiceForm = "Catalog.Products.Form.GroupChoiceForm";
		
	ElsIf DataLoadSettings.FillingObjectFullName = "Catalog.Counterparties"  Then
		
		ThisObject.Items["Parent"].ChoiceForm = "Catalog.Counterparties.Form.GroupChoiceForm.";
		
	ElsIf DataLoadSettings.FillingObjectFullName = "Document.SupplierInvoice.TabularSection.Inventory" Then
		
		ArrayProductsTypes = New Array;
		ArrayProductsTypes.Add(Enums.ProductsTypes.InventoryItem);
		
		NewParameter = New ChoiceParameter("Filter.ProductsType", ArrayProductsTypes);
		
		ParameterArray = New Array;
		ParameterArray.Add(NewParameter);
		
		ThisObject.Items["Products"].ChoiceParameters = New FixedArray(ParameterArray);
		
	ElsIf DataLoadSettings.FillingObjectFullName = "Document.SupplierInvoice.TabularSection.Expenses" Then
		
		ArrayProductsTypes = New Array;
		ArrayProductsTypes.Add(Enums.ProductsTypes.Service);
		
		NewParameter = New ChoiceParameter("Filter.ProductsType", ArrayProductsTypes);
		
		ParameterArray = New Array;
		ParameterArray.Add(NewParameter);
		
		ThisObject.Items["Products"].ChoiceParameters = New FixedArray(ParameterArray);
		
	EndIf;
	
EndProcedure

Procedure WhenDeterminingUsageMode(UseTogether) Export
	
	UseTogether = True;
	
EndProcedure

Procedure DataImportFieldsFromExternalSource(ImportFieldsTable, DataLoadSettings) Export
	
	FillingObjectFullName = DataLoadSettings.FillingObjectFullName;
	FilledObject = Metadata.FindByFullName(FillingObjectFullName);
	
	TypeDescriptionString10		= New TypeDescription("String", , , , New StringQualifiers(10));
	TypeDescriptionString11		= New TypeDescription("String", , , , New StringQualifiers(1));
	TypeDescriptionString25 	= New TypeDescription("String", , , , New StringQualifiers(25));
	TypeDescriptionString50 	= New TypeDescription("String", , , , New StringQualifiers(50));
	TypeDescriptionString100	= New TypeDescription("String", , , , New StringQualifiers(100));
	TypeDescriptionString150 	= New TypeDescription("String", , , , New StringQualifiers(150));
	TypeDescriptionString200 	= New TypeDescription("String", , , , New StringQualifiers(200));
	TypeDescriptionString1000 	= New TypeDescription("String", , , , New StringQualifiers(100));
	TypeDescriptionNumber10_0	= New TypeDescription("Number", , , , New NumberQualifiers(10, 0, AllowedSign.Nonnegative));
	TypeDescriptionNumber10_3	= New TypeDescription("Number", , , , New NumberQualifiers(10, 3, AllowedSign.Nonnegative));
	TypeDescriptionNumber15_2	= New TypeDescription("Number", , , , New NumberQualifiers(15, 2, AllowedSign.Nonnegative));
	TypeDescriptionNumber15_3 	= New TypeDescription("Number", , , , New NumberQualifiers(15, 3, AllowedSign.Nonnegative));
	TypeDescriptionDate 		= New TypeDescription("Date", , , , New DateQualifiers(DateFractions.Date));
	
	If DataLoadSettings.FillingObjectFullName = "Catalog.Counterparties" Then 
		TypeDescriptionColumn = New TypeDescription("CatalogRef.Counterparties");
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "Parent", NStr("en = 'Group'"),
																	TypeDescriptionString100, TypeDescriptionColumn);
		
		TypeDescriptionColumn = New TypeDescription("Boolean");
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "ThisIsInd",
																	NStr("en = 'Is this an individual?'"),
																	TypeDescriptionString10, TypeDescriptionColumn);
		
		TypeDescriptionColumn = New TypeDescription("CatalogRef.Counterparties");
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "TIN", NStr("en = 'TIN'"),
																	TypeDescriptionString25, TypeDescriptionColumn, "Counterparty", 1, , True);
																	
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "CounterpartyDescription",
																	NStr("en = 'Counterparty (name)'"),
																	TypeDescriptionString100, TypeDescriptionColumn, "Counterparty", 3, True, True);
																	
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "BankAccount",
																	NStr("en = 'Counterparty (operating account)'"),
																	TypeDescriptionString50, TypeDescriptionColumn, "Counterparty", 4, , True);
																			
		TypeDescriptionColumn = New TypeDescription("CatalogRef.Individuals");
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "Individual",
																	NStr("en = 'Individual'"),
																	TypeDescriptionString200, TypeDescriptionColumn);
		
		If GetFunctionalOption("UseCounterpartiesAccessGroups") Then
			
			TypeDescriptionColumn = New TypeDescription("CatalogRef.CounterpartiesAccessGroups");
			DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "AccessGroup",
																		NStr("en = 'Counterparty access group'"),
																		TypeDescriptionString200, TypeDescriptionColumn, , , True);
		EndIf;
		
		TypeDescriptionColumn = New TypeDescription("ChartOfAccountsRef.PrimaryChartOfAccounts");
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "GLAccountCustomerSettlements",
																	NStr("en = 'GL account (accounts receivable)'"),
																	TypeDescriptionString10, TypeDescriptionColumn);
																	
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "CustomerAdvancesGLAccount",
																	NStr("en = 'GL account (customer advances)'"),
																	TypeDescriptionString10, TypeDescriptionColumn);
																	
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "GLAccountVendorSettlements", 	
																	NStr("en = 'GL account (accounts payable)'"),
																	TypeDescriptionString10, TypeDescriptionColumn);
																	
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "VendorAdvancesGLAccount",
																	NStr("en = 'GL account (vendor advances)'"),
																	TypeDescriptionString10, TypeDescriptionColumn);
		
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "Comment", NStr("en = 'Comment'"),
																	TypeDescriptionString200, TypeDescriptionString200);
		
		TypeDescriptionColumn = New TypeDescription("Boolean");
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "DoOperationsByContracts",
																	NStr("en = 'Accounting by contracts'"),
																	TypeDescriptionString10, TypeDescriptionColumn);
																	
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "DoOperationsByDocuments",
																	NStr("en = 'Accounting by documents'"),
																	TypeDescriptionString10, TypeDescriptionColumn);
																	
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "DoOperationsByOrders",
																	NStr("en = 'Accounting by orders'"),
																	TypeDescriptionString10, TypeDescriptionColumn);

		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "Phone", NStr("en = 'Phone'"),
																	TypeDescriptionString100, TypeDescriptionString100);
																	
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "EMail_Address", NStr("en = 'Email'"),
																	TypeDescriptionString100, TypeDescriptionString100);
		
		TypeDescriptionColumn = New TypeDescription("Boolean");
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "Customer",
																	NStr("en = 'Customer'"),
																	TypeDescriptionString10, TypeDescriptionColumn);
																	
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "Supplier",
																	NStr("en = 'Supplier'"),
																	TypeDescriptionString10, TypeDescriptionColumn);
																	
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "OtherRelationship",
																	NStr("en = 'Other relationship'"),
																	TypeDescriptionString10, TypeDescriptionColumn);
		
		// AdditionalAttributes
		DataImportFromExternalSources.PrepareMapForAdditionalAttributes(DataLoadSettings, Catalogs.AdditionalAttributesAndInformationSets.Catalog_Counterparties);
		If DataLoadSettings.AdditionalAttributeDescription.Count() > 0 Then
			
			FieldName = DataImportFromExternalSources.AdditionalAttributesForAddingFieldsName();
			DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, FieldName,
																		NStr("en = 'Additional attributes'"),
																		TypeDescriptionString150, TypeDescriptionString11, , , , , , True,
																		Catalogs.AdditionalAttributesAndInformationSets.Catalog_Counterparties);
		EndIf;
		
	ElsIf FillingObjectFullName = "Catalog.Products" Then
		
		TypeDescriptionColumn = New TypeDescription("CatalogRef.Products");
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "Parent", NStr("en = 'Group'"),
																	TypeDescriptionString100, TypeDescriptionColumn, , , , );
		
		TypeDescriptionColumn = New TypeDescription("CatalogRef.Products");
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "Code", NStr("en = 'Code'"),
																	TypeDescriptionString11, TypeDescriptionColumn, "Products", 1, , True);
																	
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "Barcode", 	NStr("en = 'Barcode'"),
																	TypeDescriptionString200, TypeDescriptionColumn, "Products", 2, , True);
																	
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "SKU", 	NStr("en = 'Product ID'"),
																	TypeDescriptionString25, TypeDescriptionColumn, "Products", 3, , True);
																	
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "ProductsDescription",
																	NStr("en = 'Product (name)'"),
																	TypeDescriptionString100, TypeDescriptionColumn, "Products", 4, , True);
																	
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "ProductsDescriptionFull",
																	NStr("en = 'Product (full name)'"),
																	TypeDescriptionString1000, TypeDescriptionColumn, "Products", 5, , True);
																	
		TypeDescriptionColumn = New TypeDescription("EnumRef.ProductsTypes");
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "ProductsType",
																	NStr("en = 'Product type'"),
																	TypeDescriptionString11, TypeDescriptionColumn);
		
		TypeDescriptionColumn = New TypeDescription("CatalogRef.UOMClassifier");
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "MeasurementUnit", 
																	NStr("en = 'Unit of measure'"), 
																	TypeDescriptionString25, TypeDescriptionColumn);
		
		TypeDescriptionColumn = New TypeDescription("EnumRef.InventoryValuationMethods");
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "EstimationMethod", 
																	NStr("en = 'Write-off method'"), 
																	TypeDescriptionString25, TypeDescriptionColumn);
		
		TypeDescriptionColumn = New TypeDescription("CatalogRef.LinesOfBusiness");
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "BusinessLine", 
																	NStr("en = 'Line of business'"), 
																	TypeDescriptionString50, TypeDescriptionColumn, , , , ,
																	GetFunctionalOption("AccountingBySeveralLinesOfBusiness"));
		
		TypeDescriptionColumn = New TypeDescription("CatalogRef.ProductsCategories");
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "ProductsCategory", 
																	NStr("en = 'Product category'"), 
																	TypeDescriptionString100, TypeDescriptionColumn);
		
		TypeDescriptionColumn = New TypeDescription("CatalogRef.Counterparties");
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "Vendor", 
																	NStr("en = 'Supplier (TIN or name)'"), 
																	TypeDescriptionString100, TypeDescriptionColumn);
		
		If GetFunctionalOption("UseSerialNumbers") Then
			
			TypeDescriptionColumn = New TypeDescription("Boolean");
			DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "UseSerialNumbers", 
																		NStr("en = 'Use serial numbers'"),
																		TypeDescriptionString25, TypeDescriptionColumn);
			
			TypeDescriptionColumn = New TypeDescription("CatalogRef.SerialNumbers");
			DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "SerialNumber", 
																		NStr("en = 'Serial number'"),
																		TypeDescriptionString150, TypeDescriptionColumn);
			
		EndIf;
		
		TypeDescriptionColumn = New TypeDescription("CatalogRef.BusinessUnits");
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "Warehouse", 
																	NStr("en = 'Warehouse (name)'"), 
																	TypeDescriptionString50, TypeDescriptionColumn);
		
		TypeDescriptionColumn = New TypeDescription("EnumRef.InventoryReplenishmentMethods");
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "ReplenishmentMethod", 
																	NStr("en = 'Replenishment method'"), 
																	TypeDescriptionString50, TypeDescriptionColumn);
		
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "ReplenishmentDeadline", 
																	NStr("en = 'Replenishment deadline'"), 
																	TypeDescriptionString25, TypeDescriptionNumber10_0);
		
		TypeDescriptionColumn = New TypeDescription("CatalogRef.VATRates");
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "VATRate", 
																	NStr("en = 'VAT rate'"), 
																	TypeDescriptionString11, TypeDescriptionColumn);
		
		If GetFunctionalOption("UseStorageBins") Then
			TypeDescriptionColumn = New TypeDescription("CatalogRef.Cells");
			DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "Cell", 
																		NStr("en = 'Bin (name)'"),
																		TypeDescriptionString50, TypeDescriptionColumn);
		EndIf;
		
		TypeDescriptionColumn = New TypeDescription("CatalogRef.PriceGroups");
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "PriceGroup", 
																	NStr("en = 'Price group (name)'"),
																	TypeDescriptionString50, TypeDescriptionColumn);
		
		TypeDescriptionColumn = New TypeDescription("Boolean");
		If GetFunctionalOption("UseCharacteristics") Then
			DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "UseCharacteristics", 
																		NStr("en = 'Use characteristics'"), 
																		TypeDescriptionString25, TypeDescriptionColumn);
		EndIf;
		
		If GetFunctionalOption("UseBatches") Then
			DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "UseBatches", 
																		NStr("en = 'Use batches'"), 
																		TypeDescriptionString25, TypeDescriptionColumn);
		EndIf;
		
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "Comment", 
																	NStr("en = 'Comment'"), 
																	TypeDescriptionString200, TypeDescriptionString200);
		
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "OrderCompletionDeadline",
																	NStr("en = 'Order fulfillment deadline'"), 
																	TypeDescriptionString11, TypeDescriptionNumber10_0);
		
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "TimeNorm", 
																	NStr("en = 'Standard hours'"),
																	TypeDescriptionString25, TypeDescriptionNumber10_3);
		
		TypeDescriptionColumn = New TypeDescription("Boolean");
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "FixedCost", 
																	NStr("en = 'Fixed cost (for works)'"),
																	TypeDescriptionString25, TypeDescriptionColumn);
		
		TypeDescriptionColumn = New TypeDescription("CatalogRef.Countries");
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "CountryOfOrigin", 
																	NStr("en = 'Country of origin (code or name)'"),
																	TypeDescriptionString25, TypeDescriptionColumn);
		
		// AdditionalAttributes
		DataImportFromExternalSources.PrepareMapForAdditionalAttributes(DataLoadSettings, Catalogs.AdditionalAttributesAndInformationSets.Catalog_Products);
		If DataLoadSettings.AdditionalAttributeDescription.Count() > 0 Then
			
			FieldName = DataImportFromExternalSources.AdditionalAttributesForAddingFieldsName();
			DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, FieldName, 
																		NStr("en = 'Additional attributes'"),
																		TypeDescriptionString150, TypeDescriptionString11, , , , , , True,
																		Catalogs.AdditionalAttributesAndInformationSets.Catalog_Products);
			
		EndIf;
		
	ElsIf FillingObjectFullName = "Catalog.BillsOfMaterials.TabularSection.Content" Then
		
		TypeDescriptionColumn = New TypeDescription("EnumRef.BOMLineType");
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "ContentRowType",
																	NStr("en = 'Row type'"),
																	TypeDescriptionString25, TypeDescriptionColumn,,, True);
		
		TypeDescriptionColumn = New TypeDescription("CatalogRef.Products");
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "Barcode",
																	NStr("en = 'Barcode'"),
																	TypeDescriptionString200, TypeDescriptionColumn, "Products", 1, , True);
																	
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "SKU",
																	NStr("en = 'Product ID'"),
																	TypeDescriptionString25, TypeDescriptionColumn, "Products", 2, , True);
																	
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "ProductsDescription",
																	NStr("en = 'Product (description)'"),
																	TypeDescriptionString100, TypeDescriptionColumn, "Products", 3, , True);
																	
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "ProductsDescriptionFull",
																	NStr("en = 'Product (detailed description)'"),
																	TypeDescriptionString1000, TypeDescriptionColumn, "Products", 5, , True);
		
		If GetFunctionalOption("UseCharacteristics") Then
			TypeDescriptionColumn = New TypeDescription("CatalogRef.ProductsCharacteristics");
			DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "Characteristic",
																		NStr("en = 'Characteristic (name)'"),
																		TypeDescriptionString150, TypeDescriptionColumn);
		EndIf;
		
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "Quantity",
																	NStr("en = 'Quantity'"),
																	TypeDescriptionString25, TypeDescriptionNumber15_3, , , True);
		
		TypeDescriptionColumn = New TypeDescription("CatalogRef.UOMClassifier"
									+ ?(GetFunctionalOption("UseSeveralUnitsForProduct"), ", CatalogRef.UOM", ""));
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "MeasurementUnit",
																	NStr("en = 'Unit of measure'"),
																	TypeDescriptionString25, TypeDescriptionColumn);
		
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "CostPercentage",
																	NStr("en = 'Cost share'"),
																	TypeDescriptionString25, TypeDescriptionNumber15_2);
		
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "ProductsQuantity",
																	NStr("en = 'Product quantity'"),
																	TypeDescriptionString25, TypeDescriptionNumber15_3);
		
		TypeDescriptionColumn = New TypeDescription("CatalogRef.BillsOfMaterials");
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "Specification",
																	NStr("en = 'Bill of materials (name)'"),
																	TypeDescriptionString100, TypeDescriptionColumn);
		
	ElsIf FillingObjectFullName = "InformationRegister.Prices" Then
		
		TypeDescriptionColumn = New TypeDescription("CatalogRef.Products");
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "Barcode",
																	NStr("en = 'Barcode'"),
																	TypeDescriptionString200, TypeDescriptionColumn, "Products", 1, , True);
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "SKU",
																	NStr("en = 'Product ID'"),
																	TypeDescriptionString25, TypeDescriptionColumn, "Products", 2, , True);
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "ProductsDescription",
																	NStr("en = 'Product (name)'"),
																	TypeDescriptionString100, TypeDescriptionColumn, "Products", 3, , True);
																	
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "ProductsDescriptionFull",
																	NStr("en = 'Product (full name)'"),
																	TypeDescriptionString1000, TypeDescriptionColumn, "Products", 5, , True);
																	
		If GetFunctionalOption("UseCharacteristics") Then
			TypeDescriptionColumn = New TypeDescription("CatalogRef.ProductsCharacteristics");
			DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "Characteristic",
																		NStr("en = 'Characteristic (name)'"),
																		TypeDescriptionString25, TypeDescriptionColumn);
		EndIf;
		
		TypeDescriptionColumn = New TypeDescription("CatalogRef.UOMClassifier"
									+ ?(GetFunctionalOption("UseSeveralUnitsForProduct"), ", CatalogRef.UOM", ""));
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "MeasurementUnit",
																	NStr("en = 'Unit of measure'"),
																	TypeDescriptionString25, TypeDescriptionColumn,,, True);
		
		TypeDescriptionColumn = New TypeDescription("CatalogRef.PriceTypes");
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "PriceKind",
																	NStr("en = 'Price type (name)'"),
																	TypeDescriptionString100, TypeDescriptionColumn);
		
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "Price",
																	NStr("en = 'Price'"),
																	TypeDescriptionString25, TypeDescriptionNumber15_2, , , True);
		
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "Date",
																	NStr("en = 'Date (start of use)'"),
																	TypeDescriptionString25, TypeDescriptionDate);
		
	ElsIf FillingObjectFullName = "Document.OpeningBalanceEntry.TabularSection.AccountsReceivable" Then
		
		TypeDescriptionColumn = New TypeDescription("CatalogRef.Counterparties");
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "Counterparty",
																	NStr("en = 'Counterparty (TIN or name)'"),
																	TypeDescriptionString100, TypeDescriptionColumn, , , True);
		
		TypeDescriptionColumn = New TypeDescription("CatalogRef.CounterpartyContracts");
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "Contract",
																	NStr("en = 'Counterparty contract (name or number)'"),
																	TypeDescriptionString100, TypeDescriptionColumn);
		
		TypeDescriptionColumn = New TypeDescription("Boolean");
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "AdvanceFlag",
																	NStr("en = 'Is advance?'"),
																	TypeDescriptionString25, TypeDescriptionColumn);
		
		TypeDescriptionColumn = New TypeDescription("DocumentRef.SalesOrder");
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "SalesOrderNumber",
																	NStr("en = 'Sales order number'"),
																	TypeDescriptionString25, TypeDescriptionColumn, "Order");
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "SalesOrderDate",
																	NStr("en = 'Sales order date'"),
																	TypeDescriptionString25, TypeDescriptionColumn, "Order");
		
		TypeArray = New Array;
		TypeArray.Add(Type("DocumentRef.SalesOrder"));
		TypeArray.Add(Type("DocumentRef.ArApAdjustments"));
		TypeArray.Add(Type("DocumentRef.AccountSalesFromConsignee"));
		TypeArray.Add(Type("DocumentRef.SubcontractorReportIssued"));
		TypeArray.Add(Type("DocumentRef.CashReceipt"));
		TypeArray.Add(Type("DocumentRef.PaymentReceipt"));
		TypeArray.Add(Type("DocumentRef.FixedAssetSale"));
		TypeArray.Add(Type("DocumentRef.SalesInvoice"));
		
		TypeDescriptionColumn = New TypeDescription(TypeArray);
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "PaymentDocumentKind",
																	NStr("en = 'Payment document type'"),
																	TypeDescriptionString50, TypeDescriptionColumn, "Document");
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "NumberOfAccountsDocument",
																	NStr("en = 'Payment document number'"),
																	TypeDescriptionString25, TypeDescriptionColumn, "Document");
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "DateAccountingDocument",
																	NStr("en = 'Payment document date'"),
																	TypeDescriptionString25, TypeDescriptionColumn, "Document");
		
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "AmountCur",
																	NStr("en = 'Amount (cur.)'"),
																	TypeDescriptionString25, TypeDescriptionNumber15_2, , , True);
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "Amount",
																	NStr("en = 'Amount'"),
																	TypeDescriptionString25, TypeDescriptionNumber15_2);
		
		TypeDescriptionColumn = New TypeDescription("DocumentRef.Quote");
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "CustomerAccountNo",
																	NStr("en = 'Number of account for payment'"),
																	TypeDescriptionString25, TypeDescriptionColumn, "Account", , , );
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "CustomerAccountDate",
																	NStr("en = 'Date of account for payment'"),
																	TypeDescriptionString25, TypeDescriptionColumn, "Account", , , );
		
	ElsIf FillingObjectFullName = "Document.OpeningBalanceEntry.TabularSection.AccountsPayable" Then
		
		TypeDescriptionColumn = New TypeDescription("CatalogRef.Counterparties");
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "Counterparty",
																	NStr("en = 'Counterparty (TIN or name)'"),
																	TypeDescriptionString100, TypeDescriptionColumn, , , True);
		
		TypeDescriptionColumn = New TypeDescription("CatalogRef.CounterpartyContracts");
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "Contract",
																	NStr("en = 'Counterparty contract (name or number)'"),
																	TypeDescriptionString100, TypeDescriptionColumn);
		
		TypeDescriptionColumn = New TypeDescription("Boolean");
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "AdvanceFlag",
																	NStr("en = 'Is advance?'"),
																	TypeDescriptionString25, TypeDescriptionColumn, , , , False);
		
		TypeDescriptionColumn = New TypeDescription("DocumentRef.PurchaseOrder");
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "PurchaseOrderNumber",
																	NStr("en = 'Purchase order number'"),
																	TypeDescriptionString25, TypeDescriptionColumn, "Order");
																	
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "PurchaseOrderDate",
																	NStr("en = 'Purchase order date'"),
																	TypeDescriptionString25, TypeDescriptionColumn, "Order");
		TypeArray = New Array;
		TypeArray.Add(Type("DocumentRef.ExpenseReport"));
		TypeArray.Add(Type("DocumentRef.AdditionalExpenses"));
		TypeArray.Add(Type("DocumentRef.ArApAdjustments"));
		TypeArray.Add(Type("DocumentRef.AccountSalesToConsignor"));
		TypeArray.Add(Type("DocumentRef.SubcontractorReport"));
		TypeArray.Add(Type("DocumentRef.SupplierInvoice"));
		TypeArray.Add(Type("DocumentRef.CashVoucher"));
		TypeArray.Add(Type("DocumentRef.PaymentExpense"));
		
		TypeDescriptionColumn = New TypeDescription(TypeArray);
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "PaymentDocumentKind",
																	NStr("en = 'Payment document type'"),
																	TypeDescriptionString50, TypeDescriptionColumn, "Document");
																	
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "NumberOfAccountsDocument",
																	NStr("en = 'Payment document number'"),
																	TypeDescriptionString25, TypeDescriptionColumn, "Document");
																	
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "DateAccountingDocument",
																	NStr("en = 'Payment document date'"),
																	TypeDescriptionString25, TypeDescriptionColumn, "Document");
		
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "AmountCur",
																	NStr("en = 'Amount (cur.)'"),
																	TypeDescriptionString25, TypeDescriptionNumber15_2, , , True);
		
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "Amount",
																	NStr("en = 'Amount'"),
																	TypeDescriptionString25, TypeDescriptionNumber15_2);
		
		TypeDescriptionColumn = New TypeDescription("DocumentRef.SupplierQuote");
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "CustomerAccountNo",
																	NStr("en = 'Number of account for payment'"),
																	TypeDescriptionString25, TypeDescriptionString25, "Account");
		
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "CustomerAccountDate",
																	NStr("en = 'Date of account for payment'"),
																	TypeDescriptionString25, TypeDescriptionColumn, "Account");
																	
	ElsIf DataLoadSettings.FillingObjectFullName = "Catalog.Leads" Then
		
		TypeDescriptionString0000 = New TypeDescription("String", , , , New StringQualifiers(0));
		TypeDescriptionColumn = New TypeDescription("CatalogRef.Leads");
		
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "Description",
																	NStr("en = 'Description'"),
																	TypeDescriptionString100, TypeDescriptionColumn, "Lead", 1, True, True);
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "Code",
																	NStr("en = 'Code'"),
																	TypeDescriptionString10, TypeDescriptionColumn, "Lead", 2, , True);
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "Contact1",
																	NStr("en = '(1) Contact (name)'"),
																	TypeDescriptionString0000, TypeDescriptionString0000, "Contact_1", 1, , True);
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "Phone1",
																	NStr("en = '(1) Phone'"),
																	TypeDescriptionString100, TypeDescriptionString100, "Contact_1", 2, , True);
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "Email1",
																	NStr("en = '(1) Email'"),
																	TypeDescriptionString100, TypeDescriptionString100, "Contact_1", 3, , True);
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "Contact2",
																	NStr("en = '(2) Contact (name)'"),
																	TypeDescriptionString0000, TypeDescriptionString0000, "Contact_2", 1, , True);
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "Phone2",
																	NStr("en = '(2) Phone'"),
																	TypeDescriptionString100, TypeDescriptionString100, "Contact_2", 2, , True);
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "Email2",
																	NStr("en = '(2) Email'"),
																	TypeDescriptionString100, TypeDescriptionString100, "Contact_2", 3, , True);
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "Contact3",
																	NStr("en = '(3) Contact (name)'"),
																	TypeDescriptionString0000, TypeDescriptionString0000, "Contact_3", 1, , True);
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "Phone3",
																	NStr("en = '(3) Phone'"),
																	TypeDescriptionString100, TypeDescriptionString100, "Contact_3", 2, , True);
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "Email3",
																	NStr("en = '(3) Email'"),
																	TypeDescriptionString100, TypeDescriptionString100, "Contact_3", 3, , True);
		TypeDescriptionNumber15_0 = New TypeDescription("Number", , , , New NumberQualifiers(15, 0, AllowedSign.Nonnegative));
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "Potential",
																	NStr("en = 'Potential'"),
																	TypeDescriptionString10, TypeDescriptionNumber15_0);
		TypeDescriptionColumn = New TypeDescription("CatalogRef.CustomerAcquisitionChannels");
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "AcquisitionChannel",
																	NStr("en = 'Acquisition channel'"),
																	TypeDescriptionString100, TypeDescriptionColumn);
		TypeDescriptionColumn = New TypeDescription("String");
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "Note",
																	NStr("en = 'Note'"),
																	TypeDescriptionString0000, TypeDescriptionColumn);
		// AdditionalAttributes
		DataImportFromExternalSources.PrepareMapForAdditionalAttributes(DataLoadSettings, Catalogs.AdditionalAttributesAndInformationSets.Catalog_Leads);
		If DataLoadSettings.AdditionalAttributeDescription.Count() > 0 Then
			
			FieldName = DataImportFromExternalSources.AdditionalAttributesForAddingFieldsName();
			DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, FieldName,
																		NStr("en = 'Additional attributes'"),
																		TypeDescriptionString150, TypeDescriptionString11, , , , , , True,
																		Catalogs.AdditionalAttributesAndInformationSets.Catalog_Leads);
		EndIf;																
		
	// Inventory	
	Else  
		If CommonUse.IsObjectAttribute("Products", FilledObject) Then
			TypeDescriptionColumn = New TypeDescription("CatalogRef.Products");
			DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "Barcode",
																		NStr("en = 'Barcode'"),
																		TypeDescriptionString200, TypeDescriptionColumn, "Products", 1, , True);
			
			DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "SKU",
																		NStr("en = 'Product ID'"),
																		TypeDescriptionString25, TypeDescriptionColumn, "Products", 2, , True);
			
			DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "ProductsDescription",
																		NStr("en = 'Product (description)'"),
																		TypeDescriptionString100, TypeDescriptionColumn, "Products", 3, , True);
			
			DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "ProductsDescriptionFull",
																		NStr("en = 'Product(detailed description)'"),
																		TypeDescriptionString1000, TypeDescriptionColumn, "Products", 5, , True);
		EndIf;
		
		If CommonUse.IsObjectAttribute("Characteristic", FilledObject) Then
			If GetFunctionalOption("UseCharacteristics") Then
				TypeDescriptionColumn = New TypeDescription("CatalogRef.ProductsCharacteristics");
				DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "Characteristic",
																			NStr("en = 'Characteristic (name)'"),
																			TypeDescriptionString150, TypeDescriptionColumn);
			EndIf;
		EndIf;
		
		If CommonUse.IsObjectAttribute("Batch", FilledObject) Then
			If GetFunctionalOption("UseBatches") Then
				TypeDescriptionColumn = New TypeDescription("CatalogRef.ProductsBatches");
				DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "Batch",
																			NStr("en = 'Batch (name)'"),
																			TypeDescriptionString100, TypeDescriptionColumn);
			EndIf;
		EndIf;
		
		If CommonUse.IsObjectAttribute("StructuralUnit", FilledObject) Then
			TypeDescriptionColumn = New TypeDescription("CatalogRef.BusinessUnits");
			DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "StructuralUnit",
																		NStr("en = 'Warehouse'"),
																		TypeDescriptionString100, TypeDescriptionColumn);
		EndIf;
		
		If CommonUse.IsObjectAttribute("Cell", FilledObject) Then
			If GetFunctionalOption("UseStorageBins") Then
				DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "Cell",
																			NStr("en = 'Bin (name)'"),
																			TypeDescriptionString50, TypeDescriptionColumn);
			EndIf;
		EndIf;
		
		If GetFunctionalOption("UseSerialNumbers")
			And CommonUse.IsObjectAttribute("SerialNumbers", FilledObject) Then
			
			TypeDescriptionColumn = New TypeDescription("CatalogRef.SerialNumbers");
			DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "SerialNumber", 
																		NStr("en = 'Serial number'"),
																		TypeDescriptionString150, TypeDescriptionColumn);
			
		EndIf;
		
		If CommonUse.IsObjectAttribute("Quantity", FilledObject) Then
			DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "Quantity",
																		NStr("en = 'Quantity'"),
																		TypeDescriptionString25, TypeDescriptionNumber15_3, , , True);
		EndIf;
		
		If CommonUse.IsObjectAttribute("Reserve", FilledObject) Then
				DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "Reserve",
																			NStr("en = 'Reserve'"),
																			TypeDescriptionString25, TypeDescriptionNumber15_3,,,,,
																			GetFunctionalOption("UseInventoryReservation"));
		EndIf;
		
		If CommonUse.IsObjectAttribute("MeasurementUnit", FilledObject) Then
			TypeDescriptionColumn = New TypeDescription("CatalogRef.UOMClassifier"
										+ ?(GetFunctionalOption("UseSeveralUnitsForProduct"), ", CatalogRef.UOM", ""));
			DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "MeasurementUnit",
																		NStr("en = 'Unit of measure'"),
																		TypeDescriptionString25, TypeDescriptionColumn, , , , , GetFunctionalOption("UseSeveralUnitsForProduct"));
		EndIf;
		
		If CommonUse.IsObjectAttribute("Price", FilledObject) Then
			DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "Price",
																		NStr("en = 'Price'"),
																		TypeDescriptionString25, TypeDescriptionNumber15_2, , , True);
		EndIf;
		
		If CommonUse.IsObjectAttribute("Amount", FilledObject) Then
			DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "Amount",
																		NStr("en = 'Amount'"),
																		TypeDescriptionString25, TypeDescriptionNumber15_2);
		EndIf;
		
		If CommonUse.IsObjectAttribute("VATRate", FilledObject) Then
			TypeDescriptionColumn = New TypeDescription("CatalogRef.VATRates");
			DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "VATRate",
																		NStr("en = 'VAT rate'"),
																		TypeDescriptionString50, TypeDescriptionColumn);
		EndIf;
		
		If CommonUse.IsObjectAttribute("VATAmount", FilledObject) Then
			DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "VATAmount",
																		NStr("en = 'VAT amount'"),
																		TypeDescriptionString25, TypeDescriptionNumber15_2);
		EndIf;
		
		If CommonUse.IsObjectAttribute("ReceiptDate", FilledObject) Then
			DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "ReceiptDate",
																		NStr("en = 'Receipt date'"),
																		TypeDescriptionString25, TypeDescriptionDate);
		EndIf;
		
		If CommonUse.IsObjectAttribute("ShipmentDate", FilledObject) Then
			FieldVisible = (DataLoadSettings.DatePositionInOrder = Enums.AttributeStationing.InTabularSection);
			DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "ShipmentDate",
																		NStr("en = 'Shipment date'"),
																		TypeDescriptionString25, TypeDescriptionDate, , , , , FieldVisible);
		EndIf;
		
		If CommonUse.IsObjectAttribute("Order", FilledObject) Then
			
			TypeArray = New Array;
			TypeArray.Add(Type("DocumentRef.SalesOrder"));
			TypeArray.Add(Type("DocumentRef.PurchaseOrder"));
			
			If DataLoadSettings.Property("OrderPositionInDocument") Then
				VisibilityOfSalesOrder = (DataLoadSettings.OrderPositionInDocument = Enums.AttributeStationing.InTabularSection);
			Else
				VisibilityOfSalesOrder = False;
			EndIf;
			
			TypeDescriptionColumn = New TypeDescription(TypeArray);
			DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "Order",
																		NStr("en = 'Order (customer/supplier)'"),
																		TypeDescriptionString50, TypeDescriptionColumn, , , , , VisibilityOfSalesOrder);
			
		EndIf;
		
		If CommonUse.IsObjectAttribute("Specification", FilledObject) Then
			If GetFunctionalOption("UseWorkOrders")
				Or GetFunctionalOption("UseProductionSubsystem") Then
				
				TypeDescriptionColumn = New TypeDescription("CatalogRef.BillsOfMaterials");
				DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "Specification",
																			NStr("en = 'Specification (name)'"),
																			TypeDescriptionString150, TypeDescriptionColumn);
			EndIf;
		EndIf;
		
	EndIf;

EndProcedure

Procedure MatchImportedDataFromExternalSource(DataMatchingTable, DataLoadSettings) Export
	Var Manager;
	
	FillingObjectFullName 	= DataLoadSettings.FillingObjectFullName;
	FilledObject 			= Metadata.FindByFullName(FillingObjectFullName);
	UpdateData 				= DataLoadSettings.UpdateExisting;
	
	// DataMatchingTable - Type FormDataCollection
	For Each FormTableRow In DataMatchingTable Do
		
		If FillingObjectFullName = "Catalog.Counterparties" Then
			
			// Counterparty by TIN, Name, Current account
			MapCounterparty(FormTableRow.Counterparty, FormTableRow.TIN, FormTableRow.CounterpartyDescription, FormTableRow.BankAccount);
			ThisStringIsMapped = ValueIsFilled(FormTableRow.Counterparty);
			
			// Parent by name
			DefaultValue = Catalogs.Counterparties.EmptyRef();
			WhenDefiningDefaultValue(FormTableRow.Counterparty, "Parent", FormTableRow.Parent_IncomingData, ThisStringIsMapped, UpdateData, DefaultValue);
			MapParent("Counterparties", FormTableRow.Parent, FormTableRow.Parent_IncomingData, DefaultValue);
			
			ConvertStringToBoolean(FormTableRow.ThisIsInd, FormTableRow.ThisIsInd_IncomingData);
			If FormTableRow.ThisIsInd Then
				MapIndividualPerson(FormTableRow.Individual, FormTableRow.Individual_IncomingData);
			EndIf;
			
			If GetFunctionalOption("UseCounterpartiesAccessGroups") Then
				MapAccessGroup(FormTableRow.AccessGroup, FormTableRow.AccessGroup_IncomingData);
			EndIf;
			
			// GLAccountCustomerSettlements by code, name
			DefaultValue = Catalogs.DefaultGLAccounts.GetDefaultGLAccount("AccountsReceivable");
			WhenDefiningDefaultValue(FormTableRow.Counterparty, "GLAccountCustomerSettlements", FormTableRow.GLAccountCustomerSettlements_IncomingData, ThisStringIsMapped, UpdateData, DefaultValue);
			MapGLAccountCustomerSettlements(FormTableRow.GLAccountCustomerSettlements, FormTableRow.GLAccountCustomerSettlements_IncomingData, DefaultValue);
			
			// CustomerAdvancesGLAccount by code, name
			DefaultValue = Catalogs.DefaultGLAccounts.GetDefaultGLAccount("CustomerAdvances");
			WhenDefiningDefaultValue(FormTableRow.Counterparty, "CustomerAdvancesGLAccount", FormTableRow.CustomerAdvancesGLAccount_IncomingData, ThisStringIsMapped, UpdateData, DefaultValue);
			MapCustomerAdvancesGLAccount(FormTableRow.CustomerAdvancesGLAccount, FormTableRow.CustomerAdvancesGLAccount_IncomingData, DefaultValue);
			
			// GLAccountCustomerSettlements by code, name
			DefaultValue = Catalogs.DefaultGLAccounts.GetDefaultGLAccount("AccountsPayable");
			WhenDefiningDefaultValue(FormTableRow.Counterparty, "GLAccountVendorSettlements", FormTableRow.GLAccountVendorSettlements_IncomingData, ThisStringIsMapped, UpdateData, DefaultValue);
			MapGLAccountVendorSettlements(FormTableRow.GLAccountVendorSettlements, FormTableRow.GLAccountVendorSettlements_IncomingData, DefaultValue);
			
			// VendorAdvancesGLAccount by code, name
			DefaultValue = Catalogs.DefaultGLAccounts.GetDefaultGLAccount("AdvancesToSuppliers");
			WhenDefiningDefaultValue(FormTableRow.Counterparty, "VendorAdvancesGLAccount", FormTableRow.VendorAdvancesGLAccount_IncomingData, ThisStringIsMapped, UpdateData, DefaultValue);
			MapVendorAdvancesGLAccount(FormTableRow.VendorAdvancesGLAccount, FormTableRow.VendorAdvancesGLAccount_IncomingData, DefaultValue);
			
			// Comment
			CopyRowToStringTypeValue(FormTableRow.Comment, FormTableRow.Comment_IncomingData);
			
			// DoOperationsByContracts
			StringForMatch = ?(IsBlankString(FormTableRow.DoOperationsByContracts_IncomingData), "TRUE", FormTableRow.DoOperationsByContracts_IncomingData);
			ConvertStringToBoolean(FormTableRow.DoOperationsByContracts, StringForMatch);
			
			// DoOperationsByDocuments
			StringForMatch = ?(IsBlankString(FormTableRow.DoOperationsByDocuments_IncomingData), "TRUE", FormTableRow.DoOperationsByDocuments_IncomingData);
			ConvertStringToBoolean(FormTableRow.DoOperationsByDocuments, StringForMatch);
			
			// DoOperationsByOrders
			StringForMatch = ?(IsBlankString(FormTableRow.DoOperationsByOrders_IncomingData), "TRUE", FormTableRow.DoOperationsByOrders_IncomingData);
			ConvertStringToBoolean(FormTableRow.DoOperationsByOrders, StringForMatch);
			
			// Phone
			CopyRowToStringTypeValue(FormTableRow.Phone, FormTableRow.Phone_IncomingData);
			
			// EMail_Address
			CopyRowToStringTypeValue(FormTableRow.EMail_Address, FormTableRow.EMail_Address_IncomingData);
			
			// Customer, Supplier, OtherRelationship
			ConvertStringToBoolean(FormTableRow.Customer,			FormTableRow.Customer_IncomingData);
			ConvertStringToBoolean(FormTableRow.Supplier,			FormTableRow.Supplier_IncomingData);
			ConvertStringToBoolean(FormTableRow.OtherRelationship,	FormTableRow.OtherRelationship_IncomingData);
			
			If Not FormTableRow.Customer
				AND Not FormTableRow.Supplier
				AND Not FormTableRow.OtherRelationship Then
				
				FormTableRow.Customer			= True;
				FormTableRow.Supplier			= True;
				FormTableRow.OtherRelationship	= True;
				
			EndIf;
			
		ElsIf FillingObjectFullName = "Catalog.Products" Then
			
			// Product by Barcode, SKU, Description
			CompareProducts(FormTableRow.Products, FormTableRow.Barcode, FormTableRow.SKU, FormTableRow.ProductsDescription, FormTableRow.ProductsDescriptionFull, FormTableRow.Code);
			ThisStringIsMapped = ValueIsFilled(FormTableRow.Products);
			
			// Parent by name
			DefaultValue = Catalogs.Products.EmptyRef();
			WhenDefiningDefaultValue(FormTableRow.Products, "Parent", FormTableRow.Parent_IncomingData, ThisStringIsMapped, UpdateData, DefaultValue);
			MapParent("Products", FormTableRow.Parent, FormTableRow.Parent_IncomingData, DefaultValue);
			
			// Product type (we can not correct attributes closed for editing)
			If ThisStringIsMapped Then
				FormTableRow.ProductsType = FormTableRow.Products.ProductsType;
			Else
				MapProductsType(FormTableRow.ProductsType, FormTableRow.ProductsType_IncomingData, Enums.ProductsTypes.InventoryItem);
			EndIf;
			
			// MeasurementUnits by Description (also consider the option to bind user MU)
			MapUOM(FormTableRow.Products, FormTableRow.MeasurementUnit, FormTableRow.MeasurementUnit_IncomingData);
			
			// BusinessLine by name
			DefaultValue = Catalogs.LinesOfBusiness.MainLine;
			WhenDefiningDefaultValue(FormTableRow.Products, "BusinessLine", FormTableRow.BusinessLine_IncomingData, ThisStringIsMapped, UpdateData, DefaultValue);
			MapBusinessLine(FormTableRow.BusinessLine, FormTableRow.BusinessLine_IncomingData, DefaultValue);
			
			// ProductsCategory by description
			DefaultValue = Catalogs.ProductsCategories.MainGroup;
			WhenDefiningDefaultValue(FormTableRow.Products, "ProductsCategory", FormTableRow.ProductsCategory_IncomingData, ThisStringIsMapped, UpdateData, DefaultValue);
			MapProductsCategory(FormTableRow.ProductsCategory, FormTableRow.ProductsCategory_IncomingData, DefaultValue);
			
			// Supplier by TIN, Description
			MapSupplier(FormTableRow.Vendor, FormTableRow.Vendor_IncomingData);
			
			// Serial numbers
			If GetFunctionalOption("UseSerialNumbers") Then
				
				ConvertStringToBoolean(FormTableRow.UseSerialNumbers, FormTableRow.UseSerialNumbers_IncomingData);
				FormTableRow.UseSerialNumbers = Not IsBlankString(FormTableRow.SerialNumber_IncomingData);
				
				If ThisStringIsMapped
					AND FormTableRow.UseSerialNumbers Then
					
					MapSerialNumber(FormTableRow.Products, FormTableRow.SerialNumber, FormTableRow.SerialNumber_IncomingData);
					
				EndIf;
				
			EndIf;
			
			// Warehouse by description
			DefaultValue = Catalogs.BusinessUnits.MainWarehouse;
			WhenDefiningDefaultValue(FormTableRow.Products, "Warehouse", FormTableRow.Warehouse_IncomingData, ThisStringIsMapped, UpdateData, DefaultValue);
			MapStructuralUnit(FormTableRow.Warehouse, FormTableRow.Warehouse_IncomingData, DefaultValue);
			
			// ReplenishmentMethod by description
			DefaultValue = Enums.InventoryReplenishmentMethods.Purchase;
			WhenDefiningDefaultValue(FormTableRow.Products, "ReplenishmentMethod", FormTableRow.ReplenishmentMethod_IncomingData, ThisStringIsMapped, UpdateData, DefaultValue);
			MapReplenishmentMethod(FormTableRow.ReplenishmentMethod, FormTableRow.ReplenishmentMethod_IncomingData, DefaultValue);
			
			// ReplenishmentDeadline
			DefaultValue = 1;
			WhenDefiningDefaultValue(FormTableRow.Products, "ReplenishmentDeadline", FormTableRow.ReplenishmentDeadline_IncomingData, ThisStringIsMapped, UpdateData, DefaultValue);
			ConvertRowToNumber(FormTableRow.ReplenishmentDeadline, FormTableRow.ReplenishmentDeadline_IncomingData, DefaultValue);
			
			// VATRate by description
			DefaultValue = InformationRegisters.AccountingPolicy.GetDefaultVATRate(, Catalogs.Companies.MainCompany);
			WhenDefiningDefaultValue(FormTableRow.Products, "VATRate", FormTableRow.VATRate_IncomingData, ThisStringIsMapped, UpdateData, DefaultValue);
			MapVATRate(FormTableRow.VATRate, FormTableRow.VATRate_IncomingData, DefaultValue);
			
			If GetFunctionalOption("UseStorageBins") Then
				
				// Cell by description
				DefaultValue = Catalogs.Cells.EmptyRef();
				WhenDefiningDefaultValue(FormTableRow.Products, "Cell", FormTableRow.Cell_IncomingData, ThisStringIsMapped, UpdateData, DefaultValue);
				MapCell(FormTableRow.Cell, FormTableRow.Cell_IncomingData, DefaultValue);
				
			EndIf;
			
			// PriceGroup by description
			DefaultValue = Catalogs.PriceGroups.EmptyRef();
			WhenDefiningDefaultValue(FormTableRow.Products, "PriceGroup", FormTableRow.PriceGroup_IncomingData, ThisStringIsMapped, UpdateData, DefaultValue);
			MapPriceGroup(FormTableRow.PriceGroup, FormTableRow.PriceGroup_IncomingData, DefaultValue);
			
			// UseCharacteristics
			If GetFunctionalOption("UseCharacteristics") Then
				 ConvertStringToBoolean(FormTableRow.UseCharacteristics, FormTableRow.UseCharacteristics_IncomingData);
			EndIf;
			
			// UseBatches
			If GetFunctionalOption("UseBatches") Then
				ConvertStringToBoolean(FormTableRow.UseBatches, FormTableRow.UseBatches_IncomingData);
			EndIf;
			
			// Comment as string
			CopyRowToStringTypeValue(FormTableRow.Comment, FormTableRow.Comment_IncomingData);
			
			// OrderCompletionDeadline
			DefaultValue = 1;
			WhenDefiningDefaultValue(FormTableRow.Products, "OrderCompletionDeadline", FormTableRow.OrderCompletionDeadline_IncomingData, ThisStringIsMapped, UpdateData, DefaultValue);
			ConvertRowToNumber(FormTableRow.OrderCompletionDeadline, FormTableRow.OrderCompletionDeadline_IncomingData, DefaultValue);
			
			// TimeNorm
			DefaultValue = 0;
			WhenDefiningDefaultValue(FormTableRow.Products, "TimeNorm", FormTableRow.TimeNorm_IncomingData, ThisStringIsMapped, UpdateData, DefaultValue);
			ConvertRowToNumber(FormTableRow.TimeNorm, FormTableRow.TimeNorm_IncomingData, DefaultValue);
			
			// OriginCountry by the code
			DefaultValue = Catalogs.Countries.EmptyRef();
			WhenDefiningDefaultValue(FormTableRow.Products, "CountryOfOrigin", FormTableRow.CountryOfOrigin_IncomingData, ThisStringIsMapped, UpdateData, DefaultValue);
			MapOriginCountry(FormTableRow.CountryOfOrigin, FormTableRow.CountryOfOrigin_IncomingData, DefaultValue);
			
		ElsIf FillingObjectFullName = "Catalog.BillsOfMaterials.TabularSection.Content" Then
			
			// Product by Barcode, SKU, Description
			CompareProducts(FormTableRow.Products, FormTableRow.Barcode, FormTableRow.SKU, FormTableRow.ProductsDescription, FormTableRow.ProductsDescriptionFull);
			
			// StringType by StringType.Description
			MapRowType(FormTableRow.ContentRowType, FormTableRow.ContentRowType_IncomingData, Enums.BOMLineType.Material);
			
			If GetFunctionalOption("UseCharacteristics") Then
				If ValueIsFilled(FormTableRow.Products) Then
					// Characteristic by Owner and Name
					MapCharacteristic(FormTableRow.Characteristic, FormTableRow.Products, FormTableRow.Barcode, FormTableRow.Characteristic_IncomingData);
				EndIf;
			EndIf;
			
			// Quantity
			ConvertRowToNumber(FormTableRow.Quantity, FormTableRow.Quantity_IncomingData);
			
			// UOM by Description 
			MapUOM(FormTableRow.Products, FormTableRow.MeasurementUnit, FormTableRow.MeasurementUnit_IncomingData);
			
			// Cost share
			ConvertRowToNumber(FormTableRow.CostPercentage, FormTableRow.CostPercentage_IncomingData);
			
			// Product quantity
			ConvertRowToNumber(FormTableRow.ProductsQuantity, FormTableRow.ProductsQuantity_IncomingData);
			
			// BillsOfMaterials by owner, description
			MapSpecification(FormTableRow.Specification, FormTableRow.Specification_IncomingData, FormTableRow.Products);
			
		ElsIf FillingObjectFullName = "InformationRegister.Prices" Then
			
			// Product by Barcode, SKU, Description
			CompareProducts(FormTableRow.Products, FormTableRow.Barcode, FormTableRow.SKU, FormTableRow.ProductsDescription, FormTableRow.ProductsDescriptionFull);
			ThisStringIsMapped = ValueIsFilled(FormTableRow.Products);
			
			If GetFunctionalOption("UseCharacteristics") Then
				If ThisStringIsMapped Then
					// Characteristic by Owner and Name
					MapCharacteristic(FormTableRow.Characteristic, FormTableRow.Products, FormTableRow.Barcode, FormTableRow.Characteristic_IncomingData);
				EndIf;
			EndIf;
			
			// MeasurementUnits by Description (also consider the option to bind user MU)
			MapUOM(FormTableRow.Products, FormTableRow.MeasurementUnit, FormTableRow.MeasurementUnit_IncomingData);
			
			// PriceTypes by description
			DefaultValue = Catalogs.Counterparties.GetMainKindOfSalePrices();
			MapPriceKind(FormTableRow.PriceKind, FormTableRow.PriceKind_IncomingData, DefaultValue);
			
			// Price
			ConvertRowToNumber(FormTableRow.Price, FormTableRow.Price_IncomingData);
			
			// Date
			ConvertStringToDate(FormTableRow.Date, FormTableRow.Date_IncomingData);
			If Not ValueIsFilled(FormTableRow.Date) Then
				FormTableRow.Date = BegOfDay(CurrentDate());
			EndIf;
			
		ElsIf FillingObjectFullName = "Document.OpeningBalanceEntry.TabularSection.AccountsReceivable" Then
			
			// Counterparty by TIN, Name
			MapSupplier(FormTableRow.Counterparty, FormTableRow.Counterparty_IncomingData);
			ThisStringIsMapped = ValueIsFilled(FormTableRow.Counterparty);
			
			If ThisStringIsMapped Then
				
				MapContract(FormTableRow.Counterparty, FormTableRow.Contract, FormTableRow.Contract_IncomingData);
				MapOrderByNumberDate(FormTableRow.Order, "SalesOrder", FormTableRow.Counterparty, FormTableRow.SalesOrderNumber, FormTableRow.SalesOrderDate);
				MapAccountingDocumentByNumberDate(FormTableRow.Document, FormTableRow.PaymentDocumentKind, FormTableRow.Counterparty, FormTableRow.NumberOfAccountsDocument, FormTableRow.DateAccountingDocument);
				MapAccountByNumberDate(FormTableRow.Account, FormTableRow.Counterparty, FormTableRow.CustomerAccountNo, FormTableRow.CustomerAccountDate);
				
			EndIf;
			
			ConvertStringToBoolean(FormTableRow.AdvanceFlag, FormTableRow.AdvanceFlag_IncomingData);
			
			ConvertRowToNumber(FormTableRow.AmountCur, FormTableRow.AmountCur_IncomingData);
			ConvertRowToNumber(FormTableRow.Amount, FormTableRow.Amount_IncomingData);
			
		ElsIf FillingObjectFullName = "Document.OpeningBalanceEntry.TabularSection.AccountsPayable" Then
			
			// Counterparty by TIN, Name
			MapSupplier(FormTableRow.Counterparty, FormTableRow.Counterparty_IncomingData);
			ThisStringIsMapped = ValueIsFilled(FormTableRow.Counterparty);
			
			If ThisStringIsMapped Then
				
				MapContract(FormTableRow.Counterparty, FormTableRow.Contract, FormTableRow.Contract_IncomingData);
				MapOrderByNumberDate(FormTableRow.Order, "PurchaseOrder", FormTableRow.Counterparty, FormTableRow.PurchaseOrderNumber, FormTableRow.PurchaseOrderDate);
				MapAccountingDocumentByNumberDate(FormTableRow.Document, FormTableRow.PaymentDocumentKind, FormTableRow.Counterparty, FormTableRow.NumberOfAccountsDocument, FormTableRow.DateAccountingDocument);
				MapAccountByNumberDate(FormTableRow.Account, FormTableRow.Counterparty, FormTableRow.CustomerAccountNo, FormTableRow.CustomerAccountDate);
				
			EndIf;
			
			ConvertStringToBoolean(FormTableRow.AdvanceFlag, FormTableRow.AdvanceFlag_IncomingData);
			
			ConvertRowToNumber(FormTableRow.AmountCur, FormTableRow.AmountCur_IncomingData);
			ConvertRowToNumber(FormTableRow.Amount, FormTableRow.Amount_IncomingData);
			
		ElsIf FillingObjectFullName = "Catalog.Leads" Then
			
			// Lead by Name, Code
			MapLead(FormTableRow.Lead, FormTableRow.Description, FormTableRow.Code);
			ThisStringIsMapped = ValueIsFilled(FormTableRow.Lead);
			
			CopyRowToStringTypeValue(FormTableRow.Contact1, FormTableRow.Contact1);
			CopyRowToStringTypeValue(FormTableRow.Phone1, FormTableRow.Phone1);
			CopyRowToStringTypeValue(FormTableRow.Email1, FormTableRow.Email1);
			
			CopyRowToStringTypeValue(FormTableRow.Contact2, FormTableRow.Contact2);
			CopyRowToStringTypeValue(FormTableRow.Phone2, FormTableRow.Phone2);
			CopyRowToStringTypeValue(FormTableRow.Email2, FormTableRow.Email2);
			
			CopyRowToStringTypeValue(FormTableRow.Contact3, FormTableRow.Contact3);
			CopyRowToStringTypeValue(FormTableRow.Phone3, FormTableRow.Phone3);
			CopyRowToStringTypeValue(FormTableRow.Email3, FormTableRow.Email3);
			
			MapAcquisitionChannel(FormTableRow.AcquisitionChannel, FormTableRow.AcquisitionChannel_IncomingData);
			ConvertRowToNumber(FormTableRow.Potential, FormTableRow.Potential_IncomingData);
			
			CopyRowToStringTypeValue(FormTableRow.Note, FormTableRow.Note);
			
		// Inventory	
		Else
			// Product by Barcode, SKU, Description
			If CommonUse.IsObjectAttribute("Products", FilledObject) Then
				If DataLoadSettings.Property("Supplier") Then
					CompareProducts(FormTableRow.Products,
									FormTableRow.Barcode,
									FormTableRow.SKU,
									FormTableRow.ProductsDescription,
									FormTableRow.ProductsDescriptionFull,
									,
									DataLoadSettings.Supplier)
				Else
					CompareProducts(FormTableRow.Products,
									FormTableRow.Barcode,
									FormTableRow.SKU,
									FormTableRow.ProductsDescription,
									FormTableRow.ProductsDescriptionFull)
				EndIf;
			EndIf;
			
			// Characteristic by Owner and Name
			If CommonUse.IsObjectAttribute("Characteristic", FilledObject) Then
				If GetFunctionalOption("UseCharacteristics") Then
					If ValueIsFilled(FormTableRow.Products) Then
						MapCharacteristic(FormTableRow.Characteristic, FormTableRow.Products, FormTableRow.Barcode, FormTableRow.Characteristic_IncomingData);
					EndIf;
				EndIf;
			EndIf;
			
			// Batch by Owner and Name
			If CommonUse.IsObjectAttribute("Batch", FilledObject) Then
				If GetFunctionalOption("UseBatches") Then
					If ValueIsFilled(FormTableRow.Products) Then
						MapBatch(FormTableRow.Batch, FormTableRow.Products, FormTableRow.Barcode, FormTableRow.Batch_IncomingData);
					EndIf;
				EndIf;
			EndIf;
			
			// business unit
			If CommonUse.IsObjectAttribute("StructuralUnit", FilledObject) Then
				If ValueIsFilled(FormTableRow.Products) Then
					MapStructuralUnit(FormTableRow.StructuralUnit, FormTableRow.StructuralUnit_IncomingData, Catalogs.BusinessUnits.EmptyRef());
				EndIf;
			EndIf;
			
			// Cell by description
			If CommonUse.IsObjectAttribute("StructuralUnit", FilledObject) Then
				If GetFunctionalOption("UseStorageBins") And CommonUse.IsObjectAttribute("Cell", FilledObject) Then
					MapCell(FormTableRow.Cell, FormTableRow.Cell_IncomingData, DefaultValue);
				EndIf;
			EndIf;
			
			// Quantity
			If CommonUse.IsObjectAttribute("Quantity", FilledObject) Then
				ConvertRowToNumber(FormTableRow.Quantity, FormTableRow.Quantity_IncomingData);
			EndIf;
			
			// Reserve
			If CommonUse.IsObjectAttribute("Reserve", FilledObject) Then
				If GetFunctionalOption("UseInventoryReservation") Then
					ConvertRowToNumber(FormTableRow.Reserve, FormTableRow.Reserve_IncomingData, 0);
				EndIf;
			EndIf;
			
			// MeasurementUnits by Description (also consider the option to bind user MU)
			If CommonUse.IsObjectAttribute("MeasurementUnit", FilledObject) Then
				MapUOM(FormTableRow.Products, FormTableRow.MeasurementUnit, FormTableRow.MeasurementUnit_IncomingData);
			EndIf;
			
			// Price
			If CommonUse.IsObjectAttribute("Price", FilledObject) Then
				ConvertRowToNumber(FormTableRow.Price, FormTableRow.Price_IncomingData);
			EndIf;
			
			// Amount
			If CommonUse.IsObjectAttribute("Amount", FilledObject) Then
				ConvertRowToNumber(FormTableRow.Amount, FormTableRow.Amount_IncomingData);
			EndIf;
			
			// VATRate
			If CommonUse.IsObjectAttribute("VATRate", FilledObject) Then
				MapVATRate(FormTableRow.VATRate, FormTableRow.VATRate_IncomingData, Undefined);
			EndIf;
			
			// VATAmount
			If CommonUse.IsObjectAttribute("VATAmount", FilledObject) Then
				ConvertRowToNumber(FormTableRow.VATAmount, FormTableRow.VATAmount_IncomingData, 0);
			EndIf;
			
			// ReceiptDate
			If CommonUse.IsObjectAttribute("ReceiptDate", FilledObject) Then
				ConvertStringToDate(FormTableRow.ReceiptDate, FormTableRow.ReceiptDate_IncomingData);
			EndIf;
			
			// Order
			If CommonUse.IsObjectAttribute("Order", FilledObject) Then
				MatchOrder(FormTableRow.Order, FormTableRow.Order_IncomingData);
			EndIf;
			
			If GetFunctionalOption("UseSerialNumbers") Then
				If ValueIsFilled(FormTableRow.SerialNumber_IncomingData) Then
					MapSerialNumber(FormTableRow.Products, FormTableRow.SerialNumber, FormTableRow.SerialNumber_IncomingData);
				EndIf;
			EndIf;
			
			// Specification
			If CommonUse.IsObjectAttribute("Specification", FilledObject) Then
				If GetFunctionalOption("UseWorkOrders")
					Or GetFunctionalOption("UseProductionSubsystem") Then
					
					If ValueIsFilled(FormTableRow.Products) Then
						MapSpecification(FormTableRow.Specification, FormTableRow.Specification_IncomingData, FormTableRow.Products);
					EndIf;
					
				EndIf;
			EndIf;
		EndIf;
		
		// Additional attributes		
		If DataLoadSettings.Property("SelectedAdditionalAttributes") AND DataLoadSettings.SelectedAdditionalAttributes.Count() > 0 Then
			MapAdditionalAttributes(FormTableRow, DataLoadSettings.SelectedAdditionalAttributes);
		EndIf;
		
		CheckDataCorrectnessInTableRow(FormTableRow, FillingObjectFullName);
		
	EndDo;
	
EndProcedure

Procedure WhenDefiningDefaultValue(CatalogRef, AttributeName, IncomingData, RowMatched, UpdateData, DefaultValue)
	
	If RowMatched 
		AND Not ValueIsFilled(IncomingData) Then
		
		DefaultValue = CatalogRef[AttributeName];
		
	EndIf;
	
EndProcedure

Procedure CheckDataCorrectnessInTableRow(FormTableRow, FillingObjectFullName = "") Export
	
	FilledObject 		= Metadata.FindByFullName(FillingObjectFullName);
	ServiceFieldName	= DataImportFromExternalSources.ServiceFieldNameImportToApplicationPossible();
	
	If FillingObjectFullName = "Catalog.Counterparties" Then 
		
		FormTableRow._RowMatched = ValueIsFilled(FormTableRow.Counterparty);
		FormTableRow[ServiceFieldName] = FormTableRow._RowMatched
		OR (NOT FormTableRow._RowMatched AND Not IsBlankString(FormTableRow.CounterpartyDescription));
		
	ElsIf FillingObjectFullName = "Catalog.Products" Then
		
		FormTableRow._RowMatched = ValueIsFilled(FormTableRow.Products);
		FormTableRow[ServiceFieldName] = FormTableRow._RowMatched
		OR (NOT FormTableRow._RowMatched AND Not IsBlankString(FormTableRow.ProductsDescription));
		
	ElsIf FillingObjectFullName = "Catalog.BillsOfMaterials.TabularSection.Content" Then
		
		FormTableRow[ServiceFieldName] = ValueIsFilled(FormTableRow.Products) 
		AND  ValueIsFilled(FormTableRow.ContentRowType) 
		AND FormTableRow.Quantity <> 0;
		
	ElsIf FillingObjectFullName = "InformationRegister.Prices" Then
		
		FormTableRow[ServiceFieldName] = ValueIsFilled(FormTableRow.PriceKind)
		AND Not FormTableRow.PriceKind.CalculatesDynamically
		AND ValueIsFilled(FormTableRow.Products)
		AND FormTableRow.Price > 0
		AND ValueIsFilled(FormTableRow.MeasurementUnit)
		AND ValueIsFilled(FormTableRow.Date);
		
		If FormTableRow[ServiceFieldName] Then
			
			RecordSet = InformationRegisters.Prices.CreateRecordSet();
			RecordSet.Filter.Period.Set(BegOfDay(FormTableRow.Date));
			RecordSet.Filter.PriceKind.Set(FormTableRow.PriceKind);
			RecordSet.Filter.Products.Set(FormTableRow.Products);
			
			If GetFunctionalOption("UseCharacteristics") Then
				
				RecordSet.Filter.Characteristic.Set(FormTableRow.Characteristic);
				
			EndIf;
			
			RecordSet.Read();
			
			FormTableRow._RowMatched = (RecordSet.Count() > 0);
			
		EndIf;
		
	ElsIf FillingObjectFullName = "Document.OpeningBalanceEntry.TabularSection.AccountsReceivable" 
		OR FillingObjectFullName = "Document.OpeningBalanceEntry.TabularSection.AccountsPayable" Then
		
		FormTableRow[ServiceFieldName] = ValueIsFilled(FormTableRow.Counterparty)
		AND FormTableRow.AmountCur <> 0;
		
	ElsIf FillingObjectFullName = "Document.SupplierInvoice.TabularSection.Expenses" Then
		FormTableRow[ServiceFieldName] = ValueIsFilled(FormTableRow.Products)
			AND FormTableRow.Products.ProductsType = Enums.ProductsTypes.Service
			AND FormTableRow.Quantity <> 0
			AND FormTableRow.Price <> 0;
		
	ElsIf FillingObjectFullName = "Catalog.Leads" Then 
		
		FormTableRow._RowMatched = ValueIsFilled(FormTableRow.Lead);
		FormTableRow[ServiceFieldName] = FormTableRow._RowMatched
			OR (NOT FormTableRow._RowMatched AND Not IsBlankString(FormTableRow.Description));
	// Inventory	
	Else 
		
		ThisIsExpenses		= (FillingObjectFullName = "Document.SupplierInvoice.TabularSection.Expenses");
		ServicesAvailable	= (FillingObjectFullName = "Document.SalesOrder.TabularSection.Inventory") 
								OR (FillingObjectFullName = "Document.SalesInvoice.TabularSection.Inventory")
								OR (FillingObjectFullName = "Document.PurchaseOrder.TabularSection.Inventory");
		
		FormTableRow[ServiceFieldName] = ValueIsFilled(FormTableRow.Products)
		AND (?(NOT ThisIsExpenses, FormTableRow.Products.ProductsType = Enums.ProductsTypes.InventoryItem, False)
		OR ?(ServicesAvailable, FormTableRow.Products.ProductsType = Enums.ProductsTypes.Service, False))
		AND ?(FormTableRow.Property("Quantity"), FormTableRow.Quantity <> 0, True)
		AND ?(FormTableRow.Property("Price"), FormTableRow.Price <> 0, True);
		
	EndIf;
	
EndProcedure

Procedure ImportDataFromExternalSourceResultDataProcessor(ImportResult, Object = Undefined, CurrentForm = Undefined) Export
	
	Try
		
		BeginTransaction();
		
		DataMatchingTable 		= ImportResult.DataMatchingTable;
		UpdateExisting 			= ImportResult.DataLoadSettings.UpdateExisting;
		CreateIfNotMatched 		= ImportResult.DataLoadSettings.CreateIfNotMatched;
		FillingObjectFullName	= ImportResult.DataLoadSettings.FillingObjectFullName;
		
		For Each TableRow In DataMatchingTable Do
			
			ImportToApplicationIsPossible = TableRow[DataImportFromExternalSources.ServiceFieldNameImportToApplicationPossible()];
			
			If FillingObjectFullName = "Catalog.Counterparties" Then 
				
				CoordinatedStringStatus = (TableRow._RowMatched AND UpdateExisting) 
				OR (NOT TableRow._RowMatched AND CreateIfNotMatched);
				
				If ImportToApplicationIsPossible AND CoordinatedStringStatus Then
					
					If TableRow._RowMatched Then
						CatalogItem			= TableRow.Counterparty.GetObject();
					Else
						CatalogItem 		= Catalogs.Counterparties.CreateItem();
						CatalogItem.Parent	= TableRow.Parent;
					EndIf;
					
					CatalogItem.Description 	= TableRow.CounterpartyDescription;
					CatalogItem.DescriptionFull	= TableRow.CounterpartyDescription;
					FillPropertyValues(CatalogItem, TableRow, , "Parent");
					
					CatalogItem.LegalEntityIndividual = ?(TableRow.ThisIsInd, Enums.CounterpartyType.Individual, Enums.CounterpartyType.LegalEntity);
					
					If Not IsBlankString(TableRow.TIN) Then
						
						Separators = New Array;
						Separators.Add("/");
						Separators.Add("\");
						Separators.Add("-");
						Separators.Add("|");
						
						TIN = "";
						
						For Each SeparatorValue In Separators Do
							
							SeparatorPosition = Find(TableRow.TIN, SeparatorValue);
							If SeparatorPosition = 0 Then 
								Continue;
							EndIf;
							
							TIN = Left(TableRow.TIN, SeparatorPosition - 1);
							
						EndDo;
						
						If IsBlankString(TIN) Then
							TIN = TableRow.TIN;
						EndIf;
						
						CatalogItem.TIN = TIN;
						
					EndIf;
					
					If Not IsBlankString(TableRow.Phone) Then
						PhoneStructure = New Structure("Presentation, Comment", TableRow.Phone,
							NStr("en = 'Imported from external source'"));
						ContactInformationManagement.FillObjectContactInformation(CatalogItem, Catalogs.ContactInformationTypes.CounterpartyPhone, PhoneStructure);
					EndIf;
					
					If Not IsBlankString(TableRow.EMail_Address) Then
						StructureEmail = New Structure("Presentation", TableRow.EMail_Address);
						ContactInformationManagement.FillObjectContactInformation(CatalogItem, Catalogs.ContactInformationTypes.CounterpartyEmail, StructureEmail);
					EndIf;
					
					If ImportResult.DataLoadSettings.SelectedAdditionalAttributes.Count() > 0 Then
						DataImportFromExternalSources.ProcessSelectedAdditionalAttributes(CatalogItem, TableRow._RowMatched, TableRow, ImportResult.DataLoadSettings.SelectedAdditionalAttributes);
					EndIf;
					
					CatalogItem.Write();
				EndIf;
				
			ElsIf FillingObjectFullName = "Catalog.Products" Then
				
				CoordinatedStringStatus = (TableRow._RowMatched AND UpdateExisting) 
				OR (NOT TableRow._RowMatched AND CreateIfNotMatched);
				
				If ImportToApplicationIsPossible AND CoordinatedStringStatus Then
					
					If TableRow._RowMatched Then
						CatalogItem 			= TableRow.Products.GetObject();
					Else
						CatalogItem 			= Catalogs.Products.CreateItem();
						CatalogItem.Parent 		= TableRow.Parent;
					EndIf;
					
					CatalogItem.Description 	= TableRow.ProductsDescription;
					CatalogItem.DescriptionFull = ?(ValueIsFilled(TableRow.ProductsDescriptionFull),
					TableRow.ProductsDescriptionFull,
					TableRow.ProductsDescription);
					FillPropertyValues(CatalogItem, TableRow, , "Code, Parent");
					
					If ImportResult.DataLoadSettings.SelectedAdditionalAttributes.Count() > 0 Then
						DataImportFromExternalSources.ProcessSelectedAdditionalAttributes(CatalogItem, TableRow._RowMatched, TableRow, ImportResult.DataLoadSettings.SelectedAdditionalAttributes);
					EndIf;
					
					CatalogItem.Write();
				EndIf;
				
			ElsIf FillingObjectFullName = "InformationRegister.Prices" Then
				
				CoordinatedStringStatus = (TableRow._RowMatched AND UpdateExisting) 
				OR (NOT TableRow._RowMatched AND CreateIfNotMatched);
				
				If ImportToApplicationIsPossible AND CoordinatedStringStatus Then
					
					RecordManager 						= InformationRegisters.Prices.CreateRecordManager();
					RecordManager.Actuality				= True;
					RecordManager.PriceKind				= TableRow.PriceKind;
					RecordManager.MeasurementUnit 		= TableRow.MeasurementUnit;
					RecordManager.Products	= TableRow.Products;
					RecordManager.Period				= TableRow.Date;
					
					If GetFunctionalOption("UseCharacteristics") Then
						RecordManager.Characteristic	= TableRow.Characteristic;
					EndIf;
					
					RecordManager.Price					= TableRow.Price;
					RecordManager.Author				= Users.AuthorizedUser();
					RecordManager.Write(True);
					
				EndIf;
				
			ElsIf FillingObjectFullName = "Document.OpeningBalanceEntry.TabularSection.AccountsReceivable" 
				OR FillingObjectFullName = "Document.OpeningBalanceEntry.TabularSection.AccountsPayable" Then
				
				If ImportToApplicationIsPossible Then
					
					If FillingObjectFullName = "Document.OpeningBalanceEntry.TabularSection.AccountsReceivable" Then
						TabularSectionName = "AccountsReceivable";
					Else 
						TabularSectionName = "AccountsPayable";
					EndIf;
					
					NewRow = Object[TabularSectionName].Add();
					FillPropertyValues(NewRow, TableRow, "Counterparty, Contract, AdvanceFlag, AmountCur, Amount", );
			
					
					StructureData = GetDataCounterparty(Object, NewRow.Counterparty, TabularSectionName, CurrentForm);
					If Not ValueIsFilled(NewRow.Contract) Then
						NewRow.Contract = StructureData.Contract;
					EndIf;
					
					NewRow.DoOperationsByContracts = StructureData.DoOperationsByContracts;
					NewRow.DoOperationsByDocuments = StructureData.DoOperationsByDocuments;
					NewRow.DoOperationsByOrders = StructureData.DoOperationsByOrders;
					
					NewRow.Amount = DriveServer.RecalculateFromCurrencyToAccountingCurrency(NewRow.AmountCur,
																									StructureData.SettlementsCurrency,
																									Object.Date);
					If NewRow.DoOperationsByOrders Then
						If TabularSectionName = "AccountsReceivable" Then
							NewRow.SalesOrder = TableRow.Order;
						Else
							NewRow.PurchaseOrder = TableRow.Order;
						EndIf;
					EndIf;
					
					If NewRow.DoOperationsByDocuments Then
						NewRow.Document = TableRow.Document;
					EndIf;
					
				EndIf;
				
			Else 
				
				If ImportToApplicationIsPossible Then
					
					TabularSectionName = Metadata.FindByFullName(FillingObjectFullName).Name;
					NewRow = Object[TabularSectionName].Add();
					
					PropertyNames = "";
					
					If NewRow.Property("Products") Then
						PropertyNames = PropertyNames + ?(PropertyNames = "", "Products", ", Products");
					EndIf;
					
					If NewRow.Property("Quantity") Then
						PropertyNames = PropertyNames + ", Quantity";
					EndIf;
					
					If NewRow.Property("Reserve") Then
						PropertyNames = PropertyNames + ", Reserve";
					EndIf;
					
					If NewRow.Property("MeasurementUnit") Then
						PropertyNames = PropertyNames + ", MeasurementUnit";
					EndIf;
					
					If NewRow.Property("VATRate") Then
						PropertyNames = PropertyNames + ", VATRate";
					EndIf;
					
					If NewRow.Property("Order") Then
						PropertyNames = PropertyNames + ", Order";
					EndIf;

					If NewRow.Property("Characteristic")
						AND TableRow.Property("Characteristic") Then
						PropertyNames = PropertyNames + ", Characteristic";
					EndIf;
					
					If NewRow.Property("UseBatches") Then
						If NewRow.Property("Batch") Then
							PropertyNames = PropertyNames + ", Batch";
						EndIf;
					EndIf;
					
					If NewRow.Property("StructuralUnit") Then
						PropertyNames = PropertyNames + ", StructuralUnit";
					EndIf;
					
					If NewRow.Property("Specification") Then
						If GetFunctionalOption("UseWorkOrders")
							Or GetFunctionalOption("UseProductionSubsystem") Then
							
							PropertyNames = PropertyNames + ", Specification";
							
						EndIf;
					EndIf;
					
					If NewRow.Property("Order") Then
						PropertyNames = PropertyNames + ", Order";
					EndIf;
					
					If NewRow.Property("ReceiptDate") Then
						PropertyNames = PropertyNames + ", ReceiptDate";
					EndIf;
					
					If NewRow.Property("ShipmentDate") Then
						PropertyNames = PropertyNames + ", ShipmentDate";
					EndIf;
					
					If NewRow.Property("ContentRowType") Then
						PropertyNames = PropertyNames + ", ContentRowType";
					EndIf;
					
					If NewRow.Property("ProductsQuantity") Then
						PropertyNames = PropertyNames + ", ProductsQuantity";
					EndIf;
					
					If NewRow.Property("CostPercentage") Then
						PropertyNames = PropertyNames + ", CostPercentage";
					EndIf;
					If NewRow.Property("ProductsTypeInventory") Then
						NewRow.ProductsTypeInventory = (NewRow.Products.ProductsType = Enums.ProductsTypes.InventoryItem);
					EndIf;
					
					If NewRow.Property("Price") Then
						NewRow.Price = TableRow.Price;
					EndIf;
					
					If NewRow.Property("Amount")
						AND NewRow.Property("Price")
						AND NewRow.Property("Quantity") Then
						
						NewRow.Amount = TableRow.Price * TableRow.Quantity;
					EndIf;
					
					If Object.Property("VATTaxation")
						AND NewRow.Property("VATRate")
						AND NewRow.Property("VATAmount") Then
						
						If Object.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then
							
							DefaultVATRate = InformationRegisters.AccountingPolicy.GetDefaultVATRate(, Object.Company);
							
							If Not ValueIsFilled(NewRow.VATRate) Then
								NewRow.VATRate = ?(ValueIsFilled(NewRow.Products.VATRate), NewRow.Products.VATRate, DefaultVATRate);
							EndIf;
							
							If ValueIsFilled(TableRow.VATAmount) Then
								NewRow.VATAmount = TableRow.VATAmount;
							Else
								VATRate = DriveReUse.GetVATRateValue(NewRow.VATRate);
								
								NewRow.VATAmount = ?(Object.AmountIncludesVAT, 
								NewRow.Amount - (NewRow.Amount) / ((VATRate + 100) / 100),
								NewRow.Amount * VATRate / 100);
							EndIf;
							
						Else
							NewRow.VATRate = ?(Object.VATTaxation = Enums.VATTaxationTypes.NotSubjectToVAT,
							Catalogs.VATRates.Exempt,
							Catalogs.VATRates.ZeroRate);
							
							NewRow.VATAmount = 0;
						EndIf;
					EndIf;
					
					If NewRow.Property("Total")
						AND NewRow.Property("Amount")
						AND NewRow.Property("VATAmount")
						AND Object.Property("AmountIncludesVAT") Then
						
						NewRow.Total = NewRow.Amount + ?(Object.AmountIncludesVAT, 0, NewRow.VATAmount);
					EndIf;
					
					If NewRow.Property("SerialNumbers")
						And TableRow.Property("SerialNumber")
						And ValueIsFilled(TableRow.SerialNumber)
						And Object.Property("SerialNumbers")
						And NewRow.Property("ConnectionKey") Then
						
						WorkWithSerialNumbersClientServer.FillConnectionKey(Object[TabularSectionName], NewRow, "ConnectionKey");
						
						NewRow.SerialNumbers = TableRow.SerialNumber_IncomingData;
						
						SNNewRow = Object.SerialNumbers.Add();
						SNNewRow.ConnectionKey = NewRow.ConnectionKey;
						SNNewRow.SerialNumber = TableRow.SerialNumber;
						
					EndIf;
					
					FillPropertyValues(NewRow, TableRow, PropertyNames);
					
				EndIf;
			EndIf;
		EndDo;
		
		CommitTransaction();
		
	Except
		
		WriteLogEvent(
			NStr("en = 'Data Import'", CommonUseClientServer.MainLanguageCode()),
			EventLogLevel.Error,
			Metadata.Catalogs.Products,
			,
			ErrorDescription());
			
		RollbackTransaction();
	EndTry;
	
EndProcedure

// Procedure sets visible of calculation attributes depending on the parameters specified to the counterparty.
//
Procedure SetAccountsAttributesVisible(Object, CurrentForm = Undefined, Val DoOperationsByContracts = False, Val DoOperationsByDocuments = False, Val DoOperationsByOrders = False, TabularSectionName)
	
	If CurrentForm.FormName = "Document.OpeningBalanceEntry.Form.DocumentForm" Then
		ThisIsWizard = False;
	Else
		ThisIsWizard = True;
	EndIf;
	
	FillServiceAttributesByCounterpartyInCollection(Object[TabularSectionName]);
	
	For Each CurRow In Object[TabularSectionName] Do
		If CurRow.DoOperationsByContracts Then
			DoOperationsByContracts = True;
		EndIf;
		If CurRow.DoOperationsByDocuments Then
			DoOperationsByDocuments = True;
		EndIf;
		If CurRow.DoOperationsByOrders Then
			DoOperationsByOrders = True;
		EndIf;
	EndDo;
	
	If TabularSectionName = "AccountsPayable" Then
		CurrentForm.Items[?(ThisIsWizard, "OpeningBalanceEntryCounterpartiesSettlements", "")+ "AccountsPayableContract"].Visible = DoOperationsByContracts;
		CurrentForm.Items[?(ThisIsWizard, "OpeningBalanceEntryCounterpartiesSettlements", "")+ "AccountsPayableDocument"].Visible = DoOperationsByDocuments;
		CurrentForm.Items[?(ThisIsWizard, "OpeningBalanceEntryCounterpartiesSettlements", "")+ "AccountsPayablePurchaseOrder"].Visible = DoOperationsByOrders;
	ElsIf TabularSectionName = "AccountsReceivable" Then
		CurrentForm.Items[?(ThisIsWizard, "OpeningBalanceEntryCounterpartiesSettlementsAccountsReceivableContract", "AccountsReceivableAgreement")].Visible = DoOperationsByContracts;
		CurrentForm.Items[?(ThisIsWizard, "OpeningBalanceEntryCounterpartiesSettlements", "")+ "AccountsReceivableDocument"].Visible = DoOperationsByDocuments;
		CurrentForm.Items[?(ThisIsWizard, "OpeningBalanceEntryCounterpartiesSettlements", "")+ "AccountsReceivableSalesOrder"].Visible = DoOperationsByOrders;
	ElsIf TabularSectionName = "StockTransferredToThirdParties" Then
		CurrentForm.Items.StockTransferredToThirdPartiesContract.Visible = DoOperationsByContracts;
	ElsIf TabularSectionName = "StockReceivedFromThirdParties" Then
		CurrentForm.Items.StockReceivedFromThirdPartiesContract.Visible = DoOperationsByContracts;
	EndIf;
	
EndProcedure

Procedure FillServiceAttributesByCounterpartyInCollection(DataCollection)
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	CAST(Table.LineNumber AS NUMBER) AS LineNumber,
	|	Table.Counterparty AS Counterparty
	|INTO TableOfCounterparty
	|FROM
	|	&DataCollection AS Table
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableOfCounterparty.Counterparty.DoOperationsByContracts AS DoOperationsByContracts,
	|	TableOfCounterparty.Counterparty.DoOperationsByDocuments AS DoOperationsByDocuments,
	|	TableOfCounterparty.Counterparty.DoOperationsByOrders AS DoOperationsByOrders
	|FROM
	|	TableOfCounterparty AS TableOfCounterparty";
	
	Query.SetParameter("DataCollection", DataCollection.Unload( ,"LineNumber, Counterparty"));
	
	Selection = Query.Execute().Select();
	For Ct = 0 To DataCollection.Count() - 1 Do
		Selection.Next(); // Number of rows in the query selection always equals to the number of rows in the collection
		FillPropertyValues(DataCollection[Ct], Selection, "DoOperationsByContracts, DoOperationsByDocuments, DoOperationsByOrders");
	EndDo;
	
EndProcedure

Function GetContractByDefault(Document, Counterparty, Company, TabularSectionName, OperationKind = Undefined)
	
	If Not Counterparty.DoOperationsByContracts Then
		Return Counterparty.ContractByDefault;
	EndIf;
	
	If (TabularSectionName = "StockTransferredToThirdParties"
		OR TabularSectionName = "StockReceivedFromThirdParties")
		AND Not ValueIsFilled(OperationKind) Then
		
		Return Catalogs.CounterpartyContracts.EmptyRef();
	EndIf;
	
	ManagerOfCatalog = Catalogs.CounterpartyContracts;
	
	ContractTypesList = ManagerOfCatalog.GetContractKindsListForDocument(Document, OperationKind, TabularSectionName);
	ContractByDefault = ManagerOfCatalog.GetDefaultContractByCompanyContractKind(Counterparty, Company, ContractTypesList);
	
	Return ContractByDefault;
	
EndFunction

// It receives data set from the server for the CounterpartyOnChange procedure.
//
Function GetDataCounterparty(Object, Counterparty, TabularSectionName, CurrentForm = Undefined, OperationKind = Undefined)
	
	ContractByDefault = GetContractByDefault(Object, Counterparty, TabularSectionName, OperationKind);
	
	StructureData = New Structure();
	
	StructureData.Insert(
		"Contract",
		ContractByDefault);
	
	StructureData.Insert(
		"SettlementsCurrency",
		ContractByDefault.SettlementsCurrency);
	
	StructureData.Insert("DoOperationsByContracts", Counterparty.DoOperationsByContracts);
	StructureData.Insert("DoOperationsByDocuments", Counterparty.DoOperationsByDocuments);
	StructureData.Insert("DoOperationsByOrders", Counterparty.DoOperationsByOrders);
	
	SetAccountsAttributesVisible(
		Object.Ref,
		CurrentForm,
		Counterparty.DoOperationsByContracts,
		Counterparty.DoOperationsByDocuments,
		Counterparty.DoOperationsByOrders,
		TabularSectionName
	);
	
	Return StructureData;
	
EndFunction

Function DefaultPriceKind() Export
	
	Return Catalogs.Counterparties.GetMainKindOfSalePrices();
	
EndFunction

Function NotUpdatableStandardFieldNames() Export
	
	Return
	"TIN
	|CounterpartyDescription
	|ProductsDescription
	|ProductsFullDescription
	|BankAccount
	|Parent
	|PhoneNumber
	|SerialNumber
	|Barcode"
	
EndFunction

#Region ComparisonMethods

// :::Common

Procedure CatalogByName(CatalogName, CatalogValue, CatalogDescription, DefaultValue = Undefined)
	
	If Not IsBlankString(CatalogDescription) Then
		
		CatalogRef = Catalogs[CatalogName].FindByDescription(CatalogDescription, False);
		If ValueIsFilled(CatalogRef) Then
			
			CatalogValue = CatalogRef;
			
		EndIf;
		
	EndIf;
	
	If Not ValueIsFilled(CatalogValue) Then
		
		CatalogValue = DefaultValue;
		
	EndIf;
	
EndProcedure

Procedure MapEnumeration(EnumerationName, EnumValue, IncomingData, DefaultValue)
	
	If ValueIsFilled(IncomingData) Then
		
		For Each EnumerationItem In Metadata.Enums[EnumerationName].EnumValues Do
			
			Synonym = EnumerationItem.Synonym;
			If Find(Upper(Synonym), Upper(IncomingData)) > 0 Then
				
				EnumValue = Enums[EnumerationName][EnumerationItem.Name];
				Break;
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
	If Not ValueIsFilled(EnumValue) Then
		
		EnumValue = DefaultValue;
		
	EndIf;
	
EndProcedure

Procedure MapGLAccount(GLAccount, GLAccount_IncomingData, DefaultValue)
	
	If Not IsBlankString(GLAccount_IncomingData) Then
		
		FoundGLAccount = ChartsOfAccounts.PrimaryChartOfAccounts.FindByCode(GLAccount_IncomingData);
		If FoundGLAccount = Undefined Then
			
			FoundGLAccount = ChartsOfAccounts.PrimaryChartOfAccounts.FindByDescription(GLAccount_IncomingData);
			
		EndIf;
		
		If ValueIsFilled(FoundGLAccount) Then
			
			GLAccount = FoundGLAccount
			
		EndIf;
		
	EndIf;
	
	If Not ValueIsFilled(GLAccount) Then
		
		GLAccount = DefaultValue;
		
	EndIf;
	
EndProcedure

Procedure ConvertStringToBoolean(ValueBoolean, IncomingData) Export
	
	IncomingData = UPPER(TrimAll(IncomingData));
	
	Array = New Array;
	Array.Add("+");
	Array.Add("1");
	Array.Add("TRUE");
	Array.Add("Yes");
	Array.Add("TRUE");
	Array.Add("YES");
	
	ValueBoolean = (Array.Find(IncomingData) <> Undefined);
	
EndProcedure

Procedure ConvertRowToNumber(NumberResult, NumberByString, DefaultValue = 0) Export
	
	If IsBlankString(NumberByString) Then
		
		NumberResult = DefaultValue;
		Return;
		
	EndIf;
	
	NumberStringCopy = StrReplace(NumberByString, ".", "");
	NumberStringCopy = StrReplace(NumberStringCopy, ",", "");
	NumberStringCopy = StrReplace(NumberStringCopy, Char(32), "");
	NumberStringCopy = StrReplace(NumberStringCopy, Char(160), "");
	If StringFunctionsClientServer.OnlyNumbersInString(NumberStringCopy) Then
		
		NumberStringCopy = StrReplace(NumberByString, " ", "");
		Try // through try, for example, in case of several points in the expression
			
			NumberResult = Number(NumberStringCopy);
			
		Except
			
			NumberResult = 0; // If trash was sent, then zero
			
		EndTry;
		
	Else
		
		NumberResult = 0; // If trash was sent, then zero
		
	EndIf;
	
EndProcedure

Procedure ConvertStringToDate(DateResult, DateString) Export
	
	If IsBlankString(DateString) Then
		
		DateResult = Date(0001, 01, 01);
		
	Else
		
		CopyDateString = DateString;
		
		DelimitersArray = New Array;
		DelimitersArray.Add(".");
		DelimitersArray.Add("/");
		
		For Each Delimiter In DelimitersArray Do
			
			NumberByString = "";
			MonthString = "";
			YearString = "";
			
			SeparatorPosition = Find(CopyDateString, Delimiter);
			If SeparatorPosition > 0 Then
				
				NumberByString = Left(CopyDateString, SeparatorPosition - 1);
				CopyDateString = Mid(CopyDateString, SeparatorPosition + 1);
				
			EndIf;
			
			SeparatorPosition = Find(CopyDateString, Delimiter);
			If SeparatorPosition > 0 Then
				
				MonthString = Left(CopyDateString, SeparatorPosition - 1);
				CopyDateString = Mid(CopyDateString, SeparatorPosition + 1);
				
			EndIf;
			
			YearString = CopyDateString;
			
			If Not IsBlankString(NumberByString) 
				AND Not IsBlankString(MonthString) 
				AND Not IsBlankString(YearString) Then
				
				Try
					
					DateResult = Date(Number(YearString), Number(MonthString), Number(NumberByString));
					
				Except
					
					DateResult = Date(0001, 01, 01);
					
				EndTry;
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
EndProcedure

Procedure CopyRowToStringTypeValue(StringTypeValue, String) Export
	
	StringTypeValue = TrimAll(String);
	
EndProcedure

Procedure CompareProducts(Products, Barcode, SKU, ProductsDescription, ProductsDescriptionFull = Undefined, Code = Undefined, Supplier  = Undefined) Export
	
	ValueWasMapped = False;
	If ValueIsFilled(Code) Then
		
		CatalogRef = Catalogs.Products.FindByCode(Code, False);
		If Not CatalogRef.IsEmpty() Then
			
			ValueWasMapped = True;
			Products = CatalogRef;
			
		EndIf;
		
	EndIf;
	
	If Not ValueWasMapped 
		AND ValueIsFilled(Barcode) Then
		
		Query = New Query(
		"SELECT
		|	BC.Products AS Products
		|FROM
		|	InformationRegister.Barcodes AS BC
		|WHERE
		|	BC.Barcode = &Barcode");
		Query.SetParameter("Barcode", Barcode);
		Selection = Query.Execute().Select();
		If Selection.Next() Then
			
			ValueWasMapped = True;
			Products = Selection.Products;
			
		EndIf;
		
	EndIf;
	
	If Not ValueWasMapped
		AND ValueIsFilled(SKU) Then
		
		CatalogRef = Catalogs.Products.FindByAttribute("SKU", SKU);
		If Not CatalogRef.IsEmpty() Then
			
			ValueWasMapped = True;
			Products = CatalogRef;
			
		EndIf;
		
	EndIf;
	
	If Not ValueWasMapped
		AND ValueIsFilled(ProductsDescription) Then
		
		If Supplier = Undefined Then 
			CatalogRef = Catalogs.Products.FindByDescription(ProductsDescription, True);
			If ValueIsFilled(CatalogRef)
				AND Not CatalogRef.IsFolder Then 
				
				ValueWasMapped = True;
				Products = CatalogRef;
			EndIf;
		Else
			Products = SearchProduct(ProductsDescription, True, Supplier)
		EndIf;
		
	EndIf;
	
	// Categories for catalog of products are not used at the moment.
	If ValueIsFilled(Products)
		AND Products.IsFolder Then
		
		Products = Catalogs.Products.EmptyRef(ProductsDescription, True);
		
	EndIf;
	
EndProcedure

Function SearchProduct(ProductsDescription, ExactMap, Supplier)
	
	CatalogRef = Catalogs.Products.FindByDescription(ProductsDescription, ExactMap);

	If Not ValueIsFilled(CatalogRef) Then
		SupplierProduct = Catalogs.SuppliersProducts.FindByDescription(ProductsDescription, True, , Supplier);
		CatalogRef = SupplierProduct.Products;
	EndIf;

	SupplierProduct = ValueIsFilled(SupplierProduct) AND SupplierProduct.DeletionMark;
	
	If ValueIsFilled(CatalogRef)
		AND Not CatalogRef.IsFolder
		AND Not CatalogRef.DeletionMark
		AND Not SupplierProduct Then

		Products = CatalogRef;
	Else
		
		If SupplierProduct Then
			CommonUseClientServer.MessageToUser(
				StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = 'Object matching %1 has deletion mark"),
					SupplierProduct));
		EndIf;
		
		If CatalogRef.DeletionMark Then
			CommonUseClientServer.MessageToUser(
				StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = 'Object %1 has deletion mark"),
					CatalogRef));
		EndIf;
		
	EndIf;
	
	Return Products;
	
EndFunction

Procedure CreateAdditionalProperty(AdditionalAttributeValue, Property, UseHierarchy, StringValue) Export
	
	If Not ValueIsFilled(AdditionalAttributeValue) Then
		
		CatalogName = ?(UseHierarchy, "AdditionalValuesHierarchy", "AdditionalValues");
		
		CatalogObject = Catalogs[CatalogName].CreateItem();
		CatalogObject.Owner = Property;
		CatalogObject.Description = StringValue;
		
		UpdateResults.WriteObject(CatalogObject, True, True);
		
		AdditionalAttributeValue = CatalogObject.Ref;
		
	EndIf;
	
EndProcedure

Procedure MapAdditionalAttribute(AdditionalAttributeValue, Property, UseHierarchy, StringValue) Export
	
	QueryText = 
	"SELECT
	|	AdditionalValues.Ref AS PropertyValue
	|FROM
	|	Catalog.AdditionalValues AS AdditionalValues
	|WHERE
	|	AdditionalValues.Description LIKE &Description
	|	AND AdditionalValues.Ref IN(&ValueArray)";
	
	Query = New Query(QueryText);
	
	If UseHierarchy Then         
		
		Query.Text = StrReplace(Query.Text, "Catalog.AdditionalValues", "Catalog.AdditionalValuesHierarchy");
		
	EndIf;
	
	ValueArray = PropertiesManagement.GetListOfValuesOfProperties(Property);
	
	Query.SetParameter("Description", TrimAll(AdditionalAttributeValue));
	Query.SetParameter("ValueArray", ValueArray);
	QueryResult = Query.Execute();
	
	If NOT QueryResult.IsEmpty() Then
		
		Selection = QueryResult.Select();
		If Selection.Next() Then
			AdditionalAttributeValue = Selection.ЗначениеСвойства;
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure CreateFillTableOfPossibleValueTypesForAdditionalAttribute(Property, TypesTable) Export
	
	TypesTable = New ValueTable;
	TypesTable.Columns.Add("Type");
	TypesTable.Columns.Add("Priority");
	
	ValueTypeArray = Property.ТипЗначения.Types();
	For Each ArrayItem In ValueTypeArray Do
		
		NewRow = TypesTable.Add();
		NewRow.Type = ArrayItem;
		If ArrayItem = Type("CatalogRef.AdditionalValues") 
			OR ArrayItem = Type("CatalogRef.AdditionalValuesHierarchy") Then
			
			NewRow.Priority = 1;
			
		ElsIf ArrayItem = Type("Boolean")
			OR ArrayItem = Type("Date")
			OR ArrayItem = Type("Number") Then
			
			NewRow.Priority = 3;
			
		ElsIf ArrayItem = Type("String") Then
			NewRow.Priority = 4;
		Else
			NewRow.Priority = 2;
		EndIf;
		
	EndDo;
	
	TypesTable.Sort("Priority");
	
EndProcedure

Procedure MapCharacteristic(Characteristic, Products, Barcode, Characteristic_IncomingData) Export
	
	If ValueIsFilled(Products) Then
		
		ValueWasMapped = False;
		If ValueIsFilled(Barcode) Then
			
			Query = New Query("SELECT BC.Characteristic FROM InformationRegister.Barcodes AS BC WHERE BC.Barcode = &Barcode AND BC.Products = &Products");
			Query.SetParameter("Barcode", Barcode);
			Query.SetParameter("Products", Products);
			
			Selection = Query.Execute().Select();
			If Selection.Next() Then
				
				ValueWasMapped = True;
				Characteristic = Selection.Characteristic;
				
			EndIf;
			
		EndIf;
		
		If Not ValueWasMapped
			AND ValueIsFilled(Characteristic_IncomingData) Then
			
			// Product or product category can be owners of a characteristic.
			//
			
			CatalogRef = Undefined;
			CatalogRef = Catalogs.ProductsCharacteristics.FindByDescription(Characteristic_IncomingData, False, , Products);
			If Not ValueIsFilled(CatalogRef)
				AND ValueIsFilled(Products.ProductsCategory) Then
				
				CatalogRef = Catalogs.ProductsCharacteristics.FindByDescription(Characteristic_IncomingData, False, , Products.ProductsCategory);
				
			EndIf;
			
			If ValueIsFilled(CatalogRef) Then
				
				Characteristic = CatalogRef;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure MapBatch(Batch, Products, Barcode, Batch_IncomingData) Export
	
	If ValueIsFilled(Products) Then
		
		ValueWasMapped = False;
		If ValueIsFilled(Barcode) Then
			
			Query = New Query("SELECT BC.Batch FROM InformationRegister.Barcodes AS BC WHERE BC.Barcode = &Barcode AND BC.Products = &Products");
			Query.SetParameter("Barcode", Barcode);
			Query.SetParameter("Products", Products);
			
			Selection = Query.Execute().Select();
			If Selection.Next() Then
				
				ValueWasMapped = True;
				Batch = Selection.Batch;
				
			EndIf;
			
		EndIf;
		
		If Not ValueWasMapped
			AND ValueIsFilled(Batch_IncomingData) Then
			
			CatalogRef = Catalogs.ProductsBatches.FindByDescription(Batch_IncomingData, False, , Products);
			If ValueIsFilled(CatalogRef) Then
				
				Batch = CatalogRef;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure MapUOM(Products, MeasurementUnit, MeasurementUnit_IncomingData) Export
	
	If Not IsBlankString(MeasurementUnit_IncomingData) Then
		
		CatalogRef = Catalogs.UOMClassifier.FindByDescription(MeasurementUnit_IncomingData, False);
		ProductsIsFilled = ValueIsFilled(Products);
		
		If ValueIsFilled(CatalogRef) 
			AND ((ProductsIsFilled 
					AND CommonUse.GetAttributeValue(Products, "MeasurementUnit") = CatalogRef)
				Or Not ProductsIsFilled) Then
			
			MeasurementUnit = CatalogRef;
			
		ElsIf ProductsIsFilled Then
			CatalogRef = Catalogs.UOM.FindByDescription(MeasurementUnit_IncomingData, False, , Products);
			If ValueIsFilled(CatalogRef) Then
				MeasurementUnit = CatalogRef;
			EndIf;
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure MapParent(CatalogName, Parent, Parent_IncomingData, DefaultValue) Export
	
	If Not IsBlankString(Parent_IncomingData) Then
		
		Query = New Query("SELECT Catalog." + CatalogName + ".Ref WHERE Catalog." + CatalogName + ".IsFolder AND Catalog." + CatalogName + ".Description LIKE &Description");
		Query.SetParameter("Description", Parent_IncomingData + "%");
		Selection = Query.Execute().Select();
		
		If Selection.Next() Then
			
			Parent = Selection.Ref;
			
		EndIf;
		
	EndIf;
	
	If Not ValueIsFilled(Parent) Then
		
		Parent = DefaultValue;
		
	EndIf;
	
EndProcedure

Procedure MapAdditionalAttributes(FormTableRow, SelectedAdditionalAttributes) Export
	Var TypesTable;
	
	Postfix = "_IncomingData";
	For Each MapItem In SelectedAdditionalAttributes Do
		
		StringValue = FormTableRow[MapItem.Value + Postfix];
		If IsBlankString(StringValue) Then
			Continue;
		EndIf;
		
		Property = MapItem.Key;
		
		CreateFillTableOfPossibleValueTypesForAdditionalAttribute(Property, TypesTable);
		
		AdditionalAttributeValue = Undefined;
		For Each TableRow In TypesTable Do
			
			If TableRow.Type = Type("CatalogRef.AdditionalValues") Then
				
				MapAdditionalAttribute(AdditionalAttributeValue, Property, False, StringValue);
				
			ElsIf TableRow.Type = Type("CatalogRef.AdditionalValuesHierarchy") Then
				
				MapAdditionalAttribute(AdditionalAttributeValue, Property, True, StringValue);
				
			ElsIf TableRow.Type = Type("CatalogRef.Counterparties") Then
				
				MapCounterparty(AdditionalAttributeValue, StringValue, StringValue, StringValue);
				
			ElsIf TableRow.Type = Type("CatalogRef.Individuals") Then
				
				MapIndividualPerson(AdditionalAttributeValue, StringValue);
				
			ElsIf TableRow.Type = Type("Boolean") Then
				
				ConvertStringToBoolean(AdditionalAttributeValue, StringValue);
				
			ElsIf TableRow.Type = Type("String") Then
				
				CopyRowToStringTypeValue(AdditionalAttributeValue, StringValue);
				
			ElsIf TableRow.Type = Type("Date") Then
				
				ConvertStringToDate(AdditionalAttributeValue, StringValue);
				
			ElsIf TableRow.Type = Type("Number") Then
				
				ConvertRowToNumber(AdditionalAttributeValue, StringValue);
				If AdditionalAttributeValue = 0 Then // 0 ignore
					AdditionalAttributeValue = Undefined;
				EndIf;
				
			EndIf;
			
			If AdditionalAttributeValue <> Undefined Then
				FormTableRow[MapItem.Value] = AdditionalAttributeValue;
				Break;
			EndIf;
		EndDo;
	EndDo;
	
EndProcedure

// :::Specification

Procedure MapRowType(RowType, RowType_IncomingData, DefaultValue) Export
	
	MapEnumeration("BOMLineType", RowType, RowType_IncomingData, DefaultValue);
	
EndProcedure

Procedure MapSpecification(Specification, Specification_IncomingData, Products) Export
	
	If ValueIsFilled(Products) 
		AND Not IsBlankString(Specification_IncomingData) Then
		
		CatalogRef = Catalogs.BillsOfMaterials.FindByDescription(Specification_IncomingData, False, , Products);
		If ValueIsFilled(CatalogRef) Then
			
			Specification = CatalogRef;
			
		EndIf;
		
	EndIf;
	
EndProcedure

// :::Products

Procedure MapProductsType(ProductsType, ProductsType_IncomingData, DefaultValue) Export
	
	MapEnumeration("ProductsTypes", ProductsType, ProductsType_IncomingData, DefaultValue);
	
EndProcedure

Procedure MapBusinessLine(BusinessLine, BusinessLine_IncomingData, DefaultValue) Export
	
	UseEnabled = GetFunctionalOption("AccountingBySeveralLinesOfBusiness");
	If Not UseEnabled Then
		
		// You can not fill in the default value as it can, for instance, come from custom settings.
		//
		BusinessLine = Catalogs.LinesOfBusiness.MainLine;
		
	Else
		
		CatalogByName("LinesOfBusiness", BusinessLine, BusinessLine_IncomingData, DefaultValue);
		
	EndIf;
	
EndProcedure

Procedure MapProductsCategory(ProductsCategory, ProductsCategory_IncomingData, DefaultValue) Export
	
	CatalogByName("ProductsCategories", ProductsCategory, ProductsCategory_IncomingData, DefaultValue)
	
EndProcedure

Procedure MapSupplier(Vendor, Vendor_IncomingData) Export
	
	If IsBlankString(Vendor_IncomingData) Then
		
		Return;
		
	EndIf;
	
	//:::TIN Search
	Separators = New Array;
	Separators.Add("/");
	Separators.Add("\");
	Separators.Add("-");
	Separators.Add("|");
	
	TIN = "";
	
	For Each SeparatorValue In Separators Do
		
		SeparatorPosition = Find(Vendor_IncomingData, SeparatorValue);
		If SeparatorPosition = 0 Then 
			
			Continue;
			
		EndIf;
		
		TIN = Left(Vendor_IncomingData, SeparatorPosition - 1);
		
		Query = New Query("SELECT Catalog.Counterparties.Ref WHERE NOT IsFolder AND TIN = &TIN");
		Query.SetParameter("TIN", TIN);
		
		Selection = Query.Execute().Select();
		If Selection.Next() Then
			
			Vendor = Selection.Ref;
			Return;
			
		EndIf;
		
	EndDo;
	
	// :::Search TIN
	Query = New Query("SELECT Catalog.Counterparties.Ref WHERE NOT IsFolder AND TIN = &TIN");
	Query.SetParameter("TIN", Vendor_IncomingData);
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		
		Vendor = Selection.Ref;
		Return;
		
	EndIf;
	
	//:::Search Name
	CatalogRef = Catalogs.Counterparties.FindByDescription(Vendor_IncomingData, False);
	If ValueIsFilled(CatalogRef) Then
		
		Vendor = CatalogRef;
		
	EndIf;
	
EndProcedure

Procedure MapStructuralUnit(Warehouse, Warehouse_IncomingData, DefaultValue) Export
	
	CatalogByName("BusinessUnits", Warehouse, Warehouse_IncomingData, DefaultValue);
	
EndProcedure

Procedure MapReplenishmentMethod(ReplenishmentMethod, ReplenishmentMethod_IncomingData, DefaultValue) Export
	
	MapEnumeration("InventoryReplenishmentMethods", ReplenishmentMethod, ReplenishmentMethod_IncomingData, DefaultValue);
	
EndProcedure

Procedure MapVATRate(VATRate, VATRate_IncomingData, DefaultValue) Export
	
	CatalogByName("VATRates", VATRate, VATRate_IncomingData, DefaultValue);
	
EndProcedure

Procedure MapCell(Cell, Cell_IncomingData, DefaultValue) Export
	
	CatalogByName("Cells", Cell, Cell_IncomingData, DefaultValue);
	
EndProcedure

Procedure MapPriceGroup(PriceGroup, PriceGroup_IncomingData, DefaultValue) Export
	
	CatalogByName("PriceGroups", PriceGroup, PriceGroup_IncomingData, DefaultValue);
	
EndProcedure

Procedure MapOriginCountry(CountryOfOrigin, CountryOfOrigin_IncomingData, DefaultValue) Export
	
	If Not IsBlankString(CountryOfOrigin_IncomingData) Then
		
		CatalogRef = Catalogs.Countries.FindByDescription(CountryOfOrigin_IncomingData, False);
		If Not ValueIsFilled(CatalogRef) Then
			
			CatalogRef = Catalogs.Countries.FindByAttribute("AlphaCode3", CountryOfOrigin_IncomingData);
			If Not ValueIsFilled(CatalogRef) Then
				
				CatalogRef = Catalogs.Countries.FindByCode(CountryOfOrigin_IncomingData, True);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	If ValueIsFilled(CatalogRef) Then
		
		CountryOfOrigin = CatalogRef;
		
	Else
		
		CountryOfOrigin = DefaultValue;
		
	EndIf;
	
EndProcedure

Procedure MapSerialNumber(ProductsRef, SerialNumber, SerialNumber_IncomingData) Export
	
	SerialNumber = Catalogs.SerialNumbers.FindByDescription(SerialNumber_IncomingData, True, , ProductsRef);
	
EndProcedure

// :::Purchase order
Procedure MatchOrder(Order, Order_IncomingData) Export
	
	If IsBlankString(Order_IncomingData) Then
		
		Return;
		
	EndIf;
	
	SuppliersTagsArray = New Array;
	SuppliersTagsArray.Add("Purchase order");
	SuppliersTagsArray.Add("PurchaseOrder");
	SuppliersTagsArray.Add("Vendor");
	SuppliersTagsArray.Add("Vendor");
	SuppliersTagsArray.Add("Post");
	
	NumberForSearch	= Order_IncomingData;
	DocumentKind	= "SalesOrder";
	For Each TagFromArray In SuppliersTagsArray Do
		
		If Find(Order_IncomingData, TagFromArray) > 0 Then
			
			DocumentKind = "PurchaseOrder";
			NumberForSearch = TrimAll(StrReplace(NumberForSearch, "", TagFromArray));
			
		EndIf;
		
	EndDo;
	
	Query = New Query("Select Document.SalesOrder.Ref Where Number LIKE &Number ORDER BY Date Desc");
	Query.SetParameter("Number", "%" + NumberForSearch + "%");
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		
		Order = Selection.Ref;
		
	EndIf;
	
EndProcedure

// :::Counterparty
Procedure MapCounterparty(Counterparty, TIN, CounterpartyDescription, BankAccount) Export
	
	// TIN Search
	If Not IsBlankString(TIN) Then
		
		Query = New Query("SELECT Catalog.Counterparties.Ref WHERE NOT IsFolder AND TIN = &TIN");
		Query.SetParameter("TIN", TIN);
		Selection = Query.Execute().Select();
		If Selection.Next() Then
			
			Counterparty = Selection.Ref;
			Return;
			
		EndIf;
		
	EndIf;
	
	//Search Name
	If Not IsBlankString(CounterpartyDescription) Then
		
		CatalogRef = Catalogs.Counterparties.FindByDescription(CounterpartyDescription, False);
		If ValueIsFilled(CatalogRef) Then
			
			Counterparty = CatalogRef;
			Return;
			
		EndIf;
		
	EndIf;
	
	// Current account number
	If Not IsBlankString(BankAccount) Then
		
		CatalogRef = Catalogs.BankAccounts.FindByAttribute("AccountNo", BankAccount);
		If ValueIsFilled(CatalogRef) Then
			Counterparty = CatalogRef.Owner;
		Else
			
			CatalogRef = Catalogs.BankAccounts.FindByAttribute("IBAN", BankAccount);
			If ValueIsFilled(CatalogRef) Then
				Counterparty = CatalogRef.Owner;
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure MapIndividualPerson(Individual, Individual_IncomingData) Export
	
	CatalogByName("Individuals", Individual, Individual_IncomingData, Undefined);
	
EndProcedure

Procedure MapAccessGroup(AccessGroup, AccessGroup_IncomingData) Export
	
	CatalogByName("CounterpartiesAccessGroups", AccessGroup, AccessGroup_IncomingData);
	
EndProcedure

Procedure MapGLAccountCustomerSettlements(GLAccountCustomerSettlements, GLAccountCustomerSettlements_IncomingData, DefaultValue) Export
	
	MapGLAccount(GLAccountCustomerSettlements, GLAccountCustomerSettlements_IncomingData, DefaultValue);
	
EndProcedure

Procedure MapCustomerAdvancesGLAccount(CustomerAdvancesGLAccount, CustomerAdvancesGLAccount_IncomingData, DefaultValue) Export
	
	MapGLAccount(CustomerAdvancesGLAccount, CustomerAdvancesGLAccount_IncomingData, DefaultValue);
	
EndProcedure

Procedure MapGLAccountVendorSettlements(GLAccountVendorSettlements, GLAccountVendorSettlements_IncomingData, DefaultValue) Export
	
	MapGLAccount(GLAccountVendorSettlements, GLAccountVendorSettlements_IncomingData, DefaultValue);
	
EndProcedure

Procedure MapVendorAdvancesGLAccount(VendorAdvancesGLAccount, VendorAdvancesGLAccount_IncomingData, DefaultValue) Export
	
	MapGLAccount(VendorAdvancesGLAccount, VendorAdvancesGLAccount_IncomingData, DefaultValue);
	
EndProcedure

// :::Leads
Procedure MapLead(Lead, Description, Code)
	
	If Not IsBlankString(Code) AND Not IsBlankString(Description) Then
		
		Query = New Query(
		"SELECT TOP 1
		|	Leads.Ref AS Ref
		|FROM
		|	Catalog.Leads AS Leads
		|WHERE
		|	Leads.Code = &Code
		|	AND Leads.Description = &Description");
		Query.SetParameter("Code", Code);
		Query.SetParameter("Description", Description);
		Selection = Query.Execute().Select();
		If Selection.Next() Then
			
			Lead = Selection.Ref;
			
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure MapAcquisitionChannel(AcquisitionChannel, AcquisitionChannel_IncomingData)
	
	CatalogByName("CustomerAcquisitionChannels", AcquisitionChannel, AcquisitionChannel_IncomingData, Undefined);
	
EndProcedure

// :::Prices

Procedure MapPriceKind(PriceKind, PriceKind_IncomingData, DefaultValue) Export
	
	CatalogByName("PriceTypes", PriceKind, PriceKind_IncomingData, DefaultValue);
	
EndProcedure

// :::Enter opening balance

Procedure MapContract(Counterparty, Contract, Contract_IncomingData) Export
	
	If ValueIsFilled(Counterparty) 
		AND ValueIsFilled(Contract_IncomingData) Then
		
		CatalogRef = Undefined;
		CatalogRef = Catalogs.CounterpartyContracts.FindByDescription(Contract_IncomingData, False, , Counterparty);
		If Not ValueIsFilled(CatalogRef) Then
			
			CatalogRef = Catalogs.CounterpartyContracts.FindByAttribute("Number", Contract_IncomingData, , Counterparty);
			
		EndIf;
		
		If ValueIsFilled(CatalogRef) Then
			
			Contract = CatalogRef;
			
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure MapOrderByNumberDate(Order, DocumentTypeName, Counterparty, Number_IncomingData, Date_IncomingData) Export
	
	If IsBlankString(Number_IncomingData) Then
		
		Return;
		
	EndIf;
	
	If DocumentTypeName <> "PurchaseOrder" Then
		
		DocumentTypeName = "SalesOrder"
		
	EndIf;
	
	TableName = "Document." + DocumentTypeName;
	
	Query = New Query("Select Order.Ref FROM &TableName AS Order Where Order.Counterparty = &Counterparty And Order.Number LIKE &Number");
	Query.Text = StrReplace(Query.Text, "&TableName", TableName);
	Query.SetParameter("Counterparty", Counterparty);
	Query.SetParameter("Number", "%" + Number_IncomingData + "%");
	
	If Not IsBlankString(Date_IncomingData) Then
		
		DateFromString = Date('00010101');
		ConvertStringToDate(DateFromString, Date_IncomingData);
		
		If ValueIsFilled(DateFromString) Then
			
			Query.Text = Query.Text + " And Order.Date Between &StartDate And &EndDate";
			Query.SetParameter("StartDate", BegOfDay(DateFromString));
			Query.SetParameter("EndDate", EndOfDay(DateFromString));
			
		EndIf;
		
	EndIf;
	
	Query.Text = Query.Text + " ORDER BY Order.Date DESC";
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		
		Order = Selection.Ref;
		
	EndIf;
	
EndProcedure

Procedure MapAccountingDocumentByNumberDate(Document, DocumentTypeName, Counterparty, Number_IncomingData, Date_IncomingData) Export
	
	If IsBlankString(DocumentTypeName) 
		OR IsBlankString(Number_IncomingData) Then
		
		Return;
		
	EndIf;
	
	MapDocumentNames = New Map;
	
	MapDocumentNames.Insert("SalesOrder", 			"SalesOrder");
	MapDocumentNames.Insert("Sales orders",			"SalesOrder");
	MapDocumentNames.Insert("Sales order",			"SalesOrder");
	
	MapDocumentNames.Insert("ArApAdjustments",				"ArApAdjustments");
	MapDocumentNames.Insert("AR/AP Adjustments",		"ArApAdjustments");
	MapDocumentNames.Insert("Debt adjustments",		"ArApAdjustments");
	
	MapDocumentNames.Insert("AccountSalesFromConsignee",			"AccountSalesFromConsignee");
	MapDocumentNames.Insert("Agent report",			"AccountSalesFromConsignee");
	MapDocumentNames.Insert("Agent reports",		"AccountSalesFromConsignee");
	
	MapDocumentNames.Insert("SubcontractorReportIssued",		"SubcontractorReportIssued");
	MapDocumentNames.Insert("Subcontractor report issued",	"SubcontractorReportIssued");
	MapDocumentNames.Insert("Processing reports",	"SubcontractorReportIssued");
	
	MapDocumentNames.Insert("CashReceipt",			"CashReceipt");
	MapDocumentNames.Insert("Petty cash receipt",	"CashReceipt");
	MapDocumentNames.Insert("Cash receipt",			"CashReceipt");
	MapDocumentNames.Insert("OCR",					"CashReceipt");
	
	MapDocumentNames.Insert("PaymentReceipt",		"PaymentReceipt");
	MapDocumentNames.Insert("Payment receipt",		"PaymentReceipt");
	MapDocumentNames.Insert("Payment receipt",		"PaymentReceipt");
	
	MapDocumentNames.Insert("FixedAssetSale",	"FixedAssetSale");
	MapDocumentNames.Insert("Fixed assets sale",	"FixedAssetSale");
	MapDocumentNames.Insert("Fixed assets sales",	"FixedAssetSale");
	
	MapDocumentNames.Insert("SalesInvoice",			"SalesInvoice");
	MapDocumentNames.Insert("PH",					"SalesInvoice");
	MapDocumentNames.Insert("Sales invoice",		"SalesInvoice");
	MapDocumentNames.Insert("Sales invoices",		"SalesInvoice");
	
	MapDocumentNames.Insert("ExpenseReport", 		"ExpenseReport");
	MapDocumentNames.Insert("Expense report", 		"ExpenseReport");
	MapDocumentNames.Insert("Expense reports",		"ExpenseReport");
	
	MapDocumentNames.Insert("AdditionalExpenses", 		"AdditionalExpenses");
	MapDocumentNames.Insert("Additional costs", 	"AdditionalExpenses");
	
	MapDocumentNames.Insert("AccountSalesToConsignor", 	"AccountSalesToConsignor");
	MapDocumentNames.Insert("Principal report", 	"AccountSalesToConsignor");
	MapDocumentNames.Insert("Reports to principals", "AccountSalesToConsignor");
	
	MapDocumentNames.Insert("SubcontractorReport",	"SubcontractorReport");
	MapDocumentNames.Insert("Subcontractor report", "SubcontractorReport");
	MapDocumentNames.Insert("Processor reports", 	"SubcontractorReport");
	
	MapDocumentNames.Insert("SupplierInvoice", 		"SupplierInvoice");
	MapDocumentNames.Insert("Supplier invoice", 	"SupplierInvoice");
	MapDocumentNames.Insert("Supplier invoices",	"SupplierInvoice");
	MapDocumentNames.Insert("MON", 					"SupplierInvoice");
	
	MapDocumentNames.Insert("CashVoucher", 			"CashVoucher");
	MapDocumentNames.Insert("Cash payment", 		"CashVoucher");
	MapDocumentNames.Insert("CPV", 					"CashVoucher");
	
	MapDocumentNames.Insert("PaymentExpense", 		"PaymentExpense");
	MapDocumentNames.Insert("Payment expense", 		"PaymentExpense");
	
	DocumentType = MapDocumentNames.Get(DocumentTypeName);
	If DocumentType = Undefined Then
		
		Return;
		
	EndIf;
	
	TableName = "Document." + DocumentType;
	
	Query = New Query("Select AccountingDocument.Ref FROM &TableName AS AccountingDocument Where AccountingDocument.Counterparty = &Counterparty And AccountingDocument.Number LIKE &Number");
	Query.Text = StrReplace(Query.Text, "&TableName", TableName);
	Query.SetParameter("Counterparty", Counterparty);
	Query.SetParameter("Number", "%" + Number_IncomingData + "%");
	
	If Not IsBlankString(Date_IncomingData) Then
		
		DateFromString = Date('00010101');
		ConvertStringToDate(DateFromString, Date_IncomingData);
		
		If ValueIsFilled(DateFromString) Then
			
			Query.Text = Query.Text + " And AccountingDocument.Date Between &StartDate And &EndDate";
			Query.SetParameter("StartDate", BegOfDay(DateFromString));
			Query.SetParameter("EndDate", EndOfDay(DateFromString));
			
		EndIf;
		
	EndIf;
	
	Query.Text = Query.Text + " ORDER BY AccountingDocument.Date Desc";
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		
		Document = Selection.Ref;
		
	EndIf;
	
EndProcedure

Procedure MapAccountByNumberDate(Account, Counterparty, Number_IncomingData, Date_IncomingData) Export
	
	If IsBlankString(Number_IncomingData) Then
		
		Return;
		
	EndIf;
	
	Query = New Query("Select Account.Ref FROM Document.Quote AS Account Where Account.Counterparty = &Counterparty And Account.Number LIKE &Number");
	Query.SetParameter("Counterparty", Counterparty);
	Query.SetParameter("Number", "%" + Number_IncomingData + "%");
	
	If Not IsBlankString(Date_IncomingData) Then
		
		DateFromString = Date('00010101');
		ConvertStringToDate(DateFromString, Date_IncomingData);
		
		If ValueIsFilled(DateFromString) Then
			
			Query.Text = Query.Text + " And Account.Date Between &StartDate And &EndDate";
			Query.SetParameter("StartDate", BegOfDay(DateFromString));
			Query.SetParameter("EndDate", EndOfDay(DateFromString));
			
		EndIf;
		
	EndIf;
	
	Query.Text = Query.Text + " ORDER BY Account.Date DESC";
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		
		Account = Selection.Ref;
		
	EndIf;
	
EndProcedure

#EndRegion
 

