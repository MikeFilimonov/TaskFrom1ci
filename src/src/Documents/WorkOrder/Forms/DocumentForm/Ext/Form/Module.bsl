#Region Variables

&AtClient
Var WhenChangingStart;

&AtClient
Var WhenChangingFinish;

&AtClient
Var RowCopyWorks;

&AtClient
Var CopyingProductsRow;

#EndRegion

#Region FormEventHandlers

// Procedure - OnCreateAtServer event handler.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	CounterpartyContractParameters = New Structure;
	If Not ValueIsFilled(Object.Ref)
		AND ValueIsFilled(Object.Counterparty)
		AND Not ValueIsFilled(Parameters.CopyingValue) Then
		If Not ValueIsFilled(Object.Contract) Then
			ContractParametersByDefault = CommonUse.ObjectAttributesValues(Object.Counterparty, "ContractByDefault");
			Object.Contract = ContractParametersByDefault;
		EndIf;
		If ValueIsFilled(Object.Contract) Then
			CounterpartyContractParameters = CommonUse.ObjectAttributesValues(Object.Contract, "SettlementsCurrency, DiscountMarkupKind, PriceKind");
			Object.DocumentCurrency = CounterpartyContractParameters.SettlementsCurrency;
			SettlementsCurrencyRateRepetition = InformationRegisters.ExchangeRates.GetLast(Object.Date, New Structure("Currency", CounterpartyContractParameters.SettlementsCurrency));
			Object.ExchangeRate = ?(SettlementsCurrencyRateRepetition.ExchangeRate = 0, 1, SettlementsCurrencyRateRepetition.ExchangeRate);
			Object.DiscountMarkupKind = CounterpartyContractParameters.DiscountMarkupKind;
			Object.PriceKind = CounterpartyContractParameters.PriceKind;
		EndIf;
	Else
		CounterpartyContractParameters = CommonUse.ObjectAttributesValues(Object.Contract, "SettlementsCurrency");
	EndIf;
	
	// Form attributes setting.
	DocumentDate = Object.Date;
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentSessionDate();
	EndIf;
	
	ParentCompany = DriveServer.GetCompany(Object.Company);
	Counterparty = Object.Counterparty;
	Contract = Object.Contract;
	CounterpartyContractParameters.Property("SettlementsCurrency", SettlementsCurrency);
	FunctionalCurrency = DriveReUse.GetNationalCurrency();
	StructureByCurrency = InformationRegisters.ExchangeRates.GetLast(Object.Date, New Structure("Currency", FunctionalCurrency));
	RateNationalCurrency = StructureByCurrency.ExchangeRate;
	RepetitionNationalCurrency = StructureByCurrency.Multiplicity;
	TabularSectionName = "Works";
	FinishDate = Object.Finish;
	
	UseInventoryReservation = GetFunctionalOption("UseInventoryReservation");
	SetAccountingPolicyValues();
	
	If Not ValueIsFilled(Object.Ref) Then
		
		// Start and Finish
		If Not (Parameters.FillingValues.Property("Start") OR Parameters.FillingValues.Property("Finish")) Then
			CurrentDate = CurrentSessionDate();
			Object.Start = CurrentDate;
			Object.Finish = EndOfDay(CurrentDate);
		EndIf;
		
		If Not ValueIsFilled(Parameters.CopyingValue) Then
			
			If Not ValueIsFilled(Object.BankAccount) Then
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
			EndIf;
			
			If Not ValueIsFilled(Object.PettyCash) Then
				Object.PettyCash = Catalogs.CashAccounts.GetPettyCashByDefault(Object.Company);
			EndIf;
			
		EndIf;
		
	EndIf;
	
	MakeNamesOfMaterialsAndPerformers();
	
	If Not ValueIsFilled(Object.Ref)
		AND Not ValueIsFilled(Parameters.Basis) 
		AND Not ValueIsFilled(Parameters.CopyingValue) Then
		FillVATRateByCompanyVATTaxation();
	ElsIf Object.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then
		Items.InventoryVATRate.Visible = True;
		Items.InventoryVATAmount.Visible = True;
		Items.InventoryAmountTotal.Visible = True;
		Items.WorksVATRate.Visible = True;
		Items.WorksAmountVAT.Visible = True;
		Items.WorksTotal.Visible = True;
		Items.PaymentCalendarPaymentVATAmount.Visible = True;
		Items.ListPaymentCalendarVATAmountPayments.Visible = True;
	Else
		Items.InventoryVATRate.Visible = False;
		Items.InventoryVATAmount.Visible = False;
		Items.InventoryAmountTotal.Visible = False;
		Items.WorksVATRate.Visible = False;
		Items.WorksAmountVAT.Visible = False;
		Items.WorksTotal.Visible = False;
		Items.PaymentCalendarPaymentVATAmount.Visible = False;
		Items.ListPaymentCalendarVATAmountPayments.Visible = False;
	EndIf;
	
	// Generate price and currency label.
	ForeignExchangeAccounting = GetFunctionalOption("ForeignExchangeAccounting");
	
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
	
	PricesAndCurrency = GenerateLabelPricesAndCurrency(LabelStructure);
	
	SetVisibleAndEnabledFromState();
	
	UsePayrollSubsystem = GetFunctionalOption("UsePayrollSubsystem")
		AND (AccessManagement.IsRole("AddChangePayrollSubsystem") OR AccessManagement.IsRole("FullRights"));
	
	// FO Use Payroll subsystem.
	SetVisibleByFOUseSubsystemPayroll();
	
	// If the document is opened from pick, fill the tabular section products
	If Parameters.FillingValues.Property("InventoryAddressInStorage")
		AND ValueIsFilled(Parameters.FillingValues.InventoryAddressInStorage) Then
		
		GetInventoryFromStorage(Parameters.FillingValues.InventoryAddressInStorage,
							Parameters.FillingValues.TabularSectionName,
							Parameters.FillingValues.AreCharacteristics,
							Parameters.FillingValues.AreBatches);
		
	EndIf;
	
	// Form title setting.
	If Not ValueIsFilled(Object.Ref) Then
		AutoTitle = False;
		Title = NStr("en = 'Work order (create)'");
	EndIf;
	
	// Status.
	
	InProcessStatus = DriveReUse.GetStatusInProcessOfWorkOrders();
	CompletedStatus = DriveReUse.GetStatusCompletedWorkOrders();
	
	If Not GetFunctionalOption("UseWorkOrderStatuses") Then
		
		Items.GroupState.Visible = False;
		
		Items.ValStatus.ChoiceList.Add(Documents.WorkOrder.InProcessStatus(), NStr("en = 'In process'"));
		Items.ValStatus.ChoiceList.Add(Documents.WorkOrder.CompletedStatus(), NStr("en = 'Completed'"));
		Items.ValStatus.ChoiceList.Add(Documents.WorkOrder.CanceledStatus(), NStr("en = 'Canceled'"));
		
		If Object.OrderState.OrderStatus = Enums.OrderStatuses.InProcess AND Not Object.Closed Then
			ValStatus = Documents.WorkOrder.InProcessStatus();
		ElsIf Object.OrderState.OrderStatus = Enums.OrderStatuses.Completed Then
			ValStatus = Documents.WorkOrder.CompletedStatus();
		Else
			ValStatus = Documents.WorkOrder.CanceledStatus();
		EndIf;
		
	Else
		
		Items.GroupStatuses.Visible = False;
		
	EndIf;
	
	// Attribute visible set from user settings
	SetVisibleFromUserSettings(); 
	
	If ValueIsFilled(Object.Ref) Then
		NotifyWorkCalendar = False;
	Else
		NotifyWorkCalendar = True;
	EndIf;
	
	// Set filter for TableWorks by Product type.
	FilterStructure = New Structure;
	FilterStructure.Insert("ProductsTypeService", False);
	FixedFilterStructure = New FixedStructure(FilterStructure);
	Items.TableWorks.RowFilter = FixedFilterStructure;
	
	// Setting contract visible.
	SetContractVisible();
	
	// Price accessibility setup for editing.
	AllowedEditDocumentPrices = DriveAccessManagementReUse.AllowedEditDocumentPrices();
	
	Items.WorksPrice.ReadOnly 					= Not AllowedEditDocumentPrices;
	Items.WorksDiscountMarkupPercent.ReadOnly	= Not AllowedEditDocumentPrices;
	Items.WorksAmount.ReadOnly 					= Not AllowedEditDocumentPrices;
	Items.WorksAmountVAT.ReadOnly 				= Not AllowedEditDocumentPrices;
	
	Items.InventoryPrice.ReadOnly 					= Not AllowedEditDocumentPrices;
	Items.InventoryDiscountPercentMargin.ReadOnly	= Not AllowedEditDocumentPrices;
	Items.InventoryAmount.ReadOnly 					= Not AllowedEditDocumentPrices;
	Items.InventoryVATAmount.ReadOnly	 			= Not AllowedEditDocumentPrices;
	
	// AutomaticDiscounts.
	AutomaticDiscountsOnCreateAtServer();
	
	// StandardSubsystems.ObjectVersioning
	ObjectVersioning.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.ObjectVersioning
	
	// StandardSubsystems.ClosingDates
	ClosingDatesOverridable.CheckDateBanEditingWorkOrder(ThisObject, Object);
	// End StandardSubsystems.ClosingDates
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisObject, Items.GroupImportantCommands);
	// End StandardSubsystems.Printing
	
	// StandardSubsystems.Properties
	PropertiesManagement.OnCreateAtServer(ThisObject, Object, "GroupAdditionalAttributes");
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

	SwitchTypeListOfPaymentCalendar = ?(Object.PaymentCalendar.Count() > 1, 1, 0);
	
EndProcedure

// Procedure - OnReadAtServer event handler.
//
&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	ClosingDates.ObjectOnReadAtServer(ThisObject, CurrentObject);
	MakeNamesOfMaterialsAndPerformers();
	
	// StandardSubsystems.Properties
	PropertiesManagement.OnReadAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.Properties
	
	SetSwitchTypeListOfPaymentCalendar();
	
EndProcedure

// Procedure - event handler OnOpen.
//
&AtClient
Procedure OnOpen(Cancel)
	
	WhenChangingStart = Object.Start;
	WhenChangingFinish = Object.Finish;
	
	// Peripherals
	EquipmentManagerClientOverridable.StartConnectingEquipmentOnFormOpen(ThisObject, "BarCodeScanner");
	// End Peripherals
	
	OWSetCurrentPage();
	
	SetVisiblePaymentCalendar();
	SetVisibleCashAssetsTypes();
	SetEnableGroupPaymentCalendarDetails();
	SetVisibleAndEnabledFromState();
	SetVisibleDeliveryAttributes();
	SetSerialNumberEnable();
	
	RecalculateSubtotal();
	
EndProcedure

// Procedure - event handler OnClose.
//
&AtClient
Procedure OnClose(Exit)
	
	// AutomaticDiscounts
	// Display the message about discount calculation when user clicks the "Post and close" button or closes the form by
	// the cross with saving the changes.
	If UseAutomaticDiscounts AND DiscountsCalculatedBeforeWrite Then
		ShowUserNotification(
			NStr("en = 'Update:'"),
			GetURL(Object.Ref),
			StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = '%1. The automatic discounts are calculated.'"),
				String(Object.Ref)),
			PictureLib.Information32);
	EndIf;
	// End AutomaticDiscounts
	
	// Peripherals
	EquipmentManagerClientOverridable.StartDisablingEquipmentOnCloseForm(ThisObject);
	// End Peripherals
	
EndProcedure

&AtClient
// Procedure - event handler AfterWriting.
//
Procedure AfterWrite(WriteParameters)
	
	If DocumentModified Then
		
		NotifyWorkCalendar = True;
		DocumentModified = False;
		
		Notify("NotificationAboutChangingDebt");
		
	EndIf;
	
EndProcedure

// BeforeRecord event handler procedure.
//
&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	// AutomaticDiscounts
	DiscountsCalculatedBeforeWrite = False;
	// If the document is being posted, we check whether the discounts are calculated.
	If UseAutomaticDiscounts Then
		If Not Object.DiscountsAreCalculated AND DiscountsChanged() Then
			CalculateDiscountsMarkupsClient();
			CalculatedDiscounts = True;
			RecalculateSubtotal();
			CommonUseClientServer.MessageToUser(NStr("en = 'The automatic discounts are applied.'"));
			DiscountsCalculatedBeforeWrite = True;
		Else
			Object.DiscountsAreCalculated = True;
			RefreshImageAutoDiscountsAfterWrite = True;
		EndIf;
	EndIf;
	// End AutomaticDiscounts
	
EndProcedure

&AtServer
// Procedure-handler of the BeforeWriteAtServer event.
//
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	// 'Properties' subsystem handler
	PropertiesManagement.BeforeWriteAtServer(ThisObject, CurrentObject);
	// 'Properties' subsystem handler
	
	If Modified Then
		
		DocumentModified = True;
		
	EndIf;
	
	If WriteParameters.WriteMode = DocumentWriteMode.Posting Then
		
		MessageText = "";
		CheckContractToDocumentConditionAccordance(
			MessageText,
			CurrentObject.Contract,
			CurrentObject.Ref,
			CurrentObject.Company,
			CurrentObject.Counterparty,
			Cancel);
		
		If MessageText <> "" Then
			
			Message = New UserMessage;
			MessageToUserText = ?(Cancel, NStr("en = 'Cannot post the work order.'") + " " + MessageText, MessageText);
			
			If Cancel Then
				CommonUseClientServer.MessageToUser(MessageToUserText, ,"Contract","Object", Cancel);
				Return;
			Else
				CommonUseClientServer.MessageToUser(MessageToUserText);
			EndIf;
		EndIf;
		
	EndIf;
	
	// AutomaticDiscounts
	If RefreshImageAutoDiscountsAfterWrite Then
		Items.WorksCalculateDiscountsMarkups.Picture = PictureLib.Refresh;
		Items.InventoryCalculateDiscountsMarkups.Picture = PictureLib.Refresh;
		RefreshImageAutoDiscountsAfterWrite = False;
	EndIf;
	// End AutomaticDiscounts
	
EndProcedure

&AtServer
// Procedure-handler of the FillCheckProcessingAtServer event.
//
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	// StandardSubsystems.Properties
	PropertiesManagement.FillCheckProcessing(ThisObject, Cancel, CheckedAttributes);
	// End StandardSubsystems.Properties
	
EndProcedure

&AtServer
// Procedure-handler of the AfterWriteOnServer event.
//
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	// Form title setting.
	Title = "";
	AutoTitle = True;
	
	MakeNamesOfMaterialsAndPerformers();
	
EndProcedure

&AtClient
// Procedure - event handler BeforeClose form.
//
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	If NotifyWorkCalendar Then
		Notify("ChangedWorkOrder", Object.Responsible);
	EndIf;
	
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
		
	ElsIf EventName = "SerialNumbersSelection"
		AND ValueIsFilled(Parameter) 
		// Form owner checkup
		AND Source <> New UUID("00000000-0000-0000-0000-000000000000")
		AND Source = UUID Then
		
		If Items.Pages.CurrentPage = Items.GroupWork Then
			ChangedCount = GetSerialNumbersMaterialsFromStorage(Parameter.AddressInTemporaryStorage, Parameter.RowKey);
			// Recalculation of the amount not required
		Else
			ChangedCount = GetSerialNumbersFromStorage(Parameter.AddressInTemporaryStorage, Parameter.RowKey);
			If ChangedCount Then
				CalculateAmountInTabularSectionLine("Inventory");
			EndIf; 
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

// Procedure - event handler OnChange input field Status.
//
&AtClient
Procedure VALStatusOnChange(Item)
	
	If ValStatus = NStr("en = 'In process'") Then
		Object.OrderState = InProcessStatus;
		Object.Closed = False;
	ElsIf ValStatus = NStr("en = 'Completed'") Then
		Object.OrderState = CompletedStatus;
	ElsIf ValStatus = NStr("en = 'Canceled'") Then
		Object.OrderState = InProcessStatus;
		Object.Closed = True;
	EndIf;
	
	Modified = True;
	
	SetVisibleAndEnabledFromState();
	
EndProcedure

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
		LabelStructure.Insert("ForeignExchangeAccounting",	ForeignExchangeAccounting);
		LabelStructure.Insert("RateNationalCurrency",			RateNationalCurrency);
		LabelStructure.Insert("VATTaxation",					Object.VATTaxation);
		LabelStructure.Insert("DiscountCard",					Object.DiscountCard);
		LabelStructure.Insert("DiscountPercentByDiscountCard",	Object.DiscountPercentByDiscountCard);
		LabelStructure.Insert("RegisteredForVAT",				RegisteredForVAT);
		
		PricesAndCurrency = GenerateLabelPricesAndCurrency(LabelStructure);
		
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

// Procedure - event handler OnChange of the Company input field.
// In procedure the document number
// is cleared, and also the form functional options are configured.
// Overrides the corresponding form parameter.
//
&AtClient
Procedure CompanyOnChange(Item)

	// Company change event data processor.
	Object.Number = "";
	StructureData = GetCompanyDataOnChange();
	ParentCompany = StructureData.Company;
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
	
	PricesAndCurrency = GenerateLabelPricesAndCurrency(LabelStructure);
	RecalculatePaymentCalendar();
	RecalculateSubtotal();
	
EndProcedure

