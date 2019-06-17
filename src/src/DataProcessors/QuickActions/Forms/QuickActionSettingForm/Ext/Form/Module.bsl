
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	NumberOfPicturesInLine = 6;
	
	If Parameters.Property("AddedQuickActions") Then
		AddedQuickActions.Clear();
		
		For Each ID In Parameters.AddedQuickActions Do
			AddedQuickActions.Add().ID = ID;
		EndDo; 
	EndIf;
	
	If Parameters.Property("AddressOfQuickActionSettings") AND IsTempStorageURL(Parameters.AddressOfQuickActionSettings) Then
		QuickActionSettings.Load(GetFromTempStorage(Parameters.AddressOfQuickActionSettings));
	EndIf;
	
	Parameters.Property("ThereBalanceInput", ThereBalanceInput);
	FillInQuickSettings();
	
	UpdateForm();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	#If WebClient Then
		
	ResertActiveItem();
		
	#EndIf
	
EndProcedure

#EndRegion 

#Region FormsItemEventHandlers

&AtClient
Procedure Attachable_QuickActionClick(Item)
	
	ItemName = StrReplace(Item.Name, "QuickAction", "");
	
	// Record changes in the quick action table
	FilterStructure = New Structure;
	FilterStructure.Insert("ID", ItemName);
	
	Rows = QuickActions.FindRows(FilterStructure);	
	If Rows.Count() = 0 Then
		Return;
	EndIf; 
	
	CurrentRow = Rows[0];
	If Not CurrentRow.Output AND NumberOfDisplayedButtons() >= 7 Then
		ShowMessageBox(, NStr("en = 'You can display not more than 7 quick action buttons simultaneously'"), 0);
		Return;
	EndIf;
	
	CurrentRow.Output = Not CurrentRow.Output; 
	
	// Change item background color
	FormGroup = Items["QuickActionGroup" + ItemName];
	If FormGroup.BackColor = New Color(255, 255, 255) Then
		FormGroup.BackColor = New Color(255, 232, 63);
	Else
		FormGroup.BackColor = New Color(255, 255, 255);
	EndIf;
	
	#If WebClient Then
		
	ResertActiveItem();
		
	#EndIf
	
EndProcedure
 
&AtClient
Procedure Attachable_QuickActionStartDragging(Item, DragParameters, Perform)
	
	ItemName = StrReplace(Item.Name, "QuickAction", "");
	DragParameters.Value = ItemName;
	
EndProcedure

&AtClient
Procedure Attachable_QuickActionCheckDragging(Item, DragParameters, StandardProcessing)
	
	NameSource = DragParameters.Value;
	NameTarget = StrReplace(Item.Name, "QuickAction", "");
	StandardProcessing = TypeOf(NameSource) <> Type("String") OR IsBlankString(NameSource) OR NameSource=NameTarget;	
	
EndProcedure

&AtClient
Procedure Attachable_QuickActionDragging(Item, DragParameters, StandardProcessing)
	
	NameSource = DragParameters.Value;
	If TypeOf(NameSource) <> Type("String") OR IsBlankString(NameSource) Then
		Return;
	EndIf; 
	
	NameTarget = StrReplace(Item.Name, "QuickAction", "");
	If NameSource = NameTarget Then
		Return;
	EndIf; 
	
	MoveItems(NameSource, NameTarget);
	
	#If WebClient Then
		
	ResertActiveItem();
		
	#EndIf
	
EndProcedure

#EndRegion 

#Region FormCommandHandlers

&AtClient
Procedure Save(Command)
	
	Result = New Structure;
	Result.Insert("Event", "QuickActionSetting");
	Result.Insert("QuickActions", New Array);
	
	For Each Str In QuickActions Do
		If Not Str.Output Then
			Continue;
		EndIf;
		
		Result.QuickActions.Add(Str.ID);
	EndDo; 
	
	NotifyChoice(Result);
	
EndProcedure

&AtClient
Procedure Cancel(Command)	
	Close();	
EndProcedure
 
#EndRegion 

#Region InternalProceduresAndFunctions

