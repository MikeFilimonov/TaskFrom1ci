#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region DocumentFillingProcedures

Procedure FillPrepayment() Export
	
	OrderInHeader = (SalesOrderPosition = Enums.AttributeStationing.InHeader);
	ParentCompany = DriveServer.GetCompany(Company);
	
	// Preparation of the order table.
	OrdersTable = Inventory.Unload(, "Order, Total");
	OrdersTable.Columns.Add("TotalCalc");
	For Each CurRow In OrdersTable Do
		If Not Counterparty.DoOperationsByOrders Then
			CurRow.Order = Undefined;
		ElsIf OrderInHeader Then
			CurRow.Order = Order;
		EndIf;
		CurRow.TotalCalc = DriveServer.RecalculateFromCurrencyToCurrency(
			CurRow.Total,
			?(Contract.SettlementsCurrency = DocumentCurrency, ExchangeRate, 1),
			ExchangeRate,
			?(Contract.SettlementsCurrency = DocumentCurrency, Multiplicity, 1),
			Multiplicity
		);
	EndDo;
	OrdersTable.GroupBy("Order", "Total, TotalCalc");
	OrdersTable.Sort("Order Asc");
	
	// Filling prepayment details.
	Query = New Query;
	
	QueryText =
	"SELECT ALLOWED
	|	AccountsReceivableBalances.Document AS Document,
	|	AccountsReceivableBalances.Order AS Order,
	|	AccountsReceivableBalances.DocumentDate AS DocumentDate,
	|	AccountsReceivableBalances.Contract.SettlementsCurrency AS SettlementsCurrency,
	|	SUM(AccountsReceivableBalances.AmountBalance) AS AmountBalance,
	|	SUM(AccountsReceivableBalances.AmountCurBalance) AS AmountCurBalance
	|INTO TemporaryTableAccountsReceivableBalances
	|FROM
	|	(SELECT
	|		AccountsReceivableBalances.Contract AS Contract,
	|		AccountsReceivableBalances.Document AS Document,
	|		AccountsReceivableBalances.Document.Date AS DocumentDate,
	|		AccountsReceivableBalances.Order AS Order,
	|		ISNULL(AccountsReceivableBalances.AmountBalance, 0) AS AmountBalance,
	|		ISNULL(AccountsReceivableBalances.AmountCurBalance, 0) AS AmountCurBalance
	|	FROM
	|		AccumulationRegister.AccountsReceivable.Balance(
	|				,
	|				Company = &Company
	|					AND Counterparty = &Counterparty
	|					AND Contract = &Contract
	|					AND Order IN (&Order)
	|					AND SettlementsType = VALUE(Enum.SettlementsTypes.Advance)) AS AccountsReceivableBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsAccountsReceivable.Contract,
	|		DocumentRegisterRecordsAccountsReceivable.Document,
	|		DocumentRegisterRecordsAccountsReceivable.Document.Date,
	|		DocumentRegisterRecordsAccountsReceivable.Order,
	|		CASE
	|			WHEN DocumentRegisterRecordsAccountsReceivable.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -ISNULL(DocumentRegisterRecordsAccountsReceivable.Amount, 0)
	|			ELSE ISNULL(DocumentRegisterRecordsAccountsReceivable.Amount, 0)
	|		END,
	|		CASE
	|			WHEN DocumentRegisterRecordsAccountsReceivable.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -ISNULL(DocumentRegisterRecordsAccountsReceivable.AmountCur, 0)
	|			ELSE ISNULL(DocumentRegisterRecordsAccountsReceivable.AmountCur, 0)
	|		END
	|	FROM
	|		AccumulationRegister.AccountsReceivable AS DocumentRegisterRecordsAccountsReceivable
	|	WHERE
	|		DocumentRegisterRecordsAccountsReceivable.Recorder = &Ref
	|		AND DocumentRegisterRecordsAccountsReceivable.Period <= &Period
	|		AND DocumentRegisterRecordsAccountsReceivable.Company = &Company
	|		AND DocumentRegisterRecordsAccountsReceivable.Counterparty = &Counterparty
	|		AND DocumentRegisterRecordsAccountsReceivable.Contract = &Contract
	|		AND DocumentRegisterRecordsAccountsReceivable.Order IN (&Order)
	|		AND DocumentRegisterRecordsAccountsReceivable.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)) AS AccountsReceivableBalances
	|
	|GROUP BY
	|	AccountsReceivableBalances.Document,
	|	AccountsReceivableBalances.Order,
	|	AccountsReceivableBalances.DocumentDate,
	|	AccountsReceivableBalances.Contract.SettlementsCurrency
	|
	|HAVING
	|	SUM(AccountsReceivableBalances.AmountCurBalance) < 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	AccountsReceivableBalances.Document AS Document,
	|	AccountsReceivableBalances.Order AS Order,
	|	AccountsReceivableBalances.DocumentDate AS DocumentDate,
	|	AccountsReceivableBalances.SettlementsCurrency AS SettlementsCurrency,
	|	-SUM(AccountsReceivableBalances.AccountingAmount) AS AccountingAmount,
	|	-SUM(AccountsReceivableBalances.SettlementsAmount) AS SettlementsAmount,
	|	-SUM(AccountsReceivableBalances.PaymentAmount) AS PaymentAmount,
	|	SUM(AccountsReceivableBalances.AccountingAmount / CASE
	|			WHEN ISNULL(AccountsReceivableBalances.SettlementsAmount, 0) <> 0
	|				THEN AccountsReceivableBalances.SettlementsAmount
	|			ELSE 1
	|		END) * (SettlementsCurrencyExchangeRatesRate / SettlementsCurrencyExchangeRatesMultiplicity) AS ExchangeRate,
	|	1 AS Multiplicity,
	|	AccountsReceivableBalances.DocumentCurrencyExchangeRatesRate AS DocumentCurrencyExchangeRatesRate,
	|	AccountsReceivableBalances.DocumentCurrencyExchangeRatesMultiplicity AS DocumentCurrencyExchangeRatesMultiplicity
	|FROM
	|	(SELECT
	|		AccountsReceivableBalances.SettlementsCurrency AS SettlementsCurrency,
	|		AccountsReceivableBalances.Document AS Document,
	|		AccountsReceivableBalances.DocumentDate AS DocumentDate,
	|		AccountsReceivableBalances.Order AS Order,
	|		ISNULL(AccountsReceivableBalances.AmountBalance, 0) AS AccountingAmount,
	|		ISNULL(AccountsReceivableBalances.AmountCurBalance, 0) AS SettlementsAmount,
	|		ISNULL(AccountsReceivableBalances.AmountBalance, 0) * SettlementsCurrencyExchangeRates.ExchangeRate * &MultiplicityOfDocumentCurrency / (&DocumentCurrencyRate * SettlementsCurrencyExchangeRates.Multiplicity) AS PaymentAmount,
	|		SettlementsCurrencyExchangeRates.ExchangeRate AS SettlementsCurrencyExchangeRatesRate,
	|		SettlementsCurrencyExchangeRates.Multiplicity AS SettlementsCurrencyExchangeRatesMultiplicity,
	|		&DocumentCurrencyRate AS DocumentCurrencyExchangeRatesRate,
	|		&MultiplicityOfDocumentCurrency AS DocumentCurrencyExchangeRatesMultiplicity
	|	FROM
	|		TemporaryTableAccountsReceivableBalances AS AccountsReceivableBalances
	|			LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&Period, Currency = &PresentationCurrency) AS SettlementsCurrencyExchangeRates
	|			ON (TRUE)) AS AccountsReceivableBalances
	|
	|GROUP BY
	|	AccountsReceivableBalances.Document,
	|	AccountsReceivableBalances.Order,
	|	AccountsReceivableBalances.DocumentDate,
	|	AccountsReceivableBalances.SettlementsCurrency,
	|	SettlementsCurrencyExchangeRatesRate,
	|	SettlementsCurrencyExchangeRatesMultiplicity,
	|	AccountsReceivableBalances.DocumentCurrencyExchangeRatesRate,
	|	AccountsReceivableBalances.DocumentCurrencyExchangeRatesMultiplicity
	|
	|HAVING
	|	-SUM(AccountsReceivableBalances.SettlementsAmount) > 0
	|
	|ORDER BY
	|	DocumentDate";

	Query.SetParameter("Order", OrdersTable.UnloadColumn("Order"));
	Query.SetParameter("Company", ParentCompany);
	Query.SetParameter("Counterparty", Counterparty);
	Query.SetParameter("Contract", Contract);
	Query.SetParameter("Period", Date);
	Query.SetParameter("DocumentCurrency", DocumentCurrency);
	Query.SetParameter("PresentationCurrency", Constants.PresentationCurrency.Get());
	If Contract.SettlementsCurrency = DocumentCurrency Then
		Query.SetParameter("DocumentCurrencyRate", ExchangeRate);
		Query.SetParameter("MultiplicityOfDocumentCurrency", Multiplicity);
	Else
		Query.SetParameter("DocumentCurrencyRate", 1);
		Query.SetParameter("MultiplicityOfDocumentCurrency", 1);
	EndIf;
	Query.SetParameter("Ref", Ref);
	
	Query.Text = QueryText;
	
	Prepayment.Clear();
	
	SelectionOfQueryResult = Query.Execute().Select();
	
	While SelectionOfQueryResult.Next() Do
		
		FoundString = OrdersTable.Find(SelectionOfQueryResult.Order, "Order");
		
		If FoundString.TotalCalc = 0 Then
			Continue;
		EndIf;
		
		If SelectionOfQueryResult.SettlementsAmount <= FoundString.TotalCalc Then // balance amount is less or equal than it is necessary to distribute
			
			NewRow = Prepayment.Add();
			FillPropertyValues(NewRow, SelectionOfQueryResult);
			FoundString.TotalCalc = FoundString.TotalCalc - SelectionOfQueryResult.SettlementsAmount;
			
		Else // Balance amount is greater than it is necessary to distribute
			
			NewRow = Prepayment.Add();
			FillPropertyValues(NewRow, SelectionOfQueryResult);
			NewRow.SettlementsAmount = FoundString.TotalCalc;
			NewRow.PaymentAmount = DriveServer.RecalculateFromCurrencyToCurrency(
				NewRow.SettlementsAmount,
				SelectionOfQueryResult.ExchangeRate,
				SelectionOfQueryResult.DocumentCurrencyExchangeRatesRate,
				SelectionOfQueryResult.Multiplicity,
				SelectionOfQueryResult.DocumentCurrencyExchangeRatesMultiplicity
			);
			FoundString.TotalCalc = 0;
			
		EndIf;
		
	EndDo;
	
	WorkWithVAT.FillPrepaymentVATFromVATOutput(ThisObject);
	
