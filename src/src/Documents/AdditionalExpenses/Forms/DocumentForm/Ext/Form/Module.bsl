
#Region Variables

&AtClient
Var ThisIsNewRow;

#EndRegion

#Region GeneralPurposeProceduresAndFunctions

&AtClient
// Procedure handles change process of the Contract and contract currency documents attributes
//
Procedure HandleContractChangeProcessAndCurrenciesSettlements(DocumentParameters)
	
	ContractBeforeChange = DocumentParameters.ContractBeforeChange;
	SettlementsCurrencyBeforeChange = DocumentParameters.SettlementsCurrencyBeforeChange;
	ContractData = DocumentParameters.ContractData;
	OpenFormPricesAndCurrencies = DocumentParameters.OpenFormPricesAndCurrencies;
	
	If Not ContractData.AmountIncludesVAT = Undefined Then
		
		Object.AmountIncludesVAT = ContractData.AmountIncludesVAT;
		
	EndIf;
	
	If ValueIsFilled(Object.Contract) Then 
		
		Object.ExchangeRate	  = ?(ContractData.SettlementsCurrencyRateRepetition.ExchangeRate = 0, 1, ContractData.SettlementsCurrencyRateRepetition.ExchangeRate);
		Object.Multiplicity = ?(ContractData.SettlementsCurrencyRateRepetition.Multiplicity = 0, 1, ContractData.SettlementsCurrencyRateRepetition.Multiplicity);
		
	EndIf;
	
	Object.DocumentCurrency = ContractData.SettlementsCurrency;
	Order = Object.PurchaseOrder;
	
	If OpenFormPricesAndCurrencies Then
		
		WarningText = NStr("en = 'Settlement currency of the contract with counterparty changed.
		                   |It is necessary to check the document currency.'");
										
		ProcessChangesOnButtonPricesAndCurrencies(SettlementsCurrencyBeforeChange, True, WarningText);
		
	Else
		
		LabelStructure = New Structure("DocumentCurrency, SettlementsCurrency, ExchangeRate, RateNationalCurrency, AmountIncludesVAT, ForeignExchangeAccounting, VATTaxation", 
			Object.DocumentCurrency, 
			SettlementsCurrency, 
			Object.ExchangeRate, 
			RateNationalCurrency, 
			Object.AmountIncludesVAT, 
			ForeignExchangeAccounting, 
			Object.VATTaxation);
			
		PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
		
	EndIf;
	
	If DocumentParameters.Property("ChangeVariableSettlementsCurrency") Then
		
		SettlementsCurrency = ContractData.SettlementsCurrency;
		
	EndIf;
	
EndProcedure

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

// Procedure fills the column "Payment sum", etc. Inventory.
//
&AtServer
Procedure DistributeTabSectExpensesByQuantity()
	
	Document = FormAttributeToValue("Object");
	Document.DistributeTabSectExpensesByQuantity();
	ValueToFormAttribute(Document, "Object");
	FillAddedColumns();
	
EndProcedure

// Procedure fills the column "Payment sum", etc. Inventory.
//
&AtServer
Procedure DistributeTabSectExpensesByAmount()
	
	Document = FormAttributeToValue("Object");
	Document.DistributeTabSectExpensesByAmount();
	ValueToFormAttribute(Document, "Object");
	FillAddedColumns();
	
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

// Gets data set from server.
//
&AtServer
Function GetCompanyDataOnChange(Company)
	
	StructureData = New Structure;
	
	StructureData.Insert("Company", DriveServer.GetCompany(Company));
	
	TaxationBeforeChange = Object.VATTaxation;
	
	Object.VATTaxation = DriveServer.CounterpartyVATTaxation(Object.Counterparty, DriveServer.VATTaxation(Object.Company, Object.Date));
	
	If Not TaxationBeforeChange = Object.VATTaxation Then
		FillVATRateByVATTaxation();
	EndIf;
	FillAddedColumns(True);
	
	Return StructureData;
	
EndFunction

&AtServerNoContext
Function GetDataFromReceiptDocument(ReceiptDocument, Products, MeasurementUnit)
	
	Query = New Query;
		
	Query.Text =
	"SELECT
	|	SUM(SupplierInvoiceInventory.Quantity) AS Quantity,
	|	SUM(SupplierInvoiceInventory.Amount) AS Amount
	|FROM
	|	Document.SupplierInvoice.Inventory AS SupplierInvoiceInventory
	|WHERE
	|	SupplierInvoiceInventory.Ref = &Ref
	|	AND SupplierInvoiceInventory.Products = &Products
	|	AND SupplierInvoiceInventory.MeasurementUnit = &MeasurementUnit
	|
	|GROUP BY
	|	SupplierInvoiceInventory.MeasurementUnit,
	|	SupplierInvoiceInventory.VATRate
	|
	|UNION ALL
	|
	|SELECT
	|	SUM(ExpenseReportInventory.Quantity),
	|	SUM(ExpenseReportInventory.Amount)
	|FROM
	|	Document.ExpenseReport.Inventory AS ExpenseReportInventory
	|WHERE
	|	ExpenseReportInventory.Ref = &Ref
	|	AND ExpenseReportInventory.Products = &Products
	|	AND ExpenseReportInventory.MeasurementUnit = &MeasurementUnit
	|
	|GROUP BY
	|	ExpenseReportInventory.MeasurementUnit,
	|	ExpenseReportInventory.VATRate";
	
	Query.SetParameter("Ref", ReceiptDocument);
	Query.SetParameter("Products", Products);
	Query.SetParameter("MeasurementUnit", MeasurementUnit);
	
	SelectionOfQueryResult = Query.Execute().Select();
	
	StructureData = New Structure;
	
	If SelectionOfQueryResult.Next() Then
		StructureData.Insert("Quantity", SelectionOfQueryResult.Quantity);
		StructureData.Insert("Amount", SelectionOfQueryResult.Amount);
	Else
		StructureData.Insert("Quantity", 0);
		StructureData.Insert("Amount", 0);
	EndIf;
	
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
	
	If StructureData.Property("ReceiptDocument") Then
		StructureDataFromDocument = GetDataFromReceiptDocument(
			StructureData.ReceiptDocument,
			StructureData.Products,
			StructureData.Products.MeasurementUnit
		);
		StructureData.Insert("Quantity", StructureDataFromDocument.Quantity);
		StructureData.Insert("Amount", StructureDataFromDocument.Amount);
	EndIf;
	
	GLAccountsInDocuments.FillProductGLAccountsInStructure(StructureData);
	
	Return StructureData;
	
EndFunction

// Gets the data set from the server for procedure MeasurementUnitOnChange.
//
&AtServerNoContext
Function GetDataMeasurementUnitChoiceProcessing(CurrentMeasurementUnit = Undefined, MeasurementUnit = Undefined)
	
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

// It receives data set from the server for the CounterpartyOnChange procedure.
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
		"SettlementsInStandardUnits",
		ContractByDefault.SettlementsInStandardUnits
	);
	
	StructureData.Insert(
		"AmountIncludesVAT",
		?(ValueIsFilled(ContractByDefault.PriceKind), Contract.PriceKind.PriceIncludesVAT, Undefined)
	);
	
	SetContractVisible();
	
	Return StructureData;
	
