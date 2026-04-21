import { LightningElement } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import listLogs from '@salesforce/apex/NativeFormsSubmissionLogsController.listLogs';
import getLogDetail from '@salesforce/apex/NativeFormsSubmissionLogsController.getLogDetail';
import getSubmissionLogStatus from '@salesforce/apex/NativeFormsSubmissionLogsController.getSubmissionLogStatus';
import saveSubmissionLogKeyPair from '@salesforce/apex/NativeFormsSubmissionLogsController.saveSubmissionLogKeyPair';
import syncSubmissionLogConfig from '@salesforce/apex/NativeFormsSubmissionLogsController.syncSubmissionLogConfig';
import getWorkspace from '@salesforce/apex/NativeFormsDesignerController.getWorkspace';

const HIDDEN_DETAIL_KEYS = new Set([
    'captchaToken',
    'gRecaptchaResponse',
    'g-recaptcha-response'
]);

const LS_PROJECT_KEY = 'nfLogsSelectedProjectId';
const LS_FORM_KEY = 'nfLogsSelectedFormId';

export default class NativeFormsSubmissionLogs extends LightningElement {
    isLoading = true;
    isLoadingMore = false;
    isLoadingDetail = false;
    errorMessage = '';
    logs = [];
    nextToken = null;
    selectedSubmissionId = '';
    selectedDetail = null;

    projectOptions = [];
    formOptions = [];
    selectedProjectId = '';
    selectedFormId = '';
    formVersionIdSet = new Set();

    outcome = '';
    dateFrom = '';
    dateTo = '';
    pageSize = 25;
    submissionLogSetupAttempted = false;

    connectedCallback() {
        this.initializePage();
    }

    async initializePage() {
        try {
            await this.ensureSubmissionLogSetup();
        } catch (error) {
            this.errorMessage = this.normalizeError(error);
        }

        const storedProjectId = this.readStored(LS_PROJECT_KEY);
        const storedFormId = this.readStored(LS_FORM_KEY);
        await this.loadWorkspace(storedProjectId, storedFormId);
        await this.loadLogs(true);
    }

    async loadWorkspace(projectId, formId) {
        try {
            const workspace = await getWorkspace({
                projectId: projectId || null,
                formId: formId || null,
                versionId: null
            });
            this.projectOptions = (workspace?.projects || []).map((option) => ({
                label: option.label,
                value: option.value
            }));
            this.formOptions = (workspace?.forms || []).map((option) => ({
                label: option.label,
                value: option.value
            }));
            this.selectedProjectId = workspace?.selectedProjectId || '';
            this.selectedFormId = workspace?.selectedFormId || '';
            const versionIds = Array.isArray(workspace?.versions)
                ? workspace.versions.map((version) => version.value).filter(Boolean)
                : [];
            this.formVersionIdSet = new Set(versionIds);
            this.writeStored(LS_PROJECT_KEY, this.selectedProjectId);
            this.writeStored(LS_FORM_KEY, this.selectedFormId);
        } catch (error) {
            this.errorMessage = this.normalizeError(error);
        }
    }

    async handleProjectChange(event) {
        const nextProjectId = event.detail?.value || '';
        await this.loadWorkspace(nextProjectId, null);
        await this.loadLogs(true);
    }

    async handleFormChange(event) {
        const nextFormId = event.detail?.value || '';
        await this.loadWorkspace(this.selectedProjectId, nextFormId);
        await this.loadLogs(true);
    }

    readStored(key) {
        try {
            return window.localStorage.getItem(key) || '';
        } catch (error) {
            return '';
        }
    }

    writeStored(key, value) {
        try {
            if (value) {
                window.localStorage.setItem(key, value);
            } else {
                window.localStorage.removeItem(key);
            }
        } catch (error) {
            // ignore storage failures
        }
    }

    get outcomeOptions() {
        return [
            { label: 'All', value: '' },
            { label: 'Success', value: 'success' },
            { label: 'Failed', value: 'failed' }
        ];
    }

