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
	|	GoodsShippedNotInvoiced.LineNumber AS LineNumber,
	|	GoodsShippedNotInvoiced.Company AS Company,
	|	GoodsShippedNotInvoiced.GoodsIssue AS GoodsIssue,
	|	GoodsShippedNotInvoiced.Counterparty AS Counterparty,
	|	GoodsShippedNotInvoiced.Contract AS Contract,
	|	GoodsShippedNotInvoiced.Products AS Products,
	|	GoodsShippedNotInvoiced.Characteristic AS Characteristic,
	|	GoodsShippedNotInvoiced.Batch AS Batch,
	|	GoodsShippedNotInvoiced.SalesOrder AS SalesOrder,
	|	GoodsShippedNotInvoiced.Quantity AS QuantityBeforeWrite,
	|	GoodsShippedNotInvoiced.Quantity AS QuantityChange,
	|	GoodsShippedNotInvoiced.Quantity AS QuantityOnWrite
	|INTO RegisterRecordsGoodsShippedNotInvoicedChange
	|FROM
	|	AccumulationRegister.GoodsShippedNotInvoiced AS GoodsShippedNotInvoiced");
	
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	QueryResult = Query.Execute();
	
	StructureTemporaryTables.Insert("RegisterRecordsGoodsShippedNotInvoicedChange", False);
	
EndProcedure

#EndRegion

#EndIf