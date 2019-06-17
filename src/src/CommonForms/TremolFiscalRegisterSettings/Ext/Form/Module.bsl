#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skipping the initialization to guarantee that the form will be received if the AutoTest parameter is passed.
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;

	Parameters.Property("HardwareDriver",	HardwareDriver);
	Parameters.Property("ID",				ID);
	
	Title = NStr("en = 'Equipment:'") + Chars.NBSp  + String(ID);

	TextColor = StyleColors.FormTextColor;
	ErrorColor = StyleColors.NegativeTextColor;
	
	ListPort = Items.Port.ChoiceList;
	For Number = 1 To 64 Do
		ListPort.Add(Number, "COM" + Format(Number, "ND=2; NFD=0; NZ=0; NG=0"));
	EndDo;

	SpeedList = Items.Speed.ChoiceList;
	SpeedList.Add(2400,   "2400");
	SpeedList.Add(4800,   "4800");
	SpeedList.Add(9600,   "9600");
	SpeedList.Add(19200,  "19200");
	SpeedList.Add(38400,  "38400");
	SpeedList.Add(57600,  "57600");
	SpeedList.Add(115200, "115200");
	
	tempPort                       = Undefined;
	tempSpeed                      = Undefined;
	tempTimeout                    = Undefined;
	tempUserPassword               = Undefined;
	tempAdministratorPassword      = Undefined;
	TempCancelCheckOnConnect       = Undefined;
	tempPaymentDescription1        = Undefined;
	tempPaymentDescription2        = Undefined;
	tempSectionNumber              = Undefined;
	tempPartialCuttingSymbolCode   = Undefined;
	tempModel                      = Undefined;
	mVAT                           = Undefined;
	tempMoneyBox                   = Undefined;
	
	Parameters.Property("Port"                      , tempPort);
	Parameters.Property("Speed"                     , tempSpeed);
	Parameters.Property("Timeout"                   , tempTimeout);
	Parameters.Property("UserPassword"              , tempUserPassword);
	Parameters.Property("AdministratorPassword"     , tempAdministratorPassword);
	Parameters.Property("CancelCheckDuringConnect"  , TempCancelCheckOnConnect);
	Parameters.Property("PaymentDescription1"       , tempPaymentDescription1);
	Parameters.Property("PaymentDescription2"       , tempPaymentDescription2);
	Parameters.Property("SectionNumber"             , tempSectionNumber);
	Parameters.Property("PartialCuttingSymbolCode"  , tempPartialCuttingSymbolCode);
	Parameters.Property("Model"                     , tempModel);
	Parameters.Property("VAT"                       , mVAT);
	Parameters.Property("MoneyBox"                  , tempMoneyBox);
	Parameters.Property("GCPaymentCode"             , GCPaymentCode);

	Port                       = ?(tempPort                   	= Undefined,        1, tempPort);
	Speed                      = ?(tempSpeed                    = Undefined, 115200, tempSpeed);
	Timeout                    = ?(tempTimeout                  = Undefined,    150, tempTimeout);
	UserPassword               = ?(tempUserPassword             = Undefined,    "1", tempUserPassword);
	AdministratorPassword      = ?(tempAdministratorPassword    = Undefined,   "30", tempAdministratorPassword);
	CancelCheckDuringConnect   = ?(TempCancelCheckOnConnect     = Undefined,  False, TempCancelCheckOnConnect);
	PaymentDescription1        = ?(tempPaymentDescription1      = Undefined,     "", tempPaymentDescription1);
	PaymentDescription2        = ?(tempPaymentDescription2      = Undefined,     "", tempPaymentDescription2);
	SectionNumber              = ?(tempSectionNumber            = Undefined,      0, tempSectionNumber);
	PartialCuttingSymbolCode   = ?(tempPartialCuttingSymbolCode = Undefined,     22, tempPartialCuttingSymbolCode);
	Model                      = ?(tempModel                    = Undefined, Items.Model.ChoiceList[0], tempModel);
	MoneyBox                   = ?(tempMoneyBox                 = Undefined, False, tempMoneyBox); 

	If mVAT = Undefined Then
		VAT.Clear();
	ElsIf TypeOf(mVAT) = Type("Map") Then
		VAT.Clear();
		For Each KeyAndValue In mVAT Do
			NS          = VAT.Add();
			NS.Rate     = KeyAndValue.Value.Rate;
			NS.TaxGroup = KeyAndValue.Value.TaxGroup; 
		EndDo;
		VAT.Sort("rate Desc");
	EndIf;
	
	Items.DeviceTest.Visible	= (SessionParameters.ClientWorkplace = ID.Workplace);
	Items.SetupDriver.Visible	= (SessionParameters.ClientWorkplace = ID.Workplace);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)	
	UpdateInformationAboutDriver();	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure WriteAndClose(Command)
	
	VATMapping = VATSettings(VAT);
	
	Parameters.SettingParameters.Add(Port                      , "Port");
	Parameters.SettingParameters.Add(Speed                     , "Speed");
	Parameters.SettingParameters.Add(Timeout                   , "Timeout");
	Parameters.SettingParameters.Add(UserPassword              , "UserPassword");
	Parameters.SettingParameters.Add(AdministratorPassword     , "AdministratorPassword");
	Parameters.SettingParameters.Add(CancelCheckDuringConnect  , "CancelCheckDuringConnect");
	Parameters.SettingParameters.Add(PaymentDescription1       , "PaymentDescription1");
	Parameters.SettingParameters.Add(PaymentDescription2       , "PaymentDescription2");
	Parameters.SettingParameters.Add(SectionNumber             , "SectionNumber");
	Parameters.SettingParameters.Add(PartialCuttingSymbolCode  , "PartialCuttingSymbolCode");
	Parameters.SettingParameters.Add(Model                     , "Model");
	Parameters.SettingParameters.Add(MoneyBox                  , "MoneyBox");
	Parameters.SettingParameters.Add(VATMapping                , "VAT");
	Parameters.SettingParameters.Add(GCPaymentCode             , "GCPaymentCode");
	
	Close(DialogReturnCode.OK);

