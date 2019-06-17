#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

Procedure BeforeWrite(Cancel)
	
	Query = New Query;
	Query.Text = 
	"SELECT TOP 1
	|	SuppliersProducts.Ref
	|FROM
	|	Catalog.SuppliersProducts AS SuppliersProducts
	|WHERE
	|	SuppliersProducts.Owner = &Owner
	|	AND SuppliersProducts.SKU = &SKU
	|	AND SuppliersProducts.ID = &ID
	|	AND SuppliersProducts.Products = &Products
	|	AND SuppliersProducts.Characteristic = &Characteristic
	|	AND SuppliersProducts.Ref <> &CurrentRef";
	
	Query.SetParameter("Owner", Owner);
	Query.SetParameter("SKU", SKU);
	Query.SetParameter("ID", ID);
	Query.SetParameter("Products", Products);
	Query.SetParameter("Characteristic", Characteristic);
	Query.SetParameter("CurrentRef", Ref);
	
	Result = Query.Execute();
	If Not Result.IsEmpty() Then
		
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Mapping ""%1,%2,%3 - %4,%5"" is already in the catalog. Writing is canceled.'"),
			Owner, SKU, ID, Products, Characteristic
		);
		
		Message = New UserMessage();
		Message.Text = MessageText;
		Message.Message();
		
		Cancel = True;
		
	EndIf;
	
EndProcedure

#EndIf