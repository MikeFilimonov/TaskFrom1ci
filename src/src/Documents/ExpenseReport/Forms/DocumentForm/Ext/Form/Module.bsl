#Region GeneralPurposeProceduresAndFunctions

// Procedure calls the data processor for document filling by basis.
//
&AtServer
Procedure FillByDocument(BasisDocument)
	
	Document = FormAttributeToValue("Object");
	Document.Fill(BasisDocument);
	ValueToFormAttribute(Document, "Object");
	Modified = True;
	
	StructureByCurrency = InformationRegisters.ExchangeRates.GetLast(Object.Date, New Structure("Currency", Object.DocumentCurrency));
	Object.ExchangeRate = ?(
		StructureByCurrency.ExchangeRate = 0,
		1,
		StructureByCurrency.ExchangeRate
	);
	Object.Multiplicity = ?(
		StructureByCurrency.ExchangeRate = 0,
		1,
		StructureByCurrency.Multiplicity
	);
	
EndProcedure

// The function moves the AdvancesPaid tabular section
// to the temporary storage and returns the address
//
&AtServer
Function PlaceAdvancesPaidToStorage()
	
	Return PutToTempStorage(
		Object.AdvancesPaid.Unload(,
			"Document, Amount"
		),
		UUID
	);
	
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
		
		If BarcodeData <> Undefined
		   AND BarcodeData.Count() <> 0 Then
			
			StructureProductsData = New Structure();
			StructureProductsData.Insert("Company", StructureData.Company);
			StructureProductsData.Insert("Products", BarcodeData.Products);
			StructureProductsData.Insert("Characteristic", BarcodeData.Characteristic);
			StructureProductsData.Insert("VATTaxation", StructureData.VATTaxation);
			BarcodeData.Insert("StructureProductsData", GetDataProductsOnChange(StructureProductsData));
			
			If Not ValueIsFilled(BarcodeData.MeasurementUnit) Then
				BarcodeData.MeasurementUnit  = BarcodeData.Products.MeasurementUnit;
			EndIf;
			
		EndIf;
		
	EndDo;
	
	StructureData.Insert("DataByBarCodes", DataByBarCodes);
	
EndProcedure

// Procedure processes the received barcodes.
//
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
	StructureData.Insert("Date", Object.Date);
	StructureData.Insert("DocumentCurrency", Object.DocumentCurrency);
	StructureData.Insert("VATTaxation", Object.VATTaxation);
	StructureData.Insert("AmountIncludesVAT", Object.AmountIncludesVAT);
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

// The function receives the AdvancesPaid tabular section from the temporary storage.
//
&AtServer
Procedure GetAdvancesPaidFromStorage(AddressAdvancesPaidInStorage)
	
	TableAdvancesPaid = GetFromTempStorage(AddressAdvancesPaidInStorage);
	Object.AdvancesPaid.Clear();
	For Each StringAdvancesPaid In TableAdvancesPaid Do
		String = Object.AdvancesPaid.Add();
		FillPropertyValues(String, StringAdvancesPaid);
	EndDo;
	
EndProcedure

// The procedure calculates the rate and ratio of
// the document currency when changing the document date.
//
&AtClient
Procedure RecalculateRateRepetitionOfDocumentCurrency(StructureData)
	
	NewExchangeRate = ?(StructureData.CurrencyRateRepetition.ExchangeRate = 0, 1, StructureData.CurrencyRateRepetition.ExchangeRate);
	NewRatio = ?(StructureData.CurrencyRateRepetition.Multiplicity = 0, 1, StructureData.CurrencyRateRepetition.Multiplicity);
	
	If Object.ExchangeRate <> NewExchangeRate
		OR Object.Multiplicity <> NewRatio Then
		
		CurrencyRateInLetters = String(Object.Multiplicity) + " " + TrimAll(Object.DocumentCurrency) + " = " + String(Object.ExchangeRate) + " " + TrimAll(FunctionalCurrency);
		RateNewCurrenciesInLetters = String(NewRatio) + " " + TrimAll(Object.DocumentCurrency) + " = " + String(NewExchangeRate) + " " + TrimAll(FunctionalCurrency);
		
		MessageText = NStr("en = 'On the document date, the document currency (%1) exchange rate was specified.
		                   |Set document rate (%1) according to exchange rate?'");
		
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessageText, CurrencyRateInLetters); 
		
		Mode = QuestionDialogMode.YesNo;
		Response = Undefined;

		ShowQueryBox(New NotifyDescription("CalculateRateDocumentCurrencyRatioEnd", ThisObject, New Structure("NewUnitConversionFactor, NewExchangeRate", NewRatio, NewExchangeRate)), MessageText, Mode, 0);
		Return;
		
	EndIf;
	
	// Generate price and currency label.
	CalculateRateDocumentCurrencyRatioFragment();
EndProcedure

&AtClient
Procedure CalculateRateDocumentCurrencyRatioEnd(Result, AdditionalParameters) Export
	
	NewRatio = AdditionalParameters.NewRatio;
	NewExchangeRate = AdditionalParameters.NewExchangeRate;
	
	
	Response = Result;
	
	If Response = DialogReturnCode.Yes Then
		
		Object.ExchangeRate = NewExchangeRate;
		Object.Multiplicity = NewRatio;
		
	EndIf;
	
	
	CalculateRateDocumentCurrencyRatioFragment();

EndProcedure

&AtClient
Procedure CalculateRateDocumentCurrencyRatioFragment()
	
	Var LabelStructure;
	
	LabelStructure = New Structure("DocumentCurrency, ExchangeRate, AmountIncludesVAT, ForeignExchangeAccounting, VATTaxation", Object.DocumentCurrency, Object.ExchangeRate, Object.AmountIncludesVAT, ForeignExchangeAccounting, Object.VATTaxation);
	DocumentCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);

