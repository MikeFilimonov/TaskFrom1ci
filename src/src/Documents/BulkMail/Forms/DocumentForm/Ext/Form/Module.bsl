﻿
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	TypeArray = New Array;
	TypeArray.Add(Type("String"));
	Items.ContactRecipients.TypeRestriction = New TypeDescription(TypeArray, New StringQualifiers(100));
	Items.Subject.TypeRestriction 			   = New TypeDescription(TypeArray, New StringQualifiers(100));
	
	SMSProvider = Constants.SMSProvider.Get();
	SMSSettingsComplete = SendingSMS.SMSSendSettingFinished();
	AvailableRightSettingsSMS = Users.InfobaseUserWithFullAccess();
	
	If Parameters.Key.IsEmpty() Then
		FillNewEmailDefault();
	EndIf;
	
	DriveClientServer.SetPictureForComment(Items.GroupAdditional, Object.Comment);
	
	FormManagement(ThisForm);
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	If CurrentObject.SendingMethod = Enums.MessageType.Email Then
		
		Images = CurrentObject.ImagesHTML.Get();
		If Images = Undefined Then
			Images = New Structure;
		EndIf;
		FormattedDocument.SetHTML(CurrentObject.ContentHTML, Images);
		
		Attachments.Clear();
		
		Query = New Query;
		Query.Text =
			"SELECT
			|	BulkMailAttachedFiles.Ref,
			|	BulkMailAttachedFiles.Description,
			|	BulkMailAttachedFiles.Extension,
			|	BulkMailAttachedFiles.PictureIndex
			|FROM
			|	Catalog.BulkMailAttachedFiles AS BulkMailAttachedFiles
			|WHERE
			|	BulkMailAttachedFiles.FileOwner = &FileOwner
			|	AND BulkMailAttachedFiles.DeletionMark = FALSE";
		
		Query.SetParameter("FileOwner", CurrentObject.Ref);
		
		Selection = Query.Execute().Select();
		
		While Selection.Next() Do
			
			NewRow = Attachments.Add();
			NewRow.Ref                    = Selection.Ref;
			NewRow.Presentation             = Selection.Description + ?(IsBlankString(Selection.Extension), "", "." + Selection.Extension);
			NewRow.PictureIndex            = Selection.PictureIndex;
			NewRow.AddressInTemporaryStorage = PutToTempStorage(AttachedFiles.GetFileBinaryData(Selection.Ref), UUID);
			
		EndDo;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	If CurrentObject.SendingMethod = Enums.MessageType.Email Then
		
		HTMLText = "";
		Images = New Structure;
		FormattedDocument.GetHTML(HTMLText, Images);
		
		CurrentObject.ContentHTML = HTMLText;
		CurrentObject.ImagesHTML = New ValueStorage(Images);
		CurrentObject.Content = FormattedDocument.GetText();
		
	Else
		
		CheckAndConvertRecipientNumbers(CurrentObject, Cancel);
		CurrentObject.ContentHTML = "";
		CurrentObject.ImagesHTML = Undefined;
		Attachments.Clear();
		
	EndIf;
	
EndProcedure

&AtServer
Procedure OnWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	SaveAttachments(CurrentObject.Ref);
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	If Object.SendingMethod = Enums.MessageType.Email Then
		CheckEmailAddressCorrectness(Cancel);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormAttributesEventsHandlers

&AtClient
Procedure SendingMethodOnChange(Item)
	
	FormManagement(ThisForm);
	
EndProcedure

&AtClient
Procedure SubjectStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	FormParameters = New Structure;
	If TypeOf(Object.Subject) = Type("CatalogRef.EventsSubjects") AND ValueIsFilled(Object.Subject) Then
		FormParameters.Insert("CurrentRow", Object.Subject);
	EndIf;
	
	OpenForm("Catalog.EventsSubjects.ChoiceForm", FormParameters, Item);
	
EndProcedure

&AtClient
Procedure SubjectChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	StandardProcessing = False;
	Modified = True;
	
	If ValueIsFilled(ValueSelected) Then
		Object.Subject = ValueSelected;
		FillContentEvents(ValueSelected);
	EndIf;
	
EndProcedure

