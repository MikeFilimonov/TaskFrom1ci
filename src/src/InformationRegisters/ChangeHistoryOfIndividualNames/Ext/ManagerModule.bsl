#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ProgramInterface

// Function returns full name by specified individual
//
Function IndividualDescriptionFull(RelevanceDate, Ind) Export
	
	Query = New Query(
	"SELECT
	|	ChangeHistoryOfIndividualNamesSliceLast.Surname,
	|	ChangeHistoryOfIndividualNamesSliceLast.Name,
	|	ChangeHistoryOfIndividualNamesSliceLast.Patronymic
	|FROM
	|	InformationRegister.ChangeHistoryOfIndividualNames.SliceLast(&RelevanceDate, Ind = &Ind) AS ChangeHistoryOfIndividualNamesSliceLast");
	
	Query.SetParameter("RelevanceDate", RelevanceDate);
	Query.SetParameter("Ind", Ind);
	
	QueryResult	= Query.Execute();
	
	If QueryResult.IsEmpty() Then
		
		Return "";
		
	EndIf;
	
	Selection = QueryResult.Select();
	Selection.Next();
	
	Return DriveServer.GetSurnameNamePatronymic(Selection.Surname, Selection.Name, Selection.Patronymic, True);
	
EndFunction

#EndRegion

#EndIf