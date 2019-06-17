
#Region Variables

&AtClient
Var ThisIsNewRow;

#EndRegion

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Form attributes setting.
	DocumentDate = Object.Date;
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentDate();
	EndIf;
	
	ParentCompany = DriveServer.GetCompany(Object.Company);
	Counterparty = Object.Counterparty;
	Contract = Object.Contract;
	If ValueIsFilled(Contract) Then
		SettlementCurrency = CommonUse.ObjectAttributeValue(Contract, "SettlementsCurrency");
	EndIf;
	
	Order				= Object.Order;
	FunctionalCurrency	= DriveReUse.GetNationalCurrency();
	StructureByCurrency	= InformationRegisters.ExchangeRates.GetLast(Object.Date, New Structure("Currency", FunctionalCurrency));
	
	ExchangeRateNationalCurrency	= StructureByCurrency.ExchangeRate;
	MultiplicityNationalCurrency	= StructureByCurrency.Multiplicity;
	
	If Not ValueIsFilled(Object.Ref) Then
		
		If Not ValueIsFilled(Parameters.Basis) AND Not ValueIsFilled(Parameters.CopyingValue) Then
			FillVATRateByCompanyVATTaxation();
		EndIf;
		
		If Not ValueIsFilled(Object.Order) AND Parameters.Property("Basis") AND TypeOf(Parameters.Basis)=Type("DocumentRef.InventoryTransfer") Then
			For Each RowInventory In Object.Inventory Do
				WorkWithProductsServer.FillDataInTabularSectionRow(Object, "Inventory", RowInventory);
			EndDo;
		EndIf;
		
	EndIf;
	
	SetAccountingPolicyValues();
	
	// Generate price and currency label.
	ForeignExchangeAccounting	= GetFunctionalOption("ForeignExchangeAccounting");
	
	LabelStructure = New Structure;
	LabelStructure.Insert("PriceKind",						Object.PriceKind);
	LabelStructure.Insert("DiscountKind",					Object.DiscountMarkupKind);
	LabelStructure.Insert("DocumentCurrency",				Object.DocumentCurrency);
	LabelStructure.Insert("SettlementsCurrency",			SettlementCurrency);
	LabelStructure.Insert("ExchangeRate",					Object.ExchangeRate);
	LabelStructure.Insert("AmountIncludesVAT",				Object.AmountIncludesVAT);
	LabelStructure.Insert("ForeignExchangeAccounting",		ForeignExchangeAccounting);
	LabelStructure.Insert("ExchangeRateNationalCurrency",	ExchangeRateNationalCurrency);
	LabelStructure.Insert("VATTaxation",					Object.VATTaxation);
	LabelStructure.Insert("DiscountCard",					Object.DiscountCard);
	LabelStructure.Insert("DiscountPercentByDiscountCard",	Object.DiscountPercentByDiscountCard);
	LabelStructure.Insert("RegisteredForVAT",				RegisteredForVAT);
	
	PricesAndCurrency	= DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
	FillAddedColumns();
	
	SetVisibleAndEnabled();
	
	// Attribute visible set from user settings
	SetVisibleFromUserSettings();
	
	WorkWithVAT.SetTextAboutTaxInvoiceIssued(ThisForm);
	
	User = Users.CurrentUser();
	
	SettingValue	= DriveReUse.GetValueByDefaultUser(User, "MainWarehouse");
	MainWarehouse	= ?(ValueIsFilled(SettingValue), SettingValue, Catalogs.BusinessUnits.MainWarehouse);
	
	// Setting contract visible.
	SetContractVisible();
	
	// Department setting
	If Not GetFunctionalOption("UseSeveralDepartments") Then
		Items.AdditionallyRightColumn.United = True;
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
	DataImportFromExternalSources.OnCreateAtServer(Metadata.Documents.SalesInvoice.TabularSections.Inventory, DataLoadSettings, ThisObject);
	// End StandardSubsystems.DataImportFromExternalSource
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisForm, Items.ImportantCommandsGroup);
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
	
	// Serial numbers
	UseSerialNumbersBalance = WorkWithSerialNumbers.UseSerialNumbersBalance();
	
	SetTaxInvoiceText();
	
	SwitchTypeListOfPaymentCalendar = ?(Object.PaymentCalendar.Count() > 1, 1, 0);
	
	Items.InventoryDataImportFromExternalSources.Visible =
		AccessRight("Use", Metadata.DataProcessors.DataImportFromExternalSources);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	// Peripherals
	EquipmentManagerClientOverridable.StartConnectingEquipmentOnFormOpen(ThisForm, "BarCodeScanner");
	// End Peripherals
	
	SetVisiblePaymentCalendar();
	SetVisibleCashAssetsTypes();
	SetEnableGroupPaymentCalendarDetails();
	SetVisibleDeliveryAttributes();
	SetVisibleEarlyPaymentDiscounts();
	SetVisibleSalesRep();
	
	PrepaymentWasChanged = False;
	
	RecalculateSubtotal();
	
EndProcedure

