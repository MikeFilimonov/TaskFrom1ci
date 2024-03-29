﻿#Region Variables

&AtClient
Var HandlerParameters;

#EndRegion

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	SetConditionalAppearance();
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	If Not Users.InfobaseUserWithFullAccess() Then
		ErrorText = NStr("en = 'Insufficient rights to perform the operation.'");
		Return; // Denial is set in OnOpen.
	EndIf;
	
	If CommonUseReUse.DataSeparationEnabled()
		AND Not CommonUse.UseSessionSeparator() Then
		ErrorText = NStr("en = 'To delete marked items, enter data area.'");
		Return; // Denial is set in OnOpen.
	EndIf;
	
	If Not CommonUse.SubsystemExists("StandardSubsystems.SearchAndDeleteDuplicates") Then
		Items.NotRemovedChangeTo.Visible = False;
		Items.NotRemovedChangeToFromMenu.Visible = False;
	EndIf;
	
	DeletionMode = "Full";
	OnCreateAtServerSetExplanationTextForProcessing();
	VisibleEnabled(ThisObject);
EndProcedure

&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	VisibleEnabled(ThisObject);
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	If ValueIsFilled(ErrorText) Then
		ShowMessageBox(, ErrorText);
		Cancel = True;
	EndIf;
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	If Items.FormPages.CurrentPage = Items.PageLongOperation Then
		
		Cancel = True;
		
		If Exit Then
			Return;
		EndIf;
		
		DetachIdleHandler("BackgroundJobCheckAtClient");
		
		Handler = New NotifyDescription("BeforeCloseAnswerOnQuestion", ThisObject);
		QuestionText = NStr("en = 'The marked ones are still being deleted.
		                    |Do you want to abort?'");
		
		Buttons = New ValueList;
		Buttons.Add(DialogReturnCode.Abort);
		Buttons.Add(DialogReturnCode.Ignore, NStr("en = 'Do not interrupt'"));
		
		ShowQueryBox(Handler, QuestionText, Buttons, 60, DialogReturnCode.Ignore);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeCloseAnswerOnQuestion(Response, ExecuteParameters) Export
	If Response = DialogReturnCode.Abort Then
		Items.FormPages.CurrentPage = Items.PageDeleteModeSelection; // To skip the question.
		Close(); // The background job is canceled in the OnClosing() handler.
	Else
		BackgroundJobCheckAtClient();
	EndIf;
EndProcedure

&AtClient
Procedure OnClose(Exit)
	
	If Exit Then
		Return;
	EndIf;
	
	If BackgroundJobID <> Undefined Then
		BackgroundJobCancel(BackgroundJobID, Exclusive);
		BackgroundJobID = Undefined;
	EndIf;
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure DeletionModeOnChange(Item)
	VisibleEnabled(ThisObject);
EndProcedure

&AtClient
Procedure ExplanationToDataProcessorNavigationLinkDataProcessor(Item, Ref, StandardProcessing)
	StandardProcessing = False;
	FormParameters = New Structure("FilterApplicationName", "1CV8,1CV8C,WebClient");
	StandardSubsystemsClient.OpenActiveUsersList(FormParameters);
EndProcedure

#EndRegion

#Region FormTableItemEventHandlersMarkedForDeletionTree

&AtClient
Procedure MarkedToRemoveTreeMarkOnChange(Item)
	CurrentData = Items.MarkedToRemoveTree.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	MarkedForDeletionTreeRecoverMarkInList(CurrentData, CurrentData.Check, True);
EndProcedure

&AtClient
Procedure MarkedToRemoveTreeSelection(Item, SelectedRow, Field, StandardProcessing)
	StandardProcessing = False;
	ShowTableObject(Item);
EndProcedure

#EndRegion

#Region FormTableItemEventHandlersNotRemoved

&AtClient
Procedure NotRemovedOnActivateRow(Item)
	AttachIdleHandler("ShowConnectionsNotRemovedOnClient", 0.1, True);
EndProcedure

&AtClient
Procedure NotRemovedBeforeStartChange(Item, Cancel)
	Cancel = True;
	ShowTableObject(Item);
EndProcedure

&AtClient
Procedure NotRemovedBeforeRemoving(Item, Cancel)
	Cancel = True;
	MarkSelectedTableObjectsForDeletion(Item);
EndProcedure

&AtClient
Procedure NotRemovedSelection(Item, SelectedRow, Field, StandardProcessing)
	StandardProcessing = False;
	ShowTableObject(Item);
EndProcedure

&AtClient
Procedure NotRemovedPresentationOpen(Item, StandardProcessing)
	StandardProcessing = False;
	ShowTableObject(Item);
EndProcedure

#EndRegion

#Region FormTableItemEventHandlersNotRemovedConnections

&AtClient
Procedure ConnectionsNotRemovedBeforeStartChange(Item, Cancel)
	Cancel = True;
	ShowTableObject(Item);
EndProcedure

&AtClient
Procedure ConnectionsNotRemovedBeforeRemoval(Item, Cancel)
	Cancel = True;
	MarkSelectedTableObjectsForDeletion(Item);
EndProcedure

&AtClient
Procedure ConnectionsNotRemovedSelection(Item, SelectedRow, Field, StandardProcessing)
	StandardProcessing = False;
	ShowTableObject(Item);
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure CommandNext(Command)
	BackgroundJobStartOnClient(1);
EndProcedure

&AtClient
Procedure CommandBack(Command)
	Items.FormPages.CurrentPage = Items.PageDeleteModeSelection;
	VisibleEnabled(ThisObject);
EndProcedure

&AtClient
Procedure MarkedToRemoveTreeMarkAll(Command)
	
	ListItems = MarkedToRemoveTree.GetItems();
	For Each Item In ListItems Do
		MarkedForDeletionTreeRecoverMarkInList(Item, True, True);
		Parent = Item.GetParent();
		If Parent = Undefined Then
			MarkToDeleteTree(Item)
		EndIf;
	EndDo;
	
EndProcedure

&AtClient
Procedure MarkedToRemoveTreeUncheckAll(Command)
	
	ListItems = MarkedToRemoveTree.GetItems();
	For Each Item In ListItems Do
		MarkedForDeletionTreeRecoverMarkInList(Item, False, True);
		Parent = Item.GetParent();
		If Parent = Undefined Then
			MarkToDeleteTree(Item)
		EndIf;
	EndDo;
	
EndProcedure

&AtClient
Procedure MarkedToRemoveTreeChange(Command)
	ShowTableObject(Items.MarkedToRemoveTree);
EndProcedure

&AtClient
Procedure MarkedToRemoveTreeRefresh(Command)
	BackgroundJobStartOnClient(2);
EndProcedure

&AtClient
Procedure NotRemovedChangeTo(Command)
	ArrayOfIDs = Items.NotRemoved.SelectedRows;
	If ArrayOfIDs.Count() = 0 Then
		Return;
	EndIf;
	
	RefArray = New Array;
	For Each ID In ArrayOfIDs Do
		TableRow = NotRemoved.FindByID(ID);
		If TypeOf(TableRow.RemovedRefs) = Type("String") Then
			Continue; // Skip groups.
		EndIf;
		RefArray.Add(TableRow.RemovedRefs);
	EndDo;
	
	If RefArray.Count() = 0 Then
		ShowMessageBox(, NStr("en = 'Select objects'"));
		Return;
	EndIf;
	
	// The subsystem will be checked in OnCreateAtServer.
	SearchAndDeleteDuplicatesModuleClient = CommonUseClient.CommonModule("SearchAndDeleteDuplicatesClient");
	SearchAndDeleteDuplicatesModuleClient.ReplaceSelected(RefArray);
EndProcedure

&AtClient
Procedure NotRemovedRemove(Command)
	MarkSelectedTableObjectsForDeletion(Items.NotRemoved);
EndProcedure

&AtClient
Procedure ConnectionsNotRemovedRemove(Command)
	MarkSelectedTableObjectsForDeletion(Items.ConnectionsNotRemoved);
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure SetConditionalAppearance()
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ConnectionsNotRemoved.Name);
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.NotRemovingReasonsPresentation.Name);
	
	FilterElement = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("NotRemovedConnections.Visible");
	FilterElement.ComparisonType = DataCompositionComparisonType.Equal;
	FilterElement.RightValue = False;
	
	Item.Appearance.SetParameterValue("Visible", False);
	Item.Appearance.SetParameterValue("Show", False);
