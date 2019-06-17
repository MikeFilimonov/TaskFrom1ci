
#Region FormEvents

// Procedure - On create on read at server
//
// Parameters:
//  Form			- ManagedForm	 - Form for placing contact information
//  OwnerCI			- AnyRef	 - contact information owner
//  WidthKindField	- Number	 - the width of the kind field of contact information by default
//
Procedure OnCreateOnReadAtServer(Form, OwnerCI = Undefined, WidthKindField = 9) Export
	
	If OwnerCI = Undefined Then
		OwnerCI = Form.Object.Ref;
	EndIf;
	
	OwnerCIMetadata = OwnerCI.Metadata();
	
	// Determination of auxiliary information
	MetadataObjectFullName = OwnerCIMetadata.FullName();
	GroupKindsCI = Catalogs.ContactInformationTypes[StrReplace(MetadataObjectFullName, ".", "")];
	
	ContactLineIdentifierAttributeExists = 
		OwnerCIMetadata.TabularSections.ContactInformation.Attributes.Find("ContactLineIdentifier") <> Undefined;
	
	// Creation of tables-attributes, if there is no
	AddContactInformationFormAttributes(Form, ContactLineIdentifierAttributeExists);
	
	// Caching information on the available types of contact information in the created table
	ReadContactInformationKindProperties(Form, GroupKindsCI, ContactLineIdentifierAttributeExists);
	
	If ContactLineIdentifierAttributeExists Then
		// Reading existing contact information in the created object table to display
		FillContactInformationTableWithContactLineIdentifiers(Form, OwnerCI);
	Else
		// Reading existing contact information in the created object table to display
		FillContactInformationTable(Form, OwnerCI);
		// Single preparation items and form commands 
		InitializeForm(Form);
	EndIf;
	
	// Rebuilding the form items on the information from the table to display
	RefreshContactInformationItems(Form, WidthKindField);
	
EndProcedure

Procedure BeforeWriteAtServer(Form, CurrentObject) Export
	
	CurrentObject.ContactInformation.Clear();
	
	For Each DataCI In Form.ContactInformation Do
		If Form.ContactLineIdentifierAttributeExists Then
			ContactInformationManagement.WriteContactInformation(CurrentObject, DataCI.FieldValues, DataCI.Kind, DataCI.Type, DataCI.ContactLineIdentifier);
		Else
			ContactInformationManagement.WriteContactInformation(CurrentObject, DataCI.FieldValues, DataCI.Kind, DataCI.Type);
		EndIf;
	EndDo;
	
EndProcedure

Procedure FillCheckProcessingAtServer(Form, Cancel) Export
	
	IsError	= False;
	Filter	= New Structure("Kind");
	
	For Each TableRow In Form.ContactInformation Do
		
		Filter.Kind	= TableRow.Kind;
		FindedRows	= Form.ContactInformationKindProperties.FindRows(Filter);
		If FindedRows.Count() = 0 Then
			Continue;
		EndIf;
		KindProperties = FindedRows[0];
		Index = Form.ContactInformation.IndexOf(TableRow);
		AttributeName = "ContactInformation["+Index+"].Presentation";
		
		If KindProperties.Mandatory AND IsBlankString(TableRow.Presentation)
			AND Not IsAnotherFilledRowsKindCI(Form, TableRow, TableRow.Kind) Then
			// And no another rows with multiply values.
			
			IsError = True;
			CommonUseClientServer.MessageToUser(
				StrTemplate(NStr("en = 'Contact information kind ""%1"" is not filled.'"), KindProperties.KindPresentation),,, AttributeName);
			
		ElsIf KindProperties.CheckValidity AND Not IsBlankString(TableRow.Presentation) Then
			
			ObjectCI = ContactInformationInternal.ContactInformationDeserialization(TableRow.FieldValues, TableRow.Kind);
			If TableRow.Comment <> Undefined Then
				ObjectCI.Comment = TableRow.Comment;
			EndIf;
			ObjectCI.Presentation = TableRow.Presentation;
			
			// Check
			If TableRow.Type = Enums.ContactInformationTypes.EmailAddress Then
				If Not EmailIsCorrect(ObjectCI, AttributeName) Then
					IsError = True;
				EndIf;
			ElsIf TableRow.Type = Enums.ContactInformationTypes.Address Then
				If ContactInformationManagement.ValidateContactInformation(TableRow.Presentation, TableRow.FieldValues, TableRow.Kind, TableRow.Type, AttributeName) > 0 Then
					IsError = True;
				EndIf;
			Else
				// Other types of contact information do not check
			EndIf;
			
		EndIf;
		
	EndDo;
	
	If IsError Then
		Cancel = True;
	EndIf;
	
EndProcedure

#EndRegion

#Region ProgramInterface

// Procedure updates form items in accordance with the data in table-attribute
//
// Parameters:
//  Form	 - ManagedForm	 - form-owner contact information
//
Procedure RefreshContactInformationItems(Form, WidthKindField = 9) Export
	
	AddingCommands = Form.Items.Find("ContactInformationAdding");
	If AddingCommands <> Undefined Then
		AddingCommands.Visible = ContactInformationDriveClientServer.KindsListForAddingContactInformation(Form).Count() > 0;
	EndIf;
	
	If Form.ContactLineIdentifierAttributeExists Then
		ContactLineIDs = Form.LineIdentifiers.UnLoad().UnloadColumn("Value");
	Else
		ContactLineIDs = New Array;
		ContactLineIDs.Add(0);
	EndIf;
	
	Items = Form.Items;
	DeletingItems = New Array;
	
	If Form.ContactLineIdentifierAttributeExists Then
		
		For Each LineID In ContactLineIDs Do
			ValueGroup = Items.Find("ContactInformation" + LineID + "ContactInformationValues");
			If ValueGroup = Undefined Then
				Continue;
			EndIf;
			For Each Item Из ValueGroup.ChildItems Do
				DeletingItems.Add(Item);
			EndDo;
		EndDo;
		InitializeForm(Form);
		
		WidthCommentField = 11;
		
		For Each DeletingItem In DeletingItems Do
			Items.Delete(DeletingItem);
		EndDo;
		
	Else
		
		For Each GroupItems In Items.ContactInformationValues.ChildItems Do
			DeletingItems.Add(GroupItems);
		EndDo;
		
		WidthCommentField = 11;
		If DeletingItems.Count() > 0 Then
			WidthKindField = Items["KindCI_0"].Width;
		EndIf;
		
		For Each DeletingItem In DeletingItems Do
			Items.Delete(DeletingItem);
		EndDo;
		
	EndIf;

	Filter = New Structure("Kind");
	
	For Each LineID In ContactLineIDs Do
		
		If Form.ContactLineIdentifierAttributeExists Then
			ContactInformationLines = Form.ContactInformation.FindRows(New Structure("ContactLineIdentifier", LineID));
			If ContactInformationLines.Count() = 0 Then
				ContactInformationLines = NewPortionOfContactInformation(Form, Form.Object.Ref, LineID);
			Endif;
			Parent = Items["ContactInformation" + LineID + "ContactInformationValues"];
		Else
			ContactInformationLines = Form.ContactInformation;
			Parent = Items.ContactInformationValues;
		EndIf;
		
		For Each DataCI In ContactInformationLines Do
			
			IndexCI = Form.ContactInformation.IndexOf(DataCI);
			Filter.Kind = DataCI.Kind;
			FindedRows = Form.ContactInformationKindProperties.FindRows(Filter);
			If FindedRows.Count() = 0 Then
				Continue;
			EndIf;
			KindProperties = FindedRows[0];
			
			GroupValueCI = Items.Add("CI_" + IndexCI, Type("FormGroup"), Parent);
			GroupValueCI.Type			= FormGroupType.UsualGroup;
			GroupValueCI.Title			= DataCI.Kind;
			GroupValueCI.Representation	= UsualGroupRepresentation.None;
			GroupValueCI.Group			= ChildFormItemsGroup.Horizontal;
			GroupValueCI.ThroughAlign	= ThroughAlign.Use;
			GroupValueCI.ShowTitle		= False;
			
			DecorationAction = Items.Add("ActionCI_" + IndexCI, Type("FormDecoration"), GroupValueCI);
			DecorationAction.Type					= FormDecorationType.Picture;
			DecorationAction.Picture				= ActionPictureByContactInformationType(DataCI.Type);
			DecorationAction.Hyperlink				= True;
			DecorationAction.Width					= 2;
			DecorationAction.Height					= 1;
			DecorationAction.VerticalAlignInGroup	= ItemVerticalAlign.Center;
			DecorationAction.SetAction("Click", "Attachable_ActionCIClick");
			
			FieldKind = Items.Add("KindCI_" + IndexCI, Type("FormField"), GroupValueCI);
			FieldKind.Type				= FormFieldType.LabelField;
			FieldKind.DataPath			= "ContactInformation[" + IndexCI + "].Kind";
			FieldKind.TitleLocation		= FormItemTitleLocation.None;
			FieldKind.Width				= WidthKindField;
			FieldKind.HorizontalStretch	= False;
			
			EditInDialogAvailable = ForContactInformationTypeIsAvailableEditInDialog(DataCI.Type);
			
			FieldPresentation = Items.Add("PresentationCI_" + IndexCI, Type("FormField"), GroupValueCI);
			FieldPresentation.Type					= FormFieldType.InputField;
			FieldPresentation.DataPath				= "ContactInformation[" + IndexCI + "].Presentation";
			FieldPresentation.TitleLocation			= FormItemTitleLocation.None;
			FieldPresentation.ChoiceButton			= EditInDialogAvailable;
			FieldPresentation.AutoMarkIncomplete	= KindProperties.Mandatory;
			FieldPresentation.DropListWidth			= 40;
			FieldPresentation.SetAction("OnChange", "Attachable_PresentationCIOnChange");
			FieldPresentation.SetAction("Clearing", "Attachable_PresentationCIClearing");
			If KindProperties.EditInDialogOnly Then
				FieldPresentation.TextEdit	= False;
				FieldPresentation.BackColor	= StyleColors.ContactInformationWithEditingInDialogColor;
			EndIf;
			If EditInDialogAvailable Then
				FieldPresentation.SetAction("StartChoice", "Attachable_PresentationCIStartChoice");
			EndIf;
			
			// Context menu commands: show address on GoogleMaps
			If DataCI.Type = Enums.ContactInformationTypes.Address Then
				
				AddContextMenuCommand(Form,
					"ContextMenuMapGoogle_" + IndexCI,
					PictureLib.GoogleMaps,
					NStr("en = 'Address on Google Maps'"),
					NStr("en = 'Show address on Google Maps'"),
					FieldPresentation
				);
				
			EndIf;
			
			If ForContactInformationTypeIsAvailableCommentInput(DataCI.Type) Then
				
				FieldPresentation.AutoMaxWidth	= False;
				FieldPresentation.MaxWidth		= 27;
				
				FieldComment = Items.Add("CommentCI_" + IndexCI, Type("FormField"), GroupValueCI);
				FieldComment.Type			= FormFieldType.InputField;
				FieldComment.DataPath = "ContactInformation[" + IndexCI + "].Comment";
				FieldComment.TitleLocation	= FormItemTitleLocation.None;
				FieldComment.SkipOnInput	= True;
				FieldComment.InputHint		= NStr("en = 'Note'");
				FieldComment.AutoMaxWidth	= False;
				FieldComment.MaxWidth		= WidthCommentField;
				FieldComment.SetAction("OnChange", "Attachable_CommentCIOnChange");
				
			EndIf;
			
		EndDo;
		
	EndDo;
