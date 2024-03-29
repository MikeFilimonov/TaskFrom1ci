﻿#Region Interface

// 
//
// Parameters:
//  
//
// Returns:
//  
//
Function ConnectDevice(DriverObject, Parameters, ConnectionParameters, Output_Parameters) Export

	Result = True;
	Output_Parameters = New Array();
	ConnectionParameters.Insert("DeviceID", Undefined);
	ConnectionParameters.Insert("OriginalTransactionCode", Undefined);
	ConnectionParameters.Insert("TransactionType", "");
	If Not Parameters.Property("PathFprwin") Then
		FillDefaultParameters(Parameters);
	EndIf;
	
	If Not DeviceTest(DriverObject, Parameters, ConnectionParameters, Output_Parameters) Then
		Output_Parameters.Add(999);
		Output_Parameters.Add(NStr("en = 'Device parameters are not configured."
"For the correct work of the device it is necessary to specify the parameters of its work."
"It can be done using the form ""Parameters Setting"" models of the peripherals in the form ""Equipment Connect Setup"".'"));
		Result = False;
	EndIf;
	
	Output_Parameters.Add(ConnectionParameters.DeviceID);
	Output_Parameters.Add(New Array());
	
	Return Result;

EndFunction

// 
//
// Parameters:
//  
//
// Returns:
//  
//
Function DisableDevice(DriverObject, Parameters, ConnectionParameters, Output_Parameters) Export

	Result = True;
	Output_Parameters = New Array();
	Return Result;

EndFunction

// 
//
Function RunCommand(Presentation, InputParameters = Undefined, Output_Parameters = Undefined,
                         DriverObject, Parameters, ConnectionParameters) Export

	Result = True;
	
	Output_Parameters = New Array();
	
	// 
	
	// Cash session open
	If Presentation = "OpenDay" Or Presentation = "OpenSession" Then
		Result = OpenSession(DriverObject, Parameters, ConnectionParameters, Output_Parameters);
		
	// Report printing without blanking
	ElsIf Presentation = "PrintXReport" Or Presentation = "PrintReportWithoutBlanking" Then
		Result = PrintReportWithoutBlanking(DriverObject, Parameters, ConnectionParameters, Output_Parameters);
		
	// Print report with blanking
	ElsIf Presentation = "PrintZReport" Or Presentation = "PrintReportWithBlanking" Then
		Result = PrintReportWithBlanking(DriverObject, Parameters, ConnectionParameters, Output_Parameters);
		
	// 
	ElsIf Presentation = "PrintReceipt" Or Presentation = "ReceiptPrint" Then
		Result = ReceiptPrint(DriverObject, Parameters, ConnectionParameters, InputParameters,	Output_Parameters);
		
	// 
	ElsIf Presentation = "OpenCheck" Or Presentation = "OpenReceipt"  Then
		ReturnReceipt   = InputParameters[0];
		FiscalBill = InputParameters[1];
		Result = OpenReceipt(DriverObject, Parameters, ConnectionParameters, ReturnReceipt, FiscalBill, Output_Parameters);
		
	// 
	ElsIf Presentation = "CancelCheck" Or Presentation = "CancelReceipt"  Then
		Result = CancelReceipt(DriverObject, Parameters, ConnectionParameters, Output_Parameters);

	// 
	ElsIf Presentation = "Encash" Or Presentation = "Encashment" Then
		EncashmentType = InputParameters[0];
		Amount         = InputParameters[1];
		Result = Encashment(DriverObject, Parameters, ConnectionParameters, EncashmentType, Amount, Output_Parameters);

	// 
	ElsIf Presentation = "OpenCashDrawer" Or Presentation = "OpenCashDrawer" Then
		Result = OpenCashDrawer(DriverObject, Parameters, ConnectionParameters, Output_Parameters);

	// 
	ElsIf Presentation = "DeviceTest" Or Presentation = "CheckHealth" Then
		Result = DeviceTest(DriverObject, Parameters, ConnectionParameters, Output_Parameters);
		
	// 
	Else
		Output_Parameters.Add(999);
		Output_Parameters.Add(NStr("en = 'Presentation ""%Presentation%"" not supported by this driver.'"));
		Output_Parameters[1] = StrReplace(Output_Parameters[1], "%Presentation%", Presentation);
		Result = False;

	EndIf;

	Return Result;

EndFunction

#Region InternalProceduresAndFunctions

Function OpenSession(DriverObject, Parameters, ConnectionParameters, Output_Parameters)

	Result = True;
	
	Output_Parameters.Add(0);
	Output_Parameters.Add(0);
	Output_Parameters.Add(0);
	Output_Parameters.Add(EquipmentManagerClientOverridable.SessionDate());
	
	Return Result;

EndFunction

Function ReceiptPrint(DriverObject, Parameters, ConnectionParameters, InputParameters, Output_Parameters)
	
	Return EquipmentManagerClientOverridable.ReceiptPrint(PeripheralsZekaFiscalRegistrarsClient,
		DriverObject, Parameters, ConnectionParameters, InputParameters, Output_Parameters);
	
EndFunction

