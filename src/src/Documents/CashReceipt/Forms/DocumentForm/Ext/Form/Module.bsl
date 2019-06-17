
#Region FormEventHandlers

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
	
	If Object.PaymentDetails.Count() = 0 Then
		Object.PaymentDetails.Add();
		Object.PaymentDetails[0].PaymentAmount = Object.DocumentAmount;
	EndIf;
	
	DocumentObject = FormAttributeToValue("Object");
	If DocumentObject.IsNew()
	AND Not ValueIsFilled(Parameters.CopyingValue) Then
		If ValueIsFilled(Parameters.BasisDocument) Then
			DocumentObject.Fill(Parameters.BasisDocument);
			ValueToFormAttribute(DocumentObject, "Object");
		EndIf;
		If Not ValueIsFilled(Object.PettyCash) Then
			Object.PettyCash = Catalogs.CashAccounts.GetPettyCashByDefault(Object.Company);
			Object.CashCurrency = ?(ValueIsFilled(Object.PettyCash.CurrencyByDefault), Object.PettyCash.CurrencyByDefault, Object.CashCurrency);
		EndIf;
		
		If Object.OperationKind <> PredefinedValue("Enum.OperationTypesCashReceipt.LoanSettlements") AND
			Object.OperationKind <> PredefinedValue("Enum.OperationTypesCashReceipt.LoanRepaymentByEmployee") Then
			If ValueIsFilled(Object.Counterparty)
				AND Object.PaymentDetails.Count() > 0
				AND Not ValueIsFilled(Parameters.BasisDocument) Then
				If Not ValueIsFilled(Object.PaymentDetails[0].Contract) Then
					Object.PaymentDetails[0].Contract = Object.Counterparty.ContractByDefault;
				EndIf;
				If ValueIsFilled(Object.PaymentDetails[0].Contract) Then
					ContractCurrencyRateRepetition = InformationRegisters.ExchangeRates.GetLast(Object.Date, New Structure("Currency", Object.PaymentDetails[0].Contract.SettlementsCurrency));
					Object.PaymentDetails[0].ExchangeRate = ?(ContractCurrencyRateRepetition.ExchangeRate = 0, 1, ContractCurrencyRateRepetition.ExchangeRate);
					Object.PaymentDetails[0].Multiplicity = ?(ContractCurrencyRateRepetition.Multiplicity = 0, 1, ContractCurrencyRateRepetition.Multiplicity);
				EndIf;
			EndIf;
		EndIf;
		
		SetCFItem();
	EndIf;
	
	// Form attributes setting.
	ParentCompany = DriveServer.GetCompany(Object.Company);
	StructureByCurrency = InformationRegisters.ExchangeRates.GetLast(Object.Date, New Structure("Currency", Object.CashCurrency));
	
	ExchangeRate = ?(
		StructureByCurrency.ExchangeRate = 0,
		1,
		StructureByCurrency.ExchangeRate
	);
	Multiplicity = ?(
		StructureByCurrency.ExchangeRate = 0,
		1,
		StructureByCurrency.Multiplicity
	);
	
	StructureByCurrency = InformationRegisters.ExchangeRates.GetLast(Object.Date, New Structure("Currency", Constants.PresentationCurrency.Get()));
	
	AccountingCurrencyRate = ?(
		StructureByCurrency.ExchangeRate = 0,
		1,
		StructureByCurrency.ExchangeRate
	);
	AccountingCurrencyMultiplicity = ?(
		StructureByCurrency.ExchangeRate = 0,
		1,
		StructureByCurrency.Multiplicity
	);
	
	SupplementOperationTypesChoiceList();
	
	If Not ValueIsFilled(Object.Ref)
	   AND Not ValueIsFilled(Parameters.Basis)
	   AND Not ValueIsFilled(Parameters.CopyingValue) Then
		FillVATRateByCompanyVATTaxation();
	Else
		SetVisibleOfVATTaxation();
	EndIf;
	
	If Object.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then
		DefaultVATRate = InformationRegisters.AccountingPolicy.GetDefaultVATRate(Object.Date, Object.Company);
	ElsIf Object.VATTaxation = Enums.VATTaxationTypes.NotSubjectToVAT Then
		DefaultVATRate = Catalogs.VATRates.Exempt;
	Else
		DefaultVATRate = Catalogs.VATRates.ZeroRate;
	EndIf;
	
	OperationKind = Object.OperationKind;
	CashCurrency = Object.CashCurrency;
	
	DocumentDate = Object.Date;
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentDate();
	EndIf;
	
	PrintReceiptEnabled = False;
	
	Button = Items.Find("PrintReceipt");
	If Button <> Undefined Then
		
		If Object.OperationKind = Enums.OperationTypesCashReceipt.FromCustomer Then
			PrintReceiptEnabled = True;
		EndIf;
		
		Button.Enabled = PrintReceiptEnabled;
		Items.Decoration3.Visible = PrintReceiptEnabled;
		Items.SalesSlipNumber.Visible = PrintReceiptEnabled;
		
	EndIf;
	
	PresentationCurrency = Constants.PresentationCurrency.Get();
	
	// Fill in tabular section while entering a document from the working place.
	If TypeOf(Parameters.FillingValues) = Type("Structure")
	   AND Parameters.FillingValues.Property("FillDetailsOfPayment")
	   AND Parameters.FillingValues.FillDetailsOfPayment Then
		
		TabularSectionRow = Object.PaymentDetails[0];
		
		TabularSectionRow.PaymentAmount = Object.DocumentAmount;
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
		
		TabularSectionRow.SettlementsAmount = DriveServer.RecalculateFromCurrencyToCurrency(
			TabularSectionRow.PaymentAmount,
			ExchangeRate,
			TabularSectionRow.ExchangeRate,
			Multiplicity,
			TabularSectionRow.Multiplicity
		);
		
		If Not ValueIsFilled(TabularSectionRow.VATRate) Then
			TabularSectionRow.VATRate = DefaultVATRate;
		EndIf;
		
		TabularSectionRow.VATAmount = TabularSectionRow.PaymentAmount - (TabularSectionRow.PaymentAmount) / ((TabularSectionRow.VATRate.Rate + 100) / 100);
		
	EndIf;
	
	SetVisibilityItemsDependenceOnOperationKind();
	SetVisibilitySettlementAttributes();
	SetVisibilityEPDAttributes();
	
	DriveClientServer.SetPictureForComment(Items.Additionally, Object.Comment);
	
	// StandardSubsystems.ObjectVersioning
	ObjectVersioning.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.ObjectVersioning
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisForm, Items.ImportantCommandsGroup);
	// End StandardSubsystems.Printing
	
	// StandardSubsystems.Properties
	 PropertiesManagement.OnCreateAtServer(ThisForm, , "AdditionalAttributesGroup");
	// End StandardSubsystems.Properties
	
	WorkWithVAT.SetTextAboutAdvancePaymentInvoiceIssued(ThisForm);
	
	SetTaxInvoiceText();
	
	EarlyPaymentDiscountsServer.SetTextAboutCreditNote(ThisObject, Object.Ref);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	SetChoiceParameterLinksAvailableTypes();
	SetCurrentPage();
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "AfterRecordingOfCounterparty" Then
		If ValueIsFilled(Parameter)
		   AND Object.Counterparty = Parameter Then
			SetVisibilitySettlementAttributes();
			SetVisibilityEPDAttributes();
		EndIf;
	ElsIf EventName = "RefreshTaxInvoiceText" 
		AND TypeOf(Parameter) = Type("Structure") 
		AND Not Parameter.BasisDocuments.Find(Object.Ref) = Undefined Then
		
		TaxInvoiceText = Parameter.Presentation;
		
	ElsIf EventName = "RefreshCreditNoteText" Then
		
		If TypeOf(Parameter.Ref) = Type("DocumentRef.CreditNote")
			AND Parameter.BasisDocument = Object.Ref Then
			
			CreditNoteText = EarlyPaymentDiscountsClientServer.CreditNotePresentation(Parameter.Date, Parameter.Number);
			
		EndIf;
		
	EndIf;
	
	// StandardSubsystems.Properties
	If PropertiesManagementClient.ProcessAlerts(ThisForm, EventName, Parameter) Then
		UpdateAdditionalAttributesItems();
	EndIf;
	// End StandardSubsystems.Properties
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	ClosingDates.ObjectOnReadAtServer(ThisForm, CurrentObject);
	
	// StandardSubsystems.Properties
	PropertiesManagement.OnReadAtServer(ThisForm, CurrentObject);
	// End StandardSubsystems.Properties
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	// StandardSubsystems.PerformanceMeasurement
	PerformanceEstimationClientServer.StartTimeMeasurement("DocumentCashReceiptPosting");
	// StandardSubsystems.PerformanceMeasurement
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	If WriteParameters.WriteMode = DocumentWriteMode.Posting Then
		
		MessageText = "";
		CheckContractToDocumentConditionAccordance(Object.PaymentDetails, MessageText, Object.Ref, Object.Company, Object.Counterparty, Object.OperationKind, Cancel, Object.LoanContract);
		
		If MessageText <> "" Then
			
			CommonUseClientServer.MessageToUser(
				?(Cancel, 
					NStr("en = 'The cash receipt is not posted.'") + " " + MessageText, 
					MessageText));
			
			If Cancel Then
				Return;
			EndIf;
			
		EndIf;
		
	EndIf;
	
	// StandardSubsystems.Properties
	PropertiesManagement.BeforeWriteAtServer(ThisForm, CurrentObject);
	// End StandardSubsystems.Properties
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	LineCount = Object.PaymentDetails.Count();
	
	// Notification about payment.
	NotifyAboutOrderPayment = False;
	
	For Each CurRow In Object.PaymentDetails Do
		NotifyAboutOrderPayment = ?(
			NotifyAboutOrderPayment,
			NotifyAboutOrderPayment,
			ValueIsFilled(CurRow.Order)
		);
	EndDo;
	
	If NotifyAboutOrderPayment Then
		Notify("NotificationAboutOrderPayment");
	EndIf;
	
	Notify("NotificationAboutChangingDebt");
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	If CurrentObject.OperationKind = PredefinedValue("Enum.OperationTypesCashReceipt.LoanRepaymentByEmployee") Or
		CurrentObject.OperationKind = PredefinedValue("Enum.OperationTypesCashReceipt.LoanSettlements") Then
		FillInformationAboutCreditLoanAtServer();
	EndIf;
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
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormItemEventHandlers

#Region OtherSettlements

&AtClient
Procedure OtherSettlementsCorrespondenceOnChange(Item)
	
	If Correspondence <> Object.Correspondence Then
		SetVisibilityAttributesDependenceOnCorrespondence();
		Correspondence = Object.Correspondence;
	EndIf;
	
EndProcedure

#EndRegion

#EndRegion

#Region FormItemEventHandlersTablePaymentDetails

&AtClient
Procedure PaymentDetailsOtherSettlementsBeforeDeleteRow(Item, Cancel)
	
	If Object.PaymentDetails.Count() = 1 Then
		Cancel = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure PaymentDetailsOtherSettlementsContractOnChange(Item)
	
	ProcessOnChangeCounterpartyContractOtherSettlements();
	
EndProcedure

&AtClient
Procedure PaymentDetailsOtherSettlementsContractStartChoice(Item, ChoiceData, StandardProcessing)
	
	If Object.Counterparty.IsEmpty() Then
		StandardProcessing = False;
		
		Message = New UserMessage;
		Message.Text = NStr("en = 'Please select a counterparty.'");
		Message.Field = "Object.Counterparty";
		Message.Message();
		
		Return;
	EndIf;
	
	ProcessStartChoiceCounterpartyContractOtherSettlements(Item, StandardProcessing);
	
EndProcedure

&AtClient
Procedure PaymentDetailsOtherSettlementsSettlementsAmountOnChange(Item)
	
	CalculatePaymentAmountAtClient(Items.PaymentDetailsOtherSettlements.CurrentData);
	
	If Object.PaymentDetails.Count() = 1 Then
		Object.DocumentAmount = Object.PaymentDetails[0].PaymentAmount;
	EndIf;

EndProcedure

&AtClient
Procedure PaymentDetailsOtherSettlementsExchangeRateOnChange(Item)
		
	CalculatePaymentAmountAtClient(Items.PaymentDetailsOtherSettlements.CurrentData);
	
	If Object.PaymentDetails.Count() = 1 Then
		Object.DocumentAmount = Object.PaymentDetails[0].PaymentAmount;
	EndIf;
	
EndProcedure

&AtClient
Procedure PaymentDetailsOtherSettlementsMultiplicityOnChange(Item)
		
	CalculatePaymentAmountAtClient(Items.PaymentDetailsOtherSettlements.CurrentData);
	
	If Object.PaymentDetails.Count() = 1 Then
		Object.DocumentAmount = Object.PaymentDetails[0].PaymentAmount;
	EndIf;
	
EndProcedure

&AtClient
Procedure PaymentDetailsOtherSettlementsPaymentAmountOnChange(Item)
	
	TablePartRow = Items.PaymentDetailsOtherSettlements.CurrentData;
	
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
	
	TablePartRow.ExchangeRate = ?(
		TablePartRow.SettlementsAmount = 0,
		1,
		TablePartRow.PaymentAmount / TablePartRow.SettlementsAmount * ExchangeRate
	);
	
	If Not ValueIsFilled(TablePartRow.VATRate) Then
		TablePartRow.VATRate = DefaultVATRate;
	EndIf;
	
	CalculateVATAmountAtClient(TablePartRow);
	
EndProcedure

&AtClient
Procedure PaymentDetailsOtherSettlementsVATRateOnChange(Item)
	
	TablePartRow = Items.PaymentDetailsOtherSettlements.CurrentData;
	CalculateVATAmountAtClient(TablePartRow);

EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure CalculatePaymentAmountAtClient(TablePartRow, ColumnName = "")
	
	StructureData = GetDataPaymentDetailsContractOnChange(
			Object.Date,
			TablePartRow.Contract
		);
		
	TablePartRow.ExchangeRate = ?(
		TablePartRow.ExchangeRate = 0,
		?(StructureData.ContractCurrencyRateRepetition.ExchangeRate =0, 1, StructureData.ContractCurrencyRateRepetition.ExchangeRate),
		TablePartRow.ExchangeRate
	);
	TablePartRow.Multiplicity = ?(
		TablePartRow.Multiplicity = 0,
		1,
		TablePartRow.Multiplicity
	);
	
	If TablePartRow.SettlementsAmount = 0 Then
		TablePartRow.PaymentAmount = 0;
		TablePartRow.ExchangeRate = StructureData.ContractCurrencyRateRepetition.ExchangeRate;
	ElsIf Object.CashCurrency = StructureData.SettlementsCurrency Then
		TablePartRow.PaymentAmount = TablePartRow.SettlementsAmount;
	ElsIf TablePartRow.PaymentAmount = 0 Or
		(ColumnName = "ExchangeRate" Or ColumnName = "Multiplicity") Then
		If TablePartRow.ExchangeRate = 0 Then
			TablePartRow.PaymentAmount = 0;
		Else
			TablePartRow.PaymentAmount = DriveClient.RecalculateFromCurrencyToCurrency(
				TablePartRow.SettlementsAmount,
				TablePartRow.ExchangeRate,
				ExchangeRate,
				TablePartRow.Multiplicity,
				Multiplicity
			);
		EndIf;
	Else
		TablePartRow.ExchangeRate = ?(
			TablePartRow.SettlementsAmount = 0 Or TablePartRow.PaymentAmount = 0,
			StructureData.ContractCurrencyRateRepetition.ExchangeRate, //TablePartRow.ExchangeRate,
			TablePartRow.PaymentAmount / TablePartRow.SettlementsAmount * ExchangeRate
		);
		TablePartRow.Multiplicity = ?(
			TablePartRow.SettlementsAmount = 0 Or TablePartRow.PaymentAmount = 0,
			StructureData.ContractCurrencyRateRepetition.Multiplicity,
			TablePartRow.Multiplicity
		);
	EndIf;
	
	If Not ValueIsFilled(TablePartRow.VATRate) Then
		TablePartRow.VATRate = DefaultVATRate;
	EndIf;
	
	CalculateVATAmountAtClient(TablePartRow);
	
