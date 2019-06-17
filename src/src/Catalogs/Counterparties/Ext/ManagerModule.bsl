#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions

// Returns query text for printing price list (price group)
//
Function GetQueryTextForPrintingPriceListPriceGroup()
	
	Return 
	"SELECT
	|	CASE
	|		WHEN &OutputCode = VALUE(Enum.YesNo.Yes)
	|			THEN PricesSliceLast.Products.Code
	|		ELSE PricesSliceLast.Products.SKU
	|	END AS SKUCode,
	|	CASE
	|		WHEN &OutputFullDescr = VALUE(Enum.YesNo.Yes)
	|			THEN PricesSliceLast.Products.DescriptionFull
	|		ELSE PricesSliceLast.Products.Description
	|	END AS PresentationOfProducts,
	|	PricesSliceLast.Products AS Products,
	|	PricesSliceLast.Characteristic AS Characteristic,
	|	PricesSliceLast.MeasurementUnit AS MeasurementUnit,
	|	PricesSliceLast.Price AS Price,
	|	PricesSliceLast.Products.PriceGroup AS PriceGroup
	|FROM
	|	InformationRegister.Prices.SliceLast(
	|			&Period,
	|			Actuality
	|				AND PriceKind = &PriceKind) AS PricesSliceLast
	|
	|ORDER BY
	|	PricesSliceLast.Products.Description,
	|	Characteristic,
	|	SKUCode
	|TOTALS BY
	|	PriceGroup";
	
EndFunction

// Returns query text for printing price list (products hierarchy)
//
Function GetQueryTextForPrintingPriceListProductsHierarchy()
	
	Return 
	"SELECT
	|	CatalogProducts.Ref AS Products,
	|	CASE
	|		WHEN &OutputCode = VALUE(Enum.YesNo.Yes)
	|			THEN CatalogProducts.Code
	|		ELSE CatalogProducts.SKU
	|	END AS SKUCode,
	|	CASE
	|		WHEN &OutputFullDescr = VALUE(Enum.YesNo.Yes)
	|			THEN CatalogProducts.DescriptionFull
	|		ELSE CatalogProducts.Description
	|	END AS PresentationOfProducts,
	|	CatalogProducts.Parent AS Parent,
	|	CatalogProducts.IsFolder AS IsFolder,
	|	PricesSliceLast.Characteristic AS Characteristic,
	|	PricesSliceLast.MeasurementUnit AS MeasurementUnit,
	|	PricesSliceLast.Price AS Price
	|FROM
	|	Catalog.Products AS CatalogProducts
	|		Full JOIN InformationRegister.Prices.SliceLast(
	|				&Period,
	|				Actuality
	|					AND PriceKind = &PriceKind) AS PricesSliceLast
	|		ON CatalogProducts.Ref = PricesSliceLast.Products
	|
	|ORDER BY
	|	CatalogProducts.Ref HIERARCHY,
	|	PricesSliceLast.Products.Description,
	|	Characteristic,
	|	SKUCode";
	
EndFunction

// Returns the list of
// attributes allowed to be changed with the help of the group change data processor.
//
Function EditedAttributesInGroupDataProcessing() Export
	
	EditableAttributes = New Array;
	
	EditableAttributes.Add("AccessGroup");
	EditableAttributes.Add("CreationDate");
	EditableAttributes.Add("Customer");
	EditableAttributes.Add("Supplier");
	EditableAttributes.Add("OtherRelationship");
	EditableAttributes.Add("Responsible");
	EditableAttributes.Add("CustomerAcquisitionChannel");
	EditableAttributes.Add("GLAccountCustomerSettlements");
	EditableAttributes.Add("CustomerAdvancesGLAccount");
	EditableAttributes.Add("GLAccountVendorSettlements");
	EditableAttributes.Add("VendorAdvancesGLAccount");
	EditableAttributes.Add("SalesRep");
	
	Return EditableAttributes;
	
EndFunction

// Function receives selling price main kind from the user settings.
//
Function GetMainKindOfSalePrices() Export
	
	PriceTypesales = DriveReUse.GetValueByDefaultUser(UsersClientServer.AuthorizedUser(), "MainPriceTypesales");
	
	Return ?(ValueIsFilled(PriceTypesales), PriceTypesales, Catalogs.PriceTypes.Wholesale);
	
EndFunction

