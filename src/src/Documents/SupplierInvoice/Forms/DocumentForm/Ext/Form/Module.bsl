
#Region Variables

&AtClient
Var LineCopyInventory;

&AtClient
Var CloneRowsCosts;

&AtClient
Var ThisIsNewRow;

#EndRegion

#Region ServiceProceduresAndFunctions

// Procedure calls the data processor for document filling by basis.
//
&AtServer
Procedure FillByDocument(BasisDocument)
	
	Document = FormAttributeToValue("Object");
	Document.Filling(BasisDocument, );
	ValueToFormAttribute(Document, "Object");
	Modified = True;
	FillAddedColumns();
	
	SetVATTaxationDependantItemsVisibility();
	
	SetContractVisible();
	
EndProcedure

// Procedure clears the document basis by communication: counterparty, contract.
//
&AtClient
Procedure ClearBasisOnChangeCounterpartyContract()
	
	Object.BasisDocument = Undefined;
	
EndProcedure

// Procedure fills the column "Payment sum", etc. Inventory.
//
&AtServer
Procedure DistributeTabSectExpensesByQuantity()
	
	Document = FormAttributeToValue("Object");
	Document.DistributeTabSectExpensesByQuantity();
	ValueToFormAttribute(Document, "Object");
	
EndProcedure

// Procedure fills the column "Payment sum", etc. Inventory.
//
&AtServer
Procedure DistributeTabSectExpensesByAmount()
	
	Document = FormAttributeToValue("Object");
	Document.DistributeTabSectExpensesByAmount();
	ValueToFormAttribute(Document, "Object");
	
EndProcedure

// It receives data set from server for the DateOnChange procedure.
//
&AtServer
Function GetDataDateOnChange(DateBeforeChange, SettlementsCurrency)
	
	DATEDIFF = DriveServer.CheckDocumentNumber(Object.Ref, Object.Date, DateBeforeChange);
	CurrencyRateRepetition = InformationRegisters.ExchangeRates.GetLast(Object.Date, New Structure("Currency", SettlementsCurrency));
	
	StructureData = New Structure("DATEDIFF, CurrencyRateRepetition", DATEDIFF, CurrencyRateRepetition); 
	
	FillVATRateByCompanyVATTaxation();
	SetAccountingPolicyValues();
	SetTaxInvoiceText();
	SetVisibleAndEnabled();
	
	Return StructureData;
	
EndFunction

// Gets data set from server.
//
&AtServer
Function GetCompanyDataOnChange()
	
	StructureData = New Structure;
	
	StructureData.Insert("Company", DriveServer.GetCompany(Object.Company));
	FillVATRateByCompanyVATTaxation();
	FillAddedColumns(True);
	SetAccountingPolicyValues();
	SetVisibleAndEnabled();

	Return StructureData;
	
EndFunction

// Receives the set of data from the server for the ProductsOnChange procedure.
//
&AtServerNoContext
Function GetDataProductsOnChange(StructureData)
	
	ProductData = CommonUse.ObjectAttributesValues(StructureData.Products, "MeasurementUnit, VATRate, BusinessLine, ExpensesGLAccount.TypeOfAccount");
	
	StructureData.Insert("MeasurementUnit", ProductData.MeasurementUnit);
	
	If ValueIsFilled(ProductData.VATRate) Then
		ProductVATRate = ProductData.VATRate;
	Else
		ProductVATRate = InformationRegisters.AccountingPolicy.GetDefaultVATRate(, StructureData.Company);
	EndIf;
	
	StructureData.Insert("ReverseChargeVATRate", ProductVATRate);
	
	If Not StructureData.Property("VATTaxation")
		Or StructureData.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then
		
		StructureData.Insert("VATRate", ProductVATRate);
		
	ElsIf StructureData.VATTaxation = Enums.VATTaxationTypes.NotSubjectToVAT Then
		
		StructureData.Insert("VATRate", Catalogs.VATRates.Exempt);
		
	Else
		
		StructureData.Insert("VATRate", Catalogs.VATRates.ZeroRate);
		
	EndIf;
	
	If StructureData.Property("SupplierPriceTypes") Then
		
		Price = DriveServer.GetPriceProductsBySupplierPriceTypes(StructureData);
		StructureData.Insert("Price", Price);
		
	Else
		
		StructureData.Insert("Price", 0);
		
	EndIf;
	
	StructureData.Insert("ClearOrderAndDepartment", False);
	StructureData.Insert("ClearBusinessLine", False);
	StructureData.Insert("BusinessLine", ProductData.BusinessLine);
	
	If ProductData.ExpensesGLAccountTypeOfAccount <> Enums.GLAccountsTypes.Expenses
		AND ProductData.ExpensesGLAccountTypeOfAccount <> Enums.GLAccountsTypes.Revenue
		AND ProductData.ExpensesGLAccountTypeOfAccount <> Enums.GLAccountsTypes.WorkInProcess
		AND ProductData.ExpensesGLAccountTypeOfAccount <> Enums.GLAccountsTypes.IndirectExpenses Then
		StructureData.ClearOrderAndDepartment = True;
	EndIf;
	
	If ProductData.ExpensesGLAccountTypeOfAccount <> Enums.GLAccountsTypes.Expenses
		AND ProductData.ExpensesGLAccountTypeOfAccount <> Enums.GLAccountsTypes.CostOfSales
		AND ProductData.ExpensesGLAccountTypeOfAccount <> Enums.GLAccountsTypes.Revenue Then
		StructureData.ClearBusinessLine = True;
	EndIf;
	
	GLAccountsInDocuments.FillProductGLAccountsInStructure(StructureData);
	
	Return StructureData;
	
EndFunction

// It receives data set from server for the CharacteristicOnChange procedure.
//
&AtServerNoContext
Function GetDataCharacteristicOnChange(StructureData)
	
	If StructureData.Property("SupplierPriceTypes") Then
		
		If TypeOf(StructureData.MeasurementUnit) = Type("CatalogRef.UOMClassifier") Then
			StructureData.Insert("Factor", 1);
		Else
			StructureData.Insert("Factor", StructureData.MeasurementUnit.Factor);
		EndIf;		
		
		Price = DriveServer.GetPriceProductsBySupplierPriceTypes(StructureData);
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
	
	StructureData = New Structure;
	
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

// Gets the data set from the server for procedure MeasurementUnitOnChange.
//
&AtServerNoContext
Function GetDataBusinessLineStartChoice(InventoryGLAccount)
	
	StructureData = New Structure;
	
	AvailabilityOfPointingLinesOfBusiness = True;
	
	If InventoryGLAccount.TypeOfAccount <> Enums.GLAccountsTypes.Expenses
	   AND InventoryGLAccount.TypeOfAccount <> Enums.GLAccountsTypes.CostOfSales
	   AND InventoryGLAccount.TypeOfAccount <> Enums.GLAccountsTypes.Revenue Then
		AvailabilityOfPointingLinesOfBusiness = False;
	EndIf;
	
	StructureData.Insert("AvailabilityOfPointingLinesOfBusiness", AvailabilityOfPointingLinesOfBusiness);
	
	Return StructureData;
	
EndFunction

&AtServerNoContext
// Gets the data set from the server for procedure MeasurementUnitOnChange.
//
Function GetDataBusinessUnitstartChoice(InventoryGLAccount)
	
	StructureData = New Structure;
	
	AbilityToSpecifyDepartments = True;
	
	If InventoryGLAccount.TypeOfAccount <> Enums.GLAccountsTypes.Expenses
	   AND InventoryGLAccount.TypeOfAccount <> Enums.GLAccountsTypes.Revenue
	   AND InventoryGLAccount.TypeOfAccount <> Enums.GLAccountsTypes.WorkInProcess
	   AND InventoryGLAccount.TypeOfAccount <> Enums.GLAccountsTypes.IndirectExpenses Then
		AbilityToSpecifyDepartments = False;
	EndIf;
	
	StructureData.Insert("AbilityToSpecifyDepartments", AbilityToSpecifyDepartments);
	
	Return StructureData;
	
EndFunction

&AtServerNoContext
// Gets the data set from the server for procedure MeasurementUnitOnChange.
//
Function GetDataOrderStartChoice(InventoryGLAccount)
	
	StructureData = New Structure;
	
	AbilityToSpecifyOrder = True;
	
	If InventoryGLAccount.TypeOfAccount <> Enums.GLAccountsTypes.Expenses
	   AND InventoryGLAccount.TypeOfAccount <> Enums.GLAccountsTypes.Revenue
	   AND InventoryGLAccount.TypeOfAccount <> Enums.GLAccountsTypes.WorkInProcess
	   AND InventoryGLAccount.TypeOfAccount <> Enums.GLAccountsTypes.IndirectExpenses Then
		AbilityToSpecifyOrder = False;
	EndIf;
	
	StructureData.Insert("AbilityToSpecifyOrder", AbilityToSpecifyOrder);
	
	Return StructureData;
	
EndFunction

// It receives data set from server for the ContractOnChange procedure.
//
&AtServer
Function GetDataCounterpartyOnChange(Date, DocumentCurrency, Counterparty, Company)
	
	ContractByDefault = GetContractByDefault(Object.Ref, Counterparty, Company);
	
	FillVATRateByCompanyVATTaxation();
	
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
	
	SetVATTaxationDependantItemsVisibility();
	
	DefaultVATRate = Undefined;
	DefaultVATRateIsRead = False;
	
	If Object.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then
		
		For Each TabularSectionRow In Object.Inventory Do
			
			ProductVATRate = CommonUse.ObjectAttributeValue(TabularSectionRow.Products, "VATRate");
			
			If ValueIsFilled(ProductVATRate) Then
				TabularSectionRow.VATRate = ProductVATRate;
			Else
				If Not DefaultVATRateIsRead Then
					DefaultVATRate = InformationRegisters.AccountingPolicy.GetDefaultVATRate(Object.Date, Object.Company);
					DefaultVATRateIsRead = True;
				EndIf;
				TabularSectionRow.VATRate = DefaultVATRate;
			EndIf;
			
			VATRate = DriveReUse.GetVATRateValue(TabularSectionRow.VATRate);
			TabularSectionRow.VATAmount = ?(Object.AmountIncludesVAT,
											TabularSectionRow.Amount - (TabularSectionRow.Amount) / ((VATRate + 100) / 100),
											TabularSectionRow.Amount * VATRate / 100);
			TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
			
		EndDo;
		
		For Each TabularSectionRow In Object.Expenses Do
			
			ProductVATRate = CommonUse.ObjectAttributeValue(TabularSectionRow.Products, "VATRate");
			
			If ValueIsFilled(ProductVATRate) Then
				TabularSectionRow.VATRate = ProductVATRate;
			Else
				If Not DefaultVATRateIsRead Then
					DefaultVATRate = InformationRegisters.AccountingPolicy.GetDefaultVATRate(Object.Date, Object.Company);
					DefaultVATRateIsRead = True;
				EndIf;
				TabularSectionRow.VATRate = DefaultVATRate;
			EndIf;
			
			VATRate = DriveReUse.GetVATRateValue(TabularSectionRow.VATRate);
			TabularSectionRow.VATAmount = ?(Object.AmountIncludesVAT,
											TabularSectionRow.Amount - (TabularSectionRow.Amount) / ((VATRate + 100) / 100),
											TabularSectionRow.Amount * VATRate / 100);
			TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
			
		EndDo;
		
	Else
		
		If Object.VATTaxation = Enums.VATTaxationTypes.NotSubjectToVAT Then
			VATRateByTaxation = Catalogs.VATRates.Exempt;
		Else
			VATRateByTaxation = Catalogs.VATRates.ZeroRate;
		EndIf;
		
		IsReverseChargeVATTaxation = Object.VATTaxation = Enums.VATTaxationTypes.ReverseChargeVAT;
		
		For Each TabularSectionRow In Object.Inventory Do
		
			TabularSectionRow.VATRate = VATRateByTaxation;
			TabularSectionRow.VATAmount = 0;
			
			TabularSectionRow.Total = TabularSectionRow.Amount;
			
			If IsReverseChargeVATTaxation Then
				
				ProductVATRate = CommonUse.ObjectAttributeValue(TabularSectionRow.Products, "VATRate");
				
				If ValueIsFilled(ProductVATRate) Then
					TabularSectionRow.ReverseChargeVATRate = ProductVATRate;
				Else
					If Not DefaultVATRateIsRead Then
						DefaultVATRate = InformationRegisters.AccountingPolicy.GetDefaultVATRate(Object.Date, Object.Company);
						DefaultVATRateIsRead = True;
					EndIf;
					TabularSectionRow.ReverseChargeVATRate = DefaultVATRate;
				EndIf;
				
				VATRate = DriveReUse.GetVATRateValue(TabularSectionRow.ReverseChargeVATRate);
				TabularSectionRow.ReverseChargeVATAmount = TabularSectionRow.Total * VATRate / 100;
				
			EndIf;
			
		EndDo;
		
		For Each TabularSectionRow In Object.Expenses Do
			
			TabularSectionRow.VATRate = VATRateByTaxation;
			TabularSectionRow.VATAmount = 0;
			
			TabularSectionRow.Total = TabularSectionRow.Amount;
			
			If IsReverseChargeVATTaxation Then
				
				ProductVATRate = CommonUse.ObjectAttributeValue(TabularSectionRow.Products, "VATRate");
				
				If ValueIsFilled(ProductVATRate) Then
					TabularSectionRow.ReverseChargeVATRate = ProductVATRate;
				Else
					If Not DefaultVATRateIsRead Then
						DefaultVATRate = InformationRegisters.AccountingPolicy.GetDefaultVATRate(Object.Date, Object.Company);
						DefaultVATRateIsRead = True;
					EndIf;
					TabularSectionRow.ReverseChargeVATRate = DefaultVATRate;
				EndIf;
				
				VATRate = DriveReUse.GetVATRateValue(TabularSectionRow.ReverseChargeVATRate);
				TabularSectionRow.ReverseChargeVATAmount = TabularSectionRow.Total * VATRate / 100;
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
	// Update the form footer.
	TotalTotal = Object.Inventory.Total("Total") + Object.Expenses.Total("Total");
	TotalVATAmount = Object.Inventory.Total("VATAmount") + Object.Expenses.Total("VATAmount");
	If Object.VATTaxation = Enums.VATTaxationTypes.ReverseChargeVAT Then
		TotalReverseChargeVATAmount = Object.Inventory.Total("ReverseChargeVATAmount");
		If Not Object.IncludeExpensesInCostPrice Then
			TotalReverseChargeVATAmount = TotalReverseChargeVATAmount + Object.Expenses.Total("ReverseChargeVATAmount");
		EndIf;
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