    get hasLogs() {
        return this.logs.length > 0;
    }

    get loadedCount() {
        return this.logs.length;
    }

    get failedCount() {
        return this.logs.filter((item) => item.outcome === 'failed').length;
    }

    get successCount() {
        return this.logs.filter((item) => item.outcome === 'success').length;
    }

    get last24HoursCount() {
        const cutoff = Date.now() - (24 * 60 * 60 * 1000);
        return this.logs.filter((item) => {
            const submittedAtMs = Date.parse(item.submittedAt || '');
            return !Number.isNaN(submittedAtMs) && submittedAtMs >= cutoff;
        }).length;
    }

    get logRows() {
        return this.logs.map((item) => ({
            ...item,
            rowClass: item.submissionId === this.selectedSubmissionId ? 'log-row log-row--selected' : 'log-row',
            submittedAtLabel: this.formatDateTime(item.submittedAt),
            formDescription: item.formDescription || item.formId || '',
            outcomeLabel: this.toTitleCase(item.outcome),
            outcomeClass: this.badgeClass(item.outcome),
            failureStageLabel: item.failureStage === 'none' ? 'None' : this.toTitleCase(item.failureStage),
            detailModeLabel: item.detailMode === 'encrypted_detail' ? 'Encrypted detail' : 'Metadata only'
        }));
    }

    handleFilterChange(event) {
        const fieldName = event.target.name;
        const value = event.detail?.value ?? event.target.value ?? '';
        this[fieldName] = value;
    }

    async handleSearch() {
        await this.loadLogs(true);
    }

    async handleReset() {
        this.outcome = '';
        this.dateFrom = '';
        this.dateTo = '';
        await this.loadLogs(true);
    }

    async handleLoadMore() {
        await this.loadLogs(false);
    }

    async handleSelectRow(event) {
        const submissionId = event.currentTarget.dataset.id;
        if (!submissionId || submissionId === this.selectedSubmissionId) {
            return;
        }

        this.selectedSubmissionId = submissionId;
        await this.loadDetail(submissionId);
    }

