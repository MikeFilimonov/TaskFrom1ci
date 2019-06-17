
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
	
	If Object.PaymentDetails.Count() = 0
	   AND Object.OperationKind <> Enums.OperationTypesCashVoucher.Salary Then
		Object.PaymentDetails.Add();
		Object.PaymentDetails[0].PaymentAmount = Object.DocumentAmount;
	EndIf;
	
	// FO Use Payroll subsystem.
	SetVisibleByFOUseSubsystemPayroll();
	
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
	
	StructuralUnitDepartment = Catalogs.BusinessUnits.MainDepartment;
	
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
		
		If Object.OperationKind = Enums.OperationTypesCashVoucher.ToCustomer
		   AND GetFunctionalOption("UsePeripherals") Then
			PrintReceiptEnabled = True;
		EndIf;
		
		Button.Enabled = PrintReceiptEnabled;
		Items.Decoration4.Visible = PrintReceiptEnabled;
		Items.SalesSlipNumber.Visible = PrintReceiptEnabled;
		
	EndIf;
	
	AccountingPolicy = InformationRegisters.AccountingPolicy.GetAccountingPolicy();
	FunctionalOptionAccountingCashMethodIncomeAndExpenses = AccountingPolicy.CashMethodOfAccounting;
	
	SetVisibilityAttributesDependenceOnCorrespondence();
	SetVisibilityItemsDependenceOnOperationKind();
		
	If Object.OperationKind = Enums.OperationTypesCashVoucher.Taxes Then
		Items.BusinessLineTaxes.Visible = FunctionalOptionAccountingCashMethodIncomeAndExpenses;
	EndIf;
	
	If Object.OperationKind = Enums.OperationTypesCashVoucher.SalaryForEmployee Then
		Items.EmployeeSalaryPayoffBusinessLine.Visible = FunctionalOptionAccountingCashMethodIncomeAndExpenses;
	EndIf;
	
	If Object.OperationKind = Enums.OperationTypesCashVoucher.Salary Then
		Items.SalaryPayoffBusinessLine.Visible = FunctionalOptionAccountingCashMethodIncomeAndExpenses;
	EndIf;
	
	RegistrationPeriodPresentation = Format(Object.RegistrationPeriod, "DF='MMMM yyyy'");
	
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
	
	SetVisibilitySettlementAttributes();
	SetVisibilityEPDAttributes();
	
	CurrentSystemUser = UsersClientServer.CurrentUser();
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
	
	WorkWithVAT.SetTextAboutAdvancePaymentInvoiceReceived(ThisForm);
	
	SetTaxInvoiceText();
	
	EarlyPaymentDiscountsServer.SetTextAboutDebitNote(ThisObject, Object.Ref);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	SetChoiceParameterLinksAvailableTypes();
	SetCurrentPage();
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(ValueSelected, ChoiceSource)
	
	If TypeOf(ChoiceSource) = Type("ManagedForm")
		AND Find(ChoiceSource.FormName, "Calendar") > 0 Then
		
		Object.RegistrationPeriod = EndOfDay(ValueSelected);
		DriveClient.OnChangeRegistrationPeriod(ThisForm);
		
	EndIf;
	
	If ChoiceSource.FormName = "Document.TaxInvoiceReceived.Form.DocumentForm" Then
		
		TaxInvoiceText = ValueSelected;
		
	EndIf;
	
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
		
	ElsIf EventName = "RefreshDebitNoteText" Then
		
		If TypeOf(Parameter.Ref) = Type("DocumentRef.DebitNote")
			AND Parameter.BasisDocument = Object.Ref Then
			
			DebitNoteText = EarlyPaymentDiscountsClientServer.DebitNotePresentation(Parameter.Date, Parameter.Number);
			
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
	PerformanceEstimationClientServer.StartTimeMeasurement("DocumentCashVoucherPosting");
	// StandardSubsystems.PerformanceMeasurement
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	If WriteParameters.WriteMode = DocumentWriteMode.Posting Then
		
		MessageText = "";
		CheckContractToDocumentConditionAccordance(Object.PaymentDetails, MessageText, Object.Ref, Object.Company, Object.Counterparty, Object.OperationKind, Cancel, Object.LoanContract);
		
		If MessageText <> "" Then
			
			Message = New UserMessage;
			Message.Text = ?(Cancel, NStr("en = 'The cash payment is not posted.'") + " " + MessageText, MessageText);
			Message.Message();
			
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
	
	// Notification of payment.
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
	
	// CWP
	If TypeOf(FormOwner) = Type("ManagedForm")
		AND Find(FormOwner.FormName, "DocumentForm_CWP") > 0 
		Then
		Notify("CWP_Record_CPV", New Structure("Ref, Number, Date, OperationKind", Object.Ref, Object.Number, Object.Date, Object.OperationKind));
	EndIf;
	// End CWP
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	If CurrentObject.OperationKind = PredefinedValue("Enum.OperationTypesCashVoucher.IssueLoanToEmployee") 
		OR CurrentObject.OperationKind = PredefinedValue("Enum.OperationTypesCashVoucher.LoanSettlements") Then
			FillCreditLoanInformationAtServer();
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
Procedure CorrespondenceOnChange(Item)
	
	If Correspondence <> Object.Correspondence Then
		SetVisibilityAttributesDependenceOnCorrespondence();
		Correspondence = Object.Correspondence;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormItemEventHandlersTablePaymentDetails

