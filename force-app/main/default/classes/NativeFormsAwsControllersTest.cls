@IsTest
private class NativeFormsAwsControllersTest {
    private static Map<String, PermissionSet> getManagedPermissionSets() {
        Map<String, PermissionSet> byLabel = new Map<String, PermissionSet>();
        for (PermissionSet permissionSetRecord : [
            SELECT Id, Label
            FROM PermissionSet
            WHERE Label IN ('TwinaForms User', 'TwinaForms Admin')
        ]) {
            byLabel.put(permissionSetRecord.Label, permissionSetRecord);
        }
        return byLabel;
    }

    private static Map<String, Object> buildHomeSummaryPayload(Integer maxSfUsers, Boolean adminAppOpen) {
        return new Map<String, Object>{
            'success' => true,
            'plan' => new Map<String, Object>{
                'code' => 'starter',
                'label' => 'Starter',
                'description' => 'Starter plan',
                'storageMode' => 'package',
                'retentionDays' => 30,
                'detailedLogsIncluded' => false,
                'advancedSecurityIncluded' => false,
                'limits' => new Map<String, Object>{
                    'maxForms' => 100
                }
            },
            'usage' => new Map<String, Object>{
                'activeFormsCount' => 2,
                'maxForms' => 100,
                'submissionsMonth' => 12,
                'maxSubmissionsPerMonth' => 1000,
                'activeUsersCount' => 0,
                'maxSfUsers' => maxSfUsers
            },
            'supportFlags' => new Map<String, Object>{
                'enableSalesforceAdminApp' => adminAppOpen == true
            },
            'upgradeFeatures' => new List<Object>{
                new Map<String, Object>{
                    'key' => 'advancedSecurity',
                    'label' => 'Advanced Security',
                    'detail' => 'Upgrade to unlock advanced security.',
                    'status' => 'upgradeAvailable'
                }
            },
            'comparePlansUrl' => 'https://twinaforms.com/compare',
            'upgradeUrl' => 'https://twinaforms.com/upgrade'
        };
    }

    private static Map<String, Object> buildStatusPayload(Boolean success, Boolean registered, Boolean connected) {
        return new Map<String, Object>{
            'success' => success == true,
            'registered' => registered == true,
            'connected' => connected == true,
            'setupState' => connected == true ? 'connected' : 'needs_setup',
            'connectUrl' => 'https://twinaforms.com/connect',
            'hasClientCredentials' => connected == true
        };
    }

    private static NativeFormsHomeController.AccessUserItem findAccessUser(
        NativeFormsHomeController.HomeView view,
        Id userId
    ) {
        if (view == null || view.access == null || view.access.users == null) {
            return null;
        }
        for (NativeFormsHomeController.AccessUserItem item : view.access.users) {
            if (item != null && item.userId == userId) {
                return item;
            }
        }
        return null;
    }

    private static void assertAuraHandled(AuraHandledException e, String expectedFragment) {
        System.assertNotEquals(null, e);
        System.assert(String.isNotBlank(e.getMessage()));
        if (String.isNotBlank(expectedFragment)) {
            System.assert(e.getMessage().contains(expectedFragment));
        }
    }

