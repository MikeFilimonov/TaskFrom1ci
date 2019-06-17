
#Region GeneralPurposeProceduresAndFunctions

// Procedure colors list.
//
&AtServer
Procedure PaintList()
	
	// List coloring
	ListOfItemsForDeletion = New ValueList;
	For Each ConditionalAppearanceItem In List.SettingsComposer.Settings.ConditionalAppearance.Items Do
		If ConditionalAppearanceItem.UserSettingID = "Preset" Then
			ListOfItemsForDeletion.Add(ConditionalAppearanceItem);
		EndIf;
	EndDo;
	For Each Item In ListOfItemsForDeletion Do
		List.SettingsComposer.Settings.ConditionalAppearance.Items.Delete(Item.Value);
	EndDo;
	
	SelectionJobAndEventStatuses = Catalogs.JobAndEventStatuses.Select();
	While SelectionJobAndEventStatuses.Next() Do
		
		BackColor = SelectionJobAndEventStatuses.Color.Get();
		If TypeOf(BackColor) <> Type("Color") Then
			Continue;
		EndIf; 
		
		ConditionalAppearanceItem = List.SettingsComposer.Settings.ConditionalAppearance.Items.Add();
	
		FilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
		
		FilterItem.LeftValue = New DataCompositionField("State");
		FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
		FilterItem.RightValue = SelectionJobAndEventStatuses.Ref;
		
		ConditionalAppearanceItem.Appearance.SetParameterValue("TextColor", BackColor);
		ConditionalAppearanceItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
		ConditionalAppearanceItem.UserSettingID = "Preset";
		ConditionalAppearanceItem.Presentation = "By event state " + SelectionJobAndEventStatuses.Description;
	
	EndDo;
	
EndProcedure

&AtServer
// Procedure updates data in the list table.
//
Procedure UpdateListTaskByPeriod()
	
	List.Parameters.SetParameterValue("PeriodOfBegin", Date(1,1,1));
	List.Parameters.SetParameterValue("PeriodOfEnd", Date(1,1,1));
	
EndProcedure

&AtServer
// Procedure sets filter in the list table for section To-do list.
//
Procedure SetFilterToDoList()
	
	If Not Parameters.Property("ToDoList") Then
		Return;
	EndIf;
	
	ListOfState = New ValueList;
	ListOfState.Add(Catalogs.JobAndEventStatuses.Canceled);
	ListOfState.Add(Catalogs.JobAndEventStatuses.Completed);
	DriveClientServer.SetListFilterItem(List, "State", ListOfState, True, DataCompositionComparisonType.NotInList);
	
	FormHeaderText = "";
	If Parameters.Property("PastPerformance") Then
		FormHeaderText = "Tasks: overdue";
		List.Parameters.SetParameterValue("PeriodOfEnd", CurrentSessionDate());
		DriveClientServer.SetListFilterItem(List, "Overdue", True);
	EndIf;
	
	If Parameters.Property("ForToday") Then
		FormHeaderText = "Tasks: for today";
		List.Parameters.SetParameterValue("PeriodOfBegin", EndOfDay(CurrentSessionDate()));
		List.Parameters.SetParameterValue("PeriodOfEnd", CurrentSessionDate());
		DriveClientServer.SetListFilterItem(List, "ForToday", True);
	EndIf;
	
	If Parameters.Property("Planned") Then
		FormHeaderText = "Tasks: planned";
	EndIf;
	
	If Parameters.Property("OnControl") Then
		FormHeaderText = "Tasks: on control";
	EndIf;
	
	If Parameters.Property("Responsible") Then
		DriveClientServer.SetListFilterItem(List, "Employee", Parameters.Responsible.List, True, DataCompositionComparisonType.InList);
		FormHeaderText = FormHeaderText + ", responsible " + Parameters.Responsible.Initials;
	EndIf;
	
	If Parameters.Property("Performer") Then
		DriveClientServer.SetListFilterItem(List, "Employee", Parameters.Performer, True, DataCompositionComparisonType.NotInList);
	EndIf;
	
	If Parameters.Property("Author") Then
		DriveClientServer.SetListFilterItem(List, "Author", Parameters.Author.User);
		FormHeaderText = FormHeaderText + ", author " + Parameters.Author.Initials;
	EndIf;
	
	If Not IsBlankString(FormHeaderText) Then
		AutoTitle = False;
		Title = FormHeaderText;
	EndIf;
	
EndProcedure

#EndRegion

#Region ProcedureFormEventHandlers

// Procedure - OnCreateAtServer event handler.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	PaintList();
	UpdateListTaskByPeriod();
	
	SetFilterToDoList();
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisForm, Items.ImportantCommandsGroup);
	// End StandardSubsystems.Printing
	
EndProcedure

// Procedure - handler of form notification.
//
&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "Record_JobAndEventStatuses" Then
		PaintList();
	EndIf;
	
EndProcedure

#Region LibrariesHandlers

// StandardSubsystems.Printing
&AtClient
Procedure Attachable_ExecutePrintCommand(Command)
	PrintManagementClient.ExecuteConnectedPrintCommand(Command, ThisObject, Items.List);
EndProcedure
// End StandardSubsystems.Printing

#EndRegion

#EndRegion
