
#Region Variables

&AtClient
Var ThisIsNewRow;

#EndRegion

#Region ProceduresAndFunctionsForControlOfTheFormAppearance

// Procedure generates selection list for the accounting section.
//
&AtServer
Procedure GenerateAccountingSectionsList()
	
	// FO Use Payroll subsystem.
	If Constants.UsePayrollSubsystem.Get()
		OR Object.AccountingSection = "Personnel settlements" Then
		Items.AccountingSection.ChoiceList.Add("Personnel settlements", NStr("en = 'Personnel settlements'"));
	EndIf;
	
	// FD Use Belongings.
	If Constants.UseFixedAssets.Get()
		OR Object.AccountingSection = "Assets" Then
		Items.AccountingSection.ChoiceList.Add("Assets", NStr("en = 'Assets'"));
	EndIf;
	
	// Other.
	Items.AccountingSection.ChoiceList.Add("Other sections", NStr("en = 'Other sections'"));
	
EndProcedure

// Function receives page name for the document accounting section.
//
// Parameters:
// AccountingSection - EnumRef.AccountingSections - Accounting section
//
// Returns:
// String - Page name corresponding to the accounting sections
//
&AtClient
Function GetPageName(AccountingSection)

	Map = New Map;
	Map.Insert("Assets", "FolderFixedAssets");
	Map.Insert("Inventory", "GroupInventory");
	Map.Insert("Cash assets", "FolderBanking");
	Map.Insert("Accounts payable and customers", "GroupSettlementsWithCounterparties");
	Map.Insert("Tax settlements", "FolderTaxesSettlements");
	Map.Insert("Personnel settlements", "GroupSettlementsWithHPersonnel");
	Map.Insert("Settlements with advance holders", "GroupAdvanceHolders");
	Map.Insert("Other sections", "GroupOtherSections");
	
	PageName = Map.Get(AccountingSection);
	
	Return PageName;

EndFunction

// Procedure sets the current page depending on the accounting section.
//
&AtClient
Procedure SetCurrentPage()
	
	Item = Items.Find(GetPageName(Object.AccountingSection));
	
	If Item <> Undefined Then
		Items.Pages.CurrentPage = Item;
	EndIf;
	
EndProcedure

// Procedure sets items visible and availability.
//
&AtServer
Procedure SetItemsVisibleEnabled()
	
	If Object.AccountingSection = "Accounts payable and customers"
		OR Object.AccountingSection = "Settlements with advance holders" Then
		
		Items.Autogeneration.Visible = True;
		
	Else
		
		Items.Autogeneration.Visible = False;
		Object.Autogeneration = False;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region GeneralPurposeProceduresAndFunctions

// It receives data set from server for the ContractOnChange procedure.
//
&AtServerNoContext
Function GetDataDateOnChange(DocumentRef, DateNew, DateBeforeChange)
	
	DATEDIFF = DriveServer.CheckDocumentNumber(DocumentRef, DateNew, DateBeforeChange);
	
	StructureData = New Structure();
	StructureData.Insert(
		"DATEDIFF",
		DATEDIFF
	);
	
	Return StructureData;
	
EndFunction

// It receives data set from server for the ContractOnChange procedure.
//
&AtServer
Function GetCompanyDataOnChange(Company)
	
	FillAddedColumns(True);
	
	StructureData = New Structure();
	StructureData.Insert(
		"Counterparty",
		DriveServer.GetCompany(Company)		
	);
	
	Return StructureData;
	
EndFunction

// Receives data set from server for the AccountOnChange procedure.
//
// Parameters:
//  Account         - AccountsChart, account according to which you should receive structure.
//
// Returns:
//  Account structure.
//
&AtServerNoContext
Function GetDataAccountOnChange(Account) Export
	
	StructureData = New Structure();
	
	StructureData.Insert("Currency", Account.Currency);
	
	Return StructureData;
	
EndFunction

// Receives the set of data from the server for the ProductsOnChange procedure.
//
&AtServerNoContext
Function GetDataFixedAsset(FixedAsset)
	
	StructureData = New Structure();
	
	StructureData.Insert("MethodOfDepreciationProportionallyProductsAmount", FixedAsset.DepreciationMethod = Enums.FixedAssetDepreciationMethods.ProportionallyToProductsVolume);
	
	Return StructureData;
	
EndFunction

// Receives the set of data from the server for the ProductsOnChange procedure.
//
&AtServerNoContext
Function GetDataProductsOnChange(StructureData)
	
	GLAccountsInDocuments.FillProductGLAccountsInStructure(StructureData);
	
	StructureData.Insert("MeasurementUnit", StructureData.Products.MeasurementUnit);
	StructureData.Insert("VATRate", StructureData.Products.VATRate);
	StructureData.Insert("CountryOfOrigin", StructureData.Products.CountryOfOrigin);
	
	If StructureData.Property("PriceKind") Then
		
		Price = DriveServer.GetProductsPriceByPriceKind(StructureData);
		StructureData.Insert("Price", Price);
		
	Else
		
		StructureData.Insert("Price", 0);
		
	EndIf;	
	
	If StructureData.Property("DiscountMarkupKind") 
		AND ValueIsFilled(StructureData.DiscountMarkupKind) Then
		StructureData.Insert("DiscountMarkupPercent", StructureData.DiscountMarkupKind.Percent);
	Else	
		StructureData.Insert("DiscountMarkupPercent", 0);
	EndIf;
		
	Return StructureData;
	
EndFunction

// It receives data set from the server for the CashAssetsBankAccountPettyCashOnChange procedure.
//
&AtServerNoContext
Function GetDataCashAssetsBankAccountPettyCashOnChange(BankAccountPettyCash)

	StructureData = New Structure();

	If TypeOf(BankAccountPettyCash) = Type("CatalogRef.CashAccounts") Then
		StructureData.Insert("Currency", BankAccountPettyCash.CurrencyByDefault);
	ElsIf TypeOf(BankAccountPettyCash) = Type("CatalogRef.BankAccounts") Then
		StructureData.Insert("Currency", BankAccountPettyCash.CashCurrency);
	Else
		StructureData.Insert("Currency", Catalogs.Currencies.EmptyRef());
	EndIf;
	
	Return StructureData;
	
EndFunction

// Receives data set from server for the CashAssetsCashAssetsCurrencyStartChoice procedure.
//
&AtServerNoContext
Function GetDataCashAssetsCashAssetsCurrencyStartChoice(BankAccountPettyCash)

	StructureData = New Structure();

	If TypeOf(BankAccountPettyCash) = Type("CatalogRef.CashAccounts") Then
		StructureData.Insert("CashAssetsType", Enums.CashAssetTypes.Cash);
	ElsIf TypeOf(BankAccountPettyCash) = Type("CatalogRef.BankAccounts") Then
		StructureData.Insert("CashAssetsType", Enums.CashAssetTypes.Noncash);
	Else
		StructureData.Insert("CashAssetsType", Undefined);
	EndIf;
	
	Return StructureData;
	
EndFunction