EndProcedure

&AtClient
Procedure DeviceTest(Command)

	ClearMessages();
	
	TestResult        = Undefined;
	InputParameters   = Undefined;
	Output_Parameters = Undefined;
	
	tempDeviceParameters = New Structure();
	tempDeviceParameters.Insert("Port"                     , Port);
	tempDeviceParameters.Insert("Speed"                    , Speed);
	tempDeviceParameters.Insert("Timeout"                  , Timeout);
	tempDeviceParameters.Insert("UserPassword"             , UserPassword);
	tempDeviceParameters.Insert("AdministratorPassword"    , AdministratorPassword);
	tempDeviceParameters.Insert("CancelCheckDuringConnect" , CancelCheckDuringConnect);
	tempDeviceParameters.Insert("PaymentDescription1"      , PaymentDescription1);
	tempDeviceParameters.Insert("PaymentDescription2"      , PaymentDescription2);
	tempDeviceParameters.Insert("SectionNumber"            , SectionNumber);
	tempDeviceParameters.Insert("PartialCuttingSymbolCode" , PartialCuttingSymbolCode);
	tempDeviceParameters.Insert("Model"                    , Model);
	tempDeviceParameters.Insert("VAT"                      , VATSettings(VAT));
	tempDeviceParameters.Insert("MoneyBox"                 , MoneyBox);
	tempDeviceParameters.Insert("GCPaymentCode"            , GCPaymentCode);
		
	Result = EquipmentManagerClient.RunAdditionalCommand("CheckHealth",
		InputParameters,
		Output_Parameters,
		ID,
		tempDeviceParameters);

	AdditionalDetails = ?(TypeOf(Output_Parameters) = Type("Array") AND Output_Parameters.Count(),
		StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Additional description: %1'"),
			Output_Parameters[1]),
		"");
	
	If Result Then
		CommonUseClientServer.MessageToUser(StringFunctionsClientServer.SubstituteParametersInString(
			 NStr("en = 'Test completed successfully. %1'"),
			 ?(IsBlankString(AdditionalDetails), "", Chars.LF + AdditionalDetails)));
	Else
		CommonUseClientServer.MessageToUser(StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Test failed. %1'"),
			?(IsBlankString(AdditionalDetails), "", Chars.LF + AdditionalDetails)));
	EndIf;
	
