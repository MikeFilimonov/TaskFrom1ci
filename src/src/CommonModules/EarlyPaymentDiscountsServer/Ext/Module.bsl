#Region Public

// Checks for correctness of the early payments discounts
//  Parameters:
//   TabularSectionEPD - FormDataCollection - tabular section with EPD from Contract,
//                                            Sales invoice or Supplier invoice
//  Returns:
//   boolean - EPD correct or not
//
Function CheckEarlyPaymentDiscounts(TabularSectionEPD, ProvideEPD) Export
	
	Result = True;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	EarlyPaymentDiscounts.Period AS Period,
	|	EarlyPaymentDiscounts.Discount AS Discount
	|INTO TempEarlyPaymentDiscounts
	|FROM
	|	&EarlyPaymentDiscounts AS EarlyPaymentDiscounts
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Table.Period AS Period,
	|	Table.Discount AS Discount
	|FROM
	|	TempEarlyPaymentDiscounts AS Table
	|
	|ORDER BY
	|	Period";
	
	Query.SetParameter("EarlyPaymentDiscounts", TabularSectionEPD.Unload());
	
	DataSelection = Query.Execute().Select();
	
	PreviousDiscount = 100;
	PreviousPeriod = 0;
	
	If TabularSectionEPD.Count() > 0 AND NOT ValueIsFilled(ProvideEPD) Then
		
		CommonUseClientServer.MessageToUser(NStr("en = 'Select a EPD provision option'"));
		
		Result = False;
		
	EndIf;
	
	While DataSelection.Next() Do
		
		If DataSelection.Discount = 0 OR DataSelection.Discount >= 100 Then
			
			TextMessage = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'The early payment discount can''t be %1%'"),
				DataSelection.Discount);
			
			CommonUseClientServer.MessageToUser(TextMessage);
			
			Result = False;
			
		ElsIf PreviousDiscount <= DataSelection.Discount Then
			
			TextError = NStr("en = 'The early payment discount %1% with the period %2 days should be less then the discount %3% with the period %4 days'");
			
			TextMessage = StringFunctionsClientServer.SubstituteParametersInString(
				TextError,
				DataSelection.Discount,
				DataSelection.Period,
				PreviousDiscount,
				PreviousPeriod);
			
			CommonUseClientServer.MessageToUser(TextMessage);
			
			Result = False;
			
		EndIf;
		
		PreviousDiscount = DataSelection.Discount;
		PreviousPeriod = DataSelection.Period;
		
	EndDo;
	
	Return Result;
	
EndFunction

// Sets hyperlink label for credit note
//
Procedure SetTextAboutCreditNote(DocumentForm, BasisDocument) Export
	
	CreditNoteFound = GetSubordinateCreditNote(BasisDocument);
	
	If ValueIsFilled(CreditNoteFound) Then
		DocumentForm.CreditNoteText = EarlyPaymentDiscountsClientServer.CreditNotePresentation(CreditNoteFound.Date, CreditNoteFound.Number);
	Else
		DocumentForm.CreditNoteText = NStr("en = 'In order to provide EPD, please issue the Credit note'");
	EndIf;
	
EndProcedure

// Returns reference to the subordinate credit note
//
Function GetSubordinateCreditNote(BasisDocument) Export
	
	If NOT ValueIsFilled(BasisDocument) Then
		Return Undefined;
	EndIf;
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	CreditNote.Ref AS Ref
	|FROM
	|	Document.CreditNote AS CreditNote
	|WHERE
	|	CreditNote.BasisDocument = &BasisDocument
	|	AND NOT CreditNote.DeletionMark";
	
	Query.SetParameter("BasisDocument", BasisDocument);
	
	Result = Undefined;
	
	Selection = Query.Execute().Select();
	
	If Selection.Next() Then
		Result = Selection.Ref;
	EndIf;
	
	Return Result;
	
EndFunction