EndProcedure

// Procedure recalculates in the document tabular section after making
// changes in the "Prices and currency" form. The columns are
// recalculated as follows: price, discount, amount, VAT amount, total amount.
//
&AtClient
Procedure ProcessChangesOnButtonEditCurrency()
	
	ParametersStructure = New Structure();
	
	ParametersStructure.Insert("DocumentDate",					Object.Date);
	ParametersStructure.Insert("DocumentCurrency",				Object.DocumentCurrency);
	ParametersStructure.Insert("VATTaxation",					Object.VATTaxation);
	ParametersStructure.Insert("AmountIncludesVAT",				Object.AmountIncludesVAT);
	ParametersStructure.Insert("IncludeVATInPrice",				Object.IncludeVATInPrice);
	ParametersStructure.Insert("RecalculatePricesByCurrency",	False);
	ParametersStructure.Insert("ExchangeRate",					Object.ExchangeRate);
	ParametersStructure.Insert("Multiplicity",					Object.Multiplicity);
	ParametersStructure.Insert("ReverseChargeNotApplicable", True);
	
	ReturnStructure = Undefined;
	
	OpenForm("CommonForm.CurrencyForm", ParametersStructure,,,,, 
		New NotifyDescription("ProcessChangesOnEditCurrencyButtonEnd", 
		ThisObject, New Structure("ParametersStructure", ParametersStructure)));
	
EndProcedure

&AtClient
Procedure ProcessChangesOnEditCurrencyButtonEnd(Result, AdditionalParameters) Export
	
	ParametersStructure = AdditionalParameters.ParametersStructure;
	
	ReturnStructure = Result;
	
	If Not ValueIsFilled(ReturnStructure)
		OR Not ReturnStructure.WereMadeChanges
		OR ReturnStructure.DialogReturnCode = DialogReturnCode.Cancel Then
		Return;
	EndIf;
	
	FillPropertyValues(Object, ReturnStructure);
	
	// Clearing the tabular section of the issued advances.
	If ParametersStructure.DocumentCurrency <> ReturnStructure.DocumentCurrency Then
		Object.AdvancesPaid.Clear();
	EndIf;
	
	// Recalculate prices by currency.
	If ReturnStructure.RecalculatePricesByCurrency Then
		DriveClient.RecalculateTabularSectionPricesByCurrency(ThisForm, ParametersStructure.DocumentCurrency, "Inventory");
		DriveClient.RecalculateTabularSectionPricesByCurrency(ThisForm, ParametersStructure.DocumentCurrency, "Expenses");
	EndIf;
	
	// Recalculate the amount if VAT taxation flag is changed.
	If Not ReturnStructure.VATTaxation = ReturnStructure.PrevVATTaxation Then
		FillVATRateByVATTaxation();
	EndIf;
	
	// Recalculate the amount if the "Amount includes VAT" flag is changed.
	If Not Object.AmountIncludesVAT = ParametersStructure.AmountIncludesVAT Then
		DriveClient.RecalculateTabularSectionAmountByFlagAmountIncludesVAT(ThisForm, "Inventory");
		DriveClient.RecalculateTabularSectionAmountByFlagAmountIncludesVAT(ThisForm, "Expenses");
	EndIf;
	
	For Each RowPayment In Object.Payments Do
		CalculatePaymentSUM(RowPayment);
	EndDo;
	
	SpentTotalAmount = Object.Inventory.Total("Total") + Object.Expenses.Total("Total") + Object.Payments.Total("PaymentAmount");
	
	// Generate price and currency label.
	LabelStructure = New Structure("DocumentCurrency, ExchangeRate, AmountIncludesVAT, ForeignExchangeAccounting, VATTaxation", Object.DocumentCurrency, Object.ExchangeRate, Object.AmountIncludesVAT, ForeignExchangeAccounting, Object.VATTaxation);
	DocumentCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);

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

// Recalculate a payment amount in the passed tabular section string.
//
&AtClient
Procedure CalculatePaymentSUM(TabularSectionRow)
	
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
		Object.ExchangeRate,
		TabularSectionRow.Multiplicity,
		Object.Multiplicity
	);
	
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
	SpentTotalAmount = Object.Inventory.Total("Total") + Object.Expenses.Total("Total") + Object.Payments.Total("PaymentAmount");
	
EndProcedure

// It receives data set from server for the ContractOnChange procedure.
//
&AtServerNoContext
Function GetDataDateOnChange(DocumentRef, DateNew, DateBeforeChange, DocumentCurrency)
	
	DATEDIFF = DriveServer.CheckDocumentNumber(DocumentRef, DateNew, DateBeforeChange);
	CurrencyRateRepetition = InformationRegisters.ExchangeRates.GetLast(DateNew, New Structure("Currency", DocumentCurrency));
	
	StructureData = New Structure();
	
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
Function GetCompanyDataOnChange(Company)
	
	StructureData = New Structure();
	
	StructureData.Insert(
		"ParentCompany",
		DriveServer.GetCompany(Company)
	);
	
	TaxationBeforeChange = Object.VATTaxation;
	
	Object.VATTaxation = DriveServer.VATTaxation(Object.Company, Object.Date);
	
	If Not TaxationBeforeChange = Object.VATTaxation Then
		FillVATRateByVATTaxation();
	EndIf;
	
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
		
		Items.ExpencesVATRate.Visible = True;
		Items.ExpencesAmountVAT.Visible = True;
		Items.TotalExpences.Visible = True;
		
		For Each TabularSectionRow In Object.Expenses Do
			
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
		
		Items.ExpencesVATRate.Visible = False;
		Items.ExpencesAmountVAT.Visible = False;
		Items.TotalExpences.Visible = False;
		
		For Each TabularSectionRow In Object.Expenses Do
		
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
	
	StructureData.Insert("ClearOrderAndDepartment", False);
	StructureData.Insert("ClearBusinessLine", False);
	
	If StructureData.Products.ExpensesGLAccount.TypeOfAccount <> Enums.GLAccountsTypes.Expenses
	   AND StructureData.Products.ExpensesGLAccount.TypeOfAccount <> Enums.GLAccountsTypes.Revenue
	   AND StructureData.Products.ExpensesGLAccount.TypeOfAccount <> Enums.GLAccountsTypes.WorkInProcess
	   AND StructureData.Products.ExpensesGLAccount.TypeOfAccount <> Enums.GLAccountsTypes.IndirectExpenses Then
		StructureData.ClearOrderAndDepartment = True;
	EndIf;
	
	If StructureData.Products.ExpensesGLAccount.TypeOfAccount <> Enums.GLAccountsTypes.Expenses
	   AND StructureData.Products.ExpensesGLAccount.TypeOfAccount <> Enums.GLAccountsTypes.CostOfSales
	   AND StructureData.Products.ExpensesGLAccount.TypeOfAccount <> Enums.GLAccountsTypes.Revenue Then
		StructureData.ClearBusinessLine = True;
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

