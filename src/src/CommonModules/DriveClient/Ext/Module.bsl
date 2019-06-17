#Region ExportProceduresAndFunctions

// Displays a message on filling error.
//
Procedure ShowMessageAboutError(ErrorObject, MessageText, TabularSectionName = Undefined, LineNumber = Undefined, Field = Undefined, Cancel = False) Export
	
	Message = New UserMessage();
	Message.Text = MessageText;
	
	If TabularSectionName <> Undefined Then
		Message.Field = TabularSectionName + "[" + (LineNumber - 1) + "]." + Field;
	ElsIf ValueIsFilled(Field) Then
		Message.Field = Field;
	EndIf;
	
	If ErrorObject <> Undefined Then
		Message.SetData(ErrorObject);
	EndIf;
	
	Message.Message();
	
	Cancel = True;
	
EndProcedure

// Function checks whether it is possible to print receipt on fiscal data recorder.
//
// Parameters:
// Form - ManagedForm - Document form
//
// Returns:
// Boolean - Shows that printing is possible
//
Function CheckPossibilityOfReceiptPrinting(Form, ShowMessageBox = False) Export
	
	CheckPrint = True;
	
	// If object is not posted or modified - execute posting.
	If Not Form.Object.Posted
		OR Form.Modified Then
		
		Try
			If Not Form.Write(New Structure("WriteMode", DocumentWriteMode.Posting)) Then
				CheckPrint = False;
			EndIf;
		Except
			ShowMessageBox = True;
			CheckPrint = False;
		EndTry;
			
	EndIf;
	
	Return CheckPrint;

EndFunction

#EndRegion

#Region GeneralPurposeProceduresAndFunctions

// Function recalculates the amount from one currency to another
//
// Parameters:      
//  Amount        - Number - the amount to be converted.
// 	InitRate      - Number - the source currency exchange rate.
// 	FinRate       - Number - the target currency exchange rate.
// 	RepetitionBeg - Number - the exchange rate multiplier of the source currency.
//                           The default value is 1. 
// 	RepetitionEnd - Number - the exchange rate multiplier of the target currency.
//                           The default value is 1. 
//
// Returns: 
//  Number - amount recalculated to another currency.
//
Function RecalculateFromCurrencyToCurrency(Amount, InitRate, FinRate, RepetitionBeg = 1, RepetitionEnd = 1) Export
	
	If InitRate = FinRate AND RepetitionBeg = RepetitionEnd Then
		Return Amount;
	EndIf;
	
	If InitRate = 0
		OR FinRate = 0
		OR RepetitionBeg = 0
		OR RepetitionEnd = 0 Then
		CommonUseClientServer.MessageToUser(
			NStr("en = 'Null exchange rate has been found. Recalculation isn''t executed.'"));
		Return Amount;
	EndIf;
	
	RecalculatedSumm = Round((Amount * InitRate * RepetitionEnd) / (FinRate * RepetitionBeg), 2);
	
	Return RecalculatedSumm;
	
EndFunction

// Procedure updates document state.
//
Procedure RefreshDocumentStatus(Object, DocumentStatus, PictureDocumentStatus, PostingIsAllowed) Export
	
	If Object.Posted Then
		DocumentStatus = "Posted";
		PictureDocumentStatus = 1;
	ElsIf PostingIsAllowed Then
		DocumentStatus = "Not posted";
		PictureDocumentStatus = 0;
	Else
		DocumentStatus = "Recorded";
		PictureDocumentStatus = 3;
	EndIf;
	
EndProcedure

// Function returns weekday presentation.
//
Function GetPresentationOfWeekDay(CalendarWeekDay) Export
	
	WeekDayNumber = WeekDay(CalendarWeekDay);
	If WeekDayNumber = 1 Then
		
		Return NStr("en = 'Mon'");
		
	ElsIf WeekDayNumber = 2 Then
		
		Return NStr("en = 'Tue'");
		
	ElsIf WeekDayNumber = 3 Then
		
		Return NStr("en = 'Wed'");
		
	ElsIf WeekDayNumber = 4 Then
		
		Return NStr("en = 'Thu'");
		
	ElsIf WeekDayNumber = 5 Then
		
		Return NStr("en = 'Fri'");
		
	ElsIf WeekDayNumber = 6 Then
		
		Return NStr("en = 'Sa'");
		
	Else
		
		Return NStr("en = 'Sun'");
		
	EndIf;
	
EndFunction

// Fills in data structure for opening calendar selection form
//
Function GetCalendarGenerateFormOpeningParameters(CalendarDateOnOpen, 
		CloseOnChoice = True, 
		Multiselect = False) Export
	
	ParametersStructure = New Structure;
	
	ParametersStructure.Insert(
		"CalendarDate", 
			CalendarDateOnOpen
		);
		
	ParametersStructure.Insert(
		"CloseOnChoice", 
			CloseOnChoice
		);
		
	ParametersStructure.Insert(
		"Multiselect", 
			Multiselect
		);
		
	Return ParametersStructure;
	
EndFunction

// Places passed value to ValuesList
// 
Function ValueToValuesListAtClient(Value, ValueList = Undefined, AddDuplicates = False) Export
	
	If TypeOf(ValueList) = Type("ValueList") Then
		
		If AddDuplicates Then
			
			ValueList.Add(Value);
			
		ElsIf ValueList.FindByValue(Value) = Undefined Then
			
			ValueList.Add(Value);
			
		EndIf;
		
	Else
		
		ValueList = New ValueList;
		ValueList.Add(Value);
		
	EndIf;
	
	Return ValueList;
	
EndFunction

// Fills in the values list Receiver from the values list Source
//
Procedure FillListByList(Source,Receiver) Export

	Receiver.Clear();
	For Each ListIt In Source Do
		Receiver.Add(ListIt.Value, ListIt.Presentation);
	EndDo;

EndProcedure

Function CheckGetSelectedRefsInList(List) Export
	
	RefsArray = New Array;
	
	For Count = 0 To List.SelectedRows.Count() - 1 Do
		If TypeOf(List.SelectedRows[Count]) <> Type("DynamicalListGroupRow") Then
			RefsArray.Add(List.SelectedRows[Count]);
		EndIf;
	EndDo;
	
	If RefsArray.Count() = 0 Then
		ShowMessageBox(, NStr("en = 'The command cannot be executed for the specified object'"));
	EndIf;
	
	Return RefsArray;
	
EndFunction


#EndRegion

#Region ProceduresForWorkWithSubordinateTabularSections

// Procedure adds connection key to tabular section.
//
// Parameters:
//  DocumentForm - ManagedForm, contains a
//                 document form attributes of which are processed by the procedure
//
Procedure AddConnectionKeyToTabularSectionLine(DocumentForm) Export

	TabularSectionRow = DocumentForm.Items[DocumentForm.TabularSectionName].CurrentData;
	
	If TabularSectionRow = Undefined Then
		Return;
	EndIf;
	
	TabularSectionRow.ConnectionKey = CreateNewLinkKey(DocumentForm);		
        
EndProcedure

// Procedure adds connection key to the subordinate tabular section.
//
// Parameters:
//  DocumentForm - ManagedForm contains a
//                 document form attributes
// of which are processed by the SubordinateTabularSectionName procedure - String that contains the
//                 subordinate tabular section name.
//
Procedure AddConnectionKeyToSubordinateTabularSectionLine(DocumentForm, SubordinateTabularSectionName) Export
	
	SubordinateTbularSection = DocumentForm.Items[SubordinateTabularSectionName];
	
	StringSubordinateTabularSection = SubordinateTbularSection.CurrentData;
	
	If StringSubordinateTabularSection = Undefined Then
		Return;
	EndIf;
	
	StringSubordinateTabularSection.ConnectionKey = SubordinateTbularSection.RowFilter["ConnectionKey"];
	
	FilterStr = New FixedStructure("ConnectionKey", SubordinateTbularSection.RowFilter["ConnectionKey"]);
	DocumentForm.Items[SubordinateTabularSectionName].RowFilter = FilterStr;

EndProcedure

// Procedure prohibits to add new row if row in the main tabular section is not selected.
//
// Parameters:
//  DocumentForm - ManagedForm contains a
//                 document form attributes
// of which are processed by the SubordinateTabularSectionName procedure - String that contains the
//                 subordinate tabular section name.
//
Function BeforeAddToSubordinateTabularSection(DocumentForm, SubordinateTabularSectionName) Export

	If DocumentForm.Items[DocumentForm.TabularSectionName].CurrentData = Undefined Then
		Message = New UserMessage;
		Message.Text = NStr("en = 'Row of the main tabular section is not selected.'");
		Message.Message();
		Return True;
	Else
		Return False;
	EndIf;
		
EndFunction

