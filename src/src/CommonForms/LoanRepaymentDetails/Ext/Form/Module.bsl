#Region FormEventHandlers

// Procedure - handler of the WhenCreatingOnServer event of the form.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("Autotest") Then // Skipping the initialization to guarantee that the form will be received if the Autotest parameter is passed.
		Return;
	EndIf;

	Company								= Parameters.Company;
	PaymentExplanationAddressInStorage	= Parameters.PaymentExplanationAddressInStorage;
	DocumentFormID						= Parameters.DocumentFormID;
	OperationKind						= Parameters.OperationKind;
	
	If (OperationKind = Enums.OperationTypesCashReceipt.LoanRepaymentByEmployee 
			OR OperationKind = Enums.OperationTypesPaymentReceipt.LoanRepaymentByEmployee)
		AND Parameters.Property("Employee") Then
		
		Counterparty = Parameters.Employee;
		
	Else
		Counterparty = Parameters.Counterparty;
	EndIf;
	
	Date						= Parameters.Date;
	Recorder					= Parameters.Recorder;
	Ref							= Parameters.Recorder;
	LoanContract				= Parameters.LoanContract;
	Currency					= Parameters.Currency;
	DocumentAmount				= Parameters.DocumentAmount;
	DefaultVATRate				= Parameters.DefaultVATRate;
	PaymentAmount				= Parameters.PaymentAmount;
	PaymentExchangeRate			= Parameters.Rate;
	PaymentUnitConversionFactor	= Parameters.Multiplicity;
	
	Items.DecorationInformationOnDocument.Title = StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en = '%1 %2 %3. Amount: %4 (%5)'"),
		Parameters.OperationKind,
		?(TypeOf(Counterparty) = Type("CatalogRef.Counterparties"), 
			NStr("en = '. Lender:'"), 
			NStr("en = '. Employee:'")),
		Counterparty.Description,
		DocumentAmount,
		Currency);
	
	Items.DecorationLabelInformationOnLoanContract.Title = StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en = '%1 Amount: %2 (%3)'"),
		Parameters.LoanContract,
		Parameters.LoanContract.Total,
		Parameters.LoanContract.SettlementsCurrency);
	
	Title = "";
	
	ClearTabularSectionOnPopulation = True;
	
	EnterLoanDataOnServer();
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

// Procedure - handler of the Fill in forms command.
//
&AtClient
Procedure Fill(Command)
	
	PopulateOnServerAccordingToTableData();
	
	Structure = New Structure("PaymentExplanationAddressInStorage, ClearTabularSectionOnPopulation", PaymentExplanationAddressInStorage, ClearTabularSectionOnPopulation);
	
	NotifyChoice(Structure);
	
EndProcedure

// Procedure - handler of the Update forms command.
//
&AtClient
Procedure Refresh(Command)
	
	PaymentData.Clear();
	EnterLoanDataOnServer();
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

