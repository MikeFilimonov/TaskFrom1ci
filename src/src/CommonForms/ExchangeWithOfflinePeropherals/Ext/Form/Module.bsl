
#Region ProcedureFormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Query = New Query(
	"SELECT
	|	CatalogPeripherals.Ref AS Device,
	|	CatalogPeripherals.EquipmentType AS EquipmentType
	|FROM
	|	Catalog.Peripherals AS CatalogPeripherals
	|		INNER JOIN Catalog.CashRegisters AS CashRegisters
	|		ON (CashRegisters.Peripherals = CatalogPeripherals.Ref)
	|WHERE
	|	CatalogPeripherals.EquipmentType = VALUE(Enum.PeripheralTypes.CashRegistersOffline)
	|	AND CatalogPeripherals.ExchangeRule <> VALUE(Catalog.ExchangeWithOfflinePeripheralsRules.EmptyRef)
	|	AND CatalogPeripherals.DeviceIsInUse
	|
	|UNION ALL
	|
	|SELECT
	|	CatalogPeripherals.Ref,
	|	CatalogPeripherals.EquipmentType
	|FROM
	|	Catalog.Peripherals AS CatalogPeripherals
	|WHERE
	|	CatalogPeripherals.EquipmentType = VALUE(Enum.PeripheralTypes.LabelsPrintingScales)
	|	AND CatalogPeripherals.ExchangeRule <> VALUE(Catalog.ExchangeWithOfflinePeripheralsRules.EmptyRef)
	|	AND CatalogPeripherals.DeviceIsInUse");
	
	Query.SetParameter("CurrentWorksPlace", Parameters.Workplace);
	
	Result = Query.Execute();
	Selection = Result.Select();
	
	While Selection.Next() Do
		
		NewRow = Equipment.Add();
		NewRow.ExecuteExchange         = True;
		NewRow.Device                  = Selection.Device;
		NewRow.EquipmentType           = Selection.EquipmentType;
		NewRow.ExportStatus          = NStr("en = '<Export was not made>'");
		NewRow.ImportingPictureIndex   = 1;
		NewRow.ExportingPictureIndex = 1;
		
		If NewRow.EquipmentType = Enums.PeripheralTypes.LabelsPrintingScales Then
			NewRow.ImportStatus = NStr("en = '<Not needed>'");
		Else
			NewRow.ImportStatus = NStr("en = '<Import was not made>'");
		EndIf;
		
	EndDo;
	
	State = "";
	
	Items.Start.Enabled              = True;
	Items.Complete.Enabled           = False;
	
EndProcedure

#EndRegion

#Region ProcedureCommandHandlers

&AtClient
Procedure Start(Command)
	
	ClearMessages();
	
	If Not ValueIsFilled(ExchangePeriodicity) Then
		CommonUseClientServer.MessageToUser(NStr("en = 'Frequency of exchange with equipment is not specified'"),,"ExchangePeriodicity");
		Return;
	EndIf;
	
	If Not IsEquipmentForExchange() Then
		CommonUseClientServer.MessageToUser(NStr("en = 'Equipment for exchange is not selected'"),,"Equipment");
		Return;
	EndIf;
	
	Items.ExchangePeriodicity.Enabled              = False;
	Items.EquipmentExecuteExchange.Enabled         = False;
	Items.EquipmentCheckAll.Enabled                = False;
	Items.EquipmentUncheckAll.Enabled              = False;
	Items.EquipmentContextMenuCheckAll.Enabled     = False;
	Items.EquipmentContextMenuUncheckAll.Enabled   = False;
	
	Items.Start.Enabled              = False;
	Items.Complete.Enabled           = True;
	
	State = NStr("en = 'Exchange with the peripherals is being performed...'");
	
	AttachIdleHandler("ExchangeExpectationsHandler", ExchangePeriodicity * 60, False);
	
	ExchangeInProgress = True;
	
EndProcedure

