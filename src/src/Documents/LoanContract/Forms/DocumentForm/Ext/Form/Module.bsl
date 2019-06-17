
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	StructureByCurrency = InformationRegisters.ExchangeRates.GetLast(Object.Date, New Structure("Currency", Object.SettlementsCurrency));
	Rate = ?(
		StructureByCurrency.ExchangeRate = 0,
		1,
		StructureByCurrency.ExchangeRate
	);
	Multiplicity = ?(
		StructureByCurrency.ExchangeRate = 0,
		1,
		StructureByCurrency.Multiplicity
	);

	LoanKindOnCreation			= Object.LoanKind;
	CounterpartyWhenCreating	= Object.Counterparty;
	EmployeeWhenCreating		= Object.Employee;
	CompanyWhenCreating			= Object.Company;
	SettlementsCurrency			= Object.SettlementsCurrency;
	
	DocumentDate = Object.Date;
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentDate();
	EndIf;
	
	If Parameters.Key.IsEmpty() Then
		DueDate = 1;
	Else
		DueDate = LoansToEmployeesClientServer.DueDateByEndDate(Object.Maturity, 
			?(Object.FirstRepayment = '00010101', 
				Object.Issued, 
				AddMonth(Object.FirstRepayment, -1)));
	EndIf;
	
	If Not ValueIsFilled(Object.Ref)
		AND Not ValueIsFilled(Parameters.CopyingValue) Then
		
		DueDate = 1;
		
		Object.Issued				= CurrentDate();
		Object.Maturity				= AddMonth(BegOfDay(Object.Issued) - 1, DueDate);
		Object.FirstRepayment		= AddMonth(Object.Issued, 1);
		
		If ValueIsFilled(Parameters.Basis) Then
			SetDefaultValuesForLoanKind();
		EndIf;
		
	Else
		DueDate = LoansToEmployeesClientServer.DueDateByEndDate(Object.Maturity, 
			?(Object.FirstRepayment = '00010101',
				Object.Issued, 
				AddMonth(Object.FirstRepayment, -1)));
	EndIf;
	
	// Predefined values
	RepaymentOptionMonthly		= Enums.OptionsOfLoanRepaymentByEmployee.MonthlyRepayment;
	LoanKindLoanContract		= Enums.LoanContractTypes.EmployeeLoanAgreement;
	NoCommissionType			= Enums.LoanCommissionTypes.No;
	CommissionTypeBySchedule	= Enums.LoanCommissionTypes.CustomSchedule;
	// End Predefined values
	
	CommissionType = Object.CommissionType;
	
	AccountingPolicy = InformationRegisters.AccountingPolicy.GetAccountingPolicy();
	FunctionalOptionCashMethodOfIncomeAndExpenseAccounting = AccountingPolicy.CashMethodOfAccounting;
	
	SetItemVisibilityDependingOnLoanKind();
	SetAccountingParameterVisibilityOnServer();
	
	CurrentSystemUser = UsersClientServer.CurrentUser();
	
	If Not Object.Ref.IsEmpty() Then
		If ThereRecordsUnderTheContract(Object.Ref) Then
			Items.GroupGLAccountsColumns.Tooltip = 
				NStr("en = 'It is not recommended to change GL accounts after subsidary documents have been posted.'");
		EndIf;
	EndIf;
		
	DriveClientServer.SetPictureForComment(Items.PageIssue, Object.Comment);
	
	// StandardSubsystems.ObjectVersioning
	ObjectVersioning.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.ObjectVersioning
	
	// StandardSubsystems.ObjectAttributeEditProhibition
	ObjectsAttributesEditProhibition.LockAttributes(ThisForm);
	// End StandardSubsystems.ObjectAttributeEditingProhibition
	
	// StandardSubsystems.Properties
	AdditionalParameters = PropertiesManagementOverridable.FillAdditionalParameters(Object, "AdvancedPage");
	PropertiesManagement.OnCreateAtServer(ThisObject, AdditionalParameters);
	// End StandardSubsystems.Properties
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	// StandardSubsystems.Properties
	PropertiesManagementClient.AfterAdditionalAttributeImport(ThisObject);
	// End StandardSubsystems.Properties
	
	SetVisibilityOfItems();
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	// StandardSubsystems.Properties
	If PropertiesManagementClient.ProcessAlerts(ThisObject, EventName, Parameter) Then 
		UpdateAdditionalAttributesItems();
		PropertiesManagementClient.AfterAdditionalAttributeImport(ThisObject);
	EndIf;
	// End StandardSubsystems.Properties
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	// StandardSubsystems.EditProhibitionDates
	ClosingDates.ObjectOnReadAtServer(ThisForm, CurrentObject);
	// End StandardSubsystems.ChangeClosingDates
	
	// StandardSubsystems.Properties
	PropertiesManagement.OnReadAtServer(ThisForm, CurrentObject);
	// End StandardSubsystems.Properties
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	If Not Object.Ref.IsEmpty() Then
		CheckChangePossibility(Cancel);
		
		If Not Cancel Then
			
			LoanKindOnCreation			= Object.LoanKind;
			CounterpartyWhenCreating	= Object.Counterparty;
			EmployeeWhenCreating		= Object.Employee;
			CompanyWhenCreating			= Object.Company;
			
		EndIf;
	EndIf;
	
	If Cancel Then
		Return;
	EndIf;
	
	// StandardSubsystems.Properties
	PropertiesManagement.BeforeWriteAtServer(ThisForm, CurrentObject);
	// End StandardSubsystems.Properties
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	// Handler of subsystem of object attribute editing prohibition
	ObjectsAttributesEditProhibition.LockAttributes(ThisForm);
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, AttributesToCheck)
	
	// StandardSubsystems.Properties
	PropertiesManagement.FillCheckProcessing(ThisForm, Cancel, AttributesToCheck);
	// End StandardSubsystems.Properties
	
EndProcedure

#EndRegion

#Region FormHeaderItemEventHandlers

&AtClient
Procedure CommissionAmountOnChange(Item)
	PopulatePaymentAmount();
EndProcedure

&AtClient
Procedure CommissionTypeOnChange(Item)
	
	ConfigureItemsByCommissionTypeAndLoanKind();
	ClearAttributesDependingOnCommissionType();
	PopulatePaymentAmount();
	
EndProcedure

&AtClient
Procedure AnnualInterestRateOnChange(Item)
	
	PopulatePaymentAmount();
	SetDeductionVisibility();
	
EndProcedure

&AtClient
Procedure RepaymentOptionOnCange(Item)
	
	RepaymentOptionWhenChangingOnServer();
	PopulatePaymentAmount();
	
EndProcedure

&AtClient
Procedure DocumentAmountOnChange(Item)	
	PopulatePaymentAmount();	
EndProcedure

&AtClient
Procedure IssuedOnChange(Item)
	
	PopulateEndDateByDueDate(Object.Issued);
	
	Object.FirstRepayment = AddMonth(Object.Issued, 1);
	
	If EndOfDay(Object.Issued) = EndOfMonth(Object.Issued) Then
		Object.FirstRepayment = EndOfMonth(Object.FirstRepayment);
	EndIf;
	
	PopulatePaymentAmount();
	
EndProcedure

