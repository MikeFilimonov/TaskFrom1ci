﻿                                            
#Region ProgramInterface

// Function connects a device.
//
// Parameters:
//  DriverObject   - <*>
//           - DriverObject of a trading equipment driver.
//
// Returns:
//  <Boolean> - Result of the function work.
//
Function ConnectDevice(DriverObject, Parameters, ConnectionParameters, Output_Parameters) Export

	Result = True;
	Output_Parameters = New Array();
	ConnectionParameters.Insert("DeviceID", Undefined);
	
	EquipmentType = "";
	
	If ConnectionParameters.Property("EquipmentType") Then
		EquipmentType = ConnectionParameters.EquipmentType;
		// Predefined parameter with the indication of driver type.
		Try
			DriverObject.УстановитьПараметр("EquipmentType", EquipmentType) 
		Except
			Result = False;
			Output_Parameters.Add(999);
			Output_Parameters.Add(NStr("en = 'An error occurred while accessing the driver.'"));
			Return Result;
		EndTry;
	EndIf;
		
	For Each Parameter In Parameters Do
		If Left(Parameter.Key, 2) = "P_" Then
			ParameterValue = Parameter.Value;
			ParameterName = Mid(Parameter.Key, 3);
			DriverObject.УстановитьПараметр(ParameterName, ParameterValue) 
		EndIf;
	EndDo;
	  
	Response = DriverObject.Подключить(ConnectionParameters.DeviceID);
	
	If Not Response Then
		Result = False;
		Output_Parameters.Add(999);
		Output_Parameters.Add("");
		DriverObject.ПолучитьОшибку(Output_Parameters[1])
	Else
		If EquipmentType = "POSTerminal" Then
			ConnectionParameters.Insert("OriginalTransactionCode", Undefined);
			ConnectionParameters.Insert("OperationKind", "");
		ElsIf EquipmentType = "BarCodeScanner" Then
			Output_Parameters.Add(String(ConnectionParameters.DeviceID));
			Output_Parameters.Add(New Array());
			Output_Parameters[1].Add("Barcode");
			Output_Parameters[1].Add("Barcode");
		ElsIf EquipmentType = "MagneticCardReader" Then
			Output_Parameters.Add(String(ConnectionParameters.DeviceID));
			Output_Parameters.Add(New Array());
			Output_Parameters[1].Add("CardData");
			Output_Parameters[1].Add("TracksData");
		EndIf;
	EndIf;
	
	Return Result;
	
EndFunction

// Function disconnects a device.
//
// Parameters:
//  DriverObject - <*>
//         - DriverObject of a trading equipment driver.
//
// Returns:
//  <Boolean> - Result of the function work.
//
Function DisableDevice(DriverObject, Parameters, ConnectionParameters, Output_Parameters) Export
	
	Result = True;
	
	Output_Parameters = New Array();
	
	DriverObject.Отключить(ConnectionParameters.DeviceID);
	
	Return Result;
	
EndFunction

