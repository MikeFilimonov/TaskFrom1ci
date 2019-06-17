#Region Variables

&AtClient
Var DoFormClosingChecks;

#EndRegion

#Region FormEventHadlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	If Not ValueIsFilled(Object.Ref) AND Not GetFunctionalOption("UseSeveralCompanies") Then
		ErrorText = NStr("en = 'It is forbidden to create a new company
		                 |with the off parameter setting accounting ""Use several companies""'");
		Raise ErrorText;
	EndIf;
	
	If Parameters.Key.IsEmpty() Then
		
		GenerateDescriptionAutomatically = True;
		
		ContactInformationDrive.OnCreateOnReadAtServer(ThisObject);
		
		If ValueIsFilled(Object.Individual) Then
			ReadIndividual(Object.Individual);
		EndIf;
		
	EndIf;
	
	If ValueIsFilled(Object.Individual) Then
		Items.Surname.AutoChoiceIncomplete		= Undefined;
		Items.FirstName.AutoChoiceIncomplete	= Undefined;
		Items.MiddleName.AutoChoiceIncomplete	= Undefined;
	EndIf;
	
	IsWebClient = CommonUseClientServer.ThisIsWebClient();
	Items.CommandBarLogo.Visible		= IsWebClient;
	Items.CommandBarFacsimile.Visible	= IsWebClient;
	
	FormManagement(ThisObject);
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisForm, Items.PrintCommands);
	// End StandardSubsystems.Printing
	
	// StandardSubsystems.Properties
	PropertiesManagement.OnCreateAtServer(ThisForm, Object, "GroupAdditionalAttributes");
	// End StandardSubsystems.Properties
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(ValueSelected, ChoiceSource)
	
	If ChoiceSource.FormName = "CommonForm.AttachedFiles"
		AND ValueIsFilled(ValueSelected) Then
		
		If WorkWithLogo Then
			
			Object.LogoFile = ValueSelected;
			BinaryPictureData = DriveServer.ReferenceToBinaryFileData(Object.LogoFile, UUID);
			If BinaryPictureData <> Undefined Then
				AddressLogo = BinaryPictureData;
			EndIf;
			
		ElsIf WorkWithFacsimile Then
			
			Object.FileFacsimilePrinting = ValueSelected;
			BinaryPictureData = DriveServer.ReferenceToBinaryFileData(Object.FileFacsimilePrinting, UUID);
			If BinaryPictureData <> Undefined Then
				AddressFaxPrinting = BinaryPictureData;
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "SettingMainAccount" AND Parameter.Owner = Object.Ref Then
		
		Object.BankAccountByDefault = Parameter.NewMainAccount;
		If Not Modified Then
			Write();
		EndIf;
		Notify("SettingMainAccountCompleted");
		
	ElsIf EventName = "Record_AttachedFile" Then
		
		If WorkWithLogo Then
			
			Modified	= True;
			Object.LogoFile = ?(TypeOf(Source) = Type("Array"), Source[0], Source);
			BinaryPictureData = DriveServer.ReferenceToBinaryFileData(Object.LogoFile, UUID);
			If BinaryPictureData <> Undefined Then
				AddressLogo = BinaryPictureData;
			EndIf;
			WorkWithLogo = False;
			
		ElsIf WorkWithFacsimile Then
			
			Modified	= True;
			Object.FileFacsimilePrinting = ?(TypeOf(Source) = Type("Array"), Source[0], Source);
			BinaryPictureData = DriveServer.ReferenceToBinaryFileData(Object.FileFacsimilePrinting, UUID);
			If BinaryPictureData <> Undefined Then
				AddressFaxPrinting = BinaryPictureData;
			EndIf;
			WorkWithFacsimile = False;
			
		EndIf;
		
	ElsIf EventName = "Write_Individuals" AND Source <> Object.Ref AND Parameter = Object.Individual Then
		
		ReadIndividual(Parameter);
		
	EndIf;
	
	// Mechanism handler "Properties".
	If PropertiesManagementClient.ProcessAlerts(ThisForm, EventName, Parameter) Then
		
		UpdateAdditionalAttributesItems();
		
	EndIf;
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	If ValueIsFilled(CurrentObject.LogoFile) Then
		BinaryPictureData = DriveServer.ReferenceToBinaryFileData(CurrentObject.LogoFile, UUID);
		If BinaryPictureData <> Undefined Then
			AddressLogo = BinaryPictureData;
		EndIf;
	EndIf;
	
	If ValueIsFilled(CurrentObject.FileFacsimilePrinting) Then
		BinaryPictureData = DriveServer.ReferenceToBinaryFileData(CurrentObject.FileFacsimilePrinting, UUID);
		If BinaryPictureData <> Undefined Then
			AddressFaxPrinting = BinaryPictureData;
		EndIf;
	EndIf;
	
	If CurrentObject.LegalEntityIndividual = Enums.CounterpartyType.Individual Then
		ReadIndividual(CurrentObject.Individual);
	EndIf;
	
	GenerateDescriptionAutomatically	= IsBlankString(Object.Description);
	
	ContactInformationDrive.OnCreateOnReadAtServer(ThisObject);
	
	// StandardSubsystems.Properties
	PropertiesManagement.OnReadAtServer(ThisForm, CurrentObject);
	// End StandardSubsystems.Properties
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	// Save previous values for further analysis
	CurrentObject.AdditionalProperties.Insert("PreviousCompanyKind", CommonUse.ObjectAttributeValue(CurrentObject.Ref, "LegalEntityIndividual"));
	CurrentObject.AdditionalProperties.Insert("IsNew", CurrentObject.IsNew());
	
	// An individual will be created in OnWrite()
	If CurrentObject.LegalEntityIndividual = Enums.CounterpartyType.Individual AND Not ValueIsFilled(CurrentObject.Individual) Then
		CurrentObject.Individual = Catalogs.Individuals.GetRef();
	EndIf;
	
	ContactInformationDrive.BeforeWriteAtServer(ThisObject, CurrentObject);
	
	// StandardSubsystems.Properties
	PropertiesManagement.BeforeWriteAtServer(ThisForm, CurrentObject);
	// End StandardSubsystems.Properties
	
