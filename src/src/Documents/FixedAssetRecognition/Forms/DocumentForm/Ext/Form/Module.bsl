#Region GeneralPurposeProceduresAndFunctions

&AtServerNoContext
// Calculates the cost of fixed asset
//
Function GetCostFixedAsset(StructureData)
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	CASE
	|		WHEN InventoryBalance.QuantityBalance = 0
	|			THEN 0
	|		ELSE InventoryBalance.AmountBalance / InventoryBalance.QuantityBalance
	|	END AS Cost,
	|	InventoryBalance.QuantityBalance
	|FROM
	|	AccumulationRegister.Inventory.Balance(
	|			&Period,
	|			Products = &Products
	|				AND Characteristic = &Characteristic) AS InventoryBalance";
	
	Query.SetParameter("Period",				StructureData.Period);
	Query.SetParameter("Products",	StructureData.Products);
	Query.SetParameter("Characteristic",		StructureData.Characteristic);
	
	QueryResult = Query.Execute();
	If QueryResult.IsEmpty() Then
		Return 0;
	EndIf;
	
	Selection = QueryResult.Select(QueryResultIteration.ByGroups);
	Selection.Next();	
	
	If StructureData.Quantity > Selection.QuantityBalance Then
		Return 0;
	Else
		Return Selection.Cost * StructureData.Quantity;
	EndIf;
	
EndFunction

&AtServerNoContext
// It receives data set from server for the ContractOnChange procedure.
//
Function GetDataDateOnChange(DocumentRef, DateNew, DateBeforeChange)
	
	DATEDIFF = DriveServer.CheckDocumentNumber(DocumentRef, DateNew, DateBeforeChange);
	
	StructureData = New Structure();
	
	StructureData.Insert(
		"DATEDIFF",
		DATEDIFF
	);
	
	Return StructureData;
	
EndFunction

&AtServer
// It receives data set from server for the ContractOnChange procedure.
//
Function GetCompanyDataOnChange(Company)
	
	FillAddedColumns(True);
	StructureData = New Structure();
	
	StructureData.Insert(
		"Counterparty",
		DriveServer.GetCompany(Company)		
	);
	
	Return StructureData;
	
EndFunction

&AtServer
Procedure StructuralUnitOnChangeAtServer()
	FillAddedColumns(True);
EndProcedure

&AtServerNoContext
// Receives the set of data from the server for the ProductsOnChange procedure.
//
Function GetDataProductsOnChange(StructureData)
	
	GLAccountsInDocuments.FillProductGLAccountsInStructure(StructureData);
	StructureData.Insert("MeasurementUnit", StructureData.Products.MeasurementUnit);
	
	Return StructureData;
	
EndFunction

&AtServerNoContext
// Receives the set of data from the server for the ProductsOnChange procedure.
//
Function GetDataFixedAsset(FixedAsset)
	
	StructureData = New Structure();
	
	StructureData.Insert("MethodOfDepreciationProportionallyProductsAmount", FixedAsset.DepreciationMethod = Enums.FixedAssetDepreciationMethods.ProportionallyToProductsVolume);
	
	Return StructureData;
	
EndFunction

&AtClient
Procedure OpenProductGLAccountsForm(SelectedValue)

	If SelectedValue = Undefined Then
		Return;
	EndIf;

	If Not ReadOnly Then
		LockFormDataForEdit();
	EndIf;

	ObjectParameters = GLAccountsInDocumentsClientServer.GetObjectParameters(Object);
	StructureData = GetStructureData(ObjectParameters);
	
	GLAccountsForFilling = GLAccountsInDocumentsClientServer.GetGLAccountsStructure(StructureData);
	GLAccountsForFilling.Insert("TableName",	"");
	GLAccountsForFilling.Insert("Products",		Object.Products);

	OpenForm("CommonForm.ProductGLAccounts", GLAccountsForFilling, ThisObject);
	
EndProcedure

