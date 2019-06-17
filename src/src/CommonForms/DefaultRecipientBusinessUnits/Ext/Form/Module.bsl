
#Region ProceduresAndFunctions

&AtServer
// Procedure fills the form parameters.
//
Procedure GetFormValuesOfParameters()
	
	TransferSource = Parameters.TransferSource;
	TransferRecipient = Parameters.TransferRecipient;
	RecipientOfWastes = Parameters.RecipientOfWastes;
	WriteOffToExpensesSource = Parameters.WriteOffToExpensesSource;
	WriteOffToExpensesRecipient	= Parameters.WriteOffToExpensesRecipient;
	PassToOperationSource = Parameters.PassToOperationSource;
	PassToOperationRecipient = Parameters.PassToOperationRecipient;
	ReturnFromOperationSource = Parameters.ReturnFromOperationSource;
	ReturnFromOperationRecipient = Parameters.ReturnFromOperationRecipient;
	
	TransferSourceCell = Parameters.TransferSourceCell;
	TransferRecipientCell = Parameters.TransferRecipientCell;
	DisposalsRecipientCell = Parameters.DisposalsRecipientCell;
	WriteOffToExpensesSourceCell = Parameters.WriteOffToExpensesSourceCell;
	WriteOffToExpensesRecipientCell = Parameters.WriteOffToExpensesRecipientCell;
	PassToOperationSourceCell = Parameters.PassToOperationSourceCell;
	PassToOperationRecipientCell = Parameters.PassToOperationRecipientCell;
	ReturnFromOperationSourceCell = Parameters.ReturnFromOperationSourceCell;
	ReturnFromOperationRecipientCell = Parameters.ReturnFromOperationRecipientCell;
	
EndProcedure

&AtClient
// Function puts the autotransfer parameters in object.
//
Function WriteAutotransferParametersToObject()
	
	ParametersAutoshift = New Structure;
	ParametersAutoshift.Insert("TransferSource", TransferSource);
	ParametersAutoshift.Insert("TransferRecipient", TransferRecipient);
	ParametersAutoshift.Insert("RecipientOfWastes", RecipientOfWastes);
	ParametersAutoshift.Insert("WriteOffToExpensesSource", WriteOffToExpensesSource);
	ParametersAutoshift.Insert("WriteOffToExpensesRecipient", WriteOffToExpensesRecipient);
	ParametersAutoshift.Insert("PassToOperationSource", PassToOperationSource);
	ParametersAutoshift.Insert("PassToOperationRecipient", PassToOperationRecipient);
	ParametersAutoshift.Insert("ReturnFromOperationSource", ReturnFromOperationSource);
	ParametersAutoshift.Insert("ReturnFromOperationRecipient", ReturnFromOperationRecipient);
	
	ParametersAutoshift.Insert("TransferSourceCell", TransferSourceCell);
	ParametersAutoshift.Insert("TransferRecipientCell", TransferRecipientCell);
	ParametersAutoshift.Insert("DisposalsRecipientCell", DisposalsRecipientCell);
	ParametersAutoshift.Insert("WriteOffToExpensesSourceCell", WriteOffToExpensesSourceCell);
	ParametersAutoshift.Insert("WriteOffToExpensesRecipientCell", WriteOffToExpensesRecipientCell);
	ParametersAutoshift.Insert("PassToOperationSourceCell", PassToOperationSourceCell);
	ParametersAutoshift.Insert("PassToOperationRecipientCell", PassToOperationRecipientCell);
	ParametersAutoshift.Insert("ReturnFromOperationSourceCell", ReturnFromOperationSourceCell);
	ParametersAutoshift.Insert("ReturnFromOperationRecipientCell", ReturnFromOperationRecipientCell);
	
	ParametersAutoshift.Insert("Modified", Modified);
	
	Return ParametersAutoshift;
	
EndFunction

