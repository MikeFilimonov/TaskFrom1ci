﻿
#Region ProgramInterface

// Returns the current date adjusted to the time zone of the session.
// It is intended to use instead of the function CurrentDate().
//
Function SessionDate() Export
	
	Return CurrentDate();
	
EndFunction

// Function returns the driver handler object by its description.
//
Function GetDriverHandler(DriverHandler, ImportedDriver) Export
	
	Result = PeripheralsUniversalDriverClient;
	
	If Not ImportedDriver AND DriverHandler <> Undefined Then
		
		// Bar code scanners
		
		// End Barcode scanners
		
		// Magnetic card readers
		
		// End Mangnetic cards readers.

		// Fiscal cash registers
		If DriverHandler = PredefinedValue("Enum.PeripheralDriverHandlers.HandlerZekaFiscalRegisters") Then
			Return PeripheralsZekaFiscalRegistrarsClient;
		ElsIf DriverHandler = PredefinedValue("Enum.PeripheralDriverHandlers.HandlerTremolFiscalRegisters") Then
			Return PeripheralsTremolFiscalRegistrarsClient;
		EndIf;
		
		// End Fiscal registers.

		// Customer displays
		
		// End Customners displays
		
		// Data collection terminals
		
		// End Data collection terminals.
		
		// POS terminals
		
		// End POS-Terminals.
		 
		// Electronic scales
		
		// End Electronic scales
		
		// Labels printing scales
		
		// End  Scales with label.
		
		// CR offline
		
		// End CR offline
		
	EndIf;

	Return Result;
	
EndFunction

// Prints a fiscal receipt.
//
Function ReceiptPrint(EquipmentCommonModule, DriverObject, Parameters, ConnectionParameters, InputParameters, Output_Parameters, OutputMessageToUser = False) Export
	
	ProductsTable = InputParameters[0];
	PaymentsTable        = InputParameters[1];
	CommonParameters      = InputParameters[2];
		                 
	Result  = True;
	// Open receipt
	Result = EquipmentCommonModule.OpenReceipt(DriverObject, Parameters, ConnectionParameters,
	                       CommonParameters[0] = 1, CommonParameters[1], Output_Parameters);

	// Print receipt rows   
	If Result Then
		ErrorOnLinePrinting = False;
		// Print receipt rows
		For ArrayIndex = 0 To ProductsTable.Count() - 1 Do
			Description  = ProductsTable[ArrayIndex][0].Value;
			Quantity    = ProductsTable[ArrayIndex][5].Value;
			Price          = ProductsTable[ArrayIndex][4].Value;
			DiscountPercent = ProductsTable[ArrayIndex][8].Value;
			Amount         = ProductsTable[ArrayIndex][9].Value;
			SectionNumber   = ProductsTable[ArrayIndex][3].Value;
			VATRate     = ProductsTable[ArrayIndex][12].Value;

			If Not EquipmentCommonModule.PrintFiscalLine(DriverObject, Parameters, ConnectionParameters,
											   Description, Quantity, Price, DiscountPercent, Amount,
											   SectionNumber, VATRate, Output_Parameters) Then
				ErrorOnLinePrinting = True;   
				Break;
			EndIf;
			
		EndDo;

		If Not ErrorOnLinePrinting Then
		  	// Close receipt
			Result = EquipmentCommonModule.CloseReceipt(DriverObject, Parameters, ConnectionParameters, PaymentsTable, Output_Parameters);	
		Else
			Result = False;
		EndIf;
		
	EndIf;

	Return Result;
	
EndFunction

#EndRegion

#Region WorkWithFormInstanceEquipment

// Additional overridable actions with handled form
// in the Equipment instance on "OnOpen" event.
//
Procedure EquipmentInstanceOnOpen(Object, ThisForm, Cancel) Export
	
EndProcedure

// Additional overridable actions with handled form
// in the Equipment instance on "BeforeClose" event.
//
Procedure EquipmentInstanceBeforeClose(Object, ThisForm, Cancel, StandardProcessing) Export
	
EndProcedure

// Additional overridable actions with handled form
// in the Equipment instance on "BeforeWrite" event.
//
Procedure EquipmentInstanceBeforeWrite(Object, ThisForm, Cancel, WriteParameters) Export
	
EndProcedure

// Additional overridable actions with handled form
// in the Equipment instance on "AfterWrite" event.
//
Procedure EquipmentInstanceAfterWrite(Object, ThisForm, WriteParameters) Export
	
EndProcedure

// Additional overridable actions with handled form
// in the Equipment instance on "EquipmentTypeChoiceProcessing" event.
//
Procedure EquipmentInstanceEquipmentTypeSelection(Object, ThisForm, ThisObject, Item, ValueSelected) Export
	
EndProcedure

#EndRegion

#Region EquipmentConnectionDisconnectionProcedures

// Start enabling required devices types during form opening
//
// Parameters:
// Form - ManagedForm
// SupportedPeripheralTypes - String
// 	Contains peripherals types list separated by commas.
//
Procedure StartConnectingEquipmentOnFormOpen(Form, SupportedPeripheralTypes) Export
	
	AlertOnConnect = New NotifyDescription("ConnectEquipmentEnd", EquipmentManagerClientOverridable);
	EquipmentManagerClient.StartConnectingEquipmentOnFormOpen(AlertOnConnect, Form, SupportedPeripheralTypes);
	
EndProcedure

Procedure ConnectEquipmentEnd(ExecutionResult, Parameters) Export
	
	If Not ExecutionResult.Result Then
		MessageText = NStr("en = 'An error occurred when connecting the equipment:""%ErrorDetails%"".'");
		MessageText = StrReplace(MessageText, "%ErrorDetails%" , ExecutionResult.ErrorDetails);
		CommonUseClientServer.MessageToUser(MessageText);
	EndIf;
	
EndProcedure

// Start disconnecting peripherals by type on closing the form.
//
Procedure StartDisablingEquipmentOnCloseForm(Form) Export
	
	AlertOnDisconnect = New NotifyDescription("DisableEquipmentEnd", EquipmentManagerClientOverridable); 
	EquipmentManagerClient.StartDisablingEquipmentOnCloseForm(AlertOnDisconnect, Form);
	
EndProcedure

Procedure DisableEquipmentEnd(ExecutionResult, Parameters) Export
	
	If Not ExecutionResult.Result Then
		MessageText = NStr("en = 'An error occurred when disconnecting the equipment: ""%ErrorDescription%"".'");
		MessageText = StrReplace(MessageText, "%ErrorDescription%" , ExecutionResult.ErrorDescription);
		CommonUseClientServer.MessageToUser(MessageText);
	EndIf;
	
EndProcedure

#EndRegion
