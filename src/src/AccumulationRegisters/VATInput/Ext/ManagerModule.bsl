#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region InfobaseUpdate

Procedure ProcessDataToUpgradeToNewVersion() Export
	
	Query = New Query;
	Query.Text = 
	"SELECT DISTINCT
	|	VATInput.Recorder AS Recorder
	|FROM
	|	AccumulationRegister.VATInput AS VATInput
	|WHERE
	|	VATInput.OperationType = VALUE(Enum.VATOperationTypes.EmptyRef)
	|
	|UNION ALL
	|
	|SELECT
	|	TaxInvoiceReceived.Ref
	|FROM
	|	Document.TaxInvoiceReceived AS TaxInvoiceReceived
	|		LEFT JOIN AccumulationRegister.VATInput AS VATInput
	|		ON TaxInvoiceReceived.Ref = VATInput.Recorder
	|			AND (VATInput.LineNumber = 1)
	|WHERE
	|	TaxInvoiceReceived.Posted
	|	AND VATInput.Recorder IS NULL";
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		DocType = TypeOf(Selection.Recorder);
		If DocType = Type("DocumentRef.RegistersCorrection") Then
			Continue;
		EndIf;
		
		BeginTransaction();
		
		DocObject = Selection.Recorder.GetObject();
		
		DriveServer.InitializeAdditionalPropertiesForPosting(DocObject.Ref, DocObject.AdditionalProperties);
		
		Documents[DocObject.Metadata().Name].InitializeDocumentData(DocObject.Ref, DocObject.AdditionalProperties);
		
		If DocObject.AdditionalProperties.TableForRegisterRecords.Property("TableVATInput")
			And DocObject.AdditionalProperties.TableForRegisterRecords.TableVATInput.Count() Then
			
			DriveServer.ReflectVATInput(DocObject.AdditionalProperties, DocObject.RegisterRecords, False);
			
		Else
			
			DocObject.RegisterRecords.VATInput.Clear();
			DocObject.RegisterRecords.VATInput.Write = True;
			
		EndIf;
		
		DriveServer.WriteRecordSets(DocObject.ThisObject);
		
		DocObject.AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
		
		CommitTransaction();
		
	EndDo;
	
EndProcedure

#EndRegion

#EndIf