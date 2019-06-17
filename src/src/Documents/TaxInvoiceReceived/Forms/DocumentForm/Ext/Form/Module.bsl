#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
		
	// StandardSubsystems.ObjectVersioning
	ObjectVersioning.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.ObjectVersioning
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisForm, Items.ImportantCommandsGroup);
	// End StandardSubsystems.Printing
			
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If Not ValueIsFilled(Object.Ref) Then
		Title = SetTitle(Object);
		AutoTitle = False;
	EndIf;
	
	ManageFormItems();
	
	RecalculateSubtotal();
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	ClosingDates.ObjectOnReadAtServer(ThisForm, CurrentObject);
	FillDocumentAmounts();
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	Title = SetTitle(Object);
	AutoTitle = False;
	WorkWithVATClient.AfterWriteTaxInvoice(ThisForm, FormOwner, Object);
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "NotificationAboutChangingDebt" Then
		Read();
	EndIf;
	
EndProcedure

#EndRegion

#Region FormItemEventHandlersHeader

&AtClient
Procedure CounterpartyOnChange(Item)
	
	ManageFormItems();
	ClearBasisDocuments();
	
EndProcedure

&AtClient
Procedure CurrencyOnChange(Item)
	
	ClearBasisDocuments();
	
EndProcedure

&AtClient
Procedure CompanyOnChange(Item)
	
	ClearBasisDocuments();
	WorkWithVATServerCall.CheckForTaxInvoiceUse(Object.DateOfSupply, Object.Company);
	
EndProcedure

&AtClient
Procedure BasisDocumentsBasisDocumentStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	TabularSectionRow = Items.BasisDocuments.CurrentData;
	
	StructureFilter = New Structure("Counterparty, Company, Currency",
		Object.Counterparty, Object.Company, Object.Currency);
		
	ParameterStructure = New Structure("Filter, DocumentType", StructureFilter, TypeOf(Object.Ref));
	
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesTaxInvoiceReceived.AdvancePayment") Then
		ParameterStructure.Insert("ThisIsAdvancePaymentsReceived", True);
	Else
		ParameterStructure.Insert("ThisIsTaxInvoiceReceived", True);
	EndIf;
	
	OpenForm("CommonForm.SelectDocumentOfSettlements", ParameterStructure, Item);
	
EndProcedure

&AtClient
Procedure BasisDocumentsBasisDocumentChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	StandardProcessing = False;
	CurrentData = Items.BasisDocuments.CurrentData;
		
	FilterParameters = New Structure("BasisDocument", SelectedValue.Document);
	
	If Not IsDuplicatingInvoice(SelectedValue.Document) Then
		CurrentData.BasisDocument = SelectedValue.Document;
	EndIf;
	
	FillDocumentAmounts();
	
	RecalculateSubtotal();
	
EndProcedure

&AtClient
Procedure CounterpartyStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;	
	OpenForm("Catalog.Counterparties.ChoiceForm", New Structure("Filter, ChoiceMode, CloseOnChoice", New Structure("Supplier", True), True, True), Item);
	
EndProcedure

&AtClient
Procedure DateOfSupplyOnChange(Item)
	
	CheckForTaxInvoiceUse();
	
EndProcedure

&AtClient
Procedure OperationKindOnChange(Item)
	Object.BasisDocuments.Clear();
	
	Title = SetTitle(Object);
	AutoTitle = False;
EndProcedure

&AtServerNoContext
Function SetTitle(Val Object)
	
	Title = "";
	
	If ValueIsFilled(Object.Ref) Then
		Documents.TaxInvoiceReceived.PresentationGetProcessing(Object, Title, False, Object.OperationKind);
	Else
		Title = Documents.TaxInvoiceReceived.GetTitle(Object.OperationKind, True);
	EndIf;
		
	Return Title;
EndFunction

&AtClient
Procedure BasisDocumentsOnChange(Item)
	RecalculateSubtotal();
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// StandardSubsystems.Printing
&AtClient
Procedure Attachable_ExecutePrintCommand(Command)
	PrintManagementClient.ExecuteConnectedPrintCommand(Command, ThisObject, Object);
EndProcedure
// End StandardSubsystems.Printing

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
				Invoice
			)
		);
		
		Return True;
		
	EndIf;
	
EndFunction

&AtServer
Procedure FillDocumentAmounts()
	
	If Object.OperationKind = Enums.OperationTypesTaxInvoiceReceived.AdvancePayment Then
		
		Query = New Query(
		"SELECT
		|	Payment.Ref AS BasisDocument,
		|	Payment.VATAmount AS VATAmount,
		|	Payment.PaymentAmount AS Amount
		|INTO BasisDocuments
		|FROM
		|	Document.CashVoucher.PaymentDetails AS Payment
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
		|	Document.PaymentExpense.PaymentDetails AS Payment
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
		|	SupplierInvoiceInventory.Ref AS BasisDocument,
		|	SupplierInvoiceInventory.VATAmount AS VATAmount,
		|	SupplierInvoiceInventory.Total AS Amount
		|INTO DocumentData
		|FROM
		|	Document.SupplierInvoice.Inventory AS SupplierInvoiceInventory
		|WHERE
		|	SupplierInvoiceInventory.Ref IN(&Documents)
		|
		|UNION ALL
		|
		|SELECT
		|	SupplierInvoiceExpenses.Ref,
		|	SupplierInvoiceExpenses.VATAmount,
		|	SupplierInvoiceExpenses.Total
		|FROM
		|	Document.SupplierInvoice.Expenses AS SupplierInvoiceExpenses
		|WHERE
		|	SupplierInvoiceExpenses.Ref IN(&Documents)
		|
		|UNION ALL
		|
		|SELECT
		|	DebitNote.Ref,
		|	DebitNote.VATAmount,
		|	DebitNote.DocumentAmount
		|FROM
		|	Document.DebitNote AS DebitNote
		|WHERE
		|	DebitNote.Ref IN(&Documents)
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	DocumentData.BasisDocument AS BasisDocument,
		|	SUM(DocumentData.VATAmount) AS VATAmount,
		|	SUM(DocumentData.Amount) AS Amount
		|FROM
		|	DocumentData AS DocumentData
		|
		|GROUP BY
		|	DocumentData.BasisDocument");
		
	EndIf;
	
	Query.SetParameter("Documents", Object.BasisDocuments.Unload(, "BasisDocument"));
	
	Selection = Query.Execute().Select();
	DocObject = FormAttributeToValue("Object");
	
	While Selection.Next() Do
		RowBasisDocuments = DocObject.BasisDocuments.Find(Selection.BasisDocument, "BasisDocument");
		FillPropertyValues(RowBasisDocuments, Selection);
	EndDo;
	
	ValueToFormAttribute(DocObject, "Object");
	
EndProcedure

&AtClient
Procedure ClearBasisDocuments()
	
	Object.BasisDocuments.Clear();

EndProcedure

&AtClient
Procedure ManageFormItems()
	
	Items.BasisDocuments.ReadOnly = Not ValueIsFilled(Object.Counterparty);

EndProcedure

&AtServer
Procedure CheckForTaxInvoiceUse()
	
	If Object.OperationKind = Enums.OperationTypesTaxInvoiceReceived.AdvancePayment Then
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
