////////////////////////////////////////////////////////////////////////////////
// Subsystem "Change prohibition dates".
// 
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Allows to change the interface operation when embedding.
//
// Parameters:
//  InterfaceWorkSettings - Structure - contains property:
//   * UseExternalUsers - Boolean - (initial value
//     False) if True is set, then it will be possible to setup the date of prohibition for external users.
//
Procedure InterfaceSetting(InterfaceWorkSettings) Export
	
	InterfaceWorkSettings.UseExternalUsers = False;
	
EndProcedure

// Contains description of tables and object fields for data changing prohibition check.
//   Called from the ChangingProhibited procedure of ChangingProhibitionDates common
// module used to subscribe to  BeforeWrite object event in order to check existence of prohibitions and cancelation of
// prohibited object changes.
//
// Parameters:
//  DataSources - ValueTable - with columns:
//   * Table     - String - full name of the metadata object, for example "Document.SupplierInvoice".
//   * DateField    - String - name of the object attribute or tabular section, for example, "Date", "Goods.ShipmentDate".
//   * Section      - String - name of the predefined item "ChartOfCharacteristicTypesRef.ProhibitionDatesSections".
//   * ObjectField - String - name of object attribute or tabular section attribute,
//                            for example, "Organization", "Goods.Warehouse".
//
//  There is AddLine procedure in ClosingDates common module for line adding.
//
Procedure FillDataSourcesForChangeProhibitionCheck(DataSources) Export
	
	ClosingDates.AddLine(DataSources, "Document.ExpenseReport", 				"Date", "ManagementAccounting", "Company");
	ClosingDates.AddLine(DataSources, "Document.FixedAssetsDepreciation", 		"Date", "ManagementAccounting", "Company");
	ClosingDates.AddLine(DataSources, "Document.Budget", 						"Date", "ManagementAccounting", "Company");
	ClosingDates.AddLine(DataSources, "Document.OpeningBalanceEntry",	 		"Date", "ManagementAccounting", "Company");
	ClosingDates.AddLine(DataSources, "Document.ArApAdjustments", 				"Date", "ManagementAccounting", "Company");
	ClosingDates.AddLine(DataSources, "Document.FixedAssetUsage", 				"Date", "ManagementAccounting", "Company");
	ClosingDates.AddLine(DataSources, "Document.LetterOfAuthority", 			"Date", "ManagementAccounting", "Company");
	ClosingDates.AddLine(DataSources, "Document.AdditionalExpenses", 			"Date", "ManagementAccounting", "Company");
	ClosingDates.AddLine(DataSources, "Document.ObsoleteWorkOrder", 			"Date", "ManagementAccounting", "Company");
	ClosingDates.AddLine(DataSources, "Document.ProductionOrder", 				"Date", "ManagementAccounting", "Company");
	ClosingDates.AddLine(DataSources, "Document.MonthEndClosing", 				"Date", "ManagementAccounting", "Company");
	ClosingDates.AddLine(DataSources, "Document.FixedAssetDepreciationChanges",	"Date", "ManagementAccounting", "Company");
	ClosingDates.AddLine(DataSources, "Document.Stocktaking", 					"Date", "ManagementAccounting", "Company");
	ClosingDates.AddLine(DataSources, "Document.EmployeeOcupationChange", 		"Date", "ManagementAccounting", "Company");
	ClosingDates.AddLine(DataSources, "Document.Payroll", 						"Date", "ManagementAccounting", "Company");
	ClosingDates.AddLine(DataSources, "Document.TaxAccrual", 					"Date", "ManagementAccounting", "Company");
	ClosingDates.AddLine(DataSources, "Document.Operation", 					"Date", "ManagementAccounting", "Company");
	ClosingDates.AddLine(DataSources, "Document.InventoryIncrease", 			"Date", "ManagementAccounting", "Company");
	ClosingDates.AddLine(DataSources, "Document.AccountSalesFromConsignee",		"Date", "ManagementAccounting", "Company");
	ClosingDates.AddLine(DataSources, "Document.AccountSalesToConsignor", 		"Date", "ManagementAccounting", "Company");
	ClosingDates.AddLine(DataSources, "Document.SubcontractorReportIssued",		"Date", "ManagementAccounting", "Company");
	ClosingDates.AddLine(DataSources, "Document.ShiftClosure",					"Date", "ManagementAccounting", "Company");
	ClosingDates.AddLine(DataSources, "Document.SubcontractorReport", 			"Date", "ManagementAccounting", "Company");
	ClosingDates.AddLine(DataSources, "Document.FixedAssetSale", 				"Date", "ManagementAccounting", "Company");
	ClosingDates.AddLine(DataSources, "Document.CashTransfer",					"Date", "ManagementAccounting", "Company");
	ClosingDates.AddLine(DataSources, "Document.CashTransferPlan",				"Date", "ManagementAccounting", "Company");
	ClosingDates.AddLine(DataSources, "Document.InventoryTransfer",				"Date", "ManagementAccounting", "Company");
	ClosingDates.AddLine(DataSources, "Document.IntraWarehouseTransfer",		"Date", "ManagementAccounting", "Company");
	ClosingDates.AddLine(DataSources, "Document.RetailRevaluation",				"Date", "ManagementAccounting", "Company");
	ClosingDates.AddLine(DataSources, "Document.SalesTarget", 					"Date", "ManagementAccounting", "Company");
	ClosingDates.AddLine(DataSources, "Document.PayrollSheet", 					"Date", "ManagementAccounting", "Company");
	ClosingDates.AddLine(DataSources, "Document.CashReceipt", 					"Date", "ManagementAccounting", "Company");
	ClosingDates.AddLine(DataSources, "Document.CashInflowForecast", 			"Date", "ManagementAccounting", "Company");
	ClosingDates.AddLine(DataSources, "Document.PaymentReceipt", 				"Date", "ManagementAccounting", "Company");
	ClosingDates.AddLine(DataSources, "Document.EmploymentContract", 			"Date", "ManagementAccounting", "Company");
	ClosingDates.AddLine(DataSources, "Document.FixedAssetRecognition", 		"Date", "ManagementAccounting", "Company");
	ClosingDates.AddLine(DataSources, "Document.SupplierInvoice", 				"Date", "ManagementAccounting", "Company");
	ClosingDates.AddLine(DataSources, "Document.OtherExpenses", 				"Date", "ManagementAccounting", "Company");
	ClosingDates.AddLine(DataSources, "Document.CostAllocation", 				"Date", "ManagementAccounting", "Company");
	ClosingDates.AddLine(DataSources, "Document.ExpenditureRequest", 			"Date", "ManagementAccounting", "Company");
	ClosingDates.AddLine(DataSources, "Document.CashVoucher", 					"Date", "ManagementAccounting", "Company");
	ClosingDates.AddLine(DataSources, "Document.SalesInvoice", 					"Date", "ManagementAccounting", "Company");
	ClosingDates.AddLine(DataSources, "Document.PaymentExpense", 				"Date", "ManagementAccounting", "Company");
	ClosingDates.AddLine(DataSources, "Document.InventoryReservation", 			"Date", "ManagementAccounting", "Company");
	ClosingDates.AddLine(DataSources, "Document.Production", 					"Date", "ManagementAccounting", "Company");
	ClosingDates.AddLine(DataSources, "Document.JobSheet", 						"Date", "ManagementAccounting", "Company");
	ClosingDates.AddLine(DataSources, "Document.FixedAssetWriteOff", 			"Date", "ManagementAccounting", "Company");
	ClosingDates.AddLine(DataSources, "Document.InventoryWriteOff", 			"Date", "ManagementAccounting", "Company");
	ClosingDates.AddLine(DataSources, "Document.Quote", 						"Date", "ManagementAccounting", "Company");
	ClosingDates.AddLine(DataSources, "Document.SupplierQuote",					"Date", "ManagementAccounting", "Company");
	ClosingDates.AddLine(DataSources, "Document.Timesheet", 					"Date", "ManagementAccounting", "Company");
	ClosingDates.AddLine(DataSources, "Document.TerminationOfEmployment", 		"Date", "ManagementAccounting", "Company");
	ClosingDates.AddLine(DataSources, "Document.WeeklyTimesheet", 				"Date", "ManagementAccounting", "Company");
	ClosingDates.AddLine(DataSources, "Document.SalesSlip", 					"Date", "ManagementAccounting", "Company");
	ClosingDates.AddLine(DataSources, "Document.ProductReturn", 				"Date", "ManagementAccounting", "Company");
	ClosingDates.AddLine(DataSources, "Document.GoodsReceipt", 					"Date", "ManagementAccounting", "Company");
	ClosingDates.AddLine(DataSources, "Document.GoodsIssue", 					"Date", "ManagementAccounting", "Company");
	ClosingDates.AddLine(DataSources, "Document.TaxInvoiceIssued", 				"Date", "ManagementAccounting", "Company");
	ClosingDates.AddLine(DataSources, "Document.TaxInvoiceReceived", 			"Date", "ManagementAccounting", "Company");
	ClosingDates.AddLine(DataSources, "Document.LoanContract",					"Date", "ManagementAccounting", "Company");
	ClosingDates.AddLine(DataSources, "Document.DebitNote", 					"Date", "ManagementAccounting", "Company");
	ClosingDates.AddLine(DataSources, "Document.CreditNote", 					"Date", "ManagementAccounting", "Company");

	// Additional sections for Sales order, Purchase order documents
	ClosingDates.AddLine(DataSources, "Document.SalesOrder",	"Date", "SalesOrders", "OrderState");
	ClosingDates.AddLine(DataSources, "Document.PurchaseOrder",	"Date", "PurchaseOrders", "OrderState");
	
