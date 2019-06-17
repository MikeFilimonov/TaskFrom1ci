
////////////////////////////////////////////////////////////////////////////////
// PROCEDURES OF RECOVERY AND SETTINGS SAVING

&AtServer
// The procedure restores the custom settings.
//
Procedure RestoreSettings()
	
	Var SettingsValue;
	Var UserSettings;
	
	If PurchasesOnly Then
		SettingsValue = CommonSettingsStorage.Load("DataProcessor.DemandPlanning", "SettingsPurchases");
	Else
		SettingsValue = CommonSettingsStorage.Load("DataProcessor.DemandPlanning", "SettingsProduction");
	EndIf;
	
	ArrayWaysRefill = Items.FilterReplenishmentMethod.ChoiceList.UnloadValues();
	If TypeOf(SettingsValue) = Type("Structure") Then
		
		SettingsValue.Property("EndOfPeriod", EndOfPeriod);
		SettingsValue.Property("Counterparty", Counterparty);
		SettingsValue.Property("Company", Company);
		SettingsValue.Property("OnlyDeficit", OnlyDeficit);
		SettingsValue.Property("UserSettings", UserSettings);
		
		If ArrayWaysRefill.Count() = 1 Then
			
			FilterReplenishmentMethod = ArrayWaysRefill[0];
			
		Else
			
			SettingsValue.Property("FilterReplenishmentMethod", FilterReplenishmentMethod);
			
		EndIf;
		
	Else
		
		OnlyDeficit = True;
		UserSettings = New DataCompositionUserSettings;
		
	EndIf;
	
	UpdateChoiceListReplenishmentMethod();
	
	If EndOfPeriod <= CurrentDate() Then
		EndOfPeriod = CurrentDate() + 7 * 86400;
	EndIf;
	
	SettingsComposer.LoadUserSettings(UserSettings);
	
EndProcedure

&AtServer
// The procedure saves custom settings.
//
Procedure SaveSettings()
	
	Var Settings;
	
	Settings = New Structure;
	Settings.Insert("EndOfPeriod", EndOfPeriod);
	Settings.Insert("Counterparty", Counterparty);
	Settings.Insert("Company", Company);
	Settings.Insert("OnlyDeficit", OnlyDeficit);
	Settings.Insert("FilterReplenishmentMethod", FilterReplenishmentMethod);
	Settings.Insert("UserSettings", SettingsComposer.UserSettings);
	
	If PurchasesOnly Then
		CommonSettingsStorage.Save("DataProcessor.DemandPlanning", "SettingsPurchases", Settings);
	Else
		CommonSettingsStorage.Save("DataProcessor.DemandPlanning", "SettingsProduction", Settings);
	EndIf;
	
EndProcedure

&AtServer
// The procedure updates the selections depending on the SF.
//
Procedure UpdateChoiceListReplenishmentMethod()
	
	PurchasesAvailable = IsInRole("FullRights") OR IsInRole("AddChangePurchasesSubsystem");
	AvailableProduction = (IsInRole("FullRights") OR IsInRole("AddChangeProductionSubsystem"))
		AND GetFunctionalOption("UseProductionSubsystem");
	
	If PurchasesAvailable Then
		If GetFunctionalOption("TransferRawMaterialsForProcessing") AND IsInRole("AddChangeProcessingSubsystem") Then
			Items.FilterReplenishmentMethod.ChoiceList.Add("Purchase and processing", NStr("en = 'Purchase and processing'"));
		Else
			Items.FilterReplenishmentMethod.ChoiceList.Add("Purchase", NStr("en = 'Purchase'"));
		EndIf;
	EndIf;
	
	If AvailableProduction Then
		Items.FilterReplenishmentMethod.ChoiceList.Add("Production", NStr("en = 'Production'"));
		If PurchasesAvailable Then
			Items.FilterReplenishmentMethod.ChoiceList.Add("All", NStr("en = 'All'"));
		EndIf;
	EndIf;
	
	Items.FilterReplenishmentMethod.Visible = PurchasesAvailable AND AvailableProduction;
	PurchasesOnly = PurchasesAvailable AND Not AvailableProduction;
	
	UpdateReplenishmentMethod();
	
	If FilterReplenishmentMethod = "Production" Then
		Items.Counterparty.Visible = False;
	Else
		Items.Counterparty.Visible = True;
	EndIf;
	
	If Constants.AccountingBySubsidiaryCompany.Get() Then
		Items.Company.ReadOnly = True;
		Company = Constants.ParentCompany.Get();
	ElsIf Not ValueIsFilled(Company) Then
		SettingValue = DriveReUse.GetValueByDefaultUser(Users.CurrentUser(), "MainCompany");
		If ValueIsFilled(SettingValue) Then
			Company = SettingValue;
		Else
			Company = Catalogs.Companies.MainCompany;
		EndIf;
	EndIf;
	
EndProcedure

&AtServer
// The procedure updates the selection: replenishment method.
//
Procedure UpdateReplenishmentMethod()
	
	If Items.FilterReplenishmentMethod.ChoiceList.FindByValue(FilterReplenishmentMethod) = Undefined Then
		
		If PurchasesOnly Then
			If GetFunctionalOption("TransferRawMaterialsForProcessing") AND IsInRole("AddChangeProcessingSubsystem") Then
				FilterReplenishmentMethod = "Purchase and processing";
			Else
				FilterReplenishmentMethod = "Purchase";
			EndIf;
		Else
			FilterReplenishmentMethod = "Production";
		EndIf;
		
	EndIf;
	
EndProcedure

#Region GeneralPurposeProceduresAndFunctions

&AtServer
// Procedure of data processing and demand diagram output to the form.
//
Procedure UpdateAtServer()
	
	DataCompositionSchema = GetFromTempStorage(SchemaURLCompositionData);
	
	DataCompositionTemplateComposer = New DataCompositionTemplateComposer;
	DataCompositionTemplate = DataCompositionTemplateComposer.Execute(DataCompositionSchema, SettingsComposer.GetSettings());
	
	DataCompositionTemplate.ParameterValues.StartDate.Value = BegOfDay(CurrentDate());
	DataCompositionTemplate.ParameterValues.EndDate.Value = EndOfDay(?(EndOfPeriod < CurrentDate(), CurrentDate(), EndOfPeriod));
	
	Query = New Query(DataCompositionTemplate.DataSets.LineNeedsInventory.Query);

	QueryParametersDescription = Query.FindParameters();
	
	For Each QueryParameterDescription In QueryParametersDescription Do
		
		Query.SetParameter(QueryParameterDescription.Name, DataCompositionTemplate.ParameterValues[QueryParameterDescription.Name].Value);
		
	EndDo;
	
	Query.SetParameter("UseCharacteristics", Constants.UseCharacteristics.Get());
	Query.SetParameter("DateBalance", CurrentDate());
	Query.SetParameter("Company", Company);
	
	If ValueIsFilled(Counterparty) Then
		SupplierPriceTypes = GetActualSupplierPriceTypes();
		Query.SetParameter("SupplierPriceTypes", SupplierPriceTypes);
	Else
		Query.SetParameter("SupplierPriceTypes", New ValueList());
	EndIf;
	
	Query.SetParameter("Counterparty", Counterparty);
	
	ReplenishmentMethod.Clear();
	If FilterReplenishmentMethod = "Purchase and processing" OR FilterReplenishmentMethod = "Purchase" Then
		ReplenishmentMethod.Add(Enums.InventoryReplenishmentMethods.Purchase);
		ReplenishmentMethod.Add(Enums.InventoryReplenishmentMethods.Processing);
	ElsIf FilterReplenishmentMethod = "Production" Then
		ReplenishmentMethod.Add(Enums.InventoryReplenishmentMethods.Production);
	Else
		ReplenishmentMethod.Add(Enums.InventoryReplenishmentMethods.Purchase);
		ReplenishmentMethod.Add(Enums.InventoryReplenishmentMethods.Processing);
		ReplenishmentMethod.Add(Enums.InventoryReplenishmentMethods.Production);
	EndIf;
	
	Query.SetParameter("ReplenishmentMethod", ReplenishmentMethod);
	
	RefreshColumns(Query.Parameters.StartDate, Query.Parameters.EndDate);
	RefreshData(Query.Execute(), Query.Parameters.StartDate, Query.Parameters.EndDate);
	
	AddressInventory = PutToTempStorage(FormAttributeToValue("Inventory"), UUID);
	CurrentEndOfPeriod = Query.Parameters.EndDate;
	
EndProcedure

&AtServer
// Procedure of form columns update.
//
Procedure RefreshColumns(StartDate, EndDate)
	
	// Deleting previously added items.
	For Each AddedItem In AddedElements Do
		
		Items.Delete(Items[AddedItem.Value]);
		
	EndDo;
	
	ArrayAddedAttributes = New Array;
	
	// Attributes "Period".
	CurrentPeriod = StartDate;
	
	While BegOfDay(CurrentPeriod) <= BegOfDay(EndDate) Do
		
		NewAttribute = New FormAttribute("Period" + Format(CurrentPeriod, "DF=yyyyMMdd"), New TypeDescription("Number", New NumberQualifiers(15, 3)), "Inventory", Format(CurrentPeriod, "DLF=D"));
		ArrayAddedAttributes.Add(NewAttribute);
		
		NewAttribute = New FormAttribute("VariantRegistrationPeriod" + Format(CurrentPeriod, "DF=yyyyMMdd"),  New TypeDescription(New NumberQualifiers(1, 0)), "Inventory");
		ArrayAddedAttributes.Add(NewAttribute);
		
		CurrentPeriod = CurrentPeriod + 86400;
		
	EndDo;
	
	// Deleting previously added attributes and adding new attributes.
	ChangeAttributes(ArrayAddedAttributes, AddedAttributes.UnloadValues());
	
	// Updating added attributes.
	AddedAttributes.Clear();
	
	For Each AddingAttribute In ArrayAddedAttributes Do
		
		AddedAttributes.Add(AddingAttribute.Path + "." + AddingAttribute.Name);
		
	EndDo;
	
	// Adding new items.
	AddedElements.Clear();
	
	For Each Attribute In ArrayAddedAttributes Do
		
		If IsBlankString(Attribute.Title) Then
			
			Continue;
			
		EndIf;
		
		Item = Items.Add(Attribute.Path + Attribute.Name, Type("FormField"), Items[Attribute.Path]);
		Item.Type = FormFieldType.InputField;
		Item.DataPath = Attribute.Path + "." + Attribute.Name;
		Item.Title = Attribute.Title;
		Item.ReadOnly = True;
		Item.Width = 10;
		
		AddedElements.Add(Attribute.Path + Attribute.Name);
		
	EndDo;
	
	// Setting the conditional appearance.
	SetConditionalAppearance(StartDate, EndDate);
	
EndProcedure

