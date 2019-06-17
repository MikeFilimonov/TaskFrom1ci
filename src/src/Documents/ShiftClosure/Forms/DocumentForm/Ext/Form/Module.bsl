
#Region Variables

&AtClient
Var ThisIsNewRow;

#EndRegion

#Region GeneralPurposeProceduresAndFunctions

// Procedure recalculates the document on client.
//
&AtClient
Procedure RecalculateDocumentAtClient()
	
	Object.DocumentAmount = Object.Inventory.Total("Total");
	RecalculateSubtotal();
	
EndProcedure

// Procedure recalculates subtotal the document on client.
//
&AtClient
Procedure RecalculateSubtotal()
	
	DocumentDiscount = 0;
	For Each InventoryLine In Object.Inventory Do
		DocumentDiscount = DocumentDiscount +
							InventoryLine.Price * InventoryLine.Quantity * InventoryLine.DiscountMarkupPercent / 100 +
							InventoryLine.AutomaticDiscountAmount;
	EndDo;
	
	DocumentSubtotal = Object.Inventory.Total("Total") - Object.Inventory.Total("VATAmount") + DocumentDiscount;
	
EndProcedure

// Peripherals
// Procedure gets data by barcodes.
//
&AtServerNoContext
Procedure GetDataByBarCodes(StructureData)
	
	// Transform weight barcodes.
	For Each CurBarcode In StructureData.BarcodesArray Do
		
		InformationRegisters.Barcodes.ConvertWeightBarcode(CurBarcode);
		
	EndDo;
	
	DataByBarCodes = InformationRegisters.Barcodes.GetDataByBarCodes(StructureData.BarcodesArray);
	
	For Each CurBarcode In StructureData.BarcodesArray Do
		
		BarcodeData = DataByBarCodes[CurBarcode.Barcode];
		
		If BarcodeData <> Undefined
		   AND BarcodeData.Count() <> 0 Then
			
			StructureProductsData = New Structure();
			StructureProductsData.Insert("Company", StructureData.Company);
			StructureProductsData.Insert("Products", BarcodeData.Products);
			StructureProductsData.Insert("Characteristic", BarcodeData.Characteristic);
			StructureProductsData.Insert("VATTaxation", StructureData.VATTaxation);
			If ValueIsFilled(StructureData.PriceKind) Then
				StructureProductsData.Insert("ProcessingDate", StructureData.Date);
				StructureProductsData.Insert("DocumentCurrency", StructureData.DocumentCurrency);
				StructureProductsData.Insert("AmountIncludesVAT", StructureData.AmountIncludesVAT);
				StructureProductsData.Insert("PriceKind", StructureData.PriceKind);
				If ValueIsFilled(BarcodeData.MeasurementUnit)
					AND TypeOf(BarcodeData.MeasurementUnit) = Type("CatalogRef.UOM") Then
					StructureProductsData.Insert("Factor", BarcodeData.MeasurementUnit.Factor);
				Else
					StructureProductsData.Insert("Factor", 1);
				EndIf;
				StructureProductsData.Insert("DiscountMarkupKind", StructureData.DiscountMarkupKind);
			EndIf;
			BarcodeData.Insert("StructureProductsData", GetDataProductsOnChange(StructureProductsData));
			
			If Not ValueIsFilled(BarcodeData.MeasurementUnit) Then
				BarcodeData.MeasurementUnit  = BarcodeData.Products.MeasurementUnit;
			EndIf;
			
		EndIf;
		
	EndDo;
	
	StructureData.Insert("DataByBarCodes", DataByBarCodes);
	
EndProcedure

&AtClient
Function FillByBarcodesData(BarcodesData)
	
	UnknownBarcodes = New Array;
	
	If TypeOf(BarcodesData) = Type("Array") Then
		BarcodesArray = BarcodesData;
	Else
		BarcodesArray = New Array;
		BarcodesArray.Add(BarcodesData);
	EndIf;
	
	StructureData = New Structure();
	StructureData.Insert("BarcodesArray", BarcodesArray);
	StructureData.Insert("Company", Object.Company);
	StructureData.Insert("PriceKind", Object.PriceKind);
	StructureData.Insert("Date", Object.Date);
	StructureData.Insert("DocumentCurrency", Object.DocumentCurrency);
	StructureData.Insert("AmountIncludesVAT", Object.AmountIncludesVAT);
	StructureData.Insert("DiscountMarkupKind", Object.DiscountMarkupKind);
	StructureData.Insert("VATTaxation", Object.VATTaxation);
	GetDataByBarCodes(StructureData);
	
	For Each CurBarcode In StructureData.BarcodesArray Do
		BarcodeData = StructureData.DataByBarCodes[CurBarcode.Barcode];
		
		If BarcodeData <> Undefined
		   AND BarcodeData.Count() = 0 Then
			UnknownBarcodes.Add(CurBarcode);
		Else
			TSRowsArray = Object.Inventory.FindRows(New Structure("Products,Characteristic,Batch,MeasurementUnit",BarcodeData.Products,BarcodeData.Characteristic,BarcodeData.Batch,BarcodeData.MeasurementUnit));
			If TSRowsArray.Count() = 0 Then
				NewRow = Object.Inventory.Add();
				NewRow.Products = BarcodeData.Products;
				NewRow.Characteristic = BarcodeData.Characteristic;
				NewRow.Batch = BarcodeData.Batch;
				NewRow.Quantity = CurBarcode.Quantity;
				NewRow.MeasurementUnit = ?(ValueIsFilled(BarcodeData.MeasurementUnit), BarcodeData.MeasurementUnit, BarcodeData.StructureProductsData.MeasurementUnit);
				NewRow.Price = BarcodeData.StructureProductsData.Price;
				NewRow.DiscountMarkupPercent = BarcodeData.StructureProductsData.DiscountMarkupPercent;
				NewRow.VATRate = BarcodeData.StructureProductsData.VATRate;
				CalculateAmountInTabularSectionLine(NewRow);
				Items.Inventory.CurrentRow = NewRow.GetID();
			Else
				NewRow = TSRowsArray[0];
				NewRow.Quantity = NewRow.Quantity + CurBarcode.Quantity;
				CalculateAmountInTabularSectionLine(NewRow);
				Items.Inventory.CurrentRow = NewRow.GetID();
			EndIf;
			
			If BarcodeData.Property("SerialNumber") AND ValueIsFilled(BarcodeData.SerialNumber) Then
				WorkWithSerialNumbersClientServer.AddSerialNumberToString(NewRow, BarcodeData.SerialNumber, Object);
			EndIf;
		EndIf;
	EndDo;
	
	Return UnknownBarcodes;

EndFunction

// Procedure processes the received barcodes.
//
&AtClient
Procedure BarcodesReceived(BarcodesData)
	
	Modified = True;
	
	UnknownBarcodes = FillByBarcodesData(BarcodesData);
	
	ReturnParameters = Undefined;
	
	If UnknownBarcodes.Count() > 0 Then
		
		Notification = New NotifyDescription("BarcodesAreReceivedEnd", ThisForm, UnknownBarcodes);
		
		OpenForm(
			"InformationRegister.Barcodes.Form.BarcodesRegistration",
			New Structure("UnknownBarcodes", UnknownBarcodes), ThisForm,,,,Notification
		);
		
		Return;
		
	EndIf;
	
	BarcodesAreReceivedFragment(UnknownBarcodes);
	
EndProcedure

&AtClient
Procedure BarcodesAreReceivedEnd(ReturnParameters, Parameters) Export
	
	UnknownBarcodes = Parameters;
	
	If ReturnParameters <> Undefined Then
		
		BarcodesArray = New Array;
		
		For Each ArrayElement In ReturnParameters.RegisteredBarcodes Do
			BarcodesArray.Add(ArrayElement);
		EndDo;
		
		For Each ArrayElement In ReturnParameters.ReceivedNewBarcodes Do
			BarcodesArray.Add(ArrayElement);
		EndDo;
		
		UnknownBarcodes = FillByBarcodesData(BarcodesArray);
		
	EndIf;
	
	BarcodesAreReceivedFragment(UnknownBarcodes);
	
EndProcedure

