
#Region Public

Function GetGLAccountsStructure(StructureData) Export

	ObjectParameters = StructureData.ObjectParameters;
	GLAccountsForFilling = New Structure;
	
	If TypeOf(ObjectParameters.Ref) = Type("DocumentRef.AccountSalesFromConsignee") Then
		
		GLAccountsForFilling.Insert("InventoryTransferredGLAccount",	StructureData.InventoryTransferredGLAccount);
		GLAccountsForFilling.Insert("VATOutputGLAccount",				StructureData.VATOutputGLAccount);
		GLAccountsForFilling.Insert("RevenueGLAccount",					StructureData.RevenueGLAccount);
		GLAccountsForFilling.Insert("COGSGLAccount",					StructureData.COGSGLAccount);
		
	ElsIf TypeOf(ObjectParameters.Ref) = Type("DocumentRef.AdditionalExpenses") Then
	
		If StructureData.TabName = "Inventory" Then
			GLAccountsForFilling.Insert("InventoryGLAccount", StructureData.InventoryGLAccount);
		ElsIf StructureData.TabName = "Expenses" Then
			GLAccountsForFilling.Insert("VATInputGLAccount", StructureData.VATInputGLAccount);
		EndIf;
		
	ElsIf TypeOf(ObjectParameters.Ref) = Type("DocumentRef.CostAllocation") Then
	
		GLAccountsForFilling.Insert("ConsumptionGLAccount", StructureData.ConsumptionGLAccount);
		
	ElsIf TypeOf(ObjectParameters.Ref) = Type("DocumentRef.CustomsDeclaration") Then
	
		GLAccountsForFilling.Insert("InventoryGLAccount", StructureData.InventoryGLAccount);
		GLAccountsForFilling.Insert("VATInputGLAccount", StructureData.VATInputGLAccount);
		
		If ObjectParameters.VATIsDue = PredefinedValue("Enum.VATDueOnCustomsClearance.InTheVATReturn") Then
			GLAccountsForFilling.Insert("VATOutputGLAccount", StructureData.VATOutputGLAccount);
		EndIf;
		
	ElsIf TypeOf(ObjectParameters.Ref) = Type("DocumentRef.CreditNote") Then
		
		GLAccountsForFilling = New Structure("InventoryGLAccount, VATOutputGLAccount, COGSGLAccount, SalesReturnGLAccount");
		FillPropertyValues(GLAccountsForFilling, StructureData); 
		
	ElsIf TypeOf(ObjectParameters.Ref) = Type("DocumentRef.DebitNote") Then
		
		GLAccountsForFilling = New Structure("InventoryGLAccount, VATInputGLAccount, PurchaseReturnGLAccount");
		FillPropertyValues(GLAccountsForFilling, StructureData);
		
	ElsIf TypeOf(ObjectParameters.Ref) = Type("DocumentRef.GoodsIssue") Then
		
		GLAccountsForFilling.Insert("InventoryGLAccount", StructureData.InventoryGLAccount);
		
		If ObjectParameters.OperationType = PredefinedValue("Enum.OperationTypesGoodsIssue.SaleToCustomer") Then
			If ValueIsFilled(StructureData.SalesInvoice) Then
				GLAccountsForFilling.Insert("UnearnedRevenueGLAccount",	StructureData.UnearnedRevenueGLAccount);
				GLAccountsForFilling.Insert("RevenueGLAccount",			StructureData.RevenueGLAccount);
				GLAccountsForFilling.Insert("COGSGLAccount",			StructureData.COGSGLAccount);
			Else
				GLAccountsForFilling.Insert("GoodsShippedNotInvoicedGLAccount", StructureData.GoodsShippedNotInvoicedGLAccount);
			EndIf;
		ElsIf ObjectParameters.OperationType = PredefinedValue("Enum.OperationTypesGoodsIssue.TransferToAThirdParty") Then
			GLAccountsForFilling.Insert("InventoryTransferredGLAccount", StructureData.InventoryTransferredGLAccount);
		ElsIf ObjectParameters.OperationType = PredefinedValue("Enum.OperationTypesGoodsIssue.ReturnToAThirdParty") Then
			GLAccountsForFilling.Insert("InventoryReceivedGLAccount", StructureData.InventoryReceivedGLAccount);
		EndIf;
		
	ElsIf TypeOf(ObjectParameters.Ref) = Type("DocumentRef.GoodsReceipt") Then
		
		If ObjectParameters.OperationType = PredefinedValue("Enum.OperationTypesGoodsReceipt.PurchaseFromSupplier") Then
			
			GLAccountsForFilling.Insert("InventoryGLAccount", StructureData.InventoryGLAccount);
			
			If ValueIsFilled(StructureData.SupplierInvoice) Then
				GLAccountsForFilling.Insert("GoodsInvoicedNotDeliveredGLAccount", StructureData.GoodsInvoicedNotDeliveredGLAccount);
			Else
				GLAccountsForFilling.Insert("GoodsReceivedNotInvoicedGLAccount", StructureData.GoodsReceivedNotInvoicedGLAccount);
			EndIf;
		ElsIf ObjectParameters.OperationType = PredefinedValue("Enum.OperationTypesGoodsReceipt.ReturnFromAThirdParty") Then
			
			GLAccountsForFilling.Insert("InventoryGLAccount", StructureData.InventoryGLAccount);
			GLAccountsForFilling.Insert("InventoryTransferredGLAccount", StructureData.InventoryTransferredGLAccount);
			
		ElsIf ObjectParameters.OperationType = PredefinedValue("Enum.OperationTypesGoodsReceipt.ReceiptFromAThirdParty") Then
			GLAccountsForFilling.Insert("InventoryReceivedGLAccount", StructureData.InventoryReceivedGLAccount);
		EndIf;
		
	ElsIf TypeOf(ObjectParameters.Ref) = Type("DocumentRef.InventoryIncrease")
		Or TypeOf(ObjectParameters.Ref) = Type("DocumentRef.InventoryReservation")
		Or TypeOf(ObjectParameters.Ref) = Type("DocumentRef.InventoryWriteOff")
		Or TypeOf(ObjectParameters.Ref) = Type("DocumentRef.FixedAssetRecognition")
		Or TypeOf(ObjectParameters.Ref) = Type("DocumentRef.OpeningBalanceEntry")
		Or TypeOf(ObjectParameters.Ref) = Type("DocumentRef.SalesOrder") Then
		
		GLAccountsForFilling.Insert("InventoryGLAccount", StructureData.InventoryGLAccount);
				
	ElsIf TypeOf(ObjectParameters.Ref) = Type("DocumentRef.ProductReturn")
		Or TypeOf(ObjectParameters.Ref) = Type("DocumentRef.SalesSlip") Then
		
		GLAccountsForFilling.Insert("VATOutputGLAccount", StructureData.VATOutputGLAccount);
		GLAccountsForFilling.Insert("RevenueGLAccount", StructureData.RevenueGLAccount);
		
	ElsIf TypeOf(ObjectParameters.Ref) = Type("DocumentRef.ShiftClosure") Then
		
		GLAccountsForFilling.Insert("InventoryGLAccount", StructureData.InventoryGLAccount);
		GLAccountsForFilling.Insert("COGSGLAccount", StructureData.COGSGLAccount);
		GLAccountsForFilling.Insert("VATOutputGLAccount", StructureData.VATOutputGLAccount);
		GLAccountsForFilling.Insert("RevenueGLAccount", StructureData.RevenueGLAccount);
		
	ElsIf TypeOf(ObjectParameters.Ref) = Type("DocumentRef.SubcontractorReport") Then
		
		If StructureData.TabName = "Disposals" Then
			GLAccountsForFilling.Insert("InventoryGLAccount", StructureData.InventoryGLAccount);
		ElsIf StructureData.TabName = "Product" Then
			
			If ObjectParameters.StructuralUnitType = PredefinedValue("Enum.BusinessUnitsTypes.Department") Then
				GLAccountsForFilling.Insert("ConsumptionGLAccount", StructureData.ConsumptionGLAccount);
			Else
				GLAccountsForFilling.Insert("InventoryGLAccount", StructureData.InventoryGLAccount);
			EndIf;
			
		ElsIf StructureData.TabName = "Inventory" Then
			GLAccountsForFilling.Insert("InventoryTransferredGLAccount", StructureData.InventoryTransferredGLAccount);
		ElsIf StructureData.TabName = "SubcontractorFees" Then
			GLAccountsForFilling.Insert("VATInputGLAccount", StructureData.VATInputGLAccount);
		EndIf;
		
	ElsIf TypeOf(ObjectParameters.Ref) = Type("DocumentRef.SupplierInvoice") Then
		
		If StructureData.TabName = "Inventory"
			And ValueIsFilled(StructureData.GoodsReceipt) Then
			GLAccountsForFilling.Insert("InventoryGLAccount", StructureData.InventoryGLAccount);
			GLAccountsForFilling.Insert("GoodsReceivedNotInvoicedGLAccount", StructureData.GoodsReceivedNotInvoicedGLAccount);
		ElsIf StructureData.TabName = "Inventory"
			And ObjectParameters.AdvanceInvoicing Then
			GLAccountsForFilling.Insert("GoodsInvoicedNotDeliveredGLAccount", StructureData.GoodsInvoicedNotDeliveredGLAccount);
		Else
			GLAccountsForFilling.Insert("InventoryGLAccount", StructureData.InventoryGLAccount);
		EndIf;
		
		If ObjectParameters.VATTaxation <> PredefinedValue("Enum.VATTaxationTypes.NotSubjectToVAT") Then
			GLAccountsForFilling.Insert("VATInputGLAccount", StructureData.VATInputGLAccount);
		EndIf;
		
		If ObjectParameters.VATTaxation = PredefinedValue("Enum.VATTaxationTypes.ReverseChargeVAT") Then
			GLAccountsForFilling.Insert("VATOutputGLAccount", StructureData.VATOutputGLAccount);
		EndIf;
		
	EndIf;
	
	Return GLAccountsForFilling;

