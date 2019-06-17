
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	FillForm(Parameters);
	
	ProductDescription = "";
	
	If ValueIsFilled(Products) Then
		ProductDescription = CommonUse.ObjectAttributeValue(Products, "Description");
	EndIf;
	
	Title = StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en = 'GL accounts: %1'"),
		ProductDescription);
		
	Height = 16;
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, MessageText, StandardProcessing)
	
	If Exit And (Modified Or Select) Then
		Cancel = True;
		Return;
	EndIf;
	
	If Modified And Not Select Then
		Cancel = True;
		QuestionText = NStr("en = 'Data was changed. Do you want to save the changes?'");
		
		Notify = New NotifyDescription("QuestionBeforeCloseEnd", ThisForm);
		ShowQueryBox(Notify, QuestionText, QuestionDialogMode.YesNoCancel,, DialogReturnCode.Yes);
	EndIf;
	
	If Select And Not Cancel Then
		Cancel = Not CheckFillingAtClient();
	EndIf;
	
	If Cancel Then
		Select = False;
	EndIf;

EndProcedure

&AtClient
Procedure OnClose(Exit)
	
	If Select Then
		ResultStructure = New Structure("InventoryGLAccount, InventoryTransferredGLAccount, InventoryReceivedGLAccount,
			|InventoryToGLAccount, SignedOutEquipmentGLAccount, GoodsShippedNotInvoicedGLAccount,
			|GoodsReceivedNotInvoicedGLAccount, GoodsInvoicedNotDeliveredGLAccount, UnearnedRevenueGLAccount, VATInputGLAccount,
			|VATOutputGLAccount, RevenueGLAccount, COGSGLAccount, ConsumptionGLAccount, SalesReturnGLAccount,
			|PurchaseReturnGLAccount, TableName");
		
		FillPropertyValues(ResultStructure, ThisObject);
		NotifyChoice(ResultStructure);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure Cancel(Command)
	
	Select = False;
	Modified = False;
	Close();
	
EndProcedure

&AtClient
Procedure OK(Command)
	
	Select = True;
	Close();
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure FillForm(Parameters)
	
	FormItems = Items.GroupAttribute.ChildItems;
	For Each Item In FormItems Do
		Parameters.Property(Item.Name, ThisForm[Item.Name]);
		Item.Visible = Parameters.Property(Item.Name);
	EndDo;
	
	Parameters.Property("TableName",	TableName);	
	Parameters.Property("Products",		Products);
	
	If Parameters.TableName = "Expenses" Then
		Items.InventoryGLAccount.Title = NStr("en = 'Expenses';");
	ElsIf Parameters.Property("InventoryToGLAccount") Then
		Items.InventoryGLAccount.Title = NStr("en = 'From';");
	EndIf;

EndProcedure

&AtClient
Function CheckFillingAtClient()
	
	Cancel = False;
	
	FormItems = Items.GroupAttribute.ChildItems;
	For Each Item In FormItems Do
		If Item.Visible And Not ValueIsFilled(ThisForm[Item.Name]) Then
			MessageText = CommonUseClientServer.TextFillingErrors("Field", "Filling", Item.Title);
			Field = Item.Name;
			CommonUseClientServer.MessageToUser(MessageText, , Field, "", Cancel);
		EndIf;
	EndDo;
	
	Return Not Cancel;
	
EndFunction

#EndRegion