EndProcedure

Procedure FillByStructure(FillingData) Export
	
	If FillingData.Property("ArrayOfSalesOrders") Then
		FillBySalesOrder(FillingData);
	EndIf;
	
	If FillingData.Property("ArrayOfGoodsIssues") Then
		FillByGoodsIssue(FillingData);
	EndIf;
	
	If FillingData.Property("ArrayOfWorkOrders") Then
		FillByWorkOrder(FillingData);
	EndIf;

EndProcedure

Procedure FillBySalesOrder(FillingData) Export
	
	// Document basis and document setting.
	OrdersArray = New Array;
	If TypeOf(FillingData) = Type("Structure") AND FillingData.Property("ArrayOfSalesOrders") Then
		OrdersArray = FillingData.ArrayOfSalesOrders;
	Else
		OrdersArray.Add(FillingData.Ref);
		Order = FillingData;
	EndIf;
	
	// Header filling.
	Query = New Query;
	Query.Text =
	"SELECT
	|	SalesOrder.Ref AS BasisRef,
	|	SalesOrder.Posted AS BasisPosted,
	|	SalesOrder.Closed AS Closed,
	|	SalesOrder.OrderState AS OrderState,
	|	SalesOrder.Company AS Company,
	|	CASE
	|		WHEN SalesOrder.BankAccount = VALUE(Catalog.BankAccounts.EmptyRef)
	|			THEN SalesOrder.Company.BankAccountByDefault
	|		ELSE SalesOrder.BankAccount
	|	END AS BankAccount,
	|	CASE
	|		WHEN InventoryReservation.Value
	|			THEN SalesOrder.StructuralUnitReserve
	|	END AS StructuralUnit,
	|	SalesOrder.Counterparty AS Counterparty,
	|	SalesOrder.Contract AS Contract,
	|	SalesOrder.PriceKind AS PriceKind,
	|	SalesOrder.DiscountMarkupKind AS DiscountMarkupKind,
	|	SalesOrder.DiscountCard AS DiscountCard,
	|	SalesOrder.DiscountPercentByDiscountCard AS DiscountPercentByDiscountCard,
	|	SalesOrder.DocumentCurrency AS DocumentCurrency,
	|	SalesOrder.VATTaxation AS VATTaxation,
	|	SalesOrder.AmountIncludesVAT AS AmountIncludesVAT,
	|	SalesOrder.IncludeVATInPrice AS IncludeVATInPrice,
	|	CASE
	|		WHEN SalesOrder.DocumentCurrency = FunctionalCurrency.Value
	|			THEN SalesOrder.ExchangeRate
	|		ELSE ExchangeRatesSliceLast.ExchangeRate
	|	END AS ExchangeRate,
	|	CASE
	|		WHEN SalesOrder.DocumentCurrency = FunctionalCurrency.Value
	|			THEN SalesOrder.Multiplicity
	|		ELSE ExchangeRatesSliceLast.Multiplicity
	|	END AS Multiplicity,
	|	SalesOrder.CashAssetsType AS CashAssetsType,
	|	SalesOrder.PettyCash AS PettyCash,
	|	SalesOrder.SetPaymentTerms AS SetPaymentTerms,
	|	SalesOrder.ShippingAddress AS ShippingAddress,
	|	SalesOrder.ContactPerson AS ContactPerson,
	|	SalesOrder.Incoterms AS Incoterms,
	|	SalesOrder.DeliveryTimeFrom AS DeliveryTimeFrom,
	|	SalesOrder.DeliveryTimeTo AS DeliveryTimeTo,
	|	SalesOrder.GoodsMarking AS GoodsMarking,
	|	SalesOrder.LogisticsCompany AS LogisticsCompany,
	|	SalesOrder.DeliveryOption AS DeliveryOption
	|INTO TT_SalesOrders
	|FROM
	|	Document.SalesOrder AS SalesOrder
	|		{LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&DocumentDate, ) AS ExchangeRatesSliceLast
	|		ON SalesOrder.Contract.SettlementsCurrency = ExchangeRatesSliceLast.Currency},
	|	Constant.FunctionalCurrency AS FunctionalCurrency,
	|	Constant.UseInventoryReservation AS InventoryReservation
	|WHERE
	|	SalesOrder.Ref IN(&OrdersArray)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_SalesOrders.BasisRef AS BasisRef,
	|	TT_SalesOrders.BasisPosted AS BasisPosted,
	|	TT_SalesOrders.Closed AS Closed,
	|	TT_SalesOrders.OrderState AS OrderState,
	|	TT_SalesOrders.Company AS Company,
	|	TT_SalesOrders.BankAccount AS BankAccount,
	|	TT_SalesOrders.StructuralUnit AS StructuralUnit,
	|	TT_SalesOrders.Counterparty AS Counterparty,
	|	TT_SalesOrders.Contract AS Contract,
	|	TT_SalesOrders.PriceKind AS PriceKind,
	|	TT_SalesOrders.DiscountMarkupKind AS DiscountMarkupKind,
	|	TT_SalesOrders.DiscountCard AS DiscountCard,
	|	TT_SalesOrders.DiscountPercentByDiscountCard AS DiscountPercentByDiscountCard,
	|	TT_SalesOrders.DocumentCurrency AS DocumentCurrency,
	|	TT_SalesOrders.VATTaxation AS VATTaxation,
	|	TT_SalesOrders.AmountIncludesVAT AS AmountIncludesVAT,
	|	TT_SalesOrders.IncludeVATInPrice AS IncludeVATInPrice,
	|	TT_SalesOrders.ExchangeRate AS ExchangeRate,
	|	TT_SalesOrders.Multiplicity AS Multiplicity,
	|	TT_SalesOrders.CashAssetsType AS CashAssetsType,
	|	TT_SalesOrders.PettyCash AS PettyCash,
	|	TT_SalesOrders.SetPaymentTerms AS SetPaymentTerms,
	|	TT_SalesOrders.ShippingAddress AS ShippingAddress,
	|	TT_SalesOrders.ContactPerson AS ContactPerson,
	|	TT_SalesOrders.Incoterms AS Incoterms,
	|	TT_SalesOrders.DeliveryTimeFrom AS DeliveryTimeFrom,
	|	TT_SalesOrders.DeliveryTimeTo AS DeliveryTimeTo,
	|	TT_SalesOrders.GoodsMarking AS GoodsMarking,
	|	TT_SalesOrders.LogisticsCompany AS LogisticsCompany,
	|	TT_SalesOrders.DeliveryOption AS DeliveryOption
	|FROM
	|	TT_SalesOrders AS TT_SalesOrders
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	GoodsShippedNotInvoiced.GoodsIssue AS GoodsIssue
	|FROM
	|	TT_SalesOrders AS TT_SalesOrders
	|		INNER JOIN AccumulationRegister.GoodsShippedNotInvoiced AS GoodsShippedNotInvoiced
	|		ON TT_SalesOrders.BasisRef = GoodsShippedNotInvoiced.SalesOrder";
	
	Query.SetParameter("OrdersArray", OrdersArray);
	Query.SetParameter("DocumentDate", ?(ValueIsFilled(Date), Date, CurrentDate()));
	
	QueryResults = Query.ExecuteBatch();
	
	ResultTable = QueryResults[1].Unload();
	For Each TableRow In ResultTable Do
		VerifiedAttributesValues = New Structure("OrderState, Closed, Posted",
			TableRow.OrderState,
			TableRow.Closed,
			TableRow.BasisPosted);
		Documents.SalesOrder.CheckAbilityOfEnteringBySalesOrder(TableRow.BasisRef, VerifiedAttributesValues);
	EndDo;
	
	AddressesTable = ResultTable.Copy(, "ShippingAddress");
	AddressesTable.GroupBy("ShippingAddress");
	
	If AddressesTable.Count() = 1 Then
		ExcludingProperties = "";
	Else
		ExcludingProperties = "ContactPerson,Incoterms,DeliveryTimeFrom,
			|DeliveryTimeTo,GoodsMarking,LogisticsCompany,DeliveryOption";
		TableRow["ShippingAddress"] = TableRow["Counterparty"];
	EndIf;
	
	FillPropertyValues(ThisObject, TableRow, , ExcludingProperties);
	
	If Not ValueIsFilled(StructuralUnit) Then
		SettingValue = DriveReUse.GetValueOfSetting("MainWarehouse");
		If Not ValueIsFilled(SettingValue) Then
			StructuralUnit = Catalogs.BusinessUnits.MainWarehouse;
		EndIf;
	EndIf;
	
	DocumentData = New Structure;
	DocumentData.Insert("Ref", Ref);
	DocumentData.Insert("Date", CurrentSessionDate());
	DocumentData.Insert("PriceKind", PriceKind);
	DocumentData.Insert("DocumentCurrency", DocumentCurrency);
	DocumentData.Insert("Company", Company);
	DocumentData.Insert("StructuralUnit", StructuralUnit);
	DocumentData.Insert("AmountIncludesVAT", AmountIncludesVAT);
	
	Documents.SalesInvoice.FillBySalesOrders(DocumentData, New Structure("OrdersArray", OrdersArray), Inventory);
	
	GoodsIssuesArray = QueryResults[2].Unload().UnloadColumn("GoodsIssue");
	If GoodsIssuesArray.Count() Then
		
		IssuedInventory = Inventory.UnloadColumns();
		
		FilterData = New Structure("GoodsIssuesArray, Contract", GoodsIssuesArray, Contract);
		Documents.SalesInvoice.FillByGoodsIssues(DocumentData, FilterData, IssuedInventory);
		
		For Each IssuedProductsRow In IssuedInventory Do
			If Not OrdersArray.Find(IssuedProductsRow.Order) = Undefined Then
				FillPropertyValues(Inventory.Add(), IssuedProductsRow);
			EndIf;
		EndDo;
		
	EndIf;
	
	DiscountsAreCalculated = False;
	
	OrdersTable = Inventory.Unload(, "Order");
	OrdersTable.GroupBy("Order");
	If OrdersTable.Count() > 1 Then
		SalesOrderPosition = Enums.AttributeStationing.InTabularSection;
	Else
		SalesOrderPosition = DriveReUse.GetValueOfSetting("SalesOrderPositionInShipmentDocuments");
		If Not ValueIsFilled(SalesOrderPosition) Then
			SalesOrderPosition = Enums.AttributeStationing.InHeader;
		EndIf;
	EndIf;
	
	If SalesOrderPosition = Enums.AttributeStationing.InTabularSection Then
		Order = Undefined;
	ElsIf Not ValueIsFilled(Order) AND OrdersTable.Count() Then
		Order = OrdersTable[0].Order;
	EndIf;
	
	If Inventory.Count() = 0 Then
		If OrdersArray.Count() = 1 Then
			MessageText = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = '%1 has already been invoiced.'"),
				Order);
		Else
			MessageText = NStr("en = 'The selected orders have already been invoiced.'");
		EndIf;
		CommonUseClientServer.MessageToUser(MessageText, Ref);
	EndIf;
	
	SetPaymentTerms = False;
	FillPaymentCalendarFromContract();
	FillEarlyPaymentDiscounts();
	
