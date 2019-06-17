
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("PriceTypes") Then
		PriceTypes = Parameters.PriceTypes;
	Else
		PriceTypes = New Array;
	EndIf; 
	
	FillTree(PriceTypes);	
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	For Each TreeRow In PriceTypesTree.GetItems() Do
		Items.PriceTypesTree.Expand(TreeRow.GetID());
	EndDo; 	
	
EndProcedure

#EndRegion 

#Region FormsItemEventHandlers

&AtClient
Procedure PriceTypesTreeMarkOnChange(Item)
	
	TreeRow = Items.PriceTypesTree.CurrentData;
	If TreeRow = Undefined Then
		Return;
	EndIf; 
	
	If TreeRow.GetItems().Count() > 0 Then
		For Each Substring In TreeRow.GetItems()  Do
			Substring.Check = TreeRow.Check;
		EndDo; 
	EndIf;
	
	ParentRow = TreeRow.GetParent();
	If ParentRow <> Undefined Then
		
		Value = TreeRow.Check;
		
		If ParentRow.Check AND Not Value Then
			ParentRow.Check = False;
		EndIf; 
		
		For Each AnotherRow In ParentRow.GetItems() Do
			If Value <> AnotherRow.Check Then
				Return;
			EndIf; 
		EndDo;
		
		ParentRow.Check = Value;
		
	EndIf; 
	
EndProcedure

#EndRegion 

#Region FormCommandHandlers

&AtClient
Procedure Select(Command)
	
	NotifyChoice(SelectedPriceTypes());	
	
EndProcedure
 
&AtClient
Procedure CheckAll(Command)
	
	For Each TreeRow In PriceTypesTree.GetItems() Do
		TreeRow.Check = True;
		
		For Each TreeSubRow In TreeRow.GetItems() Do
			TreeSubRow.Check = True;
		EndDo; 
	EndDo; 	
	
EndProcedure

&AtClient
Procedure UncheckAll(Command)
	
	For Each TreeRow In PriceTypesTree.GetItems() Do
		TreeRow.Check = False;
		
		For Each TreeSubRow In TreeRow.GetItems() Do
			TreeSubRow.Check = False;
		EndDo; 
	EndDo; 	
	
EndProcedure

#EndRegion 

#Region InternalProceduresAndFunctions

&AtServer
Procedure FillTree(PriceTypes)
	
	PriceTypesTree.GetItems().Clear();
	
	Query = New Query;
	Query.SetParameter("PriceTypes", PriceTypes);
	Query.Text =
	"SELECT
	|	SupplierPriceTypes.Ref AS PriceKind,
	|	SupplierPriceTypes.Description AS Description,
	|	SupplierPriceTypes.Owner AS Counterparty,
	|	SupplierPriceTypes.Owner.Description AS Presentation,
	|	CASE
	|		WHEN SupplierPriceTypes.Ref IN (&PriceTypes)
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS Check
	|FROM
	|	Catalog.SupplierPriceTypes AS SupplierPriceTypes
	|WHERE
	|	SupplierPriceTypes.Owner.Supplier
	|
	|ORDER BY
	|	Check DESC,
	|	Presentation,
	|	Description
	|TOTALS
	|	MAX(Description),
	|	MAX(Presentation),
	|	MIN(Check)
	|BY
	|	Counterparty";
	SelectionCounterparty = Query.Execute().Select(QueryResultIteration.ByGroups);
	
	While SelectionCounterparty.Next() Do
		CounterpartyRow = PriceTypesTree.GetItems().Add();
		CounterpartyRow.Presentation = SelectionCounterparty.Presentation;
		
		FillPropertyValues(CounterpartyRow, SelectionCounterparty, "Counterparty, Check");
		
		SelectionPriceKind = SelectionCounterparty.Select();
		If SelectionPriceKind.Count() > 1 Then
			While SelectionPriceKind.Next() Do
				PricesKindRow = CounterpartyRow.GetItems().Add();
				FillPropertyValues(PricesKindRow, SelectionPriceKind, "PriceKind, Check");
				PricesKindRow.Presentation = String(PricesKindRow.PriceKind);
			EndDo; 
		Else
			SelectionPriceKind.Next();
			FillPropertyValues(CounterpartyRow, SelectionPriceKind, "PriceKind, Check");
			
			If Find(SelectionPriceKind.Description, SelectionPriceKind.Presentation) = 0 Then
				CounterpartyRow.Presentation = SelectionPriceKind.Presentation + ", " + SelectionPriceKind.Description;
			Else
				CounterpartyRow.Presentation = SelectionPriceKind.Description;
			EndIf; 
		EndIf; 
	EndDo;
	
EndProcedure

&AtClient
Function SelectedPriceTypes()
	
	Result = New Array;
	For Each CounterpartyRow In PriceTypesTree.GetItems() Do
		
		For Each PricesKindRow In CounterpartyRow.GetItems() Do
			If Not PricesKindRow.Check Then
				Continue;
			EndIf; 
			
			Result.Add(PricesKindRow.PriceKind);
		EndDo;
		
		If ValueIsFilled(CounterpartyRow.PriceKind) AND CounterpartyRow.Check Then
			Result.Add(CounterpartyRow.PriceKind);
		EndIf; 
		
	EndDo;
	
	Return Result;
	
EndFunction

#EndRegion
 