
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	If TypeOf(Parameters.Basis) = Type("DocumentRef.CreditNote") Then
		If Parameters.Basis.VATTaxation = Enums.VATTaxationTypes.NotSubjectToVAT Then
			MessageText = StringFunctionsClientServer.SubstituteParametersInString(
							NStr("en = '%1 is not subject to VAT.'"),
							Parameters.Basis);
			CommonUseClientServer.MessageToUser(MessageText,,,,Cancel);
			Return;
		EndIf;
	EndIf;
	
	If Not ValueIsFilled(Object.Ref) Then
		Object.DateOfSupply = ?(ValueIsFilled(Object.Date), Object.Date, CurrentSessionDate());
		OnReadCreateAtServer();
	EndIf;
	
	// StandardSubsystems.ObjectVersioning
	ObjectVersioning.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.ObjectVersioning
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisForm, Items.ImportantCommandsGroup);
	// End StandardSubsystems.Printing
			
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	ClosingDates.ObjectOnReadAtServer(ThisForm, CurrentObject);
	OnReadCreateAtServer();
	FillDocumentAmounts();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If Not ValueIsFilled(Object.Ref) Then
		AutoTitle = False;
		Title = SetTitle(Object);
	EndIf;
	
	ManageFormItems();
	
	RecalculateSubtotal();
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	If Cancel Then
		Return;
	EndIf;
	
	MessageText = NStr("en = 'Attribute ""Date of supply"" is empty'");
	
	If DateOfSupplyCheckbox AND NOT ValueIsFilled(Object.DateOfSupply) Then
		CommonUseClientServer.MessageToUser(MessageText,, "DateOfSupply", "Object", Cancel);
	ElsIf NOT DateOfSupplyCheckbox Then
		Object.DateOfSupply = '00010101'; 	
	EndIf;
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	AutoTitle = True;
	Title = "";
	
	WorkWithVATClient.AfterWriteTaxInvoice(ThisForm, FormOwner, Object);
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "NotificationAboutChangingDebt" Then
		Read();
	EndIf;
	
EndProcedure

#EndRegion

#Region FormItemEventHandlers

&AtClient
Procedure BasisDocumentStartChoiceEnd(SelectedElement, AdditionalParameters) Export
	
	If SelectedElement = Undefined Then
		Return;
	EndIf;
	
	Filter = New Structure();
	Filter.Insert("Posted", True);
	VATTaxationArray = New Array;
	VATTaxationArray.Add(PredefinedValue("Enum.VATTaxationTypes.SubjectToVAT"));
	VATTaxationArray.Add(PredefinedValue("Enum.VATTaxationTypes.ForExport"));
	
	Filter.Insert("VATTaxation", VATTaxationArray);
	
	If SelectedElement.Value = "CreditNote" Then
		If Object.OperationKind = PredefinedValue("Enum.OperationTypesTaxInvoiceIssued.SalesReturn") Then
			
			Filter.Insert("OperationKind", PredefinedValue("Enum.OperationTypesCreditNote.SalesReturn"));
			
		ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesTaxInvoiceIssued.Adjustments") Then	
			
			OperationKindArray = New Array;
			OperationKindArray.Add(PredefinedValue("Enum.OperationTypesCreditNote.Adjustments"));
			OperationKindArray.Add(PredefinedValue("Enum.OperationTypesCreditNote.DiscountAllowed"));
			
			Filter.Insert("OperationKind", OperationKindArray);
			
		EndIf;
	EndIf;
	
	ParametersStructure = New Structure();
	ParametersStructure.Insert("Filter", Filter);
	
	OpenedForm = OpenForm("Document." + SelectedElement.Value + ".ChoiceForm", ParametersStructure,AdditionalParameters.Item);
		
EndProcedure

&AtClient
Procedure CompanyOnChange(Item)
	
	ManageFormItems();
	ClearBasisDocuments();
	WorkWithVATServerCall.CheckForTaxInvoiceUse(?(DateOfSupplyCheckbox, Object.DateOfSupply, Object.Date), Object.Company);
	
EndProcedure

&AtClient
Procedure CounterpartyOnChange(Item)
	
	ManageFormItems();
	ClearBasisDocuments();
	
EndProcedure

&AtClient
Procedure CounterpartyStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	OpenForm("Catalog.Counterparties.ChoiceForm", New Structure("Filter, ChoiceMode, CloseOnChoice", New Structure("Customer", True), True, True), Item);

EndProcedure

&AtClient
Procedure CurrencyOnChange(Item)
	
	ClearBasisDocuments();
	
EndProcedure

