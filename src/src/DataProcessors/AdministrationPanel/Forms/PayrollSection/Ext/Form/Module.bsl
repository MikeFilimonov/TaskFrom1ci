
#Region Variables

&AtClient
Var RefreshInterface;

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure Attachable_OnAttributeChange(Item, RefreshingInterface = True)
	
	Result = OnAttributeChangeServer(Item.Name);
	
	If Result.Property("ErrorText") Then
		
		// There is no option to use CommonUseClientServer.ReportToUser as it is required to pass the UID forms
		CustomMessage = New UserMessage;
		Result.Property("Field", CustomMessage.Field);
		Result.Property("ErrorText", CustomMessage.Text);
		CustomMessage.TargetID = UUID;
		CustomMessage.Message();
		
		RefreshingInterface = False;
		
	EndIf;
	
	If RefreshingInterface Then
		AttachIdleHandler("RefreshApplicationInterface", 1, True);
		RefreshInterface = True;
	EndIf;
	
	If Result.Property("NotificationForms") Then
		Notify(Result.NotificationForms.EventName, Result.NotificationForms.Parameter, Result.NotificationForms.Source);
	EndIf;
	
EndProcedure

&AtClient
Procedure RefreshApplicationInterface()
	
	If RefreshInterface = True Then
		RefreshInterface = False;
		RefreshInterface();
	EndIf;
	
EndProcedure

// Procedure manages visible of the WEB Application group
//
&AtClient
Procedure VisibleManagement()
	
	#If Not WebClient Then
		
		CommonUseClientServer.SetFormItemProperty(Items, "WEBApplication", "Visible", False);
		
	#Else
		
		CommonUseClientServer.SetFormItemProperty(Items, "WEBApplication", "Visible", True);
		
	#EndIf
	
EndProcedure

&AtServer
Procedure SetEnabled(AttributePathToData = "")
	
	If AttributePathToData = "ConstantsSet.UsePayrollSubsystem" OR AttributePathToData = "" Then
		
		CommonUseClientServer.SetFormItemProperty(Items, "UsageSettings",	"Enabled", ConstantsSet.UsePayrollSubsystem);
		CommonUseClientServer.SetFormItemProperty(Items, "PayrollSectionCatalogs","Enabled", ConstantsSet.UsePayrollSubsystem);
		
		If Not ConstantsSet.UsePayrollSubsystem Then
			
			Constants.UseSecondaryEmployment.Set(False);
			Constants.UseHeadcountBudget.Set(False);
			Constants.UsePersonalIncomeTaxCalculation.Set(False);
			
		EndIf;
			
	EndIf;
	
	// there aren't dependent options requiring accessibility management in section
	
EndProcedure

&AtServer
Function OnAttributeChangeServer(ItemName)
	
	Result = New Structure;
	
	AttributePathToData = Items[ItemName].DataPath;
	
	ValidateAbilityToChangeAttributeValue(AttributePathToData, Result);
	
	If Result.Property("CurrentValue") Then
		
		// Rollback to previous value
		ReturnFormAttributeValue(AttributePathToData, Result.CurrentValue);
		
	Else
		
		SaveAttributeValue(AttributePathToData, Result);
		
		SetEnabled(AttributePathToData);
		
		RefreshReusableValues();
		
	EndIf;
	
	Return Result;
	
EndFunction

&AtServer
Procedure SaveAttributeValue(AttributePathToData, Result)
	
	// Save attribute values not connected with constants directly (one-to-one ratio).
	If AttributePathToData = "" Then
		Return;
	EndIf;
	
	// Definition of constant name.
	ConstantName = "";
	If Lower(Left(AttributePathToData, 13)) = Lower("ConstantsSet.") Then
		// If the path to attribute data is specified through "ConstantsSet".
		ConstantName = Mid(AttributePathToData, 14);
	Else
		// Definition of name and attribute value record in the corresponding constant from "ConstantsSet".
		// Used for the attributes of the form directly connected with constants (one-to-one ratio).
	EndIf;
	
	// Saving the constant value.
	If ConstantName <> "" Then
		ConstantManager = Constants[ConstantName];
		ConstantValue = ConstantsSet[ConstantName];
		
		If ConstantManager.Get() <> ConstantValue Then
			ConstantManager.Set(ConstantValue);
		EndIf;
		
		NotificationForms = New Structure("EventName, Parameter, Source", "Record_ConstantsSet", New Structure, ConstantName);
		Result.Insert("NotificationForms", NotificationForms);
	EndIf;
	
