#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	DisplaySettings = ToDoListService.SavedDisplaySettings();
	FillToDosTree(DisplaySettings);
	SetSectionsOrder(DisplaySettings);
	
	AutoUpdateSettings = CommonUse.CommonSettingsStorageImport("ToDoList", "AutoUpdateSettings");
	If TypeOf(AutoUpdateSettings) = Type("Structure") Then
		AutoUpdateSettings.Property("AutoupdateOn", UseAutoupdate);
		AutoUpdateSettings.Property("AutoUpdatePeriod", UpdatePeriod);
	Else
		UpdatePeriod = 5;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormManagementItemsEventsHandlers

&AtClient
Procedure DisplayedWorkTreeOnChange(Item)
	
	Modified = True;
	If Item.CurrentData.ThisIsSection Then
		For Each Work In Item.CurrentData.GetItems() Do
			Work.Check = Item.CurrentData.Check;
		EndDo;
	ElsIf Item.CurrentData.Check Then
		Item.CurrentData.GetParent().Check = True;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure OKButton(Command)
	
	SaveSettings();
	
	If AutoupdateOn Then
		Notify("ToDoList_AutoUpdateEnabled");
	ElsIf AutoupdateOff Then
		Notify("ToDoList_AutoUpdateDisabled");
	EndIf;
	
	Close(Modified);
	
EndProcedure

&AtClient
Procedure ButtonCancel(Command)
	Close(False);
EndProcedure

&AtClient
Procedure MoveUp(Command)
	
	Modified = True;
	// Transfer the current row 1 position higher.
	CurrentTreeRow = Items.DisplayedWorkTree.CurrentData;
	
	If CurrentTreeRow.ThisIsSection Then
		TreeSections = DisplayedWorkTree.GetItems();
	Else
		ToDoParent = CurrentTreeRow.GetParent();
		TreeSections= ToDoParent.GetItems();
	EndIf;
	
	IndexOfCurrentRow = CurrentTreeRow.IndexOf;
	If IndexOfCurrentRow = 0 Then
		Return; // The current row at the top of the list, do not transfer.
	EndIf;
	TreeSections.Move(CurrentTreeRow.IndexOf, -1);
	CurrentTreeRow.IndexOf = IndexOfCurrentRow - 1;
	// Change the index of previous row.
	PreviousRow = TreeSections.Get(IndexOfCurrentRow);
	PreviousRow.IndexOf = IndexOfCurrentRow;
	
EndProcedure

&AtClient
Procedure MoveDown(Command)
	
	Modified = True;
	// Transfer the current row 1 position lower.
	CurrentTreeRow = Items.DisplayedWorkTree.CurrentData;
	
	If CurrentTreeRow.ThisIsSection Then
		TreeSections = DisplayedWorkTree.GetItems();
	Else
		ToDoParent = CurrentTreeRow.GetParent();
		TreeSections= ToDoParent.GetItems();
	EndIf;
	
	IndexOfCurrentRow = CurrentTreeRow.IndexOf;
	If IndexOfCurrentRow = (TreeSections.Count() -1) Then
		Return; // The current row at the bottom of the list, do not transfer.
	EndIf;
	TreeSections.Move(CurrentTreeRow.IndexOf, 1);
	CurrentTreeRow.IndexOf = IndexOfCurrentRow + 1;
	// Change the index of current row.
	NextString = TreeSections.Get(IndexOfCurrentRow);
	NextString.IndexOf = IndexOfCurrentRow;
	
EndProcedure

&AtClient
Procedure UncheckAll(Command)
	
	Modified = True;
	For Each SectionRow In DisplayedWorkTree.GetItems() Do
		SectionRow.Check = False;
		For Each ToDoRow In SectionRow.GetItems() Do
			ToDoRow.Check = False;
		EndDo;
	EndDo;
	
EndProcedure

&AtClient
Procedure CheckAll(Command)
	
	Modified = True;
	For Each SectionRow In DisplayedWorkTree.GetItems() Do
		SectionRow.Check = True;
		For Each ToDoRow In SectionRow.GetItems() Do
			ToDoRow.Check = True;
		EndDo;
	EndDo;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure FillToDosTree(DisplaySettings)
	
	ToDoList   = GetFromTempStorage(Parameters.ToDoList);
	WorkTree     = FormAttributeToValue("DisplayedWorkTree");
	CurrentSection = "";
	IndexOf        = 0;
	ToDoIndex    = 0;
	
	If DisplaySettings = Undefined Then
		SetInitialSectionsOrder(ToDoList);
	EndIf;
	
	For Each Work In ToDoList Do
		
		If Work.ThisIsSection
			AND CurrentSection <> Work.IDOwner Then
			TreeRow = WorkTree.Rows.Add();
			TreeRow.Presentation = Work.PresentationOfSection;
			TreeRow.ID = Work.IDOwner;
			TreeRow.ThisIsSection     = True;
			TreeRow.Check       = True;
			TreeRow.IndexOf        = IndexOf;
			
			If DisplaySettings <> Undefined Then
				SectionVisible = DisplaySettings.SectionsVisible[TreeRow.ID];
				If SectionVisible <> Undefined Then
					TreeRow.Check = SectionVisible;
				EndIf;
			EndIf;
			IndexOf     = IndexOf + 1;
			ToDoIndex = 0;
			
		ElsIf Not Work.ThisIsSection Then
			ToDoParent = WorkTree.Rows.Find(Work.IDOwner, "ID", True);
			If ToDoParent = Undefined Then
				Continue;
			EndIf;
			ToDoParent.WorkDetails = ToDoParent.WorkDetails + ?(IsBlankString(ToDoParent.WorkDetails), "", Chars.LF) + Work.Presentation;
			Continue;
		EndIf;
		
		ToDoRow = TreeRow.Rows.Add();
		ToDoRow.Presentation = Work.Presentation;
		ToDoRow.ID = Work.ID;
		ToDoRow.ThisIsSection     = False;
		ToDoRow.Check       = True;
		ToDoRow.IndexOf        = ToDoIndex;
		
		If DisplaySettings <> Undefined Then
			ToDoVisible = DisplaySettings.WorkVisible[ToDoRow.ID];
			If ToDoVisible <> Undefined Then
				ToDoRow.Check = ToDoVisible;
			EndIf;
		EndIf;
		ToDoIndex = ToDoIndex + 1;
		
		CurrentSection = Work.IDOwner;
		
	EndDo;
	
	ValueToFormAttribute(WorkTree, "DisplayedWorkTree");
	