EndProcedure

#Region Client

&AtClient
Procedure BackgroundJobCheckAtClient()
	Result = BackgroundJobGetResult();
	If Result.BackGroundJobFinished Then
		StandardSubsystemsClient.ShowExecutionResult(ThisObject, Result);
		If Result.Property("CollapseTreeNodes") Then
			CollapseTreeNodes = Result.CollapseTreeNodes;
			If CollapseTreeNodes.Use Then
				Items[CollapseTreeNodes.Name].Expand(CollapseTreeNodes.ID, CollapseTreeNodes.WithSubordinate);
			EndIf;
		EndIf;
	Else
		LongActionsClient.UpdateIdleHandlerParameters(HandlerParameters);
		AttachIdleHandler("BackgroundJobCheckAtClient", HandlerParameters.CurrentInterval, True);
	EndIf;
EndProcedure

&AtClient
Procedure BackgroundJobStartOnClient(Action)
	JobParameters = New Structure;
	JobParameters.Insert("SearchMarked", False);
	JobParameters.Insert("DeleteMarked", False);
	JobParameters.Insert("ReadMarkedWithResultsPage", False);
	JobParameters.Insert("ReadMarkedFromCheckBoxesSelectionPage", False);
	
	If Action = 1 Then
		CurrentPage = Items.FormPages.CurrentPage;
		If CurrentPage = Items.PageDeleteModeSelection Then
			If DeletionMode = "Full" Then
				JobParameters.SearchMarked = True;
				JobParameters.DeleteMarked = True;
			Else
				JobParameters.SearchMarked = True;
			EndIf;
		ElsIf CurrentPage = Items.PageMarkedToRemove Then
			JobParameters.ReadMarkedFromCheckBoxesSelectionPage = True;
			JobParameters.DeleteMarked = True;
		ElsIf CurrentPage = Items.PageReasonsRemovingUnavailable Then
			JobParameters.ReadMarkedWithResultsPage = True;
			JobParameters.DeleteMarked = True;
		EndIf;
	ElsIf Action = 2 Then
		JobParameters.SearchMarked = True;
		JobParameters.ReadMarkedFromCheckBoxesSelectionPage = True;
	EndIf;
	
	Text = NStr("en = 'Deleting the objects marked for deletion...'");
	If JobParameters.SearchMarked AND JobParameters.DeleteMarked Then
		Status(NStr("en = 'Search and deletion of marked objects...'"));
	ElsIf JobParameters.SearchMarked Then
		Text = NStr("en = 'Search for objects marked for deletion...'");
		Status(Text);
	Else
		Status(NStr("en = 'Deleting the selected objects...'"));
	EndIf;
	Items.LabelLongAction.Title = Text;
	
	Result = BackGroundJobStart(JobParameters);
	If Result.BackgroundJobStarted Then
		LongActionsClient.InitIdleHandlerParameters(HandlerParameters);
		AttachIdleHandler("BackgroundJobCheckAtClient", 1, True);
		HandlerParameters.MaxInterval = 5;
	ElsIf Result.ErrorWhenInstallingExclusiveMode Then
		If CommonUseClient.SubsystemExists("StandardSubsystems.UserSessions") Then
			Notification = New NotifyDescription("BackgroundJobStartAfterSettingExclusiveMode", ThisObject, Action);
			FormParameters = New Structure;
			FormParameters.Insert("DeleteMarkedObjects", True);
			DBModuleConnectionsClient = CommonUseClient.CommonModule("InfobaseConnectionsClient");
			DBModuleConnectionsClient.OnOpenFormsErrorInstallationExclusiveMode(Notification, FormParameters);
		Else
			StandardSubsystemsClientServer.DisplayWarning(
				Result,
				NStr("en = 'Cannot start deletion of the marked objects'"),
				Result.ExclusiveModeSettingErrorText);
		EndIf;
	EndIf;
	StandardSubsystemsClient.ShowExecutionResult(ThisObject, Result);
EndProcedure

