﻿
#Region Variables

&AtServer
Var TableInventory;

#EndRegion

#Region FormEventHandlers

// Procedure - OnCreateAtServer event handler.
// The procedure implements
// - initialization of form attributes
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	ArrayTypePaymentDocuments.Add(Type("DocumentRef.CashReceipt"));
	ArrayTypePaymentDocuments.Add(Type("DocumentRef.PaymentReceipt"));
	ArrayTypePaymentDocuments.Add(Type("DocumentRef.CashVoucher"));
	ArrayTypePaymentDocuments.Add(Type("DocumentRef.PaymentExpense"));
	
	FillInitialData();
	
EndProcedure

// Procedure-handler of selecting in the subordinate form
//
&AtClient
Procedure ChoiceProcessing(ValueSelected, ChoiceSource)
	
	If TypeOf(ValueSelected) = Type("CatalogRef.BillsOfMaterials") Then
		ProcessBillsOfMaterialselection(ValueSelected);
		SetTreeRowsPicture();
	EndIf;
	
EndProcedure

#EndRegion

#Region FormItemsEventsHandlers

// Procedure-handler
// of the OnActivateRow event of the SectionsTree tabular section
&AtClient
Procedure SectionTreeOnActivateRow(Item)
		
	CurrentTreeRow = Items.SectionTree.CurrentData;
	
	CurrentLinkToHelp = "";
	CurrentDateLatestCorrection = '00010101';
	
	If CurrentTreeRow.Level > 0 Then		
		
		CurrentSectionNumber = CurrentTreeRow.SectionNumber;
		CurrentAccountingSection = CurrentTreeRow.AccountingSection;
		CurrentAccountingSectionPresentation = CurrentTreeRow.AccountingSectionPresentation;
		CurrentLinkToHelp = CurrentTreeRow.LinkToHelp;
		CurrentDateLatestCorrection = CurrentTreeRow.ExecutionDate;
		
		If CurrentTreeRow.AnalysisExecuted Then
			OutputDataBySection();
		Else
			OutputNavigationUpdateData();
		EndIf;
		
	ElsIf CurrentTreeRow.Level = 0 Then	
		
		If CurrentTreeRow.AccountingSection = "AccountingSections" Then
			
			OutputFirstPage();
			
		ElsIf CurrentTreeRow.AccountingSection = "FinalReport" Then
			OutputFinalReport();
		EndIf;
		
	EndIf;
	
	Items.ResultDocument.CurrentArea = ResultDocument.Area(1, 1, 1, 1);
	
EndProcedure

// Procedure-handler of the Select a tabular document event DocumentResult.
//
&AtClient
Procedure ChoiceResultDocument(Item, Area, StandardProcessing)
	
	PredefineVariant = 0;
	
	ProcedureNameToExecuteOnClient = "";
	
	DataBeenChanged = False;
	
	IsPicture = False;
	
	If TypeOf(Area) = Type("SpreadsheetDocumentDrawing") Then
		IsPicture = True;		
	EndIf;
	
	CellClickProcessor(Area.Name, PredefineVariant, ProcedureNameToExecuteOnClient, IsPicture, DataBeenChanged);
	
	CurArea = Area;
	
	If ProcedureNameToExecuteOnClient <> "" Then
		
		If ProcedureNameToExecuteOnClient = "Close()" Then
			
			StandardProcessing = False;
			
			ClearDocumentResult();
			
			Close();
			
		ElsIf Left(ProcedureNameToExecuteOnClient, 8) = "GoToRow#" Then
			
			RowID = 0;
			
			Try
				RowID = Number(Right(ProcedureNameToExecuteOnClient, StrLen(ProcedureNameToExecuteOnClient) - 8));			
			Except
			
			EndTry;
			
			If RowID <> 0 Then
				Items.SectionTree.CurrentRow = RowID;
			EndIf;
			
		ElsIf ProcedureNameToExecuteOnClient = "OutputFinalReport()" Then
			
			Items.SectionTree.CurrentRow = AllSectionsAvailable + 1;
			PredefineVariant = 1;
			
		Else			
			
			Try
				#If WebClient Then
					ExecuteProcedureOnWebClient(ProcedureNameToExecuteOnClient, CurArea, PredefineVariant, DataBeenChanged);	
				#Else
					Execute(ProcedureNameToExecuteOnClient);
				#EndIf
			Except
				ErrorsDescriptionArray = New Array;
				ErrorsDescriptionArray.Add("Unable to execute the procedure " + ProcedureNameToExecuteOnClient);
				ErrorsDescriptionArray.Add(ErrorDescription());
				OutputErrorRow(ErrorsDescriptionArray);
			EndTry;
			
		EndIf;
		
	EndIf;
	
	If PredefineVariant = 1 Then
		Items.ResultDocument.CurrentArea = ResultDocument.Area(1, 1, 1, 1);
	ElsIf PredefineVariant = 2 Then
		Items.ResultDocument.CurrentArea = ResultDocument.Area(GetCurrRowFromAreaName(Area.Name) + "C1");
	EndIf;
	
	If DataBeenChanged Then
		
		If CurrentAccountingSection = "ProductsWithoutBillsOfMaterials" Then
			ChangeSubordinateProductsWithoutBillsOfMaterials();
		ElsIf CurrentAccountingSection = "ReportsProcWithoutBillsOfMaterials" Then
			ChangeSubordinateReportsProcWithoutBillsOfMaterials();
		ElsIf CurrentAccountingSection = "DocProductionWithoutBillsOfMaterials" Then
			ChangeSubordinateDocProductionWithoutBillsOfMaterials();
		EndIf;
		
		SetTreeRowsPicture();
		
	EndIf;	
	
EndProcedure

// Procedure - handler of the DecryptionProcessor event of the DocumentResult tabular document.
//
&AtClient
Procedure ResultProcessingTranscriptionsDocument(Item, Details, StandardProcessing)
	
	If TypeOf(Details) = Type("String") Then
		StandardProcessing = False;	
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure PeriodMinus(Command)
	
	ChangePeriod(-1);
	
EndProcedure

&AtClient
Procedure PeriodPlus(Command)
	
	ChangePeriod(1);	
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// Function generates the structure containing the date
// of the last data correction for each section.
// The Data structure return value: key - section name, value - date.
//
&AtServer
Function FillExecutionDatesStructure()

	DataStructure = New Structure;
	
	Query = New Query("SELECT
	                      |	CorrectionsOfLogicalErrorsInAccounting.AccountingSection,
	                      |	CorrectionsOfLogicalErrorsInAccounting.ExecutionDate
	                      |FROM
	                      |	InformationRegister.CorrectionsOfLogicalErrorsInAccounting AS CorrectionsOfLogicalErrorsInAccounting");
						  
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		DataStructure.Insert(Selection.AccountingSection, Selection.ExecutionDate);
	EndDo;
	
	Return DataStructure;

EndFunction

// Procedure fills in initial form data, called during form creation.
//
&AtServer
Procedure FillInitialData()
	
	If Parameters.Property("BeginOfPeriod") Then
		BeginOfPeriod = Parameters.BeginOfPeriod;
	EndIf;
	
	If Parameters.Property("EndOfPeriod") Then
		EndOfPeriod = Parameters.EndOfPeriod;
	EndIf;
	
	If Parameters.Property("Company") Then
		Company = Parameters.Company;
	EndIf;
	
	SetPeriodPresentation();
	
	If Parameters.MonthEndContext Then
		
		Items.OutOfContext.Visible = False;
		
		Items.PeriodCompanyLabel.Title = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Per %1, for companies %2'"),
			Lower(PeriodPresentation),
			TrimAll(Company.Description));
		
	Else		
		Items.InContextOf.Visible = False;		
	EndIf;
	
	RunAccountingBySubsidiaryCompany = Constants.AccountingBySubsidiaryCompany.Get();
	
	FillSectionTree();
	
	OutputFirstPage();

EndProcedure

// Procedure generates a text presentation of the analyzed period in the MM-YYYY format and places to the
// PeriodPresentation attribute.
// 
&AtServer
Procedure SetPeriodPresentation()
	
	If Not ValueIsFilled(BeginOfPeriod) OR Not ValueIsFilled(EndOfPeriod) Then
		BeginOfPeriod = BegOfMonth(CurrentDate());
		EndOfPeriod = EndOfMonth(CurrentDate());
	EndIf;

	PeriodPresentation = PeriodPresentation(BeginOfPeriod, EndOfDay(EndOfPeriod));	

EndProcedure

// Procedure fills in the SectionsTree attribute.
//
&AtServer
Procedure FillSectionTree()
	
	DataStructure = FillExecutionDatesStructure();

	DataTree = FormAttributeToValue("SectionTree");
	
	DataTree.Rows.Clear();
	
	RowsCounter = 0;
	
	NewRow_Level0 = DataTree.Rows.Add();
	NewRow_Level0.AccountingSection				= "AccountingSections";
	NewRow_Level0.AccountingSectionPresentation	= NStr("en = 'ACCOUNTING SECTIONS'");
	NewRow_Level0.Level							= 0;
	TreeRowsNumeration(NewRow_Level0, RowsCounter);
	
	NewRow_Level1 = NewRow_Level0.Rows.Add();
	NewRow_Level1.AccountingSection				= "AccountsPayable";
	NewRow_Level1.AccountingSectionPresentation	= NStr("en = 'Accounts payable'");
	NewRow_Level1.Level							= 1;
	NewRow_Level1.LinkToHelp					= "postavshiki";
	SetExecutionDateToRow(NewRow_Level1, DataStructure);
	TreeRowsNumeration(NewRow_Level1, RowsCounter);
	
	NewRow_Level1 = NewRow_Level0.Rows.Add();
	NewRow_Level1.AccountingSection				= "AccountsReceivable";
	NewRow_Level1.AccountingSectionPresentation	= NStr("en = 'Accounts receivable'");
	NewRow_Level1.Level							= 1;
	NewRow_Level1.LinkToHelp					= "pokupateli";
	SetExecutionDateToRow(NewRow_Level1, DataStructure);
	TreeRowsNumeration(NewRow_Level1, RowsCounter);
		
	NewRow_Level1 = NewRow_Level0.Rows.Add();
	NewRow_Level1.AccountingSection				= "ExchangeDifferences";
	NewRow_Level1.AccountingSectionPresentation	= NStr("en = 'Exchange rate differences'");
	NewRow_Level1.Level							= 1;
	NewRow_Level1.LinkToHelp					= "kursov_r";
	SetExecutionDateToRow(NewRow_Level1, DataStructure);
	TreeRowsNumeration(NewRow_Level1, RowsCounter);
		
	NewRow_Level1 = NewRow_Level0.Rows.Add();
	NewRow_Level1.AccountingSection				= "ProductsWithoutBillsOfMaterials";
	NewRow_Level1.AccountingSectionPresentation	= NStr("en = 'Inventory-list without BillsOfMaterials'");
	NewRow_Level1.Level							= 1;
	NewRow_Level1.LinkToHelp					= "nom_bez_spec";
	SetExecutionDateToRow(NewRow_Level1, DataStructure);
	TreeRowsNumeration(NewRow_Level1, RowsCounter);
	
	NewRow_Level2 = NewRow_Level1.Rows.Add();
	NewRow_Level2.AccountingSection				= "ReportsProcWithoutBillsOfMaterials";
	NewRow_Level2.AccountingSectionPresentation	= NStr("en = 'Reports of processing companies without BillsOfMaterials'");
	NewRow_Level2.Level							= 2;
	NewRow_Level2.LinkToHelp					= "otchet_bez_spec";
	SetExecutionDateToRow(NewRow_Level2, DataStructure);
	TreeRowsNumeration(NewRow_Level2, RowsCounter);
	
	NewRow_Level3 = NewRow_Level2.Rows.Add();
	NewRow_Level3.AccountingSection				= "ReportsReprocWriteOffsMismatch";
	NewRow_Level3.AccountingSectionPresentation	= NStr("en = 'Processor reports - discrepancies between write-offs and BillsOfMaterials'");
	NewRow_Level3.Level							= 3;
	NewRow_Level3.LinkToHelp					= "otchet_nesoot_spec";
	SetExecutionDateToRow(NewRow_Level3, DataStructure);
	TreeRowsNumeration(NewRow_Level3, RowsCounter);	
	
	NewRow_Level2 = NewRow_Level1.Rows.Add();
	NewRow_Level2.AccountingSection				= "DocProductionWithoutBillsOfMaterials";
	NewRow_Level2.AccountingSectionPresentation	= NStr("en = 'The Production documents without BillsOfMaterials.'");
	NewRow_Level2.Level							= 2;
	NewRow_Level2.LinkToHelp					= "proizv_bez_spec";
	SetExecutionDateToRow(NewRow_Level2, DataStructure);
	TreeRowsNumeration(NewRow_Level2, RowsCounter);
	
	NewRow_Level3 = NewRow_Level2.Rows.Add();
	NewRow_Level3.AccountingSection				= "DocProductionWriteoffsMismatch";
	NewRow_Level3.AccountingSectionPresentation	= NStr("en = 'The Production documents - mismatch of descriptions to BillsOfMaterials'");
	NewRow_Level3.Level							= 3;
	NewRow_Level3.LinkToHelp					= "proizv_nesoot_spec";
	SetExecutionDateToRow(NewRow_Level3, DataStructure);
	TreeRowsNumeration(NewRow_Level3, RowsCounter);
	
	NewRow_Level1 = NewRow_Level0.Rows.Add();
	NewRow_Level1.AccountingSection				= "PurchasePricesAnalysis";
	NewRow_Level1.AccountingSectionPresentation	= NStr("en = 'Analysis of procurement prices'");
	NewRow_Level1.Level							= 1;
	NewRow_Level1.LinkToHelp					= "zakup_prices";
	SetExecutionDateToRow(NewRow_Level1, DataStructure);
	TreeRowsNumeration(NewRow_Level1, RowsCounter);
	
	NewRow_Level1 = NewRow_Level0.Rows.Add();
	NewRow_Level1.AccountingSection				= "CompaniesContractControl";
	NewRow_Level1.AccountingSectionPresentation	= NStr("en = 'Control of organizations and contracts in documents'");
	NewRow_Level1.Level							= 1;
	NewRow_Level1.LinkToHelp					= "dogovor_org";
	SetExecutionDateToRow(NewRow_Level1, DataStructure);
	TreeRowsNumeration(NewRow_Level1, RowsCounter);
	
	NewRow_Level1 = NewRow_Level0.Rows.Add();
	NewRow_Level1.AccountingSection				= "CashFlowItems";
	NewRow_Level1.AccountingSectionPresentation	= NStr("en = 'Cash flow items'");
	NewRow_Level1.Level							= 1;
	NewRow_Level1.LinkToHelp					= "dds";
	SetExecutionDateToRow(NewRow_Level1, DataStructure);
	TreeRowsNumeration(NewRow_Level1, RowsCounter);
	
	NewRow_Level0 = DataTree.Rows.Add();
	NewRow_Level0.AccountingSection				= "FinalReport";
	NewRow_Level0.AccountingSectionPresentation	= NStr("en = 'Final report'");
	NewRow_Level0.Level							= 0;
	TreeRowsNumeration(NewRow_Level0, RowsCounter);
	
	SectionsNumbering(DataTree);
	
	ValueToFormAttribute(DataTree, "SectionTree");

EndProcedure

// Set the last date of corrections by each section - i.e. tree row.
//
&AtServer
Procedure SetExecutionDateToRow(TreeRow, DataStructure)

	If DataStructure.Property(TreeRow.AccountingSection) Then
		TreeRow.ExecutionDate = DataStructure[TreeRow.AccountingSection];	
	EndIf;	

EndProcedure

// Numbering of the sections tree rows. 
// Only rows, level 1 and more are numbered. 
//
&AtServer
Procedure SectionsNumbering(DataTree)
	
	CounSections = 0;
	
	For Each String_Level0 In DataTree.Rows Do
		
		SetNumbersInSubordinates(String_Level0, CounSections);	  
		
	EndDo;
	
	AllSectionsAvailable = CounSections;

EndProcedure

// Recursively called from SectionsNumeration (DataTree).
//
&AtServer
Procedure SetNumbersInSubordinates(ParentRow, CounSections)

	For Each CurrentRow In ParentRow.Rows Do
		
		CounSections = CounSections + 1;
		
		CurrentRow.SectionNumber = CounSections;
		
		SetNumbersInSubordinates(CurrentRow, CounSections);
	
	EndDo; 		

EndProcedure

// All rows of tree are numbered - for navigation.
//
&AtServerNoContext
Procedure TreeRowsNumeration(TreeRow, RowsCounter)

	TreeRow.TreeLineNumber = RowsCounter;
	
	RowsCounter = RowsCounter + 1;

EndProcedure

// Procedure outputs a hyperlink of data update to DocumentResult.
// Output if data by section were not filled in before.
//
&AtServer
Procedure OutputNavigationUpdateData()

	DataProcessorObject = FormAttributeToValue("Object");
	
	TemplateOutput = DataProcessorObject.GetTemplate("TemplateOutput");
	
	ResultDocument.Clear();
	
	OutputSectionTitle(TemplateOutput);
	
	TemplateArea = TemplateOutput.GetArea("RunDataAnalysis");
	TemplateArea.Parameters.DetailRunDataAnalysis = "ExecuteProcedureOnClient#ExecuteDataRefreshing(PredefineVariant, DataBeenChanged)";
	ResultDocument.Put(TemplateArea);
	
	OutputHyperlinkDescription(TemplateOutput);

EndProcedure

// Procedure-handler of clicking the hyperlink of data update.
//
&AtClient
Procedure ExecuteDataRefreshing(PredefineVariant, DataBeenChanged)
	
	PredefineVariant = 1;
	
	DataBeenChanged = True;
	
	CurrentTreeRow = Items.SectionTree.CurrentData;
	
	If Not CurrentTreeRow.AnalysisExecuted Then
		
		CurrentTreeRow.AnalysisExecuted = True;
		
		SubordinateRows = CurrentTreeRow.GetItems();
		
		For Each String In SubordinateRows Do
			String.ParentOutputSection = True;
		EndDo;
		
	EndIf;
	
	OutputDataBySection();
	
EndProcedure

// Procedure outputs a template area with a reference to data reupdate
//
&AtServer
Procedure OutputAreaUpdateDataByGeneratedSection(TemplateOutput)
	
	TemplateArea = TemplateOutput.GetArea("AreaIndent");		
	ResultDocument.Put(TemplateArea);
	ResultDocument.Put(TemplateArea);
	
	TemplateArea = TemplateOutput.GetArea("RefreshDataOnSection");
	TemplateArea.Parameters.DetailRefreshDataOnSection = "ExecuteProcedure#Attachable_UpdateDataByGeneratedSection(CurArea, PredefineVariant, DataBeenChanged)";
	ResultDocument.Put(TemplateArea);		

EndProcedure

// Procedure-handler of clicking the hyperlink of the data update by the generated section.
//
&AtServer
Procedure Attachable_UpdateDataByGeneratedSection(CurArea, PredefineVariant, DataBeenChanged)

	PredefineVariant = 1;
	
	DataBeenChanged = True;
	
	If CurrentAccountingSection = "AccountsPayable" Then
		
		AccountsPayableFilledWith = False;
		AccountsPayable.Clear();
		
	ElsIf CurrentAccountingSection = "AccountsReceivable" Then
		
		AccountsReceivableFilledWith = False;
		AccountsReceivable.Clear();
		
	ElsIf CurrentAccountingSection = "ExchangeDifferences" Then
		
		ExchangeRatesDifferencesFilledWith = False;
		ExchangeDifferencesDocumentsPereprovedeny = False;
		
		IncorrectExchangeDifferencesDC.GetItems().Clear();
		IncorrectExchangeDifferencesCustomers.GetItems().Clear();
		IncorrectExchangeDifferencesSuppliers.GetItems().Clear();		
		
	ElsIf CurrentAccountingSection = "ProductsWithoutBillsOfMaterials" Then
		
		ProductsWithoutFilledWithBillsOfMaterials = False;
		ProductsWithoutBillsOfMaterials.Clear();
		
	ElsIf CurrentAccountingSection = "ReportsProcWithoutBillsOfMaterials" Then
		
		ReportsPereireWithoutFilledBillsOfMaterials = False;
		SubcontractorBillsOfMaterialsReports.Clear();
		
	ElsIf CurrentAccountingSection = "ReportsReprocWriteOffsMismatch" Then
		
		SubcontractorFilledWithInconsistenciesReports = False;
		SubcontractorInconsistenciesReports.Clear();
		
	ElsIf CurrentAccountingSection = "DocProductionWithoutBillsOfMaterials" Then
		
		DocFilledWithProductionBillsOfMaterials = False;
		DocProductionBillsOfMaterials.Clear();
		
	ElsIf CurrentAccountingSection = "DocProductionWriteoffsMismatch" Then
		
		DocFilledWithProductionInconsistencies = False;
		DocProductionInconsistencies.Clear();
		
	ElsIf CurrentAccountingSection = "PurchasePricesAnalysis" Then
		
		PurchasePricesAnalysisFilledWith = False;
		PurchasePricesAnalysis.GetItems().Clear();
		
	ElsIf CurrentAccountingSection = "CompaniesContractControl" Then
		
		DocumentTreeFilledWithCompanyContract = False;
		DocumentsTreeCompanyContract.GetItems().Clear();
		
	ElsIf CurrentAccountingSection = "CashFlowItems" Then
		
		CashFlowItemsFilledWith = False;
		CashFlowItems.GetItems().Clear();
		
	Else
		
		CommonUseClientServer.MessageToUser(StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Handler of the data update from section %1 is not found'"),
			CurrentAccountingSectionPresentation));
		
		Return;
	
	EndIf;
	
	OutputDataBySection();

EndProcedure

// Outputs a template area to the tabular document containing a message about data absence.
//
&AtServer
Procedure OutputAreaNoData(TemplateOutput)

	TemplateArea = TemplateOutput.GetArea("StringNoData");
	ResultDocument.Put(TemplateArea);	

EndProcedure

// Outputs a result of a specified tracking section analysis to DocumentResult.
//
&AtServer
Procedure OutputDataBySection()

	DataProcessorObject = FormAttributeToValue("Object");
	
	TemplateOutput = DataProcessorObject.GetTemplate("TemplateOutput");
	
	HandlerProcedureName = "Attachable_OutputDataBySection" + CurrentAccountingSection + "(TemplateOutput)";
	
	Try
		Execute(HandlerProcedureName);	
	Except
		ErrorsDescriptionArray = New Array;
		ErrorsDescriptionArray.Add("Unable to execute the procedure " + HandlerProcedureName);
		ErrorsDescriptionArray.Add(ErrorDescription());
		OutputErrorRow(ErrorsDescriptionArray);
	EndTry;
	
	OutputTransferToNextSectionRow(TemplateOutput);
	
	OutputHyperlinkDescription(TemplateOutput);
	
EndProcedure

// Outputs the presentation of checked
// tracking section to DocumentResult and also the date of last corrections
//
&AtServer
Procedure OutputSectionTitle(TemplateOutput)

	ResultDocument.Clear();
	
	TemplateArea = TemplateOutput.GetArea("Title");
	TemplateArea.Parameters.SECTION = CurrentAccountingSectionPresentation;
	ResultDocument.Put(TemplateArea);
	
	If CurrentDateLatestCorrection <> '00010101' Then
		TemplateArea = TemplateOutput.GetArea("LastChangesData");
		TemplateArea.Parameters.ExecutionDate = Format(CurrentDateLatestCorrection, "DLF=DD");
		ResultDocument.Put(TemplateArea);	
	EndIf;

EndProcedure

// Outputs the DataOutput area to DocumentResult during filling in the data by the section.
//
&AtServer
Procedure OutputPictureDataOutput(TemplateOutput)

	ResultDocument.Clear();
	
	TemplateArea = TemplateOutput.GetArea("DataDisplay");
	ResultDocument.Put(TemplateArea);	

EndProcedure

// Outputs a hyperlink of transfer to the next section at the end of each page of the section.
//
&AtServer
Procedure OutputTransferToNextSectionRow(TemplateOutput)

	If CurrentSectionNumber = AllSectionsAvailable Then
		TemplateArea = TemplateOutput.GetArea("StringFinalReport");
		TemplateArea.Parameters.FinalReport = "Final report";
		TemplateArea.Parameters.GoToFinalReport = "ExecuteProcedureOnClient#OutputFinalReport()";
		ResultDocument.Put(TemplateArea);
		Return;
	EndIf;
	
	SectionData = FillSectionData(CurrentSectionNumber + 1);	
	
	// ref to transition	
	TemplateArea = TemplateOutput.GetArea("StringGoToSection");
	TemplateArea.Parameters.Section = SectionData.AccountingSectionPresentation;
	TemplateArea.Parameters.GoToNextSection = "ExecuteProcedureOnClient#GoToNextSection(PredefineVariant, DataBeenChanged)";
	ResultDocument.Put(TemplateArea);	

EndProcedure

// The function is called from the OutputTransitionToTheNextSectionRow(OutputTemplate) procedure to fill in data on the
// next section relative to the previous one.
// 
&AtServer
Function FillSectionData(SectionNumber)
	
	DataTree = FormAttributeToValue("SectionTree");
	
	SectionDataStructure = New Structure("AccountingSectionPresentation", "");

	For Each String_Level0 In DataTree.Rows Do
	
		CheckSubordinateRows(String_Level0, SectionNumber, SectionDataStructure);	 	
		
	EndDo;
	
	Return SectionDataStructure;

EndFunction

// Bypass of tree rows to get data by a section.
//
&AtServerNoContext
Procedure CheckSubordinateRows(ParentRow, SectionNumber, SectionDataStructure)

	For Each CurrentRow In ParentRow.Rows Do
		
		If CurrentRow.SectionNumber = SectionNumber Then
			FillPropertyValues(SectionDataStructure, CurrentRow);
			Return;
		Else
			CheckSubordinateRows(CurrentRow, SectionNumber, SectionDataStructure);	
		EndIf;
		
	EndDo; 	

EndProcedure

// Procedure-handler of clicking the cell of tab. document, executed on server.
// Parameters:
// 	AreaName - String the name of area where was a click;
// 	PredefineVariant - number;
// 	ProcedureNameToExecuteOnClient - String, variable to which name of the procedure for execution on client will be placed;
// 	IsPicture - Boolean, shows that the processed area is a picture;
// 	DataBeenChanged - Boolean, set to TRUE in case of DB objects modification.
//
&AtServer
Procedure CellClickProcessor(AreaName, PredefineVariant, ProcedureNameToExecuteOnClient, IsPicture = False, DataBeenChanged)
	
	If IsPicture Then
		
		Try
			CurArea = ResultDocument.Drawings[AreaName];			
		Except
			Return;
		EndTry;
		
	Else
		
		Try
			CurArea = ResultDocument.Area(AreaName);
		Except
			Return;	
		EndTry;
		
	EndIf;
	
	If CurArea.Details = Undefined Then
		Return;
	EndIf;
	
	AreaDecryption = CurArea.Details;
	
	If TypeOf(AreaDecryption) = Type("String") Then
		
		If Left(AreaDecryption, 17) = "ExecuteProcedure#" Then
			
			Try
				Execute(HighlightProcedureNameServer(AreaDecryption));			
			Except
				ErrorsDescriptionArray = New Array;
				ErrorsDescriptionArray.Add("Unable to execute the procedure " + HighlightProcedureNameServer(AreaDecryption));
				ErrorsDescriptionArray.Add(ErrorDescription());
				OutputErrorRow(ErrorsDescriptionArray);
			EndTry;
			
		ElsIf Left(AreaDecryption, 25) = "ExecuteProcedureOnClient#" Then
			
			RedefineCurrentArea = True;
			ProcedureNameToExecuteOnClient = HighlightProcedureNameClient(AreaDecryption);
			
		ElsIf Left(AreaDecryption, 8) = "GoToRow#" Then
			
			ProcedureNameToExecuteOnClient = AreaDecryption;
			
		EndIf;	
		
	EndIf;

EndProcedure