EndProcedure

// Allows to override execution of prohibitions checks by random condition.
//
// Parameters:
//  Object       - CatalogObject,
//                 DocumentObject,
//                 ChartOfCharacteristicTypesObject,
//                 ChartChartOfAccountsObject,
//                 ChartOfCalculationTypesObject,
//                 BusinessProcessObject,
//                 TaskObject,
//                 ExchangePlanObject - data object (BeforeRecording or OnReadAtServer).
//               - InformationRegisterRecordSet,
//                 AccumulationRegisterRecordSet,
//                 AccountingRegisterRecordSet,
//                 CalculationRegisterRecordSet - records set (BeforeRecording or OnReadAtServer).
//  
//  ProhibitionChangeCheck - Boolean - If install False Checking
//                             prohibition change will not be executed.
//
//  ImportingProhibitionCheckNode - Undefined, LinkExchangePlans -
//                 When Undefined, loading prohibition check is not executed.
//
//  InformAboutProhibition - Boolean - initial value is True. If False
//                 is set, then error message will not be sent to user.
//                 For example, only recording denial will be visible during the online recording.
//                 The message will be recorded into a log in any case.
//
Procedure BeforeChangeProhibitionCheck(Object,
										ProhibitionChangeCheck,
										ImportingProhibitionCheckNode,
										InformAboutProhibition) Export
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// Allows to override execution of prohibitions checks by random condition.
//
Procedure CheckDateBanEditingWorkOrder(Form, CurrentObject, ImportingProhibitionCheckNode = Undefined, InformAboutProhibition = False) Export
	
	DataForChecking	= ClosingDates.DataTemplateForChecking();
	
	NewRow			= DataForChecking.Add();
	NewRow.Date	= CurrentObject.Finish;
	NewRow.Object	= CurrentObject.Company;
	NewRow.Section	= ChartsOfCharacteristicTypes.ClosingDateSections.ManagementAccounting;
	
	FoundProhibitions	= Undefined;
	StandardProcessing= True;
	Form.ReadOnly= ClosingDates.DataChangeProhibitionFound(DataForChecking, InformAboutProhibition, CurrentObject.Ref, StandardProcessing, ImportingProhibitionCheckNode, FoundProhibitions);
	
