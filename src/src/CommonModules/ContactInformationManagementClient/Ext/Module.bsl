////////////////////////////////////////////////////////////////////////////////
// Contact information subsystem.
//
////////////////////////////////////////////////////////////////////////////////

#Region SubsystemsLibrary 

#Region Interface

// Handler of the OnChange event of a contact information form field.
// It is called from the attachable actions enabled while embedding the Contact information subsystem.
//
// Parameters:
//     Form             - ManagedForm - contact information owner form.
//     Item             - FormField   - form item containing contact information presentation.
//     IsTabularSection - Boolean     - flag specifying that the item is contained in a form table.
//
Procedure PresentationOnChange(Form, Item, IsTabularSection = False) Export
	
	IsTabularSection = IsTabularSection(Item);
	
	If IsTabularSection Then
		FillingData = Form.Items[Form.CurrentItem.Name].CurrentData;
		If FillingData = Undefined Then
			Return;
		EndIf;
	Else
		FillingData = Form;
	EndIf;
	
	// Clearing presentation if clearing is required
	RowData = GetAdditionalValueString(Form, Item, IsTabularSection);
	If RowData = Undefined Then 
		Return;
	EndIf;
	
	Text = Item.EditText;
	If IsBlankString(Text) Then
		FillingData[Item.Name] = "";
		If IsTabularSection Then
			FillingData[Item.Name + "FieldValues"] = "";
		EndIf;
		RowData.Presentation = "";
		RowData.FieldValues = Undefined;
		Return;
	EndIf;
	
	RowData.FieldValues = ContactInformationInternalServerCall.ContactInformationParsingXML(Text, RowData.Kind);
	RowData.Presentation = Text;
	
	If IsTabularSection Then
		FillingData[Item.Name + "FieldValues"] = RowData.FieldValues;
	EndIf;
	
EndProcedure

// Handler of the StartChoice event of a contact information form field.
// It is called from the attachable actions enabled while embedding the Contact information subsystem.
//
// Parameters:
//     Form               - ManagedForm - contact information owner form.
//     Item               - FormField   - form item containing contact information presentation.
//     Modified           - Boolean     - flag specifying that the form was modified.
//     StandardProcessing - Boolean     - flag specifying that standard processing is required for form event.
//
// Returns:
//     Undefined.
//
Function PresentationStartChoice(Form, Item, Modified = True, StandardProcessing = False) Export
	StandardProcessing = False;
	
	Result = New Structure;
	Result.Insert("AttributeName", Item.Name);
	
	IsTabularSection = IsTabularSection(Item);
	
	If IsTabularSection Then
		FillingData = Form.Items[Form.CurrentItem.Name].CurrentData;
		If FillingData = Undefined Then
			Return Undefined;
		EndIf;
	Else
		FillingData = Form;
	EndIf;
	
	RowData = GetAdditionalValueString(Form, Item, IsTabularSection);
	
	// Setting presentation equal to the attribute if the presentation was modified directly in the form field and no
	// longer matches the attribute
	If FillingData[Item.Name] <> Item.EditText Then
		FillingData[Item.Name] = Item.EditText;
		PresentationOnChange(Form, Item, IsTabularSection);
		Form.Modified = True;
	EndIf;
	
	OpenParameters = New Structure;
	OpenParameters.Insert("ContactInformationKind", RowData.Kind);
	OpenParameters.Insert("FieldValues", RowData.FieldValues);
	OpenParameters.Insert("Presentation", Item.EditText);
	
	If Not IsTabularSection Then
		OpenParameters.Insert("Comment", RowData.Comment);
	EndIf;
	
	Notification = New NotifyDescription("PresentationStartChoiceCompletion", ThisObject, New Structure);
	Notification.AdditionalParameters.Insert("FillingData",  FillingData);
	Notification.AdditionalParameters.Insert("IsTabularSection", IsTabularSection);
	Notification.AdditionalParameters.Insert("RowData",      RowData);
	Notification.AdditionalParameters.Insert("Item",           Item);
	Notification.AdditionalParameters.Insert("Result",         Result);
	Notification.AdditionalParameters.Insert("Form",             Form);
	
	OpenContactInformationForm(OpenParameters, , , , Notification);
	
	Return Undefined;