// Gets the default contract depending on the billing details.
//
&AtServerNoContext
Function GetContractByDefault(Document, Counterparty, Company, TabularSectionName, OperationKind = Undefined)
	
	If Not Counterparty.DoOperationsByContracts Then
		Return Counterparty.ContractByDefault;
	EndIf;
	
	ManagerOfCatalog = Catalogs.CounterpartyContracts;
	
	ContractTypesList = ManagerOfCatalog.GetContractKindsListForDocument(Document, OperationKind, TabularSectionName);
	ContractByDefault = ManagerOfCatalog.GetDefaultContractByCompanyContractKind(Counterparty, Company, ContractTypesList);
	
	Return ContractByDefault;
	
EndFunction

// It receives data set from the server for the CounterpartyOnChange procedure.
//
&AtServer
Function GetDataCounterpartyOnChange(Counterparty, Company, TabularSectionName, OperationKind = Undefined)
	
	ContractByDefault = GetContractByDefault(Object.Ref, Counterparty, Company, TabularSectionName, OperationKind);
	
	StructureData = New Structure();
	
	StructureData.Insert(
		"Contract",
		ContractByDefault
	);
	
	StructureData.Insert(
		"SettlementsCurrency",
		ContractByDefault.SettlementsCurrency
	);
	
	StructureData.Insert("DoOperationsByContracts", Counterparty.DoOperationsByContracts);
	StructureData.Insert("DoOperationsByDocuments", Counterparty.DoOperationsByDocuments);
	StructureData.Insert("DoOperationsByOrders", Counterparty.DoOperationsByOrders);
	
	SetAccountsAttributesVisible(
		Counterparty.DoOperationsByContracts,
		Counterparty.DoOperationsByDocuments,
		Counterparty.DoOperationsByOrders,
		TabularSectionName
	);
	
	Return StructureData;
	
EndFunction

// Procedure sets visible of calculation attributes depending on the parameters specified to the counterparty.
//
&AtServer
Procedure SetAccountsAttributesVisible(Val DoOperationsByContracts = False, Val DoOperationsByDocuments = False, Val DoOperationsByOrders = False, TabularSectionName)
	
	FillServiceAttributesByCounterpartyInCollection(Object[TabularSectionName]);
	
	For Each CurRow In Object[TabularSectionName] Do
		If CurRow.DoOperationsByContracts Then
			DoOperationsByContracts = True;
		EndIf;
		If CurRow.DoOperationsByDocuments Then
			DoOperationsByDocuments = True;
		EndIf;
		If CurRow.DoOperationsByOrders Then
			DoOperationsByOrders = True;
		EndIf;
	EndDo;
	
	If TabularSectionName = "AccountsPayable" Then
		Items.AccountsPayableContract.Visible = DoOperationsByContracts;
		Items.AccountsPayableDocument.Visible = DoOperationsByDocuments;
		Items.AccountsPayablePurchaseOrder.Visible = DoOperationsByOrders;
	ElsIf TabularSectionName = "AccountsReceivable" Then
		Items.AccountsReceivableAgreement.Visible = DoOperationsByContracts;
		Items.AccountsReceivableDocument.Visible = DoOperationsByDocuments;
		Items.AccountsReceivableSalesOrder.Visible = DoOperationsByOrders;
	EndIf;
	
EndProcedure

// Procedure fills out the service attributes.
//
&AtServerNoContext
Procedure FillServiceAttributesByCounterpartyInCollection(DataCollection)
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	CAST(Table.LineNumber AS NUMBER) AS LineNumber,
	|	Table.Counterparty AS Counterparty
	|INTO TableOfCounterparty
	|FROM
	|	&DataCollection AS Table
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableOfCounterparty.Counterparty.DoOperationsByContracts AS DoOperationsByContracts,
	|	TableOfCounterparty.Counterparty.DoOperationsByDocuments AS DoOperationsByDocuments,
	|	TableOfCounterparty.Counterparty.DoOperationsByOrders AS DoOperationsByOrders
	|FROM
	|	TableOfCounterparty AS TableOfCounterparty";
	
	Query.SetParameter("DataCollection", DataCollection.Unload( ,"LineNumber, Counterparty"));
	
	Selection = Query.Execute().Select();
	For Ct = 0 To DataCollection.Count() - 1 Do
		Selection.Next(); // Number of rows in the query selection always equals to the number of rows in the collection
		FillPropertyValues(DataCollection[Ct], Selection, "DoOperationsByContracts, DoOperationsByDocuments, DoOperationsByOrders");
	EndDo;
	
EndProcedure

&AtServerNoContext
// It receives data set from server for the ContractOnChange procedure.
//
Function GetDataContractOnChange(Contract)
	
	StructureData = New Structure();
	
	StructureData.Insert(
		"SettlementsCurrency",
		Contract.SettlementsCurrency
	);
	
	Return StructureData;
	
EndFunction

&AtServer
Procedure InventoryStructuralUnitOnChangeAtServer()
	FillAddedColumns(True);
EndProcedure

// The procedure sets the form attributes
// visible on the option Use subsystem Production.
//
// Parameters:
// No.
//
&AtServer
Procedure SetVisibleByFOUseProductionSubsystem()
	
	// Production.
	If Constants.UseProductionSubsystem.Get() Then
		
		// Setting the method of Business unit selection depending on FO.
		If Not Constants.UseSeveralDepartments.Get()
			AND Not Constants.UseSeveralWarehouses.Get() Then
			
			Items.InventoryStructuralUnit.ListChoiceMode = True;
			If ValueIsFilled(MainWarehouse) Then
				Items.InventoryStructuralUnit.ChoiceList.Add(MainWarehouse);
			EndIf;
			Items.InventoryStructuralUnit.ChoiceList.Add(MainDepartment);
			
		EndIf;
		
	Else
		
		If Constants.UseSeveralWarehouses.Get() Then
			
			NewArray = New Array();
			NewArray.Add(Enums.BusinessUnitsTypes.Warehouse);
			NewArray.Add(Enums.BusinessUnitsTypes.Retail);
			ArrayTypesOfBusinessUnits = New FixedArray(NewArray);
			NewParameter = New ChoiceParameter("Filter.StructuralUnitType", ArrayTypesOfBusinessUnits);
			NewArray = New Array();
			NewArray.Add(NewParameter);
			NewParameters = New FixedArray(NewArray);
			
			Items.InventoryStructuralUnit.ChoiceParameters = NewParameters;
			
		Else
			
			Items.InventoryStructuralUnit.Visible = False;
			
		EndIf;
		
		Items.DirectExpencesGroup.Visible = False;
		
	EndIf;
	
EndProcedure

// It gets counterparty contract selection form parameter structure.
//
&AtServerNoContext
Function GetChoiceFormParameters(Document, Company, Counterparty, Contract, OperationKind, TabularSectionName)
	
	ContractTypesList = Catalogs.CounterpartyContracts.GetContractKindsListForDocument(Document, OperationKind, TabularSectionName);
	
	FormParameters = New Structure;
	FormParameters.Insert("ControlContractChoice", Counterparty.DoOperationsByContracts);
	FormParameters.Insert("Counterparty", Counterparty);
	FormParameters.Insert("Company", Company);
	FormParameters.Insert("ContractType", ContractTypesList);
	FormParameters.Insert("CurrentRow", Contract);
	
	Return FormParameters;
	
EndFunction

#Region FormEventsHandlers