// Procedure deletes rows from the subordinate tabular section.
//
// Parameters:
//  DocumentForm - ManagedForm contains a
//                 document form attributes
// of which are processed by the SubordinateTabularSectionName procedure - String that contains the
//                 subordinate tabular section name.
//
Procedure DeleteRowsOfSubordinateTabularSection(DocumentForm, SubordinateTabularSectionName) Export

	TabularSectionRow = DocumentForm.Items[DocumentForm.TabularSectionName].CurrentData;
	SubordinateTbularSection = DocumentForm.Object[SubordinateTabularSectionName];
   	
    SearchResult = SubordinateTbularSection.FindRows(New Structure("ConnectionKey", TabularSectionRow.ConnectionKey));
	For Each SearchString In  SearchResult Do
		IndexOfDeletion = SubordinateTbularSection.IndexOf(SearchString);
		SubordinateTbularSection.Delete(IndexOfDeletion);
	EndDo;
	
EndProcedure

// Procedure creates a new key of links for tables.
//
// Parameters:
//  DocumentForm - ManagedForm, contains a
//                 document form whose attributes are processed by the procedure.
//
Function CreateNewLinkKey(DocumentForm) Export

	ValueList = New ValueList;
	
	TabularSection = DocumentForm.Object[DocumentForm.TabularSectionName];
	For Each TSRow In TabularSection Do
        ValueList.Add(TSRow.ConnectionKey);
	EndDo;

    If ValueList.Count() = 0 Then
		ConnectionKey = 1;
	Else
		ValueList.SortByValue();
		ConnectionKey = ValueList.Get(ValueList.Count() - 1).Value + 1;
	EndIf;

	Return ConnectionKey;

EndFunction

// Procedure sets the filter on a subordinate tabular section.
//
Procedure SetFilterOnSubordinateTabularSection(DocumentForm, SubordinateTabularSectionName) Export
	
	TabularSectionRow = DocumentForm.Items[DocumentForm.TabularSectionName].CurrentData;
	If TabularSectionRow = Undefined Then
		Return;
	EndIf; 
	
	FilterStr = New FixedStructure("ConnectionKey", DocumentForm.Items[DocumentForm.TabularSectionName].CurrentData.ConnectionKey);
	DocumentForm.Items[SubordinateTabularSectionName].RowFilter = FilterStr;
	
EndProcedure

#EndRegion

#Region ProceduresAndFunctionsOfListFormAndCounterpartiesCatalogSelection

// Function checks whether positioning on the row activation is correct.
//
Function PositioningIsCorrect(Form) Export
	
	TypeGroup = Type("DynamicalListGroupRow");
		
	If TypeOf(Form.Items.List.CurrentRow) <> TypeGroup AND ValueIsFilled(Form.Items.List.CurrentRow) Then
		Return True;
	EndIf;
	
	Return False;
	
EndFunction

// Fills in the footer label: Selection basis of the Counterparties catalog.
//
Procedure FillBasisRow(Form) Export
	
	Basis = Form.Bases.FindRows(New Structure("Counterparty", Form.Items.List.CurrentRow));
	If Basis.Count() = 0 Then
		Form.ChoiceBasis = "";
	Else
		Form.ChoiceBasis = Basis[0].Basis;
	EndIf;
	
EndProcedure

// Procedure restores list display after a fulltext search.
//
Procedure RecoverListDisplayingAfterFulltextSearch(Form) Export
	
	If String(Form.Items.List.Representation) <> Form.ViewModeBeforeFulltextSearchApplying Then
		If Form.ViewModeBeforeFulltextSearchApplying = "Hierarchical list" Then
			Form.Items.List.Representation = TableRepresentation.HierarchicalList;
		ElsIf Form.ViewModeBeforeFulltextSearchApplying = "Tree" Then
			Form.Items.List.Representation = TableRepresentation.Tree;
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region ListFormsProceduresInformationPanel

// Processes a row activation event of the document list.
//
Procedure InfoPanelProcessListRowActivation(Form, InfPanelParameters) Export
	
	CurrentDataOfList = Form.Items.List.CurrentData;
	
	If CurrentDataOfList <> Undefined
		AND CurrentDataOfList.Property(InfPanelParameters.CIAttribute) Then
		
		CICurrentAttribute = CurrentDataOfList[InfPanelParameters.CIAttribute];
		
		If Form.ReferenceInformation <> CICurrentAttribute Then
			
			If ValueIsFilled(CICurrentAttribute) Then
				
				IPData = DriveServer.InfoPanelGetData(CICurrentAttribute, InfPanelParameters);
				InfoPanelFill(Form, InfPanelParameters, IPData);
				
				Form.ReferenceInformation = CICurrentAttribute;
				
			Else
				
				InfoPanelFill(Form, InfPanelParameters);
				
			EndIf;
			
		EndIf;
		
	Else
		
		InfoPanelFill(Form, InfPanelParameters);
		
	EndIf;
	
EndProcedure

// Procedure fills in data of the list info panel.
//
Procedure InfoPanelFill(Form, InfPanelParameters, IPData = Undefined)
	
	If IPData = Undefined Then
	
		Form.ReferenceInformation = Undefined;
		
		// Counterparties contact information.
		If InfPanelParameters.Property("Counterparty") Then
			
			Form.CounterpartyPhoneInformation = "";
			Form.CounterpartyInformationES = "";
			Form.CounterpartyFaxInformation = "";
			
			Form.CounterpartyFactAddressInformation = "";
			If Form.Items.Find("InformationCounterpartyShippingAddress") <> Undefined
				OR Form.Items.Find("DetailsListCounterpartyShippingAddress") <> Undefined Then
				
				Form.InformationCounterpartyShippingAddress = "";
				
			EndIf;
			Form.CounterpartyLegalAddressInformation = "";
			
			Form.InformationCounterpartyPostalAddress = "";
			Form.InformationCounterpartyAnotherInformation = "";
			
			// StatementOfAccount.
			If InfPanelParameters.Property("StatementOfAccount") Then
				
				Form.CounterpartyDebtInformation = 0;
				Form.OurDebtInformation = 0;
				
			EndIf;
			
		EndIf;
		
		// Contacts contact information.
		If InfPanelParameters.Property("ContactPerson") Then
			
			Form.InformationContactPhone = "";
			Form.ContactPersonESInformation = "";
			
		EndIf;
		
	Else
		
		// Counterparties contact information.
		If InfPanelParameters.Property("Counterparty") Then
			
			Form.CounterpartyPhoneInformation 	= IPData.Phone;
			Form.CounterpartyInformationES 		= IPData.E_mail;
			Form.CounterpartyFaxInformation 		= IPData.Fax;
			
			Form.CounterpartyFactAddressInformation = IPData.RealAddress;
			If Form.Items.Find("InformationCounterpartyShippingAddress") <> Undefined
				OR Form.Items.Find("DetailsListCounterpartyShippingAddress") <> Undefined Then
				
				Form.InformationCounterpartyShippingAddress = IPData.ShippingAddress;
				
			EndIf;
			Form.CounterpartyLegalAddressInformation 	= IPData.LegAddress;
			
			Form.InformationCounterpartyPostalAddress 	= IPData.MailAddress;
			Form.InformationCounterpartyAnotherInformation 	= IPData.OtherInformation;
			
			// StatementOfAccount.
			If InfPanelParameters.Property("StatementOfAccount") Then
				
				Form.CounterpartyDebtInformation = IPData.Debt;
				Form.OurDebtInformation 		= IPData.OurDebt;
				
			EndIf;
			
		EndIf;
		
		// Contacts contact information.
		If InfPanelParameters.Property("ContactPerson") Then
			
			Form.InformationContactPhone 	= IPData.CLPhone;
			Form.ContactPersonESInformation 		= IPData.ClEmail;
			
		EndIf;
		
	EndIf;
	
EndProcedure

#Region DiscountCards

// Processes a row activation event of the document list.
//
Procedure DiscountCardsInformationPanelHandleListRowActivation(Form, InfPanelParameters) Export
	
	CurrentDataOfList = Form.Items.List.CurrentData;
	
	If CurrentDataOfList <> Undefined
		AND CurrentDataOfList.Property(InfPanelParameters.CIAttribute) Then
		
		CICurrentAttribute = CurrentDataOfList[InfPanelParameters.CIAttribute];
		
		If Form.ReferenceInformation <> InfPanelParameters.DiscountCard Then
			
			If ValueIsFilled(InfPanelParameters.DiscountCard) Then
				
				IPData = DriveServer.InfoPanelGetData(CICurrentAttribute, InfPanelParameters);
				DiscountCardsInfoPanelFill(Form, InfPanelParameters, IPData);
				
				Form.ReferenceInformation = CICurrentAttribute;
				
			Else
				
				DiscountCardsInfoPanelFill(Form, InfPanelParameters);
				
			EndIf;
			
		EndIf;
		
	Else
		
		DiscountCardsInfoPanelFill(Form, InfPanelParameters);
		
	EndIf;
	
EndProcedure

