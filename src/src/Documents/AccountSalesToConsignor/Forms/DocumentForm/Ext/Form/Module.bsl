#Region GeneralPurposeProceduresAndFunctions

&AtClient
// The procedure handles the change of the Price kind and Settlement currency document attributes
//
Procedure HandleCounterpartiesPriceKindChangeAndSettlementsCurrency(DocumentParameters)
	
	ContractBeforeChange = DocumentParameters.ContractBeforeChange;
	SettlementsCurrencyBeforeChange = DocumentParameters.SettlementsCurrencyBeforeChange;
	ContractData = DocumentParameters.ContractData;
	PriceKindChanged = DocumentParameters.PriceKindChanged;
	QuestionSupplierPriceTypes = DocumentParameters.QuestionSupplierPriceTypes;
	OpenFormPricesAndCurrencies = DocumentParameters.OpenFormPricesAndCurrencies;
	
	If Not ContractData.AmountIncludesVAT = Undefined Then
		
		Object.AmountIncludesVAT = ContractData.AmountIncludesVAT;
		
	EndIf;
	
	If ValueIsFilled(Object.Contract) Then 
		Object.ExchangeRate      = ?(ContractData.SettlementsCurrencyRateRepetition.ExchangeRate = 0, 1, ContractData.SettlementsCurrencyRateRepetition.ExchangeRate);
		Object.Multiplicity = ?(ContractData.SettlementsCurrencyRateRepetition.Multiplicity = 0, 1, ContractData.SettlementsCurrencyRateRepetition.Multiplicity);
	EndIf;
	
	If PriceKindChanged Then
		
		Object.SupplierPriceTypes = ContractData.SupplierPriceTypes;
		
	EndIf;
	
	LabelStructure = New Structure("DocumentCurrency, SettlementsCurrency, ExchangeRate, RateNationalCurrency, AmountIncludesVAT, ForeignExchangeAccounting, SupplierPriceTypes, VATTaxation", 
		Object.DocumentCurrency, 
		SettlementsCurrency, 
		Object.ExchangeRate, 
		RateNationalCurrency, 
		Object.AmountIncludesVAT, 
		ForeignExchangeAccounting, 
		Object.SupplierPriceTypes, 
		Object.VATTaxation
		);
	
	PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
	
	Object.DocumentCurrency = ContractData.SettlementsCurrency;
	
	If OpenFormPricesAndCurrencies Then
		
		WarningText = "";
		If PriceKindChanged Then
			
			WarningText = NStr("en = 'The counterparty contract allows for the kind of prices other than prescribed in the document. 
			                   |Recalculate the document according to the contract?'") + Chars.LF + Chars.LF;
			
		EndIf;
		
		WarningText = WarningText + NStr("en = 'Settlement currency of the contract with counterparty changed. 
		                                 |It is necessary to check the document currency.'");
		
		ProcessChangesOnButtonPricesAndCurrencies(SettlementsCurrencyBeforeChange, True, PriceKindChanged, WarningText);
		
	ElsIf QuestionSupplierPriceTypes Then
		
		If Object.Inventory.Count() > 0 Then
			
			QuestionText = NStr("en = 'The counterparty contract allows for the kind of prices other than prescribed in the document. 
			                    |Recalculate the document according to the contract?'");
			
			NotifyDescription = New NotifyDescription("DefineDocumentRecalculateNeedByContractTerms", ThisObject, DocumentParameters);
			ShowQueryBox(NotifyDescription, QuestionText, QuestionDialogMode.YesNo);
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServerNoContext
// It receives data set from server for the DateOnChange procedure.
//
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

&AtServer
// Receives the data set from the server for the CompanyOnChange procedure.
//
Function GetCompanyDataOnChange(Company)
	
	StructureData = New Structure();
	StructureData.Insert("Company", DriveServer.GetCompany(Company));
	
	TaxationBeforeChange = Object.VATTaxation;
	
	Object.VATTaxation = DriveServer.CounterpartyVATTaxation(Object.Counterparty, DriveServer.VATTaxation(Object.Company, Object.Date));
	
	If Not TaxationBeforeChange = Object.VATTaxation Then
		Object.VATCommissionFeePercent = InformationRegisters.AccountingPolicy.GetDefaultVATRate(Object.Date, Object.Company);
	EndIf;
	
	Return StructureData;
	
EndFunction

&AtServerNoContext
// Receives the set of data from the server for the ProductsOnChange procedure.
//
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
		
		ReceiptPrice = DriveServer.GetPriceProductsBySupplierPriceTypes(StructureData);
		StructureData.Insert("ReceiptPrice", ReceiptPrice);
		
	Else
		
		StructureData.Insert("ReceiptPrice", 0);
		
	EndIf;
	
	Return StructureData;
	
EndFunction

&AtServerNoContext
// It receives data set from server for the CharacteristicOnChange procedure.
//
Function GetDataCharacteristicOnChange(StructureData)
	
	If StructureData.Property("SupplierPriceTypes") Then
		
		If TypeOf(StructureData.MeasurementUnit) = Type("CatalogRef.UOMClassifier") Then
			StructureData.Insert("Factor", 1);
		Else
			StructureData.Insert("Factor", StructureData.MeasurementUnit.Factor);
		EndIf;		
		
		ReceiptPrice = DriveServer.GetPriceProductsBySupplierPriceTypes(StructureData);
		StructureData.Insert("ReceiptPrice", ReceiptPrice);
		
	EndIf;
		
	Return StructureData;
	
EndFunction

&AtServerNoContext
// Gets the data set from the server for procedure MeasurementUnitOnChange.
//
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

&AtServer
// It receives data set from the server for the CounterpartyOnChange procedure.
//
Function GetDataCounterpartyOnChange(Date, DocumentCurrency, Counterparty, Company)
	
	ContractByDefault = GetContractByDefault(Object.Ref, Counterparty, Company);
	
	TaxationBeforeChange = Object.VATTaxation;
	
	Object.VATTaxation = DriveServer.CounterpartyVATTaxation(Object.Counterparty, DriveServer.VATTaxation(Object.Company, Object.Date));
	
	If Not TaxationBeforeChange = Object.VATTaxation Then
		Object.VATCommissionFeePercent = InformationRegisters.AccountingPolicy.GetDefaultVATRate(Object.Date, Object.Company);
	EndIf;
	
	StructureData = New Structure();
	
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
		"SupplierPriceTypes",
		ContractByDefault.SupplierPriceTypes
	);
	
	StructureData.Insert(
		"AmountIncludesVAT",
		?(ValueIsFilled(ContractByDefault.SupplierPriceTypes), ContractByDefault.SupplierPriceTypes.PriceIncludesVAT, Undefined)
	);
	
	StructureData.Insert(
		"SalesRep",
		CommonUse.ObjectAttributeValue(Counterparty, "SalesRep"));
	
	SetContractVisible();
	
	Return StructureData;
	
EndFunction

&AtServerNoContext
// It receives data set from server for the ContractOnChange procedure.
//
Function GetDataContractOnChange(Date, DocumentCurrency, Contract)
	
	StructureData = New Structure();
	
	StructureData.Insert(
		"SettlementsCurrency",
		Contract.SettlementsCurrency
	);
	
	StructureData.Insert(
		"SettlementsCurrencyRateRepetition",
		InformationRegisters.ExchangeRates.GetLast(Date, New Structure("Currency", Contract.SettlementsCurrency))
	);
	
	StructureData.Insert(
		"PriceKind",
		Contract.PriceKind
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

&AtServer
// Procedure fills the VAT rate in the tabular section according to the taxation system.
// 
Procedure FillVATRateByVATTaxation()
	
	If Object.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then
		
		Items.InventoryVATRate.Visible = True;
		Items.InventoryVATAmount.Visible = True;
		Items.InventoryAmountTotal.Visible = True;
		Items.InventoryVATSummOfArrival.Visible = True;
		Items.InventoryTotalAmountOfVAT.Visible = True;
		Items.PaymentCalendarPaymentVATAmount.Visible = True;
		Items.PaymentCalendarPayVATAmount.Visible = True;
		
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
											
			TabularSectionRow.ReceiptVATAmount = ?(Object.AmountIncludesVAT, 
													TabularSectionRow.AmountReceipt - (TabularSectionRow.AmountReceipt) / ((VATRate + 100) / 100),
													TabularSectionRow.AmountReceipt * VATRate / 100);								
											
			TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
			
		EndDo;	
		
	Else
		
		Items.InventoryVATRate.Visible = False;
		Items.InventoryVATAmount.Visible = False;
		Items.InventoryAmountTotal.Visible = False;
		Items.InventoryVATSummOfArrival.Visible = False;
		Items.InventoryTotalAmountOfVAT.Visible = False;
		Items.PaymentCalendarPaymentVATAmount.Visible = False;
		Items.PaymentCalendarPayVATAmount.Visible = False;
		
		If Object.VATTaxation = Enums.VATTaxationTypes.NotSubjectToVAT Then
		    DefaultVATRate = Catalogs.VATRates.Exempt;
		Else
			DefaultVATRate = Catalogs.VATRates.ZeroRate;
		EndIf;	
		
		For Each TabularSectionRow In Object.Inventory Do
		
			TabularSectionRow.VATRate = DefaultVATRate;
			TabularSectionRow.VATAmount = 0;
			TabularSectionRow.ReceiptVATAmount = 0;
			TabularSectionRow.Total = TabularSectionRow.Amount;
			
		EndDo;	
		
	EndIf;	
	
EndProcedure

&AtClient
// VAT amount is calculated in the row of tabular section.
//
Procedure CalculateVATSUM(TabularSectionRow)
	
	VATRate = DriveReUse.GetVATRateValue(TabularSectionRow.VATRate);
	
	TabularSectionRow.VATAmount = ?(Object.AmountIncludesVAT, 
									  TabularSectionRow.Amount - (TabularSectionRow.Amount) / ((VATRate + 100) / 100),
									  TabularSectionRow.Amount * VATRate / 100);
	
EndProcedure

&AtClient
// Procedure calculates the amount in the row of tabular section.
//
Procedure CalculateAmountInTabularSectionLine(TabularSectionRow = Undefined)
	
	If TabularSectionRow = Undefined Then
		TabularSectionRow = Items.Inventory.CurrentData;
	EndIf;
	
	// Amount.
	TabularSectionRow.Amount = TabularSectionRow.Quantity * TabularSectionRow.Price;
	
	// VAT amount.
	CalculateVATSUM(TabularSectionRow);
	
	// Total.
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
	// Serial numbers
	If UseSerialNumbersBalance <> Undefined Then
		WorkWithSerialNumbersClientServer.UpdateSerialNumbersQuantity(Object, TabularSectionRow);
	EndIf;
	
EndProcedure

&AtClient
// Calculates the brokerage in the row of the document tabular section
//
// Parameters:
//  TabularSectionRow - String of the document tabular section
//
Procedure CalculateCommissionRemuneration(TabularSectionRow)
	
	If Object.BrokerageCalculationMethod = PredefinedValue("Enum.CommissionFeeCalculationMethods.PercentFromSaleAmount") Then
		
		TabularSectionRow.BrokerageAmount = Object.CommissionFeePercent * TabularSectionRow.Amount / 100;
		
	ElsIf Object.BrokerageCalculationMethod = PredefinedValue("Enum.CommissionFeeCalculationMethods.PercentFromDifferenceOfSaleAndAmountReceipts") Then
		
		TabularSectionRow.BrokerageAmount = Object.CommissionFeePercent * (TabularSectionRow.Amount - TabularSectionRow.AmountReceipt) / 100;
		
	Else // Enum.CommissionFeeCalculationMethods.IsNotCalculating
		
		TabularSectionRow.BrokerageAmount = 0;
		
	EndIf;
	
	VATRate = DriveReUse.GetVATRateValue(Object.VATCommissionFeePercent);
	
	TabularSectionRow.BrokerageVATAmount = ?(Object.AmountIncludesVAT, 
	TabularSectionRow.BrokerageAmount - (TabularSectionRow.BrokerageAmount) / ((VATRate + 100) / 100),
	TabularSectionRow.BrokerageAmount * VATRate / 100);
	
EndProcedure

&AtClient
// Recalculate price by document tabular section currency after changes in the "Prices and currency" form.
//
// Parameters:
//  PreviousCurrency - CatalogRef.Currencies,
//                 contains reference to the previous currency.
//
Procedure RecalculateReceiptPricesOfTabularSectionByCurrency(DocumentForm, PreviousCurrency, TabularSectionName) 
	
	RatesStructure = DriveServer.GetExchangeRates(PreviousCurrency, DocumentForm.Object.DocumentCurrency, DocumentForm.Object.Date);
																   
	For Each TabularSectionRow In DocumentForm.Object[TabularSectionName] Do
		
		// Price.
		If TabularSectionRow.Property("ReceiptPrice") Then
			
			TabularSectionRow.ReceiptPrice = DriveClient.RecalculateFromCurrencyToCurrency(TabularSectionRow.ReceiptPrice, 
																	RatesStructure.InitRate, 
																	RatesStructure.ExchangeRate, 
																	RatesStructure.RepetitionBeg, 
																	RatesStructure.Multiplicity);
																	
																	
			TabularSectionRow.AmountReceipt = TabularSectionRow.Quantity * TabularSectionRow.ReceiptPrice;
	
			VATRate = DriveReUse.GetVATRateValue(TabularSectionRow.VATRate);

			TabularSectionRow.ReceiptVATAmount = ?(Object.AmountIncludesVAT, 
													TabularSectionRow.AmountReceipt - (TabularSectionRow.AmountReceipt) / ((VATRate + 100) / 100),
													TabularSectionRow.AmountReceipt * VATRate / 100);														
						
		// Amount.	
		ElsIf TabularSectionRow.Property("AmountReceipt") Then
			
			TabularSectionRow.AmountReceipt = DriveClient.RecalculateFromCurrencyToCurrency(TabularSectionRow.AmountReceipt, 
																	RatesStructure.InitRate, 
																	RatesStructure.ExchangeRate, 
																	RatesStructure.RepetitionBeg, 
																	RatesStructure.Multiplicity);																												
			
			VATRate = DriveReUse.GetVATRateValue(TabularSectionRow.VATRate);
			
	        TabularSectionRow.ReceiptVATAmount = ?(DocumentForm.Object.AmountIncludesVAT, 
								  				TabularSectionRow.AmountReceipt - (TabularSectionRow.AmountReceipt) / ((VATRate + 100) / 100),
								  				TabularSectionRow.AmountReceipt * VATRate / 100);
			
		EndIf;
        		        
	EndDo; 

EndProcedure

&AtClient
// Recalculate prices by the AmountIncludesVAT check box of the tabular section after changes in form "Prices and currency".
//
// Parameters:
//  PreviousCurrency - CatalogRef.Currencies,
//                 contains reference to the previous currency.
//
Procedure RecalculateTabularSectionAmountReceiptByFlagAmountIncludesVAT(DocumentForm, TabularSectionName)
																	   
	For Each TabularSectionRow In DocumentForm.Object[TabularSectionName] Do
		
		VATRate = DriveReUse.GetVATRateValue(TabularSectionRow.VATRate);
		
		If TabularSectionRow.Property("ReceiptPrice") Then
			If DocumentForm.Object.AmountIncludesVAT Then
				TabularSectionRow.ReceiptPrice = (TabularSectionRow.ReceiptPrice * (100 + VATRate)) / 100;
			Else
				TabularSectionRow.ReceiptPrice = (TabularSectionRow.ReceiptPrice * 100) / (100 + VATRate);
			EndIf;
		EndIf;
		
		TabularSectionRow.AmountReceipt = TabularSectionRow.Quantity * TabularSectionRow.ReceiptPrice;
	
		VATRate = DriveReUse.GetVATRateValue(TabularSectionRow.VATRate);

		TabularSectionRow.ReceiptVATAmount = ?(Object.AmountIncludesVAT, 
													TabularSectionRow.AmountReceipt - (TabularSectionRow.AmountReceipt) / ((VATRate + 100) / 100),
													TabularSectionRow.AmountReceipt * VATRate / 100);
		        
	EndDo;

EndProcedure

&AtClient
// Recalculates the exchange rate and multiplicity of
// the payment currency when the document date is changed.
//
Procedure RecalculateExchangeRateMultiplicitySettlementCurrency(StructureData)
	
	NewExchangeRate = ?(StructureData.CurrencyRateRepetition.ExchangeRate = 0, 1, StructureData.CurrencyRateRepetition.ExchangeRate);
	NewRatio = ?(StructureData.CurrencyRateRepetition.Multiplicity = 0, 1, StructureData.CurrencyRateRepetition.Multiplicity);
	
	If Object.ExchangeRate <> NewExchangeRate
		OR Object.Multiplicity <> NewRatio Then
		
		CurrencyRateInLetters = String(Object.Multiplicity) + " " + TrimAll(SettlementsCurrency) + " = " + String(Object.ExchangeRate) + " " + TrimAll(FunctionalCurrency);
		RateNewCurrenciesInLetters = String(NewRatio) + " " + TrimAll(SettlementsCurrency) + " = " + String(NewExchangeRate) + " " + TrimAll(FunctionalCurrency);
		
		MessageText = CommonUseClientReUse.RecalculateExchangeRateText(CurrencyRateInLetters, RateNewCurrenciesInLetters);
		
		Mode = QuestionDialogMode.YesNo;
		
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
	
	If Result = DialogReturnCode.Yes Then
		
		Object.ExchangeRate = NewExchangeRate;
		Object.Multiplicity = NewRatio;
		
		For Each TabularSectionRow In Object.Prepayment Do
			TabularSectionRow.PaymentAmount = DriveClient.RecalculateFromCurrencyToCurrency(
			TabularSectionRow.SettlementsAmount,
			TabularSectionRow.ExchangeRate,
			?(Object.DocumentCurrency = FunctionalCurrency, RateNationalCurrency, Object.ExchangeRate),
			TabularSectionRow.Multiplicity,
			?(Object.DocumentCurrency = FunctionalCurrency, RepetitionNationalCurrency, Object.Multiplicity));
		EndDo;
		
	EndIf;
	
	RecalculatePaymentCurrencyRateConversionFactorFragment();
	
EndProcedure

&AtClient
Procedure RecalculatePaymentCurrencyRateConversionFactorFragment()
    
    Var LabelStructure;
    
    LabelStructure = New Structure("SupplierPriceTypes, DocumentCurrency, SettlementsCurrency, ExchangeRate, RateNationalCurrency, AmountIncludesVAT, ForeignExchangeAccounting, VATTaxation", Object.SupplierPriceTypes, Object.DocumentCurrency, SettlementsCurrency, Object.ExchangeRate, RateNationalCurrency, Object.AmountIncludesVAT, ForeignExchangeAccounting, Object.VATTaxation);
    PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);

EndProcedure

&AtClient
// Procedure executes recalculate in the document tabular section
// after changes in "Prices and currency" form.Column recalculation is executed:
// price, discount, amount, VAT amount, total.
//
Procedure ProcessChangesOnButtonPricesAndCurrencies(Val SettlementsCurrencyBeforeChange, RecalculatePrices = False, RefillPrices = False, WarningText = "")
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("DocumentCurrency",		Object.DocumentCurrency);
	ParametersStructure.Insert("ExchangeRate",				Object.ExchangeRate);
	ParametersStructure.Insert("Multiplicity",			Object.Multiplicity);
	ParametersStructure.Insert("VATTaxation",	Object.VATTaxation);
	ParametersStructure.Insert("AmountIncludesVAT",	Object.AmountIncludesVAT);
	ParametersStructure.Insert("IncludeVATInPrice",Object.IncludeVATInPrice);
	ParametersStructure.Insert("Counterparty",			Object.Counterparty);
	ParametersStructure.Insert("Contract",				Object.Contract);
	ParametersStructure.Insert("Company",			ParentCompany);
	ParametersStructure.Insert("DocumentDate",		Object.Date);
	ParametersStructure.Insert("RefillPrices",	RefillPrices);
	ParametersStructure.Insert("RecalculatePrices",		RecalculatePrices);
	ParametersStructure.Insert("WereMadeChanges",False);
	ParametersStructure.Insert("SupplierPriceTypes", 	Object.SupplierPriceTypes);
	ParametersStructure.Insert("WarningText", WarningText);
	ParametersStructure.Insert("ReverseChargeNotApplicable", True);
	
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
			TSRowsArray = Object.Inventory.FindRows(New Structure("Products,Characteristic,Batch,MeasurementUnit",BarcodeData.Products,BarcodeData.Characteristic,BarcodeData.Batch,BarcodeData.MeasurementUnit));
			If TSRowsArray.Count() = 0 Then
				NewRow = Object.Inventory.Add();
				NewRow.Products = BarcodeData.Products;
				NewRow.Characteristic = BarcodeData.Characteristic;
				NewRow.Batch = BarcodeData.Batch;
				NewRow.Quantity = CurBarcode.Quantity;
				NewRow.MeasurementUnit = ?(ValueIsFilled(BarcodeData.MeasurementUnit), BarcodeData.MeasurementUnit, BarcodeData.StructureProductsData.MeasurementUnit);
				NewRow.ReceiptPrice = BarcodeData.StructureProductsData.ReceiptPrice;
				NewRow.VATRate = BarcodeData.StructureProductsData.VATRate;
				NewRow.AmountReceipt = NewRow.Quantity * NewRow.ReceiptPrice;
				VATRate = DriveReUse.GetVATRateValue(NewRow.VATRate);
				NewRow.ReceiptVATAmount = ?(
					Object.AmountIncludesVAT,
					NewRow.AmountReceipt
					- (NewRow.AmountReceipt)
					/ ((VATRate + 100)
					/ 100),
					NewRow.AmountReceipt
					*
					VATRate
					/ 100
				);
				CalculateAmountInTabularSectionLine(NewRow);
				CalculateCommissionRemuneration(NewRow);
				Items.Inventory.CurrentRow = NewRow.GetID();
			Else
				NewRow = TSRowsArray[0];
				NewRow.Quantity = NewRow.Quantity + CurBarcode.Quantity;
				CalculateAmountInTabularSectionLine(NewRow);
				CalculateCommissionRemuneration(NewRow);
				Items.Inventory.CurrentRow = NewRow.GetID();
			EndIf;
			
			If BarcodeData.Property("SerialNumber") AND ValueIsFilled(BarcodeData.SerialNumber) Then
				WorkWithSerialNumbersClientServer.AddSerialNumberToString(NewRow, BarcodeData.SerialNumber, Object);
			EndIf;
		EndIf;
	EndDo;
	RecalculateSubtotal();
	
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

// Procedure calls the data processor for document filling by basis.
//
&AtServer
Procedure FillByBasis(Basis)
	
	Document = FormAttributeToValue("Object");
	
	If TypeOf(Basis) = Type("CatalogRef.Counterparties") Then
	
		// Add attributes to the filling structure, that have already been specified in the document
		FillingData = New Structure();
		FillingData.Insert("Counterparty",  Basis);
		FillingData.Insert("Contract", 	 Object.Contract);
		FillingData.Insert("Company", Object.Company);
		FillingData.Insert("SupplierPriceTypes", Object.SupplierPriceTypes);
		Document.Filling(FillingData, );
		
	Else
		
		Document.Filling(Basis, );
		
	EndIf;
	
	ValueToFormAttribute(Document, "Object");
	Modified = True;
	
	If Object.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then
		
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
	
EndProcedure

// Procedure sets the contract visible depending on the parameter set to the counterparty.
//
&AtServer
Procedure SetContractVisible()
	
	CounterpartyDoSettlementsByOrders = Object.Counterparty.DoOperationsByOrders;
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
Function GetChoiceFormParameters(Document, Company, Counterparty, Contract)
	
	ContractTypesList = Catalogs.CounterpartyContracts.GetContractKindsListForDocument(Document);
	
	FormParameters = New Structure;
	FormParameters.Insert("ControlContractChoice", Counterparty.DoOperationsByContracts);
	FormParameters.Insert("Counterparty", Counterparty);
	FormParameters.Insert("Company", Company);
	FormParameters.Insert("ContractType", ContractTypesList);
	FormParameters.Insert("CurrentRow", Contract);
	
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
		
		DocumentParameters = New Structure;
		If ContractData = Undefined Then
			
			ContractData = GetDataContractOnChange(Object.Date, Object.DocumentCurrency, Object.Contract);
			
		Else
			
			DocumentParameters.Insert("CounterpartyDoSettlementsByOrdersBeforeChange", ContractData.CounterpartyDoSettlementsByOrdersBeforeChange);
			DocumentParameters.Insert("CounterpartyBeforeChange", ContractData.CounterpartyBeforeChange);
			
		EndIf;
		
		QueryBoxPrepayment = (Object.Prepayment.Count() > 0 AND Object.Contract <> ContractBeforeChange);
		
		PriceKindChanged = Object.SupplierPriceTypes <> ContractData.SupplierPriceTypes AND ValueIsFilled(ContractData.SupplierPriceTypes);
		QuestionSupplierPriceTypes = (ValueIsFilled(Object.Contract) AND PriceKindChanged);
		
		SettlementsCurrencyBeforeChange = SettlementsCurrency;
		SettlementsCurrency = ContractData.SettlementsCurrency;
		
		NewContractAndCalculationCurrency = ValueIsFilled(Object.Contract) AND ValueIsFilled(SettlementsCurrency) 
			AND Object.Contract <> ContractBeforeChange AND SettlementsCurrencyBeforeChange <> ContractData.SettlementsCurrency;
		OpenFormPricesAndCurrencies = NewContractAndCalculationCurrency AND Object.DocumentCurrency <> ContractData.SettlementsCurrency
			AND Object.Inventory.Count() > 0;
		
		DocumentParameters.Insert("ContractBeforeChange", ContractBeforeChange);
		DocumentParameters.Insert("SettlementsCurrencyBeforeChange", SettlementsCurrencyBeforeChange);
		DocumentParameters.Insert("ContractData", ContractData);
		DocumentParameters.Insert("PriceKindChanged", PriceKindChanged);
		DocumentParameters.Insert("QuestionSupplierPriceTypes", QuestionSupplierPriceTypes);
		DocumentParameters.Insert("OpenFormPricesAndCurrencies", OpenFormPricesAndCurrencies);
		DocumentParameters.Insert("ContractVisibleBeforeChange", Items.Contract.Visible);
		
		If QueryBoxPrepayment = True Then
			
			QuestionText = NStr("en = 'The prepayment recognition will be cleared. Do you want to continue?'");
			
			NotifyDescription = New NotifyDescription("DefineAdvancePaymentOffsetsRefreshNeed", ThisObject, DocumentParameters);
			ShowQueryBox(NotifyDescription, QuestionText, QuestionDialogMode.YesNo);
			
		Else
			
			HandleCounterpartiesPriceKindChangeAndSettlementsCurrency(DocumentParameters);
			
		EndIf;
		
		FillPaymentCalendarFromContract(SwitchTypeListOfPaymentCalendar);
		UpdatePaymentCalendar();
		
	EndIf;
	
EndProcedure

// Procedure recalculates subtotal the document on client.
&AtClient
Procedure RecalculateSubtotal()
	
	DocumentSubtotal = Object.Inventory.Total("Total") - Object.Inventory.Total("VATAmount");
	
EndProcedure

#Region WorkWithTheSelection

&AtClient
// Procedure - event handler Action of the Pick command
//
Procedure Pick(Command)
	
	TabularSectionName	= "Inventory";
	DocumentPresentaion	= NStr("en = 'account sales to consignor'");
	SelectionParameters	= DriveClient.GetSelectionParameters(ThisObject, TabularSectionName, DocumentPresentaion, True, False, False);
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

// Procedure - event handler Action of the command Pick of sales.
//
&AtClient
Procedure SelectionBySales(Command)
	
	Cancel = False;
	
	If Not ValueIsFilled(Object.Company) Then
		MessageText = NStr("en = 'Please specify the consignee.'");
		DriveClient.ShowMessageAboutError(ThisForm, MessageText,,, "Company", Cancel);
	EndIf;
	If Not ValueIsFilled(Object.Counterparty) Then
		MessageText = NStr("en = 'Please specify the consignor.'");
		DriveClient.ShowMessageAboutError(ThisForm, MessageText,,, "Counterparty", Cancel);
	EndIf;
	If Not ValueIsFilled(Object.Contract) Then
		MessageText = NStr("en = 'Please specify the contract.'");
		DriveClient.ShowMessageAboutError(ThisForm, MessageText,,, "Contract", Cancel);
	EndIf;
	
	If Cancel Then
		Return;
	EndIf;
	
	SelectionParameters = New Structure("
		|ParentCompany,
		|Company,
		|Counterparty,
		|Contract,
		|DocumentCurrency,
		|SupplierPriceTypes,
		|DocumentDate,
		|CurrentDocument",
		ParentCompany,
		Object.Company,
		Object.Counterparty,
		Object.Contract,
		Object.DocumentCurrency,
		Object.SupplierPriceTypes,
		Object.Date,
		Object.Ref
	);
	
	OpenForm("Document.AccountSalesToConsignor.Form.PickFormBySales", SelectionParameters, ThisForm);
	
EndProcedure

&AtServer
// Function gets a product list from the temporary storage
//
Procedure GetInventoryFromStorage(InventoryAddressInStorage, TabularSectionName, AreCharacteristics, AreBatches)
	
	TableForImport = GetFromTempStorage(InventoryAddressInStorage);
	
	For Each ImportRow In TableForImport Do
		
		NewRow 					= Object[TabularSectionName].Add();
		NewRow.ReceiptPrice 	= ImportRow.Price;
		NewRow.AmountReceipt 	= ImportRow.Amount;
		NewRow.ReceiptVATAmount = ImportRow.VATAmount;
		
		ImportRow.Price 	= 0;
		ImportRow.Amount 	= 0;
		ImportRow.VATAmount = 0;
		ImportRow.Total 	= 0;
		
		FillPropertyValues(NewRow, ImportRow);
		
	EndDo;
	
EndProcedure

// Function gets the list of inventory accepted from the temporary storage
//
&AtServer
Procedure GetInventoryAcceptedFromStorage(AddressInventoryAcceptedInStorage)
	
	StockReceivedFromThirdParties = GetFromTempStorage(AddressInventoryAcceptedInStorage);
	
	For Each TabularSectionRow In StockReceivedFromThirdParties Do
		
		NewRow = Object.Inventory.Add();
		FillPropertyValues(NewRow, TabularSectionRow);
		
		StructureData = New Structure;
		StructureData.Insert("Company", Object.Company);
		StructureData.Insert("Products", TabularSectionRow.Products);
		StructureData.Insert("VATTaxation", Object.VATTaxation);
		
		StructureData = GetDataProductsOnChange(StructureData);
		
		NewRow.MeasurementUnit = StructureData.MeasurementUnit;
		NewRow.VATRate = StructureData.VATRate;
		
		If TabularSectionRow.Quantity > TabularSectionRow.Balance
			OR TabularSectionRow.Quantity = 0 Then
			NewRow.Price = 0;
			NewRow.Amount = 0;
			NewRow.ReceiptPrice = 0;
		ElsIf TabularSectionRow.Quantity < TabularSectionRow.Balance Then
			NewRow.Amount = NewRow.Price * NewRow.Quantity;
		EndIf;
		NewRow.AmountReceipt = NewRow.ReceiptPrice * NewRow.Quantity;
		
		VATRate = DriveReUse.GetVATRateValue(NewRow.VATRate);
		
		NewRow.VATAmount = ?(Object.AmountIncludesVAT,
								NewRow.Amount - (NewRow.Amount) / ((VATRate + 100) / 100),
								NewRow.Amount * VATRate / 100);
								
		If Object.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then
			VATAmount = ?(Object.AmountIncludesVAT, 0, NewRow.VATAmount);
		Else
			VATAmount = 0
		EndIf;
		NewRow.Total = TabularSectionRow.Amount + VATAmount;
		
		NewRow.ReceiptVATAmount = ?(Object.AmountIncludesVAT,
											NewRow.AmountReceipt - (NewRow.AmountReceipt) / ((VATRate + 100) / 100),
											NewRow.AmountReceipt * VATRate / 100);
		
		If Object.BrokerageCalculationMethod = PredefinedValue("Enum.CommissionFeeCalculationMethods.IsNotCalculating") Then
			// Do nothing
		ElsIf Object.BrokerageCalculationMethod = PredefinedValue("Enum.CommissionFeeCalculationMethods.PercentFromSaleAmount") Then
			NewRow.BrokerageAmount = Object.CommissionFeePercent * NewRow.Amount / 100;
		ElsIf Object.BrokerageCalculationMethod = PredefinedValue("Enum.CommissionFeeCalculationMethods.PercentFromDifferenceOfSaleAndAmountReceipts") Then
			NewRow.BrokerageAmount = Object.CommissionFeePercent * (NewRow.Amount - NewRow.AmountReceipt) / 100;
		Else
			NewRow.BrokerageAmount = 0;
		EndIf;
		VATRate = DriveReUse.GetVATRateValue(Object.VATCommissionFeePercent);
		NewRow.BrokerageVATAmount = ?(Object.AmountIncludesVAT,
												NewRow.BrokerageAmount - (NewRow.BrokerageAmount) / ((VATRate + 100) / 100),
												NewRow.BrokerageAmount * VATRate / 100);
		
	EndDo;
	
EndProcedure

&AtServer
// Function places the list of advances into temporary storage and returns the address
//
Function PlacePrepaymentToStorage()
	
	Return PutToTempStorage(
		Object.Prepayment.Unload(,
			"Document,
			|Order,
			|SettlementsAmount,
			|ExchangeRate,
			|Multiplicity,
			|PaymentAmount"),
		UUID
	);
	
EndFunction

&AtServer
// Function gets the list of advances from the temporary storage
//
Procedure GetPrepaymentFromStorage(AddressPrepaymentInStorage)
	
	TableForImport = GetFromTempStorage(AddressPrepaymentInStorage);
	Object.Prepayment.Load(TableForImport);
	
EndProcedure

// Procedure of processing the results of selection closing
//
&AtClient
Procedure OnCloseSelection(ClosingResult, AdditionalParameters) Export
	
	If TypeOf(ClosingResult) = Type("Structure") Then
		
		If Not IsBlankString(ClosingResult.CartAddressInStorage) Then
			
			InventoryAddressInStorage	= ClosingResult.CartAddressInStorage;
			GetInventoryFromStorage(InventoryAddressInStorage, "Inventory", True, True)
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#EndRegion

#Region ProcedureFormEventHandlers

&AtServer
// Procedure - OnCreateAtServer event handler.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	DriveServer.FillDocumentHeader(
		Object,
		,
		Parameters.CopyingValue,
		Parameters.Basis,
		PostingIsAllowed,
		Parameters.FillingValues
	);
	
	If Not ValueIsFilled(Object.Ref)
		  AND ValueIsFilled(Object.Counterparty)
		  AND Not ValueIsFilled(Parameters.CopyingValue) Then
		If Not ValueIsFilled(Object.Contract) Then
			Object.Contract = Object.Counterparty.ContractByDefault;
		EndIf;
		If ValueIsFilled(Object.Contract) Then
			Object.DocumentCurrency				= Object.Contract.SettlementsCurrency;
			SettlementsCurrencyRateRepetition	= InformationRegisters.ExchangeRates.GetLast(Object.Date, New Structure("Currency", Object.Contract.SettlementsCurrency));
			Object.ExchangeRate					= ?(SettlementsCurrencyRateRepetition.ExchangeRate = 0, 1, SettlementsCurrencyRateRepetition.ExchangeRate);
			Object.Multiplicity					= ?(SettlementsCurrencyRateRepetition.Multiplicity = 0, 1, SettlementsCurrencyRateRepetition.Multiplicity);
			Object.SupplierPriceTypes		= Object.Contract.SupplierPriceTypes;
		EndIf;
		Object.VATTaxation = DriveServer.CounterpartyVATTaxation(Object.Counterparty, DriveServer.VATTaxation(Object.Company, Object.Date));
	EndIf;
	
	// Form attributes setting.
	DocumentDate = Object.Date;
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentDate();
	EndIf;
	
	ParentCompany			= DriveServer.GetCompany(Object.Company);
	Counterparty				= Object.Counterparty;
	Contract					= Object.Contract;
	SettlementsCurrency			= Object.Contract.SettlementsCurrency;
	FunctionalCurrency			= Constants.FunctionalCurrency.Get();
	StructureByCurrency			= InformationRegisters.ExchangeRates.GetLast(Object.Date, New Structure("Currency", FunctionalCurrency));
	RateNationalCurrency		= StructureByCurrency.ExchangeRate;
	RepetitionNationalCurrency	= StructureByCurrency.Multiplicity;
	
	If Not ValueIsFilled(Object.Ref)
		AND Not ValueIsFilled(Parameters.Basis) 
		AND Not ValueIsFilled(Parameters.CopyingValue) Then
		FillVATRateByVATTaxation();
	ElsIf Object.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then	
		Items.InventoryVATRate.Visible = True;
		Items.InventoryVATAmount.Visible = True;
		Items.InventoryAmountTotal.Visible = True;
		Items.InventoryVATSummOfArrival.Visible = True;
		Items.InventoryTotalAmountOfVAT.Visible = True;
		Items.PaymentCalendarPaymentVATAmount.Visible = True;
		Items.PaymentCalendarPayVATAmount.Visible = True;
	Else
		Items.InventoryVATRate.Visible = False;
		Items.InventoryVATAmount.Visible = False;
		Items.InventoryAmountTotal.Visible = False;
		Items.InventoryVATSummOfArrival.Visible = False;
		Items.InventoryTotalAmountOfVAT.Visible = False;
		Items.PaymentCalendarPaymentVATAmount.Visible = False;
		Items.PaymentCalendarPayVATAmount.Visible = False;
	EndIf;
	
	// Generate price and currency label.
	ForeignExchangeAccounting = Constants.ForeignExchangeAccounting.Get();
	LabelStructure = New Structure("SupplierPriceTypes, DocumentCurrency, SettlementsCurrency, ExchangeRate, RateNationalCurrency, AmountIncludesVAT, ForeignExchangeAccounting, VATTaxation", Object.SupplierPriceTypes, Object.DocumentCurrency, SettlementsCurrency, Object.ExchangeRate, RateNationalCurrency, Object.AmountIncludesVAT, ForeignExchangeAccounting, Object.VATTaxation);
	PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
	
	Object.VATCommissionFeePercent = InformationRegisters.AccountingPolicy.GetDefaultVATRate(Object.Date, ParentCompany);
	
	Items.CommissionFeePercent.Enabled = Not (Object.BrokerageCalculationMethod = PredefinedValue("Enum.CommissionFeeCalculationMethods.IsNotCalculating"));
	
	// Setting contract visible.
	SetContractVisible();
	
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
	
	SwitchTypeListOfPaymentCalendar = ?(Object.PaymentCalendar.Count() > 1, 1, 0);
	
EndProcedure

// Procedure - OnReadAtServer event handler.
//
&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	ClosingDates.ObjectOnReadAtServer(ThisForm, CurrentObject);
	
	SetSwitchTypeListOfPaymentCalendar();
	
EndProcedure

// Procedure-handler of the BeforeWriteAtServer event.
//
&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	If WriteParameters.WriteMode = DocumentWriteMode.Posting Then
		
		MessageText = "";
		CheckContractToDocumentConditionAccordance(MessageText, Object.Contract, Object.Ref, Object.Company, Object.Counterparty, Cancel);
		
		If MessageText <> "" Then
			
			Message = New UserMessage;
			Message.Text = ?(Cancel, NStr("en = 'Cannot post the account sales to consignor.'") + " " + MessageText, MessageText);
			
			If Cancel Then
				Message.DataPath = "Object";
				Message.Field = "Contract";
				Message.Message();
				Return;
			Else
				Message.Message();
			EndIf;
		EndIf;
		
		If DriveReUse.GetAdvanceOffsettingSettingValue() = Enums.YesNo.Yes
			AND CurrentObject.Prepayment.Count() = 0 Then
			FillPrepayment(CurrentObject);
		EndIf;
		
	EndIf;
	
EndProcedure

// Procedure fills advances.
//
&AtServer
Procedure FillPrepayment(CurrentObject)
	
	CurrentObject.FillPrepayment();
	
EndProcedure

&AtClient
// Procedure - event handler AfterWriting.
//
Procedure AfterWrite(WriteParameters)
	
	Notify("NotificationAboutChangingDebt");
	
EndProcedure

&AtClient
// Procedure - event handler OnOpen.
//
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
// Procedure - event handler OnClose.
//
Procedure OnClose(Exit)
	
	// Peripherals
	EquipmentManagerClientOverridable.StartDisablingEquipmentOnCloseForm(ThisForm);
	// End Peripherals
	
EndProcedure

&AtClient
// Procedure - event handler of the form NotificationProcessing.
//
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
	
	If EventName = "AfterRecordingOfCounterparty" 
		AND ValueIsFilled(Parameter)
		AND Object.Counterparty = Parameter Then
		
		SetContractVisible();
		
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

// Procedure - selection handler.
//
&AtClient
Procedure ChoiceProcessing(ValueSelected, ChoiceSource)
	
	If ChoiceSource.FormName = "Document.AccountSalesToConsignor.Form.PickFormBySales" Then
		
		GetInventoryAcceptedFromStorage(ValueSelected);
		
	EndIf;
	
EndProcedure

// Procedure is called when clicking the "FillByCounterparty" button 
//
&AtClient
Procedure FillByCounterparty(Command)
	ShowQueryBox(New NotifyDescription("FillByCounterpartyEnd", ThisObject), NStr("en = 'The document will be fully filled out. Continue?'"), QuestionDialogMode.YesNo, 0);
EndProcedure

&AtClient
Procedure FillByCounterpartyEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		FillByBasis(Object.Counterparty);
	EndIf;
	
EndProcedure

#EndRegion

#Region ProcedureActionsOfTheFormCommandPanels

&AtClient
// Procedure is called by clicking the PricesCurrency button of the command bar tabular field.
//
Procedure EditPricesAndCurrency(Item, StandardProcessing)
	
	StandardProcessing = False;
	ProcessChangesOnButtonPricesAndCurrencies(Object.DocumentCurrency);
	Modified = True;
	
EndProcedure

&AtClient
// Procedure - command handler of the tabular section command panel.
//
Procedure EditPrepaymentOffset(Command)
	
	If Not ValueIsFilled(Object.Counterparty) Then
		ShowMessageBox(, NStr("en = 'Please select a consignor.'"));
		Return;
	EndIf;
	
	If Not ValueIsFilled(Object.Contract) Then
		ShowMessageBox(, NStr("en = 'Please select a consignee.'"));
		Return;
	EndIf;
	
	OrdersArray = New Array;
	For Each CurItem In Object.Inventory Do
		OrderStructure = New Structure("Order, Total");
		OrderStructure.Order = CurItem.PurchaseOrder;
		OrderStructure.Total = CurItem.Total;
		OrdersArray.Add(OrderStructure);
	EndDo;
	
	AddressPrepaymentInStorage = PlacePrepaymentToStorage();
	SelectionParameters = New Structure(
		"AddressPrepaymentInStorage,
		|Pick,
		|IsOrder,
		|OrderInHeader,
		|Company,
		|Order,
		|Date,
		|Ref,
		|Counterparty,
		|Contract,
		|ExchangeRate,
		|Multiplicity,
		|DocumentCurrency,
		|DocumentAmount",
		AddressPrepaymentInStorage, // AddressPrepaymentInStorage
		True, // Pick
		True, // IsOrder
		False, // OrderInHeader
		ParentCompany, // Company
		?(CounterpartyDoSettlementsByOrders, OrdersArray, Undefined), // Order
		Object.Date, // Date
		Object.Ref, // Ref
		Object.Counterparty, // Counterparty
		Object.Contract, // Contract
		Object.ExchangeRate, // ExchangeRate
		Object.Multiplicity, // Multiplicity
		Object.DocumentCurrency, // DocumentCurrency
		Object.Inventory.Total("Total") // DocumentAmount
	);
	
	ReturnCode = Undefined;

	
	OpenForm("CommonForm.SelectAdvancesPaidToTheSupplier", SelectionParameters,,,,, New NotifyDescription("EditPrepaymentOffsetEnd", ThisObject, New Structure("AddressPrepaymentInStorage", AddressPrepaymentInStorage)));
	
EndProcedure

&AtClient
Procedure EditPrepaymentOffsetEnd(Result, AdditionalParameters) Export
    
    AddressPrepaymentInStorage = AdditionalParameters.AddressPrepaymentInStorage;
    
    
    ReturnCode = Result;
    
    If ReturnCode = DialogReturnCode.OK Then
        GetPrepaymentFromStorage(AddressPrepaymentInStorage);
    EndIf;

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
		
		ShowMessageBox(Undefined, NStr("en = 'Select a line where you want to record the weight.'"));
		
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
			MessageText = NStr("en = 'The electronic scale returned zero weight.'");
			CommonUseClientServer.MessageToUser(MessageText);
		Else
			// Weight is received.
			TabularSectionRow.Quantity = Weight;
			CalculateAmountInTabularSectionLine(TabularSectionRow);
			
			// Amount of income.
			TabularSectionRow.AmountReceipt = TabularSectionRow.ReceiptPrice * TabularSectionRow.Quantity;
			
			VATRate = DriveReUse.GetVATRateValue(TabularSectionRow.VATRate);
			TabularSectionRow.ReceiptVATAmount = ?(
				Object.AmountIncludesVAT, 
				TabularSectionRow.AmountReceipt - (TabularSectionRow.AmountReceipt) / ((VATRate + 100) / 100),
				TabularSectionRow.AmountReceipt * VATRate / 100
			);
			
			// Amount of brokerage
			CalculateCommissionRemuneration(TabularSectionRow);
			
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

&AtClient
// Procedure - event handler OnChange of the Date input field.
// In procedure situation is determined when date change document is
// into document numbering another period and in this case
// assigns to the document new unique number.
// Overrides the corresponding form parameter.
//
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

&AtClient
// Procedure - event handler OnChange of the Company input field.
// In procedure is executed document
// number clearing and also make parameter set of the form functional options.
// Overrides the corresponding form parameter.
//
Procedure CompanyOnChange(Item)

	// Company change event data processor.
	Object.Number = "";
	StructureData = GetCompanyDataOnChange(Object.Company);
	ParentCompany = StructureData.Company;
	
	Object.Contract = GetContractByDefault(Object.Ref, Object.Counterparty, Object.Company);
	ProcessContractChange();
	
	LabelStructure = New Structure("DocumentCurrency, SupplierPriceTypes, 
		|AmountIncludesVAT, ForeignExchangeAccounting, VATTaxation", 
		Object.DocumentCurrency, Object.SupplierPriceTypes, 
		Object.AmountIncludesVAT, ForeignExchangeAccounting, Object.VATTaxation);
		
	PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
	
	If Object.SetPaymentTerms
		AND ValueIsFilled(Object.CashAssetsType) Then
		
		RecalculatePaymentCalendar();
		FillPaymentScedule();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure KeepBackComissionFeeOnChange(Item)
	
	If NOT Object.KeepBackComissionFee Then
		Object.BrokerageCalculationMethod = PredefinedValue("Enum.CommissionFeeCalculationMethods.IsNotCalculating");
	EndIf;
	
	For Each TabularSectionRow In Object.Inventory Do
		CalculateCommissionRemuneration(TabularSectionRow);
	EndDo;
	
	RecalculatePaymentCalendar();
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of the BrokerageCalculationMethod input field.
//
Procedure BrokerageCalculationMethodOnChange(Item)
	
	NeedToRecalculate = False;
	If Object.BrokerageCalculationMethod = PredefinedValue("Enum.CommissionFeeCalculationMethods.IsNotCalculating")
		AND ValueIsFilled(Object.CommissionFeePercent) Then
		
		Object.CommissionFeePercent = 0;
		If Object.Inventory.Count() > 0 AND Object.Inventory.Total("BrokerageAmount") > 0 Then
			NeedToRecalculate = True;
		EndIf;
		
	EndIf;
	
	If NeedToRecalculate Or (Object.BrokerageCalculationMethod <> PredefinedValue("Enum.CommissionFeeCalculationMethods.IsNotCalculating")
		AND ValueIsFilled(Object.CommissionFeePercent) AND Object.Inventory.Count() > 0) Then
		
		ShowQueryBox(New NotifyDescription("BrokerageCalculationMethodOnChangeEnd", ThisObject),
			NStr("en = 'The calculation method has been changed. Do you want to recalculate the commission?'"),
			QuestionDialogMode.YesNo, , DialogReturnCode.Yes);
		
	EndIf;
	
	Items.CommissionFeePercent.Enabled = Not (Object.BrokerageCalculationMethod = PredefinedValue("Enum.CommissionFeeCalculationMethods.IsNotCalculating"));
	
EndProcedure

&AtClient
Procedure BrokerageCalculationMethodOnChangeEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		For Each TabularSectionRow In Object.Inventory Do
			CalculateCommissionRemuneration(TabularSectionRow);
		EndDo;
	EndIf;
	
	RecalculatePaymentCalendar();
	
EndProcedure

&AtClient
// Procedure - handler of the OnChange event of the BrokerageVATRate input field.
//
Procedure VATCommissionFeePercentOnChange(Item)
	
	If Object.Inventory.Count() = 0 Then
		Return;
	EndIf;
	
	ShowQueryBox(New NotifyDescription("BrokerageVATRateOnChangeEnd", ThisObject), "Do you want to recalculate VAT amounts of remuneration?",
		QuestionDialogMode.YesNo, , DialogReturnCode.No);
	
EndProcedure

&AtClient
Procedure BrokerageVATRateOnChangeEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.No Then
		Return;
	EndIf;
	
	VATRate = DriveReUse.GetVATRateValue(Object.VATCommissionFeePercent);
	
	For Each TabularSectionRow In Object.Inventory Do
		
		TabularSectionRow.BrokerageVATAmount = ?(Object.AmountIncludesVAT, 
		TabularSectionRow.BrokerageAmount - (TabularSectionRow.BrokerageAmount) / ((VATRate + 100) / 100),
		TabularSectionRow.BrokerageAmount * VATRate / 100);
		
	EndDo;
	
	RecalculatePaymentCalendar();
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of the BrokeragePercent.
//
Procedure CommissionFeePercentOnChange(Item)
	
	If Object.Inventory.Count() > 0 Then
		ShowQueryBox(New NotifyDescription("BrokeragePercentOnChangeEnd", ThisObject), 
			NStr("en = 'The commission rate has been changed. Do you want to recalculate the commission?'"),
			QuestionDialogMode.YesNo, , DialogReturnCode.Yes);
	EndIf;
	
EndProcedure

&AtClient
Procedure BrokeragePercentOnChangeEnd(Result, AdditionalParameters) Export
	
	// We must offer to recalculate brokerage.
	If Result = DialogReturnCode.Yes Then
		For Each TabularSectionRow In Object.Inventory Do
			CalculateCommissionRemuneration(TabularSectionRow);
		EndDo;
		RecalculatePaymentCalendar();
	EndIf;
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of the Counterparty input field.
// Clears the contract and tabular section.
//
Procedure CounterpartyOnChange(Item)
	
	CounterpartyBeforeChange = Counterparty;
	Counterparty = Object.Counterparty;
	CounterpartyDoSettlementsByOrdersBeforeChange = CounterpartyDoSettlementsByOrders;
	
	If CounterpartyBeforeChange <> Object.Counterparty Then
		
		StructureData = GetDataCounterpartyOnChange(Object.Date, Object.DocumentCurrency, Object.Counterparty, Object.Company);
		Object.Contract = StructureData.Contract;
		
		FillSalesRepInInventory(StructureData.SalesRep);
		
		StructureData.Insert("CounterpartyDoSettlementsByOrdersBeforeChange", CounterpartyDoSettlementsByOrdersBeforeChange);
		StructureData.Insert("CounterpartyBeforeChange", CounterpartyBeforeChange);
		
		ProcessContractChange(StructureData);
		
		UpdatePaymentCalendar();
		
	Else
		
		Object.Contract = Contract; // Restore the cleared contract automatically.
		
	EndIf;
	
EndProcedure

&AtClient
// The OnChange event handler of the Contract field.
// It updates the currency exchange rate and exchange rate multiplier.
//
Procedure ContractOnChange(Item)
	
	ProcessContractChange();
	
EndProcedure

// Procedure - event handler StartChoice of the Contract input field.
//
&AtClient
Procedure ContractStartChoice(Item, ChoiceData, StandardProcessing)
	
	FormParameters = GetChoiceFormParameters(Object.Ref, Object.Company, Object.Counterparty, Object.Contract);
	If FormParameters.ControlContractChoice Then
		
		StandardProcessing = False;
		OpenForm("Catalog.CounterpartyContracts.Form.ChoiceForm", FormParameters, Item);
		
	EndIf;
	
EndProcedure

#Region TabularSectionAttributeEventHandlers

&AtClient
// Procedure - event handler OnChange of the Products input field.
//
Procedure InventoryProductsOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("Company", Object.Company);
	StructureData.Insert("Products", TabularSectionRow.Products);
	StructureData.Insert("VATTaxation", Object.VATTaxation);
	
	If ValueIsFilled(Object.SupplierPriceTypes) Then
		
		StructureData.Insert("ProcessingDate", Object.Date);
		StructureData.Insert("SupplierPriceTypes", Object.SupplierPriceTypes);
		StructureData.Insert("DocumentCurrency", Object.DocumentCurrency);
		StructureData.Insert("AmountIncludesVAT", Object.AmountIncludesVAT);
		StructureData.Insert("Characteristic", TabularSectionRow.Characteristic);
		StructureData.Insert("Factor", 1);
		
	EndIf;
	
	StructureData = GetDataProductsOnChange(StructureData);
	
	TabularSectionRow.MeasurementUnit = StructureData.MeasurementUnit;
	TabularSectionRow.Quantity = 1;
	TabularSectionRow.Price = 0;
	TabularSectionRow.VATRate = StructureData.VATRate;
	
	TabularSectionRow.ReceiptPrice = StructureData.ReceiptPrice;
	
	TabularSectionRow.AmountReceipt = TabularSectionRow.Quantity * TabularSectionRow.ReceiptPrice;
	
	VATRate = DriveReUse.GetVATRateValue(TabularSectionRow.VATRate);
	
	TabularSectionRow.ReceiptVATAmount = ?(
		Object.AmountIncludesVAT,
		TabularSectionRow.AmountReceipt
		- (TabularSectionRow.AmountReceipt)
		/ ((VATRate + 100)
		/ 100),
		TabularSectionRow.AmountReceipt
		* VATRate
		/ 100
	);
	
	CalculateAmountInTabularSectionLine();
	CalculateCommissionRemuneration(TabularSectionRow);
	
	// Serial numbers
	WorkWithSerialNumbersClientServer.DeleteSerialNumbersByConnectionKey(Object.SerialNumbers, TabularSectionRow, , UseSerialNumbersBalance);
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of the Characteristic input field.
//
Procedure InventoryCharacteristicOnChange(Item)
	
	If ValueIsFilled(Object.SupplierPriceTypes) Then
	
		TabularSectionRow = Items.Inventory.CurrentData;
		
		StructureData = New Structure;
		StructureData.Insert("ProcessingDate",		Object.Date);
		StructureData.Insert("SupplierPriceTypes",	Object.SupplierPriceTypes);
		StructureData.Insert("DocumentCurrency",		Object.DocumentCurrency);
		StructureData.Insert("AmountIncludesVAT",	Object.AmountIncludesVAT);
		
		StructureData.Insert("VATRate", 		 	TabularSectionRow.VATRate);
		StructureData.Insert("Products",		TabularSectionRow.Products);
		StructureData.Insert("Characteristic",		TabularSectionRow.Characteristic);
		StructureData.Insert("MeasurementUnit",	TabularSectionRow.MeasurementUnit);
		StructureData.Insert("ReceiptPrice",		TabularSectionRow.ReceiptPrice);
		
		StructureData = GetDataCharacteristicOnChange(StructureData);
		
		TabularSectionRow.ReceiptPrice = StructureData.ReceiptPrice;
		
		TabularSectionRow.AmountReceipt = TabularSectionRow.Quantity * TabularSectionRow.ReceiptPrice;
	
		VATRate = DriveReUse.GetVATRateValue(TabularSectionRow.VATRate);

		TabularSectionRow.ReceiptVATAmount = ?(Object.AmountIncludesVAT, 
													TabularSectionRow.AmountReceipt - (TabularSectionRow.AmountReceipt) / ((VATRate + 100) / 100),
													TabularSectionRow.AmountReceipt * VATRate / 100);
    		
        CalculateAmountInTabularSectionLine();
		CalculateCommissionRemuneration(TabularSectionRow);
		
	EndIf;
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of the Count input field.
//
Procedure InventoryQuantityOnChange(Item)
	
	CalculateAmountInTabularSectionLine();
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	// Amount of income.
	TabularSectionRow.AmountReceipt = TabularSectionRow.ReceiptPrice * TabularSectionRow.Quantity;
	
	VATRate = DriveReUse.GetVATRateValue(TabularSectionRow.VATRate);
	
	TabularSectionRow.ReceiptVATAmount = ?(Object.AmountIncludesVAT, 
													TabularSectionRow.AmountReceipt - (TabularSectionRow.AmountReceipt) / ((VATRate + 100) / 100),
													TabularSectionRow.AmountReceipt * VATRate / 100);
	// Amount of brokerage
	CalculateCommissionRemuneration(TabularSectionRow);
	
EndProcedure

&AtClient
// Procedure - event handler ChoiceProcessing of the MeasurementUnit input field.
//
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
	CalculateCommissionRemuneration(TabularSectionRow);
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of the Price input field.
//
Procedure InventoryPriceOnChange(Item)
	
	CalculateAmountInTabularSectionLine();
	
	TabularSectionRow = Items.Inventory.CurrentData;
	CalculateCommissionRemuneration(TabularSectionRow);
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of the Amount input field.
//
Procedure InventoryAmountOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	// Price.
	If TabularSectionRow.Quantity <> 0 Then
		TabularSectionRow.Price = TabularSectionRow.Amount / TabularSectionRow.Quantity;
	EndIf;
	
	// VAT amount.
	CalculateVATSUM(TabularSectionRow);
	
	// Total.
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
	// Amount of brokerage
	CalculateCommissionRemuneration(TabularSectionRow);
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of the VATRate input field.
//
Procedure InventoryVATRateOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	// VAT amount.
	CalculateVATSUM(TabularSectionRow);
	
	// Total.
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
	VATRate = DriveReUse.GetVATRateValue(TabularSectionRow.VATRate);
			
	TabularSectionRow.ReceiptVATAmount = ?(Object.AmountIncludesVAT, 
													TabularSectionRow.AmountReceipt - (TabularSectionRow.AmountReceipt) / ((VATRate + 100) / 100),
													TabularSectionRow.AmountReceipt * VATRate / 100);
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of the VATRate input field.
//
Procedure InventoryVATAmountOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	// Total.
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of the ReceiptPrice input field.
//
Procedure InventoryIncreasePriceOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	// Amount of income.
	TabularSectionRow.AmountReceipt = TabularSectionRow.Quantity * TabularSectionRow.ReceiptPrice;
	
	VATRate = DriveReUse.GetVATRateValue(TabularSectionRow.VATRate);
			
	TabularSectionRow.ReceiptVATAmount = ?(Object.AmountIncludesVAT, 
													TabularSectionRow.AmountReceipt - (TabularSectionRow.AmountReceipt) / ((VATRate + 100) / 100),
													TabularSectionRow.AmountReceipt * VATRate / 100);
	
	// Amount of brokerage
	CalculateCommissionRemuneration(TabularSectionRow);
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of the AmountReceipt input field.
//
Procedure InventoryAmountReceiptOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	// Price.
	If TabularSectionRow.Quantity <> 0 Then
		TabularSectionRow.ReceiptPrice = TabularSectionRow.AmountReceipt / TabularSectionRow.Quantity;
	EndIf;
	
	// VAT amount received.
	VATRate = DriveReUse.GetVATRateValue(TabularSectionRow.VATRate);
			
	TabularSectionRow.ReceiptVATAmount = ?(Object.AmountIncludesVAT, 
													TabularSectionRow.AmountReceipt - (TabularSectionRow.AmountReceipt) / ((VATRate + 100) / 100),
													TabularSectionRow.AmountReceipt * VATRate / 100);
		
	// Amount of brokerage
	CalculateCommissionRemuneration(TabularSectionRow);
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of the BrokerageAmount input field.
//
Procedure InventoryBrokerageAmountOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	VATRate = DriveReUse.GetVATRateValue(Object.VATCommissionFeePercent);
			
	TabularSectionRow.BrokerageVATAmount = ?(Object.AmountIncludesVAT, 
													TabularSectionRow.BrokerageAmount - (TabularSectionRow.BrokerageAmount) / ((VATRate + 100) / 100),
													TabularSectionRow.BrokerageAmount * VATRate / 100);
	
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
	WorkWithSerialNumbersClientServer.DeleteSerialNumbersByConnectionKey(Object.SerialNumbers, CurrentData, , UseSerialNumbersBalance);
	
EndProcedure

&AtClient
Procedure InventoryOnStartEdit(Item, NewRow, Clone)
	
	If NewRow AND Clone Then
		Item.CurrentData.ConnectionKey = 0;
		Item.CurrentData.SerialNumbers = "";
	EndIf;	
	
	If Item.CurrentItem.Name = "InventorySerialNumbers" Then
		OpenSerialNumbersSelection();
	EndIf;
	
EndProcedure

// Procedure - event handler OnChange of the Inventory tabular section.
//
&AtClient
Procedure InventoryOnChange(Item)
	
	RecalculateSubtotal();
	RecalculatePaymentCalendar();
	
EndProcedure

&AtClient
Procedure InventorySalesOrderOnChange(Item)
	
	CurrentRow = Items.Inventory.CurrentData;
	If ValueIsFilled(CurrentRow.SalesOrder) Then
		CurrentRow.SalesRep = SalesRep(CurrentRow.SalesOrder);
	EndIf;
	
EndProcedure

&AtClient
Procedure PrepaymentAccountsAmountOnChange(Item)
	
	TabularSectionRow = Items.Prepayment.CurrentData;
		
	TabularSectionRow.ExchangeRate = ?(
		TabularSectionRow.ExchangeRate = 0,
			?(Object.ExchangeRate = 0,
			1,
			Object.ExchangeRate),
		TabularSectionRow.ExchangeRate
	);
	
	TabularSectionRow.Multiplicity = ?(
		TabularSectionRow.Multiplicity = 0,
			?(Object.Multiplicity = 0,
			1,
			Object.Multiplicity),
		TabularSectionRow.Multiplicity
	);
	
	TabularSectionRow.PaymentAmount = DriveClient.RecalculateFromCurrencyToCurrency(
		TabularSectionRow.SettlementsAmount,
		TabularSectionRow.ExchangeRate,
		?(Object.DocumentCurrency = FunctionalCurrency, RateNationalCurrency, Object.ExchangeRate),
		TabularSectionRow.Multiplicity,
		?(Object.DocumentCurrency = FunctionalCurrency,RepetitionNationalCurrency, Object.Multiplicity)
	);

EndProcedure

&AtClient
Procedure PrepaymentRateOnChange(Item)
	
	TabularSectionRow = Items.Prepayment.CurrentData;
	
	TabularSectionRow.ExchangeRate = ?(
		TabularSectionRow.ExchangeRate = 0,
		1,
		TabularSectionRow.ExchangeRate
	);
	
	TabularSectionRow.Multiplicity = ?(
		TabularSectionRow.Multiplicity = 0,
		1,
		TabularSectionRow.Multiplicity
	);
	
	TabularSectionRow.PaymentAmount = DriveClient.RecalculateFromCurrencyToCurrency(
		TabularSectionRow.SettlementsAmount,
		TabularSectionRow.ExchangeRate,
		?(Object.DocumentCurrency = FunctionalCurrency, RateNationalCurrency, Object.ExchangeRate),
		TabularSectionRow.Multiplicity,
		?(Object.DocumentCurrency = FunctionalCurrency,RepetitionNationalCurrency, Object.Multiplicity)
	);
	
EndProcedure

&AtClient
Procedure PrepaymentMultiplicityOnChange(Item)
	
	TabularSectionRow = Items.Prepayment.CurrentData;
	
	TabularSectionRow.ExchangeRate = ?(
		TabularSectionRow.ExchangeRate = 0,
		1,
		TabularSectionRow.ExchangeRate
	);
	
	TabularSectionRow.Multiplicity = ?(
		TabularSectionRow.Multiplicity = 0,
		1,
		TabularSectionRow.Multiplicity
	);
	
	TabularSectionRow.PaymentAmount = DriveClient.RecalculateFromCurrencyToCurrency(
		TabularSectionRow.SettlementsAmount,
		TabularSectionRow.ExchangeRate,
		?(Object.DocumentCurrency = FunctionalCurrency, RateNationalCurrency, Object.ExchangeRate),
		TabularSectionRow.Multiplicity,
		?(Object.DocumentCurrency = FunctionalCurrency,RepetitionNationalCurrency, Object.Multiplicity)
	);
	
EndProcedure

&AtClient
Procedure PrepaymentPaymentAmountOnChange(Item)
	
	TabularSectionRow = Items.Prepayment.CurrentData;
	
	TabularSectionRow.ExchangeRate = ?(
		TabularSectionRow.ExchangeRate = 0,
		1,
		TabularSectionRow.ExchangeRate
	);
	
	TabularSectionRow.Multiplicity = 1;
	
	TabularSectionRow.ExchangeRate =
		?(TabularSectionRow.SettlementsAmount = 0,
			1,
			TabularSectionRow.PaymentAmount
		  / TabularSectionRow.SettlementsAmount
		  * Object.ExchangeRate
	);
	
EndProcedure

// Procedure - OnChange event handler of the Comment input field.
//
&AtClient
Procedure CommentOnChange(Item)
	
	AttachIdleHandler("Attachable_SetPictureForComment", 0.5, True);
	
EndProcedure

&AtClient
Procedure Attachable_SetPictureForComment()
	
	DriveClientServer.SetPictureForComment(Items.GroupAdditional, Object.Comment);
	
EndProcedure

&AtClient
Procedure SalesRepOnChange(Item)
	If Object.Inventory.Count() > 1 Then
		FillSalesRepInInventory(Object.Inventory[0].SalesRep);
	EndIf;
EndProcedure

#EndRegion

#Region InteractiveActionResultHandlers

&AtClient
// Procedure-handler of the result of opening the "Prices and currencies" form
//
Procedure OpenPricesAndCurrencyFormEnd(ClosingResult, AdditionalParameters) Export
	
	If TypeOf(ClosingResult) = Type("Structure") 
		AND ClosingResult.WereMadeChanges Then
		
		Object.DocumentCurrency = ClosingResult.DocumentCurrency;
		Object.ExchangeRate = ClosingResult.PaymentsRate;
		Object.Multiplicity = ClosingResult.SettlementsMultiplicity;
		Object.VATTaxation = ClosingResult.VATTaxation;
		Object.AmountIncludesVAT = ClosingResult.AmountIncludesVAT;
		Object.IncludeVATInPrice = ClosingResult.IncludeVATInPrice;
		Object.SupplierPriceTypes = ClosingResult.SupplierPriceTypes;
		
		// Recalculate prices by kind of prices.
		If ClosingResult.RefillPrices Then
			
			DriveClient.RefillTabularSectionPricesBySupplierPriceTypes(ThisForm, "Inventory")
			
		EndIf;
		
		// Recalculate prices by currency.
		If Not ClosingResult.RefillPrices
			AND ClosingResult.RecalculatePrices Then	
			
			DriveClient.RecalculateTabularSectionPricesByCurrency(ThisForm, AdditionalParameters.SettlementsCurrencyBeforeChange, "Inventory");
			RecalculateReceiptPricesOfTabularSectionByCurrency(ThisForm, AdditionalParameters.SettlementsCurrencyBeforeChange, "Inventory");
			
		EndIf;
		
		// Recalculate the amount if VAT taxation flag is changed.
		If ClosingResult.VATTaxation <> ClosingResult.PrevVATTaxation Then
			
			FillVATRateByVATTaxation();
			
		EndIf;
		
		// Recalculate the amount if the "Amount includes VAT" flag is changed.
		If Not ClosingResult.RefillPrices
			AND Not ClosingResult.AmountIncludesVAT = ClosingResult.PrevAmountIncludesVAT Then
			
			DriveClient.RecalculateTabularSectionAmountByFlagAmountIncludesVAT(ThisForm, "Inventory");
			RecalculateTabularSectionAmountReceiptByFlagAmountIncludesVAT(ThisForm, "Inventory");
			
		EndIf;
		
		For Each TabularSectionRow In Object.Inventory Do
			// Amount of brokerage
			CalculateCommissionRemuneration(TabularSectionRow);
		EndDo;
		RecalculateSubtotal();
		
		For Each TabularSectionRow In Object.Prepayment Do
			
			TabularSectionRow.PaymentAmount = DriveClient.RecalculateFromCurrencyToCurrency(
				TabularSectionRow.SettlementsAmount,
				TabularSectionRow.ExchangeRate,
				?(Object.DocumentCurrency = FunctionalCurrency, RateNationalCurrency, Object.ExchangeRate),
				TabularSectionRow.Multiplicity,
				?(Object.DocumentCurrency = FunctionalCurrency, RepetitionNationalCurrency, Object.Multiplicity)
				);
				
		EndDo;
		
	EndIf;
	
	LabelStructure = New Structure("SupplierPriceTypes, DocumentCurrency, SettlementsCurrency, ExchangeRate, RateNationalCurrency, AmountIncludesVAT, ForeignExchangeAccounting, VATTaxation", 
		Object.SupplierPriceTypes, 
		Object.DocumentCurrency, 
		SettlementsCurrency, 
		Object.ExchangeRate, 
		RateNationalCurrency, 
		Object.AmountIncludesVAT, 
		ForeignExchangeAccounting, 
		Object.VATTaxation
		);
	
	PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
	
	RecalculatePaymentCalendar();
	
EndProcedure

&AtClient
// Procedure-handler of the answer to the question about repeated advances offset
//
Procedure DefineAdvancePaymentOffsetsRefreshNeed(ClosingResult, AdditionalParameters) Export
	
	If ClosingResult = DialogReturnCode.Yes Then
		
		Object.Prepayment.Clear();
		HandleCounterpartiesPriceKindChangeAndSettlementsCurrency(AdditionalParameters);
		
	Else
		
		Object.Contract = AdditionalParameters.ContractBeforeChange;
		Contract = AdditionalParameters.ContractBeforeChange;
		
		If AdditionalParameters.Property("CounterpartyBeforeChange") Then
			
			Object.Counterparty = AdditionalParameters.CounterpartyBeforeChange;
			Counterparty = AdditionalParameters.CounterpartyBeforeChange;
			CounterpartyDoSettlementsByOrders = AdditionalParameters.CounterpartyDoSettlementsByOrdersBeforeChange;
			Items.Contract.Visible = AdditionalParameters.ContractVisibleBeforeChange;
			
		EndIf;
		
	EndIf;
	
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
			Object.VATTaxation
			);
			
		PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
		
		// Recalculate prices by kind of prices.
		If Object.Inventory.Count() > 0 Then
			
			DriveClient.RefillTabularSectionPricesBySupplierPriceTypes(ThisForm, "Inventory");
			
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

// End StandardSubsystems.Printing

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
Function SerialNumberPickParameters(CurrentDataIdentifier)
	
	Return WorkWithSerialNumbers.SerialNumberPickParameters(Object, ThisObject.UUID, CurrentDataIdentifier, False);
	
EndFunction

Function GetSerialNumbersFromStorage(AddressInTemporaryStorage, RowKey)
	
	Modified = True;
	Return WorkWithSerialNumbers.GetSerialNumbersFromStorage(Object, AddressInTemporaryStorage, RowKey);
	
EndFunction

#EndRegion

#Region GeneralPurposeProceduresAndFunctionsOfPaymentCalendar

&AtServer
Procedure FillThePaymentCalendarOnServer()
	
	FillPaymentCalendarFromContract(SwitchTypeListOfPaymentCalendar);
	
	If Object.PaymentCalendar.Count() = 0 Then
		
		NewRow = Object.PaymentCalendar.Add();
		
		NewRow.PaymentPercentage = 100;
		
		AmountTotal = Object.Inventory.Total("Amount");
		VATTotal = Object.Inventory.Total("VATAmount");
		If Object.KeepBackComissionFee Then
			BrokerageVATTotal = Object.Inventory.Total("BrokerageVATAmount");
			AmountForPaymentCalendar = AmountTotal - (Object.CommissionFeePercent * AmountTotal / 100)
				- (VATTotal - BrokerageVATTotal);
			VATForPaymentCalendar = VATTotal - BrokerageVATTotal;
		Else
			AmountForPaymentCalendar = AmountTotal;
			VATForPaymentCalendar = VATTotal;
		EndIf;
		
		NewRow.PaymentAmount = AmountForPaymentCalendar;
		NewRow.PaymentVATAmount = VATForPaymentCalendar;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure UpdatePaymentCalendar()
	
	SetEnableGroupPaymentCalendarDetails();
	SetVisiblePaymentCalendar();
	SetVisibleCashAssetsTypes();
	
EndProcedure

// Procedure sets availability of the form items.
//
&AtClient
Procedure SetEnableGroupPaymentCalendarDetails()
	
	Items.GroupPaymentCalendarDetails.Enabled = Object.SetPaymentTerms;
	
EndProcedure

&AtClient
Procedure SetVisiblePaymentCalendar()
	
	If SwitchTypeListOfPaymentCalendar Then
		Items.GroupPaymentCalendarListString.CurrentPage = Items.GroupPaymentCalendarList;
	Else
		Items.GroupPaymentCalendarListString.CurrentPage = Items.GroupBillingCalendarString;
	EndIf;
	
EndProcedure

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

&AtServer
Procedure FillPaymentCalendarFromContract(TypeListOfPaymentCalendar)
	
	Document = FormAttributeToValue("Object");
	Document.FillPaymentCalendarFromContract();
	ValueToFormAttribute(Document, "Object");
	Modified = True;
	
	TypeListOfPaymentCalendar = Number(Object.PaymentCalendar.Count() > 1);
	
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

&AtClient
Procedure SetEditInListEndOption(Result, AdditionalParameters) Export
	
	LineCount = AdditionalParameters.LineCount;
	
	If Result = DialogReturnCode.No Then
		SwitchTypeListOfPaymentCalendar = 1;
		Return;
	EndIf;
	
	While LineCount > 1 Do
		Object.PaymentCalendar.Delete(Object.PaymentCalendar[LineCount - 1]);
		LineCount = LineCount - 1;
	EndDo;
	Items.PaymentCalendar.CurrentRow = Object.PaymentCalendar[0].GetID();
	
	SetVisiblePaymentCalendar();

EndProcedure

&AtServer
Procedure SetSwitchTypeListOfPaymentCalendar()
	
	If Object.PaymentCalendar.Count() > 1 Then
		SwitchTypeListOfPaymentCalendar = 1;
	Else
		SwitchTypeListOfPaymentCalendar = 0;
	EndIf;
	
EndProcedure

&AtClient
Procedure RecalculatePaymentCalendar()
	
	If Object.SetPaymentTerms
		AND Object.PaymentCalendar.Count() > 0 Then
		
		AmountForFill = AmountForPaymentCalendar();
		VATForFill = VATForPaymentCalendar();
		
		AmountForCorrectBalance = 0;
		VATForCorrectBalance = 0;
		
		For Each Line In Object.PaymentCalendar Do
			
			Line.PaymentAmount = Round(AmountForFill * Line.PaymentPercentage / 100, 2, RoundMode.Round15as20);
			Line.PaymentVATAmount = Round(VATForFill * Line.PaymentPercentage / 100, 2, RoundMode.Round15as20);
			
			AmountForCorrectBalance = AmountForCorrectBalance + Line.PaymentAmount;
			VATForCorrectBalance = VATForCorrectBalance + Line.PaymentVATAmount;
			
		EndDo;
		
		// correct balance
		Line.PaymentAmount = Line.PaymentAmount + (AmountForFill - AmountForCorrectBalance);
		Line.PaymentVATAmount = Line.PaymentVATAmount + (VATForFill - VATForCorrectBalance);
	EndIf;
	
EndProcedure

&AtClient
Function VATForPaymentCalendar()
	
	If Object.KeepBackComissionFee Then
		VATForPaymentCalendar = Object.Inventory.Total("VATAmount") - Object.Inventory.Total("BrokerageVATAmount");
	Else
		VATForPaymentCalendar = Object.Inventory.Total("VATAmount")
	EndIf;
	
	Return VATForPaymentCalendar;
	
EndFunction

&AtClient
Function AmountForPaymentCalendar()
	
	InventoryTotal = Object.Inventory.Total("Total");
	
	If Object.KeepBackComissionFee Then
		AmountForPaymentCalendar = Round(InventoryTotal - (Object.CommissionFeePercent * InventoryTotal / 100)
			- (Object.Inventory.Total("VATAmount") - Object.Inventory.Total("BrokerageVATAmount")), 2, 1);
	Else
		AmountForPaymentCalendar = Object.Inventory.Total("Amount");
	EndIf;
	
	Return AmountForPaymentCalendar;
	
EndFunction

&AtServer
Procedure FillPaymentScedule()
	
	If Object.CashAssetsType = Enums.CashAssetTypes.Noncash Then
		Object.BankAccount = CommonUse.ObjectAttributeValue(Object.Company, "BankAccountByDefault");
	ElsIf Object.CashAssetsType = Enums.CashAssetTypes.Cash Then
		Object.PettyCash = CommonUse.ObjectAttributeValue(Object.Company, "PettyCashByDefault");
	EndIf;
	
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

#EndRegion

#Region EventHandlersOfPaymentCalendar

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

// Procedure - event handler OnChange input field SwitchTypeListOfPaymentCalendar.
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

// Procedure - event handler OnChange input field CashAssetsType.
//
&AtClient
Procedure CashAssetsTypeOnChange(Item)
	
	SetVisibleCashAssetsTypes();
	
EndProcedure

// Procedure - event handler OnChange of the PaymentCalendarPaymentPercent input field.
//
&AtClient
Procedure PaymentCalendarPaymentPercentageOnChange(Item)
	
	CurrentRow = Items.PaymentCalendar.CurrentData;
	
	CurrentRow.PaymentAmount = Round(AmountForPaymentCalendar() * CurrentRow.PaymentPercentage / 100, 2, 1);
	CurrentRow.PaymentVATAmount = Round(VATForPaymentCalendar() * CurrentRow.PaymentPercentage / 100, 2, 1);
	
EndProcedure

// Procedure - event handler OnChange of the PaymentCalendarPaymentAmount input field.
//
&AtClient
Procedure PaymentCalendarPaymentSumOnChange(Item)
	
	CurrentRow = Items.PaymentCalendar.CurrentData;
	
	InventoryTotal = AmountForPaymentCalendar();
	
	CurrentRow.PaymentPercentage = ?(InventoryTotal = 0, 0, Round(CurrentRow.PaymentAmount / InventoryTotal * 100, 2, 1));
	CurrentRow.PaymentVATAmount = Round(VATForPaymentCalendar() * CurrentRow.PaymentPercentage / 100, 2, 1);
	
EndProcedure

// Procedure - event handler OnChange of the PaymentCalendarPayVATAmount input field.
//
&AtClient
Procedure PaymentCalendarPayVATAmountOnChange(Item)
	
	CurrentRow = Items.PaymentCalendar.CurrentData;
	
	InventoryTotal = VATForPaymentCalendar();
	PaymentCalendarTotal = Object.PaymentCalendar.Total("PaymentVATAmount");
	
	If PaymentCalendarTotal > InventoryTotal Then
		CurrentRow.PaymentVATAmount = CurrentRow.PaymentVATAmount - (PaymentCalendarTotal - InventoryTotal);
	EndIf;
	
EndProcedure

// Procedure - OnStartEdit event handler of the .PaymentCalendar list
//
&AtClient
Procedure PaymentCalendarOnStartEdit(Item, NewRow, Copy)
	
	CurrentRow = Items.PaymentCalendar.CurrentData;
	
	If CurrentRow.PaymentPercentage = 0 Then
		CurrentRow.PaymentPercentage = 100 - Object.PaymentCalendar.Total("PaymentPercentage");
		CurrentRow.PaymentAmount = AmountForPaymentCalendar() - Object.PaymentCalendar.Total("PaymentAmount");
		CurrentRow.PaymentVATAmount = VATForPaymentCalendar() - Object.PaymentCalendar.Total("PaymentVATAmount");
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

&AtClient
Procedure FillSalesRepInInventory(SalesRep)
	
	For Each CurrentRow In Object.Inventory Do
		CurrentRow.SalesRep = SalesRep;
	EndDo;
	
EndProcedure

&AtServerNoContext
Function SalesRep(SalesOrder)
	Return CommonUse.ObjectAttributeValue(SalesOrder, "SalesRep");
EndFunction

#EndRegion