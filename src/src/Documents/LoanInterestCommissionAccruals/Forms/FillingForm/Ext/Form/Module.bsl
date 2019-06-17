
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("Autotest") Then // Skipping the initialization to guarantee that the form will be received if the Autotest parameter is passed.
		Return;
	EndIf;

	Company					= Parameters.Company;
	AccrualAddressInStorage	= Parameters.AccrualAddressInStorage;
	OperationType			= Parameters.OperationKind;
	StartDate				= Parameters.StartDate;
	EndDate					= Parameters.EndDate;
	Recorder				= Parameters.Recorder;
	
	SetContractSelectionParameters();
	
	If OperationType = Enums.LoanAccrualTypes.AccrualsForLoansBorrowed Then
		Items.Employee.Visible = False;
	Else
		Items.Counterparty.Visible = False;
	EndIf;
	
	NewArray = New Array();
	
	If OperationType = Enums.LoanAccrualTypes.AccrualsForLoansBorrowed Then
		NewParameter = New ChoiceParameter("Filter.LoanKind", Enums.LoanContractTypes.Borrowed);
		Items.FillInByContractsWithRepaymentFromSalary.Visible = False;
	Else
		NewParameter = New ChoiceParameter("Filter.LoanKind", Enums.LoanContractTypes.EmployeeLoanAgreement);
		Items.FillInByContractsWithRepaymentFromSalary.Visible = True;
	EndIf;
	
	NewArray.Add(NewParameter);
	NewParameters = New FixedArray(NewArray);
	Items.LoanContract.ChoiceParameters = NewParameters;
	
EndProcedure

#EndRegion

#Region FormHeaderItemEventHandlers

&AtClient
Procedure CounterpartyOnChange(Item)
	SetContractSelectionParameters();
EndProcedure

&AtClient
Procedure EmployeeOnChange(Item)	
	SetContractSelectionParameters();	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Fill(Command)

	AccrualsServer();
	
	Structure = New Structure("AccrualAddressInStorage", AccrualAddressInStorage);
	NotifyChoice(Structure);

EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

#Region Others

&AtServer
Function SetContractSelectionParameters()

	ParameterArray = New Array;
	ParameterArray.Add(New ChoiceParameter("Filter.Company", Company));
	
	If OperationType = Enums.LoanAccrualTypes.AccrualsForLoansBorrowed Then
		ParameterArray.Add(New ChoiceParameter("Filter.LoanKind", Enums.LoanContractTypes.Borrowed));
		
		If Not Counterparty.IsEmpty() Then
			ParameterArray.Add(New ChoiceParameter("Filter.Lender", Counterparty));
		EndIf;
	Else
		ParameterArray.Add(New ChoiceParameter("Filter.LoanKind", Enums.LoanContractTypes.EmployeeLoanAgreement));
		
		If Not Employee.IsEmpty() Then
			ParameterArray.Add(New ChoiceParameter("Filter.Employee", Employee));
		EndIf;
	EndIf;
	
	ParameterArray.Add(New ChoiceParameter("Filter.DeletionMark", False));
	
	Items.LoanContract.ChoiceParameters = New FixedArray(ParameterArray);
	
EndFunction