EndProcedure

// The procedure adds the input fields of the form of contact information on the form
//
// Parameters:
//  Form					 - ManagedForm	 - contact information form-owner
//  AddingKind				 - CatalogRef.ContactInformationTypes	 - kindfor adding
//  SetShowInFormAlways		 - Boolean	 - sign setting "ShowInFormAlways"
//
Procedure AddContactInformation(Form, AddingKind, SetShowInFormAlways = False, ContactLineIdentifier = 0) Export
	
	If SetShowInFormAlways Then
		SetFlagShowInFormAlways(AddingKind);
		FindedRows = Form.ContactInformationKindProperties.FindRows(New Structure("Kind", AddingKind));
		If FindedRows.Count() > 0 Then
			FindedRows[0].ShowInFormAlways = True;
		EndIf;
	EndIf;
	
	If SetShowInFormAlways AND Form.ContactLineIdentifierAttributeExists Then
		
		For Each LineID In Form.LineIdentifiers Do
			NumberCollectionItems = Form.ContactInformation.Count();
			InsertIndex = NumberCollectionItems;
			
			For ReverseIndex = 1 To NumberCollectionItems Do
				CurrentIndex = NumberCollectionItems - ReverseIndex;
				If Form.ContactInformation[CurrentIndex].Kind = AddingKind
					AND Form.ContactInformation[CurrentIndex].ContactLineIdentifier = LineID.Value Then
					InsertIndex = CurrentIndex+1;
					Break;
				EndIf;
			EndDo;
			
			DataCI = Form.ContactInformation.Insert(InsertIndex);
			DataCI.Kind = AddingKind;
			DataCI.Type = CommonUse.ObjectAttributeValue(AddingKind, "Type");
			DataCI.ContactLineIdentifier = LineID.Value;
			
		EndDo;
		
	Else
		
		NumberCollectionItems = Form.ContactInformation.Count();
		InsertIndex = NumberCollectionItems;
		
		For ReverseIndex = 1 To NumberCollectionItems Do
			CurrentIndex = NumberCollectionItems - ReverseIndex;
			
			If Form.ContactLineIdentifierAttributeExists
				AND Form.ContactInformation[CurrentIndex].ContactLineIdentifier <> ContactLineIdentifier Then
				Continue;
			EndIf;
			
			If Form.ContactInformation[CurrentIndex].Kind <> AddingKind Then
				Continue;
			EndIf;
			
			InsertIndex = CurrentIndex+1;
			Break;
		EndDo;
	
		DataCI = Form.ContactInformation.Insert(InsertIndex);
		DataCI.Kind = AddingKind;
		DataCI.Type = CommonUse.ObjectAttributeValue(AddingKind, "Type");
		If Form.ContactLineIdentifierAttributeExists Then
			DataCI.ContactLineIdentifier = ContactLineIdentifier;
		EndIf;
		
	EndIf;
	
	RefreshContactInformationItems(Form);
	Form.CurrentItem = Form.Items["PresentationCI_" + InsertIndex];
	
EndProcedure

// Function - For contact information type is available edit in dialog
//
// Parameters:
//  TypeCI	 - EnumRef.ContactInformationTypes	 - type for which availability is checked editing in dialog
// 
// Returned value:
//  Boolean - flag of editing in dialog
//
Function ForContactInformationTypeIsAvailableEditInDialog(TypeCI) Export
	
	If TypeCI = Enums.ContactInformationTypes.Address Then
		Return True;
	ElsIf TypeCI = Enums.ContactInformationTypes.Phone Then
		Return True;
	ElsIf TypeCI = Enums.ContactInformationTypes.Fax Then
		Return True;
	Else
		Return False;
	EndIf;
	
EndFunction

// Function - For contact information type is available comment input
//
// Parameters:
//  TypeCI	 - EnumRef.ContactInformationTypes	 - type for which you checked the availability of a comment input
// 
// Returned value:
//  Boolean - a sign of the availability of the comment field on the form
//
Function ForContactInformationTypeIsAvailableCommentInput(TypeCI) Export
	
	If TypeCI = Enums.ContactInformationTypes.Address Or TypeCI = Enums.ContactInformationTypes.Other Then
		Return False;
	Else
		Return True;
	EndIf;
	
EndFunction

// Function - Action picture by contact information type
//
// Parameters:
//  TypeCI	 - EnumRef.ContactInformationTypes	 - type for which you get the picture
// 
// Returned value:
//  Picture - to display the icon
//
Function ActionPictureByContactInformationType(TypeCI) Export
	
	If TypeCI = Enums.ContactInformationTypes.Phone Then
		ActionPicture = PictureLib.ContactInformationPhone;
	ElsIf TypeCI = Enums.ContactInformationTypes.EmailAddress Then
		ActionPicture = PictureLib.ContactInformationEmail;
	ElsIf TypeCI = Enums.ContactInformationTypes.Address Then
		ActionPicture = PictureLib.ContactInformationAddress;
	ElsIf TypeCI = Enums.ContactInformationTypes.Skype Then
		ActionPicture = PictureLib.ContactInformationSkype;
	ElsIf TypeCI = Enums.ContactInformationTypes.WebPage Then
		ActionPicture = PictureLib.ContactInformationWebpage;
	ElsIf TypeCI = Enums.ContactInformationTypes.Fax Then
		ActionPicture = PictureLib.ContactInformationFax;
	ElsIf TypeCI = Enums.ContactInformationTypes.Other Then
		ActionPicture = PictureLib.ContactInformationOther;
	Else
		ActionPicture = PictureLib.Empty;
	EndIf;
	
	Return ActionPicture;
	
