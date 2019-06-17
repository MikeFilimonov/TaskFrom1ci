////////////////////////////////////////////////////////////////////////////////
// MODAL VARIABLES MASTERS (Client)

#Region Variables

&AtClient
Var mCurrentPageNumber;

&AtClient
Var mFirstPage;

&AtClient
Var mLastPage;

&AtClient
Var mFormRecordCompleted;

#EndRegion

#Region GeneralPurposeProceduresAndFunctions

// Procedure sets the explanation text.
//
&AtClient
Procedure SetExplanationText()
	
	If mCurrentPageNumber = 0 Then
		Items.DecorationNextActionExplanation.Title = NStr("en = 'Click Next to fill cash funds balance'");
	ElsIf mCurrentPageNumber = 1 Then
		Items.DecorationNextActionExplanation.Title = NStr("en = 'Click Next to fill in goods balance'");
	ElsIf mCurrentPageNumber = 2 Then
		Items.DecorationNextActionExplanation.Title = NStr("en = 'Click Next to fill balance by acounts payable'");
	ElsIf mCurrentPageNumber = 3 Then
		Items.DecorationNextActionExplanation.Title = NStr("en = 'Click Next to fill balance by acounts receivable'");
	ElsIf mCurrentPageNumber = 4 Then
		Items.DecorationNextActionExplanation.Title = NStr("en = 'Press ""Next"" to proceed to the final step'");
	ElsIf mCurrentPageNumber = 5 Then
		Items.DecorationNextActionExplanation.Title = NStr("en = 'To complete, it is required to click Finish'");
	EndIf;
	
EndProcedure

// Procedure sets the active page.
//
&AtClient
Procedure SetActivePage()
	
	SearchString = "Step" + String(mCurrentPageNumber);
	Items.Pages.CurrentPage = Items.Find(SearchString);
	
	Title = StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en = 'Opening balance filling wizard (Step %1/%2)'"),
		mCurrentPageNumber, mLastPage);
	SetExplanationText();
	
EndProcedure

// Procedure sets the buttons accessibility.
//
&AtClient
Procedure SetButtonsEnabled()
	
	Items.Back.Enabled = mCurrentPageNumber <> mFirstPage;
	
	If mCurrentPageNumber = mLastPage Then
		Items.GoToNext.Title = NStr("en = 'Finish'");
		Items.GoToNext.Representation = ButtonRepresentation.Text;
		Items.GoToNext.Font = New Font(Items.GoToNext.Font,,,True);
	Else
		Items.GoToNext.Title = NStr("en = 'Next'");
		Items.GoToNext.Representation = ButtonRepresentation.PictureAndText;
		Items.GoToNext.Font = New Font(Items.GoToNext.Font,,,False);
	EndIf;
	
EndProcedure

// Function adds products.
//
&AtServerNoContext
Function AddProductsAtServer(Products, UseBatches, UseCharacteristics)
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	Products.Ref
	|FROM
	|	Catalog.Products AS Products
	|WHERE
	|	Products.Description = &Description";
	Query.SetParameter("Description", Products);
	
	SelectionOfQueryResult = Query.Execute().Select();
	
	If SelectionOfQueryResult.Next() Then
		ProductsToReturn = SelectionOfQueryResult.Ref;
	Else
		NewProducts = Catalogs.Products.CreateItem();
		NewProducts.Description					= Products;
		NewProducts.DescriptionFull				= Products;
		NewProducts.UseBatches					= UseBatches = Enums.YesNo.Yes;
		NewProducts.UseCharacteristics			= UseCharacteristics = Enums.YesNo.Yes;
		NewProducts.MeasurementUnit				= Catalogs.UOMClassifier.pcs;
		NewProducts.ProductsCategory	= Catalogs.ProductsCategories.MainGroup;
		NewProducts.ReplenishmentMethod			= Enums.InventoryReplenishmentMethods.Purchase;
		NewProducts.BusinessLine				= Catalogs.LinesOfBusiness.MainLine;
		NewProducts.VATRate						= InformationRegisters.AccountingPolicy.GetDefaultVATRate(
			CurrentDate(), Catalogs.Companies.MainCompany);
		NewProducts.ProductsType		= Enums.ProductsTypes.InventoryItem;
		NewProducts.OrderCompletionDeadline		= 1;
		NewProducts.ReplenishmentDeadline		= 1;
		NewProducts.Warehouse					= Catalogs.BusinessUnits.MainWarehouse;
		NewProducts.Write();
		
		ProductsToReturn = NewProducts.Ref;
	EndIf;
	
	StructuralUnitUser = DriveReUse.GetValueByDefaultUser(Users.CurrentUser(), "MainWarehouse");
	
	ReturnStructure = New Structure("Products, StructuralUnit", ProductsToReturn, ?(ValueIsFilled(ProductsToReturn.Warehouse), ProductsToReturn.Warehouse, StructuralUnitUser));
	
	Return ReturnStructure;
	
EndFunction

// Procedure writes the form changes.
//
&AtServer
Procedure WriteFormChanges(FinishEntering = False)
	
	If OpeningBalanceEntryBankAndPettyCash.CashAssets.Count() > 0 Then
		EnteringInitialBalancesBankAndCashObject = FormAttributeToValue("OpeningBalanceEntryBankAndPettyCash");
		EnteringInitialBalancesBankAndCashObject.Date = BalanceDate;
		EnteringInitialBalancesBankAndCashObject.Company = Company;
		EnteringInitialBalancesBankAndCashObject.Comment = "# Document is entered by the balances input assistant.";
		EnteringInitialBalancesBankAndCashObject.AccountingSection = "Cash assets";
		EnteringInitialBalancesBankAndCashObject.Write(DocumentWriteMode.Posting);
		ValueToFormAttribute(EnteringInitialBalancesBankAndCashObject, "OpeningBalanceEntryBankAndPettyCash");
	EndIf;
	
	If OpeningBalanceEntryProducts.Inventory.Count() > 0 Then
		OpeningBalanceEntryProductsObject = FormAttributeToValue("OpeningBalanceEntryProducts");
		OpeningBalanceEntryProductsObject.Date = BalanceDate;
		OpeningBalanceEntryProductsObject.Company = Company;
		OpeningBalanceEntryProductsObject.Comment = "# Document is entered by the balances input assistant.";
		OpeningBalanceEntryProductsObject.AccountingSection = "Inventory";
		OpeningBalanceEntryProductsObject.Write(DocumentWriteMode.Posting);
		ValueToFormAttribute(OpeningBalanceEntryProductsObject, "OpeningBalanceEntryProducts");
	EndIf;
	
	If OpeningBalanceEntryCounterpartiesSettlements.AccountsPayable.Count() > 0
	 OR OpeningBalanceEntryCounterpartiesSettlements.AccountsReceivable.Count() > 0 Then
		OpeningBalanceEntryCounterpartiesSettlementsObject = FormAttributeToValue("OpeningBalanceEntryCounterpartiesSettlements");
		OpeningBalanceEntryCounterpartiesSettlementsObject.Date = BalanceDate;
		OpeningBalanceEntryCounterpartiesSettlementsObject.Company = Company;
		OpeningBalanceEntryCounterpartiesSettlementsObject.Autogeneration = True;
		OpeningBalanceEntryCounterpartiesSettlementsObject.Comment = "# Document is entered by the balances input assistant.";
		OpeningBalanceEntryCounterpartiesSettlementsObject.AccountingSection = "Accounts payable and customers";
		OpeningBalanceEntryCounterpartiesSettlementsObject.Write(DocumentWriteMode.Posting);
		ValueToFormAttribute(OpeningBalanceEntryCounterpartiesSettlementsObject, "OpeningBalanceEntryCounterpartiesSettlements");
	EndIf;
	
	Constants.UseSeveralWarehouses.Set(
		?(UseSeveralWarehouses = Enums.YesNo.Yes,
			True,
			False
		)
	);
	
	Constants.UseSeveralUnitsForProduct.Set(
		?(UseSeveralUnitsForProduct = Enums.YesNo.Yes,
			True,
			False
		)
	);
	
	Constants.UseCharacteristics.Set(
		?(UseCharacteristics = Enums.YesNo.Yes,
			True,
			False
		)
	);
	
	Constants.UseBatches.Set(
		?(UseBatches = Enums.YesNo.Yes,
			True,
			False
		)
	);
	
	Constants.ForeignExchangeAccounting.Set(
		?(ForeignExchangeAccounting = Enums.YesNo.Yes,
			True,
			False
		)
	);
	
	Constants.PresentationCurrency.Set(PresentationCurrency);
	Constants.FunctionalCurrency.Set(FunctionalCurrency);
	
	If FinishEntering Then
		Constants.OpeningBalanceIsFilled.Set(True);
	EndIf;
	
	SetAccountsAttributesVisible(, , , "AccountsPayable");
	SetAccountsAttributesVisible(, , , "AccountsReceivable");
	