EndProcedure

&AtClient
Procedure CalculateVATAmountAtClient(TablePartRow)
	
	VATRate = DriveReUse.GetVATRateValue(TablePartRow.VATRate);
	
	TablePartRow.VATRate = TablePartRow.PaymentAmount - (TablePartRow.PaymentAmount) / ((VATRate + 100) / 100);
	
EndProcedure

&AtServerNoContext
Function GetChoiceFormParameters(Document, Company, Counterparty, Contract, OperationKind)
	
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
Function GetDataPaymentDetailsContractOnChange(Date, Contract, PlanningDocument = Undefined)
	
	StructureData = New Structure;
	
	StructureData.Insert(
		"ContractCurrencyRateRepetition",
		InformationRegisters.ExchangeRates.GetLast(
			Date,
			New Structure("Currency", Contract.SettlementsCurrency)
		)
	);
	StructureData.Insert("SettlementsCurrency", Contract.SettlementsCurrency);
	
	Return StructureData;
	
EndFunction

&AtServer
Procedure OperationKindOnChangeAtServer()
	
	SetChoiceParameterLinksAvailableTypes();
	
	SetVisibilityPrintReceipt();
	
	If OperationKind = PredefinedValue("Enum.OperationTypesCashReceipt.RetailIncomeEarningAccounting")
	 OR Not ValueIsFilled(OperationKind) Then
		User = Users.CurrentUser();
		SettingValue = DriveReUse.GetValueByDefaultUser(User, "MainDepartment");
		Object.Department = ?(ValueIsFilled(SettingValue), SettingValue, Catalogs.BusinessUnits.MainDepartment);
	EndIf;
	
	If Object.OperationKind = Enums.OperationTypesCashReceipt.OtherSettlements Then
		DefaultVATRate			= Catalogs.VATRates.Exempt;
		DefaultVATRateNumber	= DriveReUse.GetVATRateValue(DefaultVATRate);
		Object.PaymentDetails[0].VATRate = DefaultVATRate;
	Else
		FillVATRateByCompanyVATTaxation();
	EndIf;
		
	SetVisibilityItemsDependenceOnOperationKind();
	SetVisibilityEPDAttributes();
	SetCFItemWhenChangingTheTypeOfOperations();
	
EndProcedure

&AtClient
Procedure ProcessOnChangeCounterpartyContractOtherSettlements()
	
	TablePartRow = Items.PaymentDetailsOtherSettlements.CurrentData;
	
	If ValueIsFilled(TablePartRow.Contract) Then
		StructureData = GetDataPaymentDetailsContractOnChange(
			Object.Date,
			TablePartRow.Contract,
			TablePartRow.PlanningDocument
		);
		TablePartRow.ExchangeRate = ?(
			StructureData.ContractCurrencyRateRepetition.ExchangeRate = 0,
			1,
			StructureData.ContractCurrencyRateRepetition.ExchangeRate
		);
		TablePartRow.Multiplicity = ?(
			StructureData.ContractCurrencyRateRepetition.Multiplicity = 0,
			1,
			StructureData.ContractCurrencyRateRepetition.Multiplicity
		);
		
	EndIf;
	
	TablePartRow.SettlementsAmount = DriveClient.RecalculateFromCurrencyToCurrency(
		TablePartRow.PaymentAmount,
		ExchangeRate,
		TablePartRow.ExchangeRate,
		Multiplicity,
		TablePartRow.Multiplicity
	);
	
EndProcedure

&AtClient
Procedure ProcessStartChoiceCounterpartyContractOtherSettlements(Item, StandardProcessing)
	
	TablePartRow = Items.PaymentDetailsOtherSettlements.CurrentData;
	If TablePartRow = Undefined Then
		Return;
	EndIf;
	
	FormParameters = GetChoiceFormParameters(Object.Ref, Object.Company, Object.Counterparty, TablePartRow.Contract, Object.OperationKind);
	If FormParameters.ControlContractChoice Then
		
		StandardProcessing = False;
		OpenForm("Catalog.CounterpartyContracts.Form.ChoiceForm", FormParameters, Item);
		
	EndIf;
	
EndProcedure

&AtServer
Procedure SetChoiceParametersForAccountingOtherSettlementsAtServerForAccountItem()

	Item = Items.OtherSettlementsCorrespondence;
	
	ChoiceParametersItem	= New Array;
	FilterByAccountType		= New Array;

	For Each Parameter In Item.ChoiceParameters Do
		If Parameter.Name = "Filter.TypeOfAccount" Then
			FilterByAccountType.Add(Enums.GLAccountsTypes.AccountsReceivable);
			FilterByAccountType.Add(Enums.GLAccountsTypes.AccountsPayable);
			
			ChoiceParametersItem.Add(New ChoiceParameter("Filter.TypeOfAccount", New FixedArray(FilterByAccountType)));
		Else
			ChoiceParametersItem.Add(Parameter);
		EndIf;
	EndDo;
	
	Item.ChoiceParameters = New FixedArray(ChoiceParametersItem);
	
EndProcedure

&AtServer
Procedure SetChoiceParametersOnMetadataForAccountItem()

	Item = Items.OtherSettlementsCorrespondence;
	
	ChoiceParametersItem	= New Array;
	FilterByAccountType		= New Array;
	
	ChoiceParametersFromMetadata = Object.Ref.Metadata().Attributes.Correspondence.ChoiceParameters;
	For Each Parameter In ChoiceParametersFromMetadata Do
		ChoiceParametersItem.Add(Parameter);
	EndDo;
	
	Item.ChoiceParameters = New FixedArray(ChoiceParametersItem);
	
EndProcedure

&AtServer
Procedure SetVisibilityAttributesDependenceOnCorrespondence()
	
	SetVisibilityPlanningDocument();
	
EndProcedure

&AtServer
Procedure SetVisibilityItemsDependenceOnOperationKind()
	
	Items.PaymentDetailsPaymentAmount.Visible				= GetFunctionalOption("ForeignExchangeAccounting");
	Items.OtherSettlementsPaymentAmount.Visible				= GetFunctionalOption("ForeignExchangeAccounting");
		
	Items.SettlementsWithCounterparty.Visible				= False;
	Items.SettlementsWithAdvanceHolder.Visible				= False;
	Items.RetailIncome.Visible								= False;
	Items.RetailIncomeEarningAccounting.Visible				= False;
	Items.CurrencyPurchase.Visible							= False;
	Items.AdvanceHoldersPaymentDetailsPaymentAmount.Visible	= False;
	Items.OtherSettlements.Visible							= False;
	Items.RetailIncomePaymentDetailsVATRate.Visible			= False;
	Items.RetailRevenueDetailsOfPaymentAmountOfVat.Visible	= False;
	Items.VATTaxation.Visible								= False;
	Items.PlanningDocuments.Title							= NStr("en = 'Planning'");
	Items.DocumentAmount.Width								= 14;
	Items.AdvanceHolder.Visible								= False;
	Items.Counterparty.Visible								= False;
	
	// Miscellaneous payable
	Items.LoanSettlements.Visible	    	= False;
	Items.LoanSettlements.Title		        = NStr("en = 'Loan account statement'");
	Items.EmployeeLoanAgreement.Visible		= False;
	Items.FillByLoanContract.Visible		= False;
	Items.CreditContract.Visible			= False;
	Items.FillByCreditContract.Visible		= False;
	Items.GroupContractInformation.Visible	= False;
	Items.AdvanceHolder.Visible				= False;
	// End Miscellaneous payable
	
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesCashReceipt.FromCustomer") Then
		
		Items.SettlementsWithCounterparty.Visible	= True;
		Items.PaymentDetailsPickup.Visible			= True;
		Items.PaymentDetailsFillDetails.Visible		= True;
		
		Items.Counterparty.Visible	= True;
		Items.Counterparty.Title	= NStr("en = 'Customer'");
		Items.VATTaxation.Visible	= True;
		
		Items.PaymentAmount.Visible		= True;
		Items.PaymentAmount.Title		=  NStr("en = 'Payment amount'");
		Items.SettlementsAmount.Visible	= Not GetFunctionalOption("ForeignExchangeAccounting");
		
		Items.VATAmount.Visible	= Object.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT;
		
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesCashReceipt.FromVendor") Then
		
		Items.SettlementsWithCounterparty.Visible	= True;
		Items.PaymentDetailsPickup.Visible			= False;
		Items.PaymentDetailsFillDetails.Visible		= False;
		
		Items.Counterparty.Visible	= True;
		Items.Counterparty.Title	= NStr("en = 'Supplier'");
		Items.VATTaxation.Visible	= True;
		
		Items.PaymentAmount.Visible		= True;
		Items.PaymentAmount.Title		= NStr("en = 'Payment amount'");
		Items.SettlementsAmount.Visible	= Not GetFunctionalOption("ForeignExchangeAccounting");
		
		Items.VATAmount.Visible	= Object.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT;
		
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesCashReceipt.FromAdvanceHolder") Then
		
		Items.VATTaxation.Visible					= False;
		Items.SettlementsWithAdvanceHolder.Visible	= True;
		
		Items.AdvanceHoldersPaymentDetailsPaymentAmount.Visible	= GetFunctionalOption("PaymentCalendar");
		
		Items.AdvanceHolder.Visible	= True;
		Items.DocumentAmount.Width	= 13;
		
		Items.PaymentAmount.Visible		= GetFunctionalOption("PaymentCalendar");
		Items.PaymentAmount.Title		= ?(GetFunctionalOption("PaymentCalendar"), NStr("en = 'Amount (planned)'"), NStr("en = 'Payment amount'"));
		Items.SettlementsAmount.Visible	= False;
		Items.VATAmount.Visible			= False;
		
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesCashReceipt.RetailIncome") Then
		
		Items.AdvanceHoldersPaymentDetailsPaymentAmount.Visible	= GetFunctionalOption("PaymentCalendar");
		
		Items.RetailIncome.Visible	= True;
		Items.VATTaxation.Visible	= True;
		Items.RetailIncomePaymentDetailsVATRate.Visible			= Object.VATTaxation <> Enums.VATTaxationTypes.NotSubjectToVAT;
		Items.RetailRevenueDetailsOfPaymentAmountOfVat.Visible	= Object.VATTaxation <> Enums.VATTaxationTypes.NotSubjectToVAT;
		
		If GetFunctionalOption("PaymentCalendar") Then
			Items.PlanningDocuments.Title = NStr("en = 'VAT (planned)'");
		Else
			Items.PlanningDocuments.Title = NStr("en = 'VAT'");
		EndIf;
		
		Items.PaymentAmount.Visible		= GetFunctionalOption("PaymentCalendar");
		Items.PaymentAmount.Title		= ?(GetFunctionalOption("PaymentCalendar"), 
			NStr("en = 'Amount (planned)'"), 
			NStr("en = 'Payment amount'"));
		Items.SettlementsAmount.Visible = False;
		Items.VATAmount.Visible			= Object.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT;
		
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesCashReceipt.RetailIncomeEarningAccounting") Then
		
		Items.AdvanceHoldersPaymentDetailsPaymentAmount.Visible	= GetFunctionalOption("PaymentCalendar");
		
		Items.RetailIncomeEarningAccounting.Visible	= True;
		Items.VATTaxation.Visible					= True;
		Items.RetailIncomePaymentDetailsVATRate.Visible			= Object.VATTaxation <> Enums.VATTaxationTypes.NotSubjectToVAT;
		Items.RetailRevenueDetailsOfPaymentAmountOfVat.Visible	= Object.VATTaxation <> Enums.VATTaxationTypes.NotSubjectToVAT;
		
		If GetFunctionalOption("PaymentCalendar") Then
			Items.PlanningDocuments.Title = NStr("en = 'VAT (planned)'");
		Else
			Items.PlanningDocuments.Title = NStr("en = 'VAT'");
		EndIf;
		
		Items.PaymentAmount.Visible		= GetFunctionalOption("PaymentCalendar");
		Items.PaymentAmount.Title		= ?(GetFunctionalOption("PaymentCalendar"), NStr("en = 'Amount (planned)'"), NStr("en = 'Payment amount'"));
		Items.SettlementsAmount.Visible = False;
		Items.VATAmount.Visible			= Object.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT;
		
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesCashReceipt.CurrencyPurchase") Then
		
		Items.AdvanceHoldersPaymentDetailsPaymentAmount.Visible	= GetFunctionalOption("PaymentCalendar");
		
		Items.CurrencyPurchase.Visible	= True;
		
		Items.PaymentAmount.Visible 		= GetFunctionalOption("PaymentCalendar");
		Items.PaymentAmount.Title			= ?(GetFunctionalOption("PaymentCalendar"), NStr("en = 'Amount (planned)'"), NStr("en = 'Payment amount'"));
		Items.PaymentAmountCurrency.Visible	= Items.PaymentAmount.Visible;
		Items.SettlementsAmount.Visible		= False;
		Items.VATAmount.Visible				= False;
		
	// Miscellaneous payable	
	ElsIf OperationKind = PredefinedValue("Enum.OperationTypesCashReceipt.LoanSettlements") Then
		      
		Items.LoanSettlements.Visible					= True;
		Items.Counterparty.Visible							= True;
		Items.Counterparty.Title							= NStr("en = 'Lender'");;
		Items.LoanSettlements.Visible					= True;
		Items.SettlementsOnCreditsPaymentDetails.Visible	= False;	
		Items.CreditContract.Visible						= True;
		Items.FillByCreditContract.Visible					= True;
		
		FillInformationAboutCreditLoanAtServer();
		
		Items.GroupContractInformation.Visible = True;
		
		Items.PaymentAmount.Visible			= GetFunctionalOption("PaymentCalendar");
		Items.PaymentAmountCurrency.Visible	= Items.PaymentAmount.Visible;
		Items.PaymentAmount.Title			= NStr("en = 'Payment amount'");
		Items.SettlementsAmount.Visible		= False;
		Items.VATAmount.Visible				= False;
		
		Items.AdvanceHoldersPaymentDetailsPaymentAmount.Visible = GetFunctionalOption("PaymentCalendar");
		
	ElsIf OperationKind = PredefinedValue("Enum.OperationTypesCashReceipt.LoanRepaymentByEmployee") Then
		
		Items.AdvanceHolder.Visible							= True;
		Items.LoanSettlements.Title							= NStr("en = 'Loan account statement'");
		Items.LoanSettlements.Visible						= True;
		Items.VATTaxation.Visible							= True;
		Items.SettlementsOnCreditsPaymentDetails.Visible	= True;		
		Items.EmployeeLoanAgreement.Visible					= True;
		Items.FillByLoanContract.Visible					= True;
		
		FillInformationAboutCreditLoanAtServer();
		
		Items.GroupContractInformation.Visible	= True;	
		Items.PaymentAmount.Visible				= GetFunctionalOption("ForeignExchangeAccounting");
		Items.PaymentAmount.Title				= NStr("en = 'Payment amount'");
		Items.SettlementsAmount.Visible			= True;
		Items.VATAmount.Visible					= False;
		
		Items.SettlementsOnCreditsPaymentDetailsPaymentAmount.Visible = GetFunctionalOption("ForeignExchangeAccounting");	
		
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesCashReceipt.Other") Then
		
		Items.OtherSettlements.Visible	= True;
		
		Items.PaymentAmount.Visible 		= GetFunctionalOption("PaymentCalendar");
		Items.PaymentAmount.Title			= ?(GetFunctionalOption("PaymentCalendar"), 
			NStr("en = 'Amount (planned)'"), 
			NStr("en = 'Payment amount'"));
		Items.PaymentAmountCurrency.Visible	= Items.PaymentAmount.Visible;
		Items.SettlementsAmount.Visible		= False;
		Items.VATAmount.Visible				= False;
		
		Items.AdvanceHoldersPaymentDetailsPaymentAmount.Visible	= GetFunctionalOption("PaymentCalendar");
		
		Items.PageOtherSettlementsAsList.Visible	= False;
		Items.GroupAttributesFirstRow.Visible		= False;
		SetVisibilityAttributesDependenceOnCorrespondence();
		
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesCashReceipt.OtherSettlements") Then
		
		Items.OtherSettlements.Visible	= True;
		
		Items.PaymentAmount.Visible			= False;
		Items.PaymentAmount.Title			= NStr("en = 'Payment amount'");
		Items.PaymentAmountCurrency.Visible	= Items.PaymentAmount.Visible;
		Items.SettlementsAmount.Visible		= False;
		Items.VATAmount.Visible				= False;
		
		Items.Counterparty.Visible	= True;
		Items.Counterparty.Title	= NStr("en = 'Counterparty'");
		
		Items.PageOtherSettlementsAsList.Visible	= True;
		Items.OtherSettlementsContract.Visible		= Object.Counterparty.DoOperationsByContracts;
		Items.GroupAttributesFirstRow.Visible		= True;
		SetVisibilityAttributesDependenceOnCorrespondence();
		
		If Object.PaymentDetails.Count() > 0 Then
			ID = Object.PaymentDetails[0].GetID();
			Items.PaymentDetailsOtherSettlements.CurrentRow = ID;
		EndIf;
		
	// End Miscellaneous payable	
	Else
		
		Items.AdvanceHoldersPaymentDetailsPaymentAmount.Visible = GetFunctionalOption("PaymentCalendar");
		
		Items.OtherSettlements.Visible	= True;		
		Items.PaymentAmount.Visible		= True;
		Items.PaymentAmount.Title		= NStr("en = 'Amount (planned)'");
		Items.SettlementsAmount.Visible	= False;
		Items.VATAmount.Visible			= False;
		
	EndIf;
	
	SetVisibilityPlanningDocument();
	
