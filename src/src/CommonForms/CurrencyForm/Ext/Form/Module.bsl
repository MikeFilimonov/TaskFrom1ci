
#Region GeneralPurposeProceduresAndFunctions

&AtServer
// Procedure fills the form parameters.
//
Procedure GetFormValuesOfParameters()
	
	DocumentCurrency				= Parameters.DocumentCurrency;
	DocumentCurrencyBeforeChange	= Parameters.DocumentCurrency;
	ExchangeRate					= Parameters.ExchangeRate;
	ExchangeRateBeforeChange		= Parameters.ExchangeRate;
	Multiplicity					= Parameters.Multiplicity;
	MultiplicityBeforeChange		= Parameters.Multiplicity;
	
	AmountIncludesVAT			= Parameters.AmountIncludesVAT;
	AmountIncludesVATBefore		= Parameters.AmountIncludesVAT;
	
	IncludeVATInPrice				= Parameters.IncludeVATInPrice;
	VATIncludeInCostBeforeChange	= Parameters.IncludeVATInPrice;
	
	DocumentDate = Parameters.DocumentDate;
	
	If Parameters.Property("Company") Then
		Company = Parameters.Company;
	Else
		Company = Undefined;
	EndIf;
	
	// VAT taxation.
	If Parameters.Property("VATTaxation") Then
		
		VATTaxation				= Parameters.VATTaxation;
		VATTaxationOnOpen		= Parameters.VATTaxation;
		VATTaxationIsAttribute	= True;
		
		ReverseChargeNotApplicable = Parameters.Property("ReverseChargeNotApplicable") And Parameters.ReverseChargeNotApplicable;
		
		AccountingPolicy = InformationRegisters.AccountingPolicy.GetAccountingPolicy(DocumentDate, Company);
		
		Items.VATTaxation.ListChoiceMode = True;
		VATTaxationChoiceList = Items.VATTaxation.ChoiceList;
		VATTaxationChoiceList.Clear();
		
		For Each VATTaxationType In Enums.VATTaxationTypes Do
			
			If WorkWithVAT.VATTaxationTypeIsValid(VATTaxationType, AccountingPolicy.RegisteredForVAT, ReverseChargeNotApplicable) Then
				
				VATTaxationChoiceList.Add(VATTaxationType);
				
			EndIf;
			
		EndDo;
		
	Else
		
		Items.VATTaxation.Visible	= False;
		VATTaxationIsAttribute		= False;
		
	EndIf;
	
EndProcedure

&AtServer
// Procedure fills the exchange rates table
//
Procedure FillExchangeRatesTable()
	
	Query = New Query;
	Query.SetParameter("DocumentDate", DocumentDate);
	Query.Text = 
	"SELECT
	|	ExchangeRatesSliceLast.Currency,
	|	ExchangeRatesSliceLast.ExchangeRate,
	|	ExchangeRatesSliceLast.Multiplicity
	|FROM
	|	InformationRegister.ExchangeRates.SliceLast(&DocumentDate, ) AS ExchangeRatesSliceLast";
	
	QueryResultTable = Query.Execute().Unload();
	ExchangeRates.Load(QueryResultTable);
	
EndProcedure

&AtClient
// Fills the exchange rate and multiplier of the document currency.
//
Procedure FillRateRepetitionOfDocumentCurrency()
	
	If ValueIsFilled(DocumentCurrency) Then
		ArrayCourseRepetition = ExchangeRates.FindRows(New Structure("Currency", DocumentCurrency));
		If ValueIsFilled(ArrayCourseRepetition) Then
			ExchangeRate = ArrayCourseRepetition[0].ExchangeRate;
			Multiplicity = ArrayCourseRepetition[0].Multiplicity;
		Else
			ExchangeRate = 0;
			Multiplicity = 0;
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
// Procedure checks the correctness of the form attributes filling.
//
Procedure CheckFillOfFormAttributes(Cancel)
    	
	If Not ValueIsFilled(DocumentCurrency) Then
		Message = New UserMessage();
		Message.Text = NStr("en = 'Currency for population is not selected.'");
		Message.Field = "DocumentCurrency";
		Message.Message();
		Cancel = True;
	EndIf;
	If Not ValueIsFilled(ExchangeRate) Then
		Message = New UserMessage();
		Message.Text = NStr("en = 'Zero exchange rate of the document is found.'");
		Message.Field = "ExchangeRate";
		Message.Message();
		Cancel = True;
	EndIf;
	If Not ValueIsFilled(Multiplicity) Then
		Message = New UserMessage();
		Message.Text = NStr("en = 'Cannot save the currency because its exchange rate multiplier is zero. Please, specify a different multiplier.'");
		Message.Field = "SettlementsMultiplicity";
		Message.Message();
		Cancel = True;
	EndIf;	
	
	// VAT taxation.
	If VATTaxationIsAttribute Then
		If Not ValueIsFilled(VATTaxation) Then
            Message = New UserMessage();
			Message.Text = NStr("en = 'Taxation is not filled in.'");
			Message.Field = "VATTaxation";
			Message.Message();
			Cancel = True;
   		EndIf;
	EndIf;
	