&AtClient
Procedure PaymentDetailsOtherSettlementsBeforeDeleteRow(Item, Cancel)
	
	If Object.PaymentDetails.Count() = 1 Then
		Cancel = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure PaymentDetailsOtherSettlementsAfterDeleteRow(Item)
	
	If Object.PaymentDetails.Count() = 1 Then
		SetCurrentPage();
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
	ElsIf TablePartRow.PaymentAmount = 0 
		OR ColumnName = "ExchangeRate" 
		OR ColumnName = "Multiplicity" Then
		
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
			TablePartRow.SettlementsAmount = 0 OR TablePartRow.PaymentAmount = 0,
			StructureData.ContractCurrencyRateRepetition.ExchangeRate, //TablePartRow.ExchangeRate,
			TablePartRow.PaymentAmount / TablePartRow.SettlementsAmount * ExchangeRate
		);
		TablePartRow.Multiplicity = ?(
			TablePartRow.SettlementsAmount = 0 OR TablePartRow.PaymentAmount = 0,
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
	FormParameters.Insert("ControlContractChoice",	Counterparty.DoOperationsByContracts);
	FormParameters.Insert("Counterparty",			Counterparty);
	FormParameters.Insert("Company",				Company);
	FormParameters.Insert("ContractType",			ContractTypesList);
	FormParameters.Insert("CurrentRow",				Contract);
	
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
Procedure OperationKindOnChangeAtServer(FillTaxation = True)
	
	SetChoiceParameterLinksAvailableTypes();
	
	SetVisibilityPrintReceipt();
	
	If Object.OperationKind = Enums.OperationTypesCashVoucher.OtherSettlements Then
		DefaultVATRate						= Catalogs.VATRates.Exempt;
		DefaultVATRateNumber				= DriveReUse.GetVATRateValue(DefaultVATRate);
		Object.PaymentDetails[0].VATRate	= DefaultVATRate;

	ElsIf FillTaxation Then
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

&AtClient
Procedure QuestionAmountRecalculationOnChangeCashAssetsCurrencyExchangeRateEnd(Result, AdditionalParameters) Export

	If Result = DialogReturnCode.Yes Then
		
		ExchangeRateBeforeChange = AdditionalParameters.ExchangeRateBeforeChange;
		MultiplicityBeforeChange = AdditionalParameters.MultiplicityBeforeChange;
		
		If Object.PaymentDetails.Count() > 0 
		   AND Object.OperationKind <> PredefinedValue("Enum.OperationTypesCashVoucher.Salary") Then // only header is recalculated for the "Salary" operation kind.
			If Object.OperationKind = PredefinedValue("Enum.OperationTypesCashVoucher.ToCustomer")
			 OR Object.OperationKind = PredefinedValue("Enum.OperationTypesCashVoucher.Vendor") Then
				RecalculateDocumentAmounts(ExchangeRate, Multiplicity, True);
				// Other settlement
			ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesCashVoucher.OtherSettlements")
				OR Object.OperationKind = PredefinedValue("Enum.OperationTypesCashVoucher.LoanSettlements") Then
				RecalculateDocumentAmounts(ExchangeRate, Multiplicity, True);
			// End Other settlement
			Else
				DocumentAmountIsEqualToTotalPaymentAmount = Object.PaymentDetails.Total("PaymentAmount") = Object.DocumentAmount;
				
				For Each TabularSectionRow In Object.PaymentDetails Do // recalculate plan amount for the operations with planned payments.
					TabularSectionRow.PaymentAmount = DriveClient.RecalculateFromCurrencyToCurrency(
						TabularSectionRow.PaymentAmount,
						ExchangeRateBeforeChange,
						ExchangeRate,
						MultiplicityBeforeChange,
						Multiplicity
					);
					
					CalculateVATAmountAtClient(TabularSectionRow);
				EndDo;
					
				If DocumentAmountIsEqualToTotalPaymentAmount Then
					Object.DocumentAmount = Object.PaymentDetails.Total("PaymentAmount");
				Else
					Object.DocumentAmount = DriveClient.RecalculateFromCurrencyToCurrency(
						Object.DocumentAmount,
						ExchangeRateBeforeChange,
						ExchangeRate,
						MultiplicityBeforeChange,
						Multiplicity
					);
				EndIf;
				
			EndIf;
		Else
			Object.DocumentAmount = DriveClient.RecalculateFromCurrencyToCurrency(
				Object.DocumentAmount,
				ExchangeRateBeforeChange,
				ExchangeRate,
				MultiplicityBeforeChange,
				Multiplicity
			);
		EndIf;
	Else
		If Object.PaymentDetails.Count() > 0 Then
			RecalculateDocumentAmounts(ExchangeRate, Multiplicity, False);
		EndIf;
	EndIf;

EndProcedure

&AtServer
Procedure SetChoiceParametersForAccountingOtherSettlementsAtServerForAccountItem()

	Item = Items.SettlementsOtherCorrespondence;
	
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

	Item = Items.SettlementsOtherCorrespondence;
	
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
	
	If Object.Correspondence.TypeOfAccount = Enums.GLAccountsTypes.Expenses Then
		Items.BusinessLine.Visible	= True;
		Items.Department.Visible		= True;
		Items.Order.Visible				= True;
		If Not ValueIsFilled(Object.Department) Then
			SettingValue	= DriveReUse.GetValueByDefaultUser(CurrentSystemUser, "MainDepartment");
			Object.Department	= ?(ValueIsFilled(SettingValue), SettingValue, Catalogs.BusinessUnits.MainDepartment);
		EndIf;
	Else
		If Object.OperationKind <> Enums.OperationTypesCashVoucher.Taxes // for entering based on
		   AND Object.OperationKind <> Enums.OperationTypesCashVoucher.SalaryForEmployee Then
			Object.BusinessLine	= Undefined;
		EndIf;
		If Not FunctionalOptionAccountingCashMethodIncomeAndExpenses
			AND (Object.OperationKind = Enums.OperationTypesCashVoucher.Taxes
		   OR Object.OperationKind = Enums.OperationTypesCashVoucher.SalaryForEmployee) Then
			Object.BusinessLine	= Undefined;
		EndIf;
		If Object.OperationKind = Enums.OperationTypesCashVoucher.Other
			OR Object.OperationKind = Enums.OperationTypesCashVoucher.OtherSettlements Then
			Object.Department	= Undefined;
		EndIf;
		Object.Order	= Undefined;
		Items.BusinessLine.Visible	= False;
		Items.Department.Visible		= False;
		Items.Order.Visible				= False;
	EndIf;
	
	SetVisibilityPlanningDocument();
	
EndProcedure

&AtServer
Procedure SetVisibilityItemsDependenceOnOperationKind()
	
	Items.PaymentDetailsPaymentAmount.Visible					= GetFunctionalOption("ForeignExchangeAccounting");
	Items.OtherSettlementsPaymentAmount.Visible					= GetFunctionalOption("ForeignExchangeAccounting");
	Items.PaymentDetailsOtherSettlementsPaymentAmount.Visible	= GetFunctionalOption("ForeignExchangeAccounting");
	Items.SettlementsOnCreditsPaymentDetailsPaymentAmount.Visible = GetFunctionalOption("ForeignExchangeAccounting");
	
	Items.SettlementsWithCounterparty.Visible	= False;
	Items.SettlementsWithAdvanceHolder.Visible	= False;
	Items.SalaryPayToEmployee.Visible			= False;
	Items.Payroll.Visible						= False;
	Items.TaxesSettlements.Visible				= False;
	Items.OtherSettlements.Visible				= False;
	Items.TransferToCashCR.Visible				= False;
	
	Items.VATTaxation.Visible	= False;
	Items.DocumentAmount.Width	= 14;
	
	Items.AdvanceHolder.Visible	= False;
	Items.Counterparty.Visible	= False;
	
	Items.LoanSettlements.Visible			= False;
	Items.LoanSettlements.Title				= NStr("en = 'Loan account statement'");
	Items.EmployeeLoanAgreement.Visible		= False;
	Items.FillByLoanContract.Visible		= False;
	Items.CreditContract.Visible			= False;
	Items.FillByCreditContract.Visible		= False;
	Items.GroupContractInformation.Visible	= False;
	Items.AdvanceHolder.Visible				= False;
	
	If OperationKind = PredefinedValue("Enum.OperationTypesCashVoucher.Vendor") Then
		
		Items.SettlementsWithCounterparty.Visible	= True;
		Items.PaymentDetailsPickup.Visible			= True;
		Items.PaymentDetailsFillDetails.Visible		= True;
		
		Items.Counterparty.Visible	= True;
		Items.Counterparty.Title	= NStr("en = 'Supplier'");
		Items.VATTaxation.Visible	= True;
		
		Items.PaymentAmount.Visible		= True;
		Items.PaymentAmount.Title		= NStr("en = 'Payment amount'");
		Items.SettlementsAmount.Visible = Not GetFunctionalOption("ForeignExchangeAccounting");
		
		Items.VATAmount.Visible	= Object.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT;
		Items.PayrollPaymentTotalPaymentAmount.Visible	= False;
		
	ElsIf OperationKind = PredefinedValue("Enum.OperationTypesCashVoucher.ToCustomer") Then
		
		Items.SettlementsWithCounterparty.Visible	= True;
		Items.PaymentDetailsPickup.Visible			= False;
		Items.PaymentDetailsFillDetails.Visible		= False;
		
		Items.Counterparty.Visible	= True;
		Items.Counterparty.Title	= NStr("en = 'Customer'");
		Items.VATTaxation.Visible	= True;
		
		Items.PaymentAmount.Visible		= True;
		Items.PaymentAmount.Title		= NStr("en = 'Payment amount'");
		Items.SettlementsAmount.Visible = Not GetFunctionalOption("ForeignExchangeAccounting");
		
		Items.VATAmount.Visible	= Object.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT;
		Items.PayrollPaymentTotalPaymentAmount.Visible	= False;
		
	ElsIf OperationKind = PredefinedValue("Enum.OperationTypesCashVoucher.ToAdvanceHolder") Then
		
		Items.SettlementsWithAdvanceHolder.Visible	= True;
		Items.AdvanceHolder.Visible					= True;
		Items.AdvanceHolder.Title					= NStr("en = 'Advance holder'");
		Items.DocumentAmount.Width					= 13;
		
		Items.PaymentAmount.Visible			= GetFunctionalOption("PaymentCalendar");
		Items.PaymentAmount.Title			= ?(GetFunctionalOption("PaymentCalendar"), NStr("en = 'Amount (planned)'"), NStr("en = 'Payment amount'"));
		Items.PaymentAmountCurrency.Visible	= Items.PaymentAmount.Visible;
		Items.SettlementsAmount.Visible		= False;
		
		Items.VATAmount.Visible = False;
		
	ElsIf OperationKind = PredefinedValue("Enum.OperationTypesCashVoucher.SalaryForEmployee") Then
		
		Items.SalaryPayToEmployee.Visible	= True;
		Items.AdvanceHolder.Visible			= True;
		Items.AdvanceHolder.Title			= NStr("en = 'Employee'");
		
		Items.PaymentAmount.Visible			= GetFunctionalOption("PaymentCalendar");
		Items.PaymentAmount.Title			= ?(GetFunctionalOption("PaymentCalendar"), NStr("en = 'Amount (planned)'"), NStr("en = 'Payment amount'"));
		Items.PaymentAmountCurrency.Visible	= Items.PaymentAmount.Visible;
		Items.SettlementsAmount.Visible		= False;
		
		Items.VATAmount.Visible	= False;
		
	ElsIf OperationKind = PredefinedValue("Enum.OperationTypesCashVoucher.Salary") Then
		
		Items.Payroll.Visible	= True;
		
		Items.PaymentAmount.Visible						= False;
		Items.SettlementsAmount.Visible					= False;
		Items.VATAmount.Visible							= False;
		Items.PayrollPaymentTotalPaymentAmount.Visible	= True;
		
	ElsIf OperationKind = PredefinedValue("Enum.OperationTypesCashVoucher.Taxes") Then
		
		Items.TaxesSettlements.Visible	= True;
		
		Items.PaymentAmount.Visible			= GetFunctionalOption("PaymentCalendar");
		Items.PaymentAmount.Title			= ?(GetFunctionalOption("PaymentCalendar"), NStr("en = 'Amount (planned)'"), NStr("en = 'Payment amount'"));
		Items.PaymentAmountCurrency.Visible	= Items.PaymentAmount.Visible;
		Items.SettlementsAmount.Visible		= False;
		
		Items.VATAmount.Visible	= False;
		Items.PayrollPaymentTotalPaymentAmount.Visible	= False;
		
	ElsIf OperationKind = PredefinedValue("Enum.OperationTypesCashVoucher.TransferToCashCR") Then
		
		Items.TransferToCashCR.Visible = True;
		
		Items.PaymentAmount.Visible			= GetFunctionalOption("PaymentCalendar");
		Items.PaymentAmount.Title			= ?(GetFunctionalOption("PaymentCalendar"), NStr("en = 'Amount (planned)'"), NStr("en = 'Payment amount'"));
		Items.PaymentAmountCurrency.Visible	= Items.PaymentAmount.Visible;
		Items.SettlementsAmount.Visible		= False;
		Items.VATAmount.Visible				= False;
		Items.PayrollPaymentTotalPaymentAmount.Visible	= False;
		
	ElsIf OperationKind = PredefinedValue("Enum.OperationTypesCashVoucher.Other") Then
		
		Items.OtherSettlements.Visible	= True;
		
		Items.PaymentAmount.Visible			= GetFunctionalOption("PaymentCalendar");
		Items.PaymentAmount.Title			= ?(GetFunctionalOption("PaymentCalendar"), NStr("en = 'Amount (planned)'"), NStr("en = 'Payment amount'"));
		Items.PaymentAmountCurrency.Visible	= Items.PaymentAmount.Visible;
		Items.SettlementsAmount.Visible		= False;
		
		Items.VATAmount.Visible				= False;
		Items.PayrollPaymentTotalPaymentAmount.Visible	= False;
		
		Items.PageOtherSettlementsAsList.Visible	= False;
		Items.GroupAttributesFirstRow.Visible		= False;
		SetVisibilityAttributesDependenceOnCorrespondence();
		
	ElsIf OperationKind = PredefinedValue("Enum.OperationTypesCashVoucher.OtherSettlements") Then
		
		Items.OtherSettlements.Visible	= True;
		
		Items.PaymentAmount.Visible			= False;
		Items.PaymentAmount.Title			= NStr("en = 'Payment amount'");
		Items.PaymentAmountCurrency.Visible	= Items.PaymentAmount.Visible;
		Items.SettlementsAmount.Visible		= False;
		Items.VATAmount.Visible				= False;
		Items.PayrollPaymentTotalPaymentAmount.Visible	= False;
		
		Items.Counterparty.Visible	= True;
		Items.Counterparty.Title	= NStr("en = 'Counterparty'");
		Items.PageOtherSettlementsAsList.Visible	= True;
		Items.OtherSettlementsContract.Visible = Object.Counterparty.DoOperationsByContracts;
		Items.GroupAttributesFirstRow.Visible		= True;
		SetVisibilityAttributesDependenceOnCorrespondence();
		
		If Object.PaymentDetails.Count() > 0 Then
			ID = Object.PaymentDetails[0].GetID();
			Items.PaymentDetailsOtherSettlements.CurrentRow = ID;
		EndIf;
		
	ElsIf OperationKind = PredefinedValue("Enum.OperationTypesCashVoucher.IssueLoanToEmployee") Then
		
		Items.AdvanceHolder.Visible							= True;
		Items.LoanSettlements.Title							= NStr("en = 'Loan account statement'");
		Items.LoanSettlements.Visible						= True;
		Items.SettlementsOnCreditsPaymentDetails.Visible	= False;
		
		Items.EmployeeLoanAgreement.Visible = True;
		Items.FillByLoanContract.Visible	= True;
		
		FillCreditLoanInformationAtServer();
		
		Items.GroupContractInformation.Visible = True;
		
		Items.PaymentAmount.Visible						= GetFunctionalOption("PaymentCalendar");
		Items.PaymentAmount.Title						= NStr("en = 'Payment amount'");
		Items.PaymentAmountCurrency.Visible				= Items.PaymentAmount.Visible;
		Items.SettlementsAmount.Visible					= False;
		Items.VATAmount.Visible							= False;
		Items.PayrollPaymentTotalPaymentAmount.Visible	= False;
		
	ElsIf OperationKind = PredefinedValue("Enum.OperationTypesCashVoucher.LoanSettlements") Then
		
		Items.LoanSettlements.Visible = True;
		Items.Counterparty.Visible = True;
		Items.Counterparty.Title = NStr("en = 'Lender'");
		Items.VATTaxation.Visible = True;
		Items.SettlementsOnCreditsPaymentDetails.Visible = True;
				
		Items.CreditContract.Visible = True;
		Items.FillByCreditContract.Visible = True;
		
		FillCreditLoanInformationAtServer();
		
		Items.GroupContractInformation.Visible = True;
		
		Items.PaymentAmount.Visible = GetFunctionalOption("ForeignExchangeAccounting");
		Items.PaymentAmount.Title = NStr("en = 'Payment amount'");
		Items.SettlementsAmount.Visible = True;
		Items.VATAmount.Visible = False;
		Items.PayrollPaymentTotalPaymentAmount.Visible = False;	
	Else
		
		Items.OtherSettlements.Visible = True;
		
		Items.PaymentAmount.Visible = True;
		Items.PaymentAmount.Title = NStr("en = 'Amount (planned)'");
		Items.SettlementsAmount.Visible = False;
		Items.VATAmount.Visible = False;
		Items.PayrollPaymentTotalPaymentAmount.Visible = False;
		
	EndIf;
	
	SetVisibilityPlanningDocument();
	
EndProcedure

&AtServer
Procedure SetVisibilityPlanningDocument()
	
	If Object.OperationKind = Enums.OperationTypesCashVoucher.ToCustomer
		OR Object.OperationKind = Enums.OperationTypesCashVoucher.Vendor
		OR Object.OperationKind = Enums.OperationTypesCashVoucher.Salary
		OR Not GetFunctionalOption("PaymentCalendar") Then
		Items.PlanningDocuments.Visible	= False;
	ElsIf Object.OperationKind = Enums.OperationTypesCashVoucher.OtherSettlements
		OR Object.OperationKind = Enums.OperationTypesCashVoucher.LoanSettlements
		OR Object.OperationKind = Enums.OperationTypesCashVoucher.IssueLoanToEmployee Then
			Items.PlanningDocuments.Visible	= False;
	Else
		Items.PlanningDocuments.Visible	= True;
	EndIf;
	
EndProcedure

&AtServer
Procedure SetVisibilitySettlementAttributes()
	
	CounterpartyDoOperationsByContracts = Object.Counterparty.DoOperationsByContracts;
	
	Items.PaymentDetailsContract.Visible			= CounterpartyDoOperationsByContracts;
	Items.PaymentDetailsDocument.Visible			= Object.Counterparty.DoOperationsByDocuments;
	Items.PaymentDetailsOrder.Visible				= Object.Counterparty.DoOperationsByOrders;
	
	Items.OtherSettlementsContract.Visible = CounterpartyDoOperationsByContracts;
	
EndProcedure

&AtServer
Procedure SetVisibilityEPDAttributes()
	
	If ValueIsFilled(Object.Counterparty) Then
		DoOperationsByDocuments = CommonUse.ObjectAttributeValue(Object.Counterparty, "DoOperationsByDocuments");
	Else
		DoOperationsByDocuments = False;
	EndIf;
	
	OperationKindVendor = (Object.OperationKind = Enums.OperationTypesCashVoucher.Vendor);
	
	VisibleFlag = (DoOperationsByDocuments AND OperationKindVendor);
	
	Items.PaymentDetailsEPDAmount.Visible				= VisibleFlag;
	Items.PaymentDetailsSettlementsEPDAmount.Visible	= VisibleFlag;
	Items.PaymentDetailsExistsEPD.Visible				= VisibleFlag;
	Items.PaymentDetailsCalculateEPD.Visible			= VisibleFlag;
	
EndProcedure

&AtServer
Procedure SetTaxInvoiceText()
	Items.TaxInvoiceText.Visible = Not WorkWithVAT.GetPostAdvancePaymentsBySourceDocuments(Object.Date, Object.Company)
EndProcedure

#EndRegion

#Region ExternalFormViewManagement

&AtServer
Procedure SetChoiceParameterLinksAvailableTypes()
	
	// Other settlemets
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesCashVoucher.OtherSettlements") Then
		SetChoiceParametersForAccountingOtherSettlementsAtServerForAccountItem();
	Else
		SetChoiceParametersOnMetadataForAccountItem();
	EndIf;
	// End Other settlemets
	
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesCashVoucher.Vendor") Then
		
		Array = New Array();
		Array.Add(Type("DocumentRef.AdditionalExpenses"));
		Array.Add(Type("DocumentRef.SupplierInvoice"));
		Array.Add(Type("DocumentRef.SalesInvoice"));
		Array.Add(Type("DocumentRef.AccountSalesToConsignor"));
		Array.Add(Type("DocumentRef.SubcontractorReport"));
		Array.Add(Type("DocumentRef.ArApAdjustments"));
		
		ValidTypes = New TypeDescription(Array, , );
		Items.PaymentDetailsDocument.TypeRestriction = ValidTypes;
		
		ValidTypes = New TypeDescription("DocumentRef.PurchaseOrder", , );
		Items.PaymentDetailsOrder.TypeRestriction = ValidTypes;
		
		Items.PaymentDetailsDocument.ToolTip = NStr("en = 'The document that you pay for.'");

	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesCashVoucher.ToCustomer") Then
		
		Array = New Array();
		Array.Add(Type("DocumentRef.CashReceipt"));
		Array.Add(Type("DocumentRef.PaymentReceipt"));
		Array.Add(Type("DocumentRef.ArApAdjustments"));
		Array.Add(Type("DocumentRef.SalesOrder"));
		Array.Add(Type("DocumentRef.AccountSalesFromConsignee"));
		Array.Add(Type("DocumentRef.SubcontractorReportIssued"));
		Array.Add(Type("DocumentRef.FixedAssetSale"));
		Array.Add(Type("DocumentRef.SupplierInvoice"));
		Array.Add(Type("DocumentRef.SalesInvoice"));
		
		ValidTypes = New TypeDescription(Array, , );
		Items.PaymentDetailsDocument.TypeRestriction = ValidTypes;
		
		ValidTypes = New TypeDescription("DocumentRef.SalesOrder", ,);
		Items.PaymentDetailsOrder.TypeRestriction = ValidTypes;
		
		Items.PaymentDetailsDocument.ToolTip = NStr("en = 'An advance payment document that should be returned.'");
		
	EndIf;
	
EndProcedure

&AtServer
Procedure SetVisibilityPrintReceipt()
	
	PrintReceiptEnabled = False;
	
	Button = Items.Find("PrintReceipt");
	If Button <> Undefined Then
		
		If (Object.OperationKind = Enums.OperationTypesCashVoucher.ToCustomer
			OR Object.OperationKind = Enums.OperationTypesCashVoucher.Vendor
			OR Object.OperationKind = Enums.OperationTypesCashVoucher.Other)
		   AND GetFunctionalOption("UsePeripherals")
		   AND Not ReadOnly Then
			PrintReceiptEnabled = True;
		EndIf;
		
		Button.Enabled = PrintReceiptEnabled;
		Items.Decoration4.Visible = PrintReceiptEnabled;
		Items.SalesSlipNumber.Visible = PrintReceiptEnabled;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure SetCurrentPage()
	
	LineCount = Object.PaymentDetails.Count();
	
	If LineCount = 0 Then
		Object.PaymentDetails.Add();
		Object.PaymentDetails[0].PaymentAmount = Object.DocumentAmount;
		LineCount = 1;
	EndIf;
	
EndProcedure

#EndRegion

#Region GeneralPurposeProceduresAndFunctions

// Procedure of the field change data processor Operation kind on server.
//
&AtServer
Procedure SetCFItemWhenChangingTheTypeOfOperations()
	
	If Object.OperationKind = Enums.OperationTypesCashVoucher.ToCustomer
		AND (Object.Item = Catalogs.CashFlowItems.PaymentToVendor
		OR Object.Item = Catalogs.CashFlowItems.Other
		OR Object.Item = Catalogs.CashFlowItems.PaymentFromCustomers) Then
		Object.Item = Catalogs.CashFlowItems.PaymentFromCustomers;
	ElsIf Object.OperationKind = Enums.OperationTypesCashVoucher.Vendor
		AND (Object.Item = Catalogs.CashFlowItems.PaymentFromCustomers
		OR Object.Item = Catalogs.CashFlowItems.Other
		OR Object.Item = Catalogs.CashFlowItems.PaymentToVendor) Then
		Object.Item = Catalogs.CashFlowItems.PaymentToVendor;
	ElsIf (Object.Item = Catalogs.CashFlowItems.PaymentFromCustomers
		OR Object.Item = Catalogs.CashFlowItems.PaymentToVendor) Then
		Object.Item = Catalogs.CashFlowItems.Other;
	EndIf;
	
EndProcedure

// Procedure of the field change data processor Operation kind on server.
//
&AtServer
Procedure SetCFItem()
	
	If Object.OperationKind = Enums.OperationTypesCashVoucher.ToCustomer Then
		Object.Item = Catalogs.CashFlowItems.PaymentFromCustomers;
	ElsIf Object.OperationKind = Enums.OperationTypesCashVoucher.Vendor Then
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
		Items.OperationKind.ChoiceList.Add(Enums.OperationTypesCashVoucher.TransferToCashCR);
	EndIf;
	
	Items.OperationKind.ChoiceList.Add(Enums.OperationTypesCashVoucher.Other);
	Items.OperationKind.ChoiceList.Add(Enums.OperationTypesCashVoucher.OtherSettlements);
	
	Items.OperationKind.ChoiceList.Add(Enums.OperationTypesCashVoucher.IssueLoanToEmployee);
	Items.OperationKind.ChoiceList.Add(Enums.OperationTypesCashVoucher.LoanSettlements);
	
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
				Multiplicity);
				
			TabularSectionRow.EPDAmount = DriveClient.RecalculateFromCurrencyToCurrency(
				TabularSectionRow.SettlementsEPDAmount,
				TabularSectionRow.ExchangeRate,
				ExchangeRate,
				TabularSectionRow.Multiplicity,
				Multiplicity);
				
			CalculateVATSUM(TabularSectionRow);
			
		Else
			
			TabularSectionRow.ExchangeRate = ?(
				TabularSectionRow.ExchangeRate = 0,
				1,
				TabularSectionRow.ExchangeRate);
				
			TabularSectionRow.Multiplicity = ?(
				TabularSectionRow.Multiplicity = 0,
				1,
				TabularSectionRow.Multiplicity);
				
			TabularSectionRow.SettlementsAmount = DriveClient.RecalculateFromCurrencyToCurrency(
				TabularSectionRow.PaymentAmount,
				ExchangeRate,
				TabularSectionRow.ExchangeRate,
				Multiplicity,
				TabularSectionRow.Multiplicity);
				
			TabularSectionRow.SettlementsEPDAmount = DriveClient.RecalculateFromCurrencyToCurrency(
				TabularSectionRow.EPDAmount,
				ExchangeRate,
				TabularSectionRow.ExchangeRate,
				Multiplicity,
				TabularSectionRow.Multiplicity);
				
		EndIf;
		
	EndDo;
	
	If RecalculatePaymentAmount Then
		Object.DocumentAmount = Object.PaymentDetails.Total("PaymentAmount");
	EndIf;
	
