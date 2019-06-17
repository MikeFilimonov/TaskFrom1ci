#Region GeneralPurposeProceduresAndFunctions

&AtServerNoContext
// It receives data set from server for the DateOnChange procedure.
//
Function GetDataDateOnChange(DocumentRef, DateNew, DateBeforeChange)
	
	StructureData = New Structure();
	StructureData.Insert("DATEDIFF", DriveServer.CheckDocumentNumber(DocumentRef, DateNew, DateBeforeChange));
	
	Return StructureData;
	
EndFunction

&AtServerNoContext
// It receives data set from server for the ContractOnChange procedure.
//
Function GetCompanyDataOnChange(Company)
	
	StructureData = New Structure();
	StructureData.Insert("Company", DriveServer.GetCompany(Company));
	
	Return StructureData;
	
EndFunction

&AtClient
// Procedure - sets days of the week in the table header.
//
Procedure SetWeekDays()
	
	If Object.DataInputMethod <> PredefinedValue("Enum.TimeDataInputMethods.TotalForPeriod") Then
	
		AccordanceDaysOfWeek = New Map;
		AccordanceDaysOfWeek.Insert(1, "Mo");
		AccordanceDaysOfWeek.Insert(2, "Tu");
		AccordanceDaysOfWeek.Insert(3, "We");
		AccordanceDaysOfWeek.Insert(4, "Th");
		AccordanceDaysOfWeek.Insert(5, "Fr");
		AccordanceDaysOfWeek.Insert(6, "Sa");
		AccordanceDaysOfWeek.Insert(7, "Su"); 
		
		For Day = 1 To Day(EndOfMonth(Object.RegistrationPeriod)) Do
			Items["HoursWorkedByDaysFirstHours" + Day].Title = AccordanceDaysOfWeek.Get(WeekDay(Date(Year(Object.RegistrationPeriod), Month(Object.RegistrationPeriod), Day)));
		EndDo;
		
		For Day = 29 To Day(EndOfMonth(Object.RegistrationPeriod)) Do
			Items["HoursWorkedByDaysFirstHours" + Day].Visible = True;
			Items["HoursWorkedByDaysSecondHours" + Day].Visible = True;
			Items["HoursWorkedByDaysThirdHours" + Day].Visible = True;
			Items["HoursWorkedByDaysFirstTypeOfTime" + Day].Visible = True;
			Items["HoursWorkedByDaysSecondTypeOfTime" + Day].Visible = True;
			Items["HoursWorkedByDaysThirdTypeOfTime" + Day].Visible = True;
		EndDo;
		
		For Day = Day(EndOfMonth(Object.RegistrationPeriod)) + 1 To 31 Do
			Items["HoursWorkedByDaysFirstHours" + Day].Visible = False;
			Items["HoursWorkedByDaysSecondHours" + Day].Visible = False;
			Items["HoursWorkedByDaysThirdHours" + Day].Visible = False;
			Items["HoursWorkedByDaysFirstTypeOfTime" + Day].Visible = False;
			Items["HoursWorkedByDaysSecondTypeOfTime" + Day].Visible = False;
			Items["HoursWorkedByDaysThirdTypeOfTime" + Day].Visible = False;
		EndDo;
		
	EndIf;
	
EndProcedure