// The function receives, processes and redirects for execution a command to the driver.
//
Function RunCommand(Command, InputParameters = Undefined, Output_Parameters = Undefined,
                         DriverObject, Parameters, ConnectionParameters) Export
	
	Result = True;
	
	Output_Parameters = New Array();
	
	// PROCEDURES AND FUNCTIONS OVERALL FOR ALL DRIVER TYPES
	
	// Test device
	If Command = "DeviceTest" OR Command = "CheckHealth" Then
		Result = DeviceTest(DriverObject, Parameters, ConnectionParameters, Output_Parameters);
		
	ElsIf Command = "ExecuteAdditionalAction" OR Command = "DoAdditionalAction" Then
		NameActions = InputParameters[0];
		Result = ExecuteAdditionalAction(DriverObject, Parameters, ConnectionParameters, NameActions, Output_Parameters);
		
	// Receive driver version
	ElsIf Command = "GetDriverVersion" OR Command = "GetVersion" Then
		Result = GetDriverVersion(DriverObject, Parameters, ConnectionParameters, Output_Parameters);
		
	// Get the driver description.
	ElsIf Command = "GetDriverDescription" OR Command = "GetDescription" Then
		Result = GetDriverDescription(DriverObject, Parameters, ConnectionParameters, Output_Parameters);
		
	// PROCEDURES AND FUNCTIONS OVERALL FOR WORK WITH DATA INPUT DEVICES
	
	// Processing the event from device.
	ElsIf Command = "ProcessEvent" Then
		Event = InputParameters[0];
		Data  = InputParameters[1];
		Result = ProcessEvent(DriverObject, Parameters, ConnectionParameters, Event, Data, Output_Parameters);
		
	// PROCEDURES AND FUNCTIONS OVERALL FOR WORK WITH FISCAL REGISTERS
	
	// Cash session open
	ElsIf Command = "OpenDay" OR Command = "OpenSession" Then
		Result = OpenSession(DriverObject, Parameters, ConnectionParameters, Output_Parameters);
		
	// Print report without blanking
	ElsIf Command = "PrintXReport" OR Command = "PrintReportWithoutBlanking" Then
		Result = PrintReportWithoutBlanking(DriverObject, Parameters, ConnectionParameters, Output_Parameters);
		
	// Print report with blanking
	ElsIf Command = "PrintZReport" OR Command = "PrintReportWithBlanking" Then
		Result = PrintReportWithBlanking(DriverObject, Parameters, ConnectionParameters, Output_Parameters);
		
	// Print receipt
	ElsIf Command = "PrintReceipt" OR Command = "ReceiptPrint" Then
		Result = ReceiptPrint(DriverObject, Parameters, ConnectionParameters, InputParameters, Output_Parameters);
		
	// Print slip receipt
	ElsIf Command = "PrintText" OR Command = "PrintText"  Then
		TextString = InputParameters[0];
		Result = PrintText(DriverObject, Parameters, ConnectionParameters,
		                         TextString, Output_Parameters);
	// Cancel an opened receipt
	ElsIf Command = "OpenCheck" OR Command = "OpenReceipt"  Then
		ReturnReceipt   = InputParameters[0];
		FiscalReceipt = InputParameters[1];
		Result = OpenReceipt(DriverObject, Parameters, ConnectionParameters, ReturnReceipt, FiscalReceipt, Output_Parameters);
		
	// Cancel an opened receipt
	ElsIf Command = "CancelCheck" OR Command = "CancelReceipt"  Then
		Result = CancelReceipt(DriverObject, Parameters, ConnectionParameters, Output_Parameters);
		
	// Print deposit/withdrawal receipt.
	ElsIf Command = "Encash" OR Command = "Encashment" Then
		EncashmentType = InputParameters[0];
		Amount         = InputParameters[1];
		Result = Encashment(DriverObject, Parameters, ConnectionParameters, EncashmentType, Amount, Output_Parameters);
		
	ElsIf Command = "PrintBarCode" OR Command = "PrintBarcode" Then
		BarCodeType = InputParameters[0];
		Barcode     = InputParameters[1];
		Result = PrintBarcode(DriverObject, Parameters, ConnectionParameters, BarCodeType, Barcode, Output_Parameters);
		
	// Open cash box
	ElsIf Command = "OpenCashDrawer" OR Command = "OpenCashDrawer" Then
		Result = OpenCashDrawer(DriverObject, Parameters, ConnectionParameters, Output_Parameters);
		
	// Get the width of rows in characters.
	ElsIf Command = "GetLineLength" OR Command = "GetRowWidth" Then
		Result = GetRowWidth(DriverObject, Parameters, ConnectionParameters, Output_Parameters);
		                                      
	// GENERAL PROCEDURES AND FUNCTIONS OF POS TERMINALS
	
	// Function returns whether the slip receipts will be printed on the terminal.
	ElsIf Command = "PrintSlipOnTerminal" OR Command = "ReceiptsPrintOnTerminal" Then
		Result = ReceiptsPrintOnTerminal(DriverObject, Parameters, ConnectionParameters, Output_Parameters);
		
	// Payment by a payment card
	ElsIf Command = "AuthorizeSales" OR Command = "PayByPaymentCard" Then
		Amount      = InputParameters[0];
		CardNumber = InputParameters[1];
		ReceiptNumber  = ?(InputParameters.Count() > 2, InputParameters[2], "");
		Result = PayByPaymentCard(DriverObject, Parameters, ConnectionParameters,
                                            Amount,  CardNumber, ReceiptNumber, Output_Parameters);
	// Payment return
	ElsIf Command = "AuthorizeRefund" OR Command = "ReturnPaymentByPaymentCard" Then
		Amount          = InputParameters[0];
		CardNumber     = InputParameters[1];
		RefNo = ?(InputParameters.Count() > 2, InputParameters[2], "");
		ReceiptNumber      = ?(InputParameters.Count() > 3, InputParameters[3], "");
		Result = ReturnPaymentByPaymentCard(DriverObject, Parameters, ConnectionParameters,
		                                          Amount, CardNumber, RefNo, ReceiptNumber, Output_Parameters);
	// Cancel payment
	ElsIf Command = "AuthorizeVoid" OR Command = "CancelPaymentByPaymentCard" Then
		Amount          = InputParameters[0];
		RefNo = InputParameters[1];
		ReceiptNumber      = ?(InputParameters.Count() > 2, InputParameters[2], "");
		Result = CancelPaymentByPaymentCard(DriverObject, Parameters, ConnectionParameters,
		                                           Amount, RefNo, ReceiptNumber, Output_Parameters);
	// Totals Revision by Cards
	ElsIf Command = "Settlement" OR Command = "DayTotalsByCards" Then
		Result = DayTotalsByCards(DriverObject, Parameters, ConnectionParameters, Output_Parameters);
		
	// Emergency payment cancellation
	ElsIf Command = "EmergencyVoid" OR Command = "EmergencyCancelOperations" Then
		Amount          = InputParameters[0];
		RefNo           = InputParameters[1];
		ReceiptNumber   = ?(InputParameters.Count() > 2, InputParameters[2], "");
		Result = EmergencyCancelOperations(DriverObject, Parameters, ConnectionParameters,
		                                    Amount, RefNo, ReceiptNumber, Output_Parameters);
		
	// Payment preauthorization
	ElsIf Command = "AuthorizePreSales" OR Command = "PreautorizationByPaymentCard" Then
		Amount         = InputParameters[0];
		CardNumber     = InputParameters[1];
		ReceiptNumber  = ?(InputParameters.Count() > 2, InputParameters[2], "");
		Result = PreauthorizeByPaymentCard(DriverObject, Parameters, ConnectionParameters,
		                                           Amount, CardNumber, ReceiptNumber, Output_Parameters);
		
	// Cancel preauthorization of payment.
	ElsIf Command = "AuthorizeVoidPreSales" OR Command = "CancelPreauthorizationByPaymentCard" Then
		Amount         = InputParameters[0];
		CardNumber     = InputParameters[1];
		RefNo          = ?(InputParameters.Count() > 2, InputParameters[2], "");
		ReceiptNumber  = ?(InputParameters.Count() > 3, InputParameters[3], "");
		Result = CancelPreauthorizationByPaymentCard(DriverObject, Parameters, ConnectionParameters,
		                                                   Amount, CardNumber, RefNo, ReceiptNumber, Output_Parameters);
	
	// Ends preauthorization of the payment.
	ElsIf Command = "AuthorizeCompletion" OR Command = "FinishPreauthorizationByPaymentCard" Then
		Amount         = InputParameters[0];
		CardNumber     = InputParameters[1];
		RefNo          = ?(InputParameters.Count() > 2, InputParameters[2], "");
		ReceiptNumber  = ?(InputParameters.Count() > 3, InputParameters[3], "");
		Result = FinishPreauthorizationByPaymentCard(DriverObject, Parameters, ConnectionParameters,
															Amount, CardNumber, RefNo, ReceiptNumber, Output_Parameters);
		
	// GENERAL PROCEDURES AND FUNCTIONS OF DATA COLLECTION TERMINALS
	
	// Importing a table to the data collection terminal.
	ElsIf Command =  "ImportDirectory" OR Command = "ExportTable" Then
		ExportingTable = InputParameters[1];
		Result = ExportTable(DriverObject, Parameters, ConnectionParameters,
		                             ExportingTable, Output_Parameters);
	// Exporting a table from the data collection terminal.
	ElsIf Command = "ExportDocument" OR Command = "Import_Table" Then
		Result = Import_Table(DriverObject, Parameters, ConnectionParameters, Output_Parameters);
		
	// Clears a table previously imported to the data collection terminal.
	ElsIf Command = "ClearTable" OR Command = "ClearTable" Then
		Result = ClearTable(DriverObject, Parameters, ConnectionParameters, Output_Parameters);
		
	// GENERAL PROCEDURES AND FUNCTIONS OF CUSTOMER DISPLAYS
	
	// Output of lines on a display
	ElsIf Command = "DisplayText" OR Command = "OutputLineToCustomerDisplay" Then
		TextString = InputParameters[0];
		Result = OutputLineToCustomerDisplay(DriverObject, Parameters, ConnectionParameters, TextString, Output_Parameters);
		
	// Display clearing
	ElsIf Command = "ClearText" OR Command = "ClearCustomerDisplay" Then
		Result = ClearCustomerDisplay(DriverObject, Parameters, ConnectionParameters, Output_Parameters);
		
	// Get output parameters
	ElsIf Command = "GetOutputOptions" OR Command = "GetOutputParameters" Then
		Result = GetOutputParameters(DriverObject, Parameters, ConnectionParameters, Output_Parameters);
		
	// COMMON PROCEDURES AND FUNCTIONS OF E-SCALES
	
	// Get weight 
	ElsIf Command = "GetWeight" OR Command = "GetWeight" Then
		Result = GetWeight(DriverObject, Parameters, ConnectionParameters, Output_Parameters);
		
	// Set packaging weight 
	ElsIf Command = "Calibrate" OR Command = "Tare" Then
		TareWeight = ?(TypeOf(InputParameters) = Type("Array") AND InputParameters.Count() > 0, InputParameters[0], Undefined);
		Result = Tare(DriverObject, Parameters, ConnectionParameters, Output_Parameters, TareWeight);
		
	// COMMON PROCEDURES AND FUNCTIONS OF SCALES WITH LABEL PRINTING
	
	// Export products to the scales with labels print.
	ElsIf Command = "ImportGoods" OR Command = "ExportProducts" Then
		ExportingTable   = InputParameters[0];
		PartialExport = InputParameters[1];
		Result = ExportProducts(DriverObject, Parameters, ConnectionParameters, ExportingTable, PartialExport, Output_Parameters);
		
	// Clear the base of scales with printing labels.
	ElsIf Command = "ClearBase" OR Command = "ClearBase" Then
		Result = ClearProductsInScales(DriverObject, Parameters, ConnectionParameters, Output_Parameters);
	
	// This command is not supported by the current driver.
	Else
		Output_Parameters.Add(999);
		Output_Parameters.Add(NStr("en = 'The %Command% command is not supported by the driver.'"));
		Output_Parameters[1] = StrReplace(Output_Parameters[1], "%Command%", Command);
		Result = False;
		
	EndIf;
	
	Return Result;

EndFunction

#EndRegion

#Region ProceduresAndFunctionsCommonForDataInputDevices

// Function processes external data of peripheral.
//
Function ProcessEvent(DriverObject, Parameters, ConnectionParameters, Event, Data, Output_Parameters) Export
	
	Result = True;
	
	If Event = "Barcode" Or Event = "Barcode" Then
		
		Barcode = TrimAll(Data);
		Output_Parameters.Add("ScanData");
		Output_Parameters.Add(New Array());
		Output_Parameters[1].Add(Barcode);
		Output_Parameters[1].Add(New Array());
		Output_Parameters[1][1].Add(Data);
		Output_Parameters[1][1].Add(Barcode);
		Output_Parameters[1][1].Add(0);
		Result = True;
		
	ElsIf Event = "CardData" Or Event = "TracksData" Then
		
		CardData = TrimAll(Data);
		Output_Parameters.Add("TracksData");
		Output_Parameters.Add(New Array());
		Output_Parameters[1].Add(CardData);
		Output_Parameters[1].Add(New Array());
		Output_Parameters[1][1].Add(Data);
		Output_Parameters[1][1].Add(CardData);
		Output_Parameters[1][1].Add(0);
		Result = True;
		
	EndIf;
	
	Return Result;

