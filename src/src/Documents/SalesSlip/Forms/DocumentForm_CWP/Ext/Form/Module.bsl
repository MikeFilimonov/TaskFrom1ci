#Region Variables

&AtClient
Var Displays;

#EndRegion

#Region CommonUseProceduresAndFunctions

// Procedure initializes new receipt parameters.
//
&AtServer
Procedure InitializeNewReceipt()
	
	Try
		UnlockDataForEdit(Object.Ref, UUID);
	Except
		//
	EndTry;
	
	NewReceipt = Documents.SalesSlip.CreateDocument();
	
	FillPropertyValues(NewReceipt, Object,, "Inventory, PaymentWithPaymentCards, DiscountsMarkups, Number");
	
	ValueToFormData(NewReceipt, Object);
	
	Object.DocumentAmount = 0;
	
	Object.DiscountMarkupKind = Undefined;
	Object.DiscountCard = Undefined;
	Object.DiscountPercentByDiscountCard = 0;
	Object.DiscountsAreCalculated = False;
	DiscountAmount = 0;
	
	Object.CashReceived = 0;
	ReceivedPaymentCards = 0;
	
	AmountReceiptWithoutDiscounts = 0;
	AmountShortChange = 0;
	
	Object.Inventory.Clear();
	Object.PaymentWithPaymentCards.Clear();
	Object.DiscountsMarkups.Clear();
	
	Object.SalesSlipNumber = "";
	Object.Archival = False;
	Object.Status = Enums.SalesSlipStatus.ReceiptIsNotIssued;
	
	InstalledGrayColor = True;
	Items.InventoryCalculateDiscountsMarkups.Picture = PictureLib.UpdateGray;
	
EndProcedure

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
	
	Paid = Object.CashReceived + Object.PaymentWithPaymentCards.Total("Amount");
	AmountShortChange = ?(Paid = 0, 0, Paid - Object.DocumentAmount);
	
	DiscountAmount = Object.Inventory.Total("DiscountAmount");
	AmountReceiptWithoutDiscounts = Object.DocumentAmount + DiscountAmount;
	
	DocumentSubtotal = Object.Inventory.Total("Total") - Object.Inventory.Total("VATAmount") + Object.Inventory.Total("DiscountAmount");
	
	DisplayInformationOnCustomerDisplay();
	
EndProcedure

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

EndProcedure

// Procedure fills the VAT rate in the tabular section according to company's taxation system.
// 
&AtServer
Procedure FillVATRateByCompanyVATTaxation()
	
	TaxationBeforeChange = Object.VATTaxation;
	Object.VATTaxation = DriveServer.VATTaxation(Object.Company, Object.Date);
	
	If Not TaxationBeforeChange = Object.VATTaxation Then
		FillVATRateByVATTaxation();
	EndIf;
	
EndProcedure

// Procedure fills the VAT rate in the tabular section according to taxation system.
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
	
	GLAccounts = GLAccountsInDocuments.GetProductListGLAccounts(StructureData);
	GLAccountsInDocumentsServerCall.FillProductGLAccounts(StructureData, GLAccounts);
	
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

// Procedure fills data when Products change.
//
&AtClient
Procedure ProductsOnChange(TabularSectionRow)
	
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
		StructureData.Insert("DiscountMarkupKind", Object.DiscountMarkupKind);
		
	EndIf;
	
	// DiscountCards
	StructureData.Insert("DiscountCard",  Object.DiscountCard);
	StructureData.Insert("DiscountPercentByDiscountCard", Object.DiscountPercentByDiscountCard);
	// End DiscountCards
	
	StructureData = GetDataProductsOnChange(StructureData);
	
	TabularSectionRow.MeasurementUnit = StructureData.MeasurementUnit;
	TabularSectionRow.Quantity = 1;
	TabularSectionRow.Price = StructureData.Price;
	TabularSectionRow.DiscountMarkupPercent = StructureData.DiscountMarkupPercent;
	TabularSectionRow.VATRate = StructureData.VATRate;
	
	CalculateAmountInTabularSectionLine(TabularSectionRow);
	
EndProcedure

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

// VAT amount is calculated in the row of a tabular section.
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

// Procedure calculates the amount in the row of a tabular section.
//
&AtClient
Procedure CalculateAmountInTabularSectionLine(TabularSectionRow = Undefined, SetDescription = True)
	
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
		DocumentConvertedAtClient = True;
	Else
		DocumentConvertedAtClient = False;
	EndIf;
	// End AutomaticDiscounts

	// CWP
	If SetDescription Then
		SetDescriptionForStringTSInventoryAtClient(TabularSectionRow);
	EndIf;
	
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
	
	SetDescriptionForStringTSInventoryAtClient(TabularSectionRow);
	
EndProcedure

// Function gets a product list from the temporary storage
//
&AtServer
Procedure GetInventoryFromStorage(InventoryAddressInStorage, TabularSectionName, AreCharacteristics, AreBatches)
	
	TableForImport = GetFromTempStorage(InventoryAddressInStorage);
	StructureData = New Structure("Products, RevenueGLAccount, VATOutputGLAccount");
	ObjectParameters = GLAccountsInDocumentsClientServer.GetObjectParameters(Object);
	StructureData.Insert("ObjectParameters", ObjectParameters);
	
	For Each ImportRow In TableForImport Do
		
		NewRow = Object[TabularSectionName].Add();
		FillPropertyValues(NewRow, ImportRow);
		
		NewRow.DiscountAmount = (NewRow.Quantity * NewRow.Price) - NewRow.Amount;
		NewRow.AmountDiscountsMarkups = NewRow.DiscountAmount;
		NewRow.ProductsCharacteristicAndBatch = TrimAll(NewRow.Products.Description)+?(NewRow.Characteristic.IsEmpty(), "", ". "+NewRow.Characteristic)+?(NewRow.Batch.IsEmpty(), "", ". "+NewRow.Batch);
		If NewRow.DiscountAmount <> 0 Then
			DiscountPercent = Format(NewRow.DiscountAmount * 100 / (NewRow.Quantity * NewRow.Price), "NFD=2");
			DiscountText = ?(NewRow.DiscountAmount > 0, " - "+NewRow.DiscountAmount, " + "+(-NewRow.DiscountAmount))+" "+Object.DocumentCurrency
						  +" ("+?(NewRow.DiscountAmount > 0, " - "+DiscountPercent+"%)", " + "+(-DiscountPercent)+"%)");
		Else
			DiscountText = "";
		EndIf;
		NewRow.DataOnRow = ""+NewRow.Price+" "+Object.DocumentCurrency+" X "+NewRow.Quantity+" "+NewRow.MeasurementUnit+DiscountText+" = "+NewRow.Amount+" "+Object.DocumentCurrency;
		
		FillPropertyValues(StructureData, NewRow);
		GLAccounts = GLAccountsInDocuments.GetProductListGLAccounts(StructureData);
		GLAccountsInDocumentsServerCall.FillProductGLAccounts(StructureData, GLAccounts);
		FillPropertyValues(NewRow, StructureData);
		
	EndDo;
	
	// AutomaticDiscounts
	If TableForImport.Count() > 0 Then
		ResetFlagDiscountsAreCalculatedServer("PickDataProcessor");
	EndIf;

	ShowHideDealAtServer(False, True);
	
EndProcedure

// Procedure runs recalculation in the document tabular section after making changes in the "Prices and currency" form.
// The columns are recalculated as follows: price, discount, amount, VAT amount, total amount.
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
	LabelStructure.Insert("ForeignExchangeAccounting",		ForeignExchangeAccounting);
	LabelStructure.Insert("RateNationalCurrency",			RateNationalCurrency);
	LabelStructure.Insert("VATTaxation",					Object.VATTaxation);
	LabelStructure.Insert("DiscountCard",					Object.DiscountCard);
	LabelStructure.Insert("DiscountPercentByDiscountCard",	Object.DiscountPercentByDiscountCard);
	
	PricesAndCurrency = GenerateLabelPricesAndCurrency(LabelStructure);
	
	// Update document footer
	RecalculateDocumentAtClient();
	
	// Update labels for all strings TS Inventory.
	FillInDetailsForTSInventoryAtClient();
	
EndProcedure

// Function returns the label text "Prices and currency".
//
&AtClientAtServerNoContext
Function GenerateLabelPricesAndCurrency(LabelStructure)
	
	LabelText = "";
	
	// Currency.
	If LabelStructure.ForeignExchangeAccounting Then
		If ValueIsFilled(LabelStructure.DocumentCurrency) Then
			LabelText = TrimAll(String(LabelStructure.DocumentCurrency));
		EndIf;
	EndIf;
	
	// Price kind.
	If ValueIsFilled(LabelStructure.PriceKind) Then
		If IsBlankString(LabelText) Then
			LabelText = LabelText + "%1";
		Else
			LabelText = LabelText + " • %1";
		EndIf;
		LabelText = StringFunctionsClientServer.SubstituteParametersInString(LabelText, TrimAll(String(LabelStructure.PriceKind)));  
	EndIf;
	
	// Discount type and percent.
	If ValueIsFilled(LabelStructure.DiscountKind) Then
		If IsBlankString(LabelText) Then
			LabelText = LabelText + "%1";
		Else
			LabelText = LabelText + " • %1";
		EndIf;
		LabelText = StringFunctionsClientServer.SubstituteParametersInString(LabelText, TrimAll(String(LabelStructure.DiscountKind)));  
	EndIf;
																			
	// Discount card.
	If ValueIsFilled(LabelStructure.DiscountCard) Then
		If IsBlankString(LabelText) Then
			LabelText = LabelText + "%1";
		Else
			LabelText = LabelText + " • %1";
		EndIf;
		LabelText = StringFunctionsClientServer.SubstituteParametersInString(LabelText, 
		String(LabelStructure.DiscountPercentByDiscountCard) + "% "
		+ NStr("en = 'by card'"));  
	EndIf;	
	
	// VAT taxation.
	If ValueIsFilled(LabelStructure.VATTaxation) Then
		If IsBlankString(LabelText) Then
			LabelText = LabelText + "%1";
		Else
			LabelText = LabelText + " • %1";
		EndIf;
		LabelText = StringFunctionsClientServer.SubstituteParametersInString(LabelText, TrimAll(String(LabelStructure.VATTaxation)));  
	EndIf;
	
	// Flag showing that amount includes VAT.
	If IsBlankString(LabelText) Then
		If LabelStructure.AmountIncludesVAT Then	
			LabelText = NStr("en = 'Amount includes VAT'");
		Else
			LabelText = NStr("en = 'Amount excludes VAT'");
		EndIf;
	EndIf;
	
	Return LabelText;
	
EndFunction

// Procedure forms form heading.
//
&AtServer
Procedure GenerateTitle(StructureStateCashCRSession)
	
	If StructureStateCashCRSession.SessionIsOpen Then
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = '%1, Session #%2 %3'"),
			TrimAll(StructureStateCashCRSession.StructuralUnit),
			TrimAll(StructureStateCashCRSession.CashCRSessionNumber),
			Format(StructureStateCashCRSession.StatusModificationDate, "DLF=D"));
	Else
		MessageText = "%1";
		If ValueIsFilled(StructureStateCashCRSession.StructuralUnit) Then
			MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessageText, TrimAll(StructureStateCashCRSession.StructuralUnit));
		Else
			MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessageText, TrimAll(CashCR.StructuralUnit));
		EndIf;
	EndIf;
	
	Title = MessageText;
	
EndProcedure

&AtServer
Procedure SetAccountingPolicyValues()

	AccountingPolicy = InformationRegisters.AccountingPolicy.GetAccountingPolicy(Object.Date, Object.Company);
	UseGoodsReturnFromCustomer = AccountingPolicy.UseGoodsReturnFromCustomer;
	
EndProcedure

&AtClient
Procedure AddGLAccountsToStructure(StructureData, TabRow)
	
	StructureData.Insert("RevenueGLAccount",	TabRow.RevenueGLAccount);
	StructureData.Insert("VATOutputGLAccount",	TabRow.VATOutputGLAccount);
	
EndProcedure

&AtClient
Procedure GLAccountsChoiceProcessingAtClient(GLAccounts)

	TabRow = Items[GLAccounts.TableName].CurrentData;
	FillPropertyValues(TabRow, GLAccounts);
	Modified = True;
	
	ObjectParameters = GLAccountsInDocumentsClientServer.GetObjectParameters(Object);
	
	StructureData = New Structure("Products, RevenueGLAccount, VATOutputGLAccount");
	FillPropertyValues(StructureData, TabRow);
	StructureData.Insert("TabName", GLAccounts.TableName);
	StructureData.Insert("ObjectParameters", ObjectParameters);
	
	GLAccountsInDocumentsClientServer.FillProductGLAccountsDescription(StructureData);
	FillPropertyValues(TabRow, StructureData);
	
EndProcedure

#EndRegion

#Region UseCommonUseProceduresAndFunctionsCashCRSession

// Receipt print procedure on fiscal register.
//
&AtClient
Procedure IssueReceipt(GenerateSalesReceipt = False, GenerateSimplifiedTaxInvoice = False)
	
	ErrorDescription = "";
	
	If Object.SalesSlipNumber <> 0
	AND Not CashCRUseWithoutEquipmentConnection Then
		
		MessageText = NStr("en = 'Receipt has already been issued on the fiscal data recorder.'");
		CommonUseClientServer.MessageToUser(MessageText);
		Return;
		
	EndIf;
	
	ShowMessageBox = False;
	If DriveClient.CheckPossibilityOfReceiptPrinting(ThisForm, ShowMessageBox) Then
		
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
							ProductsTableRow.Add(TSRow.Quantity);   //  6 - Count
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
							
							Try
								PostingResult = Write(New Structure("WriteMode", DocumentWriteMode.Posting));
								ShowHideDealAtServer();
							Except
							
								FillInDetailsForTSInventoryAtClient();
								ShowMessageBox(Undefined, NStr("en = 'Failed to post document.'")); // Asynchronous method.
								Return;
							EndTry;
							
							GeneratePrintForms(GenerateSalesReceipt, GenerateSimplifiedTaxInvoice);
							
							InitializeNewReceipt();
							DisplayInformationOnCustomerDisplay();
							
						Else
							
							MessageText = NStr("en = 'When printing a receipt, an error occurred.
							                   |Receipt is not printed on the fiscal register.
							                   |Additional description: %1.'");
							MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessageText,Output_Parameters[1]);
							CommonUseClientServer.MessageToUser(MessageText);
							
						EndIf;
						
						// Disconnect FR
						EquipmentManagerClient.DisableEquipmentById(UUID, DeviceIdentifier);
						
					Else
						
						MessageText = NStr("en = 'An error occurred when connecting the device.
						                   |Receipt is not printed on the fiscal register.
						                   |Additional description: %1.'");
						MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessageText, ErrorDescription);
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
			
			Try
				PostingResult = Write(New Structure("WriteMode", DocumentWriteMode.Posting));
				ShowHideDealAtServer();
			Except
				FillInDetailsForTSInventoryAtClient();
				ShowMessageBox(Undefined,NStr("en = 'Failed to post document.'")); // Asynchronous method.
				Return;
			EndTry;
			
			GeneratePrintForms(GenerateSalesReceipt, GenerateSimplifiedTaxInvoice);
			
			InitializeNewReceipt();
			DisplayInformationOnCustomerDisplay();
			
		EndIf;
		
	Else
		
		FillInDetailsForTSInventoryAtClient();
		If ShowMessageBox Then
			ShowMessageBox(Undefined,NStr("en = 'Failed to post document'"));
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure GeneratePrintForms(GenerateSalesReceipt, GenerateSimplifiedTaxInvoice)
	
	If  Not Object.Ref.IsEmpty() Then
		
		If GenerateSalesReceipt Then
			
			OpenParameters = New Structure("PrintManagerName, TemplateNames, CommandParameter, PrintParameters");
			OpenParameters.PrintManagerName = "Document.SalesSlip";
			OpenParameters.TemplateNames		 = "SalesReceipt";
			SalesSlipsArray = New Array;
			SalesSlipsArray.Add(Object.Ref);
			OpenParameters.CommandParameter	 = SalesSlipsArray;
			OpenParameters.PrintParameters	 = Undefined;
			
			OpenForm("CommonForm.PrintDocuments", OpenParameters, ThisForm, UniqueKey);
			
		EndIf;
		
		If GenerateSimplifiedTaxInvoice Then
			
			OpenParameters = New Structure("PrintManagerName, TemplateNames, CommandParameter, PrintParameters");
			OpenParameters.PrintManagerName = "Document.SalesSlip";
			OpenParameters.TemplateNames	= "SimplifiedTaxInvoice";
			SalesSlipsArray = New Array;
			SalesSlipsArray.Add(Object.Ref);
			OpenParameters.CommandParameter	= SalesSlipsArray;
			OpenParameters.PrintParameters	= Undefined;
			
			OpenForm("CommonForm.PrintDocuments", OpenParameters, ThisForm, UniqueKey);
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Function gets cash session state on server.
//
&AtServerNoContext
Function GetCashCRSessionStateAtServer(CashCR)
	
	Return Documents.ShiftClosure.GetCashCRSessionStatus(CashCR);
	
EndFunction

// Procedure - event handler "OpenCashCRSession".
//
&AtClient
Procedure CashCRSessionOpen()
	
	Result = False;
	ClearMessages();
	If EquipmentManagerClient.RefreshClientWorkplace() Then
		
		// Device connection
		CashRegistersSettings = DriveReUse.CashRegistersGetParameters(CashCR);
		DeviceIdentifier = CashRegistersSettings.DeviceIdentifier;
		UseWithoutEquipmentConnection = CashRegistersSettings.UseWithoutEquipmentConnection;
		
		If DeviceIdentifier <> Undefined OR UseWithoutEquipmentConnection Then
			
			ErrorDescription = "";
			
			If Not UseWithoutEquipmentConnection Then
				
				Result = EquipmentManagerClient.ConnectEquipmentByID(
					UUID,
					DeviceIdentifier,
					ErrorDescription
				);
				
			EndIf;
			
			If Result OR UseWithoutEquipmentConnection Then
				
				If Not UseWithoutEquipmentConnection Then
					
					InputParameters  = Undefined;
					Output_Parameters = Undefined;
					
					// Open session on fiscal register
					Result = EquipmentManagerClient.RunCommand(
						DeviceIdentifier,
						"OpenDay",
						InputParameters, 
						Output_Parameters
					);
					
				EndIf;
				
				If Result OR UseWithoutEquipmentConnection Then
					
					Result = CashCRSessionOpenAtServer(CashCR, ErrorDescription);
					
					If Not Result Then
						
						MessageText = NStr("en = 'An error occurred when opening the session.
						                   |Session is not opened.
						                   |Additional description: %1.'");
						MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessageText,
						?(UseWithoutEquipmentConnection, ErrorDescription, Output_Parameters[1]));
						CommonUseClientServer.MessageToUser(MessageText);
						
					EndIf;
					
				Else
					
					MessageText = NStr("en = 'An error occurred when opening the session.
					                   |Session is not opened.
					                   |Additional description: %1.'");
					MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessageText, ErrorDescription);
					CommonUseClientServer.MessageToUser(MessageText);
					
				EndIf;
				
				If Not UseWithoutEquipmentConnection Then
					
					EquipmentManagerClient.DisableEquipmentById(
						UUID,
						DeviceIdentifier
					);
					
				EndIf;
				
			Else
				
				MessageText = NStr("en = 'An error occurred when connecting the device.
				                   |Session is not opened on the fiscal register.
				                   |Additional description: %1.'");
				MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessageText, ErrorDescription);
				CommonUseClientServer.MessageToUser(MessageText);
				
			EndIf;
			
		EndIf;
		
	Else
		
		MessageText = NStr("en = 'First, you need to select the work place of the current session peripherals.'"
		);
		CommonUseClientServer.MessageToUser(MessageText);
		
	EndIf;
	
EndProcedure

// Function opens the cash session on server.
//
&AtServer
Function CashCRSessionOpenAtServer(CashCR, ErrorDescription = "")
	
	Return Documents.ShiftClosure.CashCRSessionOpen(CashCR, ErrorDescription);
	
EndFunction

