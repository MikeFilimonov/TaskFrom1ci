#Region ServiceHandlers

&AtClient
// Procedure changes the current row of the Employees tabular section
//
Procedure ChangeCurrentEmployee()
	
	Items.Employees.CurrentRow = CurrentEmployee;
	
EndProcedure

&AtServer
// Function calls the object function FindEmployeeDeductionEarnings.
//
Function FindEmployeeEarningsDeductionsServer(FilterStructure, Tax = False)	
	
	Document = FormAttributeToValue("Object");
	SearchResult = Document.FindEmployeeEarningsDeductions(FilterStructure, Tax);
	ValueToFormAttribute(Document, "Object");
	
	Return SearchResult;
	
EndFunction

&AtServerNoContext
// It receives data set from server for the DateOnChange procedure.
//
Function GetDataDateOnChange(DocumentRef, DateNew, DateBeforeChange)
	
	StructureData = New Structure();
	StructureData.Insert("DATEDIFF", DriveServer.CheckDocumentNumber(DocumentRef, DateNew, DateBeforeChange));
	
	Return StructureData;
	
EndFunction

&AtServerNoContext
// It receives data set from server for the ContractOnChange procedure.
//
Function GetCompanyDataOnChange(Company)
	
	StructureData = New Structure();
	StructureData.Insert("Counterparty", DriveServer.GetCompany(Company));
	
	Return StructureData;
	
EndFunction

&AtServer
// Fills the values of the Employees tabular section.
//
Procedure FillValues()
	
	If Object.Employees.Count() = 0 OR Object.OperationKind = Enums.OperationTypesTransferAndPromotion.PaymentFormChange Then
		Return;
	EndIf;
	
	For Each TSRow In Object.Employees Do
		
		EmployeeStructure = New Structure;
		EmployeeStructure.Insert("Period", TSRow.Period - 1);
		EmployeeStructure.Insert("Employee", TSRow.Employee);
		EmployeeStructure.Insert("Company", Object.Company);
		
		GetEmployeeData(EmployeeStructure);
		
		TSRow.PreviousUnit = EmployeeStructure.StructuralUnit;
		TSRow.PreviousJobTitle = EmployeeStructure.Position;
		TSRow.PreviousCountOccupiedRates = EmployeeStructure.OccupiedRates;
		TSRow.PreviousWorkSchedule = EmployeeStructure.WorkSchedule;
		
	EndDo;
	
EndProcedure

&AtServer
// Fills the values of the Employees tabular section.
//
Procedure FillValuesAboutAllEmployees()	
	
	For Each TSRow In Object.Employees Do
		
		If Not ValueIsFilled(TSRow.PreviousUnit)
				OR ValueIsFilled(TSRow.PreviousJobTitle) Then
		
			EmployeeStructure = New Structure;
			EmployeeStructure.Insert("Period", TSRow.Period - 1);
			EmployeeStructure.Insert("Employee", TSRow.Employee);
			EmployeeStructure.Insert("Company", Object.Company);
			
			GetEmployeeData(EmployeeStructure);
			
			TSRow.PreviousUnit = EmployeeStructure.StructuralUnit;
			TSRow.PreviousJobTitle = EmployeeStructure.Position;
			TSRow.PreviousCountOccupiedRates = EmployeeStructure.OccupiedRates;
			TSRow.PreviousWorkSchedule = EmployeeStructure.WorkSchedule;
		
		EndIf;
		
	EndDo;
	
EndProcedure

