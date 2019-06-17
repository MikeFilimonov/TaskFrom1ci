
#Region Variables

&AtClient
Var ThisIsNewRow;

#EndRegion

#Region FormEventHandlers

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	FillAddedColumns();
EndProcedure

&AtClient
Procedure Attachable_SetPictureForComment()
	
	DriveClientServer.SetPictureForComment(Items.GroupAdditional, Object.Comment);
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	AdjustmentAmount = Object.AdjustmentAmount;
	
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesDebitNote.PurchaseReturn")
		AND AdjustmentAmount = 0 Then
		CommonUseClientServer.MessageToUser(NStr("en = 'Fill in the quantity of goods to return.'"),
											,,, Cancel);
	EndIf;
	
	If Object.OperationKind <> PredefinedValue("Enum.OperationTypesDebitNote.PurchaseReturn") Then
		AdjustmentAmount = AdjustmentAmount	+ ?(Object.AmountIncludesVAT, 0, Object.VATAmount);
	EndIf;
	
	If Object.AmountAllocation.Count() <> 0
		AND Object.AmountAllocation.Total("OffsetAmount") <> AdjustmentAmount Then
		
		Cancel = True;
		Notify = New NotifyDescription("FillAllocationEnd", ThisObject);
		ShowQueryBox(Notify, 
					 NStr("en = 'The total of amount allocation does not match the amount of the document.
					      |Do you want to refill the tabular section?'"),
					 QuestionDialogMode.YesNo, 0);
	EndIf;
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	// StandardSubsystems.Properties
	PropertiesManagement.BeforeWriteAtServer(ThisForm, CurrentObject);
	// End StandardSubsystems.Properties
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(SelectedValue, ChoiceSource)
	
	If ChoiceSource.FormName = "Document.TaxInvoiceReceived.Form.DocumentForm" Then
		TaxInvoiceText = SelectedValue;
	ElsIf ChoiceSource.FormName = "CommonForm.ProductGLAccounts" Then
		GLAccountsChoiceProcessingAtClient(SelectedValue);
	EndIf;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "RefreshTaxInvoiceText" 
		AND TypeOf(Parameter) = Type("Structure") 
		AND Not Parameter.BasisDocuments.Find(Object.Ref) = Undefined Then
		TaxInvoiceText = Parameter.Presentation;
	ElsIf EventName = "SerialNumbersSelection"
		AND ValueIsFilled(Parameter) 
		// Form owner checkup
		AND Source = UUID Then
		GetSerialNumbersFromStorage(Parameter.AddressInTemporaryStorage, Parameter.RowKey);
	EndIf;
	
	// Properties subsystem
	If PropertiesManagementClient.ProcessAlerts(ThisForm, EventName, Parameter) Then
		UpdateAdditionalAttributesItems();
	EndIf;
	
EndProcedure

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	DriveServer.CheckBasis(Object, Parameters.Basis, Cancel);
	
	DriveServer.FillDocumentHeader(
		Object,
		,
		Parameters.CopyingValue,
		Parameters.Basis,
		PostingIsAllowed,
		Parameters.FillingValues);
	
	// Form attributes setting.
	DocumentDate = Object.Date;
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentDate();
	EndIf;
	
	ParentCompany = DriveServer.GetCompany(Object.Company);
	Contract = Object.Contract;
	
	If ValueIsFilled(Contract) Then
		SettlementCurrency = CommonUse.ObjectAttributeValue(Contract, "SettlementsCurrency");
	EndIf;
	
	If Not ValueIsFilled(Object.Ref)
		AND Not ValueIsFilled(Parameters.CopyingValue) Then
		SetDefaultValuesForGLAccount();
	EndIf;

	FunctionalCurrency				= DriveReUse.GetNationalCurrency();
	StructureByCurrency				= InformationRegisters.ExchangeRates.GetLast(Object.Date, New Structure("Currency", FunctionalCurrency));
	ExchangeRateNationalCurrency	= StructureByCurrency.ExchangeRate;
	MultiplicityNationalCurrency	= StructureByCurrency.Multiplicity;
	
	SetAccountingPolicyValues();
	
	// Generate price and currency label.
	ForeignExchangeAccounting	= GetFunctionalOption("ForeignExchangeAccounting");
	LabelStructure		= New Structure();
	LabelStructure.Insert("DocumentCurrency",				Object.DocumentCurrency);
	LabelStructure.Insert("SettlementsCurrency",			SettlementCurrency);
	LabelStructure.Insert("Rate",							Object.ExchangeRate);
	LabelStructure.Insert("RateNationalCurrency",			ExchangeRateNationalCurrency);
	LabelStructure.Insert("AmountIncludesVAT",				Object.AmountIncludesVAT);
	LabelStructure.Insert("ForeignExchangeAccounting",	ForeignExchangeAccounting);
	LabelStructure.Insert("VATTaxation",					Object.VATTaxation);
	LabelStructure.Insert("RegisteredForVAT",				RegisteredForVAT);
	
	PricesAndCurrency	= DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
	
	FillAddedColumns();
	
	SendGoodsOnConsignment 	= GetFunctionalOption("SendGoodsOnConsignment");
	UseProductionSubsystem 			= GetFunctionalOption("UseProductionSubsystem");

	UseTaxInvoice					= WorkWithVAT.GetUseTaxInvoiceForPostingVAT(Object.Date, Object.Company);
	WorkWithVAT.SetTextAboutTaxInvoiceReceived(ThisForm);
	
	DriveClientServer.SetPictureForComment(Items.GroupAdditional, Object.Comment);
	
	// Serial numbers
	UseSerialNumbersBalance = WorkWithSerialNumbers.UseSerialNumbersBalance();
	Items.InventorySerialNumbers.ReadOnly = UseGoodsReturnToSupplier;
	
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
	PropertiesManagement.OnCreateAtServer(ThisForm, Object, "AdditionalAttributesGroup");
	// End StandardSubsystems.Properties
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	ClosingDates.ObjectOnReadAtServer(ThisForm, CurrentObject);
	FillAddedColumns();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	FormManagement();
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesDebitNote.PurchaseReturn") Then
		CalculateTotal();
	EndIf;
	
	If Parameters.Key.IsEmpty() Then
		
		WorkWithVATClient.ShowReverseChargeNotSupportedMessage(Object.VATTaxation);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	If TypeOf(FormOwner) = Type("ManagedForm") Then
		
		If Find(FormOwner.FormName, "CashVoucher") > 0
			OR Find(FormOwner.FormName, "PaymentExpense") > 0 Then
			
			StructureParameter = New Structure;
			StructureParameter.Insert("Ref", Object.Ref);
			StructureParameter.Insert("Number", Object.Number);
			StructureParameter.Insert("Date", Object.Date);
			StructureParameter.Insert("BasisDocument", Object.BasisDocument);
			
			Notify("RefreshDebitNoteText", StructureParameter);
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormItemEventHandlers

&AtClient
Procedure BasisDocumentStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("Item", Item);
	
	DocumentTypes = New ValueList;
	
	If UseGoodsReturnToSupplier Then
		DocumentTypes.Add("GoodsReturn", NStr("en = 'Goods return'"));
	EndIf;
	
	DocumentTypes.Add("SupplierInvoice",	NStr("en = 'Supplier invoice'"));
	DocumentTypes.Add("CashVoucher",		NStr("en = 'Cash voucher'"));
	DocumentTypes.Add("PaymentExpense",		NStr("en = 'Bank payment'"));
	
	Descr = New NotifyDescription("BasisDocumentSelectEnd", ThisObject, AdditionalParameters);
	DocumentTypes.ShowChooseItem(Descr, NStr("en = 'Select document type'"));
	
EndProcedure

&AtClient
Procedure BasisDocumentChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	If TypeOf(SelectedValue) <> Type("DocumentRef.SupplierInvoice")
		OR TypeOf(SelectedValue) <> Type("DocumentRef.GoodsReturn") Then
		
		Object.BasisDocument = SelectedValue;
		FillByDocument(Object.BasisDocument);
		
		If Object.VATTaxation = PredefinedValue("Enum.VATTaxationTypes.NotSubjectToVAT") Then
			ClearVATAmount();
		EndIf;
		
		FormManagement();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure BasisDocumentSelectEnd(SelectedElement, AdditionalParameters) Export
	
	If SelectedElement = Undefined Then
		Return;
	EndIf;
	
	Filter = New Structure();
	Filter.Insert("Company",		Object.Company);
	Filter.Insert("Counterparty",	Object.Counterparty);
	
	If SelectedElement.Value <> "CashVoucher" AND SelectedElement.Value <> "PaymentExpense" Then
		Filter.Insert("Contract", Object.Contract);
	EndIf;
	
	ParametersStructure = New Structure();
	If SelectedElement.Value = "GoodsReturn" Then
		ParametersStructure.Insert("PurposeUseKey",	"ToSupplier");
	EndIf;
	ParametersStructure.Insert("Filter", Filter);
	
	FillByBasisEnd = New NotifyDescription("FillByBasisEnd", ThisObject, AdditionalParameters);
	OpenForm("Document." + SelectedElement.Value + ".ChoiceForm", ParametersStructure, AdditionalParameters.Item);
	
EndProcedure

&AtClient
Procedure CommentOnChange(Item)
	
	AttachIdleHandler("Attachable_SetPictureForComment", 0.5, True);
	
EndProcedure

&AtServer
Procedure CompanyOnChangeAtServer()
	
	Object.Contract = GetContractByDefault(Object.Ref, Object.Counterparty, Object.Company, Object.OperationKind);
	ContractBeforeChange = Contract;
	Contract = Object.Contract;
	
	If ContractBeforeChange <> Object.Contract Then
		
		ContractData = GetDataContractOnChange(Object.Date, Object.DocumentCurrency, Object.Contract);
		SettlementCurrency = ContractData.SettlementsCurrency;
		
		If ValueIsFilled(Object.Contract) Then
			ContractValues = ContractData.SettlementsCurrencyRateRepetition;
			Object.ExchangeRate = ?(ContractValues.ExchangeRate = 0, 1, ContractValues.ExchangeRate);
			Object.Multiplicity = ?(ContractValues.Multiplicity = 0, 1, ContractValues.Multiplicity);
		EndIf;
		
		Object.DocumentCurrency = SettlementCurrency;
		
	EndIf;
	
	FillVATRateByCompanyVATTaxation();	
	SetAccountingPolicyValues();
	
	// Generate price and currency label.
	LabelStructure = New Structure;
	LabelStructure.Insert("DocumentCurrency",				Object.DocumentCurrency);
	LabelStructure.Insert("SettlementsCurrency",			SettlementCurrency);
	LabelStructure.Insert("Rate",							Object.ExchangeRate);
	LabelStructure.Insert("RateNationalCurrency",			ExchangeRateNationalCurrency);
	LabelStructure.Insert("AmountIncludesVAT",				Object.AmountIncludesVAT);
	LabelStructure.Insert("ForeignExchangeAccounting",		ForeignExchangeAccounting);
	LabelStructure.Insert("VATTaxation",					Object.VATTaxation);
	LabelStructure.Insert("RegisteredForVAT",				RegisteredForVAT);
	
	PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
	
	FillAddedColumns(True);
	
EndProcedure

&AtClient
Procedure CompanyOnChange(Item)
	
	CompanyOnChangeAtServer();
	FormManagement();
	
EndProcedure

&AtClient
Procedure ContractOnChange(Item)
	
	ProcessContractChange();
	FormManagement();
	
EndProcedure

&AtClient
Procedure ContractStartChoice(Item, ChoiceData, StandardProcessing)
	
	If Not ValueIsFilled(Object.OperationKind) Then
		Return;
	EndIf;
	
	FormParameters = GetChoiceFormOfContractParameters(Object.Ref, Object.Company, Object.Counterparty, Object.Contract, Object.OperationKind);
	If FormParameters.ControlContractChoice Then
		
		StandardProcessing = False;
		OpenForm("Catalog.CounterpartyContracts.Form.ChoiceForm", FormParameters, Item);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CounterpartyOnChange(Item)
	
	Object.Contract = DriveServer.GetContractByDefault(Object.Ref, Object.Counterparty, Object.Company, Object.OperationKind);
	
EndProcedure

&AtClient
Procedure DateOnChange(Item)
	
	// Date change event processor.
	DateBeforeChange	= DocumentDate;
	DocumentDate		= Object.Date;
	
	If Object.Date <> DateBeforeChange Then
		StructureData = GetDataDateOnChange(DateBeforeChange, SettlementCurrency);
		
		If StructureData.DATEDIFF <> 0 Then
			Object.Number = "";
		EndIf;
		
		If ValueIsFilled(SettlementCurrency) Then
			RecalculateExchangeRateMultiplicitySettlementCurrency(StructureData);
		EndIf;
		
		FormManagement();
		
	EndIf;

EndProcedure

&AtClient
Procedure AdjustmentAmountOnChange(Item)
	
	CalculateTotalVATAmount();
	
EndProcedure

&AtClient
Procedure EditPricesAndCurrency(Item, StandardProcessing)
	
	StandardProcessing = False;
	ProcessChangesOnButtonPricesAndCurrencies(Object.DocumentCurrency);
	Modified = True;
	
EndProcedure

&AtClient
Procedure OperationKindOnChange(Item)
	
	Object.BasisDocument = PredefinedValue("Document.SalesInvoice.EmptyRef");
	Object.DebitedTransactions.Clear();
	Object.Inventory.Clear();
	Object.AmountAllocation.Clear();
	
	FormManagement();
	
	SetDefaultValuesForGLAccount();
	
EndProcedure

&AtClient
Procedure TaxInvoiceTextClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	WorkWithVATClient.OpenTaxInvoice(ThisForm, True);
	
EndProcedure

&AtClient
Procedure VATRateOnChange(Item)
	
	CalculateTotalVATAmount();
	
EndProcedure

&AtServer
Procedure StructuralUnitOnChangeAtServer()
	FillAddedColumns(True);
EndProcedure

&AtClient
Procedure StructuralUnitOnChange(Item)
	StructuralUnitOnChangeAtServer();
EndProcedure

#EndRegion

#Region FormItemEventHandlersFormTableDebitedTransactions

&AtClient
Procedure DebitedTransactionsDocumentOnChange(Item)
	
	CurrentData = Items.DebitedTransactions.CurrentData;
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("CurrentData",		CurrentData);
	AdditionalParameters.Insert("MultipleChoice",	False);

	FillDebitTransaction(CurrentData.Document, AdditionalParameters);
	
EndProcedure

&AtClient
Procedure DebitedTransactionsDocumentStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	DebitedTransactionsStartChoice(False, Item);
	
EndProcedure

&AtClient
Procedure DebitedTransactionsSelectEnd(SelectedElement, AdditionalParameters) Export
	
	If SelectedElement = Undefined Then
		Return;
	EndIf;
	
	Filter = New Structure();
	Filter.Insert("Company",		Object.Company);
	Filter.Insert("Counterparty",	Object.Counterparty);
	Filter.Insert("Contract",		Object.Contract);
	
	ParametersStructure = New Structure();
	ParametersStructure.Insert("MultipleChoice",	AdditionalParameters.MultipleChoice);
	ParametersStructure.Insert("Filter",			Filter);
	
	FillDebitTransaction = New NotifyDescription("FillDebitTransaction", ThisObject, AdditionalParameters);
	If AdditionalParameters.MultipleChoice Then
		OpenedForm = OpenForm("Document." + SelectedElement.Value + ".ChoiceForm", ParametersStructure,,,,, FillDebitTransaction);
	Else
		OpenedForm = OpenForm("Document." + SelectedElement.Value + ".ChoiceForm", ParametersStructure,AdditionalParameters.Item);
	EndIf;
	
EndProcedure

&AtClient
Procedure DebitedTransactionsStartChoice(MultipleChoice, Item = Undefined)
	
	DocumentTypes = New ValueList;
	DocumentTypes.Add("AdditionalExpenses",	NStr("en = 'Landed costs'"));
	DocumentTypes.Add("DebitNote",			NStr("en = 'Debit note'"));
	DocumentTypes.Add("ExpenseReport",		NStr("en = 'Expense report'"));
	DocumentTypes.Add("SupplierInvoice",	NStr("en = 'Supplier invoice'"));
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("Item",				Item);
	AdditionalParameters.Insert("MultipleChoice",	MultipleChoice);
	
	Descr = New NotifyDescription("DebitedTransactionsSelectEnd", ThisObject, AdditionalParameters);
	DocumentTypes.ShowChooseItem(Descr, NStr("en = 'Select document type'"));
	
EndProcedure

&AtClient
Procedure FillDebitTransaction(Documents, AdditionalParameters) Export
	
	AddDebitTransactionsAtServer(Documents);
	
	For Each TableRow In DebitedTransactionData Do
		
		If DebitedTransactionData.IndexOf(TableRow) > 0 Or AdditionalParameters.MultipleChoice Then
			NewRow = Object.DebitedTransactions.Add();
		ElsIf AdditionalParameters.Property("CurrentData") Then
			NewRow = AdditionalParameters.CurrentData;
		EndIf;
		
		FillPropertyValues(NewRow, TableRow);
		
	EndDo;
	
	DebitedTransactionData.Clear();
	
EndProcedure

&AtServer
Procedure AddDebitTransactionsAtServer(Documents)
	
	If Documents = Undefined Then 
		Return;
	EndIf;
	
	If TypeOf(Documents) = Type("Array") Then
		DocumentType = Documents[0].Metadata().Name;
	Else
		DocumentType = Documents.Metadata().Name;
	EndIf;
	
	Query = New Query;
	Query.SetParameter("Documents", Documents);
	
	Query.Text = 
	"SELECT
	|	PurchasesTurnovers.Recorder AS Document,
	|	PurchasesTurnovers.VATRate AS VATRate,
	|	CASE
	|		WHEN PurchasesTurnovers.AmountTurnover + PurchasesTurnovers.VATAmountTurnover > 0
	|			THEN PurchasesTurnovers.AmountTurnover + PurchasesTurnovers.VATAmountTurnover
	|		ELSE -(PurchasesTurnovers.AmountTurnover + PurchasesTurnovers.VATAmountTurnover)
	|	END AS Amount,
	|	CASE
	|		WHEN PurchasesTurnovers.VATAmountTurnover > 0
	|			THEN PurchasesTurnovers.VATAmountTurnover
	|		ELSE -PurchasesTurnovers.VATAmountTurnover
	|	END AS VATAmount
	|FROM
	|	AccumulationRegister.Purchases.Turnovers(, , Recorder, ) AS PurchasesTurnovers
	|WHERE
	|	PurchasesTurnovers.Recorder IN(&Documents)
	|	AND &DocumentCondition
	|
	|ORDER BY
	|	PurchasesTurnovers.Recorder,
	|	PurchasesTurnovers.VATRate
	|AUTOORDER";
	
	Query.Text = StrReplace(Query.Text, "&DocumentCondition", "PurchasesTurnovers.Recorder REFS Document." + DocumentType);
	
	ValueToFormAttribute(Query.Execute().Unload(), "DebitedTransactionData");
	
EndProcedure

#EndRegion

#Region FormItemEventHandlersFormTableInventory

&AtClient
Procedure InventoryAfterDeleteRow(Item)
	CalculateTotal();
	CalculateTotalVATAmount();
EndProcedure

&AtClient
Procedure InventoryAmountAdjustedOnChange(Item)
	
	CurrentData = Items.Inventory.CurrentData;	
	CalculateVATAmount(CurrentData, CurrentData.Amount);
	CalculateTotal(CurrentData);
	CalculateTotalVATAmount();
	
EndProcedure

&AtClient
Procedure InventoryBeforeDeleteRow(Item, Cancel)
	
	CurrentData = Items.Inventory.CurrentData;
	WorkWithSerialNumbersClientServer.DeleteSerialNumbersByConnectionKey(Object.SerialNumbers, CurrentData,,UseSerialNumbersBalance);
	
EndProcedure

&AtClient
Procedure InventorySelection(Item, SelectedRow, Field, StandardProcessing)
	
	If Field.Name = "InventoryGLAccounts" Then
		StandardProcessing = False;
		OpenProductGLAccountsForm(SelectedRow, "Inventory");
	EndIf;
	
EndProcedure

&AtClient
Procedure InventoryOnActivateCell(Item)
	
	If Items.Inventory.CurrentData = Undefined Then
		Return;
	EndIf;
	
	If ThisIsNewRow Then
		TableCurrentColumn = Items.Inventory.CurrentItem;
		If TableCurrentColumn.Name = "InventoryGLAccounts"
			And Not Items.Inventory.CurrentData.GLAccountsFilled Then
			SelectedRow = Items.Inventory.CurrentRow;
			OpenProductGLAccountsForm(SelectedRow, "Inventory");
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure InventoryOnStartEdit(Item, NewRow, Copy)
	
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
Procedure InventoryGLAccountsStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	SelectedRow = Items.Inventory.CurrentRow;
	OpenProductGLAccountsForm(SelectedRow, "Inventory");
	
EndProcedure

&AtClient
Procedure InventoryReturnQuantityOnChange(Item)
	
	CurrentData = Items.Inventory.CurrentData;
	CurrentData.Amount = ?(CurrentData.InitialQuantity = 0, 0, CurrentData.InitialAmount / CurrentData.InitialQuantity * CurrentData.Quantity);
	
	CalculateVATAmount(CurrentData, CurrentData.Amount);
	CalculateTotal(CurrentData);
	CalculateTotalVATAmount();
	
	// Serial numbers
	If UseSerialNumbersBalance <> Undefined Then
		WorkWithSerialNumbersClientServer.UpdateSerialNumbersQuantity(Object, CurrentData);
	EndIf;
	
EndProcedure

&AtClient
Procedure InventorySerialNumbersStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	OpenSerialNumbersSelection();
	
EndProcedure

#EndRegion

#Region FormItemEventHandlersFormTableAmountAllocation

&AtClient
Procedure AmountAllocationDocumentOnChange(Item)
	
	RunActionsOnAccountsDocumentChange();
	
EndProcedure

&AtClient
Procedure AmountAllocationDocumentStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	TabularSectionRow = Items.AmountAllocation.CurrentData;
	
	If TabularSectionRow.AdvanceFlag Then
		
		ShowMessageBox(, NStr("en = 'No need to select a document in case of advance recognition.'"));
		
	Else
		
		StructureFilter = New Structure();
		StructureFilter.Insert("Company",			Object.Company);
		StructureFilter.Insert("Counterparty", 		Object.Counterparty);
		StructureFilter.Insert("DocumentCurrency",	Object.DocumentCurrency);
		
		If ValueIsFilled(TabularSectionRow.Contract) Then
			StructureFilter.Insert("Contract", TabularSectionRow.Contract);
		EndIf;
		
		ParameterStructure = New Structure("Filter, ThisIsAccountsReceivable, DocumentType",
											StructureFilter,
											False,
											TypeOf(Object.Ref));
		
		OpenForm("CommonForm.SelectDocumentOfSettlements", ParameterStructure, Item);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure AmountAllocationDocumentChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	StandardProcessing = False;
	
	ProcessAccountsDocumentSelection(SelectedValue);
	
EndProcedure

&AtClient
Procedure FillAllocationEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.No Then
		Return;
	EndIf;
	
	Object.AmountAllocation.Clear();
	FillAmountAllocation();
	
EndProcedure

&AtClient
Procedure AmountAllocationPaymentAmountOnChange(Item)
	
	TabularSectionRow = Items.AmountAllocation.CurrentData;
	CalculateVATAmount(TabularSectionRow, TabularSectionRow.OffsetAmount);
	
EndProcedure

&AtClient
Procedure AmountAllocationVATRateOnChange(Item)
	
	TabularSectionRow = Items.AmountAllocation.CurrentData;
	CalculateVATAmount(TabularSectionRow, TabularSectionRow.OffsetAmount);
	
EndProcedure

&AtServer
Procedure FillAmountAllocation()
	
	Document = FormAttributeToValue("Object");
	Document.FillAmountAllocation();
	ValueToFormAttribute(Document, "Object");
	Modified = True;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure DebitedTransactionsSelect(Command)
	
	DebitedTransactionsStartChoice(True);
	
EndProcedure

&AtClient
Procedure FillAllocation(Command)
	
	If Object.AdjustmentAmount = 0 Then
		ShowMessageBox(Undefined, NStr("en = 'Please specify the amount.'"));
		Return;
	EndIf;
	
	Response = Undefined;
	
	If Object.AmountAllocation.Count() <> 0 Then
		ShowQueryBox(New NotifyDescription("FillAllocationEnd", ThisObject), 
						NStr("en = 'Allocation amount will be completely refilled. Do you want to continue?'"),
						QuestionDialogMode.YesNo);
	Else
		FillAmountAllocation();
	EndIf;
	
EndProcedure

&AtClient
Procedure FillByBasis(Command)
	
	ShowQueryBox(New NotifyDescription("FillByBasisEnd", ThisObject),
					NStr("en = 'Do you want to refill the debit note?'"), QuestionDialogMode.YesNo, 0);
	
EndProcedure

&AtClient
Procedure FillByPeriod(Command)
	
	Notify = New NotifyDescription("FillByPeriodEnd", ThisObject);
	
	If Object.DebitedTransactions.Count() = 0 Then
		ExecuteNotifyProcessing(Notify, DialogReturnCode.Yes); 
	Else
		ShowQueryBox(Notify, NStr("en = 'The tabular section will be refilled. Do you want to continue?'"), QuestionDialogMode.YesNo, 0);
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
Procedure Attachable_EditContentOfProperties(Command)
	
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
Procedure CalculateTotal(CurrentData = Undefined) 
	
	If CurrentData <> Undefined Then 
		CurrentData.Total = CurrentData.Amount + ?(Object.AmountIncludesVAT, 0, CurrentData.VATAmount);
	EndIf;
	Object.AdjustmentAmount = Object.Inventory.Total("Total");
	DocumentSubtotal = Object.Inventory.Total("Total") - Object.Inventory.Total("VATAmount");
	
EndProcedure

&AtClient
Procedure CalculateTotalVATAmount() 
    
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesDebitNote.PurchaseReturn") Then
		Object.VATAmount = Object.Inventory.Total("VATAmount");
	Else
		CalculateVATAmount(Object, Object.AdjustmentAmount);		
	EndIf;
	
EndProcedure

&AtClient
Procedure CalculateVATAmount(CurrentData, Amount) 
    
	Rate = DriveReUse.GetVATRateValue(CurrentData.VATRate);
	If Object.AmountIncludesVAT Then
		CurrentData.VATAmount = Amount - (Amount) / ((Rate + 100) / 100);
	Else
		CurrentData.VATAmount = Amount * Rate / 100;
	EndIf;

EndProcedure

&AtClient
Procedure ClearVATAmount() 
	
	Object.VATAmount = 0;
	
	For Each Row In Object.Inventory Do
		Row.VATAmount = 0;
	EndDo;
	
	For Each Row In Object.AmountAllocation Do
		Row.VATAmount = 0;
	EndDo;
	
EndProcedure

&AtClient
Procedure FillByBasisEnd(Result, AdditionalParameters) Export
    
    Response = Result;
    If Response = DialogReturnCode.Yes Then
		FillByDocument(Object.BasisDocument);
		
		If Object.VATTaxation = PredefinedValue("Enum.VATTaxationTypes.NotSubjectToVAT") Then
			ClearVATAmount();
		EndIf;
		
		FormManagement();
		FillAddedColumns();
	EndIf;
	
EndProcedure

&AtServer
Procedure FillByDocument(BasisDocument)
	
	Document = FormAttributeToValue("Object");
	Document.Filling(BasisDocument, True);
	ValueToFormAttribute(Document, "Object");
	Modified = True;
	
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
	
	If Object.VATTaxation = PredefinedValue("Enum.VATTaxationTypes.SubjectToVAT") Then
		
		DefaultVATRate = InformationRegisters.AccountingPolicy.GetDefaultVATRate(Object.Date, Object.Company);
		
		For Each TabularSectionRow In Object.Inventory Do
			
			If ValueIsFilled(TabularSectionRow.Products.VATRate) Then
				TabularSectionRow.VATRate = TabularSectionRow.Products.VATRate;
			Else
				TabularSectionRow.VATRate = DefaultVATRate;
			EndIf;	
			
			VATRate = DriveReUse.GetVATRateValue(TabularSectionRow.VATRate);
			TabularSectionRow.VATAmount = ?(Object.AmountIncludesVAT, 
									  		TabularSectionRow.InitialAmount - (TabularSectionRow.InitialAmount) / ((VATRate + 100) / 100),
									  		TabularSectionRow.InitialAmount * VATRate / 100);
			TabularSectionRow.Total		= TabularSectionRow.InitialAmount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
			
		EndDo;
		
		For Each TabularSectionRow In Object.AmountAllocation Do
		
			TabularSectionRow.VATRate		= DefaultVATRate;
			TabularSectionRow.VATAmount		= ?(Object.AmountIncludesVAT, 
										  		TabularSectionRow.OffsetAmount - (TabularSectionRow.OffsetAmount) / ((VATRate + 100) / 100),
										  		TabularSectionRow.OffsetAmount * VATRate / 100);
			TabularSectionRow.OffsetAmount	= TabularSectionRow.OffsetAmount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
			
		EndDo;
		
		If Object.OperationKind = PredefinedValue("Enum.OperationTypesDebitNote.PurchaseReturn") Then
			Object.VATAmount = Object.Inventory.Total("VATAmount");
		Else
			
			Rate = DriveReUse.GetVATRateValue(Object.VATRate);
			If Object.AmountIncludesVAT Then
				Object.VATAmount = Object.AdjustmentAmount - (Object.AdjustmentAmount) / ((Rate + 100) / 100);
			Else
				Object.VATAmount = Object.AdjustmentAmount * Rate / 100;
			EndIf;
			
		EndIf;
		
	Else
		
		If Object.VATTaxation = PredefinedValue("Enum.VATTaxationTypes.NotSubjectToVAT") Then
			DefaultVATRate = Catalogs.VATRates.Exempt;
		Else
			DefaultVATRate = Catalogs.VATRates.ZeroRate;
		EndIf;	
		
		Object.VATRate = DefaultVATRate;
		Object.VATAmount = 0;
		
		For Each TabularSectionRow In Object.Inventory Do
		
			TabularSectionRow.VATRate	= DefaultVATRate;
			TabularSectionRow.VATAmount = 0;
			TabularSectionRow.Total		= TabularSectionRow.InitialAmount;
			
		EndDo;
		
		For Each TabularSectionRow In Object.AmountAllocation Do
		
			TabularSectionRow.OffsetAmount	= TabularSectionRow.OffsetAmount - ?(Object.AmountIncludesVAT, TabularSectionRow.VATAmount, 0);
			TabularSectionRow.VATRate		= DefaultVATRate;
			TabularSectionRow.VATAmount		= 0;
			
		EndDo;
		
	EndIf;	
	
EndProcedure

&AtClient
Procedure FormManagement()
	
	VisibleFlags = GetFlagsForFormItemsVisible(Object.OperationKind, Object.VATTaxation);
	
	ThisIsPurchaseReturn	= VisibleFlags.ThisIsPurchaseReturn;
	SubjectToVAT			= VisibleFlags.SubjectToVAT;
	IsDiscountReceived		= VisibleFlags.IsDiscountReceived;
	BasisDocumentVisible	= (ThisIsPurchaseReturn OR IsDiscountReceived);
	
	CommonUseClientServer.SetFormItemProperty(Items, "GroupInventory", 							"Visible", ThisIsPurchaseReturn);
	CommonUseClientServer.SetFormItemProperty(Items, "AdjustmentAmount", 						"ReadOnly", ThisIsPurchaseReturn);
	CommonUseClientServer.SetFormItemProperty(Items, "GroupBasisDocument", 						"Visible", BasisDocumentVisible);
	CommonUseClientServer.SetFormItemProperty(Items, "GLAccount", 								"Visible", Not ThisIsPurchaseReturn);
	CommonUseClientServer.SetFormItemProperty(Items, "AdjustmentAmount", 						"Enabled", Not ThisIsPurchaseReturn);
	CommonUseClientServer.SetFormItemProperty(Items, "GroupDebitedTransactions", 				"Visible", Not ThisIsPurchaseReturn);
	CommonUseClientServer.SetFormItemProperty(Items, "VAT", 									"Visible", Not ThisIsPurchaseReturn AND SubjectToVAT);
	CommonUseClientServer.SetFormItemProperty(Items, "InventoryVATRate", 						"Visible", SubjectToVAT);
	CommonUseClientServer.SetFormItemProperty(Items, "InventoryVATAmount",						"Visible", SubjectToVAT);
	CommonUseClientServer.SetFormItemProperty(Items, "InventoryTotalVATAmount",					"Visible", SubjectToVAT);
	CommonUseClientServer.SetFormItemProperty(Items, "AmountAllocationVATRate", 				"Visible", SubjectToVAT);
	CommonUseClientServer.SetFormItemProperty(Items, "AmountAllocationVATAmount",				"Visible", SubjectToVAT);
	CommonUseClientServer.SetFormItemProperty(Items, "AmountAllocationTotalVATAmount",			"Visible", SubjectToVAT);
	CommonUseClientServer.SetFormItemProperty(Items, "TaxInvoiceText", 							"Visible", 	UseTaxInvoice AND SubjectToVAT);
	CommonUseClientServer.SetFormItemProperty(Items, "Totals", 									"Visible", 	ThisIsPurchaseReturn);
	CommonUseClientServer.SetFormItemProperty(Items, "Warehouse",								"Visible",	ThisIsPurchaseReturn 
																									AND Not UseGoodsReturnToSupplier);
	CommonUseClientServer.SetFormItemProperty(Items, "FormDocumentGoodsReturnCreateBasedOn",	"Visible",	ThisIsPurchaseReturn
																									AND UseGoodsReturnToSupplier);
	
EndProcedure

&AtServerNoContext
Function GetFlagsForFormItemsVisible(OperationKind, VATTaxation)
	
	VisibleFlags = New Structure;
	VisibleFlags.Insert("ThisIsPurchaseReturn", (OperationKind = Enums.OperationTypesDebitNote.PurchaseReturn));
	VisibleFlags.Insert("IsDiscountReceived", (OperationKind = Enums.OperationTypesDebitNote.DiscountReceived));
	VisibleFlags.Insert("SubjectToVAT", (VATTaxation <> Enums.VATTaxationTypes.NotSubjectToVAT));
	
	Return VisibleFlags;
	
EndFunction

// It gets counterparty contract selection form parameter structure.
//
&AtServerNoContext
Function GetChoiceFormOfContractParameters(Document, Company, Counterparty, Contract, OperationKind)
	
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
Function GetContractByDefault(Document, Counterparty, Company, OperationKind)
	
	If Counterparty.DoOperationsByContracts = False Then
		Return Counterparty.ContractByDefault;
	EndIf;
	
	ManagerOfCatalog = Catalogs.CounterpartyContracts;
	
	ContractTypesList = ManagerOfCatalog.GetContractKindsListForDocument(Document, OperationKind);
	ContractByDefault = ManagerOfCatalog.GetDefaultContractByCompanyContractKind(Counterparty, Company, ContractTypesList);
	
	Return ContractByDefault;
	
EndFunction

&AtServerNoContext
Function GetDataContractOnChange(Date, DocumentCurrency, Contract)
	
	StructureData = New Structure();
	
	StructureData.Insert("ContractDescription", 				Contract.Description);
	StructureData.Insert("SettlementsCurrency",					Contract.SettlementsCurrency);
	StructureData.Insert("SettlementsCurrencyRateRepetition",	InformationRegisters.ExchangeRates.GetLast(
																	Date, New Structure("Currency", Contract.SettlementsCurrency)));
	StructureData.Insert("PriceKind", 							Contract.PriceKind);
	StructureData.Insert("DiscountMarkupKind", 					Contract.DiscountMarkupKind);
	StructureData.Insert("SettlementsInStandardUnits",			Contract.SettlementsInStandardUnits);
	StructureData.Insert("AmountIncludesVAT", 					?(ValueIsFilled(Contract.PriceKind), Contract.PriceKind.PriceIncludesVAT, Undefined));
	
	Return StructureData;
	
EndFunction

&AtServer
Function GetDataDateOnChange(DateBeforeChange, SettlementsCurrency)
	
	DATEDIFF = DriveServer.CheckDocumentNumber(Object.Ref, Object.Date, DateBeforeChange);
	CurrencyRateRepetition = InformationRegisters.ExchangeRates.GetLast(Object.Date, New Structure("Currency", SettlementCurrency));
	SetAccountingPolicyValues();
	
	StructureData = New Structure;
	StructureData.Insert("DATEDIFF", 				DATEDIFF);
	StructureData.Insert("CurrencyRateRepetition",	CurrencyRateRepetition);
	
	Return StructureData;
	
EndFunction

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
	ParametersStructure.Insert("Company",			Object.Company);
	ParametersStructure.Insert("DocumentDate",		Object.Date);
	ParametersStructure.Insert("RefillPrices",		RefillPrices);
	ParametersStructure.Insert("RecalculatePrices",	RecalculatePrices);
	ParametersStructure.Insert("WereMadeChanges",	False);
	ParametersStructure.Insert("WarningText",		WarningText);
	
	// Open form "Prices and Currency".
	// Refills tabular section "Costs" if changes were made in the "Price and Currency" form.
	NotifyDescription = New NotifyDescription("OpenPricesAndCurrencyFormEnd", ThisObject, New Structure("SettlementsCurrencyBeforeChange", SettlementsCurrencyBeforeChange));
	OpenForm("CommonForm.PricesAndCurrency", ParametersStructure, ThisForm,,,, NotifyDescription, FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtClient
Procedure ProcessContractChange()
	
	ContractBeforeChange = Contract;
	Contract = Object.Contract;
	
	If ContractBeforeChange <> Object.Contract Then
		
		ContractData = GetDataContractOnChange(Object.Date, Object.DocumentCurrency, Object.Contract);
		ProcessContractConditionsChange(ContractData, ContractBeforeChange);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ProcessContractConditionsChange(ContractData, ContractBeforeChange)
	
	SettlementCurrency = ContractData.SettlementsCurrency;
	
	If ValueIsFilled(Object.Contract) Then 
		Object.ExchangeRate	= ?(ContractData.SettlementsCurrencyRateRepetition.ExchangeRate = 0, 1, ContractData.SettlementsCurrencyRateRepetition.ExchangeRate);
		Object.Multiplicity = ?(ContractData.SettlementsCurrencyRateRepetition.Multiplicity = 0, 1, ContractData.SettlementsCurrencyRateRepetition.Multiplicity);
	EndIf;
	
	Object.DocumentCurrency = SettlementCurrency;
	
EndProcedure

&AtClient
Procedure OpenPricesAndCurrencyFormEnd(ClosingResult, AdditionalParameters) Export
	
	StructurePricesAndCurrency		= ClosingResult;
	SettlementsCurrencyBeforeChange = AdditionalParameters.SettlementsCurrencyBeforeChange;
	
	If TypeOf(StructurePricesAndCurrency) = Type("Structure") AND StructurePricesAndCurrency.WereMadeChanges Then
		
		Object.DocumentCurrency		= StructurePricesAndCurrency.DocumentCurrency;
		Object.ExchangeRate			= StructurePricesAndCurrency.PaymentsRate;
		Object.Multiplicity			= StructurePricesAndCurrency.SettlementsMultiplicity;
		Object.VATTaxation			= StructurePricesAndCurrency.VATTaxation;
		Object.AmountIncludesVAT	= StructurePricesAndCurrency.AmountIncludesVAT;
		Object.IncludeVATInPrice	= StructurePricesAndCurrency.IncludeVATInPrice;
		
		// Recalculate prices by currency.
		If Not StructurePricesAndCurrency.RefillPrices
			AND StructurePricesAndCurrency.RecalculatePrices Then	
			
			If Object.OperationKind = PredefinedValue("Enum.OperationTypesDebitNote.PurchaseReturn") Then
				DriveClient.RecalculateTabularSectionPricesByCurrency(ThisForm, SettlementsCurrencyBeforeChange, "Inventory");
				Object.AdjustmentAmount = Object.Inventory.Total("Total");
			Else
				RatesStructure = DriveServer.GetExchangeRates(SettlementsCurrencyBeforeChange, Object.DocumentCurrency, Object.Date);
				Object.AdjustmentAmount = DriveClient.RecalculateFromCurrencyToCurrency(Object.AdjustmentAmount, 
				RatesStructure.InitRate, 
				RatesStructure.ExchangeRate, 
				RatesStructure.RepetitionBeg, 
				RatesStructure.Multiplicity);
			EndIf;
			
			CalculateTotalVATAmount();
			DriveClient.RecalculateTabularSectionPricesByCurrency(ThisForm, SettlementsCurrencyBeforeChange, "AmountAllocation");
		EndIf;
		
		// Recalculate the amount if VAT taxation flag is changed.
		If StructurePricesAndCurrency.VATTaxation <> StructurePricesAndCurrency.PrevVATTaxation Then
			FillVATRateByVATTaxation();
			
			FormManagement();
		EndIf;
		
		// Recalculate the amount if the "Amount includes VAT" flag is changed.
		If Not StructurePricesAndCurrency.RefillPrices
			AND Not StructurePricesAndCurrency.AmountIncludesVAT = StructurePricesAndCurrency.PrevAmountIncludesVAT Then
			DriveClient.RecalculateTabularSectionAmountByFlagAmountIncludesVAT(ThisForm, "Inventory");
			Object.AdjustmentAmount = Object.Inventory.Total("Total");
			CalculateTotalVATAmount();
		EndIf;
		
	EndIf;
	
	// Generate price and currency label.
	LabelStructure = New Structure;
	LabelStructure.Insert("DocumentCurrency",				Object.DocumentCurrency);
	LabelStructure.Insert("SettlementsCurrency",			SettlementCurrency);
	LabelStructure.Insert("Rate",							Object.ExchangeRate);
	LabelStructure.Insert("RateNationalCurrency",			ExchangeRateNationalCurrency);
	LabelStructure.Insert("AmountIncludesVAT",				Object.AmountIncludesVAT);
	LabelStructure.Insert("ForeignExchangeAccounting",		ForeignExchangeAccounting);
	LabelStructure.Insert("VATTaxation",					Object.VATTaxation);
	LabelStructure.Insert("RegisteredForVAT",				RegisteredForVAT);
	
	PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
	
	WorkWithVATClient.ShowReverseChargeNotSupportedMessage(Object.VATTaxation);
	
EndProcedure

&AtClient
Procedure RecalculateExchangeRateMultiplicitySettlementCurrency(StructureData)
	
	NewExchangeRate = ?(StructureData.CurrencyRateRepetition.ExchangeRate = 0, 1, StructureData.CurrencyRateRepetition.ExchangeRate);
	NewRatio = ?(StructureData.CurrencyRateRepetition.Multiplicity = 0, 1, StructureData.CurrencyRateRepetition.Multiplicity);
	
	If Object.ExchangeRate <> NewExchangeRate
		OR Object.Multiplicity <> NewRatio Then
		
		CurrencyRateInLetters = String(Object.Multiplicity) + " " + TrimAll(SettlementCurrency) + " = " + String(Object.ExchangeRate) + " " + TrimAll(FunctionalCurrency);
		RateNewCurrenciesInLetters = String(NewRatio) + " " + TrimAll(SettlementCurrency) + " = " + String(NewExchangeRate) + " " + TrimAll(FunctionalCurrency);
		
		QuestionParameters = New Structure;
		QuestionParameters.Insert("NewExchangeRate", NewExchangeRate);
		QuestionParameters.Insert("NewRatio", NewRatio);
		
		NotifyDescription = New NotifyDescription("QuestionOnRecalculatingPaymentCurrencyRateConversionFactorEnd", ThisObject, QuestionParameters);
		
		QuestionText = StringFunctionsClientServer.SubstituteParametersInString(
						NStr("en = 'As of the date of document the contract currency (%1) exchange rate was specified.
						     |Set the contract exchange rate (%2) according to exchange rate?'"),
						CurrencyRateInLetters, RateNewCurrenciesInLetters);
		
		ShowQueryBox(NotifyDescription, QuestionText, QuestionDialogMode.YesNo);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure QuestionOnRecalculatingPaymentCurrencyRateConversionFactorEnd(Result, AdditionalParameters) Export

	If Result = DialogReturnCode.Yes Then
		
		Object.ExchangeRate = AdditionalParameters.NewExchangeRate;
		Object.Multiplicity = AdditionalParameters.NewRatio;
		
		For Each TabularSectionRow In Object.Inventory Do
			TabularSectionRow.Amount = DriveClient.RecalculateFromCurrencyToCurrency(
				TabularSectionRow.Amount,
				Object.ExchangeRate,
				?(Object.DocumentCurrency = FunctionalCurrency, ExchangeRateNationalCurrency, Object.ExchangeRate),
				Object.Multiplicity,
				?(Object.DocumentCurrency = FunctionalCurrency, MultiplicityNationalCurrency, Object.Multiplicity));
		EndDo;
			
	EndIf;

EndProcedure

&AtClient
Procedure ChoiceProccessingPeriod(SelectedPeriod, AdditionalParemeters) Export
	
	FillByPeriodAtServer(SelectedPeriod);
	
EndProcedure

&AtClient
Procedure FillByPeriodEnd(Result, AdditionalParameters) Export
	
	Response = Result;
	If Response = DialogReturnCode.Yes Then
		Dialog = New StandardPeriodEditDialog();
		Dialog.Period = New StandardPeriod(BeginingDate, EndingDate);
		
		NotifyDescription = New NotifyDescription("ChoiceProccessingPeriod", ThisForm);
		Dialog.Show(NotifyDescription);
	EndIf;
	
EndProcedure

&AtServer
Procedure FillByPeriodAtServer(SelectedPeriod)
	
	If SelectedPeriod <> Undefined Then
		
		Object.DebitedTransactions.Clear();
		
		BeginingDate = SelectedPeriod.StartDate;
		EndingDate	= EndOfDay(SelectedPeriod.EndDate);
		
		FillDebitTransactionsByAllTypes();
		
	EndIf;
	
EndProcedure

&AtServer
Procedure FillDebitTransactionsByAllTypes()
	
	Query = New Query();
	Query.Text = 
	"SELECT
	|	PurchasesTurnovers.Recorder AS Document,
	|	PurchasesTurnovers.VATRate AS VATRate,
	|	CASE
	|		WHEN (PurchasesTurnovers.AmountTurnover + PurchasesTurnovers.VATAmountTurnover) > 0
	|			THEN PurchasesTurnovers.AmountTurnover + PurchasesTurnovers.VATAmountTurnover
	|		ELSE -(PurchasesTurnovers.AmountTurnover + PurchasesTurnovers.VATAmountTurnover)
	|	END AS Amount,
	|	CASE
	|		WHEN PurchasesTurnovers.VATAmountTurnover > 0
	|			THEN PurchasesTurnovers.VATAmountTurnover
	|		ELSE -PurchasesTurnovers.VATAmountTurnover
	|	END AS VATAmount
	|FROM
	|	AccumulationRegister.Purchases.Turnovers(&BeginingDate, &EndingDate, Recorder, Company = &Company) AS PurchasesTurnovers
	|WHERE
	|	(PurchasesTurnovers.Recorder REFS Document.AdditionalExpenses
	|			OR PurchasesTurnovers.Recorder REFS Document.DebitNote
	|			OR PurchasesTurnovers.Recorder REFS Document.ExpenseReport
	|			OR PurchasesTurnovers.Recorder REFS Document.SupplierInvoice)
	|	AND PurchasesTurnovers.Recorder.Counterparty = &Counterparty
	|	AND PurchasesTurnovers.Recorder.Contract = &Contract
	|	AND PurchasesTurnovers.Recorder <> &Ref
	|
	|ORDER BY
	|	PurchasesTurnovers.Recorder,
	|	PurchasesTurnovers.VATRate
	|AUTOORDER";
	
	Query.SetParameter("BeginingDate",	BeginingDate);
	Query.SetParameter("EndingDate", 	EndingDate);
	Query.SetParameter("Company", 		Object.Company);
	Query.SetParameter("Counterparty", 	Object.Counterparty);
	Query.SetParameter("Contract", 		Object.Contract);
	Query.SetParameter("Ref", 			Object.Ref);
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	
	While Selection.Next() Do
		NewRow = Object.DebitedTransactions.Add();
		FillPropertyValues(NewRow, Selection);
	EndDo;
	
EndProcedure

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
	
	Return WorkWithSerialNumbers.SerialNumberPickParameters(Object, ThisObject.UUID, CurrentDataIdentifier, False, "Inventory");
	
EndFunction

// Procedure fills in the PaymentDetails TS string with the billing document data.
//
&AtClient
Procedure ProcessAccountsDocumentSelection(DocumentData)
	
	TabularSectionRow = Items.AmountAllocation.CurrentData;
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

// Procedure executes actions while changing counterparty contract.
//
&AtClient
Procedure ProcessCounterpartyContractChange()
	
	TabularSectionRow = Items.PaymentDetails.CurrentData;
	
	If ValueIsFilled(TabularSectionRow.Contract) Then
		StructureData = GetDataPaymentDetailsContractOnChange(Object.Date, TabularSectionRow.Contract);
		
		TabularSectionRow.ExchangeRate = ?(StructureData.ContractCurrencyRateRepetition.ExchangeRate = 0,
											1,
											StructureData.ContractCurrencyRateRepetition.ExchangeRate);
		TabularSectionRow.Multiplicity = ?(StructureData.ContractCurrencyRateRepetition.Multiplicity = 0,
											1,
											StructureData.ContractCurrencyRateRepetition.Multiplicity);
	EndIf;
	
	TabularSectionRow.SettlementsAmount = DriveClient.RecalculateFromCurrencyToCurrency(
		TabularSectionRow.OffsetAmount,
		Object.ExchangeRate,
		TabularSectionRow.ExchangeRate,
		Object.Multiplicity,
		TabularSectionRow.Multiplicity);
	
EndProcedure

// Procedure determines an advance flag depending on the billing document type.
//
&AtClient
Procedure RunActionsOnAccountsDocumentChange()
	
	TabularSectionRow = Items.AmountAllocation.CurrentData;
	
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesPaymentReceipt.FromVendor") Then
		
		If TypeOf(TabularSectionRow.Document) = Type("DocumentRef.CashVoucher")
			OR TypeOf(TabularSectionRow.Document) = Type("DocumentRef.PaymentExpense")
			OR TypeOf(TabularSectionRow.Document) = Type("DocumentRef.ExpenseReport") Then
			
			TabularSectionRow.AdvanceFlag = True;
			
		Else
			
			TabularSectionRow.AdvanceFlag = False;
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Procedure sets GL account values by default depending on the operation type.
//
&AtServer
Procedure SetDefaultValuesForGLAccount()

	If Object.OperationKind = Enums.OperationTypesDebitNote.PurchaseReturn Then
		Object.GLAccount			= Catalogs.DefaultGLAccounts.GetDefaultGLAccount("PurchaseReturns");
	ElsIf Object.OperationKind = Enums.OperationTypesDebitNote.DiscountReceived Then 
		Object.GLAccount			= Catalogs.DefaultGLAccounts.GetDefaultGLAccount("DiscountReceived");
	ElsIf Object.OperationKind = Enums.OperationTypesDebitNote.Adjustments Then 
		Object.GLAccount			= ChartsOfAccounts.PrimaryChartOfAccounts.EmptyRef();
	EndIf;
	
EndProcedure

&AtServer
Procedure SetAccountingPolicyValues()

	AccountingPolicy = InformationRegisters.AccountingPolicy.GetAccountingPolicy(Object.Date, Object.Company);
	UseGoodsReturnToSupplier	= AccountingPolicy.UseGoodsReturnToSupplier;
	UseTaxInvoice				= AccountingPolicy.PostVATEntriesBySourceDocuments;
	RegisteredForVAT			= AccountingPolicy.RegisteredForVAT;
	
EndProcedure

&AtClient
Procedure OpenProductGLAccountsForm(SelectedValue, TabName)

	If SelectedValue = Undefined Then
		Return;
	EndIf;

	If Not ReadOnly Then
		LockFormDataForEdit();
	EndIf;

	RowData = Object.Inventory.FindByID(SelectedValue);
	
	ObjectParameters = GLAccountsInDocumentsClientServer.GetObjectParameters(Object);
	StructureData = GetStructureData(ObjectParameters, RowData);
	
	RowParameters = GLAccountsInDocumentsClientServer.GetGLAccountsStructure(StructureData);
	RowParameters.Insert("TableName",			TabName);
	RowParameters.Insert("Products",			RowData.Products);

	OpenForm("CommonForm.ProductGLAccounts", RowParameters, ThisForm);
	
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
	
	StructureData = New Structure("Products, InventoryGLAccount, VATInputGLAccount, PurchaseReturnGLAccount,
		|GLAccounts, GLAccountsFilled");
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