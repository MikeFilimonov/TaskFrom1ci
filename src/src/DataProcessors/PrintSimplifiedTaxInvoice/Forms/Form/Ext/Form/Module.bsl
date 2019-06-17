
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	FillPropertyValues(Object, Parameters);
	
EndProcedure

&AtClient
Procedure PrintSimplifiedTaxInvoice(Command)
	
	If Not CheckFilling() Then
		Return;
	EndIf;
	
	DataStructure = New Structure;
	DataStructure.Insert("Date",			Object.Date);
	DataStructure.Insert("ReceiptNumber",	Object.ReceiptNumber);
	DataStructure.Insert("Company",			Object.Company);
	DataStructure.Insert("CashCR",			Object.CashCR);
	
	If Not FindReceipt(DataStructure) Then
		
		MessageText = NStr("en = 'Receipt # %1 is not found. Please verify the specified number or change other search parameters.'");
		
		ShowMessageBox(
			Undefined,
			StringFunctionsClientServer.SubstituteParametersInString(MessageText, Object.ReceiptNumber),
			15);
		
		Return;
		
	EndIf;
	
	OpenParameters = New Structure("PrintManagerName, TemplateNames, CommandParameter, PrintParameters");
	OpenParameters.PrintManagerName = "Document.SalesSlip";
	OpenParameters.TemplateNames	= "SimplifiedTaxInvoice";
	
	ObjectsArray = New Array;
	ObjectsArray.Add(PredefinedValue("Document.SalesSlip.EmptyRef"));
	ObjectsArray.Add(DataStructure);
	
	OpenParameters.CommandParameter	= ObjectsArray;
	OpenParameters.PrintParameters	= Undefined;
	
	OpenForm("CommonForm.PrintDocuments", OpenParameters, ThisForm, UniqueKey);
	
EndProcedure

&AtServerNoContext
Function FindReceipt(DataStructure)
	
	Query = New Query;
	
	Query.SetParameter("DateBeg", BegOfDay(DataStructure.Date));
	Query.SetParameter("DateEnd", EndOfDay(DataStructure.Date));
	Query.SetParameter("Company", DataStructure.Company);
	Query.SetParameter("CashCR", DataStructure.CashCR);
	Query.SetParameter("ReceiptNumber", DataStructure.ReceiptNumber);
	Query.SetParameter("ReceiptNumberWithNoughts", Right("000000" + TrimAll(DataStructure.ReceiptNumber), 6));
	
	Query.Text = 
	"SELECT
	|	ShiftClosure.Ref AS Ref
	|INTO ShiftClosures
	|FROM
	|	Document.ShiftClosure AS ShiftClosure
	|WHERE
	|	ShiftClosure.Date BETWEEN &DateBeg AND &DateEnd
	|	AND ShiftClosure.Company = &Company
	|	AND ShiftClosure.CashCR = &CashCR
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	TRUE AS STEEL
	|FROM
	|	ShiftClosures AS ShiftClosures
	|		INNER JOIN Document.ShiftClosure.Inventory AS ShiftClosureInventory
	|		ON ShiftClosures.Ref = ShiftClosureInventory.Ref
	|			AND (ShiftClosureInventory.ReceiptNumber = &ReceiptNumber
	|				OR ShiftClosureInventory.ReceiptNumber = &ReceiptNumberWithNoughts)";
	
	Return Not Query.Execute().IsEmpty();
	
EndFunction