// Procedure fills in data of the list info panel.
//
Procedure DiscountCardsInfoPanelFill(Form, InfPanelParameters, IPData = Undefined)
	
	If IPData = Undefined Then
	
		Form.ReferenceInformation = Undefined;
		
		// Counterparties contact information.
		If InfPanelParameters.Property("Counterparty") Then
			
			Form.CounterpartyPhoneInformation = "";
			Form.CounterpartyInformationES = "";
			Form.InformationDiscountPercentOnDiscountCard = "";
			Form.InformationSalesAmountOnDiscountCard = "";
			
		EndIf;
		
	Else
		
		// Counterparties contact information.
		If InfPanelParameters.Property("Counterparty") Then
			
			Form.CounterpartyPhoneInformation 				= IPData.Phone;
			Form.CounterpartyInformationES 					= IPData.E_mail;
			Form.InformationDiscountPercentOnDiscountCard 	= IPData.DiscountPercentByDiscountCard;
			Form.InformationSalesAmountOnDiscountCard	= IPData.SalesAmountOnDiscountCard;
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#EndRegion

#Region SsmSubsystemsProceduresAndFunctions

// Procedure inputs default expenses invoice while selecting
// Earnings in the document tabular section.
//
// Parameters:
//  DocumentForm - ManagedForm, contains a
//                 document form whose attributes are processed by the procedure.
//
Procedure PutExpensesGLAccountByDefault(DocumentForm, StructuralUnit = Undefined) Export
	
	DataCurrentRows = DocumentForm.Items.EarningsDeductions.CurrentData;
	
	ParametersStructure = New Structure("GLExpenseAccount, TypeOfAccount");
	ParametersStructure.Insert("EarningAndDeductionType", DataCurrentRows.EarningAndDeductionType);
	ParametersStructure.Insert("StructuralUnit", StructuralUnit);
	
	If ValueIsFilled(DataCurrentRows.EarningAndDeductionType) Then
		
		DriveServer.GetEarningKindGLExpenseAccount(ParametersStructure);
		DataCurrentRows.GLExpenseAccount = ParametersStructure.GLExpenseAccount;
		
	EndIf;
	
	If DataCurrentRows.Property("TypeOfAccount") Then
		
		DataCurrentRows.TypeOfAccount = ParametersStructure.TypeOfAccount;
		
	EndIf;
	
EndProcedure

// Procedure sets the registration period to of the beginning of month.
// It also updates period label on form
Procedure OnChangeRegistrationPeriod(SentForm) Export
	
	If Find(SentForm.FormName, "DocumentJournal") > 0 
		OR Find(SentForm.FormName, "ReportForm") Then
		SentForm.RegistrationPeriod 				= BegOfMonth(SentForm.RegistrationPeriod);
		SentForm.RegistrationPeriodPresentation 	= Format(SentForm.RegistrationPeriod, "DF='MMMM yyyy'");
	ElsIf Find(SentForm.FormName, "ListForm") > 0 Then
		SentForm.FilterRegistrationPeriod 			= BegOfMonth(SentForm.FilterRegistrationPeriod);
		SentForm.RegistrationPeriodPresentation 	= Format(SentForm.FilterRegistrationPeriod, "DF='MMMM yyyy'");
	Else
		SentForm.Object.RegistrationPeriod 		= BegOfMonth(SentForm.Object.RegistrationPeriod);
		SentForm.RegistrationPeriodPresentation 	= Format(SentForm.Object.RegistrationPeriod, "DF='MMMM yyyy'");
	EndIf;
	
EndProcedure

// Procedure executes date increment by
// regulatory buttons Used in log and salary documents and wages Expense CA from
// petty cash, reports Payroll sheets Step equals to month
//
// Parameters:
// SentForm 	- form data of
// which is corrected Direction 		- increment value can be positive or negative
Procedure OnRegistrationPeriodRegulation(SentForm, Direction) Export
	
	If Find(SentForm.FormName, "DocumentJournal") > 0 
		OR Find(SentForm.FormName, "ReportForm") Then
		
		SentForm.RegistrationPeriod = ?(ValueIsFilled(SentForm.RegistrationPeriod), 
							AddMonth(SentForm.RegistrationPeriod, Direction),
							AddMonth(BegOfMonth(CurrentDate()), Direction));
		
	ElsIf Find(SentForm.FormName, "ListForm") > 0 Then
		
		SentForm.FilterRegistrationPeriod = ?(ValueIsFilled(SentForm.FilterRegistrationPeriod), 
							AddMonth(SentForm.FilterRegistrationPeriod, Direction),
							AddMonth(BegOfMonth(CurrentDate()), Direction));
		
	Else
		
		SentForm.Object.RegistrationPeriod = ?(ValueIsFilled(SentForm.Object.RegistrationPeriod), 
							AddMonth(SentForm.Object.RegistrationPeriod, Direction),
							AddMonth(BegOfMonth(CurrentDate()), Direction));
		
	EndIf;
	
EndProcedure

#EndRegion

#Region PricingSubsystemProceduresAndFunctions