EndProcedure

&AtServer
Procedure OnWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	WriteIndividual(CurrentObject);
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	ReadIndividual(CurrentObject.Individual);
	
	FormManagement(ThisObject);
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	Notify("Write_Companies", Object.Ref, Object.Ref);
	If Object.LegalEntityIndividual = PredefinedValue("Enum.CounterpartyType.Individual") Then
		Notify("Write_Individuals", Object.Individual, Object.Ref);
	EndIf;
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	If Object.LegalEntityIndividual = Enums.CounterpartyType.Individual Then
		If Not ValueIsFilled(IndividualFullName.Surname) 
			AND Not ValueIsFilled(IndividualFullName.Name) 
			AND Not ValueIsFilled(IndividualFullName.Patronymic) Then
			
			MessageText = NStr("en = 'Full name is not filled'");
			CommonUseClientServer.MessageToUser(MessageText, ,	"Surname", "IndividualFullName", Cancel);
		EndIf;
	EndIf;
	
	ContactInformationDrive.FillCheckProcessingAtServer(ThisObject, Cancel);
	
	// StandardSubsystems.Properties
	PropertiesManagement.FillCheckProcessing(ThisForm, Cancel, CheckedAttributes);
	// End StandardSubsystems.Properties
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, MessageText, StandardProcessing)
	
	If Not DoFormClosingChecks Or Exit Then
		Return;
	EndIf;
	
	If Not Object.Ref.IsEmpty() And Not AccountingPolicyIsSpecified(Object.Ref) Then
		
		Cancel = True;
		
		ShowQueryBox(
			New NotifyDescription("BeforeClosingQueryBoxHandler", ThisObject),
			NStr("en = 'The accounting policy is not specified. You can not use this company until it is done. Do you want to specify it now?'"),
			QuestionDialogMode.YesNoCancel);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormItemsEventHadlers

&AtClient
Procedure PrefixOnChange(Item)
	
	If StrFind(Object.Prefix, "-") > 0 Then
		
		ShowMessageBox(Undefined, NStr("en = 'It is impossible to use the symbol ""-"" in the prefix of company'"));
		Object.Prefix = StrReplace(Object.Prefix, "-", "");
		
	EndIf;
	
EndProcedure

&AtClient
Procedure DescriptionFullOnChange(Item)
	
	If GenerateDescriptionAutomatically Then
		Object.Description	= Object.DescriptionFull;
	EndIf;

EndProcedure

&AtClient
Procedure LegalEntityIndividualOnChange(Item)
	
	FormManagement(ThisObject);
	
EndProcedure

&AtClient
Procedure IndividualFullNameOnChange(Item)
	
	If Not LockIndividualOnEdit() Then
		Return;
	EndIf;
	
EndProcedure

