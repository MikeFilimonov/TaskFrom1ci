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
	|	Backorders.LineNumber AS LineNumber,
	|	Backorders.Company AS Company,
	|	Backorders.SalesOrder AS SalesOrder,
	|	Backorders.Products AS Products,
	|	Backorders.Characteristic AS Characteristic,
	|	Backorders.SupplySource AS SupplySource,
	|	Backorders.Quantity AS QuantityBeforeWrite,
	|	Backorders.Quantity AS QuantityChange,
	|	Backorders.Quantity AS QuantityOnWrite
	|INTO RegisterRecordsBackordersChange
	|FROM
	|	AccumulationRegister.Backorders AS Backorders");
	
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	QueryResult = Query.Execute();
	
	StructureTemporaryTables.Insert("RegisterRecordsBackordersChange", False);
	
EndProcedure

#EndRegion

#EndIf