
#Region ServiceProceduresAndFunctions

// Procedure updates the availability of the Company flag RunAccountingBySubsidiaryCompany.
//
&AtClient
Procedure RefreshSubsidiaryCompanyEnabled()
	
	Items.ParentCompany.Enabled = ConstantsSet.AccountingBySubsidiaryCompany;
	Items.ParentCompany.AutoChoiceIncomplete = ConstantsSet.AccountingBySubsidiaryCompany;
	Items.ParentCompany.AutoMarkIncomplete = ConstantsSet.AccountingBySubsidiaryCompany;
	
	If CheckEditRightOfParentCompanyConstant() AND Not ConstantsSet.AccountingBySubsidiaryCompany Then
		ConstantsSet.ParentCompany = PredefinedValue("Catalog.Companies.EmptyRef");
	EndIf;
	
EndProcedure

&AtServerNoContext
Function CheckEditRightOfParentCompanyConstant()
	
	Return AccessRight("Edit", Metadata.Constants.ParentCompany);
	
EndFunction

// Check on the possibility to disable the UseSeveralCompanies option.
//
&AtServer
Function CancellationUncheckUseSeveralCompanies()
	
	SetPrivilegedMode(True);
	
	Cancel = False;
	
	MainCompany = Catalogs.Companies.MainCompany;
	
	SelectionCompanies = Catalogs.Companies.Select();
	While SelectionCompanies.Next() Do
		
		If SelectionCompanies.Ref <> MainCompany Then
			
			RefArray = New Array;
			RefArray.Add(SelectionCompanies.Ref);
			RefsTable = FindByRef(RefArray);
			
			If RefsTable.Count() > 0 Then
				
				MessageText = NStr("en = 'Companies that differ from the main one are used in the infobase. Cannot clear the check box.'");
				DriveServer.ShowMessageAboutError(ThisForm, MessageText, , , "ConstantsSet.UseSeveralCompanies", Cancel);
				Break;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	SetPrivilegedMode(False);
	
	Return Cancel;
	
EndFunction