&AtServer
Procedure FillInQuickSettings()
	
	SettingsTable = QuickActionSettings.Unload();
	FillInOrder(SettingsTable);
	TableOfAdded = AddedQuickActions.Unload();
	FillInOrder(TableOfAdded);
	
	Query = New Query;
	Query.SetParameter("SettingsTable",		SettingsTable);
	Query.SetParameter("TableOfAdded",		TableOfAdded);
	Query.SetParameter("NumberOfDisplayed",	TableOfAdded.Count());
	Query.SetParameter("ThereBalanceInput",	ThereBalanceInput);
	Query.Text =
	"SELECT
	|	SettingsTable.ID,
	|	SettingsTable.Presentation,
	|	SettingsTable.PictureName,
	|	SettingsTable.Order
	|INTO SettingsTable
	|FROM
	|	&SettingsTable AS SettingsTable
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableOfAdded.ID,
	|	TableOfAdded.Order
	|INTO TableOfAdded
	|FROM
	|	&TableOfAdded AS TableOfAdded
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SettingsTable.ID,
	|	SettingsTable.Presentation,
	|	SettingsTable.PictureName,
	|	CASE
	|		WHEN TableOfAdded.ID IS NULL
	|			THEN SettingsTable.Order + &NumberOfDisplayed
	|		ELSE TableOfAdded.Order
	|	END AS Order,
	|	CASE
	|		WHEN TableOfAdded.ID IS NULL
	|			THEN FALSE
	|		ELSE TRUE
	|	END AS Output
	|FROM
	|	SettingsTable AS SettingsTable
	|		LEFT JOIN TableOfAdded AS TableOfAdded
	|		ON SettingsTable.ID = TableOfAdded.ID
	|WHERE
	|	(NOT SettingsTable.ID = ""OpeningBalanceEntry""
	|			OR NOT &ThereBalanceInput)
	|
	|ORDER BY
	|	Order";
	QuickActions.Load(Query.Execute().Unload());
	
EndProcedure

&AtServer
Procedure UpdateForm()
	
	Column = 0;
	CurrentGroup = Undefined;
	
	For Each Str In QuickActions Do
		
		Column = Column + 1;
		
		If CurrentGroup = Undefined OR Column >= NumberOfPicturesInLine Then
			
			Column						= 1;			
			CurrentGroup				= Items.Add("HorizontalGroup" + Items.GroupQuickActions.ChildItems.Count(), 
												Type("FormGroup"), 
												Items.GroupQuickActions);
			CurrentGroup.Type			= FormGroupType.UsualGroup;
			CurrentGroup.ShowTitle		= False;
			CurrentGroup.Group			= ChildFormItemsGroup.Horizontal;
			CurrentGroup.ThroughAlign	= ThroughAlign.Use;
			
		EndIf;
		
		GroupName				= "QuickActionGroup" + Str.ID;
		FormGroup				= Items.Add(GroupName, Type("FormGroup"), CurrentGroup);
		FormGroup.Type			= FormGroupType.UsualGroup;
		FormGroup.ShowTitle		= False;
		FormGroup.Group			= ChildFormItemsGroup.Vertical;
		FormGroup.ThroughAlign	= ThroughAlign.Use;
		
		If Str.Output Then
			FormGroup.BackColor = New Color(255, 232, 63);
		Else
			FormGroup.BackColor = New Color(255, 255, 255);
		EndIf; 
		
		ItemName			= "QuickAction" + Str.ID;
		Item				= Items.Add(ItemName, Type("FormDecoration"), FormGroup);
		Item.Type			= FormDecorationType.Picture;
		Item.Hyperlink		= True;
		Item.Width			= 12;
		Item.Height			= 5;
		Item.PictureSize	= PictureSize.Proportionally;
		Item.Tooltip		= Str.Presentation;
		
		If Not IsBlankString(Str.PictureName) Then
			Item.Picture = PictureLib[Str.PictureName + "Big"];
		EndIf;
		
		Item.EnableStartDrag	= True;
		Item.EnableDrag			= True;
		Item.SkipOnInput		= True;
		
		Item.SetAction("Click",		"Attachable_QuickActionClick");
		Item.SetAction("DragStart", "Attachable_QuickActionStartDragging");
		Item.SetAction("DragCheck", "Attachable_QuickActionCheckDragging");
		Item.SetAction("Drag",		"Attachable_QuickActionDragging");
		
		TitleName					= "TitleQuickAction" + Str.ID;
		ItemHeader					= Items.Add(TitleName, Type("FormDecoration"), FormGroup);
		ItemHeader.Type				= FormDecorationType.Label;
		ItemHeader.Width			= 12;
		ItemHeader.Height			= 2;
		ItemHeader.Title			= Str.Presentation;
		ItemHeader.HorizontalAlign	= ItemHorizontalLocation.Center;
		
	EndDo;
	
	// Bypass impossibility to drag the current item for web client
	FormGroup				= Items.Add("GroupCap", Type("FormGroup"), CurrentGroup);
	FormGroup.Type			= FormGroupType.UsualGroup;
	FormGroup.ShowTitle		= False;
	FormGroup.Group			= ChildFormItemsGroup.Vertical;
	FormGroup.ThroughAlign	= ThroughAlign.Use;
	
	Item				= Items.Add("Stub", Type("FormDecoration"), FormGroup);
	Item.Type			= FormDecorationType.Picture;
	Item.Hyperlink		= True;
	Item.Width			= 12;
	Item.Height			= 5;
	Item.PictureSize	= PictureSize.Proportionally;
	Item.Tooltip		= " ";
	
	ItemHeader					= Items.Add("CapTitle", Type("FormDecoration"), FormGroup);
	ItemHeader.Type				= FormDecorationType.Label;
	ItemHeader.Width			= 12;
	ItemHeader.Title			= " ";
	ItemHeader.HorizontalAlign	= ItemHorizontalLocation.Center;
	
