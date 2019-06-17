#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Interface

//  Checks infobase for duplicate items
//
//  Returns:
//      Undefined - no errors
//      Structure - infobase item description. Fields:
//          * ErrorDescription - String - error text
//          * Code             - String - attribute of the existing infobase item 
//          * Description      - String - attribute of the existing infobase item 
//          * LongDescription  - String - attribute of the existing infobase item 
//          * AlphaCode2       - String - attribute of the existing infobase item 
//          * AlphaCode3       - String - attribute of the existing infobase item 
//          * Ref              - CatalogRef.Countries - attribute of the existing infobase item
//
Function ExistingItem() Export
	
	Result = Undefined;
	
	// Ignoring non-numerical codes
	NumberType = New TypeDescription("Number", New NumberQualifiers(3, 0, AllowedSign.Nonnegative));
	If Code = "0" OR Code = "00" OR Code = "000" Then
		SearchCode = "000";
	Else
		SearchCode = Format(NumberType.AdjustValue(Code), "ND=3; NFD=2; NZ=; NLZ=");
		If SearchCode = "000" Then
			Return Result; // Not numerical
		EndIf;
	EndIf;
		
	Query = New Query(
		"SELECT TOP 1
		|	Countries.Code AS Code,
		|	Countries.Description AS Description,
		|	Countries.LongDescription AS LongDescription,
		|	Countries.AlphaCode2 AS AlphaCode2,
		|	Countries.AlphaCode3 AS AlphaCode3,
		|	Countries.Ref AS Ref
		|FROM
		|	Catalog.Countries AS Countries
		|WHERE
		|	Countries.Code = &Code
		|	AND Countries.Ref <> &Ref");
	Query.SetParameter("Ref",	Ref);
	Query.SetParameter("Code",	SearchCode);
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	If Selection.Next() Then
		
		Result = New Structure("ErrorDescription", StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Code %1 is already assigned to country %2. Enter another code, or use the existing data.'"), 
			Code, Selection.Description));
		
		For Each Field In QueryResult.Columns Do
			Result.Insert(Field.Name, Selection[Field.Name]);
		EndDo;
		
	EndIf;
	
	Return Result;
	
EndFunction

#EndRegion

#Region EventHandlers
//

Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load OR AdditionalProperties.Property("DontCheckUniqueness") Then
		Return;
	EndIf;
	
	If Not CheckFilling() Then
		Cancel = True;
	EndIf;
	
EndProcedure

Procedure FillCheckProcessing(Cancel, AttributesToCheck)
	
	Existing = ExistingItem();
	If Existing <> Undefined Then
		Cancel = True;
		CommonUseClientServer.MessageToUser(Existing.ErrorDescription,, "Object.Description");
	EndIf;
	
EndProcedure

Procedure Filling(FillingData, StandardProcessing)
	If FillingData<>Undefined Then
		FillPropertyValues(ThisObject, FillingData);
	EndIf;
EndProcedure

#EndRegion

#EndIf
