#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ProgramInterface

// Procedure creates an empty temporary table of records change.
//
Procedure CreateEmptyTemporaryTableChange(AdditionalProperties) Export
	
	If Not AdditionalProperties.Property("ForPosting")
	 OR Not AdditionalProperties.ForPosting.Property("StructureTemporaryTables") Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	Query = New Query(
	"SELECT TOP 0
	|	Payroll.LineNumber AS LineNumber,
	|	Payroll.Company AS Company,
	|	Payroll.StructuralUnit AS StructuralUnit,
	|	Payroll.Employee AS Employee,
	|	Payroll.Currency AS Currency,
	|	Payroll.RegistrationPeriod AS RegistrationPeriod,
	|	Payroll.Amount AS SumBeforeWrite,
	|	Payroll.Amount AS AmountChange,
	|	Payroll.Amount AS AmountOnWrite,
	|	Payroll.AmountCur AS AmountCurBeforeWrite,
	|	Payroll.AmountCur AS SumCurChange,
	|	Payroll.AmountCur AS SumCurOnWrite
	|INTO RegisterRecordsPayrollUpdate
	|FROM
	|	AccumulationRegister.Payroll AS Payroll");
	
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	QueryResult = Query.Execute();
	
	StructureTemporaryTables.Insert("RegisterRecordsPayrollUpdate", False);
	
EndProcedure

#EndRegion

#EndIf