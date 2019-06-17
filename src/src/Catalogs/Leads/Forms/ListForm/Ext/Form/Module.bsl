#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	DataImportFromExternalSources.OnCreateAtServer(Metadata.Catalogs.Leads, DataLoadSettings, ThisObject);
	Items.DataImportFromExternalSources.Visible = AccessRight("Use", Metadata.DataProcessors.DataImportFromExternalSources);
	
	// Establish the form settings for the case of the opening in choice mode
	Items.List.ChoiceMode		= Parameters.ChoiceMode;
	Items.List.MultipleChoice	= ?(Parameters.CloseOnChoice = Undefined, False, Not Parameters.CloseOnChoice);
	If Parameters.ChoiceMode Then
		PurposeUseKey = "ChoicePick";
		WindowOpeningMode = FormWindowOpeningMode.LockOwnerWindow;
		Items.GroupViewType.Visible = False;
	Else
		PurposeUseKey = "List";
	EndIf;
	
	If NOT Items.List.ChoiceMode Then
		FormFilterOption = FilterOptionForSetting();
		WorkWithFilters.RestoreFilterSettings(ThisObject, List,,,New Structure("FilterPeriod", "Created"), FormFilterOption, True);
	Else
		PeriodPresentation = WorkWithFiltersClientServer.RefreshPeriodPresentation(New StandardPeriod);
	EndIf;
	
	SetFilterByResult();
	
	ViewType = CommonSettingsStorage.Load("ViewType", "ViewType_LeadsList");
	FilterCampaign = CommonSettingsStorage.Load("Filter", "FilterCampaign");
	DriveClientServer.SetListFilterItem(List, "Campaign", FilterCampaign, ValueIsFilled(FilterCampaign));

	If Not ValueIsFilled(FilterCampaign) Then
		ViewType = "List";
	EndIf;
	
	SetActivityChoiseList(FilterCampaign);
	
	Items.FormList.Check = NOT ValueIsFilled(ViewType) OR ViewType = "List" OR Parameters.ChoiceMode;
	Items.FormKanban.Check = ValueIsFilled(ViewType) AND ViewType = "Kanban" AND NOT Parameters.ChoiceMode;
	
	FormManagement();
	
	SetConditionalAppearanceInCampaignsColorsAtServer();

	If Items.FormKanban.Check Then
		
		UpdatePlannerItemsAndDimensions();
		CurrentItem = Items.Planner;
		
	EndIf;
	
	ContactInformationPanelDrive.OnCreateAtServer(ThisObject, "ContactInformation");
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "Write_Lead" Then
		
		If Items.FormKanban.Check Then
			UpdatePlannerItemsAndDimensions("Drag");
		EndIf;
		Items.List.Refresh();
		RefreshContactInformationPanelServer();
		
	EndIf;
	
	If EventName = "OrderChanging_LeadsActivities" AND Items.FormKanban.Check Then
		
		UpdatePlannerItemsAndDimensions("Drag");
		
	EndIf;
	
	If EventName = "PeriodClick_Leads" Then
		
		If Items.FormKanban.Check Then
			UpdatePlannerItems("Creation");
		Else
			SetFilterByResult();
		EndIf;
		
	EndIf;
	
	If EventName = "Write_Campaigns" Then
		
		If Items.FormKanban.Check Then
			UpdatePlannerItemsAndDimensions("Drag");
		EndIf;
		SetConditionalAppearanceAndUpdateActivityCommands();
		Items.List.Refresh();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OnClose(Exit)
	
	If Exit Then
		Return;
	EndIf;
	
	SaveFilterSettings();

EndProcedure

&AtClient
Procedure ChoiceProcessing(SelectedValue, ChoiceSource)
	
	If TypeOf(SelectedValue) = Type("CatalogRef.Campaigns") Then
		
		LeadsArray = New Array;
		For Each ChangedLead In ChangedLeads Do
			ChangeLeadStateAtServer(ChangedLead.Lead, SelectedValue, , PredefinedValue("Catalog.CampaignActivities.EmptyRef"));
			LeadsArray.Add(ChangedLead.Lead);
		EndDo;
		
		Notify("Write_Lead", LeadsArray);
		
	ElsIf TypeOf(SelectedValue) = Type("CatalogRef.Employees") Then
		
		LeadsArray = New Array;
		For Each ChangedLead In ChangedLeads Do
			ChangeLeadStateAtServer(ChangedLead.Lead, , SelectedValue);
			LeadsArray.Add(ChangedLead.Lead);
		EndDo;
		
		Notify("Write_Lead", LeadsArray);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure PeriodPresentationClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	WorkWithFiltersClient.PeriodPresentationSelectPeriod(ThisObject, "List", "Created", , "PeriodClick_Leads");
	
EndProcedure

&AtClient
Procedure FilterTagChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	If Not ValueIsFilled(SelectedValue) Then
		Return;
	EndIf;
	
	SetLabelAndListFilter("Tags.Tag", Item.Parent.Name, SelectedValue);
	SelectedValue = Undefined;
	
EndProcedure

&AtClient
Procedure FilterSalesRepChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	If Not ValueIsFilled(SelectedValue) Then
		Return;
	EndIf;
	
	SetLabelAndListFilter("SalesRep", Item.Parent.Name, SelectedValue);
	SelectedValue = Undefined;
	
EndProcedure

&AtClient
Procedure FilterCampaignOnChange(Item)
	
	SetActivityChoiseList(FilterCampaign);
	
	DriveClientServer.DeleteListFilterItem(List, "Activity");
	
	DriveClientServer.SetListFilterItem(List, "Campaign", FilterCampaign, ValueIsFilled(FilterCampaign));
	
	UpdatePlannerItemsAndDimensions();
	
EndProcedure

&AtClient
Procedure FilterActivityChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	If Not ValueIsFilled(SelectedValue) Then
		Return;
	EndIf;
	
	SetLabelAndListFilter("Activity", Item.Parent.Name, SelectedValue);
	SelectedValue = Undefined;
	
EndProcedure

&AtClient
Procedure FilterAcquisitionChannelChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	If Not ValueIsFilled(SelectedValue) Then
		Return;
	EndIf;
	
	SetLabelAndListFilter("AcquisitionChannel", Item.Parent.Name, SelectedValue);
	SelectedValue = Undefined;
	
EndProcedure

&AtClient
Procedure FilterResultChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	ValuePresentation = String(SelectedValue);
	If NOT ValueIsFilled(SelectedValue) Then
		ValuePresentation = "Active";
	EndIf;
	
	SetLabelAndListFilter("ClosureResult", Item.Parent.Name, SelectedValue, ValuePresentation);
	SetFilterByResult();
	
	SelectedValue = Undefined;
	
EndProcedure

&AtClient
Procedure CollapseExpandFiltesPanelClick(Item)
	
	NewValueVisible = NOT Items.FilterSettingsAndAddInfo.Visible;
	WorkWithFiltersClient.CollapseExpandFiltesPanel(ThisObject, NewValueVisible);
	
EndProcedure

&AtClient
Procedure FilterSearchClearing(Item, StandardProcessing)
	
	FilterSearch = "";
	UpdatePlannerItems("Creation");
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure DecorationIntoCustomerDragCheck(Item, DragParameters, StandardProcessing)
	
	StandardProcessing = False;
	
EndProcedure

&AtClient
Procedure DecorationRejectedLeadDragCheck(Item, DragParameters, StandardProcessing)
	
	StandardProcessing = False;
	
EndProcedure

&AtClient
Procedure DecorationIntoCustomerDrag(Item, DragParameters, StandardProcessing)
	
	StandardProcessing = False;
	
	If TypeOf(DragParameters.Value) <> Type("Array")
		OR DragParameters.Value.Count() = 0 Then 
		Return;
	EndIf;
	
	DraggedLead = DragParameters.Value[0].Value;
	
	If NOT ValueIsFilled(DraggedLead) Then
		Return;
	EndIf;
	
	If NOT CanBeTransferredToClient(DraggedLead) Then
		Return;
	EndIf;
	
	Counterparty = ConvertIntoCustomerAtServer(DraggedLead);
	
	If Not ValueIsFilled(Counterparty) OR Counterparty = Undefined Then
		Return;
	EndIf;
	
	NotifyChanged(DraggedLead);
	Notify("Write_Lead", DraggedLead);
	
	FormParameters = New Structure("Key", Counterparty);
	OpenForm("Catalog.Counterparties.ObjectForm", FormParameters);
	
EndProcedure