&AtServer
// Procedure sets availability of the form items.
//
// Parameters:
//  No.
//
Procedure SetVisibleAndEnabled()

	If Parameters.StructuralUnitType = Enums.BusinessUnitsTypes.Warehouse Then
		
		Items.WriteOffToExpensesSource.Visible = False;
		Items.WriteOffToExpensesSourceCell.Visible = False;
		WriteOffToExpensesSource = Undefined;
		WriteOffToExpensesSourceCell = Undefined;
		
		If Not Constants.UseSeveralDepartments.Get() Then
		
			Items.WriteOffToExpensesRecipient.Visible = False;
			Items.WriteOffToExpensesRecipientCell.Visible = False;
			WriteOffToExpensesRecipient = Undefined;
			WriteOffToExpensesRecipientCell = Undefined;
			
		EndIf;	
			
		Items.PassToOperationSource.Visible = False;
		Items.PassToOperationSourceCell.Visible = False;
		PassToOperationSource = Undefined;
		PassToOperationSourceCell = Undefined;
		
		If Not Constants.UseSeveralDepartments.Get() Then
		
			Items.PassToOperationRecipient.Visible = False;
			Items.PassToOperationRecipientCell.Visible = False;
			PassToOperationRecipient = Undefined;
			PassToOperationRecipientCell = Undefined;
			
		EndIf;		
		
		Items.ReturnFromOperationRecipient.Visible = False;
		Items.ReturnFromOperationRecipientCell.Visible = False;
		ReturnFromOperationRecipient = Undefined;
		ReturnFromOperationRecipientCell = Undefined;
		
		If Not Constants.UseSeveralDepartments.Get() Then
		
			Items.ReturnFromOperationSource.Visible = False;
			Items.ReturnFromOperationSourceCell.Visible = False;
			ReturnFromOperationSource = Undefined;
			ReturnFromOperationSourceCell = Undefined;
			
		EndIf;		
		
	ElsIf Parameters.StructuralUnitType = Enums.BusinessUnitsTypes.Department Then	
		
		Items.WriteOffToExpensesRecipient.Visible = False;
		Items.WriteOffToExpensesRecipientCell.Visible = False;
		WriteOffToExpensesRecipient = Undefined;
		WriteOffToExpensesRecipientCell = Undefined;
		
		If Not Constants.UseSeveralWarehouses.Get() Then
			
			Items.WriteOffToExpensesSource.Visible = False;
			Items.WriteOffToExpensesSourceCell.Visible = False;
			WriteOffToExpensesSource = Undefined;
			WriteOffToExpensesSourceCell = Undefined;
			
		EndIf;		
		
		Items.PassToOperationRecipient.Visible = False;
		Items.PassToOperationRecipientCell.Visible = False;
		PassToOperationRecipient = Undefined;
		PassToOperationRecipientCell = Undefined;
		
		If Not Constants.UseSeveralWarehouses.Get() Then
			
			Items.PassToOperationSource.Visible = False;
			Items.PassToOperationSourceCell.Visible = False;
			PassToOperationSource = Undefined;
			PassToOperationSourceCell = Undefined;
			
		EndIf;
		
		Items.ReturnFromOperationSource.Visible = False;
		Items.ReturnFromOperationSourceCell.Visible = False;
		ReturnFromOperationSource = Undefined;
		ReturnFromOperationSourceCell = Undefined;
		
		If Not Constants.UseSeveralWarehouses.Get() Then
			
			Items.ReturnFromOperationRecipient.Visible = False;
			Items.ReturnFromOperationRecipientCell.Visible = False;
			ReturnFromOperationRecipient = Undefined;
			ReturnFromOperationRecipientCell = Undefined;
			
		EndIf;
		
	ElsIf Parameters.StructuralUnitType = Enums.BusinessUnitsTypes.Retail
		OR Parameters.StructuralUnitType = Enums.BusinessUnitsTypes.RetailEarningAccounting Then
		
		Items.RecipientOfWastes.Visible = False;
		Items.DisposalsRecipientCell.Visible = False;		
		RecipientOfWastes = Undefined;
		DisposalsRecipientCell = Undefined;
		
		Items.WriteOffToExpensesSource.Visible = False;
		Items.WriteOffToExpensesSourceCell.Visible = False;
		WriteOffToExpensesSource = Undefined;
		WriteOffToExpensesSourceCell = Undefined;
		
		Items.WriteOffToExpensesRecipient.Visible = False;
		Items.WriteOffToExpensesRecipientCell.Visible = False;
		WriteOffToExpensesRecipient = Undefined;
		WriteOffToExpensesRecipientCell = Undefined;
		
		Items.PassToOperationSource.Visible = False;
		Items.PassToOperationSourceCell.Visible = False;
		PassToOperationSource = Undefined;
		PassToOperationSourceCell = Undefined;
						
		Items.PassToOperationRecipient.Visible = False;
		Items.PassToOperationRecipientCell.Visible = False;
		PassToOperationRecipient = Undefined;
		PassToOperationRecipientCell = Undefined;
		
		Items.ReturnFromOperationSource.Visible = False;
		Items.ReturnFromOperationSourceCell.Visible = False;
		ReturnFromOperationSource = Undefined;
		ReturnFromOperationSourceCell = Undefined;	
		
		Items.ReturnFromOperationRecipient.Visible = False;
		Items.ReturnFromOperationRecipientCell.Visible = False;
		ReturnFromOperationRecipient = Undefined;
		ReturnFromOperationRecipientCell = Undefined;
		
	EndIf;	
	
	If Not ValueIsFilled(TransferSource)
		OR TransferSource.StructuralUnitType = Enums.BusinessUnitsTypes.Retail
		OR TransferSource.StructuralUnitType = Enums.BusinessUnitsTypes.RetailEarningAccounting Then
		
		Items.TransferSourceCell.Enabled = False;
		
	EndIf;
	
	If Not ValueIsFilled(TransferRecipient)
		OR TransferRecipient.StructuralUnitType = Enums.BusinessUnitsTypes.Retail
		OR TransferRecipient.StructuralUnitType = Enums.BusinessUnitsTypes.RetailEarningAccounting Then
		
		Items.TransferRecipientCell.Enabled = False;
		
	EndIf;
		
	If Not ValueIsFilled(RecipientOfWastes) Then
		
		Items.DisposalsRecipientCell.Enabled = False;
		
	EndIf;	
		
	If Not ValueIsFilled(WriteOffToExpensesSource) Then
		
		Items.WriteOffToExpensesSourceCell.Enabled = False;
		
	EndIf;
	
	If Not ValueIsFilled(WriteOffToExpensesRecipient) Then
		
		Items.WriteOffToExpensesRecipientCell.Enabled = False;
		
	EndIf;
		
	If Not ValueIsFilled(PassToOperationSource) Then
		
		Items.PassToOperationSourceCell.Enabled = False;
		
	EndIf;	
	
	If Not ValueIsFilled(PassToOperationRecipient) Then
		
		Items.PassToOperationRecipientCell.Enabled = False;
		
	EndIf;
	
	If Not ValueIsFilled(ReturnFromOperationSource) Then
		
		Items.ReturnFromOperationSourceCell.Enabled = False;
		
	EndIf;	
	
	If Not ValueIsFilled(ReturnFromOperationRecipient) Then
		
		Items.ReturnFromOperationRecipientCell.Enabled = False;
		
	EndIf;
	