// It receives data set from server for the ContractOnChange procedure.
//
&AtServerNoContext
Function GetPaymentDataContractOnChange(Date, Contract)
	
	StructureData = New Structure;
	
	StructureData.Insert(
		"ContractCurrencyRateRepetition",
		InformationRegisters.ExchangeRates.GetLast(
			Date,
			New Structure("Currency", Contract.SettlementsCurrency)
		)
	);
	
	Return StructureData;
	
EndFunction

// It receives data set from the server for the CounterpartyOnChange procedure.
//
&AtServer
Function GetDataCounterpartyOnChange(Date, Counterparty, Company)
	
	StructureData = New Structure;
	
	Contract = Counterparty.ContractByDefault;
	StructureData.Insert("Contract", Contract);
	
	StructureData.Insert("DoOperationsByContracts", Counterparty.DoOperationsByContracts);
	StructureData.Insert("DoOperationsByDocuments", Counterparty.DoOperationsByDocuments);
	StructureData.Insert("DoOperationsByOrders", Counterparty.DoOperationsByOrders);
	
	StructureData.Insert(
		"ContractCurrencyRateRepetition",
		InformationRegisters.ExchangeRates.GetLast(
			Date,
			New Structure("Currency", Contract.SettlementsCurrency)
		)
	);
	
	SetAccountsAttributesVisible(
		Counterparty.DoOperationsByContracts,
		Counterparty.DoOperationsByDocuments,
		Counterparty.DoOperationsByOrders
	);
	
	Return StructureData;
	
EndFunction

// Gets the data set from the server for procedure MeasurementUnitOnChange.
//
&AtServerNoContext
Function GetDataBusinessLineStartChoice(Products)
	
	StructureData = New Structure;
	
	AvailabilityOfPointingLinesOfBusiness = True;
	
	If Products.ExpensesGLAccount.TypeOfAccount <> Enums.GLAccountsTypes.Expenses
	   AND Products.ExpensesGLAccount.TypeOfAccount <> Enums.GLAccountsTypes.CostOfSales
	   AND Products.ExpensesGLAccount.TypeOfAccount <> Enums.GLAccountsTypes.Revenue Then
		AvailabilityOfPointingLinesOfBusiness = False;
	EndIf;
	
	StructureData.Insert("AvailabilityOfPointingLinesOfBusiness", AvailabilityOfPointingLinesOfBusiness);
	
	Return StructureData;
	
EndFunction

&AtServerNoContext
// Gets the data set from the server for procedure MeasurementUnitOnChange.
//
Function GetDataBusinessUnitstartChoice(Products)
	
	StructureData = New Structure;
	
	AbilityToSpecifyDepartments = True;
	
	If Products.ExpensesGLAccount.TypeOfAccount <> Enums.GLAccountsTypes.Expenses
	   AND Products.ExpensesGLAccount.TypeOfAccount <> Enums.GLAccountsTypes.Revenue
	   AND Products.ExpensesGLAccount.TypeOfAccount <> Enums.GLAccountsTypes.WorkInProcess
	   AND Products.ExpensesGLAccount.TypeOfAccount <> Enums.GLAccountsTypes.IndirectExpenses Then
		AbilityToSpecifyDepartments = False;
	EndIf;
	
	StructureData.Insert("AbilityToSpecifyDepartments", AbilityToSpecifyDepartments);
	
	Return StructureData;
	
EndFunction

&AtServerNoContext
// Gets the data set from the server for procedure MeasurementUnitOnChange.
//
Function GetDataOrderStartChoice(Products)
	
	StructureData = New Structure;
	
	AbilityToSpecifyOrder = True;
	
	If Products.ExpensesGLAccount.TypeOfAccount <> Enums.GLAccountsTypes.Expenses
	   AND Products.ExpensesGLAccount.TypeOfAccount <> Enums.GLAccountsTypes.Revenue
	   AND Products.ExpensesGLAccount.TypeOfAccount <> Enums.GLAccountsTypes.WorkInProcess
	   AND Products.ExpensesGLAccount.TypeOfAccount <> Enums.GLAccountsTypes.IndirectExpenses Then
		AbilityToSpecifyOrder = False;
	EndIf;
	
	StructureData.Insert("AbilityToSpecifyOrder", AbilityToSpecifyOrder);
	
	Return StructureData;
	
EndFunction

// Procedure fills out the service attributes.
//
&AtServerNoContext
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
	|SELECT ALLOWED
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

#Region WorkWithSelection

// Procedure - event handler Action of the Pick command
//
&AtClient
Procedure InventoryPick(Command)
	
	TabularSectionName	= "Inventory";
	DocumentPresentaion	= NStr("en = 'expense claim'");
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