EndProcedure

&AtServer
Procedure SetVisibilityPlanningDocument()
	
	If Object.OperationKind = Enums.OperationTypesCashReceipt.FromCustomer
		OR Object.OperationKind = Enums.OperationTypesCashReceipt.FromVendor
		OR (NOT GetFunctionalOption("PaymentCalendar")
		AND Items.RetailIncomePaymentDetailsVATRate.Visible = False
		AND Items.RetailRevenueDetailsOfPaymentAmountOfVat.Visible = False) Then
			Items.PlanningDocuments.Visible = False;
	ElsIf Object.OperationKind = Enums.OperationTypesCashReceipt.OtherSettlements
		OR Object.OperationKind = Enums.OperationTypesCashReceipt.LoanSettlements
		OR Object.OperationKind = Enums.OperationTypesCashReceipt.LoanRepaymentByEmployee Then
			Items.PlanningDocuments.Visible = False;
	Else
		Items.PlanningDocuments.Visible = True;
	EndIf;
	
EndProcedure

&AtServer
Procedure SetVisibilitySettlementAttributes()
	
	If ValueIsFilled(Object.Counterparty) Then
		DoOperationsStructure = CommonUse.ObjectAttributesValues(
			Object.Counterparty, 
			"DoOperationsByContracts,DoOperationsByDocuments,DoOperationsByOrders");
	Else
		DoOperationsStructure = New Structure("DoOperationsByContracts,DoOperationsByDocuments,DoOperationsByOrders",
			False,
			False,
			False);
	EndIf;
	
	Items.PaymentDetailsContract.Visible				= DoOperationsStructure.DoOperationsByContracts;
	Items.PaymentDetailsDocument.Visible				= DoOperationsStructure.DoOperationsByDocuments;
	Items.PaymentDetailsOrder.Visible					= DoOperationsStructure.DoOperationsByOrders;
	Items.OtherSettlementsContract.Visible				= DoOperationsStructure.DoOperationsByContracts;
	
EndProcedure

&AtServer
Procedure SetVisibilityEPDAttributes()
	
	If ValueIsFilled(Object.Counterparty) Then
		DoOperationsByDocuments = CommonUse.ObjectAttributeValue(Object.Counterparty, "DoOperationsByDocuments");
	Else
		DoOperationsByDocuments = False;
	EndIf;
	
	OperationKindFromCustomer = (Object.OperationKind = Enums.OperationTypesCashReceipt.FromCustomer);
	
	VisibleFlag = (DoOperationsByDocuments AND OperationKindFromCustomer);
	
	Items.PaymentDetailsEPDAmount.Visible				= VisibleFlag;
	Items.PaymentDetailsSettlementsEPDAmount.Visible	= VisibleFlag;
	Items.PaymentDetailsExistsEPD.Visible				= VisibleFlag;
	
EndProcedure

&AtServer
Procedure SetTaxInvoiceText()
	Items.TaxInvoiceText.Visible = Not WorkWithVAT.GetPostAdvancePaymentsBySourceDocuments(Object.Date, Object.Company)
EndProcedure

#EndRegion

#Region ExternalFormViewManagement

&AtServer
Procedure SetVisibilityPrintReceipt()
	
	PrintReceiptEnabled = False;
	
	Button = Items.Find("PrintReceipt");
	If Button <> Undefined Then
		
		If Object.OperationKind = Enums.OperationTypesCashReceipt.FromCustomer Then
			PrintReceiptEnabled = True;
		EndIf;
		
		Button.Enabled = PrintReceiptEnabled;
		Items.Decoration3.Visible = PrintReceiptEnabled;
		Items.SalesSlipNumber.Visible = PrintReceiptEnabled;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure SetChoiceParameterLinksAvailableTypes()
	
	// Other settlemets
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesCashReceipt.OtherSettlements") Then
		SetChoiceParametersForAccountingOtherSettlementsAtServerForAccountItem();
	Else
		SetChoiceParametersOnMetadataForAccountItem();
	EndIf;
	// End Other settlemets
	
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesCashReceipt.FromCustomer") Then
		
		Array = New Array();
		Array.Add(Type("DocumentRef.FixedAssetSale"));
		Array.Add(Type("DocumentRef.SupplierInvoice"));
		Array.Add(Type("DocumentRef.SalesInvoice"));
		Array.Add(Type("DocumentRef.SalesOrder"));
		Array.Add(Type("DocumentRef.AccountSalesFromConsignee"));
		Array.Add(Type("DocumentRef.SubcontractorReportIssued"));
		Array.Add(Type("DocumentRef.ArApAdjustments"));
		
		ValidTypes = New TypeDescription(Array, , );
		Items.PaymentDetails.ChildItems.PaymentDetailsDocument.TypeRestriction = ValidTypes;
		
		ValidTypes = New TypeDescription("DocumentRef.SalesOrder", , );
		Items.PaymentDetailsOrder.TypeRestriction = ValidTypes;
		
		Items.PaymentDetailsDocument.ToolTip = NStr("en = 'The document that is paid for.'");
		
		
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesCashReceipt.FromVendor") Then
		
		Array = New Array();
		Array.Add(Type("DocumentRef.ExpenseReport"));
		Array.Add(Type("DocumentRef.CashVoucher"));
		Array.Add(Type("DocumentRef.PaymentExpense"));
		Array.Add(Type("DocumentRef.ArApAdjustments"));
		Array.Add(Type("DocumentRef.AdditionalExpenses"));
		Array.Add(Type("DocumentRef.AccountSalesToConsignor"));
		Array.Add(Type("DocumentRef.SubcontractorReport"));
		Array.Add(Type("DocumentRef.SupplierInvoice"));
		Array.Add(Type("DocumentRef.SalesInvoice"));
		
		ValidTypes = New TypeDescription(Array,,);
		Items.PaymentDetailsDocument.TypeRestriction = ValidTypes;
		
		ValidTypes = New TypeDescription("DocumentRef.PurchaseOrder",,);
		Items.PaymentDetailsOrder.TypeRestriction = ValidTypes;
		
		Items.PaymentDetailsDocument.ToolTip = NStr("en = 'An advance payment document that should be returned.'");
		
	EndIf;
	
EndProcedure

#EndRegion

#Region GeneralPurposeProceduresAndFunctions

// Procedure of the field change data processor Operation kind on server.
//
&AtServer
Procedure SetCFItemWhenChangingTheTypeOfOperations()
	
	If (Object.OperationKind = Enums.OperationTypesCashReceipt.FromCustomer
		OR Object.OperationKind = Enums.OperationTypesCashReceipt.RetailIncome
		OR Object.OperationKind = Enums.OperationTypesCashReceipt.RetailIncomeEarningAccounting)
		AND (Object.Item = Catalogs.CashFlowItems.PaymentToVendor
		OR Object.Item = Catalogs.CashFlowItems.Other) Then
		Object.Item = Catalogs.CashFlowItems.PaymentFromCustomers;
	ElsIf Object.OperationKind = Enums.OperationTypesCashReceipt.FromVendor 
		AND (Object.Item = Catalogs.CashFlowItems.PaymentFromCustomers
		OR Object.Item = Catalogs.CashFlowItems.Other) Then
		Object.Item = Catalogs.CashFlowItems.PaymentToVendor;
	ElsIf (Object.OperationKind = Enums.OperationTypesCashReceipt.FromAdvanceHolder
		OR Object.OperationKind = Enums.OperationTypesCashReceipt.CurrencyPurchase
		OR Object.OperationKind = Enums.OperationTypesCashReceipt.LoanSettlements
		OR Object.OperationKind = Enums.OperationTypesCashReceipt.LoanRepaymentByEmployee
		OR Object.OperationKind = Enums.OperationTypesCashReceipt.Other)
		AND (Object.Item = Catalogs.CashFlowItems.PaymentFromCustomers
		OR Object.Item = Catalogs.CashFlowItems.PaymentToVendor) Then
		Object.Item = Catalogs.CashFlowItems.Other;
	EndIf;
	
EndProcedure

// The procedure sets CF item when opening the form.
//
&AtServer
Procedure SetCFItem()
	
	If Object.OperationKind = Enums.OperationTypesCashReceipt.FromCustomer
		OR Object.OperationKind = Enums.OperationTypesCashReceipt.RetailIncome
		OR Object.OperationKind = Enums.OperationTypesCashReceipt.RetailIncomeEarningAccounting Then
		Object.Item = Catalogs.CashFlowItems.PaymentFromCustomers;
	ElsIf Object.OperationKind = Enums.OperationTypesCashReceipt.FromVendor Then
		Object.Item = Catalogs.CashFlowItems.PaymentToVendor;
	Else
		Object.Item = Catalogs.CashFlowItems.Other;
	EndIf;
	
EndProcedure

// Procedure expands the operation kinds selection list.
//
&AtServer
Procedure SupplementOperationTypesChoiceList()
	
	If Constants.UseRetail.Get() Then
		Items.OperationKind.ChoiceList.Add(Enums.OperationTypesCashReceipt.RetailIncome);
		Items.OperationKind.ChoiceList.Add(Enums.OperationTypesCashReceipt.RetailIncomeEarningAccounting);
	EndIf;
	
	If Constants.ForeignExchangeAccounting.Get() Then
		Items.OperationKind.ChoiceList.Add(Enums.OperationTypesCashReceipt.CurrencyPurchase);
	EndIf;
	
	Items.OperationKind.ChoiceList.Add(Enums.OperationTypesCashReceipt.Other);
	Items.OperationKind.ChoiceList.Add(Enums.OperationTypesCashReceipt.OtherSettlements);
	
	Items.OperationKind.ChoiceList.Add(Enums.OperationTypesCashReceipt.LoanRepaymentByEmployee);
	Items.OperationKind.ChoiceList.Add(Enums.OperationTypesCashReceipt.LoanSettlements);
	
EndProcedure

// Procedure calls the data processor for document filling by basis.
//
&AtServer
Procedure FillByDocument(BasisDocument)
	
	Document = FormAttributeToValue("Object");
	Document.Fill(BasisDocument);
	ValueToFormAttribute(Document, "Object");
	Modified = True;
	
	SetVisibleOfVATTaxation();
	SetVisibilitySettlementAttributes();
	SetVisibilityEPDAttributes();
	
EndProcedure

// Function puts the SettlementsDetails tabular section to
// the temporary storage and returns an address
//
&AtServer
Function PlacePaymentDetailsToStorage()
	
	Return PutToTempStorage(
		Object.PaymentDetails.Unload(,
			"Contract,
			|AdvanceFlag,
			|Document,
			|Order,
			|SettlementsAmount,
			|ExchangeRate,
			|Multiplicity"
		),
		UUID
	);
	
EndFunction

// Function receives the SettlementsDetails tabular section from the temporary storage.
//
&AtServer
Procedure GetPaymentDetailsFromStorage(AddressPaymentDetailsInStorage)
	
	TableExplanationOfPayment = GetFromTempStorage(AddressPaymentDetailsInStorage);
	Object.PaymentDetails.Clear();
	For Each RowPaymentDetails In TableExplanationOfPayment Do
		String = Object.PaymentDetails.Add();
		FillPropertyValues(String, RowPaymentDetails);
	EndDo;
	
EndProcedure

// Recalculates amounts by the document tabular section
// currency after changing the bank account or petty cash.
//
&AtClient
Procedure RecalculateDocumentAmounts(ExchangeRate, Multiplicity, RecalculatePaymentAmount)
	
	For Each TabularSectionRow In Object.PaymentDetails Do
		If RecalculatePaymentAmount Then
			TabularSectionRow.PaymentAmount = DriveClient.RecalculateFromCurrencyToCurrency(
				TabularSectionRow.SettlementsAmount,
				TabularSectionRow.ExchangeRate,
				ExchangeRate,
				TabularSectionRow.Multiplicity,
				Multiplicity
			);
			CalculateVATSUM(TabularSectionRow);
		Else
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
			TabularSectionRow.SettlementsAmount = DriveClient.RecalculateFromCurrencyToCurrency(
				TabularSectionRow.PaymentAmount,
				ExchangeRate,
				TabularSectionRow.ExchangeRate,
				Multiplicity,
				TabularSectionRow.Multiplicity
			);
		EndIf;
	EndDo;
	
	If RecalculatePaymentAmount Then
		Object.DocumentAmount = Object.PaymentDetails.Total("PaymentAmount");
	EndIf;
	
EndProcedure