&AtClient
Procedure ShowConnectionsNotRemovedOnClient()
	TreeRow = Items.NotRemoved.CurrentData;
	If TreeRow = Undefined Or TreeRow.PictureNumber < 1 Then
		// Nothing is selected or a group is selected.
		CurrentPage = Items.PageSelectNotRemovedObject;
		NotRemovedToolTip = " ";
		ErrorText = NStr("en = 'Select the object to
		                 |determine the reason why it failed to be deleted.'");
	Else
		// Ref to the object that is not deleted is selected.
		Hidden = ConnectionsNotRemoved.FindRows(New Structure("Visible", True));
		For Each TableRow In Hidden Do
			TableRow.Visible = False;
		EndDo;
		
		ErrorText = "";
		ShowErrorText = True;
		Displayed = ConnectionsNotRemoved.FindRows(New Structure("RemovedRefs", TreeRow.RemovedRefs));
		For Each TableRow In Displayed Do
			TableRow.Visible = True;
			If TableRow.IsError Then
				ErrorText = TableRow.FoundReference;
			Else
				If ShowErrorText Then
					Items.ConnectionsNotRemoved.CurrentRow = TableRow.GetID();
					ShowErrorText = False;
				EndIf;
			EndIf;
		EndDo;
		
		If ShowErrorText Then
			CurrentPage = Items.PageErrorText;
			NotRemovedToolTip = " ";
		Else
			CurrentPage = Items.ReasonNotRemovedPage;
			NotRemovedToolTip = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Usage locations of object ""%1"" (%2):'"),
				TreeRow.Presentation,
				Format(TreeRow.ConnectionsCount, "NZ=0; NG=")
			);
		EndIf;
	EndIf;
	If Items.ReasonsDisplayVariantsPages.CurrentPage <> CurrentPage Then
		Items.ReasonsDisplayVariantsPages.CurrentPage = CurrentPage;
	EndIf;
EndProcedure

&AtClient
Procedure ShowTableObject(ItemTable)
	TableRow = ItemTable.CurrentData;
	If TableRow = Undefined Then
		Return;
	EndIf;
	
	Value = Undefined;
	If Not TableRow.Property("Value", Value)
		AND Not TableRow.Property("FoundReference", Value)
		AND Not TableRow.Property("RemovedRefs", Value) Then
		Return;
	EndIf;
	
	If TypeOf(Value) = Type("String") Then
		If TableRow.Property("ThisIsConstant") AND TableRow.ThisIsConstant Then
			PathToForm = Value + ".ConstantsForm";
		Else
			PathToForm = Value + ".ListForm";
		EndIf;
		OpenForm(PathToForm);
	ElsIf TypeOf(Value) = Type("ValueList") Then
		ValueDescription = Value.Get(0);
		FormParameters = New Structure;
		FormParameters.Insert("Key", ValueDescription.Value);
		OpenForm(ValueDescription.Presentation + ".RecordForm", FormParameters, ThisObject);
	Else
		ShowValue(, Value);
	EndIf;
EndProcedure

&AtClient
Procedure MarkSelectedTableObjectsForDeletion(ItemTable)
	Var Value;
	
	ArrayOfIDs = ItemTable.SelectedRows;
	QuantitySelected = ArrayOfIDs.Count();
	If QuantitySelected = 0 Then
		Return;
	EndIf;
	
	TableName = ItemTable.Name;
	If TableName = "MarkedToRemoveTree" Then
		AttributeNameValue = "Value";
		IsNotRemovedConnection = False;
	ElsIf TableName = "NotRemoved" Then
		AttributeNameValue = "RemovedRefs";
		IsNotRemovedConnection = False;
	ElsIf TableName = "ConnectionsNotRemoved" Then
		AttributeNameValue = "FoundReference";
		IsNotRemovedConnection = True;
	EndIf;
	
	TableAttribute = ThisObject[TableName];
	TableRowsArray = New Array;
	RefsMarkedForDeletionArray = New Array;
	RefsNotMarkedForDeletionArray = New Array;
	HasMarkedForDeletion = False;
	HasRegisterRecords = False;
	HasConstants = False;
	For Each ID In ArrayOfIDs Do
		TableRow = TableAttribute.FindByID(ID);
		If IsNotRemovedConnection Then
			If TableRow.ThisIsConstant Then
				HasConstants = True;
				Continue;
			ElsIf Not TableRow.LinkingType Then
				HasRegisterRecords = True;
				Continue;
			EndIf;
		EndIf;
		TableRow.Property(AttributeNameValue, Value);
		If TypeOf(Value) = Type("String") Then
			QuantitySelected = QuantitySelected - 1; // The groups should not be considered selected.
			Continue; // Skip groups.
		EndIf;
		If TableRow.DeletionMark Then
			HasMarkedForDeletion = True;
			RefsMarkedForDeletionArray.Add(Value);
		Else
			RefsNotMarkedForDeletionArray.Add(Value);
		EndIf;
		If TypeOf(TableAttribute) = Type("FormDataCollection") Then
			Found = TableAttribute.FindRows(New Structure(AttributeNameValue, Value));
			For Each RowOnLink In Found Do
				TableRowsArray.Add(RowOnLink);
			EndDo;
		Else
			TableRowsArray.Add(TableRow);
		EndIf;
	EndDo;
	
	RefArray = ?(HasMarkedForDeletion, RefsMarkedForDeletionArray, RefsNotMarkedForDeletionArray);
	QuantityCanBeDeleted = RefArray.Count();
	If QuantityCanBeDeleted = 0 Then
		ErrorText = NStr("en = 'Select object.'");
		If QuantitySelected = 1 Then
			If HasRegisterRecords Then
				ErrorText = NStr("en = 'Register records are deleted from their cards.'");
			ElsIf HasConstants Then
				ErrorText = NStr("en = 'Constant value is cleaned up from its card.'");
			EndIf;
		Else
			If HasRegisterRecords Or HasConstants Then
				ErrorText = NStr("en = 'Register record deletion or constant value cleanup is carried out from their cards.'");
			EndIf;
		EndIf;
		ShowMessageBox(, ErrorText);
		Return;
	EndIf;
	
	HandlerParameters = New Structure;
	HandlerParameters.Insert("TableName", TableName);
	HandlerParameters.Insert("TableRowsArray", TableRowsArray);
	HandlerParameters.Insert("RefArray", RefArray);
	HandlerParameters.Insert("AttributeNameValue", AttributeNameValue);
	HandlerParameters.Insert("HasMarkedForDeletion", HasMarkedForDeletion);
	
	Handler = New NotifyDescription("MarkSelectedTableObjectsForDeletionEnd", ThisObject, HandlerParameters);
	
	If QuantityCanBeDeleted = 1 Then
		If HasMarkedForDeletion Then
			QuestionText = NStr("en = 'Clear mark for deletion for ""%1""?'");
		Else
			QuestionText = NStr("en = 'Mark ""%1"" for deletion?'");
		EndIf;
		QuestionText = StrReplace(QuestionText, "%1", TableRowsArray[0].Presentation);
	Else
		If HasMarkedForDeletion Then
			QuestionText = NStr("en = 'Clear marks for deletion for the selected objects (%1)?'");
		Else
			QuestionText = NStr("en = 'Mark the selected objects (%1) for deletion?'");
		EndIf;
		QuestionText = StrReplace(QuestionText, "%1", Format(QuantityCanBeDeleted, "NZ=0; NG="));
	EndIf;
	
	Buttons = New ValueList;
	Buttons.Add(DialogReturnCode.Yes);
	Buttons.Add(DialogReturnCode.No);
	
	ShowQueryBox(Handler, QuestionText, Buttons, 60, DialogReturnCode.No);
