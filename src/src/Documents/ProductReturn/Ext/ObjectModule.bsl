#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions

// The procedure of filling in the document on the basis of cash payment voucher.
//
// Parameters:
// BasisDocument - DocumentRef.ApplicationForCashExpense - Application
// for payment FillingData - Structure - Document filling data
//	
Procedure FillBySalesSlip(Val BasisDocument, FillingData)
	
	// Fill document header data.
	QueryText = 
	"SELECT
	|	SalesSlip.DocumentCurrency AS DocumentCurrency,
	|	SalesSlip.Ref AS SalesSlip,
	|	SalesSlip.PriceKind AS PriceKind,
	|	SalesSlip.DiscountMarkupKind AS DiscountMarkupKind,
	|	SalesSlip.Company AS Company,
	|	SalesSlip.VATTaxation AS VATTaxation,
	|	SalesSlip.CashCR AS CashCR,
	|	SalesSlip.CashCRSession AS CashCRSession,
	|	SalesSlip.StructuralUnit AS StructuralUnit,
	|	SalesSlip.Department AS Department,
	|	SalesSlip.Responsible AS Responsible,
	|	SalesSlip.DocumentAmount AS DocumentAmount,
	|	SalesSlip.AmountIncludesVAT AS AmountIncludesVAT,
	|	SalesSlip.IncludeVATInPrice AS IncludeVATInPrice,
	|	SalesSlip.POSTerminal AS POSTerminal,
	|	SalesSlip.DiscountCard AS DiscountCard,
	|	SalesSlip.DiscountPercentByDiscountCard AS DiscountPercentByDiscountCard,
	|	SalesSlip.Inventory.(
	|		Products AS Products,
	|		Characteristic AS Characteristic,
	|		Batch AS Batch,
	|		Quantity AS Quantity,
	|		MeasurementUnit AS MeasurementUnit,
	|		Price AS Price,
	|		DiscountMarkupPercent AS DiscountMarkupPercent,
	|		Amount AS Amount,
	|		VATRate AS VATRate,
	|		VATAmount AS VATAmount,
	|		Total AS Total,
	|		AutomaticDiscountsPercent AS AutomaticDiscountsPercent,
	|		AutomaticDiscountAmount AS AutomaticDiscountAmount,
	|		ConnectionKey AS ConnectionKey,
	|		SerialNumbers AS SerialNumbers,
	|		RevenueGLAccount AS RevenueGLAccount,
	|		VATOutputGLAccount AS VATOutputGLAccount
	|	) AS Inventory,
	|	SalesSlip.PaymentWithPaymentCards.(
	|		ChargeCardKind AS ChargeCardKind,
	|		ChargeCardNo AS ChargeCardNo,
	|		Amount AS Amount,
	|		RefNo AS RefNo,
	|		ETReceiptNo AS ETReceiptNo
	|	) AS PaymentWithPaymentCards,
	|	SalesSlip.SalesSlipNumber AS SalesSlipNumber,
	|	SalesSlip.Posted AS Posted,
	|	SalesSlip.DiscountsMarkups.(
	|		Ref AS Ref,
	|		LineNumber AS LineNumber,
	|		ConnectionKey AS ConnectionKey,
	|		DiscountMarkup AS DiscountMarkup,
	|		Amount AS Amount
	|	) AS DiscountsMarkups,
	|	SalesSlip.DiscountsAreCalculated AS DiscountsAreCalculated
	|FROM
	|	Document.SalesSlip AS SalesSlip
	|WHERE
	|	SalesSlip.Ref = &Ref";
	
	Query = New Query;
	Query.Text = QueryText;
	Query.SetParameter("Ref", BasisDocument);
	
	Selection = Query.Execute().Select();
	Selection.Next();
	FillPropertyValues(ThisObject, Selection, ,"SalesSlipNumber, Posted");
	
	ErrorText = "";
	
	If Not Documents.ShiftClosure.SessionIsOpen(Selection.CashCRSession, CurrentDate(), ErrorText) Then
		
		ErrorText = ErrorText + NStr("en = 'Please close the shift and register the product return with a supplier invoice.'");
		
		Raise ErrorText;
		
	EndIf;
	
	If Not Selection.Posted Then
		
		ErrorText = NStr("en = 'Please select a posted sales slip.'");
		
		Raise ErrorText;
		
	EndIf;
	
	If Not ValueIsFilled(Selection.SalesSlipNumber) Then
		
		ErrorText = NStr("en = 'Please select an issued sales slip.'");
	
		Raise ErrorText;
		
	EndIf;
	
	Inventory.Load(Selection.Inventory.Unload());
	PaymentWithPaymentCards.Load(Selection.PaymentWithPaymentCards.Unload());
	
	WorkWithSerialNumbers.FillTSSerialNumbersByConnectionKey(ThisObject, FillingData);
	
	// AutomaticDiscounts
	If GetFunctionalOption("UseAutomaticDiscounts") Then
		DiscountsMarkups.Load(Selection.DiscountsMarkups.Unload());
	EndIf;
	// End AutomaticDiscounts
	
