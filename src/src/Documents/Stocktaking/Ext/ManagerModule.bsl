#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region PrintInterface

// Procedure forms and displays a printable document form by the specified layout.
//
// Parameters:
// SpreadsheetDocument - TabularDocument
// 			   in which printing form will be displayed.
//  TemplateName    - String, printing form layout name.
//
Function PrintForm(ObjectsArray, PrintObjects, TemplateName)
	
	SpreadsheetDocument = New SpreadsheetDocument;
	
	FirstDocument = True;
	
	For Each CurrentDocument In ObjectsArray Do
	
		If Not FirstDocument Then
			SpreadsheetDocument.PutHorizontalPageBreak();
		EndIf;
		FirstDocument = False;
		
		FirstLineNumber = SpreadsheetDocument.TableHeight + 1;
		
		If TemplateName = "MerchandiseFillingForm" Then
			
			Query = New Query();
			Query.SetParameter("CurrentDocument", CurrentDocument);
			Query.Text = 
			"SELECT
			|	Stocktaking.Date AS DocumentDate,
			|	Stocktaking.StructuralUnit AS WarehousePresentation,
			|	Stocktaking.Cell AS CellPresentation,
			|	Stocktaking.Number,
			|	Stocktaking.Company.Prefix AS Prefix,
			|	Stocktaking.Inventory.(
			|		LineNumber AS LineNumber,
			|		Products.Warehouse AS Warehouse,
			|		Products.Cell AS Cell,
			|		CASE
			|			WHEN (CAST(Stocktaking.Inventory.Products.DescriptionFull AS String(100))) = """"
			|				THEN Stocktaking.Inventory.Products.Description
			|			ELSE Stocktaking.Inventory.Products.DescriptionFull
			|		END AS InventoryItem,
			|		Products.SKU AS SKU,
			|		Products.Code AS Code,
			|		MeasurementUnit.Description AS MeasurementUnit,
			|		Quantity AS Quantity,
			|		Characteristic,
			|		Products.ProductsType AS ProductsType,
			|		ConnectionKey
			|	),
			|	Stocktaking.SerialNumbers.(
			|		SerialNumber,
			|		ConnectionKey
			|	)
			|FROM
			|	Document.Stocktaking AS Stocktaking
			|WHERE
			|	Stocktaking.Ref = &CurrentDocument
			|
			|ORDER BY
			|	LineNumber";
			
			Header = Query.Execute().Select();
			Header.Next();
			
			LinesSelectionInventory = Header.Inventory.Select();
			LinesSelectionSerialNumbers = Header.SerialNumbers.Select();
			
			SpreadsheetDocument.PrintParametersName = "PRINT_PARAMETERS_InventoryOfInventory_FormOfFilling";
			
			Template = PrintManagement.PrintedFormsTemplate("Document.Stocktaking.PF_MXL_MerchandiseFillingForm");
			
			If Header.DocumentDate < Date('20110101') Then
				DocumentNumber = DriveServer.GetNumberForPrinting(Header.Number, Header.Prefix);
			Else
				DocumentNumber = ObjectPrefixationClientServer.GetNumberForPrinting(Header.Number, True, True);
			EndIf;
			
			TemplateArea = Template.GetArea("Title");
			TemplateArea.Parameters.HeaderText = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Inventory survey #%1, %2'"),
				DocumentNumber,
				Format(Header.DocumentDate, "DLF=DD"));
			
			SpreadsheetDocument.Put(TemplateArea);
			
			TemplateArea = Template.GetArea("Warehouse");
			TemplateArea.Parameters.WarehousePresentation = Header.WarehousePresentation;
			SpreadsheetDocument.Put(TemplateArea);
			
			If Constants.UseStorageBins.Get() Then
				
				TemplateArea = Template.GetArea("Cell");
				TemplateArea.Parameters.CellPresentation = Header.CellPresentation;
				SpreadsheetDocument.Put(TemplateArea);
				
			EndIf;
			
			TemplateArea = Template.GetArea("PrintingTime");
			TemplateArea.Parameters.PrintingTime = 	StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Date and time of printing: %1. User: %2.'"),
				CurrentSessionDate(),
				Users.CurrentUser());
				
			SpreadsheetDocument.Put(TemplateArea);
			
			TemplateArea = Template.GetArea("TableHeader");
			SpreadsheetDocument.Put(TemplateArea);			
			TemplateArea = Template.GetArea("String");
			
			While LinesSelectionInventory.Next() Do
				
				If Not LinesSelectionInventory.ProductsType = Enums.ProductsTypes.InventoryItem Then
					Continue;
				EndIf;
				
				TemplateArea.Parameters.Fill(LinesSelectionInventory);
				
				StringSerialNumbers = WorkWithSerialNumbers.SerialNumbersStringFromSelection(LinesSelectionSerialNumbers, LinesSelectionInventory.ConnectionKey);
				TemplateArea.Parameters.InventoryItem = DriveServer.GetProductsPresentationForPrinting(LinesSelectionInventory.InventoryItem, 
					LinesSelectionInventory.Characteristic, LinesSelectionInventory.SKU, StringSerialNumbers);
				
				SpreadsheetDocument.Put(TemplateArea);
				
			EndDo;
			
			TemplateArea = Template.GetArea("Total");
			SpreadsheetDocument.Put(TemplateArea);	
			
		ElsIf TemplateName = "Stocktaking" Then
			
			PrintingCurrency = Constants.PresentationCurrency.Get();
			
			Query = New Query;
			Query.SetParameter("CurrentDocument", CurrentDocument);
			Query.Text =
			"SELECT
			|	Stocktaking.Number,
			|	Stocktaking.Date AS DocumentDate,
			|	Stocktaking.Company,
			|	Stocktaking.StructuralUnit.Presentation AS WarehousePresentation,
			|	Stocktaking.Company.Prefix AS Prefix,
			|	Stocktaking.Inventory.(
			|		LineNumber,
			|		Products,
			|		CASE
			|			WHEN (CAST(Stocktaking.Inventory.Products.DescriptionFull AS String(1000))) = """"
			|				THEN Stocktaking.Inventory.Products.Description
			|			ELSE CAST(Stocktaking.Inventory.Products.DescriptionFull AS String(1000))
			|		END AS Product,
			|		Characteristic,
			|		Products.SKU AS SKU,
			|		Quantity AS Quantity,
			|		QuantityAccounting AS AccountingCount,
			|		Deviation AS Deviation,
			|		MeasurementUnit AS MeasurementUnit,
			|		Price,
			|		Amount,
			|		AmountAccounting AS AmountByAccounting
			|	)
			|FROM
			|	Document.Stocktaking AS Stocktaking
			|WHERE
			|	Stocktaking.Ref = &CurrentDocument
			|
			|ORDER BY
			|	Stocktaking.Inventory.LineNumber";
			
			Header = Query.Execute().Select();
			
			Header.Next();
			
			StringSelectionProducts = Header.Inventory.Select();
			
			SpreadsheetDocument.PrintParametersName = "PRINT_PARAMETERS_InventoryInventory_InventoryInventory";
			
			Template = PrintManagement.PrintedFormsTemplate("Document.Stocktaking.PF_MXL_Stocktaking");
			
			If Header.DocumentDate < Date('20110101') Then
				DocumentNumber = DriveServer.GetNumberForPrinting(Header.Number, Header.Prefix);
			Else
				DocumentNumber = ObjectPrefixationClientServer.GetNumberForPrinting(Header.Number, True, True);
			EndIf;
			
			// Displaying invoice header
			TemplateArea = Template.GetArea("Title");
			TemplateArea.Parameters.HeaderText = NStr("en = 'Inventory survey #'")
				+ DocumentNumber
				+ " " + NStr("en = 'dated'") + " "
				+ Format(Header.DocumentDate, "DLF=DD");
				
			SpreadsheetDocument.Put(TemplateArea);
			
			// Output company and warehouse data
			TemplateArea = Template.GetArea("Vendor");
			TemplateArea.Parameters.Fill(Header);
			
			InfoAboutCompany    = DriveServer.InfoAboutLegalEntityIndividual(Header.Company, Header.DocumentDate);
			CompanyPresentation = DriveServer.CompaniesDescriptionFull(InfoAboutCompany, "FullDescr,");
			TemplateArea.Parameters.CompanyPresentation = CompanyPresentation;
			
			TemplateArea.Parameters.CurrencyName = String(PrintingCurrency);
			TemplateArea.Parameters.Currency             = PrintingCurrency;
			SpreadsheetDocument.Put(TemplateArea);

			// Output table header.
			TemplateArea = Template.GetArea("TableHeader");
			TemplateArea.Parameters.Fill(Header);
			SpreadsheetDocument.Put(TemplateArea);
			
			TotalAmount        = 0;
			TotalAmountByAccounting = 0;

			TemplateArea = Template.GetArea("String");
			While StringSelectionProducts.Next() Do

				TemplateArea.Parameters.Fill(StringSelectionProducts);
				TemplateArea.Parameters.Product = DriveServer.GetProductsPresentationForPrinting(StringSelectionProducts.Product, 
																		StringSelectionProducts.Characteristic, StringSelectionProducts.SKU);
				TotalAmount        = TotalAmount        + StringSelectionProducts.Amount;
				TotalAmountByAccounting = TotalAmountByAccounting + StringSelectionProducts.AmountByAccounting;
				SpreadsheetDocument.Put(TemplateArea);

			EndDo;

			// Output Total
			TemplateArea                        = Template.GetArea("Total");
			TemplateArea.Parameters.Total        = DriveServer.AmountsFormat(TotalAmount);
			TemplateArea.Parameters.TotalByAccounting = DriveServer.AmountsFormat(TotalAmountByAccounting);
			SpreadsheetDocument.Put(TemplateArea);

			// Output signatures to document
			TemplateArea = Template.GetArea("Signatures");
			SpreadsheetDocument.Put(TemplateArea);
			
		EndIf;
		
		PrintManagement.SetDocumentPrintArea(SpreadsheetDocument, FirstLineNumber, PrintObjects, CurrentDocument);
		
	EndDo;
	
	SpreadsheetDocument.FitToPage = True;
	
	Return SpreadsheetDocument;
	