EndProcedure

// Recalculates amounts by the cash assets currency.
//
&AtClient
Procedure RecalculateAmountsOnCashAssetsCurrencyRateChange(StructureData, MessageText)
	
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
	EndIf;
	
	// If currency exchange rate is not changed or cash
	// assets currency is not filled in or document is not filled in, then do nothing.
	If (ExchangeRate = ExchangeRateBeforeChange
		AND Multiplicity = MultiplicityBeforeChange)
		OR (NOT ValueIsFilled(Object.CashCurrency)) 
		OR (Object.PaymentDetails.Total("SettlementsAmount") = 0
		AND Not ValueIsFilled(Object.DocumentAmount)) Then
		Return;
	EndIf; 
	
	QuestionParameters = New Structure;
	QuestionParameters.Insert("ExchangeRateBeforeChange", ExchangeRateBeforeChange);
	QuestionParameters.Insert("MultiplicityBeforeChange", MultiplicityBeforeChange);
	
	NotifyDescription = New NotifyDescription("QuestionAmountRecalculationOnChangeCashAssetsCurrencyExchangeRateEnd", ThisObject, QuestionParameters);
	
	ShowQueryBox(NotifyDescription, MessageText, QuestionDialogMode.YesNo);
	
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

&AtClient
Procedure CalculateEPDAmount(TabularSectionRow)
	
	TabularSectionRow.ExchangeRate = ?(TabularSectionRow.ExchangeRate = 0, 1, TabularSectionRow.ExchangeRate);
	TabularSectionRow.Multiplicity = ?(TabularSectionRow.Multiplicity = 0, 1, TabularSectionRow.Multiplicity);
	
	TabularSectionRow.EPDAmount = DriveClient.RecalculateFromCurrencyToCurrency(
		TabularSectionRow.SettlementsEPDAmount,
		TabularSectionRow.ExchangeRate,
		ExchangeRate,
		TabularSectionRow.Multiplicity,
		Multiplicity);
	