// 
//
Function OpenReceipt(DriverObject, Parameters, ConnectionParameters, ReturnReceipt, FiscalBill, Output_Parameters) Export
	
	SimpleBonFile = New File(Parameters.PathSimpleBon);
	If SimpleBonFile.Exist() Then
		Try
			DeleteFiles(Parameters.PathSimpleBon);
		Except
			CommonUseClientServer.MessageToUser(StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'File %1 cannot be accessed.'"), 
				Parameters.PathSimpleBon));
			Return False;
		EndTry;
	EndIf;
	
	TextDocument = New TextDocument;
	TextDocument.Clear();
	TextDocument.AddLine("KARAT");
	TextDocument.AddLine("PCIF client:");
	TextDocument.AddLine("P" + ""); // CUI_ClientStr
	TextDocument.Write(Parameters.PathSimpleBon, "windows-1251");
	
	NumberOfSession	= 0;
	NumberReceipt	= 0;
	Output_Parameters.Clear();
	Output_Parameters.Add(NumberOfSession);
	Output_Parameters.Add(NumberReceipt);
	Output_Parameters.Add(0); // Document number
	Output_Parameters.Add(EquipmentManagerClientOverridable.SessionDate());
	
	Return True;
	
EndFunction

// 
//
Function PrintFiscalLine(DriverObject, Parameters, ConnectionParameters, Description, Quantity, 
		Price, DiscountPercent, Amount, SectionNumber, VATRate, Output_Parameters) Export

	Result					= True;
	StructureFiscalString	= NewStructureFiscalString();
	DecimalPlacesPrice		= 2;
	KDecimalPlacesPrice		= 100;
	
	TextDocument = New TextDocument;
	TextDocument.Read(Parameters.PathSimpleBon);
	If VATRate = 19 OR VATRate = 24 OR VATRate = 20 Then
		StructureFiscalString.TaxGroup = "1"; // A
	ElsIf VATRate = 9 Then
		StructureFiscalString.TaxGroup = "2"; // B
	Else
		StructureFiscalString.TaxGroup = "0"; // C
	EndIf;
	
	//ECR ZEKA        ******** 00021000 2 000001000 1 0 0
	NameStr = TrimAll(Left(Description, 24));
	DescriptionStrLength = StrLen(NameStr);
	For N = 1 To 24 - DescriptionStrLength Do
		NameStr = NameStr + "*";
	EndDo;
	StructureFiscalString.NameStr = NameStr;
	
	PriceStr	= Format(Price * 100, "ND=8; NFD=0; NGS=; NG=");
	PriceStrLen	= StrLen(PriceStr);
	For N = 1 To 8 - PriceStrLen Do
		PriceStr = "0" + PriceStr;
	EndDo;
	StructureFiscalString.PriceStr = PriceStr;
	
	QuantityStr = Format(Quantity * 1000, "ND=8; NFD=0; NGS=; NG=");
	QuantityStrLen = StrLen(QuantityStr);
	For N = 1 To 9 - QuantityStrLen Do
		QuantityStr = "0" + QuantityStr;
	EndDo;
	
	StructureFiscalString.QuantityStr = QuantityStr;
	StructureFiscalString.Decimal     = Format(DecimalPlacesPrice, "ND=1; NFD=0");
	StructureFiscalString.Departament = SectionNumber;
	
	NewFiscalLine = StringFunctionsClientServer.SubstituteParametersInStringByName(
		"*[NameStr][PriceStr][Decimal][QuantityStr][TaxGroup][Departament]0",
		StructureFiscalString);
		
	TextDocument.AddLine(NewFiscalLine);
	
	Discount = Amount - (Quantity * Price);
	If Discount <> 0 Then
		TextDocument.AddLine("; Discount");
		Multiplier = ?(Discount < 0, -1, 1);
		MultiplierStr = ?(Multiplier = -1, "-", "+");
		Discount = Discount * Multiplier;
		DiscountStr = Format(Discount * KDecimalPlacesPrice, "ND=8; NFD=0; NGS=; NG=");
		DiscountStrLen = StrLen(DiscountStr);
		For N = 1 To 8 - DiscountStrLen Do
			DiscountStr = "0" + DiscountStr;
		EndDo;
		DiscountStructure = New Structure;
		DiscountStructure.Insert("MultiplierStr", MultiplierStr);
		DiscountStructure.Insert("DiscountStr",   DiscountStr);
		DiscountStructure.Insert("Decimal",       StructureFiscalString.Decimal);
		DiscountStructure.Insert("TaxGroup",      StructureFiscalString.TaxGroup);
		
		TextDiscount = StringFunctionsClientServer.SubstituteParametersInStringByName(
			"[MultiplierStr][DiscountStr][Decimal][TaxGroup]",
			DiscountStructure);
		
		TextDocument.AddLine(TextDiscount);
	EndIf;
	
	TextDocument.Write(Parameters.PathSimpleBon, "windows-1251");
	
	Return Result;
	
EndFunction