EndProcedure

&AtServer
// The procedure sets the form attributes
// visible on the option Use subsystem Production.
//
// Parameters:
// No.
//
Procedure SetVisibleByFOUseProductionSubsystem()
	
	// Production.
	If Constants.UseProductionSubsystem.Get() Then
		
		// Warehouse. Setting the method of business unit selection depending on FO.
		If Not Constants.UseSeveralDepartments.Get()
			AND Not Constants.UseSeveralWarehouses.Get() Then
			
			Items.TransferSource.ListChoiceMode = True;
			Items.TransferSource.ChoiceList.Add(Catalogs.BusinessUnits.MainDepartment);
			Items.TransferSource.ChoiceList.Add(Catalogs.BusinessUnits.MainWarehouse);
			
			Items.TransferRecipient.ListChoiceMode = True;
			Items.TransferRecipient.ChoiceList.Add(Catalogs.BusinessUnits.MainDepartment);
			Items.TransferRecipient.ChoiceList.Add(Catalogs.BusinessUnits.MainWarehouse);
			
			Items.RecipientOfWastes.ListChoiceMode = True;
			Items.RecipientOfWastes.ChoiceList.Add(Catalogs.BusinessUnits.MainDepartment);
			Items.RecipientOfWastes.ChoiceList.Add(Catalogs.BusinessUnits.MainWarehouse);
		
		EndIf;
		
	Else
		
		If Constants.UseSeveralWarehouses.Get() Then
			
			NewArray = New Array();
			NewArray.Add(Enums.BusinessUnitsTypes.Warehouse);
			NewArray.Add(Enums.BusinessUnitsTypes.Retail);
			NewArray.Add(Enums.BusinessUnitsTypes.RetailEarningAccounting);
			ArrayTypesOfBusinessUnits = New FixedArray(NewArray);
			NewParameter = New ChoiceParameter("Filter.StructuralUnitType", ArrayTypesOfBusinessUnits);
			NewArray = New Array();
			NewArray.Add(NewParameter);
			NewParameters = New FixedArray(NewArray);
			
			Items.TransferSource.ChoiceParameters = NewParameters;
			Items.TransferRecipient.ChoiceParameters = NewParameters;
			Items.RecipientOfWastes.ChoiceParameters = NewParameters;
			
		Else
			
			Items.TransferSource.Visible = False;
			Items.TransferRecipient.Visible = False;
			Items.RecipientOfWastes.Visible = False;
			
		EndIf;
		
		If Parameters.StructuralUnitType = Enums.BusinessUnitsTypes.Department Then
			
			Items.TransferAssemblingDisassembling.Visible = False;
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region EventsHandlers