    @IsTest
    static void setupContextAndHappyPathConnectionFlowsWork() {
        NativeFormsSetupController.SetupContext context = NativeFormsSetupController.getSetupContext();
        System.assertEquals(UserInfo.getOrganizationId().substring(0, 15), context.orgId);
        System.assert(String.isNotBlank(context.adminEmail));
        System.assert(String.isNotBlank(context.loginBaseUrl));
        System.assert(String.isNotBlank(context.orgName));

        NativeFormsSetupController.RegistrationRequest registrationRequest =
            new NativeFormsSetupController.RegistrationRequest();
        registrationRequest.orgId = context.orgId;
        registrationRequest.adminEmail = context.adminEmail;
        registrationRequest.companyName = context.orgName;
        registrationRequest.loginBaseUrl = context.loginBaseUrl;

        NativeFormsSetupController.ClientCredentialsRequest credentialsRequest =
            new NativeFormsSetupController.ClientCredentialsRequest();
        credentialsRequest.orgId = context.orgId;
        credentialsRequest.adminEmail = context.adminEmail;
        credentialsRequest.companyName = context.orgName;
        credentialsRequest.loginBaseUrl = context.loginBaseUrl;

        Test.setMock(
            HttpCalloutMock.class,
            new NativeFormsAwsMockFactory.RoutingMock()
                .addJsonResponse(
                    '/tenant/register',
                    200,
                    new Map<String, Object>{
                        'success' => true,
                        'tenantSecret' => 'tenant-secret',
                        'connectUrl' => 'https://twinaforms.com/connect'
                    }
                )
                .addJsonResponse('/tenant/status', 200, buildStatusPayload(true, true, true))
                .addJsonResponse(
                    '/tenant/auth-health',
                    200,
                    new Map<String, Object>{ 'success' => true }
                )
                .addJsonResponse(
                    '/tenant/disconnect',
                    200,
                    new Map<String, Object>{
                        'success' => true,
                        'connectUrl' => 'https://twinaforms.com/connect'
                    }
                )
        );

        Test.startTest();
        NativeFormsSetupController.RegistrationResult registerResult =
            NativeFormsSetupController.registerOrg(JSON.serialize(registrationRequest));
        NativeFormsSetupController.RegistrationResult saveResult =
            NativeFormsSetupController.saveClientCredentials(JSON.serialize(credentialsRequest));
        NativeFormsSetupController.ConnectionStatus statusResult =
            NativeFormsSetupController.getConnectionStatus(context.orgId, true);
        NativeFormsSetupController.DisconnectResult disconnectResult =
            NativeFormsSetupController.disconnectOrg(context.orgId);
        Test.stopTest();

        System.assertEquals(true, registerResult.success);
        System.assertEquals('tenant-secret', registerResult.tenantSecret);
        System.assertEquals('https://twinaforms.com/connect', registerResult.connectUrl);
        System.assertEquals(true, saveResult.success);
        System.assertEquals('https://twinaforms.com/connect', saveResult.connectUrl);
        System.assertEquals(true, statusResult.success);
        System.assertEquals(true, statusResult.registered);
        System.assertEquals(true, statusResult.connected);
        System.assertEquals(true, statusResult.hasClientCredentials);
        System.assertEquals(true, statusResult.tenantAuthVerified);
        System.assertEquals('verified', statusResult.tenantAuthStatus);
        System.assertEquals(true, disconnectResult.success);
    }

    @IsTest
    static void setupControllerMapsPermissionAndAuthFailures() {
        NativeFormsSetupController.RegistrationRequest registrationRequest =
            new NativeFormsSetupController.RegistrationRequest();
        registrationRequest.orgId = UserInfo.getOrganizationId().substring(0, 15);

        NativeFormsSetupController.ClientCredentialsRequest credentialsRequest =
            new NativeFormsSetupController.ClientCredentialsRequest();
        credentialsRequest.orgId = registrationRequest.orgId;

        Test.setMock(
            HttpCalloutMock.class,
            new NativeFormsAwsMockFactory.RoutingMock().addJsonResponse(
                '/tenant/register',
                401,
                new Map<String, Object>{
                    'success' => false,
                    'error' => 'External Credential principal access missing.'
                }
            )
        );
        NativeFormsSetupController.RegistrationResult registerResult =
            NativeFormsSetupController.registerOrg(JSON.serialize(registrationRequest));
        NativeFormsSetupController.RegistrationResult saveResult =
            NativeFormsSetupController.saveClientCredentials(JSON.serialize(credentialsRequest));

        System.assertEquals(false, registerResult.success);
        System.assert(registerResult.errorMessage.contains('setup access is not complete'));
        System.assertEquals(false, saveResult.success);
        System.assert(saveResult.errorMessage.contains('setup access is not complete'));

        Test.setMock(
            HttpCalloutMock.class,
            new NativeFormsAwsMockFactory.RoutingMock().addJsonResponse(
                '/tenant/status',
                401,
                new Map<String, Object>{
                    'success' => false,
                    'error' => 'Permission-set access missing for External Credential.'
                }
            )
        );
        NativeFormsSetupController.ConnectionStatus blockedStatus =
            NativeFormsSetupController.getConnectionStatus(registrationRequest.orgId, true);
        System.assertEquals(false, blockedStatus.success);
        System.assert(blockedStatus.errorMessage.contains('setup access is not complete'));

        Test.setMock(
            HttpCalloutMock.class,
            new NativeFormsAwsMockFactory.RoutingMock()
                .addJsonResponse('/tenant/status', 200, buildStatusPayload(true, true, true))
                .addJsonResponse(
                    '/tenant/auth-health',
                    401,
                    new Map<String, Object>{
                        'success' => false,
                        'error' => 'Invalid tenant secret'
                    }
                )
        );
        NativeFormsSetupController.ConnectionStatus authFailureStatus =
            NativeFormsSetupController.getConnectionStatus(registrationRequest.orgId, true);
        System.assertEquals(true, authFailureStatus.success);
        System.assertEquals(false, authFailureStatus.tenantAuthVerified);
        System.assertEquals('not_verified', authFailureStatus.tenantAuthStatus);
        System.assert(authFailureStatus.tenantAuthErrorMessage.contains('tenant secret is incorrect'));

        Test.setMock(
            HttpCalloutMock.class,
            new NativeFormsAwsMockFactory.RoutingMock().addJsonResponse(
                '/tenant/disconnect',
                401,
                new Map<String, Object>{
                    'success' => false,
                    'error' => 'Unauthorized'
                }
            )
        );
        NativeFormsSetupController.DisconnectResult disconnectResult =
            NativeFormsSetupController.disconnectOrg(registrationRequest.orgId);
        System.assertEquals(false, disconnectResult.success);
        System.assert(disconnectResult.errorMessage.contains('no longer authorized'));
    }