// Procedure - event handler OnChange of the Counterparty input field.
// Clears the contract and tabular section.
//
&AtClient
Procedure CounterpartyOnChange(Item)
	
	CounterpartyBeforeChange = Counterparty;
	Counterparty = Object.Counterparty;
	
	If CounterpartyBeforeChange <> Object.Counterparty Then
		
		ContractData = GetDataCounterpartyOnChange(Object.Date, Object.DocumentCurrency, Object.Counterparty, Object.Company);
		Object.Contract = ContractData.Contract;
		ProcessContractChange(ContractData);
		Object.SalesRep = ContractData.SalesRep;
		
		DeliveryData = GetDeliveryData(Object.Counterparty);
		Object.DeliveryOption = DeliveryData.DeliveryOption;
		
		If DeliveryData.ShippingAddress = Undefined Then
			CommonUseClientServer.MessageToUser(NStr("en = 'There is no shipping address marked as default'"));
		Else
			Object.Location = DeliveryData.ShippingAddress;
		EndIf;
		SetVisibleDeliveryAttributes();
		
	Else
		
		Object.Contract = Contract; // Restore the cleared contract automatically.
		
	EndIf;
	
	// AutomaticDiscounts
	ClearCheckboxDiscountsAreCalculatedClient("CounterpartyOnChange");
	
EndProcedure

&AtClient
Procedure DeliveryOptionOnChange(Item)
	SetVisibleDeliveryAttributes();
EndProcedure

&AtClient
Procedure LocationOnChange(Item)
	
	DeliveryData = GetDeliveryAttributes(Object.Location);
	
	If ValueIsFilled(DeliveryData.SalesRep) Then
		Object.SalesRep = DeliveryData.SalesRep;
	EndIf;

EndProcedure

// The OnChange event handler of the Contract field.
// It updates the currency exchange rate and exchange rate multiplier.
//
&AtClient
Procedure ContractOnChange(Item)
	
	ProcessContractChange();
	
EndProcedure

&AtClient
Procedure EquipmentOnChange(Item)
	
	SetSerialNumberEnable();
	
EndProcedure

// Procedure - event handler SelectionStart input field Contract.
//
&AtClient
Procedure ContractStartChoice(Item, ChoiceData, StandardProcessing)
	
	FormParameters = GetChoiceFormOfContractParameters(Object.Ref, Object.Company, Object.Counterparty, Object.Contract);
	If FormParameters.ControlContractChoice Then
		
		StandardProcessing = False;
		OpenForm("Catalog.CounterpartyContracts.Form.ChoiceForm", FormParameters, Item);
		
	EndIf;
	
EndProcedure

// Procedure - event handler OnChange of the StructuralUnit input field.
//
&AtClient
Procedure SalesStructuralUnitOnChange(Item)
	
	If ValueIsFilled(Object.SalesStructuralUnit) Then
		
		If Not ValueIsFilled(Object.StructuralUnitReserve) Then
			
			StructureData = New Structure();
			StructureData.Insert("Department", Object.SalesStructuralUnit);
			
			StructureData = GetDataStructuralUnitOnChange(StructureData);
			
			Object.StructuralUnitReserve = StructureData.InventoryStructuralUnit;
			
		EndIf;
		
	Else
		
		Items.WOCellInventory.Enabled = False;
		
	EndIf;
	
EndProcedure

// Procedure - event handler OnChange of the OrderState input field.
//
&AtClient
Procedure OrderStatusOnChange(Item)
	
	If Object.OrderState <> CompletedStatus Then 
		Object.Closed = False;
	EndIf;
	
	SetVisibleAndEnabledFromState();
	
EndProcedure

&AtClient
Procedure OrderStatusStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	ChoiceData = GetWorkOrderStates();
	
EndProcedure

// Procedure - event handler OnChange input field Start.
//
&AtClient
Procedure StartOnChange(Item)
	
	If Object.Start > Object.Finish Then
		Object.Start = WhenChangingStart;
		CommonUseClientServer.MessageToUser(NStr("en = 'The start date is later than the end date. Please correct the dates.'"));
	Else
		WhenChangingStart = Object.Start;
	EndIf;
	
EndProcedure

// Procedure - event handler OnChange input field Finish.
//
&AtClient
Procedure FinishOnChange(Item)
	
	If Object.Finish < Object.Start Then
		Object.Finish = WhenChangingFinish;
		CommonUseClientServer.MessageToUser(NStr("en = 'The end date is earlier than the start date. Please correct the dates.'"));
	Else
		WhenChangingFinish = Object.Finish;
	EndIf;
	
	If FinishDate <> Object.Finish Then
		
		RecalculatePaymentDate(FinishDate, Object.Finish);
		FinishDate = Object.Finish;
		
	EndIf;
	
EndProcedure

// Procedure - event handler OnChange input field WorkKind.
//
&AtClient
Procedure WorkKindOnChange(Item)
	
	If ValueIsFilled(Object.WorkKind) Then
		
		FillWithBundledService(Object.WorkKind);
		
	EndIf;
	
EndProcedure

// Procedure - event handler SelectionStart input field BankAccount.
//
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

// Gets the banking account selection form parameter structure.
//
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

&AtClient
Procedure StatusExtendedTooltipNavigationLinkProcessing(Item, URL, StandardProcessing)
	
	StandardProcessing = False;
	OpenForm("DataProcessor.AdministrationPanel.Form.SectionSales");
	
EndProcedure

#EndRegion

#Region InventoryFormTableItemsEventHandlers

// Procedure - event handler OnEditEnd tabular section Products.
//
&AtClient
Procedure InventoryOnEditEnd(Item, NewRow, CancelEdit)
	
	// Payment calendar.
	RecalculatePaymentCalendar();
	
EndProcedure

// Procedure - event handler AfterDeleteRow tabular section Products.
//
&AtClient
Procedure InventoryAfterDeletion(Item)
	
	// Payment calendar.
	RecalculatePaymentCalendar();
	RecalculateSubtotal();
	
	// AutomaticDiscounts.
	ClearCheckboxDiscountsAreCalculatedClient("DeleteRow");
	
EndProcedure

&AtClient
// Procedure - event handler BeforeAddStart tabular section "Products".
//
Procedure InventoryBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	If Copy Then
		RecalculateSubtotal();
		CopyingProductsRow = True;
	EndIf;
	
EndProcedure

&AtClient
// Procedure - event handler OnChange tabular section "Products".
//
Procedure InventoryOnChange(Item)
	
	If CopyingProductsRow = Undefined OR Not CopyingProductsRow Then
		RecalculateSubtotal();
	Else
		CopyingProductsRow = False;
	EndIf;
	
EndProcedure

// Procedure - event handler OnChange of the Products input field.
//
&AtClient
Procedure ProductsProductsOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	StructureData = New Structure;
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
	
	TabularSectionRow.ProductsTypeInventory = StructureData.IsInventoryItem;
	
	// Serial numbers
	WorkWithSerialNumbersClientServer.DeleteSerialNumbersByConnectionKey(Object.SerialNumbers, TabularSectionRow,, UseSerialNumbersBalance);
	
	CalculateAmountInTabularSectionLine("Inventory");
	
EndProcedure

// Procedure - event handler OnChange of the Characteristic input field.
//
&AtClient
Procedure ProductsCharacteristicOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("Products",			TabularSectionRow.Products);
	StructureData.Insert("Characteristic",		TabularSectionRow.Characteristic);
	
	If ValueIsFilled(Object.PriceKind) Then
		
		StructureData.Insert("ProcessingDate",		Object.Date);
		StructureData.Insert("DocumentCurrency",	Object.DocumentCurrency);
		StructureData.Insert("AmountIncludesVAT",	Object.AmountIncludesVAT);
		StructureData.Insert("VATRate",				TabularSectionRow.VATRate);
		StructureData.Insert("Price",				TabularSectionRow.Price);
		StructureData.Insert("PriceKind",			Object.PriceKind);
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
Procedure ProductsQuantityOnChange(Item)
	
	CalculateAmountInTabularSectionLine("Inventory");
	
	// Payment calendar.
	RecalculatePaymentCalendar();
	
EndProcedure

// Procedure - event handler ChoiceProcessing of the MeasurementUnit input field.
//
&AtClient
Procedure GoodsMeasurementUnitChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	If TabularSectionRow.MeasurementUnit = ValueSelected
		Or TabularSectionRow.Price = 0 Then
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
	
	CalculateAmountInTabularSectionLine("Inventory");
	
EndProcedure

// Procedure - event handler OnChange of the Price input field.
//
&AtClient
Procedure ProductsPriceOnChange(Item)
	
	CalculateAmountInTabularSectionLine("Inventory");
	
	// Payment calendar.
	RecalculatePaymentCalendar();
	
EndProcedure

// Procedure - event handler OnChange of the DiscountMarkupPercent input field.
//
&AtClient
Procedure GoodsDiscountMarkupPercentOnChange(Item)
	
	CalculateAmountInTabularSectionLine("Inventory");
	
	// Payment calendar.
	RecalculatePaymentCalendar();
	
EndProcedure

// Procedure - event handler OnChange of the Amount input field.
//
&AtClient
Procedure ProductsAmountOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
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
Procedure ProductsVATRateOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
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
Procedure ProductsVATAmountOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	// Total.
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
	// Payment calendar.
	RecalculatePaymentCalendar();
	
EndProcedure

// Procedure - event handler OnChange input field Reserve.
//
&AtClient
Procedure WOProductsReserveOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
EndProcedure

#EndRegion

#Region WorksFormTableItemsEventHandlers

// Procedure - event handler OnActivateRow tabular sectionp "Works".
//
&AtClient
Procedure WorksOnActivateRow(Item)
	
	TabularSectionName = "Works";
	DriveClient.SetFilterOnSubordinateTabularSection(ThisObject, "Materials");
	
	TabularSectionRow = Items.Works.CurrentData;
	If TabularSectionRow <> Undefined Then
		Items.WorkMaterials.Enabled = Not TabularSectionRow.ProductsTypeService;
	EndIf;
	
EndProcedure

// Procedure - event handler OnActivateRow tabular section "TableWorks".
//
&AtClient
Procedure TableWorkOnActivateRow(Item)
	
	TabularSectionName = "TableWorks";
	DriveClient.SetFilterOnSubordinateTabularSection(ThisObject, "LaborAssignment");
	
EndProcedure

// Procedure - event handler OnStartEdit tabular section Works.
//
&AtClient
Procedure WorksOnStartEdit(Item, NewRow, Copy)
	
	TabularSectionName = "Works";
	If NewRow Then
		
		DriveClient.AddConnectionKeyToTabularSectionLine(ThisObject);
		DriveClient.SetFilterOnSubordinateTabularSection(ThisObject, "Materials");
		
	EndIf;
	
	TabularSectionRow = Items.Works.CurrentData;
	If TabularSectionRow <> Undefined Then
		Items.WorkMaterials.Enabled = Not TabularSectionRow.ProductsTypeService;
	EndIf;
	
	// AutomaticDiscounts
	If NewRow AND Copy Then
		Item.CurrentData.AutomaticDiscountsPercent = 0;
		Item.CurrentData.AutomaticDiscountAmount = 0;
		CalculateAmountInTabularSectionLine("Works", Item.CurrentData);
	EndIf;
	// End AutomaticDiscounts

EndProcedure

// Procedure - event handler BeforeAddStart tabular section "Works".
//
&AtClient
Procedure WorksBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	If Copy Then
		RecalculateSubtotal();
		RowCopyWorks = True;
	EndIf;
	
EndProcedure

// Procedure - event handler OnChange tabular section "Works".
//
&AtClient
Procedure WorksOnChange(Item)
	
	If RowCopyWorks = Undefined OR Not RowCopyWorks Then
		RecalculateSubtotal();
	Else
		RowCopyWorks = False;
	EndIf;
	
EndProcedure

// Procedure - event handler OnEditEnd of tabular section Works.
//
&AtClient
Procedure WorksOnEditEnd(Item, NewRow, CancelEdit)
	
	// Payment calendar.
	RecalculatePaymentCalendar();
	
	// Set filter for TableWorks by Product type.
	FilterStructure = New Structure;
	FilterStructure.Insert("ProductsTypeService", False);
	FixedFilterStructure = New FixedStructure(FilterStructure);
	Items.TableWorks.RowFilter = FixedFilterStructure;
	
EndProcedure

// Procedure - event handler BeforeDelete tabular section Works.
//
&AtClient
Procedure WorksBeforeDelete(Item, Cancel)

	TabularSectionName = "Works";
	DriveClient.DeleteRowsOfSubordinateTabularSection(ThisObject, "Materials");
	DriveClient.DeleteRowsOfSubordinateTabularSection(ThisObject, "LaborAssignment");
	
	TabularSectionRow = Items.Works.CurrentData;
	If TabularSectionRow <> Undefined Then
		Items.WorkMaterials.Enabled = Not TabularSectionRow.ProductsTypeService;
	EndIf;
	
EndProcedure

// Procedure - event handler AfterDeleteRow tabular section Works.
//
&AtClient
Procedure WorksAfterDeleteRow(Item)
	
	// Payment calendar.
	RecalculatePaymentCalendar();
	RecalculateSubtotal();
	
	// AutomaticDiscounts.
	ClearCheckboxDiscountsAreCalculatedClient("DeleteRow");
	
EndProcedure

// Procedure - event handler OnChange of the Products input field.
//
&AtClient
Procedure WorksProductsOnChange(Item)
	
	TabularSectionRow = Items.Works.CurrentData;
	
	TabularSectionName = "Works";
	DriveClient.DeleteRowsOfSubordinateTabularSection(ThisObject, "Materials");
	DriveClient.DeleteRowsOfSubordinateTabularSection(ThisObject, "LaborAssignment");
	TabularSectionRow.Materials = "";
	TabularSectionRow.Performers = "";
	
	StructureData = New Structure;
	StructureData.Insert("Company", Object.Company);
	StructureData.Insert("Products", TabularSectionRow.Products);
	StructureData.Insert("Characteristic", TabularSectionRow.Characteristic);
	StructureData.Insert("ProcessingDate", Object.Date);
	StructureData.Insert("TimeNorm", 1);
	StructureData.Insert("VATTaxation", Object.VATTaxation);
	
	StructureData.Insert("DocumentCurrency", Object.DocumentCurrency);
	StructureData.Insert("AmountIncludesVAT", Object.AmountIncludesVAT);
	StructureData.Insert("PriceKind", Object.PriceKind);
	StructureData.Insert("Factor", 1);
	StructureData.Insert("DiscountMarkupKind", Object.DiscountMarkupKind);
	
	// DiscountCards
	StructureData.Insert("DiscountCard", Object.DiscountCard);
	StructureData.Insert("DiscountPercentByDiscountCard", Object.DiscountPercentByDiscountCard);		
	// End DiscountCards

	StructureData = GetDataProductsOnChange(StructureData);
	
	TabularSectionRow.Quantity = 1;
	TabularSectionRow.StandardHours = StructureData.TimeNorm;
	TabularSectionRow.VATRate = StructureData.VATRate;
	TabularSectionRow.Specification = StructureData.Specification;
	TabularSectionRow.Content = "";
	
	If ValueIsFilled(TabularSectionRow.Specification) Then
		
		FillByBillsOfMaterialsAtServer(TabularSectionRow.Specification);
		
	EndIf;
	
	If (ValueIsFilled(Object.PriceKind) AND StructureData.Property("Price")) OR StructureData.Property("Price") Then
		TabularSectionRow.Price = StructureData.Price;
		TabularSectionRow.DiscountMarkupPercent = StructureData.DiscountMarkupPercent;
	EndIf;
	
	TabularSectionRow.ProductsTypeService = StructureData.IsService;
	
	If TabularSectionRow <> Undefined Then
		Items.WorkMaterials.Enabled = Not TabularSectionRow.ProductsTypeService;
	EndIf;
	
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
	
	If ValueIsFilled(Object.PriceKind) Then
		StructureData.Insert("DocumentCurrency", Object.DocumentCurrency);
		StructureData.Insert("AmountIncludesVAT", Object.AmountIncludesVAT);
		StructureData.Insert("PriceKind", Object.PriceKind);
		StructureData.Insert("Factor", 1);
		StructureData.Insert("DiscountMarkupKind", Object.DiscountMarkupKind);
	EndIf;
	
	// DiscountCards
	StructureData.Insert("DiscountCard", Object.DiscountCard);
	StructureData.Insert("DiscountPercentByDiscountCard", Object.DiscountPercentByDiscountCard);		
	// End DiscountCards

	StructureData = GetDataProductsOnChange(StructureData);
	
	TabularSectionRow.StandardHours = StructureData.TimeNorm;
	TabularSectionRow.Quantity = 1;
	TabularSectionRow.VATRate = StructureData.VATRate;
	TabularSectionRow.Content = "";
	TabularSectionRow.Specification = StructureData.Specification;
	
	If ValueIsFilled(Object.PriceKind) OR StructureData.Property("Price") Then
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
	
	TabularSectionRow = Items.Works.CurrentData;
	
	If ValueIsFilled(TabularSectionRow.WorkKind) Then
		
		FillWithBundledService(TabularSectionRow.WorkKind);
		
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

&AtClient
Procedure WorksStandardHoursOnChange(Item)
	
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
	If TabularSectionRow.Quantity <> 0 AND TabularSectionRow.StandardHours <> 0 Then
		TabularSectionRow.Price = TabularSectionRow.Amount / (TabularSectionRow.Quantity * TabularSectionRow.StandardHours);
	EndIf;
	
	// Discount.
	If TabularSectionRow.DiscountMarkupPercent = 100 Then
		TabularSectionRow.Price = 0;
	ElsIf TabularSectionRow.DiscountMarkupPercent <> 0 AND TabularSectionRow.Quantity <> 0 AND  TabularSectionRow.StandardHours <> 0 Then
		TabularSectionRow.Price = TabularSectionRow.Amount / ((1 - TabularSectionRow.DiscountMarkupPercent / 100) * TabularSectionRow.Quantity * TabularSectionRow.StandardHours);
	EndIf;
	
	// VAT amount.
	CalculateVATSUM(TabularSectionRow);
	
	// Total.
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
	// Payment calendar.
	RecalculatePaymentCalendar();
	
	// AutomaticDiscounts.
	ClearCheckboxDiscountsAreCalculatedClient("CalculateAmountInTabularSectionLine", "Amount");
	
	TabularSectionRow.AutomaticDiscountsPercent = 0;
	TabularSectionRow.AutomaticDiscountAmount = 0;
	TabularSectionRow.TotalDiscountAmountIsMoreThanAmount = False;
	// End AutomaticDiscounts
	
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