EndFunction

// Handler of the Clearing event for a contact information form field.
// It is called from the attachable actions enabled while embedding the Contact information subsystem.
//
// Parameters:
//     Form          - ManagedForm - contact information owner form.
//     AttributeName - String      - name of form attribute used for contact information presentation.
//
// Returns:
//     Undefined.
//
Function PresentationClearing(Val Form, Val AttributeName) Export
	
	Result = New Structure("AttributeName", AttributeName);
	FoundRow = Form.ContactInformationAdditionalAttributeInfo.FindRows(Result)[0];
	FoundRow.FieldValues = "";
	FoundRow.Presentation = "";
	FoundRow.Comment   = "";
	
	Form[AttributeName] = "";
	Form.Modified = True;
	
	UpdateFormContactInformation(Form, Result);
	Return Undefined;
EndFunction

// Handler of contact information-related commands (create an email message, open an address, and so on).
// It is called from the attachable actions enabled while embedding the Contact information subsystem.
//
// Parameters:
//     Form        - ManagedForm - contact information owner form.
//     CommandName - String      - name of automatically generated action command.
//
// Returns:
//     Undefined.
//
Function AttachableCommand(Val Form, Val CommandName) Export
	
	If CommandName = "ContactInformationAddInputField" Then
		Notification = New NotifyDescription("ContactInformationAddInputFieldCompletion", ThisObject, New Structure);
			
		Notification.AdditionalParameters.Insert("Form", Form);
		Form.ShowChooseFromMenu(Notification, Form.AddedContactInformationItemList, Form.Items.ContactInformationAddInputField);
		Return Undefined;
		
	ElsIf Left(CommandName, 7) = "Command" Then
		AttributeName = StrReplace(CommandName, "Command", "");
		ContextMenuCommand = False;
		
	Else
		AttributeName = StrReplace(CommandName, "ContextMenu", "");
		ContextMenuCommand = True;
		
	EndIf;
	
	Result = New Structure("AttributeName", AttributeName);
	FoundRow = Form.ContactInformationAdditionalAttributeInfo.FindRows(Result)[0];
	ContactInformationType = FoundRow.Type;
	
	If ContextMenuCommand Then
		EnterComment(Form, AttributeName, FoundRow, Result);
		
	ElsIf ContactInformationType = PredefinedValue("Enum.ContactInformationTypes.EmailAddress") Then
		EmailAddress = Form.Items[AttributeName].EditText;
		CreateEmailMessage("", EmailAddress, ContactInformationType);
		
	ElsIf ContactInformationType = PredefinedValue("Enum.ContactInformationTypes.WebPage") Then
		ReferenceAddress = Form.Items[AttributeName].EditText;
		GoToWebLink("", ReferenceAddress, ContactInformationType);
		
	EndIf;
	
	Return Undefined;
EndFunction

// Opens the address input form for the contact information form.
// It is called from the attachable actions enabled while embedding the Contact information subsystem.
//
// Parameters:
//     Form   - ManagedForm - contact information owner form.
//     Result - Arbitrary   - data passed by command handler.
//
Procedure OpenAddressInputForm(Form, Result) Export
	
	If Result <> Undefined Then
		
		If Result.Property("AddressFormItem") Then
			PresentationStartChoice(Form, Form.Items[Result.AddressFormItem]);
		EndIf;
		
	EndIf;
	
EndProcedure

// Handler of the refresh operation for the contact information form.
// It is called from the attachable actions enabled while embedding the Contact information subsystem.
//
// Parameters:
//     Form   - ManagedForm - contact information owner form.
//     Result - Arbitrary   - data passed by command handler.
//
Procedure FormRefreshControl(Form, Result) Export
	
	// Address input form callback analysis
	OpenAddressInputForm(Form, Result);
	
EndProcedure