// Procedure - event handler Action of the Pick command
//
&AtClient
Procedure ExpensesPick(Command)
	
	TabularSectionName	= "Expenses";
	DocumentPresentaion	= NStr("en = 'expense claim'");
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

// Procedure - event handler Action of the Pick command
//
&AtClient
Procedure AdvancesPick(Command)
	
	AddressAdvancesPaidInStorage = PlaceAdvancesPaidToStorage();
	
	SelectionParameters = New Structure(
		"AddressAdvancesPaidInStorage,
		|ParentCompany,
		|Period,
		|Employee,
		|DocumentCurrency,
		|Refs",
		AddressAdvancesPaidInStorage,
		ParentCompany,
		Object.Date,
		Object.Employee,
		Object.DocumentCurrency,
		Object.Ref
	);
	
	Result = Undefined;

	
	OpenForm("CommonForm.SelectAdvancesIssuedToTheAdvanceHolder", SelectionParameters,,,,, New NotifyDescription("AdvancesFilterEnd", ThisObject, New Structure("AddressAdvancesPaidInStorage", AddressAdvancesPaidInStorage)));
	
EndProcedure

&AtClient
Procedure AdvancesFilterEnd(Result1, AdditionalParameters) Export
	
	AddressAdvancesPaidInStorage = AdditionalParameters.AddressAdvancesPaidInStorage;
	
	
	Result = Result1;
	If Result = DialogReturnCode.OK Then
		GetAdvancesPaidFromStorage(AddressAdvancesPaidInStorage);
		
	EndIf;

EndProcedure

// Function gets a product list from the temporary storage
//
&AtServer
Procedure GetInventoryFromStorage(InventoryAddressInStorage, TabularSectionName, AreCharacteristics, AreBatches)
	
	TableForImport = GetFromTempStorage(InventoryAddressInStorage);
	
	For Each ImportRow In TableForImport Do
		
		NewRow = Object[TabularSectionName].Add();
		FillPropertyValues(NewRow, ImportRow);
		
		If TabularSectionName = "Inventory" Then
			
			NewRow.StructuralUnit = MainWarehouse;
			
		EndIf;
		
		If TabularSectionName = "Expenses" Then
			
			NewRow.StructuralUnit = MainDepartment;
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Procedure - handler of clicking the button "Fill in by basis".
//
&AtClient
Procedure FillByBasis(Command)
	
	If Not ValueIsFilled(Object.BasisDocument) Then
		ShowMessageBox(Undefined, NStr("en = 'Please select a base document.'"));
		Return;
	EndIf;
	
	Response = Undefined;

	
	ShowQueryBox(New NotifyDescription("FillByBasisEnd", ThisObject), NStr("en = 'Do you want to refill the expense report?'"), QuestionDialogMode.YesNo, 0);
	
EndProcedure

&AtClient
Procedure FillByBasisEnd(Result, AdditionalParameters) Export
	
	Response = Result;
	If Response = DialogReturnCode.Yes Then
		FillByDocument(Object.BasisDocument);
		
		ParentCompany = DriveServer.GetCompany(Object.Company);
		SpentTotalAmount = Object.Inventory.Total("Total") + Object.Expenses.Total("Total") + Object.Payments.Total("PaymentAmount");
		
		LabelStructure = New Structure("DocumentCurrency, ExchangeRate, AmountIncludesVAT, ForeignExchangeAccounting, VATTaxation", Object.DocumentCurrency, Object.ExchangeRate, Object.AmountIncludesVAT, ForeignExchangeAccounting, Object.VATTaxation);
		DocumentCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
		
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

// Procedure of processing the results of selection closing
//
&AtClient
Procedure OnCloseSelection(ClosingResult, AdditionalParameters) Export
	
	If TypeOf(ClosingResult) = Type("Structure") Then
		
		If Not IsBlankString(ClosingResult.CartAddressInStorage) Then
			
			InventoryAddressInStorage	= ClosingResult.CartAddressInStorage;
			CurrentPagesInventory		= (Items.Pages.CurrentPage = Items.Products);
			TabularSectionName			= ?(CurrentPagesInventory, "Inventory", "Expenses");
			
			GetInventoryFromStorage(InventoryAddressInStorage, TabularSectionName, CurrentPagesInventory, CurrentPagesInventory);
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

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
		PostingIsAllowed
	);
	
	FunctionalCurrency = Constants.FunctionalCurrency.Get();
	
	If Parameters.Key.IsEmpty() Then
		
		If Not ValueIsFilled(Object.DocumentCurrency) Then
			Object.DocumentCurrency = FunctionalCurrency;
		EndIf;
		
	EndIf;
	
	// Form attributes setting.
	DocumentDate = Object.Date;
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentDate();
	EndIf;
	
	ParentCompany = DriveServer.GetCompany(Object.Company);

	Object.VATTaxation = DriveServer.VATTaxation(Object.Company, DocumentDate);
	
	If Not ValueIsFilled(Object.Ref)
		AND Not ValueIsFilled(Parameters.Basis) 
		AND Not ValueIsFilled(Parameters.CopyingValue) Then
		FillVATRateByVATTaxation();
	ElsIf Object.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then	
		Items.InventoryVATRate.Visible = True;
		Items.InventoryVATAmount.Visible = True;
		Items.InventoryAmountTotal.Visible = True;
		Items.ExpencesVATRate.Visible = True;
		Items.ExpencesAmountVAT.Visible = True;
		Items.TotalExpences.Visible = True;
	Else
		Items.InventoryVATRate.Visible = False;
		Items.InventoryVATAmount.Visible = False;
		Items.InventoryAmountTotal.Visible = False;
		Items.ExpencesVATRate.Visible = False;
		Items.ExpencesAmountVAT.Visible = False;
		Items.TotalExpences.Visible = False;
	EndIf;
	
	// Generate price and currency label.
	ForeignExchangeAccounting = Constants.ForeignExchangeAccounting.Get();
	LabelStructure = New Structure("DocumentCurrency, ExchangeRate, AmountIncludesVAT, ForeignExchangeAccounting, VATTaxation", Object.DocumentCurrency, Object.ExchangeRate, Object.AmountIncludesVAT, ForeignExchangeAccounting, Object.VATTaxation);
	DocumentCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
	
	User = Users.CurrentUser();
	
	SettingValue = DriveReUse.GetValueByDefaultUser(User, "MainWarehouse");
	MainWarehouse = ?(ValueIsFilled(SettingValue), SettingValue, Catalogs.BusinessUnits.MainWarehouse);
	
	SettingValue = DriveReUse.GetValueByDefaultUser(User, "MainDepartment");
	MainDepartment = ?(ValueIsFilled(SettingValue), SettingValue, Catalogs.BusinessUnits.MainDepartment);
	
	SpentTotalAmount = Object.Inventory.Total("Total") + Object.Expenses.Total("Total") + Object.Payments.Total("PaymentAmount");
	
	Items.InventoryInventoryPick.Visible = AccessRight("Read", Metadata.AccumulationRegisters.Inventory);
	Items.ExpensesExpensesSelection.Visible = AccessRight("Read", Metadata.AccumulationRegisters.Inventory);
	
	// Filling in the additional attributes of tabular section.
	SetAccountsAttributesVisible();
	
	DriveClientServer.SetPictureForComment(Items.Additionally, Object.Comment);
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.DataImportFromExternalSources
	DataImportFromExternalSources.OnCreateAtServer(Metadata.Documents.ExpenseReport.TabularSections.Inventory, DataLoadSettings, ThisObject);
	// End StandardSubsystems.DataImportFromExternalSource
	
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
	
	Items.InventoryDataImportFromExternalSources.Visible = AccessRight("Use", Metadata.DataProcessors.DataImportFromExternalSources);
	
