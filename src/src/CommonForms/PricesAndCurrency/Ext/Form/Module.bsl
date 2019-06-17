
#Region GeneralPurposeProceduresAndFunctions

&AtServer
// Procedure fills the form parameters.
//
Procedure GetFormValuesOfParameters()
	
	// Price kind.
	If Parameters.Property("PriceKind") Then
		
		// Price kind.
		PriceKind = Parameters.PriceKind;
		PriceKindOnOpen = Parameters.PriceKind;
		PriceKindIsAttribute = True;
		
	Else
		
		// Enabled of the price kind.
		Items.PriceKind.Visible = False;
		PriceKindIsAttribute = False;
		
		Items.DiscountKind.Visible = False;
		DiscountKindIsAttribute = False;
		
	EndIf;
	
	If Parameters.Property("Company") Then
		
		DocDate = Undefined;
		Parameters.Property("DocumentDate", DocDate);
		Company = Parameters.Company;
				
	EndIf;
	
	If Parameters.Property("DocumentCurrencyEnabled") Then
		
		Items.Currency.Enabled = Parameters.DocumentCurrencyEnabled;
		Items.RecalculatePrices.Visible = Parameters.DocumentCurrencyEnabled;
		
	EndIf;
	
	UseCounterpartiesPricesTracking = GetFunctionalOption("UseCounterpartiesPricesTracking");
	
	// Counterparty price kind.
	If Parameters.Property("SupplierPriceTypes") And UseCounterpartiesPricesTracking Then
		
		// Price kind.
		SupplierPriceTypes = Parameters.SupplierPriceTypes;
		PriceKindCounterpartyOnOpen = Parameters.SupplierPriceTypes;
		Counterparty = Parameters.Counterparty;
		PriceKindCounterpartyIsAttribute = True;
		
		ValueArray = New Array;
		ValueArray.Add(Counterparty);
		ValueArray = New FixedArray(ValueArray);
		NewParameter = New ChoiceParameter("Filter.Owner", ValueArray);
		NewArray = New Array();
		NewArray.Add(NewParameter);
		NewParameters = New FixedArray(NewArray);
		Items.SupplierPriceTypes.ChoiceParameters = NewParameters;
		
	Else
		
		// Enabled of the counterparty price kind.
		Items.SupplierPriceTypes.Visible = False;
		PriceKindCounterpartyIsAttribute = False;
		
	EndIf;
	
	// RegisterVendorPrices.
	If Parameters.Property("RegisterVendorPrices") And UseCounterpartiesPricesTracking Then
		
		RegisterVendorPrices = Parameters.RegisterVendorPrices;
		RegisterVendorPricesOnOpen = Parameters.RegisterVendorPrices;
		RegisterVendorPricesIsAttribute = True;
		
	Else
		
		// Enabled.
		Items.RegisterVendorPrices.Visible = False;
		RegisterVendorPricesIsAttribute = False;
		
	EndIf;
	
	// Flag - refill prices.
	If Not (PriceKindIsAttribute OR PriceKindCounterpartyIsAttribute) Then
		
		Items.RefillPrices.Visible = False;
		
	EndIf; 
	
	// Discounts.
	If Parameters.Property("DiscountKind") Then
		
		DiscountKind = Parameters.DiscountKind;
		DiscountKindOnOpen = Parameters.DiscountKind;
		DiscountKindIsAttribute = True;
		
	Else
		
		Items.DiscountKind.Visible = False;
		DiscountKindIsAttribute = False;
		
	EndIf;
	
	// Discount cards.
	If Parameters.Property("DiscountCard") Then
		
		DiscountCard = Parameters.DiscountCard;
		DiscountCardOnOpen = Parameters.DiscountCard;
		DiscountCardHasAttribute = True;
		If Parameters.Property("Counterparty") Then
			Counterparty = Parameters.Counterparty;
		EndIf;
		Items.DiscountCard.Visible = True;
		DiscountCardHasAttribute = True;
		
	Else
		
		Items.DiscountCard.Visible = False;
		DiscountCardHasAttribute = False;
		
	EndIf;
	
	// Document currency.
	If Parameters.Property("DocumentCurrency") Then
		
		DocumentCurrency = Parameters.DocumentCurrency;
		DocumentCurrencyOnOpen = Parameters.DocumentCurrency;
		DocumentCurrencyIsAttribute = True;
		
	Else
		
		Items.DocumentCurrency.Visible = False;
		Items.ExchangeRate.Visible = False;
		Items.Multiplicity.Visible = False;
		Items.RecalculatePrices.Visible = False;
		DocumentCurrencyIsAttribute = False;
		
	EndIf;
	
	// VAT taxation.
	If Parameters.Property("VATTaxation") Then
		
		VATTaxation				= Parameters.VATTaxation;
		VATTaxationOnOpen		= Parameters.VATTaxation;
		VATTaxationIsAttribute	= True;
		
		ReverseChargeNotApplicable = Parameters.Property("ReverseChargeNotApplicable") And Parameters.ReverseChargeNotApplicable;
		
		AccountingPolicy = InformationRegisters.AccountingPolicy.GetAccountingPolicy(DocDate, Company);
		
		Items.VATTaxation.ListChoiceMode = True;
		VATTaxationChoiceList = Items.VATTaxation.ChoiceList;
		VATTaxationChoiceList.Clear();
		
		For Each VATTaxationType In Enums.VATTaxationTypes Do
			
			If WorkWithVAT.VATTaxationTypeIsValid(VATTaxationType, AccountingPolicy.RegisteredForVAT, ReverseChargeNotApplicable) Then
				
				VATTaxationChoiceList.Add(VATTaxationType);
				
			EndIf;
			
		EndDo;
		
	Else
		
		Items.VATTaxation.Visible	= False;
		VATTaxationIsAttribute		= False;
		
	EndIf;
	
	// Amount includes VAT.
	If Parameters.Property("AmountIncludesVAT") Then
		
		AmountIncludesVAT = Parameters.AmountIncludesVAT;
		AmountIncludesVATOnOpen = Parameters.AmountIncludesVAT;
		AmountIncludesVATIsAttribute = True;
		
	Else
		
		AmountIncludesVATIsAttribute = False;
		
	EndIf;	
	
	// Include VAT in price.
	If Parameters.Property("IncludeVATInPrice") Then
		
		IncludeVATInPrice = Parameters.IncludeVATInPrice;
		IncludeVATInPriceOnOpen = Parameters.IncludeVATInPrice;
		IncludeVATInPriceIsAttribute = True;
		
	Else
		
		IncludeVATInPriceIsAttribute = False;
		
	EndIf;
	
	VATInclusionAttributesVisibility();
	
	// Accounts currency.
	If Parameters.Property("Contract") Then
		
		SettlementsCurrency	  = Parameters.Contract.SettlementsCurrency;
		CalculationsInCur		  = Parameters.Contract.SettlementsInStandardUnits;
		PaymentsRate 	  = Parameters.ExchangeRate;
		SettlementsMultiplicity = Parameters.Multiplicity;
		
		SettlementsCurrencyRateOnOpen 	 = Parameters.ExchangeRate;
		SettlementsMultiplicityOnOpen = Parameters.Multiplicity;
		
		ContractIsAttribute = True;
		
		If Parameters.Property("ThisIsInvoice") Then
			
			Items.SettlementsCurrency.Visible = False;
			Items.PaymentsRate.Visible = False;
			Items.SettlementsMultiplicity.Visible = False;
			
		EndIf;
		
	Else
		
		Items.SettlementsCurrency.Visible = False;
		Items.PaymentsRate.Visible = False;
		Items.SettlementsMultiplicity.Visible = False;
		
		ContractIsAttribute = False;
		
	EndIf;
	
	RefillPrices = Parameters.RefillPrices;
	RecalculatePrices   = Parameters.RecalculatePrices;
		
	If ValueIsFilled(DocumentCurrency) Then
		ArrayCourseRepetition = ExchangeRates.FindRows(New Structure("Currency", DocumentCurrency));
		If DocumentCurrency = SettlementsCurrency
		   AND PaymentsRate <> 0
		   AND SettlementsMultiplicity <> 0 Then
			ExchangeRate = PaymentsRate;
			Multiplicity = SettlementsMultiplicity;
		Else
			If ValueIsFilled(ArrayCourseRepetition) Then
				ExchangeRate = ArrayCourseRepetition[0].ExchangeRate;
				Multiplicity = ArrayCourseRepetition[0].Multiplicity;
			Else
				ExchangeRate = 0;
				Multiplicity = 0;
			EndIf;
		EndIf;
	EndIf;
	