&AtServerNoContext
// Receives the server data set from the Employees tabular section.
//
Procedure GetEmployeeData(EmployeeStructure)
	
	Query = New Query(
	"SELECT
	|	EmployeesSliceLast.StructuralUnit,
	|	EmployeesSliceLast.Position,
	|	EmployeesSliceLast.OccupiedRates,
	|	EmployeesSliceLast.WorkSchedule
	|FROM
	|	InformationRegister.Employees.SliceLast(
	|			&Period,
	|			Employee = &Employee
	|				AND Company = &Company) AS EmployeesSliceLast");
	
	Query.SetParameter("Period", EmployeeStructure.Period);
	Query.SetParameter("Employee", EmployeeStructure.Employee);
	Query.SetParameter("Company", DriveServer.GetCompany(EmployeeStructure.Company));
	
	EmployeeStructure.Insert("StructuralUnit");
	EmployeeStructure.Insert("Position");
	EmployeeStructure.Insert("OccupiedRates", 1);
	EmployeeStructure.Insert("WorkSchedule");
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		FillPropertyValues(EmployeeStructure, Selection);
	EndDo;
	
EndProcedure

&AtServer
// Procedure fills the selection list of the "Current employee" control field
//
Procedure FillCurrentEmployeesChoiceList()
	
	Items.CurrentEmployeeEarningsDeductions.ChoiceList.Clear();
	Items.CurrentEmployeeTaxes.ChoiceList.Clear();
	For Each RowEmployee In Object.Employees Do
		
		RowPresentation = String(RowEmployee.Employee) + ", " + NStr("en = 'employee ID'") + ": " + String(RowEmployee.Employee.Code);
		Items.CurrentEmployeeEarningsDeductions.ChoiceList.Add(RowEmployee.GetID(), RowPresentation);
		Items.CurrentEmployeeTaxes.ChoiceList.Add(RowEmployee.GetID(), RowPresentation);
		
	EndDo;
	
EndProcedure

&AtServer
// Procedure states availability of the form items on client.
//
// Parameters:
//  No.
//
Procedure SetVisibleAtServer()
	
	IsIsTransferAndPromotionSalary = (Object.OperationKind = PredefinedValue("Enum.OperationTypesTransferAndPromotion.TransferAndPaymentFormChange"));
	
	Items.EmployeesFomerWorkSchedule.Visible 	= IsIsTransferAndPromotionSalary;
	Items.EmployeesFomerPosition.Visible 		= IsIsTransferAndPromotionSalary;
	Items.EmployeesFomerDepartment.Visible	= IsIsTransferAndPromotionSalary;
	Items.EmployeesWorkSchedule.Visible 			= IsIsTransferAndPromotionSalary;
	Items.EmployeesPosition.Visible 				= IsIsTransferAndPromotionSalary;
	Items.EmployeesStructuralUnit.Visible 	= IsIsTransferAndPromotionSalary;
	
	If IsIsTransferAndPromotionSalary Then
		
		Items.EmployeesFomerQuantityRatesQty.Visible	= UseHeadcountBudget;
		Items.EmployeesRatesQty.Visible					= UseHeadcountBudget;
		
		Items.EmployeesStructuralUnit.AutoChoiceIncomplete 	= True;
		Items.EmployeesPosition.AutoChoiceIncomplete 			= True;
		Items.EmployeesRatesQty.AutoChoiceIncomplete 	= True;
		Items.EmployeesStructuralUnit.AutoMarkIncomplete = True;
		Items.EmployeesPosition.AutoMarkIncomplete 			= True;
		Items.EmployeesRatesQty.AutoMarkIncomplete 	= True;
		
	Else
		
		Items.EmployeesFomerQuantityRatesQty.Visible	= False;
		Items.EmployeesRatesQty.Visible					= False;
		
	EndIf;
	
EndProcedure

&AtServer
// Procedure initializes the control of visible and filling of calculated values on server
// 
Procedure ProcessEventAtServer(SetVisible = True, FillValues = True)
	
	If SetVisible Then
		
		SetVisibleAtServer();
		
	EndIf;
	
	If FillValues Then
		
		FillValues();
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormEventsHandlers

&AtServer
// Procedure - event handler OnCreateAtServer of the form.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	DriveServer.FillDocumentHeader(Object,
	,
	Parameters.CopyingValue,
	Parameters.Basis,
	PostingIsAllowed,
	Parameters.FillingValues);

	// Form attributes setting.
	DocumentDate = Object.Date;
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentDate();
	EndIf;
	
	ParentCompany = DriveServer.GetCompany(Object.Company);
	TabularSectionName = "Employees";
	CurrencyByDefault = Constants.FunctionalCurrency.Get();
	
	UseHeadcountBudget = Constants.UseHeadcountBudget.Get();
	
	ProcessEventAtServer();
	
	If Not Constants.UseSecondaryEmployment.Get() Then
		
		If Items.Find("EmployeesEmployeeCode") <> Undefined Then
			
			Items.EmployeesEmployeeCode.Visible = False;
			
		EndIf;
		
	EndIf; 
	
	User = Users.CurrentUser();
	
	SettingValue = DriveReUse.GetValueByDefaultUser(User, "MainDepartment");
	MainDepartment = ?(ValueIsFilled(SettingValue), SettingValue, Catalogs.BusinessUnits.MainDepartment);
	
	If Not Constants.UseSeveralDepartments.Get() Then
		Items.EmployeesFomerDepartment.Visible = False;
	EndIf;
	
	TaxAccounting = GetFunctionalOption("UsePersonalIncomeTaxCalculation");
	CommonUseClientServer.SetFormItemProperty(Items, "CurrentEmployeeTaxes", "Visible", TaxAccounting);
	
	DriveClientServer.SetPictureForComment(Items.AdvancedPage, Object.Comment);
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisForm, Items.ImportantCommandsGroup);
	// End StandardSubsystems.Printing
	
