@IsTest
private class NativeFormsAgentforceActionsTest {
    @TestSetup
    static void setupPermissions() {
        NativeFormsTestDataFactory.assignTwinaFormsUserPermissionSet();
        NativeFormsBootstrapV2Signer.getOrCreateSigningSecretB64();
    }

    @IsTest
    static void returnsLayoutChoicesWhenMoreThanOneLayoutExists() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            setAllProFlagsEnabled();
            setContactLayoutMock(true);

            NativeFormsAgentforceActions.PageLayoutFormRequest request =
                new NativeFormsAgentforceActions.PageLayoutFormRequest();
            request.objectApiName = 'Contact';

            List<NativeFormsAgentforceActions.PageLayoutFormResponse> responses =
                NativeFormsAgentforceActions.createFormFromPageLayout(
                    new List<NativeFormsAgentforceActions.PageLayoutFormRequest>{ request }
                );

            System.assertEquals(1, responses.size());
            System.assertEquals('NEEDS_LAYOUT_SELECTION', responses[0].status);
            System.assert(responses[0].layoutOptions.contains('Contact Layout'));
            System.assert(responses[0].layoutOptions.contains('Contact Compact Layout'));
            System.assertEquals(0, [SELECT COUNT() FROM NF_Form__c]);
        }
    }

    @IsTest
    static void createsDraftWhenLayoutIsSelected() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            setAllProFlagsEnabled();
            setContactLayoutMock(true);

            NativeFormsAgentforceActions.PageLayoutFormRequest request =
                new NativeFormsAgentforceActions.PageLayoutFormRequest();
            request.objectApiName = 'Contact';
            request.layoutNameOrKey = 'assigned:012000000000000AAA';
            request.formName = 'Agentforce Contact Layout Form';
            request.languageCode = 'en';

            List<NativeFormsAgentforceActions.PageLayoutFormResponse> responses =
                NativeFormsAgentforceActions.createFormFromPageLayout(
                    new List<NativeFormsAgentforceActions.PageLayoutFormRequest>{ request }
                );

            System.assertEquals(1, responses.size());
            NativeFormsAgentforceActions.PageLayoutFormResponse response = responses[0];
            System.assertEquals('CREATED', response.status);
            System.assertEquals('Contact', response.objectApiName);
            System.assertEquals('assigned:012000000000000AAA', response.layoutKey);
            System.assertEquals('Agentforce Contact Layout Form', response.formName);
            System.assert(String.isNotBlank(response.formId));
            System.assert(String.isNotBlank(response.versionId));
            System.assertEquals('/lightning/n/NativeForms_Designer', response.designerUrl);
            System.assert(response.importedFieldCount > 0);

            NF_Form__c formRecord = [
                SELECT Id, Description__c, Current_Draft_Version__c
                FROM NF_Form__c
                WHERE Id = :((Id) response.formId)
            ];
            System.assertEquals('Agentforce Contact Layout Form', formRecord.Description__c);
            System.assertEquals((Id) response.versionId, formRecord.Current_Draft_Version__c);
        }
    }

    @IsTest
    static void autoCreatesWhenOnlyOneLayoutExists() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            setAllProFlagsEnabled();
            setContactLayoutMock(false);

            NativeFormsAgentforceActions.PageLayoutFormRequest request =
                new NativeFormsAgentforceActions.PageLayoutFormRequest();
            request.objectApiName = 'Contact';
            request.mode = 'create';

            List<NativeFormsAgentforceActions.PageLayoutFormResponse> responses =
                NativeFormsAgentforceActions.createFormFromPageLayout(
                    new List<NativeFormsAgentforceActions.PageLayoutFormRequest>{ request }
                );

            System.assertEquals('CREATED', responses[0].status);
            System.assertEquals('assigned:012000000000000AAA', responses[0].layoutKey);
            System.assert(responses[0].formName.startsWith('TwinaForms Contact Layout Form'));
        }
    }

    private static void setAllProFlagsEnabled() {
        NativeFormsTenantEntitlements.EntitlementSnapshot snapshot =
            new NativeFormsTenantEntitlements.EntitlementSnapshot();
        snapshot.loadedSuccessfully = true;
        snapshot.orgId = UserInfo.getOrganizationId().substring(0, 15);
        snapshot.planCode = 'pro';
        snapshot.effectiveFeatureFlags = new Map<String, Object>{
            'enableProRepeatGroups' => true,
            'enableProLoadFile' => true,
            'enableProFormulaFields' => true,
            'enableProConditionLogic' => true,
            'enableProPostSubmitAutoLink' => true,
            'enableProUserVerification' => true,
            'enableProPrefillAliasReferences' => true,
            'enableProAdvancedSubmitModes' => true,
            'enableProPageLayoutClone' => true,
            'enableProElectronicSignature' => true,
            'enableProSubmissionPdf' => true,
            'enableProSurveyFields' => true,
            'enableProCustomJs' => true,
            'enableProButtonElements' => true,
            'enableProMergedDocument' => true
        };
        snapshot.effectiveLimits = new Map<String, Object>{
            'maxForms' => 1000,
            'maxSfUsers' => 5
        };
        NativeFormsTenantEntitlements.setCachedSnapshot(snapshot);
    }

    private static void setContactLayoutMock(Boolean includeSecondLayout) {
        List<Object> layouts = new List<Object>{
            new Map<String, Object>{
                'label' => 'Contact Layout',
                'value' => 'assigned:012000000000000AAA'
            }
        };
        if (includeSecondLayout) {
            layouts.add(new Map<String, Object>{
                'label' => 'Contact Compact Layout',
                'value' => 'assigned:012000000000001AAA'
            });
        }

        NativeFormsDesignerController.pageLayoutImportMetadataMock = new Map<String, Object>{
            'success' => true,
            'objectApiName' => 'Contact',
            'objectLabel' => 'Contact',
            'defaultLayoutKey' => 'assigned:012000000000000AAA',
            'layouts' => layouts,
            'layout' => new Map<String, Object>{
                'layoutKey' => 'assigned:012000000000000AAA',
                'layoutLabel' => 'Contact Layout',
                'objectApiName' => 'Contact',
                'objectLabel' => 'Contact',
                'sections' => new List<Object>{
                    new Map<String, Object>{
                        'heading' => 'Contact Details',
                        'fields' => new List<Object>{
                            new Map<String, Object>{
                                'apiName' => 'FirstName',
                                'label' => 'First Name',
                                'required' => false,
                                'editableForNew' => true,
                                'editableForUpdate' => true
                            },
                            new Map<String, Object>{
                                'apiName' => 'LastName',
                                'label' => 'Last Name',
                                'required' => true,
                                'editableForNew' => true,
                                'editableForUpdate' => true
                            },
                            new Map<String, Object>{
                                'apiName' => 'Email',
                                'label' => 'Email',
                                'required' => false,
                                'editableForNew' => true,
                                'editableForUpdate' => true
                            },
                            new Map<String, Object>{
                                'apiName' => 'Description',
                                'label' => 'Description',
                                'required' => false,
                                'editableForNew' => true,
                                'editableForUpdate' => true
                            }
                        }
                    }
                },
                'warnings' => new List<Object>()
            }
        };
    }
}