&AtClient
Procedure OnClose(Exit)

	// AutomaticDiscounts
	// Display message about discount calculation if you click the "Post and close" or form closes by the cross with change saving.
	If UseAutomaticDiscounts AND DiscountsCalculatedBeforeWrite Then
		ShowUserNotification(NStr("en = 'Change:'"), 
									GetURL(Object.Ref), 
									String(Object.Ref) + NStr("en = '. The automatic discounts are applied.'"), 
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
	
	If EventName = "RefreshTaxInvoiceText" 
		AND TypeOf(Parameter) = Type("Structure") 
		AND Not Parameter.BasisDocuments.Find(Object.Ref) = Undefined Then
		
		TaxInvoiceText = Parameter.Presentation;
		
	ElsIf EventName = "UpdateIBDocumentAfterFilling" Then
		
		Read();
	
	ElsIf EventName = "Write_Counterparty" 
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
		EndIf; 		
	EndIf;
	
	// Properties subsystem
	If PropertiesManagementClient.ProcessAlerts(ThisForm, EventName, Parameter) Then
		
		UpdateAdditionalAttributesItems();
		
	EndIf;
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	ClosingDates.ObjectOnReadAtServer(ThisForm, CurrentObject);
	
	// StandardSubsystems.Properties
	PropertiesManagement.OnReadAtServer(ThisForm, CurrentObject);
	// End StandardSubsystems.Properties
	
	SetSwitchTypeListOfPaymentCalendar();
	FillAddedColumns();
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	// StandardSubsystems.PerformanceMeasurement
	If WriteParameters.WriteMode = DocumentWriteMode.Posting Then
		PerformanceEstimationClientServer.StartTimeMeasurement("DocumentSalesInvoicePositing");
	EndIf;
	// StandardSubsystems.PerformanceMeasurement
	
	// AutomaticDiscounts
	DiscountsCalculatedBeforeWrite = False;
	// If the document is being posted, we check whether the discounts are calculated.
	If UseAutomaticDiscounts Then
		If Not Object.DiscountsAreCalculated AND DiscountsChanged() Then
			CalculateDiscountsMarkupsClient();
			RecalculatePaymentCalendar();
			RefillDiscountAmountOfEPD();
			RecalculateSubtotal();
			CalculatedDiscounts = True;
			
			Message = New UserMessage;
			Message.Text	= NStr("en = 'The automatic discounts are applied.'");
			Message.DataKey	= Object.Ref;
			Message.Message();
			
			DiscountsCalculatedBeforeWrite	= True;
		Else
			Object.DiscountsAreCalculated	= True;
			RefreshImageAutoDiscountsAfterWrite	= True;
		EndIf;
	EndIf;
	// End AutomaticDiscounts
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	If WriteParameters.WriteMode = DocumentWriteMode.Posting Then
		
		MessageText = "";
		CheckContractToDocumentConditionAccordance(MessageText, Object.Contract, Object.Ref, Object.Company, Object.Counterparty, Cancel);
		
		If MessageText <> "" Then
			
			Message = New UserMessage;
			Message.Text = ?(Cancel, NStr("en = 'Cannot post the sales invoice.'") + " " + MessageText, MessageText);
			
			If Cancel Then
				Message.DataPath	= "Object";
				Message.Field		= "Contract";
				Message.Message();
				Return;
			Else
				Message.Message();
			EndIf;
		EndIf;
		
		If DriveReUse.GetAdvanceOffsettingSettingValue() = PredefinedValue("Enum.YesNo.Yes")
			AND CurrentObject.Prepayment.Count() = 0 Then
			FillPrepayment(CurrentObject);
		ElsIf PrepaymentWasChanged Then
			WorkWithVAT.FillPrepaymentVATFromVATOutput(CurrentObject);
		EndIf;
		
	EndIf;
	
	If NOT CheckEarlyPaymentDiscounts() Then
		Cancel = True;
	EndIf;
	
	// StandardSubsystems.Properties
	PropertiesManagement.BeforeWriteAtServer(ThisForm, CurrentObject);
	// End StandardSubsystems.Properties
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	FillAddedColumns();
	
	// AutomaticDiscounts
	If RefreshImageAutoDiscountsAfterWrite Then
		Items.InventoryCalculateDiscountsMarkups.Picture = PictureLib.Refresh;
		RefreshImageAutoDiscountsAfterWrite = False;
	EndIf;
	// End AutomaticDiscounts
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	OrderIsFilled = False;
	FilledOrderReturn = False;
	For Each TSRow In Object.Inventory Do
		If ValueIsFilled(TSRow.Order) Then
			If TypeOf(TSRow.Order) = Type("DocumentRef.SalesOrder") Then
				OrderIsFilled = True;
			Else
				FilledOrderReturn = True;
			EndIf;
			Break;
		EndIf;		
	EndDo;	
	
	If OrderIsFilled Then
		Notify("Record_SalesInvoice", Object.Ref);
	EndIf;
	
	If FilledOrderReturn Then
		Notify("Record_SalesInvoiceReturn", Object.Ref);
	EndIf;
	
	Notify("NotificationAboutChangingDebt");
	
	PrepaymentWasChanged = False;
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	// StandardSubsystems.Properties
	PropertiesManagement.FillCheckProcessing(ThisForm, Cancel, CheckedAttributes);
	// End StandardSubsystems.Properties
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(SelectedValue, ChoiceSource)
	
	If ChoiceSource.FormName = "Document.TaxInvoiceIssued.Form.DocumentForm" Then
		TaxInvoiceText = SelectedValue;
	ElsIf ChoiceSource.FormName = "CommonForm.SelectionFromOrders" Then
		OrderedProductsSelectionProcessingAtClient(SelectedValue.TempStorageInventoryAddress);
	ElsIf ChoiceSource.FormName = "Document.GoodsIssue.Form.SelectionForm" Then
		Items.Inventory.CurrentData.GoodsIssue = SelectedValue;
	ElsIf ChoiceSource.FormName = "CommonForm.ProductGLAccounts" Then
		GLAccountsChoiceProcessingAtClient(SelectedValue);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormItemEventHandlersHeader

&AtClient
Procedure AdvanceInvoicingOnChange(Item)
	FillAddedColumns(True);
EndProcedure

&AtClient
Procedure DateOnChange(Item)
	
	// Date change event processor.
	DateBeforeChange	= DocumentDate;
	DocumentDate = Object.Date;
	If Object.Date <> DateBeforeChange Then
		StructureData = GetDataDateOnChange(DateBeforeChange, SettlementCurrency);
		If StructureData.DATEDIFF <> 0 Then
			Object.Number = "";
		EndIf;
		
		If ValueIsFilled(SettlementCurrency) Then
			RecalculateExchangeRateMultiplicitySettlementCurrency(StructureData);
		EndIf;	
		
		// Generate price and currency label.
		LabelStructure = New Structure;
		LabelStructure.Insert("PriceKind",						Object.PriceKind);
		LabelStructure.Insert("DiscountKind",					Object.DiscountMarkupKind);
		LabelStructure.Insert("DocumentCurrency",				Object.DocumentCurrency);
		LabelStructure.Insert("SettlementsCurrency",			SettlementCurrency);
		LabelStructure.Insert("ExchangeRate",					Object.ExchangeRate);
		LabelStructure.Insert("AmountIncludesVAT",				Object.AmountIncludesVAT);
		LabelStructure.Insert("ForeignExchangeAccounting",	ForeignExchangeAccounting);
		LabelStructure.Insert("ExchangeRateNationalCurrency",	ExchangeRateNationalCurrency);
		LabelStructure.Insert("VATTaxation",					Object.VATTaxation);
		LabelStructure.Insert("DiscountCard",					Object.DiscountCard);
		LabelStructure.Insert("DiscountPercentByDiscountCard",	Object.DiscountPercentByDiscountCard);
		LabelStructure.Insert("RegisteredForVAT",				RegisteredForVAT);
	
		PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
		
		// DiscountCards
		// In this procedure call not modal window of question is occurred.
		RecalculateDiscountPercentAtDocumentDateChange();
		// End DiscountCards
		
		RecalculatePaymentDate(DateBeforeChange, Object.Date);
		RefillDueDateOfEPD(Object.Date);
		
	EndIf;
	
	// AutomaticDiscounts
	DocumentDateChangedManually = True;
	ClearCheckboxDiscountsAreCalculatedClient("DateOnChange");

EndProcedure

&AtClient
Procedure CompanyOnChange(Item)

	// Company change event data processor.
	Object.BankAccount	= "";
	Object.Number	= "";
	StructureData	= GetDataCompanyOnChange();
	ParentCompany = StructureData.Company;
	
	Object.ChiefAccountant	= StructureData.ChiefAccountant;
	Object.Released			= StructureData.Released;
	Object.ReleasedPosition	= StructureData.ReleasedPosition;
	
	Object.Contract = GetContractByDefault(Object.Ref, Object.Counterparty, Object.Company);
	ProcessContractChange();
	
	// Generate price and currency label.
	LabelStructure = New Structure;
	LabelStructure.Insert("PriceKind",						Object.PriceKind);
	LabelStructure.Insert("DiscountKind",					Object.DiscountMarkupKind);
	LabelStructure.Insert("DocumentCurrency",				Object.DocumentCurrency);
	LabelStructure.Insert("SettlementsCurrency",			SettlementCurrency);
	LabelStructure.Insert("ExchangeRate",					Object.ExchangeRate);
	LabelStructure.Insert("AmountIncludesVAT",				Object.AmountIncludesVAT);
	LabelStructure.Insert("ForeignExchangeAccounting",		ForeignExchangeAccounting);
	LabelStructure.Insert("ExchangeRateNationalCurrency",	ExchangeRateNationalCurrency);
	LabelStructure.Insert("VATTaxation",					Object.VATTaxation);
	LabelStructure.Insert("DiscountCard",					Object.DiscountCard);
	LabelStructure.Insert("DiscountPercentByDiscountCard",	Object.DiscountPercentByDiscountCard);
	LabelStructure.Insert("RegisteredForVAT",				RegisteredForVAT);
	
	PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
	
	If Object.SetPaymentTerms
		AND ValueIsFilled(Object.CashAssetsType) Then
		
		RecalculatePaymentCalendar();
		RecalculateSubtotal();
		FillPaymentScedule();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CounterpartyOnChange(Item)
	
	CounterpartyBeforeChange = Counterparty;
	CounterpartyDoSettlementsByOrdersBeforeChange = CounterpartyDoSettlementsByOrders;
	Counterparty = Object.Counterparty;
	
	If CounterpartyBeforeChange <> Object.Counterparty Then
		
		Object.CounterpartyBankAcc	= Undefined;
		
		DeliveryData = GetDeliveryData(Object.Counterparty);
		Object.DeliveryOption = DeliveryData.DeliveryOption;
		
		SetVisibleDeliveryAttributes();
		
		If DeliveryData.ShippingAddress = Undefined Then
			CommonUseClientServer.MessageToUser(NStr("en = 'There is no shipping address marked as default'"));
		Else
			Object.ShippingAddress = DeliveryData.ShippingAddress;
		EndIf;
		
		ProcessShippingAddressChange();
		
		ContractVisibleBeforeChange = Items.Contract.Visible;
		
		StructureData = GetDataCounterpartyOnChange(Object.Date, Object.DocumentCurrency, Object.Counterparty, Object.Company);
		
		// Discount cards (
		StructureData.Insert("CallFromProcedureAtCounterpartyChange", True);
		// ) Discount cards.
		
		Object.Contract = StructureData.Contract;
		ContractBeforeChange = Contract;
		Contract = Object.Contract;
		
		If Object.Prepayment.Count() > 0
			AND Object.Contract <> ContractBeforeChange Then
			
			DocumentParameters = New Structure;
			DocumentParameters.Insert("CounterpartyChange", True);
			DocumentParameters.Insert("ContractData", StructureData);
			DocumentParameters.Insert("CounterpartyBeforeChange", CounterpartyBeforeChange);
			DocumentParameters.Insert("CounterpartyDoSettlementsByOrdersBeforeChange", CounterpartyDoSettlementsByOrdersBeforeChange);
			DocumentParameters.Insert("ContractVisibleBeforeChange", ContractVisibleBeforeChange);
			DocumentParameters.Insert("ContractBeforeChange", ContractBeforeChange);
			
			NotifyDescription = New NotifyDescription("PrepaymentClearingQuestionEnd", ThisObject, DocumentParameters);
			QuestionText = NStr("en = 'Advances will be cleared. Do you want to continue?'");
			
			ShowQueryBox(NotifyDescription, QuestionText, QuestionDialogMode.YesNo);
			Return;
		EndIf;
		
		ProcessContractConditionsChange(StructureData, ContractBeforeChange);
		
	Else
		
		Object.Contract	= Contract; // Restore the cleared contract automatically.
		Object.Order	= Items.Order.TypeRestriction.AdjustValue(Order);;
		
	EndIf;
	
	Order = Object.Order;
	
	// AutomaticDiscounts
	ClearCheckboxDiscountsAreCalculatedClient("CounterpartyOnChange");
	
EndProcedure

&AtClient
Procedure ContractOnChange(Item)
	
	ProcessContractChange();
	
EndProcedure

&AtClient
Procedure ContractStartChoice(Item, ChoiceData, StandardProcessing)
	
	FormParameters = GetChoiceFormParameters(Object.Ref, Object.Company, Object.Counterparty, Object.Contract);
	If FormParameters.ControlContractChoice Then
		
		StandardProcessing = False;
		OpenForm("Catalog.CounterpartyContracts.Form.ChoiceForm", FormParameters, Item);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OrderStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	StructureFilter = New Structure();
	StructureFilter.Insert("Company",		Object.Company);
	StructureFilter.Insert("Counterparty",	Object.Counterparty);
	
	If ValueIsFilled(Object.Contract) Then
		StructureFilter.Insert("Contract", Object.Contract);
	EndIf;
	
	ParameterStructure = New Structure("Filter", StructureFilter);
	
	OpenForm("CommonForm.SelectDocumentOrder", ParameterStructure, Item);
	
EndProcedure

&AtClient
Procedure OrderChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	StandardProcessing = False;
	
	ProcessOrderDocumentSelection(SelectedValue);

EndProcedure

&AtClient
Procedure OrderOnChange(Item)
	
	If Object.Prepayment.Count() > 0
		AND Object.Order <> Order Then
		
		Mode = QuestionDialogMode.YesNo;
		Response = Undefined;
		ShowQueryBox(New NotifyDescription("OrderOnChangeEnd", ThisObject), NStr("en = 'Advances will be cleared. Do you want to continue?'"), Mode, 0);
		Return;
		
	EndIf;
	
	If Order <> Object.Order
		And ValueIsFilled(Object.Order) Then
		SalesRep = SalesRep(Object.Order);
		If ValueIsFilled(SalesRep) Then
			For Each Row In Object.Inventory Do
				Row.SalesRep = SalesRep;
			EndDo;
		EndIf;
	EndIf;
	
	OrderOnChangeFragment();
	
EndProcedure

&AtClient
Procedure OrderOnChangeEnd(Result, AdditionalParameters) Export
	
	Response = Result;
	If Response = DialogReturnCode.Yes Then
		Object.Prepayment.Clear();
	Else
		Object.Order = Items.Order.TypeRestriction.AdjustValue(Order);
		Return;
	EndIf;
	
	OrderOnChangeFragment();
	
EndProcedure

&AtClient
Procedure OrderOnChangeFragment()
	
	Order = Object.Order;
	
	// AutomaticDiscounts
	ClearCheckboxDiscountsAreCalculatedClient("OrderOnChange");
	// End AutomaticDiscounts
	
EndProcedure

&AtClient
Procedure DeliveryOptionOnChange(Item)
	SetVisibleDeliveryAttributes();
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

&AtClient
Procedure SalesRepOnChange(Item)
	
	If Object.Inventory.Count() > 2 Then
		
		SalesRep = Object.Inventory[0].SalesRep;
		For Each InventoryRow In Object.Inventory Do
			InventoryRow.SalesRep = SalesRep;
		EndDo;
		
	EndIf;
		
EndProcedure

&AtClient
Procedure StructuralUnitOnChange(Item)
	FillAddedColumns(True);
EndProcedure

#EndRegion

#Region FormItemEventHandlersFormTableInventory

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
Procedure InventoryProductsOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	StructureData = New Structure();
	StructureData.Insert("Company"				, Object.Company);
	StructureData.Insert("Products"				, TabularSectionRow.Products);
	StructureData.Insert("Characteristic"		, TabularSectionRow.Characteristic);
	StructureData.Insert("VATTaxation"			, Object.VATTaxation);
	
	If ValueIsFilled(Object.PriceKind) Then
		
		StructureData.Insert("ProcessingDate"		, Object.Date);
		StructureData.Insert("DocumentCurrency"		, Object.DocumentCurrency);
		StructureData.Insert("AmountIncludesVAT"	, Object.AmountIncludesVAT);
		StructureData.Insert("PriceKind"			, Object.PriceKind);
		StructureData.Insert("Factor"				, 1);
		StructureData.Insert("DiscountMarkupKind"	, Object.DiscountMarkupKind);
	
	EndIf;
	
	// DiscountCards
	StructureData.Insert("DiscountCard", Object.DiscountCard);
	StructureData.Insert("DiscountPercentByDiscountCard", Object.DiscountPercentByDiscountCard);
	// End DiscountCards
	
	AddGLAccountsToStructure(StructureData, TabularSectionRow);	
	StructureData.Insert("ObjectParameters", GLAccountsInDocumentsClientServer.GetObjectParameters(Object));
	StructureData = GetDataProductsOnChange(StructureData);
	
	FillPropertyValues(TabularSectionRow, StructureData); 
	ThisIsNewRow = False;
	
	TabularSectionRow.Quantity				= 1;
	TabularSectionRow.Content				= "";
	TabularSectionRow.ProductsTypeInventory = StructureData.ProductsTypeInventory;
	
	// Serial numbers
	WorkWithSerialNumbersClientServer.DeleteSerialNumbersByConnectionKey(Object.SerialNumbers, TabularSectionRow,,UseSerialNumbersBalance);
	
	CalculateAmountInTabularSectionLine();
	
EndProcedure

&AtClient
Procedure InventoryCharacteristicOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
		
	StructureData = New Structure;
	StructureData.Insert("Products",	TabularSectionRow.Products);
	StructureData.Insert("Characteristic",		TabularSectionRow.Characteristic);
		
	If ValueIsFilled(Object.PriceKind) Then
		
		StructureData.Insert("ProcessingDate",		Object.Date);
		StructureData.Insert("DocumentCurrency",	Object.DocumentCurrency);
		StructureData.Insert("AmountIncludesVAT",	Object.AmountIncludesVAT);
		
		StructureData.Insert("VATRate", 			TabularSectionRow.VATRate);
		StructureData.Insert("Price",			 	TabularSectionRow.Price);
		
		StructureData.Insert("PriceKind",		Object.PriceKind);
		StructureData.Insert("MeasurementUnit",	TabularSectionRow.MeasurementUnit);
		
	EndIf;
				
	StructureData = GetDataCharacteristicOnChange(StructureData);
	
	TabularSectionRow.Price		= StructureData.Price;
	TabularSectionRow.Content	= "";
			
	CalculateAmountInTabularSectionLine();
	
EndProcedure

&AtClient
Procedure InventoryBatchOnChange(Item)
	
	TabRow = Items.Inventory.CurrentData;
	
	StructureData = New Structure();
	AddGLAccountsToStructure(StructureData, TabRow);
	StructureData.Insert("Products",	TabRow.Products);
	StructureData.Insert("GoodsIssue",	TabRow.GoodsIssue);
	StructureData.Insert("Batch",	TabRow.Batch);
	
	InventoryBatchOnChangeAtServer(StructureData);
	FillPropertyValues(TabRow, StructureData);
	
EndProcedure

&AtServer
Procedure InventoryBatchOnChangeAtServer(StructureData)
	
	StructureData.Insert("ObjectParameters", GLAccountsInDocumentsClientServer.GetObjectParameters(Object));
	ProductsTypeInventory = CommonUse.ObjectAttributeValue(StructureData.Products, "ProductsType") = Enums.ProductsTypes.InventoryItem;  
	StructureData.Insert("ProductsTypeInventory", ProductsTypeInventory);
	GLAccounts = GLAccountsInDocuments.GetProductListGLAccounts(StructureData);
	FillProductGLAccounts(StructureData, GLAccounts);		
	
EndProcedure

&AtClient
Procedure InventoryContentAutoComplete(Item, Text, ChoiceData, Parameters, Wait, StandardProcessing)
	
	If Wait = 0 Then
		
		StandardProcessing = False;
		
		TabularSectionRow	= Items.Inventory.CurrentData;
		ContentPattern		= DriveServer.GetContentText(TabularSectionRow.Products, TabularSectionRow.Characteristic);
		
		ChoiceData = New ValueList;
		ChoiceData.Add(ContentPattern);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure InventoryGoodsIssueChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	InventoryGoodsIssueChoiceEnd(SelectedValue);
	
EndProcedure

&AtServer
Procedure InventoryGoodsIssueOnChangeAtServer(StructureData)
	
	StructureData.Insert("ObjectParameters", GLAccountsInDocumentsClientServer.GetObjectParameters(Object));
	ProductsTypeInventory = CommonUse.ObjectAttributeValue(StructureData.Products, "ProductsType") = Enums.ProductsTypes.InventoryItem;  
	StructureData.Insert("ProductsTypeInventory", ProductsTypeInventory);
	GLAccounts = GLAccountsInDocuments.GetProductListGLAccounts(StructureData);
	FillProductGLAccounts(StructureData, GLAccounts);		
	
EndProcedure

&AtClient
Procedure InventoryGoodsIssueOnChange(Item)
	
	TabRow = Items.Inventory.CurrentData;
	InventoryGoodsIssueChoiceEnd(TabRow.GoodsIssue);
	
EndProcedure

&AtClient
Procedure InventoryQuantityOnChange(Item)
	
	CalculateAmountInTabularSectionLine();
	
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
	
EndProcedure

&AtClient
Procedure InventoryDiscountMarkupPercentOnChange(Item)
	
	CalculateAmountInTabularSectionLine();
	
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
	
	CalculateVATAmount(TabularSectionRow);
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
	RecalculatePaymentCalendar();
	RefillDiscountAmountOfEPD();
	
	// AutomaticDiscounts.
	ClearCheckboxDiscountsAreCalculatedClient("CalculateAmountInTabularSectionLine", "Amount");
	
	TabularSectionRow.AutomaticDiscountsPercent = 0;
	TabularSectionRow.AutomaticDiscountAmount = 0;
	TabularSectionRow.TotalDiscountAmountIsMoreThanAmount = False;
	// End AutomaticDiscounts
	
EndProcedure

&AtClient
Procedure InventoryVATRateOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	CalculateVATAmount(TabularSectionRow);
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
	RecalculatePaymentCalendar();
	RefillDiscountAmountOfEPD();
	
EndProcedure

&AtClient
Procedure InventoryVATAmountOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
	RecalculatePaymentCalendar();
	RefillDiscountAmountOfEPD();
	
EndProcedure

#EndRegion

#Region FormItemEventHandlersFormTablePrepayment

&AtClient
Procedure PrepaymentSettlementsAmountOnChange(Item)
	
	TablePartRow = Items.Prepayment.CurrentData;
		
	TablePartRow.ExchangeRate = ?(
		TablePartRow.ExchangeRate = 0,
			?(Object.ExchangeRate = 0,
			1,
			Object.ExchangeRate),
		TablePartRow.ExchangeRate
	);
	
	TablePartRow.Multiplicity = ?(
		TablePartRow.Multiplicity = 0,
			?(Object.Multiplicity = 0,
			1,
			Object.Multiplicity),
		TablePartRow.Multiplicity
	);
	
	TablePartRow.PaymentAmount = DriveClient.RecalculateFromCurrencyToCurrency(
		TablePartRow.SettlementsAmount,
		TablePartRow.ExchangeRate,
		?(Object.DocumentCurrency = FunctionalCurrency, ExchangeRateNationalCurrency, Object.ExchangeRate),
		TablePartRow.Multiplicity,
		?(Object.DocumentCurrency = FunctionalCurrency, MultiplicityNationalCurrency, Object.Multiplicity)
	);

EndProcedure

&AtClient
Procedure PrepaymentPaymentAmountOnChange(Item)
	
	TablePartRow = Items.Prepayment.CurrentData;
	
	TablePartRow.ExchangeRate = ?(
		TablePartRow.ExchangeRate = 0,
		1,
		TablePartRow.ExchangeRate
	);
	
	TablePartRow.Multiplicity = 1;
	
	TablePartRow.ExchangeRate =
		?(TablePartRow.SettlementsAmount = 0,
			1,
			TablePartRow.PaymentAmount
		  / TablePartRow.SettlementsAmount
		  * Object.ExchangeRate
	);
	
EndProcedure

&AtClient
Procedure PrepaymentDocumentOnChange(Item)
	
	TablePartRow = Items.Prepayment.CurrentData;
	
	If ValueIsFilled(TablePartRow.Document) Then
		
		StructureData = GetDataDocumentOnChange(TablePartRow.Document);
		
		TablePartRow.SettlementsAmount = StructureData.SettlementsAmount;
		
		TablePartRow.ExchangeRate = 
			?(TablePartRow.ExchangeRate = 0,
				?(Object.ExchangeRate = 0,
				1,
				Object.ExchangeRate),
			TablePartRow.ExchangeRate
		);
		
		TablePartRow.Multiplicity =
			?(TablePartRow.Multiplicity = 0,
				?(Object.Multiplicity = 0,
				1,
				Object.Multiplicity),
			TablePartRow.Multiplicity
		);
			
		TablePartRow.PaymentAmount = DriveClient.RecalculateFromCurrencyToCurrency(
			TablePartRow.SettlementsAmount,
			TablePartRow.ExchangeRate,
			?(Object.DocumentCurrency = FunctionalCurrency, ExchangeRateNationalCurrency, Object.ExchangeRate),
			TablePartRow.Multiplicity,
			?(Object.DocumentCurrency = FunctionalCurrency, MultiplicityNationalCurrency, Object.Multiplicity)
		);
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Function GetDataDocumentOnChange(Document)
	
	StructureData = New Structure();
	
	StructureData.Insert("SettlementsAmount", Document.PaymentDetails.Total("SettlementsAmount"));
	
	Return StructureData;
	
EndFunction

&AtClient
Procedure PrepaymentExchangeRateOnChange(Item)
	
	TablePartRow = Items.Prepayment.CurrentData;
	
	TablePartRow.ExchangeRate = ?(
		TablePartRow.ExchangeRate = 0,
		1,
		TablePartRow.ExchangeRate
	);
	
	TablePartRow.Multiplicity = ?(
		TablePartRow.Multiplicity = 0,
		1,
		TablePartRow.Multiplicity
	);
	
	TablePartRow.PaymentAmount = DriveClient.RecalculateFromCurrencyToCurrency(
		TablePartRow.SettlementsAmount,
		TablePartRow.ExchangeRate,
		?(Object.DocumentCurrency = FunctionalCurrency, ExchangeRateNationalCurrency, Object.ExchangeRate),
		TablePartRow.Multiplicity,
		?(Object.DocumentCurrency = FunctionalCurrency, MultiplicityNationalCurrency, Object.Multiplicity)
	);
	
EndProcedure

&AtClient
Procedure PrepaymentMultiplicityOnChange(Item)
	
	TablePartRow = Items.Prepayment.CurrentData;
	
	TablePartRow.ExchangeRate = ?(
		TablePartRow.ExchangeRate = 0,
		1,
		TablePartRow.ExchangeRate
	);
	
	TablePartRow.Multiplicity = ?(
		TablePartRow.Multiplicity = 0,
		1,
		TablePartRow.Multiplicity
	);
	
	TablePartRow.PaymentAmount = DriveClient.RecalculateFromCurrencyToCurrency(
		TablePartRow.SettlementsAmount,
		TablePartRow.ExchangeRate,
		?(Object.DocumentCurrency = FunctionalCurrency, ExchangeRateNationalCurrency, Object.ExchangeRate),
		TablePartRow.Multiplicity,
		?(Object.DocumentCurrency = FunctionalCurrency, MultiplicityNationalCurrency, Object.Multiplicity)
	);
	
EndProcedure

#EndRegion

#Region TableEventHandlers

&AtClient
Procedure EditPricesAndCurrency(Item, StandardProcessing)
	
	StandardProcessing = False;
	ProcessChangesOnButtonPricesAndCurrencies(Object.DocumentCurrency);
	Modified = True;
	
EndProcedure

&AtClient
Procedure FillByBasis(Command)
	
	Response = Undefined;
	
	ShowQueryBox(New NotifyDescription("FillByBasisEnd", ThisObject), NStr("en = 'Do you want to refill the sales invoice?'"), QuestionDialogMode.YesNo, 0);
	
EndProcedure

&AtClient
Procedure FillByBasisEnd(Result, AdditionalParameters) Export
    
    Response = Result;
    If Response = DialogReturnCode.Yes Then
        FillByDocument(Object.BasisDocument);
        SetVisibleAndEnabled();
    EndIf;

EndProcedure

&AtClient
Procedure FillByOrder(Command)
	
	Response = Undefined;
	
	ShowQueryBox(New NotifyDescription("FillByOrderEnd", ThisObject), NStr("en = 'The document will be filled according to the ""Sales order."" Continue?'"), QuestionDialogMode.YesNo, 0);
	
EndProcedure

&AtClient
Procedure FillByOrderEnd(Result, AdditionalParameters) Export
    
    Response = Result;
    If Response = DialogReturnCode.Yes Then
        FillByDocument(Object.Order);
        SetVisibleAndEnabled();
    EndIf;

EndProcedure

&AtClient
Procedure EditPrepaymentOffset(Command)
	
	If Not ValueIsFilled(Object.Counterparty) Then
		ShowMessageBox(, NStr("en = 'Please specify the customer.'"));
		Return;
	EndIf;
	
	If Not ValueIsFilled(Object.Contract) Then
		ShowMessageBox(, NStr("en = 'Please specify the contract.'"));
		Return;
	EndIf;
	
	OrdersArray = New Array;
	For Each CurItem In Object.Inventory Do
		OrderStructure = New Structure("Order, Total");
		OrderStructure.Order = ?(CurItem.Order = Undefined, PredefinedValue("Document.SalesOrder.EmptyRef"), CurItem.Order);
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
		ParentCompany, // Counterparty
		?(CounterpartyDoSettlementsByOrders, ?(OrderInHeader, Object.Order, OrdersArray), Undefined), // Order
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
	OpenForm("CommonForm.SelectAdvancesReceivedFromTheCustomer",
		SelectionParameters,,,,,
		New NotifyDescription("EditPrepaymentOffsetEnd",
			ThisObject,
			New Structure("AddressPrepaymentInStorage, SelectionParameters", AddressPrepaymentInStorage, SelectionParameters)));
	
EndProcedure

&AtClient
Procedure EditPrepaymentOffsetEnd(Result, AdditionalParameters) Export
	
	AddressPrepaymentInStorage = AdditionalParameters.AddressPrepaymentInStorage;
	SelectionParameters = AdditionalParameters.SelectionParameters;
	
	ReturnCode = Result;
	
	EditPrepaymentOffsetFragment(AddressPrepaymentInStorage, ReturnCode);
	
EndProcedure

&AtClient
Procedure EditPrepaymentOffsetFragment(Val AddressPrepaymentInStorage, Val ReturnCode)
	
	If ReturnCode = DialogReturnCode.OK Then
		GetPrepaymentFromStorage(AddressPrepaymentInStorage);
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
	
	If TypeOf(Result) = Type("Array") 
	   AND Result.Count() > 0 Then
		BarcodesReceived(Result);
	EndIf;
	
EndProcedure
// End Peripherals

// Procedure - clicking handler on the hyperlink InvoiceText.
//
&AtClient
Procedure TaxInvoiceTextClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	WorkWithVATClient.OpenTaxInvoice(ThisForm);
	
EndProcedure

&AtClient
Procedure DocumentSetup(Command)
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("SalesOrderPositionInShipmentDocuments", 	Object.SalesOrderPosition);
	ParametersStructure.Insert("WereMadeChanges",							False);
	
	InvCount = Object.Inventory.Count();
	If InvCount > 1 Then
		CurrOrder = Object.Inventory[0].Order;
		MultipleOrders = False;
		For Index = 1 To InvCount - 1 Do
			If CurrOrder <> Object.Inventory[Index].Order Then
				MultipleOrders = True;
				Break;
			EndIf;
			CurrOrder = Object.Inventory[Index].Order;
		EndDo;
		If MultipleOrders Then
			ParametersStructure.Insert("ReadOnly", True);
		EndIf;
	EndIf;
	
	OpenForm("CommonForm.DocumentSetup", ParametersStructure,,,,, New NotifyDescription("DocumentSettingEnd", ThisObject));
	
EndProcedure

&AtClient
Procedure DocumentSettingEnd(Result, AdditionalParameters) Export
	
	StructureDocumentSetting = Result;
	If TypeOf(StructureDocumentSetting) = Type("Structure") AND StructureDocumentSetting.WereMadeChanges Then
		
		Object.SalesOrderPosition = StructureDocumentSetting.SalesOrderPositionInShipmentDocuments;
		If Object.SalesOrderPosition = PredefinedValue("Enum.AttributeStationing.InHeader") Then
			If Object.Inventory.Count() Then
				
				FirstRow = Object.Inventory[0];
				Object.Order = FirstRow.Order;
				SalesRep = FirstRow.SalesRep;
				
				For Each InventoryRow In Object.Inventory Do
					InventoryRow.SalesRep = SalesRep;
				EndDo;
				
			EndIf;
		ElsIf Object.SalesOrderPosition = PredefinedValue("Enum.AttributeStationing.InTabularSection") Then
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
		SetVisibleSalesRep();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ChangeReserveFillByReserves(Command)
	
	If Object.Inventory.Count() = 0 Then
		Message = New UserMessage;
		Message.Text = NStr("en = 'There are no products to reserve.'");
		Message.Message();
		Return;
	EndIf;
	
	FillColumnReserveByReservesAtServer();
	
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
Procedure InventoryGoodsIssueStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	ParametersStructure = New Structure;
	
	If Object.SalesOrderPosition = PredefinedValue("Enum.AttributeStationing.InHeader") Then
		ParametersStructure.Insert("OrderFilter", Object.Order);
	Else
		ParametersStructure.Insert("OrderFilter", Items.Inventory.CurrentData.Order);
	EndIf;
	
	NotifyDescription = New NotifyDescription("InventoryGoodsIssueChoiceEnd", ThisObject);
	
	OpenForm("Document.GoodsIssue.ChoiceForm", ParametersStructure, ThisObject,,,, NotifyDescription);
	
EndProcedure

&AtClient
Procedure InventoryGoodsIssueChoiceEnd(SelectedValue, AdditionalParameters = Undefined) Export
	
	If SelectedValue = Undefined Then
		Return;
	EndIf;
	
	TabRow = Items.Inventory.CurrentData;
	
	StructureData = New Structure();
	AddGLAccountsToStructure(StructureData, TabRow);
	StructureData.Insert("Products",	TabRow.Products);
	StructureData.Insert("GoodsIssue",	SelectedValue);

	InventoryGoodsIssueOnChangeAtServer(StructureData);
	FillPropertyValues(TabRow, StructureData);
	
EndProcedure

&AtClient
Procedure AddGLAccountsToStructure(StructureData, TabRow)
	
	StructureData.Insert("ProductsTypeInventory",	TabRow.ProductsTypeInventory);
	StructureData.Insert("Batch",					TabRow.Batch);
	StructureData.Insert("GoodsIssue",				TabRow.GoodsIssue);
	StructureData.Insert("GLAccounts",				TabRow.GLAccounts);
	StructureData.Insert("GLAccountsFilled",		TabRow.GLAccountsFilled);
	StructureData.Insert("InventoryGLAccount",		TabRow.InventoryGLAccount);
	StructureData.Insert("RevenueGLAccount",		TabRow.RevenueGLAccount);
	StructureData.Insert("COGSGLAccount",			TabRow.COGSGLAccount);
	StructureData.Insert("VATOutputGLAccount",		TabRow.VATOutputGLAccount);
	StructureData.Insert("InventoryReceivedGLAccount",			TabRow.InventoryReceivedGLAccount);
	StructureData.Insert("GoodsShippedNotInvoicedGLAccount",	TabRow.GoodsShippedNotInvoicedGLAccount);
	StructureData.Insert("UnearnedRevenueGLAccount",			TabRow.UnearnedRevenueGLAccount);
	
EndProcedure

&AtServerNoContext
Procedure FillProductGLAccounts(StructureData, GLAccounts)

	GLAccountsForFilling = GetGLAccountsStructure(StructureData);
	FillPropertyValues(GLAccountsForFilling, GLAccounts[StructureData.Products]);
	GLAccountsInDocumentsClientServer.FillProductGLAccountsDescription(StructureData, GLAccountsForFilling);
	
EndProcedure

&AtClient
Procedure InventoryGLAccountsStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	SelectedRow = Items.Inventory.CurrentRow;
	OpenProductGLAccountsForm(SelectedRow);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

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
		Items.InventoryTotalAmountOfVAT.Visible = True;
		Items.PaymentVATAmount.Visible = True;
		Items.PaymentCalendarPayVATAmount.Visible = True;
		
	Else
		
		Items.InventoryVATRate.Visible = False;
		Items.InventoryVATAmount.Visible = False;
		Items.InventoryAmountTotal.Visible = False;
		Items.InventoryTotalAmountOfVAT.Visible = False;
		Items.PaymentVATAmount.Visible = False;
		Items.PaymentCalendarPayVATAmount.Visible = False;
		
	EndIf;
	
	FillAddedColumns();
	SetContractVisible();
	
EndProcedure

&AtServer
Function GetDataDateOnChange(DateBeforeChange, SettlementsCurrency)
	
	DATEDIFF = DriveServer.CheckDocumentNumber(Object.Ref, Object.Date, DateBeforeChange);
	CurrencyRateRepetition = InformationRegisters.ExchangeRates.GetLast(Object.Date, New Structure("Currency", SettlementCurrency));
		
	StructureData = New Structure("DATEDIFF, CurrencyRateRepetition", DATEDIFF, CurrencyRateRepetition); 
	
	FillVATRateByCompanyVATTaxation();
	SetAccountingPolicyValues();
	SetTaxInvoiceText();
	SetVisibleAndEnabled();
	
	Return StructureData;
	
EndFunction

&AtServer
Function GetDataCompanyOnChange()
	
	StructureData = New Structure();
	StructureData.Insert("Company", DriveServer.GetCompany(Object.Company));
	
	ResponsiblePersons = DriveServer.OrganizationalUnitsResponsiblePersons(Object.Company, Object.Date);
	
	StructureData.Insert("ChiefAccountant", ResponsiblePersons.ChiefAccountant);
	StructureData.Insert("Released", ResponsiblePersons.WarehouseSupervisor);
	StructureData.Insert("ReleasedPosition", ResponsiblePersons.WarehouseSupervisorPositionRef);
	
	FillVATRateByCompanyVATTaxation();
	FillAddedColumns(True);
	SetAccountingPolicyValues();
	SetTaxInvoiceText();
	SetVisibleAndEnabled();
	
	Return StructureData;
	
EndFunction

&AtServerNoContext
Function GetDataProductsOnChange(StructureData)
	
	StructureData.Insert("MeasurementUnit", StructureData.Products.MeasurementUnit);
	StructureData.Insert("ProductsTypeInventory", StructureData.Products.ProductsType = PredefinedValue("Enum.ProductsTypes.InventoryItem"));
	
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
	
	GLAccountsInDocuments.FillProductGLAccountsInStructure(StructureData);
	
	Return StructureData;
	
EndFunction

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
	
	ContractByDefault = GetContractByDefault(Object.Ref, Counterparty, Company);
	
	FillVATRateByVATTaxation();
	
	StructureData = New Structure();
	
	StructureData.Insert("Contract", ContractByDefault);
	StructureData.Insert("ContractDescription", ContractByDefault.Description);
	StructureData.Insert("SettlementsCurrency", ContractByDefault.SettlementsCurrency);
	StructureData.Insert("SettlementsCurrencyRateRepetition",
							InformationRegisters.ExchangeRates.GetLast(Date, New Structure("Currency", ContractByDefault.SettlementsCurrency)));
	StructureData.Insert("SettlementsInStandardUnits", ContractByDefault.SettlementsInStandardUnits);
	StructureData.Insert("DiscountMarkupKind", ContractByDefault.DiscountMarkupKind);
	StructureData.Insert("PriceKind", ContractByDefault.PriceKind);
	StructureData.Insert("AmountIncludesVAT",
							?(ValueIsFilled(ContractByDefault.PriceKind), ContractByDefault.PriceKind.PriceIncludesVAT, Undefined));
	
	SetContractVisible();
	
	Return StructureData;
	
EndFunction

&AtServerNoContext
Function GetDataContractOnChange(Date, DocumentCurrency, Contract)
		
	StructureData = New Structure();
	
	StructureData.Insert("ContractDescription",					Contract.Description);
	StructureData.Insert("SettlementsCurrency",					Contract.SettlementsCurrency);
	StructureData.Insert("SettlementsCurrencyRateRepetition",	InformationRegisters.ExchangeRates.GetLast(
																Date, New Structure("Currency", Contract.SettlementsCurrency)));
	StructureData.Insert("PriceKind",							Contract.PriceKind);
	StructureData.Insert("DiscountMarkupKind",					Contract.DiscountMarkupKind);
	StructureData.Insert("SettlementsInStandardUnits",			Contract.SettlementsInStandardUnits);
	StructureData.Insert("AmountIncludesVAT",					?(ValueIsFilled(Contract.PriceKind), Contract.PriceKind.PriceIncludesVAT, Undefined));
	
	Return StructureData;
	
EndFunction

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
	
	If Object.VATTaxation = PredefinedValue("Enum.VATTaxationTypes.SubjectToVAT") Then
		
		Items.InventoryVATRate.Visible = True;
		Items.InventoryVATAmount.Visible = True;
		Items.InventoryAmountTotal.Visible = True;
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
		
	EndIf;	
	
EndProcedure

&AtClient
Procedure CalculateVATAmount(TablePartRow)
	
	VATRate = DriveReUse.GetVATRateValue(TablePartRow.VATRate);
	
	TablePartRow.VATAmount = ?(Object.AmountIncludesVAT, 
									  TablePartRow.Amount - (TablePartRow.Amount) / ((VATRate + 100) / 100),
									  TablePartRow.Amount * VATRate / 100);
	
EndProcedure

&AtClient
Procedure CalculateAmountInTabularSectionLine(TabularSectionRow = Undefined, ResetFlagDiscountsAreCalculated = True)
	
	If TabularSectionRow = Undefined Then
		TabularSectionRow = Items.Inventory.CurrentData;
	EndIf;
	
	TabularSectionRow.Amount = TabularSectionRow.Quantity * TabularSectionRow.Price;
	
	If TabularSectionRow.DiscountMarkupPercent = 100 Then
		
		TabularSectionRow.Amount = 0;
		
	ElsIf Not TabularSectionRow.DiscountMarkupPercent = 0
		AND Not TabularSectionRow.Quantity = 0 Then
		
		TabularSectionRow.Amount = TabularSectionRow.Amount * (1 - TabularSectionRow.DiscountMarkupPercent / 100);
		
	EndIf;
	
	CalculateVATAmount(TabularSectionRow);
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
	RecalculatePaymentCalendar();
	RefillDiscountAmountOfEPD();
	RecalculateSubtotal();
	
	// AutomaticDiscounts.
	If ResetFlagDiscountsAreCalculated Then
		AutomaticDiscountsRecalculationIsRequired = ClearCheckboxDiscountsAreCalculatedClient("CalculateAmountInTabularSectionLine");
	EndIf;
	
	TabularSectionRow.AutomaticDiscountsPercent = 0;
	TabularSectionRow.AutomaticDiscountAmount = 0;
	TabularSectionRow.TotalDiscountAmountIsMoreThanAmount = False;
	// End AutomaticDiscounts
	
	// Serial numbers
	If UseSerialNumbersBalance<>Undefined Then
		WorkWithSerialNumbersClientServer.UpdateSerialNumbersQuantity(Object, TabularSectionRow);
	EndIf;
	
EndProcedure

&AtServer
Procedure RecalculateSubtotal()
	Totals = DriveServer.CalculateSubtotal(Object.Inventory.Unload(), Object.AmountIncludesVAT);
	FillPropertyValues(ThisObject, Totals);
EndProcedure

&AtClient
Procedure RecalculateExchangeRateMultiplicitySettlementCurrency(StructureData)
	
	NewExchangeRate	= ?(StructureData.CurrencyRateRepetition.ExchangeRate = 0, 1, StructureData.CurrencyRateRepetition.ExchangeRate);
	NewRatio		= ?(StructureData.CurrencyRateRepetition.Multiplicity = 0, 1, StructureData.CurrencyRateRepetition.Multiplicity);
	
	If Object.ExchangeRate <> NewExchangeRate
		OR Object.Multiplicity <> NewRatio Then
		
		CurrencyRateInLetters		= String(Object.Multiplicity) + " " + TrimAll(SettlementCurrency) + " = " + String(Object.ExchangeRate) + " " + TrimAll(FunctionalCurrency);
		RateNewCurrenciesInLetters	= String(NewRatio) + " " + TrimAll(SettlementCurrency) + " = " + String(NewExchangeRate) + " " + TrimAll(FunctionalCurrency);
		
		QuestionParameters = New Structure;
		QuestionParameters.Insert("NewExchangeRate",	NewExchangeRate);
		QuestionParameters.Insert("NewRatio",			NewRatio);
		
		NotifyDescription = New NotifyDescription("QuestionOnRecalculatingPaymentCurrencyRateConversionFactorEnd", ThisObject, QuestionParameters);
		
		QuestionText = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'The exchange rate has changed.
			     |Do you want to apply %2 instead of %1?'"), 
			CurrencyRateInLetters, 
			RateNewCurrenciesInLetters);
		
		ShowQueryBox(NotifyDescription, QuestionText, QuestionDialogMode.YesNo);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure QuestionOnRecalculatingPaymentCurrencyRateConversionFactorEnd(Result, AdditionalParameters) Export

	If Result = DialogReturnCode.Yes Then
		
		Object.ExchangeRate = AdditionalParameters.NewExchangeRate;
		Object.Multiplicity = AdditionalParameters.NewRatio;
		
		For Each TabularSectionRow In Object.Prepayment Do
			TabularSectionRow.PaymentAmount = DriveClient.RecalculateFromCurrencyToCurrency(
				TabularSectionRow.SettlementsAmount,
				TabularSectionRow.ExchangeRate,
				?(Object.DocumentCurrency = FunctionalCurrency, ExchangeRateNationalCurrency, Object.ExchangeRate),
				TabularSectionRow.Multiplicity,
				?(Object.DocumentCurrency = FunctionalCurrency, MultiplicityNationalCurrency, Object.Multiplicity));
		EndDo;
			
		// Generate price and currency label.
		LabelStructure = New Structure;
		LabelStructure.Insert("PriceKind",						Object.PriceKind);
		LabelStructure.Insert("DiscountKind",					Object.DiscountMarkupKind);
		LabelStructure.Insert("DocumentCurrency",				Object.DocumentCurrency);
		LabelStructure.Insert("SettlementsCurrency",			SettlementCurrency);
		LabelStructure.Insert("ExchangeRate",					Object.ExchangeRate);
		LabelStructure.Insert("AmountIncludesVAT",				Object.AmountIncludesVAT);
		LabelStructure.Insert("ForeignExchangeAccounting",	ForeignExchangeAccounting);
		LabelStructure.Insert("ExchangeRateNationalCurrency",	ExchangeRateNationalCurrency);
		LabelStructure.Insert("VATTaxation",					Object.VATTaxation);
		LabelStructure.Insert("DiscountCard",					Object.DiscountCard);
		LabelStructure.Insert("DiscountPercentByDiscountCard",	Object.DiscountPercentByDiscountCard);
		LabelStructure.Insert("RegisteredForVAT",				RegisteredForVAT);
		
		PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
		
	EndIf;