EndFunction

// It receives data set from server for the ContractOnChange procedure.
//
&AtServerNoContext
Function GetDataContractOnChange(Date, DocumentCurrency, Contract)
	
	StructureData = New Structure;
	StructureData.Insert("SettlementsCurrency", Contract.SettlementsCurrency);
	StructureData.Insert("SettlementsCurrencyRateRepetition",
							InformationRegisters.ExchangeRates.GetLast(Date, New Structure("Currency", Contract.SettlementsCurrency)));
	StructureData.Insert("SettlementsInStandardUnits", 	Contract.SettlementsInStandardUnits);
	PriceKind = CommonUse.ObjectAttributeValue(Contract, "PriceKind");
	StructureData.Insert("AmountIncludesVAT",
							?(ValueIsFilled(PriceKind), CommonUse.ObjectAttributeValue(PriceKind, "PriceIncludesVAT"), Undefined));
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
			TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
			
		EndDo;	
		
		Items.ExpencesVATRate.Visible = True;
		Items.ExpencesAmountVAT.Visible = True;
		Items.TotalExpences.Visible = True;
		Items.ExpensesTotalVATSum.Visible = True;
		
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
			
			TabularSectionRow.Total = TabularSectionRow.Amount;
			
		EndDo;
		
		Items.ExpencesVATRate.Visible = False;
		Items.ExpencesAmountVAT.Visible = False;
		Items.TotalExpences.Visible = False;
		Items.ExpensesTotalVATSum.Visible = False;
		
		For Each TabularSectionRow In Object.Expenses Do
		
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
		TabularSectionRow.Amount - (TabularSectionRow.Amount) / ((VATRate + 100) / 100),
		TabularSectionRow.Amount * VATRate / 100
	);
	
EndProcedure

// Procedure calculates the amount in the row of tabular section.
//
&AtClient
Procedure CalculateAmountInTabularSectionLine(TabularSectionName = "Inventory", TabularSectionRow = Undefined)
	
	If TabularSectionRow = Undefined Then
		TabularSectionRow = Items[TabularSectionName].CurrentData;
	EndIf;
	
	TabularSectionRow.Amount = TabularSectionRow.Quantity * TabularSectionRow.Price;
	CalculateVATSUM(TabularSectionRow);
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
EndProcedure

