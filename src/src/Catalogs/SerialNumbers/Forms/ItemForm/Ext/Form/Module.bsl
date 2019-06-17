
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If ValueIsFilled(Object.Owner) AND 
		NOT Object.Owner.UseSerialNumbers Then
	
		Message = New UserMessage();
		Message.Text = NStr("en = 'The product is not serialized.
		                    |Select the ""Use serial numbers"" check box in products card'");
		Message.Message();
		Cancel = True;
		
	EndIf;
	
	// StandardSubsystems.Properties
	PropertiesManagement.OnCreateAtServer(ThisForm, Object, "AdditionalAttributesPage");
	// End StandardSubsystems.Properties
	
	If ValueIsFilled(Object.Ref) Then
		Items.GroupFill.Visible = False;
	Else
		Items.GroupFill.Visible = True;
	EndIf;
	
	If Object.Sold Then
		GuaranteeData = Catalogs.SerialNumbers.GuaranteePeriod(Object.Ref, CurrentDate());
		If GuaranteeData.Count()>0 Then
			SaleInfo = ?(GuaranteeData.Guarantee, 
				String(GuaranteeData.DocumentSales)+", guarantee before"+GuaranteeData.GuaranteePeriod,
				String(GuaranteeData.DocumentSales));
			DocumentSales = GuaranteeData.DocumentSales;
		EndIf;
	EndIf;
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	// StandardSubsystems.Properties
	PropertiesManagement.OnReadAtServer(ThisForm, CurrentObject);
	// End StandardSubsystems.Properties
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	// StandardSubsystems.Properties
	PropertiesManagement.FillCheckProcessing(ThisForm, Cancel, CheckedAttributes);
	// End StandardSubsystems.Properties
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	// StandardSubsystems.Properties
	If PropertiesManagementClient.ProcessAlerts(ThisObject, EventName, Parameter) Then
		UpdateAdditionalAttributesItems();
	EndIf;
	// End StandardSubsystems.Properties
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject)
	
	// StandardSubsystems.Properties
	PropertiesManagement.BeforeWriteAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.Properties
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	If TrimAll(Object.Description)="" Then
	    Cancel = True;
		
		Message = New UserMessage();
		Message.Text = NStr("en = 'Serial number is not filled.'");
		Message.Message();
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
	AdditionalReportsAndDataProcessors.ExecuteAllocatedCommandAtServer(ThisObject, ItemName, ExecutionResult);
EndProcedure
// End StandardSubsystems.AdditionalReportsAndDataProcessors

// StandardSubsystems.Printing
&AtClient
Procedure Attachable_ExecutePrintCommand(Command)
	PrintManagementClient.ExecuteConnectedPrintCommand(Command, ThisObject, Object);
EndProcedure
// End StandardSubsystems.Printing

// StandardSubsystems.Properties

&AtClient
Procedure Attachable_EditContentOfProperties(Command)
	
	PropertiesManagementClient.EditContentOfProperties(ThisForm, Object.Ref);
	
EndProcedure

&AtServer
Procedure UpdateAdditionalAttributesItems()
	
	PropertiesManagement.UpdateAdditionalAttributesItems(ThisObject);
	
EndProcedure

// End StandardSubsystems.Properties

&AtServer
Procedure AddSerialNumberAtServer()
	
	Object.Description = WorkWithSerialNumbers.AddSerialNumber(Object.Owner, TemplateSerialNumber).NewNumber;
	
EndProcedure

&AtClient
Procedure AddSerialNumber(Command)
	
	AddSerialNumberAtServer();
	
EndProcedure

&AtClient
Procedure SaleInfoClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	If ValueIsFilled(DocumentSales) Then
		OpenDocumentFormByType(DocumentSales);
	EndIf;
	
EndProcedure

&AtClient
Procedure OpenDocumentFormByType(DocumentRef)
	
	FormNameString = GetDocumentNameByType(TypeOf(DocumentRef));
	OpenForm("Document."+FormNameString+".ObjectForm", New Structure("Key", DocumentRef), ThisObject);
	
EndProcedure