EndProcedure

&AtClient
Procedure MarkSelectedTableObjectsForDeletionEnd(Response, ExecuteParameters) Export
	If Response <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	DeletionMark = Not ExecuteParameters.HasMarkedForDeletion;
	ServerWorkResult = ChangeObjectsDeletionMark(ExecuteParameters.RefArray, DeletionMark);
	StandardSubsystemsClient.ShowExecutionResult(ThisObject, ServerWorkResult);
EndProcedure

&AtClient
Procedure MarkedForDeletionTreeRecoverMarkInList(Data, Check, CheckParent)
	
	// Set as a subordinate
	RowItems = Data.GetItems();
	
	For Each Item In RowItems Do
		Item.Check = Check;
		MarkedForDeletionTreeRecoverMarkInList(Item, Check, False);
	EndDo;
	
	// Check the parent
	Parent = Data.GetParent();
	
	If CheckParent AND Parent <> Undefined Then 
		MarkToDeleteTree(Parent);
	EndIf;
	
EndProcedure

&AtClient
Procedure MarkToDeleteTree(Parent)
	
	ParentMark = True;
	RowItems = Parent.GetItems();
	For Each Item In RowItems Do
		If Not Item.Check Then
			ParentMark = False;
			Break;
		EndIf;
	EndDo;
	Parent.Check = ParentMark;
	
EndProcedure

&AtClientAtServerNoContext
Procedure VisibleEnabled(Form)
	Items = Form.Items;
	CurrentPage = Items.FormPages.CurrentPage;
	
	Items.ButtonNext.Title = NStr("en = 'Delete'");
	Items.CloseButton.Title = NStr("en = 'Close'");
	Items.ButtonBack.Title = NStr("en = '< Go home'");
	
	If CurrentPage = Items.PageDeleteModeSelection Then
		Items.ButtonBack.Visible = False;
		Items.ButtonNext.Visible = True;
		If Form.DeletionMode <> "Full" Then
			Items.ButtonNext.Title = NStr("en = 'Next >'");
		EndIf;
		Items.ButtonNext.DefaultButton = True;
		Items.CloseButton.Title = NStr("en = 'Cancel'");
	ElsIf CurrentPage = Items.PageMarkedToRemove Then
		Items.ButtonBack.Visible = True;
		Items.ButtonBack.Title = NStr("en = '< Back'");
		Items.ButtonNext.Visible = True;
		Items.ButtonNext.Title = NStr("en = 'Delete'");
		Items.ButtonNext.DefaultButton = True;
	ElsIf CurrentPage = Items.PageLongOperation Then
		Items.ButtonBack.Visible = False;
		Items.ButtonNext.Visible = False;
		Items.CloseButton.Title = NStr("en = 'Stop and close'");
	ElsIf CurrentPage = Items.PageReasonsRemovingUnavailable Then
		Items.ButtonBack.Visible = True;
		Items.ButtonNext.Visible = True;
		Items.ButtonNext.Title = NStr("en = 'Repeat deletion'");
		Items.ButtonNext.DefaultButton = True;
	ElsIf CurrentPage = Items.PageDeleteNotRequired Then
		Items.ButtonBack.Visible = True;
		Items.ButtonNext.Visible = False;
		Items.CloseButton.DefaultButton = True;
	ElsIf CurrentPage = Items.PageSuccessfullyCompleted Then
		Items.ButtonBack.Visible = True;
		Items.ButtonNext.Visible = False;
		Items.CloseButton.DefaultButton = True;
	EndIf;
	
	If CommonUseClientServer.ThisIsWebClient() Then
		If CurrentPage = Items.PageReasonsRemovingUnavailable Then
			Items.PageReasonsRemovingUnavailable.Visible = True;
		Else
			Items.PageReasonsRemovingUnavailable.Visible = False;
		EndIf;
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Function PictureNumber(RefOrData, LinkingType, Kind, DeletionMark)
	If LinkingType Then
		If Kind = "CATALOG"
			Or Kind = "CHARTOFCHARACTERISTICTYPES" Then
			PictureNumber = 3;
		ElsIf Kind = "DOCUMENT" Then
			PictureNumber = 12;
		ElsIf Kind = "CHARTOFACCOUNTS" Then
			PictureNumber = 15;
		ElsIf Kind = "CHARTOFCALCULATIONTYPES" Then
			PictureNumber = 17;
		ElsIf Kind = "BUSINESSPROCESS" Then
			PictureNumber = 19;
		ElsIf Kind = "TASK" Then
			PictureNumber = 21;
		ElsIf Kind = "EXCHANGEPLAN" Then
			PictureNumber = 23;
		Else
			PictureNumber = -2;
		EndIf;
		If DeletionMark Then
			PictureNumber = PictureNumber + 1;
		EndIf;
	Else
		If Kind = "CONSTANT" Then
			PictureNumber = 25;
		ElsIf Kind = "INFORMATIONREGISTER" Then
			PictureNumber = 26;
		ElsIf Kind = "ACCUMULATIONREGISTER" Then
			PictureNumber = 28;
		ElsIf Kind = "ACCOUNTINGREGISTER" Then
			PictureNumber = 34;
		ElsIf Kind = "CALCULATIONREGISTER" Then
			PictureNumber = 38;
		ElsIf RefOrData = Undefined Then
			PictureNumber = 11;
		Else
			PictureNumber = 8;
		EndIf;
	EndIf;
	
	Return PictureNumber;
EndFunction

#EndRegion

#Region ServerCallServer