&AtClient
Procedure BarcodesAreReceivedFragment(UnknownBarcodes) Export
	
	For Each CurUndefinedBarcode In UnknownBarcodes Do
		
		MessageString = NStr("en = 'Barcode data is not found: %1%; quantity: %2%'");
		MessageString = StrReplace(MessageString, "%1%", CurUndefinedBarcode.Barcode);
		MessageString = StrReplace(MessageString, "%2%", CurUndefinedBarcode.Quantity);
		CommonUseClientServer.MessageToUser(MessageString);
		
	EndDo;
	
EndProcedure

// End Peripherals

// The procedure of filling payment card kinds array.
//
&AtServer
Function GetPaymentCardKindsArray(POSTerminal)
	
	Return Catalogs.POSTerminals.PaymentCardKinds(POSTerminal);
	
EndFunction

// Receives the set of data from the server for the ProductsOnChange procedure.
//
&AtServerNoContext
Function GetDataProductsOnChange(StructureData)
	
	GLAccountsInDocuments.FillProductGLAccountsInStructure(StructureData);
	
	StructureData.Insert("MeasurementUnit", StructureData.Products.MeasurementUnit);
	
	If StructureData.Property("VATTaxation") 
		AND Not StructureData.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then
		
		If StructureData.VATTaxation = Enums.VATTaxationTypes.NotSubjectToVAT Then
			StructureData.Insert("VATRate", Catalogs.VATRates.Exempt);
		Else
			StructureData.Insert("VATRate", Catalogs.VATRates.ZeroRate);
		EndIf;
		
	ElsIf ValueIsFilled(StructureData.Products.VATRate) Then
		StructureData.Insert("VATRate", StructureData.Products.VATRate);
	Else
		StructureData.Insert("VATRate", InformationRegisters.AccountingPolicy.GetDefaultVATRate(, StructureData.Company));
	EndIf;
	
	If StructureData.Property("PriceKind") Then
		Price = DriveServer.GetProductsPriceByPriceKind(StructureData);
		StructureData.Insert("Price", Price);
	Else
		StructureData.Insert("Price", 0);
	EndIf;
	
	If StructureData.Property("DiscountMarkupKind") 
		AND ValueIsFilled(StructureData.DiscountMarkupKind) Then
		StructureData.Insert("DiscountMarkupPercent", StructureData.DiscountMarkupKind.Percent);
	Else
		StructureData.Insert("DiscountMarkupPercent", 0);
	EndIf;
	
	Return StructureData;
	
EndFunction

// It receives data set from server for the CharacteristicOnChange procedure.
//
&AtServerNoContext
Function GetDataCharacteristicOnChange(StructureData)
	
	If StructureData.Property("PriceKind") Then
		
		If TypeOf(StructureData.MeasurementUnit) = Type("CatalogRef.UOMClassifier") Then
			StructureData.Insert("Factor", 1);
		Else
			StructureData.Insert("Factor", StructureData.MeasurementUnit.Factor);
		EndIf;
		
		Price = DriveServer.GetProductsPriceByPriceKind(StructureData);
		StructureData.Insert("Price", Price);
		
	Else
		
		StructureData.Insert("Price", 0);
		
	EndIf;
	
	Return StructureData;
	
EndFunction

// Gets the data set from the server for procedure MeasurementUnitOnChange.
//
&AtServerNoContext
Function GetDataMeasurementUnitOnChange(CurrentMeasurementUnit = Undefined, MeasurementUnit = Undefined)
	
	StructureData = New Structure();
	
	If CurrentMeasurementUnit = Undefined Then
		StructureData.Insert("CurrentFactor", 1);
	Else
		StructureData.Insert("CurrentFactor", CurrentMeasurementUnit.Factor);
	EndIf;
	
	If MeasurementUnit = Undefined Then
		StructureData.Insert("Factor", 1);
	Else
		StructureData.Insert("Factor", MeasurementUnit.Factor);
	EndIf;
	
	Return StructureData;
	
EndFunction

// It receives data set from server for the DateOnChange procedure.
//
&AtServer
Function GetDataDateOnChange(DateBeforeChange)
	
	StructureData = New Structure();
	
	StructureData.Insert("DATEDIFF", DriveServer.CheckDocumentNumber(Object.Ref, Object.Date, DateBeforeChange));
	
	FillVATRateByCompanyVATTaxation();
	
	Return StructureData;
	
EndFunction

// Gets data set from server.
//
&AtServer
Function GetCompanyDataOnChange()
	
	StructureData = New Structure();
	StructureData.Insert("ParentCompany", DriveServer.GetCompany(Object.Company));
	
	FillAddedColumns(True);
	FillVATRateByCompanyVATTaxation();
	
	Return StructureData;
	
EndFunction

// Procedure fills VAT Rate in tabular section
// by company taxation system.
// 
&AtServer
Procedure FillVATRateByCompanyVATTaxation()
	
	TaxationBeforeChange = Object.VATTaxation;
	Object.VATTaxation = DriveServer.VATTaxation(Object.Company, Object.Date);
	
	If Not TaxationBeforeChange = Object.VATTaxation Then
		FillVATRateByVATTaxation();
	EndIf;
	
EndProcedure

// Procedure fills the VAT rate in the tabular section according to the taxation system.
// 
&AtServer
Procedure FillVATRateByVATTaxation()
	
	If Object.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then
		
		Items.InventoryVATRate.Visible = True;
		Items.InventoryVATAmount.Visible = True;
		Items.InventoryAmountTotal.Visible = True;
		Items.VATAmount.Visible = True;
		
		For Each TabularSectionRow In Object.Inventory Do
			
			If ValueIsFilled(TabularSectionRow.Products.VATRate) Then
				TabularSectionRow.VATRate = TabularSectionRow.Products.VATRate;
			Else
				TabularSectionRow.VATRate = InformationRegisters.AccountingPolicy.GetDefaultVATRate(Object.Date, Object.Company);
			EndIf;	
			
			VATRate = DriveReUse.GetVATRateValue(TabularSectionRow.VATRate);
			TabularSectionRow.VATAmount = ?(Object.AmountIncludesVAT, 
									  		TabularSectionRow.Amount - (TabularSectionRow.Amount) / ((VATRate + 100) / 100),
									  		TabularSectionRow.Amount * VATRate / 100);
			TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
			
		EndDo;	
		
	Else
		
		Items.InventoryVATRate.Visible = False;
		Items.InventoryVATAmount.Visible = False;
		Items.InventoryAmountTotal.Visible = False;
		Items.VATAmount.Visible = False;
		
		If Object.VATTaxation = Enums.VATTaxationTypes.NotSubjectToVAT Then	
			DefaultVATRate = Catalogs.VATRates.Exempt;
		Else
			DefaultVATRate = Catalogs.VATRates.ZeroRate;
		EndIf;	
		
		For Each TabularSectionRow In Object.Inventory Do
		
			TabularSectionRow.VATRate = DefaultVATRate;
			TabularSectionRow.VATAmount = 0;
			
			TabularSectionRow.Total = TabularSectionRow.Amount;
			
		EndDo;	
		
	EndIf;	
	
EndProcedure

// VAT amount is calculated in the row of tabular section.
//
&AtClient
Procedure CalculateVATSUM(TabularSectionRow)
	
	VATRate = DriveReUse.GetVATRateValue(TabularSectionRow.VATRate);
	
	TabularSectionRow.VATAmount = ?(
		Object.AmountIncludesVAT,
		TabularSectionRow.Amount
	  - (TabularSectionRow.Amount) / ((VATRate + 100) / 100),
	  TabularSectionRow.Amount * VATRate / 100);
	
EndProcedure

// Procedure calculates the amount in the row of tabular section.
//
&AtClient
Procedure CalculateAmountInTabularSectionLine(TabularSectionRow = Undefined)
	
	If TabularSectionRow = Undefined Then
		TabularSectionRow = Items.Inventory.CurrentData;
	EndIf;
	
	TabularSectionRow.Amount = TabularSectionRow.Quantity * TabularSectionRow.Price;
	AmountBeforeCalculation = TabularSectionRow.Amount;
	
	If TabularSectionRow.DiscountMarkupPercent = 100 Then
		TabularSectionRow.Amount = 0;
	ElsIf TabularSectionRow.DiscountMarkupPercent <> 0
			AND TabularSectionRow.Quantity <> 0 Then
		TabularSectionRow.Amount = TabularSectionRow.Amount * (1 - TabularSectionRow.DiscountMarkupPercent / 100);
	EndIf;
	
	CalculateVATSUM(TabularSectionRow);
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	TabularSectionRow.DiscountAmount = AmountBeforeCalculation - TabularSectionRow.Amount;
	
	// Serial numbers
	If UseSerialNumbersBalance<>Undefined Then
		WorkWithSerialNumbersClientServer.UpdateSerialNumbersQuantity(Object, TabularSectionRow);
	EndIf;
	
