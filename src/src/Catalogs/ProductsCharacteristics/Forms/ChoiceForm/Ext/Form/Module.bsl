
#Region GeneralPurposeProceduresAndFunctions

&AtServer
// Sets filter for product characteristic choice form.
//
Procedure SetFilterByOwnerAtServer()
	
	FilterList = New ValueList;
	FilterList.Add(Products);
	FilterList.Add(ProductsCategory);
	
	DriveClientServer.SetListFilterItem(List,"Owner",FilterList,True,DataCompositionComparisonType.InList);
	
EndProcedure

&AtClient
// Sets filter for product characteristic choice form.
//
Procedure SetFilterByOwnerAtClient()
	
	FilterList = New ValueList();
	FilterList.Add(Products);
	FilterList.Add(ProductsCategory);
	
	DriveClientServer.SetListFilterItem(List,"Owner",FilterList,True,DataCompositionComparisonType.InList);
	
EndProcedure

&AtServer
// Fill property tree by values.
//
Procedure FillValuesPropertiesTree(WrapValuesEntered, AdditionalAttributes)
	
	If WrapValuesEntered Then
		PropertiesManagementOverridable.MovePropertiesValues(AdditionalAttributes, FormAttributeToValue("PropertiesValuesTree"));
	EndIf;
	
	PrListOfSets = New ValueList;
	Set = ProductsCategory.SetOfCharacteristicProperties;
	If Set <> Undefined Then
		PrListOfSets.Add(Set);
	EndIf;
	
	Tree = PropertiesManagementOverridable.FillValuesPropertiesTree(ProductsCategory, AdditionalAttributes, True, PrListOfSets);
	ValueToFormAttribute(Tree, "PropertiesValuesTree");
	
EndProcedure

&AtClient
// Procedure traverses the value tree recursively.
//
Procedure SetFilterByPropertiesAndValues(TreeItems)
	
	For Each TreeRow In TreeItems Do
		
		If ValueIsFilled(TreeRow.Value) Then
			
			DriveClientServer.SetListFilterItem(List,"Ref.[" + String(TreeRow.Property)+"]",TreeRow.Value);
			
		EndIf;
		
		NextTreeItem = TreeRow.GetItems();
		SetFilterByPropertiesAndValues(NextTreeItem);
		
	EndDo;
	
EndProcedure

&AtServer
// Procedure traverses the value tree recursively.
//
Procedure RecursiveBypassOfValueTree(TreeItems, String)
	
	For Each TreeRow In TreeItems Do
		
		If ValueIsFilled(TreeRow.Value) Then
			If IsBlankString(TreeRow.FormatProperties) Then
				String = String + TreeRow.Value + ", ";
			Else
				String = String + Format(TreeRow.Value, TreeRow.FormatProperties) + ", ";
			EndIf;
		EndIf;
		
		NextTreeItem = TreeRow.GetItems();
		RecursiveBypassOfValueTree(NextTreeItem, String);
		
	EndDo;
	
EndProcedure

#EndRegion

#Region ProcedureFormEventHandlers

&AtServer
// Procedure - event handler OnCreateAtServer of the form.
// The procedure implements
// - setting the filter for choice form.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Filter.Property("Owner") AND TypeOf(Parameters.Filter.Owner) = Type("CatalogRef.Products") Then
		
		Products = Parameters.Filter.Owner;
		ProductsCategory = Parameters.Filter.Owner.ProductsCategory;
		
		MessageText = "";
		If Not ValueIsFilled(Products) Then
			MessageText = NStr("en = 'Products are not filled in.'");
		ElsIf Parameters.Property("ThisIsReceiptDocument") AND Products.ProductsType = Enums.ProductsTypes.Service Then
			MessageText = NStr("en = 'Accounting by characteristics is not kept for services of external counterparties.'");
		ElsIf Not Products.UseCharacteristics Then
			MessageText = NStr("en = 'Accounting by characteristics is not kept for the products.'");
		EndIf;
		
		If Not IsBlankString(MessageText) Then
			CommonUseClientServer.MessageToUser(MessageText,,,,Cancel);
			Return;
		EndIf;
		
		// Clean the passed filter and set its
		Parameters.Filter.Delete("Owner");
		SetFilterByOwnerAtServer();
		
		// Fill the property value tree.
		FillValuesPropertiesTree(False, Parameters.CurrentRow.AdditionalAttributes);
		
	Else
		
		Items.ListCreate.Enabled = False;
		Items.ListContextMenuCreate.Enabled = False;
		
	EndIf;
	
EndProcedure

&AtClient
// Event handler procedure OnOpen.
//
Procedure OnOpen(Cancel)
	
	// Develop the property value tree.
	DriveClient.ExpandPropertiesValuesTree(Items.PropertiesValuesTree, PropertiesValuesTree);
	
EndProcedure

#Region TabularSectionAttributeEventHandlersPropertiesAndValues

&AtClient
// Procedure - event handler OnChange input field Value.
//
Procedure ValueOnChange(Item)
	
	List.SettingsComposer.Settings.Filter.Items.Clear();
	
	SetFilterByOwnerAtClient();
	
	TreeItems = PropertiesValuesTree.GetItems();
	SetFilterByPropertiesAndValues(TreeItems);
	
EndProcedure

#EndRegion

#Region TabularSectionAttributeEventHandlersCharacteristics

&AtClient
// Procedure - event handler BeforeAddStart input field List.
//
Procedure ListBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	If Copy = True Then
		Return;
	EndIf;
	
	Cancel = True;
	
	FillingValues = New Structure;
	FillingValues.Insert("Owner", Products);
	
	FormParameters = New Structure;
	FormParameters.Insert("FillingValues", FillingValues);
	
	OpenForm("Catalog.ProductsCharacteristics.ObjectForm", FormParameters);
	
EndProcedure

#EndRegion

#Region PropertyMechanismProcedures

&AtClient
// Procedure - event handler OnChange input field PropertyValueTree.
//
Procedure PropertyValueTreeOnChange(Item)
	
	Modified = True;
	
EndProcedure

&AtClient
// Procedure - event handler BeforeAddStart input field PropertyValueTree.
//
Procedure PropertyValueTreeBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	Cancel = True;
	
EndProcedure

&AtClient
// Procedure - event handler BeforeDelete input field PropertyValueTree.
//
Procedure PropertyValueTreeBeforeDelete(Item, Cancel)
	
	DriveClient.PropertyValueTreeBeforeDelete(Item, Cancel, Modified);
	
EndProcedure

&AtClient
// Procedure - event handler WhenEditStart input field PropertyValueTree.
//
Procedure PropertyValueTreeOnStartEdit(Item, NewRow, Copy)
	
	DriveClient.PropertyValueTreeOnStartEdit(Item);
	
EndProcedure

#EndRegion

#EndRegion
