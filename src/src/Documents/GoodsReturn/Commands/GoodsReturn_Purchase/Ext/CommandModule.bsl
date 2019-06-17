
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	Filter = New Structure;
	Filter.Insert("OperationKind", PredefinedValue("Enum.OperationTypesGoodsReturn.ToSupplier"));
	
	FormParameters = New Structure("Filter, PurposeUseKey", Filter, "ToSupplier");
	OpenedForm = OpenForm("Document.GoodsReturn.ListForm", FormParameters, CommandExecuteParameters.Source,
					CommandExecuteParameters.Uniqueness, CommandExecuteParameters.Window, CommandExecuteParameters.URL);
					
	OpenedForm.Items.SalesDocument.Visible = False;
	
EndProcedure
