////////////////////////////////////////////////////////////////////////////////
// MODAL VARIABLES MASTERS (Client)

#Region Variables

&AtClient
Var mCurrentPageNumber;

&AtClient
Var mFirstPage;

&AtClient
Var mLastPage;

&AtClient
Var mFormRecordCompleted;

#EndRegion

#Region GeneralPurposeProceduresAndFunctions

// Procedure writes the form changes.
//
&AtServer
Procedure WriteFormChanges(FinishEntering = False)
	
	If Company.LegalEntityIndividual = PredefinedValue("Enum.CounterpartyType.Individual") Then
		IndividualObject = FormAttributeToValue("Individual");
		IndividualObject.Write();
		Company.Individual = IndividualObject.Ref;
	EndIf;
	
	CompanyObject = FormAttributeToValue("Company");
	CompanyObject.Write();
	
	RecordSet = InformationRegisters.ResponsiblePersons.CreateRecordSet();
	DateBegOfYear = BegOfYear(CurrentDate());
	
	If ValueIsFilled(ChiefExecutiveOfficer.Description) Then
		
		ChiefExecutiveObject = FormAttributeToValue("ChiefExecutiveOfficer");
		ChiefExecutiveObject.EmploymentContractType = ?(ValueIsFilled(ChiefExecutiveObject.EmploymentContractType), ChiefExecutiveObject.EmploymentContractType, Enums.EmploymentContractTypes.FullTime);
		ChiefExecutiveObject.Write();
		
		CEOPosition = NStr("en = 'Chief Executive Officer'");
		
		PositionObject = Catalogs.Positions.FindByDescription(CEOPosition);
		If PositionObject = Catalogs.Positions.EmptyRef() Then
			PositionObject = Catalogs.Positions.CreateItem();
			PositionObject.Description = CEOPosition;
			PositionObject.Write();
		EndIf;
		
		NewRow = RecordSet.Add();
		NewRow.Company					= CompanyObject.Ref;
		NewRow.ResponsiblePersonType	= Enums.ResponsiblePersonTypes.ChiefExecutiveOfficer;
		NewRow.Employee					= ChiefExecutiveObject.Ref;
		NewRow.Period					= DateBegOfYear;
		NewRow.Position					= PositionObject.Ref;
		
	EndIf;
	
	If ValueIsFilled(ChiefAccountant.Description) Then
		
		If ChiefAccountant.Description = ChiefExecutiveOfficer.Description
		 OR (ChiefAccountant.Ref <> Catalogs.Employees.EmptyRef() AND ChiefAccountant.Ref = ChiefExecutiveOfficer.Ref) Then
			ChiefAccountantObject = ChiefExecutiveObject;
		Else
			ChiefAccountantObject = FormAttributeToValue("ChiefAccountant");
			ChiefAccountantObject.EmploymentContractType = ?(ValueIsFilled(ChiefAccountantObject.EmploymentContractType), ChiefAccountantObject.EmploymentContractType, Enums.EmploymentContractTypes.FullTime);
			ChiefAccountantObject.Write();
		EndIf;
		
		CAPosition = NStr("en = 'Chief accountant'");
		
		PositionObject = Catalogs.Positions.FindByDescription(CAPosition);
		If PositionObject = Catalogs.Positions.EmptyRef() Then
			PositionObject = Catalogs.Positions.CreateItem();
			PositionObject.Description = CAPosition;
			PositionObject.Write();
		EndIf;
		
		NewRow = RecordSet.Add();
		NewRow.Company					= CompanyObject.Ref;
		NewRow.ResponsiblePersonType	= Enums.ResponsiblePersonTypes.ChiefAccountant;
		NewRow.Employee					= ChiefAccountantObject.Ref;
		NewRow.Period					= DateBegOfYear;
		NewRow.Position					= PositionObject.Ref;
		
	EndIf;
	
	If ValueIsFilled(Cashier.Description) Then
		
		If Cashier.Description = ChiefExecutiveOfficer.Description
			OR (Cashier.Ref <> Catalogs.Employees.EmptyRef()
				AND Cashier.Ref = ChiefExecutiveOfficer.Ref) Then
			CashierObject = ChiefExecutiveObject;
		ElsIf Cashier.Description = ChiefAccountant.Description
			OR (Cashier.Ref <> Catalogs.Employees.EmptyRef()
				AND Cashier.Ref = ChiefAccountant.Ref) Then
			CashierObject = ChiefAccountantObject;
		Else
			CashierObject = FormAttributeToValue("Cashier");
			CashierObject.EmploymentContractType = ?(ValueIsFilled(CashierObject.EmploymentContractType), CashierObject.EmploymentContractType, Enums.EmploymentContractTypes.FullTime);
			CashierObject.Write();
		EndIf;
		
		CashierPosition = NStr("en = 'Cashier'");
		
		PositionObject = Catalogs.Positions.FindByDescription(CashierPosition);
		If PositionObject = Catalogs.Positions.EmptyRef() Then
			PositionObject = Catalogs.Positions.CreateItem();
			PositionObject.Description = CashierPosition;
			PositionObject.Write();
		EndIf;
		
		NewRow = RecordSet.Add();
		NewRow.Company					= CompanyObject.Ref;
		NewRow.ResponsiblePersonType	= Enums.ResponsiblePersonTypes.Cashier;
		NewRow.Employee					= CashierObject.Ref;
		NewRow.Period					= DateBegOfYear;
		NewRow.Position					= PositionObject.Ref;
		
	EndIf;
	
	If ValueIsFilled(WarehouseSupervisor.Description) Then
		
		If WarehouseSupervisor.Description = ChiefExecutiveOfficer.Description
			OR (WarehouseSupervisor.Ref <> Catalogs.Employees.EmptyRef()
				AND WarehouseSupervisor.Ref = ChiefExecutiveOfficer.Ref) Then
			WarehouseSupervisorObject = ChiefExecutiveObject;
		ElsIf WarehouseSupervisor.Description = ChiefAccountant.Description
			OR (WarehouseSupervisor.Ref <> Catalogs.Employees.EmptyRef()
				AND WarehouseSupervisor.Ref = ChiefAccountant.Ref) Then
			WarehouseSupervisorObject = ChiefAccountantObject;
		ElsIf WarehouseSupervisor.Description = Cashier.Description
			OR (WarehouseSupervisor.Ref <> Catalogs.Employees.EmptyRef()
				AND WarehouseSupervisor.Ref = Cashier.Ref) Then
			WarehouseSupervisorObject = CashierObject;
		Else
			WarehouseSupervisorObject = FormAttributeToValue("WarehouseSupervisor");
			WarehouseSupervisorObject.EmploymentContractType = ?(ValueIsFilled(WarehouseSupervisorObject.EmploymentContractType), 
																	WarehouseSupervisorObject.EmploymentContractType,
																	Enums.EmploymentContractTypes.FullTime);
			WarehouseSupervisorObject.Write();
		EndIf;
		
		WSPosition = NStr("en = 'Warehouse Supervisor'");
		
		PositionObject = Catalogs.Positions.FindByDescription(WSPosition);
		If PositionObject = Catalogs.Positions.EmptyRef() Then
			PositionObject = Catalogs.Positions.CreateItem();
			PositionObject.Description = WSPosition;
			PositionObject.Write();
		EndIf;
		
		NewRow = RecordSet.Add();
		NewRow.Company					= CompanyObject.Ref;
		NewRow.ResponsiblePersonType	= Enums.ResponsiblePersonTypes.WarehouseSupervisor;
		NewRow.Employee					= WarehouseSupervisorObject.Ref;
		NewRow.Period					= DateBegOfYear;
		NewRow.Position					= PositionObject.Ref;
		
	EndIf;
	
	RecordSet.Write(True);
	
	If FinishEntering Then
		Constants.CompanyInformationIsFilled.Set(True);
	EndIf;
	