// Function - returns the position of employee.
//
&AtServerNoContext
Function FillPosition(Structure)
	
	Query = New Query(
	"SELECT
	|	EmployeesSliceLast.Position
	|FROM
	|	InformationRegister.Employees.SliceLast(
	|			&Date,
	|			Company = &Company
	|				AND Employee = &Employee) AS EmployeesSliceLast");
	
	Query.SetParameter("Date", Structure.Date);
	Query.SetParameter("Company", Structure.Company);
	Query.SetParameter("Employee", Structure.Employee);
	Result = Query.Execute();
	
	Return ?(Result.IsEmpty(), 
		Catalogs.Positions.EmptyRef(), 
			Result.Unload()[0].Position);
	
EndFunction
 
&AtServer
// The procedure fills in tabular section with department staff according to the production calendar.
//
Procedure FillTimesheet()
	
	Query = New Query;
		
	Query.SetParameter("Company", Company);
	Query.SetParameter("Calendar", Company.BusinessCalendar);
	Query.SetParameter("StructuralUnit", Object.StructuralUnit);
	Query.SetParameter("StartDate", Object.RegistrationPeriod);
	Query.SetParameter("EndDate", EndOfMonth(Object.RegistrationPeriod));
	
	Query.Text =
	"SELECT
	|	EmployeesSliceLast.Employee AS Employee,
	|	EmployeesSliceLast.Position AS Position
	|INTO YourEmployees
	|FROM
	|	InformationRegister.Employees.SliceLast(&StartDate, Company = &Company) AS EmployeesSliceLast
	|WHERE
	|	EmployeesSliceLast.StructuralUnit = &StructuralUnit
	|
	|UNION ALL
	|
	|SELECT DISTINCT
	|	Employees.Employee,
	|	Employees.Position
	|FROM
	|	InformationRegister.Employees AS Employees
	|WHERE
	|	Employees.Company = &Company
	|	AND Employees.Period between &StartDate AND &EndDate
	|	AND Employees.StructuralUnit = &StructuralUnit
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	EmployeeCalendar.Employee AS Employee,
	|	EmployeeCalendar.Position AS Position,
	|	EmployeeCalendar.ScheduleDate AS ScheduleDate,
	|	Employees.Period AS Period,
	|	CASE
	|		WHEN Employees.StructuralUnit = &StructuralUnit
	|				AND Employees.Position = EmployeeCalendar.Position
	|			THEN 8 * Employees.OccupiedRates
	|		ELSE 0
	|	END AS Hours,
	|	CASE
	|		WHEN Employees.StructuralUnit = &StructuralUnit
	|				AND Employees.Position = EmployeeCalendar.Position
	|			THEN 1
	|		ELSE 0
	|	END AS Days
	|FROM
	|	(SELECT
	|		YourEmployees.Employee AS Employee,
	|		YourEmployees.Position AS Position,
	|		CalendarSchedules.ScheduleDate AS ScheduleDate
	|	FROM
	|		YourEmployees AS YourEmployees
	|			LEFT JOIN InformationRegister.CalendarSchedules AS CalendarSchedules
	|			ON (TRUE)
	|	WHERE
	|		CalendarSchedules.Calendar = &Calendar
	|		AND CalendarSchedules.ScheduleDate between &StartDate AND &EndDate
	|		AND CalendarSchedules.DayIncludedInSchedule) AS EmployeeCalendar
	|		LEFT JOIN (SELECT
	|			&StartDate AS Period,
	|			EmployeesSliceLast.Employee AS Employee,
	|			EmployeesSliceLast.StructuralUnit AS StructuralUnit,
	|			EmployeesSliceLast.Position AS Position,
	|			EmployeesSliceLast.OccupiedRates AS OccupiedRates
	|		FROM
	|			InformationRegister.Employees.SliceLast(
	|					&StartDate,
	|					Company = &Company
	|						AND StructuralUnit = &StructuralUnit) AS EmployeesSliceLast
	|		
	|		UNION ALL
	|		
	|		SELECT
	|			Employees.Period,
	|			Employees.Employee,
	|			Employees.StructuralUnit,
	|			Employees.Position,
	|			Employees.OccupiedRates
	|		FROM
	|			InformationRegister.Employees AS Employees
	|		WHERE
	|			Employees.Company = &Company
	|			AND Employees.Period between DATEADD(&StartDate, Day, 1) AND &EndDate) AS Employees
	|		ON EmployeeCalendar.Employee = Employees.Employee
	|			AND EmployeeCalendar.ScheduleDate >= Employees.Period
	|
	|ORDER BY
	|	Employee,
	|	Position,
	|	ScheduleDate,
	|	Period DESC
	|TOTALS BY
	|	Employee,
	|	Position,
	|	ScheduleDate";
				   
	QueryResult = Query.ExecuteBatch();
	
	TimeKind = Catalogs.PayCodes.Work;
	
	If Object.DataInputMethod = Enums.TimeDataInputMethods.ByDays Then
		
		Object.HoursWorkedByDays.Clear();
		
		SelectionEmployee = QueryResult[1].Select(QueryResultIteration.ByGroups, "Employee");
		While SelectionEmployee.Next() Do
		
			SelectionPosition = SelectionEmployee.Select(QueryResultIteration.ByGroups, "Position");	
			While SelectionPosition.Next() Do
				
				NewRow 			= Object.HoursWorkedByDays.Add();
				NewRow.Employee 	= SelectionPosition.Employee;
				NewRow.Position 	= SelectionPosition.Position;
				
				SelectionScheduleDate = SelectionPosition.Select(QueryResultIteration.ByGroups, "ScheduleDate");	
				While SelectionScheduleDate.Next() Do
				
					Selection = SelectionScheduleDate.Select();
					While Selection.Next() Do
						
						If Selection.Hours > 0 Then
						
							Day = Day(SelectionScheduleDate.ScheduleDate);
							
							NewRow["FirstTimeKind" + Day] 	= TimeKind;
							NewRow["FirstHours" + Day] 		= Selection.Hours;	
						
						EndIf; 
						
						Break;
						
					EndDo; 
				
				EndDo; 
				
			EndDo;			
			
		EndDo;
		
	Else		
		
		Object.HoursWorkedPerPeriod.Clear();					   
					   
		SelectionEmployee = QueryResult[1].Select(QueryResultIteration.ByGroups, "Employee");
		While SelectionEmployee.Next() Do
		
			SelectionPosition = SelectionEmployee.Select(QueryResultIteration.ByGroups, "Position");	
			While SelectionPosition.Next() Do
				
				DaysNumber = 0;
				HoursCount = 0;
				
				SelectionScheduleDate = SelectionPosition.Select(QueryResultIteration.ByGroups, "ScheduleDate");	
				While SelectionScheduleDate.Next() Do
				
					Selection = SelectionScheduleDate.Select();
					While Selection.Next() Do
						DaysNumber 	= DaysNumber + Selection.Days;
						HoursCount = HoursCount + Selection.Hours;
						Break;
					EndDo; 
				
				EndDo; 
				
				NewRow 			= Object.HoursWorkedPerPeriod.Add();
				NewRow.Employee 	= SelectionPosition.Employee;
				NewRow.Position 	= SelectionPosition.Position;
				NewRow.TimeKind1 = TimeKind;
				NewRow.Days1 		= DaysNumber;
				NewRow.Hours1 		= HoursCount;
				
			EndDo;			
			
		EndDo;
		
	EndIf;
	
EndProcedure

&AtServerNoContext
// The function fills in the list of time kinds available for selection.
// In procedure the document number
// is cleared, and also the form functional options are configured.
// Overrides the corresponding form parameter.
//
Function GetChoiceList(ArrayRestrictions)

	Query = New Query("SELECT
	                      |	PayCodes.Ref
	                      |FROM
	                      |	Catalog.PayCodes AS PayCodes
	                      |WHERE
	                      |	(NOT PayCodes.Ref IN (&ArrayRestrictions))
	                      |
	                      |ORDER BY
	                      |	PayCodes.Description");
						  
	Query.SetParameter("ArrayRestrictions", ArrayRestrictions);					  
	Selection = Query.Execute().Select();
	
	ChoiceList = New ValueList;
	
	While Selection.Next() Do
		ChoiceList.Add(Selection.Ref);	
	EndDo; 
	
	Return ChoiceList

EndFunction

#Region ProcedureFormEventHandlers

&AtServer
// Procedure - event handler OnCreateAtServer of the form.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	DriveServer.FillDocumentHeader(Object,
	,
	Parameters.CopyingValue,
	Parameters.Basis,
	PostingIsAllowed,
	Parameters.FillingValues);
	
	If Not ValueIsFilled(Object.Ref)
		AND Not (Parameters.FillingValues.Property("RegistrationPeriod") AND ValueIsFilled(Parameters.FillingValues.RegistrationPeriod)) Then
		Object.RegistrationPeriod 	= BegOfMonth(CurrentDate());
	EndIf;
	
	RegistrationPeriodPresentation = Format(Object.RegistrationPeriod, "DF='MMMM yyyy'");
	
	// Form attributes setting.
	DocumentDate = Object.Date;
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentDate();
	EndIf;
	
	Company = DriveServer.GetCompany(Object.Company);
	If Object.DataInputMethod = PredefinedValue("Enum.TimeDataInputMethods.TotalForPeriod") Then
		Items.Pages.CurrentPage = Items.GroupHoursWorkedForPeriod;
	Else	
		Items.Pages.CurrentPage = Items.GroupHoursWorkedByDays;
	EndIf;
	
	If Object.DataInputMethod <> PredefinedValue("Enum.TimeDataInputMethods.TotalForPeriod") Then
	
		AccordanceDaysOfWeek = New Map;
		AccordanceDaysOfWeek.Insert(1, "Mo");
		AccordanceDaysOfWeek.Insert(2, "Tu");
		AccordanceDaysOfWeek.Insert(3, "We");
		AccordanceDaysOfWeek.Insert(4, "Th");
		AccordanceDaysOfWeek.Insert(5, "Fr");
		AccordanceDaysOfWeek.Insert(6, "Sa");
		AccordanceDaysOfWeek.Insert(7, "Su"); 
		
		For Day = 1 To Day(EndOfMonth(Object.RegistrationPeriod)) Do
			Items["HoursWorkedByDaysFirstHours" + Day].Title = AccordanceDaysOfWeek.Get(WeekDay(Date(Year(Object.RegistrationPeriod), Month(Object.RegistrationPeriod), Day)));
		EndDo;
		
		For Day = 28 To Day(EndOfMonth(Object.RegistrationPeriod)) Do
			Items["HoursWorkedByDaysFirstHours" + Day].Visible = True;
			Items["HoursWorkedByDaysSecondHours" + Day].Visible = True;
			Items["HoursWorkedByDaysThirdHours" + Day].Visible = True;
			Items["HoursWorkedByDaysFirstTypeOfTime" + Day].Visible = True;
			Items["HoursWorkedByDaysSecondTypeOfTime" + Day].Visible = True;
			Items["HoursWorkedByDaysThirdTypeOfTime" + Day].Visible = True;
		EndDo;
		
		For Day = Day(EndOfMonth(Object.RegistrationPeriod)) + 1 To 31 Do
			Items["HoursWorkedByDaysFirstHours" + Day].Visible = False;
			Items["HoursWorkedByDaysSecondHours" + Day].Visible = False;
			Items["HoursWorkedByDaysThirdHours" + Day].Visible = False;
			Items["HoursWorkedByDaysFirstTypeOfTime" + Day].Visible = False;
			Items["HoursWorkedByDaysSecondTypeOfTime" + Day].Visible = False;
			Items["HoursWorkedByDaysThirdTypeOfTime" + Day].Visible = False;
		EndDo;
		
	EndIf;
	
	If Not Constants.UseSecondaryEmployment.Get() Then
		If Items.Find("HoursWorkedDuringPeriodOfEmployeeCode") <> Undefined Then
			Items.HoursWorkedDuringPeriodOfEmployeeCode.Visible = False;
		EndIf;
		If Items.Find("HoursWorkedByDayOfEmployeeCode") <> Undefined Then
			Items.HoursWorkedByDayOfEmployeeCode.Visible = False;
		EndIf;
	EndIf;
	
	DriveClientServer.SetPictureForComment(Items.AdvancedPage, Object.Comment);
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisForm, Items.ImportantCommandsGroup);
	// End StandardSubsystems.Printing
	