// Procedure calculates the amount of the tabular section while filling by "Prices and currency".
//
Procedure CalculateTabularSectionRowSUM(DocumentForm, TabularSectionRow)
	
	If TabularSectionRow.Property("Quantity") AND TabularSectionRow.Property("Price") Then
		TabularSectionRow.Amount = TabularSectionRow.Quantity * TabularSectionRow.Price;
	EndIf;
	
	If TabularSectionRow.Property("StandardHours") Then
		TabularSectionRow.Amount = TabularSectionRow.Amount * TabularSectionRow.StandardHours;
	EndIf;
	
	If TabularSectionRow.Property("DiscountMarkupPercent") Then
		If TabularSectionRow.DiscountMarkupPercent = 100 Then
			TabularSectionRow.Amount = 0;
		ElsIf TabularSectionRow.DiscountMarkupPercent <> 0 AND TabularSectionRow.Quantity <> 0 Then
			TabularSectionRow.Amount = TabularSectionRow.Amount * (1 - TabularSectionRow.DiscountMarkupPercent / 100);
		EndIf;
	EndIf;	

	VATRate = DriveReUse.GetVATRateValue(TabularSectionRow.VATRate);
			
	If DocumentForm.Object.Property("AmountIncludesVAT") Then
		TabularSectionRow.VATAmount = ?(
			DocumentForm.Object.AmountIncludesVAT, 
			TabularSectionRow.Amount - (TabularSectionRow.Amount) / ((VATRate + 100) / 100),
			TabularSectionRow.Amount * VATRate / 100
		);
		TabularSectionRow.Total = TabularSectionRow.Amount + ?(DocumentForm.Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	Else
		TabularSectionRow.VATAmount = TabularSectionRow.Amount * VATRate / 100;
		TabularSectionRow.Total = TabularSectionRow.Amount + TabularSectionRow.VATAmount;
	EndIf;	
	
	// AutomaticDiscounts
	If TabularSectionRow.Property("AutomaticDiscountsPercent") Then
		TabularSectionRow.AutomaticDiscountsPercent = 0;
		TabularSectionRow.AutomaticDiscountAmount = 0;
	EndIf;
	If TabularSectionRow.Property("TotalDiscountAmountIsMoreThanAmount") Then
		TabularSectionRow.TotalDiscountAmountIsMoreThanAmount = False;
	EndIf;
	// End AutomaticDiscounts
	
EndProcedure

// Recalculate prices by the AmountIncludesVAT check box of the tabular section after changes in form "Prices and currency".
//
// Parameters:
//  PreviousCurrency - CatalogRef.Currencies,
//                 contains reference to the previous currency.
//
Procedure RecalculateTabularSectionAmountByFlagAmountIncludesVAT(DocumentForm, TabularSectionName) Export
																	   
	For Each TabularSectionRow In DocumentForm.Object[TabularSectionName] Do
		
		VATRate = DriveReUse.GetVATRateValue(TabularSectionRow.VATRate);
		
		If TabularSectionRow.Property("Price") Then
			
			If DocumentForm.Object.AmountIncludesVAT Then
				TabularSectionRow.Price = (TabularSectionRow.Price * (100 + VATRate)) / 100;
			Else
				TabularSectionRow.Price = (TabularSectionRow.Price * 100) / (100 + VATRate);
			EndIf;
			
			CalculateTabularSectionRowSUM(DocumentForm, TabularSectionRow);
		EndIf;
		        
	EndDo;

EndProcedure

// Recalculate the price of the tabular section of the document after making changes in the "Prices and currency" form.
// 
Procedure RefillTabularSectionPricesByPriceKind(DocumentForm, TabularSectionName, RecalculateDiscounts = False) Export
	
	DataStructure = New Structure;
	DocumentTabularSection = New Array;

	DataStructure.Insert("Date",				DocumentForm.Object.Date);
	DataStructure.Insert("Company",				DocumentForm.ParentCompany);
	DataStructure.Insert("PriceKind",			DocumentForm.Object.PriceKind);
	DataStructure.Insert("DocumentCurrency",	DocumentForm.Object.DocumentCurrency);
	DataStructure.Insert("AmountIncludesVAT",	DocumentForm.Object.AmountIncludesVAT);
	
	If RecalculateDiscounts Then
		DataStructure.Insert("DiscountMarkupKind", DocumentForm.Object.DiscountMarkupKind);
		DataStructure.Insert("DiscountMarkupPercent", 0);
		If DriveServer.DocumentAttributeExistsOnLink("DiscountPercentByDiscountCard", DocumentForm.Object.Ref) Then
			DataStructure.Insert("DiscountPercentByDiscountCard", DocumentForm.Object.DiscountPercentByDiscountCard);		
		EndIf;
	EndIf;
	
	For Each TSRow In DocumentForm.Object[TabularSectionName] Do
		
		TSRow.Price = 0;
		
		If Not ValueIsFilled(TSRow.Products) Then
			Continue;	
		EndIf; 
		
		TabularSectionRow = New Structure();
		TabularSectionRow.Insert("Products",		TSRow.Products);
		TabularSectionRow.Insert("Characteristic",		TSRow.Characteristic);
		TabularSectionRow.Insert("MeasurementUnit",	TSRow.MeasurementUnit);
		TabularSectionRow.Insert("VATRate",			TSRow.VATRate);
		TabularSectionRow.Insert("Price",				0);
		
		DocumentTabularSection.Add(TabularSectionRow);
		
	EndDo;
		
	DriveServer.GetTabularSectionPricesByPriceKind(DataStructure, DocumentTabularSection);
		
	For Each TSRow In DocumentTabularSection Do

		SearchStructure = New Structure;
		SearchStructure.Insert("Products",		TSRow.Products);
		SearchStructure.Insert("Characteristic",		TSRow.Characteristic);
		SearchStructure.Insert("MeasurementUnit",	TSRow.MeasurementUnit);
		SearchStructure.Insert("VATRate",			TSRow.VATRate);
		
		SearchResult = DocumentForm.Object[TabularSectionName].FindRows(SearchStructure);
		
		For Each ResultRow In SearchResult Do
			
			ResultRow.Price = TSRow.Price;
			CalculateTabularSectionRowSUM(DocumentForm, ResultRow);
			
		EndDo;
		
	EndDo;
	
	If RecalculateDiscounts Then
		For Each TabularSectionRow In DocumentForm.Object[TabularSectionName] Do
			TabularSectionRow.DiscountMarkupPercent = DataStructure.DiscountMarkupPercent;
			CalculateTabularSectionRowSUM(DocumentForm, TabularSectionRow);
		EndDo;
	EndIf;
	
EndProcedure

// Recalculate the price of the tabular section of the document after making changes in the "Prices and currency" form.
// 
Procedure RefillTabularSectionPricesBySupplierPriceTypes(DocumentForm, TabularSectionName) Export
	
	DataStructure = New Structure;
	DocumentTabularSection = New Array;

	DataStructure.Insert("Date",				DocumentForm.Object.Date);
	DataStructure.Insert("Company",			DocumentForm.Counterparty);
	DataStructure.Insert("SupplierPriceTypes",	DocumentForm.Object.SupplierPriceTypes);
	DataStructure.Insert("DocumentCurrency",		DocumentForm.Object.DocumentCurrency);
	DataStructure.Insert("AmountIncludesVAT",	DocumentForm.Object.AmountIncludesVAT);
	
	For Each TSRow In DocumentForm.Object[TabularSectionName] Do
		
		TSRow.Price = 0;
		
		If Not ValueIsFilled(TSRow.Products) Then
			Continue;	
		EndIf; 
		
		TabularSectionRow = New Structure();
		TabularSectionRow.Insert("Products",		TSRow.Products);
		TabularSectionRow.Insert("Characteristic",		TSRow.Characteristic);
		TabularSectionRow.Insert("MeasurementUnit",	TSRow.MeasurementUnit);
		TabularSectionRow.Insert("VATRate",			TSRow.VATRate);
		TabularSectionRow.Insert("Price",				0);
		
		DocumentTabularSection.Add(TabularSectionRow);
		
	EndDo;
		
	DriveServer.GetPricesTabularSectionBySupplierPriceTypes(DataStructure, DocumentTabularSection);
		
	For Each TSRow In DocumentTabularSection Do

		SearchStructure = New Structure;
		SearchStructure.Insert("Products",		TSRow.Products);
		SearchStructure.Insert("Characteristic",		TSRow.Characteristic);
		SearchStructure.Insert("MeasurementUnit",	TSRow.MeasurementUnit);
		SearchStructure.Insert("VATRate",			TSRow.VATRate);
		
		SearchResult = DocumentForm.Object[TabularSectionName].FindRows(SearchStructure);
		
		For Each ResultRow In SearchResult Do
			
			ResultRow.Price = TSRow.Price;
			CalculateTabularSectionRowSUM(DocumentForm, ResultRow);
			
		EndDo;
		
	EndDo;
	
EndProcedure

// Recalculate price by document tabular section currency after changes in the "Prices and currency" form.
//
// Parameters:
//  PreviousCurrency - CatalogRef.Currencies,
//                 contains reference to the previous currency.
//
Procedure RecalculateTabularSectionPricesByCurrency(DocumentForm, PreviousCurrency, TabularSectionName) Export
	
	RatesStructure = DriveServer.GetExchangeRates(PreviousCurrency, DocumentForm.Object.DocumentCurrency, DocumentForm.Object.Date);
																   
	For Each TabularSectionRow In DocumentForm.Object[TabularSectionName] Do
		
		// Price.
		If TabularSectionRow.Property("Price") Then
			
			TabularSectionRow.Price = RecalculateFromCurrencyToCurrency(TabularSectionRow.Price, 
																	RatesStructure.InitRate, 
																	RatesStructure.ExchangeRate, 
																	RatesStructure.RepetitionBeg, 
																	RatesStructure.Multiplicity);
																	
			CalculateTabularSectionRowSUM(DocumentForm, TabularSectionRow);
			
		// Amount.	
		ElsIf TabularSectionRow.Property("Amount") Then
			
			TabularSectionRow.Amount = RecalculateFromCurrencyToCurrency(TabularSectionRow.Amount, 
																	RatesStructure.InitRate, 
																	RatesStructure.ExchangeRate, 
																	RatesStructure.RepetitionBeg, 
																	RatesStructure.Multiplicity);														
					
			If TabularSectionRow.Property("DiscountMarkupPercent") Then
				
				// Discounts.
				If TabularSectionRow.DiscountMarkupPercent = 100 Then
					TabularSectionRow.Amount = 0;
				ElsIf TabularSectionRow.DiscountMarkupPercent <> 0 AND TabularSectionRow.Quantity <> 0 Then
					TabularSectionRow.Amount = TabularSectionRow.Amount * (1 - TabularSectionRow.DiscountMarkupPercent / 100);
				EndIf;
								
			EndIf;														
			
			VATRate = DriveReUse.GetVATRateValue(TabularSectionRow.VATRate);
			
	        TabularSectionRow.VATAmount = ?(DocumentForm.Object.AmountIncludesVAT, 
								  				TabularSectionRow.Amount - (TabularSectionRow.Amount) / ((VATRate + 100) / 100),
								  				TabularSectionRow.Amount * VATRate / 100);
					        		
			If TabularSectionRow.Property("Total") Then									
				TabularSectionRow.Total = TabularSectionRow.Amount + ?(DocumentForm.Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
			EndIf;
			
		// Offset amount.	
		ElsIf TabularSectionRow.Property("OffsetAmount") Then
			
			TabularSectionRow.OffsetAmount = RecalculateFromCurrencyToCurrency(TabularSectionRow.OffsetAmount, 
																	RatesStructure.InitRate, 
																	RatesStructure.ExchangeRate, 
																	RatesStructure.RepetitionBeg, 
																	RatesStructure.Multiplicity);														
			
			VATRate = DriveReUse.GetVATRateValue(TabularSectionRow.VATRate);
			
	        TabularSectionRow.VATAmount = ?(DocumentForm.Object.AmountIncludesVAT, 
								  				TabularSectionRow.OffsetAmount - (TabularSectionRow.OffsetAmount) / ((VATRate + 100) / 100),
								  				TabularSectionRow.OffsetAmount * VATRate / 100);
		EndIf;
        		        
	EndDo; 

EndProcedure

#Region DiscountCards

// Recalculate document tabular section amount after reading discount card.
Procedure RefillDiscountsTablePartAfterDiscountCardRead(DocumentForm, TabularSectionName) Export
																	   
	Discount = DriveServer.GetDiscountPercentByDiscountMarkupKind(DocumentForm.Object.DiscountMarkupKind) + DocumentForm.Object.DiscountPercentByDiscountCard;
	
	For Each TabularSectionRow In DocumentForm.Object[TabularSectionName] Do
		
		TabularSectionRow.DiscountMarkupPercent = Discount;
		
		CalculateTabularSectionRowSUM(DocumentForm, TabularSectionRow);
		        
	EndDo;
	
EndProcedure

#EndRegion

#EndRegion

#Region ProceduresAndFunctionsOfAdditionalAttributesSubsystem

// Procedure expands values tree on form.
//
Procedure ExpandPropertiesValuesTree(FormItem, Tree) Export
	
	For Each Item In Tree.GetItems() Do
		ID = Item.GetID();
		FormItem.Expand(ID, True);
	EndDo;
	
EndProcedure

// Procedure handler of the BeforeDeletion event.
//
Procedure PropertyValueTreeBeforeDelete(Item, Cancel, Modified) Export
	
	Cancel = True;
	Item.CurrentData.Value = Item.CurrentData.PropertyValueType.AdjustValue(Undefined);
	Modified = True;
	
EndProcedure

// Procedure handler of the OnStartEdit event.
//
Procedure PropertyValueTreeOnStartEdit(Item) Export
	
	Item.ChildItems.Value.TypeRestriction = Item.CurrentData.PropertyValueType;
	
EndProcedure

#EndRegion

#Region ProceduresAndFunctionsOfWorkWithDynamicLists

// Deletes dynamic list filter item
//
// Parameters:
// List  - processed dynamic
// list, FieldName - layout field name filter by which should be deleted
//
Procedure DeleteListFilterItem(List, FieldName) Export
	
	CompositionField = New DataCompositionField(FieldName);
	Counter = 1;
	While Counter <= List.Filter.Items.Count() Do
		FilterItem = List.Filter.Items[Counter - 1];
		If TypeOf(FilterItem) = Type("DataCompositionFilterItem")
			AND FilterItem.LeftValue = CompositionField Then
			List.Filter.Items.Delete(FilterItem);
		Else
			Counter = Counter + 1;
		EndIf;	
	EndDo; 
	
EndProcedure

// Sets dynamic list filter item
//
// Parameters:
// List			- processed dynamic
// list, FieldName			- layout field name filter on which
// should be set, ComparisonKind		- filter comparison kind, by default - Equal,
// RightValue 	- filter value
//
Procedure SetListFilterItem(List, FieldName, RightValue, ComparisonType = Undefined) Export
	
	FilterItem = List.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterItem.LeftValue    = New DataCompositionField(FieldName);
	FilterItem.ComparisonType     = ?(ComparisonType = Undefined, DataCompositionComparisonType.Equal, ComparisonType);
	FilterItem.Use    = True;
	FilterItem.RightValue   = RightValue;
	FilterItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	
EndProcedure

// Changes dynamic list filter item
//
// Parameters:
// List         - processed dynamic
// list, FieldName        - layout field name filter on which
// should be set, ComparisonKind   - filter comparison kind, by default - Equal,
// RightValue - filter
// value, Set     - shows that it is required to set filter
//
Procedure ChangeListFilterElement(List, FieldName, RightValue = Undefined, Set = False, ComparisonType = Undefined, FilterByPeriod = False) Export
	
	DeleteListFilterItem(List, FieldName);
	
	If Set Then
		If FilterByPeriod Then
			SetListFilterItem(List, FieldName, RightValue.StartDate, DataCompositionComparisonType.GreaterOrEqual);
			SetListFilterItem(List, FieldName, RightValue.EndDate, DataCompositionComparisonType.LessOrEqual);		
		Else
		    SetListFilterItem(List, FieldName, RightValue, ComparisonType);	
		EndIf;		
	EndIf;
	
EndProcedure

// Function reads values of dynamic list filter items
//
Function ReadValuesOfFilterDynamicList(List) Export
	
	FillingData = New Structure;
	
	If TypeOf(List) = Type("DynamicList") Then
		
		For Each FilterDynamicListItem In List.SettingsComposer.Settings.Filter.Items Do
			
			FilterName = String(FilterDynamicListItem.LeftValue);
			FilterValue = FilterDynamicListItem.RightValue;
			
			If Find(FilterName, ".") > 0 OR Not FilterDynamicListItem.Use Then
				
				Continue;
				
			EndIf;
			
			FillingData.Insert(FilterName, FilterValue);
			
		EndDo;
		
	EndIf;
	
	Return FillingData;
	
EndFunction

#EndRegion

#Region CalculationsManagementProceduresAndFunctions

// Procedure opens a form of totals calculations self management
//
Procedure TotalsControl() Export
	
EndProcedure

#EndRegion

#Region PrintingManagementProceduresAndFunctions

// Function generates title for the general form "Printing".
// CommandParameter - printing command parameter.
//
Function GetTitleOfPrintedForms(CommandParameter) Export
	
	If TypeOf(CommandParameter) = Type("Array") 
		AND CommandParameter.Count() = 1 Then 
		
		Return New Structure("FormTitle", CommandParameter[0]);
		
	EndIf;

	Return Undefined;
	
EndFunction

// Processor procedure the "LabelPrinting" or "PriceTagCommand" command from documents 
// - Stock summary
// - Supplier invoice
//
Function PrintLabelsAndPriceTagsFromDocuments(CommandParameter) Export
	
	If CommandParameter.Count() > 0 Then
		
		ObjectArrayPrint = CommandParameter.PrintObjects;
		IsPriceTags = Find(CommandParameter.ID, "TagsPrinting") > 0;
		AddressInStorage = DriveServer.PreparePriceTagsAndLabelsPrintingFromDocumentsDataStructure(ObjectArrayPrint, IsPriceTags);
		ParameterStructure = New Structure("AddressInStorage", AddressInStorage);
		OpenForm("DataProcessor.PrintLabelsAndTags.Form.Form", ParameterStructure, , New UUID);
		
	EndIf;
	
	Return Undefined;
	
EndFunction

Function GenerateContractForms(CommandParameter) Export
	
	For Each PrintObject In CommandParameter.PrintObjects Do
		
		Parameters = New Structure;
		Parameters.Insert("Key", DriveServer.GetContractDocument(PrintObject));
		Parameters.Insert("Document", PrintObject);
		ContractForm = GetForm("Catalog.CounterpartyContracts.ObjectForm", Parameters);
		OpenForm(ContractForm);
		ContractForm.Items.Pages.CurrentPage = ContractForm.Items.GroupPrintContract;
		
	EndDo;
	
	Return Undefined;
	
EndFunction

Function PrintCounterpartyContract(CommandParameter) Export
		
	If CommandParameter.Form.FormName = "Catalog.CounterpartyContracts.Form.ItemForm" Then 
		PrintingSource = CommandParameter.Form;
	Else
		
		CurrentData = CommandParameter.Form.Items.List.CurrentData;
		If CurrentData = Undefined Then
			Return Undefined;
		EndIf;

		FormParameters	= New Structure("Key", CurrentData.Ref);
		ContractForm	= GetForm("Catalog.CounterpartyContracts.ObjectForm", FormParameters);		
		
		OpenForm(ContractForm);
		
		PrintingSource	= ContractForm;
		
	EndIf;
	
	PrintingSource.Items.Pages.CurrentPage = PrintingSource.Items.GroupPrintContract;
	
	If CommandParameter.Form.FormName = "Catalog.CounterpartyContracts.Form.ItemForm" Then
		
		Object		= CommandParameter.Form.Object;
		Contract	= PrintingSource.ContractHTMLDocument;
		
		If Not ValueIsFilled(Object.ContractForm) Then 
			Return Undefined;
		EndIf;
		
		FilterParameters = New Structure;
		FilterParameters.Insert("FormRefs", Object.ContractForm);
		
		EditedParametersArray		= Object.EditableParameters.FindRows(FilterParameters);
		AllEditedParametersFilled	= True;
		
		For Each String In EditedParametersArray Do 
			If Find(Contract, String.ID) <> 0 Then
				If Not ValueIsFilled(String.Value) Then 
					AllEditedParametersFilled = False;
					Break;
				EndIf;
			EndIf;
		EndDo;
		
		If Not AllEditedParametersFilled Then
			ShowQueryBox(New NotifyDescription("PrintCounterpartyContractQuestion", 
				ThisObject,
				New Structure("PrintingSource", PrintingSource)),
				NStr("en = 'Not all manually edited fields are filled in, continue printing?'"), 
				QuestionDialogMode.YesNo);
		Else
			PrintCounterpartyContractEnd(PrintingSource);
		EndIf;
		
	EndIf;
	
	Return Undefined;
	
EndFunction

Function PrintCounterpartyContractQuestion(Result, AdditionalParameters) Export
	
	PrintingSource = AdditionalParameters.PrintingSource;
	
	If Result = DialogReturnCode.Yes Then
		PrintCounterpartyContractEnd(PrintingSource);
	EndIf;
	
EndFunction

Function PrintCounterpartyContractEnd(PrintingSource)
	
	document = PrintingSource.Items.ContractHTMLDocument.Document;
	If document.execCommand("Print") = False Then 
		document.defaultView.print();
	EndIf;
	
EndFunction

#EndRegion

#Region PredefinedProceduresAndFunctionsOfEmailSending

// Interface client procedure that supports call of new email editing form.
// While sending email via the standard common form EmailMessage messages are not saved in the infobase.
//
// For the parameters, see description of the WorkWithPostalMailClient.CreateNewEmail function.
//
Procedure OpenEmailMessageSendForm(Sender, Recipient, Subject, Text, FileList, BasisDocuments, DeleteFilesAfterSend, OnCloseNotifyDescription) Export
	
	EmailParameters = New Structure;
	
	EmailParameters.Insert("FillingValues", New Structure("EventType", PredefinedValue("Enum.EventTypes.Email")));
	
	EmailParameters.Insert("UserAccount", Sender);
	EmailParameters.Insert("Whom", Recipient);
	EmailParameters.Insert("Subject", Subject);
	EmailParameters.Insert("Body", Text);
	EmailParameters.Insert("Attachments", FileList);
	EmailParameters.Insert("BasisDocuments", BasisDocuments);
	EmailParameters.Insert("DeleteFilesAfterSend", DeleteFilesAfterSend);
	
	OpenForm("Document.Event.Form.EmailForm", EmailParameters, , , , , OnCloseNotifyDescription);
	
EndProcedure

// Creates email by contact information.
// While email is generated with the standard procedure, the information about object contact is not passed to a sending
// form
//
// For the parameters, see description of the ContactInformationManagementClient.CreateEmail function.
//
Procedure CreateEmail(Val FieldsValues, Val Presentation = "", ExpectedKind = Undefined, FormObject) Export
	
	ContactInformation = ContactInformationInternalServerCall.TransformContactInformationXML(
		New Structure("FieldsValues, Presentation, ContactInformationKind", FieldsValues, Presentation, ExpectedKind));
		
	InformationType = ContactInformation.ContactInformationType;
	If InformationType <> PredefinedValue("Enum.ContactInformationTypes.EmailAddress") Then
		Raise StrReplace(NStr("en = 'Cannot create email by contact information with type ""%1""'"),
			"%1", InformationType);
	EndIf;
	
	XMLData = ContactInformation.DataXML;
	MailAddress = ContactInformationInternalServerCall.ContactInformationContentString(XMLData);
	If TypeOf(MailAddress) <> Type("String") Then
		Raise NStr("en = 'An error occurred when receiving the email address, incorrect contact information type'");
	EndIf;
	
	If CommonUseClient.SubsystemExists("StandardSubsystems.EmailOperations") Then
		ModuleWorkWithPostalMailClient = CommonUseClient.CommonModule("EmailOperationsClient");
		ObjectContact = Undefined;
		FormObject.Property("Ref", ObjectContact);
		StructureRecipient = New Structure("Presentation, Address", ObjectContact, MailAddress);
		MailAddress = New Array;
		MailAddress.Add(StructureRecipient);
		
		SendingParameters = New Structure("Recipient", MailAddress);
		ModuleWorkWithPostalMailClient.CreateNewEmail(SendingParameters);
		Return; 
	EndIf;
	
	// No mail subsystem, start the system one
	Notification = New NotifyDescription("CreateEmailByContactInformationEnd", ThisObject, MailAddress);
	SuggestionText = NStr("en = 'To send the email, install the file operation extension.'");
	CommonUseClient.CheckFileOperationsExtensionConnected(Notification, SuggestionText);
	
EndProcedure

//////////////////////////////////////////////////////////////////////////////// 
// General module CommonUse does not support "Server call" any more.
// Corrections and support of a new behavior
//

// Replaces
// call CommonUse.ObjectAttributeValue from the Add() procedure of the Price-list processor form
//
Function ReadAttributeValue_Owner(ObjectOrRef) Export
	
	Return DriveServer.ReadAttributeValue_Owner(ObjectOrRef);
	
EndFunction

#Region GenerateCommands

Procedure GoodsIssueGenerationBasedOnSalesOrder(SalesOrdersListItem) Export

	If SalesOrdersListItem.CurrentData = Undefined Then
		
		WarningText = NStr("en = 'Command cannot be executed for the specified object.'");
		ShowMessageBox(Undefined, WarningText);
		Return;
		
	EndIf;
	
	OrdersArray = SalesOrdersListItem.SelectedRows;
	
	If OrdersArray.Count() = 1 Then
		
		OpenParameters = New Structure("Basis", OrdersArray[0]);
		OpenForm("Document.GoodsIssue.ObjectForm", OpenParameters);
		
	Else
		
		DataStructure = DriveServer.CheckOrdersAndInvoicesKeyAttributesForGoodsIssue(OrdersArray);
		If DataStructure.CreateMultipleInvoices Then
			
			MessageText = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'The orders have different %1 in document headers. Do you want to split them into several documents?'"),
				DataStructure.DataPresentation);
			
			ShowQueryBox(
				New NotifyDescription("CreateGoodsIssue",
					ThisObject,
					New Structure("OrdersGroups", DataStructure.OrdersGroups)),
				MessageText, QuestionDialogMode.YesNo, 0);
			
		Else
			
			BasisStructure = New Structure;
			BasisStructure.Insert("ArrayOfSalesOrders", OrdersArray);
			OpenForm("Document.GoodsIssue.ObjectForm", New Structure("Basis", BasisStructure));
			
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure CreateGoodsIssue(Result, AdditionalParameters) Export

	If Result = DialogReturnCode.Yes Then
		For Each OrdersArray In AdditionalParameters.OrdersGroups Do
			FillStructure = New Structure;
			FillStructure.Insert("ArrayOfSalesOrders", OrdersArray);
			OpenForm("Document.GoodsIssue.ObjectForm", New Structure("Basis", FillStructure), , True);
		EndDo;
	EndIf;

EndProcedure

Procedure GoodsIssueGenerationBasedOnSalesInvoice(SalesInvoicesListItem) Export

	If SalesInvoicesListItem.CurrentData = Undefined Then
		
		WarningText = NStr("en = 'Command cannot be executed for the specified object.'");
		ShowMessageBox(Undefined, WarningText);
		Return;
		
	EndIf;
	
	InvoicesArray = SalesInvoicesListItem.SelectedRows;
	
	If InvoicesArray.Count() = 1 Then
		
		OpenParameters = New Structure("Basis", InvoicesArray[0]);
		OpenForm("Document.GoodsIssue.ObjectForm", OpenParameters);
		
	Else
		
		DataStructure = DriveServer.CheckOrdersAndInvoicesKeyAttributesForGoodsIssue(InvoicesArray);
		If DataStructure.CreateMultipleInvoices Then
			
			MessageText = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'The invoices have different %1 in document headers. Do you want to split them into several documents?'"),
				DataStructure.DataPresentation);
			
			ShowQueryBox(
				New NotifyDescription("CreateGoodsIssueBasedOnSalesInvoice",
					ThisObject,
					New Structure("OrdersGroups", DataStructure.OrdersGroups)),
				MessageText, QuestionDialogMode.YesNo, 0);
			
		Else
			
			BasisStructure = New Structure;
			BasisStructure.Insert("ArrayOfSalesInvoices", InvoicesArray);
			OpenForm("Document.GoodsIssue.ObjectForm", New Structure("Basis", BasisStructure));
			
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure CreateGoodsIssueBasedOnSalesInvoice(Result, AdditionalParameters) Export

	If Result = DialogReturnCode.Yes Then
		For Each OrdersArray In AdditionalParameters.OrdersGroups Do
			FillStructure = New Structure;
			FillStructure.Insert("ArrayOfSalesInvoices", OrdersArray);
			OpenForm("Document.GoodsIssue.ObjectForm", New Structure("Basis", FillStructure), , True);
		EndDo;
	EndIf;