// Recalculates the exchange rate and multiplicity of
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
	
	LabelStructure = New Structure("DocumentCurrency, SettlementsCurrency, ExchangeRate, RateNationalCurrency, AmountIncludesVAT, ForeignExchangeAccounting, VATTaxation", Object.DocumentCurrency, SettlementsCurrency, Object.ExchangeRate, RateNationalCurrency, Object.AmountIncludesVAT, ForeignExchangeAccounting, Object.VATTaxation);
	PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);

EndProcedure

// Procedure recalculates in the document tabular section after making
// changes in the "Prices and currency" form. The columns are
// recalculated as follows: price, discount, amount, VAT amount, total amount.
//
&AtClient
Procedure ProcessChangesOnButtonPricesAndCurrencies(Val SettlementsCurrencyBeforeChange, RecalculatePrices = False, WarningText = "")
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("DocumentCurrency",		Object.DocumentCurrency);
	ParametersStructure.Insert("ExchangeRate",				Object.ExchangeRate);
	ParametersStructure.Insert("Multiplicity",			Object.Multiplicity);
	ParametersStructure.Insert("VATTaxation",	Object.VATTaxation);
	ParametersStructure.Insert("AmountIncludesVAT",	Object.AmountIncludesVAT);
	ParametersStructure.Insert("IncludeVATInPrice",Object.IncludeVATInPrice);
	ParametersStructure.Insert("Counterparty",			Object.Counterparty);
	ParametersStructure.Insert("Contract",				Object.Contract);
	ParametersStructure.Insert("Company",			Company);
	ParametersStructure.Insert("DocumentDate",		Object.Date);
	ParametersStructure.Insert("RefillPrices",	False);
	ParametersStructure.Insert("RecalculatePrices",		RecalculatePrices);
	ParametersStructure.Insert("WereMadeChanges",False);
	ParametersStructure.Insert("WarningText",	WarningText);
	ParametersStructure.Insert("ReverseChargeNotApplicable", True);
	
	NotifyDescription = New NotifyDescription("OpenPricesAndCurrencyFormEnd", ThisObject, New Structure("SettlementsCurrencyBeforeChange", SettlementsCurrencyBeforeChange));
	OpenForm("CommonForm.PricesAndCurrency", ParametersStructure, ThisForm, , , , NotifyDescription, FormWindowOpeningMode.LockOwnerWindow);
	
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
		
		SettlementsCurrencyBeforeChange = SettlementsCurrency;
		SettlementsCurrency = ContractData.SettlementsCurrency;
		
		NewContractAndCalculationCurrency = ValueIsFilled(Object.Contract) AND ValueIsFilled(SettlementsCurrency) 
			AND Object.Contract <> ContractBeforeChange AND SettlementsCurrencyBeforeChange <> ContractData.SettlementsCurrency;
		
		OpenFormPricesAndCurrencies = NewContractAndCalculationCurrency AND Object.DocumentCurrency <> ContractData.SettlementsCurrency
			AND (Object.Inventory.Count() > 0 OR Object.Expenses.Count() > 0);
		
		DocumentParameters.Insert("ContractBeforeChange", ContractBeforeChange);
		DocumentParameters.Insert("SettlementsCurrencyBeforeChange", SettlementsCurrencyBeforeChange);
		DocumentParameters.Insert("ContractData", ContractData);
		DocumentParameters.Insert("OpenFormPricesAndCurrencies", OpenFormPricesAndCurrencies);
		
		If QueryBoxPrepayment = True Then
			
			QuestionText = NStr("en = 'Prepayment setoff will be cleared, continue?'");
			
			NotifyDescription = New NotifyDescription("DefineAdvancePaymentOffsetsRefreshNeed", ThisObject, DocumentParameters);
			ShowQueryBox(NotifyDescription, QuestionText, QuestionDialogMode.YesNo);
			
		Else
			
			HandleContractChangeProcessAndCurrenciesSettlements(DocumentParameters);
			
		EndIf;
		
		FillPaymentCalendarFromContract(SwitchTypeListOfPaymentCalendar);
		UpdatePaymentCalendar();
		
	Else
		
		Object.PurchaseOrder = Order;
		
	EndIf;
	
	Order = Object.PurchaseOrder;
	
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

	OpenForm("CommonForm.ProductGLAccounts", RowParameters, ThisForm);
	
EndProcedure

