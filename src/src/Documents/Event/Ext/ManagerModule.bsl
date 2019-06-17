#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

Procedure PresentationFieldsGetProcessing(Fields, StandardProcessing)
	
	StandardProcessing = False;
	
	Fields.Add("Date");
	Fields.Add("EventType");
	
EndProcedure

Procedure PresentationGetProcessing(Data, Presentation, StandardProcessing)
	
	StandardProcessing = False;
	
	Presentation = StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en = 'Event: %1 dated %2'"),
		Data.EventType,
		Format(Data.Date, "DLF=D"));
	
EndProcedure

Procedure FormGetProcessing(FormKind, Parameters, SelectedForm, AdditionalInformation, StandardProcessing)
	
	If FormKind <> "DocumentForm"
		AND FormKind <> "ObjectForm" Then
		Return;
	EndIf;
	
	EventType = Undefined; 
	
	If Parameters.Property("Key") AND ValueIsFilled(Parameters.Key) Then
		EventType	= CommonUse.ObjectAttributeValue(Parameters.Key, "EventType");
	EndIf;
	
	// If the document is copied that we get event type from copied document.
	If Not ValueIsFilled(EventType) Then
		If Parameters.Property("CopyingValue")
			AND ValueIsFilled(Parameters.CopyingValue) Then
			EventType = CommonUse.ObjectAttributeValue(Parameters.CopyingValue, "EventType");
		EndIf;
	EndIf;
	
	If Not ValueIsFilled(EventType) Then
		If Parameters.Property("FillingValues") 
			AND TypeOf(Parameters.FillingValues) = Type("Structure") Then
			If Parameters.FillingValues.Property("EventType") Then
				EventType	= Parameters.FillingValues.EventType;
			EndIf;
		EndIf;
	EndIf;
	
	StandardProcessing = False;
	EventForms = GetOperationKindMapToForms();
	SelectedForm = EventForms[EventType];
	If SelectedForm = Undefined Then
		SelectedForm = "DocumentForm";
	EndIf;

EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

Function GetOperationKindMapToForms() Export

	EventForms = New Map;
	EventForms.Insert(Enums.EventTypes.Email, 			"EmailForm");
	EventForms.Insert(Enums.EventTypes.SMS,				"MessagesSMSForm");
	EventForms.Insert(Enums.EventTypes.PhoneCall,		"EventForm");
	EventForms.Insert(Enums.EventTypes.PersonalMeeting,	"EventForm");
	EventForms.Insert(Enums.EventTypes.Other,			"EventForm");
	
	Return EventForms;

EndFunction

#EndRegion

#Region PrintInterface

// Fills in the list of printing commands.
// 
// Parameters:
//   PrintCommands - ValueTable - see fields' content in the PrintManagement.CreatePrintCommandsCollection function.
//
Procedure AddPrintCommands(PrintCommands) Export
	
	
	
EndProcedure

#EndRegion

#Region Interface

Function GetHowToContact(Contact, IsEmail = False) Export
	
	Result = "";
	
	Contacts = New Array;
	Contacts.Add(Contact);
	
	TypesCI = New Array;
	TypesCI.Add(Enums.ContactInformationTypes.EmailAddress);
	If Not IsEmail Then
		TypesCI.Add(Enums.ContactInformationTypes.Phone);
	EndIf;
	
	TableCI = ContactInformationManagement.ObjectsContactInformation(Contacts, TypesCI);
	TableCI.Sort("Type DESC");
	For Each RowCI In TableCI Do
		Result = "" + Result + ?(Result = "", "", ", ") + RowCI.Presentation;
	EndDo;
	
	Return Result;
	
EndFunction

#EndRegion

#Region Email

Function SubjectWithResponsePrefix(Subject, Command) Export
	
	If Command = EmailDriveClientServer.CommandReply() Then
		
		If StrStartsWith(Upper(Subject), "RE:") Then
			Return Subject;
		EndIf;
		
		Return StrTemplate("Re: %1", Subject);
		
	ElsIf Command = EmailDriveClientServer.CommandForward() Then
		
		If StrStartsWith(Upper(Subject), "Fw:") Then
			Return Subject;
		EndIf;
		
		Return StrTemplate("Fw: %1", Subject);
		
	Else
		
		Return Subject;
		
	EndIf;
	
EndFunction
	
#EndRegion

#EndIf