// Function verifies the existence of issued receipts during the session.
//
&AtServer
Function IssuedReceiptsExist(CashCR)
	
	StructureStateCashCRSession = Documents.ShiftClosure.GetCashCRSessionStatus(CashCR);
	
	If StructureStateCashCRSession.CashCRSessionStatus <> Enums.ShiftClosureStatus.IsOpen Then
		Return False;
	EndIf;
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	SalesSlipInventory.Ref AS CountRecipies
	|FROM
	|	(SELECT
	|		SalesSlipInventory.Ref AS Ref
	|	FROM
	|		Document.SalesSlip.Inventory AS SalesSlipInventory
	|	WHERE
	|		SalesSlipInventory.Ref.CashCRSession = &CashCRSession
	|		AND SalesSlipInventory.Ref.Posted
	|		AND SalesSlipInventory.Ref.SalesSlipNumber > 0
	|		AND (NOT SalesSlipInventory.Ref.Archival)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		SalesSlipInventory.Ref
	|	FROM
	|		Document.ProductReturn.Inventory AS SalesSlipInventory
	|	WHERE
	|		SalesSlipInventory.Ref.CashCRSession = &CashCRSession
	|		AND SalesSlipInventory.Ref.Posted
	|		AND SalesSlipInventory.Ref.SalesSlipNumber > 0
	|		AND (NOT SalesSlipInventory.Ref.Archival)) AS SalesSlipInventory";
	
	Query.SetParameter("CashCRSession", StructureStateCashCRSession.CashCRSession);
	
	Result = Query.Execute();
	
	Return Not Result.IsEmpty();
	
EndFunction

// Procedure closes the cash session on server.
//
&AtServer
Function CloseCashCRSessionAtServer(CashCR, ErrorDescription = "")
	
	Return Documents.ShiftClosure.CloseCashCRSessionExecuteArchiving(CashCR, ErrorDescription);
	
EndFunction

// Procedure - command handler "FundsIntroduction".
//
&AtClient
Procedure CashDeposition(Command)
	
	If EquipmentManagerClient.RefreshClientWorkplace() Then
		
		InAmount = 0;
		
		WindowTitle = NStr("en = 'Deposit amount'") + ", " + "%Currency%";
		WindowTitle = StrReplace(
			WindowTitle,
			"%Currency%",
			StructureStateCashCRSession.DocumentCurrencyPresentation
		);
		
		ShowInputNumber(New NotifyDescription("FundsIntroductionEnd", ThisObject, New Structure("InAmount", InAmount)), InAmount, WindowTitle, 15, 2);
		
	Else
		
		MessageText = NStr("en = 'First, you need to select the work place of the current session peripherals.'"
		);
		CommonUseClientServer.MessageToUser(MessageText);
		
	EndIf;
	
EndProcedure

// Procedure - command handler "FundsIntroduction" after introduction amount enter.
//
&AtClient
Procedure FundsIntroductionEnd(Result1, AdditionalParameters) Export
	
	InAmount = ?(Result1 = Undefined, AdditionalParameters.InAmount, Result1);
	
	If (Result1 <> Undefined) Then
		
		// Device connection
		CashRegistersSettings = DriveReUse.CashRegistersGetParameters(CashCR);
		DeviceIdentifier = CashRegistersSettings.DeviceIdentifier;
		UseWithoutEquipmentConnection = CashRegistersSettings.UseWithoutEquipmentConnection;
		
		If ValueIsFilled(DeviceIdentifier) Then
			FundsIntroductionFiscalRegisterConnectionsEnd(DeviceIdentifier, InAmount);
		Else
			NotifyDescription = New NotifyDescription("FundsIntroductionFiscalRegisterConnectionsEnd", ThisObject, InAmount);
			EquipmentManagerClient.OfferSelectDevice(NotifyDescription, "FiscalRegister",
				NStr("en = 'Select a fiscal data recorder'"),
				NStr("en = 'Fiscal data recorder is not connected.'"));
		EndIf;
		
	EndIf;

EndProcedure

// Procedure prints receipt on FR (Encash command).
//
&AtClient
Procedure FundsIntroductionFiscalRegisterConnectionsEnd(DeviceIdentifier, Parameters) Export
	
	InAmount = Parameters;
	ErrorDescription = "";
	
	If DeviceIdentifier <> Undefined Then
		
		// Connect FR
		Result = EquipmentManagerClient.ConnectEquipmentByID(
			UUID,
			DeviceIdentifier,
			ErrorDescription
		);
		
		If Result Then
			
			// Prepare data
			InputParameters  = New Array();
			Output_Parameters = Undefined;
			
			InputParameters.Add(1);
			InputParameters.Add(InAmount);
			
			// Print receipt.
			Result = EquipmentManagerClient.RunCommand(
			DeviceIdentifier,
			"Encash",
			InputParameters,
			Output_Parameters
			);
			
			If Not Result Then
				
				MessageText = NStr("en = 'When printing a receipt, an error occurred.
				                   |Receipt is not printed on the fiscal register.
				                   |Additional description: %1.'");
				MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessageText, Output_Parameters[1]);
				CommonUseClientServer.MessageToUser(MessageText);
				
			EndIf;
			
			// Disconnect FR
			EquipmentManagerClient.DisableEquipmentById(UUID, DeviceIdentifier);
			
		Else
			
			MessageText = NStr("en = 'An error occurred when connecting the device.
			                   |Receipt is not printed on the fiscal register.
			                   |Additional description: %1.'");
			MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessageText, ErrorDescription);
			CommonUseClientServer.MessageToUser(MessageText);
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Procedure - command handler "FundsWithdrawal".
//
&AtClient
Procedure Withdrawal(Command)
	
	If EquipmentManagerClient.RefreshClientWorkplace() Then
		
		WithdrawnAmount = 0;
		
		WindowTitle = NStr("en = 'Withdrawal amount'") + ", " + "%Currency%";
		WindowTitle = StrReplace(
			WindowTitle,
			"%Currency%",
			StructureStateCashCRSession.DocumentCurrencyPresentation
		);
		
		ShowInputNumber(New NotifyDescription("CashWithdrawalEnd", ThisObject, New Structure("WithdrawnAmount", WithdrawnAmount)), WithdrawnAmount, WindowTitle, 15, 2);
		
	Else
		
		MessageText = NStr("en = 'First, you need to select the work place of the current session peripherals.'");
		CommonUseClientServer.MessageToUser(MessageText);
		
	EndIf;
	
EndProcedure

// Procedure - command handler "FundsWithdrawal" after enter dredging amount.
//
&AtClient
Procedure CashWithdrawalEnd(Result1, AdditionalParameters) Export
	
	WithdrawnAmount = ?(Result1 = Undefined, AdditionalParameters.WithdrawnAmount, Result1);
	
	If (Result1 <> Undefined) Then
		
		ErrorDescription = "";
		
		// Device connection
		CashRegistersSettings = DriveReUse.CashRegistersGetParameters(CashCR);
		DeviceIdentifier = CashRegistersSettings.DeviceIdentifier;
		UseWithoutEquipmentConnection = CashRegistersSettings.UseWithoutEquipmentConnection;
		
		If ValueIsFilled(DeviceIdentifier) Then
			CashWithdrawalFiscalRegisterConnectionsEnd(DeviceIdentifier, WithdrawnAmount);
		Else
			NotifyDescription = New NotifyDescription("CashWithdrawalFiscalRegisterConnectionsEnd", ThisObject, WithdrawnAmount);
			EquipmentManagerClient.OfferSelectDevice(NotifyDescription, "FiscalRegister",
				NStr("en = 'Select a fiscal data recorder'"),
				NStr("en = 'Fiscal data recorder is not connected.'"));
		EndIf;
	
	EndIf;

EndProcedure

// Procedure prints receipt on FR (Encash command).
//
&AtClient
Procedure CashWithdrawalFiscalRegisterConnectionsEnd(DeviceIdentifier, Parameters) Export
	
	WithdrawnAmount = Parameters;
	ErrorDescription = "";
	
	If DeviceIdentifier <> Undefined Then
			
			// Connect FR
			Result = EquipmentManagerClient.ConnectEquipmentByID(
			UUID,
			DeviceIdentifier,
			ErrorDescription
			);
			
			If Result Then
				
				// Prepare data
				InputParameters  = New Array();
				Output_Parameters = Undefined;
				
				InputParameters.Add(0);
				InputParameters.Add(WithdrawnAmount);
				
				// Print receipt.
				Result = EquipmentManagerClient.RunCommand(
					DeviceIdentifier,
					"Encash",
					InputParameters,
					Output_Parameters
				);
				
				If Not Result Then
					
					MessageText = NStr("en = 'When printing a receipt, an error occurred.
					                   |Receipt is not printed on the fiscal register.
					                   |Additional description: %1.'");
					MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessageText, Output_Parameters[1]);
					CommonUseClientServer.MessageToUser(MessageText);
					
				EndIf;
				
				// Disconnect FR
				EquipmentManagerClient.DisableEquipmentById(UUID, DeviceIdentifier);
				
			Else
				
				MessageText = NStr("en = 'An error occurred when connecting the device.
				                   |Receipt is not printed on the fiscal register.
				                   |Additional description: %1.'");
				MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessageText, ErrorDescription);
				CommonUseClientServer.MessageToUser(MessageText);
				
			EndIf;
			
		EndIf;
	
EndProcedure

// Procedure is called when pressing the PrintReceipt command panel button.
//
&AtClient
Procedure IssueReceiptExecute(Command, GenerateSalesReceipt = False, GenerateSimplifiedTaxInvoice = False)
	
	StructureStateCashCRSession = GetCashCRSessionStateAtServer(CashCR);
	If Not StructureStateCashCRSession.SessionIsOpen Then
		CashCRSessionOpen();
		StructureStateCashCRSession = GetCashCRSessionStateAtServer(CashCR);
	EndIf;
	
	If ValueIsFilled(StructureStateCashCRSession.CashCRSessionStatus) Then
		FillPropertyValues(Object, StructureStateCashCRSession,, "Responsible, Department");
		BalanceInCashier = StructureStateCashCRSession.CashInPettyCash;
		BalanceInCashierRow = ""+BalanceInCashier;
	EndIf;
	
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
	
	Object.Date = CurrentDate();
	
	If Not Cancel AND CheckFilling() Then
		
		IssueReceipt(GenerateSalesReceipt, GenerateSimplifiedTaxInvoice);
		Notify("RefreshSalesSlipDocumentsListForm");
		
		StructureStateCashCRSession = GetCashCRSessionStateAtServer(CashCR);
		BalanceInCashier = StructureStateCashCRSession.CashInPettyCash;
		BalanceInCashierRow = ""+BalanceInCashier;
		GenerateTitle(StructureStateCashCRSession);
		
	EndIf;
	
EndProcedure

// Procedure X report printing.
//
&AtClient
Procedure ReportPrintingWithoutBlankingExecuteEnd(DeviceIdentifier, AdditionalParameters) Export

	ErrorDescription = "";

	If DeviceIdentifier <> Undefined Then
		Result = EquipmentManagerClient.ConnectEquipmentByID(UUID,
		                                                                              DeviceIdentifier, ErrorDescription);

		If Result Then
			InputParameters  = Undefined;
			Output_Parameters = Undefined;

			Result = EquipmentManagerClient.RunCommand(DeviceIdentifier,
			                                                        "PrintXReport",
			                                                        InputParameters,
			                                                        Output_Parameters);

			If Not Result Then
				MessageText = NStr("en = 'An error occurred while getting the report from fiscal register.
				                   |%1.
				                   |Report on fiscal register is not formed.'");
				MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessageText, Output_Parameters[1]);
				CommonUseClientServer.MessageToUser(MessageText);
			EndIf;

			EquipmentManagerClient.DisableEquipmentById(UUID, DeviceIdentifier);
		Else
			MessageText = NStr("en = 'An error occurred when connecting the device.'") + Chars.LF + ErrorDescription;
			CommonUseClientServer.MessageToUser(MessageText);
		EndIf;
	EndIf;
	
EndProcedure

// Procedure - command handler "PrintReportWithoutClearing".
//
&AtClient
Procedure ReportPrintingWithoutBlankingExecute()
	
	If EquipmentManagerClient.RefreshClientWorkplace() Then
		// Device connection
		NotifyDescription = New NotifyDescription("ReportPrintingWithoutBlankingExecuteEnd", ThisObject);
		MessageText = "";
		EquipmentManagerClient.OfferSelectDevice(NotifyDescription, "FiscalRegister",
			NStr("en = 'Select a fiscal data recorder'"), 
			NStr("en = 'Fiscal data recorder is not connected'"));
			
		If Not IsBlankString(MessageText) Then
			MessageText = NStr("en = 'Print X report'") + MessageText;
			CommonUseClientServer.MessageToUser(MessageText);
		EndIf;
			
	Else
		MessageText = NStr("en = 'First, you need to select the work place of the current session peripherals.'");

		CommonUseClientServer.MessageToUser(MessageText);
	EndIf;
	
EndProcedure

// Procedure - command handler "CloseCashCRSession".
//
&AtClient
Procedure CloseCashCRSession(Command)
	
	ClearMessages();
	
	If Not ValueIsFilled(CashCR) Then
		Return;
	EndIf;
	
	Result = False;
	
	If Not IssuedReceiptsExist(CashCR) Then
		
		ErrorDescription = "";
		
		DocumentArray = CloseCashCRSessionAtServer(CashCR, ErrorDescription);
		
		If ValueIsFilled(ErrorDescription) Then
			MessageText = NStr("en = 'Session is closed on the fiscal register, but errors occurred when generating the retail sales report.
			                   |Additional description: %1.'");
			MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessageText, ErrorDescription);
			CommonUseClientServer.MessageToUser(MessageText);
		EndIf;
		
		// Show all resulting documents to user.
		For Each Document In DocumentArray Do
			
			OpenForm("Document.ShiftClosure.ObjectForm", New Structure("Key", Document));
			
		EndDo;
		
	ElsIf EquipmentManagerClient.RefreshClientWorkplace() Then
		
		// Device connection
		CashRegistersSettings = DriveReUse.CashRegistersGetParameters(CashCR);
		DeviceIdentifier = CashRegistersSettings.DeviceIdentifier;
		UseWithoutEquipmentConnection = CashRegistersSettings.UseWithoutEquipmentConnection;
	
		If DeviceIdentifier <> Undefined OR UseWithoutEquipmentConnection Then
			
			ErrorDescription = "";
			
			If Not UseWithoutEquipmentConnection Then
				
				Result = EquipmentManagerClient.ConnectEquipmentByID(
					UUID,
					DeviceIdentifier,
					ErrorDescription
				);
				
			EndIf;
			
			If Result OR UseWithoutEquipmentConnection Then
				
				If Not UseWithoutEquipmentConnection Then
					InputParameters  = Undefined;
					Output_Parameters = Undefined;
					
					Result = EquipmentManagerClient.RunCommand(
						DeviceIdentifier,
						"PrintZReport",
						InputParameters,
						Output_Parameters
					);
				EndIf;
				
				If Not Result AND Not UseWithoutEquipmentConnection Then
					
					MessageText = NStr("en = 'Error occurred when closing the session on the fiscal register.
					                   |""%1.""
					                   |Report on fiscal register is not formed.'");
					MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessageText, Output_Parameters[1]);
					CommonUseClientServer.MessageToUser(MessageText);
					
				Else
					
					DocumentArray = CloseCashCRSessionAtServer(CashCR, ErrorDescription);
					
					If ValueIsFilled(ErrorDescription)
					   AND UseWithoutEquipmentConnection Then
						
						CommonUseClientServer.MessageToUser(ErrorDescription);
						
					ElsIf ValueIsFilled(ErrorDescription)
						 AND Not UseWithoutEquipmentConnection Then
						
						MessageText = NStr("en = 'Session is closed on the fiscal register, but errors occurred when generating the retail sales report.
						                   |Additional description: %1.'");
						MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessageText, ErrorDescription);
						CommonUseClientServer.MessageToUser(MessageText);
						
					EndIf;
					
					// Show all resulting documents to user.
					For Each Document In DocumentArray Do
						
						OpenForm("Document.ShiftClosure.ObjectForm", New Structure("Key", Document));
						
					EndDo;
					
				EndIf;
				
				If Not UseWithoutEquipmentConnection Then
					
					EquipmentManagerClient.DisableEquipmentById(
						UUID,
						DeviceIdentifier
					);
					
				EndIf;
				
			Else
				
				MessageText = NStr("en = 'An error occurred when connecting the device.
				                   |Report is not printed and session is not closed on the fiscal register.
				                   |Additional description: %1.'");
				MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessageText, ErrorDescription);
				CommonUseClientServer.MessageToUser(MessageText);
				
			EndIf;
			
		EndIf;
		
	Else
		
		MessageText = NStr("en = 'First, you need to select the work place of the current session peripherals.'"
		);
		CommonUseClientServer.MessageToUser(MessageText);
		
	EndIf;
	
	InitializeNewReceipt();
	
	Items.List.Refresh();
	
	Notify("RefreshFormsAfterZReportIsDone");
	
EndProcedure

&AtServerNoContext
Function GetLatestClosedCashCRSession()

	Query = New Query;
	Query.Text = 
		"SELECT ALLOWED TOP 1
		|	ShiftClosure.Ref
		|FROM
		|	Document.ShiftClosure AS ShiftClosure
		|WHERE
		|	ShiftClosure.Posted
		|	AND ShiftClosure.CashCRSessionStatus <> &CashCRSessionStatus
		|
		|ORDER BY
		|	ShiftClosure.PointInTime DESC";
	
	Query.SetParameter("CashCRSessionStatus", Enums.ShiftClosureStatus.IsOpen);
	
	QueryResult = Query.Execute();
	
	Selection = QueryResult.Select();
	
	If Selection.Next() Then
		Return Selection.Ref;
	Else
		Return Documents.ShiftClosure.EmptyRef();
	EndIf;
	
EndFunction

&AtServer
Function EnterParametersForCancellingSalesSlip()
	
	// Preparation of the common parameters table
	ReceiptType = 0; //?(TypeOf(SalesSlip) = Type("DocumentRef.ProductReturn."), 1, 0);
	CommonParameters = New Array();
	CommonParameters.Add(ReceiptType);                //  1 - Receipt type
	CommonParameters.Add(True);                 //  2 - Fiscal receipt sign
	
	Return CommonParameters;
	
EndFunction

// Receipt cancellation procedure on fiscal register.
//
&AtClient
Function CancelSalesSlip(CashCR)
	
	ReceiptIsCanceled = False;
	
	ErrorDescription = "";
	
	CashRegistersSettings = DriveReUse.CashRegistersGetParameters(CashCR);
	DeviceIdentifierFR              = CashRegistersSettings.DeviceIdentifier;
	
	UseCashRegisterWithoutPeripheral = CashRegistersSettings.UseWithoutEquipmentConnection;
	
	If Not UsePeripherals 
		OR UseCashRegisterWithoutPeripheral Then
		ReceiptIsCanceled = True;
		Return ReceiptIsCanceled;
	EndIf;
	
	If EquipmentManagerClient.RefreshClientWorkplace() Then // Checks if the operator's workplace is specified
	
		
		If DeviceIdentifierFR <> Undefined Then
			
			// Connect FR
			Result = EquipmentManagerClient.ConnectEquipmentByID(ThisObject,
			                                                                              DeviceIdentifierFR,
			                                                                              ErrorDescription);
			
			If Result Then   
				
				// Prepare data
				InputParameters  = EnterParametersForCancellingSalesSlip();
				Output_Parameters = Undefined;
				
				Result = EquipmentManagerClient.RunCommand(
					DeviceIdentifierFR,
					"OpenCheck",
					InputParameters,
					Output_Parameters);
					
				If Result Then
					SessionNumberCR = Output_Parameters[0];
					SalesSlipNumber  = Output_Parameters[1]; 
					Output_Parameters = Undefined;
					Result = EquipmentManagerClient.RunCommand(
						DeviceIdentifierFR,
						"CancelCheck",
						InputParameters,
						Output_Parameters);
				EndIf;
				
				If Result Then
					ReceiptIsCanceled = True;
				Else
					MessageText = NStr("en = 'When cancellation receipt there was error.
					                   |Receipt is not cancelled on fiscal register.
					                   |Additional description: %1.'");
					MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessageText, Output_Parameters[1]);
					CommonUseClientServer.MessageToUser(MessageText);
				EndIf;
				
				// Disconnect FR
				EquipmentManagerClient.DisableEquipmentById(ThisObject, DeviceIdentifierFR);
				
			Else
				MessageText = NStr("en = 'An error occurred when connecting the device. Receipt is not cancelled on fiscal register.
				                   |Additional description: %1.'");
				MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessageText, ErrorDescription);
				CommonUseClientServer.MessageToUser(MessageText);
			EndIf;
			
		Else
			MessageText = NStr("en = 'Fiscal data recorder is not selected.'");
			CommonUseClientServer.MessageToUser(MessageText);
		EndIf;
		
	Else
		MessageText = NStr("en = 'First, you need to select the work place of the current session peripherals.'");
		CommonUseClientServer.MessageToUser(MessageText);
	EndIf;
	
	Return ReceiptIsCanceled;
	