&AtClient
Procedure DateOnChangeQueryBoxHandler(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		
		UpdatePaymentDetailsExchangeRatesAtServer();
		RecalculateAmountsOnCashAssetsCurrencyRateChange(AdditionalParameters);
		
	EndIf;
	
EndProcedure

&AtServer
Procedure UpdatePaymentDetailsExchangeRatesAtServer()
	
	For each TSRow In Object.PaymentDetails Do
			
		If ValueIsFilled(TSRow.Contract) Then
			StructureData = GetDataPaymentDetailsContractOnChange(
				Object.Date,
				TSRow.Contract
			);
			TSRow.ExchangeRate = ?(
				StructureData.ContractCurrencyRateRepetition.ExchangeRate = 0,
				1,
				StructureData.ContractCurrencyRateRepetition.ExchangeRate
			);
			TSRow.Multiplicity = ?(
				StructureData.ContractCurrencyRateRepetition.Multiplicity = 0,
				1,
				StructureData.ContractCurrencyRateRepetition.Multiplicity
			);
		EndIf;
		
	EndDo;
	
EndProcedure

// Recalculates amounts by the cash assets currency.
//
&AtClient
Procedure RecalculateAmountsOnCashAssetsCurrencyRateChange(StructureData)
	
	ExchangeRateBeforeChange = ExchangeRate;
	MultiplicityBeforeChange = Multiplicity;
	
	If ValueIsFilled(Object.CashCurrency) Then
		ExchangeRate = ?(
			StructureData.CurrencyRateRepetition.ExchangeRate = 0,
			1,
			StructureData.CurrencyRateRepetition.ExchangeRate
		);
		Multiplicity = ?(
			StructureData.CurrencyRateRepetition.Multiplicity = 0,
			1,
			StructureData.CurrencyRateRepetition.Multiplicity
		);
		If Object.OperationKind = PredefinedValue("Enum.OperationTypesCashReceipt.CurrencyPurchase") Then
			Object.ExchangeRate = ExchangeRate;
			Object.Multiplicity = Multiplicity;
		EndIf;
	EndIf;
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("ExchangeRateBeforeChange", ExchangeRateBeforeChange);
	AdditionalParameters.Insert("MultiplicityBeforeChange", MultiplicityBeforeChange);
	
	DetermineNeedForDocumentAmountRecalculation(AdditionalParameters);
	
EndProcedure

&AtClient
Procedure DefinePaymentDetailsExistsEPD()
	
	DefinePaymentDetailsExistsEPDAtServer();
	
EndProcedure

&AtServer
Procedure DefinePaymentDetailsExistsEPDAtServer()
	
	Document = FormAttributeToValue("Object");
	Document.DefinePaymentDetailsExistsEPD();
	ValueToFormAttribute(Document, "Object");
	Modified = True;
	
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
		ExchangeRate,
		TabularSectionRow.Multiplicity,
		Multiplicity
	);
	
	If Not ValueIsFilled(TabularSectionRow.VATRate) Then
		TabularSectionRow.VATRate = DefaultVATRate;
	EndIf;
	
	CalculateVATSUM(TabularSectionRow);
	
EndProcedure

&AtClient
Procedure CalculateSettlmentsAmount(TabularSectionRow)
	
	TabularSectionRow.ExchangeRate = ?(TabularSectionRow.ExchangeRate = 0, 1, TabularSectionRow.ExchangeRate);
	TabularSectionRow.Multiplicity = ?(TabularSectionRow.Multiplicity = 0, 1, TabularSectionRow.Multiplicity);
	
	TabularSectionRow.SettlementsAmount = TabularSectionRow.PaymentAmount * ExchangeRate / Multiplicity
											/ TabularSectionRow.ExchangeRate * TabularSectionRow.Multiplicity;
	
EndProcedure

&AtClient
Procedure CalculateSettlmentsEPDAmount(TabularSectionRow)
	
	TabularSectionRow.ExchangeRate = ?(TabularSectionRow.ExchangeRate = 0, 1, TabularSectionRow.ExchangeRate);
	TabularSectionRow.Multiplicity = ?(TabularSectionRow.Multiplicity = 0, 1, TabularSectionRow.Multiplicity);
	
	TabularSectionRow.SettlementsEPDAmount = TabularSectionRow.EPDAmount * ExchangeRate / Multiplicity
		/ TabularSectionRow.ExchangeRate * TabularSectionRow.Multiplicity;
	
EndProcedure

// Perform recalculation of the amount accounting.
//
&AtClient
Procedure CalculateAccountingAmount()
	
	Object.ExchangeRate = ?(
		Object.ExchangeRate = 0,
		1,
		Object.ExchangeRate
	);
	Object.Multiplicity = ?(
		Object.Multiplicity = 0,
		1,
		Object.Multiplicity
	);
	
	Object.AccountingAmount = DriveClient.RecalculateFromCurrencyToCurrency(
		Object.DocumentAmount,
		Object.ExchangeRate,
		AccountingCurrencyRate,
		Object.Multiplicity,
		AccountingCurrencyMultiplicity
	);
	
EndProcedure

// Recalculates amounts by the document tabular section
// currency after changing the bank account or petty cash.
//
&AtClient
Procedure CalculateVATSUM(TabularSectionRow)
	
	VATRate = DriveReUse.GetVATRateValue(TabularSectionRow.VATRate);
	
	TabularSectionRow.VATAmount = TabularSectionRow.PaymentAmount - (TabularSectionRow.PaymentAmount) / ((VATRate + 100) / 100);
	
EndProcedure

// It receives data set from the server for the CounterpartyOnChange procedure.
//
&AtServer
Function GetDataCounterpartyOnChange(Counterparty, Company, Date)
	
	ContractByDefault = GetContractByDefault(Object.Ref, Counterparty, Company, Object.OperationKind);
	
	StructureData = New Structure;
	
	StructureData.Insert(
		"CounterpartyDescriptionFull",
		Counterparty.DescriptionFull
	);
	
	StructureData.Insert(
		"Contract",
		ContractByDefault
	);
	
	StructureData.Insert(
		"ContractCurrencyRateRepetition",
		InformationRegisters.ExchangeRates.GetLast(
			Date,
			New Structure("Currency", ContractByDefault.SettlementsCurrency)
		)
	);
	
	StructureData.Insert(
		"DoOperationsByContracts",
		Counterparty.DoOperationsByContracts
	);
	
	StructureData.Insert(
		"DoOperationsByDocuments",
		Counterparty.DoOperationsByDocuments
	);
	
	StructureData.Insert(
		"DoOperationsByOrders",
		Counterparty.DoOperationsByOrders
	);
	
	If Object.OperationKind = Enums.OperationTypesCashReceipt.LoanSettlements Then
		DefaultLoanContract = GetDefaultLoanContract(Object.Ref, Counterparty, Company, Object.OperationKind);
		StructureData.Insert(
			"DefaultLoanContract",
			DefaultLoanContract
		);
	EndIf;
	
	SetVisibilitySettlementAttributes();
	SetVisibilityEPDAttributes();
	
	Return StructureData;
	
EndFunction

// It receives data set from the server for the CurrencyCashOnChange procedure.
//
&AtServerNoContext
Function GetDataCashAssetsCurrencyOnChange(Date, CashCurrency)
	
	StructureData = New Structure;
	
	StructureData.Insert(
		"CurrencyRateRepetition",
		InformationRegisters.ExchangeRates.GetLast(
			Date,
			New Structure("Currency", CashCurrency)
		)
	);
	
	Return StructureData;
	
EndFunction

// Receives data set from the server for the AdvanceHolderOnChange procedure.
//
&AtServerNoContext
Function GetDataAdvanceHolderOnChange(AdvanceHolder)
	
	StructureData = New Structure;
	
	StructureData.Insert("AdvanceHolderDescription", AdvanceHolder.Description);
	
	Return StructureData;
	
EndFunction

// It receives data set from server for the ContractOnChange procedure.
//
&AtServer
Function GetDataDateOnChange(DateBeforeChange)
	
	DATEDIFF = DriveServer.CheckDocumentNumber(Object.Ref, Object.Date, DateBeforeChange);
	CurrencyRateRepetition = InformationRegisters.ExchangeRates.GetLast(Object.Date, New Structure("Currency", Object.CashCurrency));
	
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
	SetTaxInvoiceText();
	
	Return StructureData;
	
EndFunction

// It receives data set from server for the ContractOnChange procedure.
//
&AtServer
Function GetCompanyDataOnChange()
	
	StructureData = New Structure;
	StructureData.Insert("ParentCompany", DriveServer.GetCompany(Object.Company));
	
	FillVATRateByCompanyVATTaxation();
	SetTaxInvoiceText();
	
	Return StructureData;
	
EndFunction

// Procedure fills in default VAT rate.
//
&AtServer
Procedure FillDefaultVATRate()
	
	If Object.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then
		DefaultVATRate = InformationRegisters.AccountingPolicy.GetDefaultVATRate(Object.Date, Object.Company);
	ElsIf Object.VATTaxation = Enums.VATTaxationTypes.NotSubjectToVAT Then
		DefaultVATRate = Catalogs.VATRates.Exempt;
	Else
		DefaultVATRate = Catalogs.VATRates.ZeroRate;
	EndIf;
	
EndProcedure

// Procedure fills the VAT rate in the tabular section
// according to company's taxation system.
// 
&AtServer
Procedure FillVATRateByCompanyVATTaxation()
	
	TaxationBeforeChange = Object.VATTaxation;
	
	If Object.OperationKind = Enums.OperationTypesCashReceipt.FromCustomer 
		OR Object.OperationKind = Enums.OperationTypesCashReceipt.RetailIncomeEarningAccounting
		OR Object.OperationKind = Enums.OperationTypesCashReceipt.RetailIncome Then
		
		Object.VATTaxation = DriveServer.VATTaxation(Object.Company, Object.Date);
		
	ElsIf Object.OperationKind = Enums.OperationTypesCashReceipt.FromAdvanceHolder
		Or Object.OperationKind = Enums.OperationTypesCashReceipt.LoanSettlements
		Or Object.OperationKind = Enums.OperationTypesCashReceipt.LoanRepaymentByEmployee Then
		Object.VATTaxation = Enums.VATTaxationTypes.NotSubjectToVAT;		
	Else		
		Object.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT;		
	EndIf;
	
	If Not (Object.OperationKind = Enums.OperationTypesCashReceipt.FromAdvanceHolder
		OR Object.OperationKind = Enums.OperationTypesCashReceipt.Other
		OR Object.OperationKind = Enums.OperationTypesCashReceipt.CurrencyPurchase)
	   AND Not TaxationBeforeChange = Object.VATTaxation Then
		
		FillVATRateByVATTaxation();
		
	Else		
		FillDefaultVATRate();		
	EndIf;
	
EndProcedure

// Procedure fills the VAT rate in the tabular section according to the taxation system.
//
&AtServer
Procedure FillVATRateByVATTaxation(RestoreRatesOfVAT = True)
	
	FillDefaultVATRate();
	
	SetVisibleOfVATTaxation();
	
	If Object.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then
				
		VATRate = DriveReUse.GetVATRateValue(DefaultVATRate);
		
		If RestoreRatesOfVAT Then
			For Each TabularSectionRow In Object.PaymentDetails Do
				TabularSectionRow.VATRate = InformationRegisters.AccountingPolicy.GetDefaultVATRate(Object.Date, Object.Company);
				TabularSectionRow.VATAmount = TabularSectionRow.PaymentAmount - (TabularSectionRow.PaymentAmount) / ((VATRate + 100) / 100);
			EndDo;
		EndIf;
		
	Else
				
		If RestoreRatesOfVAT Then
			For Each TabularSectionRow In Object.PaymentDetails Do
				TabularSectionRow.VATRate = DefaultVATRate;
				TabularSectionRow.VATAmount = 0;
			EndDo;
		EndIf;
		
	EndIf;
	
	SetVisibilityPlanningDocument();
	
EndProcedure

// Procedure sets the Taxation field visible.
//
&AtServer
Procedure SetVisibleOfVATTaxation()
	
	If Object.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then
		
		Items.PaymentDetailsVATRate.Visible							= True;
		Items.PaymentDetailsVatAmount.Visible						= True;
		Items.SettlementsOnCreditsPaymentDetailsVATRate.Visible		= True;
		Items.SettlementsOnCreditsPaymentDetailsVATAmount.Visible	= True;
		Items.RetailIncomePaymentDetailsVATRate.Visible				= True;
		Items.RetailRevenueDetailsOfPaymentAmountOfVat.Visible		= True;
		Items.VATAmount.Visible										= True;
		
	Else
		
		Items.RetailIncomePaymentDetailsVATRate.Visible				= False;
		Items.RetailRevenueDetailsOfPaymentAmountOfVat.Visible		= False;
		Items.SettlementsOnCreditsPaymentDetailsVATRate.Visible		= False;
		Items.SettlementsOnCreditsPaymentDetailsVATAmount.Visible	= False;
		Items.PaymentDetailsVATRate.Visible							= False;
		Items.PaymentDetailsVatAmount.Visible						= False;
		Items.VATAmount.Visible										= False;
		
	EndIf;
	
EndProcedure

// Procedure executes actions while changing counterparty contract.
//
&AtClient
Procedure ProcessCounterpartyContractChange()
	
	TabularSectionRow = Items.PaymentDetails.CurrentData;
	
	If ValueIsFilled(TabularSectionRow.Contract) Then
		StructureData = GetDataPaymentDetailsContractOnChange(
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
		ExchangeRate,
		TabularSectionRow.ExchangeRate,
		Multiplicity,
		TabularSectionRow.Multiplicity
	);
	
EndProcedure

// Procedure executes actions while starting to select a counterparty contract.
//
&AtClient
Procedure ProcessStartChoiceCounterpartyContract(Item, StandardProcessing)
	
	TabularSectionRow = Items.PaymentDetails.CurrentData;
	If TabularSectionRow = Undefined Then
		Return;
	EndIf;
	
	FormParameters = GetChoiceFormParameters(Object.Ref, Object.Company, Object.Counterparty, TabularSectionRow.Contract, Object.OperationKind);
	If FormParameters.ControlContractChoice Then
		
		StandardProcessing = False;
		OpenForm("Catalog.CounterpartyContracts.Form.ChoiceForm", FormParameters, Item);
		
	EndIf;
	
EndProcedure

// Procedure fills in the PaymentDetails TS string with the billing document data.
//
&AtClient
Procedure ProcessAccountsDocumentSelection(DocumentData)
	
	TabularSectionRow = Items.PaymentDetails.CurrentData;
	If TypeOf(DocumentData) = Type("Structure") Then
		
		TabularSectionRow.Document = DocumentData.Document;
		TabularSectionRow.Order = DocumentData.Order;
		
		If Not ValueIsFilled(TabularSectionRow.Contract) Then
			TabularSectionRow.Contract = DocumentData.Contract;
			ProcessCounterpartyContractChange();
		EndIf;
		
		RunActionsOnAccountsDocumentChange();
		
		Modified = True;
		
	EndIf;
	
EndProcedure

// Procedure determines an advance flag depending on the billing document type.
//
&AtClient
Procedure RunActionsOnAccountsDocumentChange()
	
	TabularSectionRow = Items.PaymentDetails.CurrentData;
	
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesCashReceipt.FromVendor") Then
		
		If TypeOf(TabularSectionRow.Document) = Type("DocumentRef.CashVoucher")
			OR TypeOf(TabularSectionRow.Document) = Type("DocumentRef.PaymentExpense")
			OR TypeOf(TabularSectionRow.Document) = Type("DocumentRef.ExpenseReport") Then
			
			TabularSectionRow.AdvanceFlag = True;
			
		Else
			
			TabularSectionRow.AdvanceFlag = False;
			
		EndIf;
		
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesCashReceipt.FromCustomer") Then
		
		If TypeOf(TabularSectionRow.Document) = Type("DocumentRef.SalesInvoice") Then
			
			SetExistsEPD(TabularSectionRow);
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure SetExistsEPD(TabularSectionRow)
	
	TabularSectionRow.ExistsEPD = ExistsEPD(TabularSectionRow.Document, Object.Date);
	
EndProcedure