EndProcedure

// Procedure sets the active page.
//
&AtClient
Procedure SetActivePage()
	
	StringLegalEntityIndividual = ?(Company.LegalEntityIndividual = PredefinedValue("Enum.CounterpartyType.Individual"), "Individual", "LegalEntity");
	SearchString = "Step" + String(mCurrentPageNumber) + ?(mCurrentPageNumber = 2, StringLegalEntityIndividual, "");
	Items.Pages.CurrentPage = Items.Find(SearchString);
	
	Title = StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en = 'Company information filling wizard (Step %1/%2)'"),
		mCurrentPageNumber, mLastPage);
	
EndProcedure

// Procedure sets the buttons accessibility.
//
&AtClient
Procedure SetButtonsEnabled()
	
	Items.Back.Enabled = mCurrentPageNumber <> mFirstPage;
	
	If mCurrentPageNumber = mLastPage Then
		Items.GoToNext.Title			= NStr("en = 'Finish'");
		Items.GoToNext.Representation	= ButtonRepresentation.Text;
		Items.GoToNext.Font				= New Font(Items.GoToNext.Font,,, True);
	Else
		Items.GoToNext.Title			= NStr("en = 'Next'");
		Items.GoToNext.Representation	= ButtonRepresentation.PictureAndText;
		Items.GoToNext.Font				= New Font(Items.GoToNext.Font,,, False);
	EndIf;
	