// Procedure - event handler OnCreateAtServer of the form.
// The procedure implements
// - form attribute initialization,
// - set parameters of the functional form
// options,
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	DriveServer.FillDocumentHeader(
		Object,
		,
		Parameters.CopyingValue,
		Parameters.Basis,
		PostingIsAllowed);
	
	GenerateAccountingSectionsList();
	
	DocumentObject = FormAttributeToValue("Object");
	If DocumentObject.IsNew() 
		AND Parameters.Property("BasisDocument") 
		AND ValueIsFilled(Parameters.BasisDocument) Then
		DocumentObject.Fill(Parameters.BasisDocument);
		ValueToFormAttribute(DocumentObject, "Object");
	EndIf;
	
	DocumentDate = Object.Date;
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentDate();
	EndIf;
	
	Cash = Enums.CashAssetTypes.Cash;
	
	ParentCompany = DriveServer.GetCompany(Object.Company);
	
	CurrencyByDefault = Constants.FunctionalCurrency.Get();
	
	SetItemsVisibleEnabled();
	
	If Not Constants.UseSecondaryEmployment.Get() Then
		If Items.Find("PayrollEmployeeCode") <> Undefined Then
			Items.PayrollEmployeeCode.Visible = False;
		EndIf;
		If Items.Find("SettlementsWithAdvanceHoldersEmployeeCode") <> Undefined Then
			Items.SettlementsWithAdvanceHoldersEmployeeCode.Visible = False;
		EndIf;
	EndIf;
	
	User = Users.CurrentUser();
	
	SettingValue = DriveReUse.GetValueByDefaultUser(User, "MainWarehouse");
	MainWarehouse = ?(ValueIsFilled(SettingValue), SettingValue, Catalogs.BusinessUnits.MainWarehouse);;
	
	If Not Constants.UseSeveralWarehouses.Get()
		AND MainWarehouse <> Undefined Then
		
		Items.StockReceivedFromThirdPartiesStructuralUnit.Visible = False;
		
	EndIf;
	
	SettingValue = DriveReUse.GetValueByDefaultUser(User, "MainDepartment");
	MainDepartment = ?(ValueIsFilled(SettingValue), SettingValue, Catalogs.BusinessUnits.MainDepartment);
	
	FillAddedColumns();
	
	// Filling in the additional attributes of tabular section.
	SetAccountsAttributesVisible(, , , "AccountsPayable");
	SetAccountsAttributesVisible(, , , "AccountsReceivable");
	
	// FO Use Production subsystem.
	SetVisibleByFOUseProductionSubsystem();
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.DataImportFromExternalSources
	DataImportFromExternalSources.OnCreateAtServer(Metadata.Documents.OpeningBalanceEntry.TabularSections.Inventory, DataLoadSettings, ThisObject, False);
	// End StandardSubsystems.DataImportFromExternalSource
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisForm, Items.ImportantCommandsGroup);
	// End StandardSubsystems.Printing
	
	// Serial numbers
	UseSerialNumbersBalance = WorkWithSerialNumbers.UseSerialNumbersBalance();
	
	Items.InventoryImportDataFromExternalSourceInventory.Visible =
		AccessRight("Use", Metadata.DataProcessors.DataImportFromExternalSources);
	
EndProcedure

// Procedure - event handler OnOpen.
//
&AtClient
Procedure OnOpen(Cancel)

	SetCurrentPage();
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	FillAddedColumns();
EndProcedure

&AtClient
Procedure ChoiceProcessing(SelectedValue, ChoiceSource)
	
	If ChoiceSource.FormName = "CommonForm.ProductGLAccounts" Then
		GLAccountsChoiceProcessingAtClient(SelectedValue);
	EndIf;
	
EndProcedure

// Procedure - event handler of the form NotificationProcessing.
//
&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "AfterRecordingOfCounterparty" Then
		If ValueIsFilled(Parameter) Then
			For Each CurRow In Object.AccountsReceivable Do
				If Parameter = CurRow.Counterparty Then
					SetAccountsAttributesVisible(, , , "AccountsReceivable");
					Return;
				EndIf;
			EndDo;
			For Each CurRow In Object.AccountsPayable Do
				If Parameter = CurRow.Counterparty Then
					SetAccountsAttributesVisible(, , , "AccountsPayable");
					Return;
				EndIf;
			EndDo;
		EndIf;
	ElsIf EventName = "SerialNumbersSelection"
		AND ValueIsFilled(Parameter) 
		// Form owner checkup
		AND Source <> New UUID("00000000-0000-0000-0000-000000000000")
		AND Source = UUID
		Then
		
		GetSerialNumbersFromStorage(Parameter.AddressInTemporaryStorage, Parameter.RowKey);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region ProcedureEventHandlersOfHeaderAttributes

// Procedure - OnChange event handler of the document date input field.
// In procedure situation is determined when date change document is
// into document numbering another period and in this case
// assigns to the document new unique number.
//
&AtClient
Procedure DateOnChange(Item)
	
	// Date change event DataProcessor.
	DateBeforeChange = DocumentDate;
	DocumentDate = Object.Date;
	If Object.Date <> DateBeforeChange Then
		StructureData = GetDataDateOnChange(Object.Ref, Object.Date, DateBeforeChange);
		If StructureData.DATEDIFF <> 0 Then
			Object.Number = "";
		EndIf;
	EndIf;
	
EndProcedure

// Procedure - OnChange event handler of the company input field.
// In procedure is executed document
// number clearing and also make parameter set of the form functional options.
//
&AtClient
Procedure CompanyOnChange(Item)
	
	// Company change event data processor.
	Object.Number = "";
	StructureData = GetCompanyDataOnChange(Object.Company);
	Counterparty = StructureData.Counterparty;
	
EndProcedure

// Procedure - OnChange event handler of the AccountingSection input field.
// Current form page is set in the procedure
// depending on the accounting section.
//
&AtClient
Procedure AccountingSectionOnChange(Item)
	
	// Current form page setting.
	SetCurrentPage();
	SetItemsVisibleEnabled();
	
	Object.FixedAssets.Clear();
	Object.Inventory.Clear();
	Object.DirectCost.Clear();
	Object.CashAssets.Clear();
	Object.AccountsReceivable.Clear();
	Object.AccountsPayable.Clear();
	Object.TaxesSettlements.Clear();
	Object.Payroll.Clear();
	Object.AdvanceHolders.Clear();
	Object.OtherSections.Clear();
	
EndProcedure

#Region BelongingsTSEventHandlers

// Procedure - OnStartEdit event handler of the FixedAssets tabular section.
//
&AtClient
Procedure FixedAssetsOnStartEdit(Item, NewRow, Copy)
	
	If NewRow Then
 
		TabularSectionRow = Items.FixedAssets.CurrentData;
		TabularSectionRow.StructuralUnit = MainDepartment;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region EventHandlersOfThePropertyTabularSectionAttributes

