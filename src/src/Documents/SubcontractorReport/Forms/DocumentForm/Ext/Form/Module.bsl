
#Region Variables

&AtClient
Var ThisIsNewRow;

#EndRegion

#Region CommonUseProceduresAndFunctions

&AtClient
// The procedure handles the change of the Price kind and Settlement currency document attributes
//
Procedure ProcessPricesKindAndSettlementsCurrencyChange(DocumentParameters)
	
	ContractBeforeChange = DocumentParameters.ContractBeforeChange;
	SettlementsCurrencyBeforeChange = DocumentParameters.SettlementsCurrencyBeforeChange;
	ContractData = DocumentParameters.ContractData;
	QueryPriceKind = DocumentParameters.QueryPriceKind;
	OpenFormPricesAndCurrencies = DocumentParameters.OpenFormPricesAndCurrencies;
	PriceKindChanged = DocumentParameters.PriceKindChanged;
	RecalculationRequired = DocumentParameters.RecalculationRequired;
	
	If Not ContractData.AmountIncludesVAT = Undefined Then
		
		Object.AmountIncludesVAT = ContractData.AmountIncludesVAT;
		
	EndIf;
	
	If ValueIsFilled(Object.Contract) Then 
		
		Object.ExchangeRate      = ?(ContractData.SettlementsCurrencyRateRepetition.ExchangeRate = 0, 1, ContractData.SettlementsCurrencyRateRepetition.ExchangeRate);
		Object.Multiplicity = ?(ContractData.SettlementsCurrencyRateRepetition.Multiplicity = 0, 1, ContractData.SettlementsCurrencyRateRepetition.Multiplicity);
		
	EndIf;
	
	If PriceKindChanged Then
		
		Object.PriceKind = ContractData.PriceKind;
		
	EndIf;
	
	LabelStructure = 
		New Structure("DocumentCurrency, SettlementsCurrency, ExchangeRate, RateNationalCurrency, AmountIncludesVAT, ForeignExchangeAccounting, PriceKind, VATTaxation", 
			Object.DocumentCurrency,
			SettlementsCurrency,
			Object.ExchangeRate,
			RateNationalCurrency,
			Object.AmountIncludesVAT,
			ForeignExchangeAccounting,
			Object.PriceKind,
			Object.VATTaxation);
	
	PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
	
	Object.DocumentCurrency = SettlementsCurrency;
	
	If OpenFormPricesAndCurrencies Then
		
		WarningText = "";
		If PriceKindChanged Then
			
			WarningText = NStr("en = 'The counterparty contract allows
			                   |for the kind of prices other than prescribed in the document. 
			                   |Recalculate the document according to the contract?'") + Chars.LF + Chars.LF;
			
		EndIf;
		
		WarningText = WarningText + NStr("en = 'Settlement currency of the contract with counterparty changed. 
		                                 |It is necessary to check the document currency.'");
		
		ProcessChangesOnButtonPricesAndCurrencies(SettlementsCurrencyBeforeChange, True, PriceKindChanged, WarningText);
		
	ElsIf QueryPriceKind Then
		
		If RecalculationRequired Then
			
			QuestionText = NStr("en = 'The counterparty contract allows
			                    |for the kind of prices other than prescribed in the document. 
			                    |Recalculate the document according to the contract?'");
			
			NotifyDescription = New NotifyDescription("RecalculationQuestionByPriceKindEnd", ThisObject, DocumentParameters);
			ShowQueryBox(NotifyDescription, QuestionText, QuestionDialogMode.YesNo);
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Procedure calls the data processor for document filling by basis.
//
&AtServer
Procedure FillByDocument(BasisDocument)
	
	Document = FormAttributeToValue("Object");
	Document.Filling(BasisDocument, );
	ValueToFormAttribute(Document, "Object");
	Modified = True;
	FillAddedColumns();
	
EndProcedure

// Procedure fills in Inventory by specification.
//
&AtServer
Procedure FillByBillsOfMaterialsAtServer()
	
	Document = FormAttributeToValue("Object");
	NodesBillsOfMaterialstack = New Array;
	Document.FillTabularSectionBySpecification(NodesBillsOfMaterialstack);
	ValueToFormAttribute(Document, "Object");
	Modified = True;
	
EndProcedure

// It receives data set from server for the DateOnChange procedure.
//
&AtServer
Function GetDataDateOnChange(DateBeforeChange, SettlementsCurrency)
	
	DATEDIFF = DriveServer.CheckDocumentNumber(Object.Ref, Object.Date, DateBeforeChange);
	CurrencyRateRepetition = InformationRegisters.ExchangeRates.GetLast(Object.Date, New Structure("Currency", SettlementsCurrency));
	
	StructureData = New Structure;
	
	StructureData.Insert(
		"DATEDIFF",
		DATEDIFF
	);
	StructureData.Insert(
		"CurrencyRateRepetition",
		CurrencyRateRepetition
	);
	
	FillVATRateByCompanyVATTaxation();
	
	Return StructureData;
	
EndFunction

// Gets data set from server.
//
&AtServer
Function GetCompanyDataOnChange()
	
	StructureData = New Structure();
	StructureData.Insert("Company", DriveServer.GetCompany(Object.Company));
	
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
	
EndProcedure

// Receives the set of data from the server for the ProductsOnChange procedure.
//
&AtServerNoContext
Function GetDataProductsOnChange(StructureData)
	
	If StructureData.Property("GLAccounts") Then
		GLAccountsInDocuments.FillProductGLAccountsInStructure(StructureData);
	EndIf;
	
	StructureData.Insert("MeasurementUnit", StructureData.Products.MeasurementUnit);
	
	If StructureData.Property("Characteristic") Then
		StructureData.Insert("Specification", DriveServer.GetDefaultSpecification(StructureData.Products, StructureData.Characteristic));
	Else
		StructureData.Insert("Specification", DriveServer.GetDefaultSpecification(StructureData.Products));
	EndIf;
	
	If StructureData.Property("PriceInTabularSection") Then
		
		If StructureData.Property("PriceKind") Then
			
			Price = DriveServer.GetProductsPriceByPriceKind(StructureData);
			StructureData.Insert("Price", Price);
			
		Else
			
			StructureData.Insert("Price", 0);
			
		EndIf;
		
		Return StructureData;
		
	Else
		
		Return StructureData;
		
	EndIf;
		
EndFunction

// Receives the set of data from the server for the ProductsOnChange procedure.
//
&AtServerNoContext
Function GetDataExpenseOnChange(StructureData)
	
	GLAccounts = GLAccountsInDocuments.GetProductListGLAccounts(StructureData);
	GLAccountsInDocumentsServerCall.FillProductGLAccounts(StructureData, GLAccounts);
	
	If ValueIsFilled(StructureData.Products.VATRate) Then
		StructureData.Insert("VATRate", StructureData.Products.VATRate);
	Else
		StructureData.Insert("VATRate", InformationRegisters.AccountingPolicy.GetDefaultVATRate(, StructureData.Company));
	EndIf;
		
	Return StructureData;
		
EndFunction

// It receives data set from server for the CharacteristicOnChange procedure.
//
&AtServerNoContext
Function GetDataCharacteristicOnChange(StructureData)
	
	StructureData.Insert("Specification", DriveServer.GetDefaultSpecification(StructureData.Products, StructureData.Characteristic));
	
	If StructureData.Property("Price") Then
		If TypeOf(StructureData.MeasurementUnit) = Type("CatalogRef.UOMClassifier") Then
			StructureData.Insert("Factor", 1);
		Else
			StructureData.Insert("Factor", StructureData.MeasurementUnit.Factor);
		EndIf;
		Price = DriveServer.GetProductsPriceByPriceKind(StructureData);
		StructureData.Insert("Price", Price);
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

// It receives data set from the server for the CounterpartyOnChange procedure.
//
&AtServer
Function GetDataCounterpartyOnChange(Date, DocumentCurrency, Counterparty, Company)
	
	ContractByDefault = GetContractByDefault(Object.Ref, Counterparty, Company);
	
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
		"SettlementsInStandardUnits",
		ContractByDefault.SettlementsInStandardUnits
	);
	
	StructureData.Insert(
		"PriceKind",
		ContractByDefault.PriceKind
	);
	
	StructureData.Insert(
		"AmountIncludesVAT",
		?(ValueIsFilled(ContractByDefault.PriceKind), ContractByDefault.PriceKind.PriceIncludesVAT, Undefined)
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
		"PriceKind",
		Contract.PriceKind
	);
	
	StructureData.Insert(
		"SettlementsInStandardUnits",
		Contract.SettlementsInStandardUnits
	);
	
	StructureData.Insert(
		"AmountIncludesVAT",
		?(ValueIsFilled(Contract.PriceKind), Contract.PriceKind.PriceIncludesVAT, Undefined)
	);
	
	Return StructureData;
	
EndFunction

// Procedure calculates the amount in the row of tabular section.
//
&AtClient
Procedure CalculateAmountInTabularSectionLine(TabularSectionRow = Undefined)
	
	If TabularSectionRow = Undefined Then
		TabularSectionRow = Items.Inventory.CurrentData;
	EndIf;
	
	// Amount.
	TabularSectionRow.Amount = TabularSectionRow.Quantity * TabularSectionRow.Price;
	
EndProcedure

// Calculates the VATAmount and Total in the header of document.
//
&AtClient
Procedure CalculateAmountsInHeader(CalculateVATAmount = True)
	
	If (CalculateVATAmount) Then
		
		VATRate = DriveReUse.GetVATRateValue(Object.VATRate);
	
		Object.VATAmount = ?(Object.AmountIncludesVAT,
			Object.Amount - (Object.Amount) / ((VATRate + 100) / 100),
			Object.Amount * VATRate / 100);
		
	EndIf;
	
	Object.Total = Object.Amount + ?(Object.AmountIncludesVAT, 0, Object.VATAmount);
	
EndProcedure

// Recalculates the exchange rate and exchange rate multiplicity of
// the payment currency when the document date is changed.
//
&AtClient
Procedure RecalculateExchangeRateMultiplicitySettlementCurrency(StructureData)
	
	NewExchangeRate	= ?(StructureData.CurrencyRateRepetition.ExchangeRate = 0, 1, StructureData.CurrencyRateRepetition.ExchangeRate);
	NewRatio		= ?(StructureData.CurrencyRateRepetition.Multiplicity = 0, 1, StructureData.CurrencyRateRepetition.Multiplicity);
	
	If Object.ExchangeRate <> NewExchangeRate
		OR Object.Multiplicity <> NewRatio Then
		
		CurrencyRateInLetters		= String(Object.Multiplicity) + " " + TrimAll(SettlementsCurrency) + " = " + String(Object.ExchangeRate) + " " + TrimAll(FunctionalCurrency);
		RateNewCurrenciesInLetters	= String(NewRatio) + " " + TrimAll(SettlementsCurrency) + " = " + String(NewExchangeRate) + " " + TrimAll(FunctionalCurrency);
		
		QuestionParameters = New Structure;
		QuestionParameters.Insert("NewExchangeRate",	NewExchangeRate);
		QuestionParameters.Insert("NewRatio",			NewRatio);
		
		NotifyDescription = New NotifyDescription("QuestionOnRecalculatingPaymentCurrencyRateConversionFactorEnd", ThisObject, QuestionParameters);
		
		QuestionText = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'The exchange rate at the document date is (%1).
			     |Do you want to apply this rate instead of (%2)?'"),
			CurrencyRateInLetters,
			RateNewCurrenciesInLetters);
		
		ShowQueryBox(NotifyDescription, QuestionText, QuestionDialogMode.YesNo);
		
	EndIf;
	
EndProcedure

// Performs the actions after a response to the question about recalculation of the exchange rate and exchange rate multiplier of the payment currency.
//
&AtClient
Procedure QuestionOnRecalculatingPaymentCurrencyRateConversionFactorEnd(Result, AdditionalParameters) Export

	If Result = DialogReturnCode.Yes Then
		
		Object.ExchangeRate = AdditionalParameters.NewExchangeRate;
		Object.Multiplicity = AdditionalParameters.NewRatio;
		
		For Each TabularSectionRow In Object.Prepayment Do
			TabularSectionRow.PaymentAmount = DriveClient.RecalculateFromCurrencyToCurrency(
				TabularSectionRow.SettlementsAmount,
				TabularSectionRow.ExchangeRate,
				?(Object.DocumentCurrency = FunctionalCurrency, RateNationalCurrency, Object.ExchangeRate),
				TabularSectionRow.Multiplicity,
				?(Object.DocumentCurrency = FunctionalCurrency, RepetitionNationalCurrency, Object.Multiplicity));
		EndDo;
		
		// Generate price and currency label.
		LabelStructure = New Structure("PriceKind, DocumentCurrency, SettlementsCurrency, ExchangeRate, RateNationalCurrency, AmountIncludesVAT, ForeignExchangeAccounting, VATTaxation", Object.PriceKind, Object.DocumentCurrency, SettlementsCurrency, Object.ExchangeRate, RateNationalCurrency, Object.AmountIncludesVAT, ForeignExchangeAccounting, Object.VATTaxation);
		PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
		
	EndIf;

EndProcedure

// Procedure executes recalculate in the document tabular section
// after changes in "Prices and currency" form.Column recalculation is executed:
// price, discount, amount, VAT amount, total.
//
&AtClient
Procedure ProcessChangesOnButtonPricesAndCurrencies(Val SettlementsCurrencyBeforeChange, RecalculatePrices = False, RefillPrices = False, WarningText = "")
	
	// 1. Form parameter structure to fill the "Prices and Currency" form.
	ParametersStructure = New Structure;
	ParametersStructure.Insert("DocumentCurrency",		  Object.DocumentCurrency);
	ParametersStructure.Insert("ExchangeRate",				  Object.ExchangeRate);
	ParametersStructure.Insert("Multiplicity",			  Object.Multiplicity);
	ParametersStructure.Insert("VATTaxation",	  Object.VATTaxation);
	ParametersStructure.Insert("AmountIncludesVAT",	  Object.AmountIncludesVAT);
	ParametersStructure.Insert("IncludeVATInPrice", Object.IncludeVATInPrice);
	ParametersStructure.Insert("Counterparty",			  Object.Counterparty);
	ParametersStructure.Insert("Contract",				  Object.Contract);
	ParametersStructure.Insert("Company",			  Company);
	ParametersStructure.Insert("DocumentDate",		  Object.Date);
	ParametersStructure.Insert("RefillPrices",	  RefillPrices);
	ParametersStructure.Insert("RecalculatePrices",		  RecalculatePrices);
	ParametersStructure.Insert("WereMadeChanges",  False);
	ParametersStructure.Insert("WarningText",   WarningText);
	ParametersStructure.Insert("ReverseChargeNotApplicable", True);
	
	ParametersStructure.Insert("PriceKind", Object.PriceKind);
	
	// Open form "Prices and Currency".
	// Refills tabular section "Costs" if changes were made in the "Price and Currency" form.
	NotifyDescription = New NotifyDescription("OpenPricesAndCurrencyFormEnd", ThisObject, New Structure("SettlementsCurrencyBeforeChange", SettlementsCurrencyBeforeChange));
	OpenForm("CommonForm.PricesAndCurrency", ParametersStructure, ThisForm,,,, NotifyDescription, FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtClient
// Procedure-handler of the result of opening the "Prices and currencies" form
//
Procedure OpenPricesAndCurrencyFormEnd(ClosingResult, AdditionalParameters) Export
	
	StructurePricesAndCurrency = ClosingResult;
	SettlementsCurrencyBeforeChange = AdditionalParameters.SettlementsCurrencyBeforeChange;
	
	If TypeOf(StructurePricesAndCurrency) = Type("Structure") AND StructurePricesAndCurrency.WereMadeChanges Then
		
		Object.PriceKind = StructurePricesAndCurrency.PriceKind;
		Object.DocumentCurrency = StructurePricesAndCurrency.DocumentCurrency;
		Object.ExchangeRate = StructurePricesAndCurrency.PaymentsRate;
		Object.Multiplicity = StructurePricesAndCurrency.SettlementsMultiplicity;
		Object.VATTaxation = StructurePricesAndCurrency.VATTaxation;
		Object.AmountIncludesVAT = StructurePricesAndCurrency.AmountIncludesVAT;
		Object.IncludeVATInPrice = StructurePricesAndCurrency.IncludeVATInPrice;
		
		// Recalculate prices by kind of prices.
		If StructurePricesAndCurrency.RefillPrices Then
			RefillTabularSectionPricesByPriceKind();
		EndIf;
		
		// Recalculate prices by currency.
		If Not StructurePricesAndCurrency.RefillPrices
			AND StructurePricesAndCurrency.RecalculatePrices Then
			RecalculateTabularSectionPricesByCurrency(SettlementsCurrencyBeforeChange);
		EndIf;
		
		For Each TabularSectionRow In Object.Prepayment Do
			TabularSectionRow.PaymentAmount = DriveClient.RecalculateFromCurrencyToCurrency(
				TabularSectionRow.SettlementsAmount,
				TabularSectionRow.ExchangeRate,
				?(Object.DocumentCurrency = FunctionalCurrency, RateNationalCurrency, Object.ExchangeRate),
				TabularSectionRow.Multiplicity,
				?(Object.DocumentCurrency = FunctionalCurrency, RepetitionNationalCurrency, Object.Multiplicity));  
		EndDo;
		
	EndIf;
	
	LabelStructure = New Structure("PriceKind, DocumentCurrency, SettlementsCurrency, ExchangeRate, RateNationalCurrency, AmountIncludesVAT, ForeignExchangeAccounting, VATTaxation", 
		Object.PriceKind, 
		Object.DocumentCurrency, 
		SettlementsCurrency, 
		Object.ExchangeRate, 
		RateNationalCurrency, 
		Object.AmountIncludesVAT, 
		ForeignExchangeAccounting, 
		Object.VATTaxation
	);
	
	PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
	
EndProcedure

// Recalculate the price of the tabular section after making changes in the "Prices and currency" form.
// 
&AtClient
Procedure RefillTabularSectionPricesByPriceKind()
	
	DataStructure = New Structure;
	DocumentTabularSection = New Array;

	DataStructure.Insert("Date",				Object.Date);
	DataStructure.Insert("Company",				Company);
	DataStructure.Insert("PriceKind",			Object.PriceKind);
	DataStructure.Insert("DocumentCurrency",	Object.DocumentCurrency);
	
	For Each TSRow In Object.Inventory Do
		
		TSRow.Price = 0;
		
		If Not ValueIsFilled(TSRow.Products) Then
			Continue;
		EndIf; 
		
		TabularSectionRow = New Structure();
		TabularSectionRow.Insert("Products",		TSRow.Products);
		TabularSectionRow.Insert("Characteristic",	TSRow.Characteristic);
		TabularSectionRow.Insert("MeasurementUnit",	TSRow.MeasurementUnit);
		TabularSectionRow.Insert("Price",			0);
		
		DocumentTabularSection.Add(TabularSectionRow);
		
	EndDo;
		
	DriveServer.GetTabularSectionPricesByPriceKind(DataStructure, DocumentTabularSection);
		
	For Each TSRow In DocumentTabularSection Do

		SearchStructure = New Structure;
		SearchStructure.Insert("Products",			TSRow.Products);
		SearchStructure.Insert("Characteristic",	TSRow.Characteristic);
		SearchStructure.Insert("MeasurementUnit",	TSRow.MeasurementUnit);
		
		SearchResult = Object.Inventory.FindRows(SearchStructure);
		
		For Each ResultRow In SearchResult Do
			
			ResultRow.Price = TSRow.Price;
			CalculateAmountInTabularSectionLine(ResultRow);
			
		EndDo;
		
	EndDo;
	
EndProcedure

// Recalculate price by document tabular section currency after changes in the "Prices and currency" form.
//
&AtClient
Procedure RecalculateTabularSectionPricesByCurrency(PreviousCurrency)
	
	RatesStructure = DriveServer.GetExchangeRates(PreviousCurrency, Object.DocumentCurrency, Object.Date);
	
	For Each TabularSectionRow In Object.Inventory Do
		
		TabularSectionRow.Price = DriveClient.RecalculateFromCurrencyToCurrency(
			TabularSectionRow.Price,
			RatesStructure.InitRate,
			RatesStructure.ExchangeRate,
			RatesStructure.RepetitionBeg,
			RatesStructure.Multiplicity);
		
		CalculateAmountInTabularSectionLine(TabularSectionRow);
		
	EndDo;

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
			StructureProductsData.Insert("PriceInTabularSection", True);
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
				NewRow.Specification = BarcodeData.StructureProductsData.Specification;
				NewRow.Quantity = CurBarcode.Quantity;
				NewRow.MeasurementUnit = ?(ValueIsFilled(BarcodeData.MeasurementUnit), BarcodeData.MeasurementUnit, BarcodeData.StructureProductsData.MeasurementUnit);
				NewRow.Price = BarcodeData.StructureProductsData.Price;
				CalculateAmountInTabularSectionLine(NewRow);
				Items.Inventory.CurrentRow = NewRow.GetID();
			Else
				FoundString = TSRowsArray[0];
				FoundString.Quantity = FoundString.Quantity + CurBarcode.Quantity;
				CalculateAmountInTabularSectionLine(FoundString);
				Items.Inventory.CurrentRow = FoundString.GetID();
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
			
			DocumentParameters.Insert("CounterpartyBeforeChange", ContractData.CounterpartyBeforeChange);
			DocumentParameters.Insert("CounterpartyDoSettlementsByOrdersBeforeChange", ContractData.CounterpartyDoSettlementsByOrdersBeforeChange);
			
		EndIf;
		
		QueryBoxPrepayment = (Object.Prepayment.Count() > 0 AND Object.Contract <> ContractBeforeChange);
		
		PriceKindChanged = Object.PriceKind <> ContractData.PriceKind AND ValueIsFilled(ContractData.PriceKind);
		QueryPriceKind = ValueIsFilled(Object.Contract) AND PriceKindChanged;
		
		SettlementsCurrencyBeforeChange = SettlementsCurrency;
		SettlementsCurrency = ContractData.SettlementsCurrency;
		
		NewContractAndCalculationCurrency = ValueIsFilled(Object.Contract) AND ValueIsFilled(SettlementsCurrency)
			AND Object.Contract <> ContractBeforeChange AND SettlementsCurrencyBeforeChange <> ContractData.SettlementsCurrency;
		OpenFormPricesAndCurrencies = Object.DocumentCurrency <> ContractData.SettlementsCurrency
			AND Object.Inventory.Count() > 0;
		
		DocumentParameters.Insert("ContractBeforeChange", ContractBeforeChange);
		DocumentParameters.Insert("SettlementsCurrencyBeforeChange", SettlementsCurrencyBeforeChange);
		DocumentParameters.Insert("ContractData", ContractData);
		DocumentParameters.Insert("PriceKindChanged", PriceKindChanged);
		DocumentParameters.Insert("QueryPriceKind", QueryPriceKind);
		DocumentParameters.Insert("OpenFormPricesAndCurrencies", OpenFormPricesAndCurrencies);
		DocumentParameters.Insert("ContractVisibleBeforeChange", Items.Contract.Visible);
		DocumentParameters.Insert("RecalculationRequired", Object.Inventory.Count() > 0);
		
		If QueryBoxPrepayment = True Then
			
			QuestionText = NStr("en = 'Prepayment setoff will be cleared, continue?'");
			
			NotifyDescription = New NotifyDescription("DefineAdvancePaymentOffsetsRefreshNeed", ThisObject, DocumentParameters);
			ShowQueryBox(NotifyDescription, QuestionText, QuestionDialogMode.YesNo);
			
		Else
			
			ProcessPricesKindAndSettlementsCurrencyChange(DocumentParameters);
			
		EndIf;
		
	Else
		
		Object.BasisDocument = Order;
		
	EndIf;
	
	Order = Object.BasisDocument;
	
EndProcedure

&AtClient
// Handler procedure of answering the question on document recalculation according to the prices kind.
//
Procedure RecalculationQuestionByPriceKindEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		
		RefillTabularSectionPricesByPriceKind();
		
	EndIf;
	
EndProcedure

&AtServer
Procedure StructuralUnitOnChangeAtServer()
	FillAddedColumns(True);
EndProcedure

&AtClient
Procedure OpenProductGLAccountsForm(SelectedValue, TabName, AttributeName = "Products")

	If SelectedValue = Undefined Then
		Return;
	EndIf;

	If Not ReadOnly Then
		LockFormDataForEdit();
	EndIf;

	If TabName = "Inventory" Or TabName = "Disposals" Then
		RowData = Object[TabName].FindByID(SelectedValue);
	Else
		RowData = SelectedValue;
	EndIf;
	
	ObjectParameters = GetObjectParameters(Object);
	StructureData = GetStructureData(ObjectParameters, TabName, RowData);
	
	GLAccountsForFilling = GLAccountsInDocumentsClientServer.GetGLAccountsStructure(StructureData);
	GLAccountsForFilling.Insert("TableName",	TabName);
	GLAccountsForFilling.Insert("Products",		RowData[AttributeName]);

	OpenForm("CommonForm.ProductGLAccounts", GLAccountsForFilling, ThisObject);
	
EndProcedure

&AtClient
Procedure AddGLAccountsToStructure(StructureData, TabRow)
	
	If StructureData.TabName = "Inventory" Then
		
		StructureData.Insert("InventoryTransferredGLAccount", TabRow.InventoryTransferredGLAccount);
		StructureData.Insert("GLAccounts",			TabRow.GLAccounts);
		StructureData.Insert("GLAccountsFilled",	TabRow.GLAccountsFilled);
		
	ElsIf StructureData.TabName = "Product" Then
		
		StructureData.Insert("ConsumptionGLAccount", TabRow.ConsumptionGLAccount);
		StructureData.Insert("InventoryGLAccount", TabRow.InventoryGLAccount);
		StructureData.Insert("GLAccounts", "");
		
	ElsIf StructureData.TabName = "Disposals" Then
		
		StructureData.Insert("InventoryGLAccount",	TabRow.InventoryGLAccount);
		StructureData.Insert("GLAccounts",			TabRow.GLAccounts);
		StructureData.Insert("GLAccountsFilled",	TabRow.GLAccountsFilled);
		
	ElsIf StructureData.TabName = "SubcontractorFees" Then
		
		StructureData.Insert("VATInputGLAccount", TabRow.VATInputGLAccount);
		StructureData.Insert("GLAccounts", "");
		
	EndIf;
	
EndProcedure

&AtServer
Procedure FillAddedColumns(GetGLAccounts = False)
	
	ObjectParameters = GetObjectParameters(Object);
	
	Tables = New Array();
	
	TableInventory = GetStructureData(ObjectParameters, "Inventory");
	TableDisposals = GetStructureData(ObjectParameters, "Disposals");
	
	Tables.Add(TableInventory);
	Tables.Add(TableDisposals);
	
	ProductInHeader = GetStructureData(ObjectParameters, "Product");
	SubcontractorFeesInHeader = GetStructureData(ObjectParameters, "SubcontractorFees");
	
	Tables.Add(ProductInHeader);
	Tables.Add(SubcontractorFeesInHeader);
	
	GLAccountsInDocuments.FillGLAccountsInTable(Object, Tables, GetGLAccounts);
	
	Items.GLAccountsSubcontractorFees.Title = SubcontractorFeesInHeader.GLAccounts;
	Items.GLAccountsProduct.Title = ProductInHeader.GLAccounts;
	
EndProcedure

&AtServer
Function GetObjectParameters(Val FormObject)

	ObjectParameters = New Structure;
	ObjectParameters.Insert("Ref", FormObject.Ref);
	ObjectParameters.Insert("Company", FormObject.Company);
	ObjectParameters.Insert("Date", FormObject.Date);
	ObjectParameters.Insert("Products", FormObject.Products);
	ObjectParameters.Insert("Expense", FormObject.Expense);
	ObjectParameters.Insert("ConsumptionGLAccount", FormObject.ConsumptionGLAccount);
	ObjectParameters.Insert("InventoryGLAccount", FormObject.InventoryGLAccount);
	ObjectParameters.Insert("VATInputGLAccount", FormObject.VATInputGLAccount);
	ObjectParameters.Insert("StructuralUnit", FormObject.StructuralUnit);
	ObjectParameters.Insert("StructuralUnitType", CommonUse.ObjectAttributeValue(FormObject.StructuralUnit, "StructuralUnitType"));
	
	Return ObjectParameters;
	
EndFunction

&AtClient
Procedure GLAccountsChoiceProcessingAtClient(GLAccounts)

	TabName = GLAccounts.TableName;
	ObjectParameters = GetObjectParameters(Object);
	
	If TabName = "Inventory" Or TabName = "Disposals" Then
		TabRow = Items[TabName].CurrentData;
		FillPropertyValues(TabRow, GLAccounts);
	ElsIf TabName = "Product" Then
		TabRow = Object;
		
		If ObjectParameters.StructuralUnitType = PredefinedValue("Enum.BusinessUnitsTypes.Department") Then
			Object.ConsumptionGLAccount = GLAccounts.ConsumptionGLAccount;
		Else
			Object.InventoryGLAccount = GLAccounts.InventoryGLAccount;
		EndIf;
		
	ElsIf TabName = "SubcontractorFees" Then
		TabRow = Object;
		Object.VATInputGLAccount = GLAccounts.VATInputGLAccount;
	EndIf;
	
	Modified = True;
	StructureData = GetStructureData(ObjectParameters, TabName, TabRow);
	
	GLAccountsForFilling = GLAccountsInDocumentsClientServer.GetGLAccountsStructure(StructureData);
	GLAccountsInDocumentsClientServer.FillProductGLAccountsDescription(StructureData, GLAccountsForFilling);
	FillPropertyValues(TabRow, StructureData);
	
	If StructureData.TabName = "Product" Then
		Items.GLAccountsProduct.Title = StructureData.GLAccounts;
	ElsIf StructureData.TabName = "SubcontractorFees" Then
		Items.GLAccountsSubcontractorFees.Title = StructureData.GLAccounts;
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Function GetStructureData(ObjectParameters, TabName, RowData = Undefined, ProductName = "Products") Export
	
	If TabName = "Inventory" Then
		
		StructureData = New Structure("Products, TabName, InventoryTransferredGLAccount, GLAccounts, GLAccountsFilled");
		
	ElsIf TabName = "Disposals" Then
		
		StructureData = New Structure("Products, TabName, InventoryGLAccount, GLAccounts, GLAccountsFilled");
		
	ElsIf TabName = "Product" Then
		
		StructureData = New Structure;
		StructureData.Insert("Products", ObjectParameters.Products);
		StructureData.Insert("GLAccounts", "");
		
		If ObjectParameters.StructuralUnitType = PredefinedValue("Enum.BusinessUnitsTypes.Department") Then
			StructureData.Insert("ConsumptionGLAccount", ObjectParameters.ConsumptionGLAccount);
		Else
			StructureData.Insert("InventoryGLAccount", ObjectParameters.InventoryGLAccount);
		EndIf;
	
	ElsIf TabName = "SubcontractorFees" Then
		
		StructureData = New Structure;
		StructureData.Insert("Products", ObjectParameters.Expense);
		StructureData.Insert("VATInputGLAccount", ObjectParameters.VATInputGLAccount);
		StructureData.Insert("GLAccounts", "");
		
	EndIf;
	
	If RowData <> Undefined Then 
		FillPropertyValues(StructureData, RowData);
	EndIf;
		
	StructureData.Insert("ObjectParameters", ObjectParameters);
	StructureData.Insert("TabName", TabName);
	StructureData.Insert("ProductName", ProductName);
	
	Return StructureData;

EndFunction

#EndRegion

#Region WorkWithSelection

// Procedure - event handler Action of the Pick command
//
&AtClient
Procedure InventoryPick(Command)
	
	TabularSectionName	= "Inventory";
	DocumentPresentaion	= NStr("en = 'subcontractor report'");
	SelectionParameters	= DriveClient.GetSelectionParameters(ThisObject, TabularSectionName, DocumentPresentaion, True, True, True);
	SelectionParameters.Insert("Company", Company);
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

// Procedure - event handler Action of the Pick command
//
&AtClient
Procedure DisposalsPick(Command)
	
	TabularSectionName	= "Disposals";
	DocumentPresentaion	= NStr("en = 'subcontractor report'");
	SelectionParameters	= DriveClient.GetSelectionParameters(ThisObject, TabularSectionName, DocumentPresentaion, True, False, True);
	SelectionParameters.Insert("Company", Company);
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

// Function gets a product list from the temporary storage
//
&AtServer
Procedure GetInventoryFromStorage(InventoryAddressInStorage, TabularSectionName, AreCharacteristics, AreBatches)
	
	TableForImport = GetFromTempStorage(InventoryAddressInStorage);
	
	ObjectParameters = GetObjectParameters(Object);
	StructureData = GetStructureData(ObjectParameters, TabularSectionName);
	
	For Each ImportRow In TableForImport Do
		
		NewRow = Object[TabularSectionName].Add();
		FillPropertyValues(NewRow, ImportRow);
		
		FillPropertyValues(StructureData, NewRow);
		
		GLAccounts = GLAccountsInDocuments.GetProductListGLAccounts(StructureData);
		GLAccountsInDocumentsServerCall.FillProductGLAccounts(StructureData, GLAccounts);
		FillPropertyValues(NewRow, StructureData);
		
	EndDo;
	
EndProcedure

// Function places the list of advances into temporary storage and returns the address
//
&AtServer
Function PlacePrepaymentToStorage()
	
	Return PutToTempStorage(
		Object.Prepayment.Unload(,
			"Document,
			|SettlementsAmount,
			|ExchangeRate,
			|Multiplicity,
			|PaymentAmount"),
		UUID
	);
	
EndFunction

// Function gets the list of advances from the temporary storage
//
&AtServer
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
			
			InventoryAddressInStorage = ClosingResult.CartAddressInStorage;
			
			TabularSectionName = ?(Items.Pages.CurrentPage = Items.GroupInventory, "Inventory", "Disposals");
			
			GetInventoryFromStorage(InventoryAddressInStorage, TabularSectionName, True, True);
			
		EndIf;
		
	EndIf;
	
EndProcedure
#EndRegion

#Region FormEventsHandlers

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

// Procedure - OnCreateAtServer event handler.
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
	
	// Form attributes setting.
	DocumentDate = Object.Date;
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentDate();
	EndIf;
	
	Company = DriveServer.GetCompany(Object.Company);
	Counterparty = Object.Counterparty;
	Contract = Object.Contract;
	Order = Object.BasisDocument;
	SettlementsCurrency = Object.Contract.SettlementsCurrency;
	FunctionalCurrency = Constants.FunctionalCurrency.Get();
	StructureByCurrency = InformationRegisters.ExchangeRates.GetLast(Object.Date, New Structure("Currency", FunctionalCurrency));
	RateNationalCurrency = StructureByCurrency.ExchangeRate;
	RepetitionNationalCurrency = StructureByCurrency.Multiplicity;
	
	If Not ValueIsFilled(Object.Ref)
		AND Not ValueIsFilled(Parameters.Basis) 
		AND Not ValueIsFilled(Parameters.CopyingValue) Then
		FillVATRateByCompanyVATTaxation();
	EndIf;
	
	// Generate price and currency label.
	ForeignExchangeAccounting = Constants.ForeignExchangeAccounting.Get();
	LabelStructure = New Structure("PriceKind, DocumentCurrency, SettlementsCurrency, ExchangeRate, RateNationalCurrency, AmountIncludesVAT, ForeignExchangeAccounting, VATTaxation", Object.PriceKind, Object.DocumentCurrency, SettlementsCurrency, Object.ExchangeRate, RateNationalCurrency, Object.AmountIncludesVAT, ForeignExchangeAccounting, Object.VATTaxation);
	PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
	
	Items.SalesOrder.Enabled = Not ValueIsFilled(Object.BasisDocument);
	
	If Not Constants.UseSeveralDepartments.Get()
		AND Not Constants.UseSeveralWarehouses.Get() Then
		
		Items.StructuralUnit.ListChoiceMode = True;
		Items.StructuralUnit.ChoiceList.Add(Catalogs.BusinessUnits.MainWarehouse);
		Items.StructuralUnit.ChoiceList.Add(Catalogs.BusinessUnits.MainDepartment);
		
	EndIf;
	
	FillAddedColumns();
	
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

// Procedure - event handler OnOpen.
//
&AtClient
Procedure OnOpen(Cancel)
	
	// Peripherals
	EquipmentManagerClientOverridable.StartConnectingEquipmentOnFormOpen(ThisForm, "BarCodeScanner");
	// End Peripherals
	
EndProcedure

// Procedure - event handler OnClose.
//
&AtClient
Procedure OnClose(Exit)
	
	// Peripherals
	EquipmentManagerClientOverridable.StartDisablingEquipmentOnCloseForm(ThisForm);
	// End Peripherals
	
EndProcedure

// Procedure - event handler AfterWriting.
//
&AtClient
Procedure AfterWrite(WriteParameters)
	
	If ValueIsFilled(Object.BasisDocument) Then
		Notify("Record_ProcessersReport", Object.Ref);
	EndIf;
	
	Notify("NotificationAboutChangingDebt");
	
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

// Procedure-handler of the BeforeWriteAtServer event.
//
&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	If WriteParameters.WriteMode = DocumentWriteMode.Posting Then
		
		MessageText = "";
		CheckContractToDocumentConditionAccordance(MessageText, Object.Contract, Object.Ref, Object.Company, Object.Counterparty, Cancel);
		
		If MessageText <> "" Then
			
			Message = New UserMessage;
			Message.Text = ?(Cancel, NStr("en = 'Document is not posted.'") + " " + MessageText, MessageText);
			
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

#EndRegion

#Region HeaderFormItemsEventsHandlers

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
		StructureData = GetDataDateOnChange(DateBeforeChange, SettlementsCurrency);
		If StructureData.DATEDIFF <> 0 Then
			Object.Number = "";
		EndIf;
		
		If ValueIsFilled(SettlementsCurrency) Then
			RecalculateExchangeRateMultiplicitySettlementCurrency(StructureData);
		EndIf;
		
		LabelStructure = New Structure("PriceKind, DocumentCurrency, SettlementsCurrency, ExchangeRate, RateNationalCurrency, AmountIncludesVAT, ForeignExchangeAccounting, VATTaxation", Object.PriceKind, Object.DocumentCurrency, SettlementsCurrency, Object.ExchangeRate, RateNationalCurrency, Object.AmountIncludesVAT, ForeignExchangeAccounting, Object.VATTaxation);
		PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
		
	EndIf;
	
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
	Company = StructureData.Company;
	
	LabelStructure = New Structure("PriceKind, DocumentCurrency, SettlementsCurrency, ExchangeRate, RateNationalCurrency, AmountIncludesVAT, ForeignExchangeAccounting, VATTaxation", Object.PriceKind, Object.DocumentCurrency, SettlementsCurrency, Object.ExchangeRate, RateNationalCurrency, Object.AmountIncludesVAT, ForeignExchangeAccounting, Object.VATTaxation);
	PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
	
	Object.Contract = GetContractByDefault(Object.Ref, Object.Counterparty, Object.Company);
	ProcessContractChange();
	
EndProcedure

&AtClient
Procedure GLAccountsProduct(Command)
	OpenProductGLAccountsForm(Object, "Product");
EndProcedure

// Procedure - event handler OnChange of the Products input field.
//
&AtClient
Procedure ProductsOnChange(Item)
	
	StructureData = New Structure;
	StructureData.Insert("Products", Object.Products);
	StructureData.Insert("TabName", "Product");
	StructureData.Insert("ObjectParameters", GetObjectParameters(Object));
	
	AddGLAccountsToStructure(StructureData, Object);	
	StructureData = GetDataProductsOnChange(StructureData);
	
	Object.MeasurementUnit = StructureData.MeasurementUnit;
	Object.Specification = StructureData.Specification;
	Object.Quantity = 1;
	
	FillPropertyValues(Object, StructureData); 
	Items.GLAccountsProduct.Title = StructureData.GLAccounts;
	
	// Serial numbers
	Object.SerialNumbers.Clear();
	
EndProcedure

&AtClient
Procedure StructuralUnitOnChange(Item)
	StructuralUnitOnChangeAtServer();
EndProcedure

// Procedure - event handler OnChange of the Characteristic input field.
//
&AtClient
Procedure CharacteristicOnChange(Item)
	
	StructureData = New Structure;
	StructureData.Insert("Products", Object.Products);
	StructureData.Insert("Characteristic", Object.Characteristic);
	
	StructureData = GetDataProductsOnChange(StructureData);
	
	Object.Specification = StructureData.Specification;
	
EndProcedure

&AtClient
Procedure SerialNumbersPresentationStartChoice(Item, ChoiceData, StandardProcessing)
	StandardProcessing = False;
	ParametersOfSerialNumbers = SerialNumberPickParametersInInputField();
	OpenForm("DataProcessor.SerialNumbersSelection.Form", ParametersOfSerialNumbers, ThisObject);
EndProcedure

&AtClient
Procedure QuantityOnChange(Item)
	
	// Serial numbers
	If TypeOf(Object.MeasurementUnit)=Type("CatalogRef.UOM") Then
		StructureData = GetDataMeasurementUnitOnChange(Object.MeasurementUnit);
		Ratio = StructureData.Factor;
	Else
		Ratio = 1;
	EndIf;
	
	ProductsQuantity = Object.Quantity * Ratio;

	If ProductsQuantity < Object.SerialNumbers.Count() AND ProductsQuantity > 0 Then
		For n=ProductsQuantity To Object.SerialNumbers.Count()-1 Do
			RowDelete = Object.SerialNumbers[n];
			Object.SerialNumbers.Delete(RowDelete);
		EndDo;
	EndIf;

	StringPresentationOfSerialNumbers = "";
	For Each Str In Object.SerialNumbers Do
		StringPresentationOfSerialNumbers = StringPresentationOfSerialNumbers + Str.SerialNumber+"; ";
	EndDo;
	Object.SerialNumbersPresentation = Left(StringPresentationOfSerialNumbers, Min(StrLen(StringPresentationOfSerialNumbers)-2,150));
	
EndProcedure

// Procedure - OnChange event handler of the Expense input field.
//
&AtClient
Procedure ExpenseOnChange(Item)
	
	StructureData = New Structure;
	StructureData.Insert("Company", Object.Company);
	StructureData.Insert("Products", Object.Expense);
	StructureData.Insert("TabName", "SubcontractorFees");
	StructureData.Insert("ObjectParameters", GetObjectParameters(Object));
	
	AddGLAccountsToStructure(StructureData, Object);	
	StructureData = GetDataExpenseOnChange(StructureData);
	
	Object.Amount = 0;
	Object.VATRate = StructureData.VATRate;
	Object.VATAmount = 0;
	Object.Total = 0;
	FillPropertyValues(Object, StructureData); 
	Items.GLAccountsSubcontractorFees.Title = StructureData.GLAccounts;
	
EndProcedure

&AtClient
Procedure GLAccountsSubcontractorFees(Command)
	OpenProductGLAccountsForm(Object, "SubcontractorFees", "Expense");
EndProcedure

// Procedure - event handler OnChange of the Amount input field.
//
&AtClient
Procedure AmountOnChange(Item)
	
	CalculateAmountsInHeader();
	
EndProcedure

// Procedure - event handler OnChange of the VATRate input field.
//
&AtClient
Procedure VATRateOnChange(Item)
	
	CalculateAmountsInHeader();
	
EndProcedure

// Procedure - OnChange event handler of the VATAmount input field.
//
&AtClient
Procedure VATAmountOnChange(Item)
	
	CalculateAmountsInHeader(False);
	
EndProcedure

// Procedure - event handler OnChange of the Counterparty input field.
// Clears the contract and tabular section.
//
&AtClient
Procedure CounterpartyOnChange(Item)
	
	CounterpartyBeforeChange = Counterparty;
	CounterpartyDoSettlementsByOrdersBeforeChange = CounterpartyDoSettlementsByOrders;
	Counterparty = Object.Counterparty;
	
	If CounterpartyBeforeChange <> Object.Counterparty Then
		
		ContractVisibleBeforeChange = Items.Contract.Visible;
		
		StructureData = GetDataCounterpartyOnChange(Object.Date, Object.DocumentCurrency, Object.Counterparty, Object.Company);
		Object.Contract = StructureData.Contract;
		
		StructureData.Insert("CounterpartyBeforeChange", CounterpartyBeforeChange);
		StructureData.Insert("CounterpartyDoSettlementsByOrdersBeforeChange", CounterpartyDoSettlementsByOrdersBeforeChange);
		
		ProcessContractChange(StructureData);
		
	Else
		
		Object.Contract = Contract; // Restore the cleared contract automatically.
		Object.BasisDocument = Order;
		
	EndIf;
	
	Order = Object.BasisDocument;
	
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
	
	FormParameters = GetChoiceFormParameters(Object.Ref, Object.Company, Object.Counterparty, Object.Contract);
	If FormParameters.ControlContractChoice Then
		
		StandardProcessing = False;
		OpenForm("Catalog.CounterpartyContracts.Form.ChoiceForm", FormParameters, Item);
		
	EndIf;
	
EndProcedure

// Procedure - handler of the OnChange event of the BasisDocument input field.
//
&AtClient
Procedure BasisDocumentOnChange(Item)
	
	If Object.Prepayment.Count() > 0
	   AND Object.BasisDocument <> Order
	   AND CounterpartyDoSettlementsByOrders Then
		Mode = QuestionDialogMode.YesNo;
		Response = Undefined;

		ShowQueryBox(New NotifyDescription("BaseDocumentOnChangeEnd", ThisObject), NStr("en = 'Prepayment setoff will be cleared, continue?'"), Mode, 0);
        Return;
	EndIf;
	
	BaseDocumentOnChangeFragment();
EndProcedure

&AtClient
Procedure BaseDocumentOnChangeEnd(Result, AdditionalParameters) Export
    
    Response = Result;
    If Response = DialogReturnCode.Yes Then
        Object.Prepayment.Clear();
    Else
        Object.BasisDocument = Order;
        Return;
    EndIf;
    
    BaseDocumentOnChangeFragment();

EndProcedure

&AtClient
Procedure BaseDocumentOnChangeFragment()
    
    Order = Object.BasisDocument;
    Items.SalesOrder.Enabled = Not ValueIsFilled(Object.BasisDocument);

EndProcedure

// Procedure - event handler Field opening StructuralUnit.
//
&AtClient
Procedure StructuralUnitOpening(Item, StandardProcessing)
	
	If Items.StructuralUnit.ListChoiceMode
		AND Not ValueIsFilled(Object.StructuralUnit) Then
		
		StandardProcessing = False;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormTableItemEventHandlersInventory

&AtClient
Procedure InventoryOnStartEdit(Item, NewRow, Clone)
	
	If Not NewRow Or Clone Then
		Return;	
	EndIf;
	
	Item.CurrentData.GLAccounts = GLAccountsInDocumentsClientServer.GetEmptyGLAccountPresentation();

EndProcedure

&AtClient
Procedure InventorySelection(Item, SelectedRow, Field, StandardProcessing)
	
	If Field.Name = "InventoryGLAccounts" Then
		StandardProcessing = False;
		OpenProductGLAccountsForm(SelectedRow, "Inventory");
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
			OpenProductGLAccountsForm(SelectedRow, "Inventory");
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure InventoryOnEditEnd(Item, NewRow, CancelEdit)
	ThisIsNewRow = False;
EndProcedure

&AtClient
Procedure InventoryGLAccountsStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	SelectedRow = Items.Inventory.CurrentRow;
	OpenProductGLAccountsForm(SelectedRow, "Inventory");
	
EndProcedure

// Procedure - event handler OnChange of the Products input field.
//
&AtClient
Procedure InventoryProductsOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("Company", Object.Company);
	StructureData.Insert("Products", TabularSectionRow.Products);
	StructureData.Insert("PriceInTabularSection", True);
	StructureData.Insert("VATTaxation", Object.VATTaxation);
	StructureData.Insert("TabName", "Inventory");
	
	If ValueIsFilled(Object.PriceKind) Then
		
		StructureData.Insert("ProcessingDate", 		Object.Date);
		StructureData.Insert("PriceKind", 				Object.PriceKind);
		StructureData.Insert("DocumentCurrency", 	Object.DocumentCurrency);
		StructureData.Insert("AmountIncludesVAT", 	Object.AmountIncludesVAT);
		StructureData.Insert("Characteristic", 		TabularSectionRow.Characteristic);
		StructureData.Insert("Factor", 		1);
		
	EndIf;
	
	StructureData.Insert("ObjectParameters", GetObjectParameters(Object));
	AddGLAccountsToStructure(StructureData, TabularSectionRow);	
	StructureData = GetDataProductsOnChange(StructureData);
	
	FillPropertyValues(TabularSectionRow, StructureData); 
	TabularSectionRow.MeasurementUnit = StructureData.MeasurementUnit;
	TabularSectionRow.Quantity = 1;
	TabularSectionRow.Price = StructureData.Price;
	TabularSectionRow.Specification = StructureData.Specification;
	
	CalculateAmountInTabularSectionLine();
	
EndProcedure

// Procedure - event handler OnChange of the Characteristic input field.
//
&AtClient
Procedure InventoryCharacteristicOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("Products", 	TabularSectionRow.Products);
	StructureData.Insert("Characteristic",	TabularSectionRow.Characteristic);
	
	If ValueIsFilled(Object.PriceKind) Then
	
		StructureData.Insert("ProcessingDate", 		Object.Date);
		StructureData.Insert("PriceKind", 				Object.PriceKind);
		StructureData.Insert("DocumentCurrency", 	Object.DocumentCurrency);
		StructureData.Insert("AmountIncludesVAT", 	Object.AmountIncludesVAT);
		
		StructureData.Insert("MeasurementUnit", 	TabularSectionRow.MeasurementUnit);
		StructureData.Insert("Price", 				TabularSectionRow.Price);
		
	EndIf;
	
	StructureData = GetDataCharacteristicOnChange(StructureData);
	
	TabularSectionRow.Specification = StructureData.Specification;
	
	If StructureData.Property("Price") Then
		TabularSectionRow.Price = StructureData.Price;
		CalculateAmountInTabularSectionLine();
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
	
	CalculateAmountInTabularSectionLine();
	
EndProcedure

// Procedure - event handler OnChange of the Price input field.
//
&AtClient
Procedure InventoryPriceOnChange(Item)
	
	CalculateAmountInTabularSectionLine();
	
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
	
EndProcedure

#EndRegion

#Region FormTableItemsEventsHandlersDisposals

&AtClient
Procedure DisposalsOnStartEdit(Item, NewRow, Clone)
	
	If Not NewRow Or Clone Then
		Return;	
	EndIf;
	
	Item.CurrentData.GLAccounts = GLAccountsInDocumentsClientServer.GetEmptyGLAccountPresentation();

EndProcedure

&AtClient
Procedure DisposalsSelection(Item, SelectedRow, Field, StandardProcessing)
	
	If Field.Name = "DisposalsGLAccounts" Then
		StandardProcessing = False;
		OpenProductGLAccountsForm(SelectedRow, "Disposals");
	EndIf;
	
EndProcedure

&AtClient
Procedure DisposalsOnActivateCell(Item)
	
	CurrentData = Items.Disposals.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If ThisIsNewRow Then
		TableCurrentColumn = Items.Disposals.CurrentItem;
		If TableCurrentColumn.Name = "DisposalsGLAccounts"
			And Not CurrentData.GLAccountsFilled Then
			SelectedRow = Items.Disposals.CurrentRow;
			OpenProductGLAccountsForm(SelectedRow, "Disposals");
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure DisposalsOnEditEnd(Item, NewRow, CancelEdit)
	ThisIsNewRow = False;
EndProcedure

&AtClient
Procedure DisposalsGLAccountsStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	SelectedRow = Items.Disposals.CurrentRow;
	OpenProductGLAccountsForm(SelectedRow, "Disposals");
	
EndProcedure

// Procedure - event handler OnChange of the Products input field.
//
&AtClient
Procedure DisposalsProductsOnChange(Item)
	
	TabularSectionRow = Items.Disposals.CurrentData;
	
	StructureData = New Structure();
	StructureData.Insert("Products", TabularSectionRow.Products);
	StructureData.Insert("TabName", "Disposals");
	StructureData.Insert("ObjectParameters", GetObjectParameters(Object));
	
	AddGLAccountsToStructure(StructureData, TabularSectionRow);	
	StructureData = GetDataProductsOnChange(StructureData);
	
	FillPropertyValues(TabularSectionRow, StructureData); 
	TabularSectionRow.MeasurementUnit = StructureData.MeasurementUnit;
	TabularSectionRow.Quantity = 1;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

// Procedure is called by clicking the PricesCurrency button of the command bar tabular field.
//
&AtClient
Procedure EditPricesAndCurrency(Item, StandardProcessing)
	
	StandardProcessing = False;
	ProcessChangesOnButtonPricesAndCurrencies(Object.DocumentCurrency);
	Modified = True;
	
EndProcedure

// You can call the procedure by clicking
// the button "FillByBasis" of the tabular field command panel.
//
&AtClient
Procedure FillByBasis(Command)
	
	Response = Undefined;

	
	ShowQueryBox(New NotifyDescription("FillByBasisEnd", ThisObject), NStr("en = 'Do you want to refill the subcontractor report?'"), QuestionDialogMode.YesNo, 0);
	
EndProcedure

&AtClient
Procedure FillByBasisEnd(Result, AdditionalParameters) Export
    
    Response = Result;
    If Response = DialogReturnCode.Yes Then
        FillByDocument(Object.BasisDocument);
        
        LabelStructure = New Structure("PriceKind, DocumentCurrency, SettlementsCurrency, ExchangeRate, RateNationalCurrency, AmountIncludesVAT, ForeignExchangeAccounting, VATTaxation", Object.PriceKind, Object.DocumentCurrency, SettlementsCurrency, Object.ExchangeRate, RateNationalCurrency, Object.AmountIncludesVAT, ForeignExchangeAccounting, Object.VATTaxation);
        PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
        
    EndIf;

EndProcedure

// Procedure - command handler of the tabular section command panel.
//
&AtClient
Procedure CommandFillBySpecification(Command)
	
	If Object.Inventory.Count() <> 0 Then
		
		Response = Undefined;

		
		ShowQueryBox(New NotifyDescription("CommandToFillBySpecificationEnd", ThisObject), NStr("en = 'The ""Inventory"" tabular section will be filled in again. Continue?'"), 
							QuestionDialogMode.YesNo, 0);
        Return;
		
	EndIf;
	
	CommandToFillBySpecificationFragment();
EndProcedure

&AtClient
Procedure CommandToFillBySpecificationEnd(Result, AdditionalParameters) Export
    
    Response = Result;
    
    If Response = DialogReturnCode.No Then
        Return;
    EndIf;
    
    
    CommandToFillBySpecificationFragment();

EndProcedure

&AtClient
Procedure CommandToFillBySpecificationFragment()
    
    FillByBillsOfMaterialsAtServer();

EndProcedure

// Procedure - command handler of the tabular section command panel.
//
&AtClient
Procedure EditPrepaymentOffset(Command)
	
	If Not ValueIsFilled(Object.Counterparty) Then
		ShowMessageBox(, NStr("en = 'Please select a counterparty.'"));
		Return;
	EndIf;
	
	If Not ValueIsFilled(Object.Contract) Then
		ShowMessageBox(, NStr("en = 'Please select a contract.'"));
		Return;
	EndIf;
	
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
		False, // IsOrder
		True, // OrderInHeader
		Company, // Company
		?(CounterpartyDoSettlementsByOrders, Object.BasisDocument, Undefined), // Order
		Object.Date, // Date
		Object.Ref, // Ref
		Object.Counterparty, // Counterparty
		Object.Contract, // Contract
		Object.ExchangeRate, // ExchangeRate
		Object.Multiplicity, // Multiplicity
		Object.DocumentCurrency, // DocumentCurrency
		Object.Total
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

#EndRegion

#Region InteractiveActionResultHandlers

// Performs the actions after a response to the question about prepayment clearing.
//
&AtClient
Procedure DefineAdvancePaymentOffsetsRefreshNeed(ClosingResult, AdditionalParameters) Export
	
	If ClosingResult = DialogReturnCode.Yes Then
		
		Object.Prepayment.Clear();
		ProcessPricesKindAndSettlementsCurrencyChange(AdditionalParameters);
		
	Else
		
		Object.Contract = AdditionalParameters.ContractBeforeChange;
		Contract = AdditionalParameters.ContractBeforeChange;
		Object.BasisDocument = Order;
		
		If AdditionalParameters.Property("CounterpartyChange") Then
			
			Object.Counterparty = AdditionalParameters.CounterpartyBeforeChange;
			Counterparty = AdditionalParameters.CounterpartyBeforeChange;
			CounterpartyDoSettlementsByOrders = AdditionalParameters.CounterpartyDoSettlementsByOrdersBeforeChange;
			Items.Contract.Visible = AdditionalParameters.ContractVisibleBeforeChange;
			
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

Function SerialNumberPickParametersInInputField()
	
	Return WorkWithSerialNumbers.SerialNumberPickParametersInInputField(Object, ThisObject.UUID, False);
	
EndFunction

Function GetSerialNumbersFromStorage(AddressInTemporaryStorage, RowKey)
	
	Return WorkWithSerialNumbers.GetSerialNumbersFromStorageForInputField(Object, AddressInTemporaryStorage);
	
EndFunction

#Region Initialize

ThisIsNewRow = False;

#EndRegion