EndProcedure

Procedure FillByWorkOrder(FillingData) Export
	
	// Document basis and document setting.
	OrdersArray = New Array;
	If TypeOf(FillingData) = Type("Structure") AND FillingData.Property("ArrayOfWorkOrders") Then
		OrdersArray = FillingData.ArrayOfWorkOrders;
	Else
		OrdersArray.Add(FillingData.Ref);
		Order = FillingData;
	EndIf;
	
	// Header filling.
	Query = New Query;
	Query.Text =
	"SELECT
	|	WorkOrder.Ref AS BasisRef,
	|	WorkOrder.Posted AS BasisPosted,
	|	WorkOrder.Closed AS Closed,
	|	WorkOrder.OrderState AS OrderState,
	|	WorkOrder.Company AS Company,
	|	CASE
	|		WHEN WorkOrder.BankAccount = VALUE(Catalog.BankAccounts.EmptyRef)
	|			THEN WorkOrder.Company.BankAccountByDefault
	|		ELSE WorkOrder.BankAccount
	|	END AS BankAccount,
	|	CASE
	|		WHEN InventoryReservation.Value
	|			THEN WorkOrder.StructuralUnitReserve
	|	END AS StructuralUnit,
	|	WorkOrder.Counterparty AS Counterparty,
	|	WorkOrder.Contract AS Contract,
	|	WorkOrder.PriceKind AS PriceKind,
	|	WorkOrder.DiscountMarkupKind AS DiscountMarkupKind,
	|	WorkOrder.DiscountCard AS DiscountCard,
	|	WorkOrder.DiscountPercentByDiscountCard AS DiscountPercentByDiscountCard,
	|	WorkOrder.DocumentCurrency AS DocumentCurrency,
	|	WorkOrder.VATTaxation AS VATTaxation,
	|	WorkOrder.AmountIncludesVAT AS AmountIncludesVAT,
	|	WorkOrder.IncludeVATInPrice AS IncludeVATInPrice,
	|	CASE
	|		WHEN WorkOrder.DocumentCurrency = FunctionalCurrency.Value
	|			THEN WorkOrder.ExchangeRate
	|		ELSE ExchangeRatesSliceLast.ExchangeRate
	|	END AS ExchangeRate,
	|	CASE
	|		WHEN WorkOrder.DocumentCurrency = FunctionalCurrency.Value
	|			THEN WorkOrder.Multiplicity
	|		ELSE ExchangeRatesSliceLast.Multiplicity
	|	END AS Multiplicity,
	|	WorkOrder.CashAssetsType AS CashAssetsType,
	|	WorkOrder.PettyCash AS PettyCash,
	|	WorkOrder.SetPaymentTerms AS SetPaymentTerms,
	|	WorkOrder.ContactPerson AS ContactPerson,
	|	WorkOrder.LogisticsCompany AS LogisticsCompany,
	|	WorkOrder.DeliveryOption AS DeliveryOption,
	|	WorkOrder.Location AS ShippingAddress
	|FROM
	|	Document.WorkOrder AS WorkOrder
	|		{LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&DocumentDate, ) AS ExchangeRatesSliceLast
	|		ON WorkOrder.Contract.SettlementsCurrency = ExchangeRatesSliceLast.Currency},
	|	Constant.FunctionalCurrency AS FunctionalCurrency,
	|	Constant.UseInventoryReservation AS InventoryReservation
	|WHERE
	|	WorkOrder.Ref IN(&OrdersArray)";
	
	Query.SetParameter("OrdersArray", OrdersArray);
	Query.SetParameter("DocumentDate", ?(ValueIsFilled(Date), Date, CurrentDate()));
	
	QueryResult = Query.Execute();
	
	ResultTable = QueryResult.Unload();
	For Each TableRow In ResultTable Do
		VerifiedAttributesValues = New Structure("OrderState, Closed, Posted",
			TableRow.OrderState,
			TableRow.Closed,
			TableRow.BasisPosted);
		Documents.WorkOrder.CheckAbilityOfEnteringByWorkOrder(TableRow.BasisRef, VerifiedAttributesValues);
	EndDo;
	
	AddressesTable = ResultTable.Copy(, "ShippingAddress");
	AddressesTable.GroupBy("ShippingAddress");
	
	FillPropertyValues(ThisObject, TableRow);
	
	If Not ValueIsFilled(StructuralUnit) Then
		SettingValue = DriveReUse.GetValueOfSetting("MainWarehouse");
		If Not ValueIsFilled(SettingValue) Then
			StructuralUnit = Catalogs.BusinessUnits.MainWarehouse;
		EndIf;
	EndIf;
	
	DocumentData = New Structure;
	DocumentData.Insert("Ref", Ref);
	DocumentData.Insert("Date", CurrentSessionDate());
	DocumentData.Insert("PriceKind", PriceKind);
	DocumentData.Insert("DocumentCurrency", DocumentCurrency);
	DocumentData.Insert("Company", Company);
	DocumentData.Insert("StructuralUnit", StructuralUnit);
	DocumentData.Insert("AmountIncludesVAT", AmountIncludesVAT);
	
	Documents.SalesInvoice.FillByWorkOrdersInventory(DocumentData, New Structure("OrdersArray", OrdersArray), Inventory);
	Documents.SalesInvoice.FillByWorkOrdersWorks(DocumentData, New Structure("OrdersArray", OrdersArray), Inventory);
	DiscountsAreCalculated = False;
	
	OrdersTable = Inventory.Unload(, "Order");
	OrdersTable.GroupBy("Order");
	If OrdersTable.Count() > 1 Then
		SalesOrderPosition = Enums.AttributeStationing.InTabularSection;
	Else
		SalesOrderPosition = DriveReUse.GetValueOfSetting("SalesOrderPositionInShipmentDocuments");
		If Not ValueIsFilled(SalesOrderPosition) Then
			SalesOrderPosition = Enums.AttributeStationing.InHeader;
		EndIf;
	EndIf;
	
	If SalesOrderPosition = Enums.AttributeStationing.InTabularSection Then
		Order = Undefined;
	ElsIf Not ValueIsFilled(Order) AND OrdersTable.Count() Then
		Order = OrdersTable[0].Order;
	EndIf;
	
	If Inventory.Count() = 0 Then
		If OrdersArray.Count() = 1 Then
			MessageText = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = '%1 has already been invoiced.'"),
				Order);
		Else
			MessageText = NStr("en = 'The selected orders have already been invoiced.'");
		EndIf;
		CommonUseClientServer.MessageToUser(MessageText, Ref);
	EndIf;
	
	SetPaymentTerms = False;
	If OrdersArray.Count() > 1 Then
		FillPaymentCalendarFromContract();
	Else
		FillPaymentCalendarFromWorkOrder();
	EndIf;
	FillEarlyPaymentDiscounts();
	