EndProcedure

Procedure GoodsReceiptGenerationBasedOnPurchaseOrder(PurchaseOrdersListItem) Export

	If PurchaseOrdersListItem.CurrentData = Undefined Then
		
		WarningText = NStr("en = 'Command cannot be executed for the specified object.'");
		ShowMessageBox(Undefined, WarningText);
		Return;
		
	EndIf;
	
	OrdersArray = PurchaseOrdersListItem.SelectedRows;
	
	If OrdersArray.Count() = 1 Then
		
		OpenParameters = New Structure("Basis", OrdersArray[0]);
		OpenForm("Document.GoodsReceipt.ObjectForm", OpenParameters);
		
	Else
		
		DataStructure = DriveServer.CheckPurchaseOrdersKeyAttributes(OrdersArray, True);
		If DataStructure.CreateMultipleInvoices Then
			
			MessageText = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'The orders have different %1 in document headers. Do you want to split them into several documents?'"),
				DataStructure.DataPresentation);
			
			ShowQueryBox(
				New NotifyDescription("CreateGoodsReceipt",
					ThisObject,
					New Structure("OrdersGroups", DataStructure.OrdersGroups)),
				MessageText, QuestionDialogMode.YesNo, 0);
			
		Else
			
			BasisStructure = New Structure;
			BasisStructure.Insert("OrdersArray", OrdersArray);
			OpenForm("Document.GoodsReceipt.ObjectForm", New Structure("Basis", BasisStructure));
			
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure CreateGoodsReceipt(Result, AdditionalParameters) Export

	If Result = DialogReturnCode.Yes Then
		For Each OrdersArray In AdditionalParameters.OrdersGroups Do
			FillStructure = New Structure;
			FillStructure.Insert("OrdersArray", OrdersArray);
			OpenForm("Document.GoodsReceipt.ObjectForm", New Structure("Basis", FillStructure), , True);
		EndDo;
	EndIf;

