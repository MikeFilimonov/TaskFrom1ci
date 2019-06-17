
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	If GetFillingErrors(CommandParameter) Then
		Return;
	EndIf;
	
	OpenForm(
		"Document.TaxInvoiceReceived.Form.DocumentForm",
		New Structure(),
		CommandExecuteParameters.Source,
		CommandExecuteParameters.Uniqueness,
		CommandExecuteParameters.Window,
		CommandExecuteParameters.URL);
	
EndProcedure

&AtServer
Function GetFillingErrors(CommandParameter)
	
	Query = New Query(
	"SELECT DISTINCT
	|	VATIncurred.Recorder AS Recorder,
	|	TRUE AS ThereAreVATRecors,
	|	FALSE AS ThereAreInvoice,
	|	FALSE AS IncorrectOperation
	|FROM
	|	AccumulationRegister.VATIncurred AS VATIncurred
	|WHERE
	|	VATIncurred.ShipmentDocument IN(&Documents)
	|	AND VATIncurred.RecordType = VALUE(AccumulationRecordType.Expense)
	|	AND VALUETYPE(VATIncurred.Recorder) = TYPE(Document.SupplierInvoice)
	|
	|UNION ALL
	|
	|SELECT TOP 1
	|	TaxInvoice.Ref,
	|	FALSE,
	|	TRUE,
	|	FALSE
	|FROM
	|	Document.TaxInvoiceReceived.BasisDocuments AS PaymentDocuments
	|		INNER JOIN Document.TaxInvoiceReceived AS TaxInvoice
	|		ON PaymentDocuments.Ref = TaxInvoice.Ref
	|WHERE
	|	PaymentDocuments.BasisDocument IN (&Documents)
	|	AND NOT TaxInvoice.DeletionMark
	|
	|UNION ALL
	|
	|SELECT TOP 1
	|	CashVoucher.Ref,
	|	FALSE,
	|	TRUE,
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
	|	TRUE,
	|	CASE
	|		WHEN PaymentExpense.OperationKind <> VALUE(Enum.OperationTypesPaymentExpense.Vendor)
	|			THEN TRUE
	|		ELSE FALSE
	|	END
	|FROM
	|	Document.PaymentExpense AS PaymentExpense
	|WHERE
	|	PaymentExpense.Ref IN(&Documents)");
	
	Query.SetParameter("Documents", CommandParameter);
	
	Cancel = False;
	Errors = Undefined;
	
	Selection = Query.Execute().Select();
	
	TextVATError = NStr("en = 'The advance amount posted by this payment document is already set off by the %1.
	                    |There is no need to recognize advance VAT. If you still want to input Advance payment invoice,
	                    |revert Supplier invoice in the saved state, input advance payment invoice, and then post supplier invoice again.'");
	
	TextInvoiceError = NStr("en = 'The advance amount posted by this payment document is already set off by the %1.
	                        |There is no need to recognize advance VAT. If you still want to input Advance payment invoice,
	                        |revert Supplier invoice in the saved state, input advance payment invoice, and then post supplier invoice again.'");
		
	IncorrectOperation = NStr("en = 'The Advance payment invoice is entered only on payment to the Supplier.'");
	
	While Selection.Next() Do
		
		If Selection.ThereAreVATRecors Then
			ErrorText = StringFunctionsClientServer.SubstituteParametersInString(TextVATError, Selection.Recorder);
			CommonUseClientServer.AddUserError(Errors, , ErrorText, Undefined);
		EndIf;
		
		If Selection.ThereAreInvoice Then
			ErrorText = StringFunctionsClientServer.SubstituteParametersInString(TextInvoiceError, Selection.Recorder);
			CommonUseClientServer.AddUserError(Errors, , ErrorText, Undefined);
		EndIf;
		
		If Selection.IncorrectOperation Then
			ErrorText = StringFunctionsClientServer.SubstituteParametersInString(IncorrectOperation, Selection.Recorder);
			CommonUseClientServer.AddUserError(Errors, , ErrorText, Undefined);
		EndIf;
		
	EndDo;
	
	CommonUseClientServer.ShowErrorsToUser(Errors, Cancel);
	
	Return Cancel;
EndFunction
