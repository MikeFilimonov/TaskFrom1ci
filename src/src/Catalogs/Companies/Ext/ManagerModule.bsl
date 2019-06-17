#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ProgramInterface

////////////////////////////////////////////////////////////////////////////////
// Objects bulk edit.

// Returns the list of attributes
// excluded from the scope of the batch object modification.
//
Function NotEditableInGroupProcessingAttributes() Export
	
	Result = New Array;
	
	Result.Add("Prefix");
	Result.Add("ContactInformation.*");
	
	Return Result
EndFunction

#Region UseSeveralCompanies

// Returns company by default.
// If there is only one company in the IB which is not marked for
// deletion and is not predetermined, then a ref to this company will be returned, otherwise an empty ref will be returned.
//
// Returns:
//     CatalogRef.Companies - ref to the company.
//
Function CompanyByDefault() Export
	
	Company = Catalogs.Companies.EmptyRef();
	
	SubsidaryCompany = Constants.ParentCompany.Get();
	MainCompanyUserSetting = DriveReUse.GetValueByDefaultUser(Users.AuthorizedUser(), "MainCompany");
	If ValueIsFilled(SubsidaryCompany) Then
		
		Company = SubsidaryCompany;
		
	ElsIf ValueIsFilled(MainCompanyUserSetting) Then
		
		Company = MainCompanyUserSetting;
		
	Else
		
		Query = New Query;
		Query.Text =
		"SELECT ALLOWED TOP 2
		|	Companies.Ref AS Company
		|FROM
		|	Catalog.Companies AS Companies
		|WHERE
		|	NOT Companies.DeletionMark";
		
		Selection = Query.Execute().Select();
		If Selection.Next() AND Selection.Count() = 1 Then
			Company = Selection.Company;
		EndIf;
		
	EndIf;
	
	Return Company;

EndFunction

// Returns quantity of the Companies catalog items.
// Does not consider items that are predefined and marked for deletion.
//
// Returns:
//     Number - companies quantity.
//
Function CompaniesCount() Export
	
	SetPrivilegedMode(True);
	
	Quantity = 0;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	COUNT(*) AS Quantity
	|FROM
	|	Catalog.Companies AS Companies
	|WHERE
	|	NOT Companies.Predefined";
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		Quantity = Selection.Quantity;
	EndIf;
	
	SetPrivilegedMode(False);
	
	Return Quantity;
	
EndFunction

// Fills in the list of printing commands.
// 
// Parameters:
//   PrintCommands - ValueTable - see fields' content in the PrintManagement.CreatePrintCommandsCollection function.
//
Procedure AddPrintCommands(PrintCommands) Export
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID				= "CompanyAttributes";
	PrintCommand.Presentation	= NStr("en = 'Attributes'");
	PrintCommand.FormsList		= "ItemForm,ListForm";
	PrintCommand.FormTitle		= NStr("en = 'Print company attributes'");
	PrintCommand.Order			= 1;
	
EndProcedure

