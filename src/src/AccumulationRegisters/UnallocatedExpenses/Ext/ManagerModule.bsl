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
	|	UnallocatedExpenses.LineNumber AS LineNumber,
	|	UnallocatedExpenses.Company AS Company,
	|	UnallocatedExpenses.Document AS Document,
	|	UnallocatedExpenses.Item AS Item,
	|	UnallocatedExpenses.AmountIncome AS AmountIncomeBeforeWrite,
	|	UnallocatedExpenses.AmountIncome AS AmountIncomeUpdate,
	|	UnallocatedExpenses.AmountIncome AS AmountIncomeOnWrite,
	|	UnallocatedExpenses.AmountExpense AS AmountExpensesBeforeWrite,
	|	UnallocatedExpenses.AmountExpense AS AmountExpensesUpdate,
	|	UnallocatedExpenses.AmountExpense AS AmountExpensesOnWrite
	|INTO RegisterRecordsUnallocatedExpensesChange
	|FROM
	|	AccumulationRegister.UnallocatedExpenses AS UnallocatedExpenses");
	
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	QueryResult = Query.Execute();
	
	StructureTemporaryTables.Insert("RegisterRecordsUnallocatedExpensesChange", False);
	
EndProcedure

#EndRegion

#EndIf