// Gets the document name by type at client without server call.
&AtClient
Function GetDocumentNameByType(DocumentType) Export
	
	TypesStructure = New Map;
	
	TypesStructure.Insert(Type("DocumentRef.AdditionalExpenses"),			"AdditionalExpenses");
	TypesStructure.Insert(Type("DocumentRef.AccountSalesFromConsignee"),	"AccountSalesFromConsignee");
	TypesStructure.Insert(Type("DocumentRef.Budget"),						"Budget");
	TypesStructure.Insert(Type("DocumentRef.BulkMail"),						"BulkMail");
	TypesStructure.Insert(Type("DocumentRef.ExpenditureRequest"),			"ExpenditureRequest");
	TypesStructure.Insert(Type("DocumentRef.CashVoucher"),					"CashVoucher");
	TypesStructure.Insert(Type("DocumentRef.CashReceipt"),					"CashReceipt");
	TypesStructure.Insert(Type("DocumentRef.CashTransfer"),					"CashTransfer");
	TypesStructure.Insert(Type("DocumentRef.CashTransferPlan"),				"CashTransferPlan");
	TypesStructure.Insert(Type("DocumentRef.CostAllocation"),				"CostAllocation");
	TypesStructure.Insert(Type("DocumentRef.TerminationOfEmployment"),		"TerminationOfEmployment");
	TypesStructure.Insert(Type("DocumentRef.TransferAndPromotion"),			"TransferAndPromotion");
	TypesStructure.Insert(Type("DocumentRef.EmploymentContract"),			"EmploymentContract");
	TypesStructure.Insert(Type("DocumentRef.OpeningBalanceEntry"),			"OpeningBalanceEntry");
	TypesStructure.Insert(Type("DocumentRef.Event"),						"Event");
	TypesStructure.Insert(Type("DocumentRef.ExpenseReport"),				"ExpenseReport");
	TypesStructure.Insert(Type("DocumentRef.FixedAssetsDepreciation"),		"FixedAssetsDepreciation");
	TypesStructure.Insert(Type("DocumentRef.FixedAssetRecognition"),		"FixedAssetRecognition");
	TypesStructure.Insert(Type("DocumentRef.FixedAssetDepreciationChanges"), "FixedAssetDepreciationChanges");
	TypesStructure.Insert(Type("DocumentRef.FixedAssetUsage"),				"FixedAssetUsage");
	TypesStructure.Insert(Type("DocumentRef.FixedAssetSale"),				"FixedAssetSale");
	TypesStructure.Insert(Type("DocumentRef.FixedAssetWriteOff"),			"FixedAssetWriteOff");
	TypesStructure.Insert(Type("DocumentRef.Production"),					"Production");
	TypesStructure.Insert(Type("DocumentRef.InventoryIncrease"),			"InventoryIncrease");
	TypesStructure.Insert(Type("DocumentRef.Stocktaking"),					"Stocktaking");
	TypesStructure.Insert(Type("DocumentRef.InventoryReservation"),			"InventoryReservation");
	TypesStructure.Insert(Type("DocumentRef.InventoryTransfer"),			"InventoryTransfer");
	TypesStructure.Insert(Type("DocumentRef.InventoryWriteOff"),			"InventoryWriteOff");
	TypesStructure.Insert(Type("DocumentRef.Quote"),						"Quote");
	TypesStructure.Insert(Type("DocumentRef.JobSheet"),						"JobSheet");
	TypesStructure.Insert(Type("DocumentRef.MonthEndClosing"),				"MonthEndClosing");
	TypesStructure.Insert(Type("DocumentRef.ArApAdjustments"),				"ArApAdjustments");
	TypesStructure.Insert(Type("DocumentRef.Operation"),					"Operation");
	TypesStructure.Insert(Type("DocumentRef.OtherExpenses"),				"OtherExpenses");
	TypesStructure.Insert(Type("DocumentRef.PaymentExpense"),				"PaymentExpense");
	TypesStructure.Insert(Type("DocumentRef.PaymentReceipt"),				"PaymentReceipt");
	TypesStructure.Insert(Type("DocumentRef.CashInflowForecast"),			"CashInflowForecast");
	TypesStructure.Insert(Type("DocumentRef.Payroll"),						"Payroll");
	TypesStructure.Insert(Type("DocumentRef.PayrollSheet"),					"PayrollSheet");
	TypesStructure.Insert(Type("DocumentRef.LetterOfAuthority"),			"LetterOfAuthority");
	TypesStructure.Insert(Type("DocumentRef.SubcontractorReportIssued"),	"SubcontractorReportIssued");
	TypesStructure.Insert(Type("DocumentRef.ProductionOrder"),				"ProductionOrder");
	TypesStructure.Insert(Type("DocumentRef.PurchaseOrder"),				"PurchaseOrder");
	TypesStructure.Insert(Type("DocumentRef.SalesSlip"),					"SalesSlip");
	TypesStructure.Insert(Type("DocumentRef.ProductReturn"),				"ProductReturn");
	TypesStructure.Insert(Type("DocumentRef.RegistersCorrection"),			"RegistersCorrection");
	TypesStructure.Insert(Type("DocumentRef.AccountSalesToConsignor"),		"AccountSalesToConsignor");
	TypesStructure.Insert(Type("DocumentRef.ShiftClosure"),					"ShiftClosure");
	TypesStructure.Insert(Type("DocumentRef.RetailRevaluation"),			"RetailRevaluation");
	TypesStructure.Insert(Type("DocumentRef.SalesInvoice"),					"SalesInvoice");
	TypesStructure.Insert(Type("DocumentRef.SalesOrder"),					"SalesOrder");
	TypesStructure.Insert(Type("DocumentRef.SalesTarget"),					"SalesTarget");
	TypesStructure.Insert(Type("DocumentRef.ReconciliationStatement"),		"ReconciliationStatement");
	TypesStructure.Insert(Type("DocumentRef.SubcontractorReport"),			"SubcontractorReport");
	TypesStructure.Insert(Type("DocumentRef.SupplierInvoice"),				"SupplierInvoice");
	TypesStructure.Insert(Type("DocumentRef.SupplierQuote"),				"SupplierQuote");
	TypesStructure.Insert(Type("DocumentRef.TaxAccrual"),					"TaxAccrual");
	TypesStructure.Insert(Type("DocumentRef.Timesheet"),					"Timesheet");
	TypesStructure.Insert(Type("DocumentRef.WeeklyTimesheet"),				"WeeklyTimesheet");
	TypesStructure.Insert(Type("DocumentRef.IntraWarehouseTransfer"),		"IntraWarehouseTransfer");
	TypesStructure.Insert(Type("DocumentRef.ObsoleteWorkOrder"),			"WorkOrder");
	
	Return TypesStructure.Get(DocumentType);

EndFunction

#EndRegion