EndProcedure

// Procedure calculates the amount in tabular section row.
//
&AtClient
Procedure CalculateAmountInTabularSectionLine()
	
	TabularSectionRow = Items.OpeningBalanceEntryProductsInventory.CurrentData;
	TabularSectionRow.Amount = TabularSectionRow.Quantity * TabularSectionRow.Price;
	
EndProcedure

// Procedure writes changes of accounting in various units.
//
&AtServerNoContext
Procedure WriteChangesAccountingInVariousUOM(UseSeveralUnitsForProduct)
	
	Constants.UseSeveralUnitsForProduct.Set(
		?(UseSeveralUnitsForProduct = Enums.YesNo.Yes,
			True,
			False
		)
	);
	
EndProcedure

// Procedure writes changes of accounting by multiple warehouses.
//
&AtServerNoContext
Procedure WriteChangesAccountingBySeveralWarehouses(UseSeveralWarehouses)
	
	Constants.UseSeveralWarehouses.Set(
		?(UseSeveralWarehouses = Enums.YesNo.Yes,
			True,
			False
		)
	);
	
EndProcedure

// Procedure writes changes in characteristics application.
//
&AtServerNoContext
Procedure WriteChangesUseCharacteristics(UseCharacteristics)
	
	Constants.UseCharacteristics.Set(
		?(UseCharacteristics = Enums.YesNo.Yes,
			True,
			False
		)
	);
	
EndProcedure

&AtServerNoContext
// Gets the data set from the server for procedure MeasurementUnitOnChange.
//
Function GetDataMeasurementUnitOnChange(CurrentMeasurementUnit = Undefined, MeasurementUnit = Undefined)
	
	StructureData = New Structure();
	
	If CurrentMeasurementUnit = Undefined Then
		StructureData.Insert("CurrentFactor", 1);
	Else
		StructureData.Insert("CurrentFactor", CurrentMeasurementUnit.Factor);
	EndIf;
	
	If MeasurementUnit = Undefined Then
		StructureData.Insert("Factor", 1);
	Else
		StructureData.Insert("Factor", MeasurementUnit.Factor);
	EndIf;
	
	Return StructureData;
	
EndFunction

// Procedure writes the changes in batches usage.
//
&AtServerNoContext
Procedure WriteChangesUseBatches(UseBatches)
	
	Constants.UseBatches.Set(
		?(UseBatches = Enums.YesNo.Yes,
			True,
			False
		)
	);
	
EndProcedure

// Function puts the Inventory tabular section in
// temporary storage and returns the address.
//
&AtServer
Function PlaceInventoryToStorage()
	
	Return PutToTempStorage(
		OpeningBalanceEntryProducts.Inventory.Unload(,
			"Products,
			|Characteristic,
			|Batch,
			|MeasurementUnit,
			|Price"
		),
		UUID
	);
	
EndFunction

// Procedure writes changes of currency operations accounting.
//
&AtServer
Procedure WriteChangesCurrencyTransactionsAccounting(ForeignExchangeAccounting)
	
	Constants.ForeignExchangeAccounting.Set(
		?(ForeignExchangeAccounting = Enums.YesNo.Yes,
			True,
			False
		)
	);
	
	If ForeignExchangeAccounting = PredefinedValue("Enum.YesNo.Yes") Then
		Items.PresentationCurrency.ReadOnly = False;
		Items.PresentationCurrency.AutoChoiceIncomplete = True;
		Items.PresentationCurrency.AutoMarkIncomplete = True;
		Items.FunctionalCurrency.ReadOnly = False;
		Items.FunctionalCurrency.AutoChoiceIncomplete = True;
		Items.FunctionalCurrency.AutoMarkIncomplete = True;
	Else
		Items.PresentationCurrency.ReadOnly = True;
		Items.PresentationCurrency.AutoChoiceIncomplete = False;
		Items.PresentationCurrency.AutoMarkIncomplete = False;
		Items.FunctionalCurrency.ReadOnly = True;
		Items.FunctionalCurrency.AutoChoiceIncomplete = False;
		Items.FunctionalCurrency.AutoMarkIncomplete = False;
		PresentationCurrency = FunctionalCurrency;
	EndIf;
	
EndProcedure

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

// Receives the set of data from the server for the ProductsOnChange procedure.
//
&AtServerNoContext
Function GetDataProductsOnChange(StructureData)
	
	GLAccounts = GLAccountsInDocuments.GetProductListGLAccounts(StructureData);
	GLAccountsInDocumentsServerCall.FillProductGLAccounts(StructureData, GLAccounts);
	
	StructureData.Insert("MeasurementUnit", StructureData.Products.MeasurementUnit);
	Return StructureData;
	
EndFunction

