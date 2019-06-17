#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

// Procedure - event handler BeforeWrite object.
//
Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;

	DocumentAmount = Inventory.Total("Total");
	
	If ValueIsFilled(Counterparty)
	AND Not Counterparty.DoOperationsByContracts
	AND Not ValueIsFilled(Contract) Then
		Contract = Counterparty.ContractByDefault;
	EndIf;
	
EndProcedure

// Procedure - event handler FillingProcessor object.
//
Procedure Filling(FillingData, StandardProcessing) Export
	
	If TypeOf(FillingData) = Type("DocumentRef.Event") Then
	
		Event = FillingData.Ref;
		If FillingData.Participants.Count() > 0 AND TypeOf(FillingData.Participants[0].Contact) = Type("CatalogRef.Counterparties") Then
			Counterparty = FillingData.Participants[0].Contact;
			Contract = Counterparty.ContractByDefault;
			SupplierPriceTypes = Contract.SupplierPriceTypes;
		EndIf;
		
		StructureByCurrency = InformationRegisters.ExchangeRates.GetLast(Date, New Structure("Currency", Contract.SettlementsCurrency));
		ExchangeRate = StructureByCurrency.ExchangeRate;
		Multiplicity = StructureByCurrency.Multiplicity;
		
	EndIf;
	
EndProcedure

// Procedure - event handler FillCheckProcessing object.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If SetPaymentTerms
	   AND CashAssetsType = Enums.CashAssetTypes.Noncash Then
	   
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PettyCash");
		
	ElsIf SetPaymentTerms
	   AND CashAssetsType = Enums.CashAssetTypes.Cash Then
	   
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "BankAccount");
		
	Else
		
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PettyCash");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "BankAccount");
		
	EndIf;
	
	If SetPaymentTerms
	   AND PaymentCalendar.Count() = 1
	   AND Not ValueIsFilled(PaymentCalendar[0].PaymentDate) Then
		
		MessageText = NStr("en = 'The ""Payment date"" field is not filled in.'");
		DriveServer.ShowMessageAboutError(ThisObject, MessageText, , , "PaymentDate", Cancel);
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentCalendar.PaymentDate");
		
	EndIf;
	
	If Not Counterparty.DoOperationsByContracts Then
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Contract");
	EndIf;
	
	//Payment calendar
	Amount = Inventory.Total("Amount");
	VATAmount = Inventory.Total("VATAmount");
	PaymentTermsServer.CheckCorrectPaymentCalendar(ThisObject, Cancel, Amount, VATAmount);
	
EndProcedure

Procedure Posting(Cancel, PostingMode)
	
	DriveServer.ReflectUsingPaymentTermsInDocuments(Ref, Cancel);
	
EndProcedure

#EndRegion

#Region DocumentFillingProcedures

Procedure FillPaymentCalendarFromContract() Export
	
	Query = New Query("
	|SELECT
	|	Table.Term AS Term,
	|	Table.DuePeriod AS DuePeriod,
	|	Table.PaymentPercentage AS PaymentPercentage
	|FROM
	|	Catalog.CounterpartyContracts.StagesOfPayment AS Table
	|WHERE
	|	Table.Ref = &Ref
	|");
	
	Query.SetParameter("Ref", Contract);
	
	Result = Query.Execute();
	DataSelection = Result.Select();
	
	If Result.IsEmpty() Then
		Return;
	EndIf;
	
	PaymentCalendar.Clear();
	
	TotalAmountForCorrectBalance = 0;
	TotalVATForCorrectBalance = 0;
	
	TotalAmount = Inventory.Total("Amount");
	TotalVAT = Inventory.Total("VATAmount");
	
	DocumentDate = ?(ValueIsFilled(Date), Date, CurrentSessionDate());
	
	While DataSelection.Next() Do
		
		NewLine = PaymentCalendar.Add();
		
		If DataSelection.Term = Enums.PaymentTerm.PaymentInAdvance Then
			NewLine.PaymentDate = DocumentDate - DataSelection.DuePeriod * 86400;
		Else
			NewLine.PaymentDate = DocumentDate + DataSelection.DuePeriod * 86400;
		EndIf;
		
		NewLine.PaymentPercentage = DataSelection.PaymentPercentage;
		NewLine.PaymentAmount = Round(TotalAmount * NewLine.PaymentPercentage / 100, 2, RoundMode.Round15as20);
		NewLine.PaymentVATAmount = Round(TotalVAT * NewLine.PaymentPercentage / 100, 2, RoundMode.Round15as20);
		
		TotalAmountForCorrectBalance = TotalAmountForCorrectBalance + NewLine.PaymentAmount;
		TotalVATForCorrectBalance = TotalVATForCorrectBalance + NewLine.PaymentVATAmount;
		
	EndDo;
	
	// correct balance
	NewLine.PaymentAmount = NewLine.PaymentAmount + (TotalAmount - TotalAmountForCorrectBalance);
	NewLine.PaymentVATAmount = NewLine.PaymentVATAmount + (TotalVAT - TotalVATForCorrectBalance);
	
	SetPaymentTerms = True;
	CashAssetsType = CommonUse.ObjectAttributeValue(Contract, "PaymentMethod");
	
	If CashAssetsType = Enums.CashAssetTypes.Noncash Then
		BankAccountByDefault = CommonUse.ObjectAttributeValue(Company, "BankAccountByDefault");
		If ValueIsFilled(BankAccountByDefault) Then
			BankAccount = BankAccountByDefault;
		EndIf;
	ElsIf CashAssetsType = Enums.CashAssetTypes.Cash Then
		PettyCashByDefault = CommonUse.ObjectAttributeValue(Company, "PettyCashByDefault");
		If ValueIsFilled(PettyCashByDefault) Then
			PettyCash = PettyCashByDefault;
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#EndIf