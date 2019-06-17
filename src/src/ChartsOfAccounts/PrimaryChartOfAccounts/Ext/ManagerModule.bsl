#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

Procedure FillNewGLAccounts(DocumentName, Fields) Export
	
	ArrayOfRefs = DocumentsForFillingGLAccounts(DocumentName, Fields);
	For Each Ref In ArrayOfRefs Do
		FillGLAccountInTable(Ref, DocumentName, Fields);
	EndDo;
	
	RefsCount = ArrayOfRefs.Count();
	If RefsCount > 0 Then
		
		EventName = EventName(DocumentName);
		
		If RefsCount = 1 Then
			Comment = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = '%1 document was overwritten'", CommonUseClientServer.MainLanguageCode()),
				RefsCount);
		Else
			Comment = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = '%1 documents were overwritten'", CommonUseClientServer.MainLanguageCode()),
			RefsCount);
		EndIf;
		
		WriteLogEvent(EventName, EventLogLevel.Information,,, Comment);
		
	EndIf;
	
EndProcedure

Function GLAccountFields() Export
	Return New Structure("Source, Receiver, Parameter", "", "", "");
EndFunction

#EndRegion

#Region EventHandlers

Procedure ChoiceDataGetProcessing(ChoiceData, Parameters, StandardProcessing)
	
	If Not Parameters.Filter.Property("TypeOfAccount")
		And (Not Parameters.Property("AllowHeaderAccountsSelection")
			Or Not Parameters.AllowHeaderAccountsSelection) Then
		
		AccountTypes = New Array;
		HeaderItem = Enums.GLAccountsTypes.Header;
		
		For Each Item In Enums.GLAccountsTypes Do
			If Not Item = HeaderItem Then
				AccountTypes.Add(Item);
			EndIf;
		EndDo;
		
		Parameters.Filter.Insert("TypeOfAccount", AccountTypes);
		
	EndIf;
	
EndProcedure

Procedure PresentationGetProcessing(Data, Presentation, StandardProcessing)
	StandardProcessing = False;
	Presentation = CommonUse.ObjectAttributeValue(Data.Ref, "Code") + " " + Data.Description;	
EndProcedure

#EndRegion

#Region Private

Procedure AddUnionInQueryText(QueryText)
	
	If ValueIsFilled(QueryText) Then
		QueryText = QueryText + "
			|UNION ALL
			|";
	EndIf;
	
EndProcedure

Function EventName(DocumentName)
	
	EventName = StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en = 'Fill GL Accounts in document.%1'", CommonUseClientServer.MainLanguageCode()),
		DocumentName);
		
	Return EventName;
	
EndFunction

Function DocumentsForFillingGLAccounts(DocumentName, Tables)
	
	Refs = New Array();
	
	Tempalate = "
	|SELECT DISTINCT
	|	Table.Ref AS Ref
	|FROM
	|	&DocumentTable AS Table
	|WHERE
	|	&Condition
	|";
	
	Query = New Query();
	
	DocumentQuery = "";
	For Each Table In Tables Do
		
		AddUnionInQueryText(DocumentQuery);
		
		If ValueIsFilled(Table.Name) Then
			DocumentTable = StringFunctionsClientServer.SubstituteParametersInString(
				"Document.%1.%2",
				DocumentName,
				Table.Name);
		Else
			DocumentTable = StringFunctionsClientServer.SubstituteParametersInString(
				"Document.%1",
				DocumentName);
		EndIf;
			
		TableTemplate = StrReplace(Tempalate, "&DocumentTable", DocumentTable);
			
		TableQueryText = "";
		For Each Condition In Table.Conditions Do
			
			AddUnionInQueryText(TableQueryText);
			
			If Left(Condition.Source, 1) = "&" Then
				SourceField = "";
				ParameterName = StrReplace(Condition.Source, "&", "");
				Query.SetParameter(ParameterName, Condition.Parameter);
			Else
				SourceField = "Table.";
			EndIf;
			
			ConditionText = StringFunctionsClientServer.SubstituteParametersInString(
				"%1%2 <> VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
				|	AND Table.%3 = VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)",
				SourceField,
				Condition.Source,
				Condition.Receiver);
				
			ConditionQueryText = StrReplace(TableTemplate, "&Condition", ConditionText);
			TableQueryText = TableQueryText + ConditionQueryText;
			
		EndDo;
		
		DocumentQuery = DocumentQuery + TableQueryText;
		
	EndDo;
		
	QueryTemplate = "
	|SELECT DISTINCT
	|	Table.Ref AS Ref
	|FROM
	|	&DocumentQuery AS Table
	|";
	
	Query.Text = StrReplace(QueryTemplate, "&DocumentQuery", "(" + DocumentQuery + ")");
	
	Result = Query.Execute().Unload();
	
	Refs = Result.UnloadColumn("Ref");
	
	Return Refs;
	