    @IsTest
    static void statusPageLoadDoesNotProbeTenantSecretCredential() {
        String orgId = UserInfo.getOrganizationId().substring(0, 15);
        Test.setMock(
            HttpCalloutMock.class,
            new NativeFormsAwsMockFactory.RoutingMock().addJsonResponse(
                '/tenant/status',
                200,
                buildStatusPayload(true, false, false)
            )
        );

        Test.startTest();
        NativeFormsSetupController.ConnectionStatus statusResult =
            NativeFormsSetupController.getConnectionStatus(orgId, false);
        Test.stopTest();

        System.assertEquals(true, statusResult.success);
        System.assertEquals(false, statusResult.registered);
        System.assertEquals(false, statusResult.tenantAuthVerified);
        System.assertEquals('not_checked', statusResult.tenantAuthStatus);
        System.assertEquals(null, statusResult.tenantAuthErrorMessage);
    }

    @IsTest
    static void setupControllerHandlesThrownCalloutExceptionsGracefully() {
        NativeFormsSetupController.RegistrationRequest registrationRequest =
            new NativeFormsSetupController.RegistrationRequest();
        registrationRequest.orgId = UserInfo.getOrganizationId().substring(0, 15);

        NativeFormsSetupController.ClientCredentialsRequest credentialsRequest =
            new NativeFormsSetupController.ClientCredentialsRequest();
        credentialsRequest.orgId = registrationRequest.orgId;

        Test.setMock(HttpCalloutMock.class, NativeFormsAwsMockFactory.throwingCallout('Synthetic callout failure.'));

        NativeFormsSetupController.RegistrationResult registerResult =
            NativeFormsSetupController.registerOrg(JSON.serialize(registrationRequest));
        NativeFormsSetupController.RegistrationResult saveResult =
            NativeFormsSetupController.saveClientCredentials(JSON.serialize(credentialsRequest));
        NativeFormsSetupController.ConnectionStatus statusResult =
            NativeFormsSetupController.getConnectionStatus(registrationRequest.orgId, true);
        NativeFormsSetupController.DisconnectResult disconnectResult =
            NativeFormsSetupController.disconnectOrg(registrationRequest.orgId);

        System.assertEquals(false, registerResult.success);
        System.assert(registerResult.errorMessage.contains('could not generate the tenant secret'));
        System.assertEquals(false, saveResult.success);
        System.assert(saveResult.errorMessage.contains('could not prepare Salesforce authorization'));
        System.assertEquals(false, statusResult.success);
        System.assert(statusResult.errorMessage.contains('could not verify the current connection status'));
        System.assertEquals(false, disconnectResult.success);
        System.assert(disconnectResult.errorMessage.contains('could not disconnect this org right now'));
    }