EndProcedure

// Procedure - OnReadAtServer event handler.
//
&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	ClosingDates.ObjectOnReadAtServer(ThisForm, CurrentObject);
	
EndProcedure

&AtServer
// Procedure - handler of the AfterWriteAtServer event.
//
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	ProcessEventAtServer();
	
EndProcedure

#EndRegion

#Region HeaderAttributesHandlers

&AtClient
// Procedure - event handler OnChange of the Date input field.
// The procedure determines the situation when after changing the date
// of a document this document is found in another period
// of documents enumeration, and in this case the procedure assigns new unique number to the document.
// Overrides the corresponding form parameter.
//
Procedure DateOnChange(Item)
	
	// Date change event DataProcessor.
	DateBeforeChange = DocumentDate;
	DocumentDate = Object.Date;
	If Object.Date <> DateBeforeChange Then
		StructureData = GetDataDateOnChange(Object.Ref, Object.Date, DateBeforeChange);
		If StructureData.DATEDIFF <> 0 Then
			Object.Number = "";
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of the Company input field.
// In procedure the document number
// is cleared, and also the form functional options are configured.
// Overrides the corresponding form parameter.
//
Procedure CompanyOnChange(Item)

	// Company change event data processor.
	Object.Number = "";
	StructureData = GetCompanyDataOnChange(Object.Company);
	Counterparty = StructureData.Counterparty;
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of the OperationKind input field.
// In procedure the document number
// is cleared, and also the form functional options are configured.
// Overrides the corresponding form parameter.
//
Procedure OperationKindOnChange(Item)
	
	ProcessEventAtServer(,False);
	
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesTransferAndPromotion.TransferAndPaymentFormChange") Then
	
		For Each TSRow In Object.Employees Do
			
			If Not ValueIsFilled(TSRow.PreviousUnit)
				OR ValueIsFilled(TSRow.PreviousJobTitle) Then
				
				FillValuesAboutAllEmployees();
				Break;
			
			EndIf;
			
		EndDo;
	
	EndIf; 
	
EndProcedure

&AtClient
// Procedure - event handler OnCurrentPageChange of field PagesMain
//
Procedure PagesMainOnCurrentPageChange(Item, CurrentPage)
	
	If CurrentPage = Items.PageEarningsDeductions
		OR CurrentPage = Items.PageTaxes Then
		
		FillCurrentEmployeesChoiceList();
		
		DataCurrentRows = Items.Employees.CurrentData;
		
		If DataCurrentRows <> Undefined Then
			
			CurrentEmployee = DataCurrentRows.GetID();
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of field CurrentEmployeeDeductionEarnings
//
Procedure CurrentEmployeeEarningsDeductionsOnChange(Item)
	
	ChangeCurrentEmployee();
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of field CurrentEmployeeTaxes
//
Procedure CurrentEmployeeTaxesOnChange(Item)
	
	ChangeCurrentEmployee();
	
