
#Region Variables

&AtClient
Var ThisIsNewRow;

#EndRegion

#Region GeneralPurposeProceduresAndFunctions

// Fills amount discounts at client.
//
&AtClient
Procedure FillAmountsDiscounts()
	
	For Each CurRow In Object.Inventory Do
		AmountWithoutDiscount = CurRow.Price * CurRow.Quantity;
		TotalDiscount = AmountWithoutDiscount - CurRow.Amount;
		ManualDiscountAmountMarkups = ?((TotalDiscount - CurRow.AutomaticDiscountAmount) > 0, TotalDiscount - CurRow.AutomaticDiscountAmount, 0);
		
		CurRow.DiscountAmount = TotalDiscount;
		CurRow.AmountDiscountsMarkups = ManualDiscountAmountMarkups;
	EndDo;
	
EndProcedure

// Procedure recalculates the document on client.
//
&AtClient
Procedure RecalculateDocumentAtClient()
	
	Object.DocumentAmount = Object.Inventory.Total("Total");
	
	AmountShortChange = Object.PaymentWithPaymentCards.Total("Amount")
			   + Object.CashReceived
			   - Object.DocumentAmount;
	
	DocumentDiscount = Object.Inventory.Total("DiscountAmount");
	DocumentSubtotal = Object.Inventory.Total("Total") - Object.Inventory.Total("VATAmount") + DocumentDiscount;
	
	GenerateToolTipsToAttributes();
	
	DisplayInformationOnCustomerDisplay();
	
EndProcedure

// Procedure recalculates the document on client.
//
&AtClient
Procedure GenerateToolTipsToAttributes()
	
	TitleAmountCheque = NStr("en = 'Receipt amount ('") + "%Currency%" + ")";
	TitleAmountCheque = StrReplace(TitleAmountCheque, "%Currency%", Object.DocumentCurrency);
	Items.DocumentAmount.ToolTip = TitleAmountCheque;
	
	TitleReceivedCash = NStr("en = 'Received in cash ('") + "%Currency%" + ")";
	TitleReceivedCash = StrReplace(TitleReceivedCash, "%Currency%", Object.DocumentCurrency);
	Items.CashReceived.ToolTip = TitleReceivedCash;
	
	TitlePaymentWithPaymentCards = NStr("en = 'By payment cards ('") + "%Currency%" + ")";
	TitlePaymentWithPaymentCards = StrReplace(TitlePaymentWithPaymentCards, "%Currency%", Object.DocumentCurrency);
	Items.PaymentWithPaymentCardsTotalAmount.ToolTip = TitlePaymentWithPaymentCards;
	
	TitleAmountPutting = NStr("en = 'Change ('") + "%Currency%" + ")";
	TitleAmountPutting = StrReplace(TitleAmountPutting, "%Currency%", Object.DocumentCurrency);
	Items.AmountShortChange.ToolTip = TitleAmountPutting;
	
EndProcedure

&AtClient
Procedure CheckPaymentAmounts(Cancel)
	
	If Object.DocumentAmount > Object.CashReceived + Object.PaymentWithPaymentCards.Total("Amount") Then
		
		ErrorText = NStr("en = 'The payment amount is less than the receipt amount'");
		
		Message = New UserMessage;
		Message.Text = ErrorText;
		Message.Field = "AmountShortChange";
		Message.Message();
		
		Cancel = True;
		
	EndIf;
	
	If Object.DocumentAmount < Object.PaymentWithPaymentCards.Total("Amount") Then
		
		ErrorText = NStr("en = 'The amount of payment by payment cards exceeds the total of a receipt'");
		
		Message = New UserMessage;
		Message.Text = ErrorText;
		Message.Field = "AmountShortChange";
		Message.Message();
		
		Cancel = True;
		
	EndIf;
	
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
				StructureProductsData.Insert("Content", "");
				StructureProductsData.Insert("DiscountMarkupKind", StructureData.DiscountMarkupKind);
			EndIf;
			// DiscountCards
			StructureProductsData.Insert("DiscountPercentByDiscountCard", StructureData.DiscountPercentByDiscountCard);
			StructureProductsData.Insert("DiscountCard", StructureData.DiscountCard);
			// End DiscountCards
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
	StructureData.Insert("VATTaxation", Object.VATTaxation);
	StructureData.Insert("AmountIncludesVAT", Object.AmountIncludesVAT);
	StructureData.Insert("DiscountMarkupKind", Object.DiscountMarkupKind);
	// DiscountCards
	StructureData.Insert("DiscountPercentByDiscountCard", Object.DiscountPercentByDiscountCard);
	StructureData.Insert("DiscountCard", Object.DiscountCard);
	// End DiscountCards
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
			
			If CurBarcode.Property("SerialNumber") AND ValueIsFilled(CurBarcode.SerialNumber) Then
				WorkWithSerialNumbersClientServer.AddSerialNumberToString(NewRow, CurBarcode.SerialNumber, Object);
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
	
	RecalculateDocumentAtClient();
	
EndProcedure

// End Peripherals

// The procedure fills out a list of payment card kinds.
//
&AtServer
Procedure GetChoiceListOfPaymentCardKinds()
	
	ArrayTypesOfPaymentCards = Catalogs.POSTerminals.PaymentCardKinds(Object.POSTerminal);
	
	Items.PaymentByChargeCardTypeCards.ChoiceList.LoadValues(ArrayTypesOfPaymentCards);
	
EndProcedure

// Gets references to external equipment.
//
&AtServer
Procedure GetRefsToEquipment()

	FiscalRegister = ?(
		UsePeripherals // Check for the included FO "Use Peripherals"
	  AND ValueIsFilled(Object.CashCR)
	  AND ValueIsFilled(Object.CashCR.Peripherals),
	  Object.CashCR.Peripherals.Ref,
	  Catalogs.Peripherals.EmptyRef()
	);

	POSTerminal = ?(
		UsePeripherals
	  AND ValueIsFilled(Object.POSTerminal)
	  AND ValueIsFilled(Object.POSTerminal.Peripherals)
	  AND Not Object.POSTerminal.UseWithoutEquipmentConnection,
	  Object.POSTerminal.Peripherals,
	  Catalogs.Peripherals.EmptyRef()
	);

	Items.GroupOfAutomatedPaymentCards.Visible = ValueIsFilled(POSTerminal);
	Items.GroupManualPaymentCards.Visible = Not ValueIsFilled(POSTerminal);
	
	// Context menu
	Items.ContextMenuGroupOfAutomatedPaymentCards.Visible = ValueIsFilled(POSTerminal);
	Items.ContextMenuGroupManualPaymentCards.Visible = Not ValueIsFilled(POSTerminal);
	
	Items.PaymentWithPaymentCards.ReadOnly = ValueIsFilled(POSTerminal);
	
EndProcedure

// Procedure fills the VAT rate in the tabular section
// according to company's taxation system.
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
		Items.InventoryTotalAmountOfVAT.Visible = True;
		
		For Each TabularSectionRow In Object.Inventory Do
			
			If ValueIsFilled(TabularSectionRow.Products.VATRate) Then
				TabularSectionRow.VATRate = TabularSectionRow.Products.VATRate;
			Else
				TabularSectionRow.VATRate = InformationRegisters.AccountingPolicy.GetDefaultVATRate(Object.Date, Object.Company);
			EndIf;
			
			VATRate = DriveReUse.GetVATRateValue(TabularSectionRow.VATRate);
			TabularSectionRow.VATAmount = ?(
				Object.AmountIncludesVAT,
				TabularSectionRow.Amount - (TabularSectionRow.Amount) / ((VATRate + 100) / 100),
				TabularSectionRow.Amount * VATRate / 100
			);
			TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
			
		EndDo;
		
	Else
		
		Items.InventoryVATRate.Visible = False;
		Items.InventoryVATAmount.Visible = False;
		Items.InventoryAmountTotal.Visible = False;
		Items.InventoryTotalAmountOfVAT.Visible = False;
		
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

// Receives the set of data from the server for the ProductsOnChange procedure.
//
&AtServerNoContext
Function GetDataProductsOnChange(StructureData)
	
	GLAccountsInDocuments.FillProductGLAccountsInStructure(StructureData);
	
	StructureData.Insert("MeasurementUnit", StructureData.Products.MeasurementUnit);
	
	StructureData.Insert(
		"Content",
		DriveServer.GetProductsPresentationForPrinting(
			?(ValueIsFilled(StructureData.Products.DescriptionFull),
			StructureData.Products.DescriptionFull, StructureData.Products.Description),
			StructureData.Characteristic, StructureData.Products.SKU)
	);
	
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
		
	If StructureData.Property("DiscountPercentByDiscountCard") 
		AND ValueIsFilled(StructureData.DiscountCard) Then
		CurPercent = StructureData.DiscountMarkupPercent;
		StructureData.Insert("DiscountMarkupPercent", CurPercent + StructureData.DiscountPercentByDiscountCard);
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
	TabularSectionRow.AmountDiscountsMarkups = TabularSectionRow.DiscountAmount;
	
	// AutomaticDiscounts.
	RecalculationIsRequired = ClearCheckboxDiscountsAreCalculatedClient("CalculateAmountInTabularSectionLine");
	
	TabularSectionRow.AutomaticDiscountsPercent = 0;
	TabularSectionRow.AutomaticDiscountAmount = 0;
	TabularSectionRow.TotalDiscountAmountIsMoreThanAmount = False;
	
	// If picture was changed that focus goes from TS and procedure RecalculateDocumentAtClient() is not called.
	If RecalculationIsRequired Then
		RecalculateDocumentAtClient();
	EndIf;
	// End AutomaticDiscounts
	
	// Serial numbers
	If UseSerialNumbersBalance <> Undefined Then
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

// Procedure calculates discount % in tabular section string.
//
&AtClient
Procedure CalculateDiscountMarkupPercent(TabularSectionRow = Undefined)
	
	If TabularSectionRow = Undefined Then
		TabularSectionRow = Items.Inventory.CurrentData;
	EndIf;
	
	// AutomaticDiscounts.
	RecalculationIsRequired = ClearCheckboxDiscountsAreCalculatedClient("CalculateDiscountPercent");
	
	TabularSectionRow.AutomaticDiscountsPercent = 0;
	TabularSectionRow.AutomaticDiscountAmount = 0;
	TabularSectionRow.TotalDiscountAmountIsMoreThanAmount = False;
	
	// If picture was changed that focus goes from TS and procedure RecalculateDocumentAtClient() is not called.
	If RecalculationIsRequired Then
		RecalculateDocumentAtClient();
		DocumentConvertedAtClient = True;
	Else
		DocumentConvertedAtClient = False;
	EndIf;
	// End AutomaticDiscounts
	
	If TabularSectionRow.Quantity * TabularSectionRow.Price < TabularSectionRow.DiscountAmount Then
		TabularSectionRow.AmountDiscountsMarkups = ?((TabularSectionRow.Quantity * TabularSectionRow.Price - TabularSectionRow.AutomaticDiscountAmount) < 0, 
			0, 
			TabularSectionRow.Quantity * TabularSectionRow.Price - TabularSectionRow.AutomaticDiscountAmount);
	EndIf;
	
	TabularSectionRow.DiscountAmount = TabularSectionRow.AmountDiscountsMarkups;
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
		
		NewRow.DiscountAmount = (NewRow.Quantity * NewRow.Price) - NewRow.Amount;
		NewRow.AmountDiscountsMarkups = NewRow.DiscountAmount;
		
		FillPropertyValues(StructureData, NewRow);
		GLAccountsInDocumentsServerCall.FillProductGLAccounts(StructureData, GLAccounts);
		FillPropertyValues(NewRow, StructureData);
		
	EndDo;
	
	// AutomaticDiscounts
	If TableForImport.Count() > 0 Then
		ResetFlagDiscountsAreCalculatedServer("PickDataProcessor");
	EndIf;

EndProcedure

