
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Parameters.Property("Parent", Parent);
	Object.EmploymentContractType = Enums.EmploymentContractTypes.FullTime;
	
	FillVariant = 1;
	EmploymentContractOccupiedRates = 1;
	
	SettlementsHumanResourcesGLAccount	= Catalogs.DefaultGLAccounts.GetDefaultGLAccount("PayrollPayable");
	AdvanceHoldersGLAccount				= Catalogs.DefaultGLAccounts.GetDefaultGLAccount("AdvanceHolders");
	OverrunGLAccount					= Catalogs.DefaultGLAccounts.GetDefaultGLAccount("AdvanceHoldersPayable");
	
	CompaniesUsed = GetFunctionalOption("UseSeveralCompanies");
	If CompaniesUsed Then
		
		AccountingByCompany = Constants.AccountingBySubsidiaryCompany.Get();
		If AccountingByCompany Then
			
			EmploymentContractCompany = Constants.ParentCompany.Get();
			CommonUseClientServer.SetFormItemProperty(Items, "EmploymentContractCompany", "Enabled", False);
			
		EndIf;
		
	Else
		
		EmploymentContractCompany = Catalogs.Companies.MainCompany;
		CommonUseClientServer.SetFormItemProperty(Items, "EmploymentContractCompany", "Enabled", False);
		
	EndIf;
	
	DepartmentsAreUsed = GetFunctionalOption("UseSeveralDepartments");
	If Not DepartmentsAreUsed Then
		
		EmploymentContractStructuralUnit = Catalogs.BusinessUnits.MainDepartment;
		
	EndIf;
	
	EmploymentContractCurrency = Constants.FunctionalCurrency.Get();
	UsedCurrencies = GetFunctionalOption("ForeignExchangeAccounting");
	CommonUseClientServer.SetFormItemProperty(Items, "EmploymentContractCurrency", "Visible", UsedCurrencies);
	
	UsedStaffSchedule = GetFunctionalOption("UseHeadcountBudget");
	
	CommonUseClientServer.SetFormItemProperty(Items, "EmploymentContractOccupiedRates", "Visible", UsedStaffSchedule);
	CommonUseClientServer.SetFormItemProperty(Items, "EmploymentContractAddRates", "Visible", UsedStaffSchedule);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	// Set the current table of transitions
	Scenario1GoToTable();
	
	// Position at the assistant's first step
	Iterator = 1;
	SetGoToNumber(Iterator);
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	WarningText = NStr("en = 'Close wizard?'");
	CommonUseClient.ShowArbitraryFormClosingConfirmation(
		ThisObject, Cancel, Exit, WarningText, "ForceCloseForm");
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure CommandNext(Command)
	
	ChangeGoToNumber(+1);
	
EndProcedure

&AtClient
Procedure CommandBack(Command)
	
	ChangeGoToNumber(-1);
	
EndProcedure

&AtClient
Procedure CommandDone(Command)
	
	ForceCloseForm = True;
	NotifyChoice(True);
	
	PageWritten_OnGoingNext();
	
EndProcedure

&AtClient
Procedure CommandCancel(Command)
	
	Close();
	
EndProcedure

#EndRegion

#Region FormAttributesHandlers

&AtClient
Procedure FillVariantOnChange(Item)
	
	Items.PagesFL.CurrentPage = ?(FillVariant = 1, Items.NewFL, Items.CurrentFL);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

#Region SuppliedPart

&AtClient
Procedure ChangeGoToNumber(IteratorLocally)
	
	ClearMessages();
	
	Iterator = IteratorLocally;
	If Iterator > 0 Then
		
		If GoToNumber = 2 Then
			
			If Not AssociateWithIndividual Then 
				
				// Ignore individual, skip one page
				Iterator = Iterator + 1;
				
			EndIf;
			
			If Not AssociateWithIndividual AND Not AcceptForEmploymentContract Then
				
				// Ignore employment, skip two more pages.
				Iterator = Iterator + 2;
				
			EndIf;
			
		EndIf;
		
		If GoToNumber = 3 Then
			
			If Not AcceptForEmploymentContract Then
				
				// Ignore employment, skip two pages
				Iterator = Iterator + 2;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	If Iterator < 0 Then
		
		If GoToNumber = 4 Then
			
			If Not AssociateWithIndividual Then
				
				// Ignore individual, skip one page
				Iterator = Iterator - 1;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	SetGoToNumber(GoToNumber + Iterator);
	