&AtClient
Procedure AddressLogoClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	LockFormDataForEdit();
	
	PicturesFlagsManagement(True, False);
	AddImageAtClient();
	
EndProcedure

&AtClient
Procedure AddressFaxPrintingClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	LockFormDataForEdit();
	
	PicturesFlagsManagement(False, True);
	AddImageAtClient();
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure PreviewPrintedFormProformaInvoice(Command)
	
	PrintManagementClient.ExecutePrintCommand(
		"Catalog.Companies",
		"PreviewPrintedFormProformaInvoice",
		CommonUseClientServer.ValueInArray(Object.Ref),
		ThisObject,
		New Structure);
	
EndProcedure

&AtClient
Procedure AddImageLogo(Command)
	
	If Not ValueIsFilled(Object.Ref) Then
		
		QuestionText = NStr("en = 'To select an image, write the object. Write?'");
		Response = Undefined;

		ShowQueryBox(New NotifyDescription("AddLogoImageEnd", ThisObject), QuestionText, QuestionDialogMode.YesNo);
        Return;
		
	EndIf;
	
	AddLogoImageFragment();
	
EndProcedure

&AtClient
Procedure ChangeImageLogo(Command)
	
	ClearMessages();
	
	If ValueIsFilled(Object.LogoFile) Then
		
		AttachedFilesClient.OpenAttachedFileForm(Object.LogoFile);
		
	Else
		
		MessageText = NStr("en = 'No image for editing'");
		CommonUseClientServer.MessageToUser(MessageText,, "AddressLogo");
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ClearImageLogo(Command)
	
	Object.LogoFile = Undefined;
	AddressLogo = "";
	
EndProcedure

&AtClient
Procedure LogoOfAttachedFiles(Command)
	
	PicturesFlagsManagement(True, False);
	ChoosePictureFromAttachedFiles();
	
EndProcedure

&AtClient
Procedure AddImageFacsimile(Command)
	
	If Not ValueIsFilled(Object.Ref) Then
		
		QuestionText = NStr("en = 'To select an image, write the object. Write?'");
		Response = Undefined;

		ShowQueryBox(New NotifyDescription("AddFacsimileImageEnd", ThisObject), QuestionText, QuestionDialogMode.YesNo);
        Return;
		
	EndIf;
	
	AddFacsimileImageFragment();
	
EndProcedure

&AtClient
Procedure ChangeImageFacsimile(Command)
	
	ClearMessages();
	
	If ValueIsFilled(Object.FileFacsimilePrinting) Then
		
		AttachedFilesClient.OpenAttachedFileForm(Object.FileFacsimilePrinting);
		
	Else
		
		MessageText = NStr("en = 'No image for editing'");
		CommonUseClientServer.MessageToUser(MessageText,, "AddressLogo");
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ClearImageFacsimile(Command)
	
	Object.FileFacsimilePrinting = Undefined;
	AddressFaxPrinting = "";
	
EndProcedure

&AtClient
Procedure FacsimileOfAttachedFiles(Command)
	
	PicturesFlagsManagement(False, True);
	ChoosePictureFromAttachedFiles();
	
EndProcedure

#EndRegion

#Region Private

#Region OtherProceduresAndFunctions

&AtServerNoContext
Function AccountingPolicyIsSpecified(Company)
	
	Query = New Query;
	
	Query.Text =
	"SELECT TOP 1
	|	0 AS Nil
	|FROM
	|	InformationRegister.AccountingPolicy AS AccountingPolicy
	|WHERE
	|	AccountingPolicy.Company = &Company
	|	AND AccountingPolicy.Period <= &Period";
	
	Query.SetParameter("Period",	CurrentDate());
	Query.SetParameter("Company",	Company);
	
	Return Not Query.Execute().IsEmpty();
	
EndFunction

&AtClient
Procedure BeforeClosingQueryBoxHandler(QueryResult, AdditionalParameters) Export
	
	If QueryResult = DialogReturnCode.Yes Then
		SpecifyAccountingPolicy();
	ElsIf QueryResult = DialogReturnCode.No Then
		DoFormClosingChecks = False;
		Close();
	EndIf;

EndProcedure

&AtClient
Procedure SpecifyAccountingPolicy()
	
	FormParameters = New Structure;
	FillingValuesParameter = New Structure;
	FillingValuesParameter.Insert("Company", Object.Ref);
	FormParameters.Insert("FillingValues", FillingValuesParameter);
	
	OpenForm("InformationRegister.AccountingPolicy.RecordForm", FormParameters);
	
