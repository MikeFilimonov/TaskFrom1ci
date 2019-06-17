#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

// Creates conterparty on base of a lead.
Function GetCreateCounterparty(Lead) Export
	
	If TypeOf(Lead) = Type("CatalogRef.Leads") Then
		LeadObject = Lead.GetObject();
	Else
		LeadObject = Lead;
	EndIf;
	
	NewCounterparty = Catalogs.Counterparties.EmptyRef();
	
	If LeadObject.CheckFilling() Then
		
		If ValueIsFilled(LeadObject.Counterparty) Then
			
			NewCounterparty = LeadObject.Counterparty;
			
		Else
			
			NewCounterparty = CreateCounterpartyAndContactPersons(LeadObject);
			
			LeadObject.ClosureResult = Enums.LeadClosureResult.ConvertedIntoCustomer;
			LeadObject.ClosureDate = CurrentSessionDate();
			LeadObject.RejectionReason = Undefined;
			LeadObject.Counterparty = NewCounterparty;
			LeadObject.Write();
			
		EndIf;
		
	EndIf;
	
	Return NewCounterparty;
	
EndFunction

// Refreshing ContactInformationPanelData group
Procedure RefreshPanelData(Form, Lead) Export
	
	Form.ContactInformationPanelData.Clear();
	
	If Lead = Undefined Тогда
		AddMessageAboutMissingData(Form.ContactInformationPanelData);
		Return;
	EndIf;
	
	ContactInformationPanelData = Form.ContactInformationPanelData;
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	CAST(LeadsContacts.Representation AS STRING(1000)) AS Representation,
		|	LeadsContacts.ContactLineIdentifier AS ContactLineIdentifier,
		|	ISNULL(LeadsContactInformation.Type, VALUE(Enum.ContactInformationTypes.EmptyRef)) AS Type,
		|	ISNULL(LeadsContactInformation.Kind, VALUE(Catalog.ContactInformationTypes.EmptyRef)) AS Kind,
		|	ISNULL(LeadsContactInformation.Presentation, """") AS Presentation,
		|	ISNULL(LeadsContactInformation.FieldValues, """") AS FieldValues
		|FROM
		|	Catalog.Leads.Contacts AS LeadsContacts
		|		LEFT JOIN Catalog.Leads.ContactInformation AS LeadsContactInformation
		|		ON LeadsContacts.Ref = LeadsContactInformation.Ref
		|			AND LeadsContacts.ContactLineIdentifier = LeadsContactInformation.ContactLineIdentifier
		|WHERE
		|	LeadsContacts.Ref = &Lead
		|
		|ORDER BY
		|	ContactLineIdentifier
		|TOTALS BY
		|	Representation";
	
	Query.SetParameter("Lead", Lead);
	DataCI = Query.Execute().Select();
	
	CurrentContact = Undefined;
	OwnerCI = Undefined;
	
	While DataCI.Next() Do
		
		If CurrentContact <> DataCI.Representation Then
			
			OwnerCI = DataCI.Representation;
			
			NewRow = ContactInformationPanelData.Add();
			NewRow.Representation	= DataCI.Representation;
			NewRow.IconIndex		= -1;
			NewRow.TypeShowingData	= "ContactPerson";
			NewRow.OwnerCI			= OwnerCI;
			
			CurrentContact = DataCI.Representation;
			
		EndIf;
		
		If Not ValueIsFilled(DataCI.Type) Then
			Continue;
		EndIf;
		
		NewRow	= ContactInformationPanelData.Add();
		Comment	= ContactInformationManagement.ContactInformationComment(DataCI.FieldValues);
		NewRow.Representation	= String(DataCI.Kind) + ": " + DataCI.Presentation + ?(IsBlankString(Comment), "", ", " + Comment);
		NewRow.IconIndex		= ContactInformationPanelDrive.IconIndexByType(DataCI.Type);
		NewRow.TypeShowingData	= "ValueCI";
		NewRow.OwnerCI			= OwnerCI;
		NewRow.PresentationCI	= DataCI.Presentation;
		
	EndDo;
	
EndProcedure

Procedure ChangeLeadActivity(Lead, Campaign, Activity) Export
	
	CurState = WorkWithLeads.LeadState(Lead.Ref);
	
	WorkWithLeads.WriteCurrentAcrivity(Lead.Ref, Campaign, CurState.SalesRep, Activity);
	
EndProcedure

Procedure ImportDataFromExternalSourceResultDataProcessor(ImportResult, Object = Undefined, CurrentForm = Undefined) Export
	
	BeginTransaction();

	Try
		
		DataMatchingTable 		= ImportResult.DataMatchingTable;
		UpdateExisting 			= ImportResult.DataLoadSettings.UpdateExisting;
		CreateIfNotMatched 		= ImportResult.DataLoadSettings.CreateIfNotMatched;
		FillingObjectFullName	= ImportResult.DataLoadSettings.FillingObjectFullName;
		
		For Each TableRow In DataMatchingTable Do
			
			ImportToApplicationIsPossible = TableRow[DataImportFromExternalSources.ServiceFieldNameImportToApplicationPossible()];
			
			If FillingObjectFullName = "Catalog.Leads" Then 
				
				CoordinatedStringStatus = (TableRow._RowMatched AND UpdateExisting) 
				OR (NOT TableRow._RowMatched AND CreateIfNotMatched);
				
				If ImportToApplicationIsPossible AND CoordinatedStringStatus Then
					
					If TableRow._RowMatched Then
						CatalogItem = TableRow.Leads.GetObject();
					Else
						CatalogItem = Catalogs.Leads.CreateItem();
					EndIf;
					
					CatalogItem.Description = TableRow.Description;
					FillPropertyValues(CatalogItem, TableRow);
					
					DescriptionByFistContact = Undefined;
					
					If Not IsBlankString(TableRow.Contact1)
						OR Not IsBlankString(TableRow.Phone1)
						OR Not IsBlankString(TableRow.Email1) Then
						
						AddContact(CatalogItem, TableRow.Contact1, TableRow.Phone1, TableRow.Email1);
						DescriptionByFistContact = True;
						
					EndIf;
					
					If Not IsBlankString(TableRow.Contact2)
						OR Not IsBlankString(TableRow.Phone2)
						OR Not IsBlankString(TableRow.Email2) Then
						
						AddContact(CatalogItem, TableRow.Contact2, TableRow.Phone2, TableRow.Email2);
						DescriptionByFistContact = ?(DescriptionByFistContact = Undefined, True, False);
						
					EndIf;
					
					If Not IsBlankString(TableRow.Contact3)
						OR Not IsBlankString(TableRow.Phone3)
						OR Not IsBlankString(TableRow.Email3) Then
						
						AddContact(CatalogItem, TableRow.Contact3, TableRow.Phone3, TableRow.Email3);
						DescriptionByFistContact = ?(DescriptionByFistContact = Undefined, True, False);
						
					EndIf;
					
					If DescriptionByFistContact AND IsBlankString(CatalogItem.Contacts[0].Representation) Then
						
						CatalogItem.Contacts[0].Representation = CatalogItem.Description;
						
					EndIf;
					
					If ImportResult.DataLoadSettings.SelectedAdditionalAttributes.Count() > 0 Then
						DataImportFromExternalSources.ProcessSelectedAdditionalAttributes(
								CatalogItem,
								TableRow._RowMatched,
								TableRow,
								ImportResult.DataLoadSettings.SelectedAdditionalAttributes);
					EndIf;
					
					CatalogItem.Write();
					
				EndIf;
				
			EndIf;
		EndDo;
		
		CommitTransaction();
		
	Except
		
		RollbackTransaction();
		
		WriteLogEvent(
			NStr("en = 'Data Import'", CommonUseClientServer.MainLanguageCode()),
			EventLogLevel.Error,
			Metadata.Catalogs.Products,
			,
			ErrorDescription());
			
	EndTry;
	
EndProcedure

// Function returns the list of the "key" attributes names.
// For working "Import data" processor
Function GetObjectAttributesBeingLocked() Export
	
	Result = New Array;
	
	Return Result;
	
EndFunction

#EndRegion

#Region Private

Function CreateCounterpartyAndContactPersons(Lead)
	
	NewCounterparty = Catalogs.Counterparties.CreateItem();
	NewCounterparty.Fill(Undefined);
	
	NewCounterparty.Description = Lead.Description;
	NewCounterparty.DescriptionFull = NewCounterparty.Description;
	NewCounterparty.CustomerAcquisitionChannel = Lead.AcquisitionChannel;
	NewCounterparty.Comment = Lead.Note;
	NewCounterparty.Customer = True;
	
	LeadActivities = InformationRegisters.LeadActivities.LeadActivitiesAtDate(Lead.Ref);
	NewCounterparty.SalesRep = LeadActivities.SalesRep;
	
	NewCounterparty.Tags.Load(Lead.Tags.Unload(, "Tag"));
	
	NewCounterparty.Write();
	
	For Each Contact In Lead.Contacts Do
		
		NewContact = Catalogs.ContactPersons.CreateItem();
		NewContact.Owner = NewCounterparty.Ref;
		NewContact.Description = Contact.Representation;
		NewContact.Fill(Undefined);
		
		ContactContactData = Lead.ContactInformation.FindRows(New Structure("ContactLineIdentifier", Contact.ContactLineIdentifier));
		For Each ContactData In ContactContactData Do
			
			If ContactData.Type = Enums.ContactInformationTypes.EmailAddress Then
				CIKind = Catalogs.ContactInformationTypes.ContactPersonEmail;
			ElsIf ContactData.Type = Enums.ContactInformationTypes.Phone Then
				CIKind = Catalogs.ContactInformationTypes.ContactPersonPhone;
			ElsIf ContactData.Type = Enums.ContactInformationTypes.Other Then
				CIKind = Catalogs.ContactInformationTypes.ContactPersonMessenger;
			ElsIf ContactData.Type = Enums.ContactInformationTypes.Skype Then
				CIKind = Catalogs.ContactInformationTypes.ContactPersonSkype;
			ElsIf ContactData.Type = Enums.ContactInformationTypes.WebPage Then
				CIKind = Catalogs.ContactInformationTypes.ContactPersonSocialNetwork;
			Else
				CIKind = CIKind(ContactData.Type);
			EndIf;
			
			If CIKind = Undefined Then
				Continue;
			EndIf;
			
			CIValue = ?(ValueIsFilled(ContactData.FieldValues), ContactData.FieldValues, ContactData.Presentation);
			
			ContactInformationManagement.WriteContactInformation(NewContact, CIValue, CIKind, ContactData.Type);
			
		EndDo;
		
		NewContact.Write();
		
	EndDo;
	
	Return NewCounterparty.Ref;
	
EndFunction

Function CIKind(CIType)
	
	Query = New Query;
	Query.Text = 
		"SELECT TOP 1
		|	ContactInformationTypes.Ref AS Ref
		|FROM
		|	Catalog.ContactInformationTypes AS ContactInformationTypes
		|WHERE
		|	ContactInformationTypes.Type = &CIType
		|	AND ContactInformationTypes.Parent = VALUE(Catalog.ContactInformationTypes.CatalogContactPersons)";
	
	Query.SetParameter("CIType", CIType);
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	If SelectionDetailRecords.Next() Then
		Return SelectionDetailRecords.Ref;
	Else
		Return Undefined;
	EndIf;
	
EndFunction

Procedure AddMessageAboutMissingData(ContactInformationPanelData)
	
	NewRow = ContactInformationPanelData.Add();
	NewRow.Representation	= NStr("en = '<No contact data>'");
	NewRow.IconIndex		= -1;
	NewRow.TypeShowingData	= "NoData";
	NewRow.OwnerCI			= Undefined;
	
EndProcedure

Procedure AddContact(CatalogItem, ContactRepresentation, ContactsPhone, ContactEmail)
	
	ContactLineIdentifier = 0;
	If CatalogItem.Contacts.Count() > 0 Then
		
		ContactLineIdentifier = CatalogItem.Contacts[CatalogItem.Contacts.Count() - 1].ContactLineIdentifier + 1;
		
	EndIf;
	
	NewContact = CatalogItem.Contacts.Add();
	NewContact.Representation = ContactRepresentation;
	NewContact.ContactLineIdentifier = ContactLineIdentifier;
	
	ContactInformationManagement.WriteContactInformation(
		CatalogItem,
		ContactsPhone,
		Catalogs.ContactInformationTypes.LeadPhone,
		Enums.ContactInformationTypes.Phone,
		ContactLineIdentifier);
		
	ContactInformationManagement.WriteContactInformation(
		CatalogItem,
		ContactEmail,
		Catalogs.ContactInformationTypes.LeadEmail,
		Enums.ContactInformationTypes.EmailAddress,
		ContactLineIdentifier);
	
EndProcedure

#EndRegion

#EndIf