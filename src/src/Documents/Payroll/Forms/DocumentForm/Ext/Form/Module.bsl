
#Region ServiceProceduresAndFunctions

&AtServer
// Procedure fills the data structure for the GL account selection.
//
Procedure ReceiveDataForSelectAccountsSettlements(DataStructure)
	
	GLAccountsAvailableTypes = New Array;
	EarningAndDeductionType = DataStructure.EarningAndDeductionType;
	If Not ValueIsFilled(EarningAndDeductionType) Then
		
		GLAccountsAvailableTypes.Add(Enums.GLAccountsTypes.WorkInProcess);
		GLAccountsAvailableTypes.Add(Enums.GLAccountsTypes.IndirectExpenses);
		GLAccountsAvailableTypes.Add(Enums.GLAccountsTypes.Expenses);
		GLAccountsAvailableTypes.Add(Enums.GLAccountsTypes.OtherExpenses);
		GLAccountsAvailableTypes.Add(Enums.GLAccountsTypes.OtherFixedAssets);
		GLAccountsAvailableTypes.Add(Enums.GLAccountsTypes.OtherIncome);
		
	ElsIf EarningAndDeductionType.Type = Enums.EarningAndDeductionTypes.Earning Then
		
		GLAccountsAvailableTypes.Add(Enums.GLAccountsTypes.WorkInProcess);
		GLAccountsAvailableTypes.Add(Enums.GLAccountsTypes.IndirectExpenses);
		GLAccountsAvailableTypes.Add(Enums.GLAccountsTypes.Expenses);
		GLAccountsAvailableTypes.Add(Enums.GLAccountsTypes.OtherExpenses);
		GLAccountsAvailableTypes.Add(Enums.GLAccountsTypes.OtherFixedAssets);
		
	ElsIf EarningAndDeductionType.Type = Enums.EarningAndDeductionTypes.Deduction Then
		
		GLAccountsAvailableTypes.Add(Enums.GLAccountsTypes.OtherIncome);
		
	EndIf;
	
	DataStructure.Insert("GLAccountsAvailableTypes", GLAccountsAvailableTypes);
	
EndProcedure

// The procedure fills in the indicator table by parameters.
//
&AtServer
Procedure FillIndicators(ReturnStructure)

	EarningAndDeductionType = ReturnStructure.EarningAndDeductionType;	
	ReturnStructure.Insert("Indicator1", "");
	ReturnStructure.Insert("Presentation1", Catalogs.EarningsCalculationParameters.EmptyRef());
	ReturnStructure.Insert("Value1", 0);
	ReturnStructure.Insert("Indicator2", "");
	ReturnStructure.Insert("Presentation2", Catalogs.EarningsCalculationParameters.EmptyRef());
	ReturnStructure.Insert("Value2", 0);
	ReturnStructure.Insert("Indicator3", "");
	ReturnStructure.Insert("Presentation3", Catalogs.EarningsCalculationParameters.EmptyRef());
	ReturnStructure.Insert("Value3", 0);
	
	// 1. Checking
	If Not ValueIsFilled(EarningAndDeductionType) Then
		Return;
	EndIf; 
	
	// 2. Search of all parameters-identifiers for the formula
	ParametersStructure = New Structure;
	DriveServer.AddParametersToStructure(EarningAndDeductionType.Formula, ParametersStructure);
		
	// 3. Adding the indicator
	Counter = 0;
	For Each ParameterStructures In ParametersStructure Do
		
		If ParameterStructures.Key = "DaysWorked" 
			OR ParameterStructures.Key = "HoursWorked"
			OR ParameterStructures.Key = "TariffRate" Then
			
			Continue;
			
		EndIf; 
		
		CalculationParameter = Catalogs.EarningsCalculationParameters.FindByAttribute("ID", ParameterStructures.Key);
		If Not ValueIsFilled(CalculationParameter) Then
			
			CommonUseClientServer.MessageToUser(StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Parameter %1 is not found for formula %2'"),
				CalculationParameter,
				EarningAndDeductionType));
				
			Continue;
			
		EndIf; 
		
		Counter = Counter + 1;
		
		If Counter > 3 Then
			
			Break;
			
		EndIf; 
		
		ReturnStructure["Indicator" + Counter] = ParameterStructures.Key;
		ReturnStructure["Presentation" + Counter] = CalculationParameter;
		
	EndDo;
	
EndProcedure

&AtServer
Procedure GetGLAccountByDefault(DataStructure)
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	CompensationPlanSliceLast.GLExpenseAccount AS GLExpenseAccount,
		|	CompensationPlanSliceLast.GLExpenseAccount.TypeOfAccount AS TypeOfAccount
		|FROM
		|	InformationRegister.CompensationPlan.SliceLast(
		|			&Period,
		|			Company = &Company
		|				AND Employee = &Employee
		|				AND EarningAndDeductionType = &EarningAndDeductionType
		|				AND Currency = &Currency) AS CompensationPlanSliceLast";
	
	Query.SetParameter("EarningAndDeductionType",	DataStructure.EarningAndDeductionType);
	Query.SetParameter("Company",				Object.Company);
	Query.SetParameter("Currency",				Object.DocumentCurrency);
	Query.SetParameter("Employee",				DataStructure.Employee);
	Query.SetParameter("Period",				DataStructure.StartDate);
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	
	If Selection.Next() Then 
		FillPropertyValues(DataStructure, Selection, "GLExpenseAccount, TypeOfAccount"); 
	Else
		If ValueIsFilled(DataStructure.EarningAndDeductionType) Then
			DataStructure.Insert("StructuralUnit",	Object.StructuralUnit);
			DriveServer.GetEarningKindGLExpenseAccount(DataStructure);
		EndIf;
	EndIf;
	
EndProcedure

&AtServer
// The function creates the table of Earnings.
//
Function GenerateEarningsTable()

	TableEarnings = New ValueTable;

    Array = New Array;
	
	Array.Add(Type("CatalogRef.Employees"));
	TypeDescription = New TypeDescription(Array, ,);
	Array.Clear();

	TableEarnings.Columns.Add("Employee", TypeDescription);

	Array.Add(Type("CatalogRef.Positions"));
	TypeDescription = New TypeDescription(Array, ,);
	Array.Clear();

	TableEarnings.Columns.Add("Position", TypeDescription);
	
	Array.Add(Type("CatalogRef.EarningAndDeductionTypes"));
	TypeDescription = New TypeDescription(Array, ,);
	Array.Clear();

	TableEarnings.Columns.Add("EarningAndDeductionType", TypeDescription);

	Array.Add(Type("Date"));
	TypeDescription = New TypeDescription(Array, ,);
	Array.Clear();
	
	TableEarnings.Columns.Add("StartDate", TypeDescription);
	  
	Array.Add(Type("Date"));
	TypeDescription = New TypeDescription(Array, ,);
	Array.Clear();
	
	TableEarnings.Columns.Add("EndDate", TypeDescription);
		        
	Array.Add(Type("ChartOfAccountsRef.PrimaryChartOfAccounts"));
	TypeDescription = New TypeDescription(Array, ,);
	Array.Clear();

	TableEarnings.Columns.Add("GLExpenseAccount", TypeDescription);

	Array.Add(Type("Number"));
	TypeDescription = New TypeDescription(Array, ,);
	Array.Clear();

	TableEarnings.Columns.Add("Size", TypeDescription);

	For Each TSRow In Object.EarningsDeductions Do

		NewRow = TableEarnings.Add();
        NewRow.Employee = TSRow.Employee;
        NewRow.Position = TSRow.Position;
		NewRow.EarningAndDeductionType = TSRow.EarningAndDeductionType;
        NewRow.StartDate = TSRow.StartDate;
        NewRow.EndDate = TSRow.EndDate;
        NewRow.GLExpenseAccount = TSRow.GLExpenseAccount;
        NewRow.Size = TSRow.Size;

	EndDo;
    	    
	Return TableEarnings;