&AtClient
Procedure DueDateOnChange(Item)
	
	If Object.FirstRepayment = '00010101' Then
		If EndOfDay(Object.Issued) = EndOfMonth(Object.Issued) Then
			Object.FirstRepayment = EndOfMonth(AddMonth(Object.Issued, 1));
		Else
			Object.FirstRepayment = AddMonth(Object.Issued, 1);
		EndIf;
	EndIf;
	
	If EndOfDay(Object.FirstRepayment) = EndOfMonth(Object.FirstRepayment) Then
		StartDate = EndOfMonth(AddMonth(Object.FirstRepayment, -1));
	Else
		StartDate = AddMonth(Object.FirstRepayment, -1);
	EndIf;
	
	PopulateEndDateByDueDate(StartDate);
	PopulatePaymentAmount();
	
EndProcedure

&AtClient
Procedure EndDateOnChange(Item)
	
	PopulateDueDateByEndDate(Object.Issued);
	PopulatePaymentAmount();
	
EndProcedure

&AtClient
Procedure FirstRepaymentOnChange(Item)
	
	If Object.FirstRepayment = '00010101' Then
		Object.FirstRepayment = AddMonth(Object.Issued, 1);
	EndIf;
	
	PopulateEndDateByDueDate(AddMonth(Object.FirstRepayment, -1));
	PopulatePaymentAmount();
	
EndProcedure

&AtClient
Procedure LoanKindOnChange(Item)	
	LoanKindWhenChangingOnServer();
EndProcedure

&AtClient
Procedure GLAccountOnChange(Item)	
	GLAccountWhenChangingOnServer();	
EndProcedure

&AtClient
Procedure PaymentTermsOnChange(Item)	
	
	PopulatePaymentAmount();
	SetVisibilityOfItems();
	
EndProcedure

&AtClient
Procedure DaysInYear360OnChange(Item)	
	PopulatePaymentAmount();	
EndProcedure

&AtClient
Procedure InterestGLAccountOnChange(Item)	
	InterestGLAccountWhenChangingOnServer();	
EndProcedure

&AtClient
Procedure CommissionGLAccountOnChange(Item)
	
	CommissionGLAccountWhenChangingOnServer();
	
EndProcedure

&AtClient
Procedure CommentOnChange(Item)
	
	AttachIdleHandler("Connected_SetPictureForComment", 0.5, True);
	
EndProcedure

&AtClient
Procedure ChargeFromSalaryOnChange(Item)
	
	SetDeductionVisibility();
	
EndProcedure

&AtClient
Procedure Attachable_SetPictureForComment()
	
	DriveClientServer.SetPictureForComment(Items.PageIssue, Object.Comment);
	
EndProcedure

&AtClient
Procedure CommentStartChoice(Item, ChoiceData, StandardProcessing)
	
	CommonUseClient.ShowCommentEditingForm(Item.EditText, ThisObject, "Object.Comment");
	
EndProcedure

&AtClient
Procedure PagesIssueAndRepayLoanCreditWhenChangingPage(Item, CurrentPage)
	
	If Not IsBlankString(Object.Comment) AND Items.PageIssue.Picture = New Picture Then
		AttachIdleHandler("Connected_SetPictureForComment", 0.5, True);
	EndIf;
	
EndProcedure

#EndRegion

#Region HandlersOfEventsItemsTableFormPaymentsAndAccrualsSchedule

&AtClient
Procedure CashAssetsTypeOnChange(Item)
	SetVisibilityOfItems();
EndProcedure

&AtClient
Procedure PaymentsAndAccrualsScheduleInterestAmountOnChange(Item)
	
	CurrentData = Items.PaymentsAndAccrualsSchedule.CurrentData;
	RecalculatePaymentAmount(CurrentData);
	
EndProcedure

&AtClient
Procedure PaymentsAndAccrualsScheduleCommissionAmountOnChange(Item)
	
	CurrentData = Items.PaymentsAndAccrualsSchedule.CurrentData;
	RecalculatePaymentAmount(CurrentData);
	
EndProcedure

&AtClient
Procedure PaymentsAndAccrualsSchedulePrincipalDebtAmountOnChange(Item)
	
	CurrentData = Items.PaymentsAndAccrualsSchedule.CurrentData;
	RecalculatePaymentAmount(CurrentData);
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure PopulatePaymentsAndAccrualsSchedule(Command)
	
	If Object.Total = 0 Then
		CommonUseClientServer.MessageToUser(
			NStr("en = 'Amount is not populated'"),,
			"Object.Total");		
		Return;
	EndIf;
	
	PopulatePaymentsAndAccrualsScheduleOnServer();
	
EndProcedure

&AtClient
Procedure CreatePaymentReminders(Command)
	
	If Object.Ref.IsEmpty() Then
		ShowMessageBox(Undefined, NStr("en = 'Write the document.'"));
		Return;
	EndIf;
	
	If Object.PaymentsAndAccrualsSchedule.Count() = 0 Then
		ShowMessageBox(Undefined, NStr("en = 'Payment schedule is not filled in.'"));
		Return;
	EndIf;
	
	AddressPaymentsAndAccrualsScheduleInStorage = PlacePaymentsAndAccrualsScheduleToStorage();
	FilterParameters = New Structure("AddressPaymentsAndAccrualsScheduleInStorage,
		|Company,
		|Recorder,
		|DocumentFormID,
		|CounterpartyBank",
		AddressPaymentsAndAccrualsScheduleInStorage,
		Object.Company,
		Object.Ref,
		UUID,
		Object.Counterparty);
		
	OpenForm("Document.LoanContract.Form.ReminderCreationForm", 
		FilterParameters,
		ThisForm,,,,
		Undefined);	
		
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtServer
Procedure LoanKindWhenChangingOnServer()
	
	SetDefaultValuesForLoanKind();
	ClearAttributesNotRelatedToLoanKind();
	SetItemVisibilityDependingOnLoanKind();
	
EndProcedure

&AtServer
Procedure GLAccountWhenChangingOnServer()
	
	PopulateAccountingParameterValuesByDefaultOnServer();
	SetAccountingParameterVisibilityOnServer();
	
EndProcedure

&AtServer
Procedure InterestGLAccountWhenChangingOnServer()
	
	PopulateAccountingParameterValuesByDefaultOnServer();
	SetAccountingParameterVisibilityOnServer();
	
EndProcedure

&AtServer
Procedure CommissionGLAccountWhenChangingOnServer()
	
	PopulateAccountingParameterValuesByDefaultOnServer();
	SetAccountingParameterVisibilityOnServer();
	
EndProcedure

&AtClient
Procedure ClearAttributesDependingOnCommissionType()

	PreviousCommissionType = CommissionType;
	CommissionType = Object.CommissionType;
	
	If PreviousCommissionType <> CommissionType Then
		If CommissionType = CommissionTypeBySchedule OR CommissionType = NoCommissionType Then
			
			Object.Commission = 0;
			
			If CommissionType = NoCommissionType Then
				For Each CurrentScheduleLine In Object.PaymentsAndAccrualsSchedule Do
				
					CurrentScheduleLine.Commission = 0;
					RecalculatePaymentAmount(CurrentScheduleLine);
				
				EndDo;
			EndIf;		
		EndIf;
	EndIf;

EndProcedure

&AtServer
Procedure RepaymentOptionWhenChangingOnServer()

	PaymentAvailability = (Object.RepaymentOption = RepaymentOptionMonthly);
	
	Items.PaymentTerms.Enabled = PaymentAvailability;
	Items.PaymentsAndAccrualsSchedulePopulatePaymentsAndAccrualsSchedule.Enabled = PaymentAvailability;
	
EndProcedure

