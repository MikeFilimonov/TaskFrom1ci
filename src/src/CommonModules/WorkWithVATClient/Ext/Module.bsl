#Region ProgramInterface

Procedure AfterWriteTaxInvoice(Form, FormOwner, Object) Export
	
	BasisDocumentsArray = Object.BasisDocuments.FindRows(New Structure());
	
	// If you open this form from the document form, then you should change the text there
	If Not FormOwner = Undefined Then
		If TypeOf(FormOwner) = Type("ManagedForm") Then
			Form.CloseOnChoice = False;
			
			If Find(FormOwner.FormName, "DocumentForm") <> 0 Then
				BasisDocument = Object.BasisDocuments.FindRows(New Structure("BasisDocument", FormOwner.Object.Ref));
				
				If ValueIsFilled(BasisDocument)
					OR FormOwner.Object.Ref = BasisDocument Then
						If Object.OperationKind = PredefinedValue("Enum.OperationTypesTaxInvoiceIssued.AdvancePayment")
							Or Object.OperationKind = PredefinedValue("Enum.OperationTypesTaxInvoiceReceived.AdvancePayment") Then
							Presentation = WorkWithVATClientServer.AdvancePaymentInvoicePresentation(Object.Date, Object.Number);
						Else
							Presentation = WorkWithVATClientServer.TaxInvoicePresentation(Object.Date, Object.Number);
						EndIf;
						Form.NotifyChoice(Presentation);
				EndIf;
			Else
				If Object.OperationKind = PredefinedValue("Enum.OperationTypesTaxInvoiceIssued.AdvancePayment")
					Or Object.OperationKind = PredefinedValue("Enum.OperationTypesTaxInvoiceReceived.AdvancePayment") Then
					Presentation = WorkWithVATClientServer.AdvancePaymentInvoicePresentation(Object.Date, Object.Number);
				Else
					Presentation = WorkWithVATClientServer.TaxInvoicePresentation(Object.Date, Object.Number);
				EndIf;
				
				Structure = New Structure;
				Structure.Insert("BasisDocuments",	BasisDocumentsArray);
				Structure.Insert("Presentation",	Presentation);
				
				Notify("RefreshTaxInvoiceText", Structure);
			EndIf; 
		EndIf;
	Else
		If Object.OperationKind = PredefinedValue("Enum.OperationTypesTaxInvoiceIssued.AdvancePayment")
			Or Object.OperationKind = PredefinedValue("Enum.OperationTypesTaxInvoiceReceived.AdvancePayment") Then
			Presentation = WorkWithVATClientServer.AdvancePaymentInvoicePresentation(Object.Date, Object.Number);
		Else
			Presentation = WorkWithVATClientServer.TaxInvoicePresentation(Object.Date, Object.Number);
		EndIf;
		
		Structure = New Structure;
		Structure.Insert("BasisDocuments",	BasisDocumentsArray);
		Structure.Insert("Presentation",	Presentation);
		
		Notify("RefreshTaxInvoiceText", Structure);
	EndIf;
	
EndProcedure

Procedure OpenTaxInvoice(DocumentForm, Received = False, Advance = False) Export
	
	InvoiceFound = WorkWithVATServerCall.GetSubordinateTaxInvoice(DocumentForm.Object.Ref, Received, Advance);
	
	If DocumentForm.Object.DeletionMark 
		AND Not ValueIsFilled(InvoiceFound) Then
		MessageText = NStr("en = 'Please select a base document that is not marked for deletion.'");	
		CommonUseClientServer.MessageToUser(MessageText);
		
		Return;	
	EndIf;
	
	If DocumentForm.Modified Then
		MessageText = NStr("en = 'Please save the document.'");	
		CommonUseClientServer.MessageToUser(MessageText);
		
		Return;	
	EndIf;
	
	If Not ValueIsFilled(DocumentForm.Object.Ref) Then
		MessageText = NStr("en = 'Please save the document.'");	
		CommonUseClientServer.MessageToUser(MessageText);
		
		Return;	
	EndIf;
	
	If Received Then
		FormName = "Document.TaxInvoiceReceived.ObjectForm";
	Else
		FormName = "Document.TaxInvoiceIssued.ObjectForm";
	EndIf;
	
	// Open and enter new document
	ParametersStructureAccountInvoice = New Structure;
	
	If ValueIsFilled(InvoiceFound) Then
		ParametersStructureAccountInvoice.Insert("Key", InvoiceFound.Ref);
	Else
		ParametersStructureAccountInvoice.Insert("Basis", DocumentForm.Object.Ref);
	EndIf;
	
	OpenForm(FormName, ParametersStructureAccountInvoice, DocumentForm);
	
EndProcedure

Procedure ShowReverseChargeNotSupportedMessage(VATTaxation) Export
	
	If VATTaxation = PredefinedValue("Enum.VATTaxationTypes.ReverseChargeVAT") Then
		
		CommonUseClientServer.MessageToUser(
			NStr("en = 'Debit/credit note issued against invoice with the reverse charge scheme doesn''t impact VAT entries.
			     |If you have any information or clarifications on this case from your tax authority, please, provide them to your vendor.'"),
			,
			,
			,
			);
		
	EndIf;
	
EndProcedure

#EndRegion