EndProcedure

// Procedure - OnReadAtServer event handler.
//
&AtServer
Procedure OnReadAtServer(CurrentObject)
	
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
	
	// Notification of payment.
	NotifyAboutOrderPayment = False;
	
	For Each CurRow In Object.Payments Do
		NotifyAboutOrderPayment = ?(
			NotifyAboutOrderPayment,
			NotifyAboutOrderPayment,
			ValueIsFilled(CurRow.Order)
		);
	EndDo;
	
	If NotifyAboutOrderPayment Then
		Notify("NotificationAboutOrderPayment");
	EndIf;
	
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
		AND ValueIsFilled(Parameter) Then
			
		For Each CurRow In Object.Payments Do
			
			If Parameter = CurRow.Counterparty Then
				
				SetAccountsAttributesVisible();
				Break;
				
			EndIf;
			
		EndDo;
			
	EndIf;
	
EndProcedure

// Procedure - EditDocumentCurrency command handler.
//
&AtClient
Procedure EditDocumentCurrency(Item, StandardProcessing)
	
	StandardProcessing = False;
	ProcessChangesOnButtonEditCurrency();
	Modified = True;
	
EndProcedure

#EndRegion

#Region ProcedureEventHandlersOfHeaderAttributes

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
		StructureData = GetDataDateOnChange(Object.Ref, Object.Date, DateBeforeChange, Object.DocumentCurrency);
		If StructureData.DATEDIFF <> 0 Then
			Object.Number = "";
		EndIf;
		
		If ValueIsFilled(Object.DocumentCurrency) Then
			RecalculateRateRepetitionOfDocumentCurrency(StructureData);
		EndIf;	
		
	EndIf;
	
EndProcedure

// Procedure - event handler OnChange of the Company input field.
// In procedure the document number
// is cleared, and also the form functional options are configured.
// Overrides the corresponding form parameter.
//
&AtClient
Procedure CompanyOnChange(Item)
	
	// Company change event data processor.
	Object.Number = "";
	StructureData = GetCompanyDataOnChange(Object.Company);
	ParentCompany = StructureData.ParentCompany;	
	
	LabelStructure = New Structure("DocumentCurrency, ExchangeRate, AmountIncludesVAT, ForeignExchangeAccounting, VATTaxation", 
		Object.DocumentCurrency, Object.ExchangeRate, Object.AmountIncludesVAT, ForeignExchangeAccounting, Object.VATTaxation);

	DocumentCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
	
EndProcedure

// Procedure - OnChange event handler of the Comment input field.
//
&AtClient
Procedure CommentOnChange(Item)
	
	AttachIdleHandler("Attachable_SetPictureForComment", 0.5, True);
	
EndProcedure

&AtClient
Procedure Attachable_SetPictureForComment()
	
	DriveClientServer.SetPictureForComment(Items.Additionally, Object.Comment);
	
EndProcedure

#Region TablePartsAttributeEventHandlers

// Procedure - SelectionStart event handler of the Document input field.
//
&AtClient
Procedure AdvancesPaidDocumentStartChoice(Item, ChoiceData, StandardProcessing)
	
	If Not ValueIsFilled(Object.Employee) Then
		MessageText = NStr("en = 'Please select an employee.'");
		ShowMessageBox(Undefined,MessageText);
		StandardProcessing = False;
	EndIf;
	
EndProcedure

// Procedure - OnStartEdit event handler of the Inventory list string.
//
&AtClient
Procedure InventoryOnStartEdit(Item, NewRow, Copy)
	
	If NewRow Then 
		TabularSectionRow = Items.Inventory.CurrentData;
		TabularSectionRow.StructuralUnit = MainWarehouse;
	EndIf;
	
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
	
	StructureData = GetDataProductsOnChange(StructureData);
	
	TabularSectionRow.MeasurementUnit = StructureData.MeasurementUnit;
	TabularSectionRow.Quantity = 1;
	TabularSectionRow.VATRate = StructureData.VATRate;
	TabularSectionRow.Content = "";
	
	CalculateAmountInTabularSectionLine(TabularSectionRow);
	
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
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	CalculateAmountInTabularSectionLine(TabularSectionRow);
	
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
	
	CalculateAmountInTabularSectionLine(TabularSectionRow);
	
