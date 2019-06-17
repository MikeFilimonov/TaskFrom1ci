
#Region ServiceProceduresAndFunctions

// Procedure sets availability of the form items.
//
// Parameters:
//  No.
//
&AtClient
Procedure SetVisibleAndEnabled()
	
	If Object.Type = Tax Then
		
		Object.GLExpenseAccount		= Undefined;		
		Items.GroupFormula.Visible	= False;
		Object.Formula				= "";		
		Items.TaxKind.Visible		= True;
		
	Else
		
		Items.GroupFormula.Visible	= True;	
		Items.TaxKind.Visible		= False;
		Object.TaxKind				= Undefined;
		
	EndIf;
	
EndProcedure

// Procedure sets the values dependending on the type selected
//
&AtServer
Procedure OnChangeEarningKindTypelAtServer(EarningKindType)
	
	If EarningKindType = Enums.EarningAndDeductionTypes.Deduction Then		
		Object.GLExpenseAccount = Catalogs.DefaultGLAccounts.GetDefaultGLAccount("PayrollExpenses");		
	Else	
		Object.GLExpenseAccount = Catalogs.DefaultGLAccounts.GetDefaultGLAccount("Expenses");		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormEventsHandlers

// Event handler procedure
// OnCreateAtServer Performs initial form attribute filling.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Tax			= Enums.EarningAndDeductionTypes.Tax;
	Deduction	= Enums.EarningAndDeductionTypes.Deduction;
	
	If Not Constants.UsePersonalIncomeTaxCalculation.Get() Then
		
		ItemOfList = Items.Type.ChoiceList.FindByValue(Enums.EarningAndDeductionTypes.Tax);
		If ItemOfList <> Undefined Then
			
			Items.Type.ChoiceList.Delete(ItemOfList);
			
		EndIf;
		
	EndIf; 
	
	IsTax = (Object.Type = Tax);
	CommonUseClientServer.SetFormItemProperty(Items, "TaxKind", "Visible", IsTax);
	CommonUseClientServer.SetFormItemProperty(Items, "GroupFormula", "Visible", Not IsTax);
	
	If NOT ValueIsFilled(Object.GLExpenseAccount) Then
		OnChangeEarningKindTypelAtServer(Object.Type);
	EndIf;
	
	// StandardSubsystems.ObjectsAttributesEditProhibition
	ObjectsAttributesEditProhibition.LockAttributes(ThisForm);
	// End StandardSubsystems.ObjectsAttributesEditProhibition
	
EndProcedure

// Event handler procedure AfterWriteAtServer
//
&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	// StandardSubsystems.ObjectsAttributesEditProhibition
	ObjectsAttributesEditProhibition.LockAttributes(ThisForm);
	// End StandardSubsystems.ObjectsAttributesEditProhibition
	
EndProcedure

// Event handler procedure NotificationProcessing
//
&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "AccountsChangedEarningAndDeductionTypes" Then
		
		Object.GLExpenseAccount = Parameter.GLExpenseAccount;
		Modified = True;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

// Procedure is called when clicking the "Edit calculation formula" buttons. 
//
&AtClient
Procedure CommandEditCalculationFormula(Command)
	
	ParametersStructure = New Structure("FormulaText", Object.Formula);
	Notification = New NotifyDescription("CommandEditFormulaOfCalculationEnd",ThisForm);
	OpenForm("Catalog.EarningAndDeductionTypes.Form.CalculationFormulaEditForm", ParametersStructure,,,,, Notification);
	
EndProcedure

&AtClient
Procedure CommandEditFormulaOfCalculationEnd(FormulaText,Parameters) Export

	If TypeOf(FormulaText) = Type("String") Then
		Object.Formula = FormulaText;
	EndIf;

EndProcedure

#EndRegion

#Region FormAttributesHandlers

// Event handler procedure OnChange of input field LegalEntityIndividual.
//
&AtClient
Procedure TypeOnChange(Item)
	
	SetVisibleAndEnabled();
	OnChangeEarningKindTypelAtServer(Object.Type);
	
EndProcedure

#EndRegion

#Region LibrariesHandlers

// StandardSubsystems.ObjectsAttributesEditProhibition
&AtClient
Procedure Attachable_AllowObjectAttributesEditing(Command)
	
	ObjectsAttributesEditProhibitionClient.AllowObjectAttributesEditing(ThisForm);
	
EndProcedure
// End

#EndRegion