EndFunction

&AtServer
// The procedure fills in the Employees tabular section with filter by department.
//
Procedure FillByDepartment()

	Object.EarningsDeductions.Clear();
	Object.IncomeTaxes.Clear();
	
	Query = New Query;
	
	Query.Parameters.Insert("BegOfMonth", 		Object.RegistrationPeriod);
	Query.Parameters.Insert("EndOfMonth",	EndOfMonth(Object.RegistrationPeriod));
	Query.Parameters.Insert("Company", 		DriveServer.GetCompany(Object.Company));
	Query.Parameters.Insert("StructuralUnit", Object.StructuralUnit);
	Query.Parameters.Insert("Currency", 			Object.DocumentCurrency);
		
	// 1. Define the	employees we need
	// 2. Define all records of the employees we need, and Earnings in the corresponding department.
	Query.Text = 
	"SELECT DISTINCT
	|	NestedSelect.Employee AS Employee
	|INTO EmployeesDeparnments
	|FROM
	|	(SELECT
	|		EmployeesSliceLast.Employee AS Employee
	|	FROM
	|		InformationRegister.Employees.SliceLast(&BegOfMonth, Company = &Company) AS EmployeesSliceLast
	|	WHERE
	|		EmployeesSliceLast.StructuralUnit = &StructuralUnit
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		Employees.Employee
	|	FROM
	|		InformationRegister.Employees AS Employees
	|	WHERE
	|		Employees.StructuralUnit = &StructuralUnit
	|		AND Employees.Period between &BegOfMonth AND &EndOfMonth
	|		AND Employees.Company = &Company) AS NestedSelect
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	NestedSelect.Employee AS Employee,
	|	NestedSelect.StructuralUnit AS StructuralUnit,
	|	NestedSelect.Position AS Position,
	|	CompensationPlan.EarningAndDeductionType AS EarningAndDeductionType,
	|	CompensationPlan.Amount AS Amount,
	|	CompensationPlan.GLExpenseAccount AS GLExpenseAccount,
	|	CompensationPlan.Actuality AS Actuality,
	|	NestedSelect.Period AS Period,
	|	NestedSelect.OthersUnitTerminationOfEmployment AS OthersUnitTerminationOfEmployment
	|INTO EmployeeRecords
	|FROM
	|	(SELECT
	|		EmployeesDeparnments.Employee AS Employee,
	|		Employees.StructuralUnit AS StructuralUnit,
	|		Employees.Position AS Position,
	|		MAX(CompensationPlan.Period) AS EarningPeriod,
	|		Employees.Period AS Period,
	|		CASE
	|			WHEN Employees.StructuralUnit = &StructuralUnit
	|				THEN FALSE
	|			ELSE TRUE
	|		END AS OthersUnitTerminationOfEmployment,
	|		CompensationPlan.EarningAndDeductionType AS EarningAndDeductionType,
	|		CompensationPlan.Currency AS Currency
	|	FROM
	|		EmployeesDeparnments AS EmployeesDeparnments
	|			INNER JOIN InformationRegister.Employees AS Employees
	|				LEFT JOIN InformationRegister.CompensationPlan AS CompensationPlan
	|				ON Employees.Company = CompensationPlan.Company
	|					AND Employees.Employee = CompensationPlan.Employee
	|					AND Employees.Period >= CompensationPlan.Period
	|					AND (Employees.StructuralUnit = &StructuralUnit)
	|					AND (CompensationPlan.Currency = &Currency)
	|					AND (CompensationPlan.EarningAndDeductionType <> VALUE(Catalog.EarningAndDeductionTypes.PieceRatePay))
	|					AND (CompensationPlan.EarningAndDeductionType <> VALUE(Catalog.EarningAndDeductionTypes.PieceRatePayPercent))
	|					AND (CompensationPlan.EarningAndDeductionType <> VALUE(Catalog.EarningAndDeductionTypes.PieceRatePayFixedAmount))
	|			ON EmployeesDeparnments.Employee = Employees.Employee
	|	WHERE
	|		Employees.Company = &Company
	|		AND Employees.Period between DATEADD(&BegOfMonth, Day, 1) AND &EndOfMonth
	|	
	|	GROUP BY
	|		Employees.StructuralUnit,
	|		EmployeesDeparnments.Employee,
	|		Employees.Position,
	|		Employees.Period,
	|		CompensationPlan.EarningAndDeductionType,
	|		CompensationPlan.Currency,
	|		CASE
	|			WHEN Employees.StructuralUnit = &StructuralUnit
	|				THEN FALSE
	|			ELSE TRUE
	|		END) AS NestedSelect
	|		LEFT JOIN InformationRegister.CompensationPlan AS CompensationPlan
	|		ON NestedSelect.Employee = CompensationPlan.Employee
	|			AND (CompensationPlan.Currency = &Currency)
	|			AND (CompensationPlan.Company = &Company)
	|			AND NestedSelect.EarningPeriod = CompensationPlan.Period
	|			AND NestedSelect.EarningAndDeductionType = CompensationPlan.EarningAndDeductionType
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	NestedSelect.Employee,
	|	NestedSelect.Period,
	|	NestedSelect.EarningAndDeductionType,
	|	NestedSelect.Amount,
	|	NestedSelect.GLExpenseAccount,
	|	NestedSelect.Actuality,
	|	Employees.StructuralUnit,
	|	Employees.Position
	|INTO RegisterRecordsPlannedEarning
	|FROM
	|	(SELECT
	|		CompensationPlan.Employee AS Employee,
	|		CompensationPlan.Period AS Period,
	|		CompensationPlan.EarningAndDeductionType AS EarningAndDeductionType,
	|		CompensationPlan.Amount AS Amount,
	|		CASE
	|			WHEN CompensationPlan.GLExpenseAccount = VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|				THEN CompensationPlan.EarningAndDeductionType.GLExpenseAccount
	|			ELSE CompensationPlan.GLExpenseAccount
	|		END AS GLExpenseAccount,
	|		CompensationPlan.Actuality AS Actuality,
	|		MAX(Employees.Period) AS PeriodStaff
	|	FROM
	|		EmployeesDeparnments AS EmployeesDeparnments
	|			INNER JOIN InformationRegister.CompensationPlan AS CompensationPlan
	|				LEFT JOIN InformationRegister.Employees AS Employees
	|				ON CompensationPlan.Employee = Employees.Employee
	|					AND CompensationPlan.Period >= Employees.Period
	|					AND (Employees.Company = &Company)
	|			ON EmployeesDeparnments.Employee = CompensationPlan.Employee
	|				AND (CompensationPlan.Currency = &Currency)
	|				AND (CompensationPlan.Period between DATEADD(&BegOfMonth, Day, 1) AND &EndOfMonth)
	|				AND (CompensationPlan.EarningAndDeductionType <> VALUE(Catalog.EarningAndDeductionTypes.PieceRatePay))
	|				AND (CompensationPlan.EarningAndDeductionType <> VALUE(Catalog.EarningAndDeductionTypes.PieceRatePayPercent))
	|				AND (CompensationPlan.EarningAndDeductionType <> VALUE(Catalog.EarningAndDeductionTypes.PieceRatePayFixedAmount))
	|				AND (CompensationPlan.Company = &Company)
	|	
	|	GROUP BY
	|		CompensationPlan.Actuality,
	|		CASE
	|			WHEN CompensationPlan.GLExpenseAccount = VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|				THEN CompensationPlan.EarningAndDeductionType.GLExpenseAccount
	|			ELSE CompensationPlan.GLExpenseAccount
	|		END,
	|		CompensationPlan.Period,
	|		CompensationPlan.EarningAndDeductionType,
	|		CompensationPlan.Employee,
	|		CompensationPlan.Amount) AS NestedSelect
	|		LEFT JOIN InformationRegister.Employees AS Employees
	|		ON NestedSelect.PeriodStaff = Employees.Period
	|			AND (Employees.Company = &Company)
	|			AND NestedSelect.Employee = Employees.Employee
	|WHERE
	|	Employees.StructuralUnit = &StructuralUnit
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	NestedSelect.Employee AS Employee,
	|	NestedSelect.StructuralUnit AS StructuralUnit,
	|	NestedSelect.Position AS Position,
	|	NestedSelect.DateActionsBegin AS DateActionsBegin,
	|	NestedSelect.EarningAndDeductionType AS EarningAndDeductionType,
	|	NestedSelect.Size AS Size,
	|	NestedSelect.GLExpenseAccount AS GLExpenseAccount,
	|	NestedSelect.Actuality,
	|	CASE
	|		WHEN NestedSelect.StructuralUnit = &StructuralUnit
	|			THEN FALSE
	|		ELSE TRUE
	|	END AS OtherUnitTerminationOfEmployment,
	|	CASE
	|		WHEN NestedSelect.EarningAndDeductionType.Type = VALUE(Enum.EarningAndDeductionTypes.Tax)
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS IsTax
	|FROM
	|	(SELECT
	|		EmployeesDeparnments.Employee AS Employee,
	|		EmployeesSliceLast.StructuralUnit AS StructuralUnit,
	|		EmployeesSliceLast.Position AS Position,
	|		&BegOfMonth AS DateActionsBegin,
	|		CompensationPlanSliceLast.EarningAndDeductionType AS EarningAndDeductionType,
	|		CompensationPlanSliceLast.Amount AS Size,
	|		CASE
	|			WHEN CompensationPlanSliceLast.GLExpenseAccount = VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|				THEN CompensationPlanSliceLast.EarningAndDeductionType.GLExpenseAccount
	|			ELSE CompensationPlanSliceLast.GLExpenseAccount
	|		END AS GLExpenseAccount,
	|		TRUE AS Actuality
	|	FROM
	|		EmployeesDeparnments AS EmployeesDeparnments
	|			INNER JOIN InformationRegister.Employees.SliceLast(&BegOfMonth, Company = &Company) AS EmployeesSliceLast
	|			ON EmployeesDeparnments.Employee = EmployeesSliceLast.Employee
	|			INNER JOIN InformationRegister.CompensationPlan.SliceLast(
	|					&BegOfMonth,
	|					Company = &Company
	|						AND Currency = &Currency) AS CompensationPlanSliceLast
	|			ON EmployeesDeparnments.Employee = CompensationPlanSliceLast.Employee
	|	WHERE
	|		CompensationPlanSliceLast.Actuality
	|		AND CompensationPlanSliceLast.EarningAndDeductionType <> VALUE(Catalog.EarningAndDeductionTypes.PieceRatePay)
	|		AND CompensationPlanSliceLast.EarningAndDeductionType <> VALUE(Catalog.EarningAndDeductionTypes.PieceRatePayPercent)
	|		AND CompensationPlanSliceLast.EarningAndDeductionType <> VALUE(Catalog.EarningAndDeductionTypes.PieceRatePayFixedAmount)
	|		AND EmployeesSliceLast.StructuralUnit = &StructuralUnit
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		CASE
	|			WHEN Employees.Employee IS NULL 
	|				THEN CompensationPlan.Employee
	|			ELSE Employees.Employee
	|		END,
	|		CASE
	|			WHEN Employees.Employee IS NULL 
	|				THEN CompensationPlan.StructuralUnit
	|			ELSE Employees.StructuralUnit
	|		END,
	|		CASE
	|			WHEN Employees.Employee IS NULL 
	|				THEN CompensationPlan.Position
	|			ELSE Employees.Position
	|		END,
	|		CASE
	|			WHEN Employees.Employee IS NULL 
	|				THEN CompensationPlan.Period
	|			ELSE Employees.Period
	|		END,
	|		CASE
	|			WHEN Employees.Employee IS NULL 
	|				THEN CompensationPlan.EarningAndDeductionType
	|			ELSE Employees.EarningAndDeductionType
	|		END,
	|		CASE
	|			WHEN Employees.Employee IS NULL 
	|				THEN CompensationPlan.Amount
	|			ELSE Employees.Amount
	|		END,
	|		CASE
	|			WHEN Employees.Employee IS NULL 
	|				THEN CASE
	|						WHEN CompensationPlan.GLExpenseAccount = VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|							THEN CompensationPlan.EarningAndDeductionType.GLExpenseAccount
	|						ELSE CompensationPlan.GLExpenseAccount
	|					END
	|			ELSE CASE
	|					WHEN Employees.GLExpenseAccount = VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|						THEN Employees.EarningAndDeductionType.GLExpenseAccount
	|					ELSE Employees.GLExpenseAccount
	|				END
	|		END,
	|		CASE
	|			WHEN Employees.Employee IS NULL 
	|				THEN CompensationPlan.Actuality
	|			ELSE Employees.Actuality
	|		END
	|	FROM
	|		EmployeeRecords AS Employees
	|			Full JOIN RegisterRecordsPlannedEarning AS CompensationPlan
	|			ON Employees.Employee = CompensationPlan.Employee
	|				AND Employees.Period = CompensationPlan.Period
	|				AND Employees.EarningAndDeductionType = CompensationPlan.EarningAndDeductionType) AS NestedSelect
	|
	|ORDER BY
	|	Employee,
	|	DateActionsBegin
	|TOTALS BY
	|	Employee";
	
	ResultsArray = Query.ExecuteBatch();
	
	// 3. We define the period end dates and fill in the value table.
	
	EndOfMonth = BegOfDay(EndOfMonth(Object.RegistrationPeriod));
	SelectionEmployee = ResultsArray[3].Select(QueryResultIteration.ByGroups, "Employee");
	While SelectionEmployee.Next() Do
		
		Selection = SelectionEmployee.Select();
		
		While Selection.Next() Do
			
			If Selection.OtherUnitTerminationOfEmployment Then
				ReplaceDateArray = Object.EarningsDeductions.FindRows(New Structure("EndDate, Employee", EndOfMonth, Selection.Employee));
				For Each ArrayElement In ReplaceDateArray Do
					ArrayElement.EndDate = Selection.DateActionsBegin - 60*60*24;
				EndDo;
				Continue;
			EndIf; 
			
			ReplaceDateArray = Object.EarningsDeductions.FindRows(New Structure("EndDate, Employee, EarningAndDeductionType", EndOfMonth, Selection.Employee, Selection.EarningAndDeductionType));
			For Each ArrayElement In ReplaceDateArray Do
				ArrayElement.EndDate = Selection.DateActionsBegin - 60*60*24;
			EndDo;
			
			If ValueIsFilled(Selection.EarningAndDeductionType) AND Selection.Actuality Then
			
				If Selection.IsTax Then				
										
					NewRow							= Object.IncomeTaxes.Add();
					NewRow.Employee 				= Selection.Employee;
					NewRow.EarningAndDeductionType 	= Selection.EarningAndDeductionType;				
				
				Else
				
					NewRow							= Object.EarningsDeductions.Add();
					NewRow.Employee 				= Selection.Employee;
					NewRow.Position 				= Selection.Position;				 
											
					NewRow.EarningAndDeductionType 	= Selection.EarningAndDeductionType;
					NewRow.StartDate 				= Selection.DateActionsBegin;
					NewRow.EndDate 			= EndOfMonth;
					NewRow.Size 					= Selection.Size;
					
					TypeOfAccount = Selection.GLExpenseAccount.TypeOfAccount;
					If Object.StructuralUnit.StructuralUnitType = Enums.BusinessUnitsTypes.Department
						AND  Not (TypeOfAccount = Enums.GLAccountsTypes.IndirectExpenses
						OR TypeOfAccount = Enums.GLAccountsTypes.Expenses
						OR TypeOfAccount = Enums.GLAccountsTypes.OtherCurrentAssets
						OR TypeOfAccount = Enums.GLAccountsTypes.IndirectExpenses
						OR TypeOfAccount = Enums.GLAccountsTypes.WorkInProcess
						OR TypeOfAccount = Enums.GLAccountsTypes.OtherCurrentAssets
						OR TypeOfAccount = Enums.GLAccountsTypes.AccountsPayable) Then
					
						NewRow.GLExpenseAccount = ChartsOfAccounts.PrimaryChartOfAccounts.EmptyRef();					
					Else
						NewRow.GLExpenseAccount = Selection.GLExpenseAccount;				
					EndIf;
					
				EndIf;	
				
			EndIf; 
					
		EndDo;
		
	EndDo;
	
	// 4. Fill in working hours
		
	Query.Parameters.Insert("TableEarningsDeductions", GenerateEarningsTable());
	
	Query.Text =
	"SELECT
	|	TableEarningsDeductions.Employee,
	|	TableEarningsDeductions.Position,
	|	TableEarningsDeductions.EarningAndDeductionType,
	|	TableEarningsDeductions.StartDate,
	|	TableEarningsDeductions.EndDate,
	|	TableEarningsDeductions.Size,
	|	TableEarningsDeductions.GLExpenseAccount
	|INTO TableEarningsDeductions
	|FROM
	|	&TableEarningsDeductions AS TableEarningsDeductions
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DocumentAssessment.Employee AS Employee,
	|	DocumentAssessment.Position AS Position,
	|	DocumentAssessment.EarningAndDeductionType AS EarningAndDeductionType,
	|	DocumentAssessment.StartDate AS StartDate,
	|	DocumentAssessment.EndDate AS EndDate,
	|	DocumentAssessment.Size AS Size,
	|	DocumentAssessment.GLExpenseAccount AS GLExpenseAccount,
	|	ScheduleData.DaysWorked AS DaysWorked,
	|	ScheduleData.HoursWorked,
	|	ScheduleData.TotalForPeriod
	|FROM
	|	TableEarningsDeductions AS DocumentAssessment
	|		LEFT JOIN (SELECT
	|			DocumentAssessment.Employee AS Employee,
	|			SUM(Timesheet.Days) AS DaysWorked,
	|			SUM(Timesheet.Hours) AS HoursWorked,
	|			DocumentAssessment.StartDate AS StartDate,
	|			DocumentAssessment.EndDate AS EndDate,
	|			MAX(Timesheet.TotalForPeriod) AS TotalForPeriod
	|		FROM
	|			(SELECT DISTINCT
	|				DocumentAssessment.Employee AS Employee,
	|				DocumentAssessment.StartDate AS StartDate,
	|				DocumentAssessment.EndDate AS EndDate
	|			FROM
	|				TableEarningsDeductions AS DocumentAssessment) AS DocumentAssessment
	|				LEFT JOIN AccumulationRegister.Timesheet AS Timesheet
	|				ON DocumentAssessment.Employee = Timesheet.Employee
	|					AND (Timesheet.TimeKind = VALUE(Catalog.PayCodes.Work))
	|					AND (Timesheet.Company = &Company)
	|					AND (Timesheet.StructuralUnit = &StructuralUnit)
	|					AND ((NOT Timesheet.TotalForPeriod)
	|							AND DocumentAssessment.StartDate <= Timesheet.Period
	|							AND DocumentAssessment.EndDate >= Timesheet.Period
	|						OR Timesheet.TotalForPeriod
	|							AND Timesheet.Period = BEGINOFPERIOD(DocumentAssessment.StartDate, MONTH))
	|		
	|		GROUP BY
	|			DocumentAssessment.Employee,
	|			DocumentAssessment.StartDate,
	|			DocumentAssessment.EndDate) AS ScheduleData
	|		ON DocumentAssessment.Employee = ScheduleData.Employee
	|			AND DocumentAssessment.StartDate = ScheduleData.StartDate
	|			AND DocumentAssessment.EndDate = ScheduleData.EndDate";
	
	QueryResult = Query.ExecuteBatch()[1].Unload();
	Object.EarningsDeductions.Load(QueryResult); 
		
	Object.EarningsDeductions.Sort("Employee Asc, StartDate Asc, EarningAndDeductionType Asc");
	
	For Each TabularSectionRow In Object.EarningsDeductions Do
		
		// 1. Checking
		If Not ValueIsFilled(TabularSectionRow.EarningAndDeductionType) Then
			Continue;
		EndIf; 
		RepetitionsArray = QueryResult.FindRows(New Structure("Employee, EarningAndDeductionType", TabularSectionRow.Employee, TabularSectionRow.EarningAndDeductionType));
		If RepetitionsArray.Count() > 1 AND RepetitionsArray[0].TotalForPeriod Then
			
			TabularSectionRow.DaysWorked = 0;
			TabularSectionRow.HoursWorked = 0;
			
			MessageText = NStr("en = '%Employee%, %EarningKind%: Working hours data has been entered consolidated. Time calculation for each earning or deduction type is not possible.'");
			MessageText = StrReplace(MessageText, "%Employee%", TabularSectionRow.Employee);
			MessageText = StrReplace(MessageText, "%EarningKind%", TabularSectionRow.EarningAndDeductionType);
			MessageField = "Object.EarningsDeductions[" + Object.EarningsDeductions.IndexOf(TabularSectionRow) + "].Employee";
			
			DriveServer.ShowMessageAboutError(Object, MessageText,,,MessageField);
			
		EndIf;
		
		// 2. Clearing
		For Counter = 1 To 3 Do		
			TabularSectionRow["Indicator" + Counter] = "";
			TabularSectionRow["Presentation" + Counter] = Catalogs.EarningsCalculationParameters.EmptyRef();
			TabularSectionRow["Value" + Counter] = 0;	
		EndDo;
		
		// 3. Search of all parameters-identifiers for the formula
		ParametersStructure = New Structure;
		DriveServer.AddParametersToStructure(TabularSectionRow.EarningAndDeductionType.Formula, ParametersStructure);
		
		// 4. Adding the indicator
		Counter = 0;
		For Each ParameterStructures In ParametersStructure Do
			
			If ParameterStructures.Key = "DaysWorked"
					OR ParameterStructures.Key = "HoursWorked"
					OR ParameterStructures.Key = "TariffRate" Then
			    Continue;
			EndIf; 
						
			CalculationParameter = Catalogs.EarningsCalculationParameters.FindByAttribute("ID", ParameterStructures.Key);
		 	If Not ValueIsFilled(CalculationParameter) Then		
				Message = New UserMessage();
				Message.Text = StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = 'The %1 parameter is not found for the employee in row #%2.'"),
					CalculationParameter,
					(Object.EarningsDeductions.IndexOf(TabularSectionRow) + 1));
				Message.Message();
		    EndIf; 
			
			Counter = Counter + 1;
			
			If Counter > 3 Then
				Break;
			EndIf; 
			
			TabularSectionRow["Indicator" + Counter] = ParameterStructures.Key;
			TabularSectionRow["Presentation" + Counter] = CalculationParameter;
			
			If CalculationParameter.SpecifyValueAtPayrollCalculation Then
				Continue;
			EndIf; 
			
		// 5. Indicator calculation
			
			StructureOfSelections = New Structure;
			StructureOfSelections.Insert("RegistrationPeriod", 		Object.RegistrationPeriod);
			StructureOfSelections.Insert("Company", 			DriveServer.GetCompany(Object.Company));
			StructureOfSelections.Insert("Currency", 				Object.DocumentCurrency);
			StructureOfSelections.Insert("Department", 			Object.StructuralUnit);
			StructureOfSelections.Insert("StructuralUnit", 	Object.StructuralUnit);
			StructureOfSelections.Insert("PointInTime", 			EndOfDay(TabularSectionRow.EndDate));
			StructureOfSelections.Insert("BeginOfPeriod", 			TabularSectionRow.StartDate);
			StructureOfSelections.Insert("EndOfPeriod", 			EndOfDay(TabularSectionRow.EndDate));
			StructureOfSelections.Insert("Employee",		 		TabularSectionRow.Employee);
			StructureOfSelections.Insert("EmploymentContractType",		 	TabularSectionRow.Employee.EmploymentContractType);
			StructureOfSelections.Insert("EmployeeCode",		 	TabularSectionRow.Employee.Code);
			StructureOfSelections.Insert("TabNumber",		 		TabularSectionRow.Employee.Code);
			StructureOfSelections.Insert("Performer",		 	TabularSectionRow.Employee);
			StructureOfSelections.Insert("Ind",		 		TabularSectionRow.Employee.Ind);
			StructureOfSelections.Insert("Individual",		 	TabularSectionRow.Employee.Ind);
			StructureOfSelections.Insert("Position", 				TabularSectionRow.Position);
			StructureOfSelections.Insert("EarningAndDeductionType", TabularSectionRow.EarningAndDeductionType);
			StructureOfSelections.Insert("SalesOrder", 		TabularSectionRow.SalesOrder);
			StructureOfSelections.Insert("Order", 					TabularSectionRow.SalesOrder);
			StructureOfSelections.Insert("Project", 				TabularSectionRow.SalesOrder.Project);
			StructureOfSelections.Insert("GLExpenseAccount", 			TabularSectionRow.GLExpenseAccount);
			StructureOfSelections.Insert("BusinessLine",TabularSectionRow.BusinessLine);
			StructureOfSelections.Insert("Size",					TabularSectionRow.Size);
			StructureOfSelections.Insert("DaysWorked",			TabularSectionRow.DaysWorked);
			StructureOfSelections.Insert("HoursWorked",		TabularSectionRow.HoursWorked);
			
			// SalesAmountInNationalCurrency
			PresentationCurrency = Constants.PresentationCurrency.Get();
			If PresentationCurrency = Object.DocumentCurrency Then
				
				StructureOfSelections.Insert("AccountingCurrecyFrequency", 1);
				StructureOfSelections.Insert("AccountingCurrencyExchangeRate", 1);
				StructureOfSelections.Insert("DocumentCurrencyMultiplicity", 1);
				StructureOfSelections.Insert("DocumentCurrencyRate", 1);
				
			Else
				
				ExchangeRatestructure = WorkWithExchangeRates.GetCurrencyRate(PresentationCurrency, Object.Date);
				StructureOfSelections.Insert("AccountingCurrecyFrequency", ExchangeRatestructure.Multiplicity);
				StructureOfSelections.Insert("AccountingCurrencyExchangeRate", ExchangeRatestructure.ExchangeRate);
				
				ExchangeRatestructure = WorkWithExchangeRates.GetCurrencyRate(Object.DocumentCurrency, Object.Date);
				StructureOfSelections.Insert("DocumentCurrencyMultiplicity", ExchangeRatestructure.Multiplicity);
				StructureOfSelections.Insert("DocumentCurrencyRate", ExchangeRatestructure.ExchangeRate);
				
			EndIf;
			
			TextStr =  " " + NStr("en = 'for the employee in row #'") + (Object.EarningsDeductions.IndexOf(TabularSectionRow) + 1);
			
			TabularSectionRow["Value" + Counter] = DriveServer.CalculateParameterValue(StructureOfSelections, CalculationParameter, TextStr);
		
		EndDo;
		
	EndDo; 
	
	FillLoansToEmployees(); //Other calculations. Loans to employees.  
	RefreshFormFooter();
	
