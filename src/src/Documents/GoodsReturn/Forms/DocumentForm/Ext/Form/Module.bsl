#Region FormEventHandlers

&AtClient
Procedure AfterWrite(WriteParameters)
	
	// CWP
	If TypeOf(FormOwner) = Type("ManagedForm")
		AND Find(FormOwner.FormName, "DocumentForm_CWP") > 0 Then
		Notify("CWP_Write_GoodsReturn", New Structure("Ref, Number, Date", Object.Ref, Object.Number, Object.Date));
	EndIf;
	// End CWP

EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	FormManagement();
	
EndProcedure

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Form attributes setting.
	DocumentDate = Object.Date;
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentDate();
	EndIf;
	
	Company = Object.Company;
	
	If ValueIsFilled(Parameters.Basis) Then
		HideOperationKind = True;
	EndIf;
	
	DriveClientServer.SetPictureForComment(Items.GroupAdditional, Object.Comment);
	
	// Serial numbers
	UseSerialNumbersBalance = WorkWithSerialNumbers.UseSerialNumbersBalance();
	
	// StandardSubsystems.ObjectVersioning
	ObjectVersioning.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.ObjectVersioning
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisForm, Items.ImportantCommandsGroup);
	// End StandardSubsystems.Printing
	
	// StandardSubsystems.Properties
	PropertiesManagement.OnCreateAtServer(ThisForm, Object, "AdditionalAttributesGroup");
	// End StandardSubsystems.Properties
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	HideOperationKind = True;
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	// StandardSubsystems.Properties
	PropertiesManagement.BeforeWriteAtServer(ThisForm, CurrentObject);
	// End StandardSubsystems.Properties
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "SerialNumbersSelection"
		AND ValueIsFilled(Parameter) 
		// Form owner checkup
		AND Source = UUID Then
		GetSerialNumbersFromStorage(Parameter.AddressInTemporaryStorage, Parameter.RowKey);
	EndIf;
	
	// Properties subsystem
	If PropertiesManagementClient.ProcessAlerts(ThisForm, EventName, Parameter) Then
		UpdateAdditionalAttributesItems();
	EndIf;
	
EndProcedure

#EndRegion

#Region FormItemEventHandlersHeader

&AtClient
Procedure CommentOnChange(Item)
	
	AttachIdleHandler("Attachable_SetPictureForComment", 0.5, True);
	
EndProcedure

&AtServer
Procedure CompanyOnChangeAtServer()
	DriveServer.CheckAvailabilityOfGoodsReturn(Object);
EndProcedure

&AtClient
Procedure CompanyOnChange(Item)
	
	CompanyBeforeChange = Company;
	Company = Object.Company;
	If Company <> CompanyBeforeChange Then
		CompanyOnChangeAtServer();
	EndIf;
	
EndProcedure

&AtClient
Procedure CreditNoteOnChange(Item)
	
	If ValueIsFilled(Object.CreditNote) Then
		FillByDocument(Object.CreditNote);
	EndIf;
	
	FormManagement();
	
EndProcedure

&AtServer
Procedure DateOnChangeAtServer()
	DriveServer.CheckAvailabilityOfGoodsReturn(Object);
EndProcedure

&AtClient
Procedure DateOnChange(Item)
	
	DateBeforeChange = DocumentDate;
	DocumentDate = Object.Date;
	If DocumentDate <> DateBeforeChange Then
		DateOnChangeAtServer();
	EndIf;
	
EndProcedure

&AtClient
Procedure DebitNoteOnChange(Item)
	
	If ValueIsFilled(Object.DebitNote) Then
		FillByDocument(Object.DebitNote);
	EndIf;
	
	FormManagement();
	
EndProcedure

&AtClient
Procedure OperationKindOnChange(Item)
	
	Object.SalesDocument 	= Undefined;
	Object.CreditNote 		= Undefined;
	Object.SupplierInvoice	= Undefined;
	Object.DebitNote 		= Undefined;
	Object.DocumentAmount 	= 0;
	Object.Inventory.Clear();
	
	SetDefaultValuesForGLAccount();
	
	FormManagement();	
	
EndProcedure

&AtClient
Procedure SalesDocumentChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	If TypeOf(SelectedValue) = Type("Array")
		AND SelectedValue.Count() > 0 Then
		Object.SalesDocument = SelectedValue[0];
	Else
		Object.SalesDocument = SelectedValue;
	EndIf;
	
	If ValueIsFilled(Object.SalesDocument) Then 
		FillByDocument(Object.SalesDocument);
	EndIf;
	
	FormManagement();
	
EndProcedure

&AtClient
Procedure SupplierInvoiceChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	Object.SupplierInvoice = SelectedValue;
	
	If ValueIsFilled(Object.SupplierInvoice) Then 
		FillByDocument(Object.SupplierInvoice);
	EndIf;
	
	FormManagement();
	
EndProcedure