// Procedure generates a table for populating the PaymentExplanation tabular section of the document and saves it to the
// temporary storage.
//
&AtServer
Procedure PopulateOnServerAccordingToTableData()
	
	PaymentExplanation = Ref.PaymentDetails.UnloadColumns();
	
	If DocumentAmount = 0 OR NOT ClearTabularSectionOnPopulation Then
		
		For Each CurrentRowOfPaymentData In PaymentData Do
			If NOT CurrentRowOfPaymentData.Mark Then
				Continue;
			EndIf;
			
			FillInLineOfExplanationOfPaymentOnLoans(PaymentExplanation, Enums.LoanScheduleAmountTypes.Interest, CurrentRowOfPaymentData.Interest);
			FillInLineOfExplanationOfPaymentOnLoans(PaymentExplanation, Enums.LoanScheduleAmountTypes.Commission, CurrentRowOfPaymentData.Commission);
			FillInLineOfExplanationOfPaymentOnLoans(PaymentExplanation, Enums.LoanScheduleAmountTypes.Principal, CurrentRowOfPaymentData.Principal);
			
		EndDo;
		
	Else
		
		AmountBalanceForAllocation = DocumentAmount * PaymentExchangeRate * SettlementUnitConversionFactor / (SettlementsRate * PaymentUnitConversionFactor);
		
		For Each CurrentRowOfPaymentData In PaymentData Do
			If NOT CurrentRowOfPaymentData.Mark Then
				Continue;
			EndIf;
			
			InterestAmount = Min(AmountBalanceForAllocation, CurrentRowOfPaymentData.Interest);
			AmountBalanceForAllocation = Max(0, AmountBalanceForAllocation - InterestAmount);
			FillInLineOfExplanationOfPaymentOnLoans(PaymentExplanation, Enums.LoanScheduleAmountTypes.Interest, InterestAmount);
			
			CommissionAmount = Min(AmountBalanceForAllocation, CurrentRowOfPaymentData.Commission);
			AmountBalanceForAllocation = Max(0, AmountBalanceForAllocation - CommissionAmount);
			FillInLineOfExplanationOfPaymentOnLoans(PaymentExplanation, Enums.LoanScheduleAmountTypes.Commission, CommissionAmount);
			
			PrincipalDebtAmount = Min(AmountBalanceForAllocation, CurrentRowOfPaymentData.Principal);
			AmountBalanceForAllocation = Max(0, AmountBalanceForAllocation - PrincipalDebtAmount);
			FillInLineOfExplanationOfPaymentOnLoans(PaymentExplanation, Enums.LoanScheduleAmountTypes.Principal, PrincipalDebtAmount);
			
		EndDo;
		
		If AmountBalanceForAllocation > 0 Then
			FillInLineOfExplanationOfPaymentOnLoans(PaymentExplanation, Undefined, AmountBalanceForAllocation);
		EndIf;
		
	EndIf;
	
	PaymentExplanationAddressInStorage = PutToTempStorage(PaymentExplanation, UUID);
	
EndProcedure

// Procedure adds and populates one line of the value table which will be transferred to a document form.
//
&AtServer
Procedure FillInLineOfExplanationOfPaymentOnLoans(PaymentExplanation, AmountType, Total)

	If Total > 0 Then
		
		NewRow = PaymentExplanation.Add();
		NewRow.TypeOfAmount			= AmountType;
		NewRow.SettlementsAmount	= Total;
		NewRow.ExchangeRate			= SettlementsRate;
		NewRow.Multiplicity			= SettlementUnitConversionFactor;
		NewRow.PaymentAmount		= Total * SettlementsRate * PaymentUnitConversionFactor / (SettlementUnitConversionFactor * PaymentExchangeRate);
		NewRow.VATRate				= DefaultVATRate;
		
		VATRate = DriveReUse.GetVATRateValue(NewRow.VATRate);
		NewRow.VATAmount			= NewRow.PaymentAmount - (NewRow.PaymentAmount) / ((VATRate + 100) / 100);
		
	EndIf;

EndProcedure