&AtServer
// Data processing procedure.
//
Procedure RefreshData(QueryResult, StartDate, EndDate)
	
	// Generate a summary table of the demand diagram.
	TableQueryResult = QueryResult.Unload();
	CalculateInventoryFlowCalendar(TableQueryResult);
		
	// Order - decryption.
	TableLineNeeds = TableQueryResult.CopyColumns();
	AddDrillDownByOrder(TableQueryResult, TableLineNeeds);
		
	// Clearing the result before update.
	ProductsItems = Inventory.GetItems();
	ProductsItems.Clear();
			
	// Previous values of selection fields.
	PreviousRecord = New Structure("Products, Characteristic");
	
	// Tree item containing current products.
	ProductsCurrent = Undefined;
	
	// Decryption.
	StructureDetails = Undefined;
	
	// The structure containing the data of current products and characteristic.
	StructureDetailing = Undefined;
	
	// Previous column for which the indicators were calculated.
	PreviousColumn = Undefined;
	
	// Selection bypass.
	RecNo = 0;
	RecCountInSample = TableLineNeeds.Count();
	For Each Selection In TableLineNeeds Do
		
		RecNo = RecNo + 1;
		
		// First record in the selection or products and the characteristic have changed.
		If RecNo = 1 OR Selection.Products <> PreviousRecord.Products OR Selection.Characteristic <> PreviousRecord.Characteristic Then
			
			// Adding previous products.
			AddProductsCharacteristic(ProductsCurrent, StructureDetailing, StructureDetails, StartDate, EndDate);
			
			// Deleting current products if they do not contain data.
			If ProductsCurrent <> Undefined AND ProductsCurrent.GetItems().Count() = 0 Then
				
				ProductsItems.Delete(ProductsCurrent);
				
			EndIf;
			
			// Adding Products.
			ProductsCurrent = ProductsItems.Add();
			ProductsCurrent.Products = Selection.Products;
			
			// Adding previous products.
			AddProductsCharacteristic(ProductsCurrent, StructureDetailing, StructureDetails, StartDate, EndDate);
			
			ArrayOrders = New Array;
			StructureDetails = New Structure("Details", ArrayOrders);
			
			// Adding products and characteristics.
			StructureDetailing = New Structure("Products, Characteristic, MinInventory, MaxInventory, Deficit, Overdue", Selection.Products, Selection.Characteristic, Selection.MinInventory, Selection.MaxInventory);
			
			// Overdue.
			StructureDetailing.Overdue = New Structure("IndicatorValue, Overdue, Detailing", 0, False);
			StructureDetailing.Overdue.Detailing = New Structure("OpeningBalance, Receipt, Demand, MinInventory, MaxInventory, ClosingBalance", 0, 0, 0, 0, 0, 0);
			
			// Deficit.
			StructureDetailing.Deficit = New Structure("IndicatorValue, Overdue, Detailing", 0, False);
			StructureDetailing.Deficit.Detailing = New Structure("OpeningBalance, Receipt, Demand, MinInventory, MaxInventory, ClosingBalance", 0, 0, 0, 0, 0, 0);
			
			// Saving current column for which the calculation is made.
			PreviousColumn = StructureDetailing.Overdue;
			
		EndIf;
					
		StructureDetails.Details.Add(Selection.OrderDetails);
						
		// Record with a period equal to the period start contains overdue items.
		If Selection.Period = StartDate Then
			
			// Setting the values of overdue indicators.
			StructureDetailing.Overdue.Detailing.Insert("OpeningBalance", Selection.AvailableBalance);
			StructureDetailing.Overdue.Detailing.Insert("Receipt", Selection.ReceiptOverdue);
			StructureDetailing.Overdue.Detailing.Insert("Demand", Selection.NeedOverdue);
			StructureDetailing.Overdue.Detailing.Insert("MinInventory", Selection.MinInventory);
			StructureDetailing.Overdue.Detailing.Insert("MaxInventory", ?(Selection.MaxInventory = 0, Selection.MinInventory, Selection.MaxInventory));
			StructureDetailing.Overdue.Detailing.Insert("ClosingBalance", StructureDetailing.Overdue.Detailing.OpeningBalance + StructureDetailing.Overdue.Detailing.Receipt - StructureDetailing.Overdue.Detailing.Demand);
			
			// Calculation of overdue deficit.
			IsOverdueDeficit = StructureDetailing.Overdue.Detailing.MinInventory >= StructureDetailing.Overdue.Detailing.ClosingBalance;
			
			If IsOverdueDeficit Then
				
				StructureDetailing.Overdue.IndicatorValue = StructureDetailing.Overdue.Detailing.MaxInventory - StructureDetailing.Overdue.Detailing.ClosingBalance;
				StructureDetailing.Overdue.Overdue = True;
				
			EndIf;
			
			// Setting the values of deficit indicators.
			FillPropertyValues(StructureDetailing.Deficit.Detailing, StructureDetailing.Overdue.Detailing);
			
			// Calculation of the general deficit.
			IsCommonDeficiency = StructureDetailing.Deficit.Detailing.MinInventory >= StructureDetailing.Deficit.Detailing.ClosingBalance;
			
			If IsCommonDeficiency Then
				
				StructureDetailing.Deficit.IndicatorValue = StructureDetailing.Deficit.Detailing.MaxInventory - StructureDetailing.Deficit.Detailing.ClosingBalance;
				
			EndIf;
			
			// Saving current column for which the calculation is made.
			PreviousColumn = StructureDetailing.Overdue;
			
		EndIf;
			
		// Record of a scheduled period.
		If Selection.Period >= StartDate Then
			
			ColumnName = "Period" + Format(Selection.Period, "DF=yyyyMMdd");
			
			StructureDetailing.Insert(ColumnName, New Structure("IndicatorValue, Overdue, Detailing", 0, False));
			StructureDetailing[ColumnName].Detailing = New Structure("OpeningBalance, Receipt, Demand, MinInventory, MaxInventory, ClosingBalance", 0, 0, 0, 0, 0, 0);
			
			// Setting the values of indicators in the target period.
			StructureDetailing[ColumnName].Detailing.OpeningBalance = PreviousColumn.IndicatorValue + PreviousColumn.Detailing.ClosingBalance;
			StructureDetailing[ColumnName].Detailing.Receipt = Selection.Receipt;
			StructureDetailing[ColumnName].Detailing.Demand = Selection.Demand;
			StructureDetailing[ColumnName].Detailing.MinInventory = PreviousColumn.Detailing.MinInventory;
			StructureDetailing[ColumnName].Detailing.MaxInventory = ?(PreviousColumn.Detailing.MaxInventory = 0, PreviousColumn.Detailing.MinInventory, PreviousColumn.Detailing.MaxInventory);
			StructureDetailing[ColumnName].Detailing.ClosingBalance = StructureDetailing[ColumnName].Detailing.OpeningBalance + StructureDetailing[ColumnName].Detailing.Receipt - StructureDetailing[ColumnName].Detailing.Demand;
			
			// Setting the values of deficit indicators.
			StructureDetailing.Deficit.Detailing.Receipt = StructureDetailing.Deficit.Detailing.Receipt + StructureDetailing[ColumnName].Detailing.Receipt;
			StructureDetailing.Deficit.Detailing.Demand = StructureDetailing.Deficit.Detailing.Demand + StructureDetailing[ColumnName].Detailing.Demand;
			StructureDetailing.Deficit.Detailing.ClosingBalance = StructureDetailing.Deficit.Detailing.OpeningBalance + StructureDetailing.Deficit.Detailing.Receipt - StructureDetailing.Deficit.Detailing.Demand;
			
			// Calculation of the deficit for the period.
			IsShortageByPeriod = StructureDetailing[ColumnName].Detailing.MinInventory >= StructureDetailing[ColumnName].Detailing.ClosingBalance;
			
			If IsShortageByPeriod Then
			
				StructureDetailing[ColumnName].IndicatorValue = StructureDetailing[ColumnName].Detailing.MaxInventory - StructureDetailing[ColumnName].Detailing.ClosingBalance;
				StructureDetailing[ColumnName].Overdue = Selection.Overdue;
				
			Else
				
				StructureDetailing[ColumnName].IndicatorValue = 0;
				StructureDetailing[ColumnName].Overdue = Selection.Overdue;
				
			EndIf;
			
			// Calculation of the general deficit.
			IsCommonDeficiency = StructureDetailing.Deficit.Detailing.MinInventory >= StructureDetailing.Deficit.Detailing.ClosingBalance;
			
			If IsCommonDeficiency Then
				
				StructureDetailing.Deficit.IndicatorValue = StructureDetailing.Deficit.Detailing.MaxInventory - StructureDetailing.Deficit.Detailing.ClosingBalance;
				
			Else
				
				StructureDetailing.Deficit.IndicatorValue = 0;
				
			EndIf;
			
			// Saving current column for which the calculation is made.
			PreviousColumn = StructureDetailing[ColumnName];
				
		EndIf;
							
		// Saving current values of selection fields.
		FillPropertyValues(PreviousRecord, Selection);
		
		// Last record in the selection.
		If RecNo = RecCountInSample Then
			
			// Adding current products.
			AddProductsCharacteristic(ProductsCurrent, StructureDetailing, StructureDetails, StartDate, EndDate);
			
			// Deleting current products if they do not contain data.
			If ProductsCurrent <> Undefined AND ProductsCurrent.GetItems().Count() = 0 Then
				
				ProductsItems.Delete(ProductsCurrent);
				
			EndIf;
			
		EndIf;
				
	EndDo;	
		
EndProcedure

&AtServer
// The procedure receives the actual kind of counterparty prices.
//
Function GetActualSupplierPriceTypes()
	
	PriceTypesLis = New ValueList();
	
	Query = New Query;
	Query.Text =
	"SELECT DISTINCT
	|	CounterpartyPricesSliceLast.SupplierPriceTypes AS SupplierPriceTypes
	|FROM
	|	InformationRegister.CounterpartyPrices.SliceLast(&StartDate, SupplierPriceTypes.Owner = &Counterparty) AS CounterpartyPricesSliceLast
	|WHERE
	|	CounterpartyPricesSliceLast.Actuality";
	
	Query.SetParameter("StartDate", BegOfDay(CurrentDate()));
	Query.SetParameter("Counterparty", Counterparty);
	
	Result = Query.Execute();
	Selection = Result.Select();
	While Selection.Next() Do
		PriceTypesLis.Add(Selection.SupplierPriceTypes);
	EndDo;
	
	Return PriceTypesLis;
	
EndFunction