EndProcedure

// Recalculate payment amount in the tabular section passed string.
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
	
	If Object.OperationKind = Enums.OperationTypesCashVoucher.LoanSettlements Then
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
Function GetDataAdvanceHolderOnChange(AdvanceHolder, Date)
	
	StructureData = New Structure;
	StructureData.Insert("AdvanceHolderDescription", "");
	StructureData.Insert("DocumentKind", "");
	StructureData.Insert("DocumentNumber", "");
	StructureData.Insert("DocumentIssueDate", "");
	StructureData.Insert("DocumentWhoIssued", "");
	
	Query = New Query();
	Query.Text =
	"SELECT
	|	LegalDocuments.DocumentKind,
	|	LegalDocuments.Number,
	|	LegalDocuments.IssueDate,
	|	LegalDocuments.Owner.Presentation AS Presentation,
	|	LegalDocuments.Authority
	|FROM
	|	Catalog.LegalDocuments AS LegalDocuments
	|WHERE
	|	LegalDocuments.Owner = &AdvanceHolder
	|
	|ORDER BY
	|	LegalDocuments.IssueDate DESC";
	
	Query.SetParameter("AdvanceHolder", AdvanceHolder.Ind);
	
	SelectionOfQueryResult = Query.Execute().Select();
	
	StructureData.AdvanceHolderDescription = AdvanceHolder.Description;
	
	If SelectionOfQueryResult.Next() Then
	
		StructureData.AdvanceHolderDescription = SelectionOfQueryResult.Presentation;
		StructureData.DocumentKind = SelectionOfQueryResult.DocumentKind;
		StructureData.DocumentNumber = SelectionOfQueryResult.Number;
		StructureData.DocumentIssueDate = SelectionOfQueryResult.IssueDate;
		StructureData.DocumentWhoIssued = SelectionOfQueryResult.Authority;
		
	EndIf;
	
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
	FillCreditLoanInformationAtServer();
	
	Return StructureData;
	
EndFunction

// It receives data set from server for the ContractOnChange procedure.
//
&AtServer
Function GetCompanyDataOnChange()
	
	StructureData = New Structure;
	
	StructureData.Insert(
		"ParentCompany",
		DriveServer.GetCompany(Object.Company)
	);
	
	FillVATRateByCompanyVATTaxation();
	SetTaxInvoiceText();
	
	Return StructureData;
		
EndFunction

// It receives data set from the server for the SalaryPaymentStatementOnChange procedure.
//
&AtServerNoContext
Function GetDataSalaryPayStatementOnChange(Statement)
	
	Return Statement.Employees.Total("PaymentAmount");
	
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

// Procedure fills VAT Rate in tabular section
// by company taxation system.
//
&AtServer
Procedure FillVATRateByCompanyVATTaxation()
	
	TaxationBeforeChange = Object.VATTaxation;
	
	If Object.OperationKind = Enums.OperationTypesCashVoucher.LoanSettlements
		Or Object.OperationKind = Enums.OperationTypesCashVoucher.IssueLoanToEmployee Then

		Object.VATTaxation = Enums.VATTaxationTypes.NotSubjectToVAT;
		
	Else
		
		Object.VATTaxation = DriveServer.VATTaxation(Object.Company, Object.Date);
		
	EndIf;
	
	If (Object.OperationKind = Enums.OperationTypesCashVoucher.ToCustomer
		OR Object.OperationKind = Enums.OperationTypesCashVoucher.Vendor)
		AND Not TaxationBeforeChange = Object.VATTaxation Then
		
		FillVATRateByVATTaxation();
		
	Else
		
		FillDefaultVATRate();
		
	EndIf;
	
EndProcedure

&AtServer
// Procedure fills the VAT rate in the tabular section according to the taxation system.
// 
Procedure FillVATRateByVATTaxation(RestoreRatesOfVAT = True)
	
	FillDefaultVATRate();
	
	If Object.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then
		
		If Object.OperationKind = Enums.OperationTypesCashVoucher.ToCustomer
		 OR Object.OperationKind = Enums.OperationTypesCashVoucher.Vendor Then
			
			Items.PaymentDetailsVATRate.Visible = True;
			Items.PaymentDetailsVatAmount.Visible = True;
			Items.VATAmount.Visible = True;
			
		EndIf;
		
		VATRate = DriveReUse.GetVATRateValue(DefaultVATRate);
		
		If RestoreRatesOfVAT Then
			For Each TabularSectionRow In Object.PaymentDetails Do
				TabularSectionRow.VATRate = InformationRegisters.AccountingPolicy.GetDefaultVATRate(Object.Date, Object.Company);
				TabularSectionRow.VATAmount = TabularSectionRow.PaymentAmount - (TabularSectionRow.PaymentAmount) / ((VATRate + 100) / 100);
			EndDo;
		EndIf;
		
	Else
		
		If Object.OperationKind = Enums.OperationTypesCashVoucher.ToCustomer
		 OR Object.OperationKind = Enums.OperationTypesCashVoucher.Vendor Then
			
			Items.PaymentDetailsVATRate.Visible = False;
			Items.PaymentDetailsVatAmount.Visible = False;
			Items.VATAmount.Visible = False;
			
		EndIf;
		
		If RestoreRatesOfVAT Then
			For Each TabularSectionRow In Object.PaymentDetails Do
				TabularSectionRow.VATRate = DefaultVATRate;
				TabularSectionRow.VATAmount = 0;
			EndDo;
		EndIf;
		
	EndIf;
	
	SetVisibilityPlanningDocument();
	
EndProcedure

&AtServer
// Procedure sets the Taxation field visible.
//
Procedure SetVisibleOfVATTaxation()
	
	If Object.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then
		
		Items.PaymentDetailsVATRate.Visible							= True;
		Items.PaymentDetailsVatAmount.Visible						= True;
		Items.SettlementsOnCreditsPaymentDetailsVATRate.Visible		= True;
		Items.SettlementsOnCreditsPaymentDetailsVATAmount.Visible	= True;
		Items.VATAmount.Visible										= True;
		
	Else
		
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
		TabularSectionRow.Multiplicity);
		
	TabularSectionRow.SettlementsEPDAmount = DriveClient.RecalculateFromCurrencyToCurrency(
		TabularSectionRow.EPDAmount,
		ExchangeRate,
		TabularSectionRow.ExchangeRate,
		Multiplicity,
		TabularSectionRow.Multiplicity);
	
EndProcedure

// Procedure executes actions while starting to select counterparty contract.
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

// Procedure determines advance flag depending on the billing document type.
//
&AtClient
Procedure RunActionsOnAccountsDocumentChange()
	
	TabularSectionRow = Items.PaymentDetails.CurrentData;
	
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesCashVoucher.ToCustomer") Then
		
		If TypeOf(TabularSectionRow.Document) = Type("DocumentRef.CashReceipt")
			OR TypeOf(TabularSectionRow.Document) = Type("DocumentRef.PaymentReceipt") Then
			
			TabularSectionRow.AdvanceFlag = True;
			
		Else
			
			TabularSectionRow.AdvanceFlag = False;
			
		EndIf;
		
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesCashVoucher.Vendor") Then
		
		If TypeOf(TabularSectionRow.Document) = Type("DocumentRef.SupplierInvoice") Then
			
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
	
	Return Documents.SupplierInvoice.CheckExistsEPD(Document, CheckDate);
	
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

&AtServer
// Procedure sets the form attribute visible
// from option Use subsystem Payroll.
//
// Parameters:
// No.
//
Procedure SetVisibleByFOUseSubsystemPayroll()
	
	// Salary.
	If Constants.UsePayrollSubsystem.Get() Then
		Items.OperationKind.ChoiceList.Add(Enums.OperationTypesCashVoucher.SalaryForEmployee);
		Items.OperationKind.ChoiceList.Add(Enums.OperationTypesCashVoucher.Salary);
	EndIf;
	
	// Taxes.
	Items.OperationKind.ChoiceList.Add(Enums.OperationTypesCashVoucher.Taxes);
	
EndProcedure

// Procedure receives the default petty cash currency.
//
&AtServerNoContext
Function GetPettyCashAccountingCurrencyAtServer(PettyCash)
	
	Return CommonUse.ObjectAttributeValue(PettyCash, "CurrencyByDefault");
	
EndFunction

// Checks the match of the "Company" and "LoanKind" contract attributes to the terms of the document.
//
&AtServerNoContext
Procedure CheckContractToDocumentConditionAccordance(Val TSPaymentDetails, MessageText, Document, Company, Counterparty, OperationKind, Cancel, LoanContract)
	
	If Not DriveReUse.CounterpartyContractsControlNeeded()
		OR Not Counterparty.DoOperationsByContracts Then
		
		Return;
	EndIf;
	
	ManagerOfCatalog = Catalogs.CounterpartyContracts;
	
	If OperationKind = Enums.OperationTypesCashVoucher.LoanSettlements Then
		
		LoanKindList = New ValueList;
		LoanKindList.Add(Enums.LoanContractTypes.Borrowed);
		
		If Not ManagerOfCatalog.ContractMeetsDocumentTerms(MessageText, LoanContract, Company, Counterparty, LoanKindList)
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