EndFunction

// Procedure - command handler ReceiptCancellation form.
//
&AtClient
Procedure ReceiptCancellation(Command)
	
	NotifyDescription = New NotifyDescription("ReceiptCancellationEnd", ThisObject);
	ShowQueryBox(NotifyDescription,
	NStr("en = 'Do you want to cancel the last receipt?'"),
	QuestionDialogMode.YesNo,, DialogReturnCode.No);
	
EndProcedure

// Procedure - command handler ReceiptCancellation form. It is called after cancellation confirmation in issue window.
//
&AtClient
Procedure ReceiptCancellationEnd(Result, AdditionalParameters) Export

	If Result = DialogReturnCode.Yes Then
		CancelSalesSlip(CashCR);
	EndIf;

EndProcedure

// Procedure - command handler PrintCopyOnFiscalRegister form.
//
&AtClient
Procedure PrintCopyOnFiscalRegistrar(Command)
	
	If Not UsePeripherals Then
		
		MessageText = NStr("en = 'Cannot print the sales slip. Peripherals are not used.'");
		CommonUseClientServer.MessageToUser(MessageText);
		
		Return;
		
	EndIf;
	
	If EquipmentManagerClient.RefreshClientWorkplace() Then
		
		// Device selection FR
		NotifyDescription = New NotifyDescription("PrintCopyOnFiscalRegistrarEnd", ThisObject);
		MessageText = "";
		EquipmentManagerClient.OfferSelectDevice(NotifyDescription, "FiscalRegister",
			NStr("en = 'Select a fiscal data recorder'"),
			NStr("en = 'Fiscal data recorder is not connected'"));
		If Not IsBlankString(MessageText) Then
			MessageText = NStr("en = 'Print the last sales slip'") + MessageText;
			CommonUseClientServer.MessageToUser(MessageText);
		EndIf;
		
	Else
		MessageText = NStr("en = 'Fiscal data recorder is not connected'");
		CommonUseClientServer.MessageToUser(MessageText);
	EndIf;
	
EndProcedure

// Procedure - command handler PrintCopyOnFiscalRegister form. Performs receipt printing on FR.
//
&AtClient
Procedure PrintCopyOnFiscalRegistrarEnd(DeviceIdentifierFR, Parameters) Export
	
	If DeviceIdentifierFR <> Undefined Then 
		
		ErrorDescription  = "";
		// FR device connection
		ResultFR = EquipmentManagerClient.ConnectEquipmentByID(UUID,
			DeviceIdentifierFR,
			ErrorDescription);
			
		If ResultFR Then
			If Not IsBlankString(glPeripherals.LastSlipReceipt) Then
				InputParameters = New Array();
				InputParameters.Add(glPeripherals.LastSlipReceipt);
				Output_Parameters = Undefined;
				
				ResultFR = EquipmentManagerClient.RunCommand(DeviceIdentifierFR,
					"PrintText",
					InputParameters,
				    Output_Parameters);
					
				If Not ResultFR Then
					MessageText = NStr(
						"en = 'An error occurred when printing a sales slip: ""%1.""'"); 
					MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessageText, Output_Parameters[1]);
					CommonUseClientServer.MessageToUser(MessageText);
				EndIf;
			EndIf;
			
			// FR device disconnect
			EquipmentManagerClient.DisableEquipmentById(UUID,
			                                                                 DeviceIdentifierFR);
		Else
			MessageText = NStr("en = 'When fiscal registrar connection there was error: ""%1.""
			                   |Sales slip is not printed.'");
			MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessageText, ErrorDescription);
			CommonUseClientServer.MessageToUser(MessageText);
		EndIf;
		
	EndIf;

EndProcedure

#EndRegion

#Region ProceduresAndFunctionsForFormAppearanceManagement

// Procedure sets mode Only view.
//
Procedure SetModeReadOnly()
	
	ReadOnly = True; // Receipt is issued. Change information is forbidden.
	
	Items.AcceptPayment.Enabled					= False;
	Items.PricesAndCurrency.Enabled				= False;
	Items.InventoryWeight.Enabled				= False;
	Items.InventorySelect.Enabled				= False;
	Items.InventoryImportDataFromDCT.Enabled	= False;
	
EndProcedure

// Procedure sets the receipt print availability.
//
&AtServer
Procedure SetEnabledOfReceiptPrinting()
	
	If Object.Status = Enums.SalesSlipStatus.ProductReserved
	 OR Object.CashCR.UseWithoutEquipmentConnection
	 OR ControlAtWarehouseDisabled Then
		Items.AcceptPayment.Enabled = True;
	Else
		Items.AcceptPayment.Enabled = True; // False;
	EndIf;
	
EndProcedure

// Procedure sets button headings and key combinations for form commands.
//
&AtServer
Procedure ConfigureButtonsAndMenuCommands()
	
	If Not ValueIsFilled(CWPSetting) Then
		// We issue message in procedure "FillFastGoods()".
		Return;
	EndIf;
	
	DontShowOnOpenCashdeskChoiceForm = CWPSetting.DontShowOnOpenCashdeskChoiceForm;
	
	For Each CurrentSettingCommandButtons In CWPSetting.LowerBarButtons Do
		Try
			
			If CurrentSettingCommandButtons.ButtonName = "ProductsSearchValue" Then
				If ValueIsFilled(CurrentSettingCommandButtons.Key) Then
					Items.ProductsSearchValue.Shortcut	= New Shortcut(Key[CurrentSettingCommandButtons.Key], CurrentSettingCommandButtons.Alt,
						CurrentSettingCommandButtons.Ctrl, CurrentSettingCommandButtons.Shift);
					Items.ProductsSearchValue.InputHint	= StringFunctionsClientServer.SubstituteParametersInString(
						NStr("en = 'Enter name, code or SKU %1'"),
						ShortcutPresentation(Items.ProductsSearchValue.Shortcut, False));
				Else
					Items.ProductsSearchValue.Shortcut	= New Shortcut(Key.None);
					Items.ProductsSearchValue.InputHint	= 
						NStr("en = 'Enter name, code or SKU'");
				EndIf;
			Else
				CurrentButton	= Items[CurrentSettingCommandButtons.ButtonName];
				CurrentCommand	= Commands[CurrentSettingCommandButtons.CommandName];
				
				If ValueIsFilled(CurrentSettingCommandButtons.ButtonName) Then
					
					CurrentButton.Title = CurrentSettingCommandButtons.ButtonTitle;
					
					If CurrentSettingCommandButtons.ButtonName = "ShowJournal" Then
						Items.SwitchJournalQuickProducts.ChoiceList.Get(0).Presentation = CurrentSettingCommandButtons.ButtonTitle;
					ElsIf CurrentSettingCommandButtons.ButtonName = "ShowQuickSales" Then
						Items.SwitchJournalQuickProducts.ChoiceList.Get(1).Presentation = CurrentSettingCommandButtons.ButtonTitle;
					ElsIf CurrentSettingCommandButtons.ButtonName = "ShowMyPettyCash" Then
						Items.SwitchJournalQuickProducts.ChoiceList.Get(2).Presentation = CurrentSettingCommandButtons.ButtonTitle;
					EndIf;
					
				EndIf;
				
				If ValueIsFilled(CurrentSettingCommandButtons.Key) Then
					CurrentCommand.Shortcut = New Shortcut(Key[CurrentSettingCommandButtons.Key], CurrentSettingCommandButtons.Alt,
						CurrentSettingCommandButtons.Ctrl, CurrentSettingCommandButtons.Shift);
				Else
					CurrentCommand.Shortcut = New Shortcut(Key.None);
				EndIf;
			EndIf;
			
		Except
			CommonUseClientServer.MessageToUser(StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Error is occurred when button and menu command setting. %1.'"),
				ErrorDescription()));
		EndTry;
	EndDo;
	
EndProcedure

// Procedure - event handler Click item GroupbyExpandSalesSidePanel form.
//
&AtClient
Procedure GroupbyExpandSalesSidePanelClick(Item)
	
	GroupbyExpandSideSalePanelClickAtServer();
	
EndProcedure

// Procedure - event handler Click item GroupbyExpandSalesSidePanel on server.
//
&AtServer
Procedure GroupbyExpandSideSalePanelClickAtServer()
	
	If Items.ExpandGroupbySalesSidePanel.Title = ">>" Then
		Items.SidePanelSales.Visible = False;
		Items.ExpandGroupbySalesSidePanel.Title = "<<";
		Items.ExpandGroupbySalesSidePanel.Picture = PictureLib.CWP_ExpandAdditionalPanel;
	Else
		Items.SidePanelSales.Visible = True;
		Items.ExpandGroupbySalesSidePanel.Title = ">>";
		Items.ExpandGroupbySalesSidePanel.Picture = PictureLib.CWP_MinimizeAdditionalPanel;
	EndIf;
	
EndProcedure

// Procedure - event handler Click item GroupbySidePanelRefunds form.
//
&AtClient
Procedure GroupbySidePanelRefundsClick(Item)
	
	GroupbySidePanelRefundsClickAtServer();
	
EndProcedure

// Procedure - event handler Click item GroupbySidePanelRefunds on server.
//
&AtServer
Procedure GroupbySidePanelRefundsClickAtServer()
	
	If Items.GroupbySidePanelRefunds.Title = ">>" Then
		Items.SidePanelRefunds.Visible = False;
		Items.GroupbySidePanelRefunds.Title = "<<";
		Items.GroupbySidePanelRefunds.Picture = PictureLib.CWP_ExpandAdditionalPanel;
	Else
		Items.SidePanelRefunds.Visible = True;
		Items.GroupbySidePanelRefunds.Title = ">>";
		Items.GroupbySidePanelRefunds.Picture = PictureLib.CWP_MinimizeAdditionalPanel;
	EndIf;
	
EndProcedure

// Procedure changes page visible on which DEAL displays.
//
&AtServer
Procedure ShowHideDealAtServer(Show = True, Check = False)
	
	If Not Check OR Not Items.PagesDataOnRowAndChange.CurrentPage = Items.PageDataOnRow Then
		ChangeRow = "Deal: "+Change+" "+Object.DocumentCurrency;
		
		If Show Then
			Items.PagesDataOnRowAndChange.CurrentPage = Items.PageChange;
		Else
			Items.PagesDataOnRowAndChange.CurrentPage = Items.PageDataOnRow;
		EndIf;
	EndIf;
	
EndProcedure

// Procedure changes page visible on which DEAL displays.
//
&AtClient
Procedure ShowHideDealAtClient()
	
	If Not Items.PagesDataOnRowAndChange.CurrentPage = Items.PageDataOnRow Then
		ShowHideDealAtServer(False);
	EndIf;
	
EndProcedure

#EndRegion

#Region ProceduresFormEventsHandlers

&AtClient
Procedure ChoiceProcessing(SelectedValue, ChoiceSource)
	
	If ChoiceSource.FormName = "CommonForm.ProductGLAccounts" Then
		GLAccountsChoiceProcessingAtClient(SelectedValue);
	EndIf;
	
EndProcedure

// Procedure - OnCreateAtServer form event handler.
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
	
	// CWP
	CashCR = Parameters.CashCR;
	If Not ValueIsFilled(CashCR) Then
		Message = New UserMessage();
		Message.Text = NStr("en = 'Cash register is not determined for the user.'");
		Message.Message();
		Cancel = True;
		Return;
	EndIf;
	
	User = Users.CurrentUser();
	
	PreviousCashCR = CashCR;
	CashCRUseWithoutEquipmentConnection = CashCR.UseWithoutEquipmentConnection;
	
	Object.POSTerminal = Parameters.POSTerminal;
	
	StructureStateCashCRSession = GetCashCRSessionStateAtServer(CashCR);
	FillPropertyValues(Object, StructureStateCashCRSession);
	BalanceInCashier = StructureStateCashCRSession.CashInPettyCash;
	BalanceInCashierRow = ""+BalanceInCashier;
	
	Object.CashCR = CashCR;
	Object.StructuralUnit = CashCR.StructuralUnit;
	Object.PriceKind = CashCR.StructuralUnit.RetailPriceKind;
	If Not ValueIsFilled(Object.DocumentCurrency) Then
		Object.DocumentCurrency = CashCR.CashCurrency;
	EndIf;
	Object.Company = Object.CashCR.Owner;
	Object.Department = Object.CashCR.Department;
	Object.Responsible = DriveReUse.GetValueByDefaultUser(User, "MainResponsible");
	// End CWP
	
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
	
	Items.RemoveReservation.Visible = Not ControlAtWarehouseDisabled;
	
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
	
	SetAccountingPolicyValues();

	ForeignExchangeAccounting = Constants.ForeignExchangeAccounting.Get();
	
	LabelStructure = New Structure;
	LabelStructure.Insert("PriceKind",						Object.PriceKind);
	LabelStructure.Insert("DiscountKind",					Object.DiscountMarkupKind);
	LabelStructure.Insert("DocumentCurrency",				Object.DocumentCurrency);
	LabelStructure.Insert("SettlementsCurrency",			Object.DocumentCurrency);
	LabelStructure.Insert("ExchangeRate",					ExchangeRate);
	LabelStructure.Insert("AmountIncludesVAT",				Object.AmountIncludesVAT);
	LabelStructure.Insert("ForeignExchangeAccounting",		ForeignExchangeAccounting);
	LabelStructure.Insert("RateNationalCurrency",			RateNationalCurrency);
	LabelStructure.Insert("VATTaxation",					Object.VATTaxation);
	LabelStructure.Insert("DiscountCard",					Object.DiscountCard);
	LabelStructure.Insert("DiscountPercentByDiscountCard",	Object.DiscountPercentByDiscountCard);
	
	PricesAndCurrency = GenerateLabelPricesAndCurrency(LabelStructure);
	
	CashCRUseWithoutEquipmentConnection = Object.CashCR.UseWithoutEquipmentConnection;
	
	SetEnabledOfReceiptPrinting();
	
	Items.InventoryAmountDiscountsMarkups.Visible = Constants.UseManualDiscounts.Get();
	
	If Object.Status = Enums.SalesSlipStatus.Issued
	AND Not CashCRUseWithoutEquipmentConnection Then
		SetModeReadOnly();
	EndIf;
	
	// Price accessibility setup for editing.
	AllowedEditDocumentPrices = DriveAccessManagementReUse.AllowedEditDocumentPrices();
	SaleFromWarehouse = Object.StructuralUnit.StructuralUnitType = Enums.BusinessUnitsTypes.Warehouse;
	
	Items.InventoryPrice.ReadOnly 					= Not AllowedEditDocumentPrices OR Not SaleFromWarehouse;
	Items.InventoryAmount.ReadOnly 					= Not AllowedEditDocumentPrices OR Not SaleFromWarehouse; 
	Items.InventoryDiscountPercentMargin.ReadOnly  	= Not AllowedEditDocumentPrices;
	Items.InventoryAmountDiscountsMarkups.ReadOnly 	= Not AllowedEditDocumentPrices;
	Items.InventoryVATAmount.ReadOnly 				= Not AllowedEditDocumentPrices OR Not SaleFromWarehouse;
	
	// StructuralUnit - blank can't be
	StructuralUnitType = Object.StructuralUnit.StructuralUnitType;
	
	// AutomaticDiscounts.
	AutomaticDiscountsOnCreateAtServer();
	
	// CWP
	SessionIsOpen = Enums.ShiftClosureStatus.IsOpen;
	
	List.Parameters.SetParameterValue("CashCR", CashCR);
	List.Parameters.SetParameterValue("WithoutConnectingEquipment", CashCRUseWithoutEquipmentConnection);
	List.Parameters.SetParameterValue("Status", Enums.ShiftClosureStatus.IsOpen);
	List.Parameters.SetParameterValue("ChoiceOnStatuses", True);
	List.Parameters.SetParameterValue("FilterByChange", False);
	List.Parameters.SetParameterValue("CashCRSession", Documents.ShiftClosure.EmptyRef());
	
	SalesSlipList.Parameters.SetParameterValue("CashCR", CashCR);
	SalesSlipList.Parameters.SetParameterValue("WithoutConnectingEquipment", CashCRUseWithoutEquipmentConnection);
	SalesSlipList.Parameters.SetParameterValue("Status", Enums.ShiftClosureStatus.IsOpen);
	SalesSlipList.Parameters.SetParameterValue("ChoiceOnStatuses", True);
	SalesSlipList.Parameters.SetParameterValue("FilterByChange", False);
	SalesSlipList.Parameters.SetParameterValue("CashCRSession", Documents.ShiftClosure.EmptyRef());
	
	SalesSlipListForReturn.Parameters.SetParameterValue("CashCR", CashCR);
	SalesSlipListForReturn.Parameters.SetParameterValue("WithoutConnectingEquipment", CashCRUseWithoutEquipmentConnection);
	SalesSlipListForReturn.Parameters.SetParameterValue("Status", Enums.ShiftClosureStatus.IsOpen);
	SalesSlipListForReturn.Parameters.SetParameterValue("ChoiceOnStatuses", True);
	SalesSlipListForReturn.Parameters.SetParameterValue("FilterByChange", False);
	SalesSlipListForReturn.Parameters.SetParameterValue("CashCRSession", Documents.ShiftClosure.EmptyRef());
	
	// StructuralUnit - blank can't be
	StructuralUnitType = Object.StructuralUnit.StructuralUnitType;
	
	GenerateTitle(StructureStateCashCRSession);
	
	// Fast goods and settings buttons and menu commands.
	FillFastGoods(True);
	ConfigureButtonsAndMenuCommands();
	
	ImportantButtonsColor = StyleColors.UnavailableCellTextColor;
	UnavailableButtonColor = StyleColors.UnavailableButton;
	
	// Period kinds.
	ForCurrentShift = Enums.CWPPeriodTypes.ForCurrentShift;
	ForUserDefinedPeriod = Enums.CWPPeriodTypes.ForUserDefinedPeriod;
	ForYesterday = Enums.CWPPeriodTypes.ForYesterday;
	ForEntirePeriod = Enums.CWPPeriodTypes.ForEntirePeriod;
	ForPreviousShift = Enums.CWPPeriodTypes.ForPreviousShift;
	
	FillPeriodKindLists();
	
	SetPeriodAtServer(ForCurrentShift, "SalesSlipList");
	SetPeriodAtServer(ForCurrentShift, "SalesSlipListForReturn");
	SetPeriodAtServer(ForCurrentShift, "List");
	
	SwitchJournalQuickProducts = 1;
	
	StructureStateCashCRSession = GetCashCRSessionStateAtServer(CashCR);
	UpdateLabelVisibleTimedOutOver24Hours(StructureStateCashCRSession);
	
	ProductsTypeInventory = Enums.ProductsTypes.InventoryItem;
	ProductsTypeService = Enums.ProductsTypes.Service;
	// End CWP
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// Serial numbers
	UseSerialNumbersBalance = WorkWithSerialNumbers.UseSerialNumbersBalance();
	
EndProcedure

// Procedure - OnCreateAtServer event handler.
//
&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	GetChoiceListOfPaymentCardKinds();
	
EndProcedure

// Procedure - OnOpen form event handler.
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
	
	// AutomaticDiscounts Display the message about discount calculation when user clicks the "Post and close" button or
	// closes the form by the cross with saving the changes.
	If UseAutomaticDiscounts AND DiscountsCalculatedBeforeWrite Then
		ShowUserNotification(NStr("en = 'Update:'"), 
		GetURL(Object.Ref), 
		String(Object.Ref) + NStr("en = '. The automatic discounts are calculated.'"), 
		PictureLib.Information32);
	EndIf;
	// End AutomaticDiscounts
	
	If NOT Exit Then
		CashierWorkplaceServerCall.UpdateCashierWorkplaceSettings(CWPSetting, DontShowOnOpenCashdeskChoiceForm);
	EndIf;
	// CWP
		
	// Peripherals
	EquipmentManagerClientOverridable.StartDisablingEquipmentOnCloseForm(ThisForm);
	// End Peripherals
	
EndProcedure

// Procedure - event handler BeforeWrite form.
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
	
	Notify("RefreshSalesSlipDocumentsListForm");
	
EndProcedure

