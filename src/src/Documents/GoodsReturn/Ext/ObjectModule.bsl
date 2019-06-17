#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

Procedure CheckReturnedQuantity(Cancel)
	
	If ValueIsFilled(SalesDocument) And CommonUse.ObjectAttributeValue(SalesDocument, "Date") > Date
		Or ValueIsFilled(SupplierInvoice) And CommonUse.ObjectAttributeValue(SupplierInvoice, "Date") > Date Then
		MessageToUser = NStr("en = 'The date of the Goods return should be more than in initial Invoice.'");
		CommonUseClientServer.MessageToUser(MessageToUser,,,,Cancel);
	EndIf;
	
	Query = New Query;
	Query.SetParameter("Ref", Ref);
	
	If OperationKind = Enums.OperationTypesGoodsReturn.FromCustomer Then
		Query.Text = 
		"SELECT
		|	GoodsReturnInventory.Products AS Products,
		|	GoodsReturnInventory.Characteristic AS Characteristic,
		|	GoodsReturnInventory.Batch AS Batch,
		|	SUM(GoodsReturnInventory.Quantity) AS ReturnQuantity,
		|	GoodsReturnInventory.MeasurementUnit AS MeasurementUnit
		|INTO GoodsReturnInventory
		|FROM
		|	Document.GoodsReturn.Inventory AS GoodsReturnInventory
		|WHERE
		|	GoodsReturnInventory.Ref = &Ref
		|
		|GROUP BY
		|	GoodsReturnInventory.Characteristic,
		|	GoodsReturnInventory.Batch,
		|	GoodsReturnInventory.Products,
		|	GoodsReturnInventory.Ref,
		|	GoodsReturnInventory.MeasurementUnit
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	GoodsReturnInventory.Products AS Products,
		|	GoodsReturnInventory.Characteristic AS Characteristic,
		|	GoodsReturnInventory.Batch AS Batch,
		|	SUM(GoodsReturnInventory.Quantity) AS ReturnQuantity,
		|	GoodsReturnInventory.MeasurementUnit AS MeasurementUnit
		|INTO GoodsReturnFromCustomer
		|FROM
		|	Document.GoodsReturn.Inventory AS GoodsReturnInventory
		|WHERE
		|	GoodsReturnInventory.Ref.SalesDocument = &SalesDocument
		|	AND GoodsReturnInventory.Ref.Posted
		|	AND GoodsReturnInventory.Quantity > 0
		|	AND GoodsReturnInventory.Ref <> &Ref
		|
		|GROUP BY
		|	GoodsReturnInventory.Characteristic,
		|	GoodsReturnInventory.Batch,
		|	GoodsReturnInventory.Products,
		|	GoodsReturnInventory.Ref,
		|	GoodsReturnInventory.MeasurementUnit
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	SalesInvoiceInventory.Products AS Products,
		|	SalesInvoiceInventory.Characteristic AS Characteristic,
		|	SalesInvoiceInventory.Batch AS Batch,
		|	SUM(SalesInvoiceInventory.Quantity) AS Quantity,
		|	SalesInvoiceInventory.MeasurementUnit AS MeasurementUnit
		|INTO SalesDocumentInventory
		|FROM
		|	Document.SalesInvoice.Inventory AS SalesInvoiceInventory
		|WHERE
		|	SalesInvoiceInventory.Ref = &SalesDocument
		|
		|GROUP BY
		|	SalesInvoiceInventory.Products,
		|	SalesInvoiceInventory.Characteristic,
		|	SalesInvoiceInventory.Batch,
		|	SalesInvoiceInventory.MeasurementUnit
		|
		|UNION ALL
		|
		|SELECT
		|	SalesSlipInventory.Products,
		|	SalesSlipInventory.Characteristic,
		|	SalesSlipInventory.Batch,
		|	SUM(SalesSlipInventory.Quantity),
		|	SalesSlipInventory.MeasurementUnit
		|FROM
		|	Document.SalesSlip.Inventory AS SalesSlipInventory
		|WHERE
		|	SalesSlipInventory.Ref = &SalesDocument
		|
		|GROUP BY
		|	SalesSlipInventory.Products,
		|	SalesSlipInventory.Characteristic,
		|	SalesSlipInventory.Batch,
		|	SalesSlipInventory.MeasurementUnit
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	SalesDocumentInventory.Products AS Products,
		|	SalesDocumentInventory.Characteristic AS Characteristic,
		|	SalesDocumentInventory.Batch AS Batch,
		|	SalesDocumentInventory.Quantity AS Quantity,
		|	SalesDocumentInventory.MeasurementUnit AS MeasurementUnit,
		|	SalesDocumentInventory.Quantity AS InitialQuantity,
		|	0 AS ReturnedQuantity
		|INTO UnionResult
		|FROM
		|	SalesDocumentInventory AS SalesDocumentInventory
		|
		|UNION ALL
		|
		|SELECT
		|	GoodsReturnFromCustomer.Products,
		|	GoodsReturnFromCustomer.Characteristic,
		|	GoodsReturnFromCustomer.Batch,
		|	-GoodsReturnFromCustomer.ReturnQuantity,
		|	GoodsReturnFromCustomer.MeasurementUnit,
		|	0,
		|	GoodsReturnFromCustomer.ReturnQuantity
		|FROM
		|	GoodsReturnFromCustomer AS GoodsReturnFromCustomer
		|
		|UNION ALL
		|
		|SELECT
		|	GoodsReturnInventory.Products,
		|	GoodsReturnInventory.Characteristic,
		|	GoodsReturnInventory.Batch,
		|	-GoodsReturnInventory.ReturnQuantity,
		|	GoodsReturnInventory.MeasurementUnit,
		|	0,
		|	0
		|FROM
		|	GoodsReturnInventory AS GoodsReturnInventory
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	UnionResult.Products.Presentation AS Products,
		|	UnionResult.Characteristic.Presentation AS Characteristic,
		|	UnionResult.Batch.Presentation AS Batch,
		|	SUM(UnionResult.Quantity) AS Quantity,
		|	SUM(UnionResult.InitialQuantity - UnionResult.ReturnedQuantity) AS AvailableQuantity,
		|	SUM(UnionResult.ReturnedQuantity) AS ReturnedQuantity,
		|	UnionResult.MeasurementUnit AS MeasurementUnit
		|INTO GroupedResult
		|FROM
		|	UnionResult AS UnionResult
		|
		|GROUP BY
		|	UnionResult.Products.Presentation,
		|	UnionResult.Characteristic.Presentation,
		|	UnionResult.Batch.Presentation,
		|	UnionResult.MeasurementUnit
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	GroupedResult.Products AS Products,
		|	GroupedResult.Characteristic AS Characteristic,
		|	GroupedResult.Batch AS Batch,
		|	GroupedResult.Quantity AS Quantity,
		|	GroupedResult.AvailableQuantity AS AvailableQuantity,
		|	GroupedResult.ReturnedQuantity AS ReturnedQuantity,
		|	GroupedResult.MeasurementUnit AS MeasurementUnit
		|FROM
		|	GroupedResult AS GroupedResult
		|WHERE
		|	GroupedResult.Quantity < 0";
		
		Query.SetParameter("SalesDocument",	SalesDocument);
		
	ElsIf OperationKind = Enums.OperationTypesGoodsReturn.ToSupplier Then
		Query.Text = 
		"SELECT
		|	GoodsReturnInventory.Products AS Products,
		|	GoodsReturnInventory.Characteristic AS Characteristic,
		|	GoodsReturnInventory.Batch AS Batch,
		|	SUM(GoodsReturnInventory.Quantity) AS ReturnQuantity,
		|	GoodsReturnInventory.MeasurementUnit AS MeasurementUnit
		|INTO GoodsReturnInventory
		|FROM
		|	Document.GoodsReturn.Inventory AS GoodsReturnInventory
		|WHERE
		|	GoodsReturnInventory.Ref = &Ref
		|
		|GROUP BY
		|	GoodsReturnInventory.Characteristic,
		|	GoodsReturnInventory.Batch,
		|	GoodsReturnInventory.Products,
		|	GoodsReturnInventory.Ref,
		|	GoodsReturnInventory.MeasurementUnit
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	GoodsReturnInventory.Products AS Products,
		|	GoodsReturnInventory.Characteristic AS Characteristic,
		|	GoodsReturnInventory.Batch AS Batch,
		|	SUM(GoodsReturnInventory.Quantity) AS ReturnQuantity,
		|	GoodsReturnInventory.MeasurementUnit AS MeasurementUnit
		|INTO GoodsReturnToSupplier
		|FROM
		|	Document.GoodsReturn.Inventory AS GoodsReturnInventory
		|WHERE
		|	GoodsReturnInventory.Ref.SupplierInvoice = &SupplierInvoice
		|	AND GoodsReturnInventory.Ref.Posted
		|	AND GoodsReturnInventory.Quantity > 0
		|	AND GoodsReturnInventory.Ref <> &Ref
		|
		|GROUP BY
		|	GoodsReturnInventory.Characteristic,
		|	GoodsReturnInventory.Batch,
		|	GoodsReturnInventory.Products,
		|	GoodsReturnInventory.Ref,
		|	GoodsReturnInventory.MeasurementUnit
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	SupplierInvoiceInventory.Products AS Products,
		|	SupplierInvoiceInventory.Characteristic AS Characteristic,
		|	SupplierInvoiceInventory.Batch AS Batch,
		|	SUM(SupplierInvoiceInventory.Quantity) AS Quantity,
		|	SupplierInvoiceInventory.MeasurementUnit AS MeasurementUnit
		|INTO SupplierInvoiceInventory
		|FROM
		|	Document.SupplierInvoice.Inventory AS SupplierInvoiceInventory
		|WHERE
		|	SupplierInvoiceInventory.Ref = &SupplierInvoice
		|
		|GROUP BY
		|	SupplierInvoiceInventory.Products,
		|	SupplierInvoiceInventory.Characteristic,
		|	SupplierInvoiceInventory.Batch,
		|	SupplierInvoiceInventory.MeasurementUnit
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	SupplierInvoiceInventory.Products AS Products,
		|	SupplierInvoiceInventory.Characteristic AS Characteristic,
		|	SupplierInvoiceInventory.Batch AS Batch,
		|	SupplierInvoiceInventory.Quantity AS Quantity,
		|	SupplierInvoiceInventory.MeasurementUnit AS MeasurementUnit,
		|	SupplierInvoiceInventory.Quantity AS InitialQuantity,
		|	0 AS ReturnedQuantity
		|INTO UnionResult
		|FROM
		|	SupplierInvoiceInventory AS SupplierInvoiceInventory
		|
		|UNION ALL
		|
		|SELECT
		|	GoodsReturnToSupplier.Products,
		|	GoodsReturnToSupplier.Characteristic,
		|	GoodsReturnToSupplier.Batch,
		|	-GoodsReturnToSupplier.ReturnQuantity,
		|	GoodsReturnToSupplier.MeasurementUnit,
		|	0,
		|	GoodsReturnToSupplier.ReturnQuantity
		|FROM
		|	GoodsReturnToSupplier AS GoodsReturnToSupplier
		|
		|UNION ALL
		|
		|SELECT
		|	GoodsReturnInventory.Products,
		|	GoodsReturnInventory.Characteristic,
		|	GoodsReturnInventory.Batch,
		|	-GoodsReturnInventory.ReturnQuantity,
		|	GoodsReturnInventory.MeasurementUnit,
		|	0,
		|	0
		|FROM
		|	GoodsReturnInventory AS GoodsReturnInventory
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	UnionResult.Products.Presentation AS Products,
		|	UnionResult.Characteristic.Presentation AS Characteristic,
		|	UnionResult.Batch.Presentation AS Batch,
		|	SUM(UnionResult.Quantity) AS Quantity,
		|	SUM(UnionResult.InitialQuantity - UnionResult.ReturnedQuantity) AS AvailableQuantity,
		|	SUM(UnionResult.ReturnedQuantity) AS ReturnedQuantity,
		|	UnionResult.MeasurementUnit AS MeasurementUnit
		|INTO GroupedResult
		|FROM
		|	UnionResult AS UnionResult
		|
		|GROUP BY
		|	UnionResult.Products.Presentation,
		|	UnionResult.Characteristic.Presentation,
		|	UnionResult.Batch.Presentation,
		|	UnionResult.MeasurementUnit
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	GroupedResult.Products AS Products,
		|	GroupedResult.Characteristic AS Characteristic,
		|	GroupedResult.Batch AS Batch,
		|	GroupedResult.Quantity AS Quantity,
		|	GroupedResult.AvailableQuantity AS AvailableQuantity,
		|	GroupedResult.ReturnedQuantity AS ReturnedQuantity,
		|	GroupedResult.MeasurementUnit AS MeasurementUnit
		|FROM
		|	GroupedResult AS GroupedResult
		|WHERE
		|	GroupedResult.Quantity < 0";
		
		Query.SetParameter("SupplierInvoice", SupplierInvoice);
		
	EndIf;
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	
	While Selection.Next() Do
		If Selection.ReturnedQuantity > 0 Then
			MessageToUser = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = '%1 %2 of %3 was previously returned by other Goods return documents.
				     |You have only %4 %2 left to return. See subordinate structure of initial Invoice for details.'"),
				Selection.ReturnedQuantity, 
				Selection.MeasurementUnit,
				Selection.Products + ?(ValueIsFilled(Selection.Characteristic), ", " + Selection.Characteristic, "")
				 + ?(ValueIsFilled(Selection.Batch), ", " + Selection.Batch, ""),
				Selection.AvailableQuantity,);
		Else
			MessageToUser = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'There is more quantity of returned goods ""%1"" than in initial Invoice.'"),
				Selection.Products + ?(ValueIsFilled(Selection.Characteristic), ", " + Selection.Characteristic, "")
				 + ?(ValueIsFilled(Selection.Batch), ", " + Selection.Batch, ""));
		EndIf;
			
		CommonUseClientServer.MessageToUser(MessageToUser,,,,Cancel);
	EndDo;
	