EndProcedure

Procedure FillByQuote(FillingDataRef) Export
	
	// Filling out a document header.
	BasisDocument = FillingDataRef;
	
	FillingData = FillingDataRef.GetObject();
	
	Company					= FillingData.Company;
	BankAccount				= FillingData.BankAccount;
	CashAssetsType			= FillingData.CashAssetsType;
	Counterparty			= FillingData.Counterparty;
	PettyCash				= FillingData.PettyCash;
	Contract				= FillingData.Contract;
	PriceKind				= FillingData.PriceKind;
	DiscountMarkupKind	= FillingData.DiscountMarkupKind;
	DocumentCurrency		= FillingData.DocumentCurrency;
	AmountIncludesVAT	= FillingData.AmountIncludesVAT;
	VATTaxation	= FillingData.VATTaxation;
	// DiscountCards
	DiscountCard = FillingData.DiscountCard;
	DiscountPercentByDiscountCard = FillingData.DiscountPercentByDiscountCard;
	// End DiscountCards
		
	If DocumentCurrency = Constants.FunctionalCurrency.Get() Then
		ExchangeRate		= FillingData.ExchangeRate;
		Multiplicity	= FillingData.Multiplicity;
	Else
		StructureByCurrency = InformationRegisters.ExchangeRates.GetLast(Date, New Structure("Currency", Contract.SettlementsCurrency));
		ExchangeRate		= StructureByCurrency.ExchangeRate;
		Multiplicity	= StructureByCurrency.Multiplicity;
	EndIf;
	
	// Filling document tabular section.
	Inventory.Clear();
	For Each TabularSectionRow In FillingData.Inventory Do
		
		If Not TabularSectionRow.Variant = FillingData.PreferredVariant Then
			Continue;
		EndIf;
		
		If TabularSectionRow.Products.ProductsType = Enums.ProductsTypes.InventoryItem
			OR TabularSectionRow.Products.ProductsType = Enums.ProductsTypes.Service Then
		
			NewRow = Inventory.Add();
			FillPropertyValues(NewRow, TabularSectionRow);
			NewRow.ProductsTypeInventory = (NewRow.Products.ProductsType = Enums.ProductsTypes.InventoryItem);
			NewRow.SalesRep = FillingData.SalesRep;
			
		EndIf;
		
	EndDo;
	
	// AutomaticDiscounts
	If GetFunctionalOption("UseAutomaticDiscounts") Then
		DiscountsAreCalculated = True;
		DiscountsMarkups.Clear();
		For Each TabularSectionRow In FillingData.DiscountsMarkups Do
			If Inventory.Find(TabularSectionRow.ConnectionKey, "ConnectionKey") <> Undefined Then
				NewRowDiscountsMarkups = DiscountsMarkups.Add();
				FillPropertyValues(NewRowDiscountsMarkups, TabularSectionRow);
			EndIf;
		EndDo;
	EndIf;
	// End AutomaticDiscounts
	
	// Payment calendar
	PaymentCalendar.Clear();
	
	Query = New Query;
	Query.SetParameter("Date", ?(ValueIsFilled(Date), Date, CurrentSessionDate()));
	Query.SetParameter("Quote", FillingDataRef);
	Query.Text = 
	"SELECT
	|	DATEADD(&Date, DAY, DATEDIFF(Calendar.Ref.Date, Calendar.PaymentDate, DAY)) AS PaymentDate,
	|	Calendar.PaymentPercentage AS PaymentPercentage,
	|	Calendar.PaymentAmount AS PaymentAmount,
	|	Calendar.PaymentVATAmount AS PaymentVATAmount
	|FROM
	|	Document.Quote.PaymentCalendar AS Calendar
	|WHERE
	|	Calendar.Ref IN(&Quote)";
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		NewLine = PaymentCalendar.Add();
		FillPropertyValues(NewLine, Selection);
	EndDo;
	
	SetPaymentTerms = PaymentCalendar.Count() > 0;
	
	FillEarlyPaymentDiscounts();
	
EndProcedure

