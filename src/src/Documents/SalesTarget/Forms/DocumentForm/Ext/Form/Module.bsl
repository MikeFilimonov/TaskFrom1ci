
#Region GeneralPurposeProceduresAndFunctions

&AtServer
// It receives data set from server for the DateOnChange procedure.
//
Function GetDataDateOnChange(DateBeforeChange)
	
	DATEDIFF = DriveServer.CheckDocumentNumber(Object.Ref, Object.Date, DateBeforeChange);
	CurrencyRateRepetition = InformationRegisters.ExchangeRates.GetLast(Object.Date, New Structure("Currency", Object.DocumentCurrency));
	
	StructureData = New Structure();
	
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
// Receives the data set from the server for the CompanyOnChange procedure.
//
Function GetCompanyDataOnChange()
	
	StructureData = New Structure();
	StructureData.Insert("Counterparty", DriveServer.GetCompany(Object.Company));
	
	FillVATRateByCompanyVATTaxation();
	
	Return StructureData;
	
EndFunction

&AtServer
// Procedure fills the VAT rate in the tabular section
// according to company's taxation system.
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
			TabularSectionRow.VATAmount = ?(Object.AmountIncludesVAT, 
									  		TabularSectionRow.Amount - (TabularSectionRow.Amount) / ((VATRate + 100) / 100),
									  		TabularSectionRow.Amount * VATRate / 100);
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

&AtServerNoContext
// Receives the set of data from the server for the ProductsOnChange procedure.
//
Function GetDataProductsOnChange(StructureData)
	
	StructureData.Insert("MeasurementUnit", StructureData.Products.MeasurementUnit);
	
	If Not StructureData.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then
		
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
			
	Return StructureData;
	
EndFunction

&AtServerNoContext
// It receives data set from server for the CharacteristicOnChange procedure.
//
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

&AtServerNoContext
// Gets the data set from the server for procedure MeasurementUnitAtChange.
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
	
EndProcedure

&AtClient
// The procedure calculates the rate and ratio of
// the document currency when changing the document date.
//
Procedure RecalculateRateRepetitionOfDocumentCurrency(StructureData)
	
	NewExchangeRate = ?(StructureData.CurrencyRateRepetition.ExchangeRate = 0, 1, StructureData.CurrencyRateRepetition.ExchangeRate);
	NewRatio = ?(StructureData.CurrencyRateRepetition.Multiplicity = 0, 1, StructureData.CurrencyRateRepetition.Multiplicity);
	
	If Object.ExchangeRate <> NewExchangeRate
		OR Object.Multiplicity <> NewRatio Then
		
		CurrencyRateInLetters = String(Object.Multiplicity) + " " + TrimAll(Object.DocumentCurrency) + " = " + String(Object.ExchangeRate) + " " + TrimAll(FunctionalCurrency);
		RateNewCurrenciesInLetters = String(NewRatio) + " " + TrimAll(Object.DocumentCurrency) + " = " + String(NewExchangeRate) + " " + TrimAll(FunctionalCurrency);
		
		QuestionParameters = New Structure;
		QuestionParameters.Insert("NewExchangeRate", NewExchangeRate);
		QuestionParameters.Insert("NewRatio", NewRatio);
		
		NotifyDescription = New NotifyDescription("QuestionOnRecalculatingPaymentCurrencyRateConversionFactorEnd", ThisObject, QuestionParameters);
		
		QuestionText = StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en = 'Current exchange rate is %1. Exchange rate for selected date is %2. Do you want to apply new exchange rate?'"),
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
		
		// Generate price and currency label.
		LabelStructure = New Structure("PriceKind, DocumentCurrency, ExchangeRate, AmountIncludesVAT, ForeignExchangeAccounting, VATTaxation", Object.PriceKind, Object.DocumentCurrency, Object.ExchangeRate, Object.AmountIncludesVAT, ForeignExchangeAccounting, Object.VATTaxation);
		PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
		
	EndIf;

EndProcedure