EndFunction

// The function checks the correctness of e-mail addresses
//
// Parameters:
//  ObjectCI	 - ObjectXDTO	 - contact information XDTO-object
//  AttributeName - string	 - form attribute name, which will be connected with an error message
// 
// Returned value:
//  Boolean - sign of correctness
//
Function EmailIsCorrect(ObjectCI, Val AttributeName = "") Export
	
	ErrorString = "";
	
	EmailAddress = ObjectCI.Content;
	Namespace = ContactInformationClientServerCached.Namespace();
	If EmailAddress <> Undefined AND EmailAddress.Type() = XDTOFactory.Type(Namespace, "Email") Then
		Try
			Result = CommonUseClientServer.SplitStringWithEmailAddresses(EmailAddress.Value);
			If Result.Count() > 1 Then
				
				ErrorString = NStr("en = 'You can enter only one email address'");
				
			EndIf;
		Except
			ErrorString = BriefErrorDescription(ErrorInfo());
		EndTry;
	EndIf;
	
	If Not IsBlankString(ErrorString) Then
		CommonUseClientServer.MessageToUser(ErrorString,,AttributeName);
	EndIf;
	
	Return IsBlankString(ErrorString);
	
EndFunction

// Function returns a contact information types table to the default order
// 
// Return value:
//  ValueTable - Standard order of contact information types to display in the interface
//
Function OrderTypesCI() Export
	
	OrderTypesCI = New ValueTable;
	OrderTypesCI.Columns.Add("Type", New TypeDescription("EnumRef.ContactInformationTypes"));
	OrderTypesCI.Columns.Add("Order", New TypeDescription("Number"));
	
	RowTypes = OrderTypesCI.Add();
	RowTypes.Type	= Enums.ContactInformationTypes.Phone;
	RowTypes.Order	= 1;
	
	RowTypes = OrderTypesCI.Add();
	RowTypes.Type	= Enums.ContactInformationTypes.EmailAddress;
	RowTypes.Order	= 2;
	
	RowTypes = OrderTypesCI.Add();
	RowTypes.Type	= Enums.ContactInformationTypes.Address;
	RowTypes.Order	= 3;
	
	RowTypes = OrderTypesCI.Add();
	RowTypes.Type	= Enums.ContactInformationTypes.Skype;
	RowTypes.Order	= 4;
	
	RowTypes = OrderTypesCI.Add();
	RowTypes.Type	= Enums.ContactInformationTypes.WebPage;
	RowTypes.Order	= 5;
	
	RowTypes = OrderTypesCI.Add();
	RowTypes.Type	= Enums.ContactInformationTypes.Fax;
	RowTypes.Order	= 6;
	
	RowTypes = OrderTypesCI.Add();
	RowTypes.Type	= Enums.ContactInformationTypes.Other;
	RowTypes.Order	= 7;
	
	Return OrderTypesCI;
	
EndFunction

// The procedure sets the setting of contact information "ShowInFormAlways"
//
// Parameters:
//  ContactInformationKind	 - CatalogRef.ContactInformationTypes	 - kind for which the setting is set
//  SwitchOn				 - boolean	 - setting value
//
Procedure SetFlagShowInFormAlways(ContactInformationKind, SwitchOn = True) Export
	
	RecordSet = InformationRegisters.ContactInformationVisibilitySettings.CreateRecordSet();
	
	// Read record set.
	RecordSet.Filter.Kind.Set(ContactInformationKind);
	RecordSet.Read();
	
	If RecordSet.Count() = 0 Then
		Record = RecordSet.Add();
	ElsIf RecordSet[0].ShowInFormAlways = SwitchOn Then
		Return; // Setting already, additional action is not required
	Else
		Record = RecordSet[0];
	EndIf;
	
	Record.Kind = ContactInformationKind;
	Record.ShowInFormAlways = SwitchOn;
	
	RecordSet.Write();
	
EndProcedure

#EndRegion

#Region UpdateResults

// The procedure for updating / refilled with predefined kinds of contact information. Initial filling of the base.
//
Procedure SetPropertiesPredefinedContactInformationTypes() Export
	
	Counterparties_SetKindProperties();
	ContactPersons_SetKindProperties();
	Companies_SetKindProperties();
	Individuals_SetKindProperties();
	BusinessUnits_SetKindProperties();
	Users_SetKindProperties();
	ShippingAddresses_SetKindProperties();
	Leads_SetKindProperties();
	
EndProcedure

Procedure Counterparties_SetKindProperties()
	
	KindParameters = ContactInformationManagement.ContactInformationKindParameters("Phone");
	KindParameters.Kind						= Catalogs.ContactInformationTypes.CounterpartyPhone;
	KindParameters.Order					= 1;
	KindParameters.CanChangeEditMode		= True;
	KindParameters.EditInDialogOnly			= False;
	KindParameters.Mandatory				= False;
	KindParameters.AllowMultipleValueInput	= True;
	ContactInformationManagement.SetContactInformationKindProperties(KindParameters);
	SetFlagShowInFormAlways(KindParameters.Kind);
	
	KindParameters = ContactInformationManagement.ContactInformationKindParameters("EmailAddress");
	KindParameters.Kind						= Catalogs.ContactInformationTypes.CounterpartyEmail;
	KindParameters.Order					= 2;
	KindParameters.CanChangeEditMode		= True;
	KindParameters.EditInDialogOnly			= False;
	KindParameters.Mandatory				= False;
	KindParameters.AllowMultipleValueInput	= True;
	KindParameters.VerificationSettings.CheckValidity	= True;
	ContactInformationManagement.SetContactInformationKindProperties(KindParameters);
	SetFlagShowInFormAlways(KindParameters.Kind);
	
	KindParameters = ContactInformationManagement.ContactInformationKindParameters("Address");
	KindParameters.Kind						= Catalogs.ContactInformationTypes.CounterpartyLegalAddress;
	KindParameters.Order					= 3;
	KindParameters.CanChangeEditMode		= True;
	KindParameters.EditInDialogOnly			= False;
	KindParameters.Mandatory				= False;
	KindParameters.AllowMultipleValueInput	= False;
	KindParameters.VerificationSettings.DomesticAddressOnly				= False;
	KindParameters.VerificationSettings.CheckValidity					= False;
	KindParameters.VerificationSettings.HideObsoleteAddresses			= False;
	KindParameters.VerificationSettings.IncludeCountryInPresentation	= True;
	ContactInformationManagement.SetContactInformationKindProperties(KindParameters);
	SetFlagShowInFormAlways(KindParameters.Kind);
	
	KindParameters = ContactInformationManagement.ContactInformationKindParameters("Address");
	KindParameters.Kind						= Catalogs.ContactInformationTypes.CounterpartyActualAddress;
	KindParameters.Order					= 4;
	KindParameters.CanChangeEditMode		= True;
	KindParameters.EditInDialogOnly			= False;
	KindParameters.Mandatory				= False;
	KindParameters.AllowMultipleValueInput	= False;
	KindParameters.VerificationSettings.DomesticAddressOnly				= False;
	KindParameters.VerificationSettings.CheckValidity					= False;
	KindParameters.VerificationSettings.HideObsoleteAddresses			= False;
	KindParameters.VerificationSettings.IncludeCountryInPresentation	= True;
	ContactInformationManagement.SetContactInformationKindProperties(KindParameters);
	
	KindParameters = ContactInformationManagement.ContactInformationKindParameters("Address");
	KindParameters.Kind						= Catalogs.ContactInformationTypes.CounterpartyDeliveryAddress;
	KindParameters.Order					= 5;
	KindParameters.CanChangeEditMode		= True;
	KindParameters.EditInDialogOnly			= False;
	KindParameters.Mandatory				= False;
	KindParameters.AllowMultipleValueInput	= True;
	KindParameters.VerificationSettings.DomesticAddressOnly				= False;
	KindParameters.VerificationSettings.CheckValidity					= False;
	KindParameters.VerificationSettings.HideObsoleteAddresses			= False;
	KindParameters.VerificationSettings.IncludeCountryInPresentation	= False;
	ContactInformationManagement.SetContactInformationKindProperties(KindParameters);
	
	KindParameters = ContactInformationManagement.ContactInformationKindParameters("Skype");
	KindParameters.Kind						= Catalogs.ContactInformationTypes.CounterpartySkype;
	KindParameters.Order					= 6;
	KindParameters.CanChangeEditMode		= True;
	KindParameters.EditInDialogOnly			= False;
	KindParameters.Mandatory				= False;
	KindParameters.AllowMultipleValueInput	= False;
	ContactInformationManagement.SetContactInformationKindProperties(KindParameters);
	
	KindParameters = ContactInformationManagement.ContactInformationKindParameters("WebPage");
	KindParameters.Kind						= Catalogs.ContactInformationTypes.CounterpartyWebpage;
	KindParameters.Order					= 7;
	KindParameters.CanChangeEditMode		= True;
	KindParameters.EditInDialogOnly			= False;
	KindParameters.Mandatory				= False;
	KindParameters.AllowMultipleValueInput	= False;
	ContactInformationManagement.SetContactInformationKindProperties(KindParameters);
	
	KindParameters = ContactInformationManagement.ContactInformationKindParameters("Fax");
	KindParameters.Kind						= Catalogs.ContactInformationTypes.CounterpartyFax;
	KindParameters.Order					= 8;
	KindParameters.CanChangeEditMode		= True;
	KindParameters.EditInDialogOnly			= False;
	KindParameters.Mandatory				= False;
	KindParameters.AllowMultipleValueInput	= False;
	ContactInformationManagement.SetContactInformationKindProperties(KindParameters);
	
	KindParameters = ContactInformationManagement.ContactInformationKindParameters("Address");
	KindParameters.Kind						= Catalogs.ContactInformationTypes.CounterpartyPostalAddress;
	KindParameters.Order					= 9;
	KindParameters.CanChangeEditMode		= True;
	KindParameters.EditInDialogOnly			= False;
	KindParameters.Mandatory				= False;
	KindParameters.AllowMultipleValueInput	= False;
	KindParameters.VerificationSettings.DomesticAddressOnly				= False;
	KindParameters.VerificationSettings.CheckValidity					= False;
	KindParameters.VerificationSettings.HideObsoleteAddresses			= False;
	KindParameters.VerificationSettings.IncludeCountryInPresentation	= False;
	ContactInformationManagement.SetContactInformationKindProperties(KindParameters);
	
	KindParameters = ContactInformationManagement.ContactInformationKindParameters("Other");
	KindParameters.Kind						= Catalogs.ContactInformationTypes.CounterpartyOtherInformation;
	KindParameters.Order					= 10;
	KindParameters.CanChangeEditMode		= True;
	KindParameters.EditInDialogOnly			= False;
	KindParameters.Mandatory				= False;
	KindParameters.AllowMultipleValueInput	= False;
	ContactInformationManagement.SetContactInformationKindProperties(KindParameters);
	
