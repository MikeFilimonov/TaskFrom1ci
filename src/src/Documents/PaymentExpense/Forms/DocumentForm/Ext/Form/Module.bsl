
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SetConditionalAppearance();
	
	DriveServer.FillDocumentHeader(
		Object,
		,
		Parameters.CopyingValue,
		Parameters.Basis,
		PostingIsAllowed,
		Parameters.FillingValues
	);
	
	If Object.OperationKind <> Enums.OperationTypesPaymentExpense.Salary
	   AND Object.PaymentDetails.Count() = 0 Then
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
		If ValueIsFilled(Object.BankAccount)
			AND TypeOf(Object.BankAccount.Owner) <> Type("CatalogRef.Companies") Then
			Object.BankAccount = Catalogs.BankAccounts.EmptyRef();
		EndIf; 
		If ValueIsFilled(Object.Company)
			AND ValueIsFilled(Object.BankAccount)
			AND Object.BankAccount.Owner <> Object.Company Then
			Object.Company = Object.BankAccount.Owner;
		EndIf; 
		If Not ValueIsFilled(Object.BankAccount) Then
			If ValueIsFilled(Object.CashCurrency) Then
				If Object.Company.BankAccountByDefault.CashCurrency = Object.CashCurrency Then
					Object.BankAccount = Object.Company.BankAccountByDefault;
				EndIf;
			Else
				Object.BankAccount = Object.Company.BankAccountByDefault;
				Object.CashCurrency = Object.BankAccount.CashCurrency;
			EndIf;
		Else
			Object.CashCurrency = Object.BankAccount.CashCurrency;
		EndIf;
		FillInContract(Parameters);
		SetCFItem();
	EndIf;
	
	If Object.PaymentDetails.Count() = 0 Then
		IsAdvance = False;
	Else
		IsAdvance = Object.PaymentDetails[0].AdvanceFlag;
	EndIf;
	
	If IsAdvance Then
		AdvanceFlag = Enums.YesNo.Yes;
	Else
		AdvanceFlag = Enums.YesNo.No;
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
	
	If Not ValueIsFilled(Object.Ref)
	   AND Not ValueIsFilled(Parameters.Basis)
	   AND Not ValueIsFilled(Parameters.CopyingValue)
	   AND Not Parameters.Property("BasisDocument") Then
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
	
	AccountingPolicy = InformationRegisters.AccountingPolicy.GetAccountingPolicy();
	FunctionalOptionAccountingCashMethodIncomeAndExpenses = AccountingPolicy.CashMethodOfAccounting;

	SetVisibilityAttributesDependenceOnCorrespondence();
	SetVisibilityItemsDependenceOnOperationKind();
	
	If Object.OperationKind = Enums.OperationTypesPaymentExpense.Taxes Then
		Items.BusinessLineTaxes.Visible = FunctionalOptionAccountingCashMethodIncomeAndExpenses;
	EndIf;
	
	If Object.OperationKind = Enums.OperationTypesPaymentExpense.Salary Then
		Items.SalaryPayoffsBusinessLine.Visible = FunctionalOptionAccountingCashMethodIncomeAndExpenses;
	EndIf;
	
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
	
	DriveClientServer.SetPictureForComment(Items.Additionally, Object.Comment);
	
	// Bank charges
	SetVisibleBankCharges();
	// End Bank charges
	
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
	SetVisiblePaymentDate();
	
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
	If WriteParameters.WriteMode = DocumentWriteMode.Posting Then
		PerformanceEstimationClientServer.StartTimeMeasurement("DocumentPaymentExpensePosting");
	EndIf;
	// StandardSubsystems.PerformanceMeasurement
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	If WriteParameters.WriteMode = DocumentWriteMode.Posting Then
		
		MessageText = "";
		CheckContractToDocumentConditionAccordance(Object.PaymentDetails, MessageText, Object.Ref, Object.Company, Object.Counterparty, Object.OperationKind, Cancel, Object.LoanContract);
		
		If MessageText <> "" Then
			
			Message = New UserMessage;
			Message.Text = ?(Cancel, NStr("en = 'Cannot post the bank payment.'") + " " + MessageText, MessageText);
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
	
	SetVisiblePaymentDate();
		
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	If CurrentObject.OperationKind = PredefinedValue("Enum.OperationTypesCashVoucher.IssueLoanToEmployee") 
		OR CurrentObject.OperationKind = PredefinedValue("Enum.OperationTypesCashVoucher.LoanSettlements") Then
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
	
	If ChoiceSource.FormName = "Document.TaxInvoiceReceived.Form.DocumentForm" Then
		
		TaxInvoiceText = SelectedValue;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormItemEventHandlers

#Region OtherSettlements

&AtClient
Procedure CorrespondenceOnChange(Item)
	
	If Correspondence <> Object.Correspondence Then
		SetVisibilityAttributesDependenceOnCorrespondence();
		Correspondence = Object.Correspondence;
	EndIf;
	
EndProcedure

&AtClient
Procedure EmployeeOnChange(Item)
	
	If OperationKind = PredefinedValue("Enum.OperationTypesPaymentExpense.IssueLoanToEmployee") 
		OR OperationKind = PredefinedValue("Enum.OperationTypesPaymentExpense.LoanSettlements") Then

		DataStructure = GetEmployeeDataOnChange(Object.AdvanceHolder, Object.Date, Object.Company);
		
		Object.LoanContract = DataStructure.LoanContract;
		HandleLoanContractChange();
		
	EndIf;
	
EndProcedure

#EndRegion 

#Region BankCharges
	
&AtClient
Procedure UseBankChargesOnChange(Item)

	SetVisibleBankCharges();
	
EndProcedure

&AtClient
Procedure BankChargeOnChange(Item)
	
	StructureData = GetDataBankChargeOnChange(
		Object.BankCharge,
		Object.CashCurrency
	);
	
	Object.BankChargeItem		= StructureData.BankChargeItem;
	Object.BankChargeAmount		= StructureData.BankChargeAmount;
	
EndProcedure

#EndRegion

&AtClient
Procedure PaidOnChange(Item)
	
	If Not Object.Paid Then
		Object.PaymentDate = Undefined;
	Else
		Object.PaymentDate = Object.Date;
	EndIf;
	
	SetVisiblePaymentDate();
	
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
	ElsIf Object.CashCurrency = StructureData.Currency Then
		TablePartRow.PaymentAmount = TablePartRow.SettlementsAmount;
	ElsIf TablePartRow.PaymentAmount = 0 OR
		(ColumnName = "ExchangeRate" OR ColumnName = "Multiplicity") Then
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
			New Structure("Currency", Contract.SettlementsCurrency)));
			
	StructureData.Insert("Currency", Contract.SettlementsCurrency);
	
	Return StructureData;
	
EndFunction

&AtServer
Procedure OperationKindOnChangeAtServer(FillTaxation = True)
	
	SetChoiceParameterLinksAvailableTypes();
	
	If Object.OperationKind = Enums.OperationTypesPaymentExpense.OtherSettlements Then
		
		DefaultVATRate						= Catalogs.VATRates.Exempt;
		DefaultVATRateNumber				= DriveReUse.GetVATRateValue(DefaultVATRate);
		Object.PaymentDetails[0].VATRate	= DefaultVATRate;
		
	ElsIf Object.OperationKind = Enums.OperationTypesCashVoucher.LoanSettlements Then
		
		DefaultVATRate			= Catalogs.VATRates.Exempt;
		DefaultVATRateNumber	= DriveReUse.GetVATRateValue(DefaultVATRate);
		
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

&AtServer
Procedure SetConditionalAppearance()
	
	// Payment date is required if the payment was marked as Paid

	Item = ConditionalAppearance.Items.Add();
	
	FilterGroup = Item.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
	FilterGroup.GroupType = DataCompositionFilterItemsGroupType.OrGroup;
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.PaymentDate.Name);
	
	ItemFilter = FilterGroup.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Object.Paid");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = False;
	
	ItemFilter = FilterGroup.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Object.PaymentDate");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Filled;
	
	Item.Appearance.SetParameterValue("MarkIncomplete", False);
	