// Procedure checks filling of the mandatory attributes when you go to the next page.
//
&AtClient
Procedure ExecuteActionsOnTransitionToNextPage(Cancel)
	
	ClearMessages();
	
	If mCurrentPageNumber = 1 Then
		
		If Not ValueIsFilled(PresentationCurrency) Then
			MessageText = NStr("en = 'Specify presentation currency.'");
			CommonUseClientServer.MessageToUser(
				MessageText,
				,
				"PresentationCurrency",
				,
				Cancel
			);
		EndIf;
		
		If ForeignExchangeAccounting = PredefinedValue("Enum.YesNo.Yes") AND Not ValueIsFilled(FunctionalCurrency) Then
			MessageText = NStr("en = 'Specify functional currency.'");
			CommonUseClientServer.MessageToUser(
				MessageText,
				,
				"FunctionalCurrency",
				,
				Cancel
			);
		EndIf;
		
		For Each CurRow In OpeningBalanceEntryBankAndPettyCash.CashAssets Do
			If Not ValueIsFilled(CurRow.BankAccountPettyCash) Then
				MessageText = StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = 'Specify banking account or petty cash in line %1.'"),
					CurRow.LineNumber);
				CommonUseClientServer.MessageToUser(
					MessageText,
					,
					"OpeningBalanceEntryBankAndPettyCash",
					,
					Cancel
				);
			EndIf;
			If Not ValueIsFilled(CurRow.CashCurrency) Then
				MessageText = StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = 'Specify currency in line %1.'"),
					CurRow.LineNumber);
				CommonUseClientServer.MessageToUser(
					MessageText,
					,
					"OpeningBalanceEntryBankAndPettyCash",
					,
					Cancel
				);
			EndIf;
			If Not ValueIsFilled(CurRow.AmountCur) Then
				MessageText = StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = 'Specify amount in line %1.'"),
					CurRow.LineNumber);
				CommonUseClientServer.MessageToUser(
					MessageText,
					,
					"OpeningBalanceEntryBankAndPettyCash",
					,
					Cancel
				);
			EndIf;
			If ForeignExchangeAccounting = PredefinedValue("Enum.YesNo.Yes")
			AND Not ValueIsFilled(CurRow.Amount) Then
			
				CommonUseClientServer.MessageToUser(
					StringFunctionsClientServer.SubstituteParametersInString(
						NStr("en = 'Specify presentation currency amount in line %1.'"),
						CurRow.LineNumber),,
					"OpeningBalanceEntryBankAndPettyCash",,
					Cancel);
			EndIf;
		EndDo;
		
	ElsIf mCurrentPageNumber = 2 Then
		
		For Each CurRow In OpeningBalanceEntryProducts.Inventory Do
			If Not ValueIsFilled(CurRow.StructuralUnit) Then
				MessageText = StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = 'Specify business unit in line %1.'"),
					CurRow.LineNumber);
				CommonUseClientServer.MessageToUser(
					MessageText,
					,
					"OpeningBalanceEntryProducts",
					,
					Cancel
				);
			EndIf;
			If Not ValueIsFilled(CurRow.Products) Then
				MessageText = StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = 'Specify item of list of goods in line %1.'"),
					CurRow.LineNumber);
				CommonUseClientServer.MessageToUser(
					MessageText,
					,
					"OpeningBalanceEntryProducts",
					,
					Cancel
				);
			EndIf;
			If Not ValueIsFilled(CurRow.MeasurementUnit) Then
				MessageText = StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = 'Specify unit of measurement in line %1.'"), 
					CurRow.LineNumber);
				CommonUseClientServer.MessageToUser(
					MessageText,
					,
					"OpeningBalanceEntryProducts",
					,
					Cancel
				);
			EndIf;
			If Not ValueIsFilled(CurRow.Quantity) Then
				MessageText = StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = 'Specify quantity in line %1.'"),
					CurRow.LineNumber);
				CommonUseClientServer.MessageToUser(
					MessageText,
					,
					"OpeningBalanceEntryProducts",
					,
					Cancel
				);
			EndIf;
		EndDo;
		
	ElsIf mCurrentPageNumber = 3 Then
		
		For Each CurRow In OpeningBalanceEntryCounterpartiesSettlements.AccountsPayable Do
			If Not ValueIsFilled(CurRow.Counterparty) Then
				MessageText = StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = 'Specify counterparty in line %1.'"),
					CurRow.LineNumber);
				CommonUseClientServer.MessageToUser(
					MessageText,
					,
					"OpeningBalanceEntryCounterpartiesSettlements",
					,
					Cancel
				);
			EndIf;
			If Not ValueIsFilled(CurRow.Contract) Then
				MessageText = StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = 'Specify contract in the line %1.'"),
					CurRow.LineNumber);
				CommonUseClientServer.MessageToUser(
					MessageText,
					,
					"OpeningBalanceEntryCounterpartiesSettlements",
					,
					Cancel
				);
			EndIf;
			If Not ValueIsFilled(CurRow.AmountCur) Then
				MessageText = StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = 'Specify amount in line %1.'"),
					CurRow.LineNumber);
				CommonUseClientServer.MessageToUser(
					MessageText,
					,
					"OpeningBalanceEntryCounterpartiesSettlements",
					,
					Cancel
				);
			EndIf;
			If ForeignExchangeAccounting = PredefinedValue("Enum.YesNo.Yes")
			AND Not ValueIsFilled(CurRow.Amount) Then
			
				CommonUseClientServer.MessageToUser(StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = 'Specify presentation currency amount in line %1.'"),
					CurRow.LineNumber),,
				"OpeningBalanceEntryProducts",,
				Cancel);
				
			EndIf;
		EndDo;
		
	ElsIf mCurrentPageNumber = 4 Then
		
		For Each CurRow In OpeningBalanceEntryCounterpartiesSettlements.AccountsReceivable Do
			If Not ValueIsFilled(CurRow.Counterparty) Then
				MessageText = StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = 'Specify counterparty in line %1.'"),
					CurRow.LineNumber);
				CommonUseClientServer.MessageToUser(
					MessageText,
					,
					"OpeningBalanceEntryCounterpartiesSettlements",
					,
					Cancel
				);
			EndIf;
			If Not ValueIsFilled(CurRow.Contract) Then
				MessageText = StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = 'Specify contract in line %1.'"),
					CurRow.LineNumber);
				CommonUseClientServer.MessageToUser(
					MessageText,
					,
					"OpeningBalanceEntryCounterpartiesSettlements",
					,
					Cancel
				);
			EndIf;
			If Not ValueIsFilled(CurRow.AmountCur) Then
				MessageText = StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = 'Specify amount in the line %1.'"),
					CurRow.LineNumber);
				CommonUseClientServer.MessageToUser(
					MessageText,
					,
					"OpeningBalanceEntryCounterpartiesSettlements",
					,
					Cancel
				);
			EndIf;
			If ForeignExchangeAccounting = PredefinedValue("Enum.YesNo.Yes")
			AND Not ValueIsFilled(CurRow.Amount) Then
				MessageText = StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = 'Specify amount in presentation currency in line %1.'"),
					CurRow.LineNumber);
				CommonUseClientServer.MessageToUser(
					MessageText,
					,
					"OpeningBalanceEntryProducts",
					,
					Cancel
				);
			EndIf;
		EndDo;
		
	EndIf;
	
EndProcedure

// Imports the form settings.
// If settings are imported during form attribute
// change, for example for new company, it shall be checked
// whether extension for file handling is enabled.
//
// Data in attributes of the processed object will be a flag of connection failure:
// ExportFile, ImportFile
//
&AtServer
Procedure ImportFormSettings()
	
	Settings = SystemSettingsStorage.Load("CommonForm.OpeningBalanceFillingWizard", "FormSettings");
	
	If Settings <> Undefined Then
		AssistantSimpleUseMode = Settings.Get("AssistantSimpleUseMode");
	EndIf;
	
EndProcedure

// Saves form settings.
//
&AtServer
Procedure SaveFormSettings()
	
	Settings = New Map;
	Settings.Insert("AssistantSimpleUseMode", AssistantSimpleUseMode);
	SystemSettingsStorage.Save("CommonForm.OpeningBalanceFillingWizard", "FormSettings", Settings);
	
EndProcedure

#EndRegion

#Region FormEventHandlers

// Procedure - OnOpen form event handler
//
&AtClient
Procedure OnOpen(Cancel)
	
	mCurrentPageNumber = 0;
	mFirstPage = 0;
	mLastPage = 5;
	mFormRecordCompleted = False;
	
	SetActivePage();
	SetButtonsEnabled();
	
