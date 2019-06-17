#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// Procedure fills choice data.
//
Procedure FillChoiceData(ChoiceData, Parameters)
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	CompanyResourceTypes.CompanyResource AS CompanyResource,
	|	CompanyResourceTypes.CompanyResource.Description AS CompanyResourceDescription,
	|	CompanyResourceTypes.CompanyResource.Code AS CompanyResourceCode
	|FROM
	|	InformationRegister.CompanyResourceTypes AS CompanyResourceTypes
	|WHERE
	|	CompanyResourceTypes.CompanyResourceType = &CompanyResourceType
	|
	|GROUP BY
	|	CompanyResourceTypes.CompanyResource,
	|	CompanyResourceTypes.CompanyResource.Description,
	|	CompanyResourceTypes.CompanyResource.Code
	|
	|HAVING
	|	SubString(CompanyResourceTypes.CompanyResource.Description, 1, &SubstringLength) LIKE &SearchString
	|
	|ORDER BY
	|	CompanyResourceDescription";
	
	Query.SetParameter("CompanyResourceType", Parameters.FilterResourceKind);
	Query.SetParameter("SearchString", Parameters.SearchString);
	Query.SetParameter("SubstringLength", StrLen(Parameters.SearchString));
	
	Result = Query.Execute();
	If Not Result.IsEmpty() Then
		ChoiceData = New ValueList;
		Selection = Result.Select();
		While Selection.Next() Do
			PresentationOfChoice = TrimAll(Selection.CompanyResource) + " (" + TrimAll(Selection.CompanyResourceCode) + ")";
			ChoiceData.Add(Selection.CompanyResource, PresentationOfChoice);
		EndDo;
	EndIf;
		
EndProcedure

Procedure ChoiceDataGetProcessing(ChoiceData, Parameters, StandardProcessing)
	
	If Parameters.Property("FilterResourceKind") Then
		
		FilterResourceKind = Parameters.FilterResourceKind;
		If ValueIsFilled(FilterResourceKind) Then
			
			StandardProcessing = False;
			FillChoiceData(ChoiceData, Parameters);
			
		EndIf;
		
	EndIf;
	
EndProcedure

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