// Handler of the ChoiceProcessing event for Countries. 
// Implements functionality for automated creation of Countries catalog item based on user choice.
//
// Parameters:
//     Item               - FormField - item containing the Country to be edited.
//     SelectedValue      - Arbitrary - selected value.
//     StandardProcessing - Boolean   - flag specifying that standard processing is required for the form event.
//
Procedure CountryChoiceProcessing(Item, SelectedValue, StandardProcessing) Export
	If Not StandardProcessing Then 
		Return;
	EndIf;
	
	SelectedValueType = TypeOf(SelectedValue);
	If SelectedValueType = Type("Array") Then
		TransformationList = New Map;
		For Index = 0 To SelectedValue.UBound() Do
			Data = SelectedValue[Index];
			If TypeOf(Data) = Type("Structure") AND Data.Property("Code") Then
				TransformationList.Insert(Index, Data.Code);
			EndIf;
		EndDo;
		
		If TransformationList.Count() > 0 Then
			ContactInformationInternalServerCall.CountryCollectionByClassifier(TransformationList);
			For Each KeyValue In TransformationList Do
				SelectedValue[KeyValue.Key] = KeyValue.Value;
			EndDo;
		EndIf;
		
	ElsIf SelectedValueType = Type("Structure") AND SelectedValue.Property("Code") Then
		SelectedValue = ContactInformationInternalServerCall.CountriesByClassifier(SelectedValue.Code);
		
	EndIf;
	
EndProcedure

// Constructor used to create a structure with contact information form opening parameters.
//
//  Parameters:
//      ContactInformationKind - CatalogRef.ContactInformationTypes - contact information kind to be edited.
//      Value                  - String - serialized value of contact information fields.
//      Presentation           - String - presentation (optional).
//
Function ContactInformationFormParameters(ContactInformationKind, Value, Presentation = Undefined, Comment = Undefined) Export
	Return New Structure("ContactInformationKind, FieldValues, Presentation, Comment",
		ContactInformationKind, Value, Presentation, Comment);
EndFunction

// Opens a contact information form for editing or viewing.
//
//  Parameters:
//      Parameters   - Arbitrary         - result of ContactInformationFormParameters function.
//      Owner        - Arbitrary         - form parameter.
//      Uniqueness   - Arbitrary         - form parameter.
//      Window       - Arbitrary         - form parameter.
//      Notification - NotifyDescription - used to process form closing.
//
//  Returns: the requested contact information form.
//
Function OpenContactInformationForm(Parameters, Owner = Undefined, Uniqueness = Undefined, Window = Undefined, Notification = Undefined) Export
	
	InformationKind = Parameters.ContactInformationKind;
	
	NameOfFormToOpen = ContactInformationClientServerCached.ContactInformationInputFormName(InformationKind);
	If NameOfFormToOpen = Undefined Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Address type can not be processed: ""%1""'"),
			InformationKind);
	EndIf;
	
	If Not Parameters.Property("Title") Then
		Parameters.Insert("Title", String(ContactInformationInternalServerCall.ContactInformationKindType(InformationKind)));
	EndIf;
	
	Parameters.Insert("OpenByScenario", True);
	
	Return OpenForm(NameOfFormToOpen, Parameters, Owner, Uniqueness, Window, , Notification);
	
EndFunction

// Creates a contact information email.
//
//  Parameters:
//    FieldValues  - String, Structure, Map, Value list - contact information.
//    Presentation - String - presentation. Used if unable to extract presentation 
//                   from FieldValues parameter (Presentation field not available).
//    ExpectedKind - CatalogRef.ContactInformationTypes, EnumRef.ContactInformationTypes, Structure.
//                   Used to determine type if it cannot be extracted from FieldValues parameter.
//
Procedure CreateEmailMessage(Val FieldValues, Val Presentation = "", ExpectedKind = Undefined) Export
	
	ContactInformation = ContactInformationInternalServerCall.TransformContactInformationXML(
		New Structure("FieldValues, Presentation, ContactInformationKind", FieldValues, Presentation, ExpectedKind));
	InformationType = ContactInformation.ContactInformationType;
	
	If InformationType <> PredefinedValue("Enum.ContactInformationTypes.EmailAddress") Then
		Raise StrReplace(NStr("en = 'Cannot create email by contact information with type ""%1""'"),
			"%1", InformationType);
	EndIf;	
	
	XMLData = ContactInformation.XMLData;
	
	EmailAddress = ContactInformationInternalServerCall.ContactInformationContentString(XMLData);
	If TypeOf(EmailAddress) <> Type("String") Then
		Raise NStr("en = 'An error occurred when receiving the email address, incorrect contact information type'");
	EndIf;
	
	If CommonUseClient.SubsystemExists("StandardSubsystems.EmailOperations") Then
		EmailOperationsModuleClient = CommonUseClient.CommonModule("EmailOperationsClient");
		
		SendingParameters = New Structure("Recipient", EmailAddress);
		EmailOperationsModuleClient.CreateNewEmailMessage(SendingParameters);
		Return; 
	EndIf;
	
	// No email subsystem, using the platform notification
	Notification = New NotifyDescription("CreateContactInformationEmailCompletion", ThisObject, EmailAddress);
	SuggestionText = NStr("en = 'To send the email, install the file operation extension.'");
	CommonUseClient.CheckFileOperationsExtensionConnected(Notification, SuggestionText);