&AtServer
Procedure CheckChangePossibility(Cancel)
	
	If LoanKindOnCreation = Object.LoanKind 
		AND CounterpartyWhenCreating = Object.Counterparty 
		AND	EmployeeWhenCreating = Object.Employee 
		AND	CompanyWhenCreating = Object.Company Then
			Return;
	EndIf;
	
	Query = New Query;
	
	QueryText =
	"SELECT TOP 1
	|	LoanSettlements.Recorder
	|FROM
	|	AccumulationRegister.LoanSettlements AS LoanSettlements
	|WHERE
	|	(LoanSettlements.LoanKind <> &LoanKind
	|			OR (LoanSettlements.Counterparty <> &Counterparty AND &CheckCounterparty)
	|			OR (LoanSettlements.Counterparty <> &Employee AND &CheckEmployee)
	|			OR LoanSettlements.Company <> &Company)
	|	AND LoanSettlements.LoanContract = &CurrentContract";
	
	Query.Text = QueryText;
	Query.SetParameter("CurrentContract",	Object.Ref);
	Query.SetParameter("LoanKind",			Object.LoanKind);
	Query.SetParameter("Counterparty",		Object.Counterparty);
	Query.SetParameter("Employee",			Object.Employee);
	Query.SetParameter("Company",			DriveServer.GetCompany(Object.Company));
	Query.SetParameter("CheckCounterparty",	Object.LoanKind = Enums.LoanContractTypes.Borrowed);
	Query.SetParameter("CheckEmployee",		Object.LoanKind = Enums.LoanContractTypes.EmployeeLoanAgreement);
	
	Selection = Query.Execute().Select();
	
	If Selection.Next() Then
		MessageText = NStr("en = 'There are documents in the base where the current contract is selected. 
		                   |Cannot change company, contract kind, counterparty bank, and employee. 
		                   |To view a linked document list, use the More - Linked documents command.'");
		DriveServer.ShowMessageAboutError(ThisForm, MessageText, , , , Cancel);
	EndIf;
	
EndProcedure

// Function checks whether GL account can be changed.
//
&AtServerNoContext
Function ThereRecordsUnderTheContract(Ref)
	
	Query = New Query(
	"SELECT TOP 1
	|	LoanSettlements.Period,
	|	LoanSettlements.Recorder,
	|	LoanSettlements.LineNumber,
	|	LoanSettlements.Active,
	|	LoanSettlements.RecordType,
	|	LoanSettlements.LoanKind,
	|	LoanSettlements.Counterparty,
	|	LoanSettlements.Company,
	|	LoanSettlements.LoanContract,
	|	LoanSettlements.PrincipalDebt,
	|	LoanSettlements.PrincipalDebtCur,
	|	LoanSettlements.Interest,
	|	LoanSettlements.InterestCur,
	|	LoanSettlements.Commission,
	|	LoanSettlements.CommissionCur,
	|	LoanSettlements.DeductedFromSalary,
	|	LoanSettlements.PostingContent,
	|	LoanSettlements.StructuralUnit
	|FROM
	|	AccumulationRegister.LoanSettlements AS LoanSettlements
	|WHERE
	|	LoanSettlements.LoanContract = &Ref");
	
	Query.SetParameter("Ref", Ref);
	
	Result = Query.Execute();
	
	Return Not Result.IsEmpty();
	
EndFunction

// Procedure sets an end date by start date and number of months.
//
&AtClient
Procedure PopulateEndDateByDueDate(StartDate) Export
	
	If DueDate > 0 Then
		Object.Maturity = AddMonth(BegOfDay(StartDate) - 1, DueDate);
		
		If EndOfDay(StartDate) = EndOfMonth(StartDate) Then
			Object.Maturity = EndOfMonth(Object.Maturity);
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure PopulateDueDateByEndDate(StartDate) Export
	
	DueDate = LoansToEmployeesClientServer.DueDateByEndDate(Object.Maturity, StartDate);
	
EndProcedure

// Procedure fills in the payment amount depending on the payment kind and repayment option.
//
&AtClient
Procedure PopulatePaymentAmount()
	
	If Object.RepaymentOption = RepaymentOptionMonthly Then
		
		If Object.PaymentTerms = PredefinedValue("Enum.LoanRepaymentTerms.AnnuityPayments") Then
			Object.PaymentAmount = AnnuityPaymentAmount();
		ElsIf Object.PaymentTerms = PredefinedValue("Enum.LoanRepaymentTerms.FixedPrincipalPayments")
			OR Object.PaymentTerms = PredefinedValue("Enum.LoanRepaymentTerms.OnlyPrincipal") Then
			Object.PaymentAmount = Object.Total / DueDate;
		ElsIf Object.PaymentTerms = PredefinedValue("Enum.LoanRepaymentTerms.OnlyInterest") Then
			Object.PaymentAmount = Object.Total * object.InterestRate * 0.01 / 12;
		ElsIf Object.PaymentTerms = PredefinedValue("Enum.LoanRepaymentTerms.CustomSchedule") Then
			Object.PaymentAmount = Object.Total / DueDate;
		Else
			Object.PaymentAmount = 0;
		EndIf;
		
		If Object.PaymentTerms = PredefinedValue("Enum.LoanRepaymentTerms.FixedPrincipalPayments") 
			AND Not Object.DaysInYear360 Then
			Object.DaysInYear360 = True;
		EndIf;
		
	Else
		
		AccumulatedInterest = 0;
		MonthNumber = 1;
	
		StartMonth = BegOfMonth(Object.Issued);
		EndMonth = BegOfMonth(Object.Maturity);
		
		CurrentMonth = StartMonth;
		While CurrentMonth <= EndMonth Do
		
			DaysPerYear = NumberOfDaysInYear(Year(CurrentMonth), Object.DaysInYear360);
			
			If CurrentMonth = BegOfMonth(Object.Issued) Then
				// During the first month, determine the number of days from the actual loan issue
				// date (as interest is accrued on the next day).
				If CurrentMonth = EndMonth Then
					DaysInMonth = Min(Day(EndOfMonth(CurrentMonth)), Day(Object.Maturity)) - Day(Object.Issued);
				Else
					DaysInMonth = Day(EndOfMonth(CurrentMonth)) - Day(Object.Issued);
				EndIf;
			Else
				If CurrentMonth = EndMonth Then
					DaysInMonth = Min(Day(EndOfMonth(CurrentMonth)), Day(Object.Maturity));
				Else
					DaysInMonth = Day(EndOfMonth(CurrentMonth));
				EndIf;
			EndIf;
			
			InterestAccrual = Object.Total * Object.InterestRate * 0.01 * DaysInMonth / DaysPerYear;
			
			CurrentMonth	= AddMonth(CurrentMonth, 1);
			MonthNumber		= MonthNumber + 1;
			
			AccumulatedInterest = AccumulatedInterest + InterestAccrual;
			
		EndDo;
		
		Object.PaymentAmount = Object.Total + AccumulatedInterest;
		Object.PaymentsAndAccrualsSchedule.Clear();
		
		RemainingDebt = Object.PaymentAmount;
		CommissionAmount = GetCommissionAmount(Object.Total);
		
		NewScheduleLine = Object.PaymentsAndAccrualsSchedule.Add();
		NewScheduleLine.PaymentDate		= Object.Maturity;
		NewScheduleLine.Principal		= Object.Total;
		NewScheduleLine.Interest		= AccumulatedInterest;
		NewScheduleLine.PaymentAmount	= Object.PaymentAmount;
		NewScheduleLine.Commission 		= CommissionAmount;
		
		LineLoanKind = ?(Object.LoanKind = PredefinedValue("Enum.LoanContractTypes.EmployeeLoanAgreement"), 
		NStr("en = 'loan'"),
		NStr("en = 'loan'"));
		
		If Object.InterestRate <> 0 Then
			NewScheduleLine.Comment = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = '%1% of total %2 amount repaid.'"),
			Format(Object.PaymentAmount / RemainingDebt * 100, "NFD=2; NZ=0"),
			LineLoanKind);
		Else
			NewScheduleLine.Comment = "";
		EndIf;
		
		RemainingDebt = RemainingDebt - Object.PaymentAmount;
		
		NewScheduleLine.Comment = StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en = '%1 Debt balance is %2 (%3).'"),
		NewScheduleLine.Comment,
		Format(RemainingDebt, "NFD=2; NZ=0"),
		Object.SettlementsCurrency);
		
	EndIf;
	
