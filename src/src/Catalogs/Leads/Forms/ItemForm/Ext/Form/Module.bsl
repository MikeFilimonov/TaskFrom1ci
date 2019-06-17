
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Not ValueIsFilled(Object.ClosureDate) Then
		CurrentItem = Items.ContactInformation0_Presentation;
	EndIf;
	
	If Parameters.Key.IsEmpty() Then
		SetFormAttrubitesAtServer();
	EndIf;
	FormManagement();
	
	PropertiesManagement.OnCreateAtServer(ThisObject, Object, "GroupAdditionalAttributes");
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	SetLeadDescription();
	
	DescriptionList = Items.LeadDescription.ChoiceList;
	FirstRep = Object.Contacts[0].Representation;
	
	GenerateDescriptionAutomatically = IsBlankString(Object.Description)
		OR DescriptionList.FindByValue(Object.Description) <> Undefined
		OR (Object.Contacts.Count() > 0
			AND ValueIsFilled(FirstRep)
			AND DescriptionList.FindByValue(FirstRep) = Undefined);
		
	SetActivityChoiseList(Campaign);
		
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If PropertiesManagementClient.ProcessAlerts(ThisObject, EventName, Parameter) Then
		UpdateAdditionalAttributesItems();
	EndIf;
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)

	SetFormAttrubitesAtServer();
	PropertiesManagement.OnReadAtServer(ThisObject, CurrentObject);
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	WriteParameters.Insert("EmptyContactsAtForm", New Array);
	
	LinesToDelete = New Array;
	For Each ContactData In CurrentObject.Contacts Do
		If ValueIsFilled(ContactData.Representation) Then
			Continue;
		EndIf;
		WriteParameters.EmptyContactsAtForm.Add(New Structure("LineIdentifiers", ContactData.ContactLineIdentifier));
		LinesToDelete.Add(ContactData);
	EndDo;
	
	For Each DelLine In LinesToDelete Do
		CurrentObject.Contacts.Delete(DelLine);
	EndDo;
	
	If CurrentObject.IsNew() Then
		WriteParameters.Insert("NewLead", True);
	EndIf;
	
	WriteTagsData(CurrentObject);
	ContactInformationDrive.BeforeWriteAtServer(ThisObject, CurrentObject);
	PropertiesManagement.BeforeWriteAtServer(ThisObject, CurrentObject);
	
	If ActivityHasChanged Then
		CurrentObject.AdditionalProperties.Insert("ActivityHasChanged", ActivityHasChanged);
		NewState = New Structure();
		NewState.Insert("Campaign", Campaign);
		NewState.Insert("SalesRep", SalesRep);
		NewState.Insert("Activity", Activity);
		CurrentObject.AdditionalProperties.Insert("NewState", NewState);
		ActivityHasChanged = False;
	EndIf;

EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	If WriteParameters.Property("NewLead") Then
		NotifyWritingNew(Object.Ref);
	EndIf;
	
	Notify("Write_Lead", Object.Ref);
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	If WriteParameters.Property("EmptyContactsAtForm") Then
		For Each ContactData In WriteParameters.EmptyContactsAtForm Do
			FillPropertyValues(Object.Contacts.Add(), ContactData);
		EndDo;
	EndIf;
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	For Each ContactData In Object.Contacts Do
		
		If ValueIsFilled(ContactData.Representation) Then
			Continue;
		EndIf;
		
		ContactInformationIsFilled = False;
		
		ContactInformationOfContact = ThisObject.ContactInformation.FindRows(New Structure("ContactLineIdentifier", ContactData.ContactLineIdentifier));
		For Each ContactInformation In ContactInformationOfContact Do
			If ValueIsFilled(ContactInformation.Presentation) Then
				ContactInformationIsFilled = True;
				Break;
			EndIf;
		EndDo;
		
		If Not ContactInformationIsFilled Then
			Continue;
		EndIf;
		
		AttributeName = StringFunctionsClientServer.SubstituteParametersInString("ContactInformation%1_Presentation", Object.Contacts.IndexOf(ContactData));
		CommonUseClientServer.MessageToUser(NStr("en = 'Contact name is empty.'"), , AttributeName, , Cancel);
		
	EndDo;
	
	ContactInformationDrive.FillCheckProcessingAtServer(ThisObject, Cancel);
	
	If ValueIsFilled(Campaign) And Not ValueIsFilled(Activity) Then
		CommonUseClientServer.MessageToUser(NStr("en = 'Activity is empty.'"), , "Activity", , Cancel);
	EndIf;
	
	PropertiesManagement.FillCheckProcessing(ThisObject, Cancel, CheckedAttributes);
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure CampaignOnChange(Item)
	
	Activity = GetActivityAtServer(Campaign);
	SetActivityChoiseList(Campaign);
	ActivityHasChanged = True;
	