EndProcedure

// Procedure checks filling of the mandatory attributes when you go to the next page.
//
&AtClient
Procedure ExecuteActionsOnTransitionToNextPage(Cancel)
	
	ClearMessages();
	
	If mCurrentPageNumber = 2 Then
		
		If Not ValueIsFilled(Company.Description) Then
			MessageText = NStr("en = 'Specify short name.'");
			CommonUseClientServer.MessageToUser(
				MessageText,
				,
				"Description",
				"Company",
				Cancel
			);
		EndIf;
		
		If Company.LegalEntityIndividual = PredefinedValue("Enum.CounterpartyType.Individual")
			AND Not ValueIsFilled(Individual.Description) Then
			
			MessageText = NStr("en = 'Specify the full name.'");
			CommonUseClientServer.MessageToUser(
				MessageText,
				,
				"Description",
				"Ind",
				Cancel
			);
			
		EndIf;
		
		CheckAccountingPolicy(Company.Ref, Cancel);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region ProcedureFormEventHandlers

// Procedure - OnOpen form event handler
//
&AtClient
Procedure OnOpen(Cancel)
	
	mCurrentPageNumber		= 1;
	mFirstPage				= 1;
	mLastPage				= 5;
	mFormRecordCompleted	= False;
	
	SetActivePage();
	SetButtonsEnabled();
	
EndProcedure

