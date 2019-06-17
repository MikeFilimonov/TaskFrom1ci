
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	FunctionalCurrency = Constants.FunctionalCurrency.Get();
	
	If Not ValueIsFilled(Object.CashCurrency) Then
		
		Object.CashCurrency = FunctionalCurrency;
		
	EndIf;
	
	// Fill SWIFT.
	FillBankDetails(SWIFTBank, Object.Bank, Object.Owner);
	
	// Fill SWIFT of correspondent bank.
	FillSWIFT(Object.AccountsBank, SWIFTBankForSettlements);
	
	FormItemsManagement();
	
	If Not ValueIsFilled(Object.AccountType) Then
		Object.AccountType = "Transactional";
	EndIf;
	
	DataSeparationEnabled = CommonUseReUse.DataSeparationEnabled();
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End of StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.Printing
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	FillInAccountViewList();
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	// StandardSubsystems.PerformanceMeasurement
	PerformanceEstimationClientServer.StartTimeMeasurement("CatalogBankAccountsWrite");
	// StandardSubsystems.PerformanceMeasurement
	
	// If correspondent bank is not used, clear the bank value.
	If Not BankForSettlementsIsUsed
		AND ValueIsFilled(Object.AccountsBank) Then
		
		Object.AccountsBank = Undefined;
		
	EndIf; 
	
	// Fill in the correspondent text.
	If EditCorrespondentText Then
		Object.CorrespondentText = CorrespondentText;
	Else
		Object.CorrespondentText = "";
	EndIf;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "AccountsChangedBankAccounts" Then
		Object.GLAccount = Parameter.GLAccount;
		Modified = True;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormItemsEventsHandlers

&AtClient
Procedure SWIFTBankOnChange(Item)
	
	FillDescription();
	
	FillInAccountViewList();
	
EndProcedure

&AtClient
Procedure SWIFTBankStartChoice(Item, ChoiceData, StandardProcessing)
	
	OpenBankChoiceForm(True);
	
EndProcedure

&AtClient
Procedure SWIFTBankChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	StandardProcessing = False;
	
	Object.Bank = ValueSelected;
	FillBankDetails(SWIFTBank, Object.Bank, Object.Owner);
	FillDescription();
	
	If IsBlankString(SWIFTBank) Then
		
		CurrentItem = Items.SWIFTBank;
		
	EndIf;
	
	FillInAccountViewList();
	
EndProcedure

&AtClient
Procedure SWIFTBankTextEditEnd(Item, Text, ChoiceData, StandardProcessing)
	
	#If WebClient Then
		
		If StrLen(Text) > 11 Then
			Message = New UserMessage;
			Message.Text = NStr("en = 'Entered value exceeds the allowed length SWIFT of 11 characters.'");
			Message.Message();
			
			StandardProcessing = False;
			
			Return;
			
		EndIf;
		
	#EndIf
	
	ListOfFoundBanks = FindBanks(Text, Item.Name, Object.CashCurrency <> FunctionalCurrency);
	If TypeOf(ListOfFoundBanks) = Type("ValueList") Then
		
		If ListOfFoundBanks.Count() = 1 Then
			
			NotifyChanged(Type("CatalogRef.Banks"));
			
			Object.Bank = ListOfFoundBanks[0].Value;
			FillBankDetails(SWIFTBank, Object.Bank, Object.Owner);
			
		ElsIf ListOfFoundBanks.Count() > 1 Then
			
			NotifyChanged(Type("CatalogRef.Banks"));
			
			OpenBankChoiceForm(True, ListOfFoundBanks);
			
		Else
			
			OpenBankChoiceForm(True);
			
		EndIf;
		
	Else
		
		CurrentItem = Item;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure SWIFTBankForSettlementsStartChoice(Item, ChoiceData, StandardProcessing)
	
	OpenBankChoiceForm(False);
	
EndProcedure