// Function receives default selling prices kind for the specified counterparty.
//
// Price receipt method:
// 1. Counterparty -> Main contract -> Prices kind;
// 2. User settings -> Selling prices main kind;
// 3. Predefined prices kind: Producer price;
//	
Function GetDefaultPriceKind(Counterparty) Export
	
	If ValueIsFilled(Counterparty) 
		AND ValueIsFilled(Counterparty.ContractByDefault)
		AND ValueIsFilled(Counterparty.ContractByDefault.PriceKind) Then
		
		Return Counterparty.ContractByDefault.PriceKind;
		
	Else
		
		Return GetMainKindOfSalePrices();
		
	EndIf;
	
EndFunction

// Function receives company for the specified counterparty.
//
// Company receipt method:
// 1. Counterparty -> Main contract -> Company; (if on. data
// synchronization) 2. User settings -> Main company;
// 3. Predefined item: Main company;
//
Function GetDefaultCompany(Counterparty)
	
	If GetFunctionalOption("UseDataSync")
		AND ValueIsFilled(Counterparty) 
		AND ValueIsFilled(Counterparty.ContractByDefault)
		AND ValueIsFilled(Counterparty.ContractByDefault.Company) Then
		
		Return Counterparty.ContractByDefault.Company;
		
	Else
		
		MainCompany = DriveReUse.GetValueByDefaultUser(UsersClientServer.AuthorizedUser(), "MainCompany");
		
		Return ?(ValueIsFilled(MainCompany), MainCompany, Catalogs.Companies.MainCompany);
		
	EndIf;

	
EndFunction

// Function returns the list of the "key" attributes names.
//
Function GetObjectAttributesBeingLocked() Export
	
	Result = New Array;
	
	Return Result;
	
EndFunction

#EndRegion

#Region CheckingDuplicates

// Function determines whether there are duplicates in counterparty.
// TIN - Checked counterparty TIN, Type - String(12)
// Ref - Checked counterparty itself, Type - CatalogRef.Counterparties
Function CheckCatalogDuplicatesCounterpartiesByTIN(Val TIN, ExcludingRef = Undefined, CheckOnWrite = False) Export
	
	Duplicates = New Array;
	
	Query = New Query;
	// If you write item, then check for
	// duplicates in register. Operation is executed only if there
	// is BeforeWrite object event IN the interactive
	// duplicates check it is not applied as exclusive locks are set to the register.
	If CheckOnWrite Then
		Duplicates = HasRecordsInDuplicatesRegister(TIN, ExcludingRef);
	EndIf;
	
	// If nothing is found in the duplicates register while writing item or while online check, execute duplicates search
	// by the Counterparties catalog
	If Duplicates.Count() = 0 Then
		
		Query.Text = 	"SELECT
		               	|	Counterparties.Ref
		               	|FROM
		               	|	Catalog.Counterparties AS Counterparties
		               	|WHERE
		               	|	NOT Counterparties.IsFolder
		               	|	AND NOT Counterparties.Ref = &Ref
		               	|	AND Counterparties.TIN = &TIN";
		
		Query.SetParameter("TIN", TrimAll(TIN));
		Query.SetParameter("Ref", ExcludingRef);
		
		DuplicatesSelection = Query.Execute().Select();
		
		While DuplicatesSelection.Next() Do
			Duplicates.Add(DuplicatesSelection.Ref);
		EndDo;
		
	EndIf;
	
	Return Duplicates;
	
EndFunction

// Procedure returns duplicates array by records in the register
// Contractor duplicates availability Input receives input VAT and reference to the counterparty
Function HasRecordsInDuplicatesRegister(TIN, ExcludingRef = Undefined) Export
	
	Duplicates = New Array;
	
	Query = New Query;
	
	Query.SetParameter("Ref", ExcludingRef);
	Query.SetParameter("TIN", TrimAll(TIN));
	
	Query.Text = 
	"SELECT
	|	CounterpartyDuplicates.Counterparty AS Ref
	|FROM
	|	InformationRegister.CounterpartyDuplicates AS CounterpartyDuplicates
	|WHERE
	|	NOT CounterpartyDuplicates.Counterparty = &Ref
	|	AND CounterpartyDuplicates.TIN = &TIN";
	
	QueryResult = Query.Execute();
	
	DuplicatesSelection = QueryResult.Select();
	
	While DuplicatesSelection.Next() Do
		Duplicates.Add(DuplicatesSelection.Ref);
	EndDo;
	
	Return Duplicates;
	
