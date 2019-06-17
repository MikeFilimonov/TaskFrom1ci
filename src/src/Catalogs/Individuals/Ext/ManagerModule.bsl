#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Interface

// The procedure fills in the array of individuals persons
//
Function IndividualDocumentByType(Period, Individual, DocumentKind = Undefined) Export
	
	IndividualsDocuments = New Array;
	DocumentData = New Structure("Individual, DocumentKind, Number, IssueDate, ExpiryDate, Authority, Presentation");
	
	If Not ValueIsFilled(Individual) Then
		Return IndividualsDocuments;
	EndIf;
	
	If Not ValueIsFilled(Period) Then
		Period = CurrentSessionDate();
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	LegalDocuments.DocumentKind AS DocumentKind,
	|	LegalDocuments.Number AS Number,
	|	LegalDocuments.IssueDate AS IssueDate,
	|	LegalDocuments.DocumentKind.Presentation AS Presentation,
	|	LegalDocuments.ExpiryDate,
	|	LegalDocuments.Owner AS Individual,
	|	LegalDocuments.Authority
	|FROM
	|	Catalog.LegalDocuments AS LegalDocuments
	|WHERE
	|	LegalDocuments.Owner = &Ind
	|			AND &SearchConditionByDocumentKind
	|
	|ORDER BY
	|	IssueDate DESC";
	
	Query.SetParameter("Ind", Individual);
	
	If ValueIsFilled(DocumentKind) Then
		Query.Text = StrReplace(Query.Text, "&SearchConditionByDocumentKind", "DocumentKind = &DocumentKind");
		Query.SetParameter("DocumentKind", DocumentKind);
	Else
		Query.SetParameter("SearchConditionByDocumentKind", True); // select all documents
	EndIf;
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		FillPropertyValues(DocumentData, Selection);
		IndividualsDocuments.Add(DocumentData);
	EndDo;
	
	Return IndividualsDocuments;
	
EndFunction

#EndRegion

#EndIf