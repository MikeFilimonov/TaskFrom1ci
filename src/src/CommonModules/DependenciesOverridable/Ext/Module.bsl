
////////////////////////////////////////////////////////////////////////////////
// Subsystem "Subordination structure".
// 
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Creates document attribute array. 
// 
// Parameters: 
//  DocumentName - String - document name.
// 
// Returns: 
//  Array - document attribute description array. 
// 
Function ArrayAdditionalDocumentAttributes(DocumentName) Export
	
	AdditAttributesArray = New Array;
	
	// Perhaps specify not more 3 additional attributes for presentation formation
	If DocumentName = "ExpenseReport" Then
		
		AdditAttributesArray.Add("Employee");
		
	ElsIf DocumentName = "ObsoleteWorkOrder" Then
		
		AdditAttributesArray.Add("OperationKind");
		AdditAttributesArray.Add("State");
		
	ElsIf DocumentName = "ProductionOrder" Then
		
		AdditAttributesArray.Add("OperationKind");
		AdditAttributesArray.Add("OrderState");
		
	ElsIf DocumentName = "SalesOrder" Then
		
		AdditAttributesArray.Add("OperationKind");
		AdditAttributesArray.Add("OrderState");
		
	ElsIf DocumentName = "PurchaseOrder" Then
		
		AdditAttributesArray.Add("OperationKind");
		AdditAttributesArray.Add("OrderState");
		
	ElsIf DocumentName = "TransferAndPromotion" Then
		
		AdditAttributesArray.Add("OperationKind");
		
	ElsIf DocumentName = "AccountSalesFromConsignee" Then
		
		AdditAttributesArray.Add("Counterparty"); // Agent
		
	ElsIf DocumentName = "AccountSalesToConsignor" Then
		
		AdditAttributesArray.Add("Counterparty"); // Consignor
		
	ElsIf DocumentName = "ShiftClosure" Then
		
		AdditAttributesArray.Add("CashCR");
		
	ElsIf DocumentName = "InventoryTransfer" Then
		
		AdditAttributesArray.Add("OperationKind");
		
	ElsIf DocumentName = "IntraWarehouseTransfer" Then
		
		AdditAttributesArray.Add("OperationKind");
		
	ElsIf DocumentName = "PayrollSheet" Then
		
		AdditAttributesArray.Add("OperationKind");
		
	ElsIf DocumentName = "CashReceipt" Then
		
		AdditAttributesArray.Add("OperationKind");
		AdditAttributesArray.Add("PettyCash");
		
	ElsIf DocumentName = "PaymentReceipt" Then
		
		AdditAttributesArray.Add("OperationKind");
		AdditAttributesArray.Add("BankAccount");
		
	ElsIf DocumentName = "CashVoucher" Then
		
		AdditAttributesArray.Add("OperationKind");
		AdditAttributesArray.Add("PettyCash");
		
	ElsIf DocumentName = "PaymentExpense" Then
		
		AdditAttributesArray.Add("OperationKind");
		AdditAttributesArray.Add("BankAccount");
		
	ElsIf DocumentName = "Production" Then
		
		AdditAttributesArray.Add("OperationKind");
		
	ElsIf DocumentName = "ReconciliationStatement" Then
		
		AdditAttributesArray.Add("Status");
		
	ElsIf DocumentName = "JobSheet" Then
		
		AdditAttributesArray.Add("Performer");
		
	ElsIf DocumentName = "Event" Then
		
		AdditAttributesArray.Add("EventType");
		
	ElsIf DocumentName = "SalesSlip" Then
		
		AdditAttributesArray.Add("CashCR");
		
	ElsIf DocumentName = "ProductReturn" Then
		
		AdditAttributesArray.Add("CashCR");
		
	EndIf;
	
	Return AdditAttributesArray;
	
EndFunction

// Receives document presentation for printing.
//
// Parameters:
//  Selection  - DataCollection - structure or selection from
//                 inquiry results in which additional attributes are
//                 contained on the basis of which
//                 it is possible to create the overridden document presentation for output in report "Subordination structure".
//
// Returns:
//   String, Undefined   - overridden document presentation
//                           or Undefined if for this document type such isn't set.
//
Function GetDocumentPresentationToPrint(Selection) Export
	
	DocumentPresentation = Selection.Presentation;
	If (Selection.DocumentAmount <> 0) 
		AND (Selection.DocumentAmount <> NULL) Then
		
		DocumentPresentation = DocumentPresentation + " " + NStr("en = 'to the amount of'") + " " + Selection.DocumentAmount;
		
		If ValueIsFilled(Selection.Currency) Then
			
			DocumentPresentation = DocumentPresentation + " " + Selection.Currency;
			
		ElsIf TypeOf(Selection.Ref) = Type("DocumentRef.Stocktaking")
			OR TypeOf(Selection.Ref) = Type("DocumentRef.InventoryIncrease")
			OR TypeOf(Selection.Ref) = Type("DocumentRef.OtherExpenses")
			OR TypeOf(Selection.Ref) = Type("DocumentRef.InventoryWriteOff") Then
			
			DocumentPresentation = DocumentPresentation + " " + Constants.PresentationCurrency.Get();
			
		ElsIf TypeOf(Selection.Ref) = Type("DocumentRef.ObsoleteWorkOrder") Then
			
			If ValueIsFilled(Selection.Ref.PriceKind) Then
				
				DocumentPresentation = DocumentPresentation + " " + Selection.Ref.PriceKind.PriceCurrency;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	For IndexOfAdditionalAttribute = 1 To 3 Do
		
		AdditionalValue = Selection["AdditionalAttribute" + String(IndexOfAdditionalAttribute)];
		
		If ValueIsFilled(AdditionalValue) Then
			
			DocumentPresentation = DocumentPresentation + ", " + TrimAll(AdditionalValue);
			
		EndIf;
		
	EndDo;
	
	Return DocumentPresentation;
	
EndFunction

// Returns document attribute name in which info about Amount and Currency of the document
// is contained for output in the subordination structure.
// Default attributes Currency and DocumentAmount are used. If for particular document or configuration in
// overall other
// attributes are used that it is possible to override values default in this function.
//
// Parameters:
//  DocumentName  - String - document name for which it is necessary to receive attribute name.
//  Attribute      - String - String, it can take the "Currency" and "DocumentAmount" values.
//
// Returns:
//   String   - Attribute name of the document containing the information on Currency or Amount.
//
Function DocumentAttributeName(DocumentName, Attribute) Export
	
	
	
	Return Undefined;
	
EndFunction

#EndRegion