&AtServerNoContext
Function ExistsEPD(Document, CheckDate)
	
	Return Documents.SalesInvoice.CheckExistsEPD(Document, CheckDate);
	
EndFunction

// Procedure is filling the payment details.
//
&AtServer
Procedure FillPaymentDetails(CurrentObject = Undefined)
	
	Document = FormAttributeToValue("Object");
	Document.FillPaymentDetails();
	ValueToFormAttribute(Document, "Object");
	Modified = True;
	
EndProcedure

// Procedure receives the default petty cash currency.
//
&AtServerNoContext
Function GetPettyCashAccountingCurrencyAtServer(Date, PettyCash)
	
	StructureData = New Structure;
	StructureData.Insert("CashCurrency", CommonUse.ObjectAttributeValue(PettyCash, "CurrencyByDefault"));
	
	StructureData.Insert("CurrencyRateRepetition",
		InformationRegisters.ExchangeRates.GetLast(Date, New Structure("Currency", StructureData.CashCurrency)));
		
	Return StructureData;
	
EndFunction

// Checks the match of the "Company" and "ContractKind" contract attributes to the terms of the document.
//
&AtServerNoContext
Procedure CheckContractToDocumentConditionAccordance(Val TSPaymentDetails, MessageText, Document, Company, Counterparty, OperationKind, Cancel, LoanContract)
	
	If Not DriveReUse.CounterpartyContractsControlNeeded()
		OR Not Counterparty.DoOperationsByContracts Then
		
		Return;
	EndIf;
	
	ManagerOfCatalog = Catalogs.CounterpartyContracts;
	
	If OperationKind = Enums.OperationTypesCashVoucher.LoanSettlements Then
		
		ContractKindList = New ValueList;
		ContractKindList.Add(Enums.LoanContractTypes.Borrowed);
		
		If Not ManagerOfCatalog.ContractMeetsDocumentTerms(MessageText, LoanContract, Company, Counterparty, ContractKindList)
			AND Constants.CheckContractsOnPosting.Get() Then
			
			Cancel = True;
			
		EndIf;
		
	Else
		ContractKindsList = ManagerOfCatalog.GetContractKindsListForDocument(Document, OperationKind);
		
		For Each TabularSectionRow In TSPaymentDetails Do
			
			If Not ManagerOfCatalog.ContractMeetsDocumentTerms(MessageText, TabularSectionRow.Contract, Company, Counterparty, ContractKindsList)
				AND Constants.CheckContractsOnPosting.Get() Then
				
				Cancel = True;
				Break;
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
EndProcedure

// Gets the default contract depending on the billing details.
//
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

&AtServerNoContext
Function GetSubordinateCreditNote(BasisDocument)
	
	Return EarlyPaymentDiscountsServer.GetSubordinateCreditNote(BasisDocument);
	
EndFunction

&AtServerNoContext
Function CheckBeforeCreditNoteFilling(BasisDocument)
	
	Return EarlyPaymentDiscountsServer.CheckBeforeCreditNoteFilling(BasisDocument, False)
	
EndFunction

#EndRegion

#Region ProceduresAndFunctionsForControlOfTheFormAppearance

// Procedure sets the current page depending on the operation kind.
//
&AtClient
Procedure SetCurrentPage()
	
	LineCount = Object.PaymentDetails.Count();
	
	If LineCount = 0 Then
		Object.PaymentDetails.Add();
		Object.PaymentDetails[0].PaymentAmount = Object.DocumentAmount;
		LineCount = 1;
	EndIf;
	
EndProcedure

// The procedure clears the attributes that could have been
// filled in earlier but do not belong to the current operation.
//
&AtClient
Procedure ClearAttributesNotRelatedToOperation()
	
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesCashReceipt.FromCustomer")
	 OR Object.OperationKind = PredefinedValue("Enum.OperationTypesCashReceipt.FromVendor") Then
		Object.Correspondence = Undefined;
		Object.AdvanceHolder = Undefined;
		Object.Document = Undefined;
		Object.Department = Undefined;
		Object.BusinessLine = Undefined;
		Object.CashCR = Undefined;
		Object.StructuralUnit = Undefined;
		Object.AccountingAmount = 0;
		Object.ExchangeRate = 0;
		Object.Multiplicity = 0;
		For Each TableRow In Object.PaymentDetails Do
			TableRow.Order = Undefined;
			TableRow.Document = Undefined;
			TableRow.AdvanceFlag = False;
			If Object.OperationKind = PredefinedValue("Enum.OperationTypesCashReceipt.FromVendor") Then
				TableRow.EPDAmount = 0;
				TableRow.SettlementsEPDAmount = 0;
				TableRow.ExistsEPD = False;
			EndIf;
		EndDo;
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesCashReceipt.FromAdvanceHolder") Then
		Object.Correspondence = Undefined;
		Object.Counterparty = Undefined;
		Object.CashCR = Undefined;
		Object.StructuralUnit = Undefined;
		Object.Department = Undefined;
		Object.BusinessLine = Undefined;
		Object.AccountingAmount = 0;
		Object.ExchangeRate = 0;
		Object.Multiplicity = 0;
		For Each TableRow In Object.PaymentDetails Do
			TableRow.Contract = Undefined;
			TableRow.AdvanceFlag = False;
			TableRow.Document = Undefined;
			TableRow.Order = Undefined;
			TableRow.VATRate = Undefined;
			TableRow.VATAmount = Undefined;
		EndDo;
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesCashReceipt.RetailIncome") Then
		Object.Counterparty = Undefined;
		Object.AdvanceHolder = Undefined;
		Object.Document = Undefined;
		Object.StructuralUnit = Undefined;
		Object.Department = Undefined;
		Object.BusinessLine = Undefined;
		Object.AccountingAmount = 0;
		Object.ExchangeRate = 0;
		Object.Multiplicity = 0;
		For Each TableRow In Object.PaymentDetails Do
			TableRow.Contract = Undefined;
			TableRow.AdvanceFlag = False;
			TableRow.Document = Undefined;
			TableRow.Order = Undefined;
		EndDo;
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesCashReceipt.RetailIncomeEarningAccounting") Then
		Object.Counterparty = Undefined;
		Object.AdvanceHolder = Undefined;
		Object.Document = Undefined;
		Object.CashCR = Undefined;
		Object.AccountingAmount = 0;
		Object.ExchangeRate = 0;
		Object.Multiplicity = 0;
		For Each TableRow In Object.PaymentDetails Do
			TableRow.Contract = Undefined;
			TableRow.AdvanceFlag = False;
			TableRow.Document = Undefined;
			TableRow.SettlementsAmount = 0;
			TableRow.ExchangeRate = 0;
			TableRow.Multiplicity = 0;
			TableRow.Order = Undefined;
		EndDo;
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesCashReceipt.LoanSettlements") Then
		Object.Correspondence = Undefined;
		Object.Counterparty = Undefined;
		Object.AdvanceHolder = Undefined;
		Object.Document = Undefined;
		Object.CashCR = Undefined;
		Object.StructuralUnit = Undefined;
		Object.Department = Undefined;
		Object.BusinessLine = Undefined;
		Object.AccountingAmount = 0;
		Object.ExchangeRate = 0;
		Object.Multiplicity = 0;
		For Each TableRow In Object.PaymentDetails Do
			TableRow.Contract = Undefined;
			TableRow.AdvanceFlag = False;
			TableRow.Document = Undefined;
			TableRow.Order = Undefined;
			TableRow.VATRate = Undefined;
			TableRow.VATAmount = Undefined;
		EndDo;
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesCashReceipt.LoanRepaymentByEmployee") Then
		Object.Correspondence = Undefined;
		Object.Counterparty = Undefined;
		Object.AdvanceHolder = Undefined;
		Object.Document = Undefined;
		Object.CashCR = Undefined;
		Object.StructuralUnit = Undefined;
		Object.Department = Undefined;
		Object.BusinessLine = Undefined;
		Object.AccountingAmount = 0;
		Object.ExchangeRate = 0;
		Object.Multiplicity = 0;
		For Each TableRow In Object.PaymentDetails Do
			TableRow.Contract = Undefined;
			TableRow.AdvanceFlag = False;
			TableRow.Document = Undefined;
			TableRow.Order = Undefined;
			TableRow.VATRate = Undefined;
			TableRow.VATAmount = Undefined;
		EndDo;
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesCashReceipt.Other") Then
		Object.Counterparty = Undefined;
		Object.AdvanceHolder = Undefined;
		Object.Document = Undefined;
		Object.CashCR = Undefined;
		Object.StructuralUnit = Undefined;
		Object.Department = Undefined;
		Object.BusinessLine = Undefined;
		Object.AccountingAmount = 0;
		Object.ExchangeRate = 0;
		Object.Multiplicity = 0;
		For Each TableRow In Object.PaymentDetails Do
			TableRow.Contract = Undefined;
			TableRow.AdvanceFlag = False;
			TableRow.Document = Undefined;
			TableRow.Order = Undefined;
			TableRow.VATRate = Undefined;
			TableRow.VATAmount = Undefined;
		EndDo;
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesCashReceipt.CurrencyPurchase") Then
		Object.Counterparty = Undefined;
		Object.AdvanceHolder = Undefined;
		Object.Document = Undefined;
		Object.CashCR = Undefined;
		Object.StructuralUnit = Undefined;
		Object.Department = Undefined;
		Object.BusinessLine = Undefined;
		Object.ExchangeRate = ?(ValueIsFilled(ExchangeRate),
			ExchangeRate,
			1
		);
		Object.Multiplicity = ?(ValueIsFilled(Multiplicity),
			Multiplicity, 1
		);
		CalculateAccountingAmount();
		For Each TableRow In Object.PaymentDetails Do
			TableRow.Contract = Undefined;
			TableRow.AdvanceFlag = False;
			TableRow.Document = Undefined;
			TableRow.Order = Undefined;
			TableRow.VATRate = Undefined;
			TableRow.VATAmount = Undefined;
		EndDo;
	EndIf;
	
EndProcedure

#EndRegion

#Region ProcedureActionsOfTheFormCommandPanels

// The procedure is called when you click "PrintReceipt" on the command panel.
//
&AtClient
Procedure PrintReceipt(Command)
	
	If Object.SalesSlipNumber <> 0 Then
		MessageText = NStr("en = 'Cannot print the sales slip because it has already been printed on the fiscal register.'");
		CommonUseClientServer.MessageToUser(MessageText);
		
		Return;
	EndIf;
	
	ShowMessageBox = False;
	If DriveClient.CheckPossibilityOfReceiptPrinting(ThisForm, ShowMessageBox) Then
		
		If EquipmentManagerClient.RefreshClientWorkplace() Then
			
			NotifyDescription = New NotifyDescription("EnableFiscalRegistrarEnd", ThisObject);
			EquipmentManagerClient.OfferSelectDevice(NotifyDescription, "FiscalRegister",
					NStr("en = 'Select a fiscal register.'"), 
					NStr("en = 'The fiscal register is not connected.'"));
			                     
		Else
			
			MessageText = NStr("en = 'First, you need to select a cashier work place for the current session.'");
			CommonUseClientServer.MessageToUser(MessageText);
			
		EndIf;
		
	ElsIf ShowMessageBox Then
		ShowMessageBox(Undefined, NStr("en = 'Cannot post the cash receipt.'"));
	EndIf;
	
EndProcedure

&AtClient
Procedure EnableFiscalRegistrarEnd(DeviceIdentifier, Parameters) Export
	
	ErrorDescription = "";
	
	If DeviceIdentifier <> Undefined Then
		
		// Enable FR.
		Result = EquipmentManagerClient.ConnectEquipmentByID(
			UUID,
			DeviceIdentifier,
			ErrorDescription
		);
		
		If Result Then
			
			// Prepare data.
			InputParameters  = New Array();
			Output_Parameters = Undefined;
			SectionNumber = 2;
			
			// Preparation of the product table
			ProductsTable = New Array();
			
			ProductsTableRow = New ValueList();
			ProductsTableRow.Add(NStr("en = 'Payment from:'") + " " + Object.AcceptedFrom + Chars.LF
			+ NStr("en = 'Purpose:'") + " " + Object.Basis); //  1 - Description
			ProductsTableRow.Add("");					   //  2 - Barcode
			ProductsTableRow.Add("");					   //  3 - SKU
			ProductsTableRow.Add(SectionNumber);			   //  4 - Department number
			ProductsTableRow.Add(Object.DocumentAmount);  //  5 - Price for position without discount
			ProductsTableRow.Add(1);					   //  6 - Quantity
			ProductsTableRow.Add("");					   //  7 - Discount description
			ProductsTableRow.Add(0);					   //  8 - Discount amount
			ProductsTableRow.Add(0);					   //  9 - Discount percentage
			ProductsTableRow.Add(Object.DocumentAmount);  // 10 - Position amount with discount
			ProductsTableRow.Add(0);					   // 11 - Tax number (1)
			ProductsTableRow.Add(0);					   // 12 - Tax amount (1)
			ProductsTableRow.Add(0);					   // 13 - Tax percent (1)
			ProductsTableRow.Add(0);					   // 14 - Tax number (2)
			ProductsTableRow.Add(0);					   // 15 - Tax amount (2)
			ProductsTableRow.Add(0);					   // 16 - Tax percent (2)
			ProductsTableRow.Add("");					   // 17 - Section name of commodity string formatting
			
			ProductsTable.Add(ProductsTableRow);
			
			// Prepare the payments table.
			PaymentsTable = New Array();
			
			PaymentRow = New ValueList();
			PaymentRow.Add(0);
			PaymentRow.Add(Object.DocumentAmount);
			PaymentRow.Add("");
			PaymentRow.Add("");
			
			PaymentsTable.Add(PaymentRow);
			
			// Prepare the general parameters table.
			CommonParameters = New Array();
			CommonParameters.Add(0);						//  1 - Receipt type
			CommonParameters.Add(True);				//  2 - Fiscal receipt sign
			CommonParameters.Add(Undefined);			//  3 - Print on lining document
			CommonParameters.Add(Object.DocumentAmount); //  4 - the receipt amount without discounts
			CommonParameters.Add(Object.DocumentAmount); //  5 - the receipt amount after applying all discounts
			CommonParameters.Add("");					//  6 - Discount card number
			CommonParameters.Add("");					//  7 - Header text
			CommonParameters.Add("");					//  8 - Footer text
			CommonParameters.Add(0);						//  9 - Session number (for receipt copy)
			CommonParameters.Add(0);						// 10 - Receipt number (for receipt copy)
			CommonParameters.Add(0);						// 11 - Document No (for receipt copy)
			CommonParameters.Add(0);						// 12 - Document date (for receipt copy)
			CommonParameters.Add("");					// 13 - Cashier name (for receipt copy)
			CommonParameters.Add("");					// 14 - Cashier password
			CommonParameters.Add(0);						// 15 - Template number
			CommonParameters.Add("");					// 16 - Section name header format
			CommonParameters.Add("");					// 17 - Section name cellar format
			
			InputParameters.Add(ProductsTable);
			InputParameters.Add(PaymentsTable);
			InputParameters.Add(CommonParameters);
			
			// Print receipt.
			Result = EquipmentManagerClient.RunCommand(
				DeviceIdentifier,
				"PrintReceipt",
				InputParameters,
				Output_Parameters
			);
			
			If Result Then
				
				// Set the received value of receipt number to document attribute.
				Object.SalesSlipNumber = Output_Parameters[1];
				Modified = True;
				Write(New Structure("WriteMode", DocumentWriteMode.Posting));
				
			Else
				MessageText = NStr("en = 'Cannot print the sales slip on the fiscal register. Details: %AdditionalDetails%'");
				MessageText = StrReplace(MessageText,"%AdditionalDetails%",Output_Parameters[1]);
				CommonUseClientServer.MessageToUser(MessageText);
			EndIf;
			
			// Disable FR.
			EquipmentManagerClient.DisableEquipmentById(UUID, DeviceIdentifier);
			
		Else
			
			MessageText = NStr("en = 'Cannot print the sales slip on the fiscal register because the register is not connected. Details: %AdditionalDetails%'");
			MessageText = StrReplace(MessageText, "%AdditionalDetails%", ErrorDescription);
			CommonUseClientServer.MessageToUser(MessageText);
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Procedure - handler of the Execute event of the Pickup command
// Opens the form of debt forming documents selection.
//
&AtClient
Procedure Pick(Command)
	
	If Not ValueIsFilled(Object.Counterparty) Then
		ShowMessageBox(Undefined,NStr("en = 'Please select a counterparty.'"));
		Return;
	EndIf;
	
	If Not ValueIsFilled(Object.CashCurrency) Then
		ShowMessageBox(Undefined,NStr("en = 'Please select a currency.'"));
		Return;
	EndIf;
	
	AddressPaymentDetailsInStorage = PlacePaymentDetailsToStorage();
	
	SelectionParameters = New Structure(
		"AddressPaymentDetailsInStorage,
		|ParentCompany,
		|Date,
		|Counterparty,
		|Ref,
		|OperationKind,
		|CashCurrency,
		|DocumentAmount",
		AddressPaymentDetailsInStorage,
		ParentCompany,
		Object.Date,
		Object.Counterparty,
		Object.Ref,
		Object.OperationKind,
		Object.CashCurrency,
		Object.DocumentAmount
	);
	
	Result = Undefined;
	
	OpenForm("CommonForm.SelectInvoicesToBePaidByTheCustomer", SelectionParameters,,,,, New NotifyDescription("SelectionEnd", ThisObject, New Structure("AddressPaymentDetailsInStorage", AddressPaymentDetailsInStorage)));
	