EndProcedure

&AtServerNoContext
Procedure FillInOrder(Table)
	
	Table.Columns.Add("Order", New TypeDescription("Number", New NumberQualifiers(10, 0)));
	
	s = 0;
	For Each Str In Table Do
		Str.Order = s;
		s = s + 1;
	EndDo;
	
EndProcedure

&AtServer
Procedure MoveItems(NameSource, NameTarget)
	
	SourceGroup = Items["QuickActionGroup"+NameSource];
	TargetGroup = Items["QuickActionGroup"+NameTarget];
	
	MoveLeft			= False;
	MoveRight			= False;
	TargetGroupMoved	= False;
	FirstItemMoved		= False;
	Column				= 0;
	Row					= 0;
	
	For Each Str In QuickActions Do
		
		Column = Column + 1;
		If Row = 0 OR Column >= NumberOfPicturesInLine + ?(MoveRight, 1, 0) Then
			Column			= 1;
			Row				= Row + 1;
			HorizontalGroup = Items.GroupQuickActions.ChildItems.Get(Row - 1);
		EndIf;
		
		CurrentGroup = HorizontalGroup.ChildItems.Get(Column - 1 - ?(MoveLeft AND Column > 1 AND FirstItemMoved, 1, 0));
		If CurrentGroup = SourceGroup AND Not MoveRight Then
			MoveLeft		= True;
			FirstItemMoved	= False;
		ElsIf CurrentGroup = SourceGroup AND MoveRight Then
			MoveRight = False;
		ElsIf CurrentGroup = TargetGroup AND Not MoveLeft Then
			MoveRight = True;
		ElsIf CurrentGroup = TargetGroup AND MoveLeft Then
			
			MoveLeft = False;
			FirstItemMoved = False;
			
			If Column = 1 Then
				TargetGroupMoved = True;
			EndIf; 
			
		EndIf;
		
		If MoveLeft AND Column = 1 AND Row > 1 Then
			// When moving items to the left, you transfer the first item of each line to the previous group
			OffsetGroup = Items.GroupQuickActions.ChildItems.Get(Row - 2);
			Items.Move(CurrentGroup, OffsetGroup);
			FirstItemMoved = True;
		EndIf; 
		
		If MoveRight AND Column = HorizontalGroup.ChildItems.Count() Then
			// When moving items to the right, you transfer the last item of each line to the next group
			OffsetGroup = Items.GroupQuickActions.ChildItems.Get(Row);
			
			Items.Move(CurrentGroup, OffsetGroup, OffsetGroup.ChildItems.Get(0));
			
			If CurrentGroup = TargetGroup Then
				TargetGroupMoved = True;
			EndIf; 
			
		EndIf; 
	EndDo;
	
	If TargetGroupMoved Then
		// You have moved the target item, transfer to the previous group
		Items.Move(SourceGroup, Items.GroupQuickActions.ChildItems.Get(Items.GroupQuickActions.ChildItems.IndexOf(TargetGroup.Parent) - 1));
	Else
		Items.Move(SourceGroup, TargetGroup.Parent, TargetGroup);
	EndIf;
	
	// Record changes in the quick action table
	FilterStructure = New Structure;
	FilterStructure.Insert("ID", NameSource);
	
	LinesSource = QuickActions.FindRows(FilterStructure);
	FilterStructure.Insert("ID", NameTarget);
	
	LinesTarger = QuickActions.FindRows(FilterStructure);
	If LinesSource.Count() > 0 AND LinesTarger.Count() > 0 Then
		
		IndexSource = QuickActions.IndexOf(LinesSource[0]);
		IndexTarget = QuickActions.IndexOf(LinesTarger[0]);
		QuickActions.Move(IndexSource, IndexTarget-IndexSource);
		
	EndIf; 
	
EndProcedure

&AtClient
Function NumberOfDisplayedButtons()
	
	FilterStructure = New Structure;
	FilterStructure.Insert("Output", True);
	
	Return QuickActions.FindRows(FilterStructure).Count();
	
EndFunction

&AtClient
Procedure ResertActiveItem()	
	CurrentItem = Items["Stub"];	
EndProcedure
 
#EndRegion
 