&AtClient
Procedure SubjectAutoSelection(Item, Text, ChoiceData, Parameters, Wait, StandardProcessing)
	
	If Wait <> 0 AND Not IsBlankString(Text) Then
		
		StandardProcessing = False;
		ChoiceData = GetSubjectChoiceList(Text);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure RecipientsContactStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	FormParameters = New Structure;
	FormParameters.Insert("CIType", "EmailAddress");
	If ValueIsFilled(Items.Recipients.CurrentData.Contact) Then
		Contact = Object.Recipients.FindByID(Items.Recipients.CurrentRow).Contact;
		If TypeOf(Contact) = Type("CatalogRef.Counterparties") Then
			FormParameters.Insert("CurrentCounterparty", Contact);
		EndIf;
	EndIf;
	NotifyDescription = New NotifyDescription("RecipientsContactSelectionEnd", ThisForm);
	OpenForm("CommonForm.AddressBook", FormParameters, ThisForm, , , , NotifyDescription, FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtClient
Procedure ContactRecipientsOpen(Item, StandardProcessing)
	
	StandardProcessing = False;
	If ValueIsFilled(Items.Recipients.CurrentData.Contact) Then
		Contact = Object.Recipients.FindByID(Items.Recipients.CurrentRow).Contact;
		ShowValue(,Contact);
	EndIf;
	
EndProcedure

&AtClient
Procedure RecipientsContactChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	StandardProcessing = False;
	Modified = True;
	
	If TypeOf(ValueSelected) = Type("CatalogRef.Counterparties") Or TypeOf(ValueSelected) = Type("CatalogRef.ContactPersons") Then
	// Selection is implemented by automatic selection mechanism
		
		Object.Recipients.FindByID(Items.Recipients.CurrentRow).Contact = ValueSelected;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ContactRecipientsAutoPick(Item, Text, ChoiceData, Parameters, Wait, StandardProcessing)
	
	If Wait <> 0 AND Not IsBlankString(Text) Then
		StandardProcessing = False;
		ChoiceData = GetContactChoiceList(Text);
	EndIf;
	
EndProcedure

&AtClient
Procedure CommentOnChange(Item)
	
	AttachIdleHandler("Attachable_SetPictureForComment", 0.5, True);
	
EndProcedure

// Procedure - event handler Attribute selection Attachments.
//
&AtClient
Procedure AttachmentsSelection(Item, SelectedRow, Field, StandardProcessing)
	
	OpenAttachment();
	
EndProcedure

// Procedure - event handler BeforeAddStart of attribute Attachments.
//
&AtClient
Procedure AttachmentsBeforeAdd(Item, Cancel, Copy, Parent, Group, Parameter)
	
	Cancel = True;
	AddFileToAttachments();
	
EndProcedure

// Procedure - event handler CheckDragAndDrop of attribute Attachments.
//
&AtClient
Procedure AttachmentsDragCheck(Item, DragParameters, StandardProcessing, String, Field)
	
	StandardProcessing = False;
	
EndProcedure

// Procedure - DragAndDrop event handler of the Attachments attribute.
//
&AtClient
Procedure AttachmentsDrag(Item, DragParameters, StandardProcessing, String, Field)
	
	StandardProcessing = False;
	
	If TypeOf(DragParameters.Value) = Type("File") Then
		NotifyDescription = New NotifyDescription("AttachmentsDragAndDropEnd", ThisObject, New Structure("Name", DragParameters.Value.Name));
		BeginPutFile(NotifyDescription, , DragParameters.Value.DescriptionFull, False);
		Modified = True;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure SendMailing(Command)
	
	If Write() Then
		
		If Object.SendingMethod = PredefinedValue("Enum.MessageType.Email") Then
			SuccessfullySent = SendEmailMailing();
		Else
			If SMSSettingsComplete Then
				SuccessfullySent = SendSMSMailing();
			ElsIf AvailableRightSettingsSMS Then
				MessageText = NStr("en = 'To send SMS, it is necessary to configure sending parameters.
				                   |You can adjust the settings in the Settings - Personal organizer - SMS sending section.'");
				ShowMessageBox(, MessageText);
				Return;
			Else
				MessageText = NStr("en = 'To send SMS, it is necessary to configure sending parameters.
				                   |Address to the administrator to perform settings.'");
				ShowMessageBox(, MessageText);
				Return;
			EndIf;
		EndIf;
		
		NotificationText = StringFunctionsClientServer.SubstituteParametersInString(NStr("en = 'Successfully sent: %1 messages'"), SuccessfullySent);
		ShowUserNotification(NotificationText, GetURL(Object.Ref), String(Object.Ref), PictureLib.Information32);
		If SuccessfullySent = Object.Recipients.Count() Then
			Object.State = PredefinedValue("Enum.MailStatus.Sent");
			Object.DateMailings = CurrentDate();
			Write();
			Close(SuccessfullySent);
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure FillContentBySubject(Command)
	
	If ValueIsFilled(Object.Subject) Then
		FillContentEvents(Object.Subject);
	EndIf;
	
EndProcedure

// Procedure - command handler OpenFile.
//
&AtClient
Procedure OpenFile(Command)
	
	OpenAttachment();
	
EndProcedure

&AtClient
Procedure PickContacts(Command)
	
	FormParameters = New Structure;
	If Object.SendingMethod = PredefinedValue("Enum.MessageType.Email") Then
		FormParameters.Insert("CIType", "EmailAddress");
	Else
		FormParameters.Insert("CIType", "Phone");
	EndIf;
	NotifyDescription = New NotifyDescription("ContactPickEnd", ThisForm);
	OpenForm("CommonForm.AddressBook", FormParameters, ThisForm, , , , NotifyDescription, FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtClient
Procedure DeleteBlank(Command)
	
	DeletedRecipients = New Array;
	
	For Each RecipientRow In Object.Recipients Do
		If IsBlankString(RecipientRow.HowToContact) Then
			DeletedRecipients.Add(RecipientRow);
		EndIf;
	EndDo;
	
	For Each DeletedRecipient In DeletedRecipients Do
		Object.Recipients.Delete(DeletedRecipient);
	EndDo;
	
EndProcedure

&AtClient
Procedure RefreshDeliveryStatuses(Command)
	
	UpdateDeliveryStatusesAtServer();
	
EndProcedure

&AtClient
Procedure ParameterTime(Command)
	
	InsertParameter("{Time}");
	
EndProcedure

&AtClient
Procedure ParameterDate(Command)
	
	InsertParameter("{Date}");
	
EndProcedure

&AtClient
Procedure ParameterRecipientNameNominativeCase(Command)
	
	InsertParameter("{Recipient name (nominative)}");
	
EndProcedure

&AtClient
Procedure ParameterRecipientNameGenitiveCase(Command)
	
	InsertParameter("{Recipient name (genitive)}");
	
EndProcedure

&AtClient
Procedure ParameterRecipientNameDativeCase(Command)
	
	InsertParameter("{Recipient name (dative)}");
	
EndProcedure

&AtClient
Procedure ParameterRecipientNameAccusativeCase(Command)
	
	InsertParameter("{Recipient name (accusative)}");
	
EndProcedure

&AtClient
Procedure ParameterRecipientNameAblativeCase(Command)
	
	InsertParameter("{Recipient name (instrumental)}");
	
EndProcedure

&AtClient
Procedure ParameterRecipientNamePrepositionalCase(Command)
	
	InsertParameter("{Recipient name (prepositional)}");
	
EndProcedure

#EndRegion

#Region CommonUseProceduresAndFunctions

&AtServer
Procedure CheckAndConvertRecipientNumbers(CurrentObject, Cancel)
	
	For Each Recipient In CurrentObject.Recipients Do
		
		If IsBlankString(Recipient.HowToContact) Then
			CommonUseClientServer.MessageToUser(
				NStr("en = 'Phone number is not populated.'"),
				,
				CommonUseClientServer.PathToTabularSection("Object.Recipients", Recipient.LineNumber, "HowToContact"),
				,
				Cancel);
			Continue;
		EndIf;
		
		If StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(Recipient.HowToContact, ";", True).Count() > 1 Then
			CommonUseClientServer.MessageToUser(
				NStr("en = 'Only one phone number should be specified.'"),
				,
				CommonUseClientServer.PathToTabularSection("Object.Recipients", Recipient.LineNumber, "HowToContact"),
				,
				Cancel);
			Continue;
		EndIf;
		
		Recipient.NumberForSending = DriveClientServer.ConvertNumberForSMSSending(Recipient.HowToContact);
			
	EndDo;
	
EndProcedure

&AtServer
Procedure CheckEmailAddressCorrectness(Cancel)
	
	For Each RecipientRow In Object.Recipients Do
		
		Try
			CommonUseClientServer.ParseStringWithPostalAddresses(RecipientRow.HowToContact);
		Except
			ErrorText = StringFunctionsClientServer.SubstituteParametersInString(NStr("en = 'Recipient email is specified incorrectly: %1, due to: %2'"),
				RecipientRow.Contact,
				BriefErrorDescription(ErrorInfo()),
				);
			CommonUseClientServer.MessageToUser(ErrorText, ,
				CommonUseClientServer.PathToTabularSection("Recipients", RecipientRow.LineNumber, "HowToContact"), "Object", Cancel);
		EndTry;
		
	EndDo;
	
EndProcedure

&AtClientAtServerNoContext
Procedure FormManagement(Form)
	
	Items = Form.Items;
	Object = Form.Object;
	
	If Object.SendingMethod = PredefinedValue("Enum.MessageType.Email") Then
		Items.ContentKind.CurrentPage = Items.ForEmail;
		Items.FormSendMessaging.Picture = PictureLib.SendByEmail;
		Items.FormattedDocumentStandardCommands.Visible	= True;
		Items.UserAccount.Visible								= True;
		Items.GroupInformationSMS.Visible							= False;
		Items.AttachmentsGroup.Visible								= True;
		Items.RecipientsRefreshDeliveryStatuses.Visible			= False;
		Items.RecipientsDeliveryStatus.Visible						= False;
	Else
		Items.ContentKind.CurrentPage = Items.ForSMS;
		Items.FormSendMessaging.Picture = PictureLib.SendingSMS;
		Items.FormattedDocumentStandardCommands.Visible	= False;
		Items.UserAccount.Visible								= False;
		Items.GroupInformationSMS.Visible							= True;
		Items.AttachmentsGroup.Visible								= False;
		Items.RecipientsRefreshDeliveryStatuses.Visible			= True;
		Items.RecipientsDeliveryStatus.Visible						= True;
	EndIf;
	
	Items.SMSProvider.Visible = ValueIsFilled(Form.SMSProvider);
	
EndProcedure

// Procedure fills attribute values of new letters default.
//
&AtServer
Procedure FillNewEmailDefault()
	
	Object.Author = Users.AuthorizedUser();
	Object.Responsible = Drivereuse.GetValueByDefaultUser(Object.Author, "MainResponsible");
	Object.UserAccount = Drivereuse.GetValueByDefaultUser(Object.Author, "DefaultEmailAccount");
	Object.SMSSenderName = CommonUse.CommonSettingsStorageImport("SMSSettings", "SMSSenderName", "");
	
	AddSignatureForNewMessages = CommonUse.CommonSettingsStorageImport("EmailSettings", "AddSignatureForNewMessages", False);
	If AddSignatureForNewMessages Then
		HTMLSignature = CommonUse.CommonSettingsStorageImport("EmailSettings", "HTMLSignature", "");
		FormattedDocument.SetHTML(HTMLSignature, New Structure);
	EndIf;
	
EndProcedure

&AtServer
Function SendEmailMailing()
	
	SuccessfullySent = 0;
	SetPrivilegedMode(True);
	
	For Each RecipientRow In Object.Recipients Do
		
		EmailBody = "";
		AttachmentsImages = New Structure;
		FormattedDocument.GetHTML(EmailBody, AttachmentsImages);
		
		SetMessageParameters(EmailBody, RecipientRow.Contact);
		EmailParameters = GenerateEmailParameters(RecipientRow.Contact, RecipientRow.HowToContact, EmailBody, AttachmentsImages);
		
		Try
			EmailOperations.SendE_Mail(Object.UserAccount, EmailParameters);
			Successfully = True;
			SuccessfullySent = SuccessfullySent + 1;
		Except
			ErrorText = StringFunctionsClientServer.SubstituteParametersInString(NStr("en = 'Cannot send Email to recipient: %1, due to: %2'"),
				RecipientRow.Contact,
				BriefErrorDescription(ErrorInfo()),
				);
			CommonUseClientServer.MessageToUser(ErrorText, , , CommonUseClientServer.PathToTabularSection("Recipients", RecipientRow.LineNumber, "Contact"));
			Successfully = False;
		EndTry;
		
		If Successfully AND Object.CreateEvents Then
		
			Event = Documents.Event.CreateDocument();
			Event.Date = CurrentDate();
			Event.EventBegin = Event.Date;
			Event.EventEnding = Event.Date;
			Event.SetNewNumber();
			Event.EventType = Enums.EventTypes.Email;
			
			Event.ContentHTML = EmailBody;
			Event.ImagesHTML = New ValueStorage(AttachmentsImages);
			Event.Content = DriveInteractions.GetTextFromHTML(Event.ContentHTML);
			
			BasisRow = Event.BasisDocuments.Add();
			BasisRow.BasisDocument = Object.Ref;
			
			Event.UserAccount = Object.UserAccount;
			Event.State = Catalogs.JobAndEventStatuses.Completed;
			Event.Subject = Object.Subject;
			Event.Responsible = Object.Responsible;
			Event.Author = Object.Author;
			RowParticipants = Event.Participants.Add();
			FillPropertyValues(RowParticipants, RecipientRow);
			Event.Write();
			
		EndIf;
		
	EndDo;
	
	SetPrivilegedMode(False);
	
	Return SuccessfullySent;
	
EndFunction

&AtServer
Function SendSMSMailing()
	
	SuccessfullySent = 0;
	SetPrivilegedMode(True);
	
	For Each RecipientRow In Object.Recipients Do
		
		SMSText = Object.Content;
		SetMessageParameters(SMSText, RecipientRow.Contact);
		
		ArrayOfNumbers     = New Array;
		ArrayOfNumbers.Add(RecipientRow.NumberForSending);
		SendingResult = SendingSMS.SendSMS(ArrayOfNumbers, SMSText, Object.SMSSenderName);
		
		For Each SentMessage In SendingResult.SentMessages Do
			If RecipientRow.NumberForSending = SentMessage.RecipientNumber Then
				RecipientRow.MessageID = SentMessage.MessageID;
				RecipientRow.DeliveryStatus         = Enums.SMSStatus.Outgoing;
			EndIf;;
		EndDo;
	
		If IsBlankString(SendingResult.ErrorDescription) Then
			Successfully = True;
			SuccessfullySent = SuccessfullySent + 1;
		Else
			ErrorText = StringFunctionsClientServer.SubstituteParametersInString(NStr("en = 'Cannot send SMS to recipient: %1, due to: %2'"),
				RecipientRow.Contact,
				SendingResult.ErrorDescription,
				);
			CommonUseClientServer.MessageToUser(ErrorText, , , CommonUseClientServer.PathToTabularSection("Recipients", RecipientRow.LineNumber, "Contact"));
			Successfully = False;
		EndIf;
		
		If Successfully AND Object.CreateEvents Then
		
			Event = Documents.Event.CreateDocument();
			
			Event.Date = CurrentDate();
			Event.EventBegin = Event.Date;
			Event.EventEnding = Event.Date;
			Event.SetNewNumber();
			
			Event.EventType = Enums.EventTypes.SMS;
			Event.Content = SMSText;
			Event.BasisDocument = Object.Ref;
			Event.State = Catalogs.JobAndEventStatuses.Completed;
			Event.Subject = Object.Subject;
			Event.Responsible = Object.Responsible;
			Event.Author = Object.Author;
			
			RowParticipants = Event.Participants.Add();
			FillPropertyValues(RowParticipants, RecipientRow);
			
			Event.Write();
			
		EndIf;
		
	EndDo;
	
	SetPrivilegedMode(False);
	
	Return SuccessfullySent;
	
EndFunction

&AtServer
Function GenerateEmailParameters(Contact, RecipientAddress, EmailBody, AttachmentsImages)
	
	EmailParameters = New Structure;
	
	If ValueIsFilled(Object.UserAccount.Password) Then
		EmailParameters.Insert("Password", Object.UserAccount.Password);
	EndIf;
	
	If ValueIsFilled(RecipientAddress) Then
		EmailParameters.Insert("Whom", RecipientAddress);
	EndIf;
	
	If ValueIsFilled(Object.Subject) Then
		EmailParameters.Insert("Subject", String(Object.Subject));
	EndIf;
	
	EmailAttachments = New Map;
	
	If AttachmentsImages.Count() > 0 Then
		DriveInteractions.AddAttachmentsImagesInEmail(EmailBody, EmailAttachments, AttachmentsImages);
	EndIf;
	
	AddAttachmentsFiles(EmailAttachments);
	
	EmailParameters.Insert("Body", EmailBody);
	EmailParameters.Insert("TextType", "HTML");
	EmailParameters.Insert("Attachments", EmailAttachments);
	
	Return EmailParameters;
	
EndFunction

&AtServer
Procedure AddAttachmentsFiles(EmailAttachments)
	
	For Each Attachment In Attachments Do
		AttachmentDescription = New Structure("BinaryData, Identifier");
		AttachmentDescription.BinaryData = GetFromTempStorage(Attachment.AddressInTemporaryStorage);
		AttachmentDescription.ID = "";
		EmailAttachments.Insert(Attachment.Presentation, AttachmentDescription);
	EndDo;
	
EndProcedure

&AtServerNoContext
Procedure SetMessageParameters(Content, Contact)
	
	AvailableParameters = New Array;
	AvailableParameters.Add("{Time}");
	AvailableParameters.Add("{Date}");
	AvailableParameters.Add("{Recipient name (nominative)}");
	AvailableParameters.Add("{Recipient name (genitive)}");
	AvailableParameters.Add("{Recipient name (dative)}");
	AvailableParameters.Add("{Recipient name (accusative)}");
	AvailableParameters.Add("{Recipient name (instrumental)}");
	AvailableParameters.Add("{Recipient name (prepositional)}");
	
	For Each Parameter In AvailableParameters Do
		If Find(Content, Parameter) = 0 Then
			Continue;
		EndIf;
		ParameterValue = GetParameterValue(Parameter, Contact);
		Content = StrReplace(Content, Parameter, ParameterValue);
	EndDo;
	
EndProcedure

&AtServerNoContext
Function GetParameterValue(Parameter, Contact)
	
	ParameterValue = "";
	
	If Parameter = "{Time}" Then
		
		ParameterValue = Format(CurrentSessionDate(), "DF=hh:mm");
		
	ElsIf Parameter = "{Date}" Then
		
		ParameterValue = Format(CurrentSessionDate(), "DLF=D");
		
	ElsIf Left(Parameter, 15) = "{Recipient name" Then
		
		If TypeOf(Contact) = Type("CatalogRef.Counterparties") Then
			ContactName = Contact.DescriptionFull;
		ElsIf TypeOf(Contact) = Type("CatalogRef.ContactPersons") Then
			ContactName = Contact.Description;
		Else
			ContactName = Contact;
		EndIf;
		
		ParameterValue = ContactName;
		
	EndIf;
	
	Return ParameterValue;
	
EndFunction

&AtClient
Procedure InsertParameter(ParameterName)
	
	If Items.ContentKind.CurrentPage = Items.ForEmail Then
		
		BeginningBookmark = 0;
		EndBookmark = 0;
		Items.FormattedDocument.GetTextSelectionBounds(BeginningBookmark, EndBookmark);
		
		Try
			
			BeginningPosition = FormattedDocument.GetBookmarkPosition(BeginningBookmark);
			EndPosition = FormattedDocument.GetBookmarkPosition(EndBookmark);
			
			If BeginningBookmark <> EndBookmark Then 
				FormattedDocument.Delete(BeginningBookmark, EndBookmark);
				Items.FormattedDocument.SetTextSelectionBounds(BeginningBookmark, BeginningBookmark);
			EndIf;
			FormattedDocument.Insert(BeginningBookmark, ParameterName);
			
			EndPosition = BeginningPosition + StrLen(ParameterName);
			EndBookmark = FormattedDocument.GetPositionBookmark(EndPosition);
			Items.FormattedDocument.SetTextSelectionBounds(BeginningBookmark, EndBookmark);
			
		Except
		EndTry;
		
	Else
		
		BeginRows = 0;
		ColumnBegin = 0;
		RowEnd = 0;
		ColumnEnd = 0;
		Items.Content.GetTextSelectionBounds(BeginRows,ColumnBegin,RowEnd,ColumnEnd);
		
		Object.Content = Left(Object.Content, ColumnBegin - 1) + ParameterName + Mid(Object.Content, ColumnBegin);
		
	EndIf;
	
	Modified = True;
	
EndProcedure

// Function returns the attachments in the form of the structures array to send the email.
//
&AtClient
Function Attachments(AttachmentsDrawings = Undefined)
	
	Result = New Array;
	
	For Each Attachment In Attachments Do
		AttachmentDescription = New Structure;
		AttachmentDescription.Insert("Presentation", Attachment.Presentation);
		AttachmentDescription.Insert("AddressInTemporaryStorage", Attachment.AddressInTemporaryStorage);
		AttachmentDescription.Insert("Encoding", "");
		Result.Add(AttachmentDescription);
	EndDo;
	
	Return Result;
	
EndFunction

// Procedure of interactive addition of attachments.
//
&AtClient
Procedure AddFileToAttachments()
	
	DialogueParameters = New Structure;
	DialogueParameters.Insert("Mode", FileDialogMode.Open);
	DialogueParameters.Insert("Multiselect", True);
	
	NotifyDescription = New NotifyDescription("AddFileToAttachmentsWhenFilePlace", ThisObject);
	
	StandardSubsystemsClient.ShowFilePlace(NotifyDescription, UUID, "", DialogueParameters);
	
EndProcedure

&AtClient
Procedure AddFileToAttachmentsWhenFilePlace(PlacedFiles, AdditionalParameters) Export
	
	If PlacedFiles = Undefined Or PlacedFiles.Count() = 0 Then
		Return;
	EndIf;
	
	AddFilesToList(PlacedFiles);
	Modified = True;
	
EndProcedure

// Procedure adds files to attachments.
//
// Parameters:
//  PlacedFiles	 - Array	 - Array of objects of the TransferredFileDescription type 
&AtServer
Procedure AddFilesToList(PlacedFiles)
	
	For Each FileDescription In PlacedFiles Do
		
		File = New File(FileDescription.Name);
		DotPosition = Find(File.Extension, ".");
		ExtensionWithoutDot = Mid(File.Extension, DotPosition + 1);
		
		Attachment = Attachments.Add();
		Attachment.Presentation = File.Name;
		Attachment.AddressInTemporaryStorage = PutToTempStorage(GetFromTempStorage(FileDescription.Location), UUID);
		Attachment.PictureIndex = FileFunctionsServiceClientServer.GetFileIconIndex(ExtensionWithoutDot);
		
	EndDo;
	
EndProcedure

&AtServer
Procedure UpdateDeliveryStatusesAtServer()
	
	For Each Recipient In Object.Recipients Do
		
		DeliveryStatus = SendingSMS.DeliveryStatus(Recipient.MessageID);
		Recipient.DeliveryStatus = DriveInteractions.MapSMSDeliveryStatus(DeliveryStatus);
		
	EndDo;
	
EndProcedure

&AtClient
Procedure Attachable_SetPictureForComment()
	
	DriveClientServer.SetPictureForComment(Items.GroupAdditional, Object.Comment);
	
EndProcedure

// Procedure in dependence on the client type opens or saves the selected file
//
&AtClient
Procedure OpenAttachment()
	
	If Items.Attachments.CurrentRow = Undefined Then
		Return;
	EndIf;
	
	SelectedAttachment = Attachments.FindByID(Items.Attachments.CurrentRow);
	
	#If WebClient Then
		GetFile(SelectedAttachment.AddressInTemporaryStorage, SelectedAttachment.Presentation, True);
	#Else
		TempFolderName = GetTempFileName();
		CreateDirectory(TempFolderName);
		
		TempFileName = CommonUseClientServer.AddFinalPathSeparator(TempFolderName) + SelectedAttachment.Presentation;
		
		BinaryData = GetFromTempStorage(SelectedAttachment.AddressInTemporaryStorage);
		BinaryData.Write(TempFileName);
		
		File = New File(TempFileName);
		File.SetReadOnly(True);
		If File.Extension = ".mxl" Then
			SpreadsheetDocument = GetSpreadsheetDocumentByBinaryData(SelectedAttachment.AddressInTemporaryStorage);
			OpenParameters = New Structure;
			OpenParameters.Insert("DocumentName", SelectedAttachment.Presentation);
			OpenParameters.Insert("SpreadsheetDocument", SpreadsheetDocument);
			OpenParameters.Insert("PathToFile", TempFileName);
			OpenForm("CommonForm.EditSpreadsheetDocument", OpenParameters, ThisObject);
		Else
			RunApp(TempFileName);
		EndIf;
	#EndIf
	
EndProcedure

&AtServerNoContext
Function GetSpreadsheetDocumentByBinaryData(Val BinaryData)
	
	If TypeOf(BinaryData) = Type("String") Then
		// binary data address is transferred for temporary storage
		BinaryData = GetFromTempStorage(BinaryData);
	EndIf;
	
	FileName = GetTempFileName("mxl");
	BinaryData.Write(FileName);
	
	SpreadsheetDocument = New SpreadsheetDocument;
	SpreadsheetDocument.Read(FileName);
	
	Try
		DeleteFiles(FileName);
	Except
		WriteLogEvent(NStr("en = 'Receive spreadsheet document'", CommonUseClientServer.MainLanguageCode()), EventLogLevel.Error, , , 
			DetailErrorDescription(ErrorInfo()));
	EndTry;
	
	Return SpreadsheetDocument;
	
EndFunction

// Function returns the content by selected subject.
//
&AtServerNoContext
Function GetContentSubject(EventSubject)
	
	Return EventSubject.Content;
	
EndFunction

&AtClient
Procedure ContactPickEnd(AddressInStorage, AdditionalParameters) Export
	
	If IsTempStorageURL(AddressInStorage) Then
		
		LockFormDataForEdit();
		Modified = True;
		FillContactsByAddressBook(AddressInStorage)
		
	EndIf;
	
EndProcedure

&AtServer
Procedure FillContactsByAddressBook(AddressInStorage)
	
	RecipientsTable = GetFromTempStorage(AddressInStorage);
	CurrentRowDataProcessor = Items.Recipients.CurrentRow <> Undefined;
	
	For Each SelectedRow In RecipientsTable Do
		
		If CurrentRowDataProcessor Then
			RecipientRow = Object.Recipients.FindByID(Items.Recipients.CurrentRow);
			CurrentRowDataProcessor = False;
		Else
			RecipientRow = Object.Recipients.Add();
		EndIf;
		
		RecipientRow.Contact = SelectedRow.Contact;
		RecipientRow.HowToContact = SelectedRow.HowToContact;
		
	EndDo;
	
EndProcedure

// Procedure - notification handler.
//
&AtClient
Procedure AttachmentsDragAndDropEnd(Result, TemporaryStorageAddress, SelectedFileName, AdditionalParameters) Export
	
	Files = New Array;
	PassedFile = New TransferableFileDescription(AdditionalParameters.Name, TemporaryStorageAddress);
	Files.Add(PassedFile);
	AddFilesToList(Files);
	
EndProcedure

&AtServer
Procedure SaveAttachments(BulkMail)
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	Attachments.Ref AS Ref,
		|	Attachments.AddressInTemporaryStorage,
		|	Attachments.Presentation
		|INTO secAttachments
		|FROM
		|	&Attachments AS Attachments
		|
		|INDEX BY
		|	Ref
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	BulkMailAttachedFiles.Ref
		|INTO ttAttachedFiles
		|FROM
		|	Catalog.BulkMailAttachedFiles AS BulkMailAttachedFiles
		|WHERE
		|	BulkMailAttachedFiles.FileOwner = &BulkMail
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	secAttachments.Ref AS AttachmentRefs,
		|	ttAttachedFiles.Ref AS AttachedFileRef,
		|	secAttachments.AddressInTemporaryStorage,
		|	secAttachments.Presentation
		|FROM
		|	secAttachments AS secAttachments
		|		Full JOIN ttAttachedFiles AS ttAttachedFiles
		|		ON secAttachments.Ref = ttAttachedFiles.Ref";
	
	Query.SetParameter("Attachments", Attachments.Unload());
	Query.SetParameter("BulkMail", BulkMail);
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		If Selection.AttachedFileRef = NULL Then
		// Add attachment to the attached files
			
			If Not IsBlankString(Selection.AddressInTemporaryStorage) Then
				
				FileNameParts = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(Selection.Presentation, ".", False);
				If FileNameParts.Count() > 1 Then
					ExtensionWithoutDot = FileNameParts[FileNameParts.Count()-1];
					NameWithoutExtension = Left(Selection.Presentation, StrLen(Selection.Presentation) - (StrLen(ExtensionWithoutDot)+1));
				Else
					ExtensionWithoutDot = "";
					NameWithoutExtension = Selection.Presentation;
				EndIf;
				
				Attachments.FindRows(New Structure("Presentation, AddressInTemporaryStorage", Selection.Presentation, Selection.AddressInTemporaryStorage))[0].Ref =
					AttachedFiles.AddFile(BulkMail, NameWithoutExtension, ExtensionWithoutDot, , , Selection.AddressInTemporaryStorage);
				
			EndIf;
			
		ElsIf Selection.AttachmentRefs = NULL Then
		// Delete attachment from the attached files
			
			AttachedFileObject = Selection.AttachedFileRef.GetObject();
			AttachedFileObject.SetDeletionMark(True);
			
		Else
		// Update attachment in attached files
			
			AttachedFiles.UpdateAttachedFile(Selection.AttachedFileRef, 
				New Structure("FileAddressInTemporaryStorage, TextTemporaryStorageAddress", Selection.AddressInTemporaryStorage, ""));
		EndIf;
		
	EndDo;
	
EndProcedure

#EndRegion

#Region SecondaryDataFilling

// Procedure fills the event content from the subject template.
//
&AtClient
Procedure FillContentEvents(EventSubject)
	
	If TypeOf(EventSubject) <> Type("CatalogRef.EventsSubjects") Then
		Return;
	EndIf;
	
	ThisIsEmail = Object.SendingMethod = PredefinedValue("Enum.MessageType.Email");
	If (ThisIsEmail AND Not IsBlankString(FormattedDocument.GetText())) Or (NOT ThisIsEmail AND Not IsBlankString(Object.Content)) Then
		
		ShowQueryBox(New NotifyDescription("FillEventContentEnd", ThisObject, New Structure("EventSubject", EventSubject)),
			NStr("en = 'Refill the content by the selected topic?'"), QuestionDialogMode.YesNo, 0);
		Return;
		
	EndIf;
	
	FillEventContentFragment(EventSubject);
	
EndProcedure

&AtClient
Procedure FillEventContentEnd(Result, AdditionalParameters) Export
	
	If Result <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	FillEventContentFragment(AdditionalParameters.EventSubject);
	
EndProcedure

&AtClient
Procedure FillEventContentFragment(Val EventSubject)
	
	If Object.SendingMethod = PredefinedValue("Enum.MessageType.Email") Then
		SetHTMLContentByEventSubject(FormattedDocument, EventSubject);
	Else
		Object.Content = GetContentSubject(EventSubject);
	EndIf;
	
EndProcedure

// Procedure sets the formatted document content by the selected subject.
//
&AtServerNoContext
Procedure SetHTMLContentByEventSubject(FormattedDocument, EventSubject)
	
	FormattedDocument.SetFormattedString(New FormattedString(EventSubject.Content));
	
EndProcedure

// Procedure fills subject selection data.
//
// Parameters:
//  SearchString - String	 - The SubjectHistoryByRow text being typed - ValueList	 - Used subjects in the row form
&AtServerNoContext
Function GetSubjectChoiceList(val SearchString)
	
	ListChoiceOfTopics = New ValueList;
	
	ChoiceParameters = New Structure;
	ChoiceParameters.Insert("Filter", New Structure("DeletionMark", False));
	ChoiceParameters.Insert("SearchString", SearchString);
	ChoiceParameters.Insert("ChoiceFoldersAndItems", FoldersAndItemsUse.Items);
	
	SubjectSelectionData = Catalogs.EventsSubjects.GetChoiceData(ChoiceParameters);
	
	For Each ItemOfList In SubjectSelectionData Do
		ListChoiceOfTopics.Add(ItemOfList.Value, New FormattedString(ItemOfList.Presentation, " (event subject)"));
	EndDo;
	
	Return ListChoiceOfTopics;
	
EndFunction

&AtClient
Procedure RecipientsContactSelectionEnd(AddressInStorage, AdditionalParameters) Export
	
	If IsTempStorageURL(AddressInStorage) Then
		
		LockFormDataForEdit();
		Modified = True;
		FillContactsByAddressBook(AddressInStorage);
		
	EndIf;
	
EndProcedure

// Procedure fills contact selection data.
//
// Parameters:
//  SearchString - String	 - Text being typed
&AtServerNoContext
Function GetContactChoiceList(val SearchString)
	
	ContactSelectionData = New ValueList;
	
	ChoiceParameters = New Structure;
	ChoiceParameters.Insert("Filter", New Structure("DeletionMark", False));
	ChoiceParameters.Insert("SearchString", SearchString);
	
	CounterpartySelectionData = Catalogs.Counterparties.GetChoiceData(ChoiceParameters);
	
	For Each ItemOfList In CounterpartySelectionData Do
		ContactSelectionData.Add(ItemOfList.Value, New FormattedString(ItemOfList.Presentation, " (counterparty)"));
	EndDo;
	
	ContactPersonSelectionData = Catalogs.ContactPersons.GetChoiceData(ChoiceParameters);
	
	For Each ItemOfList In ContactPersonSelectionData Do
		ContactSelectionData.Add(ItemOfList.Value, New FormattedString(ItemOfList.Presentation, " (contact person)"));
	EndDo;
	
	Return ContactSelectionData;
	
EndFunction

#EndRegion