EndProcedure

// Function determines a number of days in a month.
//
// Parameters:
//	Date - any month date
//
// Returns
//	- date, number of days
// in a month
&AtServerNoContext
Function NumberOfMonthDays(Date, DaysInYear360) Export
	
	If DaysInYear360 Then
		Return 30;
	Else
		Return Day(EndOfMonth(Date));
	EndIf;
	
EndFunction

// Function determines a number of days in a year.
//
//	Parameters:
// - Year - Number
&AtServerNoContext
Function NumberOfDaysInYear(Year, DaysInYear360) Export
	
	If DaysInYear360 Then
		Return 360;
	Else
		// If there are 29 days in February - then 366, otherwise 365.
		If Day(EndOfMonth(Date(Year, 2, 1))) = 29 Then
			Return 366;
		Else
			Return 365;
		EndIf;
	EndIf;
	
EndFunction

&AtServer
Function PlacePaymentsAndAccrualsScheduleToStorage()

	AddressInStorage = PutToTempStorage(Object.PaymentsAndAccrualsSchedule.Unload(), UUID);	
	Return AddressInStorage;

EndFunction

&AtClient
Procedure RecalculatePaymentAmount(CurrentData)	
	CurrentData.PaymentAmount = CurrentData.Principal + CurrentData.Interest + CurrentData.Commission;	
EndProcedure

&AtServer
Procedure RecalculatePaymentAmountOnServer(CurrentData)	
	CurrentData.PaymentAmount = CurrentData.Principal + CurrentData.Interest + CurrentData.Commission;	
EndProcedure

&AtServer
Procedure SetItemVisibilityDependingOnLoanKind()
	
	If Object.LoanKind = PredefinedValue("Enum.LoanContractTypes.Borrowed") Then
		
		Items.Employee.Visible											= False;
		Items.Counterparty.Visible										= True;
		Items.ChargeFromSalary.Visible									= False;
		Items.LabelSeparatorInsteadOfCheckBoxChargeFromSalary.Visible	= True;		
		
	Else
		
		Items.Employee.Visible											= True;
		Items.Counterparty.Visible 										= False;
		Items.ChargeFromSalary.Visible									= True;
		Items.LabelSeparatorInsteadOfCheckBoxChargeFromSalary.Visible 	= False;
			
	EndIf;
	
	ConfigureItemsByCommissionTypeAndLoanKind();
	SetDeductionVisibility();
	
EndProcedure

// Procedure sets visibility of items which are connected with the "DeductionPrincipalDebt" and "DeductionInterest" attributes.
&AtServer
Procedure SetDeductionVisibility()
	
	PrincipalDebtVisibility = GetFunctionalOption("UsePayrollSubsystem") 
		AND Object.ChargeFromSalary 
		AND Object.LoanKind = PredefinedValue("Enum.LoanContractTypes.EmployeeLoanAgreement");
	InterestVisibility = PrincipalDebtVisibility AND Object.InterestRate <> 0;
	
	Items.DeductionPrincipalDebt.Visible	= PrincipalDebtVisibility;
	Items.DeductionInterest.Visible			= InterestVisibility;
	
EndProcedure

// Procedure sets GL account values by default depending on the contract kind.
//
&AtServer
Procedure SetDefaultValuesForLoanKind()

	If Object.LoanKind = LoanKindLoanContract Then
		Object.GLAccount			= Catalogs.DefaultGLAccounts.GetDefaultGLAccount("LoansLentToEmployee");
		Object.InterestGLAccount	= Catalogs.DefaultGLAccounts.GetDefaultGLAccount("InterestReceivable");
		Object.CostAccount			= Catalogs.DefaultGLAccounts.GetDefaultGLAccount("InterestIncome");
		Object.ChargeFromSalary		= GetFunctionalOption("UsePayrollSubsystem"); 
	Else
		Object.GLAccount			= Catalogs.DefaultGLAccounts.GetDefaultGLAccount("LoansBorrowed");
		Object.InterestGLAccount	= Catalogs.DefaultGLAccounts.GetDefaultGLAccount("InterestPayable");
		Object.CostAccount			= Catalogs.DefaultGLAccounts.GetDefaultGLAccount("InterestExpensesOnLoansBorrowed");
		Object.CommissionGLAccount	= Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ComissionExpensesOnLoansBorrowed"); 
	EndIf;
	
	PopulateAccountingParameterValuesByDefaultOnServer();
	SetAccountingParameterVisibilityOnServer();
	
EndProcedure

&AtClient
Procedure SetVisibilityOfItems()
	
	Items.PaymentAmount.Visible = (Object.PaymentTerms = PredefinedValue("Enum.LoanRepaymentTerms.CustomSchedule"));

	If Object.CashAssetsType = PredefinedValue("Enum.CashAssetTypes.Cash") Then // Cash
		Items.CashAssetsTypeOfAccount.CurrentPage = Items.CashAssetsTypeOfAccountCash;
	ElsIf Object.CashAssetsType = PredefinedValue("Enum.CashAssetTypes.Noncash") Then // BankAccount
		Items.CashAssetsTypeOfAccount.CurrentPage = Items.CashAssetsTypeOfAccountBank;
	Else // Undefined
		Items.CashAssetsTypeOfAccount.CurrentPage = Items.CashAssetsTypeOfAccountNone;
	EndIf;

	
EndProcedure

// Procedure clears attributes depending on the selected contract kind.
//
&AtServer
Procedure ClearAttributesNotRelatedToLoanKind()

	If Object.LoanKind = LoanKindLoanContract Then
		
		Object.Counterparty		= Undefined;
		Object.Commission = 0;	
		
		For Each CurrentScheduleLine In Object.PaymentsAndAccrualsSchedule Do				
			CurrentScheduleLine.Commission = 0;
			RecalculatePaymentAmountOnServer(CurrentScheduleLine);		
		EndDo;
		
	Else
		Object.Employee = Undefined;
	EndIf;
	
EndProcedure

// Procedure sets attribute visibility depending on GL account type.
//
&AtServer
Procedure SetAccountingParameterVisibilityOnServer()

	If Object.GLAccount.TypeOfAccount = Enums.GLAccountsTypes.Expenses 
		OR Object.CommissionGLAccount.TypeOfAccount = Enums.GLAccountsTypes.Expenses 
		OR Object.InterestGLAccount.TypeOfAccount	= Enums.GLAccountsTypes.Expenses Then
			AccountingParameterVisibility = True;
	Else
		AccountingParameterVisibility = False;
	EndIf;
	
	Items.StructuralUnit.Visible	= AccountingParameterVisibility;
	Items.BusinessArea.Visible		= AccountingParameterVisibility;
	Items.Order.Visible				= AccountingParameterVisibility;
	