EndProcedure

// Procedure assigns the passed value to form attribute
//
// It is used if a new value did not pass the check
//
//
&AtServer
Procedure ReturnFormAttributeValue(AttributePathToData, CurrentValue)
	
	If AttributePathToData = "ConstantsSet.UsePayrollSubsystem" Then
		
		ConstantsSet.UsePayrollSubsystem = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.UseSecondaryEmployment" Then
		
		ConstantsSet.UseSecondaryEmployment = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.UsePersonalIncomeTaxCalculation" Then
		
		ConstantsSet.UsePersonalIncomeTaxCalculation = CurrentValue;
		
	EndIf;
	
EndProcedure

// Procedure to control the disabling of the "Use payroll by registers" option.
//
&AtServer
Function CheckRecordsByPayrollSubsystemRegisters()
	
	ErrorText = "";
	
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	EarningsAndDeductions.Company
	|FROM
	|	AccumulationRegister.EarningsAndDeductions AS EarningsAndDeductions
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	Payroll.Company
	|FROM
	|	AccumulationRegister.Payroll AS Payroll";
	
	ResultsArray = Query.ExecuteBatch();
	
	// 1. Register Earnings and deductions.
	If Not ResultsArray[0].IsEmpty() Then
		
		ErrorText = NStr("en = 'There are items in the ""Earnings and deductions"" catalog. To disable the payroll subsystem, delete these items.'");
		
	EndIf;
	
	// 2. Register Payroll payments.
	If Not ResultsArray[1].IsEmpty() Then
		
		ErrorText = ErrorText + ?(IsBlankString(ErrorText), "", Chars.LF) + NStr("en = '""Payroll"" document is already in use. To disable the payroll subsystem, delete this document.'");
		
	EndIf;
	
	Return ErrorText;
	
EndFunction