EndProcedure

Procedure ContactPersons_SetKindProperties()
	
	KindParameters = ContactInformationManagement.ContactInformationKindParameters("Phone");
	KindParameters.Kind						= Catalogs.ContactInformationTypes.ContactPersonPhone;
	KindParameters.Order					= 1;
	KindParameters.CanChangeEditMode		= True;
	KindParameters.EditInDialogOnly			= False;
	KindParameters.Mandatory				= False;
	KindParameters.AllowMultipleValueInput	= True;
	ContactInformationManagement.SetContactInformationKindProperties(KindParameters);
	SetFlagShowInFormAlways(KindParameters.Kind);
	
	KindParameters = ContactInformationManagement.ContactInformationKindParameters("EmailAddress");
	KindParameters.Kind						= Catalogs.ContactInformationTypes.ContactPersonEmail;
	KindParameters.Order					= 2;
	KindParameters.CanChangeEditMode		= True;
	KindParameters.EditInDialogOnly			= False;
	KindParameters.Mandatory				= False;
	KindParameters.AllowMultipleValueInput	= True;
	KindParameters.VerificationSettings.CheckValidity	= True;
	ContactInformationManagement.SetContactInformationKindProperties(KindParameters);
	SetFlagShowInFormAlways(KindParameters.Kind);
	
	KindParameters = ContactInformationManagement.ContactInformationKindParameters("Skype");
	KindParameters.Kind						= Catalogs.ContactInformationTypes.ContactPersonSkype;
	KindParameters.Order					= 3;
	KindParameters.CanChangeEditMode		= True;
	KindParameters.EditInDialogOnly			= False;
	KindParameters.Mandatory				= False;
	KindParameters.AllowMultipleValueInput	= False;
	ContactInformationManagement.SetContactInformationKindProperties(KindParameters);
	
	KindParameters = ContactInformationManagement.ContactInformationKindParameters("WebPage");
	KindParameters.Kind						= Catalogs.ContactInformationTypes.ContactPersonSocialNetwork;
	KindParameters.Order					= 4;
	KindParameters.CanChangeEditMode		= True;
	KindParameters.EditInDialogOnly			= False;
	KindParameters.Mandatory				= False;
	KindParameters.AllowMultipleValueInput	= True;
	ContactInformationManagement.SetContactInformationKindProperties(KindParameters);
	
	KindParameters = ContactInformationManagement.ContactInformationKindParameters("Other");
	KindParameters.Kind						= Catalogs.ContactInformationTypes.ContactPersonMessenger;
	KindParameters.Order					= 5;
	KindParameters.CanChangeEditMode		= True;
	KindParameters.EditInDialogOnly			= False;
	KindParameters.Mandatory				= False;
	KindParameters.AllowMultipleValueInput	= True;
	ContactInformationManagement.SetContactInformationKindProperties(KindParameters);
	
EndProcedure

Procedure Companies_SetKindProperties()
	
	KindParameters = ContactInformationManagement.ContactInformationKindParameters("Address");
	KindParameters.Kind						= Catalogs.ContactInformationTypes.CompanyLegalAddress;
	KindParameters.Order					= 1;
	KindParameters.CanChangeEditMode		= True;
	KindParameters.EditInDialogOnly			= True;
	KindParameters.Mandatory				= False;
	KindParameters.AllowMultipleValueInput	= False;
	KindParameters.VerificationSettings.DomesticAddressOnly				= False;
	KindParameters.VerificationSettings.CheckValidity					= False;
	KindParameters.VerificationSettings.HideObsoleteAddresses			= False;
	KindParameters.VerificationSettings.IncludeCountryInPresentation	= True;
	ContactInformationManagement.SetContactInformationKindProperties(KindParameters);
	SetFlagShowInFormAlways(KindParameters.Kind);
	
	KindParameters = ContactInformationManagement.ContactInformationKindParameters("Address");
	KindParameters.Kind						= Catalogs.ContactInformationTypes.CompanyActualAddress;
	KindParameters.Order					= 2;
	KindParameters.CanChangeEditMode		= True;
	KindParameters.EditInDialogOnly			= True;
	KindParameters.Mandatory				= False;
	KindParameters.AllowMultipleValueInput	= False;
	KindParameters.VerificationSettings.DomesticAddressOnly				= False;
	KindParameters.VerificationSettings.CheckValidity					= False;
	KindParameters.VerificationSettings.HideObsoleteAddresses			= False;
	KindParameters.VerificationSettings.IncludeCountryInPresentation	= True;
	ContactInformationManagement.SetContactInformationKindProperties(KindParameters);
	SetFlagShowInFormAlways(KindParameters.Kind);
	
	KindParameters = ContactInformationManagement.ContactInformationKindParameters("Address");
	KindParameters.Kind						= Catalogs.ContactInformationTypes.CompanyPostalAddress;
	KindParameters.Order					= 3;
	KindParameters.CanChangeEditMode		= True;
	KindParameters.EditInDialogOnly			= False;
	KindParameters.Mandatory				= False;
	KindParameters.AllowMultipleValueInput	= False;
	KindParameters.VerificationSettings.DomesticAddressOnly				= False;
	KindParameters.VerificationSettings.CheckValidity					= False;
	KindParameters.VerificationSettings.HideObsoleteAddresses			= False;
	KindParameters.VerificationSettings.IncludeCountryInPresentation	= False;
	ContactInformationManagement.SetContactInformationKindProperties(KindParameters);
	SetFlagShowInFormAlways(KindParameters.Kind);
	
	KindParameters = ContactInformationManagement.ContactInformationKindParameters("Phone");
	KindParameters.Kind						= Catalogs.ContactInformationTypes.CompanyPhone;
	KindParameters.Order					= 4;
	KindParameters.CanChangeEditMode		= True;
	KindParameters.EditInDialogOnly			= False;
	KindParameters.Mandatory				= False;
	KindParameters.AllowMultipleValueInput	= True;
	ContactInformationManagement.SetContactInformationKindProperties(KindParameters);
	SetFlagShowInFormAlways(KindParameters.Kind);
	
	KindParameters = ContactInformationManagement.ContactInformationKindParameters("EmailAddress");
	KindParameters.Kind						= Catalogs.ContactInformationTypes.CompanyEmail;
	KindParameters.Order					= 5;
	KindParameters.CanChangeEditMode		= True;
	KindParameters.EditInDialogOnly			= False;
	KindParameters.Mandatory				= False;
	KindParameters.AllowMultipleValueInput	= True;
	KindParameters.VerificationSettings.CheckValidity	= True;
	ContactInformationManagement.SetContactInformationKindProperties(KindParameters);
	SetFlagShowInFormAlways(KindParameters.Kind);
	
	KindParameters = ContactInformationManagement.ContactInformationKindParameters("WebPage");
	KindParameters.Kind						= Catalogs.ContactInformationTypes.CompanyWebpage;
	KindParameters.Order					= 6;
	KindParameters.CanChangeEditMode		= True;
	KindParameters.EditInDialogOnly			= False;
	KindParameters.Mandatory				= False;
	KindParameters.AllowMultipleValueInput	= False;
	ContactInformationManagement.SetContactInformationKindProperties(KindParameters);
	ContactInformationDrive.SetFlagShowInFormAlways(KindParameters.Kind);
	
	KindParameters = ContactInformationManagement.ContactInformationKindParameters("Fax");
	KindParameters.Kind						= Catalogs.ContactInformationTypes.CompanyFax;
	KindParameters.Order					= 6;
	KindParameters.CanChangeEditMode		= True;
	KindParameters.EditInDialogOnly			= False;
	KindParameters.Mandatory				= False;
	KindParameters.AllowMultipleValueInput	= False;
	ContactInformationManagement.SetContactInformationKindProperties(KindParameters);
	
	KindParameters = ContactInformationManagement.ContactInformationKindParameters("Other");
	KindParameters.Kind						= Catalogs.ContactInformationTypes.CompanyOtherInformation;
	KindParameters.Order					= 7;
	KindParameters.CanChangeEditMode		= True;
	KindParameters.EditInDialogOnly			= False;
	KindParameters.Mandatory				= False;
	KindParameters.AllowMultipleValueInput	= False;
	ContactInformationManagement.SetContactInformationKindProperties(KindParameters);
	