EndFunction

#EndRegion

#Region ProceduresAndFunctionsCommonForFiscalRegisters

// Function opens session.
//
Function OpenSession(DriverObject, Parameters, ConnectionParameters, Output_Parameters)
	
	Result = True;
	
	// Filling of the output parameters.
	Output_Parameters.Add(0);
	Output_Parameters.Add(0);
	Output_Parameters.Add(0);
	Output_Parameters.Add(EquipmentManagerClientOverridable.SessionDate());
	Return Result;
	
EndFunction

// Prints a fiscal receipt.
//
Function ReceiptPrint(DriverObject, Parameters, ConnectionParameters, InputParameters, Output_Parameters)
	       
	Return EquipmentManagerClientOverridable.ReceiptPrint(PeripheralsUniversalDriverClient,
		DriverObject, Parameters, ConnectionParameters, InputParameters, Output_Parameters);
		
EndFunction

// Prints text
//
Function PrintText(DriverObject, Parameters, ConnectionParameters,
                       TextString, Output_Parameters)
	   
	Result  = True;  
	
	// Open receipt
	Result = OpenReceipt(DriverObject, Parameters, ConnectionParameters, False, False, Output_Parameters);
	
	// Print receipt rows
	If Result Then
		For LineNumber = 1 To StrLineCount(TextString) Do
			SelectedRow = StrGetLine(TextString, LineNumber);
			
			If (Find(SelectedRow, "[segment]") > 0)
			 Or (Find(SelectedRow, "[cut]") > 0) Then
				PaymentsTable = New Array();
				Result = CloseReceipt(DriverObject, Parameters, ConnectionParameters, PaymentsTable, Output_Parameters);
				Result = OpenReceipt(DriverObject, Parameters, ConnectionParameters, False, False, Output_Parameters);
			Else
				If Not PrintNotFiscalLine(DriverObject, Parameters, ConnectionParameters,
				                                     SelectedRow, Output_Parameters) Then
					Break;
				EndIf;
			EndIf;
			
		EndDo;
	EndIf;
	
	// Close receipt
	If Result Then
		PaymentsTable = New Array();
		Result = CloseReceipt(DriverObject, Parameters, ConnectionParameters, PaymentsTable, Output_Parameters);
	EndIf;
	
	Return Result;
	
EndFunction

// Function opens a new receipt.
//
Function OpenReceipt(DriverObject, Parameters, ConnectionParameters, ReturnReceipt, FiscalReceipt, Output_Parameters) Export
	
	Result  = True;
	NumberOfSession = 0;
	ReceiptNumber  = 0;
	
	Try
		Response = DriverObject.ОткрытьЧек(ConnectionParameters.DeviceID, FiscalReceipt, ReturnReceipt,  True, ReceiptNumber, NumberOfSession);
		If Not Response Then
			Result = False;
			Output_Parameters.Clear();
			Output_Parameters.Add(999);
			Output_Parameters.Add("");
			DriverObject.ПолучитьОшибку(Output_Parameters[1]);
		Else
			// Filling of the output parameters.
			Output_Parameters.Clear();
			Output_Parameters.Add(NumberOfSession);
			Output_Parameters.Add(ReceiptNumber);
			Output_Parameters.Add(0); // Document No.
			Output_Parameters.Add(EquipmentManagerClientOverridable.SessionDate());
		EndIf;
	Except
		Result = False;
		Output_Parameters.Clear();
		Output_Parameters.Add(999);
		Output_Parameters.Add(NStr("en = 'An error occurred while calling the <DriverObject.OpenReceipt> method.'") + Chars.LF + ErrorDescription());
	EndTry;
	
	Return Result;
	
EndFunction

// Function closes a previously opened receipt.
//
Function CloseReceipt(DriverObject, Parameters, ConnectionParameters, PaymentsTable, Output_Parameters) Export

	Result = True;
	
	SumOfCashVoucher     = 0;
	AmountOfNonCashVoucher1 = 0;
	AmountOfNonCashVoucher2 = 0;
	AmountOfNonCashVoucher3 = 0;
	
	For paymentIndex = 0 To PaymentsTable.Count() - 1 Do
		If PaymentsTable[PaymentIndex][0].Value = 0 Then
			SumOfCashVoucher = SumOfCashVoucher + PaymentsTable[PaymentIndex][1].Value;
		ElsIf PaymentsTable[PaymentIndex][0].Value = 1 Then
			AmountOfNonCashVoucher1 = AmountOfNonCashVoucher1 + PaymentsTable[PaymentIndex][1].Value;
		ElsIf PaymentsTable[PaymentIndex][0].Value = 2 Then
			AmountOfNonCashVoucher2 = AmountOfNonCashVoucher2 + PaymentsTable[PaymentIndex][1].Value;
		Else
			AmountOfNonCashVoucher3 = AmountOfNonCashVoucher3 + PaymentsTable[PaymentIndex][1].Value;
		EndIf;
	EndDo;
	
	Try
		Response = DriverObject.ЗакрытьЧек(ConnectionParameters.DeviceID,
	                                      SumOfCashVoucher, AmountOfNonCashVoucher1, AmountOfNonCashVoucher2, AmountOfNonCashVoucher3);
		If Not Response Then
			Result = False;
			Output_Parameters.Clear();
			Output_Parameters.Add(999);
			Output_Parameters.Add("");
			DriverObject.GetError(Output_Parameters[1]);
			
			CancelReceipt(DriverObject, Parameters, ConnectionParameters, Output_Parameters);
		EndIf
	Except
		Result = False;
		Output_Parameters.Clear();
		Output_Parameters.Add(999);
		Output_Parameters.Add(NStr("en = 'An error occurred while calling the <DriverObject.CloseReceipt> method.'") + Chars.LF + ErrorDescription());
	EndTry;
	
	Return Result;

EndFunction

// Function cancels a previously opened receipt.
//
Function CancelReceipt(DriverObject, Parameters, ConnectionParameters, Output_Parameters) Export
	
	Result = True;
	
	Try
		DriverObject.ОтменитьЧек(ConnectionParameters.DeviceID);
	Except
		Result = False;
		Output_Parameters.Clear();
		Output_Parameters.Add(999);
		Output_Parameters.Add(NStr("en = 'An error occurred while calling the <DriverObject.CancelReceipt> method.'") + Chars.LF + ErrorDescription());
	EndTry;
	
	Return Result;   
	
EndFunction

// Function withdrawals without clearance.
//
Function PrintReportWithoutBlanking(DriverObject, Parameters, ConnectionParameters, Output_Parameters)
	
	Result = True;
	
	Try
		Response = DriverObject.НапечататьОтчетБезГашения(ConnectionParameters.DeviceID);
		If Not Response Then
			Result = False;
			Output_Parameters.Clear();
			Output_Parameters.Add(999);
			Output_Parameters.Add("");
			DriverObject.ПолучитьОшибку(Output_Parameters[1]);
		Else
			Output_Parameters.Clear();
			Output_Parameters.Add(0);
			Output_Parameters.Add(0);
			Output_Parameters.Add(0);
			Output_Parameters.Add(EquipmentManagerClientOverridable.SessionDate());
		EndIf;
	Except
		Result = False;
		Output_Parameters.Clear();
		Output_Parameters.Add(999);
		Output_Parameters.Add(NStr("en = 'An error occurred while calling the <DriverObject.PrintReportWithoutBlanking> method.'") + Chars.LF + ErrorDescription());
	EndTry;
	
	Return Result;
	
EndFunction