// Procedure - event handler OnCreateAtServer of the form.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
		
	CompanyRef = Catalogs.Companies.MainCompany;
	ValueToFormAttribute(CompanyRef.GetObject(), "Company");
	
	If ValueIsFilled(CompanyRef.Individual) Then
		ValueToFormAttribute(CompanyRef.Individual.GetObject(), "Individual");
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	ResponsiblePersonsSliceLast.Employee,
	|	ResponsiblePersonsSliceLast.ResponsiblePersonType,
	|	ResponsiblePersonsSliceLast.Company
	|FROM
	|	InformationRegister.ResponsiblePersons.SliceLast AS ResponsiblePersonsSliceLast
	|WHERE
	|	ResponsiblePersonsSliceLast.Company = &Company";
	Query.SetParameter("Company", CompanyRef);
	
	SelectionQueryResult = Query.Execute().Select();
	
	While SelectionQueryResult.Next() Do
		
		If SelectionQueryResult.ResponsiblePersonType = Enums.ResponsiblePersonTypes.ChiefExecutiveOfficer Then
			ValueToFormAttribute(SelectionQueryResult.Employee.GetObject(), "ChiefExecutiveOfficer");
		ElsIf SelectionQueryResult.ResponsiblePersonType = Enums.ResponsiblePersonTypes.ChiefAccountant Then
			ValueToFormAttribute(SelectionQueryResult.Employee.GetObject(), "ChiefAccountant");
		ElsIf SelectionQueryResult.ResponsiblePersonType = Enums.ResponsiblePersonTypes.Cashier Then
			ValueToFormAttribute(SelectionQueryResult.Employee.GetObject(), "Cashier");
		ElsIf SelectionQueryResult.ResponsiblePersonType = Enums.ResponsiblePersonTypes.WarehouseSupervisor Then
			ValueToFormAttribute(SelectionQueryResult.Employee.GetObject(), "WarehouseSupervisor");
		EndIf;
		
	EndDo;
	
	If Company.Description = NStr("en = 'LLC ""Our company""'") Then
		Company.Description = "";
	EndIf;
	
	If Not ValueIsFilled(Company.LegalEntityIndividual) Then
		Company.LegalEntityIndividual = Enums.CounterpartyType.LegalEntity;	
	EndIf;
	
	If Not ValueIsFilled(ChiefAccountant.OverrunGLAccount) Then
		ChiefAccountant.OverrunGLAccount = Catalogs.DefaultGLAccounts.GetDefaultGLAccount("AdvanceHoldersPayable");
	EndIf;
	
	If Not ValueIsFilled(ChiefAccountant.SettlementsHumanResourcesGLAccount) Then
		ChiefAccountant.SettlementsHumanResourcesGLAccount = Catalogs.DefaultGLAccounts.GetDefaultGLAccount("PayrollPayable");
	EndIf;
	
	If Not ValueIsFilled(ChiefAccountant.AdvanceHoldersGLAccount) Then
		ChiefAccountant.AdvanceHoldersGLAccount = Catalogs.DefaultGLAccounts.GetDefaultGLAccount("AdvanceHolders");
	EndIf;
	
	If Not ValueIsFilled(ChiefExecutiveOfficer.OverrunGLAccount) Then
		ChiefExecutiveOfficer.OverrunGLAccount = Catalogs.DefaultGLAccounts.GetDefaultGLAccount("AdvanceHoldersPayable");
	EndIf;
	
	If Not ValueIsFilled(ChiefExecutiveOfficer.SettlementsHumanResourcesGLAccount) Then
		ChiefExecutiveOfficer.SettlementsHumanResourcesGLAccount = Catalogs.DefaultGLAccounts.GetDefaultGLAccount("PayrollPayable");
	EndIf;
	
	If Not ValueIsFilled(ChiefExecutiveOfficer.AdvanceHoldersGLAccount) Then
		ChiefExecutiveOfficer.AdvanceHoldersGLAccount = Catalogs.DefaultGLAccounts.GetDefaultGLAccount("AdvanceHolders");
	EndIf;
	
	If Not ValueIsFilled(Cashier.OverrunGLAccount) Then
		Cashier.OverrunGLAccount = Catalogs.DefaultGLAccounts.GetDefaultGLAccount("AdvanceHoldersPayable");
	EndIf;
	
	If Not ValueIsFilled(Cashier.SettlementsHumanResourcesGLAccount) Then
		Cashier.SettlementsHumanResourcesGLAccount = Catalogs.DefaultGLAccounts.GetDefaultGLAccount("PayrollPayable");
	EndIf;
	
	If Not ValueIsFilled(Cashier.AdvanceHoldersGLAccount) Then
		Cashier.AdvanceHoldersGLAccount = Catalogs.DefaultGLAccounts.GetDefaultGLAccount("AdvanceHolders");
	EndIf;
	
	If Not ValueIsFilled(WarehouseSupervisor.OverrunGLAccount) Then
		WarehouseSupervisor.OverrunGLAccount = Catalogs.DefaultGLAccounts.GetDefaultGLAccount("AdvanceHoldersPayable");
	EndIf;
	
	If Not ValueIsFilled(WarehouseSupervisor.SettlementsHumanResourcesGLAccount) Then
		WarehouseSupervisor.SettlementsHumanResourcesGLAccount = Catalogs.DefaultGLAccounts.GetDefaultGLAccount("PayrollPayable");
	EndIf;
	
	If Not ValueIsFilled(WarehouseSupervisor.AdvanceHoldersGLAccount) Then
		WarehouseSupervisor.AdvanceHoldersGLAccount = Catalogs.DefaultGLAccounts.GetDefaultGLAccount("AdvanceHolders");
	EndIf;
	