EndProcedure

&AtClient
Procedure ActivityOnChange(Item)
	
	ActivityHasChanged = True;
	
EndProcedure

&AtClient
Procedure Attachable_Contacts0RepresentationOnChange(Item)
	
	If Item.Name <> "Contacts0_Representation" Then
		Return;
	EndIf;

	SetLeadDescription();
	
	If GenerateDescriptionAutomatically AND Items.LeadDescription.ChoiceList.Count() > 0  Then
		Object.Description = Items.LeadDescription.ChoiceList[0].Value;
	EndIf;
	
EndProcedure

&AtClient
Procedure TagsCloudURLProcessing(Item, FormattedStringURL, StandardProcessing)
	
	StandardProcessing = False;
	
	TagID = Mid(FormattedStringURL, StrLen("Tag_")+1);
	TagsRow = TagsData.FindByID(TagID);
	TagsData.Delete(TagsRow);
	
	RefreshTagsItems();
	
	Modified = True;
	
EndProcedure

&AtClient
Procedure SalesRepOnChange(Item)
	
	ActivityHasChanged = True;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure ConvertIntoCustomer(Command)
	
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
Procedure ConvertIntoRejectedLead(Command)
	
	If ValueIsFilled(Object.Ref) Then
		ConverIntoRejectedLeadAtServer();
		Return;
	EndIf;
	
	Notify = New NotifyDescription("ConvertIntoRejectedLeadClickEnd", ThisObject);
	QuestionText = NStr("en = 'You can convert lead into rejected only after saving. Do you want to save?'");
	ShowQueryBox(Notify, QuestionText, QuestionDialogMode.OKCancel);
	
EndProcedure

&AtClient
Procedure BackToWork(Command)
	
	BackToWorkAtServer();
	
EndProcedure

&AtClient
Procedure AddNewContact(Command)
	
	AddNewContactAtServer();
	
EndProcedure