EndProcedure

&AtClient
Procedure SelectionEnd(Result, AdditionalParameters) Export
	
	AddressPaymentDetailsInStorage = AdditionalParameters.AddressPaymentDetailsInStorage;
	
	If Result = DialogReturnCode.OK Then
		
		GetPaymentDetailsFromStorage(AddressPaymentDetailsInStorage);
		For Each RowPaymentDetails In Object.PaymentDetails Do
			If Not ValueIsFilled(RowPaymentDetails.VATRate) Then
				RowPaymentDetails.VATRate = DefaultVATRate;
			EndIf;
			CalculatePaymentSUM(RowPaymentDetails);
		EndDo;
		
		DefinePaymentDetailsExistsEPD();
		
		SetCurrentPage();
		
		If Object.PaymentDetails.Count() = 1 Then
			Object.DocumentAmount = Object.PaymentDetails.Total("PaymentAmount");
		EndIf;
		
	EndIf;

EndProcedure

// You can call the procedure by clicking
// the button "FillByBasis" of the tabular field command panel.
//
&AtClient
Procedure FillByBasis(Command)
	
	If Not ValueIsFilled(Object.BasisDocument) Then
		ShowMessageBox(Undefined, NStr("en = 'Please select a base document.'"));
		Return;
	EndIf;
	
	ShowQueryBox(New NotifyDescription("FillByBasisEnd", ThisObject), 
		NStr("en = 'Do you want to refill the cash receipt?'"), QuestionDialogMode.YesNo, 0);
	
EndProcedure

&AtClient
Procedure FillByBasisEnd(Result, AdditionalParameters) Export
	
	Response = Result;
	If Response = DialogReturnCode.Yes Then
		
		FillByDocument(Object.BasisDocument);
		
		If Object.PaymentDetails.Count() = 0 Then
			Object.PaymentDetails.Add();
			Object.PaymentDetails[0].PaymentAmount = Object.DocumentAmount;
		EndIf;
		
		OperationKind = Object.OperationKind;
		CashCurrency = Object.CashCurrency;
		DocumentDate = Object.Date;
		
		SetChoiceParameterLinksAvailableTypes();
		SetCurrentPage();
		
	EndIf;

EndProcedure

// Procedure - FillDetails command handler.
//
&AtClient
Procedure FillDetails(Command)
	
	If Object.DocumentAmount = 0 Then
		ShowMessageBox(Undefined,NStr("en = 'Please specify the amount.'"));
		Return;
	EndIf;
	
	If Not ValueIsFilled(Object.CashCurrency) Then
		ShowMessageBox(Undefined,NStr("en = 'Please select a currency.'"));
		Return;
	EndIf;
	
	ShowQueryBox(New NotifyDescription("FillDetailsEnd", ThisObject), 
		NStr("en = 'You are about to fill in the payment details. This will overwrite the current details. Do you want to continue?'"),
		QuestionDialogMode.YesNo
	);
	
EndProcedure

&AtClient
Procedure FillDetailsEnd(Result, AdditionalParameters) Export
	
	Response = Result;
	
	If Response = DialogReturnCode.No Then
		Return;
	EndIf;
	
	Object.PaymentDetails.Clear();
	
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesCashReceipt.FromCustomer") Then
		
		FillPaymentDetails();
		
	EndIf;
	
	SetCurrentPage();

EndProcedure

#EndRegion

#Region ProcedureEventHandlersOfHeaderAttributes

// Procedure - event handler OnChange of the Counterparty input field.
//
&AtClient
Procedure CounterpartyOnChange(Item)
	
	StructureData = GetDataCounterpartyOnChange(Object.Counterparty, Object.Company, Object.Date);
	
	If Not ValueIsFilled(Object.AcceptedFrom) Then
		Object.AcceptedFrom = StructureData.CounterpartyDescriptionFull;
	EndIf;
	
	If Object.PaymentDetails.Count() = 1 Then 
		
		Object.PaymentDetails[0].Contract = StructureData.Contract;
		
		If ValueIsFilled(Object.PaymentDetails[0].Contract) Then
			Object.PaymentDetails[0].ExchangeRate = ?(
				StructureData.ContractCurrencyRateRepetition.ExchangeRate = 0,
				1,
				StructureData.ContractCurrencyRateRepetition.ExchangeRate
			);
			Object.PaymentDetails[0].Multiplicity = ?(
				StructureData.ContractCurrencyRateRepetition.Multiplicity = 0,
				1,
				StructureData.ContractCurrencyRateRepetition.Multiplicity
			);
		EndIf;
		
		Object.PaymentDetails[0].ExchangeRate = ?(
			Object.PaymentDetails[0].ExchangeRate = 0,
			1,
			Object.PaymentDetails[0].ExchangeRate
		);
		Object.PaymentDetails[0].Multiplicity = ?(
			Object.PaymentDetails[0].Multiplicity = 0,
			1,
			Object.PaymentDetails[0].Multiplicity
		);
		
		Object.PaymentDetails[0].SettlementsAmount = DriveClient.RecalculateFromCurrencyToCurrency(
			Object.PaymentDetails[0].PaymentAmount,
			ExchangeRate,
			Object.PaymentDetails[0].ExchangeRate,
			Multiplicity,
			Object.PaymentDetails[0].Multiplicity
		);
		
	EndIf;
	
	If StructureData.Property("DefaultLoanContract") Then
		Object.LoanContract = StructureData.DefaultLoanContract;
		HandleChangeLoanContract();
	EndIf;
	
EndProcedure

// Procedure - event handler OperationKindOnChange.
// Manages pages while changing document operation kind.
//
&AtClient
Procedure OperationKindOnChange(Item)
	
	TypeOfOperationsBeforeChange = OperationKind;
	OperationKind = Object.OperationKind;
	
	If OperationKind <> TypeOfOperationsBeforeChange Then
		SetCurrentPage();
		ClearAttributesNotRelatedToOperation();
		SetChoiceParameterLinksAvailableTypes();
		OperationKindOnChangeAtServer();
		If Object.PaymentDetails.Count() = 1 Then
			Object.PaymentDetails[0].PaymentAmount = Object.DocumentAmount;
		EndIf;
	EndIf;
	
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
		StructureData = GetDataDateOnChange(DateBeforeChange);
		If StructureData.DATEDIFF <> 0 Then
			Object.Number = "";
		EndIf;
		
		QueryBoxText = NStr("en = 'The document date has changed. Do you want to use the exchange rate at that date?'");
		
		ShowQueryBox(New NotifyDescription("DateOnChangeQueryBoxHandler", ThisObject, StructureData), QueryBoxText, QuestionDialogMode.YesNo);
		
		DefinePaymentDetailsExistsEPD();
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
	StructureData = GetCompanyDataOnChange();
	ParentCompany = StructureData.ParentCompany;
	
EndProcedure

// Procedure - OnChange event handler of
// the Currency input field Recalculates the PaymentDetails tabular section.
//
&AtClient
Procedure CashAssetsCurrencyOnChange(Item)
	
	CurrencyCashBeforeChanging = CashCurrency;
	CashCurrency = Object.CashCurrency;
	
	// If currency is not changed, do nothing.
	If CashCurrency = CurrencyCashBeforeChanging Then
		Return;
	EndIf;
	
	StructureData = GetDataCashAssetsCurrencyOnChange(
		Object.Date,
		Object.CashCurrency);
	
	RecalculateAmountsOnCashAssetsCurrencyRateChange(StructureData);
	
EndProcedure

// Procedure - OnChange event handler of the AdvanceHolder input field.
// Clears the AdvanceHolders document.
//
&AtClient
Procedure AdvanceHolderOnChange(Item)
	
	If OperationKind = PredefinedValue("Enum.OperationTypesCashReceipt.LoanRepaymentByEmployee") 
		OR OperationKind = PredefinedValue("Enum.OperationTypesCashReceipt.LoanSettlements") Then
		
		DataStructure = GetEmployeeDataOnChange(Object.AdvanceHolder, Object.Date, Object.Company);
	
		If Not ValueIsFilled(Object.AcceptedFrom) Then
			Object.AcceptedFrom = DataStructure.AdvanceHolderDescription;
		EndIf;
		
		Object.LoanContract = DataStructure.LoanContract;
		
		HandleChangeLoanContract();
		
	ElsIf Not ValueIsFilled(Object.AcceptedFrom) Then
		StructureData = GetDataAdvanceHolderOnChange(Object.AdvanceHolder);
		Object.AcceptedFrom = StructureData.AdvanceHolderDescription;
	EndIf;
		
EndProcedure

// Procedure - OnChange event handler of the DocumentAmount input field.
//
&AtClient
Procedure DocumentAmountOnChange(Item)
	
	If Object.PaymentDetails.Count() = 1 Then
	
		TabularSectionRow = Object.PaymentDetails[0];
		
		TabularSectionRow.PaymentAmount = Object.DocumentAmount;
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
		
		TabularSectionRow.SettlementsAmount = DriveClient.RecalculateFromCurrencyToCurrency(
			TabularSectionRow.PaymentAmount,
			ExchangeRate,
			TabularSectionRow.ExchangeRate,
			Multiplicity,
			TabularSectionRow.Multiplicity
		);
		
		If Not ValueIsFilled(TabularSectionRow.VATRate) Then
			TabularSectionRow.VATRate = DefaultVATRate;
		EndIf;
		
		CalculateVATSUM(TabularSectionRow);
		
	EndIf;
	
	CalculateAccountingAmount();
	
EndProcedure

// Procedure - OnChange event handler of the CashCR input field.
//
&AtClient
Procedure CashCROnChange(Item)
	
	FillVATRateByCompanyVATTaxation();
	
EndProcedure

// Procedure - event handler OnChange of the StructuralUnit input field.
//
&AtClient
Procedure StructuralUnitOnChange(Item)
	
	FillVATRateByCompanyVATTaxation();
	
EndProcedure

// Procedure - OnChange event handler of the VATTaxation input field.
//
&AtClient
Procedure VATTaxationOnChange(Item)
	
	FillVATRateByVATTaxation();
	
EndProcedure

// Procedure - OnChange event handler of the PettyCash input field.
//
&AtClient
Procedure PettyCashOnChange(Item)
	
	CurrencyCashBeforeChanging = CashCurrency;
	
	StructureData = GetPettyCashAccountingCurrencyAtServer(Object.Date, Object.PettyCash);
	
	Object.CashCurrency = StructureData.CashCurrency;
	CashCurrency = StructureData.CashCurrency;
	
	// If currency is not changed, do nothing.
	If CashCurrency = CurrencyCashBeforeChanging Then
		Return;
	EndIf;
	
	RecalculateAmountsOnCashAssetsCurrencyRateChange(StructureData);
	
	
EndProcedure

&AtClient
Procedure TaxInvoiceTextClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	ParametersFilter = New Structure("AdvanceFlag", True);
	AdvanceArray = Object.PaymentDetails.FindRows(ParametersFilter);

	If AdvanceArray.Count() > 0 Then
		WorkWithVATClient.OpenTaxInvoice(ThisForm, False, True);
	Else
		CommonUseClientServer.MessageToUser(
			NStr("en = 'There are no rows with advance payments in the Payment details tab'"));
	EndIf;
	
EndProcedure

&AtClient
Procedure CreditNoteTextClick(Item, StandardProcessing)
	
	StandardProcessing	= False;
	IsError				= False;
	
	If NOT ValueIsFilled(Object.Ref) Then
		
		CommonUseClientServer.MessageToUser(NStr("en = 'Please, save the document.'"));
		
		IsError = True;
		
	ElsIf CheckBeforeCreditNoteFilling(Object.Ref) Then
		
		IsError = True;
		
	EndIf;
	
	If NOT IsError Then
		
		CreditNoteFound = GetSubordinateCreditNote(Object.Ref);
		
		ParametersStructure = New Structure;
		
		If ValueIsFilled(CreditNoteFound) Then
			ParametersStructure.Insert("Key", CreditNoteFound);
		Else
			ParametersStructure.Insert("Basis", Object.Ref);
		EndIf;
		
		OpenForm("Document.CreditNote.ObjectForm", ParametersStructure, ThisObject);
		
	EndIf;
	
EndProcedure

#Region TabularSectionAttributeEventHandlers

// Procedure - BeforeDeletion event handler of PaymentDetails tabular section.
//
&AtClient
Procedure PaymentDetailsBeforeDelete(Item, Cancel)
	
	If Object.PaymentDetails.Count() = 1 Then
		Cancel = True;
	EndIf;
	
EndProcedure

// The OnChange event handler of the PaymentDetailsContract field.
// It updates the contract currency exchange rate and exchange rate multiplier.
//
&AtClient
Procedure PaymentDetailsContractOnChange(Item)
	
	ProcessCounterpartyContractChange();
	
EndProcedure

// The OnChange event handler of the PaymentDetailsContract field.
// It updates the contract currency exchange rate and exchange rate multiplier.
//
&AtClient
Procedure PaymentDetailsContractStartChoice(Item, ChoiceData, StandardProcessing)
	
	ProcessStartChoiceCounterpartyContract(Item, StandardProcessing);
	
EndProcedure

