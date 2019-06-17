// Form is called from:
// Document.Payroll.DocumentForm
// Document.Payroll.ListForm
// Document.PayrollSheet.DocumentForm
// Document.PayrollSheet.ListForm
// Document.CashVoucher.DocumentForm
// Document.Timesheet.DocumentForm

#Region ServiceProceduresAndFunctions

// Procedure of idle data processor on date activation.
//
&AtClient
Procedure IdleProcessing()
	
	For Each SelectedDate In Items.CalendarDate.SelectedDates Do
		
		CalendarDate = SelectedDate;
		
	EndDo;
	
	NotifyChoice(CalendarDate);
	
EndProcedure

#EndRegion

#Region ProcedureFormEventHandlers

// Procedure - event handler OnCreateAtServer of the form.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Parameters.Property("CalendarDate", CalendarDate)
	
EndProcedure

#EndRegion

#Region ProcedureEventHandlersOfFormAttributes

// Procedure - event handler OnActivateDate field CalendarDate.
//
&AtClient
Procedure CalendarDateOnActivateDate(Item)
	
	AttachIdleHandler("IdleProcessing", 0.2, True);
	
EndProcedure

#EndRegion
