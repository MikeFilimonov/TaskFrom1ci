﻿// Procedure checks the correctness of the form attributes filling.
//
&AtClient
Procedure CheckFillOfFormAttributes(Cancel)
	
	// Attributes filling check.
	LineNumber = 0;
		
	For Each RowPrepayment In FilteredAdvances Do
		LineNumber = LineNumber + 1;
		If Not ValueIsFilled(RowPrepayment.Document) Then
			Message = New UserMessage();
			Message.Text = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'The ""Document"" column is not filled in the row %1 of the ""Filtered advances"" list.'"),
				String(LineNumber));
			Message.Field = "Document";
			Message.Message();
			Cancel = True;
		EndIf;
		If Not ValueIsFilled(RowPrepayment.Amount) Then
			Message = New UserMessage();
			Message.Text = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'The ""Amount"" column is not filled in the row %1 of the ""Filtered advances"" list.'"),
				String(LineNumber));
			Message.Field = "Document";
			Message.Message();
			Cancel = True;
		EndIf;
	EndDo;
	
EndProcedure

// Procedure calculates the total amount.
//
&AtClient
Procedure CalculateAmountTotal()
	
	AmountTotal = 0;
	
	For Each CurRow In FilteredAdvances Do
		AmountTotal = AmountTotal + CurRow.Amount;
	EndDo;
	
EndProcedure

// Procedure - OnCreateAtServer event handler.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Period = Parameters.Period;
	ParentCompany = Parameters.ParentCompany;
	Employee = Parameters.Employee;
	DocumentCurrency = Parameters.DocumentCurrency;
	Ref = Parameters.Refs;
	AddressAdvancesPaidInStorage = Parameters.AddressAdvancesPaidInStorage;
	FilteredAdvances.Load(GetFromTempStorage(AddressAdvancesPaidInStorage));
	FillAdvances();
	
EndProcedure

// Procedure - OnCreateAtServer event handler.
//
&AtClient
Procedure OnOpen(Cancel)
	
	CalculateAmountTotal();
	FillAdvances();
	
EndProcedure

// Procedure - OK button click handler.
//
&AtClient
Procedure OK(Command)
	
	Cancel = False;
	
	CheckFillOfFormAttributes(Cancel);
	
	If Not Cancel Then
		WritePickToStorage();
		Close(DialogReturnCode.OK);
	EndIf;
	
EndProcedure

// Procedure - handler of clicking the Refresh button.
//
&AtClient
Procedure Refresh(Command)
	
	FillAdvances();
	
EndProcedure

// Procedure - handler of clicking the AskAmount button.
//
&AtClient
Procedure AskAmount(Command)
	
	AskAmount = Not AskAmount;
	Items.AskAmount.Check = AskAmount;
	
EndProcedure

// The procedure places pick-up results in the storage.
//
&AtServer
Procedure WritePickToStorage()
	
	AdvancesInStorage = FilteredAdvances.Unload();
	PutToTempStorage(AdvancesInStorage, AddressAdvancesPaidInStorage);
	
EndProcedure

// The procedure places selection results into pick
//
&AtClient
Procedure AdvancesBalanceValueChoice(Item, Value, StandardProcessing)
	
	StandardProcessing = False;
	CurrentRow = Item.CurrentData;
	
	Amount = CurrentRow.Amount;
	If AskAmount Then
		ShowInputNumber(New NotifyDescription("AdvancesBalanceValueChoiceEnd", ThisObject, New Structure("CurrentRow, Amount", CurrentRow, Amount)), Amount, "Input amount", , );
		Return;
	EndIf;
	
	AdvancesBalanceValueChoiceFragment(Amount, CurrentRow);
EndProcedure

&AtClient
Procedure AdvancesBalanceValueChoiceEnd(Result, AdditionalParameters) Export
	
	CurrentRow = AdditionalParameters.CurrentRow;
	Amount = ?(Result = Undefined, AdditionalParameters.Amount, Result);
	
	
	If Not (Result <> Undefined) Then
		Return;
	EndIf;
	
	AdvancesBalanceValueChoiceFragment(Amount, CurrentRow);

EndProcedure

&AtClient
Procedure AdvancesBalanceValueChoiceFragment(Amount, Val CurrentRow)
	
	Var NewRow, Rows, SearchStructure;
	
	SearchStructure = New Structure("Document", CurrentRow.Document);
	Rows = FilteredAdvances.FindRows(SearchStructure);
	
	If Rows.Count() > 0 Then
		NewRow = Rows[0];
		Amount = Amount + NewRow.Amount;
	Else
		NewRow = FilteredAdvances.Add();
	EndIf;
	
	FillPropertyValues(NewRow, CurrentRow);
	
	NewRow.Amount = Amount;
	
	Items.FilteredAdvances.CurrentRow = NewRow.GetID();
	
	CalculateAmountTotal();
	FillAdvances();

EndProcedure

// Procedure - the DragStart event handler of the AdvancesBalance list.
//
&AtClient
Procedure AdvancesBalanceDragStart(Item, DragParameters, StandardProcessing)
	
	CurrentData = Item.CurrentData;
	Structure = New Structure;
	Structure.Insert("Document", CurrentData.Document);
	Structure.Insert("Amount", CurrentData.Amount);
	
	DragParameters.Value = Structure;
	
	DragParameters.AllowedActions = DragAllowedActions.Copy;
	
EndProcedure

&AtClient
// Procedure - DragChek of list FilteredAdvances event handler.
//
Procedure FilteredAdvancesDragCheck(Item, DragParameters, StandardProcessing, String, Field)
	
	StandardProcessing = False;
	DragParameters.Action = DragAction.Copy;
	