&AtClient
Procedure CalculateReverseChargeVATAmount(TabularSectionRow)
	
	If Object.VATTaxation = PredefinedValue("Enum.VATTaxationTypes.ReverseChargeVAT") Then
		
		If TabularSectionRow.Property("AmountExpense") Then
		
			If Object.IncludeExpensesInCostPrice Then
				
				VATRate = DriveReUse.GetVATRateValue(TabularSectionRow.ReverseChargeVATRate);
				TabularSectionRow.ReverseChargeVATAmount = (TabularSectionRow.Total + TabularSectionRow.AmountExpense) * VATRate / 100;
				
			Else
				
				VATRate = DriveReUse.GetVATRateValue(TabularSectionRow.ReverseChargeVATRate);
				TabularSectionRow.ReverseChargeVATAmount = TabularSectionRow.Total * VATRate / 100;
				
			EndIf;
			
		Else
			
			If Object.IncludeExpensesInCostPrice Then
				
				TabularSectionRow.ReverseChargeVATAmount = 0;
				
			Else
				
				VATRate = DriveReUse.GetVATRateValue(TabularSectionRow.ReverseChargeVATRate);
				TabularSectionRow.ReverseChargeVATAmount = TabularSectionRow.Total * VATRate / 100;
				
			EndIf;
			
		EndIf;
		
	Else
		
		TabularSectionRow.ReverseChargeVATAmount = 0;
		
	EndIf;
	
EndProcedure

// Procedure calculates the amount in the row of tabular section.
//
&AtClient
Procedure CalculateAmountInTabularSectionLine(TabularSectionName, TabularSectionRow = Undefined)
	
	If TabularSectionRow = Undefined Then
		TabularSectionRow = Items[TabularSectionName].CurrentData;
	EndIf;
	
	TabularSectionRow.Amount = TabularSectionRow.Quantity * TabularSectionRow.Price;
	CalculateVATSUM(TabularSectionRow);
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	CalculateReverseChargeVATAmount(TabularSectionRow);
	
	If TabularSectionName = "Inventory" Then
		RefillDiscountAmountOfEPD();
	EndIf;
	
	// Serial numbers
	If UseSerialNumbersBalance<>Undefined AND TabularSectionName="Inventory" Then
		WorkWithSerialNumbersClientServer.UpdateSerialNumbersQuantity(Object, TabularSectionRow);
	EndIf;
	
EndProcedure

