
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	SetConditionalAppearance();
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
		
	FillCurrencies();
	
	// Start and end of the exchange rates importing period.
	Object.ImportEndOfPeriod = BegOfDay(CurrentSessionDate());
	Object.ImportBeginOfPeriod = Object.ImportEndOfPeriod;
	MinimumDate = BegOfYear(Object.ImportEndOfPeriod);
	For Each Currency In Object.CurrenciesList Do
		If ValueIsFilled(Currency.ExchangeRateDate) AND Currency.ExchangeRateDate < Object.ImportBeginOfPeriod Then
			If Currency.ExchangeRateDate < MinimumDate Then
				Object.ImportBeginOfPeriod = MinimumDate;
				Break;
			EndIf;
			Object.ImportBeginOfPeriod = Currency.ExchangeRateDate;
		EndIf;
	EndDo;
EndProcedure

#EndRegion

#Region FormTableItemEventHandlersCurrencyList

&AtClient
Procedure CurrencyListSelection(Item, SelectedRow, Field, StandardProcessing)
	StandardProcessing = False;
	SwitchExport();
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure ExchangeRatesImport()
	
	ClearMessages();
	
	If Not ValueIsFilled(Object.ImportBeginOfPeriod) Then
		CommonUseClientServer.MessageToUser(
			NStr("en = 'Import period start date is not set.'"),
			,
			"Object.ImportBeginOfPeriod");
		Return;
	EndIf;
	
	If Not ValueIsFilled(Object.ImportEndOfPeriod) Then
		CommonUseClientServer.MessageToUser(
			NStr("en = 'Import period end date is not set.'"),
			,
			"Object.ImportEndOfPeriod");
		Return;
	EndIf;
	
	AttachIdleHandler("Attachable_ImportExchangeRatesFromWebsite", 0.2, True);		
	AttachIdleHandler("Attachable_CheckExecutionExchangeRatesImporting", 1, True);
	Items.Pages.CurrentPage = Items.ExchangeRatesImportProcessInProgress;
	Items.CommandBar.Enabled = False;
	
EndProcedure

&AtClient
Procedure SelectAllCurrencies(Command)
	SetChoice(True);
	SetEnabledOfItems();
EndProcedure

&AtClient
Procedure ClearChoice(Command)
	SetChoice(False);
	SetEnabledOfItems();
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.CurrenciesListExchangeRateDate.Name);

	FilterElement = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("Object.CurrenciesList.ExchangeRateDate");
	FilterElement.ComparisonType = DataCompositionComparisonType.Equal;
	FilterElement.RightValue = New StandardBeginningDate(Date('19800101000000'));

	Item.Appearance.SetParameterValue("Text", "");

EndProcedure

&AtClient
Procedure SetChoice(Selection)
	For Each Currency In Object.CurrenciesList Do
		Currency.Import = Selection;
	EndDo;
EndProcedure

&AtServer
Procedure FillCurrencies()
	
	// Filling the tabular section with the list of currencies, the exchange rate of which is not dependent on the exchange
	// rates of other currencies.
	ImportEndOfPeriod = Object.ImportEndOfPeriod;
	CurrenciesList = Object.CurrenciesList;
	CurrenciesList.Clear();
	
	ExportableCurrencies = WorkWithExchangeRates.GetImportCurrenciesArray();
	
	For Each CurrencyItem In ExportableCurrencies Do
		AddCurrencyToList(CurrencyItem);
	EndDo;
		
EndProcedure

&AtServer
Procedure AddCurrencyToList(Currency)
	
	// Adding a record in the currencies list.
	NewRow = Object.CurrenciesList.Add();
	
	// Filling the information about the exchange rate on the basis of the currency reference.
	FillTableRowDataBasedOnCurrency(NewRow, Currency);
	
	NewRow.Import = True;
	
EndProcedure

&AtServer
Procedure RefreshInfoInCurrenciesList()
	
	// Records update on the currencies exchange rates in the list.
	
	For Each DataRow In Object.CurrenciesList Do
		CurrencyReferences = DataRow.Currency;
		FillTableRowDataBasedOnCurrency(DataRow, CurrencyReferences);
	EndDo;
	
EndProcedure

&AtServer
Procedure FillTableRowDataBasedOnCurrency(TableRow, Currency);
	
	AdditionalInformationOnCurrency = CommonUse.ObjectAttributesValues(Currency, "DescriptionFull,Code,Description");
	
	TableRow.Currency = Currency;
	TableRow.CurrencyCode = AdditionalInformationOnCurrency.Code;
	TableRow.SymbolicCode = AdditionalInformationOnCurrency.Description;
	TableRow.Presentation = AdditionalInformationOnCurrency.DescriptionFull;
	
	ExchangeRateData = WorkWithExchangeRates.FillRateDataForCurrencies(Currency);
	
	If TypeOf(ExchangeRateData) = Type ("Structure") Then
		TableRow.ExchangeRateDate = ExchangeRateData.ExchangeRateDate;
		TableRow.ExchangeRate      = ExchangeRateData.ExchangeRate;
		TableRow.Multiplicity = ExchangeRateData.Multiplicity;
	EndIf;
	
EndProcedure

&AtClient
Procedure CheckListImportableCurrenciesEnd(AdditionalParameters) Export	
	Close();	