EndProcedure

// Adds additional attributes necessary for document
// posting to passed structure.
//
// Parameters:
//  StructureAdditionalProperties - Structure of additional document properties.
//
Procedure AddAttributesToAdditionalPropertiesForPosting(StructureAdditionalProperties)
	
	StructureAdditionalProperties.ForPosting.Insert("CheckIssued", ValueIsFilled(SalesSlipNumber));
	StructureAdditionalProperties.ForPosting.Insert("Archival", Archival);
	
EndProcedure

#EndRegion

#Region EventsHandlers

// Procedure - event handler "On copy".
//
Procedure OnCopy(CopiedObject)
	
	Raise NStr("en = 'Please generate a product return from a sales slip.'");
	
EndProcedure

// Procedure - event handler "FillingProcessor".
//
Procedure Filling(FillingData, StandardProcessing)
	
	DataTypeFill = TypeOf(FillingData);
	
	If TypeOf(FillingData) = Type("DocumentRef.SalesSlip") Then
		
		FillBySalesSlip(FillingData, FillingData);
		
	Else
		
		Raise NStr("en = 'Please generate a product return from a sales slip.'");
		
	EndIf;
	
	WorkWithVAT.ForbidReverseChargeTaxationTypeDocumentGeneration(ThisObject);
	
EndProcedure

// Procedure - event handler "Filling check processor".
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	Query = New Query;
	Query.Text = 
	"SELECT TOP 1
	|	ProductReturn.Ref
	|FROM
	|	Document.ProductReturn AS ProductReturn
	|WHERE
	|	ProductReturn.Ref <> &Ref
	|	AND ProductReturn.Posted
	|	AND ProductReturn.SalesSlip = &SalesSlip
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SalesSlip.CashCRSession AS CashCRSession,
	|	SalesSlip.Date AS Date,
	|	SalesSlip.Posted AS Posted,
	|	SalesSlip.SalesSlipNumber AS SalesSlipNumber
	|FROM
	|	Document.SalesSlip AS SalesSlip
	|WHERE
	|	SalesSlip.Ref = &SalesSlip";
	
	Query.SetParameter("SalesSlip", SalesSlip);
	Query.SetParameter("Ref", Ref);
	
	Result = Query.ExecuteBatch();
	Selection = Result[0].Select();
	
	While Selection.Next() Do
		
		ErrorText = NStr("en = 'Product return has already been entered for this receipt'");
		
		DriveServer.ShowMessageAboutError(
			ThisObject,
			ErrorText,
			Undefined,
			Undefined,
			"SalesSlip",
			Cancel
		); 
		
	EndDo;
	
	Selection = Result[1].Select();
	
	While Selection.Next() Do
		
		If BegOfDay(Selection.Date) <> BegOfDay(Date) Then
			
			ErrorText = NStr("en = 'Product return date should correspond to sales receipt date'");
			
			DriveServer.ShowMessageAboutError(
				ThisObject,
				ErrorText,
				Undefined,
				Undefined,
				"Date",
				Cancel
			); 

		EndIf;
		
		If CashCRSession <> Selection.CashCRSession Then
			
			ErrorText = NStr("en = 'Product return register shift should correspond to sale receipt register shift'");
			
			DriveServer.ShowMessageAboutError(
				ThisObject,
				ErrorText,
				Undefined,
				Undefined,
				"CashCRSession",
				Cancel
			); 

		EndIf;
		
		If Not Selection.Posted Then
			
			ErrorText = NStr("en = 'Cash receipt is not posted'");
			
			DriveServer.ShowMessageAboutError(
				ThisObject,
				ErrorText,
				Undefined,
				Undefined,
				"SalesSlip",
				Cancel
			); 

		EndIf;
		
		If Not ValueIsFilled(Selection.SalesSlipNumber) Then
			
			ErrorText = NStr("en = 'Cash receipt of a sale is not issued'");
			
			DriveServer.ShowMessageAboutError(
				ThisObject,
				ErrorText,
				Undefined,
				Undefined,
				"SalesSlip",
				Cancel
			);
			
		EndIf;
		
		ErrorText = NStr("en = 'Register shift is not opened'");
		If Not Documents.ShiftClosure.SessionIsOpen(CashCRSession, Date, ErrorText) Then
			
			
			DriveServer.ShowMessageAboutError(
				ThisObject,
				ErrorText,
				Undefined,
				Undefined,
				"CashCRSession",
				Cancel
			);

		EndIf;
		
	EndDo;
	
	If PaymentWithPaymentCards.Count() > 0 AND Not ValueIsFilled(POSTerminal) Then
		
		ErrorText = NStr("en = 'The ""POS terminal"" field is not filled in'");
		
		DriveServer.ShowMessageAboutError(
			ThisObject,
			ErrorText,
			Undefined,
			Undefined,
			"POSTerminal",
			Cancel
		);
		
	EndIf;
	
	// Serial numbers
	WorkWithSerialNumbers.FillCheckingSerialNumbers(Cancel, Inventory, SerialNumbers, StructuralUnit, ThisObject);
	
