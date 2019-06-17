#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefTerminationOfEmployment, StructureAdditionalProperties) Export

	Query = New Query(
	"SELECT
	|	&Company AS Company,
	|	TerminationOfEmploymentStaff.LineNumber,
	|	TerminationOfEmploymentStaff.Employee,
	|	VALUE(Catalog.BusinessUnits.EmptyRef) AS StructuralUnit,
	|	VALUE(Catalog.Positions.EmptyRef) AS Position,
	|	TerminationOfEmploymentStaff.Period
	|INTO TableEmployees
	|FROM
	|	Document.TerminationOfEmployment.Employees AS TerminationOfEmploymentStaff
	|WHERE
	|	TerminationOfEmploymentStaff.Ref = &Ref
	|;
	|	
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableEmployees.Company,
	|	TableEmployees.LineNumber,
	|	TableEmployees.Employee,
	|	TableEmployees.StructuralUnit,
	|	TableEmployees.Position,
	|	TableEmployees.Period
	|FROM
	|	TableEmployees AS TableEmployees
	|;
	|	
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	NestedSelect.Employee,
	|	NestedSelect.EarningAndDeductionType,
	|	NestedSelect.Currency,
	|	NestedSelect.Company,
	|	FALSE AS Actuality,
	|	VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef) AS GLExpenseAccount,
	|	0 AS Amount,
	|	NestedSelect.PeriodRows AS Period
	|FROM
	|	(SELECT
	|		TableEmployees.Employee AS Employee,
	|		MAX(CompensationPlan.Period) AS Period,
	|		CompensationPlan.EarningAndDeductionType AS EarningAndDeductionType,
	|		CompensationPlan.Currency AS Currency,
	|		CompensationPlan.Company AS Company,
	|		TableEmployees.Period AS PeriodRows
	|	FROM
	|		TableEmployees AS TableEmployees
	|			INNER JOIN InformationRegister.CompensationPlan AS CompensationPlan
	|			ON TableEmployees.Employee = CompensationPlan.Employee
	|				AND (CompensationPlan.Period <= TableEmployees.Period)
	|				AND TableEmployees.Company = CompensationPlan.Company
	|	
	|	GROUP BY
	|		CompensationPlan.EarningAndDeductionType,
	|		CompensationPlan.Currency,
	|		TableEmployees.Employee,
	|		TableEmployees.Period,
	|		CompensationPlan.Company) AS NestedSelect
	|		INNER JOIN InformationRegister.CompensationPlan AS CompensationPlan
	|		ON NestedSelect.Company = CompensationPlan.Company
	|			AND NestedSelect.Employee = CompensationPlan.Employee
	|			AND NestedSelect.EarningAndDeductionType = CompensationPlan.EarningAndDeductionType
	|			AND NestedSelect.Currency = CompensationPlan.Currency
	|			AND NestedSelect.Period = CompensationPlan.Period
	|WHERE
	|	CompensationPlan.Actuality");
	 
	Query.SetParameter("Ref", DocumentRefTerminationOfEmployment);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	
	TempTablesManager = New TempTablesManager;
	Query.TempTablesManager = TempTablesManager;
	
	ResultsArray = Query.ExecuteBatch();
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableEmployees", ResultsArray[1].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableCompensationPlan", ResultsArray[2].Unload());
	
	StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager = Query.TempTablesManager;
	
EndProcedure

#EndRegion

#Region PrintInterface

// Fills in the list of printing commands.
// 
// Parameters:
//   PrintCommands - ValueTable - see fields' content in the PrintManagement.CreatePrintCommandsCollection function.
//
Procedure AddPrintCommands(PrintCommands) Export
	
	
	
EndProcedure

#EndRegion

#EndIf