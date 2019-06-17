#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

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
	
	FillInParametersOfElectronicMail = True;
	
	If PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "Quote") Then
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection, "Quote", "Quote", DataProcessors.PrintQuote.PrintQuote(ObjectsArray, PrintObjects, "Quote"));
	EndIf;
	
	If PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "QuoteAllVariants") Then
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection, "QuoteAllVariants", "Quotation (all variants)", DataProcessors.PrintQuote.PrintQuote(ObjectsArray, PrintObjects, "QuoteAllVariants"));
	EndIf;
	
	If PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "ProformaInvoice") Then
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection, "ProformaInvoice", "Proforma invoice", DataProcessors.PrintQuote.PrintProformaInvoice(ObjectsArray, PrintObjects, "ProformaInvoice"));
	EndIf;
	
	If PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "ProformaInvoiceAllVariants") Then
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection, "ProformaInvoiceAllVariants", "Proforma invoice (all variants)", DataProcessors.PrintQuote.PrintProformaInvoice(ObjectsArray, PrintObjects, "ProformaInvoiceAllVariants"));
	EndIf;
	
	// parameters of sending printing forms by email
	If FillInParametersOfElectronicMail Then
		DriveServer.FillSendingParameters(OutputParameters.SendingParameters, ObjectsArray, PrintFormsCollection);
	EndIf;
	
EndProcedure

// Fills in Sales order printing commands list
// 
// Parameters:
//   PrintCommands - ValueTable - see fields' content in the PrintManagement.CreatePrintCommandsCollection function.
//
Procedure AddPrintCommands(PrintCommands) Export
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID							= "Quote";
	PrintCommand.Presentation				= NStr("en = 'Quotation'");
	PrintCommand.FormsList					= "DocumentForm,ListForm,DocumentsListForm";
	PrintCommand.CheckPostingBeforePrint	= False;
	PrintCommand.Order						= 1;
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID							= "QuoteAllVariants";
	PrintCommand.Presentation				= NStr("en = 'Quotation (all variants)'");
	PrintCommand.FormsList					= "DocumentForm,ListForm,DocumentsListForm";
	PrintCommand.CheckPostingBeforePrint	= False;
	PrintCommand.Order						= 2;
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID							= "ProformaInvoice";
	PrintCommand.Presentation				= NStr("en = 'Proforma invoice'");
	PrintCommand.FormsList					= "DocumentForm,ListForm,DocumentsListForm";
	PrintCommand.CheckPostingBeforePrint	= False;
	PrintCommand.Order						= 3;
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID							= "ProformaInvoiceAllVariants";
	PrintCommand.Presentation				= NStr("en = 'Proforma invoice (all variants)'");
	PrintCommand.FormsList					= "DocumentForm,ListForm,DocumentsListForm";
	PrintCommand.CheckPostingBeforePrint	= False;
	PrintCommand.Order						= 4;
	
EndProcedure

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRef, StructureAdditionalProperties) Export
	
	Query = New Query;
	
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRef);
	
	Query.Text =
	"SELECT
	|	Quote.Ref AS Ref,
	|	Quote.Company AS Company,
	|	Quote.Counterparty AS Counterparty,
	|	Quote.DocumentAmount AS DocumentAmount,
	|	Quote.Date AS Period
	|INTO TemporaryTableHeader
	|FROM
	|	Document.Quote AS Quote
	|WHERE
	|	Quote.Ref = &Ref";
	
	Query.ExecuteBatch();
	
	// Register record table creation
	GenerateTableQuotations(DocumentRef, StructureAdditionalProperties);
	
EndProcedure

#EndRegion

#Region Private

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableQuotations(DocumentRef, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRef);
	
	Query.Text =
	"SELECT
	|	TableQuotations.Ref AS Quotation,
	|	TableQuotations.Company AS Company,
	|	TableQuotations.Counterparty AS Counterparty,
	|	TableQuotations.DocumentAmount AS Amount,
	|	TableQuotations.Period AS Period
	|FROM
	|	TemporaryTableHeader AS TableQuotations";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableQuotations", QueryResult.Unload());
	
EndProcedure

#EndRegion

#EndIf