EndProcedure

&AtClient
Procedure ProcessChangesOnButtonPricesAndCurrencies(Val SettlementsCurrencyBeforeChange, RefillPrices = False, RecalculatePrices = False, WarningText = "")
	
	// 1. Form parameter structure to fill the "Prices and Currency" form.
	ParametersStructure = New Structure;
	ParametersStructure.Insert("DocumentCurrency",	Object.DocumentCurrency);
	ParametersStructure.Insert("ExchangeRate",		Object.ExchangeRate);
	ParametersStructure.Insert("Multiplicity",		Object.Multiplicity);
	ParametersStructure.Insert("VATTaxation",		Object.VATTaxation);
	ParametersStructure.Insert("AmountIncludesVAT",	Object.AmountIncludesVAT);
	ParametersStructure.Insert("IncludeVATInPrice",	Object.IncludeVATInPrice);
	ParametersStructure.Insert("Counterparty",		Object.Counterparty);
	ParametersStructure.Insert("Contract",			Object.Contract);
	ParametersStructure.Insert("Company",			ParentCompany);
	ParametersStructure.Insert("DocumentDate",		Object.Date);
	ParametersStructure.Insert("RefillPrices",		RefillPrices);
	ParametersStructure.Insert("RecalculatePrices",	RecalculatePrices);
	ParametersStructure.Insert("WereMadeChanges",	False);
	ParametersStructure.Insert("WarningText",		WarningText);
	ParametersStructure.Insert("PriceKind",			Object.PriceKind);
	ParametersStructure.Insert("DiscountKind",		Object.DiscountMarkupKind);
	ParametersStructure.Insert("DiscountCard",		Object.DiscountCard);
	
	// Open form "Prices and Currency".
	// Refills tabular section "Costs" if changes were made in the "Price and Currency" form.
	NotifyDescription = New NotifyDescription("OpenPricesAndCurrencyFormEnd", ThisObject, New Structure("SettlementsCurrencyBeforeChange", SettlementsCurrencyBeforeChange));
	OpenForm("CommonForm.PricesAndCurrency", ParametersStructure, ThisForm,,,, NotifyDescription, FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtClient
Procedure OpenPricesAndCurrencyFormEnd(ClosingResult, AdditionalParameters) Export
	
	StructurePricesAndCurrency = ClosingResult;
	SettlementsCurrencyBeforeChange = AdditionalParameters.SettlementsCurrencyBeforeChange;
	
	If TypeOf(StructurePricesAndCurrency) = Type("Structure") AND StructurePricesAndCurrency.WereMadeChanges Then
		
		Object.PriceKind = StructurePricesAndCurrency.PriceKind;
		Object.DiscountMarkupKind = StructurePricesAndCurrency.DiscountKind;
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
		Object.DocumentCurrency = StructurePricesAndCurrency.DocumentCurrency;
		Object.ExchangeRate = StructurePricesAndCurrency.PaymentsRate;
		Object.Multiplicity = StructurePricesAndCurrency.SettlementsMultiplicity;
		Object.VATTaxation = StructurePricesAndCurrency.VATTaxation;
		Object.AmountIncludesVAT = StructurePricesAndCurrency.AmountIncludesVAT;
		Object.IncludeVATInPrice = StructurePricesAndCurrency.IncludeVATInPrice;
		
		// Recalculate prices by kind of prices.
		If StructurePricesAndCurrency.RefillPrices Then
			DriveClient.RefillTabularSectionPricesByPriceKind(ThisForm, "Inventory", True);
		EndIf;
		
		// Recalculate prices by currency.
		If Not StructurePricesAndCurrency.RefillPrices
			  AND StructurePricesAndCurrency.RecalculatePrices Then	
			DriveClient.RecalculateTabularSectionPricesByCurrency(ThisForm, SettlementsCurrencyBeforeChange, "Inventory");
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
		
		For Each TabularSectionRow In Object.Prepayment Do
			TabularSectionRow.PaymentAmount = DriveClient.RecalculateFromCurrencyToCurrency(
				TabularSectionRow.SettlementsAmount,
				TabularSectionRow.ExchangeRate,
				?(Object.DocumentCurrency = FunctionalCurrency, ExchangeRateNationalCurrency, Object.ExchangeRate),
				TabularSectionRow.Multiplicity,
				?(Object.DocumentCurrency = FunctionalCurrency, MultiplicityNationalCurrency, Object.Multiplicity));  
		EndDo;
		
		// AutomaticDiscounts
		If ClosingResult.RefillDiscounts OR ClosingResult.RefillPrices OR ClosingResult.RecalculatePrices Then
			ClearCheckboxDiscountsAreCalculatedClient("RefillByFormDataPricesAndCurrency");
		EndIf;

	EndIf;
	
	// Generate price and currency label.
	LabelStructure = New Structure;
	LabelStructure.Insert("PriceKind",						Object.PriceKind);
	LabelStructure.Insert("DiscountKind",					Object.DiscountMarkupKind);
	LabelStructure.Insert("DocumentCurrency",				Object.DocumentCurrency);
	LabelStructure.Insert("SettlementsCurrency",			SettlementCurrency);
	LabelStructure.Insert("ExchangeRate",					Object.ExchangeRate);
	LabelStructure.Insert("AmountIncludesVAT",				Object.AmountIncludesVAT);
	LabelStructure.Insert("ForeignExchangeAccounting",	ForeignExchangeAccounting);
	LabelStructure.Insert("ExchangeRateNationalCurrency",	ExchangeRateNationalCurrency);
	LabelStructure.Insert("VATTaxation",					Object.VATTaxation);
	LabelStructure.Insert("DiscountCard",					Object.DiscountCard);
	LabelStructure.Insert("DiscountPercentByDiscountCard",	Object.DiscountPercentByDiscountCard);
	LabelStructure.Insert("RegisteredForVAT",				RegisteredForVAT);
		
	PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
	
	RecalculatePaymentCalendar();
	RefillDiscountAmountOfEPD();
	OpenPricesAndCurrencyFormEndAtServer();
	
EndProcedure

&AtServer
Procedure OpenPricesAndCurrencyFormEndAtServer()
	
	RecalculateSubtotal();
	FillAddedColumns(True);
	
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
				
				NewRow.ProductsTypeInventory = BarcodeData.StructureProductsData.ProductsTypeInventory;
				
				CalculateAmountInTabularSectionLine(NewRow);
				Items.Inventory.CurrentRow = NewRow.GetID();
			Else
				NewRow = TSRowsArray[0];
				NewRow.Quantity = NewRow.Quantity + CurBarcode.Quantity;
				CalculateAmountInTabularSectionLine(NewRow);
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
Procedure FillColumnReserveByReservesAtServer()
	
	Document = FormAttributeToValue("Object");
	Document.FillColumnReserveByReserves();
	ValueToFormAttribute(Document, "Object");
	
EndProcedure

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

&AtServerNoContext
Function GetContractByDefault(Document, Counterparty, Company)
	
	If Counterparty.DoOperationsByContracts = False Then
		Return Counterparty.ContractByDefault;
	EndIf;
	
	ManagerOfCatalog = Catalogs.CounterpartyContracts;
	
	ContractTypesList = ManagerOfCatalog.GetContractKindsListForDocument(Document);
	ContractByDefault = ManagerOfCatalog.GetDefaultContractByCompanyContractKind(Counterparty, Company, ContractTypesList);
	
	Return ContractByDefault;
	
EndFunction

&AtClient
Procedure ProcessContractChange()
	
	ContractBeforeChange = Contract;
	Contract = Object.Contract;
		
	If ContractBeforeChange <> Object.Contract Then
		
		ContractData = GetDataContractOnChange(Object.Date, Object.DocumentCurrency, Object.Contract);
		
		If Object.Prepayment.Count() > 0
			AND Object.Contract <> ContractBeforeChange Then
			
			DocumentParameters = New Structure;
			DocumentParameters.Insert("ContractBeforeChange", ContractBeforeChange);
			DocumentParameters.Insert("ContractData", ContractData);
			
			NotifyDescription = New NotifyDescription("PrepaymentClearingQuestionEnd", ThisObject, DocumentParameters);
			QuestionText = NStr("en = 'Advances will be cleared. Do you want to continue?'");
			
			ShowQueryBox(NotifyDescription, QuestionText, QuestionDialogMode.YesNo);
			Return;
		EndIf;
		
		ProcessContractConditionsChange(ContractData, ContractBeforeChange);
		
		FillPaymentCalendarFromContract(SwitchTypeListOfPaymentCalendar);
		UpdatePaymentCalendar();
		
	Else
		
		Object.Order = Items.Order.TypeRestriction.AdjustValue(Order);
		
	EndIf;
	
	Order = Object.Order;
	
EndProcedure

&AtClient
Procedure PrepaymentClearingQuestionEnd(Result, AdditionalParameters) Export
	
	ContractBeforeChange = AdditionalParameters.ContractBeforeChange;
	
	If Result = DialogReturnCode.Yes Then
		Object.Prepayment.Clear();
	Else
		If AdditionalParameters.Property("CounterpartyChange") Then
			Object.Counterparty = AdditionalParameters.CounterpartyBeforeChange;
			Counterparty = AdditionalParameters.CounterpartyBeforeChange;
			CounterpartyDoSettlementsByOrders = AdditionalParameters.CounterpartyDoSettlementsByOrdersBeforeChange;
			Items.Contract.Visible = AdditionalParameters.ContractVisibleBeforeChange;
		EndIf;
		Object.Contract = ContractBeforeChange;
		Contract = ContractBeforeChange;
		Object.Order = Order;
		Return;
	EndIf;
	
	ProcessContractConditionsChange(AdditionalParameters.ContractData, ContractBeforeChange);

EndProcedure

&AtClient
Procedure ProcessContractConditionsChange(ContractData, ContractBeforeChange)
	
	SettlementsCurrencyBeforeChange = SettlementCurrency;
	SettlementCurrency = ContractData.SettlementsCurrency;
	
	If Not ContractData.AmountIncludesVAT = Undefined Then
		Object.AmountIncludesVAT = ContractData.AmountIncludesVAT;
	EndIf;
	
	If ValueIsFilled(Object.Contract) Then 
		Object.ExchangeRate	= ?(ContractData.SettlementsCurrencyRateRepetition.ExchangeRate = 0, 1, ContractData.SettlementsCurrencyRateRepetition.ExchangeRate);
		Object.Multiplicity = ?(ContractData.SettlementsCurrencyRateRepetition.Multiplicity = 0, 1, ContractData.SettlementsCurrencyRateRepetition.Multiplicity);
	EndIf;
	
	PriceKindChanged = Object.PriceKind <> ContractData.PriceKind 
		AND ValueIsFilled(ContractData.PriceKind);
		
	DiscountKindChanged = Object.DiscountMarkupKind <> ContractData.DiscountMarkupKind 
		AND ValueIsFilled(ContractData.DiscountMarkupKind);
		
	// Discount card (	
	If ContractData.Property("CallFromProcedureAtCounterpartyChange") Then
		ClearDiscountCard = ValueIsFilled(Object.DiscountCard); // Attribute DiscountCard will be cleared later.
	Else
		ClearDiscountCard = False;
	EndIf;			
	
	If ClearDiscountCard Then
		Object.DiscountCard = PredefinedValue("Catalog.DiscountCards.EmptyRef");
		Object.DiscountPercentByDiscountCard = 0;		
	EndIf;
	// ) Discount card.
			
	QueryPriceKind = ValueIsFilled(Object.Contract) AND (PriceKindChanged OR DiscountKindChanged);
	If QueryPriceKind Then
		If PriceKindChanged Then
			Object.PriceKind = ContractData.PriceKind;
		EndIf; 
		If DiscountKindChanged Then
			Object.DiscountMarkupKind = ContractData.DiscountMarkupKind;
		EndIf; 
	EndIf;
	
	OpenFormPricesAndCurrencies = (ValueIsFilled(Object.Contract) AND ValueIsFilled(SettlementCurrency)
		AND Object.Contract <> ContractBeforeChange AND SettlementsCurrencyBeforeChange <> ContractData.SettlementsCurrency)
		AND Object.DocumentCurrency <> ContractData.SettlementsCurrency
		AND Object.Inventory.Count() > 0;
	
	DocumentParameters = New Structure;
	DocumentParameters.Insert("ContractBeforeChange", ContractBeforeChange);
	DocumentParameters.Insert("SettlementsCurrencyBeforeChange", SettlementsCurrencyBeforeChange);
	DocumentParameters.Insert("ContractData", ContractData);
	
	Object.DocumentCurrency = SettlementCurrency;
	If OpenFormPricesAndCurrencies Then
		
		WarningText = "";
		If QueryPriceKind Then
			WarningText = NStr("en = 'The price and discount in the contract with counterparty differ from price and discount in the document. Perhaps you have to refill prices.'");
		EndIf;
		
		WarningText = WarningText + NStr("en = 'The settlement currency specified in the contract has changed. It is necessary to check the document currency.'");
		
		ProcessChangesOnButtonPricesAndCurrencies(SettlementsCurrencyBeforeChange, PriceKindChanged, True, WarningText);
		
	ElsIf QueryPriceKind Then
		
		RecalculationRequired = (Object.Inventory.Count() > 0);
		
		LabelStructure = New Structure;
		LabelStructure.Insert("PriceKind",						Object.PriceKind);
		LabelStructure.Insert("DiscountKind",					Object.DiscountMarkupKind);
		LabelStructure.Insert("DocumentCurrency",				Object.DocumentCurrency);
		LabelStructure.Insert("SettlementsCurrency",			SettlementCurrency);
		LabelStructure.Insert("ExchangeRate",					Object.ExchangeRate);
		LabelStructure.Insert("AmountIncludesVAT",				Object.AmountIncludesVAT);
		LabelStructure.Insert("ForeignExchangeAccounting",		ForeignExchangeAccounting);
		LabelStructure.Insert("ExchangeRateNationalCurrency",	ExchangeRateNationalCurrency);
		LabelStructure.Insert("VATTaxation",					Object.VATTaxation);
		LabelStructure.Insert("DiscountCard",					Object.DiscountCard);
		LabelStructure.Insert("DiscountPercentByDiscountCard",	Object.DiscountPercentByDiscountCard);
		LabelStructure.Insert("RegisteredForVAT",				RegisteredForVAT);
		
		PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
		
		If RecalculationRequired Then
			
			QuestionText = NStr("en = 'The price and discount in the contract with counterparty differ from price and discount in the document. Recalculate the document according to the contract?'");
			
			NotifyDescription = New NotifyDescription("RecalculationQuestionByPriceKindEnd", ThisObject, DocumentParameters);
			ShowQueryBox(NotifyDescription, QuestionText, QuestionDialogMode.YesNo);
			
		EndIf;
		
	Else
		
		LabelStructure = New Structure;
		LabelStructure.Insert("PriceKind",						Object.PriceKind);
		LabelStructure.Insert("DiscountKind",					Object.DiscountMarkupKind);
		LabelStructure.Insert("DocumentCurrency",				Object.DocumentCurrency);
		LabelStructure.Insert("SettlementsCurrency",			SettlementCurrency);
		LabelStructure.Insert("ExchangeRate",					Object.ExchangeRate);
		LabelStructure.Insert("AmountIncludesVAT",				Object.AmountIncludesVAT);
		LabelStructure.Insert("ForeignExchangeAccounting",		ForeignExchangeAccounting);
		LabelStructure.Insert("ExchangeRateNationalCurrency",	ExchangeRateNationalCurrency);
		LabelStructure.Insert("VATTaxation",					Object.VATTaxation);
		LabelStructure.Insert("DiscountCard",					Object.DiscountCard);
		LabelStructure.Insert("DiscountPercentByDiscountCard",	Object.DiscountPercentByDiscountCard);
		LabelStructure.Insert("RegisteredForVAT",				RegisteredForVAT);
		
		PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
		
	EndIf;
	
	// Clear order.
	For Each CurRow In Object.Inventory Do
		CurRow.Order = Undefined;
	EndDo;
	
	If ContractBeforeChange <> Object.Contract Then
		FillPaymentCalendarFromContract(SwitchTypeListOfPaymentCalendar);
		FillEarlyPaymentDiscounts();
		UpdatePaymentCalendar();
		SetVisibleEarlyPaymentDiscounts();
	EndIf;
	
EndProcedure

&AtClient
Procedure RecalculationQuestionByPriceKindEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		
		DriveClient.RefillTabularSectionPricesByPriceKind(ThisForm, "Inventory", True);
		
	EndIf;
	
EndProcedure

&AtServer
Procedure FillPrepayment(CurrentObject)
	
	CurrentObject.FillPrepayment();
	
EndProcedure

&AtServer
Procedure SetTaxInvoiceText()
	Items.TaxInvoiceText.Visible = WorkWithVAT.GetUseTaxInvoiceForPostingVAT(Object.Date, Object.Company)
EndProcedure

&AtServer
Procedure SetAccountingPolicyValues()

	AccountingPolicy = InformationRegisters.AccountingPolicy.GetAccountingPolicy(DocumentDate, Object.Company);
	RegisteredForVAT = AccountingPolicy.RegisteredForVAT;
	UseGoodsReturnFromCustomer = AccountingPolicy.UseGoodsReturnFromCustomer;
	
EndProcedure

#EndRegion

#Region WorkWithPick

&AtClient
Procedure Pick(Command)
	
	TabularSectionName	= "Inventory";
	DocumentPresentaion	= NStr("en = 'sales invoice'");
	SelectionParameters	= DriveClient.GetSelectionParameters(ThisObject, TabularSectionName, DocumentPresentaion, True, True, True);
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
		|PriceKind,
		|DiscountMarkupKind,
		|DiscountCard,
		|DocumentCurrency,
		|AmountIncludesVAT,
		|IncludeVATInPrice,
		|VATTaxation,
		|Order");
	FillPropertyValues(SelectionParameters, Object);
	
	SelectionParameters.Insert("TempStorageInventoryAddress", PutInventoryToTempStorage());
	SelectionParameters.Insert("ShowGoodsIssue", True);

	OpenForm("CommonForm.SelectionFromOrders", SelectionParameters, ThisForm, , , , , FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtServer
Function PutInventoryToTempStorage()
	
	InventoryTable = Object.Inventory.Unload();
	InventoryTable.Columns.Add("SalesInvoice", New TypeDescription("DocumentRef.SalesInvoice"));
	
	If ValueIsFilled(Object.Order) Then
		For Each InventoryRow In InventoryTable Do
			If Not ValueIsFilled(InventoryRow.Order) Then
				InventoryRow.Order = Object.Order;
			EndIf;
		EndDo;
	EndIf;
	
	Return PutToTempStorage(InventoryTable);
	
EndFunction

&AtClient
Procedure OrderedProductsSelectionProcessingAtClient(TempStorageInventoryAddress)
	OrderedProductsSelectionProcessingAtServer(TempStorageInventoryAddress);
	RecalculatePaymentCalendar();
	RefillDiscountAmountOfEPD();
	CalculateDiscountsMarkupsClient();
	RecalculateSubtotal();
EndProcedure

&AtServer
Procedure OrderedProductsSelectionProcessingAtServer(TempStorageInventoryAddress)
	
	TablesStructure = GetFromTempStorage(TempStorageInventoryAddress);
	
	InventorySearchStructure = New Structure("Products, Characteristic, Batch, Order, GoodsIssue");
	DiscountsMarkupsSearchStructure = New Structure("ConnectionKey");
	
	ObjectParameters = GLAccountsInDocumentsClientServer.GetObjectParameters(Object);
	
	For Each InventoryRow In TablesStructure.Inventory Do
		
		FillPropertyValues(InventorySearchStructure, InventoryRow);
		
		TS_InventoryRows = Object.Inventory.FindRows(InventorySearchStructure);
		For Each TS_InventoryRow In TS_InventoryRows Do
			Object.Inventory.Delete(TS_InventoryRow);
		EndDo;
			
		TS_InventoryRow = Object.Inventory.Add();
		FillPropertyValues(TS_InventoryRow, InventoryRow);
		
		StructureData = GetStructureData(ObjectParameters, TS_InventoryRow);
		GLAccounts = GLAccountsInDocuments.GetProductListGLAccounts(StructureData);
		FillProductGLAccounts(StructureData, GLAccounts);		
		FillPropertyValues(TS_InventoryRow, StructureData);
		
	EndDo;
	
	OrdersTable = Object.Inventory.Unload( , "Order");
	OrdersTable.GroupBy("Order");
	If OrdersTable.Count() > 1 Then
		Object.Order = Undefined;
		Object.SalesOrderPosition = Enums.AttributeStationing.InTabularSection;
	ElsIf OrdersTable.Count() = 1 Then
		Object.Order = OrdersTable[0].Order;
		Object.SalesOrderPosition = Enums.AttributeStationing.InHeader;
	EndIf;
	SetVisibleFromUserSettings();
	
EndProcedure

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
		
		If ValueIsFilled(ImportRow.Products) Then
			
			NewRow.ProductsTypeInventory = (ImportRow.Products.ProductsType = PredefinedValue("Enum.ProductsTypes.InventoryItem"));
			
		EndIf;
		
		FillPropertyValues(StructureData, NewRow);
		FillProductGLAccounts(StructureData, GLAccounts);
		FillPropertyValues(NewRow, StructureData);
		
	EndDo;
	
	// AutomaticDiscounts
	If TableForImport.Count() > 0 Then
		ResetFlagDiscountsAreCalculatedServer("PickDataProcessor");
	EndIf;

EndProcedure

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
			
			GetInventoryFromStorage(InventoryAddressInStorage, "Inventory", True, True);
			
			RecalculatePaymentCalendar();
			
			RefillDiscountAmountOfEPD();
			
			RecalculateSubtotal();
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormViewManagement

&AtServer
Procedure SetVisibleAndEnabled(ChangedTypeOperations = False)
	
	Items.PricesAndCurrency.MaxWidth	= 34;
	
	// Discounts and discount cards.
	Items.Inventory.ChildItems.InventoryDiscountPercentMargin.Visible = True;
	Items.ReadDiscountCard.Visible = True; // DiscountCards
	
	// AutomaticDiscounts
	Items.Inventory.ChildItems.InventoryAutomaticDiscountPercent.Visible = True;
	Items.Inventory.ChildItems.InventoryAutomaticDiscountAmount.Visible = True;
	Items.InventoryCalculateDiscountsMarkups.Visible = True;
	// End AutomaticDiscounts
	
	LabelStructure = New Structure;
	LabelStructure.Insert("PriceKind",						Object.PriceKind);
	LabelStructure.Insert("DiscountKind",					Object.DiscountMarkupKind);
	LabelStructure.Insert("DocumentCurrency",				Object.DocumentCurrency);
	LabelStructure.Insert("SettlementsCurrency",			SettlementCurrency);
	LabelStructure.Insert("ExchangeRate",					Object.ExchangeRate);
	LabelStructure.Insert("AmountIncludesVAT",				Object.AmountIncludesVAT);
	LabelStructure.Insert("ForeignExchangeAccounting",		ForeignExchangeAccounting);
	LabelStructure.Insert("ExchangeRateNationalCurrency",	ExchangeRateNationalCurrency);
	LabelStructure.Insert("VATTaxation",					Object.VATTaxation);
	LabelStructure.Insert("DiscountCard",					Object.DiscountCard);
	LabelStructure.Insert("DiscountPercentByDiscountCard",	Object.DiscountPercentByDiscountCard);
	LabelStructure.Insert("RegisteredForVAT",				RegisteredForVAT);
	
	PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
	
	// Products.
	NewArray = New Array();
	NewArray.Add(PredefinedValue("Enum.ProductsTypes.InventoryItem"));
	NewArray.Add(PredefinedValue("Enum.ProductsTypes.Service"));
	ArrayInventoryAndServices = New FixedArray(NewArray);
	NewParameter = New ChoiceParameter("Filter.ProductsType", ArrayInventoryAndServices);
	NewParameter2 = New ChoiceParameter("Additionally.TypeRestriction", ArrayInventoryAndServices);
	NewArray = New Array();
	NewArray.Add(NewParameter);
	NewArray.Add(NewParameter2);
	NewParameters = New FixedArray(NewArray);
	Items.Inventory.ChildItems.InventoryProducts.ChoiceParameters = NewParameters;
	
	NewArray = New Array();

	// Batches.
	StatusArray = New Array();
	StatusArray.Add(PredefinedValue("Enum.BatchStatuses.OwnInventory"));
	StatusArray.Add(PredefinedValue("Enum.BatchStatuses.CounterpartysInventory"));
	ArrayOwnInventoryAndGoodsOnCommission = New FixedArray(StatusArray);
	
	NewParameter = New ChoiceParameter("Filter.Status", ArrayOwnInventoryAndGoodsOnCommission);
	NewParameter2 = New ChoiceParameter("Additionally.StatusRestriction", ArrayOwnInventoryAndGoodsOnCommission);
	NewArray.Add(NewParameter);
	NewArray.Add(NewParameter2);
		
	Items.Inventory.ChildItems.InventoryBatch.ChoiceParameters = New FixedArray(NewArray);
	
	// Order when safe storage.
	Items.Order.Visible = True;
	Items.FillByOrder.Visible = OrderInHeader;
	Items.Inventory.ChildItems.InventoryOrder.Visible = Not OrderInHeader;
	Items.FormDocumentSetting.Visible = True;
	Items.InventorySelectOrderedProducts.Visible = True;
	
	
	// Reserves.
	Items.InventoryChangeReserve.Visible = True;
	Items.Inventory.ChildItems.InventoryReserve.Visible = True;
	
	Items.Department.AutoChoiceIncomplete = True;
	Items.Department.AutoMarkIncomplete = True;
	
	// VAT Rate, VAT Amount, Total.
	If ChangedTypeOperations Then
		FillVATRateByCompanyVATTaxation();
	Else
		
		If Object.VATTaxation = PredefinedValue("Enum.VATTaxationTypes.SubjectToVAT") Then
			
			Items.InventoryVATRate.Visible = True;
			Items.InventoryVATAmount.Visible = True;
			Items.InventoryAmountTotal.Visible = True;
			Items.InventoryTotalAmountOfVAT.Visible = True;
			Items.PaymentVATAmount.Visible = True;
			Items.PaymentCalendarPayVATAmount.Visible = True;
		
		Else
			
			Items.InventoryVATRate.Visible = False;
			Items.InventoryVATAmount.Visible = False;
			Items.InventoryAmountTotal.Visible = False;
			Items.InventoryTotalAmountOfVAT.Visible = False;
			Items.PaymentVATAmount.Visible = False;
			Items.PaymentCalendarPayVATAmount.Visible = False;
			
		EndIf;
		
	EndIf;
	
	NewParameter = New ChoiceParameter("Filter.StructuralUnitType", PredefinedValue("Enum.BusinessUnitsTypes.Warehouse"));
	NewArray = New Array();
	NewArray.Add(NewParameter);
	NewParameters = New FixedArray(NewArray);
	Items.StructuralUnit.ChoiceParameters = NewParameters;
	
	If Object.StructuralUnit.StructuralUnitType <> PredefinedValue("Enum.BusinessUnitsTypes.Warehouse") Then
		Object.StructuralUnit = "";
	EndIf;
	
	// Price accessibility setup for editing.
	AllowedEditDocumentPrices = DriveAccessManagementReUse.AllowedEditDocumentPrices();
	
	Items.InventoryPrice.ReadOnly					= Not AllowedEditDocumentPrices;
	Items.InventoryDiscountPercentMargin.ReadOnly	= Not AllowedEditDocumentPrices;
	Items.InventoryAmount.ReadOnly					= Not AllowedEditDocumentPrices;
	Items.InventoryVATAmount.ReadOnly				= Not AllowedEditDocumentPrices;
	
	Items.TaxInvoiceText.Visible = WorkWithVAT.GetUseTaxInvoiceForPostingVAT(Object.Date, Object.Company);
	
	CommonUseClientServer.SetFormItemProperty(Items, "FormDocumentGoodsReturnCreateBasedOn", "Visible",	UseGoodsReturnFromCustomer);
	
EndProcedure

&AtServer
Procedure SetVisibleFromUserSettings()
	
	VisibleValue = (Object.SalesOrderPosition = PredefinedValue("Enum.AttributeStationing.InHeader"));
	
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

&AtClient
Procedure SetVisibleDeliveryAttributes()
	
	VisibleFlags			= GetFlagsForFormItemsVisible(Object.DeliveryOption);
	DeliveryOptionIsFilled	= ValueIsFilled(Object.DeliveryOption);

	Items.LogisticsCompany.Visible	= DeliveryOptionIsFilled AND VisibleFlags.DeliveryOptionLogisticsCompany;
	Items.ShippingAddress.Visible	= DeliveryOptionIsFilled AND NOT VisibleFlags.DeliveryOptionSelfPickup;
	Items.ContactPerson.Visible		= DeliveryOptionIsFilled AND NOT VisibleFlags.DeliveryOptionSelfPickup;
	Items.GoodsMarking.Visible		= DeliveryOptionIsFilled AND NOT VisibleFlags.DeliveryOptionSelfPickup;
	Items.DeliveryTimeFrom.Visible	= DeliveryOptionIsFilled AND NOT VisibleFlags.DeliveryOptionSelfPickup;
	Items.DeliveryTimeTo.Visible	= DeliveryOptionIsFilled AND NOT VisibleFlags.DeliveryOptionSelfPickup;
	Items.Incoterms.Visible			= DeliveryOptionIsFilled AND NOT VisibleFlags.DeliveryOptionSelfPickup;
	
EndProcedure

&AtServerNoContext
Function GetFlagsForFormItemsVisible(DeliveryOption)
	
	VisibleFlags = New Structure;
	VisibleFlags.Insert("DeliveryOptionLogisticsCompany", (DeliveryOption = Enums.DeliveryOptions.LogisticsCompany));
	VisibleFlags.Insert("DeliveryOptionSelfPickup", (DeliveryOption = Enums.DeliveryOptions.SelfPickup));
	
	Return VisibleFlags;
	
EndFunction

#EndRegion

#Region AutomaticDiscounts

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

&AtServer
Procedure CalculateMarkupsDiscountsForOrderServer()

	DiscountsMarkupsServer.FillLinkingKeysInSpreadsheetPartProducts(Object, "Inventory");
	
	OrdersArray = New Array;
	
	If Not ValueIsFilled(Object.SalesOrderPosition) Then
		SalesOrderPosition = DriveReUse.GetValueOfSetting("SalesOrderPositionInShipmentDocuments");
		If Not ValueIsFilled(Object.SalesOrderPosition) Then
			SalesOrderPosition = Enums.AttributeStationing.InHeader;
		EndIf;
	Else
		SalesOrderPosition = Object.SalesOrderPosition;
	EndIf;
	If SalesOrderPosition = Enums.AttributeStationing.InHeader Then
		OrdersArray.Add(Object.Order);
	Else
		OrdersGO = Object.Inventory.Unload(, "Order");
		OrdersGO.GroupBy("Order");
		OrdersArray = OrdersGO.UnloadColumn("Order");
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	DiscountsMarkups.Ref AS Order,
	|	DiscountsMarkups.DiscountMarkup AS DiscountMarkup,
	|	DiscountsMarkups.Amount AS AutomaticDiscountAmount,
	|	CASE
	|		WHEN SalesOrderInventory.Products.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS ProductsTypeInventory,
	|	CASE
	|		WHEN VALUETYPE(SalesOrderInventory.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|			THEN 1
	|		ELSE SalesOrderInventory.MeasurementUnit.Factor
	|	END AS Factor,
	|	SalesOrderInventory.Products,
	|	SalesOrderInventory.Characteristic,
	|	SalesOrderInventory.MeasurementUnit,
	|	SalesOrderInventory.Quantity
	|FROM
	|	Document.SalesOrder.DiscountsMarkups AS DiscountsMarkups
	|		INNER JOIN Document.SalesOrder.Inventory AS SalesOrderInventory
	|		ON DiscountsMarkups.Ref = SalesOrderInventory.Ref
	|			AND DiscountsMarkups.ConnectionKey = SalesOrderInventory.ConnectionKey
	|WHERE
	|	DiscountsMarkups.Ref IN(&OrdersArray)";
	
	Query.SetParameter("OrdersArray", OrdersArray);
	
	ResultsArray = Query.ExecuteBatch();
	
	OrderDiscountsMarkups = ResultsArray[0].Unload();
	
	Object.DiscountsMarkups.Clear();
	For Each CurrentDocumentRow In Object.Inventory Do
		CurrentDocumentRow.AutomaticDiscountsPercent = 0;
		CurrentDocumentRow.AutomaticDiscountAmount = 0;
	EndDo;
	
	DiscountsMarkupsCalculationResult = Object.DiscountsMarkups.Unload();
	
	For Each CurrentOrderRow In OrderDiscountsMarkups Do
		
		StructureForSearch = New Structure;
		StructureForSearch.Insert("Order", CurrentOrderRow.Order);
		StructureForSearch.Insert("Products", CurrentOrderRow.Products);
		StructureForSearch.Insert("Characteristic", CurrentOrderRow.Characteristic);
		
		DocumentRowsArray = Object.Inventory.FindRows(StructureForSearch);
		If DocumentRowsArray.Count() = 0 Then
			Continue;
		EndIf;
		
		QuantityInOrder = CurrentOrderRow.Quantity * CurrentOrderRow.Factor;
		Distributed = 0;
		For Each CurrentDocumentRow In DocumentRowsArray Do
			QuantityToWriteOff = CurrentDocumentRow.Quantity * 
									?(TypeOf(CurrentDocumentRow.MeasurementUnit) = Type("CatalogRef.UOMClassifier"), 1, CurrentDocumentRow.MeasurementUnit.Factor);
			
			RecalculateAmounts = QuantityInOrder <> QuantityToWriteOff;
			DiscountRecalculationCoefficient = ?(RecalculateAmounts, QuantityToWriteOff / QuantityInOrder, 1);
			If DiscountRecalculationCoefficient <> 1 Then
				CurrentAutomaticDiscountAmount = ROUND(CurrentOrderRow.AutomaticDiscountAmount * DiscountRecalculationCoefficient,2);
			Else
				CurrentAutomaticDiscountAmount = CurrentOrderRow.AutomaticDiscountAmount;
			EndIf;
			
			DiscountString = DiscountsMarkupsCalculationResult.Add();
			FillPropertyValues(DiscountString, CurrentOrderRow);
			DiscountString.Amount = CurrentAutomaticDiscountAmount;
			DiscountString.ConnectionKey = CurrentDocumentRow.ConnectionKey;
			
			CurrentOrderRow.AutomaticDiscountAmount = CurrentOrderRow.AutomaticDiscountAmount - CurrentAutomaticDiscountAmount;
			QuantityInOrder = QuantityInOrder - QuantityToWriteOff;
			If QuantityInOrder <=0 Or CurrentOrderRow.AutomaticDiscountAmount <=0 Then
				Break;
			EndIf;
		EndDo;
		
	EndDo;
	
	DiscountsMarkupsServer.ApplyDiscountCalculationResultToObject(Object, "Inventory", DiscountsMarkupsCalculationResult);
	
EndProcedure

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

&AtServer
Function GetAutomaticDiscountCalculationParametersStructureServer()

	OrderParametersStructure = New Structure("ImplementationByOrders, SalesExceedingOrder", False, False);
	
	If Not ValueIsFilled(Object.SalesOrderPosition) Then
		SalesOrderPosition = DriveReUse.GetValueOfSetting("SalesOrderPositionInShipmentDocuments");
		If Not ValueIsFilled(SalesOrderPosition) Then
			SalesOrderPosition = Enums.AttributeStationing.InHeader;
		EndIf;
	Else
		SalesOrderPosition = Object.SalesOrderPosition;
	EndIf;
	If SalesOrderPosition = Enums.AttributeStationing.InHeader Then
		If ValueIsFilled(Object.Order) Then
			OrderParametersStructure.ImplementationByOrders = True;
		Else
			OrderParametersStructure.ImplementationByOrders = False;
		EndIf;
		OrderParametersStructure.SalesExceedingOrder = False;
	Else
		Query = New Query;
		Query.Text = 
			"SELECT
			|	SalesInvoiceInventory.Order AS Order
			|INTO TU_Inventory
			|FROM
			|	&Inventory AS SalesInvoiceInventory
			|;
			|
			|////////////////////////////////////////////////////////////////////////////////
			|SELECT
			|	TU_Inventory.Order AS Order
			|FROM
			|	TU_Inventory AS TU_Inventory
			|
			|GROUP BY
			|	TU_Inventory.Order";
		
		Query.SetParameter("Inventory", Object.Inventory.Unload());
		QueryResult = Query.Execute();
		
		Selection = QueryResult.Select();
		
		While Selection.Next() Do
			If ValueIsFilled(Selection.Order) Then
				OrderParametersStructure.ImplementationByOrders = True;
			Else
				OrderParametersStructure.SalesExceedingOrder = True;
			EndIf;
		EndDo;
	EndIf;
	
	Return OrderParametersStructure;
	
EndFunction

&AtServer
Procedure CalculateDiscountsMarkupsOnServer(ParameterStructure)
	
	OrderParametersStructure = GetAutomaticDiscountCalculationParametersStructureServer(); // If there are orders in TS "Goods", then for such rows the automatic discount shall be calculated by the order.
	If OrderParametersStructure.ImplementationByOrders Then
		CalculateMarkupsDiscountsForOrderServer();
		If OrderParametersStructure.SalesExceedingOrder Then
			ParameterStructure.Insert("SalesExceedingOrder", True);
			AppliedDiscounts = DiscountsMarkupsServerOverridable.Calculate(Object, ParameterStructure);
		Else
			ParameterStructure.Insert("ApplyToObject", False);
			AppliedDiscounts = DiscountsMarkupsServerOverridable.Calculate(Object, ParameterStructure);
		EndIf;
	Else
		AppliedDiscounts = DiscountsMarkupsServerOverridable.Calculate(Object, ParameterStructure);
	EndIf;
	
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
Procedure OpenInformationAboutDiscounts(Command)
	
	CurrentData = Items.Inventory.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	OpenInformationAboutDiscountsClient()
	
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

&AtClient
Procedure InventorySelection(Item, SelectedRow, Field, StandardProcessing)
	
	If Item.CurrentItem = Items.InventoryAutomaticDiscountPercent
		AND Not ReadOnly Then
		
		StandardProcessing = False;
		OpenInformationAboutDiscountsClient()
		
	EndIf;
	
	If Field.Name = "InventoryGLAccounts" Then
		OpenProductGLAccountsForm(SelectedRow);
		StandardProcessing = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure InventoryOnStartEdit(Item, NewRow, Copy)
	
	// AutomaticDiscounts
	If NewRow AND Copy Then
		Item.CurrentData.AutomaticDiscountsPercent = 0;
		Item.CurrentData.AutomaticDiscountAmount = 0;
		CalculateAmountInTabularSectionLine();
	EndIf;
	// End AutomaticDiscounts
	
	ThisIsNewRow = NewRow;	
	
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

&AtClient
Procedure InventoryOnEditEnd(Item, NewRow, CancelEdit)
	ThisIsNewRow = False;
EndProcedure

&AtClient
Procedure InventoryBeforeDeleteRow(Item, Cancel)
	
	// Serial numbers
	CurrentData = Items.Inventory.CurrentData;
	WorkWithSerialNumbersClientServer.DeleteSerialNumbersByConnectionKey(Object.SerialNumbers, CurrentData,,UseSerialNumbersBalance);

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

&AtClient
Procedure InventoryAfterDeleteRow(Item)
	
	// AutomaticDiscounts.
	ClearCheckboxDiscountsAreCalculatedClient("DeleteRow");
	
	RecalculatePaymentCalendar();
	RefillDiscountAmountOfEPD();
	RecalculateSubtotal();
	
EndProcedure

&AtClient
Procedure InventoryOrderStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	StructureFilter = New Structure();
	StructureFilter.Insert("Company",		Object.Company);
	StructureFilter.Insert("Counterparty",	Object.Counterparty);
	
	If ValueIsFilled(Object.Contract) Then
		StructureFilter.Insert("Contract", Object.Contract);
	EndIf;
	
	ParameterStructure = New Structure("Filter", StructureFilter);
	
	OpenForm("CommonForm.SelectDocumentOrder", ParameterStructure, Item);

EndProcedure

&AtClient
Procedure InventoryOrderChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	StandardProcessing = False;
	
	ProcessInventoryOrderSelection(SelectedValue);

EndProcedure

&AtClient
Procedure InventoryOrderOnChange(Item)
	
	// AutomaticDiscounts
	If ClearCheckboxDiscountsAreCalculatedClient("InventoryOrderOnChange") Then
		CalculateAmountInTabularSectionLine(Undefined, False);
	EndIf;
	// End AutomaticDiscounts
	
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
Procedure PaymentCalendarPaymentAmountOnChange(Item)
	
	CurrentRow = Items.PaymentCalendar.CurrentData;
	
	TotalAmount = Object.Inventory.Total("Amount");
	
	If TotalAmount = 0 Then
		CurrentRow.PaymentPercentage	= 0;
		CurrentRow.PaymentVATAmount			= 0;
	Else
		CurrentRow.PaymentPercentage	= Round(CurrentRow.PaymentAmount / TotalAmount * 100, 2, 1);
		CurrentRow.PaymentVATAmount			= Round(Object.Inventory.Total("VATAmount") * CurrentRow.PaymentAmount / TotalAmount, 2, 1);
	EndIf;
	
EndProcedure

&AtClient
Procedure PaymentCalendarPaymentPercentageOnChange(Item)
	
	CurrentRow = Items.PaymentCalendar.CurrentData;
	
	CurrentRow.PaymentAmount	= Round(Object.Inventory.Total("Amount") * CurrentRow.PaymentPercentage / 100, 2, 1);
	CurrentRow.PaymentVATAmount		= Round(Object.Inventory.Total("VATAmount") * CurrentRow.PaymentPercentage / 100, 2, 1);
	
EndProcedure

&AtClient
Procedure PaymentCalendarPayVATAmountOnChange(Item)
	
	CurrentRow = Items.PaymentCalendar.CurrentData;
	
	PaymentCalendarTotal = Object.PaymentCalendar.Total("PaymentVATAmount");
	TotalVAT = Object.Inventory.Total("VATAmount");
	
	If PaymentCalendarTotal > TotalVAT Then
		CurrentRow.PaymentVATAmount = CurrentRow.PaymentVATAmount - (PaymentCalendarTotal - TotalVAT);
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
Procedure SchedulePaymentOnChange(Item)
	FillThePaymentCalendar();
EndProcedure

&AtClient
Procedure PrepaymentOnChange(Item)
	PrepaymentWasChanged = True;
EndProcedure

#EndRegion

#Region DiscountCards

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
	LabelStructure.Insert("SettlementsCurrency",			SettlementCurrency);
	LabelStructure.Insert("ExchangeRate",					Object.ExchangeRate);
	LabelStructure.Insert("AmountIncludesVAT",				Object.AmountIncludesVAT);
	LabelStructure.Insert("ForeignExchangeAccounting",	ForeignExchangeAccounting);
	LabelStructure.Insert("ExchangeRateNationalCurrency",	ExchangeRateNationalCurrency);
	LabelStructure.Insert("VATTaxation",					Object.VATTaxation);
	LabelStructure.Insert("DiscountCard",					Object.DiscountCard);
	LabelStructure.Insert("DiscountPercentByDiscountCard",	Object.DiscountPercentByDiscountCard);
	LabelStructure.Insert("RegisteredForVAT",				RegisteredForVAT);
			
	PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
		
	If Object.Inventory.Count() > 0 Then
		Text = NStr("en = 'Do you want to update the discounts in all lines?'");
		Notification = New NotifyDescription("DiscountCardIsSelectedAdditionallyEnd", ThisObject);
		ShowQueryBox(Notification, Text, QuestionDialogMode.YesNo, , DialogReturnCode.Yes);
	EndIf;

EndProcedure

&AtClient
Procedure DiscountCardIsSelectedAdditionallyEnd(QuestionResult, AdditionalParameters) Export

	If QuestionResult = DialogReturnCode.Yes Then
		DriveClient.RefillDiscountsTablePartAfterDiscountCardRead(ThisForm, "Inventory");
	EndIf;
	
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
				NStr("en = 'Do you want to change the card discount percent from %1% to %2% and recalculate discounts in all rows?'"),
				PreDiscountPercentByDiscountCard,
				NewDiscountPercentByDiscountCard);
			AdditionalParameters	= New Structure("NewDiscountPercentByDiscountCard, RecalculateTP", NewDiscountPercentByDiscountCard, True);
			Notification			= New NotifyDescription("RecalculateDiscountPercentAtDocumentDateChangeEnd", ThisObject, AdditionalParameters);
			
		Else
			
			Text = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Change the percent of discount of the card from %1% to %2%?'"),
				PreDiscountPercentByDiscountCard,
				NewDiscountPercentByDiscountCard);
			AdditionalParameters	= New Structure("NewDiscountPercentByDiscountCard, RecalculateTP", NewDiscountPercentByDiscountCard, False);
			Notification			= New NotifyDescription("RecalculateDiscountPercentAtDocumentDateChangeEnd", ThisObject, AdditionalParameters);
			
		EndIf;
		
		ShowQueryBox(Notification, Text, QuestionDialogMode.YesNo,, DialogReturnCode.Yes);
		
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
		LabelStructure.Insert("SettlementsCurrency",			SettlementCurrency);
		LabelStructure.Insert("ExchangeRate",					Object.ExchangeRate);
		LabelStructure.Insert("AmountIncludesVAT",				Object.AmountIncludesVAT);
		LabelStructure.Insert("ForeignExchangeAccounting",	ForeignExchangeAccounting);
		LabelStructure.Insert("ExchangeRateNationalCurrency",	ExchangeRateNationalCurrency);
		LabelStructure.Insert("VATTaxation",					Object.VATTaxation);
		LabelStructure.Insert("DiscountCard",					Object.DiscountCard);
		LabelStructure.Insert("DiscountPercentByDiscountCard",	Object.DiscountPercentByDiscountCard);
		LabelStructure.Insert("RegisteredForVAT",				RegisteredForVAT);
				
		PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
		
		If AdditionalParameters.RecalculateTP Then
			DriveClient.RefillDiscountsTablePartAfterDiscountCardRead(ThisForm, "Inventory");
		EndIf;
				
	EndIf;
	
EndProcedure

&AtClient
Procedure ReadDiscountCardClick(Item)
	
	ParametersStructure = New Structure("Counterparty", Object.Counterparty);
	NotifyDescription = New NotifyDescription("ReadDiscountCardClickEnd", ThisObject);
	OpenForm("Catalog.DiscountCards.Form.ReadingDiscountCard", ParametersStructure, ThisForm, , , , NotifyDescription, FormWindowOpeningMode.LockOwnerWindow);	
	
EndProcedure

&AtClient
Procedure ReadDiscountCardClickEnd(ReturnParameters, Parameters) Export

	If TypeOf(ReturnParameters) = Type("Structure") Then
		DiscountCardRead = ReturnParameters.DiscountCardRead;
		DiscountCardIsSelected(ReturnParameters.DiscountCard);
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

#Region DataImportFromExternalSources

&AtClient
Procedure LoadFromFileInventory(Command)
	
	NotifyDescription = New NotifyDescription("ImportDataFromExternalSourceResultDataProcessor", ThisObject, DataLoadSettings);
	
	DataLoadSettings.Insert("TabularSectionFullName",	"SalesInvoice.Inventory");
	DataLoadSettings.Insert("Title",					NStr("en = 'Import inventory from file'"));
	
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

// StandardSubsystems.Properties
&AtClient
Procedure Attachable_EditContentOfProperties(Command)
	
	PropertiesManagementClient.EditContentOfProperties(ThisForm, Object.Ref);
	
EndProcedure

&AtServer
Procedure UpdateAdditionalAttributesItems()
	
	PropertiesManagement.UpdateAdditionalAttributesItems(ThisForm, FormAttributeToValue("Object"));
	
EndProcedure
// End StandardSubsystems.Properties

#EndRegion

#Region CopyPasteRows

&AtClient
Procedure CopyRows(Command)
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
Procedure PasteRows(Command)
	
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
	
	Count = Object[TabularPartName].Count();
	
	For Iterator = 1 To CountOfPasted Do
		
		Row = Object[TabularPartName][Count - Iterator];
		CalculateAmountInTabularSectionLine(Row);
		
	EndDo; 
	
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
		
		If Not ValueIsFilled(Row.MeasurementUnit) Then
			Row.MeasurementUnit = StructData.MeasurementUnit;
		EndIf;
		
		Row.VATRate							 = StructData.VATRate;
		Row.ProductsTypeInventory = StructData.ProductsTypeInventory;
		
	EndDo;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure GLAccountsChoiceProcessingAtClient(GLAccounts)

	TabRow = Items[GLAccounts.TableName].CurrentData;
	FillPropertyValues(TabRow, GLAccounts);
	Modified = True;
	
	If TabRow.Property("GLAccounts") Then
		ObjectParameters = GLAccountsInDocumentsClientServer.GetObjectParameters(Object);
		StructureData = GetStructureData(ObjectParameters, TabRow);
		
		GLAccountsForFilling = GetGLAccountsStructure(StructureData);
		GLAccountsInDocumentsClientServer.FillProductGLAccountsDescription(StructureData, GLAccountsForFilling);
		FillPropertyValues(TabRow, StructureData);
	EndIf;
	
EndProcedure

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
Procedure FillThePaymentCalendar()
	
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

&AtServer
Procedure FillThePaymentCalendarOnServer()
	
	FillPaymentCalendarFromContract(SwitchTypeListOfPaymentCalendar);
	
	If Object.PaymentCalendar.Count() = 0 Then
		NewRow = Object.PaymentCalendar.Add();
		
		NewRow.PaymentPercentage = 100;
		NewRow.PaymentAmount = Object.Inventory.Total("Amount");
		NewRow.PaymentVATAmount = Object.Inventory.Total("VATAmount");
	EndIf;
	
EndProcedure

&AtServerNoContext
Function GetGLAccountsStructure(StructureData)

	ObjectParameters = StructureData.ObjectParameters;
	GLAccountsForFilling = New Structure;

	If StructureData.ProductsTypeInventory
		And Not ObjectParameters.AdvanceInvoicing
		And Not ValueIsFilled(StructureData.GoodsIssue) Then
		
		If ValueIsFilled(StructureData.Batch) 
			And CommonUse.ObjectAttributeValue(StructureData.Batch, "Status") = PredefinedValue("Enum.BatchStatuses.CounterpartysInventory") Then
			GLAccountsForFilling.Insert("InventoryReceivedGLAccount", StructureData.InventoryReceivedGLAccount);
		Else
			GLAccountsForFilling.Insert("InventoryGLAccount", StructureData.InventoryGLAccount);
		EndIf;
		
	EndIf;
	
	If ValueIsFilled(StructureData.GoodsIssue) Then
		GLAccountsForFilling.Insert("GoodsShippedNotInvoicedGLAccount", StructureData.GoodsShippedNotInvoicedGLAccount);
	EndIf;
	
	If ObjectParameters.AdvanceInvoicing
		And Not ValueIsFilled(StructureData.GoodsIssue) Then
		GLAccountsForFilling.Insert("UnearnedRevenueGLAccount", StructureData.UnearnedRevenueGLAccount);
	EndIf;
	
	If Not ObjectParameters.AdvanceInvoicing
		Or ValueIsFilled(StructureData.GoodsIssue) Then
		GLAccountsForFilling.Insert("RevenueGLAccount", StructureData.RevenueGLAccount);
	EndIf;
	
	If StructureData.ProductsTypeInventory
		And Not ObjectParameters.AdvanceInvoicing
		Or ValueIsFilled(StructureData.GoodsIssue) Then
		GLAccountsForFilling.Insert("COGSGLAccount", StructureData.COGSGLAccount);
	EndIf;	
	
	If ObjectParameters.VATTaxation = PredefinedValue("Enum.VATTaxationTypes.SubjectToVAT") Then
		GLAccountsForFilling.Insert("VATOutputGLAccount", StructureData.VATOutputGLAccount);
	EndIf;
	
	Return GLAccountsForFilling;

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
	
	RowParameters = GetGLAccountsStructure(StructureData);
	RowParameters.Insert("TableName",	"Inventory");
	RowParameters.Insert("Products",	RowData.Products);

	OpenForm("CommonForm.ProductGLAccounts", RowParameters, ThisForm);

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

&AtClient
Procedure SetVisibleEarlyPaymentDiscounts()
	
	Items.GroupEarlyPaymentDiscounts.Visible = GetVisibleFlagForEPD(Object.Counterparty, Object.Contract);
	
EndProcedure

&AtServerNoContext
Function GetVisibleFlagForEPD(Counterparty, Contract)
	
	If ValueIsFilled(Counterparty) Then
		DoOperationsByDocuments = CommonUse.ObjectAttributeValue(Counterparty, "DoOperationsByDocuments");
	Else
		DoOperationsByDocuments = False;
	EndIf;
	
	If ValueIsFilled(Contract) Then
		ContractKind		= CommonUse.ObjectAttributeValue(Contract, "ContractKind");
		ContractKindFlag	= ContractKind = Enums.ContractType.WithCustomer;
	Else
		ContractKindFlag	= False;
	EndIf;
	
	Return (DoOperationsByDocuments AND ContractKindFlag);
	
EndFunction

&AtServer
Procedure FillPaymentCalendarFromContract(TypeListOfPaymentCalendar)
	
	Document = FormAttributeToValue("Object");
	Document.FillPaymentCalendarFromContract();
	ValueToFormAttribute(Document, "Object");
	FillAddedColumns();
	Modified = True;
	
	TypeListOfPaymentCalendar = Number(Object.PaymentCalendar.Count() > 1);
	
EndProcedure

&AtServer
Procedure FillEarlyPaymentDiscounts()
	
	Document = FormAttributeToValue("Object");
	Document.FillEarlyPaymentDiscounts();
	ValueToFormAttribute(Document, "Object");
	
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
Procedure RecalculatePaymentCalendar()
	
	If Object.SetPaymentTerms Then
		
		InventoryTotalAmount = Object.Inventory.Total("Amount");
		InventoryTotalVAT = Object.Inventory.Total("VATAmount");
		
		TotalAmountForCorrectBalance = 0;
		TotalVATForCorrectBalance = 0;
		
		If Object.PaymentCalendar.Count() Then
		
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

&AtClient
Procedure EarlyPaymentDiscountsPeriodOnChange(Item)
	CalculateRowDueDateOfEPD(Object.Date);
EndProcedure

&AtClient
Procedure EarlyPaymentDiscountsDiscountOnChange(Item)
	CalculateRowDiscountAmountOfEPD(Object.Inventory.Total("Total"));
EndProcedure

&AtClient
Procedure ProcessShippingAddressChange()
	
	DeliveryData = GetDeliveryAttributes(Object.ShippingAddress);
	
	FillPropertyValues(Object, DeliveryData);
	If ValueIsFilled(DeliveryData.SalesRep) Then
		For Each Row In Object.Inventory Do
			Row.SalesRep = DeliveryData.SalesRep;
		EndDo;
	EndIf;
	
EndProcedure

&AtServer
Function GetDeliveryData(Counterparty)
	Return ShippingAddressesServer.GetDeliveryDataForCounterparty(Counterparty);
EndFunction

&AtServer
Function GetDeliveryAttributes(ShippingAddress)
	Return ShippingAddressesServer.GetDeliveryAttributesForAddress(ShippingAddress);
EndFunction

&AtServer
Function CheckEarlyPaymentDiscounts()
	
	Return EarlyPaymentDiscountsServer.CheckEarlyPaymentDiscounts(Object.EarlyPaymentDiscounts, Object.ProvideEPD);
	
EndFunction

&AtClient
Procedure SetVisibleSalesRep()
	
	If Object.SalesOrderPosition = PredefinedValue("Enum.AttributeStationing.InHeader") Then
		Items.SalesRep.Visible = True;
	Else 
		Items.SalesRep.Visible = False;
	EndIf;
	
EndProcedure

&AtServer
Function SalesRep(Source)
	Return CommonUse.ObjectAttributeValue(Source, "SalesRep");
EndFunction

&AtClient
Procedure ProcessOrderDocumentSelection(DocumentData)
	
	If TypeOf(DocumentData) = Type("Structure") Then
		
		If Not ValueIsFilled(Object.Contract) Then
			Object.Contract = DocumentData.Contract;
			ProcessContractChange();
		EndIf;
		
		Object.Order = DocumentData.Document;
		
		If Object.Prepayment.Count() > 0
			AND Object.Order <> Order Then
			
			Mode = QuestionDialogMode.YesNo;
			Response = Undefined;
			ShowQueryBox(New NotifyDescription("OrderOnChangeEnd", ThisObject), NStr("en = 'Advances will be cleared. Do you want to continue?'"), Mode, 0);
			Return;
			
		EndIf;
		
		If Order <> Object.Order
			And ValueIsFilled(Object.Order) Then
			SalesRep = SalesRep(Object.Order);
			If ValueIsFilled(SalesRep) Then
				For Each Row In Object.Inventory Do
					Row.SalesRep = SalesRep;
				EndDo;
			EndIf;
		EndIf;
		
		OrderOnChangeFragment();
		
		Modified = True;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ProcessInventoryOrderSelection(DocumentData)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	If TypeOf(DocumentData) = Type("Structure") Then
		
		TabularSectionRow.Order = DocumentData.Document;
		
		If ClearCheckboxDiscountsAreCalculatedClient("InventoryOrderOnChange") Then
			CalculateAmountInTabularSectionLine(Undefined, False);
		EndIf;
		
		Modified = True;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure FillAddedColumns(GetGLAccounts = False)
	
	StructureData = New Structure();
	ObjectParameters = GLAccountsInDocumentsClientServer.GetObjectParameters(Object);
	StructureData.Insert("ObjectParameters", ObjectParameters);
	StructureData.Insert("Products", Object.Inventory.Unload(, "Products").UnloadColumn(("Products")));
	
	Inventory = Object.Inventory;
	
	If GetGLAccounts Then
		GLAccounts = GLAccountsInDocuments.GetProductListGLAccounts(StructureData);
	EndIf;
	
	StructureData = GetStructureData(ObjectParameters);
	
	For Each Row In Inventory Do
		FillPropertyValues(StructureData, Row);
		
		If GetGLAccounts Then
			FillProductGLAccounts(StructureData, GLAccounts);		
		Else
			GLAccountsForFilling = GetGLAccountsStructure(StructureData);
			GLAccountsInDocumentsClientServer.FillProductGLAccountsDescription(StructureData, GLAccountsForFilling);
		EndIf;
		
		FillPropertyValues(Row, StructureData);
	EndDo;
	
EndProcedure

&AtClientAtServerNoContext
Function GetStructureData(ObjectParameters, RowData = Undefined, ProductName = "Products") Export
	
	StructureData = New Structure("Products, ProductsTypeInventory, Batch, GoodsIssue, InventoryGLAccount,
		|GoodsShippedNotInvoicedGLAccount, InventoryReceivedGLAccount, UnearnedRevenueGLAccount, VATOutputGLAccount,
		|RevenueGLAccount, COGSGLAccount, GLAccounts, GLAccountsFilled");
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