EndProcedure

&AtServer
// The procedure calculates the value of the earning or deduction using the formula.
//
Procedure CalculateByFormulas()

	For Each EarningsRow In Object.EarningsDeductions Do
		
		If EarningsRow.ManualCorrection OR Not ValueIsFilled(EarningsRow.EarningAndDeductionType.Formula) Then
			Continue;
		EndIf; 
		
		// 1. Add parameters and values to the structure
		
		ParametersStructure = New Structure;
		ParametersStructure.Insert("TariffRate", EarningsRow.Size);
		ParametersStructure.Insert("DaysWorked", EarningsRow.DaysWorked);
		ParametersStructure.Insert("HoursWorked", EarningsRow.HoursWorked);
		
		For Counter = 1 To 3 Do
			If ValueIsFilled(EarningsRow["Presentation" + Counter]) Then
				ParametersStructure.Insert(EarningsRow["Indicator" + Counter], EarningsRow["Value" + Counter]);
			EndIf; 
		EndDo; 
		
		
		// 2. Calculate using formulas
			 
		Formula = EarningsRow.EarningAndDeductionType.Formula;
		For Each Parameter In ParametersStructure Do
			Formula = StrReplace(Formula, "[" + Parameter.Key + "]", Format(Parameter.Value, "NDS=.; NZ=0; NG=0"));
		EndDo;
		Try
			CalculatedSum = Eval(Formula);
		Except
			MessageText = StrTemplate(NStr("en = 'Cannot calculate the Earning amount in the line #%1 The formula may contain an error, or indicators are not filled in.'"), 
								(Object.EarningsDeductions.IndexOf(EarningsRow) + 1));
			MessageField = "Object.EarningsDeductions[" + Object.EarningsDeductions.IndexOf(EarningsRow) + "].EarningAndDeductionType";
			
			DriveServer.ShowMessageAboutError(Object, MessageText,,,MessageField);
			
			CalculatedSum = 0;
		EndTry;
		EarningsRow.Amount = Round(CalculatedSum, 2); 

	EndDo;
	
	RefreshFormFooter();

