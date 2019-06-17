////////////////////////////////////////////////////////////////////////////////
// Subsystem "Group object change".
//
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Used for the opening of the form of objects group change.
//
// Parameters:
//  List - FormTable - list form item containing references to the objects being changed.
//
Procedure ChangeSelected(List) Export
	
	SelectedRows = List.SelectedRows;
	
	FormParameters = New Structure("ObjectsArray", New Array);
	
	For Each SelectedRow In SelectedRows Do
		If TypeOf(SelectedRow) = Type("DynamicalListGroupRow") Then
			Continue;
		EndIf;
		
		CurrentRow = List.RowData(SelectedRow);
		
		If CurrentRow <> Undefined Then
			
			FormParameters.ObjectsArray.Add(CurrentRow.Ref);
			
		EndIf;
		
	EndDo;
	
	If FormParameters.ObjectsArray.Count() = 0 Then
		ShowMessageBox(, NStr("en = 'Command cannot be executed for the specified object.'"));
		Return;
	EndIf;
		
	OpenForm("DataProcessor.BatchAttributeEditor.Form", FormParameters);
	
EndProcedure

#EndRegion
