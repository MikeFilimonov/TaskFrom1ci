#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ProgramInterface

// Procedure creates an empty temporary table of records change.
//
Procedure CreateEmptyTemporaryTableChange(AdditionalProperties) Export
	
	If Not AdditionalProperties.Property("ForPosting")
		OR Not AdditionalProperties.ForPosting.Property("StructureTemporaryTables") Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	Query = New Query(
	"SELECT TOP 0
	|	VATIncurred.LineNumber AS LineNumber,
	|	VATIncurred.Company AS Company,
	|	VATIncurred.Supplier AS Supplier,
	|	VATIncurred.ShipmentDocument AS ShipmentDocument,
	|	VATIncurred.VATRate AS VATRate,
	|	VATIncurred.AmountExcludesVAT AS AmountExcludesVATBeforeWrite,
	|	VATIncurred.AmountExcludesVAT AS AmountExcludesVATChange,
	|	VATIncurred.AmountExcludesVAT AS AmountExcludesVATOnWrite,
	|	VATIncurred.VATAmount AS VATAmountBeforeWrite,
	|	VATIncurred.VATAmount AS VATAmountChange,
	|	VATIncurred.VATAmount AS VATAmountOnWrite
	|INTO RegisterRecordsVATIncurredChange
	|FROM
	|	AccumulationRegister.VATIncurred AS VATIncurred");
	
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	QueryResult = Query.Execute();
	
	StructureTemporaryTables.Insert("RegisterRecordsVATIncurredChange", False);
	
EndProcedure

Function BalancesControlQueryText() Export
	
	Return
	"SELECT
	|	RegisterRecordsVATIncurredChange.LineNumber AS LineNumber,
	|	RegisterRecordsVATIncurredChange.Company AS Company,
	|	RegisterRecordsVATIncurredChange.Supplier AS Supplier,
	|	RegisterRecordsVATIncurredChange.ShipmentDocument AS ShipmentDocument,
	|	RegisterRecordsVATIncurredChange.VATRate AS VATRate,
	|	RegisterRecordsVATIncurredChange.AmountExcludesVATOnWrite AS AmountExcludesVAT,
	|	ISNULL(VATIncurredBalances.AmountExcludesVATBalance, 0) AS AmountExcludesVATBalance,
	|	RegisterRecordsVATIncurredChange.VATAmountOnWrite AS VATAmount,
	|	ISNULL(VATIncurredBalances.VATAmountBalance, 0) AS VATAmountBalance
	|INTO TT_RegisterRecordsVATIncurredChange
	|FROM
	|	RegisterRecordsVATIncurredChange AS RegisterRecordsVATIncurredChange
	|		LEFT JOIN AccumulationRegister.VATIncurred.Balance(&ControlTime, ) AS VATIncurredBalances
	|		ON RegisterRecordsVATIncurredChange.Company = VATIncurredBalances.Company
	|			AND RegisterRecordsVATIncurredChange.Supplier = VATIncurredBalances.Supplier
	|			AND RegisterRecordsVATIncurredChange.ShipmentDocument = VATIncurredBalances.ShipmentDocument
	|			AND RegisterRecordsVATIncurredChange.VATRate = VATIncurredBalances.VATRate
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	RegisterRecordsVATIncurredChange.LineNumber AS LineNumber,
	|	RegisterRecordsVATIncurredChange.Company AS Company,
	|	RegisterRecordsVATIncurredChange.Supplier AS Supplier,
	|	RegisterRecordsVATIncurredChange.ShipmentDocument AS ShipmentDocument,
	|	RegisterRecordsVATIncurredChange.VATRate AS VATRate,
	|	RegisterRecordsVATIncurredChange.AmountExcludesVAT AS AmountExcludesVAT,
	|	RegisterRecordsVATIncurredChange.AmountExcludesVATBalance AS AmountExcludesVATBalance,
	|	RegisterRecordsVATIncurredChange.VATAmount AS VATAmount,
	|	RegisterRecordsVATIncurredChange.VATAmountBalance AS VATAmountBalance
	|FROM
	|	TT_RegisterRecordsVATIncurredChange AS RegisterRecordsVATIncurredChange
	|WHERE
	|	NOT RegisterRecordsVATIncurredChange.ShipmentDocument REFS Document.DebitNote
	|	AND (RegisterRecordsVATIncurredChange.AmountExcludesVATBalance < 0
	|			OR RegisterRecordsVATIncurredChange.VATAmountBalance < 0)
	|
	|UNION ALL
	|
	|SELECT
	|	RegisterRecordsVATIncurredChange.LineNumber,
	|	RegisterRecordsVATIncurredChange.Company,
	|	RegisterRecordsVATIncurredChange.Supplier,
	|	RegisterRecordsVATIncurredChange.ShipmentDocument,
	|	RegisterRecordsVATIncurredChange.VATRate,
	|	RegisterRecordsVATIncurredChange.AmountExcludesVAT,
	|	-RegisterRecordsVATIncurredChange.AmountExcludesVATBalance,
	|	RegisterRecordsVATIncurredChange.VATAmount,
	|	-RegisterRecordsVATIncurredChange.VATAmountBalance
	|FROM
	|	TT_RegisterRecordsVATIncurredChange AS RegisterRecordsVATIncurredChange
	|WHERE
	|	RegisterRecordsVATIncurredChange.ShipmentDocument REFS Document.DebitNote
	|	AND (RegisterRecordsVATIncurredChange.AmountExcludesVATBalance > 0
	|			OR RegisterRecordsVATIncurredChange.VATAmountBalance > 0)
	|
	|ORDER BY
	|	LineNumber";
	
EndFunction

#EndRegion

#Region InfobaseUpdate

Procedure ProcessDataToUpgradeToNewVersion() Export
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	DebitNote.Ref AS Ref,
	|	AccountingPolicy.PostVATEntriesBySourceDocuments AS PostVATEntriesBySourceDocuments,
	|	AccountingPolicy.Period AS Period
	|INTO TT_DebitNotesAllAP
	|FROM
	|	Document.DebitNote AS DebitNote
	|		INNER JOIN InformationRegister.AccountingPolicy AS AccountingPolicy
	|		ON DebitNote.Company = AccountingPolicy.Company
	|			AND DebitNote.Date >= AccountingPolicy.Period
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_DebitNotesAllAP.Ref AS Ref,
	|	MAX(TT_DebitNotesAllAP.Period) AS Period
	|INTO TT_DebitNotesLatestAP
	|FROM
	|	TT_DebitNotesAllAP AS TT_DebitNotesAllAP
	|
	|GROUP BY
	|	TT_DebitNotesAllAP.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_DebitNotesLatestAP.Ref AS Ref
	|FROM
	|	TT_DebitNotesLatestAP AS TT_DebitNotesLatestAP
	|		INNER JOIN TT_DebitNotesAllAP AS TT_DebitNotesAllAP
	|		ON TT_DebitNotesLatestAP.Ref = TT_DebitNotesAllAP.Ref
	|			AND TT_DebitNotesLatestAP.Period = TT_DebitNotesAllAP.Period
	|		LEFT JOIN AccumulationRegister.VATIncurred AS VATIncurred
	|		ON TT_DebitNotesLatestAP.Ref = VATIncurred.Recorder
	|			AND (VATIncurred.LineNumber = 1)
	|WHERE
	|	NOT TT_DebitNotesAllAP.PostVATEntriesBySourceDocuments
	|	AND VATIncurred.Recorder IS NULL
	|
	|UNION ALL
	|
	|SELECT DISTINCT
	|	TaxInvoiceReceived.Ref
	|FROM
	|	Document.TaxInvoiceReceived AS TaxInvoiceReceived
	|		INNER JOIN Document.TaxInvoiceReceived.BasisDocuments AS TaxInvoiceReceivedBasisDocuments
	|		ON TaxInvoiceReceived.Ref = TaxInvoiceReceivedBasisDocuments.Ref
	|			AND (TaxInvoiceReceivedBasisDocuments.BasisDocument REFS Document.DebitNote)
	|		LEFT JOIN AccumulationRegister.VATIncurred AS VATIncurred
	|		ON TaxInvoiceReceived.Ref = VATIncurred.Recorder
	|			AND (VATIncurred.ShipmentDocument REFS Document.DebitNote)
	|WHERE
	|	TaxInvoiceReceived.Posted
	|	AND VATIncurred.Recorder IS NULL";
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		BeginTransaction();
		
		DocObject = Selection.Ref.GetObject();
		
		DriveServer.InitializeAdditionalPropertiesForPosting(DocObject.Ref, DocObject.AdditionalProperties);
		
		Documents[DocObject.Metadata().Name].InitializeDocumentData(DocObject.Ref, DocObject.AdditionalProperties);
		
		If DocObject.AdditionalProperties.TableForRegisterRecords.Property("TableVATIncurred")
			And DocObject.AdditionalProperties.TableForRegisterRecords.TableVATIncurred.Count() Then
			
			DriveServer.ReflectVATIncurred(DocObject.AdditionalProperties, DocObject.RegisterRecords, False);
			
		Else
			
			DocObject.RegisterRecords.VATIncurred.Clear();
			DocObject.RegisterRecords.VATIncurred.Write = True;
			
		EndIf;
		
		DriveServer.WriteRecordSets(DocObject.ThisObject);
		
		DocObject.AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
		
		CommitTransaction();
		
	EndDo;
	
EndProcedure

#EndRegion

#EndIf