&AtServer
Function QueryTextByAccruals()
	
	Return 
	"SELECT
	|	LoanRepaymentSchedule.Period,
	|	LoanRepaymentSchedule.LoanContract AS LoanContract,
	|	SUM(LoanRepaymentSchedule.Interest) AS Interest,
	|	SUM(LoanRepaymentSchedule.Commission) AS Commission,
	|	CASE
	|		WHEN LoanRepaymentSchedule.LoanContract.LoanKind = VALUE(Enum.LoanContractTypes.Borrowed)
	|			THEN LoanRepaymentSchedule.LoanContract.Counterparty
	|		ELSE LoanRepaymentSchedule.LoanContract.Employee
	|	END AS Lender,
	|	LoanRepaymentSchedule.LoanContract.Company AS Company,
	|	LoanRepaymentSchedule.LoanContract.LoanKind AS LoanKind,
	|	LoanRepaymentSchedule.LoanContract.SettlementsCurrency AS SettlementsCurrency
	|INTO CurrentAccruals
	|FROM
	|	InformationRegister.LoanRepaymentSchedule AS LoanRepaymentSchedule
	|WHERE
	|	LoanRepaymentSchedule.Active
	|	AND LoanRepaymentSchedule.Period BETWEEN &StartDate AND &EndDate
	|	AND LoanRepaymentSchedule.LoanContract.Company = &Company
	|	AND LoanRepaymentSchedule.LoanContract.LoanKind = &LoanKind
	|
	|GROUP BY
	|	LoanRepaymentSchedule.Period,
	|	LoanRepaymentSchedule.LoanContract,
	|	CASE
	|		WHEN LoanRepaymentSchedule.LoanContract.LoanKind = VALUE(Enum.LoanContractTypes.Borrowed)
	|			THEN LoanRepaymentSchedule.LoanContract.Counterparty
	|		ELSE LoanRepaymentSchedule.LoanContract.Employee
	|	END,
	|	LoanRepaymentSchedule.LoanContract.LoanKind,
	|	LoanRepaymentSchedule.LoanContract.Company,
	|	LoanRepaymentSchedule.LoanContract.SettlementsCurrency
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	LoanSettlements.Period,
	|	LoanSettlements.LoanKind,
	|	LoanSettlements.Counterparty,
	|	LoanSettlements.LoanContract,
	|	LoanSettlements.Company,
	|	SUM(LoanSettlements.InterestCur) AS InterestCur,
	|	SUM(LoanSettlements.CommissionCur) AS CommissionCur,
	|	LoanSettlements.LoanContract.SettlementsCurrency AS SettlementsCurrency
	|INTO PreviousAccruals
	|FROM
	|	AccumulationRegister.LoanSettlements AS LoanSettlements
	|WHERE
	|	LoanSettlements.Period BETWEEN &StartDate AND &EndDate
	|	AND LoanSettlements.Recorder <> &Recorder
	|	AND LoanSettlements.LoanKind = &LoanKind
	|	AND LoanSettlements.Company = &Company
	|	AND LoanSettlements.Active
	|
	|GROUP BY
	|	LoanSettlements.LoanContract,
	|	LoanSettlements.Period,
	|	LoanSettlements.LoanKind,
	|	LoanSettlements.Company,
	|	LoanSettlements.Counterparty,
	|	LoanSettlements.LoanContract.SettlementsCurrency
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CurrentAccruals.Period AS Date,
	|	CurrentAccruals.LoanContract AS LoanContract,
	|	CurrentAccruals.Interest,
	|	CurrentAccruals.Commission,
	|	CAST(CurrentAccruals.Lender AS Catalog.Counterparties) AS Lender,
	|	CAST(CurrentAccruals.Lender AS Catalog.Employees) AS Employee,
	|	CurrentAccruals.Company,
	|	CurrentAccruals.LoanKind,
	|	CurrentAccruals.SettlementsCurrency,
	|	0 AS Total,
	|	CurrentAccruals.LoanContract.ChargeFromSalary AS ChargeFromSalary
	|FROM
	|	CurrentAccruals AS CurrentAccruals
	|		LEFT JOIN PreviousAccruals AS PreviousAccruals
	|		ON CurrentAccruals.Period = PreviousAccruals.Period
	|			AND CurrentAccruals.LoanContract = PreviousAccruals.LoanContract
	|			AND CurrentAccruals.Lender = PreviousAccruals.LoanKind
	|			AND CurrentAccruals.SettlementsCurrency = PreviousAccruals.SettlementsCurrency
	|WHERE
	|	PreviousAccruals.Period IS NULL
	|{WHERE
	|	(CAST(CurrentAccruals.Lender AS Catalog.Counterparties)).* AS Lender,
	|	(CAST(CurrentAccruals.Lender AS Catalog.Employees)).* AS Employee,
	|	CurrentAccruals.LoanContract.*,
	|	CurrentAccruals.LoanContract.ChargeFromSalary AS ChargeFromSalary}
	|
	|ORDER BY
	|	Date,
	|	LoanContract
	|AUTOORDER";
	
EndFunction

&AtServer
Procedure AccrualsServer()
	
	// receive Accrual table on schedule
	QueryBuilder = New QueryBuilder(QueryTextByAccruals());
	QueryBuilder.Parameters.Insert("StartDate", StartDate);
	QueryBuilder.Parameters.Insert("EndDate",	EndDate);
	QueryBuilder.Parameters.Insert("Company",	Company);
	QueryBuilder.Parameters.Insert("Recorder",	Recorder);
	
	If OperationType = Enums.LoanAccrualTypes.AccrualsForLoansBorrowed Then
		QueryBuilder.Parameters.Insert("LoanKind", Enums.LoanContractTypes.Borrowed);
	Else
		QueryBuilder.Parameters.Insert("LoanKind", Enums.LoanContractTypes.EmployeeLoanAgreement);
	EndIf;
	
	If ValueIsFilled(Counterparty) Then
		NewFilter = QueryBuilder.Filter.Add("Lender");
		NewFilter.Set(Counterparty);
	EndIf;
	
	If ValueIsFilled(Employee) Then
		NewFilter = QueryBuilder.Filter.Add("Employee");
		NewFilter.Set(Employee);
	EndIf;
	
	If ValueIsFilled(LoanContract) Then
		NewFilter = QueryBuilder.Filter.Add("LoanContract");
		NewFilter.Set(LoanContract);
	EndIf;
	
	If OperationType = Enums.LoanAccrualTypes.AccrualsForLoansLent AND 
		Not FillInByContractsWithRepaymentFromSalary Then
		NewFilter = QueryBuilder.Filter.Add("ChargeFromSalary");
		NewFilter.Set(False);
	EndIf;
	
	QueryBuilder.Execute();
	ScheduleAccruals = QueryBuilder.Result.Unload();
	
	Accruals = ScheduleAccruals.CopyColumns();
	Accruals.Columns.Add("AmountType", New TypeDescription("EnumRef.LoanScheduleAmountTypes"));
	
	For Each CurrentAccrual In ScheduleAccruals Do
	
		If CurrentAccrual.Interest <> 0 Then
			NewAccrualLine = Accruals.Add();
			FillPropertyValues(NewAccrualLine, CurrentAccrual);
			NewAccrualLine.Total = CurrentAccrual.Interest;
			NewAccrualLine.AmountType = Enums.LoanScheduleAmountTypes.Interest;
		EndIf;
		
		If CurrentAccrual.Commission <> 0 Then
			NewAccrualLine = Accruals.Add();
			FillPropertyValues(NewAccrualLine, CurrentAccrual);
			NewAccrualLine.Total = CurrentAccrual.Commission;
			NewAccrualLine.AmountType = Enums.LoanScheduleAmountTypes.Commission;
		EndIf;

	EndDo;
	
	AccrualAddressInStorage = PutToTempStorage(Accruals, UUID);
	
EndProcedure

#EndRegion

#EndRegion