// Checks whether document is approved or not.
//
&AtServerNoContext
Function DocumentApproved(BasisDocument)
	
	Return BasisDocument.PaymentConfirmationStatus = Enums.PaymentApprovalStatuses.Approved;
	
EndFunction

&AtServerNoContext
Function GetSubordinateDebitNote(BasisDocument)
	
	Return EarlyPaymentDiscountsServer.GetSubordinateDebitNote(BasisDocument);
	
EndFunction

&AtServerNoContext
Function CheckBeforeDebitNoteFilling(BasisDocument)
	
	Return EarlyPaymentDiscountsServer.CheckBeforeDebitNoteFilling(BasisDocument, False)
	
EndFunction

#EndRegion

#Region ProceduresAndFunctionsForControlOfTheFormAppearance

// The procedure clears the attributes that could have been
// filled in earlier but do not belong to the current operation.
//
&AtClient
Procedure ClearAttributesNotRelatedToOperation()
	
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesCashVoucher.Vendor")
		OR Object.OperationKind = PredefinedValue("Enum.OperationTypesCashVoucher.ToCustomer") Then
		Object.Correspondence = Undefined;
		Object.TaxKind = Undefined;
		Object.AdvanceHolder = Undefined;
		Object.Document = Undefined;
		Object.PayrollPayment.Clear();
		Object.Department = Undefined;
		Object.BusinessLine = Undefined;
		Object.RegistrationPeriod = Undefined;
		Object.Order = Undefined;
		Object.CashCR = Undefined;
		Object.LoanContract = Undefined;
		For Each TableRow In Object.PaymentDetails Do
			TableRow.Order = Undefined;
			TableRow.Document = Undefined;
			TableRow.AdvanceFlag = False;
			If Object.OperationKind = PredefinedValue("Enum.OperationTypesCashVoucher.ToCustomer") Then
				TableRow.EPDAmount = 0;
				TableRow.SettlementsEPDAmount = 0;
				TableRow.ExistsEPD = False;
			EndIf;
		EndDo;
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesCashVoucher.ToAdvanceHolder") Then
		Object.Correspondence = Undefined;
		Object.Counterparty = Undefined;
		Object.TaxKind = Undefined;
		Object.Department = Undefined;
		Object.BusinessLine = Undefined;
		Object.Order = Undefined;
		Object.RegistrationPeriod = Undefined;
		Object.CashCR = Undefined;
		Object.PayrollPayment.Clear();
		Object.LoanContract = Undefined;
		For Each TableRow In Object.PaymentDetails Do
			TableRow.Contract = Undefined;
			TableRow.AdvanceFlag = False;
			TableRow.Document = Undefined;
			TableRow.Order = Undefined;
			TableRow.VATRate = Undefined;
			TableRow.VATAmount = Undefined;
			TableRow.EPDAmount = 0;
			TableRow.SettlementsEPDAmount = 0;
			TableRow.ExistsEPD = False;
		EndDo;
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesCashVoucher.Salary") Then
		Object.Correspondence = Undefined;
		Object.Counterparty = Undefined;
		Object.AdvanceHolder = Undefined;
		Object.Document = Undefined;
		Object.Department = Undefined;
		Object.LoanContract = Undefined;
		If Not FunctionalOptionAccountingCashMethodIncomeAndExpenses Then
			Object.BusinessLine = Undefined;
		EndIf;
		Object.Order = Undefined;
		Object.RegistrationPeriod = Undefined;
		Object.CashCR = Undefined;
		Object.PaymentDetails.Clear();
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesCashVoucher.SalaryForEmployee") Then
		Object.Correspondence = Undefined;
		Object.Counterparty = Undefined;
		Object.Document = Undefined;
		Object.Department = Undefined;
		Object.LoanContract = Undefined;
		If Not FunctionalOptionAccountingCashMethodIncomeAndExpenses Then
			Object.BusinessLine = Undefined;
		EndIf;
		Object.Order = Undefined;
		Object.CashCR = Undefined;
		Object.PayrollPayment.Clear();
		If Not ValueIsFilled(Object.Department) Then
			SettingValue = DriveReUse.GetValueByDefaultUser(CurrentSystemUser, "MainDepartment");
			Object.Department = ?(ValueIsFilled(SettingValue), SettingValue, StructuralUnitDepartment);
		EndIf;
		For Each TableRow In Object.PaymentDetails Do
			TableRow.Contract = Undefined;
			TableRow.AdvanceFlag = False;
			TableRow.Document = Undefined;
			TableRow.Order = Undefined;
			TableRow.VATRate = Undefined;
			TableRow.VATAmount = Undefined;
			TableRow.EPDAmount = 0;
			TableRow.SettlementsEPDAmount = 0;
			TableRow.ExistsEPD = False;
		EndDo;
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesCashVoucher.Other") Then
		Object.Counterparty = Undefined;
		Object.AdvanceHolder = Undefined;
		Object.Document = Undefined;
		Object.TaxKind = Undefined;
		Object.RegistrationPeriod = Undefined;
		Object.CashCR = Undefined;
		Object.PayrollPayment.Clear();
		Object.LoanContract = Undefined;
		For Each TableRow In Object.PaymentDetails Do
			TableRow.Contract = Undefined;
			TableRow.AdvanceFlag = False;
			TableRow.Document = Undefined;
			TableRow.Order = Undefined;
			TableRow.VATRate = Undefined;
			TableRow.VATAmount = Undefined;
			TableRow.EPDAmount = 0;
			TableRow.SettlementsEPDAmount = 0;
			TableRow.ExistsEPD = False;
		EndDo;
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesCashVoucher.TransferToCashCR") Then
		Object.Counterparty = Undefined;
		Object.AdvanceHolder = Undefined;
		Object.Document = Undefined;
		Object.TaxKind = Undefined;
		Object.Correspondence = Undefined;
		Object.Department = Undefined;
		Object.BusinessLine = Undefined;
		Object.Order = Undefined;
		Object.RegistrationPeriod = Undefined;
		Object.PayrollPayment.Clear();
		Object.LoanContract = Undefined;
		For Each TableRow In Object.PaymentDetails Do
			TableRow.Contract = Undefined;
			TableRow.AdvanceFlag = False;
			TableRow.Document = Undefined;
			TableRow.Order = Undefined;
			TableRow.VATRate = Undefined;
			TableRow.VATAmount = Undefined;
			TableRow.EPDAmount = 0;
			TableRow.SettlementsEPDAmount = 0;
			TableRow.ExistsEPD = False;
		EndDo;
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesCashVoucher.Taxes") Then
		Object.Counterparty = Undefined;
		Object.AdvanceHolder = Undefined;
		Object.Document = Undefined;
		Object.Correspondence = Undefined;
		Object.Department = Undefined;
		Object.LoanContract = Undefined;
		If Not FunctionalOptionAccountingCashMethodIncomeAndExpenses Then
			Object.BusinessLine = Undefined;
		EndIf;
		Object.Order = Undefined;
		Object.RegistrationPeriod = Undefined;
		Object.CashCR = Undefined;
		Object.PayrollPayment.Clear();
		For Each TableRow In Object.PaymentDetails Do
			TableRow.Contract = Undefined;
			TableRow.AdvanceFlag = False;
			TableRow.Document = Undefined;
			TableRow.Order = Undefined;
			TableRow.VATRate = Undefined;
			TableRow.VATAmount = Undefined;
			TableRow.EPDAmount = 0;
			TableRow.SettlementsEPDAmount = 0;
			TableRow.ExistsEPD = False;
		EndDo;
	// Other settlement
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesCashVoucher.OtherSettlements") Then
		Object.Correspondence = Undefined;
		Object.Counterparty = Undefined;
		Object.AdvanceHolder = Undefined;
		Object.Document = Undefined;
		Object.TaxKind = Undefined;
		Object.RegistrationPeriod = Undefined;
		Object.CashCR = Undefined;
		Object.Order = Undefined;
		Object.PayrollPayment.Clear();
		Object.PaymentDetails.Clear();
		Object.PaymentDetails.Add();
		Object.PaymentDetails[0].PaymentAmount = Object.DocumentAmount;
		Object.LoanContract = Undefined;
	// End Other settlement
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesCashVoucher.IssueLoanToEmployee") Then
		Object.Correspondence = Undefined;
		Object.Counterparty = Undefined;
		Object.TaxKind = Undefined;
		Object.Department = Undefined;
		Object.BusinessLine = Undefined;
		Object.Order = Undefined;
		Object.RegistrationPeriod = Undefined;
		Object.CashCR = Undefined;
		Object.LoanContract = Undefined;
		Object.PayrollPayment.Clear();
		For Each TableRow In Object.PaymentDetails Do
			TableRow.Contract = Undefined;
			TableRow.AdvanceFlag = False;
			TableRow.Document = Undefined;
			TableRow.Order = Undefined;
			TableRow.VATRate = Undefined;
			TableRow.VATAmount = Undefined;
			TableRow.EPDAmount = 0;
			TableRow.SettlementsEPDAmount = 0;
			TableRow.ExistsEPD = False;
		EndDo;
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesCashVoucher.LoanSettlements") Then
		Object.Correspondence = Undefined;
		Object.Counterparty = Undefined;
		Object.TaxKind = Undefined;
		Object.Department = Undefined;
		Object.BusinessLine = Undefined;
		Object.Order = Undefined;
		Object.RegistrationPeriod = Undefined;
		Object.CashCR = Undefined;
		Object.LoanContract = Undefined;
		Object.PayrollPayment.Clear();
		For Each TableRow In Object.PaymentDetails Do
			TableRow.Contract = Undefined;
			TableRow.AdvanceFlag = False;
			TableRow.Document = Undefined;
			TableRow.Order = Undefined;
			TableRow.VATRate = Undefined;
			TableRow.VATAmount = Undefined;
			TableRow.EPDAmount = 0;
			TableRow.SettlementsEPDAmount = 0;
			TableRow.ExistsEPD = False;
		EndDo;
	EndIf;
	
	Correspondence = Object.Correspondence;
	
EndProcedure

#EndRegion

#Region ProcedureActionsOfTheFormCommandPanels

// Procedure - handler of the Selection button clicking.
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

		
	OpenForm("CommonForm.SelectInvoicesToBePaidToTheSupplier", SelectionParameters,,,,, New NotifyDescription("SelectionEnd", ThisObject, New Structure("AddressPaymentDetailsInStorage", AddressPaymentDetailsInStorage)));
	
EndProcedure

&AtClient
Procedure SelectionEnd(Result1, AdditionalParameters) Export
	
	AddressPaymentDetailsInStorage = AdditionalParameters.AddressPaymentDetailsInStorage;
	
	
	Result = Result1;
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

