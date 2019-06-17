
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	If GetFillingErrors(CommandParameter) Then
		Return;
	EndIf;
	
	OpenForm(
		"Document.TaxInvoiceIssued.ObjectForm",
		New Structure("Basis", CommandParameter),
		CommandExecuteParameters.Source,
		CommandExecuteParameters.Uniqueness,
		CommandExecuteParameters.Window,
		CommandExecuteParameters.URL);
	
EndProcedure

&AtServer
Function GetFillingErrors(CommandParameter)
	
	Query = New Query(
	"SELECT DISTINCT
	|	TaxInvoice.Ref AS Recorder,
	|	TRUE AS ThereAreInvoice,
	|	FALSE AS IncorrectOperation
	|FROM
	|	Document.TaxInvoiceIssued.BasisDocuments AS PaymentDocuments
	|		INNER JOIN Document.TaxInvoiceIssued AS TaxInvoice
	|		ON PaymentDocuments.Ref = TaxInvoice.Ref
	|WHERE
	|	PaymentDocuments.BasisDocument IN(&Documents)
	|	AND NOT TaxInvoice.DeletionMark
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
	|	PaymentReceipt.Ref IN(&Documents)");
	
	Query.SetParameter("Documents", CommandParameter);
	
	Cancel = False;
	Errors = Undefined;
	
	Selection = Query.Execute().Select();
	
	TextInvoiceError = NStr("en = 'This payment document is already posted by %1.
	                        |There is no need to create new the Advance payment invoice.'");
	
	IncorrectOperation = NStr("en = 'The Advance payment invoice is entered only when paying from the Customer.'");
	
	While Selection.Next() Do
		
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