// Gets errors when filling in a credit note
//
Function CheckBeforeCreditNoteFilling(Documents, FindCreditNote = True) Export
	
	Query = New Query;
	Query.Text = 
	"SELECT DISTINCT
	|	CreditNote.BasisDocument AS Recorder,
	|	TRUE AS ThereAreCreditNote,
	|	FALSE AS IncorrectOperation
	|FROM
	|	Document.CreditNote AS CreditNote
	|WHERE
	|	CreditNote.BasisDocument IN(&Documents)
	|	AND NOT CreditNote.DeletionMark
	|	AND &FindCreditNote
	|
	|UNION ALL
	|
	|SELECT TOP 1
	|	CashReceipt.Ref,
	|	FALSE,
	|	CASE
	|		WHEN CashReceipt.OperationKind <> VALUE(Enum.OperationTypesCashReceipt.FromCustomer)
	|			THEN TRUE
	|		ELSE FALSE
	|	END
	|FROM
	|	Document.CashReceipt AS CashReceipt
	|WHERE
	|	CashReceipt.Ref IN(&Documents)
	|
	|UNION ALL
	|
	|SELECT TOP 1
	|	PaymentReceipt.Ref,
	|	FALSE,
	|	CASE
	|		WHEN PaymentReceipt.OperationKind <> VALUE(Enum.OperationTypesPaymentReceipt.FromCustomer)
	|			THEN TRUE
	|		ELSE FALSE
	|	END
	|FROM
	|	Document.PaymentReceipt AS PaymentReceipt
	|WHERE
	|	PaymentReceipt.Ref IN(&Documents)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	CashReceiptPaymentDetails.Contract AS Contract
	|FROM
	|	Document.CashReceipt.PaymentDetails AS CashReceiptPaymentDetails
	|		INNER JOIN Document.SalesInvoice AS SalesInvoice
	|		ON CashReceiptPaymentDetails.Document = SalesInvoice.Ref
	|WHERE
	|	CashReceiptPaymentDetails.SettlementsEPDAmount > 0
	|	AND (SalesInvoice.ProvideEPD = VALUE(Enum.VariantsOfProvidingEPD.CreditDebitNote)
	|			OR SalesInvoice.ProvideEPD = VALUE(Enum.VariantsOfProvidingEPD.CreditDebitNoteWithVATAdjustment))
	|	AND CashReceiptPaymentDetails.Contract <> VALUE(Catalog.CounterpartyContracts.EmptyRef)
	|	AND CashReceiptPaymentDetails.Ref IN(&Documents)
	|
	|UNION ALL
	|
	|SELECT DISTINCT
	|	PaymentReceiptPaymentDetails.Contract
	|FROM
	|	Document.PaymentReceipt.PaymentDetails AS PaymentReceiptPaymentDetails
	|		INNER JOIN Document.SalesInvoice AS SalesInvoice
	|		ON PaymentReceiptPaymentDetails.Document = SalesInvoice.Ref
	|WHERE
	|	PaymentReceiptPaymentDetails.SettlementsEPDAmount > 0
	|	AND (SalesInvoice.ProvideEPD = VALUE(Enum.VariantsOfProvidingEPD.CreditDebitNote)
	|			OR SalesInvoice.ProvideEPD = VALUE(Enum.VariantsOfProvidingEPD.CreditDebitNoteWithVATAdjustment))
	|	AND PaymentReceiptPaymentDetails.Contract <> VALUE(Catalog.CounterpartyContracts.EmptyRef)
	|	AND PaymentReceiptPaymentDetails.Ref IN(&Documents)";
	
	Query.SetParameter("Documents", Documents);
	Query.SetParameter("FindCreditNote", FindCreditNote);
	
	Cancel = False;
	Errors = Undefined;
	
	ResultArray = Query.ExecuteBatch();
	
	Selection = ResultArray[0].Select();
	
	TextCreditNoteError = NStr("en = 'There is already a credit note based on %1.'");
	
	IncorrectOperation = NStr("en = 'The Credit note is entered only when paying from the Customer.'");
	
	While Selection.Next() Do
		
		If Selection.ThereAreCreditNote Then
			ErrorText = StringFunctionsClientServer.SubstituteParametersInString(TextCreditNoteError, Selection.Recorder);
			CommonUseClientServer.AddUserError(Errors, , ErrorText, Undefined);
		EndIf;
		
		If Selection.IncorrectOperation Then
			CommonUseClientServer.AddUserError(Errors, , IncorrectOperation, Undefined);
		EndIf;
		
	EndDo;
	
	SelectionTable = ResultArray[1].Unload();
	
	TextEPDError = NStr("en = 'There are no rows with early payment discount in the Payment allocation, witch provide via credit note.'");
	
	If SelectionTable.Count() = 0 Then
		
		CommonUseClientServer.AddUserError(Errors, , TextEPDError, Undefined);
		
	EndIf;
	
	TextContractError = NStr("en = 'To generate Credit note, the payment allocation rows should contain the same contract.'");
	
	If SelectionTable.Count() > 1 Then
		
		CommonUseClientServer.AddUserError(Errors, , TextContractError, Undefined);
		
	EndIf;
	
	CommonUseClientServer.ShowErrorsToUser(Errors, Cancel);
	
	Return Cancel;
	