EndProcedure

// Procedure - event handler OnCreateAtServer of the form.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Company = Catalogs.Companies.MainCompany;
		
	Query = New Query;
	Query.Text =
	"SELECT
	|	OpeningBalanceEntry.Ref,
	|	OpeningBalanceEntry.Comment,
	|	OpeningBalanceEntry.AccountingSection,
	|	OpeningBalanceEntry.Autogeneration,
	|	OpeningBalanceEntry.Date
	|FROM
	|	Document.OpeningBalanceEntry AS OpeningBalanceEntry
	|WHERE
	|	OpeningBalanceEntry.Comment LIKE &Comment";
	
	Query.SetParameter("Comment", "# Document is entered by the balances input assistant.");
	
	SelectionQueryResult = Query.Execute().Select();
	
	While SelectionQueryResult.Next() Do
		If SelectionQueryResult.AccountingSection = "Cash assets" Then
			ValueToFormAttribute(SelectionQueryResult.Ref.GetObject(), "OpeningBalanceEntryBankAndPettyCash");
		ElsIf SelectionQueryResult.AccountingSection = "Inventory" Then
			ValueToFormAttribute(SelectionQueryResult.Ref.GetObject(), "OpeningBalanceEntryProducts");
		ElsIf SelectionQueryResult.AccountingSection = "Accounts payable and customers" Then
			ValueToFormAttribute(SelectionQueryResult.Ref.GetObject(), "OpeningBalanceEntryCounterpartiesSettlements");
			AutoGenerateAccountingDocuments = ?(
				SelectionQueryResult.Autogeneration,
				Enums.YesNo.Yes,
				Enums.YesNo.No
			);
		EndIf;
		BalanceDate = SelectionQueryResult.Date;
	EndDo;
	
	UseSeveralWarehouses = ?(
		Constants.UseSeveralWarehouses.Get(),
		Enums.YesNo.Yes,
		Enums.YesNo.No
	);
	
	UseSeveralUnitsForProduct = ?(
		Constants.UseSeveralUnitsForProduct.Get(),
		Enums.YesNo.Yes,
		Enums.YesNo.No
	);
	
	UseCharacteristics = ?(
		Constants.UseCharacteristics.Get(),
		Enums.YesNo.Yes,
		Enums.YesNo.No
	);
	
	UseBatches = ?(
		Constants.UseBatches.Get(),
		Enums.YesNo.Yes,
		Enums.YesNo.No
	);
	
	ForeignExchangeAccounting = ?(
		Constants.ForeignExchangeAccounting.Get(),
		Enums.YesNo.Yes,
		Enums.YesNo.No
	);
	
	PresentationCurrency = Constants.PresentationCurrency.Get();
	FunctionalCurrency = Constants.FunctionalCurrency.Get();
	
	If ForeignExchangeAccounting = Enums.YesNo.Yes Then
		Items.PresentationCurrency.ReadOnly = False;
		Items.PresentationCurrency.AutoChoiceIncomplete = True;
		Items.PresentationCurrency.AutoMarkIncomplete = True;
		Items.FunctionalCurrency.ReadOnly = False;
		Items.FunctionalCurrency.AutoChoiceIncomplete = True;
		Items.FunctionalCurrency.AutoMarkIncomplete = True;
	Else
		Items.PresentationCurrency.ReadOnly = True;
		Items.PresentationCurrency.AutoChoiceIncomplete = False;
		Items.PresentationCurrency.AutoMarkIncomplete = False;
		Items.FunctionalCurrency.ReadOnly = True;
		Items.FunctionalCurrency.AutoChoiceIncomplete = False;
		Items.FunctionalCurrency.AutoMarkIncomplete = False;
	EndIf;
	
	ImportFormSettings();
	
	If Not ValueIsFilled(AssistantSimpleUseMode) Then
		AssistantSimpleUseMode = Enums.YesNo.Yes;
	EndIf;
	
	SetAssistantUsageMode();
	
	// Filling in the additional attributes of tabular section.
	SetAccountsAttributesVisible(, , , "AccountsPayable");
	SetAccountsAttributesVisible(, , , "AccountsReceivable");
	
	If Not ValueIsFilled(BalanceDate) Then
		BalanceDate = CurrentDate();
	EndIf;
	
	Items.OpeningBalanceEntryProductsInventoryDataImportFromExternalSources.Visible =
		AccessRight("Use", Metadata.DataProcessors.DataImportFromExternalSources);
	
	// StandardSubsystems.DataImportFromExternalSources
	DataImportFromExternalSources.OnCreateAtServer(Metadata.Documents.OpeningBalanceEntry.TabularSections.Inventory, DataLoadSettings, ThisObject, False);
	// End StandardSubsystems.DataImportFromExternalSource
	
EndProcedure

// Procedure - event handler BeforeClose form.
//
&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)	
	
	If Not mFormRecordCompleted
		AND Modified Then
		
		If Exit Then
			WarningText = NStr("en = 'Data will be lost'"); 			
			Return;			
		EndIf;
		
		Cancel = True;
		NotifyDescription = New NotifyDescription("BeforeCloseEnd", ThisObject);
		Text = NStr("en = 'Save changes?'");
		ShowQueryBox(NotifyDescription, Text, QuestionDialogMode.YesNoCancel);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeCloseEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		Cancel = False;
		ExecuteActionsOnTransitionToNextPage(Cancel);
		If Not Cancel Then
			WriteFormChanges();
			SaveFormSettings();
			Modified = False;
			Close();
		EndIf;
	ElsIf Result = DialogReturnCode.No Then
		Modified = False;
		Close();
	EndIf;
	
EndProcedure

// Procedure - event handler of the form NotificationProcessing.
//
&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "AfterRecordingOfCounterparty" Then
		If ValueIsFilled(Parameter) Then
			For Each CurRow In OpeningBalanceEntryCounterpartiesSettlements.AccountsReceivable Do
				If Parameter = CurRow.Counterparty Then
					SetAccountsAttributesVisible(, , , "AccountsReceivable");
					Return;
				EndIf;
			EndDo;
			For Each CurRow In OpeningBalanceEntryCounterpartiesSettlements.AccountsPayable Do
				If Parameter = CurRow.Counterparty Then
					SetAccountsAttributesVisible(, , , "AccountsPayable");
					Return;
				EndIf;
			EndDo;
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region ActionsOfTheFormCommandPanels

// Procedure - CloseForm command handler.
//
&AtClient
Procedure CloseForm(Command)
	
	Close(False);
	
EndProcedure

// Procedure - Next command handler.
//
&AtClient
Procedure GoToNext(Command)
	
	Cancel = False;
	ExecuteActionsOnTransitionToNextPage(Cancel);
	If Cancel Then
		Return;
	EndIf;
	
	If mCurrentPageNumber = mLastPage Then
		WriteFormChanges(True);
		mFormRecordCompleted = True;
		SaveFormSettings();
		Close(True);
	EndIf;
	
	mCurrentPageNumber = ?(mCurrentPageNumber + 1 > mLastPage, mLastPage, mCurrentPageNumber + 1);
	SetActivePage();
	SetButtonsEnabled();
	
EndProcedure

