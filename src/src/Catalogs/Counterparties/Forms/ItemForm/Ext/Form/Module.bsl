
#Region FormEventHadlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	If Parameters.Key.IsEmpty() Then
		
		OnCreateOnReadAtServer();
		
		If Not IsBlankString(Parameters.FillingText) Then
			FillAttributesByFillingText(Parameters.FillingText);
		EndIf;
		
		If Parameters.AdditionalParameters.Property("OperationKind") Then
			Relationship = ContactsClassification.CounterpartyRelationshipTypeByOperationKind(Parameters.AdditionalParameters.OperationKind);
			FillPropertyValues(Object, Relationship, "Customer,Supplier,OtherRelationship");
		EndIf;
		
	EndIf;
	
	If Object.LegalEntityIndividual = Enums.CounterpartyType.Individual Then
		Items.DescriptionFull.Title	= NStr("en = 'Name, surname'");
	Else
		Items.DescriptionFull.Title	= NStr("en = 'Legal name'");
	EndIf;
	
	ErrorCounterpartyHighlightColor	= StyleColors.ErrorCounterpartyHighlightColor;
	ExecuteAllChecks(ThisObject);
	
	SetFormTitle(ThisObject);
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisForm, Items.ImportantCommandsGroup);
	// End StandardSubsystems.Printing
	
	// StandardSubsystems.Properties
	PropertiesManagement.OnCreateAtServer(ThisForm, Object, "GroupAdditionalAttributes");
	// End StandardSubsystems.Properties
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	FormManagement();
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "SettlementAccountsAreChanged" Then
		
		Object.GLAccountCustomerSettlements = Parameter.GLAccountCustomerSettlements;
		Object.CustomerAdvancesGLAccount = Parameter.CustomerAdvanceGLAccount;
		Object.GLAccountVendorSettlements = Parameter.GLAccountVendorSettlements;
		Object.VendorAdvancesGLAccount = Parameter.AdvanceGLAccountToSupplier; 
		Modified = True;
		
	ElsIf EventName = "SettingMainAccount" AND Parameter.Owner = Object.Ref Then
		
		Object.BankAccountByDefault = Parameter.NewMainAccount;
		If Not Modified Then
			Write();
		EndIf;
		Notify("SettingMainAccountCompleted");
		
	ElsIf EventName = "Write_ContactPerson" Then
		
		If Parameter.Owner = Object.Ref Then
			
			ContactPersonsRows = ContactPersonsData.FindRows(New Structure("ContactPerson", Parameter.ContactPerson));
			If ContactPersonsRows.Count() = 0 Then
				If Parameter.Property("ContactPersonIndex") Then
					ContactPersonsDataRow = ContactPersonsData[Parameter.ContactPersonIndex];
				Else
					ContactPersonsDataRow = ContactPersonsData.Add();
				EndIf;
				ContactPersonsDataRow.ContactPerson = Parameter.ContactPerson;
				ContactPersonsRows.Add(ContactPersonsDataRow);
			EndIf;
			
			For Each ContactPersonsDataRow In ContactPersonsRows Do
				ContactPersonIndex = ContactPersonsData.IndexOf(ContactPersonsDataRow);
				UpdateContactPersonsDataItem(ContactPersonIndex, ContactPersonsDataRow.ContactPerson);
			EndDo;
			
			CurrentItem = Items["DescriptionContact_" + ContactPersonIndex];
			
		ElsIf Parameter.PreviousOwner = Object.Ref Then
			
			ContactPersonsRows = ContactPersonsData.FindRows(New Structure("ContactPerson", Parameter.ContactPerson));
			If ContactPersonsRows.Count() > 0 Then
				
				For Each ContactPersonsDataRow In ContactPersonsRows Do
					ContactPersonsData.Delete(ContactPersonsDataRow);
				EndDo;
				
				Modified = True;
				RefreshContactPersonsItems();
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	// StandardSubsystems.Properties
	If PropertiesManagementClient.ProcessAlerts(ThisForm, EventName, Parameter) Then
		UpdateAdditionalAttributesItems();
	EndIf;
	// End StandardSubsystems.Properties
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	OnCreateOnReadAtServer();
	
	// StandardSubsystems.Properties
	PropertiesManagement.OnReadAtServer(ThisForm, CurrentObject);
	// End StandardSubsystems.Properties
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	// StandardSubsystems.PerformanceMeasurement
	PerformanceEstimationClientServer.StartTimeMeasurement("CatalogCounterpartiesWrite");
	// End StandardSubsystems.PerformanceMeasurement
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	WriteTagsData(CurrentObject);
	
	If Not ValueIsFilled(CurrentObject.ContactPerson) Then
		For Each RowCP In ContactPersonsData Do
			If ValueIsFilled(RowCP.ContactPerson) Then
				CurrentObject.ContactPerson = RowCP.ContactPerson;
				Break;
			ElsIf Not IsBlankString(RowCP.Description) And TypeOf(RowCP.Description) = Type("String") Then
				CurrentObject.ContactPerson = Catalogs.ContactPersons.GetRef();
				CurrentObject.AdditionalProperties.Insert("NewDefaultContactPerson", CurrentObject.ContactPerson);
				Break;
			EndIf;
		EndDo;
	EndIf;
	
	ContactInformationDrive.BeforeWriteAtServer(ThisObject, CurrentObject);
	
	// StandardSubsystems.Properties
	PropertiesManagement.BeforeWriteAtServer(ThisForm, CurrentObject);
	// End StandardSubsystems.Properties
	
EndProcedure

&AtServer
Procedure OnWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	WriteContactPersonsData(CurrentObject);
	
	WriteParameters.Insert("ContactPersonsToBeNotified", CurrentObject.AdditionalProperties.ContactPersonsToBeNotified);
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	SetFormTitle(ThisObject);
	Notify("AfterRecordingOfCounterparty", Object.Ref);
	Notify("Write_Counterparty", Object.Ref, ThisObject);
	
	For Each ContactPersonToBeNotified In WriteParameters.ContactPersonsToBeNotified Do
		Notify("Write_ContactPerson_Counterparty", ContactPersonToBeNotified, ThisObject);
	EndDo;
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	ReadAdditionalInformationPanelData();
	
	FillAndRefreshContactPersons();
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	ContactInformationDrive.FillCheckProcessingAtServer(ThisObject, Cancel);
	
	ContactPersonsFillCheck(Cancel);
	ContactPersonsContactInformationFillCheck(Cancel);
	
	// StandardSubsystems.Properties
	PropertiesManagement.FillCheckProcessing(ThisForm, Cancel, CheckedAttributes);
	// End StandardSubsystems.Properties
	
EndProcedure

#EndRegion

#Region FormItemsEventHadlers

&AtClient
Procedure DebtBalanceURLProcessing(Item, FormattedStingHyperlink, StandartProcessing)
	
	StandartProcessing = False;
	
	FormParameters = New Structure;
	FormParameters.Insert("VariantKey", "BalanceContext");
	FormParameters.Insert("Filter", New Structure("Period, Counterparty", New StandardPeriod, Object.Ref));
	FormParameters.Insert("GenerateOnOpen", True);
	
	OpenForm("Report.StatementOfAccount.Form", FormParameters, ThisObject, UUID);
	