// Recalculates the exchange rate and exchange rate multiplier of
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
		ShowQueryBox(New NotifyDescription("RecalculatePaymentCurrencyRateConversionFactorEnd", 
					ThisObject, 
					New Structure("NewRatio, NewExchangeRate", NewRatio, NewExchangeRate)), MessageText, Mode, 0);
		Return;
		
	EndIf;
	
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
	
	// Generate price and currency label.
	LabelStructure = New Structure;
	LabelStructure.Insert("SupplierPriceTypes",			Object.SupplierPriceTypes);
	LabelStructure.Insert("DocumentCurrency",				Object.DocumentCurrency);
	LabelStructure.Insert("SettlementsCurrency",			SettlementsCurrency);
	LabelStructure.Insert("ExchangeRate",					Object.ExchangeRate);
	LabelStructure.Insert("AmountIncludesVAT",				Object.AmountIncludesVAT);
	LabelStructure.Insert("ForeignExchangeAccounting",	ForeignExchangeAccounting);
	LabelStructure.Insert("RateNationalCurrency",			RateNationalCurrency);
	LabelStructure.Insert("VATTaxation",					Object.VATTaxation);
	LabelStructure.Insert("RegisteredForVAT",				RegisteredForVAT);
	
	PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
	
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
	ParametersStructure.Insert("SupplierPriceTypes", 	  Object.SupplierPriceTypes);
	ParametersStructure.Insert("RegisterVendorPrices", Object.RegisterVendorPrices);
	ParametersStructure.Insert("WarningText",	  WarningText);
	
	NotifyDescription = New NotifyDescription("ProcessChangesOnButtonPricesAndCurrenciesEnd", ThisObject, New Structure("SettlementsCurrencyBeforeChange", SettlementsCurrencyBeforeChange));
	OpenForm("CommonForm.PricesAndCurrency", ParametersStructure, ThisObject, , , , NotifyDescription, FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

// Procedure updates data in form footer.
//
&AtClient
Procedure RefreshFormFooter()
	
	TotalTotal = Object.Inventory.Total("Total") + Object.Expenses.Total("Total");
	TotalVATAmount = Object.Inventory.Total("VATAmount") + Object.Expenses.Total("VATAmount");
	If Object.VATTaxation = PredefinedValue("Enum.VATTaxationTypes.ReverseChargeVAT") Then
		TotalReverseChargeVATAmount = Object.Inventory.Total("ReverseChargeVATAmount");
		If Not Object.IncludeExpensesInCostPrice Then
			TotalReverseChargeVATAmount = TotalReverseChargeVATAmount + Object.Expenses.Total("ReverseChargeVATAmount");
		EndIf;
	EndIf;
	
	RecalculateSubtotal();
	
EndProcedure

// Procedure recalculates subtotal the document on client.
&AtClient
Procedure RecalculateSubtotal()
	
	DocumentSubtotal = TotalTotal - TotalVATAmount;
	
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
		
		Notification = New NotifyDescription("BarcodesAreReceivedEnd", ThisObject, UnknownBarcodes);
		
		OpenForm(
			"InformationRegister.Barcodes.Form.BarcodesRegistration",
			New Structure("UnknownBarcodes", UnknownBarcodes), ThisObject,,,,Notification
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
Procedure ProcessContractChange()
	
	ContractBeforeChange = Contract;
	Contract = Object.Contract;
	
	If ContractBeforeChange <> Object.Contract Then
		
		ClearBasisOnChangeCounterpartyContract();
		
		If Object.Prepayment.Count() > 0
		   AND Object.Contract <> ContractBeforeChange Then
			
			ShowQueryBox(New NotifyDescription("ProcessContractChangeEnd", ThisObject, New Structure("ContractBeforeChange", ContractBeforeChange)),
				NStr("en = 'Prepayment setoff will be cleared, continue?'"),
				QuestionDialogMode.YesNo
			);
			Return;
			
		EndIf;
		
		ProcessContractChangeFragment(ContractBeforeChange);
		
		FillPaymentCalendarFromContract(SwitchTypeListOfPaymentCalendar);
		UpdatePaymentCalendar();
		
	Else
		
		Object.Contract = Contract; // Restore the cleared contract automatically.
		Order = Object.Order;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ProcessContractChangeEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		Object.Prepayment.Clear();
	Else
		Object.Contract = AdditionalParameters.ContractBeforeChange;
		Contract = AdditionalParameters.ContractBeforeChange;
		Object.Order = Order;
		Return;
	EndIf;
	
	ProcessContractChangeFragment(AdditionalParameters.ContractBeforeChange);
	
EndProcedure

&AtClient
Procedure ProcessContractChangeFragment(ContractBeforeChange)
	
	StructureData = GetDataContractOnChange(Object.Date, Object.DocumentCurrency, Object.Contract);
	
	SettlementsCurrencyBeforeChange = SettlementsCurrency;
	SettlementsCurrency = StructureData.SettlementsCurrency;
	
	If Not StructureData.AmountIncludesVAT = Undefined Then
		Object.AmountIncludesVAT = StructureData.AmountIncludesVAT;
	EndIf;
	
	If ValueIsFilled(Object.Contract) Then 
		Object.ExchangeRate      = ?(StructureData.SettlementsCurrencyRateRepetition.ExchangeRate = 0, 1, StructureData.SettlementsCurrencyRateRepetition.ExchangeRate);
		Object.Multiplicity = ?(StructureData.SettlementsCurrencyRateRepetition.Multiplicity = 0, 1, StructureData.SettlementsCurrencyRateRepetition.Multiplicity);
	EndIf;
	
	PriceKindChanged = Object.SupplierPriceTypes <> StructureData.SupplierPriceTypes 
		AND ValueIsFilled(StructureData.SupplierPriceTypes);
	NewContractAndCalculationCurrency = ValueIsFilled(Object.Contract) AND ValueIsFilled(SettlementsCurrency) 
		AND Object.Contract <> ContractBeforeChange AND SettlementsCurrencyBeforeChange <> StructureData.SettlementsCurrency;
	OpenFormPricesAndCurrencies = NewContractAndCalculationCurrency AND Object.DocumentCurrency <> StructureData.SettlementsCurrency
		AND (Object.Inventory.Count() > 0 OR Object.Expenses.Count() > 0);
		
	StructureData.Insert("PriceKindChanged", PriceKindChanged);
	
	If PriceKindChanged Then
		Object.SupplierPriceTypes = StructureData.SupplierPriceTypes;
	EndIf;
	
	// If the contract has changed and the kind of counterparty prices is selected, automatically register incoming prices
	Object.RegisterVendorPrices = StructureData.PriceKindChanged AND Not Object.SupplierPriceTypes.IsEmpty();
	Order = Object.Order;
	
	Object.DocumentCurrency = StructureData.SettlementsCurrency;
	
	If OpenFormPricesAndCurrencies Then
		
		WarningText = "";
		
		If PriceKindChanged Then
			WarningText = NStr("en = 'The price and discount conditions in the contract with counterparty differ from price and discount in the document. 
			                   |Perhaps you have to refill prices.'") + Chars.LF + Chars.LF;
		EndIf;
		
		WarningText = WarningText + NStr("en = 'Settlement currency of the contract with counterparty changed.
		                                 |It is necessary to check the document currency.'");
		ProcessChangesOnButtonPricesAndCurrencies(SettlementsCurrencyBeforeChange, True, PriceKindChanged, WarningText);
		
	ElsIf ValueIsFilled(Object.Contract) 
		AND PriceKindChanged Then
		
		RecalculationRequired = (Object.Inventory.Count() > 0);
		
		Object.SupplierPriceTypes	= StructureData.SupplierPriceTypes;
		
		LabelStructure = New Structure;
		LabelStructure.Insert("SupplierPriceTypes",			Object.SupplierPriceTypes);
		LabelStructure.Insert("DocumentCurrency",				Object.DocumentCurrency);
		LabelStructure.Insert("SettlementsCurrency",			SettlementsCurrency);
		LabelStructure.Insert("ExchangeRate",					Object.ExchangeRate);
		LabelStructure.Insert("AmountIncludesVAT",				Object.AmountIncludesVAT);
		LabelStructure.Insert("ForeignExchangeAccounting",	ForeignExchangeAccounting);
		LabelStructure.Insert("RateNationalCurrency",			RateNationalCurrency);
		LabelStructure.Insert("VATTaxation",					Object.VATTaxation);
		LabelStructure.Insert("RegisteredForVAT",				RegisteredForVAT);
		
		PricesAndCurrency 				= DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
		
		If RecalculationRequired Then
			
			Message = NStr("en = 'The counterparty contract allows for the kind of prices other than prescribed in the document. 
			               |Recalculate the document according to the contract?'");
										
			ShowQueryBox(New NotifyDescription("ProcessContractChangeFragmentEnd", ThisObject, New Structure("ContractBeforeChange, SettlementsCurrencyBeforeChange, StructureData", ContractBeforeChange, SettlementsCurrencyBeforeChange, StructureData)), 
				Message,
				QuestionDialogMode.YesNo
			);
			Return;
		
		EndIf;
		
	Else
		
		LabelStructure = New Structure;
		LabelStructure.Insert("SupplierPriceTypes",			Object.SupplierPriceTypes);
		LabelStructure.Insert("DocumentCurrency",				Object.DocumentCurrency);
		LabelStructure.Insert("SettlementsCurrency",			SettlementsCurrency);
		LabelStructure.Insert("ExchangeRate",					Object.ExchangeRate);
		LabelStructure.Insert("AmountIncludesVAT",				Object.AmountIncludesVAT);
		LabelStructure.Insert("ForeignExchangeAccounting",	ForeignExchangeAccounting);
		LabelStructure.Insert("RateNationalCurrency",			RateNationalCurrency);
		LabelStructure.Insert("VATTaxation",					Object.VATTaxation);
		LabelStructure.Insert("RegisteredForVAT",				RegisteredForVAT);
		
		PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
		
	EndIf;
	
	If ContractBeforeChange <> Object.Contract Then
		FillEarlyPaymentDiscounts();
		SetVisibleEarlyPaymentDiscounts();
	EndIf;
	
	RefreshFormFooter();
	
EndProcedure

&AtClient
Procedure ProcessContractChangeFragmentEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		
		DriveClient.RefillTabularSectionPricesBySupplierPriceTypes(ThisObject, "Inventory");
		RefreshFormFooter();
		
	EndIf;
	
EndProcedure

&AtServer
Procedure SetAccountingPolicyValues()

	AccountingPolicy = InformationRegisters.AccountingPolicy.GetAccountingPolicy(DocumentDate, Object.Company);
	RegisteredForVAT = AccountingPolicy.RegisteredForVAT;
	
EndProcedure

&AtClient
Procedure OpenProductGLAccountsForm(SelectedValue, TabName)

	If SelectedValue = Undefined Then
		Return;
	EndIf;

	If Not ReadOnly Then
		LockFormDataForEdit();
	EndIf;

	RowData = Object[TabName].FindByID(SelectedValue);
	
	ObjectParameters = GLAccountsInDocumentsClientServer.GetObjectParameters(Object);
	StructureData = GetStructureData(ObjectParameters, TabName, RowData);
	
	RowParameters = GLAccountsInDocumentsClientServer.GetGLAccountsStructure(StructureData);
	RowParameters.Insert("TableName",	TabName);
	RowParameters.Insert("Products",	RowData.Products);

	OpenForm("CommonForm.ProductGLAccounts", RowParameters, ThisObject);
	
EndProcedure

&AtClient
Procedure AddGLAccountsToStructure(StructureData, TabRow)
	
	If StructureData.TabName = "Inventory" Then
		StructureData.Insert("GoodsReceipt",		TabRow.GoodsReceipt);
		StructureData.Insert("GoodsReceivedNotInvoicedGLAccount",	TabRow.GoodsReceivedNotInvoicedGLAccount);
		StructureData.Insert("GoodsInvoicedNotDeliveredGLAccount",	TabRow.GoodsInvoicedNotDeliveredGLAccount);
	EndIf;
	
	StructureData.Insert("GLAccounts",			TabRow.GLAccounts);
	StructureData.Insert("GLAccountsFilled",	TabRow.GLAccountsFilled);
	StructureData.Insert("InventoryGLAccount",	TabRow.InventoryGLAccount);
	StructureData.Insert("VATInputGLAccount",	TabRow.VATInputGLAccount);
	StructureData.Insert("VATOutputGLAccount",	TabRow.VATOutputGLAccount);
	
EndProcedure

&AtServer
Procedure FillAddedColumns(GetGLAccounts = False)
	
	ObjectParameters = GLAccountsInDocumentsClientServer.GetObjectParameters(Object);
	
	Tables = New Array();
	
	Tables.Add(GetStructureData(ObjectParameters, "Inventory"));
	Tables.Add(GetStructureData(ObjectParameters, "Expenses"));
	
	GLAccountsInDocuments.FillGLAccountsInTable(Object, Tables, GetGLAccounts);
	
EndProcedure

&AtClient
Procedure GLAccountsChoiceProcessingAtClient(GLAccounts)

	TabRow = Items[GLAccounts.TableName].CurrentData;
	FillPropertyValues(TabRow, GLAccounts);
	Modified = True;
	
	If TabRow.Property("GLAccounts") Then
		ObjectParameters = GLAccountsInDocumentsClientServer.GetObjectParameters(Object);
		StructureData = GetStructureData(ObjectParameters, GLAccounts.TableName, TabRow);
		
		GLAccountsInDocumentsClientServer.FillProductGLAccountsDescription(StructureData);
		FillPropertyValues(TabRow, StructureData);
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Function GetStructureData(ObjectParameters, TabName, RowData = Undefined, ProductName = "Products") Export
	
	StructureData = New Structure("Products, TabName, GoodsReceipt, InventoryGLAccount, GoodsReceivedNotInvoicedGLAccount,
		|GoodsInvoicedNotDeliveredGLAccount, VATInputGLAccount, VATOutputGLAccount, GLAccounts, GLAccountsFilled");
	StructureData.Insert("ObjectParameters", ObjectParameters);
	StructureData.Insert("TabName", TabName);
	StructureData.Insert("ProductName", ProductName);
	
	If RowData <> Undefined Then 
		FillPropertyValues(StructureData, RowData);
	EndIf;
	
	Return StructureData;

EndFunction

#Region WorkWithSelection

// Procedure - event handler Action of the Pick command
//
&AtClient
Procedure InventoryPick(Command)
	
	TabularSectionName	= "Inventory";
	DocumentPresentaion	= NStr("en = 'supplier invoice'");
	SelectionParameters	= DriveClient.GetSelectionParameters(ThisObject, TabularSectionName, DocumentPresentaion, True, False, False);
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
Procedure ExpensesPick(Command)
	
	TabularSectionName	= "Expenses";
	DocumentPresentaion	= NStr("en = 'supplier invoice'");
	SelectionParameters	= DriveClient.GetSelectionParameters(ThisObject, TabularSectionName, DocumentPresentaion, True, False, False);
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

// Function gets a product list from the temporary storage
//
&AtServer
Procedure GetInventoryFromStorage(InventoryAddressInStorage, TabularSectionName, AreCharacteristics, AreBatches)
	
	TableForImport = GetFromTempStorage(InventoryAddressInStorage);
	
	ObjectParameters = GLAccountsInDocumentsClientServer.GetObjectParameters(Object);
	StructureData = GetStructureData(ObjectParameters, TabularSectionName);
	
	For Each ImportRow In TableForImport Do
		
		NewRow = Object[TabularSectionName].Add();
		FillPropertyValues(NewRow, ImportRow);
		
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

&AtClient
Procedure OrderedProductsSelectionProcessingAtClient(TempStorageInventoryAddress)
	OrderedProductsSelectionProcessingAtServer(TempStorageInventoryAddress);
	RefillDiscountAmountOfEPD();
EndProcedure

&AtServer
Procedure OrderedProductsSelectionProcessingAtServer(TempStorageInventoryAddress)
	
	TablesStructure = GetFromTempStorage(TempStorageInventoryAddress);
	
	InventorySearchStructure = New Structure("Products, Characteristic, Batch, Order, GoodsReceipt");
	ServiceSearchStructure = New Structure("Products, PurchaseOrder");
	
	ZeroRate = Catalogs.VATRates.ZeroRate;
	TablesStructure.Inventory.Columns.GoodsIssue.Name = "GoodsReceipt";
	
	EmptyGR = Documents.GoodsReceipt.EmptyRef();
	EmptyPO = Documents.PurchaseOrder.EmptyRef();
	
	ObjectParameters = GLAccountsInDocumentsClientServer.GetObjectParameters(Object);
	StructureData = GetStructureData(ObjectParameters, "");
	
	For Each InventoryRow In TablesStructure.Inventory Do
		
		If InventoryRow.ProductsTypeInventory Then
			
			FillPropertyValues(InventorySearchStructure, InventoryRow);
			
			If InventoryRow.GoodsReceipt = Undefined Then
				InventorySearchStructure.GoodsReceipt = EmptyGR;
			EndIf;
			
			If InventoryRow.Order = Undefined Then
				InventorySearchStructure.Order = EmptyPO;
			EndIf;
			
			TS_InventoryRows = Object.Inventory.FindRows(InventorySearchStructure);
			For Each TS_InventoryRow In TS_InventoryRows Do
				Object.Inventory.Delete(TS_InventoryRow);
			EndDo;
			
			TS_InventoryRow = Object.Inventory.Add();
			FillPropertyValues(TS_InventoryRow, InventoryRow);
			
			StructureData.Insert("TabName", "Inventory");
			FillPropertyValues(StructureData, TS_InventoryRow);
			GLAccounts = GLAccountsInDocuments.GetProductListGLAccounts(StructureData);
			GLAccountsInDocumentsServerCall.FillProductGLAccounts(StructureData, GLAccounts);
			FillPropertyValues(TS_InventoryRow, StructureData);
			
		Else
			
			ServiceSearchStructure.Products = InventoryRow.Products;
			ServiceSearchStructure.PurchaseOrder = InventoryRow.Order;
			
			TS_ServiceRows = Object.Expenses.FindRows(ServiceSearchStructure);
			For Each TS_ServiceRow In TS_ServiceRows Do
				Object.Expenses.Delete(TS_ServiceRow);
			EndDo;
				
			TS_ServiceRow = Object.Expenses.Add();
			FillPropertyValues(TS_ServiceRow, InventoryRow);
			
			TS_ServiceRow.PurchaseOrder = InventoryRow.Order;
			TS_ServiceRow.ReverseChargeVATRate = ZeroRate;
			
			StructureData.Insert("TabName", "Expenses");
			FillPropertyValues(StructureData, TS_ServiceRow);
			GLAccounts = GLAccountsInDocuments.GetProductListGLAccounts(StructureData);
			GLAccountsInDocumentsServerCall.FillProductGLAccounts(StructureData, GLAccounts);
			FillPropertyValues(TS_ServiceRow, StructureData);

		EndIf;
		
	EndDo;
	
	OrdersTable = TablesStructure.Inventory;
	OrdersTable.GroupBy("Order");
	If OrdersTable.Count() > 1 Then
		Object.Order = Undefined;
		Object.PurchaseOrderPosition = Enums.AttributeStationing.InTabularSection;
	ElsIf OrdersTable.Count() = 1 Then
		Object.Order = OrdersTable[0].Order;
		Object.PurchaseOrderPosition = Enums.AttributeStationing.InHeader;
	EndIf;
	
	SetVisibleFromUserSettings();
	
EndProcedure

&AtClient
Procedure SelectOrderedProducts(Command)

	Try
		LockFormDataForEdit();
		Modified = True;
	Except
		ShowMessageBox(Undefined, BriefErrorDescription(ErrorInfo()));
		Return;
	EndTry;
	
	SelectionParameters = New Structure(
		"Ref,
		|Company,
		|StructuralUnit,
		|Counterparty,
		|Contract,
		|DocumentCurrency,
		|AmountIncludesVAT,
		|IncludeVATInPrice,
		|VATTaxation,
		|Order");
	FillPropertyValues(SelectionParameters, Object);
	
	SelectionParameters.Insert("TempStorageInventoryAddress", PutInventoryToTempStorage());
	SelectionParameters.Insert("ShowPurchaseOrders", True);
	SelectionParameters.Insert("ShowGoodsIssue", True);

	OpenForm("CommonForm.SelectionFromOrders", SelectionParameters, ThisObject, , , , , FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtServer
Function PutInventoryToTempStorage()
	
	InventoryTable = Object.Inventory.Unload();
	
	InventoryTable.Columns.Add("Reserve", New TypeDescription("Number"));
	InventoryTable.Columns.Add("GoodsIssue", New TypeDescription("DocumentRef.GoodsIssue"));
	InventoryTable.Columns.Add("SalesInvoice", New TypeDescription("DocumentRef.SalesInvoice"));
	
	If ValueIsFilled(Object.Order) Then
		For Each InventoryRow In InventoryTable Do
			If Not ValueIsFilled(InventoryRow.Order) Then
				InventoryRow.Order = Object.Order;
			EndIf;
		EndDo;
	EndIf;
	
	PurOrdInHeader = Object.PurchaseOrderPosition = Enums.AttributeStationing.InHeader;
	
	For Each ExpenseRow In Object.Expenses Do
		
		NewInventoryRow = InventoryTable.Add();
		
		FillPropertyValues(NewInventoryRow, ExpenseRow);
		
		If PurOrdInHeader Then
			NewInventoryRow.Order = Object.Order;
		Else
			NewInventoryRow.Order = ExpenseRow.PurchaseOrder;
		EndIf;
		
	EndDo;
	
	Return PutToTempStorage(InventoryTable);
	
EndFunction

// Procedure of processing the results of selection closing
//
&AtClient
Procedure OnCloseSelection(ClosingResult, AdditionalParameters) Export
	
	If TypeOf(ClosingResult) = Type("Structure") Then
		
		If Not IsBlankString(ClosingResult.CartAddressInStorage) Then
			
			InventoryAddressInStorage = ClosingResult.CartAddressInStorage;
			
			CurrentPageInventory	= Items.Pages.CurrentPage = Items.GroupInventory;
			TabularSectionName 		= ?(CurrentPageInventory, "Inventory", "Expenses");
			
			GetInventoryFromStorage(InventoryAddressInStorage, TabularSectionName, CurrentPageInventory, CurrentPageInventory);
			
			If TabularSectionName = "Inventory" Then
				RefillDiscountAmountOfEPD();
			EndIf;
			
			RefreshFormFooter();
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region ProceduresAndFunctionsForControlOfTheFormAppearance

// Procedure sets availability of the form items.
//
&AtServer
Procedure SetVisibleAndEnabled(ChangedTypeOperations = False)
	
	
	Items.IncludeExpensesInCostPrice.Visible = True;
	Items.Expenses.Visible = True;
	Items.InventoryAmountExpenses.Visible = True;
	
	If Object.IncludeExpensesInCostPrice Then
		
		Items.ExpensesOrder.Visible = False;
		Items.ExpensesStructuralUnit.Visible = False;
		Items.ExpensesBusinessLine.Visible = False;
		Items.AllocateExpenses.Visible = True;
		Items.InventoryAmountExpenses.Visible = True;
		
	Else
		
		Items.ExpensesOrder.Visible = True;
		Items.ExpensesStructuralUnit.Visible = True;
		Items.ExpensesBusinessLine.Visible = True;
		Items.AllocateExpenses.Visible = False;
		Items.InventoryAmountExpenses.Visible = False;
		
	EndIf;
	
	NewArray = New Array();
	NewArray.Add(Enums.BusinessUnitsTypes.Warehouse);
	NewArray.Add(Enums.BusinessUnitsTypes.Retail);
	NewArray.Add(Enums.BusinessUnitsTypes.RetailEarningAccounting);
	ArrayOwnInventoryAndGoodsOnCommission = New FixedArray(NewArray);
	NewParameter = New ChoiceParameter("Filter.StructuralUnitType", ArrayOwnInventoryAndGoodsOnCommission);
	NewArray = New Array();
	NewArray.Add(NewParameter);
	NewParameters = New FixedArray(NewArray);
	Items.StructuralUnit.ChoiceParameters = NewParameters;
	
	Items.Order.Visible = True;
	Items.FillByOrder.Visible = True;
	Items.InventoryOrder.Visible = True;
	
	If Object.StructuralUnit.StructuralUnitType = Enums.BusinessUnitsTypes.Retail
	 OR Object.StructuralUnit.StructuralUnitType = Enums.BusinessUnitsTypes.RetailEarningAccounting Then
		Items.ExpensesOrder.Visible = False;
	Else
		Items.ExpensesOrder.Visible = True;
	EndIf;
	
	If Not ValueIsFilled(Object.StructuralUnit)
		OR Object.StructuralUnit.StructuralUnitType = Enums.BusinessUnitsTypes.Retail
		OR Object.StructuralUnit.StructuralUnitType = Enums.BusinessUnitsTypes.RetailEarningAccounting Then
		Items.Cell.Visible = False;
	Else
		Items.Cell.Visible = True;
	EndIf;
	
	// VAT Rate, VAT Amount, Total.
	If ChangedTypeOperations Then
		FillVATRateByCompanyVATTaxation();
	Else
		SetVATTaxationDependantItemsVisibility();
	EndIf;
	
	// Price accessibility setup for editing.
	AllowedEditDocumentPrices = DriveAccessManagementReUse.AllowedEditDocumentPrices()
		OR IsInRole("AddChangePurchasesSubsystem");
		
	Items.InventoryPrice.ReadOnly		= Not AllowedEditDocumentPrices;
	Items.InventoryAmount.ReadOnly		= Not AllowedEditDocumentPrices;
	Items.InventoryVATAmount.ReadOnly	= Not AllowedEditDocumentPrices;
	
	// Update the form footer.
	TotalTotal = Object.Inventory.Total("Total") + Object.Expenses.Total("Total");
	TotalVATAmount = Object.Inventory.Total("VATAmount") + Object.Expenses.Total("VATAmount");
	If Object.VATTaxation = Enums.VATTaxationTypes.ReverseChargeVAT Then
		TotalReverseChargeVATAmount = Object.Inventory.Total("ReverseChargeVATAmount");
		If Not Object.IncludeExpensesInCostPrice Then
			TotalReverseChargeVATAmount = TotalReverseChargeVATAmount + Object.Expenses.Total("ReverseChargeVATAmount");
		EndIf;
	EndIf;
	DocumentSubtotal = TotalTotal - TotalVATAmount;
	
	SetVisibleFromUserSettings();

	Items.InventoryTotalAmountOfVAT.Visible	= UseVAT;
	
	If NOT WorkWithVAT.GetUseTaxInvoiceForPostingVAT(Object.Date, Object.Company) Then
		Items.TaxInvoiceText.Visible = False;
	Else
		Items.TaxInvoiceText.Visible = True;
	EndIf;
	
	AccountingPolicy = InformationRegisters.AccountingPolicy.GetAccountingPolicy(Object.Date, Object.Company);
	UseGoodsReturnToSupplier = AccountingPolicy.UseGoodsReturnToSupplier;
	CommonUseClientServer.SetFormItemProperty(Items, "FormDocumentGoodsReturnCreateBasedOn", "Visible",	UseGoodsReturnToSupplier);
	
EndProcedure

// Procedure sets the form item visible.
//
&AtServer
Procedure SetVisibleFromUserSettings()
	
	VisibleValue = (Object.PurchaseOrderPosition = PredefinedValue("Enum.AttributeStationing.InHeader"));
	
	Items.Order.Enabled = VisibleValue;
	If VisibleValue Then
		Items.Order.InputHint = "";
	Else 
		Items.Order.InputHint = NStr("en = '<Multiple orders mode>'");
	EndIf;
	Items.InventoryOrder.Visible = Not VisibleValue;
	Items.FillByOrder.Visible = VisibleValue;
	OrderInHeader = VisibleValue;
	
EndProcedure

&AtServer
Procedure SetVATTaxationDependantItemsVisibility()
	
	IsSubjectToVATTaxation = Object.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT;
	
	Items.InventoryVATRate.Visible = IsSubjectToVATTaxation;
	Items.InventoryVATAmount.Visible = IsSubjectToVATTaxation;
	Items.InventoryAmountTotal.Visible = IsSubjectToVATTaxation;
	
	Items.ExpencesVATRate.Visible = IsSubjectToVATTaxation;
	Items.ExpencesAmountVAT.Visible = IsSubjectToVATTaxation;
	Items.TotalExpences.Visible = IsSubjectToVATTaxation;
	Items.InventoryTotalAmountOfVAT.Visible = IsSubjectToVATTaxation;
	
	Items.PaymentCalendarPayVATAmount.Visible = IsSubjectToVATTaxation;
	Items.PaymentCalendarPaymentVATAmount.Visible = IsSubjectToVATTaxation;
	
	IsReverseChargeVATTaxation = Object.VATTaxation = Enums.VATTaxationTypes.ReverseChargeVAT;
	
	Items.InventoryReverseChargeVATRate.Visible = IsReverseChargeVATTaxation;
	Items.InventoryReverseChargeVATAmount.Visible = IsReverseChargeVATTaxation;
	Items.ExpensesReverseChargeVATRate.Visible = IsReverseChargeVATTaxation And Not Object.IncludeExpensesInCostPrice;
	Items.ExpensesReverseChargeVATAmount.Visible = IsReverseChargeVATTaxation And Not Object.IncludeExpensesInCostPrice;
	
	Items.InventoryTotalReverseChargeAmountOfVAT.Visible = IsReverseChargeVATTaxation;
	
EndProcedure

&AtClient
Procedure SetVisibleEarlyPaymentDiscounts()
	
	Items.GroupEarlyPaymentDiscounts.Visible = GetVisibleFlagForEPD(Object.Counterparty, Object.Contract);
	
EndProcedure

#EndRegion

#Region ProcedureFormEventHandlers

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	FillAddedColumns();
EndProcedure

// Procedure - OnCreateAtServer event handler.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	UseVAT	= DriveServer.GetFunctionalOptionValue("UseVAT");
	
	DriveServer.FillDocumentHeader(
		Object,,
		Parameters.CopyingValue,
		Parameters.Basis,
		PostingIsAllowed,
		Parameters.FillingValues);
	
	If Not ValueIsFilled(Object.Ref)
		AND ValueIsFilled(Object.Counterparty)
		AND Not ValueIsFilled(Parameters.CopyingValue) Then
		
		If Not ValueIsFilled(Object.Contract) Then
			Object.Contract = Object.Counterparty.ContractByDefault;
		EndIf;
		
		If ValueIsFilled(Object.Contract) Then
			
			If Object.DocumentCurrency <> Object.Contract.SettlementsCurrency Then	
				
				Object.DocumentCurrency				= Object.Contract.SettlementsCurrency;
				SettlementsCurrencyRateRepetition	= InformationRegisters.ExchangeRates.GetLast(Object.Date, New Structure("Currency", Object.Contract.SettlementsCurrency));
				Object.ExchangeRate					= ?(SettlementsCurrencyRateRepetition.ExchangeRate = 0, 1, SettlementsCurrencyRateRepetition.ExchangeRate);
				Object.Multiplicity					= ?(SettlementsCurrencyRateRepetition.Multiplicity = 0, 1, SettlementsCurrencyRateRepetition.Multiplicity);
				
			EndIf;
			
			If Not ValueIsFilled(Object.SupplierPriceTypes) Then
				Object.SupplierPriceTypes = Object.Contract.SupplierPriceTypes;
			EndIf;
			
		EndIf;
	EndIf;
	
	// Form attributes setting.
	DocumentDate = Object.Date;
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentDate();
	EndIf;
	
	Company						= DriveServer.GetCompany(Object.Company);
	Counterparty				= Object.Counterparty;
	Contract					= Object.Contract;
	Order						= Object.Order;
	SettlementsCurrency			= Object.Contract.SettlementsCurrency;
	FunctionalCurrency			= Constants.FunctionalCurrency.Get();
	StructureByCurrency			= InformationRegisters.ExchangeRates.GetLast(Object.Date, New Structure("Currency", FunctionalCurrency));
	RateNationalCurrency		= StructureByCurrency.ExchangeRate;
	RepetitionNationalCurrency	= StructureByCurrency.Multiplicity;
	
	SetAccountingPolicyValues();
	
	If Not ValueIsFilled(Object.Ref) Then 
		If Not ValueIsFilled(Parameters.Basis) AND Not ValueIsFilled(Parameters.CopyingValue) Then
			FillVATRateByCompanyVATTaxation();
		EndIf;
	EndIf;
	
	// Update the form footer.
	TotalTotal		= Object.Inventory.Total("Total") + Object.Expenses.Total("Total");
	TotalVATAmount	= Object.Inventory.Total("VATAmount") + Object.Expenses.Total("VATAmount");
	If Object.VATTaxation = Enums.VATTaxationTypes.ReverseChargeVAT Then
		TotalReverseChargeVATAmount = Object.Inventory.Total("ReverseChargeVATAmount");
		If Not Object.IncludeExpensesInCostPrice Then
			TotalReverseChargeVATAmount = TotalReverseChargeVATAmount + Object.Expenses.Total("ReverseChargeVATAmount");
		EndIf;
	EndIf;
	DocumentSubtotal = TotalTotal - TotalVATAmount;
	
	// Generate price and currency label.
	ForeignExchangeAccounting	= Constants.ForeignExchangeAccounting.Get();
	
	LabelStructure = New Structure;
	LabelStructure.Insert("SupplierPriceTypes",			Object.SupplierPriceTypes);
	LabelStructure.Insert("DocumentCurrency",				Object.DocumentCurrency);
	LabelStructure.Insert("SettlementsCurrency",			SettlementsCurrency);
	LabelStructure.Insert("ExchangeRate",					Object.ExchangeRate);
	LabelStructure.Insert("AmountIncludesVAT",				Object.AmountIncludesVAT);
	LabelStructure.Insert("ForeignExchangeAccounting",	ForeignExchangeAccounting);
	LabelStructure.Insert("RateNationalCurrency",			RateNationalCurrency);
	LabelStructure.Insert("VATTaxation",					Object.VATTaxation);
	LabelStructure.Insert("RegisteredForVAT",				RegisteredForVAT);
	
	PricesAndCurrency				= DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
	
	FillAddedColumns();
	WorkWithVAT.SetTextAboutTaxInvoiceReceived(ThisObject);
	
	SetVisibleAndEnabled();
	
	User = Users.CurrentUser();
	
	SettingValue = DriveReUse.GetValueByDefaultUser(User, "MainWarehouse");
	MainWarehouse = ?(ValueIsFilled(SettingValue), SettingValue, Catalogs.BusinessUnits.MainWarehouse);
	
	SettingValue = DriveReUse.GetValueByDefaultUser(User, "MainDepartment");
	MainDepartment = ?(ValueIsFilled(SettingValue), SettingValue, Catalogs.BusinessUnits.MainDepartment);
	
	// Setting contract visible.
	SetContractVisible();
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.DataImportFromExternalSources
	DataImportFromExternalSources.OnCreateAtServer(Metadata.Documents.SupplierInvoice.TabularSections.Inventory, DataLoadSettings, ThisObject);
	// End StandardSubsystems.DataImportFromExternalSource
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisObject, Items.ImportantCommandsGroup);
	// End StandardSubsystems.Printing
	
	// StandardSubsystems.Properties
	PropertiesManagement.OnCreateAtServer(ThisObject, Object, "AdditionalAttributesGroup");
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
	
	// Serial numbers
	UseSerialNumbersBalance = WorkWithSerialNumbers.UseSerialNumbersBalance();
	
	SetTaxInvoiceText();
	
	SwitchTypeListOfPaymentCalendar = ?(Object.PaymentCalendar.Count() > 1, 1, 0);
	
EndProcedure

// Procedure - OnReadAtServer event handler.
//
&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	ClosingDates.ObjectOnReadAtServer(ThisObject, CurrentObject);
	
	// StandardSubsystems.Properties
	PropertiesManagement.OnReadAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.Properties
	
	SetSwitchTypeListOfPaymentCalendar();
	FillAddedColumns();
	
EndProcedure

// Procedure - event handler AfterWriting.
//
&AtClient
Procedure AfterWrite(WriteParameters)
	
	OrderIsFilled = False;
	FilledOrderReturn = False;
	For Each TSRow In Object.Inventory Do
		If ValueIsFilled(TSRow.Order) Then
			If TypeOf(TSRow.Order) = Type("DocumentRef.PurchaseOrder") Then
				OrderIsFilled = True;
			Else
				FilledOrderReturn = True;
			EndIf;
			Break;
		EndIf;
	EndDo;
	
	If OrderIsFilled Then
		Notify("Record_SupplierInvoice", Object.Ref);
	EndIf;
	
	If FilledOrderReturn Then
		Notify("Record_SupplierInvoiceReturn", Object.Ref);
	EndIf;
	
	Notify("NotificationAboutChangingDebt");
	
	PrepaymentWasChanged = False;
	
EndProcedure

// Procedure - event handler of the form BeforeWrite
//
&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	// StandardSubsystems.PerformanceMeasurement
	PerformanceEstimationClientServer.StartTimeMeasurement("DocumentSupplierInvoicePosting");
	// StandardSubsystems.PerformanceMeasurement
	
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
		
		If DriveReUse.GetAdvanceOffsettingSettingValue() = Enums.YesNo.Yes
			AND CurrentObject.Prepayment.Count() = 0 Then
			FillPrepayment(CurrentObject);
		ElsIf PrepaymentWasChanged Then
			WorkWithVAT.FillPrepaymentVATFromVATInput(CurrentObject);
		EndIf;
		
	EndIf;
	
	If NOT CheckEarlyPaymentDiscounts() Then
		Cancel = True;
	EndIf;
	
	// "Properties" mechanism handler
	PropertiesManagement.BeforeWriteAtServer(ThisObject, CurrentObject);
	// "Properties" mechanism handler
	
EndProcedure

// Procedure - event handler OnOpen.
//
&AtClient
Procedure OnOpen(Cancel)
	
	// Peripherals
	EquipmentManagerClientOverridable.StartConnectingEquipmentOnFormOpen(ThisObject, "BarCodeScanner");
	// End Peripherals
	
	PrepaymentWasChanged = False;
	
	SetVisiblePaymentCalendar();
	SetVisibleCashAssetsTypes();
	SetEnableGroupPaymentCalendarDetails();
	SetVisibleEarlyPaymentDiscounts();
	
EndProcedure

// Procedure - event handler OnClose.
//
&AtClient
Procedure OnClose(Exit)
	
	// Peripherals
	EquipmentManagerClientOverridable.StartDisablingEquipmentOnCloseForm(ThisObject);
	// End Peripherals
	
EndProcedure

// Procedure - event handler of the form NotificationProcessing.
//
&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	// Properties subsystem
	If PropertiesManagementClient.ProcessAlerts(ThisObject, EventName, Parameter) Then
		
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
	
	If EventName = "RefreshTaxInvoiceText" 
		AND TypeOf(Parameter) = Type("Structure") 
		AND Not Parameter.BasisDocuments.Find(Object.Ref) = Undefined Then
		
		TaxInvoiceText = Parameter.Presentation;
	
	ElsIf EventName = "AfterRecordingOfCounterparty" 
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
			CalculateAmountInTabularSectionLine("Inventory");
		EndIf; 		
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(SelectedValue, ChoiceSource)
	
	If ChoiceSource.FormName = "Document.TaxInvoiceReceived.Form.DocumentForm" Then
		TaxInvoiceText = SelectedValue;
	ElsIf ChoiceSource.FormName = "CommonForm.SelectionFromOrders" Then
		OrderedProductsSelectionProcessingAtClient(SelectedValue.TempStorageInventoryAddress);
	ElsIf ChoiceSource.FormName = "Document.GoodsReceipt.Form.SelectionForm" Then
		Items.Inventory.CurrentData.GoodsReceipt = SelectedValue;
	ElsIf ChoiceSource.FormName = "CommonForm.ProductGLAccounts" Then
		GLAccountsChoiceProcessingAtClient(SelectedValue);
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

// Procedure - command handler of the tabular section command panel.
//
&AtClient
Procedure DistributeExpensesByQuantity(Command)
	
	DistributeTabSectExpensesByQuantity();
		
EndProcedure

// Procedure - command handler of the tabular section command panel.
//
&AtClient
Procedure DistributeExpensesByAmount(Command)
	
	DistributeTabSectExpensesByAmount();
		
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
	
	OrdersArray = New Array;
	For Each CurItem In Object.Inventory Do
		OrderStructure = New Structure("Order, Total");
		OrderStructure.Order = ?(CurItem.Order = Undefined, PredefinedValue("Document.PurchaseOrder.EmptyRef"), CurItem.Order);
		OrderStructure.Total = CurItem.Total;
		OrdersArray.Add(OrderStructure);
	EndDo;
	For Each CurItem In Object.Expenses Do
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
		OrderInHeader, // OrderInHeader
		Company, // Company
		?(CounterpartyDoSettlementsByOrders, ?(OrderInHeader, Object.Order, OrdersArray), Undefined), // Order
		Object.Date, // Date
		Object.Ref, // Ref
		Object.Counterparty, // Counterparty
		Object.Contract, // Contract
		Object.ExchangeRate, // ExchangeRate
		Object.Multiplicity, // Multiplicity
		Object.DocumentCurrency, // DocumentCurrency
		Object.Inventory.Total("Total") + Object.Expenses.Total("Total")
	);
	
	ReturnCode = Undefined;
	
	NotifyParametersStructure = New Structure("AddressPrepaymentInStorage, SelectionParameters", AddressPrepaymentInStorage, SelectionParameters);
	OpenForm("CommonForm.SelectAdvancesPaidToTheSupplier",
		SelectionParameters,,,,,
		New NotifyDescription("EditPrepaymentOffsetEnd", ThisObject, NotifyParametersStructure));
	
EndProcedure

&AtClient
Procedure EditPrepaymentOffsetEnd(Result, AdditionalParameters) Export
	
	AddressPrepaymentInStorage = AdditionalParameters.AddressPrepaymentInStorage;
	SelectionParameters = AdditionalParameters.SelectionParameters;
	
	EditPrepaymentOffsetFragment(AddressPrepaymentInStorage, Result);

EndProcedure

&AtClient
Procedure EditPrepaymentOffsetFragment(Val AddressPrepaymentInStorage, Val ReturnCode)
	
	If ReturnCode = DialogReturnCode.OK Then
		GetPrepaymentFromStorage(AddressPrepaymentInStorage);
	EndIf;
	
EndProcedure

// You can call the procedure by clicking
// the button "FillByBasis" of the tabular field command panel.
//
&AtClient
Procedure FillByBasis(Command)
	
	Response = Undefined;
	ShowQueryBox(New NotifyDescription("FillByBasisEnd", ThisObject), NStr("en = 'Do you want to refill the supplier invoice?'"), QuestionDialogMode.YesNo, 0);
	
EndProcedure

&AtClient
Procedure FillByBasisEnd(Result, AdditionalParameters) Export
    
    Response = Result;
    If Response = DialogReturnCode.Yes Then
        
        FillByDocument(Object.BasisDocument);
        SetVisibleAndEnabled();
        
		LabelStructure = New Structure;
		LabelStructure.Insert("SupplierPriceTypes",			Object.SupplierPriceTypes);
		LabelStructure.Insert("DocumentCurrency",				Object.DocumentCurrency);
		LabelStructure.Insert("SettlementsCurrency",			SettlementsCurrency);
		LabelStructure.Insert("ExchangeRate",					Object.ExchangeRate);
		LabelStructure.Insert("AmountIncludesVAT",				Object.AmountIncludesVAT);
		LabelStructure.Insert("ForeignExchangeAccounting",	ForeignExchangeAccounting);
		LabelStructure.Insert("RateNationalCurrency",			RateNationalCurrency);
		LabelStructure.Insert("VATTaxation",					Object.VATTaxation);
		LabelStructure.Insert("RegisteredForVAT",				RegisteredForVAT);
		
		PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
        
        RefreshFormFooter();
        
    EndIf;

EndProcedure

// You can call the procedure by clicking
// the button "FillByOrder" of the tabular field command panel.
//
&AtClient
Procedure FillByOrder(Command)
	
	Response = Undefined;
	ShowQueryBox(New NotifyDescription("FillEndByOrder", ThisObject), NStr("en = 'The document will be fully filled out according to the ""Order."" Continue?'"), QuestionDialogMode.YesNo, 0);
	
EndProcedure

&AtClient
Procedure FillEndByOrder(Result, AdditionalParameters) Export
	
	Response = Result;
	If Response = DialogReturnCode.Yes Then
		FillByDocument(Object.Order);
		SetVisibleAndEnabled();
		
		LabelStructure = New Structure;
		LabelStructure.Insert("SupplierPriceTypes",			Object.SupplierPriceTypes);
		LabelStructure.Insert("DocumentCurrency",			Object.DocumentCurrency);
		LabelStructure.Insert("SettlementsCurrency",		SettlementsCurrency);
		LabelStructure.Insert("ExchangeRate",				Object.ExchangeRate);
		LabelStructure.Insert("AmountIncludesVAT",			Object.AmountIncludesVAT);
		LabelStructure.Insert("ForeignExchangeAccounting",	ForeignExchangeAccounting);
		LabelStructure.Insert("RateNationalCurrency",		RateNationalCurrency);
		LabelStructure.Insert("VATTaxation",				Object.VATTaxation);
		LabelStructure.Insert("RegisteredForVAT",			RegisteredForVAT);
		
		PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
		
		RefreshFormFooter();
		
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

// Procedure - clicking handler on the hyperlink TaxInvoiceText.
//
&AtClient
Procedure TaxInvoiceTextClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	WorkWithVATClient.OpenTaxInvoice(ThisObject, True);
	
EndProcedure

// Procedure - command handler DocumentSetup.
//
&AtClient
Procedure DocumentSetup(Command)
	
	// 1. Form parameter structure to fill "Document setting" form.
	ParametersStructure = New Structure;
	ParametersStructure.Insert("PurchaseOrderPositionInReceiptDocuments",		Object.PurchaseOrderPosition);
	ParametersStructure.Insert("WereMadeChanges", 								False);
	
	StructureDocumentSetting = Undefined;
	
	OpenForm("CommonForm.DocumentSetup", ParametersStructure,,,,, New NotifyDescription("DocumentSettingEnd", ThisObject));
	
EndProcedure

&AtClient
Procedure DocumentSettingEnd(Result, AdditionalParameters) Export
	
	StructureDocumentSetting = Result;
	
	If TypeOf(StructureDocumentSetting) = Type("Structure") AND StructureDocumentSetting.WereMadeChanges Then
		
		Object.PurchaseOrderPosition = StructureDocumentSetting.PurchaseOrderPositionInReceiptDocuments;
		
		If Object.PurchaseOrderPosition = PredefinedValue("Enum.AttributeStationing.InHeader") Then
			If Object.Inventory.Count() Then
				Object.Order = Object.Inventory[0].Order;
			EndIf;
		ElsIf Object.PurchaseOrderPosition = PredefinedValue("Enum.AttributeStationing.InTabularSection") Then
			If ValueIsFilled(Object.Order) Then
				For Each InventoryRow In Object.Inventory Do
					If Not ValueIsFilled(InventoryRow.Order) Then
						InventoryRow.Order = Object.Order;
					EndIf;
				EndDo;
				Object.Order = Undefined;
			EndIf;
		EndIf;
		
		SetVisibleFromUserSettings();
		
	EndIf;
	
EndProcedure

#EndRegion

#Region ProcedureEventHandlersOfHeaderAttributes

&AtClient
Procedure AdvanceInvoicingOnChange(Item)
	FillAddedColumns(True);
EndProcedure

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
		
		LabelStructure = New Structure;
		LabelStructure.Insert("SupplierPriceTypes",			Object.SupplierPriceTypes);
		LabelStructure.Insert("DocumentCurrency",				Object.DocumentCurrency);
		LabelStructure.Insert("SettlementsCurrency",			SettlementsCurrency);
		LabelStructure.Insert("ExchangeRate",					Object.ExchangeRate);
		LabelStructure.Insert("AmountIncludesVAT",				Object.AmountIncludesVAT);
		LabelStructure.Insert("ForeignExchangeAccounting",	ForeignExchangeAccounting);
		LabelStructure.Insert("RateNationalCurrency",			RateNationalCurrency);
		LabelStructure.Insert("VATTaxation",					Object.VATTaxation);
		LabelStructure.Insert("RegisteredForVAT",				RegisteredForVAT);
		
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
	
	Object.Contract = GetContractByDefault(Object.Ref, Object.Counterparty, Object.Company);
	ProcessContractChange();
	
	LabelStructure = New Structure;
	LabelStructure.Insert("SupplierPriceTypes",			Object.SupplierPriceTypes);
	LabelStructure.Insert("DocumentCurrency",			Object.DocumentCurrency);
	LabelStructure.Insert("SettlementsCurrency",		SettlementsCurrency);
	LabelStructure.Insert("ExchangeRate",				Object.ExchangeRate);
	LabelStructure.Insert("AmountIncludesVAT",			Object.AmountIncludesVAT);
	LabelStructure.Insert("ForeignExchangeAccounting",	ForeignExchangeAccounting);
	LabelStructure.Insert("RateNationalCurrency",		RateNationalCurrency);
	LabelStructure.Insert("VATTaxation",				Object.VATTaxation);
	LabelStructure.Insert("RegisteredForVAT",			RegisteredForVAT);
	
	PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
	
	SetTaxInvoiceText();
	
	If Object.SetPaymentTerms
		AND ValueIsFilled(Object.CashAssetsType) Then
		
		RecalculatePaymentCalendar();
		FillPaymentScedule();
		
	EndIf;
	
EndProcedure

// Procedure - event handler OnChange of the StructuralUnit input field.
//
&AtClient
Procedure StructuralUnitOnChange(Item)
	
	FillAddedColumns(True);
	SetVisibleAndEnabled();
	
EndProcedure

// Procedure - event handler OnChange of the input field IncludeExpensesInCostPrice.
//
&AtClient
Procedure IncludeExpensesInCostPriceOnChange(Item)
	
	If Object.IncludeExpensesInCostPrice Then
		
		Items.ExpensesOrder.Visible = False;
		Items.ExpensesStructuralUnit.Visible = False;
		Items.ExpensesBusinessLine.Visible = False;
		Items.AllocateExpenses.Visible = True;
		
		Items.ExpensesReverseChargeVATRate.Visible = False;
		Items.ExpensesReverseChargeVATAmount.Visible = False;
		
		Items.InventoryAmountExpenses.Visible = True;
		Items.ExpensesGLAccounts.Visible = False;
		
		For Each RowsExpenses In Object.Expenses Do
			RowsExpenses.ReverseChargeVATAmount = 0;
		EndDo;
		
	Else
		
		Items.ExpensesOrder.Visible = True;
		Items.ExpensesStructuralUnit.Visible = True;
		Items.ExpensesBusinessLine.Visible = True;
		Items.AllocateExpenses.Visible = False;
		
		IsReverseChargeVATTaxation = Object.VATTaxation = PredefinedValue("Enum.VATTaxationTypes.ReverseChargeVAT");
		Items.ExpensesReverseChargeVATRate.Visible = IsReverseChargeVATTaxation;
		Items.ExpensesReverseChargeVATAmount.Visible = IsReverseChargeVATTaxation;
		
		Items.InventoryAmountExpenses.Visible = False;
		Items.ExpensesGLAccounts.Visible = True;
		
		For Each StringInventory In Object.Inventory Do
			StringInventory.AmountExpense = 0;
			CalculateReverseChargeVATAmount(StringInventory);
		EndDo;
		
		For Each RowsExpenses In Object.Expenses Do
			RowsExpenses.StructuralUnit = MainDepartment;
			CalculateReverseChargeVATAmount(RowsExpenses);
		EndDo;
		
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
		
		ClearBasisOnChangeCounterpartyContract();
		
		ContractVisibleBeforeChange = Items.Contract.Visible;
		
		StructureData = GetDataCounterpartyOnChange(Object.Date, Object.DocumentCurrency, Object.Counterparty, Object.Company);
		
		Object.Contract = StructureData.Contract;
		ContractBeforeChange = Contract;
		Contract = Object.Contract;
		
		If Object.Prepayment.Count() > 0
			AND Object.Contract <> ContractBeforeChange Then
			
			ShowQueryBox(New NotifyDescription("CounterpartyOnChangeEnd", ThisObject, New Structure("CounterpartyBeforeChange, ContractBeforeChange, CounterpartyDoSettlementsByOrdersBeforeChange, ContractVisibleBeforeChange, StructureData", CounterpartyBeforeChange, ContractBeforeChange, CounterpartyDoSettlementsByOrdersBeforeChange, ContractVisibleBeforeChange, StructureData)),
				NStr("en = 'Prepayment setoff will be cleared, continue?'"),
				QuestionDialogMode.YesNo);
			Return;
			
		EndIf;
		
		CounterpartyOnChangeFragment(ContractBeforeChange, StructureData);
		
		UpdatePaymentCalendar();
		
	Else
		
		Object.Contract = Contract; // Restore the cleared contract automatically.
		Object.Order = Order;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CounterpartyOnChangeEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		Object.Prepayment.Clear();
	Else 
		Object.Counterparty = AdditionalParameters.CounterpartyBeforeChange;
		Counterparty = AdditionalParameters.CounterpartyBeforeChange;
		Object.Contract = AdditionalParameters.ContractBeforeChange;
		Contract = AdditionalParameters.ContractBeforeChange;
		Object.Order = Order;
		CounterpartyDoSettlementsByOrders = AdditionalParameters.CounterpartyDoSettlementsByOrdersBeforeChange;
		Items.Contract.Visible = AdditionalParameters.ContractVisibleBeforeChange;
		Return;
	EndIf;
	
	CounterpartyOnChangeFragment(AdditionalParameters.ContractBeforeChange, AdditionalParameters.StructureData);
	
EndProcedure

&AtClient
Procedure CounterpartyOnChangeFragment(ContractBeforeChange, StructureData)
	
	SettlementsCurrencyBeforeChange = SettlementsCurrency;
	SettlementsCurrency = StructureData.SettlementsCurrency;
	
	If Not StructureData.AmountIncludesVAT = Undefined Then
		Object.AmountIncludesVAT = StructureData.AmountIncludesVAT;
	EndIf;
	
	If ValueIsFilled(Object.Contract) Then 
		Object.ExchangeRate	= ?(StructureData.SettlementsCurrencyRateRepetition.ExchangeRate = 0, 1, StructureData.SettlementsCurrencyRateRepetition.ExchangeRate);
		Object.Multiplicity	= ?(StructureData.SettlementsCurrencyRateRepetition.Multiplicity = 0, 1, StructureData.SettlementsCurrencyRateRepetition.Multiplicity);
	EndIf;
	
	PriceKindChanged = Object.SupplierPriceTypes <> StructureData.SupplierPriceTypes 
		AND ValueIsFilled(StructureData.SupplierPriceTypes);
	NewContractAndCalculationCurrency = ValueIsFilled(Object.Contract) AND ValueIsFilled(SettlementsCurrency) 
		AND Object.Contract <> ContractBeforeChange AND SettlementsCurrencyBeforeChange <> StructureData.SettlementsCurrency;
	OpenFormPricesAndCurrencies = NewContractAndCalculationCurrency AND Object.DocumentCurrency <> StructureData.SettlementsCurrency
		AND (Object.Inventory.Count() > 0 OR Object.Expenses.Count() > 0);
	
	StructureData.Insert("PriceKindChanged", PriceKindChanged);
	
	If PriceKindChanged Then
		Object.SupplierPriceTypes = StructureData.SupplierPriceTypes;
	EndIf;
	
	// If the contract has changed and the kind of counterparty prices is selected, automatically register incoming prices/
	Object.RegisterVendorPrices = StructureData.PriceKindChanged AND Not Object.SupplierPriceTypes.IsEmpty();
	Order = Object.Order;
	
	Object.DocumentCurrency = StructureData.SettlementsCurrency;
	
	If OpenFormPricesAndCurrencies Then
		
		WarningText = "";
		
		If PriceKindChanged Then
			WarningText = NStr("en = 'The price and discount conditions in the contract with counterparty differ from price and discount in the document. 
							|Perhaps you have to refill prices.'") + Chars.LF + Chars.LF;
		EndIf;
		
		WarningText = WarningText + NStr("en = 'Settlement currency of the contract with counterparty changed.
										|It is necessary to check the document currency.'");
		ProcessChangesOnButtonPricesAndCurrencies(SettlementsCurrencyBeforeChange, True, PriceKindChanged, WarningText);
		
	ElsIf ValueIsFilled(Object.Contract) 
		AND PriceKindChanged Then
		
		RecalculationRequired = (Object.Inventory.Count() > 0);
		
		Object.SupplierPriceTypes = StructureData.SupplierPriceTypes;
		LabelStructure = New Structure;
		LabelStructure.Insert("SupplierPriceTypes",			Object.SupplierPriceTypes);
		LabelStructure.Insert("DocumentCurrency",			Object.DocumentCurrency);
		LabelStructure.Insert("SettlementsCurrency",		SettlementsCurrency);
		LabelStructure.Insert("ExchangeRate",				Object.ExchangeRate);
		LabelStructure.Insert("AmountIncludesVAT",			Object.AmountIncludesVAT);
		LabelStructure.Insert("ForeignExchangeAccounting",	ForeignExchangeAccounting);
		LabelStructure.Insert("RateNationalCurrency",		RateNationalCurrency);
		LabelStructure.Insert("VATTaxation",				Object.VATTaxation);
		LabelStructure.Insert("RegisteredForVAT",			RegisteredForVAT);
							
		PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
		
		If RecalculationRequired Then
			
			Message = NStr("en = 'The counterparty contract allows for the kind of prices other than prescribed in the document. 
							|Recalculate the document according to the contract?'");
			ShowQueryBox(New NotifyDescription("CounterpartyOnChangeFragmentEnd", ThisObject, New Structure("ContractBeforeChange, SettlementsCurrencyBeforeChange, StructureData", ContractBeforeChange, SettlementsCurrencyBeforeChange, StructureData)), 
				Message,
				QuestionDialogMode.YesNo);
			Return;
			
		EndIf;
		
	Else
		
		LabelStructure = New Structure;
		LabelStructure.Insert("SupplierPriceTypes",			Object.SupplierPriceTypes);
		LabelStructure.Insert("DocumentCurrency",			Object.DocumentCurrency);
		LabelStructure.Insert("SettlementsCurrency",		SettlementsCurrency);
		LabelStructure.Insert("ExchangeRate",				Object.ExchangeRate);
		LabelStructure.Insert("AmountIncludesVAT",			Object.AmountIncludesVAT);
		LabelStructure.Insert("ForeignExchangeAccounting",	ForeignExchangeAccounting);
		LabelStructure.Insert("RateNationalCurrency",		RateNationalCurrency);
		LabelStructure.Insert("VATTaxation",				Object.VATTaxation);
		LabelStructure.Insert("RegisteredForVAT",			RegisteredForVAT);
		
		PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
		
	EndIf;
	
	If ContractBeforeChange <> Object.Contract Then
		FillEarlyPaymentDiscounts();
		SetVisibleEarlyPaymentDiscounts();
	EndIf;
	
	RefreshFormFooter();
	
EndProcedure

&AtClient
Procedure CounterpartyOnChangeFragmentEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		DriveClient.RefillTabularSectionPricesBySupplierPriceTypes(ThisObject, "Inventory");
		RefreshFormFooter();
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
	
	FormParameters = GetChoiceFormParameters(Object.Ref, Object.Company, Object.Counterparty, Object.Contract);
	If FormParameters.ControlContractChoice Then
		
		StandardProcessing = False;
		OpenForm("Catalog.CounterpartyContracts.Form.ChoiceForm", FormParameters, Item);
		
	EndIf;
	
EndProcedure

// Procedure - event handler OnChange of the input field Order.
//
&AtClient
Procedure OrderOnChange(Item)
	
	OrderBefore = Order;
	Order = Object.Order;
	
	If Object.Prepayment.Count() > 0
		AND OrderBefore <> Object.Order Then
		Mode = QuestionDialogMode.YesNo;
		Response = Undefined;
		ShowQueryBox(New NotifyDescription("OrderOnChangeEnd", ThisObject, New Structure("OrderBefore", OrderBefore)), NStr("en = 'Prepayment setoff will be cleared, continue?'"), Mode, 0);
	EndIf;
	
EndProcedure

&AtClient
Procedure OrderOnChangeEnd(Result, AdditionalParameters) Export
	
	OrderBefore = AdditionalParameters.OrderBefore;
	
	Response = Result;
	If Response = DialogReturnCode.Yes Then
		Object.Prepayment.Clear();
	Else
		Object.Order = OrderBefore;
		Order = OrderBefore;
		Return;
	EndIf;
	
EndProcedure

#Region EventHandlersOfTheEarlyPaymentDiscountsTabularSectionAttributes

&AtClient
Procedure EarlyPaymentDiscountsPeriodOnChange(Item)
	
	CalculateRowDueDateOfEPD(Object.Date);
	
EndProcedure

&AtClient
Procedure EarlyPaymentDiscountsDiscountOnChange(Item)
	
	CalculateRowDiscountAmountOfEPD(Object.Inventory.Total("Total"));
	
EndProcedure

#EndRegion

#Region EventHandlersOfTheInventoryTabularSectionAttributes

&AtClient
Procedure InventoryOnStartEdit(Item, NewRow, Copy)
	
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

// Procedure - event handler OnChange of the "Invetory" tabular section.
//
&AtClient
Procedure InventoryOnChange(Item)
	
	If LineCopyInventory = Undefined OR Not LineCopyInventory Then
		RefreshFormFooter();
	Else
		LineCopyInventory = False;
	EndIf;
	
	RecalculatePaymentCalendar();
	RefillDiscountAmountOfEPD();
	
EndProcedure

// Procedure - event handler BeforeStartAdd of the "Inventory" tabular section.
//
&AtClient
Procedure InventoryBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	If Copy Then
		TotalTotal = Object.Inventory.Total("Total") + Object.Expenses.Total("Total") + Item.CurrentData.Total;
		TotalVATAmount = Object.Inventory.Total("VATAmount") + Object.Expenses.Total("VATAmount") + Item.CurrentData.VATAmount;
		If Object.VATTaxation = PredefinedValue("Enum.VATTaxationTypes.ReverseChargeVAT") Then
			TotalReverseChargeVATAmount = Object.Inventory.Total("ReverseChargeVATAmount");
			If Not Object.IncludeExpensesInCostPrice Then
				TotalReverseChargeVATAmount = TotalReverseChargeVATAmount + Object.Expenses.Total("ReverseChargeVATAmount");
			EndIf;
		EndIf;
		RecalculateSubtotal();
		LineCopyInventory = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure InventoryBeforeDeleteRow(Item, Cancel)
	
	CurrentData = Items.Inventory.CurrentData;
	
	// Serial numbers
	WorkWithSerialNumbersClientServer.DeleteSerialNumbersByConnectionKey(Object.SerialNumbers, CurrentData,,UseSerialNumbersBalance);
	
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

&AtClient
Procedure InventoryGoodsReceiptChoiceEnd(SelectedValue, AdditionalParameters = Undefined) Export
	
	If SelectedValue = Undefined Then
		Return;
	EndIf;
	
	TabRow = Items.Inventory.CurrentData;
	
	StructureData = New Structure();
	StructureData.Insert("TabName",			"Inventory");
	AddGLAccountsToStructure(StructureData, TabRow);
	StructureData.Insert("Products",		TabRow.Products);
	StructureData.Insert("GoodsReceipt",	SelectedValue);

	InventoryGoodsReceiptOnChangeAtServer(StructureData);
	FillPropertyValues(TabRow, StructureData);
	
EndProcedure

&AtServer
Procedure InventoryGoodsReceiptOnChangeAtServer(StructureData)
	
	StructureData.Insert("ObjectParameters", GLAccountsInDocumentsClientServer.GetObjectParameters(Object));
	GLAccounts = GLAccountsInDocuments.GetProductListGLAccounts(StructureData);
	GLAccountsInDocumentsServerCall.FillProductGLAccounts(StructureData, GLAccounts);
	
EndProcedure

&AtClient
Procedure InventoryGoodsReceiptOnChange(Item)
	
	TabRow = Items.Inventory.CurrentData;
	InventoryGoodsReceiptChoiceEnd(TabRow.GoodsReceipt);
	
EndProcedure

&AtClient
Procedure InventoryGoodsReceiptChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	InventoryGoodsReceiptChoiceEnd(SelectedValue);
	
EndProcedure

// Procedure - event handler OnChange of the Products input field.
//
&AtClient
Procedure InventoryProductsOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("Company", Object.Company);
	StructureData.Insert("Products", TabularSectionRow.Products);
	StructureData.Insert("Characteristic", TabularSectionRow.Characteristic);
	StructureData.Insert("VATTaxation", Object.VATTaxation);
	StructureData.Insert("TabName", "Inventory");
	
	If ValueIsFilled(Object.SupplierPriceTypes) Then
		
		StructureData.Insert("ProcessingDate", Object.Date);
		StructureData.Insert("DocumentCurrency", Object.DocumentCurrency);
		StructureData.Insert("AmountIncludesVAT", Object.AmountIncludesVAT);
		StructureData.Insert("Characteristic", TabularSectionRow.Characteristic);
		StructureData.Insert("SupplierPriceTypes", Object.SupplierPriceTypes);
		StructureData.Insert("Factor", 1);
		
	EndIf;
	
	AddGLAccountsToStructure(StructureData, TabularSectionRow);	
	StructureData.Insert("ObjectParameters", GLAccountsInDocumentsClientServer.GetObjectParameters(Object));
	StructureData = GetDataProductsOnChange(StructureData);
	
	FillPropertyValues(TabularSectionRow, StructureData); 
	TabularSectionRow.MeasurementUnit = StructureData.MeasurementUnit;
	TabularSectionRow.Quantity = 1;
	TabularSectionRow.Price = StructureData.Price;
	TabularSectionRow.VATRate = StructureData.VATRate;
	TabularSectionRow.ReverseChargeVATRate = StructureData.ReverseChargeVATRate;
	TabularSectionRow.Content = "";
	
	// Serial numbers
	WorkWithSerialNumbersClientServer.DeleteSerialNumbersByConnectionKey(Object.SerialNumbers, TabularSectionRow,,UseSerialNumbersBalance);
	
	CalculateAmountInTabularSectionLine("Inventory");
	
EndProcedure

// Procedure - event handler OnChange of the Characteristic input field.
//
&AtClient
Procedure InventoryCharacteristicOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
		
	StructureData = New Structure;
	StructureData.Insert("Products",	 TabularSectionRow.Products);
	StructureData.Insert("Characteristic",	 TabularSectionRow.Characteristic);
		
	If ValueIsFilled(Object.SupplierPriceTypes) Then
	
		StructureData.Insert("ProcessingDate",		Object.Date);
		StructureData.Insert("DocumentCurrency",	Object.DocumentCurrency);
		StructureData.Insert("AmountIncludesVAT",	Object.AmountIncludesVAT);
		StructureData.Insert("VATRate",				TabularSectionRow.VATRate);
		StructureData.Insert("Price",				TabularSectionRow.Price);
		StructureData.Insert("SupplierPriceTypes",	Object.SupplierPriceTypes);
		StructureData.Insert("MeasurementUnit",		TabularSectionRow.MeasurementUnit);
		
	EndIf;
	
	StructureData = GetDataCharacteristicOnChange(StructureData);
		
	TabularSectionRow.Price = StructureData.Price;
	TabularSectionRow.Content = "";
	
	CalculateAmountInTabularSectionLine("Inventory");
	
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
	
	CalculateAmountInTabularSectionLine("Inventory");
	
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
	
	CalculateAmountInTabularSectionLine("Inventory");
	
EndProcedure

// Procedure - event handler OnChange of the Price input field.
//
&AtClient
Procedure InventoryPriceOnChange(Item)
	
	CalculateAmountInTabularSectionLine("Inventory");
	
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
	CalculateReverseChargeVATAmount(TabularSectionRow);
	
	RefillDiscountAmountOfEPD();
	
EndProcedure

// Procedure - event handler OnChange of the VATRate input field.
//
&AtClient
Procedure InventoryVATRateOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	CalculateVATSUM(TabularSectionRow);
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	CalculateReverseChargeVATAmount(TabularSectionRow);
	
	RefillDiscountAmountOfEPD();
	
EndProcedure

// Procedure - event handler OnChange of the VATRate input field.
//
&AtClient
Procedure InventoryVATAmountOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	CalculateReverseChargeVATAmount(TabularSectionRow);
	
	RefillDiscountAmountOfEPD();
	
EndProcedure

&AtClient
Procedure InventoryAmountExpensesOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	CalculateReverseChargeVATAmount(TabularSectionRow);
	
EndProcedure

&AtClient
Procedure InventoryReverseChargeVATRateOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	CalculateReverseChargeVATAmount(TabularSectionRow);
	
EndProcedure

&AtClient
Procedure InventoryGoodsReceiptStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	ParametersStructure = New Structure;
	
	If Object.PurchaseOrderPosition = PredefinedValue("Enum.AttributeStationing.InHeader") Then
		ParametersStructure.Insert("OrderFilter", Object.Order);
	Else
		ParametersStructure.Insert("OrderFilter", Items.Inventory.CurrentData.Order);
	EndIf;
	
	NotifyDescription = New NotifyDescription("InventoryGoodsReceiptChoiceEnd", ThisObject);
	
	OpenForm("Document.GoodsReceipt.ChoiceForm", ParametersStructure, ThisObject,,,, NotifyDescription);

EndProcedure

&AtClient
Procedure InventoryAfterDeleteRow(Item)
	
	RefillDiscountAmountOfEPD();
	
EndProcedure

#EndRegion

#Region EventHandlersOfTheExpensesTabularSectionAttributes

// Procedure - event handler OnChange of the "Costs" tabular section.
//
&AtClient
Procedure ExpensesOnChange(Item)
	
	If CloneRowsCosts = Undefined OR Not CloneRowsCosts Then
		RefreshFormFooter();
	Else
		CloneRowsCosts = False;
	EndIf;
	
	RecalculatePaymentCalendar();
	
EndProcedure

// Procedure - event handler BeforeStartAdd of the "Inventory" tabular section.
//
&AtClient
Procedure ExpensesBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	If Copy Then
		TotalTotal = Object.Inventory.Total("Total") + Object.Expenses.Total("Total") + Item.CurrentData.Total;
		TotalVATAmount = Object.Inventory.Total("VATAmount") + Object.Expenses.Total("VATAmount") + Item.CurrentData.VATAmount;
		If Object.VATTaxation = PredefinedValue("Enum.VATTaxationTypes.ReverseChargeVAT") Then
			TotalReverseChargeVATAmount = Object.Inventory.Total("ReverseChargeVATAmount");
			If Not Object.IncludeExpensesInCostPrice Then
				TotalReverseChargeVATAmount = TotalReverseChargeVATAmount + Object.Expenses.Total("ReverseChargeVATAmount");
			EndIf;
		EndIf;
		RecalculateSubtotal();
		CloneRowsCosts = True;
	EndIf;
	
EndProcedure

// Procedure - event handler AtStartEdit of the "Costs" tabular section.
//
&AtClient
Procedure ExpensesOnStartEdit(Item, NewRow, Copy)
	
	If NewRow Then
		
		TabularSectionRow = Items.Expenses.CurrentData;
		TabularSectionRow.StructuralUnit = MainDepartment;
		
	EndIf;
	
	If Not NewRow Or Copy Then
		Return;	
	EndIf;
	
	Item.CurrentData.GLAccounts = GLAccountsInDocumentsClientServer.GetEmptyGLAccountPresentation();
	
EndProcedure

&AtClient
Procedure ExpensesSelection(Item, SelectedRow, Field, StandardProcessing)
	If Field.Name = "ExpensesGLAccounts" Then
		StandardProcessing = False;
		OpenProductGLAccountsForm(SelectedRow, "Expenses");
	EndIf;
EndProcedure

&AtClient
Procedure ExpensesOnActivateCell(Item)
	
	If Items.Inventory.CurrentData = Undefined Then
		Return;
	EndIf;
	
	If ThisIsNewRow Then
		TableCurrentColumn = Items.Inventory.CurrentItem;
		If TableCurrentColumn.Name = "ExpensesGLAccounts"
			And Not Items.Expenses.CurrentData.GLAccountsFilled Then
			SelectedRow = Items.Expenses.CurrentRow;
			OpenProductGLAccountsForm(SelectedRow, "Expenses");
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure ExpensesOnEditEnd(Item, NewRow, CancelEdit)
	ThisIsNewRow = False;
EndProcedure

&AtClient
Procedure ExpensesGLAccountsStartChoice(Item, ChoiceData, StandardProcessing)
	StandardProcessing = False;
	SelectedRow = Items.Expenses.CurrentRow;
	OpenProductGLAccountsForm(SelectedRow, "Expenses");
EndProcedure

// Procedure - event handler OnChange of the Products input field.
//
&AtClient
Procedure ExpensesProductsOnChange(Item)
	
	TabularSectionRow = Items.Expenses.CurrentData;
	
	StructureData = New Structure();
	StructureData.Insert("Company", Object.Company);
	StructureData.Insert("Products", TabularSectionRow.Products);
	StructureData.Insert("Characteristic", "");
	StructureData.Insert("VATTaxation", Object.VATTaxation);
	StructureData.Insert("TabName", "Expenses");
	
	AddGLAccountsToStructure(StructureData, TabularSectionRow);	
	StructureData.Insert("ObjectParameters", GLAccountsInDocumentsClientServer.GetObjectParameters(Object));
	StructureData = GetDataProductsOnChange(StructureData);
	
	FillPropertyValues(TabularSectionRow, StructureData); 
	TabularSectionRow.MeasurementUnit = StructureData.MeasurementUnit;
	TabularSectionRow.Quantity = 1;
	TabularSectionRow.Price = 0;
	TabularSectionRow.Amount = 0;
	TabularSectionRow.VATRate = StructureData.VATRate;
	TabularSectionRow.VATAmount = 0;
	TabularSectionRow.Total = 0;
	TabularSectionRow.ReverseChargeVATRate = StructureData.ReverseChargeVATRate;
	TabularSectionRow.ReverseChargeVATAmount = 0;
	TabularSectionRow.Content = "";
	
	If StructureData.ClearOrderAndDepartment Then
		TabularSectionRow.StructuralUnit = Undefined;
		TabularSectionRow.Order = Undefined;
	ElsIf Not ValueIsFilled(TabularSectionRow.StructuralUnit) Then
		TabularSectionRow.StructuralUnit = MainDepartment;
	EndIf;
	
	If StructureData.ClearBusinessLine Then
		TabularSectionRow.BusinessLine = Undefined;
	Else
		TabularSectionRow.BusinessLine = StructureData.BusinessLine;
	EndIf;
	
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
	
	CalculateAmountInTabularSectionLine("Expenses");
	
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
		StructureData = GetDataMeasurementUnitOnChange(, ValueSelected);
	ElsIf CurrentFactor = 1 AND Factor = 1 Then
		StructureData = New Structure("CurrentFactor, Factor", 1, 1);
	EndIf;
	
	If StructureData.CurrentFactor <> 0 Then
		TabularSectionRow.Price = TabularSectionRow.Price * StructureData.Factor / StructureData.CurrentFactor;
	EndIf;
	
	CalculateAmountInTabularSectionLine("Expenses");
	
EndProcedure

// Procedure - event handler OnChange of the Price input field.
//
&AtClient
Procedure ExpensesPriceOnChange(Item)
	
	CalculateAmountInTabularSectionLine("Expenses");
	
EndProcedure

// Procedure - event handler OnChange of the Amount input field.
//
&AtClient
Procedure AmountExpensesOnChange(Item)
	
	TabularSectionRow = Items.Expenses.CurrentData;
	
	If TabularSectionRow.Quantity <> 0 Then
		TabularSectionRow.Price = TabularSectionRow.Amount / TabularSectionRow.Quantity;
	EndIf;
	
	CalculateVATSUM(TabularSectionRow);
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	CalculateReverseChargeVATAmount(TabularSectionRow);
	
EndProcedure

// Procedure - event handler OnChange of the VATRate input field.
//
&AtClient
Procedure ExpensesVATRateOnChange(Item)
	
	TabularSectionRow = Items.Expenses.CurrentData;
	
	CalculateVATSUM(TabularSectionRow);
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	CalculateReverseChargeVATAmount(TabularSectionRow);
	
EndProcedure

// Procedure - event handler OnChange of the VATRate input field.
//
&AtClient
Procedure AmountExpensesVATOnChange(Item)
	
	TabularSectionRow = Items.Expenses.CurrentData;
	
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	CalculateReverseChargeVATAmount(TabularSectionRow);
	
EndProcedure

&AtClient
Procedure ExpensesReverseChargeVATRateOnChange(Item)
	
	TabularSectionRow = Items.Expenses.CurrentData;
	
	CalculateReverseChargeVATAmount(TabularSectionRow);
	
EndProcedure

// Procedure - SelectionStart event handler of the ExpensesBusinessLine input field.
//
&AtClient
Procedure ExpensesBusinessLineStartChoice(Item, ChoiceData, StandardProcessing)
	
	TabularSectionRow = Items.Expenses.CurrentData;
	
	StructureData = GetDataBusinessLineStartChoice(TabularSectionRow.InventoryGLAccount);
	
	If Not StructureData.AvailabilityOfPointingLinesOfBusiness Then
		StandardProcessing = False;
		ShowMessageBox(, NStr("en = 'Business area is not required for this type of expense.'"));
	EndIf;
	
EndProcedure

&AtClient
// Procedure - event handler SelectionStart of the StructuralUnit input field.
//
Procedure ExpensesBusinessUnitstartChoice(Item, ChoiceData, StandardProcessing)
	
	TabularSectionRow = Items.Expenses.CurrentData;
	
	StructureData = GetDataBusinessUnitstartChoice(TabularSectionRow.InventoryGLAccount);
	
	If Not StructureData.AbilityToSpecifyDepartments Then
		StandardProcessing = False;
		ShowMessageBox(, NStr("en = 'Department is not required for this kind of expense.'"));
	EndIf;
	
EndProcedure

&AtClient
// Procedure - event handler SelectionStart of input field Order.
//
Procedure ExpensesOrderStartChoice(Item, ChoiceData, StandardProcessing)
	
	TabularSectionRow = Items.Expenses.CurrentData;
	
	StructureData = GetDataOrderStartChoice(TabularSectionRow.InventoryGLAccount);
	
	If Not StructureData.AbilityToSpecifyOrder Then
		StandardProcessing = False;
		ShowMessageBox(, NStr("en = 'The order is not specified for this type of expense.'"));
	EndIf;
	
EndProcedure

#EndRegion

#Region GeneralPurposeProceduresAndFunctionsOfPaymentCalendar

&AtServer
Procedure FillThePaymentCalendarOnServer()
	
	FillPaymentCalendarFromContract(SwitchTypeListOfPaymentCalendar);
	
	If Object.PaymentCalendar.Count() = 0 Then
		NewRow = Object.PaymentCalendar.Add();
		
		NewRow.PaymentPercentage = 100;
		NewRow.PaymentAmount = Object.Inventory.Total("Amount") + Object.Expenses.Total("Amount");
		NewRow.PaymentVATAmount = Object.Inventory.Total("VATAmount") + Object.Expenses.Total("VATAmount");
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
	FillAddedColumns();
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
	
	VATForPaymentCalendar = Object.Inventory.Total("VATAmount") + Object.Expenses.Total("VATAmount");
	
	Return VATForPaymentCalendar;
	
EndFunction

&AtClient
Function AmountForPaymentCalendar()
	
	AmountForPaymentCalendar = Object.Inventory.Total("Amount") + Object.Expenses.Total("Amount");
	
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

#EndRegion

#Region EarlyPaymentDiscount

&AtServerNoContext
Function GetVisibleFlagForEPD(Counterparty, Contract)
	
	If ValueIsFilled(Counterparty) Then
		DoOperationsByDocuments = CommonUse.ObjectAttributeValue(Counterparty, "DoOperationsByDocuments");
	Else
		DoOperationsByDocuments = False;
	EndIf;
	
	If ValueIsFilled(Contract) Then
		ContractKind		= CommonUse.ObjectAttributeValue(Contract, "ContractKind");
		ContractKindFlag	= (ContractKind = Enums.ContractType.WithVendor);
	Else
		ContractKindFlag	= False;
	EndIf;
	
	Return (DoOperationsByDocuments AND ContractKindFlag);
	
EndFunction

&AtServer
Function CheckEarlyPaymentDiscounts()
	
	Return EarlyPaymentDiscountsServer.CheckEarlyPaymentDiscounts(Object.EarlyPaymentDiscounts, Object.ProvideEPD);
	
EndFunction

&AtServer
Procedure FillEarlyPaymentDiscounts()
	
	Document = FormAttributeToValue("Object");
	Document.FillEarlyPaymentDiscounts();
	ValueToFormAttribute(Document, "Object");
	
EndProcedure

&AtClient
Procedure RefillDueDateOfEPD(NewDate)
	
	If ValueIsFilled(NewDate) Then
		
		For Each DiscountRow In Object.EarlyPaymentDiscounts Do
			
			CalculateRowDueDateOfEPD(NewDate, DiscountRow);
			
		EndDo;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CalculateRowDueDateOfEPD(DateForCalc, DiscountRow = Undefined)
	
	If DiscountRow = Undefined Then
		DiscountRow = Items.EarlyPaymentDiscounts.CurrentData;
	EndIf;
	
	If DiscountRow = Undefined Then
		Return;
	EndIf;
	
	DiscountRow.DueDate = DateForCalc + DiscountRow.Period * 86400;
	
EndProcedure

&AtClient
Procedure RefillDiscountAmountOfEPD()
	
	TotalAmount = Object.Inventory.Total("Total");
	
	For Each DiscountRow In Object.EarlyPaymentDiscounts Do
		
		CalculateRowDiscountAmountOfEPD(TotalAmount, DiscountRow);
		
	EndDo;
	
EndProcedure

&AtClient
Procedure CalculateRowDiscountAmountOfEPD(TotalAmount, DiscountRow = Undefined)
	
	If DiscountRow = Undefined Then
		DiscountRow = Items.EarlyPaymentDiscounts.CurrentData;
	EndIf;
	
	If DiscountRow = Undefined Then
		Return;
	EndIf;
	
	DiscountRow.DiscountAmount = Round(TotalAmount * DiscountRow.Discount / 100, 2);
	
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

#EndRegion

#Region EventHandlersOfIncomingDocument

&AtClient
Procedure IncomingDocumentDateStartChoice(Item, ChoiceData, StandardProcessing)
	IncomingDocumentDate = Object.IncomingDocumentDate;
EndProcedure

&AtClient
Procedure IncomingDocumentDateOnChange(Item)
	
	IncomingDocumentDateBeforeChange = IncomingDocumentDate;
	IncomingDocumentDate = Object.IncomingDocumentDate;
	
	If IncomingDocumentDateBeforeChange <> Object.IncomingDocumentDate Then
		
		If ValueIsFilled(IncomingDocumentDateBeforeChange) Then
			
			If Object.SetPaymentTerms Then
				
				Delta = Object.IncomingDocumentDate - IncomingDocumentDateBeforeChange;
				
				For Each Line In Object.PaymentCalendar Do
					
					Line.PaymentDate = Line.PaymentDate + Delta;
					
				EndDo;
				
				MessageString = NStr("en = 'The Payment terms tab was changed'");
				CommonUseClientServer.MessageToUser(MessageString);
				
			EndIf;
			
		ElsIf Object.SetPaymentTerms Then
			
			FillThePaymentCalendarOnServer();
			MessageString = NStr("en = 'The Payment terms tab was changed'");
			CommonUseClientServer.MessageToUser(MessageString);
			
		EndIf;
		
		RefillDueDateOfEPD(Object.IncomingDocumentDate);
		
	EndIf;
	
EndProcedure

#EndRegion

&AtServer
// Procedure-handler of the FillCheckProcessingAtServer event.
//
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	// StandardSubsystems.Properties
	PropertiesManagement.FillCheckProcessing(ThisObject, Cancel, CheckedAttributes);
	// End StandardSubsystems.Properties
	
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
		TabularSectionRow.ExchangeRate);
	
	TabularSectionRow.Multiplicity = ?(
		TabularSectionRow.Multiplicity = 0,
			?(Object.Multiplicity = 0,
			1,
			Object.Multiplicity),
		TabularSectionRow.Multiplicity);
	
	TabularSectionRow.PaymentAmount = DriveClient.RecalculateFromCurrencyToCurrency(
		TabularSectionRow.SettlementsAmount,
		TabularSectionRow.ExchangeRate,
		?(Object.DocumentCurrency = FunctionalCurrency, RateNationalCurrency, Object.ExchangeRate),
		TabularSectionRow.Multiplicity,
		?(Object.DocumentCurrency = FunctionalCurrency,RepetitionNationalCurrency, Object.Multiplicity));

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

&AtClient
Procedure PrepaymentOnChange(Item)
	PrepaymentWasChanged = True;
EndProcedure

#Region InteractiveActionResultHandlers

// Procedure-handler of the result of opening the "Prices and currencies" form
//
&AtClient
Procedure ProcessChangesOnButtonPricesAndCurrenciesEnd(ClosingResult, AdditionalParameters) Export
	
	// 3. Refill the tabular section "Inventory" if changes were made to the form "Prices and Currency".
	If TypeOf(ClosingResult) = Type("Structure")
		AND ClosingResult.WereMadeChanges Then
		
		Object.DocumentCurrency = ClosingResult.DocumentCurrency;
		Object.ExchangeRate = ClosingResult.PaymentsRate;
		Object.Multiplicity = ClosingResult.SettlementsMultiplicity;
		Object.VATTaxation = ClosingResult.VATTaxation;
		Object.AmountIncludesVAT = ClosingResult.AmountIncludesVAT;
		Object.IncludeVATInPrice = ClosingResult.IncludeVATInPrice;
		Object.SupplierPriceTypes = ClosingResult.SupplierPriceTypes;
		Object.RegisterVendorPrices = ClosingResult.RegisterVendorPrices;
		// DiscountCards
		If ValueIsFilled(ClosingResult.DiscountCard) AND ValueIsFilled(ClosingResult.Counterparty) AND Not Object.Counterparty.IsEmpty() Then
			If ClosingResult.Counterparty = Object.Counterparty Then
				Object.DiscountCard = ClosingResult.DiscountCard;
			Else // We will show the message and we will not change discount card data.
				CommonUseClientServer.MessageToUser(
				NStr("en = 'Discount card is not read. Discount card owner does not match the counterparty in the document.'"),
				,
				"Counterparty",
				"Object");
			EndIf;
		Else
			Object.DiscountCard = ClosingResult.DiscountCard;
		EndIf;
		// End DiscountCards
		
		// Recalculate prices by kind of prices.
		If ClosingResult.RefillPrices Then
			DriveClient.RefillTabularSectionPricesBySupplierPriceTypes(ThisObject, "Inventory");
		EndIf;

		// Recalculate prices by currency.
		If Not ClosingResult.RefillPrices
			AND ClosingResult.RecalculatePrices Then
			DriveClient.RecalculateTabularSectionPricesByCurrency(ThisObject, AdditionalParameters.SettlementsCurrencyBeforeChange, "Inventory");
		EndIf;
		
		If ClosingResult.RecalculatePrices Then
			DriveClient.RecalculateTabularSectionPricesByCurrency(ThisObject, AdditionalParameters.SettlementsCurrencyBeforeChange, "Expenses");
		EndIf;
		
		// Recalculate the amount if VAT taxation flag is changed.
		If ClosingResult.VATTaxation <> ClosingResult.PrevVATTaxation Then
			FillVATRateByVATTaxation();
		EndIf;
		
		// Recalculate the amount if the "Amount includes VAT" flag is changed.
		If Not ClosingResult.RefillPrices
			AND ClosingResult.AmountIncludesVAT <> ClosingResult.PrevAmountIncludesVAT Then
			DriveClient.RecalculateTabularSectionAmountByFlagAmountIncludesVAT(ThisObject, "Inventory");
		EndIf;
		
		If ClosingResult.AmountIncludesVAT <> ClosingResult.PrevAmountIncludesVAT Then
			DriveClient.RecalculateTabularSectionAmountByFlagAmountIncludesVAT(ThisObject, "Expenses");
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
	
	LabelStructure = New Structure;
	LabelStructure.Insert("SupplierPriceTypes",			Object.SupplierPriceTypes);
	LabelStructure.Insert("DocumentCurrency",				Object.DocumentCurrency);
	LabelStructure.Insert("SettlementsCurrency",			SettlementsCurrency);
	LabelStructure.Insert("ExchangeRate",					Object.ExchangeRate);
	LabelStructure.Insert("AmountIncludesVAT",				Object.AmountIncludesVAT);
	LabelStructure.Insert("ForeignExchangeAccounting",	ForeignExchangeAccounting);
	LabelStructure.Insert("RateNationalCurrency",			RateNationalCurrency);
	LabelStructure.Insert("VATTaxation",					Object.VATTaxation);
	LabelStructure.Insert("RegisteredForVAT",				RegisteredForVAT);
	
	PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
	
	RefreshFormFooter();
	
	RecalculatePaymentCalendar();
	RefillDiscountAmountOfEPD();
	ProcessChangesOnButtonPricesAndCurrenciesEndAtServer();
	
EndProcedure

&AtServer
Procedure ProcessChangesOnButtonPricesAndCurrenciesEndAtServer() 
	FillAddedColumns(True);
EndProcedure

#EndRegion

#Region LibrariesHandlers

// StandardSubsystems.AdditionalReportsAndDataProcessors
&AtClient
Procedure Attachable_ExecuteAssignedCommand(Command)
	
	If Not AdditionalReportsAndDataProcessorsClient.ExecuteAllocatedCommandAtClient(ThisObject, Command.Name) Then
		ExecutionResult = Undefined;
		AdditionalReportsAndProcessingsExecuteAllocatedCommandAtServer(Command.Name, ExecutionResult);
		AdditionalReportsAndDataProcessorsClient.ShowCommandExecutionResult(ThisObject, ExecutionResult);
	EndIf;
	
EndProcedure

&AtServer
Procedure AdditionalReportsAndProcessingsExecuteAllocatedCommandAtServer(ItemName, ExecutionResult)
	
	AdditionalReportsAndDataProcessors.ExecuteAllocatedCommandAtServer(ThisObject, ItemName, ExecutionResult);
	
EndProcedure
// End StandardSubsystems.AdditionalReportsAndDataProcessors

// StandardSubsystems.Printing
&AtClient
Procedure Attachable_ExecutePrintCommand(Command)
	PrintManagementClient.ExecuteConnectedPrintCommand(Command, ThisObject, Object);
EndProcedure
// End StandardSubsystems.Printing

// StandardSubsystems.Property
&AtClient
Procedure Attachable_EditContentOfProperties(Command)
	
	PropertiesManagementClient.EditContentOfProperties(ThisObject, Object.Ref);
	
EndProcedure

&AtServer
Procedure UpdateAdditionalAttributesItems()
	
	PropertiesManagement.UpdateAdditionalAttributesItems(ThisObject, FormAttributeToValue("Object"));
	
EndProcedure
// End StandardSubsystems.Property

#EndRegion

#Region DataImportFromExternalSources

&AtClient
Procedure LoadFromFileServices(Command)
	
	DataLoadSettings.FillingObjectFullName = "Document.SupplierInvoice.TabularSection.Expenses";
	
	DataLoadSettings.Insert("TabularSectionFullName", "SupplierInvoice.Expenses");
	DataLoadSettings.Insert("Title", NStr("en = 'Import services from file'"));
	
	NotifyDescription = New NotifyDescription("ImportDataFromExternalSourceResultDataProcessor", ThisObject, DataLoadSettings);
	
	DataImportFromExternalSourcesClient.ShowDataImportFormFromExternalSource(DataLoadSettings, NotifyDescription, ThisObject);
	
EndProcedure

&AtClient
Procedure LoadFromFileInventory(Command)
	
	DataLoadSettings.FillingObjectFullName = "Document.SupplierInvoice.TabularSection.Inventory";
	
	DataLoadSettings.Insert("TabularSectionFullName",	"SupplierInvoice.Inventory");
	DataLoadSettings.Insert("Title",					NStr("en = 'Import inventory from file'"));
	DataLoadSettings.Insert("OrderPositionInDocument",	Object.PurchaseOrderPosition);
	
	NotifyDescription = New NotifyDescription("ImportDataFromExternalSourceResultDataProcessor", ThisObject, DataLoadSettings);
	
	DataImportFromExternalSourcesClient.ShowDataImportFormFromExternalSource(DataLoadSettings, NotifyDescription, ThisObject);
	
EndProcedure

&AtClient
Procedure ImportDataFromExternalSourceResultDataProcessor(ImportResult, AdditionalParameters) Export
	
	If TypeOf(ImportResult) = Type("Structure") Then
		ProcessPreparedData(ImportResult);
		RefreshFormFooter();
	EndIf;
	
EndProcedure

&AtServer
Procedure ProcessPreparedData(ImportResult)
	
	DataImportFromExternalSourcesOverridable.ImportDataFromExternalSourceResultDataProcessor(ImportResult, Object);
	
EndProcedure
#EndRegion

#Region CopyPasteRows

&AtClient
Procedure InventoryCopyRows(Command)
	CopyRowsTabularPart("Inventory");
EndProcedure

&AtClient
Procedure CopyRowsTabularPart(TabularPartName)
	
	If TabularPartCopyClient.CanCopyRows(Object[TabularPartName],Items[TabularPartName].CurrentData) Then
		
		CountOfCopied = 0;
		CopyRowsTabularPartAtSever(TabularPartName, CountOfCopied);
		TabularPartCopyClient.NotifyUserCopyRows(CountOfCopied);
		
	EndIf;
	
EndProcedure

&AtServer 
Procedure CopyRowsTabularPartAtSever(TabularPartName, CountOfCopied)
	
	TabularPartCopyServer.Copy(Object[TabularPartName], Items[TabularPartName].SelectedRows, CountOfCopied);
	
EndProcedure

&AtClient
Procedure InventoryPasteRows(Command)
	PasteRowsTabularPart("Inventory");   
EndProcedure

&AtClient
Procedure PasteRowsTabularPart(TabularPartName)
	
	CountOfCopied = 0;
	CountOfPasted = 0;
	PasteRowsTabularPartAtServer(TabularPartName, CountOfCopied, CountOfPasted);
	ProcessPastedRows(TabularPartName, CountOfPasted);
	TabularPartCopyClient.NotifyUserPasteRows(CountOfCopied, CountOfPasted);
	
EndProcedure

&AtServer
Procedure PasteRowsTabularPartAtServer(TabularPartName, CountOfCopied, CountOfPasted)
	
	TabularPartCopyServer.Paste(Object, TabularPartName, Items, CountOfCopied, CountOfPasted);
	ProcessPastedRowsAtServer(TabularPartName, CountOfPasted);
	
EndProcedure

&AtClient
Procedure ProcessPastedRows(TabularPartName, CountOfPasted)
	
	If TabularPartName = "Inventory" Then
		
		Count = Object[TabularPartName].Count();
		
		For iterator = 1 To CountOfPasted Do
			
			Row = Object[TabularPartName][Count - iterator];
			CalculateAmountInTabularSectionLine(TabularPartName,Row);
			
		EndDo; 
		
	EndIf;
	           	
EndProcedure

&AtServer
Procedure ProcessPastedRowsAtServer(TabularPartName, CountOfPasted)
	
	Count = Object[TabularPartName].Count();
	
	For iterator = 1 To CountOfPasted Do
		
		Row = Object[TabularPartName][Count - iterator];
		
		StructData = New Structure;
		StructData.Insert("Company",        	  Object.Company);
		StructData.Insert("Products",  Row.Products);
		StructData.Insert("VATTaxation", 		  Object.VATTaxation);
		
		StructData = GetDataProductsOnChange(StructData); 
		
		If TabularPartName = "Inventory" Then
			
			Row.VATRate = StructData.VATRate;
			
		ElsIf TabularPartName = "Expenses" Then
			
			Row.MeasurementUnit = MainDepartment;
			
		EndIf;
		
		If Not ValueIsFilled(Row.MeasurementUnit) Then
			Row.MeasurementUnit = StructData.MeasurementUnit;
		EndIf;
		
		
	EndDo;
	//
EndProcedure

&AtClient
Procedure ExpensesCopyRows(Command)
	CopyRowsTabularPart("Expenses"); 
EndProcedure

&AtClient
Procedure ExpensesPasteRows(Command)
	PasteRowsTabularPart("Expenses"); 
EndProcedure

#EndRegion

&AtClient
Procedure InventorySerialNumbersStartChoice(Item, ChoiceData, StandardProcessing)
		
	StandardProcessing = False;
	OpenSerialNumbersSelection();
	
EndProcedure

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

&AtServer
Procedure SetTaxInvoiceText()
	Items.TaxInvoiceText.Visible = WorkWithVAT.GetUseTaxInvoiceForPostingVAT(Object.Date, Object.Company)
EndProcedure

#EndRegion

#EndRegion

ThisIsNewRow = False;