// 
//
Function CloseReceipt(DriverObject, Parameters, ConnectionParameters, PaymentsTable, Output_Parameters) Export
	
	SumOfCashVoucher		= 0;
	AmountOfNonCashVoucher	= 0;
	
	For PaymentIndex = 0 To PaymentsTable.Count() - 1 Do
		If PaymentsTable[PaymentIndex][0].Value = 0 Then
			SumOfCashVoucher = SumOfCashVoucher + PaymentsTable[PaymentIndex][1].Value;
		Else
			AmountOfNonCashVoucher = AmountOfNonCashVoucher + PaymentsTable[PaymentIndex][1].Value;
		EndIf;
	EndDo;
	
	DecimalPlacesPrice	= 2;
	KDecimalPlacesPrice	= 100;
	
	TextDocument = New TextDocument;
	TextDocument.Read(Parameters.PathSimpleBon);
	
	//RQ2CARD
	If AmountOfNonCashVoucher <> 0 Then
		TypePayment = "RQ2CARD      ";
		SumOfPaymentStr = Format(AmountOfNonCashVoucher * KDecimalPlacesPrice, "ND=8; NFD=0; NGS=; NG=");
		SumaCECStrLen = StrLen(SumOfPaymentStr);
		For N = 1 To 8 - SumaCECStrLen Do
			SumOfPaymentStr = "0" + SumOfPaymentStr;
		EndDo;
		
		TextDocument.AddLine(TypePayment + SumOfPaymentStr + Format(DecimalPlacesPrice, "ND=1; NFD=0"));
	EndIf;
	
	TextDocument.AddLine("T0000010000  CASH");
	TextDocument.AddLine("END KARAT");
	TextDocument.Write(Parameters.PathSimpleBon, "windows-1251");
	
	DirPath = StrReplace(Parameters.PathFprwin, TrimAll("fprwin_en.bat"), "");
	RunApp(Parameters.PathFprwin, DirPath);
	Result = True;
	
	Return Result;

EndFunction

// 
//
Function CancelReceipt(DriverObject, Parameters, ConnectionParameters, Output_Parameters) Export

	Result = True;
	Return Result;

EndFunction

// 
//
Function PrintReportWithoutBlanking(DriverObject, Parameters, ConnectionParameters, Output_Parameters)

	Result = True;
	
	DirPath = StrReplace(Parameters.PathXReport, "X.bat", "");
	RunApp(Parameters.PathXReport, TrimAll(DirPath));
	
	Return Result;

EndFunction

// 
//
Function PrintReportWithBlanking(DriverObject, Parameters, ConnectionParameters, Output_Parameters)

	Result = True;
	
	DirPath = StrReplace(Parameters.PathZReport, "Z.bat", "");
	RunApp(Parameters.PathZReport, TrimAll(DirPath));
	
	Return Result;

EndFunction

// 
//
Function DeviceTest(DriverObject, Parameters, ConnectionParameters, Output_Parameters)

	Result = True;
	
	ArrayFiles = New Array;
	ArrayFiles.Add(Parameters.PathFprwin);
	ArrayFiles.Add(Parameters.PathXReport);
	ArrayFiles.Add(Parameters.PathZReport);
	For Each TestFile In ArrayFiles Do
		File = New File(TestFile);
		If Not File.Exist() Then
			TextMessage = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'File %1 is not found. Check path to file.'"),
				TestFile);
			CommonUseClientServer.MessageToUser(TextMessage);
			Result = False;
			Break;
		EndIf;
	EndDo;
	
	Return Result;

EndFunction

// 
//
Function PrintNotFiscalLine(DriverObject, Parameters, ConnectionParameters, TextString, Output_Parameters) Export

	Result = True;
	Return Result;

EndFunction

// 
//
Function Encashment(DriverObject, Parameters, ConnectionParameters, EncashmentType, Amount, Output_Parameters)

	Result = True;
	Return Result;
	
EndFunction

// 
//
Function OpenCashDrawer (DriverObject, Parameters, ConnectionParameters, Output_Parameters)
	
	Result = True;
	Return Result;
	
EndFunction

// Fill default parameters of path files
//
Procedure FillDefaultParameters(Parameters)
	
	Parameters.Insert("PathFprwin",    "C:\SalesEquipmentDrivers\fprwin_en.bat");
	Parameters.Insert("PathXReport",   "C:\SalesEquipmentDrivers\X.bat");
	Parameters.Insert("PathZReport",   "C:\SalesEquipmentDrivers\Z.bat");
	Parameters.Insert("PathSimpleBon", "C:\SalesEquipmentDrivers\Simple.bon");
	
EndProcedure

// Constructor fiscal line structure
//
Function NewStructureFiscalString()
	
	StructureFiscalString = New Structure;
	StructureFiscalString.Insert("TaxGroup",    "");
	StructureFiscalString.Insert("NameStr",     "");
	StructureFiscalString.Insert("PriceStr",    "");
	StructureFiscalString.Insert("QuantityStr", "");
	StructureFiscalString.Insert("Departament", "1");
	StructureFiscalString.Insert("Decimal",     "");
	
	Return StructureFiscalString;
	
EndFunction

#EndRegion

#EndRegion