// Procedure - OnChange event handler of the PaymentDetailsSettlementsKind input field.
// Clears an attribute document if a settlement type is - "Advance".
//
&AtClient
Procedure PaymentDetailsAdvanceFlagOnChange(Item)
	
	TabularSectionRow = Items.PaymentDetails.CurrentData;
	
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesCashReceipt.FromCustomer") Then
		
		If TabularSectionRow.AdvanceFlag Then
			TabularSectionRow.Document = Undefined;
		Else
			TabularSectionRow.PlanningDocument = Undefined;
		EndIf;
		
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesCashReceipt.FromVendor") Then
		If TypeOf(TabularSectionRow.Document) = Type("DocumentRef.CashVoucher")
			OR TypeOf(TabularSectionRow.Document) = Type("DocumentRef.PaymentExpense")
			OR TypeOf(TabularSectionRow.Document) = Type("DocumentRef.ExpenseReport") Then
			
			TabularSectionRow.AdvanceFlag = True;
			ShowMessageBox(Undefined, NStr("en = 'Cannot clear the ""Advance payment"" check box for this operation type.'"));
			
		ElsIf TypeOf(TabularSectionRow.Document) <> Type("DocumentRef.ArApAdjustments") Then
			TabularSectionRow.AdvanceFlag = False;
			
			ShowMessageBox(Undefined, NStr("en = 'Cannot select the ""Advance payment"" check box for this operation type.'"));
		EndIf;
	EndIf;
	
EndProcedure

// Procedure - SelectionStart event handler of the PaymentDetailsDocument input field.
// Passes the current attribute value to the parameters.
//
&AtClient
Procedure PaymentDetailsDocumentStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	TabularSectionRow = Items.PaymentDetails.CurrentData;
	
	If TabularSectionRow.AdvanceFlag
		AND Object.OperationKind = PredefinedValue("Enum.OperationTypesCashReceipt.FromCustomer") Then
		
		ShowMessageBox(, NStr("en = 'The current document will be the billing document for the advance payment.'"));
		
	Else
		
		ThisIsAccountsReceivable = OperationKind = PredefinedValue("Enum.OperationTypesCashReceipt.FromCustomer");
		
		StructureFilter = New Structure();
		StructureFilter.Insert("Company",		Object.Company);
		StructureFilter.Insert("Counterparty",	Object.Counterparty);
		
		If ValueIsFilled(TabularSectionRow.Contract) Then
			StructureFilter.Insert("Contract", TabularSectionRow.Contract);
		EndIf;
		
		ParameterStructure = New Structure("Filter, ThisIsAccountsReceivable, DocumentType",
			StructureFilter,
			ThisIsAccountsReceivable,
			TypeOf(Object.Ref)
		);
		
		OpenForm("CommonForm.SelectDocumentOfSettlements", ParameterStructure, Item);
		
	EndIf;
	
EndProcedure

// Procedure - SelectionDataProcessor event handler of the PaymentDetailsDocument input field.
//
&AtClient
Procedure PaymentDetailsDocumentChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	StandardProcessing = False;
	
	ProcessAccountsDocumentSelection(ValueSelected);
	
EndProcedure

// Procedure - OnChange event handler of the field in PaymentDetailsSettlementsAmount.
// Calculates the amount of the payment.
//
&AtClient
Procedure PaymentDetailsSettlementsAmountOnChange(Item)
	
	TabularSectionRow = Items.PaymentDetails.CurrentData;
	
	If Not TabularSectionRow.SettlementsAmount = 0 Then
		TabularSectionRow.ExchangeRate = TabularSectionRow.PaymentAmount * ExchangeRate / Multiplicity
												/ TabularSectionRow.SettlementsAmount * TabularSectionRow.Multiplicity;
	EndIf;
	
EndProcedure

// Procedure - OnChange event handler of the PaymentDetailsExchangeRate input field.
// Calculates the amount of the payment.
//
&AtClient
Procedure PaymentDetailsRateOnChange(Item)
	
	TabularSectionRow = Items.PaymentDetails.CurrentData;
	
	CalculateSettlmentsAmount(TabularSectionRow);
	CalculateSettlmentsEPDAmount(TabularSectionRow);
	
EndProcedure

// Procedure - OnChange event handler of the PaymentDetailsUnitConversionFactor input field.
// Calculates the amount of the payment.
//
&AtClient
Procedure PaymentDetailsRepetitionOnChange(Item)
	
	TabularSectionRow = Items.PaymentDetails.CurrentData;
	
	CalculateSettlmentsAmount(TabularSectionRow);
	CalculateSettlmentsEPDAmount(TabularSectionRow);
	
EndProcedure

// The OnChange event handler of the PaymentDetailsPaymentAmount field.
// It updates the payment currency exchange rate and exchange rate multiplier, and also the VAT amount.
//
&AtClient
Procedure PaymentDetailsPaymentAmountOnChange(Item)
	
	TabularSectionRow = Items.PaymentDetails.CurrentData;
	
	CalculateSettlmentsAmount(TabularSectionRow);
	
	If Not ValueIsFilled(TabularSectionRow.VATRate) Then
		TabularSectionRow.VATRate = DefaultVATRate;
	EndIf;
	
	CalculateVATSUM(TabularSectionRow);
	
EndProcedure

&AtClient
Procedure PaymentDetailsEPDAmountOnChange(Item)
	
	CalculateSettlmentsEPDAmount(Items.PaymentDetails.CurrentData);
	
EndProcedure

// Procedure - OnChange event handler of the PaymentDetailsVATRate input field.
// Calculates VAT amount.
//
&AtClient
Procedure PaymentDetailsVATRateOnChange(Item)
	
	TabularSectionRow = Items.PaymentDetails.CurrentData;
	CalculateVATSUM(TabularSectionRow);
	
EndProcedure

// Procedure - OnChange event handler of the PaymentDetailsDocument input field.
//
&AtClient
Procedure PaymentDetailsDocumentOnChange(Item)
	
	RunActionsOnAccountsDocumentChange();
	
EndProcedure

// Procedure - OnChange event handler of the RetailIncomePaymentDetailsVATRate input field.
//
&AtClient
Procedure RetailIncomePaymentDetailsVATRateOnChange(Item)
	
	TabularSectionRow = Items.RetailIncomePaymentDetails.CurrentData;
	CalculateVATSUM(TabularSectionRow);
	
EndProcedure

// Procedure - OnChange event handler of the CurrencyPurchaseRate input field.
//
&AtClient
Procedure CurrencyPurchaseRateOnChange(Item)
	
	CalculateAccountingAmount();
	
EndProcedure

// Procedure - OnChange event handler of the CurrencyPurchaseRepetition input field.
//
&AtClient
Procedure CurrencyPurchaseRepetitionOnChange(Item)
	
	CalculateAccountingAmount();
	
EndProcedure

// Procedure - OnChange event handler of the CurrencyPurchaseAccountingAmount input field.
//
&AtClient
Procedure CurrencyPurchaseAccountingAmountOnChange(Item)
	
	Object.ExchangeRate = ?(
		Object.ExchangeRate = 0,
		1,
		Object.ExchangeRate
	);
	
	Object.Multiplicity = ?(
		Object.Multiplicity = 0,
		1,
		Object.Multiplicity
	);
	
	Object.ExchangeRate = ?(
		Object.DocumentAmount = 0,
		1,
		Object.AccountingAmount / Object.DocumentAmount * AccountingCurrencyRate
	);
	
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

#EndRegion

#Region InteractiveActionResultHandlers

// Procedure-handler of a result of the question on document amount recalculation. 
//
//
&AtClient
Procedure DetermineNeedForDocumentAmountRecalculation(AdditionalParameters) Export
	
	If Object.PaymentDetails.Count() > 0 Then
		
		RecalculateDocumentAmounts(ExchangeRate, Multiplicity, False);
		
	EndIf;
	
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesCashReceipt.CurrencyPurchase") Then
		CalculateAccountingAmount();
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
	
	PropertiesManagement.UpdateAdditionalAttributesItems(ThisForm);
	
EndProcedure

// End StandardSubsystems.Properties

#EndRegion

#Region LoanContract 

&AtServer
Procedure FillInformationAboutCreditLoanAtServer()
	
	ConfigureLoanContractItem();
	
	If Object.LoanContract.IsEmpty() Then
		Items.LabelCreditContractInformation.Title		= NStr("en = '<Select loan contract>'");
		Items.LabelRemainingDebtByCredit.Title			= "";
		
		Items.LabelCreditContractInformation.TextColor	= StyleColors.BorderColor;
		Items.LabelRemainingDebtByCredit.TextColor		= StyleColors.BorderColor;
		
		Return;
	EndIf;
	
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesCashReceipt.LoanRepaymentByEmployee") Then
		FillInformationAboutLoanAtServer();
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesCashReceipt.LoanSettlements") Then
		FillInformationAboutCreditAtServer();
	EndIf;
	
EndProcedure

&AtServer
Procedure ConfigureLoanContractItem()
	
	Items.EmployeeLoanAgreement.Enabled = NOT Object.AdvanceHolder.IsEmpty();
	If Items.EmployeeLoanAgreement.Enabled Then
		Items.EmployeeLoanAgreement.InputHint = "";
	Else
		Items.EmployeeLoanAgreement.InputHint = NStr("en = 'To select a contract, select an employee first.'");
	EndIf;
	
	Items.CreditContract.Enabled = NOT Object.Counterparty.IsEmpty();
	If Items.CreditContract.Enabled Then
		Items.CreditContract.InputHint = "";
	Else
		Items.CreditContract.InputHint = NStr("en = 'To select a contract, select a bank first.'");
	EndIf;
	
EndProcedure

&AtServer
Procedure FillInformationAboutLoanAtServer();
	    
	Query = New Query;
	Query.Text = 
	"SELECT
	|	LoanRepaymentScheduleSliceLast.Period,
	|	LoanRepaymentScheduleSliceLast.Principal,
	|	LoanRepaymentScheduleSliceLast.Interest,
	|	LoanRepaymentScheduleSliceLast.Commission,
	|	LoanRepaymentScheduleSliceLast.LoanContract.SettlementsCurrency.Description AS CurrencyPresentation
	|FROM
	|	InformationRegister.LoanRepaymentSchedule.SliceLast(&SliceLastDate, LoanContract = &LoanContract) AS LoanRepaymentScheduleSliceLast
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SUM(LoanSettlementsBalance.PrincipalDebtCurBalance) AS PrincipalDebtCurBalance,
	|	LoanSettlementsBalance.LoanContract.SettlementsCurrency,
	|	SUM(LoanSettlementsBalance.InterestCurBalance) AS InterestCurBalance,
	|	SUM(LoanSettlementsBalance.CommissionCurBalance) AS CommissionCurBalance,
	|	LoanSettlementsBalance.LoanContract.SettlementsCurrency.Description AS CurrencyPresentation
	|FROM
	|	AccumulationRegister.LoanSettlements.Balance(, LoanContract = &LoanContract) AS LoanSettlementsBalance
	|
	|GROUP BY
	|	LoanSettlementsBalance.LoanContract.SettlementsCurrency,
	|	LoanSettlementsBalance.LoanContract.SettlementsCurrency.Description
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	LoanRepaymentScheduleSliceFirst.Period,
	|	LoanRepaymentScheduleSliceFirst.Principal,
	|	LoanRepaymentScheduleSliceFirst.Interest,
	|	LoanRepaymentScheduleSliceFirst.Commission,
	|	LoanRepaymentScheduleSliceFirst.LoanContract.SettlementsCurrency.Description AS CurrencyPresentation
	|FROM
	|	InformationRegister.LoanRepaymentSchedule.SliceFirst(&SliceLastDate, LoanContract = &LoanContract) AS LoanRepaymentScheduleSliceFirst";
	
	Query.SetParameter("SliceLastDate",			?(Object.Date = '00010101', BegOfDay(CurrentDate()), BegOfDay(Object.Date)));
	Query.SetParameter("LoanContract",	Object.LoanContract);
	
	ResultArray = Query.ExecuteBatch();
	
	If Object.LoanContract.LoanKind = Enums.LoanContractTypes.EmployeeLoanAgreement Then
		Multiplier = 1;
	Else
		Multiplier = -1;
	EndIf;
	
	InformationAboutLoan = "";
	
	SelectionSchedule = ResultArray[0].SElECT();
	SelectionScheduleFutureMonth = ResultArray[2].SElECT();
	
	LabelCreditContractInformationTextColor = StyleColors.BorderColor;
	LabelRemainingDebtByCreditTextColor = StyleColors.BorderColor;
	
	If SelectionScheduleFutureMonth.Next() Then
		
		If BegOfMonth(?(Object.Date = '00010101', CurrentDate(), Object.Date)) = BegOfMonth(SelectionScheduleFutureMonth.Period) Then
			PaymentDate = Format(SelectionScheduleFutureMonth.Period, "DLF=D");
		Else
			PaymentDate = Format(SelectionScheduleFutureMonth.Period, "DLF=D") + " " +
				NStr("en = '(not in the current month)'");
			LabelCreditContractInformationTextColor = StyleColors.FormTextColor;
		EndIf;
			
		LabelCreditContractInformation = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Payment date: %1.'") + " " +
			NStr("en = 'Debt amount: %2.'")	 + " " +
			NStr("en = 'Interest: %3.'")	 + " " +
			NStr("en = 'Commission: %4 (%5).'"),
			PaymentDate,			
			Format(SelectionScheduleFutureMonth.Principal, 	"NFD=2; NZ=0"),
			Format(SelectionScheduleFutureMonth.Interest, 	"NFD=2; NZ=0"),
			Format(SelectionScheduleFutureMonth.Commission, "NFD=2; NZ=0"),
			SelectionScheduleFutureMonth.CurrencyPresentation);
		
	ElsIf SelectionSchedule.Next() Then
		
		If BegOfMonth(?(Object.Date = '00010101', CurrentDate(), Object.Date)) = BegOfMonth(SelectionSchedule.Period) Then
			PaymentDate = Format(SelectionSchedule.Period, "DLF=D");
		Else
			PaymentDate = Format(SelectionSchedule.Period, "DLF=D") + " " + 
				NStr("en = '(not in the current month)'");
			LabelCreditContractInformationTextColor = StyleColors.FormTextColor;
		EndIf;
			
		LabelCreditContractInformation = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Payment date: %1.'") + " " +
			NStr("en = 'Debt amount: %2.'")	 + " " +
			NStr("en = 'Interest: %3.'")	 + " " +
			NStr("en = 'Commission: %4 (%5).'"),
			PaymentDate, 
			Format(SelectionSchedule.Principal, 	"NFD=2; NZ=0"),
			Format(SelectionSchedule.Interest, 		"NFD=2; NZ=0"),
			Format(SelectionSchedule.Commission, 	"NFD=2; NZ=0"), 
			SelectionSchedule.CurrencyPresentation);
		
	Else
		
		LabelCreditContractInformation = NStr("en = 'Payment date: <not specified>'");
		
	EndIf;
	
	
	SelectionBalance = ResultArray[1].SElECT();
	If SelectionBalance.Next() Then
		
		LabelRemainingDebtByCredit = StringFunctionsClientServer.SubstituteParametersInString(
		    NStr("en = 'Debt balance: %1.'") 	+ " " +
			NStr("en = 'Interest: %2.'") 		+ " " +
			NStr("en = 'Commission: %3 (%4).'"),		
			Format(Multiplier * SelectionBalance.PrincipalDebtCurBalance, 	"NFD=2; NZ=0"),
			Format(Multiplier * SelectionBalance.InterestCurBalance, 		"NFD=2; NZ=0"),
			Format(Multiplier * SelectionBalance.CommissionCurBalance, 		"NFD=2; NZ=0"),
			SelectionBalance.CurrencyPresentation);
			
		If Multiplier * SelectionBalance.PrincipalDebtCurBalance >= 0 
			AND (Multiplier * SelectionBalance.InterestCurBalance < 0 
			OR Multiplier * SelectionBalance.CommissionCurBalance < 0) Then
				LabelRemainingDebtByCreditTextColor = StyleColors.FormTextColor;
		EndIf;
		
		If Multiplier * SelectionBalance.PrincipalDebtCurBalance < 0 Then
			LabelRemainingDebtByCreditTextColor = StyleColors.SpecialTextColor;
		EndIf;
	Else
		
		LabelRemainingDebtByCredit = NStr("en = 'Debt balance: <not specified>'");
		
	EndIf;
	
	Items.LabelCreditContractInformation.Title	= LabelCreditContractInformation;
	Items.LabelRemainingDebtByCredit.Title		= LabelRemainingDebtByCredit;
	
	Items.LabelCreditContractInformation.TextColor	= LabelCreditContractInformationTextColor;
	Items.LabelRemainingDebtByCredit.TextColor		= LabelRemainingDebtByCreditTextColor;
		
