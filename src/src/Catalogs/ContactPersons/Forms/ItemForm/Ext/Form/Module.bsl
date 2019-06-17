
#Region FormEventHadlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Key.IsEmpty() Then
		
		OnCreateOnReadAtServer();
		
	EndIf;
	
	// StandardSubsystems.ObjectVersioning
	ObjectVersioning.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.ObjectVersioning
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.Printing
	
	// StandardSubsystems.Properties
	PropertiesManagement.OnCreateAtServer(ThisForm, Object, "AdditionalAttributes");
	// End StandardSubsystems.Properties
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	OnCreateOnReadAtServer();
	
	PreviousOwner = Object.Owner;
	
	// StandardSubsystems.Properties
	PropertiesManagement.OnReadAtServer(ThisForm, CurrentObject);
	// End StandardSubsystems.Properties
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "Write_ContactPerson_Counterparty" And Object.Ref = Parameter Then
		ReReadObject();
	EndIf;
	
	// Mechanism handler "Properties".
	If PropertiesManagementClient.ProcessAlerts(ThisForm, EventName, Parameter) Then
		UpdateAdditionalAttributesItems();
	EndIf;
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	WriteRolesData(CurrentObject);
	
	ContactInformationDrive.BeforeWriteAtServer(ThisObject, CurrentObject);
	
	// StandardSubsystems.Properties
	PropertiesManagement.BeforeWriteAtServer(ThisForm, CurrentObject);
	// End StandardSubsystems.Properties
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	NotifyParameter = New Structure;
	NotifyParameter.Insert("ContactPerson",	Object.Ref);
	NotifyParameter.Insert("Owner",			Object.Owner);
	NotifyParameter.Insert("PreviousOwner",	PreviousOwner);
	NotifyParameter.Insert("Description",	Object.Description);
	
	If ContactPersonIndex >= 0 Then
		NotifyParameter.Insert("ContactPersonIndex",	ContactPersonIndex);
	EndIf;
	
	Notify("Write_ContactPerson", NotifyParameter, ThisObject);
	
	PreviousOwner = Object.Owner;
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	ContactInformationDrive.FillCheckProcessingAtServer(ThisObject, Cancel);
	
	// StandardSubsystems.Properties
	PropertiesManagement.FillCheckProcessing(ThisForm, Cancel, CheckedAttributes);
	// End StandardSubsystems.Properties
	
EndProcedure

#EndRegion

#Region FormItemsEventHadlers

&AtClient
Procedure RolesCloudURLProcessing(Item, FormattedStringURL, StandardProcessing)
	
	StandardProcessing = False;
	
	RoleID = Mid(FormattedStringURL, StrLen("Role_")+1);
	RolesRow = RolesData.FindByID(RoleID);
	RolesData.Delete(RolesRow);
	
	RefreshRolesItems();
	
	Modified = True;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure OnCreateOnReadAtServer()
	
	ReadRolesData();
	RefreshRolesItems();
	
	ContactInformationDrive.OnCreateOnReadAtServer(ThisObject, , 6);
	
	If Parameters.Property("ContactPersonIndex") Then
		ContactPersonIndex = Parameters.ContactPersonIndex;
	Else
		ContactPersonIndex = -1;
	EndIf;
	If Parameters.Property("Counterparty")
		And Not Object.Owner = Parameters.Counterparty Then
		Object.Owner = Parameters.Counterparty;
		Modified = True;
	EndIf;
	If Parameters.Property("ContactDescription")
		And Not Object.Description = Parameters.ContactDescription Then
		Object.Description = Parameters.ContactDescription;
		Modified = True;
	EndIf;
	If Parameters.Property("Position")
		And Not Object.Position = Parameters.Position Then
		Object.Position = Parameters.Position;
		Modified = True;
	EndIf;
	If Parameters.Property("ContactInformation") Then
		ThisObject.ContactInformation.Load(Parameters.ContactInformation.Unload());
		ContactInformationDrive.RefreshContactInformationItems(ThisObject);
		Modified = True;
	EndIf;
	
EndProcedure

&AtServer
Procedure ReReadObject()
	
	NewObject = Object.Ref.GetObject();
	ValueToFormAttribute(NewObject, "Object");
	OnCreateOnReadAtServer();
	
EndProcedure

#EndRegion

#Region Roles