EndProcedure

#EndRegion

#Region TabularSectionsHandlers

&AtClient
Procedure FillEarningsDeductions(Command)	
	
	TabularSectionRow = Items.Employees.CurrentData;
	
	If TabularSectionRow = Undefined Then
	
		Message = New UserMessage;
		Message.Text = NStr("en = 'The ""Employees"" row is not selected in the tabular section.'");
		Message.Message();	
		Return;
		
	EndIf;  
	
	If Object.EarningsDeductions.FindRows(New Structure("ConnectionKey", TabularSectionRow.ConnectionKey)).Count() > 0 Then
		Response = Undefined;

		ShowQueryBox(New NotifyDescription("FillDeductionEarningsEnd", ThisObject, New Structure("TabularSectionRow", TabularSectionRow)), NStr("en = 'The ""Earnings and deductions"" tabular section will be cleared. Continue?'"), QuestionDialogMode.YesNo, 0);
        Return; 
	EndIf;
	
	FillDeductionEarningsFragment(TabularSectionRow);
EndProcedure

&AtClient
Procedure FillDeductionEarningsEnd(Result, AdditionalParameters) Export
    
    TabularSectionRow = AdditionalParameters.TabularSectionRow;
    
    
    Response = Result;
    If Response <> DialogReturnCode.Yes Then
        Return;
    EndIf; 
    
    FillDeductionEarningsFragment(TabularSectionRow);

EndProcedure

&AtClient
Procedure FillDeductionEarningsFragment(Val TabularSectionRow)
    
    Var NewRow, SearchResult, SearchString, FilterStr, FilterStructure;
    
    DriveClient.DeleteRowsOfSubordinateTabularSection(ThisForm, "EarningsDeductions");
    
    FilterStructure = New Structure;
    FilterStructure.Insert("Employee", 	TabularSectionRow.Employee);
    FilterStructure.Insert("Company", Object.Company);
    FilterStructure.Insert("Date", 		TabularSectionRow.Period);		
    SearchResult = FindEmployeeEarningsDeductionsServer(FilterStructure);
    
    For Each SearchString In SearchResult Do
        NewRow 						= Object.EarningsDeductions.Add();
        NewRow.EarningAndDeductionType 	= SearchString.EarningAndDeductionType;		
        NewRow.Amount 					= SearchString.Amount;
        NewRow.Currency 					= SearchString.Currency;
        NewRow.GLExpenseAccount			 	= SearchString.GLExpenseAccount;
        NewRow.Actuality			= SearchString.Actuality;
        NewRow.ConnectionKey 				= TabularSectionRow.ConnectionKey;
    EndDo;	
    
    FilterStr = New FixedStructure("ConnectionKey", TabularSectionRow.ConnectionKey);
    Items.EarningsDeductions.RowFilter 	= FilterStr;

EndProcedure

&AtClient
Procedure FillIncomeTaxes(Command)	
	
	TabularSectionRow = Items.Employees.CurrentData;
	
	If TabularSectionRow = Undefined Then
	
		Message = New UserMessage;
		Message.Text = NStr("en = 'The ""Employees"" row is not selected in the tabular section.'");
		Message.Message();	
		Return;
		
	EndIf;  
	
	If Object.IncomeTaxes.FindRows(New Structure("ConnectionKey", TabularSectionRow.ConnectionKey)).Count() > 0 Then
		Response = Undefined;

		ShowQueryBox(New NotifyDescription("FillIncomeTaxesEnd", ThisObject, New Structure("TabularSectionRow", TabularSectionRow)), NStr("en = 'The ""Income taxes"" tabular section will be cleared. Continue?'"), QuestionDialogMode.YesNo, 0);
        Return; 
	EndIf;
	
	FillIncomeTaxFragment(TabularSectionRow);
