
#Region FormEventsHandlers

&AtClient
Procedure OnOpen(Cancel)
	ItemCount = 0;
	If FileOperationsServiceClient.InitializeComponent() Then
		DeviceArray = FileOperationsServiceClient.GetDevices();
		For Each String In DeviceArray Do
			ItemCount = ItemCount + 1;
			Items.DeviceName.ChoiceList.Add(String);
		EndDo;
	EndIf;
	If ItemCount = 0 Then
		Cancel = True;
		ShowMessageBox(, NStr("en = 'Scanner is not installed. Contact the application administrator.'"));
	Else
		Items.DeviceName.ListChoiceMode = True;
	EndIf;
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure ChooseScanner(Command)
	SystemInfo = New SystemInfo();
	CommonUseServerCall.CommonSettingsStorageSave(
		"ScanningSettings/DeviceName",
		SystemInfo.ClientID,
		DeviceName);
	RefreshReusableValues();
	Close(DeviceName);
EndProcedure

#EndRegion