&AtServer
Procedure ReadRolesData()
	
	RolesData.Clear();
	
	If Not ValueIsFilled(Object.Ref) Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	ContactPersonsRoles.Role AS Role,
		|	ContactPersonsRoles.Role.DeletionMark AS DeletionMark,
		|	ContactPersonsRoles.Role.Description AS Description
		|FROM
		|	Catalog.ContactPersons.Roles AS ContactPersonsRoles
		|WHERE
		|	ContactPersonsRoles.Ref = &Ref";
	
	Query.SetParameter("Ref", Object.Ref);
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		NewRoleData = RolesData.Add();
		URLFS	= "Role_" + NewRoleData.GetID();
		
		NewRoleData.Role				= Selection.Role;
		NewRoleData.DeletionMark		= Selection.DeletionMark;
		NewRoleData.RolePresentation	= FormattedStringRolePresentation(Selection.Description, Selection.DeletionMark, URLFS);
		NewRoleData.RoleLength			= StrLen(Selection.Description);
		
	EndDo;
	
EndProcedure

&AtServer
Procedure RefreshRolesItems()
	
	FS = RolesData.Unload(, "RolePresentation").UnloadColumn("RolePresentation");
	
	Index = FS.Count()-1;
	While Index > 0 Do
		FS.Insert(Index, "  ");
		Index = Index - 1;
	EndDo;
	
	Items.RolesCloud.Title			= New FormattedString(FS);
	Items.RolesAndIndent.Visible	= FS.Count() > 0;
	
EndProcedure

&AtServer
Procedure WriteRolesData(CurrentObject)
	
	CurrentObject.Roles.Load(RolesData.Unload(,"Role"));
	
EndProcedure

&AtServer
Procedure AttachRoleAtServer(Role)
	
	If RolesData.FindRows(New Structure("Role", Role)).Count() > 0 Then
		Return;
	EndIf;
	
	RoleData = CommonUse.ObjectAttributesValues(Role, "Description, DeletionMark");
	
	RolesRow = RolesData.Add();
	URLFS = "Role_" + RolesRow.GetID();
	
	RolesRow.Role				= Role;
	RolesRow.DeletionMark		= RoleData.DeletionMark;
	RolesRow.RolePresentation	= FormattedStringRolePresentation(RoleData.Description, RoleData.DeletionMark, URLFS);
	RolesRow.RoleLength			= StrLen(RoleData.Description);
	
	RefreshRolesItems();
	
	Modified = True;
	
EndProcedure

&AtServer
Procedure CreateAndAttachRoleAtServer(Val RoleTitle)
	
	Role = FindCreateRole(RoleTitle);
	AttachRoleAtServer(Role);
	
EndProcedure

&AtServerNoContext
Function FindCreateRole(Val RoleTitle)
	
	Role = Catalogs.ContactPersonsRoles.FindByDescription(RoleTitle, True);
	
	If Role.IsEmpty() Then
		
		RoleObject = Catalogs.ContactPersonsRoles.CreateItem();
		RoleObject.Description = RoleTitle;
		RoleObject.Write();
		Role = RoleObject.Ref;
		
	EndIf;
	
	Return Role;
	
EndFunction

&AtClientAtServerNoContext
Function FormattedStringRolePresentation(RoleDescription, DeletionMark, URLFS)
	
	#If Client Then
	Color		= CommonUseClientReUse.StyleColor("MinorInscriptionText");
	BaseFont	= CommonUseClientReUse.StyleFont("NormalTextFont");
	#Else
	Color		= StyleColors.MinorInscriptionText;
	BaseFont	= StyleFonts.NormalTextFont;
	#EndIf
	
	Font	= New Font(BaseFont,,,True,,?(DeletionMark, True, Undefined));
	
	ComponentsFS = New Array;
	ComponentsFS.Add(New FormattedString(RoleDescription + Chars.NBSp, Font, Color));
	ComponentsFS.Add(New FormattedString(PictureLib.Clear, , , , URLFS));
	
	Return New FormattedString(ComponentsFS);
	
EndFunction

&AtClient
Procedure RoleInputFieldChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	If Not ValueIsFilled(SelectedValue) Then
		Return;
	EndIf;
	
	StandardProcessing = False;
	
	If TypeOf(SelectedValue) = Type("CatalogRef.ContactPersonsRoles") Then
		AttachRoleAtServer(SelectedValue);
	EndIf;
	Item.UpdateEditText();
	
EndProcedure

&AtClient
Procedure RoleInputFieldTextEditEnd(Item, Text, ChoiceData, DataGetParameters, StandardProcessing)
	
	If Not IsBlankString(Text) Then
		StandardProcessing = False;
		CreateAndAttachRoleAtServer(Text);
		CurrentItem = Items.RoleInputField;
	EndIf;
	
EndProcedure

#EndRegion

#Region ContactInformationDrive

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
	AdditionalReportsAndDataProcessors.ExecuteAllocatedCommandAtServer(ThisForm, ItemName, ExecutionResult);
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