EndFunction

// Procedure moves in the
// Ref duplicates register - ref to item of
// the CounterpartyByTIN catalog - Written counterparty
// TIN - ShouldBeDeleted
Procedure ExecuteRegisterRecordsOnRegisterTakes(Ref, TIN = "", NeedToDelete) Export
	
	RecordManager = InformationRegisters.CounterpartyDuplicates.CreateRecordManager();
	
	RecordManager.Counterparty = Ref;
	RecordManager.TIN        = TIN;
	
	RecordManager.Read();
	
	WriteExist = RecordManager.Selected();
	
	If NeedToDelete AND WriteExist Then
		RecordManager.Delete();
	ElsIf Not NeedToDelete AND Not WriteExist Then
		
		RecordManager.Counterparty = Ref;
		RecordManager.TIN        = TIN;
		
		RecordManager.Active = True;
		RecordManager.Write(True);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region PrintInterface

Procedure FillAreaParameters(AreaName, ParameterValues, PrintingStructure, OutputLogo = False)
	
	Var AreaProducts, AreaCharacteristic, AreaPrice;
	
	PrintingStructure.AreaStructure.Property("Area" + AreaName + "Products",		AreaProducts);
	PrintingStructure.AreaStructure.Property("Area" + AreaName + "Characteristic",	AreaCharacteristic);
	PrintingStructure.AreaStructure.Property("Area" + AreaName + "Price",				AreaPrice);
	
	AreaProducts.Parameters.Fill(ParameterValues);
	
	If OutputLogo Then
		
		AreaProducts.Drawings.Logo.Picture = ParameterValues.Picture;
		
	EndIf;
	
	PrintingStructure.SpreadsheetDocument.Put(AreaProducts);
	
	If PrintingStructure.UseCharacteristics Then
		
		AreaCharacteristic.Parameters.Fill(ParameterValues);
		PrintingStructure.SpreadsheetDocument.Join(AreaCharacteristic);
		
	EndIf;
	
	AreaPrice.Parameters.Fill(ParameterValues);
	PrintingStructure.SpreadsheetDocument.Join(AreaPrice);
	
EndProcedure

Procedure FillPriceListTitle(AreaName, PrintingStructure)
	
	ParameterValues = New Structure;
	ParameterValues.Insert("Title", "Price list");
	
	FillAreaParameters(AreaName, ParameterValues, PrintingStructure);
	
EndProcedure

Procedure FillPriceListSender(PrintingStructure)
	
	CompanyByDefault = GetDefaultCompany(PrintingStructure.Counterparty);
	
	InfoAboutSender = DriveServer.InfoAboutLegalEntityIndividual(CompanyByDefault, CurrentSessionDate());
	
	ParameterValues = 
		New Structure("Sender, SenderAddress, SenderPhone, SenderFax, SenderEmail",
			InfoAboutSender.Presentation,
			InfoAboutSender.ActualAddress,
			InfoAboutSender.PhoneNumbers,
			InfoAboutSender.Fax,
			InfoAboutSender.Email
			);
			
	OutputLogo = False;
	AreaName 		= "SenderWithoutLogo";
	
	If ValueIsFilled(CompanyByDefault.LogoFile) Then
		
		PictureData = AttachedFiles.GetFileBinaryData(CompanyByDefault.LogoFile);
		If ValueIsFilled(PictureData) Then
			
			OutputLogo = True;
			AreaName		= "SenderWithLogo";
			ParameterValues.Insert("Picture", New Picture(PictureData));
			
		EndIf;
		
	EndIf;
	
	FillAreaParameters(AreaName, ParameterValues, PrintingStructure, OutputLogo);
	
EndProcedure

Procedure FillFormedPriceList(AreaName, PrintingStructure)
	
	ParameterValues = New Structure("Formed", "Formed" + " " + Format(CurrentSessionDate(),"DLF=D"));
	
	FillAreaParameters(AreaName, ParameterValues, PrintingStructure);
	
EndProcedure

Procedure FillPriceListHeader(AreaName, PrintingStructure)
	
	PriceKind = GetDefaultPriceKind(PrintingStructure.Counterparty);
	
	ParameterValues = 
		New Structure("SKUCode, PricesKind, Price",
			?(Constants.DisplayItemNumberInThePriceList.Get() = Enums.YesNo.Yes, "Code", "SKU"),
			PriceKind,
			"Price (" + PriceKind.PriceCurrency + ")"
			);
	
	FillAreaParameters(AreaName, ParameterValues, PrintingStructure);
	