// Procedure - event handler OnChange of
// input field WorksProductsVolumeForDepreciationCalculation in
// string of tabular section FixedAssets.
//
&AtClient
Procedure FixedAssetsVolumeProductsWorksForDepreciationCalculationOnChange(Item)
	
	TabularSectionRow = Items.FixedAssets.CurrentData;
	StructureData = GetDataFixedAsset(TabularSectionRow.FixedAsset);
	
	If Not StructureData.MethodOfDepreciationProportionallyProductsAmount Then
		ShowMessageBox(Undefined,NStr("en = '""Product (work) volume for calculating depreciation"" cannot be filled in for the specified depreciation method.'"));
		TabularSectionRow.AmountOfProductsServicesForDepreciationCalculation = 0;
	EndIf;
	
EndProcedure

// Procedure - event handler OnChange of
// input field UsagePeriodForDepreciationCalculation in string
// of tabular section FixedAssets.
//
&AtClient
Procedure FixedAssetsUsagePeriodForDepreciationCalculationOnChange(Item)
	
	TabularSectionRow = Items.FixedAssets.CurrentData;
	StructureData = GetDataFixedAsset(TabularSectionRow.FixedAsset);
	
	If StructureData.MethodOfDepreciationProportionallyProductsAmount Then
		ShowMessageBox(Undefined,NStr("en = 'Cannot fill in ""Useful life for calculating depreciation"" for the specified method of depreciation.'"));
		TabularSectionRow.UsagePeriodForDepreciationCalculation = 0;
	EndIf;
	
EndProcedure

// Procedure - event handler OnChange of
// input field FixedAsset in string of tabular section FixedAssets.
//
&AtClient
Procedure FixedAssetsFixedAssetOnChange(Item)
	
	TabularSectionRow = Items.FixedAssets.CurrentData;
	StructureData = GetDataFixedAsset(TabularSectionRow.FixedAsset);
	
	If StructureData.MethodOfDepreciationProportionallyProductsAmount Then
		TabularSectionRow.UsagePeriodForDepreciationCalculation = 0;
	Else
		TabularSectionRow.AmountOfProductsServicesForDepreciationCalculation = 0;
		TabularSectionRow.CurrentOutputQuantity = 0;
	EndIf;
	
EndProcedure

// Procedure - OnChange event handler
// of the OutputQuantity edit box in the FixedAssets tabular section string.
//
&AtClient
Procedure FixedAssetsCurrentOutputQuantityOnChange(Item)
	
	TabularSectionRow = Items.FixedAssets.CurrentData;
	StructureData = GetDataFixedAsset(TabularSectionRow.FixedAsset);
	
	If Not StructureData.MethodOfDepreciationProportionallyProductsAmount Then
		ShowMessageBox(Undefined,NStr("en = '""Product (work) volume for calculating depreciation"" cannot be filled in for the specified depreciation method.'"));
		TabularSectionRow.CurrentOutputQuantity = 0;
	EndIf;

EndProcedure

#EndRegion

#Region DirectCostsTSEventHandlers

// Procedure - OnStartEdit event handler of the DirectCosts tabular section.
//
&AtClient
Procedure DirectCostOnStartEdit(Item, NewRow, Copy)
	
	If NewRow Then
 
		TabularSectionRow = Items.DirectCost.CurrentData;
		TabularSectionRow.StructuralUnit = MainDepartment;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region InventoryTSEventHandlers

// Procedure - OnStartEdit event handler of the Inventory tabular section.
//
&AtClient
Procedure InventoryOnStartEdit(Item, NewRow, Copy)
	
	If NewRow
	   AND Not Copy Then
		TabularSectionRow = Items.Inventory.CurrentData;
		If ValueIsFilled(MainWarehouse) Then
			TabularSectionRow.StructuralUnit = MainWarehouse;
		Else
			TabularSectionRow.StructuralUnit = MainDepartment;
		EndIf;
	EndIf;
	
	If NewRow AND Copy Then
		Item.CurrentData.ConnectionKey = 0;
		Item.CurrentData.SerialNumbers = "";
	EndIf;
	
	If Item.CurrentItem.Name = "SerialNumbersInventory" Then
		OpenSerialNumbersSelection();
	EndIf;
	
	If Not NewRow Or Copy Then
		Return;	
	EndIf;
	
	Item.CurrentData.GLAccounts = GLAccountsInDocumentsClientServer.GetEmptyGLAccountPresentation();
	
EndProcedure

&AtClient
Procedure InventorySerialNumbersStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	OpenSerialNumbersSelection();
	
EndProcedure

&AtClient
Procedure InventoryBeforeDeleteRow(Item, Cancel)
	
	// Serial numbers
	CurrentData = Items.Inventory.CurrentData;
	DriveClientServer.DeleteRowsByConnectionKey(Object.SerialNumbers, CurrentData);
	
EndProcedure

&AtClient
Procedure InventorySelection(Item, SelectedRow, Field, StandardProcessing)
	
	If Field.Name = "InventoryGLAccounts" Then
		StandardProcessing = False;
		OpenProductGLAccountsForm(SelectedRow);
	EndIf;
	
EndProcedure

&AtClient
Procedure InventoryOnActivateCell(Item)
	
	CurrentData = Items.Inventory.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If ThisIsNewRow Then
		TableCurrentColumn = Items.Inventory.CurrentItem;
		If TableCurrentColumn.Name = "InventoryGLAccounts"
			And Not CurrentData.GLAccountsFilled Then
			SelectedRow = Items.Inventory.CurrentRow;
			OpenProductGLAccountsForm(SelectedRow);
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure InventoryOnEditEnd(Item, NewRow, CancelEdit)
	ThisIsNewRow = False;
EndProcedure

&AtClient
Procedure InventoryGLAccountsStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	SelectedRow = Items.Inventory.CurrentRow;
	OpenProductGLAccountsForm(SelectedRow);
	
EndProcedure

&AtClient
Procedure InventoryQuantityOnChange(Item)
	
	// Serial numbers
	If UseSerialNumbersBalance<>Undefined Then
		WorkWithSerialNumbersClientServer.UpdateSerialNumbersQuantity(Object, Items.Inventory.CurrentData);
	EndIf;
	
EndProcedure

#EndRegion

#Region EventHandlersOfTheInventoryTabularSectionAttributes

&AtClient
Procedure InventoryStructuralUnitOnChange(Item)
	InventoryStructuralUnitOnChangeAtServer();
EndProcedure

// Procedure - event handler OnChange of the Products input field.
//
&AtClient
Procedure InventoryProductsOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("Products", TabularSectionRow.Products);
	
	AddGLAccountsToStructure(StructureData, TabularSectionRow);	
	StructureData.Insert("ObjectParameters", GLAccountsInDocumentsClientServer.GetObjectParameters(Object));
	StructureData = GetDataProductsOnChange(StructureData);
	
	FillPropertyValues(TabularSectionRow, StructureData); 
	TabularSectionRow.MeasurementUnit = StructureData.MeasurementUnit;
	TabularSectionRow.Quantity = 1;
	
	// Serial numbers
	If UseSerialNumbersBalance <> Undefined Then
		WorkWithSerialNumbersClientServer.DeleteSerialNumbersByConnectionKey(Object.SerialNumbers, TabularSectionRow,,UseSerialNumbersBalance);
	EndIf;
	// Serial numbers
	
EndProcedure

#EndRegion

#Region TSAttributesEventHandlersCashAssets

// Procedure - OnStartEdit event handler of the tabular section.
//
&AtClient
Procedure CashAssetsOnStartEdit(Item, NewRow, Copy)
	
	TabularSectionRow = Items.CashAssets.CurrentData;
	