&AtClient
Procedure AddAdditionalAttributes(Command)
	
	FormParameters = New Structure;
	FormParameters.Insert("CurrentSetOfProperties", PredefinedValue("Catalog.AdditionalAttributesAndInformationSets.Catalog_Leads"));
	FormParameters.Insert("ThisIsAdditionalInformation", False);
	OpenForm("ChartOfCharacteristicTypes.AdditionalAttributesAndInformation.ObjectForm", FormParameters,,,,,, FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

#EndRegion

#Region Private

#Region LeadDescription

&AtClient
Procedure SetLeadDescription()
	
	ChoiceList = Items.LeadDescription.ChoiceList;
	ChoiceList.Clear();
	
	If Object.Contacts.Count() = 0 Then
		Return;
	EndIf;
	
	For Each Contact In Object.Contacts Do
		
		If Not IsBlankString(Contact.Representation) 
			AND ChoiceList.FindByValue(Contact.Representation) = Undefined Then
			ChoiceList.Add(Contact.Representation);
		EndIf;
		
		If Object.ContactInformation.Count() = 0 Then
			Continue;
		EndIf;
		
		For Each ObjectContactInformationLine In Object.ContactInformation Do
			If (ObjectContactInformationLine.ContactLineIdentifier <> Contact.ContactLineIdentifier
				OR IsBlankString(ObjectContactInformationLine.Presentation))
				OR ChoiceList.FindByValue(ObjectContactInformationLine.Presentation) <> Undefined Then
				Continue;
			EndIf;
			ChoiceList.Add(ObjectContactInformationLine.Presentation);
		EndDo;
	
	EndDo;
	
	Items.LeadDescription.ChoiceListButton = ChoiceList.Count() > 0;
	
	AdditionalParameters = New Structure;
	NotifyDescription = New NotifyDescription("AfterSelectionLeadDescription", ThisObject, AdditionalParameters);
	
EndProcedure

&AtClient
Procedure AfterSelectionLeadDescription(SelectedItem, Parameters) Export
	
	Object.Description = SelectedItem.Value;
	
EndProcedure

#EndRegion

#Region Tags

&AtServer
Procedure ReadTagsData()
	
	TagsData.Clear();
	
	If Not ValueIsFilled(Object.Ref) Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	LeadsTags.Tag AS Tag,
		|	LeadsTags.Tag.DeletionMark AS DeletionMark,
		|	LeadsTags.Tag.Description AS Description
		|FROM
		|	Catalog.Leads.Tags AS LeadsTags
		|WHERE
		|	LeadsTags.Ref = &Ref";
	
	Query.SetParameter("Ref", Object.Ref);
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		NewTagData	= TagsData.Add();
		URLFS	= "Tag_" + NewTagData.GetID();
		
		NewTagData.Tag				= Selection.Tag;
		NewTagData.DeletionMark		= Selection.DeletionMark;
		NewTagData.TagPresentation	= FormattedStringTagPresentation(Selection.Description, Selection.DeletionMark, URLFS);
		NewTagData.TagLength		= StrLen(Selection.Description);
		
	EndDo;
	
EndProcedure

&AtServer
Procedure RefreshTagsItems()
	
	FS = TagsData.Unload(, "TagPresentation").UnloadColumn("TagPresentation");
	
	Index = FS.Count()-1;
	While Index > 0 Do
		FS.Insert(Index, "  ");
		Index = Index - 1;
	EndDo;
	
	Items.TagsCloud.Title	= New FormattedString(FS);
	Items.TagsCloud.Visible	= FS.Count() > 0;
	
EndProcedure

&AtServer
Procedure WriteTagsData(CurrentObject)
	
	CurrentObject.Tags.Load(TagsData.Unload(,"Tag"));
	
EndProcedure

&AtServer
Procedure AttachTagAtServer(Tag)
	
	If TagsData.FindRows(New Structure("Tag", Tag)).Count() > 0 Then
		Return;
	EndIf;
	
	TagData = CommonUse.ObjectAttributesValues(Tag, "Description, DeletionMark");
	
	TagsRow = TagsData.Add();
	URLFS = "Tag_" + TagsRow.GetID();
	
	TagsRow.Tag = Tag;
	TagsRow.DeletionMark = TagData.DeletionMark;
	TagsRow.TagPresentation = FormattedStringTagPresentation(TagData.Description, TagData.DeletionMark, URLFS);
	TagsRow.TagLength = StrLen(TagData.Description);
	
	RefreshTagsItems();
	
	Modified = True;
	
EndProcedure

&AtServer
Procedure CreateAndAttachTagAtServer(Val TagTitle)
	
	Tag = FindCreateTag(TagTitle);
	AttachTagAtServer(Tag);
	
EndProcedure

&AtServerNoContext
Function FindCreateTag(Val TagTitle)
	
	Tag = Catalogs.Tags.FindByDescription(TagTitle, True);
	
	If Tag.IsEmpty() Then
		
		TagObject = Catalogs.Tags.CreateItem();
		TagObject.Description = TagTitle;
		TagObject.Write();
		Tag = TagObject.Ref;
		
	EndIf;
	
	Return Tag;
	
EndFunction

&AtClientAtServerNoContext
Function FormattedStringTagPresentation(TagDescription, DeletionMark, URLFS)
	
	#If Client Then
	Color		= CommonUseClientReUse.StyleColor("MinorInscriptionText");
	BaseFont	= CommonUseClientReUse.StyleFont("NormalTextFont");
	#Else
	Color		= StyleColors.MinorInscriptionText;
	BaseFont	= StyleFonts.NormalTextFont;
	#EndIf
	
	Font	= New Font(BaseFont,,,True,,?(DeletionMark, True, Undefined));
	
	ComponentsFS = New Array;
	ComponentsFS.Add(New FormattedString(TagDescription + Chars.NBSp, Font, Color));
	ComponentsFS.Add(New FormattedString(PictureLib.Clear, , , , URLFS));
	
	Return New FormattedString(ComponentsFS);
	
EndFunction

&AtClient
Procedure TagInputFieldChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	If Not ValueIsFilled(SelectedValue) Then
		Return;
	EndIf;
	
	StandardProcessing = False;
	
	If TypeOf(SelectedValue) = Type("CatalogRef.Tags") Then
		AttachTagAtServer(SelectedValue);
	EndIf;
	Item.UpdateEditText();
	
EndProcedure

&AtClient
Procedure TagInputFieldTextEditEnd(Item, Text, ChoiceData, DataGetParameters, StandardProcessing)
	
	If Not IsBlankString(Text) Then
		StandardProcessing = False;
		CreateAndAttachTagAtServer(Text);
		CurrentItem = Items.TagInputField;
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServerNoContext
Function GetActivityAtServer(Campaign)
	Return Catalogs.Campaigns.GetFirstActivity(Campaign);
EndFunction

&AtServer
Procedure SetFormAttrubitesAtServer()
	
	ReadContactsData();
	
	ReadTagsData();
	RefreshTagsItems();
	
	ContactInformationDrive.OnCreateOnReadAtServer(ThisObject);
	
	ReplaceAddNewContactButton();
	
	If Parameters.Property("ContactInformationLine", ContactInformationLine) Then
		FillContactInformationLine();
	EndIf;
	
	DescriptionList = Items.LeadDescription.ChoiceList;
	FirstRep = Object.Contacts[0].Representation;
	
	GenerateDescriptionAutomatically = IsBlankString(Object.Description)
		OR DescriptionList.FindByValue(Object.Description) <> Undefined
		OR Object.Contacts.Count() > 0
			AND (ValueIsFilled(FirstRep)
			AND DescriptionList.FindByValue(FirstRep) = Undefined);
	
EndProcedure

&AtServer
Procedure FormManagement()
	
	StateStructure = WorkWithLeads.LeadState(Object.Ref);
	FillPropertyValues(ThisObject, StateStructure);
	
	CanBeEdited = AccessRight("Edit", Metadata.Catalogs.Leads);
	
	Rejected = ValueIsFilled(Object.RejectionReason)
		OR Object.ClosureResult = Enums.LeadClosureResult.Rejected;
	ConvertedIntoCustomer = ValueIsFilled(Object.ClosureDate)
		AND Object.ClosureResult = Enums.LeadClosureResult.ConvertedIntoCustomer;
	
	If Rejected OR ConvertedIntoCustomer Then
		Items.TextField.Visible = True;
		Items.GroupClosure.Title = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Finalized on ""%1""'"),
			Format(Object.ClosureDate,"DLF=D"));
	Else
		Items.TextField.Visible = False;
		Items.GroupClosure.Title = NStr("en = 'Finalize'");
	EndIf;
	
	If ConvertedIntoCustomer Then
		
		Text = New FormattedString(NStr("en = 'Lead is converted into customer'"));
		If ValueIsFilled(Object.Counterparty) Then
			StringCounterparty = New FormattedString(String(Object.Counterparty),,,,GetURL(Object.Counterparty));
			TextField = New FormattedString(Text, " ", StringCounterparty);
		Else
			TextField = Text;
		EndIf;
		
		Items.TextField.AutoMaxWidth = True;
		
	EndIf;
	
	If Rejected Then
		TextField= New FormattedString(NStr("en = 'Rejected lead'"));
	EndIf;
	
	ThisObject.ReadOnly = ConvertedIntoCustomer OR Not CanBeEdited;
	
	Items.TagsCloud.Enabled = Not Rejected;
	Items.ButtonsGroup.Visible = Not (Rejected OR ConvertedIntoCustomer);
	Items.BackToWork.Visible = Rejected;
	Items.RejectionReason.Visible = Rejected;
	Items.ClosureNote.Visible = Rejected;
	Items.LeftColumn.Enabled = Not Rejected;
	Items.AdditionalInformation.Enabled = Not Rejected;
	
