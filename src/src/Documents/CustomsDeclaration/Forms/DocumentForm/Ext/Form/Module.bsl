
#Region Variables

&AtClient
Var CurrentCommodityGroup;

&AtClient
Var CurrentProduct;

&AtClient
Var CurrentInvoice;

&AtClient
Var ThisIsNewRow;

#EndRegion

#Region FormEventHandlers

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	FillAddedColumns();
EndProcedure

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	ObjectVersioning.OnCreateAtServer(ThisObject);
	
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisObject);
	
	DataImportFromExternalSources.OnCreateAtServer(Metadata.Documents.CustomsDeclaration.TabularSections.Inventory, DataLoadSettings, ThisObject);
	
	PrintManagement.OnCreateAtServer(ThisObject);
	
	PropertiesManagement.OnCreateAtServer(ThisObject, Object, "AdditionalAttributesGroup");
	
	If Parameters.Key.IsEmpty() Then
		
		OnCreateOnReadCommonActions();
		
	EndIf;
	
	PickProductsInDocuments.AssignPickForm(SelectionOpenParameters, Object.Ref.Metadata().Name, "Inventory");
	
	Items.InventoryDataImportFromExternalSources.Visible =
		AccessRight("Use", Metadata.DataProcessors.DataImportFromExternalSources);
	FillAddedColumns();		
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(SelectedValue, ChoiceSource)
	
	If ChoiceSource.FormName = "Document.SupplierInvoice.Form.ChoiceForm" Then
		
		ProcessInvoicesSelection(SelectedValue);
		RefreshFormFooter();
		
	ElsIf ChoiceSource.FormName = "CommonForm.ProductGLAccounts" Then
		GLAccountsChoiceProcessingAtClient(SelectedValue);
	EndIf;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If PropertiesManagementClient.ProcessAlerts(ThisObject, EventName, Parameter) Then
		
		UpdateAdditionalAttributesItems();
		
	EndIf;
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	FillAddedColumns();
	PropertiesManagement.OnReadAtServer(ThisObject, CurrentObject);
	
	OnCreateOnReadCommonActions();
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	PropertiesManagement.BeforeWriteAtServer(ThisObject, CurrentObject);

EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	PropertiesManagement.FillCheckProcessing(ThisObject, Cancel, CheckedAttributes);

EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandler

&AtClient
Procedure CounterpartyOnChange(Item)
	
	CounterpartyBeforeChange = Counterparty;
	Counterparty = Object.Counterparty;
	
	If CounterpartyBeforeChange <> Object.Counterparty Then
		
		StructureData = GetDataCounterpartyOnChange();
		
		Object.Contract = StructureData.Contract;
		ContractBeforeChange = Contract;
		Contract = Object.Contract;
		
		CounterpartyOnChangeFragment(ContractBeforeChange, StructureData);
		
	Else
		
		Object.Contract = Contract;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ContractOnChange(Item)
	
	ProcessContractChange();
	
EndProcedure

&AtClient
Procedure ContractStartChoice(Item, ChoiceData, StandardProcessing)
	
	FormParameters = GetContractChoiceFormParameters(Object.Ref, Object.Company, Object.Counterparty, Object.Contract, Undefined);
	If FormParameters.ControlContractChoice Then
		
		StandardProcessing = False;
		OpenForm("Catalog.CounterpartyContracts.Form.ChoiceForm", FormParameters, Item);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OtherDutyToExpensesOnChange(Item)
	
	SetOtherDutyGLAccountVisible();
	
EndProcedure

&AtClient
Procedure SupplierOnChange(Item)
	
	If Supplier <> Object.Supplier Then
		
		If Object.CommodityGroups.Count() Or Object.Inventory.Count() Then
			
			ShowQueryBox(
				New NotifyDescription("SupplierChangeQueryBoxProcessing", ThisObject),
				InventoryWillBeClearedMessageText(),
				QuestionDialogMode.YesNo);
			
		Else
			
			SupplierChangeProcessing();
			
		EndIf;
		
	Else
		
		Object.SupplierContract = SupplierContract;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure SupplierContractOnChange(Item)
	
	If Not SupplierContract = Object.SupplierContract Then
		
		If Object.CommodityGroups.Count() Or Object.Inventory.Count() Then
			
			ShowQueryBox(
				New NotifyDescription("SupplierContractChangeQueryBoxProcessing", ThisObject),
				InventoryWillBeClearedMessageText(),
				QuestionDialogMode.YesNo);
			
		Else
		
			ProcessSupplierContractChange();
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure SupplierContractStartChoice(Item, ChoiceData, StandardProcessing)
	
	FormParameters = GetSupplierContractChoiceFormParameters(
		PredefinedValue("Document.SupplierInvoice.EmptyRef"),
		Object.Company,
		Object.Supplier,
		Object.SupplierContract);
		
	If FormParameters.ControlContractChoice Then
		
		StandardProcessing = False;
		OpenForm("Catalog.CounterpartyContracts.Form.ChoiceForm", FormParameters, Item);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure DateOnChange(Item)
	
	If Date <> Object.Date Then
		
		DateChangeProcessing();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CompanyOnChange(Item)
	
	If Company <> Object.Company Then
		
		If Object.CommodityGroups.Count() Or Object.Inventory.Count() Then
			
			ShowQueryBox(
				New NotifyDescription("CompanyChangeQueryBoxProcessing", ThisObject),
				InventoryWillBeClearedMessageText(),
				QuestionDialogMode.YesNo);
			
		Else
			
			CompanyChangeProcessing();
			
		EndIf;
		
	Else
		
		Object.Contract = Contract;
		Object.SupplierContract = SupplierContract;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure EditPricesAndCurrency(Item, StandardProcessing)
	
	StandardProcessing = False;
	ProcessChangesOnButtonPricesAndCurrencies(Object.DocumentCurrency);
	Modified = True;
	
EndProcedure

&AtClient
Procedure VATIsDueOnChange(Item)
	VATIsDueOnChangeAtServer();
EndProcedure

#EndRegion

#Region FormTableEventHandlersOfCommodityGroupsTable

&AtClient
Procedure CommodityGroupsOnActivateRow(Item)
	
	CommodityGroupsRow = Item.CurrentData;
	
	If CommodityGroupsRow = Undefined Then
		
		CurrentCommodityGroup = Undefined;
		
	Else
		
		CurrentCommodityGroup = CommodityGroupsRow.CommodityGroup;
		
	EndIf;
	
	AttachIdleHandler("ActivateCommodityGroup", 0.2, True);
	
EndProcedure

&AtClient
Procedure CommodityGroupsOnStartEdit(Item, NewRow, Clone)
	
	If NewRow Then
		
		NewCommodityGroup = NewCommodityGroup();
		Item.CurrentData.CommodityGroup = NewCommodityGroup;
		CurrentCommodityGroup = NewCommodityGroup;
		ModifyInventoryCommodityGroupChoiceList(Undefined, NewCommodityGroup);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CommodityGroupsBeforeEditEnd(Item, NewRow, CancelEdit, Cancel)
	
	If NewRow And CancelEdit Then
		
		ModifyInventoryCommodityGroupChoiceList(CurrentCommodityGroup, Undefined);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CommodityGroupsBeforeDeleteRow(Item, Cancel)
	
	CGSelectedRows = Items.CommodityGroups.SelectedRows;
	
	For Each CommodityGroupsRowID In CGSelectedRows Do
		
		CommodityGroupsRow = Object.CommodityGroups.FindByID(CommodityGroupsRowID);
		
		ModifyInventoryCommodityGroupChoiceList(CommodityGroupsRow.CommodityGroup, Undefined);
		
		InventoryRows = Object.Inventory.FindRows(New Structure("CommodityGroup", CommodityGroupsRow.CommodityGroup));
		
		For Each InventoryRow In InventoryRows Do
			
			InventoryRow.CommodityGroup = 0;
			
		EndDo;
		
	EndDo;
	
EndProcedure

