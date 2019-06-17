#Region ServiceHandlers

&AtClient
// Procedure changes the current row of the Employees tabular section
//
Procedure ChangeCurrentEmployee()
	
	Items.Employees.CurrentRow = CurrentEmployee;
	
EndProcedure

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
	
	If Not Constants.UseSecondaryEmployment.Get() Then
		If Items.Find("EmployeesEmployeeCode") <> Undefined Then
			Items.EmployeesEmployeeCode.Visible = False;
		EndIf;
	EndIf;
	
	User = Users.CurrentUser();
	
	SettingValue = DriveReUse.GetValueByDefaultUser(User, "MainDepartment");
	MainDepartment = ?(ValueIsFilled(SettingValue), SettingValue, Catalogs.BusinessUnits.MainDepartment);
	
	TaxAccounting = GetFunctionalOption("UsePersonalIncomeTaxCalculation");
	CommonUseClientServer.SetFormItemProperty(Items, "CurrentEmployeeTaxes", "Visible", TaxAccounting);
	If Not TaxAccounting Then
		
		Items.Employees.ExtendedTooltip.Title = 
			NStr("en = 'Earnings and deductions are specified on the corresponding page for each employee individually.'");
			
	EndIf;
		
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
		If Not ValueIsFilled(TabularSectionRow.StructuralUnit) Then
			
			TabularSectionRow.StructuralUnit = MainDepartment;
			
		EndIf;
		
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
	
	Items.Employees.CurrentData.OccupiedRates = 1;
	
EndProcedure

&AtClient
// Procedure - event handler OnStartEdit of tabular section DeductionEarnings.
//
Procedure EarningsDeductionsOnStartEdit(Item, NewRow, Copy)
	
	If NewRow Then
		DriveClient.AddConnectionKeyToSubordinateTabularSectionLine(ThisForm, Item.Name);
		TabularSectionRow = Items.EarningsDeductions.CurrentData;
		TabularSectionRow.Currency = CurrencyByDefault;
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