&AtClient
Procedure AddGLAccountsToStructure(StructureData, TabRow)
	
	StructureData.Insert("GLAccounts",				TabRow.GLAccounts);
	StructureData.Insert("GLAccountsFilled",		TabRow.GLAccountsFilled);
	
	If StructureData.TabName = "Inventory" Then
		StructureData.Insert("InventoryGLAccount",	TabRow.InventoryGLAccount)
	ElsIf StructureData.TabName = "Expenses" Then
		StructureData.Insert("VATInputGLAccount",	TabRow.VATInputGLAccount)
	EndIf;
	
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
	TabName = GLAccounts.TableName;
	
	If TabRow.Property("GLAccounts") Then
		ObjectParameters = GLAccountsInDocumentsClientServer.GetObjectParameters(Object);
		StructureData = GetStructureData(ObjectParameters, TabName, TabRow);
		
		GLAccountsInDocumentsClientServer.FillProductGLAccountsDescription(StructureData);
		FillPropertyValues(TabRow, StructureData);
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Function GetStructureData(ObjectParameters, TabName, RowData = Undefined, ProductName = "Products") Export
	
	If TabName = "Inventory" Then
		
		StructureData = New Structure("Products, InventoryGLAccount, GLAccounts, GLAccountsFilled");
		
	ElsIf TabName = "Expenses" Then
		
		StructureData = New Structure("Products, VATInputGLAccount, GLAccounts, GLAccountsFilled");
				
	EndIf;
	
	If RowData <> Undefined Then 
		FillPropertyValues(StructureData, RowData);
	EndIf;
		
	StructureData.Insert("ObjectParameters", ObjectParameters);
	StructureData.Insert("TabName", TabName);
	StructureData.Insert("ProductName", ProductName);
	
	Return StructureData;

EndFunction

#Region WorkWithTheSelection

// Procedure - event handler Action of the Pick command
//
&AtClient
Procedure ExpensesPick(Command)
	
	TabularSectionName	= "Expenses";
	DocumentPresentaion	= NStr("en = 'landed costs'");
	SelectionParameters	= DriveClient.GetSelectionParameters(ThisObject, TabularSectionName, DocumentPresentaion, False, False, False);
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

// Procedure - handler of the Action event of the PickByDocuments command
//
&AtClient
Procedure InventoryPickByDocuments(Command)
	
	TabularSectionName	= "Inventory";
	AreCharacteristics	= True;
	AreBatches			= True;
	PickupByDocuments	= True;
	
	SelectionParameters = New Structure;
	
	SelectionParameters.Insert("Period",				   Object.Date);
	SelectionParameters.Insert("Company",		   Company);
	SelectionParameters.Insert("VATTaxation",	   Object.VATTaxation);
	SelectionParameters.Insert("AmountIncludesVAT",	   Object.AmountIncludesVAT);
	SelectionParameters.Insert("DocumentOrganization",  Object.Company);
	
	ProductsType = New ValueList;
	For Each ArrayElement In Items[TabularSectionName + "Products"].ChoiceParameters Do
		If ArrayElement.Name = "Filter.ProductsType" Then
			If TypeOf(ArrayElement.Value) = Type("FixedArray") Then
				For Each FixArrayItem In ArrayElement.Value Do
					ProductsType.Add(FixArrayItem);
				EndDo; 
			Else
				ProductsType.Add(ArrayElement.Value);
			EndIf;
		EndIf;
	EndDo;
	SelectionParameters.Insert("ProductsType", ProductsType);
	
	BatchStatus = New ValueList;
	For Each ArrayElement In Items[TabularSectionName + "Batch"].ChoiceParameters Do
		If ArrayElement.Name = "Filter.Status" Then
			If TypeOf(ArrayElement.Value) = Type("FixedArray") Then
				For Each FixArrayItem In ArrayElement.Value Do
					BatchStatus.Add(FixArrayItem);
				EndDo; 
			Else
				BatchStatus.Add(ArrayElement.Value);
			EndIf;
		EndIf;
	EndDo;
	
	SelectionParameters.Insert("BatchStatus", BatchStatus);
	SelectionParameters.Insert("OwnerFormUUID", UUID);
	OpenForm("Document.AdditionalExpenses.Form.PickFormByDocuments", SelectionParameters);
	
EndProcedure

// Procedure gets the list of goods from the temporary storage
//
&AtServer
Procedure GetInventoryFromStorage(InventoryAddressInStorage, TabularSectionName, AreCharacteristics, AreBatches)
	
	TableForImport = GetFromTempStorage(InventoryAddressInStorage);
	
	For Each ImportRow In TableForImport Do
		
		NewRow = Object[TabularSectionName].Add();
		FillPropertyValues(NewRow, ImportRow);
		
	EndDo;
	
	Document = FormAttributeToValue("Object");
	GLAccountsInDocuments.FillTabSectionFromProductGLAccounts(Document);
	ValueToFormAttribute(Document, "Object");
	FillAddedColumns();
	
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
			
			InventoryAddressInStorage	= ClosingResult.CartAddressInStorage;
			
			GetInventoryFromStorage(InventoryAddressInStorage, "Expenses", False, False);
			
			ExpensesOnChange(Undefined);
			
		EndIf;
		
	EndIf;
	
EndProcedure
#EndRegion

#EndRegion

