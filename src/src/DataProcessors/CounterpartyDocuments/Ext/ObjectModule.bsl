#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ProgramInterface

// Procedure generates the queries table.
//
Procedure FillQueryTable(RequestsTable, AddHeaderFields, ActualOnly = False, NameSelectionCriterias = "CounterpartyDocuments") Export

	DocumentsTree = New ValueTree;
	DocumentsTree.Columns.Add("Document");
	DocumentsTree.Columns.Add("DataStructure");
	DocumentsTree.Columns.Add("TabularSection");
	DocumentsTree.Columns.Add("ConditionText");

	For Each ContentItem In Metadata.FilterCriteria[NameSelectionCriterias].Content Do

		DataStructure = GetDataStructure(ContentItem.FullName());

		If Not AccessRight("Read", DataStructure.Metadata) Then
			Continue;
		EndIf;

		RootDocument = DocumentsTree.Rows.Find(DataStructure.Metadata, "Document", False);
		If RootDocument = Undefined Then

			RootDocument = DocumentsTree.Rows.Add();
			RootDocument.Document = DataStructure.Metadata;

		EndIf;

		RowTSHeader = RootDocument.Rows.Find(DataStructure.TabulSectName, "TabularSection", False);
		If RowTSHeader = Undefined Then

			RowTSHeader = RootDocument.Rows.Add();
			RowTSHeader.TabularSection = DataStructure.TabulSectName;

		EndIf;

		DataRow = RowTSHeader.Rows.Add();
		DataRow.DataStructure = DataStructure;

	EndDo;

	HeaderPatternCondition = " %PathToAttributeTable%.%FieldHeaderParameter% = &Parameter ";
	QueryPattern = 
	"SELECT
	|	HeaderTable.Ref              AS Document,
	|	//%AdditFieldsRow%
	|	HeaderTable.Number               AS Number,
	|	HeaderTable.Date                AS Date,
	|	VALUETYPE(HeaderTable.Ref) AS DocumentType,
	|	CASE
	|		WHEN HeaderTable.Posted THEN
	|			1
	|		WHEN HeaderTable.DeletionMark THEN
	|			2
	|		ELSE 0
	|	END                        AS ImageID
	|FROM
	|	Document.%HeaderTableName% AS HeaderTable
	|WHERE
	| (%ConditionText%)
	|";
	PatternConditionForTS = " TableOfStrings.%FieldTSParameter% = &Parameter ";
	TSConditionPattern    = 
	" 1 In
	|	(SELECT TOP 1
	|			1
	|	FROM
	|		Document.%TableNameOfTS% AS TableOfStrings
	|	WHERE
	|		TableOfStrings.Ref = HeaderTable.Ref
	|		AND ( %ConditionOnTSRows% )
	|	)";

	For Each RootRow In DocumentsTree.Rows Do

		ConditionsTextByDocument = "";
		// Cycle by the attributes and tabular sections of the same document
		For Each RowTSAttribute In RootRow.Rows Do

			ConditionText = "";
			// Condition on the field in TS.
			If Not IsBlankString(RowTSAttribute.TabularSection) Then

				TempText = "";
				// Cycle by tabular sections
				For Each TSRow In RowTSAttribute.Rows Do

					TempText = TempText + ?(IsBlankString(TempText),"", " OR ")
						+ StrReplace(PatternConditionForTS, "%FieldTSParameter%", TSRow.DataStructure.AttributeName);

				EndDo;

				ConditionText = StrReplace(TSConditionPattern, "%TableNameOfTS%", RootRow.Document.Name + "." + RowTSAttribute.TabularSection);
				ConditionText = StrReplace(ConditionText, "%ConditionOnTSRows%", TempText);

			Else // Condition on the header

				// Cycle by attributes
				For Each TSRow In RowTSAttribute.Rows Do

					ConditionText = ConditionText + ?(IsBlankString(ConditionText),"", " OR ")
						+ StrReplace(HeaderPatternCondition, "%FieldHeaderParameter%", TSRow.DataStructure.AttributeName);

				EndDo; 					

			EndIf;                                                                                        
			
			If Not IsBlankString(ConditionText) Then                          

				AddTextToString(ConditionsTextByDocument, ConditionText, " OR ");

			EndIf;
		EndDo;

		If Not IsBlankString(ConditionsTextByDocument) Then

			QueryText = StrReplace(QueryPattern, "%HeaderTableName%", RootRow.Document.Name);
			QueryText = StrReplace(QueryText, "%ConditionText%", ConditionsTextByDocument);
			QueryText = StrReplace(QueryText, "%PathToAttributeTable%", "HeaderTable");

			AddAdditionalHeaderFields(QueryText,RootRow.Document, AddHeaderFields);
			
			If RootRow.Document.Name = "SubcontractorReport" Then
				QueryText = StrReplace(QueryText, "NULL  AS DocumentAmount,", "REFPRESENTATION(HeaderTable.Total) AS DocumentAmount,");	
			EndIf;
			
			If RootRow.Document.Name = "CashReceipt" Then
				QueryText = StrReplace(QueryText, "NULL  AS DocumentCurrency,", "REFPRESENTATION(HeaderTable.CashCurrency) AS DocumentCurrency,");	
			EndIf;
			
			If RootRow.Document.Name = "PaymentReceipt" Then
				QueryText = StrReplace(QueryText, "NULL  AS DocumentCurrency,", "REFPRESENTATION(HeaderTable.CashCurrency) AS DocumentCurrency,");	
			EndIf;
			
			If RootRow.Document.Name = "CashVoucher" Then
				QueryText = StrReplace(QueryText, "NULL  AS DocumentCurrency,", "REFPRESENTATION(HeaderTable.CashCurrency) AS DocumentCurrency,");	
			EndIf;
			
			If RootRow.Document.Name = "PaymentExpense" Then
				QueryText = StrReplace(QueryText, "NULL  AS DocumentCurrency,", "REFPRESENTATION(HeaderTable.CashCurrency) AS DocumentCurrency,");	
			EndIf;
			
			If RootRow.Document.Name = "OpeningBalanceEntry" Then
				QueryText = StrReplace(QueryText, "NULL  AS OperationKind,", "REFPRESENTATION(HeaderTable.AccountingSection) AS OperationKind,");	
			EndIf;
			
			AddQueryTable(RequestsTable, RootRow.Document, QueryText);
			
			RootRow.ConditionText = ConditionsTextByDocument;

		EndIf;
	EndDo;

EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

Procedure AddTextToString(String, Text, Delimiter = " Or ")

	String = String + ?(IsBlankString(String), "", Delimiter) + Text;

EndProcedure

Function GetDataStructure(DataPath)
	
	Structure = New Structure;
	
	MapOfNames = New Array();
	MapOfNames.Add("ObjectType");
	MapOfNames.Add("ObjectKind");
	MapOfNames.Add("DataPath");
	MapOfNames.Add("TabulSectName");
	MapOfNames.Add("AttributeName");
	
	For index = 1 To 3 Do
		
		Point = Find(DataPath, ".");
		CurrentValue = Left(DataPath, Point-1);
		Structure.Insert(MapOfNames[index-1], CurrentValue);
		DataPath = Mid(DataPath, Point+1);
		
	EndDo;
	
	DataPath = StrReplace(DataPath, "Attribute.", "");
	
	If Structure.DataPath = "TabularSection" Then
		
		For index = 4 To 5  Do 
			
			Point = Find(DataPath, ".");
			If Point = 0 Then
				CurrentValue = DataPath;
			Else
				CurrentValue = Left(DataPath, Point-1);
			EndIf;
			
			Structure.Insert(MapOfNames[index-1], CurrentValue);
			DataPath = Mid(DataPath,  Point+1);
			
		EndDo;
		
	Else
		
		Structure.Insert(MapOfNames[3], "");
		Structure.Insert(MapOfNames[4], DataPath);
		
	EndIf;
	
	If Structure.ObjectType = "Document" Then
		Structure.Insert("Metadata", Metadata.Documents[Structure.ObjectKind]);
	Else
		Structure.Insert("Metadata", Metadata.Catalogs[Structure.ObjectKind]);
	EndIf;

	
	Return Structure;
	
EndFunction

Procedure AddQueryTable(RequestsTable, DocumentMetadata, QueryText)

	TabRow = RequestsTable.Add();
	TabRow.DocumentName     = DocumentMetadata.Name;
	TabRow.DocumentSynonym = DocumentMetadata.Synonym;
	TabRow.Use     = True;
	TabRow.QueryText     = QueryText;

EndProcedure

Procedure AddAdditionalHeaderFields(QueryText, DocumentMetadata, AddHeaderFields)

	FieldPattern  = "%FieldName% AS %FieldPseudonym%,";
	FieldsRow = "";

	For Each FieldName In AddHeaderFields Do

		If DocumentMetadata.Attributes.Find(FieldName) <> Undefined Then

			Text = StrReplace(FieldPattern, "%FieldName%", "REFPRESENTATION(HeaderTable." + FieldName +" ) ");

		ElsIf FieldName = "Department"
			AND DocumentMetadata.Attributes.Find("SalesStructuralUnit") <> Undefined Then

			Text = StrReplace(FieldPattern, "%FieldName%", "REFPRESENTATION(HeaderTable.SalesStructuralUnit) ");
            Text = StrReplace(Text, "%FieldPseudonym%", "Department");

		ElsIf FieldName = "Department"
			AND DocumentMetadata.Attributes.Find("StructuralUnit") <> Undefined Then

			Text = StrReplace(FieldPattern, "%FieldName%", "REFPRESENTATION(HeaderTable.StructuralUnit) ");
            Text = StrReplace(Text, "%FieldPseudonym%", "Department");

		Else

			Text = StrReplace(FieldPattern, "%FieldName%", " NULL ");

		EndIf;

		FieldsRow = FieldsRow + ?(IsBlankString(FieldsRow), "", Chars.LF)
				+ StrReplace(Text, "%FieldPseudonym%", FieldName);

	EndDo;

	QueryText = StrReplace(QueryText, "//%AdditFieldsRow%", FieldsRow);

EndProcedure

#EndRegion

#EndIf