EndProcedure

&AtServer
// Procedure fills the exchange rates table
//
Procedure FillExchangeRatesTable()
	
	Query = New Query;
	Query.SetParameter("DocumentDate", Parameters.DocumentDate);
	Query.Text = 
	"SELECT
	|	ExchangeRatesSliceLast.Currency,
	|	ExchangeRatesSliceLast.ExchangeRate,
	|	ExchangeRatesSliceLast.Multiplicity
	|FROM
	|	InformationRegister.ExchangeRates.SliceLast(&DocumentDate, ) AS ExchangeRatesSliceLast";
	
	QueryResultTable = Query.Execute().Unload();
	ExchangeRates.Load(QueryResultTable);
	
EndProcedure

&AtClient
// Procedure checks the correctness of the form attributes filling.
//
Procedure CheckFillOfFormAttributes(Cancel, OnlyPriceKindIsNotFilled = False)
    	
	// Attributes filling check.
	
	// DiscountCards
	OnlyPriceKindIsNotFilled = True;
	// End DiscountCards
	
	// Kind of counterparty prices.
	If (RefillPrices OR RegisterVendorPrices) AND PriceKindCounterpartyIsAttribute Then
		If Not ValueIsFilled(SupplierPriceTypes) Then
			CommonUseClientServer.MessageToUser(
				NStr("en = 'Select the supplier price type to renew the purchase prices.'"),,
				"SupplierPriceTypes",,
				Cancel);
				
			OnlyPriceKindIsNotFilled = False; // DiscountCards
    	EndIf;
	EndIf;
	
	// Document currency.
	If DocumentCurrencyIsAttribute Then
		If Not ValueIsFilled(DocumentCurrency) Then
			CommonUseClientServer.MessageToUser(
				NStr("en = 'Select the transaction currency.'"),,
				"DocumentCurrency",,
				Cancel);
				
			OnlyPriceKindIsNotFilled = False; // DiscountCards
   		EndIf;
	EndIf;
	
	// VAT taxation.
	If VATTaxationIsAttribute Then
		If Not ValueIsFilled(VATTaxation) Then
			CommonUseClientServer.MessageToUser(
				NStr("en = 'Select a tax category.'"),,
				"VATTaxation",, 
				Cancel);
				
			OnlyPriceKindIsNotFilled = False; // DiscountCards
   		EndIf;
	EndIf;
	
	// Calculations.
	If ContractIsAttribute Then
		If Not ValueIsFilled(PaymentsRate) Then
			CommonUseClientServer.MessageToUser(
				NStr("en = 'Specify the exchange rate.'"),,
				"PaymentsRate",, 
				Cancel);
				
			OnlyPriceKindIsNotFilled = False; // DiscountCards
		EndIf;
		
		If Not ValueIsFilled(SettlementsMultiplicity) Then
			CommonUseClientServer.MessageToUser(
				NStr("en = 'Specify the multiplier.'"),,
				"SettlementsMultiplicity",,
				Cancel);
				
			OnlyPriceKindIsNotFilled = False; // DiscountCards
		EndIf;
	EndIf;
	
	// Prices kind.
	If RefillPrices AND PriceKindIsAttribute Then
		If Not ValueIsFilled(PriceKind) Then
			
			If DiscountKind.IsEmpty() AND Not DiscountCard.IsEmpty() AND OnlyPriceKindIsNotFilled Then // DiscountCards
				// You can recalculate the discounts on the discount card in the document.
			Else
				CommonUseClientServer.MessageToUser(
					NStr("en = 'Select a price type.'"),,
					"PriceKind");
					
				OnlyPriceKindIsNotFilled = False;
			EndIf;
			
			Cancel = True;
    	EndIf;
	EndIf;
	