&AtServer
Function MarkToDeleteFromResultsPage()
	Result = New Array;
	
	ValueTree = FormAttributeToValue("NotRemoved");
	Found = ValueTree.Rows.FindRows(New Structure("DeletionMark", True), True);
	For Each TreeRow In Found Do
		If TypeOf(TreeRow.RemovedRefs) <> Type("String")
			AND Result.Find(TreeRow.RemovedRefs) = Undefined Then
			Result.Add(TreeRow.RemovedRefs);
		EndIf;
	EndDo;
	
	ValueTable = FormAttributeToValue("ConnectionsNotRemoved");
	Found = ValueTable.FindRows(New Structure("DeletionMark", True));
	For Each TreeRow In Found Do
		If TypeOf(TreeRow.FoundReference) <> Type("String")
			AND Result.Find(TreeRow.FoundReference) = Undefined Then
			Result.Add(TreeRow.FoundReference);
		EndIf;
	EndDo;
	
	Return Result;
EndFunction

&AtServer
Function MarkToDeleteFromCheckBoxesSelectingPage()
	Result = New Array;
	
	ValueTree = FormAttributeToValue("MarkedToRemoveTree");
	Found = ValueTree.Rows.FindRows(New Structure("Check", True), True);
	For Each TreeRow In Found Do
		If TypeOf(TreeRow.Value) <> Type("String") Then
			Result.Add(TreeRow.Value);
		EndIf;
	EndDo;
	
	Return Result;
EndFunction

&AtServer
Function BackgroundJobGetResult()
	Result = New Structure;
	Result.Insert("BackGroundJobFinished", False);
	Result.BackGroundJobFinished = LongActions.JobCompleted(BackgroundJobID);
	If Result.BackGroundJobFinished Then
		StandardSubsystemsClientServer.NewExecutionResult(Result);
		BackgroundJobImportResult(Result);
	Else
		BackgroundJobReadInterimResult(Result);
	EndIf;
	Return Result;
EndFunction

&AtServer
Function BackGroundJobStart(Val JobParameters)
	Result = StandardSubsystemsClientServer.NewExecutionResult();
	Result.Insert("BackgroundJobStarted", False);
	Result.Insert("ErrorWhenInstallingExclusiveMode", False);
	Result.Insert("ExclusiveModeSettingErrorText", Undefined);
	
	If JobParameters.DeleteMarked AND Exclusive Then
		ErrorInfo = Undefined;
		Try
			CommonUse.LockInfobase();
		Except
			ErrorInfo = ErrorInfo();
		EndTry;
		If ErrorInfo <> Undefined Then
			Result.ErrorWhenInstallingExclusiveMode   = True;
			Result.ExclusiveModeSettingErrorText = DetailErrorDescription(ErrorInfo);
			Return False;
		EndIf;
	EndIf;
	
	// Background job launch
	If Not JobParameters.SearchMarked Then
		If JobParameters.ReadMarkedWithResultsPage Then
			CustomObjects = MarkToDeleteFromResultsPage();
		ElsIf JobParameters.ReadMarkedFromCheckBoxesSelectionPage Then
			CustomObjects = MarkToDeleteFromCheckBoxesSelectingPage();
		EndIf;
		If CustomObjects.Count() = 0 Then
			Items.FormPages.CurrentPage = Items.PageDeleteNotRequired;
			VisibleEnabled(ThisObject);
			Return Result;
		EndIf;
		JobParameters.Insert("CustomObjects", CustomObjects);
	EndIf;
	
	JobParameters.Insert("RecordPeriod", 1); // Seconds
	JobParameters.Insert("Exclusive", Exclusive);
	
	BackgroundJobResult = LongActions.ExecuteInBackground(
		UUID,
		"DataProcessors.DeleteMarkedObjects.DeletionMarkedObjectsInteractively",
		JobParameters,
		NStr("en = 'Deletion of marked objects (interactive)'"));
	
	BackgroundJobID  = BackgroundJobResult.JobID;
	BackgroundJobStorageAddress = BackgroundJobResult.StorageAddress;
	
	If BackgroundJobResult.JobCompleted Then
		BackgroundJobImportResult(Result);
		Result.BackgroundJobStarted = False;
	Else
		BackgroundJobShowLongOperationPage(JobParameters);
		BackgroundJobReadInterimResult(Result);
		Result.BackgroundJobStarted = True;
	EndIf;
	VisibleEnabled(ThisObject);
	
	Return Result;
EndFunction

&AtServerNoContext
Procedure BackgroundJobCancel(Val BackgroundJobID, Val Exclusive)
	LongActions.CancelJobExecution(BackgroundJobID);
	If Exclusive Then
		SwitchOffSoleMode();
	EndIf;
EndProcedure

&AtServer
Function ChangeObjectsDeletionMark(RefArray, DeletionMark)
	Result = New Structure;
	Quantity = RefArray.Count();
	For Number = 1 To Quantity Do
		ReverseIndex = Quantity - Number;
		AMutableObject = RefArray[ReverseIndex].GetObject();
		If AMutableObject = Undefined Then
			RefArray.Delete(ReverseIndex);
		Else
			AMutableObject.SetDeletionMark(DeletionMark);
		EndIf;
	EndDo;
	
	ObjectCount = RefArray.Count();
	
	If ObjectCount > 0 Then
		ValueTree = FormAttributeToValue("NotRemoved");
		ValueTable = FormAttributeToValue("ConnectionsNotRemoved");
		
		For Each Ref In RefArray Do
			Found = ValueTree.Rows.FindRows(New Structure("RemovedRefs", Ref), True);
			For Each TreeRow In Found Do
				If TreeRow.DeletionMark = DeletionMark Then
					Continue;
				EndIf;
				TreeRow.DeletionMark = DeletionMark;
				TreeRow.PictureNumber   = TreeRow.PictureNumber + ?(DeletionMark, 1, -1);
			EndDo;
			
			Found = ValueTable.FindRows(New Structure("FoundReference", Ref));
			For Each TableRow In Found Do
				If TableRow.DeletionMark = DeletionMark Then
					Continue;
				EndIf;
				TableRow.DeletionMark = DeletionMark;
				TableRow.PictureNumber   = TableRow.PictureNumber + ?(DeletionMark, 1, -1);
			EndDo;
		EndDo;
		
		ImportCollection("NotRemoved", ValueTree, "RemovedRefs");
		ImportCollection("ConnectionsNotRemoved", ValueTable, "RemovedRefs, FoundReference");
		StandardSubsystemsClientServer.CollapseTreeNodes(Result, "NotRemoved", "*", True);
	EndIf;
	
	StandardSubsystemsClientServer.NotifyDynamicLists(Result, RefArray);
	
	NotificationText = Undefined;
	NotificationRef = Undefined;
	If ObjectCount = 0 Then
		NotificationTitle = NStr("en = 'Object is not found'");
	Else
		If DeletionMark Then
			NotificationTitle = NStr("en = 'Deletion mark is selected'");
		Else
			NotificationTitle = NStr("en = 'Deletion mark is cleared'");
		EndIf;
		If ObjectCount = 1 Then
			NotificationRef = RefArray[0];
			NotificationText  = String(NotificationRef);
		Else
			NotificationTitle = NotificationTitle + " (" + Format(ObjectCount, "NZ=0; NG=") + ")";
		EndIf;
	EndIf;
	StandardSubsystemsClientServer.DisplayNotification(Result, NotificationTitle, NotificationText, , NotificationRef);
	
	Return Result;
