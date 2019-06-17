// Function determines difference of dates in months.
//
Function DueDateByEndDate(EndDate, StartDate) Export
	
	If EndDate < StartDate Then
		Return 0;
	EndIf;
	
	StartYear = Year(StartDate);
	EndYear = Year(EndDate);
	
	StartMonth = Month(StartDate);
	EndMonth = Month(EndDate);
	
	StartDay = Day(StartDate);
	EndDay = Day(EndDate);
	
	Return Max(((EndYear - StartYear) - ?(EndMonth < StartMonth, 1, 0)), 0) * 12
		+ (EndMonth - StartMonth + 1 + ?(EndMonth < StartMonth, 12, 0) - ?(EndDay < StartDay, 1, 0));
	
EndFunction

// Calculates coefficient for annuity payments.
//
// Parameters:
//	- Rate, type number - interest rate for the repayment period (month).
//	- Due date, type Number - number of repayment periods (months).
//
Function AnnuityCoefficient(Rate, DueDate) Export
	
	If DueDate = 0 Then
		Return 0;
	EndIf;
	
	If Rate = 0 Then
		Return 1 / DueDate;
	EndIf;
	
	Return Rate / (1 - Pow(1 + Rate, - DueDate));
	
EndFunction

Function InterestRatePerMonth(AnnualInterestRate) Export
	
	If AnnualInterestRate = 0 Then
		Return 0;
	Else
		Return AnnualInterestRate / 12;
	EndIf;
	
EndFunction