EndProcedure

&AtClient
// Procedure checks if the form was modified.
//
Procedure CheckIfFormWasModified()

	WereMadeChanges = False;
	
	ChangesPriceKind 				= ?(PriceKindIsAttribute, PriceKindOnOpen <> PriceKind, False);
	ChangesSupplierPriceTypes 		= ?(PriceKindCounterpartyIsAttribute, PriceKindCounterpartyOnOpen <> SupplierPriceTypes, False);
	ChangesToRegisterVendorPrices = ?(RegisterVendorPricesIsAttribute, RegisterVendorPricesOnOpen <> RegisterVendorPrices, False);
	ChangesDiscountKind 				= ?(DiscountKindIsAttribute, DiscountKindOnOpen <> DiscountKind, False);
	ChangesDocumentCurrency 		= ?(DocumentCurrencyIsAttribute, DocumentCurrencyOnOpen <> DocumentCurrency, False);
	ChangesVATTaxation 	= ?(VATTaxationIsAttribute, VATTaxationOnOpen <> VATTaxation, False);
	ChangesAmountIncludesVAT 		= ?(AmountIncludesVATIsAttribute, AmountIncludesVATOnOpen <> AmountIncludesVAT, False);
	ChangesIncludeVATInPrice 	= ?(IncludeVATInPriceIsAttribute, IncludeVATInPriceOnOpen <> IncludeVATInPrice, False);
    ChangesPaymentsRate 			= ?(ContractIsAttribute, SettlementsCurrencyRateOnOpen <> PaymentsRate, False);
    ChangesSettlementsRates 		= ?(ContractIsAttribute, SettlementsMultiplicityOnOpen <> SettlementsMultiplicity, False);
    ChangesDiscountCard		= ?(DiscountCardHasAttribute, DiscountCardOnOpen <> DiscountCard, False); // DiscountCards
	
	If RefillPrices
	 OR RecalculatePrices
	 OR ChangesDocumentCurrency
	 OR ChangesVATTaxation
     OR ChangesAmountIncludesVAT
	 OR ChangesIncludeVATInPrice
	 OR ChangesPaymentsRate
	 OR ChangesSettlementsRates
	 OR ChangesPriceKind
	 OR ChangesSupplierPriceTypes
	 OR ChangesToRegisterVendorPrices
	 OR ChangesDiscountCard // DiscountCards
	 OR ChangesDiscountKind Then	

		WereMadeChanges = True;

	EndIf;
	