EndProcedure

// Procedure - Drag of list FilteredAdvances event handler.
//
&AtClient
Procedure FilteredAdvancesDrag(Item, DragParameters, StandardProcessing, String, Field)
	
	StandardProcessing = False;
	
	ParametersStructure = DragParameters.Value;
	
	Amount = ParametersStructure.Amount;
	If AskAmount Then
		ShowInputNumber(New NotifyDescription("FilteredAdvancesDragEnd", ThisObject, New Structure("StructureParameters,Amount", ParametersStructure, Amount)), Amount, "Input amount", , );
		Return;
	EndIf;
	
	FilteredAdvancesDragFragment(ParametersStructure, Amount);
EndProcedure

&AtClient
Procedure FilteredAdvancesDragEnd(Result, AdditionalParameters) Export
	
	ParametersStructure = AdditionalParameters.ParametersStructure;
	Amount = ?(Result = Undefined, AdditionalParameters.Amount, Result);
	
	
	If Not (Result <> Undefined) Then
		Return;
	EndIf;
	
	FilteredAdvancesDragFragment(ParametersStructure, Amount);

EndProcedure

&AtClient
Procedure FilteredAdvancesDragFragment(Val ParametersStructure, Amount)
	
	Var NewRow, Rows, SearchStructure;
	
	SearchStructure = New Structure("Document", ParametersStructure.Document);
	Rows = FilteredAdvances.FindRows(SearchStructure);
	
	If Rows.Count() > 0 Then
		NewRow = Rows[0];
		Amount = Amount + NewRow.Amount;
	Else
		NewRow = FilteredAdvances.Add();
	EndIf;
	
	FillPropertyValues(NewRow, ParametersStructure);
	
	NewRow.Amount = Amount;
	
	Items.FilteredAdvances.CurrentRow = NewRow.GetID();
	
	CalculateAmountTotal();
	FillAdvances();

EndProcedure

// Procedure - OnChange of list FilteredAdvances  event handler.
//
&AtClient
Procedure FilteredAdvancesOnChange(Item)
	
	CalculateAmountTotal();
	FillAdvances();
	
EndProcedure

// Procedure - OnStartEdit of list FilteredAdvances event handler.
//
&AtClient
Procedure FilteredAdvancesOnStartEdit(Item, NewRow, Copy)
	
	If Copy Then
		CalculateAmountTotal();
		FillAdvances();
	EndIf;
	
EndProcedure

// Procedure fills the advance list.
//
&AtServer
Procedure FillAdvances()
	
	Query = New Query();
	Query.Text =
	"SELECT
	|	FilteredAdvances.Document AS Document,
	|	FilteredAdvances.Amount AS Amount
	|INTO TableFilteredAdvances
	|FROM
	|	&TableFilteredAdvances AS FilteredAdvances
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AdvanceHoldersBalances.DocumentDate AS DocumentDate,
	|	AdvanceHoldersBalances.Document AS Document,
	|	SUM(AdvanceHoldersBalances.AmountCurBalance) AS Amount
	|FROM
	|	(SELECT
	|		AdvanceHoldersBalances.Document.Date AS DocumentDate,
	|		AdvanceHoldersBalances.Document AS Document,
	|		ISNULL(AdvanceHoldersBalances.AmountCurBalance, 0) AS AmountCurBalance
	|	FROM
	|		AccumulationRegister.AdvanceHolders.Balance(
	|				,
	|				Currency = &DocumentCurrency
	|					AND Company = &Company
	|					AND Employee = &Employee) AS AdvanceHoldersBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		FilteredAdvances.Document.Date,
	|		FilteredAdvances.Document,
	|		-FilteredAdvances.Amount
	|	FROM
	|		TableFilteredAdvances AS FilteredAdvances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsAdvanceHolders.Document.Date,
	|		DocumentRegisterRecordsAdvanceHolders.Document,
	|		CASE
	|			WHEN DocumentRegisterRecordsAdvanceHolders.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -ISNULL(DocumentRegisterRecordsAdvanceHolders.AmountCur, 0)
	|			ELSE ISNULL(DocumentRegisterRecordsAdvanceHolders.AmountCur, 0)
	|		END
	|	FROM
	|		AccumulationRegister.AdvanceHolders AS DocumentRegisterRecordsAdvanceHolders
	|	WHERE
	|		DocumentRegisterRecordsAdvanceHolders.Recorder = &Ref
	|		AND DocumentRegisterRecordsAdvanceHolders.Period <= &Period
	|		AND DocumentRegisterRecordsAdvanceHolders.Company = &Company
	|		AND DocumentRegisterRecordsAdvanceHolders.Employee = &Employee) AS AdvanceHoldersBalances
	|
	|GROUP BY
	|	AdvanceHoldersBalances.DocumentDate,
	|	AdvanceHoldersBalances.Document
	|
	|HAVING
	|	SUM(AdvanceHoldersBalances.AmountCurBalance) > 0
	|
	|ORDER BY
	|	DocumentDate";
	
	Query.SetParameter("Company", ParentCompany);
	Query.SetParameter("DocumentCurrency", DocumentCurrency);
	Query.SetParameter("Employee", Employee);
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("Period", Period);
	Query.SetParameter("TableFilteredAdvances", FilteredAdvances.Unload());
	
	AdvancesBalance.Load(Query.Execute().Unload());
	
EndProcedure

// Procedure - BeforeStartAdding of list FilteredAdvances event  handler.
//
&AtClient
Procedure FilteredAdvancesBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	Cancel = True;
	
EndProcedure
