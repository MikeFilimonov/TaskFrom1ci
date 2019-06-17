#Region InternalProceduresAndFunctions

// Procedure sets up hyperlink visibility to open the reminder list.
//
&AtServer
Procedure SetHyperlinkVisibilityThereRemindersOnServer()

	Query = New Query;
	Query.Text = 
	"SELECT TOP 1
	|	UserReminders.Source
	|FROM
	|	InformationRegister.UserReminders AS UserReminders
	|WHERE
	|	UserReminders.Source = &Recorder";
	
	Query.SetParameter("Recorder", Recorder);
	
	RequestResult = Query.Execute();
	
	DetailedRecordSelection = RequestResult.Select();
	
	Items.ThereRemindersForLoanContract.Visible = DetailedRecordSelection.Next();

EndProcedure

#EndRegion

#Region FormEventHandlers

// Procedure - handler of the WhenCreatingOnServer event of the form.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("Autotest") Then // Skipping the initialization to guarantee that the form will be received if the Autotest parameter is passed.
		Return;
	EndIf;

	AddressPaymentsAndAccrualsScheduleInStorage	= Parameters.AddressPaymentsAndAccrualsScheduleInStorage;
	DocumentFormID								= Parameters.DocumentFormID;
	Recorder									= Parameters.Recorder;
	User										= Users.CurrentUser();
	CounterpartyBank							= Parameters.CounterpartyBank;
	
	SetHyperlinkVisibilityThereRemindersOnServer();
	
EndProcedure

// Procedure - handler of the WhenOpening event of the form.
//
&AtClient
Procedure OnOpen(Cancel)
	
	If Time = '00010101000000' Then
		Time = '00010101100000';
	EndIf;
	If RadioButtonAccrualDay = 0 Then
		RadioButtonAccrualDay = 1;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

// Procedure - handler of the Create forms command.
//
&AtClient
Procedure Create(Command)

	If User.IsEmpty() Then
		ShowMessageBox(Undefined, NStr("en = 'Select user.'"));
		Return;
	EndIf;
	
	If Not ValueIsFilled(Time) Then
		ShowMessageBox(Undefined, NStr("en = 'Set reminder time.'"));
		Return;
	EndIf;
	
	CreateServer();
	
EndProcedure

// Procedure - handler of the Create forms command. Server part.
//
&AtServer
Procedure CreateServer()
	
	// receive Accrual table on schedule
	ScheduleFromStorage = GetFromTempStorage(AddressPaymentsAndAccrualsScheduleInStorage);
	
	If ScheduleFromStorage.Count() > 0 Then
		
		Set = InformationRegisters.UserReminders.CreateRecordSet();
		Set.Filter.User.Set(User);
		Set.Filter.Source.Set(Recorder);
		
		For Each ScheduleLine In ScheduleFromStorage Do
			
			Record = Set.Add();
			
			// Dimensions
			If RadioButtonAccrualDay = 1 Then
				ReminderTimeDate = BegOfDay(BegOfDay(ScheduleLine.PaymentDate) - 1) + 
					Hour(Time) * 3600 + 
					Minute(Time) * 60 + 
					Second(Time);
			Else
				ReminderTimeDate = ScheduleLine.PaymentDate + 
					Hour(Time) * 3600 + 
					Minute(Time) * 60 + 
					Second(Time);
			EndIf;
			
			Record.User			= User;
			Record.EventTime	= ReminderTimeDate;
			Record.Source		= Recorder;
			
			// Resources
			Record.ReminderPeriod = ReminderTimeDate;
			
			// Attributes
			Record.Definition = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Loan payment = %1 (princ. debt = %2; interest amount %3; commission %4) in bank %5.'"),
				ScheduleLine.PaymentAmount,
				ScheduleLine.Principal,
				ScheduleLine.Interest,
				ScheduleLine.Commission,
				CounterpartyBank.Description);
				
			Record.ReminderTimeSettingVariant	= Enums.ReminderTimeOptions.InSpecifiedTime;
			Record.ReminderInterval				= 3600;
			Record.SourcePresentation			= "" + Recorder;
			
		EndDo;
		
		Set.Write(True);
		
		Items.ThereRemindersForLoanContract.Title		= NStr("en = 'Reminders for credit (loan) contract'");
		Items.ThereRemindersForLoanContract.Visible = True;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region ProceduresHandlersOfEventsFormItems

// Procedure - handler of the Click event of the ThereReminderForLoanContract item.
&AtClient
Procedure ThereRemindersForObjectClick(Item)
	
	FormOpenParameters = New Structure("Filter", New Structure("Source", Recorder));
	OpenForm("InformationRegister.UserReminders.ListForm", FormOpenParameters);
	
EndProcedure

#EndRegion