EndProcedure

&AtClientAtServerNoContext
Procedure FormManagement(Form)
	
	Items = Form.Items;
	Object = Form.Object;
	
	// Set visibility of form items depending on the type of company
	If Object.LegalEntityIndividual = PredefinedValue("Enum.CounterpartyType.LegalEntity") Then
		
		Items.GroupFullName.Visible	= False;
		Items.LegalForm.Visible		= True;
		
	Else
		
		Items.GroupFullName.Visible	= True;
		Items.LegalForm.Visible		= False;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region Individual

&AtServer
Procedure ReadIndividual(Individual)
	
	If Not ValueIsFilled(Individual) Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	ChangeHistoryOfIndividualNamesSliceLast.Period AS Period,
		|	ChangeHistoryOfIndividualNamesSliceLast.Ind AS Ind
		|FROM
		|	InformationRegister.ChangeHistoryOfIndividualNames.SliceLast(, Ind = &Ind) AS ChangeHistoryOfIndividualNamesSliceLast";
	
	Query.SetParameter("Ind", Individual);
	
	Selection = Query.Execute().Select();
	
	If Selection.Next() Then
		RecordManager = InformationRegisters.ChangeHistoryOfIndividualNames.CreateRecordManager();
		FillPropertyValues(RecordManager, Selection);
		RecordManager.Read();
		ValueToFormAttribute(RecordManager, "IndividualFullName");
	EndIf;
	
EndProcedure

&AtServer
Procedure WriteIndividual(CurrentObject)
	
	If Object.LegalEntityIndividual <> Enums.CounterpartyType.Individual Then
		Return;
	EndIf;
	
	If Not ValueIsFilled(IndividualFullName.Period) Тогда
		IndividualFullName.Period = '19800101';
	EndIf;
	
	If Not ValueIsFilled(IndividualFullName.Ind) Then
		IndividualFullName.Ind = CurrentObject.Individual;
	EndIf;
	
	RecordManager = FormAttributeToValue("IndividualFullName");
	RecordManager.Write();
		
	If Object.Individual.IsEmpty() Then
		IndividualObject = Catalogs.Individuals.CreateItem();
		IndividualObject.SetNewObjectRef(CurrentObject.Individual);
	Else
		IndividualObject = Object.Individual.GetObject();
	EndIf;	
	
	IndividualObject.FirstName	= IndividualFullName.Name;
	IndividualObject.MiddleName	= IndividualFullName.Patronymic;
	IndividualObject.LastName	= IndividualFullName.Surname;
	
	IndividualObject.Description = IndividualFullName.Name
		+ ?(IsBlankString(IndividualFullName.Patronymic), "", " " + IndividualFullName.Patronymic)
		+ ?(IsBlankString(IndividualFullName.Surname), "", " " + IndividualFullName.Surname);
	
	IndividualObject.Write();
	
EndProcedure

&AtClient
Function LockIndividualOnEdit()
	
	If Not Parameters.Key.IsEmpty() AND Not IndividualLocked Then
		If Not LockIndividualOnEditAtServer() Then
			ShowMessageBox(, NStr("en = 'You can not make changes to the personal data of an individual. Perhaps the data is edited by another user.'"));
			ReadIndividual(Object.Individual);
			Return False;
		Else
			IndividualLocked = True;
			Return True;
		EndIf;
	Else
		Return True;
	EndIf;
	
EndFunction

&AtServer
Function LockIndividualOnEditAtServer()
	
	Try
		LockDataForEdit(Object.Individual.Ref, Object.Individual.DataVersion, UUID);
		Return True;
	Except
		Return False;
	EndTry;
	
EndFunction

#EndRegion

#Region FacsimileAndLogo

&AtServerNoContext
Function GetFileData(PictureFile, UUID)
	
	Return AttachedFiles.GetFileData(PictureFile, UUID);
	
EndFunction

&AtClient
Procedure PicturesFlagsManagement(ThisIsWorkingWithLogo = False, ThisIsWorkingWithFacsimile = False)
	
	WorkWithLogo		= ThisIsWorkingWithLogo;
	WorkWithFacsimile	= ThisIsWorkingWithFacsimile;
	
EndProcedure