&AtClient
Procedure StructuralUnitOpening(Item, StandardProcessing)
	
	If Items.StructuralUnit.ListChoiceMode
		AND Not ValueIsFilled(Object.StructuralUnit) Then
		
		StandardProcessing = False;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormItemEventHandlersFormTableInventory

&AtClient
Procedure InventoryAmountAdjustedOnChange(Item)
	
	CalculateDocumentAmount();
	CalculateVATAmount(Items.Inventory.CurrentData);
	
EndProcedure

&AtClient
Procedure InventoryReturnQuantityOnChange(Item)
	
	CurrentData = Items.Inventory.CurrentData;
	CurrentData.Amount = ?(CurrentData.InitialQuantity = 0, 0, CurrentData.InitialAmount / CurrentData.InitialQuantity * CurrentData.Quantity);
	
	StructureData = New Structure;
	StructureData.Insert("Ref", 			Object.Ref);
	StructureData.Insert("Document",		Object.SalesDocument);
	StructureData.Insert("Product",			CurrentData.Products);
	StructureData.Insert("Characteristic",	CurrentData.Characteristic);
	StructureData.Insert("Batch",			CurrentData.Batch);
	StructureData.Insert("Quantity",		CurrentData.Quantity);
	
	CurrentData.CostOfGoodsSold = GetCostAmount(StructureData);
	
	CalculateVATAmount(Items.Inventory.CurrentData);
	CalculateDocumentAmount();
	
	// Serial numbers
	If UseSerialNumbersBalance <> Undefined Then
		WorkWithSerialNumbersClientServer.UpdateSerialNumbersQuantity(Object, CurrentData);
	EndIf;
	
EndProcedure

&AtClient
Procedure InventorySerialNumbersStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	OpenSerialNumbersSelection();
	
EndProcedure

&AtClient
Procedure InventoryBeforeDeleteRow(Item, Cancel)
	
	CurrentData = Items.Inventory.CurrentData;
	WorkWithSerialNumbersClientServer.DeleteSerialNumbersByConnectionKey(Object.SerialNumbers, CurrentData,,UseSerialNumbersBalance);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServerNoContext
Function GetCostAmount(StructureData)
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	SalesTurnovers.CostTurnover / SalesTurnovers.QuantityTurnover * &ReturnQuantity AS CostOfGoodsSold,
	|	SalesTurnovers.QuantityTurnover AS QuantityTurnover,
	|	SalesTurnovers.AmountTurnover AS AmountTurnover,
	|	SalesTurnovers.CostTurnover AS CostTurnover,
	|	SalesTurnovers.VATAmountTurnover AS VATAmountTurnover
	|FROM
	|	AccumulationRegister.Sales.Turnovers(
	|			,
	|			&PointInTime,
	|			Recorder,
	|			Products = &Product
	|				AND Characteristic = &Characteristic
	|				AND Batch = &Batch) AS SalesTurnovers
	|WHERE
	|	SalesTurnovers.Recorder = &Document";
	
	Query.SetParameter("Batch",				StructureData.Batch);
	Query.SetParameter("Characteristic", 	StructureData.Characteristic);
	Query.SetParameter("Document", 			StructureData.Document);
	Query.SetParameter("Product",			StructureData.Product);
	Query.SetParameter("ReturnQuantity",	StructureData.Quantity);
	Query.SetParameter("PointInTime", 		New Boundary(StructureData.Ref.Date, BoundaryType.Excluding));
	
	QueryResult = Query.Execute();
	
	Result = 0;
	Selection = QueryResult.Select();
	
	If Selection.Next() Then
		Result = Selection.CostOfGoodsSold;
	EndIf;
	
	Return Result;
	
EndFunction

&AtClient
Procedure FillBySalesDocument(Command)

	ShowQueryBox(New NotifyDescription("FillBySalesDocumentEnd", ThisObject),
					NStr("en = 'The document will be fully filled out according to the sales invoice. Do you want to continue?'"), QuestionDialogMode.YesNo, 0);
	
EndProcedure
				
&AtClient
Procedure FillBySalesDocumentEnd(Result, AdditionalParameters = Undefined) Export
    
    If Result = DialogReturnCode.Yes Then
		FillByDocument(Object.SalesDocument);
	EndIf;
	
	CalculateDocumentAmount();
	FormManagement();
	
EndProcedure

&AtClient
Procedure FillBySupplierInvoice(Command)

	ShowQueryBox(New NotifyDescription("FillBySupplierInvoiceEnd", ThisObject),
					NStr("en = 'The document will be fully filled out according to the supplier invoice. Do you want to continue?'"), QuestionDialogMode.YesNo, 0);
	
EndProcedure
				
&AtClient
Procedure FillBySupplierInvoiceEnd(Result, AdditionalParameters = Undefined) Export
    
    If Result = DialogReturnCode.Yes Then
		FillByDocument(Object.SupplierInvoice);
	EndIf;
	
	CalculateDocumentAmount();
	FormManagement();
	
EndProcedure

&AtClient
Procedure FillByCreditNote(Command)
	
	ShowQueryBox(New NotifyDescription("FillByCreditNoteEnd", ThisObject),
					NStr("en = 'The document will be fully filled out according to the credit note. Do you want to continue?'"), QuestionDialogMode.YesNo, 0);
					
