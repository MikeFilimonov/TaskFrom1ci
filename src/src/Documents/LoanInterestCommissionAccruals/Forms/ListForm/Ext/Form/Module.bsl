
#Region FormEventHandlers

// Procedure - handler of the WhenCreatingOnServer event of the form.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	WorkWithFilters.RestoreFilterSettings(ThisObject, List);
		
EndProcedure

&AtClient
Procedure OnClose(Exit = False)
	
	If Not Exit Then
		SaveFilterSettings();
	EndIf; 

EndProcedure

#EndRegion

#Region FormsItemEventHandlers

&AtClient
Procedure FilterOperationKindChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	If Not ValueIsFilled(SelectedValue) Then
		Return;
	EndIf;
	
	SetMarkAndListFilter("OperationType", Item.Parent.Name, SelectedValue);
	SelectedValue = Undefined;
	
EndProcedure

&AtClient
Procedure FilterCompanyChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	If Not ValueIsFilled(SelectedValue) Then
		Return;
	EndIf;
	
	SetMarkAndListFilter("Company", Item.Parent.Name, SelectedValue);
	SelectedValue = Undefined;
	
EndProcedure

#EndRegion

#Region FilterMarks

&AtServer
Procedure SetMarkAndListFilter(FilterFieldListName, GroupMarkParent, SelectedValue, ValuePresentation="")
	
	If ValuePresentation = "" Then
		ValuePresentation = String(SelectedValue);
	EndIf; 
	
	WorkWithFilters.AttachFilterLabel(ThisObject, FilterFieldListName, GroupMarkParent, SelectedValue, ValuePresentation);
	WorkWithFilters.SetListFilter(ThisObject, List, FilterFieldListName);
	
EndProcedure

&AtClient
Procedure Attachable_LabelURLProcessing(Item, FormattedStringURL, StandardProcessing)
	
	StandardProcessing = False;
	
	IDMark = Mid(Item.Name, StrLen("Label_") + 1);
	DeleteFilterMark(IDMark);
	
EndProcedure

&AtServer
Procedure DeleteFilterMark(IDMark)
	
	WorkWithFilters.DeleteFilterLabelServer(ThisObject, List, IDMark);

EndProcedure

&AtClient
Procedure PeriodPresentationClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	WorkWithFiltersClient.PeriodPresentationSelectPeriod(ThisObject, "List", "Date");
	
EndProcedure

&AtServer
Procedure SaveFilterSettings()
	
	WorkWithFilters.SaveFilterSettings(ThisObject);
	
EndProcedure

&AtClient
Procedure CollapseExpandFilterBar(Item)
	
	NewValueVisibility = Not Items.FilterSettingsAndAddInfo.Visible;
	WorkWithFiltersClient.CollapseExpandFiltesPanel(ThisObject, NewValueVisibility);
		
EndProcedure

#EndRegion