EndProcedure

// Opens a contact information reference.
//
// Parameters:
//    FieldValues  - String, Structure, Map, Value list - contact information.
//    Presentation - String - presentation. Used if unable to extract presentation 
//                   from FieldValues parameter (Presentation field not available).
//    ExpectedKind - CatalogRef.ContactInformationTypes, EnumRef.ContactInformationTypes, Structure.
//                   Used to determine type if it cannot be extracted from FieldValues parameter.
//
Procedure GoToWebLink(Val FieldValues, Val Presentation = "", ExpectedKind = Undefined) Export
	
	ContactInformation = ContactInformationInternalServerCall.TransformContactInformationXML(
		New Structure("FieldValues, Presentation, ContactInformationKind", FieldValues, Presentation, ExpectedKind));
	InformationType = ContactInformation.ContactInformationType;
	
	If InformationType <> PredefinedValue("Enum.ContactInformationTypes.WebPage") Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(NStr("en = 'Cannot open a contact information reference for ""%1"" type'"), InformationType);
	EndIf;
		
	XMLData = ContactInformation.XMLData;

	ReferenceAddress = ContactInformationInternalServerCall.ContactInformationContentString(XMLData);
	If TypeOf(ReferenceAddress) <> Type("String") Then
		Raise NStr("en = 'An error occurred when receiving the reference, incorrect contact information type'");
	EndIf;
	
	If Find(ReferenceAddress, "://") > 0 Then
		GoToWebLink(ReferenceAddress);
	Else
		GoToWebLink("http://" + ReferenceAddress);
	EndIf;
EndProcedure

#EndRegion

#Region InternalInterface

// Nonmodal dialog completion
Procedure PresentationStartChoiceCompletion(Val CloseResult, Val AdditionalParameters) Export
	If TypeOf(CloseResult) <> Type("Structure") Then
		Return;
	EndIf;
	
	FillingData = AdditionalParameters.FillingData;
	RowData     = AdditionalParameters.RowData;
	Result        = AdditionalParameters.Result;
	Item          = AdditionalParameters.Item;
	Form            = AdditionalParameters.Form;
	
	PresentationText = CloseResult.Presentation;
	
	If AdditionalParameters.IsTabularSection Then
		FillingData[Item.Name + "FieldValues"] = CloseResult.ContactInformation;
		
	Else
		If IsBlankString(RowData.Comment) AND Not IsBlankString(CloseResult.Comment) Then
			Result.Insert("IsCommentAddition", True);
			
		ElsIf Not IsBlankString(RowData.Comment) AND IsBlankString(CloseResult.Comment) Then
			Result.Insert("IsCommentAddition", False);
			
		Else
			If Not IsBlankString(RowData.Comment) Then
				Form.Items["Comment" + Item.Name].Title = CloseResult.Comment;
			EndIf;
			
		EndIf;
		
		RowData.Presentation = PresentationText;
		RowData.FieldValues = CloseResult.ContactInformation;
		RowData.Comment   = CloseResult.Comment;
	EndIf;
	
	FillingData[Item.Name] = PresentationText;
	
	Form.Modified = True;
	UpdateFormContactInformation(Form, Result);
EndProcedure

// Nonmodal dialog completion
Procedure ContactInformationAddInputFieldCompletion(Val SelectedItem, Val AdditionalParameters) Export
	If SelectedItem = Undefined Then
		// Canceling selection
		Return;
	EndIf;
	
	Result = New Structure("AddedKind", SelectedItem.Value);
	
	UpdateFormContactInformation(AdditionalParameters.Form, Result);