// Procedure recalculates in the document tabular section after making
// changes in the "Prices and currency" form. The columns are
// recalculated as follows: price, discount, amount, VAT amount, total amount.
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
	ParametersStructure.Insert("DiscountCard", Object.DiscountCard);
	ParametersStructure.Insert("ReverseChargeNotApplicable", True);
	
	NotifyDescription = New NotifyDescription("OpenPricesAndCurrencyFormEnd", ThisObject, New Structure("SettlementsCurrencyBeforeChange", SettlementsCurrencyBeforeChange));
	OpenForm("CommonForm.PricesAndCurrency", ParametersStructure, ThisForm, , , , NotifyDescription, FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtClient
// Procedure-handler of the result of opening the "Prices and currencies" form
//
Procedure OpenPricesAndCurrencyFormEnd(ClosingResult, AdditionalParameters) Export
	
	// 3. Refills tabular section "Costs" if changes were made in the "Price and Currency" form.
	If TypeOf(ClosingResult) = Type("Structure")
	   AND ClosingResult.WereMadeChanges Then
		
		Object.PriceKind = ClosingResult.PriceKind;
		Object.DiscountMarkupKind = ClosingResult.DiscountKind;
		// DiscountCards
		// do not verify counterparty in receipts, so. All sales are anonymised.
		Object.DiscountCard = ClosingResult.DiscountCard;
		Object.DiscountPercentByDiscountCard = ClosingResult.DiscountPercentByDiscountCard;
		// End DiscountCards
		Object.VATTaxation = ClosingResult.VATTaxation;
		Object.AmountIncludesVAT = ClosingResult.AmountIncludesVAT;
		Object.IncludeVATInPrice = ClosingResult.IncludeVATInPrice;
		
		// Recalculate prices by kind of prices.
		If ClosingResult.RefillPrices Then
			DriveClient.RefillTabularSectionPricesByPriceKind(ThisForm, "Inventory", True);
			FillAmountsDiscounts();
		EndIf;
		
		// Recalculate prices by currency.
		If Not ClosingResult.RefillPrices
			  AND ClosingResult.RecalculatePrices Then
			DriveClient.RecalculateTabularSectionPricesByCurrency(ThisForm, AdditionalParameters.SettlementsCurrencyBeforeChange, "Inventory");
			FillAmountsDiscounts();
		EndIf;
		
		// Recalculate the amount if VAT taxation flag is changed.
		If ClosingResult.VATTaxation <> ClosingResult.PrevVATTaxation Then
			FillVATRateByVATTaxation();
			FillAmountsDiscounts();
		EndIf;
		
		// Recalculate the amount if the "Amount includes VAT" flag is changed.
		If Not ClosingResult.RefillPrices
			AND Not ClosingResult.AmountIncludesVAT = ClosingResult.PrevAmountIncludesVAT Then
			DriveClient.RecalculateTabularSectionAmountByFlagAmountIncludesVAT(ThisForm, "Inventory");
			FillAmountsDiscounts();
		EndIf;
		
		// DiscountCards
		If ClosingResult.RefillDiscounts AND Not ClosingResult.RefillPrices Then
			DriveClient.RefillDiscountsTablePartAfterDiscountCardRead(ThisForm, "Inventory");
		EndIf;
		// End DiscountCards
		
		// AutomaticDiscounts
		If ClosingResult.RefillDiscounts OR ClosingResult.RefillPrices OR ClosingResult.RecalculatePrices Then
			ClearCheckboxDiscountsAreCalculatedClient("RefillByFormDataPricesAndCurrency");
		EndIf;
	EndIf;
	
	// Generate price and currency label.
	LabelStructure = New Structure;
	LabelStructure.Insert("PriceKind",						Object.PriceKind);
	LabelStructure.Insert("DiscountKind",					Object.DiscountMarkupKind);
	LabelStructure.Insert("DocumentCurrency",				Object.DocumentCurrency);
	LabelStructure.Insert("SettlementsCurrency",			Object.DocumentCurrency);
	LabelStructure.Insert("ExchangeRate",					ExchangeRate);
	LabelStructure.Insert("AmountIncludesVAT",				Object.AmountIncludesVAT);
	LabelStructure.Insert("ForeignExchangeAccounting",	ForeignExchangeAccounting);
	LabelStructure.Insert("RateNationalCurrency",			RateNationalCurrency);
	LabelStructure.Insert("VATTaxation",					Object.VATTaxation);
	LabelStructure.Insert("DiscountCard",					Object.DiscountCard);
	LabelStructure.Insert("DiscountPercentByDiscountCard",	Object.DiscountPercentByDiscountCard);
	
	PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
	
	// Update document footer
	RecalculateDocumentAtClient();
	
EndProcedure

&AtServer
Procedure CompanyOnChangeAtServer()
	
	FillAddedColumns(True);
	FillVATRateByCompanyVATTaxation();
	
EndProcedure

&AtServer
Procedure StructuralUnitOnChangeAtServer()
	
	FillAddedColumns(True);
	FillVATRateByCompanyVATTaxation();
	
EndProcedure

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
	
	StructureData = New Structure("Products, RevenueGLAccount, VATOutputGLAccount, GLAccounts, GLAccountsFilled");
	StructureData.Insert("ObjectParameters", ObjectParameters);
	StructureData.Insert("TabName", "Inventory");
	StructureData.Insert("ProductName", ProductName);
	
	If RowData <> Undefined Then 
		FillPropertyValues(StructureData, RowData);
	EndIf;
	
	Return StructureData;

EndFunction

#EndRegion

#Region ProceduresAndFunctionsForControlOfTheFormAppearance

// Procedure sets mode Only view.
//
Procedure SetModeReadOnly()
	
	ReadOnly = True; // Receipt is issued. Change information is forbidden.
	
	If CashCRUseWithoutEquipmentConnection Then
		Items.IssueReceipt.Title = NStr("en = 'Cancel issuing'");
		Items.IssueReceipt.Enabled = True;
	Else
		Items.IssueReceipt.Enabled = False;
	EndIf;
	
	Items.PricesAndCurrency.Enabled = False;
	Items.InventoryWeight.Enabled = False;
	Items.InventoryPick.Enabled = False;
	Items.PaymentWithPaymentCardsAddPaymentByCard.Enabled = False;
	Items.PaymentWithPaymentCardsDeletePaymentByCard.Enabled = False;
	Items.InventoryImportDataFromDCT.Enabled = False;
	// DiscountCards
	Items.ReadDiscountCard.Enabled = False;
	// AutomaticDiscounts
	Items.InventoryCalculateDiscountsMarkups.Enabled = False;
	
EndProcedure

// The procedure cancels the View only mode.
//
Procedure CancelModeViewOnly()
	
	Items.IssueReceipt.Title = NStr("en = 'Issue cash receipt'");
	ReadOnly = False;
	Items.PricesAndCurrency.Enabled = True;
	Items.InventoryWeight.Enabled = True;
	Items.InventoryPick.Enabled = True;
	Items.PaymentWithPaymentCardsAddPaymentByCard.Enabled = True;
	Items.PaymentWithPaymentCardsDeletePaymentByCard.Enabled = True;
	Items.InventoryImportDataFromDCT.Enabled = True;
	// DiscountCards
	Items.ReadDiscountCard.Enabled = True;
	// AutomaticDiscounts
	Items.InventoryCalculateDiscountsMarkups.Enabled = True;
	
EndProcedure

// Procedure sets the payment availability.
//
&AtServer
Procedure SetPaymentEnabled()
	
	If Object.PaymentForm = Enums.CashAssetTypes.Cash Then
	
		Items.PaymentWithPaymentCards.Enabled = False;
		Items.PagePaymentWithPaymentCards.Visible = False;
		Items.CashReceived.Enabled = ?(
			ControlAtWarehouseDisabled,
			True,
			Object.Status = Enums.SalesSlipStatus.ProductReserved
		);
		Items.CalculateAmountOfCashVoucher.Enabled = ?(
			ControlAtWarehouseDisabled,
			True,
			Object.Status = Enums.SalesSlipStatus.ProductReserved
		);
	
	ElsIf Not ValueIsFilled(Object.PaymentForm) Then // Mixed
	
		Items.PaymentWithPaymentCards.Enabled = ?(
			ControlAtWarehouseDisabled,
			True,
			Object.Status = Enums.SalesSlipStatus.ProductReserved
		);
		Items.PagePaymentWithPaymentCards.Visible = True;
		Items.CashReceived.Enabled = ?(
			ControlAtWarehouseDisabled,
			True,
			Object.Status = Enums.SalesSlipStatus.ProductReserved
		);
		Items.CalculateAmountOfCashVoucher.Enabled = ?(
			ControlAtWarehouseDisabled,
			True,
			Object.Status = Enums.SalesSlipStatus.ProductReserved
		);
	
	Else // By payment cards
		
		Items.PaymentWithPaymentCards.Enabled = ?(
			ControlAtWarehouseDisabled,
			True,
			Object.Status = Enums.SalesSlipStatus.ProductReserved
		);
		Items.PagePaymentWithPaymentCards.Visible = True;
		Items.CashReceived.Enabled = False;
		Items.CalculateAmountOfCashVoucher.Enabled = False;
	
	EndIf;
	
EndProcedure

// Procedure sets the receipt print availability.
//
&AtServer
Procedure SetEnabledOfReceiptPrinting()
	
	If Object.Status = Enums.SalesSlipStatus.ProductReserved
	 OR Object.CashCR.UseWithoutEquipmentConnection
	 OR ControlAtWarehouseDisabled Then
		Items.IssueReceipt.Enabled = True;
	Else
		Items.IssueReceipt.Enabled = False;
	EndIf;
	
EndProcedure

#Region FormEventHandlers

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
	
	If Not ValueIsFilled(Object.Ref) Then
		GetChoiceListOfPaymentCardKinds();
	EndIf;
	
	UsePeripherals = DriveReUse.UsePeripherals();
	If UsePeripherals Then
		GetRefsToEquipment();
	EndIf;
	Items.InventoryImportDataFromDCT.Visible = UsePeripherals;
	
	ControlAtWarehouseDisabled = Not Constants.CheckStockBalanceOnPosting.Get()
						   OR Not Constants.CheckStockBalanceWhenIssuingSalesSlips.Get();
	Items.Reserve.Visible = Not ControlAtWarehouseDisabled;
	Items.RemoveReservation.Visible = Not ControlAtWarehouseDisabled;
	
	ShiftClosureIsOpen = (CommonUse.ObjectAttributeValue(Object.CashCRSession, "CashCRSessionStatus")
							= PredefinedValue("Enum.ShiftClosureStatus.IsOpen"));
	Items.FormDocumentProductReturnCreateBasedOn.Visible = ShiftClosureIsOpen;
	Items.FormDocumentCreditNoteCreateBasedOn.Visible = Not ShiftClosureIsOpen;
	
	StructureByCurrency = InformationRegisters.ExchangeRates.GetLast(Object.Date, New Structure("Currency", Object.DocumentCurrency));
	ExchangeRate = ?(
		StructureByCurrency.ExchangeRate = 0,
		1,
		StructureByCurrency.ExchangeRate);
	Multiplicity = ?(
		StructureByCurrency.ExchangeRate = 0,
		1,
		StructureByCurrency.Multiplicity);
	
	StructureByCurrency = InformationRegisters.ExchangeRates.GetLast(Object.Date, New Structure("Currency", Constants.FunctionalCurrency.Get()));
	RateNationalCurrency = StructureByCurrency.ExchangeRate;
	RepetitionNationalCurrency = StructureByCurrency.Multiplicity;
	
	If Not ValueIsFilled(Object.Ref)
		AND Not ValueIsFilled(Parameters.CopyingValue) Then
		FillVATRateByCompanyVATTaxation();
	ElsIf Object.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then	
		Items.InventoryVATRate.Visible = True;
		Items.InventoryVATAmount.Visible = True;
		Items.InventoryAmountTotal.Visible = True;
		Items.InventoryTotalAmountOfVAT.Visible = True;
	Else
		Items.InventoryVATRate.Visible = False;
		Items.InventoryVATAmount.Visible = False;
		Items.InventoryAmountTotal.Visible = False;
		Items.InventoryTotalAmountOfVAT.Visible = False;
	EndIf;
	
	ForeignExchangeAccounting = Constants.ForeignExchangeAccounting.Get();
	
	LabelStructure = New Structure;
	LabelStructure.Insert("PriceKind",						Object.PriceKind);
	LabelStructure.Insert("DiscountKind",					Object.DiscountMarkupKind);
	LabelStructure.Insert("DocumentCurrency",				Object.DocumentCurrency);
	LabelStructure.Insert("SettlementsCurrency",			Object.DocumentCurrency);
	LabelStructure.Insert("ExchangeRate",					ExchangeRate);
	LabelStructure.Insert("AmountIncludesVAT",				Object.AmountIncludesVAT);
	LabelStructure.Insert("ForeignExchangeAccounting",	ForeignExchangeAccounting);
	LabelStructure.Insert("RateNationalCurrency",			RateNationalCurrency);
	LabelStructure.Insert("VATTaxation",					Object.VATTaxation);
	LabelStructure.Insert("DiscountCard",					Object.DiscountCard);
	LabelStructure.Insert("DiscountPercentByDiscountCard",	Object.DiscountPercentByDiscountCard);
	
	PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
	
	FillAddedColumns();
	
	CashCRUseWithoutEquipmentConnection = Object.CashCR.UseWithoutEquipmentConnection;
	
	SetEnabledOfReceiptPrinting();
	Items.PaymentWithPaymentCards.Enabled = ValueIsFilled(Object.POSTerminal);
	
	If Object.Status = Enums.SalesSlipStatus.Issued Then
		SetModeReadOnly();
	EndIf;
	
	SetPaymentEnabled();
	
	Items.InventoryAmountDiscountsMarkups.Visible = Constants.UseManualDiscounts.Get();
	
	// Price accessibility setup for editing.
	AllowedEditDocumentPrices = DriveAccessManagementReUse.AllowedEditDocumentPrices();
	SaleFromWarehouse = Object.StructuralUnit.StructuralUnitType = Enums.BusinessUnitsTypes.Warehouse;
	
	Items.InventoryPrice.ReadOnly 					= Not AllowedEditDocumentPrices OR Not SaleFromWarehouse;
	Items.InventoryAmount.ReadOnly 				= Not AllowedEditDocumentPrices OR Not SaleFromWarehouse; 
	Items.InventoryDiscountPercentMargin.ReadOnly  = Not AllowedEditDocumentPrices;
	Items.InventoryAmountDiscountsMarkups.ReadOnly 	= Not AllowedEditDocumentPrices;
	Items.InventoryVATAmount.ReadOnly 				= Not AllowedEditDocumentPrices OR Not SaleFromWarehouse;
	
	TitleAmountCheque = NStr("en = 'Receipt amount ('") + "%Currency%" + ")";
	TitleAmountCheque = StrReplace(TitleAmountCheque, "%Currency%", Object.DocumentCurrency);
	Items.DocumentAmount.ToolTip = TitleAmountCheque;
	
	TitleReceivedCash = NStr("en = 'Received in cash ('") + "%Currency%" + ")";
	TitleReceivedCash = StrReplace(TitleReceivedCash, "%Currency%", Object.DocumentCurrency);
	Items.CashReceived.ToolTip = TitleReceivedCash;
	
	TitlePaymentWithPaymentCards = NStr("en = 'By payment cards ('") + "%Currency%" + ")";
	TitlePaymentWithPaymentCards = StrReplace(TitlePaymentWithPaymentCards, "%Currency%", Object.DocumentCurrency);
	Items.PaymentWithPaymentCardsTotalAmount.ToolTip = TitlePaymentWithPaymentCards;
	
	TitleAmountPutting = NStr("en = 'Change ('") + "%Currency%" + ")";
	TitleAmountPutting = StrReplace(TitleAmountPutting, "%Currency%", Object.DocumentCurrency);
	Items.AmountShortChange.ToolTip = TitleAmountPutting;

	// StructuralUnit - blank can't be
	StructuralUnitType = Object.StructuralUnit.StructuralUnitType;
	
	// AutomaticDiscounts.
	AutomaticDiscountsOnCreateAtServer();
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisForm, Items.ImportantCommandsGroup);
	// End StandardSubsystems.Printing
	
	// Serial numbers
	UseSerialNumbersBalance = WorkWithSerialNumbers.UseSerialNumbersBalance();
	