EndProcedure

// Procedure - event handler OnChange of the Price input field.
//
&AtClient
Procedure InventoryPriceOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	CalculateAmountInTabularSectionLine(TabularSectionRow);
	
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
	SpentTotalAmount = Object.Inventory.Total("Total") + Object.Expenses.Total("Total") + Object.Payments.Total("PaymentAmount");
	
EndProcedure

// Procedure - event handler OnChange of the VATRate input field.
//
&AtClient
Procedure InventoryVATRateOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	CalculateVATSUM(TabularSectionRow);
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	SpentTotalAmount = Object.Inventory.Total("Total") + Object.Expenses.Total("Total") + Object.Payments.Total("PaymentAmount");
	
EndProcedure

// Procedure - event handler OnChange of the VATRate input field.
//
&AtClient
Procedure InventoryVATAmountOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	SpentTotalAmount = Object.Inventory.Total("Total") + Object.Expenses.Total("Total") + Object.Payments.Total("PaymentAmount");
	
EndProcedure

// Procedure - event handler AfterDeletion of the Inventory list row.
//
&AtClient
Procedure InventoryAfterDeleteRow(Item)
	
	SpentTotalAmount = Object.Inventory.Total("Total") + Object.Expenses.Total("Total") + Object.Payments.Total("PaymentAmount");
	
EndProcedure

// Procedure - event handler OnStartEdit of the Expenses list row.
//
&AtClient
Procedure ExpensesOnStartEdit(Item, NewRow, Copy)
	
	If NewRow Then
		TabularSectionRow = Items.Expenses.CurrentData;
		TabularSectionRow.StructuralUnit = MainDepartment;
	EndIf;	
	
EndProcedure

// Procedure - event handler OnChange of the Products input field.
//
&AtClient
Procedure ExpensesProductsOnChange(Item)
	
	TabularSectionRow = Items.Expenses.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("Company", Object.Company);
	StructureData.Insert("Products", TabularSectionRow.Products);
	StructureData.Insert("VATTaxation", Object.VATTaxation);
	
	StructureData = GetDataProductsOnChange(StructureData);
	
	TabularSectionRow.MeasurementUnit = StructureData.MeasurementUnit;
	TabularSectionRow.Quantity = 1;
	TabularSectionRow.VATRate = StructureData.VATRate;
	TabularSectionRow.Content = "";
	
	If StructureData.ClearOrderAndDepartment Then
		TabularSectionRow.StructuralUnit = Undefined;
		TabularSectionRow.SalesOrder = Undefined;
	EndIf;
	
	If StructureData.ClearBusinessLine Then
		TabularSectionRow.BusinessLine = Undefined;
	EndIf;
	
	CalculateAmountInTabularSectionLine(TabularSectionRow);
	
EndProcedure

// Procedure - event handler AutoPick of the Content input field.
//
&AtClient
Procedure CostsContentAutoComplete(Item, Text, ChoiceData, Parameters, Wait, StandardProcessing)
	
	If Wait = 0 Then
		
		StandardProcessing = False;
		
		TabularSectionRow = Items.Expenses.CurrentData;
		ContentPattern = DriveServer.GetContentText(TabularSectionRow.Products);
		
		ChoiceData = New ValueList;
		ChoiceData.Add(ContentPattern);
		
	EndIf;
	
EndProcedure

// Procedure - event handler OnChange of the Count input field.
//
&AtClient
Procedure ExpensesQuantityOnChange(Item)
	
	TabularSectionRow = Items.Expenses.CurrentData;
	
	CalculateAmountInTabularSectionLine(TabularSectionRow);
	
EndProcedure

// Procedure - event handler ChoiceProcessing of the MeasurementUnit input field.
//
&AtClient
Procedure ExpensesMeasurementUnitChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	TabularSectionRow = Items.Expenses.CurrentData;
	
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
	
	CalculateAmountInTabularSectionLine(TabularSectionRow);
	
EndProcedure

// Procedure - event handler OnChange of the Price input field.
//
&AtClient
Procedure ExpensesPriceOnChange(Item)
	
	TabularSectionRow = Items.Expenses.CurrentData;
	
	CalculateAmountInTabularSectionLine(TabularSectionRow);
	
EndProcedure

// Procedure - event handler OnChange of the Amount input field.
//
&AtClient
Procedure AmountExpensesOnChange(Item)
	
	TabularSectionRow = Items.Expenses.CurrentData;
	
	// Price.
	If TabularSectionRow.Quantity <> 0 Then
		TabularSectionRow.Price = TabularSectionRow.Amount / TabularSectionRow.Quantity;
	EndIf;
	
	CalculateVATSUM(TabularSectionRow);
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	SpentTotalAmount = Object.Inventory.Total("Total") + Object.Expenses.Total("Total") + Object.Payments.Total("PaymentAmount");
	
EndProcedure

// Procedure - event handler OnChange of the VATRate input field.
//
&AtClient
Procedure ExpensesVATRateOnChange(Item)
	
	TabularSectionRow = Items.Expenses.CurrentData;
	
	CalculateVATSUM(TabularSectionRow);
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	SpentTotalAmount = Object.Inventory.Total("Total") + Object.Expenses.Total("Total") + Object.Payments.Total("PaymentAmount");
	
EndProcedure

// Procedure - event handler OnChange of the VATRate input field.
//
&AtClient
Procedure AmountExpensesVATOnChange(Item)
	
	TabularSectionRow = Items.Expenses.CurrentData;
	
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	SpentTotalAmount = Object.Inventory.Total("Total") + Object.Expenses.Total("Total") + Object.Payments.Total("PaymentAmount");
	
