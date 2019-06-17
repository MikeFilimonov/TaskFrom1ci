#Region Variables

&AtClient
Var UpdateSubordinatedInvoice;

#EndRegion

#Region GeneralPurposeProceduresAndFunctions

// Procedure fills in Inventory by specification.
//
&AtServer
Procedure FillByBillsOfMaterialsAtServer()
	
	Document = FormAttributeToValue("Object");
	NodesBillsOfMaterialstack = New Array;
	Document.FillTabularSectionBySpecification(NodesBillsOfMaterialstack);
	ValueToFormAttribute(Document, "Object");
	
EndProcedure

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
	DiscountKindChanged = DocumentParameters.DiscountKindChanged;
	RecalculationRequiredByProducts = DocumentParameters.RecalculationRequiredByProducts;
	RecalculationRequiredByInventory = DocumentParameters.RecalculationRequiredByInventory;
	
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
	
	If DiscountKindChanged Then
		
		Object.DiscountMarkupKind = ContractData.DiscountMarkupKind;
		
	EndIf;
	
	LabelStructure =
		New Structure("DocumentCurrency, SettlementsCurrency, ExchangeRate, RateNationalCurrency, AmountIncludesVAT, ForeignExchangeAccounting, PriceKind, DiscountKind, VATTaxation", 
			Object.DocumentCurrency, 
			SettlementsCurrency, 
			Object.ExchangeRate, 
			RateNationalCurrency, 
			Object.AmountIncludesVAT, 
			ForeignExchangeAccounting, 
			Object.PriceKind, 
			Object.DiscountMarkupKind, 
			Object.VATTaxation);
			
	PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
	
	Object.DocumentCurrency = ContractData.SettlementsCurrency;
	
	If OpenFormPricesAndCurrencies Then
		
		WarningText = "";
		If QueryPriceKind
			AND (RecalculationRequiredByProducts OR RecalculationRequiredByInventory) Then
			
			WarningText = NStr("en = 'The price and discount conditions in the contract with counterparty differ from price and discount in the document. 
			                   |Perhaps you have to refill prices.'") + Chars.LF + Chars.LF;
			
		EndIf;
		
		WarningText = WarningText + NStr("en = 'Settlement currency of the contract with counterparty changed. 
		                                 |It is necessary to check the document currency.'");
		
		ProcessChangesOnButtonPricesAndCurrencies(SettlementsCurrencyBeforeChange, True, (PriceKindChanged OR DiscountKindChanged), WarningText);
		
	ElsIf QueryPriceKind Then
		
		If RecalculationRequiredByProducts
			OR RecalculationRequiredByInventory Then
			
			QuestionText = NStr("en = 'The price and discount conditions in the contract with counterparty differ from price and discount in the document. 
			                    |Recalculate the document according to the contract?'");
			
			AdditionalParameters = New Structure;
			AdditionalParameters.Insert("RecalculationRequiredByProducts", RecalculationRequiredByProducts);
			AdditionalParameters.Insert("RecalculationRequiredByInventory", RecalculationRequiredByInventory);
			
			NotifyDescription = New NotifyDescription("DefineDocumentRecalculateNeedByContractTerms", ThisObject, AdditionalParameters);
			ShowQueryBox(NotifyDescription, QuestionText, QuestionDialogMode.YesNo);
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
// It receives data set from server for the DateOnChange procedure.
//
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

&AtServer
// Gets data set from server.
//
Function GetCompanyDataOnChange()
	
	StructureData = New Structure();
	StructureData.Insert("Company", DriveServer.GetCompany(Object.Company));
	
	ResponsiblePersons = DriveServer.OrganizationalUnitsResponsiblePersons(Object.Company, Object.Date);
	
	StructureData.Insert("ChiefAccountant",		ResponsiblePersons.ChiefAccountant);
	StructureData.Insert("Released",			ResponsiblePersons.WarehouseSupervisor);
	StructureData.Insert("ReleasedPosition",	ResponsiblePersons.WarehouseSupervisorPositionRef);
	
	FillVATRateByCompanyVATTaxation();
	
	Return StructureData;
	
EndFunction

&AtServer
// Procedure fills VAT Rate in tabular section
// by company taxation system.
// 
Procedure FillVATRateByCompanyVATTaxation()
	
	TaxationBeforeChange = Object.VATTaxation;
	Object.VATTaxation = DriveServer.VATTaxation(Object.Company, Object.Date);
	
	If Not TaxationBeforeChange = Object.VATTaxation Then
		FillVATRateByVATTaxation();
	EndIf;
	
EndProcedure

&AtServer
// Procedure fills the VAT rate in the tabular section according to the taxation system.
// 
Procedure FillVATRateByVATTaxation()
	
	If Object.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then
		
		Items.ProductsVATRate.Visible	= True;
		Items.ProductsVATAmount.Visible	= True;
		Items.ProductsTotal.Visible		= True;
		
		Items.PaymentVATAmount.Visible = True;
		Items.PaymentCalendarPayVATAmount.Visible = True;
		Items.ProductsTotalVATAmount.Visible = True;
		
		For Each TabularSectionRow In Object.Products Do
			
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
		
		Items.ProductsVATRate.Visible	= False;
		Items.ProductsVATAmount.Visible	= False;
		Items.ProductsTotal.Visible		= False;
		
		Items.PaymentVATAmount.Visible = False;
		Items.PaymentCalendarPayVATAmount.Visible = False;
		Items.ProductsTotalVATAmount.Visible = False;
		
		If Object.VATTaxation = Enums.VATTaxationTypes.NotSubjectToVAT Then	
		    DefaultVATRate = Catalogs.VATRates.Exempt;
		Else
			DefaultVATRate = Catalogs.VATRates.ZeroRate;
		EndIf;	
		
		For Each TabularSectionRow In Object.Products Do
		
			TabularSectionRow.VATRate = DefaultVATRate;
			TabularSectionRow.VATAmount = 0;
			
			TabularSectionRow.Total = TabularSectionRow.Amount;
			
		EndDo;	
		
	EndIf;	
	
EndProcedure

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
	
	If StructureData.Property("Characteristic") Then
		StructureData.Insert("Specification", DriveServer.GetDefaultSpecification(StructureData.Products, StructureData.Characteristic));
	Else
		StructureData.Insert("Specification", DriveServer.GetDefaultSpecification(StructureData.Products));
	EndIf;
	
	Return StructureData;
	
EndFunction

&AtServerNoContext
// It receives data set from server for the CharacteristicOnChange procedure.
//
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
	
	StructureData.Insert("Specification", DriveServer.GetDefaultSpecification(StructureData.Products, StructureData.Characteristic));
	
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
Procedure CalculateAmountInTabularSectionLine(TabularSectionName = "Inventory", TabularSectionRow = Undefined)
	
	If TabularSectionRow = Undefined Then
		TabularSectionRow = Items[TabularSectionName].CurrentData;
	EndIf;
	
	TabularSectionRow.Amount = TabularSectionRow.Quantity * TabularSectionRow.Price;
	
	If TabularSectionRow.Property("DiscountMarkupPercent") Then
		
		If TabularSectionRow.DiscountMarkupPercent = 100 Then
			TabularSectionRow.Amount = 0;
		ElsIf TabularSectionRow.DiscountMarkupPercent <> 0
		    AND TabularSectionRow.Quantity <> 0 Then
			TabularSectionRow.Amount = TabularSectionRow.Amount * (1 - TabularSectionRow.DiscountMarkupPercent / 100);
		EndIf;
		
	EndIf;
	
	CalculateVATSUM(TabularSectionRow);
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
	// AutomaticDiscounts.
	If TabularSectionName = "Products" Then
		AutomaticDiscountsRecalculationIsRequired = ClearCheckboxDiscountsAreCalculatedClient("CalculateAmountInTabularSectionLine");
		RecalculateSubtotal();
		TabularSectionRow.AutomaticDiscountsPercent = 0;
		TabularSectionRow.AutomaticDiscountAmount = 0;
		TabularSectionRow.TotalDiscountAmountIsMoreThanAmount = False;
	EndIf;
	// End AutomaticDiscounts

	// Serial numbers
	If UseSerialNumbersBalance <> Undefined AND TabularSectionRow.Property("SerialNumbers") Then
		WorkWithSerialNumbersClientServer.UpdateSerialNumbersQuantity(Object, TabularSectionRow);
	EndIf;
	
EndProcedure

&AtClient
// Recalculates the exchange rate and exchange rate multiplicity of
// the payment currency when the document date is changed.
//
Procedure RecalculateExchangeRateMultiplicitySettlementCurrency(StructureData)
	
	NewExchangeRate	= ?(StructureData.CurrencyRateRepetition.ExchangeRate = 0, 1, StructureData.CurrencyRateRepetition.ExchangeRate);
	NewRatio		= ?(StructureData.CurrencyRateRepetition.Multiplicity = 0, 1, StructureData.CurrencyRateRepetition.Multiplicity);
	
	If Object.ExchangeRate <> NewExchangeRate
		OR Object.Multiplicity <> NewRatio Then
		
		CurrencyRateInLetters		= String(Object.Multiplicity) + " " + TrimAll(SettlementsCurrency) + " = " + String(Object.ExchangeRate) + " " + TrimAll(FunctionalCurrency);
		RateNewCurrenciesInLetters	= String(NewRatio) + " " + TrimAll(SettlementsCurrency) + " = " + String(NewExchangeRate) + " " + TrimAll(FunctionalCurrency);
		
		QuestionText = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'As of the date of document the contract currency (%1) exchange rate was specified.
			     |Set the contract exchange rate (%2) according to exchange rate?'"),
			CurrencyRateInLetters,
			RateNewCurrenciesInLetters);
										
		AdditionalParameters = New Structure;
		AdditionalParameters.Insert("NewExchangeRate",	NewExchangeRate);
		AdditionalParameters.Insert("NewRatio",			NewRatio);
		
		NotifyDescription = New NotifyDescription("DefineNewExchangeRatesettingNeed", ThisObject, AdditionalParameters);
		ShowQueryBox(NotifyDescription, QuestionText, QuestionDialogMode.YesNo);
		
	EndIf;
	
EndProcedure

&AtClient
// Procedure executes recalculate in the document tabular section
// after changes in "Prices and currency" form.Column recalculation is executed:
// price, discount, amount, VAT amount, total.
//
Procedure ProcessChangesOnButtonPricesAndCurrencies(Val SettlementsCurrencyBeforeChange, RecalculatePrices = False, RefillPrices = False, WarningText = "")
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("DocumentCurrency",	Object.DocumentCurrency);
	ParametersStructure.Insert("ExchangeRate",		Object.ExchangeRate);
	ParametersStructure.Insert("Multiplicity",		Object.Multiplicity);
	ParametersStructure.Insert("VATTaxation",		Object.VATTaxation);
	ParametersStructure.Insert("AmountIncludesVAT",	Object.AmountIncludesVAT);
	ParametersStructure.Insert("IncludeVATInPrice",	Object.IncludeVATInPrice);
	ParametersStructure.Insert("Counterparty",		Object.Counterparty);
	ParametersStructure.Insert("Contract",			Object.Contract);
	ParametersStructure.Insert("Company",			ParentCompany);
	ParametersStructure.Insert("DocumentDate",		Object.Date);
	ParametersStructure.Insert("RefillPrices",		RefillPrices);
	ParametersStructure.Insert("RecalculatePrices",	RecalculatePrices);
	ParametersStructure.Insert("WereMadeChanges",	False);
	ParametersStructure.Insert("PriceKind",			Object.PriceKind);
	ParametersStructure.Insert("DiscountKind",		Object.DiscountMarkupKind);
	ParametersStructure.Insert("WarningText", 		WarningText);
	ParametersStructure.Insert("ReverseChargeNotApplicable", True);
	
	NotifyDescription = New NotifyDescription("OpenPricesAndCurrencyFormEnd", ThisObject, New Structure("SettlementsCurrencyBeforeChange", SettlementsCurrencyBeforeChange));
	OpenForm("CommonForm.PricesAndCurrency", ParametersStructure, ThisForm, , , , NotifyDescription, FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtServer
// Function places the list of advances into temporary storage and returns the address
//
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

&AtServer
// Function gets the list of advances from the temporary storage
//
Procedure GetPrepaymentFromStorage(AddressPrepaymentInStorage)
	
	TableForImport = GetFromTempStorage(AddressPrepaymentInStorage);
	Object.Prepayment.Load(TableForImport);
	
EndProcedure

&AtServer
// It receives data set from the server for the CounterpartyOnChange procedure.
//
Function GetDataCounterpartyOnChange(Date, DocumentCurrency, Counterparty, Company)
	
	ContractByDefault = GetContractByDefault(Object.Ref, Counterparty, Company);
	
	StructureData = New Structure();
	
	StructureData.Insert(
		"Contract",
		ContractByDefault);
		
	StructureData.Insert(
		"SettlementsCurrency",
		ContractByDefault.SettlementsCurrency);
	
	StructureData.Insert(
		"SettlementsCurrencyRateRepetition",
		InformationRegisters.ExchangeRates.GetLast(Date, New Structure("Currency", ContractByDefault.SettlementsCurrency)));
	
	StructureData.Insert(
		"SettlementsInStandardUnits",
		ContractByDefault.SettlementsInStandardUnits);
	
	StructureData.Insert(
		"DiscountMarkupKind",
		ContractByDefault.DiscountMarkupKind);
	
	StructureData.Insert(
		"PriceKind",
		ContractByDefault.PriceKind);
	
	StructureData.Insert(
		"AmountIncludesVAT",
		?(ValueIsFilled(ContractByDefault.PriceKind), ContractByDefault.PriceKind.PriceIncludesVAT, Undefined));
	
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
		"DiscountMarkupKind",
		Contract.DiscountMarkupKind
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
		
		If BarcodeData.Count() <> 0 Then
			
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
	StructureData.Insert("BarcodesArray",		BarcodesArray);
	StructureData.Insert("Company",				Object.Company);
	StructureData.Insert("PriceKind",			Object.PriceKind);
	StructureData.Insert("Date", 				Object.Date);
	StructureData.Insert("DocumentCurrency",	Object.DocumentCurrency);
	StructureData.Insert("AmountIncludesVAT",	Object.AmountIncludesVAT);
	StructureData.Insert("VATTaxation",			Object.VATTaxation);
	GetDataByBarCodes(StructureData);
	
	For Each CurBarcode In StructureData.BarcodesArray Do
		BarcodeData = StructureData.DataByBarCodes[CurBarcode.Barcode];
		
		If BarcodeData <> Undefined
		   AND BarcodeData.Count() = 0 Then
			UnknownBarcodes.Add(CurBarcode);
		Else
			TSRowsArray = Object.Inventory.FindRows(New Structure("Products,Characteristic,Batch",BarcodeData.Products,BarcodeData.Characteristic,BarcodeData.Batch));
			If TSRowsArray.Count() = 0 Then
				NewRow = Object.Inventory.Add();
				NewRow.Products = BarcodeData.Products;
				NewRow.Characteristic = BarcodeData.Characteristic;
				NewRow.Batch = BarcodeData.Batch;
				NewRow.Quantity = CurBarcode.Quantity;
				NewRow.MeasurementUnit = BarcodeData.StructureProductsData.MeasurementUnit;
				NewRow.Price = BarcodeData.StructureProductsData.Price;
				NewRow.VATRate = BarcodeData.StructureProductsData.VATRate;
				CalculateAmountInTabularSectionLine("Inventory", NewRow);
				Items.Inventory.CurrentRow = NewRow.GetID();
			Else
				NewRow = TSRowsArray[0];
				NewRow.Quantity = NewRow.Quantity + CurBarcode.Quantity;
				CalculateAmountInTabularSectionLine("Inventory", NewRow);
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

// The procedure fills in column Reserve by reserves for the order.
//
&AtServer
Procedure FillColumnReserveByReservesAtServer()
	
	Document = FormAttributeToValue("Object");
	Document.FillColumnReserveByReserves();
	ValueToFormAttribute(Document, "Object");
	
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
			
			DocumentParameters.Insert("CounterpartyBeforeChange", ContractData.CounterpartyBeforeChange);
			DocumentParameters.Insert("CounterpartyDoSettlementsByOrdersBeforeChange", ContractData.CounterpartyDoSettlementsByOrdersBeforeChange);
			DocumentParameters.Insert("ContractVisibleBeforeChange", Items.Contract.Visible);
			
		EndIf;
		
		QueryBoxPrepayment = (Object.Prepayment.Count() > 0 AND Object.Contract <> ContractBeforeChange);
		
		PriceKindChanged = Object.PriceKind <> ContractData.PriceKind AND ValueIsFilled(ContractData.PriceKind);
		DiscountKindChanged = Object.DiscountMarkupKind <> ContractData.DiscountMarkupKind AND ValueIsFilled(ContractData.DiscountMarkupKind);
		QueryPriceKind = (ValueIsFilled(Object.Contract) AND (PriceKindChanged OR DiscountKindChanged));
		
		SettlementsCurrencyBeforeChange = SettlementsCurrency;
		SettlementsCurrency = ContractData.SettlementsCurrency;
		
		RecalculationRequiredByProducts = (Object.Products.Count() > 0);
		RecalculationRequiredByInventory = (Object.Inventory.Count() > 0);
		
		NewContractAndCalculationCurrency = ValueIsFilled(Object.Contract) AND ValueIsFilled(SettlementsCurrency) 
			AND Object.Contract <> ContractBeforeChange AND SettlementsCurrencyBeforeChange <> ContractData.SettlementsCurrency;
		OpenFormPricesAndCurrencies = NewContractAndCalculationCurrency AND Object.DocumentCurrency <> ContractData.SettlementsCurrency
			AND (Object.Products.Count() > 0 OR Object.Inventory.Count() > 0);
		
		DocumentParameters.Insert("ContractBeforeChange", ContractBeforeChange);
		DocumentParameters.Insert("SettlementsCurrencyBeforeChange", SettlementsCurrencyBeforeChange);
		DocumentParameters.Insert("ContractData", ContractData);
		DocumentParameters.Insert("QueryPriceKind", QueryPriceKind);
		DocumentParameters.Insert("PriceKindChanged", PriceKindChanged);
		DocumentParameters.Insert("DiscountKindChanged", DiscountKindChanged);
		DocumentParameters.Insert("OpenFormPricesAndCurrencies", OpenFormPricesAndCurrencies);
		DocumentParameters.Insert("RecalculationRequiredByProducts", RecalculationRequiredByProducts);
		DocumentParameters.Insert("RecalculationRequiredByInventory", RecalculationRequiredByInventory);
		
		If QueryBoxPrepayment = True Then
			
			QuestionText = NStr("en = 'Prepayment setoff will be cleared, continue?'");
			
			NotifyDescription = New NotifyDescription("DefineAdvancePaymentOffsetsRefreshNeed", ThisObject, DocumentParameters);
			ShowQueryBox(NotifyDescription, QuestionText, QuestionDialogMode.YesNo);
			
		Else
			
			ProcessPricesKindAndSettlementsCurrencyChange(DocumentParameters);
			
		EndIf;
		
		FillPaymentCalendarFromContract(SwitchTypeListOfPaymentCalendar);
		UpdatePaymentCalendar();
		
	Else
		
		Object.SalesOrder = Order;
		
	EndIf;
	
	Order = Object.SalesOrder;
	
EndProcedure

&AtClient
Procedure RecalculateSubtotal()
	
	DocumentDiscount = 0;
	For Each ProductLine In Object.Products Do
		DocumentDiscount = DocumentDiscount +
							ProductLine.Price * ProductLine.Quantity * ProductLine.DiscountMarkupPercent / 100 +
							ProductLine.AutomaticDiscountAmount;
	EndDo;
					
	DocumentSubtotal = Object.Products.Total("Total") - Object.Products.Total("VATAmount") + DocumentDiscount;
	
EndProcedure

#Region ProceduresAndFunctionsForControlOfTheFormAppearance

#Region WorkWithSelection

&AtClient
// Procedure - event handler Action of the Pick command
//
Procedure ProductsPick(Command)
	
	TabularSectionName	= "Products";
	SelectionMarker		= "Products";
	DocumentPresentaion	= NStr("en = 'subcontractor report issued'");
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

&AtClient
// Procedure - event handler Action of the Pick command
//
Procedure MaterialsPick(Command)
	
	TabularSectionName	= "Inventory";
	SelectionMarker		= "Inventory";
	DocumentPresentaion	= NStr("en = 'subcontractor report issued'");
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

&AtClient
// Procedure - event handler Action of the Pick command
//
Procedure DisposalsPick(Command)
	
	TabularSectionName	= "Disposals";
	SelectionMarker		= "Disposals";
	DocumentPresentaion	= NStr("en = 'subcontractor report issued'");
	SelectionParameters	= DriveClient.GetSelectionParameters(ThisObject, TabularSectionName, DocumentPresentaion, True, False, True);
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
			CalculateAmountInTabularSectionLine("Inventory", TabularSectionRow);
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

&AtServer
// Function gets a product list from the temporary storage
//
Procedure GetInventoryFromStorage(InventoryAddressInStorage, TabularSectionName, AreCharacteristics, AreBatches)
	
	TableForImport = GetFromTempStorage(InventoryAddressInStorage);
	
	For Each ImportRow In TableForImport Do
		
		NewRow = Object[TabularSectionName].Add();
		FillPropertyValues(NewRow, ImportRow);
		
	EndDo;
	
	// AutomaticDiscounts
	If TableForImport.Count() > 0 Then
		ResetFlagDiscountsAreCalculatedServer("PickDataProcessor");
	EndIf;
	
EndProcedure

// Procedure of processing the results of selection closing
//
&AtClient
Procedure OnCloseSelection(ClosingResult, AdditionalParameters) Export
	
	If TypeOf(ClosingResult) = Type("Structure") Then
		
		If Not IsBlankString(ClosingResult.CartAddressInStorage) Then
			
			InventoryAddressInStorage	= ClosingResult.CartAddressInStorage;
			TabularSectionName			= SelectionMarker;
			
			GetInventoryFromStorage(InventoryAddressInStorage, TabularSectionName, True, True);
			SelectionMarker = "";
			RecalculateSubtotal();
			
		EndIf;
		
	EndIf;
	
EndProcedure
#EndRegion

#Region FormEventHandlers

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
	
	// Form attributes setting.
	DocumentDate = Object.Date;
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentDate();
	EndIf;
	
	ParentCompany = DriveServer.GetCompany(Object.Company);
	Counterparty = Object.Counterparty;
	Contract = Object.Contract;
	Order = Object.SalesOrder;
	SettlementsCurrency = Object.Contract.SettlementsCurrency;
	FunctionalCurrency = Constants.FunctionalCurrency.Get();
	StructureByCurrency = InformationRegisters.ExchangeRates.GetLast(Object.Date, New Structure("Currency", FunctionalCurrency));
	RateNationalCurrency = StructureByCurrency.ExchangeRate;
	RepetitionNationalCurrency = StructureByCurrency.Multiplicity;
	
	If Not ValueIsFilled(Object.Ref)
	   AND Not ValueIsFilled(Parameters.Basis)
	   AND Not ValueIsFilled(Parameters.CopyingValue) Then
		FillVATRateByCompanyVATTaxation();
	ElsIf Object.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then
		Items.ProductsVATRate.Visible = True;
		Items.ProductsVATAmount.Visible = True;
		Items.ProductsTotal.Visible = True;
		Items.ProductsTotalVATAmount.Visible = True;
		Items.PaymentVATAmount.Visible = True;
		Items.PaymentCalendarPayVATAmount.Visible = True;
	Else
		Items.ProductsVATRate.Visible = False;
		Items.ProductsVATAmount.Visible = False;
		Items.ProductsTotal.Visible = False;
		Items.ProductsTotalVATAmount.Visible = False;
		Items.PaymentVATAmount.Visible = False;
		Items.PaymentCalendarPayVATAmount.Visible = False;
	EndIf;
	
	// Generate price and currency label.
	ForeignExchangeAccounting = Constants.ForeignExchangeAccounting.Get();
	LabelStructure = New Structure("PriceKind, DiscountKind, DocumentCurrency, SettlementsCurrency, ExchangeRate, RateNationalCurrency, AmountIncludesVAT, ForeignExchangeAccounting, VATTaxation", Object.PriceKind, Object.DiscountMarkupKind, Object.DocumentCurrency, SettlementsCurrency, Object.ExchangeRate, RateNationalCurrency, Object.AmountIncludesVAT, ForeignExchangeAccounting, Object.VATTaxation);
	PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
	
	// Filling in responsible persons for new documents
	If Not ValueIsFilled(Object.Ref) Then
		
		ResponsiblePersons		= DriveServer.OrganizationalUnitsResponsiblePersons(Object.Company, Object.Date);
		
		Object.ChiefAccountant 	= ResponsiblePersons.ChiefAccountant;
		Object.Released			= ResponsiblePersons.WarehouseSupervisor;
		Object.ReleasedPosition	= ResponsiblePersons.WarehouseSupervisorPositionRef;
		
	EndIf;
	
	// Setting contract visible.
	SetContractVisible();
	
	// AutomaticDiscounts.
	AutomaticDiscountsOnCreateAtServer();
	
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
	
	SwitchTypeListOfPaymentCalendar = ?(Object.PaymentCalendar.Count() > 1, 1, 0);
	
EndProcedure

// Procedure - OnReadAtServer event handler.
//
&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	ClosingDates.ObjectOnReadAtServer(ThisForm, CurrentObject);
	
	SetSwitchTypeListOfPaymentCalendar();
	
EndProcedure

// Procedure - event handler OnOpen.
//
&AtClient
Procedure OnOpen(Cancel)
	
	SetVisibleAndEnabled();
	
	// Peripherals
	EquipmentManagerClientOverridable.StartConnectingEquipmentOnFormOpen(ThisForm, "BarCodeScanner");
	// End Peripherals
	
	SetVisibleCashAssetsTypes();
	SetEnableGroupPaymentCalendarDetails();
	
	RecalculateSubtotal();
	
EndProcedure

// Procedure - event handler OnClose.
//
&AtClient
Procedure OnClose(Exit)
	
	// AutomaticDiscounts
	// Display message about discount calculation if you click the "Post and close" or form closes by the cross with change saving.
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

&AtClient
// Procedure - event handler of the form BeforeWrite
//
Procedure BeforeWrite(Cancel, WriteParameters)
	
	UpdateSubordinatedInvoice = Modified;
	
	// AutomaticDiscounts
	DiscountsCalculatedBeforeWrite = False;
	// If the document is being posted, we check whether the discounts are calculated.
	If UseAutomaticDiscounts Then
		If Not Object.DiscountsAreCalculated AND DiscountsChanged() Then
			CalculateDiscountsMarkupsClient();
			RecalculateSubtotal();
			CalculatedDiscounts = True;
			
			Message = New UserMessage;
			Message.Text = Nstr("en = 'The automatic discounts are applied.'");
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

// Procedure - event handler BeforeWriteAtServer form.
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
// Procedure - event handler AfterWriting.
//
Procedure AfterWrite(WriteParameters)
	
	Notify("NotificationAboutChangingDebt");
	
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
			CalculateAmountInTabularSectionLine("Products");
			RecalculateSubtotal();
		EndIf; 
		
	EndIf;
	
EndProcedure

#EndRegion

#Region ActionsOfTheFormCommandPanels

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
		ParentCompany, // Company
		?(CounterpartyDoSettlementsByOrders, Object.SalesOrder, Undefined), // Order
		Object.Date, // Date
		Object.Ref, // Ref
		Object.Counterparty, // Counterparty
		Object.Contract, // Contract
		Object.ExchangeRate, // ExchangeRate
		Object.Multiplicity, // Multiplicity
		Object.DocumentCurrency, // DocumentCurrency
		Object.Products.Total("Total") // DocumentAmount
	);
	
	ReturnCode = Undefined;

	
	OpenForm("CommonForm.SelectAdvancesReceivedFromTheCustomer", SelectionParameters,,,,, New NotifyDescription("EditPrepaymentOffsetEnd", ThisObject, New Structure("AddressPrepaymentInStorage", AddressPrepaymentInStorage)));
	
EndProcedure

&AtClient
Procedure EditPrepaymentOffsetEnd(Result, AdditionalParameters) Export
    
    AddressPrepaymentInStorage = AdditionalParameters.AddressPrepaymentInStorage;
    
    
    ReturnCode = Result;
    
    If ReturnCode = DialogReturnCode.OK Then
        GetPrepaymentFromStorage(AddressPrepaymentInStorage);
    EndIf;

EndProcedure

// Procedure - command handler FillByReserve of the ChangeReserve submenu.
//
&AtClient
Procedure ChangeReserveFillByReserves(Command)
	
	If Object.Products.Count() = 0 Then
		Message = New UserMessage;
		Message.Text = NStr("en = 'The ""Products"" tabular section is not filled in.'");
		Message.Message();
		Return;
	EndIf;
	
	FillColumnReserveByReservesAtServer();
	
EndProcedure

// Procedure - command handler ClearReserve of the ChangeReserve submenu.
//
&AtClient
Procedure ChangeReserveClearReserve(Command)
	
	If Object.Products.Count() = 0 Then
		Message = New UserMessage;
		Message.Text = NStr("en = 'The ""Products"" tabular section is not filled in.'");
		Message.Message();
		Return;
	EndIf;
	
	For Each TabularSectionRow In Object.Products Do
		TabularSectionRow.Reserve = 0;
	EndDo;
	
EndProcedure

// Procedure - command handler of the tabular section command panel.
//
&AtClient
Procedure CommandFillBySpecification(Command)
	
	If Object.Inventory.Count() <> 0 Then
		
		Response = Undefined;
		
		
		ShowQueryBox(New NotifyDescription("CommandToFillBySpecificationEnd", ThisObject), NStr("en = 'Tabular section ""Materials"" will be filled in again. Continue?'"), 
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

#EndRegion

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
		StructureData = GetDataDateOnChange(DateBeforeChange, SettlementsCurrency);
		If StructureData.DATEDIFF <> 0 Then
			Object.Number = "";
		EndIf;
		
		If ValueIsFilled(SettlementsCurrency) Then
			RecalculateExchangeRateMultiplicitySettlementCurrency(StructureData);
		EndIf;
		
		LabelStructure = New Structure("PriceKind, DiscountKind, DocumentCurrency, SettlementsCurrency, ExchangeRate, RateNationalCurrency, AmountIncludesVAT, ForeignExchangeAccounting, VATTaxation", Object.PriceKind, Object.DiscountMarkupKind, Object.DocumentCurrency, SettlementsCurrency, Object.ExchangeRate, RateNationalCurrency, Object.AmountIncludesVAT, ForeignExchangeAccounting, Object.VATTaxation);
		PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
		
		RecalculatePaymentDate(DateBeforeChange, Object.Date);
		
	EndIf;
	
	// AutomaticDiscounts
	DocumentDateChangedManually = True;
	ClearCheckboxDiscountsAreCalculatedClient("DateOnChange");
	RecalculateSubtotal();
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of the Company input field.
// In procedure is executed document
// number clearing and also make parameter set of the form functional options.
// Overrides the corresponding form parameter.
//
Procedure CompanyOnChange(Item)
	
	// Company change event data processor.
	Object.BankAccount	= "";
	Object.Number		= "";
	StructureData		= GetCompanyDataOnChange();
	ParentCompany	= StructureData.Company;
	
	Object.ChiefAccountant	= StructureData.ChiefAccountant;
	Object.Released			= StructureData.Released;
	Object.ReleasedPosition	= StructureData.ReleasedPosition;
	
	LabelStructure = New Structure("PriceKind, DiscountKind, DocumentCurrency, 
		|SettlementsCurrency, ExchangeRate, RateNationalCurrency, 
		|AmountIncludesVAT, ForeignExchangeAccounting, VATTaxation", 
		Object.PriceKind, Object.DiscountMarkupKind, Object.DocumentCurrency, 
		SettlementsCurrency, Object.ExchangeRate, RateNationalCurrency, 
		Object.AmountIncludesVAT, ForeignExchangeAccounting, Object.VATTaxation);
		
	PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
	
	Object.Contract = GetContractByDefault(Object.Ref, Object.Counterparty, Object.Company);
	ProcessContractChange();
	
	If Object.SetPaymentTerms
		AND ValueIsFilled(Object.CashAssetsType) Then
		
		RecalculatePaymentCalendar();
		RecalculateSubtotal();
		FillPaymentScedule();
		
	EndIf;
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of the Counterparty input field.
// Clears the contract and tabular section.
//
Procedure CounterpartyOnChange(Item)
	
	CounterpartyBeforeChange = Counterparty;
	CounterpartyDoSettlementsByOrdersBeforeChange = CounterpartyDoSettlementsByOrders;
	Counterparty = Object.Counterparty;
	
	If CounterpartyBeforeChange <> Object.Counterparty Then
		
		Object.CounterpartyBankAcc = Undefined;
		Object.ShippingAddress = "";
		
		ContractData = GetDataCounterpartyOnChange(Object.Date, Object.DocumentCurrency, Object.Counterparty, Object.Company);
		Object.Contract = ContractData.Contract;
		
		FillSalesRepInProducts(ContractData.SalesRep);
		
		ContractData.Insert("CounterpartyBeforeChange", CounterpartyBeforeChange);
		ContractData.Insert("CounterpartyDoSettlementsByOrdersBeforeChange", CounterpartyDoSettlementsByOrdersBeforeChange);
		
		ProcessContractChange(ContractData);
		
	Else
		
		Object.Contract = Contract; // Restore the cleared contract automatically.
		Object.SalesOrder = Order;
		
	EndIf;
	
	Order = Object.SalesOrder;
	
	// AutomaticDiscounts
	ClearCheckboxDiscountsAreCalculatedClient("CounterpartyOnChange");
	RecalculateSubtotal();
	
EndProcedure

&AtClient
// The OnChange event handler of the Contract field.
// It updates the currency exchange rate and exchange rate multiplier.
//
Procedure ContractOnChange(Item)
	
	ProcessContractChange();
	UpdatePaymentCalendar();
	
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

// The OnChange event handler of the SalesOrder field.
// It updates the currency exchange rate and exchange rate multiplier.
//
&AtClient
Procedure OrderOnChange(Item)
	
	If Object.Prepayment.Count() > 0
	   AND Object.SalesOrder <> Order
	   AND CounterpartyDoSettlementsByOrders Then
		Mode = QuestionDialogMode.YesNo;
		Response = Undefined;

		ShowQueryBox(New NotifyDescription("OrderOnChangeEnd", ThisObject), NStr("en = 'Prepayment setoff will be cleared, continue?'"), Mode, 0);
        Return;
	EndIf;
	
	OrderOnChangeFragment();
EndProcedure

&AtClient
Procedure OrderOnChangeEnd(Result, AdditionalParameters) Export
    
    Response = Result;
    If Response = DialogReturnCode.Yes Then
        Object.Prepayment.Clear();
    Else
        Object.SalesOrder = Order;
        Return;
    EndIf;
    
    OrderOnChangeFragment();

EndProcedure

&AtClient
Procedure OrderOnChangeFragment()
    
    Order = Object.SalesOrder;

	// AutomaticDiscounts
	ClearCheckboxDiscountsAreCalculatedClient("OrderOnChangeFragment");
	// End AutomaticDiscounts
	
EndProcedure

#EndRegion

#Region EventHandlersOfTheProductsTabularSectionAttributes

&AtClient
// Procedure - event handler OnChange of the Products input field.
//
Procedure ProductsProductsOnChange(Item)
	
	TabularSectionRow = Items.Products.CurrentData;
	
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
	
	StructureData = GetDataProductsOnChange(StructureData);
	
	TabularSectionRow.MeasurementUnit = StructureData.MeasurementUnit;
	TabularSectionRow.Quantity = 1;
	TabularSectionRow.Reserve = 0;
	
	TabularSectionRow.Price = StructureData.Price;
	TabularSectionRow.DiscountMarkupPercent = StructureData.DiscountMarkupPercent;
	TabularSectionRow.VATRate = StructureData.VATRate;
	TabularSectionRow.Content = "";
	TabularSectionRow.Specification = StructureData.Specification;
	
	CalculateAmountInTabularSectionLine("Products");
	
	// Serial numbers
	WorkWithSerialNumbersClientServer.DeleteSerialNumbersByConnectionKey(Object.SerialNumbers, TabularSectionRow, , UseSerialNumbersBalance);
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of the Characteristic input field.
//
Procedure ProductsCharacteristicOnChange(Item)
	
	TabularSectionRow = Items.Products.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("Products",	 TabularSectionRow.Products);
	StructureData.Insert("Characteristic",	 TabularSectionRow.Characteristic);
	
	If ValueIsFilled(Object.PriceKind) Then
		
		StructureData.Insert("ProcessingDate",	 	Object.Date);
		StructureData.Insert("DocumentCurrency",	 	Object.DocumentCurrency);
		StructureData.Insert("PriceKind",			 	Object.PriceKind);
		StructureData.Insert("AmountIncludesVAT", 	Object.AmountIncludesVAT);
		
		StructureData.Insert("VATRate", 			TabularSectionRow.VATRate);
		StructureData.Insert("Price",			 	TabularSectionRow.Price);
		StructureData.Insert("MeasurementUnit", 	TabularSectionRow.MeasurementUnit);
		
	EndIf;
	
	StructureData = GetDataCharacteristicOnChange(StructureData);
	
	TabularSectionRow.Price = StructureData.Price;
	TabularSectionRow.Content = "";
	TabularSectionRow.Specification = StructureData.Specification;
	
	CalculateAmountInTabularSectionLine("Products");
	
EndProcedure

&AtClient
// Procedure - event handler AutoPick of the Content input field.
//
Procedure ProductsContentAutoPick(Item, Text, ChoiceData, Parameters, Wait, StandardProcessing)
	
	If Wait = 0 Then
		
		StandardProcessing = False;
		
		TabularSectionRow = Items.Products.CurrentData;
		ContentPattern = DriveServer.GetContentText(TabularSectionRow.Products, TabularSectionRow.Characteristic);
		
		ChoiceData = New ValueList;
		ChoiceData.Add(ContentPattern);
		
	EndIf;
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of the Count input field.
//
Procedure ProductsQuantityOnChange(Item)
	
	CalculateAmountInTabularSectionLine("Products");
	RecalculatePaymentCalendar();
	RecalculateSubtotal();
	
EndProcedure

&AtClient
// Procedure - event handler ChoiceProcessing of the MeasurementUnit input field.
//
Procedure ProductsMeasurementUnitChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	TabularSectionRow = Items.Products.CurrentData;
	
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
	
	CalculateAmountInTabularSectionLine("Products");
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of the Price input field.
//
Procedure ProductsPriceOnChange(Item)
	
	CalculateAmountInTabularSectionLine("Products");
	RecalculatePaymentCalendar();
	RecalculateSubtotal();
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of the Amount input field.
//
Procedure ProductsAmountOnChange(Item)
	
	TabularSectionRow = Items.Products.CurrentData;
	
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
	
	// AutomaticDiscounts.
	ClearCheckboxDiscountsAreCalculatedClient("CalculateAmountInTabularSectionLine", "Amount");
	
	TabularSectionRow.AutomaticDiscountsPercent = 0;
	TabularSectionRow.AutomaticDiscountAmount = 0;
	TabularSectionRow.TotalDiscountAmountIsMoreThanAmount = False;
	// End AutomaticDiscounts
	
	RecalculatePaymentCalendar();
	RecalculateSubtotal();
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of the VATRate input field.
//
Procedure ProductsVATRateOnChange(Item)
	
	TabularSectionRow = Items.Products.CurrentData;
	
	CalculateVATSUM(TabularSectionRow);
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
	RecalculatePaymentCalendar();
	RecalculateSubtotal();
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of the VATRate input field.
//
Procedure ProductsVATAmountOnChange(Item)
	
	TabularSectionRow = Items.Products.CurrentData;
	
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
	RecalculatePaymentCalendar();
	RecalculateSubtotal();
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of the DiscountMarkupPercent input field.
//
Procedure ProductsDiscountMarkupPercentOnChange(Item)
	
	CalculateAmountInTabularSectionLine("Products");
	
EndProcedure

#EndRegion

#Region EventHandlersOfTheInventoryTabularSectionAttributes

&AtClient
// Procedure - event handler OnChange of the Products input field.
//
Procedure InventoryProductsOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	StructureData = New Structure();
	StructureData.Insert("Company", Object.Company);
	StructureData.Insert("Products", TabularSectionRow.Products);
	
	StructureData = GetDataProductsOnChange(StructureData);
	
	TabularSectionRow.MeasurementUnit = StructureData.MeasurementUnit;
	TabularSectionRow.Quantity = 1;
	TabularSectionRow.Price = 0;
	TabularSectionRow.Amount = 0;
	TabularSectionRow.VATRate = StructureData.VATRate;
	TabularSectionRow.VATAmount = 0;
	TabularSectionRow.Total = 0;
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of the Count input field.
//
Procedure InventoryQuantityOnChange(Item)
	
	CalculateAmountInTabularSectionLine("Inventory");
	
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
	
	If StructureData.CurrentFactor <> 0 Then
		TabularSectionRow.Price = TabularSectionRow.Price * StructureData.Factor / StructureData.CurrentFactor;
	EndIf;
	
	CalculateAmountInTabularSectionLine("Inventory");
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of the Price input field.
//
Procedure InventoryPriceOnChange(Item)
	
	CalculateAmountInTabularSectionLine("Inventory");
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of the Amount input field.
//
Procedure InventoryAmountOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	If TabularSectionRow.Quantity <> 0 Then
		TabularSectionRow.Price = TabularSectionRow.Amount / TabularSectionRow.Quantity;
	EndIf;
	
	CalculateVATSUM(TabularSectionRow);
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of the VATRate input field.
//
Procedure InventoryVATRateOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	CalculateVATSUM(TabularSectionRow);
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of the VATRate input field.
//
Procedure InventoryVATAmountOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
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
Procedure PrepaymentExchangeRateOnChange(Item)
	
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

&AtClient
Procedure SchedulePaymentOnChange(Item)
	FillThePaymentCalender();
EndProcedure

&AtClient
Procedure FieldSwitchTypeListOfPaymentCalendarOnChange(Item)
	
	PaymentCalendarCount = Object.PaymentCalendar.Count();
	
	If Not SwitchTypeListOfPaymentCalendar Then
		If PaymentCalendarCount > 1 Then
			ClearMessages();
			TextMessage = NStr("en = 'You can''t change the mode of payment terms because there is more than one payment date'");
			CommonUseClientServer.MessageToUser(TextMessage);
			
			SwitchTypeListOfPaymentCalendar = 1;
		ElsIf PaymentCalendarCount = 0 Then
			NewLine = Object.PaymentCalendar.Add();
		EndIf;
	EndIf;
		
	SetVisiblePaymentCalendar();
	SetVisibleCashAssetsTypes();
	
EndProcedure

&AtClient
Procedure CashAssetsTypeOnChange(Item)
	SetVisibleCashAssetsTypes();
EndProcedure

&AtClient
Procedure PaymentCalendarPaymentPercentageOnChange(Item)
	
	CurrentRow = Items.PaymentCalendar.CurrentData;
	
	CurrentRow.PaymentAmount	= Round(Object.Products.Total("Amount") * CurrentRow.PaymentPercentage / 100, 2, 1);
	CurrentRow.PaymentVATAmount		= Round(Object.Products.Total("VATAmount") * CurrentRow.PaymentPercentage / 100, 2, 1);
	
EndProcedure

&AtClient
Procedure PaymentCalendarPaymentAmountOnChange(Item)
	
	CurrentRow = Items.PaymentCalendar.CurrentData;
	
	TotalAmount = Object.Products.Total("Amount");
	
	If TotalAmount = 0 Then
		CurrentRow.PaymentPercentage	= 0;
		CurrentRow.PaymentVATAmount			= 0;
	Else
		CurrentRow.PaymentPercentage	= Round(CurrentRow.PaymentAmount / TotalAmount * 100, 2, 1);
		CurrentRow.PaymentVATAmount			= Round(Object.Products.Total("VATAmount") * CurrentRow.PaymentAmount / TotalAmount, 2, 1);
	EndIf;
	
EndProcedure

&AtClient
Procedure PaymentCalendarPayVATAmountOnChange(Item)
	
	CurrentRow = Items.PaymentCalendar.CurrentData;
	
	PaymentCalendarTotal = Object.PaymentCalendar.Total("PaymentVATAmount");
	ProductsTotalVat = Object.Products.Total("VATAmount");
	
	If PaymentCalendarTotal > ProductsTotalVat Then
		CurrentRow.PaymentVATAmount = CurrentRow.PaymentVATAmount - (PaymentCalendarTotal - ProductsTotalVat);
	EndIf;
	
EndProcedure

&AtClient
Procedure PaymentCalendarOnStartEdit(Item, NewRow, Clone)
	
	CurrentRow = Items.PaymentCalendar.CurrentData;
	
	If CurrentRow.PaymentPercentage = 0 Then
		CurrentRow.PaymentPercentage = 100 - Object.PaymentCalendar.Total("PaymentPercentage");
		CurrentRow.PaymentAmount = Object.Products.Total("Amount") - Object.PaymentCalendar.Total("PaymentAmount");
		CurrentRow.PaymentVATAmount = Object.Products.Total("VATAmount") - Object.PaymentCalendar.Total("PaymentVATAmount");
	EndIf;
	
EndProcedure

#EndRegion

#Region EventHandlersOfTheDisposalsTabularSectionAttributes

&AtClient
// Procedure - event handler OnChange of the Products input field.
//
Procedure DisposalsProductsOnChange(Item)
	
	TabularSectionRow = Items.Disposals.CurrentData;
	
	StructureData = New Structure();
	StructureData.Insert("Company", ParentCompany);
	StructureData.Insert("Products", TabularSectionRow.Products);
	
	StructureData = GetDataProductsOnChange(StructureData);
	
	TabularSectionRow.MeasurementUnit = StructureData.MeasurementUnit;
	TabularSectionRow.Quantity = 1;
	
EndProcedure

#Region InteractiveActionResultHandlers

&AtClient
// Procedure-handler of the result of opening the "Prices and currencies" form
//
Procedure OpenPricesAndCurrencyFormEnd(ClosingResult, AdditionalParameters) Export
	
	If TypeOf(ClosingResult) = Type("Structure") 
		AND ClosingResult.WereMadeChanges Then
		
		Object.PriceKind = ClosingResult.PriceKind;
		Object.DiscountMarkupKind = ClosingResult.DiscountKind;
		Object.DocumentCurrency = ClosingResult.DocumentCurrency;
		Object.ExchangeRate = ClosingResult.PaymentsRate;
		Object.Multiplicity = ClosingResult.SettlementsMultiplicity;
		Object.VATTaxation = ClosingResult.VATTaxation;
		Object.AmountIncludesVAT = ClosingResult.AmountIncludesVAT;
		Object.IncludeVATInPrice = ClosingResult.IncludeVATInPrice;
		SettlementsCurrencyBeforeChange = AdditionalParameters.SettlementsCurrencyBeforeChange;
		
		// Recalculate prices by kind of prices.
		If ClosingResult.RefillPrices Then
			
			DriveClient.RefillTabularSectionPricesByPriceKind(ThisForm, "Products", True);
			
		EndIf;
		
		// Recalculate prices by currency.
		If Not ClosingResult.RefillPrices
			AND ClosingResult.RecalculatePrices Then
			
			DriveClient.RecalculateTabularSectionPricesByCurrency(ThisForm, SettlementsCurrencyBeforeChange, "Products");
			DriveClient.RecalculateTabularSectionPricesByCurrency(ThisForm, SettlementsCurrencyBeforeChange, "Inventory");
			
		EndIf;
		
		// Recalculate the amount if VAT taxation flag is changed.
		If ClosingResult.VATTaxation <> ClosingResult.PrevVATTaxation Then
			
			FillVATRateByVATTaxation();
			
		EndIf;
		
		// Recalculate the amount if the "Amount includes VAT" flag is changed.
		If Not ClosingResult.RefillPrices
			AND Not ClosingResult.AmountIncludesVAT = ClosingResult.PrevAmountIncludesVAT Then
			
			DriveClient.RecalculateTabularSectionAmountByFlagAmountIncludesVAT(ThisForm, "Products");
			DriveClient.RecalculateTabularSectionAmountByFlagAmountIncludesVAT(ThisForm, "Inventory");
			
		EndIf;
		
		For Each TabularSectionRow In Object.Prepayment Do
			
			TabularSectionRow.PaymentAmount = DriveClient.RecalculateFromCurrencyToCurrency(
				TabularSectionRow.SettlementsAmount,
				TabularSectionRow.ExchangeRate,
				?(Object.DocumentCurrency = FunctionalCurrency, RateNationalCurrency, Object.ExchangeRate),
				TabularSectionRow.Multiplicity,
				?(Object.DocumentCurrency = FunctionalCurrency, RepetitionNationalCurrency, Object.Multiplicity)
			);
			
		EndDo;
		
		// AutomaticDiscounts
		If ClosingResult.RefillDiscounts OR ClosingResult.RefillPrices OR ClosingResult.RecalculatePrices Then
			ClearCheckboxDiscountsAreCalculatedClient("RefillByFormDataPricesAndCurrency");
		EndIf;
		// End AutomaticDiscounts
		
		LabelStructure = New Structure("PriceKind, DiscountKind, DocumentCurrency, SettlementsCurrency, ExchangeRate, RateNationalCurrency, AmountIncludesVAT, ForeignExchangeAccounting, VATTaxation",
			Object.PriceKind,
			Object.DiscountMarkupKind,
			Object.DocumentCurrency,
			SettlementsCurrency,
			Object.ExchangeRate,
			RateNationalCurrency,
			Object.AmountIncludesVAT,
			ForeignExchangeAccounting,
			Object.VATTaxation);
			
		PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
		
		RecalculatePaymentCalendar();
		RecalculateSubtotal();
		
	EndIf;
	
EndProcedure

&AtClient
// Procedure-handler of the response to question about the necessity to set a new currency rate
//
Procedure DefineNewExchangeRatesettingNeed(ClosingResult, AdditionalParameters) Export
	
	If ClosingResult = DialogReturnCode.Yes Then
		
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
		
		LabelStructure = New Structure("PriceKind, DiscountKind, DocumentCurrency, SettlementsCurrency, ExchangeRate, RateNationalCurrency, AmountIncludesVAT, ForeignExchangeAccounting, VATTaxation",
			Object.PriceKind,
			Object.DiscountMarkupKind,
			Object.DocumentCurrency,
			SettlementsCurrency,
			Object.ExchangeRate,
			RateNationalCurrency,
			Object.AmountIncludesVAT,
			ForeignExchangeAccounting,
			Object.VATTaxation);
			
		PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
		
	EndIf;
	
EndProcedure

&AtClient
// Procedure-handler of the answer to the question about repeated advances offset
//
Procedure DefineAdvancePaymentOffsetsRefreshNeed(ClosingResult, AdditionalParameters) Export
	
	If ClosingResult = DialogReturnCode.Yes Then
		
		Object.Prepayment.Clear();
		ProcessPricesKindAndSettlementsCurrencyChange(AdditionalParameters);
		
	Else
		
		Object.Contract = AdditionalParameters.ContractBeforeChange;
		Contract = AdditionalParameters.ContractBeforeChange;
		Object.SalesOrder = Order;
		
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
		
		If AdditionalParameters.RecalculationRequiredByProducts Then
			
			DriveClient.RefillTabularSectionPricesByPriceKind(ThisForm, "Products", True);
			
		EndIf;
		
		If AdditionalParameters.RecalculationRequiredByInventory Then
			
			DriveClient.RefillTabularSectionPricesByPriceKind(ThisForm, "Inventory");
			
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

#Region AutomaticDiscounts

// Procedure - form command handler CalculateDiscountsMarkups.
//
&AtClient
Procedure CalculateDiscountsMarkups(Command)
	
	If Object.Products.Count() = 0 Then
		If Object.DiscountsMarkups.Count() > 0 Then
			Object.DiscountsMarkups.Clear();
		EndIf;
		Return;
	EndIf;
	
	CalculateDiscountsMarkupsClient();
	
EndProcedure

&AtServer
Procedure CalculateMarkupsDiscountsForOrderServer()

	DiscountsMarkupsServer.FillLinkingKeysInSpreadsheetPartProducts(Object, "Products");
	
	OrdersArray = New Array;
	OrdersArray.Add(Object.SalesOrder);
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	DiscountsMarkups.Ref AS Order,
	|	DiscountsMarkups.DiscountMarkup AS DiscountMarkup,
	|	DiscountsMarkups.Amount AS AutomaticDiscountAmount,
	|	CASE
	|		WHEN SalesOrderInventory.Products.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS ProductsTypeInventory,
	|	CASE
	|		WHEN VALUETYPE(SalesOrderInventory.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|			THEN 1
	|		ELSE SalesOrderInventory.MeasurementUnit.Factor
	|	END AS Factor,
	|	SalesOrderInventory.Products,
	|	SalesOrderInventory.Characteristic,
	|	SalesOrderInventory.MeasurementUnit,
	|	SalesOrderInventory.Quantity
	|FROM
	|	Document.SalesOrder.DiscountsMarkups AS DiscountsMarkups
	|		INNER JOIN Document.SalesOrder.Inventory AS SalesOrderInventory
	|		ON DiscountsMarkups.Ref = SalesOrderInventory.Ref
	|			AND DiscountsMarkups.ConnectionKey = SalesOrderInventory.ConnectionKey
	|WHERE
	|	DiscountsMarkups.Ref IN(&OrdersArray)";
	
	Query.SetParameter("OrdersArray", OrdersArray);
	
	ResultsArray = Query.ExecuteBatch();
	
	OrderDiscountsMarkups = ResultsArray[0].Unload();
	
	Object.DiscountsMarkups.Clear();
	For Each CurrentDocumentRow In Object.Products Do
		CurrentDocumentRow.AutomaticDiscountsPercent = 0;
		CurrentDocumentRow.AutomaticDiscountAmount = 0;
	EndDo;
	
	DiscountsMarkupsCalculationResult = Object.DiscountsMarkups.Unload();
	
	For Each CurrentOrderRow In OrderDiscountsMarkups Do
		
		StructureForSearch = New Structure;
		StructureForSearch.Insert("Products", CurrentOrderRow.Products);
		StructureForSearch.Insert("Characteristic", CurrentOrderRow.Characteristic);
		
		DocumentRowsArray = Object.Products.FindRows(StructureForSearch);
		If DocumentRowsArray.Count() = 0 Then
			Continue;
		EndIf;
		
		QuantityInOrder = CurrentOrderRow.Quantity * CurrentOrderRow.Factor;
		Distributed = 0;
		For Each CurrentDocumentRow In DocumentRowsArray Do
			QuantityToWriteOff = CurrentDocumentRow.Quantity * 
									?(TypeOf(CurrentDocumentRow.MeasurementUnit) = Type("CatalogRef.UOMClassifier"), 1, CurrentDocumentRow.MeasurementUnit.Factor);
			
			RecalculateAmounts = QuantityInOrder <> QuantityToWriteOff;
			DiscountRecalculationCoefficient = ?(RecalculateAmounts, QuantityToWriteOff / QuantityInOrder, 1);
			If DiscountRecalculationCoefficient <> 1 Then
				CurrentAutomaticDiscountAmount = ROUND(CurrentOrderRow.AutomaticDiscountAmount * DiscountRecalculationCoefficient,2);
			Else
				CurrentAutomaticDiscountAmount = CurrentOrderRow.AutomaticDiscountAmount;
			EndIf;
			
			DiscountString = DiscountsMarkupsCalculationResult.Add();
			FillPropertyValues(DiscountString, CurrentOrderRow);
			DiscountString.Amount = CurrentAutomaticDiscountAmount;
			DiscountString.ConnectionKey = CurrentDocumentRow.ConnectionKey;
			
			CurrentOrderRow.AutomaticDiscountAmount = CurrentOrderRow.AutomaticDiscountAmount - CurrentAutomaticDiscountAmount;
			QuantityInOrder = QuantityInOrder - QuantityToWriteOff;
			If QuantityInOrder <=0 Or CurrentOrderRow.AutomaticDiscountAmount <=0 Then
				Break;
			EndIf;
		EndDo;
		
	EndDo;
	
	DiscountsMarkupsServer.ApplyDiscountCalculationResultToObject(Object, "Products", DiscountsMarkupsCalculationResult);
		
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
		
		If Object.Products.Total("AutomaticDiscountAmount") <> Object.DiscountsMarkups.Total("Amount") Then
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

&AtServer
Function GetAutomaticDiscountCalculationParametersStructureServer()

	OrderParametersStructure = New Structure("ImplementationByOrders, SalesExceedingOrder", False, False);
	
	SalesOrderPosition = DriveReUse.GetValueOfSetting("SalesOrderPositionInShipmentDocuments");
	If Not ValueIsFilled(SalesOrderPosition) Then
		SalesOrderPosition = Enums.AttributeStationing.InHeader;
	EndIf;
	If SalesOrderPosition = Enums.AttributeStationing.InHeader Then
		If ValueIsFilled(Object.SalesOrder) Then
			OrderParametersStructure.ImplementationByOrders = True;
		Else
			OrderParametersStructure.ImplementationByOrders = False;
		EndIf;
		OrderParametersStructure.SalesExceedingOrder = False;
	Else // At this point the sales order can be specified only in the header.
		If ValueIsFilled(Object.SalesOrder) Then
			OrderParametersStructure.ImplementationByOrders = True;
		Else
			OrderParametersStructure.ImplementationByOrders = False;
		EndIf;
		OrderParametersStructure.SalesExceedingOrder = False;
	EndIf;
	
	Return OrderParametersStructure;
	
EndFunction

// Procedure calculates discounts by document.
//
&AtServer
Procedure CalculateDiscountsMarkupsOnServer(ParameterStructure)
	
	OrderParametersStructure = GetAutomaticDiscountCalculationParametersStructureServer(); // If there are orders in TS "Goods", then for such rows the automatic discount shall be calculated by the order.
	If OrderParametersStructure.ImplementationByOrders Then
		CalculateMarkupsDiscountsForOrderServer();
		If OrderParametersStructure.SalesExceedingOrder Then
			ParameterStructure.Insert("SalesExceedingOrder", True);
			AppliedDiscounts = DiscountsMarkupsServerOverridable.Calculate(Object, ParameterStructure);
		Else
			ParameterStructure.Insert("ApplyToObject", False);
			AppliedDiscounts = DiscountsMarkupsServerOverridable.Calculate(Object, ParameterStructure);
		EndIf;
	Else
		AppliedDiscounts = DiscountsMarkupsServerOverridable.Calculate(Object, ParameterStructure);
	EndIf;
	
	AddressDiscountsAppliedInTemporaryStorage = PutToTempStorage(AppliedDiscounts, UUID);
	
	Modified = True;
	
	DiscountsMarkupsServerOverridable.UpdateDiscountDisplay(Object, "Products");
	
	If Not Object.DiscountsAreCalculated Then
	
		Object.DiscountsAreCalculated = True;
	
	EndIf;
	
	Items.ProductsCalculateDiscountsMarkups.Picture = PictureLib.Refresh;
	
	ThereAreManualDiscounts = Constants.UseManualDiscounts.Get();
	For Each CurrentRow In Object.Products Do
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
	
	CurrentData = Items.Products.CurrentData;
	
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
	
	CurrentData = Items.Products.CurrentData;
	MarkupsDiscountsClient.OpenFormAppliedDiscounts(CurrentData, Object, ThisObject);
	
EndProcedure

// Function clears checkbox "DiscountsAreCalculated" if it is necessary and returns True if it is required to
// recalculate discounts.
//
&AtServer
Function ResetFlagDiscountsAreCalculatedServer(Action, SPColumn = "")
	
	RecalculationIsRequired = False;
	If UseAutomaticDiscounts AND Object.Products.Count() > 0 AND (Object.DiscountsAreCalculated OR InstalledGrayColor) Then
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
	If UseAutomaticDiscounts AND Object.Products.Count() > 0 AND (Object.DiscountsAreCalculated OR InstalledGrayColor) Then
		RecalculationIsRequired = ResetFlagDiscountsAreCalculated(Action, SPColumn);
	EndIf;
	Return RecalculationIsRequired;
	
EndFunction

// Function clears checkbox DiscountsAreCalculated if it is necessary and returns True if it is required to recalculate discounts.
//
&AtServer
Function ResetFlagDiscountsAreCalculated(Action, SPColumn = "")
	
	Return DiscountsMarkupsServer.ResetFlagDiscountsAreCalculated(ThisObject, Action, SPColumn, "Products");
	
EndFunction

// Procedure executes necessary actions when creating the form on server.
//
&AtServer
Procedure AutomaticDiscountsOnCreateAtServer()
	
	InstalledGrayColor = False;
	UseAutomaticDiscounts = GetFunctionalOption("UseAutomaticDiscounts");
	If UseAutomaticDiscounts Then
		If Object.Products.Count() = 0 Then
			Items.ProductsCalculateDiscountsMarkups.Picture = PictureLib.UpdateGray;
			InstalledGrayColor = True;
		ElsIf Not Object.DiscountsAreCalculated Then
			Object.DiscountsAreCalculated = False;
			Items.ProductsCalculateDiscountsMarkups.Picture = PictureLib.UpdateRed;
		Else
			Items.ProductsCalculateDiscountsMarkups.Picture = PictureLib.Refresh;
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure GoodsAfterDeleteRow(Item)
	
	// AutomaticDiscounts.
	ClearCheckboxDiscountsAreCalculatedClient("DeleteRow");
	RecalculateSubtotal();
	
EndProcedure

// Procedure - event handler Selection of the Products tabular section.
//
&AtClient
Procedure GoodsChoice(Item, SelectedRow, Field, StandardProcessing)
	
	If (Item.CurrentItem = Items.ProductsAutomaticDiscountPercent OR Item.CurrentItem = Items.ProductsAutomaticDiscountAmount)
		AND Not ReadOnly Then
		
		StandardProcessing = False;
		OpenInformationAboutDiscountsClient()
		
	EndIf;
	
EndProcedure

// Procedure - event handler OnStartEdit of the Product form tabular section.
//
&AtClient
Procedure GoodsOnStartEdit(Item, NewRow, Copy)
	
	// AutomaticDiscounts
	If NewRow AND Copy Then
		Item.CurrentData.AutomaticDiscountsPercent = 0;
		Item.CurrentData.AutomaticDiscountAmount = 0;
		CalculateAmountInTabularSectionLine("Products");
	EndIf;
	// End AutomaticDiscounts
	
	If NewRow AND Copy Then
		Item.CurrentData.ConnectionKey = 0;
		Item.CurrentData.SerialNumbers = "";
	EndIf;
	
	If Item.CurrentItem.Name = "ProductsSerialNumbers" Then
		OpenSerialNumbersSelection();
	EndIf;

EndProcedure

&AtClient
Procedure ProductsBeforeDeleteRow(Item, Cancel)
	
	// Serial numbers
	CurrentData = Items.Products.CurrentData;
	WorkWithSerialNumbersClientServer.DeleteSerialNumbersByConnectionKey(Object.SerialNumbers, CurrentData, , UseSerialNumbersBalance);
	
EndProcedure

&AtClient
Procedure ProductsSerialNumbersStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	OpenSerialNumbersSelection();
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	// AutomaticDiscounts
	If RefreshImageAutoDiscountsAfterWrite Then
		Items.ProductsCalculateDiscountsMarkups.Picture = PictureLib.Refresh;
		RefreshImageAutoDiscountsAfterWrite = False;
	EndIf;
	// End AutomaticDiscounts
	
EndProcedure

#EndRegion

#EndRegion

&AtClient
Procedure OpenSerialNumbersSelection()
	
	CurrentDataIdentifier = Items.Products.CurrentData.GetID();
	ParametersOfSerialNumbers = SerialNumberPickParameters(CurrentDataIdentifier);
	
	OpenForm("DataProcessor.SerialNumbersSelection.Form", ParametersOfSerialNumbers, ThisObject);
	
EndProcedure

&AtServer
Function GetSerialNumbersFromStorage(AddressInTemporaryStorage, RowKey)
	
	Modified = True;
	ParametersFieldNames = New Structure;
	ParametersFieldNames.Insert("NameTSInventory", "Products");
	
	Return WorkWithSerialNumbers.GetSerialNumbersFromStorage(Object, AddressInTemporaryStorage, RowKey, ParametersFieldNames);
	
EndFunction

&AtServer
Function SerialNumberPickParameters(CurrentDataIdentifier)
	
	Return WorkWithSerialNumbers.SerialNumberPickParameters(Object, ThisObject.UUID, CurrentDataIdentifier, False, "Products");
	
EndFunction

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
Procedure FillThePaymentCalender()
	
	If Object.SetPaymentTerms Then
		
		FillThePaymentCalenderOnServer();
		SetEnableGroupPaymentCalendarDetails();
		SetVisiblePaymentCalendar();
		SetVisibleCashAssetsTypes();
		
	Else
		
		Notify = New NotifyDescription("ClearPaymentCalendarContinue", ThisObject);
		
		QueryText = NStr("en = 'The payment terms will be cleared. Do you want to continue?'");
		ShowQueryBox(Notify, QueryText,  QuestionDialogMode.YesNo);
		
	EndIf;
	
EndProcedure

&AtServer
Procedure FillThePaymentCalenderOnServer()
	
	FillPaymentCalendarFromContract(SwitchTypeListOfPaymentCalendar);
	
	If Object.PaymentCalendar.Count() = 0 Then
		NewRow = Object.PaymentCalendar.Add();
		
		NewRow.PaymentPercentage = 100;
		NewRow.PaymentAmount = Object.Products.Total("Amount");
		NewRow.PaymentVATAmount = Object.Products.Total("VATAmount");
	EndIf;
	
EndProcedure

&AtClient
Procedure SetEnableGroupPaymentCalendarDetails()
	Items.GroupPaymentCalendarDetails.Enabled = Object.SetPaymentTerms;
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
Procedure SetVisibleAndEnabled()
	
	SetVisiblePaymentCalendar();
	
EndProcedure

&AtClient
Procedure SetVisibleCashAssetsTypes()
	
	If Object.CashAssetsType = PredefinedValue("Enum.CashAssetTypes.Cash") Then // Cash
		Items.CashAssetsTypeOfAccount.CurrentPage = Items.CashAssetsTypeOfAccountCash;
	ElsIf Object.CashAssetsType = PredefinedValue("Enum.CashAssetTypes.Noncash") Then // BankAccount
		Items.CashAssetsTypeOfAccount.CurrentPage = Items.CashAssetsTypeOfAccountBank;
	Else // Undefined
		Items.CashAssetsTypeOfAccount.CurrentPage = Items.CashAssetsTypeOfAccountNone;
	EndIf;
	
EndProcedure

&AtClient
Procedure SetVisiblePaymentCalendar()
	
	If SwitchTypeListOfPaymentCalendar Then
		Items.PagesPaymentCalendar.CurrentPage = Items.PagePaymentCalendarAsList;
	Else
		Items.PagesPaymentCalendar.CurrentPage = Items.PagePaymentCalendarWithoutSplitting;
	EndIf;
	
EndProcedure

&AtServer
Procedure FillPaymentCalendarFromContract(TypeListOfPaymentCalendar)
	
	Query = New Query("
	|SELECT
	|	Table.Term AS Term,
	|	Table.DuePeriod AS DuePeriod,
	|	Table.PaymentPercentage AS PaymentPercentage
	|FROM
	|	Catalog.CounterpartyContracts.StagesOfPayment AS Table
	|WHERE
	|	Table.Ref = &Ref
	|");
	
	Query.SetParameter("Ref", Object.Contract);
	
	Result = Query.Execute();
	DataSelection = Result.Select();
	
	If Result.IsEmpty() Then
		Return;
	EndIf;
	
	Object.PaymentCalendar.Clear();
	
	InventoryTotalAllForCorrectBalance = 0;
	InventoryTotalAmountOfVATForCorrectBalance = 0;
	
	ProductTotalAll = Object.Products.Total("Amount");
	ProductTotalVATAmount = Object.Products.Total("VATAmount");
	
	While DataSelection.Next() Do
		
		NewLine = Object.PaymentCalendar.Add();
		
		If DataSelection.Term = Enums.PaymentTerm.PaymentInAdvance Then
			NewLine.PaymentDate = Object.Date - DataSelection.DuePeriod * 86400;
		Else
			NewLine.PaymentDate = Object.Date + DataSelection.DuePeriod * 86400;
		EndIf;
		
		NewLine.PaymentPercentage = DataSelection.PaymentPercentage;
		NewLine.PaymentAmount = Round(ProductTotalAll * NewLine.PaymentPercentage / 100, 2, RoundMode.Round15as20);
		NewLine.PaymentVATAmount = Round(ProductTotalVATAmount * NewLine.PaymentPercentage / 100, 2, RoundMode.Round15as20);
		
		InventoryTotalAllForCorrectBalance = InventoryTotalAllForCorrectBalance + NewLine.PaymentAmount;
		InventoryTotalAmountOfVATForCorrectBalance = InventoryTotalAmountOfVATForCorrectBalance + NewLine.PaymentVATAmount;
		
	EndDo;
	
	// correct balance
	NewLine.PaymentAmount = NewLine.PaymentAmount + (ProductTotalAll - InventoryTotalAllForCorrectBalance);
	NewLine.PaymentVATAmount = NewLine.PaymentVATAmount + (ProductTotalVATAmount - InventoryTotalAmountOfVATForCorrectBalance);
	
	ContractAttributesValues = CommonUse.ObjectAttributesValues(
		Object.Contract,
		"PaymentMethod, CounterpartyBankAccount");
	
	Object.SetPaymentTerms = True;
	Object.CashAssetsType = CommonUse.ObjectAttributeValue(Object.Contract, "PaymentMethod");
	
	If Object.CashAssetsType = Enums.CashAssetTypes.Noncash Then
		Object.BankAccount = CommonUse.ObjectAttributeValue(Object.Company, "BankAccountByDefault");
	ElsIf Object.CashAssetsType = Enums.CashAssetTypes.Cash Then
		Object.PettyCash = CommonUse.ObjectAttributeValue(Object.Company, "PettyCashByDefault");
	EndIf;
	
	If DataSelection.Count() > 1 Then
		TypeListOfPaymentCalendar = 1;
	Else
		TypeListOfPaymentCalendar = 0;
	EndIf;
	
EndProcedure

&AtClient
Procedure UpdatePaymentCalendar()
	
	SetEnableGroupPaymentCalendarDetails();
	SetVisiblePaymentCalendar();
	SetVisibleCashAssetsTypes();
	
EndProcedure

&AtClient
Procedure ProductsProductsStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	ChoiceForm	= OpenForm("Catalog.Products.ChoiceForm",, Item);
	Filter		= ChoiceForm.List.Filter;	
	
	GroupOfFilter = CommonUseClientServer.CreateGroupOfFilterItems(Filter.Items, "Replenishment method", DataCompositionFilterItemsGroupType.OrGroup);
	CommonUseClientServer.AddCompositionItem(GroupOfFilter, "ReplenishmentMethod",
												DataCompositionComparisonType.Equal, PredefinedValue("Enum.InventoryReplenishmentMethods.Production"),, True);
	CommonUseClientServer.AddCompositionItem(GroupOfFilter, "ReplenishmentMethod",
												DataCompositionComparisonType.Equal, PredefinedValue("Enum.InventoryReplenishmentMethods.Processing"),, True);
	
EndProcedure

&AtClient
Procedure RecalculatePaymentCalendar()
	
	If Object.SetPaymentTerms
		AND Object.PaymentCalendar.Count() > 0 Then
		
		AmountForFill = Object.Products.Total("Amount");
		VATForFill = Object.Products.Total("VATAmount");
		
		InventoryTotalAllForCorrectBalance = 0;
		InventoryTotalAmountOfVATForCorrectBalance = 0;
		
		For Each Line In Object.PaymentCalendar Do
			
			Line.PaymentAmount = Round(AmountForFill * Line.PaymentPercentage / 100, 2, RoundMode.Round15as20);
			Line.PaymentVATAmount = Round(VATForFill * Line.PaymentPercentage / 100, 2, RoundMode.Round15as20);
			
			InventoryTotalAllForCorrectBalance = InventoryTotalAllForCorrectBalance + Line.PaymentAmount;
			InventoryTotalAmountOfVATForCorrectBalance = InventoryTotalAmountOfVATForCorrectBalance + Line.PaymentVATAmount;
			
		EndDo;
		
		// correct balance
		Line.PaymentAmount = Line.PaymentAmount + (AmountForFill - InventoryTotalAllForCorrectBalance);
		Line.PaymentVATAmount = Line.PaymentVATAmount + (VATForFill - InventoryTotalAmountOfVATForCorrectBalance);
	EndIf;

EndProcedure

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

&AtClient
Procedure FillSalesRepInProducts(SalesRep)
	
	For Each CurrentRow In Object.Products Do
		CurrentRow.SalesRep = SalesRep;
	EndDo;
	
EndProcedure

#EndRegion

