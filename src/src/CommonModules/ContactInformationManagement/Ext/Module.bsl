////////////////////////////////////////////////////////////////////////////////
// The Contact information subsystem.
//
////////////////////////////////////////////////////////////////////////////////

#Region SubsystemsLibrary 

#Region Interface

////////////////////////////////////////////////////////////////////////////////
// Form event handlers, object module handlers.

// OnCreateAtServer form event handler. 
// It is called from the owner object form module when Contact information subsystem is embedded.
//
// Parameters:
//    Form                            - ManagedForm - owner object form used for contact information output. 
//    Object                          - Arbitrary   - contact information owner object. 
//    ContactInformationTitleLocation - FormItemTitleLocation - can take on the following values: 
//                                      FormItemTitleLocation.Left and FormItemTitleLocation.Top (default value).
//
Procedure OnCreateAtServer(Form, Object, ItemForPlacementName = "", TitleLocationContactInformation = "") Export
	
	String500				= New TypeDescription("String",, New StringQualifiers(500));	
	BooleanTypeDescription	= New TypeDescription("Boolean");
	AttributesToAddArray	= New Array;
	
	// Creating a value table
	DescriptionName = "ContactInformationAdditionalAttributeInfo";
	AttributesToAddArray.Add(New FormAttribute(DescriptionName,				New TypeDescription("ValueTable")));
	AttributesToAddArray.Add(New FormAttribute("AttributeName",				String500, DescriptionName));
	AttributesToAddArray.Add(New FormAttribute("Kind",						New TypeDescription("CatalogRef.ContactInformationTypes"), DescriptionName));
	AttributesToAddArray.Add(New FormAttribute("Type",						New TypeDescription("EnumRef.ContactInformationTypes"), DescriptionName));
	AttributesToAddArray.Add(New FormAttribute("FieldValues",				New TypeDescription("ValueList, String"), DescriptionName));
	AttributesToAddArray.Add(New FormAttribute("Presentation",				String500, DescriptionName));
	AttributesToAddArray.Add(New FormAttribute("Comment",					New TypeDescription("String"), DescriptionName));
	AttributesToAddArray.Add(New FormAttribute("IsTabularSectionAttribute",	BooleanTypeDescription, DescriptionName));
	
	AddedItemsTableName = "AddedContactInformationItems";
	AttributesToAddArray.Add(New FormAttribute(AddedItemsTableName,						New TypeDescription("ValueTable")));
	AttributesToAddArray.Add(New FormAttribute("ItemName",								String500, AddedItemsTableName));
	AttributesToAddArray.Add(New FormAttribute("Priority",								New TypeDescription("Number"), AddedItemsTableName));
	AttributesToAddArray.Add(New FormAttribute("IsCommand",								BooleanTypeDescription, AddedItemsTableName));
	AttributesToAddArray.Add(New FormAttribute("IsTabularSectionAttribute",				BooleanTypeDescription, AddedItemsTableName));
	
	AttributesToAddArray.Add(New FormAttribute("AddedContactInformationItemList",		New TypeDescription("ValueList")));
	
	AttributesToAddArray.Add(New FormAttribute("ContactInformationTitleLocation",		String500));
	AttributesToAddArray.Add(New FormAttribute("ContactInformationGroupForPlacement",	String500));
	
	// Getting contact information kind list
	
	ObjectRef				= Object.Ref;
	ObjectMetadata			= ObjectRef.Metadata();
	MetadataObjectFullName	= ObjectMetadata.FullName();
	CIKindGroupName			= StrReplace(MetadataObjectFullName, ".", "");
	CIKindsGroup			= Catalogs.ContactInformationTypes[CIKindGroupName];
	ObjectName				= ObjectMetadata.Name;
	
	If ObjectMetadata.TabularSections.ContactInformation.Attributes.Find("ContactLineIdentifier") = Undefined Then
		ContactLineIdentifierData = "0";
	Else
		ContactLineIdentifierData = "ISNULL(ContactInformation.ContactLineIdentifier, 0)";
	EndIf;
	
	Query = New Query;
	If ValueIsFilled(ObjectRef) Then
		Query.Text = "
			|SELECT
			|	ContactInformationTypes.Ref                         AS Kind,
			|	ContactInformationTypes.PredefinedDataName          AS PredefinedDataName,
			|	ContactInformationTypes.Type                        AS Type,
			|	ContactInformationTypes.Mandatory                   AS Mandatory,
			|	ContactInformationTypes.Tooltip                     AS Tooltip,
			|	ContactInformationTypes.Description                 AS Description,
			|	ContactInformationTypes.Description                 AS Title,
			|	ContactInformationTypes.EditInDialogOnly            AS EditInDialogOnly,
			|	ContactInformationTypes.IsFolder                    AS IsTabularSectionAttribute,
			|	ContactInformationTypes.AdditionalOrderingAttribute AS AdditionalOrderingAttribute,
			|	ISNULL(ContactInformation.Presentation, """")       AS Presentation,
			|	ISNULL(ContactInformation.FieldValues, """")        AS FieldValues,
			|	ISNULL(ContactInformation.LineNumber, 0)            AS LineNumber,
			|	" + ContactLineIdentifierData + "                     AS RowID,
			|	CAST("""""""" AS STRING(200))                       AS AttributeName,
			|	CAST("""" AS STRING)                                AS Comment
			|FROM
			|	Catalog.ContactInformationTypes AS ContactInformationTypes
			|LEFT JOIN 
			|	" +  MetadataObjectFullName + ".ContactInformation
			|AS ContactInformation
			|ON ContactInformation.Ref
			|= &Owner AND
			|ContactInformationTypes.Ref
			|= ContactInformation.Kind
			|WHERE NOT
			|ContactInformationTypes.DeletionMark AND ( ContactInformationTypes.Parent
			|= &CIKindsGroup OR
			|ContactInformationTypes.Parent.Parent
			|= &CIKindsGroup
			|) ORDER BY ContactInformationTypes.Ref HIERARCHY
			|";
	Else 
		Query.Text = "
			|SELECT
			|	ContactInformation.Presentation  AS Presentation,
			|	ContactInformation.FieldValues   AS FieldValues,
			|	ContactInformation.LineNumber    AS LineNumber,
			|	ContactInformation.Kind          AS Kind,
			|	" + ContactLineIdentifierData + "  AS ContactLineIdentifier
			|INTO 
			|	ContactInformation
			|FROM
			|	&ContactInformationTable AS ContactInformation
			|INDEX BY
			|	Kind
			|;
			|////////////////////////////////////////////////////////////////////////////////
			|
			|SELECT
			|	ContactInformationTypes.Ref                         AS Kind,
			|	ContactInformationTypes.PredefinedDataName          AS PredefinedDataName,
			|	ContactInformationTypes.Type                        AS Type,
			|	ContactInformationTypes.Mandatory                   AS Mandatory,
			|	ContactInformationTypes.Tooltip                     AS Tooltip,
			|	ContactInformationTypes.Description                 AS Description,
			|	ContactInformationTypes.Description                 AS Title,
			|	ContactInformationTypes.EditInDialogOnly            AS EditInDialogOnly,
			|	ContactInformationTypes.IsFolder                    AS IsTabularSectionAttribute,
			|	ContactInformationTypes.AdditionalOrderingAttribute AS AdditionalOrderingAttribute,
			|	ISNULL(ContactInformation.Presentation, """")       AS Presentation,
			|	ISNULL(ContactInformation.FieldValues, """")        AS FieldValues,
			|	ISNULL(ContactInformation.LineNumber, 0)            AS LineNumber,
			|	" + ContactLineIdentifierData + "                     AS RowID,
			|	CAST("""""""" AS STRING(200))                       AS AttributeName,
			|	CAST("""" AS STRING)                                AS Comment
			|FROM
			|	Catalog.ContactInformationTypes AS ContactInformationTypes
			|LEFT JOIN 
			|	ContactInformation AS ContactInformation
			|ON 
			|	ContactInformationTypes.Ref = ContactInformation.Kind
			|WHERE
			|	Not ContactInformationTypes.DeletionMark
			|	AND (
			|		ContactInformationTypes.Parent = &CIKindsGroup 
			|		OR ContactInformationTypes.Parent.Parent = &CIKindsGroup
			|	)
			|ORDER BY
			|	ContactInformationTypes.Ref HIERARCHY
			|";
			
		Query.SetParameter("ContactInformationTable", Object.ContactInformation.Unload());
	EndIf;
	
	Query.SetParameter("CIKindsGroup",	CIKindsGroup);
	Query.SetParameter("Owner",			ObjectRef);
	
	SetPrivilegedMode(True);
	ContactInformation = Query.Execute().Unload(QueryResultIteration.ByGroupsWithHierarchy).Rows;
	SetPrivilegedMode(False);
	
	ContactInformation.Sort("AdditionalOrderingAttribute, LineNumber");
	
	For Each ContactInformationObject In ContactInformation Do
		
		If ContactInformationObject.IsTabularSectionAttribute Then
			
			CIKindName	= ContactInformationObject.PredefinedDataName;
			Pos			= Find(CIKindName, ObjectName);
			
			TabularSectionName = Mid(CIKindName, Pos + StrLen(ObjectName));
			
			PreviousKind	= Undefined;
			AttributeName	= "";
			
			ContactInformationObject.Rows.Sort("AdditionalOrderingAttribute");
			
			For Each CIRow In ContactInformationObject.Rows Do
				
				ContactInformationObject.Rows.Sort("AdditionalOrderingAttribute");
				
				CurrentKind = CIRow.Kind;
				
				If CurrentKind <> PreviousKind Then
					
					AttributeName = "ContactInformationField" + TabularSectionName + ContactInformationObject.Rows.IndexOf(CIRow);
					
					AttributesPath = "Object." + TabularSectionName;
					
					AttributesToAddArray.Add(New FormAttribute(AttributeName, String500, AttributesPath, CIRow.Title, True));
					AttributesToAddArray.Add(New FormAttribute(AttributeName + "FieldValues", New TypeDescription("ValueList, String"), AttributesPath,, True));
					PreviousKind = CurrentKind;
					
				EndIf;
				
				CIRow.AttributeName = AttributeName;
				
			EndDo;
			
		Else
			ContactInformationObject.AttributeName = "ContactInformationField" + ContactInformation.IndexOf(ContactInformationObject);
			
			AttributesToAddArray.Add(New FormAttribute(ContactInformationObject.AttributeName, String500,, ContactInformationObject.Title, True));
			
			// Proceeding regardless of any recognition errors
			Try
				ContactInformationObject.Comment = ContactInformationInternal.ContactInformationComment(ContactInformationObject.FieldValues);
			Except
				WriteLogEvent(ContactInformationManagementService.EventLogMessageText(),
					EventLogLevel.Error,, ContactInformationObject.FieldValues, DetailErrorDescription(ErrorInfo()));
				CommonUseClientServer.MessageToUser(
					NStr("en = 'Contact information analysis error, possibly due to invalid field value format.'"),,
					ContactInformationObject.AttributeName);
			EndTry;
		EndIf;
		
	EndDo;
	
	// Adding new attributes
	Form.ChangeAttributes(AttributesToAddArray);
	
	Form.ContactInformationTitleLocation		= TitleLocationContactInformation;
	Form.ContactInformationGroupForPlacement	= ItemForPlacementName;
	
	PreviousKind = Undefined;
	
	Filter = New Structure("Type", Enums.ContactInformationTypes.Address);
	AddressCount = ContactInformation.FindRows(Filter).Count();
	
	// Creating form items, filling in the attribute values
	Parent = ?(IsBlankString(ItemForPlacementName), Form, Form.Items[ItemForPlacementName]);
	
	// Creating groups for contact information
	CompositionGroup	= Group("ContactInformationCompositionGroup",	Form, Parent, ChildFormItemsGroup.Horizontal, 5);
	HeaderGroup			= Group("ContactInformationTitleGroup",			Form, CompositionGroup, ChildFormItemsGroup.Vertical, 4);
	InputFieldGroup		= Group("ContactInformationInputFieldGroup",	Form, CompositionGroup, ChildFormItemsGroup.Vertical, 4);
	ActionGroup			= Group("ContactInformationActionGroup",		Form, CompositionGroup, ChildFormItemsGroup.Vertical, 4);
	
	TitleLeft = TitleLeft(Form, TitleLocationContactInformation);
	
	For Each CIRow In ContactInformation Do
		
		If CIRow.IsTabularSectionAttribute Then
			
			CIKindName					= CommonUse.PredefinedName(CIRow.Kind);
			Pos							= Find(CIKindName, ObjectName);	
			TabularSectionName			= Mid(CIKindName, Pos + StrLen(ObjectName));	
			PreviousTabularSectionKind	= Undefined;
			
			For Each ContactInformationTabularSectionRow In CIRow.Rows Do
				
				TabularSectionKind = ContactInformationTabularSectionRow.Kind;
				
				If TabularSectionKind <> PreviousTabularSectionKind Then
					
					TabularSectionGroup = Form.Items[TabularSectionName + "ContactInformationGroup"];
					
					Item = Form.Items.Add(ContactInformationTabularSectionRow.AttributeName, Type("FormField"), TabularSectionGroup);
					Item.Type		= FormFieldType.InputField;
					Item.DataPath	= "Object." + TabularSectionName + "." + ContactInformationTabularSectionRow.AttributeName;
					
					If CanEditContactInformationTypeInDialog(ContactInformationTabularSectionRow.Type) Then
						
						Item.ChoiceButton = True;
						If TabularSectionKind.EditInDialogOnly Then
							Item.TextEdit = False;
						EndIf;
						
						Item.SetAction("StartChoice", "Attachable_ContactInformationStartChoice");
						
					EndIf;
					
					Item.SetAction("OnChange", "Attachable_ContactInformationOnChange");
					
					If TabularSectionKind.Mandatory Then
						Item.AutoMarkIncomplete = True;
					EndIf;
					
					AddItemDetails(Form, ContactInformationTabularSectionRow.AttributeName, 2, , True);
					AddAttributeToDetails(Form, ContactInformationTabularSectionRow, False, True);
					PreviousTabularSectionKind = TabularSectionKind;
					
				EndIf;
				
				Filter = New Structure;
				Filter.Insert("ContactLineIdentifier", ContactInformationTabularSectionRow.RowID);
				
				TableRows = Form.Object[TabularSectionName].FindRows(Filter);
				
				If TableRows.Count() = 1 Then
					
					TableRow = TableRows[0];
					TableRow[ContactInformationTabularSectionRow.AttributeName]					= ContactInformationTabularSectionRow.Presentation;
					TableRow[ContactInformationTabularSectionRow.AttributeName + "FieldValues"] = ContactInformationTabularSectionRow.FieldValues;
					
				EndIf;
				
			EndDo;
			
			Continue;
			
		EndIf;
		
		HasComment		= ValueIsFilled(CIRow.Comment);
		AttributeName	= CIRow.AttributeName;	
		IsNewCIKind		= (CIRow.Kind <> PreviousKind);
		
		// Adding the title
		If TitleLeft Then		
			ItemTitle(Form, CIRow.Type, AttributeName, HeaderGroup, CIRow.Description, IsNewCIKind, HasComment);		
		EndIf;
		
		TextBox(Form, CIRow.EditInDialogOnly, CIRow.Type, AttributeName, CIRow.ToolTip, IsNewCIKind, CIRow.Mandatory);
		
		// Displaying the comment
		If HasComment Then			
			CommentName = "Comment" + AttributeName;
			Comment(Form, CIRow.Comment, CommentName, InputFieldGroup);			
		EndIf;
		
		// Using a placeholder if the field title is located at the top
		If Not TitleLeft AND IsNewCIKind Then
			
			DecorationName	= "DecorationTop" + AttributeName;
			Decoration		= Form.Items.Add(DecorationName, Type("FormDecoration"), ActionGroup);
			AddItemDetails(Form, DecorationName, 2);
			
		EndIf;
		
		Action(Form, CIRow.Type, AttributeName, ActionGroup, AddressCount, HasComment);
		AddAttributeToDetails(Form, CIRow, IsNewCIKind);
		
		PreviousKind = CIRow.Kind;
		
	EndDo;
	
	If Form.AddedContactInformationItemList.Count() > 0 Then
		
		CommandGroup = Group("ContactInformationGroupAddInputField", Form, Parent, ChildFormItemsGroup.Horizontal, 5);
		CommandGroup.Representation = UsualGroupRepresentation.NormalSeparation;
		
		CommandName = "ContactInformationAddInputField";
		
		Command = Form.Commands.Add(CommandName);
		Command.Tooltip			= NStr("en = 'Add an additional contact information field'");
		Command.Representation	= ButtonRepresentation.PictureAndText;
		Command.Picture			= PictureLib.AddListItem;
		Command.Action			= "Attachable_ContactInformationExecuteCommand";
		
		AddItemDetails(Form, CommandName, 9, True);
		
		Button = Form.Items.Add(CommandName, Type("FormButton"), CommandGroup);
		Button.Title		= NStr("en = 'Add'");
		Button.CommandName	= CommandName;
		AddItemDetails(Form, CommandName, 2);
		
	EndIf;
	
EndProcedure

// OnReadAtServer form event handler. 
// It is called from the owner object form module when Contact information subsystem is embedded.
//
// Parameters:
//    Form   - ManagedForm - owner object form used for contact information output. 
//    Object - Arbitrary   - contact information owner object.
//
Procedure OnReadAtServer(Form, Object) Export
	
	FormAttributeList = Form.GetAttributes();
	
	Restart = False;
	For Each Attribute In FormAttributeList Do
		If Attribute.Name = "ContactInformationAdditionalAttributeInfo" Then
			Restart = True;
			Break;
		EndIf;
	EndDo;
	
	If Restart Then
		
		TitleLocationContactInformation = Form.ContactInformationTitleLocation;
		TitleLocationContactInformation = ?(ValueIsFilled(TitleLocationContactInformation), FormItemTitleLocation[TitleLocationContactInformation], FormItemTitleLocation.Top);
		
		ItemForPlacementName = Form.ContactInformationGroupForPlacement;
		
		DeleteCommandsAndFormItems(Form);
		
		AttributesToDeleteArray = New Array;
		
		ObjectName = Object.Ref.Metadata().Name;
		
		For Each FormAttribute In Form.ContactInformationAdditionalAttributeInfo Do
			If Not FormAttribute.IsTabularSectionAttribute Then
				AttributesToDeleteArray.Add(FormAttribute.AttributeName);
			Else
				AttributesToDeleteArray.Add("Object." + TabularSectionNameByCIKind(FormAttribute.Kind, ObjectName) + "." + FormAttribute.AttributeName);
				AttributesToDeleteArray.Add("Object." + TabularSectionNameByCIKind(FormAttribute.Kind, ObjectName) + "." + FormAttribute.AttributeName + "FieldValues");
			EndIf;
		EndDo;
		
		AttributesToDeleteArray.Add("AddedContactInformationItems");
		AttributesToDeleteArray.Add("AddedContactInformationItemList");
		AttributesToDeleteArray.Add("ContactInformationTitleLocation");
		AttributesToDeleteArray.Add("ContactInformationGroupForPlacement");
		AttributesToDeleteArray.Add("ContactInformationAdditionalAttributeInfo");
		
		Form.ChangeAttributes(, AttributesToDeleteArray);
		
		OnCreateAtServer(Form, Object, ItemForPlacementName, TitleLocationContactInformation);
		
	EndIf;
	
EndProcedure

// AfterWriteAtServer form event handler. 
// It is called from the owner object form module when Contact information subsystem is embedded.
//
// Parameters:
//    Form   - ManagedForm - owner object form used for contact information output. 
//    Object - Arbitrary   - contact information owner object.
//
Procedure AfterWriteAtServer(Form, Object) Export
	
	ObjectName = Object.Ref.Metadata().Name;
	
	For Each TableRow In Form.ContactInformationAdditionalAttributeInfo Do
		
		If TableRow.IsTabularSectionAttribute Then
			
			InformationKind = TableRow.Kind;
			AttributeName = TableRow.AttributeName;
			TabularSectionName = TabularSectionNameByCIKind(InformationKind, ObjectName);
			FormTabularSection = Form.Object[TabularSectionName];
			
			For Each FormTabularSectionRow In FormTabularSection Do
				
				Filter = New Structure;
				Filter.Insert("Kind", InformationKind);
				Filter.Insert("ContactLineIdentifier", FormTabularSectionRow.ContactLineIdentifier);
				FoundRows = Object.ContactInformation.FindRows(Filter);
				
				If FoundRows.Count() = 1 Then
					
					CIRow = FoundRows[0];
					FormTabularSectionRow[AttributeName] = CIRow.Presentation;
					FormTabularSectionRow[AttributeName + "FieldValues"] = CIRow.FieldValues;
					
				EndIf;
				
			EndDo;
			
		EndIf;
		
	EndDo;
	
EndProcedure

// FillCheckProcessingAtServer form event handler. 
// It is called from the owner object form module when Contact information subsystem is embedded.
//
// Parameters:
//    Form   - ManagedForm - owner object form used for contact information output. 
//    Object - Arbitrary   - contact information owner object.
//
Procedure FillCheckProcessingAtServer(Form, Object, Cancel) Export
	
	ObjectName = Object.Ref.Metadata().Name;
	ErrorLevel = 0;
	PreviousKind = Undefined;
	
	For Each TableRow In Form.ContactInformationAdditionalAttributeInfo Do
		
		InformationKind = TableRow.Kind;
		InformationType = TableRow.Type;
		Comment         = TableRow.Comment;
		AttributeName   = TableRow.AttributeName;
		
		Mandatory = InformationKind.Mandatory;
		
		If TableRow.IsTabularSectionAttribute Then
			
			TabularSectionName = TabularSectionNameByCIKind(InformationKind, ObjectName);
			FormTabularSection = Form.Object[TabularSectionName];
			
			For Each FormTabularSectionRow In FormTabularSection Do
				
				Presentation = FormTabularSectionRow[AttributeName];
				Field = "Object." + TabularSectionName + "[" + (FormTabularSectionRow.LineNumber - 1) + "]." + AttributeName;
				
				If Mandatory AND IsBlankString(Presentation) Then
					
					MessageText = NStr("en = 'The ""%1"" field is not filled in.'");
					MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessageText, InformationKind.Description);
					CommonUseClientServer.MessageToUser(MessageText,,Field);
					CurrentErrorLevel = 2;
					
				Else
					
					FieldValues = FormTabularSectionRow[AttributeName + "FieldValues"];
					
					CurrentErrorLevel = ValidateContactInformation(Presentation, FieldValues, InformationKind,
					InformationType, AttributeName, , Field);
					
					FormTabularSectionRow[AttributeName] = Presentation;
					FormTabularSectionRow[AttributeName + "FieldValues"] = FieldValues;
					
				EndIf;
				
				ErrorLevel = ?(CurrentErrorLevel > ErrorLevel, CurrentErrorLevel, ErrorLevel);
				
			EndDo;
			
		Else
			
			Presentation = Form[AttributeName];
			
			If InformationKind <> PreviousKind AND Mandatory AND IsBlankString(Presentation) 
				// And no other strings containing data for contact information kinds with multiple values
				AND Not HasOtherStringsFilledWithThisContactInformationKind(
					Form, TableRow, InformationKind
				)
			Then
				
				MessageText = NStr("en = 'The ""%1"" field is not filled in.'");
				MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessageText, InformationKind.Description);
				CommonUseClientServer.MessageToUser(MessageText,,,AttributeName);
				CurrentErrorLevel = 2;
				
			Else
				
				CurrentErrorLevel = ValidateContactInformation(Presentation, TableRow.FieldValues,
				InformationKind, InformationType, AttributeName, Comment);
				
			EndIf;
			
			ErrorLevel = ?(CurrentErrorLevel > ErrorLevel, CurrentErrorLevel, ErrorLevel);
			
		EndIf;
		
		PreviousKind = InformationKind;
		
	EndDo;
	
	If ErrorLevel <> 0 Then
		Cancel = True;
	EndIf;
	
EndProcedure

// BeforeWriteAtServer form event handler. 
// It is called from the owner object form module when Contact information subsystem is embedded.
//
// Parameters:
//    Form   - ManagedForm - owner object form used for contact information output. 
//    Object - Arbitrary   - contact information owner object.
//
Procedure BeforeWriteAtServer(Form, Object, Cancel = False) Export
	
	Object.ContactInformation.Clear();
	ObjectName = Object.Ref.Metadata().Name;
	PreviousKind = Undefined;
	
	For Each TableRow In Form.ContactInformationAdditionalAttributeInfo Do
		
		InformationKind = TableRow.Kind;
		InformationType = TableRow.Type;
		AttributeName   = TableRow.AttributeName;
		Mandatory       = InformationKind.Mandatory;
		
		If TableRow.IsTabularSectionAttribute Then
			
			TabularSectionName = TabularSectionNameByCIKind(InformationKind, ObjectName);
			FormTabularSection = Form.Object[TabularSectionName];
			For Each FormTabularSectionRow In FormTabularSection Do
				
				RowID = FormTabularSectionRow.GetID();
				FormTabularSectionRow.ContactLineIdentifier = RowID;
				
				TabularSectionRow = Object[TabularSectionName][FormTabularSectionRow.LineNumber - 1];
				TabularSectionRow.ContactLineIdentifier = RowID;
				
				FieldValues = FormTabularSectionRow[AttributeName + "FieldValues"];
				
				WriteContactInformation(Object, FieldValues, InformationKind, InformationType, RowID);
				
			EndDo;
			
		Else
			
			WriteContactInformation(Object, TableRow.FieldValues, InformationKind, InformationType);
			
		EndIf;
		
		PreviousKind = InformationKind;
		
	EndDo;
	
EndProcedure

// Adds (or deletes) an input field or comment for the form, and updates form data. 
// It is called from the owner object form module when Contact information subsystem is embedded.
//
// Parameters:
//    Form   - ManagedForm - owner object form used for contact information output. 
//    Object - Arbitrary   - contact information owner object.
//    Result - Arbitrary   - optional internal attribute provided by the previous event handler.
//
// Returns:
//    Undefined.
//
Function UpdateContactInformation(Form, Object, Result = Undefined) Export
	
	If Result = Undefined Then
		Return Undefined;
		
	ElsIf Result.Property("IsAddComment") Then
		ModifyComment(Form, Result.AttributeName, Result.IsAddComment);
		
	ElsIf Result.Property("AddedKind") Then
		AddContactInformationString(Form, Result);
		
	EndIf;
	
	Return Undefined;
EndFunction

#Region ContactInformationAccessibilityForOtherSubsystems

// Checks a domestic address for compliance with address information requirements.
//
// Parameters:
//    AddressFieldStructure - Structure, ValueList, String - address information fields.
//                             Structure and ValueList contain address field names and values,
//                             String contains a single contact information XML string,
//                             or multiple strings with field names and values.
//
//    ContactInformationKind - CatalogRef.ContactInformationTypes - contact information kind matching the address to be validated.
//
// Returns:
//    Array - contains a structure with the following fields:
//        * ErrorType - String - Error ID. Available values:
//                "PresentationNotMatchingFieldSet"
//                "MandatoryFieldsNotFilled"
//                "FieldAbbreviationsNotSpecified"
//                "InvalidFieldCharacters"
//                "FieldLengthsNotMatching"
//                "ClassifierErrors"
//        * Message - String - Detailed error text.
//        * Fields - Array - contains structures with the following fields:
//                ** FieldName - String - address structure item name.
//                ** Message   - String - detailed error text for the field.
//
Function ValidateAddress(Val AddressFieldStructure, ContactInformationKind = Undefined) Export
	Return ContactInformationInternal.AddressFillErrors(AddressFieldStructure, ContactInformationKind, True);
EndFunction

// Converts all incoming contact information formats to XML.
//
// Parameters:
//    FieldValues  - String, Structure, Map, ValueList - description of the contact information fields.
//    Presentation - String - presentation. Used if unable to determine presentation based on the
//                            FieldValues parameter (the Presentation field is not available).
//    ExpectedKind - CatalogRef.ContactInformationTypes, EnumRef.ContactInformationTypes - Used if unable 
//                            to determine type by the FieldValues field.
//
// Returns:
//     String  - contact information XML string.
//
Function ContactInformationToXML(Val FieldValues, Val Presentation = "", Val ExpectedKind = Undefined) Export
	
	Result = ContactInformationXML.TransformContactInformationXML(New Structure(
		"FieldValues, Presentation, ContactInformationKind",
		FieldValues, Presentation, ExpectedKind));
	
	Return Result.XMLData;
EndFunction

// Returns ContactInformationTypes enumeration value by XML string.
//
// Parameters:
//    XMLString - String - contact information.
//
// Returns:
//    EnumRef.ContactInformationTypes - type matching the XML string.
//
Function ContactInformationType(Val XMLString) Export
	Return ContactInformationXML.ContactInformationType(XMLString);
EndFunction

// Reads or sets the contact information presentation.
//
// Parameters:
//    XMLString - String - contact information XML string.
//    NewValue  - String - value to be set.
//
// Returns:
//    String - new value.
//
Function ContactInformationPresentation(XMLString, Val NewValue = Undefined) Export
	Return ContactInformationInternal.ContactInformationPresentation(XMLString, NewValue);
EndFunction

// Generates contact information presentation based on internal field values.
//
// Parameters:
//    XMLString              - String - contact information XML string.
//    ContactInformationKind - CatalogRef.ContactInformationTypes, Structure - a set of flags
//                             specifying presentation generation parameters.
//
// Returns:
//    String - generated presentation.
//
Function ContactInformationPresentationByFieldValues(Val XMLString, Val ContactInformationKind = Undefined) Export
	
	If ContactInformationKind = Undefined Then
		Kind = ContactInformationTypestructure();
		Kind.Type = ContactInformationXML.ContactInformationType(XMLString);
	Else
		Kind = ContactInformationKind;
	EndIf;
	
	Return ContactInformationInternal.GenerateContactInformationPresentation(XMLString, Kind);
EndFunction

// Reads or sets a contact information comment.
//
// Parameters:
//    XMLString - String - contact information XML string.
//    NewValue  - String - value to be set.
//
// Returns:
//    String - new value.
//
Function ContactInformationComment(XMLString, Val NewValue = Undefined) Export
	Return ContactInformationInternal.ContactInformationComment(XMLString, NewValue);
EndFunction

// Reads or sets an address by document (for domestic addresses only). 
// If the passed string does not contain domestic address information, raises an exception.
//
// Parameters:
//    XMLString - String - contact information XML string.
//    NewValue  - String - value to be set.
//
// Returns:
//    String - new value.
//
Function AddressByContactInformationDocument(XMLString, Val NewValue = Undefined) Export
	If IsBlankString(XMLString) Then
		Return "";
	EndIf;
	
	Namespace = ContactInformationClientServerCached.Namespace();
	Read = New XMLReader;
	Read.SetString(XMLString);
	XDTOAddress = XDTOFactory.ReadXML(Read, XDTOFactory.Type(Namespace, "ContactInformation"));
	AddressUS = ContactInformationInternal.HomeCountryAddress(XDTOAddress.Content);
	If AddressUS = Undefined Then
		Raise NStr("en = 'Cannot determine the address by document, expecting a domestic address'");
	EndIf;
	
	If NewValue <> Undefined Then
		AddressUS.Address_to_document = NewValue;
		XMLString = ContactInformationInternal.ContactInformationSerialization(XDTOAddress);
	EndIf;
	
	Return String(AddressUS.Address_to_document);
EndFunction

// Returns the address country information.
// If the passed string does not contain address information, raises an exception.
//
// Parameters:
//    XMLString - String - contact information XML string.
//
// Returns:
//    Structure - address country description. Contains the following fields:
//        * Ref             - CatalogRef.Countries, Undefined - Country item. 
//        * Description     - String - a part of country description. 
//        * Code            - String - a part of country description. 
//        * LongDescription - String - a part of country description. 
//        * AlphaCode2      - String - a part of country description. 
//        * AlphaCode3      - String - a part of country description.
//
// If an empty string is passed, returns an empty structure.
// If the country is found in the classifier but not found in the country catalog, 
// the Ref field of the resulting structure is not filled. 
// If the country is found neither in the classifier nor in the country catalog, 
// only the Description field is filled.
//
Function ContactInformationAddressCountry(Val XMLString) Export
	
	Result = New Structure("Ref, Code, Description, LongDescription, AlphaCode2, AlphaCode3");
	If IsBlankString(XMLString) Then
		Return Result;
	EndIf;
	
	// Reading the country description
	Namespace = ContactInformationClientServerCached.Namespace();
	Read = New XMLReader;
	Read.SetString(XMLString);
	
	XDTOAddress	= XDTOFactory.ReadXML(Read, XDTOFactory.Type(Namespace, "ContactInformation"));
	Address		= XDTOAddress.Content;
	
	If Address = Undefined 
		OR Address.Type() <> XDTOFactory.Type(Namespace, "Address") Then
		Raise NStr("en = 'Cannot determine country; address pending.'");
	EndIf;
	
	Result.Description = TrimAll(Address.Country);
	CountryData = Catalogs.Countries.CountryData(, Result.Description);
	
	Return ?(CountryData = Undefined, Result, CountryData);
	
EndFunction

// Returns address state name or an empty string (if the state is undefined). 
// If the passed string does not contain address information, raises an exception.
//
// Parameters:
//    XMLString - String - contact information XML string.
//
// Returns:
//    String - name.
//
Function ContactInformationAddressState(Val XMLString) Export
	If IsBlankString(XMLString) Then
		Return "";
	EndIf;
	
	Namespace = ContactInformationClientServerCached.Namespace();
	Read = New XMLReader;
	Read.SetString(XMLString);
	XDTOAddress = XDTOFactory.ReadXML(Read, XDTOFactory.Type(Namespace, "ContactInformation"));
	Address = XDTOAddress.Content;
	If Address = Undefined Or Address.Type() <> XDTOFactory.Type(Namespace, "Address") Then
		Raise NStr("en = 'Cannot determine state, expecting an address.'");
	EndIf;
	
	AddressUS = ContactInformationInternal.HomeCountryAddress(Address);
	Return ?(AddressUS = Undefined, "", TrimAll(AddressUS.Region));
EndFunction

// Returns address city name or an empty string (for foreign addresses).
// If the passed string does not contain address information, raises an exception.
//
// Parameters:
//    XMLString - String - contact information XML string.
//
// Returns:
//    String - name.
//
Function ContactInformationAddressCity(Val XMLString) Export
	If IsBlankString(XMLString) Then
		Return "";
	EndIf;
	
	Namespace = ContactInformationClientServerCached.Namespace();
	Read = New XMLReader;
	Read.SetString(XMLString);
	XDTOAddress = XDTOFactory.ReadXML(Read, XDTOFactory.Type(Namespace, "ContactInformation"));
	Address = XDTOAddress.Content;
	If Address = Undefined Or Address.Type() <> XDTOFactory.Type(Namespace, "Address") Then
		Raise NStr("en = 'Cannot determine city; address pending.'");
	EndIf;
	
	AddressUS = ContactInformationInternal.HomeCountryAddress(Address);
	Return ?(AddressUS = Undefined, "", TrimAll(AddressUS.City));
EndFunction

// Returns a network address domain for URLs or email addresses.
//
// Parameters:
//    XMLString - String - contact information XML string.
//
// Returns:
//    String - network address domain.
//
Function ContactInformationAddressDomain(Val XMLString) Export
	If IsBlankString(XMLString) Then
		Return "";
	EndIf;
	
	Namespace = ContactInformationClientServerCached.Namespace();
	Read = New XMLReader;
	Read.SetString(XMLString);
	XDTOAddress = XDTOFactory.ReadXML(Read, XDTOFactory.Type(Namespace, "ContactInformation"));
	Content = XDTOAddress.Content;
	If Content <> Undefined Then
		Type = Content.Type();
		If Type = XDTOFactory.Type(Namespace, "Website") Then
			AddressDomain = TrimAll(Content.Value);
			Position = Find(AddressDomain, "://");
			If Position > 0 Then
				AddressDomain = Mid(AddressDomain, Position + 3);
			EndIf;
			Position = Find(AddressDomain, "/");
			Return ?(Position = 0, AddressDomain, Left(AddressDomain, Position - 1));
			
		ElsIf Type = XDTOFactory.Type(Namespace, "Email") Then
			AddressDomain = TrimAll(Content.Value);
			Position = Find(AddressDomain, "@");
			Return ?(Position = 0, AddressDomain, Mid(AddressDomain, Position + 1));
			
		EndIf;
	EndIf;
	
	Raise NStr("en = 'Cannot determine domain; email or web link pending.'");	
EndFunction

// Returns a string containing a phone number without country code or extension.
//
// Parameters:
//    XMLString - String - contact information XML string.
//
// Returns:
//    String - phone number.
//
Function ContactInformationPhoneNumber(Val XMLString) Export
	If IsBlankString(XMLString) Then
		Return "";
	EndIf;
	
	Namespace = ContactInformationClientServerCached.Namespace();
	Read = New XMLReader;
	Read.SetString(XMLString);
	XDTOAddress = XDTOFactory.ReadXML(Read, XDTOFactory.Type(Namespace, "ContactInformation"));
	Content = XDTOAddress.Content;
	If Content <> Undefined Then
		Type = Content.Type();
		If Type = XDTOFactory.Type(Namespace, "PhoneNumber") Then
			Return TrimAll(Content.Number);
			
		ElsIf Type = XDTOFactory.Type(Namespace, "FaxNumber") Then
			Return TrimAll(Content.Number);
			
		EndIf;
	EndIf;
	
	Raise NStr("en = 'Cannot determine number; phone call or fax pending.'");
EndFunction

// Compares two sets of contact information.
//
// Parameters:
//    Data1 - XTDOObject - object containing contact information.
//          - String     - contact information in XML format.
//          - Structure  - contact information description. The following fields are expected:
//                 * FieldValues  - String, Structure, ValueList, Map - contact information fields.
//                 * Presentation - String  - Presentation. Used when presentation cannot be extracted 
//                                           from FieldValues (the Presentation field is not available).
//                 * Comment      - String  - comment. Used when comment cannot be extracted from FieldValues.
//                 * ContactInformationKind - CatalogRef.ContactInformationTypes,
//                                            EnumRef.ContactInformationTypes, Structure.
//                                            Used when type cannot be extracted from FieldValues.
//    Data2 - XTDOObject, String, Structure - similar to Data1.
//
// Returns:
//     ValueTable - table of differing fields, with the following columns:
//        * Path    - String - XPath identifying the value difference. ContactInformationType value
//                             specifies that the passed contact information sets have different types.
//        * Details - String - description of the differing attribute in terms of application business logic.
//        * Value1  - String - value matching the object passed in Data1 parameter.
//        * Value2  - String - value matching the object passed in Data2 parameter.
//
Function ContactInformationDifferences(Val Data1, Val Data2) Export
	Return ContactInformationXML.ContactInformationDifferences(Data1, Data2);
EndFunction

////////////////////////////////////////////////////////////////////////////////////////////////////

// Looks up country data in country catalog or Country classifier.
//
// Parameters:
//    CountryCode - String, Number - country code by country classifier. 
//                                   If not specified, search by code is not performed.
//    Description - String         - country description. If not specified, search by description is not performed.
//
// Returns:
//    Structure - country description. Contains the following fields:
//        * Ref             - CatalogRef.Countries, Undefined - Country item. 
//        * Description     - String - a part of country description.
//        * Code            - String - a part of country description.
//        * LongDescription - String - a part of country description.
//        * AlphaCode2      - String - a part of country description.
//        * AlphaCode3      - String - a part of country description.
//    Undefined - the country is found neither in the catalog nor in the classifier.
//
Function CountryData(Val CountryCode = Undefined, Val Description = Undefined) Export
	Return Catalogs.Countries.CountryData(CountryCode, Description);
EndFunction

// Determines country data using country classifier.
//
// Parameters:
//    CountryCode - String, Number - country code.
//
// Returns:
//    Structure - country description. Contains the following fields:
//        * Description     - String - a part of country description.
//        * Code            - String - a part of country description.
//        * LongDescription - String - a part of country description.
//        * AlphaCode2      - String - a part of country description.
//        * AlphaCode3      - String - a part of country description.
//    Undefined - the country is not found in the classifier.
//
Function CountryClassifierDataByCode(Val CountryCode) Export
	Return Catalogs.Countries.CountryClassifierDataByCode(CountryCode);
EndFunction

// Determines country data using country classifier.
//
// Parameters:
//    Description - String - country description.
//
// Returns:
//    Structure - country description. Contains the following fields:
//        * Description     - String - a part of country description.
//        * Code            - String - a part of country description.
//        * LongDescription - String - a part of country description.
//        * AlphaCode2      - String - a part of country description.
//        * AlphaCode3      - String - a part of country description.
//    Undefined - the country is not found in the classifier.
//
Function CountryClassifierDataByDescription(Val Description) Export
	Return Catalogs.Countries.CountryClassifierDataByDescription(Description);
EndFunction

////////////////////////////////////////////////////////////////////////////////////////////////////

// Obsolete. Use ObjectContactInformation instead.
//
Function GetObjectContactInformation(Ref, ContactInformationKind) Export
	Return ObjectContactInformation(Ref, ContactInformationKind);
EndFunction

// Gets a value of a specified contact information kind from an object.
//
// Parameters
//     Ref                    - AnyRef - reference to the contact information owner object 
//                              (company, counterparty, partner, and so on). 
//     ContactInformationKind - CatalogRef.ContactInformationTypes - contact information kind to be processed.
//
// Returns:
//     String - value represented as a string.
//
Function ObjectContactInformation(Ref, ContactInformationKind) Export
	
	ObjectArray = New Array;
	ObjectArray.Add(Ref);
	
	ObjectContactInformation = ObjectsContactInformation(ObjectArray,, ContactInformationKind);
	
	If ObjectContactInformation.Count() > 0 Then
		Return ObjectContactInformation[0].Presentation;
	EndIf;
	
	Return "";
	
EndFunction

// Creates a temporary table containing contact information for multiple objects
//
// Parameters:
//    TempTablesManager       - TempTablesManager - for generation purposes. 
//    ObjectArray             - Array - contact information owners (all items must have the same type). 
//    ContactInformationTypes - Array - optional, used if some of the types are undefined.
//    ContactInformationTypes - Array -  optional, used if some of the kinds are undefined.
//
// ContactInformationTemporaryTable is created in the temporary table manager. The table contains the following fields:
//    * Object       - Ref - contact information owner.
//    * Kind         - CatalogRef.ContactInformationTypes.
//    * Type         - EnumRef.ContactInformationTypes.
//    * FieldValues  - String - field value data. 
//    * Presentation - String - contact information presentation.
//
Procedure CreateContactInformationTemporaryTable(TempTablesManager, ObjectArray, ContactInfoTypes = Undefined, CIKinds = Undefined) Export
	
	If TypeOf(ObjectArray) = Type("Array") AND ObjectArray.Count() > 0 Then
		Ref = ObjectArray.Get(0);
	Else
		Raise NStr("en = 'Incorrect value for the array of contact information owners.'");
	EndIf;
	
	Query = New Query("
		|SELECT ALLOWED
		|	ContactInformation.Ref  AS Object,
		|	ContactInformation.Kind AS Kind,
		|	ContactInformation.Type AS Type,
		|	ContactInformation.FieldValues AS FieldValues,
		|	ContactInformation.Presentation AS Presentation
		|INTO ContactInformationTemporaryTable
		|FROM
		|	" + Ref.Metadata().FullName() + ".ContactInformation
		|AS
		|ContactInformation WHERE ContactInformation.Ref IN (&ObjectArray)
		|	" + ?(ContactInfoTypes = Undefined, "", "AND ContactInformation.Type IN (&ContactInfoTypes)") + "
		|	" + ?(CIKinds = Undefined, "", "AND ContactInformation.Kind IN (&CIKinds)") + "
		|");
	
	Query.TempTablesManager = TempTablesManager;
	
	Query.SetParameter("ObjectArray", ObjectArray);
	Query.SetParameter("ContactInfoTypes", ContactInfoTypes);
	Query.SetParameter("CIKinds", CIKinds);
	
	Query.Execute();
EndProcedure

// Gets contact information for multiple objects.
//
// Parameters:
//    ObjectArray             - Array - contact information owners (all items must have the same type).
//    ContactInformationTypes - Array - optional, used if some of the types are undefined. 
//    ContactInformationTypes - Array - optional, used if some of the kinds are undefined.
//
// Returns
//    Value table - result. Columns:
//        * Object       - Ref - contact information owner.
//        * Kind         - CatalogRef.ContactInformationTypes.
//        * Type         - EnumRef.ContactInformationTypes.
//        * FieldValues  - String - field value data.
//        * Presentation - String - contact information presentation.
//
Function ObjectsContactInformation(ObjectArray, ContactInfoTypes = Undefined, CIKinds = Undefined) Export
	
	Query = New Query;
	Query.TempTablesManager = New TempTablesManager;
	
	CreateContactInformationTemporaryTable(Query.TempTablesManager, ObjectArray, ContactInfoTypes, CIKinds);
	
	Query.Text =
	"SELECT
	|	ContactInformation.Object AS Object,
	|	ContactInformation.Kind   AS Kind,
	|	ContactInformation.Type   AS Type,
	|	ContactInformation.FieldValues  AS FieldValues,
	|	ContactInformation.Presentation AS Presentation
	|FROM
	|	ContactInformationTemporaryTable AS ContactInformation";
	
	Return Query.Execute().Unload();
	
EndFunction

// Fills in contact information for multiple objects.
//
// Parameters:
//    FillingData - ValueTable - describes objects to be filled in. Contains the following columns:
//        * Target      - Arbitrary - reference or object whose contact information must be filled in.
//        * CIKind      - CatalogRef.ContactInformationTypes  - contact information kind filled in the target.
//        * CIStructure - ValueList, String, Structure - contact information field value data.
//        * RowKey      - Structure - filter used to search the tabular section for a row
//                        where Key is the name of a tabular section column, and Value is the filter value.
//
Procedure FillObjectsContactInformation(FillingData) Export
	
	PreviousTarget = Undefined;
	FillingData.Sort("Target, CIKind");
	
	For Each FillString In FillingData Do
		
		Target = FillString.Target;
		If CommonUse.IsReference(TypeOf(Target)) Then
			Target = Target.GetObject();
		EndIf;
		
		If PreviousTarget <> Undefined AND PreviousTarget <> Target Then
			If PreviousTarget.Ref = Target.Ref Then
				Target = PreviousTarget;
			Else
				PreviousTarget.Write();
			EndIf;
		EndIf;
		
		CIKind = FillString.CIKind;
		TargetObjectName = Target.Metadata().Name;
		TabularSectionName = TabularSectionNameByCIKind(CIKind, TargetObjectName);
		
		If IsBlankString(TabularSectionName) Then
			FillTabularSectionContactInformation(Target, CIKind, FillString.CIStructure);
		Else
			If TypeOf(FillString.RowKey) <> Type("Structure") Then
				Continue;
			EndIf;
			
			If FillString.RowKey.Property("LineNumber") Then
				TabularSectionLineCount = Target[TabularSectionName].Count();
				LineNumber = FillString.RowKey.LineNumber;
				If LineNumber > 0 AND LineNumber <= TabularSectionLineCount Then
					TabularSectionRow = Target[TabularSectionName][LineNumber - 1];
					FillTabularSectionContactInformation(Target, CIKind, FillString.CIStructure, TabularSectionRow);
				EndIf;
			Else
				TabularSectionRows = Target[TabularSectionName].FindRows(FillString.RowKey);
				For Each TabularSectionRow In TabularSectionRows Do
					FillTabularSectionContactInformation(Target, CIKind, FillString.CIStructure, TabularSectionRow);
				EndDo;
			EndIf;
		EndIf;
		
		PreviousTarget = Target;
		
	EndDo;
	
	If PreviousTarget <> Undefined Then
		PreviousTarget.Write();
	EndIf;
	
EndProcedure

// Fills in contact information for a single object.
//
// Parameters:
//    Target      - Arbitrary - reference or object whose contact information must be filled in.
//    CIKind      - CatalogRef.ContactInformationTypes - contact information kind filled in the target.
//    CIStructure - Structure - filled contact information structure.
//    RowKey      - Structure - filter used to search the tabular section for a row
//                              where Key is the name of a tabular section column, and Value is filter value.
//
Procedure FillObjectContactInformation(Target, CIKind, CIStructure, RowKey = Undefined) Export
	
	FillingData = New ValueTable;
	FillingData.Columns.Add("Target");
	FillingData.Columns.Add("CIKind");
	FillingData.Columns.Add("CIStructure");
	FillingData.Columns.Add("RowKey");
	
	FillString = FillingData.Add();
	FillString.Target = Target;
	FillString.CIKind = CIKind;
	FillString.CIStructure = CIStructure;
	FillString.RowKey = RowKey;
	
	FillObjectsContactInformation(FillingData);
	
EndProcedure

#EndRegion

#EndRegion

#Region InternalInterface

//  Returns enumeration value of contact information kind type.
//
//  Parameters:
//    InformationKind - CatalogRef.ContactInformationTypes, Structure - data source.
//
Function ContactInformationKindType(Val InformationKind) Export
	Result = Undefined;
	
	Type = TypeOf(InformationKind);
	If Type = Type("EnumRef.ContactInformationTypes") Then
		Result = InformationKind;
	ElsIf Type = Type("CatalogRef.ContactInformationTypes") Then
		Result = InformationKind.Type;
	ElsIf InformationKind <> Undefined Then
		Data = New Structure("Type");
		FillPropertyValues(Data, InformationKind);
		Result = Data.Type;
	EndIf;
	
	Return Result;
EndFunction

#EndRegion

#Region InternalProceduresAndFunctions

// Filling event subscription handler.
//
Procedure FillContactInformationProcessing(Source, FillingData, FillingText, StandardProcessing) Export
	
	ObjectContactInformationFilling(Source, FillingData);
	
EndProcedure

// Filling event subscription handler for documents.
//
Procedure DocumentContactInformationFilling(Source, FillingData, StandardProcessing) Export
	
	ObjectContactInformationFilling(Source, FillingData);
	
EndProcedure

Procedure ObjectContactInformationFilling(Object, Val FillingData)
	
	If TypeOf(FillingData) <> Type("Structure") Then
		Return;
	EndIf;
	
	// Description, if available in the target object
	Description = Undefined;
	If FillingData.Property("Description", Description) 
		AND HasObjectAttribute("Description", Object) 
	Then
		Object.Description = Description;
	EndIf;
	
	// Contact information table. It is only filled if the contact information cannot be found in any other tabular section.
	ContactInformation = Undefined;
	If FillingData.Property("ContactInformation", ContactInformation) 
		AND HasObjectAttribute("ContactInformation", Object) 
	Then
	
		If TypeOf(ContactInformation) = Type("ValueTable") Then
			TableColumns = ContactInformation.Columns;
		Else
			TableColumns = ContactInformation.UnloadColumns().Columns;
		EndIf;
		
		If TableColumns.Find("ContactLineIdentifier") = Undefined Then
			
			For Each CIRow In ContactInformation Do
				NewCIRow = Object.ContactInformation.Add();
				FillPropertyValues(NewCIRow, CIRow, , "FieldValues");
				NewCIRow.FieldValues = ContactInformationToXML(CIRow.FieldValues, CIRow.Presentation, CIRow.Kind);
			EndDo;
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Checks the form for strings filled with contact information of the same kind (excluding the current string).
//
Function HasOtherStringsFilledWithThisContactInformationKind(Val Form, Val StringToValidate, Val ContactInformationKind)
	
	AllRowsOfThisKind = Form.ContactInformationAdditionalAttributeInfo.FindRows(
		New Structure("Kind", ContactInformationKind)
	);
	
	For Each RowOfThisKind In AllRowsOfThisKind Do
		
		If RowOfThisKind <> StringToValidate Then
			Presentation = Form[RowOfThisKind.AttributeName];
			If Not IsBlankString(Presentation) Then 
				Return True;
			EndIf;
		EndIf;
		
	EndDo;
	
	Return False;
EndFunction

// Checks whether an object has an attribute with the specified name.
//
// Parameters:
//     AttributeName - String    - name of the attribute to be checked.
//     Object        - Arbitrary - object to be checked.
//
// Returns:
//     Boolean - check result.
//
Function HasObjectAttribute(Val AttributeName, Val Object)
	AttributeCheck = New Structure(AttributeName, Undefined);
	FillPropertyValues(AttributeCheck, Object);
	If AttributeCheck[AttributeName] <> Undefined Then
		Return True;
	EndIf;
	
	AttributeCheck[AttributeName] = "";
	FillPropertyValues(AttributeCheck, Object);
	Return AttributeCheck.Description = Undefined;
EndFunction

// Updates contact information fields based on ValueTable of an object of different kind (such as catalog).
//
// Parameters:
//    Source - ValueTable  - value table containing contact information.
//    Target - ManagedForm - object form used to receive the contact information.
//
Procedure FillContactInformation(Source, Target) Export
	ContactInformationFieldCollection = Target.ContactInformationAdditionalAttributeInfo;
	
	For Each ContactInformationFieldCollectionItem In ContactInformationFieldCollection Do
		
		RowInCI = Source.Find(ContactInformationFieldCollectionItem.Kind, "Kind");
		If RowInCI <> Undefined Then
			Target[ContactInformationFieldCollectionItem.AttributeName] = RowInCI.Presentation;
			ContactInformationFieldCollectionItem.FieldValues          = ContactInformationManagementClientServer.ConvertStringToFieldList(RowInCI.FieldValues);
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure AddItemDetails(Form, ItemName, Priority, IsCommand = False, IsTabularSectionAttribute = False)
	
	NewRow = Form.AddedContactInformationItems.Add();
	NewRow.ItemName = ItemName;
	NewRow.Priority = Priority;
	NewRow.IsCommand = IsCommand;
	NewRow.IsTabularSectionAttribute = IsTabularSectionAttribute;
	
EndProcedure

Procedure DeleteItemDescription(Form, ItemName)
	
	AddedItems = Form.AddedContactInformationItems;
	Filter = New Structure("ItemName", ItemName);
	FoundRow = AddedItems.FindRows(Filter)[0];
	AddedItems.Delete(FoundRow);
	
EndProcedure

Function TitleLeft(Form, Val TitleLocationContactInformation = Undefined)
	
	If Not ValueIsFilled(TitleLocationContactInformation) Then
		
		SavedTitlePosition = Form.ContactInformationTitleLocation;
		If ValueIsFilled(SavedTitlePosition) Then
			TitleLocationContactInformation = FormItemTitleLocation[SavedTitlePosition];
		Else
			TitleLocationContactInformation = FormItemTitleLocation.Top;
		EndIf;
		
	EndIf;
	
	Return (TitleLocationContactInformation = FormItemTitleLocation.Left);
	
EndFunction

Procedure ModifyComment(Form, AttributeName, IsAddComment)
	
	ContactInformationDescription = Form.ContactInformationAdditionalAttributeInfo;
	
	Filter = New Structure("AttributeName", AttributeName);
	FoundRow = ContactInformationDescription.FindRows(Filter)[0];
	
	// Title and input field
	ItemTitle = Form.Items.Find("Title" + AttributeName);
	CommentName = "Comment" + AttributeName;
	
	TitleLeft = TitleLeft(Form);
	
	If IsAddComment Then
		
		TextBox = Form.Items.Find(AttributeName);
		InputFieldGroup = Form.Items.ContactInformationInputFieldGroup;
		
		CurrentItem = ?(InputFieldGroup.ChildItems.Find(TextBox.Name) = Undefined, TextBox.Parent, TextBox);
		CurrentItemIndex = InputFieldGroup.ChildItems.IndexOf(CurrentItem);
		NextItem = InputFieldGroup.ChildItems.Get(CurrentItemIndex + 1);
		
		Comment = Comment(Form, FoundRow.Comment, CommentName, InputFieldGroup);
		Form.Items.Move(Comment, InputFieldGroup, NextItem);
		
		If TitleLeft Then
			
			HeaderGroup = Form.Items.ContactInformationTitleGroup;
			TitleIndex = HeaderGroup.ChildItems.IndexOf(ItemTitle);
			NextTitle = HeaderGroup.ChildItems.Get(TitleIndex + 1);
			
			PlaceholderName = "TitlePlaceholder" + AttributeName;
			Placeholder = Form.Items.Add(PlaceholderName, Type("FormDecoration"), HeaderGroup);
			Form.Items.Move(Placeholder, HeaderGroup, NextTitle);
			AddItemDetails(Form, PlaceholderName, 2);
			
		EndIf;
		
	Else
		
		Comment = Form.Items[CommentName];
		Form.Items.Delete(Comment);
		DeleteItemDescription(Form, CommentName);
		
		If TitleLeft Then
			
			ItemTitle.Height = 1;
			
			PlaceholderName = "TitlePlaceholder" + AttributeName;
			TitlePlaceholder = Form.Items[PlaceholderName];
			Form.Items.Delete(TitlePlaceholder);
			DeleteItemDescription(Form, PlaceholderName);
			
		EndIf;
		
	EndIf;
	
	// Action
	ActionGroup = Form.Items.ContactInformationActionGroup;
	ActionPlaceholderName = "ActionPlaceholder" + AttributeName;
	ActionPlaceholder = Form.Items.Find(ActionPlaceholderName);
	
	If IsAddComment Then
		
		If ActionPlaceholder = Undefined Then
			
			ActionPlaceholder = Form.Items.Add(ActionPlaceholderName, Type("FormDecoration"), ActionGroup);
			ActionPlaceholder.Height = 1;
			Action = Form.Items["Command" + AttributeName];
			CommandIndex = ActionGroup.ChildItems.IndexOf(Action);
			NextItem = ActionGroup.ChildItems.Get(CommandIndex + 1);
			If ActionPlaceholder <> NextItem Then
				Form.Items.Move(ActionPlaceholder, ActionGroup, NextItem);
			EndIf;
			AddItemDetails(Form, ActionPlaceholderName, 2);
			
		Else
			
			ActionPlaceholder.Height = 2;
			
		EndIf;
		
	Else
		
		If ActionPlaceholder.Height = 1 Then
			
			Form.Items.Delete(ActionPlaceholder);
			DeleteItemDescription(Form, ActionPlaceholderName);
			
		Else
			
			ActionPlaceholder.Height = 1;
			
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure AddContactInformationString(Form, Result)
	
	AddedKind = Result.AddedKind;
	If TypeOf(AddedKind)= Type("CatalogRef.ContactInformationTypes") Then
		CIKindInformation = CommonUse.ObjectAttributeValues(AddedKind, "Type, Description, EditInDialogOnly, Tooltip");
	Else
		CIKindInformation = AddedKind;
		AddedKind    = AddedKind.Ref;
	EndIf;
	
	ContactInformationTable = Form.ContactInformationAdditionalAttributeInfo;
	
	Filter = New Structure("Kind", AddedKind);
	FoundRows = ContactInformationTable.FindRows(Filter);
	ItemCount = FoundRows.Count();
	
	LastRow = FoundRows.Get(ItemCount-1);
	AddedRowIndex = ContactInformationTable.IndexOf(LastRow) + 1;
	IsLastRow = False;
	If AddedRowIndex = ContactInformationTable.Count() Then
		IsLastRow = True;
	Else
		NextAttributeName = ContactInformationTable[AddedRowIndex].AttributeName;
	EndIf;
	
	NewRow = ContactInformationTable.Insert(AddedRowIndex);
	AttributeName = "ContactInformationField" + NewRow.GetID();
	NewRow.AttributeName = AttributeName;
	NewRow.Kind = AddedKind;
	NewRow.Type = CIKindInformation.Type;
	NewRow.IsTabularSectionAttribute = False;
	
	AttributesToAddArray = New Array;
	AttributesToAddArray.Add(New FormAttribute(AttributeName, New TypeDescription("String", , New StringQualifiers(500)), , CIKindInformation.Description, True));
	
	Form.ChangeAttributes(AttributesToAddArray);
	
	TitleLeft = TitleLeft(Form);
	
	// Displaying form items
	If TitleLeft Then
		HeaderGroup = Form.Items.ContactInformationTitleGroup;
		Title = ItemTitle(Form, CIKindInformation.Type, AttributeName, HeaderGroup, CIKindInformation.Description);
		
		If Not IsLastRow Then
			NextTitle = Form.Items["Title" + NextAttributeName];
			Form.Items.Move(Title, HeaderGroup, NextTitle);
		EndIf;
	EndIf;
	
	InputFieldGroup = Form.Items.ContactInformationInputFieldGroup;
	TextBox = TextBox(Form, CIKindInformation.EditInDialogOnly, CIKindInformation.Type, AttributeName, CIKindInformation.Tooltip);
	
	If Not IsLastRow Then
		
		NextItemName = LastRow.AttributeName;
		
		If ValueIsFilled(LastRow.Comment) Then
			NextItemName = "Comment" + NextItemName;
		EndIf;
		
		NextItemIndex = InputFieldGroup.ChildItems.IndexOf(Form.Items[NextItemName]) + 1;
		NextItem = InputFieldGroup.ChildItems.Get(NextItemIndex);
		
		Form.Items.Move(TextBox, InputFieldGroup, NextItem);
		
	EndIf;
	
	ActionGroup = Form.Items.ContactInformationActionGroup;
	Filter = New Structure("Type", Enums.ContactInformationTypes.Address);
	AddressCount = ContactInformationTable.FindRows(Filter).Count();
	
	ActionName = "Command" + NextAttributeName;
	PlaceholderName = "DecorationTop" + NextAttributeName;
	
	If Form.Items.Find(PlaceholderName) <> Undefined Then
		NextActionName = PlaceholderName;
	ElsIf Form.Items.Find(ActionName) <> Undefined Then
		NextActionName = ActionName;
	Else
		NextActionName = "ActionPlaceholder" + NextAttributeName;
	EndIf;
	
	Action = Action(Form, CIKindInformation.Type, AttributeName, ActionGroup, AddressCount);
	If Not IsLastRow Then
		NextAction = Form.Items[NextActionName];
		Form.Items.Move(Action, ActionGroup, NextAction);
	EndIf;
	
	Form.CurrentItem = Form.Items[AttributeName];
	
	If CIKindInformation.Type = Enums.ContactInformationTypes.Address
		AND CIKindInformation.EditInDialogOnly Then
		
		Result.Insert("AddressFormItem", AttributeName);
		
	EndIf;
	
EndProcedure

Function ItemTitle(Form, Type, AttributeName, HeaderGroup, Description, IsNewCIKind = False, HasComment = False)
	
	TitleName = "Title" + AttributeName;
	Item = Form.Items.Add(TitleName, Type("FormDecoration"), HeaderGroup);
	Item.Title = ?(IsNewCIKind, Description + ":", "");
	
	If Type = Enums.ContactInformationTypes.Other Then
		Item.Height = 5;
		Item.VerticalAlign = ItemVerticalAlign.Top;
	Else
		Item.VerticalAlign = ItemVerticalAlign.Center;
	EndIf;
	
	AddItemDetails(Form, TitleName, 2);
	
	If HasComment Then
		
		PlaceholderName = "TitlePlaceholder" + AttributeName;
		Placeholder = Form.Items.Add(PlaceholderName, Type("FormDecoration"), HeaderGroup);
		AddItemDetails(Form, PlaceholderName, 2);
		
	EndIf;
	
	Return Item;
	
EndFunction

Function TextBox(Form, EditInDialogOnly, Type, AttributeName, ToolTip, IsNewCIKind = False, Mandatory = False)
	
	TitleLeft = TitleLeft(Form);
	
	Item = Form.Items.Add(AttributeName, Type("FormField"), Form.Items.ContactInformationInputFieldGroup);
	Item.Type = FormFieldType.InputField;
	Item.ToolTip = ToolTip;
	Item.DataPath = AttributeName;
	Item.HorizontalStretch = True;
	Item.TitleLocation = ?(TitleLeft Or Not IsNewCIKind, FormItemTitleLocation.None, FormItemTitleLocation.Top);
	Item.SetAction("Clearing", "Attachable_ContactInformationClear");
	
	AddItemDetails(Form, AttributeName, 2);
	
	// Setting input field properties
	If Type = Enums.ContactInformationTypes.Other Then
		Item.Height = 5;
		Item.MultiLine = True;
		Item.VerticalStretch = False;
	Else
		
		// Entering comment via context menu
		CommandName = "ContextMenu" + AttributeName;
		Command = Form.Commands.Add(CommandName);
		Button = Form.Items.Add(CommandName,Type("FormButton"), Item.ContextMenu);
		Command.ToolTip = NStr("en = 'Enter a comment'");
		Command.Action = "Attachable_ContactInformationExecuteCommand";
		Button.Title = NStr("en = 'Enter a comment'");
		Button.CommandName = CommandName;
		Command.ModifiesStoredData = True;
		
		AddItemDetails(Form, CommandName, 1);
		AddItemDetails(Form, CommandName, 9, True);
	EndIf;
	
	If Mandatory AND IsNewCIKind Then
		Item.AutoMarkIncomplete = True;
	EndIf;
	
	// Editing in dialog
	If CanEditContactInformationTypeInDialog(Type) Then
		
		Item.ChoiceButton = True;
		
		If EditInDialogOnly Then
			Item.TextEdit = False;
			Item.BackColor = StyleColors.ContactInformationWithEditingInDialogColor;
		EndIf;
		Item.SetAction("StartChoice", "Attachable_ContactInformationStartChoice");
		
	EndIf;
	Item.SetAction("OnChange", "Attachable_ContactInformationOnChange");
	
	Return Item;
	
EndFunction

Function Action(Form, Type, AttributeName, ActionGroup, AddressCount, HasComment = False)
	
	If (Type = Enums.ContactInformationTypes.WebPage
		Or Type = Enums.ContactInformationTypes.EmailAddress)
		Or (Type = Enums.ContactInformationTypes.Address AND AddressCount > 1) Then
		
		// Action is available
		CommandName = "Command" + AttributeName;
		Command = Form.Commands.Add(CommandName);
		AddItemDetails(Form, CommandName, 9, True);
		Command.Representation = ButtonRepresentation.Picture;
		Command.Action = "Attachable_ContactInformationExecuteCommand";
		
		Item = Form.Items.Add(CommandName,Type("FormButton"), ActionGroup);
		AddItemDetails(Form, CommandName, 2);
		Item.CommandName = CommandName;
		
		If Type = Enums.ContactInformationTypes.Address Then
			
			Item.Title = NStr("en = 'Fill in'");
			Command.ToolTip = NStr("en = 'Fill in the address'");
			Command.Picture = PictureLib.MoveLeft;
			Command.ModifiesStoredData = True;
			
		ElsIf Type = Enums.ContactInformationTypes.WebPage Then
			
			Item.Title = NStr("en = 'Navigate'");
			Command.ToolTip = NStr("en = 'Click URL'");
			Command.Picture = PictureLib.ContactInformationGotoURL;
			
		ElsIf Type = Enums.ContactInformationTypes.EmailAddress Then
			
			Item.Title = NStr("en = 'Write an email'");
			Command.ToolTip = NStr("en = 'Write an email'");
			Command.Picture = PictureLib.SendEmail;
			
		EndIf;
		
		If HasComment Then
			
			ActionPlaceholderName = "ActionPlaceholder" + AttributeName;
			ActionPlaceholder = Form.Items.Add(ActionPlaceholderName, Type("FormDecoration"), ActionGroup);
			ActionPlaceholder.Height = 1;
			AddItemDetails(Form, ActionPlaceholderName, 2);
			
		EndIf;
		
	Else
		
		// Action is not available, using placeholder
		ActionPlaceholderName = "ActionPlaceholder" + AttributeName;
		Item = Form.Items.Add(ActionPlaceholderName, Type("FormDecoration"), ActionGroup);
		AddItemDetails(Form, ActionPlaceholderName, 2);
		If HasComment Then
			Item.Height = 2;
		ElsIf Type = Enums.ContactInformationTypes.Other Then
			Item.Height = 5;
		EndIf;
		
	EndIf;
	
	Return Item;
	
EndFunction

Function Comment(Form, Comment, CommentName, GroupForPlacement)
	
	Item = Form.Items.Add(CommentName, Type("FormDecoration"), GroupForPlacement);
	Item.Title = Comment;
	
	Item.TextColor = StyleColors.ExplanationText;
	
	Item.HorizontalStretch = True;
	Item.VerticalStretch  = False;
	Item.VerticalAlign  = ItemVerticalAlign.Top;
	
	Item.Height = 1;
	
	AddItemDetails(Form, CommentName, 2);
	
	Return Item;
	
EndFunction

Function Group(GroupName, Form, Parent, Grouping, DeletionOrder)
	
	NewFolder = Form.Items.Add(GroupName, Type("FormGroup"), Parent);
	NewFolder.Type = FormGroupType.UsualGroup;
	NewFolder.ShowTitle = False;
	NewFolder.Representation = UsualGroupRepresentation.None;
	NewFolder.Group = Grouping;
	AddItemDetails(Form, GroupName, DeletionOrder);
	
	Return NewFolder;
	
EndFunction

#Region FillingAdditionalAttributesOfContactInformationTabularSection

// Fills the additional attributes of Contact information tabular section for an address.
//
// Parameters:
//    TabularSectionRow - TabularSectionRow - contact information tabular section row to be filled.
//    Source            - XDTODataObject    - contact information.
//
Procedure FillTabularSectionAttributesForAddress(TabularSectionRow, Source)
	
	// Default preferences
	TabularSectionRow.Country = "";
	TabularSectionRow.Region = "";
	TabularSectionRow.City  = "";
	
	Address = Source.Content;
	
	Namespace = ContactInformationClientServerCached.Namespace();
	IsAddress = TypeOf(Address) = Type("XDTODataObject") AND Address.Type() = XDTOFactory.Type(Namespace, "Address");
	If IsAddress AND Address.Content <> Undefined Then 
		TabularSectionRow.Country = Address.Country;
		AddressUS = ContactInformationInternal.HomeCountryAddress(Address);
		If AddressUS <> Undefined Then
			// Domestic address
			TabularSectionRow.Region = AddressUS.Region;
			TabularSectionRow.City   = AddressUS.City;
		EndIf;
	EndIf;
	
EndProcedure

// Fills the additional attributes of Contact information tabular section for an email address.
//
// Parameters:
//    TabularSectionRow - TabularSectionRow - contact information tabular section row to be filled.
//    Source            - XDTODataObject    - contact information.
//
Procedure FillTabularSectionAttributesForEmailAddress(TabularSectionRow, Source)
	
	Result = CommonUseClientServer.SplitStringWithEmailAddresses(TabularSectionRow.Presentation, False);
	
	If Result.Count() > 0 Then
		TabularSectionRow.EmailAddress = Result[0].Address;
		
		Pos = Find(TabularSectionRow.EmailAddress, "@");
		If Pos <> 0 Then
			TabularSectionRow.ServerDomainName = Mid(TabularSectionRow.EmailAddress, Pos+1);
		EndIf;
	EndIf;
	
EndProcedure

// Fills the additional attributes of Contact information tabular section for phone and fax numbers.
//
// Parameters:
//    TabularSectionRow - TabularSectionRow - contact information tabular section row to be filled.
//    Source            - XDTODataObject    - contact information.
//
Procedure FillTabularSectionAttributesForPhone(TabularSectionRow, Source)
	
	// Default preferences
	TabularSectionRow.PhoneNumberWithoutCodes = "";
	TabularSectionRow.PhoneNumber         = "";
	
	Phone = Source.Content;
	Namespace = ContactInformationClientServerCached.Namespace();
	If Phone <> Undefined AND Phone.Type() = XDTOFactory.Type(Namespace, "PhoneNumber") Then
		CountryCode     = Phone.CountryCode;
		AreaCode     = Phone.AreaCode;
		PhoneNumber = Phone.Number;
		
		If Left(CountryCode, 1) = "+" Then
			CountryCode = Mid(CountryCode, 2);
		EndIf;
		
		Pos = Find(PhoneNumber, ",");
		If Pos <> 0 Then
			PhoneNumber = Left(PhoneNumber, Pos-1);
		EndIf;
		
		Pos = Find(PhoneNumber, Chars.LF);
		If Pos <> 0 Then
			PhoneNumber = Left(PhoneNumber, Pos-1);
		EndIf;
		
		TabularSectionRow.PhoneNumberWithoutCodes = RemoveSeparatorsFromPhoneNumber(PhoneNumber);
		TabularSectionRow.PhoneNumber         = RemoveSeparatorsFromPhoneNumber(String(CountryCode) + AreaCode + PhoneNumber);
	EndIf;
	
EndProcedure

// Fills the additional attributes of Contact information tabular section for phone and fax numbers.
//
// Parameters:
//    TabularSectionRow - TabularSectionRow - contact information tabular section row to be filled.
//    Source            - XDTODataObject    - contact information.
//
Procedure FillTabularSectionAttributesForWebPage(TabularSectionRow, Source)
	
	// Default preferences
	TabularSectionRow.ServerDomainName = "";
	
	PageAddress = Source.Content;
	Namespace = ContactInformationClientServerCached.Namespace();
	If PageAddress <> Undefined AND PageAddress.Type() = XDTOFactory.Type(Namespace, "Website") Then
		AddressAsString = PageAddress.Value;
		
		// Deleting the protocol
		ServerAddress = Right(AddressAsString, StrLen(AddressAsString) - Find(AddressAsString, "://") );
		Pos = Find(ServerAddress, "/");
		// Deleting the path
		ServerAddress = ?(Pos = 0, ServerAddress, Left(ServerAddress,  Pos-1));
		
		TabularSectionRow.ServerDomainName = ServerAddress;
		
	EndIf;
	
EndProcedure

// Fills the contact information in Contact information tabular section of the target.
//
// Parameters:
//     * Target            - Arbitrary - object whose contact information is to be filled.
//     * CIKind            - CatalogRef.ContactInformationTypes - contact information kind filled in the target.
//     * CIStructure       - ValueList, String, Structure - values of contact information fields.
//     * TabularSectionRow - TabularSectionRow, Undefined - target data if contact information is filled
//                                                          for a row. Undefined if contact information is 
//                                                          filled for the target.
//
Procedure FillTabularSectionContactInformation(Target, CIKind, CIStructure, TabularSectionRow = Undefined)
	
	FilterParameters = New Structure;
	If TabularSectionRow = Undefined Then
		FillingData = Target;
	Else
		FillingData = TabularSectionRow;
		FilterParameters.Insert("ContactLineIdentifier", TabularSectionRow.ContactLineIdentifier);
	EndIf;
	
	FilterParameters.Insert("Kind", CIKind);
	FoundCIRows  = Target.ContactInformation.FindRows(FilterParameters);
	If FoundCIRows.Count() = 0 Then
		CIRow = Target.ContactInformation.Add();
		If TabularSectionRow <> Undefined Then
			CIRow.ContactLineIdentifier = TabularSectionRow.ContactLineIdentifier;
		EndIf;
	Else
		CIRow = FoundCIRows[0];
	EndIf;
	
	// Converting from any readable format to XML
	FieldValues = ContactInformationToXML(CIStructure, , CIKind);
	Presentation = ContactInformationPresentation(FieldValues);
	
	CIRow.Type           = CIKind.Type;
	CIRow.Kind           = CIKind;
	CIRow.Presentation = Presentation;
	CIRow.FieldValues = FieldValues;
	
	FillContactInformationAdditionalAttributes(CIRow, Presentation, FieldValues);
EndProcedure

// Validates an address contact information and reports any errors. Returns the error flag.
//
// Parameters:
//     Source          - XDTODataObject - contact information.
//     InformationKind - CatalogRef.ContactInformationTypes - contact information kind 
//                                                            with validation settings.
//     AttributeName   - String - name of the attribute used to link the error message (optional).
//
// Returns:
//     Number - error level (0 - none, 1 - noncritical, 2 - critical).
//
Function AddressFillErrors(Source, InformationKind, AttributeName = "", AttributeField = "")
	If Not InformationKind.CheckValidity Then
		Return 0;
	EndIf;
	HasErrors = False;
	
	Address = Source.Content;
	Namespace = ContactInformationClientServerCached.Namespace();
	If Address <> Undefined AND Address.Type() = XDTOFactory.Type(Namespace, "Address") Then
		ErrorList = ContactInformationInternal.AddressFillErrors(Address, InformationKind);
		For Each Item In ErrorList Do
			DisplayUserMessage(Item.Presentation, AttributeName, AttributeField);
			HasErrors = True;
		EndDo;
	EndIf;
	
	If HasErrors AND InformationKind.ProhibitInvalidEntry Then
		Return 2;
	ElsIf HasErrors Then
		Return 1;
	EndIf;
	
	Return 0;
EndFunction

// Validates a phone contact information and reports any errors. Returns the error flag.
//
//     Source          - XDTODataObject - contact information.
//     InformationKind - CatalogRef.ContactInformationTypes - contact information kind
//                                                            with validation settings.
//     AttributeName   - String - name of the attribute used to link the error message (optional).
//
// Returns:
//     Number - error level (0 - none, 1 - noncritical, 2 - critical).
//
Function PhoneFillingErrors(Source, InformationKind, AttributeName = "")
	Return 0;
EndFunction

// Removes separators from a phone number.
//
// Parameters:
//    PhoneNumber - String - phone or fax number.
//
// Returns:
//     String - phone or fax number with separators removed.
//
Function RemoveSeparatorsFromPhoneNumber(Val PhoneNumber)
	
	Pos = Find(PhoneNumber, ",");
	If Pos <> 0 Then
		PhoneNumber = Left(PhoneNumber, Pos-1);
	EndIf;
	
	PhoneNumber = StrReplace(PhoneNumber, "-", "");
	PhoneNumber = StrReplace(PhoneNumber, " ", "");
	PhoneNumber = StrReplace(PhoneNumber, "+", "");
	
	Return PhoneNumber;
	
EndFunction

// Validates contact information and writes it to a value table.
//
Function ValidateContactInformation(Presentation, FieldValues, InformationKind, InformationType,
	AttributeName, Comment = Undefined, AttributePath = "") Export
	
	SerializationText = ?(IsBlankString(FieldValues), Presentation, FieldValues);
	
	CIObject = ContactInformationInternal.ContactInformationDeserialization(SerializationText, InformationKind);
	If Comment <> Undefined Then
		ContactInformationInternal.ContactInformationComment(CIObject, Comment);
	EndIf;
	
	ContactInformationInternal.ContactInformationPresentation(CIObject, Presentation);
	FieldValues = ContactInformationInternal.ContactInformationSerialization(CIObject);
	
	If IsBlankString(Presentation) AND IsBlankString(CIObject.Comment) Then
		Return 0;
	EndIf;
	
	// Checking
	If InformationType = Enums.ContactInformationTypes.EmailAddress Then
		ErrorLevel = EmailFIllingErrors(CIObject, InformationKind, AttributeName, AttributePath);
	ElsIf InformationType = Enums.ContactInformationTypes.Address Then
		ErrorLevel = AddressFillErrors(CIObject, InformationKind, AttributeName);
	ElsIf InformationType = Enums.ContactInformationTypes.Phone Then
		ErrorLevel = PhoneFillingErrors(CIObject, InformationKind, AttributeName);
	ElsIf InformationType = Enums.ContactInformationTypes.Fax Then
		ErrorLevel = PhoneFillingErrors(CIObject, InformationKind, AttributeName);
	ElsIf InformationType = Enums.ContactInformationTypes.WebPage Then
		ErrorLevel = WebpageFillingErrors(CIObject, InformationKind, AttributeName);
	Else
		// No validation is performed for other information types
		ErrorLevel = 0;
	EndIf;
	
	Return ErrorLevel;
	
EndFunction

Procedure WriteContactInformation(Object, FieldValues, InformationKind, InformationType, RowID = 0) Export
	
	CIObject = ContactInformationInternal.ContactInformationDeserialization(FieldValues, InformationKind);
	
	If Not ContactInformationInternal.XDTOContactInformationFilled(CIObject) Then
		Return;
	EndIf;
	
	NewRow = Object.ContactInformation.Add();
	NewRow.Presentation   = CIObject.Presentation;
	NewRow.FieldValues    = ContactInformationInternal.ContactInformationSerialization(CIObject);
	NewRow.Kind           = InformationKind;
	NewRow.Type           = InformationType;
	
	If ValueIsFilled(RowID) Then
		NewRow.ContactLineIdentifier = RowID;
	EndIf;
	
	// Filling additional attributes of the tabular section
	If InformationType = Enums.ContactInformationTypes.EmailAddress Then
		FillTabularSectionAttributesForEmailAddress(NewRow, CIObject);
		
	ElsIf InformationType = Enums.ContactInformationTypes.Address Then
		FillTabularSectionAttributesForAddress(NewRow, CIObject);
		
	ElsIf InformationType = Enums.ContactInformationTypes.Phone Then
		FillTabularSectionAttributesForPhone(NewRow, CIObject);
		
	ElsIf InformationType = Enums.ContactInformationTypes.Fax Then
		FillTabularSectionAttributesForPhone(NewRow, CIObject);
		
	ElsIf InformationType = Enums.ContactInformationTypes.WebPage Then
		FillTabularSectionAttributesForWebPage(NewRow, CIObject);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region InternalProcedures

// Fills the additional attributes of Contact information tabular section row.
//
// Parameters:
//    CIRow        - TabularSectionRow     - contact information row.
//    Presentation - String                - value presentation.
//    FieldValues  - ValueList, XTDOObject - field values.
//
Procedure FillContactInformationAdditionalAttributes(CIRow, Presentation, FieldValues)
	
	If TypeOf(FieldValues) = Type("XDTODataObject") Then
		CIObject = FieldValues;
	Else
		CIObject = ContactInformationInternal.ContactInformationDeserialization(FieldValues, CIRow.Kind);
	EndIf;
	
	InformationType = CIRow.Type;

	If InformationType = Enums.ContactInformationTypes.EmailAddress Then
		FillTabularSectionAttributesForEmailAddress(CIRow, CIObject);
		
	ElsIf InformationType = Enums.ContactInformationTypes.Address Then
		FillTabularSectionAttributesForAddress(CIRow, CIObject);
		
	ElsIf InformationType = Enums.ContactInformationTypes.Phone Then
		FillTabularSectionAttributesForPhone(CIRow, CIObject);
		
	ElsIf InformationType = Enums.ContactInformationTypes.Fax Then
		FillTabularSectionAttributesForPhone(CIRow, CIObject);
		
	ElsIf InformationType = Enums.ContactInformationTypes.WebPage Then
		FillTabularSectionAttributesForWebPage(CIRow, CIObject);
		
	EndIf;
	
EndProcedure

// Returns an empty address structure.
//
// Returns:
//    Structure - address description containing field names (keys) and field values.
//
Function GetEmptyAddressStructure() Export
	
	Return ContactInformationManagementClientServer.AddressFieldStructure();
	
EndFunction

// Returns the flag specifying whether contact information can be edited in a dialog.
//
// Parameters:
//    Type - EnumRef.ContactInformationTypes - contact information type.
//
// Returns:
//    Boolean - dialog information edit flag.
//
Function CanEditContactInformationTypeInDialog(Type)
	
	If Type = Enums.ContactInformationTypes.Address Then
		Return True;
	ElsIf Type = Enums.ContactInformationTypes.Phone Then
		Return True;
	ElsIf Type = Enums.ContactInformationTypes.Fax Then
		Return True;
	Else
		Return False;
	EndIf;
	
EndFunction

// Returns the name of a document tabular section by contact information kind.
//
// Parameters:
//    CIKind     - CatalogRef.ContactInformationTypes - contact information kind.
//    ObjectName - String                             - full name of a metadata object.
//
// Returns:
//    String - tabular section name, or an empty string if the tabular section is not available.
//
Function TabularSectionNameByCIKind(CIKind, ObjectName) Export
	
	CIKindGroup = CommonUse.ObjectAttributeValue(CIKind, "Parent");
	CIKindName = CommonUse.PredefinedName(CIKindGroup);
	Pos = Find(CIKindName, ObjectName);
	
	Return Mid(CIKindName, Pos + StrLen(ObjectName));
	
EndFunction

Procedure SetValidationAttributeValues(Object, ValidationSettings = Undefined)
	
	Object.CheckValidity				= ?(ValidationSettings = Undefined, False, ValidationSettings.CheckValidity);
	Object.DomesticAddressOnly			= False;
	Object.IncludeCountryInPresentation	= False;
	Object.ProhibitInvalidEntry			= ?(ValidationSettings = Undefined, False, ValidationSettings.ProhibitInvalidEntry);
	Object.HideObsoleteAddresses		= False;
	
EndProcedure

Procedure AddAttributeToDetails(Form, CIRow, IsNewCIKind, IsTabularSectionAttribute = False)
	
	NewRow = Form.ContactInformationAdditionalAttributeInfo.Add();
	NewRow.AttributeName  = CIRow.AttributeName;
	NewRow.Kind           = CIRow.Kind;
	NewRow.Type           = CIRow.Type;
	NewRow.IsTabularSectionAttribute = IsTabularSectionAttribute;
	
	If IsBlankString(CIRow.FieldValues) Then
		NewRow.FieldValues = "";
	Else
		NewRow.FieldValues = ContactInformationManagementClientServer.ConvertStringToFieldList(CIRow.FieldValues);
	EndIf;
	
	NewRow.Presentation = CIRow.Presentation;
	NewRow.Comment      = CIRow.Comment;
	
	If Not IsTabularSectionAttribute Then
		
		Form[CIRow.AttributeName] = CIRow.Presentation;
		
	EndIf;
	
	CIKindStructure = ContactInformationTypestructure(CIRow.Kind);
	CIKindStructure.Insert("Ref", CIRow.Kind);
	
	If IsNewCIKind AND CIKindStructure.AllowMultipleValueInput AND Not IsTabularSectionAttribute Then
		
		Form.AddedContactInformationItemList.Add(CIKindStructure, CIRow.Kind.Description);
		
	EndIf;
	
EndProcedure

Procedure DeleteCommandsAndFormItems(Form)
	
	AddedItems = Form.AddedContactInformationItems;
	AddedItems.Sort("Priority");
	
	For Each ElementToDelete In AddedItems Do
		
		If ElementToDelete.IsCommand Then
			Form.Commands.Delete(Form.Commands[ElementToDelete.ItemName]);
		Else
			Form.Items.Delete(Form.Items[ElementToDelete.ItemName]);
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure DisplayUserMessage(MessageText, AttributeName, AttributeField)
	
	AttributeName = ?(IsBlankString(AttributeField), AttributeName, "");
	CommonUseClientServer.MessageToUser(MessageText,,AttributeField, AttributeName);
	
EndProcedure

#EndRegion

#Region InfobaseUpdate

// Constructor used to create a structure containing fields compatible 
//  with the contact information kind catalog.
//
// Parameters:
//     Source - CatalogRef.ContactInformationTypes - data source (optional).
//
// Returns:
//     Structure - containing fields compatible with the contact information kind catalog.
//
Function ContactInformationTypestructure(Val Source = Undefined) Export
	
	MetaAttributes = Metadata.Catalogs.ContactInformationTypes.Attributes;
	
	If TypeOf(Source) = Type("CatalogRef.ContactInformationTypes") Then
		Attributes = "Description";
		For Each Meta In MetaAttributes Do
			Attributes = Attributes + "," + Meta.Name;
		EndDo;
		
		Return CommonUse.ObjectAttributeValues(Source, Attributes);
	EndIf;
	
	Result = New Structure("Description", "");
	For Each Meta In MetaAttributes Do
		Result.Insert(Meta.Name, Meta.Type.AdjustValue());
	EndDo;
	
	Return Result;
EndFunction

#EndRegion

#EndRegion

#EndRegion

#Region ServiceProceduresAndFunctions

// Returns document tabular section name by the contact information kind.
//
// Parameters:
//    CIKind      - CatalogRef.ContactInformationTypes - kind of contact information.
//    ObjectName - String - full name of metadata object.
//
// Returns:
//    String - tabular section name of an empty string if there is no tabular section.
//
Function TabularSectionNameByCI(CIKind, ObjectName) Export
	
	GroupTypeKI = CommonUse.ObjectAttributeValue(CIKind, "Parent");
	NameKindKI = CommonUse.PredefinedName(GroupTypeKI);
	Pos = Find(NameKindKI, ObjectName);
	
	Return Mid(NameKindKI, Pos + StrLen(ObjectName));
	
EndFunction

// It converts all incoming formats of contact information into XML.
//
// Parameters:
//    FieldsValues - String, Structure, Map, ValuesList - contact information fields description.
//    Presentation - String  - presentation. Used if it is impossible to determine presentation from parameter.
//                    FieldsValues (there is no "Presentation" field).
//    ExpectedKind  - CatalogRef.ContactInformationTypes, EnumRef.ContactInformationTypes - 
//                    Used to determine the type if it is impossible to find it by the FieldsValues field.
//
// Returns:
//     String  - contact information XML data.
//
Function XMLContactInformation(Val FieldsValues, Val Presentation = "", Val ExpectedKind = Undefined) Export
	
	Result = ContactInformationManagementService.CastContactInformationXML(New Structure(
		"FieldsValues, Presentation, ContactInformationKind",
		FieldsValues, Presentation, ExpectedKind));
	Return Result.DataXML;
	
EndFunction

// Receives contact information presentation (address, phone, e-email etc.).
//
// Parameters:
//    XMLString               - XDTOObject, Row - object or contact information XML.
//    ContactInformationKind - Structure - additional parameters of forming presentation for addresses:
//      * IncludeCountriesToPresentation - Boolean - address country will be included to the presentation;
//      * AddressFormat                 - String - If ADDRCLASS is specified, then district
// and urban district are not included in the addresses presentation.
//
// Returns:
//    String - contact information presentation.
//
Function PresentationContactInformation(Val XMLString, Val ContactInformationKind = Undefined) Export
	
	Return ContactInformationManagementService.PresentationContactInformation(XMLString, ContactInformationKind);
	
EndFunction

// Handler of the "FillingDataProcessor" event subscription.
//
Procedure FillingContactInformation(Source, FillingData, FillingText, StandardProcessing) Export
	
	ObjectContactInformationFillingDataProcessor(Source, FillingData);
	
EndProcedure

Procedure ObjectContactInformationFillingDataProcessor(Object, Val FillingData)
	
	If TypeOf(FillingData) <> Type("Structure") Then
		Return;
	EndIf;
	
	// Name if there is one in the object-receiver.
	Description = Undefined;
	If FillingData.Property("Description", Description) 
		AND IsObjectAttribute("Description", Object) 
	Then
		Object.Description = Description;
	EndIf;
	
	// Contact information table, filled in only if CI is not in another TS.
	ContactInformation = Undefined;
	If FillingData.Property("ContactInformation", ContactInformation) 
		AND IsObjectAttribute("ContactInformation", Object) 
	Then
	
		If TypeOf(ContactInformation) = Type("ValueTable") Then
			TableColumns = ContactInformation.Columns;
		Else
			TableColumns = ContactInformation.UnloadColumns().Columns;
		EndIf;
		
		If TableColumns.Find("RowIdTableParts") = Undefined Then
			
			For Each CIRow In ContactInformation Do
				NewCIRow = Object.ContactInformation.Add();
				FillPropertyValues(NewCIRow, CIRow, , "FieldsValues");
				NewCIRow.FieldsValues = ContactInformationToXML(CIRow.FieldsValues, CIRow.Presentation, CIRow.Type);
			EndDo;
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Determines whether object has attribute with the specified name.
//
// Parameters:
//     AttributeName - String       - Attribute name presence of which is checked.
//     Object       - Arbitrary - Checking object.
//
// Returns:
//     Boolean - checking result.
//
Function IsObjectAttribute(Val AttributeName, Val Object)
	CheckAttribute = New Structure(AttributeName, Undefined);
	FillPropertyValues(CheckAttribute, Object);
	If CheckAttribute[AttributeName] <> Undefined Then
		Return True;
	EndIf;
	
	CheckAttribute[AttributeName] = "";
	FillPropertyValues(CheckAttribute, Object);
	Return CheckAttribute.Description = Undefined;
EndFunction

// Returns parameters structure of contact information kind for a definite type
// 
// Parameters:
//    Type - EnumRef.ContactInformationTypes, String - contact information type
//                                                                for the CheckSettings property filling
// 
// Returns:
//    Structure - contains structure with fields:
//        * Kind - CatalogRef.ContactInformationTypes, String   - Ref to the contact
//                                                                      information kind or the predefined item ID.
//        * Type - EnumRef.ContactInformationTypes - Contact information type
//                                                                      or its identifier.
//        * Tooltip - String                                        - Tooltip to the contact information kind.
//        * Order - Number, Undefined                             - Contact information kind order,
//                                                                      position in list relatively to the other items:
//                                                                          Undefined - not reassign;
//                                                                          0            - assign automatically;
//                                                                          Number > 0    - assign specified order.
//        * CanChangeEditingMethod - Boolean                - True if there is an
//                                                                      opportunity to change editing method only in the
//                                                                      dialog, False - else.
//        * EditOnlyInDialog - Boolean                     - True if you edit only
//                                                                      in the dialog, False - else.
//        * Mandatory                                    - Boolean - True if mandatory
//                                                                      field filling is required, False - else.
//        * AllowSeveralValuesOutput - Boolean                  - Shows that it
//                                                                      is possible to use additional input fields for
//                                                                      the specified kind.
//        * CheckSettings - Structure, Undefined               - Settings of the contact information kind check.
//            For the Address type - Structure containing fields:
//                * DomesticAddressOnly        - Boolean - True if only domestic addresses are used, False -
//                                                          else.
//                * CheckValidity        - Boolean - True if address is checked by
//                                                          profiles (Only if DomesticAddressOnly = True), False - else.
//                * ProhibitEntryIncorrect   - Boolean - True if it is required
//                                                          to prohibit user to write incorrect
//                                                          address (Only if CheckValidity = True), False - else.
//                * HideObsoleteAddresses   - Boolean - True if it is not required to
//                                                          show irrelevant addresses while entering
//                                                          (Only if DomesticAddressOnly = True), False - else.
//                * IncludeCountriesToPresentation - Boolean - True if it is required to
//                                                          include country name to the address presentation, False - else.
//            For the EmailAddress type - Structure containing fields:
//                * CheckValidity        - Boolean - True if it is required to check
//                                                          whether email address is correct, False - else.
//                * ProhibitEntryIncorrect   - Boolean - True if it is required
//                                                          to prohibit user to
//                                                          write incorrect address (Only if CheckValidity = True),
//                                                          False - else.
//            For the rest of the types or to specify the default settings Undefined is used.
// 
// Note:
//    To set the CheckValidity parameter to the True value, you
//    should set the ProhibitEntryIncorrect parameter to the True value.
// 
//    While using the Order parameter, you should closely monitor the uniqueness of the assigned value. If
//    after the update order values are non unique, then user will
//    not be able to set order.
//    It is generally recommended not to use this parameter (the order does not change)
//    or to fill it in with 0 value (the order will be automatically assigned to the "Items order setting" subsystem
//    while executing the procedure). To put CI kinds in a particular order relative to each other without explicit
//    placement at the top of the list, it is enough to call this procedure
//    in the required sequence for each CI kind with order specification 0. If a definite predefined CI kind is added to
//    the existing ones in IB, it is not recommended to assign order explicitly.
// 
Function ContactInformationKindParameters(Type = Undefined) Export
	
	If TypeOf(Type) = Type("String") Then
		SetType = Enums.ContactInformationTypes[Type];
	Else
		SetType = Type;
	EndIf;
	
	ParametersKind = New Structure;
	ParametersKind.Insert("Kind");
	ParametersKind.Insert("Type", SetType);
	ParametersKind.Insert("ToolTip");
	ParametersKind.Insert("Order");
	ParametersKind.Insert("CanChangeEditMode", False);
	ParametersKind.Insert("EditInDialogOnly", False);
	ParametersKind.Insert("Mandatory", False);
	ParametersKind.Insert("AllowMultipleValueInput", False);
	
	If SetType = Enums.ContactInformationTypes.Address Then
		VerificationSettings = New Structure;
		VerificationSettings.Insert("DomesticAddressOnly", False);
		VerificationSettings.Insert("CheckValidity", False);
		VerificationSettings.Insert("ProhibitInvalidEntry", False);
		VerificationSettings.Insert("HideObsoleteAddresses", False);
		VerificationSettings.Insert("IncludeCountryInPresentation", False);
	ElsIf SetType = Enums.ContactInformationTypes.EmailAddress Then
		VerificationSettings = New Structure;
		VerificationSettings.Insert("CheckValidity", False);
		VerificationSettings.Insert("ProhibitInvalidEntry", False);
	ElsIf SetType = Enums.ContactInformationTypes.Phone Then
		VerificationSettings = New Structure;
	Else
		VerificationSettings = Undefined;
	EndIf;
	
	ParametersKind.Insert("VerificationSettings", VerificationSettings);
	
	Return ParametersKind;
	
EndFunction

// Sets contact information kind properties.
// 
// Parameters:
//    Parameters - Structure - See description in the ContactInformationKindParameters function
// 
Procedure SetContactInformationKindProperties(Parameters) Export
	
	If TypeOf(Parameters.Kind) = Type("String") Then
		Object = Catalogs.ContactInformationTypes[Parameters.Kind].GetObject();
	Else
		Object = Parameters.Kind.GetObject();
	EndIf;
	
	Object.Type						= Parameters.Type;
	Object.CanChangeEditMode		= Parameters.CanChangeEditMode;
	Object.EditInDialogOnly         = Parameters.EditInDialogOnly;
	Object.Mandatory				= Parameters.Mandatory;
	Object.AllowMultipleValueInput	= Parameters.AllowMultipleValueInput;
	
	VerificationSettings	= Parameters.VerificationSettings;
	CheckSettings	= TypeOf(VerificationSettings) = Type("Structure");
	
	If CheckSettings AND Parameters.Type = Enums.ContactInformationTypes.Address Then
		FillPropertyValues(Object, VerificationSettings);
	ElsIf CheckSettings AND Parameters.Type = Enums.ContactInformationTypes.EmailAddress Then
		SetValidationAttributeValues(Object, VerificationSettings);
	ElsIf CheckSettings AND Parameters.Type = Enums.ContactInformationTypes.Phone Then
	Else
		SetValidationAttributeValues(Object);
	EndIf;
	
	If Parameters.Order <> Undefined Then
		Object.AdditionalOrderingAttribute = Parameters.Order;
	EndIf;
	
	UpdateResults.WriteData(Object);
	
EndProcedure

// It parses  contact information presentation and returns XML string.
// For mailing addresses correct parsing is not guaranteed.
//
//  Parameters:
//      Presentation - String  - row contact information presentation displayed to a user.
//      ExpectedKind  - CatalogRef.ContactInformationTypes, EnumRef.ContactInformationTypes, Structure
//
// Returns:
//      String - contact information in XML.
//
Function ContactInformationXMLByPresentation(Presentation, ExpectedKind) Export
	
	Return ContactInformationInternal.ContactInformationSerialization(
		ContactInformationInternal.ContactInformationParsing(Presentation, ExpectedKind));
		
EndFunction

// It parses  contact information presentation and returns XML string.
// For mailing addresses correct parsing is not guaranteed.
//
//  Parameters:
//      Presentation - String  - row contact information presentation displayed to a user.
//      ExpectedKind  - CatalogRef.ContactInformationTypes, EnumRef.ContactInformationTypes, Structure
//
// Returns:
//      String - contact information in XML.
//
Function PresentationXMLContactInformation(Presentation, ExpectedKind) Export
	
	Return ContactInformationInternal.ContactInformationSerialization(
		ContactInformationInternal.ContactInformationParsing(Presentation, ExpectedKind));
		
EndFunction

// Receives comment for contact information.
//
// Parameters:
//   XMLString   - XDTOObject, Row - object or contact information XML. 
//   Comment - String - comment new value.
//
//
Procedure SetContactInformationComment(XMLString, Val Comment) Export
	
	IsRow = TypeOf(XMLString) = Type("String");
	If IsRow AND Not ContactInformationClientServer.IsXMLString(XMLString) Then
		// Previous field values format, no comment.
		Return;
	EndIf;
	
	XDTODataObject = ?(IsRow, ContactInformationInternal.ContactInformationDeserialization(XMLString), XMLString);
	XDTODataObject.Comment = Comment;
	If IsRow Then
		XMLString = ContactInformationInternal.ContactInformationSerialization(XDTODataObject);
	EndIf;
	
EndProcedure

Procedure OutputMessageToUser(MessageText, AttributeName, AttributeField)
	
	AttributeName = ?(IsBlankString(AttributeField), AttributeName, "");
	CommonUseClientServer.MessageToUser(MessageText,,AttributeField, AttributeName);
	
EndProcedure

// Checks email contact information and informs about errors. 
//
// Parameters:
//     Source      - XDTODataObject - contact information.
//     InformationKind - CatalogRef.ContactInformationTypes - contact information kind with checking settings.
//     AttributeName  - String - optional attribute name for binding error message.
//
// Returns:
//     Number - errors level: 0 - no, 1 - nonlocking, 2 - locking.
//
Function EmailFIllingErrors(Source, InformationKind, Val AttributeName = "", AttributeField = "")
	
	If Not InformationKind.CheckValidity Then
		Return 0;
	EndIf;
	
	ErrorString = "";
	
	EMail_Address = Source.Content;
	TargetNamespace = ContactInformationManagementClientServerReUse.TargetNamespace();
	If EMail_Address <> Undefined AND EMail_Address.Type() = XDTOFactory.Type(TargetNamespace, "Email") Then
		Try
			Result = CommonUseClientServer.ParseStringWithPostalAddresses(EMail_Address.Value);
			If Result.Count() > 1 Then
				
				ErrorString = NStr("en = 'Entry of the single email address is permitted'");
				
			EndIf;
		Except
			ErrorString = BriefErrorDescription(ErrorInfo());
		EndTry;
	EndIf;
	
	If Not IsBlankString(ErrorString) Then
		OutputMessageToUser(ErrorString, AttributeName, AttributeField);
		ErrorsLevel = ?(InformationKind.ProhibitInvalidEntry, 2, 1);
	Else
		ErrorsLevel = 0;
	EndIf;
	
	Return ErrorsLevel;
	
EndFunction

// Checks web page contact information and informs about errors. Returns errors check box.
//
// Parameters:
//     Source      - XDTODataObject - contact information.
//     InformationKind - CatalogRef.ContactInformationTypes - contact information kind with checking settings.
//     AttributeName  - String - optional attribute name for binding error message.
//
// Returns:
//     Number - errors level: 0 - no, 1 - nonlocking, 2 - locking.
//
Function WebpageFillingErrors(Source, InformationKind, AttributeName = "")
	Return 0;
EndFunction

#EndRegion