&AtServer
// The procedure adds products and the characteristic.
//
Procedure AddProductsCharacteristic(ProductsCurrent, StructureDetailing, StructureDetails, StartDate, EndDate)
	
	If StructureDetailing = Undefined Then
		Return;
	EndIf;
				
	If OnlyDeficit AND StructureDetailing.Deficit.IndicatorValue > 0 
		OR Not OnlyDeficit AND IndicatorsFilled(StructureDetailing) Then
		
		ProductsItems = ProductsCurrent.GetItems();
						
		// Adding the indicator values.
		OpeningBalance = ProductsItems.Add();
		OpeningBalance.Products = NStr("en = 'Opening balance'");
		
		Receipt = ProductsItems.Add();
		Receipt.Products = NStr("en = 'Receipt'");
		
		Demand = ProductsItems.Add();
		Demand.Products = NStr("en = 'Dispatch'");
				
		If StructureDetailing.MinInventory = 0 AND StructureDetailing.MaxInventory = 0 Then
			
			RegulatoryInventory = Undefined;
			MaxInventory = Undefined;
			
		Else
			
			MinInventory = ProductsItems.Add();
			MinInventory.Products = NStr("en = 'Reorder point'");
			
			MaxInventory = ProductsItems.Add();
			MaxInventory.Products = NStr("en = 'Max level'");
			
		EndIf;	
		
		ClosingBalance = ProductsItems.Add();
		ClosingBalance.Products = NStr("en = 'Closing balance'");
		
		ItemsReceipt = Receipt.GetItems();
		ItemsNeedFor = Demand.GetItems();
		
		OrdersArrayReceipt = New Array();
		OrdersArrayNeed = New Array();
		For Each RowDetails In StructureDetails.Details Do
			For Each RowOrder In RowDetails Do
				
				If (RowOrder.Value.Receipt <> 0 OR RowOrder.Value.ReceiptOverdue <> 0) AND OrdersArrayReceipt.Find(RowOrder.Key) = Undefined Then
					
					OrderDetails = ItemsReceipt.Add();
					OrderDetails.Products = RowOrder.Key;
					OrdersArrayReceipt.Add(RowOrder.Key);
					
				EndIf;	
				
				ItemsReceiptOverdue = Receipt.GetItems();
				For Each RowReceiptOutdated In ItemsReceiptOverdue Do
						
					If RowReceiptOutdated.Products = RowOrder.Key Then
						
						If RowOrder.Value.ReceiptOverdue <> 0 Then
						
							RowReceiptOutdated.Overdue = RowReceiptOutdated.Overdue + RowOrder.Value.ReceiptOverdue;
							
						EndIf;	
						
						If RowOrder.Value.Receipt <> 0 Then
						
							RowReceiptOutdated[RowOrder.Value.Period] = RowReceiptOutdated[RowOrder.Value.Period] + RowOrder.Value.Receipt;
							
						EndIf;
					
						If StructureDetailing.Deficit.IndicatorValue <> 0 Then
								
							RowReceiptOutdated.Deficit = RowReceiptOutdated.Deficit + RowOrder.Value.ReceiptOverdue + RowOrder.Value.Receipt;
								
						EndIf;
						
					EndIf;	
					
				EndDo;
				
				If (RowOrder.Value.Demand <> 0 OR RowOrder.Value.NeedOverdue <> 0) AND OrdersArrayNeed.Find(RowOrder.Key) = Undefined Then
					
					OrderDetails = ItemsNeedFor.Add();
					OrderDetails.Products = RowOrder.Key;
					OrdersArrayNeed.Add(RowOrder.Key);
					
				EndIf;
				
				ItemsNeedForOverdue = Demand.GetItems();
				For Each StringNeedOverdue In ItemsNeedForOverdue Do
						
					If StringNeedOverdue.Products = RowOrder.Key Then
						
						If RowOrder.Value.NeedOverdue <> 0 Then
						
							StringNeedOverdue.Overdue = StringNeedOverdue.Overdue + RowOrder.Value.NeedOverdue;
						
						EndIf;
						
						If RowOrder.Value.Demand <> 0 Then
						
							StringNeedOverdue[RowOrder.Value.Period] = StringNeedOverdue[RowOrder.Value.Period] + RowOrder.Value.Demand;
						    							
						EndIf;
						
						If StructureDetailing.Deficit.IndicatorValue <> 0 Then
							
							StringNeedOverdue.Deficit = StringNeedOverdue.Deficit + RowOrder.Value.NeedOverdue + RowOrder.Value.Demand;
							
						EndIf;	
						
					EndIf;	
												
				EndDo;
				
			EndDo;				
		EndDo;
		
		For Each Column In StructureDetailing Do
			
			If TypeOf(Column.Value) = Type("Structure") Then
				
				If Column.Key = "Overdue" Then
					
					OpeningBalance[Column.Key] = ?(Column.Value.IndicatorValue > 0 OR Column.Value.Detailing.Receipt > 0 OR Column.Value.Detailing.Demand > 0, Column.Value.Detailing.OpeningBalance, 0);
					
					Receipt[Column.Key] = Column.Value.Detailing.Receipt;
					Demand[Column.Key] = Column.Value.Detailing.Demand;
					
					If MinInventory <> Undefined Then
						
						MinInventory[Column.Key] = ?(Column.Value.IndicatorValue > 0, Column.Value.Detailing.MinInventory, 0);
						
					EndIf;
					
					If MaxInventory <> Undefined Then
						
						MaxInventory[Column.Key] = ?(Column.Value.IndicatorValue > 0, Column.Value.Detailing.MaxInventory, 0);
						
					EndIf;
										
					ClosingBalance[Column.Key] = ?(Column.Value.IndicatorValue > 0 OR Column.Value.Detailing.Receipt > 0 OR Column.Value.Detailing.Demand > 0, Column.Value.Detailing.ClosingBalance, 0);
					
				ElsIf Column.Key = "Deficit" Then
					
					OpeningBalance[Column.Key] = ?(Column.Value.IndicatorValue > 0, Column.Value.Detailing.OpeningBalance, 0);
					Receipt[Column.Key] = ?(Column.Value.IndicatorValue > 0, Column.Value.Detailing.Receipt, 0);
					Demand[Column.Key] = ?(Column.Value.IndicatorValue > 0, Column.Value.Detailing.Demand, 0);
										
					If MinInventory <> Undefined Then
						
						MinInventory[Column.Key] = ?(Column.Value.IndicatorValue > 0, Column.Value.Detailing.MinInventory, 0);
						
					EndIf;
					
					If MaxInventory <> Undefined Then
						
						MaxInventory[Column.Key] = ?(Column.Value.IndicatorValue > 0, Column.Value.Detailing.MaxInventory, 0);
						
					EndIf;
									
					ClosingBalance[Column.Key] = ?(Column.Value.IndicatorValue > 0, Column.Value.Detailing.ClosingBalance, 0);
					
				Else
					
					OpeningBalance[Column.Key] = Column.Value.Detailing.OpeningBalance;
					Receipt[Column.Key] = Column.Value.Detailing.Receipt;
					Demand[Column.Key] = Column.Value.Detailing.Demand;
					
					If MinInventory <> Undefined Then
						
						MinInventory[Column.Key] = Column.Value.Detailing.MinInventory;
						
					EndIf;
					
					If MaxInventory <> Undefined Then
						
						MaxInventory[Column.Key] = Column.Value.Detailing.MaxInventory;
						
					EndIf;
										
					ClosingBalance[Column.Key] = Column.Value.Detailing.ClosingBalance;
					
				EndIf;
				
				ProductsCurrent[Column.Key] = Column.Value.IndicatorValue;
												
				// Setting the formatting variant.
				ProductsCurrent["VariantRegistration" + Column.Key] = ?(StructureDetailing[Column.Key].IndicatorValue > 0, ?(StructureDetailing[Column.Key].Overdue, 2, 1), 0);
				ProductsCurrent.VariantProductsDesignCharacteristic = Max(ProductsCurrent.VariantProductsDesignCharacteristic, ProductsCurrent["VariantRegistration" + Column.Key]);
				
			Else
				
				ProductsCurrent[Column.Key] = Column.Value;
				
			EndIf;
			
		EndDo;
				
	EndIf;
	
	StructureDetailing = Undefined;
	
EndProcedure

&AtServer
// The function checks the completion of detailed data.
//
Function IndicatorsFilled(NewProductsCharacteristic)
	
	IndicatorsFilled = False;
	
	For Each Column In NewProductsCharacteristic Do
		
		If TypeOf(Column.Value) = Type("Structure") Then
			
			If Column.Value.Detailing.OpeningBalance <> 0
				OR Column.Value.Detailing.Receipt <> 0
				OR Column.Value.Detailing.Demand <> 0
				OR Column.Value.Detailing.MinInventory <> 0
				OR Column.Value.Detailing.MaxInventory <> 0
				OR Column.Value.Detailing.ClosingBalance <> 0 Then
				
				IndicatorsFilled = True;
				Break;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	Return IndicatorsFilled;
	
EndFunction

&AtServer
// The procedure calculates the inventory transfer schedule.
//
Procedure CalculateInventoryFlowCalendar(TableQueryResult)
	
	For Each RowResultQuery In TableQueryResult Do
		
		If RowResultQuery.OrderBalance <= 0 Then
			Continue;
		EndIf;
		
		CountOrderBalance 			= RowResultQuery.OrderBalance;
		QuantityBalanceReceipt 	= RowResultQuery.OrderBalance;
		QuantityBalanceNeedFor 	= RowResultQuery.OrderBalance;
		
		SearchStructure = New Structure();
		SearchStructure.Insert("Products", RowResultQuery.Products);
		SearchStructure.Insert("Characteristic", RowResultQuery.Characteristic);
		SearchStructure.Insert("Order", RowResultQuery.Order);
		
		ResultOrders = TableQueryResult.FindRows(SearchStructure);
		For Each OrdersString In ResultOrders Do
			
			// The supplies are overdue.
			If OrdersString.MovementType = Enums.InventoryMovementTypes.Receipt Then
				
				QuantityBalanceReceipt = QuantityBalanceReceipt - OrdersString.Receipt;
				
			EndIf;
			
			If OrdersString.Receipt <> 0 Then
	
				// Receipt.
				Receipt = min(CountOrderBalance, OrdersString.Receipt);
				CountOrderBalance = CountOrderBalance - OrdersString.Receipt;
				OrdersString.Receipt = Receipt;
				
			EndIf;
			
			// The demand is overdue.
			If OrdersString.MovementType = Enums.InventoryMovementTypes.Shipment Then
				
				QuantityBalanceNeedFor = QuantityBalanceNeedFor - OrdersString.Demand;
				
			EndIf;
			
			If OrdersString.Demand <> 0 Then
				
				// Demand.
				Demand = min(CountOrderBalance, OrdersString.Demand);
				CountOrderBalance = CountOrderBalance - OrdersString.Demand;
				OrdersString.Demand = Demand;
				
			EndIf;
			
			OrdersString.OrderBalance = 0;
			
		EndDo;
		
		For Each OrdersString In ResultOrders Do
			
			If OrdersString.MovementType = Enums.InventoryMovementTypes.Receipt Then
				
				If QuantityBalanceReceipt > 0 Then
					OrdersString.ReceiptOverdue = QuantityBalanceReceipt;
					QuantityBalanceReceipt = 0;
				EndIf;
				
			EndIf;
			
			If OrdersString.MovementType = Enums.InventoryMovementTypes.Shipment Then
				
				If QuantityBalanceNeedFor > 0 Then
					OrdersString.NeedOverdue = QuantityBalanceNeedFor;
					QuantityBalanceNeedFor = 0;
				EndIf;
				
			EndIf;
			
		EndDo;
		
	EndDo;
	
EndProcedure

&AtServer
// The procedure adds the decryption for the order.
//
Procedure AddDrillDownByOrder(TableQueryResult, TableLineNeeds)
	
	TableLineNeeds.Columns.Add("OrderDetails");
	
	NewRow = Undefined;
	PreviousRecordPeriod = Undefined;
	ProductsPreviousRecord = Undefined;
	PreviousRecordCharacteristic = Undefined;
	For Each RowQueryResult In TableQueryResult Do
		
		If RowQueryResult.Period = PreviousRecordPeriod
			AND RowQueryResult.Products = ProductsPreviousRecord 
			AND RowQueryResult.Characteristic = PreviousRecordCharacteristic Then
			
			IndicatorsStructure = New Structure;
			IndicatorsStructure.Insert("Period", "Period" + Format(RowQueryResult.Period, "DF=yyyyMMdd"));
			IndicatorsStructure.Insert("Receipt", RowQueryResult.Receipt);
			IndicatorsStructure.Insert("ReceiptOverdue", RowQueryResult.ReceiptOverdue);
			IndicatorsStructure.Insert("Demand", RowQueryResult.Demand);
			IndicatorsStructure.Insert("NeedOverdue", RowQueryResult.NeedOverdue);
			
			CorrespondenceNewRow = NewRow.OrderDetails;
			CorrespondenceNewRow.Insert(RowQueryResult.Order, IndicatorsStructure);
			NewRow.OrderDetails = CorrespondenceNewRow; 
			
			NewRow.Receipt = NewRow.Receipt + RowQueryResult.Receipt;
			NewRow.ReceiptOverdue = NewRow.ReceiptOverdue + RowQueryResult.ReceiptOverdue;
			
			NewRow.Demand = NewRow.Demand + RowQueryResult.Demand;
			NewRow.NeedOverdue = NewRow.NeedOverdue + RowQueryResult.NeedOverdue;
			
		Else
			
			NewRow = TableLineNeeds.Add();
			FillPropertyValues(NewRow, RowQueryResult);
			
			IndicatorsStructure = New Structure;
			IndicatorsStructure.Insert("Period", "Period" + Format(RowQueryResult.Period, "DF=yyyyMMdd"));
			IndicatorsStructure.Insert("Receipt", RowQueryResult.Receipt);
			IndicatorsStructure.Insert("ReceiptOverdue", RowQueryResult.ReceiptOverdue);
			IndicatorsStructure.Insert("Demand", RowQueryResult.Demand);
			IndicatorsStructure.Insert("NeedOverdue", RowQueryResult.NeedOverdue);
			
			OrderDetailsMap = New Map;
			OrderDetailsMap.Insert(RowQueryResult.Order, IndicatorsStructure); 
			
			NewRow.OrderDetails = OrderDetailsMap;
			
			PreviousRecordPeriod = RowQueryResult.Period;
			ProductsPreviousRecord = RowQueryResult.Products;
			PreviousRecordCharacteristic = RowQueryResult.Characteristic;
			
		EndIf;
		
	EndDo;
	
	TableQueryResult = Undefined;
	