// Procedure - Back command handler.
//
&AtClient
Procedure Back(Command)
	
	Cancel = False;
	ExecuteActionsOnTransitionToNextPage(Cancel);
	If Cancel Then
		Return;
	EndIf;
	
	mCurrentPageNumber = ?(mCurrentPageNumber - 1 < mFirstPage, mFirstPage, mCurrentPageNumber - 1);
	SetActivePage();
	SetButtonsEnabled();
	
EndProcedure

// Procedure - handler of the AddProducts command.
//
&AtClient
Procedure AddProducts(Command)
	
	If Not ValueIsFilled(Products) Then
		MessageText = NStr("en = 'Please enter the product name.'");
		ShowMessageBox(Undefined,MessageText);
		Return;
	EndIf;
	
	ReturnStructure = AddProductsAtServer(Products, UseBatches, UseCharacteristics);
	ProductsToAdd = ReturnStructure.Products;
	
	SearchStructure = New Structure;
	SearchStructure.Insert("Products", ProductsToAdd);
	RowArray = OpeningBalanceEntryProducts.Inventory.FindRows(SearchStructure);
	
	If RowArray.Count() = 0 Then
		NewRow = OpeningBalanceEntryProducts.Inventory.Add();
		NewRow.Products = ProductsToAdd;
		NewRow.MeasurementUnit = PredefinedValue("Catalog.UOMClassifier.pcs");
		NewRow.Quantity = 1;
		NewRow.StructuralUnit = ReturnStructure.StructuralUnit;
	Else
		RowArray[0].Quantity = RowArray[0].Quantity + 1;
		CalculateAmountInTabularSectionLine();
	EndIf;
	
EndProcedure

// Procedure - handler of the GoToPricing command.
//
&AtClient
Procedure GoToPricing(Command)
	
	AddressInventoryInStorage = PlaceInventoryToStorage();
	
	ParametersStructure = New Structure(
		"AddressInventoryInStorage, ToDate",
		AddressInventoryInStorage,
		BalanceDate
	);
	
	Notification = New NotifyDescription("GoToPricingCompletion",ThisForm);
	OpenForm("DataProcessor.Pricing.Form", ParametersStructure,,,,,Notification);
	
EndProcedure

&AtClient
Procedure GoToPricingCompletion(GenerationResult,Parameters) Export
	
	Result = GenerationResult;
	
EndProcedure

// Procedure - handler of the DocumentsListOpeningBalanceEntry command.
//
&AtClient
Procedure DocumentsListOpeningBalanceEntry(Command)
	
	If Modified Then
		Text = NStr("en = 'All entered data will be saved. Continue?'");
		Mode = QuestionDialogMode.YesNo;
		Response = Undefined;

		ShowQueryBox(New NotifyDescription("DocumentsListOpeningBalanceEntryEnd", ThisObject), Text, Mode, 0);
        Return;
	EndIf;
	
	DocumentsListOpeningBalanceEntryFragment();
EndProcedure

&AtClient
Procedure DocumentsListOpeningBalanceEntryEnd(Result, AdditionalParameters) Export
    
    Response = Result;
    If Response = DialogReturnCode.No Then
        Return;
    EndIf;
    WriteFormChanges(True);
    mFormRecordCompleted = True;
    SaveFormSettings();
    Modified = False;
    
    DocumentsListOpeningBalanceEntryFragment();

EndProcedure

&AtClient
Procedure DocumentsListOpeningBalanceEntryFragment()
    
    OpenForm("Document.OpeningBalanceEntry.ListForm");

EndProcedure

#EndRegion

#Region EventHandlersOfFormAttributes

// Procedure - event handler OnEditEnd attribute OpeningBalanceEntryProductsInventory.
//
&AtClient
Procedure OpeningBalanceEntryProductsInventoryOnEditEnd(Item, NewRow, CancelEdit)
	
	TabularSectionRow = Items.OpeningBalanceEntryProductsInventory.CurrentData;
	If TabularSectionRow <> Undefined
		AND Not ValueIsFilled(TabularSectionRow.StructuralUnit) Then
		TabularSectionRow.StructuralUnit = PredefinedValue("Catalog.BusinessUnits.MainWarehouse");
	EndIf;
	
EndProcedure

// Procedure - handler of the OnChange event of the ForeignExchangeAccounting attribute.
//
&AtClient
Procedure CurrencyTransactionsAccountingOnChange(Item)
	
	NeedToRefreshInterface = False;
	
	WriteChangesCurrencyTransactionsAccounting(ForeignExchangeAccounting);
	Items.Pages.CurrentPage = Items.Step1;
	
	If NeedToRefreshInterface Then
		Items.OpeningBalanceEntryCounterpartiesSettlementsAccountsPayable.Visible = False;
		Items.OpeningBalanceEntryCounterpartiesSettlementsAccountsPayable.Visible = True;
	EndIf;
	
EndProcedure

// Procedure - event handler OnChange of attribute OpeningBalanceEntryProductsInventoryPrice.
//
&AtClient
Procedure OpeningBalanceEntryProductsInventoryPriceOnChange(Item)
	
	CalculateAmountInTabularSectionLine();
	
EndProcedure

// Procedure - handler of the OnChange event of the UseSeveralWarehouses attribute.
//
&AtClient
Procedure AccountingBySeveralWarehousesOnChange(Item)
	
	WriteChangesAccountingBySeveralWarehouses(UseSeveralWarehouses);
	
	Items.OpeningBalanceEntryProductsInventory.Visible = False;
	Items.OpeningBalanceEntryProductsInventory.Visible = True;
	
EndProcedure

// Procedure - event handler OnChange of attribute OpeningBalanceEntryProductsInventoryQuantity.
//
&AtClient
Procedure OpeningBalanceEntryProductsInventoryQuantityOnChange(Item)
	
	CalculateAmountInTabularSectionLine();
	
EndProcedure

// Procedure - event handler OnChange of attribute OpeningBalanceEntryProductsInventoryAmount.
//
&AtClient
Procedure OpeningBalanceEntryProductsInventoryAmountOnChange(Item)
	
	TabularSectionRow = Items.OpeningBalanceEntryProductsInventory.CurrentData;
	
	// Price.
	If TabularSectionRow.Quantity <> 0 Then
		TabularSectionRow.Price = TabularSectionRow.Amount / TabularSectionRow.Quantity;
	EndIf;
	
EndProcedure

// Procedure - handler of the OnChange event of the UseSeveralUnitsForProduct attribute.
//
&AtClient
Procedure AccountingInVariousUOMOnChange(Item)
	
	WriteChangesAccountingInVariousUOM(UseSeveralUnitsForProduct);
	
	Items.OpeningBalanceEntryProductsInventory.Visible = False;
	Items.OpeningBalanceEntryProductsInventory.Visible = True;
	
EndProcedure

// Procedure - handler of the OnChange event of the UseCharacteristics attribute.
//
&AtClient
Procedure UseCharacteristicsOnChange(Item)
	
	WriteChangesUseCharacteristics(UseCharacteristics);
	Items.OpeningBalanceEntryProductsInventory.Visible = False;
	Items.OpeningBalanceEntryProductsInventory.Visible = True;
	
EndProcedure

// Procedure - handler of the OnChange event of the UseBatches attribute.
//
&AtClient
Procedure UseBatchesOnChange(Item)
	
	WriteChangesUseBatches(UseBatches);
	Items.OpeningBalanceEntryProductsInventory.Visible = False;
	Items.OpeningBalanceEntryProductsInventory.Visible = True;
	
EndProcedure