// Procedure - event handler AfterWriteAtServer form.
//
&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	// AutomaticDiscounts
	If RefreshImageAutoDiscountsAfterWrite Then
		Items.InventoryCalculateDiscountsMarkups.Picture = PictureLib.Refresh;
		RefreshImageAutoDiscountsAfterWrite = False;
	EndIf;
	// End AutomaticDiscounts
	
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
		
	EndIf;
	
	If EventName = "RefreshSalesSlipDocumentsListForm" Then
		Items.List.Refresh();
		
		StructureStateCashCRSession = GetCashCRSessionStateAtServer(CashCR);
		BalanceInCashier = StructureStateCashCRSession.CashInPettyCash;
		BalanceInCashierRow = ""+BalanceInCashier;
	EndIf;
	
	If EventName = "ProductsIsAddedFromCWP" AND ValueIsFilled(Parameter) Then
		CurrentData = Items.Inventory.CurrentData;
		If CurrentData <> Undefined Then
			If Not ValueIsFilled(CurrentData.Products) Then
				CurrentData.Products = Parameter;
				ProductsOnChange(CurrentData);
				RecalculateDocumentAtClient();
			EndIf;
		EndIf;
	EndIf;
	
	If EventName = "CWPSettingChanged" Then
		If CWPSetting = Parameter Then
			FillFastGoods();
			ConfigureButtonsAndMenuCommands();
		EndIf;
	EndIf;
	
	If EventName = "CWP_Write_CreditNote" Then
		Items.CreateCreditNote.TextColor = ?(ReceiptIsNotShown, UnavailableButtonColor, New Color);
		Items.CreateCPVBasedOnReceipt.TextColor = New Color;
		CreditNote = Parameter.Ref;
		DocumentNumber = ObjectPrefixationClientServer.GetNumberForPrinting(Parameter.Number, True, True);
		TitlePresentation = NStr("en = 'Credit note'");
		Items.DecorationCreditNote.Title = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = '%1 #%2 dated %3'"),
			TitlePresentation,
			DocumentNumber,
			Format(Parameter.Date, "DLF=D"));
		Items.DecorationCreditNote.Visible = True;
		AttachIdleHandler("SalesSlipListOnActivateRowIdleProcessing", 0.3, True);
	ElsIf EventName = "CWP_Record_CPV" Then
		Items.CreateCPVBasedOnReceipt.TextColor = ?(ReceiptIsNotShown, UnavailableButtonColor, New Color);
		Items.CreateGoodsReturn.TextColor = New Color;
		CPV = Parameter.Ref;
		DocumentNumber = ObjectPrefixationClientServer.GetNumberForPrinting(Parameter.Number, True, True);
		Items.DecorationCPV.Title = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Cash voucher #%1 dated %2.'"),
			TrimAll(DocumentNumber),
			Format(Parameter.Date, "DLF=D"));
		Items.DecorationCPV.Visible = True;
	ElsIf EventName = "CWP_Write_GoodsReturn" Then
		Items.CreateGoodsReturn.TextColor = ?(ReceiptIsNotShown, UnavailableButtonColor, New Color);
		GoodsReturn = Parameter.Ref;
		DocumentNumber = ObjectPrefixationClientServer.GetNumberForPrinting(Parameter.Number, True, True);
		TitlePresentation = NStr("en = 'Goods return'");
		Items.DecorationGoodsReturn.Title = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = '%1 #%2 dated %3'"),
			TitlePresentation,
			DocumentNumber,
			Format(Parameter.Date, "DLF=D"));
		Items.DecorationGoodsReturn.Visible = True;
		AttachIdleHandler("SalesSlipListOnActivateRowIdleProcessing", 0.3, True);
		
	ElsIf EventName = "CWP_Write_ProductReturn" Then
		SalesSlipForReturn = Parameter.Ref;
		DocumentNumber = ObjectPrefixationClientServer.GetNumberForPrinting(Parameter.Number, True, True);
		Items.DecorationSalesSlipForReturn.Title = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Return slip #%1 dated %2.'"),
			DocumentNumber,
			Format(Parameter.Date, "DLF=D"));
		Items.CreateSalesSlipForReturn.TextColor = UnavailableButtonColor;
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
	
	If EventName = "RefreshFormsAfterZReportIsDone" Then
		UpdateLabelVisibleTimedOutOver24Hours();
	EndIf;
	
EndProcedure

&AtServer
Procedure UpdateLabelVisibleTimedOutOver24Hours(StructureStateCashCRSession = Undefined)

	Date = CurrentSessionDate();
	
	If StructureStateCashCRSession = Undefined Then
		StructureStateCashCRSession = GetCashCRSessionStateAtServer(CashCR);
	EndIf;
	
	SetLabelVisible = False;
	If StructureStateCashCRSession.SessionIsOpen Then
		MessageText = NStr("en = 'Register shift is opened'");
		If Not Documents.ShiftClosure.SessionIsOpen(Object.CashCRSession, Date, MessageText) Then
			If Find(MessageText, "24") > 0 Then
				Items.LabelSinceChangeOpeningMore24Hours.Title = MessageText;
				SetLabelVisible = True;
			EndIf;
		EndIf;
	EndIf;
	Items.LabelSinceChangeOpeningMore24Hours.Visible = SetLabelVisible;

EndProcedure

// Procedure - event handler BeforeImportDataFromSettingsAtServer.
//
&AtServer
Procedure BeforeImportDataFromSettingsAtServer(Settings)
	
	ListForSaving = Settings.Get("ListForSettingSaving");
	If TypeOf(ListForSaving) = Type("ValueList") Then
		// Period recovery.
		PeriodKind = ListForSaving.Get(0).Value;
		If PeriodKind = ForUserDefinedPeriod Then
			StartDate = ListForSaving.Get(1).Value;
			EndDate = ListForSaving.Get(2).Value;
			If PeriodKind <> CatalogPeriodKindTransfer OR Items.List.Period.StartDate <> StartDate OR Items.List.Period.EndDate <> EndDate Then
				SetPeriodAtServer(PeriodKind, "List", New StandardPeriod(StartDate, EndDate));
			EndIf;
		ElsIf PeriodKind <> CatalogPeriodKindTransfer Then
			SetPeriodAtServer(PeriodKind, "List");
		EndIf;
		
		PeriodKind = ListForSaving.Get(3).Value;
		If PeriodKind = ForUserDefinedPeriod Then
			StartDate = ListForSaving.Get(4).Value;
			EndDate = ListForSaving.Get(5).Value;
			If PeriodKind <> SalesSlipPeriodTransferKind OR Items.SalesSlipList.Period.StartDate <> StartDate OR Items.SalesSlipList.Period.EndDate <> EndDate Then
				SetPeriodAtServer(PeriodKind, "SalesSlipList", New StandardPeriod(StartDate, EndDate));
			EndIf;
		ElsIf PeriodKind <> SalesSlipPeriodTransferKind Then
			SetPeriodAtServer(PeriodKind, "SalesSlipList");
		EndIf;
		
		PeriodKind = ListForSaving.Get(6).Value;
		If PeriodKind = ForUserDefinedPeriod Then
			StartDate = ListForSaving.Get(7).Value;
			EndDate = ListForSaving.Get(8).Value;
			If PeriodKind <> SalesSlipPeriodKindForReturnTransfer OR Items.SalesSlipListForReturn.Period.StartDate <> StartDate OR Items.SalesSlipListForReturn.Period.EndDate <> EndDate Then
				SetPeriodAtServer(PeriodKind, "SalesSlipListForReturn", New StandardPeriod(StartDate, EndDate));
			EndIf;
		ElsIf PeriodKind <> SalesSlipPeriodKindForReturnTransfer Then
			SetPeriodAtServer(PeriodKind, "SalesSlipListForReturn");
		EndIf;
		
		// Recovery current page.
		CurrentPageName = ListForSaving.Get(9).Value;
		If ValueIsFilled(CurrentPageName) Then
			Items.GroupSalesAndReturn.CurrentPage = Items[CurrentPageName];
		EndIf;
	EndIf;
	
EndProcedure

// Procedure - event handler OnSaveDataInSettingsAtServer.
//
&AtServer
Procedure OnSaveDataInSettingsAtServer(Settings)
	
	ListForSettingSaving = New ValueList;
	// Period settings. Items 0 - 8.
	ListForSettingSaving.Add(CatalogPeriodKindTransfer);
	ListForSettingSaving.Add(Items.List.Period.StartDate);
	ListForSettingSaving.Add(Items.List.Period.EndDate);
	ListForSettingSaving.Add(SalesSlipPeriodTransferKind);
	ListForSettingSaving.Add(Items.SalesSlipList.Period.StartDate);
	ListForSettingSaving.Add(Items.SalesSlipList.Period.EndDate);
	ListForSettingSaving.Add(SalesSlipPeriodKindForReturnTransfer);
	ListForSettingSaving.Add(Items.SalesSlipListForReturn.Period.StartDate);
	ListForSettingSaving.Add(Items.SalesSlipListForReturn.Period.EndDate);
	// Current page. Item 9.
	ListForSettingSaving.Add(Items.GroupSalesAndReturn.CurrentPage.Name);
	
	Settings.Insert("ListForSettingSaving", ListForSettingSaving);
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

// Procedure - event handler Action of the Pick command
//
&AtClient
Procedure Select(Command)
	
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

// Procedure - command handler ShowLog form. Workaround for quick keys implementation for switch.
//
&AtClient
Procedure ShowJournal(Command)
	
	SwitchJournalQuickProducts = 1;
	SwitchJournalQuickProductsOnChange(Items.SwitchJournalQuickProducts);
	
EndProcedure

// Procedure - command handler ShowQuickSales form. Workaround for quick keys implementation for switch.
//
&AtClient
Procedure ShowQuickSales(Command)
	
	SwitchJournalQuickProducts = 2;
	SwitchJournalQuickProductsOnChange(Items.SwitchJournalQuickProducts);
	
EndProcedure

// Procedure - command handler ShowMyCash form. Workaround for quick keys implementation for switch.
//
&AtClient
Procedure ShowMyCashRegister(Command)
	
	SwitchJournalQuickProducts = 3;
	SwitchJournalQuickProductsOnChange(Items.SwitchJournalQuickProducts);
	
EndProcedure

// Procedure - command handler FastGoodsSetting form
//
&AtClient
Procedure QuickProductsSettings(Command)
	
	If ValueIsFilled(CWPSetting) Then
		ParametersStructure = New Structure("Key", CWPSetting);
		OpenForm("Catalog.CashierWorkplaceSettings.ObjectForm", ParametersStructure, ThisObject);
	Else
		Message = New UserMessage;
		Message.Text = NStr("en = 'CWP setting is not selected.'");
		Message.Message();
	EndIf;
	
EndProcedure

&AtClient
Procedure CreateCreditNote(Command)
	
	If ReceiptIsNotShown Then
		OpenForm("Document.CreditNote.ObjectForm", New Structure("CWP, OperationKindReturn", True, True), ThisObject, UUID);
	Else
		CurrentData = Items.SalesSlipList.CurrentData;
		If CurrentData <> Undefined Then
			OpenForm("Document.CreditNote.ObjectForm", New Structure("Basis, CWP", CurrentData.Ref, True), ThisObject, UUID);
		Else
			MessageText = NStr("en = 'Sales slip is not selected'");
			CommonUseClientServer.MessageToUser(MessageText,, "SalesSlipList");
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure CreateGoodsReturn(Command)
	
	If ReceiptIsNotShown Then
		OpenForm("Document.GoodsReturn.ObjectForm", New Structure("CWP, OperationKindReturn", True, True), ThisObject, UUID);
	Else
		If ValueIsFilled(CreditNote) Then
			OpenForm("Document.GoodsReturn.ObjectForm", New Structure("Basis, CWP", CreditNote, True), ThisObject, UUID);
		Else
			MessageText = NStr("en = 'Credit note is not created'");
			CommonUseClientServer.MessageToUser(MessageText);
		EndIf;
	EndIf;
	
EndProcedure

// Procedure - command handler CreateSalesSlipForReturn form
//
&AtClient
Procedure CreateSalesSlipForReturn(Command)
	
	If Not SalesSlipForReturn.IsEmpty() Then
		Message = New UserMessage;
		Message.Text = NStr("en = 'Return slip is already created.'");
		Message.Field = "Items.CreateSalesSlipForReturn";
		Message.SetData(ThisObject);
		Message.Message();
	Else
		CurrentData = Items.SalesSlipList.CurrentData;
		If CurrentData <> Undefined Then
			OpenForm("Document.ProductReturn.ObjectForm", New Structure("Basis", CurrentData.Ref), ThisObject);
		Else
			Message = New UserMessage;
			Message.Text = NStr("en = 'Sales slip is not selected.'");
			Message.Field = "SalesSlipList";
			Message.Message();
		EndIf;
	EndIf;
	
EndProcedure

// Procedure - command handler CreateCPVBasedOnCreditNote form
//
&AtClient
Procedure CreateCPVBasedOnReceipt(Command)
	
	If CreditNote.IsEmpty() Then
		MessageText = NStr("en = 'First of all it is necessary to create the credit note.'");
		CommonUseClientServer.MessageToUser(MessageText,, "CreateDebitInvoiceForReturn");
	Else
		CurrentData = Items.SalesSlipList.CurrentData;
		If CurrentData <> Undefined OR ReceiptIsNotShown Then
			OpenForm("Document.CashVoucher.ObjectForm", New Structure("Basis, CWP", CreditNote, True), ThisObject, UUID);
		Else
			MessageText = NStr("en = 'Sales slip is not selected'");
			CommonUseClientServer.MessageToUser(MessageText,, "SalesSlipList");
		EndIf;
	EndIf;

EndProcedure

// Procedure - command handler AcceptPayment form.
//
&AtClient
Procedure Pay(Command)
	
	StructureStateCashCRSession = GetCashCRSessionStateAtServer(CashCR);
	If Not StructureStateCashCRSession.SessionIsOpen Then
		CashCRSessionOpen();
		StructureStateCashCRSession = GetCashCRSessionStateAtServer(CashCR);
		
		Object.CashCRSession = StructureStateCashCRSession.CashCRSession;
	EndIf;
	
	If ValueIsFilled(StructureStateCashCRSession.CashCRSessionStatus) Then
		FillPropertyValues(Object, StructureStateCashCRSession,, "Responsible, Department");
	EndIf;
	
	If UseAutomaticDiscounts Then
		If Object.Inventory.Count() > 0 AND Not Object.DiscountsAreCalculated Then
			CalculateDiscountsMarkups(Commands.CalculateDiscountsMarkups);
		EndIf;
	EndIf;
	
	If Object.Inventory.Count() = 0 Or Object.Inventory.Total("Amount") = 0 Then
		CommonUseClientServer.MessageToUser(
			NStr("en = 'Amount payable = 0'"),,
			"Object.DocumentAmount");
		Return;
	EndIf;
	
	If Not ControlAtWarehouseDisabled Then
		If Not ReserveAtServer() Then
			CommonUseClientServer.MessageToUser(NStr("en = 'Cannot do reservation.'"));
			Return;
		Else
			FillInDetailsForTSInventoryAtClient();
		EndIf;
		Notify("RefreshSalesSlipDocumentsListForm");
	EndIf;
	
	// We will check that there were not goods with the zero price!
	ContinuePaymentReception = True;
	For Each CurrentRow In Object.Inventory Do
		If CurrentRow.Price = 0 Then
			Message = New UserMessage;
			Message.Text = NStr("en = 'The string is missing price.'");
			Message.Field = "Object.Inventory["+(CurrentRow.LineNumber-1)+"].Price";
			Message.Message();
			
			ContinuePaymentReception = False;
		EndIf;
		If CurrentRow.Quantity = 0 Then
			Message = New UserMessage;
			Message.Text = NStr("en = 'In string is missing quantity.'");
			Message.Field = "Object.Inventory["+(CurrentRow.LineNumber-1)+"].Quantity";
			Message.Message();
			
			ContinuePaymentReception = False;
		EndIf;
		If CurrentRow.Products.IsEmpty() Then
			Message = New UserMessage;
			Message.Text = NStr("en = 'The string is missing product.'");
			Message.Field = "Object.Inventory["+(CurrentRow.LineNumber-1)+"].Products";
			Message.Message();
			
			ContinuePaymentReception = False;
		EndIf;
	EndDo;
	
	If Not ContinuePaymentReception Then
		Return;
	EndIf;
	
	Notification = New NotifyDescription("PayEnd", ThisForm);
	
	ParametersStructure = New Structure("Object, PaymentWithPaymentCards, DocumentAmount, DocumentCurrency, CardKinds, CashCR, UsePeripherals, POSTerminal, FormID", 
		Object,
		Object.PaymentWithPaymentCards,
		Object.DocumentAmount,
		Object.DocumentCurrency,
		Items.PaymentByChargeCardTypeCards.ChoiceList,
		CashCR,
		UsePeripherals,
		Object.POSTerminal,
		UUID);
		
		
	OpenForm("Document.SalesSlip.Form.PaymentForm", ParametersStructure,,,,,Notification);
	
EndProcedure

// Procedure updates the form main attribute data after closing payment form.
//
&AtServer
Procedure UpdateDocumentAtServer(ObjectParameter)
	
	ValueToFormData(FormDataToValue(ObjectParameter, Type("DocumentObject.SalesSlip")), Object);
	
	If Not Object.Ref.IsEmpty() Then
		Try
			LockDataForEdit(Object.Ref, , UUID);
		Except
			//
		EndTry;
	EndIf;
	
	For Each CurrentRow In Object.Inventory Do
		SetDescriptionForTSRowsInventoryAtServer(CurrentRow);
	EndDo;
	
EndProcedure

// Procedure - command handler AcceptPayment. It is called after closing payment form.
//
&AtClient
Procedure PayEnd(Result, Parameters) Export
	
	If TypeOf(Result) = Type("Structure") Then
		
		// Payments were made by plastic cards or cancel payments by plastic cards and in this case the document was written or posted.
		UpdateDocumentAtServer(Result.Object);
		
		If Result.Button = "IssueReceipt" Then
		
			Object.CashReceived = Result.Cash;
			
			Change = Format(Result.Deal, "NFD=2");
			
			RecalculateDocumentAtClient();
			
			GenerateSalesReceipt = Result.GenerateSalesReceipt;
			GenerateSimplifiedTaxInvoice = Result.GenerateSimplifiedTaxInvoice;
			
			IssueReceiptExecute(Commands.IssueReceipt, GenerateSalesReceipt, GenerateSimplifiedTaxInvoice);
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Procedure - command handler PrintSalesReceipt form
//
&AtClient
Procedure PrintSalesReceipt(Command)
	
	ReceiptsCRArray = New Array;
	SalesSlipArrayForReturn = New Array;
	ThereAreRetailSaleReports = False;
	
	For Each ListRow In Items.List.SelectedRows Do
		If ListRow <> Undefined Then
			If TypeOf(ListRow) = Type("DocumentRef.SalesSlip") Then
				ReceiptsCRArray.Add(ListRow);
			ElsIf TypeOf(ListRow) = Type("DocumentRef.ProductReturn") Then
				SalesSlipArrayForReturn.Add(ListRow);
			Else
				ThereAreRetailSaleReports = True;
			EndIf;
		EndIf;
	EndDo;
	
	If ThereAreRetailSaleReports Then
		CommonUseClientServer.MessageToUser(
			NStr("en = 'For retail sale reports sales slip is not formed.'"),,
			"List");
	EndIf;
	
	If ReceiptsCRArray.Count() > 0 Then
		
		OpenParameters = New Structure("PrintManagerName,TemplateNames,CommandParameter,PrintParameters");
		OpenParameters.PrintManagerName	= "Document.SalesSlip";
		OpenParameters.TemplateNames	= "SalesReceipt";
		OpenParameters.CommandParameter	= ReceiptsCRArray;
		OpenParameters.PrintParameters	= Undefined;
		
		OpenForm("CommonForm.PrintDocuments", OpenParameters, ThisForm, UniqueKey);
		
	EndIf;
	
	If SalesSlipArrayForReturn.Count() > 0 Then
		
		OpenParameters = New Structure("PrintManagerName,TemplateNames,CommandParameter,PrintParameters");
		OpenParameters.PrintManagerName	= "Document.ProductReturn";
		OpenParameters.TemplateNames	= "SalesReceipt";
		OpenParameters.CommandParameter	= SalesSlipArrayForReturn;
		OpenParameters.PrintParameters	= Undefined;
		
		OpenForm("CommonForm.PrintDocuments", OpenParameters, ThisForm, UniqueKey);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure PrintSimplifiedTaxInvoice(Command)
	
	SalesSlipsArray = New Array;

	For Each ListRow In Items.List.SelectedRows Do
		
		If ListRow <> Undefined Then
			
			If TypeOf(ListRow) = Type("DocumentRef.SalesSlip") Then
				
				SalesSlipsArray.Add(ListRow);
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	If SalesSlipsArray.Count() Then
		
		OpenParameters = New Structure("PrintManagerName, TemplateNames, CommandParameter, PrintParameters");
		OpenParameters.PrintManagerName	 = "Document.SalesSlip";
		OpenParameters.TemplateNames	 = "SimplifiedTaxInvoice";
		OpenParameters.CommandParameter	 = SalesSlipsArray;
		OpenParameters.PrintParameters	 = Undefined;
		
		OpenForm("CommonForm.PrintDocuments", OpenParameters, ThisForm, UniqueKey);
		
	Else
		
		CommonUseClientServer.MessageToUser(
			NStr("en = 'Select sales slips you want to issue tax invoice against and try again.'"),, "List");
		
	EndIf;
	