&AtClient
// Procedure recalculates in the document tabular section after making
// changes in the "Prices and currency" form. The columns are
// recalculated as follows: price, discount, amount, VAT amount, total amount.
//
Procedure ProcessChangesOnButtonPricesAndCurrencies()
	
	// 1. Form parameter structure to fill the "Prices and Currency" form.
	ParametersStructure = New Structure;
	ParametersStructure.Insert("PriceKind", Object.PriceKind);
	ParametersStructure.Insert("DocumentCurrency", Object.DocumentCurrency);
	ParametersStructure.Insert("VATTaxation", Object.VATTaxation);
	ParametersStructure.Insert("AmountIncludesVAT", Object.AmountIncludesVAT);
	ParametersStructure.Insert("IncludeVATInPrice", Object.IncludeVATInPrice);
	
	ParametersStructure.Insert("Company",	ParentCompany); 
	ParametersStructure.Insert("DocumentDate", Object.Date);
	
	ParametersStructure.Insert("RefillPrices", False);
	ParametersStructure.Insert("RecalculatePrices", False);
	ParametersStructure.Insert("WereMadeChanges", False);
	ParametersStructure.Insert("ReverseChargeNotApplicable", True);
	
	StructurePricesAndCurrency = Undefined;
	
	OpenForm("CommonForm.PricesAndCurrency", ParametersStructure,,,,, New NotifyDescription("ProcessChangesOnButtonPricesAndCurrenciesEnd", ThisObject));
	
EndProcedure

&AtClient
Procedure ProcessChangesOnButtonPricesAndCurrenciesEnd(Result, AdditionalParameters) Export
    
    // 2. Open the form "Prices and Currency".
    StructurePricesAndCurrency = Result;
    
    // 3. Refills tabular section "Costs" if changes were made in the "Price and Currency" form.
    If TypeOf(StructurePricesAndCurrency) = Type("Structure") AND StructurePricesAndCurrency.WereMadeChanges Then
        
        Modified = True;
        
        Object.PriceKind = StructurePricesAndCurrency.PriceKind;
        Object.DocumentCurrency = StructurePricesAndCurrency.DocumentCurrency;
        Object.ExchangeRate = StructurePricesAndCurrency.ExchangeRate;
        Object.Multiplicity = StructurePricesAndCurrency.Multiplicity;
        Object.VATTaxation = StructurePricesAndCurrency.VATTaxation;
        Object.AmountIncludesVAT = StructurePricesAndCurrency.AmountIncludesVAT;
        Object.IncludeVATInPrice = StructurePricesAndCurrency.IncludeVATInPrice;
        
        // Recalculate prices by kind of prices.
        If StructurePricesAndCurrency.RefillPrices Then
            DriveClient.RefillTabularSectionPricesByPriceKind(ThisForm, "Inventory");
        EndIf;
        
        // Recalculate prices by currency.
        If Not StructurePricesAndCurrency.RefillPrices
            AND StructurePricesAndCurrency.RecalculatePrices Then
            DriveClient.RecalculateTabularSectionPricesByCurrency(ThisForm, StructurePricesAndCurrency.PrevCurrencyOfDocument, "Inventory");
        EndIf;
        
        // Recalculate the amount if VAT taxation flag is changed.
        If StructurePricesAndCurrency.VATTaxation <> StructurePricesAndCurrency.PrevVATTaxation Then
            FillVATRateByVATTaxation();
        EndIf;
        
        // Recalculate the amount if the "Amount includes VAT" flag is changed.
        If Not StructurePricesAndCurrency.RefillPrices
            AND Not StructurePricesAndCurrency.AmountIncludesVAT = StructurePricesAndCurrency.PrevAmountIncludesVAT Then
            DriveClient.RecalculateTabularSectionAmountByFlagAmountIncludesVAT(ThisForm, "Inventory");
        EndIf;
        
    EndIf;
    
    LabelStructure = New Structure("PriceKind, DocumentCurrency, ExchangeRate, AmountIncludesVAT, ForeignExchangeAccounting, VATTaxation", Object.PriceKind, Object.DocumentCurrency, Object.ExchangeRate, Object.AmountIncludesVAT, ForeignExchangeAccounting, Object.VATTaxation);
    PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);

EndProcedure

