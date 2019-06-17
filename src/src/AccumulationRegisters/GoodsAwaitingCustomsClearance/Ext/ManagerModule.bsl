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
	|	GoodsAwaitingCustomsClearance.LineNumber AS LineNumber,
	|	GoodsAwaitingCustomsClearance.Company AS Company,
	|	GoodsAwaitingCustomsClearance.Counterparty AS Counterparty,
	|	GoodsAwaitingCustomsClearance.Contract AS Contract,
	|	GoodsAwaitingCustomsClearance.SupplierInvoice AS SupplierInvoice,
	|	GoodsAwaitingCustomsClearance.Products AS Products,
	|	GoodsAwaitingCustomsClearance.Characteristic AS Characteristic,
	|	GoodsAwaitingCustomsClearance.Batch AS Batch,
	|	GoodsAwaitingCustomsClearance.Quantity AS QuantityBeforeWrite,
	|	GoodsAwaitingCustomsClearance.Quantity AS QuantityChange,
	|	GoodsAwaitingCustomsClearance.Quantity AS QuantityOnWrite
	|INTO RegisterRecordsGoodsAwaitingCustomsClearanceChange
	|FROM
	|	AccumulationRegister.GoodsAwaitingCustomsClearance AS GoodsAwaitingCustomsClearance");
	
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	QueryResult = Query.Execute();
	
	StructureTemporaryTables.Insert("RegisterRecordsGoodsAwaitingCustomsClearanceChange", False);
	
EndProcedure

Function BalancesControlQueryText() Export
	
	Return
	"SELECT
	|	RegisterRecordsGoodsAwaitingCustomsClearanceChange.LineNumber AS LineNumber,
	|	RegisterRecordsGoodsAwaitingCustomsClearanceChange.Company AS Company,
	|	RegisterRecordsGoodsAwaitingCustomsClearanceChange.Counterparty AS Counterparty,
	|	RegisterRecordsGoodsAwaitingCustomsClearanceChange.Contract AS Contract,
	|	RegisterRecordsGoodsAwaitingCustomsClearanceChange.SupplierInvoice AS SupplierInvoice,
	|	RegisterRecordsGoodsAwaitingCustomsClearanceChange.Products AS Products,
	|	CatalogProducts.MeasurementUnit AS MeasurementUnit,
	|	RegisterRecordsGoodsAwaitingCustomsClearanceChange.Characteristic AS Characteristic,
	|	RegisterRecordsGoodsAwaitingCustomsClearanceChange.Batch AS Batch,
	|	RegisterRecordsGoodsAwaitingCustomsClearanceChange.QuantityChange + ISNULL(GoodsAwaitingCustomsClearanceBalances.QuantityBalance, 0) AS QuantityBalanceBeforeChange,
	|	ISNULL(GoodsAwaitingCustomsClearanceBalances.QuantityBalance, 0) AS QuantityBalance
	|FROM
	|	RegisterRecordsGoodsAwaitingCustomsClearanceChange AS RegisterRecordsGoodsAwaitingCustomsClearanceChange
	|		LEFT JOIN Catalog.Products AS CatalogProducts
	|		ON RegisterRecordsGoodsAwaitingCustomsClearanceChange.Products = CatalogProducts.Ref
	|		LEFT JOIN AccumulationRegister.GoodsAwaitingCustomsClearance.Balance(&ControlTime, ) AS GoodsAwaitingCustomsClearanceBalances
	|		ON RegisterRecordsGoodsAwaitingCustomsClearanceChange.Company = GoodsAwaitingCustomsClearanceBalances.Company
	|			AND RegisterRecordsGoodsAwaitingCustomsClearanceChange.Counterparty = GoodsAwaitingCustomsClearanceBalances.Counterparty
	|			AND RegisterRecordsGoodsAwaitingCustomsClearanceChange.Contract = GoodsAwaitingCustomsClearanceBalances.Contract
	|			AND RegisterRecordsGoodsAwaitingCustomsClearanceChange.SupplierInvoice = GoodsAwaitingCustomsClearanceBalances.SupplierInvoice
	|			AND RegisterRecordsGoodsAwaitingCustomsClearanceChange.Products = GoodsAwaitingCustomsClearanceBalances.Products
	|			AND RegisterRecordsGoodsAwaitingCustomsClearanceChange.Characteristic = GoodsAwaitingCustomsClearanceBalances.Characteristic
	|			AND RegisterRecordsGoodsAwaitingCustomsClearanceChange.Batch = GoodsAwaitingCustomsClearanceBalances.Batch
	|WHERE
	|	ISNULL(GoodsAwaitingCustomsClearanceBalances.QuantityBalance, 0) < 0
	|
	|ORDER BY
	|	LineNumber";
	
EndFunction

#EndRegion

#EndIf