// Function withdrawals with clearance.
//
Function PrintReportWithBlanking(DriverObject, Parameters, ConnectionParameters, Output_Parameters)
	
	Result = True;
	
	Try
		Response = DriverObject.НапечататьОтчетСГашением(ConnectionParameters.DeviceID);
		If Not Response Then
			Result = False;
			Output_Parameters.Clear();
			Output_Parameters.Add(999);
			Output_Parameters.Add("");
			DriverObject.ПолучитьОшибку(Output_Parameters[1]);
		Else
			Output_Parameters.Clear();
			Output_Parameters.Add(0);
			Output_Parameters.Add(0);
			Output_Parameters.Add(0);
			Output_Parameters.Add(EquipmentManagerClientOverridable.SessionDate());
		EndIf;
	Except
		Result = False;
		Output_Parameters.Clear();
		Output_Parameters.Add(999);
		Output_Parameters.Add(NStr("en = 'An error occurred while calling the <DriverObject.PrintReportWithBlanking> method.'") + Chars.LF + ErrorDescription());
	EndTry;
	
	Return Result;
	
EndFunction

// Function prints a fiscal row.
//
Function PrintFiscalLine(DriverObject, Parameters, ConnectionParameters,
                                   Description, Quantity, Price, DiscountPercent, Amount,
                                   SectionNumber, VATRate, Output_Parameters) Export
	Result = True;
	
	Try
		Response = DriverObject.НапечататьФискСтроку(ConnectionParameters.DeviceID, Description, Quantity, Price,
	                                                Amount, SectionNumber, VATRate);
		If Not Response Then
			Result = False;
			Output_Parameters.Clear();
			Output_Parameters.Add(999);
			Output_Parameters.Add("");
			DriverObject.ПолучитьОшибку(Output_Parameters[1]);
			CancelReceipt(DriverObject, Parameters, ConnectionParameters, Output_Parameters);
		EndIf;
	Except
		Result = False;
		Output_Parameters.Clear();
		Output_Parameters.Add(999);
		Output_Parameters.Add(NStr("en = 'An error occurred while calling the <DriverObject.PrintFiscString> method.'") + Chars.LF + ErrorDescription());
	EndTry;
	
	Return Result;
	
EndFunction

// Function prints a nonfiscal row.
//
Function PrintNotFiscalLine(DriverObject, Parameters, ConnectionParameters, TextString, Output_Parameters) Export
	
	Result = True;
	
	Try
		Response = DriverObject.НапечататьНефискСтроку(ConnectionParameters.DeviceID, TextString);
		If Not Response Then
			Result = False;
			Output_Parameters.Clear();
			Output_Parameters.Add(999);
			Output_Parameters.Add("");
			DriverObject.ПолучитьОшибку(Output_Parameters[1]);
			CancelReceipt(DriverObject, Parameters, ConnectionParameters, Output_Parameters);
		EndIf;
	Except
		Result = False;
		Output_Parameters.Clear();
		Output_Parameters.Add(999);
		Output_Parameters.Add(NStr("en = 'An error occurred while calling the <DriverObject.PrintNonFiscalLine> method.'") + Chars.LF + ErrorDescription());
	EndTry;
	
	Return Result;
	
EndFunction

// The function deposits and withdraws an amount.
//
Function Encashment(DriverObject, Parameters, ConnectionParameters, EncashmentType, Amount, Output_Parameters)
	
	Result = True;
	
	Try
		Response = DriverObject.НапечататьЧекВнесенияВыемки(ConnectionParameters.DeviceID,
	                           ?(EncashmentType = 1, Amount, -Amount));
		If Not Response Then
			Result = False;
			Output_Parameters.Clear();
			Output_Parameters.Add(999);
			Output_Parameters.Add("");
			DriverObject.ПолучитьОшибку(Output_Parameters[1]);
		Else
			Output_Parameters.Clear();
			Output_Parameters.Add(0);
			Output_Parameters.Add(0);
			Output_Parameters.Add(0);
			Output_Parameters.Add(EquipmentManagerClientOverridable.SessionDate());
		EndIf;
	Except
		Result = False;
		Output_Parameters.Clear();
		Output_Parameters.Add(999);
		Output_Parameters.Add(NStr("en = 'An error occurred while calling the <DriverObject.PrintDepositWithdrawReceipt> method.'") + Chars.LF + ErrorDescription());
	EndTry;
	
	Return Result;
	
EndFunction

// Function prints a barcode.
//
Function PrintBarcode(DriverObject, Parameters, ConnectionParameters, BarCodeType, Barcode, Output_Parameters)
	
	Result = True;
	
	Try
		Response = DriverObject.НапечататьШтрихКод(ConnectionParameters.DeviceID, BarCodeType, Barcode);
		If Not Response Then
			Result = False;
			Output_Parameters.Clear();
			Output_Parameters.Add(999);
			Output_Parameters.Add("");
			DriverObject.ПолучитьОшибку(Output_Parameters[1]);
		EndIf;
	Except
		Result = False;
		Output_Parameters.Clear();
		Output_Parameters.Add(999);
		Output_Parameters.Add(NStr("en = 'An error occurred while calling the <DriverObject.PrintDashCode> method.'") + Chars.LF + ErrorDescription());
	EndTry;
	
	Return Result;
	
EndFunction

// Function opens a cash box.
//
Function OpenCashDrawer(DriverObject, Parameters, ConnectionParameters, Output_Parameters)
	
	Result = True;
	
	Try
		Response = DriverObject.ОткрытьДенежныйЯщик(ConnectionParameters.DeviceID);
		If Not Response Then
			Result = False;
			Output_Parameters.Clear();
			Output_Parameters.Add(999);
			Output_Parameters.Add("");
			DriverObject.ПолучитьОшибку(Output_Parameters[1]);
		EndIf;
	Except
		Result = False;
		Output_Parameters.Clear();
		Output_Parameters.Add(999);
		Output_Parameters.Add(NStr("en = 'An error occurred while calling the <DriverObject.OpenCashBox> method.'") + Chars.LF + ErrorDescription());
	EndTry;
	
	Return Result;

EndFunction

// Function receives the width of row in characters.
//  
Function GetRowWidth(DriverObject, Parameters, ConnectionParameters, Output_Parameters)
	
	Result = True;
	WidthRows = 0;
	 
	Try
		Response = DriverObject.ПолучитьШиринуСтроки(ConnectionParameters.DeviceID, WidthRows);
		If Not Response Then
			Result = False;
			Output_Parameters.Clear();
			Output_Parameters.Add(999);
			Output_Parameters.Add("");
			DriverObject.ПолучитьОшибку(Output_Parameters[1])
		Else
			Output_Parameters.Clear();  
			Output_Parameters.Add(WidthRows);
		EndIf;
	Except
		Result = False;
		Output_Parameters.Clear();
		Output_Parameters.Add(999);
		Output_Parameters.Add(NStr("en = 'An error occurred while calling the <DriverObject.GetRowWidth> method.'") + Chars.LF + ErrorDescription());
	EndTry;
	
	Return Result;

EndFunction

#EndRegion

#Region ProceduresAndFunctionsCommonForPOSTerminals

// Function returns whether the slip receipts will be printed on the terminal.
//
Function ReceiptsPrintOnTerminal(DriverObject, Parameters, ConnectionParameters, Output_Parameters)
	
	Result = True;
	
	Try
		Response = DriverObject.ПечатьКвитанцийНаТерминале();
		Output_Parameters.Clear();  
		Output_Parameters.Add(Response);
	Except
		Result = False;
		Output_Parameters.Clear();
		Output_Parameters.Add(999);
		Output_Parameters.Add(NStr("en = 'An error occurred while calling the <DriverObject.ReceiptsPrintOnTerminal> method.'") + Chars.LF + ErrorDescription());
	EndTry;
	
	Return Result;
	
EndFunction