EndProcedure

Procedure FillPriceListDetailsPriceGroup(PrintingStructure)
	
	Query = New Query(GetQueryTextForPrintingPriceListPriceGroup());
	Query.SetParameter("Period", CurrentSessionDate());
	Query.SetParameter("PriceKind", GetDefaultPriceKind(PrintingStructure.Counterparty));
	Query.SetParameter("OutputCode", Constants.DisplayItemNumberInThePriceList.Get());
	Query.SetParameter("OutputFullDescr", Constants.DisplayDetailedDescriptionInThePriceList.Get());
	
	ParameterValues = 
		New Structure("PriceGroup, SKUCode, PresentationOfProducts, Products, Characteristic, MeasurementUnit, Price");
	
	SelectionPriceGroups = Query.Execute().Select(QueryResultIteration.ByGroupsWithHierarchy);
	While SelectionPriceGroups.Next() Do
		
		FillPropertyValues(ParameterValues, SelectionPriceGroups);
		FillAreaParameters("PriceGroup", ParameterValues, PrintingStructure);
		
		SelectionDetails = SelectionPriceGroups.Select();
		While SelectionDetails.Next() Do
			
			FillPropertyValues(ParameterValues, SelectionDetails);
			FillAreaParameters("Details", ParameterValues, PrintingStructure);
			
		EndDo;
		
	EndDo;
	
EndProcedure

Procedure FillPriceListDetailsProductsHierarchy(PrintingStructure, Selection, OutputProductsWithoutParent = False)
	
	ParameterValues = 
		New Structure("PriceGroup, SKUCode, PresentationOfProducts, Products, Characteristic, MeasurementUnit, Price");
	
	If OutputProductsWithoutParent Then
		
		ParameterValues.PriceGroup = NStr("en = '<...>'");
		FillAreaParameters("PriceGroup", ParameterValues, PrintingStructure);
		OutputEmptyParent = False;
		PrintingStructure.SpreadsheetDocument.StartRowGroup();
		
	EndIf;
	
	While Selection.Next() Do
		
		// Difficult conditions in the "If" operator are required for products to be output without parent to the price list
		If Selection.IsFolder 
			AND Not OutputProductsWithoutParent Then
			
			ParameterValues.PriceGroup = Selection.Products;
			FillAreaParameters("PriceGroup", ParameterValues, PrintingStructure);
			
			PrintingStructure.SpreadsheetDocument.StartRowGroup();
			FillPriceListDetailsProductsHierarchy(PrintingStructure, Selection.Select(QueryResultIteration.ByGroupsWithHierarchy));
			PrintingStructure.SpreadsheetDocument.EndRowGroup();
			
		ElsIf Not Selection.IsFolder 
			AND (OutputProductsWithoutParent 
				OR ValueIsFilled(Selection.Parent)) Then
			
			FillPropertyValues(ParameterValues, Selection);
			FillAreaParameters("Details", ParameterValues, PrintingStructure);
			
		EndIf;
		
	EndDo;
	
	If OutputProductsWithoutParent Then
		
		PrintingStructure.SpreadsheetDocument.EndRowGroup();
		Selection.Reset();
		FillPriceListDetailsProductsHierarchy(PrintingStructure, Selection);
		
	EndIf;
	
EndProcedure

Procedure SelectPriceistDataProductsHierarchy(PrintingStructure)
	
	Query = New Query(GetQueryTextForPrintingPriceListProductsHierarchy());
	Query.SetParameter("Period", CurrentSessionDate());
	Query.SetParameter("PriceKind", GetDefaultPriceKind(PrintingStructure.Counterparty));
	Query.SetParameter("OutputCode", Constants.DisplayItemNumberInThePriceList.Get());
	Query.SetParameter("OutputFullDescr", Constants.DisplayDetailedDescriptionInThePriceList.Get());
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		
		FillPriceListDetailsProductsHierarchy(PrintingStructure, QueryResult.Select(QueryResultIteration.ByGroupsWithHierarchy), True);
		
	EndIf;
	
EndProcedure