#EndRegion

#Region MaterialsFormTableItemsEventHandlers

// Procedure - event handler BeforeAddStart tabular section Materials.
//
&AtClient
Procedure MaterialsBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	TabularSectionName = "Works";
	Cancel = DriveClient.BeforeAddToSubordinateTabularSection(ThisObject, Item.Name);
	
EndProcedure

&AtClient
Procedure MaterialsBeforeDeleteRow(Item, Cancel)
	
	// Serial numbers
	CurrentData = Items.Materials.CurrentData;
	WorkWithSerialNumbersClientServer.DeleteSerialNumbersByConnectionKey(Object.SerialNumbersMaterials,
		CurrentData, "ConnectionKeySerialNumbers", UseSerialNumbersBalance);
	
EndProcedure

// Procedure - event handler OnStartEdit tabular section Materials.
//
&AtClient
Procedure MaterialsOnStartEdit(Item, NewRow, Copy)
	
	TabularSectionName = "Works";
	If NewRow Then
		DriveClient.AddConnectionKeyToSubordinateTabularSectionLine(ThisObject, Item.Name);
	EndIf;
	
	If Item.CurrentItem.Name = "OWMaterialsSerialNumbers" Then
		OpenSelectionMaterialsSerialNumbers();
	EndIf;

EndProcedure

&AtClient
Procedure MaterialsSerialNumbersStartChoice(Item, ChoiceData, StandardProcessing)
	StandardProcessing = False;
	OpenSelectionMaterialsSerialNumbers();
EndProcedure

// Procedure - event handler OnChange of the Products input field.
//
&AtClient
Procedure MaterialsProductsOnChange(Item)
	
	TabularSectionRow = Items.Materials.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("Products", TabularSectionRow.Products);
	
	StructureData = MaterialsGetDataProductsOnChange(StructureData);
	
	TabularSectionRow.MeasurementUnit = StructureData.MeasurementUnit;
	TabularSectionRow.Quantity = 1;
	TabularSectionRow.Reserve = 0;
	
EndProcedure

// Procedure - event handler OnChange input field Reserve.
//
&AtClient
Procedure MaterialsReserveOnChange(Item)
	
	TabularSectionRow = Items.Materials.CurrentData;
	
EndProcedure

#EndRegion

#Region PerformersFormTableItemsEventHandlers

// Procedure - event handler BeforeAddStart of tabular section Performers.
//
&AtClient
Procedure PerformersBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	TabularSectionName = "TableWorks";
	Cancel = DriveClient.BeforeAddToSubordinateTabularSection(ThisObject, Item.Name);
	
EndProcedure

// Procedure - event handler OnStartEdit tabular section Performers.
//
&AtClient
Procedure PerformersOnStartEdit(Item, NewRow, Copy)
	
	TabularSectionName = "TableWorks";
	If NewRow Then
		DriveClient.AddConnectionKeyToSubordinateTabularSectionLine(ThisObject, Item.Name);
	EndIf;
	
EndProcedure

// Procedure - event handler OnChange input field Employee.
//
&AtClient
Procedure PerformersEmployeeOnChange(Item)
	
	TabularSectionRow = Items.LaborAssignment.CurrentData;
	TabularSectionRow.LPR = 1;
	
EndProcedure

#EndRegion

#Region ConsumerMaterialsFormTableItemsEventHandlers

// Procedure - event handler OnChange of the Products input field.
//
&AtClient
Procedure OWCustomerMaterialsProductsOnChange(Item)
	
	TabularSectionRow = Items.ConsumerMaterials.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("Company", ParentCompany);
	StructureData.Insert("Products", TabularSectionRow.Products);
	StructureData.Insert("Characteristic", TabularSectionRow.Characteristic);
	
	StructureData = GetDataProductsOnChange(StructureData);
	
	TabularSectionRow.MeasurementUnit = StructureData.MeasurementUnit;
	TabularSectionRow.Quantity = 1;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

#Region CommandFormPanelsActionProcedures

&AtClient
Procedure SearchByBarcodeEnd(Result, AdditionalParameters) Export
	
	CurBarcode = ?(Result = Undefined, AdditionalParameters.CurBarcode, Result);
	
	If Not IsBlankString(CurBarcode) Then
		BarcodesReceived(New Structure("Barcode, Quantity", CurBarcode, 1));
	EndIf;
	
	// Payment calendar.
	RecalculatePaymentCalendar();
	
EndProcedure

// Gets the weight for tabular section row.
//
&AtClient
Procedure GetWeightForTabularSectionRow(TabularSectionRow)
	
	If TabularSectionRow = Undefined Then
		
		ShowMessageBox(Undefined, NStr("en = 'Select a line to get the weight for.'"));
		
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
	
	If TypeOf(Result) = Type("Array") AND Result.Count() > 0 Then
		BarcodesReceived(Result);
	EndIf;
	
EndProcedure

// End Peripherals

// Procedure - command handler of the tabular section command panel.
//
&AtClient
Procedure FillBySpecification(Command)
	
	CurrentTSLine = Items.Works.CurrentData;
	
	If CurrentTSLine = Undefined Then
		CommonUseClientServer.MessageToUser(NStr("en = 'Select a line containing BOM in the section above.'"));
		Return;
	EndIf;
	
	If Not ValueIsFilled(CurrentTSLine.Specification) Then
		DriveClient.ShowMessageAboutError(Object, NStr("en = 'BOM is not specified'"));
		Return;
	EndIf;
	
	SearchResult = Object.Materials.FindRows(New Structure("ConnectionKey", Items.Materials.RowFilter["ConnectionKey"]));
	
	If SearchResult.Count() <> 0 Then
		
		Response = Undefined;
		
		ShowQueryBox(New NotifyDescription("FillBySpecificationEnd", ThisObject, New Structure("SearchResult", SearchResult)),
			NStr("en = 'This will overwrite the list of inventory. Do you want to continue?'"), QuestionDialogMode.YesNo, 0);
		Return;
		
	EndIf;
	
	FillBySpecificationFragment(SearchResult);
	
EndProcedure

&AtClient
Procedure FillBySpecificationEnd(Result, AdditionalParameters) Export
	
	SearchResult = AdditionalParameters.SearchResult;
	
	Response = Result;
	
	If Response = DialogReturnCode.No Then
		Return;
	EndIf;
	
	FillBySpecificationFragment(SearchResult);
	
EndProcedure

&AtClient
Procedure FillBySpecificationFragment(Val SearchResult)
	
	Var IndexOfDeletion, SearchString, FilterStr, CurrentTSLine;
	
	Modified = True;
	
	For Each SearchString In SearchResult Do
		IndexOfDeletion = Object.Materials.IndexOf(SearchString);
		Object.Materials.Delete(IndexOfDeletion);
	EndDo;
	
	CurrentTSLine = Items.Works.CurrentData;
	FillByBillsOfMaterialsAtServer(CurrentTSLine.Specification);
	
	FilterStr = New FixedStructure("ConnectionKey", Items.Materials.RowFilter["ConnectionKey"]);
	Items.Materials.RowFilter = FilterStr;
	
EndProcedure

// Procedure - fill button handler by all BillsOfMaterials of tabular field Works
&AtClient
Procedure FillMaterialsFromAllBillsOfMaterials(Command)
	
	If Not Object.Works.Count() > 0 Then
		CommonUseClientServer.MessageToUser(NStr("en = 'Please fill the works list.'"),,,"Works");
		Return;
	EndIf;
	
	If Object.Materials.Count() > 0 Then
		
		Response = Undefined;
		ShowQueryBox(New NotifyDescription("FillMaterialsFromAllBillsOfMaterialsEnd", ThisObject),
			NStr("en = 'This will overwrite the list of inventory. Do you want to continue?'"), QuestionDialogMode.YesNo, 0);
		Return;
		
	EndIf;
	
	FillMaterialsFromAllBillsOfMaterialsFragment();
	
EndProcedure

&AtClient
Procedure FillMaterialsFromAllBillsOfMaterialsEnd(Result, AdditionalParameters) Export
	
	Response = Result;
	
	If Response = DialogReturnCode.No Then
		Return;
	EndIf;
	
	FillMaterialsFromAllBillsOfMaterialsFragment();
	
EndProcedure

&AtClient
Procedure FillMaterialsFromAllBillsOfMaterialsFragment()
	
	Modified = True;
	
	Object.Materials.Clear();
	
	FillMaterialsByAllBillsOfMaterialsAtServer();
	
	// For the WEB we will repeat pick, what it is correct to display the following PM
	TabularSectionName = "Works";
	DriveClient.SetFilterOnSubordinateTabularSection(ThisObject, "Materials");
	DriveClient.SetFilterOnSubordinateTabularSection(ThisObject, "LaborAssignment");
	
EndProcedure

// Procedure - command handler of the tabular section command panel.
//
&AtClient
Procedure FillByTeamsForCurrentWorks(Command)
	
	TabularSectionName = "TableWorks";
	Cancel = DriveClient.BeforeAddToSubordinateTabularSection(ThisObject, TabularSectionName);
	If Cancel Then
		Return;
	EndIf;
	
	CurrentTSLine = Items.TableWorks.CurrentData;
	If Not ValueIsFilled(CurrentTSLine.Products) Then
		DriveClient.ShowMessageAboutError(Object, NStr("en = 'Work is not specified'"));
		Return;
	EndIf;
	
	OpenParameters = New Structure;
	OpenParameters.Insert("MultiselectList", True);
	ArrayOfTeams = Undefined;

	OpenForm("Catalog.Teams.ChoiceForm", OpenParameters,,,,, New NotifyDescription("FillByTeamsForCurrentWorksEnd1", ThisObject));
	
EndProcedure

&AtClient
Procedure FillByTeamsForCurrentWorksEnd1(Result, AdditionalParameters) Export
	
	ArrayOfTeams = Result;
	If ArrayOfTeams = Undefined Then
		Return;
	EndIf;
	
	SearchResult = Object.LaborAssignment.FindRows(New Structure("ConnectionKey", Items.LaborAssignment.RowFilter["ConnectionKey"]));
	
	If SearchResult.Count() <> 0 Then
		Response = Undefined;
		
		ShowQueryBox(New NotifyDescription("FillByTeamsForCurrentWorksEnd", ThisObject, New Structure("ArrayOfTeams, SearchResult", ArrayOfTeams, SearchResult)), NStr("en = 'This will overwrite the list of assignees for the current work. Do you want to continue?'"),
		QuestionDialogMode.YesNo, 0);
		Return;
	EndIf;
	
	FillByTeamsForCurrentWorksFragment(ArrayOfTeams, SearchResult);
	
EndProcedure

&AtClient
Procedure FillByTeamsForCurrentWorksEnd(Result, AdditionalParameters) Export
	
	ArrayOfTeams = AdditionalParameters.ArrayOfTeams;
	SearchResult = AdditionalParameters.SearchResult;
	
	Response = Result;
	If Response = DialogReturnCode.No Then
		Return;
	EndIf;
	
	FillByTeamsForCurrentWorksFragment(ArrayOfTeams, SearchResult);
	
EndProcedure

&AtClient
Procedure FillByTeamsForCurrentWorksFragment(Val ArrayOfTeams, Val SearchResult)
	
	Var IndexOfDeletion, PerformersConnectionKey, SearchString, FilterStr;
	
	For Each SearchString In SearchResult Do
		IndexOfDeletion = Object.LaborAssignment.IndexOf(SearchString);
		Object.LaborAssignment.Delete(IndexOfDeletion);
	EndDo;
	
	PerformersConnectionKey = Items.LaborAssignment.RowFilter["ConnectionKey"];
	FillTabularSectionPerformersByTeamsAtServer(ArrayOfTeams, PerformersConnectionKey);
	
	FilterStr = New FixedStructure("ConnectionKey", Items.LaborAssignment.RowFilter["ConnectionKey"]);
	Items.LaborAssignment.RowFilter = FilterStr;
	
EndProcedure

// Procedure - command handler of the tabular section command panel.
//
&AtClient
Procedure FillByTeamsForAllWorks(Command)
	
	TabularSectionName = "TableWorks";
	Cancel = DriveClient.BeforeAddToSubordinateTabularSection(ThisObject, TabularSectionName);
	If Cancel Then
		Return;
	EndIf;
	
	OpenParameters = New Structure;
	OpenParameters.Insert("MultiselectList", True);
	ArrayOfTeams = Undefined;

	OpenForm("Catalog.Teams.ChoiceForm", OpenParameters,,,,, New NotifyDescription("FillByTeamsForAllWorksEnd1", ThisObject));
	
EndProcedure

&AtClient
Procedure FillByTeamsForAllWorksEnd1(Result, AdditionalParameters) Export
	
	ArrayOfTeams = Result;
	If ArrayOfTeams = Undefined Then
		Return;
	EndIf;
	
	If Object.LaborAssignment.Count() <> 0 Then
		Response = Undefined;
		
		ShowQueryBox(New NotifyDescription("FillByTeamsForAllWorksEnd", ThisObject, New Structure("ArrayOfTeams", ArrayOfTeams)),
			NStr("en = 'This will overwrite the list of assignees. Do you want to continue?'"), QuestionDialogMode.YesNo, 0);
		Return;
	EndIf;
	
	FillByTeamsForAllWorksFragment(ArrayOfTeams);
	
EndProcedure

&AtClient
Procedure FillByTeamsForAllWorksEnd(Result, AdditionalParameters) Export
	
	ArrayOfTeams = AdditionalParameters.ArrayOfTeams;
	
	Response = Result;
	If Response = DialogReturnCode.No Then
		Return;
	EndIf;
	
	FillByTeamsForAllWorksFragment(ArrayOfTeams);
	
EndProcedure

&AtClient
Procedure FillByTeamsForAllWorksFragment(Val ArrayOfTeams)
	
	Var FilterStr;
	
	Object.LaborAssignment.Clear();
	
	FillTabularSectionPerformersByTeamsAtServer(ArrayOfTeams);
	
	FilterStr = New FixedStructure("ConnectionKey", Items.LaborAssignment.RowFilter["ConnectionKey"]);
	Items.LaborAssignment.RowFilter = FilterStr;
	
EndProcedure

// Procedure - command handler DocumentSetup.
//
&AtClient
Procedure DocumentSetup(Command)
	
	// 1. Form parameter structure to fill "Document setting" form.
	ParametersStructure = New Structure;
	ParametersStructure.Insert("WorkKindPositionInWorkOrder", Object.WorkKindPosition);
	ParametersStructure.Insert("WereMadeChanges", False);
	
	StructureDocumentSetting = Undefined;
	
	OpenForm("CommonForm.DocumentSetup", ParametersStructure,,,,, New NotifyDescription("DocumentSettingEnd", ThisObject));
	
EndProcedure

&AtClient
Procedure DocumentSettingEnd(Result, AdditionalParameters) Export
	
	// 2. Open "Setting document" form.
	StructureDocumentSetting = Result;
	
	// 3. Apply changes made in "Document setting" form.
	If TypeOf(StructureDocumentSetting) = Type("Structure") AND StructureDocumentSetting.WereMadeChanges Then
		
		Object.WorkKindPosition		= StructureDocumentSetting.WorkKindPositionInWorkOrder;
		
		SetVisibleFromUserSettings();
		
	EndIf;
	
EndProcedure

// Procedure - event handler Action of the GetWeight command
//
&AtClient
Procedure GetWeight(Command)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	GetWeightForTabularSectionRow(TabularSectionRow);
	
EndProcedure

#Region ChangeReserveProducts

// Procedure - command handler FillByBalance submenu ChangeReserve.
//
&AtClient
Procedure ChangeGoodsReserveFillByBalances(Command)
	
	If Object.Inventory.Count() = 0 Then
		CommonUseClientServer.MessageToUser(NStr("en = 'There are no products to reserve.'"));
		Return;
	EndIf;
	
	WOGoodsFillColumnReserveByBalancesAtServer();
	
EndProcedure

// Procedure - command handler FillByReserve of the ChangeReserve submenu.
//
&AtClient
Procedure ChangeGoodsReserveFillByReserves(Command)
	
	If Object.Inventory.Count() = 0 Then
		CommonUseClientServer.MessageToUser(NStr("en = 'There are no products to reserve.'"));
		Return;
	EndIf;
	
	WOGoodsFillColumnReserveByReservesAtServer();
	
EndProcedure

// Procedure - command handler ClearReserve of the ChangeReserve submenu.
//
&AtClient
Procedure ChangeProductsReserveClearReserve(Command)
	
	If Object.Inventory.Count() = 0 Then
		CommonUseClientServer.MessageToUser(NStr("en = 'There is nothing to clear.'"));
		Return;
	EndIf;
	
	For Each TabularSectionRow In Object.Inventory Do
		
		If TabularSectionRow.ProductsTypeInventory Then
			TabularSectionRow.Reserve = 0;
		EndIf;
		
	EndDo;
	
EndProcedure

#EndRegion

#EndRegion