EndProcedure

&AtServer
Procedure FillInformationAboutCreditAtServer()

	LabelCreditContractInformationTextColor	= StyleColors.BorderColor;
	LabelRemainingDebtByCreditTextColor		= StyleColors.BorderColor;
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	LoanSettlementsTurnovers.LoanContract.SettlementsCurrency AS Currency,
	|	LoanSettlementsTurnovers.PrincipalDebtCurExpense
	|INTO TemporaryTableAmountsIssuedBefore
	|FROM
	|	AccumulationRegister.LoanSettlements.Turnovers(
	|			,
	|			,
	|			,
	|			LoanContract = &LoanContract
	|				AND Company = &Company) AS LoanSettlementsTurnovers
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TemporaryTableAmountsIssuedBefore.Currency,
	|	SUM(TemporaryTableAmountsIssuedBefore.PrincipalDebtCurExpense) AS PrincipalDebtCurExpense,
	|	LoanContract.Total
	|FROM
	|	TemporaryTableAmountsIssuedBefore AS TemporaryTableAmountsIssuedBefore
	|		INNER JOIN Document.LoanContract AS LoanContract
	|		ON TemporaryTableAmountsIssuedBefore.Currency = LoanContract.SettlementsCurrency
	|WHERE
	|	LoanContract.Ref = &LoanContract
	|
	|GROUP BY
	|	TemporaryTableAmountsIssuedBefore.Currency,
	|	LoanContract.Total";
	
	Query.SetParameter("LoanContract",	Object.LoanContract);
	Query.SetParameter("Company",				Object.Company);
	Query.SetParameter("Employee",				Object.AdvanceHolder);
	
	QueryResult = Query.Execute();
	
	Selection = QueryResult.Select();
	
	If Selection.Next() Then
		Object.CashCurrency = Selection.Currency;
		
		LabelCreditContractInformation = NStr("en = 'Loan amount:'") + " " +
			Selection.Total + " (" +
			Selection.Currency + ")";
		
		If Selection.Total < Selection.PrincipalDebtCurExpense Then
			LabelRemainingDebtByCredit = NStr("en = 'Remaining loan amount:'") + " " +
				(Selection.Total - Selection.PrincipalDebtCurExpense) +
				" (" + Selection.Currency + ")" +
				NStr("en = '. Received loan amount:'") + " " +
				Selection.PrincipalDebtCurExpense + 
				" (" + Selection.Currency + ").";
				
			LabelRemainingDebtByCreditTextColor = StyleColors.SpecialTextColor;
		ElsIf Selection.Total = Selection.PrincipalDebtCurExpense Then
			LabelRemainingDebtByCredit = NStr("en = 'Remaining loan amount:'") + " 0 (" +
				Selection.Currency + ")";
				
			LabelRemainingDebtByCreditTextColor = StyleColors.SpecialTextColor;
		Else
			LabelRemainingDebtByCredit = NStr("en = 'Remaining loan amount:'") + " " +
				(Selection.Total - Selection.PrincipalDebtCurExpense) + 
				" (" + Selection.Currency + ")" +
				NStr("en = '. Received loan amount:'") + " " +
				Selection.PrincipalDebtCurExpense + 
				" (" + Selection.Currency + ").";
		EndIf;
	Else
		LabelCreditContractInformation = NStr("en = 'Loan amount:'") + " " +
			Object.LoanContract.Total + " (" + 
			Object.LoanContract.SettlementsCurrency + ")";
		
		LabelRemainingDebtByCredit = NStr("en = 'Balance to receive:'") + " " +
			Object.LoanContract.Total +  
			" (" + Object.LoanContract.SettlementsCurrency + ")";
	EndIf;
	
	Items.LabelCreditContractInformation.Title		= LabelCreditContractInformation;
	Items.LabelRemainingDebtByCredit.Title			= LabelRemainingDebtByCredit;
	
	Items.LabelCreditContractInformation.TextColor	= LabelCreditContractInformationTextColor;
	Items.LabelRemainingDebtByCredit.TextColor		= LabelRemainingDebtByCreditTextColor;
	
EndProcedure

&AtClient
Procedure HandleChangeLoanContract()
	
	EmployeeLoanAgreementData	= EmployeeLoanContractOnChange(Object.LoanContract, Object.Date);
	Object.CashCurrency			= EmployeeLoanAgreementData.Currency;
	
	FillInformationAboutCreditLoanAtServer();
	
	CashCurrencyBeforeChange	= CashCurrency;
	CashCurrency				= Object.CashCurrency;
	
	If CashCurrency = CashCurrencyBeforeChange Then
		Return;
	EndIf;
	                  
	DataStructure = GetDataCashAssetsCurrencyOnChange(
		Object.Date,
		Object.CashCurrency
	);
	
	RecalculateAmountsOnCashAssetsCurrencyRateChange(DataStructure);
	
EndProcedure

&AtServerNoContext
Function GetDefaultLoanContract(Document, Counterparty, Company, OperationKind)
	
	DocumentManager = Documents.LoanContract;
	
	ContractKindList = New ValueList;
	ContractKindList.Add(?(OperationKind = Enums.OperationTypesCashReceipt.LoanSettlements, 
		Enums.LoanContractTypes.Borrowed,
		Enums.LoanContractTypes.EmployeeLoanAgreement));
	                                                   
	DefaultLoanContract = DocumentManager.ReceiveLoanContractByDefaultByCompanyLoanKind(Counterparty, Company, ContractKindList);
	
	Return DefaultLoanContract;
	
EndFunction

&AtServerNoContext
Function EmployeeLoanContractOnChange(EmployeeLoanContract, Date)
	
	DataStructure = New Structure;
	
	DataStructure.Insert("Currency", 			EmployeeLoanContract.SettlementsCurrency);
	DataStructure.Insert("Counterparty",		EmployeeLoanContract.Counterparty);
	DataStructure.Insert("Employee",			EmployeeLoanContract.Employee);
	DataStructure.Insert("ThisIsLoanContract",	EmployeeLoanContract.LoanKind = Enums.LoanContractTypes.EmployeeLoanAgreement);
	
	Return DataStructure;
	 	
EndFunction

&AtClient
Procedure EmployeeLoanAgreementOnChange(Item)
	HandleChangeLoanContract();
EndProcedure

&AtServerNoContext
Function GetEmployeeDataOnChange(Employee, Date, Company)
	
	DataStructure = GetDataAdvanceHolderOnChange(Employee);
	
	DataStructure.Insert("LoanContract", Documents.LoanContract.ReceiveLoanContractByDefaultByCompanyLoanKind(Employee, Company));
	
	Return DataStructure;
	
EndFunction

&AtClient
Procedure SettlementsOnCreditsPaymentDetailsSettlementsAmountOnChange(Item)
	
	CalculatePaymentAmountAtClient(Items.SettlementsOnCreditsPaymentDetails.CurrentData);
	If Object.PaymentDetails.Count() = 1 Then
		Object.DocumentAmount = Object.PaymentDetails[0].PaymentAmount;
	EndIf;
	
EndProcedure

&AtClient
Procedure SettlementsOnCreditsPaymentDetailsExchangeRateOnChange(Item)
	
	CalculatePaymentAmountAtClient(Items.SettlementsOnCreditsPaymentDetails.CurrentData);
	If Object.PaymentDetails.Count() = 1 Then
		Object.DocumentAmount = Object.PaymentDetails[0].PaymentAmount;
	EndIf;
	
EndProcedure

&AtClient
Procedure SettlementsOnCreditsPaymentDetailsMultiplicityOnChange(Item)
		
	CalculatePaymentAmountAtClient(Items.SettlementsOnCreditsPaymentDetails.CurrentData);
	If Object.PaymentDetails.Count() = 1 Then
		Object.DocumentAmount = Object.PaymentDetails[0].PaymentAmount;
	EndIf;
	
EndProcedure

&AtClient
Procedure SettlementsOnCreditsPaymentDetailsVATRateOnChange(Item)
		
	TabularSectionRow = Items.SettlementsOnCreditsPaymentDetails.CurrentData;
	CalculateVATAmountAtClient(TabularSectionRow);
	
EndProcedure

&AtClient
Procedure SettlementsOnCreditsPaymentDetailsPaymentAmountOnChange(Item)
	
	TabularSectionRow = Items.SettlementsOnCreditsPaymentDetails.CurrentData;
	
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
		TabularSectionRow.PaymentAmount / TabularSectionRow.SettlementsAmount * ExchangeRate
	);
	
	If NOT ValueIsFilled(TabularSectionRow.VATRate) Then
		TabularSectionRow.VATRate = DefaultVATRate;
	EndIf;
	
	CalculateVATAmountAtClient(TabularSectionRow);
	
EndProcedure

&AtClient
Procedure SettlementsOnCreditsPaymentDetailsBeforeDeleteRow(Item, Cancel)
	
	If Object.PaymentDetails.Count() = 1 Then
		Cancel = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure FillByLoanContract(Command)
	
	If Object.LoanContract.IsEmpty() Then
		ShowMessageBox(Undefined, NStr("en = 'Select a contract'"));
		Return;
	EndIf;
	
	PaymentExplanationAddressInStorage = PlacePaymentDetailsToStorage();
	
	FilterParameters = New Structure("
		|PaymentExplanationAddressInStorage,
		|Company,
		|Recorder,
		|DocumentFormID,
		|OperationKind,
		|Date,
		|Currency,
		|LoanContract,
		|DocumentAmount,
		|Counterparty,
		|DefaultVATRate,
		|PaymentAmount,
		|Rate,
		|Multiplicity,
		|Employee",
		PaymentExplanationAddressInStorage,
		Object.Company,
		Object.Ref,
		UUID,
		Object.OperationKind,
		Object.Date,
		Object.CashCurrency,
		Object.LoanContract,
		Object.DocumentAmount,
		Object.Counterparty,
		DefaultVATRate,
		Object.PaymentDetails.Total("PaymentAmount"),
		ExchangeRate,
		Multiplicity,
		Object.AdvanceHolder);
		
	OpenForm("CommonForm.LoanRepaymentDetails", 
		FilterParameters,
		ThisObject,,,,
		New NotifyDescription("FillByCreditContractEnd", ThisObject));
						
EndProcedure

&AtClient
Procedure FillByCreditContractEnd(FillingResult, CompletionParameters) Export
	
	FillDocumentAmount = False;
	If TypeOf(FillingResult) = Type("Structure") Then
		
		FillDocumentAmount = False;
		
		If FillingResult.Property("ClearTabularSectionOnPopulation") AND FillingResult.ClearTabularSectionOnPopulation Then
			Object.PaymentDetails.Clear();
			FillDocumentAmount = True;
		EndIf;
		
		If FillingResult.Property("PaymentExplanationAddressInStorage") Then
			GetPaymentDetailsFromStorage(FillingResult.PaymentExplanationAddressInStorage);
			
			If Object.PaymentDetails.Count() = 1 Then
				Object.DocumentAmount = Object.PaymentDetails[0].PaymentAmount;
			EndIf;
		EndIf;
		
		If FillDocumentAmount Then
			Object.DocumentAmount = Object.PaymentDetails.Total("PaymentAmount");
			DocumentAmountOnChange(Items.DocumentAmount);
		EndIf;
		
		Modified = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure FillByCreditContract(Command)
	
	If Object.LoanContract.IsEmpty() Then
		ShowMessageBox(Undefined, NStr("en = 'Select a contract'"));
		Return;
	EndIf;
	
	FillByLoanContractAtServer();
	DocumentAmountOnChange(Items.DocumentAmount);
	
EndProcedure

&AtServer
Procedure FillByLoanContractAtServer()
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	LoanSettlementsTurnovers.LoanContract.SettlementsCurrency AS Currency,
	|	LoanSettlementsTurnovers.PrincipalDebtCurExpense
	|INTO TemporaryTableAmountsIssuedBefore
	|FROM
	|	AccumulationRegister.LoanSettlements.Turnovers(
	|			,
	|			,
	|			,
	|			LoanContract = &LoanContract
	|				AND Company = &Company) AS LoanSettlementsTurnovers
	|
	|UNION ALL
	|
	|SELECT
	|	LoanSettlements.LoanContract.SettlementsCurrency,
	|	CASE
	|		WHEN LoanSettlements.RecordType = VALUE(AccumulationRecordType.Expense)
	|			THEN -LoanSettlements.PrincipalDebtCur
	|		ELSE LoanSettlements.PrincipalDebtCur
	|	END
	|FROM
	|	AccumulationRegister.LoanSettlements AS LoanSettlements
	|WHERE
	|	LoanSettlements.Recorder = &Ref
	|	AND LoanSettlements.LoanContract = &LoanContract
	|	AND LoanSettlements.Company = &Company
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TemporaryTableAmountsIssuedBefore.Currency,
	|	SUM(TemporaryTableAmountsIssuedBefore.PrincipalDebtCurExpense) AS PrincipalDebtCurExpense,
	|	LoanContract.Total
	|FROM
	|	TemporaryTableAmountsIssuedBefore AS TemporaryTableAmountsIssuedBefore
	|		INNER JOIN Document.LoanContract AS LoanContract
	|		ON TemporaryTableAmountsIssuedBefore.Currency = LoanContract.SettlementsCurrency
	|WHERE
	|	LoanContract.Ref = &LoanContract
	|
	|GROUP BY
	|	TemporaryTableAmountsIssuedBefore.Currency,
	|	LoanContract.Total";
	
	Query.SetParameter("LoanContract",	Object.LoanContract);
	Query.SetParameter("Company",		Object.Company);
	Query.SetParameter("Ref",			Object.Ref);
	
	QueryResult = Query.Execute();
	
	Selection = QueryResult.Select();
	
	If Selection.Next() Then
		
		Object.CashCurrency = Selection.Currency;
		
		MessageText = "";
		
		If Selection.Total < Selection.PrincipalDebtCurExpense Then
			MessageText = NStr("en = 'Issued under the loan contract:'") + " " +
				Selection.PrincipalDebtCurExpense +
				" (" + Selection.Currency + ").";
		ElsIf Selection.Total = Selection.PrincipalDebtCurExpense Then
			MessageText = NStr("en = 'The complete amount has been alredy issued under the loan contract:'") + " " +
				Selection.PrincipalDebtCurExpense +
				" (" + Selection.Currency + ").";
		Else
			Object.DocumentAmount = Selection.Total - Selection.PrincipalDebtCurExpense;
			Object.CashCurrency = Selection.Currency;
		EndIf;
		
		If MessageText <> "" Then
			CommonUseClientServer.MessageToUser(MessageText,, "EmployeeLoanAgreement");
		EndIf;
	Else
		Object.DocumentAmount	= Object.LoanContract.Total;
		Object.CashCurrency		= Object.LoanContract.SettlementsCurrency;
	EndIf;
	
	Modified = True;
	
EndProcedure

#EndRegion

#EndRegion
