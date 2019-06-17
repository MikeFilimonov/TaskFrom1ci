
#Region GeneralPurposeProceduresAndFunctions

&AtClient
// The procedure handles the change of the Price kind and Settlement currency document attributes
//
Procedure HandleCounterpartiesPriceKindChangeAndSettlementsCurrency(DocumentParameters)
	
	ContractBeforeChange = DocumentParameters.ContractBeforeChange;
	SettlementsCurrencyBeforeChange = DocumentParameters.SettlementsCurrencyBeforeChange;
	ContractData = DocumentParameters.ContractData;
	QuestionSupplierPriceTypes = DocumentParameters.QuestionSupplierPriceTypes;
	OpenFormPricesAndCurrencies = DocumentParameters.OpenFormPricesAndCurrencies;
	ModifiedSupplierPriceTypes = DocumentParameters.ModifiedSupplierPriceTypes;
	
	If Not ContractData.AmountIncludesVAT = Undefined Then
		
		Object.AmountIncludesVAT = ContractData.AmountIncludesVAT;
		
	EndIf;
	
	If ValueIsFilled(Object.Contract) Then 
		
		Object.ExchangeRate      = ?(ContractData.SettlementsCurrencyRateRepetition.ExchangeRate = 0, 1, ContractData.SettlementsCurrencyRateRepetition.ExchangeRate);
		Object.Multiplicity = ?(ContractData.SettlementsCurrencyRateRepetition.Multiplicity = 0, 1, ContractData.SettlementsCurrencyRateRepetition.Multiplicity);
		
	EndIf;
	
	If ModifiedSupplierPriceTypes Then
		
		Object.SupplierPriceTypes = ContractData.SupplierPriceTypes;
		
	EndIf;
	
	If Object.DocumentCurrency <> ContractData.SettlementsCurrency Then
		Object.BankAccount = Undefined;
	EndIf;
	Object.DocumentCurrency = ContractData.SettlementsCurrency;
	
	If OpenFormPricesAndCurrencies Then
		
		WarningText = "";
		If ModifiedSupplierPriceTypes Then
			WarningText = NStr("en = 'Counterparty contract specifies the counterparty
			                   |price kind that differs from the kind specified for the document. 
			                   |Perhaps you have to refill prices.'") + Chars.LF + Chars.LF;
		EndIf;
		
		WarningText = WarningText + NStr("en = 'Settlement currency of the contract with counterparty changed.
		                                 |It is necessary to check the document currency.'");
										
		ProcessChangesOnButtonPricesAndCurrencies(SettlementsCurrencyBeforeChange, True, ModifiedSupplierPriceTypes, WarningText);
		
	ElsIf QuestionSupplierPriceTypes Then
		
		If Object.Inventory.Count() > 0 Then
			
			QuestionText = NStr("en = 'The counterparty contract allows for the kind of prices other than prescribed in the document. 
			                    |Recalculate the document according to the contract?'");
										
			NotifyDescription = New NotifyDescription("DefineDocumentRecalculateNeedByContractTerms", ThisObject, DocumentParameters);
			ShowQueryBox(NotifyDescription, QuestionText, QuestionDialogMode.YesNo);
			
		EndIf;
		
	Else
		
		LabelStructure = New Structure("SupplierPriceTypes, DocumentCurrency, SettlementsCurrency, ExchangeRate, AmountIncludesVAT, ForeignExchangeAccounting, RateNationalCurrency, VATTaxation",
			Object.SupplierPriceTypes,
			Object.DocumentCurrency,
			SettlementsCurrency,
			Object.ExchangeRate,
			Object.AmountIncludesVAT,
			ForeignExchangeAccounting,
			RateNationalCurrency,
			Object.VATTaxation);
			
		PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
		
	EndIf;
	
EndProcedure

// It receives data set from server for the DateOnChange procedure.
//
&AtServerNoContext
Function GetDataDateOnChange(DocumentRef, DateNew, DateBeforeChange, SettlementsCurrency)
	
	DATEDIFF = DriveServer.CheckDocumentNumber(DocumentRef, DateNew, DateBeforeChange);
	CurrencyRateRepetition = InformationRegisters.ExchangeRates.GetLast(DateNew, New Structure("Currency", SettlementsCurrency));
	
	StructureData = New Structure;
	
	StructureData.Insert(
		"DATEDIFF",
		DATEDIFF
	);
	StructureData.Insert(
		"CurrencyRateRepetition",
		CurrencyRateRepetition
	);
	
	Return StructureData;
	
EndFunction

// It receives data set from server for the ContractOnChange procedure.
//
&AtServer
Function GetDataCounterpartyOnChange(Date, DocumentCurrency, Counterparty, Company)
	
	ContractByDefault = GetContractByDefault(Object.Ref, Counterparty, Company);
	
	FillVATRateByVATTaxation();
	
	StructureData = New Structure;
	
	StructureData.Insert(
		"Contract",
		ContractByDefault
	);
		
	StructureData.Insert(
		"SettlementsCurrency",
		ContractByDefault.SettlementsCurrency
	);
	
	StructureData.Insert(
		"SettlementsCurrencyRateRepetition",
		InformationRegisters.ExchangeRates.GetLast(Date, New Structure("Currency", ContractByDefault.SettlementsCurrency))
	);
	
	StructureData.Insert(
		"SupplierPriceTypes",
		ContractByDefault.SupplierPriceTypes
	);
	
	StructureData.Insert(
		"SettlementsInStandardUnits",
		ContractByDefault.SettlementsInStandardUnits
	);
	
	StructureData.Insert(
		"AmountIncludesVAT",
		?(ValueIsFilled(ContractByDefault.SupplierPriceTypes), ContractByDefault.SupplierPriceTypes.PriceIncludesVAT, Undefined)
	);
	
	SetContractVisible();
	
	Return StructureData;
	
EndFunction

// It receives data set from server for the ContractOnChange procedure.
//
&AtServerNoContext
Function GetDataContractOnChange(Date, DocumentCurrency, Contract)
	
	StructureData = New Structure;
	
	StructureData.Insert(
		"SettlementsCurrency",
		Contract.SettlementsCurrency
	);
	
	StructureData.Insert(
		"SettlementsCurrencyRateRepetition",
		InformationRegisters.ExchangeRates.GetLast(Date, New Structure("Currency", Contract.SettlementsCurrency))
	);
	
	StructureData.Insert(
		"SettlementsInStandardUnits",
		Contract.SettlementsInStandardUnits
	);
	
	StructureData.Insert(
		"SupplierPriceTypes",
		Contract.SupplierPriceTypes
	);
	
	StructureData.Insert(
		"AmountIncludesVAT",
		?(ValueIsFilled(Contract.SupplierPriceTypes), Contract.SupplierPriceTypes.PriceIncludesVAT, Undefined)
	);
	
	Return StructureData;
	
EndFunction

// Procedure fills the VAT rate in the tabular section according to the taxation system.
// 
&AtServer
Procedure FillVATRateByVATTaxation()
	
	If Object.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then
		
		Items.InventoryVATRate.Visible = True;
		Items.InventoryVATAmount.Visible = True;
		Items.InventoryAmountTotal.Visible = True;
		Items.PaymentCalendarPayVATAmount.Visible = True;
		Items.ListPaymentsCalendarSumVatOfPayment.Visible = True;
		Items.DocumentTax.Visible = True;
		
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
		Items.PaymentCalendarPayVATAmount.Visible = False;
		Items.ListPaymentsCalendarSumVatOfPayment.Visible = False;
		Items.DocumentTax.Visible = False;
		
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
			
	If StructureData.Property("SupplierPriceTypes") Then
		Price = DriveServer.GetPriceProductsBySupplierPriceTypes(StructureData);
		StructureData.Insert("Price", Price);
	Else
		StructureData.Insert("Price", 0);
	EndIf;
	
	Return StructureData;
	
EndFunction

// It receives data set from server for the CharacteristicOnChange procedure.
//
&AtServerNoContext
Function GetDataCharacteristicOnChange(StructureData)
	
	If TypeOf(StructureData.MeasurementUnit) = Type("CatalogRef.UOMClassifier") Then
		StructureData.Insert("Factor", 1);
	Else
		StructureData.Insert("Factor", StructureData.MeasurementUnit.Factor);
	EndIf;
	
	Price = DriveServer.GetPriceProductsBySupplierPriceTypes(StructureData);
	StructureData.Insert("Price", Price);
	
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

// VAT amount is calculated in the row of tabular section.
//
&AtClient
Procedure CalculateVATSUM(TabularSectionRow)
	
	VATRate = DriveReUse.GetVATRateValue(TabularSectionRow.VATRate);
	
	TabularSectionRow.VATAmount = ?(Object.AmountIncludesVAT, 
									  TabularSectionRow.Amount - (TabularSectionRow.Amount) / ((VATRate + 100) / 100),
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
	
	CalculateVATSUM(TabularSectionRow);
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
EndProcedure

// Procedure recalculates amounts in the payment calendar.
//
&AtClient
Procedure RecalculatePaymentCalendar()
	
	InventoryTotal = Object.Inventory.Total("Amount");
	InventoryVATAmount = Object.Inventory.Total("VATAmount");
	
	For Each CurRow In Object.PaymentCalendar Do
		CurRow.PaymentAmount = Round(InventoryTotal * CurRow.PaymentPercentage / 100, 2, 1);
		CurRow.PaymentVATAmount = Round(InventoryVATAmount * CurRow.PaymentPercentage / 100, 2, 1);
	EndDo;
	
EndProcedure

&AtClient
Procedure RecalculatePaymentDate(OldDate, NewDate)
	
	If ValueIsFilled(OldDate)
		AND Object.SetPaymentTerms Then
		
		Delta = BegOfDay(NewDate) - BegOfDay(OldDate);
		
		For Each Line In Object.PaymentCalendar Do
			
			Line.PaymentDate = Line.PaymentDate + Delta;
			
		EndDo;
		
		MessageString = NStr("en = 'The Payment terms tab was changed'");
		CommonUseClientServer.MessageToUser(MessageString);
		
	EndIf;
	
EndProcedure

// Recalculates the exchange rate and exchange rate multiplicity of
// the payment currency when the document date is changed.
//
&AtClient
Procedure RecalculateExchangeRateMultiplicitySettlementCurrency(StructureData)
	
	NewExchangeRate = ?(StructureData.CurrencyRateRepetition.ExchangeRate = 0, 1, StructureData.CurrencyRateRepetition.ExchangeRate);
	NewRatio = ?(StructureData.CurrencyRateRepetition.Multiplicity = 0, 1, StructureData.CurrencyRateRepetition.Multiplicity);
	
	If Object.ExchangeRate <> NewExchangeRate
		OR Object.Multiplicity <> NewRatio Then
		
		CurrencyRateInLetters = String(Object.Multiplicity) + " " + TrimAll(SettlementsCurrency) + " = " + String(Object.ExchangeRate) + " " + TrimAll(FunctionalCurrency);
		RateNewCurrenciesInLetters = String(NewRatio) + " " + TrimAll(SettlementsCurrency) + " = " + String(NewExchangeRate) + " " + TrimAll(FunctionalCurrency);
		
		MessageText = CommonUseClientReUse.RecalculateExchangeRateText(CurrencyRateInLetters, RateNewCurrenciesInLetters);
		
		Mode = QuestionDialogMode.YesNo;
		Response = Undefined;

		ShowQueryBox(New NotifyDescription("RecalculatePaymentCurrencyRateConversionFactorEnd", 
					ThisObject, 
					New Structure("NewRatio, NewExchangeRate", NewRatio, NewExchangeRate)), MessageText, Mode, 0);
        Return;		
		
	EndIf;	
	
	// Generate price and currency label.
	RecalculatePaymentCurrencyRateConversionFactorFragment();
EndProcedure

&AtClient
Procedure RecalculatePaymentCurrencyRateConversionFactorEnd(Result, AdditionalParameters) Export
    
    NewRatio = AdditionalParameters.NewRatio;
    NewExchangeRate = AdditionalParameters.NewExchangeRate;
    
    
    Response = Result;
    
    If Response = DialogReturnCode.Yes Then
        
        Object.ExchangeRate = NewExchangeRate;
        Object.Multiplicity = NewRatio;
        
    EndIf;		
    
    
    RecalculatePaymentCurrencyRateConversionFactorFragment();

EndProcedure

&AtClient
Procedure RecalculatePaymentCurrencyRateConversionFactorFragment()
    
    Var LabelStructure;
    
    LabelStructure = New Structure("SupplierPriceTypes, DocumentCurrency, SettlementsCurrency, ExchangeRate, AmountIncludesVAT, ForeignExchangeAccounting, RateNationalCurrency, VATTaxation", Object.SupplierPriceTypes, Object.DocumentCurrency, SettlementsCurrency, Object.ExchangeRate, Object.AmountIncludesVAT, ForeignExchangeAccounting, RateNationalCurrency, Object.VATTaxation);
    PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);

EndProcedure

// Procedure executes recalculate in the document tabular section
// after changes in "Prices and currency" form.Column recalculation is executed:
// price, discount, amount, VAT amount, total.
//
&AtClient
Procedure ProcessChangesOnButtonPricesAndCurrencies(Val SettlementsCurrencyBeforeChange, RecalculatePrices = False, RefillPrices = False, WarningText = "")
	
	ParametersStructure = New Structure();
	ParametersStructure.Insert("DocumentCurrency",		Object.DocumentCurrency);
	ParametersStructure.Insert("ExchangeRate",			Object.ExchangeRate);
	ParametersStructure.Insert("Multiplicity",			Object.Multiplicity);
	ParametersStructure.Insert("VATTaxation",			Object.VATTaxation);
	ParametersStructure.Insert("AmountIncludesVAT",		Object.AmountIncludesVAT);
	ParametersStructure.Insert("Counterparty",			Object.Counterparty);
	ParametersStructure.Insert("Contract",				Object.Contract);
	ParametersStructure.Insert("ExchangeRate",			Object.ExchangeRate);
	ParametersStructure.Insert("Multiplicity",			Object.Multiplicity);
	ParametersStructure.Insert("Company",				Object.Company);
	ParametersStructure.Insert("DocumentDate",			Object.Date);
	ParametersStructure.Insert("RefillPrices",			RefillPrices);
	ParametersStructure.Insert("RecalculatePrices",		RecalculatePrices);
	ParametersStructure.Insert("WereMadeChanges",		False);
	ParametersStructure.Insert("SupplierPriceTypes",	Object.SupplierPriceTypes);
	ParametersStructure.Insert("WarningText",			WarningText);
	
	NotifyDescription = New NotifyDescription("OpenPricesAndCurrencyFormEnd", ThisObject, New Structure("SettlementsCurrencyBeforeChange", SettlementsCurrencyBeforeChange));
	OpenForm("CommonForm.PricesAndCurrency", ParametersStructure, ThisForm, , , , NotifyDescription, FormWindowOpeningMode.LockOwnerWindow);
	
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
			If ValueIsFilled(StructureData.SupplierPriceTypes) Then
				StructureProductsData.Insert("ProcessingDate", StructureData.Date);
				StructureProductsData.Insert("DocumentCurrency", StructureData.DocumentCurrency);
				StructureProductsData.Insert("AmountIncludesVAT", StructureData.AmountIncludesVAT);
				StructureProductsData.Insert("SupplierPriceTypes", StructureData.SupplierPriceTypes);
				If ValueIsFilled(BarcodeData.MeasurementUnit)
					AND TypeOf(BarcodeData.MeasurementUnit) = Type("CatalogRef.UOM") Then
					StructureProductsData.Insert("Factor", BarcodeData.MeasurementUnit.Factor);
				Else
					StructureProductsData.Insert("Factor", 1);
				EndIf;
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
	StructureData.Insert("SupplierPriceTypes", Object.SupplierPriceTypes);
	StructureData.Insert("Date", Object.Date);
	StructureData.Insert("DocumentCurrency", Object.DocumentCurrency);
	StructureData.Insert("AmountIncludesVAT", Object.AmountIncludesVAT);
	StructureData.Insert("VATTaxation", Object.VATTaxation);
	GetDataByBarCodes(StructureData);
	
	For Each CurBarcode In StructureData.BarcodesArray Do
		BarcodeData = StructureData.DataByBarCodes[CurBarcode.Barcode];
		
		If BarcodeData <> Undefined
		   AND BarcodeData.Count() = 0 Then
			UnknownBarcodes.Add(CurBarcode);
		Else
			
			ProductFilter = New Structure("Products, Characteristic, MeasurementUnit");
			ProductFilter.Products			= BarcodeData.Products;
			ProductFilter.Characteristic	= BarcodeData.Characteristic;
			ProductFilter.MeasurementUnit	= BarcodeData.MeasurementUnit;
			
			TSRowsArray = Object.Inventory.FindRows(ProductFilter);
			If TSRowsArray.Count() = 0 Then
				NewRow = Object.Inventory.Add();
				NewRow.Products = BarcodeData.Products;
				NewRow.Characteristic = BarcodeData.Characteristic;
				NewRow.Quantity = CurBarcode.Quantity;
				NewRow.MeasurementUnit = ?(ValueIsFilled(BarcodeData.MeasurementUnit), BarcodeData.MeasurementUnit, BarcodeData.StructureProductsData.MeasurementUnit);
				NewRow.Price = BarcodeData.StructureProductsData.Price;
				NewRow.VATRate = BarcodeData.StructureProductsData.VATRate;
				CalculateAmountInTabularSectionLine(NewRow);
				Items.Inventory.CurrentRow = NewRow.GetID();
			Else
				FoundString = TSRowsArray[0];
				FoundString.Quantity = FoundString.Quantity + CurBarcode.Quantity;
				CalculateAmountInTabularSectionLine(FoundString);
				Items.Inventory.CurrentRow = FoundString.GetID();
			EndIf;
			RecalculateSubtotal();
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

// Procedure sets the contract visible depending on the parameter set to the counterparty.
//
&AtServer
Procedure SetContractVisible()
	
	Items.Contract.Visible = Object.Counterparty.DoOperationsByContracts;
	
EndProcedure

// Checks the match of the "Company" and "ContractKind" contract attributes to the terms of the document.
//
&AtServerNoContext
Procedure CheckContractToDocumentConditionAccordance(MessageText, Contract, Document, Company, Counterparty, Cancel)
	
	If Not DriveReUse.CounterpartyContractsControlNeeded()
		OR Not Counterparty.DoOperationsByContracts Then
		
		Return;
	EndIf;
	
	ManagerOfCatalog = Catalogs.CounterpartyContracts;
	ContractKindsList = ManagerOfCatalog.GetContractKindsListForDocument(Document);
	
	If Not ManagerOfCatalog.ContractMeetsDocumentTerms(MessageText, Contract, Company, Counterparty, ContractKindsList)
		AND Constants.CheckContractsOnPosting.Get() Then
		
		Cancel = True;
	EndIf;
	
EndProcedure

// It gets counterparty contract selection form parameter structure.
//
&AtServerNoContext
Function GetChoiceFormOfContractParameters(Document, Company, Counterparty, Contract)
	
	ContractTypesList = Catalogs.CounterpartyContracts.GetContractKindsListForDocument(Document);
	
	FormParameters = New Structure;
	FormParameters.Insert("ControlContractChoice", Counterparty.DoOperationsByContracts);
	FormParameters.Insert("Counterparty", Counterparty);
	FormParameters.Insert("Company", Company);
	FormParameters.Insert("ContractType", ContractTypesList);
	FormParameters.Insert("CurrentRow", Contract);
	
	Return FormParameters;
	
EndFunction

// Gets the banking account selection form parameter structure.
//
&AtServerNoContext
Function GetChoiceFormParametersBankAccount(Contract, Company, FunctionalCurrency)
	
	AttributesContract = CommonUse.ObjectAttributesValues(Contract, "SettlementsCurrency, SettlementsInStandardUnits");
	
	CurrenciesList = New ValueList;
	CurrenciesList.Add(AttributesContract.SettlementsCurrency);
	CurrenciesList.Add(FunctionalCurrency);
	
	FormParameters = New Structure;
	FormParameters.Insert("SettlementsInStandardUnits", AttributesContract.SettlementsInStandardUnits);
	FormParameters.Insert("Owner", Company);
	FormParameters.Insert("CurrenciesList", CurrenciesList);
	
	Return FormParameters;
	
EndFunction

// Gets the default contract depending on the billing details.
//
&AtServerNoContext
Function GetContractByDefault(Document, Counterparty, Company)
	
	If Not Counterparty.DoOperationsByContracts Then
		Return Counterparty.ContractByDefault;
	EndIf;
	
	ManagerOfCatalog = Catalogs.CounterpartyContracts;
	
	ContractTypesList = ManagerOfCatalog.GetContractKindsListForDocument(Document);
	ContractByDefault = ManagerOfCatalog.GetDefaultContractByCompanyContractKind(Counterparty, Company, ContractTypesList);
	
	Return ContractByDefault;
	
EndFunction

// Performs actions when counterparty contract is changed.
//
&AtClient
Procedure ProcessContractChange(ContractData = Undefined)
	
	ContractBeforeChange = Contract;
	Contract = Object.Contract;
	
	If ContractBeforeChange <> Object.Contract Then
		
		If ContractData = Undefined Then
			
			ContractData = GetDataContractOnChange(Object.Date, Object.DocumentCurrency, Object.Contract);
			
		EndIf;
		
		ModifiedSupplierPriceTypes = Object.SupplierPriceTypes <> ContractData.SupplierPriceTypes AND ValueIsFilled(ContractData.SupplierPriceTypes);
		QuestionSupplierPriceTypes = (ValueIsFilled(Object.Contract) AND ModifiedSupplierPriceTypes);
		
		SettlementsCurrencyBeforeChange = SettlementsCurrency;
		SettlementsCurrency = ContractData.SettlementsCurrency;
		
		NewContractAndCalculationCurrency = ValueIsFilled(Object.Contract) AND ValueIsFilled(SettlementsCurrency) 
			AND Object.Contract <> ContractBeforeChange AND SettlementsCurrencyBeforeChange <> ContractData.SettlementsCurrency;
		OpenFormPricesAndCurrencies = NewContractAndCalculationCurrency AND Object.DocumentCurrency <> ContractData.SettlementsCurrency
			AND Object.Inventory.Count() > 0;
		
		DocumentParameters = New Structure;
		DocumentParameters.Insert("ContractBeforeChange", ContractBeforeChange);
		DocumentParameters.Insert("SettlementsCurrencyBeforeChange", SettlementsCurrencyBeforeChange);
		DocumentParameters.Insert("ContractData", ContractData);
		DocumentParameters.Insert("QuestionSupplierPriceTypes", QuestionSupplierPriceTypes);
		DocumentParameters.Insert("ModifiedSupplierPriceTypes", ModifiedSupplierPriceTypes);
		DocumentParameters.Insert("OpenFormPricesAndCurrencies", OpenFormPricesAndCurrencies);
		
		HandleCounterpartiesPriceKindChangeAndSettlementsCurrency(DocumentParameters);
		
		FillPaymentCalendarFromContract(SwitchTypeListOfPaymentCalendar);
		UpdatePaymentCalendar();
		
	EndIf;
	
EndProcedure

// Procedure recalculates subtotal the document on client.
&AtClient
Procedure RecalculateSubtotal()
	
	DocumentSubtotal = Object.Inventory.Total("Total") - Object.Inventory.Total("VATAmount");
	
EndProcedure

&AtClient
Procedure ClearPaymentCalendarContinue(Answer, Parameters) Export
	If Answer = DialogReturnCode.Yes Then
		Object.PaymentCalendar.Clear();
		SetEnableGroupPaymentCalendarDetails();
	ElsIf Answer = DialogReturnCode.No Then
		Object.SetPaymentTerms = True;
	EndIf;
EndProcedure

&AtServer
Procedure FillThePaymentCalendarOnServer()
	
	FillPaymentCalendarFromContract(SwitchTypeListOfPaymentCalendar);
	
	If Object.PaymentCalendar.Count() = 0 Then
		NewRow = Object.PaymentCalendar.Add();
		
		NewRow.PaymentPercentage = 100;
		NewRow.PaymentAmount = Object.Inventory.Total("Amount");
		NewRow.PaymentVATAmount = Object.Inventory.Total("VATAmount");
	EndIf;
	
EndProcedure

&AtServer
Procedure SetSwitchTypeListOfPaymentCalendar()
	
	If Object.PaymentCalendar.Count() > 1 Then
		SwitchTypeListOfPaymentCalendar = 1;
	Else
		SwitchTypeListOfPaymentCalendar = 0;
	EndIf;
	
EndProcedure

// Procedure - event handler OnChange of the SwitchTypeListOfPaymentCalendar field.
//
&AtClient
Procedure FieldSwitchTypeListOfPaymentCalendarOnChange(Item)
	
	LineCount = Object.PaymentCalendar.Count();
	
	If Not SwitchTypeListOfPaymentCalendar AND LineCount > 1 Then
		Response = Undefined;
		ShowQueryBox(
			New NotifyDescription("SetEditInListEndOption", ThisObject, New Structure("LineCount", LineCount)),
			NStr("en = 'All lines except for the first one will be deleted. Continue?'"),
			QuestionDialogMode.YesNo);
		Return;
	EndIf;
	
	SetVisiblePaymentCalendar();
	
EndProcedure

&AtClient
Procedure UpdatePaymentCalendar()
	
	SetEnableGroupPaymentCalendarDetails();
	SetVisiblePaymentCalendar();
	SetVisibleCashAssetsTypes();
	
EndProcedure

#EndRegion

#Region ProceduresAndFunctionsForControlOfTheFormAppearance

// Sets the current page for document operation kind.
//
// Parameters:
// BusinessOperation - EnumRef.EconomicOperations - Economic operations
//
&AtClient
Procedure SetVisibleCashAssetsTypes()
	
	PageName = "";
	
	If Object.CashAssetsType = PredefinedValue("Enum.CashAssetTypes.Noncash") Then
		PageName = "PageBankAccount";
	ElsIf Object.CashAssetsType = PredefinedValue("Enum.CashAssetTypes.Cash") Then
		PageName = "PagePettyCash";
	EndIf;  

	PageItem = Items.Find(PageName);
	If PageItem <> Undefined Then
		Items.CashboxBankAccount.Visible = True;
		Items.CashboxBankAccount.CurrentPage = PageItem;
	Else
		Items.CashboxBankAccount.Visible = False;
	EndIf;
	
EndProcedure

// Procedure sets availability of the form items.
//
&AtClient
Procedure SetEnableGroupPaymentCalendarDetails()
	
	Items.GroupPaymentCalendarDetails.Enabled = Object.SetPaymentTerms;
	
EndProcedure

&AtClient
Procedure SetEditInListEndOption(Result, AdditionalParameters) Export
	
	LineCount = AdditionalParameters.LineCount;
	
	If Result = DialogReturnCode.No Then
		SwitchTypeListOfPaymentCalendar = True;
		Return;
	EndIf;
	
	While LineCount > 1 Do
		Object.PaymentCalendar.Delete(Object.PaymentCalendar[LineCount - 1]);
		LineCount = LineCount - 1;
	EndDo;
	Items.PaymentCalendar.CurrentRow = Object.PaymentCalendar[0].GetID();
	
	SetVisiblePaymentCalendar();

EndProcedure

&AtClient
Procedure SetVisiblePaymentCalendar()
	
	If SwitchTypeListOfPaymentCalendar Then
		Items.GroupPaymentCalendarListString.CurrentPage = Items.GroupPaymentCalendarList;
	Else
		Items.GroupPaymentCalendarListString.CurrentPage = Items.GroupBillingCalendarString;
	EndIf;
	
EndProcedure

&AtServer
Procedure FillPaymentCalendarFromContract(TypeListOfPaymentCalendar)
	
	Document = FormAttributeToValue("Object");
	Document.FillPaymentCalendarFromContract();
	ValueToFormAttribute(Document, "Object");
	Modified = True;
	
	TypeListOfPaymentCalendar = Number(Object.PaymentCalendar.Count() > 1);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES FOR WORK WITH THE SELECTION

// Procedure - event handler Action of the Pick command
//
&AtClient
Procedure Pick(Command)
	
	TabularSectionName	= "Inventory";
	DocumentPresentaion	= NStr("en = 'RFQ response'");
	SelectionParameters	= DriveClient.GetSelectionParameters(ThisObject, TabularSectionName, DocumentPresentaion, False, False, False);
	SelectionParameters.Insert("Company", Counterparty);
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

// Function gets a product list from the temporary storage
//
&AtServer
Procedure GetInventoryFromStorage(InventoryAddressInStorage, TabularSectionName, AreCharacteristics, AreBatches)
	
	TableForImport = GetFromTempStorage(InventoryAddressInStorage);
	
	For Each ImportRow In TableForImport Do
		
		NewRow = Object[TabularSectionName].Add();
		FillPropertyValues(NewRow, ImportRow);
		
		StructureData = New Structure();
		
		StructureData.Insert("Company", 	 Counterparty);
		StructureData.Insert("ProcessingDate",	 Object.Date);
		StructureData.Insert("SupplierPriceTypes",Object.SupplierPriceTypes);
		StructureData.Insert("DocumentCurrency",	 Object.DocumentCurrency);
		StructureData.Insert("AmountIncludesVAT", Object.AmountIncludesVAT);
		StructureData.Insert("Products",	 NewRow.Products);
		StructureData.Insert("Characteristic",	 NewRow.Characteristic);
		StructureData.Insert("Factor",		 1);
		StructureData.Insert("VATTaxation", Object.VATTaxation);
		
		StructureData = GetDataProductsOnChange(StructureData);
		
		NewRow.VATRate			= StructureData.VATRate;
		NewRow.Content			= "";
		
		VATRate = DriveReUse.GetVATRateValue(NewRow.VATRate);
		
		NewRow.VATAmount = ?(StructureData.AmountIncludesVAT, 
										NewRow.Amount - (NewRow.Amount) / ((VATRate + 100) / 100),
										NewRow.Amount * VATRate / 100);
										
		NewRow.Total = NewRow.Amount + ?(StructureData.AmountIncludesVAT, 0, NewRow.VATAmount);
		
	EndDo;
	
EndProcedure

// Procedure of processing the results of selection closing
//
&AtClient
Procedure OnCloseSelection(ClosingResult, AdditionalParameters) Export
	
	If TypeOf(ClosingResult) = Type("Structure") Then
		
		If Not IsBlankString(ClosingResult.CartAddressInStorage) Then
			
			InventoryAddressInStorage = ClosingResult.CartAddressInStorage;
			
			GetInventoryFromStorage(InventoryAddressInStorage, "Inventory", True, True);
			
			// Payment calendar.
			RecalculatePaymentCalendar();
			RecalculateSubtotal();
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region ProcedureFormEventHandlers

// Procedure - OnCreateAtServer event handler.
// The procedure implements
// - form attribute initialization,
// - setting of the form functional options parameters.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	DriveServer.FillDocumentHeader(
		Object,
		,
		Parameters.CopyingValue,
		Parameters.Basis,
		PostingIsAllowed,
		Parameters.FillingValues
	);
	
	// Initialization of form attributes.
	If Not ValueIsFilled(Object.Ref)
	   AND Not ValueIsFilled(Parameters.CopyingValue) Then
		
		Query = New Query(
		"SELECT
		|	CASE
		|		WHEN Companies.BankAccountByDefault.CashCurrency = &CashCurrency
		|			THEN Companies.BankAccountByDefault
		|		ELSE UNDEFINED
		|	END AS BankAccount
		|FROM
		|	Catalog.Companies AS Companies
		|WHERE
		|	Companies.Ref = &Company");
		Query.SetParameter("Company", Object.Company);
		Query.SetParameter("CashCurrency", Object.DocumentCurrency);
		QueryResult = Query.Execute();
		Selection = QueryResult.Select();
		If Selection.Next() Then
			Object.BankAccount = Selection.BankAccount;
		EndIf;
		Object.PettyCash = Catalogs.CashAccounts.GetPettyCashByDefault(Object.Company);
		
		If ValueIsFilled(Object.Counterparty) Then
			If Not ValueIsFilled(Object.Contract) Then
				Object.Contract = Object.Counterparty.ContractByDefault;
			EndIf;
			If ValueIsFilled(Object.Contract) Then
				Object.DocumentCurrency = Object.Contract.SettlementsCurrency;
				SettlementsCurrencyRateRepetition = InformationRegisters.ExchangeRates.GetLast(Object.Date, New Structure("Currency", Object.Contract.SettlementsCurrency));
				Object.ExchangeRate      = ?(SettlementsCurrencyRateRepetition.ExchangeRate = 0, 1, SettlementsCurrencyRateRepetition.ExchangeRate);
				Object.Multiplicity = ?(SettlementsCurrencyRateRepetition.Multiplicity = 0, 1, SettlementsCurrencyRateRepetition.Multiplicity);
				If Not ValueIsFilled(Object.SupplierPriceTypes) Then
					Object.SupplierPriceTypes = Object.Contract.SupplierPriceTypes;
				EndIf;
			EndIf;
		EndIf;
		
	EndIf;
	
	ParentCompany = DriveServer.GetCompany(Object.Company);
	
	DocumentDate = Object.Date;
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentDate();
	EndIf;
	
	Object.VATTaxation = DriveServer.CounterpartyVATTaxation(Object.Counterparty, DriveServer.VATTaxation(Object.Company, Object.Date));
	
	Contract = Object.Contract;
	SettlementsCurrency = Object.Contract.SettlementsCurrency;
	FunctionalCurrency = Constants.FunctionalCurrency.Get();
	StructureByCurrency = InformationRegisters.ExchangeRates.GetLast(Object.Date, New Structure("Currency", FunctionalCurrency));
	RateNationalCurrency = StructureByCurrency.ExchangeRate;
	RepetitionNationalCurrency = StructureByCurrency.Multiplicity;
	
	If Not ValueIsFilled(Object.Ref)
		AND Not ValueIsFilled(Parameters.Basis) 
		AND Not ValueIsFilled(Parameters.CopyingValue) Then
		FillVATRateByVATTaxation();			
	ElsIf Object.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then	
		Items.InventoryVATRate.Visible = True;
		Items.InventoryVATAmount.Visible = True;
		Items.InventoryAmountTotal.Visible = True;
		Items.PaymentCalendarPayVATAmount.Visible = True;
		Items.ListPaymentsCalendarSumVatOfPayment.Visible = True;
		Items.DocumentTax.Visible = True;
	Else
		Items.InventoryVATRate.Visible = False;
		Items.InventoryVATAmount.Visible = False;
		Items.InventoryAmountTotal.Visible = False;
		Items.PaymentCalendarPayVATAmount.Visible = False;
		Items.ListPaymentsCalendarSumVatOfPayment.Visible = False;
		Items.DocumentTax.Visible = False;
	EndIf;
	
	// Generate price and currency label.
	ForeignExchangeAccounting = Constants.ForeignExchangeAccounting.Get();
	LabelStructure = New Structure("SupplierPriceTypes, DocumentCurrency, SettlementsCurrency, ExchangeRate, AmountIncludesVAT, ForeignExchangeAccounting, RateNationalCurrency, VATTaxation", Object.SupplierPriceTypes, Object.DocumentCurrency, SettlementsCurrency, Object.ExchangeRate, Object.AmountIncludesVAT, ForeignExchangeAccounting, RateNationalCurrency, Object.VATTaxation);
	PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
	
	// Setting contract visible.
	SetContractVisible();
	
	// StandardSubsystems.ObjectVersioning
	ObjectVersioning.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.ObjectVersioning
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisForm, Items.ImportantCommandsGroup);
	// End StandardSubsystems.Printing
	
	// StandardSubsystems.Properties
	PropertiesManagement.OnCreateAtServer(ThisForm, Object, "AdditionalAttributesGroup");
	// End StandardSubsystems.Properties
	
	// Peripherals
	UsePeripherals = DriveReUse.UsePeripherals();
	ListOfElectronicScales = EquipmentManagerServerCall.GetEquipmentList("ElectronicScales", , EquipmentManagerServerCall.GetClientWorkplace());
	If ListOfElectronicScales.Count() = 0 Then
		// There are no connected scales.
		Items.InventoryGetWeight.Visible = False;
	EndIf;
	Items.InventoryImportDataFromDCT.Visible = UsePeripherals;
	// End Peripherals
	
	SwitchTypeListOfPaymentCalendar = ?(Object.PaymentCalendar.Count() > 1, 1, 0);
	
EndProcedure

// Procedure - OnReadAtServer event handler.
//
&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	ClosingDates.ObjectOnReadAtServer(ThisForm, CurrentObject);
	
	// StandardSubsystems.Properties
	PropertiesManagement.OnReadAtServer(ThisForm, CurrentObject);
	// End StandardSubsystems.Properties
	
	SetSwitchTypeListOfPaymentCalendar();
	
EndProcedure

// Procedure - "AfterWrite" event handler of the forms.
//
&AtClient
Procedure AfterWrite()
	
	Notify();
	
EndProcedure

// Procedure - form event handler "OnOpen".
//
&AtClient
Procedure OnOpen(Cancel)
	
	// Peripherals
	EquipmentManagerClientOverridable.StartConnectingEquipmentOnFormOpen(ThisForm, "BarCodeScanner");
	// End Peripherals
	
	SetVisiblePaymentCalendar();
	SetVisibleCashAssetsTypes();
	SetEnableGroupPaymentCalendarDetails();
	
	RecalculateSubtotal();
	
EndProcedure

&AtClient
// Procedure - event handler of the form BeforeWrite
//
Procedure BeforeWrite(Cancel, WriteParameters)
	
	// StandardSubsystems.PerformanceMeasurement
	PerformanceEstimationClientServer.StartTimeMeasurement("DocumentSupplierQuotePosting");
	// StandardSubsystems.PerformanceMeasurement
	
EndProcedure

// Procedure - event handler OnClose.
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
	
	// Properties subsystem
	If PropertiesManagementClient.ProcessAlerts(ThisForm, EventName, Parameter) Then
		
		UpdateAdditionalAttributesItems();
		
	EndIf;
	
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
	
	If EventName = "AfterRecordingOfCounterparty" 
		AND ValueIsFilled(Parameter)
		AND Object.Counterparty = Parameter Then
		
		SetContractVisible();
		
	EndIf;
	
EndProcedure

&AtServer
// Procedure-handler of the BeforeWriteAtServer event.
// 
//
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	If WriteParameters.WriteMode = DocumentWriteMode.Posting Then
		
		MessageText = "";
		CheckContractToDocumentConditionAccordance(MessageText, Object.Contract, Object.Ref, Object.Company, Object.Counterparty, Cancel);
		
		If MessageText <> "" Then
			
			Message = New UserMessage;
			Message.Text = ?(Cancel, NStr("en = 'Document is not posted. '") + MessageText, MessageText);
			
			If Cancel Then
				Message.DataPath = "Object";
				Message.Field = "Contract";
				Message.Message();
				Return;
			Else
				Message.Message();
			EndIf;
		EndIf;
		
	EndIf;
	
	// "Properties" mechanism handler
	PropertiesManagement.BeforeWriteAtServer(ThisForm, CurrentObject);
	// "Properties" mechanism handler
	
EndProcedure

&AtServer
// Procedure-handler of the FillCheckProcessingAtServer event.
//
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	// StandardSubsystems.Properties
	PropertiesManagement.FillCheckProcessing(ThisForm, Cancel, CheckedAttributes);
	// End StandardSubsystems.Properties
	
EndProcedure

#EndRegion

#Region ProcedureActionsOfTheFormCommandPanels

// Procedure is called by clicking the PricesCurrency button of the command bar tabular field.
//
&AtClient
Procedure EditPricesAndCurrency(Item, StandardProcessing)
	
	StandardProcessing = False;
	ProcessChangesOnButtonPricesAndCurrencies(Object.DocumentCurrency);
	Modified = True;
	
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
    
    // Payment calendar.
    RecalculatePaymentCalendar();
	RecalculateSubtotal();

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
			RecalculatePaymentCalendar();
			RecalculateSubtotal();
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
#EndRegion

#Region ProcedureEventHandlersOfHeaderAttributes

// Procedure - event handler OnChange of the Date input field.
// In procedure situation is determined when date change document is
// into document numbering another period and in this case
// assigns to the document new unique number.
// Overrides the corresponding form parameter.
//
&AtClient
Procedure DateOnChange(Item)
	
	// Date change event DataProcessor.
	DateBeforeChange = DocumentDate;
	DocumentDate = Object.Date;
	If Object.Date <> DateBeforeChange Then
		StructureData = GetDataDateOnChange(Object.Ref, Object.Date, DateBeforeChange, SettlementsCurrency);
		If StructureData.DATEDIFF <> 0 Then
			Object.Number = "";
		EndIf;
		
		If ValueIsFilled(SettlementsCurrency) Then
			RecalculateExchangeRateMultiplicitySettlementCurrency(StructureData);
		EndIf;	
		
		RecalculatePaymentDate(DateBeforeChange, Object.Date);
	EndIf;
	
EndProcedure

// Receives the data set from the server for the CompanyOnChange procedure.
//
&AtServer
Function GetCompanyDataOnChange(Company)
	
	StructureData = New Structure();
	
	StructureData.Insert("Counterparty",					DriveServer.GetCompany(Company));
	StructureData.Insert("BankAccount",						Company.BankAccountByDefault);
	StructureData.Insert("BankAccountCashAssetsCurrency",	Company.BankAccountByDefault.CashCurrency);
	
	TaxationBeforeChange = Object.VATTaxation;
	
	Object.VATTaxation = DriveServer.CounterpartyVATTaxation(Object.Counterparty, DriveServer.VATTaxation(Object.Company, Object.Date));
	
	If Not TaxationBeforeChange = Object.VATTaxation Then
		FillVATRateByVATTaxation();
	EndIf;
	
	Return StructureData;
	
EndFunction

// Procedure - event handler OnChange of the Company input field.
// In procedure is executed document
// number clearing and also make parameter set of the form functional options.
// Overrides the corresponding form parameter.
//
&AtClient
Procedure CompanyOnChange(Item)
	
	// Company change event data processor.
	Object.Number = "";
	
	Object.Contract = GetContractByDefault(Object.Ref, Object.Counterparty, Object.Company);
	ProcessContractChange();
	
	StructureData = GetCompanyDataOnChange(Object.Company);
	Counterparty = StructureData.Counterparty;
	If Object.DocumentCurrency = StructureData.BankAccountCashAssetsCurrency Then
		Object.BankAccount = StructureData.BankAccount;
	EndIf;
	
	LabelStructure = New Structure("DocumentCurrency, SettlementsCurrency, ExchangeRate, 
		|RateNationalCurrency, AmountIncludesVAT, ForeignExchangeAccounting, 
		|SupplierPriceTypes, VATTaxation", 
		Object.DocumentCurrency, SettlementsCurrency, Object.ExchangeRate, 
		RateNationalCurrency, Object.AmountIncludesVAT, ForeignExchangeAccounting, 
		Object.SupplierPriceTypes, Object.VATTaxation);
		
	PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);	
	
EndProcedure

// Procedure - event handler OnChange input field CashAssetsType.
//
&AtClient
Procedure CashAssetsTypeOnChange(Item)
	
	SetVisibleCashAssetsTypes();

EndProcedure

// Procedure - event handler OnChange of the Counterparty input field.
// Clears the contract and tabular section.
//
&AtClient
Procedure CounterpartyOnChange(Item)
	
	CounterpartyBeforeChange = Counterparty;
	Counterparty = Object.Counterparty;
	
	If CounterpartyBeforeChange <> Object.Counterparty Then
		
		StructureData = GetDataCounterpartyOnChange(Object.Date, Object.DocumentCurrency, Object.Counterparty, Object.Company);
		
		Object.Contract = StructureData.Contract;
		ProcessContractChange(StructureData);
		UpdatePaymentCalendar();
		
	Else
		
		Object.Contract = Contract; // Restore the cleared contract automatically.
		
	EndIf;
	
EndProcedure

// The OnChange event handler of the Contract field.
// It updates the currency exchange rate and exchange rate multiplier.
//
&AtClient
Procedure ContractOnChange(Item)
	
	ProcessContractChange();
	
EndProcedure

// Procedure - event handler StartChoice of the Contract input field.
//
&AtClient
Procedure ContractStartChoice(Item, ChoiceData, StandardProcessing)
	
	FormParameters = GetChoiceFormOfContractParameters(Object.Ref, Object.Company, Object.Counterparty, Object.Contract);
	If FormParameters.ControlContractChoice Then
		
		StandardProcessing = False;
		OpenForm("Catalog.CounterpartyContracts.Form.ChoiceForm", FormParameters, Item);
		
	EndIf;
	
EndProcedure

// Procedure - event handler SelectionStart input field BankAccount.
//
&AtClient
Procedure BankAccountStartChoice(Item, ChoiceData, StandardProcessing)
	
	If Not ValueIsFilled(Object.Contract) Then
		Return;
	EndIf;
	
	FormParameters = GetChoiceFormParametersBankAccount(Object.Contract, Object.Company, FunctionalCurrency);
	If FormParameters.SettlementsInStandardUnits Then
		
		StandardProcessing = False;
		OpenForm("Catalog.BankAccounts.ChoiceForm", FormParameters, Item);
		
	EndIf;
	
EndProcedure

// Procedure - event handler OnChange of the ReflectInPaymentCalendar input field.
//
&AtClient
Procedure SchedulePayOnChange(Item)
	
	If Object.SetPaymentTerms Then
		
		FillThePaymentCalendarOnServer();
		SetEnableGroupPaymentCalendarDetails();
		SetVisiblePaymentCalendar();
		SetVisibleCashAssetsTypes();
		
	Else
		
		Notify = New NotifyDescription("ClearPaymentCalendarContinue", ThisObject);
		
		QueryText = NStr("en = 'The payment terms will be cleared. Do you want to continue?'");
		ShowQueryBox(Notify, QueryText,  QuestionDialogMode.YesNo);
		
	EndIf;

EndProcedure

// Procedure - event handler OnChange of the PaymentCalendarPaymentPercent input field.
//
&AtClient
Procedure PaymentCalendarPaymentPercentageOnChange(Item)
	
	InventoryTotal = Object.Inventory.Total("Amount");
	InventoryVATAmount = Object.Inventory.Total("VATAmount");
	
	CurrentRow = Items.PaymentCalendar.CurrentData;
	CurrentRow.PaymentAmount = Round(InventoryTotal * CurrentRow.PaymentPercentage / 100, 2, 1);
	CurrentRow.PaymentVATAmount = Round(InventoryVATAmount * CurrentRow.PaymentPercentage / 100, 2, 1);
	
EndProcedure

// Procedure - event handler OnChange of the PaymentCalendarPaymentAmount input field.
//
&AtClient
Procedure PaymentCalendarPaymentSumOnChange(Item)
	
	CurrentRow = Items.PaymentCalendar.CurrentData;
	
	InventoryTotal = Object.Inventory.Total("Amount");
	InventoryVATAmount = Object.Inventory.Total("VATAmount");
	
	CurrentRow.PaymentPercentage = ?(InventoryTotal = 0, 0, Round(CurrentRow.PaymentAmount / InventoryTotal * 100, 2, 1));
	CurrentRow.PaymentVATAmount = Round(InventoryVATAmount * CurrentRow.PaymentPercentage / 100, 2, 1);
	
EndProcedure

// Procedure - event handler OnChange of the PaymentCalendarPayVATAmount input field.
//
&AtClient
Procedure PaymentCalendarPayVATAmountOnChange(Item)
	
	CurrentRow = Items.PaymentCalendar.CurrentData;
	
	InventoryTotal = Object.Inventory.Total("VATAmount");
	PaymentCalendarTotal = Object.PaymentCalendar.Total("PaymentVATAmount");
	
	If PaymentCalendarTotal > InventoryTotal Then
		CurrentRow.PaymentVATAmount = CurrentRow.PaymentVATAmount - (PaymentCalendarTotal - InventoryTotal);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - TABULAR SECTION ATTRIBUTE EVENT HANDLERS

// Procedure - OnEditEnd event handler of the Inventory tabular section.
//
&AtClient
Procedure InventoryOnEditEnd(Item, NewRow, CancelEdit)
	
	// Payment calendar.
	RecalculatePaymentCalendar();
	RecalculateSubtotal();

EndProcedure

// Procedure - AfterDeletion event handler of the Inventory tabular section.
//
&AtClient
Procedure InventoryAfterDeleteRow(Item)
	
	// Payment calendar.
	RecalculatePaymentCalendar();
	RecalculateSubtotal();
	
EndProcedure

// Procedure - event handler OnChange of the Products input field.
//
&AtClient
Procedure InventoryProductsOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	StructureData = New Structure();
	
	StructureData.Insert("Company", 	 Counterparty);
	StructureData.Insert("ProcessingDate",	 Object.Date);
	StructureData.Insert("SupplierPriceTypes", Object.SupplierPriceTypes);
	StructureData.Insert("DocumentCurrency",	 Object.DocumentCurrency);
	StructureData.Insert("AmountIncludesVAT", Object.AmountIncludesVAT);
	StructureData.Insert("Products",	 TabularSectionRow.Products);
	StructureData.Insert("Characteristic",	 TabularSectionRow.Characteristic);
	StructureData.Insert("Factor",		 1);
	StructureData.Insert("VATTaxation", Object.VATTaxation);
	
	StructureData = GetDataProductsOnChange(StructureData);
	
	TabularSectionRow.MeasurementUnit = StructureData.MeasurementUnit;
	TabularSectionRow.Quantity = 1;
	TabularSectionRow.Price = StructureData.Price;
	TabularSectionRow.VATRate = StructureData.VATRate;
	TabularSectionRow.Content = "";
	
	CalculateAmountInTabularSectionLine();
	RecalculateSubtotal();
	
EndProcedure

// Procedure - event handler OnChange of the Characteristic input field.
//
&AtClient
Procedure InventoryCharacteristicOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	StructureData = New Structure();
	
	StructureData.Insert("ProcessingDate",	 	Object.Date);
	StructureData.Insert("SupplierPriceTypes",	Object.SupplierPriceTypes);
	StructureData.Insert("DocumentCurrency",	 	Object.DocumentCurrency);
	StructureData.Insert("AmountIncludesVAT", 	Object.AmountIncludesVAT);
	
	StructureData.Insert("VATRate", 			TabularSectionRow.VATRate);
	StructureData.Insert("Products",	 	TabularSectionRow.Products);
	StructureData.Insert("Characteristic",	 	TabularSectionRow.Characteristic);
	StructureData.Insert("MeasurementUnit", 	TabularSectionRow.MeasurementUnit);
	
	StructureData = GetDataCharacteristicOnChange(StructureData);
	
	TabularSectionRow.Price = StructureData.Price;
	TabularSectionRow.Content = "";
	CalculateAmountInTabularSectionLine();
	RecalculateSubtotal();
	
EndProcedure

// Procedure - event handler AutoPick of the Content input field.
//
&AtClient
Procedure InventoryContentAutoComplete(Item, Text, ChoiceData, Parameters, Wait, StandardProcessing)
	
	If Wait = 0 Then
		
		StandardProcessing = False;
		
		TabularSectionRow = Items.Inventory.CurrentData;
		ContentPattern = DriveServer.GetContentText(TabularSectionRow.Products, TabularSectionRow.Characteristic);
		
		ChoiceData = New ValueList;
		ChoiceData.Add(ContentPattern);
		
	EndIf;
	
EndProcedure

// Procedure - event handler OnChange of the Count input field.
//
&AtClient
Procedure InventoryQuantityOnChange(Item)
	
	CalculateAmountInTabularSectionLine();
	RecalculateSubtotal();
	
	// Payment calendar.
	RecalculatePaymentCalendar();
	
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
	
	If StructureData.CurrentFactor <> 0 Then
		TabularSectionRow.Price = TabularSectionRow.Price * StructureData.Factor / StructureData.CurrentFactor;
	EndIf;
	
	CalculateAmountInTabularSectionLine();
	RecalculateSubtotal();
	
EndProcedure

// Procedure - event handler OnChange of the Price input field.
//
&AtClient
Procedure InventoryPriceOnChange(Item)
	
	CalculateAmountInTabularSectionLine();
	RecalculateSubtotal();
	
	// Payment calendar.
	RecalculatePaymentCalendar();
	
EndProcedure

// Procedure - event handler OnChange of the Amount input field.
//
&AtClient
Procedure InventoryAmountOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	If TabularSectionRow.Quantity <> 0 Then
		TabularSectionRow.Price = TabularSectionRow.Amount / TabularSectionRow.Quantity;
	EndIf;
	
	CalculateVATSUM(TabularSectionRow);
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
	// Payment calendar.
	RecalculatePaymentCalendar();
	RecalculateSubtotal();
	
EndProcedure

// Procedure - event handler OnChange of the VATRate input field.
//
&AtClient
Procedure InventoryVATRateOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	CalculateVATSUM(TabularSectionRow);
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
	// Payment calendar.
	RecalculatePaymentCalendar();
	RecalculateSubtotal();
	
EndProcedure

// Procedure - event handler OnChange of the VATRate input field.
//
&AtClient
Procedure InventoryVATAmountOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
	// Payment calendar.
	RecalculatePaymentCalendar();
	RecalculateSubtotal();
	
EndProcedure

// Procedure - OnStartEdit event handler of the .PaymentCalendar list
//
&AtClient
Procedure PaymentCalendarOnStartEdit(Item, NewRow, Copy)
	
	CurrentRow = Items.PaymentCalendar.CurrentData;
	
	If CurrentRow.PaymentPercentage = 0 Then
		CurrentRow.PaymentPercentage = 100 - Object.PaymentCalendar.Total("PaymentPercentage");
		CurrentRow.PaymentAmount = Object.Inventory.Total("Amount") - Object.PaymentCalendar.Total("PaymentAmount");
		CurrentRow.PaymentVATAmount = Object.Inventory.Total("VATAmount") - Object.PaymentCalendar.Total("PaymentVATAmount");
	EndIf;

EndProcedure

// Procedure - BeforeDeletion event handler of the PaymentCalendar tabular section.
//
&AtClient
Procedure PaymentCalendarBeforeDelete(Item, Cancel)
	
	If Object.PaymentCalendar.Count() = 1 Then
		Cancel = True;
	EndIf;
	
EndProcedure

#Region InteractiveActionResultHandlers

&AtClient
// Procedure-handler of the result of opening the "Prices and currencies" form
//
Procedure OpenPricesAndCurrencyFormEnd(ClosingResult, AdditionalParameters) Export
	
	If TypeOf(ClosingResult) = Type("Structure") 
		AND ClosingResult.WereMadeChanges Then
		
		If Object.DocumentCurrency <> ClosingResult.DocumentCurrency Then
			
			Object.BankAccount = Undefined;
			
		EndIf;
		
		Object.SupplierPriceTypes = ClosingResult.SupplierPriceTypes;
		Object.DocumentCurrency = ClosingResult.DocumentCurrency;
		Object.ExchangeRate = ClosingResult.PaymentsRate;
		Object.Multiplicity = ClosingResult.SettlementsMultiplicity;
		Object.AmountIncludesVAT = ClosingResult.AmountIncludesVAT;
		Object.VATTaxation = ClosingResult.VATTaxation;
		SettlementsCurrencyBeforeChange = AdditionalParameters.SettlementsCurrencyBeforeChange;
		
		// Recalculate prices by kind of prices.
		If ClosingResult.RefillPrices Then
			DriveClient.RefillTabularSectionPricesBySupplierPriceTypes(ThisForm, "Inventory");
		EndIf;
		
		// Recalculate prices by currency.
		If Not ClosingResult.RefillPrices
			  AND ClosingResult.RecalculatePrices Then
			DriveClient.RecalculateTabularSectionPricesByCurrency(ThisForm, SettlementsCurrencyBeforeChange, "Inventory");
		EndIf;
		
		// Recalculate the amount if VAT taxation flag is changed.
		If ClosingResult.VATTaxation <> ClosingResult.PrevVATTaxation Then
			FillVATRateByVATTaxation();
		EndIf;
		
		// Recalculate the amount if the "Amount includes VAT" flag is changed.
		If Not ClosingResult.RefillPrices
			AND Not ClosingResult.AmountIncludesVAT = ClosingResult.PrevAmountIncludesVAT Then
			DriveClient.RecalculateTabularSectionAmountByFlagAmountIncludesVAT(ThisForm, "Inventory");
		EndIf;
		
	EndIf;
	
	LabelStructure = New Structure("SupplierPriceTypes, DocumentCurrency, SettlementsCurrency, ExchangeRate, AmountIncludesVAT, ForeignExchangeAccounting, RateNationalCurrency, VATTaxation",
		Object.SupplierPriceTypes,
		Object.DocumentCurrency,
		SettlementsCurrency,
		Object.ExchangeRate,
		Object.AmountIncludesVAT,
		ForeignExchangeAccounting,
		RateNationalCurrency,
		Object.VATTaxation);
		
	PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
	
	RecalculatePaymentCalendar();
	RecalculateSubtotal();
	
EndProcedure

&AtClient
// Procedure-handler response on question about document recalculate by contract data
//
Procedure DefineDocumentRecalculateNeedByContractTerms(ClosingResult, AdditionalParameters) Export
	
	If ClosingResult = DialogReturnCode.Yes Then
		
		ContractData = AdditionalParameters.ContractData;
		Object.SupplierPriceTypes = ContractData.SupplierPriceTypes;
		
		LabelStructure = New Structure("DocumentCurrency, SettlementsCurrency, ExchangeRate, RateNationalCurrency, AmountIncludesVAT, ForeignExchangeAccounting, SupplierPriceTypes, VATTaxation",
			Object.DocumentCurrency,
			SettlementsCurrency,
			Object.ExchangeRate,
			RateNationalCurrency,
			Object.AmountIncludesVAT,
			ForeignExchangeAccounting,
			Object.SupplierPriceTypes,
			Object.VATTaxation);
			
		PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
		
		// Recalculate prices by kind of prices.
		If Object.Inventory.Count() > 0 Then
			
			DriveClient.RefillTabularSectionPricesBySupplierPriceTypes(ThisForm, "Inventory");
			
		EndIf;
		
		RecalculatePaymentCalendar();
		RecalculateSubtotal();
		
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
// End StandardSubsystems.Printing

// StandardSubsystems.Properties
&AtClient
Procedure Attachable_EditContentOfProperties(Command)
	
	PropertiesManagementClient.EditContentOfProperties(ThisForm, Object.Ref);
	
EndProcedure

&AtServer
Procedure UpdateAdditionalAttributesItems()
	
	PropertiesManagement.UpdateAdditionalAttributesItems(ThisForm, FormAttributeToValue("Object"));
	
EndProcedure

// End StandardSubsystems.Properties

#EndRegion

#EndRegion