EndProcedure

&AtClient
Procedure SetGoToNumber(Val Value)
	
	IsGoNext = (Value > GoToNumber);
	
	GoToNumber = Value;
	
	If GoToNumber < 0 Then
		
		GoToNumber = 0;
		
	EndIf;
	
	GoToNumberOnChange(IsGoNext);
	
EndProcedure

&AtClient
Procedure GoToNumberOnChange(Val IsGoNext)
	
	// Executing the step change event handlers
	ExecuteGoToEventHandlers(IsGoNext);
	
	// Setting page visible
	GoToRowsCurrent = GoToTable.FindRows(New Structure("GoToNumber", GoToNumber));
	
	If GoToRowsCurrent.Count() = 0 Then
		Raise NStr("en = 'Page for displaying is not defined.'");
	EndIf;
	
	GoToRowCurrent = GoToRowsCurrent[0];
	
	Items.MainPanel.CurrentPage  = Items[GoToRowCurrent.MainPageName];
	Items.NavigationPanel.CurrentPage = Items[GoToRowCurrent.NavigationPageName];
	
	If Not IsBlankString(GoToRowCurrent.DecorationPageName) Then
		
		Items.DecorationPanel.CurrentPage = Items[GoToRowCurrent.DecorationPageName];
		
	EndIf;
	
	// Set current button by default
	ButtonNext = GetFormButtonByCommandName(Items.NavigationPanel.CurrentPage, "CommandNext");
	
	If ButtonNext <> Undefined Then
		
		ButtonNext.DefaultButton = True;
		
	Else
		
		DoneButton = GetFormButtonByCommandName(Items.NavigationPanel.CurrentPage, "CommandDone");
		
		If DoneButton <> Undefined Then
			
			DoneButton.DefaultButton = True;
			
		EndIf;
		
	EndIf;
	
	If IsGoNext AND GoToRowCurrent.LongAction Then
		
		AttachIdleHandler("ExecuteLongOperationHandler", 0.1, True);
		
	EndIf;
	
	Iterator = 1;
	
EndProcedure

&AtClient
Procedure ExecuteGoToEventHandlers(Val IsGoNext)
	
	// Transition events handlers
	If IsGoNext Then
		
		GoToRows = GoToTable.FindRows(New Structure("GoToNumber", GoToNumber - Iterator));
		
		If GoToRows.Count() > 0 Then
			
			GoToRow = GoToRows[0];
			
			// handler OnGoingNext
			If Not IsBlankString(GoToRow.GoNextHandlerName)
				AND Not GoToRow.LongAction Then
				
				ProcedureName = "Attachable_[HandlerName](Cancel)";
				ProcedureName = StrReplace(ProcedureName, "[HandlerName]", GoToRow.GoNextHandlerName);
				
				Cancel = False;
				
				A = Eval(ProcedureName);
				
				If Cancel Then
					
					SetGoToNumber(GoToNumber - Iterator);
					
					Return;
					
				EndIf;
				
			EndIf;
			
		EndIf;
		
	Else
		
		GoToRows = GoToTable.FindRows(New Structure("GoToNumber", GoToNumber + Iterator));
		
		If GoToRows.Count() > 0 Then
			
			GoToRow = GoToRows[0];
			
			// handler OnGoingBack
			If Not IsBlankString(GoToRow.GoBackHandlerName)
				AND Not GoToRow.LongAction Then
				
				ProcedureName = "Attachable_[HandlerName](Cancel)";
				ProcedureName = StrReplace(ProcedureName, "[HandlerName]", GoToRow.GoBackHandlerName);
				
				Cancel = False;
				
				A = Eval(ProcedureName);
				
				If Cancel Then
					
					SetGoToNumber(GoToNumber + Iterator);
					
					Return;
					
				EndIf;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	GoToRowsCurrent = GoToTable.FindRows(New Structure("GoToNumber", GoToNumber));
	
	If GoToRowsCurrent.Count() = 0 Then
		Raise NStr("en = 'Page for displaying is not defined.'");
	EndIf;
	
	GoToRowCurrent = GoToRowsCurrent[0];
	
	If GoToRowCurrent.LongAction AND Not IsGoNext Then
		
		SetGoToNumber(GoToNumber - 1);
		Return;
	EndIf;
	
	// handler OnOpen
	If Not IsBlankString(GoToRowCurrent.OnOpenHandlerName) Then
		
		ProcedureName = "Attachable_[HandlerName](Cancel, SkipPage, IsGoNext)";
		ProcedureName = StrReplace(ProcedureName, "[HandlerName]", GoToRowCurrent.OnOpenHandlerName);
		
		Cancel = False;
		SkipPage = False;
		
		A = Eval(ProcedureName);
		
		If Cancel Then
			
			SetGoToNumber(GoToNumber - 1);
			
			Return;
			
		ElsIf SkipPage Then
			
			If IsGoNext Then
				
				SetGoToNumber(GoToNumber + 1);
				
				Return;
				
			Else
				
				SetGoToNumber(GoToNumber - 1);
				
				Return;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ExecuteLongOperationHandler()
	
	GoToRowsCurrent = GoToTable.FindRows(New Structure("GoToNumber", GoToNumber));
	
	If GoToRowsCurrent.Count() = 0 Then
		Raise NStr("en = 'Page for displaying is not defined.'");
	EndIf;
	
	GoToRowCurrent = GoToRowsCurrent[0];
	
	// handler LongOperationHandling
	If Not IsBlankString(GoToRowCurrent.LongOperationHandlerName) Then
		
		ProcedureName = "Attachable_[HandlerName](Cancel, GoToNext)";
		ProcedureName = StrReplace(ProcedureName, "[HandlerName]", GoToRowCurrent.LongOperationHandlerName);
		
		Cancel = False;
		GoToNext = True;
		
		A = Eval(ProcedureName);
		
		If Cancel Then
			
			SetGoToNumber(GoToNumber - 1);
			
			Return;
			
		ElsIf GoToNext Then
			
			SetGoToNumber(GoToNumber + 1);
			
			Return;
			
		EndIf;
		
	Else
		
		SetGoToNumber(GoToNumber + 1);
		
		Return;
		
	EndIf;
	
