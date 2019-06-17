
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	PresentationCurrency = Constants.PresentationCurrency.Get();
	
	KeyDataOnChange();
	
	DriveClientServer.SetPictureForComment(Items.Additionally, Object.Comment);
	
	// StandardSubsystems.ObjectVersioning
	ObjectVersioning.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.ObjectVersioning
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisObject, Items.ImportantCommandsGroup);
	// End StandardSubsystems.Printing
	
	// StandardSubsystems.Properties
	PropertiesManagement.OnCreateAtServer(ThisObject, , "AdditionalAttributesGroup");
	// End StandardSubsystems.Properties
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
		
	// StandardSubsystems.Properties
	If PropertiesManagementClient.ProcessAlerts(ThisObject, EventName, Parameter) Then
		UpdateAdditionalAttributesItems();
	EndIf;
	// End StandardSubsystems.Properties
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	ClosingDates.ObjectOnReadAtServer(ThisObject, CurrentObject);
	
	// StandardSubsystems.Properties
	PropertiesManagement.OnReadAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.Properties
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	// StandardSubsystems.PerformanceMeasurement
	PerformanceEstimationClientServer.StartTimeMeasurement("DocumentForeignCurrencyExchangePosting");
	// StandardSubsystems.PerformanceMeasurement
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	// StandardSubsystems.Properties
	PropertiesManagement.BeforeWriteAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.Properties
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	// StandardSubsystems.Properties
	PropertiesManagement.FillCheckProcessing(ThisObject, Cancel, CheckedAttributes);
	// End StandardSubsystems.Properties
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure DateOnChange(Item)
	KeyDataOnChange();
EndProcedure

&AtClient
Procedure CompanyOnChange(Item)
	
	// Company change event data processor.
	Object.Number = "";
	
EndProcedure

&AtClient
Procedure FromAccountOnChange(Item)
	FromAccountOnChangeAtServer();
EndProcedure

&AtClient
Procedure ToAccountOnChange(Item)
	ToAccountOnChangeAtServer();
EndProcedure

&AtClient
Procedure BankChargeOnChange(Item)
	BankChargeOnChangeAtServer();
EndProcedure

&AtClient
Procedure BankFeeValueOnChange(Item)
	CalculateData();
EndProcedure

&AtClient
Procedure DocumentAmountOnChange(Item)
	CalculateData();
EndProcedure

&AtClient
Procedure FromAccountExchangeRateOnChange(Item)
	
	CalculateData();
	
EndProcedure

&AtClient
Procedure FromAccountMultiplicityOnChange(Item)
	
	CalculateData();
	
EndProcedure

&AtClient
Procedure ToAccountExchangeRateOnChange(Item)
	
	CalculateData();
	
EndProcedure

&AtClient
Procedure ToAccountMultiplicityOnChange(Item)
	
	CalculateData();
	
EndProcedure

&AtClient
Procedure CommentOnChange(Item)
	
	AttachIdleHandler("Attachable_SetPictureForComment", 0.5, True);
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure ToAccountOnChangeAtServer()
	
	Object.ToAccountCurrency = CommonUse.GetAttributeValue(Object.ToAccount, "CashCurrency");
	KeyDataOnChange();
	
EndProcedure

&AtServer
Procedure FromAccountOnChangeAtServer()
	
	Object.FromAccountCurrency = CommonUse.GetAttributeValue(Object.FromAccount, "CashCurrency");
	KeyDataOnChange();
	
EndProcedure

&AtServer
Procedure BankChargeOnChangeAtServer()
	
	Object.BankChargeItem	= Object.BankCharge.Item;
	Object.BankFeeValue		= Object.BankCharge.Value;
	
	KeyDataOnChange();
	
EndProcedure

&AtServer
Procedure SetVisibilityItems()
	
	BankChargeType = CommonUse.GetAttributeValue(Object.BankCharge, "ChargeType");
	SpecialExchangeRate = BankChargeType = Enums.ChargeMethod.SpecialExchangeRate;
	
	SendingExchangeRatesIsVisible	= ValueIsFilled(Object.FromAccount) AND (Object.FromAccountCurrency <> PresentationCurrency);
	ReceivingExchangeRatesIsVisible	= ValueIsFilled(Object.ToAccount) AND (Object.ToAccountCurrency <> PresentationCurrency);
	
	Items.BankFeeValue.Visible	= NOT SpecialExchangeRate;
	Items.FeeGroup.Visible		= NOT BankChargeType = Enums.ChargeMethod.Amount AND PresentationCurrency <> Object.FromAccountCurrency;
	
	Items.FromAccountExchangeRateGroup.Visible				= SendingExchangeRatesIsVisible AND SpecialExchangeRate;
	Items.FromAccountCentralBankExchangeRateGroup.Visible	= SendingExchangeRatesIsVisible;
	
	Items.ToAccountExchangeRateGroup.Visible			= ReceivingExchangeRatesIsVisible AND SpecialExchangeRate;
	Items.ToAccountCentralBankExchangeRateGroup.Visible	= ReceivingExchangeRatesIsVisible;
	