#Region ProcedureFormEventHandlers

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
	
	If Not ValueIsFilled(Object.Ref)
		  AND ValueIsFilled(Object.Counterparty)
	   AND Not ValueIsFilled(Parameters.CopyingValue) Then
		If Not ValueIsFilled(Object.Contract) Then
			Object.Contract = Object.Counterparty.ContractByDefault;
		EndIf;
		If ValueIsFilled(Object.Contract) Then
			Object.DocumentCurrency = Object.Contract.SettlementsCurrency;
			SettlementsCurrencyRateRepetition = InformationRegisters.ExchangeRates.GetLast(Object.Date, New Structure("Currency", Object.Contract.SettlementsCurrency));
			Object.ExchangeRate	  = ?(SettlementsCurrencyRateRepetition.ExchangeRate = 0, 1, SettlementsCurrencyRateRepetition.ExchangeRate);
			Object.Multiplicity = ?(SettlementsCurrencyRateRepetition.Multiplicity = 0, 1, SettlementsCurrencyRateRepetition.Multiplicity);
		EndIf;
	EndIf;
	
	// Form attributes setting.
	DocumentDate = Object.Date;
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentDate();
	EndIf;
	
	Company = DriveServer.GetCompany(Object.Company);
	Counterparty = Object.Counterparty;
	Contract = Object.Contract;
	Order = Object.PurchaseOrder;
	SettlementsCurrency = Object.Contract.SettlementsCurrency;
	FunctionalCurrency = Constants.FunctionalCurrency.Get();
	StructureByCurrency = InformationRegisters.ExchangeRates.GetLast(Object.Date, New Structure("Currency", FunctionalCurrency));
	RateNationalCurrency = StructureByCurrency.ExchangeRate;
	RepetitionNationalCurrency = StructureByCurrency.Multiplicity;
	DocumentSubtotal = Object.Expenses.Total("Total") - Object.Expenses.Total("VATAmount");
	
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
		Items.ExpensesTotalVATSum.Visible = True;
	Else
		Items.InventoryVATRate.Visible = False;
		Items.InventoryVATAmount.Visible = False;
		Items.InventoryAmountTotal.Visible = False;
		Items.ExpencesVATRate.Visible = False;
		Items.ExpencesAmountVAT.Visible = False;
		Items.TotalExpences.Visible = False;
		Items.ExpensesTotalVATSum.Visible = False;
	EndIf;
	
	FillAddedColumns();
	
	// Generate price and currency label.
	ForeignExchangeAccounting = Constants.ForeignExchangeAccounting.Get();
	LabelStructure = New Structure("DocumentCurrency, SettlementsCurrency, ExchangeRate, RateNationalCurrency, AmountIncludesVAT, ForeignExchangeAccounting, VATTaxation", Object.DocumentCurrency, SettlementsCurrency, Object.ExchangeRate, RateNationalCurrency, Object.AmountIncludesVAT, ForeignExchangeAccounting, Object.VATTaxation);
	PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
	
	// Setting contract visible.
	SetContractVisible();
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisForm, Items.ImportantCommandsGroup);
	// End StandardSubsystems.Printing
	
	SwitchTypeListOfPaymentCalendar = ?(Object.PaymentCalendar.Count() > 1, 1, 0);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	SetVisiblePaymentCalendar();
	SetVisibleCashAssetsTypes();
	SetEnableGroupPaymentCalendarDetails();
	
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

// Procedure - OnReadAtServer event handler.
//
&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	FillAddedColumns();
	ClosingDates.ObjectOnReadAtServer(ThisForm, CurrentObject);
	
	SetSwitchTypeListOfPaymentCalendar();
	
EndProcedure

// Procedure - event handler AfterWriting.
//
&AtClient
Procedure AfterWrite(WriteParameters)
	
	Notify("NotificationAboutChangingDebt");
	
EndProcedure

// Procedure - event handler of the form NotificationProcessing.
//
&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "AfterRecordingOfCounterparty" 
		AND ValueIsFilled(Parameter)
		AND Object.Counterparty = Parameter Then
		
		SetContractVisible();
		
	ElsIf EventName = "PickupOnDocumentsProduced"
		AND TypeOf(Parameter) = Type("Structure")
		// Check for the form owner
		AND Source = UUID
		Then
		
		AddNewPositionsIntoTableFooter = False;
		Parameter.Property("AddNewPositionsIntoTableFooter", AddNewPositionsIntoTableFooter);
		If Not AddNewPositionsIntoTableFooter Then
			
			Object.Inventory.Clear();
			
		EndIf;
		
		InventoryAddressInStorage = "";
		Parameter.Property("InventoryAddressInStorage", InventoryAddressInStorage);
		If ValueIsFilled(InventoryAddressInStorage) 
			AND InventoryAddressInStorage <> DialogReturnCode.Cancel Then
			
			GetInventoryFromStorage(InventoryAddressInStorage, "Inventory", True, True);
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region ProcedureActionsOfTheFormCommandPanels

