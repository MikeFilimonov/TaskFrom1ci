#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	InvTotals = GetInventoryTotalAmounts();
	DocumentAmount = InvTotals.Amount + InvTotals.VATAmount;
	
	If ValueIsFilled(Counterparty) Then
		CounterpartyData = CommonUse.ObjectAttributesValues(Counterparty, "DoOperationsByContracts, ContractByDefault");
		If Not CounterpartyData.DoOperationsByContracts And Not ValueIsFilled(Contract) Then
			Contract = Counterparty.ContractByDefault;
		EndIf;
	EndIf;
	
EndProcedure

Procedure Filling(FillingData, StandardProcessing) Export
	
	ObjectFillingDrive.FillDocument(ThisObject, FillingData, "FillingHandler");
	
EndProcedure

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	// 100% discount.
	AreManualDiscounts		= GetFunctionalOption("UseManualDiscounts");
	AreAutomaticDiscounts	= GetFunctionalOption("UseAutomaticDiscounts"); // AutomaticDiscounts
	If AreManualDiscounts OR AreAutomaticDiscounts Then
		For Each StringInventory In Inventory Do
			// AutomaticDiscounts
			CurAmount = StringInventory.Price * StringInventory.Quantity;
			CurAmountManualDiscount		= ?(AreManualDiscounts, Round(CurAmount * StringInventory.DiscountMarkupPercent / 100, 2), 0);
			CurAmountAutomaticDiscount	= ?(AreAutomaticDiscounts, StringInventory.AutomaticDiscountAmount, 0);
			CurAmountDiscount			= CurAmountManualDiscount + CurAmountAutomaticDiscount;
			If StringInventory.DiscountMarkupPercent <> 100 AND CurAmountDiscount < CurAmount
				AND Not ValueIsFilled(StringInventory.Amount) Then
				MessageText = NStr("en = 'The ""Amount"" column is not populated in the %Number% line of the ""Inventory"" list.'");
				MessageText = StrReplace(MessageText, "%Number%", StringInventory.LineNumber);
				DriveServer.ShowMessageAboutError(
					ThisObject,
					MessageText,
					"Inventory",
					StringInventory.LineNumber,
					"Amount",
					Cancel
				);
			EndIf;
		EndDo;
	EndIf;
	
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
	InvTotals = GetInventoryTotalAmounts();
	PaymentTermsServer.CheckCorrectPaymentCalendar(ThisObject, Cancel, InvTotals.Amount, InvTotals.VATAmount);
	
EndProcedure

Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting.
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Document data initialization.
	Documents.Quote.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Preparation of records sets.
	DriveServer.PrepareRecordSetsForRecording(ThisObject);

	DriveServer.ReflectTasksForUpdatingStatuses(Ref, Cancel);
	DriveServer.ReflectUsingPaymentTermsInDocuments(Ref, Cancel);
	DriveServer.ReflectQuotations(AdditionalProperties, RegisterRecords, Cancel);

	// Record of the records sets.
	DriveServer.WriteRecordSets(ThisObject);
	
	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
EndProcedure

Procedure UndoPosting(Cancel)
	
	DriveServer.ReflectTasksForUpdatingStatuses(Ref, Cancel);
	
EndProcedure

#EndRegion

#Region Private

Procedure FillingHandler(FillingData) Export
	
	If Not ValueIsFilled(FillingData) Or Not CommonUse.ReferenceTypeValue(FillingData) Then
		Return;
	EndIf;
	
EndProcedure

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
	
	InvTotals = GetInventoryTotalAmounts();
	
	DocumentDate = ?(ValueIsFilled(Date), Date, CurrentDate());
	
	While DataSelection.Next() Do
		
		NewLine = PaymentCalendar.Add();
		
		If DataSelection.Term = Enums.PaymentTerm.PaymentInAdvance Then
			NewLine.PaymentDate = DocumentDate - DataSelection.DuePeriod * 86400;
		Else
			NewLine.PaymentDate = DocumentDate + DataSelection.DuePeriod * 86400;
		EndIf;
		
		NewLine.PaymentPercentage = DataSelection.PaymentPercentage;
		NewLine.PaymentAmount = Round(InvTotals.Amount * NewLine.PaymentPercentage / 100, 2, RoundMode.Round15as20);
		NewLine.PaymentVATAmount = Round(InvTotals.VATAmount * NewLine.PaymentPercentage / 100, 2, RoundMode.Round15as20);
		
		TotalAmountForCorrectBalance = TotalAmountForCorrectBalance + NewLine.PaymentAmount;
		TotalVATForCorrectBalance = TotalVATForCorrectBalance + NewLine.PaymentVATAmount;
		
	EndDo;
	
	// correct balance
	NewLine.PaymentAmount = NewLine.PaymentAmount + (InvTotals.Amount - TotalAmountForCorrectBalance);
	NewLine.PaymentVATAmount = NewLine.PaymentVATAmount + (InvTotals.VATAmount - TotalVATForCorrectBalance);
	
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

Function GetInventoryTotalAmounts()
	
	If VariantsCount < 2 Then
		
		TotalAmount = Inventory.Total("Amount");
		TotalVAT = Inventory.Total("VATAmount");
		
	Else
		
		TotalAmount = 0;
		TotalVAT = 0;
		InvRows = Inventory.FindRows(New Structure("Variant", PreferredVariant));
		For Each InvRow In InvRows Do
			
			TotalAmount = TotalAmount + InvRow.Amount;
			TotalVAT = TotalVAT + InvRow.VATAmount;
			
		EndDo;
		
	EndIf;
	
	Return New Structure("Amount, VATAmount", TotalAmount, TotalVAT);
	
EndFunction

#EndRegion

#EndIf