// Procedure fills in the PaymentData table.
//
&AtServer
Procedure EnterLoanDataOnServer()
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	LoanRepaymentScheduleLastSlice.Period,
	|	LoanRepaymentScheduleLastSlice.Principal,
	|	LoanRepaymentScheduleLastSlice.Interest,
	|	LoanRepaymentScheduleLastSlice.Commission
	|FROM
	|	InformationRegister.LoanRepaymentSchedule.SliceLast(&LastSliceDate, LoanContract = &LoanContract) AS LoanRepaymentScheduleLastSlice
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SUM(LoanSettlementsBalance.PrincipalDebtCurBalance) AS PrincipalDebtCurBalance,
	|	LoanSettlementsBalance.LoanContract.SettlementsCurrency,
	|	SUM(LoanSettlementsBalance.InterestCurBalance) AS InterestCurBalance,
	|	SUM(LoanSettlementsBalance.CommissionCurBalance) AS CommissionCurBalance
	|INTO TemporaryTableBalance
	|FROM
	|	AccumulationRegister.LoanSettlements.Balance(, LoanContract = &LoanContract) AS LoanSettlementsBalance
	|
	|GROUP BY
	|	LoanSettlementsBalance.LoanContract.SettlementsCurrency
	|
	|UNION ALL
	|
	|SELECT
	|	CASE
	|		WHEN LoanSettlements.RecordType = VALUE(AccumulationRecordType.Receipt)
	|			THEN -LoanSettlements.PrincipalDebtCur
	|		ELSE LoanSettlements.PrincipalDebtCur
	|	END,
	|	LoanSettlements.LoanContract.SettlementsCurrency,
	|	CASE
	|		WHEN LoanSettlements.RecordType = VALUE(AccumulationRecordType.Receipt)
	|			THEN -LoanSettlements.InterestCur
	|		ELSE LoanSettlements.InterestCur
	|	END,
	|	CASE
	|		WHEN LoanSettlements.RecordType = VALUE(AccumulationRecordType.Receipt)
	|			THEN -LoanSettlements.CommissionCur
	|		ELSE LoanSettlements.CommissionCur
	|	END
	|FROM
	|	AccumulationRegister.LoanSettlements AS LoanSettlements
	|WHERE
	|	LoanSettlements.LoanContract = &LoanContract
	|	AND LoanSettlements.Recorder = &Ref
	|
	|GROUP BY
	|	LoanSettlements.LoanContract.SettlementsCurrency,
	|	CASE
	|		WHEN LoanSettlements.RecordType = VALUE(AccumulationRecordType.Receipt)
	|			THEN -LoanSettlements.PrincipalDebtCur
	|		ELSE LoanSettlements.PrincipalDebtCur
	|	END,
	|	CASE
	|		WHEN LoanSettlements.RecordType = VALUE(AccumulationRecordType.Receipt)
	|			THEN -LoanSettlements.InterestCur
	|		ELSE LoanSettlements.InterestCur
	|	END,
	|	CASE
	|		WHEN LoanSettlements.RecordType = VALUE(AccumulationRecordType.Receipt)
	|			THEN -LoanSettlements.CommissionCur
	|		ELSE LoanSettlements.CommissionCur
	|	END
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	LoanRepaymentScheduleSliceFirst.Period,
	|	LoanRepaymentScheduleSliceFirst.Principal,
	|	LoanRepaymentScheduleSliceFirst.Interest,
	|	LoanRepaymentScheduleSliceFirst.Commission
	|FROM
	|	InformationRegister.LoanRepaymentSchedule.SliceFirst(&LastSliceDate, LoanContract = &LoanContract) AS LoanRepaymentScheduleSliceFirst
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SUM(ISNULL(LoanRepaymentSchedule.Principal, 0)) AS Principal,
	|	SUM(ISNULL(LoanRepaymentSchedule.Interest, 0)) AS Interest,
	|	SUM(ISNULL(LoanRepaymentSchedule.Commission, 0)) AS Commission
	|FROM
	|	InformationRegister.LoanRepaymentSchedule AS LoanRepaymentSchedule
	|WHERE
	|	LoanRepaymentSchedule.LoanContract = &LoanContract
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SUM(CASE
	|			WHEN LoanSettlementsTurnovers.LoanKind = &LoanKindCreditContract
	|				THEN LoanSettlementsTurnovers.PrincipalDebtCurExpense
	|			ELSE LoanSettlementsTurnovers.PrincipalDebtCurReceipt
	|		END) AS PrincipalDebtCurReceived,
	|	SUM(CASE
	|			WHEN LoanSettlementsTurnovers.LoanKind = &LoanKindCreditContract
	|				THEN LoanSettlementsTurnovers.InterestCurReceipt
	|			ELSE LoanSettlementsTurnovers.InterestCurExpense
	|		END) AS InterestCurPaid,
	|	SUM(CASE
	|			WHEN LoanSettlementsTurnovers.LoanKind = &LoanKindCreditContract
	|				THEN LoanSettlementsTurnovers.CommissionCurReceipt
	|			ELSE LoanSettlementsTurnovers.CommissionCurExpense
	|		END) AS CommissionCurPaid,
	|	SUM(CASE
	|			WHEN LoanSettlementsTurnovers.LoanKind = &LoanKindCreditContract
	|				THEN LoanSettlementsTurnovers.PrincipalDebtCurReceipt
	|			ELSE LoanSettlementsTurnovers.PrincipalDebtCurExpense
	|		END) AS PrincipalDebtCurPaid
	|FROM
	|	AccumulationRegister.LoanSettlements.Turnovers(, , Recorder, LoanContract = &LoanContract) AS LoanSettlementsTurnovers
	|WHERE
	|	LoanSettlementsTurnovers.Recorder <> &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SUM(ISNULL(TemporaryTableBalance.PrincipalDebtCurBalance, 0)) AS PrincipalDebtCurBalance,
	|	TemporaryTableBalance.LoanContractSettlementsCurrency,
	|	SUM(ISNULL(TemporaryTableBalance.InterestCurBalance, 0)) AS InterestCurBalance,
	|	SUM(ISNULL(TemporaryTableBalance.CommissionCurBalance, 0)) AS CommissionCurBalance
	|FROM
	|	TemporaryTableBalance AS TemporaryTableBalance
	|
	|GROUP BY
	|	TemporaryTableBalance.LoanContractSettlementsCurrency
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ExchangeRatesSliceLast.ExchangeRate AS Rate,
	|	ExchangeRatesSliceLast.Multiplicity
	|FROM
	|	InformationRegister.ExchangeRates.SliceLast(&Date, Currency = &Currency) AS ExchangeRatesSliceLast";
	
	Query.SetParameter("LastSliceDate",				?(Date = '00010101', BegOfDay(CurrentDate()), BegOfDay(Date)));
	Query.SetParameter("LoanContract",				LoanContract);
	Query.SetParameter("Ref",						Ref);
	Query.SetParameter("LoanKindCreditContract",	Enums.LoanContractTypes.Borrowed);
	Query.SetParameter("Date",						?(ValueIsFilled(Ref.Date), Ref.Date, CurrentDate()));
	Query.SetParameter("Currency",					LoanContract.SettlementsCurrency);
	
	MResults = Query.ExecuteBatch();
	
	// Exchange rate and exchange rate multiplier.
	SelectionExchangeRateAndUnitConversionFactor = MResults[6].Select();
	If SelectionExchangeRateAndUnitConversionFactor.Next() Then
		SettlementsRate = SelectionExchangeRateAndUnitConversionFactor.Rate;
		SettlementUnitConversionFactor = SelectionExchangeRateAndUnitConversionFactor.Multiplicity;
	Else
		SettlementsRate = 1;
		SettlementUnitConversionFactor = 1;
	EndIf;
	// End Exchange rate and exchange rate multiplier.
	
	If LoanContract.LoanKind = Enums.LoanContractTypes.EmployeeLoanAgreement Then
		Factor = 1;
	Else
		Factor = -1;
	EndIf;
	
	DataOnLoan = "";
	
	SelectionSchedule = MResults[0].Select();
	SelectionScheduleFollowingMonths = MResults[2].Select();
	
	CheckBox1 = False;
	CheckBox2 = False;
	CheckBox3 = False;
	CheckBox4 = False;
	
	// Next payment.
	If SelectionScheduleFollowingMonths.Next() Then
		
		PaymentDate = Format(SelectionScheduleFollowingMonths.Period, "DLF=D");
			
		NewRow = PaymentData.Add();
		NewRow.PaymentDate	= SelectionScheduleFollowingMonths.Period;
		NewRow.Principal	= SelectionScheduleFollowingMonths.Principal;
		NewRow.Interest		= SelectionScheduleFollowingMonths.Interest;
		NewRow.Commission	= SelectionScheduleFollowingMonths.Commission;
		NewRow.Details		= "Next payment";
		NewRow.Mark			= True;
		
		CheckBox1 = True;
			
	Else
		NewRow = PaymentData.Add();
		NewRow.Details = "Next payment";
	EndIf;
		
	// Previous payment.
	If SelectionSchedule.Next() Then
		
		PaymentDate = Format(SelectionSchedule.Period, "DLF=D");
			
		NewRow = PaymentData.Add();
		NewRow.PaymentDate	= SelectionSchedule.Period;
		NewRow.Principal	= SelectionSchedule.Principal;
		NewRow.Interest		= SelectionSchedule.Interest;
		NewRow.Commission	= SelectionSchedule.Commission;
		NewRow.Details		= "Previous payment";
		NewRow.Mark			= NOT CheckBox1;
		
		CheckBox2 = NewRow.Mark;
		
	Else
		NewRow = PaymentData.Add();
		NewRow.Details = "Previous payment";
	EndIf;
	
	// Balance.
	SelectionBalance = MResults[5].Select();
	If SelectionBalance.Next() Then
		
		NewRow = PaymentData.Add();
		NewRow.PaymentDate	= Date;
		NewRow.Principal	= Factor * SelectionBalance.PrincipalDebtCurBalance;
		NewRow.Interest		= Factor * SelectionBalance.InterestCurBalance;
		NewRow.Commission	= Factor * SelectionBalance.CommissionCurBalance;
		NewRow.Details		= "Remaining debt";
		NewRow.Mark			= (NOT CheckBox1 AND NOT CheckBox2);
		
		CheckBox3 = NewRow.Mark;
		
	Else
		NewRow = PaymentData.Add();
		NewRow.Details = "Remaining debt";
	EndIf;
	
	// For calculation.
	SelectionTotalSchedule = MResults[3].Select();
	SelectionTotalSchedule.Next();
	SelectionTotalTurnovers = MResults[4].Select();
	SelectionTotalTurnovers.Next();
	
	PrincipalDebtCurReceived	= ?(ValueIsFilled(SelectionTotalTurnovers.PrincipalDebtCurReceived), 
		SelectionTotalTurnovers.PrincipalDebtCurReceived, 0);
	PrincipalDebtCurPaid		= ?(ValueIsFilled(SelectionTotalTurnovers.PrincipalDebtCurPaid), 
		SelectionTotalTurnovers.PrincipalDebtCurPaid, 0);
	InterestCurPaid				= ?(ValueIsFilled(SelectionTotalTurnovers.InterestCurPaid), 
		SelectionTotalTurnovers.InterestCurPaid, 0);
	CommissionCurPaid			= ?(ValueIsFilled(SelectionTotalTurnovers.CommissionCurPaid), 
		SelectionTotalTurnovers.CommissionCurPaid, 0);
	
	TotalReceived = PrincipalDebtCurReceived;
	TotalPrincipalDebt = Max(0, TotalReceived - PrincipalDebtCurPaid);
	
	TotalInterest = Max(0, ?(SelectionTotalSchedule.Interest = NULL, 
		0, 
		SelectionTotalSchedule.Interest) - InterestCurPaid);
	TotalCommission = Max(0, ?(SelectionTotalSchedule.Commission = NULL, 
		0, 
		SelectionTotalSchedule.Commission) - CommissionCurPaid);
	
	If TotalPrincipalDebt > 0 OR TotalInterest > 0 OR TotalCommission > 0 Then
		
		NewRow = PaymentData.Add();
		NewRow.PaymentDate	= Date;
		NewRow.Principal	= TotalPrincipalDebt;
		NewRow.Interest		= TotalInterest;
		NewRow.Commission	= TotalCommission;
		NewRow.Details		= NStr("en = 'Complete early repayment'");
		NewRow.Mark			= (NOT CheckBox1 AND NOT CheckBox2 AND NOT CheckBox3);
		
	Else
		NewRow = PaymentData.Add();
		NewRow.Details = NStr("en = 'Complete early repayment'");
	EndIf;
	
EndProcedure

#EndRegion