&AtClient
Procedure DateOfSupplyCheckboxOnChange(Item)
	
	ManageFormItems();
	
EndProcedure

&AtClient
Procedure BasisDocumentsBasisDocumentStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	TabularSectionRow = Items.BasisDocuments.CurrentData;
	
	StructureFilter = New Structure("Counterparty, Company, Currency",
		Object.Counterparty, Object.Company, Object.Currency);
		
	ParameterStructure = New Structure("Filter, DocumentType", StructureFilter, TypeOf(Object.Ref));
	
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesTaxInvoiceIssued.AdvancePayment") Then
		ParameterStructure.Insert("ThisIsAdvancePaymentsIssued", True);
	Else
		ParameterStructure.Insert("ThisIsTaxInvoiceIssued", True);
	EndIf;
	
	OpenForm("CommonForm.SelectDocumentOfSettlements", ParameterStructure, Item);

EndProcedure

&AtClient
Procedure BasisDocumentsBasisDocumentChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	If TypeOf(SelectedValue) = Type("Array") Then  
		
		StandardProcessing = False;
		CurrentData = Items.BasisDocuments.CurrentData;
		CurrentData.BasisDocument = Undefined;
		
		For Each ArrayItem In SelectedValue Do
			FilterParameters = New Structure;
			FilterParameters.Insert("BasisDocument",ArrayItem);
			If Not IsDuplicatingInvoice(ArrayItem) Then
				If ValueIsFilled(CurrentData.BasisDocument) Then 
					RowBasisDocuments = Object.BasisDocuments.Add();
					RowBasisDocuments.BasisDocument = ArrayItem;
				Else 
					CurrentData.BasisDocument = ArrayItem;
				EndIf;
			EndIf;
		EndDo;
		
		FillDocumentAmounts();
		
	Else
		
		StandardProcessing = False;
		CurrentData = Items.BasisDocuments.CurrentData;
		
		FilterParameters = New Structure;
		FilterParameters.Insert("BasisDocument", SelectedValue.Document);
		
		If Not IsDuplicatingInvoice(SelectedValue.Document) Then
			CurrentData.BasisDocument = SelectedValue.Document;
		EndIf;
		
		FillDocumentAmounts();
		
	EndIf;
	
	RecalculateSubtotal();
	
EndProcedure

&AtClient
Procedure DateOnChange(Item)
	
	If NOT DateOfSupplyCheckbox Then
		CheckForTaxInvoiceUse();
	EndIf;
	
EndProcedure

&AtClient
Procedure DateOfSupplyOnChange(Item)
	
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesTaxInvoiceIssued.AdvancePayment") Then
		WorkWithVATServerCall.CheckForAdvancePaymentInvoiceUse(Object.DateOfSupply, Object.Company);
	Else
		WorkWithVATServerCall.CheckForTaxInvoiceUse(Object.DateOfSupply, Object.Company);
	EndIf;
	
EndProcedure

&AtClient
Procedure OperationKindOnChange(Item)
	
	Object.BasisDocuments.Clear();
	
	AutoTitle = False;
	Title = SetTitle(Object);
	
EndProcedure

&AtServerNoContext
Function SetTitle(Val Object)
	
	Title = "";
	
	If ValueIsFilled(Object.Ref) Then
		Documents.TaxInvoiceIssued.PresentationGetProcessing(Object, Title, False, Object.OperationKind);
	Else
		Title = Documents.TaxInvoiceIssued.GetTitle(Object.OperationKind, True);
	EndIf;
		
	Return Title;
	
EndFunction

&AtClient
Procedure BasisDocumentsOnChange(Item)
	RecalculateSubtotal();
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

#Region Other

&AtClient
Procedure ManageFormItems()
	
	IsNew				= NOT ValueIsFilled(Object.Ref);
	IsReadOnly			= DateOfSupplyCheckbox AND NOT IsNew;
	
	Items.DateOfSupply.Enabled		= DateOfSupplyCheckbox;
	Items.Number.ReadOnly			= IsReadOnly; 
	Items.Date.ReadOnly				= IsReadOnly;
	Items.Company.ReadOnly			= IsReadOnly;
	Items.Counterparty.ReadOnly		= IsReadOnly;
	Items.Currency.ReadOnly			= IsReadOnly;
	Items.BasisDocuments.ReadOnly	= Not ValueIsFilled(Object.Counterparty);
	
EndProcedure

&AtClient
Procedure ClearBasisDocuments()
	
	Object.BasisDocuments.Clear();

EndProcedure