EndProcedure

// Gets the data set from the server for the ExpenseGLAccount attribute of the EarningsAndDeductions tabular section
//
&AtServerNoContext
Function GetDataCostsAccount(GLExpenseAccount)
	
	DataStructure = New Structure("TypeOfAccount", Undefined);
	If ValueIsFilled(GLExpenseAccount) Then
		
		DataStructure.TypeOfAccount = GLExpenseAccount.TypeOfAccount;
		
	EndIf;
	
	Return DataStructure;
	
EndFunction

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
	StructureData.Insert("Counterparty", DriveServer.GetCompany(Company));
	
	Return StructureData;
	
EndFunction

&AtServer
// Procedure updates data in form footer.
//
Procedure RefreshFormFooter()
	
	Document			= FormAttributeToValue("Object");
	ResultsStructure	= Document.GetDocumentAmount();
	DocumentAmount		= ResultsStructure.DocumentAmount;
	AmountAccrued		= ResultsStructure.AmountAccrued;
	AmountWithheld		= ResultsStructure.AmountWithheld;
	AmountCharged		= ResultsStructure.AmountCharged;
	ValueToFormAttribute(Document, "Object");
	
EndProcedure

#EndRegion

#Region FormEventsHandlers

&AtServer
// Procedure - event handler OnCreateAtServer of the form.
// The procedure implements
// - initialization of form parameters,
// - setting of the form functional options parameters.
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
		Object.RegistrationPeriod = BegOfMonth(CurrentDate());
	EndIf;
	
	RegistrationPeriodPresentation = Format(Object.RegistrationPeriod, "DF='MMMM yyyy'");
	
	// Form attributes setting.
	DocumentDate = Object.Date;
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentDate();
	EndIf;
	
	DocumentCurrency = Object.DocumentCurrency;
	ParentCompany = DriveServer.GetCompany(Object.Company);
	
	RefreshFormFooter();
	
	If Not Constants.UseSecondaryEmployment.Get() Then
		
		If Items.Find("EarningsDeductionsEmployeeCode") <> Undefined Then
			
			Items.EarningsDeductionsEmployeeCode.Visible = False;
			
		EndIf;
		
		If Items.Find("IncomeTaxesEmployeeCode") <> Undefined Then
			
			Items.IncomeTaxesEmployeeCode.Visible = False;
			
		EndIf;
		
	EndIf;
	
	If Object.EarningsDeductions.Count() > 0 Then
		
		For Each DataRow In Object.EarningsDeductions Do
			
			If ValueIsFilled(DataRow.GLExpenseAccount) Then
				
				DataRow.TypeOfAccount = DataRow.GLExpenseAccount.TypeOfAccount;
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
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
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
// Procedure - Calculate command handler.
//
Procedure Calculate(Command)
	
	CalculateByFormulas();
	