EndProcedure

// Procedure - SelectionStart event handler of the ExpensesBusinessLine input field.
//
&AtClient
Procedure ExpensesBusinessLineStartChoice(Item, ChoiceData, StandardProcessing)
	
	TabularSectionRow = Items.Expenses.CurrentData;
	
	StructureData = GetDataBusinessLineStartChoice(TabularSectionRow.Products);
	
	If Not StructureData.AvailabilityOfPointingLinesOfBusiness Then
		ShowMessageBox(, NStr("en = 'Business area is not required for this type of expense.'"));
		StandardProcessing = False;
	EndIf;
	
EndProcedure

&AtClient
// Procedure - event handler SelectionStart of the StructuralUnit input field.
//
Procedure ExpensesBusinessUnitstartChoice(Item, ChoiceData, StandardProcessing)
	
	TabularSectionRow = Items.Expenses.CurrentData;
	
	StructureData = GetDataBusinessUnitstartChoice(TabularSectionRow.Products);
	
	If Not StructureData.AbilityToSpecifyDepartments Then
		ShowMessageBox(, NStr("en = 'Department is not required for this kind of expense.'"));
		StandardProcessing = False;
	EndIf;
	
EndProcedure

&AtClient
// Procedure - event handler SelectionStart of input field Order.
//
Procedure ExpensesOrderStartChoice(Item, ChoiceData, StandardProcessing)
	
	TabularSectionRow = Items.Expenses.CurrentData;
	
	StructureData = GetDataOrderStartChoice(TabularSectionRow.Products);
	
	If Not StructureData.AbilityToSpecifyOrder Then
		ShowMessageBox(, NStr("en = 'The order is not specified for this type of expense.'"));
		StandardProcessing = False;
	EndIf;
	
EndProcedure

// Procedure - event handler AfterDeletion of the Expenses list row.
//
&AtClient
Procedure ExpensesAfterDeleteRow(Item)
	
	SpentTotalAmount = Object.Inventory.Total("Total") + Object.Expenses.Total("Total") + Object.Payments.Total("PaymentAmount");
	
EndProcedure

// The OnChange event handler of the CounterpartyPayment field.
// It updates the contract currency exchange rate and exchange rate multiplier.
//
&AtClient
Procedure PaymentsCounterpartyOnChange(Item)
	
	TabularSectionRow = Items.Payments.CurrentData;
	
	StructureData = GetDataCounterpartyOnChange(Object.Date, TabularSectionRow.Counterparty, Object.Company);
	
	TabularSectionRow.Contract = StructureData.Contract;
	
	TabularSectionRow.DoOperationsByContracts = StructureData.DoOperationsByContracts;
	TabularSectionRow.DoOperationsByDocuments = StructureData.DoOperationsByDocuments;
	TabularSectionRow.DoOperationsByOrders = StructureData.DoOperationsByOrders;
	
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
	
	If ValueIsFilled(TabularSectionRow.Contract) Then
		TabularSectionRow.ExchangeRate = ?(
			StructureData.ContractCurrencyRateRepetition.ExchangeRate = 0,
			1,
			StructureData.ContractCurrencyRateRepetition.ExchangeRate
		);
		TabularSectionRow.Multiplicity = ?(
			StructureData.ContractCurrencyRateRepetition.Multiplicity = 0,
			1,
			StructureData.ContractCurrencyRateRepetition.Multiplicity
		);
	EndIf;
	
	TabularSectionRow.SettlementsAmount = DriveClient.RecalculateFromCurrencyToCurrency(
		TabularSectionRow.PaymentAmount,
		Object.ExchangeRate,
		TabularSectionRow.ExchangeRate,
		Object.Multiplicity,
		TabularSectionRow.Multiplicity
	);
	
EndProcedure

// The OnChange event handler of the PaymentContract field.
// It updates the contract currency exchange rate and exchange rate multiplier.
//
&AtClient
Procedure PaymentsContractOnChange(Item)
	
	TabularSectionRow = Items.Payments.CurrentData;
	
	If ValueIsFilled(TabularSectionRow.Contract) Then
		StructureData = GetPaymentDataContractOnChange(
			Object.Date,
			TabularSectionRow.Contract
		);
		TabularSectionRow.ExchangeRate = ?(
			StructureData.ContractCurrencyRateRepetition.ExchangeRate = 0,
			1,
			StructureData.ContractCurrencyRateRepetition.ExchangeRate
		);
		TabularSectionRow.Multiplicity = ?(
			StructureData.ContractCurrencyRateRepetition.Multiplicity = 0,
			1,
			StructureData.ContractCurrencyRateRepetition.Multiplicity
		);
	EndIf;
	
	TabularSectionRow.SettlementsAmount = DriveClient.RecalculateFromCurrencyToCurrency(
		TabularSectionRow.PaymentAmount,
		Object.ExchangeRate,
		TabularSectionRow.ExchangeRate,
		Object.Multiplicity,
		TabularSectionRow.Multiplicity
	);
	
EndProcedure

// Procedure - OnChange event handler of the PaymentsSettlementKind input field.
// Clears an attribute document if a settlement type is - "Advance".
//
&AtClient
Procedure PaymentsAdvanceFlagOnChange(Item)
	
	TabularSectionRow = Items.Payments.CurrentData;
	
	If TabularSectionRow.AdvanceFlag Then
		TabularSectionRow.Document = Undefined;
	EndIf;
	
EndProcedure

// Procedure - SelectionStart event handler of the PaymentDocument input field.
// Passes the current attribute value to the parameters.
//
&AtClient
Procedure PaymentsDocumentStartChoice(Item, ChoiceData, StandardProcessing)
	
	TabularSectionRow = Items.Payments.CurrentData;
	
	If TabularSectionRow.AdvanceFlag Then
		ShowMessageBox(, NStr("en = 'The current document is a billing document in case of advance payment.'"));
		StandardProcessing = False;
	EndIf;
	
