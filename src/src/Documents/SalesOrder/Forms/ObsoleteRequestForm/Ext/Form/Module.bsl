
#Region Variables

&AtClient
Var WhenChangingStart;

&AtClient
Var WhenChangingFinish;

&AtClient
Var RowCopyWorks;

#EndRegion

#Region GeneralPurposeProceduresAndFunctions

&AtServer
// Procedure fills the VAT rate in the tabular section
// according to company's taxation system.
// 
Procedure FillVATRateByCompanyVATTaxation()
	
	Object.VATTaxation = DriveServer.CounterpartyVATTaxation(Object.Counterparty, DriveServer.VATTaxation(Object.Company, Object.Date));
	
	FillVATRateByVATTaxation();
	
EndProcedure

&AtServer
// Procedure fills the VAT rate in the tabular section according to the taxation system.
// 
Procedure FillVATRateByVATTaxation()
	
	If Object.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then
		
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
		
		For Each TabularSectionRow In Object.Works Do
			
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
		
		For Each TabularSectionRow In Object.Works Do
		
			TabularSectionRow.VATRate = DefaultVATRate;
			TabularSectionRow.VATAmount = 0;
			
			TabularSectionRow.Total = TabularSectionRow.Amount;
			
		EndDo;
		
	EndIf;
	
EndProcedure

// Function returns the label text "Prices and currency".
//
&AtClientAtServerNoContext
Function GenerateLabelPricesAndCurrency(LabelStructure)
	
	LabelText = "";
	
	// Currency.
	If LabelStructure.ForeignExchangeAccounting Then
		If ValueIsFilled(LabelStructure.DocumentCurrency) Then
			LabelText = "%Currency%";
			LabelText = StrReplace(LabelText, "%Currency%", TrimAll(String(LabelStructure.DocumentCurrency)));
		EndIf;
	EndIf;
	
	// Prices kind.
	If ValueIsFilled(LabelStructure.PriceKind) Then
		If IsBlankString(LabelText) Then
			LabelText = LabelText + "%PriceKind%";
		Else
			LabelText = LabelText + " • %PriceKind%";
		EndIf;
		LabelText = StrReplace(LabelText, "%PriceKind%", TrimAll(String(LabelStructure.PriceKind)));
	EndIf;
	
	// Margins discount kind.
	If ValueIsFilled(LabelStructure.DiscountKind) Then
		If IsBlankString(LabelText) Then
			LabelText = LabelText + "%DiscountMarkupKind%";
		Else
			LabelText = LabelText + " • %DiscountMarkupKind%";
		EndIf;
		LabelText = StrReplace(LabelText, "%DiscountMarkupKind%", TrimAll(String(LabelStructure.DiscountKind)));
	EndIf;
	
	// VAT taxation.
	If ValueIsFilled(LabelStructure.VATTaxation) Then
		If IsBlankString(LabelText) Then
			LabelText = LabelText + "%VATTaxation%";
		Else
			LabelText = LabelText + " • %VATTaxation%";
		EndIf;
		LabelText = StrReplace(LabelText, "%VATTaxation%", TrimAll(String(LabelStructure.VATTaxation)));
	EndIf;
	
	// Flag showing that amount includes VAT.
	If IsBlankString(LabelText) Then
		If LabelStructure.AmountIncludesVAT Then
			LabelText = NStr("en = 'Amount includes VAT'");
		Else
			LabelText = NStr("en = 'Amount does not include VAT'");
		EndIf;
	EndIf;
	
	Return LabelText;
	
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
Procedure CalculateAmountInTabularSectionLine(TabularSectionName = "Inventory", TabularSectionRow = Undefined)
	
	If TabularSectionRow = Undefined Then
		TabularSectionRow = Items[TabularSectionName].CurrentData;
	EndIf;
		
	// Amount.
	If TabularSectionName = "Works" Then
		TabularSectionRow.Amount = TabularSectionRow.Quantity * TabularSectionRow.Multiplicity * TabularSectionRow.Factor * TabularSectionRow.Price;
	Else
		TabularSectionRow.Amount = TabularSectionRow.Quantity * TabularSectionRow.Price;
	EndIf; 
		
	// Discounts.
	If TabularSectionRow.DiscountMarkupPercent = 100 Then
		TabularSectionRow.Amount = 0;
	ElsIf TabularSectionRow.DiscountMarkupPercent <> 0 AND TabularSectionRow.Quantity <> 0 Then
		TabularSectionRow.Amount = TabularSectionRow.Amount * (1 - TabularSectionRow.DiscountMarkupPercent / 100);
	EndIf;
	          	
	// VAT amount.
	CalculateVATSUM(TabularSectionRow);
	
	// Total.
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
EndProcedure

// Procedure recalculates amounts in the payment calendar.
//
&AtClient
Procedure RecalculatePaymentCalendar()
	
	For Each CurRow In Object.PaymentCalendar Do
		CurRow.PaymentAmount = Round((Object.Inventory.Total("Total") + Object.Works.Total("Total")) * CurRow.PaymentPercentage / 100, 2, 1);
		CurRow.PaymentVATAmount = Round((Object.Inventory.Total("VATAmount") + Object.Works.Total("VATAmount")) * CurRow.PaymentPercentage / 100, 2, 1);
	EndDo;
	
EndProcedure

// Procedure recalculates in the document tabular section after making
// changes in the "Prices and currency" form. The columns are
// recalculated as follows: price, discount, amount, VAT amount, total amount.
//
&AtClient
Procedure ProcessChangesOnButtonPricesAndCurrencies(Val SettlementsCurrencyBeforeChange, RecalculatePrices = False, WarningText = "")
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("DocumentCurrency", Object.DocumentCurrency);
	ParametersStructure.Insert("ExchangeRate", Object.ExchangeRate);
	ParametersStructure.Insert("Multiplicity", Object.Multiplicity);
	ParametersStructure.Insert("VATTaxation", Object.VATTaxation);
	ParametersStructure.Insert("AmountIncludesVAT", Object.AmountIncludesVAT);
	ParametersStructure.Insert("IncludeVATInPrice", Object.IncludeVATInPrice);
	ParametersStructure.Insert("Counterparty", Object.Counterparty);
	ParametersStructure.Insert("Contract", Object.Contract);
	ParametersStructure.Insert("Company",	ParentCompany); 
	ParametersStructure.Insert("DocumentDate", Object.Date);
	ParametersStructure.Insert("RefillPrices", False);
	ParametersStructure.Insert("RecalculatePrices", RecalculatePrices);
	ParametersStructure.Insert("WereMadeChanges", False);
	ParametersStructure.Insert("PriceKind", Object.PriceKind);
	ParametersStructure.Insert("DiscountKind", Object.DiscountMarkupKind);
	ParametersStructure.Insert("WarningText", WarningText);
	
	NotifyDescription = New NotifyDescription("OpenPricesAndCurrencyFormEnd", ThisObject, New Structure("SettlementsCurrencyBeforeChange", SettlementsCurrencyBeforeChange));
	OpenForm("CommonForm.PricesAndCurrency", ParametersStructure, ThisForm, , , , NotifyDescription, FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtClient
// Recalculate the price of the tabular section of the document after making changes in the "Prices and currency" form.
// 
Procedure RefillTabularSectionPricesByPriceKind() 
	
	DataStructure = New Structure;
	DocumentTabularSection = New Array;

	DataStructure.Insert("Date",				Object.Date);
	DataStructure.Insert("Company",			ParentCompany);
	DataStructure.Insert("PriceKind",				Object.PriceKind);
	DataStructure.Insert("DocumentCurrency",		Object.DocumentCurrency);
	DataStructure.Insert("AmountIncludesVAT",	Object.AmountIncludesVAT);
	
	DataStructure.Insert("DiscountMarkupKind", Object.DiscountMarkupKind);
	DataStructure.Insert("DiscountMarkupPercent", 0);
	
	If WorkKindInHeader Then
		
		For Each TSRow In Object.Works Do
			
			TSRow.Price = 0;
			
			If Not ValueIsFilled(TSRow.Products) Then
				Continue;	
			EndIf; 
			
			TabularSectionRow = New Structure();
			TabularSectionRow.Insert("WorkKind",			Object.WorkKind);
			TabularSectionRow.Insert("Products",		TSRow.Products);
			TabularSectionRow.Insert("Characteristic",		TSRow.Characteristic);
			TabularSectionRow.Insert("Price",				0);
			
			DocumentTabularSection.Add(TabularSectionRow);
			
		EndDo;
	
	Else
	
		For Each TSRow In Object.Works Do
			
			TSRow.Price = 0;
			
			If Not ValueIsFilled(TSRow.WorkKind) Then
				Continue;	
			EndIf; 
			
			TabularSectionRow = New Structure();
			TabularSectionRow.Insert("WorkKind",			TSRow.WorkKind);
			TabularSectionRow.Insert("Products",		TSRow.Products);
			TabularSectionRow.Insert("Characteristic",		TSRow.Characteristic);
			TabularSectionRow.Insert("Price",				0);
			
			DocumentTabularSection.Add(TabularSectionRow);
			
		EndDo;		
	
	EndIf;
		
	GetTabularSectionPricesByPriceKind(DataStructure, DocumentTabularSection);	
	
	For Each TSRow In DocumentTabularSection Do

		SearchStructure = New Structure;
		SearchStructure.Insert("Products", TSRow.Products);
		SearchStructure.Insert("Characteristic", TSRow.Characteristic);
		
		SearchResult = Object.Works.FindRows(SearchStructure);
		
		For Each ResultRow In SearchResult Do				
			ResultRow.Price = TSRow.Price;
			CalculateAmountInTabularSectionLine("Works", ResultRow);				
		EndDo;
		
	EndDo;		
	
	For Each TabularSectionRow In Object.Works Do
		TabularSectionRow.DiscountMarkupPercent = DataStructure.DiscountMarkupPercent;
		CalculateAmountInTabularSectionLine("Works", TabularSectionRow);
	EndDo;
	
EndProcedure

&AtServerNoContext
// Recalculate the price of the tabular section of the document after making changes in the "Prices and currency" form.
//
// Parameters:
//  AttributesStructure - Attribute structure, which necessary
//  when recalculation DocumentTabularSection - FormDataStructure, it
//                 contains the tabular document part.
//
Procedure GetTabularSectionPricesByPriceKind(DataStructure, DocumentTabularSection)
	
	// Discounts.
	If DataStructure.Property("DiscountMarkupKind") 
		AND ValueIsFilled(DataStructure.DiscountMarkupKind) Then
		
		DataStructure.DiscountMarkupPercent = DataStructure.DiscountMarkupKind.Percent;
		
	EndIf;	
	
	// 1. Generate document table.
	TempTablesManager = New TempTablesManager;
	
	ProductsTable = New ValueTable;
	
	Array = New Array;
	
	// Work kind.
	Array.Add(Type("CatalogRef.Products"));
	TypeDescription = New TypeDescription(Array, ,);
	Array.Clear();
	
	ProductsTable.Columns.Add("WorkKind", TypeDescription);
	
	// Products.
	Array.Add(Type("CatalogRef.Products"));
	TypeDescription = New TypeDescription(Array, ,);
	Array.Clear();
	
	ProductsTable.Columns.Add("Products", TypeDescription);
	
	// FixedValue.
	Array.Add(Type("Boolean"));
	TypeDescription = New TypeDescription(Array, ,);
	Array.Clear();
	
	ProductsTable.Columns.Add("FixedCost", TypeDescription);
	
	// Characteristic.
	Array.Add(Type("CatalogRef.ProductsCharacteristics"));
	TypeDescription = New TypeDescription(Array, ,);
	Array.Clear();
	
	ProductsTable.Columns.Add("Characteristic", TypeDescription);
	
	// VATRates.
	Array.Add(Type("CatalogRef.VATRates"));
	TypeDescription = New TypeDescription(Array, ,);
	Array.Clear();
	
	ProductsTable.Columns.Add("VATRate", TypeDescription);	
	
	For Each TSRow In DocumentTabularSection Do
		
		NewRow = ProductsTable.Add();
		NewRow.WorkKind	 	 = TSRow.WorkKind;
		NewRow.FixedCost	 = False;
		NewRow.Products	 = TSRow.Products;
		NewRow.Characteristic	 = TSRow.Characteristic;
		If TypeOf(TSRow) = Type("Structure")
		   AND TSRow.Property("VATRate") Then
			NewRow.VATRate		 = TSRow.VATRate;
		EndIf;
		
	EndDo;
	
	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	
	Query.Text =
	"SELECT
	|	ProductsTable.WorkKind,
	|	ProductsTable.FixedCost,
	|	ProductsTable.Products,
	|	ProductsTable.Characteristic,
	|	ProductsTable.VATRate
	|INTO TemporaryProductsTable
	|FROM
	|	&ProductsTable AS ProductsTable";
	
	Query.SetParameter("ProductsTable", ProductsTable);
	Query.Execute();
	
	// 2. We will fill prices.
	If DataStructure.PriceKind.CalculatesDynamically Then
		DynamicPriceKind = True;
		PriceKindParameter = DataStructure.PriceKind.PricesBaseKind;
		Markup = DataStructure.PriceKind.Percent;
		RoundingOrder = DataStructure.PriceKind.RoundingOrder;
		RoundUp = DataStructure.PriceKind.RoundUp;
	Else
		DynamicPriceKind = False;
		PriceKindParameter = DataStructure.PriceKind;	
	EndIf;	
	
	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	
	Query.Text = 
	"SELECT
	|	ProductsTable.Products AS Products,
	|	ProductsTable.Characteristic AS Characteristic,
	|	ProductsTable.VATRate AS VATRate,
	|	PricesSliceLast.PriceKind.PriceCurrency AS PricesCurrency,
	|	PricesSliceLast.PriceKind.PriceIncludesVAT AS PriceIncludesVAT,
	|	PricesSliceLast.PriceKind.RoundingOrder AS RoundingOrder,
	|	PricesSliceLast.PriceKind.RoundUp AS RoundUp,
	|	ISNULL(PricesSliceLast.Price * RateCurrencyTypePrices.ExchangeRate * DocumentCurrencyRate.Multiplicity / (DocumentCurrencyRate.ExchangeRate * RateCurrencyTypePrices.Multiplicity) / ISNULL(PricesSliceLast.MeasurementUnit.Factor, 1), 0) AS Price
	|FROM
	|	TemporaryProductsTable AS ProductsTable
	|		LEFT JOIN InformationRegister.Prices.SliceLast(&ProcessingDate, PriceKind = &PriceKind) AS PricesSliceLast
	|		ON (CASE
	|				WHEN ProductsTable.FixedCost
	|					THEN ProductsTable.Products = PricesSliceLast.Products
	|				ELSE ProductsTable.WorkKind = PricesSliceLast.Products
	|			END)
	|			AND (CASE
	|				WHEN ProductsTable.FixedCost
	|					THEN ProductsTable.Characteristic = PricesSliceLast.Characteristic
	|				ELSE TRUE
	|			END)
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&ProcessingDate, ) AS RateCurrencyTypePrices
	|		ON (PricesSliceLast.PriceKind.PriceCurrency = RateCurrencyTypePrices.Currency),
	|	InformationRegister.ExchangeRates.SliceLast(&ProcessingDate, Currency = &DocumentCurrency) AS DocumentCurrencyRate
	|WHERE
	|	PricesSliceLast.Actuality";
		
	Query.SetParameter("ProcessingDate",	 DataStructure.Date);
	Query.SetParameter("PriceKind",			 PriceKindParameter);
	Query.SetParameter("DocumentCurrency", DataStructure.DocumentCurrency);
	
	PricesTable = Query.Execute().Unload();
	For Each TabularSectionRow In DocumentTabularSection Do
		
		SearchStructure = New Structure;
		SearchStructure.Insert("Products",	 TabularSectionRow.Products);
		SearchStructure.Insert("Characteristic",	 TabularSectionRow.Characteristic);
		If TypeOf(TSRow) = Type("Structure")
		   AND TabularSectionRow.Property("VATRate") Then
			SearchStructure.Insert("VATRate", TabularSectionRow.VATRate);
		EndIf;
		
		SearchResult = PricesTable.FindRows(SearchStructure);
		If SearchResult.Count() > 0 Then
			
			Price = SearchResult[0].Price;
			If Price = 0 Then
				TabularSectionRow.Price = Price;
			Else
				
				// Dynamically calculate the price
				If DynamicPriceKind Then
					
					Price = Price * (1 + Markup / 100);
										
				Else	
					
					RoundingOrder = SearchResult[0].RoundingOrder;
					RoundUp = SearchResult[0].RoundUp;
	
				EndIf;
				
				If DataStructure.Property("AmountIncludesVAT") 
				   AND ((DataStructure.AmountIncludesVAT AND Not SearchResult[0].PriceIncludesVAT) 
				   OR (NOT DataStructure.AmountIncludesVAT AND SearchResult[0].PriceIncludesVAT)) Then
					Price = DriveServer.RecalculateAmountOnVATFlagsChange(Price, DataStructure.AmountIncludesVAT, TabularSectionRow.VATRate);
				EndIf;
										
				TabularSectionRow.Price = DriveClientServer.RoundPrice(Price, RoundingOrder, RoundUp);
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	TempTablesManager.Close()
	
