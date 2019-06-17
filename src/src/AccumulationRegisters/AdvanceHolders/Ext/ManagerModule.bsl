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
	|	AccumulationRegisterAdvanceHolders.LineNumber AS LineNumber,
	|	AccumulationRegisterAdvanceHolders.Company AS Company,
	|	AccumulationRegisterAdvanceHolders.Employee AS Employee,
	|	AccumulationRegisterAdvanceHolders.Currency AS Currency,
	|	AccumulationRegisterAdvanceHolders.Document AS Document,
	|	AccumulationRegisterAdvanceHolders.Amount AS SumBeforeWrite,
	|	AccumulationRegisterAdvanceHolders.Amount AS AmountChange,
	|	AccumulationRegisterAdvanceHolders.Amount AS AmountOnWrite,
	|	AccumulationRegisterAdvanceHolders.AmountCur AS AmountCurBeforeWrite,
	|	AccumulationRegisterAdvanceHolders.AmountCur AS SumCurChange,
	|	AccumulationRegisterAdvanceHolders.AmountCur AS SumCurOnWrite
	|INTO RegisterRecordsAdvanceHoldersChange
	|FROM
	|	AccumulationRegister.AdvanceHolders AS AccumulationRegisterAdvanceHolders");
	
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	QueryResult = Query.Execute();
	
	StructureTemporaryTables.Insert("RegisterRecordsAdvanceHoldersChange", False);
	
EndProcedure

#EndRegion

#EndIf