EndFunction

// Sets hyperlink label for debit note
//
Procedure SetTextAboutDebitNote(DocumentForm, BasisDocument) Export
	
	DebitNoteFound = GetSubordinateDebitNote(BasisDocument);
	
	If ValueIsFilled(DebitNoteFound) Then
		DocumentForm.DebitNoteText = EarlyPaymentDiscountsClientServer.DebitNotePresentation(DebitNoteFound.Date, DebitNoteFound.Number);
	Else
		DocumentForm.DebitNoteText = NStr("en = 'In order to provide EPD, please issue the Debit note'");
	EndIf;
	
EndProcedure

// Returns reference to the subordinate credit note
//
Function GetSubordinateDebitNote(BasisDocument) Export
	
	If NOT ValueIsFilled(BasisDocument) Then
		Return Undefined;
	EndIf;
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	DebitNote.Ref AS Ref
	|FROM
	|	Document.DebitNote AS DebitNote
	|WHERE
	|	DebitNote.BasisDocument = &BasisDocument
	|	AND NOT DebitNote.DeletionMark";
	
	Query.SetParameter("BasisDocument", BasisDocument);
	
	Result = Undefined;
	
	Selection = Query.Execute().Select();
	
	If Selection.Next() Then
		Result = Selection.Ref;
	EndIf;
	
	Return Result;
	
EndFunction

