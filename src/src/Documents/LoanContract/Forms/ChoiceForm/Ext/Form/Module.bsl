#Region FormEventHandlers

// Procedure - handler of the WhenCreatingOnServer event of the form.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("CompanyForFilter") AND Not Constants.AccountingBySubsidiaryCompany.Get() Then
		Parameters.Filter.Insert("Company", Parameters.CompanyForFilter);
	EndIf;
	
	If Parameters.Property("CounterpartyForFilter") 
		AND ValueIsFilled(Parameters.CounterpartyForFilter)
		AND ((Parameters.Property("OperationType")
				AND Parameters.OperationType = Enums.LoanAccrualTypes.AccrualsForLoansBorrowed)
			OR Not Parameters.Property("OperationType")) Then
				Parameters.Filter.Insert("Counterparty", Parameters.CounterpartyForFilter);
	EndIf;
	
	If Parameters.Property("EmployeeForFilter") 
		AND ValueIsFilled(Parameters.EmployeeForFilter) 
		AND ((Parameters.Property("OperationType") 
				AND Parameters.OperationType = Enums.LoanAccrualTypes.AccrualsForLoansLent)
			OR Not Parameters.Property("OperationType")) Then
				Parameters.Filter.Insert("Employee", Parameters.EmployeeForFilter);
	EndIf;
	
EndProcedure

#EndRegion