&AtClient
Procedure SWIFTBankForSettlementsTextEditEnd(Item, Text, ChoiceData, StandardProcessing)
	
	#If WebClient Then
		
		If StrLen(Text) > 11 Then
			Message = New UserMessage;
			Message.Text = NStr("en = 'Entered value exceeds the allowed length SWIFT of 11 characters.'");
			Message.Message();
			
			StandardProcessing = False;
			
			Return;
			
		EndIf;
		
	#EndIf
	
	ListOfFoundBanks = FindBanks(TrimAll(Text), Item.Name, Object.CashCurrency <> FunctionalCurrency);
	If TypeOf(ListOfFoundBanks) = Type("ValueList") Then
		
		If ListOfFoundBanks.Count() = 1 Then
		
			NotifyChanged(Type("CatalogRef.Banks"));
			
			Object.AccountsBank = ListOfFoundBanks[0].Value;
			FillSWIFT(Object.AccountsBank,  SWIFTBankForSettlements);
			
		ElsIf ListOfFoundBanks.Count() > 1 Then
			
			NotifyChanged(Type("CatalogRef.Banks"));
			
			OpenBankChoiceForm(False, ListOfFoundBanks);
			
		Else
			
			OpenBankChoiceForm(False);
			
		EndIf;
		
	Else
		
		CurrentItem = Item;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure SWIFTBankForSettlementsChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	StandardProcessing = False;
	
	FillSWIFT(ValueSelected, SWIFTBankForSettlements);
	Object.AccountsBank = ValueSelected;
	
	If IsBlankString(SWIFTBankForSettlements) Then
		
		CurrentItem = Items.SWIFTBankForSettlements;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure BankForSettlementsIsUsedOnChange(Item)
	
	Items.SWIFTBankForSettlements.Visible		= BankForSettlementsIsUsed;
	Items.BankForSettlements.Visible			= BankForSettlementsIsUsed;
	Items.BankForSettlementsCity.Visible		= BankForSettlementsIsUsed;
	
EndProcedure

&AtClient
Procedure EditPayerTextOnChange(Item)
	
	Items.PayerText.Enabled = EditCorrespondentText;
	
	If Not EditCorrespondentText Then
		FillCorrespondentText();
	EndIf;
	
EndProcedure

&AtClient
Procedure EditPayeeTextOnChange(Item)
	
	Items.PayeeText.Enabled = EditCorrespondentText;
	
	If Not EditCorrespondentText Then
		FillCorrespondentText();
	EndIf;
	
EndProcedure

&AtClient
Procedure AccountNoOnChange(Item)
	
	FillDescription();
	FillInAccountViewList();
	
EndProcedure

&AtClient
Procedure IBANOnChange(Item)
	
	Object.Description = GetAccountDescription(Object.IBAN);
	FillInAccountViewList();
	
EndProcedure

&AtClient
Procedure CashAssetsCurrencyOnChange(Item)
	
	FillInAccountViewList();
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure FillDescription()
	
	AccountNo = ?(IsBlankString(Object.AccountNo), Object.IBAN, Object.AccountNo);
	
	Object.Description = GetAccountDescription(AccountNo);
	
EndProcedure

// The procedure fills in the SWIFT field value.
//
&AtServerNoContext
Procedure FillSWIFT(Bank, SWIFT)
	
	If Not ValueIsFilled(Bank) Then
		
		Return;
		
	EndIf;
	
	SWIFT	= Bank.Code;
	
EndProcedure

// The procedure fills in the CorrespondentText field value.
//
&AtServer
Procedure FillCorrespondentText()
	
	Query = New Query;
	Query.SetParameter("Ref", Object.Owner);
		
	If TypeOf(Object.Owner) = Type("CatalogRef.Companies") Then
		
		Query.Text =
		"SELECT
		|	Companies.DescriptionFull
		|FROM
		|	Catalog.Companies AS Companies
		|WHERE
		|	Companies.Ref = &Ref";
		
	Else
		
		Query.Text =
		"SELECT
		|	Counterparties.DescriptionFull
		|FROM
		|	Catalog.Counterparties AS Counterparties
		|WHERE
		|	Counterparties.Ref = &Ref";
		
	EndIf;
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	If Selection.Next() Then
		CorrespondentText = TrimAll(Selection.DescriptionFull);
	EndIf;
	
