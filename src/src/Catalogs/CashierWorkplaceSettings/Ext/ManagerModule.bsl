#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region UpdateHandlers

Procedure RepairCWPSettings() Export
	
	Selection = Catalogs.CashierWorkplaceSettings.Select();
	
	While Selection.Next() Do
		
		CatalogObject = Selection.GetObject();
		CatalogObject.LowerBarButtons.Clear();
		CatalogObject.FillInButtonsTableFromLayout();
		CatalogObject.Write();
		
	EndDo;
	
EndProcedure

#EndRegion

#EndIf