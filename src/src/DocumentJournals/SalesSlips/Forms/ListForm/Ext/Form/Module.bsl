// Procedure - form event handler "OnLoadDataFromSettingsAtServer".
//
&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	CashCR = Settings.Get("CashCR");
	CurrentSessionOnly = Settings.Get("CurrentSessionOnly");
	
	UpdateCashCRSessionStateAtServer(CashCR);
	SetDynamicListsFilter();
	
	Items.CashDeposition.Visible = Not CashCR.UseWithoutEquipmentConnection;
	Items.Withdrawal.Visible = Not CashCR.UseWithoutEquipmentConnection;
	
EndProcedure

#Region ProcedureFormFieldEventHandlers

// Procedure sets filter of dynamic form lists.
//
&AtServer
Procedure SetDynamicListsFilter()
	
	DriveClientServer.SetListFilterItem(SalesSlips, "CashCR", CashCR, ValueIsFilled(CashCR), DataCompositionComparisonType.Equal);
	DriveClientServer.SetListFilterItem(SalesSlips, "CashCRSession", CurrentCashCRSession, CurrentSessionOnly, DataCompositionComparisonType.Equal);
	
EndProcedure

// Procedure - event handler "OnChange" of field "CashCR".
//
&AtServer
Procedure CashCRFilterOnChangeAtServer()
	
	UpdateCashCRSessionStateAtServer(CashCR);
	SetDynamicListsFilter();
	Items.CashDeposition.Visible = Not CashCR.UseWithoutEquipmentConnection;
	Items.Withdrawal.Visible = Not CashCR.UseWithoutEquipmentConnection;
	
EndProcedure

// Procedure - event handler "OnChange" of field "CashCR" on server.
//
&AtClient
Procedure CashCRFilterOnChange(Item)
	
	CashCRFilterOnChangeAtServer();
	
EndProcedure

// Function opens the cash session on server.
//
&AtServer
Function CashCRSessionOpenAtServer(CashCR, ErrorDescription = "")
	
	Return Documents.ShiftClosure.CashCRSessionOpen(CashCR, ErrorDescription);
	
EndFunction

// Procedure closes the cash session on server.
//
&AtServer
Function CloseCashCRSessionAtServer(CashCR, ErrorDescription = "")
	
	Return Documents.ShiftClosure.CloseCashCRSessionExecuteArchiving(CashCR, ErrorDescription);
	
EndFunction

// It is required to call the procedure from client when opening the cash session
&AtServer
Procedure UpdateCashCRSessionStateAndSetDynamicListsFilter(CashCR)
	
	UpdateCashCRSessionStateAtServer(CashCR);
	
	SetDynamicListsFilter();
	
EndProcedure

