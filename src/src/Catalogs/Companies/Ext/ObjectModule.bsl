#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

Procedure Filling(FillingData, FillingText, StandardProcessing)
	
	FillByDefault();

EndProcedure

Procedure BeforeWrite(Cancel)
	
	// 1. Actions performed always, including the exchange of data
	
	If IsNew() Then
		
		// The "Ref" is certainly not filled.
		// However, reference may be transmitted in the During the exchange.
		
		NewObjectRef = GetNewObjectRef();
		If NewObjectRef.IsEmpty() Then
			SetNewObjectRef(Catalogs.Companies.GetRef());
		EndIf;
		
	EndIf;
	
	// No execute action in the data exchange
	If DataExchange.Load Then
		Return;
	EndIf;
	
	// 2. No further action is performed when recording data exchange mechanism is initiated
	
	// Check the possibility of changes
	If IsNew() AND Not GetFunctionalOption("UseSeveralCompanies") Then
		CommonUseClientServer.MessageToUser(NStr("en = 'In the application, accounting by several companies is disabled.'"));
		Cancel = True;
	EndIf;
	
	If Cancel Then
		Return;
	EndIf;
	
	BringDataToConsistentState();
	
EndProcedure

Procedure OnCopy(CopiedObject)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	BankAccountByDefault	= Undefined;
	LogoFile				= Undefined;
	FileFacsimilePrinting	= Undefined;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

Procedure FillByDefault()
	
	If Not ValueIsFilled(BusinessCalendar) Then
		BusinessCalendar = DriveServer.GetFiveDaysCalendar();
	EndIf;
		
	If Not ValueIsFilled(PettyCashByDefault) Then
		PettyCashByDefault = Catalogs.CashAccounts.GetPettyCashByDefault();
	EndIf;
	
EndProcedure

// Procedure coordinates the state some attributes of the object depending on the other
//
Procedure BringDataToConsistentState()
	
	If LegalEntityIndividual = Enums.CounterpartyType.LegalEntity Then
		
		Individual = Undefined;
		
	EndIf;
	
EndProcedure

#EndRegion

#EndIf