EndProcedure

&AtClient
// Fills the exchange rate and exchange rate multiplier of the document currency.
//
Procedure FillRateRepetitionOfDocumentCurrency()
	
	If ValueIsFilled(DocumentCurrency) Then
		ArrayCourseRepetition = ExchangeRates.FindRows(New Structure("Currency", DocumentCurrency));
		If DocumentCurrency = SettlementsCurrency
		   AND PaymentsRate <> 0
		   AND SettlementsMultiplicity <> 0 Then
			ExchangeRate = PaymentsRate;
			Multiplicity = SettlementsMultiplicity;
		Else
			If ValueIsFilled(ArrayCourseRepetition) Then
				ExchangeRate = ArrayCourseRepetition[0].ExchangeRate;
				Multiplicity = ArrayCourseRepetition[0].Multiplicity;
			Else
				ExchangeRate = 0;
				Multiplicity = 0;
			EndIf;
		EndIf;
	EndIf;
	
EndProcedure

&AtServer
Procedure VATInclusionAttributesVisibility()
	
	TaxationVisibilityComponent = VATTaxationIsAttribute And VATTaxation = Enums.VATTaxationTypes.SubjectToVAT;
	
	Items.AmountIncludesVAT.Visible = AmountIncludesVATIsAttribute And TaxationVisibilityComponent;
	Items.IncludeVATInPrice.Visible = IncludeVATInPriceIsAttribute And TaxationVisibilityComponent;
	
