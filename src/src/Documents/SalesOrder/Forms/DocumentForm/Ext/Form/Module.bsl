
#Region Variables

&AtClient
Var ThisIsNewRow;

#EndRegion

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	DocumentDate = Object.Date;
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentSessionDate();
	EndIf;
	
	If Not ValueIsFilled(Object.ShipmentDate) Then
		Object.ShipmentDate = DocumentDate;
	EndIf;
	
	ThisObject.InventoryReservation	= GetFunctionalOption("UseInventoryReservation");
	ThisObject.ForeignExchangeAccounting	= GetFunctionalOption("ForeignExchangeAccounting");
	
	ParentCompany = DriveServer.GetCompany(Object.Company);
	ThisObject.Counterparty	= Object.Counterparty;
	ThisObject.Contract		= Object.Contract;
	If ValueIsFilled(ThisObject.Contract) Then
		ThisObject.SettlementsCurrency = CommonUse.ObjectAttributeValue(Contract, "SettlementsCurrency");
	EndIf;
	
	ThisObject.FunctionalCurrency			= DriveReUse.GetNationalCurrency();
	StructureByCurrency						= InformationRegisters.ExchangeRates.GetLast(Object.Date, New Structure("Currency", ThisObject.FunctionalCurrency));
	ThisObject.NationalCurrencyExchangeRate	= StructureByCurrency.ExchangeRate;
	ThisObject.NationalCurrencyMultiplicity	= StructureByCurrency.Multiplicity;
	TabularSectionName = "Inventory";
	
	SetAccountingPolicyValues();
	
	ReadCounterpartyAttributes(ThisObject.CounterpartyAttributes, Object.Counterparty);
	
	TollProcessing					= GetFunctionalOption("UseSubcontractingManufacturing");
	Items.OperationKind.ReadOnly	= Not TollProcessing;
	Items.OperationKind.ChoiceList.Add(Enums.OperationTypesSalesOrder.OrderForSale);
	
	If TollProcessing Then
		Items.OperationKind.ChoiceList.Add(Enums.OperationTypesSalesOrder.OrderForProcessing);
	EndIf;

	If Not ValueIsFilled(Object.Ref)
		AND Not ValueIsFilled(Parameters.Basis) 
		AND Not ValueIsFilled(Parameters.CopyingValue) Then
		
		FillVATRateByCompanyVATTaxation(True);
		
	ElsIf Object.VATTaxation = PredefinedValue("Enum.VATTaxationTypes.SubjectToVAT") Then
		
		Items.InventoryVATRate.Visible						= True;
		Items.InventoryVATAmount.Visible					= True;
		Items.InventoryAmountTotal.Visible					= True;
		Items.PaymentVATAmount.Visible						= True;
		Items.PaymentCalendarPayVATAmount.Visible			= True;
		Items.InventoryTotalAmountOfVAT.Visible				= True;
		
	Else
		
		Items.InventoryVATRate.Visible						= False;
		Items.InventoryVATAmount.Visible					= False;
		Items.InventoryAmountTotal.Visible					= False;
		Items.PaymentVATAmount.Visible						= False;
		Items.PaymentCalendarPayVATAmount.Visible			= False;
		Items.InventoryTotalAmountOfVAT.Visible				= False;
		
	EndIf;
	
	Items.StructuralUnitReserve.Visible	= ThisObject.InventoryReservation;
	
	If Items.OperationKind.ChoiceList.Count() = 1 Then
		Items.OperationKind.Visible = False;
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
	LabelStructure.Insert("RateNationalCurrency",			NationalCurrencyExchangeRate);
	LabelStructure.Insert("VATTaxation",					Object.VATTaxation);
	LabelStructure.Insert("DiscountCard",					Object.DiscountCard);
	LabelStructure.Insert("DiscountPercentByDiscountCard",	Object.DiscountPercentByDiscountCard);
	LabelStructure.Insert("RegisteredForVAT",				RegisteredForVAT);
	
	PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
	
	FillAddedColumns();
	
	// If the document is opened from pick, fill the tabular section products
	If Parameters.FillingValues.Property("InventoryAddressInStorage") 
		AND ValueIsFilled(Parameters.FillingValues.InventoryAddressInStorage) Then
		
		GetInventoryFromStorage(Parameters.FillingValues.InventoryAddressInStorage, 
			Parameters.FillingValues.TabularSectionName,
			Parameters.FillingValues.AreCharacteristics,
			Parameters.FillingValues.AreBatches);
		
	EndIf;
	
	// Price accessibility setup for editing.
	AllowedEditDocumentPrices = DriveAccessManagementReUse.AllowedEditDocumentPrices();
	
	Items.InventoryPrice.ReadOnly					= Not AllowedEditDocumentPrices;
	Items.InventoryDiscountPercentMargin.ReadOnly	= Not AllowedEditDocumentPrices;
	Items.InventoryAmount.ReadOnly					= Not AllowedEditDocumentPrices;
	Items.InventoryVATAmount.ReadOnly				= Not AllowedEditDocumentPrices;
	
	// Status.
	
	InProcessStatus = DriveReUse.GetStatusInProcessOfSalesOrders();
	CompletedStatus = DriveReUse.GetStatusCompletedSalesOrders();
	
	If Not GetFunctionalOption("UseSalesOrderStatuses") Then
		
		Items.StateGroup.Visible = False;
		
		Items.Status.ChoiceList.Add("In process", "In process");
		Items.Status.ChoiceList.Add("Completed", "Completed");
		Items.Status.ChoiceList.Add("Canceled", "Canceled");
		
		If Object.OrderState.OrderStatus = Enums.OrderStatuses.InProcess AND Not Object.Closed Then
			Status = "In process";
		ElsIf Object.OrderState.OrderStatus = Enums.OrderStatuses.Completed Then
			Status = "Completed";
		Else
			Status = "Canceled";
		EndIf;
		
	Else
		
		Items.GroupStatuses.Visible = False;
		
	EndIf;
	
	// AutomaticDiscounts.
	AutomaticDiscountsOnCreateAtServer();
	
	// StandardSubsystems.ObjectVersioning
	ObjectVersioning.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.ObjectVersioning
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.DataImportFromExternalSources
	DataImportFromExternalSources.OnCreateAtServer(Metadata.Documents.SalesOrder.TabularSections.Inventory, DataLoadSettings, ThisObject);
	// End StandardSubsystems.DataImportFromExternalSource
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisForm, Items.GroupImportantCommandsSalesOrder);
	// End StandardSubsystems.Printing
	
	// StandardSubsystems.Properties
	PropertiesManagement.OnCreateAtServer(ThisForm, Object, "AdditionalAttributesGroup");
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
	RefreshChoiceParametersBillsOfMaterials();
	
	SwitchTypeListOfPaymentCalendar = ?(Object.PaymentCalendar.Count() > 1, 1, 0);
	
	Items.InventoryDataImportFromExternalSources.Visible =
		AccessRight("Use", Metadata.DataProcessors.DataImportFromExternalSources);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	FormManagement();
	
	// Peripherals
	EquipmentManagerClientOverridable.StartConnectingEquipmentOnFormOpen(ThisForm, "BarCodeScanner");
	// End Peripherals
	
	SetVisiblePaymentCalendar();
	SetVisibleCashAssetsTypes();
	SetEnableGroupPaymentCalendarDetails();
	
	RecalculateSubtotal();
	
EndProcedure

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
Procedure NotificationProcessing(EventName, Parameter, Source)
	
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
	
	If EventName = "Write_Counterparty" 
		AND ValueIsFilled(Parameter)
		AND Object.Counterparty = Parameter Then
		
		ReadCounterpartyAttributes(ThisObject.CounterpartyAttributes, Parameter);
		FormManagement();
		
	EndIf;
	
	// StandardSubsystems.Properties
	If PropertiesManagementClient.ProcessAlerts(ThisForm, EventName, Parameter) Then
		UpdateAdditionalAttributesItems();
	EndIf;
	// EndStandardSubsystems.Properties
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	FillAddedColumns();
	ClosingDates.ObjectOnReadAtServer(ThisForm, CurrentObject);
	
	// StandardSubsystems.Properties
	PropertiesManagement.OnReadAtServer(ThisForm, CurrentObject);
	// End StandardSubsystems.Properties
	
	SetSwitchTypeListOfPaymentCalendar();
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	// AutomaticDiscounts
	DiscountsCalculatedBeforeWrite = False;
	// If the document is being posted, we check whether the discounts are calculated.
	If UseAutomaticDiscounts Then
		If Not Object.DiscountsAreCalculated AND DiscountsChanged() Then
			CalculateDiscountsMarkupsClient();
			RecalculatePaymentCalendar();
			RecalculateSubtotal();
			
			CalculatedDiscounts = True;
			
			Message = New UserMessage;
			Message.Text = NStr("en = 'The automatic discounts are applied.'");
			Message.DataKey = Object.Ref;
			Message.Message();
			
			DiscountsCalculatedBeforeWrite = True;
			
		Else
			Object.DiscountsAreCalculated = True;
			RefreshImageAutoDiscountsAfterWrite = True;
		EndIf;
	EndIf;
	// End AutomaticDiscounts
	
	// StandardSubsystems.PerformanceMeasurement
	PerformanceEstimationClientServer.StartTimeMeasurement("DocumentSalesOrderPosting");
	// StandardSubsystems.PerformanceMeasurement
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	If WriteParameters.WriteMode = DocumentWriteMode.Posting Then
		
		MessageText = "";
		CheckContractToDocumentConditionAccordance(
			MessageText, 
			CurrentObject.Contract, 
			CurrentObject.Ref, 
			CurrentObject.Company, 
			CurrentObject.Counterparty, 
			CurrentObject.OperationKind, 
			Cancel
		);
		
		If MessageText <> "" Then
			
			Message = New UserMessage;
			Message.Text = ?(Cancel, NStr("en = 'Cannot post the sales order.'") + " " + MessageText, MessageText);
			
			If Cancel Then
				Message.DataPath = "Object";
				Message.Field = "Contract";
				Message.Message();
				Return;
			Else
				Message.Message();
			EndIf;
		EndIf;
		
	EndIf;
	
	// StandardSubsystems.Properties
	PropertiesManagement.BeforeWriteAtServer(ThisForm, CurrentObject);
	// End StandardSubsystems.Properties
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	FillAddedColumns();
	PerformanceEstimationClientServer.StartTimeMeasurement("DocumentSalesOrderAfterWriteOnServer");
	
	// AutomaticDiscounts
	If RefreshImageAutoDiscountsAfterWrite Then
		Items.InventoryCalculateDiscountsMarkups.Picture = PictureLib.Refresh;
		RefreshImageAutoDiscountsAfterWrite = False;
	EndIf;
	// End AutomaticDiscounts
	RefreshChoiceParametersBillsOfMaterials();
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	Notify("Write_SalesOrder", Object.Ref);
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(SelectedValue, ChoiceSource)
	
	If ChoiceSource.FormName = "CommonForm.ProductGLAccounts" Then
		GLAccountsChoiceProcessingAtClient(SelectedValue);
	EndIf;
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	// StandardSubsystems.Properties
	PropertiesManagement.FillCheckProcessing(ThisForm, Cancel, CheckedAttributes);
	// End StandardSubsystems.Properties
	
