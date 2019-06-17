
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	DocumentInitiator = Undefined;
	Parameters.Property("DocumentInitiator", DocumentInitiator);
	
	DataProcessorObject = FormAttributeToValue("Object");
	DataProcessorObject.FillOrders(Parameters);
	ValueToFormAttribute(DataProcessorObject, "Object");
	FormManagment();
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure MarkAllExecute(Command)
	
	Tab = StrReplace(Items.Pages.CurrentPage.Name, "Page", "");
	
	For Each Row In Object[Tab] Do
		Row.Mark = True;	
	EndDo;
	
EndProcedure

&AtClient
Procedure ClearAllExecute(Command)
	
	Tab = StrReplace(Items.Pages.CurrentPage.Name, "Page", "");
	
	For Each Row In Object[Tab] Do
		Row.Mark = False;	
	EndDo;
	
EndProcedure

&AtClient
Procedure Complete(Command)
	CompleteAtServer();
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure FormManagment()
	
	Items.PageSalesOrders.Visible = Object.SalesOrders.Count();
	Items.PagePurchaseOrders.Visible = Object.PurchaseOrders.Count();
	Items.PageProductionOrders.Visible = Object.ProductionOrders.Count();
	Items.PageWorkOrders.Visible = Object.WorkOrders.Count();

	ThereAreOrders = Object.SalesOrders.Count() 
		Or Object.PurchaseOrders.Count()
		Or Object.ProductionOrders.Count()
		OR Object.WorkOrders.Count();
		
	Items.DecorationAllOrdersClosed.Visible = Not ThereAreOrders;
	Items.CloseOrders.Visible = ThereAreOrders;
	
EndProcedure

&AtServer
Procedure CompleteAtServer()
	
	DataProcessorObject = FormAttributeToValue("Object");
	DataProcessorObject.CloseOrders();
	ValueToFormAttribute(DataProcessorObject, "Object");
	
EndProcedure

#EndRegion
