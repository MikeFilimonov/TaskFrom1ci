#Region CommonUseProceduresAndFunctions

// Using the procedure you can select or clear the "Active" flag.
//
// Parameters:
//  NewValue  - Boolean - New value of the "Active" flag.
//  SelectedRowArray  - Array - String array selected in the list of automatic discounts.
//
&AtServer
Procedure ChangeCheckBoxActsServer(NewValue, Val SelectedRowArray)

	NeedToUpdateList = False;
	For Each AutoDiscountRow In SelectedRowArray Do
		If AutoDiscountRow.Acts <> NewValue Then
			If AutoDiscountRow.Ref.IsEmpty() Or AutoDiscountRow.IsFolder Then
				Continue;
			EndIf;
			ObjectAutoDiscount = AutoDiscountRow.Ref.GetObject();
			ObjectAutoDiscount.Acts = NewValue;
			Try
				ObjectAutoDiscount.Write();
				NeedToUpdateList = True;
			Except
				Message = New UserMessage;
				Message.Text = NStr("en = 'Cannot change the ""Active"" flag for  ""'")+AutoDiscountRow.Ref+""".";
				Message.Field = "Acts";
				Message.SetData(AutoDiscountRow.Ref);
				Message.Message();
			EndTry;
		EndIf;
	EndDo;
	
	If NeedToUpdateList Then
		Items.AutomaticDiscounts.Refresh();
	EndIf;

EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// The procedure checks the configured sorting by the
// attribute "AdditionalSortingAttribute" and suggests to set this sorting.
//
&AtClient
Procedure ValidateListFilter()
	
	SortingSetupParameters = New Structure;
	SortingSetupParameters.Insert("ListAttribute", AutomaticDiscounts);
	SortingSetupParameters.Insert("ListItem", Items.AutomaticDiscounts);
	
	If Not SortInListIsSetCorrectly() Then
		QuestionText = NStr("en = 'It is recommended
		                    |to sort the list by the field ""Order"". Configure the necessary sorting?'");
		NotifyDescription = New NotifyDescription("CheckListBeforeOperationResponseForSortingReceived", ThisObject, SortingSetupParameters);
		Buttons = New ValueList;
		Buttons.Add(DialogReturnCode.Yes, NStr("en = 'Customize'"));
		Buttons.Add(DialogReturnCode.No, NStr("en = 'Do not configure'"));
		ShowQueryBox(NotifyDescription, QuestionText, Buttons, , DialogReturnCode.Yes);
		Return;
	EndIf;
	
EndProcedure

// The function checks that the list is sorted by the attribute AdditionalOrderingAttribute.
//
&AtClient
Function SortInListIsSetCorrectly()
	
	UserOrderSettings = Undefined;
	For Each Item In AutomaticDiscounts.SettingsComposer.UserSettings.Items Do
		If TypeOf(Item) = Type("DataCompositionOrder") Then
			UserOrderSettings = Item;
			Break;
		EndIf;
	EndDo;
	
	If UserOrderSettings = Undefined Then
		Return True;
	EndIf;
	
	OrderItems = UserOrderSettings.Items;
	
	// Find the first used order item
	Item = Undefined;
	For Each OrderingItem In OrderItems Do
		If OrderingItem.Use Then
			Item = OrderingItem;
			Break;
		EndIf;
	EndDo;
	
	If Item = Undefined Then
		// No sorting is set
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

// The procedure processes user response to the question about the sorting by the attribute AdditionalOrderingAttribute.
//
&AtClient
Procedure CheckListBeforeOperationResponseForSortingReceived(ResponseResult, AdditionalParameters) Export
	
	If ResponseResult <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	SetListSortingByFieldOrderAtClient();
	
EndProcedure

// The procedure sets the order by the field AdditionalOrderingAttribute.
//
&AtClient
Procedure SetListSortingByFieldOrderAtClient()
	
	ListAttribute = AutomaticDiscounts;
	
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

// The procedure sets the order by the field AdditionalOrderingAttribute.
//
&AtServer
Procedure SetListSortingByFieldOrderAtServer()
	
	ListAttribute = AutomaticDiscounts;
	
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

#EndRegion

#Region ProceduresFormEventsHandlers

// Procedure - OnCreateAtServer form event handler.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Price accessibility setup for editing.
	AllowedEditDocumentPrices = DriveAccessManagementReUse.AllowedEditDocumentPrices();
	
	Items.DiscountTypes.ReadOnly = Not AllowedEditDocumentPrices;
	Items.AutomaticDiscounts.ReadOnly = Not AllowedEditDocumentPrices;
	
	// AutomaticDiscounts
	UseAutomaticDiscounts = GetFunctionalOption("UseAutomaticDiscounts");
	If UseAutomaticDiscounts Then
		Exclusion = PredefinedValue("Enum.DiscountsApplyingRules.Exclusion");
		Multiplication = PredefinedValue("Enum.DiscountsApplyingRules.Multiplication");
		
		SharedUsageVariantOfDiscounts = Constants.DefaultDiscountsApplyingRule.Get();
		If SharedUsageVariantOfDiscounts.IsEmpty() Then
			If AllowedEditDocumentPrices Then
				SharedUsageVariantOfDiscounts = Enums.DiscountsApplyingRules.Addition;
				SetPrivilegedMode(True);
				Constants.DefaultDiscountsApplyingRule.Set(SharedUsageVariantOfDiscounts);
				SetPrivilegedMode(False);
			Else
				Cancel = True;
				CommonUseClientServer.MessageToUser("Automatic discounts are not configured! Refer to the user with the right to edit price in the documents!");
				Return;
			EndIf;
		EndIf;
	EndIf;
	
	If Not AllowedEditDocumentPrices Then
		Items.SharedUsageVariantOfDiscounts.Visible = False;
		
		Items.LabelJointUseVariant.Title = "Joint application: "+Constants.DefaultDiscountsApplyingRule.Get();
		Items.LabelJointUseVariant.Visible = True;
	EndIf;
	// End AutomaticDiscounts
	
	VisibleManagementServer();
	
	If SharedUsageVariantOfDiscounts = Exclusion
		OR SharedUsageVariantOfDiscounts = Multiplication Then
		SetListSortingByFieldOrderAtServer();
	EndIf;
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm, "ListForm");
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
EndProcedure

// Procedure - event handler of the form NotificationProcessing.
//
&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If Source = "UseAutomaticDiscounts" Or Source = "UseManualDiscounts" Then
		VisibleManagementServer();
	EndIf;
	
EndProcedure

#EndRegion

#Region ProceduresAndFunctionsForFormAppearanceManagement

// The procedure manages the visible and headers depending on FO UseManualDiscounts and UseAutomaticDiscounts.
// 
&AtServer
Procedure VisibleManagementServer()
	
	UseAutomaticDiscounts = GetFunctionalOption("UseAutomaticDiscounts");
	UseManualDiscounts = GetFunctionalOption("UseManualDiscounts");
	If UseAutomaticDiscounts AND Not UseManualDiscounts Then
		Items.GroupManualDiscounts.Visible = False;
		Items.GroupManualAndAutomaticDiscounts.PagesRepresentation = FormPagesRepresentation.None;
		Title = NStr("en = 'Automatic discount'");
	ElsIf Not UseAutomaticDiscounts AND UseManualDiscounts Then
		Items.GroupAutomaticDiscounts.Visible = False;
		Items.GroupManualAndAutomaticDiscounts.PagesRepresentation = FormPagesRepresentation.None;
		Title = NStr("en = 'Discount types'");
	Else
		// This branch will be used while processing alerts of accounting setting forms.
		Items.GroupManualDiscounts.Visible = True;
		Items.GroupAutomaticDiscounts.Visible = True;
		Items.GroupManualAndAutomaticDiscounts.PagesRepresentation = FormPagesRepresentation.TabsOnTop;
		Title = NStr("en = 'Discounts'");
	EndIf;
	
EndProcedure
	
#EndRegion

#Region ProceduresElementFormEventsHandlers

// Procedure - event handler OnChange item DiscountSharedUsageVariant of the form.
//
&AtClient
Procedure SharedUsageVariantOfDiscountsOnChange(Item)
	
	DiscountsJointApplicationOptionOnChangeAtServer(SharedUsageVariantOfDiscounts);
	If SharedUsageVariantOfDiscounts = Exclusion
		OR SharedUsageVariantOfDiscounts = Multiplication Then
		ValidateListFilter();
	EndIf;
	Items.AutomaticDiscounts.Refresh();
	
EndProcedure

// Server part of DiscountSharedUsageVariantOnChange procedure.
//
&AtServerNoContext
Procedure DiscountsJointApplicationOptionOnChangeAtServer(SharedUsageVariantOfDiscounts)
	
	SetPrivilegedMode(True);
	Constants.DefaultDiscountsApplyingRule.Set(SharedUsageVariantOfDiscounts);
	SetPrivilegedMode(False);
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

// Procedure - CreateJointApplicationGroup command handler of the form.
&AtClient
Procedure CreateFolderSharedUse(Command)
	
	GroupFormParameters = New Structure("IsFolder", True);
	OpenForm("Catalog.AutomaticDiscountTypes.FolderForm", GroupFormParameters);
	
EndProcedure

// Procedure - SelectFlagActive command handler of the form.
//
&AtClient
Procedure EnableFlagActive(Command)
	
	If ValueIsFilled(Items.AutomaticDiscounts.SelectedRows) Then
		ChangeCheckBoxActsServer(True, Items.AutomaticDiscounts.SelectedRows);
	EndIf;
	
EndProcedure

// Procedure - ClearFlagActive command handler of the form.
//
&AtClient
Procedure ClearFlagActs(Command)
	
	If ValueIsFilled(Items.AutomaticDiscounts.SelectedRows) Then
		ChangeCheckBoxActsServer(False, Items.AutomaticDiscounts.SelectedRows);
	EndIf;
	
EndProcedure

#EndRegion

#Region ProceduresEventHandlersDynamicLists

// Procedure - OnChange event handler of AutomaticDiscounts dynamic list.
//
&AtClient
Procedure AutomaticDiscountsOnChange(Item)
	
	Item.Refresh();
	
EndProcedure

#EndRegion