// Method returns all companies
Function AllCompanies() Export
	
	Query = New Query("
	|SELECT ALLOWED
	|	Company.Ref AS Company
	|FROM
	|	Catalog.Companies AS Company");
	
	Result = Query.Execute().Unload();
	
	Return Result.UnloadColumn("Company");
EndFunction

#EndRegion

#EndRegion

#Region ServiceProgramInterface

// It is called while transferring to SSL version 2.2.1.12.
//
Procedure FillConstantUseSeveralCompanies() Export
	
	If GetFunctionalOption("UseSeveralCompanies") =
			GetFunctionalOption("UseOneCompany") Then
		// Options should have the opposite values.
		// If it is not true, then there were no such options in IB - initialize their values.
		Constants.UseSeveralCompanies.Set(CompaniesCount() > 1);
	EndIf;
	
EndProcedure

// Printing template generation procedure
//
Function GenerateFaxPrintJobAssistant(CompaniesArray, PrintObjects, TemplateName)
	
	SpreadsheetDocument	= New SpreadsheetDocument;
	Template				= PrintManagement.GetTemplate("Catalog.Companies." + TemplateName);
	
	For Each Company In CompaniesArray Do 
	
		SpreadsheetDocument.Put(Template.GetArea("FieldsRequired"));
		SpreadsheetDocument.Put(Template.GetArea("Line"));
		SpreadsheetDocument.Put(Template.GetArea("Schema"));
		
		PrintManagement.SetDocumentPrintArea(SpreadsheetDocument, 1, PrintObjects, Company);
	
	EndDo;
	
	SpreadsheetDocument.FitToPage = True;
	
	Return SpreadsheetDocument;

EndFunction

// Procedure of generating preliminary document printing form (sample)
//
// It is called from the "Company" card to view logos placing
//
Function PreviewPrintedFormProformaInvoice(ObjectsArray, PrintObjects, TemplateName) Export
	
	Var Errors;
	
	UseVAT	= GetFunctionalOption("UseVAT");
	
	Company = ObjectsArray[0];
	
	SpreadsheetDocument = New SpreadsheetDocument;
	
	DateValue = CurrentSessionDate();
	
	Header = New Structure;
	Header.Insert("Ref",				Company);
	Header.Insert("AmountIncludesVAT",	False);
	Header.Insert("DocumentCurrency",	Constants.FunctionalCurrency.Get());
	Header.Insert("Currency",			Constants.FunctionalCurrency.Get());
	Header.Insert("DocumentDate",		DateValue);
	Header.Insert("DocumentNumber",		"00000000001");
	Header.Insert("Company",			Company);
	Header.Insert("BankAccount",		Company.BankAccountByDefault);
	Header.Insert("Prefix",				Company.Prefix);
	Header.Insert("CompanyLogoFile",	Company.LogoFile);
	Header.Insert("Counterparty",		NStr("en = 'Field contains customer information: legal name, TIN, legal address, phones.'"));
	
	Inventory = New Structure;
	Inventory.Insert("LineNumber",				1);
	Inventory.Insert("ProductDescription",		NStr("en = 'Inventory for preview'"));
	Inventory.Insert("SKU",						NStr("en = 'SKU-0000001'"));
	Inventory.Insert("UnitOfMeasure",			Catalogs.UOMClassifier.pcs);
	Inventory.Insert("Quantity",				1);
	Inventory.Insert("Price",					100);
	Inventory.Insert("Amount",					100);
	Inventory.Insert("TotalVAT",				18);
	Inventory.Insert("Total",					118);
	Inventory.Insert("VATAmount",				NStr("en = 'VAT amount'"));
	Inventory.Insert("Characteristic",			Catalogs.ProductsCharacteristics.EmptyRef());
	Inventory.Insert("DiscountMarkupPercent",	0);
	
	FirstLineNumber = SpreadsheetDocument.TableHeight + 1;
	
	SpreadsheetDocument.PrintParametersName = "PARAMETERS_PRINT_PF_MXL_Quote";
	
	Template = PrintManagement.PrintedFormsTemplate("DataProcessor.PrintQuote.PF_MXL_Quote");
	
	#Region PrintQuoteTitleArea
	
	TitleArea = Template.GetArea("Title");
	TitleArea.Parameters.Fill(Header);
	
	If ValueIsFilled(Header.CompanyLogoFile) Then
		
		PictureData = AttachedFiles.GetFileBinaryData(Header.CompanyLogoFile);
		If ValueIsFilled(PictureData) Then
			
			TitleArea.Drawings.Logo.Picture = New Picture(PictureData);
			
		EndIf;
		
	Else
		
		TitleArea.Drawings.Delete(TitleArea.Drawings.Logo);
		
	EndIf;
	
	SpreadsheetDocument.Put(TitleArea);
	
	#EndRegion
	
	#Region PrintQuoteCompanyInfoArea
	
	CompanyInfoArea = Template.GetArea("CompanyInfo");
	
	InfoAboutCompany = DriveServer.InfoAboutLegalEntityIndividual(Header.Company, Header.DocumentDate, ,Header.BankAccount);
	CompanyInfoArea.Parameters.Fill(InfoAboutCompany);
	
	SpreadsheetDocument.Put(CompanyInfoArea);
	
	#EndRegion
	
	#Region PrintQuoteCounterpartyInfoArea
	
	CounterpartyInfoArea = Template.GetArea("CounterpartyInfo");
	CounterpartyInfoArea.Parameters.Fill(Header);
	
	SpreadsheetDocument.Put(CounterpartyInfoArea);
	
	#EndRegion
	
	#Region PrintQuoteCommentArea
	
	CommentArea = Template.GetArea("Comment");
	CommentArea.Parameters.TermsAndConditions = "";
	
	SpreadsheetDocument.Put(CommentArea);
	
	#EndRegion
	
	#Region PrintQuoteTotalsAreaPrefill
	
	TotalsAreasArray = New Array;
	
	LineTotalArea = Template.GetArea("LineTotal");
	LineTotalArea.Parameters.Fill(Header);
	
	TotalsAreasArray.Add(LineTotalArea);
	
	#EndRegion
	
	#Region PrintQuoteLinesArea
	
	LineHeaderArea = Template.GetArea("LineHeader");
	SpreadsheetDocument.Put(LineHeaderArea);
	
	LineSectionArea	= Template.GetArea("LineSection");
	SeeNextPageArea	= Template.GetArea("SeeNextPage");
	EmptyLineArea	= Template.GetArea("EmptyLine");
	PageNumberArea	= Template.GetArea("PageNumber");
	
	PageNumber = 0;
	
	TabSelection = Inventory;
	
	LineSectionArea.Parameters.Fill(TabSelection);
	
	AreasToBeChecked = New Array;
	AreasToBeChecked.Add(LineSectionArea);
	For Each Area In TotalsAreasArray Do
		AreasToBeChecked.Add(Area);
	EndDo;
	AreasToBeChecked.Add(PageNumberArea);
	
	If CommonUse.SpreadsheetDocumentFitsPage(SpreadsheetDocument, AreasToBeChecked) Then
		
		SpreadsheetDocument.Put(LineSectionArea);
		
	Else
		
		SpreadsheetDocument.Put(SeeNextPageArea);
		
		AreasToBeChecked.Clear();
		AreasToBeChecked.Add(EmptyLineArea);
		AreasToBeChecked.Add(PageNumberArea);
		
		For i = 1 To 50 Do
			
			If Not CommonUse.SpreadsheetDocumentFitsPage(SpreadsheetDocument, AreasToBeChecked)
				Or i = 50 Then
				
				PageNumber = PageNumber + 1;
				PageNumberArea.Parameters.PageNumber = PageNumber;
				SpreadsheetDocument.Put(PageNumberArea);
				Break;
				
			Else
				
				SpreadsheetDocument.Put(EmptyLineArea);
				
			EndIf;
			
		EndDo;
		
		SpreadsheetDocument.PutHorizontalPageBreak();
		SpreadsheetDocument.Put(TitleArea);
		SpreadsheetDocument.Put(LineHeaderArea);
		SpreadsheetDocument.Put(LineSectionArea);
		
	EndIf;
	
	#EndRegion
	
	#Region PrintQuoteTotalsArea
	
	For Each Area In TotalsAreasArray Do
		
		SpreadsheetDocument.Put(Area);
		
	EndDo;
	
	AreasToBeChecked.Clear();
	AreasToBeChecked.Add(EmptyLineArea);
	AreasToBeChecked.Add(PageNumberArea);
	
	For i = 1 To 50 Do
		
		If Not CommonUse.SpreadsheetDocumentFitsPage(SpreadsheetDocument, AreasToBeChecked)
			Or i = 50 Then
			
			PageNumber = PageNumber + 1;
			PageNumberArea.Parameters.PageNumber = PageNumber;
			SpreadsheetDocument.Put(PageNumberArea);
			Break;
			
		Else
			
			SpreadsheetDocument.Put(EmptyLineArea);
			
		EndIf;
		
	EndDo;
	
	#EndRegion
	
	PrintManagement.SetDocumentPrintArea(SpreadsheetDocument, FirstLineNumber, PrintObjects, Header.Ref);
	
	CommonUseClientServer.ShowErrorsToUser(Errors);
	
	SpreadsheetDocument.FitToPage = True;
	
	Return SpreadsheetDocument;
	
EndFunction

// The procedure for the formation of a spreadsheet document with details of companies
//
Function PrintCompanyCard(ObjectsArray, PrintObjects)
	
	SpreadsheetDocument = New SpreadsheetDocument;
	Template = PrintManagement.PrintedFormsTemplate("Catalog.Companies.CompanyAttributes");
	Separator = Template.GetArea("Separator");
	
	CurrentDate		= CurrentSessionDate();
	FirstDocument	= True;
	
	For Each Company In ObjectsArray Do
	
		If Not FirstDocument Then
			SpreadsheetDocument.Put(Separator);
			SpreadsheetDocument.PutHorizontalPageBreak();
		EndIf;
		
		FirstDocument	= False;
		RowNumberBegin	= SpreadsheetDocument.TableHeight + 1;
		IsLegalEntity	= Company.LegalEntityIndividual = Enums.CounterpartyType.LegalEntity;
		
		InfoAboutCompany = DriveServer.InfoAboutLegalEntityIndividual(Company, CurrentDate);
		
		Area = Template.GetArea("Description");
		Area.Parameters.DescriptionFull = InfoAboutCompany.FullDescr;
		SpreadsheetDocument.Put(Area);
		
		If ValueIsFilled(InfoAboutCompany.TIN) Then
			Area = Template.GetArea("TIN");
			Area.Parameters.TIN = InfoAboutCompany.TIN;
			SpreadsheetDocument.Put(Area);
		EndIf;
		
		If ValueIsFilled(InfoAboutCompany.RegistrationNumber) Then
			Area = Template.GetArea("RegistrationNumber");
			Area.Parameters.RegistrationNumber = InfoAboutCompany.RegistrationNumber;
			SpreadsheetDocument.Put(Area);
		EndIf;
		
		If ValueIsFilled(InfoAboutCompany.SWIFT)
			AND ValueIsFilled(InfoAboutCompany.Bank)
			AND (ValueIsFilled(InfoAboutCompany.AccountNo)
				OR ValueIsFilled(InfoAboutCompany.IBAN)) Then
			
			Area = Template.GetArea("BankAccount");
			Area.Parameters.AccountNo	= InfoAboutCompany.AccountNo;
			Area.Parameters.IBAN		= InfoAboutCompany.IBAN;
			Area.Parameters.SWIFT		= InfoAboutCompany.SWIFT;
			Area.Parameters.Bank		= InfoAboutCompany.Bank;
			SpreadsheetDocument.Put(Area);
			
		EndIf;
		
		If ValueIsFilled(InfoAboutCompany.LegalAddress) 
			Or ValueIsFilled(InfoAboutCompany.PhoneNumbers) Then
			SpreadsheetDocument.Put(Separator);
		EndIf;
		
		If IsLegalEntity AND ValueIsFilled(InfoAboutCompany.LegalAddress) Then
			Area = Template.GetArea("LegalAddress");
			Area.Parameters.LegalAddress	= InfoAboutCompany.LegalAddress;
			SpreadsheetDocument.Put(Area);
		EndIf;
			
		If Not IsLegalEntity AND ValueIsFilled(InfoAboutCompany.LegalAddress) Then
			Area = Template.GetArea("IndividualAddress");
			Area.Parameters.IndividualAddress	= InfoAboutCompany.LegalAddress;
			SpreadsheetDocument.Put(Area);
		EndIf;
			
		If ValueIsFilled(InfoAboutCompany.PhoneNumbers) Then
			Area = Template.GetArea("Phone");
			Area.Parameters.Phone = InfoAboutCompany.PhoneNumbers;
			SpreadsheetDocument.Put(Area);
		EndIf;
		
		PrintManagement.SetDocumentPrintArea(SpreadsheetDocument, RowNumberBegin, PrintObjects, Company);
		
	EndDo;
	
	SpreadsheetDocument.TopMargin		= 20;
	SpreadsheetDocument.BottomMargin	= 20;
	SpreadsheetDocument.LeftMargin		= 20;
	SpreadsheetDocument.RightMargin		= 20;
	
	SpreadsheetDocument.PageOrientation	= PageOrientation.Portrait;
	SpreadsheetDocument.FitToPage		= True;
	
	SpreadsheetDocument.PrintParametersKey = "PrintParameters__Company_CompanyCard";
	
	Return SpreadsheetDocument;

EndFunction

// Generate printed forms of objects
//
// Incoming:
//   TemplateNames    - String    - Names of templates separated
//   by commas ObjectsArray  - Array    - Array of refs to objects that
//   need to be printed PrintParameters - Structure - Structure of additional printing parameters
//
// Outgoing:
//   PrintFormsCollection - Values table - Generated
//   table documents OutputParameters       - Structure        - Parameters of generated table documents
//
Procedure Print(ObjectsArray,
				 PrintParameters,
				 PrintFormsCollection,
				 PrintObjects,
				 OutputParameters) Export
	
	If PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "CompanyAttributes") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(
			PrintFormsCollection,
			"CompanyAttributes",
			NStr("en = 'Company details'"),
			PrintCompanyCard(ObjectsArray, PrintObjects));
		
	EndIf;
	
	If PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "PrintFaxPrintWorkAssistant") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection, "PrintFaxPrintWorkAssistant", "How can I quickly and easily create fax signature and printing?", GenerateFaxPrintJobAssistant(ObjectsArray, PrintObjects, "AssistantWorkFaxPrint"));
		
	EndIf;
	
	If PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "PreviewPrintedFormProformaInvoice") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection, "PreviewPrintedFormProformaInvoice", "Quote", PreviewPrintedFormProformaInvoice(ObjectsArray, PrintObjects, "ProformaInvoice"));
		
	EndIf;
	
	
EndProcedure

#EndRegion

#EndIf