EndProcedure

Procedure Individuals_SetKindProperties()
	
	KindParameters = ContactInformationManagement.ContactInformationKindParameters("Phone");
	KindParameters.Kind						= Catalogs.ContactInformationTypes.IndividualPhone;
	KindParameters.Order					= 1;
	KindParameters.CanChangeEditMode		= True;
	KindParameters.EditInDialogOnly			= False;
	KindParameters.Mandatory				= False;
	KindParameters.AllowMultipleValueInput	= True;
	ContactInformationManagement.SetContactInformationKindProperties(KindParameters);
	SetFlagShowInFormAlways(KindParameters.Kind);
	
	KindParameters = ContactInformationManagement.ContactInformationKindParameters("Address");
	KindParameters.Kind						= Catalogs.ContactInformationTypes.IndividualActualAddress;
	KindParameters.Order					= 2;
	KindParameters.CanChangeEditMode		= False;
	KindParameters.EditInDialogOnly			= True;
	KindParameters.Mandatory				= False;
	KindParameters.AllowMultipleValueInput	= False;
	KindParameters.VerificationSettings.DomesticAddressOnly				= False;
	KindParameters.VerificationSettings.CheckValidity					= False;
	KindParameters.VerificationSettings.HideObsoleteAddresses			= False;
	KindParameters.VerificationSettings.IncludeCountryInPresentation	= True;
	ContactInformationManagement.SetContactInformationKindProperties(KindParameters);
	SetFlagShowInFormAlways(KindParameters.Kind);
	
	KindParameters = ContactInformationManagement.ContactInformationKindParameters("Address");
	KindParameters.Kind						= Catalogs.ContactInformationTypes.IndividualPostalAddress;
	KindParameters.Order					= 4;
	KindParameters.CanChangeEditMode		= False;
	KindParameters.EditInDialogOnly			= True;
	KindParameters.Mandatory				= False;
	KindParameters.AllowMultipleValueInput	= False;
	KindParameters.VerificationSettings.DomesticAddressOnly				= False;
	KindParameters.VerificationSettings.CheckValidity					= False;
	KindParameters.VerificationSettings.HideObsoleteAddresses			= False;
	KindParameters.VerificationSettings.IncludeCountryInPresentation	= True;
	ContactInformationManagement.SetContactInformationKindProperties(KindParameters);
	
	KindParameters = ContactInformationManagement.ContactInformationKindParameters("EmailAddress");
	KindParameters.Kind						= Catalogs.ContactInformationTypes.IndividualEmail;
	KindParameters.Order					= 6;
	KindParameters.CanChangeEditMode		= True;
	KindParameters.EditInDialogOnly			= False;
	KindParameters.Mandatory				= False;
	KindParameters.AllowMultipleValueInput	= True;
	KindParameters.VerificationSettings.CheckValidity	= True;
	ContactInformationManagement.SetContactInformationKindProperties(KindParameters);
	SetFlagShowInFormAlways(KindParameters.Kind);
	
	KindParameters = ContactInformationManagement.ContactInformationKindParameters("Other");
	KindParameters.Kind						= Catalogs.ContactInformationTypes.IndividualOtherInformation;
	KindParameters.Order					= 7;
	KindParameters.CanChangeEditMode		= True;
	KindParameters.EditInDialogOnly			= False;
	KindParameters.Mandatory				= False;
	KindParameters.AllowMultipleValueInput	= False;
	ContactInformationManagement.SetContactInformationKindProperties(KindParameters);
	
EndProcedure

Procedure BusinessUnits_SetKindProperties()
	
	KindParameters = ContactInformationManagement.ContactInformationKindParameters("Phone");
	KindParameters.Kind						= Catalogs.ContactInformationTypes.BusinessUnitsPhone;
	KindParameters.Order					= 1;
	KindParameters.CanChangeEditMode		= True;
	KindParameters.EditInDialogOnly			= False;
	KindParameters.Mandatory				= False;
	KindParameters.AllowMultipleValueInput	= True;
	ContactInformationManagement.SetContactInformationKindProperties(KindParameters);
	SetFlagShowInFormAlways(KindParameters.Kind);
	
	KindParameters = ContactInformationManagement.ContactInformationKindParameters("Address");
	KindParameters.Kind						= Catalogs.ContactInformationTypes.BusinessUnitsActualAddress;
	KindParameters.Order					= 2;
	KindParameters.CanChangeEditMode		= True;
	KindParameters.EditInDialogOnly			= True;
	KindParameters.Mandatory				= False;
	KindParameters.AllowMultipleValueInput	= False;
	KindParameters.VerificationSettings.DomesticAddressOnly				= False;
	KindParameters.VerificationSettings.CheckValidity					= False;
	KindParameters.VerificationSettings.HideObsoleteAddresses			= False;
	KindParameters.VerificationSettings.IncludeCountryInPresentation	= False;
	ContactInformationManagement.SetContactInformationKindProperties(KindParameters);
	SetFlagShowInFormAlways(KindParameters.Kind);
	
EndProcedure

Procedure Users_SetKindProperties()
	
	KindParameters = ContactInformationManagement.ContactInformationKindParameters("Phone");
	KindParameters.Kind						= Catalogs.ContactInformationTypes.UserPhone;
	KindParameters.Order					= 1;
	KindParameters.CanChangeEditMode		= True;
	KindParameters.EditInDialogOnly			= False;
	KindParameters.Mandatory				= False;
	KindParameters.AllowMultipleValueInput	= True;
	ContactInformationManagement.SetContactInformationKindProperties(KindParameters);
	SetFlagShowInFormAlways(KindParameters.Kind);
	
	KindParameters = ContactInformationManagement.ContactInformationKindParameters("EmailAddress");
	KindParameters.Kind						= Catalogs.ContactInformationTypes.UserEmail;
	KindParameters.Order					= 2;
	KindParameters.CanChangeEditMode		= True;
	KindParameters.EditInDialogOnly			= False;
	KindParameters.Mandatory				= False;
	KindParameters.AllowMultipleValueInput	= True;
	KindParameters.VerificationSettings.CheckValidity		= True;
	ContactInformationManagement.SetContactInformationKindProperties(KindParameters);
	SetFlagShowInFormAlways(KindParameters.Kind);
	
	KindParameters = ContactInformationManagement.ContactInformationKindParameters("WebPage");
	KindParameters.Kind						= Catalogs.ContactInformationTypes.UserWebpage;
	KindParameters.Order					= 3;
	KindParameters.CanChangeEditMode		= True;
	KindParameters.EditInDialogOnly			= False;
	KindParameters.Mandatory				= False;
	KindParameters.AllowMultipleValueInput	= True;
	ContactInformationManagement.SetContactInformationKindProperties(KindParameters);
	SetFlagShowInFormAlways(KindParameters.Kind);
	