EndProcedure

// Procedure - OnReadAtServer event handler.
//
&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	FillAddedColumns();
	ClosingDates.ObjectOnReadAtServer(ThisForm, CurrentObject);
	
	GetChoiceListOfPaymentCardKinds();
	
	Items.IssueReceipt.Enabled = Not Object.DeletionMark;
	
EndProcedure

// Procedure - OnOpen form event handler
//
&AtClient
Procedure OnOpen(Cancel)
	
	// Peripherals
	EquipmentManagerClientOverridable.StartConnectingEquipmentOnFormOpen(ThisForm, "BarcodeScanner,CustomerDisplay");
	// End Peripherals
	
	FillAmountsDiscounts();
	
	RecalculateDocumentAtClient();
	
EndProcedure

// Procedure - event handler BeforeWriteAtServer form.
//
&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	If WriteParameters.WriteMode = DocumentWriteMode.Posting Then
		If ValueIsFilled(Object.Ref) Then
			UsePostingMode = PostingModeUse.Regular;
		EndIf;
	EndIf;
	
EndProcedure

// Procedure - event handler OnClose form.
//
&AtClient
Procedure OnClose(Exit)
	
	// AutomaticDiscounts
	// Display the message about discount calculation when user clicks the "Post and close" button or closes the form by
	// the cross with saving the changes.
	If UseAutomaticDiscounts AND DiscountsCalculatedBeforeWrite Then
		ShowUserNotification(NStr("en = 'Update:'"), 
										GetURL(Object.Ref), 
										String(Object.Ref) + NStr("en = '. The automatic discounts are calculated.'"), 
										PictureLib.Information32);
	EndIf;
	// End AutomaticDiscounts
	
	// Peripherals
	EquipmentManagerClientOverridable.StartDisablingEquipmentOnCloseForm(ThisForm);
	// End Peripherals

EndProcedure

// BeforeRecord event handler procedure.
//
&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	// AutomaticDiscounts
	DiscountsCalculatedBeforeWrite = False;
	// If the document is being posted, we check whether the discounts are calculated.
	If UseAutomaticDiscounts Then
		If Not Object.DiscountsAreCalculated AND DiscountsChanged() Then
			CalculateDiscountsMarkupsClient();
			CalculatedDiscounts = True;
			
			Message = New UserMessage;
			Message.Text = NStr("en = 'The automatic discounts are applied.'");
			Message.DataKey = Object.Ref;
			Message.Message();
			
			DiscountsCalculatedBeforeWrite = True;
		Else
			Object.DiscountsAreCalculated = True;
			RefreshImageAutoDiscountsAfterWrite = True;
		EndIf;
	EndIf;
	// End AutomaticDiscounts
	
EndProcedure

// Procedure - event handler AfterWrite form.
//
&AtClient
Procedure AfterWrite(WriteParameters)
	
	// AutomaticDiscounts
	If DiscountsCalculatedBeforeWrite Then
		RecalculateDocumentAtClient();
	EndIf;
	// End AutomaticDiscounts
	
	Notify("RefreshSalesSlipDocumentsListForm");
	
EndProcedure

// Procedure - event handler of the form NotificationProcessing.
//
&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	// Peripherals
	If Source = "Peripherals"
		AND IsInputAvailable() AND Not DiscountCardRead Then
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
	
	// DiscountCards
	If DiscountCardRead Then
		DiscountCardRead = False;
	EndIf;
	// End DiscountCards
	
	If EventName = "RefreshSalesSlipDocumentsListForm" Then
		
		For Each CurRow In Object.Inventory Do
			
			CurRow.DiscountAmount = CurRow.Price * CurRow.Quantity - CurRow.Amount;
			
		EndDo;
		
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

#EndRegion

#Region ProcedureActionsOfTheFormCommandPanels