EndProcedure

&AtServer
Procedure SetChoiceParametersForAccountingOtherSettlementsAtServerForAccountItem()

	Item = Items.Correspondence;
	
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

	Item = Items.Correspondence;
	
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
			User = Users.CurrentUser();
			SettingValue = DriveReUse.GetValueByDefaultUser(User, "MainDepartment");
			Object.Department = ?(ValueIsFilled(SettingValue), SettingValue, Catalogs.BusinessUnits.MainDepartment);
		EndIf;
	Else
		If Object.OperationKind <> Enums.OperationTypesPaymentExpense.Taxes // for entering based on
		 OR (Object.OperationKind = Enums.OperationTypesPaymentExpense.Taxes
		 AND Not FunctionalOptionAccountingCashMethodIncomeAndExpenses) Then
			Object.BusinessLine	= Undefined;
		EndIf;
		Object.Department				= Undefined;
		Object.Order					= Undefined;
		Items.BusinessLine.Visible	= False;
		Items.Department.Visible		= False;
		Items.Order.Visible				= False;
	EndIf;
	
EndProcedure

&AtServer
Procedure SetVisibilityItemsDependenceOnOperationKind()
	
	Items.PaymentDetailsPaymentAmount.Visible						= GetFunctionalOption("ForeignExchangeAccounting");
	Items.PaymentDetailsOtherSettlementsPaymentAmount.Visible		= GetFunctionalOption("ForeignExchangeAccounting");
	Items.SettlementsOnCreditsPaymentDetailsPaymentAmount.Visible	= GetFunctionalOption("ForeignExchangeAccounting");
	
	Items.SettlementsWithCounterparty.Visible	= False;
	Items.SettlementsWithAdvanceHolder.Visible	= False;
	Items.OtherSettlements.Visible				= False;
	Items.Payroll.Visible						= False;
	Items.TaxesSettlements.Visible				= False;
	
	Items.Counterparty.Visible					= False;
	Items.CounterpartyAccount.Visible			= False;
	Items.AdvanceHolder.Visible					= False;
	Items.VATTaxation.Visible					= False;
	
	NewArray		= New Array();
	NewConnection	= New ChoiceParameterLink("Filter.Owner", "Object.Counterparty");
	NewArray.Add(NewConnection);
	NewConnection	= New ChoiceParameterLink("Filter.CashCurrency", "Object.CashCurrency");
	NewArray.Add(NewConnection);
	Items.CounterpartyAccount.ChoiceParameterLinks	= New FixedArray(NewArray);
	Items.Counterparty.ChoiceParameters				= New FixedArray(New Array());
	
	Items.LoanSettlements.Visible			= False;
	Items.LoanSettlements.Title				= NStr("en = 'Loan account statement'");
	Items.EmployeeLoanAgreement.Visible		= False;
	Items.FillByLoanContract.Visible		= False;
	Items.CreditContract.Visible			= False;
	Items.FillByCreditContract.Visible		= False;
	Items.GroupContractInformation.Visible	= False;
	Items.AdvanceHolder.Visible				= False;
	
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesPaymentExpense.Vendor") Then
		
		Items.SettlementsWithCounterparty.Visible	= True;
		Items.PaymentDetailsPickup.Visible			= True;
		Items.PaymentDetailsFillDetails.Visible		= True;
		
		Items.Counterparty.Visible					= True;
		Items.Counterparty.Title					= NStr("en = 'Supplier'");
		Items.CounterpartyAccount.Visible			= True;
		Items.VATTaxation.Visible					= True;
		
		Items.PaymentAmount.Visible		= True;
		Items.PaymentAmount.Title		= NStr("en = 'Payment amount'");
		Items.SettlementsAmount.Visible = Not GetFunctionalOption("ForeignExchangeAccounting");
		
		Items.VATAmount.Visible	= Object.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT;
		Items.PayrollPaymentTotalPaymentAmount.Visible	= False;
	
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesPaymentExpense.ToCustomer") Then
		
		Items.SettlementsWithCounterparty.Visible	= True;
		Items.PaymentDetailsPickup.Visible			= False;
		Items.PaymentDetailsFillDetails.Visible		= False;
		
		Items.Counterparty.Visible					= True;
		Items.Counterparty.Title					= NStr("en = 'Customer'");
		Items.CounterpartyAccount.Visible			= True;
		Items.VATTaxation.Visible					= True;
		
		Items.PaymentAmount.Visible		= True;
		Items.PaymentAmount.Title		= NStr("en = 'Payment amount'");
		Items.SettlementsAmount.Visible	= Not GetFunctionalOption("ForeignExchangeAccounting");
		
		Items.VATAmount.Visible	= Object.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT;
		Items.PayrollPaymentTotalPaymentAmount.Visible	= False;
		
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesPaymentExpense.ToAdvanceHolder") Then
		
		NewArray		= New Array();
		NewConnection	= New ChoiceParameterLink("Filter.Owner", "Object.AdvanceHolder");
		NewArray.Add(NewConnection);
		NewConnections	= New FixedArray(NewArray);
		Items.CounterpartyAccount.ChoiceParameterLinks	= NewConnections;
		
		Items.CounterpartyAccount.Visible			= True;
		Items.SettlementsWithAdvanceHolder.Visible	= True;
		Items.AdvanceHolder.Visible					= True;
		Items.AdvanceHolder.Title					= NStr("en = 'Advance holder'");
		Items.PaymentAmount.Visible					= GetFunctionalOption("PaymentCalendar");
		Items.PaymentAmount.Title					= ?(GetFunctionalOption("PaymentCalendar"), 
			NStr("en = 'Amount (planned)'"), 
			NStr("en = 'Payment amount'"));
		Items.PaymentAmountCurrency.Visible			= Items.PaymentAmount.Visible;
		Items.SettlementsAmount.Visible				= False;
		
		Items.VATAmount.Visible	= False;
		
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesPaymentExpense.Salary") Then
		
		Items.Payroll.Visible					= True;	
		Items.PaymentAmount.Visible						= False;
		Items.SettlementsAmount.Visible					= False;
		Items.VATAmount.Visible							= False;
		Items.PayrollPaymentTotalPaymentAmount.Visible	= True;
		
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesPaymentExpense.Taxes") Then
		
		NewArray 		= New Array();
		NewConnection	= New ChoiceParameter("Filter.OtherRelationship", True);
		NewArray.Add(NewConnection);
		NewConnections	= New FixedArray(NewArray);
		Items.Counterparty.ChoiceParameters	= NewConnections;
		
		Items.Counterparty.Visible			= True;
		Items.CounterpartyAccount.Visible	= True;
		Items.TaxesSettlements.Visible		= True;
		
		Items.PaymentAmount.Visible			= GetFunctionalOption("PaymentCalendar");
		Items.PaymentAmount.Title			= ?(GetFunctionalOption("PaymentCalendar"), 
			NStr("en = 'Amount (planned)'"), 
			NStr("en = 'Payment amount'"));
		Items.PaymentAmountCurrency.Visible	= Items.PaymentAmount.Visible;
		Items.SettlementsAmount.Visible		= False;
		
		Items.VATAmount.Visible							= False;
		Items.PayrollPaymentTotalPaymentAmount.Visible	= False;
		
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesPaymentExpense.Other") Then
		
		Items.OtherSettlements.Visible	= True;
		
		Items.PaymentAmount.Visible			= GetFunctionalOption("PaymentCalendar");
		Items.PaymentAmount.Title			= ?(GetFunctionalOption("PaymentCalendar"), 
			NStr("en = 'Amount (planned)'"), 
			NStr("en = 'Payment amount'"));
		Items.PaymentAmountCurrency.Visible	= Items.PaymentAmount.Visible;
		Items.SettlementsAmount.Visible		= False;
		
		Items.VATAmount.Visible							= False;
		Items.PaymentDetailsOtherSettlements.Visible	= False;
		
		SetVisibilityAttributesDependenceOnCorrespondence();
		
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesPaymentExpense.OtherSettlements") Then
		
		Items.OtherSettlements.Visible	= True;
		
		Items.PaymentAmount.Visible			= GetFunctionalOption("ForeignExchangeAccounting");
		Items.PaymentAmount.Title 			= NStr("en = 'Payment amount'");
		Items.SettlementsAmount.Visible 	= Not GetFunctionalOption("ForeignExchangeAccounting");
		Items.VATAmount.Visible				= False;
		
		Items.Counterparty.Visible	= True;
		Items.Counterparty.Title	= NStr("en = 'Counterparty'");
		Items.CounterpartyAccount.Visible = True;
		Items.PaymentDetailsOtherSettlements.Visible 			= True;
		Items.PaymentDetailsOtherSettlementsContract.Visible	= Object.Counterparty.DoOperationsByContracts;
		SetVisibilityAttributesDependenceOnCorrespondence();
		
		If Object.PaymentDetails.Count() > 0 Then
			ID = Object.PaymentDetails[0].GetID();
			Items.PaymentDetailsOtherSettlements.CurrentRow = ID;
		EndIf;
		
	ElsIf OperationKind = PredefinedValue("Enum.OperationTypesPaymentExpense.IssueLoanToEmployee") Then
		
		NewArray		= New Array();
		NewConnection	= New ChoiceParameterLink("Filter.Owner", "Object.AdvanceHolder");
		NewArray.Add(NewConnection);
		NewConnections	= New FixedArray(NewArray);
		Items.CounterpartyAccount.ChoiceParameterLinks	= NewConnections;
		
		Items.CounterpartyAccount.Visible					= True;
		Items.AdvanceHolder.Visible							= True;
		Items.AdvanceHolder.Title							= NStr("en = 'Employee'");
		Items.LoanSettlements.Title							= NStr("en = 'Loan account statement'");
		Items.LoanSettlements.Visible						= True;
		Items.SettlementsOnCreditsPaymentDetails.Visible	= False;
		Items.EmployeeLoanAgreement.Visible					= True;
		Items.FillByLoanContract.Visible					= True;
		
		FillInformationAboutCreditLoanAtServer();
		
		Items.GroupContractInformation.Visible			= True;		
		Items.PaymentAmount.Visible						= GetFunctionalOption("PaymentCalendar");
		Items.PaymentAmountCurrency.Visible				= Items.PaymentAmount.Visible;
		Items.PaymentAmount.Title						= NStr("en = 'Payment amount'");
		Items.SettlementsAmount.Visible					= False;
		Items.VATAmount.Visible							= False;
		Items.PayrollPaymentTotalPaymentAmount.Visible	= False;
		
	ElsIf OperationKind = PredefinedValue("Enum.OperationTypesPaymentExpense.LoanSettlements") Then
		
		Items.LoanSettlements.Visible					= True;
		Items.Counterparty.Visible							= True;
		Items.Counterparty.Title							= NStr("en = 'Lender'");
		Items.CounterpartyAccount.Visible					= True;
		Items.VATTaxation.Visible							= True;
		Items.SettlementsOnCreditsPaymentDetails.Visible	= True;
		Items.CreditContract.Visible						= True;
		Items.FillByCreditContract.Visible					= True;
		
		FillInformationAboutCreditLoanAtServer();
		
		Items.GroupContractInformation.Visible			= True;	
		Items.PaymentAmount.Visible						= GetFunctionalOption("ForeignExchangeAccounting");
		Items.PaymentAmount.Title						= NStr("en = 'Payment amount'");
		Items.SettlementsAmount.Visible					= True;
		Items.VATAmount.Visible							= False;
		Items.PayrollPaymentTotalPaymentAmount.Visible	= False;

	Else
		
		Items.OtherSettlements.Visible					= True;		
		Items.PaymentAmount.Visible						= True;
		Items.PaymentAmount.Title						= NStr("en = 'Amount (planned)'");
		Items.SettlementsAmount.Visible					= False;
		Items.VATAmount.Visible							= False;
		Items.PayrollPaymentTotalPaymentAmount.Visible	= False;
		
	EndIf;
	
	SetVisibilityPlanningDocument();
	