Procedure FillBySupplierInvoice(FillingData, Operation = "") Export
	
	If DriveReUse.AttributeInHeader("SalesOrderPositionInShipmentDocuments") 
		AND FillingData.PurchaseOrderPosition = Enums.AttributeStationing.InHeader Then
		Order = FillingData.Order;
	Else
		Order = Undefined;
	EndIf;
	
	BasisDocument = FillingData.Ref;
	Company = FillingData.Company;
	VATTaxation = DriveServer.VATTaxation(Company, Date);
	
	StructuralUnit = FillingData.StructuralUnit;
	Cell = FillingData.Cell;
	DocumentCurrency = FillingData.DocumentCurrency;
	AmountIncludesVAT = FillingData.AmountIncludesVAT;
	IncludeVATInPrice = FillingData.IncludeVATInPrice;
	
	ExchangeRate = FillingData.ExchangeRate;
	Multiplicity = FillingData.Multiplicity;
	
	StructureData = New Structure;
	ObjectParameters = New Structure;
	ObjectParameters.Insert("Company", Company);
	ObjectParameters.Insert("StructuralUnit", StructuralUnit);
	StructureData.Insert("ObjectParameters", ObjectParameters);
	
	// Filling document tabular section.
	Inventory.Clear();
	For Each TabularSectionRow In FillingData.Inventory Do
		
		NewRow = Inventory.Add();
		FillPropertyValues(NewRow, TabularSectionRow, ,"Price, Amount, VATAmount, Total");
		
		NewRow.ProductsTypeInventory = (NewRow.Products.ProductsType = Enums.ProductsTypes.InventoryItem);
		
		If Not FillingData.PurchaseOrderPosition = Enums.AttributeStationing.InHeader
			AND DriveReUse.AttributeInHeader("SalesOrderPositionInShipmentDocuments") Then
			NewRow.Order = Undefined;
		EndIf;
		
		If VATTaxation = FillingData.VATTaxation Then
			Continue;
		EndIf;
		
		If VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then
			
			For Each TabularSectionRow In Inventory Do
				
				If ValueIsFilled(TabularSectionRow.Products.VATRate) Then
					TabularSectionRow.VATRate = TabularSectionRow.Products.VATRate;
				Else
					TabularSectionRow.VATRate = InformationRegisters.AccountingPolicy.GetDefaultVATRate(Date, Company);
				EndIf;	
				
				VATRate = DriveReUse.GetVATRateValue(TabularSectionRow.VATRate);
				TabularSectionRow.VATAmount = ?(AmountIncludesVAT, 
												TabularSectionRow.Amount - (TabularSectionRow.Amount) / ((VATRate + 100) / 100),
												TabularSectionRow.Amount * VATRate / 100);
				TabularSectionRow.Total = TabularSectionRow.Amount + ?(AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
				
			EndDo;
			
		Else
			
			If VATTaxation = Enums.VATTaxationTypes.NotSubjectToVAT Then	
				DefaultVATRate = Catalogs.VATRates.Exempt;
			Else
				DefaultVATRate = Catalogs.VATRates.ZeroRate;
			EndIf;	
			
			For Each TabularSectionRow In Inventory Do
			
				TabularSectionRow.VATRate = DefaultVATRate;
				TabularSectionRow.VATAmount = 0;
				
				TabularSectionRow.Total = TabularSectionRow.Amount;
				
			EndDo;
			
		EndIf;
		
	EndDo;
	
	GLAccountsInDocuments.FillTabSectionFromProductGLAccounts(ThisObject, FillingData);
	WorkWithSerialNumbers.FillTSSerialNumbersByConnectionKey(ThisObject, FillingData);
	
	// Payment calendar
	PaymentCalendar.Clear();
	
	Query = New Query;
	Query.SetParameter("Date", ?(ValueIsFilled(Date), Date, CurrentDate()));
	Query.SetParameter("BasisDocument", FillingData);
	Query.Text = 
	"SELECT
	|	DATEADD(&Date, DAY, DATEDIFF(SupplierInvoicePaymentCalendar.Ref.Date, SupplierInvoicePaymentCalendar.PaymentDate, DAY)) AS PaymentDate,
	|	SupplierInvoicePaymentCalendar.PaymentPercentage AS PaymentPercentage,
	|	SupplierInvoicePaymentCalendar.PaymentAmount AS PaymentAmount,
	|	SupplierInvoicePaymentCalendar.PaymentVATAmount AS PaymentVATAmount
	|FROM
	|	Document.SupplierInvoice.PaymentCalendar AS SupplierInvoicePaymentCalendar
	|WHERE
	|	SupplierInvoicePaymentCalendar.Ref = &BasisDocument";
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		NewLine = PaymentCalendar.Add();
		FillPropertyValues(NewLine, Selection);
	EndDo;
	
	SetPaymentTerms = PaymentCalendar.Count() > 0;

EndProcedure

Procedure FillByGoodsIssue(FillingData) Export
	
	// Document basis and document setting.
	GoodsIssuesArray = New Array;
	Contract = Undefined;
	
	If TypeOf(FillingData) = Type("Structure")
		AND FillingData.Property("ArrayOfGoodsIssues") Then
		
		For Each ArrayItem In FillingData.ArrayOfGoodsIssues Do
			Contract = ArrayItem.Contract;
			GoodsIssuesArray.Add(ArrayItem.Ref);
		EndDo;
		
		GoodsIssue = GoodsIssuesArray[0];
		
	Else
		GoodsIssuesArray.Add(FillingData.Ref);
		GoodsIssue = FillingData;
	EndIf;
	
	// Header filling.
	Query = New Query;
	Query.Text =
	"SELECT
	|	GoodsIssue.Ref AS BasisRef,
	|	GoodsIssue.Posted AS BasisPosted,
	|	GoodsIssue.Company AS Company,
	|	GoodsIssue.StructuralUnit AS StructuralUnit,
	|	GoodsIssue.Cell AS Cell,
	|	GoodsIssue.Contract AS Contract,
	|	GoodsIssue.Order AS Order,
	|	GoodsIssue.Counterparty AS Counterparty,
	|	GoodsIssue.ShippingAddress AS ShippingAddress,
	|	GoodsIssue.ContactPerson AS ContactPerson,
	|	GoodsIssue.Incoterms AS Incoterms,
	|	GoodsIssue.DeliveryTimeFrom AS DeliveryTimeFrom,
	|	GoodsIssue.DeliveryTimeTo AS DeliveryTimeTo,
	|	GoodsIssue.GoodsMarking AS GoodsMarking,
	|	GoodsIssue.LogisticsCompany AS LogisticsCompany,
	|	GoodsIssue.DeliveryOption AS DeliveryOption,
	|	GoodsIssue.OperationType AS OperationType
	|INTO GoodsIssueHeader
	|FROM
	|	Document.GoodsIssue AS GoodsIssue
	|WHERE
	|	GoodsIssue.Ref IN(&GoodsIssuesArray)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	GoodsIssueHeader.BasisRef AS BasisRef,
	|	GoodsIssueHeader.BasisPosted AS BasisPosted,
	|	GoodsIssueHeader.Company AS Company,
	|	GoodsIssueHeader.StructuralUnit AS StructuralUnit,
	|	GoodsIssueHeader.Cell AS Cell,
	|	GoodsIssueHeader.Counterparty AS Counterparty,
	|	CASE
	|		WHEN GoodsIssueProducts.Contract <> VALUE(Catalog.CounterpartyContracts.EmptyRef)
	|			THEN GoodsIssueProducts.Contract
	|		ELSE GoodsIssueHeader.Contract
	|	END AS Contract,
	|	CASE
	|		WHEN GoodsIssueProducts.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|			THEN GoodsIssueProducts.Order
	|		ELSE GoodsIssueHeader.Order
	|	END AS Order,
	|	GoodsIssueHeader.ShippingAddress AS ShippingAddress,
	|	GoodsIssueHeader.ContactPerson AS ContactPerson,
	|	GoodsIssueHeader.Incoterms AS Incoterms,
	|	GoodsIssueHeader.DeliveryTimeFrom AS DeliveryTimeFrom,
	|	GoodsIssueHeader.DeliveryTimeTo AS DeliveryTimeTo,
	|	GoodsIssueHeader.GoodsMarking AS GoodsMarking,
	|	GoodsIssueHeader.LogisticsCompany AS LogisticsCompany,
	|	GoodsIssueHeader.DeliveryOption AS DeliveryOption,
	|	GoodsIssueHeader.OperationType AS OperationType
	|INTO GIFiltred
	|FROM
	|	GoodsIssueHeader AS GoodsIssueHeader
	|		LEFT JOIN Document.GoodsIssue.Products AS GoodsIssueProducts
	|		ON GoodsIssueHeader.BasisRef = GoodsIssueProducts.Ref
	|WHERE
	|	(GoodsIssueProducts.Contract = &Contract
	|			OR &Contract = VALUE(Catalog.CounterpartyContracts.EmptyRef))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	GIFiltred.BasisRef AS BasisRef,
	|	GIFiltred.BasisPosted AS BasisPosted,
	|	GIFiltred.Company AS Company,
	|	GIFiltred.StructuralUnit AS StructuralUnit,
	|	GIFiltred.Cell AS Cell,
	|	GIFiltred.Counterparty AS Counterparty,
	|	GIFiltred.Contract AS Contract,
	|	GIFiltred.Order AS Order,
	|	SalesOrder.PriceKind AS PriceKind,
	|	SalesOrder.DiscountMarkupKind AS DiscountMarkupKind,
	|	SalesOrder.DiscountCard AS DiscountCard,
	|	SalesOrder.DiscountPercentByDiscountCard AS DiscountPercentByDiscountCard,
	|	SalesOrder.DocumentCurrency AS DocumentCurrency,
	|	SalesOrder.VATTaxation AS VATTaxation,
	|	SalesOrder.AmountIncludesVAT AS AmountIncludesVAT,
	|	SalesOrder.IncludeVATInPrice AS IncludeVATInPrice,
	|	CASE
	|		WHEN SalesOrder.DocumentCurrency = FunctionalCurrency.Value
	|			THEN SalesOrder.ExchangeRate
	|		ELSE ExchangeRatesSliceLast.ExchangeRate
	|	END AS ExchangeRate,
	|	CASE
	|		WHEN SalesOrder.DocumentCurrency = FunctionalCurrency.Value
	|			THEN SalesOrder.Multiplicity
	|		ELSE ExchangeRatesSliceLast.Multiplicity
	|	END AS Multiplicity,
	|	SalesOrder.CashAssetsType AS CashAssetsType,
	|	SalesOrder.PettyCash AS PettyCash,
	|	SalesOrder.SetPaymentTerms AS SetPaymentTerms,
	|	SalesOrder.BankAccount AS BankAccount,
	|	GIFiltred.ShippingAddress AS ShippingAddress,
	|	GIFiltred.ContactPerson AS ContactPerson,
	|	GIFiltred.Incoterms AS Incoterms,
	|	GIFiltred.DeliveryTimeFrom AS DeliveryTimeFrom,
	|	GIFiltred.DeliveryTimeTo AS DeliveryTimeTo,
	|	GIFiltred.GoodsMarking AS GoodsMarking,
	|	GIFiltred.LogisticsCompany AS LogisticsCompany,
	|	GIFiltred.DeliveryOption AS DeliveryOption,
	|	GIFiltred.OperationType AS OperationType
	|FROM
	|	GIFiltred AS GIFiltred
	|		LEFT JOIN Document.SalesOrder AS SalesOrder
	|		ON GIFiltred.Order = SalesOrder.Ref
	|		{LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&DocumentDate, ) AS ExchangeRatesSliceLast
	|		ON (SalesOrder.Contract.SettlementsCurrency = ExchangeRatesSliceLast.Currency)},
	|	Constant.FunctionalCurrency AS FunctionalCurrency,
	|	Constant.UseInventoryReservation AS InventoryReservation";
	
	Query.SetParameter("DocumentDate", ?(ValueIsFilled(Date), Date, CurrentDate()));
	Query.SetParameter("GoodsIssuesArray", GoodsIssuesArray);
	Query.SetParameter("Contract", Contract);
	
	ResultTable = Query.Execute().Unload();
	For Each TableRow In ResultTable Do
		Documents.GoodsIssue.CheckAbilityOfEnteringByGoodsIssue(TableRow.BasisRef, TableRow.BasisPosted, TableRow.OperationType, True);
	EndDo;
	
	AddressesTable = ResultTable.Copy(, "ShippingAddress");
	AddressesTable.GroupBy("ShippingAddress");
	
	If AddressesTable.Count() = 1 Then
		ExcludingProperties = "";
	Else
		ExcludingProperties = "ContactPerson,Incoterms,DeliveryTimeFrom,
			|DeliveryTimeTo,GoodsMarking,LogisticsCompany,DeliveryOption";
		TableRow["ShippingAddress"] = TableRow["Counterparty"];
	EndIf;
	
	FillPropertyValues(ThisObject, TableRow, , ExcludingProperties);
	
	DocumentData = New Structure;
	DocumentData.Insert("Ref", Ref);
	DocumentData.Insert("Date", CurrentSessionDate());
	DocumentData.Insert("PriceKind", PriceKind);
	DocumentData.Insert("DocumentCurrency", DocumentCurrency);
	DocumentData.Insert("Company", Company);
	DocumentData.Insert("AmountIncludesVAT", AmountIncludesVAT);
	DocumentData.Insert("StructuralUnit", StructuralUnit);
	    
	FilterData = New Structure("GoodsIssuesArray, Contract", GoodsIssuesArray, Contract);
	
	Documents.SalesInvoice.FillByGoodsIssues(DocumentData, FilterData, Inventory);
	
	DiscountsAreCalculated = False;
	
	OrdersTable = Inventory.Unload(, "Order, GoodsIssue");
	OrdersTable.GroupBy("Order, GoodsIssue");
	If OrdersTable.Count() > 1 Then
		SalesOrderPosition = Enums.AttributeStationing.InTabularSection;
	Else
		
		SalesOrderPosition = DriveReUse.GetValueOfSetting("SalesOrderPositionInShipmentDocuments");
		If Not ValueIsFilled(SalesOrderPosition) Then
			SalesOrderPosition = Enums.AttributeStationing.InHeader;
		EndIf;
		
	EndIf;
	
	OrdersTable.GroupBy("Order");
	
	If OrdersTable.Count() = 1 Then
		
		PaymentCalendar.Clear();
	
		Query = New Query;
		Query.SetParameter("Date",			?(ValueIsFilled(Date), Date, CurrentDate()));
		Query.SetParameter("SalesOrders",	OrdersTable);
		Query.Text = 
		"SELECT
		|	DATEADD(&Date, DAY, DATEDIFF(Calendar.Ref.Date, Calendar.PaymentDate, DAY)) AS PaymentDate,
		|	Calendar.PaymentPercentage AS PaymentPercentage,
		|	Calendar.PaymentAmount AS PaymentAmount,
		|	Calendar.PaymentVATAmount AS PaymentVATAmount
		|FROM
		|	Document.SalesOrder.PaymentCalendar AS Calendar
		|WHERE
		|	Calendar.Ref IN(&SalesOrders)";
		
		Selection = Query.Execute().Select();
		While Selection.Next() Do
			NewLine = PaymentCalendar.Add();
			FillPropertyValues(NewLine, Selection);
		EndDo;
		
		SetPaymentTerms = PaymentCalendar.Count() > 0;
		
	Else
		SetPaymentTerms = False;
		FillPaymentCalendarFromContract();
	EndIf;
	
	FillEarlyPaymentDiscounts();
	
	If SalesOrderPosition = Enums.AttributeStationing.InTabularSection Then
		Order = Undefined;
	ElsIf Not ValueIsFilled(Order) AND GoodsIssuesArray.Count() > 0 Then
		Order = GoodsIssuesArray[0].Order;
	EndIf;
	
	If Inventory.Count() = 0 Then
		If GoodsIssuesArray.Count() = 1 Then
			MessageText = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = '%1 has already been invoiced.'"),
				GoodsIssue);
		Else
			MessageText = NStr("en = 'The selected goods issues have already been invoiced.'");
		EndIf;
		CommonUseClientServer.MessageToUser(MessageText, Ref);
	EndIf;
	
