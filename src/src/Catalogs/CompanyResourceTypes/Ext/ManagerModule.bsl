#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// Procedure fills choice data.
//
Procedure FillChoiceData(ChoiceData, Parameters)
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	CompanyResourceTypes.Ref AS Ref,
	|	CompanyResourceTypes.Description AS CompanyResourceDescription,
	|	CompanyResourceTypes.Code AS CompanyResourceCode
	|FROM
	|	Catalog.CompanyResourceTypes AS CompanyResourceTypes
	|WHERE
	|	CompanyResourceTypes.Ref <> &AllResources
	|
	|GROUP BY
	|	CompanyResourceTypes.Ref,
	|	CompanyResourceTypes.Description,
	|	CompanyResourceTypes.Code
	|
	|HAVING
	|	SubString(CompanyResourceTypes.Description, 1, &SubstringLength) LIKE &SearchString
	|
	|ORDER BY
	|	CompanyResourceDescription";
	
	Query.SetParameter("AllResources", Catalogs.CompanyResourceTypes.AllResources);
	Query.SetParameter("SearchString", Parameters.SearchString);
	Query.SetParameter("SubstringLength", StrLen(Parameters.SearchString));
	
	Result = Query.Execute();
	If Not Result.IsEmpty() Then
		ChoiceData = New ValueList;
		Selection = Result.Select();
		While Selection.Next() Do
			PresentationOfChoice = TrimAll(Selection.Ref) + " (" + TrimAll(Selection.CompanyResourceCode) + ")";
			ChoiceData.Add(Selection.Ref, PresentationOfChoice);
		EndDo;
	EndIf;
		
EndProcedure

Procedure ChoiceDataGetProcessing(ChoiceData, Parameters, StandardProcessing)
	
	StandardProcessing = False;
	FillChoiceData(ChoiceData, Parameters);
	
EndProcedure

#EndIf