&AtClient
Procedure Complete(Command)
	
	Items.ExchangePeriodicity.Enabled             = True;
	Items.EquipmentExecuteExchange.Enabled        = True;
	Items.EquipmentCheckAll.Enabled               = True;
	Items.EquipmentUncheckAll.Enabled             = True;
	Items.EquipmentContextMenuCheckAll.Enabled    = True;
	Items.EquipmentContextMenuUncheckAll.Enabled  = True;
	
	Items.Start.Enabled              = True;
	Items.Complete.Enabled           = False;
	
	State = NStr("en = 'Exchange completed.'");
	
	DetachIdleHandler("ExchangeExpectationsHandler");
	
	ExchangeInProgress = False;
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	If ExchangeInProgress Then
		
		If Exit Then
			WarningText = NStr("en = 'Exchange will be terminated'");
		Else
			ShowMessageBox(, NStr("en = 'After the form is closed, exchange with equipment will not be performed.'"));
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CheckAll(Command)
	SetCheckboxesOnServer();
EndProcedure

&AtClient
Procedure UncheckAll(Command)
	RemoveCheckboxesOnServer();
EndProcedure

&AtClient
Procedure ExecuteNow(Command)
	
	State = NStr("en = 'Exchange with the peripherals is being performed...'");
	RunExchange();
	State = NStr("en = 'Exchange completed.'");
	
EndProcedure

#EndRegion

#Region Other

&AtClient
Procedure RunExchange()
	
	For Each TSRow In Equipment Do
		
		If Not TSRow.ExecuteExchange Then
			Continue;
		EndIf;
		
		DeviceArray = New Array;
		DeviceArray.Add(TSRow.Device);
		
		// Data export
		MessageText = "";
		NotificationOnImplementation = New NotifyDescription(
			"ExecuteExchangeEnd",
			ThisObject,
			New Structure ("MessageText, TSRow, DeviceArray", MessageText, TSRow, DeviceArray)
		);
		
		PeripheralsOfflineClient.AsynchronousExportProductsInEquipmentOffline(TSRow.EquipmentType, DeviceArray, MessageText, False, NotificationOnImplementation, True);
		
	EndDo;
	
EndProcedure

&AtClient
Procedure ExecuteExchangeEnd(Result, Parameters) Export
	
	Parameters.TSRow.ExportStatus = Parameters.MessageText;
	Parameters.TSRow.ExportingPictureIndex = ?(Result, 1, 0);
	Parameters.TSRow.ExportEndDate = CurrentDate();
	
	// Data Import
	If Parameters.TSRow.EquipmentType = PredefinedValue("Enum.PeripheralTypes.CashRegistersOffline") Then
		
		MessageText = "";
		
		NotificationOnImplementation = New NotifyDescription(
			"ExecuteImportEnd",
			ThisObject,
			Parameters
		);
		
		PeripheralsOfflineClient.AsynchronousImportReportAboutRetailSales(Parameters.DeviceArray,,, NotificationOnImplementation);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ExecuteImportEnd(Result, Parameters) Export
	
	Parameters.TSRow.ExportStatus = Parameters.MessageText;
	Parameters.TSRow.ExportingPictureIndex = ?(Result, 1, 0);
	Parameters.TSRow.ExportEndDate = CurrentDate();
	
EndProcedure

&AtClient
Procedure ExchangeExpectationsHandler()
	
	RunExchange();
	
	DetachIdleHandler("ExchangeExpectationsHandler");
	AttachIdleHandler("ExchangeExpectationsHandler", ExchangePeriodicity * 60, False);
	
EndProcedure

&AtServer
Procedure SetCheckboxesOnServer()
	
	For Each TSRow In Equipment Do
		TSRow.ExecuteExchange = True;
	EndDo;
	
EndProcedure

&AtServer
Procedure RemoveCheckboxesOnServer()
	
	For Each TSRow In Equipment Do
		TSRow.ExecuteExchange = False;
	EndDo;
	
EndProcedure

&AtServer
Function IsEquipmentForExchange()
	
	Return Equipment.FindRows(New Structure("ExecuteExchange", True)).Count() > 0;
	
EndFunction

#EndRegion
