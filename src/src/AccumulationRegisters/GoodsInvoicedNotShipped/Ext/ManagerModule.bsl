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
	|	GoodsInvoicedNotShipped.LineNumber AS LineNumber,
	|	GoodsInvoicedNotShipped.Company AS Company,
	|	GoodsInvoicedNotShipped.SalesInvoice AS SalesInvoice,
	|	GoodsInvoicedNotShipped.Counterparty AS Counterparty,
	|	GoodsInvoicedNotShipped.Contract AS Contract,
	|	GoodsInvoicedNotShipped.Products AS Products,
	|	GoodsInvoicedNotShipped.Characteristic AS Characteristic,
	|	GoodsInvoicedNotShipped.Batch AS Batch,
	|	GoodsInvoicedNotShipped.VATRate AS VATRate,
	|	GoodsInvoicedNotShipped.Department AS Department,
	|	GoodsInvoicedNotShipped.Responsible AS Responsible,
	|	GoodsInvoicedNotShipped.SalesOrder AS SalesOrder,
	|	GoodsInvoicedNotShipped.Quantity AS QuantityBeforeWrite,
	|	GoodsInvoicedNotShipped.Quantity AS QuantityChange,
	|	GoodsInvoicedNotShipped.Quantity AS QuantityOnWrite
	|INTO RegisterRecordsGoodsInvoicedNotShippedChange
	|FROM
	|	AccumulationRegister.GoodsInvoicedNotShipped AS GoodsInvoicedNotShipped");
	
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	QueryResult = Query.Execute();
	
	StructureTemporaryTables.Insert("RegisterRecordsGoodsInvoicedNotShippedChange", False);
	
EndProcedure

Function BalancesControlQueryText() Export
	
	Return
	"SELECT
	|	RegisterRecordsGoodsInvoicedNotShippedChange.LineNumber AS LineNumber,
	|	RegisterRecordsGoodsInvoicedNotShippedChange.SalesInvoice AS SalesInvoice,
	|	RegisterRecordsGoodsInvoicedNotShippedChange.Company AS Company,
	|	RegisterRecordsGoodsInvoicedNotShippedChange.Counterparty AS Counterparty,
	|	RegisterRecordsGoodsInvoicedNotShippedChange.Contract AS Contract,
	|	RegisterRecordsGoodsInvoicedNotShippedChange.SalesOrder AS SalesOrder,
	|	RegisterRecordsGoodsInvoicedNotShippedChange.Products AS Products,
	|	CatalogProducts.MeasurementUnit AS MeasurementUnit,
	|	RegisterRecordsGoodsInvoicedNotShippedChange.Characteristic AS Characteristic,
	|	RegisterRecordsGoodsInvoicedNotShippedChange.Batch AS Batch,
	|	RegisterRecordsGoodsInvoicedNotShippedChange.VATRate AS VATRate,
	|	RegisterRecordsGoodsInvoicedNotShippedChange.Department AS Department,
	|	RegisterRecordsGoodsInvoicedNotShippedChange.Responsible AS Responsible,
	|	RegisterRecordsGoodsInvoicedNotShippedChange.QuantityChange + ISNULL(GoodsInvoicedNotShippedBalances.QuantityBalance, 0) AS QuantityBalanceBeforeChange,
	|	ISNULL(GoodsInvoicedNotShippedBalances.QuantityBalance, 0) AS QuantityBalance
	|FROM
	|	RegisterRecordsGoodsInvoicedNotShippedChange AS RegisterRecordsGoodsInvoicedNotShippedChange
	|		LEFT JOIN Catalog.Products AS CatalogProducts
	|		ON RegisterRecordsGoodsInvoicedNotShippedChange.Products = CatalogProducts.Ref
	|		LEFT JOIN AccumulationRegister.GoodsInvoicedNotShipped.Balance(&ControlTime, ) AS GoodsInvoicedNotShippedBalances
	|		ON RegisterRecordsGoodsInvoicedNotShippedChange.SalesInvoice = GoodsInvoicedNotShippedBalances.SalesInvoice
	|			AND RegisterRecordsGoodsInvoicedNotShippedChange.Company = GoodsInvoicedNotShippedBalances.Company
	|			AND RegisterRecordsGoodsInvoicedNotShippedChange.Counterparty = GoodsInvoicedNotShippedBalances.Counterparty
	|			AND RegisterRecordsGoodsInvoicedNotShippedChange.Contract = GoodsInvoicedNotShippedBalances.Contract
	|			AND RegisterRecordsGoodsInvoicedNotShippedChange.SalesOrder = GoodsInvoicedNotShippedBalances.SalesOrder
	|			AND RegisterRecordsGoodsInvoicedNotShippedChange.Products = GoodsInvoicedNotShippedBalances.Products
	|			AND RegisterRecordsGoodsInvoicedNotShippedChange.Characteristic = GoodsInvoicedNotShippedBalances.Characteristic
	|			AND RegisterRecordsGoodsInvoicedNotShippedChange.Batch = GoodsInvoicedNotShippedBalances.Batch
	|			AND RegisterRecordsGoodsInvoicedNotShippedChange.VATRate = GoodsInvoicedNotShippedBalances.VATRate
	|			AND RegisterRecordsGoodsInvoicedNotShippedChange.Department = GoodsInvoicedNotShippedBalances.Department
	|			AND RegisterRecordsGoodsInvoicedNotShippedChange.Responsible = GoodsInvoicedNotShippedBalances.Responsible
	|WHERE
	|	ISNULL(GoodsInvoicedNotShippedBalances.QuantityBalance, 0) < 0
	|
	|ORDER BY
	|	LineNumber";
	
EndFunction

#EndRegion

#EndIf