EndProcedure

&AtServer
Procedure SetVisibilityPlanningDocument()
	
	If Object.OperationKind = Enums.OperationTypesPaymentExpense.ToCustomer
		OR Object.OperationKind = Enums.OperationTypesPaymentExpense.Vendor
		OR Object.OperationKind = Enums.OperationTypesPaymentExpense.Salary
		OR Not GetFunctionalOption("PaymentCalendar") Then
			Items.PlanningDocuments.Visible = False;
	ElsIf Object.OperationKind = Enums.OperationTypesPaymentExpense.OtherSettlements 
		OR Object.OperationKind = Enums.OperationTypesPaymentExpense.LoanSettlements 
		OR Object.OperationKind = Enums.OperationTypesPaymentExpense.IssueLoanToEmployee Then
			Items.PlanningDocuments.Visible = False;
	Else
		Items.PlanningDocuments.Visible = True;
	EndIf;
	
EndProcedure

&AtServer
Procedure SetVisibilityEPDAttributes()
	
	If ValueIsFilled(Object.Counterparty) Then
		DoOperationsByDocuments = CommonUse.ObjectAttributeValue(Object.Counterparty, "DoOperationsByDocuments");
	Else
		DoOperationsByDocuments = False;
	EndIf;
	
	OperationKindVendor = (Object.OperationKind = Enums.OperationTypesPaymentExpense.Vendor);
	
	VisibleFlag = (DoOperationsByDocuments AND OperationKindVendor);
	
	Items.PaymentDetailsEPDAmount.Visible				= VisibleFlag;
	Items.PaymentDetailsSettlementsEPDAmount.Visible	= VisibleFlag;
	Items.PaymentDetailsExistsEPD.Visible				= VisibleFlag;
	Items.PaymentDetailsCalculateEPD.Visible			= VisibleFlag;
	
EndProcedure

&AtServer
Procedure SetVisibilitySettlementAttributes()
	
	CounterpartyDoOperationsByContracts = Object.Counterparty.DoOperationsByContracts;
	
	Items.PaymentDetailsContract.Visible			= CounterpartyDoOperationsByContracts;
	Items.PaymentDetailsDocument.Visible			= Object.Counterparty.DoOperationsByDocuments;
	Items.PaymentDetailsOrder.Visible				= Object.Counterparty.DoOperationsByOrders;
	
	Items.PaymentDetailsOtherSettlementsContract.Visible = CounterpartyDoOperationsByContracts;
	
EndProcedure

#Region BankCharges

&AtServer
Procedure SetVisibleBankCharges()

	Items.GroupBankCharges.Visible	= Object.UseBankCharges;

EndProcedure

&AtClient
Procedure SetVisiblePaymentDate()

	Items.PaymentDate.ReadOnly = Not Object.Paid;

EndProcedure

&AtServer
Function GetDataBankChargeOnChange(BankCharge, CashCurrency)

	StructureData	= New Structure;
	
	StructureData.Insert(
		"BankChargeItem", 
		BankCharge.Item
	);
	
	StructureData.Insert(
		"BankChargeAmount", 
		?(BankCharge.ChargeType = Enums.ChargeMethod.Percent, Object.DocumentAmount * BankCharge.Value / 100, BankCharge.Value)
	);
	
	Return StructureData;

EndFunction

#EndRegion 

#EndRegion

#Region ExternalFormViewManagement

