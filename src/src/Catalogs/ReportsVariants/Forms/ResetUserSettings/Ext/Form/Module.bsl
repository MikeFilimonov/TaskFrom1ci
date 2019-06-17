
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	If Not Parameters.Property("OptionsArray") Or TypeOf(Parameters.OptionsArray) <> Type("Array") Then
		ErrorText = NStr("en = 'Report options are not specified.'");
		Return;
	EndIf;
	
	If Not AreUserSettings(Parameters.OptionsArray) Then
		ErrorText = NStr("en = 'User settings of the selected report options (%1 pcs.) were not specified or have already been reset.'");
		ErrorText = StrReplace(ErrorText, "%1", Format(Parameters.OptionsArray.Count(), "NZ=0; NG=0"));
		Return;
	EndIf;
	
	CustomizableOptions.LoadValues(Parameters.OptionsArray);
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	If Not IsBlankString(ErrorText) Then
		Cancel = True;
		ShowMessageBox(, ErrorText);
	EndIf;
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure ResetCommand(Command)
	VariantCount = CustomizableOptions.Count();
	If VariantCount = 0 Then
		ShowMessageBox(, NStr("en = 'Report options are not specified.'"));
		Return;
	EndIf;
	
	ResetUserSettingsServer(CustomizableOptions);
	If VariantCount = 1 Then
		OptionRef = CustomizableOptions[0].Value;
		NotificationTitle = NStr("en = 'User settings of report option were reset'");
		NotificationRef    = GetURL(OptionRef);
		NotificationText     = String(OptionRef);
		ShowUserNotification(NotificationTitle, NotificationRef, NotificationText);
	Else
		NotificationText = NStr("en = 'Custom settings of report options are reset (%1 pcs.)'");
		NotificationText = StrReplace(NotificationText, "%1", Format(VariantCount, "NZ=0; NG=0"));
		ShowUserNotification(, , NotificationText);
	EndIf;
	Close();
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

#Region CallingTheServer

&AtServerNoContext
Function ResetUserSettingsServer(Val CustomizableOptions)
	BeginTransaction();
	InformationRegisters.ReportOptionSettings.ResetSettings(CustomizableOptions.UnloadValues());
	CommitTransaction();
EndFunction

#EndRegion

#Region Server

&AtServer
Function AreUserSettings(OptionsArray)
	Query = New Query;
	Query.SetParameter("OptionsArray", OptionsArray);
	Query.Text =
	"SELECT TOP 1
	|	TRUE AS Field1
	|FROM
	|	InformationRegister.ReportOptionSettings AS Settings
	|WHERE
	|	Settings.Variant IN(&OptionsArray)";
	
	AreUserSettings = Not Query.Execute().IsEmpty();
	Return AreUserSettings;
EndFunction

#EndRegion

#EndRegion