EndProcedure

// Adds new row to the end of current transitions table
//
// Parameters:
//
//  TransitionSequenceNumber (mandatory) - Number. Sequence number of transition that corresponds
//  to the current MainPageName transition step (mandatory) - String. Page name of the MainPanel panel which corresponds
//  to the current number of transition NavigationPageName (mandatory) - String. Page name of the NavigationPanel panel,
//  which corresponds to the current number of transition DecorationPageName (optional) - String. Page name of the
//  DecorationPanel panel, which corresponds to the current number of transition DeveloperNameOnOpening (optional) -
//  String. Name of the function-processor of the HandlerNameOnGoingNext assistant current page open event (optional) -
//  String. Name of the function-processor of the HandlerNameOnGoingBack transition to the next assistant page event
//  (optional) - String. Name of the function-processor of the LongAction transition to assistant previous page event
//  (optional) - Boolean. Shows displayed long operation page.
//  True - long operation page is displayed; False - show normal page. Value by default - False.
// 
&AtClient
Procedure GoToTableNewRow(GoToNumber,
									MainPageName,
									NavigationPageName,
									DecorationPageName = "",
									OnOpenHandlerName = "",
									GoNextHandlerName = "",
									GoBackHandlerName = "",
									LongAction = False,
									LongOperationHandlerName = "")
	NewRow = GoToTable.Add();
	
	NewRow.GoToNumber = GoToNumber;
	NewRow.MainPageName     = MainPageName;
	NewRow.DecorationPageName    = DecorationPageName;
	NewRow.NavigationPageName    = NavigationPageName;
	
	NewRow.GoNextHandlerName = GoNextHandlerName;
	NewRow.GoBackHandlerName = GoBackHandlerName;
	NewRow.OnOpenHandlerName      = OnOpenHandlerName;
	
	NewRow.LongAction = LongAction;
	NewRow.LongOperationHandlerName = LongOperationHandlerName;
	
EndProcedure

&AtClient
Function GetFormButtonByCommandName(FormItem, CommandName)
	
	For Each Item In FormItem.ChildItems Do
		
		If TypeOf(Item) = Type("FormGroup") Then
			
			FormItemByCommandName = GetFormButtonByCommandName(Item, CommandName);
			
			If FormItemByCommandName <> Undefined Then
				
				Return FormItemByCommandName;
				
			EndIf;
			
		ElsIf TypeOf(Item) = Type("FormButton")
			AND Find(Item.CommandName, CommandName) > 0 Then
			
			Return Item;
			
		Else
			
			Continue;
			
		EndIf;
		
	EndDo;
	
	Return Undefined;
	