EndProcedure

Procedure FillColumnReserveByReserves() Export
	DocumentData = New Structure;
	DocumentData.Insert("Date", Date);
	DocumentData.Insert("Ref", Ref);
	DocumentData.Insert("Company", Company);
	DocumentData.Insert("StructuralUnit", StructuralUnit);
	DocumentData.Insert("Order", Order);
	DocumentData.Insert("SalesOrderPosition", SalesOrderPosition);
	Documents.SalesInvoice.FillColumnReserveByReserves(DocumentData, Inventory);	
EndProcedure

Procedure FillPaymentCalendarFromContract() Export
	
	Query = New Query("
	|SELECT
	|	Table.Term AS Term,
	|	Table.DuePeriod AS DuePeriod,
	|	Table.PaymentPercentage AS PaymentPercentage
	|FROM
	|	Catalog.CounterpartyContracts.StagesOfPayment AS Table
	|WHERE
	|	Table.Ref = &Ref
	|");
	
	Query.SetParameter("Ref", Contract);
	
	Result = Query.Execute();
	DataSelection = Result.Select();
	
	If Result.IsEmpty() Then
		Return;
	EndIf;
	
	PaymentCalendar.Clear();
	
	TotalAmountForCorrectBalance = 0;
	TotalVATForCorrectBalance = 0;
	
	TotalAmount = Inventory.Total("Amount");
	TotalVAT = Inventory.Total("VATAmount");
	
	DocumentDate = ?(ValueIsFilled(Date), Date, CurrentSessionDate());
	
	While DataSelection.Next() Do
		
		NewLine = PaymentCalendar.Add();
		
		If DataSelection.Term = Enums.PaymentTerm.PaymentInAdvance Then
			NewLine.PaymentDate = DocumentDate - DataSelection.DuePeriod * 86400;
		Else
			NewLine.PaymentDate = DocumentDate + DataSelection.DuePeriod * 86400;
		EndIf;
		
		NewLine.PaymentPercentage = DataSelection.PaymentPercentage;
		NewLine.PaymentAmount = Round(TotalAmount * NewLine.PaymentPercentage / 100, 2, RoundMode.Round15as20);
		NewLine.PaymentVATAmount = Round(TotalVAT * NewLine.PaymentPercentage / 100, 2, RoundMode.Round15as20);
		
		TotalAmountForCorrectBalance = TotalAmountForCorrectBalance + NewLine.PaymentAmount;
		TotalVATForCorrectBalance = TotalVATForCorrectBalance + NewLine.PaymentVATAmount;
		
	EndDo;
	
	// correct balance
	NewLine.PaymentAmount = NewLine.PaymentAmount + (TotalAmount - TotalAmountForCorrectBalance);
	NewLine.PaymentVATAmount = NewLine.PaymentVATAmount + (TotalVAT - TotalVATForCorrectBalance);
	
	SetPaymentTerms = True;
	CashAssetsType = CommonUse.ObjectAttributeValue(Contract, "PaymentMethod");
	
	If CashAssetsType = Enums.CashAssetTypes.Noncash Then
		BankAccountByDefault = CommonUse.ObjectAttributeValue(Company, "BankAccountByDefault");
		If ValueIsFilled(BankAccountByDefault) Then
			BankAccount = BankAccountByDefault;
		EndIf;
	ElsIf CashAssetsType = Enums.CashAssetTypes.Cash Then
		PettyCashByDefault = CommonUse.ObjectAttributeValue(Company, "PettyCashByDefault");
		If ValueIsFilled(PettyCashByDefault) Then
			PettyCash = PettyCashByDefault;
		EndIf;
	EndIf;
	
EndProcedure

Procedure FillPaymentCalendarFromWorkOrder()
	
	Query = New Query("SELECT
	|	WorkOrder.Start AS ShipmentDate,
	|	WorkOrderPaymentCalendar.PaymentDate AS PaymentDate,
	|	WorkOrderPaymentCalendar.PaymentPercentage AS PaymentPercentage
	|FROM
	|	Document.WorkOrder.PaymentCalendar AS WorkOrderPaymentCalendar
	|		INNER JOIN Document.WorkOrder AS WorkOrder
	|		ON WorkOrderPaymentCalendar.Ref = WorkOrder.Ref
	|WHERE
	|	WorkOrderPaymentCalendar.Ref = &Ref");
	
	Query.SetParameter("Ref", Order);
	
	Result = Query.Execute();
	DataSelection = Result.Select();
	
	If Result.IsEmpty() Then
		Return;
	EndIf;
	
	PaymentCalendar.Clear();
	
	TotalAmountForCorrectBalance = 0;
	TotalVATForCorrectBalance = 0;
	
	TotalAmount = Inventory.Total("Amount");
	TotalVAT = Inventory.Total("VATAmount");
	
	DocumentDate = ?(ValueIsFilled(Date), Date, CurrentSessionDate());
	
	While DataSelection.Next() Do
		
		NewLine = PaymentCalendar.Add();
		
		NewLine.PaymentDate = DocumentDate + (DataSelection.ShipmentDate - DataSelection.PaymentDate);
		NewLine.PaymentPercentage = DataSelection.PaymentPercentage;
		NewLine.PaymentAmount = Round(TotalAmount * NewLine.PaymentPercentage / 100, 2, RoundMode.Round15as20);
		NewLine.PaymentVATAmount = Round(TotalVAT * NewLine.PaymentPercentage / 100, 2, RoundMode.Round15as20);
		
		TotalAmountForCorrectBalance = TotalAmountForCorrectBalance + NewLine.PaymentAmount;
		TotalVATForCorrectBalance = TotalVATForCorrectBalance + NewLine.PaymentVATAmount;
		
	EndDo;
	
	// correct balance
	NewLine.PaymentAmount = NewLine.PaymentAmount + (TotalAmount - TotalAmountForCorrectBalance);
	NewLine.PaymentVATAmount = NewLine.PaymentVATAmount + (TotalVAT - TotalVATForCorrectBalance);
	
	SetPaymentTerms = True;
	CashAssetsType = CommonUse.ObjectAttributeValue(Contract, "PaymentMethod");
	
	If CashAssetsType = Enums.CashAssetTypes.Noncash Then
		BankAccountByDefault = CommonUse.ObjectAttributeValue(Company, "BankAccountByDefault");
		If ValueIsFilled(BankAccountByDefault) Then
			BankAccount = BankAccountByDefault;
		EndIf;
	ElsIf CashAssetsType = Enums.CashAssetTypes.Cash Then
		PettyCashByDefault = CommonUse.ObjectAttributeValue(Company, "PettyCashByDefault");
		If ValueIsFilled(PettyCashByDefault) Then
			PettyCash = PettyCashByDefault;
		EndIf;
	EndIf;
	
EndProcedure

// Fills in the table section "EarlyPaymentDiscounts" from the contract
//
Procedure FillEarlyPaymentDiscounts() Export
	
	If Counterparty.DoOperationsByDocuments AND Contract.ContractKind = Enums.ContractType.WithCustomer Then
	
		Query = New Query;
		Query.Text =
		"SELECT
		|	ContractsEarlyPaymentDiscounts.Period AS Period,
		|	ContractsEarlyPaymentDiscounts.Discount AS Discount,
		|	Contracts.ProvideEPD AS ProvideEPD
		|FROM
		|	Catalog.CounterpartyContracts AS Contracts
		|		INNER JOIN Catalog.CounterpartyContracts.EarlyPaymentDiscounts AS ContractsEarlyPaymentDiscounts
		|		ON Contracts.Ref = ContractsEarlyPaymentDiscounts.Ref
		|WHERE
		|	Contracts.Ref = &Ref";
		
		Query.SetParameter("Ref", Contract);
		
		QueryResult = Query.Execute();
		If QueryResult.IsEmpty() Then
			Return;
		EndIf;
		
		EarlyPaymentDiscounts.Clear();
		
		TotalAmount		= Inventory.Total("Total");
		DocumentDate	= ?(ValueIsFilled(Date), Date, CurrentSessionDate());
		
		ResultTable = QueryResult.Unload();
		
		ProvideEPD = ResultTable[0].ProvideEPD;
		
		For each ResultRow In ResultTable Do
			
			NewRow = EarlyPaymentDiscounts.Add();
			FillPropertyValues(NewRow, ResultRow);
			
			NewRow.DueDate			= DocumentDate + NewRow.Period * 86400;
			NewRow.DiscountAmount	= Round(TotalAmount * NewRow.Discount / 100, 2);
			
		EndDo;
		
	Else
		
		EarlyPaymentDiscounts.Clear();
		ProvideEPD = Undefined;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region EventHandlers

Procedure Filling(FillingData, StandardProcessing) Export
	
	FillingStrategy = New Map;
	FillingStrategy[Type("Structure")]						= "FillByStructure";
	FillingStrategy[Type("DocumentRef.SalesOrder")]			= "FillBySalesOrder";
	FillingStrategy[Type("DocumentRef.Quote")]				= "FillByQuote";
	FillingStrategy[Type("DocumentRef.GoodsIssue")]			= "FillByGoodsIssue";
	FillingStrategy[Type("DocumentRef.SupplierInvoice")]	= "FillBySupplierInvoice";
	FillingStrategy[Type("DocumentRef.WorkOrder")]			= "FillByWorkOrder";
	
	ExcludingProperties = "Order";
	If TypeOf(FillingData) = Type("Structure")
		AND FillingData.Property("ArrayOfSalesOrders") Then
		ExcludingProperties = ExcludingProperties + ", AmountIncludesVAT";
	EndIf;
	
	ObjectFillingDrive.FillDocument(ThisObject, FillingData, FillingStrategy, ExcludingProperties);
	
EndProcedure

Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If SalesOrderPosition = Enums.AttributeStationing.InHeader Then
		For Each TabularSectionRow In Inventory Do
			TabularSectionRow.Order = Order;
		EndDo;
		If Counterparty.DoOperationsByOrders Then
			For Each TabularSectionRow In Prepayment Do
				TabularSectionRow.Order = Order;
			EndDo;
		EndIf;
	EndIf;
	
	If ValueIsFilled(Counterparty)
		AND Not Counterparty.DoOperationsByContracts
		AND Not ValueIsFilled(Contract) Then
		Contract = Counterparty.ContractByDefault;
	EndIf;
	
	DocumentAmount = Inventory.Total("Total");
	
	If NOT ValueIsFilled(DeliveryOption) OR DeliveryOption = Enums.DeliveryOptions.SelfPickup Then
		ClearDeliveryAttributes();
	ElsIf DeliveryOption <> Enums.DeliveryOptions.LogisticsCompany Then
		ClearDeliveryAttributes("LogisticsCompany");
	EndIf;
	
	FillSalesRep();
	
	AdditionalProperties.Insert("WriteMode", WriteMode);
		
EndProcedure

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	CheckedAttributes.Add("Department");
	
	OrderInHeader = SalesOrderPosition = Enums.AttributeStationing.InHeader;
	
	TableInventory = Inventory.Unload(, "Order, Total");
	TableInventory.GroupBy("Order", "Total");
	
	TablePrepayment = Prepayment.Unload(, "Order, PaymentAmount");
	TablePrepayment.GroupBy("Order", "PaymentAmount");
	
	If OrderInHeader Then
		For Each StringInventory In TableInventory Do
			StringInventory.Order = Order;
		EndDo;
		If Counterparty.DoOperationsByOrders Then
			For Each RowPrepayment In TablePrepayment Do
				RowPrepayment.Order = Order;
			EndDo;
		EndIf;
	EndIf;
	
	QuantityInventory = Inventory.Count();
	
	For Each String In TablePrepayment Do
		
		FoundStringInventory = Undefined;
		
		If Counterparty.DoOperationsByOrders
		   AND String.Order <> Undefined
		   AND String.Order <> Documents.SalesOrder.EmptyRef()
		   AND String.Order <> Documents.PurchaseOrder.EmptyRef() Then
			FoundStringInventory = TableInventory.Find(String.Order, "Order");
			Total = ?(FoundStringInventory = Undefined, 0, FoundStringInventory.Total);
		ElsIf Counterparty.DoOperationsByOrders Then
			FoundStringInventory = TableInventory.Find(Undefined, "Order");
			FoundStringInventory = ?(FoundStringInventory = Undefined, TableInventory.Find(Documents.SalesOrder.EmptyRef(), "Order"), FoundStringInventory);
			FoundStringInventory = ?(FoundStringInventory = Undefined, TableInventory.Find(Documents.PurchaseOrder.EmptyRef(), "Order"), FoundStringInventory);				
			Total = ?(FoundStringInventory = Undefined, 0, FoundStringInventory.Total);
		Else
			Total = Inventory.Total("Total");
		EndIf;
		
		If FoundStringInventory = Undefined
		   AND QuantityInventory > 0
		   AND Counterparty.DoOperationsByOrders Then
			MessageText = NStr("en = 'You can''t make an advance clearing against the sales order if the sales invoice doesn''t refer to this sales order.'");
			DriveServer.ShowMessageAboutError(
				,
				MessageText,
				Undefined,
				Undefined,
				"PrepaymentTotalSettlementsAmountCurrency",
				Cancel
			);
		EndIf;
	EndDo;
	
	If Constants.UseInventoryReservation.Get() Then
		
		For Each StringInventory In Inventory Do
			
			If StringInventory.Reserve > StringInventory.Quantity Then
				
				MessageText = NStr("en = 'The quantity of items to be shipped in line #%Number% of the Products list exceeds the quantity available in the warehouse reserve.'");
				MessageText = StrReplace(MessageText, "%Number%", StringInventory.LineNumber);
				DriveServer.ShowMessageAboutError(
					ThisObject,
					MessageText,
					"Inventory",
					StringInventory.LineNumber,
					"Reserve",
					Cancel
				);
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
	// 100% discount.
	ThereAreManualDiscounts = GetFunctionalOption("UseManualDiscounts");
	ThereAreAutomaticDiscounts = GetFunctionalOption("UseAutomaticDiscounts");
	
	If ThereAreManualDiscounts
		OR ThereAreAutomaticDiscounts Then
		For Each StringInventory In Inventory Do
			// AutomaticDiscounts
			CurAmount = StringInventory.Price * StringInventory.Quantity;
			
			ManualDiscountCurAmount		= ?(ThereAreManualDiscounts, Round(CurAmount * StringInventory.DiscountMarkupPercent / 100, 2), 0);
			AutomaticDiscountCurAmount	= ?(ThereAreAutomaticDiscounts, StringInventory.AutomaticDiscountAmount, 0);
			CurAmountDiscounts			= ManualDiscountCurAmount + AutomaticDiscountCurAmount;
			
			If StringInventory.DiscountMarkupPercent <> 100 AND CurAmountDiscounts < CurAmount
				AND Not ValueIsFilled(StringInventory.Amount) Then
				
				MessageText = StringFunctionsClientServer.SubstituteParametersInString(
								NStr("en = 'Please fill the amount in line #%1 of the Products list.'"),
								StringInventory.LineNumber);
				DriveServer.ShowMessageAboutError(
					ThisObject,
					MessageText,
					"Inventory",
					StringInventory.LineNumber,
					"Amount",
					Cancel);
					
			EndIf;
		EndDo;
	EndIf;
	
	If Not Counterparty.DoOperationsByContracts Then
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Contract");
	EndIf;
	
	// Serial numbers
	If Not AdvanceInvoicing Then
		WorkWithSerialNumbers.FillCheckingSerialNumbers(Cancel, Inventory, SerialNumbers, StructuralUnit, ThisObject);
	EndIf;
	
	//Payment calendar
	Amount = Inventory.Total("Amount");
	VATAmount = Inventory.Total("VATAmount");
	PaymentTermsServer.CheckCorrectPaymentCalendar(ThisObject, Cancel, Amount, VATAmount);
	
	If AdvanceInvoicing Then
		If Not IsNew() Then
			AdvanceInvoicingDateCheck(Cancel);
		EndIf;
	EndIf;
	
EndProcedure

Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting.
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Document data initialization.
	PerformanceEstimationClientServer.StartTimeMeasurement("SalesInvoiceDocumentPostingInitialization");
	
	Documents.SalesInvoice.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Preparation of records sets.
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Account for in accounting sections.
	PerformanceEstimationClientServer.StartTimeMeasurement("SalesInvoiceDocumentPostingMovementsCreation");
	
	DriveServer.ReflectInventory(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectSales(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectProductRelease(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectInventoryInWarehouses(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectPaymentCalendar(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectSalesOrders(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectWorkOrders(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectGoodsShippedNotInvoiced(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectGoodsInvoicedNotShipped(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectIncomeAndExpenses(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectIncomeAndExpensesCashMethod(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectUnallocatedExpenses(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectIncomeAndExpensesRetained(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountsReceivable(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectUsingPaymentTermsInDocuments(Ref, Cancel);
	
	// DiscountCards
	DriveServer.ReflectSalesByDiscountCard(AdditionalProperties, RegisterRecords, Cancel);
	
	// AutomaticDiscounts
	DriveServer.FlipAutomaticDiscountsApplied(AdditionalProperties, RegisterRecords, Cancel);

	DriveServer.ReflectAccountingJournalEntries(AdditionalProperties, RegisterRecords, Cancel);

	// Serial numbers
	DriveServer.ReflectTheSerialNumbersOfTheGuarantee(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectTheSerialNumbersBalance(AdditionalProperties, RegisterRecords, Cancel);

	//VAT
	DriveServer.ReflectVATOutput(AdditionalProperties, RegisterRecords, Cancel);
	
	// Record of the records sets.
	PerformanceEstimationClientServer.StartTimeMeasurement("SalesInvoiceDocumentPostingMovementsRecord");
	
	DriveServer.WriteRecordSets(ThisObject);
	
	DriveServer.CreateRecordsInTasksRegisters(ThisObject, Cancel);
	
	DriveServer.ReflectTasksForUpdatingStatuses(Ref, Cancel);
	
	// Subordinate tax invoice
	If Not Cancel AND Not AdditionalProperties.AccountingPolicy.PostVATEntriesBySourceDocuments Then
		If AdditionalProperties.AccountingPolicy.IssueAutomaticallyAgainstSales Then
			WorkWithVAT.CreateTaxInvoice(DocumentWriteMode.Posting, Ref, DeletionMark)
		EndIf;
		WorkWithVAT.SubordinatedTaxInvoiceControl(DocumentWriteMode.Posting, Ref, DeletionMark);
	EndIf;
	
	// Control of occurrence of a negative balance.
	PerformanceEstimationClientServer.StartTimeMeasurement("SalesInvoiceDocumentPostingControl");
	
	Documents.SalesInvoice.RunControl(Ref, AdditionalProperties, Cancel);
	
	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
EndProcedure

Procedure UndoPosting(Cancel)
	
	// Initialization of additional properties for document posting
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Preparation of record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Writing of record sets
	DriveServer.WriteRecordSets(ThisObject);
	
	DriveServer.ReflectTasksForUpdatingStatuses(Ref, Cancel);
	
	// Subordinate tax invoice
	If Not Cancel Then
		WorkWithVAT.SubordinatedTaxInvoiceControl(DocumentWriteMode.UndoPosting, Ref, DeletionMark);
	EndIf;
	
	DriveServer.CreateRecordsInTasksRegisters(ThisObject, Cancel);
	
	// Control of occurrence of a negative balance.
	Documents.SalesInvoice.RunControl(Ref, AdditionalProperties, Cancel, True);
	
EndProcedure

Procedure OnCopy(CopiedObject)
	
	Prepayment.Clear();
	
EndProcedure

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	// Subordinate tax invoice
	If Not Cancel And AdditionalProperties.WriteMode = DocumentWriteMode.Write Then
		WorkWithVAT.SubordinatedTaxInvoiceControl(AdditionalProperties.WriteMode, Ref, DeletionMark);
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

Procedure ClearDeliveryAttributes(FieldsToClear = "")
	
	ClearStructure = New Structure;
	ClearStructure.Insert("ShippingAddress",	Undefined);
	ClearStructure.Insert("ContactPerson",		Undefined);
	ClearStructure.Insert("Incoterms",			Undefined);
	ClearStructure.Insert("DeliveryTimeFrom",	Undefined);
	ClearStructure.Insert("DeliveryTimeTo",		Undefined);
	ClearStructure.Insert("GoodsMarking",		Undefined);
	ClearStructure.Insert("LogisticsCompany",	Undefined);
	
	If IsBlankString(FieldsToClear) Then
		FillPropertyValues(ThisObject, ClearStructure);
	Else
		FillPropertyValues(ThisObject, ClearStructure, FieldsToClear);
	EndIf;
	
EndProcedure

Procedure AdvanceInvoicingDateCheck(Cancel)
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	MIN(GoodsInvoicedNotShipped.Period) AS Period
	|FROM
	|	AccumulationRegister.GoodsInvoicedNotShipped AS GoodsInvoicedNotShipped
	|WHERE
	|	GoodsInvoicedNotShipped.SalesInvoice = &Ref
	|	AND GoodsInvoicedNotShipped.RecordType = VALUE(AccumulationRecordType.Expense)
	|	AND GoodsInvoicedNotShipped.Period <= &Date";
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("Date", Date);
	
	Sel = Query.Execute().Select();
	If Sel.Next() And ValueIsFilled(Sel.Period) Then
		
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'An advance invoice must be dated earlier than its subordinate goods issues are (%1).'"),
			Sel.Period);
		
		CommonUseClientServer.MessageToUser(MessageText, ThisObject, "Date", , Cancel);
		
	EndIf;
	
EndProcedure

Procedure FillSalesRep()
	
	Filter = New Structure("Order", Undefined);
	RowsWithEmptyOrder = Inventory.FindRows(Filter);
	
	If (SalesOrderPosition = Enums.AttributeStationing.InTabularSection
			AND RowsWithEmptyOrder.Count() < Inventory.Count())
		OR (SalesOrderPosition = Enums.AttributeStationing.InHeader
			AND ValueIsFilled(Order)) Then
		
		SalesRep = Undefined;
		If ValueIsFilled(ShippingAddress) Then
			SalesRep = CommonUse.ObjectAttributeValue(ShippingAddress, "SalesRep");
		EndIf;
		If Not ValueIsFilled(SalesRep) Then
			SalesRep = CommonUse.ObjectAttributeValue(Counterparty, "SalesRep");
		EndIf;
		
		For Each CurrentRow In Inventory Do
			If ValueIsFilled(CurrentRow.Order)
				And CurrentRow.Order <> Order Then
				CurrentRow.SalesRep = CommonUse.ObjectAttributeValue(CurrentRow.Order, "SalesRep");
			Else
				CurrentRow.SalesRep = SalesRep;
			EndIf;
		EndDo;
		
	EndIf;
	
EndProcedure

#EndRegion

#EndIf