EndProcedure

Procedure Leads_SetKindProperties() Export
	
	KindParameters = ContactInformationManagement.ContactInformationKindParameters("Phone");
	KindParameters.Kind						= Catalogs.ContactInformationTypes.LeadPhone;
	KindParameters.Order					= 1;
	KindParameters.CanChangeEditMode		= True;
	KindParameters.EditInDialogOnly			= False;
	KindParameters.Mandatory				= False;
	KindParameters.AllowMultipleValueInput	= True;
	ContactInformationManagement.SetContactInformationKindProperties(KindParameters);
	SetFlagShowInFormAlways(KindParameters.Kind);
	
	KindParameters = ContactInformationManagement.ContactInformationKindParameters("EmailAddress");
	KindParameters.Kind						= Catalogs.ContactInformationTypes.LeadEmail;
	KindParameters.Order					= 2;
	KindParameters.CanChangeEditMode		= True;
	KindParameters.EditInDialogOnly			= False;
	KindParameters.Mandatory				= False;
	KindParameters.AllowMultipleValueInput	= True;
	KindParameters.VerificationSettings.CheckValidity	= True;
	ContactInformationManagement.SetContactInformationKindProperties(KindParameters);
	SetFlagShowInFormAlways(KindParameters.Kind);

	KindParameters = ContactInformationManagement.ContactInformationKindParameters("Skype");
	KindParameters.Kind						= Catalogs.ContactInformationTypes.LeadSkype;
	KindParameters.Order					= 3;
	KindParameters.CanChangeEditMode		= True;
	KindParameters.EditInDialogOnly			= False;
	KindParameters.Mandatory				= False;
	KindParameters.AllowMultipleValueInput	= False;
	ContactInformationManagement.SetContactInformationKindProperties(KindParameters);
	
	KindParameters = ContactInformationManagement.ContactInformationKindParameters("WebPage");
	KindParameters.Kind						= Catalogs.ContactInformationTypes.LeadSocialNetwork;
	KindParameters.Order					= 4;
	KindParameters.CanChangeEditMode		= True;
	KindParameters.EditInDialogOnly			= False;
	KindParameters.Mandatory				= False;
	KindParameters.AllowMultipleValueInput	= True;
	ContactInformationManagement.SetContactInformationKindProperties(KindParameters);
	
	KindParameters = ContactInformationManagement.ContactInformationKindParameters("Other");
	KindParameters.Kind						= Catalogs.ContactInformationTypes.LeadMessenger;
	KindParameters.Order					= 5;
	KindParameters.CanChangeEditMode		= True;
	KindParameters.EditInDialogOnly			= False;
	KindParameters.Mandatory				= False;
	KindParameters.AllowMultipleValueInput	= True;
	ContactInformationManagement.SetContactInformationKindProperties(KindParameters);
	
EndProcedure

// Updates with predefined kinds of contact information for Shipping addresses.
//
Procedure ShippingAddresses_SetKindProperties() Export
	
	KindParameters = ContactInformationManagement.ContactInformationKindParameters("Address");
	KindParameters.Kind						= Catalogs.ContactInformationTypes.ShippingAddress;
	KindParameters.Order					= 1;
	KindParameters.CanChangeEditMode		= True;
	KindParameters.EditInDialogOnly			= False;
	KindParameters.Mandatory				= False;
	KindParameters.AllowMultipleValueInput	= False;
	VerificationSettings = KindParameters.VerificationSettings;
	VerificationSettings.DomesticAddressOnly			= False;
	VerificationSettings.CheckValidity					= False;
	VerificationSettings.HideObsoleteAddresses			= False;
	VerificationSettings.IncludeCountryInPresentation	= True;
	ContactInformationManagement.SetContactInformationKindProperties(KindParameters);
	SetFlagShowInFormAlways(KindParameters.Kind);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

Procedure AddContactInformationFormAttributes(Form, ContactLineIdentifierAttributeExists)
	
	ArrayAddingAttributes	= New Array;
	FormAttributesList		= Form.GetAttributes();
	
	CreateTableContactInformation = True;
	CreateTableContactInformationKindProperties	= True;
	
	For Each Attribute In FormAttributesList Do
		If Attribute.Name = "ContactInformation" Then
			CreateTableContactInformation = False;
		ElsIf Attribute.Name = "ContactInformationKindProperties" Then
			CreateTableContactInformationKindProperties = False;
		EndIf;
	EndDo;
	
	DescriptionString	= New TypeDescription("String");
	DescriptionBoolean	= New TypeDescription("Boolean");
	
	If CreateTableContactInformation Then
		
		ArrayAddingAttributes.Add(New FormAttribute("ContactLineIdentifierAttributeExists", DescriptionBoolean));
		
		TableName = "ContactInformation";
		ArrayAddingAttributes.Add(New FormAttribute(TableName, New TypeDescription("ValueTable"),,, True));
		ArrayAddingAttributes.Add(New FormAttribute("Kind", New TypeDescription("CatalogRef.ContactInformationTypes"), TableName));
		ArrayAddingAttributes.Add(New FormAttribute("Type", New TypeDescription("EnumRef.ContactInformationTypes"), TableName));
		ArrayAddingAttributes.Add(New FormAttribute("Presentation", New TypeDescription("String", , New StringQualifiers(500)), TableName));
		ArrayAddingAttributes.Add(New FormAttribute("Comment", DescriptionString, TableName));
		ArrayAddingAttributes.Add(New FormAttribute("FieldValues", DescriptionString, TableName));
		
		If ContactLineIdentifierAttributeExists Then
			ArrayAddingAttributes.Add(New FormAttribute("ContactLineIdentifier",
				New TypeDescription("Number", New NumberQualifiers(7, 0, AllowedSign.Nonnegative)),
				TableName));
		EndIf;
		
	EndIf;
	
	If CreateTableContactInformationKindProperties Then
		
		TableName = "ContactInformationKindProperties";
		ArrayAddingAttributes.Add(New FormAttribute(TableName, New TypeDescription("ValueTable")));
		ArrayAddingAttributes.Add(New FormAttribute("Kind", New TypeDescription("CatalogRef.ContactInformationTypes"), TableName));
		ArrayAddingAttributes.Add(New FormAttribute("KindPresentation", DescriptionString, TableName));
		ArrayAddingAttributes.Add(New FormAttribute("Type", New TypeDescription("EnumRef.ContactInformationTypes"), TableName));
		ArrayAddingAttributes.Add(New FormAttribute("ShowInFormAlways", DescriptionBoolean, TableName));
		ArrayAddingAttributes.Add(New FormAttribute("AllowMultipleValueInput", DescriptionBoolean, TableName));
		ArrayAddingAttributes.Add(New FormAttribute("Mandatory", DescriptionBoolean, TableName));
		ArrayAddingAttributes.Add(New FormAttribute("CheckValidity", DescriptionBoolean, TableName));
		ArrayAddingAttributes.Add(New FormAttribute("EditInDialogOnly", DescriptionBoolean, TableName));
		
	EndIf;
	
	If ArrayAddingAttributes.Count() > 0 Then
		Form.ChangeAttributes(ArrayAddingAttributes);
	EndIf;
	
EndProcedure

Procedure ReadContactInformationKindProperties(Form, GroupKindsCI, ContactLineIdentifierAttributeExists)
	
	Form.ContactLineIdentifierAttributeExists = ContactLineIdentifierAttributeExists;
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	OrderTypesCI.Type AS Type,
		|	OrderTypesCI.Order AS Order
		|INTO ttOrderTypes
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
		|		LEFT JOIN ttOrderTypes AS ttOrderTypes
		|		ON ContactInformationTypes.Type = ttOrderTypes.Type
		|		LEFT JOIN InformationRegister.ContactInformationVisibilitySettings AS ContactInformationVisibilitySettings
		|		ON ContactInformationTypes.Ref = ContactInformationVisibilitySettings.Kind
		|WHERE
		|	ContactInformationTypes.DeletionMark = FALSE
		|	AND (ContactInformationTypes.Parent = &GroupKindsCI
		|			OR ContactInformationTypes.Parent.Parent = &GroupKindsCI)
		|	AND NOT ContactInformationTypes.IsFolder
		|
		|ORDER BY
		|	ttOrderTypes.Order,
		|	ContactInformationTypes.AdditionalOrderingAttribute";
	
	Query.SetParameter("OrderTypesCI", OrderTypesCI());
	Query.SetParameter("GroupKindsCI", GroupKindsCI);
	
	PropertiesTable = Query.Execute().Unload();
	Form.ContactInformationKindProperties.Load(PropertiesTable);
	
