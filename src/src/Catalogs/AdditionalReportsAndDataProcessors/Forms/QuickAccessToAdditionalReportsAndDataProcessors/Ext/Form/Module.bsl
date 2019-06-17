#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	Title = StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en = 'Quick access to the ""%1"" command'"),
		Parameters.CommandPresentation);
	
	FillTables();
	
EndProcedure

#EndRegion

#Region FormTableItemEventHandlersAllUsers

&AtClient
Procedure AllUsersDrag(Item, DragParameters, StandardProcessing, String, Field)
	
	If TypeOf(DragParameters.Value[0]) = Type("Number") Then
		Return;
	EndIf;
	
	MoveUsers(AllUsers, UsersOfShortList, DragParameters.Value);
	
EndProcedure

&AtClient
Procedure AllUsersDragCheck(Item, DragParameters, StandardProcessing, String, Field)
	
	StandardProcessing = False;
	
EndProcedure

#EndRegion

#Region FormTableItemEventHandlersShortListUsers

&AtClient
Procedure ShortListUsersDrag(Item, DragParameters, StandardProcessing, String, Field)
	
	If TypeOf(DragParameters.Value[0]) = Type("Number") Then
		Return;
	EndIf;
	
	MoveUsers(UsersOfShortList, AllUsers, DragParameters.Value);
	
EndProcedure

&AtClient
Procedure ShortListUsersDragCheck(Item, DragParameters, StandardProcessing, String, Field)
	
	StandardProcessing = False;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure RemoveAccessToCommandFromAllUsers(Command)
	
	ArrayOfDruggedItems = New Array;
	
	For Each RowDetails In UsersOfShortList Do
		ArrayOfDruggedItems.Add(RowDetails);
	EndDo;
	
	MoveUsers(AllUsers, UsersOfShortList, ArrayOfDruggedItems);
	
EndProcedure

&AtClient
Procedure RemoveAccessToCommandFromSelectedUsers(Command)
	
	ArrayOfDruggedItems = New Array;
	
	For Each SelectedRow In Items.UsersOfShortList.SelectedRows Do
		ArrayOfDruggedItems.Add(Items.UsersOfShortList.RowData(SelectedRow));
	EndDo;
	
	MoveUsers(AllUsers, UsersOfShortList, ArrayOfDruggedItems);
	
EndProcedure

&AtClient
Procedure SetAccessForAllUsers(Command)
	
	ArrayOfDruggedItems = New Array;
	
	For Each RowDetails In AllUsers Do
		ArrayOfDruggedItems.Add(RowDetails);
	EndDo;
	
	MoveUsers(UsersOfShortList, AllUsers, ArrayOfDruggedItems);
	
EndProcedure

&AtClient
Procedure SetCommandForSelectedUsers(Command)
	
	ArrayOfDruggedItems = New Array;
	
	For Each SelectedRow In Items.AllUsers.SelectedRows Do
		ArrayOfDruggedItems.Add(Items.AllUsers.RowData(SelectedRow));
	EndDo;
	
	MoveUsers(UsersOfShortList, AllUsers, ArrayOfDruggedItems);
	
EndProcedure

&AtClient
Procedure OK(Command)
	
	ChoiceResult = New ValueList;
	
	For Each CollectionItem In UsersOfShortList Do
		ChoiceResult.Add(CollectionItem.User);
	EndDo;
	
	NotifyChoice(ChoiceResult);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure FillTables()
	SelectedList = Parameters.UsersWithFastAccess;
	Query = New Query("SELECT Ref FROM Catalog.Users WHERE NOT DeletionMark AND NOT NotValid");
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		If SelectedList.FindByValue(Selection.Ref) = Undefined Then
			AllUsers.Add().User = Selection.Ref;
		Else
			UsersOfShortList.Add().User = Selection.Ref;
		EndIf;
	EndDo;
	AllUsers.Sort("User Asc");
	UsersOfShortList.Sort("User Asc");
EndProcedure

&AtClient
Procedure MoveUsers(Receiver, Source, ArrayOfDruggedItems)
	
	For Each DraggedItem In ArrayOfDruggedItems Do
		NewUser = Receiver.Add();
		NewUser.User = DraggedItem.User;
		Source.Delete(DraggedItem);
	EndDo;
	
	Receiver.Sort("User Asc");
	
EndProcedure

#EndRegion