// Outputs to DocumentResult an error message. 
// 
&AtServer
Procedure OutputErrorRow(ErrorsDescriptionArray)

	ResultDocument.Put(GetTemplateArea("StringError"));
	
	ErrorDescriptionArea = GetTemplateArea("StringErrorContent"); 
	
	For Each ArrayElement In ErrorsDescriptionArray Do
		ErrorDescriptionArea.Parameters.ErrorContent = ArrayElement;
		ResultDocument.Put(ErrorDescriptionArea);
	EndDo; 

EndProcedure

// Function returns template area with the specified name.
//
&AtServer
Function GetTemplateArea(AreaName)

	DataProcessorObject = FormAttributeToValue("Object");
	Template = DataProcessorObject.GetTemplate("TemplateOutput");
	
	Return Template.GetArea(AreaName);

EndFunction

// Function returns procedure name for execution on server.
//
&AtServerNoContext
Function HighlightProcedureNameServer(SourceText)

	Return Right(SourceText, StrLen(SourceText) - 17);	

EndFunction

// Function returns procedure name for execution on client.
//
&AtServerNoContext
Function HighlightProcedureNameClient(SourceText)

	Return Right(SourceText, StrLen(SourceText) - 25);	

EndFunction

// Procedure-handler of clicking the hyperlink of transition to the next section.
//
&AtClient
Procedure GoToNextSection(PredefineVariant, DataBeenChanged)
	
	PredefineVariant = 1;
	
	DataBeenChanged = True;
	
	NextSectionNumber = CurrentSectionNumber + 1;
	
	Rows_Level0 = SectionTree.GetItems();
	
	For Each String_Level0 In Rows_Level0 Do
		
		GetSetSubrowIdentifier(Rows_Level0, NextSectionNumber);		
		
	EndDo; 

EndProcedure

// Sets a new current row of sections tree.
//
&AtClient
Procedure GetSetSubrowIdentifier(RowsSet, SectionNumber)

	For Each String In RowsSet Do
		
		If String.SectionNumber = SectionNumber Then
			Items.SectionTree.CurrentRow = String.GetID();
			Return;
		Else
			GetSetSubrowIdentifier(String.GetItems(), SectionNumber);	
		EndIf;
		
	EndDo; 	

EndProcedure

// sections
 
// Procedure initializes data filling by the Accounts payable section and puts out the data to DocumentResult.
// 
&AtServer
Procedure Attachable_OutputDataBySectionAccountsPayable(TemplateOutput)
	 
	If Not AccountsPayableFilledWith Then
		
		OutputPictureDataOutput(TemplateOutput);
		 
		TableAccountsPayable = GenerateTableAccountsPayable();
		ValueToFormAttribute(TableAccountsPayable, "AccountsPayable");
		AccountsPayableFilledWith = True;	
		
	EndIf;
	
	OutputSectionTitle(TemplateOutput);
	
	If AccountsPayable.Count() = 0 Then
		OutputAreaNoData(TemplateOutput);
		OutputAreaUpdateDataByGeneratedSection(TemplateOutput);
		Return;
	EndIf;
	
	For Each TabularSectionRow In AccountsPayable Do
		
		If TabularSectionRow.DataProcessorExecuted Then
			
			TemplateArea = TemplateOutput.GetArea("StringProcessedSettlement");			
			TemplateArea.Parameters.ResultAnalysis = "Advances were credited";
			
		Else			
			
			If TabularSectionRow.WereCorrections Then
				
				TemplateArea = TemplateOutput.GetArea("StringNotProcessedSettlementsChangesWereMade");
			
			ElsIf TabularSectionRow.ThereAreTurnoversForPeriod Then
				
				TemplateArea = TemplateOutput.GetArea("StringNotProcessedSettlements");				
				TemplateArea.Parameters.ExecuteAction = "Execute expense offset";
				TemplateArea.Parameters.ExecuteActionDecrypt = "ExecuteProcedure#Attachable_ExecuteExpensesOffsetByVendor(CurArea, PredefineVariant, DataBeenChanged)";
				
			Else
				
				TemplateArea = TemplateOutput.GetArea("StringNotProcessedSettlementsWithoutTurnovers");
				
			EndIf;
			
			TemplateArea.Parameters.ResultAnalysis = "Unaccounted advances are found";
		
		EndIf;
		
		TemplateArea.Parameters.CounterpartyDescription = TrimAll(TabularSectionRow.Counterparty.Description);
		TemplateArea.Parameters.Counterparty = TabularSectionRow.Counterparty;
		
		TemplateArea.Parameters.AnalysisResultDecrypt = "ExecuteProcedureOnClient#OutputReportBySettlements(CurArea, PredefineVariant, DataBeenChanged)";
		ResultDocument.Put(TemplateArea);
		
	EndDo;
		
	OutputAreaUpdateDataByGeneratedSection(TemplateOutput);
	 
EndProcedure

// Procedure implements a mechanism of the data control by the Accounts payable section.
//
&AtServer
Function GenerateTableAccountsPayable(CounterpartyFilter = Undefined)

	QueryText = 
	"SELECT
	|	NestedSelect.SettlementsTypesQuantity AS SettlementsTypesQuantity,
	|	NestedSelect.Counterparty AS Counterparty
	|INTO TU_CounterpartiesAdvanceDebt
	|FROM
	|	(SELECT
	|		SUM(NestedSelect.SettlementsTypesQuantity) AS SettlementsTypesQuantity,
	|		NestedSelect.Counterparty AS Counterparty
	|	FROM
	|		(SELECT
	|			AccountsPayableBalances.SettlementsType AS SettlementsType,
	|			1 AS SettlementsTypesQuantity,
	|			AccountsPayableBalances.Counterparty AS Counterparty
	|		FROM
	|			AccumulationRegister.AccountsPayable.Balance(
	|					&BalanceDate,
	|					Company = &Company
	|						AND &CounterpartyFilter) AS AccountsPayableBalances
	|		WHERE
	|			AccountsPayableBalances.AmountCurBalance <> 0) AS NestedSelect
	|	
	|	GROUP BY
	|		NestedSelect.Counterparty) AS NestedSelect
	|WHERE
	|	NestedSelect.SettlementsTypesQuantity > 1
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TU_CounterpartiesAdvanceDebt.Counterparty AS Counterparty,
	|	CASE
	|		WHEN ISNULL(NestedSelect.RecordersCount, 0) = 0
	|			THEN FALSE
	|		ELSE TRUE
	|	END AS ThereAreTurnoversForPeriod,
	|	FALSE AS DataProcessorExecuted,
	|	FALSE AS WereCorrections
	|FROM
	|	TU_CounterpartiesAdvanceDebt AS TU_CounterpartiesAdvanceDebt
	|		LEFT JOIN (SELECT
	|			VendorsSettlementsTurnovers.Counterparty AS Counterparty,
	|			COUNT(DISTINCT VendorsSettlementsTurnovers.Recorder) AS RecordersCount
	|		FROM
	|			AccumulationRegister.AccountsPayable.Turnovers(
	|					&DateBeg,
	|					&BalanceDate,
	|					Recorder,
	|					Company = &Company
	|						AND Counterparty IN
	|							(SELECT
	|								TU_CounterpartiesAdvanceDebt.Counterparty
	|							FROM
	|								TU_CounterpartiesAdvanceDebt AS TU_CounterpartiesAdvanceDebt)) AS VendorsSettlementsTurnovers
	|		
	|		GROUP BY
	|			VendorsSettlementsTurnovers.Counterparty) AS NestedSelect
	|		ON TU_CounterpartiesAdvanceDebt.Counterparty = NestedSelect.Counterparty";
	
	Query = New Query;
	Query.Text = QueryText;
	
	Query.SetParameter("DateBeg",		New Boundary(BeginOfPeriod, BoundaryType.Including));					  
	Query.SetParameter("BalanceDate",	New Boundary(EndOfDay(EndOfPeriod), BoundaryType.Including));
	Query.SetParameter("Company",		Company);
	
	If CounterpartyFilter = Undefined Then
		Query.Text = StrReplace(QueryText, "&CounterpartyFilter", "TRUE");	
	Else
		Query.Text = StrReplace(QueryText, "&CounterpartyFilter", "Counterparty = &CounterpartyFilter");	
		Query.SetParameter("CounterpartyFilter", CounterpartyFilter);
	EndIf;
	
	QueryResult = Query.Execute();
	
	Return QueryResult.Unload();	

EndFunction

// Procedure initializes data filling by the Accounts receivable section and puts out the data to DocumentResult.
// 
&AtServer
Procedure Attachable_OutputDataBySectionAccountsReceivable(TemplateOutput)
	
	If Not AccountsReceivableFilledWith Then
		
		OutputPictureDataOutput(TemplateOutput);
		
		TableAccountsReceivable = GenerateTableAccountsReceivable();
		ValueToFormAttribute(TableAccountsReceivable, "AccountsReceivable");
		AccountsReceivableFilledWith = True;	
		
	EndIf;
	
	OutputSectionTitle(TemplateOutput);
	
	If AccountsReceivable.Count() = 0 Then
		OutputAreaNoData(TemplateOutput);
		OutputAreaUpdateDataByGeneratedSection(TemplateOutput);
		Return;
	EndIf;
	
	For Each TabularSectionRow In AccountsReceivable Do
		
		If TabularSectionRow.DataProcessorExecuted Then
			
			TemplateArea = TemplateOutput.GetArea("StringProcessedSettlement");
			
			TemplateArea.Parameters.CounterpartyDescription = TrimAll(TabularSectionRow.Counterparty.Description);
			TemplateArea.Parameters.Counterparty = TabularSectionRow.Counterparty;
			
			TemplateArea.Parameters.ResultAnalysis = "Advances were credited";
			
		Else
			
			If TabularSectionRow.WereCorrections Then
				
				TemplateArea = TemplateOutput.GetArea("StringNotProcessedSettlementsChangesWereMade");
			
			ElsIf TabularSectionRow.ThereAreTurnoversForPeriod Then
				
				TemplateArea = TemplateOutput.GetArea("StringNotProcessedSettlements");
				TemplateArea.Parameters.ExecuteAction = "Execute expense offset";
				TemplateArea.Parameters.ExecuteActionDecrypt = "ExecuteProcedure#Attachable_ExecuteExpensesOffsetByCustomer(CurArea, PredefineVariant, DataBeenChanged)";
				                                                                 
			Else
				
				TemplateArea = TemplateOutput.GetArea("StringNotProcessedSettlementsWithoutTurnovers");
				
			EndIf;				
			
			TemplateArea.Parameters.ResultAnalysis = "Unaccounted advances are found";
			
			TemplateArea.Parameters.CounterpartyDescription = TrimAll(TabularSectionRow.Counterparty.Description);
			TemplateArea.Parameters.Counterparty = TabularSectionRow.Counterparty;	
			
		EndIf;
		
		TemplateArea.Parameters.AnalysisResultDecrypt = "ExecuteProcedureOnClient#OutputReportBySettlements(CurArea, PredefineVariant, DataBeenChanged)";
		ResultDocument.Put(TemplateArea);
		
	EndDo;
	
	OutputAreaUpdateDataByGeneratedSection(TemplateOutput);	
	
EndProcedure

// Procedure implements a mechanism of the data control by the Accounts receivable section.
//
&AtServer
Function GenerateTableAccountsReceivable(CounterpartyFilter = Undefined)

	QueryText = 
	"SELECT
	|	NestedSelect.SettlementsTypesQuantity AS SettlementsTypesQuantity,
	|	NestedSelect.Counterparty AS Counterparty
	|INTO TU_CounterpartiesAdvanceDebt
	|FROM
	|	(SELECT
	|		SUM(NestedSelect.SettlementsTypesQuantity) AS SettlementsTypesQuantity,
	|		NestedSelect.Counterparty AS Counterparty
	|	FROM
	|		(SELECT
	|			AccountsReceivableBalances.SettlementsType AS SettlementsType,
	|			1 AS SettlementsTypesQuantity,
	|			AccountsReceivableBalances.Counterparty AS Counterparty
	|		FROM
	|			AccumulationRegister.AccountsReceivable.Balance(
	|					&BalanceDate,
	|					Company = &Company
	|						AND &CounterpartyFilter) AS AccountsReceivableBalances
	|		WHERE
	|			AccountsReceivableBalances.AmountCurBalance <> 0) AS NestedSelect
	|	
	|	GROUP BY
	|		NestedSelect.Counterparty) AS NestedSelect
	|WHERE
	|	NestedSelect.SettlementsTypesQuantity > 1
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TU_CounterpartiesAdvanceDebt.Counterparty AS Counterparty,
	|	CASE
	|		WHEN ISNULL(NestedSelect.RecordersCount, 0) = 0
	|			THEN FALSE
	|		ELSE TRUE
	|	END AS ThereAreTurnoversForPeriod,
	|	FALSE AS DataProcessorExecuted,
	|	FALSE AS WereCorrections
	|FROM
	|	TU_CounterpartiesAdvanceDebt AS TU_CounterpartiesAdvanceDebt
	|		LEFT JOIN (SELECT
	|			CustomersSettlementsTurnovers.Counterparty AS Counterparty,
	|			COUNT(DISTINCT CustomersSettlementsTurnovers.Recorder) AS RecordersCount
	|		FROM
	|			AccumulationRegister.AccountsReceivable.Turnovers(
	|					&DateBeg,
	|					&BalanceDate,
	|					Recorder,
	|					Company = &Company
	|						AND Counterparty IN
	|							(SELECT
	|								TU_CounterpartiesAdvanceDebt.Counterparty
	|							FROM
	|								TU_CounterpartiesAdvanceDebt AS TU_CounterpartiesAdvanceDebt)) AS CustomersSettlementsTurnovers
	|		
	|		GROUP BY
	|			CustomersSettlementsTurnovers.Counterparty) AS NestedSelect
	|		ON TU_CounterpartiesAdvanceDebt.Counterparty = NestedSelect.Counterparty";
	
	Query = New Query;
	Query.Text = QueryText;
						  
	Query.SetParameter("DateBeg",		New Boundary(BeginOfPeriod, BoundaryType.Including));					  
	Query.SetParameter("BalanceDate",	New Boundary(EndOfDay(EndOfPeriod), BoundaryType.Including));
	Query.SetParameter("Company",		Company);
	
	If CounterpartyFilter = Undefined Then
		Query.Text = StrReplace(QueryText, "&CounterpartyFilter", "TRUE");	
	Else
		Query.Text = StrReplace(QueryText, "&CounterpartyFilter", "Counterparty = &CounterpartyFilter");	
		Query.SetParameter("CounterpartyFilter", CounterpartyFilter);
	EndIf;
						  
	QueryResult = Query.Execute();
	
	Return QueryResult.Unload();

EndFunction

// Procedure initializes data filling by the Exchange rate differences section and puts out the data to DocumentResult.
// 
&AtServer
Procedure Attachable_OutputDataBySectionExchangeDifferences(TemplateOutput)
	
	If Not ExchangeRatesDifferencesFilledWith Then
		OutputPictureDataOutput(TemplateOutput);		
		FillDataByExchangeRateDifferences();
		ExchangeRatesDifferencesFilledWith = True;
	EndIf;
	
	OutputSectionTitle(TemplateOutput);
	
	If IncorrectExchangeDifferencesDC.GetItems().Count() = 0 AND 
		IncorrectExchangeDifferencesCustomers.GetItems().Count() = 0 AND
		IncorrectExchangeDifferencesSuppliers.GetItems().Count() = 0 Then
		
		OutputAreaNoData(TemplateOutput);
		OutputAreaUpdateDataByGeneratedSection(TemplateOutput);		
		Return;
	
	EndIf;
	
	HasErrorsOnCD = False;
	
	RowsAccountCash = IncorrectExchangeDifferencesDC.GetItems();
	
	If RowsAccountCash.Count() > 0 Then
		
		HasErrorsOnCD = True;
		
		TemplateArea = TemplateOutput.GetArea("StringNotProcessedExchangeDifferences_CA");
		ResultDocument.Put(TemplateArea);
		
		For Each TreeRow In RowsAccountCash Do
			
			TemplateArea = TemplateOutput.GetArea("CD_AccountCashRegisters");
			TemplateArea.Parameters.ObjectKR_DC = TrimAll(TreeRow.BankAccountPettyCash.Description);
			TemplateArea.Parameters.ObjectKR_DC_Details = "ExecuteProcedureOnClient#OutputReportExchangeRatesDifferencesCash(CurArea, PredefineVariant, DataBeenChanged)";
			TemplateArea.Area(2,1,2,1).Mask = String(TreeRow.BankAccountPettyCash.UUID());
			ResultDocument.Put(TemplateArea);
		
		EndDo; 
		
	EndIf;
	
	RowsCustomers = IncorrectExchangeDifferencesCustomers.GetItems();
	
	If RowsCustomers.Count() > 0 Then
		
		HasErrorsOnCD = True;
	
		TemplateArea = TemplateOutput.GetArea("StringNotProcessedExchangeDifferences_Customers");
		ResultDocument.Put(TemplateArea);
		
		For Each TreeRow In RowsCustomers Do
			
			TemplateArea = TemplateOutput.GetArea("CD_Customers");
			TemplateArea.Parameters.ObjectKR_Customers = TrimAll(TreeRow.Counterparty.Description);
			TemplateArea.Parameters.ObjectKR_Customers_Details = "ExecuteProcedureOnClient#GenerateReportDataTableExchangeRatesDifferencesCustomers(CurArea, PredefineVariant, DataBeenChanged)";
			TemplateArea.Area(2,1,2,1).Mask = String(TreeRow.Counterparty.UUID());
			ResultDocument.Put(TemplateArea);
		
		EndDo;
	
	EndIf;
	
	RowsVendors = IncorrectExchangeDifferencesSuppliers.GetItems();
	
	If RowsVendors.Count() > 0 Then
		
		HasErrorsOnCD = True;
		
		TemplateArea = TemplateOutput.GetArea("StringNotProcessedExchangeDifferences_Vendors");
		ResultDocument.Put(TemplateArea);
		
		For Each TreeRow In RowsVendors Do
		
			TemplateArea = TemplateOutput.GetArea("CD_Vendors");
			TemplateArea.Parameters.ObjectKR_Vendors = TrimAll(TreeRow.Counterparty.Description);
			TemplateArea.Parameters.ObjectKR_Vendors_Details = "ExecuteProcedureOnClient#OutputReportExchangeRatesDifferencesVendors(CurArea, PredefineVariant, DataBeenChanged)";
			TemplateArea.Area(2,1,2,1).Mask = String(TreeRow.Counterparty.UUID());
			ResultDocument.Put(TemplateArea);
			
		EndDo; 
	
	EndIf;
	
	If ExchangeDifferencesDocumentsPereprovedeny Then
		
		If HasErrorsOnCD Then
			
			TemplateArea = TemplateOutput.GetArea("StringExchangeDifferences_ErrorsAfterReposting");
			ResultDocument.Put(TemplateArea);
			
		Else
			
			TemplateArea = TemplateOutput.GetArea("StringProcessedExchangeDifferences");
			ResultDocument.Put(TemplateArea);
			
		EndIf;
		
	Else
		
		TemplateArea = TemplateOutput.GetArea("RunRepostingExchanging");
		TemplateArea.Parameters.ExecuteAction = "Fill reposting";
		TemplateArea.Parameters.ExecuteActionDecrypt = "ExecuteProcedure#Attachable_ExecuteRepostByExchangeRatesDifferences(PredefineVariant, DataBeenChanged)";
		ResultDocument.Put(TemplateArea);
		
	EndIf;
	
	OutputAreaUpdateDataByGeneratedSection(TemplateOutput);
	
EndProcedure