// Procedure - handler of clicking the button "Fill in by basis".
//
&AtClient
Procedure FillByBasis(Command)
	
	If Not ValueIsFilled(Object.BasisDocument) Then
		ShowMessageBox(Undefined,NStr("en = 'Please select a base document.'"));
		Return;
	EndIf;
	
	If (TypeOf(Object.BasisDocument) = Type("DocumentRef.CashTransferPlan")
		OR TypeOf(Object.BasisDocument) = Type("DocumentRef.ExpenditureRequest"))
		AND Not DocumentApproved(Object.BasisDocument) Then
		Raise NStr("en = 'Please select an approved cash transfer plan.'");
	EndIf;
	
	Response = Undefined;
	
	ShowQueryBox(New NotifyDescription("FillByBasisEnd", ThisObject), NStr("en = 'Do you want to refill the cash voucher?'"), QuestionDialogMode.YesNo, 0);
	
EndProcedure

&AtClient
Procedure FillByBasisEnd(Result, AdditionalParameters) Export
	
	Response = Result;
	If Response = DialogReturnCode.Yes Then
		
		Object.PaymentDetails.Clear();
		Object.PayrollPayment.Clear();
		
		FillByDocument(Object.BasisDocument);
		
		If Object.PaymentDetails.Count() = 0
			AND Object.OperationKind <> PredefinedValue("Enum.OperationTypesCashVoucher.Salary") Then
			Object.PaymentDetails.Add();
			Object.PaymentDetails[0].PaymentAmount = Object.DocumentAmount;
		EndIf;
		
		OperationKind = Object.OperationKind;
		CashCurrency = Object.CashCurrency;
		DocumentDate = Object.Date;
		
		SetCurrentPage();
		SetChoiceParameterLinksAvailableTypes();
		OperationKindOnChangeAtServer(False);
		
	EndIf;

EndProcedure

// Procedure is called while clicking the "Print receipt" button of the command bar.
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
					NStr("en = 'Select a fiscal register'"), NStr("en = 'The fiscal register is not connected.'"));
			
		Else
			
			MessageText = NStr("en = 'First, you need to select the cashier work place of the current session.'");
			
			CommonUseClientServer.MessageToUser(MessageText);
			
		EndIf;
		
	ElsIf ShowMessageBox Then
		ShowMessageBox(Undefined,NStr("en = 'Failed to post document'"));
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
			
			// Prepare goods table.
			ProductsTable = New Array();
			
			ProductsTableRow = New ValueList();
			ProductsTableRow.Add(NStr("en = 'Pay to:'") + " " + Object.Issue + Chars.LF
			+ NStr("en = 'Purpose:'") + " " + Object.Basis); //  1 - Description
			ProductsTableRow.Add("");					 //  2 - Barcode
			ProductsTableRow.Add("");					 //  3 - SKU
			ProductsTableRow.Add(SectionNumber);			//  4 - Department number
			ProductsTableRow.Add(Object.DocumentAmount);  //  5 - Price for position without discount
			ProductsTableRow.Add(1);					  //  6 - Quantity
			ProductsTableRow.Add("");					  //  7 - Discount description
			ProductsTableRow.Add(0);					  //  8 - Discount amount
			ProductsTableRow.Add(0);					  //  9 - Discount percentage
			ProductsTableRow.Add(Object.DocumentAmount);  // 10 - Position amount with discount
			ProductsTableRow.Add(0);					  // 11 - Tax number (1)
			ProductsTableRow.Add(0);					  // 12 - Tax amount (1)
			ProductsTableRow.Add(0);					  // 13 - Tax percent (1)
			ProductsTableRow.Add(0);					  // 14 - Tax number (2)
			ProductsTableRow.Add(0);					  // 15 - Tax amount (2)
			ProductsTableRow.Add(0);					  // 16 - Tax percent (2)
			ProductsTableRow.Add("");					 // 17 - Section name of commodity string formatting
			
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
			CommonParameters.Add(1);					  //  1 - Receipt type
			CommonParameters.Add(True);				 //  2 - Fiscal receipt sign
			CommonParameters.Add(Undefined);		   //  3 - Print on lining document
			CommonParameters.Add(Object.DocumentAmount);  //  4 - the receipt amount without discounts
			CommonParameters.Add(Object.DocumentAmount);  //  5 - the receipt amount after applying all discounts
			CommonParameters.Add("");					 //  6 - Discount card number
			CommonParameters.Add("");					 //  7 - Header text
			CommonParameters.Add("");					 //  8 - Footer text
			CommonParameters.Add(0);					  //  9 - Session number (for receipt copy)
			CommonParameters.Add(0);					  // 10 - Receipt number (for receipt copy)
			CommonParameters.Add(0);					  // 11 - Document No (for receipt copy)
			CommonParameters.Add(0);					  // 12 - Document date (for receipt copy)
			CommonParameters.Add("");					 // 13 - Cashier name (for receipt copy)
			CommonParameters.Add("");					 // 14 - Cashier password
			CommonParameters.Add(0);					  // 15 - Template number
			CommonParameters.Add("");					 // 16 - Section name header format
			CommonParameters.Add("");					 // 17 - Section name cellar format
			
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
				Modified  = True;
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

// Procedure - FillDetails command handler.
//
&AtClient
Procedure FillDetails(Command)
	
	If Object.DocumentAmount = 0 Then
		ShowMessageBox(Undefined, NStr("en = 'Please specify the amount.'"));
		Return;
	EndIf;
	
	If Not ValueIsFilled(Object.CashCurrency) Then
		ShowMessageBox(Undefined, NStr("en = 'Please select a currency.'"));
		Return;
	EndIf;
	
	Response = Undefined;
	
	ShowQueryBox(New NotifyDescription("FillDetailsEnd", ThisObject), 
		NStr("en = 'You are about to fill the payment details. This will overwrite the current details. Do you want to continue?'"),
		QuestionDialogMode.YesNo);
	
EndProcedure

&AtClient
Procedure FillDetailsEnd(Result, AdditionalParameters) Export
	
	Response = Result;
	
	If Response = DialogReturnCode.No Then
		Return;
	EndIf;
	
	Object.PaymentDetails.Clear();
	
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesCashVoucher.Vendor") Then
		
		FillPaymentDetails();
		
	EndIf;
	
	SetCurrentPage();
	
EndProcedure

