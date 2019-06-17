#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

Procedure AddLeadToEnd(Lead) Export
	
	LeadState = WorkWithLeads.LeadState(Lead);
	KanbanItem = InformationRegisters.LeadKanban.CreateRecordManager();
	KanbanItem.Lead = Lead;
	FillPropertyValues(KanbanItem, LeadState);
	KanbanItem.Order = NewLastOrder(LeadState.Campaign, LeadState.Activity);
	KanbanItem.Write();
	
EndProcedure

Procedure DeleteLead(Lead) Export
	
	DeleteSet = InformationRegisters.LeadKanban.CreateRecordSet();
	DeleteSet.Filter.Lead.Set(Lead);
	DeleteSet.Write();
		
EndProcedure

Procedure DragLead(NewActivity, NewCampaign, Lead, Order = Undefined) Export
	
	BeginTransaction();
	Try
		
		DeleteSet = InformationRegisters.LeadKanban.CreateRecordSet();
		DeleteSet.Filter.Lead.Set(Lead);
		DeleteSet.Write();
		
		If Order = Undefined Then
			Order = NewLastOrder(NewCampaign, NewActivity);
		EndIf;
		
		RecordSet = InformationRegisters.LeadKanban.CreateRecordSet();
		RecordSet.Filter.Activity.Set(NewActivity);
		RecordSet.Filter.Campaign.Set(NewCampaign);
		RecordSet.Read();
		
		For Each Record In RecordSet Do
			If Record.Order < Order Then
				Continue;
			EndIf;
			Record.Order = Record.Order + 1;
		EndDo;
		
		NewRecord = RecordSet.Add();
		NewRecord.Activity = NewActivity;
		NewRecord.Campaign = NewCampaign;
		NewRecord.Lead = Lead;
		NewRecord.Order = Order;
		
		RecordSet.Write();
		
		CommitTransaction();
		
	Except
		
		RollbackTransaction();
		ErrorText = DetailErrorDescription(ErrorInfo());
		Raise ErrorText;
		
	EndTry;
	
EndProcedure

Procedure ChangeLeadOrder(LeadsData) Export
	
	RecordManagerFirst = InformationRegisters.LeadKanban.CreateRecordManager();
	RecordManagerFirst.Lead = LeadsData.FirstLeadRef;
	RecordManagerFirst.Order = LeadsData.SecontLeadOrder;
	RecordManagerFirst.Activity = LeadsData.Activity;
	RecordManagerFirst.Campaign = LeadsData.Campaign;
	RecordManagerFirst.Write();
	
	RecordManagerSecond = InformationRegisters.LeadKanban.CreateRecordManager();
	RecordManagerSecond.Lead = LeadsData.SecondLeadRef;
	RecordManagerSecond.Order = LeadsData.FirstLeadOrder;
	RecordManagerSecond.Activity = LeadsData.Activity;
	RecordManagerSecond.Campaign = LeadsData.Campaign;
	RecordManagerSecond.Write();
	
EndProcedure

Procedure DragLeads(Campaign, Activity, Leads, Order = Undefined) Export
	
	If Order = Undefined Then
		Order = NewLastOrder(Campaign, Activity);
	EndIf;
	
	FirstLeadOrder = Order;
	
	For Each Lead In Leads Do
		
		DeleteSet = InformationRegisters.LeadKanban.CreateRecordSet();
		DeleteSet.Filter.Lead.Set(Lead);
		DeleteSet.Write();
		
	EndDo;
	
	RecordSet = InformationRegisters.LeadKanban.CreateRecordSet();
	RecordSet.Filter.Activity.Set(Activity);
	RecordSet.Filter.Campaign.Set(Campaign);
	RecordSet.Read();
	
	For Each Lead In Leads Do
		NewRecord = RecordSet.Add();
		NewRecord.Activity = Activity;
		NewRecord.Campaign = Campaign;
		NewRecord.Lead = Lead;
		NewRecord.Order = Order;
		Order = Order + 1;
	EndDo;
	
	For Each Record In RecordSet Do
		FoundLead = Leads.Find(Record.Lead);
		If Record.Order < FirstLeadOrder OR FoundLead <> Undefined Then
			Continue;
		EndIf;
		Record.Order = Record.Order + Leads.Count();
	EndDo;
	
	RecordSet.Write();
	
EndProcedure

#EndRegion

#Region Private

Function NewLastOrder(Campaign, Activity)
	
	Order = 0;
	
	Query = New Query;
	Query.Text = 
		"SELECT TOP 1
		|	LeadKanban.Order AS Order
		|FROM
		|	InformationRegister.LeadKanban AS LeadKanban
		|WHERE
		|	LeadKanban.Campaign = &Campaign
		|	AND LeadKanban.Activity = &Activity
		|
		|ORDER BY
		|	Order DESC";
	
	Query.SetParameter("Activity", Activity);
	Query.SetParameter("Campaign", Campaign);
	
	Selection = Query.Execute().Select();
	
	If Selection.Next() Then
		Order = Selection.Order + 1;
	EndIf;
	
	Return Order;
	
EndFunction

#EndRegion

#EndIf