// Procedure is called by clicking the PricesCurrency
// button of the command bar tabular field.
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
	
	If Object.Inventory.Count() = 0 Then
		DriveClient.ShowMessageAboutError(Object, NStr("en = 'No records in tabular section ""Inventory"".'"));
		Return;
	EndIf;
	
	If Object.Expenses.Count() = 0 Then
		DriveClient.ShowMessageAboutError(Object, NStr("en = 'There are no records in the tabular section ""Services"".'"));
		Return;
	EndIf;
	
	DistributeTabSectExpensesByQuantity();
	
EndProcedure

// Procedure - command handler of the tabular section command panel.
//
&AtClient
Procedure DistributeExpensesByAmount(Command)
	
	If Object.Inventory.Count() = 0 Then
		DriveClient.ShowMessageAboutError(Object, NStr("en = 'No records in tabular section ""Inventory"".'"));
		Return;
	EndIf;
	
	If Object.Expenses.Count() = 0 Then
		DriveClient.ShowMessageAboutError(Object, NStr("en = 'There are no records in the tabular section ""Services"".'"));
		Return;
	EndIf;
	
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
		?(CounterpartyDoSettlementsByOrders, Object.PurchaseOrder, Undefined), // Order
		Object.Date, // Date
		Object.Ref, // Ref
		Object.Counterparty, // Counterparty
		Object.Contract, // Contract
		Object.ExchangeRate, // ExchangeRate
		Object.Multiplicity, // Multiplicity
		Object.DocumentCurrency, // DocumentCurrency
		Object.Expenses.Total("Total")
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
		StructureData = GetDataDateOnChange(Object.Ref, Object.Date, DateBeforeChange, SettlementsCurrency);
		If StructureData.DATEDIFF <> 0 Then
			Object.Number = "";
		EndIf;
		
		If ValueIsFilled(SettlementsCurrency) Then
			RecalculateExchangeRateMultiplicitySettlementCurrency(StructureData);
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
	Company = StructureData.Company;
	
	Object.Contract = GetContractByDefault(Object.Ref, Object.Counterparty, Object.Company);
	ProcessContractChange();
	
	LabelStructure = New Structure("DocumentCurrency, ExchangeRate, AmountIncludesVAT, ForeignExchangeAccounting, VATTaxation", 
		Object.DocumentCurrency, Object.ExchangeRate, Object.AmountIncludesVAT, ForeignExchangeAccounting, Object.VATTaxation);
	
	PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
	
	If Object.SetPaymentTerms
		AND ValueIsFilled(Object.CashAssetsType) Then
		
		RecalculatePaymentCalendar();
		FillPaymentScedule();
		
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
		
		DataStructure = GetDataCounterpartyOnChange(Object.Date, Object.DocumentCurrency, Object.Counterparty, Object.Company);
		Object.Contract = DataStructure.Contract;
		
		DataStructure.Insert("CounterpartyBeforeChange", CounterpartyBeforeChange);
		DataStructure.Insert("CounterpartyDoSettlementsByOrdersBeforeChange", CounterpartyDoSettlementsByOrdersBeforeChange);
		
		ProcessContractChange(DataStructure);
		
	Else
		
		Object.Contract = Contract; // Restore the cleared contract automatically.
		Object.PurchaseOrder = Order;
		
	EndIf;
	
	Order = Object.PurchaseOrder;
	
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

// Procedure - handler of the OnChange event of PurchaseOrder input field.
//
&AtClient
Procedure PurchaseOrderOnChange(Item)
	
	If Object.Prepayment.Count() > 0
	   AND Object.PurchaseOrder <> Order
	   AND CounterpartyDoSettlementsByOrders Then
		Mode = QuestionDialogMode.YesNo;
		Response = Undefined;

		ShowQueryBox(New NotifyDescription("PurchaseOrderOnChangeEnd", ThisObject), NStr("en = 'Prepayment setoff will be cleared, continue?'"), Mode, 0);
		Return;
	EndIf;
	
	PurchaseOrderOnChangeFragment();
EndProcedure

&AtClient
Procedure PurchaseOrderOnChangeEnd(Result, AdditionalParameters) Export
	
	Response = Result;
	If Response = DialogReturnCode.Yes Then
		Object.Prepayment.Clear();
	Else
		Object.PurchaseOrder = Order;
		Return;
	EndIf;
	
	PurchaseOrderOnChangeFragment();

EndProcedure

&AtClient
Procedure PurchaseOrderOnChangeFragment()
	
	Order = Object.PurchaseOrder;

EndProcedure

&AtClient
Procedure StructuralUnitOnChange(Item)
	FillAddedColumns(True);
EndProcedure