// Procedure - handler of the OnChange event of the InputInitialBalancesBankAndPettyCashCashAssetsAmountCur attribute.
//
&AtClient
Procedure OpeningBalanceEntryBankAndPettyCashCashAssetsAmountCurOnChange(Item)
	
	TabularSectionRow = Items.OpeningBalanceEntryBankAndPettyCashCashAssets.CurrentData;
	
	TabularSectionRow.Amount = DriveServer.RecalculateFromCurrencyToAccountingCurrency(TabularSectionRow.AmountCur,
																								TabularSectionRow.CashCurrency,
																								BalanceDate);
EndProcedure

// Procedure - handler of the OnChange event of the InputOpeningBalancesBankAndPettyCashCashAssetsBankAccountPettyCash attribute.
//
&AtClient
Procedure OpeningBalanceEntryBankAndPettyCashCashAssetsBankAccountPettyCashOnChange(Item)
	
	TabularSectionRow = Items.OpeningBalanceEntryBankAndPettyCashCashAssets.CurrentData;
	
	StructureData = GetDataCashAssetsBankAccountPettyCashOnChange(TabularSectionRow.BankAccountPettyCash);
	
	TabularSectionRow.CashCurrency = StructureData.Currency;
	
	TabularSectionRow.Amount = DriveServer.RecalculateFromCurrencyToAccountingCurrency(TabularSectionRow.AmountCur,
																								TabularSectionRow.CashCurrency,
																								BalanceDate);
EndProcedure

// Procedure - handler of the OnChange event of the InputOpeningBalancesBankAndPettyCashCashAssetsCurrencyCashAssets attribute.
//
&AtClient
Procedure OpeningBalanceEntryBankAndPettyCashCashAssetsCurrencyOfCashAssetsOnChange(Item)
	
	TabularSectionRow = Items.OpeningBalanceEntryBankAndPettyCashCashAssets.CurrentData;
	
	TabularSectionRow.Amount = DriveServer.RecalculateFromCurrencyToAccountingCurrency(TabularSectionRow.AmountCur,
																								TabularSectionRow.CashCurrency,
																								BalanceDate);
EndProcedure

// Procedure - handler of the SelectionStart event of the
//             InputOpeningBalancesBankAndPettyCashCashAssetsCurrencyCashAssets attribute.
//
&AtClient
Procedure OpeningBalanceEntryBankAndPettyCashCashAssetsCurrencyOfCashAssetsStartChoice(Item, ChoiceData, StandardProcessing)
	
	TabularSectionRow = Items.OpeningBalanceEntryBankAndPettyCashCashAssets.CurrentData;
	
	// If type of cash assets is changed, appropriate actions are required.
	If TypeOf(TabularSectionRow.BankAccountPettyCash) = Type("CatalogRef.BankAccounts") Then
		ShowMessageBox(Undefined,NStr("en = 'Cannot change the cash currency of the bank account.'"));
		StandardProcessing = False;
	EndIf;
	
EndProcedure

// It receives data set from the server for the CounterpartyOnChange procedure.
//
&AtServer
Function GetDataCounterpartyOnChange(Counterparty, Company, TabularSectionName)
	
	StructureData = New Structure("Contract, SettlementsCurrency");
	
	Query = New Query;
	Query.Text = "SELECT
	|	CounterpartyContracts.Ref AS Ref,
	|	CounterpartyContracts.SettlementsCurrency AS SettlementsCurrency
	|FROM
	|	Catalog.CounterpartyContracts AS CounterpartyContracts
	|WHERE
	|	CounterpartyContracts.Owner = &Counterparty
	|	AND CounterpartyContracts.Company = &Company";
	Query.SetParameter("Counterparty",	Counterparty);
	Query.SetParameter("Company",		Company);
	
	QueryResult	= Query.Execute();
	Selection	= QueryResult.Select();
	
	Selection.Select();
	
	FillPropertyValues(StructureData, Selection);
	
	StructureData.Insert("DoOperationsByContracts", Counterparty.DoOperationsByContracts);
	StructureData.Insert("DoOperationsByDocuments", Counterparty.DoOperationsByDocuments);
	StructureData.Insert("DoOperationsByOrders",	Counterparty.DoOperationsByOrders);
	
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
	
	FillServiceAttributesByCounterpartyInCollection(OpeningBalanceEntryCounterpartiesSettlements[TabularSectionName]);
	
	For Each CurRow In OpeningBalanceEntryCounterpartiesSettlements[TabularSectionName] Do
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
		Items.OpeningBalanceEntryCounterpartiesSettlementsAccountsPayableContract.Visible = DoOperationsByContracts;
		Items.OpeningBalanceEntryCounterpartiesSettlementsAccountsPayableDocument.Visible = DoOperationsByDocuments;
		Items.OpeningBalanceEntryCounterpartiesSettlementsAccountsPayablePurchaseOrder.Visible = DoOperationsByOrders;
	ElsIf TabularSectionName = "AccountsReceivable" Then
		Items.OpeningBalanceEntryCounterpartiesSettlementsAccountsReceivableContract.Visible = DoOperationsByContracts;
		Items.OpeningBalanceEntryCounterpartiesSettlementsAccountsReceivableDocument.Visible = DoOperationsByDocuments;
		Items.OpeningBalanceEntryCounterpartiesSettlementsAccountsReceivableSalesOrder.Visible = DoOperationsByOrders;
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

// Procedure - handler of the OnChange event of input field.
//
&AtClient
Procedure OpeningBalanceEntryCounterpartiesSettlementsAccountsPayableCounterpartyOnChange(Item)
	
	TabularSectionRow = Items.OpeningBalanceEntryCounterpartiesSettlementsAccountsPayable.CurrentData;
	StructureData = GetDataCounterpartyOnChange(TabularSectionRow.Counterparty, Company, "AccountsPayable");
	TabularSectionRow.Contract = StructureData.Contract;
	
	TabularSectionRow.Amount = DriveServer.RecalculateFromCurrencyToAccountingCurrency(TabularSectionRow.AmountCur,
																								StructureData.SettlementsCurrency,
																								BalanceDate);
	TabularSectionRow.DoOperationsByContracts = StructureData.DoOperationsByContracts;
	TabularSectionRow.DoOperationsByDocuments = StructureData.DoOperationsByDocuments;
	TabularSectionRow.DoOperationsByOrders = StructureData.DoOperationsByOrders;
	
EndProcedure

// Procedure - handler of the OnChange event of input field.
//
&AtClient
Procedure OpeningBalanceEntryCounterpartiesSettlementsAccountsReceivableCounterpartyOnChange(Item)
	
	TabularSectionRow = Items.OpeningBalanceEntryCounterpartiesSettlementsAccountsReceivable.CurrentData;
	StructureData = GetDataCounterpartyOnChange(TabularSectionRow.Counterparty, Company, "AccountsReceivable");
	TabularSectionRow.Contract = StructureData.Contract;
	
	TabularSectionRow.Amount = DriveServer.RecalculateFromCurrencyToAccountingCurrency(TabularSectionRow.AmountCur,
																								StructureData.SettlementsCurrency,
																								BalanceDate);
	TabularSectionRow.DoOperationsByContracts = StructureData.DoOperationsByContracts;
	TabularSectionRow.DoOperationsByDocuments = StructureData.DoOperationsByDocuments;
	TabularSectionRow.DoOperationsByOrders = StructureData.DoOperationsByOrders;
	
