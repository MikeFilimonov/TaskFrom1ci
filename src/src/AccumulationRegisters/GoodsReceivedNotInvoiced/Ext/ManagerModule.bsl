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
	|	GoodsReceivedNotInvoiced.LineNumber AS LineNumber,
	|	GoodsReceivedNotInvoiced.Company AS Company,
	|	GoodsReceivedNotInvoiced.GoodsReceipt AS GoodsReceipt,
	|	GoodsReceivedNotInvoiced.Counterparty AS Counterparty,
	|	GoodsReceivedNotInvoiced.Contract AS Contract,
	|	GoodsReceivedNotInvoiced.Products AS Products,
	|	GoodsReceivedNotInvoiced.Characteristic AS Characteristic,
	|	GoodsReceivedNotInvoiced.Batch AS Batch,
	|	GoodsReceivedNotInvoiced.PurchaseOrder AS PurchaseOrder,
	|	GoodsReceivedNotInvoiced.Quantity AS QuantityBeforeWrite,
	|	GoodsReceivedNotInvoiced.Quantity AS QuantityChange,
	|	GoodsReceivedNotInvoiced.Quantity AS QuantityOnWrite
	|INTO RegisterRecordsGoodsReceivedNotInvoicedChange
	|FROM
	|	AccumulationRegister.GoodsReceivedNotInvoiced AS GoodsReceivedNotInvoiced");
	
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	QueryResult = Query.Execute();
	
	StructureTemporaryTables.Insert("RegisterRecordsGoodsReceivedNotInvoicedChange", False);
	
EndProcedure

#EndRegion

#EndIf