EndProcedure

#EndRegion

#Region FormItemEventHandlersHeader

&AtClient
Procedure StatusOnChange(Item)
	
	If Status = "In process" Then
		Object.OrderState = InProcessStatus;
		Object.Closed = False;
	ElsIf Status = "Completed" Then
		Object.OrderState = CompletedStatus;
	ElsIf Status = "Canceled" Then
		Object.OrderState = InProcessStatus;
		Object.Closed = False;
	EndIf;
	
	Modified = True;
	FormManagement();
	
EndProcedure

&AtClient
Procedure StatusExtendedTooltipNavigationLinkProcessing(Item, URL, StandardProcessing)
	
	StandardProcessing = False;
	OpenForm("DataProcessor.AdministrationPanel.Form.SectionSales");
	
EndProcedure

&AtClient
Procedure OrderStateOnChange(Item)
	
	If Object.OrderState <> CompletedStatus Then 
		Object.Closed = False;
	EndIf;
	FormManagement();
	
EndProcedure

&AtClient
Procedure OrderStateStartChoice(Item, ChoiceData, StandardProcessing)
	StandardProcessing = False;
	ChoiceData = GetSalesOrderStates();
EndProcedure

&AtClient
Procedure DateOnChange(Item)
	
	// Processing change event dates.
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
		LabelStructure.Insert("RateNationalCurrency",			NationalCurrencyExchangeRate);
		LabelStructure.Insert("VATTaxation",					Object.VATTaxation);
		LabelStructure.Insert("DiscountCard",					Object.DiscountCard);
		LabelStructure.Insert("DiscountPercentByDiscountCard",	Object.DiscountPercentByDiscountCard);
		LabelStructure.Insert("RegisteredForVAT",				RegisteredForVAT);
		
		PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
		
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
	
	ClearEstimate();
	
EndProcedure

&AtClient
Procedure CompanyOnChange(Item)

	// Company change event processor.
	Object.Number = "";
	StructureData = GetDataCompanyOnChange();
	ParentCompany = StructureData.Company;
	If Object.DocumentCurrency = StructureData.BankAccountCashAssetsCurrency Then
		Object.BankAccount = StructureData.BankAccount;
	EndIf;
	
	// Petty cash by default
	If StructureData.Property("PettyCash") Then
		Object.PettyCash = StructureData.PettyCash;
	EndIf;
	// End Petty cash by default
	
	Object.Contract = GetContractByDefault(Object.Ref, Object.Counterparty, Object.Company, Object.OperationKind);
	ProcessContractChange();
	
	LabelStructure = New Structure;
	LabelStructure.Insert("PriceKind",						Object.PriceKind);
	LabelStructure.Insert("DiscountKind",					Object.DiscountMarkupKind);
	LabelStructure.Insert("DocumentCurrency",				Object.DocumentCurrency);
	LabelStructure.Insert("SettlementsCurrency",			SettlementsCurrency);
	LabelStructure.Insert("ExchangeRate",					Object.ExchangeRate);
	LabelStructure.Insert("AmountIncludesVAT",				Object.AmountIncludesVAT);
	LabelStructure.Insert("ForeignExchangeAccounting",	ForeignExchangeAccounting);
	LabelStructure.Insert("RateNationalCurrency",			NationalCurrencyExchangeRate);
	LabelStructure.Insert("VATTaxation",					Object.VATTaxation);
	LabelStructure.Insert("DiscountCard",					Object.DiscountCard);
	LabelStructure.Insert("DiscountPercentByDiscountCard",	Object.DiscountPercentByDiscountCard);
	LabelStructure.Insert("RegisteredForVAT",				RegisteredForVAT);
	
	PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
	
	If Object.SetPaymentTerms
		AND ValueIsFilled(Object.CashAssetsType) Then
		
		RecalculatePaymentCalendar();
		FillPaymentScedule();
		
	EndIf;
	
	RecalculatePaymentCalendar();
	RecalculateSubtotal();
	ClearEstimate();
	
EndProcedure

&AtClient
Procedure StructuralUnitReserveOnChange(Item)
	StructuralUnitReserveOnChangeAtServer();
EndProcedure

&AtClient
Procedure OperationKindOnChange(Item)
	
	ProcessOperationKindChange();
	ProcessContractChange();
	
	TypeOfOperationsBeforeChange = OperationKind;
	OperationKind = Object.OperationKind;
	
	If TypeOfOperationsBeforeChange <> Object.OperationKind Then
		If Object.OperationKind = PredefinedValue("Enum.OperationTypesSalesOrder.OrderForSale") Then
			Items.ReadDiscountCard.Visible = True;
		Else
			If Not Object.DiscountCard.IsEmpty() Then
				
				Object.DiscountCard = PredefinedValue("Catalog.DiscountCards.EmptyRef");
				Object.DiscountPercentByDiscountCard = 0;
				
				LabelStructure = New Structure;
				LabelStructure.Insert("PriceKind",						Object.PriceKind);
				LabelStructure.Insert("DiscountKind",					Object.DiscountMarkupKind);
				LabelStructure.Insert("DocumentCurrency",				Object.DocumentCurrency);
				LabelStructure.Insert("SettlementsCurrency",			SettlementsCurrency);
				LabelStructure.Insert("ExchangeRate",					Object.ExchangeRate);
				LabelStructure.Insert("AmountIncludesVAT",				Object.AmountIncludesVAT);
				LabelStructure.Insert("ForeignExchangeAccounting",	ForeignExchangeAccounting);
				LabelStructure.Insert("RateNationalCurrency",			NationalCurrencyExchangeRate);
				LabelStructure.Insert("VATTaxation",					Object.VATTaxation);
				LabelStructure.Insert("DiscountCard",					Object.DiscountCard);
				LabelStructure.Insert("DiscountPercentByDiscountCard",	Object.DiscountPercentByDiscountCard);
				LabelStructure.Insert("RegisteredForVAT",				RegisteredForVAT);
			
				PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
				
			EndIf;
			Items.ReadDiscountCard.Visible = False;
			Object.SetPaymentTerms = False;
			Object.PaymentCalendar.Clear();
		EndIf;
	EndIf;
	
	FormManagement();
	ClearEstimate();
	
EndProcedure

&AtClient
Procedure CounterpartyOnChange(Item)
	
	CounterpartyBeforeChange = Counterparty;
	Counterparty = Object.Counterparty;
	
	If CounterpartyBeforeChange <> Object.Counterparty Then
		
		DeliveryData = GetDeliveryData(Object.Counterparty);
		Object.DeliveryOption = DeliveryData.DeliveryOption;
		
		If DeliveryData.ShippingAddress = Undefined Then
			CommonUseClientServer.MessageToUser(NStr("en = 'There is no shipping address marked as default'"));
		Else
			Object.ShippingAddress = DeliveryData.ShippingAddress;
		EndIf;
		
		ContractData = GetDataCounterpartyOnChange(Object.Date, Object.DocumentCurrency, Object.Counterparty, Object.Company);
		ContractData.Insert("CallFromProcedureAtCounterpartyChange", True);
		Object.Contract = ContractData.Contract;
		ProcessContractChange(ContractData);
		FormManagement();
		UpdatePaymentCalendar();
		
		Object.SalesRep = ContractData.SalesRep;
		ProcessShippingAddressChange();
		
	Else
		
		Object.Contract = Contract; // Restore the cleared contract automatically.
		
	EndIf;
	
	// AutomaticDiscounts
	ClearCheckboxDiscountsAreCalculatedClient("CounterpartyOnChange");
	ClearEstimate();
	
EndProcedure

&AtClient
Procedure ContractOnChange(Item)
	
	ProcessContractChange();
	ClearEstimate();
	
EndProcedure

&AtClient
Procedure ContractStartChoice(Item, ChoiceData, StandardProcessing)
	
	If Not ValueIsFilled(Object.OperationKind) Then
		Return;
	EndIf;
	
	FormParameters = GetContractChoiceFormParameters(Object.Ref, Object.Company, Object.Counterparty, Object.Contract, Object.OperationKind);
	If FormParameters.ControlContractChoice Then
		
		StandardProcessing = False;
		OpenForm("Catalog.CounterpartyContracts.Form.ChoiceForm", FormParameters, Item);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure EditPricesAndCurrency(Item, StandardProcessing)
	
	StandardProcessing = False;
	ProcessChangesOnButtonPricesAndCurrencies(Object.DocumentCurrency);
	Modified = True;
	
EndProcedure

&AtClient
Procedure BankAccountOnChange(Item)
	
	FormManagement();
	
EndProcedure

&AtClient
Procedure BankAccountStartChoice(Item, ChoiceData, StandardProcessing)
	
	If Not ValueIsFilled(Object.Contract) Then
		Return;
	EndIf;
	
	FormParameters = GetBankAccountChoiceFormParameters(Object.Contract, Object.Company, FunctionalCurrency);
	If FormParameters.SettlementsInStandardUnits Then
		
		StandardProcessing = False;
		OpenForm("Catalog.BankAccounts.ChoiceForm", FormParameters, Item);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CashAssetsTypeOnChange(Item)
	SetVisibleCashAssetsTypes();
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
Procedure SchedulePaymentOnChange(Item)
	FillThePaymentCalender();
EndProcedure

&AtClient
Procedure ShipmentDateOnChange(Item)
		
	ShipmentDateBeforeChange = ShipmentDate;
	ShipmentDate = Object.ShipmentDate;
	
	If ShipmentDateBeforeChange <> Object.ShipmentDate
		AND ValueIsFilled(ShipmentDateBeforeChange) Then
		
		Delta = Object.ShipmentDate - ShipmentDateBeforeChange;
		
		For Each Line In Object.PaymentCalendar Do
			
			Line.PaymentDate = Line.PaymentDate + Delta;
			
		EndDo;
		
		MessageString = NStr("en = 'The Payment terms tab was changed'");
		CommonUseClientServer.MessageToUser(MessageString);
		
	EndIf;
		
EndProcedure

&AtClient
Procedure ShipmentDateStartChoice(Item, ChoiceData, StandardProcessing)
	ShipmentDate = Object.ShipmentDate;
EndProcedure

&AtClient
Procedure DeliveryOptionOnChange(Item)
	FormManagement();
EndProcedure

&AtClient
Procedure ShippingAddressOnChange(Item)
	ProcessShippingAddressChange();
EndProcedure

