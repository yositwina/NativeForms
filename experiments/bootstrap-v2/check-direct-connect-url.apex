NativeFormsSetupController.SetupContext context = NativeFormsSetupController.getSetupContext();
NativeFormsSetupController.RegistrationRequest request = new NativeFormsSetupController.RegistrationRequest();
request.orgId = context.orgId;
request.adminEmail = context.adminEmail;
request.companyName = context.orgName;
request.loginBaseUrl = context.loginBaseUrl;
NativeFormsSetupController.RegistrationResult result = NativeFormsSetupController.registerOrg(JSON.serialize(request));
System.debug('DIRECT_CONNECT_RESULT=' + JSON.serialize(result));
