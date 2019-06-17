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
	|	StockTransferredToThirdParties.LineNumber AS LineNumber,
	|	StockTransferredToThirdParties.Company AS Company,
	|	StockTransferredToThirdParties.Products AS Products,
	|	StockTransferredToThirdParties.Characteristic AS Characteristic,
	|	StockTransferredToThirdParties.Batch AS Batch,
	|	StockTransferredToThirdParties.Counterparty AS Counterparty,
	|	StockTransferredToThirdParties.Contract AS Contract,
	|	StockTransferredToThirdParties.Order AS Order,
	|	StockTransferredToThirdParties.Quantity AS QuantityBeforeWrite,
	|	StockTransferredToThirdParties.Quantity AS QuantityChange,
	|	StockTransferredToThirdParties.Quantity AS QuantityOnWrite
	|INTO RegisterRecordsStockTransferredToThirdPartiesChange
	|FROM
	|	AccumulationRegister.StockTransferredToThirdParties AS StockTransferredToThirdParties");
	
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	QueryResult = Query.Execute();
	
	StructureTemporaryTables.Insert("RegisterRecordsStockTransferredToThirdPartiesChange", False);
	
EndProcedure

#EndRegion

#EndIf