// Gets errors when filling in a credit note
//
Function CheckBeforeDebitNoteFilling(Documents, FindDebitNote = True) Export
	
	Query = New Query;
	Query.Text = 
	"SELECT DISTINCT
	|	DebitNote.BasisDocument AS Recorder,
	|	TRUE AS ThereAreDebitNote,
	|	FALSE AS IncorrectOperation
	|FROM
	|	Document.DebitNote AS DebitNote
	|WHERE
	|	DebitNote.BasisDocument IN(&Documents)
	|	AND NOT DebitNote.DeletionMark
	|	AND &FindDebitNote
	|
	|UNION ALL
	|
	|SELECT TOP 1
	|	CashVoucher.Ref,
	|	FALSE,
	|	CASE
	|		WHEN CashVoucher.OperationKind <> VALUE(Enum.OperationTypesCashVoucher.Vendor)
	|			THEN TRUE
	|		ELSE FALSE
	|	END
	|FROM
	|	Document.CashVoucher AS CashVoucher
	|WHERE
	|	CashVoucher.Ref IN(&Documents)
	|
	|UNION ALL
	|
	|SELECT TOP 1
	|	PaymentExpense.Ref,
	|	FALSE,
	|	CASE
	|		WHEN PaymentExpense.OperationKind <> VALUE(Enum.OperationTypesPaymentExpense.Vendor)
	|			THEN TRUE
	|		ELSE FALSE
	|	END
	|FROM
	|	Document.PaymentExpense AS PaymentExpense
	|WHERE
	|	PaymentExpense.Ref IN(&Documents)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	CashVoucherPaymentDetails.Contract AS Contract
	|FROM
	|	Document.CashVoucher.PaymentDetails AS CashVoucherPaymentDetails
	|		INNER JOIN Document.SupplierInvoice AS SupplierInvoice
	|		ON CashVoucherPaymentDetails.Document = SupplierInvoice.Ref
	|WHERE
	|	CashVoucherPaymentDetails.SettlementsEPDAmount > 0
	|	AND (SupplierInvoice.ProvideEPD = VALUE(Enum.VariantsOfProvidingEPD.CreditDebitNote)
	|			OR SupplierInvoice.ProvideEPD = VALUE(Enum.VariantsOfProvidingEPD.CreditDebitNoteWithVATAdjustment))
	|	AND CashVoucherPaymentDetails.Contract <> VALUE(Catalog.CounterpartyContracts.EmptyRef)
	|	AND CashVoucherPaymentDetails.Ref IN(&Documents)
	|
	|UNION ALL
	|
	|SELECT DISTINCT
	|	PaymentExpensePaymentDetails.Contract
	|FROM
	|	Document.PaymentExpense.PaymentDetails AS PaymentExpensePaymentDetails
	|		INNER JOIN Document.SupplierInvoice AS SupplierInvoice
	|		ON PaymentExpensePaymentDetails.Document = SupplierInvoice.Ref
	|WHERE
	|	PaymentExpensePaymentDetails.SettlementsEPDAmount > 0
	|	AND (SupplierInvoice.ProvideEPD = VALUE(Enum.VariantsOfProvidingEPD.CreditDebitNote)
	|			OR SupplierInvoice.ProvideEPD = VALUE(Enum.VariantsOfProvidingEPD.CreditDebitNoteWithVATAdjustment))
	|	AND PaymentExpensePaymentDetails.Contract <> VALUE(Catalog.CounterpartyContracts.EmptyRef)
	|	AND PaymentExpensePaymentDetails.Ref IN(&Documents)";
	
	Query.SetParameter("Documents", Documents);
	Query.SetParameter("FindDebitNote", FindDebitNote);
	
	Cancel = False;
	Errors = Undefined;
	
	ResultArray = Query.ExecuteBatch();
	
	Selection = ResultArray[0].Select();
	
	TextDebitNoteError = NStr("en = 'There is already a debit note based on %1.'");
	
	IncorrectOperation = NStr("en = 'The Debit note is entered only when paying to the Vendor.'");
	
	While Selection.Next() Do
		
		If Selection.ThereAreDebitNote Then
			ErrorText = StringFunctionsClientServer.SubstituteParametersInString(TextDebitNoteError, Selection.Recorder);
			CommonUseClientServer.AddUserError(Errors, , ErrorText, Undefined);
		EndIf;
		
		If Selection.IncorrectOperation Then
			CommonUseClientServer.AddUserError(Errors, , IncorrectOperation, Undefined);
		EndIf;
		
	EndDo;
	
	SelectionTable = ResultArray[1].Unload();
	
	TextEPDError = NStr("en = 'There are no rows with early payment discount in the Payment allocation, witch provide via debit note.'");
	
	If SelectionTable.Count() = 0 Then
		
		CommonUseClientServer.AddUserError(Errors, , TextEPDError, Undefined);
		
	EndIf;
	
	TextContractError = NStr("en = 'To generate Debit note, the payment allocation rows should contain the same contract.'");
	
	If SelectionTable.Count() > 1 Then
		
		CommonUseClientServer.AddUserError(Errors, , TextContractError, Undefined);
		
	EndIf;
	
	CommonUseClientServer.ShowErrorsToUser(Errors, Cancel);
	
	Return Cancel;
	
EndFunction

#EndRegion