EndProcedure

&AtServer
// Procedure of data processing and demand diagram output to the form.
//
Procedure UpdateRecommendationsAtServer()
	
	// Clearing the result before update.
	RecommendationsItems = Recommendations.GetItems();
	RecommendationsItems.Clear();
	
	TSInventory = GetFromTempStorage(AddressInventory);
	
	DataSource = New ValueTable;
	DataSource.Columns.Add("RowIndex", New TypeDescription("Number"));
	DataSource.Columns.Add("Products", New TypeDescription("CatalogRef.Products"));
	DataSource.Columns.Add("Characteristic", New TypeDescription("CatalogRef.ProductsCharacteristics"));
	DataSource.Columns.Add("Vendor", New TypeDescription("CatalogRef.Counterparties"));
	DataSource.Columns.Add("ReplenishmentMethod", New TypeDescription("EnumRef.InventoryReplenishmentMethods"));
	DataSource.Columns.Add("ReplenishmentDeadline", New TypeDescription("Number"));
	DataSource.Columns.Add("ReplenishmentMethodPrecision", New TypeDescription("Number"));
	DataSource.Columns.Add("Quantity", New TypeDescription("Number"));
	DataSource.Columns.Add("ReceiptDate", New TypeDescription("Date"));
	
	RowIndex = 0;
	
	For Each Products In TSInventory.Rows Do
		
		If Products.Deficit > 0 Then
			
			CurrentPeriod = BegOfDay(CurrentDate());
		
			While BegOfDay(CurrentPeriod) <= BegOfDay(EndOfPeriod) Do
				
				ColumnName = "Period" + Format(CurrentPeriod, "DF=yyyyMMdd");
				
				If Products[ColumnName] > 0 OR Products.Overdue > 0 AND CurrentPeriod = BegOfDay(CurrentDate()) Then
					
					NewRow = DataSource.Add();
					NewRow.RowIndex = RowIndex;
					NewRow.Products = Products.Products;
					NewRow.Characteristic = Products.Characteristic;
					NewRow.Vendor = Products.Products.Vendor;
					NewRow.ReplenishmentMethod = Products.Products.ReplenishmentMethod;
					NewRow.ReplenishmentDeadline = Products.Products.ReplenishmentDeadline;
					NewRow.ReplenishmentMethodPrecision = 1;
					
					If CurrentPeriod = BegOfDay(CurrentDate()) Then
						
						NewRow.Quantity = Products[ColumnName] + Products.Overdue;
						
					Else
						
						NewRow.Quantity = Products[ColumnName];
						
					EndIf;
					
					NewRow.ReceiptDate = CurrentPeriod;
					
					If NewRow.ReplenishmentMethod = Enums.InventoryReplenishmentMethods.Purchase Then
						
						If Constants.UseProductionSubsystem.Get() Then
						
							NewReplenishmentMethod = DataSource.Add();
							FillPropertyValues(NewReplenishmentMethod, NewRow);
							NewReplenishmentMethod.ReplenishmentMethod = Enums.InventoryReplenishmentMethods.Production;
							NewReplenishmentMethod.ReplenishmentMethodPrecision = 2;
							
						EndIf;
						
						If Constants.UseSubcontractorManufacturers.Get() Then
						
							NewReplenishmentMethod = DataSource.Add();
							FillPropertyValues(NewReplenishmentMethod, NewRow);
							NewReplenishmentMethod.ReplenishmentMethod = Enums.InventoryReplenishmentMethods.Processing;
							NewReplenishmentMethod.ReplenishmentMethodPrecision = 3;
							
						EndIf;
						
					ElsIf NewRow.ReplenishmentMethod = Enums.InventoryReplenishmentMethods.Production Then	
						
						NewReplenishmentMethod = DataSource.Add();
						FillPropertyValues(NewReplenishmentMethod, NewRow);
						NewReplenishmentMethod.ReplenishmentMethod = Enums.InventoryReplenishmentMethods.Purchase;
						NewReplenishmentMethod.ReplenishmentMethodPrecision = 2;
						
						If Constants.UseSubcontractorManufacturers.Get() Then
						
							NewReplenishmentMethod = DataSource.Add();
							FillPropertyValues(NewReplenishmentMethod, NewRow);
							NewReplenishmentMethod.ReplenishmentMethod = Enums.InventoryReplenishmentMethods.Processing;
							NewReplenishmentMethod.ReplenishmentMethodPrecision = 3;
							
						EndIf;
						
					Else
						
						NewReplenishmentMethod = DataSource.Add();
						FillPropertyValues(NewReplenishmentMethod, NewRow);
						NewReplenishmentMethod.ReplenishmentMethod = Enums.InventoryReplenishmentMethods.Purchase;
						NewReplenishmentMethod.ReplenishmentMethodPrecision = 2;
						
						If Constants.UseProductionSubsystem.Get() Then
						
							NewReplenishmentMethod = DataSource.Add();
							FillPropertyValues(NewReplenishmentMethod, NewRow);
							NewReplenishmentMethod.ReplenishmentMethod = Enums.InventoryReplenishmentMethods.Production;
							NewReplenishmentMethod.ReplenishmentMethodPrecision = 3;
							
						EndIf;
						
					EndIf;
					
					RowIndex = RowIndex + 1;
					
				EndIf;
				
				CurrentPeriod = CurrentPeriod + 86400;
				
			EndDo;
			
		EndIf;
		
	EndDo;
	
	If DataSource.Count() = 0 Then
		
		Return;
		
	EndIf;
	
	Query = New Query(
	"SELECT
	|	DataSource.RowIndex AS RowIndex,
	|	DataSource.ReplenishmentMethodPrecision AS ReplenishmentMethodPrecision,
	|	DataSource.Products AS Products,
	|	DataSource.Characteristic AS Characteristic,
	|	DataSource.Vendor AS Vendor,
	|	DataSource.ReplenishmentMethod AS ReplenishmentMethod,
	|	DataSource.ReplenishmentDeadline AS ReplenishmentDeadline,
	|	DataSource.Quantity AS Quantity,
	|	DataSource.ReceiptDate AS ReceiptDate
	|INTO DataSource
	|FROM
	|	&DataSource AS DataSource
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	TableCounterpartyPrices.Products AS Products,
	|	TableCounterpartyPrices.Characteristic AS Characteristic,
	|	CounterpartyPricesSliceLast.SupplierPriceTypes AS PriceKind,
	|	CounterpartyPricesSliceLast.SupplierPriceTypes.Owner AS Vendor,
	|	CounterpartyPricesSliceLast.SupplierPriceTypes.PriceCurrency AS PriceCurrency,
	|	ISNULL(CounterpartyPricesSliceLast.Price / ISNULL(CounterpartyPricesSliceLast.MeasurementUnit.Factor, 1), 0) AS Price
	|INTO DataSourcePricesCounterparties
	|FROM
	|	DataSource AS TableCounterpartyPrices
	|		LEFT JOIN InformationRegister.CounterpartyPrices.SliceLast(
	|				&ProcessingDate,
	|				(Products, Characteristic) In
	|					(SELECT
	|						DataSource.Products AS Products,
	|						DataSource.Characteristic AS Characteristic
	|					FROM
	|						DataSource AS DataSource)) AS CounterpartyPricesSliceLast
	|		ON TableCounterpartyPrices.Products = CounterpartyPricesSliceLast.Products
	|			AND TableCounterpartyPrices.Characteristic = CounterpartyPricesSliceLast.Characteristic
	|WHERE
	|	CounterpartyPricesSliceLast.Actuality
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	1 AS Order,
	|	DataSource.RowIndex AS RowIndex,
	|	DataSource.ReplenishmentMethodPrecision AS ReplenishmentMethodPrecision,
	|	DataSource.Products AS Products,
	|	DataSource.Characteristic AS Characteristic,
	|	DataSource.Vendor AS Vendor,
	|	DataSource.ReplenishmentMethod AS ReplenishmentMethod,
	|	DataSource.ReplenishmentDeadline AS ReplenishmentDeadline,
	|	DataSource.Quantity AS Quantity,
	|	DataSource.ReceiptDate AS ReceiptDate,
	|	DataSourcePricesCounterparties.PriceKind AS PriceKind,
	|	DataSourcePricesCounterparties.PriceCurrency AS PriceCurrency,
	|	ISNULL(DataSourcePricesCounterparties.Price, 0) AS Price
	|FROM
	|	DataSource AS DataSource
	|		LEFT JOIN DataSourcePricesCounterparties AS DataSourcePricesCounterparties
	|		ON DataSource.Vendor = DataSourcePricesCounterparties.Vendor
	|			AND DataSource.Products = DataSourcePricesCounterparties.Products
	|			AND DataSource.Characteristic = DataSourcePricesCounterparties.Characteristic
	|			AND (DataSource.ReplenishmentMethod = VALUE(Enum.InventoryReplenishmentMethods.Purchase))
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	DataSource.RowIndex,
	|	DataSource.ReplenishmentMethodPrecision,
	|	DataSource.Products,
	|	DataSource.Characteristic,
	|	DataSourcePricesCounterparties.Vendor,
	|	DataSource.ReplenishmentMethod,
	|	DataSource.ReplenishmentDeadline,
	|	DataSource.Quantity,
	|	DataSource.ReceiptDate,
	|	DataSourcePricesCounterparties.PriceKind,
	|	DataSourcePricesCounterparties.PriceCurrency,
	|	ISNULL(DataSourcePricesCounterparties.Price, 0)
	|FROM
	|	DataSource AS DataSource
	|		LEFT JOIN DataSourcePricesCounterparties AS DataSourcePricesCounterparties
	|		ON DataSource.Vendor <> DataSourcePricesCounterparties.Vendor
	|			AND DataSource.Products = DataSourcePricesCounterparties.Products
	|			AND DataSource.Characteristic = DataSourcePricesCounterparties.Characteristic
	|			AND (DataSource.ReplenishmentMethod = VALUE(Enum.InventoryReplenishmentMethods.Purchase))
	|WHERE
	|	ISNULL(DataSourcePricesCounterparties.Price, 0) <> 0
	|
	|ORDER BY
	|	RowIndex,
	|	ReplenishmentMethodPrecision,
	|	Order,
	|	PriceKind");
	
	Query.SetParameter("DataSource", DataSource);
	Query.SetParameter("ProcessingDate", BegOfDay(CurrentDate()));
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	
	ProductsItems = Recommendations.GetItems();
	
	RowCurrentIndex = Undefined;
	While Selection.Next() Do

		// 1. Adding products.
		If RowCurrentIndex <> Selection.RowIndex Then
			
			RowCurrentIndex = Selection.RowIndex;
			
			NewProducts = ProductsItems.Add();
			NewProducts.Products = Selection.Products;
			NewProducts.CharacteristicInventoryReplenishmentSource = Selection.Characteristic;
			NewProducts.Quantity = Selection.Quantity;
			NewProducts.ReceiptDate = Selection.ReceiptDate;
			NewProducts.ReceiptDateExpired = True;
			
			NewProducts.EditAllowed = False;
			
		EndIf;
		
		// 2. Adding replenishment method and prices.
		ReplenishmentMethodItems = NewProducts.GetItems();
		NewReplenishmentMethod = ReplenishmentMethodItems.Add();
		
		If Selection.ReplenishmentMethodPrecision = 1 Then
			NewReplenishmentMethod.Products = String(Selection.ReplenishmentMethod) + " " + "(Default)";
		Else
			NewReplenishmentMethod.Products = String(Selection.ReplenishmentMethod);
		EndIf;
		
		NewReplenishmentMethod.ReplenishmentMethod = Selection.ReplenishmentMethod;
		
		NewReplenishmentMethod.Quantity = Selection.Quantity;
		NewReplenishmentMethod.ReceiptDate =  Max(BegOfDay(CurrentDate()) + Selection.ReplenishmentDeadline * 86400, Selection.ReceiptDate);
		NewReplenishmentMethod.ReceiptDateExpired = NewReplenishmentMethod.ReceiptDate > Selection.ReceiptDate;
		NewReplenishmentMethod.EditAllowed = True;
		
		If Selection.ReplenishmentMethod = Enums.InventoryReplenishmentMethods.Purchase Then
			
			NewReplenishmentMethod.CharacteristicInventoryReplenishmentSource = Selection.Vendor;
			NewReplenishmentMethod.Price = Selection.Price;
			NewReplenishmentMethod.Amount = Selection.Price * Selection.Quantity;
			NewReplenishmentMethod.Currency = Selection.PriceCurrency;
			NewReplenishmentMethod.PriceKind = Selection.PriceKind;
			
		EndIf;
		
		// 3. Formatting parameters.
		If Not NewReplenishmentMethod.ReceiptDateExpired Then
			
			NewProducts.ReceiptDateExpired = False;
			NewProducts.DemandClosed = True;
			
			If Not NewProducts.Selected Then
				
				NewReplenishmentMethod.Selected = True;
				NewProducts.Selected = True;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	DataSource = Undefined;
	
EndProcedure

&AtServer
// The procedure of data processing and orders generation.
//
Procedure GenerateOrdersAtServer()
	
	TableOrders = New ValueTable;
	TableOrders.Columns.Add("ReplenishmentMethod", New TypeDescription("EnumRef.InventoryReplenishmentMethods"));
	TableOrders.Columns.Add("Counterparty", New TypeDescription("CatalogRef.Counterparties"));
	TableOrders.Columns.Add("PriceKind", New TypeDescription("CatalogRef.SupplierPriceTypes"));
	TableOrders.Columns.Add("Currency", New TypeDescription("CatalogRef.Currencies"));
	TableOrders.Columns.Add("Products", New TypeDescription("CatalogRef.Products"));
	TableOrders.Columns.Add("Characteristic", New TypeDescription("CatalogRef.ProductsCharacteristics"));
	TableOrders.Columns.Add("ReceiptDate", New TypeDescription("Date"));
	TableOrders.Columns.Add("Quantity", New TypeDescription("Number"));
	TableOrders.Columns.Add("Price", New TypeDescription("Number"));
	TableOrders.Columns.Add("Amount", New TypeDescription("Number"));
	TableOrders.Columns.Add("Order", New TypeDescription("DocumentObject.ProductionOrder, DocumentObject.PurchaseOrder"));
	
	RecommendationsProducts = Recommendations.GetItems();
	For Each RecommendationRow In RecommendationsProducts Do
		
		RecommendationsItems = RecommendationRow.GetItems();
		
		For Each StringProducts In RecommendationsItems Do
			
			If StringProducts.Selected Then
				
				NewRow = TableOrders.Add();
				NewRow.ReplenishmentMethod = StringProducts.ReplenishmentMethod;
				NewRow.Counterparty = StringProducts.CharacteristicInventoryReplenishmentSource;
				NewRow.PriceKind = StringProducts.PriceKind;
				NewRow.Currency = StringProducts.Currency;
				NewRow.Products = RecommendationRow.Products;
				NewRow.Characteristic = RecommendationRow.CharacteristicInventoryReplenishmentSource;
				NewRow.ReceiptDate = StringProducts.ReceiptDate;
				NewRow.Quantity = StringProducts.Quantity;
				NewRow.Price = StringProducts.Price;
				
			EndIf;
			
		EndDo;
		
	EndDo;
	
	ReceiptDateInHead = DriveReUse.AttributeInHeader("ReceiptDatePositionInPurchaseOrder");
	
	DocumentCurrencyDefault = Constants.FunctionalCurrency.Get();
	DataCurrency = WorkWithExchangeRates.FillRateDataForCurrencies(DocumentCurrencyDefault);
	ExchangeRateDocumentDefault = DataCurrency.ExchangeRate;
	RepetitionDocumentDefault = DataCurrency.Multiplicity;
	
	For Each OrderParameters In TableOrders Do
		
		// Create the purchase orders.
		If OrderParameters.ReplenishmentMethod = Enums.InventoryReplenishmentMethods.Purchase
			OR OrderParameters.ReplenishmentMethod = Enums.InventoryReplenishmentMethods.Processing Then
			
			SearchStructure = New Structure("ReplenishmentMethod, Counterparty, Currency, Order", OrderParameters.ReplenishmentMethod, OrderParameters.Counterparty, OrderParameters.Currency, Undefined);
			
			If ReceiptDateInHead Then
				SearchStructure.Insert("ReceiptDate", OrderParameters.ReceiptDate);
			EndIf;
			
			SearchResult = TableOrders.FindRows(SearchStructure);
			
			If SearchResult.Count() = 0 Then
				Continue;
			EndIf;
			
			CurrentOrder = Documents.PurchaseOrder.CreateDocument();
			CurrentOrder.Date = CurrentDate();
			
			CurrentOrder.Fill(Undefined);
			
			If OrderParameters.ReplenishmentMethod = Enums.InventoryReplenishmentMethods.Purchase Then
				CurrentOrder.OperationKind = Enums.OperationTypesPurchaseOrder.OrderForPurchase;
			Else
				CurrentOrder.OperationKind = Enums.OperationTypesPurchaseOrder.OrderForProcessing;
			EndIf;
			
			DriveServer.FillDocumentHeader(CurrentOrder,,,, True, );
			
			CurrentOrder.Company = Company;
			CurrentOrder.DocumentCurrency = DocumentCurrencyDefault;
			CurrentOrder.ExchangeRate = ExchangeRateDocumentDefault;
			CurrentOrder.Multiplicity = RepetitionDocumentDefault;
			
			CurrentOrder.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT;
			CurrentOrder.AmountIncludesVAT = True;
			
			CurrentOrder.Counterparty = OrderParameters.Counterparty;
			ContractByDefault = CurrentOrder.Counterparty.ContractByDefault;
			
			If Not ValueIsFilled(OrderParameters.Currency) Then
				
				CurrentOrder.Contract = ContractByDefault;
				
			Else
				
				If OrderParameters.Currency = ContractByDefault.SettlementsCurrency Then
					
					CurrentOrder.Contract = ContractByDefault;
					
				Else
					
					CurrentOrder.Contract = Catalogs.CounterpartyContracts.EmptyRef();
					
					CurrentOrder.DocumentCurrency = OrderParameters.Currency;
					DataCurrency = WorkWithExchangeRates.FillRateDataForCurrencies(CurrentOrder.DocumentCurrency);
					CurrentOrder.ExchangeRate = DataCurrency.ExchangeRate;
					CurrentOrder.Multiplicity = DataCurrency.Multiplicity;
					
				EndIf;
				
			EndIf;
			
			CurrentOrder.SupplierPriceTypes = CurrentOrder.Contract.SupplierPriceTypes;
			
			If ValueIsFilled(CurrentOrder.Contract) AND Not CurrentOrder.Contract.SettlementsCurrency = CurrentOrder.DocumentCurrency Then
				
				CurrentOrder.DocumentCurrency = CurrentOrder.Contract.SettlementsCurrency;
				DataCurrency = WorkWithExchangeRates.FillRateDataForCurrencies(CurrentOrder.DocumentCurrency);
				CurrentOrder.ExchangeRate = DataCurrency.ExchangeRate;
				CurrentOrder.Multiplicity = DataCurrency.Multiplicity;
				
			EndIf;
			
			If ReceiptDateInHead Then
				CurrentOrder.ReceiptDate = OrderParameters.ReceiptDate;
			EndIf;
			
			For Each ResultRow In SearchResult Do
				
				NewRow = CurrentOrder.Inventory.Add();
				NewRow.Products = ResultRow.Products;
				NewRow.Characteristic = ResultRow.Characteristic;
				NewRow.Quantity = ResultRow.Quantity;
				NewRow.MeasurementUnit = NewRow.Products.MeasurementUnit;
				
				If ValueIsFilled(NewRow.Products.VATRate) Then
					NewRow.VATRate = NewRow.Products.VATRate;
				Else
					NewRow.VATRate = InformationRegisters.AccountingPolicy.GetDefaultVATRate(Object.Date, Object.Company);
				EndIf;
				
				If ValueIsFilled(OrderParameters.PriceKind) Then
					
					NewRow.Price = ResultRow.Price;
					
					VATRate = DriveReUse.GetVATRateValue(NewRow.VATRate);
					If Not ResultRow.PriceKind.PriceIncludesVAT Then
						NewRow.Price = (NewRow.Price * (100 + VATRate)) / 100;
					EndIf;
					
					NewRow.Amount = NewRow.Price * NewRow.Quantity;
					NewRow.VATAmount = NewRow.Amount - (NewRow.Amount) / ((VATRate + 100) / 100);
					NewRow.Total = NewRow.Amount;
					
				EndIf;
				
				NewRow.ReceiptDate = ResultRow.ReceiptDate;
				
				ResultRow.Order = CurrentOrder;
				
			EndDo;
			
		Else // We will create orders for production.
			
			SearchStructure = New Structure("ReplenishmentMethod, Order", OrderParameters.ReplenishmentMethod, Undefined);
			
			SearchResult = TableOrders.FindRows(SearchStructure);
			
			If SearchResult.Count() = 0 Then
				Continue;
			EndIf;
			
			CurrentOrder = Documents.ProductionOrder.CreateDocument();
			CurrentOrder.Date = CurrentDate();
			
			CurrentOrder.OperationKind = Enums.OperationTypesProductionOrder.Assembly;
			
			DriveServer.FillDocumentHeader(CurrentOrder,,,, True, );
			
			CurrentOrder.Company = Company;
			CurrentOrder.Start = OrderParameters.ReceiptDate - 86400 * OrderParameters.Products.ReplenishmentDeadline;
			CurrentOrder.Finish = OrderParameters.ReceiptDate;
			
			For Each ResultRow In SearchResult Do
				
				NewRow = CurrentOrder.Products.Add();
				NewRow.Products = ResultRow.Products;
				NewRow.Characteristic = ResultRow.Characteristic;
				NewRow.Quantity = ResultRow.Quantity;
				NewRow.MeasurementUnit = NewRow.Products.MeasurementUnit;
				NewRow.Specification = DriveServer.GetDefaultSpecification(NewRow.Products, NewRow.Characteristic);
				
				ResultRow.Order = CurrentOrder;
				
			EndDo;
			
			FillingData = New Structure("DemandPlanning", True);
			CurrentOrder.Fill(FillingData);
			
		EndIf;
		
		CurrentOrder.Comment = NStr("en = 'Automatically generated by the ""Demand planning"".'");
		
		CurrentOrder.Write();
		GeneratedOrder = Orders.Add();
		GeneratedOrder.Order = CurrentOrder.Ref;
		GeneratedOrder.DefaultPicture = 0;
		
	EndDo;
	
EndProcedure

&AtServerNoContext
// The function returns the result of posting.
//
Function OrdersPostAtServer(OrdersForPosting)
	
	PostingResults = New Array;
	
	For Each OrderForPosting In OrdersForPosting Do
	
		OrderObject = OrderForPosting.Ref.GetObject();
		
		If Not OrderObject.DeletionMark Then
			
			If OrderObject.CheckFilling() Then
			
				Try
					
					OrderObject.Write(DocumentWriteMode.Posting);
					PostingResults.Add(OrderForPosting.IndexOf);
					
				Except
				EndTry;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	Return PostingResults;
	
EndFunction

&AtServerNoContext
// The function returns the result of posting cancellation.
//
Function OrdersUndoPostingAtServer(OrdersForUndoPosting)
	
	UndoPostingResults = New Array;
	
	For Each OrderForUndoPosting In OrdersForUndoPosting Do
	
		OrderObject = OrderForUndoPosting.Ref.GetObject();
		
		If Not OrderObject.DeletionMark Then
			
			Try
				
				OrderObject.Write(DocumentWriteMode.UndoPosting);
				UndoPostingResults.Add(OrderForUndoPosting.IndexOf);
				
			Except
			EndTry;
			
		EndIf;
		
	EndDo;
	
	Return UndoPostingResults;
	
EndFunction

&AtServerNoContext
// The function returns the result of deletion mark.
//
Function OrdersMarkToDeleteAtServer(OrdersForMarkToDelete)
	
	MarkToDeleteResults = New Array;
	
	For Each OrderForMarkToDelete In OrdersForMarkToDelete Do
	
		OrderObject = OrderForMarkToDelete.Ref.GetObject();
		
		Try
			
			OrderObject.SetDeletionMark(NOT OrderObject.DeletionMark);
			MarkToDeleteResults.Add(OrderForMarkToDelete.IndexOf);
			
		Except
		EndTry;
			
	EndDo;
	
	Return MarkToDeleteResults;
	
EndFunction

&AtServer
// Procedure sets conditional design.
//
Procedure SetConditionalAppearance(BeginOfPeriod, EndOfPeriod)
	
	ListOfItemsForDeletion = New ValueList;
	For Each ConditionalAppearanceItem In ConditionalAppearance.Items Do
		If ConditionalAppearanceItem.UserSettingID = "Preset" Then
			ListOfItemsForDeletion.Add(ConditionalAppearanceItem);
		EndIf;
	EndDo;
	For Each Item In ListOfItemsForDeletion Do
		ConditionalAppearance.Items.Delete(Item.Value);
	EndDo;
	
	// Products and the characteristic are displayed in bold.
	ConditionalAppearanceItem = ConditionalAppearance.Items.Add();
	ConditionalAppearanceItem.UserSettingID = "Preset";
	
	MadeOutField = ConditionalAppearanceItem.Fields.Items.Add();
	MadeOutField.Field = New DataCompositionField("InventoryProducts");
	
	MadeOutField = ConditionalAppearanceItem.Fields.Items.Add();
	MadeOutField.Field = New DataCompositionField("InventoryCharacteristic");
	
	FilterItemGroup = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
	FilterItemGroup.GroupType = DataCompositionFilterItemsGroupType.OrGroup;
	
	FilterItem = FilterItemGroup.Items.Add(Type("DataCompositionFilterItem"));
	
	FilterItem.LeftValue = New DataCompositionField("Inventory.FormattingVariantProductsCharacteristic");
	FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
	FilterItem.RightValue = 1;
	
	FilterItem = FilterItemGroup.Items.Add(Type("DataCompositionFilterItem"));
	
	FilterItem.LeftValue = New DataCompositionField("Inventory.FormattingVariantProductsCharacteristic");
	FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
	FilterItem.RightValue = 4;
	
	ConditionalAppearanceItem.Appearance.SetParameterValue("Font", New Font(,, True));
	
	// Deficit is highlighted in bold.
	ConditionalAppearanceItem = ConditionalAppearance.Items.Add();
	ConditionalAppearanceItem.UserSettingID = "Preset";
	
	MadeOutField = ConditionalAppearanceItem.Fields.Items.Add();
	MadeOutField.Field = New DataCompositionField("InventoryDeficit");
	
	FilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	
	FilterItem.LeftValue = New DataCompositionField("Inventory.FormattingVariantDeficit");
	FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
	FilterItem.RightValue = 1;
	
	ConditionalAppearanceItem.Appearance.SetParameterValue("Font", New Font(,, True));
	
	// Negative in the deficit is highlighted.
	ConditionalAppearanceItem = ConditionalAppearance.Items.Add();
	ConditionalAppearanceItem.UserSettingID = "Preset";
	
	MadeOutField = ConditionalAppearanceItem.Fields.Items.Add();
	MadeOutField.Field = New DataCompositionField("InventoryDeficit");
	
	FilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	
	FilterItem.LeftValue = New DataCompositionField("Inventory.Deficit");
	FilterItem.ComparisonType = DataCompositionComparisonType.Less;
	FilterItem.RightValue = 0;
	
	ConditionalAppearanceItem.Appearance.SetParameterValue("TextColor", WebColors.FireBrick);
	
	// Overdue items are highlighted in bold.
	ConditionalAppearanceItem = ConditionalAppearance.Items.Add();
	ConditionalAppearanceItem.UserSettingID = "Preset";
	
	MadeOutField = ConditionalAppearanceItem.Fields.Items.Add();
	MadeOutField.Field = New DataCompositionField("InventoryOverdue");
	
	FilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	
	FilterItem.LeftValue = New DataCompositionField("Inventory.FormattingVariantOverdue");
	FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
	FilterItem.RightValue = 1;
	
	ConditionalAppearanceItem.Appearance.SetParameterValue("Font", New Font(,, True));
	
	// Negative overdue is highlighted.
	ConditionalAppearanceItem = ConditionalAppearance.Items.Add();
	ConditionalAppearanceItem.UserSettingID = "Preset";
	
	MadeOutField = ConditionalAppearanceItem.Fields.Items.Add();
	MadeOutField.Field = New DataCompositionField("InventoryOverdue");
	
	FilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	
	FilterItem.LeftValue = New DataCompositionField("Inventory.Overdue");
	FilterItem.ComparisonType = DataCompositionComparisonType.Less;
	FilterItem.RightValue = 0;
	
	ConditionalAppearanceItem.Appearance.SetParameterValue("TextColor", WebColors.FireBrick);
	
	// Products and the characteristic are displayed in bold and highlighted.
	ConditionalAppearanceItem = ConditionalAppearance.Items.Add();
	ConditionalAppearanceItem.UserSettingID = "Preset";
	
	MadeOutField = ConditionalAppearanceItem.Fields.Items.Add();
	MadeOutField.Field = New DataCompositionField("InventoryProducts");
	
	MadeOutField = ConditionalAppearanceItem.Fields.Items.Add();
	MadeOutField.Field = New DataCompositionField("InventoryCharacteristic");
	
	FilterItemGroup = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
	FilterItemGroup.GroupType = DataCompositionFilterItemsGroupType.OrGroup;
	
	FilterItem = FilterItemGroup.Items.Add(Type("DataCompositionFilterItem"));
	
	FilterItem.LeftValue = New DataCompositionField("Inventory.FormattingVariantProductsCharacteristic");
	FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
	FilterItem.RightValue = 2;
	
	FilterItem = FilterItemGroup.Items.Add(Type("DataCompositionFilterItem"));
	
	FilterItem.LeftValue = New DataCompositionField("Inventory.FormattingVariantProductsCharacteristic");
	FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
	FilterItem.RightValue = 5;
	
	ConditionalAppearanceItem.Appearance.SetParameterValue("TextColor", WebColors.FireBrick);
	ConditionalAppearanceItem.Appearance.SetParameterValue("Font", New Font(,, True));
	
	// Deficit is highlighted in bold and color.
	ConditionalAppearanceItem = ConditionalAppearance.Items.Add();
	ConditionalAppearanceItem.UserSettingID = "Preset";
	
	MadeOutField = ConditionalAppearanceItem.Fields.Items.Add();
	MadeOutField.Field = New DataCompositionField("InventoryDeficit");
	
	FilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	
	FilterItem.LeftValue = New DataCompositionField("Inventory.FormattingVariantDeficit");
	FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
	FilterItem.RightValue = 2;
	
	ConditionalAppearanceItem.Appearance.SetParameterValue("TextColor", WebColors.FireBrick);
	ConditionalAppearanceItem.Appearance.SetParameterValue("Font", New Font(,, True));
	
	// Overdue items are highlighted in bold and color.
	ConditionalAppearanceItem = ConditionalAppearance.Items.Add();
	ConditionalAppearanceItem.UserSettingID = "Preset";
	
	MadeOutField = ConditionalAppearanceItem.Fields.Items.Add();
	MadeOutField.Field = New DataCompositionField("InventoryOverdue");
	
	FilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	
	FilterItem.LeftValue = New DataCompositionField("Inventory.FormattingVariantOverdue");
	FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
	FilterItem.RightValue = 2;
	
	ConditionalAppearanceItem.Appearance.SetParameterValue("TextColor", WebColors.FireBrick);
	ConditionalAppearanceItem.Appearance.SetParameterValue("Font", New Font(,, True));
	
	// Decryption overdue is displayed in the background color.
	ConditionalAppearanceItem = ConditionalAppearance.Items.Add();
	ConditionalAppearanceItem.UserSettingID = "Preset";
	
	MadeOutField = ConditionalAppearanceItem.Fields.Items.Add();
	MadeOutField.Field = New DataCompositionField("InventoryOverdue");
	
	FilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	
	FilterItem.LeftValue = New DataCompositionField("Inventory.Overdue");
	FilterItem.ComparisonType = DataCompositionComparisonType.Greater;
	FilterItem.RightValue = 0;
	
	FilterItemGroup = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
	FilterItemGroup.GroupType = DataCompositionFilterItemsGroupType.OrGroup;
	
	FilterItem = FilterItemGroup.Items.Add(Type("DataCompositionFilterItem"));
	
	FilterItem.LeftValue = New DataCompositionField("Inventory.Products");
	FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
	FilterItem.RightValue = NStr("en = 'Receipt'");
	
	FilterItem = FilterItemGroup.Items.Add(Type("DataCompositionFilterItem"));
	
	FilterItem.LeftValue = New DataCompositionField("Inventory.Products");
	FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
	FilterItem.RightValue = NStr("en = 'Token expiration date'");
	
	ConditionalAppearanceItem.Appearance.SetParameterValue("BackColor", WebColors.LightGray);
	
	CurrentPeriod = BeginOfPeriod;
	
	While BegOfDay(CurrentPeriod) <= BegOfDay(EndOfPeriod) Do
		
		// The period is bold.
		ConditionalAppearanceItem = ConditionalAppearance.Items.Add();
		ConditionalAppearanceItem.UserSettingID = "Preset";
		
		MadeOutField = ConditionalAppearanceItem.Fields.Items.Add();
		MadeOutField.Field = New DataCompositionField("InventoryPeriod" + Format(CurrentPeriod, "DF=yyyyMMdd"));
		
		FilterItemGroup = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
		FilterItemGroup.GroupType = DataCompositionFilterItemsGroupType.OrGroup;
		
		FilterItem = FilterItemGroup.Items.Add(Type("DataCompositionFilterItem"));
		
		FilterItem.LeftValue = New DataCompositionField("Inventory.FormattingVariantPeriod" + Format(CurrentPeriod, "DF=yyyyMMdd"));
		FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
		FilterItem.RightValue = 1;
		
		FilterItem = FilterItemGroup.Items.Add(Type("DataCompositionFilterItem"));
		
		FilterItem.LeftValue = New DataCompositionField("Inventory.FormattingVariantPeriod" + Format(CurrentPeriod, "DF=yyyyMMdd"));
		FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
		FilterItem.RightValue = 4;
		
		ConditionalAppearanceItem.Appearance.SetParameterValue("Font", New Font(,, True));
		
		// Negative in the period is highlighted.
		ConditionalAppearanceItem = ConditionalAppearance.Items.Add();
		ConditionalAppearanceItem.UserSettingID = "Preset";
		
		MadeOutField = ConditionalAppearanceItem.Fields.Items.Add();
		MadeOutField.Field = New DataCompositionField("InventoryPeriod" + Format(CurrentPeriod, "DF=yyyyMMdd"));
		
		FilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
		
		FilterItem.LeftValue = New DataCompositionField("Inventory.Period" + Format(CurrentPeriod, "DF=yyyyMMdd"));
		FilterItem.ComparisonType = DataCompositionComparisonType.Less;
		FilterItem.RightValue = 0;
		
		ConditionalAppearanceItem.Appearance.SetParameterValue("TextColor", WebColors.FireBrick);
		
		// The period is highlighted in bold and color.
		ConditionalAppearanceItem = ConditionalAppearance.Items.Add();
		ConditionalAppearanceItem.UserSettingID = "Preset";
		
		MadeOutField = ConditionalAppearanceItem.Fields.Items.Add();
		MadeOutField.Field = New DataCompositionField("InventoryPeriod" + Format(CurrentPeriod, "DF=yyyyMMdd"));
		
		FilterItemGroup = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
		FilterItemGroup.GroupType = DataCompositionFilterItemsGroupType.OrGroup;
		
		FilterItem = FilterItemGroup.Items.Add(Type("DataCompositionFilterItem"));
		
		FilterItem.LeftValue = New DataCompositionField("Inventory.FormattingVariantPeriod" + Format(CurrentPeriod, "DF=yyyyMMdd"));
		FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
		FilterItem.RightValue = 2;
		
		FilterItem = FilterItemGroup.Items.Add(Type("DataCompositionFilterItem"));
		
		FilterItem.LeftValue = New DataCompositionField("Inventory.FormattingVariantPeriod" + Format(CurrentPeriod, "DF=yyyyMMdd"));
		FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
		FilterItem.RightValue = 5;
		
		ConditionalAppearanceItem.Appearance.SetParameterValue("TextColor", WebColors.FireBrick);
		ConditionalAppearanceItem.Appearance.SetParameterValue("Font", New Font(,, True));
		
		// Weekends are displayed in the background color.
		ConditionalAppearanceItem = ConditionalAppearance.Items.Add();
		ConditionalAppearanceItem.UserSettingID = "Preset";
		
		MadeOutField = ConditionalAppearanceItem.Fields.Items.Add();
		MadeOutField.Field = New DataCompositionField("InventoryPeriod" + Format(CurrentPeriod, "DF=yyyyMMdd"));
		
		FilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
		
		FilterItem.LeftValue = New DataCompositionField("Inventory.FormattingVariantPeriod" + Format(CurrentPeriod, "DF=yyyyMMdd"));
		FilterItem.ComparisonType = DataCompositionComparisonType.Greater;
		FilterItem.RightValue = 2;
		
		ConditionalAppearanceItem.Appearance.SetParameterValue("BackColor", WebColors.CornSilk);
		
		// Decryption of the period is displayed in the background color.
		ConditionalAppearanceItem = ConditionalAppearance.Items.Add();
		ConditionalAppearanceItem.UserSettingID = "Preset";
		
		MadeOutField = ConditionalAppearanceItem.Fields.Items.Add();
		MadeOutField.Field = New DataCompositionField("InventoryPeriod" + Format(CurrentPeriod, "DF=yyyyMMdd"));
		
		FilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
		
		FilterItem.LeftValue = New DataCompositionField("Inventory.Period" + Format(CurrentPeriod, "DF=yyyyMMdd"));
		FilterItem.ComparisonType = DataCompositionComparisonType.Greater;
		FilterItem.RightValue = 0;
		
		FilterItemGroup = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
		FilterItemGroup.GroupType = DataCompositionFilterItemsGroupType.OrGroup;
		
		FilterItem = FilterItemGroup.Items.Add(Type("DataCompositionFilterItem"));
		
		FilterItem.LeftValue = New DataCompositionField("Inventory.Products");
		FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
		FilterItem.RightValue = NStr("en = 'Receipt'");
		
		FilterItem = FilterItemGroup.Items.Add(Type("DataCompositionFilterItem"));
		
		FilterItem.LeftValue = New DataCompositionField("Inventory.Products");
		FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
		FilterItem.RightValue = NStr("en = 'Token expiration date'");
		
		ConditionalAppearanceItem.Appearance.SetParameterValue("BackColor", WebColors.LightGray);
		
		CurrentPeriod = CurrentPeriod + 86400;
		
	EndDo;
	
EndProcedure

// The procedure forms the period of demand generation.
//
&AtClient
Procedure GenerateDemandPeriod()
	
	CalendarDateBegin = BegOfDay(BegOfDay(CurrentDate()));
	CalendarDateEnd = EndOfDay(EndOfPeriod);
	
	If Month(CalendarDateBegin) = Month(CalendarDateEnd) Then
		
		DayOfScheduleBegin = Format(CalendarDateBegin, "DF=dd");
		WeekDayOfScheduleBegin = DriveClient.GetPresentationOfWeekDay(CalendarDateBegin);
		DayOfScheduleEnd = Format(CalendarDateEnd, "DF=dd");
		WeekDayOfScheduleEnd = DriveClient.GetPresentationOfWeekDay(CalendarDateBegin);
		
		MonthOfSchedule = Format(CalendarDateBegin, "DF=MMM");
		YearOfSchedule = Format(Year(CalendarDateBegin), "NG=0");
		
		PeriodPresentation = WeekDayOfScheduleBegin + " " + DayOfScheduleBegin + " - " + WeekDayOfScheduleEnd + " " + DayOfScheduleEnd + " " + MonthOfSchedule + ", " + YearOfSchedule;
		
	Else
		
		DayOfScheduleBegin = Format(CalendarDateBegin, "DF=dd");
		WeekDayOfScheduleBegin = DriveClient.GetPresentationOfWeekDay(CalendarDateBegin);
		MonthOfScheduleBegin = Format(CalendarDateBegin, "DF=MMM");
		DayOfScheduleEnd = Format(CalendarDateEnd, "DF=dd");
		WeekDayOfScheduleEnd = DriveClient.GetPresentationOfWeekDay(CalendarDateEnd);
		MonthOfScheduleEnd = Format(CalendarDateEnd, "DF=MMM");
		
		If Year(CalendarDateBegin) = Year(CalendarDateEnd) Then
			YearOfSchedule = Format(Year(CalendarDateBegin), "NG=0");
			PeriodPresentation = WeekDayOfScheduleBegin + " " + DayOfScheduleBegin + " " + MonthOfScheduleBegin + " - " + WeekDayOfScheduleEnd + " " + DayOfScheduleEnd + " " + MonthOfScheduleEnd + ", " + YearOfSchedule;
		Else
			YearOfScheduleBegin = Format(Year(CalendarDateBegin), "NG=0");
			YearOfScheduleEnd = Format(Year(CalendarDateEnd), "NG=0");
			PeriodPresentation = WeekDayOfScheduleBegin + " " + DayOfScheduleBegin + " " + MonthOfScheduleBegin + " " + YearOfScheduleBegin + " - " + WeekDayOfScheduleEnd + " " + DayOfScheduleEnd + " " + MonthOfScheduleEnd + " " + YearOfScheduleEnd;
			
		EndIf;
		
	EndIf;
	
EndProcedure

// The procedure updates the state of the orders (posted, recorded, marked for deletion) in TS Orders
//
&AtServer
Procedure UpdateStateOrdersAtServer()
	
	For Each OrderRow In Orders Do
		
		CurrentOrder = OrderRow.Order;
		
		If CurrentOrder.Posted Then
			OrderRow.DefaultPicture = 1;
		ElsIf CurrentOrder.DeletionMark Then
			OrderRow.DefaultPicture = 2;
		Else
			OrderRow.DefaultPicture = 0;
		EndIf;
		
	EndDo
	
EndProcedure

#Region ActionsOfTheFormCommandPanels

&AtClient
// The procedure is called when clicking "Update" on the command panel of the form.
//
Procedure Refresh(Command)
	
	If Not ValueIsFilled(Company) Then
		Message = New UserMessage();
		Message.Text = NStr("en = 'Company is not selected.'");
		Message.Field = "Company";
		Message.Message();
		Return;
	EndIf;
	
	UpdateAtServer();
	
EndProcedure

&AtClient
// The procedure is called when clicking "Setup" on the command panel of the form.
//
Procedure Setting(Command)
	
	FormParameters = New Structure();
	FormParameters.Insert("SchemaURLCompositionData", SchemaURLCompositionData);
	FormParameters.Insert("FilterSettingComposer", SettingsComposer);
	
	Notification = New NotifyDescription("SettingsEnd", ThisForm);
	OpenForm("DataProcessor.DemandPlanning.Form.FormSetting", FormParameters,,,,, Notification);
	
EndProcedure

&AtClient
Procedure SettingsEnd(ReturnStructure, Parameters) Export
	
	If TypeOf(ReturnStructure) = Type("Structure") Then
		SettingsComposer.LoadSettings(ReturnStructure.SettingsComposer.Settings);
		SettingsComposer.LoadUserSettings(ReturnStructure.SettingsComposer.UserSettings);
		SettingsComposer.LoadFixedSettings(ReturnStructure.SettingsComposer.FixedSettings);
	EndIf;
	
EndProcedure

&AtClient
// The procedure is called when clicking "GenerateOrders" on the command panel of the form.
//
Procedure GenerateOrders(Command)
	
	GenerateOrdersAtServer();
	
EndProcedure

&AtClient
// The procedure is called when clicking "Post" on the command panel of the form.
//
Procedure OrdersPost(Command)
	
	OrdersArray = New Array;
	
	For Each SelectedRow In Items.Orders.SelectedRows Do
		
		OrdersArray.Add(New Structure("Index, Ref", SelectedRow, Orders.Get(SelectedRow).Order));
		
	EndDo;
	
	PostingResults = OrdersPostAtServer(OrdersArray);
	
	For Each PostingResult In PostingResults Do
		
		Orders.Get(PostingResult).DefaultPicture = 1;
		
	EndDo;
	
EndProcedure

&AtClient
// The procedure is called when clicking "UndoPost" on the command panel of the form.
//
Procedure OrdersUndoPosting(Command)
	
	OrdersArray = New Array;
	
	For Each SelectedRow In Items.Orders.SelectedRows Do
		
		OrdersArray.Add(New Structure("Index, Ref", SelectedRow, Orders.Get(SelectedRow).Order));
		
	EndDo;
	
	UndoPostingResults = OrdersUndoPostingAtServer(OrdersArray);
	
	For Each UndoPostingResult In UndoPostingResults Do
		
		Orders.Get(UndoPostingResult).DefaultPicture = 0;
		
	EndDo;
	
EndProcedure

&AtClient
// The procedure is called when clicking "MarkToDelete" on the command panel of the form.
//
Procedure OrdersMarkToDelete(Command)
	
	OrdersArray = New Array;
	
	For Each SelectedRow In Items.Orders.SelectedRows Do
		
		OrdersArray.Add(New Structure("Index, Ref", SelectedRow, Orders.Get(SelectedRow).Order));
		
	EndDo;
	
	MarkToDeleteResults = OrdersMarkToDeleteAtServer(OrdersArray);
	
	For Each MarkToDeleteResult In MarkToDeleteResults Do
		
		If Orders.Get(MarkToDeleteResult).DefaultPicture = 2 Then
			
			Orders.Get(MarkToDeleteResult).DefaultPicture = 0;
			
		Else
			
			Orders.Get(MarkToDeleteResult).DefaultPicture = 2;
			
		EndIf;
		
	EndDo;
	
EndProcedure

&AtClient
// The procedure is called when clicking "Reread" on the command panel of the form.
//
Procedure Reread(Command)
	
	If Modified Then
		
		QuestionStr = NStr("en = 'Data is changed. Reread?'");
		Notification = New NotifyDescription("RereadCompletion",ThisForm);
		ShowQueryBox(Notification,QuestionStr,QuestionDialogMode.YesNo);
		Return;
		
	EndIf;
	
	UpdateRecommendationsAtServer();
	
EndProcedure

&AtClient
Procedure RereadCompletion(Result,Parameters) Export
	
	If Result = DialogReturnCode.Yes Then
		UpdateRecommendationsAtServer();
	EndIf;
	
EndProcedure

&AtClient
// The procedure is called when clicking "OpenProducts" on the command panel Inventory.
//
Procedure InventoryOpenProducts(Command)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	If TabularSectionRow <> Undefined Then
		
		While True Do
			
			If TypeOf(TabularSectionRow.Products) = Type("CatalogRef.Products") Then
				OpenForm("Catalog.Products.Form.ItemForm", New Structure("Key", TabularSectionRow.Products));
				Break;
			Else
				TabularSectionRow = TabularSectionRow.GetParent();
				If TabularSectionRow = Undefined Then
					Break;
				EndIf;
			EndIf;
			
		EndDo;
		
		
	EndIf;
	
EndProcedure

&AtClient
// The procedure is called when clicking "OpenProducts" on the command panel Recommendations.
//
Procedure RecommendationsOpenProducts(Command)
	
	TabularSectionRow = Items.Recommendations.CurrentData;
	If TabularSectionRow <> Undefined Then
		
		While True Do
			
			If TypeOf(TabularSectionRow.Products) = Type("CatalogRef.Products") Then
				OpenForm("Catalog.Products.Form.ItemForm", New Structure("Key", TabularSectionRow.Products));
				Break;
			Else
				TabularSectionRow = TabularSectionRow.GetParent();
				If TabularSectionRow = Undefined Then
					Break;
				EndIf;
			EndIf;
			
		EndDo;
		
		
	EndIf;
	
EndProcedure

// Procedure - handler of Calendar command.
//
&AtClient
Procedure PeriodPresentationStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	ParametersStructure = New Structure("CalendarDate", EndOfPeriod);
	Notification = New NotifyDescription("PeriodPresentationStartChoiceEnd",ThisForm);
	OpenForm("CommonForm.Calendar", ParametersStructure,,,,,Notification);
	
EndProcedure

&AtClient
Procedure PeriodPresentationStartChoiceEnd(CalendarDateEnd,Parameters) Export
	
	If ValueIsFilled(CalendarDateEnd) Then
		
		EndOfPeriod = EndOfDay(CalendarDateEnd);
		If BegOfDay(CurrentDate()) > BegOfDay(EndOfPeriod) Then
			EndOfPeriod = EndOfDay(CurrentDate());
		EndIf;
		
		GenerateDemandPeriod();
		
	EndIf;
	
EndProcedure

// Procedure - handler of ShortenPeriod command.
//
&AtClient
Procedure ShortenPeriod(Command)
	
	EndOfPeriod = EndOfDay(EndOfPeriod - 60 * 60 * 24);
	If BegOfDay(CurrentDate()) > BegOfDay(EndOfPeriod) Then
		EndOfPeriod = EndOfDay(CurrentDate());
	EndIf;
	
	GenerateDemandPeriod();
	
EndProcedure

// Procedure - handler of ExtendPeriod command.
//
&AtClient
Procedure ExtendPeriod(Command)
	
	EndOfPeriod = EndOfDay(EndOfPeriod + 60 * 60 * 24);
	GenerateDemandPeriod();
	
EndProcedure

// Procedure - handler of UpdateOrders command.
//
&AtClient
Procedure RefreshOrders(Command)
	
	UpdateStateOrdersAtServer();
	
EndProcedure

#EndRegion

#EndRegion

#Region ProcedureFormEventHandlers

&AtServer
// Procedure-handler of the OnCreateAtServer event.
// Performs initial attributes forms filling.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("PurchasesOnly") Then
		PurchasesOnly = Parameters.PurchasesOnly;
	EndIf;
	
	EndOfPeriod = CurrentDate() + 7 * 86400;
	
	DataProcessor = FormAttributeToValue("Object");
	DataCompositionSchema = DataProcessor.GetTemplate("DataCompositionSchema");
	
	SchemaURLCompositionData = PutToTempStorage(DataCompositionSchema, New UUID);
	SettingsSource = New DataCompositionAvailableSettingsSource(SchemaURLCompositionData);
	
	SettingsComposer.Initialize(SettingsSource);
	SettingsComposer.LoadSettings(DataCompositionSchema.DefaultSettings);
	
	RestoreSettings();
	
	If Not ValueIsFilled(EndOfPeriod) Then
		EndOfPeriod = CurrentDate() + 7 * 86400;
	EndIf;
	
	AddressInventory = PutToTempStorage(FormAttributeToValue("Inventory"), UUID);
	
EndProcedure

&AtClient
// Event handler procedure OnOpen.
// Performs initial attributes forms filling.
//
Procedure OnOpen(Cancel)
	
	GenerateDemandPeriod();
	
EndProcedure

&AtClient
// Procedure-handler of OnClose event.
//
Procedure OnClose(Exit)
	
	If Exit Then
		Return;
	EndIf;

	SaveSettings();
	
EndProcedure

#EndRegion

#Region ProcedureEventHandlersOfFormAttributes

&AtClient
// Procedure - event handler OnChange of input field FilterReplenishmentMethod.
//
Procedure FilterReplenishmentMethodOnChange(Item)
	
	If FilterReplenishmentMethod = "Production" Then
		Items.Counterparty.Visible = False;
		Counterparty = Undefined;
	Else
		Items.Counterparty.Visible = True;
	EndIf;
	
EndProcedure

#Region EventHandlersOfTableField

&AtClient
// Procedure-the Choice event handler of the Inventory tabular section.
//
Procedure InventorySelection(Item, SelectedRow, Field, StandardProcessing)
	
	If Item.CurrentData <> Undefined Then
		
		If TypeOf(Item.CurrentData.Products) = Type("DocumentRef.SalesOrder") Then
			OpenForm("Document.SalesOrder.ObjectForm", New Structure("Key", Item.CurrentData.Products));
		ElsIf TypeOf(Item.CurrentData.Products) = Type("DocumentRef.PurchaseOrder") Then
			OpenForm("Document.PurchaseOrder.ObjectForm", New Structure("Key", Item.CurrentData.Products));
		ElsIf TypeOf(Item.CurrentData.Products) = Type("DocumentRef.ProductionOrder") Then
			OpenForm("Document.ProductionOrder.ObjectForm", New Structure("Key", Item.CurrentData.Products));
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region EventHandlersOfTabularSectionsRecommendations

&AtClient
// Procedure - event handler BeforeStartChanging of tabular section Recommendations.
//
Procedure RecommendationsBeforeRowChange(Item, Cancel)
	
	If Item.CurrentData = Undefined 
		OR Not Item.CurrentData.EditAllowed 
		AND Not (Item.CurrentItem <> Undefined AND Item.CurrentItem.Name = "RecommendationsSelected")Then
		
		Cancel = True;
		Return;
		
	EndIf;
	
EndProcedure

&AtClient
// Procedure - event handler BeforeAddStart of tabular section Recommendations.
//
Procedure RecommendationsBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	Cancel = True;
	
EndProcedure

&AtClient
// Procedure - event handler BeforeDelete of tabular section Recommendations.
//
Procedure RecommendationsBeforeDeleteRow(Item, Cancel)
	
	Cancel = True;
	
EndProcedure

#EndRegion

#Region TabularSectionEventHandlersOrders

&AtClient
// Procedure - event handler of Tabular section selection Orders.
//
Procedure OrdersSelection(Item, SelectedRow, Field, StandardProcessing)
	
	ShowValue(Undefined,Item.RowData(SelectedRow).Order);
	
EndProcedure

#EndRegion

#Region EventHandlersOfAttributesOfTabularSectionsRecommendations

&AtClient
// Procedure - event handler OnChange of the Selected input field.
//
Procedure RecommendationsSelectedOnChange(Item)
	
	SecuredQuantity = 0;
	Selected = False;
	
	CurrentDataParent = Items.Recommendations.CurrentData.GetParent();
	
	If CurrentDataParent = Undefined Then
		
		ParentCurrentData = Items.Recommendations.CurrentData.GetItems();
		SelectedParent = Items.Recommendations.CurrentData.Selected;
		Default = True;
		For Each TreeRow In ParentCurrentData Do
			
			If SelectedParent Then
				TreeRow.Selected = Default;
			Else
				TreeRow.Selected = False;
			EndIf;
			
			Default = False;
			
			If TreeRow.Selected Then
			
				Selected = True;
				SecuredQuantity = SecuredQuantity + TreeRow.Quantity;
			
			EndIf;
			
		EndDo;
		
		Items.Recommendations.CurrentData.Selected = Selected;
		Items.Recommendations.CurrentData.DemandClosed = (SecuredQuantity >= Items.Recommendations.CurrentData.Quantity);
		
	Else	
		
		For Each TreeRow In CurrentDataParent.GetItems() Do
		
			If TreeRow.Selected Then
				
				Selected = True;
				SecuredQuantity = SecuredQuantity + TreeRow.Quantity;
				
			EndIf;
			
		EndDo;
		
		CurrentDataParent.Selected = Selected;
		CurrentDataParent.DemandClosed = (SecuredQuantity >= CurrentDataParent.Quantity);
		
	EndIf;
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of the Count input field.
//
Procedure RecommendationsQuantityOnChange(Item)
	
	Item.Parent.CurrentData.Selected = True;
	Item.Parent.CurrentData.Amount = Item.Parent.CurrentData.Quantity * Item.Parent.CurrentData.Price;
	
	RecommendationsSelectedOnChange(Item);
	
EndProcedure

#EndRegion

#EndRegion