EndProcedure

// Procedure fills in attributes by default depending on GL account type.
//
&AtServer
Procedure PopulateAccountingParameterValuesByDefaultOnServer()
	
	If Object.GLAccount.TypeOfAccount				= Enums.GLAccountsTypes.Expenses 
		OR Object.CommissionGLAccount.TypeOfAccount	= Enums.GLAccountsTypes.Expenses 
		OR Object.InterestGLAccount.TypeOfAccount	= Enums.GLAccountsTypes.Expenses Then
	
		If Not ValueIsFilled(Object.StructuralUnit) Then
			SettingValue = DriveReUse.GetValueByDefaultUser(CurrentSystemUser, "MainDepartment");
			Object.StructuralUnit = ?(ValueIsFilled(SettingValue), SettingValue, Catalogs.BusinessUnits.MainDepartment);
		EndIf;
		
		Object.Order = Undefined;
		
	EndIf;
	
EndProcedure

// Procedure sets up items which are used for setting and filling in credit (loan) commission.
//
&AtServer
Procedure ConfigureItemsByCommissionTypeAndLoanKind()
	
	If Object.LoanKind = PredefinedValue("Enum.LoanContractTypes.Borrowed") Then
		
		Items.CommissionBySchedule.Visible	= True;
		Items.CommissionType.Visible		= True;
		Items.CommissionAmount.Visible		= True;
		
		ThereCommission	= (Object.CommissionType <> Enums.LoanCommissionTypes.No);
		
		Items.CommissionAmount.Visible 							= ThereCommission AND (Object.CommissionType <> Enums.LoanCommissionTypes.CustomSchedule);
		Items.PaymentsAndAccrualsScheduleCommissionAmount.Visible = ThereCommission;
		Items.CommissionGLAccount.Visible 						= ThereCommission;
		
	Else
		
		Items.PaymentsAndAccrualsScheduleCommissionAmount.Visible = False;
		Items.CommissionType.Visible							= False;
		Items.CommissionAmount.Visible							= False;
		Items.CommissionBySchedule.Visible						= False;
		Items.CommissionGLAccount.Visible						= False;
		
	EndIf;
	
	Items.RateExplanation.Visible = GetFunctionalOption("ForeignExchangeAccounting");
	
EndProcedure

#EndRegion

#Region FillInScheduleAndCalculatePaymentAmount

// Function returns the table with a repayment (payment) schedule if credit (loan) provision dates are in one month.
//
&AtServer
Function RepaymentScheduleOneMonth(PaymentAmount)
	
	RepaymentScheduleTable = New ValueTable;
	
	RepaymentScheduleTable.Columns.Add("MonthNumber", 				New TypeDescription("Number"));
	RepaymentScheduleTable.Columns.Add("Month",						New TypeDescription("Date"));
	RepaymentScheduleTable.Columns.Add("PaymentDate",				New TypeDescription("Date"));	
	RepaymentScheduleTable.Columns.Add("RemainingDebt",				New TypeDescription("Number"));
	RepaymentScheduleTable.Columns.Add("InterestAccrual", 			New TypeDescription("Number"));
	RepaymentScheduleTable.Columns.Add("InterestRepayment",			New TypeDescription("Number"));
	RepaymentScheduleTable.Columns.Add("CommissionAccrual", 		New TypeDescription("Number"));
	RepaymentScheduleTable.Columns.Add("CommissionRepayment",		New TypeDescription("Number"));
	RepaymentScheduleTable.Columns.Add("DebtRepayment",				New TypeDescription("Number"));
	RepaymentScheduleTable.Columns.Add("MonthlyPayment",			New TypeDescription("Number"));
	RepaymentScheduleTable.Columns.Add("MutualSettlementBalance",	New TypeDescription("Number"));
	
	// Process the situation when a loan is issued within one month.
	DaysInMonth = Day(Object.Maturity) - Day(Object.Issued) + 1; // Interest is accrued starting from the day after issue until the payment day inclusive.
		
	AccruedInterest 		= Object.Total * Object.InterestRate * 0.01 * DaysInMonth / NumberOfDaysInYear(Year(Object.Issued), Object.DaysInYear360);
	AccruedCommission 		= GetCommissionAmount(Object.Total);
	AccruedPrincipalDebt	= Object.Total;

	MonthlyPayment = AccruedInterest + AccruedPrincipalDebt + AccruedCommission;
	
	// Monthly payment loan amount and interest.
	ScheduleLine = RepaymentScheduleTable.Add();
	ScheduleLine.MonthNumber				= 1;
	ScheduleLine.RemainingDebt				= 0; 
	ScheduleLine.InterestAccrual			= AccruedInterest; 
	ScheduleLine.InterestRepayment			= AccruedInterest;
	ScheduleLine.CommissionAccrual			= AccruedCommission; 
	ScheduleLine.CommissionRepayment		= AccruedCommission;
	ScheduleLine.DebtRepayment				= AccruedPrincipalDebt; 
	ScheduleLine.MonthlyPayment				= MonthlyPayment;
	ScheduleLine.MutualSettlementBalance	= 0;
	ScheduleLine.PaymentDate				= EndOfDay(Object.Maturity)+1;
	
	Return RepaymentScheduleTable;
	
EndFunction

