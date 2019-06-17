#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure Filling(FillingData, StandardProcessing) Export
	
	FillingStrategy = New Map;
	FillingStrategy[Type("Structure")] = "FillByStructure";
	FillingStrategy[Type("DocumentRef.SupplierInvoice")] = "FillBySupplierInvoice";
	
	ObjectFillingDrive.FillDocument(ThisObject, FillingData, FillingStrategy);
	
EndProcedure

Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If ValueIsFilled(Supplier)
		And Not Supplier.DoOperationsByContracts
		And Not ValueIsFilled(SupplierContract) Then
		
		SupplierContract = Supplier.ContractByDefault;
		
	EndIf;
	
	AdditionalProperties.Insert("WriteMode", WriteMode);
	
EndProcedure

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If Not ValueIsFilled(Counterparty) Or Not CommonUse.ObjectAttributeValue(Counterparty, "DoOperationsByContracts") Then
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Contract");
	EndIf;
	
	If Not ValueIsFilled(Supplier) Or Not CommonUse.ObjectAttributeValue(Supplier, "DoOperationsByContracts") Then
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "SupplierContract");
	EndIf;
	
	If Not OtherDutyToExpenses Then
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "OtherDutyGLAccount");
	EndIf;
	
	SearchStructure = New Structure("CommodityGroup");
	InventoryTotals = New Structure;
	
	For Each CGRow In CommodityGroups Do
		
		SearchStructure.CommodityGroup = CGRow.CommodityGroup;
		
		InventoryTotals.Insert("CustomsValue", 0);
		InventoryTotals.Insert("DutyAmount", 0);
		InventoryTotals.Insert("OtherDutyAmount", 0);
		InventoryTotals.Insert("ExciseAmount", 0);
		InventoryTotals.Insert("VATAmount", 0);
		
		InventoryRows = Inventory.FindRows(SearchStructure);
		
		For Each InventoryRow In InventoryRows Do
			
			InventoryTotals.CustomsValue = InventoryTotals.CustomsValue + InventoryRow.CustomsValue;
			InventoryTotals.DutyAmount = InventoryTotals.DutyAmount + InventoryRow.DutyAmount;
			InventoryTotals.OtherDutyAmount = InventoryTotals.OtherDutyAmount + InventoryRow.OtherDutyAmount;
			InventoryTotals.ExciseAmount = InventoryTotals.ExciseAmount + InventoryRow.ExciseAmount;
			InventoryTotals.VATAmount = InventoryTotals.VATAmount + InventoryRow.VATAmount;
			
		EndDo;
		
		MessagePattern = NStr("en = 'The ""%1"" in the line #%2 of the ""Commodity groups"" list does not match the respective inventory total.'");
		
		DocMetadataAttributes = Metadata().TabularSections.CommodityGroups.Attributes;
		
		For Each InvTotal in InventoryTotals Do
			
			If InvTotal.Value <> CGRow[InvTotal.Key] Then
				
				FieldPresentation = DocMetadataAttributes[InvTotal.Key].Presentation();
				ErrorText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, FieldPresentation, Format(CGRow.LineNumber, "NZ=0; NG=0"));
				Field = CommonUseClientServer.PathToTabularSection("CommodityGroups", CGRow.LineNumber, InvTotal.Key);
				CommonUseClientServer.MessageToUser(ErrorText, ThisObject, Field, , Cancel);
				
			EndIf;
			
		EndDo;
		
	EndDo;
	
	InvoicesData = InvoicesDataToBeChecked();
	
	If ValueIsFilled(Date) And InvoicesData.InvoicesDates.Count() Then
		
		MaxInvoiceDate = InvoicesData.InvoicesDates[0].InvoiceDate;
		
		If ValueIsFilled(MaxInvoiceDate) Then
			
			MessagePattern = NStr("en = 'The customs declaration date should be greater than the invoice date (%1).'");
			ErrorText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, Format(MaxInvoiceDate, "DLF=D"));
			CommonUseClientServer.MessageToUser(ErrorText, ThisObject, "Date", , Cancel);
			
		EndIf;
		
	EndIf;
	
	MessagePattern = NStr("en = 'The warehouse in the line #%1 of the ""Inventory"" list does not match the invoice.'");
	
	For Each InventoryRow In InvoicesData.StructuralUnitsMatch Do
		
		ErrorText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, Format(InventoryRow.LineNumber, "NZ=0; NG=0"));
		Field = CommonUseClientServer.PathToTabularSection("Inventory", InventoryRow.LineNumber, "StructuralUnit");
		CommonUseClientServer.MessageToUser(ErrorText, ThisObject, Field, , Cancel);
		
	EndDo;
	
	If ValueIsFilled(VATIsDue) Then
		
		RegisteredForVAT = InformationRegisters.AccountingPolicy.GetAccountingPolicy(Date, Company).RegisteredForVAT;
		
		If Not RegisteredForVAT And VATIsDue <> Enums.VATDueOnCustomsClearance.OnTheSupply Then
			
			ErrorText = NStr("en = 'VAT return is not applicable for non VAT-registered entities.'");
			
			CommonUseClientServer.MessageToUser(ErrorText, ThisObject, "VATIsDue", , Cancel);
			
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting.
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Document data initialization.
	Documents.CustomsDeclaration.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Preparation of records sets.
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	DriveServer.ReflectGoodsAwaitingCustomsClearance(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectInventory(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectIncomeAndExpenses(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectMiscellaneousPayable(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectVATInput(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectVATOutput(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingJournalEntries(AdditionalProperties, RegisterRecords, Cancel);
	
	// Offline registers
	DriveServer.ReflectLandedCosts(AdditionalProperties, RegisterRecords, Cancel);
	
	// Record of the records sets.
	DriveServer.WriteRecordSets(ThisObject);
	
	// Control of occurrence of a negative balance.
	Documents.CustomsDeclaration.RunControl(Ref, AdditionalProperties, Cancel);
	
	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
EndProcedure

Procedure UndoPosting(Cancel)
	
	// Initialization of additional properties for document posting
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Preparation of record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Writing of record sets
	DriveServer.WriteRecordSets(ThisObject);
	
	// Control of occurrence of a negative balance.
	Documents.CustomsDeclaration.RunControl(Ref, AdditionalProperties, Cancel, True);
	
EndProcedure

#EndRegion

#Region Private

#Region DocumentFillingProcedures

Procedure FillByStructure(FillingData) Export
	
	If FillingData.Property("ArrayOfSupplierInvoices") Then
		FillBySupplierInvoice(FillingData);
	EndIf;
	
EndProcedure

Procedure FillBySupplierInvoice(FillingData) Export
	
	// Document basis and document setting.
	If TypeOf(FillingData) = Type("Structure") AND FillingData.Property("ArrayOfSupplierInvoices") Then
		InvoicesArray = FillingData.ArrayOfSupplierInvoices;
	Else
		InvoicesArray = New Array;
		InvoicesArray.Add(FillingData.Ref);
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	SupplierInvoiceHeader.Company AS Company,
	|	SupplierInvoiceHeader.Counterparty AS Counterparty,
	|	SupplierInvoiceHeader.Contract AS Contract,
	|	SupplierInvoiceHeader.StructuralUnit AS StructuralUnit,
	|	SupplierInvoiceHeader.VATTaxation AS VATTaxation,
	|	SupplierInvoiceHeader.DocumentCurrency AS DocumentCurrency,
	|	SupplierInvoiceHeader.Ref AS Ref,
	|	SupplierInvoiceHeader.Posted AS Posted
	|INTO TT_SupplierInvoiceHeader
	|FROM
	|	Document.SupplierInvoice AS SupplierInvoiceHeader
	|WHERE
	|	SupplierInvoiceHeader.Ref IN(&InvoicesArray)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_SupplierInvoiceHeader.Company AS Company,
	|	TT_SupplierInvoiceHeader.Counterparty AS Supplier,
	|	TT_SupplierInvoiceHeader.Contract AS SupplierContract,
	|	TT_SupplierInvoiceHeader.StructuralUnit AS StructuralUnit,
	|	TT_SupplierInvoiceHeader.VATTaxation AS VATTaxation,
	|	TT_SupplierInvoiceHeader.Ref AS Ref,
	|	TT_SupplierInvoiceHeader.Posted AS Posted
	|FROM
	|	TT_SupplierInvoiceHeader AS TT_SupplierInvoiceHeader
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Inventory.Products AS Products,
	|	Inventory.Characteristic AS Characteristic,
	|	Inventory.Batch AS Batch,
	|	Inventory.Invoice AS Invoice,
	|	Inventory.Quantity AS Quantity,
	|	Inventory.CommodityGroup AS CommodityGroup
	|INTO TT_Inventory
	|FROM
	|	&Inventory AS Inventory
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CommodityGroups.CommodityGroup AS CommodityGroup
	|INTO TT_CommodityGroups
	|FROM
	|	&CommodityGroups AS CommodityGroups
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ISNULL(MAX(CommodityGroups.CommodityGroup), 0) AS CommodityGroup
	|FROM
	|	(SELECT
	|		TT_CommodityGroups.CommodityGroup AS CommodityGroup
	|	FROM
	|		TT_CommodityGroups AS TT_CommodityGroups
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		TT_Inventory.CommodityGroup
	|	FROM
	|		TT_Inventory AS TT_Inventory) AS CommodityGroups
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	GoodsBalances.Products AS Products,
	|	GoodsBalances.Characteristic AS Characteristic,
	|	GoodsBalances.Batch AS Batch,
	|	GoodsBalances.Invoice AS Invoice,
	|	SUM(GoodsBalances.Quantity) AS Quantity
	|INTO TT_GoodsBalances
	|FROM
	|	(SELECT
	|		GoodsBalances.Products AS Products,
	|		GoodsBalances.Characteristic AS Characteristic,
	|		GoodsBalances.Batch AS Batch,
	|		GoodsBalances.SupplierInvoice AS Invoice,
	|		GoodsBalances.QuantityBalance AS Quantity
	|	FROM
	|		AccumulationRegister.GoodsAwaitingCustomsClearance.Balance(
	|				,
	|				SupplierInvoice IN
	|					(SELECT
	|						TT_SupplierInvoiceHeader.Ref
	|					FROM
	|						TT_SupplierInvoiceHeader)) AS GoodsBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		Inventory.Products,
	|		Inventory.Characteristic,
	|		Inventory.Batch,
	|		Inventory.Invoice,
	|		-Inventory.Quantity
	|	FROM
	|		TT_Inventory AS Inventory
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		GoodsRecords.Products,
	|		GoodsRecords.Characteristic,
	|		GoodsRecords.Batch,
	|		GoodsRecords.SupplierInvoice,
	|		CASE
	|			WHEN GoodsRecords.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN ISNULL(GoodsRecords.Quantity, 0)
	|			ELSE -ISNULL(GoodsRecords.Quantity, 0)
	|		END
	|	FROM
	|		AccumulationRegister.GoodsAwaitingCustomsClearance AS GoodsRecords
	|	WHERE
	|		GoodsRecords.Recorder = &Ref) AS GoodsBalances
	|
	|GROUP BY
	|	GoodsBalances.Products,
	|	GoodsBalances.Characteristic,
	|	GoodsBalances.Batch,
	|	GoodsBalances.Invoice
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_SupplierInvoiceHeader.Ref AS Ref,
	|	TT_SupplierInvoiceHeader.StructuralUnit AS StructuralUnit,
	|	SupplierInvoiceInventory.Products AS Products,
	|	SupplierInvoiceInventory.Characteristic AS Characteristic,
	|	SupplierInvoiceInventory.Batch AS Batch,
	|	SUM(SupplierInvoiceInventory.Quantity * ISNULL(UOM.Factor, 1)) AS Quantity,
	|	SUM(CASE
	|			WHEN TT_SupplierInvoiceHeader.DocumentCurrency = &FunctionalCurrency
	|				THEN SupplierInvoiceInventory.Total
	|			WHEN FCRate.ExchangeRate = 0
	|					OR DocRate.Multiplicity = 0
	|				THEN 0
	|			ELSE SupplierInvoiceInventory.Total * DocRate.ExchangeRate * FCRate.Multiplicity / FCRate.ExchangeRate / DocRate.Multiplicity
	|		END) AS Total
	|INTO TT_AmountsData
	|FROM
	|	TT_SupplierInvoiceHeader AS TT_SupplierInvoiceHeader
	|		INNER JOIN Document.SupplierInvoice.Inventory AS SupplierInvoiceInventory
	|		ON TT_SupplierInvoiceHeader.Ref = SupplierInvoiceInventory.Ref
	|		LEFT JOIN Catalog.UOM AS UOM
	|		ON (SupplierInvoiceInventory.MeasurementUnit = UOM.Ref)
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&RatesDate, ) AS DocRate
	|		ON TT_SupplierInvoiceHeader.DocumentCurrency = DocRate.Currency
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&RatesDate, ) AS FCRate
	|		ON (FCRate.Currency = &FunctionalCurrency)
	|
	|GROUP BY
	|	SupplierInvoiceInventory.Products,
	|	SupplierInvoiceInventory.Characteristic,
	|	SupplierInvoiceInventory.Batch,
	|	TT_SupplierInvoiceHeader.StructuralUnit,
	|	TT_SupplierInvoiceHeader.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	GoodsBalances.Products AS Products,
	|	GoodsBalances.Characteristic AS Characteristic,
	|	GoodsBalances.Batch AS Batch,
	|	GoodsBalances.Invoice AS Invoice,
	|	GoodsBalances.Quantity AS Quantity,
	|	CASE
	|		WHEN ISNULL(TT_AmountsData.Quantity, 0) = 0
	|			THEN 0
	|		ELSE CAST(GoodsBalances.Quantity * ISNULL(TT_AmountsData.Total, 0) / TT_AmountsData.Quantity AS NUMBER(15, 2))
	|	END AS CustomsValue,
	|	TT_AmountsData.StructuralUnit AS StructuralUnit,
	|	CatalogProducts.CountryOfOrigin AS Origin,
	|	CatalogProducts.HSCode AS HSCode
	|FROM
	|	TT_GoodsBalances AS GoodsBalances
	|		LEFT JOIN Catalog.Products AS CatalogProducts
	|		ON GoodsBalances.Products = CatalogProducts.Ref
	|		LEFT JOIN TT_AmountsData AS TT_AmountsData
	|		ON GoodsBalances.Invoice = TT_AmountsData.Ref
	|			AND GoodsBalances.Products = TT_AmountsData.Products
	|			AND GoodsBalances.Characteristic = TT_AmountsData.Characteristic
	|			AND GoodsBalances.Batch = TT_AmountsData.Batch
	|WHERE
	|	GoodsBalances.Quantity > 0
	|TOTALS
	|	SUM(CustomsValue)
	|BY
	|	Origin";
	
	Query.SetParameter("InvoicesArray", InvoicesArray);
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("Inventory", Inventory);
	Query.SetParameter("CommodityGroups", CommodityGroups);
	Query.SetParameter("FunctionalCurrency", Constants.FunctionalCurrency.Get());
	If IsNew() Then
		Query.SetParameter("RatesDate", CurrentDate());
	Else
		Query.SetParameter("RatesDate", Date);
	EndIf;
	
	Results = Query.ExecuteBatch();
	
	SelHeader = Results[1].Select();
	While SelHeader.Next() Do
		
		If Not SelHeader.Posted Then
			Raise NStr("en = 'Please select a posted document.'");
		EndIf;
		If Not SelHeader.VATTaxation = Enums.VATTaxationTypes.ForExport Then
			Raise NStr("en = 'Please select a document with ""Zero rate"" tax category.'");
		EndIf;
		
	EndDo;
	FillPropertyValues(ThisObject, SelHeader, , "Ref, Posted");
	
	SelCommodityGroups = Results[4].Select();
	If SelCommodityGroups.Next() Then
		MaxCommodityGruop = SelCommodityGroups.CommodityGroup;
	Else
		MaxCommodityGruop = 0;
	EndIf;
	
	SelOrigins = Results[7].Select(QueryResultIteration.ByGroups);
	While SelOrigins.Next() Do
		
		MaxCommodityGruop = MaxCommodityGruop + 1;
		
		NewCommodityGroupsRow = CommodityGroups.Add();
		NewCommodityGroupsRow.Origin = SelOrigins.Origin;
		NewCommodityGroupsRow.CustomsValue = SelOrigins.CustomsValue;
		NewCommodityGroupsRow.CommodityGroup = MaxCommodityGruop;
		
		SelInventory = SelOrigins.Select();
		
		While SelInventory.Next() Do
			
			If SelInventory.Quantity > 0 Then
			
				NewInventoryRow = Inventory.Add();
				FillPropertyValues(NewInventoryRow, SelInventory);
				NewInventoryRow.CommodityGroup = MaxCommodityGruop;
				
			EndIf;
			
		EndDo;
		
	EndDo;
	
	GLAccountsInDocuments.FillTabSectionFromProductGLAccounts(ThisObject, FillingData);
	
EndProcedure

#EndRegion

Function InvoicesDataToBeChecked()
	
	Query = New Query;
	
	Query.Text =
	"SELECT
	|	Inventory.LineNumber AS LineNumber,
	|	Inventory.Invoice AS Invoice,
	|	Inventory.StructuralUnit AS StructuralUnit
	|INTO TT_Inventory
	|FROM
	|	&Inventory AS Inventory
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_Inventory.LineNumber AS LineNumber,
	|	TT_Inventory.Invoice AS Invoice,
	|	TT_Inventory.StructuralUnit AS StructuralUnit,
	|	SupplierInvoice.StructuralUnit AS InvoiceStructuralUnit,
	|	SupplierInvoice.Date AS InvoiceDate
	|INTO TT_InventoryWithData
	|FROM
	|	TT_Inventory AS TT_Inventory
	|		INNER JOIN Document.SupplierInvoice AS SupplierInvoice
	|		ON TT_Inventory.Invoice = SupplierInvoice.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_InventoryWithData.LineNumber AS LineNumber
	|FROM
	|	TT_InventoryWithData AS TT_InventoryWithData
	|WHERE
	|	TT_InventoryWithData.StructuralUnit <> TT_InventoryWithData.InvoiceStructuralUnit
	|	AND TT_InventoryWithData.StructuralUnit <> VALUE(Catalog.BusinessUnits.EmptyRef)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MAX(TT_InventoryWithData.InvoiceDate) AS InvoiceDate
	|FROM
	|	TT_InventoryWithData AS TT_InventoryWithData
	|WHERE
	|	TT_InventoryWithData.InvoiceDate > &Date";
	
	Query.SetParameter("Inventory", Inventory);
	Query.SetParameter("Date", Date);
	
	QueryResults = Query.ExecuteBatch();
	
	Result = New Structure;
	Result.Insert("StructuralUnitsMatch", QueryResults[2].Unload());
	Result.Insert("InvoicesDates", QueryResults[3].Unload());
	
	Return Result;
	
EndFunction

#EndRegion

#EndIf