EndFunction

// Generate printed forms of objects
//
// Incoming:
//   TemplateNames    - String    - Names of layouts separated
//   by commas ObjectsArray  - Array    - Array of refs to objects that
//   need to be printed PrintParameters - Structure - Structure of additional printing parameters
//
// Outgoing:
//   PrintFormsCollection - Values table - Generated
//   table documents OutputParameters       - Structure        - Parameters of generated table documents
//
Procedure Print(ObjectsArray, PrintParameters, PrintFormsCollection, PrintObjects, OutputParameters) Export
	
	If PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "MerchandiseFillingForm") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection, "MerchandiseFillingForm", "Merchandise filling form", PrintForm(ObjectsArray, PrintObjects, "MerchandiseFillingForm"));
		
	ElsIf PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "Stocktaking") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection, "Stocktaking", "Inventory reconciliation", PrintForm(ObjectsArray, PrintObjects, "Stocktaking"));
		
	EndIf;
	
	// parameters of sending printing forms by email
	DriveServer.FillSendingParameters(OutputParameters.SendingParameters, ObjectsArray, PrintFormsCollection);
	
EndProcedure

// Fills in the list of printing commands.
// 
// Parameters:
//   PrintCommands - ValueTable - see fields' content in the PrintManagement.CreatePrintCommandsCollection function.
//
Procedure AddPrintCommands(PrintCommands) Export
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID = "Stocktaking";
	PrintCommand.Presentation = NStr("en = 'Stocktaking'");
	PrintCommand.FormsList = "DocumentForm,ListForm";
	PrintCommand.CheckPostingBeforePrint = False;
	PrintCommand.Order = 4;
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID = "MerchandiseFillingForm";
	PrintCommand.Presentation = NStr("en = 'Goods content form'");
	PrintCommand.FormsList = "DocumentForm,ListForm";
	PrintCommand.CheckPostingBeforePrint = False;
	PrintCommand.Order = 17;
	
EndProcedure

#EndRegion

#EndIf