EndProcedure

// Gets data set from server.
//
&AtServer
Function GetCompanyDataOnChange()
	
	StructureData = New Structure();
	StructureData.Insert("ParentCompany", DriveServer.GetCompany(Object.Company));
	StructureData.Insert("BankAccount", Object.Company.BankAccountByDefault);
	StructureData.Insert("BankAccountCashAssetsCurrency", Object.Company.BankAccountByDefault.CashCurrency);
	
	FillVATRateByCompanyVATTaxation();
	
	Return StructureData;
	
EndFunction

// Receives the set of data from the server for the ProductsOnChange procedure.
//
&AtServerNoContext
Function GetDataProductsOnChange(StructureData)
	
	StructureData.Insert("MeasurementUnit", StructureData.Products.MeasurementUnit);
	
	StructureData.Insert("IsService", StructureData.Products.ProductsType = Enums.ProductsTypes.Service);
	
	If StructureData.Property("TimeNorm") Then		
		StructureData.TimeNorm = DriveServer.GetWorkTimeRate(StructureData);		
	EndIf;	
	
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
	
	If StructureData.Property("Characteristic") Then
		StructureData.Insert("Specification", DriveServer.GetDefaultSpecification(StructureData.Products, StructureData.Characteristic));
	Else
		StructureData.Insert("Specification", DriveServer.GetDefaultSpecification(StructureData.Products));
	EndIf;
	
	If StructureData.Property("PriceKind") Then
		
		If Not StructureData.Property("Characteristic") Then	
			StructureData.Insert("Characteristic", Catalogs.ProductsCharacteristics.EmptyRef());	
		EndIf;
		
		If StructureData.Property("WorkKind") Then
		
			StructureData.Products = StructureData.WorkKind;
			Price = DriveServer.GetProductsPriceByPriceKind(StructureData);
			StructureData.Insert("Price", Price);
				
		Else
		
			Price = DriveServer.GetProductsPriceByPriceKind(StructureData);
			StructureData.Insert("Price", Price);	
		
		EndIf;				
		
	Else
		
		StructureData.Insert("Price", 0);
		
	EndIf;	
	
	If StructureData.Property("DiscountMarkupKind") 
		AND ValueIsFilled(StructureData.DiscountMarkupKind) Then
		StructureData.Insert("DiscountMarkupPercent", StructureData.DiscountMarkupKind.Percent);
	Else	
		StructureData.Insert("DiscountMarkupPercent", 0);
	EndIf;
		
	Return StructureData;
	
EndFunction

// It receives the data set from the server for the OrderStateOnChange procedure.
//
&AtServerNoContext
Function GetDataOrderStateOnChange(OrderState)
	
	If ValueIsFilled(OrderState) Then
		Return String(OrderState.OrderStatus);
	Else
		Return "";
	EndIf;
	
EndFunction

// It receives data set from the server for the CounterpartyOnChange procedure.
//
&AtServer
Function GetDataCounterpartyOnChange(Date, DocumentCurrency, Counterparty)
	
	FillVATRateByVATTaxation();
	
	StructureData = New Structure();
	
	StructureData.Insert(
		"Contract",
		Counterparty.ContractByDefault
	);
	
	StructureData.Insert(
		"SettlementsCurrency",
		Counterparty.ContractByDefault.SettlementsCurrency
	);
	
	StructureData.Insert(
		"SettlementsCurrencyRateRepetition",
		InformationRegisters.ExchangeRates.GetLast(Date, New Structure("Currency", Counterparty.ContractByDefault.SettlementsCurrency))
	);
	
	StructureData.Insert(
		"SettlementsInStandardUnits",
		Counterparty.ContractByDefault.SettlementsInStandardUnits
	);
	
	StructureData.Insert(
		"DiscountMarkupKind",
		Counterparty.ContractByDefault.DiscountMarkupKind
	);
	
	StructureData.Insert(
		"PriceKind",
		Counterparty.ContractByDefault.PriceKind
	);
	
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
		"DiscountMarkupKind",
		Contract.DiscountMarkupKind
	);
	
	StructureData.Insert(
		"SettlementsInStandardUnits",
		Contract.SettlementsInStandardUnits
	);
	
	Return StructureData;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// CALENDAR (RESOURCES UPLOAD)

/// The procedure generates the period of work schedule.
//
&AtClient
Procedure GenerateScheduledWorksPeriod()
	
	CalendarDateBegin = BegOfDay(CalendarDate);
	CalendarDateEnd = EndOfDay(CalendarDate);
	
	DayOfSchedule = Format(CalendarDateBegin, "DF=dd");
	MonthOfSchedule = Format(CalendarDateBegin, "DF=MMM");
	YearOfSchedule = Format(Year(CalendarDateBegin), "NG=0");
	WeekDayOfSchedule = DriveClient.GetPresentationOfWeekDay(CalendarDateBegin);
	
	PeriodPresentation = WeekDayOfSchedule + " " + DayOfSchedule + " " + MonthOfSchedule + " " + YearOfSchedule;
	
EndProcedure

// The function returns the list of resources by resource kind.
//
&AtServer
Function GetListOfResourcesByResourceKind()
	
	ListResourcesKinds = New ValueList;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	CompanyResourceTypes.CompanyResource AS CompanyResource
	|FROM
	|	InformationRegister.CompanyResourceTypes AS CompanyResourceTypes
	|WHERE
	|	CompanyResourceTypes.CompanyResourceType = &CompanyResourceType";
	
	Query.SetParameter("CompanyResourceType", FilterResourceKind);
	
	Result = Query.Execute();
	If Result.IsEmpty() Then
		Return ListResourcesKinds;
	EndIf;
	
	Selection = Result.Select();
	While Selection.Next() Do
		ListResourcesKinds.Add(Selection.CompanyResource);
	EndDo;
	
	Return ListResourcesKinds;
	
EndFunction

// The function returns the list of resources for fast selection.
//
&AtServer
Function GetListOfResourcesForFilter()
	
	If ValueIsFilled(FilterKeyResource) Then
		ListResourcesKinds = New ValueList;
		ListResourcesKinds.Add(FilterKeyResource);
	ElsIf ValueIsFilled(FilterResourceKind) Then
		ListResourcesKinds = GetListOfResourcesByResourceKind();
	Else
		ListResourcesKinds = Undefined;
	EndIf;
	
	Return ListResourcesKinds;
	
EndFunction

// Procedure fills the common calendar parameters.
//
&AtServer
Procedure FillCalendarParametersOnCreateAtServer()
	
	If ValueIsFilled(Parameters.Key) Then
		TimeLimitFrom = Parameters.TimeLimitFrom;
		TimeLimitTo = Parameters.TimeLimitTo;
		RepetitionFactorOFDay = Parameters.RepetitionFactorOFDay;
		If Parameters.Property("CalendarDate") Then
			CalendarDate = Parameters.CalendarDate;
		EndIf;
	ElsIf Parameters.Property("Details") Then
		TimeLimitFrom = Parameters.TimeLimitFrom;
		TimeLimitTo = Parameters.TimeLimitTo;
		RepetitionFactorOFDay = Parameters.RepetitionFactorOFDay;
		FilterKeyResource = Parameters.FilterKeyResource;
		FilterResourceKind = Parameters.FilterResourceKind;
		CalendarDetails = Parameters.Details;
		If CalendarDetails.Count() > 0 Then
			StructureInterval = CalendarDetails[0];
			If StructureInterval.Property("CompanyResource") Then
				CalendarDate = CurrentDate();
				FillTableOfResourcesInUseOnCreateAtServer(CalendarDetails);
			Else
				CalendarDate = StructureInterval.Interval;
			EndIf;
		Else
			CalendarDate = CurrentDate();
		EndIf;
	ElsIf Parameters.Property("DayOnly") Then
		TimeLimitFrom = Parameters.TimeLimitFrom;
		TimeLimitTo = Parameters.TimeLimitTo;
		RepetitionFactorOFDay = Parameters.RepetitionFactorOFDay;
		FilterKeyResource = Parameters.FilterKeyResource;
		FilterResourceKind = Parameters.FilterResourceKind;
		CalendarDate =  Parameters.DayOnly;
		Details = Undefined;
	Else
		TimeLimitFrom = '00010101090000';
		TimeLimitTo = '00010101210000';
		RepetitionFactorOFDay = 30;
		CalendarDate = CurrentDate();
		Details = Undefined;
	EndIf;
	
EndProcedure

// Procedure creates the resources table for request.
//
&AtServer
Procedure FillTableOfResourcesInUseOnCreateAtServer(CalendarDetails)
	
	ResourcesTable = New ValueTable;
	ResourcesTable.Columns.Add("CompanyResource");
	ResourcesTable.Columns.Add("CompanyResourceDescription");
	ResourcesTable.Columns.Add("Interval");
	For Each DetailsItm In CalendarDetails Do
		NewRow = ResourcesTable.Add();
		NewRow.CompanyResource = DetailsItm.CompanyResource;
		NewRow.CompanyResourceDescription = DetailsItm.CompanyResource.Description;
		NewRow.Interval = DetailsItm.Interval;
	EndDo;
	
	NewRow = Undefined;
	Resource = Undefined;
	IndexOf = 1;
	FirstStart = '00010101';
	LastFinish = '00010101';
	ResourcesTable.Sort("CompanyResourceDescription,Interval");
	For Each ResourcesRow In ResourcesTable Do
		If IndexOf = 1 Then
			CalendarDate = ResourcesRow.Interval;
		EndIf;
		If Resource = ResourcesRow.CompanyResource Then
			If NewRow <> Undefined Then
				PreviousFinish = NewRow.Finish;
				NextFinish = ResourcesRow.Interval + RepetitionFactorOFDay * 60;
				If BegOfDay(PreviousFinish) = BegOfDay(NextFinish) Then
					NewRow.Finish = ResourcesRow.Interval + RepetitionFactorOFDay * 60;
					If FirstStart > NewRow.Start OR FirstStart = '00010101' Then
						FirstStart = NewRow.Start;
					EndIf;
					If LastFinish < NewRow.Finish OR LastFinish = '00010101' Then
						LastFinish = NewRow.Finish;
					EndIf;
				Else
					NewRow.Finish = PreviousFinish;
					NewRow = Object.CompanyResources.Add();
					NewRow.CompanyResource = ResourcesRow.CompanyResource;
					NewRow.Capacity = 1;
					NewRow.Start = NextFinish - RepetitionFactorOFDay * 60;
					NewRow.Finish = NextFinish;
					If FirstStart > NewRow.Start OR FirstStart = '00010101' Then
						FirstStart = NewRow.Start;
					EndIf;
					If LastFinish < NewRow.Finish OR LastFinish = '00010101' Then
						LastFinish = NewRow.Finish;
					EndIf;
				EndIf;
				DurationInSeconds = NewRow.Finish - NewRow.Start;
				Hours = Int(DurationInSeconds / 3600);
				Minutes = (DurationInSeconds - Hours * 3600) / 60;
				NewRow.Duration = Date(0001, 01, 01, Hours, Minutes, 0);
			EndIf;
		Else
			NewRow = Object.CompanyResources.Add();
			NewRow.CompanyResource = ResourcesRow.CompanyResource;
			NewRow.Capacity = 1;
			NewRow.Start = ResourcesRow.Interval;
			NewRow.Finish = ResourcesRow.Interval + RepetitionFactorOFDay * 60;
			DurationInSeconds = NewRow.Finish - NewRow.Start;
			Hours = Int(DurationInSeconds / 3600);
			Minutes = (DurationInSeconds - Hours * 3600) / 60;
			NewRow.Duration = Date(0001, 01, 01, Hours, Minutes, 0);
			Resource = ResourcesRow.CompanyResource;
			If FirstStart > NewRow.Start OR FirstStart = '00010101' Then
				FirstStart = NewRow.Start;
			EndIf;
			If LastFinish < NewRow.Finish OR LastFinish = '00010101' Then
				LastFinish = NewRow.Finish;
			EndIf;
		EndIf;
		IndexOf = IndexOf + 1;
	EndDo;
	
	Object.Start = FirstStart;
	Object.Finish = LastFinish;
	
	WhenChangingStart = Object.Start;
	WhenChangingFinish = Object.Finish;
	
EndProcedure

// Function receives the involved resources table of current order.
//
&AtClient
Function GetTableOfResourcesInUse()
	
	StructureResourcesTS = New Structure;
	ArrayOfResourcesInUse = New Array;
	For Each TSRow In Object.CompanyResources Do
		StringStructure = New Structure;
		StringStructure.Insert("CompanyResource", TSRow.CompanyResource);
		StringStructure.Insert("Capacity", TSRow.Capacity);
		StringStructure.Insert("Duration", TSRow.Duration);
		StringStructure.Insert("Start", TSRow.Start);
		StringStructure.Insert("Finish", TSRow.Finish);
		ArrayOfResourcesInUse.Add(StringStructure);
	EndDo;
	StructureResourcesTS.Insert("Ref", Object.Ref);
	StructureResourcesTS.Insert("TabularSection", ArrayOfResourcesInUse);
	
	Return StructureResourcesTS;
	
EndFunction

// The procedure generates the schedule of resources import.
//
&AtServer
Procedure UpdateCalendar(StructureResourcesTS)
	
	Spreadsheet = ResourcesImport;
	Spreadsheet.Clear();
	
	ResourcesList = GetListOfResourcesForFilter();
	UpdateCalendarDayPeriod(Spreadsheet, StructureResourcesTS, ResourcesList);
	
	Spreadsheet.FixedTop = 4;
	Spreadsheet.FixedLeft = 5;
	
	Spreadsheet.ShowGrid = False;
	Spreadsheet.Protection = False;
	Spreadsheet.ReadOnly = True;
	
EndProcedure

