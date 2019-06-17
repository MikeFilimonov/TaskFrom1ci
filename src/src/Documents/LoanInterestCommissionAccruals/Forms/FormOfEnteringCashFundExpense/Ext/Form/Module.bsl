#Region GeneralPurposeProceduresAndFunctions

// Procedure fills in the contract table with data from the Document Accruals LoanInterestCommissionAccruals TS.
//
&AtServer
Procedure FillInContractTable()
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	AccrualsForLoansAccruals.Employee,
	|	AccrualsForLoansAccruals.Lender,
	|	AccrualsForLoansAccruals.LoanContract,
	|	AccrualsForLoansAccruals.SettlementsCurrency,
	|	SUM(CASE
	|			WHEN AccrualsForLoansAccruals.AmountType = &AmountTypeInterest
	|				THEN AccrualsForLoansAccruals.Total
	|			ELSE 0
	|		END) AS Interest,
	|	SUM(CASE
	|			WHEN AccrualsForLoansAccruals.AmountType = &AmountTypeInterest
	|				THEN 0
	|			ELSE AccrualsForLoansAccruals.Total
	|		END) AS Commission,
	|	TRUE AS Mark
	|FROM
	|	Document.LoanInterestCommissionAccruals.Accruals AS AccrualsForLoansAccruals
	|WHERE
	|	AccrualsForLoansAccruals.Ref = &DocumentAccruals
	|
	|GROUP BY
	|	AccrualsForLoansAccruals.LoanContract,
	|	AccrualsForLoansAccruals.SettlementsCurrency,
	|	AccrualsForLoansAccruals.Lender,
	|	AccrualsForLoansAccruals.Employee";
	
	Query.SetParameter("DocumentAccruals",		DocumentAccruals);
	Query.SetParameter("AmountTypeInterest",	Enums.LoanScheduleAmountTypes.Interest);
	
	RequestResult = Query.Execute();
	
	ContractsOfLoan.Load(RequestResult.Unload());
	
EndProcedure

#EndRegion

#Region ProceduresEventHandlersForms

// Procedure - handler of the WhenCreatingOnServer event of the form.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	DocumentAccruals = Parameters.DocumentAccruals;
	If Not ValueIsFilled(DocumentAccruals) Then
		Cancel = True;
		Return;
	EndIf;
	
	If DocumentAccruals.OperationType = Enums.LoanAccrualTypes.AccrualsForLoansBorrowed Then
		
		Items.GroupCashExpenseButtons.Visible			= True;
		Items.FormEnterExpenseFromAccount.DefaultButton	= True;
		
		Items.GroupCashReceiptButtons.Visible			= False;
		Items.FormEnterReceiptToCashFund.DefaultButton	= False;
		
	Else
		
		Items.GroupCashExpenseButtons.Visible			= False;
		Items.FormEnterExpenseFromAccount.DefaultButton = False;
		
		Items.GroupCashReceiptButtons.Visible			= True;
		Items.FormEnterReceiptToCashFund.DefaultButton	= True;
	EndIf;
	
	FillInContractTable();
	
EndProcedure

#EndRegion

#Region CommandActionProcedures

// Procedure - handler of the EnterActualPayment command.
//
&AtClient
Procedure EnterActualPayment(DocumentKind)
	
	IsMark = False;
	
	For Each CurrentRow In ContractsOfLoan Do
		If CurrentRow.Mark Then
			IsMark = True;
			
			ParametersOfLoans = New Structure("Document, LoanContract, SettlementsCurrency, Employee, Lender", 
				DocumentAccruals, 
				CurrentRow.LoanContract,
				CurrentRow.SettlementsCurrency,
				CurrentRow.Employee,
				CurrentRow.Lender
			);
			FillingParameters = New Structure("Basis", ParametersOfLoans);
			
			OpenForm("Document." + DocumentKind + ".ObjectForm", FillingParameters, , CurrentRow.LoanContract);
		EndIf;
	EndDo;
	
	If Not IsMark Then
		ShowMessageBox(Undefined, 
			NStr("en = 'No line selected. Mark check boxes and try again.'"));
	EndIf;
	
EndProcedure

// Procedure - handler of the EnterCashFundExpense command.
//
&AtClient
Procedure EnterCashFundExpense(Command)
	
	EnterActualPayment("CashVoucher");
	Close();
	
EndProcedure

// Procedure - handler of the EnterCashFundReceipt command.
//
&AtClient
Procedure EnterCashFundReceipt(Command)
	
	EnterActualPayment("CashReceipt");
	Close();
	
EndProcedure

// Procedure - handler of the EnterExpenseFromAccount command.
//
&AtClient
Procedure EnterExpenseFromAccount(Command)
	
	EnterActualPayment("PaymentExpense");
	Close();
	
EndProcedure

// Procedure - handler of the ReceiptToAccount command.
//
&AtClient
Procedure EnterReceiptToAccount(Command)
	
	EnterActualPayment("PaymentReceipt");
	Close();
	
EndProcedure

#EndRegion