EndFunction

#EndRegion

#Region OverridablePart

#Region TransitionEventsHandlers

//Function
// Connected_PageTwo_OnGoingNext (Denial)
// Function Connected_PageTwo_OnGoingBack (Denial) Function Connected_PageTwo_OnOpen(Denial, SkipPage, Value IsGoingNext)
&AtClient
Function Attachable_PageEmployee1_OnGoingNext(Cancel)
	
	If IsBlankString(Object.Description) Then
		
		MessageText = NStr("en = 'Fill in employee''s full name.'");
		CommonUseClientServer.MessageToUser(MessageText, , "Object.Description", , Cancel);
		
	EndIf;
	
EndFunction

&AtClient
Function Attachable_PageFL_OnGoingNext(Cancel)
	Var Errors;
	
	CheckInd(Errors);
	
	CommonUseClientServer.ShowErrorsToUser(Errors, Cancel);
	
EndFunction

&AtClient
Function Attachable_PageEmploymentContract1_OnGoingNext(Cancel)
	Var Errors;
	
	If Not ValueIsFilled(EmploymentContractEmploymentContractDate) Then
		
		MessageText = NStr("en = 'Fill in hiring date.'");
		CommonUseClientServer.AddUserError(Errors, "EmploymentContractEmploymentContractDate", MessageText, Undefined);
		
	EndIf;
	
	If Not ValueIsFilled(EmploymentContractCompany) Then
		
		MessageText = NStr("en = 'Fill in company.'");
		CommonUseClientServer.AddUserError(Errors, "EmploymentContractCompany", MessageText, Undefined);
		
	EndIf;
	
	If DepartmentsAreUsed
		AND Not ValueIsFilled(EmploymentContractStructuralUnit) Then
		
		MessageText = NStr("en = 'Fill in department.'");
		CommonUseClientServer.AddUserError(Errors, "EmploymentContractStructuralUnit", MessageText, Undefined);
		
	EndIf;
	
	If Not ValueIsFilled(EmploymentContractPosition) Then
		
		MessageText = NStr("en = 'Fill in employee''s position.'");
		CommonUseClientServer.AddUserError(Errors, "EmploymentContractPosition", MessageText, Undefined);
		
	EndIf;
	
	If UsedStaffSchedule Then
		
		If Not ValueIsFilled(EmploymentContractOccupiedRates) Then
			
			MessageText = NStr("en = 'Fill in quantity of held rates.'");
			CommonUseClientServer.AddUserError(Errors, "EmploymentContractOccupiedRates", MessageText, Undefined);
			
		Else
			
			DataStructure = New Structure;
			DataStructure.Insert("EmploymentContractDate", EmploymentContractEmploymentContractDate);
			DataStructure.Insert("Company", EmploymentContractCompany);
			DataStructure.Insert("StructuralUnit", EmploymentContractStructuralUnit);
			DataStructure.Insert("Position", EmploymentContractPosition);
			DataStructure.Insert("PlannedTakeRates", EmploymentContractOccupiedRates);
			DataStructure.Insert("AddRates", EmploymentContractAddRates);
			
			RunControlStaffSchedule(DataStructure, Errors, Cancel);
			
		EndIf;
		
	EndIf;
	
	CommonUseClientServer.ShowErrorsToUser(Errors, Cancel);
	
EndFunction

&AtClient
Function Attachable_PageEmploymentContract2_OnGoingNext(Cancel)
	Var Errors;
	
	If EarningsAndDeductions.Count() < 1 Then
		
		MessageText = NStr("en = 'Fill in the table of earnings and deductions.'");
		CommonUseClientServer.AddUserError(Errors, "EarningsAndDeductions", MessageText, Undefined);
		
	EndIf;
	
	CommonUseClientServer.ShowErrorsToUser(Errors, Cancel);
	
EndFunction

&AtClient
Function PageWritten_OnGoingNext()
	
	If CreateApplicationUser Then
		
		FillingValues = New Structure("Description", Object.Description);
		OpenForm("Catalog.Users.ObjectForm", New Structure("FillingValues", FillingValues));
		
	EndIf;
	