EndProcedure

// Procedure - OnReadAtServer event handler.
//
&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	ClosingDates.ObjectOnReadAtServer(ThisForm, CurrentObject);
	
EndProcedure

&AtClient
// Procedure - form event handler ChoiceProcessing
//
Procedure ChoiceProcessing(ValueSelected, ChoiceSource)
	
	If TypeOf(ChoiceSource) = Type("ManagedForm")
		AND Find(ChoiceSource.FormName, "Calendar") > 0 Then
		
		Object.RegistrationPeriod = EndOfDay(ValueSelected);
		DriveClient.OnChangeRegistrationPeriod(ThisForm);
		SetWeekDays();
		
	EndIf;
	
EndProcedure

#EndRegion

#Region ProcedureActionsOfTheFormCommandPanels

// Procedure - event handler StartChoice of attribute RegistrationPeriod.
//
&AtClient
Procedure RegistrationPeriodStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing	 = False;
	
	CalendarDateOnOpen = ?(ValueIsFilled(Object.RegistrationPeriod), Object.RegistrationPeriod, DriveReUse.GetSessionCurrentDate());
	
	OpenForm("CommonForm.Calendar", DriveClient.GetCalendarGenerateFormOpeningParameters(CalendarDateOnOpen), ThisForm);
	