EndProcedure

#Region DiscountCards

// Function returns the discount card holder.
//
&AtServerNoContext
Function GetCardHolder(DiscountCard)

	Return DiscountCard.CardOwner;

EndFunction

#EndRegion

#EndRegion

#Region FormEventHandlers

&AtServer
// Procedure - event handler OnCreateAtServer of the form.
// The procedure implements
// - initializing the form parameters.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	PresentationCurrency = Constants.FunctionalCurrency.Get();
	FillExchangeRatesTable();
	GetFormValuesOfParameters();
	
	If ContractIsAttribute Then	
		NewArray = New Array();
		If CalculationsInCur
		   AND PresentationCurrency <> SettlementsCurrency Then
			NewArray.Add(PresentationCurrency);
		EndIf;
		NewArray.Add(SettlementsCurrency);
		NewParameter = New ChoiceParameter("Filter.Ref", New FixedArray(NewArray));
		NewArray2 = New Array();
		NewArray2.Add(NewParameter);
		NewParameters = New FixedArray(NewArray2);
		Items.Currency.ChoiceParameters = NewParameters;
	EndIf;
	
	Parameters.Property("WarningText", WarningText);
	If IsBlankString(WarningText) Then
		
		CommonUseClientServer.SetFormItemProperty(Items, "WarningGroup", "Visible", False);
		
	EndIf;
	Items.Warning.Title = WarningText;
	
	// DiscountCards
	Parameters.Property("DocumentDate", DocumentDate);
	ConfigureLabelOnDiscountCard();
	
EndProcedure

#EndRegion

#Region ActionsOfTheFormCommandPanels