EndProcedure

&AtClient
Procedure SalesAmountURLProcessing(Item, FormattedStingHyperlink, StandartProcessing)
	
	StandartProcessing = False;
	
	FormParameters = New Structure;
	FormParameters.Insert("VariantKey", "SalesDynamicsByCustomers");
	FormParameters.Insert("Filter", New Structure("Period, Counterparty", New StandardPeriod, Object.Ref));
	FormParameters.Insert("GenerateOnOpen", True);
	
	OpenForm("Report.NetSales.Form", FormParameters, ThisObject, UUID);
	
EndProcedure

&AtClient
Procedure DescriptionFullOnChange(Item)
	
	Object.DescriptionFull = StrReplace(Object.DescriptionFull, Chars.LF, " ");
	If GenerateDescriptionAutomatically Then
		Object.Description = Object.DescriptionFull;
	EndIf;
	
EndProcedure

&AtClient
Procedure LegalEntityIndividualOnChange(Item)
	
	IsIndividual = Object.LegalEntityIndividual = PredefinedValue("Enum.CounterpartyType.Individual");
	
	Items.DateOfBirth.Visible	= IsIndividual;
	Items.Gender.Visible		= IsIndividual;
	Items.LegalForm.Visible		= Not IsIndividual;
	
	If IsIndividual Then
		Items.DescriptionFull.Title	= NStr("en = 'Name, surname'");
	Else
		Items.DescriptionFull.Title	= NStr("en = 'Legal name'");
	EndIf;
	
EndProcedure

&AtClient
Procedure TINOnChange(Item)
	
	GenerateDuplicateChecksPresentation(ThisObject);
	
	WorkWithCounterpartiesClientServerOverridable.GenerateDataChecksPresentation(ThisObject);
	
EndProcedure

&AtClient
Procedure DataChecksPresentationURLProcessing(Item, FormattedStringURL, StandardProcessing)
	
	If StrFind(FormattedStringURL, "ShowDuplicates") > 0 Then
		
		StandardProcessing = False;
		
		FormParameters = New Structure;
		FormParameters.Insert("TIN",			TrimAll(Object.TIN));
		FormParameters.Insert("IsLegalEntity",	IsLegalEntity(Object.LegalEntityIndividual));
		
		OpenForm("Catalog.Counterparties.Form.DuplicatesChoiceForm", FormParameters, Item);
		
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
Procedure CustomerOnChange(Item)
	
	FormManagement();
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure AddContactFields(Command)
	
	ContactPersonsDataRow = ContactPersonsData.Add();
	
	FillAlwaysShownKindsCI(
		ContactPersonsDataRow.ContactInformation,
		ContactPersonContactInformationKindProperties);
	
	RefreshContactPersonsItems();
	CurrentItem = Items["DescriptionContact_" + ContactPersonsData.IndexOf(ContactPersonsDataRow)];
	
EndProcedure

&AtClient
Procedure AddContactsContactInformationField(Command)
	
	ContactIndex = Number(StrReplace(CurrentItem.Name, "AddContactsContactInformationField_", ""));
	ContactPersonsDataRow = ContactPersonsData[ContactIndex];
	
	NotifyDescription = New NotifyDescription(
		"AddContactsContactInformationKindIsSelected",
		ThisObject,
		New Structure("ContactIndex", ContactIndex));
	
	AvailableKinds = New ValueList;
	Filter = New Structure("Kind");
	For Each TableRow In ContactPersonContactInformationKindProperties Do
		Filter.Kind = TableRow.Kind;
		FoundRows = ContactPersonsDataRow.ContactInformation.FindRows(Filter);
		If TableRow.AllowMultipleValueInput Or FoundRows.Count() = 0 Then
			AvailableKinds.Add(TableRow.Kind, TableRow.KindPresentation);
		EndIf;
	EndDo;
	
	ShowChooseFromList(NotifyDescription, AvailableKinds, CurrentItem);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure OnCreateOnReadAtServer()
	
	ViewStatemenOfAccount = AccessRight("View", Metadata.Reports.StatementOfAccount);
	ViewNetSales = AccessRight("View", Metadata.Reports.NetSales);
	
	// 2. Reading additional information
	ReadAdditionalInformationPanelData();
	ReadContactPersonContactInformationKindProperties();
	FillContactPersonContactInformation();
	RefreshContactPersonsItems();
	
	ReadTagsData();
	RefreshTagsItems();
	
	GenerateDescriptionAutomatically = IsBlankString(Object.Description);
	
	ContactInformationDrive.OnCreateOnReadAtServer(ThisObject);
	
EndProcedure

&AtClient
Procedure FormManagement()
	
	IsIndividual = Object.LegalEntityIndividual = PredefinedValue("Enum.CounterpartyType.Individual");
	
	Items.DateOfBirth.Visible	= IsIndividual;
	Items.Gender.Visible	= IsIndividual;
	Items.LegalForm.Visible			= Not IsIndividual;
	
	Items.CustomerAcquisitionChannel.Visible = Object.Customer;
	
	Items.DebtBalance.Visible = ViewStatemenOfAccount;
	Items.SalesAmount.Visible = ViewNetSales And Object.Customer;
	Items.LastSale.Visible = ViewNetSales And Object.Customer;
	
EndProcedure

&AtClientAtServerNoContext
Procedure SetFormTitle(Form)
	
	Object = Form.Object;
	If Not ValueIsFilled(Object.Ref) Then
		Form.AutoTitle = True;
		Return;
	EndIf;
	
	Form.AutoTitle	= False;
	RelationshipKinds = New Array;
	
	If Object.Customer Then
		RelationshipKinds.Add(NStr("en = 'Customer'"));
	EndIf;
	
	If Object.Supplier Then
		RelationshipKinds.Add(NStr("en = 'Supplier'"));
	EndIf;
	
	If Object.OtherRelationship Then
		RelationshipKinds.Add(NStr("en = 'Other relationship'"));
	EndIf;
	
	If RelationshipKinds.Count() > 0 Then
		Title = Object.Description + " (";
		For Each Kind In RelationshipKinds Do
			Title = Title + Kind + ", ";
		EndDo;
		StringFunctionsClientServer.DeleteLatestCharInRow(Title, 2);
	Else	
		Title = Object.Description + " (" + NStr("en = 'Counterparty'");
	EndIf;
	
	Title = Title + ")";
	
	Form.Title = Title;
	
EndProcedure

&AtServer
Procedure FillAttributesByFillingText(Val FillingText)
	
	Object.DescriptionFull	= FillingText;
	CurrentItem = Items.DescriptionFull;
	
	GenerateDescriptionAutomatically = True;
	Object.Description	= Object.DescriptionFull;
	
EndProcedure

#EndRegion

#Region ContactPersonsAndContactInformation