&AtClient
Procedure CommodityGroupsCommodityGroupOnChange(Item)
	
	CommodityGroupsRow = Items.CommodityGroups.CurrentData;
	
	NewCommodityGroup = CommodityGroupsRow.CommodityGroup;
	
	If Object.CommodityGroups.FindRows(New Structure("CommodityGroup", NewCommodityGroup)).Count() > 1 Then
		
		CommodityGroupsRow.CommodityGroup = CurrentCommodityGroup;
		
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Commodity group ""%1"" already exists. Please specify different value.'"),
			NewCommodityGroup);
			
		CommodityGroupField = CommonUseClientServer.PathToTabularSection("Object.CommodityGroups", CommodityGroupsRow.LineNumber, "CommodityGroup");
		
		CommonUseClientServer.MessageToUser(MessageText, , CommodityGroupField);
		
	ElsIf CommodityGroupsRow.CommodityGroup <> CurrentCommodityGroup Then
		
		InventoryRows = Object.Inventory.FindRows(New Structure("CommodityGroup", CurrentCommodityGroup));
		
		For Each InventoryRow In InventoryRows Do
			
			InventoryRow.CommodityGroup = NewCommodityGroup;
			
		EndDo;
		
		ModifyInventoryCommodityGroupChoiceList(CurrentCommodityGroup, NewCommodityGroup);
		
		CurrentCommodityGroup = NewCommodityGroup;
		
		ActivateCommodityGroup();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CommodityGroupsOriginOnChange(Item)
	
	CommodityGroupsRow = Items.CommodityGroups.CurrentData;
	
	InventoryRows = Object.Inventory.FindRows(New Structure("CommodityGroup", CurrentCommodityGroup));
	
	For Each InventoryRow In InventoryRows Do
		
		InventoryRow.Origin = CommodityGroupsRow.Origin;
		
	EndDo;
	
	
EndProcedure

&AtClient
Procedure CommodityGroupsCustomsValueOnChange(Item)
	
	CG_CalculationSettings = New Structure;
	CG_CalculationSettings.Insert("CalculateDutyAmount");
	CG_CalculationSettings.Insert("CalculateOtherDutyAmount");
	CG_CalculationSettings.Insert("CalculateVATAmount");
	
	Inv_CalculationSettings = New Structure;
	Inv_CalculationSettings.Insert("CalculateDutyAmount");
	Inv_CalculationSettings.Insert("CalculateOtherDutyAmount");
	Inv_CalculationSettings.Insert("CalculateExciseAmount");
	Inv_CalculationSettings.Insert("CalculateVATAmount");
	
	CommodityGroupsAmountsCalculations(CG_CalculationSettings, Inv_CalculationSettings);
	
EndProcedure

&AtClient
Procedure CommodityGroupsDutyRateOnChange(Item)
	
	CG_CalculationSettings = New Structure;
	CG_CalculationSettings.Insert("CalculateDutyAmount");
	CG_CalculationSettings.Insert("CalculateVATAmount");
	
	Inv_CalculationSettings = New Structure;
	Inv_CalculationSettings.Insert("CalculateDutyAmount");
	Inv_CalculationSettings.Insert("CalculateVATAmount");
	
	CommodityGroupsAmountsCalculations(CG_CalculationSettings, Inv_CalculationSettings);
	
EndProcedure

&AtClient
Procedure CommodityGroupsDutyAmountOnChange(Item)
	
	CG_CalculationSettings = New Structure;
	CG_CalculationSettings.Insert("CalculateDutyRate");
	CG_CalculationSettings.Insert("CalculateVATAmount");
	
	Inv_CalculationSettings = New Structure;
	Inv_CalculationSettings.Insert("CalculateDutyAmount");
	Inv_CalculationSettings.Insert("CalculateVATAmount");
	
	CommodityGroupsAmountsCalculations(CG_CalculationSettings, Inv_CalculationSettings);
	
EndProcedure

&AtClient
Procedure CommodityGroupsOtherDutyRateOnChange(Item)
	
	CG_CalculationSettings = New Structure;
	CG_CalculationSettings.Insert("CalculateOtherDutyAmount");
	CG_CalculationSettings.Insert("CalculateVATAmount");
	
	Inv_CalculationSettings = New Structure;
	Inv_CalculationSettings.Insert("CalculateOtherDutyAmount");
	Inv_CalculationSettings.Insert("CalculateVATAmount");
	
	CommodityGroupsAmountsCalculations(CG_CalculationSettings, Inv_CalculationSettings);
	
EndProcedure

&AtClient
Procedure CommodityGroupsOtherDutyAmountOnChange(Item)
	
	CG_CalculationSettings = New Structure;
	CG_CalculationSettings.Insert("CalculateOtherDutyRate");
	CG_CalculationSettings.Insert("CalculateVATAmount");
	
	Inv_CalculationSettings = New Structure;
	Inv_CalculationSettings.Insert("CalculateOtherDutyAmount");
	Inv_CalculationSettings.Insert("CalculateVATAmount");
	
	CommodityGroupsAmountsCalculations(CG_CalculationSettings, Inv_CalculationSettings);
	
EndProcedure

&AtClient
Procedure CommodityGroupsExciseAmountOnChange(Item)
	
	CG_CalculationSettings = New Structure;
	CG_CalculationSettings.Insert("CalculateVATAmount");
	
	Inv_CalculationSettings = New Structure;
	Inv_CalculationSettings.Insert("CalculateExciseAmount");
	Inv_CalculationSettings.Insert("CalculateVATAmount");
	
	CommodityGroupsAmountsCalculations(CG_CalculationSettings, Inv_CalculationSettings);
	
EndProcedure

&AtClient
Procedure CommodityGroupsVATRateOnChange(Item)
	
	CG_CalculationSettings = New Structure;
	CG_CalculationSettings.Insert("CalculateVATAmount");
	
	Inv_CalculationSettings = New Structure;
	Inv_CalculationSettings.Insert("CalculateVATAmount");
	
	CommodityGroupsAmountsCalculations(CG_CalculationSettings, Inv_CalculationSettings);
	
EndProcedure

#EndRegion

#Region FormTableEventHandlersOfInventoryTable

&AtClient
Procedure InventoryOnActivateRow(Item)
	
	InventoryRow = Item.CurrentData;
	
	If InventoryRow = Undefined Then
		
		CurrentProduct = Undefined;
		CurrentInvoice = Undefined;
		
	Else
		
		If Not InventoryRow.Products = CurrentProduct Then
			
			CurrentProduct = InventoryRow.Products;
			
			FillProductDependentChoiceLists();
			
		EndIf;
		
		If Not InventoryRow.StructuralUnit = CurrentInvoice Then
			
			CurrentInvoice = InventoryRow.Invoice;
			
			FillInvoiceDependentChoiceLists();
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure InventoryOnStartEdit(Item, NewRow, Clone)
	
	If NewRow Then
		
		CommodityGroupsRow = Items.CommodityGroups.CurrentData;
		
		If Not CommodityGroupsRow = Undefined Then
			
			InventoryRow = Item.CurrentData;
			
			InventoryRow.CommodityGroup = CommodityGroupsRow.CommodityGroup;
			InventoryRow.Origin = CommodityGroupsRow.Origin;
			
		EndIf;
		
	EndIf;
	
	If Not NewRow Or Clone Then
		Return;	
	EndIf;
	
	Item.CurrentData.GLAccounts = GLAccountsInDocumentsClientServer.GetEmptyGLAccountPresentation();
	
EndProcedure

&AtClient
Procedure InventorySelection(Item, SelectedRow, Field, StandardProcessing)
	
	If Field.Name = "InventoryGLAccounts" Then
		StandardProcessing = False;
		OpenProductGLAccountsForm(Items.Inventory.CurrentData);
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
			OpenProductGLAccountsForm(CurrentData);
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
	OpenProductGLAccountsForm(Items.Inventory.CurrentData);
	
EndProcedure


&AtClient
Procedure InventoryProductsOnChange(Item)
	
	CurrentProduct = Items.Inventory.CurrentData.Products;
	
	FillProductDependentChoiceLists();
	