EndProcedure

// Procedure - OnChange event handler of the PaymentsSettlementAmount field.
// Calculates the amount of the payment.
//
&AtClient
Procedure PaymentsSettlementsAmountOnChange(Item)
	
	CalculatePaymentSUM(Items.Payments.CurrentData);
	SpentTotalAmount = Object.Inventory.Total("Total") + Object.Expenses.Total("Total") + Object.Payments.Total("PaymentAmount");
	
EndProcedure

// Procedure - OnChange event handler of the PaymentRate input field.
// Calculates the amount of the payment.
//
&AtClient
Procedure PaymentsExchangeRateOnChange(Item)
	
	CalculatePaymentSUM(Items.Payments.CurrentData);
	SpentTotalAmount = Object.Inventory.Total("Total") + Object.Expenses.Total("Total") + Object.Payments.Total("PaymentAmount");
	
EndProcedure

// Procedure - OnChange event handler of the PaymentsRatio input field.
// Calculates the amount of the payment.
//
&AtClient
Procedure PaymentsMultiplicityOnChange(Item)
	
	CalculatePaymentSUM(Items.Payments.CurrentData);
	SpentTotalAmount = Object.Inventory.Total("Total") + Object.Expenses.Total("Total") + Object.Payments.Total("PaymentAmount");
	
EndProcedure

// The OnChange event handler of the PaymentPaymentAmount field.
// It updates the payment currency exchange rate and exchange rate multiplier, and also the VAT amount.
//
&AtClient
Procedure PaymentsPaymentAmountOnChange(Item)
	
	TabularSectionRow = Items.Payments.CurrentData;
	
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
	
	TabularSectionRow.ExchangeRate = ?(
		TabularSectionRow.SettlementsAmount = 0,
		1,
		TabularSectionRow.PaymentAmount / TabularSectionRow.SettlementsAmount * Object.ExchangeRate
	);
	SpentTotalAmount = Object.Inventory.Total("Total") + Object.Expenses.Total("Total") + Object.Payments.Total("PaymentAmount");
	
EndProcedure

// Procedure - event handler AfterDeletion of the Payments list row.
//
&AtClient
Procedure PaymentsAfterDeleteRow(Item)
	
	SpentTotalAmount = Object.Inventory.Total("Total") + Object.Expenses.Total("Total") + Object.Payments.Total("PaymentAmount");
	SetAccountsAttributesVisible();
	
EndProcedure

// Procedure - event handler OnEditEnd of the Inventory list row.
//
&AtClient
Procedure InventoryOnEditEnd(Item, NewRow, CancelEdit)
	
	SpentTotalAmount = Object.Inventory.Total("Total") + Object.Expenses.Total("Total") + Object.Payments.Total("PaymentAmount");
	
EndProcedure

// Procedure - event handler OnEditEnd of the Expenses list row.
//
&AtClient
Procedure ExpensesOnEditEnd(Item, NewRow, CancelEdit)
	
	SpentTotalAmount = Object.Inventory.Total("Total") + Object.Expenses.Total("Total") + Object.Payments.Total("PaymentAmount");
	
EndProcedure

// Procedure - event handler OnEditEnd of the Payments list row.
//
&AtClient
Procedure PaymentsOnEditEnd(Item, NewRow, CancelEdit)
	
	SpentTotalAmount = Object.Inventory.Total("Total") + Object.Expenses.Total("Total") + Object.Payments.Total("PaymentAmount");
	
EndProcedure

// Procedure sets visible of calculation attributes depending on the parameters specified to the counterparty.
//
&AtServer
Procedure SetAccountsAttributesVisible(Val DoOperationsByContracts = False, Val DoOperationsByDocuments = False, Val DoOperationsByOrders = False)
	
	FillServiceAttributesByCounterpartyInCollection(Object.Payments);
	
	For Each CurRow In Object.Payments Do
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
	
	Items.PaymentContract.Visible = DoOperationsByContracts;
	Items.PaymentDocument.Visible = DoOperationsByDocuments;
	Items.PaymentSchedule.Visible = DoOperationsByOrders;
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	// Filling in the additional attributes of tabular section.
	SetAccountsAttributesVisible();

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

#Region DataImportFromExternalSources
&AtClient
Procedure LoadFromFileInventory(Command)
	
	NotifyDescription = New NotifyDescription("ImportDataFromExternalSourceResultDataProcessor", ThisObject, DataLoadSettings);
	
	DataLoadSettings.Insert("TabularSectionFullName", 	"ExpenseReport.Inventory");
	DataLoadSettings.Insert("Title", 					NStr("en = 'Import inventory from file'"));
	
	DataImportFromExternalSourcesClient.ShowDataImportFormFromExternalSource(DataLoadSettings, NotifyDescription, ThisObject);
	
EndProcedure

&AtClient
Procedure ImportDataFromExternalSourceResultDataProcessor(ImportResult, AdditionalParameters) Export
	
	If TypeOf(ImportResult) = Type("Structure") Then
		ProcessPreparedData(ImportResult);
	EndIf;
	
EndProcedure

&AtServer
Procedure ProcessPreparedData(ImportResult)
	
	DataImportFromExternalSourcesOverridable.ImportDataFromExternalSourceResultDataProcessor(ImportResult, Object);
	
EndProcedure

#EndRegion

// StandardSubsystems.Printing
&AtClient
Procedure Attachable_ExecutePrintCommand(Command)
	PrintManagementClient.ExecuteConnectedPrintCommand(Command, ThisObject, Object);
EndProcedure
// End StandardSubsystems.Printing

#EndRegion

#EndRegion