// Procedure fills in data by the Exchange rate differences section.
//
&AtServer
Procedure FillDataByExchangeRateDifferences(ResultsArray = Undefined)
	
	DaysTable = New ValueTable;
	DaysTable.Columns.Add("DateDay", New TypeDescription("Date"));
	
	CurDate = BeginOfPeriod;
	EndDate = EndOfPeriod;
	
	While CurDate <= EndDate Do
		NewRow = DaysTable.Add();
		NewRow.DateDay = CurDate;
		CurDate = CurDate + 24*60*60;
	EndDo;
	
	MonthBeginDate = BeginOfPeriod;
	MonthEndDate = EndOfDay(EndOfPeriod);
	
	MonthBeginBoundary = New Boundary(MonthBeginDate, BoundaryType.Including);
	MonthEndBoundary = New Boundary(MonthEndDate, BoundaryType.Including);
	
	Query = New Query("SELECT
	                      |	PeriodDaysTable.DateDay
	                      |INTO TU_PeriodDaysTable
	                      |FROM
	                      |	&PeriodDaysTable AS PeriodDaysTable
	                      |;
	                      |
	                      |////////////////////////////////////////////////////////////////////////////////
	                      |SELECT
	                      |	ExchangeRatesSliceLast.Period,
	                      |	ExchangeRatesSliceLast.Currency,
	                      |	ExchangeRatesSliceLast.ExchangeRate,
	                      |	ExchangeRatesSliceLast.Multiplicity
	                      |INTO TU_ExchangeRatesForPeriod
	                      |FROM
	                      |	InformationRegister.ExchangeRates.SliceLast(&MonthBeginDate, ) AS ExchangeRatesSliceLast
	                      |
	                      |UNION
	                      |
	                      |SELECT
	                      |	ExchangeRates.Period,
	                      |	ExchangeRates.Currency,
	                      |	ExchangeRates.ExchangeRate,
	                      |	ExchangeRates.Multiplicity
	                      |FROM
	                      |	InformationRegister.ExchangeRates AS ExchangeRates
	                      |WHERE
	                      |	ExchangeRates.Period between &MonthBeginDate AND &MonthEndDate
	                      |;
	                      |
	                      |////////////////////////////////////////////////////////////////////////////////
	                      |SELECT
	                      |	ExchangeRatesCurrenciesSettingsPeriods.DateDay,
	                      |	ExchangeRatesCurrenciesSettingsPeriods.Currency,
	                      |	TU_ExchangeRatesForPeriod.ExchangeRate,
	                      |	TU_ExchangeRatesForPeriod.Multiplicity
	                      |INTO TU_ExchangeRatesByDates
	                      |FROM
	                      |	(SELECT
	                      |		TU_PeriodDaysTable.DateDay AS DateDay,
	                      |		TU_ExchangeRatesForPeriod.Currency AS Currency,
	                      |		MAX(TU_ExchangeRatesForPeriod.Period) AS Period
	                      |	FROM
	                      |		TU_PeriodDaysTable AS TU_PeriodDaysTable
	                      |			LEFT JOIN TU_ExchangeRatesForPeriod AS TU_ExchangeRatesForPeriod
	                      |			ON TU_PeriodDaysTable.DateDay >= TU_ExchangeRatesForPeriod.Period
	                      |	
	                      |	GROUP BY
	                      |		TU_PeriodDaysTable.DateDay,
	                      |		TU_ExchangeRatesForPeriod.Currency) AS ExchangeRatesCurrenciesSettingsPeriods
	                      |		LEFT JOIN TU_ExchangeRatesForPeriod AS TU_ExchangeRatesForPeriod
	                      |		ON ExchangeRatesCurrenciesSettingsPeriods.Currency = TU_ExchangeRatesForPeriod.Currency
	                      |			AND ExchangeRatesCurrenciesSettingsPeriods.Period = TU_ExchangeRatesForPeriod.Period
	                      |;
	                      |
	                      |////////////////////////////////////////////////////////////////////////////////
	                      |SELECT
	                      |	TU_ExchangeRatesByDates.DateDay AS DateDay,
	                      |	TU_ExchangeRatesByDates.Currency,
	                      |	TU_ExchangeRatesByDates.ExchangeRate,
	                      |	TU_ExchangeRatesByDates.Multiplicity
	                      |INTO TU_AccountCurrencyCourses
	                      |FROM
	                      |	(SELECT
	                      |		ConstantAccountingCurrency.Value AS PresentationCurrency
	                      |	FROM
	                      |		Constant.PresentationCurrency AS ConstantAccountingCurrency) AS ConstantAccountingCurrency
	                      |		INNER JOIN TU_ExchangeRatesByDates AS TU_ExchangeRatesByDates
	                      |		ON ConstantAccountingCurrency.PresentationCurrency = TU_ExchangeRatesByDates.Currency
	                      |;
	                      |
	                      |////////////////////////////////////////////////////////////////////////////////
	                      |SELECT
	                      |	ExchangeRates.DateDay,
	                      |	ExchangeRates.Currency,
	                      |	ExchangeRates.ExchangeRate,
	                      |	ExchangeRates.Multiplicity,
	                      |	ExchangeRates.RateTracking,
	                      |	ExchangeRates.AccountingMultiplicity,
	                      |	ExchangeRates.ExchangeRate / ExchangeRates.Multiplicity / (ExchangeRates.RateTracking / ExchangeRates.AccountingMultiplicity) AS CurrencyExchangeRateByExchangeRateTracking
	                      |INTO TU_ExchangeRates
	                      |FROM
	                      |	(SELECT
	                      |		TU_ExchangeRatesByDates.DateDay AS DateDay,
	                      |		TU_ExchangeRatesByDates.Currency AS Currency,
	                      |		TU_ExchangeRatesByDates.ExchangeRate AS ExchangeRate,
	                      |		TU_ExchangeRatesByDates.Multiplicity AS Multiplicity,
	                      |		TU_AccountCurrencyCourses.ExchangeRate AS RateTracking,
	                      |		TU_AccountCurrencyCourses.Multiplicity AS AccountingMultiplicity
	                      |	FROM
	                      |		TU_ExchangeRatesByDates AS TU_ExchangeRatesByDates
	                      |			INNER JOIN TU_AccountCurrencyCourses AS TU_AccountCurrencyCourses
	                      |			ON TU_ExchangeRatesByDates.DateDay = TU_AccountCurrencyCourses.DateDay) AS ExchangeRates
	                      |;
	                      |
	                      |////////////////////////////////////////////////////////////////////////////////
	                      |SELECT
	                      |	CoursesExtreme.Currency,
	                      |	CoursesExtreme.MaximumExchangeRate,
	                      |	CoursesExtreme.MinimumExchangeRate,
	                      |	TU_ExchangeRates.CurrencyExchangeRateByExchangeRateTracking AS ExchangeRateAtMonthBegin,
	                      |	CAST((CoursesExtreme.MaximumExchangeRate - TU_ExchangeRates.CurrencyExchangeRateByExchangeRateTracking) / TU_ExchangeRates.CurrencyExchangeRateByExchangeRateTracking * 100 AS NUMBER(10, 2)) AS UpperLimit,
	                      |	CAST((CoursesExtreme.MinimumExchangeRate - TU_ExchangeRates.CurrencyExchangeRateByExchangeRateTracking) / TU_ExchangeRates.CurrencyExchangeRateByExchangeRateTracking * 100 AS NUMBER(10, 2)) AS LowerLimit
	                      |FROM
	                      |	(SELECT
	                      |		MaximumExchangeRates.Currency AS Currency,
	                      |		MaximumExchangeRates.CurrencyExchangeRateByExchangeRateTracking AS MaximumExchangeRate,
	                      |		MinimumExchangeRates.CurrencyExchangeRateByExchangeRateTracking AS MinimumExchangeRate
	                      |	FROM
	                      |		(SELECT
	                      |			TU_ExchangeRates.Currency AS Currency,
	                      |			MAX(TU_ExchangeRates.CurrencyExchangeRateByExchangeRateTracking) AS CurrencyExchangeRateByExchangeRateTracking
	                      |		FROM
	                      |			TU_ExchangeRates AS TU_ExchangeRates
	                      |		
	                      |		GROUP BY
	                      |			TU_ExchangeRates.Currency) AS MaximumExchangeRates
	                      |			INNER JOIN (SELECT
	                      |				TU_ExchangeRates.Currency AS Currency,
	                      |				MIN(TU_ExchangeRates.CurrencyExchangeRateByExchangeRateTracking) AS CurrencyExchangeRateByExchangeRateTracking
	                      |			FROM
	                      |				TU_ExchangeRates AS TU_ExchangeRates
	                      |			
	                      |			GROUP BY
	                      |				TU_ExchangeRates.Currency) AS MinimumExchangeRates
	                      |			ON MaximumExchangeRates.Currency = MinimumExchangeRates.Currency
	                      |	WHERE
	                      |		MaximumExchangeRates.CurrencyExchangeRateByExchangeRateTracking <> MinimumExchangeRates.CurrencyExchangeRateByExchangeRateTracking) AS CoursesExtreme
	                      |		INNER JOIN TU_ExchangeRates AS TU_ExchangeRates
	                      |		ON (TU_ExchangeRates.Currency = CoursesExtreme.Currency)
	                      |			AND (TU_ExchangeRates.DateDay = &MonthBeginDate)
	                      |;
	                      |
	                      |////////////////////////////////////////////////////////////////////////////////
	                      |SELECT
	                      |	TU_ExchangeRates.DateDay AS DateDay,
	                      |	TU_ExchangeRates.Currency,
	                      |	TU_ExchangeRates.ExchangeRate,
	                      |	TU_ExchangeRates.Multiplicity,
	                      |	TU_ExchangeRates.RateTracking,
	                      |	TU_ExchangeRates.AccountingMultiplicity,
	                      |	TU_ExchangeRates.CurrencyExchangeRateByExchangeRateTracking
	                      |FROM
	                      |	TU_ExchangeRates AS TU_ExchangeRates
	                      |
	                      |ORDER BY
	                      |	DateDay");
						  
						  
	Query.SetParameter("PeriodDaysTable", DaysTable);
	Query.SetParameter("MonthBeginDate", MonthBeginDate);
	Query.SetParameter("MonthEndDate", MonthEndDate);
	
	ResultsArray = Query.ExecuteBatch();
	
	LimitsTable = ResultsArray[5].Unload();
	ExchangeRatesTable = ResultsArray[6].Unload();
	
	If LimitsTable.Count() = 0 Then //exchange rate did not change
		Return;	
	EndIf;  	
	
	ExchangeDifferences_DC(LimitsTable, MonthBeginDate, MonthEndDate);
	
	ExchangeDifferences_Customers(LimitsTable, MonthBeginDate, MonthEndDate);
	
	ExchangeDifferences_Vendors(LimitsTable, MonthBeginDate, MonthEndDate);

EndProcedure

&AtServer
Procedure ExchangeDifferences_DC(LimitsTable, MonthBeginDate, MonthEndDate)
	
	CashAccountsArray = New Array;
	
	Query = New Query("SELECT DISTINCT
	                  |	CashAssets.Recorder AS Recorder,
	                  |	CashAssets.CashAssetsType AS CashAssetsType,
	                  |	CashAssets.BankAccountPettyCash AS BankAccountPettyCash,
	                  |	CashAssets.Currency AS Currency,
	                  |	CashAssets.Period AS Period,
	                  |	SUM(CASE
	                  |			WHEN CashAssets.RecordType = VALUE(AccumulationRecordType.Expense)
	                  |				THEN -1 * CashAssets.Amount
	                  |			ELSE CashAssets.Amount
	                  |		END) AS AmountCD
	                  |FROM
	                  |	AccumulationRegister.CashAssets AS CashAssets
	                  |WHERE
	                  |	CashAssets.Company = &Company
	                  |	AND (CashAssets.ContentOfAccountingRecord = ""Exchange rate difference""
	                  |			OR CashAssets.ContentOfAccountingRecord = &CurrencyExchangeText)
	                  |	AND CashAssets.Period BETWEEN &MonthBeginDate AND &MonthEndDate
	                  |
	                  |GROUP BY
	                  |	CashAssets.Recorder,
	                  |	CashAssets.CashAssetsType,
	                  |	CashAssets.BankAccountPettyCash,
	                  |	CashAssets.Currency,
	                  |	CashAssets.Period
	                  |
	                  |ORDER BY
	                  |	Period");
						  
	Query.SetParameter("MonthBeginDate", MonthBeginDate);
	Query.SetParameter("MonthEndDate", MonthEndDate);
	Query.SetParameter("Company", Company);
	Query.SetParameter("CurrencyExchangeText", NStr("en = 'Foreign currency exchange gains and losses'"));
	
	CDMovementsTable = Query.Execute().Unload();
	
	BalanceQuery = New Query("SELECT
	                                |	CashAssetsBalances.AmountBalance AS BalanceBeforePosting
	                                |FROM
	                                |	AccumulationRegister.CashAssets.Balance(
	                                |			&DocumentMoment,
	                                |			Company = &Company
	                                |				AND CashAssetsType = &CashAssetsType
	                                |				AND BankAccountPettyCash = &BankAccountPettyCash
	                                |				AND Currency = &Currency) AS CashAssetsBalances");
																	
									
	For Each CDMovementsRow In CDMovementsTable Do
		
		BalanceQuery.SetParameter("DocumentMoment", CDMovementsRow.Recorder.PointInTime());
		BalanceQuery.SetParameter("Company", Company);
		BalanceQuery.SetParameter("CashAssetsType", CDMovementsRow.CashAssetsType);
		BalanceQuery.SetParameter("BankAccountPettyCash", CDMovementsRow.BankAccountPettyCash);
		BalanceQuery.SetParameter("Currency", CDMovementsRow.Currency);
		
		SelectionBalances = BalanceQuery.Execute().Select();
		
		If SelectionBalances.Next() Then
			
			If SelectionBalances.BalanceBeforePosting = 0 Then
				CDMovementsPercent = 0;
			Else
				CDMovementsPercent = Round(CDMovementsRow.AmountCD / SelectionBalances.BalanceBeforePosting * 100, 2);
			EndIf;
			
			LimitsRow = LimitsTable.Find(CDMovementsRow.Currency);
			
			If LimitsRow <> Undefined Then
				
				If CDMovementsPercent > 0 Then
					
					If (CDMovementsPercent - LimitsRow.UpperLimit) > 0.1 Then
						
						If (CashAccountsArray.Find(CDMovementsRow.BankAccountPettyCash) = Undefined) Then
							CashAccountsArray.Add(CDMovementsRow.BankAccountPettyCash);
						EndIf;	
						
					EndIf;
					
				ElsIf CDMovementsPercent < 0 Then
					
					If (LimitsRow.LowerLimit - CDMovementsPercent) > 0.1 Then
						
						If (CashAccountsArray.Find(CDMovementsRow.BankAccountPettyCash) = Undefined) Then
							CashAccountsArray.Add(CDMovementsRow.BankAccountPettyCash);
						EndIf;	
						
					EndIf;	
					
				EndIf;
				
			EndIf;
		
		Else
			
			Continue;
			
		EndIf;
	
	EndDo;
	
	If CashAccountsArray.Count() > 0 Then
		
		Query = New Query("SELECT DISTINCT
		                      |	CashAssets.BankAccountPettyCash AS BankAccountPettyCash,
		                      |	CashAssets.Recorder AS Recorder,
		                      |	CashAssets.Period AS Period
		                      |FROM
		                      |	AccumulationRegister.CashAssets AS CashAssets
		                      |WHERE
		                      |	CashAssets.Period between &MonthBeginDate AND &MonthEndDate
		                      |	AND CashAssets.BankAccountPettyCash IN(&CashAccountsArray)
		                      |	AND CashAssets.Company = &Company
		                      |
		                      |ORDER BY
		                      |	Period
		                      |TOTALS BY
		                      |	BankAccountPettyCash,
		                      |	Recorder");
							  
		Query.SetParameter("Company", Company);
		Query.SetParameter("CashAccountsArray", CashAccountsArray);
		Query.SetParameter("MonthBeginDate", MonthBeginDate);
		Query.SetParameter("MonthEndDate", MonthEndDate);
		
		QueryResult = Query.Execute();
		
		ValueToFormAttribute(QueryResult.Unload(QueryResultIteration.ByGroups), "IncorrectExchangeDifferencesDC");
		
	EndIf;

EndProcedure

&AtServer
Procedure ExchangeDifferences_Customers(LimitsTable, MonthBeginDate, MonthEndDate)	
	
	CustomersArray = New Array;
	
	Query = New Query("SELECT
	                      |	AccountsReceivable.Recorder,
	                      |	AccountsReceivable.SettlementsType,
	                      |	AccountsReceivable.Counterparty,
	                      |	AccountsReceivable.Contract,
	                      |	AccountsReceivable.Document,
	                      |	AccountsReceivable.Order,
	                      |	SUM(CASE
	                      |			WHEN AccountsReceivable.RecordType = VALUE(AccumulationRecordType.Expense)
	                      |				THEN -1 * BankAccountsReceivable.Amount
	                      |			ELSE AccountsReceivable.Amount
	                      |		END) AS AmountCD,
	                      |	AccountsReceivable.Period AS Period,
	                      |	AccountsReceivable.Contract.SettlementsCurrency AS Currency
	                      |FROM
	                      |	AccumulationRegister.AccountsReceivable AS AccountsReceivable
	                      |WHERE
	                      |	AccountsReceivable.Company = &Company
	                      |	AND AccountsReceivable.ContentOfAccountingRecord = ""Exchange rate difference""
	                      |	AND AccountsReceivable.Period between &MonthBeginDate AND &MonthEndDate
	                      |
	                      |GROUP BY
	                      |	AccountsReceivable.Recorder,
	                      |	AccountsReceivable.SettlementsType,
	                      |	AccountsReceivable.Counterparty,
	                      |	AccountsReceivable.Contract,
	                      |	AccountsReceivable.Document,
	                      |	AccountsReceivable.Order,
	                      |	AccountsReceivable.Period
	                      |
	                      |ORDER BY
	                      |	Period");	
	
	Query.SetParameter("MonthBeginDate", MonthBeginDate);
	Query.SetParameter("MonthEndDate", MonthEndDate);
	Query.SetParameter("Company", Company);
	
	CDMovementsTable = Query.Execute().Unload();
	
	BalanceQuery = New Query("SELECT
	                                |	AccountsReceivableBalances.AmountBalance AS BalanceBeforePosting
	                                |FROM
	                                |	AccumulationRegister.AccountsReceivable.Balance(
	                                |			&DocumentMoment,
	                                |			Contract = &Contract
	                                |				AND Document = &Document
	                                |				AND Order = &Order
	                                |				AND Counterparty = &Counterparty
	                                |				AND Company = &Company
	                                |				AND SettlementsType = &SettlementsType) AS AccountsReceivableBalances");
	
	For Each CDMovementsRow In CDMovementsTable Do
		
		BalanceQuery.SetParameter("DocumentMoment", CDMovementsRow.Recorder.PointInTime());
		BalanceQuery.SetParameter("Contract", CDMovementsRow.Contract);
		BalanceQuery.SetParameter("Document", CDMovementsRow.Document);
		BalanceQuery.SetParameter("Order", CDMovementsRow.Order);
		BalanceQuery.SetParameter("Counterparty", CDMovementsRow.Counterparty);
		BalanceQuery.SetParameter("Company", Company);
		BalanceQuery.SetParameter("SettlementsType", CDMovementsRow.SettlementsType);
		
		SelectionBalances = BalanceQuery.Execute().Select();
		
		If SelectionBalances.Next() Then
			
			If SelectionBalances.BalanceBeforePosting = 0 Then
				CDMovementsPercent = 0;
			Else
				CDMovementsPercent = Round(CDMovementsRow.AmountCD / SelectionBalances.BalanceBeforePosting * 100, 2);
			EndIf;
			
			LimitsRow = LimitsTable.Find(CDMovementsRow.Currency);
			
			If LimitsRow <> Undefined Then
				
				If CDMovementsPercent > 0 Then
					
					If (CDMovementsPercent - LimitsRow.UpperLimit) > 0.1 Then
						
						If (CustomersArray.Find(CDMovementsRow.Counterparty) = Undefined) Then
							CustomersArray.Add(CDMovementsRow.Counterparty);
						EndIf;	
						
					EndIf;
					
				ElsIf CDMovementsPercent < 0 Then
					
					If (LimitsRow.LowerLimit - CDMovementsPercent) > 0.1 Then
						
						If (CustomersArray.Find(CDMovementsRow.Counterparty) = Undefined) Then
							CustomersArray.Add(CDMovementsRow.Counterparty);
						EndIf;	
						
					EndIf;	
					
				EndIf;
				
			EndIf;
		
		Else
			
			Continue;
			
		EndIf;
		
	EndDo;	
									
	If CustomersArray.Count() > 0 Then
	
		Query = New Query("SELECT DISTINCT
		                      |	AccountsReceivable.Counterparty AS Counterparty,
		                      |	AccountsReceivable.Recorder AS Recorder,
		                      |	AccountsReceivable.Period AS Period
		                      |FROM
		                      |	AccumulationRegister.AccountsReceivable AS AccountsReceivable
		                      |WHERE
		                      |	AccountsReceivable.Period between &MonthBeginDate AND &MonthEndDate
		                      |	AND AccountsReceivable.Company = &Company
		                      |	AND AccountsReceivable.Counterparty IN(&CustomersArray)
		                      |
		                      |ORDER BY
		                      |	Period
		                      |TOTALS BY
		                      |	Counterparty,
		                      |	Recorder");
		
		Query.SetParameter("MonthBeginDate", MonthBeginDate);
		Query.SetParameter("MonthEndDate", MonthEndDate);
		Query.SetParameter("Company", Company);
		Query.SetParameter("CustomersArray", CustomersArray);
							  
		QueryResult = Query.Execute();
		
		ValueToFormAttribute(QueryResult.Unload(QueryResultIteration.ByGroups), "IncorrectExchangeDifferencesCustomers");	
	
	EndIf;

EndProcedure

&AtServer
Procedure ExchangeDifferences_Vendors(LimitsTable, MonthBeginDate, MonthEndDate)

	VendorsArray = New Array;
	
	Query = New Query("SELECT
	                      |	AccountsPayable.Recorder,
	                      |	AccountsPayable.SettlementsType,
	                      |	AccountsPayable.Counterparty,
	                      |	AccountsPayable.Contract,
	                      |	AccountsPayable.Document,
	                      |	AccountsPayable.Order,
	                      |	SUM(CASE
	                      |			WHEN AccountsPayable.RecordType = VALUE(AccumulationRecordType.Expense)
	                      |				THEN -1 * BankAccountsPayable.Amount
	                      |			ELSE AccountsPayable.Amount
	                      |		END) AS AmountCD,
	                      |	AccountsPayable.Period AS Period,
	                      |	AccountsPayable.Contract.SettlementsCurrency AS Currency
	                      |FROM
	                      |	AccumulationRegister.AccountsPayable AS AccountsPayable
	                      |WHERE
	                      |	AccountsPayable.Company = &Company
	                      |	AND AccountsPayable.ContentOfAccountingRecord = ""Exchange rate difference""
	                      |	AND AccountsPayable.Period between &MonthBeginDate AND &MonthEndDate
	                      |
	                      |GROUP BY
	                      |	AccountsPayable.Recorder,
	                      |	AccountsPayable.SettlementsType,
	                      |	AccountsPayable.Counterparty,
	                      |	AccountsPayable.Contract,
	                      |	AccountsPayable.Document,
	                      |	AccountsPayable.Order,
	                      |	AccountsPayable.Period,
	                      |	AccountsPayable.Contract.SettlementsCurrency
	                      |
	                      |ORDER BY
	                      |	Period");	
	
	Query.SetParameter("MonthBeginDate", MonthBeginDate);
	Query.SetParameter("MonthEndDate", MonthEndDate);
	Query.SetParameter("Company", Company);
	
	CDMovementsTable = Query.Execute().Unload();
	
	BalanceQuery = New Query("SELECT
	                                |	AccountsPayableBalances.AmountBalance AS BalanceBeforePosting
	                                |FROM
	                                |	AccumulationRegister.AccountsPayable.Balance(
	                                |			&DocumentMoment,
	                                |			Contract = &Contract
	                                |				AND Document = &Document
	                                |				AND Order = &Order
	                                |				AND Counterparty = &Counterparty
	                                |				AND Company = &Company
	                                |				AND SettlementsType = &SettlementsType) AS AccountsPayableBalances");
	
	For Each CDMovementsRow In CDMovementsTable Do
		
		BalanceQuery.SetParameter("DocumentMoment", CDMovementsRow.Recorder.PointInTime());
		BalanceQuery.SetParameter("Contract", CDMovementsRow.Contract);
		BalanceQuery.SetParameter("Document", CDMovementsRow.Document);
		BalanceQuery.SetParameter("Order", CDMovementsRow.Order);
		BalanceQuery.SetParameter("Counterparty", CDMovementsRow.Counterparty);
		BalanceQuery.SetParameter("Company", Company);
		BalanceQuery.SetParameter("SettlementsType", CDMovementsRow.SettlementsType);
		
		SelectionBalances = BalanceQuery.Execute().Select();
		
		If SelectionBalances.Next() Then
			
			If SelectionBalances.BalanceBeforePosting = 0 Then
				CDMovementsPercent = 0;
			Else
				CDMovementsPercent = Round(CDMovementsRow.AmountCD / SelectionBalances.BalanceBeforePosting * 100, 2);
			EndIf;
			
			LimitsRow = LimitsTable.Find(CDMovementsRow.Currency);
			
			If LimitsRow <> Undefined Then
				
				If CDMovementsPercent > 0 Then
					
					If (CDMovementsPercent - LimitsRow.UpperLimit) > 0.1 Then
						
						If (VendorsArray.Find(CDMovementsRow.Counterparty) = Undefined) Then
							VendorsArray.Add(CDMovementsRow.Counterparty);
						EndIf;	
						
					EndIf;
					
				ElsIf CDMovementsPercent < 0 Then
					
					If (LimitsRow.LowerLimit - CDMovementsPercent) > 0.1 Then
						
						If (VendorsArray.Find(CDMovementsRow.Counterparty) = Undefined) Then
							VendorsArray.Add(CDMovementsRow.Counterparty);
						EndIf;	
						
					EndIf;	
					
				EndIf;
				
			EndIf;
		
		Else
			
			Continue;
			
		EndIf;
		
	EndDo;	
									
	If VendorsArray.Count() > 0 Then
	
		Query = New Query("SELECT DISTINCT
		                      |	AccountsPayable.Counterparty AS Counterparty,
		                      |	AccountsPayable.Recorder AS Recorder,
		                      |	AccountsPayable.Period AS Period
		                      |FROM
		                      |	AccumulationRegister.AccountsPayable AS AccountsPayable
		                      |WHERE
		                      |	AccountsPayable.Period between &MonthBeginDate AND &MonthEndDate
		                      |	AND AccountsPayable.Company = &Company
		                      |	AND AccountsPayable.Counterparty IN(&CustomersArray)
		                      |
		                      |ORDER BY
		                      |	Period
		                      |TOTALS BY
		                      |	Counterparty,
		                      |	Recorder");
		
		Query.SetParameter("MonthBeginDate", MonthBeginDate);
		Query.SetParameter("MonthEndDate", MonthEndDate);
		Query.SetParameter("Company", Company);
		Query.SetParameter("VendorsArray", VendorsArray);
							  
		QueryResult = Query.Execute();
		
		ValueToFormAttribute(QueryResult.Unload(QueryResultIteration.ByGroups), "IncorrectExchangeDifferencesSuppliers");	
	
	EndIf;

EndProcedure

// Procedure initializes data filling by the Products without specification section and puts out the data to DocumentResult.
// 
&AtServer
Procedure Attachable_OutputDataBySectionProductsWithoutBillsOfMaterials(TemplateOutput)
	
	If Not ProductsWithoutFilledWithBillsOfMaterials Then
		OutputPictureDataOutput(TemplateOutput);
		FillDataByProductsWithoutBillsOfMaterials();
		ProductsWithoutFilledWithBillsOfMaterials = True;
	EndIf;
	
	OutputSectionTitle(TemplateOutput);
	
	If ProductsWithoutBillsOfMaterials.Count() = 0 Then
		OutputAreaNoData(TemplateOutput);
		OutputAreaUpdateDataByGeneratedSection(TemplateOutput);
		Return;
	EndIf;

	TemplateArea = TemplateOutput.GetArea("StringCommentsTop");
	TemplateArea.Parameters.Comment = "Records of the Products catalog were found in the accounting system with BillsOfMaterials created for them. Default specification is not specified for some products positions.";
	ResultDocument.Put(TemplateArea);
	
	
	For Each TableRow In ProductsWithoutBillsOfMaterials Do
		
		If TableRow.DataProcessorExecuted Then
			
			TemplateArea = TemplateOutput.GetArea("StringProcessedBillsOfMaterials");
			TemplateArea.Parameters.Fill(TableRow);
			TemplateArea.Parameters.ResultAnalysis = "Open specification";
			TemplateArea.Parameters.AnalysisResultDecrypt = TableRow.Specification;
			
		Else	
			
			TemplateArea = TemplateOutput.GetArea("StringNotProcessedBillsOfMaterials");
			TemplateArea.Parameters.Fill(TableRow);
			
			If TableRow.BillsOfMaterialsAmount = 1 Then
				TemplateArea.Parameters.ResultAnalysis = "Open specification";
				TemplateArea.Parameters.AnalysisResultDecrypt = TableRow.Specification;
				TemplateArea.Parameters.ExecuteAction = "Set default specification";
				TemplateArea.Parameters.ExecuteActionDecrypt = "ExecuteProcedure#Attachable_SetDefaultSpecification(CurArea, PredefineVariant, DataBeenChanged)";
			Else
				TemplateArea.Parameters.ResultAnalysis = "Several BillsOfMaterials are found";
				TemplateArea.Parameters.AnalysisResultDecrypt = "ExecuteProcedureOnClient#OpenBillsOfMaterialsList(CurArea, PredefineVariant, DataBeenChanged)";
				TemplateArea.Parameters.ExecuteAction = "Select and set specification";
				TemplateArea.Parameters.ExecuteActionDecrypt = "ExecuteProcedureOnClient#SelectSetDefaultSpecification(CurArea, PredefineVariant, DataBeenChanged)";
			EndIf;
			
		EndIf;
		
		ResultDocument.Put(TemplateArea);
		
	EndDo;
	
	OutputAreaUpdateDataByGeneratedSection(TemplateOutput);
	
EndProcedure

// Procedure implements the mechanism of data control by the Products without BillsOfMaterials section.
//
&AtServer
Procedure FillDataByProductsWithoutBillsOfMaterials()

	Query = New Query("SELECT
	                      |	BillsOfMaterials.Owner AS Products,
	                      |	BillsOfMaterials.Ref AS Specification,
	                      |	1 AS BillsOfMaterialsAmount
	                      |FROM
	                      |	Catalog.BillsOfMaterials AS BillsOfMaterials
	                      |WHERE
	                      |	BillsOfMaterials.Owner.Specification = VALUE(Catalog.BillsOfMaterials.EmptyRef)
	                      |TOTALS
	                      |	SUM(BillsOfMaterialsAmount)
	                      |BY
	                      |	Products,
	                      |	Specification");
						  
	DataTable = FormAttributeToValue("ProductsWithoutBillsOfMaterials");
	DataTable.Clear();
	
	Selection = Query.Execute().Select(QueryResultIteration.ByGroups);
	
	While Selection.Next() Do
		
		If Selection.BillsOfMaterialsAmount = 1 Then
			
			SelectionSpecification = Selection.Select();
			
			SelectionSpecification.Next();
			
			NewRow = DataTable.Add();
			FillPropertyValues(NewRow, SelectionSpecification);
			
		Else
			
			NewRow = DataTable.Add();
			NewRow.Products = Selection.Products;
			NewRow.BillsOfMaterialsAmount = Selection.BillsOfMaterialsAmount;
			
		EndIf;
		
	EndDo;
	
	ValueToFormAttribute(DataTable, "ProductsWithoutBillsOfMaterials"); 

EndProcedure

// Procedure initializes data filling by the Subcontractor reports without BillsOfMaterials section and puts out the
// data to DocumentResult.
// 
&AtServer
Procedure Attachable_OutputDataBySectionReportsProcWithoutBillsOfMaterials(TemplateOutput)
	
	If Not ReportsPereireWithoutFilledBillsOfMaterials Then
		OutputPictureDataOutput(TemplateOutput);
		FillDataByReportsProcWithoutBillsOfMaterials();
		ReportsPereireWithoutFilledBillsOfMaterials = True;	
	EndIf;
	
	OutputSectionTitle(TemplateOutput);
	
	If SubcontractorBillsOfMaterialsReports.Count() = 0 Then
		OutputAreaNoData(TemplateOutput);
		OutputAreaUpdateDataByGeneratedSection(TemplateOutput);
		Return;		
	EndIf;
	
	TemplateArea = TemplateOutput.GetArea("StringCommentsTop");
	TemplateArea.Parameters.Comment = "Over the review period, posted documents of the Subcontractor report kind were found that do not have BillsOfMaterials in them. Default specification is set for products items specified in these documents as the goods.";
	ResultDocument.Put(TemplateArea);
	
	DataTable = FormAttributeToValue("SubcontractorBillsOfMaterialsReports");
	
	For Each TableRow In DataTable Do
		
		If Not TableRow.DataProcessorExecuted Then
			
			TemplateArea = TemplateOutput.GetArea("StringNotProcessedReportReprocessing");
			
			TemplateArea.Parameters.ExecuteAction = "Set a specification";
			TemplateArea.Parameters.ExecuteActionDecrypt = "ExecuteProcedure#Attachable_SetSpecificationToProcReport(CurArea, PredefineVariant, DataBeenChanged)";
			
		Else
			
			TemplateArea = TemplateOutput.GetArea("StringProcessedReportReprocessing");	
			
		EndIf;
		
		TemplateArea.Parameters.ResultAnalysis = "Open specification";
		TemplateArea.Parameters.AnalysisResultDecrypt = TableRow.Specification;
		
		DocumentPresentation = GenerateDocumentPresentation(TableRow.DocumentRef);
												
		TemplateArea.Parameters.DocumentRef = TableRow.DocumentRef;
		TemplateArea.Parameters.DocumentPresentation = DocumentPresentation;
		
		ResultDocument.Put(TemplateArea);
		
	EndDo;
	
	OutputAreaUpdateDataByGeneratedSection(TemplateOutput);
	
EndProcedure

// Procedure implements mechanism of data control by the Subcontractors reports without BillsOfMaterials section.
//
&AtServer
Procedure FillDataByReportsProcWithoutBillsOfMaterials()

	Query = New Query("SELECT
	                      |	SubcontractorReport.Ref AS DocumentRef,
	                      |	SubcontractorReport.Products.Specification AS Specification,
	                      |	SubcontractorReport.Date,
	                      |	FALSE AS DataProcessorExecuted
	                      |FROM
	                      |	Document.SubcontractorReport AS SubcontractorReport
	                      |WHERE
	                      |	SubcontractorReport.Date between &DateBeg AND &DateEnd
	                      |	AND SubcontractorReport.Posted = TRUE
	                      |	AND SubcontractorReport.Products.Specification <> VALUE(Catalog.BillsOfMaterials.EmptyRef)
	                      |	AND SubcontractorReport.Specification = VALUE(Catalog.BillsOfMaterials.EmptyRef)
	                      |	AND CASE
	                      |			WHEN Not &RunAccountingBySubsidiaryCompany
	                      |				THEN SubcontractorReport.Company = &Company
	                      |			ELSE TRUE
	                      |		END");
						  
	Query.SetParameter("Company", Company);					  
	Query.SetParameter("DateBeg", BegOfDay(BeginOfPeriod));
	Query.SetParameter("DateEnd", EndOfDay(EndOfPeriod));
	Query.SetParameter("RunAccountingBySubsidiaryCompany", RunAccountingBySubsidiaryCompany);
	
	ValueToFormAttribute(Query.Execute().Unload(), "SubcontractorBillsOfMaterialsReports");	

EndProcedure

// Procedure initializes data filling by the Subcontractors report section - mismatch of writeoffs to BillsOfMaterials
// and outputs data to DocumentResult.
// 
&AtServer
Procedure Attachable_OutputDataBySectionReportsReprocWriteOffsMismatch(TemplateOutput)
	
	If Not SubcontractorFilledWithInconsistenciesReports Then
		OutputPictureDataOutput(TemplateOutput);
		FillDataByReportsReprocWriteoffsMismatch();
		SubcontractorFilledWithInconsistenciesReports = True;	
	EndIf;
	
	OutputSectionTitle(TemplateOutput);
	
	DataTable = FormAttributeToValue("SubcontractorInconsistenciesReports");
	
	If DataTable.Count() = 0 Then
		OutputAreaNoData(TemplateOutput);
		OutputAreaUpdateDataByGeneratedSection(TemplateOutput);		
		Return;		
	EndIf;
	
	TemplateArea = TemplateOutput.GetArea("StringCommentsTop");
	TemplateArea.Parameters.Comment = "Over the review period posted documents of the Subcontractor report kind were found in which the written off inventory does not correspond to the specification.";
	ResultDocument.Put(TemplateArea);
	
	For Each TableRow In DataTable Do
		
		If Not TableRow.DataProcessorExecuted Then
			
			TemplateArea = TemplateOutput.GetArea("StringNotProcessedReportReprocessing");
			
			TemplateArea.Parameters.ResultAnalysis = "Mismatch is found";
			TemplateArea.Parameters.AnalysisResultDecrypt = "ExecuteProcedureOnClient#OutputReportByMismatchProcReport(CurArea, PredefineVariant, DataBeenChanged)";
			
			TemplateArea.Parameters.ExecuteAction = "Refill and repost";
			TemplateArea.Parameters.ExecuteActionDecrypt = "ExecuteProcedure#Attachable_CorrectNoncorrReportProc(PredefineVariant, DataBeenChanged)";
			
		Else
			
			TemplateArea = TemplateOutput.GetArea("StringProcessedReportReprocessing");
			
			TemplateArea.Parameters.ResultAnalysis = "Corrected";
			TemplateArea.Parameters.AnalysisResultDecrypt = TableRow.DocumentRef;
			
		EndIf;
		
		DocumentPresentation = GenerateDocumentPresentation(TableRow.DocumentRef);
												
		TemplateArea.Parameters.DocumentRef = TableRow.DocumentRef;
		TemplateArea.Parameters.DocumentPresentation = DocumentPresentation;
		
		ResultDocument.Put(TemplateArea);		
		
	EndDo;
	
	OutputAreaUpdateDataByGeneratedSection(TemplateOutput);
	
EndProcedure

// Procedure implements a mechanism of the data control by the Handlers reports section - mismatch of writeoffs to BillsOfMaterials.
//
&AtServer
Procedure FillDataByReportsReprocWriteoffsMismatch()
	
	Query = New Query("SELECT
	                      |	SubcontractorReport.Ref AS DocumentRef,
	                      |	SubcontractorReport.MeasurementUnit,
	                      |	SubcontractorReport.Specification,
	                      |	SubcontractorReport.Quantity
	                      |FROM
	                      |	Document.SubcontractorReport AS SubcontractorReport
	                      |WHERE
	                      |	SubcontractorReport.Posted = TRUE
	                      |	AND CASE
	                      |			WHEN Not &RunAccountingBySubsidiaryCompany
	                      |				THEN SubcontractorReport.Company = &Company
	                      |			ELSE TRUE
	                      |		END
	                      |	AND SubcontractorReport.Date between &DateBeg AND &DateEnd
	                      |	AND SubcontractorReport.Specification <> VALUE(Catalog.BillsOfMaterials.EmptyRef)
	                      |
	                      |ORDER BY
	                      |	SubcontractorReport.Date");
						  
	Query.SetParameter("Company", Company);
	Query.SetParameter("DateBeg", BeginOfPeriod);
	Query.SetParameter("DateEnd", EndOfDay(EndOfPeriod));
	Query.SetParameter("RunAccountingBySubsidiaryCompany", RunAccountingBySubsidiaryCompany);
	
	DocumentsTable = Query.Execute().Unload();
	
	For Each TableRow In DocumentsTable Do
		
		TableInventory = TableRow.DocumentRef.Inventory.Unload();
		TableInventory.GroupBy("Products,Characteristic", "Quantity");
		
		TableInventory.Columns.Quantity.Name = "QuantityInFact";
		
		TableInventory.Columns.Add("Quantity", New TypeDescription("Number"));
	
		
		FillTableBySpecificationProcReport(TableRow.Specification, TableRow.Quantity, TableRow.MeasurementUnit);
		
		TableInventory.GroupBy("Products, Characteristic", "Quantity, ActualQuantity");
		
		TableInventory.Columns.Quantity.Name = "QuantityOnSpecification";
		
		DataTablesRow = Undefined;
		
		For Each TableStringInventory In TableInventory Do
		
			If TableStringInventory.QuantityInFact <> TableStringInventory.QuantityOnSpecification Then
			
				If DataTablesRow = Undefined Then
					DataTablesRow = SubcontractorInconsistenciesReports.Add();
					DataTablesRow.DocumentRef = TableRow.DocumentRef;
				EndIf;
				
				NewRow = DataTablesRow.DifferencesTable.Add();
				
				FillPropertyValues(NewRow, TableStringInventory);
			
			EndIf;		
			
		EndDo;		
		
	EndDo;

EndProcedure

// Procedure from the
// SubcontractorReport document module places a table of inventory write-off to the InventoryTable variable according to
// the specification.
//
&AtServer
Procedure FillTableBySpecificationProcReport(BySpecification, RequiredQuantity, UsedMeasurementUnit)

	Query = New Query(
	"SELECT
	|	MAX(BillsOfMaterialsContent.LineNumber) AS BillsOfMaterialsContentLineNumber,
	|	BillsOfMaterialsContent.Products AS Products,
	|	BillsOfMaterialsContent.ContentRowType AS ContentRowType,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN BillsOfMaterialsContent.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	BillsOfMaterialsContent.MeasurementUnit AS MeasurementUnit,
	|	BillsOfMaterialsContent.Specification AS Specification,
	|	SUM(CASE
	|			WHEN VALUETYPE(&MeasurementUnit) = Type(Catalog.UOMClassifier)
	|				THEN BillsOfMaterialsContent.Quantity / BillsOfMaterialsContent.ProductsQuantity * &Quantity
	|			ELSE BillsOfMaterialsContent.Quantity / BillsOfMaterialsContent.ProductsQuantity * &Factor * &Quantity
	|		END) AS Quantity,
	|	BillsOfMaterialsContent.Products.VATRate AS VATRate
	|FROM
	|	Catalog.BillsOfMaterials.Content AS BillsOfMaterialsContent
	|WHERE
	|	BillsOfMaterialsContent.Ref = &Specification
	|	AND BillsOfMaterialsContent.Products.ProductsType = &ProductsType
	|
	|GROUP BY
	|	BillsOfMaterialsContent.Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN BillsOfMaterialsContent.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END,
	|	BillsOfMaterialsContent.MeasurementUnit,
	|	BillsOfMaterialsContent.Specification,
	|	BillsOfMaterialsContent.ContentRowType,
	|	BillsOfMaterialsContent.Products.MeasurementUnit,
	|	BillsOfMaterialsContent.Products.VATRate
	|
	|ORDER BY
	|	BillsOfMaterialsContentLineNumber");
	
	Query.SetParameter("UseCharacteristics", Constants.UseCharacteristics.Get());
	
	Query.SetParameter("Specification", BySpecification);
	Query.SetParameter("Quantity", RequiredQuantity);
	
	Query.SetParameter("MeasurementUnit", UsedMeasurementUnit);
	
	If TypeOf(UsedMeasurementUnit) = Type("CatalogRef.UOMClassifier") Then
		Query.SetParameter("Factor", 1);
	Else
		Query.SetParameter("Factor", UsedMeasurementUnit.Factor);
	EndIf;
	
	Query.SetParameter("ProductsType", Enums.ProductsTypes.InventoryItem);
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		
		If Selection.ContentRowType = Enums.BOMLineType.Node Then
			
			FillTableBySpecificationProcReport(Selection.Specification, Selection.Quantity, Selection.MeasurementUnit);
			
		Else
			
			NewRow = TableInventory.Add();
			FillPropertyValues(NewRow, Selection);
			
		EndIf;
		
	EndDo;	

EndProcedure

// Procedure initializes data filling by the section doc. Production without BillsOfMaterials and outputs data to DocumentResult
// 
&AtServer
Procedure Attachable_OutputDataBySectionDocProductionWithoutBillsOfMaterials(TemplateOutput)
	
	If Not DocFilledWithProductionBillsOfMaterials Then
		OutputPictureDataOutput(TemplateOutput);
		FillDataByDocProductionWithoutBillsOfMaterials();
		DocFilledWithProductionBillsOfMaterials = True;	
	EndIf;
	
	OutputSectionTitle(TemplateOutput);
	
	If DocProductionBillsOfMaterials.Count() = 0 Then
		OutputAreaNoData(TemplateOutput);
		OutputAreaUpdateDataByGeneratedSection(TemplateOutput);
		Return;
	EndIf;
	
	TemplateArea = TemplateOutput.GetArea("StringCommentsTop");
	TemplateArea.Parameters.Comment = "Over the review period, posted documents of the Production kind were found that do not have specification (in the Products tabular sections).";
	ResultDocument.Put(TemplateArea);
	
	For Each CollectionItem In DocProductionBillsOfMaterials Do
		
		If Not CollectionItem.DataProcessorExecuted Then
			
			TemplateArea = TemplateOutput.GetArea("StringNotProcessedReportReprocessing");
			
			TemplateArea.Parameters.ResultAnalysis = "Suggested BillsOfMaterials";
			TemplateArea.Parameters.AnalysisResultDecrypt = "ExecuteProcedureOnClient#OutputReportDocSpecificationProduction(CurArea, PredefineVariant, DataBeenChanged)";
			
			TemplateArea.Parameters.ExecuteAction = "Set BillsOfMaterials";
			TemplateArea.Parameters.ExecuteActionDecrypt = "ExecuteProcedure#Attachable_SetBillsOfMaterialsInDocProduction(CurArea, PredefineVariant, DataBeenChanged)";
			
		Else
			
			TemplateArea = TemplateOutput.GetArea("StringProcessedReportReprocessing");
			TemplateArea.Parameters.ResultAnalysis = "BillsOfMaterials are filled in";
			TemplateArea.Parameters.AnalysisResultDecrypt = CollectionItem.DocumentRef;
		
		EndIf;
		
		DocumentPresentation = GenerateDocumentPresentation(CollectionItem.DocumentRef);
												
		TemplateArea.Parameters.DocumentRef = CollectionItem.DocumentRef;
		TemplateArea.Parameters.DocumentPresentation = DocumentPresentation;
		
		ResultDocument.Put(TemplateArea);
		
	EndDo;
	
	OutputAreaUpdateDataByGeneratedSection(TemplateOutput);
	
EndProcedure

// Implements a mechanism of data control by the doc. section Production without BillsOfMaterials.
//
&AtServer
Procedure FillDataByDocProductionWithoutBillsOfMaterials()

	Query = New Query("SELECT
	                      |	ProductionProducts.Ref,
	                      |	ProductionProducts.Products,
	                      |	ProductionProducts.Products.Specification
	                      |INTO TU_ProductionWithoutBillsOfMaterials
	                      |FROM
	                      |	Document.Production.Products AS ProductionProducts
	                      |WHERE
	                      |	ProductionProducts.Ref.Posted = TRUE
	                      |	AND ProductionProducts.Ref.Date between &DateBeg AND &DateEnd
	                      |	AND CASE
	                      |			WHEN Not &RunAccountingBySubsidiaryCompany
	                      |				THEN ProductionProducts.Ref.Company = &Company
	                      |			ELSE TRUE
	                      |		END
	                      |	AND ProductionProducts.Specification = VALUE(Catalog.BillsOfMaterials.EmptyRef)
	                      |;
	                      |
	                      |////////////////////////////////////////////////////////////////////////////////
	                      |SELECT
	                      |	TU_ProductionWithoutBillsOfMaterials.Ref
	                      |INTO TU_RefsExceptions
	                      |FROM
	                      |	TU_ProductionWithoutBillsOfMaterials AS TU_ProductionWithoutBillsOfMaterials
	                      |WHERE
	                      |	TU_ProductionWithoutBillsOfMaterials.ProductsSpecification = VALUE(Catalog.BillsOfMaterials.EmptyRef)
	                      |;
	                      |
	                      |////////////////////////////////////////////////////////////////////////////////
	                      |SELECT DISTINCT
	                      |	TU_ProductionWithoutBillsOfMaterials.Ref AS DocumentRef,
	                      |	FALSE AS DataProcessorExecuted
	                      |FROM
	                      |	TU_ProductionWithoutBillsOfMaterials AS TU_ProductionWithoutBillsOfMaterials
	                      |WHERE
	                      |	Not TU_ProductionWithoutBillsOfMaterials.Ref In
	                      |				(SELECT
	                      |					TU_RefsExceptions.Ref
	                      |				FROM
	                      |					TU_RefsExceptions AS TU_RefsExceptions)
	                      |
	                      |ORDER BY
	                      |	TU_ProductionWithoutBillsOfMaterials.Ref.Date");
						  
	Query.SetParameter("Company", Company);
	Query.SetParameter("DateBeg", BeginOfPeriod);
	Query.SetParameter("DateEnd", EndOfDay(EndOfPeriod));
	Query.SetParameter("RunAccountingBySubsidiaryCompany", RunAccountingBySubsidiaryCompany);
	
	ValueToFormAttribute(Query.Execute().Unload(), "DocProductionBillsOfMaterials");

EndProcedure

// Procedure initializes data filling by the section doc. Production - mismatch of writeoffs to BillsOfMaterials and
// outputs data to DocumentResult.
// 
&AtServer
Procedure Attachable_OutputDataBySectionDocProductionWriteoffsMismatch(TemplateOutput)
	
	If Not DocFilledWithProductionInconsistencies Then
		OutputPictureDataOutput(TemplateOutput);
		FillDataByDocProductionWriteoffsMismatch();
		DocFilledWithProductionInconsistencies = True;	
	EndIf;
	
	OutputSectionTitle(TemplateOutput);
	
	If DocProductionInconsistencies.Count() = 0 Then
		OutputAreaNoData(TemplateOutput);
		OutputAreaUpdateDataByGeneratedSection(TemplateOutput);
		Return;
	EndIf;
	
	TemplateArea = TemplateOutput.GetArea("StringCommentsTop");
	TemplateArea.Parameters.Comment = "Over the review period, posted documents of the Production kind were found in which the written off inventory does not correspond to the specification.";
	ResultDocument.Put(TemplateArea);
	
	For Each TableRow In DocProductionInconsistencies Do
	
		If Not TableRow.DataProcessorExecuted Then
			
			TemplateArea = TemplateOutput.GetArea("StringNotProcessedReportReprocessing");
			
			TemplateArea.Parameters.ResultAnalysis = "Mismatch is found";
			TemplateArea.Parameters.AnalysisResultDecrypt = "ExecuteProcedureOnClient#OutputReportByMismatchesDocProduction(CurArea, PredefineVariant, DataBeenChanged)";
			
			TemplateArea.Parameters.ExecuteAction = "Refill and repost";
			TemplateArea.Parameters.ExecuteActionDecrypt = "ExecuteProcedure#Attachable_CorrectMismatchDocProduction(CurArea, PredefineVariant, DataBeenChanged)";
			
		Else
			
			TemplateArea = TemplateOutput.GetArea("StringProcessedReportReprocessing");
			
			TemplateArea.Parameters.ResultAnalysis = "Corrected";
			TemplateArea.Parameters.AnalysisResultDecrypt = TableRow.DocumentRef;
			
		EndIf;
		
		DocumentPresentation = GenerateDocumentPresentation(TableRow.DocumentRef);
												
		TemplateArea.Parameters.DocumentRef = TableRow.DocumentRef;
		TemplateArea.Parameters.DocumentPresentation = DocumentPresentation;
		
		ResultDocument.Put(TemplateArea);	
		
	EndDo;
	
	OutputAreaUpdateDataByGeneratedSection(TemplateOutput);
	
EndProcedure

// Implements a mechanism of data control by the doc. section Production - mismatch of writeoffs to BillsOfMaterials.
//
&AtServer
Procedure FillDataByDocProductionWriteoffsMismatch()

	Query = New Query("SELECT
	                      |	ProductionProducts.Ref AS DocumentRef,
	                      |	ProductionProducts.Specification AS Specification
	                      |INTO TU_ProductionForPeriod
	                      |FROM
	                      |	Document.Production.Products AS ProductionProducts
	                      |WHERE
	                      |	ProductionProducts.Ref.Date between &DateBeg AND &DateEnd
	                      |	AND ProductionProducts.Ref.Posted = TRUE
	                      |	AND CASE
	                      |			WHEN Not &RunAccountingBySubsidiaryCompany
	                      |				THEN ProductionProducts.Ref.Company = &Company
	                      |			ELSE TRUE
	                      |		END
	                      |;
	                      |
	                      |////////////////////////////////////////////////////////////////////////////////
	                      |SELECT DISTINCT
	                      |	TU_ProductionForPeriod.DocumentRef
	                      |INTO TU_RefsExceptions
	                      |FROM
	                      |	TU_ProductionForPeriod AS TU_ProductionForPeriod
	                      |WHERE
	                      |	TU_ProductionForPeriod.Specification = VALUE(Catalog.BillsOfMaterials.EmptyRef)
	                      |;
	                      |
	                      |////////////////////////////////////////////////////////////////////////////////
	                      |SELECT DISTINCT
	                      |	TU_ProductionForPeriod.DocumentRef
	                      |FROM
	                      |	TU_ProductionForPeriod AS TU_ProductionForPeriod
	                      |WHERE
	                      |	Not TU_ProductionForPeriod.DocumentRef In
	                      |				(SELECT
	                      |					TU_RefsExceptions.DocumentRef
	                      |				FROM
	                      |					TU_RefsExceptions AS TU_RefsExceptions)
	                      |
	                      |ORDER BY
	                      |	TU_ProductionForPeriod.DocumentRef.Date");
						  
	Query.SetParameter("Company", Company);
	Query.SetParameter("DateBeg", BeginOfPeriod);
	Query.SetParameter("DateEnd", EndOfDay(EndOfPeriod));
	Query.SetParameter("RunAccountingBySubsidiaryCompany", RunAccountingBySubsidiaryCompany);
	
	DocumentsTable = Query.Execute().Unload();
	
	For Each DocumentsTableRow In DocumentsTable Do
		
		TableInventory = DocumentsTableRow.DocumentRef.Inventory.Unload();
		TableInventory.GroupBy("Products,Characteristic", "Quantity");
		TableInventory.Columns.Quantity.Name = "QuantityInFact";
		TableInventory.Columns.Add("Quantity", New TypeDescription("Number"));
		
		NodesBillsOfMaterialstack = New Array;
		FillTableBySpecificationProduction(DocumentsTableRow.DocumentRef, NodesBillsOfMaterialstack);
		
		TableInventory.GroupBy("Products,Characteristic", "ActualQuantity, Quantity");
		
		TableInventory.Columns.Quantity.Name = "QuantityOnSpecification";
		
		DataTablesRow = Undefined;
		
		For Each InventoryTableRow In TableInventory Do
		
			If InventoryTableRow.QuantityInFact <> InventoryTableRow.QuantityOnSpecification Then
			
				If DataTablesRow = Undefined Then					
					DataTablesRow = DocProductionInconsistencies.Add();
					DataTablesRow.DocumentRef = DocumentsTableRow.DocumentRef;
				EndIf;
				
				NewRow = DataTablesRow.DifferencesTable.Add();
				
				FillPropertyValues(NewRow, InventoryTableRow);
				
			EndIf;
			
		EndDo;
	
	EndDo;	

EndProcedure

// Procedure from the
// Production document module places a table of inventory write-off to variable InventoryTable according to the specification.
//
&AtServer
Procedure FillTableBySpecificationProduction(DocumentRef, NodesBillsOfMaterialstack, NodesTable = Undefined) Export
	
	TempTablesManager = New TempTablesManager;
	
	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	Query.Text =
	"SELECT
	|	TableProduction.LineNumber AS LineNumber,
	|	TableProduction.Quantity AS Quantity,
	|	TableProduction.Factor AS Factor,
	|	TableProduction.Specification AS Specification
	|INTO TemporaryTableProduction
	|FROM
	|	&TableProduction AS TableProduction
	|WHERE
	|	TableProduction.Specification <> VALUE(Catalog.BillsOfMaterials.EmptyRef)";
	
	If NodesTable = Undefined Then
		TableProduction = DocumentRef.Products.Unload();
		Array = New Array();
		Array.Add(Type("Number"));
		TypeDescriptionC = New TypeDescription(Array, , ,New NumberQualifiers(10,3));
		TableProduction.Columns.Add("Factor", TypeDescriptionC);
		For Each StringProducts In TableProduction Do
			If ValueIsFilled(StringProducts.MeasurementUnit)
				AND TypeOf(StringProducts.MeasurementUnit) = Type("CatalogRef.UOM") Then
				StringProducts.Factor = StringProducts.MeasurementUnit.Factor;
			Else
				StringProducts.Factor = 1;
			EndIf;
		EndDo;
		NodesTable = TableProduction.CopyColumns("LineNumber,Quantity,Factor,Specification");
		Query.SetParameter("TableProduction", TableProduction);
	Else
		Query.SetParameter("TableProduction", NodesTable);
	EndIf;
	
	Query.Execute();
	
	Query.Text =
	"SELECT
	|	MIN(TableProduction.LineNumber) AS ProductionLineNumber,
	|	TableProduction.Specification AS ProductionSpecification,
	|	MIN(TableMaterials.LineNumber) AS StructureLineNumber,
	|	TableMaterials.ContentRowType AS ContentRowType,
	|	TableMaterials.Products AS Products,
	|	CASE
	|		WHEN UseCharacteristics.Value
	|			THEN TableMaterials.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	SUM(TableMaterials.Quantity / TableMaterials.ProductsQuantity * TableProduction.Factor * TableProduction.Quantity) AS Quantity,
	|	TableMaterials.MeasurementUnit AS MeasurementUnit,
	|	CASE
	|		WHEN TableMaterials.ContentRowType = VALUE(Enum.BOMLineType.Node)
	|				AND VALUETYPE(TableMaterials.MeasurementUnit) = Type(Catalog.UOM)
	|				AND TableMaterials.MeasurementUnit <> VALUE(Catalog.UOM.EmptyRef)
	|			THEN TableMaterials.MeasurementUnit.Factor
	|		ELSE 1
	|	END AS Factor,
	|	TableMaterials.CostPercentage AS CostPercentage,
	|	TableMaterials.Specification AS Specification
	|FROM
	|	TemporaryTableProduction AS TableProduction
	|		LEFT JOIN Catalog.BillsOfMaterials.Content AS TableMaterials
	|		ON TableProduction.Specification = TableMaterials.Ref,
	|	Constant.UseCharacteristics AS UseCharacteristics
	|WHERE
	|	TableMaterials.Products.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
	|
	|GROUP BY
	|	TableProduction.Specification,
	|	TableMaterials.ContentRowType,
	|	TableMaterials.Products,
	|	TableMaterials.MeasurementUnit,
	|	CASE
	|		WHEN TableMaterials.ContentRowType = VALUE(Enum.BOMLineType.Node)
	|				AND VALUETYPE(TableMaterials.MeasurementUnit) = Type(Catalog.UOM)
	|				AND TableMaterials.MeasurementUnit <> VALUE(Catalog.UOM.EmptyRef)
	|			THEN TableMaterials.MeasurementUnit.Factor
	|		ELSE 1
	|	END,
	|	TableMaterials.CostPercentage,
	|	TableMaterials.Specification,
	|	CASE
	|		WHEN UseCharacteristics.Value
	|			THEN TableMaterials.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END
	|
	|ORDER BY
	|	ProductionLineNumber,
	|	StructureLineNumber";
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		If Selection.ContentRowType = Enums.BOMLineType.Node Then
			NodesTable.Clear();
			If Not NodesBillsOfMaterialstack.Find(Selection.Specification) = Undefined Then
				MessageText = NStr("en = 'During filling in of the Specification materials
				                   |tabular section a recursive item occurrence was found'")+" "+Selection.Products+" "+NStr("en = 'in BOM'")+" "+Selection.ProductionSpecification+"
									|The operation failed.";
				Raise MessageText;
			EndIf;
			NodesBillsOfMaterialstack.Add(Selection.Specification);
			NewRow = NodesTable.Add();
			FillPropertyValues(NewRow, Selection);
			FillTableBySpecificationProduction(DocumentRef, NodesBillsOfMaterialstack, NodesTable);
		Else
			NewRow = TableInventory.Add();
			FillPropertyValues(NewRow, Selection);
		EndIf;
	EndDo;
	
	NodesBillsOfMaterialstack.Clear();
	
EndProcedure

// Procedure initializes data filling by the Analysis of the purchase prices section and puts out the data to DocumentResult.
// 
&AtServer
Procedure Attachable_OutputDataBySectionPurchasePricesAnalysis(TemplateOutput)
	
	If Not PurchasePricesAnalysisFilledWith Then
		OutputPictureDataOutput(TemplateOutput);
		FillDataByPurchasePricesAnalysis();
		PurchasePricesAnalysisFilledWith = True;	
	EndIf;
	
	OutputSectionTitle(TemplateOutput);
	
	If PurchasePricesAnalysis.GetItems().Count() = 0 Then
		OutputAreaNoData(TemplateOutput);
		OutputAreaUpdateDataByGeneratedSection(TemplateOutput);
		Return;
	EndIf;
	
	TemplateArea = TemplateOutput.GetArea("StringCommentsTop");
	TemplateArea.Parameters.Comment = "Over the review period sharp changes of purchase prices were found for some products positions (5 or more times).";
	ResultDocument.Put(TemplateArea);
	
	RowsProducts = PurchasePricesAnalysis.GetItems();
	
	For Each StringProducts In RowsProducts Do
		
		TemplateArea = TemplateOutput.GetArea("StringPriceAnalysis");
		TemplateArea.Parameters.Products = TrimAll(StringProducts.Products.Description);
		TemplateArea.Parameters.ProductsDecrypt = StringProducts.Products;
		TemplateArea.Parameters.ResultAnalysis = "Analysis result";
		TemplateArea.Parameters.AnalysisResultDecrypt = "ExecuteProcedureOnClient#OutputReportPricesAnalysisByProducts(CurArea, PredefineVariant, DataBeenChanged)";
		
		ResultDocument.Put(TemplateArea);
		
	EndDo;
	
	OutputAreaUpdateDataByGeneratedSection(TemplateOutput);
	
EndProcedure

// Procedure implements a mechanism of the data control by the Purchase prices analysis section.
//
&AtServer
Procedure FillDataByPurchasePricesAnalysis()
	
	LastMonthBegin = AddMonth(BeginOfPeriod, -1);
	LastMonthEnd = EndOfMonth(LastMonthBegin);

	Query = New Query("SELECT
	                      |	PurchasesForCurrentPeriod.Products AS Products,
	                      |	PurchasesForCurrentPeriod.Characteristic AS Characteristic,
	                      |	PurchasesForCurrentPeriod.Quantity AS Quantity,
	                      |	PurchasesForCurrentPeriod.Amount AS Amount,
	                      |	PurchasesForCurrentPeriod.Recorder AS Recorder,
	                      |	CASE
	                      |		WHEN PurchasesForCurrentPeriod.Quantity = 0
	                      |			THEN 0
	                      |		ELSE PurchasesForCurrentPeriod.Amount / PurchasesForCurrentPeriod.Quantity
	                      |	END AS CurrentPeriodPrice
	                      |INTO TU_PurchasesForCurrentPeriod
	                      |FROM
	                      |	(SELECT
	                      |		PurchasesTurnovers.Products AS Products,
	                      |		PurchasesTurnovers.Characteristic AS Characteristic,
	                      |		SUM(PurchasesTurnovers.QuantityTurnover) AS Quantity,
	                      |		SUM(PurchasesTurnovers.AmountTurnover + PurchasesTurnovers.VATAmountTurnover) AS Amount,
	                      |		PurchasesTurnovers.Recorder AS Recorder
	                      |	FROM
	                      |		AccumulationRegister.Purchases.Turnovers(
	                      |				&DateBeg,
	                      |				&DateEnd,
	                      |				Recorder,
	                      |				Company = &Company
	                      |					AND Products.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)) AS PurchasesTurnovers
	                      |	WHERE
	                      |		PurchasesTurnovers.Recorder REFS Document.SupplierInvoice
	                      |	
	                      |	GROUP BY
	                      |		PurchasesTurnovers.Products,
	                      |		PurchasesTurnovers.Characteristic,
	                      |		PurchasesTurnovers.Recorder) AS PurchasesForCurrentPeriod
	                      |;
	                      |
	                      |////////////////////////////////////////////////////////////////////////////////
	                      |SELECT
	                      |	PurchasesForLastPeriod.Recorder AS Recorder,
	                      |	PurchasesForLastPeriod.Period AS Period,
	                      |	PurchasesForLastPeriod.Products AS Products,
	                      |	PurchasesForLastPeriod.Characteristic AS Characteristic,
	                      |	PurchasesForLastPeriod.Quantity AS Quantity,
	                      |	PurchasesForLastPeriod.Amount AS Amount,
	                      |	CASE
	                      |		WHEN PurchasesForLastPeriod.Quantity = 0
	                      |			THEN 0
	                      |		ELSE PurchasesForLastPeriod.Amount / PurchasesForLastPeriod.Quantity
	                      |	END AS PriceLastPeriod
	                      |INTO TU_PurchasesForLastPeriod
	                      |FROM
	                      |	(SELECT
	                      |		PurchasesTurnovers.Recorder AS Recorder,
	                      |		PurchasesTurnovers.Period AS Period,
	                      |		PurchasesTurnovers.Products AS Products,
	                      |		PurchasesTurnovers.Characteristic AS Characteristic,
	                      |		SUM(PurchasesTurnovers.QuantityTurnover) AS Quantity,
	                      |		SUM(PurchasesTurnovers.AmountTurnover + PurchasesTurnovers.VATAmountTurnover) AS Amount
	                      |	FROM
	                      |		AccumulationRegister.Purchases.Turnovers(
	                      |				&DateBegLast,
	                      |				&DateEndLast,
	                      |				Recorder,
	                      |				Company = &Company
	                      |					AND Products IN
	                      |						(SELECT
	                      |							TU_PurchasesForCurrentPeriod.Products
	                      |						FROM
	                      |							TU_PurchasesForCurrentPeriod AS TU_PurchasesForCurrentPeriod)
	                      |					AND Characteristic IN
	                      |						(SELECT
	                      |							TU_PurchasesForCurrentPeriod.Characteristic
	                      |						FROM
	                      |							TU_PurchasesForCurrentPeriod AS TU_PurchasesForCurrentPeriod)) AS PurchasesTurnovers
	                      |	
	                      |	GROUP BY
	                      |		PurchasesTurnovers.Recorder,
	                      |		PurchasesTurnovers.Period,
	                      |		PurchasesTurnovers.Products,
	                      |		PurchasesTurnovers.Characteristic) AS PurchasesForLastPeriod
	                      |;
	                      |
	                      |////////////////////////////////////////////////////////////////////////////////
	                      |SELECT
	                      |	TU_PurchasesForLastPeriod.Products AS Products,
	                      |	TU_PurchasesForLastPeriod.Characteristic AS Characteristic,
	                      |	TU_PurchasesForLastPeriod.PriceLastPeriod AS PriceLastPeriod,
	                      |	LastRegistrar.Recorder AS RegistrarLastPeriod
	                      |INTO TU_LastPurchasesForLastPeriod
	                      |FROM
	                      |	TU_PurchasesForLastPeriod AS TU_PurchasesForLastPeriod
	                      |		INNER JOIN (SELECT
	                      |			TU_PurchasesForLastPeriod.Products AS Products,
	                      |			TU_PurchasesForLastPeriod.Characteristic AS Characteristic,
	                      |			MAX(TU_PurchasesForLastPeriod.Recorder) AS Recorder
	                      |		FROM
	                      |			TU_PurchasesForLastPeriod AS TU_PurchasesForLastPeriod
	                      |				INNER JOIN (SELECT
	                      |					TU_PurchasesForLastPeriod.Products AS Products,
	                      |					TU_PurchasesForLastPeriod.Characteristic AS Characteristic,
	                      |					MAX(TU_PurchasesForLastPeriod.Period) AS Period
	                      |				FROM
	                      |					TU_PurchasesForLastPeriod AS TU_PurchasesForLastPeriod
	                      |				
	                      |				GROUP BY
	                      |					TU_PurchasesForLastPeriod.Products,
	                      |					TU_PurchasesForLastPeriod.Characteristic) AS LastPeriod
	                      |				ON TU_PurchasesForLastPeriod.Products = LastPeriod.Products
	                      |					AND TU_PurchasesForLastPeriod.Characteristic = LastPeriod.Characteristic
	                      |					AND TU_PurchasesForLastPeriod.Period = LastPeriod.Period
	                      |		
	                      |		GROUP BY
	                      |			TU_PurchasesForLastPeriod.Products,
	                      |			TU_PurchasesForLastPeriod.Characteristic) AS LastRegistrar
	                      |		ON TU_PurchasesForLastPeriod.Products = LastRegistrar.Products
	                      |			AND TU_PurchasesForLastPeriod.Characteristic = LastRegistrar.Characteristic
	                      |			AND TU_PurchasesForLastPeriod.Recorder = LastRegistrar.Recorder
	                      |;
	                      |
	                      |////////////////////////////////////////////////////////////////////////////////
	                      |SELECT
	                      |	PricesVariance.Products AS Products,
	                      |	PricesVariance.Characteristic AS Characteristic
	                      |INTO TU_ProductsForSelection
	                      |FROM
	                      |	(SELECT DISTINCT
	                      |		TU_PurchasesForCurrentPeriod.Products AS Products,
	                      |		TU_PurchasesForCurrentPeriod.Characteristic AS Characteristic
	                      |	FROM
	                      |		TU_PurchasesForCurrentPeriod AS TU_PurchasesForCurrentPeriod
	                      |			INNER JOIN TU_LastPurchasesForLastPeriod AS TU_LastPurchasesForLastPeriod
	                      |			ON TU_PurchasesForCurrentPeriod.Products = TU_LastPurchasesForLastPeriod.Products
	                      |				AND TU_PurchasesForCurrentPeriod.Characteristic = TU_LastPurchasesForLastPeriod.Characteristic
	                      |	WHERE
	                      |		(TU_PurchasesForCurrentPeriod.CurrentPeriodPrice / TU_LastPurchasesForLastPeriod.PriceLastPeriod >= &OverageThreshold
	                      |				OR TU_LastPurchasesForLastPeriod.PriceLastPeriod / TU_PurchasesForCurrentPeriod.CurrentPeriodPrice >= &OverageThreshold)) AS PricesVariance
	                      |;
	                      |
	                      |////////////////////////////////////////////////////////////////////////////////
	                      |SELECT
	                      |	FinalTable.Products AS Products,
	                      |	FinalTable.Characteristic AS Characteristic,
	                      |	FinalTable.PurchaseDate AS PurchaseDate,
	                      |	FinalTable.PurchasePrice AS PurchasePrice,
	                      |	FinalTable.ThereIsDeviation AS ThereIsDeviation,
	                      |	FinalTable.PurchaseDocument AS PurchaseDocument
	                      |FROM
	                      |	(SELECT
	                      |		TU_PurchasesForCurrentPeriod.Products AS Products,
	                      |		TU_PurchasesForCurrentPeriod.Characteristic AS Characteristic,
	                      |		TU_PurchasesForCurrentPeriod.Recorder.Date AS PurchaseDate,
	                      |		TU_PurchasesForCurrentPeriod.CurrentPeriodPrice AS PurchasePrice,
	                      |		CASE
	                      |			WHEN TU_PurchasesForCurrentPeriod.CurrentPeriodPrice / TU_LastPurchasesForLastPeriod.PriceLastPeriod >= &OverageThreshold
	                      |					OR TU_LastPurchasesForLastPeriod.PriceLastPeriod / TU_PurchasesForCurrentPeriod.CurrentPeriodPrice >= &OverageThreshold
	                      |				THEN TRUE
	                      |			ELSE FALSE
	                      |		END AS ThereIsDeviation,
	                      |		TU_PurchasesForCurrentPeriod.Recorder AS PurchaseDocument
	                      |	FROM
	                      |		TU_ProductsForSelection AS TU_ProductsForSelection
	                      |			INNER JOIN TU_PurchasesForCurrentPeriod AS TU_PurchasesForCurrentPeriod
	                      |			ON TU_ProductsForSelection.Products = TU_PurchasesForCurrentPeriod.Products
	                      |				AND TU_ProductsForSelection.Characteristic = TU_PurchasesForCurrentPeriod.Characteristic
	                      |			INNER JOIN TU_LastPurchasesForLastPeriod AS TU_LastPurchasesForLastPeriod
	                      |			ON TU_ProductsForSelection.Products = TU_LastPurchasesForLastPeriod.Products
	                      |				AND TU_ProductsForSelection.Characteristic = TU_LastPurchasesForLastPeriod.Characteristic
	                      |	
	                      |	UNION ALL
	                      |	
	                      |	SELECT
	                      |		TU_LastPurchasesForLastPeriod.Products,
	                      |		TU_LastPurchasesForLastPeriod.Characteristic,
	                      |		TU_LastPurchasesForLastPeriod.RegistrarLastPeriod.Date,
	                      |		TU_LastPurchasesForLastPeriod.PriceLastPeriod,
	                      |		FALSE,
	                      |		TU_LastPurchasesForLastPeriod.RegistrarLastPeriod
	                      |	FROM
	                      |		TU_ProductsForSelection AS TU_ProductsForSelection,
	                      |		TU_LastPurchasesForLastPeriod AS TU_LastPurchasesForLastPeriod) AS FinalTable
	                      |
	                      |GROUP BY
	                      |	FinalTable.Products,
	                      |	FinalTable.Characteristic,
	                      |	FinalTable.PurchaseDate,
	                      |	FinalTable.ThereIsDeviation,
	                      |	FinalTable.PurchasePrice,
	                      |	FinalTable.PurchaseDocument
	                      |
	                      |ORDER BY
	                      |	PurchaseDate
	                      |TOTALS BY
	                      |	Products");
						  
						  
	Query.SetParameter("Company", Company);
	Query.SetParameter("DateBeg", New Boundary(BeginOfPeriod, BoundaryType.Including));
	Query.SetParameter("DateEnd", New Boundary(EndOfDay(EndOfPeriod), BoundaryType.Including));
	Query.SetParameter("DateBegLast", New Boundary(LastMonthBegin, BoundaryType.Including));
	Query.SetParameter("DateEndLast", New Boundary(EndOfDay(LastMonthEnd), BoundaryType.Including));
	Query.SetParameter("OverageThreshold", 5);
	
	QueryResult = Query.Execute();
	
	ValueToFormAttribute(QueryResult.Unload(QueryResultIteration.ByGroups), "PurchasePricesAnalysis");

EndProcedure

// Procedure initializes data filling by the Checks of the companies and contracts in documents section and puts out the
// data to DocumentResult.
// 
&AtServer
Procedure Attachable_OutputDataBySectionCompaniesContractControl(TemplateOutput)
	
	If Not DocumentTreeFilledWithCompanyContract Then
	    OutputPictureDataOutput(TemplateOutput);
		FillDataByCompaniesContractsControl();
		DocumentTreeFilledWithCompanyContract = True;
	EndIf;
	
	OutputSectionTitle(TemplateOutput);
	
	If DocumentsTreeCompanyContract.GetItems().Count() = 0 Then
		OutputAreaNoData(TemplateOutput);
		OutputAreaUpdateDataByGeneratedSection(TemplateOutput);
		Return;
	EndIf;
	
	TableContractCompany = New ValueTable;
	TableContractCompany.Columns.Add("Contract");
	TableContractCompany.Columns.Add("CompanyInContract");
	TableContractCompany.Columns.Add("CompanyInHeader");
	
	TableSubordinateDocument = New ValueTable;
	TableSubordinateDocument.Columns.Add("SubordinateDocument");
	TableSubordinateDocument.Columns.Add("MessageText");
	
	For Each RowLevel0 In DocumentsTreeCompanyContract.GetItems() Do
		
		RowRef = StrReplace(String(RowLevel0.MainDocument.UUID()), "-", "");
		
		TableContractCompany.Clear();
		TableSubordinateDocument.Clear();
		
		For Each RowLevel1 In RowLevel0.GetItems() Do
		
			If Not ValueIsFilled(RowLevel1.SubordinateDocument) Then
				
				NewRow = TableContractCompany.Add();
				FillPropertyValues(NewRow, RowLevel1);
								
			Else
				
				NewRow = TableSubordinateDocument.Add();
				FillPropertyValues(NewRow, RowLevel1);
				
			EndIf;
		
		EndDo;
		
		TemplateArea = TemplateOutput.GetArea("StringMismatchContractCompany");
		TemplateArea.Parameters.MainDocument = GenerateDocumentPresentation(RowLevel0.MainDocument);
		TemplateArea.Parameters.DefaultDocumentDecrypt = RowLevel0.MainDocument;		
		ResultDocument.Put(TemplateArea);
		
		If TableContractCompany.Count() > 0 Then
			
			TemplateArea = TemplateOutput.GetArea("RefMismatchContractCompany");
			TemplateArea.Parameters.CompaniesInHeaderAndContractDifferences = "ExecuteProcedure#Attachable_ChangeCellAreaVisible(CurArea, PredefineVariant, DataBeenChanged)";
			TemplateArea.Area(1,3,1,5).Mask = RowRef + "-1";
			CellsArea = ResultDocument.Put(TemplateArea);
			
			InterTabDocument = New SpreadsheetDocument;
			
			For Each TableRow In TableContractCompany Do
				
				TemplateArea = TemplateOutput.GetArea("NonAccordanceContractCompany");
				
				TemplateArea.Parameters.Contract	= TrimAll(TableRow.Contract.Description);
				TemplateArea.Parameters.ContractDecrypt = TableRow.Contract;
				
				TemplateArea.Parameters.CompanyInContract	= TrimAll(TableRow.CompanyInContract.Description);
				TemplateArea.Parameters.CompanyInContractDecrypt = TableRow.CompanyInContract;
				
				TemplateArea.Parameters.CompanyInHeader	= TrimAll(TableRow.CompanyInHeader.Description);
				TemplateArea.Parameters.CompanyInHeaderDecrypt = TableRow.CompanyInHeader;
				
				InterTabDocument.Put(TemplateArea);
				
			EndDo;
			
			If TableSubordinateDocument.Count() > 0 Then
				TemplateArea = TemplateOutput.GetArea("AreaIndent");		
				InterTabDocument.Put(TemplateArea);
			EndIf;
			
			CellsArea = ResultDocument.Put(InterTabDocument);
			CellsArea.Name = RowRef + "-1";
			CellsArea.Visible = False;		
			
		EndIf;
		
		If TableSubordinateDocument.Count() > 0 Then
						
			TemplateArea = TemplateOutput.GetArea("RefMismatchSubordinateDocument");
			TemplateArea.Parameters.DifferencesSubordinateDocument = "ExecuteProcedure#Attachable_ChangeCellAreaVisible(CurArea, PredefineVariant, DataBeenChanged)";
			TemplateArea.Area(1,3,1,5).Mask = RowRef + "-2";
			ResultDocument.Put(TemplateArea);
			
			InterTabDocument = New SpreadsheetDocument;
			
			For Each TableRow In TableSubordinateDocument Do
				
				TemplateArea = TemplateOutput.GetArea("NonAccordanceSubordinatedDocument");
				
				TemplateArea.Parameters.SubordinateDocument	= GenerateDocumentPresentation(TableRow.SubordinateDocument);
				TemplateArea.Parameters.SubordinateDocumentDecrypt = TableRow.SubordinateDocument;
				
				TemplateArea.Parameters.MessageText = TableRow.MessageText;
				
				InterTabDocument.Put(TemplateArea);	
				
			EndDo;
			
			CellsArea = ResultDocument.Put(InterTabDocument);
			CellsArea.Name = RowRef + "-2";
			CellsArea.Visible = False;
		
		EndIf;
	
	EndDo;
	
	OutputAreaUpdateDataByGeneratedSection(TemplateOutput);
	
EndProcedure

// Procedure implements the control mechanism by the Companies and contacts controls in documents section.
// 
&AtServer
Procedure FillDataByCompaniesContractsControl()
	
	ContractLocationTable = GenerateContractsLocationTable();
	
	RuleTemplate = FormAttributeToValue("Object").GetTemplate("CompaniesContractsControlRules");
	
	RuleStructure = GenerateRulesStructure(RuleTemplate);
	
	If RuleStructure.Count() = 0 Then
		Return;	
	EndIf;
	
	QueryText = GenerateQueryTextByDocuments(RuleStructure);
	
	Query = New Query;
	Query.Text = QueryText;
	Query.SetParameter("DateBeg", BeginOfPeriod);
	Query.SetParameter("DateEnd", EndOfDay(EndOfPeriod));
	
	QueryResult = Query.Execute();
	
	Selection = QueryResult.Select();
	
	TableOfResults = New ValueTable;
	TableOfResults.Columns.Add("MainDocument");
	TableOfResults.Columns.Add("SubordinateDocument");
	TableOfResults.Columns.Add("MessageText");
	TableOfResults.Columns.Add("CompanyInHeader");
	TableOfResults.Columns.Add("Contract");
	TableOfResults.Columns.Add("CompanyInContract");
	
	ControlMatchCompaniesInContracts = DriveReUse.CounterpartyContractsControlNeeded();
	
	While Selection.Next() Do
	
		DocumentRulesTable = Undefined;
		DocumentName = Selection.DocumentRef.Metadata().Name;
		
		If RuleStructure.Property(DocumentName, DocumentRulesTable) Then
			
			Try
				CheckMatchesInDocument(DocumentName, Selection.DocumentRef, ContractLocationTable, DocumentRulesTable, TableOfResults, ControlMatchCompaniesInContracts);			
			Except
				Message = New UserMessage;
				Message.Text = "Unable to check document " + String(Selection.DocumentRef) + Chars.LF + ErrorDescription();
				Message.SetData(Object);
				Message.Message(); 
			EndTry;	
			
		EndIf;
		
	EndDo;
	
	DataTree = FormAttributeToValue("DocumentsTreeCompanyContract");
		
	DataTree.Rows.Clear();
	
	If TableOfResults.Count() > 0 Then
		
		TableOfResults.GroupBy("MainDocument,SubordinateDocument,MessageText,CompanyInHeader,Contract,CompanyInContract");
		
		MainDocumentsTable = TableOfResults.Copy();
		MainDocumentsTable.GroupBy("MainDocument");
		
		For Each TableRowMain In MainDocumentsTable Do
			
			String_Level0 = DataTree.Rows.Add();
			FillPropertyValues(String_Level0, TableRowMain);
			
			SubordinateRowsArray = TableOfResults.FindRows(New Structure("MainDocument", TableRowMain.MainDocument));
			
			For Each SubordinatedRow In SubordinateRowsArray Do
				String_Level1 = String_Level0.Rows.Add();
				FillPropertyValues(String_Level1, SubordinatedRow);
			EndDo; 
			
		EndDo; 
	
	EndIf;
	
	ValueToFormAttribute(DataTree, "DocumentsTreeCompanyContract");

EndProcedure

// Function generates the values table that contains location of the attributes
// with the Contract name and the CatalogRef.CounterpartyContracts type - attribute or tabular sections.
// Filled in based on documents metadata.
//
&AtServerNoContext
Function GenerateContractsLocationTable()
	
	ContractType = Type("CatalogRef.CounterpartyContracts");
	
	ContractLocationTable = New ValueTable;
	ContractLocationTable.Columns.Add("DocumentName");
	ContractLocationTable.Columns.Add("AttributeType");
	ContractLocationTable.Columns.Add("TabularSectionName");

	For Each Document In Metadata.Documents Do
		
		ContractInHeader = False;
		
		For Each Attribute In Document.Attributes Do
			
			If Attribute.Type.ContainsType(ContractType) AND Attribute.Name = "Contract" Then
				
				NewRow = ContractLocationTable.Add();
				NewRow.DocumentName = Document.Name;
				NewRow.AttributeType = "Attribute";
				ContractInHeader = True;
				
				Break;
				
			EndIf;
			
		EndDo;
		
		If Not ContractInHeader Then
			
			For Each TabularSection In Document.TabularSections Do
				
				For Each TabularSectionAttribute In TabularSection.Attributes Do
					
					If TabularSectionAttribute.Type.ContainsType(ContractType) AND TabularSectionAttribute.Name = "Contract" Then
						
						NewRow = ContractLocationTable.Add();
						NewRow.DocumentName = Document.Name;
						NewRow.AttributeType = "TabularSection";
						NewRow.TabularSectionName = TabularSection.Name;
						
						Break;	
						
					EndIf;	
					
				EndDo; 	
				
			EndDo; 	
		
		EndIf;
		
	EndDo;
	
	Return ContractLocationTable;

EndFunction

// Function reads the rules of documents control
// from the CompanyContractsControlRules template and generates the structure in which the key - document name, value -
// rules table.
//
&AtServerNoContext
Function GenerateRulesStructure(RuleTemplate)
	
	RuleStructure = New Structure;

	RulesTable = New ValueTable;
	RulesTable.Columns.Add("DocumentName");
	RulesTable.Columns.Add("AttributeType");
	RulesTable.Columns.Add("AttributeName_TabularSections");
	RulesTable.Columns.Add("TabSecAttributeSynonym");
	RulesTable.Columns.Add("AttributeNameInTabularSection");
	
	TemplateRowsQuantity = RuleTemplate.TableHeight;
	
	For Ct = 2 To TemplateRowsQuantity Do
		
		DocumentName = "";
		AttributeType = "";
		AttributeName_TabularSections = "";
		AttributeNameInTabularSection = "";
		TabSecAttributeSynonym = "";
	
		DocumentName = StrReplace(TrimAll(RuleTemplate.Area(Ct, 1, Ct, 1).Text), " ", "");
		
		If DocumentName = "" OR DocumentName = "OpeningBalanceEntry" Then
			Continue;
		EndIf;
		
		AttributeType = StrReplace(TrimAll(RuleTemplate.Area(Ct, 2, Ct, 2).Text), " ", "");
		
		If AttributeType = "" Then
			Continue;
		EndIf;
		
		AttributeName_TabularSections = StrReplace(TrimAll(RuleTemplate.Area(Ct, 3, Ct, 3).Text), " ", "");
		
		If AttributeName_TabularSections = "" Then
			Continue;
		EndIf;
		
		If AttributeType = "Attribute" Then
			
			TabSecAttributeSynonym = Metadata.Documents[DocumentName].Attributes[AttributeName_TabularSections].Synonym;
			
		Else
			
			AttributeNameInTabularSection = StrReplace(TrimAll(RuleTemplate.Area(Ct, 4, Ct, 4).Text), " ", "");
			
			If AttributeNameInTabularSection = "" Then
				Continue;
			EndIf;
			
			TabSecAttributeSynonym = Metadata.Documents[DocumentName].TabularSections[AttributeName_TabularSections].Synonym;
		
		EndIf;
		
		NewRow = RulesTable.Add();
		NewRow.DocumentName = DocumentName;
		NewRow.AttributeType = AttributeType;
		NewRow.AttributeName_TabularSections = AttributeName_TabularSections;
		NewRow.TabSecAttributeSynonym = TabSecAttributeSynonym;
		NewRow.AttributeNameInTabularSection = AttributeNameInTabularSection;
		
	EndDo;
	
	RulesTableByDocument = RulesTable.CopyColumns();
	RulesTableByDocument.Columns.Delete("DocumentName");
	
	DocumentsNamesTable = RulesTable.Copy();
	DocumentsNamesTable.GroupBy("DocumentName");
	
	For Each NamesTableRow In DocumentsNamesTable Do
		
		RulesRowsArray = RulesTable.FindRows(New Structure("DocumentName", NamesTableRow.DocumentName));
		
		RuleStructure.Insert(NamesTableRow.DocumentName, RulesTableByDocument.CopyColumns());
		
		For Each ArrayRow In RulesRowsArray Do
		
			NewRow = RuleStructure[NamesTableRow.DocumentName].Add();
			FillPropertyValues(NewRow, ArrayRow);	
		
		EndDo;
		
	EndDo;
	
	Return RuleStructure;

EndFunction

// Function generates a query text based on the rules structure data.
//
&AtServerNoContext
Function GenerateQueryTextByDocuments(RuleStructure)
				   
	QueryText = "";				   
				   
	For Each KeyAndValue In RuleStructure Do
		
		If QueryText = "" Then
			
			QueryText =  "SELECT
	               |	DocumentTable.Ref AS DocumentRef,
	               |	DocumentTable.Date AS Date
	               |FROM
	               |	Document." + KeyAndValue.Key + " AS
	               |DocumentTable
	               |WHERE DocumentTable.Date BETWEEN &DateBeg
	               |	and &DateEnd AND DocumentTable.Posted = TRUE";
		
		Else
		
			QueryText = QueryText + Chars.LF + Chars.LF + "UNION ALL" + Chars.LF + Chars.LF;
			
			QueryText = QueryText + "SELECT
	               |	DocumentTable.Ref AS DocumentRef,
	               |	DocumentTable.Date AS Date
	               |FROM
	               |	Document." + KeyAndValue.Key + " AS
	               |DocumentTable
	               |WHERE DocumentTable.Date BETWEEN &DateBeg
	               |	and &DateEnd AND DocumentTable.Posted = TRUE";
			
		EndIf;	
	
	EndDo;
	
	If QueryText <> "" Then
		QueryText = QueryText + Chars.LF + Chars.LF + "ORDER BY" + Chars.LF + Chars.Tab + "Date";	
	EndIf;
	
	Return QueryText;

EndFunction

// IN the procedure, data is prepared and document data comparison with data of the same type in subordinate documents
// is initialized. IN case there are differences, both documents are placed to ResultsTable.
//
&AtServerNoContext
Procedure CheckMatchesInDocument(DocumentName, DocumentRef, ContractLocationTable, RulesTable, TableOfResults, ControlMatchCompaniesInContracts)
	
	ContractLocation = ContractLocationTable.Find(DocumentName);
	
	CurCompany = DocumentRef.Company;
	CurrContract = Undefined;
	
	If ContractLocation = Undefined Then
		Return;
	EndIf;
	
	If ContractLocation.AttributeType = "Attribute" Then
		
		CurrContract = DocumentRef.Contract;
		
		If ControlMatchCompaniesInContracts Then
			
			If CurCompany <> CurrContract.Company Then
				
				NewRow = TableOfResults.Add();
				NewRow.MainDocument = DocumentRef;
				NewRow.SubordinateDocument = Undefined;
				NewRow.MessageText = "Company specified in the document does not match company specified in the contract " + TrimAll(CurrContract.Description);
				NewRow.CompanyInHeader = CurCompany;
				NewRow.Contract = CurrContract;
				NewRow.CompanyInContract = CurrContract.Company;
				
			EndIf;
			
		EndIf;
		
		For Each RulesTablesRow In RulesTable Do
			
			CheckObject = Undefined;
			
			If RulesTablesRow.AttributeType = "Attribute" Then
				
				CheckObject = DocumentRef[RulesTablesRow.AttributeName_TabularSections];
				
				If ValueIsFilled(CheckObject) Then
					
					CompareDocumentsData_ContractInAttribute(CheckObject, ContractLocationTable, CurCompany, CurrContract, TableOfResults, DocumentRef, RulesTablesRow, "Field");	
					
				EndIf;
				
			ElsIf RulesTablesRow.AttributeType = "TabularSection" Then
				
				For Each TabularSectionRow In DocumentRef[RulesTablesRow.AttributeName_TabularSections] Do
					
					CheckObject = Undefined;
					
					CheckObject = TabularSectionRow[RulesTablesRow.AttributeNameInTabularSection];
					
					If ValueIsFilled(CheckObject) Then
						
						CompareDocumentsData_ContractInAttribute(CheckObject, ContractLocationTable, CurCompany, CurrContract, TableOfResults, DocumentRef, RulesTablesRow, "tab. section");	
						
					EndIf;
					
				EndDo;		
				
			EndIf;
			
		EndDo; 
		
	ElsIf ContractLocation.AttributeType = "TabularSection" Then
		
		ContractsArray = DocumentRef[ContractLocation.TabularSectionName].UnloadColumn("Contract");
		
		If ControlMatchCompaniesInContracts Then
		
			For Each CurrContract In ContractsArray Do
				
				If CurCompany <> CurrContract.Company Then
					
					NewRow = TableOfResults.Add();
					NewRow.MainDocument = DocumentRef;
					NewRow.SubordinateDocument = Undefined;
					NewRow.MessageText = "Company specified in the document does not match company specified in the contract " + TrimAll(CurrContract.Description);
					NewRow.CompanyInHeader = CurCompany;
					NewRow.Contract = CurrContract;
					NewRow.CompanyInContract = CurrContract.Company;
					
				EndIf;	
				
			EndDo; 	
		
		EndIf;
		
		For Each RulesTablesRow In RulesTable Do
		
			CheckObject = Undefined;
			
			If RulesTablesRow.AttributeType = "Attribute" Then
				
				CheckObject = DocumentRef[RulesTablesRow.AttributeName_TabularSections];
				
				If ValueIsFilled(CheckObject) Then
					
					CompareDocumentsData_ContractInTabSec(CheckObject, ContractLocationTable, CurCompany, ContractsArray, TableOfResults, DocumentRef, RulesTablesRow, "Field");	
					
				EndIf;	
			
			ElsIf RulesTablesRow.AttributeType = "TabularSection" Then	
			
				If ContractLocation.TabularSectionName <> RulesTablesRow.AttributeName_TabularSections Then
					// There is no point comparing document and document from different tabular sections
					Continue;			
				EndIf;
				
				For Each TabularSectionRowOwner In DocumentRef[RulesTablesRow.AttributeName_TabularSections] Do
					// Take each row separately i.e. compare a contract in row with
					// a document check as if it is a separate document with a contract in the header
					CheckObject = Undefined;
				
					CheckObject = TabularSectionRowOwner[RulesTablesRow.AttributeNameInTabularSection];
					
					If ValueIsFilled(CheckObject) Then
						
						CompaniesMismatch = False;
						ContractsMismatch = False;
						
						CompareDocumentsData_ContractInAttribute(CheckObject, ContractLocationTable, CurCompany, TabularSectionRowOwner.Contract, TableOfResults, DocumentRef, RulesTablesRow, "tab. section");
						
					EndIf;
				
				EndDo; 
				
			EndIf;
		
		EndDo; 
	
	EndIf; 

EndProcedure

// IN the procedure, the document data is
// compared for cases when the contract of the document-owner is located in the header.
//
&AtServerNoContext
Procedure CompareDocumentsData_ContractInAttribute(CheckObject, ContractLocationTable, CurCompany, CurrContract, TableOfResults, DocumentRef, RulesTablesRow, SubordinateLocation)
	
	SubordinateDocumentName = CheckObject.Metadata().Name;
	
	ContractLocationSubordinated = ContractLocationTable.Find(SubordinateDocumentName);
	
	If ContractLocationSubordinated = Undefined Then
		Return;
	EndIf;
	
	If ContractLocationSubordinated.AttributeType = "Attribute" Then
		
		CompaniesMismatch = False;
		ContractsMismatch = False;
		
		If CurCompany <> CheckObject.Company Then
			CompaniesMismatch = True;
		EndIf;
		
		If CurrContract <> CheckObject.Contract Then
			ContractsMismatch = True;					
		EndIf;
		
		If CompaniesMismatch OR ContractsMismatch Then
			
			NewRow = TableOfResults.Add();
			NewRow.MainDocument = DocumentRef;
			NewRow.SubordinateDocument = CheckObject;
			NewRow.MessageText = GenerateMessageTextByMismatch(CompaniesMismatch, ContractsMismatch) 
			+ ". Location: " + SubordinateLocation + " " + RulesTablesRow.TabSecAttributeSynonym;
			
		EndIf;
		
	ElsIf ContractLocationSubordinated.AttributeType = "TabularSection" Then
		
		CompaniesMismatch = False;
		ContractsMismatch = False;
		
		If CurCompany <> CheckObject.Company Then
			CompaniesMismatch = True;
		EndIf;
		
		ArrayContractSubordinate = CheckObject[ContractLocationSubordinated.TabularSectionName].UnloadColumn("Contract");
		
		If ArrayContractSubordinate.Find(CurrContract) = Undefined Then
			ContractsMismatch = True;
		EndIf;
		
		If CompaniesMismatch OR ContractsMismatch Then
			
			NewRow = TableOfResults.Add();
			NewRow.MainDocument = DocumentRef;
			NewRow.SubordinateDocument = CheckObject;
			NewRow.MessageText = GenerateMessageTextByMismatch(CompaniesMismatch, ContractsMismatch) 
			+ ". Location: " + SubordinateLocation + " " + RulesTablesRow.TabSecAttributeSynonym;
			
		EndIf;
		
	EndIf;	 
	
EndProcedure

// IN the procedure, the document data is
// compared for cases when the contract of the document-owner is located in the tab. parts.
//
&AtServerNoContext
Procedure CompareDocumentsData_ContractInTabSec(CheckObject, ContractLocationTable, CurCompany, ContractsArray, TableOfResults, DocumentRef, RulesTablesRow, SubordinateLocation)
	
	SubordinateDocumentName = CheckObject.Metadata().Name;
	
	ContractLocationSubordinated = ContractLocationTable.Find(SubordinateDocumentName);
	
	If ContractLocationSubordinated = Undefined Then
		Return;
	EndIf;
	
	If ContractLocationSubordinated.AttributeType = "Attribute" Then
		
		CompaniesMismatch = False;
		ContractsMismatch = False;
		
		If CurCompany <> CheckObject.Company Then
			CompaniesMismatch = True;
		EndIf;
		
		ContractsMismatch = (ContractsArray.Find(CheckObject.Contract) = Undefined);
		
		If CompaniesMismatch OR ContractsMismatch Then
			
			NewRow = TableOfResults.Add();
			NewRow.MainDocument = DocumentRef;
			NewRow.SubordinateDocument = CheckObject;
			NewRow.MessageText = GenerateMessageTextByMismatch(CompaniesMismatch, ContractsMismatch) 
			+ ". Location: " + SubordinateLocation + " " + RulesTablesRow.TabSecAttributeSynonym;
			
		EndIf;
		
	ElsIf ContractLocationSubordinated.AttributeType = "TabularSection" Then
		
		CompaniesMismatch = False;
		ContractsMismatch = False;
		
		If CurCompany <> CheckObject.Company Then
			CompaniesMismatch = True;
		EndIf;
		
		ArrayContractSubordinate = CheckObject[ContractLocationSubordinated.TabularSectionName].UnloadColumn("Contract");
		
		ContractsMismatch = (NOT HasContractsMatchesInArrays(ContractsArray, ArrayContractSubordinate));
		
		If CompaniesMismatch OR ContractsMismatch Then
			
			NewRow = TableOfResults.Add();
			NewRow.MainDocument = DocumentRef;
			NewRow.SubordinateDocument = CheckObject;
			NewRow.MessageText = GenerateMessageTextByMismatch(CompaniesMismatch, ContractsMismatch) 
			+ ". Location: " + SubordinateLocation + " " + RulesTablesRow.TabSecAttributeSynonym;
			
		EndIf;
		
	EndIf;	 
	
EndProcedure

// Function generates a message text to a user about the mismatch according to the passed check boxes.
//
&AtServerNoContext
Function GenerateMessageTextByMismatch(CompaniesMismatch, ContractsMismatch)

	MessageText = "";
	
	If CompaniesMismatch AND ContractsMismatch Then
		
		MessageText = "Mismatches of companies to contracts are found";
		
	ElsIf CompaniesMismatch Then
		
		MessageText = "Companies mismatch is found";
		
	ElsIf ContractsMismatch Then
		
		MessageText = "Contracts mismatch is found";
	
	EndIf;
	
	Return MessageText;

EndFunction

// Function checks if there is the same contract in arrays.
//
&AtServerNoContext
Function HasContractsMatchesInArrays(ContractsArray, ArrayContractSubordinate)

	Result = False;
	
	For Each SubordinateContract In ArrayContractSubordinate Do
		If ContractsArray.Find(SubordinateContract) <> Undefined Then
			Result = True;
			Break;
		EndIf;	
	EndDo;
	
	Return Result;

EndFunction

// Procedure initializes data filling by the Cash flow items section and shows the data in DocumentResult.
// 
&AtServer
Procedure Attachable_OutputDataBySectionCashFlowItems(TemplateOutput)
	
	If Not CashFlowItemsFilledWith Then
		OutputPictureDataOutput(TemplateOutput);
		FillCashFlowItemData();
		CashFlowItemsFilledWith = True;
	EndIf;
	
	OutputSectionTitle(TemplateOutput);
	
	TemplateArea = TemplateOutput.GetArea("AreaIndent");
	ResultDocument.Put(TemplateArea);
	
	If CashFlowGroupEmpty(Catalogs.CashFlowItems.Payments) Then
		
		TemplateArea = TemplateOutput.GetArea("CFPaymentsNotFilled");
		TemplateArea.Parameters.ExecuteActionDecrypt = "ExecuteProcedureOnClient#OpenCatalogCashFlowItems(CurArea, PredefineVariant, DataBeenChanged)";
		ResultDocument.Put(TemplateArea);
		
		TemplateArea = TemplateOutput.GetArea("AreaIndent");
		ResultDocument.Put(TemplateArea);
		
	EndIf;
	
	If CashFlowGroupEmpty(Catalogs.CashFlowItems.Receipts) Then
		
		TemplateArea = TemplateOutput.GetArea("CFReceiptNotFilled");
		TemplateArea.Parameters.ExecuteActionDecrypt = "ExecuteProcedureOnClient#OpenCatalogCashFlowItems(CurArea, PredefineVariant, DataBeenChanged)";
		ResultDocument.Put(TemplateArea);
		
		TemplateArea = TemplateOutput.GetArea("AreaIndent");
		ResultDocument.Put(TemplateArea);
		
	EndIf;
	
	If CashFlowItems.GetItems().Count() = 0 Then
		OutputAreaNoData(TemplateOutput);
		OutputAreaUpdateDataByGeneratedSection(TemplateOutput);
		Return;
	EndIf;
	
	For Each String_Level1 In CashFlowItems.GetItems() Do
		
		If String_Level1.ItemsGroup = "Payments" Then
			
			TemplateArea = TemplateOutput.GetArea("CashFlowItems_Payments");
		
		ElsIf String_Level1.ItemsGroup = "Receipts" Then
			
			TemplateArea = TemplateOutput.GetArea("CashFlowItems_Receipts");
			
		ElsIf String_Level1.ItemsGroup = "Other" Then
			
			TemplateArea = TemplateOutput.GetArea("CashFlowItems_Other");
		
		EndIf;
		
		ResultDocument.Put(TemplateArea);
		
		For Each String_Level2 In String_Level1.GetItems() Do
			
			TemplateArea = TemplateOutput.GetArea("CFItem");
			TemplateArea.Parameters.CFItem = TrimAll(String_Level2.Item.Description);
			TemplateArea.Parameters.CFItemDetails = "ExecuteProcedureOnClient#OutputReportAcrticleCashFlow(CurArea, PredefineVariant, DataBeenChanged)";
			TemplateArea.Area(2,1,2,1).Mask = String(String_Level2.Item.UUID());
			ResultDocument.Put(TemplateArea);
			
		EndDo; 
		
	EndDo; 
	
	OutputAreaUpdateDataByGeneratedSection(TemplateOutput);
	 
EndProcedure

// Procedure implements mechanism of data control by the Cash flow items section.
//
&AtServer
Procedure FillCashFlowItemData()

	Query = New Query("SELECT
	                      |	CashAssets.Item,
	                      |	CashAssets.Currency,
	                      |	CashAssets.Recorder,
	                      |	SUM(CASE
	                      |			WHEN CashAssets.RecordType = VALUE(AccumulationRecordType.Receipt)
	                      |				THEN CashAssets.AmountCur
	                      |			ELSE 0
	                      |		END) AS AmountReceipt,
	                      |	SUM(CASE
	                      |			WHEN CashAssets.RecordType = VALUE(AccumulationRecordType.Expense)
	                      |				THEN CashAssets.AmountCur
	                      |			ELSE 0
	                      |		END) AS AmountExpense
	                      |INTO TU_DetailedRecords
	                      |FROM
	                      |	AccumulationRegister.CashAssets AS CashAssets
	                      |WHERE
	                      |	CashAssets.Period between &DateBeg AND &DateEnd
	                      |	AND CashAssets.Company = &Company
	                      |
	                      |GROUP BY
	                      |	CashAssets.Item,
	                      |	CashAssets.Currency,
	                      |	CashAssets.Recorder
	                      |;
	                      |
	                      |////////////////////////////////////////////////////////////////////////////////
	                      |SELECT
	                      |	TU_DetailedRecords.Item AS Item,
	                      |	TU_DetailedRecords.Currency AS Currency,
	                      |	SUM(CASE
	                      |			WHEN TU_DetailedRecords.Item = VALUE(Catalog.CashFlowItems.PaymentToVendor)
	                      |				THEN CASE
	                      |						WHEN TU_DetailedRecords.Recorder REFS Document.CashReceipt
	                      |								AND TU_DetailedRecords.Recorder.OperationKind = VALUE(Enum.OperationTypesCashReceipt.FromVendor)
	                      |							THEN 0
	                      |						WHEN TU_DetailedRecords.Recorder REFS Document.PaymentReceipt
	                      |								AND TU_DetailedRecords.Recorder.OperationKind = VALUE(Enum.OperationTypesPaymentReceipt.FromVendor)
	                      |							THEN 0
	                      |						ELSE TU_DetailedRecords.AmountReceipt
	                      |					END
	                      |			ELSE TU_DetailedRecords.AmountReceipt
	                      |		END) AS AmountReceipt,
	                      |	SUM(CASE
	                      |			WHEN TU_DetailedRecords.Item = VALUE(Catalog.CashFlowItems.PaymentFromCustomers)
	                      |				THEN CASE
	                      |						WHEN TU_DetailedRecords.Recorder REFS Document.CashVoucher
	                      |								AND TU_DetailedRecords.Recorder.OperationKind = VALUE(Enum.OperationTypesCashVoucher.ToCustomer)
	                      |							THEN 0
	                      |						WHEN TU_DetailedRecords.Recorder REFS Document.PaymentExpense
	                      |								AND TU_DetailedRecords.Recorder.OperationKind = VALUE(Enum.OperationTypesPaymentExpense.ToCustomer)
	                      |							THEN 0
	                      |						ELSE TU_DetailedRecords.AmountExpense
	                      |					END
	                      |			ELSE TU_DetailedRecords.AmountExpense
	                      |		END) AS AmountExpense
	                      |INTO TU_TurnoversByItemsCurrency
	                      |FROM
	                      |	TU_DetailedRecords AS TU_DetailedRecords
	                      |
	                      |GROUP BY
	                      |	TU_DetailedRecords.Item,
	                      |	TU_DetailedRecords.Currency
	                      |;
	                      |
	                      |////////////////////////////////////////////////////////////////////////////////
	                      |SELECT
	                      |	Payments.ItemsGroup AS ItemsGroup,
	                      |	Payments.Item AS Item,
	                      |	Payments.Currency AS Currency,
	                      |	Payments.Recorder AS Recorder,
	                      |	Payments.RecorderDate AS RecorderDate,
	                      |	Payments.AmountReceipt AS AmountReceipt,
	                      |	Payments.AmountExpense AS AmountExpense
	                      |FROM
	                      |	(SELECT
	                      |		NestedSelect.ItemsGroup AS ItemsGroup,
	                      |		NestedSelect.Item AS Item,
	                      |		NestedSelect.Currency AS Currency,
	                      |		TU_DetailedRecords.Recorder AS Recorder,
	                      |		TU_DetailedRecords.Recorder.Date AS RecorderDate,
	                      |		TU_DetailedRecords.AmountReceipt AS AmountReceipt,
	                      |		TU_DetailedRecords.AmountExpense AS AmountExpense
	                      |	FROM
	                      |		(SELECT DISTINCT
	                      |			""Payments"" AS ItemsGroup,
	                      |			TU_TurnoversByItemsCurrency.Item AS Item,
	                      |			TU_TurnoversByItemsCurrency.Currency AS Currency
	                      |		FROM
	                      |			TU_TurnoversByItemsCurrency AS TU_TurnoversByItemsCurrency
	                      |		WHERE
	                      |			TU_TurnoversByItemsCurrency.Item IN HIERARCHY (VALUE(Catalog.CashFlowItems.Payments))
	                      |			AND TU_TurnoversByItemsCurrency.AmountReceipt <> 0) AS NestedSelect
	                      |			INNER JOIN TU_DetailedRecords AS TU_DetailedRecords
	                      |			ON NestedSelect.Item = TU_DetailedRecords.Item
	                      |				AND NestedSelect.Currency = TU_DetailedRecords.Currency) AS Payments
	                      |
	                      |UNION ALL
	                      |
	                      |SELECT
	                      |	Receipts.ItemsGroup,
	                      |	Receipts.Item,
	                      |	Receipts.Currency,
	                      |	Receipts.Recorder,
	                      |	Receipts.RecorderDate,
	                      |	Receipts.AmountReceipt,
	                      |	Receipts.AmountExpense
	                      |FROM
	                      |	(SELECT
	                      |		NestedSelect.ItemsGroup AS ItemsGroup,
	                      |		NestedSelect.Item AS Item,
	                      |		NestedSelect.Currency AS Currency,
	                      |		TU_DetailedRecords.Recorder AS Recorder,
	                      |		TU_DetailedRecords.Recorder.Date AS RecorderDate,
	                      |		TU_DetailedRecords.AmountReceipt AS AmountReceipt,
	                      |		TU_DetailedRecords.AmountExpense AS AmountExpense
	                      |	FROM
	                      |		(SELECT DISTINCT
	                      |			""Receipts"" AS ItemsGroup,
	                      |			TU_TurnoversByItemsCurrency.Item AS Item,
	                      |			TU_TurnoversByItemsCurrency.Currency AS Currency
	                      |		FROM
	                      |			TU_TurnoversByItemsCurrency AS TU_TurnoversByItemsCurrency
	                      |		WHERE
	                      |			TU_TurnoversByItemsCurrency.Item IN HIERARCHY (VALUE(Catalog.CashFlowItems.Receipts))
	                      |			AND TU_TurnoversByItemsCurrency.AmountExpense <> 0) AS NestedSelect
	                      |			INNER JOIN TU_DetailedRecords AS TU_DetailedRecords
	                      |			ON NestedSelect.Item = TU_DetailedRecords.Item
	                      |				AND NestedSelect.Currency = TU_DetailedRecords.Currency) AS Receipts
	                      |
	                      |UNION ALL
	                      |
	                      |SELECT
	                      |	Other.ItemsGroup,
	                      |	Other.Item,
	                      |	Other.Currency,
	                      |	Other.Recorder,
	                      |	Other.RecorderDate,
	                      |	Other.AmountReceipt,
	                      |	Other.AmountExpense
	                      |FROM
	                      |	(SELECT
	                      |		NestedSelect.ItemsGroup AS ItemsGroup,
	                      |		NestedSelect.Item AS Item,
	                      |		NestedSelect.Currency AS Currency,
	                      |		TU_DetailedRecords.Recorder AS Recorder,
	                      |		TU_DetailedRecords.Recorder.Date AS RecorderDate,
	                      |		TU_DetailedRecords.AmountReceipt AS AmountReceipt,
	                      |		TU_DetailedRecords.AmountExpense AS AmountExpense
	                      |	FROM
	                      |		(SELECT DISTINCT
	                      |			""Other"" AS ItemsGroup,
	                      |			TU_TurnoversByItemsCurrency.Item AS Item,
	                      |			TU_TurnoversByItemsCurrency.Currency AS Currency
	                      |		FROM
	                      |			TU_TurnoversByItemsCurrency AS TU_TurnoversByItemsCurrency
	                      |		WHERE
	                      |			Not TU_TurnoversByItemsCurrency.Item IN HIERARCHY (VALUE(Catalog.CashFlowItems.Payments), VALUE(Catalog.CashFlowItems.Receipts))
	                      |			AND TU_TurnoversByItemsCurrency.AmountReceipt <> TU_TurnoversByItemsCurrency.AmountExpense) AS NestedSelect
	                      |			INNER JOIN TU_DetailedRecords AS TU_DetailedRecords
	                      |			ON NestedSelect.Item = TU_DetailedRecords.Item
	                      |				AND NestedSelect.Currency = TU_DetailedRecords.Currency) AS Other
	                      |
	                      |ORDER BY
	                      |	ItemsGroup,
	                      |	RecorderDate
	                      |TOTALS
	                      |	SUM(AmountReceipt),
	                      |	SUM(AmountExpense)
	                      |BY
	                      |	ItemsGroup,
	                      |	Item,
	                      |	Currency,
	                      |	Recorder");
						  
	Query.SetParameter("DateBeg", BeginOfPeriod);
	Query.SetParameter("DateEnd", EndOfDay(EndOfPeriod));
	Query.SetParameter("Company", Company);
	
	QueryResult = Query.Execute();
	
	ValueToFormAttribute(QueryResult.Unload(QueryResultIteration.ByGroups), "CashFlowItems");

EndProcedure

// Function checks if there are subordinate items in the passed group.
// Parameters - RefToGroup - group where you need to find items
//
&AtServerNoContext
Function CashFlowGroupEmpty(RefToGroup)
	
	Query = New Query("SELECT TOP 1
	                      |	CashFlowItems.Ref
	                      |FROM
	                      |	Catalog.CashFlowItems AS CashFlowItems
	                      |WHERE
	                      |	CashFlowItems.IsFolder = FALSE
	                      |	AND CashFlowItems.Ref <> &RefToGroup
	                      |	AND CashFlowItems.Ref IN HIERARCHY(&RefToGroup)");
						  
	Query.SetParameter("RefToGroup", RefToGroup);					  
	
	QueryResult = Query.Execute();
	
	Return QueryResult.IsEmpty();

EndFunction

// sections

// Procedure outputs the first row with listing
// of sections and description, called once on opening.
//
&AtServer
Procedure OutputFirstPage()
	
	TemplateOutput = FormAttributeToValue("Object").GetTemplate("TemplateOutput");
	
	ResultDocument.Clear();
	
	TemplateArea = TemplateOutput.GetArea("TitleDefault");	
	ResultDocument.Put(TemplateArea);
	
	DataTree = FormAttributeToValue("SectionTree");
	
	For Each String_Level0 In DataTree.Rows Do
		
		For Each String_Level1 In String_Level0.Rows Do
			
			TemplateArea = TemplateOutput.GetArea("StringGoToSection");
			TemplateArea.Parameters.Section = String_Level1.AccountingSectionPresentation;
			TemplateArea.Parameters.GoToNextSection = "GoToRow#" + String(String_Level1.TreeLineNumber);
			ResultDocument.Put(TemplateArea);
			
			Try
				TemplateArea = TemplateOutput.GetArea("Description" + String_Level1.AccountingSection);
				ResultDocument.Put(TemplateArea);			
			Except
				Message = New UserMessage;
				Message.Text = "Description to section is not found " + String_Level1.AccountingSection;
				Message.SetData(Object);
				Message.Message(); 
			EndTry;
			
			
		EndDo; 
		
	EndDo;
	
	OutputHyperlinkDescription(TemplateOutput);	
	
EndProcedure

// Procedure outputs hyperlink to executed sections description to the tabular document. 
//
&AtServer
Procedure OutputHyperlinkDescription(TemplateOutput)

	TemplateArea = TemplateOutput.GetArea("InformationDetailed");
	TemplateArea.Parameters.OpenDescriptionDetailsParameter = "ExecuteProcedureOnClient#OutputDetailedDescription(PredefineVariant, DataBeenChanged)";	
	ResultDocument.Put(TemplateArea);	

EndProcedure

// Output a final report.
// Procedure-handler of clicking the Final report hyperlink.
//
&AtClient
Procedure OutputFinalReport()
	
	OutputFinalReport_AtServer();

EndProcedure

// Generate and output a final report on server.
//
&AtServer
Procedure OutputFinalReport_AtServer()

	DataProcessorObject = FormAttributeToValue("Object");
	
	TemplateOutput = DataProcessorObject.GetTemplate("TemplateOutput");
	
	ResultDocument.Clear();
	
	TemplateArea = TemplateOutput.GetArea("TitleFinalReport");
	ResultDocument.Put(TemplateArea);
	
	DataTree = FormAttributeToValue("SectionTree");
	
	For Each String_Level0 In DataTree.Rows Do
	
		For Each String_Level1 In String_Level0.Rows Do
			
			OutputReportOnSection(String_Level1, TemplateOutput);
			
			OutputSubordinateSectionsResults(String_Level1, TemplateOutput);
			
		EndDo; 
		
	EndDo; 
	
	TemplateArea = TemplateOutput.GetArea("Exit");
	TemplateArea.Parameters.Exit = "EXIT";
	TemplateArea.Parameters.ExecuteActionDecrypt = "ExecuteProcedureOnClient#Close()";
	ResultDocument.Put(TemplateArea);
	
	OutputHyperlinkDescription(TemplateOutput);

EndProcedure

// Bypass of the
// subordinate tree rows, called from OutputFinalReport_OnServer().
//
&AtServer
Procedure OutputSubordinateSectionsResults(ParentRow, TemplateOutput)
	
	For Each CurrentRow In ParentRow.Rows Do
		
		OutputReportOnSection(CurrentRow, TemplateOutput);
		
		OutputSubordinateSectionsResults(CurrentRow, TemplateOutput);
		
	EndDo;	
	
EndProcedure

// Procedure puts out an analysis report by
// each section according to the data located in the attribute of the ImageIndex row.
//
&AtServer
Procedure OutputReportOnSection(CurrentRow, TemplateOutput)

	If CurrentRow.PictureIndex = 0 Then
		TemplateArea = TemplateOutput.GetArea("SectionWasNotAnalyzed");
	ElsIf CurrentRow.PictureIndex = 1 Then
		TemplateArea = TemplateOutput.GetArea("SectionNotPatched");		
	ElsIf CurrentRow.PictureIndex = 2 Then
		TemplateArea = TemplateOutput.GetArea("SectionNotFullyFixed");	
	ElsIf CurrentRow.PictureIndex = 3 Then
		TemplateArea = TemplateOutput.GetArea("SectionNoErrors");
	ElsIf CurrentRow.PictureIndex = 4 Then
		TemplateArea = TemplateOutput.GetArea("SectionWasCorrected");
	Else
		Return;
	EndIf;
	
	TemplateArea.Parameters.Section = CurrentRow.AccountingSectionPresentation;
	ResultDocument.Put(TemplateArea);

EndProcedure

// Tab. clearing is in progress document (DocumentResult attribute).
//
&AtServer
Procedure ClearDocumentResult()

	ResultDocument.Clear();	

EndProcedure

 // Procedure-handler of clicking the hyperlink of analysis result for sections: Accounts payable and Accounts receivable.
 // Generates report in a separate window.
 // Parameters
 // 	CurArea - area of the tabular document cells according to which the click was executed;
 // 	PredefineVariant - Number;
 // 	DataBeenChanged - Boolean.
 //
&AtClient
Procedure OutputReportBySettlements(CurArea, PredefineVariant, DataBeenChanged)
	
	PredefineVariant = 2;

	CurrentRow = GetCurrRowFromAreaName(CurArea.Name);
	CounterpartyRef = ResultDocument.Area(CurrentRow + "C3:" + CurrentRow + "C4").Details;
	FormParameters = New Structure("ReportKind, CounterpartyRef, BeginOfPeriod, EndOfPeriod, Company", "StatementOfAccount", CounterpartyRef, BeginOfPeriod, EndOfPeriod, Company);
	
	OpenReportForm(FormParameters, True);

EndProcedure

// Procedure-handler of clicking the Advance offset hyperlink in the Accounts payable section.
//
&AtServer
Procedure Attachable_ExecuteExpensesOffsetByVendor(CurArea, PredefineVariant, DataBeenChanged)
	
	PredefineVariant = 2;
	
	DataBeenChanged = True;

	CurrentRow = GetCurrRowFromAreaName(CurArea.Name);
	CounterpartyRef = ResultDocument.Area(CurrentRow + "C3:" + CurrentRow + "C4").Details;
	
	For Each TabularSectionRow In AccountsPayable Do
		
		If (TabularSectionRow.Counterparty = CounterpartyRef) AND (NOT TabularSectionRow.DataProcessorExecuted) AND TabularSectionRow.ThereAreTurnoversForPeriod Then
			
			RefillVendorDocuments(CounterpartyRef);
			
			TabularSectionRow.WereCorrections = True;
			
			CalculationsTable = GenerateTableAccountsPayable(CounterpartyRef);
			
			If CalculationsTable.Count() = 0 Then
				TabularSectionRow.DataProcessorExecuted = True;
			Else
				TabularSectionRow.ThereAreTurnoversForPeriod = CalculationsTable[0].ThereAreTurnoversForPeriod
			EndIf;
			
			Break;
			
		EndIf;
	
	EndDo; 
	
	WriteExecutionDateBySection();
	
	OutputDataBySection();
	
EndProcedure

// IN the procedure, the Prepayment and PaymentDetails tabular
// sections are filled in, and documents are posted, i.e. advances of section "Accounts payable" are accounted applicationmatically
//
&AtServer
Procedure RefillVendorDocuments(CounterpartyRef)

	Query = New Query("SELECT
	                      |	VendorsSettlementsTurnovers.Recorder AS Recorder,
	                      |	VendorsSettlementsTurnovers.Period AS Period
	                      |FROM
	                      |	AccumulationRegister.AccountsPayable.Turnovers(
	                      |			&DateBeg,
	                      |			&DateEnd,
	                      |			Recorder,
	                      |			Company = &Company
	                      |				AND Counterparty = &Counterparty) AS VendorsSettlementsTurnovers
	                      |
	                      |ORDER BY
	                      |	Period,
	                      |	Recorder");
						  
	Query.SetParameter("DateBeg", New Boundary(BeginOfPeriod, BoundaryType.Including));					  
	Query.SetParameter("DateEnd", New Boundary(EndOfDay(EndOfPeriod), BoundaryType.Including));
	Query.SetParameter("Company", Company);
	Query.SetParameter("Counterparty", CounterpartyRef);
	
	QueryResult = Query.Execute();
	
	Selection = QueryResult.Select();
	
	While Selection.Next() Do		
		
		If IsPaymentDocument(Selection.Recorder) Then//decryption refilling
			
			DocumentObject = Selection.Recorder.GetObject(); 
			
			Try
				DocumentObject.FillPaymentDetails();
				DocumentObject.Write(DocumentWriteMode.Posting, DocumentPostingMode.Regular);
				WriteStoryObjectChanges(Selection.Recorder, "Posting", "Document posting.");
			Except
				ErrorString = "Unable to process document " + String(Selection.Recorder);
				Message = New UserMessage;
				Message.Text = ErrorString;
				Message.SetData(Object);
				Message.Message(); 
			EndTry;
			
		ElsIf Selection.Recorder.Metadata().TabularSections.Find("Prepayment") <> Undefined Then
			
			DocumentObject = Selection.Recorder.GetObject();
			
			Try
				DocumentObject.FillPrepayment();
				DocumentObject.Write(DocumentWriteMode.Posting, DocumentPostingMode.Regular);
				WriteStoryObjectChanges(Selection.Recorder, "Posting", "Document posting.");
			Except
				ErrorString = "Unable to process document " + String(Selection.Recorder);
				Message = New UserMessage;
				Message.Text = ErrorString;
				Message.SetData(Object);
				Message.Message(); 
			EndTry;
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Procedure-handler of clicking the Advance offset hyperlink in the Accounts receivable section.
//
&AtServer
Procedure Attachable_ExecuteExpensesOffsetByCustomer(CurArea, PredefineVariant, DataBeenChanged)
	
	PredefineVariant = 2;
	
	DataBeenChanged = True;

	CurrentRow = GetCurrRowFromAreaName(CurArea.Name);
	CounterpartyRef = ResultDocument.Area(CurrentRow + "C3:" + CurrentRow + "C4").Details;
	
	For Each TabularSectionRow In AccountsReceivable Do
		
		If (TabularSectionRow.Counterparty = CounterpartyRef) AND (NOT TabularSectionRow.DataProcessorExecuted) AND TabularSectionRow.ThereAreTurnoversForPeriod Then
			
			RefillCustomerDocuments(CounterpartyRef);
			
			TabularSectionRow.WereCorrections = True;
			
			CalculationsTable = GenerateTableAccountsReceivable(CounterpartyRef);
			
			If CalculationsTable.Count() = 0 Then
				TabularSectionRow.DataProcessorExecuted = True;
			Else
				TabularSectionRow.ThereAreTurnoversForPeriod = CalculationsTable[0].ThereAreTurnoversForPeriod
			EndIf;
			
			Break;
			
		EndIf;
	
	EndDo;
	
	WriteExecutionDateBySection();
	
	OutputDataBySection();
	
EndProcedure

// IN the procedure, the Prepayment and PaymentDetails tabular
// sections are filled in, and documents are posted, i.e. advances of section "Accounts receivable" are accounted applicationmatically
//
&AtServer
Procedure RefillCustomerDocuments(CounterpartyRef)

	Query = New Query("SELECT
	                      |	CustomersSettlementsTurnovers.Recorder AS Recorder,
	                      |	CustomersSettlementsTurnovers.Period AS Period
	                      |FROM
	                      |	AccumulationRegister.AccountsReceivable.Turnovers(
	                      |			&DateBeg,
	                      |			&DateEnd,
	                      |			Recorder,
	                      |			Company = &Company
	                      |				AND Counterparty = &Counterparty) AS CustomersSettlementsTurnovers
	                      |
	                      |ORDER BY
	                      |	Period,
	                      |	Recorder");
						  
	Query.SetParameter("DateBeg", New Boundary(BeginOfPeriod, BoundaryType.Including));					  
	Query.SetParameter("DateEnd", New Boundary(EndOfDay(EndOfPeriod), BoundaryType.Including));
	Query.SetParameter("Company", Company);
	Query.SetParameter("Counterparty", CounterpartyRef);
	
	QueryResult = Query.Execute();
	
	Selection = QueryResult.Select(QueryResultIteration.ByGroups);	
	
	While Selection.Next() Do
		
		If IsPaymentDocument(Selection.Recorder) Then//decryption refilling
			
			DocumentObject = Selection.Recorder.GetObject(); 
			
			Try
				DocumentObject.FillPaymentDetails();
				DocumentObject.Write(DocumentWriteMode.Posting, DocumentPostingMode.Regular);
				WriteStoryObjectChanges(Selection.Recorder, "Posting", "Document posting.");
			Except
				ErrorString = "Unable to process document " + String(Selection.Recorder);
				Message = New UserMessage;
				Message.Text = ErrorString;
				Message.SetData(Object);
				Message.Message(); 
			EndTry;
			
		ElsIf Selection.Recorder.Metadata().TabularSections.Find("Prepayment") <> Undefined Then
			
			DocumentObject = Selection.Recorder.GetObject();
			
			Try
				DocumentObject.FillPrepayment();
				DocumentObject.Write(DocumentWriteMode.Posting, DocumentPostingMode.Regular);
				WriteStoryObjectChanges(Selection.Recorder, "Posting", "Document posting.");
			Except
				ErrorString = "Unable to process document " + String(Selection.Recorder);
				Message = New UserMessage;
				Message.Text = ErrorString;
				Message.SetData(Object);
				Message.Message(); 
			EndTry;
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Procedure reposts
// the documents located in the DocumentsTableForReposting attribute.
//
&AtServer
Procedure Attachable_ExecuteRepostByExchangeRatesDifferences(PredefineVariant, DataBeenChanged)
	
	PredefineVariant = 1;
	
	DataBeenChanged = True;
	
	TableForReposting = New ValueTable;
	TableForReposting.Columns.Add("DocumentRef");
	TableForReposting.Columns.Add("Date");
	
	For Each String_Level1 In IncorrectExchangeDifferencesDC.GetItems() Do
		
		For Each String_Level2 In String_Level1.GetItems() Do
			NewRow = TableForReposting.Add();
			NewRow.DocumentRef = String_Level2.Recorder;
			NewRow.Date = String_Level2.Recorder.Date;
		EndDo; 
		
	EndDo;
	
	For Each String_Level1 In IncorrectExchangeDifferencesCustomers.GetItems() Do
		
		For Each String_Level2 In String_Level1.GetItems() Do
			NewRow = TableForReposting.Add();
			NewRow.DocumentRef = String_Level2.Recorder;
			NewRow.Date = String_Level2.Recorder.Date;
		EndDo; 
		
	EndDo;
	
	For Each String_Level1 In IncorrectExchangeDifferencesSuppliers.GetItems() Do
		
		For Each String_Level2 In String_Level1.GetItems() Do
			NewRow = TableForReposting.Add();
			NewRow.DocumentRef = String_Level2.Recorder;
			NewRow.Date = String_Level2.Recorder.Date;
		EndDo; 
		
	EndDo;
	
	TableForReposting.GroupBy("DocumentRef, Date");
	TableForReposting.Sort("Date");
	
	For Each TableRow In TableForReposting Do
		
		DocumentObject = TableRow.DocumentRef.GetObject();
		
		Try
		
			DocumentObject.Write(DocumentWriteMode.Posting, DocumentPostingMode.Regular);
			
			WriteStoryObjectChanges(TableRow.DocumentRef, "Posting", "Document posting.");
		
		Except
			
			ErrorText = "Unable to repost document " + String(TableRow.DocumentRef) + Chars.LF + ErrorDescription();
			
			Message = New UserMessage;
			Message.Text = ErrorText;
			Message.SetData(Object);
			Message.Message();
			
			Return;
			
		EndTry;
		
	EndDo;
	
	IncorrectExchangeDifferencesDC.GetItems().Clear();
	IncorrectExchangeDifferencesCustomers.GetItems().Clear();
	IncorrectExchangeDifferencesSuppliers.GetItems().Clear();
	
	ExchangeRatesDifferencesFilledWith = False;	
	
	ExchangeDifferencesDocumentsPereprovedeny = True;
	
	WriteExecutionDateBySection();
	
	OutputDataBySection();

EndProcedure

// Procedure-handler of clicking the Set default specification hyperlink.
// Initialization of the Specification attribute filling for specified products.
//
&AtServer
Procedure Attachable_SetDefaultSpecification(CurArea, PredefineVariant, DataBeenChanged)
	
	PredefineVariant = 2;
	
	DataBeenChanged = True;
 
	CurrentRow = GetCurrRowFromAreaName(CurArea.Name);
	ProductsCurrent = ResultDocument.Area(CurrentRow + "C3:" + CurrentRow + "C4").Details;
	CurrentSpecification = ResultDocument.Area(CurrentRow + "C5").Details;
	
	DataTable = FormAttributeToValue("ProductsWithoutBillsOfMaterials");
	
	RowArray = DataTable.FindRows(New Structure("Products, Specification", ProductsCurrent, CurrentSpecification));
	
	If RowArray.Count() > 0 Then
		Try
			SetSpecificationToProducts(ProductsCurrent, CurrentSpecification);
			WriteStoryObjectChanges(ProductsCurrent, "Record", "Write catalog item.");
		Except
			Message = New UserMessage;
			Message.Text = "Unable to set specification." + Chars.LF + ErrorDescription();
			Message.SetData(Object);
			Message.Message();
			Return;
		EndTry;
		
		RowArray[0].DataProcessorExecuted = True;
	EndIf;
	
	ValueToFormAttribute(DataTable, "ProductsWithoutBillsOfMaterials");
	
	WriteExecutionDateBySection();
	
	OutputDataBySection();
 
EndProcedure

// Procedure-handler of clicking the Select and set specification hyperlink.
// Open a selection form of the Specification catalog.
//
&AtClient
Procedure SelectSetDefaultSpecification(CurArea, PredefineVariant, DataBeenChanged)
	
	PredefineVariant = 2;
	
	DataBeenChanged = True;
 
	CurrentRow = GetCurrRowFromAreaName(CurArea.Name);
	ProductsCurrent = ResultDocument.Area(CurrentRow + "C3:" + CurrentRow + "C4").Details;

	Filter = New Structure("Owner", ProductsCurrent);
	FormParameters = New Structure("Filter", Filter);
	
	OpenForm("Catalog.BillsOfMaterials.ChoiceForm", FormParameters, ThisForm);	
 
EndProcedure

// Procedure-handler of clicking the Several BillsOfMaterials are found hyperlink.
// Open a list form of the Specification catalog.
//
&AtClient
Procedure OpenBillsOfMaterialsList(CurArea, PredefineVariant, DataBeenChanged)
	
	PredefineVariant = 2;
	
	CurrentRow = GetCurrRowFromAreaName(CurArea.Name);
	ProductsCurrent = ResultDocument.Area(CurrentRow + "C3:" + CurrentRow + "C4").Details;

	Filter = New Structure("Owner", ProductsCurrent);
	FormParameters = New Structure("Filter", Filter);
	
	OpenForm("Catalog.BillsOfMaterials.ListForm", FormParameters);

EndProcedure

// Processor of specification selection from selection form.
// Called from the ChoiceProcessing(SelectedValue,
// SelectionSource) predefined procedure Parameters:
// SelectedSpecification - matches value of the SelectedValue variable from the SelectionProcessor procedure.	
//
&AtServer
Procedure ProcessBillsOfMaterialselection(SelectedSpecification)

	DataTable = FormAttributeToValue("ProductsWithoutBillsOfMaterials");
	
	ProductsCurrent = SelectedSpecification.Owner;
	
	RowArray = DataTable.FindRows(New Structure("Products, Specification", ProductsCurrent, Catalogs.BillsOfMaterials.EmptyRef()));
	
	If RowArray.Count() > 0 Then
		Try
			SetSpecificationToProducts(ProductsCurrent, SelectedSpecification);
			WriteStoryObjectChanges(ProductsCurrent, "Record", "Write catalog item.");
		Except
			Message = New UserMessage;
			Message.Text = "Unable to set specification." + Chars.LF + ErrorDescription();
			Message.SetData(Object);
			Message.Message();
			Return;
		EndTry;
		
		RowArray[0].Specification = SelectedSpecification;
		RowArray[0].DataProcessorExecuted = True;
	EndIf;
	
	ValueToFormAttribute(DataTable, "ProductsWithoutBillsOfMaterials");
	
	WriteExecutionDateBySection();
	
	OutputDataBySection();

EndProcedure

// Procedure fills in the Specification attribute with the
// specified value and writes the item of the Products catalog.
//
&AtServerNoContext
Procedure SetSpecificationToProducts(ProductsRef, SpecificationRefs)

	ProductsObject = ProductsRef.GetObject();
	ProductsObject.Specification = SpecificationRefs;
	ProductsObject.Write();	

EndProcedure

// Procedure-handler of clicking
// the Set specification hyperlink in the Subcontractors reports without specification section.
//
&AtServer
Procedure Attachable_SetSpecificationToProcReport(CurArea, PredefineVariant, DataBeenChanged)
	
	PredefineVariant	= 2;	
	DataBeenChanged		= True;

	CurrentRow				= GetCurrRowFromAreaName(CurArea.Name);
	CurrentRef				= ResultDocument.Area(CurrentRow + "C3:" + CurrentRow + "C4").Details;
	CurrentSpecification	= ResultDocument.Area(CurrentRow + "C5").Details;
	
	DataTable = FormAttributeToValue("SubcontractorBillsOfMaterialsReports");
	
	RowArray = DataTable.FindRows(New Structure("DocumentRef, Specification", CurrentRef, CurrentSpecification));
	
	If RowArray.Count() > 0 Then

		DocumentObject = CurrentRef.GetObject();
		DocumentObject.Specification		= CurrentSpecification;
		DocumentObject.DataExchange.Load	= True;
		
		Try
			DocumentObject.Write(DocumentWriteMode.Write);
			WriteStoryObjectChanges(CurrentRef, "Record", "Write document."); 
		Except
			CommonUseClientServer.MessageToUser(StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Unable to write %1 (%2)'"),
				String(CurrentRef),
				ErrorDescription()));
			
			Return;
		EndTry;
		
		RowArray[0].DataProcessorExecuted = True;
		
	EndIf;
	
	ValueToFormAttribute(DataTable, "SubcontractorBillsOfMaterialsReports");
	
	WriteExecutionDateBySection();
	
	OutputDataBySection();

EndProcedure

// Function defines if there is a type of passed
// document in the TypesArrayPaymentDocuments list Parameters:
// DocumentRef - ref of the defined document
//
&AtServer
Function IsPaymentDocument(DocumentRef)
	
	DocumentType = TypeOf(DocumentRef);
	
	Return ArrayTypePaymentDocuments.FindByValue(DocumentType) <> Undefined;
	
EndFunction

// Procedure writes the correction date for each section to the CorrectionDatesExecutionBySections information register.
// Called during data modification.
//
&AtServer
Procedure WriteExecutionDateBySection()

	RecordSet = InformationRegisters.CorrectionsOfLogicalErrorsInAccounting.CreateRecordSet();
	RecordSet.Filter.AccountingSection.Set(CurrentAccountingSection);
	
	Record = RecordSet.Add();
	Record.AccountingSection = CurrentAccountingSection;
	Record.ExecutionDate = CurrentDate();
	
	RecordSet.Write();

EndProcedure

// Procedure-handler of clicking the "For more information on each check
// stage, see ..." hyperlink shows a detailed description of the current processor mechanisms in a separate window.
//
&AtClient
Procedure OutputDetailedDescription(PredefineVariant, DataBeenChanged)
	
	PredefineVariant = 2;
	
	FormKey = "ControlAccountingCorrectness_DetailedDescriptionForm";
	
	FormParameters = New Structure("TransitionLink", CurrentLinkToHelp);
	DescriptionForm = GetForm("DataProcessor.AccountingCorrectnessControl.Form.DetailedDescriptionForm", FormParameters, ThisForm, FormKey);
	
	If DescriptionForm.IsOpen() Then
		DescriptionForm.Close();
		DescriptionForm = Undefined;
		DescriptionForm = GetForm("DataProcessor.AccountingCorrectnessControl.Form.DetailedDescriptionForm", FormParameters, ThisForm, FormKey);
	EndIf;
	
	OpenForm(DescriptionForm);

EndProcedure

// Procedure-handler of clicking the Mismatch is found hyperlink in the section Subcontractors report. - mismatch of
// writeoffs to BillsOfMaterials. Outputs to a separate window a mismatches report.
//
&AtClient
Procedure OutputReportByMismatchProcReport(CurArea, PredefineVariant, DataBeenChanged)
	
	PredefineVariant = 2;

	CurrentRow = GetCurrRowFromAreaName(CurArea.Name);
	DocumentRef = ResultDocument.Area(CurrentRow + "C3:" + CurrentRow + "C4").Details;
	
	DifferencesTable = Undefined;
	
	For Each TableRow In SubcontractorInconsistenciesReports Do
		If TableRow.DocumentRef = DocumentRef Then
			DifferencesTable = TableRow.DifferencesTable;
			Break;
		EndIf;	
	EndDo; 
	
	FormParameters = New Structure("ReportKind, DocumentRef, DifferencesTable", "WriteOffsInconsistenciesToBillsOfMaterials", DocumentRef, DifferencesTable);
	
	OpenReportForm(FormParameters, True);
	
EndProcedure

// Procedure-handler of clicking the Refill and repost hyperlink in the Subcontractors reports section - mismatch of
// writeoffs to BillsOfMaterials. Refills a specific subcontractor report by
// the specification calling the FillTabularSectionBySpecification export procedure from
// the object module and reposts the document.
//
&AtServer
Procedure Attachable_CorrectNoncorrReportProc(CurArea, PredefineVariant, DataBeenChanged)
	
	PredefineVariant = 2;
	
	DataBeenChanged = True;

	CurrentRow = GetCurrRowFromAreaName(CurArea.Name);
	DocumentRef = ResultDocument.Area(CurrentRow + "C3:" + CurrentRow + "C4").Details;
	
	RowArray = SubcontractorInconsistenciesReports.FindRows(New Structure("DocumentRef", DocumentRef));
	
	If RowArray.Count() > 0 Then
		
		DocumentObject = DocumentRef.GetObject();
		
		DocumentObject.FillTabularSectionBySpecification(DocumentObject.Specification, DocumentObject.Quantity, DocumentObject.MeasurementUnit);
		
		Try
			DocumentObject.Write(DocumentWriteMode.Posting, DocumentPostingMode.Regular);
			WriteStoryObjectChanges(DocumentRef, "Posting", "Document posting.");
		Except
			Message = New UserMessage;
			Message.Text = "Unable to repost document " + String(DocumentRef) + Chars.LF + ErrorDescription();
			Message.SetData(Object);
			Message.Message(); 
			Return;
		EndTry;
		
		RowArray[0].DataProcessorExecuted = True;
		
		WriteExecutionDateBySection();
	
		OutputDataBySection();
		
	EndIf;

EndProcedure

// Procedure-handler of clicking the Offered BillsOfMaterials hyperlink.in the doc. section Production without BillsOfMaterials.
// Outputs to separate report with offered BillsOfMaterials.
&AtClient
Procedure OutputReportDocProductionBillsOfMaterials(CurArea, PredefineVariant, DataBeenChanged)
	
	PredefineVariant = 2;

	CurrentRow = GetCurrRowFromAreaName(CurArea.Name);
	DocumentRef = ResultDocument.Area(CurrentRow + "C3:" + CurrentRow + "C4").Details;
	
	FormParameters = New Structure("ReportKind, DocumentRef", "SuggestedProductionBillsOfMaterials", DocumentRef);
	
	OpenReportForm(FormParameters, True);

EndProcedure

// Procedure-handler of clicking the Set BillsOfMaterials hyperlink in the section doc. Production without BillsOfMaterials.
// Fills in BillsOfMaterials to tab. the Document products Production parts and document record
//
&AtServer
Procedure Attachable_SetBillsOfMaterialsInDocProduction(CurArea, PredefineVariant, DataBeenChanged)
	
	PredefineVariant = 2;
	
	DataBeenChanged = True;

	CurrentRow = GetCurrRowFromAreaName(CurArea.Name);
	DocumentRef = ResultDocument.Area(CurrentRow + "C3:" + CurrentRow + "C4").Details;
	
	
	RowArray = DocProductionBillsOfMaterials.FindRows(New Structure("DocumentRef", DocumentRef));
	
	If RowArray.Count() > 0 Then
		
		DocumentObject = DocumentRef.GetObject();
		
		For Each TabularSectionRow In DocumentObject.Products Do
			
			If Not ValueIsFilled(TabularSectionRow.Specification) Then
				
				TabularSectionRow.Specification = TabularSectionRow.Products.Specification;	
				
			EndIf;
			
		EndDo;
		
		DocumentObject.DataExchange.Load = True;
		
		Try
			DocumentObject.Write(DocumentWriteMode.Write);
			WriteStoryObjectChanges(DocumentRef, "Record", "Write document.");
		Except
			CommonUseClientServer.MessageToUser(StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Unable to write %1 (%2)'"),
				String(DocumentRef),
				ErrorDescription()));			
			Return;
		EndTry;		
		
		RowArray[0].DataProcessorExecuted = True;
		
	EndIf;
	
	WriteExecutionDateBySection();
	
	OutputDataBySection();
	
EndProcedure

// Procedure-handler of clicking the Mismatch is found hyperlink in the section doc. Production - mismatch of writeoffs
// to BillsOfMaterials. Outputs a mismatches report to a separate window.
//
&AtClient
Procedure OutputReportByMismatchesDocProduction(CurArea, PredefineVariant, DataBeenChanged)
	
	PredefineVariant = 2;

	CurrentRow = GetCurrRowFromAreaName(CurArea.Name);
	DocumentRef = ResultDocument.Area(CurrentRow + "C3:" + CurrentRow + "C4").Details;
	
	DifferencesTable = Undefined;
	
	For Each TableRow In DocProductionInconsistencies Do
		If TableRow.DocumentRef = DocumentRef Then
			DifferencesTable = TableRow.DifferencesTable;
			Break;
		EndIf;	
	EndDo;
	
	FormParameters = New Structure("ReportKind, DocumentRef, DifferencesTable", "WriteOffsInconsistenciesToBillsOfMaterials", DocumentRef, DifferencesTable);
	
	OpenReportForm(FormParameters, True);

EndProcedure

// Procedure-handler of clicking the Refill and repost hyperlink in the section doc. Production - mismatch of writeoffs
// to BillsOfMaterials. Refills the Document inventory Production tabular section by BillsOfMaterials and reposts the document.
//
&AtServer
Procedure Attachable_CorrectMismatchDocProduction(CurArea, PredefineVariant, DataBeenChanged)
	
	PredefineVariant = 2;
	
	DataBeenChanged = True;
	
	CurrentRow = GetCurrRowFromAreaName(CurArea.Name);
	DocumentRef = ResultDocument.Area(CurrentRow + "C3:" + CurrentRow + "C4").Details;
	
	RowArray = DocProductionInconsistencies.FindRows(New Structure("DocumentRef", DocumentRef));
	
	If RowArray.Count() > 0 Then
		
		DocumentObject = DocumentRef.GetObject();
		
		NodesBillsOfMaterialstack = New Array;		
		DocumentObject.FillTabularSectionBySpecification(NodesBillsOfMaterialstack);
		
		Try
			DocumentObject.Write(DocumentWriteMode.Posting, DocumentPostingMode.Regular);
			WriteStoryObjectChanges(DocumentRef, "Posting", "Document posting.");
		Except
			Message = New UserMessage;
			Message.Text = "Unable to repost document " + String(DocumentRef) + Chars.LF + ErrorDescription();
			Message.SetData(Object);
			Message.Message(); 
			Return;
		EndTry;
		
		RowArray[0].DataProcessorExecuted = True;
		
		WriteExecutionDateBySection();
	
		OutputDataBySection();
		
	EndIf;

EndProcedure

// Procedure-handler of clicking the Alalysis result hyperlink of the Purchase prices analysis section. 
// 
&AtClient
Procedure OutputReportPricesAnalysisByProducts(CurArea, PredefineVariant, DataBeenChanged)
	
	PredefineVariant = 2;

	CurrentRow = GetCurrRowFromAreaName(CurArea.Name);
	ProductsRef = ResultDocument.Area(CurrentRow + "C3:" + CurrentRow + "C4").Details;
	
	AddressInStorage = GenerateReportDataTablePurchasePricesAnalysis(ProductsRef);
	
	If AddressInStorage <> "" Then		
		FormParameters = New Structure("ReportKind, AddressInStorage", "PurchasePricesAnalysis", AddressInStorage);		
		OpenReportForm(FormParameters, True);		
	EndIf;

EndProcedure

// Generate data table about purchase prices for specified products 
//
&AtServer
Function GenerateReportDataTablePurchasePricesAnalysis(ProductsRef)

	DataTable = New ValueTable;
	DataTable.Columns.Add("Products");
	DataTable.Columns.Add("Characteristic");
	DataTable.Columns.Add("PurchaseDocument");
	DataTable.Columns.Add("PurchasePrice");
	DataTable.Columns.Add("ThereIsDeviation");
	
	AddressInStorage = "";
	
	RowsProducts = PurchasePricesAnalysis.GetItems();
	
	For Each StringProducts In RowsProducts Do
		
		If StringProducts.Products = ProductsRef Then
			
			RowsDetailedRecords = StringProducts.GetItems();
			
			For Each RowDetailedRecord In RowsDetailedRecords Do
				
				NewRow = DataTable.Add();
				FillPropertyValues(NewRow, RowDetailedRecord);
			
			EndDo;
			
			Break;
			
		EndIf;
		
	EndDo;
	
	If DataTable.Count() > 0 Then
		AddressInStorage = PutToTempStorage(DataTable);
	EndIf;
	
	Return AddressInStorage;

EndFunction

// Procedure-handler of clicking the hyperlink of petty cash/r. account of the Exchange rate differences section.
//
&AtClient
Procedure OutputReportExchangeRatesDifferencesCash(CurArea, PredefineVariant, DataBeenChanged)
	
	PredefineVariant = 2;
	
	RowCellsRefs = StrReplace(GetCurrRowFromAreaName(CurArea.Name), "R", "");
	
	RowItemRef = ResultDocument.Area(RowCellsRefs, 1, RowCellsRefs, 1).Mask;

	AddressInStorage = GenerateTableReportDataCashExchangeRatesDifferences(RowItemRef);
	
	If AddressInStorage <> "" Then
		FormParameters = New Structure("ReportKind, AddressInStorage", "ExchangeDifferences", AddressInStorage);
		OpenReportForm(FormParameters, True);
	EndIf;

EndProcedure

// Generates the data table for report on exchange rates differences by cash assets.
//
&AtServer
Function GenerateTableReportDataCashExchangeRatesDifferences(RowItemRef = "")
	
	If RowItemRef = "" Then
		Return "";
	EndIf;

	DataTable = New ValueTable;
	DataTable.Columns.Add("ObjectAccounting");
	DataTable.Columns.Add("Recorder");
	DataTable.Columns.Add("Date");
	
	TextRef = Catalogs.BankAccounts.GetRef(New UUID(RowItemRef));
	
	If (TextRef.GetObject() = Undefined) Then
		TextRef = Catalogs.CashAccounts.GetRef(New UUID(RowItemRef));
	EndIf;
	
	For Each String_Level1 In IncorrectExchangeDifferencesDC.GetItems() Do
		
		If String_Level1.BankAccountPettyCash <> TextRef Then
		
			Continue;
		
		EndIf;
		
		For Each String_Level2 In String_Level1.GetItems() Do
			
			NewRow = DataTable.Add();
			NewRow.ObjectAccounting = String_Level2.BankAccountPettyCash;
			NewRow.Recorder = String_Level2.Recorder;
			NewRow.Date = String_Level2.Recorder.Date;
			
		EndDo; 
	
	EndDo;
	
	DataTable.Sort("Date");
	
	AddressInStorage = "";	
	
	If DataTable.Count() > 0 Then
		AddressInStorage = PutToTempStorage(DataTable);
	EndIf;
	
	Return AddressInStorage;

EndFunction

// Procedure-handler of clicking the hyperlink-counterparty of the Exchange rate differences section.
//
&AtClient
Procedure OutputExchangeRatesDifferencesReportCustomers(CurArea, PredefineVariant, DataBeenChanged)
	
	PredefineVariant = 2;
	
	RowCellsRefs = StrReplace(GetCurrRowFromAreaName(CurArea.Name), "R", "");
	
	RowItemRef = ResultDocument.Area(RowCellsRefs, 1, RowCellsRefs, 1).Mask;

	AddressInStorage = GenerateReportDataTableExchangeRatesDifferencesCustomers(RowItemRef);
	
	If AddressInStorage <> "" Then
		FormParameters = New Structure("ReportKind, AddressInStorage", "ExchangeDifferences", AddressInStorage);
		OpenReportForm(FormParameters, True);
	EndIf;	

EndProcedure

// Function generates the data table for exchange rates differences report by accounts receivable.
//
&AtServer
Function GenerateReportDataTableExchangeRatesDifferencesCustomers(RowItemRef = "")

	If RowItemRef = "" Then
		Return "";
	EndIf;

	DataTable = New ValueTable;
	DataTable.Columns.Add("ObjectAccounting");
	DataTable.Columns.Add("Recorder");
	DataTable.Columns.Add("Date");
	
	TextRef = Catalogs.Counterparties.GetRef(New UUID(RowItemRef));
		
	For Each String_Level1 In IncorrectExchangeDifferencesCustomers.GetItems() Do
		
		If String_Level1.Counterparty <> TextRef Then
		
			Continue;
		
		EndIf;
		
		For Each String_Level2 In String_Level1.GetItems() Do
			
			NewRow = DataTable.Add();
			NewRow.ObjectAccounting = String_Level2.Counterparty;
			NewRow.Recorder = String_Level2.Recorder;
			NewRow.Date = String_Level2.Recorder.Date;
			
		EndDo; 
	
	EndDo;
	
	DataTable.Sort("Date");
	
	AddressInStorage = "";	
	
	If DataTable.Count() > 0 Then
		AddressInStorage = PutToTempStorage(DataTable);
	EndIf;
	
	Return AddressInStorage;

EndFunction

// Procedure-handler of clicking the hyperlink-counterparty of the Exchange rate differences section.
//
&AtClient
Procedure OutputReportExchangeRatesDifferencesVendors(CurArea, PredefineVariant, DataBeenChanged)
	
	PredefineVariant = 2;
	
	RowCellsRefs = StrReplace(GetCurrRowFromAreaName(CurArea.Name), "R", "");
	
	RowItemRef = ResultDocument.Area(RowCellsRefs, 1, RowCellsRefs, 1).Mask;

	AddressInStorage = GenerateReportDataTableExchangeRatesDifferencesVendors(RowItemRef);
	
	If AddressInStorage <> "" Then
		FormParameters = New Structure("ReportKind, AddressInStorage", "ExchangeDifferences", AddressInStorage);	
		OpenReportForm(FormParameters, True);
	EndIf;	

EndProcedure

// Function generates the data table for exchange rates differences report by accounts payable.
//
&AtServer
Function GenerateReportDataTableExchangeRatesDifferencesVendors(RowItemRef)

	If RowItemRef = "" Then
		Return "";
	EndIf;

	DataTable = New ValueTable;
	DataTable.Columns.Add("ObjectAccounting");
	DataTable.Columns.Add("Recorder");
	DataTable.Columns.Add("Date");
	
	TextRef = Catalogs.Counterparties.GetRef(New UUID(RowItemRef));
		
	For Each String_Level1 In IncorrectExchangeDifferencesCustomers.GetItems() Do
		
		If String_Level1.Counterparty <> TextRef Then
		
			Continue;
		
		EndIf;
		
		For Each String_Level2 In String_Level1.GetItems() Do
			
			NewRow = DataTable.Add();
			NewRow.ObjectAccounting = String_Level2.Counterparty;
			NewRow.Recorder = String_Level2.Recorder;
			NewRow.Date = String_Level2.Recorder.Date;
			
		EndDo; 
	
	EndDo;
	
	DataTable.Sort("Date");
	
	AddressInStorage = "";	
	
	If DataTable.Count() > 0 Then
		AddressInStorage = PutToTempStorage(DataTable);
	EndIf;
	
	Return AddressInStorage;

EndFunction

// Procedure changes the attribute of the ImageIndex row depending on the data content by each section.
// 
&AtClient
Procedure SetTreeRowsPicture()

	CurrentTreeRow = Items.SectionTree.CurrentData;
	
	If CurrentTreeRow.Level = 0 Then
		Return;
	EndIf;
	
	If CurrentAccountingSection = "AccountsPayable" OR CurrentAccountingSection = "AccountsReceivable" Then
		
		FlagExecution = Undefined;
		TabSection = Undefined;
		
		DefineCheckBoxAndTabSectionBySection(FlagExecution, TabSection);
		
		If FlagExecution Then
			
			If TabSection.Count() = 0 Then
				
				CurrentTreeRow.PictureIndex = 3;
				
			Else
				
				HasProcessed = False;
				HasNotProcessed = False;
				
				DefineExecutionStateByCalculations(HasProcessed, HasNotProcessed);
				
				If HasProcessed AND HasNotProcessed Then//corrected something but not everything
					
					CurrentTreeRow.PictureIndex = 2;	
				
				ElsIf HasProcessed AND Not HasNotProcessed Then//fixed all
					
					CurrentTreeRow.PictureIndex = 4;
				
				ElsIf Not HasProcessed AND HasNotProcessed Then//corrected nothing
					
					CurrentTreeRow.PictureIndex = 1;
					
				ElsIf Not HasProcessed AND Not HasNotProcessed Then//no rows
					
					CurrentTreeRow.PictureIndex = 3;
					
				EndIf;
				
			EndIf;	
		
		Else
			
			CurrentTreeRow.PictureIndex = 0;
			
		EndIf;
		
	ElsIf CurrentAccountingSection = "ExchangeDifferences" Then
		
		NoCDErrors = ((IncorrectExchangeDifferencesDC.GetItems().Count() = 0) AND 
			(IncorrectExchangeDifferencesCustomers.GetItems().Count() = 0) AND 
			(IncorrectExchangeDifferencesCustomers.GetItems().Count() = 0));
		
		If ExchangeRatesDifferencesFilledWith Then
			
			If ExchangeDifferencesDocumentsPereprovedeny Then
				
				If NoCDErrors Then
					CurrentTreeRow.PictureIndex = 4;
				Else
					CurrentTreeRow.PictureIndex = 1;
				EndIf;
				
			Else
				
				If NoCDErrors Then
					CurrentTreeRow.PictureIndex = 3;
				Else
					CurrentTreeRow.PictureIndex = 1;
				EndIf;

			EndIf;		
		Else
			CurrentTreeRow.PictureIndex = 0;
		EndIf;
		
	ElsIf CurrentAccountingSection = "ProductsWithoutBillsOfMaterials" OR CurrentAccountingSection = "ReportsProcWithoutBillsOfMaterials" OR
		CurrentAccountingSection = "ReportsReprocWriteOffsMismatch" OR CurrentAccountingSection = "DocProductionWithoutBillsOfMaterials" OR
		CurrentAccountingSection = "DocProductionWriteoffsMismatch" Then
		
		FlagExecution = Undefined;
		TabSection = Undefined;
		
		DefineCheckBoxAndTabSectionBySection(FlagExecution, TabSection);
		
		If FlagExecution Then
			
			HasProcessed = False;
			HasNotProcessed = False;
			
			DefineExecutionStateByTabSection(HasProcessed, HasNotProcessed, TabSection);
			
			If HasProcessed AND HasNotProcessed Then//corrected something but not everything
				
				CurrentTreeRow.PictureIndex = 2;	
				
			ElsIf HasProcessed AND Not HasNotProcessed Then//fixed all
				
				CurrentTreeRow.PictureIndex = 4;
				
			ElsIf Not HasProcessed AND HasNotProcessed Then//corrected nothing
				
				CurrentTreeRow.PictureIndex = 1;
				
			ElsIf Not HasProcessed AND Not HasNotProcessed Then//no rows
				
				CurrentTreeRow.PictureIndex = 3;
				
			EndIf;
			
		Else
			CurrentTreeRow.PictureIndex = 0;
		EndIf;
		
	ElsIf CurrentAccountingSection = "PurchasePricesAnalysis" Then
		
		If PurchasePricesAnalysisFilledWith Then
			
			If PurchasePricesAnalysis.GetItems().Count() = 0 Then				
				CurrentTreeRow.PictureIndex = 3;
			Else
				CurrentTreeRow.PictureIndex = 1;				
			EndIf;
			
		Else
			CurrentTreeRow.PictureIndex = 0;
		EndIf;
		
	ElsIf CurrentAccountingSection = "CompaniesContractControl" Then
		
		If DocumentTreeFilledWithCompanyContract Then
			
			If DocumentsTreeCompanyContract.GetItems().Count() = 0 Then				
				CurrentTreeRow.PictureIndex = 3;
			Else
				CurrentTreeRow.PictureIndex = 1;				
			EndIf;
			
		Else
			CurrentTreeRow.PictureIndex = 0;
		EndIf;
		
	ElsIf CurrentAccountingSection = "CashFlowItems" Then
		
		If CashFlowItemsFilledWith Then
			
			If CashFlowItems.GetItems().Count() = 0 Then				
				CurrentTreeRow.PictureIndex = 3;
			Else
				CurrentTreeRow.PictureIndex = 1;				
			EndIf;
			
		Else
			CurrentTreeRow.PictureIndex = 0;
		EndIf;
		
	EndIf;

EndProcedure

// Procedure analyzes data state
// by the Accounts payable and Accounts receivable sections.
//
&AtServer
Procedure DefineExecutionStateByCalculations(HasProcessed, HasNotProcessed)
	
	TabSection = Undefined;
	
	If CurrentAccountingSection = "AccountsPayable" Then
		TabSection = AccountsPayable;
	ElsIf CurrentAccountingSection = "AccountsReceivable" Then
		TabSection = AccountsReceivable;
	EndIf;	
	
	
	For Each TabularSectionRow In TabSection Do
		
		If TabularSectionRow.DataProcessorExecuted Then
			HasProcessed = True;
		Else
			HasNotProcessed = True;	
		EndIf;
		
		If HasProcessed AND HasNotProcessed Then
			Break;
		EndIf;
		
	EndDo; 
	
EndProcedure

// The procedure puts ExecutionCheckBox, TabSection, a flag showing that the data has been filled and attribute-data
// source (ValuesTable, ValuesTree) to variables.
// 
&AtServer
Procedure DefineCheckBoxAndTabSectionBySection(FlagExecution, TabSection)

	If CurrentAccountingSection = "AccountsPayable" Then
		
		FlagExecution = AccountsPayableFilledWith;
		TabSection = AccountsPayable;
		
	ElsIf CurrentAccountingSection = "AccountsReceivable" Then
		
		FlagExecution = AccountsReceivableFilledWith;
		TabSection = AccountsReceivable;
		
	ElsIf CurrentAccountingSection = "ProductsWithoutBillsOfMaterials" Then
		
		FlagExecution = ProductsWithoutFilledWithBillsOfMaterials;
		TabSection = ProductsWithoutBillsOfMaterials;
		
	ElsIf CurrentAccountingSection = "ReportsProcWithoutBillsOfMaterials" Then
		
		FlagExecution = ReportsPereireWithoutFilledBillsOfMaterials;
		TabSection = SubcontractorBillsOfMaterialsReports;
		
	ElsIf CurrentAccountingSection = "ReportsReprocWriteOffsMismatch" Then
		
		FlagExecution = SubcontractorFilledWithInconsistenciesReports;
		TabSection = SubcontractorInconsistenciesReports;
		
	ElsIf CurrentAccountingSection = "DocProductionWithoutBillsOfMaterials" Then
		
		FlagExecution = DocFilledWithProductionBillsOfMaterials;
		TabSection = DocProductionBillsOfMaterials;
		
	ElsIf CurrentAccountingSection = "DocProductionWriteoffsMismatch" Then
		
		FlagExecution = DocFilledWithProductionInconsistencies;
		TabSection = DocProductionInconsistencies;
	
	EndIf;	

EndProcedure

// Procedure analyzes data state by a passed attribute-data source
//
&AtServer
Procedure DefineExecutionStateByTabSection(HasProcessed, HasNotProcessed, TabSection)
	
	For Each TabularSectionRow In TabSection Do
		
		If TabularSectionRow.DataProcessorExecuted Then
			HasProcessed = True;
		Else
			HasNotProcessed = True;	
		EndIf;
		
		If HasProcessed AND HasNotProcessed Then
			Break;
		EndIf;
		
	EndDo;	
	
EndProcedure

// Function generates document presentation from reference.
//
&AtServerNoContext
Function GenerateDocumentPresentation(DocumentRef)

	DocumentPresentation = DocumentRef.Metadata().Synonym;
	
	DocumentNumber = ObjectPrefixationClientServer.GetNumberForPrinting(DocumentRef.Number);
		
	DocumentPresentation = DocumentPresentation + " # "
												+ DocumentNumber
												+ " from "
												+ Format(DocumentRef.Date, "DLF=DD");
												
	Return DocumentPresentation;

EndFunction

// Function returns a row number of a tabular from the highlighted area name.
//
&AtServerNoContext
Function GetCurrRowFromAreaName(AreaName)

	RowName = "";
	
	For Ct = 1 To StrLen(AreaName) Do
		
		CurSymbol = Mid(AreaName, Ct, 1);
	
		If CurSymbol <> "C" Then
			RowName = RowName + CurSymbol;
		Else
			Break;
		EndIf;
		
	EndDo;
	
	Return RowName;

EndFunction

// Processor of rows-sections subordinate to the Products without BillsOfMaterials section.
// Called during data modification by the section specified above
//
&AtClient
Procedure ChangeSubordinateProductsWithoutBillsOfMaterials()
	
	CurrentTreeRow = Items.SectionTree.CurrentData;
	
	Rows_Level1 = CurrentTreeRow.GetItems();
	
	For Each String_Level1 In Rows_Level1 Do
	
		String_Level1.AnalysisExecuted = False;
		
		String_Level1.PictureIndex = 0; 
		
		Rows_Level2 = String_Level1.GetItems();
		
		For Each String_Level2 In Rows_Level2 Do
			String_Level2.AnalysisExecuted = False;
			String_Level2.ParentOutputSection = False;
			String_Level2.PictureIndex = 0;
		EndDo; 
		
	EndDo; 

	If ReportsPereireWithoutFilledBillsOfMaterials Then
		
		SubcontractorBillsOfMaterialsReports.Clear();
		ReportsPereireWithoutFilledBillsOfMaterials = False;
		
		If SubcontractorFilledWithInconsistenciesReports Then
			SubcontractorInconsistenciesReports.Clear();
			SubcontractorFilledWithInconsistenciesReports = False;
		EndIf;
		
	EndIf;
	
	If DocFilledWithProductionBillsOfMaterials Then
	
		DocProductionBillsOfMaterials.Clear();
		DocFilledWithProductionBillsOfMaterials = False;
		
		If DocFilledWithProductionInconsistencies Then
		
			DocProductionInconsistencies.Clear();
			DocFilledWithProductionInconsistencies = False;
		
		EndIf;
	
	EndIf;

EndProcedure

// Processing rows-sections subordinate to the Subcontractors reports without BillsOfMaterials section.
// Called during data modification by the section specified above
//
&AtClient
Procedure ChangeSubordinateReportsProcWithoutBillsOfMaterials()
	
	CurrentTreeRow = Items.SectionTree.CurrentData;
	
	Rows_Level2 = CurrentTreeRow.GetItems();
	
	For Each String_Level2 In Rows_Level2 Do
		String_Level2.AnalysisExecuted = False;
		String_Level2.PictureIndex = 0;
	EndDo;
	
	If SubcontractorFilledWithInconsistenciesReports Then
		SubcontractorInconsistenciesReports.Clear();
		SubcontractorFilledWithInconsistenciesReports = False;
	EndIf;

EndProcedure

// Processing rows-sections subordinate to the Production documents without BillsOfMaterials section.
// Called during data modification by the section specified above
//
&AtClient
Procedure ChangeSubordinateDocProductionWithoutBillsOfMaterials()
	
	CurrentTreeRow = Items.SectionTree.CurrentData;
	
	Rows_Level2 = CurrentTreeRow.GetItems();
	
	For Each String_Level2 In Rows_Level2 Do
		String_Level2.AnalysisExecuted = False;
		String_Level2.PictureIndex = 0;
	EndDo;
	
	If DocFilledWithProductionInconsistencies Then
		DocProductionInconsistencies.Clear();
		DocFilledWithProductionInconsistencies = False;
	EndIf;

EndProcedure

// Procedure saves a date and an event of
// changing (write, post) of the specified object of the infobase
//
&AtServer
Procedure WriteStoryObjectChanges(ObjectRef, Event, Comment)
	
	ErrorMessage = NStr("en = 'Control accounting correctness'", CommonUseClientServer.MainLanguageCode());
	WriteLogEvent(ErrorMessage + "." + Event, EventLogLevel.Information, ,ObjectRef, Comment);
	
EndProcedure

// Procedure inverts the visible of the cells area of a tabular document.
// The Mask field of the passed area should contain name of the
// area, i.e. area that was clicked.
//
&AtServer
Procedure Attachable_ChangeVisibleCellsArea(CurArea, PredefineVariant, DataBeenChanged)

	PredefineVariant = 2;
	
	If CurArea.Mask <> "" Then
		ResultDocument.Area(CurArea.Mask).Visible = (NOT ResultDocument.Area(CurArea.Mask).Visible);
	EndIf;
	
EndProcedure

// Procedure opens a new window of the ReportForm form
//
&AtClient
Procedure OpenReportForm(FormParameters, ProcessTranscriptions = False)

	FormKey = "ControlAccountingCorrectness_ReportForm";
	
	FormParameters.Insert("ProcessTranscriptions", ProcessTranscriptions);
	
	ReportForm = GetForm("DataProcessor.AccountingCorrectnessControl.Form.ReportForm", FormParameters, ThisForm, FormKey);
	
	If ReportForm.IsOpen() Then
		ReportForm.Close();
		ReportForm = Undefined;
		ReportForm = GetForm("DataProcessor.AccountingCorrectnessControl.Form.ReportForm", FormParameters, ThisForm, FormKey);
	EndIf;
	
	OpenForm(ReportForm);

EndProcedure

// Procedure-handler of clicking the Open the Cash flow items catalog hyperlink of the Cash flow items section.
//
&AtClient
Procedure OpenCatalogCashFlowItems(CurArea, PredefineVariant, DataBeenChanged)

	PredefineVariant = 2;
	
	OpenForm("Catalog.CashFlowItems.ListForm");	

EndProcedure

// Procedure-handler of clicking the hyperlink of the cash flow item to generate a report by the specific item.
//
&AtClient
Procedure OutputReportCashFlowItem(CurArea, PredefineVariant, DataBeenChanged)
	
	PredefineVariant = 2; 
	
	RowCellsRefs = StrReplace(GetCurrRowFromAreaName(CurArea.Name), "R", "");	

	AddressInStorage = GenerateTableReportDataCashFlowItems(RowCellsRefs);
	
	If AddressInStorage <> "" Then
		FormParameters = New Structure("ReportKind, AddressInStorage", "CashFlowItems", AddressInStorage);
		OpenReportForm(FormParameters, True);
	EndIf;

EndProcedure

// Function generates a data table for the report on movements by a specified cash flow item.
//
&AtServer
Function GenerateTableReportDataCashFlowItems(RowCellsRefs = "")
	
	If RowCellsRefs = "" Then
		Return "";
	EndIf;
	
	RowItemRef = ResultDocument.Area(RowCellsRefs, 1, RowCellsRefs, 1).Mask;
	
	If RowItemRef = "" Then
		Return "";
	EndIf;
	
	DataTable = New ValueTable;
	DataTable.Columns.Add("Item");
	DataTable.Columns.Add("Recorder");
	DataTable.Columns.Add("AmountReceipt");
	DataTable.Columns.Add("AmountExpense");
	DataTable.Columns.Add("Currency");
	
	CurrItem = Catalogs.CashFlowItems.GetRef(New UUID(RowItemRef));
	
	For Each String_Level1 In CashFlowItems.GetItems() Do
	
		For Each String_Level2 In String_Level1.GetItems() Do
		
			If String_Level2.Item = CurrItem Then
				
				For Each String_Level3 In String_Level2.GetItems() Do //Currency
					
					For Each String_Level4 In String_Level3.GetItems() Do //Recorder
						
						NewRow = DataTable.Add();
						FillPropertyValues(NewRow, String_Level4);
						
					EndDo;	
					
				EndDo; 
				
			EndIf;
			
		EndDo; 	
		
	EndDo; 

	AddressInStorage = "";	
	
	If DataTable.Count() > 0 Then
		AddressInStorage = PutToTempStorage(DataTable);
	EndIf;
	
	Return AddressInStorage;	

EndFunction

&AtServer
Procedure ChangePeriod(MonthQuantity)

	BeginOfPeriod = AddMonth(BeginOfPeriod, MonthQuantity);
	EndOfPeriod = EndOfMonth(BeginOfPeriod);
	
	SetPeriodPresentation();

EndProcedure

&AtClient
Procedure ExecuteProcedureOnWebClient(ProcedureCallText, CurArea, PredefineVariant, DataBeenChanged)

	If ProcedureCallText = "UpdateData(PredefineVariant, DataBeenChanged)" Then
	
		ExecuteDataRefreshing(PredefineVariant, DataBeenChanged);
		
	ElsIf ProcedureCallText = "TransferToNextSection(CurArea, PredefineVariant, DataBeenChanged)" Then
		
		GoToNextSection(PredefineVariant, DataBeenChanged);
		
	ElsIf ProcedureCallText = "OutputReportOnSettlements(CurArea, PredefineVariant, DataBeenChanged)" Then
		
		OutputReportBySettlements(CurArea, PredefineVariant, DataBeenChanged);
		
	ElsIf ProcedureCallText = "OutputReportExchangeRatesDifferencesCash(CurArea, PredefineVariant, DataBeenChanged)" Then
		
		OutputReportExchangeRatesDifferencesCash(CurArea, PredefineVariant, DataBeenChanged);
		
	ElsIf ProcedureCallText = "GenerateReportDataTableExchangeRatesDifferencesCustomers(CurArea, PredefineVariant, DataBeenChanged)" Then
		
		OutputExchangeRatesDifferencesReportCustomers(CurArea, PredefineVariant, DataBeenChanged);
		
	ElsIf ProcedureCallText = "OutputReportExchangeRatesDifferencesVendors(CurArea, PredefineVariant, DataBeenChanged)" Then
		
		OutputReportExchangeRatesDifferencesVendors(CurArea, PredefineVariant, DataBeenChanged);
		
	ElsIf ProcedureCallText = "OutputBillsOfMaterialsList(CurArea, PredefineVariant, DataBeenChanged)" Then
		
		OpenBillsOfMaterialsList(CurArea, PredefineVariant, DataBeenChanged);
		
	ElsIf ProcedureCallText = "SelectSetDefaultSpecification (CurArea, PredefineVariant, DataBeenChanged)" Then
		
		SelectSetDefaultSpecification(CurArea, PredefineVariant, DataBeenChanged);
		
	ElsIf ProcedureCallText = "OutputReportOnMismatchReportReproc(CurArea, PredefineVariant, DataBeenChanged)" Then
		
		OutputReportByMismatchProcReport(CurArea, PredefineVariant, DataBeenChanged);
		
	ElsIf ProcedureCallText = "OutputReportDocProductionBillsOfMaterials(CurArea, PredefineVariant, DataBeenChanged)" Then
		
		OutputReportDocProductionBillsOfMaterials(CurArea, PredefineVariant, DataBeenChanged);
		
	ElsIf ProcedureCallText = "OutputReportOnMismatchDocProduction(CurArea, PredefineVariant, DataBeenChanged)" Then
		
		OutputReportByMismatchesDocProduction(CurArea, PredefineVariant, DataBeenChanged);
		
	ElsIf ProcedureCallText = "OutputReportPricesAnalysisByProducts(CurArea, PredefineVariant, DataBeenChanged)" Then
		
		OutputReportPricesAnalysisByProducts(CurArea, PredefineVariant, DataBeenChanged);
		
	ElsIf ProcedureCallText = "OpenCatalogCashFlowItems(CurArea, PredefineVariant, DataBeenChanged)" Then
		
		OpenCatalogCashFlowItems(CurArea, PredefineVariant, DataBeenChanged);
		
	ElsIf ProcedureCallText = "OutputReportCashFlowItem(CurArea, PredefineVariant, DataBeenChanged)" Then
		
		OutputReportCashFlowItem(CurArea, PredefineVariant, DataBeenChanged);
		
	ElsIf ProcedureCallText = "OutputDetailedDescription(PredefineVariant, DataBeenChanged)" Then 
		
		OutputDetailedDescription(PredefineVariant, DataBeenChanged);
		
	Else
		
		Raise ProcedureCallText + " - handler is not defined for a web client";
	
	EndIf;	

EndProcedure

#EndRegion