    @IsTest
    static void homeViewLoadsAwsSummaryAndLocalAccessDetails() {
        Map<String, PermissionSet> permissionSetsByLabel = getManagedPermissionSets();
        System.assert(permissionSetsByLabel.containsKey('TwinaForms User'));

        User assignedUser = NativeFormsTestDataFactory.createActiveUser('Assigned', 'TwinaForms User');
        insert new PermissionSetAssignment(
            AssigneeId = assignedUser.Id,
            PermissionSetId = permissionSetsByLabel.get('TwinaForms User').Id
        );
        NativeFormsTestDataFactory.createForm('Home Usage One');
        NativeFormsTestDataFactory.createForm('Home Usage Two');

        Test.setMock(
            HttpCalloutMock.class,
            new NativeFormsAwsMockFactory.RoutingMock()
                .addJsonResponse('/tenant/status', 200, buildStatusPayload(true, true, true))
                .addJsonResponse('/tenant/auth-health', 200, new Map<String, Object>{ 'success' => true })
                .addJsonResponse('/tenant/home-summary', 200, buildHomeSummaryPayload(5, true))
        );

        Test.startTest();
        NativeFormsHomeController.HomeView view = NativeFormsHomeController.getHomeView();
        Test.stopTest();

        System.assertEquals(true, view.success);
        System.assert(
            String.isNotBlank(view.connectTabApiName) &&
            view.connectTabApiName.endsWith('NativeForms_Connect'),
            'Home should return a namespace-safe Connect tab api name.'
        );
        System.assertEquals('starter', view.plan.code);
        System.assertEquals(100, view.plan.maxForms);
        System.assertEquals('2 / 100', view.usage.formsUsageLabel);
        System.assert(view.usage.activeUsersCount >= 1);
        System.assertEquals(String.valueOf(view.usage.activeUsersCount) + ' / 5', view.usage.activeUsersLabel);
        System.assertEquals(true, view.connection.ready);
        System.assertEquals(true, view.connection.secretKeyConfigured);
        System.assertEquals(true, view.connection.permissionSetConfigured);
        System.assertEquals(true, view.access.adminAppOpen);
        System.assertEquals('https://twinaforms.com/compare', view.comparePlansUrl);
        System.assertEquals('https://twinaforms.com/upgrade', view.upgradeUrl);
        System.assertEquals(1, view.upgradeFeatures.size());
        System.assertEquals('Upgrade Available', view.upgradeFeatures[0].statusLabel);

        NativeFormsHomeController.AccessUserItem assignedItem = findAccessUser(view, assignedUser.Id);
        System.assertNotEquals(null, assignedItem);
        System.assertEquals(true, assignedItem.hasTwinaFormsUser);
    }

    @IsTest
    static void homeAccessManagementBlocksSeatLimitAndClosedAdminApp() {
        Map<String, PermissionSet> permissionSetsByLabel = getManagedPermissionSets();
        System.assert(permissionSetsByLabel.containsKey('TwinaForms User'));
        System.assert(permissionSetsByLabel.containsKey('TwinaForms Admin'));

        User targetUser = NativeFormsTestDataFactory.createActiveUser('Target', 'Seat User');

        Test.setMock(
            HttpCalloutMock.class,
            new NativeFormsAwsMockFactory.RoutingMock().addJsonResponse(
                '/tenant/home-summary',
                200,
                buildHomeSummaryPayload(0, false)
            )
        );

        try {
            NativeFormsHomeController.updatePermissionSetAccess(targetUser.Id, 'user', true);
            System.assert(false, 'Seat-limit enforcement should block the extra assignment.');
        } catch (AuraHandledException e) {
            assertAuraHandled(e, null);
        }

        try {
            NativeFormsHomeController.updatePermissionSetAccess(targetUser.Id, 'admin', true);
            System.assert(false, 'Closed admin-app flag should block admin assignment.');
        } catch (AuraHandledException e) {
            assertAuraHandled(e, null);
        }
    }

    @IsTest
    static void homeAccessManagementAddsAndRemovesUserAssignments() {
        Map<String, PermissionSet> permissionSetsByLabel = getManagedPermissionSets();
        System.assert(permissionSetsByLabel.containsKey('TwinaForms User'));

        User targetUser = NativeFormsTestDataFactory.createActiveUser('Access', 'Managed User');

        Test.setMock(
            HttpCalloutMock.class,
            new NativeFormsAwsMockFactory.RoutingMock().addJsonResponse(
                '/tenant/home-summary',
                200,
                buildHomeSummaryPayload(5, true)
            )
        );

        Test.startTest();
        NativeFormsHomeController.HomeView afterUserGrant =
            NativeFormsHomeController.updatePermissionSetAccess(targetUser.Id, 'user', true);
        NativeFormsHomeController.HomeView afterUserRemoval =
            NativeFormsHomeController.updatePermissionSetAccess(targetUser.Id, 'user', false);
        Test.stopTest();

        NativeFormsHomeController.AccessUserItem grantedUserItem = findAccessUser(afterUserGrant, targetUser.Id);
        NativeFormsHomeController.AccessUserItem removedUserItem = findAccessUser(afterUserRemoval, targetUser.Id);

        System.assertNotEquals(null, grantedUserItem);
        System.assertEquals(true, grantedUserItem.hasTwinaFormsUser);
        System.assertNotEquals(null, removedUserItem);
        System.assertEquals(false, removedUserItem.hasTwinaFormsUser);

        System.assertEquals(
            0,
            [
                SELECT COUNT()
                FROM PermissionSetAssignment
                WHERE AssigneeId = :targetUser.Id
                AND PermissionSetId = :permissionSetsByLabel.get('TwinaForms User').Id
            ]
        );
    }