EndProcedure

//  Returns the full name of a settlement. 
//  Settlement is a synthetic field storing any address unit greater than street.
//
//  Parameters:
//      AddressParts - Arbitrary - values of address parts, may vary depending on the classifier.
//
Function SettlementNameByAddressParts(AddressParts) Export
	// Address classifier is not available
	Return "";
EndFunction

// Completes the modal dialog for email creation.
Procedure CreateContactInformationEmailCompletion(Action, EmailAddress) Export
	
	RunApp("mailto:" + EmailAddress);
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

// Returns a string of additional values by attribute name.
//
// Parameters:
//    Form - ManagedForm                    - passed form.
//    Item - FormDataStructureAndCollection - form data.
//
// Returns:
//    CollectionRow - data found.
//    Undefined     - if no data is available.
//
Function GetAdditionalValueString(Form, Item, IsTabularSection = False)
	
	Filter = New Structure("AttributeName", Item.Name);
	Rows = Form.ContactInformationAdditionalAttributeInfo.FindRows(Filter);
	RowData = ?(Rows.Count() = 0, Undefined, Rows[0]);
	
	If IsTabularSection AND RowData <> Undefined Then
		
		PathToString = Form.Items[Form.CurrentItem.Name].CurrentData;
		
		RowData.Presentation = PathToString[Item.Name];
		RowData.FieldValues = PathToString[Item.Name + "FieldValues"];
		
	EndIf;
	
	Return RowData;
	
EndFunction

// Generates a string presentation of a phone number.
//
// Parameters:
//    CountryCode - String - country code.
//    AreaCode    - String - area code.
//    PhoneNumber - String - phone number.
//    Extension   - String - extension.
//    Comment     - String - comment.
//
// Returns:
//    String - phone number presentation.
//
Function GeneratePhonePresentation(CountryCode, AreaCode, PhoneNumber, Extension, Comment) Export
	
	Presentation = ContactInformationManagementClientServer.GeneratePhonePresentation(
	CountryCode, AreaCode, PhoneNumber, Extension, Comment);
	
	Return Presentation;
	
EndFunction

// Processes entering a comment using the context menu.
Procedure EnterComment(Val Form, Val AttributeName, Val FoundRow, Val Result)
	Comment = FoundRow.Comment;
	
	Notification = New NotifyDescription("EnterCommentCompletion", ThisObject, New Structure);
	Notification.AdditionalParameters.Insert("Form", Form);
	Notification.AdditionalParameters.Insert("CommentAttributeName", "Comment" + AttributeName);
	Notification.AdditionalParameters.Insert("FoundRow", FoundRow);
	Notification.AdditionalParameters.Insert("PreviousComment", Comment);
	Notification.AdditionalParameters.Insert("Result", Result);
	
	CommonUseClient.ShowMultilineTextEditForm(Notification, Comment, 
		NStr("en = 'Comment'"));
EndProcedure

// Completes a nonmodal dialog.
Procedure EnterCommentCompletion(Val Comment, Val AdditionalParameters) Export
	If Comment = Undefined Or Comment = AdditionalParameters.PreviousComment Then
		// Input canceled, or no changes
		Return;
	EndIf;
	
	CommentWasEmpty  = IsBlankString(AdditionalParameters.PreviousComment);
	CommentBecameEmpty = IsBlankString(Comment);
	
	AdditionalParameters.FoundRow.Comment = Comment;
	
	If CommentWasEmpty AND Not CommentBecameEmpty Then
		AdditionalParameters.Result.Insert("IsCommentAddition", True);
	ElsIf Not CommentWasEmpty AND CommentBecameEmpty Then
		AdditionalParameters.Result.Insert("IsCommentAddition", False);
	Else
		Item = AdditionalParameters.Form.Items[AdditionalParameters.CommentAttributeName];
		Item.Title = Comment;
	EndIf;
	
	AdditionalParameters.Form.Modified = True;
	UpdateFormContactInformation(AdditionalParameters.Form, AdditionalParameters.Result)
EndProcedure

// Context call.
Procedure UpdateFormContactInformation(Form, Result)

	Form.RefreshContactInformation(Result);
	
EndProcedure