&AtClient
Procedure DecorationRejectedLeadDrag(Item, DragParameters, StandardProcessing)
	
	StandardProcessing = False;
	
	If TypeOf(DragParameters.Value) <> Type("Array")
		OR DragParameters.Value.Count() = 0 Then
		Return;
	EndIf;
	
	ChangedLeads.Clear();
	
	For Each Lead In DragParameters.Value Do
		
		If NOT ValueIsFilled(Lead.Value) Then
			Continue;
		EndIf;
		
		NewRejectedLead = ChangedLeads.Add();
		NewRejectedLead.Lead = Lead.Value;
		
	EndDo;
	
	If ChangedLeads.Count() = 0 Then
		Return;
	EndIf;
	
	Res = New NotifyDescription("DoAfterCloseRejectedLead", ThisObject);
	OpenForm("Catalog.Leads.Form.FormOfRejectedLead",,,,,,Res, FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtClient
Procedure MarkFoDeletionBinDragCheck(Item, DragParameters, StandardProcessing)
	
	StandardProcessing = False;
	
EndProcedure

&AtClient
Procedure MarkFoDeletionBinDrag(Item, DragParameters, StandardProcessing)
	
	StandardProcessing = False;
	
	If TypeOf(DragParameters.Value) <> Type("Array")
		OR DragParameters.Value.Count() = 0 Then 
		Return;
	EndIf;
	
	If DragParameters.Value.Count() > 1 Then
		Str = NStr("en = 'Leads marked for deletion'");
	Else
		Str = NStr("en = 'Lead marked for deletion'");
	EndIf;
	
	LeadsArray = New Array;
	
	For Each Lead In DragParameters.Value Do
		LeadsArray.Add(Lead.Value);
	EndDo;
	
	MarkFoDeletionBinDragAtServer(LeadsArray);
	
	ShowUserNotification(
		NStr("en = 'Deletion mark'"),
		,
		Str,
		PictureLib.Information32);
		
EndProcedure

&AtClient
Procedure FilterSearchEditTextChange(Item, Text, StandardProcessing)
	
	FilterSearch = Text;
	UpdatePlannerItems("Creation");
	
EndProcedure

#EndRegion

#Region ListFormTableItemsEventHandlers

&AtClient
Procedure ListOnActivateRow(Item)
	
	If TypeOf(Item.CurrentRow) <> Type("DynamicalListGroupRow") Then
		
		LeadCurrentRow = ?(Item.CurrentData = Undefined, Undefined, Item.CurrentData.Ref);
		If LeadCurrentRow <> CurrentLead Then
			CurrentLead = LeadCurrentRow;
			AttachIdleHandler("HandleActivateListRow", 0.2, True);
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Clone, Parent, Folder, Parameter)
	
	KeyOperation = "FormCreatingLeads";
	PerformanceEstimationClientServer.StartTimeMeasurement(KeyOperation);
	
EndProcedure

&AtClient
Procedure ListBeforeRowChange(Item, Cancel)
	
	KeyOperation = "FormOpeningLeads";
	PerformanceEstimationClientServer.StartTimeMeasurement(KeyOperation);
	
EndProcedure

&AtClient
Procedure ListNewWriteProcessing(NewObject, Source, StandardProcessing)
	
	CurrentItem = Items.List;
	
EndProcedure

&AtClient
Procedure ListSelection(Item, SelectedRow, Field, StandardProcessing)
	
	If Field.Name = "Counterparty" Then
		
		Counterparty = CounterpartyRef(SelectedRow);
		
		If NOT ValueIsFilled(Counterparty) Then
			Return;
		EndIf;
		
		StandardProcessing = False;
		FormParameters = New Structure("Key", Counterparty);
		OpenForm("Catalog.Counterparties.ObjectForm", FormParameters);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormPlannerItemsEventHandlers

&AtClient
Procedure PlannerOnEditEnd(Item, NewItem, CancelEdit)
	
	FirstItem = Item.SelectedItems[0];
	
	If Second(FirstItem.End) - Second(FirstItem.Begin) <> 2 Then
		CancelEdit = True;
		Return;
	EndIf;
	
	DragParameters = New Structure;
	
	DragParameters.Insert("DragAndDropLead", Undefined);
	DragParameters.Insert("MoveToTheTop", False);
	DragParameters.Insert("MoveToTheEnd", False);
	DragParameters.Insert("Activity", FirstItem.DimensionValues["LeadActivities"]);
	
	Array = New Array;
	For Each SelectedItem In Item.SelectedItems Do
		Array.Add(SelectedItem.Value);
	EndDo;
	DragParameters.Insert("DragAndDropLeads", Array);
	
	If FirstItem.Begin = Planner.CurrentRepresentationPeriods[0].Begin Then
		DragParameters.Insert("MoveToTheTop", True);
	ElsIf FirstItem.Begin >= Planner.CurrentRepresentationPeriods[0].End Then 
		DragParameters.Insert("MoveToTheEnd", True);
	Else
		For Each PlannerItem In Planner.Items Do
			If ((PlannerItem.Begin = FirstItem.Begin
					AND PlannerItem.End = FirstItem.End)
				OR (Item.SelectedItems[Item.SelectedItems.UBound()].End > PlannerItem.Begin
					AND Item.SelectedItems[Item.SelectedItems.UBound()].End < PlannerItem.End))
				AND FirstItem.DimensionValues.Get("LeadActivities") = PlannerItem.DimensionValues.Get("LeadActivities")
				AND PlannerItem.Value <> FirstItem.Value Then
				
				DragParameters.Insert("DragAndDropLead", PlannerItem.Value);
				Break;
			EndIf;
		EndDo;
		
	EndIf;
	
	UpdatePlannerItemsDrag(DragParameters);
	Notify("Write_Lead", Array);
	
EndProcedure

&AtClient
Procedure PlannerOnCurrentRepresentationPeriodChange(Item, CurrentRepresentationPeriods, StandardProcessing)
	
	StandardProcessing = False;
	
	If MaxItemKanban < CurrentRepresentationPeriods[0].Begin - 1 Then
		Return;
	EndIf;
	
	NewRepresentationPeriod = Planner.CurrentRepresentationPeriods[0];
	
	If CurrentRepresentationPeriods[0].Begin > NewRepresentationPeriod.End Then
		CurrentDisplayKanban = CurrentDisplayKanban + 1;
		UpdatePlannerItems("Scroll","ScrollForward");
	ElsIf CurrentRepresentationPeriods[0].Begin < NewRepresentationPeriod.Begin Then
		
		CurrentDisplayKanban = CurrentDisplayKanban - 1;
		
		If CurrentDisplayKanban < 0 Then
			CurrentDisplayKanban = 0;
		Else
			If CurrentDisplayKanban = 0 Then
				UpdatePlannerItems("Creation");
			Else
				UpdatePlannerItems("Scroll","ScrollBackward");
			EndIf; 
		EndIf;
	EndIf;
		
EndProcedure

&AtClient
Procedure PlannerBeforeStartEdit(Item, NewItem, StandardProcessing)
	
	StandardProcessing = False;
	
EndProcedure

&AtClient
Procedure PlannerSelection(Item, StandardProcessing)
	
	StandardProcessing = False;
	OpenCurrentPlannerItemForm();
	
EndProcedure

&AtClient
Procedure PlannerBeforeCreate(Item, Begin, End, Values, Text, StandardProcessing)
	StandardProcessing = False;
EndProcedure

&AtClient
Procedure PlannerBeforeStartQuickEdit(Item, StandardProcessing)
	StandardProcessing = False;
EndProcedure

&AtClient
Procedure PlannerOnActivate(Item)
	
	If Item.SelectedItems.Count() = 0 Then
		CurrentLead = Undefined;
		RefreshContactInformationPanelKanban();
		Return;
	EndIf;
	
	If Item.SelectedItems[0].Begin = (FirstItemKanban + NumberOfItemsToDisplayCanban*2 + 1) Then
		GoToActivityEnd(Item.SelectedItems[0].DimensionValues["LeadActivities"]);
	ElsIf Item.SelectedItems[0].Begin = FirstItemKanban Then
		CurrentDisplayKanban = 0;
		UpdatePlannerItems("Creation");
	Else
		CurrentLead = Item.SelectedItems[0].Value;
		RefreshContactInformationPanelKanban();
	EndIf;
	
EndProcedure

&AtClient
Procedure PlannerBeforeDelete(Item, Cancel)
	
	Cancel = True;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure Kanban(Command)
	
	Items.FormKanban.Check = True;
	Items.FormList.Check = False;
	
	UpdatePlannerItemsAndDimensions();
	RefreshContactInformationPanelKanban();
	CurrentItem = Items.Planner;
	
EndProcedure

&AtClient
Procedure List(Command)
	
	Items.FormKanban.Check = False;
	Items.FormList.Check = True;
	FormManagement();
	
EndProcedure

&AtClient
Procedure ConvertIntoCustomer()
	
	DontAskUser = DriveReUse.GetValueByDefaultUser(UsersClientServer.CurrentUser(), "ConvertLeadWithoutMessage");
	
	If Not DontAskUser Then
		
		QuestionParameters = StandardSubsystemsClient.QuestionToUserParameters();
		QuestionParameters.OfferDontAskAgain = True;
		QuestionParameters.Title = "Lead finalizing";
		
		Notify = New NotifyDescription("ConvertIntoCustomerClickEnd", ThisObject);
		QuestionText = NStr("en = 'Are you sure you want to convert the lead to the customer? This is an irreversible action.'");
		StandardSubsystemsClient.ShowQuestionToUser(Notify, QuestionText, QuestionDialogMode.OKCancel, QuestionParameters);
		
	Else
		
		Response = New Structure;
		Response.Insert("Value", DialogReturnCode.OK);
		Response.Insert("DontAskAgain", False);
		ConvertIntoCustomerClickEnd(Response, Undefined);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure MoveToEnd(Command)
	
	If Items.Planner.SelectedItems.Count() = 0 Then 
		Return;
	EndIf;
	
	FirstItem = Items.Planner.SelectedItems[0];
	
	Lead = FirstItem.Value;
	
	If Lead = Undefined OR NOT ValueIsFilled(Lead) Then
		Return;
	EndIf;
	
	DragParameters = New Structure;
	Array = New Array;
	
	DragParameters.Insert("MoveToTheTop", False);
	DragParameters.Insert("DragAndDropLead", Undefined);
	DragParameters.Insert("MoveToTheEnd", True);
	DragParameters.Insert("Activity", FirstItem.DimensionValues["LeadActivities"]);
	DragParameters.Insert("Campaign", FilterCampaign);
	
	For Each SelectedItem In Items.Planner.SelectedItems Do
		Array.Add(SelectedItem.Value);
	EndDo;
	DragParameters.Insert("DragAndDropLeads", Array);
	
	UpdatePlannerItemsDrag(DragParameters);
	
