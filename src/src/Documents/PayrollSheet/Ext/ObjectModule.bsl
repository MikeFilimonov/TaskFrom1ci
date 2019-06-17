#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

// Procedure - event handler BeforeWrite object.
//
Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;

	DocumentAmount = Employees.Total("PaymentAmount");
	
EndProcedure

#EndRegion

#Region ProgramInterface

// Procedure fills tabular section Employees balance by charges.
//
Procedure FillByBalanceAtServer() Export
	
	If OperationKind = Enums.OperationTypesPayrollSheet.Salary Then
	
		Query = New Query;
		Query.Text = "SELECT
		               |	PayrollBalance.Employee,
		               |	SUM(CASE
		               |			WHEN &SettlementsCurrency = &DocumentCurrency
		               |				THEN PayrollBalance.AmountCurBalance
		               |			ELSE CAST(PayrollBalance.AmountCurBalance * &ExchangeRate / &Multiplicity AS NUMBER(15, 2))
		               |		END) AS PaymentAmount,
		               |	SUM(PayrollBalance.AmountCurBalance) AS SettlementsAmount
		               |FROM
		               |	AccumulationRegister.Payroll.Balance(,
		               |			Company = &Company
		               |				AND RegistrationPeriod = &RegistrationPeriod
		               |				AND Currency = &SettlementsCurrency
		               |				AND StructuralUnit = &StructuralUnit) AS PayrollBalance
		               |WHERE
		               |	PayrollBalance.AmountCurBalance > 0
		               |
		               |GROUP BY
		               |	PayrollBalance.Employee
		               |
		               |ORDER BY
		               |	PayrollBalance.Employee.Description";
		
		Query.SetParameter("RegistrationPeriod", 	RegistrationPeriod);
		Query.SetParameter("Company", 		DriveServer.GetCompany(Company));
		Query.SetParameter("StructuralUnit", StructuralUnit);
		Query.SetParameter("SettlementsCurrency",		SettlementsCurrency);
		Query.SetParameter("DocumentCurrency",	DocumentCurrency);
		Query.SetParameter("ExchangeRate",				ExchangeRate);
		Query.SetParameter("Multiplicity",			Multiplicity);
		
		Employees.Load(Query.Execute().Unload());

	ElsIf OperationKind = Enums.OperationTypesPayrollSheet.Advance Then	
		
		Message = New UserMessage();
		Message.Text = NStr("en = 'If advance is paid, population according to balance is not provided.'");
 		Message.Message();
		
	EndIf;
	
EndProcedure

// Procedure fills tabular section Employees by department.
//
Procedure FillByDepartmentAtServer() Export
		
	Query = New Query;
	Query.Text = "SELECT DISTINCT
	               |	EmployeesDeparnments.Employee AS Employee,
	               |	EmployeesDeparnments.StructuralUnit AS StructuralUnit
	               |FROM
	               |	(SELECT
	               |		EmployeesSliceLast.Employee AS Employee,
	               |		EmployeesSliceLast.StructuralUnit AS StructuralUnit
	               |	FROM
	               |		InformationRegister.Employees.SliceLast(
	               |				&RegistrationPeriod,
	               |				Company = &Company
	               |					AND (StructuralUnit = &StructuralUnit
	               |						OR StructuralUnit = VALUE(Catalog.BusinessUnits.EmptyRef))) AS EmployeesSliceLast
	               |	
	               |	UNION ALL
	               |	
	               |	SELECT
	               |		Employees.Employee,
	               |		Employees.StructuralUnit
	               |	FROM
	               |		InformationRegister.Employees AS Employees
	               |	WHERE
	               |		Employees.Company = &Company
	               |		AND Employees.StructuralUnit = &StructuralUnit
	               |		AND Employees.Period between &RegistrationPeriod AND ENDOFPERIOD(&RegistrationPeriod, MONTH)) AS EmployeesDeparnments
	               |WHERE
	               |	EmployeesDeparnments.StructuralUnit <> VALUE(Catalog.BusinessUnits.EmptyRef)
	               |
	               |GROUP BY
	               |	EmployeesDeparnments.Employee,
	               |	EmployeesDeparnments.StructuralUnit
	               |
	               |ORDER BY
	               |	Employee";
	
	Query.SetParameter("RegistrationPeriod", 		RegistrationPeriod);
	Query.SetParameter("StructuralUnit",		StructuralUnit);
	Query.SetParameter("Company", 			DriveServer.GetCompany(Company));
	
	Employees.Load(Query.Execute().Unload());
	
EndProcedure

#EndRegion

#EndIf