EndProcedure

// Procedure calculates discount % in tabular section string.
//
&AtClient
Procedure CalculateDiscountPercent(TabularSectionRow = Undefined)
	
	If TabularSectionRow = Undefined Then
		TabularSectionRow = Items.Inventory.CurrentData;
	EndIf;
	
	If TabularSectionRow.Quantity * TabularSectionRow.Price < TabularSectionRow.DiscountAmount Then
		TabularSectionRow.DiscountAmount = TabularSectionRow.Quantity * TabularSectionRow.Price;
	EndIf;
	
	TabularSectionRow.Amount = TabularSectionRow.Quantity * TabularSectionRow.Price - TabularSectionRow.DiscountAmount;
	If TabularSectionRow.Price <> 0
	   AND TabularSectionRow.Quantity <> 0 Then
		TabularSectionRow.DiscountMarkupPercent = (1 - TabularSectionRow.Amount / (TabularSectionRow.Price * TabularSectionRow.Quantity)) * 100;
	Else
		TabularSectionRow.DiscountMarkupPercent = 0;
	EndIf;
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
EndProcedure

// Function gets a product list from the temporary storage
//
&AtServer
Procedure GetInventoryFromStorage(InventoryAddressInStorage, TabularSectionName, AreCharacteristics, AreBatches)
	
	TableForImport = GetFromTempStorage(InventoryAddressInStorage);
	ObjectParameters = GLAccountsInDocumentsClientServer.GetObjectParameters(Object);
	StructureData = GetStructureData(ObjectParameters);
	StructureData.Insert("Products", TableForImport.UnloadColumn("Products"));
	GLAccounts = GLAccountsInDocuments.GetProductListGLAccounts(StructureData);
	
	For Each ImportRow In TableForImport Do
		
		NewRow = Object[TabularSectionName].Add();
		FillPropertyValues(NewRow, ImportRow);
		
		FillPropertyValues(StructureData, NewRow);
		GLAccountsInDocumentsServerCall.FillProductGLAccounts(StructureData, GLAccounts);
		FillPropertyValues(NewRow, StructureData);
		
	EndDo;
	
EndProcedure

// Procedure executes recalculate in the document tabular section
// after changes in "Prices and currency" form.Column recalculation is executed:
// price, discount, amount, VAT amount, total.
//
&AtClient
Procedure ProcessChangesOnButtonPricesAndCurrencies(Val SettlementsCurrencyBeforeChange, RecalculatePrices = False)
	
	// 1. Form parameter structure to fill the "Prices and Currency" form.
	ParametersStructure = New Structure;
	ParametersStructure.Insert("DocumentCurrency",		  Object.DocumentCurrency);
	ParametersStructure.Insert("VATTaxation",	  Object.VATTaxation);
	ParametersStructure.Insert("AmountIncludesVAT",	  Object.AmountIncludesVAT);
	ParametersStructure.Insert("IncludeVATInPrice", Object.IncludeVATInPrice);
	ParametersStructure.Insert("Company",			  ParentCompany);
	ParametersStructure.Insert("DocumentDate",		  Object.Date);
	ParametersStructure.Insert("RefillPrices",	  False);
	ParametersStructure.Insert("RecalculatePrices",		  RecalculatePrices);
	ParametersStructure.Insert("WereMadeChanges",  False);
	ParametersStructure.Insert("DocumentCurrencyEnabled", False);
	ParametersStructure.Insert("PriceKind", Object.PriceKind);
	ParametersStructure.Insert("DiscountKind", Object.DiscountMarkupKind);
	ParametersStructure.Insert("ReverseChargeNotApplicable", True);
	
	StructurePricesAndCurrency = Undefined;
	
	OpenForm("CommonForm.PricesAndCurrency", ParametersStructure,,,,, New NotifyDescription("ProcessChangesOnButtonPricesAndCurrenciesEnd", ThisObject, New Structure("SettlementsCurrencyBeforeChange", SettlementsCurrencyBeforeChange)));
	
EndProcedure

&AtClient
Procedure ProcessChangesOnButtonPricesAndCurrenciesEnd(Result, AdditionalParameters) Export
	
	SettlementsCurrencyBeforeChange = AdditionalParameters.SettlementsCurrencyBeforeChange;
	
	// 2. Open the form "Prices and Currency".
	StructurePricesAndCurrency = Result;
	
	// 3. Refills tabular section "Costs" if changes were made in the "Price and Currency" form.
	If TypeOf(StructurePricesAndCurrency) = Type("Structure") AND StructurePricesAndCurrency.WereMadeChanges Then
		
		Object.PriceKind = StructurePricesAndCurrency.PriceKind;
		Object.DiscountMarkupKind = StructurePricesAndCurrency.DiscountKind;
		Object.VATTaxation = StructurePricesAndCurrency.VATTaxation;
		Object.AmountIncludesVAT = StructurePricesAndCurrency.AmountIncludesVAT;
		Object.IncludeVATInPrice = StructurePricesAndCurrency.IncludeVATInPrice;
		
		// Recalculate prices by kind of prices.
		If StructurePricesAndCurrency.RefillPrices Then
			DriveClient.RefillTabularSectionPricesByPriceKind(ThisForm, "Inventory", True);
		EndIf;
		
		// Recalculate prices by currency.
		If Not StructurePricesAndCurrency.RefillPrices
			AND StructurePricesAndCurrency.RecalculatePrices Then
			DriveClient.RecalculateTabularSectionPricesByCurrency(ThisForm, SettlementsCurrencyBeforeChange, "Inventory");
		EndIf;
		
		// Recalculate the amount if VAT taxation flag is changed.
		If StructurePricesAndCurrency.VATTaxation <> StructurePricesAndCurrency.PrevVATTaxation Then
			FillVATRateByVATTaxation();
		EndIf;
		
		// Recalculate the amount if the "Amount includes VAT" flag is changed.
		If Not StructurePricesAndCurrency.RefillPrices
			AND Not StructurePricesAndCurrency.AmountIncludesVAT = StructurePricesAndCurrency.PrevAmountIncludesVAT Then
			DriveClient.RecalculateTabularSectionAmountByFlagAmountIncludesVAT(ThisForm, "Inventory");
		EndIf;
		
	EndIf;
	
	// Generate price and currency label.
	LabelStructure = New Structure("PriceKind, DiscountKind, DocumentCurrency, SettlementsCurrency, ExchangeRate, RateNationalCurrency, AmountIncludesVAT, ForeignExchangeAccounting, VATTaxation", Object.PriceKind, Object.DiscountMarkupKind, Object.DocumentCurrency, Object.DocumentCurrency, ExchangeRate, RateNationalCurrency, Object.AmountIncludesVAT, ForeignExchangeAccounting, Object.VATTaxation);
	PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);

EndProcedure