// Function returns template areas structure to generate price list
//
Function FillTemplateAreaStructure(Template)
	
	AreaStructure = New Structure;
	
	AreaStructure.Insert("AreaGapProducts",			Template.GetArea("Indent|Products"));
	AreaStructure.Insert("AreaGapCharacteristic",		Template.GetArea("Indent|Characteristic"));
	AreaStructure.Insert("AreaGapPrice",					Template.GetArea("Indent|Price"));
	
	AreaStructure.Insert("AreaTitleProducts",		Template.GetArea("Title|Products"));
	AreaStructure.Insert("AreaTitleCharacteristic",	Template.GetArea("Title|Characteristic"));
	AreaStructure.Insert("AreaTitlePrice",				Template.GetArea("Title|Price"));
	
	AreaStructure.Insert("AreaSenderWithoutLogoProducts",		Template.GetArea("SenderWithoutLogo|Products"));
	AreaStructure.Insert("AreaSenderWithoutLogoCharacteristic",	Template.GetArea("SenderWithoutLogo|Characteristic"));
	AreaStructure.Insert("AreaSenderWithoutLogoPrice",				Template.GetArea("SenderWithoutLogo|Price"));
	
	AreaStructure.Insert("AreaSenderWithLogoProducts",		Template.GetArea("SenderWithLogo|Products"));
	AreaStructure.Insert("AreaSenderWithLogoCharacteristic",	Template.GetArea("SenderWithLogo|Characteristic"));
	AreaStructure.Insert("AreaSenderWithLogoPrice",				Template.GetArea("SenderWithLogo|Price"));
	
	AreaStructure.Insert("AreaFormedProducts",	Template.GetArea("Formed|Products"));
	AreaStructure.Insert("AreaFormedCharacteristic",	Template.GetArea("Formed|Characteristic"));
	AreaStructure.Insert("AreaFormedPrice",			Template.GetArea("Formed|Price"));
	
	AreaStructure.Insert("AreaTableHeaderProducts",	Template.GetArea("TableHeader|Products"));
	AreaStructure.Insert("AreaTableHeaderCharacteristic",	Template.GetArea("TableHeader|Characteristic"));
	AreaStructure.Insert("AreaTableHeaderPrice",			Template.GetArea("TableHeader|Price"));
	
	AreaStructure.Insert("AreaPriceGroupProducts",	Template.GetArea("PriceGroup|Products"));
	AreaStructure.Insert("AreaPriceGroupCharacteristic",Template.GetArea("PriceGroup|Characteristic"));
	AreaStructure.Insert("AreaPriceGroupPrice",			Template.GetArea("PriceGroup|Price"));
	
	AreaStructure.Insert("AreaDetailsProducts",			Template.GetArea("Details|Products"));
	AreaStructure.Insert("AreaDetailsCharacteristic",		Template.GetArea("Details|Characteristic"));
	AreaStructure.Insert("AreaDetailsPrice",					Template.GetArea("Details|Price"));
	
	Return AreaStructure;
	
EndFunction

// Price list generating procedure
//
Function GeneratePriceList(ObjectsArray, PrintObjects)
	
	UseItemHierarchy = Constants.GeneratePriceListAccordingToProductsHierarchy.Get();
	
	SpreadsheetDocument = New SpreadsheetDocument;
	SpreadsheetDocument.PrintParametersKey = "PrintParameters_PriceList";
	SpreadsheetDocument.PrintParametersName = "PRINT_PARAMETERS_PriceList";
	
	AreaStructure = FillTemplateAreaStructure(PrintManagement.PrintedFormsTemplate("Catalog.Counterparties.PF_MXL_PriceList"));
	
	FirstLineNumber = SpreadsheetDocument.TableHeight + 1;
	
	UseCharacteristics = GetFunctionalOption("UseCharacteristics");
	
	PrintingStructure =
		New Structure("SpreadSheetDocument, AreaStructure, Counterparty, UseCharacteristics",
			SpreadsheetDocument,
			AreaStructure,
			ObjectsArray,
			UseCharacteristics);
			
	NameSectionSender = ?(ValueIsFilled(GetDefaultCompany(PrintingStructure.Counterparty).LogoFile), "SenderWithLogo", "SenderWithoutLogo");
			
	// Fill in price list section by section
	FillPriceListTitle("Title", PrintingStructure);
	FillPriceListSender(PrintingStructure); // section is determined dynamically
	FillFormedPriceList("Formed", PrintingStructure);
	FillPriceListHeader("TableHeader", PrintingStructure);
	
	If UseItemHierarchy Then
		
		SelectPriceistDataProductsHierarchy(PrintingStructure); // Output areas "Product group" and "Details"
		
	Else
		
		FillPriceListDetailsPriceGroup(PrintingStructure); // Output "PriceGroup" and "Details" areas
		
	EndIf;
	
	PrintManagement.SetDocumentPrintArea(SpreadsheetDocument, FirstLineNumber, PrintObjects, ObjectsArray.Ref);
	SpreadsheetDocument.FitToPage = True;
	
	Return SpreadsheetDocument;
	