EndProcedure

&AtClient
Procedure FillIncomeTaxesEnd(Result, AdditionalParameters) Export
    
    TabularSectionRow = AdditionalParameters.TabularSectionRow;
    
    
    Response = Result;
    If Response <> DialogReturnCode.Yes Then
        Return;
    EndIf; 
    
    FillIncomeTaxFragment(TabularSectionRow);

EndProcedure

&AtClient
Procedure FillIncomeTaxFragment(Val TabularSectionRow)
    
    Var NewRow, SearchResult, SearchString, FilterStr, FilterStructure;
    
    DriveClient.DeleteRowsOfSubordinateTabularSection(ThisForm, "IncomeTaxes");
    
    FilterStructure = New Structure;
    FilterStructure.Insert("Employee", 	TabularSectionRow.Employee);
    FilterStructure.Insert("Company", Object.Company);
    FilterStructure.Insert("Date", 		TabularSectionRow.Period);		
    SearchResult = FindEmployeeEarningsDeductionsServer(FilterStructure, True);
    
    For Each SearchString In SearchResult Do
        NewRow 						= Object.IncomeTaxes.Add();
        NewRow.EarningAndDeductionType 	= SearchString.EarningAndDeductionType;		
        NewRow.Currency 					= SearchString.Currency;
        NewRow.Actuality			= SearchString.Actuality;
        NewRow.ConnectionKey 				= TabularSectionRow.ConnectionKey;
    EndDo;	
    
    FilterStr = New FixedStructure("ConnectionKey", TabularSectionRow.ConnectionKey);
    Items.IncomeTaxes.RowFilter 	= FilterStr;

EndProcedure

&AtClient
// Procedure - event handler OnActivate of the Employees tabular section row.
//
Procedure EmployeesOnActivateRow(Item)
		
	DriveClient.SetFilterOnSubordinateTabularSection(ThisForm, "EarningsDeductions");
	DriveClient.SetFilterOnSubordinateTabularSection(ThisForm, "IncomeTaxes");
	
EndProcedure

&AtClient
// Procedure - handler of event OnStartEdit of tabular section Employees.
//
Procedure EmployeesOnStartEdit(Item, NewRow, Copy)
	
	If NewRow Then

		DriveClient.AddConnectionKeyToTabularSectionLine(ThisForm);
		DriveClient.SetFilterOnSubordinateTabularSection(ThisForm, "EarningsDeductions");
		DriveClient.SetFilterOnSubordinateTabularSection(ThisForm, "IncomeTaxes");
		
		TabularSectionRow = Items.Employees.CurrentData;
		TabularSectionRow.StructuralUnit = MainDepartment;
		
	EndIf;

EndProcedure

&AtClient
// Procedure - event handler BeforeDelete of tabular section Employees.
//
Procedure EmployeesBeforeDelete(Item, Cancel)

	DriveClient.DeleteRowsOfSubordinateTabularSection(ThisForm, "EarningsDeductions");
	DriveClient.DeleteRowsOfSubordinateTabularSection(ThisForm, "IncomeTaxes");

EndProcedure