// The procedure generates the schedule of resources import - period day.
//
&AtServer
Procedure UpdateCalendarDayPeriod(Spreadsheet, StructureResourcesTS, ResourcesList)
	
	ScaleTemplate = DataProcessors.Scheduler.GetTemplate("DayScale");
	
	// Displaying the scale.
	Indent = 1;
	ScaleStep = 3;
	ScaleBegin = 6;
	ShiftByScale = 1;
	ScaleSeparatorBottom = 3;
	ScaleSeparatorTop = 2;
	
	If ValueIsFilled(TimeLimitFrom) Then
		HourC = Hour(TimeLimitFrom);
		MinuteFrom = Minute(TimeLimitFrom);
	Else
		HourC = 0;
		MinuteFrom = 0;
	EndIf;
	If ValueIsFilled(TimeLimitTo) Then
		HourTo = Hour(TimeLimitTo);
		MinuteOn = Minute(TimeLimitTo);
	Else
		HourTo = 24;
		MinuteOn = 0;
	EndIf;
	
	ResourcesListArea = ScaleTemplate.Area("Scale60|ResourcesList");
	Spreadsheet.InsertArea(ResourcesListArea, Spreadsheet.Area(ResourcesListArea.Name));
	If RepetitionFactorOFDay = 60 Then
		If HourC = HourTo Then
			HourTo = HourC + ShiftByScale;
		ElsIf MinuteOn <> 0 Then
			HourTo = HourTo + ShiftByScale;
		EndIf;
		TotalMinutesFrom =  HourC * 60;
		TotalMinutesTo = HourTo * 60;
		ColumnNumberFrom = ScaleBegin + ?(HourC-Int(HourC/2)*2 = 1, (HourC - ShiftByScale), HourC) / 2 * ScaleStep;
		MultipleRestrictionFrom = Date('00010101') + (?(HourC-Int(HourC/2)*2 = 1, (HourC - ShiftByScale), HourC)) * 60 * 60;
		ColumnNumberTo = ScaleBegin + ?(HourTo-Int(HourTo/2)*2 = 1, (HourTo + ShiftByScale), HourTo) / 2 * ScaleStep - ShiftByScale;
		MultipleRestrictionTo = Date('00010101') + (?(HourTo-Int(HourTo/2)*2 = 1, (HourTo + ShiftByScale), HourTo)) * 60 * 60;
		ScaleArea = ScaleTemplate.Area("Scale60|Repetition60");
	ElsIf RepetitionFactorOFDay = 15 Then
		TotalMinutesFrom = HourC * 60 + MinuteFrom;
		TotalMinutesTo = HourTo * 60 + MinuteOn;
		If TotalMinutesFrom = TotalMinutesTo Then
			TotalMinutesTo = TotalMinutesFrom + 60;
		EndIf;
		ColumnNumberFrom = ScaleBegin + Int(TotalMinutesFrom / 30) * ScaleStep;
		MultipleRestrictionFrom = Date('00010101') + (?(Int(TotalMinutesFrom / 30) = (TotalMinutesFrom / 30), TotalMinutesFrom, Int(TotalMinutesFrom / 30) * 30)) * 60;
		ColumnNumberTo = ScaleBegin + ?(Int(TotalMinutesTo / 30) = (TotalMinutesTo / 30), (TotalMinutesTo / 30), Int(TotalMinutesTo / 30) + 1) * ScaleStep - ShiftByScale;
		MultipleRestrictionTo = Date('00010101') + (?(Int(TotalMinutesTo / 30) = (TotalMinutesTo / 30), TotalMinutesTo, Int(TotalMinutesTo / 30) * 30 + 30)) * 60;
		ScaleArea = ScaleTemplate.Area("Scale15|Repetition15");
	ElsIf RepetitionFactorOFDay = 10 Then
		TotalMinutesFrom = HourC * 60 + MinuteFrom;
		TotalMinutesTo = HourTo * 60 + MinuteOn;
		If TotalMinutesFrom = TotalMinutesTo Then
			TotalMinutesTo = TotalMinutesFrom + 60;
		EndIf;
		ColumnNumberFrom = ScaleBegin + Int(TotalMinutesFrom / 20) * ScaleStep;
		MultipleRestrictionFrom = Date('00010101') + (?(Int(TotalMinutesFrom / 20) = (TotalMinutesFrom / 20), TotalMinutesFrom, Int(TotalMinutesFrom / 20) * 20)) * 60;
		ColumnNumberTo = ScaleBegin + ?(Int(TotalMinutesTo / 20) = (TotalMinutesTo / 20), (TotalMinutesTo / 20), Int(TotalMinutesTo / 20) + 1) * ScaleStep - ShiftByScale;
		MultipleRestrictionTo = Date('00010101') + (?(Int(TotalMinutesTo / 20) = (TotalMinutesTo / 20), TotalMinutesTo, Int(TotalMinutesTo / 20) * 20 + 20)) * 60;
		ScaleArea = ScaleTemplate.Area("Scale10|Repetition10");
	ElsIf RepetitionFactorOFDay = 5 Then
		TotalMinutesFrom = HourC * 60 + MinuteFrom;
		TotalMinutesTo = HourTo * 60 + MinuteOn;
		If TotalMinutesFrom = TotalMinutesTo Then
			TotalMinutesTo = TotalMinutesFrom + 60;
		EndIf;
		ColumnNumberFrom = ScaleBegin + Int(TotalMinutesFrom / 10) * ScaleStep;
		MultipleRestrictionFrom = Date('00010101') + (?(Int(TotalMinutesFrom / 10) = (TotalMinutesFrom / 10), TotalMinutesFrom, Int(TotalMinutesFrom / 10) * 10)) * 60;
		ColumnNumberTo = ScaleBegin + ?(Int(TotalMinutesTo / 10) = (TotalMinutesTo / 10), (TotalMinutesTo / 10), Int(TotalMinutesTo / 10) + 1) * ScaleStep - ShiftByScale;
		MultipleRestrictionTo = Date('00010101') + (?(Int(TotalMinutesTo / 10) = (TotalMinutesTo / 10), TotalMinutesTo, Int(TotalMinutesTo / 10) * 10 + 10)) * 60;
		ScaleArea = ScaleTemplate.Area("Scale5|Repetition5");
	Else // 30 min
		If HourC = HourTo Then
			HourTo = HourC + ShiftByScale;
		ElsIf MinuteOn <> 0 Then
			HourTo = HourTo + ShiftByScale;
		EndIf;
		TotalMinutesFrom =  HourC * 60;
		TotalMinutesTo = HourTo * 60;
		ColumnNumberFrom = ScaleBegin + HourC * ScaleStep;
		MultipleRestrictionFrom = Date('00010101') + (?(Int(TotalMinutesFrom / 60) = (TotalMinutesFrom / 60), TotalMinutesFrom, TotalMinutesFrom - 30)) * 60;
		ColumnNumberTo = ScaleBegin + HourTo * ScaleStep - ShiftByScale;
		MultipleRestrictionTo = Date('00010101') + (?(Int(TotalMinutesTo / 60) = (TotalMinutesTo / 60), TotalMinutesTo, TotalMinutesTo + 30)) * 60;
		ScaleArea = ScaleTemplate.Area("Scale30|Repetition30");
	EndIf;
	TemplateArea = ScaleTemplate.Area("R" + ScaleArea.Top + "C"+ ColumnNumberFrom +":R"+ ScaleArea.Bottom +"C" + ColumnNumberTo);
	SpreadsheetArea = Spreadsheet.Area("R" + ShiftByScale + "C" + ScaleBegin + ":R"+ (ScaleStep + 1) +"C" + (ScaleBegin + ColumnNumberTo - ColumnNumberFrom));
	Spreadsheet.InsertArea(TemplateArea, SpreadsheetArea);
	
	// Initialization of days array.
	DaysArray = New Array;
	DaysArray.Add(CalendarDateBegin);
	
	// First column format.
	FirstColumnCoordinates = "R" + ShiftByScale + "C" + (ScaleBegin + ShiftByScale) + ":R" + ShiftByScale + "C" + (ScaleBegin + ShiftByScale);
	Spreadsheet.Area(FirstColumnCoordinates).Text = Format(CalendarDateBegin, "DF=""dd MMMM yyyy dddd""");
	Spreadsheet.Area("R" + ScaleSeparatorTop + "C" + (ScaleBegin + ShiftByScale) + ":R" + ScaleSeparatorBottom + "C" + (ScaleBegin + ShiftByScale)).LeftBorder = New Line(SpreadsheetDocumentCellLineType.None);
	
	// Last column format.
	LastColumnCoordinates = "R" + ShiftByScale + "C" + (ScaleBegin + ColumnNumberTo - ColumnNumberFrom) + ":R" + (ScaleStep + 1) + "C" + (ScaleBegin + ColumnNumberTo - ColumnNumberFrom);
	Spreadsheet.Area(LastColumnCoordinates).RightBorder = New Line(SpreadsheetDocumentCellLineType.Solid);
	Spreadsheet.Area(LastColumnCoordinates).BorderColor = StyleColors.BorderColor;
	
	CoordinatesForUnion = "R" + ShiftByScale + "C" + (ScaleBegin + ShiftByScale) + ":R" + ShiftByScale + "C" + (ScaleBegin + ColumnNumberTo - ColumnNumberFrom);
	UnionArea = Spreadsheet.Area(CoordinatesForUnion);
	UnionArea.Merge();
	
	// Coordinates of day end.
	EndOfDayCoordinates = LastColumnCoordinates;
	
	// Day-off format.
	If Weekday(CalendarDateBegin) = 6 
		OR Weekday(CalendarDateBegin) = 7 Then
		DayOffCoordinates = "R" + (ShiftByScale + 1) + "C" + ScaleBegin + ":R"+ (ScaleStep + 1) +"C" + (ScaleBegin + ColumnNumberTo - ColumnNumberFrom);
		Spreadsheet.Area(DayOffCoordinates).BackColor = StyleColors.NonWorkingTimeDayOff;
	EndIf;
	
	// Initialization of scale sizes.
	Spreadsheet.Area(1,,1,).RowHeight = 16;
	Spreadsheet.Area(2,,2,).RowHeight = 6;
	Spreadsheet.Area(3,,3,).RowHeight = 5;
	Spreadsheet.Area(4,,4,).RowHeight = 5;
	
	Spreadsheet.Area(,1,,1).ColumnWidth = 16;
	Spreadsheet.Area(,2,,2).ColumnWidth = 1;
	Spreadsheet.Area(,3,,3).ColumnWidth = 3;
	Spreadsheet.Area(,4,,4).ColumnWidth = 1;
	Spreadsheet.Area(,5,,5).ColumnWidth = 3;
	
	ColumnNumber = ScaleBegin;
	LastColumnNumber = Spreadsheet.TableWidth;
	While ColumnNumber <= LastColumnNumber Do
		
		Spreadsheet.Area(,ColumnNumber,,ColumnNumber).ColumnWidth = 0.8;
		Spreadsheet.Area(,ColumnNumber + 1,,ColumnNumber + 1).ColumnWidth = 6;
		Spreadsheet.Area(,ColumnNumber + 2,,ColumnNumber + 2).ColumnWidth = 6;
		ColumnNumber = ColumnNumber + 3;
		
	EndDo;
	
	// Displaying the schedule of resources import.
	BusyResourceCellColor = StyleColors.BusyResource;
	AvailableResourceCellColor =  StyleColors.WorktimeCompletelyBusy;
	ResourceIsNotEditableCellColor = StyleColors.WorktimeFreeAvailable;
	CellBorderColor = StyleColors.CellBorder;
	EditingCellColor = StyleColors.CurrentTimeInterval;
	
	ResourcesListBegin = ResourcesListArea.Bottom + Indent;
	FirstColumnNumber = Spreadsheet.Area(FirstColumnCoordinates).Left - 1;
	NumberOfLasfColumnOfDay = Spreadsheet.Area(EndOfDayCoordinates).Right;
	
	// Resourse import.
	IntervalsTable = New ValueTable();
	IntervalsTable.Columns.Add("Interval");
	IntervalsTable.Columns.Add("IntervalIsImported");
	IntervalsTable.Columns.Add("IntervalEdited");
	IntervalsTable.Columns.Add("Import");
	IntervalsTable.Indexes.Add("Interval");
	
	QueryResult = GetResourcesWorkImportSchedule(StructureResourcesTS, ResourcesList, DaysArray);
	
	// Resource import (on schedule, on deviations).
	SelectionResource = QueryResult[2].Select(QueryResultIteration.ByGroups, "CompanyResource");
	LineNumber = 1;
	While SelectionResource.Next() Do
		
		// List of resources.
		R = ResourcesListBegin + LineNumber;
		Spreadsheet.Area(R, 1).Text = SelectionResource.CompanyResource;
		Spreadsheet.Area(R, 1).VerticalAlign = VerticalAlign.Center;
		Spreadsheet.Area(R, 1).Details = SelectionResource.CompanyResource;
		
		UnionArea = Spreadsheet.Area(R,1,R,ScaleBegin-1);
		UnionArea.Merge();
		
		ResourceCapacity = ?(SelectionResource.Capacity = 1, 0, SelectionResource.Capacity);
		
		// Resourse import.
		IntervalsTable.Clear();
		
		WorkBySchedule = False;
		Selection = SelectionResource.Select();
		While Selection.Next() Do
			
			// There is a deviation for the current day.
			If Selection.RejectionsNotABusinessDay
				AND ValueIsFilled(Selection.RejectionsBeginTime) AND ValueIsFilled(Selection.RejectionsEndTime) Then
				
				CalculateIntervals(IntervalsTable, MultipleRestrictionFrom, MultipleRestrictionTo, Selection.RejectionsBeginTime, Selection.RejectionsEndTime);
				
			EndIf;
			
			// There is a shedule for the current day.
			If Not Selection.RejectionsNotABusinessDay
				AND ValueIsFilled(Selection.BeginTime) AND ValueIsFilled(Selection.EndTime) Then
				
				CalculateIntervals(IntervalsTable, MultipleRestrictionFrom, MultipleRestrictionTo, Selection.BeginTime, Selection.EndTime);
				
			EndIf;
			
			// Work on schedule.
			If ValueIsFilled(Selection.WorkSchedule) Then
				WorkBySchedule = True;
			EndIf;
			
		EndDo;
		
		// Output of calendar import.
		Interval = 0;
		MultipleTimeFrom = MultipleRestrictionFrom;
		NextFirstColumn = FirstColumnNumber;
		NextLastColumn = NumberOfLasfColumnOfDay;
		While NextFirstColumn <= NextLastColumn Do
			
			// Cell 1.
			Spreadsheet.Area(R, NextFirstColumn + Indent).TextPlacement = SpreadsheetDocumentTextPlacementType.Cut;
			Spreadsheet.Area(R, NextFirstColumn + Indent).VerticalAlign = VerticalAlign.Center;
			Spreadsheet.Area(R, NextFirstColumn + Indent).HorizontalAlign = HorizontalAlign.Center;
			Spreadsheet.Area(R, NextFirstColumn + Indent).Font = New Font(, 8, True, , , );
			Spreadsheet.Area(R, NextFirstColumn + Indent).RightBorder = New Line(SpreadsheetDocumentCellLineType.Solid, 2);
			Spreadsheet.Area(R, NextFirstColumn + Indent).BorderColor = CellBorderColor;
			
			SearchInterval = CalendarDateBegin + Hour(MultipleTimeFrom) * 60 * 60 + Minute(MultipleTimeFrom) * 60;
			SearchStructure = New Structure("Interval", SearchInterval);
			SearchResult = IntervalsTable.FindRows(SearchStructure);
			If SearchResult.Count() = 0 AND Not WorkBySchedule Then
				
				Spreadsheet.Area(R, NextFirstColumn + Indent).BackColor = AvailableResourceCellColor;
				Spreadsheet.Area(R, NextFirstColumn + Indent).Text = ResourceCapacity;
				Spreadsheet.Area(R, NextFirstColumn + Indent).TextColor = CellBorderColor;
				Spreadsheet.Area(R, NextFirstColumn + Indent).Details = GetCellDetails(SelectionResource.CompanyResource, SearchInterval, ResourceCapacity);
				
			ElsIf SearchResult.Count() = 0 AND WorkBySchedule Then
				
				Spreadsheet.Area(R, NextFirstColumn + Indent).BackColor = ResourceIsNotEditableCellColor;
				Spreadsheet.Area(R, NextFirstColumn + Indent).Text = ResourceCapacity;
				Spreadsheet.Area(R, NextFirstColumn + Indent).TextColor = CellBorderColor;
				Spreadsheet.Area(R, NextFirstColumn + Indent).Details = GetCellDetails(SelectionResource.CompanyResource, SearchInterval, ResourceCapacity);
				
			Else
				
				Spreadsheet.Area(R, NextFirstColumn + Indent).BackColor = AvailableResourceCellColor;
				Spreadsheet.Area(R, NextFirstColumn + Indent).Text = ResourceCapacity;
				Spreadsheet.Area(R, NextFirstColumn + Indent).TextColor = CellBorderColor;
				Spreadsheet.Area(R, NextFirstColumn + Indent).Details = GetCellDetails(SelectionResource.CompanyResource, SearchInterval, ResourceCapacity);
				
			EndIf;
			
			// Cell 2.
			Spreadsheet.Area(R, NextFirstColumn + ShiftByScale + Indent).TextPlacement = SpreadsheetDocumentTextPlacementType.Cut;
			Spreadsheet.Area(R, NextFirstColumn + ShiftByScale + Indent).VerticalAlign = VerticalAlign.Center;
			Spreadsheet.Area(R, NextFirstColumn + ShiftByScale + Indent).HorizontalAlign = HorizontalAlign.Center;
			Spreadsheet.Area(R, NextFirstColumn + ShiftByScale + Indent).Font = New Font(, 8, True, , , );
			
			MultipleTimeFrom = MultipleTimeFrom + RepetitionFactorOFDay * 60;
			SearchInterval = CalendarDateBegin + Hour(MultipleTimeFrom) * 60 * 60 + Minute(MultipleTimeFrom) * 60;
			SearchStructure = New Structure("Interval", SearchInterval);
			SearchResult = IntervalsTable.FindRows(SearchStructure);
			If SearchResult.Count() = 0 AND Not WorkBySchedule Then
				
				Spreadsheet.Area(R, NextFirstColumn + ShiftByScale + Indent).BackColor = AvailableResourceCellColor;
				Spreadsheet.Area(R, NextFirstColumn + ShiftByScale + Indent).Text = ResourceCapacity;
				Spreadsheet.Area(R, NextFirstColumn + ShiftByScale + Indent).TextColor = CellBorderColor;
				Spreadsheet.Area(R, NextFirstColumn + ShiftByScale + Indent).Details = GetCellDetails(SelectionResource.CompanyResource, SearchInterval, ResourceCapacity);
				
			ElsIf SearchResult.Count() = 0 AND WorkBySchedule Then
				
				Spreadsheet.Area(R, NextFirstColumn + ShiftByScale + Indent).BackColor = ResourceIsNotEditableCellColor;
				Spreadsheet.Area(R, NextFirstColumn + ShiftByScale + Indent).Text = ResourceCapacity;
				Spreadsheet.Area(R, NextFirstColumn + ShiftByScale + Indent).TextColor = CellBorderColor;
				Spreadsheet.Area(R, NextFirstColumn + ShiftByScale + Indent).Details = GetCellDetails(SelectionResource.CompanyResource, SearchInterval, ResourceCapacity);
				
			Else
				
				Spreadsheet.Area(R, NextFirstColumn + ShiftByScale + Indent).BackColor = AvailableResourceCellColor;
				Spreadsheet.Area(R, NextFirstColumn + ShiftByScale + Indent).Text = ResourceCapacity;
				Spreadsheet.Area(R, NextFirstColumn + ShiftByScale + Indent).TextColor = CellBorderColor;
				Spreadsheet.Area(R, NextFirstColumn + ShiftByScale + Indent).Details = GetCellDetails(SelectionResource.CompanyResource, SearchInterval, ResourceCapacity);
				
			EndIf;
			
			MultipleTimeFrom = MultipleTimeFrom + RepetitionFactorOFDay * 60;
			NextFirstColumn = NextFirstColumn + 3;
			Interval = Interval + 3;
			
		EndDo;
		
		// Initialization of line sizes.
		R = ScaleStep + LineNumber + ShiftByScale;
		Spreadsheet.Area(R, 1).RowHeight = 5;
		Spreadsheet.Area(R + Indent, 1).RowHeight = 18;
		
		LineNumber = LineNumber + 2;
		
	EndDo;
	
	// Resourse import (on orders).
	SelectionResource = QueryResult[3].Select(QueryResultIteration.ByGroups, "CompanyResource");
	LineNumber = 1;
	While SelectionResource.Next() Do
		
		// List of resources.
		R = ResourcesListBegin + LineNumber;
		ResourceCapacity = ?(SelectionResource.Capacity = 1, 0, SelectionResource.Capacity);
		
		// Resourse import.
		IntervalsTable.Clear();
		
		Selection = SelectionResource.Select();
		While Selection.Next() Do
			
			// There is an order for the current day.
			If ValueIsFilled(Selection.BeginTime) AND ValueIsFilled(Selection.EndTime) Then
				
				CalculateIntervals(IntervalsTable, MultipleRestrictionFrom, MultipleRestrictionTo, Selection.BeginTime, Selection.EndTime, Selection.Import, Selection.Edit);
				
			EndIf;
			
		EndDo;
		
		// Output of calendar import.
		Interval = 0;
		MultipleTimeFrom = MultipleRestrictionFrom;
		NextFirstColumn = FirstColumnNumber;
		NextLastColumn = NumberOfLasfColumnOfDay;
		While NextFirstColumn <= NextLastColumn Do
			
			// Cell 1.
			SearchInterval = CalendarDateBegin + Hour(MultipleTimeFrom) * 60 * 60 + Minute(MultipleTimeFrom) * 60;
			SearchStructure = New Structure("Interval", SearchInterval);
			SearchResult = IntervalsTable.FindRows(SearchStructure);
			Import = 0;
			IntervalEdited = False;
			For Each SearchString In SearchResult Do
				
				If SearchString.IntervalIsImported Then
					
					If SearchString.IntervalEdited Then
						IntervalEdited = True;
					EndIf;
					Import = Import + SearchString.Import;
					
				EndIf;
					
			EndDo;
				
			If Import <> 0 Then
				
				TotalImport = Import;
				If ResourceCapacity = 0 Then
					Import = 0;
				Else
					Import = ResourceCapacity - Import;
				EndIf;
					
				If Import = 0 Then
					Spreadsheet.Area(R, NextFirstColumn + Indent).BackColor = BusyResourceCellColor;
					Spreadsheet.Area(R, NextFirstColumn + Indent).Text = Import;
					Spreadsheet.Area(R, NextFirstColumn + Indent).TextColor = CellBorderColor;
				ElsIf Import < 0 Then
					Spreadsheet.Area(R, NextFirstColumn + Indent).BackColor = BusyResourceCellColor;
					Spreadsheet.Area(R, NextFirstColumn + Indent).Text = Import * (-1);
					Spreadsheet.Area(R, NextFirstColumn + Indent).TextColor = CellBorderColor;
				Else
					Spreadsheet.Area(R, NextFirstColumn + Indent).BackColor = AvailableResourceCellColor;
					Spreadsheet.Area(R, NextFirstColumn + Indent).Text = Import;
					Spreadsheet.Area(R, NextFirstColumn + Indent).TextColor = CellBorderColor;
				EndIf;
					
				If IntervalEdited Then
					Spreadsheet.Area(R, NextFirstColumn + Indent).BackColor = EditingCellColor;
					If Import < 0 Then
						Spreadsheet.Area(R, NextFirstColumn + Indent).TextColor = BusyResourceCellColor;
					EndIf;
				EndIf;
				
				Spreadsheet.Area(R, NextFirstColumn + Indent).Details = GetCellDetails(SelectionResource.CompanyResource, SearchInterval, ResourceCapacity, TotalImport);
				
			EndIf;
			
			// Cell 2.
			MultipleTimeFrom = MultipleTimeFrom + RepetitionFactorOFDay * 60;
			SearchInterval = CalendarDateBegin + Hour(MultipleTimeFrom) * 60 * 60 + Minute(MultipleTimeFrom) * 60;
			SearchStructure = New Structure("Interval", SearchInterval);
			SearchResult = IntervalsTable.FindRows(SearchStructure);
			Import = 0;
			IntervalEdited = False;
			For Each SearchString In SearchResult Do
				
				If SearchString.IntervalIsImported Then
					
					If SearchString.IntervalEdited Then
						IntervalEdited = True;
					EndIf;
					Import = Import + SearchString.Import;
					
				EndIf;
				
			EndDo;
				
			If Import <> 0 Then
				
				TotalImport = Import;
				If ResourceCapacity = 0 Then
					Import = 0;
				Else
					Import = ResourceCapacity - Import;
				EndIf;
				
				If Import = 0 Then
					Spreadsheet.Area(R, NextFirstColumn + ShiftByScale + Indent).BackColor = BusyResourceCellColor;
					Spreadsheet.Area(R, NextFirstColumn + ShiftByScale + Indent).Text = Import;
					Spreadsheet.Area(R, NextFirstColumn + ShiftByScale + Indent).TextColor = CellBorderColor;
				ElsIf Import < 0 Then
					Spreadsheet.Area(R, NextFirstColumn + ShiftByScale + Indent).BackColor = BusyResourceCellColor;
					Spreadsheet.Area(R, NextFirstColumn + ShiftByScale + Indent).Text = Import * (-1);
					Spreadsheet.Area(R, NextFirstColumn + ShiftByScale + Indent).TextColor = CellBorderColor;
				Else
					Spreadsheet.Area(R, NextFirstColumn + ShiftByScale + Indent).BackColor = AvailableResourceCellColor;
					Spreadsheet.Area(R, NextFirstColumn + ShiftByScale + Indent).Text = Import;
					Spreadsheet.Area(R, NextFirstColumn + ShiftByScale + Indent).TextColor = CellBorderColor;
				EndIf;
				
				If IntervalEdited Then
					Spreadsheet.Area(R, NextFirstColumn + ShiftByScale + Indent).BackColor = EditingCellColor;
					If Import < 0 Then
						Spreadsheet.Area(R, NextFirstColumn + ShiftByScale + Indent).TextColor = BusyResourceCellColor;
					EndIf;
				EndIf;
				
				Spreadsheet.Area(R, NextFirstColumn + ShiftByScale + Indent).Details = GetCellDetails(SelectionResource.CompanyResource, SearchInterval, ResourceCapacity, TotalImport);
				
			EndIf;
			
			MultipleTimeFrom = MultipleTimeFrom + RepetitionFactorOFDay * 60;
			NextFirstColumn = NextFirstColumn + 3;
			Interval = Interval + 3;
			
		EndDo;
		
		LineNumber = LineNumber + 2;
		
	EndDo;
	