// Function returns the table with a repayment (payment) schedule if credit (loan) provision dates are in different months.
//
&AtServer
Function RepaymentScheduleSeveralMonths(PaymentAmount)
	
	RepaymentScheduleTable = New ValueTable;
	
	RepaymentScheduleTable.Columns.Add("MonthNumber", 				New TypeDescription("Number"));
	RepaymentScheduleTable.Columns.Add("Month",						New TypeDescription("Date"));
	RepaymentScheduleTable.Columns.Add("PaymentDate",				New TypeDescription("Date"));	
	RepaymentScheduleTable.Columns.Add("RemainingDebt",				New TypeDescription("Number"));
	RepaymentScheduleTable.Columns.Add("InterestAccrual", 			New TypeDescription("Number"));
	RepaymentScheduleTable.Columns.Add("InterestRepayment",			New TypeDescription("Number"));
	RepaymentScheduleTable.Columns.Add("CommissionAccrual", 		New TypeDescription("Number"));
	RepaymentScheduleTable.Columns.Add("CommissionRepayment",		New TypeDescription("Number"));
	RepaymentScheduleTable.Columns.Add("DebtRepayment",				New TypeDescription("Number"));
	RepaymentScheduleTable.Columns.Add("MonthlyPayment",			New TypeDescription("Number"));
	RepaymentScheduleTable.Columns.Add("MutualSettlementBalance",	New TypeDescription("Number"));
	
	// Determine some frequently used parameters.
	EndDate			= Object.Maturity;
	Issued			= Object.Issued;
	EndMonth		= BegOfMonth(Object.Maturity);
	PaymentAmount	= PaymentAmount;
	RepaymentAmount	= PaymentAmount;
	PaymentTerms	= Object.PaymentTerms;
	
	// Process the situation when a loan is issued within several months.
	// Populate the structure array, determine the function result for interpolation search according to the Remaining debt
	// field in the last item of the array.
	RemainingDebt				= Object.Total;
	AccumulatedInterest			= 0;
	AccumulatedPrincipalDebt	= 0;
	MutualSettlementBalance		= RemainingDebt;
	MonthNumber					= 1;
	
	// Payment kinds when the payment amount is determined according to the principal debt repayment amount and not
	// specified by the fixed amount.
	PaymentTermsRepaymentAmount = New Array;
	PaymentTermsRepaymentAmount.Add(PredefinedValue("Enum.LoanRepaymentTerms.FixedPrincipalPayments"));
	PaymentTermsRepaymentAmount.Add(PredefinedValue("Enum.LoanRepaymentTerms.OnlyPrincipal"));
	
	FirstRepayment = ?(Object.FirstRepayment = '00010101', AddMonth(Object.Issued, 1), Object.FirstRepayment);
	FirstRepaymentEqualsToMonthEnd = (EndOfDay(FirstRepayment) = EndOfMonth(FirstRepayment)); // If you add 1 month to 01/31, it will become 02/28 (or 02/29). If you add a month to 02/29, it will become 03/29, i.e. not the end of the month.
	
	NextPaymentDate = AddMonth(FirstRepayment, -1);
	
	If FirstRepaymentEqualsToMonthEnd Then
		NextPaymentDate = EndOfMonth(NextPaymentDate);
	EndIf;
	
	StartMonth		= BegOfMonth(NextPaymentDate);
	CurrentMonth	= StartMonth;
	
	While NextPaymentDate < EndDate Do
		
		// Example: payroll month from 04/10 - 05/10, i.e. from 04/10 to 05/09, and payment date is 05/10.
		// Calculate interest for a month.
		PreviousPaymentDate = NextPaymentDate;
		PaymentDate = AddMonth(NextPaymentDate, 1);
		
		If FirstRepaymentEqualsToMonthEnd Then
			PaymentDate = EndOfMonth(PaymentDate);
		EndIf;
		
		NextPaymentDate					= Min(PaymentDate, EndOfDay(EndDate) + 1);
		DaysInYearPreviousPaymentDate	= NumberOfDaysInYear(Year(PreviousPaymentDate), Object.DaysInYear360);
		DaysInYearNextPaymentDate		= NumberOfDaysInYear(Year(NextPaymentDate), Object.DaysInYear360);
		
		/////////////////////////////////////////////////////////////////////////////////////////////////
		// Calculate parameters to the month end.
		If Object.DaysInYear360 Then
			DaysInMonth = 30 - Min(Day(PreviousPaymentDate), 30);
		Else
			DaysInMonth = Day(EndOfMonth(PreviousPaymentDate)) - Day(PreviousPaymentDate);
		EndIf;
		
		InterestAccrualPrevious = Max(RemainingDebt, 0) * Object.InterestRate * 0.01 * DaysInMonth / DaysInYearPreviousPaymentDate;
		InterestAccrualPrevious = Round(InterestAccrualPrevious, 2);
		
		If PaymentTermsRepaymentAmount.Find(PaymentTerms) <> Undefined Then
		// Decrease the repayment amount proportionally to the time passed (from the issue date).
			AccruedPrincipalDebtPrevious = RepaymentAmount * DaysInMonth / NumberOfMonthDays(PreviousPaymentDate, Object.DaysInYear360);
			AccruedPrincipalDebtPrevious = Round(AccruedPrincipalDebtPrevious, 2);
		EndIf;
			
		// //////////////////////////////////////////////////////////////////////////////////////////////
		// Calculate parameters from the month start.
		If Object.DaysInYear360 Then
			DaysInMonth = Min(Day(NextPaymentDate), 30);
		Else
			DaysInMonth = Day(NextPaymentDate);
		EndIf;
		
		InterestAccrualNext = Max(RemainingDebt, 0) * Object.InterestRate * 0.01 * DaysInMonth / DaysInYearNextPaymentDate;
		InterestAccrualNext = Round(InterestAccrualNext, 2);
		
		If PaymentTermsRepaymentAmount.Find(PaymentTerms) <> Undefined Then
		// Decrease the repayment amount proportionally to the time passed (from the issue date).
			AccruedPrincipalDebtNext	= RepaymentAmount * DaysInMonth / NumberOfMonthDays(NextPaymentDate, Object.DaysInYear360);
			AccruedPrincipalDebtNext	= Round(AccruedPrincipalDebtNext, 2);
		EndIf;
		
		InterestAccrual	= InterestAccrualPrevious + InterestAccrualNext;
		
		If PaymentTermsRepaymentAmount.Find(PaymentTerms) <> Undefined Then
			AccruedPrincipalDebt = AccruedPrincipalDebtPrevious + AccruedPrincipalDebtNext;
		Else
			AccruedPrincipalDebt = PaymentAmount - InterestAccrual;
		EndIf;
		
		// calculate repayment
		InterestRepayment	= 0;
		DebtRepayment		= 0;
		MonthlyPayment		= 0;
		
		If Object.RepaymentOption = PredefinedValue("Enum.OptionsOfLoanRepaymentByEmployee.MonthlyRepayment") Then
			
			// Repaid within the period.
			If PaymentTerms = PredefinedValue("Enum.LoanRepaymentTerms.AnnuityPayments") Then
				MonthlyPayment		= PaymentAmount;
				InterestRepayment	= InterestAccrual;
				DebtRepayment		= MonthlyPayment - InterestRepayment;			
			ElsIf PaymentTerms = PredefinedValue("Enum.LoanRepaymentTerms.FixedPrincipalPayments") Then
				InterestRepayment	= InterestAccrual;
				DebtRepayment		= AccruedPrincipalDebt;
			ElsIf PaymentTerms = PredefinedValue("Enum.LoanRepaymentTerms.OnlyPrincipal") Then
				
				If CurrentMonth = EndMonth Then
					// Include the whole payment in the last month.
					InterestRepayment = AccumulatedInterest;
				EndIf;
				
				DebtRepayment = RepaymentAmount;
				
			ElsIf PaymentTerms = PredefinedValue("Enum.LoanRepaymentTerms.OnlyInterest") Then
				
				If CurrentMonth = EndMonth Then
					// Include the whole payment in the last month.
					DebtRepayment = AccumulatedPrincipalDebt;
				EndIf;
				
				InterestRepayment = InterestAccrual;
				
			ElsIf PaymentTerms = PredefinedValue("Enum.LoanRepaymentTerms.CustomSchedule") Then
				DebtRepayment = RepaymentAmount;
			EndIf;
			
		EndIf;
		
		// Include amount balance in the last month.
		If NextPaymentDate >= EndDate 
			AND	PaymentTerms <> PredefinedValue("Enum.LoanRepaymentTerms.AnnuityPayments") Then
			// Include the whole payment in the last month.
			InterestRepayment	= AccumulatedInterest	+ InterestAccrual;
			DebtRepayment		= RemainingDebt;
		EndIf;
		
		CommissionAccrual	= GetCommissionAmount(RemainingDebt);
		CommissionAccrual	= Round(CommissionAccrual, 2);
		CommissionRepayment	= CommissionAccrual;
		
		// Monthly payment loan amount and interest.
		MonthlyPayment = DebtRepayment + InterestRepayment + CommissionRepayment;
		
		MutualSettlementBalance = MutualSettlementBalance + InterestAccrual + CommissionAccrual - MonthlyPayment;
		
		ScheduleLine = RepaymentScheduleTable.Add();
		ScheduleLine.MonthNumber				= MonthNumber;
		ScheduleLine.Month						= CurrentMonth; 
		ScheduleLine.RemainingDebt				= RemainingDebt; 
		ScheduleLine.InterestAccrual			= InterestAccrual; 
		ScheduleLine.InterestRepayment			= InterestRepayment;
		ScheduleLine.CommissionAccrual			= CommissionAccrual; 
		ScheduleLine.CommissionRepayment		= CommissionRepayment;
		ScheduleLine.DebtRepayment				= DebtRepayment; 
		ScheduleLine.MonthlyPayment				= MonthlyPayment;
		ScheduleLine.MutualSettlementBalance	= MutualSettlementBalance;
		ScheduleLine.PaymentDate				= NextPaymentDate;
		
		// updating counters
		RemainingDebt				= RemainingDebt - DebtRepayment;
		AccumulatedInterest			= AccumulatedInterest + InterestAccrual - InterestRepayment;
		AccumulatedPrincipalDebt	= AccumulatedPrincipalDebt + AccruedPrincipalDebt - DebtRepayment;
		
		CurrentMonth = AddMonth(CurrentMonth, 1);
		MonthNumber = MonthNumber + 1;
		
	EndDo;
	
	// Small debt amount may not have been allocated after allocation. Allocate it to principal debt by reducing interest.
	// Start from the last line.
	If MutualSettlementBalance <> 0 AND RepaymentScheduleTable.Count() > 0 Then
		
		Cnt = RepaymentScheduleTable.Count() - 1;
		
		If MutualSettlementBalance > 0 Then
			
			While MutualSettlementBalance > 0 AND Cnt >= 0 Do;
				ScheduleLine = RepaymentScheduleTable[Cnt];
				
				If ScheduleLine.InterestRepayment >= MutualSettlementBalance Then
					
					ScheduleLine.DebtRepayment		= ScheduleLine.DebtRepayment + MutualSettlementBalance;
					ScheduleLine.InterestAccrual	= ScheduleLine.InterestAccrual - MutualSettlementBalance;
					ScheduleLine.InterestRepayment	= ScheduleLine.InterestRepayment - MutualSettlementBalance;
					MutualSettlementBalance			= 0;
					
				ElsIf ScheduleLine.InterestRepayment > 0 Then
					
					ScheduleLine.DebtRepayment		= ScheduleLine.DebtRepayment + ScheduleLine.InterestRepayment;
					ScheduleLine.InterestAccrual	= ScheduleLine.InterestAccrual - ScheduleLine.InterestRepayment;
					MutualSettlementBalance			= MutualSettlementBalance - ScheduleLine.InterestRepayment;
					ScheduleLine.InterestRepayment	= ScheduleLine.InterestRepayment - ScheduleLine.InterestRepayment;
					
				EndIf;
				
				Cnt = Cnt - 1;			
			EndDo;
			
		Else
			
			While MutualSettlementBalance < 0 AND Cnt >= 0 Do;
				ScheduleLine = RepaymentScheduleTable[Cnt];
				
				If ScheduleLine.DebtRepayment >= -MutualSettlementBalance Then
					
					ScheduleLine.DebtRepayment		= ScheduleLine.DebtRepayment + MutualSettlementBalance;
					ScheduleLine.InterestAccrual	= ScheduleLine.InterestAccrual - MutualSettlementBalance;
					ScheduleLine.InterestRepayment	= ScheduleLine.InterestRepayment - MutualSettlementBalance;

					MutualSettlementBalance			= 0;
					
				ElsIf ScheduleLine.DebtRepayment > 0 Then
					
					ScheduleLine.InterestAccrual	= ScheduleLine.InterestAccrual + ScheduleLine.DebtRepayment;
					ScheduleLine.InterestRepayment	= ScheduleLine.InterestRepayment + ScheduleLine.DebtRepayment;
					MutualSettlementBalance			= MutualSettlementBalance + ScheduleLine.DebtRepayment;
					ScheduleLine.DebtRepayment		= 0;
					
				EndIf;
				
				Cnt = Cnt - 1;
			EndDo;
			
		EndIf;
	EndIf;
	
	Return RepaymentScheduleTable;
	