&AtClient
Procedure ShippingAddressStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	ShippingAddressesClient.OpenShippingAddressesSelectForm(Object.Counterparty, Item);
	
EndProcedure

&AtClient
Procedure ShippingAddressChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	StandardProcessing = False;
	
	If TypeOf(SelectedValue) = Type("Structure") OR TypeOf(SelectedValue) = Type("CatalogRef.ShippingAddresses") Then
		
		If TypeOf(SelectedValue) = Type("Structure") Then
			If SelectedValue.Property("ShippingAddress") Then
				Object.ShippingAddress = SelectedValue.ShippingAddress;
			EndIf;
		Else
			Object.ShippingAddress = SelectedValue;
		EndIf;
		
		ProcessShippingAddressChange();
		
		Modified = True;
		
	EndIf;

EndProcedure

&AtClient
Procedure ShippingAddressCreating(Item, StandardProcessing)
	
	If TypeOf(Object.ShippingAddress) = Type("CatalogRef.Counterparties") Then
		
		StandardProcessing = False;
		
		ShippingAddressesClient.OpenShippingAddressesObjectForm(Object.ShippingAddress, Item);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormItemEventHandlersFormTableInventory

&AtClient
Procedure InventorySelection(Item, SelectedRow, Field, StandardProcessing)
	
	If Item.CurrentItem = Items.InventoryAutomaticDiscountPercent
		AND Not ReadOnly Then
		
		StandardProcessing = False;
		OpenInformationAboutDiscountsClient();
		
	ElsIf Field.Name = "InventoryGLAccounts" Then
		
		StandardProcessing = False;
		OpenProductGLAccountsForm(SelectedRow);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure InventoryOnStartEdit(Item, NewRow, Copy)
	
	If NewRow AND Copy AND 
		(Item.CurrentData.AutomaticDiscountsPercent <> 0 Or Item.CurrentData.AutomaticDiscountAmount <> 0) Then
		Item.CurrentData.AutomaticDiscountsPercent = 0;
		Item.CurrentData.AutomaticDiscountAmount = 0;
		CalculateAmountInTabularSectionLine();
		ClearEstimate();
	ElsIf UseAutomaticDiscounts AND NewRow AND Copy Then
		// Automatic discounts have become irrelevant.
		ClearCheckboxDiscountsAreCalculatedClient("OnStartEdit");
	EndIf;
	
EndProcedure

&AtClient
Procedure InventoryOnEditEnd(Item, NewRow, CancelEdit)
	
	RecalculatePaymentCalendar();
	RecalculateSubtotal();
	
	ThisIsNewRow = False;

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
Procedure InventoryGLAccountsStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	SelectedRow = Items.Inventory.CurrentRow;
	OpenProductGLAccountsForm(SelectedRow);
	
EndProcedure

&AtClient
Procedure InventoryAfterDeleteRow(Item)
	
	RecalculatePaymentCalendar();
	RecalculateSubtotal();
	
	// AutomaticDiscounts.
	ClearCheckboxDiscountsAreCalculatedClient("DeleteRow");
	
EndProcedure

&AtClient
Procedure InventoryProductsOnChange(Item)
	
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
	
	AddGLAccountsToStructure(StructureData, TabularSectionRow);	
	StructureData.Insert("ObjectParameters", GLAccountsInDocumentsClientServer.GetObjectParameters(Object));
	StructureData = GetDataProductsOnChange(StructureData);
	
	FillPropertyValues(TabularSectionRow, StructureData); 
	TabularSectionRow.Quantity				= 1;
	TabularSectionRow.Content				= "";
	TabularSectionRow.ProductsTypeInventory	= StructureData.IsInventoryItem;
	
	CalculateAmountInTabularSectionLine();
	
	ClearEstimate();
	
EndProcedure

&AtClient
Procedure InventoryCharacteristicOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("Products", 	TabularSectionRow.Products);
	StructureData.Insert("Characteristic",			TabularSectionRow.Characteristic);
	
	If ValueIsFilled(Object.PriceKind) Then
	
		StructureData.Insert("ProcessingDate", 		Object.Date);
		StructureData.Insert("DocumentCurrency", 	Object.DocumentCurrency);
		StructureData.Insert("AmountIncludesVAT",	Object.AmountIncludesVAT);	
		StructureData.Insert("VATRate", 			TabularSectionRow.VATRate);
		StructureData.Insert("Price", 				TabularSectionRow.Price);	
		StructureData.Insert("PriceKind",			Object.PriceKind);
		StructureData.Insert("MeasurementUnit", 	TabularSectionRow.MeasurementUnit);
		
	EndIf;
	
	StructureData = GetDataCharacteristicOnChange(StructureData);
	
	TabularSectionRow.Price			= StructureData.Price;
	TabularSectionRow.Content		= "";
	TabularSectionRow.Specification = StructureData.Specification;
	
	CalculateAmountInTabularSectionLine();
	
	ClearEstimate();
	
EndProcedure

&AtClient
Procedure InventoryBatchOnChange(Item)
	
	ClearEstimate();

EndProcedure

&AtClient
Procedure InventorySpecificationOnChange(Item)
	
	ClearEstimate();

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
	
	RecalculatePaymentCalendar();
	RecalculateSubtotal();
	ClearEstimate();
	
EndProcedure

&AtClient
Procedure InventoryMeasurementUnitOnChange(Item)
	
	ClearEstimate();

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
	
	// Price.
	If StructureData.CurrentFactor <> 0 Then
		TabularSectionRow.Price = TabularSectionRow.Price * StructureData.Factor / StructureData.CurrentFactor;
	EndIf; 		
	
	CalculateAmountInTabularSectionLine();
	
EndProcedure

&AtClient
Procedure InventoryPriceOnChange(Item)
	
	CalculateAmountInTabularSectionLine();
	
	RecalculatePaymentCalendar();
	RecalculateSubtotal();
	ClearEstimate();
	
EndProcedure

&AtClient
Procedure InventoryDiscountMarkupPercentOnChange(Item)
	
	CalculateAmountInTabularSectionLine();
	
	RecalculatePaymentCalendar();
	RecalculateSubtotal();
	ClearEstimate();
	
EndProcedure

&AtClient
Procedure InventoryAmountOnChange(Item)
	
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
	CalculateVATAmount(TabularSectionRow);
	
	// Total.
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
	// AutomaticDiscounts.
	ClearCheckboxDiscountsAreCalculatedClient("CalculateAmountInTabularSectionLine", "Amount");
	
	TabularSectionRow.AutomaticDiscountsPercent = 0;
	TabularSectionRow.AutomaticDiscountAmount = 0;
	TabularSectionRow.TotalDiscountAmountIsMoreThanAmount = False;
	// End AutomaticDiscounts
	
	RecalculatePaymentCalendar();
	RecalculateSubtotal();
	ClearEstimate();
	
EndProcedure

&AtClient
Procedure InventoryVATRateOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	CalculateVATAmount(TabularSectionRow);
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
	RecalculatePaymentCalendar();
	RecalculateSubtotal();
	ClearEstimate();
	
EndProcedure

&AtClient
Procedure InventoryVATAmountOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
	RecalculatePaymentCalendar();
	RecalculateSubtotal();
	ClearEstimate();
	
EndProcedure

#EndRegion

#Region FormItemEventHandlersFormConsumerMaterials

&AtClient
Procedure ConsumerMaterialsProductsOnChange(Item)
	
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

#Region FormItemEventHandlersFormPaymentCalendar

&AtClient
Procedure PaymentCalendarPaymentAmountOnChange(Item)
	
	CurrentRow = Items.PaymentCalendar.CurrentData;
	
	TotalInventoryAmount = Object.Inventory.Total("Amount");
	
	If TotalInventoryAmount = 0 Then
		CurrentRow.PaymentPercentage = 0;
		CurrentRow.PaymentVATAmount = 0;
	Else
		CurrentRow.PaymentPercentage = Round(CurrentRow.PaymentAmount / TotalInventoryAmount * 100, 2, 1);
		CurrentRow.PaymentVATAmount = Round(Object.Inventory.Total("VATAmount") * CurrentRow.PaymentAmount / TotalInventoryAmount, 2, 1);
	EndIf;
	
EndProcedure

&AtClient
Procedure PaymentCalendarPaymentPercentageOnChange(Item)
	
	CurrentRow = Items.PaymentCalendar.CurrentData;
	
	CurrentRow.PaymentAmount = Round(Object.Inventory.Total("Amount") * CurrentRow.PaymentPercentage / 100, 2, 1);
	CurrentRow.PaymentVATAmount = Round(Object.Inventory.Total("VATAmount") * CurrentRow.PaymentPercentage / 100, 2, 1);
	
EndProcedure

&AtClient
Procedure PaymentCalendarPayVATAmountOnChange(Item)
	
	CurrentRow = Items.PaymentCalendar.CurrentData;
	
	PaymentCalendarTotal = Object.PaymentCalendar.Total("PaymentVATAmount");
	TotalInventoryAmountOfVAT = Object.PaymentCalendar.Total("PaymentVATAmount");
	
	If PaymentCalendarTotal > TotalInventoryAmountOfVAT Then
		CurrentRow.PaymentVATAmount = CurrentRow.PaymentVATAmount - (PaymentCalendarTotal - TotalInventoryAmountOfVAT);
	EndIf;
	
EndProcedure

&AtClient
Procedure PaymentCalendarOnStartEdit(Item, NewRow, Clone)
	
	CurrentRow = Items.PaymentCalendar.CurrentData;
	
	If CurrentRow.PaymentPercentage = 0 Then
		CurrentRow.PaymentPercentage = 100 - Object.PaymentCalendar.Total("PaymentPercentage");
		CurrentRow.PaymentAmount = Object.Inventory.Total("Amount") - Object.PaymentCalendar.Total("PaymentAmount");
		CurrentRow.PaymentVATAmount = Object.Inventory.Total("VATAmount") - Object.PaymentCalendar.Total("PaymentVATAmount");
	EndIf;
	
EndProcedure

&AtClient
Procedure FillRefreshEstimate(Item)
	
	SaveAndOpenEstimate();
	
EndProcedure

&AtClient
Procedure OpenEstimate(Item)
	
	SaveAndOpenEstimate();
	
EndProcedure

#EndRegion

#Region FormCommandEvents