EndProcedure

&AtClient
Procedure SetEnabledOfItems()
	
	AreSelectedCurrencies = Object.CurrenciesList.FindRows(New Structure("Import", True)).Count() > 0;
	Items.ExchangeRatesImportForm.Enabled = AreSelectedCurrencies;
	
EndProcedure

&AtClient
Procedure DisconnectExportRateOfSelectedCurrenciesFromInternet(Command)
	
	CurrentData = Items.CurrenciesList.CurrentData;
	ToRemoveExportFromInternetSignUp(CurrentData.Currency);
	Object.CurrenciesList.Delete(CurrentData);
	
EndProcedure

&AtServer
Procedure ToRemoveExportFromInternetSignUp(CurrencyRef)
	
	CurrencyObject = CurrencyRef.GetObject();
	CurrencyObject.SetRateMethod = Enums.ExchangeRateSetupMethod.ManualInput;
	CurrencyObject.Write();
	
EndProcedure

&AtClient
Procedure SwitchExport()
	
	Items.CurrenciesList.CurrentData.Import = Not Items.CurrenciesList.CurrentData.Import;
	SetEnabledOfItems();
	
EndProcedure

&AtClient
Procedure Attachable_ImportExchangeRatesFromWebsite()
	
	ImportExchangeRatesFromWebsite();
	
EndProcedure

&AtServer
Procedure ImportExchangeRatesFromWebsite()
	
	SetPrivilegedMode(True);
	
	ImportParameters = New Structure;
	ImportParameters.Insert("BeginOfPeriod", Object.ImportBeginOfPeriod);
	ImportParameters.Insert("EndOfPeriod", Object.ImportEndOfPeriod);
	ImportParameters.Insert("CurrenciesList", CommonUse.ValueTableToArray(Object.CurrenciesList.Unload(
		Object.CurrenciesList.FindRows(New Structure("Import", True)), "CurrencyCode,Currency")));
	
	ResultAddress = PutToTempStorage(Undefined, UUID);	
		
	WorkWithExchangeRates.ImportExchangeRates(ImportParameters, ResultAddress);
	
EndProcedure

&AtClient
Procedure Attachable_CheckExecutionExchangeRatesImporting()
	
	If ValueIsFilled(ResultAddress) Then
		Items.Pages.CurrentPage = Items.PageCurrenciesList;
		Items.CommandBar.Enabled = True;
		ImportResultProcessing();
		ResultAddress = "";
	Else
		AttachIdleHandler("Attachable_CheckExecutionExchangeRatesImporting", 2, True);
	EndIf;
	
EndProcedure

&AtClient
Procedure ImportResultProcessing()
	
	ImportResult = GetFromTempStorage(ResultAddress);
	
	IsSuccessfullyImportedExchangeRates = False;
	WithoutErrors = True;
	
	ErrorsCount = 0;
	
	ErrorList = New TextDocument;
	For Each ImportStatus In ImportResult Do
		If ImportStatus.OperationStatus Then
			IsSuccessfullyImportedExchangeRates = True;
		Else
			WithoutErrors = False;
			ErrorsCount = ErrorsCount + 1;
			ErrorList.AddLine(ImportStatus.Message + Chars.LF);
		EndIf;
	EndDo;
	
	If IsSuccessfullyImportedExchangeRates Then
		RefreshInfoInCurrenciesList();
		WriteParameters = Undefined;
		UpdatedCurrenciesArray = New Array;
		For Each TableRow In Object.CurrenciesList Do
			UpdatedCurrenciesArray.Add(TableRow.Currency);
		EndDo;
		Notify("Write_ExchangeRatesImportProcess", WriteParameters, UpdatedCurrenciesArray);
		WorkWithExchangeRatesClient.NotifyExchangeRatesSuccessfullyUpdated();
	EndIf;
	
	If WithoutErrors Then
		NotifyDescription = New NotifyDescription("ImportResultProcessingMessageBoxEnd", ThisObject);
		ShowMessageBox(
			NotifyDescription, 
			NStr("en = 'Exchange rates have been successfully imported.'"),
		);
	Else
		ErrorPresentation = TrimAll(ErrorList.GetText());
		If ErrorsCount > 1 Then
			Buttons = New ValueList;
			Buttons.Add("Details", NStr("en = 'More...'"));
			Buttons.Add("Continue", NStr("en = 'Continue'"));
			QuestionText = StringFunctionsClientServer.SubstituteParametersInString(NStr("en = 'Cannot import exchange rates (%1).'"), ErrorsCount);
			NotifyDescription = New NotifyDescription("ImportResultProcessingWhenAnsweringQuestion", ThisObject, ErrorPresentation);
			ShowQueryBox(NotifyDescription, QuestionText, Buttons);
		Else
			ShowMessageBox(, ErrorPresentation);
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure ImportResultProcessingMessageBoxEnd(Parameters) Export
	Close();
EndProcedure

&AtClient
Procedure ImportResultProcessingWhenAnsweringQuestion(QuestionResult, ErrorPresentation) Export
	
	If QuestionResult <> "Details" Then
		Return;
	EndIf;
	
	OpenForm("DataProcessor.ImportExchangeRates.Form.ErrorMessages", New Structure("Text", ErrorPresentation));	
	
EndProcedure

#EndRegion