EndFunction

Function GetObjectParameters(Val FormObject) Export

	ObjectParameters = New Structure;
	If FormObject.Property("Ref") Then
		ObjectParameters.Insert("Ref", FormObject.Ref);
	EndIf;
	
	If FormObject.Property("Company") Then
		ObjectParameters.Insert("Company", FormObject.Company);
	EndIf;
	
	If FormObject.Property("Date") Then
		ObjectParameters.Insert("Date", FormObject.Date);
	EndIf;
	
	If FormObject.Property("InventoryGLAccount") Then
		ObjectParameters.Insert("InventoryGLAccount", FormObject.InventoryGLAccount);
	EndIf;
	
	If FormObject.Property("Products") Then
		ObjectParameters.Insert("Products", FormObject.Products);
	EndIf;
	
	If FormObject.Property("StructuralUnitReserve") Then
		ObjectParameters.Insert("StructuralUnit", FormObject.StructuralUnitReserve);
	EndIf;
	
	If FormObject.Property("StructuralUnit") Then
		ObjectParameters.Insert("StructuralUnit", FormObject.StructuralUnit);
	EndIf;
	
	If FormObject.Property("StructuralUnitPayee") Then
		ObjectParameters.Insert("StructuralUnitPayee", FormObject.StructuralUnitPayee);
	EndIf;
	
	If FormObject.Property("OperationKind") Then
		ObjectParameters.Insert("OperationKind", FormObject.OperationKind);
	EndIf;
	
	If FormObject.Property("OperationType") Then
		ObjectParameters.Insert("OperationType", FormObject.OperationType);
	EndIf;
	
	If FormObject.Property("AdvanceInvoicing") Then
		ObjectParameters.Insert("AdvanceInvoicing", FormObject.AdvanceInvoicing);
	EndIf;
	
	If FormObject.Property("VATIsDue") Then
		ObjectParameters.Insert("VATIsDue", FormObject.VATIsDue);
	EndIf;
	
	If FormObject.Property("VATTaxation") Then
		ObjectParameters.Insert("VATTaxation", FormObject.VATTaxation);
	EndIf;
	
	Return ObjectParameters;
	
EndFunction

Function GetEmptyGLAccountPresentation() Export

	Return "<...>";

EndFunction

Procedure FillProductGLAccountsDescription(StructureData, GLAccountsForFilling = Undefined) Export

	If GLAccountsForFilling = Undefined Then
		GLAccountsForFilling = GLAccountsInDocumentsClientServer.GetGLAccountsStructure(StructureData);
	EndIf;
	
	GLAccountsDescription = GLAccountsInDocumentsServerCall.GetGLAccountsDescription(GLAccountsForFilling);
	FillPropertyValues(StructureData, GLAccountsDescription);
	
EndProcedure

Procedure FillGLAccountsInStructure(StructureForFilling, GLAccounts, GetGLAccounts) Export
	
	If GetGLAccounts Then
		GLAccountsInDocumentsServerCall.FillProductGLAccounts(StructureForFilling, GLAccounts);
	Else
		FillProductGLAccountsDescription(StructureForFilling);
	EndIf;
	
EndProcedure

#EndRegion