EndFunction

Procedure FillGLAccountInTable(Ref, DocumentName, Tables)
	
	Template = "
	|SELECT
	|	&LineNumber AS LineNumber,
	|	""&TableName"" AS TableName,
	|	&CasesOfNewGLAccounts
	|FROM
	|	&SourceTable AS Table
	|WHERE
	|	Table.Ref = &Ref";
	
	TemplateOfNewGLAccount = "
	|
	|	CASE
	|		WHEN Table.%1 = VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|			AND %2%3 <> VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|		THEN %2%3
	|		ELSE Table.%1
	|	END AS %1";
	
	Query = New Query();
	Query.SetParameter("Ref", Ref);
	
	Object = Ref.GetObject();
	
	GLAccountWasChanged = False;
	For Each Table In Tables Do
		
		CasesOfNewGLAccounts = "";
		For Each Condition In Table.Conditions Do
			
			If ValueIsFilled(CasesOfNewGLAccounts) Then
				CasesOfNewGLAccounts = CasesOfNewGLAccounts + ",";
			EndIf;
			
			If Left(Condition.Source, 1) = "&" Then
				SourceField = "";
				ParameterName = StrReplace(Condition.Source, "&", "");
				Query.SetParameter(ParameterName, Condition.Parameter);
			Else
				SourceField = "Table.";
			EndIf;
			
			NewGLAccount = StringFunctionsClientServer.SubstituteParametersInString(
				TemplateOfNewGLAccount,
				Condition.Receiver,
				SourceField,
				Condition.Source);
			
			CasesOfNewGLAccounts = CasesOfNewGLAccounts + NewGLAccount;
			
		EndDo;
		
		If ValueIsFilled(Table.Name) Then
			
			SourceTable = StringFunctionsClientServer.SubstituteParametersInString(
				"Document.%1.%2",
				DocumentName,
				Table.Name);
				
			LineNumber = "Table.LineNumber";
			
		Else
			
			SourceTable = StringFunctionsClientServer.SubstituteParametersInString(
				"Document.%1",
				DocumentName);
				
			LineNumber = "1";
			
		EndIf;
			
		TableTemplate = StrReplace(Template, "&TableName", Table.Name);
		TableTemplate = StrReplace(TableTemplate, "&LineNumber", LineNumber);
		TableTemplate = StrReplace(TableTemplate, "&SourceTable", SourceTable);
		TableTemplate = StrReplace(TableTemplate, "&CasesOfNewGLAccounts", CasesOfNewGLAccounts);
		
		Query.Text = TableTemplate;
		
		Selection = Query.Execute().Select();
		While Selection.Next() Do
			GLAccountWasChanged = True;
			If ValueIsFilled(Selection.TableName) Then
				CurrentRow = Object[Selection.TableName][Selection.LineNumber - 1];
				FillPropertyValues(CurrentRow, Selection, ,"LineNumber");
			Else
				FillPropertyValues(Object, Selection);
			EndIf;
		EndDo;
	EndDo;
	
	If Not GLAccountWasChanged Then
		Return;
	EndIf;
	
	BeginTransaction();
	Try
		Object.Write();
		CommitTransaction();
	Except
		RollbackTransaction();
		
		EventName = EventName(DocumentName);
		Comment = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Error on rewriting the document %1'", CommonUseClientServer.MainLanguageCode()),
			Ref);
			
		WriteLogEvent(EventName, EventLogLevel.Error,,, Comment);
		
		Raise;
	EndTry;
	
EndProcedure

#EndRegion

#EndIf