EndProcedure
	
Procedure FillByCreditNote(FillingData) Export
	
	CreditNote = FillingData.Ref;
	If TypeOf(CreditNote.BasisDocument) = Type("DocumentRef.SalesInvoice") 
		OR TypeOf(CreditNote.BasisDocument) = Type("DocumentRef.SalesSlip") Then
		SalesDocument = CreditNote.BasisDocument;
	EndIf;
	
	If FillingData.BasisDocument <> Undefined Then
		StructuralUnit = FillingData.BasisDocument.StructuralUnit;
	EndIf;
	
	FillPropertyValues(ThisObject, FillingData,, "Number, Date");
	
	OperationKind	= Enums.OperationTypesGoodsReturn.FromCustomer;
	
	FillProducts(FillingData);

EndProcedure
	
Procedure FillBySalesInvoice(FillingData) Export
	
	SalesDocument = FillingData.Ref;

	FillPropertyValues(ThisObject, FillingData,, "Number, Date");
	
	OperationKind	= Enums.OperationTypesGoodsReturn.FromCustomer;
	DocumentAmount	= 0;
	
	FillProducts(FillingData);

EndProcedure

Procedure FillByDebitNote(FillingData) Export
	
	DebitNote = FillingData.Ref;
	If TypeOf(DebitNote.BasisDocument) = Type("DocumentRef.SupplierInvoice") Then
		SupplierInvoice	= DebitNote.BasisDocument;
	EndIf;
	
	If FillingData.BasisDocument <> Undefined Then
		StructuralUnit = CommonUse.ObjectAttributeValue(FillingData.BasisDocument, "StructuralUnit");
	EndIf;
	
	FillPropertyValues(ThisObject, FillingData,, "Number, Date");
	
	OperationKind = Enums.OperationTypesGoodsReturn.ToSupplier;
	
	FillProducts(FillingData);

