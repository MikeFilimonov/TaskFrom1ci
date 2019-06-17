#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

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
	|	WorkOrders.LineNumber AS LineNumber,
	|	WorkOrders.Company AS Company,
	|	WorkOrders.WorkOrder AS WorkOrder,
	|	WorkOrders.Products AS Products,
	|	WorkOrders.Characteristic AS Characteristic,
	|	WorkOrders.Quantity AS QuantityBeforeWrite,
	|	WorkOrders.Quantity AS QuantityChange,
	|	WorkOrders.Quantity AS QuantityOnWrite
	|INTO RegisterRecordsWorkOrdersChange
	|FROM
	|	AccumulationRegister.WorkOrders AS WorkOrders");
	
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	QueryResult = Query.Execute();
	
	StructureTemporaryTables.Insert("RegisterRecordsWorkOrdersChange", False);
	
EndProcedure

#EndRegion

#EndIf