EndProcedure

Procedure SalesInvoiceGenerationBasedOnGoodsIssue(GoodsIssueListItem) Export

	If TypeOf(GoodsIssueListItem) = Type("Array") Then
		GoodsIssueArray = GoodsIssueListItem;
	Else
		
		If GoodsIssueListItem.CurrentData = Undefined Then
		
			WarningText = NStr("en = 'Command cannot be executed for the specified object.'");
			ShowMessageBox(Undefined, WarningText);
			Return;
			
		EndIf;
		
		GoodsIssueArray = GoodsIssueListItem.SelectedRows;
	EndIf;
	
	DataStructure = DriveServer.CheckGoodsIssueKeyAttributes(GoodsIssueArray);
	If DataStructure.CreateMultipleInvoices Then
		
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'The goods issues have different %1 in document. Do you want to split them into several documents?'"),
			DataStructure.DataPresentation);
		
		ShowQueryBox(
			New NotifyDescription("CreateSalesInvoicesBasedOnGoodsIssue", 
				ThisObject,
				New Structure("GoodsIssueGroups", DataStructure.GoodsIssueGroups)),
			MessageText, QuestionDialogMode.YesNo, 0);
		
	Else
		
		BasisStructure = New Structure;
		BasisStructure.Insert("ArrayOfGoodsIssues", GoodsIssueArray);
		OpenForm("Document.SalesInvoice.ObjectForm", New Structure("Basis", BasisStructure));
		
	EndIf;