EndProcedure

&AtClient
Procedure SetupDriver(Command)
	
	ClearMessages();
	
	NotificationsDriverFromDistributionOnEnd	= New NotifyDescription("SettingDriverFromDistributionOnEnd", ThisObject);
	NotificationsDriverFromArchiveOnEnd			= New NotifyDescription("SetDriverFromArchiveOnEnd", ThisObject);
	EquipmentManagerClient.SetupDriver(HardwareDriver, NotificationsDriverFromDistributionOnEnd, NotificationsDriverFromArchiveOnEnd);
	
	UpdateInformationAboutDriver();

EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure SetDriverFromArchiveOnEnd(Result) Export
	
	CommonUseClientServer.MessageToUser(NStr("en = 'Driver is installed.'")); 
	UpdateInformationAboutDriver();
	
EndProcedure

&AtClient
Procedure SettingDriverFromDistributionOnEnd(Result, Parameters) Export 
	
	If Result Then
		CommonUseClientServer.MessageToUser(NStr("en = 'Driver is installed.'")); 
		UpdateInformationAboutDriver();
	Else
		CommonUseClientServer.MessageToUser(NStr("en = 'An error occurred when installing the driver from distribution.'")); 
	EndIf;

EndProcedure

&AtClient
Procedure UpdateInformationAboutDriver()

	InputParameters   = Undefined;
	Output_Parameters = Undefined;

	tempDeviceParameters = New Structure();
	tempDeviceParameters.Insert("Port"                      , Port);
	tempDeviceParameters.Insert("Speed"                     , Speed);
	tempDeviceParameters.Insert("Timeout"                   , Timeout);
	tempDeviceParameters.Insert("UserPassword"              , UserPassword);
	tempDeviceParameters.Insert("AdministratorPassword"     , AdministratorPassword);
	tempDeviceParameters.Insert("CancelCheckDuringConnect"  , CancelCheckDuringConnect);
	tempDeviceParameters.Insert("PaymentDescription1"       , PaymentDescription1);
	tempDeviceParameters.Insert("PaymentDescription2"       , PaymentDescription2);
	tempDeviceParameters.Insert("SectionNumber"             , SectionNumber);
	tempDeviceParameters.Insert("PartialCuttingSymbolCode"  , PartialCuttingSymbolCode);
	tempDeviceParameters.Insert("Model"                     , Model);
	tempDeviceParameters.Insert("VAT"                       , VATSettings(VAT));
	tempDeviceParameters.Insert("MoneyBox"                  , MoneyBox);
	tempDeviceParameters.Insert("GCPaymentCode"             , GCPaymentCode);

	If EquipmentManagerClient.RunAdditionalCommand("GetDriverVersion", InputParameters, Output_Parameters, ID, tempDeviceParameters) Then	
		Driver   = Output_Parameters[0];
		Version  = Output_Parameters[1];		
	Else
		Driver   = Output_Parameters[2];
		Version  = NStr("en = 'Not defined'");
	EndIf;

	Items.Driver.TextColor		= ?(Driver = NStr("en = 'Not set'"), ErrorColor, TextColor);
	Items.Version.TextColor		= ?(Version = NStr("en = 'Not defined'"), ErrorColor, TextColor);
	Items.SetupDriver.Enabled	= Not (Driver = NStr("en = 'Installed'"));

EndProcedure

&AtClient
Function VATSettings(VATTable)
	
	VATMapping = New Map;
	
	For Each Str In VATTable Do 
		
		VATStructure = New Structure;
		VATStructure.Insert("Rate",		Str.Rate);
		VATStructure.Insert("TaxGroup",	Str.TaxGroup);
		
		VATMapping.Insert("Rate" + Str.Rate, VATStructure);
		
	EndDo;
	
	Return VATMapping;
	
EndFunction

#EndRegion