EndProcedure

// Procedure - handler of clicking on the input field.
//
&AtClient
Procedure Decoration47Click(Item)
	
	Cancel = False;
	ExecuteActionsOnTransitionToNextPage(Cancel);
	If Cancel Then
		Return;
	EndIf;
	
	mCurrentPageNumber = 1;
	SetActivePage();
	SetButtonsEnabled();
	
EndProcedure

// Procedure - handler of clicking on the input field.
//
&AtClient
Procedure Decoration53Click(Item)
	
	Cancel = False;
	ExecuteActionsOnTransitionToNextPage(Cancel);
	If Cancel Then
		Return;
	EndIf;
	
	mCurrentPageNumber = 3;
	SetActivePage();
	SetButtonsEnabled();
	
EndProcedure

// Procedure - handler of clicking on the input field.
//
&AtClient
Procedure Decoration50Click(Item)
	
	Cancel = False;
	ExecuteActionsOnTransitionToNextPage(Cancel);
	If Cancel Then
		Return;
	EndIf;
	
	mCurrentPageNumber = 2;
	SetActivePage();
	SetButtonsEnabled();
	
EndProcedure

// Procedure - handler of clicking on the input field.
//
&AtClient
Procedure Decoration56Click(Item)
	
	Cancel = False;
	ExecuteActionsOnTransitionToNextPage(Cancel);
	If Cancel Then
		Return;
	EndIf;
	
	mCurrentPageNumber = 4;
	SetActivePage();
	SetButtonsEnabled();
	
EndProcedure

// Procedure - handler of clicking on the input field.
//
&AtClient
Procedure Decoration133Click(Item)
	
	mCurrentPageNumber = 0;
	SetActivePage();
	SetButtonsEnabled();
	
EndProcedure

// Procedure - handler of the OnChange event of the Products attribute in tablular section.
//
&AtClient
Procedure OpeningBalanceEntryProductsInventoryProductsOnChange(Item)
	
	TabularSectionRow = Items.OpeningBalanceEntryProductsInventory.CurrentData;
	
	StructureData = New Structure();
	StructureData.Insert("Products", TabularSectionRow.Products);
	StructureData.Insert("InventoryGLAccount",	TabularSectionRow.InventoryGLAccount);
	
	ObjectParameters = New Structure;
	ObjectParameters.Insert("Company", Company);
	ObjectParameters.Insert("StructuralUnit", TabularSectionRow.StructuralUnit);
	ObjectParameters.Insert("Ref", PredefinedValue("Document.OpeningBalanceEntry.EmptyRef"));

	StructureData.Insert("ObjectParameters", ObjectParameters);
	StructureData = GetDataProductsOnChange(StructureData);
	
	FillPropertyValues(TabularSectionRow, StructureData); 
	If TabularSectionRow.Quantity = 0 Then
		TabularSectionRow.Quantity = 1;
	EndIf;
	
EndProcedure

&AtClient
// Procedure - event handler ChoiceProcessing of the MeasurementUnit input field.
//
Procedure OpeningBalanceEntryProductsInventoryMeasurementUnitChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	TabularSectionRow = Items.OpeningBalanceEntryProductsInventory.CurrentData;
	
	If TabularSectionRow.MeasurementUnit = ValueSelected
		OR TabularSectionRow.Price = 0 Then
		Return;
	EndIf;
	
	CurrentFactor = 0;
	If TypeOf(TabularSectionRow.MeasurementUnit) = Type("CatalogRef.UOMClassifier") Then
		CurrentFactor = 1;
	EndIf;
	
	Factor = 0;
	If TypeOf(ValueSelected) = Type("CatalogRef.UOMClassifier") Then
		Factor = 1;
	EndIf;
	
	If CurrentFactor = 0 AND Factor = 0 Then
		StructureData = GetDataMeasurementUnitOnChange(TabularSectionRow.MeasurementUnit, ValueSelected);
	ElsIf CurrentFactor = 0 Then
		StructureData = GetDataMeasurementUnitOnChange(TabularSectionRow.MeasurementUnit);
	ElsIf Factor = 0 Then
		StructureData = GetDataMeasurementUnitOnChange(,ValueSelected);
	ElsIf CurrentFactor = 1 AND Factor = 1 Then
		StructureData = New Structure("CurrentFactor, Factor", 1, 1);
	EndIf;
	
	// Price.
	If StructureData.CurrentFactor <> 0 Then
		TabularSectionRow.Price = TabularSectionRow.Price * StructureData.Factor / StructureData.CurrentFactor;
	EndIf;
	
	CalculateAmountInTabularSectionLine();
	
EndProcedure

// Procedure - handler of the OnChange event of the AmountCur attribute in tabular section.
//
&AtClient
Procedure OpeningBalanceEntryCounterpartiesSettlementsAccountsPayableAmountValOnChange(Item)
	
	TabularSectionRow = Items.OpeningBalanceEntryCounterpartiesSettlementsAccountsPayable.CurrentData;
	
	TabularSectionRow.Amount = DriveServer.RecalculateFromCurrencyToAccountingCurrency(TabularSectionRow.AmountCur,
																								TabularSectionRow.Contract,
																								BalanceDate);
EndProcedure

// Procedure - handler of the OnChange event of the AmountCur attribute in tabular section.
//
&AtClient
Procedure OpeningBalanceEntryCounterpartiesSettlementsAccountsReceivableAmountCurOnChange(Item)
	
	TabularSectionRow = Items.OpeningBalanceEntryCounterpartiesSettlementsAccountsReceivable.CurrentData;
	
	TabularSectionRow.Amount = DriveServer.RecalculateFromCurrencyToAccountingCurrency(TabularSectionRow.AmountCur,
																								TabularSectionRow.Contract,
																								BalanceDate);
EndProcedure

// Procedure - handler of the OnChange event of the AccountsReceivableContract attribute in tabular section.
//
&AtClient
Procedure OpeningBalanceEntryCounterpartiesSettlementsAccountsReceivableContractOnChange(Item)
	
	TabularSectionRow = Items.OpeningBalanceEntryCounterpartiesSettlementsAccountsReceivable.CurrentData;
	
	TabularSectionRow.Amount = DriveServer.RecalculateFromCurrencyToAccountingCurrency(TabularSectionRow.AmountCur,
																								TabularSectionRow.Contract,
																								BalanceDate);
EndProcedure

// Procedure - handler of the OnChange event of the AccountsPayableContract attribute in tabular section.
//
&AtClient
Procedure OpeningBalanceEntryCounterpartiesSettlementsAccountsPayableContractOnChange(Item)
	
	TabularSectionRow = Items.OpeningBalanceEntryCounterpartiesSettlementsAccountsPayable.CurrentData;
	
	TabularSectionRow.Amount = DriveServer.RecalculateFromCurrencyToAccountingCurrency(TabularSectionRow.AmountCur,
																								TabularSectionRow.Contract,
																								BalanceDate);
EndProcedure

// Procedure - handler of the OnChange event of the AssistantSimpleUseMode attribute in tabular section.
//
&AtClient
Procedure AssistantSimpleUseModeOnChange(Item)
	
	SetAssistantUsageMode();
	
EndProcedure