&AtClient
// Procedure - event handler OnChange of the Employee of the Employees tabular section.
//
Procedure EmployeesEmployeeOnChange(Item)
	
	CurrentData = Items.Employees.CurrentData;
	CurrentData.Period = CurrentDate();
	
	If Object.OperationKind <> PredefinedValue("Enum.OperationTypesTransferAndPromotion.TransferAndPaymentFormChange") Then
		Return;
	EndIf;
	
	EmployeeStructure = New Structure();
	EmployeeStructure.Insert("Employee", CurrentData.Employee);
	EmployeeStructure.Insert("Period", CurrentData.Period);
	EmployeeStructure.Insert("Company", Object.Company);
	
	GetEmployeeData(EmployeeStructure);
	
	FillPropertyValues(CurrentData, EmployeeStructure);
		
	CurrentData.PreviousUnit = EmployeeStructure.StructuralUnit;
	CurrentData.PreviousJobTitle = EmployeeStructure.Position;
	CurrentData.PreviousCountOccupiedRates = EmployeeStructure.OccupiedRates;
	CurrentData.PreviousWorkSchedule = EmployeeStructure.WorkSchedule;
	
	If Not ValueIsFilled(CurrentData.StructuralUnit) Then
		CurrentData.StructuralUnit = MainDepartment;
	EndIf;	
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of the Period of the Employees tabular section.
//
Procedure EmployeesPeriodOnChange(Item)
	
	If Object.OperationKind <> PredefinedValue("Enum.OperationTypesTransferAndPromotion.TransferAndPaymentFormChange") Then
		Return;
	EndIf;
	
	CurrentData = Items.Employees.CurrentData;
	
	EmployeeStructure = New Structure();
	EmployeeStructure.Insert("Employee", CurrentData.Employee);
	EmployeeStructure.Insert("Period", CurrentData.Period);
	EmployeeStructure.Insert("Company", Object.Company);
	
	GetEmployeeData(EmployeeStructure);
	
	CurrentData.PreviousUnit = EmployeeStructure.StructuralUnit;
	CurrentData.PreviousJobTitle = EmployeeStructure.Position;
	CurrentData.PreviousCountOccupiedRates = EmployeeStructure.OccupiedRates;
	CurrentData.PreviousWorkSchedule = EmployeeStructure.WorkSchedule;
	
	If Not ValueIsFilled(CurrentData.StructuralUnit) AND Not ValueIsFilled(CurrentData.Position) AND Not ValueIsFilled(CurrentData.WorkSchedule) Then	
		FillPropertyValues(CurrentData, EmployeeStructure);	
	EndIf; 
	
EndProcedure

&AtClient
// Procedure - event handler OnStartEdit of tabular section DeductionEarnings.
//
Procedure EarningsDeductionsOnStartEdit(Item, NewRow, Copy)
	
	If NewRow Then
		DriveClient.AddConnectionKeyToSubordinateTabularSectionLine(ThisForm, Item.Name);
		TabularSectionRow = Items.EarningsDeductions.CurrentData;
		TabularSectionRow.Currency = CurrencyByDefault;
		TabularSectionRow.Actuality = True;
	EndIf;

EndProcedure

&AtClient
// Procedure - event handler BeforeAdditionStart of tabular section DeductionEarnings.
//
Procedure EarningsDeductionsBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	Cancel = DriveClient.BeforeAddToSubordinateTabularSection(ThisForm, Item.Name);
	
EndProcedure

&AtClient
// Procedure - event handler OnChange DeductionEarningKind of tabular section DeductionEarnings.
//
Procedure EarningsDeductionsEarningAndDeductionTypeOnChange(Item)
	
	DriveClient.PutExpensesGLAccountByDefault(ThisForm);
	
EndProcedure

&AtClient
// Procedure - event handler OnStartEdit of tabular section IncomeTaxes.
//
Procedure IncomeTaxesOnStartEdit(Item, NewRow, Copy)
	
	If NewRow Then
		DriveClient.AddConnectionKeyToSubordinateTabularSectionLine(ThisForm, Item.Name);
		TabularSectionRow = Items.IncomeTaxes.CurrentData;
		TabularSectionRow.Currency = CurrencyByDefault;
		TabularSectionRow.Actuality = True;
	EndIf;

EndProcedure

&AtClient
// Procedure - event handler BeforeAdditionStart of tabular section IncomeTaxes.
//
Procedure IncomeTaxesBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	Cancel = DriveClient.BeforeAddToSubordinateTabularSection(ThisForm, Item.Name);
	
EndProcedure

// Procedure - OnChange event handler of the Comment input field.
//
&AtClient
Procedure CommentOnChange(Item)
	
	AttachIdleHandler("Attachable_SetPictureForComment", 0.5, True);
	
EndProcedure

&AtClient
Procedure Attachable_SetPictureForComment()
	
	DriveClientServer.SetPictureForComment(Items.AdvancedPage, Object.Comment);
	
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

#EndRegion