// Procedure to control the disabling of the "Use salary by documents and catalogs" option.
//
&AtServer
Function CancellationUncheckFunctionalOptionUsePayrollSubsystem()
	
	ErrorText = "";
	
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	Payroll.Ref
	|FROM
	|	Document.Payroll AS Payroll
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	EarningsAndDeductions.Company,
	|	JobSheet.Ref
	|FROM
	|	AccumulationRegister.EarningsAndDeductions AS EarningsAndDeductions
	|		LEFT JOIN Document.JobSheet AS JobSheet
	|		ON EarningsAndDeductions.Recorder = JobSheet.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	SalesOrderPerformers.Employee
	|FROM
	|	Document.SalesOrder.Performers AS SalesOrderPerformers
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	OpeningBalanceEntry.Ref
	|FROM
	|	Document.OpeningBalanceEntry AS OpeningBalanceEntry
	|WHERE
	|	OpeningBalanceEntry.AccountingSection = &AccountingSection
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	CashVoucher.Ref
	|FROM
	|	Document.CashVoucher AS CashVoucher
	|WHERE
	|	(CashVoucher.OperationKind = VALUE(Enum.OperationTypesCashVoucher.Salary)
	|			OR CashVoucher.OperationKind = VALUE(Enum.OperationTypesCashVoucher.SalaryForEmployee))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	PaymentExpense.Ref
	|FROM
	|	Document.PaymentExpense AS PaymentExpense
	|WHERE
	|	PaymentExpense.OperationKind = VALUE(Enum.OperationTypesPaymentExpense.Salary)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	Employees.Ref
	|FROM
	|	Catalog.Employees AS Employees
	|WHERE
	|	Employees.EmploymentContractType = VALUE(Enum.EmploymentContractTypes.PartTime)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	EarningAndDeductionTypes.Ref
	|FROM
	|	Catalog.EarningAndDeductionTypes AS EarningAndDeductionTypes
	|WHERE
	|	EarningAndDeductionTypes.Type = VALUE(Enum.EarningAndDeductionTypes.Tax)";
	
	Query.SetParameter("AccountingSection", "Personnel settlements");
	
	ResultsArray = Query.ExecuteBatch();
	
	// 1. Document Payroll.
	If Not ResultsArray[0].IsEmpty() Then
		
		ErrorText = NStr("en = '""Payroll"" document is already in use. To disable the payroll subsystem, delete this document.'");
		
	EndIf;
	
	// 2. The Job sheet document
	If Not ResultsArray[1].IsEmpty() Then
		
		ErrorText = ErrorText + ?(IsBlankString(ErrorText), "", Chars.LF) + NStr("en = '""Timesheet"" document is already in use. To disable the payroll subsystem, delete this document.'");
		
	EndIf;
	
	// 3. Document Order - order.
	If Not ResultsArray[2].IsEmpty() Then
		
		ErrorText = ErrorText + ?(IsBlankString(ErrorText), "", Chars.LF) + NStr("en = 'There are documents of the ""Work order"" kind in the infobase that are used to calculate employees'' salary. You cannot clear the ""Salary"" check box.'");
		
	EndIf;
	
	// 4. Document Enter opening balance.
	If Not ResultsArray[3].IsEmpty() Then
		
		ErrorText = ErrorText + ?(IsBlankString(ErrorText), "", Chars.LF) +  NStr("en = '""Opening balance entry"" document of ""Salary payable balance"" operation type is already in use. To disable the payroll subsystem, delete this document.'");
		
	EndIf;
	
	// 5. Document Cash payment.
	If Not ResultsArray[4].IsEmpty() Then
		
		ErrorText = ErrorText + ?(IsBlankString(ErrorText), "", Chars.LF) + NStr("en = '""Cash voucher"" document of ""Salary to employee"" or ""Payroll"" operation type is already in use. To disable the payroll subsystem, delete this document.'");
		
	EndIf;
	
	// 6. Document Payment expense.
	If Not ResultsArray[5].IsEmpty() Then
		
		ErrorText = ErrorText + ?(IsBlankString(ErrorText), "", Chars.LF) + NStr("en = '""Bank payment"" document of ""Payroll"" operation type is already in use. To disable the payroll subsystem, delete this document.'");
		
	EndIf;
	
	// 7. Catalog Employees.
	If Not ResultsArray[6].IsEmpty() Then
		
		ErrorText = ErrorText + ?(IsBlankString(ErrorText), "", Chars.LF) + NStr("en = 'There are secondary employment employees. To disable the payroll subsystem, delete these records.'");	
		
	EndIf;
	
	// 8. Catalog Earning and deduction types.
	If Not ResultsArray[7].IsEmpty() Then
		
		ErrorText = ErrorText + ?(IsBlankString(ErrorText), "", Chars.LF) + NStr("en = 'There are items in the ""Earnings and deductions"" catalog of the tax type. To disable the payroll subsystem, delete these items.'");
		
	EndIf;
	
	If IsBlankString(ErrorText) Then
		
		ErrorText = CheckRecordsByPayrollSubsystemRegisters();
		
	EndIf;
	
	Return ErrorText;
	
EndFunction

// Check on the possibility of option disable UseJobsharing.
//
&AtServer
Function CancellationUncheckFunctionalOptionUseJobsharing()
	
	ErrorText = "";
	
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	Employees.Ref
	|FROM
	|	Catalog.Employees AS Employees
	|WHERE
	|	Employees.EmploymentContractType = VALUE(Enum.EmploymentContractTypes.PartTime)";
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		
		ErrorText = NStr("en = 'There are secondary employment employees. To disable the secondary employment, delete these records.'");
		
	EndIf;
	
	Return ErrorText;
	
EndFunction

// Check on the possibility of option disable UsePersonalIncomeTaxCalculation.
//
&AtServer
Function CancellationUncheckFunctionalOptionAccountingDoIncomeTax()
	
	ErrorText = "";
	
	Query = New Query(
		"SELECT TOP 1
		|	EarningAndDeductionTypes.Ref
		|FROM
		|	Catalog.EarningAndDeductionTypes AS EarningAndDeductionTypes
		|WHERE
		|	EarningAndDeductionTypes.Type = VALUE(Enum.EarningAndDeductionTypes.Tax)"
	);
	
	QueryResult = Query.Execute();
	If Not QueryResult.IsEmpty() Then
		
		ErrorText = NStr("en = 'There are items in the ""Earnings and deductions"" catalog of the tax type. To disable the payroll subsystem, delete these items.'");	
		
	EndIf;
	
	Return ErrorText;
	