#Region EventHandlersOfTheCostsTabularSectionAttributes

// Procedure - event handler OnChange of the any input field.
//
&AtClient
Procedure ExpensesOnChange(Item)
	
	DocumentSubtotal = Object.Expenses.Total("Total") - Object.Expenses.Total("VATAmount");
	
	RecalculatePaymentCalendar();
	
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
		StructureData = GetDataMeasurementUnitChoiceProcessing(TabularSectionRow.MeasurementUnit, ValueSelected);
	ElsIf CurrentFactor = 0 Then
		StructureData = GetDataMeasurementUnitChoiceProcessing(TabularSectionRow.MeasurementUnit);
	ElsIf Factor = 0 Then
		StructureData = GetDataMeasurementUnitChoiceProcessing(,ValueSelected);
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
	
EndProcedure

// Procedure - event handler OnChange of the VATRate input field.
//
&AtClient
Procedure ExpensesVATRateOnChange(Item)
	
	TabularSectionRow = Items.Expenses.CurrentData;
	
	CalculateVATSUM(TabularSectionRow);
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
EndProcedure

&AtClient
Procedure ExpensesOnStartEdit(Item, NewRow, Clone)
	
	If Not NewRow Or Clone Then
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
	
	CurrentData = Items.Expenses.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If ThisIsNewRow Then
		TableCurrentColumn = Items.Expenses.CurrentItem;
		If TableCurrentColumn.Name = "ExpensesGLAccounts"
			And Not CurrentData.GLAccountsFilled Then
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

// Procedure - event handler OnChange of the VATRate input field.
//
&AtClient
Procedure AmountExpensesVATOnChange(Item)
	
	TabularSectionRow = Items.Expenses.CurrentData;
	
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
EndProcedure

// Procedure - handler of the OnChange event of the Coefficient field of the Inventory table.
//
&AtClient
Procedure InventoryFactorOnChange(Item)
		
	VATExpenses = 0;
	If NOT Object.IncludeVATInPrice Then
		VATExpenses = Object.Expenses.Total("VATAmount");
	EndIf;	 	
	
	SrcAmount			= 0;
	DistributionBase	= Object.Inventory.Total("Factor");
	TotalExpenses		= Object.Expenses.Total("Total") - VATExpenses;
	
	For Each StringInventory In Object.Inventory Do
		StringInventory.AmountExpense = ?(DistributionBase <> 0, Round((TotalExpenses - SrcAmount) * StringInventory.Factor / DistributionBase, 2, 1),0);
		DistributionBase = DistributionBase - StringInventory.Factor;
		SrcAmount = SrcAmount + StringInventory.AmountExpense;
	EndDo;
	
EndProcedure

// Procedure - handler of the OnChange event of the ReceiptDocument attribute.
//
&AtClient
Procedure InventoryIncreaseDocumentOnChange(Item)
	
	CurrentRow = Items.Inventory.CurrentData;
	If Not ValueIsFilled(CurrentRow.Factor) Then
		
		CurrentRow.Factor = 1;
		
	EndIf;
	
EndProcedure

// Procedure - handler of the OnChange event of the Products attribute.
//
&AtClient
Procedure InventoryProductsOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("Company", Object.Company);
	StructureData.Insert("Products", TabularSectionRow.Products);
	StructureData.Insert("VATTaxation", Object.VATTaxation);
	StructureData.Insert("TabName", "Inventory");
	
	AddGLAccountsToStructure(StructureData, TabularSectionRow);	
	StructureData.Insert("ObjectParameters", GLAccountsInDocumentsClientServer.GetObjectParameters(Object));
	StructureData = GetDataProductsOnChange(StructureData);
	
	FillPropertyValues(TabularSectionRow, StructureData); 
	TabularSectionRow.MeasurementUnit	= StructureData.MeasurementUnit;
	TabularSectionRow.Quantity			= 1;
	TabularSectionRow.Factor		= 1;
	TabularSectionRow.Price				= 0;
	TabularSectionRow.Amount				= 0;
	TabularSectionRow.VATRate			= StructureData.VATRate;
	TabularSectionRow.VATAmount			= 0;
	TabularSectionRow.Total				= 0;
	
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

// Procedure - event handler OnChange of the Count input field.
//
&AtClient
Procedure InventoryQuantityOnChange(Item)
	
	CalculateAmountInTabularSectionLine("Inventory");
	
EndProcedure

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

#EndRegion

#Region GeneralPurposeProceduresAndFunctionsOfPaymentCalendar

&AtServer
Procedure FillThePaymentCalendarOnServer()
	
	FillPaymentCalendarFromContract(SwitchTypeListOfPaymentCalendar);
	
	If Object.PaymentCalendar.Count() = 0 Then
		NewRow = Object.PaymentCalendar.Add();
		
		NewRow.PaymentPercentage = 100;
		NewRow.PaymentAmount = Object.Expenses.Total("Amount");
		NewRow.PaymentVATAmount = Object.Expenses.Total("VATAmount");
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
	
	VATForPaymentCalendar = Object.Expenses.Total("VATAmount");
	
	Return VATForPaymentCalendar;
	