EndProcedure

&AtClient
Procedure MoveToTop(Command)
	
	If Items.Planner.SelectedItems.Count() = 0 Then 
		Return;
	EndIf;
	
	FirstItem = Items.Planner.SelectedItems[0];
	
	Lead = FirstItem.Value;
	
	If Lead = Undefined OR NOT ValueIsFilled(Lead) Then
		Return;
	EndIf;
	
	DragParameters = New Structure;
	Array = New Array;
	
	DragParameters.Insert("MoveToTheTop", True);
	DragParameters.Insert("DragAndDropLead", Undefined);
	DragParameters.Insert("MoveToTheEnd", False);
	DragParameters.Insert("Activity", FirstItem.DimensionValues["LeadActivities"]);
	DragParameters.Insert("Campaign", FilterCampaign);
	
	For Each SelectedItem In Items.Planner.SelectedItems Do
		Array.Add(SelectedItem.Value);
	EndDo;
	DragParameters.Insert("DragAndDropLeads", Array);
	
	UpdatePlannerItemsDrag(DragParameters);
	
EndProcedure

&AtClient
Procedure MoveUp(Command)
	
	If Items.Planner.SelectedItems.Count() = 0 Then 
		Return;
	EndIf;
	
	FirstItem = Items.Planner.SelectedItems[0];
	
	Lead = FirstItem.Value;
	
	If Lead = Undefined OR NOT ValueIsFilled(Lead) Then
		Return;
	EndIf;
	
	MoveUpDownAtServer(Lead, FirstItem.DimensionValues["LeadActivities"], "MoveUp");
	
EndProcedure

&AtClient
Procedure MoveDown(Command)
	
	If Items.Planner.SelectedItems.Count() = 0 Then 
		Return;
	EndIf;
	
	FirstItem = Items.Planner.SelectedItems[0];
	
	Lead = FirstItem.Value;
	
	If Lead = Undefined OR NOT ValueIsFilled(Lead) Then
		Return;
	EndIf;
	
	MoveUpDownAtServer(Lead, FirstItem.DimensionValues["LeadActivities"], "MoveDown");
	
EndProcedure

&AtClient
Procedure Create(Command)
	
	OpenForm("Catalog.Leads.ObjectForm",,ThisObject);
	
EndProcedure