EndProcedure

&AtClient
// The procedure fills in the Employees tabular section with filter by department.
//
Procedure Fill(Command)
	
	If Not ValueIsFilled(Object.StructuralUnit) Then
		
		Message = New UserMessage();
		Message.Text = NStr("en = 'Department is not populated. Document population is canceled.'");
		Message.Field = "Object.StructuralUnit";
		Message.Message();
		
		Return;
		
	EndIf;

	If Object.EarningsDeductions.Count() > 0 AND Object.IncomeTaxes.Count() > 0 Then
		
		Response = Undefined;

		
		ShowQueryBox(New NotifyDescription("FillEnd1", ThisObject), NStr("en = 'Document tabular sections will be cleared. Continue?'"), QuestionDialogMode.YesNo, 0);
        Return;
		
	ElsIf Object.EarningsDeductions.Count() > 0 OR Object.IncomeTaxes.Count() > 0
		OR Object.LoanRepayment.Count() > 0 Then
		
		ShowQueryBox(New NotifyDescription("FillEnd", ThisObject), NStr("en = 'Tabular section of the document will be cleared. Continue?'"), QuestionDialogMode.YesNo, 0);
        Return; 
		
	EndIf;
	
	FillFragment1();
	
EndProcedure

&AtClient
Procedure FillEnd1(Result, AdditionalParameters) Export
	
	Response = Result;
	
	If Response <> DialogReturnCode.Yes Then
		
		Return;
		
	EndIf;
	
	
	FillFragment1();
	