// Procedure - event handler Action of the Pick command
//
&AtClient
Procedure InventoryPick(Command)
	
	TabularSectionName	= "Inventory";
	SelectionMarker		= "Inventory";
	DocumentPresentaion	= NStr("en = 'work order'");
	SelectionParameters	= DriveClient.GetSelectionParameters(ThisObject, TabularSectionName, DocumentPresentaion, True, True, True);
	SelectionParameters.Insert("Company",			ParentCompany);
	SelectionParameters.Insert("StructuralUnit",	Object.StructuralUnitReserve);
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
Procedure WorkSelection(Command)
	
	TabularSectionName			= "Works";
	SelectionMarker				= "Works";
	PickupForMaterialsInWorks	= False;
	
	DocumentPresentaion	= NStr("en = 'work order'");
	SelectionParameters	= DriveClient.GetSelectionParameters(ThisObject, TabularSectionName, DocumentPresentaion, False, False, False);
	SelectionParameters.Insert("Company",			ParentCompany);
	SelectionParameters.Insert("StructuralUnit",	Object.StructuralUnitReserve);
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
Procedure MaterialsPick(Command)
	
	TabularSectionName = "ConsumerMaterials";
	SelectionMarker = "ConsumersInventory";
	
	DocumentPresentaion	= "work order";
	SelectionParameters	= DriveClient.GetSelectionParameters(ThisObject, TabularSectionName, DocumentPresentaion, False, False, True);
	SelectionParameters.Insert("Company",			ParentCompany);
	SelectionParameters.Insert("StructuralUnit",	Object.InventoryWarehouse);
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
Procedure WOMaterialsPick(Command)
	
	TabularSectionName = "Materials";
	SelectionMarker = "Works";
	PickupForMaterialsInWorks = True;
	
	DocumentPresentaion	= "work order";
	SelectionParameters	= DriveClient.GetSelectionParameters(ThisObject, TabularSectionName, DocumentPresentaion, False, False, True);
	SelectionParameters.Insert("Company",			ParentCompany);
	SelectionParameters.Insert("StructuralUnit",	Object.InventoryWarehouse);
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
Procedure CloseOrder(Command)
	
	If Modified Or Not Object.Posted Then
		ShowQueryBox(New NotifyDescription("CloseOrderEnd", ThisObject),
			NStr("en = 'Data is still not recorded. Completion of order is possible only after data is recorded.
					|Data will be written.'"), QuestionDialogMode.OKCancel);
		Return;
	EndIf;
		
	CloseOrderFragment();
	SetVisibleAndEnabledFromState();
	
EndProcedure

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
Procedure SearchByBarcode(Command)
	
	CurBarcode = "";
	ShowInputValue(New NotifyDescription("SearchByBarcodeEnd", ThisObject, New Structure("CurBarcode", CurBarcode)), CurBarcode, NStr("en = 'Enter barcode'"));
	
EndProcedure

#Region ChangeReserveMaterials

&AtClient
Procedure WOChangeMaterialsReserveFillByBalancesForAllEnd(Result, AdditionalParameters) Export
	
	Response = Result;
	If Response = DialogReturnCode.No Then
		Return;
	EndIf;
	
	WOChangeMaterialsReserveFillByBalancesForAllFragment();
	
EndProcedure

&AtClient
Procedure WOChangeMaterialsReserveFillByBalancesForAllFragment()
	
	MaterialsFillColumnReserveByBalancesAtServer();
	
	DriveClient.SetFilterOnSubordinateTabularSection(ThisObject, "Materials");
	
EndProcedure

&AtClient
Procedure WOChangeMaterialsReserveFillByReservesForAllEnd(Result, AdditionalParameters) Export
	
	Response = Result;
	If Response = DialogReturnCode.No Then
		Return;
	EndIf;
	
	WOChangeMaterialsReserveFillByReservesForAllFragment();
	
EndProcedure

&AtClient
Procedure WOChangeMaterialsReserveFillByReservesForAllFragment()
	
	MaterialsFillColumnReserveByReservesAtServer();
	
	DriveClient.SetFilterOnSubordinateTabularSection(ThisObject, "Materials");
	
EndProcedure

&AtClient
Procedure ChangeMaterialsReserveClearReserveForAllEnd(Result, AdditionalParameters) Export
	
	Response = Result;
	If Response = DialogReturnCode.No Then
		Return;
	EndIf;
	
	WOChangeMaterialsReserveClearReserveForAllFragment();
	
EndProcedure

&AtClient
Procedure WOChangeMaterialsReserveClearReserveForAllFragment()
	
	Var TabularSectionRow;
	
	For Each TabularSectionRow In Object.Materials Do
		TabularSectionRow.Reserve = 0;
	EndDo;
	
EndProcedure

// Procedure - command handler FillByBalance submenu ChangeReserve.
//
&AtClient
Procedure ChangeMaterialsReserveFillByBalances(Command)
	
	CurrentTSLine = Items.Works.CurrentData;
	
	If CurrentTSLine = Undefined Then
		CommonUseClientServer.MessageToUser(NStr("en = 'There is nothing to reserve.'"));
		Return;
	EndIf;
	
	MaterialsConnectionKey = Items.Materials.RowFilter["ConnectionKey"];
	SearchResult = Object.Materials.FindRows(New Structure("ConnectionKey", MaterialsConnectionKey));
	If SearchResult.Count() = 0 Then
		CommonUseClientServer.MessageToUser(NStr("en = 'There is nothing to reserve.'"));
		Return;
	EndIf;
	
	MaterialsFillColumnReserveByBalancesAtServer(MaterialsConnectionKey);
	
	DriveClient.SetFilterOnSubordinateTabularSection(ThisObject, "Materials");
	
EndProcedure

// Procedure - command handler FillByBalance submenu ChangeReserve.
//
&AtClient
Procedure ChangeMaterialsReserveFillByBalancesForAll(Command)
	
	If Object.Materials.Count() = 0 Then
		CommonUseClientServer.MessageToUser(NStr("en = 'There is nothing to reserve.'"));
		Return;
	EndIf;
	
	If Object.Works.Count() > 1 Then
		Response = Undefined;
		ShowQueryBox(New NotifyDescription("WOChangeMaterialsReserveFillByBalancesForAllEnd", ThisObject),
			NStr("en = 'This will overwrite the Reserve column in the list of inventory. Do you want to continue?'"), QuestionDialogMode.YesNo, 0);
		Return;
	EndIf;
	
	WOChangeMaterialsReserveFillByBalancesForAllFragment();
	
EndProcedure

// Procedure - command handler FillByReserve of the ChangeReserve submenu.
//
&AtClient
Procedure ChangeMaterialsReserveFillByReserves(Command)
	
	CurrentTSLine = Items.Works.CurrentData;
	
	If CurrentTSLine = Undefined Then
		CommonUseClientServer.MessageToUser(NStr("en = 'Select a line in the section above.'"));
		Return;
	EndIf;
	
	MaterialsConnectionKey = Items.Materials.RowFilter["ConnectionKey"];
	SearchResult = Object.Materials.FindRows(New Structure("ConnectionKey", MaterialsConnectionKey));
	If SearchResult.Count() = 0 Then
		CommonUseClientServer.MessageToUser(NStr("en = 'There is nothing to reserve.'"));
		Return;
	EndIf;
	
	MaterialsFillColumnReserveByReservesAtServer(MaterialsConnectionKey);
	
	DriveClient.SetFilterOnSubordinateTabularSection(ThisObject, "Materials");
	
EndProcedure

// Procedure - command handler FillByReserve of the ChangeReserve submenu.
//
&AtClient
Procedure ChangeMaterialsReserveFillByReservesForAll(Command)
	
	If Object.Materials.Count() = 0 Then
		CommonUseClientServer.MessageToUser(NStr("en = 'There is nothing to reserve.'"));
		Return;
	EndIf;
	
	If Object.Works.Count() > 1 Then
		Response = Undefined;
		ShowQueryBox(New NotifyDescription("WOChangeMaterialsReserveFillByReservesForAllEnd", ThisObject),
			NStr("en = 'This will overwrite the Reserve column in the list of inventory. Do you want to continue?'"), QuestionDialogMode.YesNo, 0);
		Return;
	EndIf;
	
	WOChangeMaterialsReserveFillByReservesForAllFragment();
	
EndProcedure

// Procedure - command handler ClearReserve of the ChangeReserve submenu.
//
&AtClient
Procedure ChangeMaterialsReserveClearReserve(Command)
	
	CurrentTSLine = Items.Works.CurrentData;
	
	If CurrentTSLine = Undefined Then
		CommonUseClientServer.MessageToUser(NStr("en = 'Select a line in the section above.'"));
		Return;
	EndIf;
	
	SearchResult = Object.Materials.FindRows(New Structure("ConnectionKey", Items.Materials.RowFilter["ConnectionKey"]));
	If SearchResult.Count() = 0 Then
		CommonUseClientServer.MessageToUser(NStr("en = 'There is nothing to clear.'"));
		Return;
	EndIf;
	
	For Each TabularSectionRow In SearchResult Do
		TabularSectionRow.Reserve = 0;
	EndDo;
	
EndProcedure

// Procedure - command handler ClearReserve of the ChangeReserve submenu.
//
&AtClient
Procedure ChangeMaterialsReserveClearReserveForAll(Command)
	
	If Object.Materials.Count() = 0 Then
		CommonUseClientServer.MessageToUser(NStr("en = 'There is nothing to clear.'"));
		Return;
	EndIf;
	
	If Object.Works.Count() > 1 Then
		Response = Undefined;
		ShowQueryBox(New NotifyDescription("ChangeMaterialsReserveClearReserveForAllEnd", ThisObject),
			NStr("en = 'This will overwrite the Reserve column in the list of materials. Do you want to continue?'"), QuestionDialogMode.YesNo, 0);
		Return;
	EndIf;
	
	WOChangeMaterialsReserveClearReserveForAllFragment();
	
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
		ShowQueryBox(Notify, QueryText, QuestionDialogMode.YesNo);
		
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
	
	PaymentAmount = Object.Inventory.Total("Amount") + Object.Works.Total("Amount");
	PaymentVATAmount = Object.Inventory.Total("VATAmount") + Object.Works.Total("VATAmount");
	
	CurrentRow.PaymentAmount = Round(PaymentAmount * CurrentRow.PaymentPercentage / 100, 2, 1);
	CurrentRow.PaymentVATAmount = Round(PaymentVATAmount * CurrentRow.PaymentPercentage / 100, 2, 1);
	
EndProcedure

// Procedure - event handler OnChange of the PaymentCalendarPaymentAmount input field.
//
&AtClient
Procedure PaymentCalendarPaymentSumOnChange(Item)
	
	CurrentRow = Items.PaymentCalendar.CurrentData;
	
	PaymentAmount = Object.Inventory.Total("Amount") + Object.Works.Total("Amount");
	PaymentVATAmount = Object.Inventory.Total("VATAmount") + Object.Works.Total("VATAmount");
	
	CurrentRow.PaymentPercentage = ?(PaymentAmount = 0, 0, Round(CurrentRow.PaymentAmount / PaymentAmount * 100, 2, 1));
	CurrentRow.PaymentVATAmount = Round(PaymentVATAmount * CurrentRow.PaymentPercentage / 100, 2, 1);
	
EndProcedure

// Procedure - event handler OnChange of the PaymentCalendarPayVATAmount input field.
//
&AtClient
Procedure PaymentCalendarPayVATAmountOnChange(Item)
	
	CurrentRow = Items.PaymentCalendar.CurrentData;
	
	InventoryTotal = Object.Inventory.Total("VATAmount");
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
	
	PaymentAmount = Object.Inventory.Total("Amount") + Object.Works.Total("Amount");
	PaymentVATAmount = Object.Inventory.Total("VATAmount") + Object.Works.Total("VATAmount");
	
	If CurrentRow.PaymentPercentage = 0 Then
		CurrentRow.PaymentPercentage = 100 - Object.PaymentCalendar.Total("PaymentPercentage");
		CurrentRow.PaymentAmount = PaymentAmount - Object.PaymentCalendar.Total("PaymentAmount");
		CurrentRow.PaymentVATAmount = PaymentVATAmount - Object.PaymentCalendar.Total("PaymentVATAmount");
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

#Region AutomaticDiscounts

// Procedure - form command handler CalculateDiscountsMarkups.
//
&AtClient
Procedure CalculateDiscountsMarkups(Command)
	
	If Object.Inventory.Count() = 0 AND Object.Works.Count() = 0 Then
		If Object.DiscountsMarkups.Count() > 0 Then
			Object.DiscountsMarkups.Clear();
		EndIf;
		Return;
	EndIf;
	
	CalculateDiscountsMarkupsClient();
	
EndProcedure

// Procedure - command handler "OpenDiscountInformation" for tabular section "Inventory".
//
&AtClient
Procedure OpenInformationAboutDiscounts(Command)
	
	CurrentData = Items.Inventory.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	OpenInformationAboutDiscountsClient("Inventory")
	
EndProcedure

// Procedure - command handler "OpenDiscountInformation" for tabular section "Works".
//
&AtClient
Procedure OpenInformationAboutDiscountsWorks(Command)
	
	CurrentData = Items.Works.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	OpenInformationAboutDiscountsClient("Works");
	
EndProcedure

// Procedure - event handler Table parts selection Inventory.
//
&AtClient
Procedure InventorySelection(Item, SelectedRow, Field, StandardProcessing)
	
	If (Item.CurrentItem = Items.InventoryAutomaticDiscountPercent OR Item.CurrentItem = Items.InventoryAutomaticDiscountAmount)
		AND Not ReadOnly Then
		
		StandardProcessing = False;
		OpenInformationAboutDiscountsClient("Inventory");
		
	EndIf;
	
EndProcedure

// Procedure - event handler OnStartEdit tabular section Inventory forms.
//
&AtClient
Procedure InventoryOnStartEdit(Item, NewRow, Copy)
	
	// AutomaticDiscounts
	If NewRow AND Copy Then
		Item.CurrentData.AutomaticDiscountsPercent = 0;
		Item.CurrentData.AutomaticDiscountAmount = 0;
		CalculateAmountInTabularSectionLine();
	EndIf;
	// End AutomaticDiscounts
	
	// Serial numbers
	If NewRow AND Copy Then
		Item.CurrentData.ConnectionKey = 0;
		Item.CurrentData.SerialNumbers = "";
	EndIf;
	
	If Item.CurrentItem.Name = "SerialNumbersInventory" Then
		OpenSerialNumbersSelection();
	EndIf;
	
EndProcedure

&AtClient
Procedure InventoryBeforeDeleteRow(Item, Cancel)
	
	// Serial numbers
	CurrentData = Items.Inventory.CurrentData;
	WorkWithSerialNumbersClientServer.DeleteSerialNumbersByConnectionKey(Object.SerialNumbers, CurrentData,, UseSerialNumbersBalance);
	
EndProcedure

&AtClient
Procedure InventorySerialNumbersStartChoice(Item, ChoiceData, StandardProcessing)
	StandardProcessing = False;
	OpenSerialNumbersSelection();
EndProcedure

// Procedure - event handler Table parts selection Works.
//
&AtClient
Procedure ChoiceWorks(Item, SelectedRow, Field, StandardProcessing)
	
	If (Item.CurrentItem = Items.WorksAutomaticDiscountPercent OR Item.CurrentItem = Items.WorksAutomaticDiscountAmount)
		AND Not ReadOnly Then
		
		StandardProcessing = False;
		OpenInformationAboutDiscountsClient("Works");
		
	EndIf;
	
EndProcedure

#EndRegion

#EndRegion

#Region Private

#Region CommonUseProceduresAndFunctions

&AtServer
Function GetDeliveryAttributes(ShippingAddress)
	Return ShippingAddressesServer.GetDeliveryAttributesForAddress(ShippingAddress);
EndFunction

&AtClient
Procedure SetVisibleDeliveryAttributes()
	
	VisibleFlags			= GetFlagsForFormItemsVisible(Object.DeliveryOption);
	DeliveryOptionIsFilled	= ValueIsFilled(Object.DeliveryOption);
	Items.Location.Visible	= DeliveryOptionIsFilled AND NOT VisibleFlags.DeliveryOptionSelfPickup;
	
EndProcedure

&AtServerNoContext
Function GetFlagsForFormItemsVisible(DeliveryOption)
	
	VisibleFlags = New Structure;
	VisibleFlags.Insert("DeliveryOptionLogisticsCompany", (DeliveryOption = Enums.DeliveryOptions.LogisticsCompany));
	VisibleFlags.Insert("DeliveryOptionSelfPickup", (DeliveryOption = Enums.DeliveryOptions.SelfPickup));
	
	Return VisibleFlags;
	
EndFunction

&AtServer
Function GetDeliveryData(Counterparty)
	Return ShippingAddressesServer.GetDeliveryDataForCounterparty(Counterparty);
EndFunction

&AtServer
Procedure RecalculateSubtotal()
	
	SubtotalsTable = Object.Inventory.Unload();
	For Each WorkLine In Object.Works Do
		NewLine = SubtotalsTable.Add();
		FillPropertyValues(NewLine, WorkLine);
		NewLine.Quantity = WorkLine.Quantity * WorkLine.StandardHours;
	EndDo;
	
	Totals = DriveServer.CalculateSubtotal(SubtotalsTable, Object.AmountIncludesVAT, False);
	FillPropertyValues(ThisObject, Totals);
	
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
	If DocumentParameters.Property("ClearDiscountCard") Then
		ClearDiscountCard = True;
	Else
		ClearDiscountCard = False;
	EndIf;
	RecalculationRequiredInventory = DocumentParameters.RecalculationRequiredInventory;
	RecalculationRequiredWork = DocumentParameters.RecalculationRequiredWork;
	
	If Not ContractData.AmountIncludesVAT = Undefined Then
		
		Object.AmountIncludesVAT = ContractData.AmountIncludesVAT;
		
	EndIf;
	
	If ValueIsFilled(Object.Contract) Then 
		
		Object.ExchangeRate = ?(ContractData.SettlementsCurrencyRateRepetition.ExchangeRate = 0, 1, ContractData.SettlementsCurrencyRateRepetition.ExchangeRate);
		Object.Multiplicity = ?(ContractData.SettlementsCurrencyRateRepetition.Multiplicity = 0, 1, ContractData.SettlementsCurrencyRateRepetition.Multiplicity);
		
	EndIf;
	
	If PriceKindChanged Then
		
		Object.PriceKind = ContractData.PriceKind;
		
	EndIf; 
	
	If DiscountKindChanged Then
		
		Object.DiscountMarkupKind = ContractData.DiscountMarkupKind;
		
	EndIf;
	
	If ClearDiscountCard Then
		
		Object.DiscountCard = PredefinedValue("Catalog.DiscountCards.EmptyRef");
		Object.DiscountPercentByDiscountCard = 0;
		
	EndIf;
	
	If Object.DocumentCurrency <> ContractData.SettlementsCurrency Then
		
		Object.BankAccount = Undefined;
		
	EndIf;
	Object.DocumentCurrency = ContractData.SettlementsCurrency;
	
	If OpenFormPricesAndCurrencies Then
		
		WarningText = "";
		If PriceKindChanged OR DiscountKindChanged Then
			
			WarningText = NStr("en = 'The price and discount in the contract with counterparty differ from price and discount in the document. Perhaps you have to refill prices.'") + Chars.LF + Chars.LF;
			
		EndIf;
		
		WarningText = WarningText + NStr("en = 'The settlement currency specified in the contract has changed. It is necessary to check the document currency'");
		
		ProcessChangesOnButtonPricesAndCurrencies(SettlementsCurrencyBeforeChange, True, (PriceKindChanged OR DiscountKindChanged), WarningText);
		
	ElsIf QueryPriceKind Then
		
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
		
		PricesAndCurrency = GenerateLabelPricesAndCurrency(LabelStructure);
		
		If (RecalculationRequiredInventory AND Object.Inventory.Count() > 0)
			OR (RecalculationRequiredWork AND Object.Works.Count() > 0) Then
			
			QuestionText = NStr("en = 'The price and discount in the contract with counterparty differ from price and discount in the document. Recalculate the document according to the contract?'");
			
			NotifyDescription = New NotifyDescription("DefineDocumentRecalculateNeedByContractTerms", ThisObject, DocumentParameters);
			ShowQueryBox(NotifyDescription, QuestionText, QuestionDialogMode.YesNo);
			
		EndIf;
		
	Else
		
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
		
		PricesAndCurrency = GenerateLabelPricesAndCurrency(LabelStructure);
		
	EndIf;
	
EndProcedure

// It receives data set from server for the DateOnChange procedure.
//
&AtServer
Function GetDataDateOnChange(DateBeforeChange, SettlementsCurrency)
	
	DATEDIFF = DriveServer.CheckDocumentNumber(Object.Ref, Object.Date, DateBeforeChange);
	CurrencyRateRepetition = InformationRegisters.ExchangeRates.GetLast(Object.Date, New Structure("Currency", SettlementsCurrency));
	
	StructureData = New Structure;
	StructureData.Insert("DATEDIFF", DATEDIFF);
	StructureData.Insert("CurrencyRateRepetition", CurrencyRateRepetition);
	
	FillVATRateByCompanyVATTaxation();
	SetAccountingPolicyValues();
	
	Return StructureData;
	
EndFunction

// Gets data set from server.
//
&AtServer
Function GetCompanyDataOnChange()
	
	StructureData = New Structure();
	StructureData.Insert("Company", DriveServer.GetCompany(Object.Company));
	StructureData.Insert("BankAccount", Object.Company.BankAccountByDefault);
	StructureData.Insert("BankAccountCashAssetsCurrency", Object.Company.BankAccountByDefault.CashCurrency);
	
	FillVATRateByCompanyVATTaxation();
	SetAccountingPolicyValues();
	
	Return StructureData;
	
EndFunction

// Receives the set of data from the server for the ProductsOnChange procedure.
//
&AtServerNoContext
Function GetDataProductsOnChange(StructureData)
	
	StructureData.Insert("MeasurementUnit", StructureData.Products.MeasurementUnit);
	
	StructureData.Insert("IsService", StructureData.Products.ProductsType = Enums.ProductsTypes.Service);
	StructureData.Insert("IsInventoryItem", StructureData.Products.ProductsType = Enums.ProductsTypes.InventoryItem);
	
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

// It receives data set from server for the CharacteristicOnChange procedure.
//
&AtServerNoContext
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
	
	If StructureData.Property("TimeNorm") Then
		StructureData.TimeNorm = DriveServer.GetWorkTimeRate(StructureData);
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
	
	FillVATRateByVATTaxation();
	
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

// It receives data set from server for the ContractOnChange procedure.
//
&AtServerNoContext
Function GetDataContractOnChange(Date, DocumentCurrency, Contract)
	
	StructureData = New Structure();
	
	StructureData.Insert(
		"SettlementsCurrency",
		Contract.SettlementsCurrency);
	
	StructureData.Insert(
		"SettlementsCurrencyRateRepetition",
		InformationRegisters.ExchangeRates.GetLast(Date, New Structure("Currency", Contract.SettlementsCurrency)));
	
	StructureData.Insert(
		"PriceKind",
		Contract.PriceKind);
	
	StructureData.Insert(
		"DiscountMarkupKind",
		Contract.DiscountMarkupKind);
	
	StructureData.Insert(
		"SettlementsInStandardUnits",
		Contract.SettlementsInStandardUnits);
	
	StructureData.Insert(
		"AmountIncludesVAT",
		?(ValueIsFilled(Contract.PriceKind), Contract.PriceKind.PriceIncludesVAT, Undefined));
	
	Return StructureData;
	
EndFunction

&AtServerNoContext
// Receives the set of data from the server for the ProductsOnChange procedure.
//
Function MaterialsGetDataProductsOnChange(StructureData)
	
	StructureData.Insert("MeasurementUnit", StructureData.Products.MeasurementUnit);
	
	Return StructureData;
	
EndFunction

&AtServer
// Procedure fills the VAT rate in the tabular section
// according to company's taxation system.
// 
Procedure FillVATRateByCompanyVATTaxation()
	
	TaxationBeforeChange = Object.VATTaxation;
	
	Object.VATTaxation = DriveServer.CounterpartyVATTaxation(Object.Counterparty, DriveServer.VATTaxation(Object.Company, Object.Date));
	
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
		Items.PaymentCalendarPaymentVATAmount.Visible = True;
		Items.ListPaymentCalendarVATAmountPayments.Visible = True;
		
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
		
		Items.WorksVATRate.Visible = True;
		Items.WorksAmountVAT.Visible = True;
		Items.WorksTotal.Visible = True;
		Items.DocumentVATAmount.Visible = True;
		
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
		
		Items.InventoryVATRate.Visible = False;
		Items.InventoryVATAmount.Visible = False;
		Items.InventoryAmountTotal.Visible = False;
		Items.PaymentCalendarPaymentVATAmount.Visible = False;
		Items.ListPaymentCalendarVATAmountPayments.Visible = False;
		
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
		
		Items.WorksVATRate.Visible = False;
		Items.WorksAmountVAT.Visible = False;
		Items.WorksTotal.Visible = False;
		Items.DocumentVATAmount.Visible = False;
		
		For Each TabularSectionRow In Object.Works Do
		
			TabularSectionRow.VATRate = DefaultVATRate;
			TabularSectionRow.VATAmount = 0;
			TabularSectionRow.Total = TabularSectionRow.Amount;
			
		EndDo;
		
	EndIf;
	
EndProcedure

&AtServerNoContext
// It receives data set from the server for the StructuralUnitOnChange procedure.
//
Function GetDataStructuralUnitOnChange(StructureData)
	
	If StructureData.Department.TransferSource.StructuralUnitType = Enums.BusinessUnitsTypes.Warehouse
		OR StructureData.Department.TransferSource.StructuralUnitType = Enums.BusinessUnitsTypes.Department Then
	
		StructureData.Insert("InventoryStructuralUnit", StructureData.Department.TransferSource);
		StructureData.Insert("CellInventory", StructureData.Department.TransferSourceCell);

	Else
		
		StructureData.Insert("InventoryStructuralUnit", Undefined);
		StructureData.Insert("CellInventory", Undefined);
		
	EndIf;
	
	Return StructureData;
	
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
Procedure CalculateAmountInTabularSectionLine(TabularSectionName = "Inventory", TabularSectionRow = Undefined, ColumnTS = Undefined)
	
	If TabularSectionRow = Undefined Then
		TabularSectionRow = Items[TabularSectionName].CurrentData;
	EndIf;
	
	// Amount.
	TabularSectionRow.Amount = TabularSectionRow.Quantity * TabularSectionRow.Price;
	
	If TabularSectionName = "Works" Then
		TabularSectionRow.Amount = TabularSectionRow.Amount * TabularSectionRow.StandardHours;
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
	
	RecalculateSubtotal();
	
	// AutomaticDiscounts.
	ClearCheckboxDiscountsAreCalculatedClient("CalculateAmountInTabularSectionLine");
	
	TabularSectionRow.AutomaticDiscountsPercent = 0;
	TabularSectionRow.AutomaticDiscountAmount = 0;
	TabularSectionRow.TotalDiscountAmountIsMoreThanAmount = False;
	// End AutomaticDiscounts
	
	// Serial numbers
	If UseSerialNumbersBalance <> Undefined AND TabularSectionName = "Inventory" Then
		WorkWithSerialNumbersClientServer.UpdateSerialNumbersQuantity(Object, TabularSectionRow);
	EndIf;
	
EndProcedure

// Procedure recalculates amounts in the payment calendar.
//
&AtClient
Procedure RecalculatePaymentCalendar()
	
	PaymentAmount = Object.Inventory.Total("Amount") + Object.Works.Total("Amount");
	PaymentVATAmount = Object.Inventory.Total("VATAmount") + Object.Works.Total("VATAmount");
	
	For Each CurRow In Object.PaymentCalendar Do
		CurRow.PaymentAmount = Round(PaymentAmount * CurRow.PaymentPercentage / 100, 2, 1);
		CurRow.PaymentVATAmount = Round(PaymentVATAmount * CurRow.PaymentPercentage / 100, 2, 1);
	EndDo;
	
EndProcedure

&AtClient
// Recalculates the exchange rate and exchange rate multiplier of
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
			NStr("en = 'The exchange rate at the document date is (%1).
					|Do you want to apply this rate instead of (%2)?'"), 
			CurrencyRateInLetters, 
			RateNewCurrenciesInLetters);
			
		AdditionalParameters = New Structure;
		AdditionalParameters.Insert("NewExchangeRate",	NewExchangeRate);
		AdditionalParameters.Insert("NewRatio",			NewRatio);
		
		NotifyDescription = New NotifyDescription("DefineNewExchangeRatesettingNeed", ThisObject, AdditionalParameters);
		ShowQueryBox(NotifyDescription, QuestionText, QuestionDialogMode.YesNo);
		
	EndIf;
	
EndProcedure

// Procedure recalculates in the document tabular section after making
// changes in the "Prices and currency" form. The columns are
// recalculated as follows: price, discount, amount, VAT amount, total amount.
//
&AtClient
Procedure ProcessChangesOnButtonPricesAndCurrencies(Val SettlementsCurrencyBeforeChange, RecalculatePrices = False, RefillPrices = False, WarningText = "")
	
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
	ParametersStructure.Insert("RefillPrices", RefillPrices);
	ParametersStructure.Insert("RecalculatePrices", RecalculatePrices);
	ParametersStructure.Insert("WereMadeChanges", False);
	ParametersStructure.Insert("PriceKind", Object.PriceKind);
	ParametersStructure.Insert("DiscountKind", Object.DiscountMarkupKind);
	ParametersStructure.Insert("DiscountCard", Object.DiscountCard);
	ParametersStructure.Insert("WarningText", WarningText);
	
	NotifyDescription = New NotifyDescription("OpenPricesAndCurrencyFormEnd", ThisObject, New Structure("SettlementsCurrencyBeforeChange", SettlementsCurrencyBeforeChange));
	OpenForm("CommonForm.PricesAndCurrency", ParametersStructure, ThisObject, , , , NotifyDescription, FormWindowOpeningMode.LockOwnerWindow);
	
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
	DataStructure.Insert("DiscountPercentByDiscountCard", Object.DiscountPercentByDiscountCard);
	DataStructure.Insert("DiscountMarkupPercent", 0);
	
	For Each TSRow In Object.Works Do
		
		TSRow.Price = 0;
		
		If Not ValueIsFilled(TSRow.Products) Then
			Continue;
		EndIf;
		
		TabularSectionRow = New Structure();
		TabularSectionRow.Insert("Products",		TSRow.Products);
		TabularSectionRow.Insert("Characteristic",	TSRow.Characteristic);
		TabularSectionRow.Insert("Price",			0);
		
		DocumentTabularSection.Add(TabularSectionRow);
		
	EndDo;
	
	GetTabularSectionPricesByPriceKind(DataStructure, DocumentTabularSection);
	
	For Each TSRow In DocumentTabularSection Do
		
		SearchStructure = New Structure;
		SearchStructure.Insert("Products", TSRow.Products);
		SearchStructure.Insert("Characteristic", TSRow.Characteristic);
		
		SearchResult = Object.Works.FindRows(SearchStructure);
		
		For Each ResultRow In SearchResult Do
			ResultRow.Price = TSRow.Price;
			CalculateAmountInTabularSectionLine("Works", ResultRow, "Price");
		EndDo;
		
	EndDo;
	
	For Each TabularSectionRow In Object.Works Do
		TabularSectionRow.DiscountMarkupPercent = DataStructure.DiscountMarkupPercent;
		CalculateAmountInTabularSectionLine("Works", TabularSectionRow, "Price");
	EndDo;
	
EndProcedure

&AtServerNoContext
// Filling the tabular section Works with bundled service.
// 
Function BundledServiceComposition(WorkKind)
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	BundledServicesWorksAndServices.Products AS Products,
	|	BundledServicesWorksAndServices.StandardHours AS StandardHours,
	|	BundledServicesWorksAndServices.Specification AS Specification
	|FROM
	|	Catalog.BundledServices.WorksAndServices AS BundledServicesWorksAndServices
	|WHERE
	|	BundledServicesWorksAndServices.Ref = &WorkKind";
	
	Query.SetParameter("WorkKind", WorkKind);
	
	BundledServicesArray = New Array;
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	While SelectionDetailRecords.Next() Do
		
		BundledServicesStructure = New Structure("Products, StandardHours, Specification");
		FillPropertyValues(BundledServicesStructure, SelectionDetailRecords);
		BundledServicesArray.Add(BundledServicesStructure);
		
	EndDo;
	
	Return BundledServicesArray;
	
EndFunction

&AtClient
// Filling the tabular section Works with bundled service.
// 
Procedure FillWithBundledService(WorkKind)
	
	ArrayToDel = New Array;
	
	For Each WorkLine In Object.Works Do
		If WorkLine.WorkKind = WorkKind Then
			ArrayToDel.Add(WorkLine);
		EndIf;
	EndDo;
	
	TabularSectionName = "Works";
	For Each DelLine In ArrayToDel Do
		
		// Clear Materials
		SearchResult = Object.Materials.FindRows(New Structure("ConnectionKey", DelLine.ConnectionKey));
		For Each SearchString In SearchResult Do
			IndexOfDeletion = Object.Materials.IndexOf(SearchString);
			Object.Materials.Delete(IndexOfDeletion);
		EndDo;
		
		// Clear LaborAssignment
		SearchResult = Object.LaborAssignment.FindRows(New Structure("ConnectionKey", DelLine.ConnectionKey));
		For Each SearchString In SearchResult Do
			IndexOfDeletion = Object.LaborAssignment.IndexOf(SearchString);
			Object.LaborAssignment.Delete(IndexOfDeletion);
		EndDo;
		
		Object.Works.Delete(DelLine);
		
		ClearCheckboxDiscountsAreCalculatedClient("DeleteRow");
		
	EndDo;
	
	WorksTable = BundledServiceComposition(WorkKind);
	
	For Each WorkLine In WorksTable Do
		
		TabularSectionRow = Object.Works.Add();
		FillPropertyValues(TabularSectionRow, WorkLine);
		TabularSectionRow.WorkKind = WorkKind;
		TabularSectionRow.ConnectionKey = NewConnectionKey();
		
		StructureData = New Structure;
		StructureData.Insert("Company", Object.Company);
		StructureData.Insert("Products", TabularSectionRow.Products);
		StructureData.Insert("Characteristic", TabularSectionRow.Characteristic);
		StructureData.Insert("ProcessingDate", Object.Date);
		StructureData.Insert("TimeNorm", 1);
		StructureData.Insert("VATTaxation", Object.VATTaxation);
		StructureData.Insert("DocumentCurrency", Object.DocumentCurrency);
		StructureData.Insert("AmountIncludesVAT", Object.AmountIncludesVAT);
		StructureData.Insert("PriceKind", Object.PriceKind);
		StructureData.Insert("Factor", 1);
		StructureData.Insert("DiscountMarkupKind", Object.DiscountMarkupKind);
		StructureData.Insert("DiscountCard", Object.DiscountCard);
		StructureData.Insert("DiscountPercentByDiscountCard", Object.DiscountPercentByDiscountCard);
		
		StructureData = GetDataProductsOnChange(StructureData);
		
		TabularSectionRow.Quantity = 1;
		TabularSectionRow.StandardHours = ?(TabularSectionRow.StandardHours = 0, StructureData.TimeNorm, TabularSectionRow.StandardHours);
		TabularSectionRow.VATRate = StructureData.VATRate;
		TabularSectionRow.Specification = ?(ValueIsFilled(TabularSectionRow.Specification), TabularSectionRow.Specification, StructureData.Specification);
		TabularSectionRow.Content = "";
		
		If (ValueIsFilled(Object.PriceKind) AND StructureData.Property("Price")) OR StructureData.Property("Price") Then
			TabularSectionRow.Price = StructureData.Price;
			TabularSectionRow.DiscountMarkupPercent = StructureData.DiscountMarkupPercent;
		EndIf;
		
		TabularSectionRow.ProductsTypeService = StructureData.IsService;
		
		If TabularSectionRow <> Undefined Then
			Items.WorkMaterials.Enabled = Not TabularSectionRow.ProductsTypeService;
		EndIf;
		
		CalculateAmountInTabularSectionLine("Works", TabularSectionRow);
		
	EndDo;
	
EndProcedure

&AtServer
Function NewConnectionKey()
	
	Return DriveServer.CreateNewLinkKey(ThisObject);
	
EndFunction

&AtServerNoContext
// Recalculate the price of the tabular section of the document after making changes in the "Prices and currency" form.
//
// Parameters:
// AttributesStructure - Attribute structure, which necessary
// when recalculation DocumentTabularSection - FormDataStructure, it
// contains the tabular document part.
//
Procedure GetTabularSectionPricesByPriceKind(DataStructure, DocumentTabularSection)
	
	// Discounts.
	If DataStructure.Property("DiscountMarkupKind") 
		AND ValueIsFilled(DataStructure.DiscountMarkupKind) Then
		
		DataStructure.DiscountMarkupPercent = DataStructure.DiscountMarkupKind.Percent;
		
	EndIf;
	
	// Discount card.
	If DataStructure.Property("DiscountPercentByDiscountCard") 
		AND ValueIsFilled(DataStructure.DiscountPercentByDiscountCard) Then
		
		DataStructure.DiscountMarkupPercent = DataStructure.DiscountMarkupPercent + DataStructure.DiscountPercentByDiscountCard;
		
	EndIf;
		
	// 1. Generate document table.
	TempTablesManager = New TempTablesManager;
	
	ProductsTable = New ValueTable;
	
	Array = New Array;
	
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
		NewRow.Products = TSRow.Products;
		NewRow.Characteristic	 = TSRow.Characteristic;
		If TypeOf(TSRow) = Type("Structure") AND TSRow.Property("VATRate") Then
			NewRow.VATRate	 = TSRow.VATRate;
		EndIf;
		
	EndDo;
	
	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	
	Query.Text =
	"SELECT
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
	|		ON (ProductsTable.Products = PricesSliceLast.Products)
	|			AND (ProductsTable.Characteristic = PricesSliceLast.Characteristic)
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
		If TypeOf(TSRow) = Type("Structure") AND TabularSectionRow.Property("VATRate") Then
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

// Function returns the label text "Prices and currency".
//
&AtClientAtServerNoContext
Function GenerateLabelPricesAndCurrency(LabelStructure)
	
	LabelText = "";
	
	// Currency.
	If LabelStructure.ForeignExchangeAccounting Then
		If ValueIsFilled(LabelStructure.DocumentCurrency) Then
			LabelText = TrimAll(String(LabelStructure.DocumentCurrency));
		EndIf;
	EndIf;
	
	// Price kind.
	If ValueIsFilled(LabelStructure.PriceKind) Then
		If IsBlankString(LabelText) Then
			LabelText = LabelText + "%1";
		Else
			LabelText = LabelText + " • %1";
		EndIf;
		LabelText = StringFunctionsClientServer.SubstituteParametersInString(LabelText, TrimAll(String(LabelStructure.PriceKind)));
	EndIf;
	
	// Discount type and percent.
	If ValueIsFilled(LabelStructure.DiscountKind) Then
		If IsBlankString(LabelText) Then
			LabelText = LabelText + "%1";
		Else
			LabelText = LabelText + " • %1";
		EndIf;
		LabelText = StringFunctionsClientServer.SubstituteParametersInString(LabelText, TrimAll(String(LabelStructure.DiscountKind)));
	EndIf;
																			
	// Discount card.
	If ValueIsFilled(LabelStructure.DiscountCard) Then
		If IsBlankString(LabelText) Then
			LabelText = LabelText + "%1";
		Else
			LabelText = LabelText + " • %1";
		EndIf;
		LabelText = StringFunctionsClientServer.SubstituteParametersInString(LabelText, 
																				String(LabelStructure.DiscountPercentByDiscountCard) + "% "
																				+ NStr("en = 'by card'"));
	EndIf;	
	
	If LabelStructure.RegisteredForVAT Then
	
		// VAT taxation.
		If ValueIsFilled(LabelStructure.VATTaxation) Then
			If IsBlankString(LabelText) Then
				LabelText = LabelText + "%1";
			Else
				LabelText = LabelText + " • %1";
			EndIf;
			LabelText = StringFunctionsClientServer.SubstituteParametersInString(LabelText, TrimAll(String(LabelStructure.VATTaxation)));
		EndIf;
		
		// Flag showing that amount includes VAT.
		If IsBlankString(LabelText) Then
			If LabelStructure.AmountIncludesVAT Then	
				LabelText = NStr("en = 'VAT inclusive'");
			Else
				LabelText = NStr("en = 'VAT exclusive'");
			EndIf;
		EndIf;
	
	EndIf;
	
	Return LabelText;
	
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
		
		If BarcodeData <> Undefined AND BarcodeData.Count() <> 0 Then
			
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
				BarcodeData.MeasurementUnit = BarcodeData.Products.MeasurementUnit;
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
		
		If BarcodeData <> Undefined AND BarcodeData.Count() = 0 Then
			UnknownBarcodes.Add(CurBarcode);
		Else
			Filter = New Structure("Products, Characteristic, MeasurementUnit, Batch");
			FillPropertyValues(Filter, BarcodeData);
			
			TSRowsArray = Object.Inventory.FindRows(Filter);
			If TSRowsArray.Count() = 0 Then
				
				NewRow = Object.Inventory.Add();
				NewRow.Products = BarcodeData.Products;
				NewRow.Characteristic = BarcodeData.Characteristic;
				NewRow.Batch = BarcodeData.Batch;
				NewRow.Quantity = CurBarcode.Quantity;
				NewRow.MeasurementUnit = ?(ValueIsFilled(BarcodeData.MeasurementUnit), BarcodeData.MeasurementUnit, BarcodeData.StructureProductsData.MeasurementUnit);
				NewRow.Price = BarcodeData.StructureProductsData.Price;
				NewRow.DiscountMarkupPercent = BarcodeData.StructureProductsData.DiscountMarkupPercent;
				NewRow.VATRate = BarcodeData.StructureProductsData.VATRate;
				NewRow.Specification = BarcodeData.StructureProductsData.Specification;
				
				NewRow.ProductsTypeInventory = BarcodeData.StructureProductsData.IsInventoryItem;
				
				CalculateAmountInTabularSectionLine( , NewRow);
				Items.Inventory.CurrentRow = NewRow.GetID();
				
			Else
				
				NewRow = TSRowsArray[0];
				NewRow.Quantity = NewRow.Quantity + CurBarcode.Quantity;
				CalculateAmountInTabularSectionLine( , NewRow);
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
			New Structure("UnknownBarcodes", UnknownBarcodes), ThisObject,,,,Notification);
		
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
Procedure BarcodesAreReceivedFragment(UnknownBarcodes)
	
	For Each CurUndefinedBarcode In UnknownBarcodes Do
		
		MessageString = NStr("en = 'Barcode is not found: %1%; quantity: %2%'");
		MessageString = StrReplace(MessageString, "%1%", CurUndefinedBarcode.Barcode);
		MessageString = StrReplace(MessageString, "%2%", CurUndefinedBarcode.Quantity);
		CommonUseClientServer.MessageToUser(MessageString);
		
	EndDo;
	
EndProcedure

// End Peripherals

&AtServer
// Procedure fills inventories by specification.
//
Procedure FillByBillsOfMaterialsAtServer(BySpecification, RequiredQuantity = 1, UsedMeasurementUnit = Undefined)
	
	Query = New Query(
	"SELECT
	|	MAX(BillsOfMaterialsContent.LineNumber) AS BillsOfMaterialsContentLineNumber,
	|	BillsOfMaterialsContent.Products AS Products,
	|	BillsOfMaterialsContent.ContentRowType AS ContentRowType,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN BillsOfMaterialsContent.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	BillsOfMaterialsContent.MeasurementUnit AS MeasurementUnit,
	|	BillsOfMaterialsContent.Specification AS Specification,
	|	SUM(BillsOfMaterialsContent.Quantity / BillsOfMaterialsContent.ProductsQuantity * &Factor * &Quantity) AS Quantity
	|FROM
	|	Catalog.BillsOfMaterials.Content AS BillsOfMaterialsContent
	|WHERE
	|	BillsOfMaterialsContent.Ref = &Specification
	|	AND BillsOfMaterialsContent.Products.ProductsType = &ProductsType
	|
	|GROUP BY
	|	BillsOfMaterialsContent.Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN BillsOfMaterialsContent.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END,
	|	BillsOfMaterialsContent.MeasurementUnit,
	|	BillsOfMaterialsContent.Specification,
	|	BillsOfMaterialsContent.ContentRowType
	|
	|ORDER BY
	|	BillsOfMaterialsContentLineNumber");
	
	Query.SetParameter("UseCharacteristics", GetFunctionalOption("UseCharacteristics"));
	
	Query.SetParameter("Specification", BySpecification);
	Query.SetParameter("Quantity", RequiredQuantity);
	
	If Not TypeOf(UsedMeasurementUnit) = Type("CatalogRef.UOMClassifier")
		AND UsedMeasurementUnit <> Undefined Then
		Query.SetParameter("Factor", UsedMeasurementUnit.Factor);
	Else
		Query.SetParameter("Factor", 1);
	EndIf;
	
	Query.SetParameter("ProductsType", Enums.ProductsTypes.InventoryItem);
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		
		If Selection.ContentRowType = Enums.BOMLineType.Node Then
			
			FillByBillsOfMaterialsAtServer(Selection.Specification, Selection.Quantity, Selection.MeasurementUnit);
			
		Else
			
			NewRow = Object.Materials.Add();
			FillPropertyValues(NewRow, Selection);
			NewRow.ConnectionKey = Items.Materials.RowFilter["ConnectionKey"];
			
		EndIf;
		
	EndDo;
	
EndProcedure

&AtServer
// Get materials by BillsOfMaterials
//
Procedure MoveMaterialsToTableFieldWithRecordKeys(TableOfBillsOfMaterials)
	
	Query	= New Query;
	
	Query.Text = 
	"SELECT
	|	TableOfBillsOfMaterials.Specification AS Specification,
	|	TableOfBillsOfMaterials.Quantity AS Quantity,
	|	TableOfBillsOfMaterials.CoefficientFromBaseMeasurementUnit AS CoefficientFromBaseMeasurementUnit,
	|	TableOfBillsOfMaterials.ConnectionKey AS ConnectionKey
	|INTO TmpSpecificationTab
	|FROM
	|	&TableOfBillsOfMaterials AS TableOfBillsOfMaterials
	|WHERE
	|	NOT TableOfBillsOfMaterials.ProductsTypeService
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TmpSpecificationTab.ConnectionKey AS ConnectionKey,
	|	BillsOfMaterialsContent.ContentRowType AS ContentRowType,
	|	BillsOfMaterialsContent.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN BillsOfMaterialsContent.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	BillsOfMaterialsContent.MeasurementUnit AS MeasurementUnit,
	|	CASE
	|		WHEN BillsOfMaterialsContent.ContentRowType = VALUE(Enum.BOMLineType.Node)
	|			THEN CASE
	|					WHEN NOT BillsOfMaterialsContent.MeasurementUnit = BillsOfMaterialsContent.Products.MeasurementUnit
	|						THEN CASE
	|								WHEN BillsOfMaterialsContent.MeasurementUnit.Factor = 0
	|									THEN 1
	|								ELSE BillsOfMaterialsContent.MeasurementUnit.Factor
	|							END
	|					ELSE 1
	|				END
	|		ELSE 1
	|	END AS CoefficientFromBaseMeasurementUnit,
	|	BillsOfMaterialsContent.Quantity / BillsOfMaterialsContent.ProductsQuantity * TmpSpecificationTab.Quantity * CASE
	|		WHEN ISNULL(TmpSpecificationTab.CoefficientFromBaseMeasurementUnit, 0) = 0
	|			THEN 1
	|		ELSE TmpSpecificationTab.CoefficientFromBaseMeasurementUnit
	|	END AS Quantity,
	|	BillsOfMaterialsContent.ProductsQuantity AS ProductsQuantity,
	|	BillsOfMaterialsContent.Specification AS Specification
	|FROM
	|	TmpSpecificationTab AS TmpSpecificationTab
	|		LEFT JOIN Catalog.BillsOfMaterials.Content AS BillsOfMaterialsContent
	|		ON TmpSpecificationTab.Specification = BillsOfMaterialsContent.Ref
	|WHERE
	|	BillsOfMaterialsContent.Products.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)";
	
	Query.SetParameter("TableOfBillsOfMaterials", TableOfBillsOfMaterials);
	Query.SetParameter("UseCharacteristics", GetFunctionalOption("UseCharacteristics"));
	
	QueryResult = Query.Execute().Unload();
	
	TableOfNodes = TableOfBillsOfMaterials.Copy();
	TableOfNodes.Clear();
	
	For Each TableRow In QueryResult Do
		
		If TableRow.ContentRowType = Enums.BOMLineType.Node Then
			
			NewRow = TableOfNodes.Add();
			
		Else
			
			NewRow = Object.Materials.Add();
			
		EndIf;
		
		FillPropertyValues(NewRow, TableRow);
		
	EndDo;
	
	If TableOfNodes.Count() > 0 Then
		
		MoveMaterialsToTableFieldWithRecordKeys(TableOfNodes);
		
	EndIf;
	
EndProcedure

&AtServer
// Calls the material fill procedure by
// all BillsOfMaterials Next minimizes the row duplicates
Procedure FillMaterialsByAllBillsOfMaterialsAtServer()
	
	Works_ValueTable = FormAttributeToValue("Object").Works.Unload();
	
	// Delete rows without BillsOfMaterials and with BillsOfMaterials without content
	Counter = (Works_ValueTable.Count() - 1);
	While Counter >= 0 Do
		If Works_ValueTable[Counter].Specification.Content.Count() = 0 Then 
			Works_ValueTable.Delete(Works_ValueTable[Counter]);
		EndIf;
		Counter = Counter - 1;
	EndDo;
	
	Works_ValueTable.Columns.Add("CoefficientFromBaseMeasurementUnit", New TypeDescription("Number"));
	MoveMaterialsToTableFieldWithRecordKeys(Works_ValueTable);
	
	// Everything is filled now we will minimize the duplicating rows.
	MaterialsTable = Object.Materials.Unload();
	MaterialsTable.GroupBy("ConnectionKey, Products, Characteristic, Batch, MeasurementUnit", "Quantity, Reserve");
	
	Object.Materials.Clear();
	Object.Materials.Load(MaterialsTable);
	
EndProcedure

&AtServer
// Generates column content Materials and Performers in the PM Works Work order.
//
Procedure MakeNamesOfMaterialsAndPerformers()
	
	// Subordinate TP
	UseSecondaryEmployment = GetFunctionalOption("UseSecondaryEmployment");
	For Each WorkRow In Object.Works Do
	
		StringMaterials = "";
		ArrayByKeyRecords = Object.Materials.FindRows(New Structure("ConnectionKey", WorkRow.ConnectionKey));
		For Each TSRow In ArrayByKeyRecords Do
			StringMaterials = StringMaterials + ?(StringMaterials = "", "", ", ") + TSRow.Products 
								+ ?(ValueIsFilled(TSRow.Characteristic), " (" + TSRow.Characteristic + ")", "");
		EndDo;
		WorkRow.Materials = StringMaterials;
		
		TablePerformers = Object.LaborAssignment.Unload(New Structure("ConnectionKey", WorkRow.ConnectionKey), "Employee");
		Query = New Query;
		
		Query.Text = 
		"SELECT
		|	Employees.Code,
		|	Employees.Description,
		|	ChangeHistoryOfIndividualNamesSliceLast.Surname,
		|	ChangeHistoryOfIndividualNamesSliceLast.Name,
		|	ChangeHistoryOfIndividualNamesSliceLast.Patronymic
		|FROM
		|	Catalog.Employees AS Employees
		|		LEFT JOIN InformationRegister.ChangeHistoryOfIndividualNames.SliceLast(&ToDate, ) AS ChangeHistoryOfIndividualNamesSliceLast
		|		ON Employees.Ind = ChangeHistoryOfIndividualNamesSliceLast.Ind
		|WHERE
		|	Employees.Ref IN(&TablePerformers)";
		
		Query.SetParameter("ToDate", Object.Date);
		Query.SetParameter("TablePerformers", TablePerformers);
		
		Selection = Query.Execute().Select();
		
		StringPerformers = "";
		While Selection.Next() Do
			PresentationEmployee = DriveServer.GetSurnameNamePatronymic(Selection.Surname, Selection.Name, Selection.Patronymic);
			StringPerformers = StringPerformers + ?(StringPerformers = "", "", ", ")
				+ ?(ValueIsFilled(PresentationEmployee), PresentationEmployee, Selection.Description);
			If UseSecondaryEmployment Then
				StringPerformers = StringPerformers + " (" + TrimAll(Selection.Code) + ")";
			EndIf;
		EndDo;
		WorkRow.Performers = StringPerformers;
	
	EndDo;
	
EndProcedure

// Procedure fills the tabular section Performers by teams.
//
&AtServer
Procedure FillTabularSectionPerformersByTeamsAtServer(ArrayOfTeams, PerformersConnectionKey = Undefined)
	
	Document = FormAttributeToValue("Object");
	Document.FillTabularSectionPerformersByTeams(ArrayOfTeams, PerformersConnectionKey);
	ValueToFormAttribute(Document, "Object");
	
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
		AND GetFunctionalOption("CheckContractsOnPosting") Then
		
		Cancel = True;
	EndIf;
	
EndProcedure

// It gets counterparty contract selection form parameter structure.
//
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
		
		If ContractData = Undefined Then
			
			ContractData = GetDataContractOnChange(Object.Date, Object.DocumentCurrency, Object.Contract);
			
		EndIf;
		
		PriceKindChanged = Object.PriceKind <> ContractData.PriceKind AND ValueIsFilled(ContractData.PriceKind);
		DiscountKindChanged = Object.DiscountMarkupKind <> ContractData.DiscountMarkupKind AND ValueIsFilled(ContractData.DiscountMarkupKind);
		If ContractData.Property("CallFromProcedureAtCounterpartyChange") Then
			ClearDiscountCard = ValueIsFilled(Object.DiscountCard); // Attribute DiscountCard will be cleared later.
		Else
			ClearDiscountCard = False;
		EndIf;			
		QueryPriceKind = (ValueIsFilled(Object.Contract) AND (PriceKindChanged OR DiscountKindChanged));
		
		SettlementsCurrencyBeforeChange = SettlementsCurrency;
		SettlementsCurrency = ContractData.SettlementsCurrency;
		
		NewContractAndCalculationCurrency = ValueIsFilled(Object.Contract) AND ValueIsFilled(SettlementsCurrency) 
										AND Object.Contract <> ContractBeforeChange AND SettlementsCurrencyBeforeChange <> ContractData.SettlementsCurrency;
		OpenFormPricesAndCurrencies = NewContractAndCalculationCurrency AND Object.DocumentCurrency <> ContractData.SettlementsCurrency
			AND (Object.Inventory.Count() > 0 OR Object.Works.Count() > 0);
		
		DocumentParameters = New Structure;
		DocumentParameters.Insert("ContractBeforeChange", ContractBeforeChange);
		DocumentParameters.Insert("SettlementsCurrencyBeforeChange", SettlementsCurrencyBeforeChange);
		DocumentParameters.Insert("ContractData", ContractData);
		DocumentParameters.Insert("QueryPriceKind", QueryPriceKind);
		DocumentParameters.Insert("OpenFormPricesAndCurrencies", OpenFormPricesAndCurrencies);
		DocumentParameters.Insert("PriceKindChanged", PriceKindChanged);
		DocumentParameters.Insert("DiscountKindChanged", DiscountKindChanged);
		DocumentParameters.Insert("ClearDiscountCard", ClearDiscountCard);
		DocumentParameters.Insert("RecalculationRequiredInventory", Object.Inventory.Count() > 0);
		DocumentParameters.Insert("RecalculationRequiredWork", Object.Works.Count() > 0);
		
		ProcessPricesKindAndSettlementsCurrencyChange(DocumentParameters);
		
		FillPaymentCalendarFromContract(SwitchTypeListOfPaymentCalendar);
		UpdatePaymentCalendar();
		
	EndIf;
	
EndProcedure

&AtServer
Procedure SetAccountingPolicyValues()

	AccountingPolicy = InformationRegisters.AccountingPolicy.GetAccountingPolicy(DocumentDate, Object.Company);
	RegisteredForVAT = AccountingPolicy.RegisteredForVAT;
	
EndProcedure

// Procedure fills the column Reserve by free balances on stock.
//
&AtServer
Procedure WOGoodsFillColumnReserveByBalancesAtServer()
	
	Document = FormAttributeToValue("Object");
	Document.GoodsFillColumnReserveByBalances();
	ValueToFormAttribute(Document, "Object");
	
EndProcedure

// Procedure fills the column Reserve by free balances on stock.
//
&AtServer
Procedure WOGoodsFillColumnReserveByReservesAtServer()
	
	Document = FormAttributeToValue("Object");
	Document.GoodsFillColumnReserveByReserves();
	ValueToFormAttribute(Document, "Object");
	
EndProcedure

// Procedure fills the column Reserve by free balances on stock.
//
&AtServer
Procedure MaterialsFillColumnReserveByBalancesAtServer(MaterialsConnectionKey = Undefined)
	
	Document = FormAttributeToValue("Object");
	Document.MaterialsFillColumnReserveByBalances(MaterialsConnectionKey);
	ValueToFormAttribute(Document, "Object");
	
EndProcedure

// Procedure fills the column Reserve by free balances on stock.
//
&AtServer
Procedure MaterialsFillColumnReserveByReservesAtServer(MaterialsConnectionKey = Undefined)
	
	Document = FormAttributeToValue("Object");
	Document.MaterialsFillColumnReserveByReserves(MaterialsConnectionKey);
	ValueToFormAttribute(Document, "Object");
	
EndProcedure

#EndRegion

#Region ProcedureForWorksWithPick

// Fixes error in event log
//
&AtClient
Procedure WriteErrorReadingDataFromStorage()
	
	EventLogMonitorClient.AddMessageForEventLogMonitor("Error", , EventLogMonitorErrorText);
	
EndProcedure

// Function gets a product list from the temporary storage
//
&AtServer
Procedure GetInventoryFromStorage(InventoryAddressInStorage, TabularSectionName, AreCharacteristics, AreBatches)
	
	TableForImport = GetFromTempStorage(InventoryAddressInStorage);
	
	If Not (TypeOf(TableForImport) = Type("ValueTable")
		OR TypeOf(TableForImport) = Type("Array")) Then
		
		EventLogMonitorErrorText = NStr("en = 'Mismatch the type of passed to the document from pick [%1].
			|Address of inventories in storage: %2
			|Tabular section name: %3'");
		EventLogMonitorErrorText = StringFunctionsClientServer.SubstituteParametersInString(EventLogMonitorErrorText,
			TypeOf(TableForImport),
			TrimAll(InventoryAddressInStorage),
			TrimAll(TabularSectionName));
			
		Return;
		
	Else
		
		EventLogMonitorErrorText = "";
		
	EndIf;
	
	For Each ImportRow In TableForImport Do
		
		NewRow = Object[TabularSectionName].Add();
		FillPropertyValues(NewRow, ImportRow);
		
		If NewRow.Property("Total")
			AND Not ValueIsFilled(NewRow.Total) Then
			
			NewRow.Total = NewRow.Amount + ?(Object.AmountIncludesVAT, 0, NewRow.VATAmount);
			
		EndIf;
		
		// Refilling
		If TabularSectionName = "Works" Then
			
			NewRow.StandardHours = 1;
			
			NewRow.ConnectionKey = DriveServer.CreateNewLinkKey(ThisObject);
			
			If ValueIsFilled(ImportRow.Products) Then
				NewRow.ProductsTypeService = ImportRow.Products.ProductsType = Enums.ProductsTypes.Service;
			EndIf;
			
		ElsIf TabularSectionName = "Inventory" Then
			
			If ValueIsFilled(ImportRow.Products) Then
				NewRow.ProductsTypeInventory = ImportRow.Products.ProductsType = Enums.ProductsTypes.InventoryItem;
			EndIf;
			
		EndIf;
		
		If NewRow.Property("Specification") Then 
			NewRow.Specification = DriveServer.GetDefaultSpecification(ImportRow.Products, ImportRow.Characteristic);
		EndIf;
		
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
			AreCharacteristics		= True;
			
			If SelectionMarker = "Works" Then
				
				If PickupForMaterialsInWorks Then
					
					TabularSectionName	= "Materials";
					AreBatches			= True;
					
					MaterialsGetInventoryFromStorage(InventoryAddressInStorage, TabularSectionName, AreCharacteristics, AreBatches);
					
					FilterStr = New FixedStructure("ConnectionKey", Items[TabularSectionName].RowFilter["ConnectionKey"]);
					Items[TabularSectionName].RowFilter = FilterStr;
					
				Else
					
					TabularSectionName	= "Works";
					AreBatches			= False;
					
					GetInventoryFromStorage(InventoryAddressInStorage, TabularSectionName, AreCharacteristics, AreBatches);
					
					RecalculateSubtotal();
					
					// Payment calendar.
					RecalculatePaymentCalendar();
					
				EndIf;
				
			ElsIf SelectionMarker = "Inventory" Then
				
				TabularSectionName	= "Inventory";
				AreBatches 			= True;
				
				GetInventoryFromStorage(InventoryAddressInStorage, TabularSectionName, AreCharacteristics, AreBatches);
				
				If Not IsBlankString(EventLogMonitorErrorText) Then
					WriteErrorReadingDataFromStorage();
				EndIf;
				
				RecalculateSubtotal();
				
				// Payment calendar.
				RecalculatePaymentCalendar();
				
			ElsIf SelectionMarker = "ConsumersInventory" Then
				
				TabularSectionName	= "ConsumersInventory";
				AreBatches 			= False;
				
				GetInventoryFromStorage(InventoryAddressInStorage, TabularSectionName, AreCharacteristics, AreBatches);
				
			EndIf;

			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region DataProcessorProcedureButtonPressPickTPMaterials

&AtServer
// Function gets a product list from the temporary storage
//
Procedure MaterialsGetInventoryFromStorage(InventoryAddressInStorage, TabularSectionName, AreCharacteristics, AreBatches)
	
	TableForImport = GetFromTempStorage(InventoryAddressInStorage);
	
	For Each ImportRow In TableForImport Do
		
		NewRow = Object.Materials.Add();
		FillPropertyValues(NewRow, ImportRow);
		NewRow.ConnectionKey = Items.Materials.RowFilter["ConnectionKey"];
		
	EndDo;
	
EndProcedure

#EndRegion

#Region ProceduresAndFunctionsForFormAppearanceManagement

// Procedure sets form item availability from order stage.
//
&AtServer
Procedure SetVisibleAndEnabledFromState()
	
	If Object.OrderState.OrderStatus = Enums.OrderStatuses.Completed Then
		
		Items.InventoryReserve.Visible = False;
		
		Items.InventoryChangeReserveFillByBalances.Visible = False;
		Items.InventoryChangeReserveFillByReserves.Visible = True;
		
		Items.MaterialsReserve.Visible = False;
		Items.MaterialsGroupFill.Visible = False;
		Items.ExecutorsFillByTeams.Visible = False;
	Else
		
		Items.InventoryReserve.Visible = True;
		
		Items.InventoryChangeReserveFillByBalances.Visible = True;
		Items.InventoryChangeReserveFillByReserves.Visible = False;
		
		Items.MaterialsChangeReserve.Visible = True;
		Items.MaterialsGroupFill.Visible = True;
		Items.ExecutorsFillByTeams.Visible = True;
	EndIf;
	
	StatusIsComplete = (Object.OrderState = CompletedStatus);
	
	Items.FormWrite.Enabled							= Not StatusIsComplete Or Not Object.Closed;
	Items.FormPost.Enabled							= Not StatusIsComplete Or Not Object.Closed;
	Items.FormPostAndClose.Enabled					= Not StatusIsComplete Or Not Object.Closed;
	Items.FormCreateBasedOn.Enabled 				= Not StatusIsComplete Or Not Object.Closed;
	Items.CloseOrder.Visible						= Not Object.Closed;
	Items.CloseOrderStatus.Visible					= Not Object.Closed;
	Items.InventoryCommandBar.Enabled				= Not StatusIsComplete;
	Items.PricesAndCurrency.Enabled					= Not StatusIsComplete;
	Items.ReadDiscountCard.Enabled					= Not StatusIsComplete;
	Items.WorksWorksSelection.Enabled				= Not StatusIsComplete;
	Items.WorksCalculateDiscountsMarkups.Enabled	= Not StatusIsComplete;
	Items.MaterialsMaterialsPickup.Enabled			= Not StatusIsComplete;
	Items.CustomerMaterialsMaterialsPickup.Enabled	= Not StatusIsComplete;
	
	Items.Counterparty.ReadOnly				= StatusIsComplete;
	Items.Contract.ReadOnly					= StatusIsComplete;
	Items.GroupStartSummary.ReadOnly		= StatusIsComplete;
	Items.RightColumn.ReadOnly				= StatusIsComplete;
	Items.GroupTerms.ReadOnly				= StatusIsComplete;
	Items.GroupWorkDescription.ReadOnly		= StatusIsComplete;
	Items.GroupComment.ReadOnly				= StatusIsComplete;
	Items.Equipment.ReadOnly				= StatusIsComplete;
	Items.SerialNumber.ReadOnly				= StatusIsComplete;
	
	Items.GroupWork.ReadOnly				= StatusIsComplete;
	Items.GroupInventory.ReadOnly			= StatusIsComplete;
	Items.GroupConsumerMaterials.ReadOnly	= StatusIsComplete;
	Items.GroupPerformers.ReadOnly			= StatusIsComplete;
	Items.GroupPaymentsCalendar.ReadOnly	= StatusIsComplete;
	Items.GroupAdditional.ReadOnly			= StatusIsComplete;
	
EndProcedure

&AtServer
// Procedure sets the form attribute visible
// from option Use subsystem Payroll.
//
// Parameters:
// No.
//
Procedure SetVisibleByFOUseSubsystemPayroll()
	
	// Salary.
	Items.GroupPerformers.Visible = UsePayrollSubsystem;
	
EndProcedure

// Procedure sets the form item visible.
//
&AtServer
Procedure SetVisibleFromUserSettings()
	
	If Object.WorkKindPosition = Enums.AttributeStationing.InHeader Then
		Items.WorkKind.Visible = True;
		Items.WorksWorkKind.Visible = False;
		Items.TableWorksWorkKind.Visible = False;
		WorkKindInHeader = True;
	Else
		Items.WorkKind.Visible = False;
		Items.WorksWorkKind.Visible = True;
		Items.TableWorksWorkKind.Visible = True;
		WorkKindInHeader = False;
	EndIf;
	
EndProcedure

// Sets the current page for document operation kind.
//
// Parameters:
// No
//
&AtClient
Procedure OWSetCurrentPage()
	
	PageName = "";
	
	If Object.CashAssetsType = PredefinedValue("Enum.CashAssetTypes.Noncash") Then
		PageName = "ValPageBankAccount";
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

// Procedure sets the contract visible depending on the parameter set to the counterparty.
//
&AtServer
Procedure SetContractVisible()
	
	If ValueIsFilled(Object.Counterparty) Then
		
		CalculationParametersWithCounterparty = CommonUse.ObjectAttributesValues(Object.Counterparty, "DoOperationsByOrders, DoOperationsByContracts");
		
		CounterpartyDoSettlementsByOrders = CalculationParametersWithCounterparty.DoOperationsByOrders;
		Items.Contract.Visible = CalculationParametersWithCounterparty.DoOperationsByContracts;
		
	Else
		
		CounterpartyDoSettlementsByOrders = False;
		Items.Contract.Visible = False;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure SetSerialNumberEnable()

	Items.SerialNumber.Enabled = UseSerialNumbersBalance AND Object.Equipment.UseSerialNumbers;
	If Items.SerialNumber.Enabled Then
		Items.SerialNumber.InputHint = "";
	Else
		Items.SerialNumber.InputHint = NStr("en = '<not use>'");
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
		NewRow.PaymentAmount = Object.Inventory.Total("Amount") + Object.Works.Total("Amount");
		NewRow.PaymentVATAmount = Object.Inventory.Total("VATAmount") + Object.Works.Total("VATAmount");
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
		Items.GroupPaymentCalendarAsListAsString.CurrentPage = Items.GroupPaymentCalendarAsList;
	Else
		Items.GroupPaymentCalendarAsListAsString.CurrentPage = Items.GroupPaymentCalendarAsString;
	EndIf;
	
EndProcedure

&AtClient
Procedure SetVisibleCashAssetsTypes()
	
	PageName = "";
	
	If Object.CashAssetsType = PredefinedValue("Enum.CashAssetTypes.Noncash") Then
		PageName = "ValPageBankAccount";
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
Procedure CloseOrderEnd(QuestionResult, AdditionalParameters) Export
	
	Response = QuestionResult;
	WriteParameters = New Structure;
	WriteParameters.Insert("WriteMode", DocumentWriteMode.Posting);
	
	If Response = DialogReturnCode.Cancel
		Or Not Write(WriteParameters) Then
		Return;
	EndIf;
	
	CloseOrderFragment();
	SetVisibleAndEnabledFromState();
	
EndProcedure

&AtServer
Procedure CloseOrderFragment(Result = Undefined, AdditionalParameters = Undefined)
	
	OrdersArray = New Array;
	OrdersArray.Add(Object.Ref);
	
	ClosingStructure = New Structure;
	ClosingStructure.Insert("WorkOrders", OrdersArray);
	
	OrdersClosingObject = DataProcessors.OrdersClosing.Create();
	OrdersClosingObject.FillOrders(ClosingStructure);
	OrdersClosingObject.CloseOrders();
	Read();
	
EndProcedure

&AtServerNoContext
Function GetWorkOrderStates()
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	WorkOrderStatuses.Ref AS Status
	|FROM
	|	Catalog.WorkOrderStatuses AS WorkOrderStatuses
	|		INNER JOIN Enum.OrderStatuses AS OrderStatuses
	|		ON WorkOrderStatuses.OrderStatus = OrderStatuses.Ref
	|
	|ORDER BY
	|	OrderStatuses.Order";
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	ChoiceData = New ValueList;
	
	While Selection.Next() Do
		ChoiceData.Add(Selection.Status);
	EndDo;
	
	Return ChoiceData;
	
EndFunction

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

// StandardSubsystems.Properties
&AtClient
Procedure Attachable_EditContentOfProperties()
	
	PropertiesManagementClient.EditContentOfProperties(ThisObject, Object.Ref);
	
EndProcedure

&AtServer
Procedure UpdateAdditionalAttributesItems()
	
	PropertiesManagement.UpdateAdditionalAttributesItems(ThisObject, FormAttributeToValue("Object"));
	
EndProcedure
// End StandardSubsystems.Properties

#EndRegion

#Region SerialNumbers

&AtClient
Procedure OpenSerialNumbersSelection()
		
	CurrentDataIdentifier = Items.Inventory.CurrentData.GetID();
	ParametersOfSerialNumbers = SerialNumberPickParameters(CurrentDataIdentifier);
	
	OpenForm("DataProcessor.SerialNumbersSelection.Form", ParametersOfSerialNumbers, ThisObject);

EndProcedure

&AtClient
Procedure OpenSelectionMaterialsSerialNumbers()
	
	CurrentDataIdentifier = Items.Materials.CurrentData.GetID();
	ParametersOfSerialNumbers = SerialNumberPickParametersMaterials(CurrentDataIdentifier);
	
	OpenForm("DataProcessor.SerialNumbersSelection.Form", ParametersOfSerialNumbers, ThisObject);

EndProcedure

&AtServer
Function GetSerialNumbersFromStorage(AddressInTemporaryStorage, RowKey)
	
	Modified = True;
	Return WorkWithSerialNumbers.GetSerialNumbersFromStorage(Object, AddressInTemporaryStorage, RowKey);
	
EndFunction

&AtServer
Function GetSerialNumbersMaterialsFromStorage(AddressInTemporaryStorage, RowKey)
	
	Modified = True;
	
	ParametersFieldNames = New Structure;
	ParametersFieldNames.Insert("NameTSInventory", "Materials");
	ParametersFieldNames.Insert("TSNameSerialNumbers", "SerialNumbersMaterials");
	ParametersFieldNames.Insert("FieldNameConnectionKey", "ConnectionKeySerialNumbers");
	
	Return WorkWithSerialNumbers.GetSerialNumbersFromStorage(Object, AddressInTemporaryStorage, RowKey, ParametersFieldNames);
	
EndFunction

&AtServer
Function SerialNumberPickParameters(CurrentDataIdentifier)
	
	Return WorkWithSerialNumbers.SerialNumberPickParameters(Object, ThisObject.UUID, CurrentDataIdentifier, False);
	
EndFunction

&AtServer
Function SerialNumberPickParametersMaterials(RowID, PickMode = Undefined, TSName = "Materials", TSNameSerialNumbers = "SerialNumbersMaterials")
	
	Return WorkWithSerialNumbers.SerialNumberPickParameters(Object, ThisObject.UUID, RowID, True,
		"Materials", "SerialNumbersMaterials", "ConnectionKeySerialNumbers");
	
EndFunction

#EndRegion

#Region AutomaticDiscounts

// Procedure calculates discounts by document.
//
&AtClient
Procedure CalculateDiscountsMarkupsClient()
	
	ParameterStructure = New Structure;
	ParameterStructure.Insert("ApplyToObject", True);
	ParameterStructure.Insert("OnlyPreliminaryCalculation", False);
	
	If EquipmentManagerClient.RefreshClientWorkplace() Then // Checks if the operator's workplace is specified
		Workplace = EquipmentManagerClientReUse.GetClientWorkplace();
	Else
		Workplace = ""
	EndIf;
	
	ParameterStructure.Insert("Workplace", Workplace);
	
	CalculateDiscountsMarkupsOnServer(ParameterStructure);
	
	RecalculatePaymentCalendar();
	RecalculateSubtotal();
	
EndProcedure

// Function compares discount calculating data on current moment with data of the discount last calculation in document.
// If discounts changed the function returns the value True.
//
&AtServer
Function DiscountsChanged()
	
	ParameterStructure = New Structure;
	ParameterStructure.Insert("ApplyToObject", False);
	ParameterStructure.Insert("OnlyPreliminaryCalculation", False);
	
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
				If Object.DiscountsMarkups[LineNumber-1].Amount <> AppliedDiscounts.TableDiscountsMarkups[LineNumber-1].Amount
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

// Procedure calculates discounts by document.
//
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
	Items.WorksCalculateDiscountsMarkups.Picture = PictureLib.Refresh;
	
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
	
	For Each CurrentRow In Object.Works Do
		ManualDiscountCurAmount = ?(ThereAreManualDiscounts, CurrentRow.Price * CurrentRow.Quantity * CurrentRow.StandardHours * CurrentRow.DiscountMarkupPercent / 100, 0);
		CurAmountDiscounts = ManualDiscountCurAmount + CurrentRow.AutomaticDiscountAmount;
		If CurAmountDiscounts >= CurrentRow.Amount AND CurrentRow.Price > 0 Then
			CurrentRow.TotalDiscountAmountIsMoreThanAmount = True;
		Else
			CurrentRow.TotalDiscountAmountIsMoreThanAmount = False;
		EndIf;
	EndDo;
	
EndProcedure

// Procedure opens a common form for information analysis about discounts by current row.
//
&AtClient
Procedure OpenInformationAboutDiscountsClient(TSName)
	
	ParameterStructure = New Structure;
	ParameterStructure.Insert("ApplyToObject", True);
	ParameterStructure.Insert("OnlyPreliminaryCalculation", False);
	
	ParameterStructure.Insert("OnlyMessagesAfterRegistration", False);
	
	If EquipmentManagerClient.RefreshClientWorkplace() Then // Checks if the operator's workplace is specified
		Workplace = EquipmentManagerClientReUse.GetClientWorkplace();
	Else
		Workplace = ""
	EndIf;
	
	ParameterStructure.Insert("Workplace", Workplace);
	
	If Not Object.DiscountsAreCalculated Then
		QuestionText = NStr("en = 'The discounts are not applied. Do you want to apply them?'");
		
		AdditionalParameters = New Structure("TSName", TSName); 
		AdditionalParameters.Insert("ParameterStructure", ParameterStructure);
		NotificationHandler = New NotifyDescription("NotificationQueryCalculateDiscounts", ThisObject, AdditionalParameters);
		ShowQueryBox(NotificationHandler, QuestionText, QuestionDialogMode.YesNo);
	Else
		CalculateDiscountsCompleteQuestionDataProcessor(ParameterStructure, TSName);
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
	CalculateDiscountsCompleteQuestionDataProcessor(ParameterStructure, AdditionalParameters.TSName);
	
EndProcedure

// Procedure opens a common form for information analysis about discounts by current row after calculation of automatic discounts (if it was necessary).
//
&AtClient
Procedure CalculateDiscountsCompleteQuestionDataProcessor(ParameterStructure, TSName)
	
	If Not ValueIsFilled(AddressDiscountsAppliedInTemporaryStorage) Then
		CalculateDiscountsMarkupsClient();
	EndIf;
	
	CurrentData = Items[TSName].CurrentData;
	MarkupsDiscountsClient.OpenFormAppliedDiscounts(CurrentData, Object, ThisObject);
	
EndProcedure

// Function clears checkbox "DiscountsAreCalculated" if it is necessary and returns True if it is required to
// recalculate discounts.
//
&AtServer
Function ResetFlagDiscountsAreCalculatedServer(Action, SPColumn = "")
	
	RecalculationIsRequired = False;
	If UseAutomaticDiscounts AND (Object.Inventory.Count() > 0 OR Object.Works.Count() > 0) AND (Object.DiscountsAreCalculated OR InstalledGrayColor) Then
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
	If UseAutomaticDiscounts AND (Object.Inventory.Count() > 0 OR Object.Works.Count() > 0) AND (Object.DiscountsAreCalculated OR InstalledGrayColor) Then
		RecalculationIsRequired = ResetFlagDiscountsAreCalculated(Action, SPColumn);
	EndIf;
	Return RecalculationIsRequired;
	
EndFunction

// Function clears checkbox DiscountsAreCalculated if it is necessary and returns True if it is required to recalculate discounts.
//
&AtServer
Function ResetFlagDiscountsAreCalculated(Action, SPColumn = "")
	
	Return DiscountsMarkupsServer.ResetFlagDiscountsAreCalculated(ThisObject, Action, SPColumn, "Inventory", "Works");
	
EndFunction

// Procedure executes necessary actions when creating the form on server.
//
&AtServer
Procedure AutomaticDiscountsOnCreateAtServer()
	
	InstalledGrayColor = False;
	UseAutomaticDiscounts = GetFunctionalOption("UseAutomaticDiscounts");
	If UseAutomaticDiscounts Then
		If Object.Inventory.Count() = 0 AND Object.Works.Count() = 0 Then
			Items.InventoryCalculateDiscountsMarkups.Picture = PictureLib.UpdateGray;
			Items.WorksCalculateDiscountsMarkups.Picture = PictureLib.UpdateGray;
			InstalledGrayColor = True;
		ElsIf Not Object.DiscountsAreCalculated Then
			Object.DiscountsAreCalculated = False;
			Items.InventoryCalculateDiscountsMarkups.Picture = PictureLib.UpdateRed;
			Items.WorksCalculateDiscountsMarkups.Picture = PictureLib.UpdateRed;
		Else
			Items.InventoryCalculateDiscountsMarkups.Picture = PictureLib.Refresh;
			Items.WorksCalculateDiscountsMarkups.Picture = PictureLib.Refresh;
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region DiscountCards

// Procedure - selection handler of discount card, beginning.
//
&AtClient
Procedure DiscountCardIsSelected(DiscountCard)

	DiscountCardOwner = GetDiscountCardOwner(DiscountCard);
	If Object.Counterparty.IsEmpty() AND Not DiscountCardOwner.IsEmpty() Then
		Object.Counterparty = DiscountCardOwner;
		CounterpartyOnChange(Items.Counterparty);
		
		ShowUserNotification(
			NStr("en = 'Customer is filled in and discount card is read'"),
			GetURL(DiscountCard),
			StringFunctionsClientServer.SubstituteParametersInString(NStr("en = 'The customer is filled out in the document and discount card %1 is read'"), DiscountCard),
			PictureLib.Information32);
	ElsIf Object.Counterparty <> DiscountCardOwner AND Not DiscountCardOwner.IsEmpty() Then
		
		CommonUseClientServer.MessageToUser(
			NStr("en = 'Discount card is not read. Discount card holder does not match the customer in the document.'"),
			,
			"Counterparty",
			"Object");
		
		Return;
	Else
		ShowUserNotification(
			NStr("en = 'Discount card read'"),
			GetURL(DiscountCard),
			StringFunctionsClientServer.SubstituteParametersInString(NStr("en = 'Discount card %1 is read'"), DiscountCard),
			PictureLib.Information32);
	EndIf;
	
	DiscountCardIsSelectedAdditionally(DiscountCard);
		
EndProcedure

// Procedure - selection handler of discount card, end.
//
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
			
	PricesAndCurrency = GenerateLabelPricesAndCurrency(LabelStructure);
	
	If Object.Inventory.Count() > 0 Or Object.Works.Count() > 0 Then
		Text = NStr("en = 'Should we recalculate discounts in all lines?'");
		Notification = New NotifyDescription("DiscountCardIsSelectedAdditionallyEnd", ThisObject);
		ShowQueryBox(Notification, Text, QuestionDialogMode.YesNo, , DialogReturnCode.Yes);
	EndIf;
	
EndProcedure

// Procedure - selection handler of discount card, end.
//
&AtClient
Procedure DiscountCardIsSelectedAdditionallyEnd(QuestionResult, AdditionalParameters) Export

	If QuestionResult = DialogReturnCode.Yes Then
		DriveClient.RefillDiscountsTablePartAfterDiscountCardRead(ThisObject, "Inventory");
		DriveClient.RefillDiscountsTablePartAfterDiscountCardRead(ThisObject, "Works");
	EndIf;
	
	// Payment calendar.
	RecalculatePaymentCalendar();
	
	// AutomaticDiscounts
	ClearCheckboxDiscountsAreCalculatedClient("DiscountRecalculationByDiscountCard");
	
EndProcedure

// Function returns the discount card owner.
//
&AtServerNoContext
Function GetDiscountCardOwner(DiscountCard)
	
	Return DiscountCard.CardOwner;
	
EndFunction

// Function returns True if the discount card, which is passed as the parameter, is fixed.
//
&AtServerNoContext
Function ThisDiscountCardWithFixedDiscount(DiscountCard)
	
	Return DiscountCard.Owner.DiscountKindForDiscountCards = Enums.DiscountTypeForDiscountCards.FixedDiscount;
	
EndFunction

// Procedure executes only for ACCUMULATIVE discount cards.
// Procedure calculates document discounts after document date change. Recalculation is executed if
// the discount percent by selected discount card changed. 
//
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
				NStr("en = 'Change the percent of discount of the card from %1% to %2% and recalculate discounts in all rows?'"),
				PreDiscountPercentByDiscountCard,
				NewDiscountPercentByDiscountCard);
			AdditionalParameters	= New Structure("NewDiscountPercentByDiscountCard, RecalculateTP", NewDiscountPercentByDiscountCard, True);
			Notification			= New NotifyDescription("RecalculateDiscountPercentAtDocumentDateChangeEnd", ThisObject, AdditionalParameters);
			
		Else
			
			Text = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Do you want to change the discount percent of the card from %1% to %2%?'"),
				PreDiscountPercentByDiscountCard,
				NewDiscountPercentByDiscountCard);
			AdditionalParameters	= New Structure("NewDiscountPercentByDiscountCard, RecalculateTP", NewDiscountPercentByDiscountCard, False);
			Notification			= New NotifyDescription("RecalculateDiscountPercentAtDocumentDateChangeEnd", ThisObject, AdditionalParameters);
			
		EndIf;
		
		ShowQueryBox(Notification, Text, QuestionDialogMode.YesNo,, DialogReturnCode.Yes);
		
	EndIf;
	