EndFunction

&AtServer
Procedure ImportCollection(TableName, TableData, KeyColumns)
	SelectedRows = RememberSelectedRows(TableName, KeyColumns);
	ValueToFormAttribute(TableData, TableName);
	RecallSelectedRows(TableName, SelectedRows);
EndProcedure

&AtServer
Function RememberSelectedRows(TableName, KeyColumns)
	TableAttribute = ThisObject[TableName];
	ItemTable = Items[TableName];
	
	Result = New Structure;
	Result.Insert("Selected", New Array);
	Result.Insert("Current", Undefined);
	
	CurrentIdentifier = ItemTable.CurrentRow;
	If CurrentIdentifier <> Undefined Then
		TableRow = TableAttribute.FindByID(CurrentIdentifier);
		If TableRow <> Undefined Then
			RowData = New Structure(KeyColumns);
			FillPropertyValues(RowData, TableRow);
			Result.Current = RowData;
		EndIf;
	EndIf;
	
	SelectedRows = ItemTable.SelectedRows;
	If SelectedRows <> Undefined Then
		For Each SelectedIdentifier In SelectedRows Do
			If SelectedIdentifier = CurrentIdentifier Then
				Continue;
			EndIf;
			TableRow = TableAttribute.FindByID(SelectedIdentifier);
			If TableRow <> Undefined Then
				RowData = New Structure(KeyColumns);
				FillPropertyValues(RowData, TableRow);
				Result.Selected.Add(RowData);
			EndIf;
		EndDo;
	EndIf;
	
	Return Result;
EndFunction

&AtServer
Procedure RecallSelectedRows(TableName, TableRows)
	TableAttribute = ThisObject[TableName];
	ItemTable = Items[TableName];
	
	ItemTable.SelectedRows.Clear();
	
	If TableRows.Current <> Undefined Then
		Found = FindTableRows(TableAttribute, TableRows.Current);
		If Found <> Undefined AND Found.Count() > 0 Then
			For Each TableRow In Found Do
				If TableRow <> Undefined Then
					ID = TableRow.GetID();
					ItemTable.CurrentRow = ID;
					ItemTable.SelectedRows.Add(ID);
					Break;
				EndIf;
			EndDo;
		EndIf;
	EndIf;
	
	For Each RowData In TableRows.Selected Do
		Found = FindTableRows(TableAttribute, RowData);
		If Found <> Undefined AND Found.Count() > 0 Then
			For Each TableRow In Found Do
				If TableRow <> Undefined Then
					ItemTable.SelectedRows.Add(TableRow.GetID());
				EndIf;
			EndDo;
		EndIf;
	EndDo;
EndProcedure

&AtServer
Function FindTableRows(TableAttribute, RowData)
	If TypeOf(TableAttribute) = Type("FormDataCollection") Then // Values table.
		Return TableAttribute.FindRows(RowData);
	ElsIf TypeOf(TableAttribute) = Type("FormDataTree") Then // Values tree.
		Return FindRecursively(TableAttribute.GetItems(), RowData);
	Else
		Return Undefined;
	EndIf;
EndFunction

&AtServer
Function FindRecursively(RowsSet, RowData, Found = Undefined)
	If Found = Undefined Then
		Found = New Array;
	EndIf;
	For Each TableRow In RowsSet Do
		ValuesMatch = True;
		For Each KeyAndValue In RowData Do
			If TableRow[KeyAndValue.Key] <> KeyAndValue.Value Then
				ValuesMatch = False;
				Break;
			EndIf;
		EndDo;
		If ValuesMatch Then
			Found.Add(TableRow);
		EndIf;
		FindRecursively(TableRow.GetItems(), RowData, Found);
	EndDo;
	Return Found;
EndFunction

&AtServerNoContext
Procedure SwitchOffSoleMode()
	CommonUse.UnlockInfobase();
EndProcedure

&AtClient
Procedure BackgroundJobStartAfterSettingExclusiveMode(Result, AdditionalParameters) Export
	If Result = False Then // The exclusive mode is set.
		BackgroundJobStartOnClient(AdditionalParameters);
	EndIf;
EndProcedure

#EndRegion

#Region Server

