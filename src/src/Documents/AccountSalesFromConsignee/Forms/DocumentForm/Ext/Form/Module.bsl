
////////////////////////////////////////////////////////////////////////////////
// MODULE VARIABLES

#Region Variables

&AtClient
Var LineCopyInventory;

&AtClient
Var ThisIsNewRow;

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
// The procedure handles the change of the Price kind and Settlement currency document
// attributes
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
	
	LabelStructure = New Structure("DocumentCurrency, SettlementsCurrency, ExchangeRate, RateNationalCurrency, AmountIncludesVAT, ForeignExchangeAccounting, PriceKind, VATTaxation",
		ContractData.SettlementsCurrency,
		SettlementsCurrency,
		Object.ExchangeRate,
		RateNationalCurrency,
		Object.AmountIncludesVAT,
		ForeignExchangeAccounting,
		Object.PriceKind,
		Object.VATTaxation);
	
	PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
	
	Object.DocumentCurrency = ContractData.SettlementsCurrency;
	
	If OpenFormPricesAndCurrencies Then
		
		WarningText = "";
		If QueryPriceKind AND RecalculationRequired Then
			
			WarningText = NStr("en = 'The counterparty contract allows for the kind of prices other than prescribed in the document. 
			                   |Recalculate the document according to the contract?'") + Chars.LF + Chars.LF;
				
		EndIf;
		
		WarningText = WarningText + NStr("en = 'Settlement currency of the contract with counterparty changed. 
		                                 |It is necessary to check the document currency.'");
			
		ProcessChangesOnButtonPricesAndCurrencies(SettlementsCurrencyBeforeChange, True, QueryPriceKind, WarningText);
		
	ElsIf QueryPriceKind Then
		
		If RecalculationRequired Then
			
			QuestionText = NStr("en = 'The counterparty contract allows for the kind of prices other than prescribed in the document. 
			                    |Recalculate the document according to the contract?'");
				
			NotifyDescription = New NotifyDescription("DefineDocumentRecalculateNeedByContractTerms", ThisObject, DocumentParameters);
			
			ShowQueryBox(NotifyDescription, QuestionText, QuestionDialogMode.YesNo);
			
		EndIf;
		
	EndIf;
	
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

// Receives the data set from the server for the CompanyOnChange procedure.
//
&AtServer
Function GetCompanyDataOnChange()
	
	StructureData = New Structure();
	
	StructureData.Insert("Company", DriveServer.GetCompany(Object.Company));
	StructureData.Insert("VATRate", InformationRegisters.AccountingPolicy.GetDefaultVATRate(Object.Date, Object.Company));
	
	FillAddedColumns(True);
	FillVATRateByCompanyVATTaxation();
	
	Return StructureData;
	
EndFunction

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
	
	If StructureData.Property("PriceKind") Then
		Price = DriveServer.GetProductsPriceByPriceKind(StructureData);
		StructureData.Insert("Price", Price);
	Else
		StructureData.Insert("Price", 0);
	EndIf;
	
	GLAccountsInDocumentsServerCall.FillProductGLAccounts(StructureData);
	
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
	
	Price = DriveServer.GetProductsPriceByPriceKind(StructureData);
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

// It receives data set from server for the ContractOnChange procedure.
//
&AtServer
Function GetDataCounterpartyOnChange(Date, DocumentCurrency, Counterparty, Company)
	
	ContractByDefault = GetContractByDefault(Object.Ref, Counterparty, Company);
	
	FillVATRateByCompanyVATTaxation();
	
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
	
	StructureData.Insert(
		"SalesRep",
		CommonUse.ObjectAttributeValue(Counterparty, "SalesRep"));
	
	SetContractVisible();
	
	Return StructureData;
	
EndFunction

// It receives data set from server for the ContractOnChange procedure.
//
&AtServerNoContext
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
		"AmountIncludesVAT",
		?(ValueIsFilled(Contract.PriceKind), Contract.PriceKind.PriceIncludesVAT, Undefined)
	);
	
	Return StructureData;
	
EndFunction

// Procedure fills VAT Rate in tabular section
// by company taxation system.
// 
&AtServer
Procedure FillVATRateByCompanyVATTaxation()
	
	TaxationBeforeChange = Object.VATTaxation;
	
	Object.VATTaxation = DriveServer.CounterpartyVATTaxation(Object.Counterparty, DriveServer.VATTaxation(Object.Company, Object.Date));
	
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
		Items.InventoryVATAmountTransfer.Visible = True;
		Items.PaymentVATAmount.Visible = True;
		Items.PaymentCalendarPayVATAmount.Visible = True;
		Items.InventoryTotalAmountOfVAT.Visible = True;
		
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
											
			TabularSectionRow.TransmissionVATAmount = ?(Object.AmountIncludesVAT,
													TabularSectionRow.TransmissionAmount - (TabularSectionRow.TransmissionAmount) / ((VATRate + 100) / 100),
													TabularSectionRow.TransmissionAmount * VATRate / 100);
								                    											
			TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
			
		EndDo;	
		
	Else
		
		Items.InventoryVATRate.Visible = False;
		Items.InventoryVATAmount.Visible = False;
		Items.InventoryAmountTotal.Visible = False;
		Items.InventoryVATAmountTransfer.Visible = False;
		Items.PaymentVATAmount.Visible = False;
		Items.PaymentCalendarPayVATAmount.Visible = False;
		Items.InventoryTotalAmountOfVAT.Visible = False;
		
		If Object.VATTaxation = Enums.VATTaxationTypes.NotSubjectToVAT Then
		    DefaultVATRate = Catalogs.VATRates.Exempt;
		Else
			DefaultVATRate = Catalogs.VATRates.ZeroRate;
		EndIf;	
		
		For Each TabularSectionRow In Object.Inventory Do
		
			TabularSectionRow.VATRate = DefaultVATRate;
			TabularSectionRow.VATAmount = 0;
			TabularSectionRow.TransmissionVATAmount = 0;
			
			TabularSectionRow.Total = TabularSectionRow.Amount;
			
		EndDo;	
		
	EndIf;	
	
EndProcedure

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
	
	// Serial numbers
	If UseSerialNumbersBalance <> Undefined Then
		WorkWithSerialNumbersClientServer.UpdateSerialNumbersQuantity(Object, TabularSectionRow,, "ConnectionKeySerialNumbers");
	EndIf;
	
EndProcedure

// Calculates the brokerage in the row of the document tabular section
//
// Parameters:
//  TabularSectionRow - String of the document
// tabular section,
&AtClient
Procedure CalculateCommissionRemuneration(TabularSectionRow)
	
	If Object.BrokerageCalculationMethod = PredefinedValue("Enum.CommissionFeeCalculationMethods.IsNotCalculating") Then
	
	ElsIf Object.BrokerageCalculationMethod = PredefinedValue("Enum.CommissionFeeCalculationMethods.PercentFromSaleAmount") Then
		TabularSectionRow.BrokerageAmount = Object.CommissionFeePercent * TabularSectionRow.Amount / 100;
	ElsIf Object.BrokerageCalculationMethod = PredefinedValue("Enum.CommissionFeeCalculationMethods.PercentFromDifferenceOfSaleAndAmountReceipts") Then
		TabularSectionRow.BrokerageAmount = Object.CommissionFeePercent * (TabularSectionRow.Amount - TabularSectionRow.TransmissionAmount) / 100;
	Else
		TabularSectionRow.BrokerageAmount = 0;
	EndIf;
	
	VATRate = DriveReUse.GetVATRateValue(Object.VATCommissionFeePercent);
	
	TabularSectionRow.BrokerageVATAmount = ?(Object.AmountIncludesVAT,
													TabularSectionRow.BrokerageAmount - (TabularSectionRow.BrokerageAmount) / ((VATRate + 100) / 100),
													TabularSectionRow.BrokerageAmount * VATRate / 100);
													
	// Serial numbers
	If UseSerialNumbersBalance<>Undefined Then
		WorkWithSerialNumbersClientServer.UpdateSerialNumbersQuantity(Object, TabularSectionRow, ,"ConnectionKeySerialNumbers");
	EndIf;
	
EndProcedure

// Recalculates the exchange rate and multiplicity of
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
		
		QuestionText = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'The exchange rate as of the sales invoice date was: %1.
			     |Do you want to apply this rate instead of %2?'"),
			CurrencyRateInLetters,
			RateNewCurrenciesInLetters);
							
		AdditionalParameters = New Structure;
		AdditionalParameters.Insert("NewExchangeRate",	NewExchangeRate);
		AdditionalParameters.Insert("NewRatio",			NewRatio);
		
		NotifyDescription = New NotifyDescription("DefineNewExchangeRatesettingNeed", ThisObject, AdditionalParameters);
		ShowQueryBox(NotifyDescription, QuestionText, QuestionDialogMode.YesNo);
		
	EndIf;
	
EndProcedure

// Procedure executes recalculate in the document tabular section
// after changes in "Prices and currency" form.Column recalculation is executed:
// price, discount, amount, VAT amount, total.
//
&AtClient
Procedure ProcessChangesOnButtonPricesAndCurrencies(Val SettlementsCurrencyBeforeChange, RecalculatePrices = False, RefillPrices = False, WarningText = "")
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("PriceKind",				Object.PriceKind);
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
	ParametersStructure.Insert("WarningText", WarningText);
	ParametersStructure.Insert("ReverseChargeNotApplicable", True);
	
	NotifyDescription = New NotifyDescription("OpenPricesAndCurrencyFormEnd", ThisObject, New Structure("SettlementsCurrencyBeforeChange", SettlementsCurrencyBeforeChange));
	OpenForm("CommonForm.PricesAndCurrency", ParametersStructure, ThisForm, , , , NotifyDescription, FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

// Column value Total PM is being calculated Customers on client.
//
&AtClient
Procedure CalculateColumnTotalAtClient(RowCustomers)
	
	FilterParameters = New Structure;
	FilterParameters.Insert("ConnectionKey", RowCustomers.ConnectionKey);
	SearchResult = Object.Inventory.FindRows(FilterParameters);
	If SearchResult.Count() = 0 Then
		RowCustomers.Total = 0;
	Else
		TotalAmount = 0;
		For Each TSRow In SearchResult Do
			TotalAmount = TotalAmount + TSRow.Total;
		EndDo;
		RowCustomers.Total = TotalAmount;
	EndIf;
	
EndProcedure

// Update the column value Total PM Customers on client.
//
&AtClient
Procedure UpdateColumnTotalAtClient(UpdateAllRows = False)
	
	CurrentRowCustomers = Items.Customers.CurrentData;
	If CurrentRowCustomers = Undefined Then
		Return;
	EndIf;
	
	If UpdateAllRows Then
		
		For Each RowCustomers In Object.Customers Do
			
			CalculateColumnTotalAtClient(RowCustomers);
			
		EndDo;
		
	Else
		
		CalculateColumnTotalAtClient(CurrentRowCustomers);
		
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
	
	CurrentConnectionKey = Items.Inventory.RowFilter["ConnectionKey"];
	For Each CurBarcode In StructureData.BarcodesArray Do
		BarcodeData = StructureData.DataByBarCodes[CurBarcode.Barcode];
		
		If BarcodeData <> Undefined
		   AND BarcodeData.Count() = 0 Then
			UnknownBarcodes.Add(CurBarcode);
		Else
			TSRowsArray = Object.Inventory.FindRows(New Structure("Products,Characteristic,Batch,MeasurementUnit,ConnectionKey",BarcodeData.Products,BarcodeData.Characteristic,BarcodeData.Batch,BarcodeData.MeasurementUnit,CurrentConnectionKey));
			If TSRowsArray.Count() = 0 Then
				NewRow = Object.Inventory.Add();
				NewRow.Products = BarcodeData.Products;
				NewRow.Characteristic = BarcodeData.Characteristic;
				NewRow.Batch = BarcodeData.Batch;
				NewRow.Quantity = CurBarcode.Quantity;
				NewRow.MeasurementUnit = ?(ValueIsFilled(BarcodeData.MeasurementUnit), BarcodeData.MeasurementUnit, BarcodeData.StructureProductsData.MeasurementUnit);
				NewRow.Price = BarcodeData.StructureProductsData.Price;
				NewRow.VATRate = BarcodeData.StructureProductsData.VATRate;
				NewRow.ConnectionKey = CurrentConnectionKey;
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
				WorkWithSerialNumbersClientServer.AddSerialNumberToString(NewRow, BarcodeData.SerialNumber, Object, "ConnectionKeySerialNumbers");
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
		
		QueryBoxPrepayment = Object.Prepayment.Count() > 0 AND Object.Contract <> ContractBeforeChange;
		
		PriceKindChanged = Object.PriceKind <> ContractData.PriceKind AND ValueIsFilled(ContractData.PriceKind);
		QueryPriceKind = ValueIsFilled(Object.Contract) AND PriceKindChanged;
		
		SettlementsCurrencyBeforeChange = SettlementsCurrency;
		SettlementsCurrency = ContractData.SettlementsCurrency;
		
		RecalculationRequired = (Object.Inventory.Count() > 0);
		
		NewContractAndCalculationCurrency = ValueIsFilled(Object.Contract) AND ValueIsFilled(SettlementsCurrency) 
			AND Object.Contract <> ContractBeforeChange AND SettlementsCurrencyBeforeChange <> ContractData.SettlementsCurrency;
		OpenFormPricesAndCurrencies = NewContractAndCalculationCurrency AND Object.DocumentCurrency <> ContractData.SettlementsCurrency
			AND Object.Inventory.Count() > 0;
		
		DocumentParameters.Insert("ContractBeforeChange", ContractBeforeChange);
		DocumentParameters.Insert("SettlementsCurrencyBeforeChange", SettlementsCurrencyBeforeChange);
		DocumentParameters.Insert("ContractData", ContractData);
		DocumentParameters.Insert("RecalculationRequired", RecalculationRequired);
		DocumentParameters.Insert("PriceKindChanged", PriceKindChanged);
		DocumentParameters.Insert("QueryBoxPrepayment", QueryBoxPrepayment);
		DocumentParameters.Insert("QueryPriceKind", QueryPriceKind);
		DocumentParameters.Insert("OpenFormPricesAndCurrencies", OpenFormPricesAndCurrencies);
		DocumentParameters.Insert("ContractVisibleBeforeChange", Items.Contract.Visible);
		
		If QueryBoxPrepayment = True Then
			
			QuestionText = NStr("en = 'The prepayment recognition will be cleared. Do you want to continue?'");
			
			NotifyDescription = New NotifyDescription("DefineAdvancePaymentOffsetsRefreshNeed", ThisObject, DocumentParameters);
			ShowQueryBox(NotifyDescription, QuestionText, QuestionDialogMode.YesNo);
			
		Else
			
			ProcessPricesKindAndSettlementsCurrencyChange(DocumentParameters);
			
		EndIf;
		
		FillPaymentCalendarFromContract(SwitchTypeListOfPaymentCalendar);
		UpdatePaymentCalendar();
		
	EndIf;
	
EndProcedure

#Region WorkWithSelection 

// Procedure - event handler Action of the Pick command
//
&AtClient
Procedure Pick(Command)
	
	TabularSectionName	= "Customers";
	Cancel = DriveClient.BeforeAddToSubordinateTabularSection(ThisObject, "Inventory");
	If Cancel Then
		Return;
	EndIf;
	TabularSectionName	= "Inventory";
	DocumentPresentaion	= NStr("en = 'account sales from consignee'");
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

// Procedure - event handler Action of the command pick by balances.
//
&AtClient
Procedure SelectionByBalances(Command)
	
	TabularSectionName = "Customers";
	Cancel = DriveClient.BeforeAddToSubordinateTabularSection(ThisForm, "Inventory");
	
	If Not ValueIsFilled(Object.Company) Then
		MessageText = NStr("en = 'Please specify the consignor.'");
		DriveClient.ShowMessageAboutError(ThisForm, MessageText,,, "Company", Cancel);
	EndIf;
	If Not ValueIsFilled(Object.Counterparty) Then
		MessageText = NStr("en = 'Please specify the consignee.'");
		DriveClient.ShowMessageAboutError(ThisForm, MessageText,,, "Counterparty", Cancel);
	EndIf;
	If Not ValueIsFilled(Object.Contract) Then
		MessageText = NStr("en = 'Please specify the contract.'");
		DriveClient.ShowMessageAboutError(ThisForm, MessageText,,, "Contract", Cancel);
	EndIf;
	
	If Cancel Then
		Return;
	EndIf;
	
	TabularSectionName = "Inventory";
	
	SelectionParameters = New Structure("Company,
		|Counterparty,
		|Contract,
		|DocumentCurrency,
		|DocumentDate",
		ParentCompany,
		Object.Counterparty,
		Object.Contract,
		Object.DocumentCurrency,
		Object.Date
	);
	
	OpenForm("Document.AccountSalesFromConsignee.Form.PickFormByBalances", SelectionParameters, ThisForm);
	
	FilterStr = New FixedStructure("ConnectionKey", Items[TabularSectionName].RowFilter["ConnectionKey"]);
	Items[TabularSectionName].RowFilter = FilterStr;
	
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
		
		NewRow.TransmissionPrice = NewRow.Price;
		NewRow.TransmissionAmount = NewRow.Amount;
		NewRow.TransmissionVATAmount = NewRow.VATAmount;
		
		NewRow.ConnectionKey = Items[TabularSectionName].RowFilter["ConnectionKey"];
		
		FillPropertyValues(StructureData, NewRow);
		GLAccountsInDocumentsServerCall.FillProductGLAccounts(StructureData, GLAccounts);
		FillPropertyValues(NewRow, StructureData);
		
	EndDo;
	
EndProcedure

// Function receives the inventory list transferred from the temporary storage
//
&AtServer
Procedure GetStockTransferredToThirdPartiesFromStorage(AddressStockTransferredToThirdPartiesInStorage)
	
	StockTransferredToThirdParties = GetFromTempStorage(AddressStockTransferredToThirdPartiesInStorage);
	
	For Each TabularSectionRow In StockTransferredToThirdParties Do
		
		NewRow = Object.Inventory.Add();
		FillPropertyValues(NewRow, TabularSectionRow);
		
		StructureData = New Structure("InventoryTransferredGLAccount, VATOutputGLAccount, RevenueGLAccount, COGSGLAccount");
		StructureData.Insert("Company", Object.Company);
		StructureData.Insert("Products", TabularSectionRow.Products);
		StructureData.Insert("VATTaxation", Object.VATTaxation);
		
		FillPropertyValues(StructureData, NewRow);
		StructureData.Insert("ObjectParameters", GLAccountsInDocumentsClientServer.GetObjectParameters(Object));
		StructureData = GetDataProductsOnChange(StructureData);
		
		FillPropertyValues(TabularSectionRow, StructureData); 
		NewRow.MeasurementUnit = StructureData.MeasurementUnit;
		NewRow.VATRate = StructureData.VATRate;
		
		If TabularSectionRow.Quantity > TabularSectionRow.Balance
			OR TabularSectionRow.Quantity = 0
			OR TabularSectionRow.SettlementsAmount = 0 Then
			NewRow.TransmissionAmount = 0;
		ElsIf TabularSectionRow.Quantity = TabularSectionRow.Balance Then
			NewRow.TransmissionAmount = TabularSectionRow.SettlementsAmount;
		Else
			NewRow.TransmissionAmount = Round(TabularSectionRow.SettlementsAmount / TabularSectionRow.Balance * TabularSectionRow.Quantity,2,0);
		EndIf;
		
		NewRow.TransmissionPrice = NewRow.TransmissionAmount / NewRow.Quantity;
		
		VATRate = DriveReUse.GetVATRateValue(NewRow.VATRate);
		NewRow.TransmissionVATAmount = ?(Object.AmountIncludesVAT,
										NewRow.TransmissionAmount - (NewRow.TransmissionAmount) / ((VATRate + 100) / 100),
										NewRow.TransmissionAmount * VATRate / 100);
		
		NewRow.ConnectionKey = Items[TabularSectionName].RowFilter["ConnectionKey"];
		
	EndDo;
	
EndProcedure

// Function places the list of advances into temporary storage and returns the address
//
&AtServer
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
			
			InventoryAddressInStorage	= ClosingResult.CartAddressInStorage;
			TabularSectionName	= "Inventory";
		
			GetInventoryFromStorage(InventoryAddressInStorage, TabularSectionName, True, False);
			
			FilterStr = New FixedStructure("ConnectionKey", Items[TabularSectionName].RowFilter["ConnectionKey"]);
			Items[TabularSectionName].RowFilter = FilterStr;
			
			UpdateColumnTotalAtClient();
			RecalculateSubtotal();
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region ControlOfTheFormAppearance

// Procedure sets availability of the form items.
//
&AtClient
Procedure SetVisibleAndEnabled()
	
	If Object.BrokerageCalculationMethod = PredefinedValue("Enum.CommissionFeeCalculationMethods.IsNotCalculating") Then
		Object.CommissionFeePercent = 0;
		Items.CommissionFeePercent.Enabled = False;
	Else
		Items.CommissionFeePercent.Enabled = True;
	EndIf;
	
	SetVisiblePaymentCalendar();
	
EndProcedure

&AtClient
Procedure SetVisiblePaymentCalendar()
	
	If SwitchTypeListOfPaymentCalendar Then
		Items.PagesPaymentCalendar.CurrentPage = Items.PagePaymentCalendarAsList;
	Else
		Items.PagesPaymentCalendar.CurrentPage = Items.PagePaymentCalendarWithoutSplitting;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormEventHandlers

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	FillAddedColumns();
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
	
	If Not ValueIsFilled(Object.Ref)
		  AND ValueIsFilled(Object.Counterparty)
	   AND Not ValueIsFilled(Parameters.CopyingValue) Then
		If Not ValueIsFilled(Object.Contract) Then
			Object.Contract = Object.Counterparty.ContractByDefault;
		EndIf;
		If ValueIsFilled(Object.Contract) Then
			Object.DocumentCurrency = Object.Contract.SettlementsCurrency;
			SettlementsCurrencyRateRepetition = InformationRegisters.ExchangeRates.GetLast(Object.Date, New Structure("Currency", Object.Contract.SettlementsCurrency));
			Object.ExchangeRate      = ?(SettlementsCurrencyRateRepetition.ExchangeRate = 0, 1, SettlementsCurrencyRateRepetition.ExchangeRate);
			Object.Multiplicity = ?(SettlementsCurrencyRateRepetition.Multiplicity = 0, 1, SettlementsCurrencyRateRepetition.Multiplicity);
			Object.PriceKind = Object.Contract.PriceKind;
		EndIf;
	EndIf;
	
	// Form attributes setting.
	DocumentDate = Object.Date;
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentDate();
	EndIf;
	
	ParentCompany = DriveServer.GetCompany(Object.Company);
	Counterparty = Object.Counterparty;
	Contract = Object.Contract;
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
		Items.InventoryVATRate.Visible = True;
		Items.InventoryVATAmount.Visible = True;
		Items.InventoryAmountTotal.Visible = True;
		Items.InventoryVATAmountTransfer.Visible = True;
		Items.InventoryTotalAmountOfVAT.Visible = True;
		Items.PaymentVATAmount.Visible = True;
		Items.PaymentCalendarPayVATAmount.Visible = True;
	Else
		Items.InventoryVATRate.Visible = False;
		Items.InventoryVATAmount.Visible = False;
		Items.InventoryAmountTotal.Visible = False;
		Items.InventoryVATAmountTransfer.Visible = False;
		Items.InventoryTotalAmountOfVAT.Visible = False;
		Items.PaymentVATAmount.Visible = False;
		Items.PaymentCalendarPayVATAmount.Visible = False;
	EndIf;
	
	// Generate price and currency label.
	ForeignExchangeAccounting = Constants.ForeignExchangeAccounting.Get();
	LabelStructure = New Structure("PriceKind, DocumentCurrency, SettlementsCurrency, ExchangeRate, RateNationalCurrency, AmountIncludesVAT, ForeignExchangeAccounting, VATTaxation", Object.PriceKind, Object.DocumentCurrency, SettlementsCurrency, Object.ExchangeRate, RateNationalCurrency, Object.AmountIncludesVAT, ForeignExchangeAccounting, Object.VATTaxation);
	PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
	
	Object.VATCommissionFeePercent = InformationRegisters.AccountingPolicy.GetDefaultVATRate(Object.Date, ParentCompany);
	
	FillAddedColumns();
	
	// Setting contract visible.
	SetContractVisible();
	
	// Price accessibility setup for editing.
	AllowedEditDocumentPrices = DriveAccessManagementReUse.AllowedEditDocumentPrices();
	
	Items.InventoryPriceOfTransfer.ReadOnly 	   = Not AllowedEditDocumentPrices;
	Items.InventorySumOfTransfers.ReadOnly    = Not AllowedEditDocumentPrices;
	Items.InventoryVATAmountTransfer.ReadOnly = Not AllowedEditDocumentPrices;
	
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
	
	FillAddedColumns();
	ClosingDates.ObjectOnReadAtServer(ThisForm, CurrentObject);
	
	SetSwitchTypeListOfPaymentCalendar();
	
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
			Message.Text = ?(Cancel, NStr("en = 'Cannot post the account sales.'") + " " + MessageText, MessageText);
			
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

// Procedure - event handler AfterWriting.
//
&AtClient
Procedure AfterWrite(WriteParameters)
	
	Notify("NotificationAboutChangingDebt");
	
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
			TabularSectionName = "Customers";
			If DriveClient.BeforeAddToSubordinateTabularSection(ThisForm, "Inventory") Then
				Return;
			EndIf;
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
			RecalculateSubtotal();
		EndIf; 	
	EndIf;
	
EndProcedure

// Procedure - event handler ChoiceProcessing.
//
&AtClient
Procedure ChoiceProcessing(ValueSelected, ChoiceSource)
	
	If ChoiceSource.FormName = "Document.AccountSalesFromConsignee.Form.PickFormByBalances" Then
		GetStockTransferredToThirdPartiesFromStorage(ValueSelected);
	ElsIf ChoiceSource.FormName = "CommonForm.ProductGLAccounts" Then
		GLAccountsChoiceProcessingAtClient(ValueSelected);
	EndIf;
	
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

// Procedure is called when clicking the "AddCounterpartyToCustomers" button
//
&AtClient
Procedure AddCounterpartyToCustomers(Command)
	
	If ValueIsFilled(Object.Counterparty) Then
		
		NewRow = Object.Customers.Add();
		NewRow.Customer = Object.Counterparty;
		
		TabularSectionName = "Customers";
		NewRow.ConnectionKey = DriveClient.CreateNewLinkKey(ThisForm);
		DriveClient.SetFilterOnSubordinateTabularSection(ThisForm, "Inventory");
		
		Items.Customers.CurrentRow = NewRow.GetID();
		
	EndIf;
	
EndProcedure

// Procedure - command handler of the tabular section command panel.
//
&AtClient
Procedure EditPrepaymentOffset(Command)
	
	If Not ValueIsFilled(Object.Counterparty) Then
		ShowMessageBox(, NStr("en = 'Please select a consignee.'"));
		Return;
	EndIf;
	
	If Not ValueIsFilled(Object.Contract) Then
		ShowMessageBox(, NStr("en = 'Please select a contract.'"));
		Return;
	EndIf;
	
	OrdersArray = New Array;
	For Each CurItem In Object.Inventory Do
		OrderStructure = New Structure("Order, Total");
		OrderStructure.Order = CurItem.SalesOrder;
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

// Peripherals
// Procedure - command handler of the tabular section command panel.
//
&AtClient
Procedure SearchByBarcode(Command)
	
	TabularSectionName = "Customers";
	Cancel = DriveClient.BeforeAddToSubordinateTabularSection(ThisForm, "Inventory");
	If Cancel Then
		Return;
	EndIf;
	
	CurBarcode = "";
	ShowInputValue(New NotifyDescription("SearchByBarcodeEnd", ThisObject, New Structure("CurBarcode", CurBarcode)), CurBarcode, NStr("en = 'Enter barcode'"));

EndProcedure

&AtClient
Procedure SearchByBarcodeEnd(Result, AdditionalParameters) Export
	
	CurBarcode = ?(Result = Undefined, AdditionalParameters.CurBarcode, Result);
	
	
	If Not IsBlankString(CurBarcode) Then
		
		BarcodesReceived(New Structure("Barcode, Quantity", CurBarcode, 1));
		
		TabularSectionName = "Inventory";
		FilterStr = New FixedStructure("ConnectionKey", Items[TabularSectionName].RowFilter["ConnectionKey"]);
		Items[TabularSectionName].RowFilter = FilterStr;
		
		UpdateColumnTotalAtClient();
		
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
			
			// Amount of the transfer.
			TabularSectionRow.TransmissionAmount = TabularSectionRow.TransmissionPrice * TabularSectionRow.Quantity;
			
			VATRate = DriveReUse.GetVATRateValue(TabularSectionRow.VATRate);
			
			// VAT amount of the transfer.
			TabularSectionRow.TransmissionVATAmount = ?(
				Object.AmountIncludesVAT,
				TabularSectionRow.TransmissionAmount - (TabularSectionRow.TransmissionAmount) / ((VATRate + 100) / 100),
				TabularSectionRow.TransmissionAmount * VATRate / 100
			);
			
			// Amount of brokerage
			CalculateCommissionRemuneration(TabularSectionRow);
		EndIf;
	EndIf;
	
EndProcedure

// Procedure - ImportDataFromDTC command handler.
//
&AtClient
Procedure ImportDataFromDCT(Command)
	
	TabularSectionName = "Customers";
	Cancel = DriveClient.BeforeAddToSubordinateTabularSection(ThisForm, "Inventory");
	If Cancel Then
		Return;
	EndIf;
	
	NotificationsAtImportFromDCT = New NotifyDescription("ImportFromDCTEnd", ThisObject);
	EquipmentManagerClient.StartImportDataFromDCT(NotificationsAtImportFromDCT, UUID);
	
EndProcedure

&AtClient
Procedure ImportFromDCTEnd(Result, Parameters) Export
	
	If TypeOf(Result) = Type("Array") 
	   AND Result.Count() > 0 Then
		
		BarcodesReceived(Result);
		
		TabularSectionName = "Inventory";
		FilterStr = New FixedStructure("ConnectionKey", Items[TabularSectionName].RowFilter["ConnectionKey"]);
		Items[TabularSectionName].RowFilter = FilterStr;
		
		UpdateColumnTotalAtClient();
		
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
		StructureData = GetDataDateOnChange(DateBeforeChange, SettlementsCurrency);
		If StructureData.DATEDIFF <> 0 Then
			Object.Number = "";
		EndIf;
		
		If ValueIsFilled(SettlementsCurrency) Then
			RecalculateExchangeRateMultiplicitySettlementCurrency(StructureData);
		EndIf;	
		
		LabelStructure = New Structure("PriceKind, DocumentCurrency, SettlementsCurrency, ExchangeRate, RateNationalCurrency, AmountIncludesVAT, ForeignExchangeAccounting, VATTaxation", Object.PriceKind, Object.DocumentCurrency, SettlementsCurrency, Object.ExchangeRate, RateNationalCurrency, Object.AmountIncludesVAT, ForeignExchangeAccounting, Object.VATTaxation);
		PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
		
		RecalculatePaymentDate(DateBeforeChange, Object.Date);
		
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
	ParentCompany = StructureData.Company;
	Object.VATCommissionFeePercent = StructureData.VATRate;
	
	LabelStructure = New Structure("PriceKind, DocumentCurrency, SettlementsCurrency, ExchangeRate, RateNationalCurrency, AmountIncludesVAT, ForeignExchangeAccounting, VATTaxation", Object.PriceKind, Object.DocumentCurrency, SettlementsCurrency, Object.ExchangeRate, RateNationalCurrency, Object.AmountIncludesVAT, ForeignExchangeAccounting, Object.VATTaxation);
	PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
	
	Object.Contract = GetContractByDefault(Object.Ref, Object.Counterparty, Object.Company);
	ProcessContractChange();
	
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

// Procedure - event handler OnChange of the BrokerageCalculationMethod input field.
//
&AtClient
Procedure BrokerageCalculationMethodOnChange(Item)
	
	If Object.BrokerageCalculationMethod <> PredefinedValue("Enum.CommissionFeeCalculationMethods.IsNotCalculating")
		AND ValueIsFilled(Object.CommissionFeePercent) Then
		If Object.Inventory.Count() > 0 Then
			Response = Undefined;
			
			ShowQueryBox(New NotifyDescription("BrokerageCalculationMethodOnChangeEnd", ThisObject), 
				NStr("en = 'The calculation method has been changed. Do you want to recalculate the commission?'"),
				QuestionDialogMode.YesNo, , DialogReturnCode.Yes);
			Return;
		EndIf;
	EndIf;
	
	BrokerageCalculationMethodOnChangeFragment();
EndProcedure

&AtClient
Procedure BrokerageCalculationMethodOnChangeEnd(Result, AdditionalParameters) Export
	
	Response = Result;
	If Response = DialogReturnCode.Yes Then
		For Each TabularSectionRow In Object.Inventory Do
			CalculateCommissionRemuneration(TabularSectionRow);
		EndDo;
	EndIf;
	
	BrokerageCalculationMethodOnChangeFragment();
	RecalculatePaymentCalendar();

EndProcedure

&AtClient
Procedure BrokerageCalculationMethodOnChangeFragment()
    
    SetVisibleAndEnabled();

EndProcedure

// Procedure - handler of the OnChange event of the BrokerageVATRate input field.
//
&AtClient
Procedure VATCommissionFeePercentOnChange(Item)
	
	If Object.Inventory.Count() = 0 Then
		Return;
	EndIf;
	
	Response = Undefined;

	
	ShowQueryBox(New NotifyDescription("BrokerageVATRateOnChangeEnd", ThisObject), "Do you want to recalculate VAT amounts of remuneration?", QuestionDialogMode.YesNo, , DialogReturnCode.No);
	
EndProcedure

&AtClient
Procedure BrokerageVATRateOnChangeEnd(Result, AdditionalParameters) Export
	
	Response = Result;
	
	If Response = DialogReturnCode.No Then
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

// Procedure - event handler OnChange of the BrokeragePercent.
//
&AtClient
Procedure CommissionFeePercentOnChange(Item)
	
	If Object.Inventory.Count() > 0 Then
		Response = Undefined;
		
		ShowQueryBox(New NotifyDescription("BrokeragePercentOnChangeEnd", ThisObject),
			NStr("en = 'The calculation method has been changed. Do you want to recalculate the commission?'"),
			QuestionDialogMode.YesNo, , DialogReturnCode.Yes);
	EndIf;
		
EndProcedure

&AtClient
Procedure BrokeragePercentOnChangeEnd(Result, AdditionalParameters) Export
	
	// We must offer to recalculate brokerage.
	Response = Result;
	If Response = DialogReturnCode.Yes Then
		For Each TabularSectionRow In Object.Inventory Do
			CalculateCommissionRemuneration(TabularSectionRow);
		EndDo;
		RecalculatePaymentCalendar();
	EndIf;
	
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
		
		StructureData = GetDataCounterpartyOnChange(Object.Date, Object.DocumentCurrency, Object.Counterparty, Object.Company);
		Object.Contract = StructureData.Contract;
		
		FillSalesRepInInventory(StructureData.SalesRep);
		
		StructureData.Insert("CounterpartyBeforeChange", CounterpartyBeforeChange);
		StructureData.Insert("CounterpartyDoSettlementsByOrdersBeforeChange", CounterpartyDoSettlementsByOrdersBeforeChange);
		
		ProcessContractChange(StructureData);
		
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

&AtClient
Procedure SalesRepOnChange(Item)
	If Object.Inventory.Count() > 1 Then
		FillSalesRepInInventory(Object.Inventory[0].SalesRep);
	EndIf;
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
Procedure SchedulePaymentOnChange(Item)
	FillThePaymentCalender();
EndProcedure

&AtClient
Procedure PaymentCalendarPaymentPercentageOnChange(Item)
	
	CurrentRow = Items.PaymentCalendar.CurrentData;
	
	CurrentRow.PaymentAmount = Round(AmountForPaymentCalendar() * CurrentRow.PaymentPercentage / 100, 2, 1);
	CurrentRow.PaymentVATAmount = Round(VATForPaymentCalendar() * CurrentRow.PaymentPercentage / 100, 2, 1);
	
EndProcedure

&AtClient
Procedure PaymentCalendarPaymentAmountOnChange(Item)
	
	CurrentRow = Items.PaymentCalendar.CurrentData;
	
	TotalAmount = AmountForPaymentCalendar();
	
	If TotalAmount = 0 Then
		CurrentRow.PaymentPercentage = 0;
		CurrentRow.PaymentVATAmount = 0;
	Else
		CurrentRow.PaymentPercentage = Round(CurrentRow.PaymentAmount / TotalAmount * 100, 2, 1);
		TotalVAT = VATForPaymentCalendar();
		CurrentRow.PaymentVATAmount = Round(TotalVAT * CurrentRow.PaymentAmount / TotalAmount, 2, 1);
	EndIf;
	
EndProcedure

&AtClient
Procedure PaymentCalendarPayVATAmountOnChange(Item)
	
	CurrentRow = Items.PaymentCalendar.CurrentData;
	
	PaymentCalendarTotal = Object.PaymentCalendar.Total("PaymentVATAmount");
	TotalAmountOfVAT = VATForPaymentCalendar();
	
	If PaymentCalendarTotal > TotalAmountOfVAT Then
		CurrentRow.PaymentVATAmount = CurrentRow.PaymentVATAmount - (PaymentCalendarTotal - TotalAmountOfVAT);
	EndIf;
	
EndProcedure

&AtClient
Procedure PaymentCalendarOnStartEdit(Item, NewRow, Clone)
	
	CurrentRow = Items.PaymentCalendar.CurrentData;
	
	If CurrentRow.PaymentPercentage = 0 Then
		CurrentRow.PaymentPercentage = 100 - Object.PaymentCalendar.Total("PaymentPercentage");
		CurrentRow.PaymentAmount = AmountForPaymentCalendar() - Object.PaymentCalendar.Total("PaymentAmount");
		CurrentRow.PaymentVATAmount = VATForPaymentCalendar() - Object.PaymentCalendar.Total("PaymentVATAmount");
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - EVENT HANDLERS OF TABULAR SECTION ATTRIBUTES CUSTOMERS

// Procedure - event handler OnActivateRow of the Customers tabular section.
//
&AtClient
Procedure CustomersOnActivateRow(Item)
	
	TabularSectionName = "Customers";
	DriveClient.SetFilterOnSubordinateTabularSection(ThisForm, "Inventory");
	
EndProcedure

// Procedure - OnStartEdit event handler of the Customers tabular section.
//
&AtClient
Procedure CustomersOnStartEdit(Item, NewRow, Copy)
	
	TabularSectionName = "Customers";
	TabularSectionRow = Item.CurrentData;
	
	If NewRow Then
		DriveClient.AddConnectionKeyToTabularSectionLine(ThisForm);
		DriveClient.SetFilterOnSubordinateTabularSection(ThisForm, "Inventory");
	EndIf;
	
	If Copy Then
		TabularSectionRow.Total = 0;
	EndIf;
	
EndProcedure

// Procedure - event handler BeforeDelete of the Customers tabular section.
//
&AtClient
Procedure CustomersBeforeDeleteRow(Item, Cancel)
	
	// Serial numbers
	CurrentCustomer = Items.Customers.CurrentData;
	SearchResult = Object.Inventory.FindRows(New Structure("ConnectionKey", CurrentCustomer.ConnectionKey));
	For Each StringInventory In SearchResult Do
		
		SearchResultSN = Object.SerialNumbers.FindRows(New Structure("ConnectionKey", StringInventory.ConnectionKeySerialNumbers));
		For Each StrSerialNumbers In SearchResultSN Do
			IndexToBeDeleted = Object.SerialNumbers.IndexOf(StrSerialNumbers);
			Object.SerialNumbers.Delete(IndexToBeDeleted);
		EndDo;
	EndDo;
	// Serial numbers
	
	TabularSectionName = "Customers";
	DriveClient.DeleteRowsOfSubordinateTabularSection(ThisForm, "Inventory");
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////PROCEDURE - EVENT HANDLERS OF THE
//    INVENTORY TABULAR SECTION ATTRIBUTES

// Procedure - OnStartEdit event handler of the Inventory tabular section.
//
&AtClient
Procedure InventoryOnStartEdit(Item, NewRow, Copy)
	
	TabularSectionName = "Customers";
	
	If NewRow Then
		DriveClient.AddConnectionKeyToSubordinateTabularSectionLine(ThisForm, Item.Name);
	EndIf;
	
	If NewRow AND Copy Then
		Item.CurrentData.ConnectionKeySerialNumbers = 0;
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

// Procedure - event handler BeforeAddStart of the Inventory tabular section.
//
&AtClient
Procedure InventoryBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	TabularSectionName = "Customers";
	
	Cancel = DriveClient.BeforeAddToSubordinateTabularSection(ThisForm, Item.Name);
	
	If Not Cancel AND Copy Then
		
		UpdateColumnTotalAtClient();
		
		CurRowCustomers = Items.Customers.CurrentData;
		CurRowCustomers.Total = CurRowCustomers.Total + Item.CurrentData.Total;
		
		LineCopyInventory = True;
		
	EndIf;
	
EndProcedure

// Procedure - event handler OnChange of the Inventory tabular section.
//
&AtClient
Procedure InventoryOnChange(Item)
	
	If LineCopyInventory = Undefined OR Not LineCopyInventory Then
		UpdateColumnTotalAtClient();
	Else
		LineCopyInventory = False;
	EndIf;
	RecalculatePaymentCalendar();
	RecalculateSubtotal();
	
EndProcedure

// Procedure - event handler OnChange of the Products input field.
//
&AtClient
Procedure InventoryProductsOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("Company", Object.Company);
	StructureData.Insert("Products", TabularSectionRow.Products);
	StructureData.Insert("VATTaxation", Object.VATTaxation);
	
	If ValueIsFilled(Object.PriceKind) Then
		StructureData.Insert("ProcessingDate",	 Object.Date);
		StructureData.Insert("PriceKind",			 Object.PriceKind);
		StructureData.Insert("DocumentCurrency",	 Object.DocumentCurrency);
		StructureData.Insert("AmountIncludesVAT", Object.AmountIncludesVAT);
		StructureData.Insert("Characteristic",	 TabularSectionRow.Characteristic);
		StructureData.Insert("Factor",		 1);
	EndIf;
	
	AddGLAccountsToStructure(StructureData, TabularSectionRow);	
	StructureData.Insert("ObjectParameters", GLAccountsInDocumentsClientServer.GetObjectParameters(Object));
	StructureData = GetDataProductsOnChange(StructureData);
	
	FillPropertyValues(TabularSectionRow, StructureData); 
	TabularSectionRow.MeasurementUnit = StructureData.MeasurementUnit;
	TabularSectionRow.Quantity		  = 1;
	TabularSectionRow.Price			  = StructureData.Price;
	TabularSectionRow.VATRate		  = StructureData.VATRate;
	TabularSectionRow.TransmissionPrice	  = 0;
	TabularSectionRow.TransmissionAmount	  = 0;
	TabularSectionRow.TransmissionVATAmount = 0;
	
	CalculateAmountInTabularSectionLine();
	CalculateCommissionRemuneration(TabularSectionRow);
	
	// Serial numbers
	For Each SelectedRow In Items.Inventory.SelectedRows Do
		CurrentRowData = Items.Inventory.RowData(SelectedRow);
		WorkWithSerialNumbersClientServer.DeleteSerialNumbersByConnectionKey(Object.SerialNumbers, CurrentRowData,, UseSerialNumbersBalance);
	EndDo;
	
EndProcedure

&AtClient
Procedure InventoryBeforeDeleteRow(Item, Cancel)
	
	// Serial numbers
	For Each SelectedRow In Items.Inventory.SelectedRows Do
		CurrentRowData = Items.Inventory.RowData(SelectedRow);
		WorkWithSerialNumbersClientServer.DeleteSerialNumbersByConnectionKey(Object.SerialNumbers, CurrentRowData,,UseSerialNumbersBalance);
	EndDo;
	
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
Procedure InventoryOnEditEnd(Item, NewRow, CancelEdit)
	ThisIsNewRow = False;
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

// Procedure - event handler OnChange of the Characteristic input field.
//
&AtClient
Procedure InventoryCharacteristicOnChange(Item)
	
	If ValueIsFilled(Object.PriceKind) Then
		
		TabularSectionRow = Items.Inventory.CurrentData;
		
		StructureData = New Structure;
		StructureData.Insert("ProcessingDate",	 Object.Date);
		StructureData.Insert("PriceKind",			 Object.PriceKind);
		StructureData.Insert("DocumentCurrency",	 Object.DocumentCurrency);
		StructureData.Insert("AmountIncludesVAT", Object.AmountIncludesVAT);
		
		StructureData.Insert("VATRate", 		 TabularSectionRow.VATRate);
		StructureData.Insert("Products",	 TabularSectionRow.Products);
		StructureData.Insert("Characteristic",	 TabularSectionRow.Characteristic);
		StructureData.Insert("MeasurementUnit", TabularSectionRow.MeasurementUnit);
		StructureData.Insert("Price",			 TabularSectionRow.Price);
		
		StructureData = GetDataCharacteristicOnChange(StructureData);
		
		TabularSectionRow.Price = StructureData.Price;
		
		CalculateAmountInTabularSectionLine();
		CalculateCommissionRemuneration(TabularSectionRow);
		
	EndIf;
	
EndProcedure

// Procedure - event handler OnChange of the Count input field.
//
&AtClient
Procedure InventoryQuantityOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	CalculateAmountInTabularSectionLine(TabularSectionRow);
	
	// Amount of the transfer.
	TabularSectionRow.TransmissionAmount = TabularSectionRow.TransmissionPrice * TabularSectionRow.Quantity;
	
	VATRate = DriveReUse.GetVATRateValue(TabularSectionRow.VATRate);
	
	// VAT amount of the transfer.
	TabularSectionRow.TransmissionVATAmount = ?(
		Object.AmountIncludesVAT,
		TabularSectionRow.TransmissionAmount - (TabularSectionRow.TransmissionAmount) / ((VATRate + 100) / 100),
		TabularSectionRow.TransmissionAmount * VATRate / 100
	);
	
	// Amount of brokerage
	CalculateCommissionRemuneration(TabularSectionRow);
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
	
	// Price.
	If StructureData.CurrentFactor <> 0 Then
		TabularSectionRow.Price = TabularSectionRow.Price * StructureData.Factor / StructureData.CurrentFactor;
	EndIf;
	
	CalculateAmountInTabularSectionLine();
	CalculateCommissionRemuneration(TabularSectionRow);
	
EndProcedure

// Procedure - event handler OnChange of the Price input field.
//
&AtClient
Procedure InventoryPriceOnChange(Item)
	
	CalculateAmountInTabularSectionLine();
	
	TabularSectionRow = Items.Inventory.CurrentData;
	CalculateCommissionRemuneration(TabularSectionRow);
	RecalculatePaymentCalendar();
	
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
	
	// VAT amount.
	CalculateVATSUM(TabularSectionRow);
	
	// Total.
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
	// Amount of brokerage
	CalculateCommissionRemuneration(TabularSectionRow);
	RecalculatePaymentCalendar();
	
EndProcedure

// Procedure - event handler OnChange of the VATRate input field.
//
&AtClient
Procedure InventoryVATRateOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	// VAT amount.
	CalculateVATSUM(TabularSectionRow);
	
	// Total.
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
	VATRate = DriveReUse.GetVATRateValue(TabularSectionRow.VATRate);
		
	// VAT amount of the transfer.
	TabularSectionRow.TransmissionVATAmount = ?(Object.AmountIncludesVAT,
												TabularSectionRow.TransmissionAmount - (TabularSectionRow.TransmissionAmount) / ((VATRate + 100) / 100),
												TabularSectionRow.TransmissionAmount * VATRate / 100);
	RecalculatePaymentCalendar();
	
EndProcedure

// Procedure - event handler OnChange of the VATRate input field.
//
&AtClient
Procedure InventoryVATAmountOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	// Total.
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	RecalculatePaymentCalendar();
	
EndProcedure

// Procedure - event handler OnChange of the TransmissionPrice input field.
//
&AtClient
Procedure InventoryTransferPriceOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	// Amount of the transfer.
	TabularSectionRow.TransmissionAmount = TabularSectionRow.Quantity * TabularSectionRow.TransmissionPrice;
	
	VATRate = DriveReUse.GetVATRateValue(TabularSectionRow.VATRate);
	
	// VAT amount of the transfer.
	TabularSectionRow.TransmissionVATAmount = ?(Object.AmountIncludesVAT,
												TabularSectionRow.TransmissionAmount - (TabularSectionRow.TransmissionAmount) / ((VATRate + 100) / 100),
												TabularSectionRow.TransmissionAmount * VATRate / 100);	
	
	// Amount of brokerage
	CalculateCommissionRemuneration(TabularSectionRow);
	
EndProcedure

// Procedure - event handler OnChange of the TransmissionAmount input field.
//
&AtClient
Procedure InventoryAmountTransferOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	// Price.
	If TabularSectionRow.Quantity <> 0 Then
		TabularSectionRow.TransmissionPrice = TabularSectionRow.TransmissionAmount / TabularSectionRow.Quantity;
	EndIf;
	
	// VAT amount of the transfer.
	VATRate = DriveReUse.GetVATRateValue(TabularSectionRow.VATRate);
		
	TabularSectionRow.TransmissionVATAmount = ?(Object.AmountIncludesVAT,
												TabularSectionRow.TransmissionAmount - (TabularSectionRow.TransmissionAmount) / ((VATRate + 100) / 100),
												TabularSectionRow.TransmissionAmount * VATRate / 100);	
	
	// Amount of brokerage
	CalculateCommissionRemuneration(TabularSectionRow);
	
EndProcedure

// Procedure - event handler OnChange of the BrokerageAmount input field.
//
&AtClient
Procedure InventoryBrokerageAmountOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	VATRate = DriveReUse.GetVATRateValue(Object.VATCommissionFeePercent);
		
	TabularSectionRow.BrokerageVATAmount = ?(Object.AmountIncludesVAT,
													TabularSectionRow.BrokerageAmount - (TabularSectionRow.BrokerageAmount) / ((VATRate + 100) / 100),
													TabularSectionRow.BrokerageAmount * VATRate / 100);	
	RecalculatePaymentCalendar();
	
EndProcedure

&AtClient
Procedure InventoryVATAmountRemunerationOnChange(Item)
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

#Region InteractiveActionResultHandlers

// Procedure-handler of the result of opening the "Prices and currencies" form
//
&AtClient
Procedure OpenPricesAndCurrencyFormEnd(ClosingResult, AdditionalParameters) Export
	
	If TypeOf(ClosingResult) = Type("Structure") 
		AND ClosingResult.WereMadeChanges Then
		
		Object.PriceKind = ClosingResult.PriceKind;
		Object.DocumentCurrency = ClosingResult.DocumentCurrency;
		Object.ExchangeRate = ClosingResult.PaymentsRate;
		Object.Multiplicity = ClosingResult.SettlementsMultiplicity;
		Object.VATTaxation = ClosingResult.VATTaxation;
		Object.AmountIncludesVAT = ClosingResult.AmountIncludesVAT;
		Object.IncludeVATInPrice = ClosingResult.IncludeVATInPrice;
		SettlementsCurrencyBeforeChange = AdditionalParameters.SettlementsCurrencyBeforeChange;
		
		// Recalculate prices by kind of prices.
		If ClosingResult.RefillPrices Then
			
			DriveClient.RefillTabularSectionPricesByPriceKind(ThisForm, "Inventory");
			
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
		
		// Amount of brokerage
		For Each TabularSectionRow In Object.Inventory Do
			
			CalculateCommissionRemuneration(TabularSectionRow);
			
		EndDo;
		
		For Each TabularSectionRow In Object.Prepayment Do
			
			TabularSectionRow.PaymentAmount = DriveClient.RecalculateFromCurrencyToCurrency(
				TabularSectionRow.SettlementsAmount,
				TabularSectionRow.ExchangeRate,
				?(
					Object.DocumentCurrency = FunctionalCurrency,
					RateNationalCurrency,
					Object.ExchangeRate
				),
				TabularSectionRow.Multiplicity,
				?(
					Object.DocumentCurrency = FunctionalCurrency,
					RepetitionNationalCurrency,
					Object.Multiplicity)
				);
				
		EndDo;
		
		UpdateColumnTotalAtClient(True);
		
	EndIf;
	
	LabelStructure = New Structure("PriceKind, DocumentCurrency, SettlementsCurrency, ExchangeRate, RateNationalCurrency, AmountIncludesVAT, ForeignExchangeAccounting, VATTaxation", 
		Object.PriceKind, 
		Object.DocumentCurrency, 
		SettlementsCurrency, 
		Object.ExchangeRate, 
		RateNationalCurrency, 
		Object.AmountIncludesVAT, 
		ForeignExchangeAccounting, 
		Object.VATTaxation);
		
	PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
	
	RecalculatePaymentCalendar();
	
EndProcedure

// Procedure-handler of the response to question about the necessity to set a new currency rate
//
&AtClient
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
				?(Object.DocumentCurrency = FunctionalCurrency, RepetitionNationalCurrency, Object.Multiplicity)
				);
				
		EndDo;
		
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
		
	EndIf;
	
EndProcedure

// Procedure-handler of the answer to the question about repeated advances offset
//
&AtClient
Procedure DefineAdvancePaymentOffsetsRefreshNeed(ClosingResult, AdditionalParameters) Export
	
	If ClosingResult = DialogReturnCode.Yes Then
		
		Object.Prepayment.Clear();
		
	Else
		
		Object.Contract = AdditionalParameters.ContractBeforeChange;
		Contract = AdditionalParameters.ContractBeforeChange;
		
		If AdditionalParameters.Property("CounterpartyBeforeChange") Then
			
			Counterparty = AdditionalParameters.CounterpartyBeforeChange;
			CounterpartyDoSettlementsByOrders = AdditionalParameters.CounterpartyDoSettlementsByOrdersBeforeChange;
			Object.Counterparty = AdditionalParameters.CounterpartyBeforeChange;
			Items.Contract.Visible = AdditionalParameters.ContractVisibleBeforeChange;
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Procedure-handler response on question about document recalculate by contract data
//
&AtClient
Procedure DefineDocumentRecalculateNeedByContractTerms(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		
		DriveClient.RefillTabularSectionPricesByPriceKind(ThisForm, "Inventory");
		
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

&AtClient
Procedure OpenSerialNumbersSelection()
	
	CurrentDataIdentifier = Items.Inventory.CurrentData.GetID();
	ParametersOfSerialNumbers = SerialNumberPickParameters(CurrentDataIdentifier);
	
	OpenForm("DataProcessor.SerialNumbersSelection.Form", ParametersOfSerialNumbers, ThisObject);
	
EndProcedure

&AtServer
Function GetSerialNumbersFromStorage(AddressInTemporaryStorage, RowKey)
	
	Modified = True;
	
	ParametersFieldNames = New Structure;
	ParametersFieldNames.Insert("FieldNameConnectionKey", "ConnectionKeySerialNumbers");
	
	Return WorkWithSerialNumbers.GetSerialNumbersFromStorage(Object, AddressInTemporaryStorage, RowKey, ParametersFieldNames);
	
EndFunction

&AtServer
Function SerialNumberPickParameters(CurrentDataIdentifier)
	
	Return WorkWithSerialNumbers.SerialNumberPickParameters(Object, ThisObject.UUID, CurrentDataIdentifier,
		False,,, "ConnectionKeySerialNumbers");
	
EndFunction

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

&AtServer
Procedure SetSwitchTypeListOfPaymentCalendar()
	
	If Object.PaymentCalendar.Count() > 1 Then
		SwitchTypeListOfPaymentCalendar = 1;
	Else
		SwitchTypeListOfPaymentCalendar = 0;
	EndIf;
	
EndProcedure

&AtClient
Procedure SetEnableGroupPaymentCalendarDetails()
	Items.GroupPaymentCalendarDetails.Enabled = Object.SetPaymentTerms;
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
		NewRow.PaymentAmount = AmountForPaymentCalendarAtServer();
		NewRow.PaymentVATAmount = VATForPaymentCalendarAtServer();
	EndIf;
	
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
	
	AmountForCorrectBalance = 0;
	VATForCorrectBalance = 0;
	
	TotalAmount = AmountForPaymentCalendarAtServer();
	TotalVAT = VATForPaymentCalendarAtServer();
	
	While DataSelection.Next() Do
		
		NewLine = Object.PaymentCalendar.Add();
		
		If DataSelection.Term = Enums.PaymentTerm.PaymentInAdvance Then
			NewLine.PaymentDate = Object.Date - DataSelection.DuePeriod * 86400;
		Else
			NewLine.PaymentDate = Object.Date + DataSelection.DuePeriod * 86400;
		EndIf;
		
		NewLine.PaymentPercentage = DataSelection.PaymentPercentage;
		NewLine.PaymentAmount = Round(TotalAmount * NewLine.PaymentPercentage / 100, 2, RoundMode.Round15as20);
		NewLine.PaymentVATAmount = Round(TotalVAT * NewLine.PaymentPercentage / 100, 2, RoundMode.Round15as20);
		
		AmountForCorrectBalance = AmountForCorrectBalance + NewLine.PaymentAmount;
		VATForCorrectBalance = VATForCorrectBalance + NewLine.PaymentVATAmount;
		
	EndDo;
	
	// correct balance
	NewLine.PaymentAmount = NewLine.PaymentAmount + (TotalAmount - AmountForCorrectBalance);
	NewLine.PaymentVATAmount = NewLine.PaymentVATAmount + (TotalVAT - VATForCorrectBalance);
	
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

&AtServer
Function VATForPaymentCalendarAtServer()
	
	If Object.KeepBackComissionFee Then
		VATForPaymentCalendar = Object.Inventory.Total("VATAmount") - Object.Inventory.Total("BrokerageVATAmount");
	Else
		VATForPaymentCalendar = Object.Inventory.Total("VATAmount")
	EndIf;
	
	Return VATForPaymentCalendar;
	
EndFunction

&AtServer
Function AmountForPaymentCalendarAtServer()
	
	InventoryTotal = Object.Inventory.Total("Total");
	
	If Object.KeepBackComissionFee Then
		AmountForPaymentCalendar = InventoryTotal - (Object.CommissionFeePercent * InventoryTotal / 100)
			- (Object.Inventory.Total("VATAmount") - Object.Inventory.Total("BrokerageVATAmount"));
	Else
		AmountForPaymentCalendar = Object.Inventory.Total("Amount");
	EndIf;
	
	Return AmountForPaymentCalendar;
	
EndFunction

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
		AmountForPaymentCalendar = InventoryTotal - (Object.CommissionFeePercent * InventoryTotal / 100)
			- (Object.Inventory.Total("VATAmount") - Object.Inventory.Total("BrokerageVATAmount"));
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

// Procedure recalculates subtotal the document on client.
&AtClient
Procedure RecalculateSubtotal()
	
	DocumentSubtotal = Object.Inventory.Total("Total") - Object.Inventory.Total("VATAmount");
	
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
	StructureData.Insert("InventoryTransferredGLAccount",	TabRow.InventoryTransferredGLAccount);
	StructureData.Insert("VATOutputGLAccount",				TabRow.VATOutputGLAccount);
	StructureData.Insert("RevenueGLAccount",				TabRow.RevenueGLAccount);
	StructureData.Insert("COGSGLAccount",					TabRow.COGSGLAccount);
	
EndProcedure

&AtServer
Procedure FillAddedColumns(GetGLAccounts = False)
	
	ObjectParameters = GLAccountsInDocumentsClientServer.GetObjectParameters(Object);
	
	Tables = New Array();
	
	TableInventory = GetStructureData(ObjectParameters);
	
	Tables.Add(TableInventory);
	
	GLAccountsInDocuments.FillGLAccountsInTable(Object, Tables, GetGLAccounts);
	
EndProcedure

&AtClientAtServerNoContext
Function GetStructureData(ObjectParameters, RowData = Undefined, ProductName = "Products") Export
	
	StructureData = New Structure("Products, InventoryTransferredGLAccount, VATOutputGLAccount, RevenueGLAccount,
				|COGSGLAccount, GLAccounts, GLAccountsFilled");	
	StructureData.Insert("ObjectParameters", ObjectParameters);
	StructureData.Insert("TabName", "Inventory");
	StructureData.Insert("ProductName", ProductName);
	
	Return StructureData;

EndFunction

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

#EndRegion

#Region Initialize

ThisIsNewRow = False;

#EndRegion