// Function verifies totals by cards.
//
Function DayTotalsByCards(DriverObject, Parameters, ConnectionParameters, Output_Parameters)

	Result = True;
	Response     = False;
	SlipReceipt   = "";

	ConnectionParameters.OperationKind = NStr("en = 'Totals reconciliation'");

	Try
		Response = DriverObject.ИтогиДняПоКартам(ConnectionParameters.DeviceID, SlipReceipt);
		If Response Then
			Output_Parameters.Clear();
			Output_Parameters.Add(New Array());
			Output_Parameters[0].Add("SlipReceipt");
			Output_Parameters[0].Add(SlipReceipt);
		Else
			Result = False;
			Output_Parameters.Clear();
			Output_Parameters.Add(999);
			Output_Parameters.Add("");
			DriverObject.GetError(Output_Parameters[1])
		EndIf;
	Except
		Result = False;
		Output_Parameters.Clear();
		Output_Parameters.Add(999);
		Output_Parameters.Add(NStr("en = 'An error occurred while calling the <DriverObject.DayTotalsByCards> method.'") + Chars.LF + ErrorDescription());
	EndTry;

	Return Result;

EndFunction

// The function authorizes/pays by card.
//
Function PayByPaymentCard(DriverObject, Parameters, ConnectionParameters,
                                Amount, CardNumber, ReceiptNumber, Output_Parameters)

	Result      = True;
	RRNCode         = Undefined;
	AuthorizationCode = Undefined;
	SlipReceipt        = "";
	
	ConnectionParameters.OperationKind = NStr("en = 'Pay'");
	
	If Not (Amount > 0) Then
		Result = False;
		ConnectionParameters.OperationKind = NStr("en = 'Cancel'");
		Output_Parameters.Clear();
		Output_Parameters.Add(999);
		Output_Parameters.Add(NStr("en = 'Incorrect operation amount.'"));
		Return Result;
	EndIf;
	
	Try
		Response = DriverObject.ОплатитьПлатежнойКартой(ConnectionParameters.DeviceID, CardNumber, Amount, 
													ReceiptNumber, RRNCode, AuthorizationCode, SlipReceipt);
		If Response Then
			Output_Parameters.Clear();
			Output_Parameters.Add(CardNumber);
			Output_Parameters.Add(RRNCode);
			Output_Parameters.Add(ReceiptNumber);
			Output_Parameters.Add(New Array());
			Output_Parameters[3].Add("SlipReceipt");
			Output_Parameters[3].Add(SlipReceipt);
			Output_Parameters.Add(AuthorizationCode);
		Else
			Result = False;
			ConnectionParameters.OperationKind = NStr("en = 'Cancel'");
			Output_Parameters.Clear();
			Output_Parameters.Add(999);
			Output_Parameters.Add("");
			DriverObject.ПолучитьОшибку(Output_Parameters[1])
		EndIf;
	Except
		Result = False;
		Output_Parameters.Clear();
		Output_Parameters.Add(999);
		Output_Parameters.Add(NStr("en = 'An error occurred while calling the <DriverObject.PayByPaymentCard> method.'") + Chars.LF + ErrorDescription());
	EndTry;
	
	Return Result;
	
EndFunction

// Function carries out a chargeback by a card.
//
Function ReturnPaymentByPaymentCard(DriverObject, Parameters, ConnectionParameters,
                                      Amount, CardNumber, RefNo, ReceiptNumber, Output_Parameters)
	  
	Result      = True;
	RRNCode         = RefNo;
	AuthorizationCode = Undefined;
	SlipReceipt        = "";
	CardNumber     = "";
	
	ConnectionParameters.OperationKind = NStr("en = 'Refund payment'");
	
	If Not (Amount > 0) Then
		Result = False;
		ConnectionParameters.OperationKind = NStr("en = 'Cancel'");
		Output_Parameters.Clear();
		Output_Parameters.Add(999);
		Output_Parameters.Add(NStr("en = 'Incorrect operation amount.'"));
		Return Result;
	EndIf;
	
	Try
		Response = DriverObject.ВернутьПлатежПоПлатежнойКарте(ConnectionParameters.DeviceID, CardNumber, Amount, 
													ReceiptNumber, RRNCode, AuthorizationCode, SlipReceipt);
		If Response Then
			Output_Parameters.Clear();
			Output_Parameters.Add(CardNumber);
			Output_Parameters.Add(RRNCode);
			Output_Parameters.Add(ReceiptNumber);
			Output_Parameters.Add(New Array());
			Output_Parameters[3].Add("SlipReceipt");
			Output_Parameters[3].Add(SlipReceipt);
			Output_Parameters.Add(AuthorizationCode);
		Else
			Result = False;
			ConnectionParameters.OperationKind = NStr("en = 'Cancel'");
			Output_Parameters.Clear();
			Output_Parameters.Add(999);
			Output_Parameters.Add("");
			DriverObject.ПолучитьОшибку(Output_Parameters[1])
		EndIf;
	Except
		Result = False;
		Output_Parameters.Clear();
		Output_Parameters.Add(999);
		Output_Parameters.Add(NStr("en = 'An error occurred while calling the <DriverObject.ReturnPaymentByPaymentCard> method.'") + Chars.LF + ErrorDescription());
	EndTry;
	
	Return Result;
	
EndFunction

// Function cancels payment by card.
//
Function CancelPaymentByPaymentCard(DriverObject, Parameters, ConnectionParameters,
                                      Amount, RefNo, ReceiptNumber, Output_Parameters)
	  
	Result      = True;
	RRNCode         = RefNo;
	AuthorizationCode = Undefined;
	SlipReceipt        = "";
	CardNumber     = "";

	
	ConnectionParameters.OperationKind = NStr("en = 'Cancel payment'");
	
	If Not (Amount > 0) Then
		Result = False;
		ConnectionParameters.OperationKind = NStr("en = 'Cancel'");
		Output_Parameters.Clear();
		Output_Parameters.Add(999);
		Output_Parameters.Add(NStr("en = 'Incorrect operation amount.'"));
		Return Result;
	EndIf;
	
	Try
		Response = DriverObject.ОтменитьПлатежПоПлатежнойКарте(ConnectionParameters.DeviceID, CardNumber, Amount, 
													ReceiptNumber, RRNCode, AuthorizationCode, SlipReceipt);
		If Response Then
			Output_Parameters.Clear();
			Output_Parameters.Add(New Array());
			Output_Parameters[0].Add("SlipReceipt");
			Output_Parameters[0].Add(SlipReceipt);
		Else
			Result = False;
			ConnectionParameters.OperationKind = NStr("en = 'Cancel'");
			Output_Parameters.Clear();
			Output_Parameters.Add(999);
			Output_Parameters.Add("");
			DriverObject.ПолучитьОшибку(Output_Parameters[1])
		EndIf;
	Except
		Result = False;
		Output_Parameters.Clear();
		Output_Parameters.Add(999);
		Output_Parameters.Add(NStr("en = 'An error occurred while calling the <DriverObject.CancelPaymentByPaymentCard> method.'") + Chars.LF + ErrorDescription());
	EndTry;
	
	Return Result;

EndFunction

// Function carries out an emergency cancellation of the card operation.
//
Function EmergencyCancelOperations(DriverObject, Parameters, ConnectionParameters,
                                Amount, RefNo, ReceiptNumber, Output_Parameters)

	Response = False;
	Result = True;

	Try
		Response = DriverObject.АварийнаяОтменаОперации(ConnectionParameters.DeviceID);
		If Not Response Then
			Result = False;
			Output_Parameters.Clear();
			Output_Parameters.Add(999);
			Output_Parameters.Add("");
			DriverObject.ПолучитьОшибку(Output_Parameters[1])
		EndIf;
	Except
		Result = False;
		Output_Parameters.Clear();
		Output_Parameters.Add(999);
		Output_Parameters.Add(NStr("en = 'An error occurred while calling the <DriverObject.EmergencyCancelOperations> method.'") + Chars.LF + ErrorDescription());
	EndTry;

	Return Result;

EndFunction