EndProcedure

Procedure FillBySupplierInvoice(FillingData) Export
	
	SupplierInvoice = FillingData.Ref;

	FillPropertyValues(ThisObject, FillingData,, "Number, Date");
	
	OperationKind	= Enums.OperationTypesGoodsReturn.ToSupplier;
	DocumentAmount	= 0;
	
	FillProducts(FillingData);

EndProcedure

Procedure FillProducts(BasisDocument) Export
	
	If BasisDocument = Undefined Then 
		Return;
	EndIf;
	
	Query = New Query;
	Query.TempTablesManager = New TempTablesManager;	
	Query.SetParameter("BasisDocument", BasisDocument);
	Query.SetParameter("Ref", 			Ref);
	
	If OperationKind = Enums.OperationTypesGoodsReturn.FromCustomer Then
		Query.Text = 
		"SELECT
		|	GoodsReturnInventory.Batch AS Batch,
		|	GoodsReturnInventory.Characteristic AS Characteristic,
		|	GoodsReturnInventory.Products AS Products,
		|	SUM(GoodsReturnInventory.Quantity) AS Quantity,
		|	GoodsReturnInventory.SerialNumbers AS SerialNumbers,
		|	GoodsReturnInventory.ConnectionKey AS ConnectionKey,
		|	GoodsReturnInventory.Price AS Price,
		|	GoodsReturnInventory.MeasurementUnit AS MeasurementUnit,
		|	GoodsReturnInventory.VATRate AS VATRate,
		|	GoodsReturnInventory.Order AS Order,
		|	GoodsReturnInventory.SalesRep AS SalesRep
		|INTO GoodsReturnFromCustomer
		|FROM
		|	Document.GoodsReturn.Inventory AS GoodsReturnInventory
		|WHERE
		|	GoodsReturnInventory.Ref.SalesDocument = &SalesDocument
		|	AND GoodsReturnInventory.Ref.Posted
		|	AND GoodsReturnInventory.Quantity > 0
		|	AND GoodsReturnInventory.Ref <> &Ref
		|
		|GROUP BY
		|	GoodsReturnInventory.SerialNumbers,
		|	GoodsReturnInventory.Order,
		|	GoodsReturnInventory.MeasurementUnit,
		|	GoodsReturnInventory.Characteristic,
		|	GoodsReturnInventory.Batch,
		|	GoodsReturnInventory.VATRate,
		|	GoodsReturnInventory.Products,
		|	GoodsReturnInventory.ConnectionKey,
		|	GoodsReturnInventory.Price,
		|	GoodsReturnInventory.SalesRep
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	Inventory.InitialPrice AS Price,
		|	Inventory.MeasurementUnit AS MeasurementUnit,
		|	Inventory.Products AS Products,
		|	Inventory.Characteristic AS Characteristic,
		|	Inventory.Batch AS Batch,
		|	Inventory.InitialQuantity AS InitialQuantity,
		|	Inventory.InitialAmount AS InitialAmount,
		|	Inventory.Quantity AS Quantity,
		|	Inventory.VATRate AS VATRate,
		|	Inventory.Amount AS Amount,
		|	Inventory.VATAmount AS VATAmount,
		|	Inventory.CostOfGoodsSold AS CostOfGoodsSold,
		|	Inventory.SerialNumbers AS SerialNumbers,
		|	Inventory.ConnectionKey AS ConnectionKey,
		|	Inventory.Order AS Order,
		|	Inventory.SalesRep AS SalesRep
		|INTO BasisInventory
		|FROM
		|	Document.CreditNote.Inventory AS Inventory
		|WHERE
		|	Inventory.Ref = &BasisDocument
		|	AND Inventory.Products.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
		|	AND Inventory.Quantity > 0
		|
		|UNION ALL
		|
		|SELECT
		|	SalesInvoiceInventory.Price,
		|	SalesInvoiceInventory.MeasurementUnit,
		|	SalesInvoiceInventory.Products,
		|	SalesInvoiceInventory.Characteristic,
		|	SalesInvoiceInventory.Batch,
		|	SalesInvoiceInventory.Quantity,
		|	SalesInvoiceInventory.Amount,
		|	0,
		|	SalesInvoiceInventory.VATRate,
		|	0,
		|	0,
		|	0,
		|	SalesInvoiceInventory.SerialNumbers,
		|	SalesInvoiceInventory.ConnectionKey,
		|	SalesInvoiceInventory.Order,
		|	SalesInvoiceInventory.SalesRep AS SalesRep
		|FROM
		|	Document.SalesInvoice.Inventory AS SalesInvoiceInventory
		|WHERE
		|	SalesInvoiceInventory.Ref = &BasisDocument
		|	AND SalesInvoiceInventory.Products.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	BasisInventory.Price AS Price,
		|	BasisInventory.MeasurementUnit AS MeasurementUnit,
		|	BasisInventory.Products AS Products,
		|	BasisInventory.Characteristic AS Characteristic,
		|	BasisInventory.Batch AS Batch,
		|	SUM(BasisInventory.InitialQuantity) AS InitialQuantity,
		|	SUM(BasisInventory.InitialAmount) AS InitialAmount,
		|	SUM(BasisInventory.Quantity) AS Quantity,
		|	BasisInventory.VATRate AS VATRate,
		|	SUM(BasisInventory.Amount) AS Amount,
		|	SUM(BasisInventory.VATAmount) AS VATAmount,
		|	SUM(BasisInventory.CostOfGoodsSold) AS CostOfGoodsSold,
		|	BasisInventory.SerialNumbers AS SerialNumbers,
		|	BasisInventory.ConnectionKey AS ConnectionKey,
		|	BasisInventory.Order AS Order,
		|	BasisInventory.SalesRep AS SalesRep
		|INTO GroupedBasis
		|FROM
		|	BasisInventory AS BasisInventory
		|
		|GROUP BY
		|	BasisInventory.Characteristic,
		|	BasisInventory.MeasurementUnit,
		|	BasisInventory.Products,
		|	BasisInventory.Batch,
		|	BasisInventory.VATRate,
		|	BasisInventory.SerialNumbers,
		|	BasisInventory.ConnectionKey,
		|	BasisInventory.Price,
		|	BasisInventory.Order,
		|	BasisInventory.SalesRep
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	GroupedBasis.Amount AS Amount,
		|	GroupedBasis.Batch AS Batch,
		|	GroupedBasis.Characteristic AS Characteristic,
		|	GroupedBasis.CostOfGoodsSold AS CostOfGoodsSold,
		|	GroupedBasis.InitialAmount AS InitialAmount,
		|	GroupedBasis.MeasurementUnit AS MeasurementUnit,
		|	GroupedBasis.InitialQuantity AS InitialQuantity,
		|	GroupedBasis.Price AS Price,
		|	GroupedBasis.Products AS Products,
		|	GroupedBasis.Quantity AS Quantity,
		|	GroupedBasis.VATAmount AS VATAmount,
		|	GroupedBasis.VATRate AS VATRate,
		|	GroupedBasis.InitialQuantity - ISNULL(GoodsReturnFromCustomer.Quantity, 0) AS QuantityBalance,
		|	GroupedBasis.SerialNumbers AS SerialNumbers,
		|	GroupedBasis.ConnectionKey AS ConnectionKey,
		|	GroupedBasis.Order AS Order,
		|	GroupedBasis.SalesRep AS SalesRep
		|INTO Balances
		|FROM
		|	GroupedBasis AS GroupedBasis
		|		LEFT JOIN GoodsReturnFromCustomer AS GoodsReturnFromCustomer
		|		ON GroupedBasis.Products = GoodsReturnFromCustomer.Products
		|			AND GroupedBasis.Characteristic = GoodsReturnFromCustomer.Characteristic
		|			AND GroupedBasis.Batch = GoodsReturnFromCustomer.Batch
		|			AND GroupedBasis.SerialNumbers = GoodsReturnFromCustomer.SerialNumbers
		|			AND GroupedBasis.VATRate = GoodsReturnFromCustomer.VATRate
		|			AND GroupedBasis.ConnectionKey = GoodsReturnFromCustomer.ConnectionKey
		|			AND GroupedBasis.Price = GoodsReturnFromCustomer.Price
		|			AND GroupedBasis.MeasurementUnit = GoodsReturnFromCustomer.MeasurementUnit
		|			AND GroupedBasis.Order = GoodsReturnFromCustomer.Order
		|			AND GroupedBasis.SalesRep = GoodsReturnFromCustomer.SalesRep
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	Balances.Amount AS Amount,
		|	Balances.Batch AS Batch,
		|	Balances.Characteristic AS Characteristic,
		|	Balances.CostOfGoodsSold AS CostOfGoodsSold,
		|	Balances.InitialAmount AS InitialAmount,
		|	Balances.MeasurementUnit AS MeasurementUnit,
		|	Balances.InitialQuantity AS InitialQuantity,
		|	Balances.Price AS Price,
		|	Balances.Products AS Products,
		|	Balances.Quantity AS Quantity,
		|	Balances.VATAmount AS VATAmount,
		|	Balances.VATRate AS VATRate,
		|	Balances.QuantityBalance AS QuantityBalance,
		|	Balances.SerialNumbers AS SerialNumbers,
		|	Balances.ConnectionKey AS ConnectionKey,
		|	Balances.Order AS Order,
		|	Balances.SalesRep AS SalesRep
		|FROM
		|	Balances AS Balances
		|WHERE
		|	Balances.QuantityBalance > 0";
		
		Query.SetParameter("SalesDocument", SalesDocument);
		
	ElsIf OperationKind = Enums.OperationTypesGoodsReturn.ToSupplier Then
		Query.Text = 
		"SELECT
		|	GoodsReturnInventory.Batch AS Batch,
		|	GoodsReturnInventory.Characteristic AS Characteristic,
		|	GoodsReturnInventory.Products AS Products,
		|	SUM(GoodsReturnInventory.Quantity) AS Quantity,
		|	GoodsReturnInventory.SerialNumbers AS SerialNumbers,
		|	GoodsReturnInventory.ConnectionKey AS ConnectionKey,
		|	GoodsReturnInventory.MeasurementUnit AS MeasurementUnit,
		|	GoodsReturnInventory.Price AS Price,
		|	GoodsReturnInventory.VATRate AS VATRate,
		|	GoodsReturnInventory.Order AS Order
		|INTO GoodsReturnToSupplier
		|FROM
		|	Document.GoodsReturn.Inventory AS GoodsReturnInventory
		|WHERE
		|	GoodsReturnInventory.Ref.SupplierInvoice = &SupplierInvoice
		|	AND GoodsReturnInventory.Ref.Posted
		|	AND GoodsReturnInventory.Quantity > 0
		|	AND GoodsReturnInventory.Ref <> &Ref
		|
		|GROUP BY
		|	GoodsReturnInventory.Batch,
		|	GoodsReturnInventory.Characteristic,
		|	GoodsReturnInventory.Products,
		|	GoodsReturnInventory.SerialNumbers,
		|	GoodsReturnInventory.ConnectionKey,
		|	GoodsReturnInventory.MeasurementUnit,
		|	GoodsReturnInventory.Price,
		|	GoodsReturnInventory.VATRate,
		|	GoodsReturnInventory.Order
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	DebitNoteInventory.InitialPrice AS Price,
		|	DebitNoteInventory.MeasurementUnit AS MeasurementUnit,
		|	DebitNoteInventory.Products AS Products,
		|	DebitNoteInventory.Characteristic AS Characteristic,
		|	DebitNoteInventory.Batch AS Batch,
		|	DebitNoteInventory.InitialQuantity AS InitialQuantity,
		|	DebitNoteInventory.InitialAmount AS InitialAmount,
		|	DebitNoteInventory.Quantity AS Quantity,
		|	DebitNoteInventory.VATRate AS VATRate,
		|	DebitNoteInventory.Amount AS Amount,
		|	DebitNoteInventory.VATAmount AS VATAmount,
		|	0 AS CostOfGoodsSold,
		|	DebitNoteInventory.SerialNumbers AS SerialNumbers,
		|	DebitNoteInventory.ConnectionKey AS ConnectionKey,
		|	DebitNoteInventory.Order AS Order
		|INTO BasisInventory
		|FROM
		|	Document.DebitNote.Inventory AS DebitNoteInventory
		|WHERE
		|	DebitNoteInventory.Ref = &BasisDocument
		|	AND DebitNoteInventory.Products.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
		|	AND DebitNoteInventory.Quantity > 0
		|
		|UNION ALL
		|
		|SELECT
		|	SupplierInvoiceInventory.Price,
		|	SupplierInvoiceInventory.MeasurementUnit,
		|	SupplierInvoiceInventory.Products,
		|	SupplierInvoiceInventory.Characteristic,
		|	SupplierInvoiceInventory.Batch,
		|	SupplierInvoiceInventory.Quantity,
		|	SupplierInvoiceInventory.Amount + SupplierInvoiceInventory.AmountExpense,
		|	0,
		|	SupplierInvoiceInventory.VATRate,
		|	0,
		|	0,
		|	0,
		|	SupplierInvoiceInventory.SerialNumbers,
		|	SupplierInvoiceInventory.ConnectionKey,
		|	SupplierInvoiceInventory.Order
		|FROM
		|	Document.SupplierInvoice.Inventory AS SupplierInvoiceInventory
		|WHERE
		|	SupplierInvoiceInventory.Ref = &BasisDocument
		|	AND SupplierInvoiceInventory.Products.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	BasisInventory.Price AS Price,
		|	BasisInventory.MeasurementUnit AS MeasurementUnit,
		|	BasisInventory.Products AS Products,
		|	BasisInventory.Characteristic AS Characteristic,
		|	BasisInventory.Batch AS Batch,
		|	SUM(BasisInventory.InitialQuantity) AS InitialQuantity,
		|	SUM(BasisInventory.InitialAmount) AS InitialAmount,
		|	SUM(BasisInventory.Quantity) AS Quantity,
		|	BasisInventory.VATRate AS VATRate,
		|	SUM(BasisInventory.Amount) AS Amount,
		|	SUM(BasisInventory.VATAmount) AS VATAmount,
		|	SUM(BasisInventory.CostOfGoodsSold) AS CostOfGoodsSold,
		|	BasisInventory.SerialNumbers AS SerialNumbers,
		|	BasisInventory.ConnectionKey AS ConnectionKey,
		|	BasisInventory.Order AS Order
		|INTO GroupedBasisInventory
		|FROM
		|	BasisInventory AS BasisInventory
		|
		|GROUP BY
		|	BasisInventory.Batch,
		|	BasisInventory.MeasurementUnit,
		|	BasisInventory.Products,
		|	BasisInventory.Characteristic,
		|	BasisInventory.VATRate,
		|	BasisInventory.SerialNumbers,
		|	BasisInventory.ConnectionKey,
		|	BasisInventory.Price,
		|	BasisInventory.Order
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	GroupedBasisInventory.Amount AS Amount,
		|	GroupedBasisInventory.Batch AS Batch,
		|	GroupedBasisInventory.Characteristic AS Characteristic,
		|	GroupedBasisInventory.CostOfGoodsSold AS CostOfGoodsSold,
		|	GroupedBasisInventory.InitialAmount AS InitialAmount,
		|	GroupedBasisInventory.MeasurementUnit AS MeasurementUnit,
		|	GroupedBasisInventory.InitialQuantity AS InitialQuantity,
		|	GroupedBasisInventory.Price AS Price,
		|	GroupedBasisInventory.Products AS Products,
		|	GroupedBasisInventory.Quantity AS Quantity,
		|	GroupedBasisInventory.VATAmount AS VATAmount,
		|	GroupedBasisInventory.VATRate AS VATRate,
		|	GroupedBasisInventory.InitialQuantity - ISNULL(GoodsReturnToSupplier.Quantity, 0) AS QuantityBalance,
		|	GroupedBasisInventory.SerialNumbers AS SerialNumbers,
		|	GroupedBasisInventory.ConnectionKey AS ConnectionKey,
		|	GroupedBasisInventory.Order AS Order
		|INTO Balances
		|FROM
		|	GroupedBasisInventory AS GroupedBasisInventory
		|		LEFT JOIN GoodsReturnToSupplier AS GoodsReturnToSupplier
		|		ON GroupedBasisInventory.Products = GoodsReturnToSupplier.Products
		|			AND GroupedBasisInventory.Characteristic = GoodsReturnToSupplier.Characteristic
		|			AND GroupedBasisInventory.Batch = GoodsReturnToSupplier.Batch
		|			AND GroupedBasisInventory.SerialNumbers = GoodsReturnToSupplier.SerialNumbers
		|			AND GroupedBasisInventory.ConnectionKey = GoodsReturnToSupplier.ConnectionKey
		|			AND GroupedBasisInventory.MeasurementUnit = GoodsReturnToSupplier.MeasurementUnit
		|			AND GroupedBasisInventory.Price = GoodsReturnToSupplier.Price
		|			AND GroupedBasisInventory.VATRate = GoodsReturnToSupplier.VATRate
		|			AND GroupedBasisInventory.Order = GoodsReturnToSupplier.Order
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	Balances.Amount AS Amount,
		|	Balances.Batch AS Batch,
		|	Balances.Characteristic AS Characteristic,
		|	Balances.CostOfGoodsSold AS CostOfGoodsSold,
		|	Balances.InitialAmount AS InitialAmount,
		|	Balances.MeasurementUnit AS MeasurementUnit,
		|	Balances.InitialQuantity AS InitialQuantity,
		|	Balances.Price AS Price,
		|	Balances.Products AS Products,
		|	Balances.Quantity AS Quantity,
		|	Balances.VATAmount AS VATAmount,
		|	Balances.VATRate AS VATRate,
		|	Balances.SerialNumbers AS SerialNumbers,
		|	Balances.ConnectionKey AS ConnectionKey,
		|	Balances.Order AS Order
		|FROM
		|	Balances AS Balances
		|WHERE
		|	Balances.QuantityBalance > 0";
		
		Query.SetParameter("SupplierInvoice",	SupplierInvoice);
	EndIf;
		
	QueryResult = Query.Execute();
	Inventory.Load(QueryResult.Unload());
	
	WorkWithSerialNumbers.FillTSSerialNumbersByConnectionKey(ThisObject, BasisDocument);
	