&AtServer
Procedure OnCreateAtServerSetExplanationTextForProcessing()
	If StandardSubsystemsServer.ThisIsBasicConfigurationVersion() Then
		ConnectionsQuantity = 0;
		OutputSignature = False;
		OutputQuantity = False;
	ElsIf CommonUse.FileInfobase() Then
		ConnectionsQuantity = 0;
		ThisSessionNumber = InfobaseSessionNumber();
		For Each InfobaseSession In GetInfobaseSessions() Do
			If InfobaseSession.SessionNumber = ThisSessionNumber Then
				Continue;
			EndIf;
			If InfobaseSession.ApplicationName = "1CV8" // Thick .
				Or InfobaseSession.ApplicationName = "1CV8C" // Thin client.
				Or InfobaseSession.ApplicationName = "WebClient" // Web client.
				Then
				ConnectionsQuantity = ConnectionsQuantity + 1;
			EndIf;
		EndDo;
		OutputSignature = (ConnectionsQuantity > 0);
		OutputQuantity = True;
	Else
		ConnectionsQuantity = 0;
		OutputSignature = True;
		OutputQuantity = False;
	EndIf;
	
	CaptionPattern = Items.ExplanationToProcessing.Title;
	If Not OutputSignature Then
		Items.ExplanationToProcessing.Title = Left(CaptionPattern, Find(CaptionPattern, "<1/>") - 1);
		WindowOptionsKey = "1";
	Else
		Balance = StrReplace(CaptionPattern, "<1/>", "");
		RowArray = New Array;
		
		Position = Find(Balance, "<a");
		RowArray.Add(Left(Balance, Position - 1));
		Balance = Mid(Balance, Position);
		
		Position = Find(Balance, "</a>");
		DetermineRef = Left(Balance, Position -1);
		Balance = Mid(Balance, Position + 4);
		
		Position = Find(DetermineRef, """");
		DetermineRef = Mid(DetermineRef, Position + 1);
		
		Position = Find(DetermineRef, """");
		RefAddress = Left(DetermineRef, Position - 1);
		HyperlinkText = Mid(DetermineRef, Position + 2);
		If OutputQuantity Then
			HyperlinkText = HyperlinkText + " (" + Format(ConnectionsQuantity, "NG=") + ")";
		EndIf;
		
		RowArray.Add(New FormattedString(HyperlinkText, , , , RefAddress));
		RowArray.Add(Balance);
		
		Items.ExplanationToProcessing.Title = New FormattedString(RowArray);
		WindowOptionsKey = "2";
	EndIf;
EndProcedure

&AtServer
Procedure BackgroundJobShowLongOperationPage(JobParameters)
	ModePresentation = Items.DeletionMode.ChoiceList.FindByValue(DeletionMode).Presentation;
	
	ShowDonut = JobParameters.DeleteMarked AND Exclusive;
	Items.BackgroundOrderAnimation.Visible = ShowDonut;
	Items.BackgroundOrderPercent.Visible  = Not ShowDonut;
	Items.FormPages.CurrentPage    = Items.PageLongOperation;
	If ShowDonut Then
		Items.LabelLongAction.Title = NStr("en = 'Please wait...'");
		Items.BackgroundOrderStatus.HorizontalAlign = ItemHorizontalLocation.Left;
	ElsIf JobParameters.DeleteMarked Then
		Items.LabelLongAction.Title = NStr("en = 'Deleting the objects marked for deletion...'");
		Items.BackgroundOrderStatus.HorizontalAlign = ItemHorizontalLocation.Center;
	Else
		Items.LabelLongAction.Title = NStr("en = 'Search for objects marked for deletion...'");
		Items.BackgroundOrderStatus.HorizontalAlign = ItemHorizontalLocation.Center;
	EndIf;
EndProcedure

&AtServer
Procedure BackgroundJobReadInterimResult(Result)
	Progress = LongActions.ReadProgress(BackgroundJobID);
	If Progress <> Undefined Then
		BackgroundOrderPercent   = Progress.Percent;
		BackgroundOrderStatus = Progress.Text;
	EndIf;
EndProcedure

&AtServer
Procedure BackgroundJobImportResult(Result)
	If Exclusive Then
		SwitchOffSoleMode();
	EndIf;
	
	// Receive result.
	ExecutionResultInBackground = GetFromTempStorage(BackgroundJobStorageAddress);
	If ExecutionResultInBackground = Undefined Then
		Return;
	EndIf;
	
	If ExecutionResultInBackground.DeleteMarked Then
		
		// Prepare notifications for the dynamic lists.
		StandardSubsystemsClientServer.NotifyDynamicLists(Result, ExecutionResultInBackground.Deleted);
		
		DeletedQuantity = ExecutionResultInBackground.Deleted.Count();
		NotRemovedQuantity = ExecutionResultInBackground.NotRemoved.Count();
		
		NotificationText = Undefined;
		NotificationPicture = Undefined;
		
		If DeletedQuantity = 0 AND NotRemovedQuantity = 0 Then
			Items.FormPages.CurrentPage = Items.PageDeleteNotRequired;
		ElsIf NotRemovedQuantity = 0 Then
			Items.FormPages.CurrentPage = Items.PageSuccessfullyCompleted;
			NotificationText = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Removing marked objects successfully completed.
				     |Objects deleted: %1.'"),
				Format(DeletedQuantity, "NZ=0; NG=")
			);
			Items.LabelSuccessfullyCompleted.Title = NotificationText;
		Else
			Items.FormPages.CurrentPage = Items.PageReasonsRemovingUnavailable;
			NotificationText = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Marked objects are deleted.
				     |Objects deleted:
				     |%1, Not deleted: %2.'"),
				Format(DeletedQuantity, "NZ=0; NG="),
				Format(NOTRemovedQuantity, "NZ=0; NG=")
			);
			NotificationPicture = PictureLib.Warning32;
			
			If DeletedQuantity = 0 Then
				Items.LabelResultPartialRemoval.Title = StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = 'Cannot delete objects marked for deletion (%1):'"),
					Format(NOTRemovedQuantity, "NZ=0; NG=")
				);
			Else
				Items.LabelResultPartialRemoval.Title = StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = 'Successfully deleted: %1 from %2, other objects are not deleted (%3):'"),
					Format(DeletedQuantity, "NZ=0; NG="),
					Format(DeletedQuantity+NotRemovedQuantity, "NZ=0; NG="),
					Format(NOTRemovedQuantity, "NZ=0; NG=")
				);
			EndIf;
			
			Pattern = Items.GroupNotRemoved.Title;
			Pattern = Left(Pattern, Find(Pattern, "("));
			Items.GroupNotRemoved.Title = Pattern + Format(NOTRemovedQuantity, "NZ=0; NG=") + ")";
			
			FillLeftObjectCollections(ExecutionResultInBackground);
			
			NotRemovedGroups = NotRemoved.GetItems();
			If NotRemovedGroups.Count() > 0 Then
				FirstGroupItems = NotRemovedGroups[0].GetItems();
				If FirstGroupItems.Count() > 0 Then
					Items.NotRemoved.CurrentRow = FirstGroupItems[0].GetID();
				EndIf;
			EndIf;
			
		EndIf;
		
		If NotificationText <> Undefined Then
			StandardSubsystemsClientServer.DisplayNotification(
				Result,
				NStr("en = 'Deletion of marked objects'"),
				NotificationText,
				NotificationPicture,
				URL);
		EndIf;
		
	Else
		
		// Fill in the tree marked for deletion.
		marked = MarkToDeleteFromResultsPage();
		MarksSetSelectively = (marked.Count() > 0);
		
		DataProcessorManager = DataProcessors.DeleteMarkedObjects;
		
		ValueTree = FormAttributeToValue("MarkedToRemoveTree");
		ValueTree.Rows.Clear();
		ValueTree.Columns.Add("Quantity");
		
		FirstLevelNodes = New Map;
		
		CustomObjects = ExecutionResultInBackground.CustomObjects;
		For Each RemovedRefs In CustomObjects Do
			DeletedType = TypeOf(RemovedRefs);
			DeletedInformation = DataProcessorManager.GenerateTypeInformation(ExecutionResultInBackground, DeletedType);
			
			TypeNode = FirstLevelNodes.Get(DeletedType);
			If TypeNode = Undefined Then
				DeletedMetadata = RemovedRefs.Metadata();
				TypeNode = ValueTree.Rows.Add();
				TypeNode.Value      = DeletedInformation.FullName;
				TypeNode.Presentation = DeletedInformation.ListPresentation;
				TypeNode.Check       = True;
				TypeNode.Quantity    = 0;
				TypeNode.PictureNumber = -1;
				FirstLevelNodes.Insert(DeletedType, TypeNode);
			EndIf;
			TypeNode.Quantity = TypeNode.Quantity + 1;
			
			DeletedNode = TypeNode.Rows.Add();
			DeletedNode.Value      = RemovedRefs;
			DeletedNode.Presentation = String(RemovedRefs);
			DeletedNode.Check       = True;
			DeletedNode.PictureNumber = PictureNumber(RemovedRefs, True, DeletedInformation.Type, True);
			
			If MarksSetSelectively AND marked.Find(RemovedRefs) = Undefined Then
				DeletedNode.Check = False;
				TypeNode.Check       = False;
			EndIf;
			
		EndDo;
		
		For Each TypeNode In ValueTree.Rows Do
			TypeNode.Presentation = TypeNode.Presentation + " (" + TypeNode.Quantity + ")";
		EndDo;
		
		ValueTree.Columns.Delete(ValueTree.Columns.Quantity);
		ValueTree.Rows.Sort("Presentation", True);
		
		ValueToFormAttribute(ValueTree, "MarkedToRemoveTree");
		
		TypeCount = FirstLevelNodes.Count();
		
		If TypeCount = 0 Then
			Items.FormPages.CurrentPage = Items.PageDeleteNotRequired;
		Else
			Items.FormPages.CurrentPage = Items.PageMarkedToRemove;
			If TypeCount = 1 Then
				StandardSubsystemsClientServer.CollapseTreeNodes(Result, "MarkedToRemoveTree");
			EndIf;
		EndIf;
		
	EndIf;
	
	DeleteFromTempStorage(BackgroundJobStorageAddress);
	BackgroundJobStorageAddress = Undefined;
	BackgroundJobID  = Undefined;
	VisibleEnabled(ThisObject);