// Function carries out preauthorization by a card.
// 
Function PreauthorizeByPaymentCard(DriverObject, Parameters, ConnectionParameters,
                                        Amount, CardNumber, ReceiptNumber, Output_Parameters)
	Result      = True;
	RRNCode         = Undefined;
	AuthorizationCode = Undefined;
	SlipReceipt        = "";
	
	ConnectionParameters.OperationKind = NStr("en = 'Preauthorize payment'");
	
	If Not (Amount > 0) Then
		Result = False;
		ConnectionParameters.OperationKind = NStr("en = 'Cancel'");
		Output_Parameters.Clear();
		Output_Parameters.Add(999);
		Output_Parameters.Add(NStr("en = 'Incorrect operation amount.'"));
		Return Result;
	EndIf;
	
	Try
		Response = DriverObject.ПреавторизацияПоПлатежнойКарте(ConnectionParameters.DeviceID, CardNumber, Amount, 
													ReceiptNumber, RRNCode, AuthorizationCode, SlipReceipt);
		If Response Then
			Output_Parameters.Clear();
			Output_Parameters.Add(CardNumber);
			Output_Parameters.Add(RRNCode);
			Output_Parameters.Add(ReceiptNumber);
			Output_Parameters.Add(New Array());
			Output_Parameters[3].Add("SlipReceipt");
			Output_Parameters[3].Add(SlipReceipt);
			Output_Parameters.Add(AuthorizationCode);
		Else
			Result = False;
			ConnectionParameters.OperationKind = NStr("en = 'Cancel'");
			Output_Parameters.Clear();
			Output_Parameters.Add(999);
			Output_Parameters.Add("");
			DriverObject.ПолучитьОшибку(Output_Parameters[1])
		EndIf;
	Except
		Result = False;
		Output_Parameters.Clear();
		Output_Parameters.Add(999);
		Output_Parameters.Add(NStr("en = 'An error occurred while calling the <DriverObject.PreauthorizationByPaymentCard> method.'") + Chars.LF + ErrorDescription());
	 EndTry;
	
	Return Result;
	
EndFunction

// Function cancels preauthorization by a card.
//
Function CancelPreauthorizationByPaymentCard(DriverObject, Parameters, ConnectionParameters,
                                               Amount, CardNumber, RefNo, ReceiptNumber, Output_Parameters)
	Result      = True;
	AuthorizationCode = Undefined;
	SlipReceipt        = "";
	
	ConnectionParameters.OperationKind = NStr("en = 'Cancel preauthorization'");
	
	Try
		Response = DriverObject.ОтменитьПреавторизациюПоПлатежнойКарте(ConnectionParameters.DeviceID, CardNumber, Amount, 
													ReceiptNumber, RefNo, AuthorizationCode, SlipReceipt);
		If Response Then
			Output_Parameters.Clear();
			Output_Parameters.Add(New Array());
			Output_Parameters[0].Add("SlipReceipt");
			Output_Parameters[0].Add(SlipReceipt);
		Else
			Result = False; 
			ConnectionParameters.OperationKind = NStr("en = 'Cancel'");
			Output_Parameters.Clear();
			Output_Parameters.Add(999);
			Output_Parameters.Add("");
			DriverObject.ПолучитьОшибку(Output_Parameters[1])
		EndIf;
	Except
		Result = False;
		Output_Parameters.Clear();
		Output_Parameters.Add(999);
		Output_Parameters.Add(NStr("en = 'An error occurred while calling the <DriverObject.CancelPreauthorizationByPaymentCard> method.'") + Chars.LF + ErrorDescription());
	 EndTry;
	 
	 Return Result;
	 
EndFunction

// Function ends preauthorization by a card.
//
Function FinishPreauthorizationByPaymentCard(DriverObject, Parameters, ConnectionParameters,
                                                Amount, CardNumber, RefNo, ReceiptNumber, Output_Parameters)
	Result      = True;
	AuthorizationCode = Undefined;
	SlipReceipt        = "";
	
	ConnectionParameters.OperationKind = NStr("en = 'Finish preauthorization'");
	
	Try
		Response = DriverObject.ЗавершитьПреавторизациюПоПлатежнойКарте(ConnectionParameters.DeviceID, CardNumber, Amount, 
													ReceiptNumber, RefNo, AuthorizationCode, SlipReceipt);
		If Response Then
			Output_Parameters.Clear();
			Output_Parameters.Add(New Array());
			Output_Parameters[0].Add("SlipReceipt");
			Output_Parameters[0].Add(SlipReceipt);
		Else
			Result = False; 
			ConnectionParameters.OperationKind = NStr("en = 'Cancel'");
			Output_Parameters.Clear();
			Output_Parameters.Add(999);
			Output_Parameters.Add("");
			DriverObject.ПолучитьОшибку(Output_Parameters[1])
		EndIf;
	Except
		Result = False;
		Output_Parameters.Clear();
		Output_Parameters.Add(999);
		Output_Parameters.Add(NStr("en = 'An error occurred while calling the <DriverObject.FinishPreauthorizationByPaymentCard> method.'") + Chars.LF + ErrorDescription());
	 EndTry;
	 
	Return Result;
	
EndFunction

#EndRegion

#Region ProceduresAndFunctionsCommonForDataCollectionTerminals

// The function exports data to the data collection terminal.
//
Function ExportTable(DriverObject, Parameters, ConnectionParameters, ExportingTable, Output_Parameters)

	Result = True;

	If ExportingTable.Count() = 0 Then
		Output_Parameters.Clear();
		Output_Parameters.Add(999);
		Output_Parameters.Add(NStr("en = 'No data for export.'"));
		Return False;
	EndIf;
	
	PackageSize     = 100;
	CurrentPackage     = 1;
	RecordInBatch    = 0;
	RecordsExported = 0;
	RecordsTotal     = ExportingTable.Count();
	PackageStatus     = "first";
	
	CurrentPercent = 0;
	Status(NStr("en = 'Initializing export...'"), Round(CurrentPercent));
	PercentIncrement = 100 / (RecordsTotal / PackageSize);
	
	ProductsArray = New Array;

	For Each Position In ExportingTable  Do
		
		If RecordInBatch = 0 Then
		    ProductsArray.Clear();
		EndIf;
		
		DCTArrayRow = New ValueList; 
		DCTArrayRow.Add(Position[0].Value);
		DCTArrayRow.Add(Position[1].Value);
		DCTArrayRow.Add(Position[2].Value);
		DCTArrayRow.Add(Position[3].Value);
		DCTArrayRow.Add(Position[4].Value);
		DCTArrayRow.Add(Position[5].Value);
		DCTArrayRow.Add(Position[6].Value);
		DCTArrayRow.Add(Position[7].Value);
		ProductsArray.Add(DCTArrayRow);
		
		RecordsExported  = RecordsExported + 1;
		RecordInBatch = RecordInBatch + 1;
		
		If (RecordInBatch = PackageSize) OR (RecordsExported = RecordsTotal) Then  

			
			DataForExportings = EquipmentManagerServerCall.GenerateProductsTableDCT(ProductsArray);
			
			If (RecordsExported = RecordsTotal) Then
				PackageStatus = "last";
			ElsIf (CurrentPackage > 1) Then
				PackageStatus = "regular";
			EndIf;
			
			Response = DriverObject.ВыгрузитьТаблицу(ConnectionParameters.DeviceID, DataForExportings, PackageStatus);
			If Not Response Then
				Result = False;
				Output_Parameters.Clear();
				Output_Parameters.Add(999);
				Output_Parameters.Add("");
				DriverObject.ПолучитьОшибку(Output_Parameters[1]);
				Return Result;
			EndIf;
			
			RecordInBatch = 0;
			CurrentPackage = CurrentPackage + 1;
			
			CurrentPercent = CurrentPercent + PercentIncrement;
			Status(NStr("en = 'Exporting data ...'"), Round(CurrentPercent));
			
		 EndIf;
		
	EndDo;
	
	Return Result;

EndFunction