EndProcedure

// Procedure - OnChange event handler of the BankAccountPettyCash input field.
//
&AtClient
Procedure CashAssetsBankAccountPettyCashOnChange(Item)

	TabularSectionRow = Items.CashAssets.CurrentData;

	StructureData = GetDataCashAssetsBankAccountPettyCashOnChange(TabularSectionRow.BankAccountPettyCash);
	
	TabularSectionRow.CashCurrency = StructureData.Currency;
	
	TabularSectionRow.Amount = DriveServer.RecalculateFromCurrencyToAccountingCurrency(TabularSectionRow.AmountCur,
																								TabularSectionRow.CashCurrency,
																								Object.Date);
EndProcedure

// Procedure - OnChange event handler of
// the CashAssetsCurrency edit box in the CashAssets tabular section.
// Recalculates amount by amount (curr.) in the tabular section string.
//
&AtClient
Procedure CashAssetsCashAssetsCurrencyOnChange(Item)
	
	TabularSectionRow = Items.CashAssets.CurrentData;

	TabularSectionRow.Amount = DriveServer.RecalculateFromCurrencyToAccountingCurrency(TabularSectionRow.AmountCur,
																								 TabularSectionRow.CashCurrency,
																								 Object.Date);
EndProcedure

// Procedure - OnChange event handler of
// the AmountCurr edit box in the CashAssest tabular section string.
// Recalculates amount by amount (curr.) in the tabular section string.
//
&AtClient
Procedure CashAssetsAmountCurOnChange(Item)
	
	TabularSectionRow = Items.CashAssets.CurrentData;

	TabularSectionRow.Amount = DriveServer.RecalculateFromCurrencyToAccountingCurrency(TabularSectionRow.AmountCur,
																								 TabularSectionRow.CashCurrency,
																								 Object.Date);
EndProcedure

// Procedure - SelectionStart event handler of the CashAssestCurrency input field.
// Tabular section CashAssets.
//
&AtClient
Procedure CashAssetsCashAssetsCurrencyStartChoice(Item, ChoiceData, StandardProcessing)
	
	TabularSectionRow = Items.CashAssets.CurrentData;
	StructureData = GetDataCashAssetsCashAssetsCurrencyStartChoice(TabularSectionRow.BankAccountPettyCash);
	
	// If type of cash assets is changed, appropriate actions are required.
	If ValueIsFilled(StructureData.CashAssetsType)
	   AND StructureData.CashAssetsType <> Cash Then
		ShowMessageBox(Undefined,NStr("en = 'Cannot change the cash currency of the bank account.'"));
		StandardProcessing = False;
	EndIf;

EndProcedure

#EndRegion

#Region TSAttributesEventHandlersAccountsReceivable

// Procedure - OnChange event handler of the
// Counterparty edit box in the AccountsReceivable tabular section string.
// Generates the Contract
// column value, recalculates amount in the man. currency. account from the amount in the document currency.
//
&AtClient
Procedure AccountsReceivableCounterpartyOnChange(Item)

	TabularSectionRow = Items.AccountsReceivable.CurrentData;
	
	StructureData = GetDataCounterpartyOnChange(TabularSectionRow.Counterparty, Object.Company, "AccountsReceivable");
		
	TabularSectionRow.Contract = StructureData.Contract;
	
	TabularSectionRow.DoOperationsByContracts = StructureData.DoOperationsByContracts;
	TabularSectionRow.DoOperationsByDocuments = StructureData.DoOperationsByDocuments;
	TabularSectionRow.DoOperationsByOrders = StructureData.DoOperationsByOrders;
	
	TabularSectionRow.Amount = DriveServer.RecalculateFromCurrencyToAccountingCurrency(TabularSectionRow.AmountCur,
																								 StructureData.SettlementsCurrency,
																								 Object.Date);
EndProcedure

// Procedure - OnChange event handler of the
// Contract edit box in the AccountsReceivable tabular section string.
// Generates the Contract
// column value, recalculates amount in the man. currency. account from the amount in the document currency.
//
&AtClient
Procedure AccountsReceivableContractOnChange(Item)
	
	TabularSectionRow = Items.AccountsReceivable.CurrentData;
	
	StructureData = GetDataContractOnChange(TabularSectionRow.Contract);

	
	TabularSectionRow.Amount = DriveServer.RecalculateFromCurrencyToAccountingCurrency(TabularSectionRow.AmountCur,
																								 StructureData.SettlementsCurrency,
																								 Object.Date);
EndProcedure

// Procedure - SelectionStart event handler of
// the Contract edit box in the AccountsReceivable tabular section string.
//
&AtClient
Procedure AccountsReceivableAccountsContractBeginChoice(Item, ChoiceData, StandardProcessing)
	
	TabularSectionRow = Items.AccountsReceivable.CurrentData;
	
	FormParameters = GetChoiceFormParameters(Object.Ref, 
		Object.Company, 
		TabularSectionRow.Counterparty, 
		TabularSectionRow.Contract, 
		Undefined, 
		"AccountsReceivable"
	);
	
	If FormParameters.ControlContractChoice Then
		
		StandardProcessing = False;
		OpenForm("Catalog.CounterpartyContracts.Form.ChoiceForm", FormParameters, Item);
		
	EndIf;
	
EndProcedure

// Procedure - OnChange event handler of the
// AmountsCurr edit box in the AccountsReceivable tabular section string.
// recalculates amount in the man. currency. account from the amount in the document currency.
//
&AtClient
Procedure AccountsReceivableAmountCurOnChange(Item)
	
	TabularSectionRow = Items.AccountsReceivable.CurrentData;
	
	StructureData = GetDataContractOnChange(TabularSectionRow.Contract);

	TabularSectionRow.Amount = DriveServer.RecalculateFromCurrencyToAccountingCurrency(TabularSectionRow.AmountCur,
																								 StructureData.SettlementsCurrency,
																								 Object.Date);
EndProcedure

// Procedure - AfterDeletion event handler of the AccountsReceivable tabular section.
//
&AtClient
Procedure AccountsReceivableAfterDeleteRow(Item)
	
	SetAccountsAttributesVisible(, , , "AccountsReceivable");
	
EndProcedure

#EndRegion

#Region TSAttributesEventhandlersAccountsPayable

// Procedure - OnChange event handler of
// the Counterparty edit box in the AccountsPayable tabular section string.
// Generates the Contract
// column value, recalculates amount in the man. currency. account from the amount in the document currency.
//
&AtClient
Procedure AccountsPayableCounterpartyOnChange(Item)

	TabularSectionRow = Items.AccountsPayable.CurrentData;
	
	StructureData = GetDataCounterpartyOnChange(TabularSectionRow.Counterparty, Object.Company, "AccountsPayable");
		
	TabularSectionRow.Contract = StructureData.Contract;
	
	TabularSectionRow.DoOperationsByContracts = StructureData.DoOperationsByContracts;
	TabularSectionRow.DoOperationsByDocuments = StructureData.DoOperationsByDocuments;
	TabularSectionRow.DoOperationsByOrders = StructureData.DoOperationsByOrders;
		
	TabularSectionRow.Amount = DriveServer.RecalculateFromCurrencyToAccountingCurrency(TabularSectionRow.AmountCur,
																								 StructureData.SettlementsCurrency,
																								 Object.Date);
