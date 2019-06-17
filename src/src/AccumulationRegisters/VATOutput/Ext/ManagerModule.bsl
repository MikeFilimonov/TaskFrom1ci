#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region InfobaseUpdate

Procedure ProcessDataToUpgradeToNewVersion() Export
	
	Query = New Query;
	Query.Text = 
	"SELECT DISTINCT
	|	VATOutput.Recorder AS Recorder
	|FROM
	|	AccumulationRegister.VATOutput AS VATOutput
	|WHERE
	|	VATOutput.OperationType = VALUE(Enum.VATOperationTypes.EmptyRef)";
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		DocType = TypeOf(Selection.Recorder);
		If DocType = Type("DocumentRef.RegistersCorrection") Then
			Continue;
		EndIf;
		
		BeginTransaction();
		
		DocObject = Selection.Recorder.GetObject();
		
		DriveServer.InitializeAdditionalPropertiesForPosting(DocObject.Ref, DocObject.AdditionalProperties);
		
		If DocType = Type("DocumentRef.ShiftClosure") Then
			DocObject.AdditionalProperties.ForPosting.Insert("CompletePosting", False);
		EndIf;
		
		Documents[DocObject.Metadata().Name].InitializeDocumentData(DocObject.Ref, DocObject.AdditionalProperties);
		
		If DocObject.AdditionalProperties.TableForRegisterRecords.Property("TableVATOutput")
			And DocObject.AdditionalProperties.TableForRegisterRecords.TableVATOutput.Count() Then
			
			DriveServer.ReflectVATOutput(DocObject.AdditionalProperties, DocObject.RegisterRecords, False);
			
		Else
			
			DocObject.RegisterRecords.VATOutput.Clear();
			DocObject.RegisterRecords.VATOutput.Write = True;
			
		EndIf;
		
		DriveServer.WriteRecordSets(DocObject.ThisObject);
		
		DocObject.AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
		
		CommitTransaction();
		
	EndDo;
	
EndProcedure

#EndRegion

#EndIf