EndProcedure

&AtServer
Function ConvertIntoCustomerAtServer()
	
	If Not CheckFilling() Then
		Return Undefined;
	EndIf;
	
	ObjectLead = FormAttributeToValue("Object");
	WriteTagsData(ObjectLead);
	
	ContactInformationDrive.BeforeWriteAtServer(ThisObject, ObjectLead);
	
	Return Catalogs.Leads.GetCreateCounterparty(ObjectLead);
	
EndFunction

&AtServer
Procedure ConverIntoRejectedLeadAtServer()
	
	If Not CheckFilling() Then
		Return;
	EndIf;
	
	Write();
	
	Object.ClosureDate = CurrentSessionDate();
	Object.ClosureResult = Enums.LeadClosureResult.Rejected;
	
	Modified = True;
	FormManagement();
	
EndProcedure

&AtServer
Procedure BackToWorkAtServer()
	
	Object.ClosureResult = Undefined;
	Object.RejectionReason = Undefined;
	Object.ClosureDate = Date('00010101');
	Object.ClosureNote = Undefined;
	FormManagement();
	
EndProcedure

&AtClient
Procedure ConvertIntoRejectedLeadClickEnd(Response, Parameter) Export
	
	If Response = DialogReturnCode.Cancel Then
		Return;
	EndIf;
	
	ConverIntoRejectedLeadAtServer();
	