    @IsTest
    static void homeAccessManagementAddsAdminAssignments() {
        Map<String, PermissionSet> permissionSetsByLabel = getManagedPermissionSets();
        System.assert(permissionSetsByLabel.containsKey('TwinaForms Admin'));

        User targetUser = NativeFormsTestDataFactory.createActiveUser('Admin', 'Managed User');

        Test.setMock(
            HttpCalloutMock.class,
            new NativeFormsAwsMockFactory.RoutingMock().addJsonResponse(
                '/tenant/home-summary',
                200,
                buildHomeSummaryPayload(5, true)
            )
        );

        Test.startTest();
        NativeFormsHomeController.HomeView afterAdminGrant =
            NativeFormsHomeController.updatePermissionSetAccess(targetUser.Id, 'admin', true);
        NativeFormsHomeController.HomeView afterAdminRemoval =
            NativeFormsHomeController.updatePermissionSetAccess(targetUser.Id, 'admin', false);
        Test.stopTest();

        NativeFormsHomeController.AccessUserItem grantedAdminItem = findAccessUser(afterAdminGrant, targetUser.Id);
        NativeFormsHomeController.AccessUserItem removedAdminItem = findAccessUser(afterAdminRemoval, targetUser.Id);
        System.assertNotEquals(null, grantedAdminItem);
        System.assertEquals(true, grantedAdminItem.hasTwinaFormsAdmin);
        System.assertNotEquals(null, removedAdminItem);
        System.assertEquals(false, removedAdminItem.hasTwinaFormsAdmin);

        System.assertEquals(
            0,
            [
                SELECT COUNT()
                FROM PermissionSetAssignment
                WHERE AssigneeId = :targetUser.Id
                AND PermissionSetId = :permissionSetsByLabel.get('TwinaForms Admin').Id
            ]
        );
    }

    @IsTest
    static void homeFailurePathAndAdminSettingsPersistenceWork() {
        Test.setMock(HttpCalloutMock.class, NativeFormsAwsMockFactory.throwingCallout('Synthetic callout failure.'));

        Test.startTest();
        NativeFormsHomeController.HomeView homeFailureView = NativeFormsHomeController.getHomeView();
        NativeFormsHomeController.HomeView accessFailureView = NativeFormsHomeController.getAccessManagementView();
        Test.stopTest();

        System.assertEquals(false, homeFailureView.success);
        System.assert(homeFailureView.errorMessage.contains('Plan and usage details are temporarily unavailable'));
        System.assertEquals(false, accessFailureView.success);
        System.assert(accessFailureView.errorMessage.contains('Plan and usage details are temporarily unavailable'));

        NativeFormsAdminController.FeatureSettings initialSettings =
            NativeFormsAdminController.getFeatureSettings();
        System.assertEquals(false, initialSettings.enableProConditionLogic);
        System.assertEquals(false, initialSettings.enableProFormulaFields);

        NativeFormsAdminController.FeatureSettings enabledSettings =
            new NativeFormsAdminController.FeatureSettings();
        enabledSettings.enableProConditionLogic = true;
        enabledSettings.enableProRepeatGroups = true;
        enabledSettings.enableProPrefillAliasReferences = true;
        enabledSettings.enableProAdvancedSubmitModes = true;
        enabledSettings.enableProFormulaFields = true;
        enabledSettings.enableProPostSubmitAutoLink = true;
        enabledSettings.enableProSfSecretCodeAuth = true;
        enabledSettings.enableProLoadFile = true;

        NativeFormsAdminController.FeatureSettings savedEnabledSettings =
            NativeFormsAdminController.saveFeatureSettings(JSON.serialize(enabledSettings));
        System.assertEquals(true, savedEnabledSettings.enableProConditionLogic);
        System.assertEquals(true, savedEnabledSettings.enableProFormulaFields);
        System.assertEquals(true, savedEnabledSettings.enableProLoadFile);

        NativeFormsAdminController.FeatureSettings disabledSettings =
            new NativeFormsAdminController.FeatureSettings();
        NativeFormsAdminController.FeatureSettings savedDisabledSettings =
            NativeFormsAdminController.saveFeatureSettings(JSON.serialize(disabledSettings));
        System.assertEquals(false, savedDisabledSettings.enableProConditionLogic);
        System.assertEquals(false, savedDisabledSettings.enableProFormulaFields);
        System.assertEquals(false, savedDisabledSettings.enableProLoadFile);
    }
}