EndProcedure

// Procedure - OnChange event handler of
// the Contract edit box in the AccountsPayable tabular section string.
// Generates the Contract
// column value, recalculates amount in the man. currency. account from the amount in the document currency.
//
&AtClient
Procedure AccountsPayableContractOnChange(Item)
	
	TabularSectionRow = Items.AccountsPayable.CurrentData;
	
	StructureData = GetDataContractOnChange(TabularSectionRow.Contract);

	
	TabularSectionRow.Amount = DriveServer.RecalculateFromCurrencyToAccountingCurrency(TabularSectionRow.AmountCur,
																								 StructureData.SettlementsCurrency,
																								 Object.Date);
EndProcedure

// Procedure - SelectionStart event handler of
// the Contract edit box in the AccountsPayable tabular section string.
//
&AtClient
Procedure AccountsPayableContractBeginChoice(Item, ChoiceData, StandardProcessing)
	
	TabularSectionRow = Items.AccountsPayable.CurrentData;
	
	FormParameters = GetChoiceFormParameters(Object.Ref,
		Object.Company,
		TabularSectionRow.Counterparty,
		TabularSectionRow.Contract, 
		Undefined,
		"AccountsPayable"
	);
	
	If FormParameters.ControlContractChoice Then
		
		StandardProcessing = False;
		OpenForm("Catalog.CounterpartyContracts.Form.ChoiceForm", FormParameters, Item);
		
	EndIf;
	
EndProcedure

// Procedure - OnChange event handler of
// the AmountCurr edit box in the AccountsPayable tabular section string.
// recalculates amount in the man. currency. account from the amount in the document currency.
//
&AtClient
Procedure AccountsPayableAmountCurOnChange(Item)
	
	TabularSectionRow = Items.AccountsPayable.CurrentData;
	
	StructureData = GetDataContractOnChange(TabularSectionRow.Contract);

	TabularSectionRow.Amount = DriveServer.RecalculateFromCurrencyToAccountingCurrency(TabularSectionRow.AmountCur,
																								 StructureData.SettlementsCurrency,
																								 Object.Date);
EndProcedure

// Procedure - AfterDeletion event handler of the AccountsPayable tabular section.
//
&AtClient
Procedure AccountsPayableAfterDeleteRow(Item)
	
	SetAccountsAttributesVisible(, , , "AccountsPayable");
	
EndProcedure

#EndRegion

#Region TSAttributesEventPayrollPayments

// Procedure - OnStartEdit event handler of the Payroll tabular section.
//
&AtClient
Procedure PayrollOnStartEdit(Item, NewRow, Copy)
	
	If NewRow Then
		
		TabularSectionRow = Items.Payroll.CurrentData;
		TabularSectionRow.Currency = CurrencyByDefault;
		
		TabularSectionRow.StructuralUnit = MainDepartment;
		
	EndIf;
	
EndProcedure

// Procedure - OnChange event handler of the
// Currency edit box in the Payroll tabular section string.
// recalculates amount in the man. currency. account from amount in the contract currency.
//
&AtClient
Procedure PayrollCurrencyOnChange(Item)
	
	TabularSectionRow = Items.Payroll.CurrentData;
	TabularSectionRow.Amount = DriveServer.RecalculateFromCurrencyToAccountingCurrency(TabularSectionRow.AmountCur,
																								 TabularSectionRow.Currency,
																								 Object.Date);
EndProcedure

// Procedure - OnChange event handler of the
// AmountCurr edit box in the Payroll tabular section string.
// recalculates amount in the man. currency. account from amount in the contract currency.
//
&AtClient
Procedure PayrollAmountCurOnChange(Item)
	
	TabularSectionRow = Items.Payroll.CurrentData;

	TabularSectionRow.Amount = DriveServer.RecalculateFromCurrencyToAccountingCurrency(TabularSectionRow.AmountCur,
																								 TabularSectionRow.Currency,
																								 Object.Date);
EndProcedure

// Procedure - OnChange event handler of
// the RegistrationPeriod edit box in the Payroll tabular section string.
// Aligns registration period on the month start.
//
&AtClient
Procedure RegisterRecordsPayrollPeriodOnChange(Item)
	
	CurRow = Items.Payroll.CurrentData;
	CurRow.RegistrationPeriod = BegOfMonth(CurRow.RegistrationPeriod);
	
EndProcedure

#EndRegion

#Region TSAttributesEventHandlersAdvanceHolderPayments

// Procedure - OnStartEdit event handler of the AdvanceHolders tabular section.
//
&AtClient
Procedure AdvanceHoldersOnStartEdit(Item, NewRow, Copy)
	
	If NewRow Then
		
		TabularSectionRow = Items.AdvanceHolders.CurrentData;
		TabularSectionRow.Currency = CurrencyByDefault;
		
	EndIf;
	
EndProcedure

// Procedure - OnChange event handler of the
// Currency edit box in the AdvanceHolders tabular section string.
// recalculates amount in the man. currency. account from amount in the contract currency.
//
&AtClient
Procedure AdvanceHoldersCurrencyOnChange(Item)
	
	TabularSectionRow = Items.AdvanceHolders.CurrentData;
	
	TabularSectionRow.Amount = DriveServer.RecalculateFromCurrencyToAccountingCurrency(TabularSectionRow.AmountCur,
																			 TabularSectionRow.Currency,
																			 Object.Date);
EndProcedure

// Procedure - OnChange event handler of the
// AmountCurr edit box in the AdvanceHolders tabular section string.
// recalculates amount in the man. currency. account from amount in the contract currency.
//
&AtClient
Procedure AdvanceHoldersAmountCurOnChange(Item)
	
	TabularSectionRow = Items.AdvanceHolders.CurrentData;

	TabularSectionRow.Amount = DriveServer.RecalculateFromCurrencyToAccountingCurrency(TabularSectionRow.AmountCur,
																								 TabularSectionRow.Currency,
																								 Object.Date);
EndProcedure

#EndRegion

#Region TSAttributesEventHandlersOtherSections

// Procedure - OnChange event handler of the Account input field.
// Transactions tabular section.
//
&AtClient
Procedure OtherSectionsAccountOnChange(Item)
	
	CurrentRow = Items.OtherSections.CurrentData;
	StructureData = GetDataAccountOnChange(CurrentRow.Account);
	
	If Not StructureData.Currency Then
		CurrentRow.Currency = Undefined;
		CurrentRow.AmountCur = Undefined;
	EndIf;
	
EndProcedure

// Procedure - SelectionStart event handler of the Currency input field.
// Transactions tabular section.
//
&AtClient
Procedure OtherSectionsCurrencyStartChoice(Item, ChoiceData, StandardProcessing)
	
	CurrentRow = Items.OtherSections.CurrentData;
	StructureData = GetDataAccountOnChange(CurrentRow.Account);
	
	If Not StructureData.Currency Then
		StandardProcessing = False;
		If ValueIsFilled(CurrentRow.Account) Then
			ShowMessageBox(Undefined,NStr("en = 'Currency flag is not set for the selected account.'"));
		Else
			ShowMessageBox(Undefined,NStr("en = 'Specify the account first.'"));
		EndIf;
	EndIf;
	