EndProcedure

&AtClient
Procedure SetActivityChoiseList(NewCampaign)

	Items.Activity.ChoiceList.Clear();
	
	Items.Activity.Enabled = ValueIsFilled(NewCampaign);
	
	ActivitiesChoiceList = GetAvailableActivities(NewCampaign);
	
	For Each ActivityValue In ActivitiesChoiceList Do
		Items.Activity.ChoiceList.Add(ActivityValue.Value);
	EndDo;
	
EndProcedure

&AtServerNoContext
Function GetAvailableActivities(Campaign)
	
	Return WorkWithLeads.GetAvailableActivities(Campaign);
	
EndFunction

&AtClient
Procedure ConvertIntoCustomerClickEnd(Response, Parameter) Export
	
	If Response.Value = DialogReturnCode.Cancel Then
		Return;
	EndIf;
	
	If Response.DontAskAgain Then
		SetUserSettingAtServer(True, "ConvertLeadWithoutMessage");
	EndIf;
	
	NewCounterparty = ConvertIntoCustomerAtServer();
	
	If Not ValueIsFilled(NewCounterparty) Then
		Return;
	EndIf;
	
	NotifyChanged(Object.Ref);
	
	FormParameters = New Structure("Key", NewCounterparty);
	OpenForm("Catalog.Counterparties.ObjectForm", FormParameters);
	
	Modified = False;
	Close();
	
EndProcedure

&AtServerNoContext
Procedure SetUserSettingAtServer(SettingValue, SettingName)
	DriveServer.SetUserSetting(SettingValue, SettingName, Users.CurrentUser());
EndProcedure

#EndRegion

#Region Contacts

&AtServer
Procedure CreateContactGroup(ID)
	
	ContactGroup = Items.Add("ContactInformation" + ID, Type("FormGroup"), Items.ContactInformation);
	ContactGroup.Type = FormGroupType.UsualGroup;
	ContactGroup.ShowTitle = False;
	ContactGroup.Representation = UsualGroupRepresentation.None;
	ContactGroup.Group = ChildFormItemsGroup.Vertical;
	
	LineIdentifier = LineIdentifiers.FindRows(New Structure("Value", ID));
	
	ContactField = Items.Add("ContactInformation" + ID + "Presentation", Type("FormField"), ContactGroup);
	ContactField.Type = FormFieldType.InputField;
	If LineIdentifier.Count() <> 0 Then
		ContactField.DataPath = StrTemplate("Object.Contacts[%1].Representation", LineIdentifiers.IndexOf(LineIdentifier[0]));
	EndIf;
	FillPropertyValues(ContactField, Items.ContactInformation0_Presentation, "TitleLocation,InputHint,HorizontalStretch,AutoMaxWidth,MaxWidth");
	
EndProcedure