// Check on the possibility to change the established company.
//
&AtServer
Function CancellationSetAccountingBySubsidiaryCompanyChangeSubsidiaryCompany(FieldName)
	
	ParentCompany = ConstantsSet.ParentCompany;
	AccumulationRegistersCounter = 0;
	AreRecords = False;
	Query = New Query;
	Query.SetParameter("ParentCompany", ParentCompany);
	
	For Each AccumulationRegister In Metadata.AccumulationRegisters Do
		
		If AccumulationRegister = AccumulationRegisters.Workload Then
			Continue;
		EndIf;
			
		Query.Text = Query.Text + 
			?(Query.Text = "",
				"SELECT ALLOWED TOP 1", 
				"UNION ALL 
				|
				|SELECT TOP 1 ") + "
				|
				|	AccumulationRegister" + AccumulationRegister.Name + ".Company
				|FROM
				|	AccumulationRegister." + AccumulationRegister.Name + " AS " + "AccumulationRegister" + AccumulationRegister.Name + "
				|WHERE
				|	AccumulationRegister" + AccumulationRegister.Name + ".Company <> &ParentCompany
				|";
		
		AccumulationRegistersCounter = AccumulationRegistersCounter + 1;
		
		If AccumulationRegistersCounter > 3 Then
			AccumulationRegistersCounter = 0;
			Try
				QueryResult = Query.Execute();
				AreRecords = Not QueryResult.IsEmpty();
			Except
				
			EndTry;
			
			If AreRecords Then
				Break;
			EndIf; 
			Query.Text = "";
		EndIf;
		
	EndDo;
	
	If AccumulationRegistersCounter > 0 Then
		Try
			QueryResult = Query.Execute();
			If Not QueryResult.IsEmpty() Then
				AreRecords = True;
			EndIf;
		Except
		
		EndTry;
	EndIf;
	
	If AreRecords Then
		MessageText = NStr("en = 'Records are registered for a company that is different from the company in the infobase. Cannot change the parameter.'");
		DriveServer.ShowMessageAboutError(ThisForm, MessageText, , , FieldName);
		Return True;
	Else
		Return False;
	EndIf;
	
EndFunction

// Check on the possibility to disable the AccountingBySubsidiaryCompany option.
//
&AtServer
Function CancellationUncheckAccountingBySubsidiaryCompany()
	
	ParentCompany = Constants.ParentCompany.Get();
	DocumentsCounter = 0;
	Query = New Query;
	For Each Doc In Metadata.Documents Do
		
		If Doc.Posting = Metadata.ObjectProperties.Posting.Deny Then
			Continue;
		EndIf;

		Query.Text = Query.Text +
			?(Query.Text = "",
				"SELECT ALLOWED TOP 1",
				"UNION ALL
				|
				|SELECT TOP 1 ") + "
				|
				|	Document" + Doc.Name + ".Ref FROM Document." + Doc.Name + " AS " + "Document" + Doc.Name + "
				|	WHERE document" + Doc.Name + ".Company
				|	<> &ParentCompany AND Document" + Doc.Name + ".Posted
				|";
		
		DocumentsCounter = DocumentsCounter + 1;
		
		If DocumentsCounter > 3 Then
			DocumentsCounter = 0;
			Try
				Query.SetParameter("ParentCompany", ParentCompany);
				QueryResult = Query.Execute();
				AreDocuments = Not QueryResult.IsEmpty();
			Except
				
			EndTry;
			
			If AreDocuments Then
				Break;
			EndIf; 
			Query.Text = "";
		EndIf;
		
	EndDo;
	
	If DocumentsCounter > 0 Then
		Try
			QueryResult = Query.Execute();
			AreDocuments = Not QueryResult.IsEmpty();
		Except
			
		EndTry;
	EndIf;
	
	If AreDocuments Then
		MessageText = NStr("en = 'There are posted documents of a company which differs from the company in the infobase. You cannot clear the ""Company accounting"" check box.'");	
		DriveServer.ShowMessageAboutError(ThisForm, MessageText, , , "ConstantsSet.AccountingBySubsidiaryCompany");
		Return True;
	Else
		Return False;
	EndIf;
	
EndFunction

#Region FormCommandHandlers

// Procedure - command handler CompanyCatalog.
//
&AtClient
Procedure CatalogCompanies(Command)
	
	If Modified Then
		
		Message = New UserMessage();
		Message.Text = NStr("en = 'Data is not written yet. You can start editing the ""Companies"" catalog only after the data is written.'");
		Message.Message();
		Return;
		
	EndIf;
	
	If ConstantsSet.UseSeveralCompanies Then
		
		OpenForm("Catalog.Companies.ListForm");
		
	Else
		
		ParemeterCompany = New Structure("Key", PredefinedValue("Catalog.Companies.MainCompany"));
		OpenForm("Catalog.Companies.ObjectForm", ParemeterCompany);
		
	EndIf;
	
EndProcedure

#EndRegion

#EndRegion

#Region ProcedureFormEventHandlers

// Procedure - OnOpen form event handler
//
&AtClient
Procedure OnOpen(Cancel)
	
	RefreshSubsidiaryCompanyEnabled();
	ConstantValue = ConstantsSet.UseSeveralCompanies;
	
	Items.CompanySettingsSettings.Enabled	= ConstantValue;
	ValueOnOpenAccountingForSeveralCompanies 	= ConstantValue;
	
EndProcedure

// Procedure - event handler BeforeWriteAtServer form.
//
&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	// If there are references to the company different from the main company, it is not allowed to clear the
	// UseSeveralCompanies flag.
	If Constants.UseSeveralCompanies.Get() <> ConstantsSet.UseSeveralCompanies
		AND (NOT ConstantsSet.UseSeveralCompanies) 
		AND CancellationUncheckUseSeveralCompanies() Then
		
		ConstantsSet.UseSeveralCompanies = True;
		Cancel = True;
		Return;
		
	EndIf;
	
	// If the AccountingBySubsidiaryCompany flag is set, then the company must be filled.
	If ConstantsSet.AccountingBySubsidiaryCompany 
		AND Not ValueIsFilled(ConstantsSet.ParentCompany) Then
		
		MessageText = NStr("en = 'The ""Keep accounting by company"" check box is selected, but the company is not filled in.'");
		DriveServer.ShowMessageAboutError(ThisForm, MessageText, , , "ConstantsSet.ParentCompany", Cancel);
		Return;
		
	EndIf;
	
	// If there are any records of the company different from the selected company, it is not allowed to select AccountingBySubsidiaryCompany.
	If Constants.AccountingBySubsidiaryCompany.Get() <> ConstantsSet.AccountingBySubsidiaryCompany AND ConstantsSet.AccountingBySubsidiaryCompany
		AND CancellationSetAccountingBySubsidiaryCompanyChangeSubsidiaryCompany("ConstantsSet.AccountingBySubsidiaryCompany") Then
		
		ConstantsSet.AccountingBySubsidiaryCompany = False;
		ConstantsSet.ParentCompany = Catalogs.Companies.EmptyRef();
		Items.ParentCompany.Enabled = False;
		Items.ParentCompany.AutoChoiceIncomplete = False;
		Items.ParentCompany.AutoMarkIncomplete = False;
		Cancel = True;
		Return;
		
	EndIf;
	
	// If there are any posted documents of the company different from the company, it is not allowed to clear AccountingBySubsidiaryCompany.
	If Constants.AccountingBySubsidiaryCompany.Get() <> ConstantsSet.AccountingBySubsidiaryCompany AND (NOT ConstantsSet.AccountingBySubsidiaryCompany)
		AND CancellationUncheckAccountingBySubsidiaryCompany() Then
		
		ConstantsSet.AccountingBySubsidiaryCompany = True;
		ConstantsSet.ParentCompany = Constants.ParentCompany.Get();
		Items.ParentCompany.Enabled = True;
		Items.ParentCompany.AutoChoiceIncomplete = True;
		Items.ParentCompany.AutoMarkIncomplete = True;
		Cancel = True;
		Return;
		
	EndIf;
	
	// If there are any records of the company different from the selected company, it is not allowed to change Company.
	If Constants.ParentCompany.Get() <> ConstantsSet.ParentCompany
		AND ValueIsFilled(ConstantsSet.ParentCompany)
		AND ValueIsFilled(Constants.ParentCompany.Get())
		AND CancellationSetAccountingBySubsidiaryCompanyChangeSubsidiaryCompany("ConstantsSet.ParentCompany") Then
		
		ConstantsSet.ParentCompany = Constants.ParentCompany.Get();
		Cancel = True;
		Return;
		
	EndIf;
	
EndProcedure

// Procedure - event handler AfterWrite form.
//
&AtClient
Procedure AfterWrite(WriteParameters)
	
	ConstantValue = ConstantsSet.UseSeveralCompanies;
	If ValueOnOpenAccountingForSeveralCompanies <> ConstantValue Then
		
		Notify("Record_ConstantsSet", New Structure("Value", ConstantValue), "UseSeveralCompanies");
		
	EndIf;
	
EndProcedure

#Region ProcedureEventHandlersOfFormAttributes

// Procedure - event handler OnChange of the AccountingBySubsidiaryCompany field.
//
&AtClient
Procedure AccountingBySubsidiaryCompanyOnChange(Item)
	
	If ConstantsSet.AccountingBySubsidiaryCompany
	AND Not ValueIsFilled(ConstantsSet.ParentCompany) Then
		ConstantsSet.ParentCompany = PredefinedValue("Catalog.Companies.MainCompany");
	EndIf;
	
	RefreshSubsidiaryCompanyEnabled();
	
EndProcedure

// Procedure - event handler OnChange of the UseSeveralCompanies field.
//
&AtClient
Procedure UseSeveralCompaniesOnChange(Item)
	
	ConstantValue = ConstantsSet.UseSeveralCompanies;
	
	If Not ConstantValue Then
		
		ConstantsSet.AccountingBySubsidiaryCompany = False;
		ConstantsSet.ParentCompany = "";
		
	EndIf;
	
	RefreshSubsidiaryCompanyEnabled();
	Items.CompanySettingsSettings.Enabled = ConstantValue;
	
	RefreshInterface();
	
EndProcedure
// 

#EndRegion

#EndRegion