Function IsTabularSection(Item)
	
	Parent = Item.Parent;
	
	While TypeOf(Parent) <> Type("ManagedForm") Do
		
		If TypeOf(Parent) = Type("FormTable") Then
			Return True;
		EndIf;
		
		Parent = Parent.Parent;
		
	EndDo;
	
	Return False;
	
EndFunction

#EndRegion

#EndRegion

#Region Drive
	
#Region HandlersOfTheConditionalCallsIntoOtherSubsystems

Procedure CreateEmailByContactInformationAfterLaunchApplications(ReturnCode, AdditionalParameters) Export
	// Action is not required
EndProcedure

Function URLEncode(String) 
	Result = "";
	CharSet = "0123456789ABCDEF";
	For CharNumber = 1 To StrLen(String) Do
		CharCode = CharCode(String, CharNumber);
		Char = Mid(String, CharNumber, 1);
		
		// skip A..Z, a..z, 0..9
		If Find("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789", Char) > 0 Then // chars -_.!~*\() encode as unsafe  
			Result = Result + Char;
			Continue;
		EndIf;
		
		If Char = " " Then
			Result = Result + "+";
			Continue;
		EndIf;
		
		If CharCode <= 127 Then // 0x007F
			Result = Result + BytePresentation(CharCode);
		ElsIf CharCode <= 2047 Then // 0x07FF 
			Result = Result 
					  + BytePresentation(
					  					   BinaryArrayToNumber(
																ArrayBitwiseOR(
																			 NumberToBinaryArray(192,8),
																			 NumberToBinaryArray(Int(CharCode / Pow(2,6)),8)))); // 0xc0 | (ch >> 6)
			Result = Result 
					  + BytePresentation(
					  					   BinaryArrayToNumber(
										   						ArrayBitwiseOR(
																			 NumberToBinaryArray(128,8),
																			 ArrayBitwiseAnd(
																			 			NumberToBinaryArray(CharCode,8),
																						NumberToBinaryArray(63,8)))));  //0x80 | (ch & 0x3F)
		Else  // 0x7FF < ch <= 0xFFFF
			Result = Result 
					  + BytePresentation	(
					  						 BinaryArrayToNumber(
																  ArrayBitwiseOR(
																			   NumberToBinaryArray(224,8), 
																			   NumberToBinaryArray(Int(CharCode / Pow(2,12)),8)))); // 0xe0 | (ch >> 12)
											
			Result = Result 
					  + BytePresentation(
					  					   BinaryArrayToNumber(
										   						ArrayBitwiseOR(
																			 NumberToBinaryArray(128,8),
																			 ArrayBitwiseAnd(
																			 			NumberToBinaryArray(Int(CharCode / Pow(2,6)),8),
																						NumberToBinaryArray(63,8)))));  //0x80 | ((ch >> 6) & 0x3F)
											
			Result = Result 
					  + BytePresentation(
					  					   BinaryArrayToNumber(
										   						ArrayBitwiseOR(
																			 NumberToBinaryArray(128,8),
																			 ArrayBitwiseAnd(
																			 			NumberToBinaryArray(CharCode,8),
																						NumberToBinaryArray(63,8)))));  //0x80 | (ch & 0x3F)
								
		EndIf;
	EndDo;
	Return Result;
EndFunction

Function BytePresentation(Val Byte)
	Result = "";
	CharString = "0123456789ABCDEF";
	For Counter = 1 To 2 Do
		Result = Mid(CharString, Byte % 16 + 1, 1) + Result;
		Byte = Int(Byte / 16);
	EndDo;
	Return "%" + Result;
EndFunction

Function NumberToBinaryArray(Val Number, Val AllRanks = 32)
	Result = New Array;
	CurrentRank = 0;
	While CurrentRank < AllRanks Do
		CurrentRank = CurrentRank + 1;
		Result.Add(Boolean(Number % 2));
		Number = Int(Number / 2);
	EndDo;
	Return Result;
EndFunction

Function BinaryArrayToNumber(Array)
	Result = 0;
	For RankNumber = -(Array.Count()-1) To 0 Do
		Result = Result * 2 + Number(Array[-RankNumber]);
	EndDo;
	Return Result;
EndFunction