&AtClient
Procedure ConvertIntoReject()
	
	If Not CheckLeadsSelected() Then
		Return;
	EndIf;
	
	ChangedLeads.Clear();
	
	If Items.FormKanban.Check Then
		
		For Each Lead In Items.Planner.SelectedItems Do
			
			If NOT ValueIsFilled(Lead.Value) Then
				Continue;
			EndIf;
			
			NewRejectedLead = ChangedLeads.Add();
			NewRejectedLead.Lead = Lead.Value;
			
		EndDo;
		
		If ChangedLeads.Count() = 0 Then
			Return;
		EndIf;
		
	EndIf;
	
	If Items.FormList.Check Then
		
		For Each Lead In Items.List.SelectedRows Do
			
			If NOT ValueIsFilled(Lead) Then
				Continue;
			EndIf;
			
			NewRejectedLead = ChangedLeads.Add();
			NewRejectedLead.Lead = Lead;
			
		EndDo;
		
		If ChangedLeads.Count() = 0 Then
			Return;
		EndIf;
		
	EndIf;
	
	RejectedLead = New NotifyDescription("DoAfterCloseRejectedLead", ThisObject);
	OpenForm("Catalog.Leads.Form.FormOfRejectedLead",,,,,, RejectedLead, FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtClient
Procedure PhoneCall(Command)
	
	If Not CheckLeadSelected() Then
		Return;
	EndIf;
	
	If Items.FormList.Check Then
		SelectedLead = Items.List.CurrentData.Ref;
	Else
		SelectedLead = Items.Planner.SelectedItems[0].Value;
	EndIf;
	
	CreateEventWithContact("PhoneCall", SelectedLead);

EndProcedure

&AtClient
Procedure Email(Command)
	
	If Not CheckLeadSelected() Then
		Return;
	EndIf;
	
	If Items.FormList.Check Then
		SelectedLead = Items.List.CurrentData.Ref;
	Else
		SelectedLead = Items.Planner.SelectedItems[0].Value;
	EndIf;
	
	CreateEventWithContact("Email", SelectedLead);
	
EndProcedure

&AtClient
Procedure SMS(Command)
	
	If Not CheckLeadSelected() Then
		Return;
	EndIf;
	
	If Items.FormList.Check Then
		SelectedLead = Items.List.CurrentData.Ref;
	Else
		SelectedLead = Items.Planner.SelectedItems[0].Value;
	EndIf;
	
	CreateEventWithContact("SMS", SelectedLead);
	
EndProcedure

&AtClient
Procedure PersonalMeeting(Command)
	
	If Not CheckLeadSelected() Then
		Return;
	EndIf;
	
	If Items.FormList.Check Then
		SelectedLead = Items.List.CurrentData.Ref;
	Else
		SelectedLead = Items.Planner.SelectedItems[0].Value;
	EndIf;
	
	CreateEventWithContact("PersonalMeeting", SelectedLead);
	
EndProcedure

&AtClient
Procedure Other(Command)
	
	If Not CheckLeadSelected() Then
		Return;
	EndIf;
	
	If Items.FormList.Check Then
		SelectedLead = Items.List.CurrentData.Ref;
	Else
		SelectedLead = Items.Planner.SelectedItems[0].Value;
	EndIf;
	
	CreateEventWithContact("Other", SelectedLead);
	
EndProcedure

&AtClient
Procedure DataImportFromExternalSources(Command)
	
	NotifyDescription = New NotifyDescription("ImportDataFromExternalSourceResultDataProcessor", ThisObject, DataLoadSettings);
	
	DataLoadSettings.Insert("TemplateNameWithTemplate",	"LoadFromFile");
	DataLoadSettings.Insert("SelectionRowDescription",	New Structure("FullMetadataObjectName, Type", "Leads", "AppliedImport"));
	
	DataImportFromExternalSourcesClient.ShowDataImportFormFromExternalSource(DataLoadSettings, NotifyDescription, ThisObject);
	
EndProcedure

&AtClient
Procedure ChangeSelected(Command)
	
	GroupObjectsChangeClient.ChangeSelected(Items.List);
	
EndProcedure

&AtClient
Procedure ChangeCampaign(Command)
	
	ClosedLeads = False;
	
	If Not CheckLeadsSelected() Then
		Return;
	EndIf;
	
	ChangedLeads.Clear();
	FillChangedLeads(ClosedLeads);
	
	If ChangedLeads.Count() = 0 Then
		Return;
	EndIf;
	
	If ClosedLeads Then
		CommonUseClientServer.MessageToUser(NStr("en = 'You can''t change finalized leads'"));
		Return;
	EndIf;
	
	OpenForm("Catalog.Campaigns.ChoiceForm", , ThisObject);
	
EndProcedure

&AtClient
Procedure ChangeActivity(Command)
	
	SelectedCampaign = PredefinedValue("Catalog.Campaigns.EmptyRef");
	ClosedLeads = False;
	
	If Not CheckLeadsSelected() Then
		Return;
	EndIf;
	
	ChangedLeads.Clear();
	FillChangedLeads(ClosedLeads);
	
	If ChangedLeads.Count() = 0 Then
		Return;
	EndIf;
	
	If ClosedLeads Then
		CommonUseClientServer.MessageToUser(NStr("en = 'You can''t change finalized leads'"));
		Return;
	EndIf;
	
	// Check one campaign
	If Items.FormKanban.Check Then
		SelectedCampaign = FilterCampaign;
	EndIf;
	
	If Items.FormList.Check Then
		SelectedCampaign = Items.List.RowData(ChangedLeads[0].Lead).Campaign;
		For Each ChangedValue In ChangedLeads Do
			If Items.List.RowData(ChangedValue.Lead).Campaign <> SelectedCampaign Then
				CommonUseClientServer.MessageToUser(NStr("en = 'To change current activity the leads should be of the same campaign'"));
				Return;
			EndIf;
		EndDo;
	EndIf;

	ListOfActivities = GetAvailableActivities(SelectedCampaign);
	Notification = New NotifyDescription("AfterActivitiesSelection", ThisForm, SelectedCampaign);
	ListOfActivities.ShowChooseItem(Notification, NStr("en = 'Select new activity.'"));
	
EndProcedure

&AtClient
Procedure ChangeSalesRep(Command)
	
	ClosedLeads = False;
	
	If Not CheckLeadsSelected() Then
		Return;
	EndIf;
	
	ChangedLeads.Clear();
	FillChangedLeads(ClosedLeads);
	
	If ChangedLeads.Count() = 0 Then
		Return;
	EndIf;
	
	If ClosedLeads Then
		CommonUseClientServer.MessageToUser(NStr("en = 'You can''t change finalized leads'"));
		Return;
	EndIf;
	
	OpenForm("Catalog.Employees.ChoiceForm", , ThisObject);

EndProcedure

#EndRegion

#Region Private

#Region ServiceProceduresAndFunctions

&AtClient
Procedure ConvertIntoCustomerClickEnd(Response, Parameter) Export
	
	If Response.Value = DialogReturnCode.Cancel Then
		Return;
	EndIf;
	
	If Response.DontAskAgain Then
		SetUserSettingAtServer(True, "ConvertLeadWithoutMessage");
	EndIf;
	
	If CheckLeadsSelected() Then
		
		If Items.FormList.Check Then
			DraggedLead = Items.List.CurrentData.Ref;
		Else
			DraggedLead = Items.Planner.SelectedItems[0].Value;
		EndIf;
		
		If ValueIsFilled(DraggedLead) AND CanBeTransferredToClient(DraggedLead) Then
			
			Counterparty = ConvertIntoCustomerAtServer(DraggedLead);
			
			If ValueIsFilled(Counterparty) Then
				
				NotifyChanged(DraggedLead);
				Notify("Write_Lead", DraggedLead);
				
				FormParameters = New Structure("Key", Counterparty);
				OpenForm("Catalog.Counterparties.ObjectForm", FormParameters);
				
			EndIf;
			
		EndIf;
		
	EndIf;

EndProcedure

&AtServerNoContext
Procedure SetUserSettingAtServer(SettingValue, SettingName)
	DriveServer.SetUserSetting(SettingValue, SettingName, Users.CurrentUser());
EndProcedure

&AtClient
Procedure FillChangedLeads(ClosedLeads)
	
	If Items.FormKanban.Check Then
		
		For Each Lead In Items.Planner.SelectedItems Do
			
			If NOT ValueIsFilled(Lead.Value) Then
				Continue;
			EndIf;
			
			NewChangedLead = ChangedLeads.Add();
			NewChangedLead.Lead = Lead.Value;
			
		EndDo;
		
	EndIf;
	
	If Items.FormList.Check Then
		
		For Each Lead In Items.List.SelectedRows Do
			
			If NOT ValueIsFilled(Lead) Then
				Continue;
			EndIf;
			
			NewChangedLead = ChangedLeads.Add();
			NewChangedLead.Lead = Lead;
			
			If Items.ClosureResult.Visible Then
				RowDataLead = Items.List.RowData(Lead);
				If ValueIsFilled(RowDataLead.ClosureResult) Then
					ClosedLeads = True;
					Break;
				EndIf;
			EndIf;
			
		EndDo;
		
	EndIf;
	
EndProcedure

&AtClient
Function CheckLeadsSelected()
	
	Result = True;
	
	If Items.FormKanban.Check
		AND (TypeOf(Items.Planner.SelectedItems) <> Type("FixedArray")
			OR Items.Planner.SelectedItems.Count() = 0) Then
		
		Result = False;
		
	ElsIf Items.FormList.Check
		AND (Items.List.CurrentData = Undefined
			OR TypeOf(Items.List.SelectedRows) <> Type("Array")
			OR Items.List.SelectedRows.Count() = 0) Then
			
		Result = False;
		
	EndIf;
	
	If Not Result Then
		
		CommonUseClientServer.MessageToUser(NStr("en = 'No leads selected'"));
		
	EndIf;
	
	Return Result;
	
EndFunction

&AtClient
Function CheckLeadSelected()
	
	Result = True;
	
	If Items.FormKanban.Check
		AND (TypeOf(Items.Planner.SelectedItems) <> Type("FixedArray")
			OR Items.Planner.SelectedItems.Count() = 0) Then
		
		Result = False;
		
	ElsIf Items.FormList.Check
		AND (Items.List.CurrentData = Undefined
			OR Not ValueIsFilled(Items.List.CurrentData.Ref)) Then
		
		Result = False;
		
	EndIf;
	
	If Not Result Then
		
		CommonUseClientServer.MessageToUser(NStr("en = 'No lead selected'"));
		
	EndIf;
	
	Return Result;
	
EndFunction

&AtClient
Procedure HandleActivateListRow()
	
	RefreshContactInformationPanelServer();
	
EndProcedure

&AtServer
Function CounterpartyRef(SelectedRow)
	
	Return SelectedRow.Counterparty;
	
EndFunction

&AtServer
Function ConvertIntoCustomerAtServer(DraggedItem)
	
	ObjectLead = DraggedItem.GetObject();
	
	NewCounterparty = Catalogs.Leads.GetCreateCounterparty(ObjectLead);
	
	If Items.FormKanban.Check Then
		UpdatePlannerItems("Drag");
	EndIf;
	
	Return NewCounterparty;
	
EndFunction

&AtServer
Procedure ConverIntoRejectedLeadAtServer(RejectedLeadData)
	
	For Each RejectedLead In ChangedLeads Do
		
		Try
			
			DraggedLead = RejectedLead.Lead.GetObject();
			
			DraggedLead.ClosureDate = CurrentSessionDate();
			DraggedLead.ClosureResult = Enums.LeadClosureResult.Rejected;
			DraggedLead.RejectionReason = RejectedLeadData.RejectionReason;
			DraggedLead.ClosureNote = RejectedLeadData.ClosureNote;
			
			DraggedLead.Write();
			
		Except
			CommonUseClientServer.MessageToUser(BriefErrorDescription(ErrorInfo()), RejectedLead);
			Continue;
		EndTry;
		
	EndDo;
	
	If Items.FormKanban.Check Then
		UpdatePlannerItems("Drag");
	EndIf;
	
EndProcedure

&AtServer
Procedure SetConditionalAppearanceInCampaignsColorsAtServer()
	
	WorkWithLeads.SetConditionalAppearanceInCampaignsColors(List.SettingsComposer.Settings.ConditionalAppearance);
	
EndProcedure

&AtServer
Procedure MoveUpDownAtServer(Lead, Activity, Operation)
	
	LeadsData = New Structure();
	LeadsData.Insert("FirstLeadRef", Lead);
	
	FirstLeadOrder = MovableItemOrder(Lead);
	LeadsData.Insert("FirstLeadOrder", FirstLeadOrder);
	
	Query = New Query;
	Query.Text = "SELECT ALLOWED TOP 1
	|	LeadKanban.Lead AS Lead,
	|	LeadKanban.Order AS Order
	|FROM
	|	InformationRegister.LeadKanban AS LeadKanban
	|WHERE
	|	LeadKanban.Activity = &Activity
	|	AND LeadKanban.Campaign = &Campaign";
	
	If Operation = "MoveDown" Then
		Query.Text = Query.Text + Chars.LF + "AND LeadKanban.Order > &Order ORDER BY LeadKanban.Order";
	ElsIf Operation = "MoveUp" Then
		Query.Text = Query.Text + Chars.LF + "AND LeadKanban.Order < &Order ORDER BY LeadKanban.Order DESC";
	EndIf;
	
	Query.SetParameter("Order", FirstLeadOrder);
	Query.SetParameter("Activity", Activity);
	Query.SetParameter("Campaign", FilterCampaign);
	
	Result = Query.Execute();
	
	If Not Result.IsEmpty() Then
		
		Selection = Result.Select();
		
		If Selection.Next() Then
			LeadsData.Insert("SecondLeadRef", Selection.Lead);
			LeadsData.Insert("SecontLeadOrder", Selection.Order);
		EndIf;
		
		LeadsData.Insert("Activity", Activity);
		LeadsData.Insert("Campaign", FilterCampaign);
		InformationRegisters.LeadKanban.ChangeLeadOrder(LeadsData);
		
		UpdatePlannerItems("Drag");
		
	EndIf;
	
EndProcedure

&AtServer
Procedure FormManagement()
	
	CanBeEdited = AccessRight("Edit", Metadata.Catalogs.Leads);
	FilterItems = CommonUseClientServer.FindFilterItemsAndGroups(List.SettingsComposer.Settings.Filter, "ClosureResult");
	NoSelectionSet = FilterItems.Count() = 0
		OR (TypeOf(FilterItems[0].RightValue) = Type("Array")
			AND (FilterItems[0].RightValue.Count() = 0
				OR (FilterItems[0].RightValue.Count() <> 0 AND NOT ValueIsFilled(FilterItems[0].RightValue[0]))));
	
	Items.CreateKanban.Visible = CanBeEdited AND Items.FormKanban.Check;
	
	If CanBeEdited Then
		Items.Create.Visible = Items.FormList.Check;
		Items.Copy.Visible = Items.FormList.Check;
		Items.CommonCommandSetReminder.Visible = Items.FormList.Check;
	EndIf;
	
	Items.PlannerContextMenuGroupClosure.Visible = CanBeEdited;
	Items.PlannerContextMenuGroupMoving.Visible = CanBeEdited;
	
	Items.ListContextMenuGroupLeadClosure.Visible = NoSelectionSet AND CanBeEdited;
	Items.FormGroupLeadClosure.Visible = NoSelectionSet AND CanBeEdited;
	
	Items.LeadClosure.Visible = Items.FormKanban.Check;
	Items.LeadClosure.Enabled = CanBeEdited;
	
	Items.Planner.Visible = Items.FormKanban.Check;
	Items.FilterSearch.Visible = Items.FormKanban.Check;
	Items.FormUpdateKanban.Visible = Items.FormKanban.Check;
	Items.FilterCampaign.AutoMarkIncomplete = Items.FormKanban.Check;
	Items.FilterCampaign.MarkIncomplete = Items.FormKanban.Check;
	
	Items.List.Visible = Items.FormList.Check;
	Items.Result.Visible = Items.FormList.Check;
	Items.SearchGroup.Visible = Items.FormList.Check;
	Items.FormGroupCommandsList.Visible = Items.FormList.Check;
	
EndProcedure

&AtServer
Procedure MarkFoDeletionBinDragAtServer(Leads)
	
	For Each Lead In Leads Do
		
		If NOT ValueIsFilled(Lead) Then
			Continue;
		EndIf;
		
		ObjectLead = Lead.Ref.GetObject();
		ObjectLead.DeletionMark = True;
		ObjectLead.Write();
		
	EndDo;
	
	UpdatePlannerItems("Drag");
	
EndProcedure

&AtServer
Function CanBeTransferredToClient(Lead)
	
	CanBeTransferredToClient = True;
	
	ObjectLead = Lead.GetObject();
	
	If NOT ObjectLead.CheckFilling() Then
		CanBeTransferredToClient = False;
	EndIf;
	
	Return CanBeTransferredToClient;
		
EndFunction

&AtClient
Procedure CreateEventWithContact(EventTypeName, Lead)
	
	FillingValues = New Structure;
	FillingValues.Insert("EventType", PredefinedValue("Enum.EventTypes." + EventTypeName));
	FillingValues.Insert("Lead", Lead);
	
	FormParameters = New Structure;
	FormParameters.Insert("FillingValues", FillingValues);
	
	OpenForm("Document.Event.ObjectForm", FormParameters, ThisObject);
	
EndProcedure

&AtServer
Procedure SetConditionalAppearanceAndUpdateActivityCommands()
	
	SetConditionalAppearanceInCampaignsColorsAtServer();
	
EndProcedure

&AtClient
Procedure DoAfterCloseRejectedLead(Result, AdditionalParameters) Export
	
	If Result = Undefined Then
		Return;
	EndIf;
	
	ConverIntoRejectedLeadAtServer(Result);
	
	LeadsArray = New Array;
	For Each Lead In ChangedLeads Do
		LeadsArray.Add(Lead.Lead);
	EndDo;
	Notify("Write_Lead", LeadsArray);
	
	ChangedLeads.Clear();
	
EndProcedure

&AtServerNoContext
Function GetAvailableActivities(Campaign)
	
	Return WorkWithLeads.GetAvailableActivities(Campaign);
	
EndFunction

&AtClient
Procedure AfterActivitiesSelection(SelectedActivity, SelectedCampaign) Export
	
	If SelectedActivity <> Undefined Then
		
		SelectedValue = SelectedActivity.Value;
		LeadsArray = New Array;
		For Each ChangedLead In ChangedLeads Do
			ChangeLeadStateAtServer(ChangedLead.Lead, SelectedCampaign, , SelectedValue);
			LeadsArray.Add(ChangedLead.Lead);
		EndDo;
		
		Notify("Write_Lead", LeadsArray);
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Procedure ChangeLeadStateAtServer(Lead, Campaign = Undefined, SalesRep = Undefined, Activity = Undefined)
	
	LeadState = WorkWithLeads.LeadState(Lead);
	
	If Campaign <> Undefined Then
		LeadState.Campaign = Campaign;
	EndIf;
	
	If SalesRep <> Undefined Then
		LeadState.SalesRep = SalesRep;
	EndIf;
	
	If Activity <> Undefined Then
		LeadState.Activity = Activity;
	EndIf;
	
	If Not ValueIsFilled(LeadState.Activity) Then
		LeadState.Activity = Catalogs.Campaigns.GetFirstActivity(LeadState.Campaign);
	EndIf;
	
	ObjectLead = Lead.GetObject();
	ObjectLead.AdditionalProperties.Insert("NewState", LeadState);
	ObjectLead.AdditionalProperties.Insert("ActivityHasChanged", True);
	ObjectLead.Write();
	
EndProcedure

#EndRegion

#Region FilterLabel

&AtServer
Procedure SetLabelAndListFilter(ListFilterFieldName, GroupLabelParent, SelectedValue, ValuePresentation = "")
	
	If ValuePresentation = "" Then
		ValuePresentation = String(SelectedValue);
	EndIf;
	
	WorkWithFilters.AttachFilterLabel(ThisObject, ListFilterFieldName, GroupLabelParent, SelectedValue, ValuePresentation);
	WorkWithFilters.SetListFilter(ThisObject, List, ListFilterFieldName,,True);
	
	If Items.FormKanban.Check Then
		If ListFilterFieldName = "Activity" Then
			UpdatePlannerItemsAndDimensions();
		Else
			UpdatePlannerItems("Creation");
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure Attachable_LabelURLProcessing(Item, URLFS, StandardProcessing)
	
	StandardProcessing = False;
		
	LabelID = Mid(Item.Name, StrLen("Label_") + 1);
	DeleteFilterLabel(LabelID);
	
EndProcedure

&AtServer
Procedure DeleteFilterLabel(LabelID)
	
	WorkWithFilters.DeleteFilterLabelServer(ThisObject, List, LabelID);
	
	If Items.FormKanban.Check Then
		UpdatePlannerItemsAndDimensions();
		CurrentItem = Items.Planner;
	EndIf;
	SetFilterByResult();
	
EndProcedure

&AtServer
Function FilterOptionForSetting()
	
	FormFiltersOption = "";

	Return FormFiltersOption;
	
EndFunction

&AtServer
Procedure SaveFilterSettings()
	
	FormFiltersOption = FilterOptionForSetting();
	WorkWithFilters.SaveFilterSettings(ThisObject,,,FormFiltersOption);
	
	CommonUse.CommonSettingsStorageSave("Filter", "FilterCampaign", FilterCampaign);
	CommonUse.CommonSettingsStorageSave("ViewType", "ViewType_LeadsList", ?(Items.FormList.Check, "List", "Kanban"));
	
EndProcedure

&AtServer
Procedure SetFilterByResult()
	
	CanBeEdited = AccessRight("Edit", Metadata.Catalogs.Leads);
	
	FilterItems = CommonUseClientServer.FindFilterItemsAndGroups(List.SettingsComposer.Settings.Filter, "ClosureResult");
	FirstItem = ?(FilterItems.Count() = 0, Undefined, FilterItems[0]);
	NoSelectionSet = FilterItems.Count() = 0 OR (TypeOf(FirstItem.RightValue) = Type("Array") AND FirstItem.RightValue.Count() = 0);
	IsSelectionSet = Not NoSelectionSet
		AND FilterItems.Count() <> 0
		AND TypeOf(FirstItem.RightValue) = Type("Array")
		AND FirstItem.RightValue.Count() <> 0;
	
	SelectionByActive = IsSelectionSet
		AND FirstItem.RightValue[0] = Enums.LeadClosureResult.EmptyRef();
	
	SelectionByConvertedIntoCustomer = IsSelectionSet 
		AND FirstItem.RightValue[0] = Enums.LeadClosureResult.ConvertedIntoCustomer;
		
	SelectionByRejected = IsSelectionSet
		AND FirstItem.RightValue[0] = Enums.LeadClosureResult.Rejected;
	
	Items.Counterparty.Visible = SelectionByConvertedIntoCustomer OR NoSelectionSet;
	Items.ClosureResult.Visible = SelectionByRejected OR SelectionByConvertedIntoCustomer OR NoSelectionSet;
	Items.RejectionReason.Visible = SelectionByRejected OR NoSelectionSet;
	
	Items.ListContextMenuGroupLeadClosure.Visible = (NoSelectionSet OR SelectionByActive) AND CanBeEdited;
	Items.FormGroupLeadClosure.Visible = Items.ListContextMenuGroupLeadClosure.Visible;
	
	Items.GroupChangeItems.Visible = (NoSelectionSet OR SelectionByActive) AND CanBeEdited;
	
	If SelectionByActive OR SelectionByConvertedIntoCustomer OR SelectionByRejected Then
		
		DriveClientServer.SetListFilterItem(List, "DeletionMark", False, , DataCompositionComparisonType.Equal);
		
	Else
		
		DriveClientServer.DeleteListFilterItem(List, "DeletionMark");
		
	EndIf;
	
EndProcedure

#EndRegion

#Region Kanban

&AtServer
Procedure UpdatePlannerDimensions()
	
	HeaderFont = New Font(StyleFonts.NormalTextFont, , , True);
	PlannerDimensions = Planner.Dimensions;
	PlannerDimensions.Clear();
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	CampaignsActivities.Activity AS Activity,
		|	CampaignsActivities.HighlightColor AS HighlightColor
		|FROM
		|	Catalog.Campaigns.Activities AS CampaignsActivities
		|WHERE
		|	CampaignsActivities.Ref = &Campaign
		|	AND &ActivityFilter";
		
	FilterItems = CommonUseClientServer.FindFilterItemsAndGroups(List.SettingsComposer.Settings.Filter, "Activity");
	If FilterItems.Count() <> 0
		AND TypeOf(FilterItems[0].RightValue) = Type("Array")
		AND FilterItems[0].RightValue.Count() <> 0 Then
		Query.Text = StrReplace(Query.Text, "&ActivityFilter", "Activity IN (&Activities)");
		Query.SetParameter("Activities", FilterItems[0].RightValue);
	Else
		Query.SetParameter("ActivityFilter", True);
	EndIf;
	
	Query.SetParameter("Campaign", FilterCampaign);
	Result = Query.Execute();
	
	Selection = Result.Select();
	
	ActivityDimension = PlannerDimensions.Add("LeadActivities");
	
	While Selection.Next() Do
		
		NewActivity = ActivityDimension.Items.Add(Selection.Activity);
		Color = Selection.HighlightColor.Get();
		
		If Color = Undefined Then
			Color = StyleColors.FieldTextColor;
		EndIf;
		
		NewActivity.TextColor = Color;
		NewActivity.Font = HeaderFont;
		NewActivity.Text = " ";
		
	EndDo;
	
EndProcedure

&AtServer
Procedure UpdatePlannerItemsDrag(DragParameters)
	
	LeadsKanban = New Structure;
	LeadsKanban.Insert("Operation", "DragLead");
	
	If DragParameters.MoveToTheTop Then
		LeadsKanban.Insert("Order", 0);
	ElsIf DragParameters.MoveToTheEnd OR DragParameters.DragAndDropLead = Undefined Then
		LeadsKanban.Insert("Order", Undefined);
	Else
		LeadsKanban.Insert("Order", MovableItemOrder(DragParameters.DragAndDropLead));
	EndIf;
	
	For Each Lead In DragParameters.DragAndDropLeads Do
		
		OldState = WorkWithLeads.LeadState(Lead.Ref);
		
		NewState = New Structure();
		NewState.Insert("Campaign", FilterCampaign);
		NewState.Insert("SalesRep", OldState.SalesRep);
		NewState.Insert("Activity", DragParameters.Activity);
		
		ObjectLead = Lead.Ref.GetObject();
		
		ObjectLead.AdditionalProperties.Insert("NewState", NewState);
		ObjectLead.AdditionalProperties.Insert("ActivityHasChanged", OldState.Activity <> DragParameters.Activity);
		
		If DragParameters.DragAndDropLeads.Count() = 1 Then
			ObjectLead.AdditionalProperties.Insert("LeadsKanban", LeadsKanban);
		Else
			ObjectLead.AdditionalProperties.Insert("DoNotWriteToRegister", True);
		EndIf;
		
		ObjectLead.Write();
		
		If DragParameters.MoveToTheEnd
			OR DragParameters.DragAndDropLeads = Undefined
			OR DragParameters.MoveToTheTop Then
			
			Rows = FirstLastItemKanban.FindRows(New Structure("Activity", DragParameters.Activity));
			If Rows.Count() > 0 Then
				Rows[0].Count = Rows[0].Count + 1;
			EndIf;
			UpdateTableFirstLastItemKanban(ObjectLead, DragParameters.Activity, DragParameters.MoveToTheTop);
			
		EndIf;
		
	EndDo;
	
	If DragParameters.DragAndDropLeads.Count() > 1 Then
		InformationRegisters.LeadKanban.DragLeads(
			FilterCampaign,
			DragParameters.Activity,
			DragParameters.DragAndDropLeads,
			LeadsKanban.Order);
	EndIf;
	UpdatePlannerItems("Drag");
	
	// If there are no items left on the current screen while dragging, return to the previous screen
	If NumberOfStatesWithoutDisplayedItems = Planner.Dimensions[0].Items.Count() Then
		CurrentDisplayKanban = CurrentDisplayKanban - 1;
		UpdatePlannerItems("Scroll", "ScrollBackward");
	EndIf;
	
EndProcedure

&AtServer
Procedure UpdatePlannerItems(Operation, ScrollDirection = Undefined)
	
	KanbanCardWidth = 2;
	PanelWidthKanban = 1;
	NumberOfItemsToDisplayCanban = 14;
	FirstItemKanban = BegOfDay(CurrentSessionDate());
	DisplayEndKanban = FirstItemKanban
		+ NumberOfItemsToDisplayCanban * KanbanCardWidth
		+ PanelWidthKanban;
	MaxItemKanban = FirstItemKanban;
	Planner.CurrentRepresentationPeriods.Clear();
	Planner.CurrentRepresentationPeriods.Add(FirstItemKanban, DisplayEndKanban);
	PlannerItems = Planner.Items;
	PlannerItems.Clear();
	CIDataKanban.Clear();
	
	FilterStringKanban = FilterStringKanban();
	ItemsCountInStateKanban = ItemsCountInStateKanban();
	NumberOfStatesWithoutDisplayedItems = 0;
	
	For Each Activity In Planner.Dimensions[0].Items Do
		
		BackColor = ?(Activity.TextColor = New Color(0, 0, 0), StyleColors.WorktimeFreeAvailable, Activity.TextColor);
		
		LeadCountInActivity = ItemsCountInStateKanban.Find(Activity.Value, "Activity");
		
		// Item to top
		NewItem = AddNewItemKanban(FirstItemKanban,
			FirstItemKanban + 1,
			Catalogs.Leads.EmptyRef(),
			Activity);
		NewItem.Text = String(Activity.Value);
		NewItem.BackColor = BackColor;
		NewItem.Font = New Font(StyleFonts.NormalTextFont,,, True);
		
		// Item to end
		NewItem = AddNewItemKanban(DisplayEndKanban,
			DisplayEndKanban + 1,
			Catalogs.Leads.EmptyRef(),
			Activity);
		StrTotal = NStr("en = 'Total: %1'");
		NewItem.Text = StringFunctionsClientServer.SubstituteParametersInString(
			StrTotal,
			?(LeadCountInActivity = Undefined, NStr("en = '0'"), String(LeadCountInActivity.Count)));
		NewItem.BackColor = BackColor;
		NewItem.Font = New Font(StyleFonts.NormalTextFont,,, True);
		
		FirstLastRows = FirstLastItemKanban.FindRows(New Structure("Activity", Activity.Value));
		FirstRow = ?(FirstLastRows.Count() > 0, FirstLastRows[0], Undefined);
		
		If FirstLastRows.Count() = 0 Then
			NewLine = FirstLastItemKanban.Add();
			NewLine.Activity = Activity.Value;
			FirstLastRows.Add(NewLine);
			FirstRow =NewLine;
		EndIf;
		If Operation = "Creation" OR CurrentDisplayKanban = 0 Then
			FirstRow.FirstItemOrder = 0;
			CurrentDisplayKanban = 0;
		EndIf;
		
		If LeadCountInActivity = Undefined 
			OR LeadCountInActivity.Count < (CurrentDisplayKanban * NumberOfItemsToDisplayCanban - (CurrentDisplayKanban - 1))  Then
			NumberOfStatesWithoutDisplayedItems = NumberOfStatesWithoutDisplayedItems + 1;
			Continue;
		EndIf;
		
		FirstRow.Count = LeadCountInActivity.Count;
		
		Query = New Query;
		Query.Text = QueryTextKanban(Operation,
			ScrollDirection,
			?(LeadCountInActivity.Count <= ((CurrentDisplayKanban + 1) * NumberOfItemsToDisplayCanban - CurrentDisplayKanban),
				LeadCountInActivity.Count - (CurrentDisplayKanban * NumberOfItemsToDisplayCanban - CurrentDisplayKanban),
				NumberOfItemsToDisplayCanban));
		Query.SetParameter("Activity", Activity.Value);
		Query.SetParameter("Campaign", FilterCampaign);
		
		If Operation = "Creation" OR Operation = "Drag" Then
			OrderParam = FirstRow.FirstItemOrder;
		ElsIf Operation = "Scroll" AND ScrollDirection = "ScrollForward" Then
			OrderParam = FirstRow.LastItemOrder;
		Else
			CurCount = (CurrentDisplayKanban + 1) * NumberOfItemsToDisplayCanban - CurrentDisplayKanban;
			OrderParam = ?(LeadCountInActivity.Count <= CurCount,
				FirstRow.LastItemOrder,
				FirstRow.FirstItemOrder);
		EndIf;
		Query.SetParameter("Order", OrderParam);
		
		SetFiltersParametres(Query);
		Result = Query.Execute();
		Selection  = Result.Select();
		
		If Selection.Count() = 0 Then
			Continue;
		EndIf;
		
		LineIndex = 0;
		
		While Selection.Next() Do
			
			If Operation = "Scroll" AND ScrollDirection = "ScrollBackward" Then
				ItemEnd = FirstItemKanban
					+ ((Selection.Count() * KanbanCardWidth)
					+ PanelWidthKanban
					- LineIndex);
				ItemStart = ItemEnd - KanbanCardWidth;
				If LineIndex = 0 Then
					FirstRow.LastItemOrder = Selection.Order;
					FirstRow.EndOfLastItem = ItemEnd;
				Else
					FirstRow.FirstItemOrder = Selection.Order;
				EndIf;
			Else
				ItemStart = FirstItemKanban + PanelWidthKanban + LineIndex;
				ItemEnd = ItemStart + KanbanCardWidth;
				If LineIndex = 0 Then
					FirstRow.FirstItemOrder = Selection.Order;
				Else
					FirstRow.LastItemOrder = Selection.Order;
					FirstRow.EndOfLastItem = ItemEnd;
				EndIf;
			EndIf;
			
			NewItem = AddNewItemKanban(ItemStart,
				ItemEnd,
				Selection.Lead,
				Activity);
			NewItem.Text = KanbanLeadPresentation(Selection);
			NewItem.BackColor = BackColor;
			NewItem.Font = New Font(StyleFonts.NormalTextFont,,, False);
		
			If ItemEnd > MaxItemKanban Then
				MaxItemKanban = ItemEnd;
			EndIf;
			LineIndex = LineIndex + KanbanCardWidth;
		EndDo;
	EndDo;
	
EndProcedure

&AtServer
Procedure UpdatePlannerItemsAndDimensions(Operation = "Creation")
	
	UpdatePlannerDimensions();
	UpdatePlannerItems(Operation);
	FormManagement();
	
EndProcedure

&AtServer
Function QueryTextKanban(Operation, ScrollDirection, Count = 14)
	
	If Operation = "Scroll" AND ScrollDirection = "ScrollBackward" Then
		Text = "SELECT
		|	LeadActivitiesSliceLast.Lead AS Lead,
		|	LeadActivitiesSliceLast.SalesRep AS SalesRep
		|INTO LeadReps
		|FROM
		|	InformationRegister.LeadActivities.SliceLast AS LeadActivitiesSliceLast
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED TOP 14
		|	LeadKanban.Activity AS Activity,
		|	LeadKanban.Lead AS Lead,
		|	LeadKanban.Order AS Order,
		|	Leads.Description AS Description,
		|	Leads.Contacts.(
		|		Representation AS Representation,
		|		ContactLineIdentifier AS ContactLineIdentifier
		|	) AS Contacts,
		|	Leads.ContactInformation.(
		|		Type AS Type,
		|		Kind AS Kind,
		|		Presentation AS Presentation,
		|		FieldValues AS FieldValues,
		|		ContactLineIdentifier AS ContactLineIdentifier
		|	) AS ContactInformation,
		|	Leads.Tags.(
		|		Tag AS Tag
		|	) AS Tags,
		|	Leads.Note AS Note,
		|	Leads.Created AS Created,
		|	LeadReps.SalesRep AS SalesRep
		|FROM
		|	InformationRegister.LeadKanban AS LeadKanban
		|		INNER JOIN Catalog.Leads AS Leads
		|		ON LeadKanban.Lead = Leads.Ref
		|		INNER JOIN LeadReps AS LeadReps
		|		ON LeadKanban.Lead = LeadReps.Lead
		|WHERE
		|	LeadKanban.Activity = &Activity
		|	AND NOT Leads.DeletionMark
		|	AND LeadKanban.Order <= &Order
		|	AND LeadKanban.Campaign = &Campaign
		|	AND &FilterStringKanban
		|	ORDER BY Order DESC";
		
		Text = StrReplace(Text, "14", Count);
	Else
		Text = "SELECT
		|	LeadActivitiesSliceLast.Lead AS Lead,
		|	LeadActivitiesSliceLast.SalesRep AS SalesRep
		|INTO LeadsReps
		|FROM
		|	InformationRegister.LeadActivities.SliceLast AS LeadActivitiesSliceLast
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED TOP 14
		|	LeadKanban.Activity AS Activity,
		|	LeadKanban.Lead AS Lead,
		|	LeadKanban.Order AS Order,
		|	Leads.Description AS Description,
		|	Leads.Contacts.(
		|		Representation AS Representation,
		|		ContactLineIdentifier AS ContactLineIdentifier
		|	) AS Contacts,
		|	Leads.ContactInformation.(
		|		Type AS Type,
		|		Kind AS Kind,
		|		Presentation AS Presentation,
		|		FieldValues AS FieldValues,
		|		ContactLineIdentifier AS ContactLineIdentifier
		|	) AS ContactInformation,
		|	Leads.Tags.(
		|		Tag AS Tag
		|	) AS Tags,
		|	Leads.Note AS Note,
		|	Leads.Created AS Created,
		|	LeadsReps.SalesRep AS SalesRep
		|FROM
		|	InformationRegister.LeadKanban AS LeadKanban
		|		INNER JOIN Catalog.Leads AS Leads
		|		ON LeadKanban.Lead = Leads.Ref
		|		INNER JOIN LeadsReps AS LeadsReps
		|		ON LeadKanban.Lead = LeadsReps.Lead
		|WHERE
		|	LeadKanban.Activity = &Activity
		|	AND NOT Leads.DeletionMark
		|	AND LeadKanban.Order >= &Order
		|	AND LeadKanban.Campaign = &Campaign
		|	AND &FilterStringKanban
		|	ORDER BY Order";
	EndIf;
	
	If IsBlankString(FilterStringKanban) Then
		Text = StrReplace(Text, "&FilterStringKanban", "TRUE");
	Else
		Text = StrReplace(Text, "AND &FilterStringKanban", FilterStringKanban);
	EndIf;
	
	Return Text;
	
EndFunction

&AtServer
Function FilterStringKanban()
	
	StringsArray = New Array;
	
	For Each FilterItem In List.SettingsComposer.Settings.Filter.Items Do
		
		If Not FilterItem.Use Then
			Continue;
		EndIf;
		
		If FilterItem.Presentation = "Period" Then
			
			If FilterItem.Items.Count() >= 2 Then
				If FilterItem.Items[0].Use AND FilterItem.Items[1].Use Then
					StringsArray.Add(" AND Created >= &BegDate AND Created <= &EndDate");
				EndIf;
			EndIf;
			Continue;
			
		EndIf;
		
		If TypeOf(FilterItem.RightValue) = Type("Array") AND FilterItem.RightValue.Count() = 0 Then
			
			Continue;
			
		EndIf;
		
		If String(FilterItem.LeftValue) = "Tags.Tag" Then
			
			StringsArray.Add(" AND Tags.Tag IN (&Tags) ");
			
		ElsIf String(FilterItem.LeftValue) = "SalesRep" Then
			
			StringsArray.Add(" AND SalesRep IN (&SalesReps) ");
			
		ElsIf String(FilterItem.LeftValue) = "AcquisitionChannel" Then
			
			StringsArray.Add(" AND AcquisitionChannel IN (&AcquisitionChannels) ");
			
		ElsIf String(FilterItem.LeftValue) = "Activity" Then
			
			StringsArray.Add(" AND Activity IN (&Activities) ");
			
		EndIf;
		
	EndDo;
	
	If ValueIsFilled(FilterSearch) Then
		
		StringsArray.Add(" AND BasicInformation LIKE &Search ");
		
	EndIf;
	
	For Each ListFilterItem In List.Filter.Items Do
		
		If ListFilterItem.Use = False Then
			Continue;
		EndIf;
		
	EndDo;
	
	FilterString = StrConcat(StringsArray, Chars.LF);
	
	Return FilterString;
	
EndFunction

&AtServer
Function KanbanLeadPresentation(SelectionLead)
	
	LeadsArray = New Array;
	
	If ValueIsFilled(SelectionLead.Description) Then
		LeadsArray.Add(SelectionLead.Description);
	EndIf;
	
	Contacts = SelectionLead.Contacts.Unload();
	CI = SelectionLead.ContactInformation.Unload();
	
	If Contacts.Count() = 0 Then
		
		// Filling in the table for the contact information panel
		AddMissingDataMessage(SelectionLead.Lead);
		
		// Forming a presentation
		If ValueIsFilled(SelectionLead.Note) Then
			LeadsArray.Add(SelectionLead.Note);
		EndIf;
		
		LeadsArray.Add(Format(SelectionLead.Created + Chars.LF, "DLF=D"));
		LeadTags = SelectionLead.Tags.Unload();
		
		If LeadTags.Count() = 0 Then
			
			Presentation = StrConcat(LeadsArray, Chars.LF);
			Return Presentation;
			
		Else
			
			For Each Tag In LeadTags Do
				LeadsArray.Add(Tag.Tag.Description);
			EndDo;
			
			Presentation = StrConcat(LeadsArray, Chars.LF);
			Return Presentation;
			
		EndIf;
		
	EndIf;
	
	CurrentContact = Undefined;
	
	For Each Contact In Contacts Do
		
		If ValueIsFilled(Contact.Representation) AND Contact.Representation <> SelectionLead.Description Then
			LeadsArray.Add(Contact.Representation);
		EndIf;
		
		If CurrentContact <> Contact.Representation Then
			NewContactItem = CIDataKanban.Add();
			NewContactItem.Representation = Contact.Representation;
			NewContactItem.IconIndex = -1;
			NewContactItem.TypeShowingData = "ContactPerson";
			NewContactItem.OwnerCI = Contact.Representation;
			NewContactItem.LeadRef = SelectionLead.Lead;
			CurrentContact = Contact.Representation;
		EndIf;
		
		For Each CILine In CI Do
			If CILine.ContactLineIdentifier <> Contact.ContactLineIdentifier Then
				Continue;
			EndIf;
			LeadsArray.Add(CILine.Presentation);
			If NOT ValueIsFilled(CILine.Type) Then
				Continue;
			EndIf;
			
			NewCIItem = CIDataKanban.Add();
			Comment = ContactInformationManagement.ContactInformationComment(CILine.FieldValues);
			NewCIItem.Representation = String(CILine.Kind) + ": " + CILine.Presentation + ?(IsBlankString(Comment), "", ", " + Comment);
			NewCIItem.IconIndex = ContactInformationPanelDrive.IconIndexByType(CILine.Type);
			NewCIItem.TypeShowingData = "ValueCI";
			NewCIItem.OwnerCI = Contact.Representation;
			NewCIItem.LeadRef = SelectionLead.Lead;
			NewCIItem.PresentationCI = CILine.Presentation;
		EndDo;
		
	EndDo;
	
	If ValueIsFilled(SelectionLead.Note) Then
		LeadsArray.Add(SelectionLead.Note);
	EndIf;
	
	LeadsArray.Add(Format(SelectionLead.Created + Chars.LF, "DLF=D"));
	
	LeadTags = SelectionLead.Tags.Unload();
	
	If LeadTags.Count() = 0 Then
		Presentation = StrConcat(LeadsArray,Chars.LF);
		Return Presentation;
	Else
		For Each Tag In LeadTags Do
			LeadsArray.Add(Tag.Tag.Description);
		EndDo;
	EndIf;
	
	Presentation = StrConcat(LeadsArray,Chars.LF);
	
	Return Presentation;
	
EndFunction

&AtServer
Procedure SetFiltersParametres(Query)
	
	For Each FilterItem In List.SettingsComposer.Settings.Filter.Items Do
		
		If FilterItem = "ClosureResult" OR Not FilterItem.Use Then
			Continue;
		EndIf;
		
		If FilterItem.Presentation = "Period" Then
			If FilterItem.Items.Count() >= 2 Then
				If FilterItem.Items[0].Use AND FilterItem.Items[1].Use Then
					Query.SetParameter("BegDate",FilterItem.Items[0].RightValue);
					Query.SetParameter("EndDate",FilterItem.Items[1].RightValue);
				EndIf;
			EndIf;
			Continue;
		EndIf;
		
		If TypeOf(FilterItem.RightValue) = Type("Array") AND FilterItem.RightValue.Count() = 0 Then
			Continue;
		EndIf;
		
		If String(FilterItem.LeftValue) = "Tags.Tag" Then
			
			Query.SetParameter("Tags",FilterItem.RightValue);
			
		ElsIf String(FilterItem.LeftValue) = "SalesRep" Then
			
			Query.SetParameter("SalesReps",FilterItem.RightValue);
			
		ElsIf String(FilterItem.LeftValue) = "AcquisitionChannel" Then
			
			Query.SetParameter("AcquisitionChannels",FilterItem.RightValue);
			
		ElsIf String(FilterItem.LeftValue) = "Activity" Then
			
			Query.SetParameter("Activities",FilterItem.RightValue);
			
		ElsIf String(FilterItem.LeftValue) = "Campaign" Then
			
			Query.SetParameter("Campaign",FilterItem.RightValue);
			
		EndIf;
		
	EndDo;
	If ValueIsFilled(FilterSearch) Then
		
		Query.SetParameter("Search","%" + FilterSearch + "%");
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OpenCurrentPlannerItemForm()
	
	If Items.Planner.SelectedItems.Count() = 0 Then
		Return;
	EndIf;
	
	ItemValue = Items.Planner.SelectedItems[0].Value;
	
	If ValueIsFilled(ItemValue) AND TypeOf(ItemValue) = Type("CatalogRef.Leads") Then
		FormParameters = New Structure;
		FormParameters.Insert("Key", ItemValue);
		OpenForm("Catalog.Leads.Form.ItemForm", FormParameters, ThisObject);
	EndIf;
	
EndProcedure

&AtServer
Function MovableItemOrder(Lead)
	
	Query = New Query;
	Query.Text = "SELECT ALLOWED TOP 1
	|	LeadKanban.Order AS Order
	|FROM
	|	InformationRegister.LeadKanban AS LeadKanban
	|WHERE
	|	LeadKanban.Lead = &Lead";
	
	Query.SetParameter("Lead", Lead.Ref);
	Result = Query.Execute();
	Selection = Result.Select();
	
	If Selection.Count() = 0 Then
		Return Undefined;
	EndIf;
	
	While Selection.Next() Do
		Return Selection.Order;
	EndDo;
	
EndFunction

&AtServer
Function ItemsCountInStateKanban()
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	Leads.Ref AS Ref,
	|	LeadActivitiesSliceLast.Campaign AS Campaign,
	|	LeadActivitiesSliceLast.SalesRep AS SalesRep,
	|	LeadActivitiesSliceLast.Activity AS Activity,
	|	Leads.AcquisitionChannel AS AcquisitionChannel,
	|	Leads.Counterparty AS Counterparty,
	|	Leads.BasicInformation AS BasicInformation
	|INTO Leads
	|FROM
	|	InformationRegister.LeadActivities.SliceLast AS LeadActivitiesSliceLast
	|		INNER JOIN Catalog.Leads AS Leads
	|		ON LeadActivitiesSliceLast.Lead = Leads.Ref
	|WHERE
	|	NOT Leads.DeletionMark
	|	AND Leads.ClosureDate = DATETIME(1, 1, 1)
	|	AND &FilterStringKanban;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	COUNT(DISTINCT LeadActivitiesSliceLast.Lead) AS Count,
	|	LeadActivitiesSliceLast.Campaign AS Campaign,
	|	LeadActivitiesSliceLast.Activity AS Activity
	|FROM
	|	InformationRegister.LeadActivities.SliceLast(, ) AS LeadActivitiesSliceLast
	|		INNER JOIN Leads AS Leads
	|		ON LeadActivitiesSliceLast.Lead = Leads.Ref
	|WHERE
	|	LeadActivitiesSliceLast.Campaign = &FilterCampaign
	|
	|GROUP BY
	|	LeadActivitiesSliceLast.Campaign,
	|	LeadActivitiesSliceLast.Activity";
	
	If IsBlankString(FilterStringKanban) Then
		Query.SetParameter("FilterStringKanban", True);
	Else
		Query.Text = StrReplace(Query.Text, "AND &FilterStringKanban", FilterStringKanban);
		SetFiltersParametres(Query);
	EndIf;
	Query.SetParameter("FilterCampaign", FilterCampaign);
	ItemsCountInStateKanban = Query.Execute().Unload();
	Return ItemsCountInStateKanban;
	
EndFunction

&AtServer
Function AddNewItemKanban(Beg, End, Value, Activity)
	
	ValueMap = New Map;
	ValueMap.Insert("LeadActivities", Activity.Value);
	
	NewItem = Planner.Items.Add(Beg, End);
	NewItem.DimensionValues = New FixedMap(ValueMap);
	NewItem.Value = Value;
	
	Return NewItem;
	
EndFunction

&AtServer
Procedure UpdateTableFirstLastItemKanban(Lead, Activity, MoveToTheTop)
	
	KanbanRow = FirstLastItemKanban.FindRows(New Structure("Activity", Activity));
	If KanbanRow.Count() > 0 Then
		FirstRow = KanbanRow[0];
		If FirstRow.Count = (CurrentDisplayKanban * NumberOfItemsToDisplayCanban - (CurrentDisplayKanban - 1)) Then
			FirstRow.FirstItemOrder = ?(MoveToTheTop,
				FirstRow.LastItemOrder,
				MovableItemOrder(Lead.Ref));
		Else
			FirstRow.LastItemOrder = MovableItemOrder(Lead.Ref);
		EndIf;
	EndIf;
	
EndProcedure

&AtServer
Procedure GoToActivityEnd(Activity)
	
	LeadCountInActivity = FirstLastItemKanban.FindRows(New Structure("Activity",Activity));
	
	While LeadCountInActivity[0].Count >= ((CurrentDisplayKanban + 1) * NumberOfItemsToDisplayCanban - CurrentDisplayKanban) Do
		
		CurrentDisplayKanban = CurrentDisplayKanban + 1;
		UpdatePlannerItems("Scroll", "ScrollForward")
		
	EndDo;
	
EndProcedure

#EndRegion

#Region ContactInformationPanel

&AtServer
Procedure RefreshContactInformationPanelServer()
	
	Catalogs.Leads.RefreshPanelData(ThisObject, CurrentLead);
	
EndProcedure

&AtClient
Procedure Attachable_ContactInformationPanelDataSelection(Item, SelectedRow, Field, StandardProcessing)
	
	ContactInformationPanelDriveClient.ContactInformationPanelDataSelection(ThisObject, Item, SelectedRow, Field, StandardProcessing);
	
EndProcedure

&AtClient
Procedure Attachable_ContactInformationPanelDataOnActivateRow(Item)
	
	ContactInformationPanelDriveClient.ContactInformationPanelDataOnActivateRow(ThisObject, Item);
	
EndProcedure

&AtClient
Procedure Attachable_ContactInformationPanelDataExecuteCommand(Command)
	
	ContactInformationPanelDriveClient.ExecuteCommand(ThisObject, Command);
	
EndProcedure

&AtClient
Procedure RefreshContactInformationPanelKanban()
	
	LeadData = CIDataKanban.FindRows(New Structure("LeadRef", CurrentLead));
	
	If LeadData.Count() = 0 Then
		
		ThisObject.ContactInformationPanelData.Clear();
		NewLine = ThisObject.ContactInformationPanelData.Add();
		NewLine.Representation = NStr("en = '<No contact information>'");
		NewLine.IconIndex = -1;
		NewLine.TypeShowingData = "NoData";
		NewLine.OwnerCI = "";
		
	Else
	
		ThisObject.ContactInformationPanelData.Clear();
		For Each Line In LeadData Do
			NewLine = ThisObject.ContactInformationPanelData.Add();
			FillPropertyValues(NewLine,Line);
		EndDo;
	
	EndIf;
	
EndProcedure

&AtServer
Procedure AddMissingDataMessage(Lead)
	
	NewLine = CIDataKanban.Add();
	NewLine.Representation = NStr("en = '<No contact information>'");
	NewLine.IconIndex = -1;
	NewLine.TypeShowingData = "NoData";
	NewLine.OwnerCI = "";
	NewLine.LeadRef = Lead;
	
EndProcedure

#EndRegion

#Region ActivitiesChanging

&AtServer
Procedure SetActivityChoiseList(Campaign)
	
	// Clear filter
	DelArray = New Array();
	For Each ChildItem In Items.Activities.ChildItems Do
		If StrFind(ChildItem.Name, "Label_") Then
			LabelID = Mid(ChildItem.Name, StrLen("Label_")+1);
			DelArray.Add(LabelID);
		EndIf;
	EndDo;
	Index = DelArray.Count()-1;
	While Index >= 0 Do
		WorkWithFilters.DeleteFilterLabelServer(ThisObject, List, DelArray[Index]);
		Index = Index - 1;
	EndDo;
	
	// New choice list
	Items.FilterActivity.Enabled = ValueIsFilled(Campaign);
	
	Items.FilterActivity.ChoiceList.Clear();
	ActivitiesChoiceList = GetAvailableActivities(Campaign);
	
	For Each ActivityValue In ActivitiesChoiceList Do
		Items.FilterActivity.ChoiceList.Add(ActivityValue.Value);
	EndDo;
	
EndProcedure

#EndRegion

#Region LibrariesHandlers

&AtClient
Procedure ImportDataFromExternalSourceResultDataProcessor(ImportResult, AdditionalParameters) Export
	
	If TypeOf(ImportResult) = Type("Structure") Then
		ProcessPreparedData(ImportResult);
		ShowMessageBox(,NStr("en = 'Data import is complete.'"));
	EndIf;
	
	Items.List.Refresh();
	
EndProcedure

&AtServer
Procedure ProcessPreparedData(ImportResult)
	
	Catalogs.Leads.ImportDataFromExternalSourceResultDataProcessor(ImportResult);
	
EndProcedure

&AtClient
Procedure Attachable_ExecutePrintCommand(Command)
	
	PrintManagementClient.ExecuteConnectedPrintCommand(Command, ThisObject, Items.List);
	
EndProcedure

#EndRegion

#EndRegion