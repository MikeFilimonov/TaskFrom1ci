// Returns the array of strings weekly.
//
&AtServer
Function GetArrayOfRows(DocumentRef)
	
	Query = New Query();
	Query.Text =
	"SELECT
	|	WorkOrderWorks.LineNumber AS LineNumber,
	|	BEGINOFPERIOD(WorkOrderWorks.Day, WEEK) AS BegOfWeek
	|FROM
	|	Document.ObsoleteWorkOrder.Works AS WorkOrderWorks
	|WHERE
	|	WorkOrderWorks.Ref = &Ref
	|
	|ORDER BY
	|	BegOfWeek
	|TOTALS BY
	|	BegOfWeek";
	
	Query.SetParameter("Ref", DocumentRef);
	ArrayOfArraysOfRows = New Array;
	
	SelectionBeginOfWeek = Query.Execute().Select(QueryResultIteration.ByGroups, "BegOfWeek");
	While SelectionBeginOfWeek.Next() Do
		RowArray = New Array;
		Selection = SelectionBeginOfWeek.Select();
		While Selection.Next() Do
			RowArray.Add(Selection.LineNumber);
		EndDo;
		ArrayOfArraysOfRows.Add(RowArray);
	EndDo;
	
	Return ArrayOfArraysOfRows;
	
EndFunction

// Procedure of command data processor.
//
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	RowArray = GetArrayOfRows(CommandParameter);
	
	For Each ArrayElement In RowArray Do
		ParametersStructure = New Structure;
		ParametersStructure.Insert("Basis", CommandParameter);
		ParametersStructure.Insert("RowArray", ArrayElement);
		Parameters = New Structure("Basis", ParametersStructure);
		OpenForm("Document.WeeklyTimesheet.ObjectForm", Parameters, ,Parameters);
	EndDo;
	
	If RowArray.Count() = 0 Then
		ParametersStructure = New Structure;
		ParametersStructure.Insert("Basis", CommandParameter);
		ParametersStructure.Insert("RowArray", Undefined);
		Parameters = New Structure("Basis", ParametersStructure);
		OpenForm("Document.WeeklyTimesheet.ObjectForm", Parameters, ,Parameters);
	EndIf;
	
EndProcedure
