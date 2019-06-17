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
	|	POSSummary.LineNumber AS LineNumber,
	|	POSSummary.Company AS Company,
	|	POSSummary.StructuralUnit AS StructuralUnit,
	|	POSSummary.Currency AS Currency,
	|	POSSummary.Amount AS SumBeforeWrite,
	|	POSSummary.Amount AS AmountChange,
	|	POSSummary.Amount AS AmountOnWrite,
	|	POSSummary.AmountCur AS AmountCurBeforeWrite,
	|	POSSummary.AmountCur AS SumCurChange,
	|	POSSummary.AmountCur AS SumCurOnWrite,
	|	POSSummary.Cost AS CostBeforeWrite,
	|	POSSummary.Cost AS CostUpdate,
	|	POSSummary.Cost AS CostOnWrite
	|INTO RegisterRecordsPOSSummaryUpdate
	|FROM
	|	AccumulationRegister.POSSummary AS POSSummary");
	
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	QueryResult = Query.Execute();
	
	StructureTemporaryTables.Insert("RegisterRecordsPOSSummaryUpdate", False);
	
EndProcedure

#EndRegion

#EndIf