&AtServer
Procedure FillAddedColumns(GetGLAccounts = False)
	
	ObjectParameters = GLAccountsInDocumentsClientServer.GetObjectParameters(Object);
	
	ProductInHeader = GetStructureData(ObjectParameters);
	
	Tables = New Array();
	Tables.Add(ProductInHeader);
	
	GLAccountsInDocuments.FillGLAccountsInTable(Object, Tables, GetGLAccounts);
	
	Items.GLAccountsLink.Title = ProductInHeader.GLAccounts;
	
EndProcedure

&AtClient
Procedure GLAccountsChoiceProcessingAtClient(GLAccounts)

	FillPropertyValues(Object, GLAccounts);
	Modified = True;
	
	ObjectParameters = GLAccountsInDocumentsClientServer.GetObjectParameters(Object);
	StructureData = GetStructureData(ObjectParameters);
	
	GLAccountsInDocumentsClientServer.FillProductGLAccountsDescription(StructureData);
	FillPropertyValues(Object, StructureData);
	Items.GLAccountsLink.Title = StructureData.GLAccounts;
	
EndProcedure

&AtClientAtServerNoContext
Function GetStructureData(ObjectParameters, ProductName = "Products") Export
	
	StructureData = New Structure;
	StructureData.Insert("Products",			ObjectParameters.Products);
	StructureData.Insert("InventoryGLAccount",	ObjectParameters.InventoryGLAccount);
	StructureData.Insert("GLAccounts",			"");
	StructureData.Insert("ObjectParameters", ObjectParameters);
	StructureData.Insert("TabName", "DataAboutObject");
	StructureData.Insert("ProductName", ProductName);
	
	Return StructureData;

EndFunction

#EndRegion

#Region ProcedureFormEventHandlers

&AtClient
Procedure ChoiceProcessing(SelectedValue, ChoiceSource)
	
	If ChoiceSource.FormName = "CommonForm.ProductGLAccounts" Then
		GLAccountsChoiceProcessingAtClient(SelectedValue);
	EndIf;
	
EndProcedure

&AtServer
// Procedure - event handler "OnCreateAtServer".
// The procedure implements
// - form attribute initialization,
// - setting of the form functional options parameters.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	DriveServer.FillDocumentHeader(
		Object,
		,
		Parameters.CopyingValue,
		Parameters.Basis,
		PostingIsAllowed,
		Parameters.FillingValues
	);
	
	DocumentDate = Object.Date;
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentDate();
	EndIf;
	
	ParentCompany = DriveServer.GetCompany(Object.Company);
	
	User = Users.CurrentUser();
	
	SettingValue = DriveReUse.GetValueByDefaultUser(User, "MainDepartment");
	MainDepartment = ?(ValueIsFilled(SettingValue), SettingValue, Catalogs.BusinessUnits.MainDepartment);
	
	FillAddedColumns();
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisForm, Items.ImportantCommandsGroup);
	// End StandardSubsystems.Printing
	
EndProcedure

// Procedure - OnReadAtServer event handler.
//
&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	FillAddedColumns();
	ClosingDates.ObjectOnReadAtServer(ThisForm, CurrentObject);
	
EndProcedure

&AtClient
// Procedure - event handler AfterWriting.
//
Procedure AfterWrite(WriteParameters)
	
	Notify("FixedAssetsStatesUpdate");
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	FillAddedColumns();
EndProcedure

#EndRegion

#Region ProcedureEventHandlersOfFormAttributes

&AtClient
Procedure QuantityOnChange(Item)
	
	If Object.Quantity = 0 Then
		Object.Amount = 0;
	Else
		StructureData = New Structure("Products, Characteristic", Object.Products, Object.Characteristic);
		StructureData.Insert("Period",				Object.Date);
		StructureData.Insert("Products",	Object.Products);
		StructureData.Insert("Characteristic", 		Object.Characteristic);
		StructureData.Insert("Quantity",			Object.Quantity);
		
		Object.Amount = GetCostFixedAsset(StructureData);
	EndIf;
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of the Date input field.
// The procedure determines the situation when after changing the date
// of a document this document is found in another period
// of documents enumeration, and in this case the procedure assigns new unique number to the document.
// Overrides the corresponding form parameter.
//
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