EndProcedure

&AtServer
Procedure SaveSettings()
	
	DisplayOldSettings = CommonUse.CommonSettingsStorageImport("ToDoList", "DisplaySettings");
	CollapsedSections = Undefined;
	If TypeOf(DisplayOldSettings) = Type("Structure") Then
		DisplayOldSettings.Property("CollapsedSections", CollapsedSections);
	EndIf;
	
	If CollapsedSections = Undefined Then
		CollapsedSections = New Map;
	EndIf;
	
	// Save location and visible of sections.
	SectionsVisible = New Map;
	WorkVisible      = New Map;
	
	WorkTree = FormAttributeToValue("DisplayedWorkTree");
	For Each Section In WorkTree.Rows Do
		SectionsVisible.Insert(Section.ID, Section.Mark);
		For Each Work In Section.Rows Do
			WorkVisible.Insert(Work.ID, Work.Mark);
		EndDo;
	EndDo;
	
	Result = New Structure;
	Result.Insert("WorkTree", WorkTree);
	Result.Insert("SectionsVisible", SectionsVisible);
	Result.Insert("WorkVisible", WorkVisible);
	Result.Insert("CollapsedSections", CollapsedSections);
	
	CommonUse.CommonSettingsStorageSave("ToDoList", "DisplaySettings", Result);
	
	// Save settings of the update.
	AutoUpdateSettings = CommonUse.CommonSettingsStorageImport("ToDoList", "AutoUpdateSettings");
	
	If AutoUpdateSettings = Undefined Then
		AutoUpdateSettings = New Structure;
	Else
		If UseAutoupdate Then
			AutoupdateOn = AutoUpdateSettings.AutoupdateOn <> UseAutoupdate;
		Else
			AutoupdateOff = AutoUpdateSettings.AutoupdateOn <> UseAutoupdate;
		EndIf;
	EndIf;
	
	AutoUpdateSettings.Insert("AutoupdateOn", UseAutoupdate);
	AutoUpdateSettings.Insert("AutoUpdatePeriod", UpdatePeriod);
	
	CommonUse.CommonSettingsStorageSave("ToDoList", "AutoUpdateSettings", AutoUpdateSettings);
	
EndProcedure

&AtServer
Procedure SetSectionsOrder(DisplaySettings)
	
	If DisplaySettings = Undefined Then
		Return;
	EndIf;
	
	WorkTree = FormAttributeToValue("DisplayedWorkTree");
	Sections   = WorkTree.Rows;
	SavedToDosTree = DisplaySettings.WorkTree;
	For Each SectionRow In Sections Do
		SavedSection = SavedToDosTree.Rows.Find(SectionRow.ID, "ID");
		If SavedSection = Undefined Then
			Continue;
		EndIf;
		SectionRow.IndexOf = SavedSection.IndexOf;
		Works = SectionRow.Rows;
		LastToDoIndex = Works.Count() - 1;
		For Each RowToDo In Works Do
			SavedToDo = SavedSection.Rows.Find(RowToDo.ID, "ID");
			If SavedToDo = Undefined Then
				RowToDo.IndexOf = LastToDoIndex;
				LastToDoIndex = LastToDoIndex - 1;
				Continue;
			EndIf;
			RowToDo.IndexOf = SavedToDo.IndexOf;
		EndDo;
		Works.Sort("Code asc");
	EndDo;
	
	Sections.Sort("Code asc");
	ValueToFormAttribute(WorkTree, "DisplayedWorkTree");
	
EndProcedure

&AtServer
Procedure SetInitialSectionsOrder(ToDoList)
	
	CommandInterfaceSectionsOrder = New Array;
	ToDoListOverridable.AtDeterminingCommandInterfaceSectionsOrder(CommandInterfaceSectionsOrder);
	
	IndexOf = 0;
	For Each CommandInterfaceSection In CommandInterfaceSectionsOrder Do
		CommandInterfaceSection = StrReplace(CommandInterfaceSection.FullName(), ".", "");
		RowFilter = New Structure;
		RowFilter.Insert("IDOwner", CommandInterfaceSection);
		
		FoundStrings = ToDoList.FindRows(RowFilter);
		For Each FoundString In FoundStrings Do
			RowIndexInTable = ToDoList.IndexOf(FoundString);
			If RowIndexInTable = IndexOf Then
				IndexOf = IndexOf + 1;
				Continue;
			EndIf;
			
			ToDoList.Move(RowIndexInTable, (IndexOf - RowIndexInTable));
			IndexOf = IndexOf + 1;
		EndDo;
		
	EndDo;
	
EndProcedure

#EndRegion

