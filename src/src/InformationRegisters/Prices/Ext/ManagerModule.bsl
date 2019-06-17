#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ProgramInterface

// Function returns the key of the register record.
//
Function GetRecordKey(ParametersStructure) Export

	Query = New Query;
	Query.Text = 
		"SELECT TOP 1
		|	PricesSliceLast.Period
		|FROM
		|	InformationRegister.Prices.SliceLast(
		|			&ToDate,
		|			PriceKind = &PriceKind
		|				AND Products = &Products
		|				AND Characteristic = &Characteristic) AS PricesSliceLast";
	
	Query.SetParameter("ToDate", ParametersStructure.Period);
	Query.SetParameter("Products", ParametersStructure.Products);
	Query.SetParameter("Characteristic", ParametersStructure.Characteristic);
	Query.SetParameter("PriceKind", ParametersStructure.PriceKind);
	
	ReturnStructure = New Structure("RecordExists, Period, PriceKind, Products, Characteristic", False);
	FillPropertyValues(ReturnStructure, ParametersStructure);
	
	ResultTable = Query.Execute().Unload();
	If ResultTable.Count() > 0 Then
		
		ReturnStructure.Period = ResultTable[0].Period;
		ReturnStructure.RecordExists = True;
		
	EndIf; 

	Return ReturnStructure;

EndFunction

// Sets register record by transferred data
//
Procedure SetChangeBasicSalesPrice(FillingData) Export
	
	RecordManager = CreateRecordManager();
	FillPropertyValues(RecordManager, FillingData);
	RecordManager.Author = Users.AuthorizedUser();
	RecordManager.Write(True);
	
EndProcedure

// Function returns the list of the "key" attributes names.
//
Function GetObjectAttributesBeingLocked() Export
	
	Result = New Array;
	
	Return Result;
	
EndFunction

#EndRegion

#EndIf