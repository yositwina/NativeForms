@IsTest
private class NativeFormsConnectedOrgControllerTest {
    @TestSetup
    static void setupPermissions() {
        NativeFormsTestDataFactory.assignTwinaFormsUserPermissionSet();
        NativeFormsBootstrapV2Signer.getOrCreateSigningSecretB64();
    }

    @IsTest
    static void connectedImportViewReturnsOrgsAndSnapshots() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Test.setMock(
                HttpCalloutMock.class,
                new NativeFormsAwsMockFactory.RoutingMock()
                    .addJsonResponse(
                        '/connected-orgs',
                        200,
                        new Map<String, Object>{
                            'success' => true,
                            'groupId' => 'group_test',
                            'orgs' => new List<Object>{
                                new Map<String, Object>{
                                    'orgId' => '00Dxx0000000001',
                                    'orgName' => 'Sandbox',
                                    'status' => 'active'
                                }
                            }
                        }
                    )
                    .addJsonResponse(
                        '/portable-snapshots',
                        200,
                        new Map<String, Object>{
                            'success' => true,
                            'snapshots' => new List<Object>{
                                new Map<String, Object>{
                                    'sourceOrgId' => '00Dxx0000000001',
                                    'sourceOrgName' => 'Sandbox',
                                    'globalFormKey' => 'form35',
                                    'formName' => 'Contact Form'
                                }
                            }
                        }
                    )
            );

            Test.startTest();
            NativeFormsConnectedOrgController.ConnectedImportView view =
                NativeFormsConnectedOrgController.getConnectedImportView();
            Test.stopTest();

            System.assertEquals(true, view.success);
            System.assertEquals('group_test', view.groupId);
            System.assertEquals(1, view.orgs.size());
            System.assertEquals(1, view.snapshots.size());
        }
    }

    @IsTest
    static void startConnectAndGetSnapshotReturnExpectedFields() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Test.setMock(
                HttpCalloutMock.class,
                new NativeFormsAwsMockFactory.RoutingMock()
                    .addJsonResponse(
                        '/connected-orgs/connect/start',
                        200,
                        new Map<String, Object>{
                            'success' => true,
                            'connectUrl' => 'https://login.salesforce.com/services/oauth2/authorize'
                        }
                    )
                    .addJsonResponse(
                        '/portable-snapshots/00Dxx0000000001',
                        200,
                        new Map<String, Object>{
                            'success' => true,
                            'portableJson' => '{"packageType":"twinaformsFormDefinition"}',
                            'snapshot' => new Map<String, Object>{
                                'sourceOrgId' => '00Dxx0000000001',
                                'globalFormKey' => 'form35'
                            }
                        }
                    )
                    .addJsonResponse(
                        '/connected-orgs/disconnect',
                        200,
                        new Map<String, Object>{
                            'success' => true,
                            'disconnected' => true
                        }
                    )
            );

            Test.startTest();
            NativeFormsConnectedOrgController.ConnectedOrgStartResult startResult =
                NativeFormsConnectedOrgController.startConnect('https://login.salesforce.com', 'https://example.my.salesforce.com');
            NativeFormsConnectedOrgController.SnapshotPackageResult snapshotResult =
                NativeFormsConnectedOrgController.getSnapshotPackage('00Dxx0000000001', 'form35');
            Boolean disconnected = NativeFormsConnectedOrgController.disconnectOrg('00Dxx0000000001');
            Test.stopTest();

            System.assertEquals(true, startResult.success);
            System.assert(startResult.connectUrl.contains('/services/oauth2/authorize'));
            System.assertEquals(true, snapshotResult.success);
            System.assertEquals('{"packageType":"twinaformsFormDefinition"}', snapshotResult.portableJson);
            System.assertEquals(true, disconnected);
        }
    }

    @IsTest
    static void controllerReturnsFriendlyErrors() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Test.setMock(
                HttpCalloutMock.class,
                new NativeFormsAwsMockFactory.RoutingMock()
                    .addJsonResponse(
                        '/connected-orgs',
                        401,
                        new Map<String, Object>{
                            'success' => false,
                            'error' => 'Unauthorized: Bootstrap V2 signature is not available.'
                        }
                    )
                    .addJsonResponse(
                        '/connected-orgs/connect/start',
                        500,
                        new Map<String, Object>{
                            'success' => false,
                            'error' => 'snapshot service down'
                        }
                    )
            );

            Test.startTest();
            NativeFormsConnectedOrgController.ConnectedImportView view =
                NativeFormsConnectedOrgController.getConnectedImportView();
            NativeFormsConnectedOrgController.ConnectedOrgStartResult startResult =
                NativeFormsConnectedOrgController.startConnect(null, null);
            NativeFormsConnectedOrgController.SnapshotPackageResult missingSnapshot =
                NativeFormsConnectedOrgController.getSnapshotPackage('', '');
            Boolean blankDisconnectThrown = false;
            try {
                NativeFormsConnectedOrgController.disconnectOrg('');
            } catch (AuraHandledException e) {
                blankDisconnectThrown = true;
            }
            Test.stopTest();

            System.assertEquals(false, view.success);
            System.assert(view.errorMessage.contains('secure service access'));
            System.assertEquals(false, startResult.success);
            System.assert(String.isNotBlank(startResult.errorMessage));
            System.assertEquals(false, missingSnapshot.success);
            System.assert(String.isNotBlank(missingSnapshot.errorMessage));
            System.assertEquals(true, blankDisconnectThrown);
        }
    }
}