EndProcedure

// Procedure - event handler Management of attribute RegistrationPeriod.
//
&AtClient
Procedure RegistrationPeriodTuning(Item, Direction, StandardProcessing)
	
	DriveClient.OnRegistrationPeriodRegulation(ThisForm, Direction);
	DriveClient.OnChangeRegistrationPeriod(ThisForm);
	SetWeekDays();
	
EndProcedure

&AtClient
// Procedure - OnChange event handler of DataInputMethod attribute.
//
Procedure DataInputMethodOnChange(Item)
	
	If Object.DataInputMethod = PredefinedValue("Enum.TimeDataInputMethods.TotalForPeriod") Then	
		Items.Pages.CurrentPage = Items.GroupHoursWorkedForPeriod;	
	Else	
		Items.Pages.CurrentPage = Items.GroupHoursWorkedByDays;	
	EndIf;
	
	If Object.DataInputMethod = PredefinedValue("Enum.TimeDataInputMethods.TotalForPeriod") Then
		Object.HoursWorkedByDays.Clear();
	Else
		Object.HoursWorkedPerPeriod.Clear();
	EndIf;

EndProcedure

&AtClient
// Procedure - event handler OnChange of the Date input field.
// The procedure determines the situation when after changing the date
// of a document this document is found in another period
// of documents enumeration, and in this case the procedure assigns new unique number to the document.
// Overrides the corresponding form parameter.
//
Procedure DateOnChange(Item)
	
	// Date change event DataProcessor.
	DateBeforeChange = DocumentDate;
	DocumentDate = Object.Date;
	If Object.Date <> DateBeforeChange Then
		StructureData = GetDataDateOnChange(Object.Ref, Object.Date, DateBeforeChange);
		If StructureData.DATEDIFF <> 0 Then
			Object.Number = "";
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of the Company input field.
// In procedure the document number
// is cleared, and also the form functional options are configured.
// Overrides the corresponding form parameter.
//
Procedure CompanyOnChange(Item)

	// Company change event data processor.
	Object.Number = "";
	StructureData	= GetCompanyDataOnChange(Object.Company);
	Company			= StructureData.Company;
	