EndFunction

&AtClient
Function AmountForPaymentCalendar()
	
	AmountForPaymentCalendar = Object.Expenses.Total("Amount");
	
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
	
	CurrentRow.PaymentAmount = Round(Object.Expenses.Total("Amount") * CurrentRow.PaymentPercentage / 100, 2, 1);
	CurrentRow.PaymentVATAmount = Round(Object.Expenses.Total("VATAmount") * CurrentRow.PaymentPercentage / 100, 2, 1);
	
EndProcedure

// Procedure - event handler OnChange of the PaymentCalendarPaymentAmount input field.
//
&AtClient
Procedure PaymentCalendarPaymentSumOnChange(Item)
	
	CurrentRow = Items.PaymentCalendar.CurrentData;
	
	InventoryTotal = Object.Expenses.Total("Amount");
	
	CurrentRow.PaymentPercentage = ?(InventoryTotal = 0, 0, Round(CurrentRow.PaymentAmount / InventoryTotal * 100, 2, 1));
	CurrentRow.PaymentVATAmount = Round(Object.Expenses.Total("VATAmount") * CurrentRow.PaymentPercentage / 100, 2, 1);
	
EndProcedure

// Procedure - event handler OnChange of the PaymentCalendarPayVATAmount input field.
//
&AtClient
Procedure PaymentCalendarPayVATAmountOnChange(Item)
	
	CurrentRow = Items.PaymentCalendar.CurrentData;
	
	InventoryTotal = Object.Expenses.Total("VATAmount");
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
		CurrentRow.PaymentAmount = Object.Expenses.Total("Amount") - Object.PaymentCalendar.Total("PaymentAmount");
		CurrentRow.PaymentVATAmount = Object.Expenses.Total("VATAmount") - Object.PaymentCalendar.Total("PaymentVATAmount");
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
	IncomingDocumentDate = ?(Object.IncomingDocumentDate=Date(1,1,1), Object.Date, Object.IncomingDocumentDate);
EndProcedure

&AtClient
Procedure IncomingDocumentDateOnChange(Item)
	IncomingDocumentDateBeforeChange = IncomingDocumentDate;
	IncomingDocumentDate = Object.IncomingDocumentDate;
	
	If IncomingDocumentDateBeforeChange <> Object.IncomingDocumentDate
		AND ValueIsFilled(IncomingDocumentDateBeforeChange) Then
		
		Delta = Object.IncomingDocumentDate - IncomingDocumentDateBeforeChange;
		
		For Each Line In Object.PaymentCalendar Do
			
			Line.PaymentDate = Line.PaymentDate + Delta;
			
		EndDo;
		
		MessageString = NStr("en = 'The Payment terms tab was changed'");
		CommonUseClientServer.MessageToUser(MessageString);
		
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
		SettlementsCurrencyBeforeChange = AdditionalParameters.SettlementsCurrencyBeforeChange;
		
		// Recalculate prices by currency.
		If ClosingResult.RecalculatePrices Then
			
			DriveClient.RecalculateTabularSectionPricesByCurrency(ThisForm, SettlementsCurrencyBeforeChange, "Inventory");
			DriveClient.RecalculateTabularSectionPricesByCurrency(ThisForm, SettlementsCurrencyBeforeChange, "Expenses");
			
		EndIf;
		
		// Recalculate the amount if VAT taxation flag is changed.
		If ClosingResult.VATTaxation <> ClosingResult.PrevVATTaxation Then
			
			FillVATRateByVATTaxation();
			
		EndIf;
		
		// Recalculate the amount if the "Amount includes VAT" flag is changed.
		If ClosingResult.AmountIncludesVAT <> ClosingResult.PrevAmountIncludesVAT Then
			
			DriveClient.RecalculateTabularSectionAmountByFlagAmountIncludesVAT(ThisForm, "Expenses");
			
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
		
	EndIf;
	
	LabelStructure = New Structure("DocumentCurrency, SettlementsCurrency, ExchangeRate, RateNationalCurrency, AmountIncludesVAT, ForeignExchangeAccounting, VATTaxation",
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

&AtClient
// Procedure-handler of the answer to the question about repeated advances offset
//
Procedure DefineAdvancePaymentOffsetsRefreshNeed(ClosingResult, AdditionalParameters) Export
	
	If ClosingResult = DialogReturnCode.Yes Then
		
		Object.Prepayment.Clear();
		HandleContractChangeProcessAndCurrenciesSettlements(AdditionalParameters);
		
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

#Region Initialize

ThisIsNewRow = False;

#EndRegion