EndProcedure

&AtServer
Procedure CalculateData()
	
	If NOT (ValueIsFilled(Object.BankCharge)
		AND ValueIsFilled(Object.ToAccount)
		AND ValueIsFilled(Object.FromAccount)
		AND ValueIsFilled(Object.DocumentAmount)) Then
		Return;
	EndIf;
	
	If PresentationCurrency = Object.FromAccountCurrency Then
		Object.FromAccountExchangeRate = 1;
		Object.FromAccountMultiplicity = 1;
	EndIf;
	
	If PresentationCurrency = Object.ToAccountCurrency Then
		Object.ToAccountExchangeRate = 1;
		Object.ToAccountMultiplicity = 1;
	EndIf;
	
	If Object.FromAccountExchangeRate = 0 Then
		Object.FromAccountExchangeRate = 1;
	EndIf;
	
	If Object.FromAccountMultiplicity = 0 Then
		Object.FromAccountMultiplicity = 1;
	EndIf;
	
	If Object.ToAccountExchangeRate = 0 Then
		Object.ToAccountExchangeRate = 1;
	EndIf;
	
	If Object.ToAccountMultiplicity = 0 Then
		Object.ToAccountMultiplicity = 1;
	EndIf;
	
	CalculatedData = Documents.ForeignCurrencyExchange.GetCalculatedData(Object);
	
	FillPropertyValues(ThisObject, CalculatedData);
	
EndProcedure

&AtServer
Procedure KeyDataOnChange()
	
	If ValueIsFilled(Object.ToAccount)
		AND ValueIsFilled(Object.ToAccountCurrency)
		AND Object.ToAccountCurrency = Object.FromAccountCurrency Then
		CommonUseClientServer.MessageToUser(
			NStr("en = 'Please, select accounts of different currencies'"),,
			"ToAccount",
			"Object");
	EndIf;
	
	AmountTitlePattern = NStr("en = 'Amount %1'");
	
	Items.SendingAmout.Title = StringFunctionsClientServer.SubstituteParametersInString(
									AmountTitlePattern,
									"(" + Object.FromAccountCurrency + ")");
								
	Items.SendingAmoutCurrency.Title = StringFunctionsClientServer.SubstituteParametersInString(
									AmountTitlePattern,
									"(" + PresentationCurrency + ")");

	Items.ReceivingAmountCurrency.Title = StringFunctionsClientServer.SubstituteParametersInString(
									AmountTitlePattern,
									"(" + Object.ToAccountCurrency + ")");
									
	Items.ReceivingAmount.Title = Items.SendingAmoutCurrency.Title;
	
	CalculateData();
	SetVisibilityItems();

EndProcedure

#EndRegion

#Region LibrariesHandlers

&AtClient
Procedure Attachable_SetPictureForComment()
	
	DriveClientServer.SetPictureForComment(Items.Additionally, Object.Comment);
	
EndProcedure

// StandardSubsystems.AdditionalReportsAndDataProcessors
&AtClient
Procedure Attachable_ExecuteAssignedCommand(Command)
	If Not AdditionalReportsAndDataProcessorsClient.ExecuteAllocatedCommandAtClient(ThisObject, Command.Name) Then
		ExecutionResult = Undefined;
		AdditionalReportsAndProcessingsExecuteAllocatedCommandAtServer(Command.Name, ExecutionResult);
		AdditionalReportsAndDataProcessorsClient.ShowCommandExecutionResult(ThisObject, ExecutionResult);
	EndIf;
EndProcedure

&AtServer
Procedure AdditionalReportsAndProcessingsExecuteAllocatedCommandAtServer(ItemName, ExecutionResult)
	AdditionalReportsAndDataProcessors.ExecuteAllocatedCommandAtServer(ThisObject, ItemName, ExecutionResult);
EndProcedure
// End StandardSubsystems.AdditionalReportsAndDataProcessors

// StandardSubsystems.Printing
&AtClient
Procedure Attachable_ExecutePrintCommand(Command)
	PrintManagementClient.ExecuteConnectedPrintCommand(Command, ThisObject, Object);
EndProcedure

// End StandardSubsystems.Printing

// StandardSubsystems.Properties
&AtClient
Procedure Attachable_EditContentOfProperties()
	
	PropertiesManagementClient.EditContentOfProperties(ThisObject, Object.Ref);
	
EndProcedure

&AtServer
Procedure UpdateAdditionalAttributesItems()
	
	PropertiesManagement.UpdateAdditionalAttributesItems(ThisObject);
	
EndProcedure
// End StandardSubsystems.Properties

#EndRegion