// Procedure - command handler "OpenCashCRSession".
//
&AtClient
Procedure CashCRSessionOpen(Command)
	
	ClearMessages();
	
	If Not ValueIsFilled(CashCR) Then
		Return;
	EndIf;
	
	Result = False;
	
	If EquipmentManagerClient.RefreshClientWorkplace() Then
		
		// Device connection
		CashRegistersSettings = DriveReUse.CashRegistersGetParameters(CashCR);
		DeviceIdentifier = CashRegistersSettings.DeviceIdentifier;
		UseWithoutEquipmentConnection = CashRegistersSettings.UseWithoutEquipmentConnection;
		
		If DeviceIdentifier <> Undefined OR UseWithoutEquipmentConnection Then
			
			ErrorDescription = "";
			
			If Not UseWithoutEquipmentConnection Then
				
				Result = EquipmentManagerClient.ConnectEquipmentByID(
					UUID,
					DeviceIdentifier,
					ErrorDescription
				);
				
			EndIf;
			
			If Result OR UseWithoutEquipmentConnection Then
				
				If Not UseWithoutEquipmentConnection Then
					
					InputParameters   = Undefined;
					Output_Parameters = Undefined;
					
					// Open session on fiscal register
					Result = EquipmentManagerClient.RunCommand(
						DeviceIdentifier,
						"OpenDay",
						InputParameters, 
						Output_Parameters
					);
					
				EndIf;
				
				If Result OR UseWithoutEquipmentConnection Then
					
					Result = CashCRSessionOpenAtServer(CashCR, ErrorDescription);
					
					If Not Result Then
						
						MessageText = NStr("en = 'An error occurred when opening the session.
						                   |Session is not opened.
						                   |Additional
						                   |description: %AdditionalDetails%'");
						MessageText = StrReplace(MessageText,"%AdditionalDetails%",
							?(UseWithoutEquipmentConnection, ErrorDescription, Output_Parameters[1]));
						CommonUseClientServer.MessageToUser(MessageText);
						
					EndIf;
					
				Else
					
					MessageText = NStr("en = 'An error occurred when opening the session.
					                   |Session is not opened.
					                   |Additional
					                   |description: %AdditionalDetails%'");
					MessageText = StrReplace(MessageText,"%AdditionalDetails%",ErrorDescription);
					CommonUseClientServer.MessageToUser(MessageText);
					
				EndIf;
				
				If Not UseWithoutEquipmentConnection Then
					
					EquipmentManagerClient.DisableEquipmentById(
						UUID,
						DeviceIdentifier
					);
					
				EndIf;
				
			Else
				
				MessageText = NStr("en = 'An error occurred when connecting the device.
				                   |Session is not opened on the fiscal register.
				                   |Additional
				                   |description: %AdditionalDetails%'");
				MessageText = StrReplace(MessageText, "%AdditionalDetails%", ErrorDescription);
				CommonUseClientServer.MessageToUser(MessageText);
				
			EndIf;
			
		EndIf;
		
	Else
		
		MessageText = NStr("en = 'First, you need to select the work place of the current session peripherals.'"
		);
		CommonUseClientServer.MessageToUser(MessageText);
		
	EndIf;
	
	UpdateCashCRSessionStateAndSetDynamicListsFilter(CashCR);
	
EndProcedure

// Function verifies the existence of issued receipts during the session.
//
&AtServer
Function IssuedReceiptsExist(CashCR)
	
	StructureStateCashCRSession = Documents.ShiftClosure.GetCashCRSessionStatus(CashCR);
	
	If StructureStateCashCRSession.CashCRSessionStatus <> Enums.ShiftClosureStatus.IsOpen Then
		Return False;
	EndIf;
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	SalesSlipInventory.Ref AS CountRecipies
	|FROM
	|	(SELECT
	|		SalesSlipInventory.Ref AS Ref
	|	FROM
	|		Document.SalesSlip.Inventory AS SalesSlipInventory
	|	WHERE
	|		SalesSlipInventory.Ref.CashCRSession = &CashCRSession
	|		AND SalesSlipInventory.Ref.Posted
	|		AND SalesSlipInventory.Ref.SalesSlipNumber > 0
	|		AND (NOT SalesSlipInventory.Ref.Archival)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		SalesSlipInventory.Ref
	|	FROM
	|		Document.ProductReturn.Inventory AS SalesSlipInventory
	|	WHERE
	|		SalesSlipInventory.Ref.CashCRSession = &CashCRSession
	|		AND SalesSlipInventory.Ref.Posted
	|		AND SalesSlipInventory.Ref.SalesSlipNumber > 0
	|		AND (NOT SalesSlipInventory.Ref.Archival)) AS SalesSlipInventory";
	
	Query.SetParameter("CashCRSession", StructureStateCashCRSession.CashCRSession);
	
	Result = Query.Execute();
	
	Return Not Result.IsEmpty();
	
EndFunction

// Procedure - command handler "CloseCashCRSession".
//
&AtClient
Procedure CloseCashCRSession(Command)
	
	ClearMessages();
	
	If Not ValueIsFilled(CashCR) Then
		Return;
	EndIf;
	
	Result = False;
	
	If Not IssuedReceiptsExist(CashCR) Then
		
		ErrorDescription = "";
		
		DocumentArray = CloseCashCRSessionAtServer(CashCR, ErrorDescription);
		
		If ValueIsFilled(ErrorDescription) Then
			MessageText = NStr("en = 'Session is closed on the fiscal register, but errors occurred when generating the retail sales report.
			                   |Additional
			                   |description: %AdditionalDetails%'");
			MessageText = StrReplace(MessageText, "%AdditionalDetails%", ErrorDescription);
			CommonUseClientServer.MessageToUser(MessageText);
		EndIf;
		
		// Show all resulting documents to user.
		For Each Document In DocumentArray Do
			
			OpenForm("Document.ShiftClosure.ObjectForm", New Structure("Key", Document));
			
		EndDo;
		
	ElsIf EquipmentManagerClient.RefreshClientWorkplace() Then
		
		// Device connection
		CashRegistersSettings = DriveReUse.CashRegistersGetParameters(CashCR);
		DeviceIdentifier = CashRegistersSettings.DeviceIdentifier;
		UseWithoutEquipmentConnection = CashRegistersSettings.UseWithoutEquipmentConnection;
	
		If DeviceIdentifier <> Undefined OR UseWithoutEquipmentConnection Then
			
			ErrorDescription = "";
			
			If Not UseWithoutEquipmentConnection Then
				
				Result = EquipmentManagerClient.ConnectEquipmentByID(
					UUID,
					DeviceIdentifier,
					ErrorDescription
				);
				
			EndIf;
			
			If Result OR UseWithoutEquipmentConnection Then
				
				If Not UseWithoutEquipmentConnection Then
					InputParameters  = Undefined;
					Output_Parameters = Undefined;
					
					Result = EquipmentManagerClient.RunCommand(
						DeviceIdentifier,
						"PrintZReport",
						InputParameters,
						Output_Parameters
					);
				EndIf;
				
				If Not Result AND Not UseWithoutEquipmentConnection Then
					
					MessageText = NStr("en = 'Error occurred when closing the session on the fiscal register.
					                   |""%ErrorDescription%""
					                   |Report on fiscal register is not formed.'");
					MessageText = StrReplace(MessageText,"%ErrorDescription%",Output_Parameters[1]);
					CommonUseClientServer.MessageToUser(MessageText);
					
				Else
					
					DocumentArray = CloseCashCRSessionAtServer(CashCR, ErrorDescription);
					
					If ValueIsFilled(ErrorDescription)
					   AND UseWithoutEquipmentConnection Then
						
						CommonUseClientServer.MessageToUser(ErrorDescription);
						
					ElsIf ValueIsFilled(ErrorDescription)
						 AND Not UseWithoutEquipmentConnection Then
						
						MessageText = NStr("en = 'Session is closed on the fiscal register, but errors occurred when generating the retail sales report.
						                   |Additional description:
						                   |%AdditionalDetails%'");
						MessageText = StrReplace(MessageText, "%AdditionalDetails%", ErrorDescription);
						CommonUseClientServer.MessageToUser(MessageText);
						
					EndIf;
					
					// Show all resulting documents to user.
					For Each Document In DocumentArray Do
						
						OpenForm("Document.ShiftClosure.ObjectForm", New Structure("Key", Document));
						
					EndDo;
					
				EndIf;
				
				If Not UseWithoutEquipmentConnection Then
					
					EquipmentManagerClient.DisableEquipmentById(
						UUID,
						DeviceIdentifier
					);
					
				EndIf;
				
			Else
				
				MessageText = NStr("en = 'An error occurred when connecting the device.
				                   |Report is not printed and session is not closed on the fiscal register.
				                   |Additional description:
				                   |%AdditionalDetails%'");
				MessageText = StrReplace(MessageText, "%AdditionalDetails%", ErrorDescription);
				CommonUseClientServer.MessageToUser(MessageText);
				
			EndIf;
			
		EndIf;
		
	Else
		
		MessageText = NStr("en = 'First, you need to select the work place of the current session peripherals.'"
		);
		CommonUseClientServer.MessageToUser(MessageText);
		
	EndIf;
	
	UpdateCashCRSessionStateAndSetDynamicListsFilter(CashCR);
	
	Notify("RefreshFormsAfterZReportIsDone");
	
EndProcedure

// Procedure - command handler "FundsIntroduction".
//
&AtClient
Procedure CashDeposition(Command)
	
	If EquipmentManagerClient.RefreshClientWorkplace() Then
		
		InAmount = 0;
		
		WindowTitle = NStr("en = 'Deposit amount'") + ", " + "%Currency%";
		WindowTitle = StrReplace(
			WindowTitle,
			"%Currency%",
			StructureStateCashCRSession.DocumentCurrencyPresentation
		);
		
		ShowInputNumber(New NotifyDescription("FundsIntroductionEnd", ThisObject, New Structure("InAmount", InAmount)), InAmount, WindowTitle, 15, 2);
		
	Else
		
		MessageText = NStr("en = 'First, you need to select the work place of the current session peripherals.'"
		);
		CommonUseClientServer.MessageToUser(MessageText);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure FundsIntroductionEnd(Result1, AdditionalParameters) Export
	
	InAmount = ?(Result1 = Undefined, AdditionalParameters.InAmount, Result1);
	
	If (Result1 <> Undefined) Then
		
		// Device connection
		CashRegistersSettings = DriveReUse.CashRegistersGetParameters(CashCR);
		DeviceIdentifier = CashRegistersSettings.DeviceIdentifier;
		UseWithoutEquipmentConnection = CashRegistersSettings.UseWithoutEquipmentConnection;
		
		If ValueIsFilled(DeviceIdentifier) Then
			FundsIntroductionFiscalRegisterConnectionsEnd(DeviceIdentifier, InAmount);
		Else
			NotifyDescription = New NotifyDescription("FundsIntroductionFiscalRegisterConnectionsEnd", ThisObject, InAmount);
			EquipmentManagerClient.OfferSelectDevice(NotifyDescription, "FiscalRegister",
				NStr("en = 'Select a fiscal data recorder'"), NStr("en = 'Fiscal data recorder is not connected.'"));
		EndIf;
		
	EndIf;

EndProcedure

&AtClient
Procedure FundsIntroductionFiscalRegisterConnectionsEnd(DeviceIdentifier, Parameters) Export
	
	InAmount = Parameters;
	ErrorDescription = "";
	
	If DeviceIdentifier <> Undefined Then
		
		// Connect FR
		Result = EquipmentManagerClient.ConnectEquipmentByID(
			UUID,
			DeviceIdentifier,
			ErrorDescription
		);
		
		If Result Then
			
			// Prepare data
			InputParameters  = New Array();
			Output_Parameters = Undefined;
			
			InputParameters.Add(1);
			InputParameters.Add(InAmount);
			
			// Print receipt.
			Result = EquipmentManagerClient.RunCommand(
			DeviceIdentifier,
			"Encash",
			InputParameters,
			Output_Parameters
			);
			
			If Not Result Then
				
				MessageText = NStr("en = 'When printing a receipt, an error occurred.
				                   |Receipt is not printed on the fiscal register.
				                   |Additional description:
				                   |%AdditionalDetails%'");
				MessageText = StrReplace(MessageText,"%AdditionalDetails%",Output_Parameters[1]);
				CommonUseClientServer.MessageToUser(MessageText);
				
			EndIf;
			
			// Disconnect FR
			EquipmentManagerClient.DisableEquipmentById(UUID, DeviceIdentifier);
			
		Else
			
			MessageText = NStr("en = 'An error occurred when connecting the device.
			                   |Receipt is not printed on the fiscal register.
			                   |Additional description:
			                   |%AdditionalDetails%'");
			MessageText = StrReplace(MessageText, "%AdditionalDetails%", ErrorDescription);
			CommonUseClientServer.MessageToUser(MessageText);
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Procedure - command handler "FundsWithdrawal".
//
&AtClient
Procedure Withdrawal(Command)
	
	If EquipmentManagerClient.RefreshClientWorkplace() Then
		
		WithdrawnAmount = 0;
		
		WindowTitle = NStr("en = 'Withdrawal amount'") + ", " + "%Currency%";
		WindowTitle = StrReplace(WindowTitle,"%Currency%",StructureStateCashCRSession.DocumentCurrencyPresentation);
		
		ShowInputNumber(New NotifyDescription("CashWithdrawalEnd", ThisObject, New Structure("WithdrawnAmount", WithdrawnAmount)), WithdrawnAmount, WindowTitle, 15, 2);
		
	Else
		
		MessageText = NStr("en = 'First, you need to select the work place of the current session peripherals.'");
		CommonUseClientServer.MessageToUser(MessageText);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CashWithdrawalEnd(Result1, AdditionalParameters) Export
	
	WithdrawnAmount = ?(Result1 = Undefined, AdditionalParameters.WithdrawnAmount, Result1);
	
	If (Result1 <> Undefined) Then
		
		ErrorDescription = "";
		
		// Device connection
		CashRegistersSettings = DriveReUse.CashRegistersGetParameters(CashCR);
		DeviceIdentifier = CashRegistersSettings.DeviceIdentifier;
		UseWithoutEquipmentConnection = CashRegistersSettings.UseWithoutEquipmentConnection;
		
		If ValueIsFilled(DeviceIdentifier) Then
			CashWithdrawalFiscalRegisterConnectionsEnd(DeviceIdentifier, WithdrawnAmount);
		Else
			NotifyDescription = New NotifyDescription("CashWithdrawalFiscalRegisterConnectionsEnd", ThisObject, WithdrawnAmount);
			EquipmentManagerClient.OfferSelectDevice(NotifyDescription, "FiscalRegister",
				NStr("en = 'Select a fiscal data recorder'"), NStr("en = 'Fiscal data recorder is not connected.'"));
		EndIf;
	
	EndIf;

EndProcedure

&AtClient
Procedure CashWithdrawalFiscalRegisterConnectionsEnd(DeviceIdentifier, Parameters) Export
	
	WithdrawnAmount = Parameters;
	ErrorDescription = "";
	
	If DeviceIdentifier <> Undefined Then
			
			// Connect FR
			Result = EquipmentManagerClient.ConnectEquipmentByID(
			UUID,
			DeviceIdentifier,
			ErrorDescription
			);
			
			If Result Then
				
				// Prepare data
				InputParameters  = New Array();
				Output_Parameters = Undefined;
				
				InputParameters.Add(0);
				InputParameters.Add(WithdrawnAmount);
				
				// Print receipt.
				Result = EquipmentManagerClient.RunCommand(
					DeviceIdentifier,
					"Encash",
					InputParameters,
					Output_Parameters
				);
				
				If Not Result Then
					
					MessageText = NStr("en = 'When printing a receipt, an error occurred. Receipt is not printed on the fiscal register.
					                   |Additional description: %AdditionalDetails%'");
					MessageText = StrReplace(MessageText,"%AdditionalDetails%",Output_Parameters[1]);
					CommonUseClientServer.MessageToUser(MessageText);
					
				EndIf;
				
				// Disconnect FR
				EquipmentManagerClient.DisableEquipmentById(UUID, DeviceIdentifier);
				
			Else
				
				MessageText = NStr("en = 'An error occurred when connecting the device.
				                   |Receipt is not printed on the fiscal register.
				                   |Additional description:
				                   |%AdditionalDetails%'");
				MessageText = StrReplace(MessageText, "%AdditionalDetails%", ErrorDescription);
				CommonUseClientServer.MessageToUser(MessageText);
				
			EndIf;
			
		EndIf;
	
EndProcedure

// Function gets cash session state on server.
//
&AtServerNoContext
Function GetCashCRSessionStateAtServer(CashCR)
	
	Return Documents.ShiftClosure.GetCashCRSessionStatus(CashCR);
	
EndFunction

// Procedure updates cash session state on client.
//
&AtServer
Procedure UpdateCashCRSessionStateAtServer(CashCR)
	
	StructureStateCashCRSession = GetCashCRSessionStateAtServer(CashCR);
	If ValueIsFilled(StructureStateCashCRSession.CashCRSessionStatus) Then
		
		MessageText = NStr("en = 'Session No.%NumberOfSession%, Status: %SessionStatus% %ModifiedAt%, IN cash %CashInPettyCash% %Currency%'");
		MessageText = StrReplace(MessageText, "%NumberOfSession%", TrimAll(StructureStateCashCRSession.CashCRSessionNumber));
		MessageText = StrReplace(MessageText, "%SessionStatus%", StructureStateCashCRSession.CashCRSessionStatus);
		MessageText = StrReplace(MessageText, "%CashInPettyCash%", StructureStateCashCRSession.CashInPettyCash);
		MessageText = StrReplace(MessageText, "%Currency%", StructureStateCashCRSession.DocumentCurrencyPresentation);
		MessageText = StrReplace(MessageText, "%ModifiedAt%", Format(StructureStateCashCRSession.StatusModificationDate,"DF=dd.MM.yy HH:mm'"));
		
		StatusCashCRSession = MessageText;
		
	Else
		
		StatusCashCRSession = NStr("en = 'Shift is not opened.'");
		
	EndIf;
	
	// Form variable
	SessionIsOpen = StructureStateCashCRSession.SessionIsOpen;
	CurrentCashCRSession = StructureStateCashCRSession.CashCRSession;
	
	// Availability management.
	Items.DisableZReport.Visible		  = SessionIsOpen;
	Items.CashCRSessionOpen.Visible = Not SessionIsOpen AND ValueIsFilled(CashCR);
	
	Items.ReceiptsCRCreateReceipt.Enabled					= SessionIsOpen;
	Items.ReceiptsCRDocumentReturnSalesSlipCreateBasedOn.Enabled = SessionIsOpen;
	Items.SalesSlipsCopy.Enabled				= SessionIsOpen;
	Items.ContextMenuReceiptsCRCopy.Enabled = SessionIsOpen;
	
	Items.CashDeposition.Enabled = ValueIsFilled(CashCR);
	Items.Withdrawal.Enabled   = ValueIsFilled(CashCR);
	
EndProcedure

// Procedure - command handler "UpdateCashCRSessionState".
//
&AtClient
Procedure UpdateCashCRSessionState(Command)
	
	If Not ValueIsFilled(CashCR) Then
		Return;
	EndIf;
	
	UpdateCashCRSessionStateAndSetDynamicListsFilter(CashCR);
	
EndProcedure

// Procedure - command handler "OpenFiscalRegisterManagement".
//
&AtClient
Procedure OpenFiscalRegisterManagement(Command)
	
	OpenForm("Catalog.Peripherals.Form.CashRegisterShiftClosure");

EndProcedure

// Procedure - command handler "OpenPOSTerminalManagement".
//
&AtClient
Procedure OpenPOSTerminalManagement(Command)
	
	OpenForm("Catalog.Peripherals.Form.PaymentTerminalFunctions");

EndProcedure

// Procedure - form event handler "NotificationProcessing".
//
&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName  = "RefreshFormsAfterZReportIsDone" Then
		Items.SalesSlips.Refresh();
		UpdateCashCRSessionStateAndSetDynamicListsFilter(CashCR);
		ReceiptsCROnActivateRowAtClient();
	ElsIf EventName = "RefreshSalesSlipDocumentsListForm" Then
		Items.SalesSlips.Refresh();
		UpdateCashCRSessionStateAndSetDynamicListsFilter(CashCR);
		ReceiptsCROnActivateRowAtClient();
	ElsIf EventName = "RefreshFormsAfterClosingCashCRSession" Then
		Items.SalesSlips.Refresh();
		UpdateCashCRSessionStateAndSetDynamicListsFilter(CashCR);
		ReceiptsCROnActivateRowAtClient();
	EndIf;
	
EndProcedure

// Procedure is intended to handle the "OnActivateRow" event of the SalesSlips list
//
&AtClient
Procedure ReceiptsCROnActivateRowAtClient()
	
	If StructureStateCashCRSession = Undefined Then
		UpdateCashCRSessionStateAndSetDynamicListsFilter(CashCR);
	EndIf;
	
	CurrentData = Items.SalesSlips.CurrentData;
	If CurrentData <> Undefined Then
		
		If Not CurrentData.Property("RowGroup")
			AND ValueIsFilled(CurrentData.SalesSlipNumber)
			AND ValueIsFilled(StructureStateCashCRSession)
			AND CurrentData.CashCRSession = StructureStateCashCRSession.CashCRSession
			AND Not CurrentData.ThereIsBillForReturn
			AND SessionIsOpen
			AND CurrentData.Type <> Type("DocumentRef.ProductReturn") Then
			
			Items.ReceiptsCRDocumentReturnSalesSlipCreateBasedOn.Enabled = True;
			Items.ContextMenuReceiptsCRDocumentProductReturnCreateBasedOn.Enabled = True;
			
		Else
			
			Items.ReceiptsCRDocumentReturnSalesSlipCreateBasedOn.Enabled = False;
			Items.ContextMenuReceiptsCRDocumentProductReturnCreateBasedOn.Enabled = False;
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Procedure - event handler "OnActivateRow" of the SalesSlips list.
//
&AtClient
Procedure ReceiptsCROnActivateRow(Item)
	
	ReceiptsCROnActivateRowAtClient();
	
EndProcedure

// Procedure is intended to handle the "OnChangeAtServer" event of the CurrentSessionOnlyFilter flag on server
//
&AtServer
Procedure CurrentSessionOnlyFilterOnChangeAtServer()
	
	SetDynamicListsFilter();
	
EndProcedure

// Procedure - event handler "OnChange" of the CurrentSessionOnlyFilter flag.
//
&AtClient
Procedure CurrentSessionOnlyFilterOnChange(Item)

	CurrentSessionOnlyFilterOnChangeAtServer();

EndProcedure

// Procedure - command handler "CreateReceipt".
//
&AtClient
Procedure CreateReceipt(Command)
	
	If SessionIsOpen Then
		OpenParameters = New Structure("Basis", New Structure("CashCR", CashCR));
		OpenForm("Document.SalesSlip.ObjectForm", OpenParameters);
	EndIf;
	
EndProcedure

#Region PerformanceMeasurements

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	KeyOperation = "FormCreatingSalesSlip";
	PerformanceEstimationClientServer.StartTimeMeasurement(KeyOperation);
	
EndProcedure

&AtClient
Procedure ListBeforeRowChange(Item, Cancel)
	
	KeyOperation = "FormOpeningSalesSlip";
	PerformanceEstimationClientServer.StartTimeMeasurement(KeyOperation);
	
EndProcedure

#EndRegion

#EndRegion