&AtClient
Procedure CalculateEPD(Command)
	
	CalculateEPDServer();
	
	PaymentAmount = Object.PaymentDetails.Total("PaymentAmount");
	
	If PaymentAmount <> Object.DocumentAmount Then
		
		Notification	= New NotifyDescription("ChangeDocumentAmountAfterCalculateEPD", ThisObject);
		MessageText		= NStr("en = 'Document total is not equal to the sum of the allocated payments.
			|Do you want to correct the document amount?'");
		
		ShowQueryBox(Notification, MessageText, QuestionDialogMode.YesNo, ,DialogReturnCode.Yes);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ChangeDocumentAmountAfterCalculateEPD(Response, NotSpecified) Export
	
	If Response = DialogReturnCode.Yes Then
		
		Object.DocumentAmount = Object.PaymentDetails.Total("PaymentAmount");
		
	EndIf;
	
EndProcedure

&AtServer
Procedure CalculateEPDServer()
	
	Document = FormAttributeToValue("Object");
	Document.CalculateEPD();
	ValueToFormAttribute(Document, "Object");
	Modified = True;
	
EndProcedure

#EndRegion

#Region ProcedureEventHandlersOfHeaderAttributes

// Procedure - event handler OnChange of the Counterparty input field.
//
&AtClient
Procedure CounterpartyOnChange(Item)
	
	StructureData = GetDataCounterpartyOnChange(Object.Counterparty, Object.Company, Object.Date);
	
	If Not ValueIsFilled(Object.Issue) Then
		Object.Issue = StructureData.CounterpartyDescriptionFull;
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
	
	If StructureData.Property("DefaultLoanContract") AND ValueIsFilled(StructureData.DefaultLoanContract) Then
		Object.LoanContract = StructureData.DefaultLoanContract;
		ProceedChangeCreditOrLoanContract();
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
		OperationKindOnChangeAtServer();
		If Object.PaymentDetails.Count() = 1 Then
			Object.PaymentDetails[0].PaymentAmount = Object.DocumentAmount;
		EndIf;
	EndIf;
	
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
		StructureData = GetDataDateOnChange(DateBeforeChange);
		If StructureData.DATEDIFF <> 0 Then
			Object.Number = "";
		EndIf;
		MessageText = NStr("en = 'The exchange rate has changed. Do you want to recalculate the document amount?'");
		RecalculateAmountsOnCashAssetsCurrencyRateChange(StructureData, MessageText);
		
		DefinePaymentDetailsExistsEPD();
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
	ParentCompany = StructureData.ParentCompany;
	
EndProcedure

&AtClient
Procedure CashAssetsCurrencyOnChangeEnd(AdditionalParameters) Export
	
	MessageText = AdditionalParameters.MessageText;
	
	
	Object.PayrollPayment.Clear();
	
	CashAssetsCurrencyOnChangeFragment();

EndProcedure

&AtClient
Procedure CashAssetsCurrencyOnChangeFragment()
	
	Var StructureData, MessageText;
	
	StructureData = GetDataCashAssetsCurrencyOnChange(
	Object.Date,
	Object.CashCurrency
	);
	
	MessageText = NStr("en = 'Do you want to recalculate the document amount?'");
	RecalculateAmountsOnCashAssetsCurrencyRateChange(StructureData, MessageText);

EndProcedure

// Procedure - OnChange event handler of AdvanceHandler input field.
// Clears the AdvanceHolders document.
//
&AtClient
Procedure AdvanceHolderOnChange(Item)
	
	If OperationKind = PredefinedValue("Enum.OperationTypesCashVoucher.IssueLoanToEmployee") 
		OR OperationKind = PredefinedValue("Enum.OperationTypesCashVoucher.LoanSettlements") Then
		
		DataStructure = GetEmployeeDataOnChange(Object.AdvanceHolder, Object.Date, Object.Company);	
		Object.LoanContract = DataStructure.LoanContract;
		ProceedChangeCreditOrLoanContract();
		
	Else 
		DataStructure = GetDataAdvanceHolderOnChange(Object.AdvanceHolder, Object.Date);
	EndIf;	
	  		
	Object.Issue = DataStructure.AdvanceHolderDescription;
	Object.ByDocument = ?(ValueIsFilled(DataStructure.DocumentKind), 
							StringFunctionsClientServer.SubstituteParametersInString(
								NStr("en = '%1 number %2, issued %3 %4'"),
								DataStructure.DocumentKind, DataStructure.DocumentNumber, Format(DataStructure.DocumentIssueDate, "DLF=D"),
								DataStructure.DocumentWhoIssued),
							"");
EndProcedure

// Procedure - OnChange event handler of DocumentAmount input field.
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
	
EndProcedure

// Procedure - OnChange event handler of PettyCash input field.
//
&AtClient
Procedure PettyCashOnChange(Item)
	
	Object.CashCurrency = GetPettyCashAccountingCurrencyAtServer(Object.PettyCash);
	
	CurrencyCashBeforeChanging = CashCurrency;
	CashCurrency = Object.CashCurrency;
	
	// If currency is not changed, do nothing.
	If CashCurrency <> CurrencyCashBeforeChanging Then
		
		If Object.OperationKind = PredefinedValue("Enum.OperationTypesCashVoucher.Salary") Then
			
			MessageText = NStr("en = 'The currency has changed. The list of payslips will be cleared.'");
			
			Notification = New NotifyDescription(
				"CashAssetsCurrencyOnChangeEnd",
				ThisObject,
				New Structure("MessageText", MessageText));
				
			ShowMessageBox(Notification, MessageText);
			
			Return;
			
		EndIf;
		
		CashAssetsCurrencyOnChangeFragment();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure TaxInvoiceTextClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	ParametersFilter = New Structure("AdvanceFlag", True);
	AdvanceArray = Object.PaymentDetails.FindRows(ParametersFilter);

	If AdvanceArray.Count() > 0 Then
		WorkWithVATClient.OpenTaxInvoice(ThisForm, True, True);
	Else
		CommonUseClientServer.MessageToUser(
			NStr("en = 'There are no rows with advance payments in the Payment details tab'"));
	EndIf;
	
EndProcedure

&AtClient
Procedure DebitNoteTextClick(Item, StandardProcessing)
	
	StandardProcessing	= False;
	IsError				= False;
	
	If NOT ValueIsFilled(Object.Ref) Then
		
		CommonUseClientServer.MessageToUser(NStr("en = 'Please, save the document.'"));
		
		IsError = True;
		
	ElsIf CheckBeforeDebitNoteFilling(Object.Ref) Then
		
		IsError = True;
		
	EndIf;
	
	If NOT IsError Then
		
		DebitNoteFound = GetSubordinateDebitNote(Object.Ref);
		
		ParametersStructure = New Structure;
		
		If ValueIsFilled(DebitNoteFound) Then
			ParametersStructure.Insert("Key", DebitNoteFound);
		Else
			ParametersStructure.Insert("Basis", Object.Ref);
		EndIf;
		
		OpenForm("Document.DebitNote.ObjectForm", ParametersStructure, ThisObject);
		
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

// Procedure - OnChange event handler of PaymentDetailsSettlementsKind input field.
// Clears an attribute document if a settlement type is - "Advance".
//
&AtClient
Procedure PaymentDetailsAdvanceFlagOnChange(Item)
	
	TabularSectionRow = Items.PaymentDetails.CurrentData;
	
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesCashVoucher.Vendor") Then
		If TabularSectionRow.AdvanceFlag Then
			TabularSectionRow.Document = Undefined;
		Else
			TabularSectionRow.PlanningDocument = Undefined;
		EndIf;
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesCashVoucher.ToCustomer") Then
		If TypeOf(TabularSectionRow.Document) = Type("DocumentRef.CashReceipt")
			OR TypeOf(TabularSectionRow.Document) = Type("DocumentRef.PaymentReceipt") Then
			TabularSectionRow.AdvanceFlag = True;
			ShowMessageBox(Undefined,NStr("en = 'Cannot clear the ""Advance payment"" check box for this operation type.'"));
		ElsIf TypeOf(TabularSectionRow.Document) <> Type("DocumentRef.ArApAdjustments") Then
			TabularSectionRow.AdvanceFlag = False;
			ShowMessageBox(Undefined,NStr("en = 'Cannot select the ""Advance payment"" check box for this operation type.'"));
		EndIf;
	EndIf;
	
EndProcedure

// Procedure - SelectionStart event handler of PaymentDetailsDocument input field.
// Passes the current attribute value to the parameters.
//
&AtClient
Procedure PaymentDetailsDocumentStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	TabularSectionRow = Items.PaymentDetails.CurrentData;
	
	If TabularSectionRow.AdvanceFlag
		AND Object.OperationKind = PredefinedValue("Enum.OperationTypesCashVoucher.Vendor") Then
		
		Mode = QuestionDialogMode.OK;
		ShowMessageBox(, NStr("en = 'The current document will be the billing document in case of advance payment.'"));
		
	Else
		
		ThisIsAccountsReceivable = Object.OperationKind = PredefinedValue("Enum.OperationTypesCashVoucher.ToCustomer");
		
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

// Procedure - SelectionDataProcessor event handler of PaymentDetailsDocument input field.
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
	
	CalculatePaymentSUM(Items.PaymentDetails.CurrentData);
	
	If Object.PaymentDetails.Count() = 1 Then
		Object.DocumentAmount = Object.PaymentDetails[0].PaymentAmount;
	EndIf;
	
EndProcedure

&AtClient
Procedure PaymentDetailsSettlementsEPDAmountOnChange(Item)
	
	CalculateEPDAmount(Items.PaymentDetails.CurrentData);
	
EndProcedure

// Procedure - OnChange event handler of PaymentDetailsExchangeRate input field.
// Calculates the amount of the payment.
//
&AtClient
Procedure PaymentDetailsRateOnChange(Item)
	
	TabularSectionRow = Items.PaymentDetails.CurrentData;
	
	CalculatePaymentSUM(TabularSectionRow);
	CalculateEPDAmount(TabularSectionRow);
	
	If Object.PaymentDetails.Count() = 1 Then
		Object.DocumentAmount = Object.PaymentDetails[0].PaymentAmount;
	EndIf;
	
EndProcedure

// Procedure - OnChange event handler of PaymentDetailsUnitConversionFactor input field.
// Calculates the amount of the payment.
//
&AtClient
Procedure PaymentDetailsRepetitionOnChange(Item)
	
	TabularSectionRow = Items.PaymentDetails.CurrentData;
	
	CalculatePaymentSUM(TabularSectionRow);
	CalculateEPDAmount(TabularSectionRow);
	
	If Object.PaymentDetails.Count() = 1 Then
		Object.DocumentAmount = Object.PaymentDetails[0].PaymentAmount;
	EndIf;
	
EndProcedure

// The OnChange event handler of the PaymentDetailsPaymentAmount field.
// It updates the payment currency exchange rate and exchange rate multiplier, and also the VAT amount.
//
&AtClient
Procedure PaymentDetailsPaymentAmountOnChange(Item)
	
	TabularSectionRow = Items.PaymentDetails.CurrentData;
	
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
	
	If Not ValueIsFilled(TabularSectionRow.VATRate) Then
		TabularSectionRow.VATRate = DefaultVATRate;
	EndIf;
	
	CalculateVATSUM(TabularSectionRow);
	
EndProcedure

// Procedure - OnChange event handler of PaymentDetailsVATRate input field.
// Calculates VAT amount.
//
&AtClient
Procedure PaymentDetailsVATRateOnChange(Item)
	
	TabularSectionRow = Items.PaymentDetails.CurrentData;
	CalculateVATSUM(TabularSectionRow);
	
EndProcedure

// Procedure - OnChange event handler of PaymentDetailsDocument input field.
//
&AtClient
Procedure PaymentDetailsDocumentOnChange(Item)
	
	RunActionsOnAccountsDocumentChange();
	
EndProcedure

// Procedure - OnChange event handler of SalaryPaymentStatement input field.
//
&AtClient
Procedure SalaryPayStatementOnChange(Item)
	
	TabularSectionRow = Items.PayrollPayment.CurrentData;
	TabularSectionRow.PaymentAmount = GetDataSalaryPayStatementOnChange(TabularSectionRow.Statement);
	
EndProcedure

// Procedure - event handler Management of attribute RegistrationPeriod.
//
&AtClient
Procedure RegistrationPeriodTuning(Item, Direction, StandardProcessing)
	
	DriveClient.OnRegistrationPeriodRegulation(ThisForm, Direction);
	DriveClient.OnChangeRegistrationPeriod(ThisForm);
	
EndProcedure

// Procedure - event handler StartChoice of attribute RegistrationPeriod.
//
&AtClient
Procedure RegistrationPeriodStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing	 = False;
	
	CalendarDateOnOpen = ?(ValueIsFilled(Object.RegistrationPeriod), Object.RegistrationPeriod, DriveReUse.GetSessionCurrentDate());
	
	OpenForm("CommonForm.Calendar", DriveClient.GetCalendarGenerateFormOpeningParameters(CalendarDateOnOpen), ThisForm);
	
EndProcedure

&AtClient
Procedure VATTaxationOnChange(Item)
	
	FillVATRateByVATTaxation();
	
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
Procedure FillCreditLoanInformationAtServer()
	
	ConfigureLoanContractItem();
	
	If Object.LoanContract.IsEmpty() Then
		Items.LabelCreditContractInformation.Title = NStr("en = '<Select loan contract>'");
		Items.LabelRemainingDebtByCredit.Title = "";
		
		Items.LabelCreditContractInformation.TextColor = StyleColors.BorderColor;
		Items.LabelRemainingDebtByCredit.TextColor = StyleColors.BorderColor;
		
		Return;
	EndIf;
	
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesCashVoucher.IssueLoanToEmployee") Then
		FillLoanInformationAtServer();
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesCashVoucher.LoanSettlements") Then
		FillCreditInformationAtServer();
	EndIf;
	
EndProcedure

&AtServer
Procedure FillCreditInformationAtServer()
	    
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
	|	LoanSettlementsBalance.LoanContract.SettlementsCurrency.Description AS CurrencyPresentation,
	|	SUM(LoanSettlementsBalance.InterestCurBalance) AS InterestCurBalance,
	|	SUM(LoanSettlementsBalance.CommissionCurBalance) AS CommissionCurBalance
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
	
	Query.SetParameter("SliceLastDate", ?(Object.Date = '00010101', BegOfDay(CurrentDate()), BegOfDay(Object.Date)));
	Query.SetParameter("LoanContract", Object.LoanContract);
	
	ResultArray = Query.ExecuteBatch();
	
	If Object.LoanContract.LoanKind = Enums.LoanContractTypes.EmployeeLoanAgreement Then
		Multiplier = 1;
	Else
		Multiplier = -1;
	EndIf;
	
	SelectionSchedule = ResultArray[0].Select();
	SelectionScheduleFutureMonth = ResultArray[2].Select();
	
	LabelCreditContractInformationTextColor	= StyleColors.BorderColor;
	LabelRemainingDebtByCreditTextColor		= StyleColors.BorderColor;
	
	If SelectionScheduleFutureMonth.Next() Then
		
		If BegOfMonth(?(Object.Date = '00010101', CurrentDate(), Object.Date)) = BegOfMonth(SelectionScheduleFutureMonth.Period) Then
			PaymentDate = Format(SelectionScheduleFutureMonth.Period, "DLF=D");
		Else
			PaymentDate = Format(SelectionScheduleFutureMonth.Period, "DLF=D") + " (" + NStr("en = 'not in the current month'") + ")";
			LabelCreditContractInformationTextColor = StyleColors.FormTextColor;
		EndIf;
			
		LabelCreditContractInformation = StringFunctionsClientServer.SubstituteParametersInString( 
			NStr("en = 'Payment date: %1. Debt amount: %2. Interest: %3. Commission: %4 (%5)'"),
			PaymentDate,
			Format(SelectionScheduleFutureMonth.Principal, "NFD=2; NZ=0"),
			Format(SelectionScheduleFutureMonth.Interest, "NFD=2; NZ=0"),
			Format(SelectionScheduleFutureMonth.Commission, "NFD=2; NZ=0"),
			SelectionScheduleFutureMonth.CurrencyPresentation);

	ElsIf SelectionSchedule.Next() Then
		
		If BegOfMonth(?(Object.Date = '00010101', CurrentDate(), Object.Date)) = BegOfMonth(SelectionSchedule.Period) Then
			PaymentDate = Format(SelectionSchedule.Period, "DLF=D");
		Else
			PaymentDate = Format(SelectionSchedule.Period, "DLF=D") + " (" + NStr("en = 'not in the current month'") + ")";
			LabelCreditContractInformationTextColor = StyleColors.FormTextColor;
		EndIf;
			
		LabelCreditContractInformation = StringFunctionsClientServer.SubstituteParametersInString( 
			NStr("en = 'Payment date: %1. Debt amount: %2. Interest: %3. Commission: %4 (%5)'"),
			PaymentDate,
			Format(SelectionScheduleFutureMonth.Principal, "NFD=2; NZ=0"),
			Format(SelectionScheduleFutureMonth.Interest, "NFD=2; NZ=0"),
			Format(SelectionScheduleFutureMonth.Commission, "NFD=2; NZ=0"),
			SelectionScheduleFutureMonth.CurrencyPresentation);

	Else		
		LabelCreditContractInformation = NStr("en = 'Payment date: <not specified>'");		
	EndIf;
	
	
	SelectionBalance = ResultArray[1].Select();
	If SelectionBalance.Next() Then
		
		LabelRemainingDebtByCredit = StringFunctionsClientServer.SubstituteParametersInString( 
			NStr("en = 'Debt balance: %1. Interest: %2. Commission amount: %3 (%4)'"),
			Format(Multiplier * SelectionBalance.PrincipalDebtCurBalance, "NFD=2; NZ=0"),
			Format(Multiplier * SelectionBalance.InterestCurBalance, "NFD=2; NZ=0"),
			Format(SelectionScheduleFutureMonth.Interest, "NFD=2; NZ=0"),
			Format(Multiplier * SelectionBalance.CommissionCurBalance, "NFD=2; NZ=0"),
			SelectionBalance.CurrencyPresentation);
			
		If Multiplier * SelectionBalance.PrincipalDebtCurBalance >= 0 AND (Multiplier * SelectionBalance.InterestCurBalance < 0 OR 
			Multiplier * SelectionBalance.CommissionCurBalance < 0) Then
			LabelRemainingDebtByCreditTextColor = StyleColors.FormTextColor;
		EndIf;
		
		If Multiplier * SelectionBalance.PrincipalDebtCurBalance < 0 Then
			LabelRemainingDebtByCreditTextColor = StyleColors.SpecialTextColor;
		EndIf;
	Else		
		LabelRemainingDebtByCredit = NStr("en = 'Debt balance: <not specified>'");		
	EndIf;
	
	Items.LabelCreditContractInformation.Title		= LabelCreditContractInformation;
	Items.LabelRemainingDebtByCredit.Title			= LabelRemainingDebtByCredit;	
	Items.LabelCreditContractInformation.TextColor	= LabelCreditContractInformationTextColor;
	Items.LabelRemainingDebtByCredit.TextColor		= LabelRemainingDebtByCreditTextColor;
		
EndProcedure

&AtServer
Procedure FillLoanInformationAtServer()

	LabelCreditContractInformationTextColor = StyleColors.BorderColor;
	LabelRemainingDebtByCreditTextColor = StyleColors.BorderColor;
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	LoanSettlementsTurnovers.LoanContract.SettlementsCurrency AS Currency,
	|	LoanSettlementsTurnovers.PrincipalDebtCurReceipt
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
	|	SUM(TemporaryTableAmountsIssuedBefore.PrincipalDebtCurReceipt) AS PrincipalDebtCurReceipt,
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
	
	Query.SetParameter("LoanContract", Object.LoanContract);
	Query.SetParameter("Company", Object.Company);
	
	QueryResult = Query.Execute();
	
	Selection = QueryResult.Select();
	
	If Selection.Next() Then
		
		LabelCreditContractInformation = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Loan amount: %1 (%2)'"), 
			Selection.Total, 
			Selection.Currency);
		
		If Selection.Total = Selection.PrincipalDebtCurReceipt Then
			LabelRemainingDebtByCredit = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Remaining amount to issue: 0 (%1)'"),
				Selection.Currency);
			LabelRemainingDebtByCreditTextColor = StyleColors.SpecialTextColor;
		Else
			LabelRemainingDebtByCredit = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Remaining amount to issue: %1 (%2). Issued %3 (%2)'"),
				Selection.Total - Selection.PrincipalDebtCurReceipt,
				Selection.Currency,
				Selection.PrincipalDebtCurReceipt);
			LabelRemainingDebtByCreditTextColor = StyleColors.SpecialTextColor;
		EndIf;
		
	Else
		
		LabelCreditContractInformation = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Loan amount: %1 (%2)'"),
			Object.LoanContract.Total,
			Object.LoanContract.SettlementsCurrency);
		LabelRemainingDebtByCredit = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Remaining amount to issue: %1 (%2)'"),
			Object.LoanContract.Total,
			Object.LoanContract.SettlementsCurrency);
	EndIf;
	
	Items.LabelCreditContractInformation.Title = LabelCreditContractInformation;
	Items.LabelRemainingDebtByCredit.Title = LabelRemainingDebtByCredit;
	
	Items.LabelCreditContractInformation.TextColor = LabelCreditContractInformationTextColor;
	Items.LabelRemainingDebtByCredit.TextColor = LabelRemainingDebtByCreditTextColor;
	
