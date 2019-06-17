#If Server Or ThickClientOrdinaryApplication Then

#Region PrintInterface

// Fills in the list of printing commands.
// 
// Parameters:
//   PrintCommands - ValueTable - see the fields content in the PrintManagement.CreatePrintCommandsCollection function
//
Procedure AddPrintCommands(PrintCommands) Export
	
	
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// Gets the contact person which belongs to the counterparty.
//
// Parameters:
//  Counterparty - CatalogRef.Counterparties - owner of contact persons.
//
// Returns:
//  CatalogRef.ContactPersons - if there is contact person marked as default or there is only
//  one contact person, otherwise returns EmptyRef.
//
Function GetDefaultContactPerson(Counterparty) Export
	
	Result = Catalogs.ContactPersons.EmptyRef();
	
	If (TypeOf(Counterparty) = Type("CatalogRef.Counterparties")) Then
	
		If ValueIsFilled(Counterparty.ContactPerson) Then
			Result = Counterparty.ContactPerson;
		Else
			
			Query = New Query;	
			Query.Text = 
			"SELECT ALLOWED
			|	ContactPersons.Ref AS Ref
			|FROM
			|	Catalog.ContactPersons AS ContactPersons
			|WHERE
			|	ContactPersons.Owner = &Owner";
			
			Query.SetParameter("Owner", Counterparty);
			
			QueryResult = Query.Execute();
			If NOT QueryResult.IsEmpty() Then
			
				QueryResultTable = QueryResult.Unload();
				If QueryResultTable.Count() = 1 Then
					Result = QueryResultTable[0].Ref;
				EndIf;
			
			EndIf;
			
		EndIf;
	
	EndIf;
	
	Return Result;
	
EndFunction

#EndRegion

#EndIf