EndProcedure

Procedure FillContactInformationTable(Form, OwnerCI)
	
	Form.ContactInformation.Clear();
	
	Query = New Query;
	Query.Текст = 
		"SELECT
		|	OrderTypes.Type,
		|	OrderTypes.Order
		|INTO ttOrderTypes
		|FROM
		|	&OrderTypes AS OrderTypes
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	ContactInformationTypes.Ref AS Kind,
		|	ContactInformationTypes.Type AS Type,
		|	ContactInformationTypes.AdditionalOrderingAttribute AS OrderKinds,
		|	ttOrderTypes.Order AS OrderTypes
		|INTO ttAlwaysShowKinds
		|FROM
		|	Catalog.ContactInformationTypes AS ContactInformationTypes
		|		LEFT JOIN ttOrderTypes AS ttOrderTypes
		|		ON ContactInformationTypes.Type = ttOrderTypes.Type
		|WHERE
		|	ContactInformationTypes.Ref IN(&AlwaysShowKinds)
		|
		|INDEX BY
		|	Kind
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	OwnerContactInformation.Kind AS Kind,
		|	OwnerContactInformation.Type,
		|	OwnerContactInformation.Presentation,
		|	OwnerContactInformation.FieldValues,
		|	OwnerContactInformation.Kind.AdditionalOrderingAttribute AS OrderKinds,
		|	ttOrderTypes.Order AS OrderTypes
		|INTO ttDataCI
		|FROM
		|	Catalog.Counterparties.ContactInformation AS OwnerContactInformation
		|		LEFT JOIN ttOrderTypes AS ttOrderTypes
		|		ON OwnerContactInformation.Type = ttOrderTypes.Type
		|WHERE
		|	OwnerContactInformation.Ref = &OwnerCI
		|	AND OwnerContactInformation.Kind <> VALUE(Catalog.ContactInformationTypes.EmptyRef)
		|
		|INDEX BY
		|	Kind
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	ISNULL(ttDataCI.Kind, ttAlwaysShowKinds.Kind) AS Kind,
		|	ISNULL(ttDataCI.Type, ttAlwaysShowKinds.Type) AS Type,
		|	ISNULL(ttDataCI.Presentation, """") AS Presentation,
		|	ISNULL(ttDataCI.FieldValues, """") AS FieldValues,
		|	ISNULL(ttDataCI.OrderTypes, ttAlwaysShowKinds.OrderTypes) AS OrderTypes,
		|	ISNULL(ttDataCI.OrderKinds, ttAlwaysShowKinds.OrderKinds) AS OrderKinds
		|FROM
		|	ttAlwaysShowKinds AS ttAlwaysShowKinds
		|		FULL JOIN ttDataCI AS ttDataCI
		|		ON ttAlwaysShowKinds.Kind = ttDataCI.Kind
		|
		|ORDER BY
		|	OrderTypes,
		|	OrderKinds";
	
	Query.Text = StrReplace(Query.Text, "Catalog.Counterparties", OwnerCI.Metadata().FullName());
	Query.SetParameter("OwnerCI",		OwnerCI);
	Query.SetParameter("OrderTypes",	OrderTypesCI());
	Query.SetParameter("AlwaysShowKinds", 
		Form.ContactInformationKindProperties.Unload(New Structure("ShowInFormAlways", True), "Kind"));
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		NewRow = Form.ContactInformation.Add();
		FillPropertyValues(NewRow, Selection);
		NewRow.Comment = ContactInformationManagement.ContactInformationComment(Selection.FieldValues);
	EndDo;
	
EndProcedure

Procedure FillContactInformationTableWithContactLineIdentifiers(Form, OwnerCI)
	
	Form.ContactInformation.Clear();
	
	Query = New Query;
	Query.Текст = 
		"SELECT
		|	OrderTypes.Type AS Type,
		|	OrderTypes.Order AS Order
		|INTO ttOrderTypes
		|FROM
		|	&OrderTypes AS OrderTypes
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	ContactLineIdentifiers.Value AS ContactLineIdentifier
		|INTO ttLineIdentifiers
		|FROM
		|	&LineIdentifiers AS ContactLineIdentifiers
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	ContactInformationTypes.Ref AS Kind,
		|	ContactInformationTypes.Type AS Type,
		|	ContactInformationTypes.AdditionalOrderingAttribute AS OrderKinds,
		|	ttOrderTypes.Order AS OrderTypes,
		|	ttLineIdentifiers.ContactLineIdentifier AS ContactLineIdentifier
		|INTO ttAlwaysShowKinds
		|FROM
		|	Catalog.ContactInformationTypes AS ContactInformationTypes
		|		LEFT JOIN ttOrderTypes AS ttOrderTypes
		|		ON ContactInformationTypes.Type = ttOrderTypes.Type,
		|	ttLineIdentifiers AS ttLineIdentifiers
		|WHERE
		|	ContactInformationTypes.Ref IN(&AlwaysShowKinds)
		|
		|INDEX BY
		|	Kind
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	LeadsContactInformation.Kind AS Kind,
		|	LeadsContactInformation.Type AS Type,
		|	LeadsContactInformation.Presentation AS Presentation,
		|	LeadsContactInformation.FieldValues AS FieldValues,
		|	ISNULL(LeadsContactInformation.ContactLineIdentifier, 0) AS ContactLineIdentifier,
		|	LeadsContactInformation.Kind.AdditionalOrderingAttribute AS OrderKinds,
		|	ttOrderTypes.Order AS OrderTypes
		|INTO ttDataCI
		|FROM
		|	Catalog.Leads.ContactInformation AS LeadsContactInformation
		|		LEFT JOIN ttOrderTypes AS ttOrderTypes
		|		ON LeadsContactInformation.Type = ttOrderTypes.Type
		|WHERE
		|	LeadsContactInformation.Ref = &OwnerCI
		|	AND LeadsContactInformation.Kind <> VALUE(Catalog.ContactInformationTypes.EmptyRef)
		|
		|INDEX BY
		|	Kind
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	ISNULL(ttDataCI.Kind, ttAlwaysShowKinds.Kind) AS Kind,
		|	ISNULL(ttDataCI.Type, ttAlwaysShowKinds.Type) AS Type,
		|	ISNULL(ttDataCI.Presentation, """") AS Presentation,
		|	ISNULL(ttDataCI.FieldValues, """") AS FieldValues,
		|	ISNULL(ttDataCI.ContactLineIdentifier, ttAlwaysShowKinds.ContactLineIdentifier) AS ContactLineIdentifier,
		|	ISNULL(ttDataCI.OrderTypes, ttAlwaysShowKinds.OrderTypes) AS OrderTypes,
		|	ISNULL(ttDataCI.OrderKinds, ttAlwaysShowKinds.OrderKinds) AS OrderKinds
		|FROM
		|	ttAlwaysShowKinds AS ttAlwaysShowKinds
		|		FULL JOIN ttDataCI AS ttDataCI
		|		ON ttAlwaysShowKinds.Kind = ttDataCI.Kind
		|			AND ttAlwaysShowKinds.ContactLineIdentifier = ttDataCI.ContactLineIdentifier
		|
		|ORDER BY
		|	ContactLineIdentifier,
		|	OrderTypes,
		|	OrderKinds";
	
	Query.Text = StrReplace(Query.Text, "Catalog.Counterparties", OwnerCI.Metadata().FullName());
	Query.SetParameter("OwnerCI",			OwnerCI);
	Query.SetParameter("OrderTypes",		OrderTypesCI());
	Query.SetParameter("LineIdentifiers",	Form.LineIdentifiers.Unload());
	Query.SetParameter("AlwaysShowKinds", 
		Form.ContactInformationKindProperties.Unload(New Structure("ShowInFormAlways", True), "Kind"));
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		NewRow = Form.ContactInformation.Add();
		FillPropertyValues(NewRow, Selection);
		NewRow.Comment = ContactInformationManagement.ContactInformationComment(Selection.FieldValues);
	EndDo;
	
EndProcedure

Function NewPortionOfContactInformation(Form, OwnerCI, ContactLineIdentifier)
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	OrderTypes.Type AS Type,
		|	OrderTypes.Order AS Order
		|INTO ttOrderTypes
		|FROM
		|	&OrderTypes AS OrderTypes
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	&ContactLineIdentifier AS ContactLineIdentifier
		|INTO ttLineIdentifiers
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	ContactInformationTypes.Ref AS Kind,
		|	ContactInformationTypes.Type AS Type,
		|	ContactInformationTypes.AdditionalOrderingAttribute AS OrderKinds,
		|	ttOrderTypes.Order AS OrderTypes,
		|	&ContactLineIdentifier AS ContactLineIdentifier
		|INTO ttAlwaysShowKinds
		|FROM
		|	Catalog.ContactInformationTypes AS ContactInformationTypes
		|		LEFT JOIN ttOrderTypes AS ttOrderTypes
		|		ON ContactInformationTypes.Type = ttOrderTypes.Type
		|WHERE
		|	ContactInformationTypes.Ref IN(&AlwaysShowKinds)
		|
		|INDEX BY
		|	Kind
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	TableCI.Type AS Type,
		|	TableCI.Kind AS Kind,
		|	TableCI.Presentation AS Presentation,
		|	TableCI.FieldValues AS FieldValues
		|INTO TableCI
		|FROM
		|	&TableCI AS TableCI
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	TableCI.Kind AS Kind,
		|	TableCI.Type AS Type,
		|	TableCI.Presentation AS Presentation,
		|	TableCI.FieldValues AS FieldValues,
		|	0 AS ContactLineIdentifier,
		|	ttOrderTypes.Order AS OrderTypes
		|INTO ttDataCI
		|FROM
		|	TableCI AS TableCI
		|		LEFT JOIN ttOrderTypes AS ttOrderTypes
		|		ON TableCI.Type = ttOrderTypes.Type
		|
		|INDEX BY
		|	Kind
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	ISNULL(ttDataCI.Kind, ttAlwaysShowKinds.Kind) AS Kind,
		|	ISNULL(ttDataCI.Type, ttAlwaysShowKinds.Type) AS Type,
		|	ISNULL(ttDataCI.Presentation, """") AS Presentation,
		|	ISNULL(ttDataCI.FieldValues, """") AS FieldValues,
		|	ISNULL(ttDataCI.ContactLineIdentifier, ttAlwaysShowKinds.ContactLineIdentifier) AS ContactLineIdentifier,
		|	ISNULL(ttDataCI.OrderTypes, ttAlwaysShowKinds.OrderTypes) AS OrderTypes
		|FROM
		|	ttAlwaysShowKinds AS ttAlwaysShowKinds
		|		FULL JOIN ttDataCI AS ttDataCI
		|		ON ttAlwaysShowKinds.Kind = ttDataCI.Kind
		|			AND ttAlwaysShowKinds.ContactLineIdentifier = ttDataCI.ContactLineIdentifier
		|
		|ORDER BY
		|	ContactLineIdentifier,
		|	OrderTypes";
	
	Query.SetParameter("TableCI",				OwnerCI.ContactInformation.Unload(New Array, "Kind, Type, Presentation, FieldValues"));
	Query.SetParameter("OwnerCI",				OwnerCI);
	Query.SetParameter("OrderTypes",			OrderTypesCI());
	Query.SetParameter("ContactLineIdentifier",	ContactLineIdentifier);
	Query.SetParameter("AlwaysShowKinds", 
		Form.ContactInformationKindProperties.Unload(New Structure("ShowInFormAlways", True), "Kind"));
		
	Rows = New Array;
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		NewRow = Form.ContactInformation.Add();
		FillPropertyValues(NewRow, Selection);
		NewRow.Comment = ContactInformationManagement.ContactInformationComment(Selection.FieldValues);
		
		Rows.Add(NewRow);
	EndDo;
	
	Return Rows;
	
EndFunction

Procedure InitializeForm(Form)
	
	Items = Form.Items;
	
	If NOT Form.ContactLineIdentifierAttributeExists Then
		
		If Items.Find("ContactInformationValues") <> Undefined Then
			Return; // The form has already been initialized earlier
		EndIf;
		
		GroupValuesCI = Items.Add("ContactInformationValues", Type("FormGroup"), Items.ContactInformation);
		GroupValuesCI.Type				= FormGroupType.UsualGroup;
		GroupValuesCI.Title				= NStr("en = 'Contact information values'");
		GroupValuesCI.Representation	= UsualGroupRepresentation.None;
		GroupValuesCI.Group				= ChildFormItemsGroup.Vertical;
		GroupValuesCI.ThroughAlign		= ThroughAlign.Use;
		GroupValuesCI.ShowTitle			= False;
		
		If ContactInformationDriveClientServer.KindsListForAddingContactInformation(Form).Count() = 0 Then
			Return;
		EndIf;
		
		CommandName = "AddFieldContactInformation";
		Command = Form.Commands.Add(CommandName);
		Command.Title	= NStr("en = '+ phone, address'");
		Command.Action	= "Attachable_ContactInformationDriveExecuteCommand";
		
		Button = Items.Add(CommandName, Type("FormButton"), Items.ContactInformation);
		Button.CommandName = CommandName;
		Button.ShapeRepresentation		= ButtonShapeRepresentation.None;
		Button.HorizontalAlignInGroup	= ItemHorizontalLocation.Right;
		
	Else
		
		For Each LineID In Form.LineIdentifiers Do
			
			GroupValuesCIName = "ContactInformation" + LineID.Value + "ContactInformationValues";
			
			If Items.Find(GroupValuesCIName) <> Undefined Then
				Continue; // The form has already been initialized earlier
			EndIf;
			
			GroupValuesCI = Items.Add(GroupValuesCIName, Type("FormGroup"), Items["ContactInformation" + LineID.Value]);
			GroupValuesCI.Type				= FormGroupType.UsualGroup;
			GroupValuesCI.Title				= NStr("en = 'Contact information values'");
			GroupValuesCI.Representation	= UsualGroupRepresentation.None;
			GroupValuesCI.Group				= ChildFormItemsGroup.Vertical;
			GroupValuesCI.ThroughAlign		= ThroughAlign.Use;
			GroupValuesCI.ShowTitle			= False;
			
			If ContactInformationDriveClientServer.KindsListForAddingContactInformation(Form).Count() = 0 Then
				Continue;
			EndIf;
			
			CommandName = "AddFieldContactInformation_" + LineID.Value;
			Command = Form.Commands.Add(CommandName);
			Command.Title	= NStr("en = '+ phone, address'");
			Command.Action	= "Attachable_ContactInformationDriveExecuteCommand";
			
			GroupAddCI = Items.Add("Group" + CommandName, Type("FormGroup"), Items["ContactInformation" + LineID.Value]);
			GroupAddCI.Type						= FormGroupType.UsualGroup;
			GroupAddCI.Title					= NStr("en = 'Contact information values'");
			GroupAddCI.Representation			= UsualGroupRepresentation.None;
			GroupAddCI.Group					= ChildFormItemsGroup.AlwaysHorizontal;
			GroupAddCI.ThroughAlign				= ThroughAlign.Use;
			GroupAddCI.ShowTitle				= False;
			GroupAddCI.HorizontalAlignInGroup	= ItemHorizontalLocation.Right;

			Button = Items.Add(CommandName, Type("FormButton"), GroupAddCI);
			Button.CommandName				= CommandName;
			Button.ShapeRepresentation		= ButtonShapeRepresentation.None;
			Button.HorizontalAlignInGroup	= ItemHorizontalLocation.Right;

		EndDo;
		
	EndIf;
	
EndProcedure

Function IsAnotherFilledRowsKindCI(Val Form, Val CheckingRow, Val ContactInformationKind)
	
	AllRowsThisKind = Form.ContactInformation.FindRows(
		New Structure("Kind", ContactInformationKind));
	
	For Each KindRow In AllRowsThisKind Do
		
		If KindRow <> CheckingRow AND Not IsBlankString(KindRow.Presentation) Then
			Return True;
		EndIf;
		
	EndDo;
	
	Return False;
	
EndFunction

Procedure AddContextMenuCommand(Form, CommandName, Picture, Title, ToolTip, FieldOwner)
	
	If Form.Commands.Find(CommandName) = Undefined Then
		Command = Form.Commands.Add(CommandName);
		Command.Picture	= Picture;
		Command.Title	= Title;
		Command.ToolTip	= ToolTip;
		Command.Action	= "Attachable_ContactInformationDriveExecuteCommand";
	EndIf;
	
	Button = Form.Items.Add(CommandName, Type("FormButton"), FieldOwner.ContextMenu);
	Button.CommandName = CommandName;
	
EndProcedure

#EndRegion
