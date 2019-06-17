#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

// Event handler procedure ChoiceDataGetProcessor.
//
Procedure ChoiceDataGetProcessing(ChoiceData, Parameters, StandardProcessing)
	
	If Parameters.Filter.Property("Owner")
		AND ValueIsFilled(Parameters.Filter.Owner)
		AND NOT Parameters.Filter.Owner.UseSerialNumbers Then
		
		Message = New UserMessage();
		Message.Text = NStr("en = 'For the products serial numbers are not accounted.'");
		Message.Message();
		StandardProcessing = False;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region PrintInterface

// Fills in the list of printing commands.
// 
// Parameters:
//   PrintCommands - ValueTable - see the fields content in the PrintManagement.CreatePrintCommandsCollection function
//
Procedure AddPrintCommands(PrintCommands) Export
	
	
	
EndProcedure

#EndRegion

#EndIf

#Region ProgramInterface

// Calculates the maximum serial number that is already used
// for the product type or is already listed in the ValueTable "TableSeries"
// 
//	Parameters
//  ProductsKind - CatalogRef.ProductsKinds - type of the product for which the serial number is
//      searched in TableSerial - ValueTable - A value table containing the series numbers used on the form
//
//   Return value:
// ValueOfCodeNumber - Number - SerialNumber
Function CalculateMaximumSerialNumber(Owner, TemplateSerialNumber=Undefined)  Export 
	
	TemplateString = "";
	If TemplateSerialNumber=Undefined OR NOT ValueIsFilled(TemplateSerialNumber) Then
		// 8 numbers
		TemplateString = "[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]";
		TemplateSerialNumberAsString = "########";
	Else	
		For n=1 To StrLen(TemplateSerialNumber) Do
			Symb = Mid(TemplateSerialNumber, n, 1);
			If Symb=WorkWithSerialNumbersClientServer.CharNumber() Then
				TemplateString = TemplateString + "[0-9]";
			Else
				TemplateString = TemplateString + Symb;
			EndIf;
		EndDo;
		TemplateSerialNumberAsString = String(TemplateSerialNumber);
	EndIf;
	
	Query = New Query;
	Query.Text =	
	"SELECT TOP 1
	|	SerialNumbers.Description AS Description
	|FROM
	|	Catalog.SerialNumbers AS SerialNumbers
	|WHERE
	|	SerialNumbers.Owner = &Owner
	|	AND NOT SerialNumbers.DeletionMark
	|	AND SerialNumbers.Description LIKE """+TemplateString+"""
	|
	|ORDER BY
	|	SerialNumbers.Description DESC";
	
	Query.SetParameter("Owner", Owner);
	Selection = Query.Execute().Select();
	Selection.Next();
	
	If Selection.Count()=0 Then
		NumberTypeDescription = New TypeDescription("Number", New NumberQualifiers(8, 0, AllowedSign.Nonnegative));
		ValueOfCodeNumber = NumberTypeDescription.AdjustValue(Selection.Description);
	Else
		ValueOfCodeNumber = SerialNumberNumericByTemplate(Selection.Description, TemplateSerialNumberAsString);
	EndIf; 
	
	Return ValueOfCodeNumber;
	
EndFunction

Function SerialNumberFromNumericByTemplate(SerialNumberNumeric, TemplateSerialNumberAsString, NumericPartLength) Export
	
	AddZerosInSerialNumber = String(SerialNumberNumeric);
	For n=1 To NumericPartLength - StrLen(SerialNumberNumeric) Do
		AddZerosInSerialNumber = "0"+AddZerosInSerialNumber;
	EndDo;
	
	SerialNumberByTemplate = "";
	NumericCharacterNumber = 1;
	For n=1 To StrLen(TemplateSerialNumberAsString) Do
		Symb = Mid(TemplateSerialNumberAsString, n, 1);
		If Symb=WorkWithSerialNumbersClientServer.CharNumber() Then
			SerialNumberByTemplate = SerialNumberByTemplate + Mid(AddZerosInSerialNumber,NumericCharacterNumber,1);
			NumericCharacterNumber = NumericCharacterNumber+1;
		Else
			SerialNumberByTemplate = SerialNumberByTemplate + Mid(TemplateSerialNumberAsString,n,1);
		EndIf;
	EndDo;
	
	Return SerialNumberByTemplate;
	
EndFunction

Function SerialNumberNumericByTemplate(SerialNumber, TemplateSerialNumberAsString) Export
	
	SerialNumberFromNumbers = "";
	For n=1 To StrLen(TemplateSerialNumberAsString) Do
		Symb = Mid(TemplateSerialNumberAsString,n,1);
		If Symb=WorkWithSerialNumbersClientServer.CharNumber() Then
			SerialNumberFromNumbers = SerialNumberFromNumbers+Mid(SerialNumber,n,1);
		EndIf;
	EndDo;
	
	NumberTypeDescription = New TypeDescription("Number");
	Return NumberTypeDescription.AdjustValue(SerialNumberFromNumbers);
	
EndFunction

// Returns the names of the details that should not be displayed in the list of GroupObjectsChange data processor details
//
//	Return value:
//		Array - array of
// attributes names
Function NotEditableInGroupProcessingAttributes() Export
	
	NotEditableAttributes = New Array;
	NotEditableAttributes.Add("Number");
	
	Return NotEditableAttributes;
	
EndFunction

Function GuaranteePeriod(SerialNumber, CheckDate) Export
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	SerialNumbersInWarranty.Recorder,
	|	SerialNumbersInWarranty.Recorder.Number AS DocumentSalesNumber,
	|	SerialNumbersInWarranty.Products.GuaranteePeriod AS GuaranteePeriodMonths,
	|	SerialNumbersInWarranty.EventDate AS SaleDate,
	|	DATEDIFF(SerialNumbersInWarranty.EventDate, &CheckDate, MONTH) AS MonthsPassed,
	|	DATEADD(SerialNumbersInWarranty.EventDate, MONTH, SerialNumbersInWarranty.Products.GuaranteePeriod) AS GuaranteeBefore,
	|	SerialNumbersInWarranty.SerialNumber.Owner.WriteOutTheGuaranteeCard AS WriteOutTheGuaranteeCard
	|FROM
	|	InformationRegister.SerialNumbersInWarranty AS SerialNumbersInWarranty
	|WHERE
	|	SerialNumbersInWarranty.SerialNumber = &SerialNumber
	|	AND SerialNumbersInWarranty.Operation = &Operation
	|
	|ORDER BY
	|	SerialNumbersInWarranty.EventDate DESC";
	
	Query.SetParameter("SerialNumber", SerialNumber);
	Query.SetParameter("Operation", Enums.SerialNumbersOperations.Expense);
	Query.SetParameter("CheckDate", CheckDate);
	
	Result = Query.Execute();
	Selection = Result.Select();
	
	ReturnStructure = New Structure;
	If Selection.Next() Then
		If Selection.GuaranteePeriodMonths > Selection.MonthsPassed Then
			ReturnStructure.Insert("Guarantee", True);
		Else
			ReturnStructure.Insert("Guarantee", False);
		EndIf;
		ReturnStructure.Insert("GuaranteePeriod",Selection.GuaranteeBefore);
		ReturnStructure.Insert("GuaranteeNumber",Selection.DocumentSalesNumber);
		ReturnStructure.Insert("DocumentSales",Selection.Recorder);
	EndIf;
	
	Return ReturnStructure;
	
EndFunction

#EndRegion