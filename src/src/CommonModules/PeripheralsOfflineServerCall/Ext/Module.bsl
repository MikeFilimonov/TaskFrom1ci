
#Region ServiceProceduresAndFunctions

// Calculates VAT amount from the amount depending on the inclusion of VAT in the price
//
// Amount           - Number - Amount from which it is required to calculate VAT amount 
// VATRate          - CatalogRef.VATRates - VAT rate
// PriceIncludesVAT - Boolean - Sign of VAT inclusion to the price
//
Function CalculateVATSUM(Amount, VATRate, PriceIncludesVAT = True)
	
	VATPercent = VATRate.Rate / 100;
	
	If PriceIncludesVAT Then
		VATAmount = Amount * VATPercent / (VATPercent + 1);
	Else
		VATAmount = Amount * VATPercent;
	EndIf;
	
	Return VATAmount;
	
EndFunction

// The function receives the device parameters
Function GetDeviceParameters(Device) Export
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	Peripherals.ExchangeRule AS ExchangeRule,
	|	Peripherals.InfobaseNode AS InfobaseNode,
	|	ISNULL(Peripherals.ExchangeRule.StructuralUnit.RetailPriceKind, VALUE(Catalog.PriceTypes.EmptyRef)) AS PriceKind,
	|	ISNULL(Peripherals.ExchangeRule.StructuralUnit, VALUE(Catalog.BusinessUnits.EmptyRef)) AS StructuralUnit,
	|	ISNULL(Peripherals.ExchangeRule.MaximumCode, 0) AS MaximumCode,
	|	ISNULL(Peripherals.ExchangeRule.WeightProductPrefix, 0) AS WeightProductPrefix,
	|	ISNULL(Peripherals.ExchangeRule.ImportChanges, True) AS ImportChanges,
	|	Peripherals.EquipmentType AS EquipmentType
	|FROM
	|	Catalog.Peripherals AS Peripherals
	|WHERE
	|	Peripherals.Ref = &Device";
	
	Query.SetParameter("Device", Device);
	
	Result = Query.Execute();
	Selection = Result.Select();
	
	If Not Selection.Next() Then
		Return Undefined;
	EndIf;
	
	ReturnValue = New Structure;
	ReturnValue.Insert("ExchangeRule",          Selection.ExchangeRule);
	ReturnValue.Insert("InfobaseNode", Selection.InfobaseNode);
	ReturnValue.Insert("StructuralUnit",                  Selection.StructuralUnit);
	ReturnValue.Insert("PriceKind",                Selection.PriceKind);
	ReturnValue.Insert("EquipmentType",        Selection.EquipmentType);
	ReturnValue.Insert("MaximumCode",        Selection.MaximumCode);
	ReturnValue.Insert("WeightProductPrefix",  String(Selection.WeightProductPrefix));
	ReturnValue.Insert("ImportChanges",     Selection.ImportChanges);
	
	Return ReturnValue;
	
EndFunction

