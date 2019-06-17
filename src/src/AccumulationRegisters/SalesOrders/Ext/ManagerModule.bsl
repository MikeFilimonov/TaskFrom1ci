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
	|	SalesOrders.LineNumber AS LineNumber,
	|	SalesOrders.Company AS Company,
	|	SalesOrders.SalesOrder AS SalesOrder,
	|	SalesOrders.Products AS Products,
	|	SalesOrders.Characteristic AS Characteristic,
	|	SalesOrders.Quantity AS QuantityBeforeWrite,
	|	SalesOrders.Quantity AS QuantityChange,
	|	SalesOrders.Quantity AS QuantityOnWrite
	|INTO RegisterRecordsSalesOrdersChange
	|FROM
	|	AccumulationRegister.SalesOrders AS SalesOrders");
	
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	QueryResult = Query.Execute();
	
	StructureTemporaryTables.Insert("RegisterRecordsSalesOrdersChange", False);
	
EndProcedure

#EndRegion

#EndIf