EndProcedure

&AtClient
Procedure PrintSimplifiedTaxInvoiceForAnArchivedSalesSlip(Command)
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("Date", CurrentDate());
	ParametersStructure.Insert("Company", Object.Company);
	ParametersStructure.Insert("CashCR", CashCR);
	
	OpenForm("DataProcessor.PrintSimplifiedTaxInvoice.Form", ParametersStructure, ThisObject);
	
EndProcedure

// Procedure - command handler SubordinateDocumentStructure form
//
&AtClient
Procedure SubordinateDocumentStructure(Command)
	
	CurrentDocument = Items.SalesSlipList.CurrentRow;
	
	If CurrentDocument <> Undefined Then
		OpenForm("CommonForm.SubordinateDocumentStructureTabularRepresentation",New Structure("DocumentRef", CurrentDocument),
					ThisObject,
					CurrentDocument.UUID(),
					Undefined
					);
	Else
		Message = New UserMessage;
		Message.Text = NStr("en = 'Select a document.'");
		Message.Field = "SalesSlipList";
		Message.Message();
	EndIf;
	
EndProcedure

// Procedure - command handler Reserve on server.
&AtServer
Function ReserveAtServer(CancelReservation = False)
	
	ReturnValue = False;
	If CancelReservation Then
		CurrentDocument = Items.List.CurrentRow;
		If ValueIsFilled(CurrentDocument) AND TypeOf(CurrentDocument) = Type("DocumentRef.SalesSlip") Then
			DocObject = CurrentDocument.GetObject();
			
			OldStatus = DocObject.Status;
			
			DocObject.Status = Undefined;
			WriteMode = DocumentWriteMode.UndoPosting;
			
			Try
				DocObject.Write(WriteMode);
				If Not DocObject.Posted Then
					ReturnValue = True;
					// If we post object with which work in form you need to update the form object.
					// This situation arises in the following case. 
					// Balance control is set.
					// 1. Click the "Accept payment" button. Document will be written so. Reservation will the executed.
					// 2. IN the payment form click the "Cancel" button.
					// 3. Select current document in list and select "More..."-"Remove reserve".
					// 4. Click the "Accept payment" button.
					If DocObject.Ref = Object.Ref Then
						ValueToFormData(DocObject, Object);
					EndIf;
				EndIf;
			Except
				Message = New UserMessage;
				Message.Text = ErrorDescription();
				Message.Field = "List";
				Message.Message();
			EndTry;
		Else
			Message = New UserMessage;
			Message.Text = NStr("en = 'Sales slip is not selected.'");
			Message.Field = "List";
			Message.Message();
		EndIf;
	Else
		OldStatus = Object.Status;
		
		Object.Status = Enums.SalesSlipStatus.ProductReserved;
		WriteMode = DocumentWriteMode.Posting;
		
		Try
			If Not Write(New Structure("WriteMode", WriteMode)) Then
				Object.Status = OldStatus;
			Else
				ReturnValue = True;
			EndIf;
		Except
			Object.Status = OldStatus;
			
			Message = New UserMessage;
			Message.Text = NStr("en = 'It was not succeeded to execute document post.'");
			Message.Message();
		EndTry;
		
		SetEnabledOfReceiptPrinting();
	EndIf;
	
	Return ReturnValue;
	
EndFunction

// Procedure - command handler RemoveReservation.
//
&AtClient
Procedure RemoveReservation(Command)
	
	ReserveAtServer(True);
	
	Notify("RefreshSalesSlipDocumentsListForm");
	
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

#Region ProceduresElementFormEventsHandlers

// Procedure - event handler OnChange input field ProductsSearchValue.
//
&AtClient
Procedure ProductsSearchValueOnChange(Item)
	
	If ValueIsFilled(ProductsSearchValue) Then
		
		NewRow = Object.Inventory.Add();
		NewRow.Products = ProductsSearchValue;
		
		ProductsSearchValue = Undefined;
		Modified = True;
		
		ProductsOnChange(NewRow);
		
		RecalculateDocumentAtClient();
		
		CurrentItem = Items.ProductsSearchValue;
		Items.Inventory.CurrentRow = NewRow.GetID();
		
	EndIf;
	
EndProcedure

// Procedure - event handler OnChange item ReceiptIsNotShown form.
//
&AtClient
Procedure ReceiptInNotShowedOnChange(Item)
	
	ReceiptIsNotShownOnChangeAtServer();
	
	If Not ReceiptIsNotShown Then
		AttachIdleHandler("SalesSlipListOnActivateRowIdleProcessing", 0.2, True);
	EndIf;
	
EndProcedure

// Procedure - event handler OnChange item ReceiptIsNotShown on server.
//
&AtServer
Procedure ReceiptIsNotShownOnChangeAtServer()
	
	If ReceiptIsNotShown Then
		CreditNote = "";
		CPV = "";
		
		Items.DecorationTitleReceiptsCR.Title = NStr("en = 'Create a credit note and a cash voucher'");
		Items.DecorationCreditNote.Title = "";
		Items.DecorationCPV.Title = "";
		Items.DecorationGoodsReturn.Title = "";
		
		Items.DecorationSalesSlipForReturn.Visible = False;
		Items.DecorationCreditNote.Visible = True;
		Items.DecorationCPV.Visible = True;
		Items.DecorationGoodsReturn.Visible = True;
		
		Items.CreateSalesSlipForReturn.Visible = False;
		Items.CreateCreditNote.Visible = True;
		Items.CreateCPVBasedOnReceipt.Visible = True;
		If UseGoodsReturnFromCustomer Then
			Items.CreateGoodsReturn.Visible = True;
		EndIf;
		
		Items.CreateCreditNote.TextColor = New Color;
		Items.CreateCPVBasedOnReceipt.TextColor = ?(ReceiptIsNotShown, UnavailableButtonColor, New Color);
		Items.CreateGoodsReturn.TextColor = ?(ReceiptIsNotShown, UnavailableButtonColor, New Color);
		
		Items.PagesSalesSlipList_and_SalesSlipContent_and_PageWithLabel.CurrentPage = Items.PageWithEmptyLabel;
	Else
		Items.DecorationTitleReceiptsCR.Title = NStr("en = 'Select a reason for refund.'");
		
		Items.CreateSalesSlipForReturn.Visible = True;
		Items.CreateCreditNote.Visible = False;
		Items.CreateCPVBasedOnReceipt.Visible = False;
		If UseGoodsReturnFromCustomer Then
			Items.CreateGoodsReturn.Visible = False;
		EndIf;
		
		Items.PagesSalesSlipList_and_SalesSlipContent_and_PageWithLabel.CurrentPage = Items.PageSalesSlipList_and_SalesSlipContent;
	EndIf;
	
EndProcedure

// Function gets Associated documents of a certain kind, places them
// in a temporary storage and returns address
//
&AtServer
Function PlaceRelatedDocumentsInStorage(SalesSlip, Kind)
	
	// Fill references on documents.
	Query = New Query;
	
	If Kind = "CreditNote" Then
		Query.Text = 
			"SELECT ALLOWED
			|	CreditNote.Ref AS RelatedDocument
			|FROM
			|	Document.CreditNote AS CreditNote
			|WHERE
			|	CreditNote.Posted
			|	AND CreditNote.BasisDocument = &SalesSlip";
	ElsIf Kind = "CashVoucher" Then
		Query.Text = 
			"SELECT ALLOWED
			|	CreditNote.Ref AS Ref,
			|	CreditNote.Number AS Number,
			|	CreditNote.Date AS Date
			|INTO CreditNote
			|FROM
			|	Document.CreditNote AS CreditNote
			|WHERE
			|	CreditNote.Posted
			|	AND CreditNote.BasisDocument = &SalesSlip
			|;
			|
			|////////////////////////////////////////////////////////////////////////////////
			|SELECT ALLOWED
			|	CashVoucher.Ref AS RelatedDocument
			|FROM
			|	Document.CashVoucher AS CashVoucher
			|		INNER JOIN CreditNote AS CreditNote
			|		ON CashVoucher.BasisDocument = CreditNote.Ref
			|WHERE
			|	CashVoucher.Posted";
	ElsIf Kind = "ProductReturn" Then
		Query.Text = 
			"SELECT ALLOWED
			|	ProductReturn.Ref AS RelatedDocument
			|FROM
			|	Document.ProductReturn AS ProductReturn
			|WHERE
			|	ProductReturn.Posted
			|	AND ProductReturn.SalesSlip = &SalesSlip";
	EndIf;
	
	Query.SetParameter("SalesSlip", SalesSlip);
	Result = Query.Execute();
	
	Return PutToTempStorage(Result.Unload(), UUID);
	
EndFunction

// Procedure - event handler Click item DecorationCreditNote form.
//
&AtClient
Procedure DecorationCreditNoteClick(Item)
	
	If ReceiptIsNotShown Then
		If Not CreditNote.IsEmpty() Then
			OpenForm("Document.CreditNote.ObjectForm", New Structure("Key", CreditNote));
		EndIf;
	Else
		CurSalesSlip = Items.SalesSlipList.CurrentRow;
		If CurSalesSlip = Undefined Then
			Return;
		EndIf;
		
		Modified = True;
		AddressInRelatedDocumentsStorage = PlaceRelatedDocumentsInStorage(CurSalesSlip, "CreditNote");
		FormParameters = New Structure("AddressInRelatedDocumentsStorage", AddressInRelatedDocumentsStorage);
		OpenForm("Document.SalesSlip.Form.LinkedDocuments", FormParameters
			,,,,,, FormWindowOpeningMode.LockOwnerWindow);
	EndIf;
	
EndProcedure

// Procedure - event handler Click item DecorationCPV form.
//
&AtClient
Procedure DecorationCPVClick(Item)
	
	If ReceiptIsNotShown Then
		If Not CPV.IsEmpty() Then
			OpenForm("Document.CashVoucher.ObjectForm", New Structure("Key", CPV));
		EndIf;
	Else
		CurSalesSlip = Items.SalesSlipList.CurrentRow;
		If CurSalesSlip = Undefined Then
			Return;
		EndIf;
		
		Modified = True;
		AddressInRelatedDocumentsStorage = PlaceRelatedDocumentsInStorage(CurSalesSlip, "CashVoucher");
		FormParameters = New Structure("AddressInRelatedDocumentsStorage", AddressInRelatedDocumentsStorage);
		OpenForm("Document.SalesSlip.Form.LinkedDocuments", FormParameters
			,,,,,, FormWindowOpeningMode.LockOwnerWindow);
	EndIf;
	
EndProcedure

// Procedure - event handler Click item DecorationGoodsReturn form.
//
&AtClient
Procedure DecorationGoodsReturnClick(Item)
	
	If ReceiptIsNotShown Then
		If Not CreditNote.IsEmpty() Then
			OpenForm("Document.GoodsReturn.ObjectForm", New Structure("Key", GoodsReturn));
		EndIf;
	Else
		CurSalesSlip = Items.SalesSlipList.CurrentRow;
		If CurSalesSlip = Undefined Then
			Return;
		EndIf;
		
		Modified = True;
		AddressInRelatedDocumentsStorage = PlaceRelatedDocumentsInStorage(CurSalesSlip, "GoodsReturn");
		FormParameters = New Structure("AddressInRelatedDocumentsStorage", AddressInRelatedDocumentsStorage);
		OpenForm("Document.SalesSlip.Form.LinkedDocuments", FormParameters
			,,,,,, FormWindowOpeningMode.LockOwnerWindow);
	EndIf;
	
EndProcedure