EndProcedure

#Region TabularSectionEventHandlers

&AtClient
// Procedure - event handler OnChange input field Employee.
// In procedure the document number
// is cleared, and also the form functional options are configured.
// Overrides the corresponding form parameter.
//
Procedure HoursWorkedPerPeriodEmployeeOnChange(Item)
	
	If Not ValueIsFilled(Object.RegistrationPeriod) Then
		Return;
	EndIf; 
	
	CurrentData = Items.HoursWorkedPerPeriod.CurrentData;
	
	Structure = New Structure;
	Structure.Insert("Date", EndOfMonth(Object.RegistrationPeriod));
	Structure.Insert("Company", Object.Company);
	Structure.Insert("Employee", CurrentData.Employee);
	CurrentData.Position = FillPosition(Structure);
	
EndProcedure

&AtClient
// Procedure - event handler OnChange input field Employee.
// In procedure the document number
// is cleared, and also the form functional options are configured.
// Overrides the corresponding form parameter.
//
Procedure HoursWorkedByDaysEmployeeOnChange(Item)
	
	If Not ValueIsFilled(Object.RegistrationPeriod) Then
		Return;
	EndIf; 
	
	CurrentData = Items.HoursWorkedByDays.CurrentData;
	
	Structure = New Structure;
	Structure.Insert("Date", EndOfMonth(Object.RegistrationPeriod));
	Structure.Insert("Company", Object.Company);
	Structure.Insert("Employee", CurrentData.Employee);
	CurrentData.Position = FillPosition(Structure);
	
EndProcedure

&AtClient
// Procedure - FillIn command handler.
// In procedure the document number
// is cleared, and also the form functional options are configured.
// Overrides the corresponding form parameter.
//
Procedure Fill(Command)
	
	If Not ValueIsFilled(Object.StructuralUnit) Then
		DriveClient.ShowMessageAboutError(Object, "Department is not specified.");
		Return;
	EndIf;
	
	If Object.RegistrationPeriod = '00010101000000' Then
		DriveClient.ShowMessageAboutError(Object, "Registration period is not specified.");
		Return;
	EndIf;
	
	Mode = QuestionDialogMode.YesNo;
	If Object.HoursWorkedByDays.Count() > 0
	 OR Object.HoursWorkedPerPeriod.Count() > 0 Then
		Response = Undefined;

		ShowQueryBox(New NotifyDescription("FillEnd", ThisObject), NStr("en = 'Tabular section will be cleared. Continue?'"), Mode, 0);
	Else
		FillTimesheet();
	EndIf;
	