&AtClient
Procedure SeeAttachedFile()
	
	ClearMessages();
	
	AnObjectsNameAttribute = "";
	
	If WorkWithLogo Then
		
		AnObjectsNameAttribute = "LogoFile";
		
	ElsIf WorkWithFacsimile Then
		
		AnObjectsNameAttribute = "FileFacsimilePrinting";
		
	EndIf;
	
	If Not IsBlankString(AnObjectsNameAttribute)
		AND ValueIsFilled(Object[AnObjectsNameAttribute]) Then
		
		FileData = GetFileData(Object[AnObjectsNameAttribute], UUID);
		AttachedFilesClient.OpenFile(FileData);
		
	Else
		
		MessageText = NStr("en = 'No preview image'");
		CommonUseClientServer.MessageToUser(MessageText,, "PictureURL");
		
	EndIf;
	
EndProcedure

&AtClient
Procedure AddImageAtClient()
	
	If Not ValueIsFilled(Object.Ref) Then
		
		QuestionText = NStr("en = 'To select an image, write the object. Write?'");
		Response = Undefined;

		ShowQueryBox(New NotifyDescription("AddImageAtClientEnd", ThisObject), QuestionText, QuestionDialogMode.YesNo);
        Return;
		
	EndIf;
	
	AddImageAtClientFragment();
	
EndProcedure

&AtClient
Procedure AddImageAtClientEnd(Result, AdditionalParameters) Export
    
    Response = Result;
    
    If Response = DialogReturnCode.No Then
        
        Return;
        
    EndIf;
    
    Write();
    
    
    AddImageAtClientFragment();

EndProcedure

&AtClient
Procedure AddImageAtClientFragment()
    
    Var FileID, AnObjectsNameAttribute, Filter;
    
    If WorkWithLogo Then
        
        AnObjectsNameAttribute = "LogoFile";
        
    ElsIf WorkWithFacsimile Then
        
        AnObjectsNameAttribute = "FileFacsimilePrinting";
        
    EndIf;
    
    If ValueIsFilled(Object[AnObjectsNameAttribute]) Then
        
        SeeAttachedFile();
        
    ElsIf ValueIsFilled(Object.Ref) Then
        
        FileID = New UUID;
        
        Filter = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'All Images %1|All files %2|bmp format %3|GIF format %4|JPEG format %5|PNG format %6|TIFF format %7|Icon format %8|MetaFile format %9'"),
			"(*.bmp;*.gif;*.png;*.jpeg;*.dib;*.rle;*.tif;*.jpg;*.ico;*.wmf;*.emf)|*.bmp;*.gif;*.png;*.jpeg;*.dib;*.rle;*.tif;*.jpg;*.ico;*.wmf;*.emf",
			"(*.*)|*.*",
			"(*.bmp*;*.dib;*.rle)|*.bmp;*.dib;*.rle",
			"(*.gif*)|*.gif",
			"(*.jpeg;*.jpg)|*.jpeg;*.jpg",
			"(*.png*)|*.png",
			"(*.tif)|*.tif",
			"(*.ico)|*.ico",
			"(*.wmf;*.emf)|*.wmf;*.emf");
        
        AttachedFilesClient.AddFiles(Object.Ref, FileID, Filter);
        
    EndIf;

EndProcedure

&AtClient
Procedure ChoosePictureFromAttachedFiles()
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("FileOwner", Object.Ref);
	ParametersStructure.Insert("ChoiceMode", True);
	ParametersStructure.Insert("CloseOnChoice", True);
	
	OpenForm("CommonForm.AttachedFiles", ParametersStructure, ThisForm);
	
EndProcedure

&AtClient
Procedure AddLogoImageEnd(Result, AdditionalParameters) Export
    
    Response = Result;
    
    If Response = DialogReturnCode.No Then
        Return
    EndIf;
    
    Write();
    
    
    AddLogoImageFragment();

EndProcedure

&AtClient
Procedure AddLogoImageFragment()
    
    Var FileID;
    
    PicturesFlagsManagement(True, False);
    
    FileID = New UUID;
    AttachedFilesClient.AddFiles(Object.Ref, FileID);

EndProcedure

&AtClient
Procedure AddFacsimileImageEnd(Result, AdditionalParameters) Export
    
    Response = Result;
    
    If Response = DialogReturnCode.No Then
        Return
    EndIf;
    
    Write();
    
    
    AddFacsimileImageFragment();

EndProcedure

&AtClient
Procedure AddFacsimileImageFragment()
    
    Var FileID;
    
    PicturesFlagsManagement(False, True);
    
    FileID = New UUID;
    AttachedFilesClient.AddFiles(Object.Ref, FileID);

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

#Region Initialization

DoFormClosingChecks = True;

#EndRegion

#EndRegion