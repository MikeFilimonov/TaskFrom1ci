#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ProgramInterface

Function GetDefaultGLAccount(DefaultAccountString) Export
	
	DefaultGLAccountsItem = Catalogs.DefaultGLAccounts[DefaultAccountString];
	GLAccount = CommonUse.ObjectAttributeValue(DefaultGLAccountsItem, "GLAccount");
	
	If ValueIsFilled(GLAccount) Then
		Return GLAccount;
	Else
		CommonUseClientServer.MessageToUser(
			StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Default GL account for %1 is not set. Please go to Company - Default GL Accounts and specify it.'"),
			DefaultGLAccountsItem.Description),
			DefaultGLAccountsItem,
			"GLAccount");
		Return ChartsOfAccounts.PrimaryChartOfAccounts.EmptyRef();
	EndIf;
	
EndFunction

#EndRegion

#Region InfobaseUpdate

Procedure DeleteDublicateBankFeesCreditAccount() Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	DefaultGLAccounts.Ref AS Ref
	|FROM
	|	Catalog.DefaultGLAccounts AS DefaultGLAccounts
	|WHERE
	|	DefaultGLAccounts.PredefinedDataName = ""BankFeesCreditAccount""
	|	AND DefaultGLAccounts.Ref <> &Ref";
	
	TrueItem		= Catalogs.DefaultGLAccounts.BankFeesCreditAccount;
	ItemToDelete	= Undefined;
	ReWriteTrueItem	= Not ValueIsFilled(TrueItem.GLAccount);
	
	Query.SetParameter("Ref", TrueItem);
	
	Result = Query.Execute();
	Selection = Result.Select();
	
	If Selection.Next() Then
		ItemToDelete = Selection.Ref;
	Else
		Return;
	EndIf;
	
	ItemToDeleteObject = ItemToDelete.GetObject();
	ItemToDeleteObject.DataExchange.Load = True;
	ItemToDeleteObject.PredefinedDataName = "";
	ItemToDeleteObject.Write();
	
	ItemToDeleteObject.SetDeletionMark(True);
	
	If ReWriteTrueItem Then
		
		TrueObject = TrueItem.GetObject();
		TrueObject.GLAccount = ItemToDelete.GLAccount;
		TrueObject.Write();
		
	EndIf;
	
EndProcedure

#EndRegion

#EndIf