EndProcedure

// Procedure - event handler OnChange of the Currency input field.
// Transactions tabular section.
//
&AtClient
Procedure OtherSectionsCurrencyOnChange(Item)
	
	CurrentRow = Items.OtherSections.CurrentData;
	StructureData = GetDataAccountOnChange(CurrentRow.Account);
	
	If Not StructureData.Currency Then
		CurrentRow.Currency = Undefined;
		StandardProcessing = False;
		If ValueIsFilled(CurrentRow.Account) Then
			ShowMessageBox(Undefined,NStr("en = 'Currency flag is not set for the selected account.'"));
		Else
			ShowMessageBox(Undefined,NStr("en = 'Specify the account first.'"));
		EndIf;
	EndIf;
	
EndProcedure

// Procedure - SelectionStart event handler of the AmountCurr input field.
// Transactions tabular section.
//
&AtClient
Procedure OtherSectionsAmountCurStartChoice(Item, ChoiceData, StandardProcessing)
	
	CurrentRow = Items.OtherSections.CurrentData;
	StructureData = GetDataAccountOnChange(CurrentRow.Account);
	
	If Not StructureData.Currency Then
		StandardProcessing = False;
		If ValueIsFilled(CurrentRow.Account) Then
			ShowMessageBox(Undefined,NStr("en = 'Currency flag is not set for the selected account.'"));
		Else
			ShowMessageBox(Undefined,NStr("en = 'Specify the account first.'"));
		EndIf;
	EndIf;
	
EndProcedure

// Procedure - OnChange event handler of the AmountCurr input field.
// Transactions tabular section.
//
&AtClient
Procedure OtherSectionsAmountCurOnChange(Item)
	
	CurrentRow = Items.OtherSections.CurrentData;
	StructureData = GetDataAccountOnChange(CurrentRow.Account);
	
	If Not StructureData.Currency Then
		CurrentRow.AmountCur = Undefined;
		StandardProcessing = False;
		If ValueIsFilled(CurrentRow.Account) Then
			ShowMessageBox(Undefined,NStr("en = 'Currency flag is not set for the selected account.'"));
		Else
			ShowMessageBox(Undefined,NStr("en = 'Specify the account first.'"));
		EndIf;
	EndIf;
	
EndProcedure

// Procedure - event handler AfterWriteAtServer form.
//
&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	FillAddedColumns();
	
	// Filling in the additional attributes of tabular section.
	SetAccountsAttributesVisible(, , , "AccountsPayable");
	SetAccountsAttributesVisible(, , , "AccountsReceivable");
	
EndProcedure

// Procedure - OnChange event handler of the AdvanceFlag box of the AccountsPayable table.
//
&AtClient
Procedure AccountsPayableAdvanceFlagOnChange(Item)
	
	TabularSectionRow = Items.AccountsPayable.CurrentData;
	
	If TypeOf(TabularSectionRow.Document) = Type("DocumentRef.ArApAdjustments") Then
		Return;
	EndIf;
	
	If TabularSectionRow.AdvanceFlag Then
		
		If TypeOf(TabularSectionRow.Document) <> Type("DocumentRef.CashVoucher")
			AND TypeOf(TabularSectionRow.Document) <> Type("DocumentRef.PaymentExpense")
			AND TypeOf(TabularSectionRow.Document) <> Type("DocumentRef.ExpenseReport") Then
			TabularSectionRow.Document = Undefined;
		EndIf;
		
	Else
		
		If TypeOf(TabularSectionRow.Document) = Type("DocumentRef.CashVoucher")
		 OR TypeOf(TabularSectionRow.Document) = Type("DocumentRef.PaymentExpense")
		 OR TypeOf(TabularSectionRow.Document) = Type("DocumentRef.ExpenseReport") Then
			TabularSectionRow.Document = Undefined;
		EndIf;
		
	EndIf;
	
EndProcedure

// Procedure - OnChange event handler of the Document box of the AccountsPayable table.
//
&AtClient
Procedure AccountsPayableDocumentOnChange(Item)
	
	TabularSectionRow = Items.AccountsPayable.CurrentData;
	
	If TypeOf(TabularSectionRow.Document) = Type("DocumentRef.CashVoucher")
	 OR TypeOf(TabularSectionRow.Document) = Type("DocumentRef.PaymentExpense")
	 OR TypeOf(TabularSectionRow.Document) = Type("DocumentRef.ExpenseReport") Then
		TabularSectionRow.AdvanceFlag = True;
	ElsIf TypeOf(TabularSectionRow.Document) <> Type("DocumentRef.ArApAdjustments") Then
		TabularSectionRow.AdvanceFlag = False;
	EndIf;
	
EndProcedure

// Procedure - OnChange event handler of the AdvanceFlag box of the AccountsReceivable table.
//
&AtClient
Procedure AccountsReceivableAdvanceFlagPaymentOnChange(Item)
	
	TabularSectionRow = Items.AccountsReceivable.CurrentData;
	
	If TypeOf(TabularSectionRow.Document) = Type("DocumentRef.ArApAdjustments") Then
		Return;
	EndIf;
	
	If TabularSectionRow.AdvanceFlag Then
		
		If TypeOf(TabularSectionRow.Document) <> Type("DocumentRef.CashReceipt")
			AND TypeOf(TabularSectionRow.Document) <> Type("DocumentRef.PaymentReceipt") Then
			TabularSectionRow.Document = Undefined;
		EndIf;
		
	Else
		
		If TypeOf(TabularSectionRow.Document) = Type("DocumentRef.CashReceipt")
		 OR TypeOf(TabularSectionRow.Document) = Type("DocumentRef.PaymentReceipt") Then
			TabularSectionRow.Document = Undefined;
		EndIf;
		
	EndIf;
	
EndProcedure

// Procedure - OnChange event handler of the Document box of the AccountsReceivable table.
//
&AtClient
Procedure AccountsReceivableDocumentOnChange(Item)
	
	TabularSectionRow = Items.AccountsReceivable.CurrentData;
	
	If TypeOf(TabularSectionRow.Document) = Type("DocumentRef.CashReceipt")
	 OR TypeOf(TabularSectionRow.Document) = Type("DocumentRef.PaymentReceipt") Then
		TabularSectionRow.AdvanceFlag = True;
	ElsIf TypeOf(TabularSectionRow.Document) <> Type("DocumentRef.ArApAdjustments") Then
		TabularSectionRow.AdvanceFlag = False;
	EndIf;
	
EndProcedure

// Procedure - OnChange event handler of the Autogenerate box.
//
&AtClient
Procedure AutogenerationOnChange(Item)
	
	If Object.Autogeneration Then
		For Each TSRow In Object.AccountsReceivable Do
			TSRow.Document = Undefined;
		EndDo;
		
		For Each TSRow In Object.AccountsPayable Do
			TSRow.Document = Undefined;
		EndDo;
		
		For Each TSRow In Object.AdvanceHolders Do
			TSRow.Document = Undefined;
		EndDo;
	EndIf;
	
EndProcedure

#Region LibrariesHandlers