&AtServer
// Procedure receives the planning period data.
//
Procedure GetPlanningPeriodData()
	
	Periodicity = Object.PlanningPeriod.Periodicity;
	StartDate = Object.PlanningPeriod.StartDate;
	EndDate = Object.PlanningPeriod.EndDate;
	
EndProcedure

&AtClient
// Procedure adjusts the planning date to the planning period.
//
Procedure AlignPlanningDateByPlanningPeriod(PlanningDate)
	
	If Periodicity = PredefinedValue("Enum.Periodicity.Day") Then
	
	ElsIf Periodicity = PredefinedValue("Enum.Periodicity.Week") Then
		
		PlanningDate = BegOfWeek(PlanningDate);
		
	ElsIf Periodicity = PredefinedValue("Enum.Periodicity.TenDays") Then
		
		If Day(PlanningDate) < 11 Then
			
			PlanningDate = Date(Year(PlanningDate), Month(PlanningDate), 1);
			
		ElsIf Day(PlanningDate) < 21 Then
			
			PlanningDate = Date(Year(PlanningDate), Month(PlanningDate), 11);
			
		Else
			
			PlanningDate = Date(Year(PlanningDate), Month(PlanningDate), 21);
			
		EndIf;
		
	ElsIf Periodicity = PredefinedValue("Enum.Periodicity.Month") Then
		
		PlanningDate = BegOfMonth(PlanningDate);
		
	ElsIf Periodicity = PredefinedValue("Enum.Periodicity.Quarter") Then
		
		PlanningDate = BegOfQuarter(PlanningDate);
		
	ElsIf Periodicity = PredefinedValue("Enum.Periodicity.HalfYear") Then
		
		MonthOfStartDate = Month(PlanningDate);
		
		PlanningDate = BegOfYear(PlanningDate);
		
		If MonthOfStartDate > 6 Then
			
			PlanningDate = AddMonth(PlanningDate, 6);
			
		EndIf;
		
	ElsIf Periodicity = PredefinedValue("Enum.Periodicity.Year") Then
		
		PlanningDate = BegOfYear(PlanningDate);
		
	Else
		
		PlanningDate = '00010101';
		
	EndIf;
	
	If StartDate <> '00010101'
		AND (PlanningDate < StartDate
		OR PlanningDate > EndDate) Then
		
		PlanningDate = StartDate;
		
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
	
	For Each CurBarcode In StructureData.BarcodesArray Do
		BarcodeData = StructureData.DataByBarCodes[CurBarcode.Barcode];
		
		If BarcodeData <> Undefined
		   AND BarcodeData.Count() = 0 Then
			UnknownBarcodes.Add(CurBarcode);
		Else
			TSRowsArray = Object.Inventory.FindRows(New Structure("Products,Characteristic,MeasurementUnit",BarcodeData.Products,BarcodeData.Characteristic,BarcodeData.MeasurementUnit));
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

// Procedure recalculates subtotal the document on client.
&AtClient
Procedure RecalculateSubtotal()
	
	DocumentSubtotal = Object.Inventory.Total("Total") - Object.Inventory.Total("VATAmount");
	
EndProcedure

// End Peripherals

#Region WorkWithSelection

&AtClient
// Procedure - event handler Action of the Pick command
//
Procedure Pick(Command)
	
	TabularSectionName	= "Inventory";
	DocumentPresentaion	= NStr("en = 'sales target'");
	SelectionParameters	= DriveClient.GetSelectionParameters(ThisObject, TabularSectionName, DocumentPresentaion, False, True, False);
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
			CalculateAmountInTabularSectionLine(TabularSectionRow);
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

&AtServer
// Function gets a product list from the temporary storage
//
Procedure GetInventoryFromStorage(InventoryAddressInStorage, TabularSectionName, AreCharacteristics, AreBatches)
	
	TableForImport = GetFromTempStorage(InventoryAddressInStorage);
	
	For Each ImportRow In TableForImport Do
		
		NewRow = Object[TabularSectionName].Add();
		FillPropertyValues(NewRow, ImportRow);
		
	EndDo;
	
EndProcedure