    async handleCopySubmissionRef() {
        if (!this.selectedDetail?.submissionRef) {
            return;
        }

        try {
            await navigator.clipboard.writeText(this.selectedDetail.submissionRef);
            this.dispatchEvent(new ShowToastEvent({
                title: 'Copied',
                message: 'Submission reference copied to clipboard.',
                variant: 'success'
            }));
        } catch (error) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Copy failed',
                message: 'Unable to copy the submission reference from this browser context.',
                variant: 'error'
            }));
        }
    }

    async loadLogs(resetList) {
        if (resetList) {
            this.isLoading = true;
            this.logs = [];
            this.nextToken = null;
            this.selectedSubmissionId = '';
            this.selectedDetail = null;
        } else {
            this.isLoadingMore = true;
        }
        this.errorMessage = '';

        try {
            const result = await listLogs({
                formId: null,
                outcome: this.outcome || null,
                dateFrom: this.dateFrom || null,
                dateTo: this.dateTo || null,
                pageSize: this.pageSize,
                nextToken: resetList ? null : this.nextToken
            });

            if (result?.success !== true) {
                throw new Error(result?.errorMessage || 'Unable to load submission logs.');
            }

            let newLogs = Array.isArray(result.logs) ? result.logs : [];
            if (this.selectedFormId && this.formVersionIdSet.size > 0) {
                newLogs = newLogs.filter((log) => this.formVersionIdSet.has(log.formVersionId));
            }
            this.logs = resetList ? newLogs : [...this.logs, ...newLogs];
            this.nextToken = result?.nextToken || null;

            if (resetList && this.logs.length > 0) {
                this.selectedSubmissionId = this.logs[0].submissionId;
                await this.loadDetail(this.selectedSubmissionId);
            }
        } catch (error) {
            this.errorMessage = this.normalizeError(error);
        } finally {
            this.isLoading = false;
            this.isLoadingMore = false;
        }
    }

    async loadDetail(submissionId) {
        this.isLoadingDetail = true;
        this.errorMessage = '';

        try {
            const result = await getLogDetail({ submissionId });
            if (result?.success !== true) {
                throw new Error(result?.errorMessage || 'Unable to load submission log detail.');
            }

            const detailResolution = await this.resolveDetailPayload(result);
            this.selectedDetail = this.buildDetailView({
                ...result,
                decryptedDetailJson: detailResolution.decryptedDetailJson,
                detailAccessMessage: detailResolution.detailAccessMessage || result?.detailAccessMessage || ''
            });
        } catch (error) {
            this.selectedDetail = null;
            this.errorMessage = this.normalizeError(error);
        } finally {
            this.isLoadingDetail = false;
        }
    }

    async resolveDetailPayload(result) {
        if (result?.decryptedDetailJson) {
            return {
                decryptedDetailJson: result.decryptedDetailJson,
                detailAccessMessage: result?.detailAccessMessage || ''
            };
        }

        if (!result?.clientEncryptedDetailJson) {
            return {
                decryptedDetailJson: null,
                detailAccessMessage: result?.detailAccessMessage || ''
            };
        }

        if (!result?.privateKeyPkcs8B64) {
            return {
                decryptedDetailJson: null,
                detailAccessMessage: result?.detailAccessMessage || 'This org does not have the private submission-log key needed to decrypt this detail yet.'
            };
        }

        try {
            return {
                decryptedDetailJson: await this.decryptClientEncryptedDetail(
                    result.clientEncryptedDetailJson,
                    result.privateKeyPkcs8B64
                ),
                detailAccessMessage: ''
            };
        } catch (error) {
            return {
                decryptedDetailJson: null,
                detailAccessMessage: `This log is encrypted, but the detail could not be decrypted in this browser session. ${this.normalizeError(error)}`
            };
        }
    }

    buildDetailView(result) {
        const log = result?.log || {};
        const detailPayload = this.parseJson(result?.decryptedDetailJson);
        const fieldLabelMap = this.indexLabels(result?.fieldLabels, 'fieldKey');
        const repeatGroupLabelMap = this.indexLabels(result?.repeatGroupLabels, 'groupKey');
        const submittedPayload = detailPayload?.submittedPayload || {};
        const repeatGroups = submittedPayload?.repeatGroups || {};
        const submissionRows = this.buildFieldRows(submittedPayload, fieldLabelMap, ['repeatGroups']);
        const prefillRows = this.buildFieldRows(detailPayload?.prefillSnapshot, fieldLabelMap, []);
        const salesforceResults = this.buildSalesforceResults(detailPayload?.partialResults || []);
        const errorRows = this.buildGenericRows(detailPayload?.error, {
            message: 'Message',
            code: 'Code',
            commandKey: 'Command Key',
            commandType: 'Command Type',
            objectApiName: 'Object',
            statusCode: 'Status Code'
        });
        const userAgent = detailPayload?.technicalContext?.userAgent;
        const technicalRows = this.buildGenericRows({
            durationMs: detailPayload?.durationMs,
            ipAddress: detailPayload?.technicalContext?.ipAddress,
            device: this.detectDevice(userAgent),
            userAgent,
            securityMode: detailPayload?.technicalContext?.securityMode,
            planCode: detailPayload?.planCode,
            submissionId: detailPayload?.submissionId || log.submissionId,
            expiresAt: this.formatExpiry(log.expiresAt)
        }, {
            durationMs: 'Duration (ms)',
            ipAddress: 'IP Address',
            device: 'Device',
            userAgent: 'User Agent',
            securityMode: 'Security Mode',
            planCode: 'Plan',
            submissionId: 'Submission Id',
            expiresAt: 'Expires At'
        });
        const normalizedRepeatGroups = this.buildRepeatGroups(repeatGroups, fieldLabelMap, repeatGroupLabelMap);

        return {
            formHeading: result?.formTitle || log.formId || 'Submission',
            formId: log.formId,
            formVersionId: log.formVersionId,
            formDescription: log.formDescription || '',
            submissionRef: log.submissionRef,
            submittedAtLabel: this.formatDateTime(log.submittedAt),
            outcomeLabel: this.toTitleCase(log.outcome),
            outcomeClass: this.badgeClass(log.outcome),
            failureStageLabel: log.failureStage === 'none' ? 'None' : this.toTitleCase(log.failureStage),
            failureStageVisible: !!log.failureStage && log.failureStage !== 'none',
            detailModeLabel: log.detailMode === 'encrypted_detail' ? 'Encrypted detail' : 'Metadata only',
            metadataOnlyMessage: log.detailMode === 'metadata_only'
                ? 'This log stored only operational metadata for this org or plan, so the full private detail payload is not available.'
                : (result?.detailAccessMessage || ''),
            hasSubmissionRows: submissionRows.length > 0,
            submissionRows,
            hasRepeatGroups: normalizedRepeatGroups.length > 0,
            repeatGroups: normalizedRepeatGroups,
            hasPrefillRows: prefillRows.length > 0,
            prefillRows,
            hasSalesforceResults: salesforceResults.length > 0,
            salesforceResults,
            hasErrorRows: errorRows.length > 0,
            errorRows,
            hasTechnicalRows: technicalRows.length > 0,
            technicalRows,
            rawJson: detailPayload ? JSON.stringify(detailPayload, null, 2) : ''
        };
    }

    async decryptClientEncryptedDetail(clientEncryptedDetailJson, privateKeyPkcs8B64) {
        const subtle = window?.crypto?.subtle;
        if (!subtle) {
            throw new Error('Web Crypto is not available in this browser.');
        }

        const encryptedDetail = this.parseJson(clientEncryptedDetailJson);
        if (!encryptedDetail?.detailCiphertextB64 || !encryptedDetail?.detailIvB64 || !encryptedDetail?.detailEncryptedKeyB64) {
            throw new Error('Encrypted detail payload is incomplete.');
        }

        const privateKey = await subtle.importKey(
            'pkcs8',
            this.base64ToArrayBuffer(privateKeyPkcs8B64),
            {
                name: 'RSA-OAEP',
                hash: 'SHA-256'
            },
            false,
            ['decrypt']
        );

        const rawDataKey = await subtle.decrypt(
            { name: 'RSA-OAEP' },
            privateKey,
            this.base64ToArrayBuffer(encryptedDetail.detailEncryptedKeyB64)
        );

        const aesKey = await subtle.importKey(
            'raw',
            rawDataKey,
            { name: 'AES-CBC' },
            false,
            ['decrypt']
        );

        const plaintext = await subtle.decrypt(
            {
                name: 'AES-CBC',
                iv: new Uint8Array(this.base64ToArrayBuffer(encryptedDetail.detailIvB64))
            },
            aesKey,
            this.base64ToArrayBuffer(encryptedDetail.detailCiphertextB64)
        );

        return new TextDecoder().decode(plaintext);
    }

    base64ToArrayBuffer(base64Value) {
        const binary = atob(base64Value);
        const bytes = new Uint8Array(binary.length);
        for (let index = 0; index < binary.length; index += 1) {
            bytes[index] = binary.charCodeAt(index);
        }
        return bytes.buffer;
    }

    buildRepeatGroups(source, fieldLabelMap, repeatGroupLabelMap) {
        if (!source || typeof source !== 'object') {
            return [];
        }

        return Object.keys(source).map((groupKey) => {
            const groupPayload = source[groupKey] || {};
            const rows = Array.isArray(groupPayload.rows) ? groupPayload.rows : [];
            return {
                groupKey,
                label: repeatGroupLabelMap[groupKey] || this.prettyKey(groupKey),
                rowCountLabel: rows.length === 1 ? '1 row' : `${rows.length} rows`,
                rows: rows.map((row, index) => ({
                    key: `${groupKey}-${index}`,
                    label: `Row ${index + 1}`,
                    fields: this.buildFieldRows(row, fieldLabelMap, [])
                }))
            };
        }).filter((group) => group.rows.length > 0);
    }

    buildSalesforceResults(results) {
        if (!Array.isArray(results)) {
            return [];
        }

        return results.map((entry, index) => ({
            key: `result-${index}`,
            title: entry?.commandKey || entry?.type || `Result ${index + 1}`,
            rows: this.buildGenericRows(entry, {
                type: 'Command Type',
                objectApiName: 'Object',
                id: 'Record Id',
                found: 'Found',
                processedCount: 'Processed Count',
                createdIds: 'Created Ids',
                updatedIds: 'Updated Ids',
                deletedIds: 'Deleted Ids',
                skipped: 'Skipped',
                success: 'Success'
            })
        })).filter((item) => item.rows.length > 0);
    }

    buildFieldRows(source, labelMap, excludedKeys) {
        if (!source || typeof source !== 'object' || Array.isArray(source)) {
            return [];
        }

        return Object.keys(source)
            .filter((key) => !excludedKeys.includes(key))
            .map((key) => this.normalizeDisplayRow(
                key,
                labelMap[key] || this.prettyKey(key),
                source[key]
            ))
            .filter(Boolean);
    }

    buildGenericRows(source, labelOverrides) {
        if (!source || typeof source !== 'object' || Array.isArray(source)) {
            return [];
        }

        return Object.keys(source)
            .map((key) => this.normalizeDisplayRow(
                key,
                labelOverrides[key] || this.prettyKey(key),
                source[key]
            ))
            .filter(Boolean);
    }

    normalizeDisplayRow(key, label, rawValue) {
        if (this.shouldHideDetailKey(key)) {
            return null;
        }

        const formatted = this.formatDisplayValue(rawValue);
        if (formatted.hidden) {
            return null;
        }

        return {
            key,
            label,
            value: formatted.value,
            valueClass: formatted.multiline ? 'kv-value kv-value--multiline' : 'kv-value'
        };
    }

    shouldHideDetailKey(key) {
        return HIDDEN_DETAIL_KEYS.has(String(key || '').trim());
    }

    formatDisplayValue(value) {
        if (value === undefined) {
            return { hidden: true };
        }
        if (value === null || value === '') {
            return { value: 'Empty', multiline: false };
        }
        if (typeof value === 'boolean') {
            return { value: value ? 'Yes' : 'No', multiline: false };
        }
        if (Array.isArray(value)) {
            return {
                value: value.length === 0 ? 'Empty' : JSON.stringify(value, null, 2),
                multiline: true
            };
        }
        if (typeof value === 'object') {
            return {
                value: JSON.stringify(value, null, 2),
                multiline: true
            };
        }

        const stringValue = String(value);
        return {
            value: stringValue,
            multiline: stringValue.includes('\n') || stringValue.length > 90
        };
    }

    indexLabels(entries, keyName) {
        return (Array.isArray(entries) ? entries : []).reduce((map, entry) => {
            if (entry?.[keyName]) {
                map[entry[keyName]] = entry.label || entry[keyName];
            }
            return map;
        }, {});
    }

    parseJson(rawJson) {
        if (!rawJson) {
            return null;
        }

        try {
            return JSON.parse(rawJson);
        } catch (error) {
            return null;
        }
    }

    formatDateTime(value) {
        if (!value) {
            return 'Unknown';
        }

        const parsed = new Date(value);
        if (Number.isNaN(parsed.getTime())) {
            return value;
        }

        return new Intl.DateTimeFormat('en-GB', {
            year: 'numeric',
            month: 'short',
            day: '2-digit',
            hour: '2-digit',
            minute: '2-digit'
        }).format(parsed);
    }

    formatExpiry(expiresAt) {
        if (!expiresAt) {
            return null;
        }
        return this.formatDateTime(new Date(Number(expiresAt) * 1000).toISOString());
    }

    detectDevice(userAgent) {
        if (!userAgent || typeof userAgent !== 'string') {
            return undefined;
        }
        if (/iPhone/i.test(userAgent)) return 'iPhone';
        if (/iPad/i.test(userAgent)) return 'iPad';
        if (/Android/i.test(userAgent)) return 'Android';
        if (/Windows/i.test(userAgent)) return 'Windows';
        if (/Macintosh|Mac OS X/i.test(userAgent)) return 'Mac';
        if (/CrOS/i.test(userAgent)) return 'ChromeOS';
        if (/Linux/i.test(userAgent)) return 'Linux';
        return 'Other';
    }

    prettyKey(value) {
        return String(value || '')
            .replace(/([a-z])([A-Z])/g, '$1 $2')
            .replace(/[_-]+/g, ' ')
            .replace(/\s+/g, ' ')
            .trim()
            .replace(/\b\w/g, (character) => character.toUpperCase());
    }

    badgeClass(value) {
        return value === 'failed'
            ? 'status-badge status-badge--failed'
            : 'status-badge status-badge--success';
    }

    toTitleCase(value) {
        return this.prettyKey(value);
    }

    async ensureSubmissionLogSetup() {
        if (this.submissionLogSetupAttempted) {
            return;
        }
        this.submissionLogSetupAttempted = true;

        const status = await getSubmissionLogStatus();
        if (status?.success !== true || status?.detailedLogsIncludedByPlan !== true) {
            return;
        }

        let hasPublicKey = status?.hasPublicKey === true;
        let hasPrivateKey = status?.hasPrivateKey === true;

        if (!hasPublicKey || !hasPrivateKey) {
            const generated = await this.generateSubmissionLogKeyPair();
            const saved = await saveSubmissionLogKeyPair({
                publicKeyB64: generated.publicKeyB64,
                privateKeyPkcs8B64: generated.privateKeyB64,
                keyVersion: generated.keyVersion
            });
            hasPublicKey = saved?.hasPublicKey === true;
            hasPrivateKey = saved?.hasPrivateKey === true;
        }

        const encryptionReady = status?.encryptionStatus === 'ready';
        if (!encryptionReady || !status?.publicKeySyncedAt || !hasPublicKey || !hasPrivateKey) {
            await syncSubmissionLogConfig();
        }
    }

    async generateSubmissionLogKeyPair() {
        const subtle = window?.crypto?.subtle;
        if (!subtle) {
            throw new Error('This browser does not support Web Crypto key generation for submission logs.');
        }

        const keyPair = await subtle.generateKey(
            {
                name: 'RSA-OAEP',
                modulusLength: 2048,
                publicExponent: new Uint8Array([1, 0, 1]),
                hash: 'SHA-256'
            },
            true,
            ['encrypt', 'decrypt']
        );

        const publicKeyBuffer = await subtle.exportKey('spki', keyPair.publicKey);
        const privateKeyBuffer = await subtle.exportKey('pkcs8', keyPair.privateKey);

        return {
            publicKeyB64: this.arrayBufferToBase64(publicKeyBuffer),
            privateKeyB64: this.arrayBufferToBase64(privateKeyBuffer),
            keyVersion: 'v2'
        };
    }

    arrayBufferToBase64(buffer) {
        const bytes = new Uint8Array(buffer);
        let binary = '';
        bytes.forEach((byte) => {
            binary += String.fromCharCode(byte);
        });
        return btoa(binary);
    }

    normalizeError(error) {
        if (error?.body?.message) {
            return error.body.message;
        }
        if (error?.message) {
            return error.message;
        }
        return 'Something went wrong while loading submission logs.';
    }
}