EndProcedure

// Procedure executes only for ACCUMULATIVE discount cards.
// Procedure calculates document discounts after document date change. Recalculation is executed if
// the discount percent by selected discount card changed. 
//
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
				
		PricesAndCurrency = GenerateLabelPricesAndCurrency(LabelStructure);
		
		If AdditionalParameters.RecalculateTP Then
			DriveClient.RefillDiscountsTablePartAfterDiscountCardRead(ThisObject, "Inventory");
			
			// Payment calendar.
			RecalculatePaymentCalendar();
		EndIf;
				
	EndIf;
	
EndProcedure

// Procedure - Command handler ReadDiscountCard forms.
//
&AtClient
Procedure ReadDiscountCardClick(Item)
	
	ParametersStructure = New Structure("Counterparty", Object.Counterparty);
	NotifyDescription = New NotifyDescription("ReadDiscountCardClickEnd", ThisObject);
	OpenForm("Catalog.DiscountCards.Form.ReadingDiscountCard", ParametersStructure, ThisObject, , , , NotifyDescription, FormWindowOpeningMode.LockOwnerWindow);	
	
EndProcedure

// Final part of procedure - of command handler ReadDiscountCard forms.
// Is called after read form closing of discount card.
//
&AtClient
Procedure ReadDiscountCardClickEnd(ReturnParameters, Parameters) Export

	If TypeOf(ReturnParameters) = Type("Structure") Then
		DiscountCardRead = ReturnParameters.DiscountCardRead;
		DiscountCardIsSelected(ReturnParameters.DiscountCard);
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
		
		Modified = True;
		
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
				NStr("en = 'Discount card is not read. Discount card holder does not match the customer in the document.'"),
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
		Object.IncludeVATInPrice = ClosingResult.IncludeVATInPrice;
		Object.VATTaxation = ClosingResult.VATTaxation;
		SettlementsCurrencyBeforeChange = AdditionalParameters.SettlementsCurrencyBeforeChange;
		
		// Recalculate prices by kind of prices.
		If ClosingResult.RefillPrices Then
			
			DriveClient.RefillTabularSectionPricesByPriceKind(ThisObject, "Inventory", True);
			RefillTabularSectionPricesByPriceKind();
			
		EndIf;
		
		// Recalculate prices by currency.
		If Not ClosingResult.RefillPrices
			AND ClosingResult.RecalculatePrices Then
			
			DriveClient.RecalculateTabularSectionPricesByCurrency(ThisObject, SettlementsCurrencyBeforeChange, "Inventory");
			DriveClient.RecalculateTabularSectionPricesByCurrency(ThisObject, SettlementsCurrencyBeforeChange, "Works");
			
		EndIf;
		
		// Recalculate the amount if VAT taxation flag is changed.
		If ClosingResult.VATTaxation <> ClosingResult.PrevVATTaxation Then
			
			FillVATRateByVATTaxation();
			
		EndIf;
		
		// Recalculate the amount if the "Amount includes VAT" flag is changed.
		If Not ClosingResult.RefillPrices
			AND Not ClosingResult.AmountIncludesVAT = ClosingResult.PrevAmountIncludesVAT Then
			
			DriveClient.RecalculateTabularSectionAmountByFlagAmountIncludesVAT(ThisObject, "Inventory");
			DriveClient.RecalculateTabularSectionAmountByFlagAmountIncludesVAT(ThisObject, "Works");
			
		EndIf;
		
		// Generate price and currency label.
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
			
		PricesAndCurrency = GenerateLabelPricesAndCurrency(LabelStructure);
		
		// AutomaticDiscounts
		If ClosingResult.RefillDiscounts OR ClosingResult.RefillPrices OR ClosingResult.RecalculatePrices Then
			ClearCheckboxDiscountsAreCalculatedClient("RefillByFormDataPricesAndCurrency");
		EndIf;
	EndIf;
	
	RecalculatePaymentCalendar();
	RecalculateSubtotal();
	