// Procedure displays information output on the customer display.
//
// Parameters:
//  No.
//
&AtClient
Procedure DisplayInformationOnCustomerDisplay()

	Displays = EquipmentManagerClientReUse.GetEquipmentList("CustomerDisplay", , EquipmentManagerServerCall.GetClientWorkplace());
	display = Undefined;
	DPText = ?(
		Items.Inventory.CurrentData = Undefined,
		"",
		TrimAll(Items.Inventory.CurrentData.Products)
	  + Chars.LF
	  + NStr("en = 'Total'") + ": " +
	  + Format(Object.DocumentAmount, "NFD=2; NGS=' '; NZ=0")
	);

	For Each display In Displays Do
		
		// Data preparation
		InputParameters  = New Array();
		Output_Parameters = Undefined;
		
		InputParameters.Add(DPText);
		InputParameters.Add(0);
		
		Result = EquipmentManagerClient.RunCommand(
			display.Ref,
			"DisplayText",
			InputParameters,
				Output_Parameters
		);
		
		If Not Result Then
			MessageText = NStr("en = 'When using customer display error occurred.
			                   |Additional
			                   |description: %AdditionalDetails%'");
			MessageText = StrReplace(MessageText,"%AdditionalDetails%",Output_Parameters[1]);
			CommonUseClientServer.MessageToUser(MessageText);
		EndIf;
		
	EndDo;
	
EndProcedure

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
			CalculateAmountInTabularSectionLine();
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

// The procedure of cancelling receipt issuing if equipment is not connected.
//
&AtClient
Procedure CancelBreakoutCheque()
	
	PostingResult = Write(New Structure("WriteMode", DocumentWriteMode.UndoPosting));
	If PostingResult = True Then
		CancelModeViewOnly();
	EndIf;
	
EndProcedure

// Receipt print procedure on fiscal register.
//
&AtClient
Procedure IssueReceipt()
	
	ErrorDescription = "";
	
	If Object.SalesSlipNumber <> 0
	AND Not CashCRUseWithoutEquipmentConnection Then
		
		MessageText = NStr("en = 'Receipt has already been issued on the fiscal data recorder.'");
		CommonUseClientServer.MessageToUser(MessageText);
		Return;
		
	EndIf;
	
	ShowMessageBox = False;
	If (ControlAtWarehouseDisabled OR DriveClient.CheckPossibilityOfReceiptPrinting(ThisForm, ShowMessageBox)) Then
		
		If UsePeripherals // Check for the included FO "Use Peripherals"
		AND Not CashCRUseWithoutEquipmentConnection Then 
			
			If EquipmentManagerClient.RefreshClientWorkplace() Then // Check on the certainty of Peripheral workplace
				
				DeviceIdentifier = ?(
					ValueIsFilled(FiscalRegister),
					FiscalRegister,
					Undefined
				);
				
				If DeviceIdentifier <> Undefined Then
					
					// Connect FR
					Result = EquipmentManagerClient.ConnectEquipmentByID(
						UUID,
						DeviceIdentifier,
						ErrorDescription
					);
						
					If Result Then
						
						// Prepare data
						InputParameters  = New Array;
						Output_Parameters = Undefined;
						
						SectionNumber = 1;
						
						// Preparation of the product table
						ProductsTable = New Array();
						
						For Each TSRow In Object.Inventory Do
							
							VATRate = DriveReUse.GetVATRateValue(TSRow.VATRate);
							
							ProductsTableRow = New ValueList();
							ProductsTableRow.Add(String(TSRow.Products));
																				  //  1 - Description
							ProductsTableRow.Add("");                    //  2 - Barcode
							ProductsTableRow.Add("");                    //  3 - SKU
							ProductsTableRow.Add(SectionNumber);           //  4 - Department number
							ProductsTableRow.Add(TSRow.Price);         //  5 - Price for position without discount
							ProductsTableRow.Add(TSRow.Quantity);   //  6 - Quantity
							ProductsTableRow.Add("");                    //  7 - Discount description
							ProductsTableRow.Add(0);                     //  8 - Discount amount
							ProductsTableRow.Add(0);                     //  9 - Discount percentage
							ProductsTableRow.Add(TSRow.Amount);        // 10 - Position amount with discount
							ProductsTableRow.Add(0);                     // 11 - Tax number (1)
							ProductsTableRow.Add(TSRow.VATAmount);     // 12 - Tax amount (1)
							ProductsTableRow.Add(VATRate);             // 13 - Tax percent (1)
							ProductsTableRow.Add(0);                     // 14 - Tax number (2)
							ProductsTableRow.Add(0);                     // 15 - Tax amount (2)
							ProductsTableRow.Add(0);                     // 16 - Tax percent (2)
							ProductsTableRow.Add("");                    // 17 - Section name of commodity string formatting
							
							ProductsTable.Add(ProductsTableRow);
							
						EndDo;
						
						// Preparation of the payment table
						PaymentsTable = New Array();
						
						// Cash
						PaymentRow = New ValueList();
						PaymentRow.Add(0);
						PaymentRow.Add(Object.CashReceived);
						PaymentRow.Add("Payment by cash");
						PaymentRow.Add("");
						PaymentsTable.Add(PaymentRow);
						
						// Noncash
						PaymentRow = New ValueList();
						PaymentRow.Add(1);
						PaymentRow.Add(Object.PaymentWithPaymentCards.Total("Amount"));
						PaymentRow.Add("Group Cashless payment");
						PaymentRow.Add("");
						PaymentsTable.Add(PaymentRow);
						
						// Preparation of the common parameters table
						CommonParameters = New Array();
						CommonParameters.Add(0);                      //  1 - Receipt type
						CommonParameters.Add(True);                 //  2 - Fiscal receipt sign
						CommonParameters.Add(Undefined);           //  3 - Print on lining document
						CommonParameters.Add(Object.DocumentAmount);  //  4 - the receipt amount without discounts
						CommonParameters.Add(Object.DocumentAmount);  //  5 - the receipt amount after applying all discounts
						CommonParameters.Add("");                     //  6 - Discount card number
						CommonParameters.Add("");                     //  7 - Header text
						CommonParameters.Add("");                     //  8 - Footer text
						CommonParameters.Add(0);                      //  9 - Session number (for receipt copy)
						CommonParameters.Add(0);                      // 10 - Receipt number (for receipt copy)
						CommonParameters.Add(0);                      // 11 - Document No (for receipt copy)
						CommonParameters.Add(0);                      // 12 - Document date (for receipt copy)
						CommonParameters.Add("");                     // 13 - Cashier name (for receipt copy)
						CommonParameters.Add("");                     // 14 - Cashier password
						CommonParameters.Add(0);                      // 15 - Template number
						CommonParameters.Add("");                     // 16 - Section name header format
						CommonParameters.Add("");                     // 17 - Section name cellar format
						
						InputParameters.Add(ProductsTable);
						InputParameters.Add(PaymentsTable);
						InputParameters.Add(CommonParameters);
						
						// Print receipt.
						Result = EquipmentManagerClient.RunCommand(
							DeviceIdentifier,
							"PrintReceipt",
							InputParameters,
							Output_Parameters
						);
						
						If Result Then
							
							// Set the received value of receipt number to document attribute.
							Object.SalesSlipNumber = Output_Parameters[1];
							Object.Status = PredefinedValue("Enum.SalesSlipStatus.Issued");
							Object.Date = CurrentDate();
							
							If Not ValueIsFilled(Object.SalesSlipNumber) Then
								Object.SalesSlipNumber = 1;
							EndIf;
							
							Modified = True;
							
							PostingResult = Write(New Structure("WriteMode", DocumentWriteMode.Posting));
							
							If PostingResult = True Then
								SetModeReadOnly();
							EndIf;
							
						Else
							
							MessageText = NStr("en = 'When printing a receipt, an error occurred.
							                   |Receipt is not printed on the fiscal register.
							                   |Additional
							                   |description: %AdditionalDetails%'");
							MessageText = StrReplace(MessageText,"%AdditionalDetails%",Output_Parameters[1]);
							CommonUseClientServer.MessageToUser(MessageText);
							
						EndIf;
						
						// Disconnect FR
						EquipmentManagerClient.DisableEquipmentById(UUID, DeviceIdentifier);
						
					Else
						
						MessageText = NStr("en = 'An error occurred when connecting the device.
						                   |Receipt is not printed on the fiscal register.
						                   |Additional
						                   |description: %AdditionalDetails%'");
						MessageText = StrReplace(MessageText, "%AdditionalDetails%", ErrorDescription);
						CommonUseClientServer.MessageToUser(MessageText);
						
					EndIf;
					
				Else
					
					MessageText = NStr("en = 'Fiscal data recorder is not selected'");
					CommonUseClientServer.MessageToUser(MessageText);
					
				EndIf;
				
			Else
				
				MessageText = NStr("en = 'First, you need to select the work place of the current session peripherals.'");
				CommonUseClientServer.MessageToUser(MessageText);
				
			EndIf;
			
		Else
			
			// External equipment is not used
			Object.Status = PredefinedValue("Enum.SalesSlipStatus.Issued");
			Object.Date = CurrentDate();
			
			If Not ValueIsFilled(Object.SalesSlipNumber) Then
				Object.SalesSlipNumber = 1;
			EndIf;
			
			Modified = True;
			
			PostingResult = Write(New Structure("WriteMode", DocumentWriteMode.Posting));
			
			If PostingResult = True Then
				SetModeReadOnly();
			EndIf;
			
		EndIf;
		
	ElsIf ShowMessageBox Then
		ShowMessageBox(Undefined,NStr("en = 'Failed to post document'"));
	EndIf;
	
EndProcedure

// Procedure is called when pressing the PrintReceipt command panel button.
//
&AtClient
Procedure IssueReceiptExecute(Command)
	
	// StandardSubsystems.PerformanceMeasurement
	PerformanceEstimationClientServer.StartTimeMeasurement("DocumentSalesSlipPosting");
	// StandardSubsystems.PerformanceMeasurement
	
	Cancel = False;
	
	ClearMessages();
	
	If Object.DeletionMark Then
		
		ErrorText = NStr("en = 'The document is marked for deletion'");
		
		Message = New UserMessage;
		Message.Text = ErrorText;
		Message.Message();
		
		Cancel = True;
		
	EndIf;
	
	CheckPaymentAmounts(Cancel);
	
	If Cancel Then
		Return;
	EndIf;
	
	If ReadOnly Then
		CancelBreakoutCheque();
		SetPaymentEnabled();
	ElsIf CheckFilling() Then
		Object.Date = CurrentDate();
		IssueReceipt();
	EndIf;
	
EndProcedure

// Procedure - AddPaymentByCard command handler.
//
&AtClient
Procedure AddPaymentByCard(Command)
	
	DeviceIdentifierET = Undefined;
	DeviceIdentifierFR = Undefined;
	ErrorDescription            = "";
	
	AmountOfOperations       = 0;
	CardNumber          = "";
	OperationRefNumber = "";
	ETReceiptNo         = "";
	SlipCheckString      = "";
	CardKind            = "";
	
	ShowMessageBox = False;
	If DriveClient.CheckPossibilityOfReceiptPrinting(ThisForm, ShowMessageBox) Then
		
		If UsePeripherals Then // Check on the included FO "Use ExternalEquipment"
			
			If EquipmentManagerClient.RefreshClientWorkplace()Then // Checks if the operator's workplace is specified
				
				// Device selection ET
				DeviceIdentifierET = ?(ValueIsFilled(POSTerminal),
											  POSTerminal,
											  Undefined);
				
				If DeviceIdentifierET <> Undefined Then
					
					// Device selection FR
					DeviceIdentifierFR = ?(ValueIsFilled(FiscalRegister),
												  FiscalRegister,
												  Undefined);
					
					If DeviceIdentifierFR <> Undefined
					 OR CashCRUseWithoutEquipmentConnection Then
						
						// ET device connection
						ResultET = EquipmentManagerClient.ConnectEquipmentByID(UUID,
																										DeviceIdentifierET,
																										ErrorDescription);
						
						If ResultET Then
							
							// FR device connection
							ResultFR = EquipmentManagerClient.ConnectEquipmentByID(UUID,
																											DeviceIdentifierFR,
																											ErrorDescription);
							
							If ResultFR OR CashCRUseWithoutEquipmentConnection Then
								
								// we will authorize operation previously
								FormParameters = New Structure();
								FormParameters.Insert("Amount", Object.DocumentAmount - Object.CashReceived - Object.PaymentWithPaymentCards.Total("Amount"));
								FormParameters.Insert("LimitAmount", Object.DocumentAmount - Object.PaymentWithPaymentCards.Total("Amount"));
								FormParameters.Insert("ListOfCardTypes", New ValueList());
								IndexOf = 0;
								For Each CardKind In Items.PaymentByChargeCardTypeCards.ChoiceList Do
									FormParameters.ListOfCardTypes.Add(IndexOf, CardKind.Value);
									IndexOf = IndexOf + 1;
								EndDo;
								
								Result = Undefined;

								
								OpenForm("Catalog.Peripherals.Form.POSTerminalAuthorizationForm", FormParameters,,,,, New NotifyDescription("AddPaymentByCardEnd", ThisObject, New Structure("FRDeviceIdentifier, ETDeviceIdentifier, CardNumber", DeviceIdentifierFR, DeviceIdentifierET, CardNumber)));
							Else
								MessageText = NStr("en = 'An error occurred while connecting
								                   |the fiscal register: ""%ErrorDescription%"".
								                   |Operation by card has not been performed.'");
								MessageText = StrReplace(MessageText, "%ErrorDescription%", ErrorDescription);
								CommonUseClientServer.MessageToUser(MessageText);
							EndIf;
							
						Else
							
							MessageText = NStr("en = 'When POS terminal connection there
							                   |was error: ""%ErrorDescription%"".
							                   |Operation by card has not been performed.'");
								MessageText = StrReplace(MessageText, "%ErrorDescription%", ErrorDescription);
							CommonUseClientServer.MessageToUser(MessageText);
							
						EndIf;
						
					EndIf;
					
				EndIf;
				
			Else
				
				MessageText = NStr("en = 'First, you need to select the work place of the current session peripherals.'");
				CommonUseClientServer.MessageToUser(MessageText);
				
			EndIf;
			
		Else
			
			// External equipment is not used
			
		EndIf;
		
	ElsIf ShowMessageBox Then
		ShowMessageBox(Undefined,NStr("en = 'Failed to post document'"));
	EndIf;
	
EndProcedure

&AtClient
Procedure AddPaymentByCardEnd(Result1, AdditionalParameters) Export
    
    DeviceIdentifierFR = AdditionalParameters.DeviceIdentifierFR;
    DeviceIdentifierET = AdditionalParameters.DeviceIdentifierET;
    CardNumber = AdditionalParameters.CardNumber;
    
    
    // we will authorize operation previously
    Result = Result1;
    
    If TypeOf(Result) = Type("Structure") Then
        
        InputParameters  = New Array();
        Output_Parameters = Undefined;
        
        InputParameters.Add(Result.Amount);
        InputParameters.Add(Result.CardNumber);
        
        AmountOfOperations       = Result.Amount;
        CardNumber          = Result.CardNumber;
        OperationRefNumber = Result.RefNo;
        ETReceiptNo         = Result.ReceiptNumber;
        CardKind      = Items.PaymentByChargeCardTypeCards.ChoiceList[Result.CardType].Value;
        
        // Executing the operation on POS terminal
        ResultET = EquipmentManagerClient.RunCommand(DeviceIdentifierET,
        "AuthorizeSales",
        InputParameters,
        Output_Parameters);
        
        If ResultET Then
            
            CardNumber          = ?(NOT IsBlankString(CardNumber)
            AND IsBlankString(StrReplace(TrimAll(Output_Parameters[0]), "*", "")),
            CardNumber, Output_Parameters[0]);
            OperationRefNumber = Output_Parameters[1];
            ETReceiptNo         = Output_Parameters[2];
            SlipCheckString      = Output_Parameters[3][1];
            
            If Not IsBlankString(SlipCheckString) Then
                glPeripherals.Insert("LastSlipReceipt", SlipCheckString);
            EndIf;
            
            If Not IsBlankString(SlipCheckString) AND Not CashCRUseWithoutEquipmentConnection Then
                InputParameters  = New Array();
                InputParameters.Add(SlipCheckString);
                Output_Parameters = Undefined;
                
                ResultFR = EquipmentManagerClient.RunCommand(DeviceIdentifierFR,
                "PrintText",
                InputParameters,
                Output_Parameters);
			Else
				ResultFR = True;
            EndIf;
            
        Else
            
            MessageText = NStr("en = 'When operation execution there
                               |was error: ""%ErrorDescription%"".
                               |Payment by card has not been performed.'"
            );
            MessageText = StrReplace(MessageText,"%ErrorDescription%",Output_Parameters[1]);
            CommonUseClientServer.MessageToUser(MessageText);
            
        EndIf;
        
        If ResultET AND (NOT ResultFR AND Not CashCRUseWithoutEquipmentConnection) Then
            
            ErrorDescriptionFR = Output_Parameters[1];
            
            InputParameters  = New Array();
            Output_Parameters = Undefined;
            
            InputParameters.Add(AmountOfOperations);
            InputParameters.Add(OperationRefNumber);
            InputParameters.Add(ETReceiptNo);
            
            // Executing the operation on POS terminal
            EquipmentManagerClient.RunCommand(DeviceIdentifierET,
            "EmergencyVoid",
            InputParameters,
            Output_Parameters);
            
            MessageText = NStr("en = 'When printing slip receipt
                               |there was error: ""%ErrorDescription%"".
                               |Operation by card has been cancelled.'"
            );
            MessageText = StrReplace(MessageText,"%ErrorDescription%",ErrorDescriptionFR);
            CommonUseClientServer.MessageToUser(MessageText);
            
        ElsIf ResultET Then
            
            // Save the data of payment by card to the table
            PaymentRowByCard = Object.PaymentWithPaymentCards.Add();
            
            PaymentRowByCard.ChargeCardKind   = CardKind;
            PaymentRowByCard.ChargeCardNo = CardNumber; // ItIsPossible record empty Numbers maps or Numbers type "****************"
            PaymentRowByCard.Amount               = AmountOfOperations;
            PaymentRowByCard.RefNo      = OperationRefNumber;
            PaymentRowByCard.ETReceiptNo         = ETReceiptNo;
            
            RecalculateDocumentAtClient();
            
            Write(); // It is required to write document to prevent information loss.
            
        EndIf;
    EndIf;
    
    // FR device disconnect
    EquipmentManagerClient.DisableEquipmentById(UUID,
    DeviceIdentifierFR);
    // ET device disconnect
    EquipmentManagerClient.DisableEquipmentById(UUID,
    DeviceIdentifierET);

EndProcedure

// Procedure - DeletePaymentByCard command handler.
//
&AtClient
Procedure DeletePaymentByCard(Command)
	
	DeviceIdentifierET = Undefined;
	DeviceIdentifierFR = Undefined;
	ErrorDescription            = "";
	
	// Check selected string in payment table by payment cards
	CurrentData = Items.PaymentWithPaymentCards.CurrentData;
	If CurrentData = Undefined Then
		CommonUseClientServer.MessageToUser(NStr("en = 'Select a row of deleted payment by card'"));
		Return;
	EndIf;
	
	ShowMessageBox = False;
	If DriveClient.CheckPossibilityOfReceiptPrinting(ThisForm, ShowMessageBox) Then
		
		If UsePeripherals Then // Check on the included FO "Use ExternalEquipment"
			If EquipmentManagerClient.RefreshClientWorkplace()Then // Checks if the operator's workplace is specified
				AmountOfOperations       = CurrentData.Amount;
				CardNumber          = CurrentData.ChargeCardNo;
				OperationRefNumber = CurrentData.RefNo;
				ETReceiptNo         = CurrentData.ETReceiptNo;
				SlipCheckString      = "";
				
				// Device selection ET
				DeviceIdentifierET = ?(ValueIsFilled(POSTerminal),
											  POSTerminal,
											  Undefined);
				
				If DeviceIdentifierET <> Undefined Then
					// Device selection FR
					DeviceIdentifierFR = ?(ValueIsFilled(FiscalRegister),
												  FiscalRegister,
												  Undefined);
					
					If DeviceIdentifierFR <> Undefined OR CashCRUseWithoutEquipmentConnection Then
						// ET device connection
						ResultET = EquipmentManagerClient.ConnectEquipmentByID(UUID,
																										DeviceIdentifierET,
																										ErrorDescription);
						
						If ResultET Then
							// FR device connection
							ResultFR = EquipmentManagerClient.ConnectEquipmentByID(UUID,
																											DeviceIdentifierFR,
																											ErrorDescription);
							
							If ResultFR OR CashCRUseWithoutEquipmentConnection Then
								
								InputParameters  = New Array();
								Output_Parameters = Undefined;
								
								InputParameters.Add(AmountOfOperations);
								InputParameters.Add(OperationRefNumber);
								InputParameters.Add(ETReceiptNo);
								
								// Executing the operation on POS terminal
								ResultET = EquipmentManagerClient.RunCommand(DeviceIdentifierET,
																						  "AuthorizeVoid",
																						  InputParameters,
																						  Output_Parameters);
								
								If ResultET Then
									
									CardNumber          = "";
									OperationRefNumber = "";
									ETReceiptNo         = "";
									SlipCheckString      = Output_Parameters[0][1];
									
									If Not IsBlankString(SlipCheckString) Then
										glPeripherals.Insert("LastSlipReceipt", SlipCheckString);
									EndIf;
									
									If Not IsBlankString(SlipCheckString) AND Not CashCRUseWithoutEquipmentConnection Then
										InputParameters  = New Array();
										InputParameters.Add(SlipCheckString);
										Output_Parameters = Undefined;
										
										ResultFR = EquipmentManagerClient.RunCommand(DeviceIdentifierFR,
																								  "PrintText",
																								  InputParameters,
																								  Output_Parameters);
									EndIf;
									
								Else
									
									MessageText = NStr("en = 'When operation execution there
									                   |was error: ""%ErrorDescription%"".
									                   |Cancellation by card has not been performed.'");
									MessageText = StrReplace(MessageText,"%ErrorDescription%",Output_Parameters[1]);
									CommonUseClientServer.MessageToUser(MessageText);
									
								EndIf;
								
								If ResultET AND (NOT ResultFR AND Not CashCRUseWithoutEquipmentConnection) Then
									
									ErrorDescriptionFR = Output_Parameters[1];
									
									MessageText = NStr("en = 'When printing slip receipt
									                   |there was error: ""%ErrorDescription%"".
									                   |Operation by card has been cancelled.'");
									MessageText = StrReplace(MessageText,"%ErrorDescription%",ErrorDescriptionFR);
									CommonUseClientServer.MessageToUser(MessageText);
								
								ElsIf ResultET Then
									
									Object.PaymentWithPaymentCards.Delete(CurrentData);
									
									RecalculateDocumentAtClient();
									
									Write();
									
								EndIf;
								
								// FR device disconnect
								EquipmentManagerClient.DisableEquipmentById(UUID,
																								 DeviceIdentifierFR);
								// ET device disconnect
								EquipmentManagerClient.DisableEquipmentById(UUID,
																								 DeviceIdentifierET);
							Else
								MessageText = NStr("en = 'An error occurred while connecting
								                   |the fiscal register: ""%ErrorDescription%"".
								                   |Operation by card has not been performed.'");
								MessageText = StrReplace(MessageText, "%ErrorDescription%", ErrorDescription);
								CommonUseClientServer.MessageToUser(MessageText);
							EndIf;
						Else
							MessageText = NStr("en = 'When POS terminal connection there
							                   |was error: ""%ErrorDescription%"".
							                   |Operation by card has not been performed.'");
								MessageText = StrReplace(MessageText, "%ErrorDescription%", ErrorDescription);
							CommonUseClientServer.MessageToUser(MessageText);
						EndIf;
					EndIf;
				EndIf;
			Else
				MessageText = NStr("en = 'First, you need to select the work place of the current session peripherals.'");
				
				CommonUseClientServer.MessageToUser(MessageText);
			EndIf;
		EndIf;
		
	ElsIf ShowMessageBox Then
		ShowMessageBox(Undefined,NStr("en = 'Failed to post document'"));
	EndIf;
	
EndProcedure

// Procedure - PrintLastSlipCheck command handler.
//
&AtClient
Procedure PrintLastSlipReceipt(Command)
	
	If UsePeripherals Then // Check on the included FO "Use ExternalEquipment"
		If EquipmentManagerClient.RefreshClientWorkplace()Then // Checks if the operator's workplace is specified
			DeviceIdentifierFR = Undefined;
			ErrorDescription            = "";
			
			SlipCheckString = "";
			If Not glPeripherals.Property("LastSlipReceipt", SlipCheckString)
			 Or TypeOf(SlipCheckString) <> Type("String")
			 Or IsBlankString(SlipCheckString) Then
				CommonUseClientServer.MessageToUser(NStr("en = 'Slip check is absent.
				                                         |Acquiring operation may not have been executed for this session.'"));
				Return;
			EndIf;
			
			// Device selection FR
			DeviceIdentifierFR = ?(ValueIsFilled(FiscalRegister),
										  FiscalRegister,
										  Undefined);
			
			If DeviceIdentifierFR <> Undefined Then
				// FR device connection
				ResultFR = EquipmentManagerClient.ConnectEquipmentByID(UUID,
																								DeviceIdentifierFR,
																								ErrorDescription);
				
				If ResultFR Then
					
					InputParameters  = New Array();
					InputParameters.Add(SlipCheckString);
					Output_Parameters = Undefined;
					
					ResultFR = EquipmentManagerClient.RunCommand(DeviceIdentifierFR,
																			  "PrintText",
																			  InputParameters,
																			  Output_Parameters);
					If Not ResultFR Then
						MessageText = NStr("en = 'When printing slip receipt
						                   |there was error: ""%ErrorDescription%"".'");
						MessageText = StrReplace(MessageText,
													 "%ErrorDescription%",
													 Output_Parameters[1]);
						CommonUseClientServer.MessageToUser(MessageText);
					EndIf;
					
					// FR device disconnect
					EquipmentManagerClient.DisableEquipmentById(UUID,
																					 DeviceIdentifierFR);
				Else
					MessageText = NStr("en = 'An error occurred while connecting the fiscal register: ""%ErrorDescription%"".'");
					MessageText = StrReplace(MessageText, "%ErrorDescription%", ErrorDescription);
					CommonUseClientServer.MessageToUser(MessageText);
				EndIf;
			EndIf;
		Else
			MessageText = NStr("en = 'First, you need to select the work place of the current session peripherals.'");
			
			CommonUseClientServer.MessageToUser(MessageText);
		EndIf;
	EndIf;
	
EndProcedure

// Procedure - command handler Reserve on server.
&AtServer
Procedure ReserveAtServer(CancelReservation = False)
	
	OldStatus = Object.Status;
	
	If CancelReservation Then
		Object.Status = Undefined;
		WriteMode = DocumentWriteMode.UndoPosting;
	Else
		Object.Status = Enums.SalesSlipStatus.ProductReserved;
		WriteMode= DocumentWriteMode.Posting;
	EndIf;
	
	Try
		If Not Write(New Structure("WriteMode", WriteMode)) Then
			Object.Status = OldStatus;
		EndIf;
	Except
		Object.Status = OldStatus;
	EndTry;
	
	SetEnabledOfReceiptPrinting();
	SetPaymentEnabled();
	
EndProcedure

// Procedure - The Reserve command handler.
//
&AtClient
Procedure Reserve(Command)
	
	ReserveAtServer();
	
	Notify("RefreshSalesSlipDocumentsListForm");
	
EndProcedure

// Procedure - command handler RemoveReservation.
//
&AtClient
Procedure RemoveReservation(Command)
	
	ReserveAtServer(True);
	
	Notify("RefreshSalesSlipDocumentsListForm");
	
EndProcedure

// Procedure - event handler Action of the Pick command
//
&AtClient
Procedure Pick(Command)
	
	TabularSectionName	= "Inventory";
	DocumentPresentaion	= NStr("en = 'sales slip'");
	SelectionParameters	= DriveClient.GetSelectionParameters(ThisObject, TabularSectionName, DocumentPresentaion, True, True, True);
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

// Procedure calculates the amount of payment in cash.
//
&AtClient
Procedure CalculateAmountOfCashVoucher(Command)
	
	PaymentTotalPaymentCards = Object.PaymentWithPaymentCards.Total("Amount");
	Object.CashReceived = Object.DocumentAmount
							 - ?(PaymentTotalPaymentCards > Object.DocumentAmount, 0, PaymentTotalPaymentCards);
	
	RecalculateDocumentAtClient();
	
EndProcedure

&AtClient
Procedure EditPricesAndCurrency(Item, StandardProcessing)
	
	StandardProcessing = False;
	ProcessChangesOnButtonPricesAndCurrencies(Object.DocumentCurrency);
	Modified = True;
	
EndProcedure

// Procedure of processing the results of selection closing
//
&AtClient
Procedure OnCloseSelection(ClosingResult, AdditionalParameters) Export
	
	If TypeOf(ClosingResult) = Type("Structure") Then
		
		If Not IsBlankString(ClosingResult.CartAddressInStorage) Then
			
			InventoryAddressInStorage	= ClosingResult.CartAddressInStorage;
			
			GetInventoryFromStorage(InventoryAddressInStorage, "Inventory", True, True);
			
			RecalculateDocumentAtClient();
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region ProcedureEventHandlersOfHeaderAttributes

// Procedure - event handler OnChange field CashRegister on server.
//
&AtServer
Procedure CashCROnChangeAtServer()
	
	StatusCashCRSession = Documents.ShiftClosure.GetCashCRSessionAttributesToDate(Object.CashCR, ?(ValueIsFilled(Object.Ref), Object.Date, CurrentDate()));
	
	If ValueIsFilled(StatusCashCRSession.CashCRSessionStatus) Then
		FillPropertyValues(Object, StatusCashCRSession);
	EndIf;
	
	Items.Reserve.Visible = Not ControlAtWarehouseDisabled;
	Items.RemoveReservation.Visible = Not ControlAtWarehouseDisabled;
	
	ParentCompany = DriveServer.GetCompany(Object.Company);
	
	Object.POSTerminal = Catalogs.POSTerminals.GetPOSTerminalByDefault(Object.CashCR);
	
	GetRefsToEquipment();
	
	Object.Department = Object.CashCR.Department;
	If Not ValueIsFilled(Object.Department) Then
		
		User = Users.CurrentUser();
		SettingValue = DriveReUse.GetValueByDefaultUser(User, "MainDepartment");
		MainDepartment = ?(ValueIsFilled(SettingValue), SettingValue, Catalogs.BusinessUnits.MainDepartment);
		Object.Department = MainDepartment;
		
	EndIf;
	
	FillVATRateByCompanyVATTaxation();
	
	CashCRUseWithoutEquipmentConnection = Object.CashCR.UseWithoutEquipmentConnection;
	Items.InventoryPrice.ReadOnly = Object.StructuralUnit.StructuralUnitType <> Enums.BusinessUnitsTypes.Warehouse;
	Items.InventoryAmount.ReadOnly = Object.StructuralUnit.StructuralUnitType <> Enums.BusinessUnitsTypes.Warehouse;
	Items.InventoryVATAmount.ReadOnly = Object.StructuralUnit.StructuralUnitType <> Enums.BusinessUnitsTypes.Warehouse;
	
EndProcedure

// Procedure - event handler OnChange field CashCR.
//
&AtClient
Procedure CashCROnChange(Item)
	
	CashCROnChangeAtServer();
	DriveClient.RefillTabularSectionPricesByPriceKind(ThisForm, "Inventory", True);
	RecalculateDocumentAtClient();
	
	// Generate price and currency label.
	LabelStructure = New Structure;
	LabelStructure.Insert("PriceKind",						Object.PriceKind);
	LabelStructure.Insert("DiscountKind",					Object.DiscountMarkupKind);
	LabelStructure.Insert("DocumentCurrency",				Object.DocumentCurrency);
	LabelStructure.Insert("SettlementsCurrency",			Object.DocumentCurrency);
	LabelStructure.Insert("ExchangeRate",					ExchangeRate);
	LabelStructure.Insert("AmountIncludesVAT",				Object.AmountIncludesVAT);
	LabelStructure.Insert("ForeignExchangeAccounting",	ForeignExchangeAccounting);
	LabelStructure.Insert("RateNationalCurrency",			RateNationalCurrency);
	LabelStructure.Insert("VATTaxation",					Object.VATTaxation);
	LabelStructure.Insert("DiscountCard",					Object.DiscountCard);
	LabelStructure.Insert("DiscountPercentByDiscountCard",	Object.DiscountPercentByDiscountCard);
	
	PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
	
EndProcedure

// Procedure - OnChange event handler of the PaymentInCashAmount field.
//
&AtClient
Procedure CashReceivedOnChange(Item)
	
	RecalculateDocumentAtClient();
	
EndProcedure

// Procedure - event handler OnChange field POSTerminal on server.
//
&AtServer
Procedure POSTerminalOnChangeAtServer()
	
	GetRefsToEquipment();
	GetChoiceListOfPaymentCardKinds();
	SetPaymentEnabled();
	
EndProcedure

// Procedure - OnChange event handler of the POSTerminal field.
//
&AtClient
Procedure POSTerminalOnChange(Item)
	
	POSTerminalOnChangeAtServer();
	
EndProcedure

// Procedure - OnChange event handler of the PettyCashShift field.
//
&AtServer
Procedure CashCRSessionOnChangeAtServer()
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	ShiftClosure.CashCR AS CashCR
	|FROM
	|	Document.ShiftClosure AS ShiftClosure
	|WHERE
	|	ShiftClosure.Ref = &Ref";
	
	Query.SetParameter("Ref", Object.CashCRSession);
	
	Result = Query.Execute();
	Selection = Result.Select();
	Selection.Next();
	
	Object.CashCR = Selection.CashCR;
	
	StatusCashCRSession = Documents.ShiftClosure.GetCashCRSessionStatus(Object.CashCR);
	FillPropertyValues(Object, StatusCashCRSession);
	
	Items.Reserve.Visible = Not ControlAtWarehouseDisabled;
	Items.RemoveReservation.Visible = Not ControlAtWarehouseDisabled;
	
EndProcedure

// Procedure - OnChange event handler of the PettyCashShift field.
//
&AtClient
Procedure CashCRSessionOnChange(Item)
	
	CashCRSessionOnChangeAtServer();
	DriveClient.RefillTabularSectionPricesByPriceKind(ThisForm, "Inventory", True);
	RecalculateDocumentAtClient();
	
EndProcedure

// Procedure - OnChange event handler of the PaymentForm field on server.
//
&AtServer
Function PaymentFormOnChangeAtServer(ErrorDescription = "")
	
	If Object.PaymentForm = Enums.CashAssetTypes.Cash Then
		
		If Object.PaymentWithPaymentCards.Count() > 0 Then
			
			Object.PaymentForm = Enums.CashAssetTypes.EmptyRef();
			
			ErrorDescription = NStr("en = 'Paid with payment cards. Cannot set the ""In cash"" payment method'");
			Return False;
			
		EndIf;
		
	ElsIf Not ValueIsFilled(Object.PaymentForm) Then // Mixed
		
	Else // By payment cards
		
		Object.CashReceived = 0;
		
	EndIf;
	
	SetPaymentEnabled();
	
	Return True;
	
EndFunction

// Procedure - OnChange event handler of the PaymentForm field.
//
&AtClient
Procedure PaymentFormOnChange(Item)
	
	ErrorDescription = "";
	If Not PaymentFormOnChangeAtServer(ErrorDescription) Then
		ShowMessageBox(Undefined,ErrorDescription);
	EndIf;
	
EndProcedure

// Procedure - event handler OnChange of the Date input field.
// The procedure determines the situation when after changing the date
// of a document this document is found in another period
// of documents enumeration, and in this case the procedure assigns new unique number to the document.
// Overrides the corresponding form parameter.
//
&AtClient
Procedure DateOnChange(Item)
	
	// Date change event DataProcessor.
	DateBeforeChange = DocumentDate;
	DocumentDate = Object.Date;
	If Object.Date <> DateBeforeChange Then
		StructureData = GetDataDateOnChange(DateBeforeChange);
		If StructureData.DATEDIFF <> 0 Then
			Object.Number = "";
		EndIf;
		
		// Generate price and currency label.
		LabelStructure = New Structure;
		LabelStructure.Insert("PriceKind",						Object.PriceKind);
		LabelStructure.Insert("DiscountKind",					Object.DiscountMarkupKind);
		LabelStructure.Insert("DocumentCurrency",				Object.DocumentCurrency);
		LabelStructure.Insert("SettlementsCurrency",			Object.DocumentCurrency);
		LabelStructure.Insert("ExchangeRate",					ExchangeRate);
		LabelStructure.Insert("AmountIncludesVAT",				Object.AmountIncludesVAT);
		LabelStructure.Insert("ForeignExchangeAccounting",	ForeignExchangeAccounting);
		LabelStructure.Insert("RateNationalCurrency",			RateNationalCurrency);
		LabelStructure.Insert("VATTaxation",					Object.VATTaxation);
		LabelStructure.Insert("DiscountCard",					Object.DiscountCard);
		LabelStructure.Insert("DiscountPercentByDiscountCard",	Object.DiscountPercentByDiscountCard);
		
		PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
		
		// DiscountCards
		// IN this procedure call not modal window of question is occurred.
		RecalculateDiscountPercentAtDocumentDateChange();
		// End DiscountCards
	EndIf;
	
	// AutomaticDiscounts
	DocumentDateChangedManually = True;
	ClearCheckboxDiscountsAreCalculatedClient("DateOnChange");
	
EndProcedure

// Procedure - event handler OnChange field Company.
//
&AtClient
Procedure CompanyOnChange(Item)
	
	CompanyOnChangeAtServer();
	
	// Generate price and currency label.
	LabelStructure = New Structure;
	LabelStructure.Insert("PriceKind",						Object.PriceKind);
	LabelStructure.Insert("DiscountKind",					Object.DiscountMarkupKind);
	LabelStructure.Insert("DocumentCurrency",				Object.DocumentCurrency);
	LabelStructure.Insert("SettlementsCurrency",			Object.DocumentCurrency);
	LabelStructure.Insert("ExchangeRate",					ExchangeRate);
	LabelStructure.Insert("AmountIncludesVAT",				Object.AmountIncludesVAT);
	LabelStructure.Insert("ForeignExchangeAccounting",	ForeignExchangeAccounting);
	LabelStructure.Insert("RateNationalCurrency",			RateNationalCurrency);
	LabelStructure.Insert("VATTaxation",					Object.VATTaxation);
	LabelStructure.Insert("DiscountCard",					Object.DiscountCard);
	LabelStructure.Insert("DiscountPercentByDiscountCard",	Object.DiscountPercentByDiscountCard);
	
	PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
	
EndProcedure

// Procedure - OnChange event handler of the StructuralUnit field.
//
&AtClient
Procedure StructuralUnitOnChange(Item)
	
	StructuralUnitOnChangeAtServer();
	
EndProcedure

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
		StructureData.Insert("DocumentCurrency", Object.DocumentCurrency);
		StructureData.Insert("AmountIncludesVAT", Object.AmountIncludesVAT);
		StructureData.Insert("PriceKind", Object.PriceKind);
		StructureData.Insert("Factor", 1);
		StructureData.Insert("Content", "");
		StructureData.Insert("DiscountMarkupKind", Object.DiscountMarkupKind);
		
	EndIf;
	
	// DiscountCards
	StructureData.Insert("DiscountCard", Object.DiscountCard);
	StructureData.Insert("DiscountPercentByDiscountCard", Object.DiscountPercentByDiscountCard);		
	// End DiscountCards
	
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
	WorkWithSerialNumbersClientServer.DeleteSerialNumbersByConnectionKey(
		Object.SerialNumbers, TabularSectionRow,, UseSerialNumbersBalance);
	
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

// Procedure - event handler OnChange input field AmountDiscountsMarkups.
//
&AtClient
Procedure InventoryAmountDiscountsMarkupsOnChange(Item)
	
	CalculateDiscountMarkupPercent();
	
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
	
	// AutomaticDiscounts.
	AutomaticDiscountsRecalculationIsRequired = ClearCheckboxDiscountsAreCalculatedClient("CalculateAmountInTabularSectionLine", ThisObject.CurrentItem.CurrentItem.Name);
		
	TabularSectionRow.AutomaticDiscountsPercent = 0;
	TabularSectionRow.AutomaticDiscountAmount = 0;
	TabularSectionRow.TotalDiscountAmountIsMoreThanAmount = False;
	// End AutomaticDiscounts
	
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
	
	RecalculateDocumentAtClient();
	ThisIsNewRow = False;
	
EndProcedure

// Procedure - event handler AfterDeletion of the Inventory list row.
//
&AtClient
Procedure InventoryAfterDeleteRow(Item)
	
	RecalculateDocumentAtClient();
	
	// AutomaticDiscounts.
	ClearCheckboxDiscountsAreCalculatedClient("DeleteRow");
	
EndProcedure

&AtClient
Procedure InventorySerialNumbersStartChoice(Item, ChoiceData, StandardProcessing)
	StandardProcessing = False;
	OpenSerialNumbersSelection();
EndProcedure

&AtClient
Procedure InventoryBeforeDeleteRow(Item, Cancel)
	// Serial numbers
	CurrentData = Items.Inventory.CurrentData;
	WorkWithSerialNumbersClientServer.DeleteSerialNumbersByConnectionKey(
		Object.SerialNumbers, CurrentData,, UseSerialNumbersBalance);
EndProcedure

&AtClient
Procedure InventoryGLAccountsStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	SelectedRow = Items.Inventory.CurrentRow;
	OpenProductGLAccountsForm(SelectedRow);
	
EndProcedure

#EndRegion

// Procedure - OnEditEnd event handler of the PaymentWithPaymentCards list string.
//
&AtClient
Procedure PaymentWithPaymentCardsOnEditEnd(Item, NewRow, CancelEdit)
	
	RecalculateDocumentAtClient();
	
EndProcedure

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

// End StandardSubsystems.Printing

#EndRegion

#Region DiscountCards

// Procedure - Command handler ReadDiscountCard forms.
//
&AtClient
Procedure ReadDiscountCardClick(Item)
	
	NotifyDescription = New NotifyDescription("ReadDiscountCardClickEnd", ThisObject);
	OpenForm("Catalog.DiscountCards.Form.ReadingDiscountCard", , ThisForm, , , , NotifyDescription, FormWindowOpeningMode.LockOwnerWindow);	
	
EndProcedure

// Final part of procedure - of command handler ReadDiscountCard forms.
// Is called after read form closing of discount card.
//
&AtClient
Procedure ReadDiscountCardClickEnd(ReturnParameters, Parameters) Export

	If TypeOf(ReturnParameters) = Type("Structure") Then
		DiscountCardRead = ReturnParameters.DiscountCardRead;
		DiscountCardIsSelected(ReturnParameters.DiscountCard);
	EndIf;

EndProcedure

// Procedure - selection handler of discount card, beginning.
//
&AtClient
Procedure DiscountCardIsSelected(DiscountCard)

	ShowUserNotification(
		NStr("en = 'Discount card read'"),
		GetURL(DiscountCard),
		StringFunctionsClientServer.SubstituteParametersInString(NStr("en = 'Discount card %1 is read'"), DiscountCard),
		PictureLib.Information32);
	
	DiscountCardIsSelectedAdditionally(DiscountCard);
		
EndProcedure

// Procedure - selection handler of discount card, end.
//
&AtClient
Procedure DiscountCardIsSelectedAdditionally(DiscountCard)
	
	If Not Modified Then
		Modified = True;
	EndIf;
	
	Object.DiscountCard = DiscountCard;
	Object.DiscountPercentByDiscountCard = DriveServer.CalculateDiscountPercentByDiscountCard(Object.Date, DiscountCard);
	
	LabelStructure = New Structure;
	LabelStructure.Insert("PriceKind",						Object.PriceKind);
	LabelStructure.Insert("DiscountKind",					Object.DiscountMarkupKind);
	LabelStructure.Insert("DocumentCurrency",				Object.DocumentCurrency);
	LabelStructure.Insert("SettlementsCurrency",			Object.DocumentCurrency);
	LabelStructure.Insert("ExchangeRate",					ExchangeRate);
	LabelStructure.Insert("AmountIncludesVAT",				Object.AmountIncludesVAT);
	LabelStructure.Insert("ForeignExchangeAccounting",	ForeignExchangeAccounting);
	LabelStructure.Insert("RateNationalCurrency",			RateNationalCurrency);
	LabelStructure.Insert("VATTaxation",					Object.VATTaxation);
	LabelStructure.Insert("DiscountCard",					Object.DiscountCard);
	LabelStructure.Insert("DiscountPercentByDiscountCard",	Object.DiscountPercentByDiscountCard);
	
	PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
	
	If Object.Inventory.Count() > 0 Then
		Text = NStr("en = 'Refill discounts in all lines?'");
		Notification = New NotifyDescription("DiscountCardIsSelectedAdditionallyEnd", ThisObject);
		ShowQueryBox(Notification, Text, QuestionDialogMode.YesNo, , DialogReturnCode.Yes);
	EndIf;
	
EndProcedure

// Procedure - selection handler of discount card, end.
//
&AtClient
Procedure DiscountCardIsSelectedAdditionallyEnd(QuestionResult, AdditionalParameters) Export

	If QuestionResult = DialogReturnCode.Yes Then
		Discount = DriveServer.GetDiscountPercentByDiscountMarkupKind(Object.DiscountMarkupKind) + Object.DiscountPercentByDiscountCard;
	
		For Each TabularSectionRow In Object.Inventory Do
			
			TabularSectionRow.DiscountMarkupPercent = Discount;
			
			CalculateAmountInTabularSectionLine(TabularSectionRow);
			        
		EndDo;
	EndIf;
	
	RecalculateDocumentAtClient();
	
	// AutomaticDiscounts
	ClearCheckboxDiscountsAreCalculatedClient("DiscountRecalculationByDiscountCard");

EndProcedure

// Function returns True if the discount card, which is passed as the parameter, is fixed.
//
&AtServerNoContext
Function ThisDiscountCardWithFixedDiscount(DiscountCard)
	
	Return DiscountCard.Owner.DiscountKindForDiscountCards = Enums.DiscountTypeForDiscountCards.FixedDiscount;
	
EndFunction

// Procedure executes only for ACCUMULATIVE discount cards.
// Procedure calculates document discounts after document date change. Recalculation is executed if
// the discount percent by selected discount card changed. 
//
&AtClient
Procedure RecalculateDiscountPercentAtDocumentDateChange()
	
	If Object.DiscountCard.IsEmpty() OR ThisDiscountCardWithFixedDiscount(Object.DiscountCard) Then
		Return;
	EndIf;
	
	PreDiscountPercentByDiscountCard = Object.DiscountPercentByDiscountCard;
	NewDiscountPercentByDiscountCard = DriveServer.CalculateDiscountPercentByDiscountCard(Object.Date, Object.DiscountCard);
	
	If PreDiscountPercentByDiscountCard <> NewDiscountPercentByDiscountCard Then
		
		If Object.Inventory.Count() > 0 Then
			
			Text = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Do you want to change the discount rate from %1% to %2% and apply to the document?'"),
				PreDiscountPercentByDiscountCard,
				NewDiscountPercentByDiscountCard);			
			AdditionalParameters	= New Structure("NewDiscountPercentByDiscountCard, RecalculateTP", NewDiscountPercentByDiscountCard, True);
			Notification			= New NotifyDescription("RecalculateDiscountPercentAtDocumentDateChangeEnd", ThisObject, AdditionalParameters);
			
		Else
			
			Text = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Do you want to change the discount rate from %1% to %2%?'"),
				PreDiscountPercentByDiscountCard,
				NewDiscountPercentByDiscountCard);			
			AdditionalParameters	= New Structure("NewDiscountPercentByDiscountCard, RecalculateTP", NewDiscountPercentByDiscountCard, False);
			Notification			= New NotifyDescription("RecalculateDiscountPercentAtDocumentDateChangeEnd", ThisObject, AdditionalParameters);
			
		EndIf;
		
		ShowQueryBox(Notification, Text, QuestionDialogMode.YesNo,, DialogReturnCode.Yes);
		
	EndIf;
	
EndProcedure

// Procedure executes only for ACCUMULATIVE discount cards.
// Procedure calculates document discounts after document date change. Recalculation is executed if
// the discount percent by selected discount card changed. 
//
&AtClient
Procedure RecalculateDiscountPercentAtDocumentDateChangeEnd(QuestionResult, AdditionalParameters) Export

	If QuestionResult = DialogReturnCode.Yes Then
		Object.DiscountPercentByDiscountCard = AdditionalParameters.NewDiscountPercentByDiscountCard;
		
		LabelStructure = New Structure;
		LabelStructure.Insert("PriceKind",						Object.PriceKind);
		LabelStructure.Insert("DiscountKind",					Object.DiscountMarkupKind);
		LabelStructure.Insert("DocumentCurrency",				Object.DocumentCurrency);
		LabelStructure.Insert("SettlementsCurrency",			Object.DocumentCurrency);
		LabelStructure.Insert("ExchangeRate",					ExchangeRate);
		LabelStructure.Insert("AmountIncludesVAT",				Object.AmountIncludesVAT);
		LabelStructure.Insert("ForeignExchangeAccounting",	ForeignExchangeAccounting);
		LabelStructure.Insert("RateNationalCurrency",			RateNationalCurrency);
		LabelStructure.Insert("VATTaxation",					Object.VATTaxation);
		LabelStructure.Insert("DiscountCard",					Object.DiscountCard);
		LabelStructure.Insert("DiscountPercentByDiscountCard",	Object.DiscountPercentByDiscountCard);
		
		PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
		
		If AdditionalParameters.RecalculateTP Then
			DriveClient.RefillDiscountsTablePartAfterDiscountCardRead(ThisForm, "Inventory");
		EndIf;
				
	EndIf;
	
EndProcedure

#EndRegion

#Region AutomaticDiscounts

// Procedure - form command handler CalculateDiscountsMarkups.
//
&AtClient
Procedure CalculateDiscountsMarkups(Command)
	
	If Object.Inventory.Count() = 0 Then
		If Object.DiscountsMarkups.Count() > 0 Then
			Object.DiscountsMarkups.Clear();
		EndIf;
		Return;
	EndIf;
	
	CalculateDiscountsMarkupsClient();
	
EndProcedure

// Procedure calculates discounts by document.
//
&AtClient
Procedure CalculateDiscountsMarkupsClient()
	
	ParameterStructure = New Structure;
	ParameterStructure.Insert("ApplyToObject",                True);
	ParameterStructure.Insert("OnlyPreliminaryCalculation",      False);
	
	If EquipmentManagerClient.RefreshClientWorkplace() Then // Checks if the operator's workplace is specified
		Workplace = EquipmentManagerClientReUse.GetClientWorkplace();
	Else
		Workplace = ""
	EndIf;
	
	ParameterStructure.Insert("Workplace", Workplace);
	
	CalculateDiscountsMarkupsOnServer(ParameterStructure);
	
	RecalculateDocumentAtClient();
	
EndProcedure

// Function compares discount calculating data on current moment with data of the discount last calculation in document.
// If discounts changed the function returns the value True.
//
&AtServer
Function DiscountsChanged()
	
	ParameterStructure = New Structure;
	ParameterStructure.Insert("ApplyToObject",                False);
	ParameterStructure.Insert("OnlyPreliminaryCalculation",      False);
	
	AppliedDiscounts = DiscountsMarkupsServerOverridable.Calculate(Object, ParameterStructure);
	
	DiscountsChanged = False;
	
	LineCount = AppliedDiscounts.TableDiscountsMarkups.Count();
	If LineCount <> Object.DiscountsMarkups.Count() Then
		DiscountsChanged = True;
	Else
		
		If Object.Inventory.Total("AutomaticDiscountAmount") <> Object.DiscountsMarkups.Total("Amount") Then
			DiscountsChanged = True;
		EndIf;
		
		If Not DiscountsChanged Then
			For LineNumber = 1 To LineCount Do
				If    Object.DiscountsMarkups[LineNumber-1].Amount <> AppliedDiscounts.TableDiscountsMarkups[LineNumber-1].Amount
					OR Object.DiscountsMarkups[LineNumber-1].ConnectionKey <> AppliedDiscounts.TableDiscountsMarkups[LineNumber-1].ConnectionKey
					OR Object.DiscountsMarkups[LineNumber-1].DiscountMarkup <> AppliedDiscounts.TableDiscountsMarkups[LineNumber-1].DiscountMarkup Then
					DiscountsChanged = True;
					Break;
				EndIf;
			EndDo;
		EndIf;
		
	EndIf;
	
	If DiscountsChanged Then
		AddressDiscountsAppliedInTemporaryStorage = PutToTempStorage(AppliedDiscounts, UUID);
	EndIf;
	
	Return DiscountsChanged;
	
EndFunction

// Procedure calculates discounts by document.
//
&AtServer
Procedure CalculateDiscountsMarkupsOnServer(ParameterStructure)
	
	AppliedDiscounts = DiscountsMarkupsServerOverridable.Calculate(Object, ParameterStructure);
	
	AddressDiscountsAppliedInTemporaryStorage = PutToTempStorage(AppliedDiscounts, UUID);
	
	Modified = True;
	
	DiscountsMarkupsServerOverridable.UpdateDiscountDisplay(Object, "Inventory");
	
	If Not Object.DiscountsAreCalculated Then
	
		Object.DiscountsAreCalculated = True;
	
	EndIf;
	
	Items.InventoryCalculateDiscountsMarkups.Picture = PictureLib.Refresh;
	
	ThereAreManualDiscounts = Constants.UseManualDiscounts.Get();
	For Each CurrentRow In Object.Inventory Do
		ManualDiscountCurAmount = ?(ThereAreManualDiscounts, CurrentRow.Price * CurrentRow.Quantity * CurrentRow.DiscountMarkupPercent / 100, 0);
		CurAmountDiscounts = ManualDiscountCurAmount + CurrentRow.AutomaticDiscountAmount;
		If CurAmountDiscounts >= CurrentRow.Amount AND CurrentRow.Price > 0 Then
			CurrentRow.TotalDiscountAmountIsMoreThanAmount = True;
		Else
			CurrentRow.TotalDiscountAmountIsMoreThanAmount = False;
		EndIf;
	EndDo;
	
EndProcedure

// Procedure - command handler "OpenInformationAboutDiscounts".
//
&AtClient
Procedure OpenInformationAboutDiscounts(Command)
	
	CurrentData = Items.Inventory.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	OpenInformationAboutDiscountsClient()
	
EndProcedure

// Procedure opens a common form for information analysis about discounts by current row.
//
&AtClient
Procedure OpenInformationAboutDiscountsClient()
	
	ParameterStructure = New Structure;
	ParameterStructure.Insert("ApplyToObject",                True);
	ParameterStructure.Insert("OnlyPreliminaryCalculation",      False);
	
	ParameterStructure.Insert("OnlyMessagesAfterRegistration",   False);
	
	If EquipmentManagerClient.RefreshClientWorkplace() Then // Checks if the operator's workplace is specified
		Workplace = EquipmentManagerClientReUse.GetClientWorkplace();
	Else
		Workplace = ""
	EndIf;
	
	ParameterStructure.Insert("Workplace", Workplace);
	
	If Not Object.DiscountsAreCalculated Then
		QuestionText = NStr("en = 'The discounts are not applied. Do you want to apply them?'");
		
		AdditionalParameters = New Structure; 
		AdditionalParameters.Insert("ParameterStructure", ParameterStructure);
		NotificationHandler = New NotifyDescription("NotificationQueryCalculateDiscounts", ThisObject, AdditionalParameters);
		ShowQueryBox(NotificationHandler, QuestionText, QuestionDialogMode.YesNo);
	Else
		CalculateDiscountsCompleteQuestionDataProcessor(ParameterStructure);
	EndIf;
	
EndProcedure

// End modeless window opening "ShowQuestion()". Procedure opens a common form for information analysis about discounts
// by current row.
//
&AtClient
Procedure NotificationQueryCalculateDiscounts(QuestionResult, AdditionalParameters) Export
	
	If QuestionResult = DialogReturnCode.No Then
		Return;
	EndIf;
	ParameterStructure = AdditionalParameters.ParameterStructure;
	CalculateDiscountsMarkupsOnServer(ParameterStructure);
	CalculateDiscountsCompleteQuestionDataProcessor(ParameterStructure);
	
EndProcedure

// Procedure opens a common form for information analysis about discounts by current row after calculation of automatic discounts (if it was necessary).
//
&AtClient
Procedure CalculateDiscountsCompleteQuestionDataProcessor(ParameterStructure)
	
	If Not ValueIsFilled(AddressDiscountsAppliedInTemporaryStorage) Then
		CalculateDiscountsMarkupsClient();
	EndIf;
	
	CurrentData = Items.Inventory.CurrentData;
	MarkupsDiscountsClient.OpenFormAppliedDiscounts(CurrentData, Object, ThisObject);
	
EndProcedure

// Procedure - event handler Table parts selection Inventory.
//
&AtClient
Procedure InventorySelection(Item, SelectedRow, Field, StandardProcessing)
	
	If (Item.CurrentItem = Items.InventoryAutomaticDiscountPercent OR Item.CurrentItem = Items.InventoryAutomaticDiscountAmount)
		AND Not ReadOnly Then
		
		StandardProcessing = False;
		OpenInformationAboutDiscountsClient();
		
	ElsIf Field.Name = "InventoryGLAccounts" Then
		
		StandardProcessing = False;
		OpenProductGLAccountsForm(SelectedRow);
		
	EndIf;
	
EndProcedure

// Procedure - event handler OnStartEdit tabular section Inventory forms.
//
&AtClient
Procedure InventoryOnStartEdit(Item, NewRow, Copy)
	
	// AutomaticDiscounts
	If NewRow AND Copy Then
		Item.CurrentData.AutomaticDiscountsPercent = 0;
		Item.CurrentData.AutomaticDiscountAmount = 0;
		CalculateAmountInTabularSectionLine();
	EndIf;
	// End AutomaticDiscounts
	
	If NewRow AND Copy Then
		Item.CurrentData.ConnectionKey = 0;
		Item.CurrentData.SerialNumbers = "";
	EndIf;
	
	If Item.CurrentItem.Name = "SerialNumbersInventory" Then
		OpenSerialNumbersSelection();
	EndIf;
	
	If Not NewRow Or Copy Then
		Return;	
	EndIf;
	
	Item.CurrentData.GLAccounts = GLAccountsInDocumentsClientServer.GetEmptyGLAccountPresentation();
	
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

// Function clears checkbox "DiscountsAreCalculated" if it is necessary and returns True if it is required to
// recalculate discounts.
//
&AtServer
Function ResetFlagDiscountsAreCalculatedServer(Action, SPColumn = "")
	
	RecalculationIsRequired = False;
	If UseAutomaticDiscounts AND Object.Inventory.Count() > 0 AND (Object.DiscountsAreCalculated OR InstalledGrayColor) Then
		RecalculationIsRequired = ResetFlagDiscountsAreCalculated(Action, SPColumn);
	EndIf;
	Return RecalculationIsRequired;
	
EndFunction

// Function clears checkbox "DiscountsAreCalculated" if it is necessary and returns True if it is required to
// recalculate discounts.
//
&AtClient
Function ClearCheckboxDiscountsAreCalculatedClient(Action, SPColumn = "")
	
	RecalculationIsRequired = False;
	If UseAutomaticDiscounts AND Object.Inventory.Count() > 0 AND (Object.DiscountsAreCalculated OR InstalledGrayColor) Then
		RecalculationIsRequired = ResetFlagDiscountsAreCalculated(Action, SPColumn);
	EndIf;
	Return RecalculationIsRequired;
	
EndFunction

// Function clears checkbox DiscountsAreCalculated if it is necessary and returns True if it is required to recalculate discounts.
//
&AtServer
Function ResetFlagDiscountsAreCalculated(Action, SPColumn = "")
	
	Return DiscountsMarkupsServer.ResetFlagDiscountsAreCalculated(ThisObject, Action, SPColumn);
	
EndFunction

// Procedure executes necessary actions when creating the form on server.
//
&AtServer
Procedure AutomaticDiscountsOnCreateAtServer()
	
	InstalledGrayColor = False;
	UseAutomaticDiscounts = GetFunctionalOption("UseAutomaticDiscounts");
	If UseAutomaticDiscounts Then
		If Object.Inventory.Count() = 0 Then
			Items.InventoryCalculateDiscountsMarkups.Picture = PictureLib.UpdateGray;
			InstalledGrayColor = True;
		ElsIf Not Object.DiscountsAreCalculated Then
			Object.DiscountsAreCalculated = False;
			Items.InventoryCalculateDiscountsMarkups.Picture = PictureLib.UpdateRed;
		Else
			Items.InventoryCalculateDiscountsMarkups.Picture = PictureLib.Refresh;
		EndIf;
	EndIf;
	
EndProcedure

// Procedure - AppliedDiscounts event handler of the form.
&AtClient
Procedure AppliedDiscounts(Command)
	
	If Object.Ref.IsEmpty() Then
		QuestionText = "Data is still not recorded.
		|Transfer to ""Applied discounts"" is possible only after data is written.
		|Data will be written.";
		NotifyDescription = New NotifyDescription("AppliedDiscountsCompletion", ThisObject);
		ShowQueryBox(NotifyDescription, QuestionText, QuestionDialogMode.OKCancel);
	Else
		FormParameters = New Structure("DocumentRef", Object.Ref);
		OpenForm("Report.DiscountsAppliedInDocument.Form.ReportForm", FormParameters, ThisObject, UUID);
	EndIf;
	
EndProcedure

// End the AppliedDiscounts procedure. Called after closing the answer form.
//
&AtClient
Procedure AppliedDiscountsCompletion(Result, Parameters) Export
	
	If Result <> DialogReturnCode.OK Then
		Return;
	EndIf;

	If Write() Then
		FormParameters = New Structure("DocumentRef", Object.Ref);
		OpenForm("Report.DiscountsAppliedInDocument.Form.ReportForm", FormParameters, ThisObject, UUID);
	EndIf;
	
EndProcedure

// Procedure - event handler AfterWriteAtServer form.
//
&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	FillAddedColumns();
	
	// AutomaticDiscounts
	If RefreshImageAutoDiscountsAfterWrite Then
		Items.InventoryCalculateDiscountsMarkups.Picture = PictureLib.Refresh;
		RefreshImageAutoDiscountsAfterWrite = False;
	EndIf;
	// End AutomaticDiscounts
	
EndProcedure

#EndRegion

#Region WorkWithSerialNumbers

Function SerialNumberPickParameters(CurrentDataIdentifier)
	
	Return WorkWithSerialNumbers.SerialNumberPickParameters(Object, ThisObject.UUID, CurrentDataIdentifier);
	
EndFunction

Function GetSerialNumbersFromStorage(AddressInTemporaryStorage, RowKey)
	
	Modified = True;
	Return WorkWithSerialNumbers.GetSerialNumbersFromStorage(Object, AddressInTemporaryStorage, RowKey);
	
EndFunction

&AtClient
Procedure OpenSerialNumbersSelection()
		
	CurrentDataIdentifier = Items.Inventory.CurrentData.GetID();
	ParametersOfSerialNumbers = SerialNumberPickParameters(CurrentDataIdentifier);
	
	OpenForm("DataProcessor.SerialNumbersSelection.Form", ParametersOfSerialNumbers, ThisObject);

EndProcedure

#EndRegion

#EndRegion

#Region Initialize

ThisIsNewRow = False;

#EndRegion