// The procedure fills in the "Inventory" tabular section by balance
// 
&AtServer
Procedure FillByBalanceAtWarehouse()
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	InventoryBalances.Products AS Products,
	|	InventoryBalances.Characteristic AS Characteristic,
	|	InventoryBalances.Batch AS Batch,
	|	PricesSliceLast.Price / ISNULL(PricesSliceLast.MeasurementUnit.Factor, 1) AS Price,
	|	InventoryBalances.QuantityBalance AS Quantity,
	|	InventoryBalances.Products.MeasurementUnit AS MeasurementUnit,
	|	&DiscountMarkupPercent AS DiscountMarkupPercent,
	|	CASE
	|		WHEN InventoryBalances.Products.VATRate <> VALUE(Catalog.VATRates.EmptyRef)
	|			THEN InventoryBalances.Products.VATRate
	|		ELSE AccountingPolicySliceLast.DefaultVATRate
	|	END AS VATRate
	|FROM
	|	AccumulationRegister.Inventory.Balance(
	|			&Period,
	|			Company = &Company
	|				AND StructuralUnit = &StructuralUnit) AS InventoryBalances
	|		LEFT JOIN InformationRegister.Prices.SliceLast(
	|				&Period,
	|				Actuality
	|					AND PriceKind = &PriceKind) AS PricesSliceLast
	|		ON InventoryBalances.Products = PricesSliceLast.Products
	|			AND InventoryBalances.Characteristic = PricesSliceLast.Characteristic
	|		LEFT JOIN InformationRegister.AccountingPolicy.SliceLast(&Period, ) AS AccountingPolicySliceLast
	|		ON InventoryBalances.Company = AccountingPolicySliceLast.Company
	|WHERE
	|	InventoryBalances.Products <> VALUE(Catalog.Products.EmptyRef)";

	Query.SetParameter("Period",	Object.Date);
	Query.SetParameter("Company",	ParentCompany);
	Query.SetParameter("PriceKind",	Object.PriceKind);
	
	If ValueIsFilled(Object.DiscountMarkupKind) Then
		Query.SetParameter("DiscountMarkupPercent", Object.DiscountMarkupKind.Percent);
	Else
		Query.SetParameter("DiscountMarkupPercent", 0);
	EndIf;
	
	Query.SetParameter("StructuralUnit", Object.StructuralUnit);
	
	Object.Inventory.Load(Query.Execute().Unload());
		
	FillAddedColumns(True);

EndProcedure

#EndRegion

#Region ProceduresAndFunctionsForControlOfTheFormAppearance

// Procedure sets the form item visible.
//
// Parameters:
//  No.
//
&AtServer
Procedure SetVisibleFromUserSettings()
	
	If Object.PositionResponsible = Enums.AttributeStationing.InHeader Then
		Items.Responsible.Visible = True;
		Items.InventoryResponsible.Visible = False;
	Else
		Items.Responsible.Visible = False;
		Items.InventoryResponsible.Visible = True;
	EndIf;
	
EndProcedure

#Region FormEventHandlers

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	FillAddedColumns();
EndProcedure

&AtClient
Procedure ChoiceProcessing(SelectedValue, ChoiceSource)
	
	If ChoiceSource.FormName = "CommonForm.ProductGLAccounts" Then
		GLAccountsChoiceProcessingAtClient(SelectedValue);
	EndIf;
	
EndProcedure

// Procedure - event handler OnCreateAtServer of the form.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	DriveServer.FillDocumentHeader(
		Object,
		,
		Parameters.CopyingValue,
		Parameters.Basis,
		PostingIsAllowed
	);
	
	DocumentDate = Object.Date;
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentDate();
	EndIf;
	
	ParentCompany = DriveServer.GetCompany(Object.Company);
	
	If Not ValueIsFilled(Object.Ref)
	   AND Not ValueIsFilled(Parameters.CopyingValue) Then
		Object.Responsible = DriveReUse.GetValueByDefaultUser(Users.CurrentUser(), "MainResponsible");
	EndIf;
	
	CashCRType = Catalogs.CashRegisters.GetCashRegisterAttributes(Object.CashCR).CashCRType;
	Items.GroupCashCRSession.Visible = CashCRType = Enums.CashRegisterTypes.FiscalRegister;
	
	StructureByCurrency = InformationRegisters.ExchangeRates.GetLast(Object.Date, New Structure("Currency", Object.DocumentCurrency));
	ExchangeRate = ?(
		StructureByCurrency.ExchangeRate = 0,
		1,
		StructureByCurrency.ExchangeRate
	);
	Multiplicity = ?(
		StructureByCurrency.ExchangeRate = 0,
		1,
		StructureByCurrency.Multiplicity
	);
	
	StructureByCurrency = InformationRegisters.ExchangeRates.GetLast(Object.Date, New Structure("Currency", Constants.FunctionalCurrency.Get()));
	RateNationalCurrency = StructureByCurrency.ExchangeRate;
	RepetitionNationalCurrency = StructureByCurrency.Multiplicity;
	
	If Not ValueIsFilled(Object.Ref)
		AND Not ValueIsFilled(Parameters.Basis) 
		AND Not ValueIsFilled(Parameters.CopyingValue) Then
		FillVATRateByCompanyVATTaxation();
	ElsIf Object.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then
		Items.InventoryVATRate.Visible = True;
		Items.InventoryVATAmount.Visible = True;
		Items.InventoryAmountTotal.Visible = True;
		Items.VATAmount.Visible = True;
	Else
		Items.InventoryVATRate.Visible = False;
		Items.InventoryVATAmount.Visible = False;
		Items.InventoryAmountTotal.Visible = False;
		Items.VATAmount.Visible = False;
	EndIf;
	
	ForeignExchangeAccounting = Constants.ForeignExchangeAccounting.Get();
	LabelStructure = New Structure("PriceKind, DiscountKind, DocumentCurrency, SettlementsCurrency, ExchangeRate, RateNationalCurrency, AmountIncludesVAT, ForeignExchangeAccounting, VATTaxation", Object.PriceKind, Object.DiscountMarkupKind, Object.DocumentCurrency, Object.DocumentCurrency, ExchangeRate, RateNationalCurrency, Object.AmountIncludesVAT, ForeignExchangeAccounting, Object.VATTaxation);
	PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
	
	// Attribute visible set from user settings
	SetVisibleFromUserSettings(); 
	
	Items.InventoryDiscountAmount.Visible = Constants.UseManualDiscounts.Get();
	
	// Price accessibility setup for editing.
	AllowedEditDocumentPrices = DriveAccessManagementReUse.AllowedEditDocumentPrices();
	SaleFromWarehouse = Object.StructuralUnit.StructuralUnitType = Enums.BusinessUnitsTypes.Warehouse;
	
	FillAddedColumns();
	
	Items.InventoryPrice.ReadOnly 					= Not AllowedEditDocumentPrices OR Not SaleFromWarehouse;
	Items.InventoryAmount.ReadOnly 				= Not AllowedEditDocumentPrices OR Not SaleFromWarehouse; 
	Items.InventoryDiscountPercentMargin.ReadOnly  = Not AllowedEditDocumentPrices;
	Items.InventoryDiscountAmount.ReadOnly 			= Not AllowedEditDocumentPrices;
	Items.InventoryVATAmount.ReadOnly 				= Not AllowedEditDocumentPrices;
	
	// AutomaticDiscounts
	AutomaticDiscountsOnCreateAtServer();
	// End AutomaticDiscounts
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisForm, Items.ImportantCommandsGroup);
	// End StandardSubsystems.Printing
	
	// Peripherals
	UsePeripherals = DriveReUse.UsePeripherals();
	ListOfElectronicScales = EquipmentManagerServerCall.GetEquipmentList("ElectronicScales", , EquipmentManagerServerCall.GetClientWorkplace());
	If ListOfElectronicScales.Count() = 0 Then
		// There are no connected scales.
		Items.InventoryGetWeight.Visible = False;
	EndIf;
	Items.InventoryImportDataFromDCT.Visible = UsePeripherals;
	// End Peripherals
	
	// Serial numbers
	UseSerialNumbersBalance = WorkWithSerialNumbers.UseSerialNumbersBalance();
	
EndProcedure

// Procedure - OnReadAtServer event handler.
//
&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	FillAddedColumns();
	ClosingDates.ObjectOnReadAtServer(ThisForm, CurrentObject);
	
EndProcedure

// Procedure - event handler AfterWriting.
//
&AtClient
Procedure AfterWrite(WriteParameters)
	
	Notify("UpdateDiscountAmount");
	
EndProcedure

// Procedure - OnOpen form event handler
//
&AtClient
Procedure OnOpen(Cancel)

	// Peripherals
	EquipmentManagerClientOverridable.StartConnectingEquipmentOnFormOpen(ThisForm, "BarCodeScanner");
	// End Peripherals
	
	For Each CurRow In Object.Inventory Do
		CurRow.DiscountAmount = CurRow.Price * CurRow.Quantity - CurRow.Amount;
	EndDo;
	
	RecalculateSubtotal();
	
EndProcedure

// Procedure - event handler OnClose form.
//
&AtClient
Procedure OnClose(Exit)

	// Peripherals
	EquipmentManagerClientOverridable.StartDisablingEquipmentOnCloseForm(ThisForm);
	// End Peripherals