// The function removes registration of changes for the device.
//
// Parameters:
//  Device - <CatalogRef.Peripherals>
//
// Returns:
//  No
//
Procedure DeleteChangeRecords(Device) Export
	
	SetPrivilegedMode(True);
	
	Query = New Query(
	"SELECT
	|	Peripherals.InfobaseNode AS InfobaseNode
	|FROM
	|	Catalog.Peripherals AS Peripherals
	|WHERE
	|	Peripherals.Ref = &Device");
	
	Query.SetParameter("Device", Device);
	
	Result = Query.Execute();
	Selection = Result.Select();
	
	BeginTransaction();
	
	While Selection.Next() Do
		ExchangePlans.DeleteChangeRecords(Selection.InfobaseNode);
	EndDo;
	
	CommitTransaction();
	
	SetPrivilegedMode(False);
	
EndProcedure

// Function registers a change for device.
//
// Parameters:
//  Device - <CatalogRef.Peripherals>
//
// Returns:
//  No
//
Procedure RecordChanges(Device) Export
	
	SetPrivilegedMode(True);
	
	Query = New Query(
	"SELECT
	|	Peripherals.InfobaseNode AS InfobaseNode,
	|	ProductsCodesPeripheralOffline.Code AS Code,
	|	ProductsCodesPeripheralOffline.ExchangeRule AS ExchangeRule
	|FROM
	|	Catalog.Peripherals AS Peripherals
	|		LEFT JOIN InformationRegister.ProductsCodesPeripheralOffline AS ProductsCodesPeripheralOffline
	|		ON Peripherals.ExchangeRule = ProductsCodesPeripheralOffline.ExchangeRule
	|WHERE
	|	ProductsCodesPeripheralOffline.Used
	|	AND Peripherals.Ref = &Device");
	
	Query.SetParameter("Device", Device);
	
	Result = Query.Execute();
	Selection = Result.Select();
	
	BeginTransaction();
	
	Set = InformationRegisters.ProductsCodesPeripheralOffline.CreateRecordSet();
	While Selection.Next() Do
		
		Set.Filter.ExchangeRule.Value = Selection.ExchangeRule;
		Set.Filter.ExchangeRule.Use = True;
		
		Set.Filter.Code.Value = Selection.Code;
		Set.Filter.Code.Use = True;
		
		ExchangePlans.RecordChanges(Selection.InfobaseNode, Set);
		
	EndDo;
	
	CommitTransaction();
	
	SetPrivilegedMode(False);
	
EndProcedure

// The procedure is called when clearing products in the device.
// Writes information to the exchange plan node.
//
// Parameters:
//  Device       - <CatalogRef.Peripherals>
//  CompletedSuccessfully - <Boolean > Shows that the operation is successfully completed
//
// Returns:
//  No
//
Procedure OnProductsClearingInDevice(Device, CompletedSuccessfully = True) Export
	
	SetPrivilegedMode(True);
	
	Query = New Query(
	"SELECT
	|	Peripherals.InfobaseNode AS InfobaseNode
	|FROM
	|	Catalog.Peripherals AS Peripherals
	|WHERE
	|	Peripherals.Ref = &Device");
	
	Query.SetParameter("Device", Device);
	
	Result = Query.Execute();
	Selection = Result.Select();
	
	BeginTransaction();
	
	While Selection.Next() Do
		NodeObject = Selection.InfobaseNode.GetObject();
		NodeObject.ExportDate      = CurrentDate();
		NodeObject.ExportCompleted = CompletedSuccessfully;
		NodeObject.Write();
	EndDo;
	
	RecordChanges(Device);
	
	CommitTransaction();
	
	SetPrivilegedMode(False);
	
EndProcedure

// The procedure is called when importing products to the device.
// Writes information to the exchange plan node.
//
// Parameters:
//  Device       - <CatalogRef.Peripherals>
//  CompletedSuccessfully - <Boolean > Shows that the operation is successfully completed
//
// Returns:
//  No
//
Procedure OnProductsExportToDevice(Device, StructureData, CompletedSuccessfully = True) Export
	
	SetPrivilegedMode(True);
	
	Query = New Query(
	"SELECT
	|	Peripherals.InfobaseNode                             AS InfobaseNode,
	|	Peripherals.ExchangeRule                                      AS ExchangeRule,
	|	ISNULL(Peripherals.ExchangeRule.ImportChanges, True) AS ImportChanges
	|FROM
	|	Catalog.Peripherals AS Peripherals
	|WHERE
	|	Peripherals.Ref = &Device");
	
	Query.SetParameter("Device", Device);
	
	Result = Query.Execute();
	Selection = Result.Select();
	
	BeginTransaction();
	
	While Selection.Next() Do
		
		If CompletedSuccessfully AND StructureData <> Undefined Then
			
			If Selection.ImportChanges Then
				
				Set = InformationRegisters.ProductsCodesPeripheralOffline.CreateRecordSet();
				For Each TSRow In StructureData.Data Do
					
					Set.Filter.ExchangeRule.Value = Selection.ExchangeRule;
					Set.Filter.ExchangeRule.Use = True;
					
					Set.Filter.Code.Value = TSRow.Code;
					Set.Filter.Code.Use = True;
					
					ExchangePlans.DeleteChangeRecords(Selection.InfobaseNode, Set);
					
				EndDo;
				
			Else
				
				ExchangePlans.DeleteChangeRecords(Selection.InfobaseNode);
				
			EndIf;
			
		EndIf;
		
		NodeObject = Selection.InfobaseNode.GetObject();
		NodeObject.ExportDate      = CurrentDate();
		NodeObject.ExportCompleted = CompletedSuccessfully;
		NodeObject.Write();
		
	EndDo;
	
	CommitTransaction();
	
	SetPrivilegedMode(False);
	
EndProcedure

// The procedure is called when exporting a report on retail sales from the device.
// Writes information to the exchange plan node. Creates a report on retail sales.
//
// Parameters:
//  Device       - <CatalogRef.Peripherals>
//  CompletedSuccessfully - <Boolean > Shows that the operation is successfully completed
//
// Returns:
//  No
//
Function WhenImportingReportAboutRetailSales(Device, ArrayOfData) Export
	
	SetPrivilegedMode(True);
	
	Query = New Query(
	"SELECT TOP 1
	|	CatalogPeripherals.ExchangeRule AS ExchangeRule,
	|	CatalogPeripherals.InfobaseNode AS InfobaseNode,
	|	CashRegisters.Ref AS CashCR,
	|	CashRegisters.CashCurrency AS Currency,
	|	CatalogPeripherals.ExchangeRule.StructuralUnit AS StructuralUnit,
	|	CatalogPeripherals.ExchangeRule.StructuralUnit.RetailPriceKind AS PriceKind,
	|	CatalogPeripherals.ExchangeRule.StructuralUnit.RetailPriceKind.PriceIncludesVAT AS PriceIncludesVAT,
	|	CashRegisters.Owner AS Company
	|FROM
	|	Catalog.Peripherals AS CatalogPeripherals
	|		INNER JOIN Catalog.CashRegisters AS CashRegisters
	|		ON (CashRegisters.Peripherals = CatalogPeripherals.Ref)
	|WHERE
	|	CatalogPeripherals.Ref = &Device");
	
	Query.SetParameter("Device", Device);
	
	Result = Query.Execute();
	Selection = Result.Select();
	
	If Not Selection.Next() Then
		Return Undefined;
	EndIf;
	
	ProductsTable = New ValueTable;
	ProductsTable.Columns.Add("Code",        New TypeDescription("Number"));
	ProductsTable.Columns.Add("Price",       New TypeDescription("Number"));
	ProductsTable.Columns.Add("Quantity", New TypeDescription("Number"));
	ProductsTable.Columns.Add("Discount",     New TypeDescription("Number"));
	ProductsTable.Columns.Add("Amount",      New TypeDescription("Number"));
	
	For Each TSRow In ArrayOfData Do
		NewRow = ProductsTable.Add();
		NewRow.Code        = TSRow.Code;
		NewRow.Price       = TSRow.Price;
		NewRow.Quantity = TSRow.Quantity;
		NewRow.Discount     = TSRow.Discount;
		NewRow.Amount      = TSRow.Amount;
	EndDo;
	
	Query = New Query(
	"SELECT
	|	Products.Code AS Code,
	|	Products.Price AS Price,
	|	Products.Quantity AS Quantity,
	|	Products.Discount AS Discount,
	|	Products.Amount AS Amount
	|INTO Products
	|FROM
	|	&ValueTable AS Products
	|;
	|	
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ISNULL(ProductsCodesPeripheralOffline.Products, VALUE(Catalog.Products.EmptyRef))                 AS Products,
	|	ISNULL(ProductsCodesPeripheralOffline.Characteristic, VALUE(Catalog.ProductsCharacteristics.EmptyRef)) AS Characteristic,
	|	ISNULL(ProductsCodesPeripheralOffline.Batch, VALUE(Catalog.ProductsBatches.EmptyRef))                 AS Batch,
	|	ISNULL(ProductsCodesPeripheralOffline.MeasurementUnit, VALUE(Catalog.UOM.EmptyRef))         AS MeasurementUnit,
	|	
	|	Products.Quantity                                                                                 AS PackingQuantity,
	|	ISNULL(ProductsCodesPeripheralOffline.MeasurementUnit.Factor, 1) * Products.Quantity AS Quantity,
	|	Products.Price                                                                                       AS Price,
	|	Products.Amount                                                                                      AS Amount,
	|	Products.Discount                                                                                     AS ManualDiscountPercentage,
	|	ProductsCodesPeripheralOffline.Products.VATRate                                AS VATRate
	|FROM
	|	Products AS Products
	|		LEFT JOIN InformationRegister.ProductsCodesPeripheralOffline AS ProductsCodesPeripheralOffline
	|		ON Products.Code = ProductsCodesPeripheralOffline.Code
	|			AND (ProductsCodesPeripheralOffline.ExchangeRule = &ExchangeRule)");
	
	Query.SetParameter("ExchangeRule",   Selection.ExchangeRule);
	Query.SetParameter("ValueTable", ProductsTable);
	
	ReportAboutRetailSalesObject = Documents.ShiftClosure.CreateDocument();
	ReportAboutRetailSalesObject.Date					= CurrentDate();
	ReportAboutRetailSalesObject.CashCRSessionStart		= BegOfDay(ReportAboutRetailSalesObject.Date);
	ReportAboutRetailSalesObject.CashCRSessionEnd		= EndOfDay(ReportAboutRetailSalesObject.Date);
	ReportAboutRetailSalesObject.DocumentCurrency		= Selection.Currency;
	ReportAboutRetailSalesObject.PriceKind				= Selection.PriceKind;
	ReportAboutRetailSalesObject.CashCR					= Selection.CashCR;
	ReportAboutRetailSalesObject.Comment				= NStr("en = 'It is imported from offline cash register:'") + " " + Device;
	ReportAboutRetailSalesObject.VATTaxation			= DriveServer.VATTaxation(Selection.Company, CurrentDate());
	ReportAboutRetailSalesObject.CashCRSessionStatus	= Enums.ShiftClosureStatus.Closed;
	ReportAboutRetailSalesObject.Item					= Catalogs.CashFlowItems.PaymentFromCustomers;

	ReportAboutRetailSalesObject.Company				= Selection.Company;
	ReportAboutRetailSalesObject.Responsible			= DriveReUse.GetValueByDefaultUser(Users.CurrentUser(), "MainResponsible");
	ReportAboutRetailSalesObject.PositionResponsible	= Enums.AttributeStationing.InHeader;
	ReportAboutRetailSalesObject.Department				= DriveReUse.GetValueByDefaultUser(Users.CurrentUser(), "MainDepartment");
	
	If Not ValueIsFilled(ReportAboutRetailSalesObject.Department) Then
		ReportAboutRetailSalesObject.Department = Catalogs.BusinessUnits.MainDepartment;
	EndIf;
	
	ReportAboutRetailSalesObject.StructuralUnit		= Selection.StructuralUnit;
	ReportAboutRetailSalesObject.AmountIncludesVAT	= Selection.PriceIncludesVAT;
	
	SelectionByProducts = Query.Execute().Select();
	While SelectionByProducts.Next() Do
		
		NewRow = ReportAboutRetailSalesObject.Inventory.Add();
		NewRow.Products        = SelectionByProducts.Products;
		NewRow.Characteristic      = SelectionByProducts.Characteristic;
		NewRow.Batch              = SelectionByProducts.Batch;
		NewRow.MeasurementUnit    = SelectionByProducts.MeasurementUnit;
		If Not ValueIsFilled(NewRow.MeasurementUnit) Then
			NewRow.MeasurementUnit = NewRow.Products.MeasurementUnit;
		EndIf;
		NewRow.Quantity          = SelectionByProducts.PackingQuantity;
		NewRow.Amount               = SelectionByProducts.Amount;
		NewRow.Price                = SelectionByProducts.Price;
		NewRow.VATRate           = SelectionByProducts.VATRate;
		NewRow.DiscountMarkupPercent = SelectionByProducts.ManualDiscountPercentage;
		NewRow.VATAmount            = CalculateVATSUM(NewRow.Amount, NewRow.VATRate, Selection.PriceIncludesVAT);
		NewRow.Total = NewRow.Amount + ?(ReportAboutRetailSalesObject.AmountIncludesVAT, 0, NewRow.VATAmount);
		
	EndDo;
	
	ReportAboutRetailSalesObject.DocumentAmount = ReportAboutRetailSalesObject.Inventory.Total("TotalAmount");
	
	Try
		If ReportAboutRetailSalesObject.CheckFilling() Then
			ReportAboutRetailSalesObject.Write(DocumentWriteMode.Posting);
		Else
			ReportAboutRetailSalesObject.Write(DocumentWriteMode.Write);
		EndIf;
	Except
		ReportAboutRetailSalesObject.Write(DocumentWriteMode.Write);
	EndTry;
	
	NodeObject = Selection.InfobaseNode.GetObject();
	NodeObject.ImportDate = CurrentDate();
	NodeObject.Write();
	
	SetPrivilegedMode(False);
	
	Return ReportAboutRetailSalesObject.Ref;
	
EndFunction

#EndRegion

#Region WorkWithRegisterCodesOfPeripheralProducts

// The function returns a maximum product code
// in register ProductsCodesPeripheralOffline for the specified exchange rule.
//
// Parameters:
//  ExchangeRule - <CatalogRef.ExchangeRulesWithPeripheralsOffline>
//
// Returns:
//  <Number> - Maximum product code for the specified exchange rule.
//
Function GetMaximumCode(ExchangeRule) Export
	
	Query = New Query(
	"SELECT
	|	ISNULL(MAX(ProductsCodesPeripheralOffline.Code), 0) AS Code
	|FROM
	|	InformationRegister.ProductsCodesPeripheralOffline AS ProductsCodesPeripheralOffline
	|WHERE
	|	ProductsCodesPeripheralOffline.ExchangeRule = &ExchangeRule");
	
	Query.SetParameter("ExchangeRule", ExchangeRule);
	
	Result = Query.Execute();
	Selection = Result.Select();
	
	If Selection.Next() Then
		Return Selection.Code;
	Else
		Return 0;
	EndIf;
	
EndFunction

// The function returns a table of free product
// codes in register ProductsCodesPeripheralOffline for the specified exchange rule. Free codes are those for which
// products are not specified.
//
// Parameters:
//  ExchangeRule - <CatalogRef.ExchangeRulesWithPeripheralsOffline>
//  Quantity - <Number> - Required quantity of free codes.
//
// Returns:
//  <ValueTable> - Table of free product codes.
//
Function GetFreeCodes(ExchangeRule, Quantity = 0) Export
	
	Query = New Query(
	"SELECT //TOP
	|	ProductsCodesPeripheralOffline.Code AS Code
	|FROM
	|	InformationRegister.ProductsCodesPeripheralOffline AS ProductsCodesPeripheralOffline
	|WHERE
	|	ProductsCodesPeripheralOffline.ExchangeRule = &ExchangeRule
	|	AND ProductsCodesPeripheralOffline.Products = VALUE(Catalog.Products.EmptyRef)
	|
	|ORDER BY
	|	ProductsCodesPeripheralOffline.Code Asc");
	
	Query.SetParameter("ExchangeRule", ExchangeRule);
	
	Query.Text = StrReplace(Query.Text, "//TOP", ?(Quantity = 0,"","TOP" + " " + Format(Quantity, "NG=0")));
	
	Return Query.Execute().Unload();
	
EndFunction

// The procedure writes a
// code for the specified exchange rule and corresponding parameters of products to register ProductsCodesPeripheralOffline
//
// Parameters:
//  ExchangeRule - <RefCatalog.ExchangeRulesWithPeripheralsOffline>
//  Data         - <Structure> - Structure that contains fields: Products, Characteristic, MeasurementUnit 
//  Code         - <Number> - Product code by an exchange rule.
//  Used         - <Number> - Shows that the product corresponds to the filter set in the exchange rule.
//
// Returns:
//  No
//
Procedure WriteCode(Data, ExchangeRule, Code, Used) Export
	
	RecordManager = InformationRegisters.ProductsCodesPeripheralOffline.CreateRecordManager();
	
	FillPropertyValues(RecordManager, Data);
	
	RecordManager.Code             = Code;
	RecordManager.ExchangeRule   = ExchangeRule;
	RecordManager.Used    = Used;
	
	RecordManager.Write();

EndProcedure

// The procedure clears parameters of products for the record
// that corresponds to a code within an exchange rule in register ProductsCodesPeripheralOffline.
// This record becomes free.
//
// Parameters:
//  ExchangeRule - <RefCatalog.ExchangeRulesWithPeripheralsOffline>
//  Code         - <Number> - Product code by an exchange rule.
//
// Returns:
//  No
//
Procedure DeleteCode(ExchangeRule, Code) Export
	
	WriteCode(New Structure("Products, Characteristic, Batch, MeasurementUnit"), ExchangeRule, Code , False);
	
EndProcedure

// Procedure updates the records in the ProductsCodesPeripheralOffline register
// in compliance with the rule of exchange. Records that do not
// correspond to the rule filter become unused. New records that correspond to the filter are added if they are found.
//
// Parameters:
//  ExchangeRule - <CatalogRef.ExchangeRulesWithPeripheralsOffline>
//
// Returns:
//  No
//
Procedure RefreshProductProduct(ExchangeRule) Export
	
	SetPrivilegedMode(True);
	
	Query = New Query(
	"SELECT
	|	ExchangeWithOfflinePeripheralsRules.StructuralUnit.RetailPriceKind AS PriceKind,
	|	ExchangeWithOfflinePeripheralsRules.WeighingUnits AS WeighingUnits,
	|	ExchangeWithOfflinePeripheralsRules.DataCompositionSettings AS DataCompositionSettings,
	|	ExchangeWithOfflinePeripheralsRules.PeripheralsType AS PeripheralsType,
	|	ExchangeWithOfflinePeripheralsRules.WeightProductPrefix AS WeightProductPrefix
	|FROM
	|	Catalog.ExchangeWithOfflinePeripheralsRules AS ExchangeWithOfflinePeripheralsRules
	|WHERE
	|	ExchangeWithOfflinePeripheralsRules.Ref = &ExchangeRule");
	
	Query.SetParameter("ExchangeRule", ExchangeRule);
	
	Selection = Query.Execute().Select();
	If Not Selection.Next() Then
		Return;
	EndIf;
	
	If Selection.PeripheralsType = Enums.PeripheralTypes.CashRegistersOffline Then
		DataCompositionSchema = Catalogs.ExchangeWithOfflinePeripheralsRules.GetTemplate("CRProductCodesUpdate");
	ElsIf Selection.PeripheralsType = Enums.PeripheralTypes.LabelsPrintingScales Then
		DataCompositionSchema = Catalogs.ExchangeWithOfflinePeripheralsRules.GetTemplate("PLUProductCodesUpdate");
	Else
		Raise NStr("en = 'Incorrect peripherals type'");
	EndIf;
	
	// Preparation of layout compositing of data composition, importing settings
	Composer = New DataCompositionSettingsComposer;
	Composer.Initialize(New DataCompositionAvailableSettingsSource(DataCompositionSchema));
	
	Composer.LoadSettings(Selection.DataCompositionSettings.Get());
	Composer.Refresh(DataCompositionSettingsRefreshMethod.CheckAvailability);
	
	// Filling out the report structure and selected fields.
	Composer.Settings.Structure.Clear();
	
	GroupDetailedRecords = Composer.Settings.Structure.Add(Type("DataCompositionGroup"));
	GroupDetailedRecords.Use = True;
	
	Composer.Settings.Selection.Items.Clear();
	
	SelectedField               = GroupDetailedRecords.Selection.Items.Add(Type("DataCompositionSelectedField"));
	SelectedField.Field          = New DataCompositionField("Products");
	SelectedField.Use = True;
	
	If GetFunctionalOption("UseCharacteristics") Then
		SelectedField               = GroupDetailedRecords.Selection.Items.Add(Type("DataCompositionSelectedField"));
		SelectedField.Field          = New DataCompositionField("Characteristic");
		SelectedField.Use = True;
	EndIf;
	
	If GetFunctionalOption("UseBatches") Then
		SelectedField               = GroupDetailedRecords.Selection.Items.Add(Type("DataCompositionSelectedField"));
		SelectedField.Field          = New DataCompositionField("Batch");
		SelectedField.Use = True;
	EndIf;
	
	If GetFunctionalOption("UseSeveralUnitsForProduct") Then
		SelectedField               = GroupDetailedRecords.Selection.Items.Add(Type("DataCompositionSelectedField"));
		SelectedField.Field          = New DataCompositionField("MeasurementUnit");
		SelectedField.Use = True;
	EndIf;
	
	SelectedField               = GroupDetailedRecords.Selection.Items.Add(Type("DataCompositionSelectedField"));
	SelectedField.Field          = New DataCompositionField("MatchesSelection");
	SelectedField.Use = True;
	
	SelectedField               = GroupDetailedRecords.Selection.Items.Add(Type("DataCompositionSelectedField"));
	SelectedField.Field          = New DataCompositionField("Code");
	SelectedField.Use = True;
	
	SelectedField               = GroupDetailedRecords.Selection.Items.Add(Type("DataCompositionSelectedField"));
	SelectedField.Field          = New DataCompositionField("Used");
	SelectedField.Use = True;
	
	// Layout composition and query execution.
	TemplateComposer = New DataCompositionTemplateComposer;
	CompositionTemplate = TemplateComposer.Execute(DataCompositionSchema, Composer.GetSettings(), , , Type("DataCompositionValueCollectionTemplateGenerator"));
	
	Parameter = CompositionTemplate.ParameterValues.Find("Date");
	If Parameter <> Undefined Then
		Parameter.Value = CurrentDate();
	EndIf;
	Parameter = CompositionTemplate.ParameterValues.Find("PriceKind");
	If Parameter <> Undefined Then
		Parameter.Value = Selection.PriceKind;
	EndIf;
	Parameter = CompositionTemplate.ParameterValues.Find("ExchangeRule");
	If Parameter <> Undefined Then
		Parameter.Value = ExchangeRule;
	EndIf;
	Parameter = CompositionTemplate.ParameterValues.Find("WeighingUnits");
	If Parameter <> Undefined Then
		Parameter.Value = Selection.WeighingUnits;
	EndIf;
	Parameter = CompositionTemplate.ParameterValues.Find("BarcodeFormat");
	If Parameter <> Undefined Then
		Parameter.Value = InformationRegisters.Barcodes.WeightBarcodeFormat(Selection.WeightProductPrefix);
	EndIf;
	
	CompositionProcessor = New DataCompositionProcessor;
	CompositionProcessor.Initialize(CompositionTemplate);
	OutputProcessor = New DataCompositionResultValueCollectionOutputProcessor;
	
	ReportData = New ValueTable();
	OutputProcessor.SetObject(ReportData);
	ReportData = OutputProcessor.Output(CompositionProcessor);
	
	BeginTransaction();
	PLU = GetMaximumCode( ExchangeRule) + 1;
	FreePLU = GetFreeCodes( ExchangeRule);
	For Each Capsule In ReportData Do
		If Capsule.MatchesSelection Then
			If Not ValueIsFilled(Capsule.Code) Then
				If FreePLU.Count() = 0 Then
					WriteCode(Capsule, ExchangeRule, PLU, True);
					PLU = PLU + 1;
				Else
					WriteCode(Capsule, ExchangeRule, FreePLU[0].Code, True);
					FreePLU.Delete(0);
				EndIf;
			Else
				WriteCode(Capsule, ExchangeRule, Capsule.Code, True);
			EndIf;
		Else
			WriteCode(Capsule, ExchangeRule, Capsule.Code, False);
		EndIf;
	EndDo;
	CommitTransaction();
	
	SetPrivilegedMode(False);
	
EndProcedure

// The procedure updates product codes for all exchange rules.
// Parameters:
//  No
//
// Returns:
//  No
//
Procedure ScheduledJobUpdateGoodsCodes() Export
	
	SetPrivilegedMode(True);
	
	LangCode = CommonUseClientServer.MainLanguageCode();
	WriteLogEvent(
		NStr("en = 'Update goods codes of offline peripherals'",
			LangCode),
		EventLogLevel.Information,,,
		NStr("en = 'Scheduled update of goods codes of offline peripherals has been started.'",
			LangCode));
	
	Query = New Query(
	"SELECT
	|	ExchangeWithOfflinePeripheralsRules.Ref AS ExchangeRule
	|FROM
	|	Catalog.ExchangeWithOfflinePeripheralsRules AS ExchangeWithOfflinePeripheralsRules");
	
	Result = Query.Execute();
	Selection = Result.Select();
	
	While Selection.Next() Do
		Try
			RefreshProductProduct(Selection.ExchangeRule);
		Except
			WriteLogEvent(
				NStr("en = 'Update goods codes of offline peripherals'",
					LangCode),
				EventLogLevel.Error,,,
				NStr("en = 'An error occurred during the scheduled update of the Offline peripherals goods codes.'",
					LangCode)
				+ Chars.LF + ErrorInfo().Definition);
		EndTry;
	EndDo;
	
	WriteLogEvent(
		NStr("en = 'Update goods codes of offline peripherals'",
			LangCode),
		EventLogLevel.Information,,,
		NStr("en = 'Scheduled update of goods codes of offline peripherals is completed.'",
			LangCode));
	
	SetPrivilegedMode(False);
	
EndProcedure

#EndRegion

#Region ProductsDump

// The function returns a structure with data in a format required to import a product list to the scales with labels printing
//
// Parameters:
//  Device - <CatalogRef.Peripherals> - Device for which it is required to get data
//  ModifiedOnly - <Boolean> - Shows that only changed data is received
//
// Returns:
//  <Structure> with a structure array to be exported and a number of strings that are not exported
//
Function GetDataForScales(Device, ModifiedOnly = True) Export
	
	Parameters = GetDeviceParameters(Device);
	If Parameters = Undefined Then
		Return Undefined;
	EndIf;
	
	Parameters.Insert("PartialExport", ModifiedOnly AND Parameters.ImportChanges);
	
	ReturnValue = New Structure(
		"Data, ExportedRowsWithErrorsCount, PartialExport, Parameters",
		New Array(),
		0,
		ModifiedOnly AND Parameters.ImportChanges,
		Parameters
	);
	
	Table = GetGoodsTableForExport(Device, Parameters, True);
	
	For Each TSRow In Table Do
		
		If TSRow.HasErrors Then
			ReturnValue.ExportedRowsWithErrorsCount = ReturnValue.ExportedRowsWithErrorsCount + 1;
			Continue;
		EndIf;
		
		ArrayElement = New Structure("PLU, Code, Barcode, Description, Price", 0, 0, "", "" , 0);
		ArrayElement.PLU = TSRow.Code;
		ArrayElement.Code = TSRow.Code;
		If TSRow.Used Then
			ArrayElement.Barcode     = Mid(TSRow.BarcodesArray[0], 3, 5);
			ArrayElement.Description = String(TSRow.Products);
			ArrayElement.Price         = TSRow.Price;
		EndIf;
		
		ReturnValue.Data.Add(ArrayElement);
		
	EndDo;

	Return ReturnValue;

EndFunction

// The function returns a structure with data in a format required to import a product list to Cash register Offline
//
// Parameters:
//  Device - <CatalogRef.Peripherals> - Device for which it is required to get data
//  ModifiedOnly - <Boolean> - Shows that only changed data is received
//
// Returns:
//  <Structure> with a structure array to be exported and a number of strings that are not exported
//
Function GetDataForPettyCash(Device, ModifiedOnly = True) Export
	
	Parameters = GetDeviceParameters(Device);
	If Parameters = Undefined Then
		Return Undefined;
	EndIf;
	
	Parameters.Insert("PartialExport", ModifiedOnly AND Parameters.ImportChanges);
	
	ReturnValue = New Structure(
		"Data, ExportedRowsWithErrorsCount, PartialExport, Parameters",
		New Array(),
		0,
		ModifiedOnly AND Parameters.ImportChanges,
		Parameters);
	
	Table = GetGoodsTableForExport(Device, Parameters, True);
	
	For Each TSRow In Table Do
		
		If TSRow.HasErrors Then
			ReturnValue.ExportedRowsWithErrorsCount = ReturnValue.ExportedRowsWithErrorsCount + 1;
			Continue;
		EndIf;
		
		ArrayElement = New Structure("Code, Barcode, Description, DescriptionFull, MeasurementUnit, Price, Balance, WeightProduct", 0, "", "", "", "", 0, 0, False);
		ArrayElement.Code = TSRow.Code;
		If TSRow.Used Then
			ArrayElement.Barcode           = TSRow.BarcodesArray;
			ArrayElement.Description       = TSRow.Description;
			ArrayElement.DescriptionFull   = TSRow.DescriptionFull;
			ArrayElement.MeasurementUnit   = TSRow.MeasurementUnit;
			ArrayElement.Price             = TSRow.Price;
			ArrayElement.Balance           = 0;
			ArrayElement.WeightProduct     = TSRow.Weight;
		EndIf;
		
		ReturnValue.Data.Add(ArrayElement);
		
	EndDo;
	
	Return ReturnValue;
	
EndFunction

// The function returns a product table with data to be imported to the device
//
// Parameters:
//  Device - <CatalogRef.Peripherals> - Device for which it is required to get data
//  ModifiedOnly - <Boolean> - Shows that only changed data is received
//  RefreshProductCodes - <Boolean> - Shows that product codes are updated before obtaining data.
//
// Returns:
//  <ValuesTable> of products to be exported
//
Function GetGoodsTableForExport(Device, Parameters, RefreshProductProduct = False) Export
	
	SetPrivilegedMode(True);
	
	WeightCodeMaximumValue = InformationRegisters.Barcodes.GetWeightBarcodeMaximumCodeValueAsNumber(Parameters.WeightProductPrefix);
	
	If RefreshProductProduct Then
		RefreshProductProduct(Parameters.ExchangeRule);
	EndIf;
	
	Query = New Query(
	"SELECT
	|	ProductsCodesPeripheralOffline.Used AS Used,
	|	ProductsCodesPeripheralOffline.Code AS Code,
	|	ProductsCodesPeripheralOffline.Products AS Products,
	|	ISNULL(ProductsCodesPeripheralOffline.Products.Description, """") AS ProductsDescription,
	|	ISNULL(ProductsCodesPeripheralOffline.Products.DescriptionFull, """") AS ProductsDescriptionFull,
	|	ProductsCodesPeripheralOffline.Characteristic AS Characteristic,
	|	ISNULL(ProductsCodesPeripheralOffline.Characteristic.Description, """") AS CharacteristicDescription,
	|	ISNULL(ProductsCodesPeripheralOffline.Characteristic.Description, """") AS CharacteristicDescriptionFull,
	|	ProductsCodesPeripheralOffline.Batch AS Batch,
	|	ISNULL(ProductsCodesPeripheralOffline.Batch.Description, """") AS BatchDescription,
	|	ISNULL(ProductsCodesPeripheralOffline.Products.MeasurementUnit.Description, """") AS StoringUnitDescription,
	|	ProductsCodesPeripheralOffline.MeasurementUnit AS MeasurementUnit,
	|	ISNULL(ProductsCodesPeripheralOffline.MeasurementUnit.Description, """") AS MeasurementUnitDescription,
	|	ISNULL(Barcodes.Barcode, """") AS Barcode,
	|	ISNULL(ProductsCodesPeripheralOffline.MeasurementUnit.Factor, 1) / ISNULL(PricesSliceLast.MeasurementUnit.Factor, 1) * ISNULL(PricesSliceLast.Price, 0) AS Price,
	|	TRUE AS Weight,
	|	CASE
	|		WHEN ProductsCodesPeripheralOfflineChanges.Node = &InfobaseNode
	|			THEN 1
	|		ELSE 0
	|	END AS PictureIndexAreChanges
	|FROM
	|	InformationRegister.ProductsCodesPeripheralOffline AS ProductsCodesPeripheralOffline
	|		LEFT JOIN InformationRegister.Barcodes AS Barcodes
	|		ON ProductsCodesPeripheralOffline.Products = Barcodes.Products
	|			AND ProductsCodesPeripheralOffline.Characteristic = Barcodes.Characteristic
	|			AND ProductsCodesPeripheralOffline.Batch = Barcodes.Batch
	|			AND ProductsCodesPeripheralOffline.MeasurementUnit = Barcodes.MeasurementUnit
	|			AND (&LabelsWithPrintScales)
	|		LEFT JOIN InformationRegister.Prices.SliceLast(&CurrentDate, PriceKind = &PriceKind) AS PricesSliceLast
	|		ON ProductsCodesPeripheralOffline.Products = PricesSliceLast.Products
	|			AND ProductsCodesPeripheralOffline.Characteristic = PricesSliceLast.Characteristic
	|		LEFT JOIN InformationRegister.ProductsCodesPeripheralOffline.Changes AS ProductsCodesPeripheralOfflineChanges
	|		ON ProductsCodesPeripheralOffline.Code = ProductsCodesPeripheralOfflineChanges.Code
	|			AND (ProductsCodesPeripheralOfflineChanges.ExchangeRule = &ExchangeRule)
	|			AND (ProductsCodesPeripheralOfflineChanges.Node = &InfobaseNode)
	|WHERE
	|	ProductsCodesPeripheralOffline.ExchangeRule = &ExchangeRule
	|	AND ProductsCodesPeripheralOffline.Products <> VALUE(Catalog.Products.EmptyRef)
	|	AND &ModifiedOnly
	|TOTALS
	|	MAX(Barcode)
	|BY
	|	Code");
	
	ReplaceString = "TRUE";
	
	If Parameters.PartialExport Then
		ReplaceString = "ProductsCodesPeripheralOfflineChanges.ExchangeRule = &ExchangeRule
						|AND ProductsCodesPeripheralOfflineChanges.Node = &InfobaseNode";
	EndIf;
	
	Query.Text = StrReplace(Query.Text, "&ModifiedOnly", ReplaceString);
	
	ReplaceString = "TRUE";

	If Parameters.EquipmentType = Enums.PeripheralTypes.LabelsPrintingScales Then
		ReplaceString = "Barcodes.Barcode LIKE & BarcodeFormat";
		Query.SetParameter("BarcodeFormat", InformationRegisters.Barcodes.WeightBarcodeFormat(Parameters.WeightProductPrefix));
	EndIf;
	
	Query.Text = StrReplace(Query.Text, "&LabelsWithPrintScales", ReplaceString);
	
	Query.SetParameter("ExchangeRule",	Parameters.ExchangeRule);
	Query.SetParameter("PriceKind",		Parameters.PriceKind);
	Query.SetParameter("InfobaseNode",	Parameters.InfobaseNode);
	Query.SetParameter("CurrentDate",	EndOfDay(CurrentDate()));
	
	ProductsTable = New ValueTable;
	ProductsTable.Columns.Add("Used",       New TypeDescription("Boolean"));
	ProductsTable.Columns.Add("Code",                New TypeDescription("Number"));
	ProductsTable.Columns.Add("Products",       New TypeDescription("CatalogRef.Products"));
	ProductsTable.Columns.Add("Characteristic",     New TypeDescription("CatalogRef.ProductsCharacteristics"));
	ProductsTable.Columns.Add("Batch",             New TypeDescription("CatalogRef.ProductsBatches"));
	ProductsTable.Columns.Add("PackingUnit",    New TypeDescription("CatalogRef.UOM"));
	ProductsTable.Columns.Add("MeasurementUnit",   New TypeDescription("String"));
	ProductsTable.Columns.Add("Description",       New TypeDescription("String"));
	ProductsTable.Columns.Add("DescriptionFull", New TypeDescription("String"));
	ProductsTable.Columns.Add("Barcode",           New TypeDescription("String"));
	ProductsTable.Columns.Add("BarcodesArray",   New TypeDescription("Array"));
	ProductsTable.Columns.Add("Price",               New TypeDescription("Number"));
	ProductsTable.Columns.Add("Weight",            New TypeDescription("Boolean"));
	
	ProductsTable.Columns.Add("NeededSeriesIndication", New TypeDescription("Boolean"));
	
	ProductsTable.Columns.Add("HasErrors",                  New TypeDescription("Boolean"));
	ProductsTable.Columns.Add("PictureIndexAreChanges", New TypeDescription("Number"));
	
	SelectionOnCodes = Query.Execute().Select(QueryResultIteration.ByGroups);
	While SelectionOnCodes.Next() Do
		
		NewRow = ProductsTable.Add();
		
		Selection = SelectionOnCodes.Select();
		While Selection.Next() Do
			
			Barcode = TrimAll(Selection.Barcode);
			
			If Not ValueIsFilled(NewRow.Code) Then
				
				NewRow.Used                = Selection.Used;
				NewRow.Code                = Selection.Code;
				NewRow.Products = Selection.Products;
				NewRow.Characteristic      = Selection.Characteristic;
				NewRow.Batch               = Selection.Batch;
				NewRow.PackingUnit         = Selection.MeasurementUnit;
				NewRow.Description         = DriveServer.GetProductsPresentationForPrinting(
						Selection.ProductsDescription,
						Selection.CharacteristicDescription)
					+ ?(ValueIsFilled(Selection.MeasurementUnitDescription),
						", (" + Selection.MeasurementUnitDescription + ")",
						""
				);
				NewRow.DescriptionFull          =  DriveServer.GetProductsPresentationForPrinting(
						Selection.ProductsDescriptionFull,
						Selection.CharacteristicDescriptionFull)
					+ ?(ValueIsFilled(Selection.MeasurementUnitDescription),
						", (" + Selection.MeasurementUnitDescription + ")",
						""
				);
				NewRow.Price                        = Selection.Price;
				NewRow.Weight                     = Selection.Weight;
				NewRow.PictureIndexAreChanges = Selection.PictureIndexAreChanges;
				NewRow.Barcode                    = Barcode;
				
			Else
				NewRow.Barcode = NewRow.Barcode + ", " + Barcode;
			EndIf;
			
			If ValueIsFilled(Barcode) Then
				NewRow.BarcodesArray.Add(Barcode);
			EndIf;
			
		EndDo;
		
		If Parameters.EquipmentType = Enums.PeripheralTypes.LabelsPrintingScales
			AND RefreshProductProduct
			AND (NOT ValueIsFilled(NewRow.Barcode)) Then
			
				PreviousValueWeightCodeMaximumValue = WeightCodeMaximumValue;
				WeightCodeMaximumValue                   = min(WeightCodeMaximumValue + 1, 99999);
				
				NewRow.Barcode = InformationRegisters.Barcodes.GetWeightProcuctBarcodeByCode(WeightCodeMaximumValue, Parameters.WeightProductPrefix);
				NewRow.BarcodesArray.Add(NewRow.Barcode);
				
				Try
					BarcodeRecordManager = InformationRegisters.Barcodes.CreateRecordManager();
					BarcodeRecordManager.Products   = NewRow.Products;
					BarcodeRecordManager.Characteristic = NewRow.Characteristic;
					BarcodeRecordManager.Batch = NewRow.Batch;
					BarcodeRecordManager.MeasurementUnit = NewRow.MeasurementUnit;
					BarcodeRecordManager.Barcode       = NewRow.Barcode;
					BarcodeRecordManager.Write();
				Except
					NewRow.Barcode = "";
					NewRow.BarcodesArray.Clear();
				EndTry;
				
		EndIf;
		
		If Not ValueIsFilled(NewRow.Price)
			OR NewRow.NeededSeriesIndication
			OR Not ValueIsFilled(NewRow.Description)
			OR (NOT ValueIsFilled(NewRow.Barcode) AND Parameters.EquipmentType = Enums.PeripheralTypes.LabelsPrintingScales)
			OR (ValueIsFilled(Parameters.MaximumCode) AND NewRow.Code > Parameters.MaximumCode) Then
			NewRow.HasErrors = True;
		EndIf;
		
	EndDo;
	
	SetPrivilegedMode(False);
	
	Return ProductsTable;
	
EndFunction

#EndRegion

#Region ProductsExportRules

// The function returns a product table with the product data for the export rule with prices
//
// Parameters:
//  ExchangeRule - <CatalogRef.ExchangeRulesWithPeripheralsOffline>
//  PriceKind - <CatalogRef.PriceTypes>
//
// Returns:
//  <ValueTable>
//
Function GetGoodsTableForRule(ExchangeRule, PriceKind) Export
	
	SetPrivilegedMode(True);
	
	QueryParameters = New Query(
	"SELECT
	|	ExchangeWithOfflinePeripheralsRules.PeripheralsType AS EquipmentType,
	|	ExchangeWithOfflinePeripheralsRules.WeightProductPrefix AS WeightProductPrefix
	|FROM
	|	Catalog.ExchangeWithOfflinePeripheralsRules AS ExchangeWithOfflinePeripheralsRules
	|WHERE
	|	ExchangeWithOfflinePeripheralsRules.Ref = &Ref");
	
	QueryParameters.SetParameter("Ref", ExchangeRule);
	
	Parameters = QueryParameters.Execute().Select();
	Parameters.Next();
	
	Query = New Query(
	"SELECT
	|	ProductsCodesPeripheralOffline.Used AS Used,
	|	ProductsCodesPeripheralOffline.Code AS Code,
	|	ProductsCodesPeripheralOffline.Products AS Products,
	|	ISNULL(ProductsCodesPeripheralOffline.Products.Description, """") AS ProductsDescription,
	|	ISNULL(ProductsCodesPeripheralOffline.Products.DescriptionFull, """") AS ProductsDescriptionFull,
	|	ProductsCodesPeripheralOffline.Characteristic AS Characteristic,
	|	ISNULL(ProductsCodesPeripheralOffline.Characteristic.Description, """") AS CharacteristicDescription,
	|	ISNULL(ProductsCodesPeripheralOffline.Characteristic.Description, """") AS CharacteristicDescriptionFull,
	|	ProductsCodesPeripheralOffline.Batch AS Batch,
	|	ISNULL(ProductsCodesPeripheralOffline.Batch.Description, """") AS BatchDescription,
	|	ProductsCodesPeripheralOffline.MeasurementUnit AS MeasurementUnit,
	|	ISNULL(ProductsCodesPeripheralOffline.MeasurementUnit.Description, """") AS MeasurementUnitDescription,
	|	Barcodes.Barcode AS Barcode,
	|	ISNULL(ProductsCodesPeripheralOffline.MeasurementUnit.Factor, 1) / ISNULL(PricesSliceLast.MeasurementUnit.Factor, 1) * ISNULL(PricesSliceLast.Price, 0) AS Price,
	|	TRUE AS Weight
	|FROM
	|	InformationRegister.ProductsCodesPeripheralOffline AS ProductsCodesPeripheralOffline
	|		LEFT JOIN InformationRegister.Barcodes AS Barcodes
	|		ON ProductsCodesPeripheralOffline.Products = Barcodes.Products
	|			AND ProductsCodesPeripheralOffline.Characteristic = Barcodes.Characteristic
	|			AND ProductsCodesPeripheralOffline.Batch = Barcodes.Batch
	|			AND ProductsCodesPeripheralOffline.MeasurementUnit = Barcodes.MeasurementUnit
	|			AND (&LabelsWithPrintScales)
	|		LEFT JOIN InformationRegister.Prices.SliceLast(&CurrentDate, PriceKind = &PriceKind) AS PricesSliceLast
	|		ON ProductsCodesPeripheralOffline.Products = PricesSliceLast.Products
	|			AND ProductsCodesPeripheralOffline.Characteristic = PricesSliceLast.Characteristic
	|WHERE
	|	ProductsCodesPeripheralOffline.ExchangeRule = &ExchangeRule
	|TOTALS
	|	MAX(Barcode)
	|BY
	|	Code");
	
	ReplaceString = "TRUE";
	
	If Parameters.EquipmentType = Enums.PeripheralTypes.LabelsPrintingScales Then
		ReplaceString = "Barcodes.Barcode LIKE & BarcodeFormat";
		Query.SetParameter("BarcodeFormat", InformationRegisters.Barcodes.WeightBarcodeFormat(Parameters.WeightProductPrefix));
	EndIf;
	
	Query.Text = StrReplace(Query.Text, "&LabelsWithPrintScales", ReplaceString);
	
	Query.SetParameter("ExchangeRule",	ExchangeRule);
	Query.SetParameter("PriceKind",		PriceKind);
	Query.SetParameter("CurrentDate",	EndOfDay(CurrentDate()));
	
	ProductsTable = New ValueTable;
	ProductsTable.Columns.Add("Used",       New TypeDescription("Boolean"));
	ProductsTable.Columns.Add("Code",                New TypeDescription("Number"));
	ProductsTable.Columns.Add("Products",       New TypeDescription("CatalogRef.Products"));
	ProductsTable.Columns.Add("Characteristic",     New TypeDescription("CatalogRef.ProductsCharacteristics"));
	ProductsTable.Columns.Add("Batch",             New TypeDescription("CatalogRef.ProductsBatches"));
	ProductsTable.Columns.Add("MeasurementUnit",   New TypeDescription("CatalogRef.UOM"));
	ProductsTable.Columns.Add("Description",       New TypeDescription("String"));
	ProductsTable.Columns.Add("DescriptionFull", New TypeDescription("String"));
	ProductsTable.Columns.Add("Barcode",           New TypeDescription("String"));
	ProductsTable.Columns.Add("Price",               New TypeDescription("Number"));
	ProductsTable.Columns.Add("Weight",            New TypeDescription("Boolean"));
	
	SelectionOnCodes = Query.Execute().Select(QueryResultIteration.ByGroups);
	While SelectionOnCodes.Next() Do
		
		NewRow = ProductsTable.Add();
		
		Selection = SelectionOnCodes.Select();
		While Selection.Next() Do
			
			Barcode = TrimAll(Selection.Barcode);
			
			If Not ValueIsFilled(NewRow.Code) Then
				NewRow.Used       = Selection.Used;
				NewRow.Code                = Selection.Code;
				NewRow.Products       = Selection.Products;
				NewRow.Characteristic     = Selection.Characteristic;
				NewRow.Batch             = Selection.Batch;
				NewRow.MeasurementUnit           = Selection.MeasurementUnit;
				NewRow.Description                = DriveServer.GetProductsPresentationForPrinting(
						Selection.ProductsDescription,
						Selection.CharacteristicDescription)
					+ ?(ValueIsFilled(Selection.MeasurementUnitDescription),
						", (" + Selection.MeasurementUnitDescription + ")",
						""
				);
				NewRow.DescriptionFull          =  DriveServer.GetProductsPresentationForPrinting(
						Selection.ProductsDescriptionFull,
						Selection.CharacteristicDescriptionFull)
					+ ?(ValueIsFilled(Selection.MeasurementUnitDescription),
						", (" + Selection.MeasurementUnitDescription + ")",
						""
				);
				NewRow.Price               = Selection.Price;
				NewRow.Weight            = Selection.Weight;
				NewRow.Barcode           = Barcode;
			Else
				NewRow.Barcode = NewRow.Barcode + ", " + Barcode;
			EndIf;
			
		EndDo;
		
	EndDo;
	
	SetPrivilegedMode(False);
	
	Return ProductsTable;
	
EndFunction

#EndRegion