&AtClient
// Procedure - event handler of clicking the OK button.
//
Procedure CommandOK(Command)
	
	Cancel = False;
	OnlyPriceKindIsNotFilledAndCardIsFilled = False; // DiscountCards

	CheckFillOfFormAttributes(Cancel, OnlyPriceKindIsNotFilledAndCardIsFilled);
	CheckIfFormWasModified();
    
	If Not Cancel OR OnlyPriceKindIsNotFilledAndCardIsFilled Then

		StructureOfFormAttributes = New Structure;

        StructureOfFormAttributes.Insert("WereMadeChanges", 			WereMadeChanges);

        StructureOfFormAttributes.Insert("PriceKind", 						PriceKind);
		StructureOfFormAttributes.Insert("SupplierPriceTypes", 				SupplierPriceTypes);
		StructureOfFormAttributes.Insert("RegisterVendorPrices", 	RegisterVendorPrices);
		StructureOfFormAttributes.Insert("DiscountKind",  					DiscountKind);

		StructureOfFormAttributes.Insert("DocumentCurrency", 				DocumentCurrency);
		StructureOfFormAttributes.Insert("VATTaxation",				VATTaxation);
		StructureOfFormAttributes.Insert("AmountIncludesVAT", 				AmountIncludesVAT);
		StructureOfFormAttributes.Insert("IncludeVATInPrice", 			IncludeVATInPrice);

		StructureOfFormAttributes.Insert("SettlementsCurrency", 				SettlementsCurrency);
		StructureOfFormAttributes.Insert("ExchangeRate", 							ExchangeRate);
		StructureOfFormAttributes.Insert("PaymentsRate", 					PaymentsRate);
		StructureOfFormAttributes.Insert("Multiplicity", 						Multiplicity);
        StructureOfFormAttributes.Insert("SettlementsMultiplicity", 				SettlementsMultiplicity);
                         
		StructureOfFormAttributes.Insert("PrevCurrencyOfDocument", 			DocumentCurrencyOnOpen);
		StructureOfFormAttributes.Insert("PrevVATTaxation", 		VATTaxationOnOpen);
		StructureOfFormAttributes.Insert("PrevAmountIncludesVAT", 			AmountIncludesVATOnOpen);

        StructureOfFormAttributes.Insert("RefillPrices", 				RefillPrices AND Not Cancel);
        StructureOfFormAttributes.Insert("RecalculatePrices", 				RecalculatePrices);

		StructureOfFormAttributes.Insert("FormName", 						"CommonForm.CurrencyForm");

		// DiscountCards
		StructureOfFormAttributes.Insert("RefillDiscounts",			RefillPrices AND OnlyPriceKindIsNotFilledAndCardIsFilled);
		StructureOfFormAttributes.Insert("DiscountCard",  				DiscountCard);
		StructureOfFormAttributes.Insert("DiscountPercentByDiscountCard",	DiscountPercentByDiscountCard);
		StructureOfFormAttributes.Insert("Counterparty",						GetCardHolder(DiscountCard));
		// End DiscountCards
		
		Close(StructureOfFormAttributes);

	EndIf;
	
EndProcedure

#EndRegion

#Region EventHandlersOfFormAttributes

&AtClient
// Procedure - event handler OnChange of the PriceKind input field.
//
Procedure PriceKindOnChange(Item)
	
	If ValueIsFilled(PriceKind) Then
                        
        If PriceKindOnOpen <> PriceKind Then
			
			RefillPrices = True;

		EndIf;
        
	EndIf;
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of the SupplierPriceTypes input field.
//
Procedure SupplierPriceTypesOnChange(Item)
	
	If ValueIsFilled(SupplierPriceTypes) Then
                        
        If PriceKindCounterpartyOnOpen <> SupplierPriceTypes Then
			
			RefillPrices = True;

		EndIf;
        
	EndIf;
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of the DiscountKind input field.
//
Procedure DiscountKindOnChange(Item)
	
	If DiscountKindOnOpen <> DiscountKind Then
		RefillPrices = True;
	EndIf;
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of the Currency input field.
//
Procedure CurrencyOnChange(Item)
	
	FillRateRepetitionOfDocumentCurrency();

	If ValueIsFilled(DocumentCurrency)
		
	   AND DocumentCurrencyOnOpen <> DocumentCurrency Then
  		RecalculatePrices = True;
		
  	EndIf;

EndProcedure

&AtClient
// Procedure - event handler OnChange of the SettlementsCurrency input field.
//
Procedure SettlementsCurrencyOnChange(Item)
	
	FillRateRepetitionOfDocumentCurrency();

EndProcedure

&AtClient
// Procedure - event  handler OnChange of the PaymentsRate input field.
//
Procedure SettlementsRateOnChange(Item)
	
	FillRateRepetitionOfDocumentCurrency();

EndProcedure

&AtClient
// Procedure - event handler OnChange of the SettlementsMultiplicity input field.
//
Procedure SettlementsMultiplicityOnChange(Item)
	
	FillRateRepetitionOfDocumentCurrency();

EndProcedure