EndProcedure

// The procedure opens a form with a list of banks for manual selection.
//
&AtClient
Procedure OpenBankChoiceForm(IsBank, ListOfFoundBanks = Undefined)
	
	FormParameters = New Structure;
	FormParameters.Insert("CurrentRow", ?(IsBank, Object.Bank, Object.AccountsBank));
	FormParameters.Insert("ChoiceFoldersAndItemsParameter", FoldersAndItemsUse.Items);
	FormParameters.Insert("CloseOnChoice", True);
	FormParameters.Insert("Multiselect", False);
	
	If ListOfFoundBanks <> Undefined Then
		
		FormParameters.Insert("ListOfFoundBanks", ListOfFoundBanks);
		
	EndIf;
	
	OpenForm("Catalog.Banks.ChoiceForm", FormParameters, ?(IsBank, Items.SWIFTBank, Items.SWIFTBankForSettlements));
	
EndProcedure

&AtServerNoContext
Function GetListOfBanksByAttributes(Val Field, Val Value) Export

	BankList = New ValueList;
	
	If IsBlankString(Value) Then
	
		Return BankList;
		
	EndIf;
	
	BanksTable = Catalogs.Banks.GetBanksTableByAttributes(Field, Value);
	
	BankList.LoadValues(BanksTable.UnloadColumn("Ref"));
	
	Return BankList;
	
EndFunction

&AtClientAtServerNoContext
Function CheckCorrectnessOfSWIFT(SWIFT, ErrorText = "")
	
	If IsBlankString(SWIFT) Then
		
		Return True;
		
	EndIf;
	
	ErrorText = "";
	If StrLen(SWIFT) <> 8 AND StrLen(SWIFT) <> 11 Then
		
		ErrorText = NStr("en = 'Bank is not found by the specified SWIFT. SWIFT might be specified incompletely.'");
		
	EndIf;
	
	Return IsBlankString(ErrorText);
	
EndFunction

// The function returns a list of banks that satisfy the search condition
// 
// IN case of failure returns "Undefined" or empty value list.
//
&AtClient
Function FindBanks(TextForSearch, Field, Currency = False)
	
	Var ErrorText;
	
	IsBank = (Field = "SWIFTBank");
	ClearValuesInAssociatedFieldsInForms(IsBank);
	
	If IsBlankString(TextForSearch) Then
		
		ClearMessages();
		
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'The ""%1"" field value is incorrect.'"), 
			"SWIFT"
			);
		
		CommonUseClientServer.MessageToUser(MessageText,, Field);
		
		Return Undefined;
		
	EndIf;
	
	If Find(Field, "SWIFT") = 1 Then
		
		SearchArea = "Code";
		
	Else
		
		Return Undefined;
		
	EndIf;
	
	ListOfFoundBanks = GetListOfBanksByAttributes(SearchArea, TextForSearch);
	If ListOfFoundBanks.Count() = 0 Then
		
		If SearchArea = "Code" Then
			
			If Not CheckCorrectnessOfSWIFT(TextForSearch, ErrorText) Then
				
				ClearMessages();
				CommonUseClientServer.MessageToUser(ErrorText,, Field);
				Return Undefined;
				
			EndIf;
			
			QuestionText = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Bank with SWIFT ""%1"" was not found in the Banks catalog'"), TextForSearch);
			
		EndIf;
		
		// Generate variants
		Buttons	= New ValueList;
		Buttons.Add("Select",     NStr("en = 'Select from the catalog'"));
		Buttons.Add("Cancel",   NStr("en = 'Cancel entering'"));
		
		// Choice processor
		NotifyDescription = New NotifyDescription("DetermineIfBankIsToBeSelectedFromCatalog", ThisObject, New Structure("IsBank", IsBank));
		ShowQueryBox(NotifyDescription, QuestionText, Buttons,, "Select", NStr("en = 'Bank is not found'"));
		Return Undefined;
		
	EndIf;
	
	Return ListOfFoundBanks;
	