EndProcedure

Procedure CreateSalesInvoicesBasedOnGoodsIssue(Result, AdditionalParameters) Export

	If Result = DialogReturnCode.Yes Then
		For Each GoodsIssueArray In AdditionalParameters.GoodsIssueGroups Do
			FillStructure = New Structure;
			FillStructure.Insert("ArrayOfGoodsIssues", GoodsIssueArray);
			OpenForm("Document.SalesInvoice.ObjectForm", New Structure("Basis", FillStructure), , True);
		EndDo;
	EndIf;

EndProcedure

Procedure SalesInvoiceGenerationBasedOnSalesOrder(SalesOrdersListItem) Export

	If SalesOrdersListItem.CurrentData = Undefined Then
		
		WarningText = NStr("en = 'Command cannot be executed for the specified object.'");
		ShowMessageBox(Undefined, WarningText);
		Return;
		
	EndIf;
	
	OrdersArray = SalesOrdersListItem.SelectedRows;
	
	If OrdersArray.Count() = 1 Then
		
		OpenParameters = New Structure("Basis", OrdersArray[0]);
		OpenForm("Document.SalesInvoice.ObjectForm", OpenParameters);
		
	Else
		
		DataStructure = DriveServer.CheckOrdersKeyAttributes(OrdersArray);
		If DataStructure.CreateMultipleInvoices Then
			
			MessageText = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'The orders have different %1 in document headers. Do you want to split them into several documents?'"),
				DataStructure.DataPresentation);
			
			ShowQueryBox(
				New NotifyDescription("CreateSalesInvoices", 
					ThisObject,
					New Structure("OrdersGroups", DataStructure.OrdersGroups)),
				MessageText, QuestionDialogMode.YesNo, 0);
			
		Else
			
			BasisStructure = New Structure();
			BasisStructure.Insert("ArrayOfSalesOrders", OrdersArray);
			OpenForm("Document.SalesInvoice.ObjectForm", New Structure("Basis", BasisStructure));
			
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure SalesInvoiceGenerationBasedOnWorkOrder(WorkOrdersListItem) Export

	If WorkOrdersListItem.CurrentData = Undefined Then
		
		WarningText = NStr("en = 'Command cannot be executed for the specified object.'");
		ShowMessageBox(Undefined, WarningText);
		Return;
		
	EndIf;
	
	OrdersArray = WorkOrdersListItem.SelectedRows;
	
	If OrdersArray.Count() = 1 Then
		
		OpenParameters = New Structure("Basis", OrdersArray[0]);
		OpenForm("Document.SalesInvoice.ObjectForm", OpenParameters);
		
	Else
		
		DataStructure = DriveServer.CheckWorkOrdersKeyAttributes(OrdersArray);
		If DataStructure.CreateMultipleInvoices Then
			
			MessageText = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'The orders have different %1 in document headers. Do you want to split them into several documents?'"),
				DataStructure.DataPresentation);
			
			ShowQueryBox(
				New NotifyDescription("CreateSalesInvoicesOnWorkOrder", 
					ThisObject,
					New Structure("OrdersGroups", DataStructure.OrdersGroups)),
				MessageText, QuestionDialogMode.YesNo, 0);
			
		Else
			
			BasisStructure = New Structure();
			BasisStructure.Insert("ArrayOfWorkOrders", OrdersArray);
			OpenForm("Document.SalesInvoice.ObjectForm", New Structure("Basis", BasisStructure));
			
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure CreateSalesInvoices(Result, AdditionalParameters) Export

	If Result = DialogReturnCode.Yes Then
		For Each OrdersArray In AdditionalParameters.OrdersGroups Do
			FillStructure = New Structure;
			FillStructure.Insert("ArrayOfSalesOrders", OrdersArray);
			OpenForm("Document.SalesInvoice.ObjectForm", New Structure("Basis", FillStructure), , True);
		EndDo;
	EndIf;

EndProcedure

Procedure CreateSalesInvoicesOnWorkOrder(Result, AdditionalParameters) Export

	If Result = DialogReturnCode.Yes Then
		For Each OrdersArray In AdditionalParameters.OrdersGroups Do
			FillStructure = New Structure;
			FillStructure.Insert("ArrayOfWorkOrders", OrdersArray);
			OpenForm("Document.SalesInvoice.ObjectForm", New Structure("Basis", FillStructure), , True);
		EndDo;
	EndIf;

EndProcedure

Procedure SupplierInvoiceGenerationBasedOnPurchaseOrder(PurchaseOrdersListItem) Export

	If PurchaseOrdersListItem.CurrentData = Undefined Then
		
		WarningText = NStr("en = 'Command cannot be executed for the specified object.'");
		ShowMessageBox(Undefined, WarningText);
		Return;
		
	EndIf;
	
	OrdersArray = PurchaseOrdersListItem.SelectedRows;
	
	If OrdersArray.Count() = 1 Then
		
		OpenParameters = New Structure("Basis", OrdersArray[0]);
		OpenForm("Document.SupplierInvoice.ObjectForm", OpenParameters);
		
	Else
		
		DataStructure = DriveServer.CheckPurchaseOrdersKeyAttributes(OrdersArray);
		If DataStructure.CreateMultipleInvoices Then
			
			MessageText = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'The orders have different %1 in document headers. Do you want to split them into several documents?'"),
				DataStructure.DataPresentation);
			
			ShowQueryBox(
				New NotifyDescription("CreateSuppliersInvoices", 
					ThisObject,
					New Structure("OrdersGroups", DataStructure.OrdersGroups)),
				MessageText, QuestionDialogMode.YesNo, 0);
			
		Else
			
			BasisStructure = New Structure();
			BasisStructure.Insert("ArrayOfPurchaseOrders", OrdersArray);
			OpenForm("Document.SupplierInvoice.ObjectForm", New Structure("Basis", BasisStructure));
			
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure CreateSuppliersInvoices(Result, AdditionalParameters) Export

	If Result = DialogReturnCode.Yes Then
		For Each OrdersArray In AdditionalParameters.OrdersGroups Do
			FillStructure = New Structure;
			FillStructure.Insert("ArrayOfPurchaseOrders", OrdersArray);
			OpenForm("Document.SupplierInvoice.ObjectForm", New Structure("Basis", FillStructure), , True);
		EndDo;
	EndIf;

EndProcedure

Procedure SupplierInvoiceGenerationBasedOnGoodsReceipt(GoodsReceiptListItem) Export

	If TypeOf(GoodsReceiptListItem) = Type("Array") Then
		GoodsReceiptArray = GoodsReceiptListItem;
	Else
		
		If GoodsReceiptListItem.CurrentData = Undefined Then
		
			WarningText = NStr("en = 'Command cannot be executed for the specified object.'");
			ShowMessageBox(Undefined, WarningText);
			Return;
			
		EndIf;
		
		GoodsReceiptArray = GoodsReceiptListItem.SelectedRows;
	EndIf;
	
	DataStructure = DriveServer.CheckGoodsReceiptKeyAttributes(GoodsReceiptArray);
	If DataStructure.CreateMultipleInvoices Then
		
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'The goods receipts have different %1 in document. Do you want to split them into several documents?'"),
			DataStructure.DataPresentation);
		
		ShowQueryBox(
			New NotifyDescription("CreateSupplierInvoicesBasedOnGoodsReceipt",
				ThisObject,
				New Structure("GoodsReceiptGroups", DataStructure.GoodsReceiptGroups)),
			MessageText, QuestionDialogMode.YesNo, 0);
		
	Else
		
		BasisStructure = New Structure;
		BasisStructure.Insert("GoodsReceiptArray", GoodsReceiptArray);
		OpenForm("Document.SupplierInvoice.ObjectForm", New Structure("Basis", BasisStructure));
		
	EndIf;