EndProcedure

&AtClient
Procedure FillFragment1()
	
	FillFragment();
	
EndProcedure

&AtClient
Procedure FillEnd(Result, AdditionalParameters) Export
	
	Response = Result;
	
	If Response <> DialogReturnCode.Yes Then
		Return;
		
	EndIf; 
	
	
	FillFragment();
	
EndProcedure

&AtClient
Procedure FillFragment()
	
	FillByDepartment();
	
EndProcedure

#EndRegion

#Region FormAttributesEventsHandlers

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
	StructureData = GetCompanyDataOnChange(Object.Company);
	Counterparty = StructureData.Counterparty;
	
EndProcedure

&AtClient
// Procedure - handler of event OnChange of input field DocumentCurrency.
//
Procedure DocumentCurrencyOnChange(Item)
	
	If Object.DocumentCurrency = DocumentCurrency Then
		Return;
	EndIf; 
	
	If Object.EarningsDeductions.Count() > 0
		Or Object.LoanRepayment.Count() > 0 Then
		
		Mode = QuestionDialogMode.YesNo;
		Response = Undefined;
		
		ShowQueryBox(New NotifyDescription("DocumentCurrencyOnChangeEnd", ThisObject), NStr("en = 'Tabular section will be cleared. Continue?'"), Mode, 0);
		Return;
		
	EndIf; 
	
	DocumentCurrencyOnChangeFragment();
EndProcedure

// Procedure event handler of field management RegistrationPeriod
//
&AtClient
Procedure RegistrationPeriodTuning(Item, Direction, StandardProcessing)
	
	DriveClient.OnRegistrationPeriodRegulation(ThisForm, Direction);
	DriveClient.OnChangeRegistrationPeriod(ThisForm);
	
EndProcedure

// Procedure-handler of the data entry start event of the RegistrationPeriod field
//
&AtClient
Procedure RegistrationPeriodStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing	 = False;
	
	CalendarDateOnOpen = ?(ValueIsFilled(Object.RegistrationPeriod), Object.RegistrationPeriod, DriveReUse.GetSessionCurrentDate());
	
	OpenForm("CommonForm.Calendar", DriveClient.GetCalendarGenerateFormOpeningParameters(CalendarDateOnOpen), ThisForm);
	
EndProcedure

&AtClient
Procedure DocumentCurrencyOnChangeEnd(Result, AdditionalParameters) Export
    
    Response = Result;
    If Response = DialogReturnCode.Yes Then
        Object.EarningsDeductions.Clear();
		Object.IncomeTaxes.Clear();
		Object.LoanRepayment.Clear();
	EndIf;
    
    
    DocumentCurrencyOnChangeFragment();

EndProcedure

&AtClient
Procedure DocumentCurrencyOnChangeFragment()
    
    DocumentCurrency = Object.DocumentCurrency;

EndProcedure

&AtClient
Procedure EarningsDeductionsEmployeeOnChange(Item)
	
	CurrentRow = Items.EarningsDeductions.CurrentData;
	
	DataStructure = New Structure("GLExpenseAccount, TypeOfAccount");
	DataStructure.Insert("EarningAndDeductionType",	CurrentRow.EarningAndDeductionType);
	DataStructure.Insert("Employee",				CurrentRow.Employee);
	DataStructure.Insert("StartDate",				CurrentRow.StartDate);
	
	GetGLAccountByDefault(DataStructure);
	FillPropertyValues(CurrentRow, DataStructure); 
	
EndProcedure