EndFunction

// Next transfer handler (to the next page) on leaving WaitingPage assistant page
//
// Parameters:
// Cancel - Boolean - no going next check box;
// 				if you select this check box in the handler, you will not be transferred to the next page.
//
&AtClient
Function Attachable_WaitPage_LongOperationProcessing(Cancel, GoToNext)
	
	ExecuteLongOperationAtServer();
	
EndFunction

&AtServer
Procedure ExecuteLongOperationAtServer()
	
	Try
		
		BeginTransaction(DataLockControlMode.Managed);
		
		Block				= New DataLock;
		DataLockItem		= Block.Add("Catalog.Employees");
		DataLockItem.Mode	= DataLockMode.Shared;
		
		If AssociateWithIndividual AND FillVariant = 1 Then		
			DataLockItem = Block.Add("Catalog.Individuals");
			DataLockItem.Mode = DataLockMode.Shared;		
		EndIf;
		
		If AcceptForEmploymentContract Then		
			DataLockItem = Block.Add("Document.EmploymentContract");
			DataLockItem.Mode = DataLockMode.Shared;			
		EndIf;
		
		Block.Lock();
		
		// Individual record
		EventLogMonitorEvent = NStr("en = 'New employee ind. entry'", CommonUseClientServer.MainLanguageCode());
		If AssociateWithIndividual AND FillVariant = 1 Then
			
			NewInd = Catalogs.Individuals.CreateItem();
			NewInd.Description	= IndLastName + " " + IndFirstName;
			NewInd.FirstName	= IndFirstName;
			NewInd.LastName		= IndLastName;
			NewInd.Gender		= NewFLGender;
			NewInd.BirthDate	= NewFLBirthDate;
			NewInd.Write();
			
			Object.Ind = NewInd.Ref;
			
		EndIf;
	
		// Employee record
		EventLogMonitorEvent	= NStr("en = 'New employee record'", CommonUseClientServer.MainLanguageCode());
		NewEmployee				= Catalogs.Employees.CreateItem();
		FillPropertyValues(NewEmployee, Object);
		NewEmployee.Parent		= Parent;
		NewEmployee.Write();
		
		// EmploymentContract
		If AcceptForEmploymentContract Then
			
			EventLogMonitorEvent = NStr("en = 'Add rates to staff list'", CommonUseClientServer.MainLanguageCode());
			If UsedStaffSchedule
				AND RatesFree < EmploymentContractOccupiedRates 
				AND EmploymentContractAddRates Then
				
				Filter = New Structure("Company, StructuralUnit, Position", EmploymentContractCompany, EmploymentContractStructuralUnit, EmploymentContractPosition);
				RecordsTable = InformationRegisters.HeadcountBudget.SliceLast(EmploymentContractEmploymentContractDate, Filter);
				
				RecordManager = InformationRegisters.HeadcountBudget.CreateRecordManager();
				RecordManager.Period				= EmploymentContractEmploymentContractDate;
				RecordManager.Company				= EmploymentContractCompany;
				RecordManager.StructuralUnit		= EmploymentContractStructuralUnit;
				RecordManager.Position				= EmploymentContractPosition;
				RecordManager.TariffRateCurrency	= EmploymentContractCurrency;
				
				If RecordsTable.Count() <> 0 Then
					
					RecordManager.NumberOfRates			= RecordsTable[0].NumberOfRates + ?(RatesFree < 0, RatesFree * -1, RatesFree) + EmploymentContractOccupiedRates;
					RecordManager.EarningAndDeductionType	= RecordsTable[0].EarningAndDeductionType;
					RecordManager.MinimumTariffRate		= RecordsTable[0].MinimumTariffRate;
					RecordManager.MaximumTariffRate		= RecordsTable[0].MaximumTariffRate;
					
				Else
					
					RecordManager.NumberOfRates = ?(RatesFree < 0, RatesFree * -1, RatesFree) + EmploymentContractOccupiedRates;
					
				EndIf;
				
				RecordManager.Write(True);
				
			EndIf;
			
			EventLogMonitorEvent			= NStr("en = 'New employee hiring entry'", CommonUseClientServer.MainLanguageCode());
			EmploymentContractObject		= Documents.EmploymentContract.CreateDocument();
			EmploymentContractObject.Date	= CurrentDate();
			DriveServer.FillDocumentHeader(EmploymentContractObject,,,, True);
			EmploymentContractObject.Company= EmploymentContractCompany;
			
			EmployeesPage					= EmploymentContractObject.Employees.Add();
			EmployeesPage.Period			= EmploymentContractEmploymentContractDate;
			EmployeesPage.Employee			= NewEmployee.Ref;
			EmployeesPage.StructuralUnit	= EmploymentContractStructuralUnit;
			EmployeesPage.Position			= EmploymentContractPosition;
			EmployeesPage.WorkSchedule		= EmploymentContractWorkSchedule;
			EmployeesPage.OccupiedRates		= EmploymentContractOccupiedRates;
			EmployeesPage.ConnectionKey		= 1;
			
			For Each TSRow In EarningsAndDeductions Do
				
				If ValueIsFilled(TSRow.EarningAndDeductionType) Then
					
					RowEarning						= EmploymentContractObject.EarningsDeductions.Add();
					RowEarning.EarningAndDeductionType	= TSRow.EarningAndDeductionType;
					RowEarning.Amount				= TSRow.Amount;
					RowEarning.Currency				= EmploymentContractCurrency;
					RowEarning.GLExpenseAccount		= TSRow.GLExpenseAccount;
					RowEarning.ConnectionKey		= 1;
					
				EndIf; 
				
			EndDo;
			
			EmploymentContractObject.Write(DocumentWriteMode.Posting);
			
		EndIf;
		
		CommitTransaction();
		
	Except		
		WriteLogEvent(EventLogMonitorEvent, EventLogLevel.Error, Metadata.Catalogs.Employees, , ErrorDescription());		
	EndTry;
	
