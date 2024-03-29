﻿////////////////////////////////////////////////////////////////////////////////
// Subsystem "Items sequence setting".
//
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Handler of the command "Move up" of the list form.
//
// Parameters:
//  ListFormAttribute - DynamicList - form attribute that contains the list;
//  ListFormItem      - FormTable   - form item that contains the list.
//
Procedure MoveItemUpExecute(ListFormAttribute, ListFormItem) Export
	
	MoveItem(ListFormAttribute, ListFormItem, "Up");
	
EndProcedure

// Handler of the command "Move down" of the list form.
//
// Parameters:
//  ListFormAttribute - DynamicList - form attribute that contains the list;
//  ListFormItem      - FormTable   - form item that contains the list.
//
Procedure MoveItemDownExecute(ListFormAttribute, ListFormItem) Export
	
	MoveItem(ListFormAttribute, ListFormItem, "Down");
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

Procedure MoveItem(ListAttribute, ListItem, Direction)
	
	If ListItem.CurrentData = Undefined Then
		Return;
	EndIf;
	
	Parameters = New Structure;
	Parameters.Insert("ListAttribute", ListAttribute);
	Parameters.Insert("ListItem", ListItem);
	Parameters.Insert("Direction", Direction);
	
	NotifyDescription = New NotifyDescription("MoveItemCheckingExecuted", ThisObject, Parameters);
	
	CheckListBeforeOperation(NotifyDescription, ListAttribute);
	
EndProcedure

Procedure MoveItemCheckingExecuted(CheckResult, AdditionalParameters) Export
	
	If CheckResult <> True Then
		Return;
	EndIf;
	
	ListItem = AdditionalParameters.ListItem;
	ListAttribute = AdditionalParameters.ListAttribute;
	Direction = AdditionalParameters.Direction;
	
	RepresentedAsList = (ListItem.Representation = TableRepresentation.List);
	
	ErrorText = ItemOrderSetupServiceServerCall.ChangeElementsOrder(
		ListItem.CurrentData.Ref, ListAttribute, RepresentedAsList, Direction);
		
	If Not IsBlankString(ErrorText) Then
		ShowMessageBox(, ErrorText);
	EndIf;
	
	ListItem.Refresh();
	
EndProcedure

Procedure CheckListBeforeOperation(ResultHandler, ListAttribute)
	
	Parameters = New Structure;
	Parameters.Insert("ResultHandler", ResultHandler);
	Parameters.Insert("ListAttribute", ListAttribute);
	
	If Not SortInListIsSetCorrectly(ListAttribute) Then
		QuestionText = NStr("en = 'To change the order of items, it
		                    |is necessary to configure the list sorting by the field ""Order"". Configure the necessary sorting?'");
		NotifyDescription = New NotifyDescription("CheckListBeforeOperationResponseForSortingReceived", ThisObject, Parameters);
		Buttons = New ValueList;
		Buttons.Add(DialogReturnCode.Yes, NStr("en = 'Customize'"));
		Buttons.Add(DialogReturnCode.No, NStr("en = 'Do not configure'"));
		ShowQueryBox(NotifyDescription, QuestionText, Buttons, , DialogReturnCode.Yes);
		Return;
	EndIf;
	
	MoveItemCheckingExecuted(True, ResultHandler.AdditionalParameters);
	
EndProcedure

Procedure CheckListBeforeOperationResponseForSortingReceived(ResponseResult, AdditionalParameters) Export
	
	If ResponseResult <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	ListAttribute = AdditionalParameters.ListAttribute;
	
	UserOrderSettings = Undefined;
	For Each Item In ListAttribute.SettingsComposer.UserSettings.Items Do
		If TypeOf(Item) = Type("DataCompositionOrder") Then
			UserOrderSettings = Item;
			Break;
		EndIf;
	EndDo;
	
	CommonUseClientServer.Validate(UserOrderSettings <> Undefined, NStr("en = 'Custom order setup setting was not found.'"));
	
	UserOrderSettings.Items.Clear();
	Item = UserOrderSettings.Items.Add(Type("DataCompositionOrderItem"));
	Item.Use = True;
	Item.Field = New DataCompositionField("AdditionalOrderingAttribute");
	Item.OrderType = DataCompositionSortDirection.Asc;
	
EndProcedure

Function SortInListIsSetCorrectly(List)
	
	UserOrderSettings = Undefined;
	For Each Item In List.SettingsComposer.UserSettings.Items Do
		If TypeOf(Item) = Type("DataCompositionOrder") Then
			UserOrderSettings = Item;
			Break;
		EndIf;
	EndDo;
	
	If UserOrderSettings = Undefined Then
		Return True;
	EndIf;
	
	OrderItems = UserOrderSettings.Items;
	
	// Find the first used order item.
	Item = Undefined;
	For Each OrderingItem In OrderItems Do
		If OrderingItem.Use Then
			Item = OrderingItem;
			Break;
		EndIf;
	EndDo;
	
	If Item = Undefined Then
		// No sorting is used.
		Return False;
	EndIf;
	
	If TypeOf(Item) = Type("DataCompositionOrderItem") Then
		If Item.OrderType = DataCompositionSortDirection.Asc Then
			AttributeField = New DataCompositionField("AdditionalOrderingAttribute");
			If Item.Field = AttributeField Then
				Return True;
			EndIf;
		EndIf;
	EndIf;
	
	Return False;
	
EndFunction

#EndRegion