// Procedure of processing the results of selection closing
//
&AtClient
Procedure OnCloseSelection(ClosingResult, AdditionalParameters) Export
	
	If TypeOf(ClosingResult) = Type("Structure") Then
		
		If Not IsBlankString(ClosingResult.CartAddressInStorage) Then
			
			InventoryAddressInStorage = ClosingResult.CartAddressInStorage;
			
			GetInventoryFromStorage(InventoryAddressInStorage, "Inventory", True, False);
			
			RecalculateSubtotal();
			
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
	
	DriveServer.FillDocumentHeader(Object,
		,
		Parameters.CopyingValue,
		Parameters.Basis,
		PostingIsAllowed
	);
	
	// Form attributes setting.
	DocumentDate = Object.Date;
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentDate();
	EndIf;
	
	ParentCompany = DriveServer.GetCompany(Object.Company);
	
	GetPlanningPeriodData();
	
	FunctionalCurrency = Constants.FunctionalCurrency.Get();
	
	If Not ValueIsFilled(Object.Ref)
		AND Not ValueIsFilled(Parameters.Basis) 
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
	
	// Generate price and currency label.
	ForeignExchangeAccounting = Constants.ForeignExchangeAccounting.Get();
	LabelStructure = New Structure("PriceKind, DocumentCurrency, ExchangeRate, AmountIncludesVAT, ForeignExchangeAccounting, VATTaxation", Object.PriceKind, Object.DocumentCurrency, Object.ExchangeRate, Object.AmountIncludesVAT, ForeignExchangeAccounting, Object.VATTaxation);
	PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
	
	// Price accessibility setup for editing.
	AllowedEditDocumentPrices = DriveAccessManagementReUse.AllowedEditDocumentPrices();
	
	Items.InventoryPrice.ReadOnly	   = Not AllowedEditDocumentPrices;
	Items.InventoryAmount.ReadOnly	   = Not AllowedEditDocumentPrices;
	Items.InventoryVATAmount.ReadOnly = Not AllowedEditDocumentPrices;
	
	// StandardSubsystems.ObjectVersioning
	ObjectVersioning.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.ObjectVersioning
	
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
	
EndProcedure

#EndRegion

#Region ProcedureActionsOfTheFormCommandPanels

&AtClient
// Procedure is called by clicking the PricesCurrency
// button of the command bar tabular field.
//
Procedure EditPricesAndCurrency(Item, StandardProcessing)
	
	StandardProcessing = False;
	ProcessChangesOnButtonPricesAndCurrencies();
	Modified = True;
	
EndProcedure

#EndRegion

#Region ProcedureEventHandlersOfHeaderAttributes

&AtClient
// Procedure - event handler OnChange of the Date input field.
// The procedure determines the situation when after changing the date
// of a document this document is found in another period
// of documents enumeration, and in this case the procedure assigns new unique number to the document.
// Overrides the corresponding form parameter.
//
Procedure DateOnChange(Item)
	
	// Date change event DataProcessor.
	DateBeforeChange = DocumentDate;
	DocumentDate = Object.Date;
	If Object.Date <> DateBeforeChange Then
		StructureData = GetDataDateOnChange(DateBeforeChange);
		If StructureData.DATEDIFF <> 0 Then
			Object.Number = "";
		EndIf;
		
		If ValueIsFilled(Object.DocumentCurrency) Then
			RecalculateRateRepetitionOfDocumentCurrency(StructureData);
		EndIf;
		
		LabelStructure = New Structure("PriceKind, DocumentCurrency, ExchangeRate, AmountIncludesVAT, ForeignExchangeAccounting, VATTaxation", Object.PriceKind, Object.DocumentCurrency, Object.ExchangeRate, Object.AmountIncludesVAT, ForeignExchangeAccounting, Object.VATTaxation);
		PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
		
	EndIf;
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of the Company input field.
// In procedure the document number
// is cleared, and also the form functional options are configured.
// Overrides the corresponding form parameter.
//
Procedure CompanyOnChange(Item)

	// Company change event data processor.
	Object.Number = "";
	StructureData = GetCompanyDataOnChange();
	Counterparty = StructureData.Counterparty;
	
	LabelStructure = New Structure("PriceKind, DocumentCurrency, ExchangeRate, AmountIncludesVAT, ForeignExchangeAccounting, VATTaxation", Object.PriceKind, Object.DocumentCurrency, Object.ExchangeRate, Object.AmountIncludesVAT, ForeignExchangeAccounting, Object.VATTaxation);
	PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
	