// Procedure - event handler Click item DecorationSalesSlipForReturn form.
//
&AtClient
Procedure CRDecorationForReturnReceiptClick(Item)
		
	CurSalesSlip = Items.SalesSlipList.CurrentRow;
	If CurSalesSlip = Undefined Then
		Return;
	EndIf;
	
	Modified = True;
	AddressInRelatedDocumentsStorage = PlaceRelatedDocumentsInStorage(CurSalesSlip, "ProductReturn");
	FormParameters = New Structure("AddressInRelatedDocumentsStorage", AddressInRelatedDocumentsStorage);
	OpenForm("Document.SalesSlip.Form.LinkedDocuments", FormParameters
		,,,,,, FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

// Procedure - event handler OnChange item SwitchLogFastGoods form.
//
&AtClient
Procedure SwitchJournalQuickProductsOnChange(Item)
	
	If SwitchJournalQuickProducts = 1 Then // Journal
		Items.CatalogPagesAndQuickProducts.CurrentPage = Items.Journal;
	ElsIf SwitchJournalQuickProducts = 2 Then // Quick sale
		Items.CatalogPagesAndQuickProducts.CurrentPage = Items.QuickSale;
	Else // Main attributes
		Items.CatalogPagesAndQuickProducts.CurrentPage = Items.MainAttributes;
	EndIf;
	
EndProcedure

// Procedure - event handler OnCurrentPageChange item GroupSalesAndReturn form.
//
&AtClient
Procedure GroupSalesAndReturnOnCurrentPageChange(Item, CurrentPage)
	
	SavedInSettingsDataModified = True;
	
EndProcedure

#EndRegion

#Region ProceduresEventHandlersHeaderAttributes

// Procedure - event handler OnChange field POSTerminal form.
//
&AtClient
Procedure POSTerminalOnChange(Item)
	
	POSTerminalOnChangeAtServer();
	
EndProcedure

// Procedure - event handler OnChange field POSTerminal on server.
//
&AtServer
Procedure POSTerminalOnChangeAtServer()
	
	GetRefsToEquipment();
	GetChoiceListOfPaymentCardKinds();
	
EndProcedure

// Procedure - event handler OnChange field CashCR.
//
&AtClient
Procedure CashCROnChange(Item)
	
	If CashCR.IsEmpty() Then
		Message = New UserMessage;
		Message.Text = NStr("en = 'Cash register cannot be empty.'");
		Message.Field = "CashCR";
		Message.Message();
		
		CashCR = PreviousCashCR;
		Return;
	EndIf;
	
	If CashCR = PreviousCashCR Then
		Return;
	EndIf;
	
	PreviousCashCR = CashCR;
	Object.CashCR = CashCR;
	
	CashParameters = New Structure("CashCurrency");
	CashCROnChangeAtServer(CashParameters);
	
	If Object.Inventory.Count() > 0 Then
		DriveClient.RefillTabularSectionPricesByPriceKind(ThisForm, "Inventory", True);
		DriveClient.RecalculateTabularSectionPricesByCurrency(ThisForm, CashParameters.CashCurrency, "Inventory");
		FillVATRateByVATTaxation();
		DriveClient.RecalculateTabularSectionAmountByFlagAmountIncludesVAT(ThisForm, "Inventory");
		
		FillAmountsDiscounts();
		
		RecalculateDocumentAtClient();
	EndIf;
	
	// Generate price and currency label.
	LabelStructure = New Structure;
	LabelStructure.Insert("PriceKind",						Object.PriceKind);
	LabelStructure.Insert("DiscountKind",					Object.DiscountMarkupKind);
	LabelStructure.Insert("DocumentCurrency",				Object.DocumentCurrency);
	LabelStructure.Insert("SettlementsCurrency",			Object.DocumentCurrency);
	LabelStructure.Insert("ExchangeRate",					ExchangeRate);
	LabelStructure.Insert("AmountIncludesVAT",				Object.AmountIncludesVAT);
	LabelStructure.Insert("ForeignExchangeAccounting",		ForeignExchangeAccounting);
	LabelStructure.Insert("RateNationalCurrency",			RateNationalCurrency);
	LabelStructure.Insert("VATTaxation",					Object.VATTaxation);
	LabelStructure.Insert("DiscountCard",					Object.DiscountCard);
	LabelStructure.Insert("DiscountPercentByDiscountCard",	Object.DiscountPercentByDiscountCard);
	
	PricesAndCurrency = GenerateLabelPricesAndCurrency(LabelStructure);
	
EndProcedure

// Procedure - event handler OnChange field CashRegister on server.
//
&AtServer
Procedure CashCROnChangeAtServer(CashParameters)
	
	CashParameters.Insert("CashCurrency", PreviousCashCR.CashCurrency);
	
	CashCRUseWithoutEquipmentConnection = CashCR.UseWithoutEquipmentConnection;
	
	Object.POSTerminal = Catalogs.POSTerminals.GetPOSTerminalByDefault(Object.CashCR);
	
	StructureStateCashCRSession = GetCashCRSessionStateAtServer(CashCR);
	FillPropertyValues(Object, StructureStateCashCRSession);
	
	Items.RemoveReservation.Visible = Not ControlAtWarehouseDisabled;
	
	UpdateLabelVisibleTimedOutOver24Hours(StructureStateCashCRSession);
	
	BalanceInCashier = StructureStateCashCRSession.CashInPettyCash;
	BalanceInCashierRow = ""+BalanceInCashier;
	
	Object.CashCR = CashCR;
	Object.StructuralUnit = CashCR.StructuralUnit;
	Object.PriceKind = CashCR.StructuralUnit.RetailPriceKind;
	If Not ValueIsFilled(Object.DocumentCurrency) Then
		Object.DocumentCurrency = CashCR.CashCurrency;
	EndIf;
	Object.Company = Object.CashCR.Owner;
	Object.Department = Object.CashCR.Department;
	Object.Responsible = DriveReUse.GetValueByDefaultUser(User, "MainResponsible");
	
	DocumentDate = Object.Date;
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentDate();
	EndIf;
	
	ParentCompany = DriveServer.GetCompany(Object.Company);
	
	Object.IncludeVATInPrice = True;
	
	If Not ValueIsFilled(Object.Ref) Then
		GetChoiceListOfPaymentCardKinds();
	EndIf;
	
	If UsePeripherals Then
		GetRefsToEquipment();
	EndIf;
	Items.InventoryImportDataFromDCT.Visible = UsePeripherals;
	
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
	
	FillVATRateByCompanyVATTaxation();
	
	LabelStructure = New Structure;
	LabelStructure.Insert("PriceKind",						Object.PriceKind);
	LabelStructure.Insert("DiscountKind",					Object.DiscountMarkupKind);
	LabelStructure.Insert("DocumentCurrency",				Object.DocumentCurrency);
	LabelStructure.Insert("SettlementsCurrency",			Object.DocumentCurrency);
	LabelStructure.Insert("ExchangeRate",					ExchangeRate);
	LabelStructure.Insert("AmountIncludesVAT",				Object.AmountIncludesVAT);
	LabelStructure.Insert("ForeignExchangeAccounting",		ForeignExchangeAccounting);
	LabelStructure.Insert("RateNationalCurrency",			RateNationalCurrency);
	LabelStructure.Insert("VATTaxation",					Object.VATTaxation);
	LabelStructure.Insert("DiscountCard",					Object.DiscountCard);
	LabelStructure.Insert("DiscountPercentByDiscountCard",	Object.DiscountPercentByDiscountCard);
	
	PricesAndCurrency = GenerateLabelPricesAndCurrency(LabelStructure);
	
	CashCRUseWithoutEquipmentConnection = Object.CashCR.UseWithoutEquipmentConnection;
	
	SetEnabledOfReceiptPrinting();
	
	If Object.Status = Enums.SalesSlipStatus.Issued
	AND Not CashCRUseWithoutEquipmentConnection Then
		SetModeReadOnly();
	EndIf;
	
	// Price accessibility setup for editing.
	AllowedEditDocumentPrices = DriveAccessManagementReUse.AllowedEditDocumentPrices();
	SaleFromWarehouse = Object.StructuralUnit.StructuralUnitType = Enums.BusinessUnitsTypes.Warehouse;
	
	Items.InventoryPrice.ReadOnly 					= Not AllowedEditDocumentPrices OR Not SaleFromWarehouse;
	Items.InventoryAmount.ReadOnly 					= Not AllowedEditDocumentPrices OR Not SaleFromWarehouse; 
	Items.InventoryDiscountPercentMargin.ReadOnly  	= Not AllowedEditDocumentPrices;
	Items.InventoryAmountDiscountsMarkups.ReadOnly	= Not AllowedEditDocumentPrices;
	Items.InventoryVATAmount.ReadOnly 				= Not AllowedEditDocumentPrices OR Not SaleFromWarehouse;
	
	// StructuralUnit - blank can't be
	StructuralUnitType = Object.StructuralUnit.StructuralUnitType;
	
	List.Parameters.SetParameterValue("CashCR", CashCR);
	List.Parameters.SetParameterValue("WithoutConnectingEquipment", CashCRUseWithoutEquipmentConnection);
	List.Parameters.SetParameterValue("Status", Enums.ShiftClosureStatus.IsOpen);
	List.Parameters.SetParameterValue("ChoiceOnStatuses", True);
	List.Parameters.SetParameterValue("FilterByChange", False);
	List.Parameters.SetParameterValue("CashCRSession", Documents.ShiftClosure.EmptyRef());
	
	SalesSlipList.Parameters.SetParameterValue("CashCR", CashCR);
	SalesSlipList.Parameters.SetParameterValue("WithoutConnectingEquipment", CashCRUseWithoutEquipmentConnection);
	SalesSlipList.Parameters.SetParameterValue("Status", Enums.ShiftClosureStatus.IsOpen);
	SalesSlipList.Parameters.SetParameterValue("ChoiceOnStatuses", True);
	SalesSlipList.Parameters.SetParameterValue("FilterByChange", False);
	SalesSlipList.Parameters.SetParameterValue("CashCRSession", Documents.ShiftClosure.EmptyRef());
	
	SalesSlipListForReturn.Parameters.SetParameterValue("CashCR", CashCR);
	SalesSlipListForReturn.Parameters.SetParameterValue("WithoutConnectingEquipment", CashCRUseWithoutEquipmentConnection);
	SalesSlipListForReturn.Parameters.SetParameterValue("Status", Enums.ShiftClosureStatus.IsOpen);
	SalesSlipListForReturn.Parameters.SetParameterValue("ChoiceOnStatuses", True);
	SalesSlipListForReturn.Parameters.SetParameterValue("FilterByChange", False);
	SalesSlipListForReturn.Parameters.SetParameterValue("CashCRSession", Documents.ShiftClosure.EmptyRef());
	
	// StructuralUnit - blank can't be
	StructuralUnitType = Object.StructuralUnit.StructuralUnitType;
	
	GenerateTitle(StructureStateCashCRSession);
	
	SetPeriodAtServer(SalesSlipPeriodTransferKind, "SalesSlipList", 
							  New StandardPeriod(Items.SalesSlipList.Period.StartDate, Items.SalesSlipList.Period.EndDate));
	SetPeriodAtServer(SalesSlipPeriodKindForReturnTransfer, "SalesSlipListForReturn", 
							  New StandardPeriod(Items.SalesSlipListForReturn.Period.StartDate, Items.SalesSlipListForReturn.Period.EndDate));
	SetPeriodAtServer(CatalogPeriodKindTransfer, "List", 
							  New StandardPeriod(Items.List.Period.StartDate, Items.List.Period.EndDate));
	
	// Recalculation TS Inventory
	ResetFlagDiscountsAreCalculatedServer("ChangeCashRegister");
	
EndProcedure

// Procedure - event handler OnChange field Company.
//
&AtClient
Procedure CompanyOnChange(Item)
	
	FillVATRateByCompanyVATTaxation();
	
	// Generate price and currency label.
	LabelStructure = New Structure;
	LabelStructure.Insert("PriceKind",						Object.PriceKind);
	LabelStructure.Insert("DiscountKind",					Object.DiscountMarkupKind);
	LabelStructure.Insert("DocumentCurrency",				Object.DocumentCurrency);
	LabelStructure.Insert("SettlementsCurrency",			Object.DocumentCurrency);
	LabelStructure.Insert("ExchangeRate",					ExchangeRate);
	LabelStructure.Insert("AmountIncludesVAT",				Object.AmountIncludesVAT);
	LabelStructure.Insert("ForeignExchangeAccounting",		ForeignExchangeAccounting);
	LabelStructure.Insert("RateNationalCurrency",			RateNationalCurrency);
	LabelStructure.Insert("VATTaxation",					Object.VATTaxation);
	LabelStructure.Insert("DiscountCard",					Object.DiscountCard);
	LabelStructure.Insert("DiscountPercentByDiscountCard",	Object.DiscountPercentByDiscountCard);
	
	PricesAndCurrency = GenerateLabelPricesAndCurrency(LabelStructure);
	
EndProcedure

// Procedure - event handler OnChange checkbox DoNotShowAtOpenCashChoiceForm.
//
&AtClient
Procedure DoNotShowOnOpenCashierChoiceFormOnChange(Item)
	
	// CWP
	CashierWorkplaceServerCall.UpdateCashierWorkplaceSettings(CWPSetting, DontShowOnOpenCashdeskChoiceForm);
	
EndProcedure

#EndRegion

#Region ProceduresEventHandlersTablePartAttributes

// Procedure - event handler OnChange column Products TS Inventory.
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
	WorkWithSerialNumbersClientServer.DeleteSerialNumbersByConnectionKey(Object.SerialNumbers, TabularSectionRow,, UseSerialNumbersBalance);
	
EndProcedure

// Procedure - event handler OnStartEdit of the Inventory form tabular section.
//
&AtClient
Procedure InventoryOnStartEdit(Item, NewRow, Copy)
	
	If NewRow AND Copy Then
		Item.CurrentData.AutomaticDiscountsPercent = 0;
		Item.CurrentData.AutomaticDiscountAmount = 0;
		CalculateAmountInTabularSectionLine();
	EndIf;
	
EndProcedure

// Procedure - event handler OnEditEnd of the Inventory list row.
//
&AtClient
Procedure InventoryOnEditEnd(Item, NewRow, CancelEdit)
	
	RecalculateDocumentAtClient();
	
EndProcedure

// Procedure - event handler AfterDeletion of the Inventory list row.
//
&AtClient
Procedure InventoryAfterDeleteRow(Item)
	
	RecalculateDocumentAtClient();
	
	// AutomaticDiscounts.
	ClearCheckboxDiscountsAreCalculatedClient("DeleteRow");
	
EndProcedure

// Procedure - event handler OnChange of the Characteristic input field.
//
&AtClient
Procedure InventoryCharacteristicOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
		
	StructureData = New Structure;
	StructureData.Insert("Products",				TabularSectionRow.Products);
	StructureData.Insert("Characteristic",			TabularSectionRow.Characteristic);
		
	If ValueIsFilled(Object.PriceKind) Then
		
		StructureData.Insert("ProcessingDate",	 	Object.Date);
		StructureData.Insert("DocumentCurrency",	Object.DocumentCurrency);
		StructureData.Insert("AmountIncludesVAT", 	Object.AmountIncludesVAT);
		
		StructureData.Insert("VATRate", 			TabularSectionRow.VATRate);
		StructureData.Insert("Price",			 	TabularSectionRow.Price);
		
		StructureData.Insert("PriceKind", 			Object.PriceKind);
		StructureData.Insert("MeasurementUnit", 	TabularSectionRow.MeasurementUnit);
		
	EndIf;
	
	StructureData = GetDataCharacteristicOnChange(StructureData);
	
	TabularSectionRow.Price = StructureData.Price;
	
	CalculateAmountInTabularSectionLine();
	
	TabularSectionRow.ProductsCharacteristicAndBatch = TrimAll(""+TabularSectionRow.Products)+?(TabularSectionRow.Characteristic.IsEmpty(), "", ". "+TabularSectionRow.Characteristic)+
		?(TabularSectionRow.Batch.IsEmpty(), "", ". "+TabularSectionRow.Batch);
	
EndProcedure

// Procedure - event handler OnChange column TS Batch Inventory.
//
&AtClient
Procedure DocumentSalesSlipInventoryBatchOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	If TabularSectionRow <> Undefined Then
		TabularSectionRow.ProductsCharacteristicAndBatch = "" + TabularSectionRow.Products + ?(TabularSectionRow.Characteristic.IsEmpty(), "", ". "+TabularSectionRow.Characteristic)+
			?(TabularSectionRow.Batch.IsEmpty(), "", ". "+TabularSectionRow.Batch);
	EndIf;
	
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
	
	CalculateAmountInTabularSectionLine(, False);
	
EndProcedure

// Procedure - event handler OnChange input field MeasurementUnit.
//
&AtClient
Procedure InventoryMeasurementUnitOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	SetDescriptionForStringTSInventoryAtClient(TabularSectionRow);
	
EndProcedure

// Procedure - event handler OnChange of the Price entered field.
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
	
	CalculateDiscountPercent();
	
EndProcedure

// Procedure - event handler OnChange of the Amount entered field.
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
	AutomaticDiscountsRecalculationIsRequired = ClearCheckboxDiscountsAreCalculatedClient("CalculateAmountInTabularSectionLine");
		
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

&AtClient
Procedure InventoryOnChange(Item)
	
	ShowHideDealAtClient();
	
EndProcedure

&AtClient
Procedure InventoryBeforeDeleteRow(Item, Cancel)
	
	CurrentData = Items.Inventory.CurrentData;
	// Serial numbers
	WorkWithSerialNumbersClientServer.DeleteSerialNumbersByConnectionKey(
		Object.SerialNumbers, CurrentData,, UseSerialNumbersBalance);
	
EndProcedure

&AtClient
Procedure InventorySerialNumbersStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	OpenSerialNumbersSelection();
	
EndProcedure

#EndRegion

#Region ProceduresEventHandlersDynamicLists

// Procedure - event handler OnActivateRow item SalesSlipList.
//
&AtClient
Procedure SalesSlipListOnRowRevitalization(Item)
	
	// Make a bit more period better, else user will not be able to enter a number in the search field.
	AttachIdleHandler("SalesSlipListOnActivateRowIdleProcessing", 0.3, True);
	
EndProcedure

// Procedure updates the information on the content, hyperlinks and sets cellar buttons on a Return bookmark.
//
&AtClient
Procedure SalesSlipListOnActivateRowIdleProcessing()
	
	CurSalesSlip = Items.SalesSlipList.CurrentRow;
	If CurSalesSlip <> Undefined Then
		FillReceiptAndRefContentOnDocumentsAtServer(CurSalesSlip);
	Else
		ReceiptContent = "";
	EndIf;
	
	DetachIdleHandler("SalesSlipListOnActivateRowIdleProcessing");
	
EndProcedure

// Procedure fills information about current receipt CR TS content in the SalesSlipList item.
//
&AtServer
Procedure FillReceiptAndRefContentOnDocumentsAtServer(SalesSlip)
	
	// Fill receipt content.
	ThisIsFirstString = True;
	For Each CurRow In SalesSlip.Inventory Do
		If ThisIsFirstString Then
			ThisIsFirstString = False;
			ReceiptContent = ""+CurRow.Products+". "+Chars.LF+Chars.Tab+GetDescriptionForTSStringInventoryAtServer(CurRow);
		Else
			ReceiptContent = ReceiptContent+Chars.LF+CurRow.Products+". "+Chars.LF+Chars.Tab+GetDescriptionForTSStringInventoryAtServer(CurRow);
		EndIf;
	EndDo;
	
	// Fill references on documents.
	Query = New Query;
	Query.Text = 
		"SELECT ALLOWED
		|	CreditNote.Ref AS Ref,
		|	CreditNote.Number AS Number,
		|	CreditNote.Date AS Date
		|INTO CreditNote
		|FROM
		|	Document.CreditNote AS CreditNote
		|WHERE
		|	CreditNote.Posted
		|	AND CreditNote.BasisDocument = &SalesSlip
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	CreditNote.Ref AS Ref,
		|	CreditNote.Number AS Number,
		|	CreditNote.Date AS Date
		|FROM
		|	CreditNote AS CreditNote
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED
		|	CashVoucher.Ref AS Ref,
		|	CashVoucher.Date AS Date,
		|	CashVoucher.Number AS Number
		|FROM
		|	Document.CashVoucher AS CashVoucher
		|		INNER JOIN CreditNote AS CreditNote
		|		ON CashVoucher.BasisDocument = CreditNote.Ref
		|WHERE
		|	CashVoucher.Posted
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	GoodsReturn.Ref AS Ref,
		|	GoodsReturn.Date AS Date,
		|	GoodsReturn.Number AS Number
		|FROM
		|	CreditNote AS CreditNote_
		|		INNER JOIN Document.GoodsReturn AS GoodsReturn
		|		ON CreditNote_.Ref = GoodsReturn.CreditNote
		|WHERE
		|	GoodsReturn.Posted
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED
		|	ProductReturn.Ref AS Ref,
		|	ProductReturn.Number AS Number,
		|	ProductReturn.Date AS Date
		|FROM
		|	Document.ProductReturn AS ProductReturn
		|WHERE
		|	ProductReturn.Posted
		|	AND ProductReturn.SalesSlip = &SalesSlip";
	
	Query.SetParameter("SalesSlip", SalesSlip);
	
	MResults = Query.ExecuteBatch();
	
	// Define button and hyperlink visible.
	If SalesSlip.CashCRSession.CashCRSessionStatus = Enums.ShiftClosureStatus.IsOpen Then
		// Receipt CR on return.
		Selection = MResults[4].Select();
		If Selection.Next() Then
			SalesSlipForReturn = Selection.Ref;
			DocumentNumber = ObjectPrefixationClientServer.GetNumberForPrinting(Selection.Number, True, True);
			Items.DecorationSalesSlipForReturn.Title = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Return slip #%1 dated %2.'"), 
				DocumentNumber,  
				Format(Selection.Date, "DLF=D"));
			Items.CreateSalesSlipForReturn.TextColor = UnavailableButtonColor;
		Else
			SalesSlipForReturn = Documents.ProductReturn.EmptyRef();
			Items.DecorationSalesSlipForReturn.Title = "";
			Items.CreateSalesSlipForReturn.TextColor = New Color;
		EndIf;
		
		While Selection.Next() Do
			DocumentNumber = ObjectPrefixationClientServer.GetNumberForPrinting(Selection.Number, True, True);
			Items.DecorationSalesSlipForReturn.Title = Items.DecorationSalesSlipForReturn.Title + " " + StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = '#%1 dated %2.'"),
				DocumentNumber,
				Format(Selection.Date, "DLF=D"));
		EndDo;
		
		Items.CreateSalesSlipForReturn.Visible = True;
		Items.CreateCreditNote.Visible = False;
		Items.CreateCPVBasedOnReceipt.Visible = False;
		If UseGoodsReturnFromCustomer Then
			Items.CreateGoodsReturn.Visible = False;
		EndIf;
		
		Items.DecorationSalesSlipForReturn.Visible = True;
		Items.DecorationCreditNote.Visible = False;
		Items.DecorationCPV.Visible = False;
		Items.DecorationGoodsReturn.Visible = False;
		
		Items.DecorationTitleReceiptsCR.Title = NStr("en = 'Choose a reason for the return'");
	Else
		
		Selection = MResults[4].Select();
		If Selection.Next() Then // Receipt CR on return.
			SalesSlipForReturn = Selection.Ref;
			DocumentNumber = ObjectPrefixationClientServer.GetNumberForPrinting(Selection.Number, True, True);
			Items.DecorationSalesSlipForReturn.Title = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Return slip #%1 dated %2.'"),
			    DocumentNumber,
				Format(Selection.Date, "DLF=D"));
			
			While Selection.Next() Do
				DocumentNumber = ObjectPrefixationClientServer.GetNumberForPrinting(Selection.Number, True, True);
				Items.DecorationSalesSlipForReturn.Title = Items.DecorationSalesSlipForReturn.Title + "; "
					+ StringFunctionsClientServer.SubstituteParametersInString(
						NStr("en = '#%1 dated %2.'"),
						DocumentNumber,
						Format(Selection.Date, "DLF=D"));
			EndDo;
			
			Items.CreateSalesSlipForReturn.TextColor = UnavailableButtonColor;
			Items.CreateSalesSlipForReturn.Visible = True;
			Items.CreateCreditNote.Visible = False;
			Items.CreateCPVBasedOnReceipt.Visible = False;
			If UseGoodsReturnFromCustomer Then
				Items.CreateGoodsReturn.Visible = False;
			EndIf;
			
			Items.DecorationSalesSlipForReturn.Visible = True;
			Items.DecorationCreditNote.Visible = False;
			Items.DecorationCPV.Visible = False;
			Items.DecorationGoodsReturn.Visible = False;
		Else
			// Receipt CR on return.
			SalesSlipForReturn = Documents.ProductReturn.EmptyRef();
			Items.DecorationSalesSlipForReturn.Title = "";
			
			// Credit note.
			Selection = MResults[1].Select();
			If Selection.Next() Then
				CreditNote = Selection.Ref;
				
				Items.CreateCreditNote.TextColor = UnavailableButtonColor;
				Items.CreateCPVBasedOnReceipt.TextColor = UnavailableButtonColor;
				Items.CreateGoodsReturn.TextColor = UnavailableButtonColor;
				
				DocumentNumber = ObjectPrefixationClientServer.GetNumberForPrinting(Selection.Number, True, True);
				TitlePresentation = NStr("en = 'Credit note'");
				Items.DecorationCreditNote.Title = StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = '%1 #%2 dated %3'"),
					TitlePresentation,
					DocumentNumber,
					Format(Selection.Date, "DLF=D"));
				While Selection.Next() Do
				DocumentNumber = ObjectPrefixationClientServer.GetNumberForPrinting(Selection.Number, True, True);
				Items.DecorationCreditNote.Title = Items.DecorationCreditNote.Title + "; "
					+ StringFunctionsClientServer.SubstituteParametersInString(
						NStr("en = '#%1 dated %2'"),
						DocumentNumber,
						Format(Selection.Date, "DLF=D"));
				EndDo;
			Else
				CreditNote = Documents.CreditNote.EmptyRef();
				
				Items.CreateCreditNote.TextColor = New Color;
				Items.CreateCPVBasedOnReceipt.TextColor = UnavailableButtonColor;
				Items.CreateGoodsReturn.TextColor = UnavailableButtonColor;
				
				Items.DecorationCreditNote.Title = "";
			EndIf;
			
			// CPV.
			Selection = MResults[2].Select();
			If Selection.Next() Then
				CPV = Selection.Ref;
				
				DocumentNumber = ObjectPrefixationClientServer.GetNumberForPrinting(Selection.Number, True, True);
				Items.DecorationCPV.Title = StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = 'Cash voucher #%1 dated %2.'"),
					DocumentNumber,
					Format(Selection.Date, "DLF=D"));
				Items.CreateCPVBasedOnReceipt.TextColor = UnavailableButtonColor;
				
				While Selection.Next() Do
					DocumentNumber = ObjectPrefixationClientServer.GetNumberForPrinting(Selection.Number, True, True);
					Items.DecorationCPV.Title = Items.DecorationCPV.Title + StringFunctionsClientServer.SubstituteParametersInString(
						NStr("en = '; #%1 dated %2.'"),
						DocumentNumber,
						Format(Selection.Date, "DLF=D"));
				EndDo;
			Else
				Items.DecorationCPV.Title = "";
				If Not CreditNote.IsEmpty() Then
					Items.CreateCPVBasedOnReceipt.TextColor = New Color;
				Else
					Items.CreateCPVBasedOnReceipt.TextColor = UnavailableButtonColor;
					Items.CreateGoodsReturn.TextColor = New Color;
				EndIf;
			EndIf;
			
			// Goods return.
			Selection = MResults[3].Select();
			If Selection.Next() Then
				GoodsReturn = Selection.Ref;
				
				Items.CreateCreditNote.TextColor = UnavailableButtonColor;
				Items.CreateCPVBasedOnReceipt.TextColor = UnavailableButtonColor;
				Items.CreateGoodsReturn.TextColor = UnavailableButtonColor;
				
				DocumentNumber = ObjectPrefixationClientServer.GetNumberForPrinting(Selection.Number, True, True);
				TitlePresentation = NStr("en = 'Goods return'");
				Items.DecorationGoodsReturn.Title = StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = '%1 #%2 dated %3'"),
					TitlePresentation,
					DocumentNumber,
					Format(Selection.Date, "DLF=D"));
				While Selection.Next() Do
					DocumentNumber = ObjectPrefixationClientServer.GetNumberForPrinting(Selection.Number, True, True);
					Items.DecorationGoodsReturn.Title = Items.DecorationGoodsReturn.Title + "; "
						+ StringFunctionsClientServer.SubstituteParametersInString(NStr("en = '#%1 dated %2'"),
																					DocumentNumber,
																					Format(Selection.Date, "DLF=D"));
				EndDo;
			Else
				GoodsReturn = Documents.GoodsReturn.EmptyRef();
				
				If Not CPV.IsEmpty() Then
					Items.CreateGoodsReturn.TextColor = New Color;
				Else
					Items.CreateGoodsReturn.TextColor = UnavailableButtonColor;
				EndIf;
				
				Items.DecorationGoodsReturn.Title = "";
			EndIf;
			
			Items.CreateSalesSlipForReturn.Visible = False;
			Items.CreateCreditNote.Visible = True;
			Items.CreateCPVBasedOnReceipt.Visible = True;
			If UseGoodsReturnFromCustomer Then
				Items.CreateGoodsReturn.Visible = True;
			EndIf;
		
		Items.DecorationSalesSlipForReturn.Visible = False;
			Items.DecorationCreditNote.Visible = True;
			Items.DecorationCPV.Visible = True;
			Items.DecorationGoodsReturn.Visible = True;
		EndIf;
		
	EndIf;
	