EndProcedure

&AtClient
// Procedure-handler of the response to question about the necessity to set a new currency rate
//
Procedure DefineNewExchangeRatesettingNeed(ClosingResult, AdditionalParameters) Export
	
	If ClosingResult = DialogReturnCode.Yes Then
		
		Object.ExchangeRate = AdditionalParameters.NewExchangeRate;
		Object.Multiplicity = AdditionalParameters.NewRatio;
		
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
		
		PricesAndCurrency = GenerateLabelPricesAndCurrency(LabelStructure);
		
	EndIf;
	
EndProcedure

&AtClient
// Procedure-handler response on question about document recalculate by contract data
//
Procedure DefineDocumentRecalculateNeedByContractTerms(ClosingResult, AdditionalParameters) Export
	
	If ClosingResult = DialogReturnCode.Yes Then
		
		ContractData = AdditionalParameters.ContractData;
		
		If AdditionalParameters.RecalculationRequiredInventory Then
			
			DriveClient.RefillTabularSectionPricesByPriceKind(ThisObject, "Inventory", True);
			
		EndIf;
		
		If AdditionalParameters.RecalculationRequiredWork Then
			
			RefillTabularSectionPricesByPriceKind();
			
		EndIf;
		
		RecalculatePaymentCalendar();
		RecalculateSubtotal();
		
	EndIf;
	
EndProcedure


#EndRegion

#EndRegion





