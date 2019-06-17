#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions

// Initializes the document receipt CR.
//
Procedure InitializeDocument()
	
	POSTerminal = Catalogs.POSTerminals.GetPOSTerminalByDefault(CashCR);
	
EndProcedure

// Fills document Receipt CR by cash register.
//
// Parameters
//  FillingData - Structure with the filter values
//
Procedure FillDocumentByCachRegister(CashCR)
	
	StatusCashCRSession = Documents.ShiftClosure.GetCashCRSessionStatus(CashCR);
	FillPropertyValues(ThisObject, StatusCashCRSession);
	
EndProcedure

// Fills document CR receipt in compliance with filter.
//
// Parameters
//  FillingData - Structure with the filter values
//
Procedure FillDocumentByFilter(FillingData)
	
	If FillingData.Property("CashCR") Then
		
		FillDocumentByCachRegister(FillingData.CashCR);
		
	EndIf;
	
EndProcedure

// Adds additional attributes necessary for document
// posting to passed structure.
//
// Parameters:
//  StructureAdditionalProperties - Structure of additional document properties.
//
Procedure AddAttributesToAdditionalPropertiesForPosting(StructureAdditionalProperties)
	
	StructureAdditionalProperties.ForPosting.Insert("CheckIssued", Status = Enums.SalesSlipStatus.Issued);
	StructureAdditionalProperties.ForPosting.Insert("ProductReserved", Status = Enums.SalesSlipStatus.ProductReserved);
	StructureAdditionalProperties.ForPosting.Insert("Archival", Archival);
	
EndProcedure

#EndRegion

#Region EventHandlers

// Procedure - handler of the OnCopy event.
//
Procedure OnCopy(CopiedObject)
	
	SalesSlipNumber = "";
	Archival = False;
	Status = Enums.SalesSlipStatus.ReceiptIsNotIssued;
	
	CashReceived = 0;
	PaymentWithPaymentCards.Clear();
		
	StatusCashCRSession = Documents.ShiftClosure.GetCashCRSessionStatus(CashCR);
	FillPropertyValues(ThisObject, StatusCashCRSession);
	
	InitializeDocument();
	
EndProcedure

// Procedure - FillCheckProcessing event handler.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If PaymentWithPaymentCards.Count() > 0 AND Not ValueIsFilled(POSTerminal) Then
		
		MessageText = NStr("en = 'The ""POS terminal"" field is not filled in'");

		DriveServer.ShowMessageAboutError(
			ThisObject,
			MessageText,
			,
			,
			"POSTerminal",
			Cancel
		);
		
	EndIf;
	
	If PaymentWithPaymentCards.Total("Amount") > DocumentAmount Then
		
		MessageText = NStr("en = 'Card payment amount is greater than the document amount'");
		
		DriveServer.ShowMessageAboutError(
			ThisObject,
			MessageText,
			,
			,
			"PaymentWithPaymentCards",
			Cancel
		);

	EndIf;
	
	MessageText = NStr("en = 'Register shift is not opened'");
	
	If Not Documents.ShiftClosure.SessionIsOpen(CashCRSession, Date, MessageText) Then
		
		DriveServer.ShowMessageAboutError(
			ThisObject,
			MessageText,
			,
			,
			"CashCRSession",
			Cancel
		);

	EndIf;
	
	// Serial numbers
	WorkWithSerialNumbers.FillCheckingSerialNumbers(Cancel, Inventory, SerialNumbers, StructuralUnit, ThisObject);
	
EndProcedure

// Procedure - handler of the FillingProcessor event.
//
Procedure Filling(FillingData, StandardProcessing)
	
	DataTypeFill = TypeOf(FillingData);
	
	If DataTypeFill = Type("Structure") Then
		
		FillDocumentByFilter(FillingData);
		
	Else
		
		CashCR = Catalogs.CashRegisters.GetCashCRByDefault();
		If CashCR <> Undefined Then
			FillDocumentByCachRegister(CashCR);
		EndIf;
		
	EndIf;
	
	InitializeDocument();
	
	WorkWithVAT.ForbidReverseChargeTaxationTypeDocumentGeneration(ThisObject);
	
EndProcedure

// Procedure - BeforeWrite event handler.
//
Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Status = Enums.SalesSlipStatus.Issued
	   AND WriteMode = DocumentWriteMode.UndoPosting
	   AND Not CashCR.UseWithoutEquipmentConnection Then
		
		MessageText = NStr("en = 'Cash receipt was issued on the fiscal data recorder. Cannot cancel posting'");
		
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
	
	If WriteMode = DocumentWriteMode.UndoPosting Then
		SalesSlipNumber = 0;
		Status = Undefined;
	EndIf;
	
	AdditionalProperties.Insert("IsNew", IsNew());
	AdditionalProperties.Insert("WriteMode", WriteMode);
	
EndProcedure

// Procedure - event handler Posting().
//
Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting.
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	AddAttributesToAdditionalPropertiesForPosting(AdditionalProperties);
	
	// Document data initialization.
	Documents.SalesSlip.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Preparation of records sets.
	DriveServer.PrepareRecordSetsForRecording(ThisObject);

	DriveServer.ReflectInventoryInWarehouses(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectCashAssetsInCashRegisters(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectIncomeAndExpenses(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectSales(AdditionalProperties, RegisterRecords, Cancel);
	
	DriveServer.ReflectAccountingJournalEntries(AdditionalProperties, RegisterRecords, Cancel);
	
	// DiscountCards
	DriveServer.ReflectSalesByDiscountCard(AdditionalProperties, RegisterRecords, Cancel);
	// AutomaticDiscounts
	DriveServer.FlipAutomaticDiscountsApplied(AdditionalProperties, RegisterRecords, Cancel);
	
	// SerialNumbers
	DriveServer.ReflectTheSerialNumbersOfTheGuarantee(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectTheSerialNumbersBalance(AdditionalProperties, RegisterRecords, Cancel);
	
	// Record of the records sets.
	DriveServer.WriteRecordSets(ThisObject);
	
	// Control of occurrence of a negative balance.
	Documents.SalesSlip.RunControl(Ref, AdditionalProperties, Cancel);
	
	DriveServer.CreateRecordsInTasksRegisters(ThisObject, Cancel);
	
	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
EndProcedure

// Procedure - event handler UndoPosting object.
//
Procedure UndoPosting(Cancel)
	
	// Initialization of additional properties for document posting
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Preparation of record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Writing of record sets
	DriveServer.WriteRecordSets(ThisObject);
	
	// Control of occurrence of a negative balance.
	Documents.SalesSlip.RunControl(Ref, AdditionalProperties, Cancel, True);
	
	DriveServer.CreateRecordsInTasksRegisters(ThisObject, Cancel);
	
EndProcedure

#EndRegion

#EndIf