EndProcedure

// Starting availability for use new sections.
//
// - SalesOrders;
// - PurchaseOrders;
//
// Therefore the option to edit (or prohibition to edit) these documents is set separately.
//
Procedure UpdateChangesProhibitionDatesSections(DataProcessorCompleted) Export
	
	Query = New Query(
	"SELECT
	|	SectionSalesOrders.User,
	|	TRUE AS Use
	|INTO SectionSalesOrders
	|FROM
	|	InformationRegister.ClosingDates AS SectionSalesOrders
	|WHERE
	|	SectionSalesOrders.Section = VALUE(ChartOfCharacteristicTypes.ClosingDateSections.SalesOrders)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SectionPurchaseOrders.User,
	|	TRUE AS Use
	|INTO SectionPurchaseOrders
	|FROM
	|	InformationRegister.ClosingDates AS SectionPurchaseOrders
	|WHERE
	|	SectionPurchaseOrders.Section = VALUE(ChartOfCharacteristicTypes.ClosingDateSections.PurchaseOrders)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SectionMain.User AS User,
	|	SectionMain.ProhibitionDateDescription AS ProhibitionDateDescription,
	|	SectionMain.ProhibitionDate AS ProhibitionDate,
	|	ISNULL(SectionSalesOrders.Use, FALSE) AS SectionSalesOrdersUsed,
	|	ISNULL(SectionPurchaseOrders.Use, FALSE) AS SectionPurchaseOrdersUsed
	|FROM
	|	InformationRegister.ClosingDates AS SectionMain
	|		LEFT JOIN SectionSalesOrders AS SectionSalesOrders
	|		ON SectionMain.User = SectionSalesOrders.User
	|		LEFT JOIN SectionPurchaseOrders AS SectionPurchaseOrders
	|		ON SectionMain.User = SectionPurchaseOrders.User
	|WHERE
	|	SectionMain.Section = VALUE(ChartOfCharacteristicTypes.ClosingDateSections.ManagementAccounting)"
	);
	
	BeginTransaction();
	Try
		
		DataProcessorCompleted = True;
		Selection = Query.Execute().Select();
		While Selection.Next() Do
			
			If Selection.SectionSalesOrdersUsed
				OR Selection.SectionPurchaseOrdersUsed Then
				
				Continue;
				
			EndIf;
			
			// do not need to translate!
			Comment = "Section is added automatically when the Programm was updated";
			
			ManagerRegister = InformationRegisters.ClosingDates.CreateRecordManager();
			ManagerRegister.User = Selection.User;
			ManagerRegister.ProhibitionDate = Selection.ProhibitionDate;
			ManagerRegister.Section = ChartsOfCharacteristicTypes.ClosingDateSections.SalesOrders;
			ManagerRegister.Object = ChartsOfCharacteristicTypes.ClosingDateSections.SalesOrders;
			ManagerRegister.ProhibitionDateDescription = Selection.ProhibitionDateDescription;
			ManagerRegister.Comment = Comment;
			ManagerRegister.Write();
			
			ManagerRegister = InformationRegisters.ClosingDates.CreateRecordManager();
			ManagerRegister.User = Selection.User;
			ManagerRegister.ProhibitionDate = Selection.ProhibitionDate;
			ManagerRegister.Section = ChartsOfCharacteristicTypes.ClosingDateSections.PurchaseOrders;
			ManagerRegister.Object = ChartsOfCharacteristicTypes.ClosingDateSections.PurchaseOrders;
			ManagerRegister.ProhibitionDateDescription = Selection.ProhibitionDateDescription;
			ManagerRegister.Comment = Comment;
			ManagerRegister.Write();
			
			DataProcessorCompleted = False; // Update handler is considered executed if records are not added
			
		EndDo;
		
		CommitTransaction();
		
	Except
		
		DataProcessorCompleted = False;
		ErrorMessage = NStr("en = 'Update of changes prohibition dates sections'", CommonUseClientServer.MainLanguageCode());
		WriteLogEvent(ErrorMessage, EventLogLevel.Error, Metadata.InformationRegisters.ClosingDates, , ErrorDescription());
		
	EndTry;
	
EndProcedure

#EndRegion