#Region GeneralPurposeProceduresAndFunctions

&AtServer
// Function forms and performs query.
//
Function ExecuteQuery()

	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	EmployeesSliceLast.StructuralUnit AS Department,
	|	EarningsAndDeductions.Employee.Code AS EmployeeCode,
	|	EarningsAndDeductions.Employee AS Ind,
	|	EmployeesSliceLast.Position AS Position,
	|	CASE
	|		WHEN EarningsAndDeductions.EarningAndDeductionType.Type = VALUE(Enum.EarningAndDeductionTypes.Earning)
	|			THEN EarningsAndDeductions.Size
	|		ELSE 0
	|	END AS Size,
	|	CASE
	|		WHEN EarningsAndDeductions.EarningAndDeductionType.Type = VALUE(Enum.EarningAndDeductionTypes.Deduction)
	|				OR EarningsAndDeductions.EarningAndDeductionType.Type = VALUE(Enum.EarningAndDeductionTypes.Tax)
	|			THEN ISNULL(EarningsAndDeductions.AmountCur, 0)
	|		ELSE 0
	|	END AS AmountWithheld,
	|	CASE
	|		WHEN EarningsAndDeductions.EarningAndDeductionType.Type = VALUE(Enum.EarningAndDeductionTypes.Earning)
	|			THEN ISNULL(EarningsAndDeductions.AmountCur, 0)
	|		ELSE 0
	|	END AS AmountAccrued,
	|	Timesheet.DaysTurnover AS DaysWorked,
	|	Timesheet.HoursTurnover AS HoursWorked,
	|	ISNULL(DebtAtEnd.AmountCurBalance, 0) AS ClosingBalance,
	|	ISNULL(DebtPayable.AmountCurBalance, 0) AS DebtPayable,
	|	ChangeHistoryOfIndividualNamesSliceLast.Surname AS Surname,
	|	ChangeHistoryOfIndividualNamesSliceLast.Name AS Name,
	|	ChangeHistoryOfIndividualNamesSliceLast.Patronymic AS Patronymic,
	|	CASE
	|		WHEN ISNULL(ChangeHistoryOfIndividualNamesSliceLast.Surname, """") <> """"
	|			THEN ChangeHistoryOfIndividualNamesSliceLast.Surname + "" "" + ChangeHistoryOfIndividualNamesSliceLast.Name + "" "" + ChangeHistoryOfIndividualNamesSliceLast.Patronymic
	|		ELSE EarningsAndDeductions.Employee.Description
	|	END AS EmployeePresentation
	|FROM
	|	AccumulationRegister.EarningsAndDeductions AS EarningsAndDeductions
	|		LEFT JOIN AccumulationRegister.Payroll.Balance(
	|				&RegistrationEndOfPeriod,
	|				Company = &Company
	|					AND Currency = &Currency
	|					AND RegistrationPeriod < &RegistrationPeriod
	|					" + ?(NOT ValueIsFilled(Department), "", "AND StructuralUnit = &Department") + ") AS DebtAtEnd 
	|		ON EarningsAndDeductions.Employee = DebtAtEnd.Employee
	|		LEFT JOIN InformationRegister.Employees.SliceLast(
	|				&RegistrationEndOfPeriod, 
	|				Company = &Company
	|					AND StructuralUnit <> VALUE(Catalog.BusinessUnits.EmptyRef) 
	|					) AS EmployeesSliceLast 
	|			LEFT JOIN (SELECT 
	|				TimesheetTurnovers.DaysTurnover AS DaysTurnover, 
	|				TimesheetTurnovers.HoursTurnover AS HoursTurnover, 
	|				TimesheetTurnovers.Employee AS Employee, 
	|				TimesheetTurnovers.Position AS Position
	|			FROM
	|				AccumulationRegister.Timesheet.Turnovers(
	|					&RegistrationPeriod,
	|					&RegistrationEndOfPeriod, 
	|					Month, 
	|					Company = &Company
	|							" + ?(NOT ValueIsFilled(Department), "", "AND StructuralUnit = &Department") + "
	|							AND TimeKind = VALUE(Catalog.PayCodes.Work)) AS TimesheetTurnovers) AS Timesheet 
	|			ON EmployeesSliceLast.Employee = Timesheet.Employee 
	|				AND EmployeesSliceLast.Position = Timesheet.Position 
	|		ON EarningsAndDeductions.Employee = EmployeesSliceLast.Employee 
	|		LEFT JOIN InformationRegister.ChangeHistoryOfIndividualNames.SliceLast(&RegistrationEndOfPeriod, ) AS ChangeHistoryOfIndividualNamesSliceLast
	|		ON EarningsAndDeductions.Employee.Ind = ChangeHistoryOfIndividualNamesSliceLast.Ind 
	|		LEFT JOIN AccumulationRegister.Payroll.Balance( 
	|			&RegistrationEndOfPeriod, 
	|			Company = &Company 
	|				AND Currency = &Currency 
	|				AND RegistrationPeriod = &RegistrationPeriod
	|					" + ?(NOT ValueIsFilled(Department), "", "AND StructuralUnit = &Department") + ") AS DebtPayable 
	|		ON EarningsAndDeductions.Employee = DebtPayable.Employee
	|WHERE 
	|	EarningsAndDeductions.Company = &Company 
	|	AND EarningsAndDeductions.RegistrationPeriod = &RegistrationPeriod 
	|	AND EarningsAndDeductions.Currency = &Currency" + ?(NOT ValueIsFilled(Department), "", "
	|	And EarningsAndDeductions.StructuralUnit = &Department") + "
	|
	|ORDER BY
	|	EmployeePresentation, EarningsAndDeductions.StartDate
	|TOTALS
	|	MAX(Department),
	|	MAX(EmployeeCode),
	|	MAX(Position),
	|	SUM(AmountWithheld),
	|	SUM(AmountAccrued),
	|	MAX(DaysWorked),
	|	MAX(HoursWorked),
	|	MAX(ClosingBalance),
	|	MAX(DebtPayable),
	|	MAX(Surname),
	|	MAX(Name),
	|	MAX(Patronymic)
	|BY
	|	Ind";
                      
	Query.SetParameter("Currency", Currency);
	Query.SetParameter("Company", Company); 
	Query.SetParameter("Department", Department);
	Query.SetParameter("RegistrationPeriod", RegistrationPeriod);
	Query.SetParameter("RegistrationEndOfPeriod", EndOfMonth(RegistrationPeriod));
    
	Return Query.Execute();	

EndFunction

&AtServer
// Procedure forms the report.
//
Procedure MakeExecute()

	If Constants.UseSeveralCompanies.Get() AND Not ValueIsFilled(Company) Then
		MessageText = NStr("en = 'Company is not selected.'");
		MessageField = "Company";
		DriveServer.ShowMessageAboutError(Report, MessageText,,,MessageField);
		Return;
	EndIf;

	If Not ValueIsFilled(RegistrationPeriod) Then
		MessageText = NStr("en = 'The registration period is required.'");
		MessageField = "RegistrationPeriod";
		DriveServer.ShowMessageAboutError(Report, MessageText,,,MessageField);
		Return;
	EndIf;

	If Not Constants.ForeignExchangeAccounting.Get() AND Not ValueIsFilled(Currency) Then
		MessageText = NStr("en = 'Currency is not selected.'");
		MessageField = "Currency";
		DriveServer.ShowMessageAboutError(Report, MessageText,,,MessageField);
		Return;
	EndIf;

	QueryResult = ExecuteQuery();

	If QueryResult.IsEmpty() Then
		Message = New UserMessage();
		Message.Text = NStr("en = 'No data to generate the report.'");
		Message.Message();
		Return;
	EndIf; 

	Template = Reports.PayStatementFixedTemplate.GetTemplate("Template");

	AreaDocumentHeader 		= Template.GetArea("DocumentHeader");
	AreaHeader 				= Template.GetArea("Header");
	AreaDetails 				= Template.GetArea("Details");
	AreaTotalByPage 		= Template.GetArea("TotalByPage");
	FooterArea 				= Template.GetArea("Footer");

	SpreadsheetDocument.Clear();
	
    SpreadsheetDocument.PageOrientation = PageOrientation.Landscape;
	
    AreaDocumentHeader.Parameters.Company = Company.DescriptionFull;
	AreaDocumentHeader.Parameters.Department = Department;
	AreaDocumentHeader.Parameters.DateD = CurrentDate();
	AreaDocumentHeader.Parameters.FinancialPeriodFrom = RegistrationPeriod;
	AreaDocumentHeader.Parameters.FinancialPeriodTo = EndOfMonth(RegistrationPeriod);
	SpreadsheetDocument.Put(AreaDocumentHeader);

    AreaHeader.Parameters.Currency = Currency;
	SpreadsheetDocument.Put(AreaHeader);
	
	// Initialization of totals for the page
	TotalOnPageDebtForOrganization = 0;
	TotalDebtForEmployeePage	 = 0;
	TotalByPageClosingBalance      = 0;

	// Initialization of totals for the document
	TotalDebtForOrganization			 = 0;
	TotalDebtForEmployee			 = 0;
	TotalBalanceAtEnd				 = 0;
	
	NPP = 0;
	FirstPage = True;

	IndividualSelection = QueryResult.Select(QueryResultIteration.ByGroups, "Ind");
	While IndividualSelection.Next() Do

		RateList = "";

		SelectionDetails = IndividualSelection.Select();
		While SelectionDetails.Next() Do
			If ValueIsFilled(SelectionDetails.Size) Then
				RateList = RateList + ?(ValueIsFilled(RateList), ", ", "") + Format(SelectionDetails.Size, "NFD=2");
			EndIf; 	
		EndDo; 

		NPP = NPP + 1;
		AreaDetails.Parameters.SerialNumber = NPP;
		AreaDetails.Parameters.Fill(IndividualSelection);
		AreaDetails.Parameters.TariffRate = RateList;
		PresentationIndividual = DriveServer.GetSurnameNamePatronymic(IndividualSelection.Surname, IndividualSelection.Name, IndividualSelection.Patronymic, True);
		AreaDetails.Parameters.Ind = ?(ValueIsFilled(PresentationIndividual), PresentationIndividual, IndividualSelection.Ind);
		AreaDetails.Parameters.EmployeeCode = TrimAll(IndividualSelection.EmployeeCode);
			
		If IndividualSelection.ClosingBalance < 0 Then
			AreaDetails.Parameters.DebtForOrganization = 0;
			AreaDetails.Parameters.DebtForEmployee = -1 * IndividualSelection.ClosingBalance;
		Else
			AreaDetails.Parameters.DebtForOrganization = IndividualSelection.ClosingBalance;
			AreaDetails.Parameters.DebtForEmployee = 0;
		EndIf;
		
		// Check output
		RowWithFooter = New Array;
		If FirstPage Then
			RowWithFooter.Add(AreaHeader); // if the first row then title should be placed
			FirstPage = False;
		EndIf;                                                   
		RowWithFooter.Add(AreaDetails);
		RowWithFooter.Add(AreaTotalByPage);

		If Not FirstPage AND Not SpreadsheetDocument.CheckPut(RowWithFooter) Then
			
			// Displaying results for the page
			AreaTotalByPage.Parameters.TotalOnPageDebtForOrganization	 = TotalOnPageDebtForOrganization;
			AreaTotalByPage.Parameters.TotalDebtForEmployeePage		 = TotalDebtForEmployeePage;
			AreaTotalByPage.Parameters.TotalByPageClosingBalance		 = TotalByPageClosingBalance;
			SpreadsheetDocument.Put(AreaTotalByPage);
			
			SpreadsheetDocument.PutHorizontalPageBreak();
			
			// Clear results for the page
			TotalOnPageDebtForOrganization	 = 0;
			TotalDebtForEmployeePage		 = 0;
			TotalByPageClosingBalance			 = 0;
			
			// Display table header
			SpreadsheetDocument.Put(AreaHeader);
			
		EndIf;
			
		SpreadsheetDocument.Put(AreaDetails);
		
        // Increase totals
		If IndividualSelection.ClosingBalance < 0 Then
			
			TotalDebtForEmployeePage		 = TotalDebtForEmployeePage - IndividualSelection.ClosingBalance;
			TotalByPageClosingBalance			 = TotalByPageClosingBalance      + IndividualSelection.DebtPayable;

			TotalDebtForEmployee				 = TotalDebtForEmployee + IndividualSelection.ClosingBalance;
			TotalBalanceAtEnd     				 = TotalBalanceAtEnd      + IndividualSelection.DebtPayable;
			
		Else
			
			TotalOnPageDebtForOrganization	 = TotalOnPageDebtForOrganization       + IndividualSelection.ClosingBalance;
			TotalByPageClosingBalance			 = TotalByPageClosingBalance      + IndividualSelection.DebtPayable;

			TotalDebtForOrganization      		 = TotalDebtForOrganization       + IndividualSelection.ClosingBalance;
			TotalBalanceAtEnd     				 = TotalBalanceAtEnd      + IndividualSelection.DebtPayable;
			
		EndIf;
		
	EndDo;
	
	// Displaying results for the page
	AreaTotalByPage.Parameters.TotalOnPageDebtForOrganization	 = TotalOnPageDebtForOrganization;
	AreaTotalByPage.Parameters.TotalDebtForEmployeePage		 = TotalDebtForEmployeePage;
	AreaTotalByPage.Parameters.TotalByPageClosingBalance		 = TotalByPageClosingBalance;
	SpreadsheetDocument.Put(AreaTotalByPage);

	FooterArea.Parameters.TotalDebtForOrganization	 = TotalDebtForOrganization;
	FooterArea.Parameters.TotalDebtForEmployee		 = TotalDebtForEmployee;
	FooterArea.Parameters.TotalBalanceAtEnd		 = TotalBalanceAtEnd;
	SpreadsheetDocument.Put(FooterArea);

EndProcedure
 
#EndRegion

#Region ProcedureFormEventHandlers

&AtClient
// Procedure - command handler Generate.
//
Procedure Generate(Command)
	
	MakeExecute();
	
EndProcedure

&AtServer
// Procedure - OnCreateAtServer form event handler.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	RegistrationPeriod 	= BegOfMonth(CurrentDate());
	Company 		= DriveServer.GetCompany(Catalogs.Companies.MainCompany);
	Currency 				= Constants.PresentationCurrency.Get();

	If Not Constants.UseSeveralDepartments.Get() Then
		
		Department = Catalogs.BusinessUnits.MainDepartment;
		
	EndIf;	
	
EndProcedure

&AtClient
// Procedure - event handler OnChange attribute RegistrationPeriod.
//
Procedure RegistrationPeriodOnChange(Item)

	RegistrationPeriod = BegOfMonth(RegistrationPeriod);

EndProcedure

&AtServer
Procedure OnSaveUserSettingsAtServer(Settings)
	
	ReportsVariants.OnSaveUserSettingsAtServer(ThisObject, Settings);
	
EndProcedure

#EndRegion
