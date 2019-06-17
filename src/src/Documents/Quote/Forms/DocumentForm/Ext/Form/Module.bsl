#Region Variables

&AtClient
Var UpdateSubordinatedInvoice;

#EndRegion

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	DriveServer.FillDocumentHeader(
		Object,
		,
		Parameters.CopyingValue,
		Parameters.Basis,
		PostingIsAllowed,
		Parameters.FillingValues);
	
	If Not ValueIsFilled(Object.Ref)
		  AND ValueIsFilled(Object.Counterparty)
	   AND Not ValueIsFilled(Parameters.CopyingValue) Then
		
		If Not ValueIsFilled(Object.Contract) Then
			
			Object.Contract = CommonUse.ObjectAttributeValue(Object.Counterparty, "ContractByDefault");
			
		EndIf;
		
		If ValueIsFilled(Object.Contract) Then
			
			ContractData = CommonUse.ObjectAttributeValues(Object.Contract, "SettlementsCurrency, DiscountMarkupKind, PriceKind");
			
			Object.DocumentCurrency 			= ContractData.SettlementsCurrency;
			SettlementsCurrencyRateRepetition	= InformationRegisters.ExchangeRates.GetLast(Object.Date, New Structure("Currency", ContractData.SettlementsCurrency));
			Object.ExchangeRate					= ?(SettlementsCurrencyRateRepetition.ExchangeRate = 0, 1, SettlementsCurrencyRateRepetition.ExchangeRate);
			Object.Multiplicity					= ?(SettlementsCurrencyRateRepetition.Multiplicity = 0, 1, SettlementsCurrencyRateRepetition.Multiplicity);
			Object.DiscountMarkupKind			= ContractData.DiscountMarkupKind;
			Object.PriceKind					= ContractData.PriceKind;
			
		EndIf;
		
	EndIf;
	
	// Initialization of form attributes.
	If Not ValueIsFilled(Object.Ref)
	   AND Not ValueIsFilled(Parameters.CopyingValue) Then
		
		Query = New Query(
		"SELECT
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
		
	EndIf;
	
	ParentCompany = DriveServer.GetCompany(Object.Company);
	
	DocumentDate = Object.Date;
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentDate();
	EndIf;
	
	Counterparty				= Object.Counterparty;
	Contract 					= Object.Contract;
	SettlementsCurrency			= Object.Contract.SettlementsCurrency;
	FunctionalCurrency			= Constants.FunctionalCurrency.Get();
	StructureByCurrency			= InformationRegisters.ExchangeRates.GetLast(Object.Date, New Structure("Currency", FunctionalCurrency));
	RateNationalCurrency 		= StructureByCurrency.ExchangeRate;
	RepetitionNationalCurrency	= StructureByCurrency.Multiplicity;
	
	SetAccountingPolicyValues();
	
	If Not ValueIsFilled(Object.Ref)
		AND Not ValueIsFilled(Parameters.Basis) 
		AND Not ValueIsFilled(Parameters.CopyingValue) Then
		FillVATRateByCompanyVATTaxation();
	ElsIf Object.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then	
		Items.InventoryVATRate.Visible = True;
		Items.InventoryVATAmount.Visible = True;
		Items.InventoryAmountTotal.Visible = True;
		Items.PaymentCalendarPayVATAmount.Visible = True;
		Items.ListPaymentsCalendarSumVatOfPayment.Visible = True;
	Else	
		Items.InventoryVATRate.Visible = False;
		Items.InventoryVATAmount.Visible = False;
		Items.InventoryAmountTotal.Visible = False;
		Items.PaymentCalendarPayVATAmount.Visible = False;
		Items.ListPaymentsCalendarSumVatOfPayment.Visible = False;
	EndIf;
	
	// Generate price and currency label.
	ForeignExchangeAccounting = Constants.ForeignExchangeAccounting.Get();
	
	LabelStructure = New Structure;
	LabelStructure.Insert("PriceKind",						Object.PriceKind);
	LabelStructure.Insert("DiscountKind",					Object.DiscountMarkupKind);
	LabelStructure.Insert("DocumentCurrency",				Object.DocumentCurrency);
	LabelStructure.Insert("SettlementsCurrency",			SettlementsCurrency);
	LabelStructure.Insert("ExchangeRate",					Object.ExchangeRate);
	LabelStructure.Insert("AmountIncludesVAT",				Object.AmountIncludesVAT);
	LabelStructure.Insert("ForeignExchangeAccounting",	ForeignExchangeAccounting);
	LabelStructure.Insert("RateNationalCurrency",			RateNationalCurrency);
	LabelStructure.Insert("VATTaxation",					Object.VATTaxation);
	LabelStructure.Insert("DiscountCard",					Object.DiscountCard);
	LabelStructure.Insert("DiscountPercentByDiscountCard",	Object.DiscountPercentByDiscountCard);
	LabelStructure.Insert("RegisteredForVAT",				RegisteredForVAT);
	
	PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
	
	// Setting contract visible.
	SetContractVisible();
	
	// Price accessibility setup for editing.
	AllowedEditDocumentPrices = DriveAccessManagementReUse.AllowedEditDocumentPrices();
	
	Items.InventoryPrice.ReadOnly 				   = Not AllowedEditDocumentPrices;
	Items.InventoryDiscountPercentMargin.ReadOnly = Not AllowedEditDocumentPrices;
	Items.InventoryAmount.ReadOnly 			   = Not AllowedEditDocumentPrices;
	Items.InventoryVATAmount.ReadOnly 			   = Not AllowedEditDocumentPrices;
	
	// AutomaticDiscounts.
	AutomaticDiscountsOnCreateAtServer();
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.ObjectVersioning
	ObjectVersioning.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.ObjectVersioning
	
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
	
	SwitchTypeListOfPaymentCalendar = ?(Object.PaymentCalendar.Count() > 1, 1, 0);
	
	EditingIsAvailable = Not ReadOnly And AccessRight("Edit", Metadata.Documents.Quote);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	// Peripherals
	EquipmentManagerClientOverridable.StartConnectingEquipmentOnFormOpen(ThisObject, "BarCodeScanner");
	// End Peripherals
	
	SetCurrentPage();
	
	If Object.PaymentCalendar.Count() > 0 Then
		Items.PaymentCalendar.CurrentRow = Object.PaymentCalendar[0].GetID();
	EndIf;
	
	SetEditInListFragmentOption();
	SetEnableGroupPaymentCalendarDetails();
	
	PopulateVariantsList();
	CurrentVariant = Object.PreferredVariant;
	SetVariantsActionsAvailability();
	FillInventoryRelativeLineNumbers();
	SetVariantRowFilter();
	
	RecalculateSubtotal();
	
EndProcedure

&AtClient
Procedure OnClose(Exit)

	// AutomaticDiscounts
	// Display message about discount calculation if you click the "Post and close" or form closes by the cross with change saving.
	If UseAutomaticDiscounts AND DiscountsCalculatedBeforeWrite Then
		ShowUserNotification(NStr("en = 'Update:'"), 
										GetURL(Object.Ref), 
										String(Object.Ref) + ". " + NStr("en = 'The automatic discounts are calculated.'"), 
										PictureLib.Information32);
	EndIf;
	// End AutomaticDiscounts
	
	// Peripherals
	EquipmentManagerClientOverridable.StartDisablingEquipmentOnCloseForm(ThisObject);
	// End Peripherals
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	// Properties subsystem
	If PropertiesManagementClient.ProcessAlerts(ThisObject, EventName, Parameter) Then
		
		UpdateAdditionalAttributesItems();
		Items.InventoryTotalVATAmount.Visible = True;
		
	EndIf;
	
	// Peripherals
	If Source = "Peripherals"
	   AND IsInputAvailable() AND Not DiscountCardRead Then
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
	
	// DiscountCards
	If DiscountCardRead Then
		DiscountCardRead = False;
	EndIf;
	// End DiscountCards
	
	If EventName = "AfterRecordingOfCounterparty" 
		AND ValueIsFilled(Parameter)
		AND Object.Counterparty = Parameter Then
		
		SetContractVisible();
		Items.InventoryTotalVATAmount.Visible = False;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	ClosingDates.ObjectOnReadAtServer(ThisObject, CurrentObject);
	
	// StandardSubsystems.Properties
	PropertiesManagement.OnReadAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.Properties
	
	SetSwitchTypeListOfPaymentCalendar();
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	// StandardSubsystems.PerformanceMeasurement
	PerformanceEstimationClientServer.StartTimeMeasurement("DocumentQuotePosting");
	// StandardSubsystems.PerformanceMeasurement
	
	UpdateSubordinatedInvoice = Modified;
	
	// AutomaticDiscounts
	DiscountsCalculatedBeforeWrite = False;
	// If the document is being posted, we check whether the discounts are calculated.
	If UseAutomaticDiscounts Then
		If Not Object.DiscountsAreCalculated AND DiscountsChanged() Then
			CalculateDiscountsMarkupsClient();
			RecalculatePaymentCalendar();
			RecalculateSubtotal();
			CalculatedDiscounts = True;
			
			CommonUseClientServer.MessageToUser(
				NStr("en = 'The automatic discounts are applied.'"),
				Object.Ref);
			
			DiscountsCalculatedBeforeWrite = True;
		Else
			Object.DiscountsAreCalculated = True;
			RefreshImageAutoDiscountsAfterWrite = True;
		EndIf;
	EndIf;
	// End AutomaticDiscounts
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	If WriteParameters.WriteMode = DocumentWriteMode.Posting Then
		
		MessageText = "";
		CheckContractToDocumentConditionAccordance(MessageText, Object.Contract, Object.Ref, Object.Company, Object.Counterparty, Cancel);
		
		If Not IsBlankString(MessageText) Then
			If Cancel Then
				MessageText = NStr("en = 'Document is not posted.'") + " " + MessageText;
				CommonUseClientServer.MessageToUser(MessageText, , "Contract", "Object");
			Else
				CommonUseClientServer.MessageToUser(MessageText);
			EndIf;
		EndIf;
		
	EndIf;
	
	// "Properties" mechanism handler
	PropertiesManagement.BeforeWriteAtServer(ThisObject, CurrentObject);
	// "Properties" mechanism handler
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	// AutomaticDiscounts
	If RefreshImageAutoDiscountsAfterWrite Then
		Items.InventoryCalculateDiscountsMarkups.Picture = PictureLib.Refresh;
		RefreshImageAutoDiscountsAfterWrite = False;
	EndIf;
	// End AutomaticDiscounts
	
EndProcedure

&AtClient
Procedure AfterWrite()
	
	Notify();
	FillInventoryRelativeLineNumbers();
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	// StandardSubsystems.Properties
	PropertiesManagement.FillCheckProcessing(ThisObject, Cancel, CheckedAttributes);
	// End StandardSubsystems.Properties
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure CounterpartyOnChange(Item)
	
	CounterpartyBeforeChange = Counterparty;
	Counterparty = Object.Counterparty;
	
	If CounterpartyBeforeChange <> Object.Counterparty Then
		
		StructureData = GetDataCounterpartyOnChange(Object.Date, Object.DocumentCurrency, Object.Counterparty, Object.Company);
		
		Object.Contract 		= StructureData.Contract;
		ContractBeforeChange	= Contract;
		Contract 				= Object.Contract;
		
		SettlementsCurrencyBeforeChange = SettlementsCurrency;
		SettlementsCurrency 			= StructureData.SettlementsCurrency;
		
		If ValueIsFilled(Object.Contract) Then 
			Object.ExchangeRate	  = ?(StructureData.SettlementsCurrencyRateRepetition.ExchangeRate = 0, 1, StructureData.SettlementsCurrencyRateRepetition.ExchangeRate);
			Object.Multiplicity = ?(StructureData.SettlementsCurrencyRateRepetition.Multiplicity = 0, 1, StructureData.SettlementsCurrencyRateRepetition.Multiplicity);
		EndIf;
		
		PriceKindChanged = Object.PriceKind <> StructureData.PriceKind 
			AND ValueIsFilled(StructureData.PriceKind);
			
		DiscountKindChanged = Object.DiscountMarkupKind <> StructureData.DiscountMarkupKind 
			AND ValueIsFilled(StructureData.DiscountMarkupKind);
			
		// DiscountCards	
		Object.DiscountCard = PredefinedValue("Catalog.DiscountCards.EmptyRef");
		Object.DiscountPercentByDiscountCard = 0;
		// End DiscountCards
			
		NewContractAndCalculationCurrency = ValueIsFilled(Object.Contract) AND ValueIsFilled(SettlementsCurrency) 
			AND Object.Contract <> ContractBeforeChange AND SettlementsCurrencyBeforeChange <> StructureData.SettlementsCurrency;
			
		OpenFormPricesAndCurrencies = NewContractAndCalculationCurrency AND Object.DocumentCurrency <> StructureData.SettlementsCurrency
			AND Object.Inventory.Count() > 0;
			
		QueryPriceKind = ValueIsFilled(Object.Contract) AND (PriceKindChanged OR DiscountKindChanged);
		If QueryPriceKind Then
			If PriceKindChanged Then
				Object.PriceKind = StructureData.PriceKind;
			EndIf;
			If DiscountKindChanged Then
				Object.DiscountMarkupKind = StructureData.DiscountMarkupKind;
			EndIf;
		EndIf;
		
		If Object.DocumentCurrency <> StructureData.SettlementsCurrency Then
			Object.BankAccount = Undefined;
		EndIf;
		Object.DocumentCurrency = StructureData.SettlementsCurrency;
		
		If OpenFormPricesAndCurrencies Then
			
			WarningText = "";
			If QueryPriceKind Then
				WarningText = NStr("en = 'The price and discount in the contract with counterparty differ from price and discount in the document. 
				                   |Perhaps you have to refill prices.'") + Chars.LF + Chars.LF;
			EndIf;
			
			WarningText = WarningText + NStr("en = 'Settlement currency of the contract with counterparty has changed.
			                                 |It is necessary to check the document currency.'");
			ProcessChangesOnButtonPricesAndCurrencies(SettlementsCurrencyBeforeChange, True, PriceKindChanged, WarningText);
		
		ElsIf QueryPriceKind Then
			
			RecalculationRequired = (Object.Inventory.Count() > 0);
			
			LabelStructure = New Structure;
			LabelStructure.Insert("PriceKind",						Object.PriceKind);
			LabelStructure.Insert("DiscountKind",					Object.DiscountMarkupKind);
			LabelStructure.Insert("DocumentCurrency",				Object.DocumentCurrency);
			LabelStructure.Insert("SettlementsCurrency",			SettlementsCurrency);
			LabelStructure.Insert("ExchangeRate",					Object.ExchangeRate);
			LabelStructure.Insert("AmountIncludesVAT",				Object.AmountIncludesVAT);
			LabelStructure.Insert("ForeignExchangeAccounting",		ForeignExchangeAccounting);
			LabelStructure.Insert("RateNationalCurrency",			RateNationalCurrency);
			LabelStructure.Insert("VATTaxation",					Object.VATTaxation);
			LabelStructure.Insert("DiscountCard",					Object.DiscountCard);
			LabelStructure.Insert("DiscountPercentByDiscountCard",	Object.DiscountPercentByDiscountCard);
			LabelStructure.Insert("RegisteredForVAT",				RegisteredForVAT);
					
			PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
			
			If RecalculationRequired Then
				
				Message = NStr("en = 'The price and discount in the contract with counterparty differ from price and discount in the document. 
				               |Recalculate the document according to the contract?'");
				
				ShowQueryBox(New NotifyDescription("CounterpartyOnChangeEnd", ThisObject, New Structure("SettlementsCurrencyBeforeChange, ContractBeforeChange, StructureData", SettlementsCurrencyBeforeChange, ContractBeforeChange, StructureData)), Message, QuestionDialogMode.YesNo);
				Return;
				
			EndIf;
			
		Else
			
			LabelStructure = New Structure;
			LabelStructure.Insert("PriceKind",						Object.PriceKind);
			LabelStructure.Insert("DiscountKind",					Object.DiscountMarkupKind);
			LabelStructure.Insert("DocumentCurrency",				Object.DocumentCurrency);
			LabelStructure.Insert("SettlementsCurrency",			SettlementsCurrency);
			LabelStructure.Insert("ExchangeRate",					Object.ExchangeRate);
			LabelStructure.Insert("AmountIncludesVAT",				Object.AmountIncludesVAT);
			LabelStructure.Insert("ForeignExchangeAccounting",	ForeignExchangeAccounting);
			LabelStructure.Insert("RateNationalCurrency",			RateNationalCurrency);
			LabelStructure.Insert("VATTaxation",					Object.VATTaxation);
			LabelStructure.Insert("DiscountCard",					Object.DiscountCard);
			LabelStructure.Insert("DiscountPercentByDiscountCard",	Object.DiscountPercentByDiscountCard);
			LabelStructure.Insert("RegisteredForVAT",				RegisteredForVAT);
					
			PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
			
		EndIf;
		
		Object.SalesRep = StructureData.SalesRep;
	Else
		
		Object.Contract = Contract; // Restore the cleared contract automatically.
		
	EndIf;
	
	// AutomaticDiscounts
	ClearCheckboxDiscountsAreCalculatedClient("CounterpartyOnChange");
	
EndProcedure

&AtClient
Procedure ContractOnChange(Item)
	
	ProcessContractChange();
	
EndProcedure

&AtClient
Procedure ContractStartChoice(Item, ChoiceData, StandardProcessing)
	
	FormParameters = GetChoiceFormOfContractParameters(Object.Ref, Object.Company, Object.Counterparty, Object.Contract);
	If FormParameters.ControlContractChoice Then
		
		StandardProcessing = False;
		OpenForm("Catalog.CounterpartyContracts.Form.ChoiceForm", FormParameters, Item);
		
	EndIf;
	
EndProcedure

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
		LabelStructure.Insert("PriceKind",						Object.PriceKind);
		LabelStructure.Insert("DiscountKind",					Object.DiscountMarkupKind);
		LabelStructure.Insert("DocumentCurrency",				Object.DocumentCurrency);
		LabelStructure.Insert("SettlementsCurrency",			SettlementsCurrency);
		LabelStructure.Insert("ExchangeRate",					Object.ExchangeRate);
		LabelStructure.Insert("AmountIncludesVAT",				Object.AmountIncludesVAT);
		LabelStructure.Insert("ForeignExchangeAccounting",		ForeignExchangeAccounting);
		LabelStructure.Insert("RateNationalCurrency",			RateNationalCurrency);
		LabelStructure.Insert("VATTaxation",					Object.VATTaxation);
		LabelStructure.Insert("DiscountCard",					Object.DiscountCard);
		LabelStructure.Insert("DiscountPercentByDiscountCard",	Object.DiscountPercentByDiscountCard);
		LabelStructure.Insert("RegisteredForVAT",				RegisteredForVAT);
		
		PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
		
		// Payment calendar.
		RecalculatePaymentCalendar();
		RecalculateSubtotal();
		
		// DiscountCards
		// IN this procedure call not modal window of question is occurred.
		RecalculateDiscountPercentAtDocumentDateChange();
		// End DiscountCards
	EndIf;
	
	// AutomaticDiscounts
	DocumentDateChangedManually = True;
	ClearCheckboxDiscountsAreCalculatedClient("DateOnChange");

EndProcedure

&AtClient
Procedure CompanyOnChange(Item)
	
	// Company change event data processor.
	Object.Number = "";
	StructureData = GetCompanyDataOnChange();
	ParentCompany = StructureData.ParentCompany;
	If Object.DocumentCurrency = StructureData.BankAccountCashAssetsCurrency Then
		Object.BankAccount = StructureData.BankAccount;
	EndIf;
	
	Object.Contract = GetContractByDefault(Object.Ref, Object.Counterparty, Object.Company);
	ProcessContractChange();
	
	LabelStructure = New Structure;
	LabelStructure.Insert("PriceKind",						Object.PriceKind);
	LabelStructure.Insert("DiscountKind",					Object.DiscountMarkupKind);
	LabelStructure.Insert("DocumentCurrency",				Object.DocumentCurrency);
	LabelStructure.Insert("SettlementsCurrency",			SettlementsCurrency);
	LabelStructure.Insert("ExchangeRate",					Object.ExchangeRate);
	LabelStructure.Insert("AmountIncludesVAT",				Object.AmountIncludesVAT);
	LabelStructure.Insert("ForeignExchangeAccounting",	ForeignExchangeAccounting);
	LabelStructure.Insert("RateNationalCurrency",			RateNationalCurrency);
	LabelStructure.Insert("VATTaxation",					Object.VATTaxation);
	LabelStructure.Insert("DiscountCard",					Object.DiscountCard);
	LabelStructure.Insert("DiscountPercentByDiscountCard",	Object.DiscountPercentByDiscountCard);
	LabelStructure.Insert("RegisteredForVAT",				RegisteredForVAT);
	
	PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
	
	// Payment calendar.
	RecalculatePaymentCalendar();
	RecalculateSubtotal();
	
EndProcedure

&AtClient
Procedure EditPricesAndCurrency(Item, StandardProcessing)
	
	StandardProcessing = False;
	ProcessChangesOnButtonPricesAndCurrencies(Object.DocumentCurrency);
	Modified = True;
	
EndProcedure

&AtClient
Procedure CurrentVariantOnChange(Item)
	
	If CurrentVariant > Object.VariantsCount Then
		AddVariant();
	Else
		SetVariantsActionsAvailability();
		FillInventoryRelativeLineNumbers();
		SetVariantRowFilter();
	EndIf;
	RecalculateSubtotal();
	
EndProcedure

&AtClient
Procedure SchedulePayOnChange(Item)
	
	If Object.SetPaymentTerms Then
		
		FillThePaymentCalendarOnServer();
		SetEnableGroupPaymentCalendarDetails();
		SetEditInListFragmentOption();
		SetCurrentPage();
		
	Else
		
		Notify = New NotifyDescription("ClearPaymentCalendarContinue", ThisObject);
		QueryText = NStr("en = 'The payment terms will be cleared. Do you want to continue?'");
		ShowQueryBox(Notify, QueryText,  QuestionDialogMode.YesNo);
		
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
	
	SetEditInListFragmentOption();

EndProcedure

&AtClient
Procedure CashAssetsTypeOnChange(Item)
	
	SetCurrentPage();
	
EndProcedure

&AtClient
Procedure BankAccountStartChoice(Item, ChoiceData, StandardProcessing)
	
	If Not ValueIsFilled(Object.Contract) Then
		Return;
	EndIf;
	
	FormParameters = GetChoiceFormParametersBankAccount(Object.Contract, Object.Company, FunctionalCurrency);
	If FormParameters.SettlementsInStandardUnits Then
		
		StandardProcessing = False;
		OpenForm("Catalog.BankAccounts.ChoiceForm", FormParameters, Item);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure PaymentCalendarPaymentPercentageOnChange(Item)
	
	CurrentRow = Items.PaymentCalendar.CurrentData;
	PercentOfPaymentTotal = Object.PaymentCalendar.Total("PaymentPercentage");
	
	If PercentOfPaymentTotal > 100 Then
		CurrentRow.PaymentPercentage = CurrentRow.PaymentPercentage - (PercentOfPaymentTotal - 100);
	EndIf;
	
	InventoryTotals = GetTotalAmountsForPaymentCalendar(Object.Inventory, Object.VariantsCount, Object.PreferredVariant);
	
	CurrentRow.PaymentAmount = Round(InventoryTotals.Amount * CurrentRow.PaymentPercentage / 100, 2, 1);
	CurrentRow.PaymentVATAmount = Round(InventoryTotals.VATAmount * CurrentRow.PaymentPercentage / 100, 2, 1);
	
EndProcedure

&AtClient
Procedure PaymentCalendarPaymentSumOnChange(Item)
	
	CurrentRow = Items.PaymentCalendar.CurrentData;
	
	InventoryTotals = GetTotalAmountsForPaymentCalendar(Object.Inventory, Object.VariantsCount, Object.PreferredVariant);
	
	PaymentCalendarTotal = Object.PaymentCalendar.Total("PaymentAmount");
	
	If PaymentCalendarTotal > InventoryTotals.Amount Then
		CurrentRow.PaymentAmount = CurrentRow.PaymentAmount - (PaymentCalendarTotal - InventoryTotals.Amount);
	EndIf;
	
	CurrentRow.PaymentPercentage = ?(InventoryTotals.Amount = 0, 0, Round(CurrentRow.PaymentAmount / InventoryTotals.Amount * 100, 2, 1));
	CurrentRow.PaymentVATAmount = Round(InventoryTotals.VATAmount * CurrentRow.PaymentPercentage / 100, 2, 1);
	
EndProcedure

&AtClient
Procedure PaymentCalendarPayVATAmountOnChange(Item)
	
	CurrentRow = Items.PaymentCalendar.CurrentData;
	
	InventoryTotals = GetTotalAmountsForPaymentCalendar(Object.Inventory, Object.VariantsCount, Object.PreferredVariant);
	
	PaymentCalendarTotal = Object.PaymentCalendar.Total("PaymentVATAmount");
	
	If PaymentCalendarTotal > InventoryTotals.VATAmount Then
		CurrentRow.PaymentVATAmount = CurrentRow.PaymentVATAmount - (PaymentCalendarTotal - InventoryTotals.VATAmount);
	EndIf;
	
EndProcedure

#EndRegion

#Region InventoryFormTableItemsEventHandlers

&AtClient
Procedure InventorySelection(Item, SelectedRow, Field, StandardProcessing)
	
	// AutomaticDiscounts
	If Item.CurrentItem = Items.InventoryAutomaticDiscountPercent
		AND Not ReadOnly Then
		
		StandardProcessing = False;
		OpenInformationAboutDiscountsClient()
		
	EndIf;
	// End AutomaticDiscounts
	
EndProcedure

&AtClient
Procedure InventoryOnActivateRow(Item)
	
	InventoryRowIsSelected = Not Items.Inventory.CurrentRow = Undefined;
	
	Items.InventoryMoveUp.Enabled = InventoryRowIsSelected;
	Items.InventoryMoveDown.Enabled = InventoryRowIsSelected;
	Items.InventorySortAscending.Enabled = InventoryRowIsSelected;
	Items.InventorySortDescending.Enabled = InventoryRowIsSelected;
	Items.InventoryContextMenuMoveUp.Enabled = InventoryRowIsSelected;
	Items.InventoryContextMenuMoveDown.Enabled = InventoryRowIsSelected;
	
EndProcedure

&AtClient
Procedure InventoryOnStartEdit(Item, NewRow, Copy)
	
	If NewRow Then
		
		InventoryRow = Item.CurrentData;
		
		If Copy Then
			InventoryRow.AutomaticDiscountsPercent = 0;
			InventoryRow.AutomaticDiscountAmount = 0;
			CalculateAmountInTabularSectionLine();
		EndIf;
		
		InventoryRow.Variant = CurrentVariant;
		
		FillInventoryRelativeLineNumbers();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure InventoryOnEditEnd(Item, NewRow, CancelEdit)
	
	// Payment calendar.
	RecalculatePaymentCalendar();
	RecalculateSubtotal();

EndProcedure

&AtClient
Procedure InventoryAfterDeleteRow(Item)
	
	// Payment calendar.
	RecalculatePaymentCalendar();
	RecalculateSubtotal();
	
	// AutomaticDiscounts.
	ClearCheckboxDiscountsAreCalculatedClient("DeleteRow");
	
	FillInventoryRelativeLineNumbers();
	
EndProcedure

&AtClient
Procedure InventoryDragEnd(Item, DragParameters, StandardProcessing)
	
	FillInventoryRelativeLineNumbers();
	
EndProcedure

&AtClient
Procedure InventoryProductsOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	StructureData = New Structure();
	
	StructureData.Insert("Company", 			Object.Company);
	StructureData.Insert("ProcessingDate",		Object.Date);
	StructureData.Insert("PriceKind",			Object.PriceKind);
	StructureData.Insert("DocumentCurrency",	Object.DocumentCurrency);
	StructureData.Insert("AmountIncludesVAT",	Object.AmountIncludesVAT);
	StructureData.Insert("Products",			TabularSectionRow.Products);
	StructureData.Insert("Characteristic",		TabularSectionRow.Characteristic);
	StructureData.Insert("Factor",				1);
	StructureData.Insert("VATTaxation",			Object.VATTaxation);
	StructureData.Insert("DiscountMarkupKind",	Object.DiscountMarkupKind);
	
	// DiscountCards
	StructureData.Insert("DiscountCard", Object.DiscountCard);
	StructureData.Insert("DiscountPercentByDiscountCard", Object.DiscountPercentByDiscountCard);
	// End DiscountCards
	
	StructureData = GetDataProductsOnChange(StructureData);
	
	TabularSectionRow.MeasurementUnit = StructureData.MeasurementUnit;
	TabularSectionRow.Quantity = 1;
	TabularSectionRow.Price = StructureData.Price;
	TabularSectionRow.DiscountMarkupPercent = StructureData.DiscountMarkupPercent;
	TabularSectionRow.VATRate = StructureData.VATRate;
	TabularSectionRow.Content = "";
	
	CalculateAmountInTabularSectionLine();
	
EndProcedure

&AtClient
Procedure InventoryCharacteristicOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	StructureData = New Structure();
	
	StructureData.Insert("ProcessingDate",		Object.Date);
	StructureData.Insert("PriceKind",			Object.PriceKind);
	StructureData.Insert("DocumentCurrency",	Object.DocumentCurrency);
	StructureData.Insert("AmountIncludesVAT",	Object.AmountIncludesVAT);
	
	StructureData.Insert("VATRate",			TabularSectionRow.VATRate);
	StructureData.Insert("Products",		TabularSectionRow.Products);
	StructureData.Insert("Characteristic",	TabularSectionRow.Characteristic);
	StructureData.Insert("MeasurementUnit",	TabularSectionRow.MeasurementUnit);
	
	StructureData = GetDataCharacteristicOnChange(StructureData);
	
	TabularSectionRow.Price = StructureData.Price;
	TabularSectionRow.Content = "";
	CalculateAmountInTabularSectionLine();
	
EndProcedure

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

&AtClient
Procedure InventoryQuantityOnChange(Item)
	
	CalculateAmountInTabularSectionLine();
	
	// Payment calendar.
	RecalculatePaymentCalendar();
	RecalculateSubtotal();
	
EndProcedure

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
	
	CalculateAmountInTabularSectionLine();
	
EndProcedure

&AtClient
Procedure InventoryPriceOnChange(Item)
	
	CalculateAmountInTabularSectionLine();
	
	// Payment calendar.
	RecalculatePaymentCalendar();
	RecalculateSubtotal();
	
EndProcedure

&AtClient
Procedure InventoryDiscountMarkupPercentOnChange(Item)
	
	CalculateAmountInTabularSectionLine();
	
	// Payment calendar.
	RecalculatePaymentCalendar();
	RecalculateSubtotal();
	
EndProcedure

&AtClient
Procedure InventoryAmountOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
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
	
	// Payment calendar.
	RecalculatePaymentCalendar();
	RecalculateSubtotal();
	
	// AutomaticDiscounts.
	ClearCheckboxDiscountsAreCalculatedClient("CalculateAmountInTabularSectionLine", ThisObject.CurrentItem.CurrentItem.Name);
	
	TabularSectionRow.AutomaticDiscountsPercent = 0;
	TabularSectionRow.AutomaticDiscountAmount = 0;
	TabularSectionRow.TotalDiscountAmountIsMoreThanAmount = False;
	// End AutomaticDiscounts
	
EndProcedure

&AtClient
Procedure InventoryVATRateOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	CalculateVATSUM(TabularSectionRow);
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
	// Payment calendar.
	RecalculatePaymentCalendar();
	RecalculateSubtotal();
	
EndProcedure

&AtClient
Procedure InventoryVATAmountOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
	// Payment calendar.
	RecalculatePaymentCalendar();
	RecalculateSubtotal();
	
EndProcedure

#EndRegion

#Region PaymentCalendarFormTableItemsEventHandlers

&AtClient
Procedure PaymentCalendarBeforeDelete(Item, Cancel)
	
	If Object.PaymentCalendar.Count() = 1 Then
		Cancel = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure PaymentCalendarOnStartEdit(Item, NewRow, Copy)
	
	If NewRow Then
		
		CurrentRow = Items.PaymentCalendar.CurrentData;
		
		InventoryTotals = GetTotalAmountsForPaymentCalendar(Object.Inventory, Object.VariantsCount, Object.PreferredVariant);
		
		CurrentRow.PaymentAmount = Round(InventoryTotals.Amount * CurrentRow.PaymentPercentage / 100, 2, 1);
		CurrentRow.PaymentVATAmount = Round(InventoryTotals.VATAmount * CurrentRow.PaymentPercentage / 100, 2, 1);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ListPaymentCalendarPaymentPercentageOnChange(Item)
	
	CurrentRow = Items.PaymentCalendar.CurrentData;
	
	InventoryTotals = GetTotalAmountsForPaymentCalendar(Object.Inventory, Object.VariantsCount, Object.PreferredVariant);
	
	CurrentRow.PaymentAmount = Round(InventoryTotals.Amount * CurrentRow.PaymentPercentage / 100, 2, 1);
	CurrentRow.PaymentVATAmount = Round(InventoryTotals.VATAmount * CurrentRow.PaymentPercentage / 100, 2, 1);
	
EndProcedure

&AtClient
Procedure ListPaymentCalendarPaymentSumOnChange(Item)
	
	CurrentRow = Items.PaymentCalendar.CurrentData;
	
	InventoryTotals = GetTotalAmountsForPaymentCalendar(Object.Inventory, Object.VariantsCount, Object.PreferredVariant);
	
	If InventoryTotals.Amount = 0 Then
		CurrentRow.PaymentPercentage	= 0;
		CurrentRow.PaymentVATAmount		= 0;
	Else
		CurrentRow.PaymentPercentage	= Round(CurrentRow.PaymentAmount / InventoryTotals.Amount * 100, 2, 1);
		CurrentRow.PaymentVATAmount		= Round(InventoryTotals.VATAmount * CurrentRow.PaymentAmount / InventoryTotals.Amount, 2, 1);
	EndIf;
	
EndProcedure

&AtClient
Procedure ListPaymentCalendarPayVATAmountOnChange(Item)
	
	CurrentRow = Items.PaymentCalendar.CurrentData;
	
	PaymentCalendarTotal = Object.PaymentCalendar.Total("PaymentVATAmount");
	
	InventoryTotals = GetTotalAmountsForPaymentCalendar(Object.Inventory, Object.VariantsCount, Object.PreferredVariant);
	
	If PaymentCalendarTotal > InventoryTotals.VATAmount Then
		CurrentRow.PaymentVATAmount = CurrentRow.PaymentVATAmount - (PaymentCalendarTotal - InventoryTotals.VATAmount);
	EndIf;

EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure CalculateDiscountsMarkups(Command)
	
	If Object.Inventory.Count() = 0 Then
		If Object.DiscountsMarkups.Count() > 0 Then
			Object.DiscountsMarkups.Clear();
		EndIf;
		Return;
	EndIf;
	
	CalculateDiscountsMarkupsClient();
	
EndProcedure

&AtClient
Procedure GetWeight(Command)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	If TabularSectionRow = Undefined Then
		
		ShowMessageBox(Undefined, NStr("en = 'Select a line to get the weight for.'"));
		
	ElsIf EquipmentManagerClient.RefreshClientWorkplace() Then // Checks if the operator's workplace is specified
		
		NotifyDescription = New NotifyDescription("GetWeightEnd", ThisObject, TabularSectionRow);
		EquipmentManagerClient.StartWeightReceivingFromElectronicScales(NotifyDescription, UUID);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ImportDataFromDCT(Command)
	
	NotificationsAtImportFromDCT = New NotifyDescription("ImportFromDCTEnd", ThisObject);
	EquipmentManagerClient.StartImportDataFromDCT(NotificationsAtImportFromDCT, UUID);
	
EndProcedure

&AtClient
Procedure OpenInformationAboutDiscounts(Command)
	
	CurrentData = Items.Inventory.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	OpenInformationAboutDiscountsClient()
	
EndProcedure

&AtClient
Procedure Pick(Command)
	
	TabularSectionName	= "Inventory";
	DocumentPresentaion	= NStr("en = 'quotation'");
	SelectionParameters	= DriveClient.GetSelectionParameters(ThisObject, TabularSectionName, DocumentPresentaion, False, True, False);
	SelectionParameters.Insert("Company", Counterparty);
	
	InvRows = Object.Inventory.FindRows(New Structure("Variant", CurrentVariant));
	SelectionParameters.Insert("TotalItems", InvRows.Count());
	SelectionParameters.Insert("TotalAmount", DocumentTotal);
	
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
Procedure ReadDiscountCardClick(Item)
	
	ParametersStructure = New Structure("Counterparty", Object.Counterparty);
	NotifyDescription = New NotifyDescription("ReadDiscountCardClickEnd", ThisObject);
	OpenForm("Catalog.DiscountCards.Form.ReadingDiscountCard", ParametersStructure, ThisObject, , , , NotifyDescription, FormWindowOpeningMode.LockOwnerWindow);	
	
EndProcedure

&AtClient
Procedure SearchByBarcode(Command)
	
	CurBarcode = "";
	ShowInputValue(New NotifyDescription("SearchByBarcodeEnd", ThisObject, New Structure("CurBarcode", CurBarcode)), CurBarcode, NStr("en = 'Enter barcode'"));
	
EndProcedure

&AtClient
Procedure VariantAdd(Command)
	
	AddVariant();
	RecalculateSubtotal();
	
EndProcedure

&AtClient
Procedure VariantSetAsPreferred(Command)
	
	Object.PreferredVariant = CurrentVariant;
	PopulateVariantsList();
	SetVariantsActionsAvailability();
	RecalculatePaymentCalendar();
	
EndProcedure

&AtClient
Procedure VariantCopy(Command)
	
	CopyVariant();
	
EndProcedure

&AtClient
Procedure VariantDelete(Command)
	
	DeleteVariant();
	
EndProcedure

&AtClient
Procedure InventoryMoveUp(Command)
	InventoryMove(-1);
	FillInventoryRelativeLineNumbers();
EndProcedure

&AtClient
Procedure InventoryMoveDown(Command)
	InventoryMove(1);
	FillInventoryRelativeLineNumbers();
EndProcedure

&AtClient
Procedure InventorySortAscending(Command)
	InventorySort("Asc");
	FillInventoryRelativeLineNumbers();
EndProcedure

&AtClient
Procedure InventorySortDescending(Command)
	InventorySort("Desc");
	FillInventoryRelativeLineNumbers();
EndProcedure

#EndRegion

#Region Private

#Region Other

&AtServer
Procedure SetAccountingPolicyValues()

	AccountingPolicy = InformationRegisters.AccountingPolicy.GetAccountingPolicy(DocumentDate, Object.Company);
	RegisteredForVAT = AccountingPolicy.RegisteredForVAT;
	
EndProcedure

&AtServer
Procedure FillVATRateByCompanyVATTaxation()
	
	TaxationBeforeChange = Object.VATTaxation;
	
	Object.VATTaxation = DriveServer.CounterpartyVATTaxation(Object.Counterparty, DriveServer.VATTaxation(Object.Company, Object.Date));
	
	If Not TaxationBeforeChange = Object.VATTaxation Then
		FillVATRateByVATTaxation();
	EndIf;
	
EndProcedure

&AtServer
Procedure FillVATRateByVATTaxation()
	
	If Object.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then
		
		Items.InventoryVATRate.Visible = True;
		Items.InventoryVATAmount.Visible = True;
		Items.InventoryAmountTotal.Visible = True;
		Items.PaymentCalendarPayVATAmount.Visible = True;
		Items.ListPaymentsCalendarSumVatOfPayment.Visible = True;
		Items.InventoryTotalVATAmount.Visible = True;
		
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
		Items.PaymentCalendarPayVATAmount.Visible = False;
		Items.ListPaymentsCalendarSumVatOfPayment.Visible = False;
		Items.InventoryTotalVATAmount.Visible = False;
		
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
	
	RecalculatePaymentCurrencyRateConversionFactorFragment()
	
EndProcedure

&AtClient
Procedure RecalculatePaymentCurrencyRateConversionFactorEnd(Result, AdditionalParameters) Export
	
	NewRatio = AdditionalParameters.NewRatio;
	NewExchangeRate = AdditionalParameters.NewExchangeRate;
	
	Response = Result;
	
	If Response = DialogReturnCode.Yes Then
		Object.ExchangeRate = NewExchangeRate;
		Object.Multiplicity = NewRatio;
	EndIf;
	
	RecalculatePaymentCurrencyRateConversionFactorFragment();
	
EndProcedure

&AtClient
Procedure RecalculatePaymentCurrencyRateConversionFactorFragment()
	
	// Generate price and currency label.
	LabelStructure = New Structure;
	LabelStructure.Insert("PriceKind",						Object.PriceKind);
	LabelStructure.Insert("DiscountKind",					Object.DiscountMarkupKind);
	LabelStructure.Insert("DocumentCurrency",				Object.DocumentCurrency);
	LabelStructure.Insert("SettlementsCurrency",			SettlementsCurrency);
	LabelStructure.Insert("ExchangeRate",					Object.ExchangeRate);
	LabelStructure.Insert("AmountIncludesVAT",				Object.AmountIncludesVAT);
	LabelStructure.Insert("ForeignExchangeAccounting",		ForeignExchangeAccounting);
	LabelStructure.Insert("RateNationalCurrency",			RateNationalCurrency);
	LabelStructure.Insert("VATTaxation",					Object.VATTaxation);
	LabelStructure.Insert("DiscountCard",					Object.DiscountCard);
	LabelStructure.Insert("DiscountPercentByDiscountCard",	Object.DiscountPercentByDiscountCard);
	LabelStructure.Insert("RegisteredForVAT",				RegisteredForVAT);
	
	PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
	
EndProcedure

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

&AtServer
Procedure RecalculateSubtotal()
	
	InventoryRowsCount = 0;
	
	If Object.VariantsCount = 0 Then
		InventoryRows = Object.Inventory;
		Table = InventoryRows.Unload();
	Else
		InventoryRows = Object.Inventory.FindRows(New Structure("Variant", CurrentVariant));
		Table = Object.Inventory.Unload(InventoryRows);
	EndIf;
	
	InventoryRowsCount = InventoryRows.Count() - 1;
	
	Totals = DriveServer.CalculateSubtotal(Table, Object.AmountIncludesVAT);
	
	FillPropertyValues(ThisObject, Totals);
	
EndProcedure

#EndRegion

#Region WorkWithSelection

&AtServer
Procedure GetInventoryFromStorage(InventoryAddressInStorage, TabularSectionName, AreCharacteristics)
	
	TableForImport = GetFromTempStorage(InventoryAddressInStorage);
	
	For Each ImportRow In TableForImport Do
		
		NewRow = Object[TabularSectionName].Add();
		FillPropertyValues(NewRow, ImportRow);
		NewRow.Variant = CurrentVariant;
		
	EndDo;
	
	// AutomaticDiscounts
	If TableForImport.Count() > 0 Then
		ResetFlagDiscountsAreCalculatedServer("PickDataProcessor");
	EndIf;
	
EndProcedure

&AtClient
Procedure OnCloseSelection(ClosingResult, AdditionalParameters) Export
	
	If TypeOf(ClosingResult) = Type("Structure") Then
		
		If Not IsBlankString(ClosingResult.CartAddressInStorage) Then
			
			InventoryAddressInStorage	= ClosingResult.CartAddressInStorage;
			GetInventoryFromStorage(InventoryAddressInStorage, "Inventory", True);
		
			// Payment calendar
			RecalculatePaymentCalendar();
			RecalculateSubtotal();
			
			FillInventoryRelativeLineNumbers();
			SetVariantRowFilter();
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region Header

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
	SetAccountingPolicyValues();
	
	Return StructureData;
	
EndFunction

&AtServer
Function GetCompanyDataOnChange()
	
	StructureData = New Structure();
	
	StructureData.Insert("ParentCompany", DriveServer.GetCompany(Object.Company));
	StructureData.Insert("BankAccount", Object.Company.BankAccountByDefault);
	StructureData.Insert("BankAccountCashAssetsCurrency", Object.Company.BankAccountByDefault.CashCurrency);
	
	FillVATRateByCompanyVATTaxation();
	SetAccountingPolicyValues();
	
	Return StructureData;
	
EndFunction

&AtServer
Function GetDataCounterpartyOnChange(Date, DocumentCurrency, Counterparty, Company)
	
	ContractByDefault = GetContractByDefault(Object.Ref, Counterparty, Company);
	
	FillVATRateByVATTaxation();
	
	StructureData = New Structure;
	
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
		"DiscountMarkupKind",
		ContractByDefault.DiscountMarkupKind);
	
	StructureData.Insert(
		"PriceKind",
		ContractByDefault.PriceKind);
	
	StructureData.Insert(
		"SettlementsInStandardUnits",
		ContractByDefault.SettlementsInStandardUnits);
		
	StructureData.Insert(
		"SalesRep",
		CommonUse.ObjectAttributeValue(Counterparty, "SalesRep"));
	
	SetContractVisible();
	
	Return StructureData;
	
EndFunction

&AtServerNoContext
Function GetDataContractOnChange(Date, DocumentCurrency, Contract)
	
	StructureData = New Structure;
	
	StructureData.Insert(
		"SettlementsCurrency",
		Contract.SettlementsCurrency);
	
	StructureData.Insert(
		"SettlementsCurrencyRateRepetition",
		InformationRegisters.ExchangeRates.GetLast(Date, New Structure("Currency", Contract.SettlementsCurrency)));
	
	StructureData.Insert(
		"SettlementsInStandardUnits",
		Contract.SettlementsInStandardUnits);
	
	StructureData.Insert(
		"DiscountMarkupKind",
		Contract.DiscountMarkupKind);
	
	StructureData.Insert(
		"PriceKind",
		Contract.PriceKind);
	
	StructureData.Insert(
		"AmountIncludesVAT",
		?(ValueIsFilled(Contract.PriceKind), Contract.PriceKind.PriceIncludesVAT, Undefined));
	
	Return StructureData;
	
EndFunction

&AtClient
Procedure CounterpartyOnChangeEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		
		DriveClient.RefillTabularSectionPricesByPriceKind(ThisObject, "Inventory", True);
		RecalculatePaymentCalendar();
		RecalculateSubtotal();
		
	EndIf;
	
EndProcedure

&AtServer
Procedure SetContractVisible()
	
	Items.Contract.Visible = Object.Counterparty.DoOperationsByContracts;
	
EndProcedure

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

&AtClient
Procedure ProcessContractChange()
	
	ContractBeforeChange	= Contract;
	Contract 				= Object.Contract;
	
	If ContractBeforeChange <> Object.Contract Then
		
		StructureData = GetDataContractOnChange(Object.Date, Object.DocumentCurrency, Object.Contract);
		
		SettlementsCurrencyBeforeChange = SettlementsCurrency;
		SettlementsCurrency = StructureData.SettlementsCurrency;
		
		If Not StructureData.AmountIncludesVAT = Undefined Then
			
			Object.AmountIncludesVAT = StructureData.AmountIncludesVAT;
			
		EndIf;
		
		If ValueIsFilled(Object.Contract) Then 
			Object.ExchangeRate	  = ?(StructureData.SettlementsCurrencyRateRepetition.ExchangeRate = 0, 1, StructureData.SettlementsCurrencyRateRepetition.ExchangeRate);
			Object.Multiplicity = ?(StructureData.SettlementsCurrencyRateRepetition.Multiplicity = 0, 1, StructureData.SettlementsCurrencyRateRepetition.Multiplicity);
		EndIf;
		
		PriceKindChanged = Object.PriceKind <> StructureData.PriceKind 
			AND ValueIsFilled(StructureData.PriceKind);
			
		DiscountKindChanged = Object.DiscountMarkupKind <> StructureData.DiscountMarkupKind 
			AND ValueIsFilled(StructureData.DiscountMarkupKind);
		
		NewContractAndCalculationCurrency = ValueIsFilled(Object.Contract) AND ValueIsFilled(SettlementsCurrency) 
			AND Object.Contract <> ContractBeforeChange AND SettlementsCurrencyBeforeChange <> StructureData.SettlementsCurrency;
			
		OpenFormPricesAndCurrencies = NewContractAndCalculationCurrency AND Object.DocumentCurrency <> StructureData.SettlementsCurrency
			AND Object.Inventory.Count() > 0;

			
		QueryPriceKind = ValueIsFilled(Object.Contract) AND (PriceKindChanged OR DiscountKindChanged);
		If QueryPriceKind Then
			If PriceKindChanged Then
				Object.PriceKind = StructureData.PriceKind;
			EndIf; 
			If DiscountKindChanged Then
				Object.DiscountMarkupKind = StructureData.DiscountMarkupKind;
			EndIf; 
		EndIf;
		
		If Object.DocumentCurrency <> StructureData.SettlementsCurrency Then
			Object.BankAccount = Undefined;
		EndIf;
		Object.DocumentCurrency = StructureData.SettlementsCurrency;
		
		If OpenFormPricesAndCurrencies Then
			
			WarningText = "";
			If QueryPriceKind Then
				
				WarningText = NStr("en = 'The price and discount in the contract with counterparty differ from price and discount in the document. 
				                   |Perhaps you have to refill prices.'") + Chars.LF + Chars.LF;
				
			EndIf;
			
			WarningText = WarningText + NStr("en = 'Settlement currency of the contract with counterparty has changed.
			                                 |It is necessary to check the document currency.'"
			);
			
			ProcessChangesOnButtonPricesAndCurrencies(SettlementsCurrencyBeforeChange, True, PriceKindChanged, WarningText);
			
		ElsIf QueryPriceKind Then
			
			RecalculationRequired = (Object.Inventory.Count() > 0);
			
			LabelStructure = New Structure;
			LabelStructure.Insert("PriceKind",						Object.PriceKind);
			LabelStructure.Insert("DiscountKind",					Object.DiscountMarkupKind);
			LabelStructure.Insert("DocumentCurrency",				Object.DocumentCurrency);
			LabelStructure.Insert("SettlementsCurrency",			SettlementsCurrency);
			LabelStructure.Insert("ExchangeRate",					Object.ExchangeRate);
			LabelStructure.Insert("AmountIncludesVAT",				Object.AmountIncludesVAT);
			LabelStructure.Insert("ForeignExchangeAccounting",	ForeignExchangeAccounting);
			LabelStructure.Insert("RateNationalCurrency",			RateNationalCurrency);
			LabelStructure.Insert("VATTaxation",					Object.VATTaxation);
			LabelStructure.Insert("DiscountCard",					Object.DiscountCard);
			LabelStructure.Insert("DiscountPercentByDiscountCard",	Object.DiscountPercentByDiscountCard);
			LabelStructure.Insert("RegisteredForVAT",				RegisteredForVAT);
					
			PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
			
			If RecalculationRequired Then
				
				MessageText = NStr("en = 'The price and discount in the contract with counterparty differ from price and discount in the document. 
				                   |Recalculate the document according to the contract?'");
										
				Mode = QuestionDialogMode.YesNo;
				ShowQueryBox(New NotifyDescription("ProcessContractChangeEnd", ThisObject, New Structure("ContractBeforeChange, SettlementsCurrencyBeforeChange, StructureData", ContractBeforeChange, SettlementsCurrencyBeforeChange, StructureData)), MessageText, Mode, 0);
				Return;
				
			EndIf;
			
		Else
			
			LabelStructure = New Structure;
			LabelStructure.Insert("PriceKind",						Object.PriceKind);
			LabelStructure.Insert("DiscountKind",					Object.DiscountMarkupKind);
			LabelStructure.Insert("DocumentCurrency",				Object.DocumentCurrency);
			LabelStructure.Insert("SettlementsCurrency",			SettlementsCurrency);
			LabelStructure.Insert("ExchangeRate",					Object.ExchangeRate);
			LabelStructure.Insert("AmountIncludesVAT",				Object.AmountIncludesVAT);
			LabelStructure.Insert("ForeignExchangeAccounting",	ForeignExchangeAccounting);
			LabelStructure.Insert("RateNationalCurrency",			RateNationalCurrency);
			LabelStructure.Insert("VATTaxation",					Object.VATTaxation);
			LabelStructure.Insert("DiscountCard",					Object.DiscountCard);
			LabelStructure.Insert("DiscountPercentByDiscountCard",	Object.DiscountPercentByDiscountCard);
			LabelStructure.Insert("RegisteredForVAT",				RegisteredForVAT);
					
			PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
			
		EndIf;
		
		FillPaymentCalendarFromContract(SwitchTypeListOfPaymentCalendar);
		UpdatePaymentCalendar();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ProcessContractChangeEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		
		DriveClient.RefillTabularSectionPricesByPriceKind(ThisObject, "Inventory", True);
		RecalculatePaymentCalendar();
		RecalculateSubtotal();
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Function GetChoiceFormOfContractParameters(Document, Company, Counterparty, Contract)
	
	ContractTypesList = Catalogs.CounterpartyContracts.GetContractKindsListForDocument(Document);
	
	FormParameters = New Structure;
	FormParameters.Insert("ControlContractChoice", Counterparty.DoOperationsByContracts);
	FormParameters.Insert("Counterparty", Counterparty);
	FormParameters.Insert("Company", Company);
	FormParameters.Insert("ContractType", ContractTypesList);
	FormParameters.Insert("CurrentRow", Contract);
	
	Return FormParameters;
	
EndFunction

#EndRegion

#Region PricesAndCurrency

&AtClient
Procedure ProcessChangesOnButtonPricesAndCurrencies(Val SettlementsCurrencyBeforeChange, RecalculatePrices = False, RefillPrices = False, WarningText = "")
	
	// 1. Form parameter structure to fill the "Prices and Currency" form.
	ParametersStructure = New Structure();
	
	ParametersStructure.Insert("PriceKind",			Object.PriceKind);
	ParametersStructure.Insert("DocumentCurrency",	Object.DocumentCurrency);
	ParametersStructure.Insert("VATTaxation",		Object.VATTaxation);
	ParametersStructure.Insert("AmountIncludesVAT",	Object.AmountIncludesVAT);
	ParametersStructure.Insert("Contract",			Object.Contract);
	ParametersStructure.Insert("ExchangeRate",		Object.ExchangeRate);
	ParametersStructure.Insert("Multiplicity",		Object.Multiplicity);
	ParametersStructure.Insert("Company",			ParentCompany);
	ParametersStructure.Insert("DocumentDate",		Object.Date);
	ParametersStructure.Insert("RefillPrices",	 	RefillPrices);
	ParametersStructure.Insert("RecalculatePrices",	RecalculatePrices);
	ParametersStructure.Insert("WereMadeChanges",	False);
	ParametersStructure.Insert("DiscountKind",		Object.DiscountMarkupKind);
	ParametersStructure.Insert("DiscountCard",		Object.DiscountCard);
	// DiscountCards
	ParametersStructure.Insert("Counterparty",		Object.Counterparty);
	// End DiscountCards
	ParametersStructure.Insert("WarningText",		WarningText);
	
	NotifyDescription = New NotifyDescription("ProcessChangesOnButtonPricesAndCurrenciesEnd", ThisObject, New Structure("SettlementsCurrencyBeforeChange", SettlementsCurrencyBeforeChange));
	OpenForm("CommonForm.PricesAndCurrency", ParametersStructure, ThisObject, , , , NotifyDescription, FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtClient
Procedure ProcessChangesOnButtonPricesAndCurrenciesEnd(ClosingResult, AdditionalParameters) Export
	
	// 3. Refills tabular section "Costs" if changes were made in the "Price and Currency" form.
	If TypeOf(ClosingResult) = Type("Structure")
	   AND ClosingResult.WereMadeChanges Then
		
		If Object.DocumentCurrency <> ClosingResult.DocumentCurrency Then
			Object.BankAccount = Undefined;
		EndIf;
		
		Object.PriceKind = ClosingResult.PriceKind;
		Object.DiscountMarkupKind = ClosingResult.DiscountKind;
		// DiscountCards
		If ValueIsFilled(ClosingResult.DiscountCard) AND ValueIsFilled(ClosingResult.Counterparty) AND Not Object.Counterparty.IsEmpty() Then
			If ClosingResult.Counterparty = Object.Counterparty Then
				Object.DiscountCard = ClosingResult.DiscountCard;
				Object.DiscountPercentByDiscountCard = ClosingResult.DiscountPercentByDiscountCard;
			Else // We will show the message and we will not change discount card data.
				CommonUseClientServer.MessageToUser(
					NStr("en = 'Discount card is not read. Discount card holder does not match the counterparty in the document.'"),
					,
					"Counterparty",
					"Object");
			EndIf;
		Else
			Object.DiscountCard = ClosingResult.DiscountCard;
			Object.DiscountPercentByDiscountCard = ClosingResult.DiscountPercentByDiscountCard;
		EndIf;
		// End DiscountCards
		Object.DocumentCurrency = ClosingResult.DocumentCurrency;
		Object.ExchangeRate = ClosingResult.PaymentsRate;
		Object.Multiplicity = ClosingResult.SettlementsMultiplicity;
		Object.AmountIncludesVAT = ClosingResult.AmountIncludesVAT;
		Object.VATTaxation = ClosingResult.VATTaxation;
		
		// Recalculate prices by kind of prices.
		If ClosingResult.RefillPrices Then
			DriveClient.RefillTabularSectionPricesByPriceKind(ThisObject, "Inventory", True);
		EndIf;
		
		// Recalculate prices by currency.
		If Not ClosingResult.RefillPrices
			  AND ClosingResult.RecalculatePrices Then
			DriveClient.RecalculateTabularSectionPricesByCurrency(ThisObject, AdditionalParameters.SettlementsCurrencyBeforeChange, "Inventory");
		EndIf;
		
		// Recalculate the amount if VAT taxation flag is changed.
		If ClosingResult.VATTaxation <> ClosingResult.PrevVATTaxation Then
			FillVATRateByVATTaxation();
		EndIf;
		
		// Recalculate the amount if the "Amount includes VAT" flag is changed.
		If Not ClosingResult.RefillPrices
			AND Not ClosingResult.AmountIncludesVAT = ClosingResult.PrevAmountIncludesVAT Then
			DriveClient.RecalculateTabularSectionAmountByFlagAmountIncludesVAT(ThisObject, "Inventory");
		EndIf;
		
		// AutomaticDiscounts
		If ClosingResult.RefillDiscounts OR ClosingResult.RefillPrices OR ClosingResult.RecalculatePrices Then
			ClearCheckboxDiscountsAreCalculatedClient("RefillByFormDataPricesAndCurrency");
		EndIf;

	EndIf;
	
	LabelStructure = New Structure;
	LabelStructure.Insert("PriceKind",						Object.PriceKind);
	LabelStructure.Insert("DiscountKind",					Object.DiscountMarkupKind);
	LabelStructure.Insert("DocumentCurrency",				Object.DocumentCurrency);
	LabelStructure.Insert("SettlementsCurrency",			SettlementsCurrency);
	LabelStructure.Insert("ExchangeRate",					Object.ExchangeRate);
	LabelStructure.Insert("AmountIncludesVAT",				Object.AmountIncludesVAT);
	LabelStructure.Insert("ForeignExchangeAccounting",		ForeignExchangeAccounting);
	LabelStructure.Insert("RateNationalCurrency",			RateNationalCurrency);
	LabelStructure.Insert("VATTaxation",					Object.VATTaxation);
	LabelStructure.Insert("DiscountCard",					Object.DiscountCard);
	LabelStructure.Insert("DiscountPercentByDiscountCard",	Object.DiscountPercentByDiscountCard);
	LabelStructure.Insert("RegisteredForVAT",				RegisteredForVAT);
	
	PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
	
	RecalculatePaymentCalendar();
	RecalculateSubtotal();
	
EndProcedure

#EndRegion

#Region LibrariesHandlers

#Region StandardSubsystemsAdditionalReportsAndDataProcessors

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

#EndRegion

#Region StandardSubsystemsPrinting

&AtClient
Procedure Attachable_ExecutePrintCommand(Command)
	PrintManagementClient.ExecuteConnectedPrintCommand(Command, ThisObject, Object);
EndProcedure

#EndRegion

#Region StandardSubsystemsProperties

&AtClient
Procedure Attachable_EditContentOfProperties(Command)
	
	PropertiesManagementClient.EditContentOfProperties(ThisObject, Object.Ref);
	
EndProcedure

&AtServer
Procedure UpdateAdditionalAttributesItems()
	
	PropertiesManagement.UpdateAdditionalAttributesItems(ThisObject, FormAttributeToValue("Object"));
	
EndProcedure

#EndRegion

#EndRegion

#Region Inventory

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
	
	If StructureData.Property("DiscountMarkupKind") 
		AND ValueIsFilled(StructureData.DiscountMarkupKind) Then
		StructureData.Insert("DiscountMarkupPercent", StructureData.DiscountMarkupKind.Percent);
	Else	
		StructureData.Insert("DiscountMarkupPercent", 0);
	EndIf;
		
	If StructureData.Property("DiscountPercentByDiscountCard") 
		AND ValueIsFilled(StructureData.DiscountCard) Then
		CurPercent = StructureData.DiscountMarkupPercent;
		StructureData.Insert("DiscountMarkupPercent", CurPercent + StructureData.DiscountPercentByDiscountCard);
	EndIf;

	Return StructureData;
	
EndFunction

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

&AtClient
Procedure CalculateVATSUM(TabularSectionRow)
	
	VATRate = DriveReUse.GetVATRateValue(TabularSectionRow.VATRate);
	
	TabularSectionRow.VATAmount = ?(Object.AmountIncludesVAT, 
									  TabularSectionRow.Amount - (TabularSectionRow.Amount) / ((VATRate + 100) / 100),
									  TabularSectionRow.Amount * VATRate / 100);
	
EndProcedure

&AtClient
Procedure CalculateAmountInTabularSectionLine(TabularSectionRow = Undefined)
	
	If TabularSectionRow = Undefined Then
		TabularSectionRow = Items.Inventory.CurrentData;
	EndIf;
	
	TabularSectionRow.Amount = TabularSectionRow.Quantity * TabularSectionRow.Price;
	
	If TabularSectionRow.DiscountMarkupPercent = 100 Then
		TabularSectionRow.Amount = 0;
	ElsIf TabularSectionRow.DiscountMarkupPercent <> 0
			AND TabularSectionRow.Quantity <> 0 Then
		TabularSectionRow.Amount = TabularSectionRow.Amount * (1 - TabularSectionRow.DiscountMarkupPercent / 100);
	EndIf;
	
	CalculateVATSUM(TabularSectionRow);
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
	// AutomaticDiscounts.
	AutomaticDiscountsRecalculationIsRequired = ClearCheckboxDiscountsAreCalculatedClient("CalculateAmountInTabularSectionLine");
	
	TabularSectionRow.AutomaticDiscountsPercent = 0;
	TabularSectionRow.AutomaticDiscountAmount = 0;
	TabularSectionRow.TotalDiscountAmountIsMoreThanAmount = False;
	// End AutomaticDiscounts
	
EndProcedure

&AtServer
Procedure InventoryMove(Offset)
	
	SelectedRowsCount = Items.Inventory.SelectedRows.Count();
	
	If SelectedRowsCount = 0 Then
		Return;
	EndIf;
	
	If Offset > 0 Then
		BoundaryRowID = Items.Inventory.SelectedRows[SelectedRowsCount - 1];
	Else
		BoundaryRowID = Items.Inventory.SelectedRows[0];
	EndIf;
	BoundaryRow = Object.Inventory.FindByID(BoundaryRowID);
	
	NextRow = Undefined;
	
	Rows = Object.Inventory.FindRows(
		New Structure(
			"Variant, RelativeLineNumber",
			CurrentVariant,
			BoundaryRow.RelativeLineNumber + Offset));
			
	If Rows.Count() <> 0 Then
		NextRow = Rows[0];
	EndIf;
	
	If NextRow = Undefined Then
		Return;
	EndIf;
	
	If Offset > 0 Then
		Index = SelectedRowsCount -1 
	Else
		Index = 0;
	EndIf;
	While Index >= 0 And Index < SelectedRowsCount Do
		RowID = Items.Inventory.SelectedRows[Index];
		InventoryRow = Object.Inventory.FindByID(RowID);
		Object.Inventory.Move(Object.Inventory.IndexOf(InventoryRow), NextRow.LineNumber - InventoryRow.LineNumber);
		Index = Index - Offset;
	EndDo;
	
EndProcedure

&AtServer
Procedure InventorySort(Direction)
	
	InventoryCurrentItem = Items.Inventory.CurrentItem;
	
	If InventoryCurrentItem = Items.InventoryRelativeLineNumber Then
		Return;
	EndIf;
	
	ColumnName = StrReplace(InventoryCurrentItem.DataPath, "Object.Inventory.", "");
	
	Object.Inventory.Sort(ColumnName + " " + Direction);
	
EndProcedure

#EndRegion

#Region PaymentCalendar

&AtClient
Procedure RecalculatePaymentCalendar()
	
	InventoryTotals = GetTotalAmountsForPaymentCalendar(Object.Inventory, Object.VariantsCount, Object.PreferredVariant);
	
	For Each CurRow In Object.PaymentCalendar Do
		CurRow.PaymentAmount = Round(InventoryTotals.Amount * CurRow.PaymentPercentage / 100, 2, 1);
		CurRow.PaymentVATAmount = Round(InventoryTotals.VATAmount * CurRow.PaymentPercentage / 100, 2, 1);
	EndDo;
	
EndProcedure

&AtClient
Procedure SetCurrentPage()
	
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

&AtClient
Procedure SetEditInListFragmentOption()
	
	If SwitchTypeListOfPaymentCalendar Then
		Items.GroupPaymentCalendarListString.CurrentPage = Items.GroupPaymentCalendarList;
	Else
		Items.GroupPaymentCalendarListString.CurrentPage = Items.GroupBillingCalendarString;
	EndIf;

EndProcedure

&AtServerNoContext
Function GetChoiceFormParametersBankAccount(Contract, Company, FunctionalCurrency)
	
	AttributesContract = CommonUse.ObjectAttributesValues(Contract, "SettlementsCurrency, SettlementsInStandardUnits");
	
	CurrenciesList = New ValueList;
	CurrenciesList.Add(AttributesContract.SettlementsCurrency);
	CurrenciesList.Add(FunctionalCurrency);
	
	FormParameters = New Structure;
	FormParameters.Insert("SettlementsInStandardUnits", AttributesContract.SettlementsInStandardUnits);
	FormParameters.Insert("Owner", Company);
	FormParameters.Insert("CurrenciesList", CurrenciesList);
	
	Return FormParameters;
	
EndFunction

&AtServer
Procedure FillThePaymentCalendarOnServer()
	
	FillPaymentCalendarFromContract(SwitchTypeListOfPaymentCalendar);
	
	If Object.PaymentCalendar.Count() = 0 Then
		NewRow = Object.PaymentCalendar.Add();
		
		NewRow.PaymentPercentage = 100;
		InventoryTotals = GetTotalAmountsForPaymentCalendar(Object.Inventory, Object.VariantsCount, Object.PreferredVariant);
		NewRow.PaymentAmount = InventoryTotals.Amount;
		NewRow.PaymentVATAmount = InventoryTotals.VATAmount;
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
Procedure UpdatePaymentCalendar()
	
	SetEnableGroupPaymentCalendarDetails();
	SetEditInListFragmentOption();
	SetCurrentPage();
	
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
Procedure SetEnableGroupPaymentCalendarDetails()
	
	Items.SwitchTypeListOfPaymentCalendar.Enabled = Object.SetPaymentTerms;
	Items.GroupEditList.Enabled = Object.SetPaymentTerms;
	Items.CashboxBankAccount.Enabled = Object.SetPaymentTerms;
	Items.GroupPaymentCalendarListString.Enabled = Object.SetPaymentTerms;
	
EndProcedure

&AtServer
Procedure SetSwitchTypeListOfPaymentCalendar()
	
	If Object.PaymentCalendar.Count() > 1 Then
		SwitchTypeListOfPaymentCalendar = 1;
	Else
		SwitchTypeListOfPaymentCalendar = 0;
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Function GetTotalAmountsForPaymentCalendar(Inventory, VariantsCount, PreferredVariant)
	
	If VariantsCount < 2 Then
		
		PreferredVariantAmount = Inventory.Total("Amount");
		PreferredVariantVATAmount = Inventory.Total("VATAmount");
		
	Else
		
		PreferredVariantAmount = 0;
		PreferredVariantVATAmount = 0;
		InvRows = Inventory.FindRows(New Structure("Variant", PreferredVariant));
		For Each InvRow In InvRows Do
			
			PreferredVariantAmount = PreferredVariantAmount + InvRow.Amount;
			PreferredVariantVATAmount = PreferredVariantVATAmount + InvRow.VATAmount;
			
		EndDo;
		
	EndIf;
	
	Return New Structure("Amount, VATAmount", PreferredVariantAmount, PreferredVariantVATAmount);
	
EndFunction

#EndRegion

#Region BarcodesAndPeripherals

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
				StructureProductsData.Insert("DiscountMarkupKind", StructureData.DiscountMarkupKind);
			EndIf;
			
			// DiscountCards
			StructureProductsData.Insert("DiscountPercentByDiscountCard", StructureData.DiscountPercentByDiscountCard);
			StructureProductsData.Insert("DiscountCard", StructureData.DiscountCard);
			// End DiscountCards
			
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
	StructureData.Insert("DiscountMarkupKind", Object.DiscountMarkupKind);
	StructureData.Insert("VATTaxation", Object.VATTaxation);
	// DiscountCards
	StructureData.Insert("DiscountPercentByDiscountCard", Object.DiscountPercentByDiscountCard);
	StructureData.Insert("DiscountCard", Object.DiscountCard);
	// End DiscountCards
	
	GetDataByBarCodes(StructureData);
	
	For Each CurBarcode In StructureData.BarcodesArray Do
		BarcodeData = StructureData.DataByBarCodes[CurBarcode.Barcode];
		
		If BarcodeData <> Undefined
		   AND BarcodeData.Count() = 0 Then
			UnknownBarcodes.Add(CurBarcode);
		Else
			FilterParameters = New Structure;
			FilterParameters.Insert("Products", BarcodeData.Products);
			FilterParameters.Insert("Characteristic", BarcodeData.Characteristic);
			FilterParameters.Insert("MeasurementUnit", BarcodeData.MeasurementUnit);
			FilterParameters.Insert("Variant", CurrentVariant);
			TSRowsArray = Object.Inventory.FindRows(FilterParameters);
			If TSRowsArray.Count() = 0 Then
				NewRow = Object.Inventory.Add();
				NewRow.Variant = CurrentVariant;
				NewRow.Products = BarcodeData.Products;
				NewRow.Characteristic = BarcodeData.Characteristic;
				NewRow.Quantity = CurBarcode.Quantity;
				NewRow.MeasurementUnit = ?(ValueIsFilled(BarcodeData.MeasurementUnit), BarcodeData.MeasurementUnit, BarcodeData.StructureProductsData.MeasurementUnit);
				NewRow.Price = BarcodeData.StructureProductsData.Price;
				NewRow.DiscountMarkupPercent = BarcodeData.StructureProductsData.DiscountMarkupPercent;
				NewRow.VATRate = BarcodeData.StructureProductsData.VATRate;
				NewCurrentRow = NewRow.GetID();
				CalculateAmountInTabularSectionLine(NewRow);
			Else
				FoundString = TSRowsArray[0];
				FoundString.Quantity = FoundString.Quantity + CurBarcode.Quantity;
				CalculateAmountInTabularSectionLine(FoundString);
				NewCurrentRow= FoundString.GetID();
			EndIf;
		EndIf;
	EndDo;
	
	FillInventoryRelativeLineNumbers();
	SetVariantRowFilter();
	
	Items.Inventory.CurrentRow = NewCurrentRow;
	
	Return UnknownBarcodes;

EndFunction

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
		
		MessageString = NStr("en = 'Barcode is not found: %1%; quantity: %2%'");
		MessageString = StrReplace(MessageString, "%1%", CurUndefinedBarcode.Barcode);
		MessageString = StrReplace(MessageString, "%2%", CurUndefinedBarcode.Quantity);
		CommonUseClientServer.MessageToUser(MessageString);
		
	EndDo;
	
EndProcedure

&AtClient
Procedure SearchByBarcodeEnd(Result, AdditionalParameters) Export
	
	CurBarcode = ?(Result = Undefined, AdditionalParameters.CurBarcode, Result);
	
	
	If Not IsBlankString(CurBarcode) Then
		BarcodesReceived(New Structure("Barcode, Quantity", CurBarcode, 1));
	EndIf;
	
	// Payment calendar.
	RecalculatePaymentCalendar();
	RecalculateSubtotal();

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
			RecalculatePaymentCalendar();
			RecalculateSubtotal();
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure ImportFromDCTEnd(Result, Parameters) Export
	
	If TypeOf(Result) = Type("Array") 
	   AND Result.Count() > 0 Then
		BarcodesReceived(Result);
	EndIf;
	
EndProcedure

#EndRegion

#Region DiscountCards

&AtClient
Procedure ReadDiscountCardClickEnd(ReturnParameters, Parameters) Export

	If TypeOf(ReturnParameters) = Type("Structure") Then
		DiscountCardRead = ReturnParameters.DiscountCardRead;
		DiscountCardIsSelected(ReturnParameters.DiscountCard);
	EndIf;

EndProcedure

&AtClient
Procedure DiscountCardIsSelected(DiscountCard)

	DiscountCardOwner = GetDiscountCardOwner(DiscountCard);
	If Object.Counterparty.IsEmpty() AND Not DiscountCardOwner.IsEmpty() Then
		Object.Counterparty = DiscountCardOwner;
		CounterpartyOnChange(Items.Counterparty);
		
		ShowUserNotification(
			NStr("en = 'Counterparty is filled in and discount card is read'"),
			GetURL(DiscountCard),
			StringFunctionsClientServer.SubstituteParametersInString(NStr("en = 'The counterparty is filled out in the document and discount card %1 is read'"), DiscountCard),
			PictureLib.Information32);
	ElsIf Object.Counterparty <> DiscountCardOwner AND Not DiscountCardOwner.IsEmpty() Then
		
		CommonUseClientServer.MessageToUser(
			NStr("en = 'Discount card is not read. Discount card holder does not match the counterparty in the document.'"),
			,
			"Counterparty",
			"Object");
		
		Return;
	Else
		ShowUserNotification(
			NStr("en = 'Discount card is read'"),
			GetURL(DiscountCard),
			StringFunctionsClientServer.SubstituteParametersInString(NStr("en = 'Discount card %1 is read'"), DiscountCard),
			PictureLib.Information32);
	EndIf;
	
	DiscountCardIsSelectedAdditionally(DiscountCard);
		
EndProcedure

&AtClient
Procedure DiscountCardIsSelectedAdditionally(DiscountCard)
	
	If Not Modified Then
		Modified = True;
	EndIf;
	
	Object.DiscountCard = DiscountCard;
	Object.DiscountPercentByDiscountCard = DriveServer.CalculateDiscountPercentByDiscountCard(Object.Date, DiscountCard);
	
	LabelStructure = New Structure;
	LabelStructure.Insert("PriceKind",						Object.PriceKind);
	LabelStructure.Insert("DiscountKind",					Object.DiscountMarkupKind);
	LabelStructure.Insert("DocumentCurrency",				Object.DocumentCurrency);
	LabelStructure.Insert("SettlementsCurrency",			SettlementsCurrency);
	LabelStructure.Insert("ExchangeRate",					Object.ExchangeRate);
	LabelStructure.Insert("AmountIncludesVAT",				Object.AmountIncludesVAT);
	LabelStructure.Insert("ForeignExchangeAccounting",	ForeignExchangeAccounting);
	LabelStructure.Insert("RateNationalCurrency",			RateNationalCurrency);
	LabelStructure.Insert("VATTaxation",					Object.VATTaxation);
	LabelStructure.Insert("DiscountCard",					Object.DiscountCard);
	LabelStructure.Insert("DiscountPercentByDiscountCard",	Object.DiscountPercentByDiscountCard);
	LabelStructure.Insert("RegisteredForVAT",				RegisteredForVAT);
			
	PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
	
	If Object.Inventory.Count() > 0 Then
		Text = NStr("en = 'Should we recalculate discounts in all lines?'");
		Notification = New NotifyDescription("DiscountCardIsSelectedAdditionallyEnd", ThisObject);
		ShowQueryBox(Notification, Text, QuestionDialogMode.YesNo, , DialogReturnCode.Yes);
	EndIf;
	
EndProcedure

&AtClient
Procedure DiscountCardIsSelectedAdditionallyEnd(QuestionResult, AdditionalParameters) Export

	If QuestionResult = DialogReturnCode.Yes Then
		DriveClient.RefillDiscountsTablePartAfterDiscountCardRead(ThisObject, "Inventory");
	EndIf;
	
	// Payment calendar.
	RecalculatePaymentCalendar();
	RecalculateSubtotal();
	
	// AutomaticDiscounts
	ClearCheckboxDiscountsAreCalculatedClient("DiscountRecalculationByDiscountCard");
	
EndProcedure

&AtServerNoContext
Function GetDiscountCardOwner(DiscountCard)
	
	Return DiscountCard.CardOwner;
	
EndFunction

&AtServerNoContext
Function ThisDiscountCardWithFixedDiscount(DiscountCard)
	
	Return DiscountCard.Owner.DiscountKindForDiscountCards = Enums.DiscountTypeForDiscountCards.FixedDiscount;
	
EndFunction

&AtClient
Procedure RecalculateDiscountPercentAtDocumentDateChange()
	
	If Object.DiscountCard.IsEmpty() OR ThisDiscountCardWithFixedDiscount(Object.DiscountCard) Then
		Return;
	EndIf;
	
	PreDiscountPercentByDiscountCard = Object.DiscountPercentByDiscountCard;
	NewDiscountPercentByDiscountCard = DriveServer.CalculateDiscountPercentByDiscountCard(Object.Date, Object.DiscountCard);
	
	If PreDiscountPercentByDiscountCard <> NewDiscountPercentByDiscountCard Then
		
		If Object.Inventory.Count() > 0 Then
			
			Text = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Do you want to change the discount rate from %1% to %2% and apply to the document?'"),
				PreDiscountPercentByDiscountCard,
				NewDiscountPercentByDiscountCard);
			AdditionalParameters	= New Structure("NewDiscountPercentByDiscountCard, RecalculateTP", NewDiscountPercentByDiscountCard, True);
			Notification			= New NotifyDescription("RecalculateDiscountPercentAtDocumentDateChangeEnd", ThisObject, AdditionalParameters);
			
		Else
			
			Text = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Do you want to change the discount rate from %1% to %2%?'"),
				PreDiscountPercentByDiscountCard,
				NewDiscountPercentByDiscountCard);
			AdditionalParameters	= New Structure("NewDiscountPercentByDiscountCard, RecalculateTP", NewDiscountPercentByDiscountCard, False);
			Notification			= New NotifyDescription("RecalculateDiscountPercentAtDocumentDateChangeEnd", ThisObject, AdditionalParameters);
			
		EndIf;
		
		ShowQueryBox(Notification, Text, QuestionDialogMode.YesNo, , DialogReturnCode.Yes);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure RecalculateDiscountPercentAtDocumentDateChangeEnd(QuestionResult, AdditionalParameters) Export

	If QuestionResult = DialogReturnCode.Yes Then
		Object.DiscountPercentByDiscountCard = AdditionalParameters.NewDiscountPercentByDiscountCard;
		
		LabelStructure = New Structure;
		LabelStructure.Insert("PriceKind",						Object.PriceKind);
		LabelStructure.Insert("DiscountKind",					Object.DiscountMarkupKind);
		LabelStructure.Insert("DocumentCurrency",				Object.DocumentCurrency);
		LabelStructure.Insert("SettlementsCurrency",			SettlementsCurrency);
		LabelStructure.Insert("ExchangeRate",					Object.ExchangeRate);
		LabelStructure.Insert("AmountIncludesVAT",				Object.AmountIncludesVAT);
		LabelStructure.Insert("ForeignExchangeAccounting",	ForeignExchangeAccounting);
		LabelStructure.Insert("RateNationalCurrency",			RateNationalCurrency);
		LabelStructure.Insert("VATTaxation",					Object.VATTaxation);
		LabelStructure.Insert("DiscountCard",					Object.DiscountCard);
		LabelStructure.Insert("DiscountPercentByDiscountCard",	Object.DiscountPercentByDiscountCard);
		LabelStructure.Insert("RegisteredForVAT",				RegisteredForVAT);
				
		PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
		
		If AdditionalParameters.RecalculateTP Then
			DriveClient.RefillDiscountsTablePartAfterDiscountCardRead(ThisObject, "Inventory");
			
			// Payment calendar.
			RecalculatePaymentCalendar();
			RecalculateSubtotal();
		EndIf;
				
	EndIf;
	
EndProcedure

#EndRegion

#Region AutomaticDiscounts

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
		
		If Object.Inventory.Total("AutomaticDiscountAmount") <> Object.DiscountsMarkups.Total("Amount") Then
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
Procedure CalculateDiscountsMarkupsOnServer(ParameterStructure)
	
	AppliedDiscounts = DiscountsMarkupsServerOverridable.Calculate(Object, ParameterStructure);
	
	AddressDiscountsAppliedInTemporaryStorage = PutToTempStorage(AppliedDiscounts, UUID);
	
	Modified = True;
	
	DiscountsMarkupsServerOverridable.UpdateDiscountDisplay(Object, "Inventory");
	
	If Not Object.DiscountsAreCalculated Then
	
		Object.DiscountsAreCalculated = True;
	
	EndIf;
	
	Items.InventoryCalculateDiscountsMarkups.Picture = PictureLib.Refresh;
	
	ThereAreManualDiscounts = Constants.UseManualDiscounts.Get();
	For Each CurrentRow In Object.Inventory Do
		ManualDiscountCurAmount = ?(ThereAreManualDiscounts, CurrentRow.Price * CurrentRow.Quantity * CurrentRow.DiscountMarkupPercent / 100, 0);
		CurAmountDiscounts = ManualDiscountCurAmount + CurrentRow.AutomaticDiscountAmount;
		If CurAmountDiscounts >= CurrentRow.Amount AND CurrentRow.Price > 0 Then
			CurrentRow.TotalDiscountAmountIsMoreThanAmount = True;
		Else
			CurrentRow.TotalDiscountAmountIsMoreThanAmount = False;
		EndIf;
	EndDo;
	
	RecalculateSubtotal();

EndProcedure

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
		QuestionText = NStr("en = 'Do you want to apply discounts?'");
		
		AdditionalParameters = New Structure; 
		AdditionalParameters.Insert("ParameterStructure", ParameterStructure);
		NotificationHandler = New NotifyDescription("NotificationQueryCalculateDiscounts", ThisObject, AdditionalParameters);
		ShowQueryBox(NotificationHandler, QuestionText, QuestionDialogMode.YesNo);
	Else
		CalculateDiscountsCompleteQuestionDataProcessor(ParameterStructure);
	EndIf;
	
EndProcedure

&AtClient
Procedure NotificationQueryCalculateDiscounts(QuestionResult, AdditionalParameters) Export
	
	If QuestionResult = DialogReturnCode.No Then
		Return;
	EndIf;
	ParameterStructure = AdditionalParameters.ParameterStructure;
	CalculateDiscountsMarkupsOnServer(ParameterStructure);
	CalculateDiscountsCompleteQuestionDataProcessor(ParameterStructure);
	
EndProcedure

&AtClient
Procedure CalculateDiscountsCompleteQuestionDataProcessor(ParameterStructure)
	
	If Not ValueIsFilled(AddressDiscountsAppliedInTemporaryStorage) Then
		CalculateDiscountsMarkupsClient();
	EndIf;
	
	CurrentData = Items.Inventory.CurrentData;
	MarkupsDiscountsClient.OpenFormAppliedDiscounts(CurrentData, Object, ThisObject);
	
EndProcedure

&AtServer
Function ResetFlagDiscountsAreCalculatedServer(Action, SPColumn = "")
	
	RecalculationIsRequired = False;
	If UseAutomaticDiscounts AND Object.Inventory.Count() > 0 AND (Object.DiscountsAreCalculated OR InstalledGrayColor) Then
		RecalculationIsRequired = ResetFlagDiscountsAreCalculated(Action, SPColumn);
	EndIf;
	Return RecalculationIsRequired;
	
EndFunction

&AtClient
Function ClearCheckboxDiscountsAreCalculatedClient(Action, SPColumn = "")
	
	RecalculationIsRequired = False;
	If UseAutomaticDiscounts AND Object.Inventory.Count() > 0 AND (Object.DiscountsAreCalculated OR InstalledGrayColor) Then
		RecalculationIsRequired = ResetFlagDiscountsAreCalculated(Action, SPColumn);
	EndIf;
	Return RecalculationIsRequired;
	
EndFunction

&AtServer
Function ResetFlagDiscountsAreCalculated(Action, SPColumn = "")
	
	Return DiscountsMarkupsServer.ResetFlagDiscountsAreCalculated(ThisObject, Action, SPColumn);
	
EndFunction

&AtServer
Procedure AutomaticDiscountsOnCreateAtServer()
	
	InstalledGrayColor = False;
	UseAutomaticDiscounts = GetFunctionalOption("UseAutomaticDiscounts");
	If UseAutomaticDiscounts Then
		If Object.Inventory.Count() = 0 Then
			Items.InventoryCalculateDiscountsMarkups.Picture = PictureLib.UpdateGray;
			InstalledGrayColor = True;
		ElsIf Not Object.DiscountsAreCalculated Then
			Object.DiscountsAreCalculated = False;
			Items.InventoryCalculateDiscountsMarkups.Picture = PictureLib.UpdateRed;
		Else
			Items.InventoryCalculateDiscountsMarkups.Picture = PictureLib.Refresh;
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region Variants

&AtClient
Procedure PopulateVariantsList()
	
	VariantsChoiceList = Items.CurrentVariant.ChoiceList;
	
	VariantsChoiceList.Clear();
	
	SingleVariant = Object.VariantsCount < 2;
	
	If SingleVariant Then
		
		VariantsChoiceList.Add(0, NStr("en = 'Single variant'"));
		Variant = 2;
		
	Else
		
		For Variant = 1 To Object.VariantsCount Do
			
			If Variant = Object.PreferredVariant Then
				VariantPostfix = NStr("en = '(preferred)'");
			Else
				VariantPostfix = "";
			EndIf;
			
			VariantName = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Variant %1 %2'"), Variant, VariantPostfix);
			VariantsChoiceList.Add(Variant, VariantName);
			
		EndDo;
		
	EndIf;
	
	If EditingIsAvailable Then
		VariantsChoiceList.Add(Variant, "+");
	EndIf;
	
EndProcedure

&AtClient
Procedure FillInventoryRelativeLineNumbers()
	
	If CurrentVariant = 0 Then
		
		For Each InventoryRow In Object.Inventory Do
			InventoryRow.RelativeLineNumber = InventoryRow.LineNumber;
		EndDo;
		
	Else
		
		InventoryRows = Object.Inventory.FindRows(New Structure("Variant", CurrentVariant));
		LineNumber = 0;
		For Each InventoryRow In InventoryRows Do
			LineNumber = LineNumber + 1;
			InventoryRow.RelativeLineNumber = LineNumber;
		EndDo;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure SetVariantsActionsAvailability()
	
	CurrentVariantIsPreferred = CurrentVariant = Object.PreferredVariant;
	Items.VariantDelete.Enabled = Not CurrentVariantIsPreferred;
	Items.VariantSetAsPreferred.Enabled = Not CurrentVariantIsPreferred;
	
EndProcedure

&AtClient
Procedure SetVariantRowFilter()
	
	If Object.VariantsCount < 2 Then
		Items.Inventory.RowFilter = Undefined;
	Else
		Items.Inventory.RowFilter = New FixedStructure("Variant", CurrentVariant);
	EndIf;
	
EndProcedure

&AtClient
Procedure AddVariant()
	
	If Object.VariantsCount < 2 Then
		
		Object.VariantsCount = 2;
		Object.PreferredVariant = 1;
		
		For Each InventoryRow In Object.Inventory Do
			InventoryRow.Variant = 1;
		EndDo;
		
	Else
		
		Object.VariantsCount = Object.VariantsCount + 1;
		
	EndIf;
	
	PopulateVariantsList();
	
	CurrentVariant = Object.VariantsCount;
	
	SetVariantsActionsAvailability();
	SetVariantRowFilter();
	
EndProcedure

&AtClient
Procedure CopyVariant()
	
	PreviousVariant = ?(CurrentVariant = 0, 1, CurrentVariant);
	
	AddVariant();
	
	InventoryRows = Object.Inventory.FindRows(New Structure("Variant", PreviousVariant));
	
	For Each InventoryRow In InventoryRows Do
		
		NewRow = Object.Inventory.Add();
		FillPropertyValues(NewRow, InventoryRow, , "ConnectionKey");
		NewRow.Variant = CurrentVariant;
		
	EndDo;
	
	RecalculateSubtotal();
	
	ClearCheckboxDiscountsAreCalculatedClient("DeleteRow");
	
EndProcedure

&AtClient
Procedure DeleteVariant()
	
	If CurrentVariant = Object.PreferredVariant
		Or Object.VariantsCount < 2
		Or Object.PreferredVariant = 0 Then
		
		Return;
		
	EndIf;
	
	InvRows = Object.Inventory.FindRows(New Structure("Variant", CurrentVariant));
	For Each InvRow In InvRows Do
		Object.Inventory.Delete(InvRow);
	EndDo;
	
	If Object.VariantsCount = 2 Then
		
		Object.VariantsCount = 0;
		Object.PreferredVariant = 0;
		
		For Each InvRow In Object.Inventory Do
			InvRow.Variant = 0;
		EndDo;
		
	Else
		
		Object.VariantsCount = Object.VariantsCount - 1;
		
	EndIf;
	
	CurrentVariant = Object.PreferredVariant;
	
	PopulateVariantsList();
	SetVariantsActionsAvailability();
	FillInventoryRelativeLineNumbers();
	SetVariantRowFilter();
	RecalculateSubtotal();
	
EndProcedure

#EndRegion

#EndRegion