&AtServer
Procedure ReadContactPersonContactInformationKindProperties()
	
	Query = New Query(
	"SELECT
	|	OrderTypesCI.Type AS Type,
	|	OrderTypesCI.Order AS Order
	|INTO TT_TypesOrder
	|FROM
	|	&OrderTypesCI AS OrderTypesCI
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ContactInformationTypes.Ref AS Kind,
	|	PRESENTATION(ContactInformationTypes.Ref) AS KindPresentation,
	|	ContactInformationTypes.Type AS Type,
	|	ISNULL(ContactInformationVisibilitySettings.ShowInFormAlways, FALSE) AS ShowInFormAlways,
	|	ContactInformationTypes.AllowMultipleValueInput AS AllowMultipleValueInput,
	|	ContactInformationTypes.Mandatory AS Mandatory,
	|	ContactInformationTypes.CheckValidity AS CheckValidity,
	|	ContactInformationTypes.EditInDialogOnly AS EditInDialogOnly
	|FROM
	|	Catalog.ContactInformationTypes AS ContactInformationTypes
	|		LEFT JOIN TT_TypesOrder AS TT_TypesOrder
	|		ON ContactInformationTypes.Type = TT_TypesOrder.Type
	|		LEFT JOIN InformationRegister.ContactInformationVisibilitySettings AS ContactInformationVisibilitySettings
	|		ON ContactInformationTypes.Ref = ContactInformationVisibilitySettings.Kind
	|WHERE
	|	ContactInformationTypes.DeletionMark = FALSE
	|	AND ContactInformationTypes.Parent = &GroupTypesCI
	|
	|ORDER BY
	|	TT_TypesOrder.Order,
	|	ContactInformationTypes.AdditionalOrderingAttribute");
	
	Query.SetParameter("OrderTypesCI", ContactInformationDrive.OrderTypesCI());
	Query.SetParameter("GroupTypesCI", Catalogs.ContactInformationTypes.CatalogContactPersons);
	
	ContactPersonContactInformationKindProperties.Load(Query.Execute().Unload());
	
EndProcedure

&AtServer
Procedure FillAndRefreshContactPersons()
	
	FillContactPersonContactInformation();
	RefreshContactPersonsItems();
	
EndProcedure

&AtServer
Procedure FillContactPersonContactInformation()
	
	ContactPersonsData.Clear();
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	ContactPersons.Ref AS ContactPerson,
	|	ContactPersons.Owner AS Owner,
	|	ContactPersons.Position AS Position,
	|	ContactPersons.Description AS Description,
	|	ContactPersons.AdditionalOrderingAttribute AS AdditionalOrderingAttribute
	|INTO TT_Contacts
	|FROM
	|	Catalog.ContactPersons AS ContactPersons
	|WHERE
	|	ContactPersons.Owner = &Owner
	|	AND ContactPersons.Invalid = FALSE
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_Contacts.ContactPerson AS ContactPerson,
	|	TT_Contacts.Description AS Description,
	|	TT_Contacts.Position AS Position
	|FROM
	|	TT_Contacts AS TT_Contacts
	|
	|ORDER BY
	|	TT_Contacts.AdditionalOrderingAttribute,
	|	Description
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	OrderTypesCI.Type AS Type,
	|	OrderTypesCI.Order AS Order
	|INTO TT_OrderTypesCI
	|FROM
	|	&OrderTypesCI AS OrderTypesCI
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	OwnerContactInformation.Ref AS ContactPerson,
	|	OwnerContactInformation.Kind AS Kind,
	|	OwnerContactInformation.Type AS Type,
	|	OwnerContactInformation.Presentation AS Presentation,
	|	OwnerContactInformation.FieldValues AS FieldValues,
	|	OwnerContactInformation.Kind.AdditionalOrderingAttribute AS OrderKindsCI,
	|	TT_OrderTypesCI.Order AS OrderTypesCI
	|FROM
	|	Catalog.ContactPersons.ContactInformation AS OwnerContactInformation
	|		LEFT JOIN TT_OrderTypesCI AS TT_OrderTypesCI
	|		ON OwnerContactInformation.Type = TT_OrderTypesCI.Type
	|WHERE
	|	OwnerContactInformation.Ref IN
	|			(SELECT
	|				TT_Contacts.ContactPerson
	|			FROM
	|				TT_Contacts)
	|
	|ORDER BY
	|	OrderTypesCI,
	|	OrderKindsCI";
	
	Query.SetParameter("Owner",				Object.Ref);
	Query.SetParameter("OrderTypesCI",		ContactInformationDrive.OrderTypesCI());
	
	QueryResults = Query.ExecuteBatch();
	
	SelContacts = QueryResults[1].Select();
	SelCI = QueryResults[3].Select();
	
	Filter = New Structure("ContactPerson");
	
	While SelContacts.Next() Do
		
		Filter.ContactPerson = SelContacts.ContactPerson;
		
		ContactPersonsRow = ContactPersonsData.Add();
		FillPropertyValues(ContactPersonsRow, SelContacts, "ContactPerson, Description, Position");
		SelCI.Reset();
		
		While SelCI.FindNext(Filter) Do
			
			ContactPersonContactInformationRow = ContactPersonsRow.ContactInformation.Add();
			FillPropertyValues(ContactPersonContactInformationRow, SelCI, "Type, Kind, Presentation, FieldValues");
			ContactPersonContactInformationRow.Comment = ContactInformationManagement.ContactInformationComment(SelCI.FieldValues);
			
		EndDo;
		
	EndDo;
	
	If ContactPersonsData.Count() = 0 Then
		
		ContactPersonsRow = ContactPersonsData.Add();
		FillAlwaysShownKindsCI(
			ContactPersonsRow.ContactInformation,
			ContactPersonContactInformationKindProperties);
	EndIf;
	
EndProcedure

&AtServer
Procedure RefreshContactPersonsItems()
	
	Items.Move(Items.AddContactFields, Items.AddCommandsContact_0);
	
	DeleteItems = New Array;
	
	For GroupIndex = 1 To Items.Contacts.ChildItems.Count() - 1 Do
		DeleteItems.Add(Items.Contacts.ChildItems[GroupIndex]);
	EndDo;
	For Each GroupCI In Items.ContactInformationContact_0.ChildItems Do
		DeleteItems.Add(GroupCI);
	EndDo;
	For Each DeleteItem In DeleteItems Do
		Items.Delete(DeleteItem);
	EndDo;
	
	CIKindWidth = 9;
	CommentFieldWidth = 11;
	
	For Each ContactPersonsDataRow In ContactPersonsData Do
		
		ContactIndex = ContactPersonsData.IndexOf(ContactPersonsDataRow);
		
		If ContactIndex > 0 Then
			
			ContactGroup = Items.Add("Contact_" + ContactIndex, Type("FormGroup"), Items.Contacts);
			ContactGroup.Type = Items.Contact_0.Type;
			ContactGroup.Representation = Items.Contact_0.Representation;
			ContactGroup.Group = Items.Contact_0.Group;
			ContactGroup.ShowTitle = Items.Contact_0.ShowTitle;
			
			GroupDescriptionContact = Items.Add("GroupDescriptionContact_" + ContactIndex, Type("FormGroup"), ContactGroup);
			GroupDescriptionContact.Type = Items.GroupDescriptionContact_0.Type;
			GroupDescriptionContact.Representation = Items.GroupDescriptionContact_0.Representation;
			GroupDescriptionContact.Group = Items.GroupDescriptionContact_0.Group;
			GroupDescriptionContact.ShowTitle = Items.GroupDescriptionContact_0.ShowTitle;
			
			DescriptionContact = Items.Add("DescriptionContact_" + ContactIndex, Type("FormField"), GroupDescriptionContact);
			DescriptionContact.Type = Items.DescriptionContact_0.Type;
			DescriptionContact.DataPath = "ContactPersonsData[" + ContactIndex + "].Description";
			DescriptionContact.TitleLocation = Items.DescriptionContact_0.TitleLocation;
			DescriptionContact.InputHint = Items.DescriptionContact_0.InputHint;
			
			DescriptionContact.AutoMaxWidth = Items.DescriptionContact_0.AutoMaxWidth;
			DescriptionContact.MaxWidth = Items.DescriptionContact_0.MaxWidth;
			DescriptionContact.ChoiceButton = Items.DescriptionContact_0.ChoiceButton;
			DescriptionContact.DropListButton = Items.DescriptionContact_0.DropListButton;
			DescriptionContact.CreateButton = Items.DescriptionContact_0.CreateButton;
			DescriptionContact.OpenButton = Items.DescriptionContact_0.OpenButton;
			
			DescriptionContact.SetAction("OnChange", "DescriptionContact_OnChange");
			DescriptionContact.SetAction("Opening", "DescriptionContact_Opening");
			
			PositionContact = Items.Add("PositionContact_" + ContactIndex, Type("FormField"), GroupDescriptionContact);
			PositionContact.Type = Items.PositionContact_0.Type;
			PositionContact.DataPath = "ContactPersonsData[" + ContactIndex + "].Position";
			PositionContact.TitleLocation = Items.PositionContact_0.TitleLocation;
			PositionContact.InputHint = Items.PositionContact_0.InputHint;
			
			PositionContact.AutoMaxWidth = Items.PositionContact_0.AutoMaxWidth;
			PositionContact.MaxWidth = Items.PositionContact_0.MaxWidth;
			PositionContact.ChoiceButton = Items.PositionContact_0.ChoiceButton;
			PositionContact.DropListButton = Items.PositionContact_0.DropListButton;
			PositionContact.CreateButton = Items.PositionContact_0.CreateButton;
			PositionContact.OpenButton = Items.PositionContact_0.OpenButton;
			
			PositionContact.SetAction("OnChange", "PositionContact_OnChange");
			
			GroupCI = Items.Add("ContactInformationContact_" + ContactIndex, Type("FormGroup"), ContactGroup);
			GroupCI.Type = FormGroupType.UsualGroup;
			GroupCI.Representation = UsualGroupRepresentation.None;
			GroupCI.Group = ChildFormItemsGroup.Vertical;
			GroupCI.ShowTitle = False;
			
			GroupAddCommandsContact = Items.Add("AddCommandsContact_" + ContactIndex, Type("FormGroup"), ContactGroup);
			GroupAddCommandsContact.Type = FormGroupType.UsualGroup;
			GroupAddCommandsContact.Representation = UsualGroupRepresentation.None;
			GroupAddCommandsContact.Group = ChildFormItemsGroup.AlwaysHorizontal;
			GroupAddCommandsContact.HorizontalAlignInGroup = ItemHorizontalLocation.Right;
			GroupAddCommandsContact.ShowTitle = False;
			
			Button = Items.Add("AddContactsContactInformationField_" + ContactIndex, Type("FormButton"), GroupAddCommandsContact);
			Button.CommandName = "AddContactsContactInformationField";
			Button.ShapeRepresentation = ButtonShapeRepresentation.None;
			Button.HorizontalAlignInGroup = ItemHorizontalLocation.Right;
			
		Else
			
			GroupCI = Items.ContactInformationContact_0;
			
		EndIf;
		
		Filter = New Structure("Kind");
		
		For Each ContactPersonContactInformationRow In ContactPersonsDataRow.ContactInformation Do
			
			IndexCI = ContactPersonsDataRow.ContactInformation.IndexOf(ContactPersonContactInformationRow);
			Filter.Kind = ContactPersonContactInformationRow.Kind;
			FoundRows = ContactPersonContactInformationKindProperties.FindRows(Filter);
			If FoundRows.Count() = 0 Then
				Continue;
			EndIf;;
			KindProperties = FoundRows[0];
			
			GroupValueCI = Items.Add("Contact_" + ContactIndex + "_CI_" + IndexCI, Type("FormGroup"), GroupCI);
			GroupValueCI.Type = FormGroupType.UsualGroup;
			GroupValueCI.Title = ContactPersonContactInformationRow.Kind;
			GroupValueCI.Representation = UsualGroupRepresentation.None;
			GroupValueCI.Group = ChildFormItemsGroup.AlwaysHorizontal;
			GroupValueCI.ShowTitle = False;
			GroupValueCI.Width = 35;
			
			DecorationAction = Items.Add("ActionContact_" + ContactIndex + "_CI_" + IndexCI, Type("FormDecoration"), GroupValueCI);
			DecorationAction.Type = FormDecorationType.Picture;
			DecorationAction.Picture = ContactInformationDrive.ActionPictureByContactInformationType(ContactPersonContactInformationRow.Type);
			DecorationAction.PictureSize = PictureSize.AutoSize;
			DecorationAction.Hyperlink = True;
			DecorationAction.Width = 2;
			DecorationAction.Height = 1;
			DecorationAction.VerticalAlignInGroup = ItemVerticalAlign.Auto;
			DecorationAction.SetAction("Click", "Attachable_ActionContactCIClick");
			
			KindField = Items.Add("KindContact_" + ContactIndex + "_CI_" + IndexCI, Type("FormField"), GroupValueCI);
			KindField.Type = FormFieldType.LabelField;
			KindField.DataPath = "ContactPersonsData[" + ContactIndex + "].ContactInformation[" + IndexCI + "].Kind";
			KindField.TitleLocation = FormItemTitleLocation.None;
			KindField.Width = CIKindWidth;
			KindField.HorizontalStretch = False;
			
			EditInDialogIsAvailable = ContactInformationDrive.ForContactInformationTypeIsAvailableEditInDialog(ContactPersonContactInformationRow.Type);
			
			PresentationField = Items.Add("PresentationContact_" + ContactIndex + "_CI_" + IndexCI, Type("FormField"), GroupValueCI);
			PresentationField.Type = FormFieldType.InputField;
			PresentationField.DataPath = "ContactPersonsData[" + ContactIndex + "].ContactInformation[" + IndexCI + "].Presentation";
			PresentationField.TitleLocation = FormItemTitleLocation.None;
			PresentationField.ChoiceButton = EditInDialogIsAvailable;
			PresentationField.AutoMarkIncomplete = KindProperties.Mandatory;
			PresentationField.DropListWidth = 40;
			PresentationField.SetAction("OnChange", "Attachable_PresentationContactCIOnChange");
			PresentationField.SetAction("Clearing", "Attachable_PresentationContactCIClearing");
			If KindProperties.EditInDialogOnly Then
				PresentationField.TextEdit	= False;
				PresentationField.BackColor	= StyleColors.ContactInformationWithEditingInDialogColor;
			EndIf;
			If EditInDialogIsAvailable Then
				PresentationField.SetAction("StartChoice", "Attachable_PresentationContactCIStartChoice");
			EndIf;
			If ContactPersonContactInformationRow.Type = Enums.ContactInformationTypes.Other Then
				PresentationField.MultiLine = True;
				PresentationField.Height = 2;
				PresentationField.VerticalStretch = False;
			EndIf;
			
			If ContactInformationDrive.ForContactInformationTypeIsAvailableCommentInput(ContactPersonContactInformationRow.Type) Then
				
				PresentationField.AutoMaxWidth = False;
				PresentationField.MaxWidth = 27;
				
				FieldComment = Items.Add("CommentContact_" + ContactIndex + "_CI_" + IndexCI, Type("FormField"), GroupValueCI);
				FieldComment.Type = FormFieldType.InputField;
				FieldComment.DataPath = "ContactPersonsData[" + ContactIndex + "].ContactInformation[" + IndexCI + "].Comment";
				FieldComment.TitleLocation = FormItemTitleLocation.None;
				FieldComment.SkipOnInput = True;
				FieldComment.InputHint = NStr("en = 'Note'");
				FieldComment.AutoMaxWidth = False;
				FieldComment.MaxWidth = CommentFieldWidth;
				FieldComment.SetAction("OnChange", "Attachable_CommentContactCIOnChange");
				
			EndIf;
			
		EndDo;
		
	EndDo;
	
	LastContactIndex = ContactPersonsData.Count() - 1;
	AddContactFieldsCommand = Items["AddContactsContactInformationField_" + LastContactIndex];
	Items.Move(Items.AddContactFields, AddContactFieldsCommand.Parent, AddContactFieldsCommand);
	
EndProcedure

&AtServer
Procedure UpdateContactPersonsDataItem(Index, ContactPerson)
	
	ContactPersonsData[Index].ContactPerson = ContactPerson;
	ContactPersonAttributes = CommonUse.ObjectAttributesValues(ContactPerson, "Description, Position");
	ContactPersonsData[Index].Description = ContactPersonAttributes.Description;
	ContactPersonsData[Index].Position = ContactPersonAttributes.Position;
	ContactPersonsData[Index].Modified = True;
	
	ContactPersonsData[Index].ContactInformation.Clear();
	FillContactsContactInformation(ContactPerson, ContactPersonsData[Index]);
	
	Modified = True;
	RefreshContactPersonsItems();
	
EndProcedure

&AtClientAtServerNoContext
Procedure FillAlwaysShownKindsCI(CI, ContactPersonContactInformationKindProperties)
	
	For Each RowCI In ContactPersonContactInformationKindProperties Do
		
		NewRowCI = CI.Add();
		NewRowCI.Kind = RowCI.Kind;
		NewRowCI.Type = RowCI.Type;
		
	EndDo;
	
EndProcedure

&AtServer
Procedure FillContactsContactInformation(ContactPerson, ContactPersonsRow)
	
	For Each RowKindsCI In ContactPersonContactInformationKindProperties Do
		RowsCI = ContactPerson.ContactInformation.FindRows(New Structure("Kind", RowKindsCI.Kind));
		For Each RowCI In RowsCI Do
			ContactPersonContactInformationRow = ContactPersonsRow.ContactInformation.Add();
			FillPropertyValues(ContactPersonContactInformationRow, RowCI, "Type, Kind, Presentation, FieldValues");
			ContactPersonContactInformationRow.Comment = ContactInformationManagement.ContactInformationComment(ContactPersonContactInformationRow.FieldValues);
		EndDo;
	EndDo;
	
EndProcedure

&AtClient
Procedure DescriptionContact_OnChange(Item)
	
	ContactPersonIndex = Number(StrReplace(Item.Name, "DescriptionContact_", ""));
	ContactPersonsData[ContactPersonIndex].Modified = True;
	
EndProcedure

&AtClient
Procedure DescriptionContact_Opening(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	ContactPersonIndex = Number(StrReplace(Item.Name, "DescriptionContact_", ""));
	
	FormParameters = New Structure;
	FormParameters.Insert("ContactPersonIndex", ContactPersonIndex);
	FormParameters.Insert("ContactDescription", Item.EditText);
	FormParameters.Insert("Counterparty", Object.Ref);
	FormParameters.Insert("Position", ContactPersonsData[ContactPersonIndex].Position);
	
	If ValueIsFilled(ContactPersonsData[ContactPersonIndex].ContactPerson) Then
		FormParameters.Insert("Key", ContactPersonsData[ContactPersonIndex].ContactPerson);
	EndIf;
	
	If ContactPersonsData[ContactPersonIndex].Modified
		Or Not ContactPersonsData[ContactPersonIndex].Description = Item.EditText Then
		FormParameters.Insert("ContactInformation", ContactPersonsData[ContactPersonIndex].ContactInformation);
	EndIf;
	
	If Not ValueIsFilled(Object.Ref) Then
		Notification = New NotifyDescription(
			"ProcessCreateContactPersonQuery",
			ThisObject,
			New Structure("ContactPersonIndex, FormParameters", ContactPersonIndex, FormParameters));
		QueryText = NStr(
			"en = 'To switch to contact creation you must save your work.
			|Click OK to save and continue, or click Cancel to return.'");
		ShowQueryBox(Notification, QueryText, QuestionDialogMode.OKCancel);
		Return;
	EndIf;
	
	OpenForm("Catalog.ContactPersons.ObjectForm", FormParameters, ThisObject);
	
EndProcedure

&AtClient
Procedure PositionContact_OnChange(Item)
	
	ContactPersonIndex = Number(StrReplace(Item.Name, "PositionContact_", ""));
	ContactPersonsData[ContactPersonIndex].Modified = True;
	
EndProcedure

&AtClient
Procedure ProcessCreateContactPersonQuery(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.OK Then
		
		Write();
		
		If Not ValueIsFilled(Object.Ref) Then
			Return;
		EndIf;
		
		FormParameters = AdditionalParameters.FormParameters;
		FormParameters.Insert("Counterparty", Object.Ref);
		
		OpenForm("Catalog.ContactPersons.ObjectForm", FormParameters, ThisObject);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure AddContactsContactInformationKindIsSelected(SelectedItem, AdditionalParameters) Export
	
	If SelectedItem = Undefined Then
		Return;
	EndIf;
	
	AddContactsContactInformationServer(SelectedItem.Value, AdditionalParameters.ContactIndex);
	
EndProcedure

&AtServer
Procedure AddContactsContactInformationServer(AddedKind, ContactIndex)
	
	AddedType = CommonUse.ObjectAttributeValue(AddedKind, "Type");
	ContactPersonsDataRow = ContactPersonsData[ContactIndex];
	
	CIRowsCount = ContactPersonsDataRow.ContactInformation.Count();
	InsertIndex = CIRowsCount;
	
	For ReverseIndex = 1 To CIRowsCount Do
		CurrentIndex = CIRowsCount - ReverseIndex;
		If ContactPersonsDataRow.ContactInformation[CurrentIndex].Kind = AddedKind Then
			InsertIndex = CurrentIndex+1;
			Break;
		EndIf;
	EndDo;
	
	ContactInformationRow = ContactPersonsDataRow.ContactInformation.Insert(InsertIndex);
	ContactInformationRow.Kind = AddedKind;
	ContactInformationRow.Type = AddedType;
	
	RefreshContactPersonsItems();
	CurrentItem = Items["PresentationContact_" + ContactIndex + "_CI_" + InsertIndex];
	
EndProcedure

&AtClient
Procedure Attachable_ActionContactCIClick(Item)
	
	Underline1Pos = StrFind(Item.Name, "_", , , 1);
	Underline2Pos = StrFind(Item.Name, "_", , , 2);
	Underline3Pos = StrFind(Item.Name, "_", , , 3);
	
	IndexCP = Number(Mid(Item.Name, Underline1Pos + 1, Underline2Pos - Underline1Pos - 1));
	IndexCI = Number(Mid(Item.Name, Underline3Pos + 1));
	
	RowCI = ContactPersonsData[IndexCP].ContactInformation[IndexCI];
	
	DataCI = New Structure;
	DataCI.Insert("Type", RowCI.Type);
	DataCI.Insert("Presentation", RowCI.Presentation);
	DataCI.Insert("Owner", ContactPersonsData[IndexCP].ContactPerson);
	
	ContactInformationDriveClient.ActionCIClick(ThisObject, Item, DataCI);
	
EndProcedure

&AtClient
Procedure Attachable_PresentationContactCIOnChange(Item)
	
	Underline1Pos = StrFind(Item.Name, "_", , , 1);
	Underline2Pos = StrFind(Item.Name, "_", , , 2);
	Underline3Pos = StrFind(Item.Name, "_", , , 3);
	
	IndexCP = Number(Mid(Item.Name, Underline1Pos + 1, Underline2Pos - Underline1Pos - 1));
	IndexCI = Number(Mid(Item.Name, Underline3Pos + 1));
	
	ContactPersonsData[IndexCP].Modified = True;
	ContactInformationRow = ContactPersonsData[IndexCP].ContactInformation[IndexCI];
	
	If IsBlankString(ContactInformationRow.Presentation) Then
		ContactInformationRow.FieldValues = "";
	Else
		ContactInformationRow.FieldValues = ContactInformationDriveServerCall.ContactInformationXMLByPresentation(ContactInformationRow.Presentation, ContactInformationRow.Kind);
	EndIf;
	
EndProcedure

&AtClient
Procedure Attachable_PresentationContactCIStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	Underline1Pos = StrFind(Item.Name, "_", , , 1);
	Underline2Pos = StrFind(Item.Name, "_", , , 2);
	Underline3Pos = StrFind(Item.Name, "_", , , 3);
	
	IndexCP = Number(Mid(Item.Name, Underline1Pos + 1, Underline2Pos - Underline1Pos - 1));
	IndexCI = Number(Mid(Item.Name, Underline3Pos + 1));
	
	ContactPersonsData[IndexCP].Modified = True;
	ContactInformationRow = ContactPersonsData[IndexCP].ContactInformation[IndexCI];
	
	If ContactInformationRow.Presentation <> Item.EditText Then
		ContactInformationRow.Presentation = Item.EditText;
		Attachable_PresentationContactCIOnChange(Item);
		Modified = True;
	EndIf;
	
	FormParameters = ContactInformationManagementClient.ContactInformationFormParameters(
		ContactInformationRow.Kind,
		ContactInformationRow.FieldValues,
		ContactInformationRow.Presentation,
		ContactInformationRow.Comment);
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("IndexCP", IndexCP);
	AdditionalParameters.Insert("IndexCI", IndexCI);
	
	NotifyDescription = New NotifyDescription("ContactsContactInformationEditInDialogCompleted", ThisObject, AdditionalParameters);
	
	ContactInformationManagementClient.OpenContactInformationForm(FormParameters, , , , NotifyDescription);
	
EndProcedure

&AtClient
Procedure Attachable_PresentationContactCIClearing(Item, StandardProcessing)
	
	Underline1Pos = StrFind(Item.Name, "_", , , 1);
	Underline2Pos = StrFind(Item.Name, "_", , , 2);
	Underline3Pos = StrFind(Item.Name, "_", , , 3);
	
	IndexCP = Number(Mid(Item.Name, Underline1Pos + 1, Underline2Pos - Underline1Pos - 1));
	IndexCI = Number(Mid(Item.Name, Underline3Pos + 1));
	
	ContactPersonsData[IndexCP].Modified = True;
	ContactInformationRow = ContactPersonsData[IndexCP].ContactInformation[IndexCI];
	ContactInformationRow.FieldValues = "";
	
EndProcedure

&AtClient
Procedure Attachable_CommentContactCIOnChange(Item)
	
	Underline1Pos = StrFind(Item.Name, "_", , , 1);
	Underline2Pos = StrFind(Item.Name, "_", , , 2);
	Underline3Pos = StrFind(Item.Name, "_", , , 3);
	
	IndexCP = Number(Mid(Item.Name, Underline1Pos + 1, Underline2Pos - Underline1Pos - 1));
	IndexCI = Number(Mid(Item.Name, Underline3Pos + 1));
	ContactPersonsData[IndexCP].Modified = True;
	ContactInformationRow = ContactPersonsData[IndexCP].ContactInformation[IndexCI];
	
	ExpectedKind = ?(IsBlankString(ContactInformationRow.FieldValues), ContactInformationRow.Kind, Undefined);
	ContactInformationDriveServerCall.SetContactInformationComment(ContactInformationRow.FieldValues, ContactInformationRow.Comment, ExpectedKind);
	
EndProcedure

&AtClient
Procedure ContactsContactInformationEditInDialogCompleted(Result, AdditionalParameters) Export
	
	If TypeOf(Result) <> Type("Structure") Then
		Return;
	EndIf;
	
	ContactInformationRow = ContactPersonsData[AdditionalParameters.IndexCP].ContactInformation[AdditionalParameters.IndexCI];
	ContactPersonsData[AdditionalParameters.IndexCP].Modified = True;

	ContactInformationRow.Presentation = Result.Presentation;
	ContactInformationRow.FieldValues = Result.ContactInformation;
	ContactInformationRow.Comment = Result.Comment;
	
	Modified = True;
	
EndProcedure

&AtServer
Procedure WriteContactPersonsData(CurrentObject)
	
	SetPrivilegedMode(True);
	
	ContactPersonsToBeNotified = New Array;
	
	For Each RowCP In ContactPersonsData Do
		
		If IsBlankString(RowCP.Description) Or Not RowCP.Modified Then
			Continue;
		EndIf;
		
		If ValueIsFilled(RowCP.ContactPerson) Then
			ContactPersonObject = RowCP.ContactPerson.GetObject();
		EndIf;
		
		If Not ValueIsFilled(RowCP.ContactPerson) Or ContactPersonObject = Undefined Then
			
			ContactPersonObject = Catalogs.ContactPersons.CreateItem();
			ContactPersonObject.Fill(CurrentObject.Ref);
			
			If CurrentObject.AdditionalProperties.Property("NewDefaultContactPerson") Then
				ContactPersonObject.SetNewObjectRef(CurrentObject.AdditionalProperties.NewDefaultContactPerson);
				CurrentObject.AdditionalProperties.Delete("NewDefaultContactPerson");
			EndIf;
			
		EndIf;
		
		FillPropertyValues(ContactPersonObject, RowCP, "Description, Position");
		ContactPersonObject.ContactInformation.Clear();
		
		For Each RowCI In RowCP.ContactInformation Do
			ContactInformationManagement.WriteContactInformation(ContactPersonObject, RowCI.FieldValues, RowCI.Kind, RowCI.Type);
		EndDo;
		
		ContactPersonObject.Write();
		
		If ValueIsFilled(RowCP.ContactPerson) Then
			ContactPersonsToBeNotified.Add(ContactPersonObject.Ref);
		EndIf;
		
		RowCP.ContactPerson = ContactPersonObject.Ref;
		
	EndDo;
	
	CurrentObject.AdditionalProperties.Insert("ContactPersonsToBeNotified", ContactPersonsToBeNotified);
	
EndProcedure

&AtServer
Procedure ContactPersonsFillCheck(Cancel)
	
	For Each RowCP In ContactPersonsData Do
		
		If Not IsBlankString(RowCP.Description) Then
			Continue;
		EndIf;
		
		AttributeName = "ContactPersonsData[" + ContactPersonsData.IndexOf(RowCP) + "].Description";
		For Each RowCI In RowCP.ContactInformation Do
			If Not IsBlankString(RowCI.FieldValues) Or Not IsBlankString(RowCI.Presentation) Then
				CommonUseClientServer.MessageToUser(NStr("en = 'Contact name is empty.'"), , AttributeName, , Cancel);
				Break;
			EndIf;
		EndDo;
		
	EndDo;
	
EndProcedure

&AtServer
Procedure ContactPersonsContactInformationFillCheck(Cancel)
	
	Filter = New Structure("Kind");
	
	For Each RowCP In ContactPersonsData Do
		
		If IsBlankString(RowCP.Description) Then
			Continue;
		EndIf;
		
		IndexCP = ContactPersonsData.IndexOf(RowCP);
		
		For Each RowCI In RowCP.ContactInformation Do
			
			Filter.Kind = RowCI.Kind;
			FoundRows = ContactPersonContactInformationKindProperties.FindRows(Filter);
			If FoundRows.Count() = 0 Then
				Continue;
			EndIf;
			KindPropertiesRow = FoundRows[0];
			IndexCI = RowCP.ContactInformation.IndexOf(RowCI);
			AttributeName = "ContactPersonsData["+IndexCP+"].ContactInformation["+IndexCI+"].Presentation";
			
			If KindPropertiesRow.Mandatory And IsBlankString(RowCI.Presentation)
				And Not MoreFilledConactInformationRowsOfAKindExist(RowCP, RowCI, RowCI.Kind) Then
				
				ErrorsFound = True;
				
				CommonUseClientServer.MessageToUser(
					StringFunctionsClientServer.SubstituteParametersInString(
						NStr("en = '""%1"" contact information is not filled in.'"),
						KindPropertiesRow.KindPresentation),
					,
					AttributeName,
					,
					Cancel);
				
			ElsIf Not IsBlankString(RowCI.Presentation) And KindPropertiesRow.CheckValidity Then
				
				Cancel = Not ContactInformationManagement.ValidateContactInformation(RowCI.Presentation, RowCI.FieldValues, RowCI.Kind, RowCI.Type, AttributeName) = 0;
				
			EndIf;
			
		EndDo;
		
	EndDo;
	
EndProcedure

&AtServer
Function MoreFilledConactInformationRowsOfAKindExist(Val RowCP, Val RowCI, Val Kind)
	
	ThisKindRows = RowCP.ContactInformation.FindRows(New Structure("Kind", Kind));
	
	For Each KindRow In ThisKindRows Do
		
		If KindRow <> RowCI And Not IsBlankString(KindRow.Presentation) Then
			Return True;
		EndIf;
		
	EndDo;
	
	Return False;
	
EndFunction

#EndRegion

#Region AdditionalInformationPanel

&AtServer
Procedure ReadAdditionalInformationPanelData()
	
	Items.AdditionalInformationPanel.Visible = ValueIsFilled(Object.Ref);
	
	If Not ValueIsFilled(Object.Ref) Then
		Return;
	EndIf;
	
	LargeFont = StyleFonts.InformationPanelLargeFont;
	SmallFont  = StyleFonts.InformationPanelSmallFont;
	
	Query = New Query;
	Query.SetParameter("Counterparty", Object.Ref);
	
	If ViewStatemenOfAccount Then
		
		Query.Text = 
		"SELECT ALLOWED
		|	AccountsPayableBalance.Counterparty AS Counterparty,
		|	-AccountsPayableBalance.AmountBalance AS AmountBalance
		|INTO TT_PRM
		|FROM
		|	AccumulationRegister.AccountsPayable.Balance(, Counterparty = &Counterparty) AS AccountsPayableBalance
		|
		|UNION ALL
		|
		|SELECT
		|	AccountsReceivableBalance.Counterparty,
		|	AccountsReceivableBalance.AmountBalance
		|FROM
		|	AccumulationRegister.AccountsReceivable.Balance(, Counterparty = &Counterparty) AS AccountsReceivableBalance
		|
		|UNION ALL
		|
		|SELECT
		|	MiscellaneousPayableBalance.Counterparty,
		|	MiscellaneousPayableBalance.AmountBalance
		|FROM
		|	AccumulationRegister.MiscellaneousPayable.Balance(, Counterparty = &Counterparty) AS MiscellaneousPayableBalance
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	TT_PRM.Counterparty AS Counterparty,
		|	SUM(TT_PRM.AmountBalance) AS Amount
		|FROM
		|	TT_PRM AS TT_PRM
		|
		|GROUP BY
		|	TT_PRM.Counterparty";
		
		Sel = Query.Execute().Select();
		If Sel.Next() Then
			Amount = Sel.Amount;
		Else
			Amount = 0;
		EndIf;
		
		FSParts = New Array;
		If Amount < 0 Then
			FSParts.Add(New FormattedString(NStr("en = 'Amount owed'") + " ", LargeFont));
			Amount = -Amount;
		Else
			FSParts.Add(New FormattedString(NStr("en = 'Amount due'") + " ", LargeFont));
		EndIf;
		
		AmountInWords = Format(Amount, "NFD=2; NDS=,; NGS=' '; NZ=0,00");
		CommaPosition = StrFind(AmountInWords, ",");
		NumberParts = New Array;
		NumberParts.Add(New FormattedString(Left(AmountInWords, CommaPosition), LargeFont));
		NumberParts.Add(New FormattedString(Mid(AmountInWords, CommaPosition+1), SmallFont));
		FSParts.Add(New FormattedString(NumberParts, , , , "DebtBalance"));
		
		FSParts.Add(" " + DriveReUse.GetAccountCurrency());
		
		Items.DebtBalance.Title = New FormattedString(FSParts, , StyleColors.MinorInscriptionText);
		
	EndIf;
	
	If ViewNetSales Then
		
		Query.Text =
		"SELECT ALLOWED
		|	SUM(SalesTurnovers.AmountTurnover) AS Amount
		|FROM
		|	AccumulationRegister.Sales.Turnovers AS SalesTurnovers
		|		INNER JOIN Document.SalesInvoice AS SalesInvoice
		|		ON SalesTurnovers.Document = SalesInvoice.Ref
		|WHERE
		|	SalesInvoice.Counterparty = &Counterparty
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED TOP 1
		|	SalesInvoice.Ref AS Document,
		|	SalesInvoice.Date AS Date
		|FROM
		|	Document.SalesInvoice AS SalesInvoice
		|WHERE
		|	SalesInvoice.Posted
		|	AND SalesInvoice.Counterparty = &Counterparty
		|
		|ORDER BY
		|	SalesInvoice.PointInTime DESC";
		
		QueryResults = Query.ExecuteBatch();
		
		Sel = QueryResults[0].Select();
		If Sel.Next() Then
			Amount = Sel.Amount;
		Else
			Amount = 0;
		EndIf;
		
		FSParts = New Array;
		FSParts.Add(New FormattedString(NStr("en = 'Sales'") + " ", LargeFont));
		
		AmountInWords = Format(Amount, "NFD=2; NDS=,; NGS=' '; NZ=0,00");
		CommaPosition = StrFind(AmountInWords, ",");
		NumberParts = New Array;
		NumberParts.Add(New FormattedString(Left(AmountInWords, CommaPosition), LargeFont));
		NumberParts.Add(New FormattedString(Mid(AmountInWords, CommaPosition + 1), SmallFont));
		FSParts.Add(New FormattedString(NumberParts, , , , "Sales"));
		
		FSParts.Add(" " + DriveReUse.GetAccountCurrency());
		
		Items.SalesAmount.Title = New FormattedString(FSParts, , StyleColors.MinorInscriptionText);
		
		Sel = QueryResults[1].Select();
		If Sel.Next() Then
			Date = Sel.Date;
			Hyperlink = GetURL(Sel.Document);
		Else
			Date = '00010101';
			Hyperlink = "";
		EndIf;
		
		FSParts = New Array;
		FSParts.Add(NStr("en = 'Last sale'") + " ");
		FSParts.Add(New FormattedString(Format(Date, "L=en; DLF=D; DE=<none>"), , , , Hyperlink));
		
		Items.LastSale.Title = New FormattedString(FSParts, LargeFont, StyleColors.MinorInscriptionText);
		
	EndIf;
	
	Query.Text =
	"SELECT ALLOWED DISTINCT
	|	EventParticipants.Ref AS Ref
	|INTO TT_Events
	|FROM
	|	Document.Event.Participants AS EventParticipants
	|WHERE
	|	EventParticipants.Contact = &Counterparty
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED TOP 1
	|	Events.Ref AS Event,
	|	Events.EventBegin AS Date
	|FROM
	|	TT_Events AS TT_Events
	|		INNER JOIN Document.Event AS Events
	|		ON TT_Events.Ref = Events.Ref
	|WHERE
	|	NOT Events.DeletionMark
	|
	|ORDER BY
	|	Events.EventBegin DESC";
	
	Sel = Query.Execute().Select();
	If Sel.Next() Then
		Date = Sel.Date;
		Hyperlink = GetURL(Sel.Event);
	Else
		Date = '00010101';
		Hyperlink = "";
	EndIf;
	
	FSParts = New Array;
	FSParts.Add(NStr("en = 'Last event'") + " ");
	FSParts.Add(New FormattedString(Format(Date, "L=en; DLF=D; DE=<none>"), , , , Hyperlink));
	
	Items.LastEvent.Title = New FormattedString(FSParts, LargeFont, StyleColors.MinorInscriptionText);
	
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
		|	CounterpartiesTags.Tag AS Tag,
		|	CounterpartiesTags.Tag.DeletionMark AS DeletionMark,
		|	CounterpartiesTags.Tag.Description AS Description
		|FROM
		|	Catalog.Counterparties.Tags AS CounterpartiesTags
		|WHERE
		|	CounterpartiesTags.Ref = &Ref";
	
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

#Region CounterpartiesChecks

&AtClientAtServerNoContext
Procedure ExecuteAllChecks(Form)
	
	GenerateDuplicateChecksPresentation(Form);
	
	WorkWithCounterpartiesClientServerOverridable.GenerateDataChecksPresentation(Form);
	
EndProcedure

&AtClientAtServerNoContext
Procedure GenerateDuplicateChecksPresentation(Form)
	
	Object = Form.Object;
	ErrorDescription = "";
	
	If Not IsBlankString(Object.TIN) Then
		
		DuplicatesArray = GetCounterpartyDuplicatesServer(TrimAll(Object.TIN), Object.Ref);
		
		DuplicatesCount = DuplicatesArray.Count();
		
		If DuplicatesCount > 0 Then
						
			If DuplicatesCount = 1 Then
				CounterpartyDeclension = NStr("en = 'counterparty'");
			ElsIf DuplicatesCount < 5 Then
				CounterpartyDeclension = NStr("en = 'counterparties'");
			Else
				CounterpartyDeclension = NStr("en = 'counterparties'");
			EndIf;
			
			ErrorDescription = NStr("en = 'Found %2 %3 with the same %1'");
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersInString(ErrorDescription, 
				NStr("en = 'TIN'"),
				DuplicatesCount,
				CounterpartyDeclension);
			
		EndIf;
	EndIf;
	
	Form.DuplicateChecksPresentation = New FormattedString(ErrorDescription, , Form.ErrorCounterpartyHighlightColor, , "ShowDuplicates");
	
EndProcedure

&AtServerNoContext
Function GetCounterpartyDuplicatesServer(TIN, ExcludingRef)
	
	Return Catalogs.Counterparties.CheckCatalogDuplicatesCounterpartiesByTIN(TIN, ExcludingRef);
	
EndFunction

&AtClientAtServerNoContext
Function IsLegalEntity(CounterpartyKind)
	
	Return CounterpartyKind = PredefinedValue("Enum.CounterpartyType.LegalEntity");
	
EndFunction

#EndRegion

#Region CounterpartyContactInformationDrive

&AtServer
Procedure AddContactInformationServer(AddingKind, SetShowInFormAlways = False) Export
	
	ContactInformationDrive.AddContactInformation(ThisObject, AddingKind, SetShowInFormAlways);
	
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

// StandardSubsystems.AdditionalReportsAndDataProcessors
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
// End StandardSubsystems.AdditionalReportsAndDataProcessors

// StandardSubsystems.Printing
&AtClient
Procedure Attachable_ExecutePrintCommand(Command)
	PrintManagementClient.ExecuteConnectedPrintCommand(Command, ThisObject, Object);
EndProcedure
// End StandardSubsystems.Printing

// StandardSubsystems.Properties
&AtClient
Procedure Attachable_EditContentOfProperties(Command)
	
	PropertiesManagementClient.EditContentOfProperties(ThisForm, Object.Ref);
	
EndProcedure

&AtServer
Procedure UpdateAdditionalAttributesItems()
	
	PropertiesManagement.UpdateAdditionalAttributesItems(ThisForm, FormAttributeToValue("Object"));
	
EndProcedure
// End StandardSubsystems.Properties

#EndRegion