EndFunction

// Function calls procedure of printing price list for counterparty
// 
//
Function PrintForm(ObjectsArray, PrintObjects)
	
	Return GeneratePriceList(ObjectsArray[0], PrintObjects);
	
EndFunction

// Generate printed forms of objects
//
// Incoming:
// TemplateNames    - String    - Names of layouts separated
// by commas ObjectsArray  - Array    - Array of refs to objects that
// need to be printed PrintParameters - Structure - Structure of additional printing parameters
//
// Outgoing:
// PrintFormsCollection - Values table - Generated
// table documents OutputParameters       - Structure        - Parameters of generated table documents
//
Procedure Print(ObjectsArray, PrintParameters, PrintFormsCollection, PrintObjects, OutputParameters) Export
	
	If PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "PriceList") Then		
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection, "PriceList", "Price list", PrintForm(ObjectsArray, PrintObjects));		
	EndIf;
	
	// Fill in price list receivers
	Recipients = New ValueList;
	Recipients.Add(ObjectsArray[0]);
	
	ArrayOfRecipients = New Array;
	ArrayOfRecipients.Add(ObjectsArray[0]);
	
	OutputParameters.SendingParameters.Recipient	= Recipients;
	OutputParameters.SendingParameters.Subject		= StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en = 'Price list %1 dated %2. Generated %3.'"),
		GetDefaultCompany(ObjectsArray[0]).Description,
		CurrentSessionDate(),
		UsersClientServer.AuthorizedUser());
	DriveServer.FillSendingParameters(OutputParameters.SendingParameters, ArrayOfRecipients, PrintFormsCollection);
	
EndProcedure

// Fills in Sales order printing commands list
// 
// Parameters:
//   PrintCommands - ValueTable - see fields' content in the PrintManagement.CreatePrintCommandsCollection function.
//
Procedure AddPrintCommands(PrintCommands) Export

EndProcedure

#EndRegion

#Region InfobaseUpdate

Procedure SetPropertiesForRetailCustomerPredefinedItem() Export
	
	RetailCustomerRef = RetailCustomer;
	
	RetailCustomerData = CommonUse.ObjectAttributesValues(RetailCustomerRef, "ContractByDefault, ContractByDefault.SettlementsCurrency");
	
	If Not ValueIsFilled(RetailCustomerData.ContractByDefault) Then
		
		RetailCustomerObj = RetailCustomerRef.GetObject();
		
		RetailCustomerObj.DescriptionFull = RetailCustomerObj.Description;
		
		RetailCustomerObj.Customer = True;
		RetailCustomerObj.LegalEntityIndividual = Enums.CounterpartyType.Individual;
		
		RetailCustomerObj.GLAccountCustomerSettlements	= Catalogs.DefaultGLAccounts.GetDefaultGLAccount("AccountsReceivable");
		RetailCustomerObj.CustomerAdvancesGLAccount		= Catalogs.DefaultGLAccounts.GetDefaultGLAccount("CustomerAdvances");
		RetailCustomerObj.GLAccountVendorSettlements	= Catalogs.DefaultGLAccounts.GetDefaultGLAccount("AccountsPayable");
		RetailCustomerObj.VendorAdvancesGLAccount		= Catalogs.DefaultGLAccounts.GetDefaultGLAccount("AdvancesToSuppliers");
		
		If RetailCustomerObj.Code = "000000001" Then
			
			RetailCustomerObj.SetNewCode();
			
		EndIf;
		
		InfobaseUpdateDrive.WriteCatalogObject(RetailCustomerObj);
		
	ElsIf Not ValueIsFilled(RetailCustomerData.ContractByDefaultSettlementsCurrency) Then
		
		ContractObj = RetailCustomerData.ContractByDefault.GetObject();
		
		ContractObj.SettlementsCurrency = Constants.FunctionalCurrency.Get();
		
		InfobaseUpdateDrive.WriteCatalogObject(ContractObj);
		
	EndIf;
	
EndProcedure

#EndRegion

#EndIf