&AtServer
// Procedure - event handler OnCreateAtServer of the form.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	GetFormValuesOfParameters();
	
	SetVisibleAndEnabled();
	
	// FO Use Production subsystem.
	SetVisibleByFOUseProductionSubsystem();
	
EndProcedure

&AtClient
// Procedure - OK button click handler.
//
Procedure CommandOK(Command)
	
	Close(WriteAutotransferParametersToObject());
	
EndProcedure

#Region ProcedureEventHandlersOfFormAttributes

&AtClient
// Procedure - event handler OnChange of WriteOffToExpensesRecipient field.
//
Procedure WriteOffToExpensesRecipientOnChange(Item)
	
	If ValueIsFilled(WriteOffToExpensesRecipient) Then
		Items.WriteOffToExpensesRecipientCell.Enabled = True;
	Else
		Items.WriteOffToExpensesRecipientCell.Enabled = False;
	EndIf;	
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of PassToOperationRecipient field.
//
Procedure PassToOperationRecipientOnChange(Item)
	
	If ValueIsFilled(PassToOperationRecipient) Then
		Items.PassToOperationRecipientCell.Enabled = True;
	Else
		Items.PassToOperationRecipientCell.Enabled = False;
	EndIf;	
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of ReturnFromOperationSource field.
//
Procedure ReturnFromOperationSourceOnChange(Item)
	
	If ValueIsFilled(ReturnFromOperationSource) Then
		Items.ReturnFromOperationSourceCell.Enabled = True;
	Else
		Items.ReturnFromOperationSourceCell.Enabled = False;
	EndIf;	
	
EndProcedure

&AtClient
// Procedure - event handler Open of TransferSource field.
//
Procedure TransferSourceOpening(Item, StandardProcessing)
	
	If Items.TransferSource.ListChoiceMode
		AND Not ValueIsFilled(TransferSource) Then
		
		StandardProcessing = False;
		
	EndIf;
	
EndProcedure

&AtClient
// Procedure - event handler Open of TransferRecipient field.
//
Procedure TransferRecipientOpening(Item, StandardProcessing)
	
	If Items.TransferRecipient.ListChoiceMode
		AND Not ValueIsFilled(TransferRecipient) Then
		
		StandardProcessing = False;
		
	EndIf;
	
EndProcedure

&AtClient
// Procedure - event handler Open of RecipientOfWastes field.
//
Procedure RecipientOfWastesOpening(Item, StandardProcessing)
	
	If Items.RecipientOfWastes.ListChoiceMode
		AND Not ValueIsFilled(RecipientOfWastes) Then
		
		StandardProcessing = False;
		
	EndIf;
	
EndProcedure

#EndRegion

#EndRegion