EndFunction

// Fuction imitates loan repayment for the whole period with the specified parameters.
// Used while creating a repayment (payment) schedule, as well as while using methods of interpolation search for an
// optimal value of payment amount and repayment period.
// 
// Parameters:
//	- PaymentAmount - payment amount for which repayment schedule should be created.
//
// Returns - structure array with each structure representing a value describing loan repayment for a specific month.
//
&AtServer
Function RepaymentSchedule(PaymentAmount) Export
	
	// Determine some frequently used parameters.
	StartMonth	= BegOfMonth(Object.Issued);
	EndMonth	= BegOfMonth(Object.Maturity);
	
	// Process the situation when a loan is issued within one month.
	If StartMonth = EndMonth Then
		Return ValueToFormAttribute(RepaymentScheduleOneMonth(PaymentAmount),"RepaymentSchedule");
	Else
		Return ValueToFormAttribute(RepaymentScheduleSeveralMonths(PaymentAmount),"RepaymentSchedule");
	EndIf;
	
EndFunction

// Procedure fills in the payment schedule.
//
&AtServer
Procedure PopulatePaymentsAndAccrualsScheduleOnServer()
	
	Object.PaymentsAndAccrualsSchedule.Clear();
	
	PaymentAmount			= 0;
	MonthNumber				= 1;
	MutualSettlementBalance = Undefined;
	
	RepaymentSchedule(Object.PaymentAmount);
	
	RemainingDebt = Object.Total + RepaymentSchedule.Total("InterestAccrual") + RepaymentSchedule.Total("CommissionAccrual");
	AmountTotal		= RemainingDebt;
	ChargedAmount	= 0;
	
	For Each ScheduleLine In RepaymentSchedule Do
		
		RemainingDebt = RemainingDebt - ROUND(ScheduleLine.MonthlyPayment, 2);
		
		NewScheduleLine	= Object.PaymentsAndAccrualsSchedule.Add();
		NewScheduleLine.PaymentDate = ScheduleLine.PaymentDate;
		
		MonthlyPayment		= ScheduleLine.MonthlyPayment;
		CommissionRepayment = ScheduleLine.CommissionRepayment;

		NewScheduleLine.Commission		= CommissionRepayment;
		NewScheduleLine.PaymentAmount	= ScheduleLine.MonthlyPayment;
		NewScheduleLine.Principal		= ScheduleLine.DebtRepayment;
		NewScheduleLine.Interest		= ScheduleLine.InterestRepayment;
		
		ChargedAmount = ChargedAmount + NewScheduleLine.PaymentAmount;
		
		LineLoanKind = ?(Object.LoanKind = Enums.LoanContractTypes.EmployeeLoanAgreement, 
						NStr("en = 'loan'"),
						NStr("en = 'loan'"));
		
		If Object.InterestRate <> 0 Then
			NewScheduleLine.Comment = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = '%1% of total %2 amount repaid.'"),
				Format(ChargedAmount / AmountTotal * 100, "NFD=2; NZ=0"),
				LineLoanKind);
		Else
			NewScheduleLine.Comment = "";
		EndIf;
		
		NewScheduleLine.Comment = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = '%1 Debt balance is %2 (%3).'"),
				NewScheduleLine.Comment,
				Format(RemainingDebt, "NFD=2; NZ=0"),
				Object.SettlementsCurrency);
		
		MonthNumber = MonthNumber + 1;
		
	EndDo;
	
	Modified = True;
	
EndProcedure