&AtServer
Procedure UpdateContactsIDs()
	
	IDs = Object.Contacts.Unload(, "ContactLineIdentifier");
	IDs.GroupBy("ContactLineIdentifier");
	IDs.Sort("ContactLineIdentifier Asc");
	IDs = IDs.UnloadColumn("ContactLineIdentifier");
	
	LineIdentifiers.Clear();
	
	For Each ID In IDs Do
		NewLine = LineIdentifiers.Add();
		NewLine.Value = ID;
	EndDo;
	
EndProcedure

&AtServer
Function LastRowID()
	
	If LineIdentifiers.Count() = 0 Then
		Return Undefined;
	EndIf;
	
	Return LineIdentifiers[LineIdentifiers.Count() - 1].Value;
	
EndFunction

&AtServer
Function NewRowID()
	
	NewID = 0;
	If LineIdentifiers.Count() <> 0 Then
		NewID = LastRowID() + 1;
	EndIf;
	
	NewRow = LineIdentifiers.Add();
	NewRow.Value = NewID;
	
	Return NewID;
	
EndFunction

&AtServer
Procedure ReadContactsData()
	
	If Object.Contacts.Count() = 0 Then
		Object.Contacts.Add();
	EndIf;
	
	UpdateContactsIDs();
	
	Items.Move(Items.AddNewContact, Items.Contacts);
	
	DeletingItems = New Array;
	
	For Each LineID In LineIdentifiers Do
		If LineID.Value = 0 Then
			Continue;
		EndIf;
		DeletingItem = Items.Find("ContactInformation" + LineID.Value);
		If DeletingItem <> Undefined Then
			DeletingItems.Add(DeletingItem);
		EndIf;
	EndDo;
	
	For Each DeletingItem In DeletingItems Do
		Items.Delete(DeletingItem);
	EndDo;
	
	For Each LineID In LineIdentifiers Do
		If LineID.Value = 0 Then
			Continue;
		EndIf;
		CreateContactGroup(LineID.Value);
	EndDo;
	
EndProcedure

&AtServer
Procedure ReplaceAddNewContactButton(ContactID = Undefined)
	
	If ContactID = Undefined Then
		ContactID = LastRowID();
	EndIf;
	
	LastGroupWithComands = Items.Find("GroupAddFieldContactInformation_" + ContactID);
	
	If LastGroupWithComands = Undefined Then
		Return;
	EndIf;
	
	Location = Undefined;
	If LastGroupWithComands.ChildItems.Count() <> 0 Then
		Location = LastGroupWithComands.ChildItems[0];
	EndIf;
	
	Items.Move(Items.AddNewContact, LastGroupWithComands, Location);
	
EndProcedure

&AtServer
Procedure AddNewContactAtServer()
	
	NewID = NewRowID();
	
	NewRow = Object.Contacts.Add();
	NewRow.ContactLineIdentifier = NewID;
	
	CreateContactGroup(NewID);
	
	ContactInformationDrive.RefreshContactInformationItems(ThisObject);
	
	FieldContactRepresentation = Items["ContactInformation" + NewID + "Presentation"];
	FieldContactRepresentation.SetAction("OnChange", "Attachable_Contacts0RepresentationOnChange");
	
	ReplaceAddNewContactButton(NewID);
	
	CurrentItem = FieldContactRepresentation;
	
EndProcedure

#EndRegion

#Region ContactInformationDrive

&AtServer
Function FindOrAddNewCILine(ContactLineIdentifier, Type)
	
	SearchStructure = New Structure;
	SearchStructure.Insert("ContactLineIdentifier",	ContactLineIdentifier);
	SearchStructure.Insert("Type",					Type);
	SearchStructure.Insert("Presentation",			"");
	
	FoundLines = Object.ContactInformation.FindRows(SearchStructure);
	
	For Each CILine In FoundLines Do
		If Not ValueIsFilled(CILine.Presentation) Then
			Return CILine;
		EndIf;
	EndDo;
	
	// Add new line CI with grouped by CI type
	CICount = Object.ContactInformation.Count();
	InsertIndex = CICount;
	
	For ReverseIndex = 1 To CICount Do
		CurIndex = CICount - ReverseIndex;
		If Object.ContactInformation[CurIndex].ContactLineIdentifier = ContactLineIdentifier
			AND Object.ContactInformation[CurIndex].Type = Type Then
			InsertIndex = CurIndex + 1;
			Break;
		EndIf;
	EndDo;
	
	Result = Object.ContactInformation.Insert(InsertIndex);
	Result.Type = Type;
	
	Return Result;
	