// Procedure changes the visible of attributes depending on the usage mode.
//
&AtServer
Procedure SetAssistantUsageMode()
	
	AdditionalAttributesVisible = AssistantSimpleUseMode = Enums.YesNo.No;
	
	Items.Step1FOTitle.Visible = AdditionalAttributesVisible;
	Items.Step1FO.Visible = AdditionalAttributesVisible;
	Items.Step2FOTitle.Visible = AdditionalAttributesVisible;
	Items.Step2FO.Visible = AdditionalAttributesVisible;
	
EndProcedure

// Procedure - event data processor.
//
&AtClient
Procedure OpeningBalanceEntryCounterpartiesSettlementsAccountsPayableAfterDeleteRowRow(Item)
	
	SetAccountsAttributesVisible(, , , "AccountsPayable");
	
EndProcedure

// Procedure - event data processor.
//
&AtClient
Procedure OpeningBalanceEntryCounterpartiesSettlementsAccountsReceivableAfterDeleteRowRow(Item)
	
	SetAccountsAttributesVisible(, , , "AccountsReceivable");
	
EndProcedure

// Procedure - event data processor.
//
&AtClient
Procedure DateOfChange(Item)
	
	BalanceDateOnChangeAtServer();
	
EndProcedure

// Procedure - event data processor.
//
&AtServer
Procedure BalanceDateOnChangeAtServer()
	
	For Each CurRow In OpeningBalanceEntryBankAndPettyCash.CashAssets Do
		
		CurRow.Amount = DriveServer.RecalculateFromCurrencyToAccountingCurrency(CurRow.AmountCur,
																						CurRow.CashCurrency,
																						BalanceDate);
	EndDo;
	
	For Each CurRow In OpeningBalanceEntryCounterpartiesSettlements.AccountsPayable Do
		
		CurRow.Amount = DriveServer.RecalculateFromCurrencyToAccountingCurrency(CurRow.AmountCur,
																						CurRow.Contract,
																						BalanceDate);
	EndDo;
	
	For Each CurRow In OpeningBalanceEntryCounterpartiesSettlements.AccountsReceivable Do
		
		CurRow.Amount = DriveServer.RecalculateFromCurrencyToAccountingCurrency(CurRow.AmountCur,
																						CurRow.Contract,
																						BalanceDate);
	EndDo;
	
EndProcedure

&AtClient
Procedure OpeningBalanceEntryCounterpartiesSettlementsAccountsPayableAdvanceFlagOnChange(Item)
	
	TabularSectionRow = Items.OpeningBalanceEntryCounterpartiesSettlementsAccountsPayable.CurrentData;
	
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

&AtClient
Procedure OpeningBalanceEntryCounterpartiesSettlementsAccountsPayableDocumentOnChange(Item)
	
	TabularSectionRow = Items.OpeningBalanceEntryCounterpartiesSettlementsAccountsPayable.CurrentData;
	
	If TypeOf(TabularSectionRow.Document) = Type("DocumentRef.CashVoucher")
	 OR TypeOf(TabularSectionRow.Document) = Type("DocumentRef.PaymentExpense")
	 OR TypeOf(TabularSectionRow.Document) = Type("DocumentRef.ExpenseReport") Then
		TabularSectionRow.AdvanceFlag = True;
	ElsIf TypeOf(TabularSectionRow.Document) <> Type("DocumentRef.ArApAdjustments") Then
		TabularSectionRow.AdvanceFlag = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure OpeningBalanceEntryCounterpartiesSettlementsAccountsReceivableAdvanceFlagOnChange(Item)
	
	TabularSectionRow = Items.OpeningBalanceEntryCounterpartiesSettlementsAccountsReceivable.CurrentData;
	
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

&AtClient
Procedure OpeningBalanceEntryCounterpartiesSettlementsAccountsReceivableDocumentOnChange(Item)
	
	TabularSectionRow = Items.OpeningBalanceEntryCounterpartiesSettlementsAccountsReceivable.CurrentData;
	
	If TypeOf(TabularSectionRow.Document) = Type("DocumentRef.CashReceipt")
	 OR TypeOf(TabularSectionRow.Document) = Type("DocumentRef.PaymentReceipt") Then
		TabularSectionRow.AdvanceFlag = True;
	ElsIf TypeOf(TabularSectionRow.Document) <> Type("DocumentRef.ArApAdjustments") Then
		TabularSectionRow.AdvanceFlag = False;
	EndIf;
	
EndProcedure

#EndRegion

#Region LibrariesHandlers

// StandardSubsystems.DataImportFromExternalSources
&AtClient
Procedure DataImportFromExternalSources(Command)
	
	DataLoadSettings.FillingObjectFullName = "Document.OpeningBalanceEntry.TabularSection.Inventory";
	NotifyDescription = New NotifyDescription("ImportDataFromExternalSourceResultDataProcessor", ThisObject, DataLoadSettings);
	DataImportFromExternalSourcesClient.ShowDataImportFormFromExternalSource(DataLoadSettings, NotifyDescription, ThisObject);
	
EndProcedure

&AtClient
Procedure DataImportFromExternalSourcesAccountsPayable(Command)
	
	DataLoadSettings.FillingObjectFullName = "Document.OpeningBalanceEntry.TabularSection.AccountsPayable";
	NotifyDescription = New NotifyDescription("ImportDataFromExternalSourceResultDataProcessor", ThisObject, DataLoadSettings);
	DataImportFromExternalSourcesClient.ShowDataImportFormFromExternalSource(DataLoadSettings, NotifyDescription, ThisObject);
	
EndProcedure

&AtClient
Procedure DataImportFromExternalSourcesAccountsReceivable(Command)
	
	DataLoadSettings.FillingObjectFullName = "Document.OpeningBalanceEntry.TabularSection.AccountsReceivable";
	NotifyDescription = New NotifyDescription("ImportDataFromExternalSourceResultDataProcessor", ThisObject, DataLoadSettings);
	DataImportFromExternalSourcesClient.ShowDataImportFormFromExternalSource(DataLoadSettings, NotifyDescription, ThisObject);
	
EndProcedure

&AtClient
Procedure ImportDataFromExternalSourceResultDataProcessor(ImportResult, AdditionalParameters) Export
	
	If TypeOf(ImportResult) = Type("Structure") Then
		ProcessPreparedData(ImportResult, AdditionalParameters);
	EndIf;
	
EndProcedure

&AtServer
Procedure ProcessPreparedData(ImportResult, AdditionalParameters)
	
	FillingObjectFullName = AdditionalParameters.FillingObjectFullName;	
	
	If FillingObjectFullName = "Document.OpeningBalanceEntry.TabularSection.Inventory" Then
		DataImportFromExternalSourcesOverridable.ImportDataFromExternalSourceResultDataProcessor(ImportResult,
																									OpeningBalanceEntryProducts,
																									ThisObject);
	ElsIf FillingObjectFullName = "Document.OpeningBalanceEntry.TabularSection.AccountsPayable" Then
		DataImportFromExternalSourcesOverridable.ImportDataFromExternalSourceResultDataProcessor(ImportResult,
																									OpeningBalanceEntryCounterpartiesSettlements,
																									ThisObject);
	ElsIf FillingObjectFullName = "Document.OpeningBalanceEntry.TabularSection.AccountsReceivable" Then
		DataImportFromExternalSourcesOverridable.ImportDataFromExternalSourceResultDataProcessor(ImportResult,
																									OpeningBalanceEntryCounterpartiesSettlements,
																									ThisObject);
	EndIf;
	
EndProcedure

// End StandardSubsystems.DataImportFromExternalSource

#EndRegion