&AtClient
// Procedure - event handler OnChange of the Company input field.
// In procedure the document number
// is cleared, and also the form functional options are configured.
// Overrides the corresponding form parameter.
//
Procedure CompanyOnChange(Item)
	
	// Company change event data processor.
	Object.Number = "";
	StructureData = GetCompanyDataOnChange(Object.Company);
	Counterparty = StructureData.Counterparty;
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of the Products input field.
//
Procedure ProductsOnChange(Item)
	
	ObjectParameters = GLAccountsInDocumentsClientServer.GetObjectParameters(Object);
	StructureDataWithoutGLAccounts = GetStructureData(ObjectParameters);
	StructureData = GetDataProductsOnChange(StructureDataWithoutGLAccounts);
	
	Object.MeasurementUnit = StructureData.MeasurementUnit;
	Object.InventoryGLAccount = StructureData.InventoryGLAccount;
	Items.GLAccountsLink.Title = StructureData.GLAccounts;
	
EndProcedure

&AtClient
Procedure StructuralUnitOnChange(Item)
	StructuralUnitOnChangeAtServer();
EndProcedure

&AtClient
Procedure GLAccountsCommand(Command)
	OpenProductGLAccountsForm(Object);
EndProcedure

#Region TabularSectionAttributeEventHandlers

&AtClient
// Procedure - OnStartEdit event handler of the FixedAssets tabular section.
//
Procedure FixedAssetsOnStartEdit(Item, NewRow, Copy)
	
	If NewRow Then
 
		TabularSectionRow = Items.FixedAssets.CurrentData;
		TabularSectionRow.StructuralUnit = MainDepartment;
		
	EndIf;
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of
// input field WorksProductsVolumeForDepreciationCalculation in
// string of tabular section FixedAssets.
//
Procedure FixedAssetsVolumeProductsWorksForDepreciationCalculationOnChange(Item)
	
	TabularSectionRow = Items.FixedAssets.CurrentData;
	StructureData = GetDataFixedAsset(TabularSectionRow.FixedAsset);
	
	If Not StructureData.MethodOfDepreciationProportionallyProductsAmount Then
		ShowMessageBox(Undefined,NStr("en = '""Product (work) volume for calculating depreciation"" cannot be filled in for the specified depreciation method.'"));
		TabularSectionRow.AmountOfProductsServicesForDepreciationCalculation = 0;
	EndIf;
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of
// input field UsagePeriodForDepreciationCalculation in string
// of tabular section FixedAssets.
//
Procedure FixedAssetsUsagePeriodForDepreciationCalculationOnChange(Item)
	
	TabularSectionRow = Items.FixedAssets.CurrentData;
	StructureData = GetDataFixedAsset(TabularSectionRow.FixedAsset);
	
	If StructureData.MethodOfDepreciationProportionallyProductsAmount Then
		ShowMessageBox(Undefined,NStr("en = 'Cannot fill in ""Useful life for calculating depreciation"" for the specified method of depreciation.'"));
		TabularSectionRow.UsagePeriodForDepreciationCalculation = 0;
	EndIf;
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of
// input field FixedAsset in string of tabular section FixedAssets.
//
Procedure FixedAssetsFixedAssetOnChange(Item)
	
	TabularSectionRow = Items.FixedAssets.CurrentData;
	StructureData = GetDataFixedAsset(TabularSectionRow.FixedAsset);
	
	If StructureData.MethodOfDepreciationProportionallyProductsAmount Then
		TabularSectionRow.UsagePeriodForDepreciationCalculation = 0;
	Else
		TabularSectionRow.AmountOfProductsServicesForDepreciationCalculation = 0;
	EndIf;
	
EndProcedure

#EndRegion

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

// StandardSubsystems.Printing
&AtClient
Procedure Attachable_ExecutePrintCommand(Command)
	PrintManagementClient.ExecuteConnectedPrintCommand(Command, ThisObject, Object);
EndProcedure

// End StandardSubsystems.Printing

#EndRegion

#EndRegion