EndFunction

// Procedure for managing form controls.
//
&AtServer
Procedure FormItemsManagement()
	
	// Set using the correspondent bank.
	BankForSettlementsIsUsed = ValueIsFilled(Object.AccountsBank);
	
	Items.SWIFTBankForSettlements.Visible		= BankForSettlementsIsUsed;
	Items.BankForSettlements.Visible			= BankForSettlementsIsUsed;
	Items.BankForSettlementsCity .Visible		= BankForSettlementsIsUsed;
	
	Items.Owner.ReadOnly = NOT Object.Ref.IsEmpty() OR ValueIsFilled(Object.Owner);
	
	// Edit company name.
	EditCorrespondentText = ValueIsFilled(Object.CorrespondentText);
	Items.PayerText.Enabled = EditCorrespondentText;
	Items.PayeeText.Enabled = EditCorrespondentText;
	
	If EditCorrespondentText Then
		CorrespondentText = Object.CorrespondentText;
	Else
		FillCorrespondentText();
	EndIf;
	
	// Print settings
	Items.GroupCompanyAccountAttributes.Visible			= (TypeOf(Object.Owner) = Type("CatalogRef.Companies"));
	Items.GroupCounterpartyAccountAttributes.Visible	= Not (TypeOf(Object.Owner) = Type("CatalogRef.Companies"));
	
EndProcedure

// Function generates a bank account description.
//
&AtClient
Procedure FillInAccountViewList()
	
	Items.Description.ChoiceList.Clear();
	
	If NOT IsBlankString(Object.AccountNo) Then
		Items.Description.ChoiceList.Add(GetAccountDescription(Object.AccountNo));
	EndIf;
	
	If NOT IsBlankString(Object.IBAN) Then
		Items.Description.ChoiceList.Add(GetAccountDescription(Object.IBAN));
	EndIf;
	
	DescriptionString = ?(ValueIsFilled(Object.Bank), String(Object.Bank), "") + " (" + String(Object.CashCurrency) + ")";
	DescriptionString = Left(DescriptionString, 100);
	
	Items.Description.ChoiceList.Add(DescriptionString);
	
EndProcedure

&AtClient
Function GetAccountDescription(AccountNo)
	
	Text = AccountNo;
	
	If ValueIsFilled(Object.Bank) Then
		Text = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = '%1, in %2'"),
				TrimAll(AccountNo),
				String(Object.Bank));
	EndIf;
			
	Return Left(Text, 100);
	
EndFunction

// The procedure clears the related fields of the form
//
// It is useful if a user opens a selection form and refuses to select a value.
//
&AtClient
Procedure ClearValuesInAssociatedFieldsInForms(IsBank)
	
	If IsBank Then
		
		Object.Bank = Undefined;
		SWIFTBank = "";
		
	Else
		
		Object.AccountsBank = Undefined;
		SWIFTBankForSettlements = "";
		
	EndIf;
	
EndProcedure

// Fills in the bank details and direct exchange settings.
//
&AtServerNoContext
Procedure FillBankDetails(SWIFTBank, Val Bank, Val AccountOwner)

	FillSWIFT(Bank, SWIFTBank);

EndProcedure

#EndRegion

#Region InteractiveActionResultHandlers

&AtClient
// Procedure-handler of the prompt result about selecting the bank from classifier
//
//
Procedure DetermineIfBankIsToBeSelectedFromCatalog(ClosingResult, AdditionalParameters) Export
	
	If ClosingResult = "Select" Then
		
		OpenBankChoiceForm(AdditionalParameters.IsBank);
		
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
