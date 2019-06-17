#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

Procedure Posting(Parameters, StorageAddress = "") Export
	
	SetPrivilegedMode(True);
	
	WriteLogEvent(
		NStr("en = 'FIFO.Posting documents'", CommonUseClientServer.MainLanguageCode()),
		EventLogLevel.Information,
		,
		NStr("en = 'Start posting documents'"),
		EventLogEntryTransactionMode.Transactional);
		
	SourceRegisters = New Array;
	SourceRegisters.Add(Metadata.AccumulationRegisters.Inventory);
	SourceRegisters.Add(Metadata.AccumulationRegisters.LandedCosts);
	
	DocumentsForPosting = New Array();
	// Inventory
	DocumentsForPosting.Add(Metadata.Documents.ExpenseReport);
	DocumentsForPosting.Add(Metadata.Documents.InventoryIncrease);
	DocumentsForPosting.Add(Metadata.Documents.OpeningBalanceEntry);
	DocumentsForPosting.Add(Metadata.Documents.SupplierInvoice);
	// Landed costs
	DocumentsForPosting.Add(Metadata.Documents.AdditionalExpenses);
	DocumentsForPosting.Add(Metadata.Documents.CustomsDeclaration);
	
	DocumentsPeriod = DocumentsPeriod(SourceRegisters);
	
	If DocumentsPeriod.BeginPeriod = Undefined Then
		Parameters.Insert("LoadingIsCompleted", False);
		Parameters.Insert("MessageText", NStr("en = 'There are no documents for posting'"));
	Else
		CurrentMonth = DocumentsPeriod.BeginPeriod;
		If ValueIsFilled(DocumentsPeriod.EndPeriod) Then
			While CurrentMonth < DocumentsPeriod.EndPeriod Do
				
				EndOfCurrentMonth = EndOfMonth(CurrentMonth);
				
				PostDocuments(DocumentsForPosting, CurrentMonth, EndOfCurrentMonth);
				
				CurrentMonth = AddMonth(CurrentMonth, 1);
				
			EndDo;
		EndIf;
		Parameters.Insert("LoadingIsCompleted", True);
	EndIf;
	
	If ValueIsFilled(StorageAddress) Then
		PutToTempStorage(Parameters, StorageAddress);
	EndIf;
EndProcedure
	
#EndRegion

#Region Private

Function DocumentsPeriod(SourceRegisters)
	
	QueryTextTemplate = "
	|SELECT
	|	MIN(Table.Period) AS BeginPeriod,
	|	MAX(Table.Period) AS EndPeriod
	|FROM
	|	&RegisterName AS Table";
	
	Query = New Query;
	DocumentsPeriod = New Structure("BeginPeriod, EndPeriod", Undefined, Undefined);
	
	For Each SourceRegister In SourceRegisters Do
		
		Query.Text = StrReplace(QueryTextTemplate, "&RegisterName", "AccumulationRegister." + SourceRegister.Name);
		Selection = Query.Execute().Select();
		Selection.Next();
		
		If DocumentsPeriod.BeginPeriod = Undefined Then
			FillPropertyValues(DocumentsPeriod, Selection);
		Else
			If ValueIsFilled(Selection.BeginPeriod)
				And Selection.BeginPeriod < DocumentsPeriod.BeginPeriod Then
				DocumentsPeriod.BeginPeriod = BegOfMonth(Selection.BeginPeriod);
			EndIf;
			If ValueIsFilled(Selection.EndPeriod)
				And Selection.EndPeriod > DocumentsPeriod.EndPeriod Then
				DocumentsPeriod.EndPeriod = EndOfMonth(Selection.EndPeriod) + 1;
			EndIf;
		EndIf;
	EndDo;
	
	Return DocumentsPeriod;
EndFunction