EndProcedure

#Region EventHandlers

// Procedure - handler of the FillingProcessor event.
//
Procedure Filling(FillingData, StandardProcessing) Export
		
	FillingStrategy = New Map;
	FillingStrategy[Type("DocumentRef.CreditNote")]			= "FillByCreditNote";
	FillingStrategy[Type("DocumentRef.SalesInvoice")]		= "FillBySalesInvoice";
	FillingStrategy[Type("DocumentRef.DebitNote")]			= "FillByDebitNote";
	FillingStrategy[Type("DocumentRef.SupplierInvoice")]	= "FillBySupplierInvoice";
	
	ObjectFillingDrive.FillDocument(ThisObject, FillingData, FillingStrategy);
	
EndProcedure

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If OperationKind <> Enums.OperationTypesGoodsReturn.FromCustomer Then
		CheckedAttributes.Delete(CheckedAttributes.Find("SalesDocument"));
	ElsIf OperationKind <> Enums.OperationTypesGoodsReturn.ToSupplier Then
		CheckedAttributes.Delete(CheckedAttributes.Find("GLAccount"));
		CheckedAttributes.Delete(CheckedAttributes.Find("SupplierInvoice"));
	EndIf;
	
	If Inventory.Total("Quantity") = 0 Then
		CommonUseClientServer.MessageToUser(NStr("en = 'Please specify the quantity of goods to return.'"),,,, Cancel);
	EndIf;
	