EndProcedure

&AtServer
// Controls staff list
//
Procedure RunControlStaffSchedule(DataStructure, Errors, Cancel)
	
	Query = New Query(
	"SELECT
	|	StaffScheduleSliceLast.NumberOfRates AS NumberOfRates,
	|	StaffScheduleSliceLast.MinimumTariffRate,
	|	StaffScheduleSliceLast.MaximumTariffRate,
	|	StaffScheduleSliceLast.EarningAndDeductionType,
	|	StaffScheduleSliceLast.TariffRateCurrency
	|FROM
	|	InformationRegister.HeadcountBudget.SliceLast(
	|			&Period,
	|			Company = &Company
	|				AND StructuralUnit = &StructuralUnit
	|				AND Position = &Position) AS StaffScheduleSliceLast
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SUM(OccupiedRates.OccupiedRates1) AS OccupiedRates
	|FROM
	|	(SELECT
	|		SUM(EmployeesSliceLast.OccupiedRates) AS OccupiedRates1,
	|		MAX(EmployeesSliceLast.Period) AS Period,
	|		EmployeesSliceLast.Company AS Company,
	|		EmployeesSliceLast.StructuralUnit AS StructuralUnit,
	|		EmployeesSliceLast.Position AS Position
	|	FROM
	|		InformationRegister.Employees.SliceLast(&Period, ) AS EmployeesSliceLast
	|	
	|	GROUP BY
	|		EmployeesSliceLast.Company,
	|		EmployeesSliceLast.StructuralUnit,
	|		EmployeesSliceLast.Position) AS OccupiedRates
	|WHERE
	|	OccupiedRates.Company = &Company
	|	AND OccupiedRates.StructuralUnit = &StructuralUnit
	|	AND OccupiedRates.Position = &Position");
	
	Query.SetParameter("Period", 		DataStructure.EmploymentContractDate);
	Query.SetParameter("Company",	DataStructure.Company);
	Query.SetParameter("StructuralUnit", DataStructure.StructuralUnit);
	Query.SetParameter("Position", 		DataStructure.Position);
	
	BatchQueryExecutionResult = Query.ExecuteBatch();
	SelectionNumberOfRates = BatchQueryExecutionResult[0].Select();
	SampleReservedRates = BatchQueryExecutionResult[1].Select();
	
	MessageText = "";
	If DataStructure.AddRates Then // If you select add positions option, there will be no mistakes in absence of vacant positions.
		
		SelectionNumberOfRates.Next();
		SampleReservedRates.Next();
		RatesFree = ?(ValueIsFilled(SelectionNumberOfRates.NumberOfRates), SelectionNumberOfRates.NumberOfRates, 0) - ?(ValueIsFilled(SampleReservedRates.OccupiedRates), SampleReservedRates.OccupiedRates, 0);
		
	ElsIf Not SelectionNumberOfRates.Next() Then
		
		MessageText = NStr("en = 'Rates for position %3 are not available in the staff list of company %2 by business unit %2.'");
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessageText, DataStructure.Company, DataStructure.StructuralUnit, DataStructure.Position);
		
	Else
		
		SampleReservedRates.Next();
		RatesFree = SelectionNumberOfRates.NumberOfRates - ?(ValueIsFilled(SampleReservedRates.OccupiedRates), SampleReservedRates.OccupiedRates, 0);
		
		If RatesFree < DataStructure.PlannedTakeRates Then
			
			MessageText = NStr("en = 'There''s not enough vacant positions for job %3 according to business unit %2 in the company %1 staff list.
			                   |Vacant positions %4, required positions %5.'");
			MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessageText, DataStructure.Company, DataStructure.StructuralUnit, DataStructure.Position, RatesFree, DataStructure.PlannedTakeRates);
			
		EndIf;
		
	EndIf;
	
	If Not IsBlankString(MessageText) Then
		
		CommonUseClientServer.AddUserError(Errors, , MessageText, Undefined);
		Cancel = True;
		
	EndIf;
	