EndFunction

&AtServer
Procedure FillContactInformationLine()
	
	If ContactInformationLine.Type = Enums.ContactInformationTypes.EmailAddress Then
		CIKind = CommonUse.PredefinedName("Catalog.ContactInformationTypes.LeadEmail");
	ElsIf ContactInformationLine.Type = Enums.ContactInformationTypes.Phone Then
		CIKind = CommonUse.PredefinedName("Catalog.ContactInformationTypes.LeadPhone");
	EndIf;
	If CIKind = Undefined Then
		Return;
	EndIf;
	
	Object.Description = ContactInformationLine.Contact;
	
	LineID = LineIdentifiers[0].Value;
	
	ContactsData = Object.Contacts.FindRows(New Structure("ContactLineIdentifier", LineID));
	If ContactsData = 0 Then
		Return;
	EndIf;
	
	ContactData = ContactsData[0];
	ContactData.Representation = ContactInformationLine.Contact;
	
	CILine = FindOrAddNewCILine(LineID, ContactInformationLine.Type);
	CILine.Presentation = ContactInformationLine.HowToContact;
	CILine.Kind = CIKind;
	
EndProcedure

&AtClient
Procedure Attachable_ActionCIClick(Item)
	
	ContactInformationDriveClient.ActionCIClick(ThisObject, Item);
	
EndProcedure

&AtClient
Procedure Attachable_PresentationCIOnChange(Item)
	
	ContactInformationDriveClient.PresentationCIOnChange(ThisObject, Item);
	
EndProcedure

&AtClient
Procedure Attachable_PresentationCIStartChoice(Item, ChoiceData, StandardProcessing)
	
	ContactInformationDriveClient.PresentationCIStartChoice(ThisObject, Item, ChoiceData, StandardProcessing);
	
EndProcedure

&AtClient
Procedure Attachable_PresentationCIClearing(Item, StandardProcessing)
	
	ContactInformationDriveClient.PresentationCIClearing(ThisObject, Item, StandardProcessing);
	
EndProcedure

&AtClient
Procedure Attachable_CommentCIOnChange(Item)
	
	ContactInformationDriveClient.CommentCIOnChange(ThisObject, Item);
	
EndProcedure

&AtClient
Procedure Attachable_ContactInformationDriveExecuteCommand(Command)
	
	ContactInformationDriveClient.ExecuteCommand(ThisObject, Command);
	
EndProcedure

#EndRegion

#Region LibrariesHandlers

&AtClient
Procedure Attachable_ExecuteAssignedCommand(Command)
	
	If Not AdditionalReportsAndDataProcessorsClient.ExecuteAllocatedCommandAtClient(ThisForm, Command.Name) Then
		ExecutionResult = Undefined;
		AdditionalReportsAndProcessingsExecuteAllocatedCommandAtServer(Command.Name, ExecutionResult);
		AdditionalReportsAndDataProcessorsClient.ShowCommandExecutionResult(ThisForm, ExecutionResult);
	EndIf;
	
EndProcedure

&AtServer
Procedure AdditionalReportsAndProcessingsExecuteAllocatedCommandAtServer(ItemName, ExecutionResult)
	AdditionalReportsAndDataProcessors.ExecuteAllocatedCommandAtServer(ThisObject, ItemName, ExecutionResult);
EndProcedure

&AtClient
Procedure Attachable_ExecutePrintCommand(Command)
	PrintManagementClient.ExecuteConnectedPrintCommand(Command, ThisObject, Object);
EndProcedure

&AtClient
Procedure Attachable_EditContentOfProperties(Command)
	
	PropertiesManagementClient.EditContentOfProperties(ThisForm, Object.Ref);
	
EndProcedure

&AtServer
Procedure UpdateAdditionalAttributesItems()
	
	PropertiesManagement.UpdateAdditionalAttributesItems(ThisForm, FormAttributeToValue("Object"));
	
EndProcedure

#EndRegion

#EndRegion