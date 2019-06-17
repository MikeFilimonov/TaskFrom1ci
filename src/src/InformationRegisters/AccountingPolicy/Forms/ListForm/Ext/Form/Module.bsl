
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	CommonUseClientServer.SetDynamicListParameter(List, 
													"CreditNote", 
													NStr("en = 'Credit note document only'"),
													True); 
	CommonUseClientServer.SetDynamicListParameter(List,
													"CreditNoteAndGoodsReturn", 
													NStr("en = 'Credit note and Goods return documents'"),
													True); 
	CommonUseClientServer.SetDynamicListParameter(List,
													"DebitNote", 
													NStr("en = 'Debit note document only'"),
													True); 
	CommonUseClientServer.SetDynamicListParameter(List, 
													"DebitNoteAndGoodsReturn", 
													NStr("en = 'Debit note and Goods return documents'"),
													True);
EndProcedure