EndProcedure

&AtClient
Procedure FillByCreditNoteEnd(Result, AdditionalParameters = Undefined) Export
    
    If Result = DialogReturnCode.Yes Then
		FillByDocument(Object.CreditNote);
	EndIf;
	
	CalculateDocumentAmount();
	FormManagement();
	
EndProcedure

&AtClient
Procedure FillByDebitNote(Command)
	
	ShowQueryBox(New NotifyDescription("FillByDebitNoteEnd", ThisObject),
					NStr("en = 'The document will be fully filled out according to the debit note. Do you want to continue?'"), QuestionDialogMode.YesNo, 0);
					
EndProcedure

&AtClient
Procedure FillByDebitNoteEnd(Result, AdditionalParameters = Undefined) Export
    
	If Result = DialogReturnCode.Yes Then
		FillByDocument(Object.DebitNote);
	EndIf;
	
	CalculateDocumentAmount();
	FormManagement();
	
EndProcedure

&AtServer
Procedure FillByDocument(BasisDocument)
	
	Document = FormAttributeToValue("Object");
	Document.Filling(BasisDocument, True);
	ValueToFormAttribute(Document, "Object");
	Modified = True;
	
EndProcedure

&AtClient
Procedure CalculateDocumentAmount() 
    
	Object.DocumentAmount = Object.Inventory.Total("Amount") + Object.Inventory.Total("VATAmount");
	
EndProcedure

&AtClient
Procedure CalculateVATAmount(CurrentData) 
    
	Rate = DriveReUse.GetVATRateValue(CurrentData.VATRate);
	CurrentData.VATAmount = CurrentData.Amount * Rate / 100;
	
EndProcedure

&AtClient
Procedure FormManagement()
	
	FromCustomer		= (Object.OperationKind = PredefinedValue("Enum.OperationTypesGoodsReturn.FromCustomer"));
	SubjectToVAT		= Object.VATTaxation <> PredefinedValue("Enum.VATTaxationTypes.NotSubjectToVAT");
	
	If Not HideOperationKind Then
		HideOperationKind	= TypeOf(FormOwner) = Type("FormTable") 
								AND ValueIsFilled(FormOwner.Parent.PurposeUseKey);
	EndIf;
	
	CommonUseClientServer.SetFormItemProperty(Items, "OperationKind",				"Visible", Not HideOperationKind);
	CommonUseClientServer.SetFormItemProperty(Items, "GroupFromCustomer",			"Visible", FromCustomer);
	CommonUseClientServer.SetFormItemProperty(Items, "InventoryCostOfGoodsSold",	"Visible", FromCustomer);
	CommonUseClientServer.SetFormItemProperty(Items, "InventoryVATRate", 			"Visible", SubjectToVAT);
	CommonUseClientServer.SetFormItemProperty(Items, "InventoryVATAmount",			"Visible", SubjectToVAT);
	CommonUseClientServer.SetFormItemProperty(Items, "GroupToSupplier",				"Visible", Not FromCustomer);
	CommonUseClientServer.SetFormItemProperty(Items, "GLAccount",					"Visible", Not FromCustomer);
	
EndProcedure

&AtClient
Procedure OpenSerialNumbersSelection()
		
	CurrentDataIdentifier = Items.Inventory.CurrentData.GetID();
	ParametersOfSerialNumbers = SerialNumberPickParameters(CurrentDataIdentifier);
	
	OpenForm("DataProcessor.SerialNumbersSelection.Form", ParametersOfSerialNumbers, ThisObject);

EndProcedure

&AtServer
Function GetSerialNumbersFromStorage(AddressInTemporaryStorage, RowKey)
	
	Modified = True;
	Return WorkWithSerialNumbers.GetSerialNumbersFromStorage(Object, AddressInTemporaryStorage, RowKey);
	
EndFunction

&AtServer
Function SerialNumberPickParameters(CurrentDataIdentifier)
	
	Return WorkWithSerialNumbers.SerialNumberPickParameters(Object, ThisObject.UUID, CurrentDataIdentifier, False, "Inventory");
	
EndFunction

// Procedure sets GL account values by default depending on the operation type.
//
&AtServer
Procedure SetDefaultValuesForGLAccount()

	If Object.OperationKind = Enums.OperationTypesGoodsReturn.ToSupplier Then
		Object.GLAccount = Catalogs.DefaultGLAccounts.GetDefaultGLAccount("PurchaseReturns");
	Else
		Object.GLAccount = ChartsOfAccounts.PrimaryChartOfAccounts.EmptyRef();
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
	
	AdditionalReportsAndDataProcessors.ExecuteAllocatedCommandAtServer(ThisForm, ItemName, ExecutionResult);
	
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
	
	PropertiesManagement.UpdateAdditionalAttributesItems(ThisForm, FormAttributeToValue("Object"));
	
EndProcedure

// End StandardSubsystems.Properties

#EndRegion