// The function exports a table from the data collection terminal.
//
Function Import_Table(DriverObject, Parameters, ConnectionParameters, Output_Parameters)

	Result = True;
	DataExport = "";
	Status(NStr("en = 'Importing data...'"));
	
	Try
		
		Response = DriverObject.ЗагрузитьТаблицу(ConnectionParameters.DeviceID, DataExport);
		If Not Response Then
			Result = False;
			Output_Parameters.Clear();
			Output_Parameters.Add(999);
			Output_Parameters.Add("");
			DriverObject.ПолучитьОшибку(Output_Parameters[1]);
			Return Result;
		EndIf;      
		
		If Not IsBlankString(DataExport) Then
			ArrayOfData = EquipmentManagerServerCall.GetProductsTableDCT(DataExport);
		EndIf;
	
		If IsBlankString(DataExport) Or (ArrayOfData.Count() = 0) Then
			Result = False;
			Output_Parameters.Clear();
			Output_Parameters.Add(999);
			Output_Parameters.Add(NStr("en = 'No data to load.'"));
		Else
			Output_Parameters.Add(ArrayOfData);
		EndIf;   
		
	Except
		Result = False;
		Output_Parameters.Clear();
		Output_Parameters.Add(999);
		Output_Parameters.Add(NStr("en = 'An error occurred while calling the <DriverObject.ImportingTable> method.'") + Chars.LF + ErrorDescription());
	EndTry;
	
	Return Result;
	
EndFunction

// Clears a table previously imported to the data collection terminal.
//
Function ClearTable(DriverObject, Parameters, ConnectionParameters, Output_Parameters)
	
	Result = True;
	
	Status(NStr("en = 'Executing operation...'"));	
	
	Try
		Response = DriverObject.ОчиститьТаблицу(ConnectionParameters.DeviceID);
		If Not Response Then
			Result = False;
			Output_Parameters.Clear();
			Output_Parameters.Add(999);
			Output_Parameters.Add("");
			DriverObject.ПолучитьОшибку(Output_Parameters[1])
		EndIf;
	Except
		Result = False;
		Output_Parameters.Clear();
		Output_Parameters.Add(999);
		Output_Parameters.Add(NStr("en = 'An error occurred while calling the <DriverObject.ClearTable> method.'") + Chars.LF + ErrorDescription());
	EndTry;
	
	Return Result;

EndFunction

#EndRegion

#Region ProceduresAndFunctionsCommonForCustomerDisplays

// Function displays string list on customer display.
//
Function OutputLineToCustomerDisplay(DriverObject, Parameters, ConnectionParameters, TextString, Output_Parameters)
	
	Result = True;
	
	Try
		Response = DriverObject.OutputLineToCustomerDisplay(ConnectionParameters.DeviceID, TextString);
		If Not Response Then
			Result = False;
			Output_Parameters.Clear();
			Output_Parameters.Add(999);
			Output_Parameters.Add("");
			DriverObject.GetError(Output_Parameters[1])
		EndIf;
	Except
		Result = False;
		Output_Parameters.Clear();
		Output_Parameters.Add(999);
		Output_Parameters.Add(NStr("en = 'An error occurred while calling the <DriverObject.OutputLineToCustomerDisplay> method.'") + Chars.LF + ErrorDescription());
	EndTry;
	
	Return Result;
	
EndFunction

// Function clears the customer display.
//
Function ClearCustomerDisplay(DriverObject, Parameters, ConnectionParameters, Output_Parameters)
	
	Result = True;
	
	Try
		Response = DriverObject.ClearCustomerDisplay(ConnectionParameters.DeviceID);
		If Not Response Then
			Result = False;
			Output_Parameters.Clear();
			Output_Parameters.Add(999);
			Output_Parameters.Add("");
			DriverObject.GetError(Output_Parameters[1])
		EndIf;
	Except
		Result = False;
		Output_Parameters.Clear();
		Output_Parameters.Add(999);
		Output_Parameters.Add(NStr("en = 'An error occurred while calling the <DriverObject.ClearCustomerDisplay> method.'") + Chars.LF + ErrorDescription());
	EndTry;
	
	Return Result;
	
EndFunction

// function returns the parameters of output to the customer display).
//
Function GetOutputParameters(DriverObject, Parameters, ConnectionParameters, Output_Parameters)
	
	Result = True;
	DisplayedColumns = 20; 
	LinesOnDisplay    = 2;
	
	Try
		Response = DriverObject.GetOutputParameters(ConnectionParameters.DeviceID, DisplayedColumns, LinesOnDisplay);
		If Not Response Then
			Result = False;
			Output_Parameters.Clear();
			Output_Parameters.Add(999);
			Output_Parameters.Add("");
			DriverObject.GetError(Output_Parameters[1])
		Else
			Output_Parameters.Clear();  
			Output_Parameters.Add(DisplayedColumns);
			Output_Parameters.Add(LinesOnDisplay);
		EndIf;
	Except
		Result = False;
		Output_Parameters.Clear();
		Output_Parameters.Add(999);
		Output_Parameters.Add(NStr("en = 'An error occurred while calling the <DriverObject.GetOutputParameters> method.'") + Chars.LF + ErrorDescription());
	EndTry;
	
	Return Result;
	
EndFunction

#EndRegion

#Region ProceduresAndFunctionsCommonForElectronicScales

// The function receives weight of the load placed on the scales.
//
Function GetWeight(DriverObject, Parameters, ConnectionParameters, Output_Parameters)
	
	Result = True;
	Weight = 0;
	
	Try
		Response = DriverObject.ПолучитьВес(ConnectionParameters.DeviceID, Weight);
		If Not Response Then
			Result = False;
			Output_Parameters.Clear();
			Output_Parameters.Add(999);
			Output_Parameters.Add("");
			DriverObject.ПолучитьОшибку(Output_Parameters[1])
		Else
			Output_Parameters.Clear();  
			Output_Parameters.Add(Weight);
		EndIf;
	Except
		Result = False;
		Output_Parameters.Clear();
		Output_Parameters.Add(999);
		Output_Parameters.Add(NStr("en = 'An error occurred while calling the <DriverObject.GetWeight> method.'") + Chars.LF + ErrorDescription());
	EndTry;
	
	Return Result;
	
EndFunction

// The function weighs a tare on the scales.
//
Function Tare(DriverObject, Parameters, ConnectionParameters, Output_Parameters, TareWeight = 0)
	
	Result = True;
	
	Try
		Response = DriverObject.УстановитьВесТары(ConnectionParameters.DeviceID, TareWeight);
		If Not Response Then
			Result = False;
			Output_Parameters.Clear();
			Output_Parameters.Add(999);
			Output_Parameters.Add("");
			DriverObject.ПолучитьОшибку(Output_Parameters[1])
		Else
			Output_Parameters.Clear();  
		EndIf;
	Except
		Result = False;
		Output_Parameters.Clear();
		Output_Parameters.Add(999);
		Output_Parameters.Add(NStr("en = 'An error occurred while calling the <DriverObject.Tare> method.'") + Chars.LF + ErrorDescription());
	EndTry;
	
	Return Result;
	
EndFunction

#EndRegion

#Region ProceduresAndFunctionsForCommonScalesWithPrintingLabels

// The function clears a products base in scales with label printing.
//
Function ClearProductsInScales(DriverObject, Parameters, ConnectionParameters, Output_Parameters)
	
	Result = True;
	
	Try
		Response = DriverObject.ClearProducts(ConnectionParameters.DeviceID);
		If Not Response Then
			Result = False;
			Output_Parameters.Clear();
			Output_Parameters.Add(999);
			Output_Parameters.Add("");
			DriverObject.GetError(Output_Parameters[1])
		Else
			Output_Parameters.Clear();  
		EndIf;
	Except
		Result = False;
		Output_Parameters.Clear();
		Output_Parameters.Add(999);
		Output_Parameters.Add(NStr("en = 'An error occurred while calling the <DriverObject.ClearProducts> method.'") +  ErrorDescription());
	EndTry;
	
	Return Result;
	
EndFunction