EndProcedure

&AtServer
Procedure FillLeftObjectCollections(ExecutionResultInBackground)
	
	ImpedingRemoval = ExecutionResultInBackground.ImpedingRemoval;
	TypeInformation = ExecutionResultInBackground.TypeInformation;
	
	TreeNotRemoved = FormAttributeToValue("NotRemoved");
	TreeNotRemoved.Rows.Clear();
	NotRemovedConnectionTable = FormAttributeToValue("ConnectionsNotRemoved");
	NotRemovedConnectionTable.Clear();
	
	NotRemovedGroups = New Map;
	NotRemovedStrings = New Map;
	
	For Each Cause In ImpedingRemoval Do
		StringNotRemoved = NotRemovedStrings.Get(Cause.RemovedRefs);
		If StringNotRemoved = Undefined Then
			DeletedInformation = TypeInformation.Get(Cause.DeletedType);
			If DeletedInformation.Technical Then
				Continue;
			EndIf;
			
			NotRemovedGroup = NotRemovedGroups.Get(Cause.DeletedType);
			If NotRemovedGroup = Undefined Then
				NotRemovedGroup = TreeNotRemoved.Rows.Add();
				NotRemovedGroup.PictureNumber   = -1;
				NotRemovedGroup.RemovedRefs = DeletedInformation.FullName;
				NotRemovedGroup.Presentation   = DeletedInformation.ListPresentation;
				
				NotRemovedGroups.Insert(Cause.DeletedType, NotRemovedGroup);
			EndIf;
			
			NotRemovedGroup.ConnectionsCount = NotRemovedGroup.ConnectionsCount + 1;
			
			StringNotRemoved = NotRemovedGroup.Rows.Add();
			StringNotRemoved.RemovedRefs = Cause.RemovedRefs;
			StringNotRemoved.Presentation   = String(Cause.RemovedRefs);
			StringNotRemoved.DeletionMark = True;
			
			StringNotRemoved.PictureNumber = PictureNumber(
				StringNotRemoved.RemovedRefs,
				True,
				DeletedInformation.Type,
				StringNotRemoved.DeletionMark);
			
			NotRemovedStrings.Insert(Cause.RemovedRefs, StringNotRemoved);
		EndIf;
		
		StringNotRemoved.ConnectionsCount = StringNotRemoved.ConnectionsCount + 1;
		
		RemovalObstacleString = NotRemovedConnectionTable.Add();
		RemovalObstacleString.RemovedRefs    = Cause.RemovedRefs;
		RemovalObstacleString.FoundReference = Cause.FoundReference;
		RemovalObstacleString.DeletionMark    = Cause.DetectedDeletionMark;
		RemovalObstacleString.IsError          = (Cause.DetectedType = Type("String"));
		
		If Not RemovalObstacleString.IsError Then
			DetectedInformation = TypeInformation.Get(Cause.DetectedType);
			
			RemovalObstacleString.LinkingType = DetectedInformation.Reference;
			
			If Cause.FoundReference = Undefined Then // Constant
				RemovalObstacleString.FoundReference = DetectedInformation.FullName;
				RemovalObstacleString.ThisIsConstant = True;
				RemovalObstacleString.Presentation = DetectedInformation.ItemPresentation + " (" + NStr("en = 'Constant'") + ")";
			Else
				RemovalObstacleString.Presentation = String(Cause.FoundReference) + " (" + DetectedInformation.ItemPresentation + ")";
			EndIf;
			
			RemovalObstacleString.PictureNumber = PictureNumber(
				RemovalObstacleString.FoundReference,
				RemovalObstacleString.LinkingType,
				DetectedInformation.Type,
				RemovalObstacleString.DeletionMark);
		EndIf;
	EndDo;
	
	For Each NotRemovedGroup In TreeNotRemoved.Rows Do
		NotRemovedGroup.Presentation = NotRemovedGroup.Presentation + " (" + Format(NOTRemovedGroup.ConnectionsCount, "NZ=0; NG=") + ")";
	EndDo;
	
	TreeNotRemoved.Rows.Sort("Presentation", True);
	NotRemovedConnectionTable.Sort("RemovedRefs, Presentation");
	
	ValueToFormAttribute(TreeNotRemoved,       "NotRemoved");
	ValueToFormAttribute(NOTRemovedConnectionTable, "ConnectionsNotRemoved");
EndProcedure

#EndRegion

#EndRegion