EndProcedure

// Procedure - event handler of the form NotificationProcessing.
//
&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	// Peripherals
	If Source = "Peripherals"
	   AND IsInputAvailable() Then
		If EventName = "ScanData" Then
			// Transform preliminary to the expected format
			Data = New Array();
			If Parameter[1] = Undefined Then
				Data.Add(New Structure("Barcode, Quantity", Parameter[0], 1)); // Get a barcode from the basic data
			Else
				Data.Add(New Structure("Barcode, Quantity", Parameter[1][1], 1)); // Get a barcode from the additional data
			EndIf;
			
			BarcodesReceived(Data);
		EndIf;
	EndIf;
	// End Peripherals
	
	If EventName = "RefreshFormsAfterClosingCashCRSession" Then
		
		Read();
		
	ElsIf EventName = "UpdateDiscountAmount" Then
		
		For Each CurRow In Object.Inventory Do
			
			CurRow.DiscountAmount = CurRow.Price * CurRow.Quantity - CurRow.Amount;
		EndDo;
		
		RecalculateSubtotal();
		
	ElsIf EventName = "SerialNumbersSelection"
		AND ValueIsFilled(Parameter) 
		// Form owner checkup
		AND Source <> New UUID("00000000-0000-0000-0000-000000000000")
		AND Source = UUID
		Then
		
		ChangedCount = GetSerialNumbersFromStorage(Parameter.AddressInTemporaryStorage, Parameter.RowKey);
		If ChangedCount Then
			CalculateAmountInTabularSectionLine();
		EndIf; 
		
	EndIf;
	
EndProcedure

#EndRegion

#Region ProcedureActionsOfTheFormCommandPanels

// Peripherals
// Procedure - command handler of the tabular section command panel.
//
&AtClient
Procedure SearchByBarcode(Command)
	
	CurBarcode = "";
	ShowInputValue(New NotifyDescription("SearchByBarcodeEnd", ThisObject, New Structure("CurBarcode", CurBarcode)), CurBarcode, NStr("en = 'Enter barcode'"));

EndProcedure

&AtClient
Procedure SearchByBarcodeEnd(Result, AdditionalParameters) Export
	
	CurBarcode = ?(Result = Undefined, AdditionalParameters.CurBarcode, Result);
	
	
	If Not IsBlankString(CurBarcode) Then
		BarcodesReceived(New Structure("Barcode, Quantity", CurBarcode, 1));
	EndIf;

EndProcedure

// Procedure - event handler Action of the GetWeight command
//
&AtClient
Procedure GetWeight(Command)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	If TabularSectionRow = Undefined Then
		
		ShowMessageBox(Undefined, NStr("en = 'Select a line for which the weight should be received.'"));
		
	ElsIf EquipmentManagerClient.RefreshClientWorkplace() Then // Checks if the operator's workplace is specified
		
		NotifyDescription = New NotifyDescription("GetWeightEnd", ThisObject, TabularSectionRow);
		EquipmentManagerClient.StartWeightReceivingFromElectronicScales(NotifyDescription, UUID);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure GetWeightEnd(Weight, Parameters) Export
	
	TabularSectionRow = Parameters;
	
	If Not Weight = Undefined Then
		If Weight = 0 Then
			MessageText = NStr("en = 'Electronic scales returned zero weight.'");
			CommonUseClientServer.MessageToUser(MessageText);
		Else
			// Weight is received.
			TabularSectionRow.Quantity = Weight;
			CalculateAmountInTabularSectionLine(TabularSectionRow);
		EndIf;
	EndIf;
	
EndProcedure

// Procedure - ImportDataFromDTC command handler.
//
&AtClient
Procedure ImportDataFromDCT(Command)
	
	NotificationsAtImportFromDCT = New NotifyDescription("ImportFromDCTEnd", ThisObject);
	EquipmentManagerClient.StartImportDataFromDCT(NotificationsAtImportFromDCT, UUID);
	
EndProcedure

&AtClient
Procedure ImportFromDCTEnd(Result, Parameters) Export
	
	If TypeOf(Result) = Type("Array") 
	   AND Result.Count() > 0 Then
		BarcodesReceived(Result);
	EndIf;
	
EndProcedure

// End Peripherals

// Procedure - event handler Action of the Pick command
//
&AtClient
Procedure Pick(Command)
	
	TabularSectionName	= "Inventory";
	DocumentPresentaion	= NStr("en = 'shift closure (z-report)'");
	SelectionParameters	= DriveClient.GetSelectionParameters(ThisObject, TabularSectionName, DocumentPresentaion, True, True, False);
	SelectionParameters.Insert("Company", ParentCompany);
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

// Procedure - FillInByBalanceOnWarehouse button clicking handler.
// 
&AtClient
Procedure CommandFillByBalanceAtWarehouse()
	
	If Object.Inventory.Count() > 0 Then
		Response = Undefined;

		ShowQueryBox(New NotifyDescription("FillCommandByBalanceOnWarehouseEnd", ThisObject), NStr("en = 'Tabular section will be cleared. Continue?'"), QuestionDialogMode.YesNo, 0);
		Return; 
	EndIf;
	
	FillCommandByBalanceOnWarehouseFragment();
EndProcedure

&AtClient
Procedure FillCommandByBalanceOnWarehouseEnd(Result, AdditionalParameters) Export
	
	Response = Result;
	If Response <> DialogReturnCode.Yes Then
		Return;
	EndIf; 
	
	FillCommandByBalanceOnWarehouseFragment();

EndProcedure

&AtClient
Procedure FillCommandByBalanceOnWarehouseFragment()
	
	Var CurRow;
	
	FillByBalanceAtWarehouse();
	
	For Each CurRow In Object.Inventory Do
		CalculateAmountInTabularSectionLine(CurRow);
	EndDo;

EndProcedure

// Procedure - command handler DocumentSetup.
//
&AtClient
Procedure DocumentSetup(Command)
	
	// 1. Form parameter structure to fill "Document setting" form.
	ParametersStructure = New Structure;
	ParametersStructure.Insert("PositionResponsible", Object.PositionResponsible);
	ParametersStructure.Insert("WereMadeChanges", False);
	
	StructureDocumentSetting = Undefined;

	
	OpenForm("CommonForm.DocumentSetup", ParametersStructure,,,,, New NotifyDescription("DocumentSettingEnd", ThisObject));
	
EndProcedure

&AtClient
Procedure DocumentSettingEnd(Result, AdditionalParameters) Export
	
	// 2. Open the form "Prices and Currency".
	StructureDocumentSetting = Result;
	
	// 3. Apply changes made in "Document setting" form.
	If TypeOf(StructureDocumentSetting) = Type("Structure") AND StructureDocumentSetting.WereMadeChanges Then
		
		Object.PositionResponsible = StructureDocumentSetting.PositionResponsible;
		SetVisibleFromUserSettings();
		
	EndIf;

EndProcedure

&AtClient
Procedure PrintSimplifiedTaxInvoiceForCurrentReceipt(Command)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	If TabularSectionRow = Undefined Then
		Return;
	EndIf;
	
	If Modified Or Object.Ref.IsEmpty() Then
		
		MessageText = NStr("en = 'Data was changed. Save the document and try again.'");
		
		ShowMessageBox(Undefined, MessageText);
		Return;
		
	EndIf;
	
	OpenParameters = New Structure("PrintManagerName, TemplateNames, CommandParameter, PrintParameters");
	OpenParameters.PrintManagerName = "Document.SalesSlip";
	OpenParameters.TemplateNames	= "SimplifiedTaxInvoice";
	
	DataStructure = New Structure;
	DataStructure.Insert("Date",			Object.Date);
	DataStructure.Insert("ReceiptNumber",	TabularSectionRow.ReceiptNumber);
	DataStructure.Insert("Company",			Object.Company);
	DataStructure.Insert("CashCR",			Object.CashCR);
	
	ObjectsArray = New Array;
	ObjectsArray.Add(PredefinedValue("Document.SalesSlip.EmptyRef"));
	ObjectsArray.Add(DataStructure);
	
	OpenParameters.CommandParameter	= ObjectsArray;
	OpenParameters.PrintParameters	= Undefined;
	
	OpenForm("CommonForm.PrintDocuments", OpenParameters, ThisForm, UniqueKey);
	