// StandardSubsystems.AdditionalReportsAndDataProcessors
&AtClient
Procedure Attachable_ExecuteAssignedCommand(Command)
	If Not AdditionalReportsAndDataProcessorsClient.ExecuteAllocatedCommandAtClient(ThisForm, Command.Name) Then
		ExecutionResult = Undefined;
		AdditionalReportsAndProcessingsExecuteAllocatedCommandAtServer(Command.Name, ExecutionResult);
		AdditionalReportsAndDataProcessorsClient.ShowCommandExecutionResult(ThisForm, ExecutionResult);
	EndIf;
EndProcedure

&AtServer
Procedure AdditionalReportsAndProcessingsExecuteAllocatedCommandAtServer(ItemName, ExecutionResult)
	AdditionalReportsAndDataProcessors.ExecuteAllocatedCommandAtServer(ThisForm, ItemName, ExecutionResult);
EndProcedure
// End StandardSubsystems.AdditionalReportsAndDataProcessors

// StandardSubsystems.DataImportFromExternalSources
&AtClient
Procedure ImportDataFromExternalSourceInventory(Command)
	
	DataLoadSettings.FillingObjectFullName = "Document.OpeningBalanceEntry.TabularSection.Inventory";
	NotifyDescription = New NotifyDescription("ImportDataFromExternalSourceResultDataProcessor", ThisObject, DataLoadSettings);
	
	DataImportFromExternalSourcesClient.ShowDataImportFormFromExternalSource(DataLoadSettings, NotifyDescription, ThisObject);
	
EndProcedure

&AtClient
Procedure ImportDataFromExternalSourceAccountsReceivable(Command)
	
	DataLoadSettings.FillingObjectFullName = "Document.OpeningBalanceEntry.TabularSection.AccountsReceivable";
	NotifyDescription = New NotifyDescription("ImportDataFromExternalSourceResultDataProcessor", ThisObject, DataLoadSettings);
	
	DataImportFromExternalSourcesClient.ShowDataImportFormFromExternalSource(DataLoadSettings, NotifyDescription, ThisObject);
	
EndProcedure

&AtClient
Procedure ImportDataFromExternalSourceAccountsPayable(Command)
	
	DataLoadSettings.FillingObjectFullName = "Document.OpeningBalanceEntry.TabularSection.AccountsPayable";
	NotifyDescription = New NotifyDescription("ImportDataFromExternalSourceResultDataProcessor", ThisObject, DataLoadSettings);
	
	DataImportFromExternalSourcesClient.ShowDataImportFormFromExternalSource(DataLoadSettings, NotifyDescription, ThisObject);
	
EndProcedure

&AtClient
Procedure ImportDataFromExternalSourceResultDataProcessor(ImportResult, AdditionalParameters) Export
	
	If TypeOf(ImportResult) = Type("Structure") Then
		ProcessPreparedData(ImportResult);
	EndIf;
	
EndProcedure

&AtServer
Procedure ProcessPreparedData(ImportResult)
	
	DataImportFromExternalSourcesOverridable.ImportDataFromExternalSourceResultDataProcessor(ImportResult, Object, ThisObject);
	
EndProcedure

// End StandardSubsystems.DataImportFromExternalSource

// StandardSubsystems.Printing
&AtClient
Procedure Attachable_ExecutePrintCommand(Command)
	PrintManagementClient.ExecuteConnectedPrintCommand(Command, ThisObject, Object);
EndProcedure

// End StandardSubsystems.Printing

#EndRegion

#EndRegion

#EndRegion

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure OpenSerialNumbersSelection()
		
	CurrentDataIdentifier = Items.Inventory.CurrentData.GetID();
	ParametersOfSerialNumbers = SerialNumberPickParameters(CurrentDataIdentifier);
	
	OpenForm("DataProcessor.SerialNumbersSelection.Form", ParametersOfSerialNumbers, ThisObject);

EndProcedure

&AtServer
Function GetSerialNumbersFromStorage(AddressInTemporaryStorage, RowKey)
	
	Modified = True;
	Return WorkWithSerialNumbers.GetSerialNumbersFromStorage(Object, AddressInTemporaryStorage, RowKey);
	
EndFunction

&AtServer
Function SerialNumberPickParameters(CurrentDataIdentifier)
	
	Return WorkWithSerialNumbers.SerialNumberPickParameters(Object, ThisObject.UUID, CurrentDataIdentifier, False);
	
EndFunction

&AtClient
Procedure OpenProductGLAccountsForm(SelectedValue)

	If SelectedValue = Undefined Then
		Return;
	EndIf;

	If Not ReadOnly Then
		LockFormDataForEdit();
	EndIf;

	RowData = Object.Inventory.FindByID(SelectedValue);
	
	ObjectParameters = GLAccountsInDocumentsClientServer.GetObjectParameters(Object);
	StructureData = GetStructureData(ObjectParameters, RowData);
	
	GLAccountsForFilling = GLAccountsInDocumentsClientServer.GetGLAccountsStructure(StructureData);
	GLAccountsForFilling.Insert("TableName",	"Inventory");
	GLAccountsForFilling.Insert("Products",	RowData.Products);

	OpenForm("CommonForm.ProductGLAccounts", GLAccountsForFilling, ThisObject);
	
EndProcedure

&AtClient
Procedure AddGLAccountsToStructure(StructureData, TabRow)
	
	StructureData.Insert("GLAccounts",			TabRow.GLAccounts);
	StructureData.Insert("GLAccountsFilled",	TabRow.GLAccountsFilled);
	StructureData.Insert("InventoryGLAccount",	TabRow.InventoryGLAccount);
	
EndProcedure

&AtServer
Procedure FillAddedColumns(GetGLAccounts = False)
	
	ObjectParameters = GLAccountsInDocumentsClientServer.GetObjectParameters(Object);
	
	Tables = New Array();
	Tables.Add(GetStructureData(ObjectParameters));
	
	GLAccountsInDocuments.FillGLAccountsInTable(Object, Tables, GetGLAccounts);
	
EndProcedure

&AtClient
Procedure GLAccountsChoiceProcessingAtClient(GLAccounts)

	TabRow = Items[GLAccounts.TableName].CurrentData;
	FillPropertyValues(TabRow, GLAccounts);
	Modified = True;
	
	If TabRow.Property("GLAccounts") Then
		ObjectParameters = GLAccountsInDocumentsClientServer.GetObjectParameters(Object);
		StructureData = GetStructureData(ObjectParameters, TabRow);
		
		GLAccountsInDocumentsClientServer.FillProductGLAccountsDescription(StructureData);
		FillPropertyValues(TabRow, StructureData);
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Function GetStructureData(ObjectParameters, RowData = Undefined, ProductName = "Products") Export
	
	StructureData = New Structure("Products, StructuralUnit, InventoryGLAccount, GLAccounts, GLAccountsFilled");
	StructureData.Insert("ObjectParameters", ObjectParameters);
	StructureData.Insert("TabName", "Inventory");
	StructureData.Insert("ProductName", ProductName);
	
	If RowData <> Undefined Then 
		FillPropertyValues(StructureData, RowData);
	EndIf;
	
	Return StructureData;

EndFunction

#EndRegion

#Region Initialize

ThisIsNewRow = False;

#EndRegion