&AtClient
Procedure EarningsDeductionsExpensesAccountOnChange(Item)
	
	DataCurrentRows = Items.EarningsDeductions.CurrentData;
	If DataCurrentRows <> Undefined Then
		
		DataStructure = GetDataCostsAccount(DataCurrentRows.GLExpenseAccount);
		DataCurrentRows.TypeOfAccount = DataStructure.TypeOfAccount;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure EarningsDeductionsExpensesAccountStartChoice(Item, ChoiceData, StandardProcessing)
	
	DataCurrentRows = Items.EarningsDeductions.CurrentData;
	
	DataStructure = New Structure;
	DataStructure.Insert("EarningAndDeductionType", 
		?(DataCurrentRows = Undefined, Undefined, DataCurrentRows.EarningAndDeductionType));
		
	ReceiveDataForSelectAccountsSettlements(DataStructure);
	
	NewArray = New Array;
	NewParameter = New ChoiceParameter("Filter.TypeOfAccount", New FixedArray(DataStructure.GLAccountsAvailableTypes));
	NewArray.Add(NewParameter);
	Items.EarningsDeductionsExpensesAccount.ChoiceParameters = New FixedArray(NewArray);
	
EndProcedure

&AtClient
// Procedure - OnStartEdit event handler of the Earnings tabular section.
//
Procedure EarningsDeductionsOnStartEdit(Item, NewRow, Copy)
	
	If NewRow Then
		
		If Not Copy Then
			
			CurrentData 				= Items.EarningsDeductions.CurrentData;
			
			CurrentData.StartDate 	= Object.RegistrationPeriod;
			CurrentData.EndDate = EndOfMonth(Object.RegistrationPeriod);
			CurrentData.ManualCorrection = True;
			
		EndIf; 
		
	EndIf;

EndProcedure

&AtClient
// Procedure - OnChange event handler of the Earnings tabular section.
//
Procedure EarningsDeductionsOnChange(Item)
	
	RefreshFormFooter();
	
EndProcedure

&AtClient
Procedure EarningsDeductionsStartDateOnChange(Item)
	CurrentRow = Items.EarningsDeductions.CurrentData;
	
	DataStructure = New Structure("GLExpenseAccount, TypeOfAccount");
	DataStructure.Insert("EarningAndDeductionType",	CurrentRow.EarningAndDeductionType);
	DataStructure.Insert("Employee",				CurrentRow.Employee);
	DataStructure.Insert("StartDate",				CurrentRow.StartDate);
	
	GetGLAccountByDefault(DataStructure);
	FillPropertyValues(CurrentRow, DataStructure); 
EndProcedure

&AtClient
// Procedure - OnChange event handler of the Earnings tabular section.
//
Procedure IncomeTaxesOnChange(Item)
	
	RefreshFormFooter();
	
EndProcedure

&AtClient
// Procedure - OnChange event data of the EarningAndDeductionType attribute of the EarningsDeductions tabular section.
//
Procedure EarningsDeductionsEarningAndDeductionTypeOnChange(Item)
	
	CurrentRow = Items.EarningsDeductions.CurrentData;
	
	DataStructure = New Structure("GLExpenseAccount, TypeOfAccount");
	DataStructure.Insert("EarningAndDeductionType",	CurrentRow.EarningAndDeductionType);
	DataStructure.Insert("Employee",				CurrentRow.Employee);
	DataStructure.Insert("StartDate",				CurrentRow.StartDate);
	
	FillDataStructure(DataStructure);
	FillPropertyValues(CurrentRow, DataStructure);
		
EndProcedure

&AtServer
// Fills the indicators and GL account in the data structure.
//
Function FillDataStructure(DataStructure)
	
	FillIndicators(DataStructure);
	GetGLAccountByDefault(DataStructure);
	
EndFunction

&AtClient
Procedure LoanRepaymentOnChange(Item)
	
	RefreshFormFooter();
	
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

#Region LoansToEmployees