EndProcedure

// Procedure - event handler ValueSelection item List.
//
&AtClient
Procedure ValueChoiceList(Item, Value, StandardProcessing)
	
	CurrentData = Items.List.CurrentData;
	If CurrentData <> Undefined Then
		If TypeOf(CurrentData.Ref) = Type("DocumentRef.SalesSlip") Then
			OpenForm("Document.SalesSlip.ObjectForm", New Structure("Key", CurrentData.Ref));
		ElsIf TypeOf(CurrentData.Ref) = Type("DocumentRef.SalesSlip") Then
			OpenForm("Document.ProductReturn.ObjectForm", New Structure("Key", CurrentData.Ref));
		ElsIf TypeOf(CurrentData.Ref) = Type("DocumentRef.SalesSlip") Then
			OpenForm("Document.ShiftClosure.ObjectForm", New Structure("Key", CurrentData.Ref));
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region CommandFormPanelsActionProcedures

// Procedure - ImportDataFromDTC command handler.
//
&AtClient
Procedure ImportDataFromDCT(Command)
	
	NotificationsAtImportFromDCT = New NotifyDescription("ImportFromDCTEnd", ThisObject);
	EquipmentManagerClient.StartImportDataFromDCT(NotificationsAtImportFromDCT, UUID);
	
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

// Procedure - command handler GetWeight form. It is executed after obtaining weight from electronic scales.
//
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

// Procedure - event handler Click item PricesAndCurrency form.
//
&AtClient
Procedure EditPricesAndCurrency(Item, StandardProcessing)
	
	StandardProcessing = False;
	ProcessChangesOnButtonPricesAndCurrencies(Object.DocumentCurrency);
	
EndProcedure

// Procedure - command handler IncreaseQuantity form.
//
&AtClient
Procedure GroupQuantity(Command)
	
	CurrentData = Items.Inventory.CurrentData;
	If CurrentData <> Undefined Then
		CurrentData.Quantity = CurrentData.Quantity + 1;
		CalculateAmountInTabularSectionLine();
		RecalculateDocumentAtClient();
	Else
		Message = New UserMessage;
		Message.Text = NStr("en = 'String is not selected.'");
		Message.Field = "Object.Inventory";
		Message.Message();
	EndIf;
	
EndProcedure

// Procedure - command handler ReduceQuantity form.
//
&AtClient
Procedure ReduceQuantity(Command)
	
	CurrentData = Items.Inventory.CurrentData;
	If CurrentData <> Undefined Then
		CurrentData.Quantity = CurrentData.Quantity - 1;
		CalculateAmountInTabularSectionLine();
		RecalculateDocumentAtClient();
	Else
		Message = New UserMessage;
		Message.Text = NStr("en = 'String is not selected.'");
		Message.Field = "Object.Inventory";
		Message.Message();
	EndIf;
	
EndProcedure

// Procedure - command handler ChangeQuantityByCalculator form.
//
&AtClient
Procedure ChangeQuantityUsingCalculator(Command)
	
	CurrentData = Items.Inventory.CurrentData;
	If CurrentData <> Undefined Then
		Notification = New NotifyDescription("ChangeQuantityUsingCalculatorEnd", ThisForm);
		
		ParametersStructure = New Structure("Quantity, ProductsCharacteristicAndBatch, Price, Amount, DiscountMarkupPercent, AutomaticDiscountPercent", 
			CurrentData.Quantity, 
			CurrentData.ProductsCharacteristicAndBatch,
			CurrentData.Price,
			CurrentData.Amount,
			CurrentData.DiscountMarkupPercent,
			CurrentData.AutomaticDiscountsPercent);
			
		OpenForm("Document.SalesSlip.Form.FormEnterQuantity", ParametersStructure,,,,,Notification);
	Else
		Message = New UserMessage;
		Message.Text = NStr("en = 'String is not selected.'");
		Message.Field = "Object.Inventory";
		Message.Message();
	EndIf;
	
EndProcedure

// Procedure - command handler ChangeQuantityByCalculatorEnd after closing quantity change form.
//
&AtClient
Procedure ChangeQuantityUsingCalculatorEnd(Result, Parameters) Export
	
	If TypeOf(Result) = Type("Structure") Then
		
		CurrentData = Items.Inventory.CurrentData;
		If CurrentData <> Undefined Then
			CurrentData.Quantity = Result.Quantity;
			CalculateAmountInTabularSectionLine();
			RecalculateDocumentAtClient();
		EndIf;
		
	EndIf;
	
EndProcedure

// Procedure - command handler ClearTSInventory form.
//
&AtClient
Procedure ClearTSInventory(Command)
	
	If Object.Inventory.Count() = 0 Then
		Return;
	EndIf;
	
	NotifyDescription = New NotifyDescription("ClearTSInventoryEnd", ThisObject);
	ShowQueryBox(NotifyDescription, NStr("en = 'Clear the table?'"), QuestionDialogMode.YesNo,,DialogReturnCode.Yes);
	
EndProcedure

// Procedure - command handler ClearTSInventoryEnd after confirmation delete all strings TS inventory in issue form.
//
&AtClient
Procedure ClearTSInventoryEnd(Result, AdditionalParameters) Export

	If Result = DialogReturnCode.Yes Then
		Object.Inventory.Clear();
	EndIf;

EndProcedure

// Procedure - command handler OpenProductsCard form.
//
&AtClient
Procedure OpenProductsCard(Command)
	
	CurrentData = Items.Inventory.CurrentData;
	If CurrentData <> Undefined Then
		MTypeRestriction = New Array;
		MTypeRestriction.Add(ProductsTypeInventory);
		MTypeRestriction.Add(ProductsTypeService);
		
		AdditParameters = New Structure("TypeRestriction", MTypeRestriction);
		FillingValues = New Structure("ProductsType", MTypeRestriction);
		
		NewPositionProductsParameters = New Structure("Key, AdditionalParameters, FillingValues", CurrentData.Products, AdditParameters, FillingValues);
		OpenForm("Catalog.Products.ObjectForm", NewPositionProductsParameters, ThisObject);
	Else
		Message = New UserMessage;
		Message.Text = NStr("en = 'String is not selected.'");
		Message.Field = "Object.Inventory";
		Message.Message();
	EndIf;
	
EndProcedure

// Procedure - command handler ListCreateSalesSlipForReturn form.
//
&AtClient
Procedure ListCreateSalesSlipForReturn(Command)
	
	MessageText = "";
	CurrentData = Items.List.CurrentData;
	If CurrentData <> Undefined Then
		If TypeOf(CurrentData.Ref) = Type("DocumentRef.SalesSlip") Then
			OpenForm("Document.ProductReturn.ObjectForm", New Structure("Basis", CurrentData.Ref));
		Else
			MessageText = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Return slip is not allowed to enter based on a ddocument of the %1 type.'"),
				TypeOf(CurrentData.Ref));
		EndIf;
	Else
		MessageText = NStr("en = 'Return slip is not selected.'");
	EndIf;
	
	If MessageText <> "" Then
		Message = New UserMessage;
		Message.Text = MessageText;
		Message.Field = "List";
		Message.Message();
	EndIf;
	
EndProcedure

// Procedure - command handler CreateCreditNoteListForReturn form.
//
&AtClient
Procedure CreateCreditNoteListForReturn(Command)
	
	MessageText = "";
	CurrentData = Items.List.CurrentData;
	If CurrentData <> Undefined Then
		If TypeOf(CurrentData.Ref) = Type("DocumentRef.SalesSlip") Then
			OpenForm("Document.CreditNote.ObjectForm", New Structure("Basis, CWP", CurrentData.Ref, True), ThisObject, UUID);
		Else
			MessageText = NStr("en = 'Cannot create receipt CR for return based on the document type:'") + " " + TypeOf(CurrentData.Ref) + ".";
		EndIf;
	Else
		MessageText = NStr("en = 'Receipt CR is not selected.'");
	EndIf;
	
	If MessageText <> "" Then
		Message = New UserMessage;
		Message.Text = MessageText;
		Message.Field = "List";
		Message.Message();
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
	ParameterStructure.Insert("ApplyToObject",                	True);
	ParameterStructure.Insert("OnlyPreliminaryCalculation",		False);
	
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
// If the discounts are changed, the function returns True.
//
&AtServer
Function DiscountsChanged()
	
	ParameterStructure = New Structure;
	ParameterStructure.Insert("ApplyToObject",                	False);
	ParameterStructure.Insert("OnlyPreliminaryCalculation",     False);
	
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
		
		SetDescriptionForTSRowsInventoryAtServer(CurrentRow);
	EndDo;
	
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

// End modeless window opening "ShowDoQueryBox()". Procedure opens a common form for information analysis about
// discounts by current row.
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

// Procedure - event handler Selection of the Inventory tabular section.
//
&AtClient
Procedure InventorySelection(Item, SelectedRow, Field, StandardProcessing)
	
	If (Item.CurrentItem = Items.InventoryAutomaticDiscountPercent OR Item.CurrentItem = Items.InventoryAutomaticDiscountAmount)
		AND Not ReadOnly Then
		
		StandardProcessing = False;
		OpenInformationAboutDiscountsClient();
		
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