// The function exports data to the scales with label printing.
//
Function ExportProducts(DriverObject, Parameters, ConnectionParameters, ExportingTable, PartialExport, Output_Parameters)
	
	Result = True;
	
	If ExportingTable.Count() = 0 Then
		Output_Parameters.Clear();
		Output_Parameters.Add(999);
		Output_Parameters.Add(NStr("en = 'No data for export.'"));
		Return False;
	EndIf;
	
	PackageSize     = 100;
	CurrentPackage     = 1;
	RecordInBatch    = 0;
	RecordsExported = 0;
	RecordsTotal     = ExportingTable.Count();
	PackageStatus     = "first";
	
	CurrentPercent = 0;
	Status(NStr("en = 'Initializing export...'"), Round(CurrentPercent));
	PercentIncrement = 100 / (RecordsTotal / PackageSize);
	
	ProductsArray = New Array;
	
	For Each Position In ExportingTable  Do
		
		If RecordInBatch = 0 Then
		    ProductsArray.Clear();
		EndIf;
		
		TempName = ?(Position.Property("Products"), Position.Products, "");
		TempName = ?(Position.Property("Description"), Position.Description, TempName);
		TempName = ?(Position.Property("DescriptionFull"), Position.DescriptionFull, TempName);
		
		ProductsArrayRow = New ValueList; 
		ProductsArrayRow.Add(Position.PLU);
		ProductsArrayRow.Add(Position.Code);
		ProductsArrayRow.Add(TempName);
		ProductsArrayRow.Add(?(Position.Property("Price"), Position.Price, 0));
		ProductsArrayRow.Add(?(Position.Property("ProductDescription"), Position.ProductDescription, ""));
		ProductsArrayRow.Add(?(Position.Property("StoragePeriod"), Position.StoragePeriod, 0));
		ProductsArray.Add(ProductsArrayRow);
		
		RecordsExported  = RecordsExported + 1;
		RecordInBatch = RecordInBatch + 1;
		
		If (RecordInBatch = PackageSize) OR (RecordsExported = RecordsTotal) Then  
			
			DataForExportings = EquipmentManagerServerCall.GenerateProductsTableLabelsPrintingScales(ProductsArray);
			
			If (RecordsExported = RecordsTotal) Then
				PackageStatus = "last";
			ElsIf (CurrentPackage > 1) Then
				PackageStatus = "regular";
			EndIf;
			
			Response = DriverObject.ExportProducts(ConnectionParameters.DeviceID, DataForExportings, PackageStatus);
			If Not Response Then
				Result = False;
				Output_Parameters.Clear();
				Output_Parameters.Add(999);
				Output_Parameters.Add("");
				DriverObject.GetError(Output_Parameters[1]);
				Return Result;
			EndIf;
			
			RecordInBatch = 0;
			CurrentPackage = CurrentPackage + 1;
			
			CurrentPercent = CurrentPercent + PercentIncrement;
			Status(NStr("en = 'Exporting data ...'"), Round(CurrentPercent));
			 
		 EndIf;
		
	EndDo;
	
	Return Result;

EndFunction

#EndRegion

#Region ProceduresAndFunctionsCommonForAllDriversTypes

// Function tests device.
//
Function DeviceTest(DriverObject, Parameters, ConnectionParameters, Output_Parameters)

	Result            = True;
	TestResult       = "";
	ActivatedDemoMode = "";
	
	For Each Parameter In Parameters Do
		If Left(Parameter.Key, 2) = "P_" Then
			ParameterValue = Parameter.Value;
			ParameterName = Mid(Parameter.Key, 3);
			Response = DriverObject.УстановитьПараметр(ParameterName, ParameterValue) 
		EndIf;
	EndDo;
	
	Try
		Response = DriverObject.ТестУстройства(TestResult, ActivatedDemoMode);
	
		If Response Then
			Output_Parameters.Clear();
			Output_Parameters.Add(0);
		Else
			Result = False;
			Output_Parameters.Clear();
			Output_Parameters.Add(999);
		EndIf;
		Output_Parameters.Add(TestResult);
		Output_Parameters.Add(ActivatedDemoMode);
	
	Except
		Result = False;
		Output_Parameters.Clear();
		Output_Parameters.Add(999);
		Output_Parameters.Add(NStr("en = 'An error occurred while calling the <DriverObject.DeviceText> method.'") + Chars.LF + ErrorDescription());
	EndTry;
	
	Return Result;

EndFunction

// Function executes an additional action for a device.
//
Function ExecuteAdditionalAction(DriverObject, Parameters, ConnectionParameters, NameActions, Output_Parameters)
	
	Result  = True;
	
	For Each Parameter In Parameters Do
		If Left(Parameter.Key, 2) = "P_" Then
			ParameterValue = Parameter.Value;
			ParameterName = Mid(Parameter.Key, 3);
			Response = DriverObject.УстановитьПараметр(ParameterName, ParameterValue) 
		EndIf;
	EndDo;
	
	Try
		Response = DriverObject.ВыполнитьДополнительноеДействие(NameActions);
		If Not Response Then
			Result = False;
			Output_Parameters.Clear();
			Output_Parameters.Add(999);
			Output_Parameters.Add("");
			DriverObject.ПолучитьОшибку(Output_Parameters[1])
		Else
			Output_Parameters.Clear();  
		EndIf;
	Except
		Result = False;
		Output_Parameters.Clear();
		Output_Parameters.Add(999);
		Output_Parameters.Add(NStr("en = 'An error occurred while calling the <DriverObject.ExecuteAdditionalAction> method.'") + Chars.LF + ErrorDescription());
	EndTry;
	
	Return Result;
	
EndFunction

// Function returns installed driver version.
//
Function GetDriverVersion(DriverObject, Parameters, ConnectionParameters, Output_Parameters)

	Result = True;

	Output_Parameters.Add(NStr("en = 'Set'"));
	Output_Parameters.Add(NStr("en = 'Not defined'"));

	Try
		Output_Parameters[1] = DriverObject.ПолучитьНомерВерсии();
	Except
	EndTry;

	Return Result;

EndFunction

// The function returns description of the installed driver.
//
Function GetDriverDescription(DriverObject, Parameters, ConnectionParameters, Output_Parameters)
	
	Result = True;
	
	Output_Parameters.Clear();
	Output_Parameters.Add(NStr("en = 'Set'"));
	Output_Parameters.Add(NStr("en = 'Not defined'"));
	
	Output_Parameters.Add(NStr("en = 'Undefined'"));
	Output_Parameters.Add(NStr("en = 'Undefined'"));
	Output_Parameters.Add(NStr("en = 'Undefined'"));
	Output_Parameters.Add(Undefined);
	Output_Parameters.Add(Undefined);
	Output_Parameters.Add(Undefined);
	Output_Parameters.Add(Undefined);
	Output_Parameters.Add(Undefined);
	Output_Parameters.Add(Undefined);
	
	DriverDescription      = "";
	DetailsDriver          = "";
	EquipmentType           = "";
	IntegrationLibrary  = True;
	MainDriverIsSet = False;
	AuditInterface         = 1012;
	URLExportDriver       = "";
	ParametersDriver         = "";
	AdditionalActions    = "";
	
	Try
		// Get a driver version
		DriverVersion = DriverObject.ПолучитьНомерВерсии();
		Output_Parameters[1] = DriverVersion;
		
		If ConnectionParameters.Property("EquipmentType") Then
			EquipmentType = ConnectionParameters.EquipmentType;
			// Predefined parameter with the indication of driver type.
			DriverObject.УстановитьПараметр("EquipmentType", EquipmentType) 
		EndIf;
		
		// Get driver description
		DriverObject.ПолучитьОписание(DriverDescription, 
										DetailsDriver, 
										EquipmentType, 
										AuditInterface, 
										IntegrationLibrary, 
										MainDriverIsSet, 
										URLExportDriver);
		Output_Parameters[2] = DriverDescription;
		Output_Parameters[3] = DetailsDriver;
		Output_Parameters[4] = EquipmentType;
		Output_Parameters[5] = AuditInterface;
		Output_Parameters[6] = IntegrationLibrary;
		Output_Parameters[7] = MainDriverIsSet;
		Output_Parameters[8] = URLExportDriver;
		
		// Get driver description
		DriverObject.ПолучитьПараметры(ParametersDriver);
		Output_Parameters[9] = ParametersDriver;
		
		// Get additional actions.
		DriverObject.ПолучитьДополнительныеДействия(AdditionalActions);
		Output_Parameters[10] = AdditionalActions;
	Except
		Result = False;
		CommonUseClientServer.MessageToUser(NStr("en = 'An error occurred while receiving the driver description'"));
	EndTry;
	
	Return Result;

EndFunction

#EndRegion