EndProcedure

Procedure CreateSupplierInvoicesBasedOnGoodsReceipt(Result, AdditionalParameters) Export

	If Result = DialogReturnCode.Yes Then
		For Each GoodsReceiptArray In AdditionalParameters.GoodsReceiptGroups Do
			FillStructure = New Structure;
			FillStructure.Insert("GoodsReceiptArray", GoodsReceiptArray);
			OpenForm("Document.SupplierInvoice.ObjectForm", New Structure("Basis", FillStructure), , True);
		EndDo;
	EndIf;

EndProcedure

Procedure CustomsDeclarationGenerationBasedOnSupplierInvoice(SupplierInvoicesListItem) Export

	If SupplierInvoicesListItem.CurrentData = Undefined Then
		
		WarningText = NStr("en = 'Command cannot be executed for the specified object.'");
		ShowMessageBox(Undefined, WarningText);
		Return;
		
	EndIf;
	
	InvoicesArray = SupplierInvoicesListItem.SelectedRows;
	
	If InvoicesArray.Count() = 1 Then
		
		OpenParameters = New Structure("Basis", InvoicesArray[0]);
		OpenForm("Document.CustomsDeclaration.ObjectForm", OpenParameters);
		
	Else
		
		DataStructure = DriveServer.CheckSupplierInvoicesKeyAttributes(InvoicesArray);
		If DataStructure.CreateMultipleCustomsDeclarations Then
			
			MessageText = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'The invoices have different %1 in document headers. Create multiple customs declarations?'"),
				DataStructure.DataPresentation);
			
			ShowQueryBox(
				New NotifyDescription("CreateCustomsDeclaration", 
					ThisObject,
					New Structure("InvoicesGroups", DataStructure.InvoicesGroups)),
				MessageText, QuestionDialogMode.YesNo, 0);
			
		Else
			
			BasisStructure = New Structure();
			BasisStructure.Insert("ArrayOfSupplierInvoices", InvoicesArray);
			OpenForm("Document.CustomsDeclaration.ObjectForm", New Structure("Basis", BasisStructure));
			
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure CreateCustomsDeclaration(Result, AdditionalParameters) Export

	If Result = DialogReturnCode.Yes Then
		For Each InvoicesArray In AdditionalParameters.InvoicesGroups Do
			FillStructure = New Structure;
			FillStructure.Insert("ArrayOfSupplierInvoices", InvoicesArray);
			OpenForm("Document.CustomsDeclaration.ObjectForm", New Structure("Basis", FillStructure), , True);
		EndDo;
	EndIf;

EndProcedure
#EndRegion

#EndRegion

#Region ProceduresForWorkWithProductsSelectionForm

// Function creates a structure for ProductsSelection data processor
//
Function GetSelectionParameters(OwnerForm, TabularSectionName, DocumentPresentaion = "document", ShowBatch = True, ShowPrice = True, ShowAvailable = True) Export
	
	SelectionParameters = New Structure;
	
	OwnerObject = OwnerForm.Object;
	
	If OwnerObject.Property("Date") Then
		SelectionParameters.Insert("Date", OwnerObject.Date);
	Else
		SelectionParameters.Insert("Date", CurrentDate());
	EndIf;
	SelectionParameters.Insert("PricePeriod", SelectionParameters.Date);
	
	If OwnerObject.Property("Company") Then
		SelectionParameters.Insert("Company", OwnerObject.Company);
	Else
		SelectionParameters.Insert("Company", PredefinedValue("Catalog.Companies.EmptyRef"));
	EndIf;
	
	If OwnerObject.Property("StructuralUnit") Then
		SelectionParameters.Insert("StructuralUnit", OwnerObject.StructuralUnit);
	Else
		SelectionParameters.Insert("StructuralUnit", PredefinedValue("Catalog.BusinessUnits.EmptyRef"));
	EndIf;

	DiscountsMarkupsVisible = False;
	If OwnerObject.Property("DiscountMarkupKind") Then
		SelectionParameters.Insert("DiscountMarkupKind", OwnerObject.DiscountMarkupKind);
		DiscountsMarkupsVisible = True;
	EndIf;
	SelectionParameters.Insert("DiscountsMarkupsVisible", DiscountsMarkupsVisible);
	
	If OwnerObject.Property("PriceKind") Then
		SelectionParameters.Insert("PriceKind", OwnerObject.PriceKind);
	Else
		SelectionParameters.Insert("PriceKind", PredefinedValue("Catalog.PriceTypes.EmptyRef"));
	EndIf;
	
	If OwnerObject.Property("DocumentCurrency") Then
		SelectionParameters.Insert("DocumentCurrency", OwnerObject.DocumentCurrency);
	Else
		SelectionParameters.Insert("DocumentCurrency", Undefined);
	EndIf;

	If OwnerObject.Property("DocumentCurrency") Then
		SelectionParameters.Insert("DocumentCurrency", OwnerObject.DocumentCurrency);
	Else
		SelectionParameters.Insert("DocumentCurrency", Undefined);
	EndIf;

	If OwnerObject.Property("AmountIncludesVAT") Then
		SelectionParameters.Insert("AmountIncludesVAT", OwnerObject.AmountIncludesVAT);
	EndIf;
	
	If OwnerObject.Property("VATTaxation") Then
		SelectionParameters.Insert("VATTaxation", OwnerObject.VATTaxation);
	EndIf;
	
	SelectionParameters.Insert("OwnerFormUUID", OwnerForm.UUID);
	
	If ValueIsFilled(OwnerObject.Ref) Then
		DocumentPresentaion = "" + OwnerObject.Ref;
	EndIf;
	Title = StringFunctionsClientServer.SubstituteParametersInString(NStr("en = 'Select products for %1'"),
																	DocumentPresentaion);
	SelectionParameters.Insert("Title", Title);
	
	//Products type
	ProductsType = New ValueList;
	ProductsColumn = OwnerForm.Items.Find(TabularSectionName + "Products");
	If ProductsColumn  <> Undefined Then
		For Each ArrayElement In ProductsColumn.ChoiceParameters Do
			If ArrayElement.Name = "Filter.ProductsType" Then
				If TypeOf(ArrayElement.Value) = Type("FixedArray") Then
					For Each FixArrayItem In ArrayElement.Value Do
						ProductsType.Add(FixArrayItem);
					EndDo; 
				Else
					ProductsType.Add(ArrayElement.Value);
				EndIf;
			EndIf;
		EndDo;
	EndIf;
	SelectionParameters.Insert("ProductsType", ProductsType);
	
	DiscountCardVisible = False;
	If OwnerObject.Property("DiscountCard") Then
		DiscountCardVisible = True;
		If TypeOf(OwnerObject) = Type("DocumentRef.SalesOrder") Then
			If OwnerObject.OperationKind = PredefinedValue("Enum.OperationTypesSalesOrder.OrderForProcessing") Then
				DiscountCardVisible = False;
			EndIf;
		ElsIf TypeOf(OwnerObject) = Type("DocumentRef.SalesInvoice") Then
			DiscountCardVisible = False;
		EndIf;
		
		If DiscountCardVisible Then
			SelectionParameters.Insert("DiscountCard", OwnerObject.DiscountCard);
			If OwnerObject.Property("DiscountPercentByDiscountCard") Then
				SelectionParameters.Insert("DiscountPercentByDiscountCard", OwnerObject.DiscountPercentByDiscountCard);
			EndIf;
		EndIf;
	EndIf;
	SelectionParameters.Insert("DiscountCardVisible", DiscountCardVisible);
	
	If OwnerObject.Property(TabularSectionName) Then
		TabularSection = OwnerObject[TabularSectionName];
		TotalItems = TabularSection.Count();
		If TotalItems > 0 Then
			If TabularSection[0].Property("Total") Then
				SelectionParameters.Insert("TotalItems", TotalItems);
				SelectionParameters.Insert("TotalAmount", TabularSection.Total("Total"));
			EndIf;
		EndIf; 
	EndIf;
	
	SelectionParameters.Insert("ShowBatch",		ShowBatch);
	SelectionParameters.Insert("ShowPrice",		ShowPrice);
	SelectionParameters.Insert("ShowAvailable",	ShowAvailable);
	
	Return SelectionParameters;
	
EndFunction

#EndRegion