// Procedure calls the report form "Used discounts" for current document in the "List" item.
//
&AtClient
Procedure AppliedDiscounts(Command)
	
	CurrentData = Items.List.CurrentData;
	If CurrentData = Undefined Then
		MessageText = NStr("en = 'Document is not selected.
		                   |Go to ""Applied discounts"" is possible only after the selection in list.'");
		Message = New UserMessage;
		Message.Text = MessageText;
		Message.Field = "List";
		Message.Message();
		Return;
	ElsIf TypeOf(CurrentData.Ref) <> Type("DocumentRef.ShiftClosure") Then
		FormParameters = New Structure("DocumentRef", CurrentData.Ref);
		OpenForm("Report.DiscountsAppliedInDocument.Form.ReportForm", FormParameters, ThisObject, UUID);
	Else
		MessageText = NStr("en = 'Select sales slip or return slip.'");
		Message = New UserMessage;
		Message.Text = MessageText;
		Message.Field = "List";
		Message.Message();
		Return;
	EndIf;
	
EndProcedure

#EndRegion

#Region DiscountCards

// Procedure - Command handler ReadDiscountCard forms.
//
&AtClient
Procedure ReadDiscountCard(Command)
	
	NotifyDescription = New NotifyDescription("ReadDiscountCardClickEnd", ThisObject);
	OpenForm("Catalog.DiscountCards.Form.ReadingDiscountCard", , ThisForm, , , , NotifyDescription, FormWindowOpeningMode.LockOwnerWindow);	
	
EndProcedure

// Final part of procedure - of the form command handler ReadDiscountCard.
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
	LabelStructure.Insert("ForeignExchangeAccounting",		ForeignExchangeAccounting);
	LabelStructure.Insert("RateNationalCurrency",			RateNationalCurrency);
	LabelStructure.Insert("VATTaxation",					Object.VATTaxation);
	LabelStructure.Insert("DiscountCard",					Object.DiscountCard);
	LabelStructure.Insert("DiscountPercentByDiscountCard",	Object.DiscountPercentByDiscountCard);
	
	PricesAndCurrency = GenerateLabelPricesAndCurrency(LabelStructure);
	
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

#EndRegion

#Region Peripherals

// Procedure displays information output on the customer display.
//
// Parameters:
//  No.
//
&AtClient
Procedure DisplayInformationOnCustomerDisplay()

	If Displays = Undefined Then
		Displays = EquipmentManagerClientReUse.GetEquipmentList("CustomerDisplay", , EquipmentManagerServerCall.GetClientWorkplace());
	EndIf;
	
	display = Undefined;
	DPText = ?(
		Items.Inventory.CurrentData = Undefined,
		"",
		TrimAll(Items.Inventory.CurrentData.Products)
	  + Chars.LF
	  + NStr("en = 'Total'") + ": "
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
			                   |Additional description:
			                   |%AdditionalDetails%'");
			MessageText = StrReplace(MessageText,"%AdditionalDetails%",Output_Parameters[1]);
			CommonUseClientServer.MessageToUser(MessageText);
		EndIf;
		
	EndDo;
	
EndProcedure

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
	StructureData.Insert("DiscountPercentByDiscountCard", Object.DiscountPercentByDiscountCard);
	StructureData.Insert("DiscountCard", Object.DiscountCard);
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
	
	RecalculateDocumentAtClient();
	
EndProcedure

&AtClient
Procedure ImportFromDCTEnd(Result, Parameters) Export
	
	If TypeOf(Result) = Type("Array") 
	   AND Result.Count() > 0 Then
		BarcodesReceived(Result);
	EndIf;
	
EndProcedure

// Procedure - tabular section command bar command handler.
//
&AtClient
Procedure SearchByBarcode(Command)
	
	CurBarcode = "";
	
	NotifyDescription = New NotifyDescription("SearchByBarcodeEnd", ThisObject);
	ShowInputValue(NotifyDescription, CurBarcode, NStr("en = 'Enter barcode'"));
	
EndProcedure

&AtClient
Procedure SearchByBarcodeEnd(Result, AdditionalParameters) Export
	
	If Result = Undefined AND AdditionalParameters = Undefined Then
		Return;
	EndIf;
	
	CurBarcode = ?(Result = Undefined, AdditionalParameters.CurBarcode, Result);
	
	If Not IsBlankString(CurBarcode) Then
		BarcodesReceived(New Structure("Barcode, Quantity", CurBarcode, 1));
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
	PrintManagementClient.ExecuteConnectedPrintCommand(Command, ThisObject, Items.List);
EndProcedure

// End StandardSubsystems.Printing

#EndRegion

#Region SettingDynamicListPeriods

// Procedure fills selection lists in items which manage the period in document lists.
//
&AtServer
Procedure FillPeriodKindLists()
	
	Items.MagazinePeriodKind.ChoiceList.Clear();
	Items.MagazinePeriodKind.ChoiceList.Add(Enums.CWPPeriodTypes.ForCurrentShift);
	Items.MagazinePeriodKind.ChoiceList.Add(Enums.CWPPeriodTypes.ForPreviousShift);
	Items.MagazinePeriodKind.ChoiceList.Add(Enums.CWPPeriodTypes.ForUserDefinedPeriod);
	
	Items.SalesSlipPeriodKind.ChoiceList.Clear();
	Items.SalesSlipPeriodKind.ChoiceList.Add(Enums.CWPPeriodTypes.ForCurrentShift);
	Items.SalesSlipPeriodKind.ChoiceList.Add(Enums.CWPPeriodTypes.ForPreviousShift);
	Items.SalesSlipPeriodKind.ChoiceList.Add(Enums.CWPPeriodTypes.ForUserDefinedPeriod);
	
	Items.SalesSlipPeriodKindForReturn.ChoiceList.Clear();
	Items.SalesSlipPeriodKindForReturn.ChoiceList.Add(Enums.CWPPeriodTypes.ForCurrentShift);
	Items.SalesSlipPeriodKindForReturn.ChoiceList.Add(Enums.CWPPeriodTypes.ForPreviousShift);
	Items.SalesSlipPeriodKindForReturn.ChoiceList.Add(Enums.CWPPeriodTypes.ForUserDefinedPeriod);
	
EndProcedure

// Procedure - event handler SelectionDataProcessor item LogPeriodKind form.
//
&AtClient
Procedure JournalPeriodKindChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	SetPeriodAtClient(ValueSelected, "List");
	StandardProcessing = False;
	Items.MagazinePeriodKind.UpdateEditText();
	
EndProcedure

// Procedure - event handler SelectionDataProcessor item SalesSlipPeriodKind form.
//
&AtClient
Procedure SalesSlipPeriodKindChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	SetPeriodAtClient(ValueSelected, "SalesSlipList");
	StandardProcessing = False;
	Items.SalesSlipPeriodKind.UpdateEditText();
	
EndProcedure

// Procedure - event handler SelectionDataProcessor item SalesSlipPeriodKindForReturn form.
//
&AtClient
Procedure SalesSlipPeriodKindForReturnChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	SetPeriodAtClient(ValueSelected, "SalesSlipListForReturn");
	StandardProcessing = False;
	Items.SalesSlipPeriodKindForReturn.UpdateEditText();
	
EndProcedure

// Procedure sets dynamic list period.
//
&AtClient
Procedure SetPeriodAtClient(PeriodKindCWP, ListName, ParameterStandardPeriod = Undefined)
	
	If PeriodKindCWP = ThisObject.ForUserDefinedPeriod Then
		
		If ListName = "List" Then
			CatalogPeriodKindTransfer = PeriodKindCWP;
		ElsIf ListName = "SalesSlipListForReturn" Then
			SalesSlipPeriodKindForReturnTransfer = PeriodKindCWP;
		ElsIf ListName = "SalesSlipList" Then
			SalesSlipPeriodTransferKind = PeriodKindCWP;
		EndIf;
		
		NotifyDescription = New NotifyDescription("SetEndOfPeriod", ThisObject, New Structure("ListName", ListName));
		Dialog = New StandardPeriodEditDialog();
		Dialog.Period = ThisObject.Items[ListName].Period;
		Dialog.Show(NotifyDescription);
		
	Else
		
		SetPeriodAtServer(PeriodKindCWP, ListName, ParameterStandardPeriod);
		
	EndIf;
	
EndProcedure

// Procedure sets dynamic list period (if it is required period interactive selection).
//
&AtClient
Procedure SetEndOfPeriod(Result, Parameters) Export
	
	SetEndOfPeriodAtServer(Result, Parameters);
	
EndProcedure

// Procedure sets dynamic list period on server (if it is required period interactive selection).
//
&AtServer
Procedure SetEndOfPeriodAtServer(Result, Parameters)
	
	If Result <> Undefined Then
		
		ThisObject[Parameters.ListName].Parameters.SetParameterValue("ChoiceOnStatuses", False);
		ThisObject[Parameters.ListName].Parameters.SetParameterValue("Status", SessionIsOpen);
		ThisObject[Parameters.ListName].Parameters.SetParameterValue("FilterByChange", False);
		
		Items[Parameters.ListName].Period.Variant = Result.Variant;
		Items[Parameters.ListName].Period.StartDate = Result.StartDate;
		Items[Parameters.ListName].Period.EndDate = Result.EndDate;
		Items[Parameters.ListName].Refresh();
		
		If Parameters.ListName = "List" Then
			Items.Date.Visible = True;
			MagazinePeriodKind = GetPeriodPresentation(Result, " - ");
		ElsIf Parameters.ListName = "SalesSlipListForReturn" Then
			SalesSlipPeriodKindForReturn = GetPeriodPresentation(Result, " - ");
		ElsIf Parameters.ListName = "SalesSlipList" Then
			SalesSlipPeriodKind = GetPeriodPresentation(Result, " - ");
		EndIf;
		
	EndIf;
	
EndProcedure

// Procedure sets dynamic list period on server.
//
&AtServer
Procedure SetPeriodAtServer(PeriodKindCWP, ListName, ParameterStandardPeriod = Undefined)
	
	If ListName = "List" Then
		CatalogPeriodKindTransfer = PeriodKindCWP;
	ElsIf ListName = "SalesSlipListForReturn" Then
		SalesSlipPeriodKindForReturnTransfer = PeriodKindCWP;
	ElsIf ListName = "SalesSlipList" Then
		SalesSlipPeriodTransferKind = PeriodKindCWP;
	EndIf;
	
	If PeriodKindCWP = ForCurrentShift Then
		
		ThisObject[ListName].Parameters.SetParameterValue("ChoiceOnStatuses", True);
		ThisObject[ListName].Parameters.SetParameterValue("FilterByChange", False);
		Items[ListName].Period = New StandardPeriod;
		Items[ListName].Refresh();
		If ListName = "List" Then
			Items.Date.Visible = False;
			MagazinePeriodKind = NStr("en = 'For current shift'");
		ElsIf ListName = "SalesSlipListForReturn" Then
			SalesSlipPeriodKindForReturn = NStr("en = 'For current shift'");
		ElsIf ListName = "SalesSlipList" Then
			SalesSlipPeriodKind = NStr("en = 'For current shift'");
		EndIf;
		
	ElsIf PeriodKindCWP = ForPreviousShift Then
		
		ThisObject[ListName].Parameters.SetParameterValue("ChoiceOnStatuses", False);
		ThisObject[ListName].Parameters.SetParameterValue("FilterByChange", True);
		ThisObject[ListName].Parameters.SetParameterValue("CashCRSession", GetLatestClosedCashCRSession());
		Items[ListName].Period = New StandardPeriod;
		Items[ListName].Refresh();
		If ListName = "List" Then
			Items.Date.Visible = False;
			MagazinePeriodKind = NStr("en = 'For last shift'");
		ElsIf ListName = "SalesSlipListForReturn" Then
			SalesSlipPeriodKindForReturn = NStr("en = 'For last shift'");
		ElsIf ListName = "SalesSlipList" Then
			SalesSlipPeriodKind = NStr("en = 'For last shift'");
		EndIf;
		
	ElsIf PeriodKindCWP = ForYesterday Then
		
		ThisObject[ListName].Parameters.SetParameterValue("ChoiceOnStatuses", False);
		ThisObject[ListName].Parameters.SetParameterValue("FilterByChange", False);
		Items[ListName].Refresh();
		Items[ListName].Period.StartDate = BegOfDay(BegOfDay(CurrentDate())-1);
		Items[ListName].Period.EndDate = BegOfDay(CurrentDate())-1;
		Items[ListName].Refresh();
		If ListName = "List" Then
			Items.Date.Visible = False;
			MagazinePeriodKind = NStr("en = 'For yesterday'");
		ElsIf ListName = "SalesSlipListForReturn" Then
			SalesSlipPeriodKindForReturn = NStr("en = 'For yesterday'");
		ElsIf ListName = "SalesSlipList" Then
			SalesSlipPeriodKind = NStr("en = 'For yesterday'");
		EndIf;
		
	ElsIf PeriodKindCWP = ForUserDefinedPeriod Then
		
		Items[ListName].Period.StartDate = ParameterStandardPeriod.StartDate;
		Items[ListName].Period.EndDate = ParameterStandardPeriod.EndDate;
		ThisObject[ListName].Parameters.SetParameterValue("ChoiceOnStatuses", False);
		ThisObject[ListName].Parameters.SetParameterValue("FilterByChange", False);
		Items[ListName].Refresh();
		If ListName = "List" Then
			Items.Date.Visible = True;
			MagazinePeriodKind = GetPeriodPresentation(Items.List.Period, " - ");
		ElsIf ListName = "SalesSlipListForReturn" Then
			SalesSlipPeriodKindForReturn = GetPeriodPresentation(Items.SalesSlipListForReturn.Period, " - ");
		ElsIf ListName = "SalesSlipList" Then
			SalesSlipPeriodKind = GetPeriodPresentation(Items.SalesSlipList.Period, " - ");
		EndIf;
		
	ElsIf PeriodKindCWP = ForEntirePeriod Then
		
		ThisObject[ListName].Parameters.SetParameterValue("ChoiceOnStatuses", False);
		ThisObject[ListName].Parameters.SetParameterValue("FilterByChange", False);
		Items[ListName].Period = New StandardPeriod;
		Items[ListName].Refresh();
		If ListName = "List" Then
			Items.Date.Visible = True;
			MagazinePeriodKind = NStr("en = 'During all the time'");
		ElsIf ListName = "SalesSlipListForReturn" Then
			SalesSlipPeriodKindForReturn = NStr("en = 'During all the time'");
		ElsIf ListName = "SalesSlipList" Then
			SalesSlipPeriodKind = NStr("en = 'During all the time'");
		EndIf;
		
	EndIf;
	
EndProcedure

// Function returns the standard period presentation.
//
&AtClientAtServerNoContext
Function GetPeriodPresentation(StandardPeriod, Delimiter)
	
	StartDate = StandardPeriod.StartDate;
	EndDate = StandardPeriod.EndDate;
	If Not ValueIsFilled(StartDate) AND Not ValueIsFilled(EndDate) Then
		Return NStr("en = 'During all the time'");;
	ElsIf Year(StartDate) = Year(EndDate) AND Month(StartDate) = Month(EndDate) Then
		Return Format(StartDate, "DF=dd")+Delimiter+Format(EndDate, "DLF=D");
	ElsIf Year(StartDate) = Year(EndDate) Then
		Return Format(StartDate, "DF=dd.MM")+Delimiter+Format(EndDate, "DLF=D");
	Else
		Return Format(StartDate, "DLF=D")+Delimiter+Format(EndDate, "DLF=D");
	EndIf;
	
EndFunction

#EndRegion

#Region QuickSale

// Procedure creates buttons on fast goods panel.
//
&AtServer
Procedure FillFastGoods(OnOpen = False)

	ColumnQuantity = 3;
	
	Workplace = EquipmentManagerServerCall.GetClientWorkplace();
	
	If Not ValueIsFilled(Workplace) Then
		Message = New UserMessage;
		Message.Text = NStr("en = 'Failed to identify workplace to work with peripherals.'");
		Message.Message();
		Return;
	EndIf;
	
	CWPSetting = CashierWorkplaceServerCall.GetCWPSetup(Workplace);
	If Not ValueIsFilled(CWPSetting) Then
		Message = New UserMessage;
		Message.Text = NStr("en = 'Failed to receive the CWP settings for current workplace.'");
		Message.Message();
		Return;
	EndIf;
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	QuickSale.Products AS Products,
		|	QuickSale.Characteristic AS Characteristic,
		|	QuickSale.Ctrl,
		|	QuickSale.Shift,
		|	QuickSale.Alt,
		|	QuickSale.Shortcut,
		|	QuickSale.Key,
		|	QuickSale.Title,
		|	QuickSale.Products.UseCharacteristics AS CharacteristicsAreUsed,
		|	QuickSale.Products.Description AS Description,
		|	QuickSale.Characteristic.Description,
		|	CASE
		|		WHEN QuickSale.SortingField = """"
		|			THEN QuickSale.Products.Description
		|		ELSE QuickSale.SortingField
		|	END AS SortingField
		|FROM
		|	Catalog.CashierWorkplaceSettings.QuickSale AS QuickSale
		|WHERE
		|	QuickSale.Ref = &CWPSetting
		|	AND Not QuickSale.Disabled
		|
		|ORDER BY
		|	SortingField,
		|	Products,
		|	Characteristic
		|AUTOORDER";
	
	Query.SetParameter("CWPSetting", CWPSetting);
	
	MResults = Query.ExecuteBatch();
	
	ResultTable = MResults[0].Unload();
	
	// Delete commands.
	If Not OnOpen Then
		DeletedCommandArray = New Array;
		For Each Command In Commands Do
			If (Find(Command.Name, "QuickProduct_") > 0) 
				OR (Find(Command.Name, "FastGoodsGroup_") > 0) 
				Then
				DeletedCommandArray.Add(Command);
			EndIf;
		EndDo;
		For Each Command In DeletedCommandArray Do
			Commands.Delete(Command);
		EndDo;
		// Delete items.
		DeletedItemsArray = New Array;
		For Each Item In Items Do
			If (Find(Item.Name, "QuickProduct_") > 0) 
				OR (Find(Item.Name, "GroupPaymentByCard_") > 0) 
				OR (Find(Item.Name, "FastGoodsGroup_")) Then
				DeletedItemsArray.Add(Item);
			EndIf;
		EndDo;
		For Each Item In DeletedItemsArray Do
			Try
				Items.Delete(Item);
			Except EndTry;
		EndDo;
		
		QuickSale.Clear();
	EndIf;
	
	CurAcc = 1;
	For Each QuickProduct In ResultTable Do
		If Not ValueIsFilled(QuickProduct.Products) Then
			Continue;
		EndIf;
		
		NewRow = QuickSale.Add();
		FillPropertyValues(NewRow, QuickProduct);
		
		ButtonName = "QuickProduct_" + QuickSale.IndexOf(NewRow);
			
		NewCommand = Commands.Add(ButtonName);
		NewCommand.Action = "FastGoodsIsSelected";
		If ValueIsFilled(QuickProduct.Title) Then
			NewCommand.Title = QuickProduct.Title;
		Else
			NewCommand.Title = String(QuickProduct.Description)+?(ValueIsFilled(QuickProduct.CharacteristicDescription), ". "+TrimAll(QuickProduct.CharacteristicDescription), "");
		EndIf;
		NewCommand.Representation               = ButtonRepresentation.Text;
		NewCommand.ModifiesStoredData = True;
		If ValueIsFilled(QuickProduct.Key) Then
			NewCommand.Shortcut           = New Shortcut(Key[QuickProduct.Key], QuickProduct.Alt, QuickProduct.Ctrl, QuickProduct.Shift);
		EndIf;
		
		If CurAcc = 1 OR (CurAcc-1) % ColumnQuantity = 0 Then
			NewFolder = Items.Add("GroupPaymentByCard_"+CurAcc, Type("FormGroup"), Items.ButtonsGroupFastProducts);
			NewFolder.Type = FormGroupType.UsualGroup;
			NewFolder.ShowTitle = False;
			NewFolder.Group = ChildFormItemsGroup.Horizontal;
		EndIf;

		NewButton = Items.Add(ButtonName, Type("FormButton"), NewFolder);
		NewButton.OnlyInAllActions = False;
		NewButton.Visible = True;
		NewButton.CommandName = NewCommand.Name;
		If ValueIsFilled(QuickProduct.Title) Then
			NewButton.Title = TrimAll(QuickProduct.Title);
		Else
			NewButton.Title = TrimAll(QuickProduct.Description)+?(ValueIsFilled(QuickProduct.CharacteristicDescription), ". "+TrimAll(QuickProduct.CharacteristicDescription), "");
		EndIf;
		CombinationPresentation = ShortcutPresentation(NewCommand.Shortcut);
		If ValueIsFilled(CombinationPresentation) Then
			NewButton.Title = Left(TrimAll(NewButton.Title), 20) + " " + CombinationPresentation;
		EndIf;
		NewButton.Width = 7;
		NewButton.Height = 3;
		NewButton.Shortcut = NewCommand.Shortcut;
		
		NewRow.CommandName = ButtonName;
		
		CurAcc = CurAcc + 1;
	EndDo;
	
	If CurAcc > ColumnQuantity Then
		While (CurAcc-1) % ColumnQuantity <> 0 Do
			NewDecoration = Items.Add("LabelDecoration_"+CurAcc, Type("FormDecoration"), NewFolder);
			NewDecoration.Type = FormDecorationType.Label;
			NewDecoration.Title = "";
			NewDecoration.Width = 7;
			NewDecoration.Height = 3;
			
			CurAcc = CurAcc + 1;
		EndDo;
	EndIf;
	
	// Fast goods setting button.
	CurAcc = CurAcc + 1;
	
	NewFolder = Items.Add("GroupPaymentByCard_"+CurAcc, Type("FormGroup"), Items.ButtonsGroupFastProducts);
	NewFolder.Type = FormGroupType.UsualGroup;
	NewFolder.ShowTitle = False;
	NewFolder.Group = ChildFormItemsGroup.Horizontal;
	
	NewButton = Items.Add("QuickProductsSettings", Type("FormButton"), NewFolder);
	NewButton.Representation = ButtonRepresentation.Picture;
	NewButton.OnlyInAllActions = False;
	NewButton.Visible = True;
	NewButton.CommandName = "QuickProductsSettings";
	NewButton.Title = "Settings";
	NewButton.Width = 3;
	NewButton.Height = 1;
	NewButton.Shortcut = New Shortcut(Key.S, True, False, False);
	
EndProcedure

// Procedure - handler fast goods button click.
&AtClient
Procedure FastGoodsIsSelected(Command)
	
	FoundStrings = QuickSale.FindRows(New Structure("CommandName", ""+Command.Name));
	If FoundStrings.Count() > 0 Then
		
		FilterStructure = New Structure("Products, Characteristic", FoundStrings[0].Products, FoundStrings[0].Characteristic);
		InventoryFoundStrings = Object.Inventory.FindRows(FilterStructure);
		
		If InventoryFoundStrings.Count() = 0 Then
			NewRow = Object.Inventory.Add();
			NewRow.Products = FoundStrings[0].Products;
			NewRow.Characteristic = FoundStrings[0].Characteristic;
			
			DocumentConvertedAtClient = False;
			ProductsOnChange(NewRow);
		Else
			InventoryFoundStrings[0].Quantity = InventoryFoundStrings[0].Quantity + 1;
			
			DocumentConvertedAtClient = False;
			CalculateAmountInTabularSectionLine(InventoryFoundStrings[0]);
			
			NewRow = InventoryFoundStrings[0];
		EndIf;
		
		SetDescriptionForStringTSInventoryAtClient(NewRow);
		
		Items.Inventory.Refresh();
		Items.List.CurrentRow = NewRow.GetID();
		
		RecalculateDocumentAtClient();
		
		Items.Inventory.CurrentRow = NewRow.GetID();
		
		SwitchJournalQuickProducts = 2;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region KeyboardShortcuts

// The function returns
// the parameters key presentation:
// ValueKey						- Key
//
// Returned
// value String - Key presentation
//
&AtServer
Function KeyPresentation(ValueKey) Export
	
	If String(Key._1) = String(ValueKey) Then
		Return "1";
	ElsIf String(Key._2) = String(ValueKey) Then
		Return "2";
	ElsIf String(Key._3) = String(ValueKey) Then
		Return "3";
	ElsIf String(Key._4) = String(ValueKey) Then
		Return "4";
	ElsIf String(Key._5) = String(ValueKey) Then
		Return "5";
	ElsIf String(Key._6) = String(ValueKey) Then
		Return "6";
	ElsIf String(Key._7) = String(ValueKey) Then
		Return "7";
	ElsIf String(Key._8) = String(ValueKey) Then
		Return "8";
	ElsIf String(Key._9) = String(ValueKey) Then
		Return "9";
	ElsIf String(Key.Num0) = String(ValueKey) Then
		Return "Num 0";
	ElsIf String(Key.Num1) = String(ValueKey) Then
		Return "Num 1";
	ElsIf String(Key.Num2) = String(ValueKey) Then
		Return "Num 2";
	ElsIf String(Key.Num3) = String(ValueKey) Then
		Return "Num 3";
	ElsIf String(Key.Num4) = String(ValueKey) Then
		Return "Num 4";
	ElsIf String(Key.Num5) = String(ValueKey) Then
		Return "Num 5";
	ElsIf String(Key.Num6) = String(ValueKey) Then
		Return "Num 6";
	ElsIf String(Key.Num7) = String(ValueKey) Then
		Return "Num 7";
	ElsIf String(Key.Num8) = String(ValueKey) Then
		Return "Num 8";
	ElsIf String(Key.Num9) = String(ValueKey) Then
		Return "Num 9";
	ElsIf String(Key.NumAdd) = String(ValueKey) Then
		Return "Num +";
	ElsIf String(Key.NumDecimal) = String(ValueKey) Then
		Return "Num .";
	ElsIf String(Key.NumDivide) = String(ValueKey) Then
		Return "Num /";
	ElsIf String(Key.NumMultiply) = String(ValueKey) Then
		Return "Num *";
	ElsIf String(Key.NumSubtract) = String(ValueKey) Then
		Return "Num -";
	Else
		Return String(ValueKey);
	EndIf;
	
EndFunction

// The function returns
// the parameters key presentation:
// Shortcut						- Combination of keys that
// require WithoutBrackets presentation							- The flag indicating that the presentation shall be formed without brackets
//
// Returned
// value String - Key combination presentation
//
&AtServer
Function ShortcutPresentation(Shortcut, WithoutParentheses = False) Export
	
	If Shortcut.Key = Key.None Then
		Return "";
	EndIf;
	
	Description = ?(WithoutParentheses, "", "(");
	If Shortcut.Ctrl Then
		Description = Description + "Ctrl+"
	EndIf;
	If Shortcut.Alt Then
		Description = Description + "Alt+"
	EndIf;
	If Shortcut.Shift Then
		Description = Description + "Shift+"
	EndIf;
	Description = Description + KeyPresentation(Shortcut.Key) + ?(WithoutParentheses, "", ")");
	
	Return Description;
	
EndFunction

#EndRegion

#Region StringPresentationTSInventoryOnReceipt

// Function returns information about quantity and amounts in string form. Used to fill receipt content on a "Return" bookmark.
//
&AtServer
Function GetDescriptionForTSStringInventoryAtServer(String)
	
	DiscountAmountStrings = (String.Quantity * String.Price) - String.Amount;
	ProductsCharacteristicAndBatch = TrimAll(String.Products.Description)+?(String.Characteristic.IsEmpty(), "", ". "+String.Characteristic)+?(String.Batch.IsEmpty(), "", ". "+String.Batch);
	If DiscountAmountStrings <> 0 Then
		DiscountPercent = Format(DiscountAmountStrings * 100 / (String.Quantity * String.Price), "NFD=2");
		DiscountText = ?(DiscountAmountStrings > 0, " - "+DiscountAmountStrings, " + "+(-DiscountAmountStrings))+" "+Object.DocumentCurrency
					  +" ("+?(DiscountAmountStrings > 0, " - "+DiscountPercent+"%)", " + "+(-DiscountPercent)+"%)");
	Else
		DiscountText = "";
	EndIf;
	Return ""+String.Price+" "+Object.DocumentCurrency+" X "+String.Quantity+" "+String.MeasurementUnit+DiscountText+" = "+String.Amount+" "+Object.DocumentCurrency;
	
EndFunction

// Function fills the DataByString and ProductsCharacteristicAndBatch attributes string TS Inventory.
//
&AtClient
Function SetDescriptionForStringTSInventoryAtClient(String)
	
	DiscountAmountStrings = (String.Quantity * String.Price) - String.Amount;
	String.ProductsCharacteristicAndBatch = TrimAll(""+String.Products)+?(String.Characteristic.IsEmpty(), "", ". "+String.Characteristic)+?(String.Batch.IsEmpty(), "", ". "+String.Batch);
	If DiscountAmountStrings <> 0 Then
		DiscountPercent = Format(DiscountAmountStrings * 100 / (String.Quantity * String.Price), "NFD=2");
		DiscountText = ?(DiscountAmountStrings > 0, " - "+DiscountAmountStrings, " + "+(-DiscountAmountStrings))+" "+Object.DocumentCurrency
					  +" ("+?(DiscountAmountStrings > 0, " - "+DiscountPercent+"%)", " + "+(-DiscountPercent)+"%)");
	Else
		DiscountText = "";
	EndIf;
	String.DataOnRow = ""+String.Price+" "+Object.DocumentCurrency+" X "+String.Quantity+" "+String.MeasurementUnit+DiscountText+" = "+String.Amount+" "+Object.DocumentCurrency;
	
	ShowHideDealAtClient();
	
EndFunction

// Function fills the DataByString and ProductsCharacteristicAndBatch attributes string TS Inventory.
//
&AtServer
Function SetDescriptionForTSRowsInventoryAtServer(String)
	
	DiscountAmountStrings = (String.Quantity * String.Price) - String.Amount;
	String.ProductsCharacteristicAndBatch = TrimAll(""+String.Products)+?(String.Characteristic.IsEmpty(), "", ". "+String.Characteristic)+?(String.Batch.IsEmpty(), "", ". "+String.Batch);
	If DiscountAmountStrings <> 0 Then
		DiscountPercent = Format(DiscountAmountStrings * 100 / (String.Quantity * String.Price), "NFD=2");
		DiscountText = ?(DiscountAmountStrings > 0, " - "+DiscountAmountStrings, " + "+(-DiscountAmountStrings))+" "+Object.DocumentCurrency
					  +" ("+?(DiscountAmountStrings > 0, " - "+DiscountPercent+"%)", " + "+(-DiscountPercent)+"%)");
	Else
		DiscountText = "";
	EndIf;
	String.DataOnRow = ""+String.Price+" "+Object.DocumentCurrency+" X "+String.Quantity+" "+String.MeasurementUnit+DiscountText+" = "+String.Amount+" "+Object.DocumentCurrency;
	
EndFunction

// Function fills the DataByString and ProductsCharacteristicAndBatch attributes for all strings TS Inventory.
//
&AtClient
Procedure FillInDetailsForTSInventoryAtClient()
	
	For Each CurrentRow In Object.Inventory Do
		SetDescriptionForStringTSInventoryAtClient(CurrentRow);
	EndDo;
	
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