&AtServer
Procedure SetChoiceParameterLinksAvailableTypes()
	
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesPaymentExpense.OtherSettlements") Then
		SetChoiceParametersForAccountingOtherSettlementsAtServerForAccountItem();
	Else
		SetChoiceParametersOnMetadataForAccountItem();
	EndIf;
	
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesPaymentExpense.Vendor") Then
		
		Array = New Array();
		Array.Add(Type("DocumentRef.AdditionalExpenses"));
		Array.Add(Type("DocumentRef.SupplierInvoice"));
		Array.Add(Type("DocumentRef.SalesInvoice"));
		Array.Add(Type("DocumentRef.AccountSalesToConsignor"));
		Array.Add(Type("DocumentRef.SubcontractorReport"));
		Array.Add(Type("DocumentRef.ArApAdjustments"));
		
		ValidTypes = New TypeDescription(Array, ,);
		Items.PaymentDetailsDocument.TypeRestriction = ValidTypes;
		
		ValidTypes = New TypeDescription("DocumentRef.PurchaseOrder", ,);
		Items.PaymentDetailsOrder.TypeRestriction = ValidTypes;
		
		Items.PaymentDetailsDocument.ToolTip = NStr("en = 'The document that you pay for.'");
		
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesPaymentExpense.ToCustomer") Then
		
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
		
		ValidTypes = New TypeDescription(Array, ,);
		Items.PaymentDetailsDocument.TypeRestriction = ValidTypes;
		
		ValidTypes = New TypeDescription("DocumentRef.SalesOrder", , );
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
	
	If Object.OperationKind = Enums.OperationTypesPaymentExpense.ToCustomer
		AND (Object.Item = Catalogs.CashFlowItems.PaymentToVendor
		OR Object.Item = Catalogs.CashFlowItems.Other
		OR Object.Item = Catalogs.CashFlowItems.PaymentFromCustomers) Then
		Object.Item = Catalogs.CashFlowItems.PaymentFromCustomers;
	ElsIf Object.OperationKind = Enums.OperationTypesPaymentExpense.Vendor
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
	
	If Object.OperationKind = Enums.OperationTypesPaymentExpense.ToCustomer Then
		Object.Item = Catalogs.CashFlowItems.PaymentFromCustomers;
	ElsIf Object.OperationKind = Enums.OperationTypesPaymentExpense.Vendor Then
		Object.Item = Catalogs.CashFlowItems.PaymentToVendor;
	Else
		Object.Item = Catalogs.CashFlowItems.Other;
	EndIf;
	
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
&AtServer
Procedure RecalculateDocumentAmounts(ExchangeRate, Multiplicity, RecalculatePaymentAmount)
	
	For Each TabularSectionRow In Object.PaymentDetails Do
		
		If CommonUse.ObjectAttributeValue(TabularSectionRow.Contract, "SettlementsCurrency") = Object.CashCurrency Then
			TabularSectionRow.SettlementsAmount = TabularSectionRow.PaymentAmount;
			Continue;
		EndIf;
		
		If RecalculatePaymentAmount Then
			
			TabularSectionRow.PaymentAmount = DriveServer.RecalculateFromCurrencyToCurrency(
				TabularSectionRow.SettlementsAmount,
				TabularSectionRow.ExchangeRate,
				ExchangeRate,
				TabularSectionRow.Multiplicity,
				Multiplicity);
			
			TabularSectionRow.EPDAmount = DriveServer.RecalculateFromCurrencyToCurrency(
				TabularSectionRow.SettlementsEPDAmount,
				TabularSectionRow.ExchangeRate,
				ExchangeRate,
				TabularSectionRow.Multiplicity,
				Multiplicity);
				
			CalculateVATSUMAtServer(TabularSectionRow);
			
		Else
			
			TabularSectionRow.ExchangeRate = ?(
				TabularSectionRow.ExchangeRate = 0,
				1,
				TabularSectionRow.ExchangeRate);
				
			TabularSectionRow.Multiplicity = ?(
				TabularSectionRow.Multiplicity = 0,
				1,
				TabularSectionRow.Multiplicity);
				
			TabularSectionRow.SettlementsAmount = DriveServer.RecalculateFromCurrencyToCurrency(
				TabularSectionRow.PaymentAmount,
				ExchangeRate,
				TabularSectionRow.ExchangeRate,
				Multiplicity,
				TabularSectionRow.Multiplicity);
				
			TabularSectionRow.SettlementsEPDAmount = DriveServer.RecalculateFromCurrencyToCurrency(
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
	 
	 	If StructureData.Property("UpdateExchangeRate") AND StructureData.UpdateExchangeRate Then
			ShowQueryBox(New NotifyDescription("UpdateExchangeRateInPaymentDetails", ThisObject), StructureData.UpdateExchangeRateQueryText, QuestionDialogMode.YesNo);
		EndIf;

		Return;
	EndIf;
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("ExchangeRateBeforeChange", ExchangeRateBeforeChange);
	AdditionalParameters.Insert("MultiplicityBeforeChange", MultiplicityBeforeChange);
	
	NotifyDescription = New NotifyDescription("DefineNeedToRecalculateAmountsOnRateChange", ThisObject, AdditionalParameters);
	ShowQueryBox(NotifyDescription, MessageText, QuestionDialogMode.YesNo, 0);
	
EndProcedure

// Procedure-handler of a response to the question on document recalculation after currency rate change
//
&AtClient
Procedure DefineNeedToRecalculateAmountsOnRateChange(ClosingResult, AdditionalParameters) Export
	
	If ClosingResult = DialogReturnCode.Yes Then
		
		ExchangeRateBeforeChange = AdditionalParameters.ExchangeRateBeforeChange;
		MultiplicityBeforeChange = AdditionalParameters.MultiplicityBeforeChange;
		
		If Object.PaymentDetails.Count() > 0
		   AND Object.OperationKind <> PredefinedValue("Enum.OperationTypesPaymentExpense.Salary") Then // only header is recalculated for the "Salary" operation kind.
			If Object.OperationKind = PredefinedValue("Enum.OperationTypesPaymentExpense.ToCustomer")
			 OR Object.OperationKind = PredefinedValue("Enum.OperationTypesPaymentExpense.Vendor") Then
				RecalculateDocumentAmounts(ExchangeRate, Multiplicity, True);
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
	
	If NOT (Object.OperationKind = PredefinedValue("Enum.OperationTypesPaymentExpense.Vendor")) Then
		If AdditionalParameters.Property("UpdateExchangeRate")  AND AdditionalParameters.UpdateExchangeRate Then
			ShowQueryBox(New NotifyDescription("UpdateExchangeRateInPaymentDetails", ThisObject),
				AdditionalParameters.UpdateExchangeRateQueryText,
				QuestionDialogMode.YesNo);
		EndIf;
	EndIf;
	
EndProcedure

&AtServerNoContext
Function GetDataPaymentDetailsOnChange(Date, Contract)
	
	StructureData = New Structure;
	
	StructureData.Insert(
		"ContractCurrencyExchangeRate",
		InformationRegisters.ExchangeRates.GetLast(
			Date,
			New Structure("Currency", Contract.SettlementsCurrency)));
	StructureData.Insert("Currency", Contract.SettlementsCurrency);
	
	Return StructureData;
	
EndFunction

&AtServer
Procedure UpdatePaymentDetailsExchangeRatesAtServer()
	
	For each TSRow In Object.PaymentDetails Do
			
		If ValueIsFilled(TSRow.Contract) Then
			StructureData = GetDataPaymentDetailsOnChange(
				Object.Date,
				TSRow.Contract
			);
			TSRow.ExchangeRate = ?(
				StructureData.ContractCurrencyExchangeRate.ExchangeRate = 0,
				1,
				StructureData.ContractCurrencyExchangeRate.ExchangeRate
			);
			TSRow.Multiplicity = ?(
				StructureData.ContractCurrencyExchangeRate.Multiplicity = 0,
				1,
				StructureData.ContractCurrencyExchangeRate.Multiplicity
			);
		EndIf;
		
		TSRow.SettlementsAmount = DriveServer.RecalculateFromCurrencyToCurrency(
			TSRow.PaymentAmount,
			ExchangeRate,
			TSRow.ExchangeRate,
			Multiplicity,
			TSRow.Multiplicity
		);
		
	EndDo;
	
EndProcedure

&AtClient
Procedure UpdateExchangeRateInPaymentDetails(ResultButton, AdditionalParameters) Export

	If ResultButton = DialogReturnCode.Yes Then
		UpdatePaymentDetailsExchangeRatesAtServer();
	EndIf;

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

// Recalculates amounts by the document tabular section
// currency after changing the bank account or petty cash.
//
&AtClient
Procedure CalculateVATSUM(TabularSectionRow)
	
	VATRate = DriveReUse.GetVATRateValue(TabularSectionRow.VATRate);
	
	TabularSectionRow.VATAmount = TabularSectionRow.PaymentAmount - (TabularSectionRow.PaymentAmount) / ((VATRate + 100) / 100);
	
EndProcedure

&AtServer
Procedure CalculateVATSUMAtServer(TabularSectionRow)
	
	VATRate = DriveReUse.GetVATRateValue(TabularSectionRow.VATRate);
	
	TabularSectionRow.VATAmount = TabularSectionRow.PaymentAmount - (TabularSectionRow.PaymentAmount) / ((VATRate + 100) / 100);
	
EndProcedure

// It receives data set from the server for the CounterpartyOnChange procedure.
//
&AtServer
Function GetDataCounterpartyOnChange(Counterparty, Company, Date)
	
	ContractByDefault = GetContractByDefault(Object.Ref, Counterparty, Company, Object.OperationKind);
	
	If ValueIsFilled(Object.CounterpartyAccount) 
		AND CommonUse.ObjectAttributeValue(Object.CounterpartyAccount, "Owner") = Counterparty Then
		CounterpartyAccount = Object.CounterpartyAccount;
	Else
		CounterpartyAccount = CommonUse.ObjectAttributeValue(Counterparty, "BankAccountByDefault");
	EndIf;
	
	StructureData = New Structure;
	StructureData.Insert("Contract", ContractByDefault);
	StructureData.Insert("CounterpartyAccount", CounterpartyAccount);
	
	StructureData.Insert(
		"ContractCurrencyRateRepetition",
		InformationRegisters.ExchangeRates.GetLast(
			Date,
			New Structure("Currency", ContractByDefault.SettlementsCurrency)));
	
	If Object.OperationKind = Enums.OperationTypesPaymentExpense.LoanSettlements Then
		DefaultLoanContract = GetDefaultLoanContract(Object.Ref, Counterparty, Company, Object.OperationKind);
		StructureData.Insert(
			"DefaultLoanContract",
			DefaultLoanContract);
	EndIf;

	SetVisibilitySettlementAttributes();
	SetVisibilityEPDAttributes();
	
	Return StructureData;
	
EndFunction

// It receives data set from the server for the CurrencyCashOnChange procedure.
//
&AtServerNoContext
Function GetDataBankAccountOnChange(Date, BankAccount, CounterpartyAccount)
	
	StructureData = New Structure;
	
	StructureData.Insert(
		"CurrencyRateRepetition",
		InformationRegisters.ExchangeRates.GetLast(
			Date,
			New Structure("Currency", BankAccount.CashCurrency)
		)
	);
	
	StructureData.Insert(
		"CashCurrency",
		BankAccount.CashCurrency
	);
	
	StructureData.Insert(
		"CounterpartyAccount",
		?(ValueIsFilled(CounterpartyAccount) AND CounterpartyAccount.CashCurrency = BankAccount.CashCurrency, CounterpartyAccount, Undefined)
	);
	
	
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
	
	StructureData.Insert(
		"ParentCompany",
		DriveServer.GetCompany(Object.Company)
	);
	
	StructureData.Insert(
		"BankAccount",
		?(ValueIsFilled(Object.BankAccount) AND Object.BankAccount.Owner = Object.Company, Object.BankAccount, Object.Company.BankAccountByDefault)
	);
	
	StructureData.Insert(
		"CurrencyRateRepetition",
		InformationRegisters.ExchangeRates.GetLast(
			Object.Date,
			New Structure("Currency", StructureData.BankAccount.CashCurrency)
		)
	);
	
	StructureData.Insert(
		"CashCurrency",
		StructureData.BankAccount.CashCurrency
	);
	
	StructureData.Insert(
		"CounterpartyAccount",
		?(ValueIsFilled(Object.CounterpartyAccount) AND StructureData.BankAccount.CashCurrency = Object.CounterpartyAccount.CashCurrency, Object.CounterpartyAccount, Catalogs.BankAccounts.EmptyRef())
	);
	
	FillVATRateByCompanyVATTaxation();
	
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
	
	If Object.OperationKind = Enums.OperationTypesPaymentExpense.LoanSettlements
		OR Object.OperationKind = Enums.OperationTypesPaymentExpense.IssueLoanToEmployee Then
		
		Object.VATTaxation = Enums.VATTaxationTypes.NotSubjectToVAT;
		
	Else
		
		Object.VATTaxation = DriveServer.VATTaxation(Object.Company, Object.Date);
		
	EndIf;
	
	If (Object.OperationKind = Enums.OperationTypesPaymentExpense.ToCustomer
			OR Object.OperationKind = Enums.OperationTypesPaymentExpense.Vendor)
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

// Procedure sets the form attribute visible
// from option Use subsystem Payroll.
//
// Parameters:
// No.
//
&AtServer
Procedure SetVisibleByFOUseSubsystemPayroll()
	
	// Salary.
	If Constants.UsePayrollSubsystem.Get() Then
		Items.OperationKind.ChoiceList.Add(Enums.OperationTypesPaymentExpense.Salary);
	EndIf;
	
	// Taxes.
	Items.OperationKind.ChoiceList.Add(Enums.OperationTypesPaymentExpense.Taxes);
	
	// Other.
	Items.OperationKind.ChoiceList.Add(Enums.OperationTypesPaymentExpense.Other);
	Items.OperationKind.ChoiceList.Add(Enums.OperationTypesPaymentExpense.IssueLoanToEmployee);
	Items.OperationKind.ChoiceList.Add(Enums.OperationTypesPaymentExpense.LoanSettlements);
	Items.OperationKind.ChoiceList.Add(Enums.OperationTypesPaymentExpense.OtherSettlements);
	
EndProcedure

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

// Fills in the contract.
//
Procedure FillInContract(Parameters = Undefined)
	
	If Object.OperationKind <> PredefinedValue("Enum.OperationTypesPaymentExpense.IssueLoanToEmployee") AND
		Object.OperationKind <> PredefinedValue("Enum.OperationTypesPaymentExpense.LoanSettlements") Then
		
		If ValueIsFilled(Object.Counterparty)
			AND Object.PaymentDetails.Count() > 0
			AND (Parameters = Undefined OR (Parameters <> Undefined AND Not ValueIsFilled(Parameters.BasisDocument))) Then
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
	
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesPaymentExpense.Vendor")
	 OR Object.OperationKind = PredefinedValue("Enum.OperationTypesPaymentExpense.ToCustomer") Then
		Object.Correspondence = Undefined;
		Object.TaxKind = Undefined;
		Object.CounterpartyAccount = Undefined;
		Object.AdvanceHolder = Undefined;
		Object.Document = Undefined;
		Object.PayrollPayment.Clear();
		Object.Department = Undefined;
		Object.BusinessLine = Undefined;
		Object.Order = Undefined;
		Object.LoanContract = Undefined;
		For Each TableRow In Object.PaymentDetails Do
			TableRow.Order = Undefined;
			TableRow.Document = Undefined;
			TableRow.AdvanceFlag = False;
			If Object.OperationKind = PredefinedValue("Enum.OperationTypesPaymentExpense.ToCustomer") Then
				TableRow.EPDAmount = 0;
				TableRow.SettlementsEPDAmount = 0;
				TableRow.ExistsEPD = False;
			EndIf;
		EndDo;
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesPaymentExpense.ToAdvanceHolder") Then
		Object.Correspondence = Undefined;
		Object.TaxKind = Undefined;
		Object.Counterparty = Undefined;
		Object.CounterpartyAccount = Undefined;
		Object.Department = Undefined;
		Object.BusinessLine = Undefined;
		Object.Order = Undefined;
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
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesPaymentExpense.Salary") Then
		Object.Correspondence = Undefined;
		Object.Counterparty = Undefined;
		Object.CounterpartyAccount = Undefined;
		Object.AdvanceHolder = Undefined;
		Object.Document = Undefined;
		Object.Department = Undefined;
		Object.LoanContract = Undefined;
		If Not FunctionalOptionAccountingCashMethodIncomeAndExpenses Then
			Object.BusinessLine = Undefined;
		EndIf;
		Object.Order = Undefined;
		Object.PaymentDetails.Clear();
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesPaymentExpense.Other") Then
		Object.Counterparty = Undefined;
		Object.CounterpartyAccount = Undefined;
		Object.AdvanceHolder = Undefined;
		Object.Document = Undefined;
		Object.TaxKind = Undefined;
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
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesPaymentExpense.Taxes") Then
		Object.Counterparty = Undefined;
		Object.CounterpartyAccount = Undefined;
		Object.AdvanceHolder = Undefined;
		Object.Document = Undefined;
		Object.Correspondence = Undefined;
		Object.Department = Undefined;
		Object.LoanContract = Undefined;
		If Not FunctionalOptionAccountingCashMethodIncomeAndExpenses Then
			Object.BusinessLine = Undefined;
		EndIf;
		Object.Order = Undefined;
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
		
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesPaymentExpense.OtherSettlements") Then
		
		Object.Correspondence		= Undefined;
		Object.Counterparty			= Undefined;
		Object.CounterpartyAccount	= Undefined;
		Object.AdvanceHolder		= Undefined;
		Object.Document				= Undefined;
		Object.TaxKind				= Undefined;
		Object.Order				= Undefined;
		Object.LoanContract			= Undefined;
		
		Object.PayrollPayment.Clear();
		Object.PaymentDetails.Clear();
		
		Object.PaymentDetails.Add();
		Object.PaymentDetails[0].PaymentAmount = Object.DocumentAmount;
		
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesCashVoucher.LoanSettlements") Then
		
		Object.Correspondence		= Undefined;
		Object.Counterparty			= Undefined;
		Object.CounterpartyAccount	= Undefined;
		Object.AdvanceHolder		= Undefined;
		Object.TaxKind				= Undefined;
		Object.Department			= Undefined;
		Object.BusinessLine		= Undefined;
		Object.Order				= Undefined;
		Object.LoanContract			= Undefined;
		
		Object.PayrollPayment.Clear();
		
		For Each TableRow In Object.PaymentDetails Do
			TableRow.Contract				= Undefined;
			TableRow.AdvanceFlag			= False;
			TableRow.Document				= Undefined;
			TableRow.Order					= Undefined;
			TableRow.VATRate				= Undefined;
			TableRow.VATAmount				= Undefined;
			TableRow.EPDAmount				= 0;
			TableRow.SettlementsEPDAmount	= 0;
			TableRow.ExistsEPD				= False;
		EndDo;
		
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesCashVoucher.IssueLoanToEmployee") Then
		
		Object.Correspondence		= Undefined;
		Object.Counterparty			= Undefined;
		Object.CounterpartyAccount	= Undefined;
		Object.AdvanceHolder		= Undefined;
		Object.TaxKind				= Undefined;
		Object.Department			= Undefined;
		Object.BusinessLine		= Undefined;
		Object.Order				= Undefined;
		Object.LoanContract			= Undefined;
		
		Object.PayrollPayment.Clear();
		
		For Each TableRow In Object.PaymentDetails Do
			TableRow.Contract				= Undefined;
			TableRow.AdvanceFlag			= False;
			TableRow.Document				= Undefined;
			TableRow.Order					= Undefined;
			TableRow.VATRate				= Undefined;
			TableRow.VATAmount				= Undefined;
			TableRow.EPDAmount				= 0;
			TableRow.SettlementsEPDAmount	= 0;
			TableRow.ExistsEPD				= False;
		EndDo;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region ProcedureActionsOfTheFormCommandPanels

// Procedure - handler of the Execute event of the Pickup command
// Opens the form of debt forming documents selection.
//
&AtClient
Procedure Pick(Command)
	
	If Not ValueIsFilled(Object.Counterparty) Then
		ShowMessageBox(Undefined,NStr("en = 'Please select a counterparty.'"));
		Return;
	EndIf;
	
	If Not ValueIsFilled(Object.BankAccount)
	   AND Not ValueIsFilled(Object.CashCurrency) Then
		ShowMessageBox(Undefined,NStr("en = 'Please select a bank account.'"));
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

// You can call the procedure by clicking
// the button "FillByBasis" of the tabular field command panel.
//
&AtClient
Procedure FillByBasis(Command)
	
	If Not ValueIsFilled(Object.BasisDocument) Then
		ShowMessageBox(Undefined, NStr("en = 'Please select a base document.'"));
		Return;
	EndIf;
	
	If (TypeOf(Object.BasisDocument) = Type("DocumentRef.CashTransferPlan")
		OR TypeOf(Object.BasisDocument) = Type("DocumentRef.ExpenditureRequest"))
		AND Not DocumentApproved(Object.BasisDocument) Then
			Raise NStr("en = 'Please select an approved cash transfer plan.'");
	EndIf;
	
	Response = Undefined;
	
	ShowQueryBox(New NotifyDescription("FillByBasisEnd", ThisObject), 
		NStr("en = 'Do you want to refill the payment expense?'"), 
		QuestionDialogMode.YesNo, 
		0);
	
EndProcedure

&AtClient
Procedure FillByBasisEnd(Result, AdditionalParameters) Export
	
	Response = Result;
	If Response = DialogReturnCode.Yes Then
		
		Object.BankAccount = Undefined;
		Object.CounterpartyAccount = Undefined;
		
		Object.PaymentDetails.Clear();
		Object.PayrollPayment.Clear();
		
		FillByDocument(Object.BasisDocument);
		
		If Object.OperationKind <> PredefinedValue("Enum.OperationTypesPaymentExpense.Salary")
			AND Object.PaymentDetails.Count() = 0 Then
			Object.PaymentDetails.Add();
			Object.PaymentDetails[0].PaymentAmount = Object.DocumentAmount;
		EndIf;
		
		OperationKind = Object.OperationKind;
		CashCurrency = Object.CashCurrency;
		DocumentDate = Object.Date;
		
		SetCurrentPage();
		SetChoiceParameterLinksAvailableTypes();
		OperationKindOnChangeAtServer(False);
		
		FillInContract();
		
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
	
	If Not ValueIsFilled(Object.BankAccount)
	   AND Not ValueIsFilled(Object.CashCurrency) Then
		ShowMessageBox(Undefined,NStr("en = 'Please select a bank account.'"));
		Return;
	EndIf;
	
	Response = Undefined;

	
	ShowQueryBox(New NotifyDescription("FillDetailsEnd", ThisObject), 
		NStr("en = 'Do you want to overwrite the payment details?'"),
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
	
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesPaymentExpense.Vendor") Then
		
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
	
	If NOT ValueIsFilled(Object.CounterpartyAccount) AND StructureData.Property("CounterpartyAccount") 
		AND ValueIsFilled(StructureData.CounterpartyAccount) Then
		Object.CounterpartyAccount = StructureData.CounterpartyAccount;
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
		HandleLoanContractChange();
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
		
		StructureData.Insert("UpdateExchangeRate", (Object.PaymentDetails.Count() > 0 AND Object.PaymentDetails.Total("ExchangeRate") > 0 AND
			Object.PaymentDetails.Count() <> Object.PaymentDetails.Total("ExchangeRate")));
		StructureData.Insert("UpdateExchangeRateQueryText", NStr("en = 'The document date has changed. Do you want to apply the exchange rate as of this date?'"));
		
		MessageText = NStr("en = 'The exchange rate has changed. Do you want to recalculate the document amount?'");
		RecalculateAmountsOnCashAssetsCurrencyRateChange(StructureData, MessageText);
		
		DefinePaymentDetailsExistsEPD();
	EndIf;
	
EndProcedure

&AtClient
Procedure PaymentDateOnChange(Item)
	
	DefinePaymentDetailsExistsEPD();
	
EndProcedure

// Procedure - event handler OnChange of the Company input field.
// In procedure is executed document
// number clearing and also make parameter set of the form functional options.
// Overrides the corresponding form parameter.
//
&AtClient
Procedure CompanyOnChange(Item)
	
	// Company change event data processor.
	Object.Number				= "";
	StructureData				= GetCompanyDataOnChange();
	ParentCompany			= StructureData.ParentCompany;
	Object.BankAccount			= StructureData.BankAccount;
	Object.CounterpartyAccount	= StructureData.CounterpartyAccount;
	
	CurrencyCashBeforeChanging	= CashCurrency;
	Object.CashCurrency			= StructureData.CashCurrency;
	CashCurrency				= StructureData.CashCurrency;
	
	SetTaxInvoiceText();
	
	// If currency is not changed, do nothing.
	If CashCurrency = CurrencyCashBeforeChanging Then
		Return;
	EndIf;
	
	If Object.PaymentDetails.Count() > 0 Then
		Object.PaymentDetails[0].Contract = Undefined;
	EndIf;
	
	MessageText = NStr("en = 'The currency has changed. Do you want to recalculate the document amount?'");

	RecalculateAmountsOnCashAssetsCurrencyRateChange(StructureData, MessageText);
	
EndProcedure

// Procedure - OnChange event handler of BankAccount input field.
//
&AtClient
Procedure BankAccountOnChange(Item)
	
	StructureData = GetDataBankAccountOnChange(
		Object.Date,
		Object.BankAccount,
		Object.CounterpartyAccount
	);
	
	If Object.CashCurrency = StructureData.CashCurrency Then
		Return;
	EndIf;
	
	Object.CounterpartyAccount		= StructureData.CounterpartyAccount;
	Object.CashCurrency				= StructureData.CashCurrency;
	CashCurrency 					= StructureData.CashCurrency;
	
	If Object.PaymentDetails.Count() > 0 Then
		Object.PaymentDetails[0].Contract	= Undefined;
	EndIf;
	
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesPaymentExpense.Salary") Then
		
		MessageText = NStr("en = 'The currency of the bank account has changed. The list of payslips will be cleared.'");		
		ShowMessageBox(New NotifyDescription("BankAccountOnChangeEnd", 
			ThisObject, 
			New Structure("StructureData, MessageText", StructureData, MessageText)), 
			MessageText);
			
		Return;
		
	EndIf;
	
	BankAccountOnChangeFragment(StructureData);
	
EndProcedure

&AtClient
Procedure BankAccountOnChangeEnd(AdditionalParameters) Export
	
	StructureData = AdditionalParameters.StructureData;
	MessageText = AdditionalParameters.MessageText;
	
	Object.PayrollPayment.Clear();
	
	BankAccountOnChangeFragment(StructureData);

EndProcedure

&AtClient
Procedure BankAccountOnChangeFragment(Val StructureData)
	
	Var MessageText;
	
	MessageText = NStr("en = 'The currency of the bank account has changed. Do you want to recalculate the document amount?'");
	RecalculateAmountsOnCashAssetsCurrencyRateChange(StructureData, MessageText);
	
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

#Region TabularSectionAttributeEventHandlers

// Procedure - BeforeDeletion event handler of PaymentDetails tabular section.
//
&AtClient
Procedure PaymentDetailsBeforeDelete(Item, Cancel)
	
	If Object.PaymentDetails.Count() <= 1 Then
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
	
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesPaymentExpense.Vendor") Then
		
		If TabularSectionRow.AdvanceFlag Then
			TabularSectionRow.Document = Undefined;
		Else
			TabularSectionRow.PlanningDocument = Undefined;
		EndIf;
		
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesPaymentExpense.ToCustomer") Then
		
		If TypeOf(TabularSectionRow.Document) = Type("DocumentRef.CashReceipt")
			OR TypeOf(TabularSectionRow.Document) = Type("DocumentRef.PaymentReceipt") Then
			
			TabularSectionRow.AdvanceFlag = True;
			ShowMessageBox(Undefined,
				NStr("en = 'Cannot cancel advance payment for this document type.'"));
			
		ElsIf TypeOf(TabularSectionRow.Document) <> Type("DocumentRef.ArApAdjustments") Then
			
			TabularSectionRow.AdvanceFlag = False;
			ShowMessageBox(Undefined,
				NStr("en = 'Cannot apply advance payment to this document type.'"));
			
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
		AND Object.OperationKind = PredefinedValue("Enum.OperationTypesPaymentExpense.Vendor") Then
		
		ShowMessageBox(, NStr("en = 'The current document will be the billing document for the advance payment..'"));
		
	Else
		
		ThisIsAccountsReceivable = Object.OperationKind = PredefinedValue("Enum.OperationTypesPaymentExpense.ToCustomer");
		
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

#EndRegion

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
	
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesPaymentExpense.ToCustomer") Then
		
		If TypeOf(TabularSectionRow.Document) = Type("DocumentRef.CashReceipt")
			OR TypeOf(TabularSectionRow.Document) = Type("DocumentRef.PaymentReceipt") Then
			
			TabularSectionRow.AdvanceFlag = True;
			
		Else
			
			TabularSectionRow.AdvanceFlag = False;
			
		EndIf;
		
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesPaymentExpense.Vendor") Then
		
		If TypeOf(TabularSectionRow.Document) = Type("DocumentRef.SupplierInvoice") Then
			
			SetExistsEPD(TabularSectionRow);
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure SetExistsEPD(TabularSectionRow)
	
	CheckDate = ?(ValueIsFilled(Object.PaymentDate), Object.PaymentDate, Object.Date);
	
	TabularSectionRow.ExistsEPD = ExistsEPD(TabularSectionRow.Document, CheckDate);
	
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

&AtServer
Procedure SetTaxInvoiceText()
	Items.TaxInvoiceText.Visible = Not WorkWithVAT.GetPostAdvancePaymentsBySourceDocuments(Object.Date, Object.Company)
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

&AtClient
Procedure HandleLoanContractChange()
	
	EmployeeLoanAgreementData = LoanContractOnChangeAtServer(Object.LoanContract, Object.Date);
	
	FillInformationAboutCreditLoanAtServer();
		
EndProcedure

&AtServerNoContext
Function LoanContractOnChangeAtServer(LoanContract, Date)
	
	DataStructure = New Structure;
	
	DataStructure.Insert("Currency", 			LoanContract.SettlementsCurrency);
	DataStructure.Insert("Counterparty",		LoanContract.Counterparty);
	DataStructure.Insert("Employee",			LoanContract.Employee);
	DataStructure.Insert("ThisIsLoanContract",	LoanContract.LoanKind = Enums.LoanContractTypes.EmployeeLoanAgreement);
		
	Return DataStructure;
	
EndFunction

&AtServer
Procedure FillInformationAboutCreditLoanAtServer()
	
	ConfigureLoanContractItem();
	
	If Object.LoanContract.IsEmpty() Then
		
		Items.LabelCreditContractInformation.Title	= NStr("en = '<Select a loan contract>'");
		Items.LabelRemainingDebtByCredit.Title		= "";
		
		Items.LabelCreditContractInformation.TextColor	= StyleColors.BorderColor;
		Items.LabelRemainingDebtByCredit.TextColor		= StyleColors.BorderColor;
		
		Return;
		
	EndIf;
	
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesPaymentExpense.IssueLoanToEmployee") Then
		FillInformationAboutLoanAtServer();
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesPaymentExpense.LoanSettlements") Then
		FillInformationAboutCreditAtServer();
	EndIf;
	
EndProcedure

&AtServer
Procedure FillInformationAboutCreditAtServer();
	    
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
	
	ResultsArray = Query.ExecuteBatch();
	
	If Object.LoanContract.LoanKind = Enums.LoanContractTypes.EmployeeLoanAgreement Then
		Multiplier = 1;
	Else
		Multiplier = -1;
	EndIf;
	
	SelectionSchedule = ResultsArray[0].Select();
	SelectionScheduleFutureMonth = ResultsArray[2].Select();
	
	LabelCreditContractInformationTextColor = StyleColors.BorderColor;
	LabelRemainingDebtByCreditTextColor = StyleColors.BorderColor;
	
	If SelectionScheduleFutureMonth.Next() Then
		
		If BegOfMonth(?(Object.Date = '00010101', CurrentDate(), Object.Date)) = BegOfMonth(SelectionScheduleFutureMonth.Period) Then
			PaymentDate = Format(SelectionScheduleFutureMonth.Period, "DLF=D");
		Else
			PaymentDate = Format(SelectionScheduleFutureMonth.Period, "DLF=D") + " (" + NStr("en = 'not in the current month'") + ")";
			LabelCreditContractInformationTextColor = StyleColors.FormTextColor;
		EndIf;
			
		LabelCreditContractInformation = StringFunctionsClientServer.SubstituteParametersInString( 
			NStr("en = 'Payment date: %1. Debt amount: %2. Interest: %3. Comission: %4 (%5).'"),
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
			NStr("en = 'Payment date: %1. Debt amount: %2. Interest: %3. Comission: %4 (%5).'"),
			PaymentDate,
			Format(SelectionSchedule.Principal, "NFD=2; NZ=0"),
			Format(SelectionSchedule.Interest, "NFD=2; NZ=0"),
			Format(SelectionSchedule.Commission, "NFD=2; NZ=0"),
			SelectionSchedule.CurrencyPresentation);
		
	Else
		
		LabelCreditContractInformation = NStr("en = 'Payment date: <not specified>'");
		
	EndIf;
		
	SelectionBalance = ResultsArray[1].Select();
	If SelectionBalance.Next() Then
		
		LabelRemainingDebtByCredit = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Debt balance: %1. Interest: %2. Comission: %3 (%4).'"),
			Format(Multiplier * SelectionBalance.PrincipalDebtCurBalance, "NFD=2; NZ=0"),
			Format(Multiplier * SelectionBalance.InterestCurBalance, "NFD=2; NZ=0"),
			Format(Multiplier * SelectionBalance.CommissionCurBalance, "NFD=2; NZ=0"),
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
	
	Items.LabelCreditContractInformation.Title		= LabelCreditContractInformation;
	Items.LabelRemainingDebtByCredit.Title			= LabelRemainingDebtByCredit;	
	Items.LabelCreditContractInformation.TextColor	= LabelCreditContractInformationTextColor;
	Items.LabelRemainingDebtByCredit.TextColor		= LabelRemainingDebtByCreditTextColor;
		
EndProcedure

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
Procedure FillInformationAboutLoanAtServer()

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
	
	Query.SetParameter("LoanContract",	Object.LoanContract);
	Query.SetParameter("Company",				Object.Company);
	
	QueryResult = Query.Execute();
	
	Selection = QueryResult.Select();
	
	If Selection.Next() Then
		
		LabelCreditContractInformation = NStr("en = 'Loan amount:'") + " " +
			Selection.Total +
			" (" + Selection.Currency + ")";
		
		If Selection.Total < Selection.PrincipalDebtCurReceipt Then
			
			LabelRemainingDebtByCredit = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Remaining amount to issue: %1 (%2). Issued %3 (%2).'"),
				Selection.Total - Selection.PrincipalDebtCurReceipt,
				Selection.Currency,
				Selection.PrincipalDebtCurReceipt);
			LabelRemainingDebtByCreditTextColor = StyleColors.SpecialTextColor;
			
		ElsIf Selection.Total = Selection.PrincipalDebtCurReceipt Then
			LabelRemainingDebtByCredit = NStr("en = 'Remaining amount to issue: 0 ('") + Selection.Currency + ").";
			LabelRemainingDebtByCreditTextColor = StyleColors.SpecialTextColor;
		Else
			LabelRemainingDebtByCredit = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Remaining amount to issue: %1 (%2). Issued %3 (%2).'"),
				Selection.Total - Selection.PrincipalDebtCurReceipt,
				Selection.Currency,
				Selection.PrincipalDebtCurReceipt);
		EndIf;
			
	Else
		LabelCreditContractInformation = NStr("en = 'Loan amount:'") + " " + Object.LoanContract.Total + " (" + Object.LoanContract.SettlementsCurrency + ").";
		LabelRemainingDebtByCredit = NStr("en = 'Remaining amount to issue:'") + " " + Object.LoanContract.Total + " (" + Object.LoanContract.SettlementsCurrency + ").";
	EndIf;
	
	Items.LabelCreditContractInformation.Title		= LabelCreditContractInformation;
	Items.LabelRemainingDebtByCredit.Title			= LabelRemainingDebtByCredit;	
	Items.LabelCreditContractInformation.TextColor	= LabelCreditContractInformationTextColor;
	Items.LabelRemainingDebtByCredit.TextColor		= LabelRemainingDebtByCreditTextColor;
	