Function ArrayBitwiseAnd(BinaryArray1, BinaryArray2)
	Result = New Array;
	For Index = 0 To BinaryArray1.Count()-1 Do
		Result.Add(BinaryArray1[Index] AND BinaryArray2[Index]);
	EndDo;	
	Return Result;
EndFunction

Function ArrayBitwiseOR(BinaryArray1, BinaryArray2)
	Result = New Array;
	For Index = 0 To BinaryArray1.Count()-1 Do
		Result.Add(BinaryArray1[Index] Or BinaryArray2[Index]);
	EndDo;	
	Return Result;
EndFunction

// It shows the address in the browser on maps Google.
//
// Parameters:
//  Address			 - String - Text of the address.
//  MapServiceName	 - String - Name mapping service in which you need to show address: GoogleMaps.
//
Procedure ShowAddressOnMap(Address, MapServiceName) Export
	
	AddressCoded = URLEncode(Address);
	
	LaunchString = "https://maps.google.ru/?q=" + AddressCoded;
	
	GotoURL(LaunchString);
	
EndProcedure

#Region ServiceInterface

Procedure AfterLaunchApplication(SelectedItem, Parameters) Export
	// Stub procedure, because for BeginRunningApplication requires a notification handler.
	SaveThisProcedure	= True;
EndProcedure

#EndRegion

#EndRegion

#Region ServiceProceduresAndFunctions

Procedure AfterSelectionFromMenuSkype(SelectedItem, Parameters) Export
	
	If SelectedItem = Undefined Then
		Return;
	EndIf;
	
	#If Not WebClient Then
		If IsBlankString(TelephonySoftwareIsInstalled("skype")) Then
			ShowMessageBox(Undefined, NStr("en = 'To make a call on Skype is required to install the program.'"));
			Return;
		EndIf;
	#EndIf
	
	LaunchString = "skype:" + Parameters.LoginSkype;
	If SelectedItem.Value = "Call" Then
		LaunchString = LaunchString + "?call";
	ElsIf SelectedItem.Value = "StartChat" Then
		LaunchString = LaunchString + "?chat";
	Else
		LaunchString = LaunchString + "?userinfo";
	EndIf;
	
	Notify = New NotifyDescription("LaunchSkype", ThisObject, LaunchString);
	MessageText = NStr("en = 'To start Skype, you must install the extension work with files.'");
	CommonUseClient.ShowFileSystemExtensionInstallationQuestion(Notify, MessageText);

EndProcedure

Procedure LaunchSkype(ExtensionAttached, LaunchString) Export
	
	If ExtensionAttached Then
		Notify = New NotifyDescription("AfterLaunchApplication", ThisObject);
		BeginRunningApplication(Notify, LaunchString);
	EndIf;
	
EndProcedure

// Check whether the telephony software is installed on your computer.
//  Checking is only possible in a thin client for Windows.
//
// Parameters:
//  ProtocolName - String - Name verifiable URI protocol, options "skype", "tel", "sip".
//                          If not specified, then checked all the protocols. 
// 
// Returned value:
//  String - the name of the available URI protocol is registered in the registry. An empty string - if the protocol is
//                                                                                                   not available.
//  Uncertain if the check is not possible.
//
Function TelephonySoftwareIsInstalled(ProtocolName = Undefined)
	
	If CommonUseClientServer.IsWindowsClient() Then
		If ValueIsFilled(ProtocolName) Then
			Return ?(ProtocolNameRegisteredInRegister(ProtocolName), ProtocolName, "");
		Else
			ProtocolList = New Array;
			ProtocolList.Add("tel");
			ProtocolList.Add("sip");
			ProtocolList.Add("skype");
			For Each ProtocolName In ProtocolList Do
				If ProtocolNameRegisteredInRegister(ProtocolName) Then
					Return ProtocolName;
				EndIf;
			EndDo;
			Return Undefined;
		EndIf;
	EndIf;
	
	Return "";
	
EndFunction

Function ProtocolNameRegisteredInRegister(ProtocolName)
	
	Try
		Shell = New COMObject("Wscript.Shell");
		Result = Shell.RegRead("HKEY_CLASSES_ROOT\" + ProtocolName + "\");
	Except
		Return False;
	EndTry;
	Return True;
	
EndFunction

#EndRegion

#EndRegion