EndProcedure

Procedure CheckInd(Errors)
	
	If AssociateWithIndividual AND FillVariant = 1 Then
		
		If NOT ValueIsFilled(IndLastName) Then
			MessageText = NStr("en = 'Please enter the last name of the employee.'");
			CommonUseClientServer.AddUserError(Errors,, MessageText, Undefined);
		EndIf;

		If NOT ValueIsFilled(IndFirstName) Then
			MessageText = NStr("en = 'Please enter the first name of the employee.'");
			CommonUseClientServer.AddUserError(Errors,, MessageText, Undefined);
		EndIf;
		
	EndIf;
	
		
	If Object.EmploymentContractType = Enums.EmploymentContractTypes.FullTime
		AND ValueIsFilled(Object.Ind) Then
		
		MessageText = "";
		Query		= New Query;
		Query.SetParameter("Ind", Object.Ind);
		
		Query.Text = 
		"SELECT
		|	MAX(Employees.Period) AS DateOfReception,
		|	Employees.Employee.Ind AS Ind,
		|	Employees.Employee AS MainStaff
		|FROM
		|	InformationRegister.Employees AS Employees
		|WHERE
		|	Employees.Employee.EmploymentContractType = VALUE(Enum.EmploymentContractTypes.FullTime)
		|	AND Employees.Employee.Ind = &Ind
		|
		|GROUP BY
		|	Employees.Employee,
		|	Employees.Employee.Ind";
		
		Selection = Query.Execute().Select();
		If Selection.Next() Then
			
			MessageText = NStr("en = 'There is already full-time employee exists for selected individual.'");
			CommonUseClientServer.AddUserError(Errors, , MessageText, Undefined);
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region InitializeAssistantTransitions

// Procedure defines scripted transitions table No1.
// To fill transitions table, use TransitionsTableNewRow()procedure
//
&AtClient
Procedure Scenario1GoToTable()
	
	GoToTable.Clear();
	
	GoToTableNewRow(1, "PageEmployee1", "NavigationPageStart", "DecorationPageStart", , "PageEmployee1_OnGoingNext");
	GoToTableNewRow(2, "PageEmployee2", "NavigationPageContinuation", "DecorationPageContinuation");
	GoToTableNewRow(3, "PageFL", "NavigationPageContinuation", "DecorationPageContinuation", , "PageFL_OnGoingNext");
	GoToTableNewRow(4, "PageEmploymentContract1", "NavigationPageContinuation", "DecorationPageContinuation", , "PageEmploymentContract1_OnGoingNext");
	GoToTableNewRow(5, "PageEmploymentContract2", "NavigationPageContinuation", "DecorationPageContinuation", , "PageEmploymentContract2_OnGoingNext");
	GoToTableNewRow(6, "WaitPage", "NavigationPageWait", "DecorationPageContinuation",,,, True, "WaitPage_LongOperationProcessing");
	GoToTableNewRow(7, "PageWritten", "NavigationPageEnd", "DecorationPageEnd", , "PageWritten_OnGoingNext");
	
EndProcedure

#EndRegion

#EndRegion

#EndRegion