EndProcedure

&AtServerNoContext
Function GetDefaultLoanContract(Document, Counterparty, Company, OperationKind)
	
	DocumentManager = Documents.LoanContract;
	
	LoanKindList = New ValueList;
	LoanKindList.Add(?(OperationKind = Enums.OperationTypesPaymentExpense.LoanSettlements, 
		Enums.LoanContractTypes.Borrowed,
		Enums.LoanContractTypes.EmployeeLoanAgreement));
	                                                   
	DefaultLoanContract = DocumentManager.ReceiveLoanContractByDefaultByCompanyLoanKind(Counterparty, Company, LoanKindList);
	
	Return DefaultLoanContract;
	
EndFunction

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
	
	Query.SetParameter("LoanContract",	Object.LoanContract);
	Query.SetParameter("Company",		Object.Company);
	Query.SetParameter("Ref",			Object.Ref);
	
	QueryResult = Query.Execute();
	
	Selection = QueryResult.Select();
	
	If Selection.Next() Then
		
		Object.CashCurrency = Selection.Currency;
		MessageText = "";
		
		If Selection.Total < Selection.PrincipalDebtCurReceipt Then
			MessageText = NStr("en = 'Issued under the loan contract'") + " " + 
				Selection.PrincipalDebtCurReceipt + 
				" (" + Selection.Currency + ").";
		ElsIf Selection.Total = Selection.PrincipalDebtCurReceipt Then
			MessageText = NStr("en = 'The complete amount has been already issued under the loan contract'") +
				Selection.PrincipalDebtCurReceipt +
				" (" + Selection.Currency + ").";
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

&AtServerNoContext
Function GetEmployeeDataOnChange(Employee, Date, Company)
	
	DataStructure = New Structure;
	
	DataStructure.Insert("LoanContract", Documents.LoanContract.ReceiveLoanContractByDefaultByCompanyLoanKind(Employee, Company));
	
	Return DataStructure;
	
EndFunction

&AtClient
Procedure EmployeeLoanAgreementOnChange(Item)
	HandleLoanContractChange();
EndProcedure

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