Procedure PostDocuments(Documents, BeginOfMonth, EndOfMonth)
	
	QueryTextTemplate = "
	|SELECT
	|	Doc.Ref AS Ref,
	|	Doc.Date AS Data,
	|	Doc.Company AS Company
	|FROM
	|	&DocumentName AS Doc
	|WHERE
	|	Doc.Date BETWEEN &BegOfPeriod AND &EndOfPeriod
	|	AND Doc.Posted";
	
	Query = New Query;
	Query.SetParameter("BegOfPeriod", BeginOfMonth);
	Query.SetParameter("EndOfPeriod", EndOfMonth);
	
	Companies = New Array;
	CostLayerRegisters = CostLayerRegisters();
	
	For Each Document In Documents Do
		
		Query.Text = StrReplace(QueryTextTemplate, "&DocumentName", "Document." + Document.Name);
		Selection = Query.Execute().Select();
		
		While Selection.Next() Do
			Companies.Add(Selection.Company);
			WriteRecordsToRegister(Selection.Ref, CostLayerRegisters);
		EndDo;
		
	EndDo;
	
	Query.Text = 
	"SELECT
	|	Task.Month AS Month,
	|	Task.TaskNumber AS TaskNumber,
	|	Task.Company AS Company,
	|	Task.Document AS Document
	|INTO TempTasks
	|FROM
	|	InformationRegister.TasksForCostsCalculation AS Task
	|
	|UNION ALL
	|
	|SELECT
	|	&CurrentMonth,
	|	1,
	|	Companies.Ref,
	|	UNDEFINED
	|FROM
	|	Catalog.Companies AS Companies
	|WHERE
	|	Companies.Ref IN(&ArrayOfCompanies)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Task.Month AS Month,
	|	MIN(Task.TaskNumber) AS TaskNumber,
	|	Task.Company AS Company,
	|	Task.Document AS Document
	|FROM
	|	TempTasks AS Task
	|
	|GROUP BY
	|	Task.Month,
	|	Task.Company,
	|	Task.Document";
	
	Query.SetParameter("ArrayOfCompanies", Companies);
	Query.SetParameter("CurrentMonth", BeginOfMonth);
	Result = Query.Execute();
	
	Records = InformationRegisters.TasksForCostsCalculation.CreateRecordSet();
	Records.Load(Result.Unload());
	Records.Write();
	
EndProcedure

Function CostLayerRegisters()
	
	CostLayerRegisters = New Structure;
	CostLayerRegisters.Insert("TableInventoryCostLayer", AccumulationRegisters.InventoryCostLayer);
	CostLayerRegisters.Insert("TableLandedCosts", AccumulationRegisters.LandedCosts);
	CostLayerRegisters.Insert("TableInventory", AccumulationRegisters.Inventory);
	CostLayerRegisters.Insert("TableSales", AccumulationRegisters.Sales);
	CostLayerRegisters.Insert("TableAccountingJournalEntries", AccountingRegisters.AccountingJournalEntries);
	
	Return CostLayerRegisters;
EndFunction

Procedure WriteRecordsToRegister(Ref, RegistersForPosting)
	
	Var Table;
	
	BeginTransaction();
	
	AdditionalProperties = New Structure("IsNew, WriteMode", True, DocumentWriteMode.Posting);
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	Documents[AdditionalProperties.ForPosting.DocumentMetadata.Name].InitializeDocumentData(Ref, AdditionalProperties);
	Tables = AdditionalProperties.TableForRegisterRecords;
	
	For Each Register In RegistersForPosting Do
		If Tables.Property(Register.Key, Table) Then
			WriteRecords(Register.Value, Table, Ref);
		EndIf;
	EndDo;
	
	CommitTransaction();
	
EndProcedure

Procedure WriteRecords(RegisterManager, Table, Ref)
	
	Records = RegisterManager.CreateRecordSet();
	Records.Filter.Recorder.Set(Ref);
	Records.Read();
	
	If Records.Count() > 0 Or Table.Count() > 0 Then
		Records.Load(Table);
		Records.Write(True);
	EndIf;
	
EndProcedure

#EndRegion

#EndIf