EndProcedure

&AtClient
// Procedure checks if the form was modified.
//
Function CheckIfFormWasModified()

	WereMadeChanges = False;

	ChangesVATTaxation = ?(VATTaxationIsAttribute, VATTaxationOnOpen <> VATTaxation, False);
	
	If RecalculatePricesByCurrency 
		OR (AmountIncludesVATBefore <> AmountIncludesVAT)
		OR (VATIncludeInCostBeforeChange <> IncludeVATInPrice)
		OR (ExchangeRateBeforeChange <> ExchangeRate)
		OR (MultiplicityBeforeChange <> Multiplicity)
		OR (DocumentCurrencyBeforeChange <> DocumentCurrency) 
		OR ChangesVATTaxation Then

        WereMadeChanges = True;

	EndIf; 
	
	Return WereMadeChanges;

EndFunction

#EndRegion

#Region ProcedureFormEventHandlers

&AtServer
// Procedure - event handler OnCreateAtServer of the form.
// The procedure implements
// - initializing the form parameters.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	GetFormValuesOfParameters();
	FillExchangeRatesTable();
		
EndProcedure

#EndRegion

#Region ProcedureActionsOfTheFormCommandPanels

&AtClient
// Procedure - event handler of clicking the Cancel button.
//
Procedure CancelExecute()
	
	ReturnStructure = New Structure();
	ReturnStructure.Insert("DialogReturnCode", DialogReturnCode.Cancel);
	ReturnStructure.Insert("WereMadeChanges", False);
	Close(ReturnStructure);

EndProcedure

&AtClient
// Procedure - event handler of clicking the OK button.
//
Procedure ButtOKExecute()
	
	Cancel = False;

	CheckFillOfFormAttributes(Cancel);
	If Not Cancel Then
		WereMadeChanges = CheckIfFormWasModified();
		ReturnStructure = New Structure();
		ReturnStructure.Insert("DocumentCurrency", DocumentCurrency);
		ReturnStructure.Insert("ExchangeRate", ExchangeRate);
		ReturnStructure.Insert("Multiplicity", Multiplicity);
		ReturnStructure.Insert("AmountIncludesVAT", AmountIncludesVAT);
		ReturnStructure.Insert("IncludeVATInPrice", IncludeVATInPrice);
		ReturnStructure.Insert("RecalculatePricesByCurrency", RecalculatePricesByCurrency);
		ReturnStructure.Insert("VATTaxation", VATTaxation);
		ReturnStructure.Insert("PrevVATTaxation", VATTaxationOnOpen);
		ReturnStructure.Insert("WereMadeChanges", WereMadeChanges);
		ReturnStructure.Insert("DialogReturnCode", DialogReturnCode.OK);
		Close(ReturnStructure);
	EndIf;

EndProcedure

#EndRegion

#Region ProcedureEventHandlersOfFormAttributes

&AtClient
// Procedure - event handler OnChange of the Currency input field.
//
Procedure CurrencyOnChange(Item)
	
	FillRateRepetitionOfDocumentCurrency();
	If ValueIsFilled(DocumentCurrency) 
	   AND DocumentCurrencyBeforeChange <> DocumentCurrency Then
  		RecalculatePricesByCurrency = True;
		FillRateRepetitionOfDocumentCurrency();
  	Else
  		RecalculatePricesByCurrency = False;
	EndIf;
	
EndProcedure

&AtClient
// Procedure - OnChange event handler of the DocumentCurrencyRate entry field.
//
Procedure DocumentCurrencyRateOnChange(Item)
	
	If ValueIsFilled(ExchangeRate) 
	   AND ExchangeRateBeforeChange <> ExchangeRate Then
		RecalculatePricesByCurrency = True;
	Else
		RecalculatePricesByCurrency = False;
	EndIf;
	
EndProcedure

&AtClient
// Procedure - OnChange event handler of the DocumentCurrencyRatio entry field.
//
Procedure RepetitionDocumentCurrenciesOnChange(Item)
	
	If ValueIsFilled(Multiplicity) 
	   AND MultiplicityBeforeChange <> Multiplicity Then
		RecalculatePricesByCurrency = True;
	Else
		RecalculatePricesByCurrency = False;
	EndIf;
	
EndProcedure

#EndRegion
