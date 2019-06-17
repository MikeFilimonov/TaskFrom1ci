#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

// Method returns slice lats from LeadActivities register
//
// Parameters:
//	Lead - CatalogRef.Leads, Undefined - Lead  for slice last.
//	Date - Date, Undefined - Date for slice last.
//
// Returned value:
//	Structure - contains dimensions and and resources in keys.
//
Function LeadActivitiesAtDate(Val Lead = Undefined, Val Date = Undefined) Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	LeadActivities.Period AS Period,
	|	LeadActivities.Lead AS Lead,
	|	LeadActivities.Campaign AS Campaign,
	|	LeadActivities.SalesRep AS SalesRep,
	|	LeadActivities.Activity AS Activity
	|FROM
	|	InformationRegister.LeadActivities.SliceLast(&Date, &Condition) AS LeadActivities
	|";
	
	If Date = Undefined Then
		Query.SetParameter("Date", CurrentSessionDate());
	Else
		Query.SetParameter("Date", Date);
	EndIf;
	
	If ValueIsFilled(Lead) Then
		Query.Text = StrReplace(Query.Text, "&Condition", "Lead = &Lead");
		Query.SetParameter("Lead", Lead);
	Else
		Query.Text = StrReplace(Query.Text, "&Condition", "");
	EndIf;
	
	Selection = Query.Execute().Select();
	
	Result = EmptyRecords();
	Result.Lead = Lead;
	
	If Selection.Next() Then
		FillPropertyValues(Result, Selection);
	EndIf;
	
	Return Result;
EndFunction

#EndRegion

#Region Private

Function EmptyRecords()
	
	RecordsSet = InformationRegisters.LeadActivities.CreateRecordSet();
	Table = RecordsSet.UnloadColumns();
	
	EmptyRecords = New Structure();
	For Each Column In Table.Columns Do
		EmptyRecords.Insert(Column.Name, Undefined);
	EndDo;
	
	Return EmptyRecords;
EndFunction

#EndRegion

#EndIf