EndProcedure

// Procedure updates the calendar cell according to the details parameters.
//
&AtClient
Procedure UpdateCalendarCell(CellCoordinates, Details)
	
	TotalImport = Details.Import + 1;
	If Details.Capacity = 0 Then
		Import = 0;
	Else
		Import = Details.Capacity - Details.Import - 1;
	EndIf;
	
	ResourcesImport.Area(CellCoordinates).BackColor = ColorEditing;
	If Import < 0 Then
		ResourcesImport.Area(CellCoordinates).Text = Import *(-1);
		ResourcesImport.Area(CellCoordinates).TextColor = ColorBusyResource;
	Else
		ResourcesImport.Area(CellCoordinates).Text = Import;
	EndIf;
	
	Details.Import = TotalImport;
	
EndProcedure

// The procedure calculates the planning intervals for calendar scale.
//
&AtServer
Procedure CalculateIntervals(IntervalsTable, TimeFrom, TimeTo, BeginTime, EndTime, Import = 0, Edit = Undefined)
	
	MultipleTimeRestrictionFrom = BegOfDay(BeginTime) + Hour(TimeFrom) * 60 * 60 + Minute(TimeFrom) * 60;
	MultipleTimeRestrictionTo = BegOfDay(BeginTime) + Hour(TimeTo) * 60 * 60 + Minute(TimeTo) * 60;
	
	// If 24 hours.
	If MultipleTimeRestrictionFrom >= MultipleTimeRestrictionTo Then
		MultipleTimeRestrictionTo = MultipleTimeRestrictionTo + 24 * 60 * 60;
	EndIf;
	
	If RepetitionFactorOFDay = 60 Then
		
		HourBeginTime = Hour(BeginTime);
		MultipleStartTime = BegOfDay(BeginTime) + HourBeginTime * 60 * 60;
		EndTimeHour = ?(Minute(EndTime) <> 0, Hour(EndTime) + 1, Hour(EndTime));
		MultipleEndTime = BegOfDay(EndTime) + EndTimeHour * 60 * 60;
		
		While MultipleStartTime < MultipleEndTime Do
			If Hour(MultipleStartTime) >= Hour(MultipleTimeRestrictionFrom) AND Hour(MultipleStartTime) <= Hour(MultipleTimeRestrictionTo) Then
				NewRow = IntervalsTable.Add();
				NewRow.Interval = MultipleStartTime;
				NewRow.Import = Import;
				If Edit = Undefined Then
					NewRow.IntervalIsImported = False;
					NewRow.IntervalEdited = False;
				Else
					NewRow.IntervalIsImported = True;
					NewRow.IntervalEdited = Edit;
					NewRow.Import = Import;
				EndIf;
			EndIf;
			MultipleStartTime = MultipleStartTime + RepetitionFactorOFDay * 60;
		EndDo;
		
	ElsIf RepetitionFactorOFDay = 15 Then
		
		MinutesBeginTime = Int(Minute(BeginTime) / 15) * 15;
		MultipleStartTime = BegOfDay(BeginTime) + Hour(BeginTime) * 60 * 60 + MinutesBeginTime * 60;
		
		MinutesEndTime = ?(Int(Minute(EndTime) / 15) = Minute(EndTime) / 15, Minute(EndTime), Int(Minute(EndTime) / 15) * 15 + 15);
		MultipleEndTime = BegOfDay(EndTime) + Hour(EndTime) * 60 * 60 + MinutesEndTime * 60;
		
		While MultipleStartTime < MultipleEndTime Do
			If MultipleStartTime >= MultipleTimeRestrictionFrom AND MultipleStartTime <= MultipleTimeRestrictionTo Then
				NewRow = IntervalsTable.Add();
				NewRow.Interval = MultipleStartTime;
				NewRow.Import = Import;
				If Edit = Undefined Then
					NewRow.IntervalIsImported = False;
					NewRow.IntervalEdited = False;
				Else
					NewRow.IntervalIsImported = True;
					NewRow.IntervalEdited = Edit;
					NewRow.Import = Import;
				EndIf;
			EndIf;
			MultipleStartTime = MultipleStartTime + RepetitionFactorOFDay * 60;
		EndDo;
		
	ElsIf RepetitionFactorOFDay = 10 Then
		
		MinutesBeginTime = Int(Minute(BeginTime) / 10) * 10;
		MultipleStartTime = BegOfDay(BeginTime) + Hour(BeginTime) * 60 * 60 + MinutesBeginTime * 60;
		
		MinutesEndTime = ?(Int(Minute(EndTime) / 10) = Minute(EndTime) / 10, Minute(EndTime), Int(Minute(EndTime) / 10) * 10 + 10);
		MultipleEndTime = BegOfDay(EndTime) + Hour(EndTime) * 60 * 60 + MinutesEndTime * 60;
		
		While MultipleStartTime < MultipleEndTime Do
			If MultipleStartTime >= MultipleTimeRestrictionFrom AND MultipleStartTime <= MultipleTimeRestrictionTo Then
				NewRow = IntervalsTable.Add();
				NewRow.Interval = MultipleStartTime;
				NewRow.Import = Import;
				If Edit = Undefined Then
					NewRow.IntervalIsImported = False;
					NewRow.IntervalEdited = False;
				Else
					NewRow.IntervalIsImported = True;
					NewRow.IntervalEdited = Edit;
					NewRow.Import = Import;
				EndIf;
			EndIf;
			MultipleStartTime = MultipleStartTime + RepetitionFactorOFDay * 60;
		EndDo;
		
	ElsIf RepetitionFactorOFDay = 5 Then
		
		MinutesBeginTime = Int(Minute(BeginTime) / 5) * 5;
		MultipleStartTime = BegOfDay(BeginTime) + Hour(BeginTime) * 60 * 60 + MinutesBeginTime * 60;
		
		MinutesEndTime = ?(Int(Minute(EndTime) / 5) = Minute(EndTime) / 5, Minute(EndTime), Int(Minute(EndTime) / 5) * 5 + 5);
		MultipleEndTime = BegOfDay(EndTime) + Hour(EndTime) * 60 * 60 + MinutesEndTime * 60;
		
		While MultipleStartTime < MultipleEndTime Do
			If MultipleStartTime >= MultipleTimeRestrictionFrom AND MultipleStartTime <= MultipleTimeRestrictionTo Then
				NewRow = IntervalsTable.Add();
				NewRow.Interval = MultipleStartTime;
				NewRow.Import = Import;
				If Edit = Undefined Then
					NewRow.IntervalIsImported = False;
					NewRow.IntervalEdited = False;
				Else
					NewRow.IntervalIsImported = True;
					NewRow.IntervalEdited = Edit;
					NewRow.Import = Import;
				EndIf;
			EndIf;
			MultipleStartTime = MultipleStartTime + RepetitionFactorOFDay * 60;
		EndDo;
		
		TimeFrom = MultipleTimeRestrictionFrom;
		
	Else // Multiplicity = 30
		
		MinutesBeginTime = ?(Minute(BeginTime) < 30, Hour(BeginTime) * 60, Hour(BeginTime) * 60 + 30);
		MultipleStartTime = BegOfDay(BeginTime) + MinutesBeginTime * 60;
		If Minute(EndTime) <= 30 Then
			MinutesEndTime = ?(Minute(EndTime) = 0, Hour(EndTime) * 60, Hour(EndTime) * 60 + 30);
		Else
			MinutesEndTime = (Hour(EndTime) + 1) * 60;
		EndIf;
		MultipleEndTime = BegOfDay(EndTime) + MinutesEndTime * 60;
		
		While MultipleStartTime < MultipleEndTime Do
			If MultipleStartTime >= MultipleTimeRestrictionFrom AND MultipleStartTime <= MultipleTimeRestrictionTo Then
				NewRow = IntervalsTable.Add();
				NewRow.Interval = MultipleStartTime;
				NewRow.Import = Import;
				If Edit = Undefined Then
					NewRow.IntervalIsImported = False;
					NewRow.IntervalEdited = False;
				Else
					NewRow.IntervalIsImported = True;
					NewRow.IntervalEdited = Edit;
					NewRow.Import = Import;
				EndIf;
			EndIf;
			MultipleStartTime = MultipleStartTime + RepetitionFactorOFDay * 60;
		EndDo;
		
	EndIf;
	