EndProcedure

&AtClient
Procedure FillEnd(Result, AdditionalParameters) Export
    
    Response = Result;
    If Response = DialogReturnCode.Yes Then
        FillTimesheet();
    Else 
        Return;
    EndIf;

EndProcedure

&AtClient
// Procedure - OnChange event handler of TimeKind1 input field.
// In procedure the document number
// is cleared, and also the form functional options are configured.
// Overrides the corresponding form parameter.
//
Procedure HoursWorkedPerPeriodTimeKindStartChoice(Item, ChoiceData, StandardProcessing)	
	
	StandardProcessing = False;
	
	CurrentRow = Items.HoursWorkedPerPeriod.CurrentData;
	ItemNumber = Right(Item.Name, 1);
	
	ArrayRestrictions = New Array;
	For Counter = 1 To 6 Do
		If Counter = ItemNumber Then
			Continue;		
		EndIf; 
		ArrayRestrictions.Add(CurrentRow["TimeKind" + Counter]);	
	EndDo; 
	
	ChoiceData = GetChoiceList(ArrayRestrictions);
	
EndProcedure

&AtClient
// Procedure - OnChange event handler of FirstTimeKind input field.
//
Procedure HoursWorkedByDaysFirstTimeKindStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	CurrentRow = Items.HoursWorkedByDays.CurrentData;
	ItemNumber = StrReplace(Item.Name, "HoursWorkedByDaysFirstTypeOfTime", "");
	
	ArrayRestrictions = New Array;
	ArrayRestrictions.Add(CurrentRow["SecondTimeKind" + ItemNumber]);
	ArrayRestrictions.Add(CurrentRow["ThirdTimeKind" + ItemNumber]);
	
	ChoiceData = GetChoiceList(ArrayRestrictions);
	
EndProcedure

&AtClient
// Procedure - OnChange event handler of SecondTimeKind input field.
//
Procedure HoursWorkedByDaysSecondTimeKindStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	CurrentRow = Items.HoursWorkedByDays.CurrentData;
	ItemNumber = StrReplace(Item.Name, "HoursWorkedByDaysSecondTypeOfTime", "");
	
	ArrayRestrictions = New Array;
	ArrayRestrictions.Add(CurrentRow["FirstTimeKind" + ItemNumber]);
	ArrayRestrictions.Add(CurrentRow["ThirdTimeKind" + ItemNumber]);
	
	ChoiceData = GetChoiceList(ArrayRestrictions);
	
EndProcedure

&AtClient
// Procedure - OnChange event handler of ThirdTimeKind input field.
//
Procedure HoursWorkedByDaysThirdTimeKindStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	CurrentRow = Items.HoursWorkedByDays.CurrentData;
	ItemNumber = StrReplace(Item.Name, "HoursWorkedByDaysThirdTypeOfTime", "");
	
	ArrayRestrictions = New Array;
	ArrayRestrictions.Add(CurrentRow["SecondTimeKind" + ItemNumber]);
	ArrayRestrictions.Add(CurrentRow["FirstTimeKind" + ItemNumber]);
	
	ChoiceData = GetChoiceList(ArrayRestrictions);
	
EndProcedure

// Procedure - OnChange event handler of the Comment input field.
//
&AtClient
Procedure CommentOnChange(Item)
	
	AttachIdleHandler("Attachable_SetPictureForComment", 0.5, True);
	
EndProcedure

&AtClient
Procedure Attachable_SetPictureForComment()
	
	DriveClientServer.SetPictureForComment(Items.AdvancedPage, Object.Comment);
	
EndProcedure

#EndRegion

#Region LibrariesHandlers

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

// StandardSubsystems.Printing
&AtClient
Procedure Attachable_ExecutePrintCommand(Command)
	PrintManagementClient.ExecuteConnectedPrintCommand(Command, ThisObject, Object);
EndProcedure

// End StandardSubsystems.Printing

#EndRegion

#EndRegion

#EndRegion