EndProcedure

// Procedure - event handler BeforeClose form.
//
&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)	
	
	If Not mFormRecordCompleted
		AND Modified Then
		
		If Exit Then
			WarningText = NStr("en = 'Data will be lost'"); 			
			Return;			
		EndIf;
		
		Cancel = True;
		NotifyDescription = New NotifyDescription("BeforeCloseEnd", ThisObject);
		ShowQueryBox(NotifyDescription, NStr("en = 'Save changes?'"), QuestionDialogMode.YesNoCancel);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeCloseEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		Cancel = False;
		ExecuteActionsOnTransitionToNextPage(Cancel);
		If Not Cancel Then
			WriteFormChanges();
		EndIf;
		Modified = False;
		Close();
	ElsIf Result = DialogReturnCode.No Then
		Modified = False;
		Close();
	EndIf;
	
EndProcedure

#EndRegion

#Region ProcedureActionsOfTheFormCommandPanels

// Procedure - CloseForm command handler.
//
&AtClient
Procedure CloseForm(Command)
	
	Close(False);
	
EndProcedure

// Procedure - CompleteFilling command handler.
//
&AtClient
Procedure CompleteFilling(Command)
	
	WriteFormChanges();
	Close(True);
	
EndProcedure

// Procedure - Next command handler.
//
&AtClient
Procedure GoToNext(Command)
	
	Cancel = False;
	ExecuteActionsOnTransitionToNextPage(Cancel);
	If Cancel Then
		Return;
	EndIf;
	
	If mCurrentPageNumber = mLastPage Then
		WriteFormChanges(True);
		mFormRecordCompleted = True;
		Close(True);
	EndIf;
	
	mCurrentPageNumber = ?(mCurrentPageNumber + 1 > mLastPage, mLastPage, mCurrentPageNumber + 1);
	SetActivePage();
	SetButtonsEnabled();
	
EndProcedure

// Procedure - Back command handler.
//
&AtClient
Procedure Back(Command)
	
	Cancel = False;
	ExecuteActionsOnTransitionToNextPage(Cancel);
	If Cancel Then
		Return;
	EndIf;
	
	mCurrentPageNumber = ?(mCurrentPageNumber - 1 < mFirstPage, mFirstPage, mCurrentPageNumber - 1);
	SetActivePage();
	SetButtonsEnabled();
	
EndProcedure

#EndRegion

#Region ProcedureEventHandlersOfFormAttributes

// Procedure - handler of clicking on the input field.
//
&AtClient
Procedure Decoration32Click(Item)
	
	Cancel = False;
	ExecuteActionsOnTransitionToNextPage(Cancel);
	If Cancel Then
		Return;
	EndIf;
	
	mCurrentPageNumber = 1;
	SetActivePage();
	SetButtonsEnabled();
	
EndProcedure

// Procedure - handler of clicking on the input field.
//
&AtClient
Procedure Decoration34Click(Item)
	
	Cancel = False;
	ExecuteActionsOnTransitionToNextPage(Cancel);
	If Cancel Then
		Return;
	EndIf;
	
	mCurrentPageNumber = 2;
	SetActivePage();
	SetButtonsEnabled();
	
EndProcedure

// Procedure - handler of clicking on the input field.
//
&AtClient
Procedure Decoration36Click(Item)
	
	Cancel = False;
	ExecuteActionsOnTransitionToNextPage(Cancel);
	If Cancel Then
		Return;
	EndIf;
	
	mCurrentPageNumber = 3;
	SetActivePage();
	SetButtonsEnabled();
	
EndProcedure

// Procedure - handler of clicking on the input field.
//
&AtClient
Procedure Decoration38Click(Item)
	
	Cancel = False;
	ExecuteActionsOnTransitionToNextPage(Cancel);
	If Cancel Then
		Return;
	EndIf;
	
	mCurrentPageNumber = 4;
	SetActivePage();
	SetButtonsEnabled();
	
EndProcedure

