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
	|	StockReceivedFromThirdParties.LineNumber AS LineNumber,
	|	StockReceivedFromThirdParties.Company AS Company,
	|	StockReceivedFromThirdParties.Products AS Products,
	|	StockReceivedFromThirdParties.Characteristic AS Characteristic,
	|	StockReceivedFromThirdParties.Batch AS Batch,
	|	StockReceivedFromThirdParties.Counterparty AS Counterparty,
	|	StockReceivedFromThirdParties.Contract AS Contract,
	|	StockReceivedFromThirdParties.Order AS Order,
	|	StockReceivedFromThirdParties.Quantity AS QuantityBeforeWrite,
	|	StockReceivedFromThirdParties.Quantity AS QuantityChange,
	|	StockReceivedFromThirdParties.Quantity AS QuantityOnWrite
	|INTO RegisterRecordsStockReceivedFromThirdPartiesChange
	|FROM
	|	AccumulationRegister.StockReceivedFromThirdParties AS StockReceivedFromThirdParties");
	
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	QueryResult = Query.Execute();
	
	StructureTemporaryTables.Insert("RegisterRecordsStockReceivedFromThirdPartiesChange", False);
	
EndProcedure

#EndRegion

#EndIf