EndProcedure

&AtClient
Procedure InventoryCustomsValueOnChange(Item)
	
	CalculationSettings = New Structure;
	CalculationSettings.Insert("CalculateDutyAmount");
	CalculationSettings.Insert("CalculateOtherDutyAmount");
	CalculationSettings.Insert("CalculateVATAmount");
	
	InventoryAmountsCalculations(CalculationSettings);
	
EndProcedure

&AtClient
Procedure InventoryDutyAmountOnChange(Item)
	
	CalculationSettings = New Structure;
	CalculationSettings.Insert("CalculateVATAmount");
	
	InventoryAmountsCalculations(CalculationSettings);
	
EndProcedure

&AtClient
Procedure InventoryOtherDutyAmountOnChange(Item)
	
	CalculationSettings = New Structure;
	CalculationSettings.Insert("CalculateVATAmount");
	
	InventoryAmountsCalculations(CalculationSettings);
	
EndProcedure

&AtClient
Procedure InventoryExciseAmountOnChange(Item)
	
	CalculationSettings = New Structure;
	CalculationSettings.Insert("CalculateVATAmount");
	
	InventoryAmountsCalculations(CalculationSettings);
	
EndProcedure

&AtClient
Procedure InventoryInvoiceOnChange(Item)
	
	InventoryRow = Items.Inventory.CurrentData;
	
	CurrentInvoice = InventoryRow.Invoice;
	
	FillInvoiceDependentChoiceLists();
	
	StructuralUnitChoiceList = Items.InventoryStructuralUnit.ChoiceList;
	
	If StructuralUnitChoiceList.Count() Then
		
		InventoryRow.StructuralUnit = StructuralUnitChoiceList[0].Value;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure ShowAll(Command)
	
	ShowAllItem = Items.ShowAll;
	
	ShowAllItem.Check = Not ShowAllItem.Check;
	
	ActivateCommodityGroup();
	
EndProcedure

&AtClient
Procedure AllocateCostsToInventory(Command)
	
	ClearMessages();
	
	ErrorText = "";
	
	If Object.CommodityGroups.Count() = 0 Or Object.Inventory.Count() = 0 Then
		ErrorText = NStr("en = 'Please create at least one commodity group and fill in the inventory.'");
		CommonUseClientServer.MessageToUser(ErrorText, , "Object.CommodityGroups");
		Return;
	EndIf;
	
	FilterStructure = New Structure("CommodityGroup");
	CGList = "";
	CGSelectedRows = Items.CommodityGroups.SelectedRows;
	
	For Each CommodityGroupsRowID In CGSelectedRows Do
		
		CommodityGroupsRow = Object.CommodityGroups.FindByID(CommodityGroupsRowID);
		
		CommodityGroup = Format(CommodityGroupsRow.CommodityGroup, "NZ=0; NG=0");
		CGList = CGList + ?(Not IsBlankString(CGList), ", ", "") + CommodityGroup;
		
		If CommodityGroupsRow.CustomsValue = 0. Then
			ErrorText = NStr("en = 'Please specify the customs value in the commodity group #%1.'");
			ErrorText = StringFunctionsClientServer.SubstituteParametersInString(ErrorText, CommodityGroup);
			CustomsValueField = CommonUseClientServer.PathToTabularSection("Object.CommodityGroups", CommodityGroupsRow.LineNumber, "CustomsValue");
			CommonUseClientServer.MessageToUser(ErrorText, , CustomsValueField);
		EndIf;
		
		FilterStructure.CommodityGroup = CommodityGroupsRow.CommodityGroup;
		InventoryRows = Object.Inventory.FindRows(FilterStructure);
		
		If InventoryRows.Count() = 0 Then
			
			ErrorText = NStr("en = 'Please fill in the inventory of the commodity group #%1.'");
			ErrorText = StringFunctionsClientServer.SubstituteParametersInString(ErrorText, CommodityGroup);
			CommonUseClientServer.MessageToUser(ErrorText, , "Object.Inventory");
			
		Else
			
			For Each InventoryRow In InventoryRows Do
				
				If InventoryRow.CustomsValue = 0 Then
					ErrorText = NStr("en = 'Please specify the customs value for the product in the line #%2 of the commodity group #%1.'");
					ErrorText = StringFunctionsClientServer.SubstituteParametersInString(ErrorText, CommodityGroup, Format(InventoryRow.LineNumber, "NZ=0; NG=0"));
					CustomsValueField = CommonUseClientServer.PathToTabularSection("Object.Inventory", InventoryRow.LineNumber, "CustomsValue");
					CommonUseClientServer.MessageToUser(ErrorText, , CustomsValueField);
				EndIf;
				
			EndDo;
			
		EndIf;
		
	EndDo;
	
	If ErrorText <> "" Or CGSelectedRows.Count() = 0 Then
		Return;
	EndIf;
	
	AllocateCostsToInventoryAtServer();
	
	RefreshFormFooter();
	
	NotificationText = ?(CGSelectedRows.Count() > 1,
		NStr("en = 'Customs fees of the commodity groups #%1 have been allocated.'"),
		NStr("en = 'Customs fees of the commodity group #%1 have been allocated.'"));
	ShowUserNotification(
		NStr("en = 'Done'"), ,
		StringFunctionsClientServer.SubstituteParametersInString(NotificationText, CGList),
		PictureLib.Information32);
	
EndProcedure

&AtClient
Procedure FillCostsByInventory(Command)
	
	FilterStructure = New Structure("CommodityGroup");
	
	For Each CommodityGroupsRowID In Items.CommodityGroups.SelectedRows Do
		
		CommodityGroupsRow = Object.CommodityGroups.FindByID(CommodityGroupsRowID);
		
		If Not CommodityGroupsRow = Undefined Then
			
			FilterStructure.CommodityGroup = CommodityGroupsRow.CommodityGroup;
			
			InventoryRows = Object.Inventory.FindRows(FilterStructure);
			
			CommodityGroupsRow.CustomsValue = 0;
			CommodityGroupsRow.DutyAmount = 0;
			CommodityGroupsRow.OtherDutyAmount = 0;
			CommodityGroupsRow.ExciseAmount = 0;
			CommodityGroupsRow.VATAmount = 0;
			
			For Each InventoryRow In InventoryRows Do
				
				CommodityGroupsRow.CustomsValue		= CommodityGroupsRow.CustomsValue		+ InventoryRow.CustomsValue;
				CommodityGroupsRow.DutyAmount		= CommodityGroupsRow.DutyAmount			+ InventoryRow.DutyAmount;
				CommodityGroupsRow.OtherDutyAmount	= CommodityGroupsRow.OtherDutyAmount	+ InventoryRow.OtherDutyAmount;
				CommodityGroupsRow.ExciseAmount		= CommodityGroupsRow.ExciseAmount		+ InventoryRow.ExciseAmount;
				CommodityGroupsRow.VATAmount		= CommodityGroupsRow.VATAmount			+ InventoryRow.VATAmount;
				
			EndDo;
			
			CalculateDutyRate(CommodityGroupsRow);
			CalculateOtherDutyRate(CommodityGroupsRow);
			
		EndIf;
		
	EndDo;
	
EndProcedure

&AtClient
Procedure InventoryPickByInvoices(Command)
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("ChoiceMode", True);
	ParametersStructure.Insert("MultipleChoice", True);
	
	FilterStructure = New Structure;
	FilterStructure.Insert("Posted", True);
	FilterStructure.Insert("VATTaxation", PredefinedValue("Enum.VATTaxationTypes.ForExport"));
	FilterStructure.Insert("Company", Object.Company);
	FilterStructure.Insert("Counterparty", Object.Supplier);
	FilterStructure.Insert("Contract", Object.SupplierContract);
	
	ParametersStructure.Insert("Filter", FilterStructure);
	
	OpenForm("Document.SupplierInvoice.ChoiceForm", ParametersStructure, ThisObject);
	
EndProcedure