// Procedure - event handler OnChange of the CompanyDescription attribute.
//
&AtClient
Procedure CompanyDescriptionOnChange(Item)
	
	If IsBlankString(Company.DescriptionFull) Then
		Company.DescriptionFull = Company.LegalEntityIndividual;
	EndIf;
	
EndProcedure

&AtClient
Procedure ChiefExecutiveNameOnChange(Item)
	
	If Not ValueIsFilled(ChiefExecutiveOfficer.Ref) Then
		Return;
	EndIf;
	
	If ChiefExecutiveOfficer.Ref = ChiefAccountant.Ref Then
		ChiefAccountant.Description = ChiefExecutiveOfficer.Description;
	EndIf;
	
	If ChiefExecutiveOfficer.Ref = Cashier.Ref Then
		Cashier.Description = ChiefExecutiveOfficer.Description;
	EndIf;
	
	If ChiefExecutiveOfficer.Ref = WarehouseSupervisor.Ref Then
		WarehouseSupervisor.Description = ChiefExecutiveOfficer.Description;
	EndIf;
	
EndProcedure

&AtClient
Procedure ChiefAccountantNameOnChange(Item)
	
	If Not ValueIsFilled(ChiefAccountant.Ref) Then
		Return;
	EndIf;
	
	If ChiefAccountant.Ref = ChiefExecutiveOfficer.Ref Then
		ChiefExecutiveOfficer.Description = ChiefAccountant.Description;
	EndIf;
	
	If ChiefAccountant.Ref = Cashier.Ref Then
		Cashier.Description = ChiefAccountant.Description;
	EndIf;
	
	If ChiefAccountant.Ref = WarehouseSupervisor.Ref Then
		WarehouseSupervisor.Description = ChiefAccountant.Description;
	EndIf;
	
EndProcedure

&AtClient
Procedure CashierDescriptionOnChange(Item)
	
	If Not ValueIsFilled(Cashier.Ref) Then
		Return;
	EndIf;
	
	If Cashier.Ref = ChiefExecutiveOfficer.Ref Then
		ChiefExecutiveOfficer.Description = Cashier.Description;
	EndIf;
	
	If Cashier.Ref = ChiefAccountant.Ref Then
		ChiefAccountant.Description = Cashier.Description;
	EndIf;
	
	If Cashier.Ref = WarehouseSupervisor.Ref Then
		WarehouseSupervisor.Description = Cashier.Description;
	EndIf;
	
EndProcedure

&AtClient
Procedure WarehouseSupervisorNameOnChange(Item)
	
	If Not ValueIsFilled(WarehouseSupervisor.Ref) Then
		Return;
	EndIf;
	
	If WarehouseSupervisor.Ref = ChiefExecutiveOfficer.Ref Then
		ChiefExecutiveOfficer.Description = WarehouseSupervisor.Description;
	EndIf;
	
	If WarehouseSupervisor.Ref = ChiefAccountant.Ref Then
		ChiefAccountant.Description = WarehouseSupervisor.Description;
	EndIf;
	
	If WarehouseSupervisor.Ref = Cashier.Ref Then
		Cashier.Description = WarehouseSupervisor.Description;
	EndIf;
	
EndProcedure

&AtClient
Procedure SpecifyAccountingPolicy(Command)
	OpenForm("InformationRegister.AccountingPolicy.RecordForm", New Structure("Company, Period", Company.Ref, BegOfYear(CurrentDate())));	
EndProcedure

&AtServerNoContext
Procedure CheckAccountingPolicy(Company, Cancel)
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	AccountingPolicySliceLast.Company AS Company
	|FROM
	|	InformationRegister.AccountingPolicy.SliceLast(&Date, Company = &Company) AS AccountingPolicySliceLast";
	Query.SetParameter("Date",		CurrentDate());
	Query.SetParameter("Company",	Company);
	
	Result = Query.Execute();
	
	If Not Result.IsEmpty() Then
		Return;
	EndIf;
	
	CommonUseClientServer.MessageToUser(
		NStr("en = 'Specify the accounting policy.'"),,,,
		Cancel);
	
EndProcedure

#EndRegion