EndProcedure

&AtClient
Procedure PrintSimplifiedTaxInvoice(Command)
	
	If Modified Or Object.Ref.IsEmpty() Then
		
		MessageText = NStr("en = 'Data was changed. Save the document and try again.'");
		
		ShowMessageBox(Undefined, MessageText);
		Return;
		
	EndIf;
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("Date", Object.Date);
	ParametersStructure.Insert("Company", Object.Company);
	ParametersStructure.Insert("CashCR", Object.CashCR);
	
	OpenForm("DataProcessor.PrintSimplifiedTaxInvoice.Form", ParametersStructure, ThisObject);
	
EndProcedure

// Procedure of processing the results of selection closing
//
&AtClient
Procedure OnCloseSelection(ClosingResult, AdditionalParameters) Export
	
	If TypeOf(ClosingResult) = Type("Structure") Then
		
		If Not IsBlankString(ClosingResult.CartAddressInStorage) Then
			
			InventoryAddressInStorage = ClosingResult.CartAddressInStorage;
			
			GetInventoryFromStorage(InventoryAddressInStorage, "Inventory", True, True);
			
			RecalculateSubtotal();
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region ProcedureEventHandlersOfHeaderAttributes

// Procedure - OnChange event handler of the CashCRSessionStatus field on server.
//
&AtServer
Procedure CashCRSessionStatusOnChangeAtServer()
	
	If Object.CashCRSessionStatus = Enums.ShiftClosureStatus.IsOpen Then
		
		Object.CashCRSessionEnd = Date(1,1,1);
		
	EndIf;
	
EndProcedure

// Procedure - OnChange event handler of the CashCRSessionStatusOnChange field.
//
&AtClient
Procedure CashCRSessionStatusOnChange(Item)
	
	CashCRSessionStatusOnChangeAtServer();
	
EndProcedure

// Procedure - OnChange event handler of the Date field on server.
//
&AtServer
Procedure DateOnChangeAtServer()
	
	If Catalogs.CashRegisters.GetCashRegisterAttributes(Object.CashCR).CashCRType <> Enums.CashRegisterTypes.FiscalRegister Then
		Object.CashCRSessionStart = BegOfDay(Object.Date);
		Object.CashCRSessionEnd = EndOfDay(Object.Date);
	EndIf;
	
EndProcedure

// Procedure - OnChange event handler of the Date field.
//
&AtClient
Procedure DateOnChange(Item)
	
	DateOnChangeAtServer();
	
	// Date change event DataProcessor.
	DateBeforeChange = DocumentDate;
	DocumentDate = Object.Date;
	If Object.Date <> DateBeforeChange Then
		StructureData = GetDataDateOnChange(DateBeforeChange);
		If StructureData.DATEDIFF <> 0 Then
			Object.Number = "";
		EndIf;
		
		// Generate price and currency label.
		LabelStructure = New Structure("PriceKind, DiscountKind, DocumentCurrency, SettlementsCurrency, ExchangeRate, RateNationalCurrency, AmountIncludesVAT, ForeignExchangeAccounting, VATTaxation", Object.PriceKind, Object.DiscountMarkupKind, Object.DocumentCurrency, Object.DocumentCurrency, ExchangeRate, RateNationalCurrency, Object.AmountIncludesVAT, ForeignExchangeAccounting, Object.VATTaxation);
		PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
		
	EndIf;
	
EndProcedure

// Procedure - event handler OnChange field CashRegister on server.
//
&AtServer
Procedure CashCROnChangeAtServer()
	
	CashRegisterAttributes = Catalogs.CashRegisters.GetCashRegisterAttributes(Object.CashCR);
	FillPropertyValues(Object, CashRegisterAttributes);
	
	ParentCompany = DriveServer.GetCompany(Object.Company);
	
	FillVATRateByCompanyVATTaxation();
	
	Items.GroupCashCRSession.Visible = CashRegisterAttributes.CashCRType = Enums.CashRegisterTypes.FiscalRegister;
	
	Items.InventoryPrice.ReadOnly = Object.StructuralUnit.StructuralUnitType <> Enums.BusinessUnitsTypes.Warehouse;
	Items.InventoryAmount.ReadOnly = Object.StructuralUnit.StructuralUnitType <> Enums.BusinessUnitsTypes.Warehouse;
	
EndProcedure

// Procedure - event handler OnChange field CashCR.
//
&AtClient
Procedure CashCROnChange(Item)
	
	CashCROnChangeAtServer();
	DriveClient.RefillTabularSectionPricesByPriceKind(ThisForm, "Inventory", True);
	RecalculateDocumentAtClient();
	
	// Generate price and currency label.
	LabelStructure = New Structure("PriceKind, DiscountKind, DocumentCurrency, SettlementsCurrency, ExchangeRate, RateNationalCurrency, AmountIncludesVAT, ForeignExchangeAccounting, VATTaxation", Object.PriceKind, Object.DiscountMarkupKind, Object.DocumentCurrency, Object.DocumentCurrency, ExchangeRate, RateNationalCurrency, Object.AmountIncludesVAT, ForeignExchangeAccounting, Object.VATTaxation);
	PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
	
EndProcedure

// Procedure - OnChange event handler of the Warehouse field on server.
//
&AtServer
Procedure StructuralUnitOnChangeAtServer()
	
	Query = New Query;
	Query.Text = 
	"SELECT TOP 1
	|	BusinessUnits.Ref AS StructuralUnit,
	|	BusinessUnits.RetailPriceKind AS PriceKind,
	|	BusinessUnits.RetailPriceKind.PriceIncludesVAT AS PriceIncludesVAT
	|FROM
	|	Catalog.BusinessUnits AS BusinessUnits
	|WHERE
	|	BusinessUnits.Ref = &Ref";
	
	Query.SetParameter("Ref", Object.StructuralUnit);
	
	Result = Query.Execute();
	Selection = Result.Select();
	
	While Selection.Next() Do
		FillPropertyValues(Object, Selection);
	EndDo;
	
	FillAddedColumns(True);
	FillVATRateByCompanyVATTaxation();
	
	Items.InventoryPrice.ReadOnly = Object.StructuralUnit.StructuralUnitType <> Enums.BusinessUnitsTypes.Warehouse;
	Items.InventoryAmount.ReadOnly = Object.StructuralUnit.StructuralUnitType <> Enums.BusinessUnitsTypes.Warehouse;
	
EndProcedure

// Procedure - OnChange event handler of the StructuralUnit field.
//
&AtClient
Procedure StructuralUnitOnChange(Item)
	
	StructuralUnitOnChangeAtServer();
	DriveClient.RefillTabularSectionPricesByPriceKind(ThisForm, "Inventory", True);
	RecalculateDocumentAtClient();
	
	// Generate price and currency label.
	LabelStructure = New Structure("PriceKind, DiscountKind, DocumentCurrency, SettlementsCurrency, ExchangeRate, RateNationalCurrency, AmountIncludesVAT, ForeignExchangeAccounting, VATTaxation", Object.PriceKind, Object.DiscountMarkupKind, Object.DocumentCurrency, Object.DocumentCurrency, ExchangeRate, RateNationalCurrency, Object.AmountIncludesVAT, ForeignExchangeAccounting, Object.VATTaxation);
	PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
	
EndProcedure

// Procedure - event handler OnChange of the Company input field.
// In procedure is executed document
// number clearing and also make parameter set of the form functional options.
// Overrides the corresponding form parameter.
//
&AtClient
Procedure CompanyOnChange(Item)

	// Company change event data processor.
	Object.Number = "";
	StructureData = GetCompanyDataOnChange();
	ParentCompany = StructureData.ParentCompany;
	
	// Generate price and currency label.
	LabelStructure = New Structure("PriceKind, DiscountKind, DocumentCurrency, SettlementsCurrency, ExchangeRate, RateNationalCurrency, AmountIncludesVAT, ForeignExchangeAccounting, VATTaxation", Object.PriceKind, Object.DiscountMarkupKind, Object.DocumentCurrency, Object.DocumentCurrency, ExchangeRate, RateNationalCurrency, Object.AmountIncludesVAT, ForeignExchangeAccounting, Object.VATTaxation);
	PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
	
