
Procedure OnWrite(Cancel, Replacing)
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	MAX(AccountingPolicy.RegisteredForVAT) AS RegisteredForVAT,
		|	MAX(NOT AccountingPolicy.PostVATEntriesBySourceDocuments) AS PostVATEntriesBySourceDocuments,
		|	MAX(NOT AccountingPolicy.PostAdvancePaymentsBySourceDocuments) AS PostAdvancePaymentsBySourceDocuments,
		|	MAX(AccountingPolicy.UseGoodsReturnFromCustomer) AS UseGoodsReturnFromCustomer,
		|	MAX(AccountingPolicy.UseGoodsReturnToSupplier) AS UseGoodsReturnToSupplier,
		|	FunctionalOptionUseVAT.Value AS CommonUseVAT,
		|	UseTaxInvoices.Value AS CommonUseTaxInvoice,
		|	FunctionalOptionUseGoodsReturnFromCustomer.Value AS CommonUseGoodsReturnFromCustomer,
		|	FunctionalOptionUseGoodsReturnToSupplier.Value AS CommonUseGoodsReturnToSupplier
		|FROM
		|	InformationRegister.AccountingPolicy AS AccountingPolicy
		|		LEFT JOIN Constant.FunctionalOptionUseVAT AS FunctionalOptionUseVAT
		|		ON (TRUE)
		|		LEFT JOIN Constant.UseTaxInvoices AS UseTaxInvoices
		|		ON (TRUE)
		|		LEFT JOIN Constant.UseGoodsReturnFromCustomer AS FunctionalOptionUseGoodsReturnFromCustomer
		|		ON (TRUE)
		|		LEFT JOIN Constant.UseGoodsReturnToSupplier AS FunctionalOptionUseGoodsReturnToSupplier
		|		ON (TRUE)
		|
		|GROUP BY
		|	FunctionalOptionUseVAT.Value,
		|	UseTaxInvoices.Value,
		|	FunctionalOptionUseGoodsReturnFromCustomer.Value,
		|	FunctionalOptionUseGoodsReturnToSupplier.Value";
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		
		RegisteredForVAT	= Selection.RegisteredForVAT;
		UseTaxInvoices		= Selection.PostVATEntriesBySourceDocuments OR Selection.PostAdvancePaymentsBySourceDocuments;
		
		UseGoodsReturnFromCustomer	= Selection.UseGoodsReturnFromCustomer;
		UseGoodsReturnToSupplier	= Selection.UseGoodsReturnToSupplier;
	Else
		
		RegisteredForVAT	= False;
		UseTaxInvoices		= False;
		
		UseGoodsReturnFromCustomer	= False;
		UseGoodsReturnToSupplier	= False;
	EndIf;
	
	If Selection.CommonUseGoodsReturnFromCustomer <> UseGoodsReturnFromCustomer Then
		Constants.UseGoodsReturnFromCustomer.Set(UseGoodsReturnFromCustomer);
	EndIf;
	
	If Selection.CommonUseGoodsReturnToSupplier <> UseGoodsReturnToSupplier Then
		Constants.UseGoodsReturnToSupplier.Set(UseGoodsReturnToSupplier);
	EndIf;
	
	If Selection.CommonUseVAT <> RegisteredForVAT Then
		Constants.FunctionalOptionUseVAT.Set(RegisteredForVAT);
	EndIf;
	
	If Selection.CommonUseTaxInvoice <> UseTaxInvoices Then
		Constants.UseTaxInvoices.Set(UseTaxInvoices);
	EndIf;
	
EndProcedure