EndProcedure

&AtServerNoContext
Function GetDefaultLoanContract(Document, Counterparty, Company, OperationKind)
	
	DocumentManager = Documents.LoanContract;
	
	LoanKindList = New ValueList;
	LoanKindList.Add(?(OperationKind = Enums.OperationTypesCashVoucher.LoanSettlements, 
		Enums.LoanContractTypes.Borrowed,
		Enums.LoanContractTypes.EmployeeLoanAgreement));
	                                                   
	DefaultLoanContract = DocumentManager.ReceiveLoanContractByDefaultByCompanyLoanKind(Counterparty, Company, LoanKindList);
	
	Return DefaultLoanContract;
	
EndFunction

&AtServer
Procedure ConfigureLoanContractItem()
	
	Items.EmployeeLoanAgreement.Enabled = NOT Object.AdvanceHolder.IsEmpty();
	If Items.EmployeeLoanAgreement.Enabled Then
		Items.EmployeeLoanAgreement.InputHint = "";
	Else
		Items.EmployeeLoanAgreement.InputHint = NStr("en = 'Before selecting a contract, select an employee.'");
	EndIf;
	
	Items.CreditContract.Enabled = NOT Object.Counterparty.IsEmpty();
	If Items.CreditContract.Enabled Then
		Items.CreditContract.InputHint = "";
	Else
		Items.CreditContract.InputHint = NStr("en = 'Before selecting a contract, select a bank.'");
	EndIf;
	
EndProcedure

&AtServer
Procedure FillByLoanContractAtServer()
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	LoanSettlementsTurnovers.LoanContract.SettlementsCurrency AS Currency,
	|	LoanSettlementsTurnovers.PrincipalDebtCurReceipt,
	|	NULL AS Field1
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
	|	NULL,
	|	CASE
	|		WHEN LoanSettlements.RecordType = VALUE(AccumulationRecordType.Receipt)
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
	|	SUM(TemporaryTableAmountsIssuedBefore.PrincipalDebtCurReceipt) AS PrincipalDebtCurReceipt,
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
	
	Query.SetParameter("LoanContract", Object.LoanContract);
	Query.SetParameter("Company", Object.Company);
	Query.SetParameter("Ref", Object.Ref);
	
	QueryResult = Query.Execute();
	
	Selection = QueryResult.Select();
	
	If Selection.Next() Then
		
		Object.CashCurrency = Selection.Currency;
		
		MessageText = "";
		
		If Selection.Total < Selection.PrincipalDebtCurReceipt Then
			MessageText = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Issued under the loan contract %1 (%2)'"), 
				Selection.PrincipalDebtCurReceipt,
				Selection.Currency);
		ElsIf Selection.Total = Selection.PrincipalDebtCurReceipt Then
			MessageText = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'The complete amount has been already issued under the loan contract %1 (%2)'"),
				Selection.PrincipalDebtCurReceipt,
				Selection.Currency);
		Else
			Object.DocumentAmount = Selection.Total - Selection.PrincipalDebtCurReceipt;
		EndIf;
		
		If MessageText <> "" Then
			CommonUseClientServer.MessageToUser(MessageText,, "LoanContract");
		EndIf;
	Else
		Object.DocumentAmount = Object.LoanContract.Total;
		Object.CashCurrency = Object.LoanContract.SettlementsCurrency;
	EndIf;
	
	Modified = True;
	
EndProcedure

&AtClient
Procedure FillByLoanContract(Command)
	
	If Object.LoanContract.IsEmpty() Then
		ShowMessageBox(Undefined, NStr("en = 'Please select a contract.'"));
		Return;
	EndIf;
	
	FillByLoanContractAtServer();
	DocumentAmountOnChange(Items.DocumentAmount);
	
EndProcedure

&AtClient
Procedure FillByCreditContract(Command)
	
	If Object.LoanContract.IsEmpty() Then
		ShowMessageBox(Undefined, NStr("en = 'Please select a contract.'"));
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
Procedure ProceedChangeCreditOrLoanContract()
	
	EmployeeLoanAgreementData = ProceedChangeCreditOrLoanContractAtServer(Object.LoanContract, Object.Date);
	Object.CashCurrency = EmployeeLoanAgreementData.Currency;
	
	FillCreditLoanInformationAtServer();
	
	CashCurrencyBeforeChange = CashCurrency;
	CashCurrency = Object.CashCurrency;
	
	If CashCurrency = CashCurrencyBeforeChange Then
		Return;
	EndIf;
	
	CashAssetsCurrencyOnChangeFragment();
	
EndProcedure

&AtServerNoContext
Function ProceedChangeCreditOrLoanContractAtServer(LoanContract, Date)
	
	DataStructure = New Structure;
	
	DataStructure.Insert("Currency", 			LoanContract.SettlementsCurrency);
	DataStructure.Insert("Counterparty",		LoanContract.Counterparty);
	DataStructure.Insert("Employee",			LoanContract.Employee);
	DataStructure.Insert("ThisIsLoanContract",	LoanContract.LoanKind = Enums.LoanContractTypes.EmployeeLoanAgreement);
		
	Return DataStructure;
	
EndFunction

&AtClient
Procedure EmployeeLoanAgreementOnChange(Item)
	ProceedChangeCreditOrLoanContract();
EndProcedure

&AtServerNoContext
Function GetEmployeeDataOnChange(Employee, Date, Company)
	
	DataStructure = GetDataAdvanceHolderOnChange(Employee, Date);
	
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

#EndRegion

#EndRegion