EndProcedure

// The function returns the schedule of resources import.
//
&AtServer
Function GetResourcesWorkImportSchedule(StructureResourcesTS, ResourcesList, DaysArray)
	
	ResourcesTable = New ValueTable;
	
	Array = New Array;
	Array.Add(Type("CatalogRef.CompanyResources"));
	TypeDescription = New TypeDescription(Array, ,);
	Array.Clear();
	
	ResourcesTable.Columns.Add("CompanyResource", TypeDescription);
	
	Array = New Array;
	Array.Add(Type("Date"));
	TypeDescription = New TypeDescription(Array, ,);
	Array.Clear();
	
	ResourcesTable.Columns.Add("Start", TypeDescription);
	ResourcesTable.Columns.Add("Finish", TypeDescription);
	
	Array = New Array;
	Array.Add(Type("Number"));
	TypeDescription = New TypeDescription(Array, ,);
	Array.Clear();
	
	ResourcesTable.Columns.Add("Capacity", TypeDescription);
	
	For Each ResourceRow In StructureResourcesTS.TabularSection Do
		NewRow = ResourcesTable.Add();
		FillPropertyValues(NewRow, ResourceRow);
	EndDo;
	CurrentDocument = StructureResourcesTS.Ref;
	
	TempTablesManager = New TempTablesManager;
	
	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	Query.Text =
	"SELECT
	|	CompanyResources.Ref AS CompanyResource,
	|	CompanyResources.Capacity AS Capacity,
	|	CompanyResources.Description AS ResourceDescription
	|INTO CompanyResourceTempTable
	|FROM
	|	Catalog.CompanyResources AS CompanyResources
	|WHERE
	|	(&FilterByKeyResource
	|			OR CompanyResources.Ref IN (&FilterCompanyResourcesList))
	|	AND (NOT CompanyResources.DeletionMark)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ResourcesTable.CompanyResource AS CompanyResource,
	|	ResourcesTable.Start AS Start,
	|	ResourcesTable.Finish AS Finish,
	|	ResourcesTable.Capacity AS Capacity
	|INTO TemporaryTableRequest
	|FROM
	|	&ResourcesTable AS ResourcesTable
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CompanyResourceTempTable.CompanyResource AS CompanyResource,
	|	CompanyResourceTempTable.Capacity AS Capacity,
	|	TableOfSchedules.WorkSchedule AS WorkSchedule,
	|	WorkSchedules.BeginTime AS BeginTime,
	|	WorkSchedules.EndTime AS EndTime,
	|	ResourceWorkScheduleAdjustment.BeginTime AS RejectionsBeginTime,
	|	ResourceWorkScheduleAdjustment.EndTime AS RejectionsEndTime,
	|	ISNULL(ResourceWorkScheduleAdjustment.NotABusinessDay, FALSE) AS RejectionsNotABusinessDay
	|FROM
	|	CompanyResourceTempTable AS CompanyResourceTempTable
	|		LEFT JOIN InformationRegister.WorkSchedulesOfResources.SliceLast(&StartDate, ) AS TableOfSchedules
	|		ON CompanyResourceTempTable.CompanyResource = TableOfSchedules.CompanyResource
	|		LEFT JOIN InformationRegister.WorkSchedules AS WorkSchedules
	|		ON (TableOfSchedules.WorkSchedule = WorkSchedules.WorkSchedule)
	|			AND (WorkSchedules.BeginTime between &StartDate AND &EndDate)
	|			AND (WorkSchedules.EndTime between &StartDate AND &EndDate)
	|		LEFT JOIN InformationRegister.ResourceWorkScheduleAdjustment AS ResourceWorkScheduleAdjustment
	|		ON CompanyResourceTempTable.CompanyResource = ResourceWorkScheduleAdjustment.CompanyResource
	|			AND (ResourceWorkScheduleAdjustment.BeginTime between &StartDate AND &EndDate)
	|			AND (ResourceWorkScheduleAdjustment.EndTime between &StartDate AND &EndDate)
	|
	|ORDER BY
	|	CompanyResourceTempTable.ResourceDescription,
	|	BeginTime,
	|	EndTime
	|TOTALS
	|	MIN(Capacity)
	|BY
	|	CompanyResource
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CompanyResourceTempTable.CompanyResource AS CompanyResource,
	|	CompanyResourceTempTable.Capacity AS Capacity,
	|	NestedSelect.Edit AS Edit,
	|	NestedSelect.Start AS BeginTime,
	|	NestedSelect.Finish AS EndTime,
	|	NestedSelect.Capacity AS Import
	|FROM
	|	CompanyResourceTempTable AS CompanyResourceTempTable
	|		LEFT JOIN (SELECT
	|			FALSE AS Edit,
	|			ProductionOrderCompanyResources.CompanyResource AS CompanyResource,
	|			ProductionOrderCompanyResources.Capacity AS Capacity,
	|			ProductionOrderCompanyResources.Start AS Start,
	|			ProductionOrderCompanyResources.Finish AS Finish
	|		FROM
	|			Document.ProductionOrder.CompanyResources AS ProductionOrderCompanyResources
	|		WHERE
	|			(NOT ProductionOrderCompanyResources.CompanyResource.DeletionMark)
	|			AND ProductionOrderCompanyResources.Ref.Posted
	|			AND ((NOT ProductionOrderCompanyResources.Ref.Closed)
	|					OR ProductionOrderCompanyResources.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.Completed))
	|			AND ProductionOrderCompanyResources.Start between &StartDate AND &EndDate
	|			AND ProductionOrderCompanyResources.Finish between &StartDate AND &EndDate
	|			AND (&FilterByKeyResource
	|					OR ProductionOrderCompanyResources.CompanyResource IN (&FilterCompanyResourcesList))
	|		
	|		UNION ALL
	|		
	|		SELECT
	|			TRUE,
	|			ResourcesTable.CompanyResource,
	|			ResourcesTable.Capacity,
	|			ResourcesTable.Start,
	|			ResourcesTable.Finish
	|		FROM
	|			TemporaryTableRequest AS ResourcesTable
	|		WHERE
	|			ResourcesTable.Start between &StartDate AND &EndDate
	|			AND ResourcesTable.Finish between &StartDate AND &EndDate
	|			AND (&FilterByKeyResource
	|					OR ResourcesTable.CompanyResource IN (&FilterCompanyResourcesList))) AS NestedSelect
	|		ON CompanyResourceTempTable.CompanyResource = NestedSelect.CompanyResource
	|
	|ORDER BY
	|	CompanyResourceTempTable.ResourceDescription,
	|	BeginTime,
	|	EndTime
	|TOTALS
	|	MIN(Capacity)
	|BY
	|	CompanyResource";
	
	Query.SetParameter("StartDate", CalendarDateBegin);
	Query.SetParameter("EndDate", CalendarDateEnd);
	Query.SetParameter("FilterByKeyResource", ResourcesList = Undefined);
	Query.SetParameter("FilterCompanyResourcesList", ResourcesList);
	Query.SetParameter("ResourcesTable", ResourcesTable);
	Query.SetParameter("CurrentDocument", CurrentDocument);
	
	Return Query.ExecuteBatch();
	
EndFunction

// The function returns the value of cell decryption.
//
&AtServer
Function GetCellDetails(CompanyResource, Interval, Capacity, Import = 0, Edit = False)
	
	DetailsStructure = New Structure;
	DetailsStructure.Insert("CompanyResource", CompanyResource);
	DetailsStructure.Insert("Interval", Interval);
	DetailsStructure.Insert("Capacity", Capacity);
	DetailsStructure.Insert("Import", Import);
	DetailsStructure.Insert("Edit", False);
	
	Return DetailsStructure;
	
EndFunction

#Region WorkWithSelection

// Procedure - event handler Action of the Pick command
//
&AtClient
Procedure WorkSelection(Command)
	
	TabularSectionName	= "Works";
	DocumentPresentaion	= NStr("en = 'work order'");
	SelectionParameters	= DriveClient.GetSelectionParameters(ThisObject, TabularSectionName, DocumentPresentaion, False, True, True);
	SelectionParameters.Insert("Company", ParentCompany);
	ProductsType = New ValueList;
	For Each ArrayElement In Items.ValWorksProducts.ChoiceParameters Do
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
		
		If TabularSectionName = "Works" Then
			
			NewRow.ConnectionKey = DriveServer.CreateNewLinkKey(ThisForm);
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Procedure of processing the results of selection closing
//
&AtClient
Procedure OnCloseSelection(ClosingResult, AdditionalParameters) Export
	
	If TypeOf(ClosingResult) = Type("Structure") Then
		
		If Not IsBlankString(ClosingResult.CartAddressInStorage) Then
			
			InventoryAddressInStorage = ClosingResult.CartAddressInStorage;
			GetInventoryFromStorage(InventoryAddressInStorage, "Works", True, False);
			// Payment calendar.
			RecalculatePaymentCalendar();
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#EndRegion

#Region ProcedureFormEventHandlers