EndProcedure

#EndRegion

#Region EventHandlersOfTheInventoryTabularSectionAttributes

// Procedure - event handler OnChange of the Products input field.
//
&AtClient
Procedure InventoryProductsOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	StructureData = New Structure();
	StructureData.Insert("Company", Object.Company);
	StructureData.Insert("Products", TabularSectionRow.Products);
	StructureData.Insert("Characteristic", TabularSectionRow.Characteristic);
	StructureData.Insert("VATTaxation", Object.VATTaxation);
	
	If ValueIsFilled(Object.PriceKind) Then
		
		StructureData.Insert("ProcessingDate", Object.Date);
		StructureData.Insert("DocumentCurrency",  Object.DocumentCurrency);
		StructureData.Insert("AmountIncludesVAT", Object.AmountIncludesVAT);
		StructureData.Insert("PriceKind", Object.PriceKind);
		StructureData.Insert("Factor", 1);
		StructureData.Insert("DiscountMarkupKind", Object.DiscountMarkupKind);
		
	EndIf;
	
	AddGLAccountsToStructure(StructureData, TabularSectionRow);	
	StructureData.Insert("ObjectParameters", GLAccountsInDocumentsClientServer.GetObjectParameters(Object));
	StructureData = GetDataProductsOnChange(StructureData);
	
	FillPropertyValues(TabularSectionRow, StructureData); 
	TabularSectionRow.MeasurementUnit = StructureData.MeasurementUnit;
	TabularSectionRow.Quantity = 1;
	TabularSectionRow.Price = StructureData.Price;
	TabularSectionRow.DiscountMarkupPercent = StructureData.DiscountMarkupPercent;
	TabularSectionRow.VATRate = StructureData.VATRate;
	
	CalculateAmountInTabularSectionLine();
	
	// Serial numbers
	WorkWithSerialNumbersClientServer.DeleteSerialNumbersByConnectionKey(Object.SerialNumbers, TabularSectionRow, , UseSerialNumbersBalance);
	
EndProcedure

// Procedure - event handler OnChange of the Characteristic input field.
//
&AtClient
Procedure InventoryCharacteristicOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
		
	StructureData = New Structure;
	StructureData.Insert("Products",	 TabularSectionRow.Products);
	StructureData.Insert("Characteristic",	 TabularSectionRow.Characteristic);
		
	If ValueIsFilled(Object.PriceKind) Then
		
		StructureData.Insert("ProcessingDate",	 	Object.Date);
		StructureData.Insert("DocumentCurrency",	 	Object.DocumentCurrency);
		StructureData.Insert("AmountIncludesVAT", 	Object.AmountIncludesVAT);
		
		StructureData.Insert("VATRate", 			TabularSectionRow.VATRate);
		StructureData.Insert("Price",			 	TabularSectionRow.Price);
		
		StructureData.Insert("PriceKind", Object.PriceKind);
		StructureData.Insert("MeasurementUnit", TabularSectionRow.MeasurementUnit);
		
	EndIf;
				
	StructureData = GetDataCharacteristicOnChange(StructureData);
	
	TabularSectionRow.Price = StructureData.Price;
			
	CalculateAmountInTabularSectionLine();
	
EndProcedure

// Procedure - event handler OnChange of the Count input field.
//
&AtClient
Procedure InventoryQuantityOnChange(Item)
	
	CalculateAmountInTabularSectionLine();
	
EndProcedure

// Procedure - event handler ChoiceProcessing of the MeasurementUnit input field.
//
&AtClient
Procedure InventoryMeasurementUnitChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	If TabularSectionRow.MeasurementUnit = ValueSelected 
		OR TabularSectionRow.Price = 0 Then
		Return;
	EndIf;
	
	CurrentFactor = 0;
	If TypeOf(TabularSectionRow.MeasurementUnit) = Type("CatalogRef.UOMClassifier") Then
		CurrentFactor = 1;
	EndIf;
	
	Factor = 0;
	If TypeOf(ValueSelected) = Type("CatalogRef.UOMClassifier") Then
		Factor = 1;
	EndIf;
	
	If CurrentFactor = 0 AND Factor = 0 Then
		StructureData = GetDataMeasurementUnitOnChange(TabularSectionRow.MeasurementUnit, ValueSelected);
	ElsIf CurrentFactor = 0 Then
		StructureData = GetDataMeasurementUnitOnChange(TabularSectionRow.MeasurementUnit);
	ElsIf Factor = 0 Then
		StructureData = GetDataMeasurementUnitOnChange(,ValueSelected);
	ElsIf CurrentFactor = 1 AND Factor = 1 Then
		StructureData = New Structure("CurrentFactor, Factor", 1, 1);
	EndIf;
	
	// Price.
	If StructureData.CurrentFactor <> 0 Then
		TabularSectionRow.Price = TabularSectionRow.Price * StructureData.Factor / StructureData.CurrentFactor;
	EndIf;
	
	CalculateAmountInTabularSectionLine();
	
EndProcedure

// Procedure - event handler OnChange of the Price input field.
//
&AtClient
Procedure InventoryPriceOnChange(Item)
	
	CalculateAmountInTabularSectionLine();
	
EndProcedure

// Procedure - event handler OnChange of the DiscountMarkupPercent input field.
//
&AtClient
Procedure InventoryDiscountMarkupPercentOnChange(Item)
	
	CalculateAmountInTabularSectionLine();
	
EndProcedure

// Procedure - OnChange event handler of the DiscountAmount input field.
//
&AtClient
Procedure InventoryOfDiscountAmountIfYouChange(Item)
	
	CalculateDiscountPercent();
	
EndProcedure

// Procedure - event handler OnChange of the Amount input field.
//
&AtClient
Procedure InventoryAmountOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	// Price.
	If TabularSectionRow.Quantity <> 0 Then
		TabularSectionRow.Price = TabularSectionRow.Amount / TabularSectionRow.Quantity;
	EndIf;
	
	// Discount.
	If TabularSectionRow.DiscountMarkupPercent = 100 Then
		TabularSectionRow.Price = 0;
	ElsIf TabularSectionRow.DiscountMarkupPercent <> 0 AND TabularSectionRow.Quantity <> 0 Then
		TabularSectionRow.Price = TabularSectionRow.Amount / ((1 - TabularSectionRow.DiscountMarkupPercent / 100) * TabularSectionRow.Quantity);
	EndIf;
	
	CalculateVATSUM(TabularSectionRow);
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	TabularSectionRow.DiscountAmount = TabularSectionRow.Quantity * TabularSectionRow.Price - TabularSectionRow.Amount;
	
EndProcedure

// Procedure - event handler OnChange of the VATRate input field.
//
&AtClient
Procedure InventoryVATRateOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	CalculateVATSUM(TabularSectionRow);
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
EndProcedure

// Procedure - event handler OnChange of the VATRate input field.
//
&AtClient
Procedure InventoryVATAmountOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);	
	
EndProcedure

// Procedure - event handler OnEditEnd of the Inventory list row.
//
&AtClient
Procedure InventoryOnEditEnd(Item, NewRow, CancelEdit)
	
	ThisIsNewRow = False;
	RecalculateDocumentAtClient();
	
EndProcedure

// Procedure - event handler AfterDeletion of the Inventory list row.
//
&AtClient
Procedure InventoryAfterDeleteRow(Item)
	
	RecalculateDocumentAtClient();
	
EndProcedure

// Procedure - OnEndEdit event handler of the PaymentCardsPayment tabular section row.
//
&AtClient
Procedure PaymentWithPaymentCardsOnEditEnd(Item, NewRow, CancelEdit)
	
	RecalculateDocumentAtClient();
	
EndProcedure

// Procedure - OnStartEdit event handler of the Inventory tabular section row.
//
&AtClient
Procedure InventoryOnStartEdit(Item, NewRow, Copy)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	If Not ValueIsFilled(TabularSectionRow.Responsible) Then
		TabularSectionRow.Responsible = Object.Responsible;
	EndIf;
	
	If NewRow AND Copy Then
		Item.CurrentData.ConnectionKey = 0;
		Item.CurrentData.SerialNumbers = "";
	EndIf;
	
	If Item.CurrentItem.Name = "InventorySerialNumbers" Then
		OpenSerialNumbersSelection();
	EndIf;
	
	If Not NewRow Or Copy Then
		Return;	
	EndIf;
	
	Item.CurrentData.GLAccounts = GLAccountsInDocumentsClientServer.GetEmptyGLAccountPresentation();
	