&AtServer
Procedure OnReadCreateAtServer()
		
	DateOfSupplyCheckbox = ValueIsFilled(Object.DateOfSupply);	
	
EndProcedure

// StandardSubsystems.Printing
&AtClient
Procedure Attachable_ExecutePrintCommand(Command)
	PrintManagementClient.ExecuteConnectedPrintCommand(Command, ThisObject, Object);
EndProcedure
// End StandardSubsystems.Printing

#EndRegion

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

&AtClient
Function IsDuplicatingInvoice(Invoice)
	
	FilterParameters = New Structure;
	FilterParameters.Insert("BasisDocument",Invoice);
	
	If Object.BasisDocuments.FindRows(FilterParameters).Count() = 0 Then
		Return False;
	Else
		CommonUseClientServer.MessageToUser(
			StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'The document %1 already exists in the list.'"),
				Invoice));
		Return True;
	EndIf;
	
EndFunction

&AtServer
Procedure FillDocumentAmounts()
	
	If Object.OperationKind = Enums.OperationTypesTaxInvoiceIssued.AdvancePayment Then
		
		Query = New Query(
		"SELECT
		|	Payment.Ref AS BasisDocument,
		|	Payment.VATAmount AS VATAmount,
		|	Payment.PaymentAmount AS Amount
		|INTO BasisDocuments
		|FROM
		|	Document.CashReceipt.PaymentDetails AS Payment
		|WHERE
		|	Payment.Ref IN(&Documents)
		|
		|UNION ALL
		|
		|SELECT
		|	Payment.Ref AS BasisDocument,
		|	Payment.VATAmount AS VATAmount,
		|	Payment.PaymentAmount AS Amount
		|FROM
		|	Document.PaymentReceipt.PaymentDetails AS Payment
		|WHERE
		|	Payment.Ref IN(&Documents)
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	BasisDocuments.BasisDocument AS BasisDocument,
		|	SUM(BasisDocuments.VATAmount) AS VATAmount,
		|	SUM(BasisDocuments.Amount) AS Amount
		|FROM
		|	BasisDocuments AS BasisDocuments
		|
		|GROUP BY
		|	BasisDocuments.BasisDocument");
		
	Else
		
		Query = New Query("
		|SELECT
		|	SalesInvoiceInventory.Ref AS BasisDocument,
		|	SalesInvoiceInventory.VATAmount AS VATAmount,
		|	SalesInvoiceInventory.Total AS Amount
		|INTO BasisDocuments
		|FROM
		|	Document.SalesInvoice.Inventory AS SalesInvoiceInventory
		|WHERE
		|	SalesInvoiceInventory.Ref IN(&Documents)
		|
		|UNION ALL
		|
		|SELECT
		|	CreditNote.Ref,
		|	CreditNote.VATAmount,
		|	CreditNote.DocumentAmount
		|FROM
		|	Document.CreditNote AS CreditNote
		|WHERE
		|	CreditNote.Ref IN(&Documents)
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	BasisDocuments.BasisDocument AS BasisDocument,
		|	SUM(BasisDocuments.VATAmount) AS VATAmount,
		|	SUM(BasisDocuments.Amount) AS Amount
		|FROM
		|	BasisDocuments AS BasisDocuments
		|
		|GROUP BY
		|	BasisDocuments.BasisDocument");
		
	EndIf;
	
	Query.SetParameter("Documents", Object.BasisDocuments.Unload(,"BasisDocument"));
	
	Selection = Query.Execute().Select();
	DocObject = FormAttributeToValue("Object");
	
	While Selection.Next() Do
		RowBasisDocuments = DocObject.BasisDocuments.Find(Selection.BasisDocument,"BasisDocument");
		FillPropertyValues(RowBasisDocuments, Selection);
	EndDo;
	
	ValueToFormAttribute(DocObject,"Object");
	
EndProcedure

&AtServer
Procedure CheckForTaxInvoiceUse()
	
	If Object.OperationKind = Enums.OperationTypesTaxInvoiceIssued.AdvancePayment Then
		WorkWithVATServerCall.CheckForAdvancePaymentInvoiceUse(Object.DateOfSupply, Object.Company);
	Else
		WorkWithVATServerCall.CheckForTaxInvoiceUse(Object.DateOfSupply, Object.Company);
	EndIf;
	
EndProcedure

// Procedure recalculates subtotal
//
&AtClient
Procedure RecalculateSubtotal()
	
	DocumentSubtotal = Object.BasisDocuments.Total("Amount") - Object.BasisDocuments.Total("VATAmount");
	
EndProcedure


#EndRegion
