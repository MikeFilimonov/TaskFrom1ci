#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

Procedure Filling(FillingData, FillingText, StandardProcessing)
	
	If TypeOf(FillingData) = Type("CatalogRef.Counterparties") Then
		
		FillByCounterparty(FillingData);
		
	ElsIf TypeOf(FillingData) = Type("Structure") Then
		
		FillByStructure(FillingData);
		
	EndIf;
	
	FillByDefault();
	
EndProcedure

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	// Prices kind.
	If ValueIsFilled(DiscountMarkupKind) Then
		CheckedAttributes.Add("PriceKind");
	EndIf;
	
EndProcedure

Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If DeletionMark Then
		
		CounterpartyAttributesValues = CommonUse.ObjectAttributesValues(Owner, "DeletionMark, ContractByDefault");
		
		If Not CounterpartyAttributesValues.DeletionMark AND CounterpartyAttributesValues.ContractByDefault = Ref Then
			MessageText = NStr("en = 'The default contract cannot be marked for deletion. Select another default contract for this counterparty and try again.'");
			CommonUseClientServer.MessageToUser(MessageText, Ref,,, Cancel);
		EndIf;
		
	EndIf;
	
	Query = New Query(
	"SELECT
	|	CounterpartyContracts.Ref
	|FROM
	|	Catalog.CounterpartyContracts AS CounterpartyContracts
	|WHERE
	|	CounterpartyContracts.Ref <> &Ref
	|	AND CounterpartyContracts.Owner = &Owner
	|	AND NOT CounterpartyContracts.Owner.DoOperationsByContracts");
	
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("Owner", Owner);
	
	Selection = Query.Execute().Select();
	
	If Selection.Next() Then
		MessageText = NStr("en = 'Cannot save the contract because billing details by contract are turned off for the selected counterparty. Turn them on in the counterparty details and then try again.'");
		DriveServer.ShowMessageAboutError(
			ThisObject,
			MessageText,
			,
			,
			,
			Cancel
		);
	EndIf;
	
	If ValueIsFilled(Ref) Then
		AdditionalProperties.Insert("DeletionMark", Ref.DeletionMark);
	EndIf;
	
	If EarlyPaymentDiscounts.Count() > 0 AND ContractKind <> Enums.ContractType.WithCustomer
		AND ContractKind <> Enums.ContractType.WithVendor Then
		
		EarlyPaymentDiscounts.Clear();
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FillingProcedures

Procedure FillByCounterparty(FillingData)
	
	AttributesValues	= CommonUse.ObjectAttributesValues(FillingData, "Customer,Supplier,OtherRelationship, BankAccountByDefault");
	
	If Not ValueIsFilled(Company) Then
		
		CompanyByDefault = DriveReUse.GetValueByDefaultUser(Users.CurrentUser(), "MainCompany");
		If Not ValueIsFilled(CompanyByDefault) Then
			CompanyByDefault = Catalogs.Companies.MainCompany;
		EndIf;
		
		Company = CompanyByDefault;
		
	EndIf;
	
	Description				= NStr("en = 'Default contract'");
	SettlementsCurrency		= Constants.FunctionalCurrency.Get();
	
	If Not ValueIsFilled(ContractKind) Then
		If AttributesValues.Supplier AND Not AttributesValues.Customer Then
			ContractKind = Enums.ContractType.WithVendor;
		ElsIf AttributesValues.OtherRelationship AND Not AttributesValues.Customer AND Not AttributesValues.Supplier Then
			ContractKind = Enums.ContractType.Other;
		Else
			ContractKind = Enums.ContractType.WithCustomer;
		EndIf;
	EndIf;
	
	If ContractKind = Enums.ContractType.WithCustomer Then
		CashFlowItem = Catalogs.CashFlowItems.PaymentFromCustomers;
	ElsIf ContractKind = Enums.ContractType.WithVendor Then
		CashFlowItem = Catalogs.CashFlowItems.PaymentToVendor;
	Else
		CashFlowItem = Catalogs.CashFlowItems.Other;
	EndIf;
	
	PriceKind				= Catalogs.PriceTypes.GetMainKindOfSalePrices();
	Owner					= FillingData;
	CounterpartyBankAccount	= AttributesValues.BankAccountByDefault;
	Status					= Enums.CounterpartyContractStatuses.Active;
	
EndProcedure

Procedure FillByStructure(FillingData)
	
	FillPropertyValues(ThisObject, FillingData);
	
	If FillingData.Property("Owner") AND ValueIsFilled(FillingData.Owner) Then
		
		FillByCounterparty(FillingData.Owner);
		
	EndIf;
	

EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

Procedure FillByDefault()
	
	If IsFolder Then
		Return;
	EndIf;
	
	If Not ValueIsFilled(Responsible) Then
		Responsible = DriveReUse.GetValueByDefaultUser(Users.CurrentUser(), "MainResponsible");
	EndIf;
	
	If Not ValueIsFilled(Department) Then
		Department = DriveReUse.GetValueByDefaultUser(Users.CurrentUser(), "MainDepartment");
		If Not ValueIsFilled(Department) Then
			Department	= Catalogs.BusinessUnits.MainDepartment;	
		EndIf;
	EndIf;
	
	If Not ValueIsFilled(BusinessLine) Then
		BusinessLine	= Catalogs.LinesOfBusiness.MainLine;	
	EndIf;
	
EndProcedure

#EndRegion

#EndIf