EndProcedure

&AtClient
// Procedure - handler of event OnChange of input field PlanningPeriod.
//
Procedure PlanningPeriodOnChange(Item)
	
	GetPlanningPeriodData();	
	
	For Each TabularSectionRow In Object.Inventory Do
		
		AlignPlanningDateByPlanningPeriod(TabularSectionRow.PlanningDate);
		
	EndDo;	
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - TABULAR SECTION ATTRIBUTE EVENT HANDLERS

&AtClient
// Procedure - event handler OnChange of the Products input field.
//
Procedure InventoryProductsOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("Company", Object.Company);
	StructureData.Insert("Products", TabularSectionRow.Products);
	StructureData.Insert("VATTaxation", Object.VATTaxation);
	
	If ValueIsFilled(Object.PriceKind) Then
		
		StructureData.Insert("ProcessingDate", 		Object.Date);
		StructureData.Insert("PriceKind", 				Object.PriceKind);
		StructureData.Insert("DocumentCurrency", 	Object.DocumentCurrency);
		StructureData.Insert("AmountIncludesVAT", 	Object.AmountIncludesVAT);
		StructureData.Insert("Characteristic", 		TabularSectionRow.Characteristic);
		StructureData.Insert("Factor", 		1);
        		
	EndIf;	
	
	StructureData = GetDataProductsOnChange(StructureData);
	
	TabularSectionRow.MeasurementUnit = StructureData.MeasurementUnit;
	TabularSectionRow.Quantity = 1;
	TabularSectionRow.Price = StructureData.Price;
	TabularSectionRow.VATRate = StructureData.VATRate;
	
	CalculateAmountInTabularSectionLine();
	RecalculateSubtotal();
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of the Characteristic input field.
//
Procedure InventoryCharacteristicOnChange(Item)
	
	If ValueIsFilled(Object.PriceKind) Then
	
		TabularSectionRow = Items.Inventory.CurrentData;
		
		StructureData = New Structure;
		StructureData.Insert("ProcessingDate", 		Object.Date);
		StructureData.Insert("PriceKind", 				Object.PriceKind);
		StructureData.Insert("DocumentCurrency", 	Object.DocumentCurrency);
		StructureData.Insert("AmountIncludesVAT", 	Object.AmountIncludesVAT);
		
		StructureData.Insert("VATRate", 			TabularSectionRow.VATRate);
		StructureData.Insert("Products", 		TabularSectionRow.Products);
		StructureData.Insert("Characteristic", 		TabularSectionRow.Characteristic);
		StructureData.Insert("MeasurementUnit", 	TabularSectionRow.MeasurementUnit);
		StructureData.Insert("Price", 				TabularSectionRow.Price);
		
		StructureData = GetDataCharacteristicOnChange(StructureData);
			
		TabularSectionRow.Price = StructureData.Price;
		
		CalculateAmountInTabularSectionLine();
		RecalculateSubtotal();
		
	EndIf;	
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of the Count input field.
//
Procedure InventoryQuantityOnChange(Item)
	
	CalculateAmountInTabularSectionLine();
	RecalculateSubtotal();
	
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
	RecalculateSubtotal();
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of the Price input field.
//
Procedure InventoryPriceOnChange(Item)
	
	CalculateAmountInTabularSectionLine();
	RecalculateSubtotal();
	
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
// Procedure - handler of event OnChange of input field PlanningDate.
//
Procedure InventoryPlanningDateOnChange(Item)
	
	If ValueIsFilled(Object.PlanningPeriod)
		AND Items.Inventory.CurrentData.PlanningDate <> '00010101' Then
		
		AlignPlanningDateByPlanningPeriod(Items.Inventory.CurrentData.PlanningDate);	
		
	EndIf;	
		
EndProcedure

&AtClient
// Procedure - handler of event AfterDeleteRow of the table
Procedure InventoryAfterDeleteRow(Item)
	RecalculateSubtotal();
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
