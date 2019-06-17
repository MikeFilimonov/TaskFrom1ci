#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ProgramInterface

Function GetAccountingPolicy(Val Date = Undefined, Val Company = Undefined) Export
	
	StructureToReturn = New Structure;
	StructureToReturn.Insert("RegisteredForVAT",			False);
	StructureToReturn.Insert("DefaultVATRate",				Undefined);
	StructureToReturn.Insert("VATThreshold",				0);
	StructureToReturn.Insert("CashMethodOfAccounting",		Undefined);
	StructureToReturn.Insert("InventoryValuationMethod",	Undefined);
	StructureToReturn.Insert("UseGoodsReturnFromCustomer",	False);
	StructureToReturn.Insert("UseGoodsReturnToSupplier",	False);
	
	StructureToReturn.Insert("PostVATEntriesBySourceDocuments", True);
	StructureToReturn.Insert("PostAdvancePaymentsBySourceDocuments", False);
	StructureToReturn.Insert("IssueAutomaticallyAgainstSales", False);
		
	If NOT ValueIsFilled(Company) Then
		Company = DriveReUse.GetValueOfSetting("MainCompany");
	EndIf;
		
	If NOT ValueIsFilled(Company) Then
		Company = Catalogs.Companies.MainCompany;	
	EndIf;
	
	If NOT ValueIsFilled(Date) Then
		Date = CurrentDate();
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	AccountingPolicySliceLast.DefaultVATRate AS DefaultVATRate,
	|	AccountingPolicySliceLast.RegisteredForVAT AS RegisteredForVAT,
	|	AccountingPolicySliceLast.VATThreshold AS VATThreshold,
	|	AccountingPolicySliceLast.CashMethodOfAccounting AS CashMethodOfAccounting,
	|	AccountingPolicySliceLast.InventoryValuationMethod AS InventoryValuationMethod,
	|	AccountingPolicySliceLast.UseGoodsReturnFromCustomer AS UseGoodsReturnFromCustomer,
	|	AccountingPolicySliceLast.UseGoodsReturnToSupplier AS UseGoodsReturnToSupplier,
	|	AccountingPolicySliceLast.PostVATEntriesBySourceDocuments AS PostVATEntriesBySourceDocuments,
	|	AccountingPolicySliceLast.PostAdvancePaymentsBySourceDocuments AS PostAdvancePaymentsBySourceDocuments,
	|	AccountingPolicySliceLast.IssueAutomaticallyAgainstSales AS IssueAutomaticallyAgainstSales
	|FROM
	|	InformationRegister.AccountingPolicy.SliceLast(&Date, Company = &Company) AS AccountingPolicySliceLast";
	Query.SetParameter("Date",		Date);
	Query.SetParameter("Company",	Company);
	
	QueryResult	= Query.Execute();
	Selection	= QueryResult.Select();
	
	If Selection.Next() Then
		FillPropertyValues(StructureToReturn, Selection);
	Else
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Please, specify accounting policy actual at %2 for %1. Go to Companies catalog (Company->Company details) and select Accounting policy menu in the header of the form.'"),
			Company,
			Format(Date, "DLF=D"));
	EndIf;
	
	Return StructureToReturn;

EndFunction

Function GetDefaultVATRate(Val Date = Undefined, Val Company = Undefined) Export
	
	Policy = GetAccountingPolicy(Date, Company);
	
	Return ?(Policy.DefaultVATRate = Catalogs.VATRates.EmptyRef(), 
		Catalogs.VATRates.Exempt, 
		Policy.DefaultVATRate);
	
EndFunction

Function InventoryValuationMethod(Val Date = Undefined, Val Company = Undefined) Export
	
	Policy = GetAccountingPolicy(Date, Company);
	
	Return Policy.InventoryValuationMethod;
EndFunction

#EndRegion

#EndIf