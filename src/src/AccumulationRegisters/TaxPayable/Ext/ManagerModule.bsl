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
	|	TaxPayable.LineNumber AS LineNumber,
	|	TaxPayable.Company AS Company,
	|	TaxPayable.TaxKind AS TaxKind,
	|	TaxPayable.Amount AS SumBeforeWrite,
	|	TaxPayable.Amount AS AmountChange,
	|	TaxPayable.Amount AS AmountOnWrite
	|INTO RegisterRecordsTaxesSettlementsUpdate
	|FROM
	|	AccumulationRegister.TaxPayable AS TaxPayable");
	
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	QueryResult = Query.Execute();
	
	StructureTemporaryTables.Insert("RegisterRecordsTaxesSettlementsUpdate", False);
	
EndProcedure

#EndRegion

#EndIf