&AtClient
Procedure CloseOrder(Command)
	
	If Modified Or Not Object.Posted Then
		ShowQueryBox(New NotifyDescription("CloseOrderEnd", ThisObject),
			NStr("en = 'Data is still not recorded. Completion of order is possible only after data is recorded.
					|Data will be written.'"), QuestionDialogMode.OKCancel);
		Return;
	EndIf;
		
	CloseOrderFragment();
	FormManagement();
	
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
	
	RecalculatePaymentCalendar();
	RecalculateSubtotal();
	ClearEstimate();
	
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

&AtClient
Procedure GetWeight(Command)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	GetWeightForTabularSectionRow(TabularSectionRow);
	
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

&AtClient
Procedure EditInList(Command)
	
	If Items.EditInList.Check AND Object.PaymentCalendar.Count() > 1 Then
		
		NotifyDescription = New NotifyDescription("SetOptionEditInListCompleted", ThisObject);
		
		ShowQueryBox(
			NotifyDescription,
			NStr("en = 'All lines except the first one will be deleted. Do you want to continue?'"),
			QuestionDialogMode.YesNo
		);
		Return;
	EndIf;
	
	Items.EditInList.Check = Not Items.EditInList.Check;
	FormManagement();
	
EndProcedure

&AtClient
Procedure DocumentSetup(Command)
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("ShipmentDatePositionInSalesOrder", Object.ShipmentDatePosition);
	ParametersStructure.Insert("WereMadeChanges", False);
	
	OpenForm("CommonForm.DocumentSetup", ParametersStructure,,,,, New NotifyDescription("DocumentSettingCompleted", ThisObject));
	
EndProcedure

&AtClient
Procedure DocumentSettingCompleted(Result, AdditionalParameters) Export
	
	StructureDocumentSetting = Result;
	
	If TypeOf(StructureDocumentSetting) = Type("Structure") AND StructureDocumentSetting.WereMadeChanges Then
		
		Object.ShipmentDatePosition = StructureDocumentSetting.ShipmentDatePositionInSalesOrder;
		
		BeforeShipmentDateVisible = Items.ShipmentDate.Visible;
		
		FormManagement();
		
		If BeforeShipmentDateVisible = False // It was in TS.
			AND Items.ShipmentDate.Visible = True Then // It is in the header.
			
			For Each Row In Object.Inventory Do
				If Not ValueIsFilled(Row.ShipmentDate) Then
					Continue;
				EndIf;
				Object.ShipmentDate = Row.ShipmentDate;
				Break;
			EndDo;
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ChangeReserveFillByBalances(Command)
	
	If Object.Inventory.Count() = 0 Then
		Message = New UserMessage;
		Message.Text = NStr("en = 'There are no products to reserve.'");
		Message.Message();
		Return;
	EndIf;
	
	FillColumnReserveByBalancesAtServer();
	
EndProcedure

&AtClient
Procedure ChangeReserveClearReserve(Command)
	
	If Object.Inventory.Count() = 0 Then
		Message = New UserMessage;
		Message.Text = NStr("en = 'There is nothing to clear.'");
		Message.Message();
		Return;
	EndIf;
	
	For Each TabularSectionRow In Object.Inventory Do
		
		If TabularSectionRow.ProductsTypeInventory Then
			TabularSectionRow.Reserve = 0;
		EndIf;
		
	EndDo;
	
EndProcedure

&AtClient
Procedure FillByBasis(Command)
	
	Response = Undefined;
	
	ShowQueryBox(New NotifyDescription("FillByBasisEnd", ThisObject),
					NStr("en = 'Do you want to refill the sales order with the base document data?'"),
					QuestionDialogMode.YesNo, 0);
EndProcedure

&AtClient
Procedure FillByBasisEnd(Result, AdditionalParameters) Export
    
    Response = Result;
    If Response = DialogReturnCode.Yes Then
        FillByDocument(Object.BasisDocument);
    EndIf;

EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServerNoContext
Function GetBankAccountChoiceFormParameters(Contract, Company, FunctionalCurrency)
	
	ContractAttributes = CommonUse.ObjectAttributesValues(Contract, "SettlementsCurrency, SettlementsInStandardUnits");
	
	CurrenciesList = New ValueList;
	CurrenciesList.Add(ContractAttributes.SettlementsCurrency);
	CurrenciesList.Add(FunctionalCurrency);
	
	FormParameters = New Structure;
	FormParameters.Insert("SettlementsInStandardUnits", ContractAttributes.SettlementsInStandardUnits);
	FormParameters.Insert("Owner", Company);
	FormParameters.Insert("CurrenciesList", CurrenciesList);
	
	Return FormParameters;
	
EndFunction

&AtClient
Procedure ProcessPricesKindAndSettlementsCurrencyChange(DocumentParameters)
	
	ContractBeforeChange = DocumentParameters.ContractBeforeChange;
	SettlementsCurrencyBeforeChange = DocumentParameters.SettlementsCurrencyBeforeChange;
	ContractData = DocumentParameters.ContractData;
	QueryPriceKind = DocumentParameters.QueryPriceKind;
	OpenFormPricesAndCurrencies = DocumentParameters.OpenFormPricesAndCurrencies;
	PriceKindChanged = DocumentParameters.PriceKindChanged;
	DiscountKindChanged = DocumentParameters.DiscountKindChanged;
	If DocumentParameters.Property("ClearDiscountCard") Then
		ClearDiscountCard = DocumentParameters.ClearDiscountCard;
	Else
		ClearDiscountCard = False;
	EndIf;
	RecalculationRequiredInventory	= DocumentParameters.RecalculationRequiredInventory;
	RecalculationRequiredWork		= DocumentParameters.RecalculationRequiredWork;
	
	If Not ContractData.AmountIncludesVAT = Undefined Then
		
		Object.AmountIncludesVAT = ContractData.AmountIncludesVAT;
		
	EndIf;
	
	If ValueIsFilled(Object.Contract) Then 
		
		Object.ExchangeRate	= ?(ContractData.SettlementsCurrencyRateRepetition.ExchangeRate = 0, 1, ContractData.SettlementsCurrencyRateRepetition.ExchangeRate);
		Object.Multiplicity	= ?(ContractData.SettlementsCurrencyRateRepetition.Multiplicity = 0, 1, ContractData.SettlementsCurrencyRateRepetition.Multiplicity);
		
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
		
		WarningText = WarningText + NStr("en = 'Settlement currency of the contract with counterparty has changed. It is necessary to check the document currency.'");
		
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
		LabelStructure.Insert("RateNationalCurrency",			NationalCurrencyExchangeRate);
		LabelStructure.Insert("VATTaxation",					Object.VATTaxation);
		LabelStructure.Insert("DiscountCard",					Object.DiscountCard);
		LabelStructure.Insert("DiscountPercentByDiscountCard",	Object.DiscountPercentByDiscountCard);
		LabelStructure.Insert("RegisteredForVAT",				RegisteredForVAT);
	
		PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
		
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
		LabelStructure.Insert("RateNationalCurrency",			NationalCurrencyExchangeRate);
		LabelStructure.Insert("VATTaxation",					Object.VATTaxation);
		LabelStructure.Insert("DiscountCard",					Object.DiscountCard);
		LabelStructure.Insert("DiscountPercentByDiscountCard",	Object.DiscountPercentByDiscountCard);
		LabelStructure.Insert("RegisteredForVAT",				RegisteredForVAT);
		
		PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
		
	EndIf;
	
EndProcedure

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
Function GetDataCompanyOnChange()
	
	StructureData = New Structure();
	StructureData.Insert("Company", DriveServer.GetCompany(Object.Company));
	StructureData.Insert("BankAccount", Object.Company.BankAccountByDefault);
	StructureData.Insert("BankAccountCashAssetsCurrency", Object.Company.BankAccountByDefault.CashCurrency);
	
	FillAddedColumns(True);
	FillVATRateByCompanyVATTaxation();
	SetAccountingPolicyValues();
	
	Return StructureData;
	
EndFunction

&AtServerNoContext
Function GetDataProductsOnChange(StructureData)
	
	StructureData.Insert("MeasurementUnit", StructureData.Products.MeasurementUnit);
	
	StructureData.Insert("IsService", StructureData.Products.ProductsType = PredefinedValue("Enum.ProductsTypes.Service"));
	StructureData.Insert("IsInventoryItem", StructureData.Products.ProductsType = PredefinedValue("Enum.ProductsTypes.InventoryItem"));
	
	If StructureData.Property("TimeNorm") Then		
		StructureData.TimeNorm = DriveServer.GetWorkTimeRate(StructureData);
	EndIf;
	
	If StructureData.Property("VATTaxation") 
		AND Not StructureData.VATTaxation = PredefinedValue("Enum.VATTaxationTypes.SubjectToVAT") Then
		
		If StructureData.VATTaxation = PredefinedValue("Enum.VATTaxationTypes.NotSubjectToVAT") Then
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
			StructureData.Characteristic = Catalogs.ProductsCharacteristics.EmptyRef();
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
	
	If StructureData.Property("DiscountPercentByDiscountCard") 
		AND ValueIsFilled(StructureData.DiscountCard) Then
		CurPercent = StructureData.DiscountMarkupPercent;
		StructureData.Insert("DiscountMarkupPercent", CurPercent + StructureData.DiscountPercentByDiscountCard);
	EndIf;
	
	GLAccountsInDocuments.FillProductGLAccountsInStructure(StructureData);
	
	Return StructureData;
	
EndFunction

&AtServerNoContext
Function GetDataCharacteristicOnChange(StructureData)
	
	If StructureData.Property("PriceKind") Then
		
		If TypeOf(StructureData.MeasurementUnit) = Type("CatalogRef.UOMClassifier")
			OR NOT ValueIsFilled(StructureData.MeasurementUnit) Then
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

&AtServer
Function GetDataCounterpartyOnChange(Date, DocumentCurrency, Counterparty, Company)
	
	ContractByDefault = GetContractByDefault(Object.Ref, Counterparty, Company, Object.OperationKind);
	
	FillVATRateByVATTaxation();
	
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
		"DiscountMarkupKind",
		ContractByDefault.DiscountMarkupKind
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
		
	ReadCounterpartyAttributes(ThisObject.CounterpartyAttributes, Counterparty);
	
	Return StructureData;
	
EndFunction

&AtServer
Function GetDeliveryData(Counterparty)
	Return ShippingAddressesServer.GetDeliveryDataForCounterparty(Counterparty);
EndFunction

&AtServer
Function GetDeliveryAttributes(ShippingAddress)
	Return ShippingAddressesServer.GetDeliveryAttributesForAddress(ShippingAddress);
EndFunction

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
	
	StructureData.Insert(
		"AmountIncludesVAT",
		?(ValueIsFilled(Contract.PriceKind), Contract.PriceKind.PriceIncludesVAT, Undefined)
	);
	
	Return StructureData;
	
EndFunction

&AtServer
Procedure StructuralUnitReserveOnChangeAtServer()
	FillAddedColumns(True);
EndProcedure

&AtServer
Procedure FillVATRateByCompanyVATTaxation(IsOpening = False)
	
	TaxationBeforeChange = Object.VATTaxation;
	
	Object.VATTaxation = DriveServer.CounterpartyVATTaxation(Object.Counterparty, DriveServer.VATTaxation(Object.Company, Object.Date));
	
	If Not TaxationBeforeChange = Object.VATTaxation Or IsOpening Then
		FillVATRateByVATTaxation();
	EndIf;
	
EndProcedure

&AtServer
Procedure FillVATRateByVATTaxation()
	
	If Object.VATTaxation = PredefinedValue("Enum.VATTaxationTypes.SubjectToVAT") Then
		
		Items.InventoryVATRate.Visible					= True;
		Items.InventoryVATAmount.Visible				= True;
		Items.InventoryAmountTotal.Visible				= True;
		Items.PaymentVATAmount.Visible					= True;
		Items.PaymentCalendarPayVATAmount.Visible		= True;
		Items.InventoryTotalAmountOfVAT.Visible			= True;
		
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
		
		Items.InventoryVATRate.Visible = False;
		Items.InventoryVATAmount.Visible = False;
		Items.InventoryAmountTotal.Visible = False;
		Items.PaymentVATAmount.Visible = False;
		Items.PaymentCalendarPayVATAmount.Visible = False;
		Items.InventoryTotalAmountOfVAT.Visible = False;
		
		If Object.VATTaxation = PredefinedValue("Enum.VATTaxationTypes.NotSubjectToVAT") Then
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

&AtClient
Procedure CalculateVATAmount(TabularSectionRow)
	
	VATRate = DriveReUse.GetVATRateValue(TabularSectionRow.VATRate);
	
	If Object.AmountIncludesVAT Then
		TabularSectionRow.VATAmount = TabularSectionRow.Amount - TabularSectionRow.Amount / ((VATRate + 100) / 100);
	Else
		TabularSectionRow.VATAmount = TabularSectionRow.Amount * VATRate / 100;
	EndIf;
											
EndProcedure

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
	
	CalculateVATAmount(TabularSectionRow);
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
	// AutomaticDiscounts.
	AutomaticDiscountsRecalculationIsRequired = ClearCheckboxDiscountsAreCalculatedClient("CalculateAmountInTabularSectionLine");
	
	TabularSectionRow.AutomaticDiscountsPercent = 0;
	TabularSectionRow.AutomaticDiscountAmount = 0;
	TabularSectionRow.TotalDiscountAmountIsMoreThanAmount = False;
	// End AutomaticDiscounts
	
EndProcedure

&AtClient
Procedure RecalculatePaymentCalendar()
	
	If Object.SetPaymentTerms Then
		
		InventoryTotalAmount = Object.Inventory.Total("Amount");
		InventoryTotalVAT = Object.Inventory.Total("VATAmount");
		
		TotalAmountForCorrectBalance = 0;
		TotalVATForCorrectBalance = 0;
		
		For Each CurRow In Object.PaymentCalendar Do
			CurRow.PaymentAmount	= Round(InventoryTotalAmount * CurRow.PaymentPercentage / 100, 2, 1);
			CurRow.PaymentVATAmount		= Round(InventoryTotalVAT * CurRow.PaymentPercentage / 100, 2, 1);
			
			TotalAmountForCorrectBalance = TotalAmountForCorrectBalance + CurRow.PaymentAmount;
			TotalVATForCorrectBalance = TotalVATForCorrectBalance + CurRow.PaymentVATAmount;
		
		EndDo;
		
		// correct balance
		CurRow.PaymentAmount = CurRow.PaymentAmount + (InventoryTotalAmount - TotalAmountForCorrectBalance);
		CurRow.PaymentVATAmount = CurRow.PaymentVATAmount + (InventoryTotalVAT - TotalVATForCorrectBalance);
		
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
		
		QuestionText = CommonUseClientReUse.RecalculateExchangeRateText(CurrencyRateInLetters, RateNewCurrenciesInLetters);
		 
		AdditionalParameters = New Structure;
		AdditionalParameters.Insert("NewExchangeRate", NewExchangeRate);
		AdditionalParameters.Insert("NewRatio", NewRatio);
		
		NotifyDescription = New NotifyDescription("DefineNewExchangeRatesettingNeed", ThisObject, AdditionalParameters);
		ShowQueryBox(NotifyDescription, QuestionText, QuestionDialogMode.YesNo);
		
	EndIf;
	
EndProcedure

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
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesSalesOrder.OrderForSale") Then
		ParametersStructure.Insert("DiscountCard", Object.DiscountCard);
		ParametersStructure.Insert("WarningText", WarningText);
	EndIf;
	
	NotifyDescription = New NotifyDescription("OpenPricesAndCurrencyFormEnd", ThisObject, New Structure("SettlementsCurrencyBeforeChange", SettlementsCurrencyBeforeChange));
	OpenForm("CommonForm.PricesAndCurrency", ParametersStructure, ThisForm, , , , NotifyDescription, FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtClient
Procedure RefillTabularSectionPricesByPriceKind() 
	
	DataStructure = New Structure;
	DocumentTabularSection = New Array;

	DataStructure.Insert("Date",				Object.Date);
	DataStructure.Insert("Company",				ParentCompany);
	DataStructure.Insert("PriceKind",			Object.PriceKind);
	DataStructure.Insert("DocumentCurrency",	Object.DocumentCurrency);
	DataStructure.Insert("AmountIncludesVAT",	Object.AmountIncludesVAT);
	
	DataStructure.Insert("DiscountMarkupKind", Object.DiscountMarkupKind);
	DataStructure.Insert("DiscountPercentByDiscountCard", Object.DiscountPercentByDiscountCard);
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
			TSRowsArray = Object.Inventory.FindRows(New Structure("Products,Characteristic,Batch,MeasurementUnit",BarcodeData.Products,BarcodeData.Characteristic,BarcodeData.Batch,BarcodeData.MeasurementUnit));
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
				
				FoundString = TSRowsArray[0];
				FoundString.Quantity = FoundString.Quantity + CurBarcode.Quantity;
				CalculateAmountInTabularSectionLine( , FoundString);
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
		
		MessageString = NStr("en = 'Barcode is not found: %1%; quantity: %2%'");
		MessageString = StrReplace(MessageString, "%1%", CurUndefinedBarcode.Barcode);
		MessageString = StrReplace(MessageString, "%2%", CurUndefinedBarcode.Quantity);
		CommonUseClientServer.MessageToUser(MessageString);
		
	EndDo;
	
EndProcedure
// End Peripherals

&AtServer
Procedure FillColumnReserveByBalancesAtServer()
	
	Document = FormAttributeToValue("Object");
	Document.FillColumnReserveByBalances();
	ValueToFormAttribute(Document, "Object");
	
EndProcedure

&AtServerNoContext
Procedure CheckContractToDocumentConditionAccordance(MessageText, Contract, Document, Company, Counterparty, OperationKind, Cancel)
	
	If Not DriveReUse.CounterpartyContractsControlNeeded()
		OR Not Counterparty.DoOperationsByContracts Then
		
		Return;
	EndIf;
	
	ManagerOfCatalog = Catalogs.CounterpartyContracts;
	ContractKindsList = ManagerOfCatalog.GetContractKindsListForDocument(Document, OperationKind);
	
	If Not ManagerOfCatalog.ContractMeetsDocumentTerms(MessageText, Contract, Company, Counterparty, ContractKindsList)
		AND GetFunctionalOption("CheckContractsOnPosting") Then
		
		Cancel = True;
	EndIf;
	
EndProcedure

&AtServerNoContext
Function GetContractChoiceFormParameters(Document, Company, Counterparty, Contract, OperationKind)
	
	ContractTypesList = Catalogs.CounterpartyContracts.GetContractKindsListForDocument(Document, OperationKind);
	
	FormParameters = New Structure;
	FormParameters.Insert("ControlContractChoice", Counterparty.DoOperationsByContracts);
	FormParameters.Insert("Counterparty", Counterparty);
	FormParameters.Insert("Company", Company);
	FormParameters.Insert("ContractType", ContractTypesList);
	FormParameters.Insert("CurrentRow", Contract);
	
	Return FormParameters;
	
EndFunction

&AtServerNoContext
Function GetContractByDefault(Document, Counterparty, Company, OperationKind)
	
	If Not Counterparty.DoOperationsByContracts Then
		Return Counterparty.ContractByDefault;
	EndIf;
	
	ManagerOfCatalog = Catalogs.CounterpartyContracts;
	
	ContractTypesList = ManagerOfCatalog.GetContractKindsListForDocument(Document, OperationKind);
	ContractByDefault = ManagerOfCatalog.GetDefaultContractByCompanyContractKind(Counterparty, Company, ContractTypesList);
	
	Return ContractByDefault;
	
EndFunction

&AtServer
Procedure ProcessOperationKindChange()
	
	Object.Contract = GetContractByDefault(Object.Ref, Object.Counterparty, Object.Company, Object.OperationKind);
	
	For Each StringInventory In Object.Inventory Do
		StringInventory.Reserve = 0;
	EndDo;
	
EndProcedure

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
			AND Object.Inventory.Count() > 0;
		
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
		DocumentParameters.Insert("RecalculationRequiredWork", False);
		
		ProcessPricesKindAndSettlementsCurrencyChange(DocumentParameters);
		
		If Object.OperationKind = PredefinedValue("Enum.OperationTypesSalesOrder.OrderForSale") Then
			FillPaymentCalendarFromContract(SwitchTypeListOfPaymentCalendar);
			UpdatePaymentCalendar();
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ProcessShippingAddressChange()
	
	DeliveryData = GetDeliveryAttributes(Object.ShippingAddress);
	
	FillPropertyValues(Object, DeliveryData,,"SalesRep");
	If ValueIsFilled(DeliveryData.SalesRep) Then
		Object.SalesRep = DeliveryData.SalesRep;
	EndIf;
	
EndProcedure

&AtClient
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
		ElsIf ValueIsFilled(ClosingResult.DiscountCard) AND ValueIsFilled(ClosingResult.Counterparty) AND Object.Counterparty.IsEmpty() Then
			Object.Counterparty = ClosingResult.Counterparty;
			CounterpartyOnChange(Items.Counterparty); // Discount card data is cleared in this procedure.
			Object.DiscountCard = ClosingResult.DiscountCard;
			Object.DiscountPercentByDiscountCard = ClosingResult.DiscountPercentByDiscountCard;
			
			ShowUserNotification(
				NStr("en = 'Customer is filled and discount card is read.'"),
				GetURL(Object.DiscountCard),
				StringFunctionsClientServer.SubstituteParametersInString(
				    NStr("en = 'The customer is filled and discount card %1 is read.'"),
					Object.DiscountCard),
				PictureLib.Information32);
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
			
			DriveClient.RefillTabularSectionPricesByPriceKind(ThisForm, "Inventory", True);
			
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
		
		// DiscountCards
		If ClosingResult.RefillDiscounts AND Not ClosingResult.RefillPrices Then
			DriveClient.RefillDiscountsTablePartAfterDiscountCardRead(ThisForm, "Inventory");
		EndIf;
		// End DiscountCards
		
		For Each TabularSectionRow In Object.Prepayment Do
			
			TabularSectionRow.PaymentAmount = DriveClient.RecalculateFromCurrencyToCurrency(
				TabularSectionRow.SettlementsAmount,
				TabularSectionRow.ExchangeRate,
				?(Object.DocumentCurrency = FunctionalCurrency, NationalCurrencyExchangeRate, Object.ExchangeRate),
				TabularSectionRow.Multiplicity,
				?(Object.DocumentCurrency = FunctionalCurrency, NationalCurrencyMultiplicity, Object.Multiplicity));
				
		EndDo;
		
		// Generate price and currency label.
		LabelStructure = New Structure;
		LabelStructure.Insert("PriceKind",						Object.PriceKind);
		LabelStructure.Insert("DiscountKind",					Object.DiscountMarkupKind);
		LabelStructure.Insert("DocumentCurrency",				Object.DocumentCurrency);
		LabelStructure.Insert("SettlementsCurrency",			SettlementsCurrency);
		LabelStructure.Insert("ExchangeRate",					Object.ExchangeRate);
		LabelStructure.Insert("AmountIncludesVAT",				Object.AmountIncludesVAT);
		LabelStructure.Insert("ForeignExchangeAccounting",	ForeignExchangeAccounting);
		LabelStructure.Insert("RateNationalCurrency",			NationalCurrencyExchangeRate);
		LabelStructure.Insert("VATTaxation",					Object.VATTaxation);
		LabelStructure.Insert("DiscountCard",					Object.DiscountCard);
		LabelStructure.Insert("DiscountPercentByDiscountCard",	Object.DiscountPercentByDiscountCard);
		LabelStructure.Insert("RegisteredForVAT",				RegisteredForVAT);
	
		PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
		
		// AutomaticDiscounts
		If ClosingResult.RefillDiscounts OR ClosingResult.RefillPrices OR ClosingResult.RecalculatePrices Then
			ClearCheckboxDiscountsAreCalculatedClient("RefillByFormDataPricesAndCurrency");
		EndIf;
	EndIf;
	
	RecalculatePaymentCalendar();
	RecalculateSubtotal();
	
EndProcedure

&AtClient
Procedure DefineNewExchangeRatesettingNeed(ClosingResult, AdditionalParameters) Export
	
	If ClosingResult = DialogReturnCode.Yes Then
		
		Object.ExchangeRate = AdditionalParameters.NewExchangeRate;
		Object.Multiplicity = AdditionalParameters.NewRatio;
		
		For Each TabularSectionRow In Object.Prepayment Do
			
			TabularSectionRow.PaymentAmount = DriveClient.RecalculateFromCurrencyToCurrency(
				TabularSectionRow.SettlementsAmount,
				TabularSectionRow.ExchangeRate,
				?(Object.DocumentCurrency = FunctionalCurrency, NationalCurrencyExchangeRate, Object.ExchangeRate),
				TabularSectionRow.Multiplicity,
				?(Object.DocumentCurrency = FunctionalCurrency, NationalCurrencyMultiplicity, Object.Multiplicity));  
			
		EndDo;
			
		LabelStructure = New Structure;
		LabelStructure.Insert("PriceKind",						Object.PriceKind);
		LabelStructure.Insert("DiscountKind",					Object.DiscountMarkupKind);
		LabelStructure.Insert("DocumentCurrency",				Object.DocumentCurrency);
		LabelStructure.Insert("SettlementsCurrency",			SettlementsCurrency);
		LabelStructure.Insert("ExchangeRate",					Object.ExchangeRate);
		LabelStructure.Insert("AmountIncludesVAT",				Object.AmountIncludesVAT);
		LabelStructure.Insert("ForeignExchangeAccounting",	ForeignExchangeAccounting);
		LabelStructure.Insert("RateNationalCurrency",			NationalCurrencyExchangeRate);
		LabelStructure.Insert("VATTaxation",					Object.VATTaxation);
		LabelStructure.Insert("DiscountCard",					Object.DiscountCard);
		LabelStructure.Insert("DiscountPercentByDiscountCard",	Object.DiscountPercentByDiscountCard);
		LabelStructure.Insert("RegisteredForVAT",				RegisteredForVAT);
		
		PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure DefineDocumentRecalculateNeedByContractTerms(ClosingResult, AdditionalParameters) Export
	
	If ClosingResult = DialogReturnCode.Yes Then
		
		ContractData = AdditionalParameters.ContractData;
		
		If AdditionalParameters.RecalculationRequiredInventory Then
			
			DriveClient.RefillTabularSectionPricesByPriceKind(ThisForm, "Inventory", True);
			
		EndIf;
		
		If AdditionalParameters.RecalculationRequiredWork Then
			
			RefillTabularSectionPricesByPriceKind();
			
		EndIf;
		
		RecalculatePaymentCalendar();
		RecalculateSubtotal();
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Procedure ReadCounterpartyAttributes(StructureAttributes, Val Counterparty)
	
	Attributes = "DoOperationsByContracts";
	
	If StructureAttributes = Undefined Then
		StructureAttributes = New Structure(Attributes);
	EndIf;
	
	If ValueIsFilled(Counterparty) Then
		FillPropertyValues(StructureAttributes, CommonUse.ObjectAttributesValues(Counterparty, Attributes));
	Else
		StructureAttributes.DoOperationsByContracts = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure SetOptionEditInListCompleted(Result, AdditionalParameters) Export
	
	If Result <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	While Object.PaymentCalendar.Count() > 1 Do
		Object.PaymentCalendar.Delete(Object.PaymentCalendar.Count()-1);
	EndDo;
	
	Items.EditInList.Check = Not Items.EditInList.Check;
	FormManagement();
	
EndProcedure

&AtClient
Procedure FormManagement()
	
	VisibleFlags = GetFlagsForFormItemsVisible(Object.ShipmentDatePosition, Object.OperationKind, Object.DeliveryOption);
	
	ShipmentDateInHeader	= VisibleFlags.ShipmentDateInHeader;
	IsOrderForProcessing	= VisibleFlags.IsOrderForProcessing;
	OrderSaved				= Not Object.Ref.IsEmpty();
	DeliveryOptionIsFilled	= ValueIsFilled(Object.DeliveryOption);
	
	Items.ShipmentDate.Visible						= ShipmentDateInHeader;
	Items.InventoryShipmentDate.Visible				= Not ShipmentDateInHeader;
	Items.Contract.Visible							= CounterpartyAttributes.DoOperationsByContracts;
	Items.InventoryCommandsChangeReserve.Visible	= Not IsOrderForProcessing;
	Items.InventoryReserve.Visible					= Not IsOrderForProcessing;
	Items.PageConsumerMaterials.Visible				= IsOrderForProcessing;
	Items.InventoryBatch.Visible					= Not IsOrderForProcessing AND ThisObject.InventoryReservation;
	Items.FillRefreshEstimate.Visible				= Not Object.EstimateIsCalculated AND Not ReadOnly;
	Items.OpenEstimate.Visible						= Object.EstimateIsCalculated;
	Items.GroupPaymentCalendar.Visible				= VisibleFlags.OperationKindOrderForSale;
	Items.LogisticsCompany.Visible					= DeliveryOptionIsFilled AND VisibleFlags.DeliveryOptionLogisticsCompany;
	Items.ShippingAddress.Visible					= DeliveryOptionIsFilled AND NOT VisibleFlags.DeliveryOptionSelfPickup;
	Items.ContactPerson.Visible						= DeliveryOptionIsFilled AND NOT VisibleFlags.DeliveryOptionSelfPickup;
	Items.GoodsMarking.Visible						= DeliveryOptionIsFilled AND NOT VisibleFlags.DeliveryOptionSelfPickup;
	Items.DeliveryTimeFrom.Visible					= DeliveryOptionIsFilled AND NOT VisibleFlags.DeliveryOptionSelfPickup;
	Items.DeliveryTimeTo.Visible					= DeliveryOptionIsFilled AND NOT VisibleFlags.DeliveryOptionSelfPickup;
	Items.Incoterms.Visible							= DeliveryOptionIsFilled AND NOT VisibleFlags.DeliveryOptionSelfPickup;
	
	StatusIsComplete = (Object.OrderState = CompletedStatus);
	
	Items.FormWrite.Enabled 				= Not StatusIsComplete Or Not Object.Closed;
	Items.FormPost.Enabled 					= Not StatusIsComplete Or Not Object.Closed;
	Items.FormPostAndClose.Enabled 			= Not StatusIsComplete Or Not Object.Closed;
	Items.FormCreateBasedOn.Enabled 		= Not StatusIsComplete Or Not Object.Closed;
	Items.CloseOrder.Visible				= Not Object.Closed;
	Items.CloseOrderStatus.Visible			= Not Object.Closed;
	Items.InventoryCommandBar.Enabled		= Not StatusIsComplete;
	Items.FillByBasis.Enabled				= Not StatusIsComplete;
	Items.PricesAndCurrency.Enabled			= Not StatusIsComplete;
	Items.FillRefreshEstimate.Enabled		= Not StatusIsComplete;
	Items.OpenEstimate.Enabled				= Not StatusIsComplete;
	Items.ReadDiscountCard.Enabled			= Not StatusIsComplete;
	Items.Counterparty.ReadOnly				= StatusIsComplete;
	Items.Contract.ReadOnly					= StatusIsComplete;
	Items.BasisDocument.ReadOnly			= StatusIsComplete;
	Items.ShippingGroup.ReadOnly			= StatusIsComplete;
	Items.HeaderRight.ReadOnly				= StatusIsComplete;
	Items.Pages.ReadOnly					= StatusIsComplete;
	Items.Footer.ReadOnly					= StatusIsComplete;

	Items.OrderState.DropListButton = True;
	
EndProcedure

&AtServerNoContext
Function GetFlagsForFormItemsVisible(ShipmentDatePosition, OperationKind, DeliveryOption)
	
	VisibleFlags = New Structure;
	VisibleFlags.Insert("ShipmentDateInHeader", (ShipmentDatePosition = Enums.AttributeStationing.InHeader));
	VisibleFlags.Insert("IsOrderForProcessing", (OperationKind = Enums.OperationTypesSalesOrder.OrderForProcessing));
	VisibleFlags.Insert("OperationKindOrderForSale", (OperationKind = Enums.OperationTypesSalesOrder.OrderForSale));
	VisibleFlags.Insert("DeliveryOptionLogisticsCompany", (DeliveryOption = Enums.DeliveryOptions.LogisticsCompany));
	VisibleFlags.Insert("DeliveryOptionSelfPickup", (DeliveryOption = Enums.DeliveryOptions.SelfPickup));
	
	Return VisibleFlags;
	
EndFunction

&AtServer
Procedure SetAccountingPolicyValues()

	AccountingPolicy = InformationRegisters.AccountingPolicy.GetAccountingPolicy(DocumentDate, Object.Company);
	RegisteredForVAT = AccountingPolicy.RegisteredForVAT;
	
EndProcedure

&AtServer
Procedure RecalculateSubtotal()
	Totals = DriveServer.CalculateSubtotal(Object.Inventory.Unload(), Object.AmountIncludesVAT);
	FillPropertyValues(ThisObject, Totals);
EndProcedure

#EndRegion

#Region WorkWithPick

&AtClient
Procedure InventoryPick(Command)
	
	TabularSectionName	= "Inventory";
	SelectionMarker		= "Inventory";
	DocumentPresentaion	= NStr("en = 'sales order'");
	SelectionParameters	= DriveClient.GetSelectionParameters(ThisObject, TabularSectionName, DocumentPresentaion, True, True, True);
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesSalesOrder.OrderForProcessing") Then
		SelectionParameters.Insert("DiscountsMarkupsVisible", False);
	EndIf;
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
Procedure MaterialsPick(Command)
	
	TabularSectionName	= "ConsumerMaterials";
	SelectionMarker		= "Materials";
	DocumentPresentaion	= NStr("en = 'sales order'");
	SelectionParameters	= DriveClient.GetSelectionParameters(ThisObject, TabularSectionName, DocumentPresentaion, False, False, True);
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesSalesOrder.OrderForProcessing") Then
		SelectionParameters.Insert("DiscountsMarkupsVisible", False);
	EndIf;
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
Procedure WriteErrorReadingDataFromStorage()
	
	EventLogMonitorClient.AddMessageForEventLogMonitor("Error", , EventLogMonitorErrorText);
		
EndProcedure

&AtServer
Procedure GetInventoryFromStorage(InventoryAddressInStorage, TabularSectionName, AreCharacteristics, AreBatches)
	
	TableForImport = GetFromTempStorage(InventoryAddressInStorage);
	
	If Not (TypeOf(TableForImport) = Type("ValueTable")
		OR TypeOf(TableForImport) = Type("Array")) Then
		
		EventLogMonitorErrorText = "Mismatch the type of passed to the document from pick [" + TypeOf(TableForImport) + "].
				|Address of inventories in storage: " + TrimAll(InventoryAddressInStorage) + "
				|Tabular section name: " + TrimAll(TabularSectionName);
		
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
			
			NewRow.ConnectionKey = DriveServer.CreateNewLinkKey(ThisForm);
			
			If ValueIsFilled(ImportRow.Products) Then
				
				NewRow.ProductsTypeService = (ImportRow.Products.ProductsType = PredefinedValue("Enum.ProductsTypes.Service"));
				
			EndIf;
			
		ElsIf TabularSectionName = "Inventory" Then
			
			If ValueIsFilled(ImportRow.Products) Then
				
				NewRow.ProductsTypeInventory = (ImportRow.Products.ProductsType = PredefinedValue("Enum.ProductsTypes.InventoryItem"));
				
			EndIf;
			
		EndIf;
		
		If NewRow.Property("Specification") Then 
			
			NewRow.Specification = DriveServer.GetDefaultSpecification(ImportRow.Products, ImportRow.Characteristic);
			
		EndIf;
		
	EndDo;
	
	Document = FormAttributeToValue("Object");
	GLAccountsInDocuments.FillTabSectionFromProductGLAccounts(Document);
	ValueToFormAttribute(Document, "Object");
	FillAddedColumns();
	
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
			AreCharacteristics 			= True;
			
			AreBatches			= False;
			
			If SelectionMarker = "Inventory" Then
				
				TabularSectionName	= "Inventory";
				
				GetInventoryFromStorage(InventoryAddressInStorage, TabularSectionName, AreCharacteristics, AreBatches);
				
				If Not IsBlankString(EventLogMonitorErrorText) Then
					WriteErrorReadingDataFromStorage();
				EndIf;
				
				RecalculatePaymentCalendar();
				RecalculateSubtotal();
				ClearEstimate();
				
			ElsIf SelectionMarker = "Materials" Then
				
				TabularSectionName	= "ConsumerMaterials";
				
				GetInventoryFromStorage(InventoryAddressInStorage, TabularSectionName, AreCharacteristics, AreBatches);
				
			EndIf;
			
			SelectionMarker = "";

			
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
			NStr("en = 'Customer is filled and discount card is read'"),
			GetURL(DiscountCard),
			StringFunctionsClientServer.SubstituteParametersInString(NStr("en = 'The customer is filled and discount card %1 is read'"), DiscountCard),
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
			NStr("en = 'Discount card is read'"),
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
	LabelStructure.Insert("RateNationalCurrency",			NationalCurrencyExchangeRate);
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

// Procedure - selection handler of discount card, end.
//
&AtClient
Procedure DiscountCardIsSelectedAdditionallyEnd(QuestionResult, AdditionalParameters) Export

	If QuestionResult = DialogReturnCode.Yes Then
		DriveClient.RefillDiscountsTablePartAfterDiscountCardRead(ThisForm, "Inventory");
		
		RecalculatePaymentCalendar();
		RecalculateSubtotal();
	EndIf;
	
	// AutomaticDiscounts
	ClearCheckboxDiscountsAreCalculatedClient("DiscountRecalculationByDiscountCard");
	ClearEstimate();
	
EndProcedure

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
		LabelStructure.Insert("RateNationalCurrency",			NationalCurrencyExchangeRate);
		LabelStructure.Insert("VATTaxation",					Object.VATTaxation);
		LabelStructure.Insert("DiscountCard",					Object.DiscountCard);
		LabelStructure.Insert("DiscountPercentByDiscountCard",	Object.DiscountPercentByDiscountCard);
		LabelStructure.Insert("RegisteredForVAT",				RegisteredForVAT);
		
		PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
		
		If AdditionalParameters.RecalculateTP Then
			DriveClient.RefillDiscountsTablePartAfterDiscountCardRead(ThisForm, "Inventory");
			
			RecalculatePaymentCalendar();
			RecalculateSubtotal();
		EndIf;
				
	EndIf;
	
EndProcedure

// Function returns the discount card owner.
//
&AtServerNoContext
Function GetDiscountCardOwner(DiscountCard)
	
	Return DiscountCard.CardOwner;
	
EndFunction

// Procedure - Command handler ReadDiscountCard forms.
//
&AtClient
Procedure ReadDiscountCardClick(Item)
	
	ParametersStructure = New Structure("Counterparty", Object.Counterparty);
	NotifyDescription = New NotifyDescription("ReadDiscountCardClickEnd", ThisObject);
	OpenForm("Catalog.DiscountCards.Form.ReadingDiscountCard", ParametersStructure, ThisForm, , , , NotifyDescription, FormWindowOpeningMode.LockOwnerWindow);
	
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

#Region AutomaticDiscounts

// Procedure - form command handler CalculateDiscountsMarkups.
//
&AtClient
Procedure CalculateDiscountsMarkups(Command)
	
	If Object.Inventory.Count() = 0 Then
		If Object.DiscountsMarkups.Count() > 0 Then
			Object.DiscountsMarkups.Clear();
		EndIf;
		Return;
	EndIf;
	
	CalculateDiscountsMarkupsClient();
	ClearEstimate();
	
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
	
	RecalculatePaymentCalendar();
	RecalculateSubtotal();
	
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

// Procedure - command handler "OpenInformationAboutDiscounts".
//
&AtClient
Procedure OpenInformationAboutDiscounts(Command)
	
	CurrentData = Items.Inventory.CurrentData;
	
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
	
	CurrentData = Items.Inventory.CurrentData;
	MarkupsDiscountsClient.OpenFormAppliedDiscounts(CurrentData, Object, ThisObject);
	
EndProcedure

// Function clears checkbox "DiscountsAreCalculated" if it is necessary and returns True if it is required to
// recalculate discounts.
//
&AtServer
Function ResetFlagDiscountsAreCalculatedServer(Action, SPColumn = "")
	
	RecalculationIsRequired = False;
	If UseAutomaticDiscounts AND Object.Inventory.Count() > 0 AND (Object.DiscountsAreCalculated OR InstalledGrayColor) Then
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
	If UseAutomaticDiscounts AND Object.Inventory.Count() > 0 AND (Object.DiscountsAreCalculated OR InstalledGrayColor) Then
		RecalculationIsRequired = ResetFlagDiscountsAreCalculated(Action, SPColumn);
	EndIf;
	
	Return RecalculationIsRequired;
	
EndFunction

// Function clears checkbox DiscountsAreCalculated if it is necessary and returns True if it is required to recalculate discounts.
//
&AtServer
Function ResetFlagDiscountsAreCalculated(Action, SPColumn = "")
	
	Return DiscountsMarkupsServer.ResetFlagDiscountsAreCalculated(ThisObject, Action, SPColumn);
	
EndFunction

// Procedure executes necessary actions when creating the form on server.
//
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

#Region Estimate

&AtClient
Procedure SaveAndOpenEstimate()
	
	If EquipmentManagerClient.RefreshClientWorkplace() Then // Checks if the operators workplace is specified
		Workplace = EquipmentManagerClientReUse.GetClientWorkplace();
	Else
		Workplace = ""
	EndIf;
	
	Cancel = False;
		
	If Cancel Then
		Return;
	EndIf; 
	
	If Modified Or Object.Ref.IsEmpty() Then
		
		Notification = New NotifyDescription("SaveAndOpenEstimateCompletion", ThisObject);
		ShowQueryBox(Notification, 
			NStr("en = 'To estimate the profit, you have to save the sales order. Do you want to save it?'"),
			QuestionDialogMode.OKCancel);
		Return;
		
	EndIf;
	
	ParameterStructure = New Structure;
	FillEstimateOpenParameters(ParameterStructure);
	Notification = New NotifyDescription("OnChangeEstimate", ThisObject);
	OpenForm("Document.SalesOrder.Form.EstimateForm", ParameterStructure, ThisObject, UUID,,, Notification, FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtClient
Procedure SaveAndOpenEstimateCompletion(Answer, AdditionalData) Export
	
	If Answer = DialogReturnCode.OK Then
		Write();
		If Object.Ref.IsEmpty() Or Modified Then
			Return; // Failed to write, the platform shows the error message.
		EndIf;
		SaveAndOpenEstimate();
	EndIf;
	
EndProcedure

&AtClient
Procedure OnChangeEstimate(OpeningResult, AdditionalParameters) Export
	
	If OpeningResult = Undefined Then
		Return;
	EndIf;
	
	If Not ReadOnly AND OpeningResult.Property("DataAddress") Then
		OnChangeEstimateServer(OpeningResult.DataAddress);
		FormManagement();
	EndIf;
	
	If OpeningResult.Property("Print")
		AND OpeningResult.Print = True Then
			Command = Commands.Estimate;
	EndIf;
	
EndProcedure

&AtClient
Procedure ClearEstimate()
	
	If Not Object.EstimateIsCalculated Then
		Return;
	EndIf; 
	
	Object.EstimateIsCalculated = False;
	
	// Delete all not common estimate rows
	FilterStructure = New Structure;
	FilterStructure.Insert("Source", PredefinedValue("Enum.EstimateRowsSources.InventoryItem"));
	StringsToDelete = Object.Estimate.FindRows(FilterStructure);
	
	For Each Str In StringsToDelete Do
		Object.Estimate.Delete(Str);
	EndDo;
	
	Items.FillRefreshEstimate.Visible = Not Object.EstimateIsCalculated;
	Items.OpenEstimate.Visible = Object.EstimateIsCalculated;
	
EndProcedure

&AtServer
Function FillEstimateOpenParameters(ParameterStructure)
	
	For Each TabularSectionRow In Object.Inventory Do
		If Not ValueIsFilled(TabularSectionRow.ConnectionKey) Then
			DriveClientServer.FillConnectionKey(Object.Inventory, TabularSectionRow, "ConnectionKey");
		EndIf;
	EndDo;
	
	DataStructure = New Structure;
	DataStructure.Insert("Ref",			Object.Ref);
	DataStructure.Insert("ReadOnly",	ReadOnly);
	
	DataOrder = New Structure;
	DataOrder.Insert("Date",	Object.Date);
	DataOrder.Insert("Number",	Object.Number);
	
	For Each Attribute In Metadata.Documents.SalesOrder.Attributes Do
		DataOrder.Insert(Attribute.Name, Object[Attribute.Name]);
	EndDo;
	
	DataStructure.Insert("DataOrder",	DataOrder);
	DataStructure.Insert("PriceTypes",	Object.EstimatePriceTypes.Unload().UnloadColumn("PriceKind"));
	
	InventoryTable = Object.Inventory.Unload();
	DataStructure.Insert("Inventory",	InventoryTable);
	
	EstimateTable = Object.Estimate.Unload();
	DataStructure.Insert("Estimate",	EstimateTable);
	
	ParameterStructure.Insert("DataAddress", PutToTempStorage(DataStructure, UUID));
	
EndFunction

&AtServer
Procedure OnChangeEstimateServer(SettingsAddress)
	
	If Not IsTempStorageURL(SettingsAddress) Then
		Return;
	EndIf;
	
	Modified = True;
	
	DataStructure = GetFromTempStorage(SettingsAddress);
	Object.Estimate.Load(DataStructure.Estimate);
	
	Object.Inventory.Clear();
	
	For Each EstimateRow In DataStructure.Inventory Do
		NewRow = Object.Inventory.Add();
		FillPropertyValues(NewRow, EstimateRow);
	EndDo;
	
	Object.EstimatePriceTypes.Clear();
	
	For Each PriceKind In DataStructure.PriceTypes Do
		Object.EstimatePriceTypes.Add().PriceKind = PriceKind;
	EndDo;
	
	FillPropertyValues(Object, DataStructure, "EstimateCostPriceCalculationMethod, EstimateTemplate, EstimateComment");
	Object.EstimateIsCalculated = True;
	
EndProcedure

&AtServer
Procedure RefreshChoiceParametersBillsOfMaterials()
	
	ParameterArray = New Array(Items.InventorySpecification.ChoiceParameters);
	
	For ParametersCounter = 1 To ParameterArray.Count() Do
		Index = ParameterArray.Count() - ParametersCounter;
		Parameter = ParameterArray[Index];
		If Parameter.Name = "Filter.SalesOrder" Then
			ParameterArray.Delete(Index);
		EndIf; 
	EndDo; 
	
	Values = New Array;
	Values.Add(Documents.SalesOrder.EmptyRef());
	
	If ValueIsFilled(Object.Ref) Then
		Values.Add(Object.Ref);
	EndIf;
	
	ParameterArray.Add(New ChoiceParameter("Filter.SalesOrder", New FixedArray(Values)));
	
	Items.InventorySpecification.ChoiceParameters = New FixedArray(ParameterArray);
	
EndProcedure

#EndRegion

#Region LibrariesHandlers

// StandardSubsystems.DataImportFromExternalSources
&AtClient
Procedure LoadFromFileInventory(Command)
	
	NotifyDescription = New NotifyDescription("ImportDataFromExternalSourceResultDataProcessor", ThisObject, DataLoadSettings);
	
	DataLoadSettings.Insert("TabularSectionFullName",	"SalesOrder.Inventory");
	DataLoadSettings.Insert("Title",					NStr("en = 'Import inventory from file'"));
	DataLoadSettings.Insert("DatePositionInOrder",		Object.ShipmentDatePosition);
	
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

// End StandardSubsystems.DataImportFromExternalSources

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

// StandardSubsystems.Properties
&AtClient
Procedure Attachable_EditContentOfProperties()
	
	PropertiesManagementClient.EditContentOfProperties(ThisForm, Object.Ref);
	
EndProcedure

&AtServer
Procedure UpdateAdditionalAttributesItems()
	
	PropertiesManagement.UpdateAdditionalAttributesItems(ThisForm, FormAttributeToValue("Object"));
	
EndProcedure
// End StandardSubsystems.Properties

#EndRegion

#Region ServiceProceduresAndFunctions

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
Procedure FillByDocument(BasisDocument)
	
	Document = FormAttributeToValue("Object");
	Document.Filling(BasisDocument, );
	ValueToFormAttribute(Document, "Object");
	Modified = True;
	
	If Object.VATTaxation = PredefinedValue("Enum.VATTaxationTypes.SubjectToVAT") Then
		Items.InventoryVATRate.Visible = True;
		Items.InventoryVATAmount.Visible = True;
		Items.InventoryAmountTotal.Visible = True;
		Items.PaymentVATAmount.Visible = True;
		Items.PaymentCalendarPayVATAmount.Visible = True;
		Items.InventoryTotalAmountOfVAT.Visible = True;
	Else
		Items.InventoryVATRate.Visible = False;
		Items.InventoryVATAmount.Visible = False;
		Items.InventoryAmountTotal.Visible = False;
		Items.PaymentVATAmount.Visible = False;
		Items.PaymentCalendarPayVATAmount.Visible = False;
		Items.InventoryTotalAmountOfVAT.Visible = False;
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
		NewRow.PaymentAmount = Object.Inventory.Total("Amount");
		NewRow.PaymentVATAmount = Object.Inventory.Total("VATAmount");
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
	
	InventoryTotalAmountForCorrectBalance = 0;
	InventoryTotalVATForCorrectBalance = 0;
	
	InventoryTotalAmount = Object.Inventory.Total("Amount");
	InventoryTotalVAT = Object.Inventory.Total("VATAmount");
	
	While DataSelection.Next() Do
		
		NewLine = Object.PaymentCalendar.Add();
		
		If DataSelection.Term = Enums.PaymentTerm.PaymentInAdvance Then
			NewLine.PaymentDate = Object.ShipmentDate - DataSelection.DuePeriod * 86400;
		Else
			NewLine.PaymentDate = Object.ShipmentDate + DataSelection.DuePeriod * 86400;
		EndIf;
		
		NewLine.PaymentPercentage = DataSelection.PaymentPercentage;
		NewLine.PaymentAmount = Round(InventoryTotalAmount * NewLine.PaymentPercentage / 100, 2, RoundMode.Round15as20);
		NewLine.PaymentVATAmount = Round(InventoryTotalVAT * NewLine.PaymentPercentage / 100, 2, RoundMode.Round15as20);
		
		InventoryTotalAmountForCorrectBalance = InventoryTotalAmountForCorrectBalance + NewLine.PaymentAmount;
		InventoryTotalVATForCorrectBalance = InventoryTotalVATForCorrectBalance + NewLine.PaymentVATAmount;
		
	EndDo;
	
	// correct balance
	NewLine.PaymentAmount = NewLine.PaymentAmount + (InventoryTotalAmount - InventoryTotalAmountForCorrectBalance);
	NewLine.PaymentVATAmount = NewLine.PaymentVATAmount + (InventoryTotalVAT - InventoryTotalVATForCorrectBalance);
	
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

&AtServer
Procedure FillPaymentScedule()
	
	If Object.CashAssetsType = Enums.CashAssetTypes.Noncash Then
		Object.BankAccount = CommonUse.ObjectAttributeValue(Object.Company, "BankAccountByDefault");
	ElsIf Object.CashAssetsType = Enums.CashAssetTypes.Cash Then
		Object.PettyCash = CommonUse.ObjectAttributeValue(Object.Company, "PettyCashByDefault");
	EndIf;
	
EndProcedure

&AtClient
Procedure UpdatePaymentCalendar()
	
	SetEnableGroupPaymentCalendarDetails();
	SetVisiblePaymentCalendar();
	SetVisibleCashAssetsTypes();
	
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
	FormManagement();
	
EndProcedure

&AtServer
Procedure CloseOrderFragment(Result = Undefined, AdditionalParameters = Undefined) Export
	
	OrdersArray = New Array;
	OrdersArray.Add(Object.Ref);
	
	ClosingStructure = New Structure;
	ClosingStructure.Insert("SalesOrders", OrdersArray);
	
	OrdersClosingObject = DataProcessors.OrdersClosing.Create();
	OrdersClosingObject.FillOrders(ClosingStructure);
	OrdersClosingObject.CloseOrders();
	Read();
	
EndProcedure

&AtServerNoContext
Function GetSalesOrderStates()
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	SalesOrderStatuses.Ref AS Status
	|FROM
	|	Catalog.SalesOrderStatuses AS SalesOrderStatuses
	|		INNER JOIN Enum.OrderStatuses AS OrderStatuses
	|		ON SalesOrderStatuses.OrderStatus = OrderStatuses.Ref
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
	StructureData.Insert("InventoryGLAccount",	TabRow.InventoryGLAccount);
	
EndProcedure

&AtServer
Procedure FillAddedColumns(GetGLAccounts = False)
	
	ObjectParameters = GLAccountsInDocumentsClientServer.GetObjectParameters(Object);
	
	Tables = New Array();
	Tables.Add(GetStructureData(ObjectParameters));
	
	GLAccountsInDocuments.FillGLAccountsInTable(Object, Tables, GetGLAccounts);
	
EndProcedure

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

&AtClientAtServerNoContext
Function GetStructureData(ObjectParameters, RowData = Undefined, ProductName = "Products") Export
	
	StructureData = New Structure("Products, InventoryGLAccount, GLAccounts, GLAccountsFilled");
	StructureData.Insert("ObjectParameters", ObjectParameters);
	StructureData.Insert("TabName", "Inventory");
	StructureData.Insert("ProductName", ProductName);
	
	If RowData <> Undefined Then 
		FillPropertyValues(StructureData, RowData);
	EndIf;
	
	Return StructureData;

EndFunction

#EndRegion

#Region Initialize

ThisIsNewRow = False;

#EndRegion