EndProcedure

// Procedure - event handler "BeforeWrite".
//
Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If ValueIsFilled(SalesSlipNumber)
	   AND WriteMode = DocumentWriteMode.UndoPosting
	   AND Not CashCR.UseWithoutEquipmentConnection Then
		
		Cancel = True;
		
		ErrorText = NStr("en = 'Cash receipt for return is issued on the fiscal data recorder. Cannot cancel posting'");
		
		CommonUseClientServer.MessageToUser(
			ErrorText,
			ThisObject);
			
		Return;
		
	EndIf;
	
	If WriteMode = DocumentWriteMode.UndoPosting
	   AND CashCR.UseWithoutEquipmentConnection
	   AND CashCRSession.Posted
	   AND CashCRSession.CashCRSessionStatus = Enums.ShiftClosureStatus.Closed Then
		
		MessageText = NStr("en = 'Register shift is closed. Cannot cancel posting'");
		
		DriveServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				,
				,
				,
				Cancel
			);
		
		Return;
		
	EndIf;
	
	AdditionalProperties.Insert("IsNew",    IsNew());
	AdditionalProperties.Insert("WriteMode", WriteMode);
	
EndProcedure

// Procedure - event handler "Posting".
//
Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting.
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	AddAttributesToAdditionalPropertiesForPosting(AdditionalProperties);
	
	// Document data initialization.
	Documents.ProductReturn.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Preparation of records sets.
	DriveServer.PrepareRecordSetsForRecording(ThisObject);

	DriveServer.ReflectInventoryInWarehouses(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectCashAssetsInCashRegisters(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectIncomeAndExpenses(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectSales(AdditionalProperties, RegisterRecords, Cancel);
	
	// DiscountCards
	DriveServer.ReflectSalesByDiscountCard(AdditionalProperties, RegisterRecords, Cancel);
	
	// AutomaticDiscounts
	DriveServer.FlipAutomaticDiscountsApplied(AdditionalProperties, RegisterRecords, Cancel);
	
	DriveServer.ReflectAccountingJournalEntries(AdditionalProperties, RegisterRecords, Cancel);
	
	// SerialNumbers
	DriveServer.ReflectTheSerialNumbersOfTheGuarantee(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectTheSerialNumbersBalance(AdditionalProperties, RegisterRecords, Cancel);
	
	// Record of the records sets.
	DriveServer.WriteRecordSets(ThisObject);
	
	// Control of occurrence of a negative balance.
	Documents.ProductReturn.RunControl(Ref, AdditionalProperties, Cancel);

	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
EndProcedure

// Procedure - event handler "UndoPosting".
//
Procedure UndoPosting(Cancel)
	
	// Initialization of additional properties for document posting
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Preparation of record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Writing of record sets
	DriveServer.WriteRecordSets(ThisObject);
	
	// Control of occurrence of a negative balance.
	Documents.ProductReturn.RunControl(Ref, AdditionalProperties, Cancel, True);
	
EndProcedure

#EndRegion

#EndIf