&AtClient
// Procedure - event handler OnChange of the RefillPrices input field.
//
Procedure RefillPricesOnChange(Item)
	
	If PriceKindIsAttribute Then
		
		If RefillPrices Then
			If DiscountKind.IsEmpty() AND Not DiscountCard.IsEmpty() Then // DiscountCards
				Items.PriceKind.AutoMarkIncomplete = False;
			Else
				Items.PriceKind.AutoMarkIncomplete = True;
			EndIf;
		Else	
			Items.PriceKind.AutoMarkIncomplete = False;
			ClearMarkIncomplete();
		EndIf;		
	
	ElsIf PriceKindCounterpartyIsAttribute Then
		
		If RefillPrices OR RegisterVendorPrices Then
			Items.SupplierPriceTypes.AutoMarkIncomplete = True;
		Else	
			Items.SupplierPriceTypes.AutoMarkIncomplete = False;
			ClearMarkIncomplete();
		EndIf;		
	
	EndIf;
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of the RegisterVendorPrices input field.
//
Procedure RegisterVendorPricesOnChange(Item)
	
	If RegisterVendorPrices OR RefillPrices Then
		Items.SupplierPriceTypes.AutoMarkIncomplete = True;
	Else	
		Items.SupplierPriceTypes.AutoMarkIncomplete = False;
		ClearMarkIncomplete();
	EndIf;
	
EndProcedure

&AtClient
Procedure VATTaxationOnChange(Item)
	VATInclusionAttributesVisibility();
EndProcedure

#Region DiscountCards

// Procedure - event handler of the StartChoice item of the DiscountCard form.
//
&AtClient
Procedure DiscountCardStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	NotifyDescription = New NotifyDescription("OpenDiscountCardSelectionFormEnd", ThisObject); //, New Structure("Filter", FilterStructure));
	OpenForm("Catalog.DiscountCards.ChoiceForm", New Structure("Counterparty", Counterparty), DiscountCard, UUID, , , NotifyDescription, FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

// Procedure is called after selection of the discount card from the form catalog selection DiscountCards.
//
&AtClient
Procedure OpenDiscountCardSelectionFormEnd(ClosingResult, AdditionalParameters) Export

	If ValueIsFilled(ClosingResult) Then 
		DiscountCard = ClosingResult;
	
		If DiscountCardOnOpen <> DiscountCard Then
			
			RefillPrices = True;
			
		EndIf;
	EndIf;

	// The % of the progressive discount could have been changed, so refresh the label, even if the discount card is not changed.
	ConfigureLabelOnDiscountCard();
	
EndProcedure

// Procedure - event handler of the OnChange item of the DiscountCard form.
//
&AtClient
Procedure DiscountCardOnChange(Item)
	
	If DiscountCardOnOpen <> DiscountCard Then
		
		RefillPrices = True;
		
	EndIf;
	
	// The % of the progressive discount could have been changed, so refresh the label, even if the discount card is not changed.
	ConfigureLabelOnDiscountCard();
	
	RefillPricesOnChange(Items.RefillPrices);
	
EndProcedure

// Procedure fills the discount card tooltip with the information about the discount on the discount card.
//
&AtServer
Procedure ConfigureLabelOnDiscountCard()
	
	If Not DiscountCard.IsEmpty() Then
		If Not Counterparty.IsEmpty() AND DiscountCard.Owner.ThisIsMembershipCard AND DiscountCard.CardOwner <> Counterparty Then
			
			DiscountCard = Catalogs.DiscountCards.EmptyRef();
			
			Message = New UserMessage;
			Message.Text = "Discount card owner does not match with a counterparty in the document.";
			Message.Field = "DiscountCard";
			Message.Message();
			
		EndIf;
	EndIf;
	
	If DiscountCard.IsEmpty() Then
		DiscountPercentByDiscountCard = 0;
		Items.DiscountCard.ToolTip = "";
	Else
		DiscountPercentByDiscountCard = DriveServer.CalculateDiscountPercentByDiscountCard(DocumentDate, DiscountCard);
		Items.DiscountCard.ToolTip = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Discount by the card is %1%'"), DiscountPercentByDiscountCard);
		
	EndIf;
	
EndProcedure

#EndRegion

#EndRegion