&AtServer
Function GetCommissionAmount(RemainingDebt) Export
	
	If Object.CommissionType = Enums.LoanCommissionTypes.PercentOfPrincipal Then
		CommissionAmount = Object.Total * Object.Commission / 100;
	ElsIf Object.CommissionType = Enums.LoanCommissionTypes.PercentOfPrincipalBalance Then
		CommissionAmount = RemainingDebt * Object.Commission / 100;
	ElsIf Object.CommissionType = Enums.LoanCommissionTypes.AmountPerMonth Then
		CommissionAmount = Object.Commission;
	Else
		CommissionAmount = 0;
	EndIf;
	
	Return CommissionAmount;
	
EndFunction

// Procedure updates information in the Comment field of the PaymentsAndAccrualsSchedule tabular section.
//
&AtClient
Procedure UpdateInformationInFieldComment(Command)
	
	LineLoanKind = ?(Object.LoanKind = PredefinedValue("Enum.LoanContractTypes.EmployeeLoanAgreement"), 
	NStr("en = 'loan'"),
	NStr("en = 'loan'"));
	
	RemainingDebt	= Object.Total + Object.PaymentsAndAccrualsSchedule.Total("Interest") + Object.PaymentsAndAccrualsSchedule.Total("Commission");
	AmountTotal		= RemainingDebt;
	ChargedAmount	= 0;
	
	For Each ScheduleLine In Object.PaymentsAndAccrualsSchedule Do
		RemainingDebt = RemainingDebt - ScheduleLine.PaymentAmount;
		ChargedAmount = ChargedAmount + ScheduleLine.PaymentAmount;
		
		If Object.InterestRate <> 0 Then
			ScheduleLine.Comment = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = '%1% of total %2 amount repaid.'"),
			Format(ChargedAmount / AmountTotal * 100, "NFD=2; NZ=0"),
			LineLoanKind);
		Else
			ScheduleLine.Comment = "";
		EndIf;
		
		ScheduleLine.Comment = StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en = '%1 Debt balance is %2 (%3).'"),
				ScheduleLine.Comment,
				Format(RemainingDebt, "NFD=2; NZ=0"),
				Object.SettlementsCurrency);

	EndDo;
	
EndProcedure

// Method selects the amount of annuity payment (fixed for the whole loan repayment period).
//
// Parameters:
// - LoanData - structure
&AtClient
Function AnnuityPaymentAmount() Export
	
	// Search for the suitable payment amount using interpolation search:
	// - in the first approximation, the payment amount is equal to the annuity payment on one-off issue of all tranches
	// - receive the remaining debt after effecting all payments of this amount
	// - in the second approximation, the payment amount is 20% less
	// than annuity payment on one-off payment
	// - then decrease the payment amount proportionally to the remaining debt change.
	
	// Make the first assumption.
	Total = Object.Total;
	If BegOfMonth(Object.Issued) = BegOfMonth(Object.Maturity) Then
		
		DaysInMonth = Day(Object.Maturity) - Day(Object.Issued) + 1; // Interest is accrued starting from the day after issue until the payment day inclusive.
		AccruedInterest = Object.Total * Object.InterestRate * 0.01 * DaysInMonth / NumberOfDaysInYear(Year(Object.Issued), Object.DaysInYear360);
		
		Return Total + AccruedInterest;
		
	Else
		
		PreviousPaymentAmount = Total * LoansToEmployeesClientServer.AnnuityCoefficient(
					LoansToEmployeesClientServer.InterestRatePerMonth(Object.InterestRate) * 0.01, 
					LoansToEmployeesClientServer.DueDateByEndDate(Object.Maturity, Object.Issued));
		PreviousRemainingDebt = MutualSettlementBalanceUponCompletion(PreviousPaymentAmount);
		
		// No need to calculate if PreviousPaymentAmount fully covers the debt.
		If Not ValueIsFilled(PreviousRemainingDebt) Then
			Return PreviousPaymentAmount;
		EndIf;

		// Make the second assumption.
		CurrentPaymentAmount = PreviousPaymentAmount * 0.8;
		CurrentRemainingDebt = MutualSettlementBalanceUponCompletion(CurrentPaymentAmount);
		
		// Select payment amount until the selected amount does not lead to zero balance after all payments.
		While Round(CurrentRemainingDebt, 2) <> 0 
			AND (Round(CurrentRemainingDebt, 2) > 0.01 OR Round(CurrentRemainingDebt, 2) < -0.01)
			AND CurrentPaymentAmount <> PreviousPaymentAmount 
			AND CurrentRemainingDebt <> PreviousRemainingDebt Do
			
			ChangePaymentAmount		= CurrentPaymentAmount - PreviousPaymentAmount;
			PreviousPaymentAmount	= CurrentPaymentAmount;
			CurrentPaymentAmount	= CurrentPaymentAmount - ChangePaymentAmount - (PreviousRemainingDebt / (CurrentRemainingDebt - PreviousRemainingDebt)) * ChangePaymentAmount;
			PreviousRemainingDebt	= CurrentRemainingDebt;
			CurrentRemainingDebt	= MutualSettlementBalanceUponCompletion(CurrentPaymentAmount);
			
		EndDo;
		
		Return CurrentPaymentAmount;
		
	EndIf;
	
EndFunction

// Function determines a closing balance after all effected payments of this amount according to the fixed payment amount.
// Used for interpolation search for the payment amount.
// 
// Parameters:
// - PaymentAmount - fixed payment amount.
//
&AtClient
Function MutualSettlementBalanceUponCompletion(PaymentAmount)
	
	 RepaymentSchedule(PaymentAmount);
				
	If RepaymentSchedule.Count() = 0 Then
		Return Object.Total;
	EndIf;
	
	BalanceUponCompletion = RepaymentSchedule[RepaymentSchedule.Count()-1].MutualSettlementBalance;
	If BalanceUponCompletion <> 0 Then
		Return BalanceUponCompletion;
	EndIf;
	
	PostalCode = RepaymentSchedule.Count() - 1;
	While PostalCode >= 0 Do
		If RepaymentSchedule[PostalCode].RemainingDebt <> 0 Then
			Return RepaymentSchedule[PostalCode].MutualSettlementBalance;
		EndIf;
		PostalCode = PostalCode - 1;
	EndDo;
	
EndFunction

#EndRegion

#Region LibraryHandlers

// StandardSubsystems.ObjectAttributeEditProhibition
&AtClient
Procedure Attachable_AllowObjectAttributesEditing(Command)
	
	ObjectsAttributesEditProhibitionClient.AllowObjectAttributesEditing(ThisForm);
	
EndProcedure
// End StandardSubsystems.ObjectAttributeEditingProhibition

// StandardSubsystems.Properties

&AtServer
Procedure UpdateAdditionalAttributesItems()
	
	PropertiesManagement.UpdateAdditionalAttributesItems(ThisForm, FormAttributeToValue("Object"));
	
EndProcedure

&AtClient
Procedure UpdateAdditionalAttributeDependencies()
	PropertiesManagementClient.UpdateAdditionalAttributeDependencies(ThisObject);
EndProcedure

&AtClient
Procedure Attachable_WhenChangingAdditionalAttribute(Item)
	
	PropertiesManagementClient.UpdateAdditionalAttributeDependencies(ThisObject);
	
EndProcedure

&AtClient
Procedure Attachable_EditContentOfProperties(Command)
	
	PropertiesManagementClient.EditContentOfProperties(ThisForm, Object.Ref);
	
EndProcedure
// End StandardSubsystems.Properties

#EndRegion