// Procedure - OnCreateAtServer event handler.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	DriveServer.FillDocumentHeader(
		Object,
		Object.OperationKind,
		Parameters.CopyingValue,
		Parameters.Basis,
		PostingIsAllowed,
		Parameters.FillingValues
	);
	
	If Not ValueIsFilled(Object.Ref)
		  AND ValueIsFilled(Object.Counterparty) Then
		If Not ValueIsFilled(Object.Contract) Then
			Object.Contract = Object.Counterparty.ContractByDefault;
		EndIf;
		If ValueIsFilled(Object.Contract) Then
			Object.DocumentCurrency = Object.Contract.SettlementsCurrency;
			SettlementsCurrencyRateRepetition = InformationRegisters.ExchangeRates.GetLast(Object.Date, New Structure("Currency", Object.Contract.SettlementsCurrency));
			Object.ExchangeRate      = ?(SettlementsCurrencyRateRepetition.ExchangeRate = 0, 1, SettlementsCurrencyRateRepetition.ExchangeRate);
			Object.Multiplicity = ?(SettlementsCurrencyRateRepetition.Multiplicity = 0, 1, SettlementsCurrencyRateRepetition.Multiplicity);
			Object.DiscountMarkupKind = Object.Contract.DiscountMarkupKind;
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
	Object.OperationKind = Enums.OperationTypesSalesOrder.ObsoleteWorkOrder;
	WorkOrder = True;
	TabularSectionName = "Works";
	WorkKindInHeader = False;
	
	If Not ValueIsFilled(Object.Ref) Then
		
		Query = New Query(
		"SELECT ALLOWED
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
		
		// Start and Finish
		If WorkOrder AND Not (Parameters.FillingValues.Property("Start") OR Parameters.FillingValues.Property("Finish")) Then
			
			Object.Start = CurrentDate();
			Object.Finish = EndOfDay(CurrentDate());
			WhenChangingStart = Object.Start;
			WhenChangingFinish = Object.Finish;
			
		EndIf;
		
	EndIf;
	
	If Not ValueIsFilled(Object.Ref)
		AND Not ValueIsFilled(Parameters.Basis) 
		AND Not ValueIsFilled(Parameters.CopyingValue) Then
		FillVATRateByCompanyVATTaxation();
	ElsIf Object.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then	
		Items.OWWorksVATRate.Visible = True;
		Items.OWWorksAmountVAT.Visible = True;
		Items.WOWorksTotal.Visible = True;
		Items.VAT.Visible = True;
	Else
		Items.OWWorksVATRate.Visible = False;
		Items.OWWorksAmountVAT.Visible = False;
		Items.WOWorksTotal.Visible = False;
		Items.VAT.Visible = False;
	EndIf;
	
	// Generate price and currency label.
	ForeignExchangeAccounting = Constants.ForeignExchangeAccounting.Get();
	LabelStructure = New Structure("PriceKind, DiscountKind, DocumentCurrency, SettlementsCurrency, ExchangeRate, RateNationalCurrency, AmountIncludesVAT, ForeignExchangeAccounting, VATTaxation", Object.PriceKind, Object.DiscountMarkupKind, Object.DocumentCurrency, SettlementsCurrency, Object.ExchangeRate, RateNationalCurrency, Object.AmountIncludesVAT, ForeignExchangeAccounting, Object.VATTaxation);
	PricesAndCurrency = GenerateLabelPricesAndCurrency(LabelStructure);
	
	If Not ValueIsFilled(Object.Ref) Then
		AutoTitle = False;
		Title = "Work order (Creation)";
	EndIf;
	
	If ValueIsFilled(Object.Ref) Then
		NotifyWorkCalendar = False;
	Else
		NotifyWorkCalendar = True;
	EndIf; 
	DocumentModified = False;
	
	// Setting calendar period.
	CalendarDate = Object.Start;
	FillCalendarParametersOnCreateAtServer();
	CalendarDateBegin = BegOfDay(CalendarDate);
	CalendarDateEnd = EndOfDay(CalendarDate);
	
	ColorBusyResource = StyleColors.BusyResource;
	ColorEditing = StyleColors.CurrentTimeInterval;
	
	// Resources table (structure) filling.
	StructureResourcesTS = New Structure;
	ArrayOfResourcesInUse = New Array;
	For Each TSRow In Object.CompanyResources Do
		StringStructure = New Structure;
		StringStructure.Insert("CompanyResource", TSRow.CompanyResource);
		StringStructure.Insert("Capacity", TSRow.Capacity);
		StringStructure.Insert("Duration", TSRow.Duration);
		StringStructure.Insert("Start", TSRow.Start);
		StringStructure.Insert("Finish", TSRow.Finish);
		ArrayOfResourcesInUse.Add(StringStructure);
	EndDo;
	StructureResourcesTS.Insert("Ref", Object.Ref);
	StructureResourcesTS.Insert("TabularSection", ArrayOfResourcesInUse);
	
	// Status.
	If Not GetFunctionalOption("UseSalesOrderStatuses") Then
		
		Items.State.Visible = False;
		
		InProcessStatus = DriveReUse.GetStatusInProcessOfSalesOrders();
		CompletedStatus = DriveReUse.GetStatusCompletedSalesOrders();
		Items.ValStatus.ChoiceList.Add("In process", "In process");
		Items.ValStatus.ChoiceList.Add("Completed", "Completed");
		Items.ValStatus.ChoiceList.Add("Canceled", "Canceled");
		
		If Object.OrderState.OrderStatus = Enums.OrderStatuses.InProcess AND Not Object.Closed Then
			ValStatus = "In process";
		ElsIf Object.OrderState.OrderStatus = Enums.OrderStatuses.Completed Then
			ValStatus = "Completed";
		Else
			ValStatus = "Canceled";
		EndIf;
		
	Else
		
		Items.OWGroupStatuses.Visible = False;
		
	EndIf;
	
	UpdateCalendar(StructureResourcesTS);
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// Mechanism handler "ObjectVersioning".
	ObjectVersioning.OnCreateAtServer(ThisForm);
	
EndProcedure

// Procedure - OnOpen form event handler
//
&AtClient
Procedure OnOpen(Cancel)
	
	GenerateScheduledWorksPeriod();
	
	WhenChangingStart = Object.Start;
	WhenChangingFinish = Object.Finish;
	
EndProcedure

// Procedure - OnReadAtServer event handler.
//
&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	ClosingDates.ObjectOnReadAtServer(ThisForm, CurrentObject);
	
EndProcedure

// Procedure - event handler AfterWriting.
//
&AtClient
Procedure AfterWrite(WriteParameters)
	
	If DocumentModified Then
		NotifyWorkCalendar = True;
		DocumentModified = False;
		
		Notify("NotificationAboutChangingDebt");
		
	EndIf;
	
EndProcedure

// Procedure-handler of the BeforeWriteAtServer event.
// Performs initial attributes forms filling.
//
&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	If Modified Then
		DocumentModified = True;
	EndIf;
	
EndProcedure

// Procedure-handler  of the AfterWriteOnServer event.
//
&AtServer
Procedure OnWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	Title = "";
	AutoTitle = True;
	
EndProcedure

// Procedure - event handler BeforeClose form.
//
&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	If NotifyWorkCalendar AND WorkOrder Then
		Notify("ChangedWorkOrder", Object.Responsible);
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
	
	// Payment calendar.
	RecalculatePaymentCalendar();
	
	Modified = True;
	
EndProcedure

#EndRegion

#Region ProcedureEventHandlersOfHeaderAttributes

// Procedure - event handler OnChange of the Company input field.
// The procedure is used to
// clear the document number and set the parameters of the form functional options.
// Overrides the corresponding form parameter.
//
&AtClient
Procedure CompanyOnChange(Item)
	
	// Company change event data processor.
	Object.Number = "";
	StructureData = GetCompanyDataOnChange();
	ParentCompany = StructureData.ParentCompany;
	If Object.DocumentCurrency = StructureData.BankAccountCashAssetsCurrency Then
		Object.BankAccount = StructureData.BankAccount;
	EndIf;
	
	LabelStructure = New Structure("PriceKind, DiscountKind, DocumentCurrency, SettlementsCurrency, ExchangeRate, RateNationalCurrency, AmountIncludesVAT, ForeignExchangeAccounting, VATTaxation", Object.PriceKind, Object.DiscountMarkupKind, Object.DocumentCurrency, SettlementsCurrency, Object.ExchangeRate, RateNationalCurrency, Object.AmountIncludesVAT, ForeignExchangeAccounting, Object.VATTaxation);
	PricesAndCurrency = GenerateLabelPricesAndCurrency(LabelStructure);
	RecalculatePaymentCalendar();
	
EndProcedure

// Procedure - event handler OnChange of the Counterparty input field.
// Clears the contract and tabular section.
//
&AtClient
Procedure CounterpartyOnChange(Item)
	
	CounterpartyBeforeChange = Counterparty;
	Counterparty = Object.Counterparty;
	
	If CounterpartyBeforeChange <> Object.Counterparty Then
		
		StructureData = GetDataCounterpartyOnChange(Object.Date, Object.DocumentCurrency, Object.Counterparty);
		
		Object.Contract = StructureData.Contract;
		ContractBeforeChange = Contract;
		Contract = Object.Contract;
		
		SettlementsCurrencyBeforeChange = SettlementsCurrency;
		SettlementsCurrency = StructureData.SettlementsCurrency;
		
		If ValueIsFilled(Object.Contract) Then 
			Object.ExchangeRate      = ?(StructureData.SettlementsCurrencyRateRepetition.ExchangeRate = 0, 1, StructureData.SettlementsCurrencyRateRepetition.ExchangeRate);
			Object.Multiplicity = ?(StructureData.SettlementsCurrencyRateRepetition.Multiplicity = 0, 1, StructureData.SettlementsCurrencyRateRepetition.Multiplicity);
		EndIf;
		
		PriceKindChanged = Object.PriceKind <> StructureData.PriceKind 
			AND ValueIsFilled(StructureData.PriceKind);
			
		DiscountKindChanged = Object.DiscountMarkupKind <> StructureData.DiscountMarkupKind 
			AND ValueIsFilled(StructureData.DiscountMarkupKind);
			
		If ValueIsFilled(Object.Contract) 
			AND (PriceKindChanged OR DiscountKindChanged) Then
			
			RecalculationRequired = (Object.Works.Count() > 0);
			
			If PriceKindChanged Then
				
				Object.PriceKind = StructureData.PriceKind;
				
			EndIf; 
			
			If DiscountKindChanged Then
				
				Object.DiscountMarkupKind = StructureData.DiscountMarkupKind;
				
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
					
			PricesAndCurrency = GenerateLabelPricesAndCurrency(LabelStructure);
			
			If RecalculationRequired Then
			
				Message = NStr("en = 'The price and discount conditions in the contract with counterparty differ from price and discount in the document. 
				               |Recalculate the document according to the contract?'");
									
				ShowQueryBox(New NotifyDescription("CounterpartyOnChangeEnd1", ThisObject, New Structure("SettlementsCurrencyBeforeChange, ContractBeforeChange, StructureData", SettlementsCurrencyBeforeChange, ContractBeforeChange, StructureData)), Message, QuestionDialogMode.YesNo);
                Return;
				
			EndIf;
			
		EndIf; 
		
		CounterpartyOnChangeFragment1(SettlementsCurrencyBeforeChange, ContractBeforeChange, StructureData);

		
	EndIf;

EndProcedure

&AtClient
Procedure CounterpartyOnChangeEnd1(Result, AdditionalParameters) Export
    
    SettlementsCurrencyBeforeChange = AdditionalParameters.SettlementsCurrencyBeforeChange;
    ContractBeforeChange = AdditionalParameters.ContractBeforeChange;
    StructureData = AdditionalParameters.StructureData;
    
    
    If Result = DialogReturnCode.Yes Then
        
        DriveClient.RecalculateTabularSectionAmountByFlagAmountIncludesVAT(ThisForm, "Works");
        
    EndIf;
    
    
    CounterpartyOnChangeFragment1(SettlementsCurrencyBeforeChange, ContractBeforeChange, StructureData);

EndProcedure

&AtClient
Procedure CounterpartyOnChangeFragment1(Val SettlementsCurrencyBeforeChange, Val ContractBeforeChange, Val StructureData)
    
    If (ValueIsFilled(Object.Contract)
        AND ValueIsFilled(SettlementsCurrency)
        AND Object.Contract <> ContractBeforeChange
        AND SettlementsCurrencyBeforeChange <> StructureData.SettlementsCurrency)
        AND Object.DocumentCurrency <> StructureData.SettlementsCurrency Then
        
        If Object.DocumentCurrency <> StructureData.SettlementsCurrency Then
            
            Object.BankAccount = Undefined;
            
        EndIf;
        
        Object.DocumentCurrency = StructureData.SettlementsCurrency;
        ShowMessageBox(New NotifyDescription("CounterpartyOnChangeEnd", ThisObject, New Structure("SettlementsCurrencyBeforeChange, StructureData", SettlementsCurrencyBeforeChange, StructureData)), NStr("en = 'Contract currency of the counterparty has changed. Check the document currency.'"));
        Return;
        
    EndIf;
    
    CounterpartyOnChangeFragment(StructureData);

EndProcedure

&AtClient
Procedure CounterpartyOnChangeEnd(AdditionalParameters) Export
    
    SettlementsCurrencyBeforeChange = AdditionalParameters.SettlementsCurrencyBeforeChange;
    StructureData = AdditionalParameters.StructureData;
    
    
    ProcessChangesOnButtonPricesAndCurrencies(SettlementsCurrencyBeforeChange, True);
    
    
    CounterpartyOnChangeFragment(StructureData);

EndProcedure

&AtClient
Procedure CounterpartyOnChangeFragment(Val StructureData)
    
    SettlementsCurrency = StructureData.SettlementsCurrency;

EndProcedure

// The OnChange event handler of the Contract field.
// It updates the currency exchange rate and exchange rate multiplier.
//
&AtClient
Procedure ContractOnChange(Item)
	
	ContractBeforeChange = Contract;
	Contract = Object.Contract;
		
	If ContractBeforeChange <> Object.Contract Then
		
		StructureData = GetDataContractOnChange(Object.Date, Object.DocumentCurrency, Object.Contract);
		
		SettlementsCurrencyBeforeChange = SettlementsCurrency;
		SettlementsCurrency = StructureData.SettlementsCurrency;
		
		If ValueIsFilled(Object.Contract) Then 
			Object.ExchangeRate      = ?(StructureData.SettlementsCurrencyRateRepetition.ExchangeRate = 0, 1, StructureData.SettlementsCurrencyRateRepetition.ExchangeRate);
			Object.Multiplicity = ?(StructureData.SettlementsCurrencyRateRepetition.Multiplicity = 0, 1, StructureData.SettlementsCurrencyRateRepetition.Multiplicity);
		EndIf;
		
		PriceKindChanged = Object.PriceKind <> StructureData.PriceKind 
			AND ValueIsFilled(StructureData.PriceKind);
			
		DiscountKindChanged = Object.DiscountMarkupKind <> StructureData.DiscountMarkupKind 
			AND ValueIsFilled(StructureData.DiscountMarkupKind);
			
		If ValueIsFilled(Object.Contract) 
			AND (PriceKindChanged OR DiscountKindChanged) Then
			
			RecalculationRequired = (Object.Works.Count() > 0);
			
			If PriceKindChanged Then
				
				Object.PriceKind = StructureData.PriceKind;
				
			EndIf; 
			
			If DiscountKindChanged Then
				
				Object.DiscountMarkupKind = StructureData.DiscountMarkupKind;
				
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
					
			PricesAndCurrency = GenerateLabelPricesAndCurrency(LabelStructure);
			
			If RecalculationRequired Then
			
				Message = NStr("en = 'The price and discount conditions in the contract with counterparty differ from price and discount in the document. 
				               |Recalculate the document according to the contract?'");
									
				ShowQueryBox(New NotifyDescription("ContractOnChangeEnd1", ThisObject, New Structure("SettlementsCurrencyBeforeChange, ContractBeforeChange, StructureData", SettlementsCurrencyBeforeChange, ContractBeforeChange, StructureData)), Message, QuestionDialogMode.YesNo);
                Return;
				
			EndIf;
			
		EndIf; 
		
		ContractOnChangeFragment(SettlementsCurrencyBeforeChange, ContractBeforeChange, StructureData);

	
	EndIf;
	
EndProcedure

&AtClient
Procedure ContractOnChangeEnd1(Result, AdditionalParameters) Export
    
    SettlementsCurrencyBeforeChange = AdditionalParameters.SettlementsCurrencyBeforeChange;
    ContractBeforeChange = AdditionalParameters.ContractBeforeChange;
    StructureData = AdditionalParameters.StructureData;
    
    
    If Result = DialogReturnCode.Yes Then
        
        DriveClient.RecalculateTabularSectionAmountByFlagAmountIncludesVAT(ThisForm, "Works");
        
    EndIf;
    
    
    ContractOnChangeFragment(SettlementsCurrencyBeforeChange, ContractBeforeChange, StructureData);

EndProcedure

&AtClient
Procedure ContractOnChangeFragment(Val SettlementsCurrencyBeforeChange, Val ContractBeforeChange, Val StructureData)
    
    If (ValueIsFilled(Object.Contract)
        AND ValueIsFilled(SettlementsCurrency)
        AND Object.Contract <> ContractBeforeChange
        AND SettlementsCurrencyBeforeChange <> StructureData.SettlementsCurrency)
        AND Object.DocumentCurrency <> StructureData.SettlementsCurrency Then
        
        If Object.DocumentCurrency <> StructureData.SettlementsCurrency Then
            
            Object.BankAccount = Undefined;
            
        EndIf;
        
        Object.DocumentCurrency = StructureData.SettlementsCurrency;
        ShowMessageBox(New NotifyDescription("ContractOnChangeEnd", ThisObject, New Structure("SettlementsCurrencyBeforeChange", SettlementsCurrencyBeforeChange)), NStr("en = 'Contract currency of the counterparty has changed. Check document currency.'"));
        
    EndIf;

EndProcedure

&AtClient
Procedure ContractOnChangeEnd(AdditionalParameters) Export
    
    SettlementsCurrencyBeforeChange = AdditionalParameters.SettlementsCurrencyBeforeChange;
    
    
    ProcessChangesOnButtonPricesAndCurrencies(SettlementsCurrencyBeforeChange, True);

EndProcedure

// Procedure - event handler OnChange of the OrderState input field.
//
&AtClient
Procedure OWOrderStatusOnChange(Item)
	
	Status = GetDataOrderStateOnChange(Object.OrderState);
	
	If TrimAll(Status) = "Completed" Then
	
	Else
		If Object.Prepayment.Count() > 0 Then
			Object.Prepayment.Clear();
		EndIf;
	EndIf;
	
	If TrimAll(Status) = "Open" Then
		Object.SetPaymentTerms = False;
		If Object.PaymentCalendar.Count() > 0 Then
			Object.PaymentCalendar.Clear();
		EndIf;
	EndIf;
	
EndProcedure

// Procedure - OnChange event handler of Resource input field.
//
&AtClient
Procedure FilterKeyResourceOnChange(Item)
	
	StructureResourcesTS = GetTableOfResourcesInUse();
	UpdateCalendar(StructureResourcesTS);
	
EndProcedure

// Procedure - OnChange event handler of ResourceKind input field.
//
&AtClient
Procedure FilterResourceKindOnChange(Item)
	
	StructureResourcesTS = GetTableOfResourcesInUse();
	UpdateCalendar(StructureResourcesTS);
	
EndProcedure

// Procedure - handler of Calendar command.
//
&AtClient
Procedure PeriodPresentationStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	ParametersStructure = New Structure("CalendarDate", CalendarDate);
	CalendarDateBegin = Undefined;

	OpenForm("CommonForm.Calendar", ParametersStructure,,,,, New NotifyDescription("PeriodPresentationStartChoiceEnd", ThisObject));
	
EndProcedure

&AtClient
Procedure PeriodPresentationStartChoiceEnd(Result, AdditionalParameters) Export
	
	If ValueIsFilled(Result) Then
		
		CalendarDateBegin = Result;
		
		CalendarDate = EndOfDay(CalendarDateBegin);
		GenerateScheduledWorksPeriod();
		
		StructureResourcesTS = GetTableOfResourcesInUse();
		UpdateCalendar(StructureResourcesTS);
		
	EndIf;
	
EndProcedure

// Procedure - handler of ShortenPeriod command.
//
&AtClient
Procedure ShortenPeriod(Command)
	
	CalendarDate = EndOfDay(CalendarDate - 60 * 60 * 24);
	GenerateScheduledWorksPeriod();
	
	StructureResourcesTS = GetTableOfResourcesInUse();
	UpdateCalendar(StructureResourcesTS);
	
EndProcedure

// Procedure - handler of ExtendPeriod command.
//
&AtClient
Procedure ExtendPeriod(Command)
	
	CalendarDate = EndOfDay(CalendarDate + 60 * 60 * 24);
	GenerateScheduledWorksPeriod();
	
	StructureResourcesTS = GetTableOfResourcesInUse();
	UpdateCalendar(StructureResourcesTS);
	
EndProcedure

// Procedure - Refresh command handler.
//
&AtClient
Procedure Refresh(Command)
	
	StructureResourcesTS = GetTableOfResourcesInUse();
	UpdateCalendar(StructureResourcesTS);
	
EndProcedure

// Procedure - event handler OnChange input field Start.
//
&AtClient
Procedure StartOnChange(Item)
	
	If Object.Start > Object.Finish Then
		Object.Start = WhenChangingStart;
		CommonUseClientServer.MessageToUser(NStr("en = 'The start date cannot be later than the end date.'"));
	Else
		WhenChangingStart = Object.Start;
	EndIf;
	
EndProcedure

// Procedure - event handler OnChange input field Finish.
//
&AtClient
Procedure FinishOnChange(Item)
	
	If Hour(Object.Finish) = 0 AND Minute(Object.Finish) = 0 Then
		Object.Finish = EndOfDay(Object.Finish);
	EndIf;
	
	If Object.Finish < Object.Start Then
		Object.Finish = WhenChangingFinish;
		CommonUseClientServer.MessageToUser(NStr("en = 'The end date cannot be earlier than the start date.'"));
	Else
		WhenChangingFinish = Object.Finish;
	EndIf;
	
EndProcedure

// Procedure - event handler OnChange input field Status.
//
&AtClient
Procedure VALStatusOnChange(Item)
	
	If Status = "In process" Then
		Object.OrderState = InProcessStatus;
		Object.Closed = False;
	ElsIf Status = "Completed" Then
		Object.OrderState = CompletedStatus;
		Object.Closed = True;
	ElsIf Status = "Canceled" Then
		Object.OrderState = InProcessStatus;
		Object.Closed = True;
	EndIf;
	
	Modified = True;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - EVENT HANDLERS OF WO TABULAR SECTION ATTRIBUTES

/////////////////// WORK From SUBORDINATES CWT ///////////////////////////////////

// Procedure - event handler OnActivateRow tabular sectionp "Works".
//
&AtClient
Procedure WorksOnActivateRow(Item)
	
	TabularSectionName = "Works";
	
EndProcedure

// Procedure - event handler OnStartEdit tabular section Works.
//
&AtClient
Procedure WorksOnStartEdit(Item, NewRow, Copy)
	
	TabularSectionName = "Works";
	If NewRow Then
		DriveClient.AddConnectionKeyToTabularSectionLine(ThisForm);
	EndIf;
	
EndProcedure

// Procedure - event handler BeforeDelete tabular section Works.
//
&AtClient
Procedure WorksBeforeDelete(Item, Cancel)

	TabularSectionName = "Works";
	DriveClient.DeleteRowsOfSubordinateTabularSection(ThisForm, "Materials");
	DriveClient.DeleteRowsOfSubordinateTabularSection(ThisForm, "Performers");
	
EndProcedure

// Procedure - event handler OnEditEnd of tabular section Works.
//
&AtClient
Procedure WorksOnEditEnd(Item, NewRow, CancelEdit)
	
	// Payment calendar.
	RecalculatePaymentCalendar();

EndProcedure

// Procedure - event handler AfterDeleteRow tabular section Works.
//
&AtClient
Procedure WorksAfterDeleteRow(Item)
	
	// Payment calendar.
	RecalculatePaymentCalendar();

EndProcedure

// Procedure - event handler BeforeAddStart tabular section "Works".
//
&AtClient
Procedure WorksBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	If Copy Then
		RowCopyWorks = True;
	EndIf;
	
EndProcedure

// Procedure - event handler OnChange tabular section "Works".
//
&AtClient
Procedure WorksOnChange(Item)
	
	If RowCopyWorks = Undefined OR Not RowCopyWorks Then
	Else
		RowCopyWorks = False;
	EndIf;
	
EndProcedure

// Procedure - event handler OnChange of the Products input field.
//
&AtClient
Procedure WorksProductsOnChange(Item)
	
	TabularSectionRow = Items.Works.CurrentData;
	
	TabularSectionName = "Works";
	DriveClient.DeleteRowsOfSubordinateTabularSection(ThisForm, "Materials");
	DriveClient.DeleteRowsOfSubordinateTabularSection(ThisForm, "Performers");
	
	StructureData = New Structure;
	StructureData.Insert("Company", Object.Company);
	StructureData.Insert("Products", TabularSectionRow.Products);
	StructureData.Insert("Characteristic", TabularSectionRow.Characteristic);
	StructureData.Insert("ProcessingDate", Object.Date);
	StructureData.Insert("TimeNorm", 1);
	StructureData.Insert("VATTaxation", Object.VATTaxation);
	
	If WorkKindInHeader AND ValueIsFilled(Object.PriceKind) Then
		StructureData.Insert("DocumentCurrency", Object.DocumentCurrency);
		StructureData.Insert("AmountIncludesVAT", Object.AmountIncludesVAT);
		StructureData.Insert("PriceKind", Object.PriceKind);
		StructureData.Insert("Factor", 1);
		StructureData.Insert("WorkKind", Object.WorkKind);
		StructureData.Insert("DiscountMarkupKind", Object.DiscountMarkupKind);
	ElsIf (NOT WorkKindInHeader) AND ValueIsFilled(Object.PriceKind) Then
		StructureData.Insert("DocumentCurrency", Object.DocumentCurrency);
		StructureData.Insert("AmountIncludesVAT", Object.AmountIncludesVAT);
		StructureData.Insert("PriceKind", Object.PriceKind);
		StructureData.Insert("Factor", 1);
		StructureData.Insert("WorkKind", TabularSectionRow.WorkKind);
		StructureData.Insert("DiscountMarkupKind", Object.DiscountMarkupKind);
	EndIf;
	
	StructureData = GetDataProductsOnChange(StructureData);
	
	TabularSectionRow.Quantity = StructureData.TimeNorm;
	TabularSectionRow.Multiplicity = 1; 
	TabularSectionRow.Factor = 1;
	TabularSectionRow.VATRate = StructureData.VATRate;
	TabularSectionRow.Specification = StructureData.Specification;
	TabularSectionRow.Content = "";
	
	If (WorkKindInHeader AND ValueIsFilled(Object.PriceKind) AND StructureData.Property("Price")) OR StructureData.Property("Price") Then
		TabularSectionRow.Price = StructureData.Price;
		TabularSectionRow.DiscountMarkupPercent = StructureData.DiscountMarkupPercent;
	EndIf;
	
	TabularSectionRow.ProductsTypeService = StructureData.IsService;
	
	CalculateAmountInTabularSectionLine("Works");
	
EndProcedure

// Procedure - event handler OnChange of the Characteristic input field.
//
&AtClient
Procedure WorksCharacteristicOnChange(Item)
	
	TabularSectionRow = Items.Works.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("Company", Object.Company);
	StructureData.Insert("Products", TabularSectionRow.Products);
	StructureData.Insert("Characteristic", TabularSectionRow.Characteristic);
	StructureData.Insert("ProcessingDate", Object.Date);
	StructureData.Insert("TimeNorm", 1);
	
	If WorkKindInHeader AND ValueIsFilled(Object.PriceKind) Then
		StructureData.Insert("DocumentCurrency", Object.DocumentCurrency);
		StructureData.Insert("AmountIncludesVAT", Object.AmountIncludesVAT);
		StructureData.Insert("PriceKind", Object.PriceKind);
		StructureData.Insert("Factor", 1);
		StructureData.Insert("WorkKind", Object.WorkKind);
		StructureData.Insert("DiscountMarkupKind", Object.DiscountMarkupKind);
	EndIf;
	
	StructureData = GetDataProductsOnChange(StructureData);
	
	TabularSectionRow.Quantity = StructureData.TimeNorm;
	TabularSectionRow.Multiplicity = 1; 
	TabularSectionRow.Factor = 1; 
	TabularSectionRow.VATRate = StructureData.VATRate;
	TabularSectionRow.Content = "";
	TabularSectionRow.Specification = StructureData.Specification;
	
	If (WorkKindInHeader AND ValueIsFilled(Object.PriceKind)) OR StructureData.Property("Price") Then
		TabularSectionRow.Price = StructureData.Price;
		TabularSectionRow.DiscountMarkupPercent = StructureData.DiscountMarkupPercent;
	EndIf;
	
	CalculateAmountInTabularSectionLine("Works");
	
EndProcedure

// Procedure - event handler AutoPick of the Content input field.
//
&AtClient
Procedure VALWorksContentAutoPick(Item, Text, ChoiceData, Parameters, Wait, StandardProcessing)
	
	If Wait = 0 Then
		
		StandardProcessing = False;
		
		TabularSectionRow = Items.Works.CurrentData;
		ContentPattern = DriveServer.GetContentText(TabularSectionRow.Products, TabularSectionRow.Characteristic);
		
		ChoiceData = New ValueList;
		ChoiceData.Add(ContentPattern);
		
	EndIf;
	
EndProcedure

// Procedure - event handler OnChange input field WorkKind.
//
&AtClient
Procedure WorksWorkKindOnChange(Item)
	
	If ValueIsFilled(Object.PriceKind) Then
	
		TabularSectionRow = Items.Works.CurrentData;
	
		StructureData = New Structure;
		StructureData.Insert("Company", ParentCompany);
		StructureData.Insert("Products", TabularSectionRow.Products);
		StructureData.Insert("Characteristic", TabularSectionRow.Characteristic);
		StructureData.Insert("WorkKind", TabularSectionRow.WorkKind);
		
		StructureData.Insert("ProcessingDate", 			Object.Date);
		StructureData.Insert("DocumentCurrency", 		Object.DocumentCurrency);
		StructureData.Insert("AmountIncludesVAT", 		Object.AmountIncludesVAT);
		StructureData.Insert("PriceKind", Object.PriceKind);
		StructureData.Insert("Factor", 1);
		
		StructureData.Insert("DiscountMarkupKind", Object.DiscountMarkupKind);
			
		StructureData = GetDataProductsOnChange(StructureData);
		
		TabularSectionRow.Price = StructureData.Price;
		TabularSectionRow.DiscountMarkupPercent = StructureData.DiscountMarkupPercent;
			
		CalculateAmountInTabularSectionLine("Works");
	
	EndIf;
	
EndProcedure

// Procedure - event handler OnChange of the Count input field.
//
&AtClient
Procedure WorksQuantityOnChange(Item)
	
	CalculateAmountInTabularSectionLine("Works");
	
	// Payment calendar.
	RecalculatePaymentCalendar();
	
EndProcedure

// Procedure - event handler OnChange of the Count input field.
//
&AtClient
Procedure WorksFactorOnChange(Item)
	
	CalculateAmountInTabularSectionLine("Works");
	
	// Payment calendar.
	RecalculatePaymentCalendar();
	
EndProcedure

// Procedure - event handler OnChange of the Count input field.
//
&AtClient
Procedure WorksRepetitionOnChange(Item)
	
	CalculateAmountInTabularSectionLine("Works");
	
	// Payment calendar.
	RecalculatePaymentCalendar();
	
EndProcedure

// Procedure - event handler OnChange of the Price input field.
//
&AtClient
Procedure WorksPriceOnChange(Item)
	
	CalculateAmountInTabularSectionLine("Works");
	
	// Payment calendar.
	RecalculatePaymentCalendar();
	
EndProcedure

// Procedure - event handler OnChange of the DiscountMarkupPercent input field.
//
&AtClient
Procedure WorksDiscountMarkupPercentOnChange(Item)
	
	CalculateAmountInTabularSectionLine("Works");
	
	// Payment calendar.
	RecalculatePaymentCalendar();
	
EndProcedure

// Procedure - event handler OnChange of the Amount input field.
//
&AtClient
Procedure WorksAmountOnChange(Item)
	
	TabularSectionRow = Items.Works.CurrentData;
	
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
		
	// VAT amount.
	CalculateVATSUM(TabularSectionRow);
	
	// Total.	
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
	// Payment calendar.
	RecalculatePaymentCalendar();
	
EndProcedure

// Procedure - event handler OnChange of the VATRate input field.
//
&AtClient
Procedure WorksVATRateOnChange(Item)
	
	TabularSectionRow = Items.Works.CurrentData;
	
	// VAT amount.
	CalculateVATSUM(TabularSectionRow);
	
	// Total.	
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
	// Payment calendar.
	RecalculatePaymentCalendar();
	
EndProcedure

// Procedure - event handler OnChange of the VATRate input field.
//
&AtClient
Procedure WorksAmountVATOnChange(Item)
	
	TabularSectionRow = Items.Works.CurrentData;
	
	// Total.	
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
	// Payment calendar.
	RecalculatePaymentCalendar();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - EVENTS HANDLERS OF THE ENTERPRISE RESOURCES TABULAR SECTION ATTRIBUTES

// Procedure calculates start and finish values.
//
&AtClient
Procedure CalculateStartAndFinishOfRequest()
	
	MinStart = '00010101';
	MaxFinish = '00010101';
	For Each RowResource In Object.CompanyResources Do
		If MinStart > RowResource.Start OR MinStart = '00010101' Then
			MinStart = RowResource.Start;
		EndIf;
		If MaxFinish < RowResource.Finish OR MaxFinish = '00010101' Then
			MaxFinish = RowResource.Finish;
		EndIf;
	EndDo;
	
	Object.Start = MinStart;
	Object.Finish = MaxFinish;
	
	WhenChangingStart = Object.Start;
	WhenChangingFinish = Object.Finish;
	
EndProcedure

// Procedure calculates the operation duration.
//
// Parameters:
//  No.
//
&AtClient
Function CalculateDuration(CurrentRow)
	
	DurationInSeconds = CurrentRow.Finish - CurrentRow.Start;
	Hours = Int(DurationInSeconds / 3600);
	Minutes = (DurationInSeconds - Hours * 3600) / 60;
	Duration = Date(0001, 01, 01, Hours, Minutes, 0);
	
	Return Duration;
	
EndFunction

// It receives data set from the server for the CompanyResourcesOnStartEdit procedure.
//
&AtClient
Function GetDataCompanyResourcesOnStartEdit(DataStructure)
	
	DataStructure.Start = Object.Start - Second(Object.Start);
	DataStructure.Finish = Object.Finish - Second(Object.Finish);
	
	If ValueIsFilled(DataStructure.Start) AND ValueIsFilled(DataStructure.Finish) Then
		If BegOfDay(DataStructure.Start) <> BegOfDay(DataStructure.Finish) Then
			DataStructure.Finish = EndOfDay(DataStructure.Start) - 59;
		EndIf;
		If DataStructure.Start >= DataStructure.Finish Then
			DataStructure.Finish = DataStructure.Start + 1800;
			If BegOfDay(DataStructure.Finish) <> BegOfDay(DataStructure.Start) Then
				If EndOfDay(DataStructure.Start) = DataStructure.Start Then
					DataStructure.Start = DataStructure.Start - 29 * 60;
				EndIf;
				DataStructure.Finish = EndOfDay(DataStructure.Start) - 59;
			EndIf;
		EndIf;
	ElsIf ValueIsFilled(DataStructure.Start) Then
		DataStructure.Start = DataStructure.Start;
		DataStructure.Finish = EndOfDay(DataStructure.Start) - 59;
		If DataStructure.Finish = DataStructure.Start Then
			DataStructure.Start = BegOfDay(DataStructure.Start);
		EndIf;
	ElsIf ValueIsFilled(DataStructure.Finish) Then
		DataStructure.Start = BegOfDay(DataStructure.Finish);
		DataStructure.Finish = DataStructure.Finish;
		If DataStructure.Finish = DataStructure.Start Then
			DataStructure.Finish = EndOfDay(DataStructure.Finish) - 59;
		EndIf;
	Else
		DataStructure.Start = BegOfDay(CurrentDate());
		DataStructure.Finish = EndOfDay(CurrentDate()) - 59;
	EndIf;
	
	DurationInSeconds = DataStructure.Finish - DataStructure.Start;
	Hours = Int(DurationInSeconds / 3600);
	Minutes = (DurationInSeconds - Hours * 3600) / 60;
	Duration = Date(0001, 01, 01, Hours, Minutes, 0);
	DataStructure.Duration = Duration;
	
	Return DataStructure;
	
EndFunction

// Procedure - event handler OnStartEdit tabular section CompanyResources.
//
&AtClient
Procedure CompanyResourcesOnStartEdit(Item, NewRow, Copy)
	
	If NewRow Then
		
		TabularSectionRow = Items.CompanyResources.CurrentData;
		
		DataStructure = New Structure;
		DataStructure.Insert("Start", '00010101');
		DataStructure.Insert("Finish", '00010101');
		DataStructure.Insert("Duration", '00010101');
		
		DataStructure = GetDataCompanyResourcesOnStartEdit(DataStructure);
		TabularSectionRow.Start = DataStructure.Start;
		TabularSectionRow.Finish = DataStructure.Finish;
		TabularSectionRow.Duration = DataStructure.Duration;
		
		CalculateStartAndFinishOfRequest();
		
	EndIf;
	
EndProcedure

// Procedure - handler of event AfterDelete of the CompanyResources tabular section.
//
&AtClient
Procedure CompanyResourcesAfterDeleteRow(Item)
	
	CalculateStartAndFinishOfRequest();
	
EndProcedure

// Procedure - event handler OnChange input field CompanyResource.
//
&AtClient
Procedure CompanyResourcesCompanyResourceOnChange(Item)
	
	TabularSectionRow = Items.CompanyResources.CurrentData;
	TabularSectionRow.Capacity = 1;
	
EndProcedure

// Procedure - event handler OnChange input field Day.
//
&AtClient
Procedure CompanyResourcesDayOnChange(Item)
	
	CurrentRow = Items.CompanyResources.CurrentData;
	
	If CurrentRow.Start = '00010101' Then
		CurrentRow.Start = CurrentDate();
	EndIf;
	
	FinishInSeconds = Hour(CurrentRow.Finish) * 3600 + Minute(CurrentRow.Finish) * 60;
	DurationInSeconds = Hour(CurrentRow.Duration) * 3600 + Minute(CurrentRow.Duration) * 60;
	CurrentRow.Finish = BegOfDay(CurrentRow.Start) + FinishInSeconds;
	CurrentRow.Start = CurrentRow.Finish - DurationInSeconds;
	
	CalculateStartAndFinishOfRequest();
	
EndProcedure

// Procedure - event handler OnChange input field Duration.
//
&AtClient
Procedure CompanyResourcesDurationOnChange(Item)
	
	CurrentRow = Items.CompanyResources.CurrentData;
	DurationInSeconds = Hour(CurrentRow.Duration) * 3600 + Minute(CurrentRow.Duration) * 60;
	If DurationInSeconds = 0 Then
		CurrentRow.Finish = CurrentRow.Start + 1800;
	Else
		CurrentRow.Finish = CurrentRow.Start + DurationInSeconds;
	EndIf;
	If BegOfDay(CurrentRow.Start) <> BegOfDay(CurrentRow.Finish) Then
		CurrentRow.Finish = EndOfDay(CurrentRow.Start) - 59;
	EndIf;
	If CurrentRow.Start >= CurrentRow.Finish Then
		CurrentRow.Finish = CurrentRow.Start + 1800;
		If BegOfDay(CurrentRow.Finish) <> BegOfDay(CurrentRow.Start) Then
			If EndOfDay(CurrentRow.Start) = CurrentRow.Start Then
				CurrentRow.Start = CurrentRow.Start - 29 * 60;
			EndIf;
			CurrentRow.Finish = EndOfDay(CurrentRow.Start) - 59;
		EndIf;
	EndIf;
	
	CurrentRow.Duration = CalculateDuration(CurrentRow);
	
	CalculateStartAndFinishOfRequest();
	
EndProcedure

// Procedure - event handler OnChange input field Start.
//
&AtClient
Procedure CompanyResourcesStartOnChange(Item)
	
	CurrentRow = Items.CompanyResources.CurrentData;
	
	If CurrentRow.Start = '00010101' Then
		CurrentRow.Start = BegOfDay(CurrentRow.Finish);
	EndIf;
	
	If CurrentRow.Start >= CurrentRow.Finish Then
		CurrentRow.Finish = CurrentRow.Start + 1800;
		If BegOfDay(CurrentRow.Finish) <> BegOfDay(CurrentRow.Start) Then
			If EndOfDay(CurrentRow.Start) = CurrentRow.Start Then
				CurrentRow.Start = CurrentRow.Start - 29 * 60;
			EndIf;
			CurrentRow.Finish = EndOfDay(CurrentRow.Start) - 59;
		EndIf;
	EndIf;
	
	CurrentRow.Duration = CalculateDuration(CurrentRow);
	
	CalculateStartAndFinishOfRequest();
	
EndProcedure

// Procedure - event handler OnChange input field Finish.
//
&AtClient
Procedure CompanyResourcesFinishOnChange(Item)
	
	CurrentRow = Items.CompanyResources.CurrentData;
	
	If Hour(CurrentRow.Finish) = 0 AND Minute(CurrentRow.Finish) = 0 Then
		CurrentRow.Finish = EndOfDay(CurrentRow.Start) - 59;
	EndIf;
	If CurrentRow.Start >= CurrentRow.Finish Then
		CurrentRow.Finish = CurrentRow.Start + 1800;
		If BegOfDay(CurrentRow.Finish) <> BegOfDay(CurrentRow.Start) Then
			If EndOfDay(CurrentRow.Start) = CurrentRow.Start Then
				CurrentRow.Start = CurrentRow.Start - 29 * 60;
			EndIf;
			CurrentRow.Finish = EndOfDay(CurrentRow.Start) - 59;
		EndIf;
	EndIf;
	
	CurrentRow.Duration = CalculateDuration(CurrentRow);
	
	CalculateStartAndFinishOfRequest();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - EVENT HANDLERS OF TABULAR DOCUMENT

// Procedure - DecryptionProcessor event handler.
//
&AtClient
Procedure ResourcesImportDetailProcessing(Item, Details, StandardProcessing)
	
	If TypeOf(Details) = Type("Structure") Then
		
		StandardProcessing = False;
		
		MatchFound = False;
		SearchStructure = New Structure;
		SearchStructure.Insert("CompanyResource", Details.CompanyResource);
		RowArray = Object.CompanyResources.FindRows(SearchStructure);
		For Each RowsArrayItm In RowArray Do
			If RowsArrayItm.Start = Details.Interval
				AND RowsArrayItm.Finish = Details.Interval + RepetitionFactorOFDay * 60 
				AND Not MatchFound Then
				RowsArrayItm.Capacity = RowsArrayItm.Capacity + 1;
				MatchFound = True;
			EndIf;
		EndDo;
		
		If Not MatchFound Then
			NewRow = Object.CompanyResources.Add();
			NewRow.CompanyResource = Details.CompanyResource;
			NewRow.Capacity = 1;
			NewRow.Start = Details.Interval;
			NewRow.Finish = Details.Interval + RepetitionFactorOFDay * 60;
			NewRow.Duration = CalculateDuration(NewRow);
			CalculateStartAndFinishOfRequest();
		EndIf;
		
		UpdateCalendarCell(Item.CurrentArea.Name, Details);
		Modified = True;
		
	EndIf;
	
EndProcedure

// Procedure - handler of the UseResource command.
//
&AtClient
Procedure UseResource(Command)
	
	ResourcesListChanged = False;
	CurrentCalendarArea = Items.ResourcesImport.CurrentArea;
	FirstRow = CurrentCalendarArea.Top;
	LastRow = CurrentCalendarArea.Bottom;
	LastColumn = CurrentCalendarArea.Right;
	While FirstRow <= LastRow Do
		
		PickupStructure = New Structure;
		PickupStructure.Insert("CompanyResource");
		PickupStructure.Insert("Capacity");
		PickupStructure.Insert("Start");
		PickupStructure.Insert("Finish");
		PickupStructure.Insert("Duration");
		
		NewInterval = False;
		FirstStart = True;
		FirstColumn = CurrentCalendarArea.Left;
		While FirstColumn <= LastColumn Do
			CellDetails = ResourcesImport.Area(FirstRow, FirstColumn).Details;
			If TypeOf(CellDetails) = Type("Structure") Then
				
				If FirstStart Then
					NewInterval = True;
					PickupStructure.CompanyResource = CellDetails.CompanyResource;
					PickupStructure.Capacity = 1;
					PickupStructure.Start = CellDetails.Interval;
					
					FirstStart = False;
					ResourcesListChanged = True;
				EndIf;
				
				If NewInterval <> Undefined Then
					PickupStructure.Finish = CellDetails.Interval + RepetitionFactorOFDay * 60;
				EndIf;
				
				CurrentAreaName = "R" + FirstRow + "C" + FirstColumn;
				UpdateCalendarCell(CurrentAreaName, CellDetails);
				
			EndIf;
			FirstColumn = FirstColumn + 1;
		EndDo;
		
		If NewInterval Then
			
			MatchFound = False;
			SearchStructure = New Structure;
			SearchStructure.Insert("CompanyResource", PickupStructure.CompanyResource);
			RowArray = Object.CompanyResources.FindRows(SearchStructure);
			For Each RowsArrayItm In RowArray Do
				If RowsArrayItm.Start = PickupStructure.Start
					AND RowsArrayItm.Finish = PickupStructure.Finish
					AND Not MatchFound Then
					RowsArrayItm.Capacity = RowsArrayItm.Capacity + 1;
					MatchFound = True;
				EndIf;
			EndDo;
			
			If Not MatchFound Then
				NewRow = Object.CompanyResources.Add();
				NewRow.CompanyResource = PickupStructure.CompanyResource;
				NewRow.Capacity = PickupStructure.Capacity;
				NewRow.Start = PickupStructure.Start;
				NewRow.Finish = PickupStructure.Finish;
				NewRow.Duration = CalculateDuration(NewRow);
				CalculateStartAndFinishOfRequest();
			EndIf;
			
		EndIf;
		
		FirstRow = FirstRow + 1;
	EndDo;
	
	If ResourcesListChanged Then
		CalculateStartAndFinishOfRequest();
		Modified = True;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

// StandardSubsystems.AdditionalReportsAndDataProcessors

&AtClient
Procedure Attachable_ExecuteAssignedCommand(Command)
	If Not AdditionalReportsAndDataProcessorsClient.ExecuteAllocatedCommandAtClient(ThisForm, Command.Name) Then
		ExecutionResult = Undefined;
		AdditionalReportsAndProcessingsExecuteAllocatedCommandAtServer(Command.Name, ExecutionResult);
		AdditionalReportsAndDataProcessorsClient.ShowCommandExecutionResult(ThisForm, ExecutionResult);
	EndIf;
EndProcedure

// End StandardSubsystems.AdditionalReportsAndDataProcessors

#EndRegion

#Region ServiceProceduresAndFunctions

// StandardSubsystems.AdditionalReportsAndDataProcessors

&AtServer
Procedure AdditionalReportsAndProcessingsExecuteAllocatedCommandAtServer(ItemName, ExecutionResult)
	AdditionalReportsAndDataProcessors.ExecuteAllocatedCommandAtServer(ThisForm, ItemName, ExecutionResult);
EndProcedure

// End StandardSubsystems.AdditionalReportsAndDataProcessors

#Region InteractiveActionResultHandlers

&AtClient
// Procedure-handler of the result of opening the "Prices and currencies" form
//
Procedure OpenPricesAndCurrencyFormEnd(ClosingResult, AdditionalParameters) Export
	
	If TypeOf(ClosingResult) = Type("Structure") 
		AND ClosingResult.WereMadeChanges Then
		
		Modified = True;
		
		If Object.DocumentCurrency <> ClosingResult.DocumentCurrency Then
			Object.BankAccount = Undefined;
		EndIf;
		
		Object.PriceKind = ClosingResult.PriceKind;
		Object.DiscountMarkupKind = ClosingResult.DiscountKind;
		Object.DocumentCurrency = ClosingResult.DocumentCurrency;
		Object.ExchangeRate = ClosingResult.PaymentsRate;
		Object.Multiplicity = ClosingResult.SettlementsMultiplicity;
		Object.AmountIncludesVAT = ClosingResult.AmountIncludesVAT;
		Object.IncludeVATInPrice = ClosingResult.IncludeVATInPrice;
		Object.VATTaxation = ClosingResult.VATTaxation;
		SettlementsCurrencyBeforeChange = AdditionalParameters.SettlementsCurrencyBeforeChange;
		
		// Recalculate prices by kind of prices.
		If ClosingResult.RefillPrices Then
			RefillTabularSectionPricesByPriceKind();
		EndIf;

		// Recalculate prices by currency.
		If Not ClosingResult.RefillPrices
			AND ClosingResult.RecalculatePrices Then
			
			DriveClient.RecalculateTabularSectionPricesByCurrency(ThisForm, SettlementsCurrencyBeforeChange, "Inventory");
			
			If Not ClosingResult.RefillPrices Then
				
				DriveClient.RecalculateTabularSectionPricesByCurrency(ThisForm, SettlementsCurrencyBeforeChange, "Works");
				
			EndIf;
			
		EndIf;
		
		// Recalculate the amount if VAT taxation flag is changed.
		If ClosingResult.VATTaxation <> ClosingResult.PrevVATTaxation Then
			
			FillVATRateByVATTaxation();
			
		EndIf;
		
		// Recalculate the amount if the "Amount includes VAT" flag is changed.
		If Not ClosingResult.RefillPrices
			AND Not ClosingResult.AmountIncludesVAT = ClosingResult.PrevAmountIncludesVAT Then
			
			DriveClient.RecalculateTabularSectionAmountByFlagAmountIncludesVAT(ThisForm, "Inventory");
			DriveClient.RecalculateTabularSectionAmountByFlagAmountIncludesVAT(ThisForm, "Works");
			
		EndIf;
		
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
			
		PricesAndCurrency = GenerateLabelPricesAndCurrency(LabelStructure);
		
	EndIf;
	
EndProcedure

#EndRegion

#EndRegion