&AtServer
Procedure FillLoansToEmployees()
	
	Object.LoanRepayment.Clear();
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	NestedSelect.Employee
	|INTO UnitEmployees
	|FROM
	|	(SELECT
	|		EmployeesSliceLast.Employee AS Employee
	|	FROM
	|		InformationRegister.Employees.SliceLast(&BeginOfMonth, Company = &Company) AS EmployeesSliceLast
	|	WHERE
	|		EmployeesSliceLast.StructuralUnit = &StructuralUnit
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		Employees.Employee
	|	FROM
	|		InformationRegister.Employees AS Employees
	|	WHERE
	|		Employees.StructuralUnit = &StructuralUnit
	|		AND Employees.Period BETWEEN &BeginOfMonth AND &EndOfMonth
	|		AND Employees.Company = &Company) AS NestedSelect
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	LoanSettlements.LoanContract AS LoanContract,
	|	LoanSettlements.LoanContract.SettlementsCurrency AS Currency,
	|	LoanSettlements.PrincipalDebtCurReceipt AS PrincipalDebtCurAccrued,
	|	LoanSettlements.PrincipalDebtCurExpense AS PrincipalDebtCurCharged,
	|	LoanSettlements.InterestCurReceipt AS InterestCurAccrued,
	|	LoanSettlements.InterestCurExpense AS InterestCurCharged,
	|	LoanSettlements.CommissionCurReceipt AS CommissionCurAccrued,
	|	LoanSettlements.CommissionCurExpense AS CommissionCurCharged
	|INTO TemporaryTableAmountAccruedAndChargedWithRegisterRecords
	|FROM
	|	AccumulationRegister.LoanSettlements.Turnovers(
	|			,
	|			,
	|			,
	|			LoanContract.ChargeFromSalary
	|				AND Company = &Company
	|				AND LoanContract.LoanKind = &LoanKindLoanContract
	|				AND LoanKind = &LoanKindLoanContract
	|				AND LoanContract.SettlementsCurrency = &Currency
	|				AND Counterparty IN
	|					(SELECT DISTINCT
	|						UnitEmployees.Employee
	|					FROM
	|						UnitEmployees AS UnitEmployees)) AS LoanSettlements
	|
	|UNION ALL
	|
	|SELECT
	|	LoanSettlements.LoanContract,
	|	LoanSettlements.LoanContract.SettlementsCurrency,
	|	CASE
	|		WHEN LoanSettlements.RecordType = VALUE(AccumulationRecordType.Receipt)
	|			THEN -LoanSettlements.PrincipalDebtCur
	|		ELSE LoanSettlements.PrincipalDebtCur
	|	END,
	|	CASE
	|		WHEN LoanSettlements.RecordType = VALUE(AccumulationRecordType.Expense)
	|			THEN -LoanSettlements.PrincipalDebtCur
	|		ELSE LoanSettlements.PrincipalDebtCur
	|	END,
	|	CASE
	|		WHEN LoanSettlements.RecordType = VALUE(AccumulationRecordType.Receipt)
	|			THEN -LoanSettlements.InterestCur
	|		ELSE LoanSettlements.InterestCur
	|	END,
	|	CASE
	|		WHEN LoanSettlements.RecordType = VALUE(AccumulationRecordType.Expense)
	|			THEN -LoanSettlements.InterestCur
	|		ELSE LoanSettlements.InterestCur
	|	END,
	|	CASE
	|		WHEN LoanSettlements.RecordType = VALUE(AccumulationRecordType.Receipt)
	|			THEN -LoanSettlements.CommissionCur
	|		ELSE LoanSettlements.CommissionCur
	|	END,
	|	CASE
	|		WHEN LoanSettlements.RecordType = VALUE(AccumulationRecordType.Expense)
	|			THEN -LoanSettlements.CommissionCur
	|		ELSE LoanSettlements.CommissionCur
	|	END
	|FROM
	|	AccumulationRegister.LoanSettlements AS LoanSettlements
	|WHERE
	|	LoanSettlements.Recorder = &Ref
	|	AND LoanSettlements.LoanContract.ChargeFromSalary
	|	AND LoanSettlements.Company = &Company
	|	AND LoanSettlements.LoanContract.LoanKind = &LoanKindLoanContract
	|	AND LoanSettlements.LoanKind = &LoanKindLoanContract
	|	AND LoanSettlements.Counterparty IN
	|			(SELECT DISTINCT
	|				UnitEmployees.Employee
	|			FROM
	|				UnitEmployees AS UnitEmployees)
	|	AND LoanSettlements.LoanContract.SettlementsCurrency = &Currency
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TemporaryTableAmountAccruedAndChargedWithRegisterRecords.LoanContract,
	|	TemporaryTableAmountAccruedAndChargedWithRegisterRecords.Currency,
	|	SUM(TemporaryTableAmountAccruedAndChargedWithRegisterRecords.PrincipalDebtCurAccrued) AS PrincipalDebtCurAccrued,
	|	SUM(TemporaryTableAmountAccruedAndChargedWithRegisterRecords.PrincipalDebtCurCharged) AS PrincipalDebtCurCharged,
	|	SUM(TemporaryTableAmountAccruedAndChargedWithRegisterRecords.InterestCurAccrued) AS InterestCurAccrued,
	|	SUM(TemporaryTableAmountAccruedAndChargedWithRegisterRecords.InterestCurCharged) AS InterestCurCharged,
	|	SUM(TemporaryTableAmountAccruedAndChargedWithRegisterRecords.CommissionCurAccrued) AS CommissionCurAccrued,
	|	SUM(TemporaryTableAmountAccruedAndChargedWithRegisterRecords.CommissionCurCharged) AS CommissionCurCharged
	|INTO TemporaryTableAmountAccruedAndCharged
	|FROM
	|	TemporaryTableAmountAccruedAndChargedWithRegisterRecords AS TemporaryTableAmountAccruedAndChargedWithRegisterRecords
	|
	|GROUP BY
	|	TemporaryTableAmountAccruedAndChargedWithRegisterRecords.LoanContract,
	|	TemporaryTableAmountAccruedAndChargedWithRegisterRecords.Currency
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	LoanRepaymentSchedule.LoanContract AS LoanContract,
	|	LoanRepaymentSchedule.LoanContract.SettlementsCurrency AS LoanContractCurrency,
	|	SUM(LoanRepaymentSchedule.Principal) AS PrincipalAmountSchedule,
	|	SUM(LoanRepaymentSchedule.Interest) AS InterestAmountSchedule,
	|	SUM(LoanRepaymentSchedule.Commission) AS CommissionAmountSchedule
	|INTO TemporaryTableAmountToCharge
	|FROM
	|	UnitEmployees AS UnitEmployees
	|		INNER JOIN InformationRegister.LoanRepaymentSchedule AS LoanRepaymentSchedule
	|		ON UnitEmployees.Employee = LoanRepaymentSchedule.LoanContract.Employee
	|WHERE
	|	LoanRepaymentSchedule.Period <= &EndOfMonth
	|	AND LoanRepaymentSchedule.LoanContract.SettlementsCurrency = &Currency
	|
	|GROUP BY
	|	LoanRepaymentSchedule.LoanContract,
	|	LoanRepaymentSchedule.LoanContract.SettlementsCurrency
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TemporaryTableAmountToCharge.LoanContract AS LoanContract,
	|	TemporaryTableAmountToCharge.LoanContractCurrency AS Currency,
	|	TemporaryTableAmountToCharge.PrincipalAmountSchedule,
	|	TemporaryTableAmountToCharge.InterestAmountSchedule,
	|	TemporaryTableAmountToCharge.CommissionAmountSchedule,
	|	ISNULL(TemporaryTableAmountAccruedAndCharged.PrincipalDebtCurAccrued, 0) AS PrincipalDebtCurAccrued,
	|	ISNULL(TemporaryTableAmountAccruedAndCharged.PrincipalDebtCurCharged, 0) AS PrincipalDebtCurCharged,
	|	ISNULL(TemporaryTableAmountAccruedAndCharged.InterestCurAccrued, 0) AS InterestCurAccrued,
	|	ISNULL(TemporaryTableAmountAccruedAndCharged.InterestCurCharged, 0) AS InterestCurCharged,
	|	ISNULL(TemporaryTableAmountAccruedAndCharged.CommissionCurAccrued, 0) AS CommissionCurAccrued,
	|	ISNULL(TemporaryTableAmountAccruedAndCharged.CommissionCurCharged, 0) AS CommissionCurCharged,
	|	TemporaryTableAmountAccruedAndCharged.LoanContract.Employee AS Employee,
	|	TemporaryTableAmountAccruedAndCharged.LoanContract.Total AS TotalAmountOfLoan
	|FROM
	|	TemporaryTableAmountToCharge AS TemporaryTableAmountToCharge
	|		LEFT JOIN TemporaryTableAmountAccruedAndCharged AS TemporaryTableAmountAccruedAndCharged
	|		ON TemporaryTableAmountToCharge.LoanContract = TemporaryTableAmountAccruedAndCharged.LoanContract";
	
	Query.SetParameter("BeginOfMonth", Object.RegistrationPeriod);
	Query.SetParameter("EndOfMonth", EndOfMonth(Object.RegistrationPeriod));
	Query.SetParameter("Company", DriveServer.GetCompany(Object.Company));
	Query.SetParameter("Currency", Object.DocumentCurrency);
	Query.SetParameter("LoanKindLoanContract", Enums.LoanContractTypes.EmployeeLoanAgreement);
	Query.SetParameter("Ref", Object.Ref);
	Query.SetParameter("StructuralUnit", Object.StructuralUnit);
	
	QueryResult = Query.Execute();
	
	Selection = QueryResult.Select();
	
	While Selection.Next() Do
		
		// If the money under the loan agreement hasn't been paid, then we will not repay.
		If Selection.PrincipalDebtCurAccrued = 0 Then
			Continue;	
		EndIf;
		
		NeedToRepayLoan = Selection.PrincipalAmountSchedule - Selection.PrincipalDebtCurCharged;
		NeedToRepayLoan = ?(NeedToRepayLoan < 0, 0, NeedToRepayLoan);
		NeedToRepayLoan = ?(Selection.PrincipalDebtCurCharged > Selection.TotalAmountOfLoan, 0, NeedToRepayLoan);
		
		InterestAccrued = (Selection.InterestAmountSchedule + Selection.CommissionAmountSchedule) - (Selection.InterestCurAccrued + Selection.CommissionCurAccrued);
		InterestAccrued = ?(InterestAccrued < 0, 0, InterestAccrued);
		
		InterestCharged = (Selection.InterestAmountSchedule + Selection.CommissionAmountSchedule) - (Selection.InterestCurCharged + Selection.CommissionCurCharged);
		InterestCharged = ?(InterestCharged < 0, 0, InterestCharged);
		
		If NeedToRepayLoan > 0 OR InterestAccrued > 0 Then
			NewRow = Object.LoanRepayment.Add();
			FillPropertyValues(NewRow, Selection);
			NewRow.PrincipalCharged	= NeedToRepayLoan;
			NewRow.InterestAccrued	= InterestAccrued;
			NewRow.InterestCharged	= InterestCharged;
		EndIf;
		
	EndDo;
	
EndProcedure

#EndRegion
