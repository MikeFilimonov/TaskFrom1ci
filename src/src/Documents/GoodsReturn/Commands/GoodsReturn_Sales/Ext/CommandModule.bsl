
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	Filter = New Structure;
	Filter.Insert("OperationKind", PredefinedValue("Enum.OperationTypesGoodsReturn.FromCustomer"));
	
	FormParameters = New Structure("Filter, PurposeUseKey", Filter, "FromCustomer");
	OpenedForm = OpenForm("Document.GoodsReturn.ListForm", FormParameters, CommandExecuteParameters.Source,
					CommandExecuteParameters.Uniqueness, CommandExecuteParameters.Window, CommandExecuteParameters.URL);
	
	OpenedForm.Items.SupplierInvoice.Visible = False;
	
EndProcedure
