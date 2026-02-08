#ASSET MANAGEMENT SYSTEM

##A - ASSET 
###FIXED FIELDS :- 
	•id
	•asset_token [public, random encoded, goes into the qr]
	•created_at
###Flexible Fields :-
	•asset_name
	•geolocation
	•department
	•assigned_to [Depends on department type], not needed for all use cases
	•validtill
###Status Values :-
	•ACTIVE
	•ARCHIVED
____________________________________________________________________________________________________________________________

##B - ASSET EVENT 
###Event Type :-
	•CREATED
	•UPDATED
	•DELETED
	•ARCHIVED
###MANDATORY FIELDS :-
	•userid
	•timestamp
	•geolocation
###What triggers each event :-
	•ADD 
		•Create a new asset record
	•MODIFY
		•Modify the flexible fields
	•Archive
		•Status changes from active -> archive
	•DELETE
		•Push to trash, to be auto-deleted in 30, unless done manually by admin user
____________________________________________________________________________________________________________________________

##C - TENANT
###Tenantid :-
	•Autocreated when a new tenant is created
	•Tenant is created manually by the admin
	•No tenant signup
###Secret_key :-
	•Different for each tenant db
###Isolation rule :-
	•Every user cannot get a result when scanning another tenants QR code
____________________________________________________________________________________________________________________________

##D - ENDPOINTS
	•Create Asset
	•Get Asset by QR
	•Archive Asset
____________________________________________________________________________________________________________________________