EndFunction

// Initialization of checking the possibility to disable the ForeignExchangeAccounting option.
//
&AtServer
Function ValidateAbilityToChangeAttributeValue(AttributePathToData, Result)
	
	// Enable/disable  Payroll section
	If AttributePathToData = "ConstantsSet.UsePayrollSubsystem" Then
	
		If Constants.UsePayrollSubsystem.Get() <> ConstantsSet.UsePayrollSubsystem
			AND (NOT ConstantsSet.UsePayrollSubsystem) Then
			
			ErrorText = CancellationUncheckFunctionalOptionUsePayrollSubsystem();
			If Not IsBlankString(ErrorText) Then 
				
				Result.Insert("Field", 				AttributePathToData);
				Result.Insert("ErrorText", 		ErrorText);
				Result.Insert("CurrentValue",	True);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	// If the catalog Employees there are part-time workers then it is not allowed to delete flag UseSecondaryEmployment
	If AttributePathToData = "ConstantsSet.UseSecondaryEmployment" Then
		
		If Constants.UseSecondaryEmployment.Get() <> ConstantsSet.UseSecondaryEmployment
			AND (NOT ConstantsSet.UseSecondaryEmployment) Then
			
			ErrorText = CancellationUncheckFunctionalOptionUseJobsharing();
			If Not IsBlankString(ErrorText) Then 
				
				Result.Insert("Field", 				AttributePathToData);
				Result.Insert("ErrorText", 		ErrorText);
				Result.Insert("CurrentValue",	True);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	// If there are catalog items "Earning and deduction kinds" with type "Tax" then it is not allowed to delete flag UsePersonalIncomeTaxCalculation
	If AttributePathToData = "ConstantsSet.UsePersonalIncomeTaxCalculation" Then
		
		If Constants.UsePersonalIncomeTaxCalculation.Get() <> ConstantsSet.UsePersonalIncomeTaxCalculation
			AND (NOT ConstantsSet.UsePersonalIncomeTaxCalculation) Then
			
			ErrorText = CancellationUncheckFunctionalOptionAccountingDoIncomeTax();
			If Not IsBlankString(ErrorText) Then 
				
				Result.Insert("Field", 				AttributePathToData);
				Result.Insert("ErrorText", 		ErrorText);
				Result.Insert("CurrentValue",	True);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndFunction

#Region FormCommandHandlers

// Procedure - command handler UpdateSystemParameters.
//
&AtClient
Procedure UpdateSystemParameters()
	
	RefreshInterface();
	
EndProcedure

#EndRegion

#EndRegion

#Region ProcedureFormEventHandlers

// Procedure - event handler OnCreateAtServer of the form.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	// Attribute values of the form
	RunMode = CommonUseReUse.ApplicationRunningMode();
	RunMode = New FixedStructure(RunMode);
	
	SetEnabled();
	
EndProcedure

// Procedure - event handler OnCreateAtServer of the form.
//
&AtClient
Procedure OnOpen(Cancel)
	
	VisibleManagement();
	
EndProcedure

// Procedure - event handler OnClose form.
//
&AtClient
Procedure OnClose(Exit)
	
	If Exit Then
		Return;
	EndIf;

	RefreshApplicationInterface();
	
EndProcedure

#Region ProcedureEventHandlersOfFormAttributes

// Procedure - event handler OnChange field UsePayrollSubsystem.
&AtClient
Procedure FunctionalOptionUseSubsystemPayrollOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

// Procedure - ref click handler FunctionalOptionDoStaffScheduleHelp.
//
&AtClient
Procedure FunctionalOptionDoStaffScheduleOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

// Procedure - event handler OnChange field FunctionalOptionUseJobsharing.
//
&AtClient
Procedure FunctionalOptionUseJobSharingOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

// Procedure - event handler OnChange field FunctionalOptionReflectIncomeTaxes.
&AtClient
Procedure FunctionalOptionToReflectIncomeTaxesOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

#EndRegion

#EndRegion