EndProcedure

&AtClient
Procedure InventoryBeforeDeleteRow(Item, Cancel)
	
	// Serial numbers
	CurrentData = Items.Inventory.CurrentData;
	WorkWithSerialNumbersClientServer.DeleteSerialNumbersByConnectionKey(Object.SerialNumbers, CurrentData, , UseSerialNumbersBalance);
	
EndProcedure

&AtClient
Procedure InventorySelection(Item, SelectedRow, Field, StandardProcessing)
	
	If Field.Name = "InventoryGLAccounts" Then
		StandardProcessing = False;
		OpenProductGLAccountsForm(SelectedRow);
	EndIf;
	
EndProcedure

&AtClient
Procedure InventoryOnActivateCell(Item)
	
	CurrentData = Items.Inventory.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If ThisIsNewRow Then
		TableCurrentColumn = Items.Inventory.CurrentItem;
		If TableCurrentColumn.Name = "InventoryGLAccounts"
			And Not CurrentData.GLAccountsFilled Then
			SelectedRow = Items.Inventory.CurrentRow;
			OpenProductGLAccountsForm(SelectedRow);
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure InventoryGLAccountsStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	SelectedRow = Items.Inventory.CurrentRow;
	OpenProductGLAccountsForm(SelectedRow);
	
EndProcedure

&AtClient
Procedure InventorySerialNumbersStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	OpenSerialNumbersSelection();
	
EndProcedure

&AtClient
Procedure PaymentWithPaymentCardsOnActivateCell(Item)
	
	If TypeOf(Item)=Type("FormTable") AND TypeOf(Item.CurrentItem)=Type("FormField") Then
		
		Name = Item.CurrentItem.Name;
		
		If Name = "PaymentByChargeCardTypeCards" Then
			
			If Item.CurrentData = Undefined Then
				Return;
			EndIf;
			
			ArrayCardsTypes = GetPaymentCardKindsArray(Item.CurrentData.POSTerminal);
			Item.CurrentItem.ChoiceList.LoadValues(ArrayCardsTypes);
			
		EndIf;
		
	EndIf;

EndProcedure

#EndRegion

#Region LibrariesHandlers

// StandardSubsystems.AdditionalReportsAndDataProcessors
&AtClient
Procedure Attachable_ExecuteAssignedCommand(Command)
	If Not AdditionalReportsAndDataProcessorsClient.ExecuteAllocatedCommandAtClient(ThisForm, Command.Name) Then
		ExecutionResult = Undefined;
		AdditionalReportsAndProcessingsExecuteAllocatedCommandAtServer(Command.Name, ExecutionResult);
		AdditionalReportsAndDataProcessorsClient.ShowCommandExecutionResult(ThisForm, ExecutionResult);
	EndIf;
EndProcedure

&AtServer
Procedure AdditionalReportsAndProcessingsExecuteAllocatedCommandAtServer(ItemName, ExecutionResult)
	AdditionalReportsAndDataProcessors.ExecuteAllocatedCommandAtServer(ThisForm, ItemName, ExecutionResult);
EndProcedure
// End StandardSubsystems.AdditionalReportsAndDataProcessors

// StandardSubsystems.Printing
&AtClient
Procedure Attachable_ExecutePrintCommand(Command)
	PrintManagementClient.ExecuteConnectedPrintCommand(Command, ThisObject, Object);
EndProcedure

&AtClient
Procedure PricesAndCurrencyClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	ProcessChangesOnButtonPricesAndCurrencies(Object.DocumentCurrency);
	Modified = True;
	
EndProcedure

// End StandardSubsystems.Printing

#EndRegion

#Region AutomaticDiscounts

// Procedure executes necessary actions when creating the form on server.
//
&AtServer
Procedure AutomaticDiscountsOnCreateAtServer()

	UseAutomaticDiscounts = GetFunctionalOption("UseAutomaticDiscounts");

EndProcedure

#EndRegion

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure OpenSerialNumbersSelection()
		
	CurrentDataIdentifier = Items.Inventory.CurrentData.GetID();
	ParametersOfSerialNumbers = SerialNumberPickParameters(CurrentDataIdentifier);
	
	OpenForm("DataProcessor.SerialNumbersSelection.Form", ParametersOfSerialNumbers, ThisObject);

EndProcedure

&AtServer
Function GetSerialNumbersFromStorage(AddressInTemporaryStorage, RowKey)
	
	Modified = True;
	Return WorkWithSerialNumbers.GetSerialNumbersFromStorage(Object, AddressInTemporaryStorage, RowKey);
	
EndFunction

&AtServer
Function SerialNumberPickParameters(CurrentDataIdentifier)
	
	Return WorkWithSerialNumbers.SerialNumberPickParameters(Object, ThisObject.UUID, CurrentDataIdentifier, False);
	
EndFunction

&AtClient
Procedure OpenProductGLAccountsForm(SelectedValue)

	If SelectedValue = Undefined Then
		Return;
	EndIf;

	If Not ReadOnly Then
		LockFormDataForEdit();
	EndIf;

	RowData = Object.Inventory.FindByID(SelectedValue);
	
	ObjectParameters = GLAccountsInDocumentsClientServer.GetObjectParameters(Object);
	StructureData = GetStructureData(ObjectParameters, RowData);
	
	GLAccountsForFilling = GLAccountsInDocumentsClientServer.GetGLAccountsStructure(StructureData);
	GLAccountsForFilling.Insert("TableName",	"Inventory");
	GLAccountsForFilling.Insert("Products",	RowData.Products);

	OpenForm("CommonForm.ProductGLAccounts", GLAccountsForFilling, ThisObject);
	
EndProcedure

&AtClient
Procedure AddGLAccountsToStructure(StructureData, TabRow)
	
	StructureData.Insert("GLAccounts",			TabRow.GLAccounts);
	StructureData.Insert("GLAccountsFilled",	TabRow.GLAccountsFilled);
	StructureData.Insert("InventoryGLAccount",	TabRow.InventoryGLAccount);
	StructureData.Insert("COGSGLAccount",		TabRow.COGSGLAccount);
	StructureData.Insert("RevenueGLAccount",	TabRow.RevenueGLAccount);
	StructureData.Insert("VATOutputGLAccount",	TabRow.VATOutputGLAccount);
	
EndProcedure

&AtServer
Procedure FillAddedColumns(GetGLAccounts = False)
	
	ObjectParameters = GLAccountsInDocumentsClientServer.GetObjectParameters(Object);
	
	Tables = New Array();
	Tables.Add(GetStructureData(ObjectParameters));
	
	GLAccountsInDocuments.FillGLAccountsInTable(Object, Tables, GetGLAccounts);
	
EndProcedure

&AtClient
Procedure GLAccountsChoiceProcessingAtClient(GLAccounts)

	TabRow = Items[GLAccounts.TableName].CurrentData;
	FillPropertyValues(TabRow, GLAccounts);
	Modified = True;
	
	If TabRow.Property("GLAccounts") Then
		ObjectParameters = GLAccountsInDocumentsClientServer.GetObjectParameters(Object);
		StructureData = GetStructureData(ObjectParameters, TabRow);
		
		GLAccountsInDocumentsClientServer.FillProductGLAccountsDescription(StructureData);
		FillPropertyValues(TabRow, StructureData);
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Function GetStructureData(ObjectParameters, RowData = Undefined, ProductName = "Products") Export
	
	StructureData = New Structure("Products, InventoryGLAccount, COGSGLAccount, RevenueGLAccount, VATOutputGLAccount, 
		|GLAccounts, GLAccountsFilled");
	StructureData.Insert("ObjectParameters", ObjectParameters);
	StructureData.Insert("TabName", "Inventory");
	StructureData.Insert("ProductName", ProductName);
	
	If RowData <> Undefined Then 
		FillPropertyValues(StructureData, RowData);
	EndIf;
	
	Return StructureData;

EndFunction

#EndRegion

#Region Initialize

ThisIsNewRow = False;

#EndRegion