&AtClient
Procedure Pick(Command)
	
	DocumentPresentaion	= NStr("en = 'customs declaration'");
	
	SelectionParameters	= DriveClient.GetSelectionParameters(ThisObject, "Inventory", DocumentPresentaion, True, False, False);
	
	SelectionParameters.Insert("Company", Company);
	
	NotificationDescriptionOnCloseSelection = New NotifyDescription("OnCloseSelection", ThisObject);
	OpenForm("DataProcessor.ProductsSelection.Form.MainForm",
			SelectionParameters,
			ThisObject,
			True,
			,
			,
			NotificationDescriptionOnCloseSelection,
			FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

#Region CounterpartyAndContract

&AtServer
Function GetDataCounterpartyOnChange()
	
	ContractByDefault = GetContractByDefault(Object.Ref, Object.Counterparty, Object.Company, Undefined);
	
	StructureData = New Structure;
	
	StructureData.Insert(
		"Contract",
		ContractByDefault);
		
	StructureData.Insert(
		"SettlementsCurrency",
		CommonUse.ObjectAttributeValue(ContractByDefault, "SettlementsCurrency"));
	
	StructureData.Insert(
		"SettlementsCurrencyRateRepetition",
		InformationRegisters.ExchangeRates.GetLast(Object.Date, New Structure("Currency", StructureData.SettlementsCurrency)));
	
	SetContractVisible();
	
	Return StructureData;
	
EndFunction

&AtServerNoContext
Function GetContractByDefault(Document, Counterparty, Company, OperationKind)
	
	ManagerOfCatalog = Catalogs.CounterpartyContracts;
	
	If Not ValueIsFilled(Counterparty) Then
		Return ManagerOfCatalog.EmptyRef();
	EndIf;
	
	CounterpartyData = CommonUse.ObjectAttributeValues(Counterparty, "DoOperationsByContracts, ContractByDefault");
	
	If Not CounterpartyData.DoOperationsByContracts Then
		Return CounterpartyData.ContractByDefault;
	EndIf;
	
	ContractTypesList = ManagerOfCatalog.GetContractKindsListForDocument(Document, OperationKind);
	ContractByDefault = ManagerOfCatalog.GetDefaultContractByCompanyContractKind(Counterparty, Company, ContractTypesList);
	
	Return ContractByDefault;
	
EndFunction

&AtServer
Procedure SetContractVisible()
	
	If ValueIsFilled(Object.Counterparty) Then
		
		Items.Contract.Visible = CommonUse.ObjectAttributeValue(Object.Counterparty, "DoOperationsByContracts");
		
	Else
		
		Items.Contract.Visible = False;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CounterpartyOnChangeFragment(ContractBeforeChange, StructureData)
	
	SettlementsCurrencyBeforeChange = SettlementsCurrency;
	SettlementsCurrency = StructureData.SettlementsCurrency;
	
	If ValueIsFilled(Object.Contract) Then 
		Object.ExchangeRate = ?(StructureData.SettlementsCurrencyRateRepetition.ExchangeRate = 0, 1, StructureData.SettlementsCurrencyRateRepetition.ExchangeRate);
		Object.Multiplicity = ?(StructureData.SettlementsCurrencyRateRepetition.Multiplicity = 0, 1, StructureData.SettlementsCurrencyRateRepetition.Multiplicity);
	EndIf;
	
	NewContractAndCalculationCurrency = ValueIsFilled(Object.Contract) AND ValueIsFilled(SettlementsCurrency) 
		AND Object.Contract <> ContractBeforeChange AND SettlementsCurrencyBeforeChange <> StructureData.SettlementsCurrency;
	OpenFormPricesAndCurrencies = NewContractAndCalculationCurrency AND Object.DocumentCurrency <> StructureData.SettlementsCurrency
		AND (Object.Inventory.Count() > 0 OR Object.CommodityGroups.Count() > 0);
	
	Object.DocumentCurrency = StructureData.SettlementsCurrency;
	
	If OpenFormPricesAndCurrencies Then
		
		WarningText = NStr("en = 'Settlement currency of the contract has changed.
							|It is necessary to check the document currency.'");
		
		ProcessChangesOnButtonPricesAndCurrencies(SettlementsCurrencyBeforeChange, True, False, WarningText);
		
	Else
		
		GenerateLabelPricesAndCurrency();
		
	EndIf;
	
	RefreshFormFooter();
	
EndProcedure

&AtClient
Procedure ProcessContractChange()
	
	ContractBeforeChange = Contract;
	Contract = Object.Contract;
	
	If ContractBeforeChange <> Object.Contract Then
		
		ProcessContractChangeFragment(ContractBeforeChange);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ProcessContractChangeFragment(ContractBeforeChange)
	
	StructureData = GetDataContractOnChange(Object.Date, Object.DocumentCurrency, Object.Contract);
	
	SettlementsCurrencyBeforeChange = SettlementsCurrency;
	SettlementsCurrency = StructureData.SettlementsCurrency;
	
	If ValueIsFilled(Object.Contract) Then 
		Object.ExchangeRate = ?(StructureData.SettlementsCurrencyRateRepetition.ExchangeRate = 0, 1, StructureData.SettlementsCurrencyRateRepetition.ExchangeRate);
		Object.Multiplicity = ?(StructureData.SettlementsCurrencyRateRepetition.Multiplicity = 0, 1, StructureData.SettlementsCurrencyRateRepetition.Multiplicity);
	EndIf;
	
	NewContractAndCalculationCurrency = ValueIsFilled(Object.Contract) AND ValueIsFilled(SettlementsCurrency) 
		AND Object.Contract <> ContractBeforeChange AND SettlementsCurrencyBeforeChange <> StructureData.SettlementsCurrency;
	OpenFormPricesAndCurrencies = NewContractAndCalculationCurrency AND Object.DocumentCurrency <> StructureData.SettlementsCurrency
		AND (Object.Inventory.Count() > 0 OR Object.CommodityGroups.Count() > 0);
		
	Object.DocumentCurrency = StructureData.SettlementsCurrency;
	
	If OpenFormPricesAndCurrencies Then
		
		WarningText = "";
		WarningText = WarningText + NStr("en = 'Settlement currency of the contract has changed.
										|It is necessary to check the document currency.'");
		
		ProcessChangesOnButtonPricesAndCurrencies(SettlementsCurrencyBeforeChange, True, False, WarningText);
		
	Else
		
		GenerateLabelPricesAndCurrency();
		
	EndIf;
	
	RefreshFormFooter();
	
EndProcedure

&AtServerNoContext
Function GetDataContractOnChange(Date, DocumentCurrency, Contract)
	
	StructureData = New Structure;
	
	StructureData.Insert(
		"SettlementsCurrency",
		CommonUse.ObjectAttributeValue(Contract, "SettlementsCurrency"));
	
	StructureData.Insert(
		"SettlementsCurrencyRateRepetition",
		InformationRegisters.ExchangeRates.GetLast(Date, New Structure("Currency", StructureData.SettlementsCurrency)));
	
	Return StructureData;
	
EndFunction

&AtServerNoContext
Function GetContractChoiceFormParameters(Document, Company, Counterparty, Contract, OperationKind)
	
	ContractTypesList = Catalogs.CounterpartyContracts.GetContractKindsListForDocument(Document, OperationKind);
	
	FormParameters = New Structure;
	If ValueIsFilled(Counterparty) Then
		FormParameters.Insert("ControlContractChoice", CommonUse.ObjectAttributeValue(Counterparty, "DoOperationsByContracts"));
	Else
		FormParameters.Insert("ControlContractChoice", False);
	EndIf;
	FormParameters.Insert("Counterparty", Counterparty);
	FormParameters.Insert("Company", Company);
	FormParameters.Insert("ContractType", ContractTypesList);
	FormParameters.Insert("CurrentRow", Contract);
	
	Return FormParameters;
	
EndFunction

#EndRegion

#Region SupplierAndSupplierContract

&AtClient
Function InventoryWillBeClearedMessageText()
	
	Return NStr("en = 'Inventory tab will be cleared. Do you want to continue?'");
	
EndFunction

&AtClient
Procedure SupplierChangeQueryBoxProcessing(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		
		Object.CommodityGroups.Clear();
		Object.Inventory.Clear();
		InitializeInventoryCommodityGroupChoiceList(Items.InventoryCommodityGroup, Object.CommodityGroups);
		RefreshFormFooter();
		
		SupplierChangeProcessing();
		
	Else
		
		Object.Supplier = Supplier;
		Object.SupplierContract = SupplierContract;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure SupplierChangeProcessing()
	
	Supplier = Object.Supplier;
	
	StructureData = GetDataSupplierOnChange(Object.Date, Object.DocumentCurrency, Object.Supplier, Object.Company);
	
	Object.SupplierContract = StructureData.SupplierContract;
	SupplierContract = Object.SupplierContract;
	
EndProcedure

&AtServer
Function GetDataSupplierOnChange(Date, DocumentCurrency, Supplier, Company)
	
	SupplierContractByDefault = GetSupplierContractByDefault(Documents.SupplierInvoice.EmptyRef(), Supplier, Company);
	
	StructureData = New Structure;
	
	StructureData.Insert(
		"SupplierContract",
		SupplierContractByDefault);
		
	StructureData.Insert(
		"SettlementsCurrency",
		CommonUse.ObjectAttributeValue(SupplierContractByDefault, "SettlementsCurrency"));
	
	SetSupplierContractVisible();
	
	Return StructureData;
	
EndFunction

&AtServerNoContext
Function GetSupplierContractByDefault(Document, Supplier, Company)
	
	ManagerOfCatalog = Catalogs.CounterpartyContracts;
	
	If Not ValueIsFilled(Supplier) Then
		Return ManagerOfCatalog.EmptyRef();
	EndIf;
	
	SupplierData = CommonUse.ObjectAttributeValues(Supplier, "DoOperationsByContracts, ContractByDefault");
	
	If Not SupplierData.DoOperationsByContracts Then
		Return SupplierData.ContractByDefault;
	EndIf;
	
	SupplierContractTypesList = ManagerOfCatalog.GetContractKindsListForDocument(Document);
	SupplierContractByDefault = ManagerOfCatalog.GetDefaultContractByCompanyContractKind(Supplier, Company, SupplierContractTypesList);
	
	Return SupplierContractByDefault;
	
EndFunction

&AtServer
Procedure SetSupplierContractVisible()
	
	If ValueIsFilled(Object.Supplier) Then
		
		Items.SupplierContract.Visible = CommonUse.ObjectAttributeValue(Object.Supplier, "DoOperationsByContracts");
		
	Else
		
		Items.SupplierContract.Visible = False;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure SupplierContractChangeQueryBoxProcessing(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		
		Object.CommodityGroups.Clear();
		Object.Inventory.Clear();
		InitializeInventoryCommodityGroupChoiceList(Items.InventoryCommodityGroup, Object.CommodityGroups);
		RefreshFormFooter();
		
		ProcessSupplierContractChange();
		
	Else
		
		Object.SupplierContract = SupplierContract;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ProcessSupplierContractChange()
	
	SupplierContract = Object.SupplierContract;
	
EndProcedure

&AtServerNoContext
Function GetSupplierContractChoiceFormParameters(Document, Company, Supplier, SupplierContract)
	
	SupplierContractTypesList = Catalogs.CounterpartyContracts.GetContractKindsListForDocument(Document);
	
	FormParameters = New Structure;
	If ValueIsFilled(Supplier) Then
		FormParameters.Insert("ControlContractChoice", CommonUse.ObjectAttributeValue(Supplier, "DoOperationsByContracts"));
	Else
		FormParameters.Insert("ControlContractChoice", False);
	EndIf;
	FormParameters.Insert("Counterparty", Supplier);
	FormParameters.Insert("Company", Company);
	FormParameters.Insert("ContractType", SupplierContractTypesList);
	FormParameters.Insert("CurrentRow", SupplierContract);
	
	Return FormParameters;
	
EndFunction

#EndRegion

#Region PricesAndCurrency

&AtServer
Procedure GenerateLabelPricesAndCurrency()
	
	LabelStructure = New Structure;
	LabelStructure.Insert("ForeignExchangeAccounting",	ForeignExchangeAccounting);
	LabelStructure.Insert("DocumentCurrency",			Object.DocumentCurrency);
	LabelStructure.Insert("ExchangeRate",				Object.ExchangeRate);
	LabelStructure.Insert("SettlementsCurrency",		SettlementsCurrency);
	LabelStructure.Insert("RateNationalCurrency",		RateNationalCurrency);
	
	PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
	
EndProcedure

&AtClient
Procedure ProcessChangesOnButtonPricesAndCurrencies(Val SettlementsCurrencyBeforeChange, RecalculatePrices = False, RefillPrices = False, WarningText = "")
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("DocumentCurrency",	Object.DocumentCurrency);
	ParametersStructure.Insert("ExchangeRate",		Object.ExchangeRate);
	ParametersStructure.Insert("Multiplicity",		Object.Multiplicity);
	ParametersStructure.Insert("Counterparty",		Object.Counterparty);
	ParametersStructure.Insert("Contract",			Object.Contract);
	ParametersStructure.Insert("Company",			Company);
	ParametersStructure.Insert("DocumentDate",		Object.Date);
	ParametersStructure.Insert("RefillPrices",		False);
	ParametersStructure.Insert("RecalculatePrices",	False);
	ParametersStructure.Insert("WereMadeChanges",	False);
	ParametersStructure.Insert("WarningText",		WarningText);
	
	NotifyDescription = New NotifyDescription("ProcessChangesOnButtonPricesAndCurrenciesEnd", ThisObject, New Structure("SettlementsCurrencyBeforeChange", SettlementsCurrencyBeforeChange));
	OpenForm("CommonForm.PricesAndCurrency", ParametersStructure, ThisObject, , , , NotifyDescription, FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtClient
Procedure ProcessChangesOnButtonPricesAndCurrenciesEnd(ClosingResult, AdditionalParameters) Export
	
	If TypeOf(ClosingResult) = Type("Structure")
		AND ClosingResult.WereMadeChanges Then
		
		Object.DocumentCurrency = ClosingResult.DocumentCurrency;
		Object.ExchangeRate = ClosingResult.PaymentsRate;
		Object.Multiplicity = ClosingResult.SettlementsMultiplicity;
		
		If ClosingResult.RecalculatePrices Then
			
			RatesStructure = DriveServer.GetExchangeRates(AdditionalParameters.SettlementsCurrencyBeforeChange, Object.DocumentCurrency, Object.Date);
			
			RecalculateAmountsOfATabularSection(Object.CommodityGroups, RatesStructure);
			RecalculateAmountsOfATabularSection(Object.Inventory, RatesStructure);
			
		EndIf;
		
	EndIf;
	
	GenerateLabelPricesAndCurrency();
	
	RefreshFormFooter();
	
EndProcedure

&AtClient
Procedure RecalculateAmountsOfATabularSection(TabularSection, RatesStructure)
	
	AmountFieldsToBeRecalculated = New Array;
	AmountFieldsToBeRecalculated.Add("CustomsValue");
	AmountFieldsToBeRecalculated.Add("DutyAmount");
	AmountFieldsToBeRecalculated.Add("OtherDutyAmount");
	AmountFieldsToBeRecalculated.Add("ExciseAmount");
	AmountFieldsToBeRecalculated.Add("VATAmount");
	
	For Each TabularSectionRow In TabularSection Do
		
		For Each AmountField In AmountFieldsToBeRecalculated Do
			
			TabularSectionRow[AmountField] = DriveClient.RecalculateFromCurrencyToCurrency(
				TabularSectionRow[AmountField], 
				RatesStructure.InitRate, 
				RatesStructure.ExchangeRate, 
				RatesStructure.RepetitionBeg, 
				RatesStructure.Multiplicity);
			
		EndDo;
		
	EndDo;
	
EndProcedure

#EndRegion

#Region Other

&AtServer
Procedure OnCreateOnReadCommonActions()
	
	FillFormAttributesValues();
	
	GenerateLabelPricesAndCurrency();

	InitializeInventoryCommodityGroupChoiceList(Items.InventoryCommodityGroup, Object.CommodityGroups);
	
	Items.Inventory.RowFilter = New FixedStructure("CommodityGroup", 0);
	
	SetContractVisible();
	SetSupplierContractVisible();
	SetOtherDutyGLAccountVisible();
	
EndProcedure

&AtServer
Procedure FillFormAttributesValues()
	
	Date						= Object.Date;
	Company						= Object.Company;
	Counterparty				= Object.Counterparty;
	Contract					= Object.Contract;
	Supplier					= Object.Supplier;
	SupplierContract			= Object.SupplierContract;
	SettlementsCurrency			= CommonUse.ObjectAttributeValue(Object.Contract, "SettlementsCurrency");
	FunctionalCurrency			= Constants.FunctionalCurrency.Get();
	StructureByCurrency			= InformationRegisters.ExchangeRates.GetLast(Object.Date, New Structure("Currency", FunctionalCurrency));
	RateNationalCurrency		= StructureByCurrency.ExchangeRate;
	RepetitionNationalCurrency	= StructureByCurrency.Multiplicity;
	ForeignExchangeAccounting	= Constants.ForeignExchangeAccounting.Get();
	
	AccountingPolicy = GetAccountingPolicyValues(Date, Company);
	RegisteredForVAT = AccountingPolicy.RegisteredForVAT;
	
	SetVATIsDueChoiceList(Items.VATIsDue, RegisteredForVAT);
	
EndProcedure

&AtServer
Procedure SetOtherDutyGLAccountVisible()
	
	Items.OtherDutyGLAccount.Visible = Object.OtherDutyToExpenses;
	
EndProcedure

&AtClient
Procedure CompanyChangeQueryBoxProcessing(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		
		Object.CommodityGroups.Clear();
		Object.Inventory.Clear();
		InitializeInventoryCommodityGroupChoiceList(Items.InventoryCommodityGroup, Object.CommodityGroups);
		RefreshFormFooter();
		
		CompanyChangeProcessing();
		
	Else
		
		Object.Company = Company;
		Object.Contract = Contract;
		Object.SupplierContract = SupplierContract;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CompanyChangeProcessing()
	
	Object.Number = "";
	Company = Object.Company;
	
	DataCompanyOnChange = GetDataCompanyOnChange(Object.Date, Object.Company, Object.Ref, Object.Counterparty, Object.Supplier);
	
	Object.SupplierContract = DataCompanyOnChange.SupplierContract;
	ProcessSupplierContractChange();
	
	Object.Contract = DataCompanyOnChange.Contract;
	ProcessContractChange();
	
	If RegisteredForVAT <> DataCompanyOnChange.RegisteredForVAT Then
		
		RegisteredForVAT = DataCompanyOnChange.RegisteredForVAT;
		
		SetVATIsDueChoiceList(Items.VATIsDue, RegisteredForVAT);
		
		ValidateVATIsDueValue();
		
	EndIf;
	
	GenerateLabelPricesAndCurrency();
	
EndProcedure

&AtServer
Function GetDataCompanyOnChange(Date, Company, Ref, Counterparty, Supplier)
	
	FillAddedColumns(True);
	DataCompanyOnChange = New Structure;
	
	SupplierContract = GetSupplierContractByDefault(
		PredefinedValue("Document.SupplierInvoice.EmptyRef"),
		Supplier,
		Company);
	DataCompanyOnChange.Insert("SupplierContract", SupplierContract);
			
	Contract = GetContractByDefault(
	 	Ref,
		Counterparty,
		Company,
		Undefined);
	DataCompanyOnChange.Insert("Contract", Contract);
	
	RegisteredForVAT = GetAccountingPolicyValues(Date, Company).RegisteredForVAT;
	DataCompanyOnChange.Insert("RegisteredForVAT", RegisteredForVAT);
	
	Return DataCompanyOnChange;
	
EndFunction

&AtClient
Procedure DateChangeProcessing()
	
	Date = Object.Date;
	
	DataDateOnChange = GetDataDateOnChange(Object.Date, Object.Company);
	
	If RegisteredForVAT <> DataDateOnChange.RegisteredForVAT Then
		
		RegisteredForVAT = DataDateOnChange.RegisteredForVAT;
		
		SetVATIsDueChoiceList(Items.VATIsDue, RegisteredForVAT);
		
		ValidateVATIsDueValue();
		
	EndIf;
	
	GenerateLabelPricesAndCurrency();
	
EndProcedure

&AtServerNoContext
Function GetDataDateOnChange(Date, Company)
	
	DataCompanyOnChange = New Structure;
	
	RegisteredForVAT = GetAccountingPolicyValues(Date, Company).RegisteredForVAT;
	DataCompanyOnChange.Insert("RegisteredForVAT", RegisteredForVAT);
	
	Return DataCompanyOnChange;
	
EndFunction

&AtServerNoContext
Function GetAccountingPolicyValues(Date, Company)

	Return InformationRegisters.AccountingPolicy.GetAccountingPolicy(Date, Company);
	
EndFunction

&AtClientAtServerNoContext
Procedure SetVATIsDueChoiceList(ItemVATIsDue, RegisteredForVAT)
	
	VATIsDueChoiceList = ItemVATIsDue.ChoiceList;
	VATIsDueChoiceList.Clear();
	
	VATIsDueChoiceList.Add(PredefinedValue("Enum.VATDueOnCustomsClearance.OnTheSupply"));
	
	If RegisteredForVAT Then
		
		VATIsDueChoiceList.Add(PredefinedValue("Enum.VATDueOnCustomsClearance.InTheVATReturn"));
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ValidateVATIsDueValue()
	
	If Not RegisteredForVAT Then
		
		VATDueOnTheSupply = PredefinedValue("Enum.VATDueOnCustomsClearance.OnTheSupply");
		
		If Object.VATIsDue <> VATDueOnTheSupply Then
			
			Object.VATIsDue = VATDueOnTheSupply;
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure RefreshFormFooter()
	
	Object.CustomsValue		= Object.Inventory.Total("CustomsValue");
	Object.DutyAmount		= Object.Inventory.Total("DutyAmount");
	Object.OtherDutyAmount	= Object.Inventory.Total("OtherDutyAmount");
	Object.ExciseAmount		= Object.Inventory.Total("ExciseAmount");
	Object.VATAmount		= Object.Inventory.Total("VATAmount");
	Object.DocumentAmount	= Object.DutyAmount + Object.OtherDutyAmount + Object.ExciseAmount + Object.VATAmount;
	
EndProcedure

&AtClient
Procedure FillInvoiceDependentChoiceLists()
	
	StructuralUnitChoiceList = Items.InventoryStructuralUnit.ChoiceList;
	StructuralUnitChoiceList.Clear();
	
	If ValueIsFilled(CurrentInvoice) Then
		
		InvoiceData = GetInvoiceData(CurrentInvoice);
		
		If ValueIsFilled(InvoiceData.StructuralUnit) Then
			
			StructuralUnitChoiceList.Add(InvoiceData.StructuralUnit);
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Function GetInvoiceData(Invoice)
	
	Return CommonUse.ObjectAttributesValues(Invoice, "StructuralUnit");
	
EndFunction

&AtClient
Procedure FillProductDependentChoiceLists()
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	OriginChoiceList = Items.InventoryOrigin.ChoiceList;
	OriginChoiceList.Clear();
	
	HSCodeChoiceList = Items.InventoryHSCode.ChoiceList;
	HSCodeChoiceList.Clear();
	
	If ValueIsFilled(CurrentProduct) Then
		
		StructureData = New Structure;
		StructureData.Insert("Products", CurrentProduct);
		
		AddGLAccountsToStructure(StructureData, TabularSectionRow);	
		StructureData.Insert("ObjectParameters", GLAccountsInDocumentsClientServer.GetObjectParameters(Object));
		StructureData = GetProductData(StructureData);
		ProductData = StructureData.ProductData;
		
		FillPropertyValues(TabularSectionRow, StructureData); 
		
		If ValueIsFilled(ProductData.CountryOfOrigin) Then
			
			OriginChoiceList.Add(ProductData.CountryOfOrigin);
			
		EndIf;
		
		If ValueIsFilled(ProductData.HSCode) Then
			
			HSCodeChoiceList.Add(ProductData.HSCode);
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Function GetProductData(StructureData)
	
	GLAccountsInDocuments.FillProductGLAccountsInStructure(StructureData);
	StructureData.Insert("ProductData", CommonUse.ObjectAttributesValues(StructureData.Products, "CountryOfOrigin, HSCode"));	
	
	Return StructureData;
	
EndFunction

&AtServer
Procedure AllocateCostsToInventoryAtServer()
	
	FilterStructure = New Structure("CommodityGroup");
	CGSelectedRows = Items.CommodityGroups.SelectedRows;
	
	For Each CommodityGroupsRowID In CGSelectedRows Do
		
		CommodityGroupsRow = Object.CommodityGroups.FindByID(CommodityGroupsRowID);
		
		FilterStructure.CommodityGroup = CommodityGroupsRow.CommodityGroup;
		
		InventoryRows = Object.Inventory.Unload(FilterStructure);
		
		If InventoryRows.Count() > 0 Then
			
			Coefficients = InventoryRows.UnloadColumn("CustomsValue");
			
			AmountNames = StringFunctionsClientServer.SplitStringIntoWordArray("CustomsValue, DutyAmount, OtherDutyAmount, ExciseAmount, VATAmount");
			
			For Each AmountName In AmountNames Do
			
				NewAmounts = CommonUseClientServer.DistributeAmountProportionallyToFactors(CommodityGroupsRow[AmountName], Coefficients);
				If NewAmounts = Undefined Then
					
					InventoryRows.FillValues(0, AmountName);
					
				Else
					
					InventoryRows.LoadColumn(NewAmounts, AmountName);
				EndIf;
				
			EndDo;
			
			For Each InventoryRow In InventoryRows Do
				FillPropertyValues(Object.Inventory[InventoryRow.LineNumber - 1], InventoryRow);
			EndDo;
			
		EndIf;
		
	EndDo;
	
EndProcedure

&AtClient
Procedure OnCloseSelection(ClosingResult, AdditionalParameters) Export
	
	If TypeOf(ClosingResult) = Type("Structure") Then
		
		If Not IsBlankString(ClosingResult.CartAddressInStorage) Then
			
			InventoryAddressInStorage = ClosingResult.CartAddressInStorage;
			
			GetInventoryFromStorage(InventoryAddressInStorage, CurrentCommodityGroup);
			
			RefreshFormFooter();
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure GetInventoryFromStorage(InventoryAddressInStorage, CommodityGroup)
	
	TableForImport = GetFromTempStorage(InventoryAddressInStorage);
	
	ObjectParameters = GLAccountsInDocumentsClientServer.GetObjectParameters(Object);
	StructureData = GetStructureData(ObjectParameters);
	StructureData.Insert("Products", TableForImport.UnloadColumn("Products"));
	GLAccounts = GLAccountsInDocuments.GetProductListGLAccounts(StructureData);
	
	For Each ImportRow In TableForImport Do
		
		NewRow = Object.Inventory.Add();
		FillPropertyValues(NewRow, ImportRow);
		NewRow.CommodityGroup = CommodityGroup;
		
		FillPropertyValues(StructureData, NewRow);
		GLAccountsInDocumentsServerCall.FillProductGLAccounts(StructureData, GLAccounts);
		FillPropertyValues(NewRow, StructureData);
		
	EndDo;
	
EndProcedure

&AtServer
Procedure ProcessInvoicesSelection(SelectedInvoices)
	
	DocObject = FormAttributeToValue("Object");
	
	DocObject.FillBySupplierInvoice(New Structure("ArrayOfSupplierInvoices", SelectedInvoices));
	
	ValueToFormAttribute(DocObject, "Object");
	FillAddedColumns();
	
EndProcedure

&AtServer
Procedure VATIsDueOnChangeAtServer()
	FillAddedColumns(True);
EndProcedure


#EndRegion

#Region CommodityGroups

&AtClient
Function NewCommodityGroup()
	
	MaxCommodityGroup = 0;
	
	For Each CommodityGroupRow In Object.CommodityGroups Do
		
		If CommodityGroupRow.CommodityGroup > MaxCommodityGroup Then
			
			MaxCommodityGroup = CommodityGroupRow.CommodityGroup;
			
		EndIf;
		
	EndDo;
	
	Return MaxCommodityGroup + 1;
	
EndFunction

&AtClient
Procedure ActivateCommodityGroup()
	
	ShowAll = Items.ShowAll.Check;
	InventoryItem = Items.Inventory;
	
	If Not ShowAll And (InventoryItem.RowFilter = Undefined Or InventoryItem.RowFilter.CommodityGroup <> CurrentCommodityGroup) Then
		
		InventoryItem.RowFilter = New FixedStructure("CommodityGroup", CurrentCommodityGroup);
		
	ElsIf ShowAll And InventoryItem.RowFilter <> Undefined Then
		
		InventoryItem.RowFilter = Undefined;
		
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Procedure InitializeInventoryCommodityGroupChoiceList(ItemInventoryCommodityGroup, ObjectCommodityGroups)
	
	ICGChoiceList = ItemInventoryCommodityGroup.ChoiceList;
	
	ICGChoiceList.Clear();
	
	For Each CGRow In ObjectCommodityGroups Do
		
		ICGChoiceList.Add(CGRow.CommodityGroup);
		
	EndDo;
	
	ICGChoiceList.Add(0, "-");
	
	ICGChoiceList.SortByValue();
	
EndProcedure

&AtClient
Procedure ModifyInventoryCommodityGroupChoiceList(ValueToBeRemoved, ValueToBeAdded)
	
	ICGChoiceList = Items.InventoryCommodityGroup.ChoiceList;
	
	If Not ValueToBeRemoved = Undefined Then
		
		ICGChoiceListItem = ICGChoiceList.FindByValue(ValueToBeRemoved);
		
		If Not ICGChoiceListItem = Undefined Then
			
			ICGChoiceList.Delete(ICGChoiceListItem);
			
		EndIf;
		
	EndIf;
	
	If Not ValueToBeAdded = Undefined Then
		
		ICGChoiceList.Add(ValueToBeAdded);
		
	EndIf;
	
	ICGChoiceList.SortByValue();
	
EndProcedure

#EndRegion

#Region AmountsAndRatesCalculation

&AtClient
Procedure CalculateDutyAmount(TableRow, DutyRate)
	
	TableRow.DutyAmount = TableRow.CustomsValue * DutyRate / 100;
	
EndProcedure

&AtClient
Procedure CalculateDutyRate(TableRow)
	
	If Not TableRow.CustomsValue = 0 Then
		
		TableRow.DutyRate = 100 * TableRow.DutyAmount / TableRow.CustomsValue;
		
	Else
		
		TableRow.DutyRate = 0;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CalculateOtherDutyAmount(TableRow, OtherDutyRate)
	
	TableRow.OtherDutyAmount = TableRow.CustomsValue * OtherDutyRate / 100;
	
EndProcedure

&AtClient
Procedure CalculateOtherDutyRate(TableRow)
	
	If Not TableRow.CustomsValue = 0 Then
		
		TableRow.OtherDutyRate = 100 * TableRow.OtherDutyAmount / TableRow.CustomsValue;
		
	Else
		
		TableRow.OtherDutyRate = 0;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CalculateExciseAmount(TableRow, CustomsValue, ExciseAmount)
	
	If CustomsValue = 0 Or ExciseAmount = 0 Then
		
		TableRow.ExciseAmount = 0;
		
	Else
		
		TableRow.ExciseAmount = TableRow.CustomsValue * ExciseAmount / CustomsValue;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CalculateVATAmount(TableRow, VATRate)
	
	If TypeOf(VATRate) = Type("CatalogRef.VATRates") Then
		
		VATRateValue = DriveReUse.GetVATRateValue(VATRate);
		
	Else
		
		VATRateValue = VATRate;
		
	EndIf;
	
	TableRow.VATAmount = (TableRow.CustomsValue + TableRow.DutyAmount + TableRow.OtherDutyAmount + TableRow.ExciseAmount) * VATRateValue / 100;
	
EndProcedure

&AtClient
Procedure InventoryAmountsCalculations(CalculationSettings)
	
	CommodityGroupsRow = Items.CommodityGroups.CurrentData;
	
	If Not CommodityGroupsRow = Undefined Then
		
		InventoryRow = Items.Inventory.CurrentData;
		
		If CalculationSettings.Property("CalculateDutyAmount") Then
			
			CalculateDutyAmount(InventoryRow, CommodityGroupsRow.DutyRate);
			
		EndIf;
		
		If CalculationSettings.Property("CalculateOtherDutyAmount") Then
			
			CalculateOtherDutyAmount(InventoryRow, CommodityGroupsRow.OtherDutyRate);
			
		EndIf;
		
		If CalculationSettings.Property("CalculateVATAmount") Then
			
			CalculateVATAmount(InventoryRow, CommodityGroupsRow.VATRate);
			
		EndIf;
		
		RefreshFormFooter();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CommodityGroupsAmountsCalculations(CG_CalculationSettings, Inv_CalculationSettings)
	
	CommodityGroupsRow = Items.CommodityGroups.CurrentData;
	
	VATRateValue = DriveReUse.GetVATRateValue(CommodityGroupsRow.VATRate);
	
	If CG_CalculationSettings.Property("CalculateDutyRate") Then
		CalculateDutyRate(CommodityGroupsRow);
	EndIf;
	
	If CG_CalculationSettings.Property("CalculateDutyAmount") Then
		CalculateDutyAmount(CommodityGroupsRow, CommodityGroupsRow.DutyRate);
	EndIf;
	
	If CG_CalculationSettings.Property("CalculateOtherDutyRate") Then
		CalculateOtherDutyRate(CommodityGroupsRow);
	EndIf;
	
	If CG_CalculationSettings.Property("CalculateOtherDutyAmount") Then
		CalculateOtherDutyAmount(CommodityGroupsRow, CommodityGroupsRow.OtherDutyRate);
	EndIf;
	
	If CG_CalculationSettings.Property("CalculateVATAmount") Then
		CalculateVATAmount(CommodityGroupsRow, VATRateValue);
	EndIf;
	
	InventoryRows = Object.Inventory.FindRows(New Structure("CommodityGroup", CurrentCommodityGroup));
	
	For Each InventoryRow In InventoryRows Do
		
		If Inv_CalculationSettings.Property("CalculateDutyAmount") Then
			CalculateDutyAmount(InventoryRow, CommodityGroupsRow.DutyRate);
		EndIf;
		
		If Inv_CalculationSettings.Property("CalculateOtherDutyAmount") Then
			CalculateOtherDutyAmount(InventoryRow, CommodityGroupsRow.OtherDutyRate);
		EndIf;
		
		If Inv_CalculationSettings.Property("CalculateExciseAmount") Then
			CalculateExciseAmount(InventoryRow, CommodityGroupsRow.CustomsValue, CommodityGroupsRow.ExciseAmount);
		EndIf;
		
		If Inv_CalculationSettings.Property("CalculateVATAmount") Then
			CalculateVATAmount(InventoryRow, VATRateValue);
		EndIf;
		
	EndDo;
	
	RefreshFormFooter();
	
	
EndProcedure

#EndRegion

#Region ProductsGLAccounts
&AtClient
Procedure OpenProductGLAccountsForm(CurrentData)

	If CurrentData = Undefined Then
		Return;
	EndIf;

	If Not ReadOnly Then
		LockFormDataForEdit();
	EndIf;

	FilterStructure = New Structure("LineNumber", CurrentData.LineNumber);
	RowArray = Object.Inventory.FindRows(FilterStructure);
	
	If RowArray.Count() > 0 Then
		RowData = RowArray[0];	
	EndIf;
	
	ObjectParameters = GLAccountsInDocumentsClientServer.GetObjectParameters(Object);
	StructureData = GetStructureData(ObjectParameters);
	
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
	StructureData.Insert("VATInputGLAccount",	TabRow.VATInputGLAccount);
	If Object.VATIsDue = PredefinedValue("Enum.VATDueOnCustomsClearance.InTheVATReturn") Then 
		StructureData.Insert("VATOutputGLAccount",	TabRow.VATOutputGLAccount);
	EndIf;
	
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
		StructureData = GetStructureData(ObjectParameters, GLAccounts.TableName);
		
		GLAccountsInDocumentsClientServer.FillProductGLAccountsDescription(StructureData);
		FillPropertyValues(TabRow, StructureData);
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Function GetStructureData(ObjectParameters, RowData = Undefined, ProductName = "Products") Export
	
	StructureData = New Structure("Products, InventoryGLAccount, VATInputGLAccount, GLAccounts, GLAccountsFilled");
	
	If ObjectParameters.VATIsDue = PredefinedValue("Enum.VATDueOnCustomsClearance.InTheVATReturn") Then 
		StructureData.Insert("VATOutputGLAccount",	PredefinedValue("ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef"));
	EndIf;
	
	StructureData.Insert("ObjectParameters", ObjectParameters);
	StructureData.Insert("TabName", "Inventory");
	StructureData.Insert("ProductName", ProductName);
	
	If RowData <> Undefined Then 
		FillPropertyValues(StructureData, RowData);
	EndIf;
	
	Return StructureData;
	
EndFunction

#EndRegion

#Region LibrariesHandlers

#Region AdditionalReportsAndDataProcessors

&AtClient
Procedure Attachable_ExecuteAssignedCommand(Command)
	
	If Not AdditionalReportsAndDataProcessorsClient.ExecuteAllocatedCommandAtClient(ThisObject, Command.Name) Then
		ExecutionResult = Undefined;
		AdditionalReportsAndProcessingsExecuteAllocatedCommandAtServer(Command.Name, ExecutionResult);
		AdditionalReportsAndDataProcessorsClient.ShowCommandExecutionResult(ThisObject, ExecutionResult);
	EndIf;
	
EndProcedure

&AtServer
Procedure AdditionalReportsAndProcessingsExecuteAllocatedCommandAtServer(ItemName, ExecutionResult)
	
	AdditionalReportsAndDataProcessors.ExecuteAllocatedCommandAtServer(ThisObject, ItemName, ExecutionResult);
	
EndProcedure

#EndRegion

#Region DataImportFromExternalSources

&AtClient
Procedure DataImportFromExternalSources(Command)
	
	NotifyDescription = New NotifyDescription("ImportDataFromExternalSourceResultDataProcessor", ThisObject, DataLoadSettings);
	
	DataLoadSettings.Insert("TabularSectionFullName",	"CustomsDeclaration.Inventory");
	DataLoadSettings.Insert("Title",					NStr("en = 'Import products from file'"));
	
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
	
	DataImportFromExternalSourcesOverridable.ImportDataFromExternalSourceResultDataProcessor(ImportResult, Object);
		
EndProcedure

#EndRegion

#Region Printing

&AtClient
Procedure Attachable_ExecutePrintCommand(Command)
	PrintManagementClient.ExecuteConnectedPrintCommand(Command, ThisObject, Object);
EndProcedure

#EndRegion

#Region Properties

&AtClient
Procedure Attachable_EditContentOfProperties(Command)
	
	PropertiesManagementClient.EditContentOfProperties(ThisObject, Object.Ref);
	
EndProcedure

&AtServer
Procedure UpdateAdditionalAttributesItems()
	
	PropertiesManagement.UpdateAdditionalAttributesItems(ThisObject, FormAttributeToValue("Object"));
	
EndProcedure

#EndRegion

#EndRegion

#EndRegion

#Region Initialize

ThisIsNewRow = False;

#EndRegion