EndProcedure

// Procedure - event handler Posting object.
//
Procedure Posting(Cancel, PostingMode)
	
	DriveServer.CheckAvailabilityOfGoodsReturn(ThisObject, Cancel);
	
	CheckReturnedQuantity(Cancel);
	
	// Initialization of additional properties for document posting
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Document data initialization.
	PerformanceEstimationClientServer.StartTimeMeasurement("GoodsReturnDocumentPostingInitialization");
	
	// Initialization of document data
	Documents.GoodsReturn.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Preparation of record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Account for in accounting sections.
	PerformanceEstimationClientServer.StartTimeMeasurement("GoodsReturnDocumentPostingMovementsCreation");
	
	If OperationKind = Enums.OperationTypesGoodsReturn.FromCustomer Then
		DriveServer.ReflectSales(AdditionalProperties, RegisterRecords, Cancel)
	EndIf;
	
	DriveServer.ReflectInventoryInWarehouses(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectInventory(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectIncomeAndExpenses(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingJournalEntries(AdditionalProperties, RegisterRecords, Cancel);
	
	// SerialNumbers
	DriveServer.ReflectTheSerialNumbersOfTheGuarantee(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectTheSerialNumbersBalance(AdditionalProperties, RegisterRecords, Cancel);
	
	// Record of the records sets.
	PerformanceEstimationClientServer.StartTimeMeasurement("GoodsReturnDocumentPostingMovementsRecord");
		
	// Writing of record sets
	DriveServer.WriteRecordSets(ThisObject);
	
	DriveServer.CreateRecordsInTasksRegisters(ThisObject, Cancel);
	
	// Control of occurrence of a negative balance.
	PerformanceEstimationClientServer.StartTimeMeasurement("GoodsReturnDocumentPostingControl");
	Documents.GoodsReturn.RunControl(Ref, AdditionalProperties, Cancel);

	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
EndProcedure

// Procedure - event handler UndoPosting object.
//
Procedure UndoPosting(Cancel)
	
	// Initialization of additional properties for document posting
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Preparation of record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Writing of record sets
	DriveServer.WriteRecordSets(ThisObject);

EndProcedure

Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	AdditionalProperties.Insert("WriteMode", WriteMode);
EndProcedure

#EndRegion

#EndIf
