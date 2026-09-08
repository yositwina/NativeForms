import { LightningElement, track } from 'lwc';
import getWorkspace from '@salesforce/apex/NativeFormsThemesController.getWorkspace';
import ensureSampleThemes from '@salesforce/apex/NativeFormsThemesController.ensureSampleThemes';
import createTheme from '@salesforce/apex/NativeFormsThemesController.createTheme';
import cloneTheme from '@salesforce/apex/NativeFormsThemesController.cloneTheme';
import saveTheme from '@salesforce/apex/NativeFormsThemesController.saveTheme';
import deleteTheme from '@salesforce/apex/NativeFormsThemesController.deleteTheme';
import uploadLogo from '@salesforce/apex/NativeFormsThemesController.uploadLogo';
import uploadBackgroundImage from '@salesforce/apex/NativeFormsThemesController.uploadBackgroundImage';
import uploadFooterImage from '@salesforce/apex/NativeFormsThemesController.uploadFooterImage';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

const MAX_EMBEDDED_IMAGE_BYTES = 69 * 1024;
const MAX_EMBEDDED_IMAGE_LABEL = '69 KB';

export default class NativeFormsThemes extends LightningElement {
    isLoading = true;
    errorMessage = '';
    selectedThemeId;
    highlightedField = '';

    @track themes = [];
    @track selectedTheme = null;
    @track draft = null;

    fontOptions = [
        { label: 'Arial', value: 'Arial' },
        { label: 'Tahoma', value: 'Tahoma' },
        { label: 'Georgia', value: 'Georgia' },
        { label: 'Times New Roman', value: 'Times New Roman' },
        { label: 'Inter', value: 'Inter' },
        { label: 'Roboto', value: 'Roboto' },
        { label: 'Roboto Slab', value: 'Roboto Slab' },
        { label: 'Open Sans', value: 'Open Sans' },
        { label: 'Lato', value: 'Lato' },
        { label: 'Montserrat', value: 'Montserrat' },
        { label: 'Assistant', value: 'Assistant' },
        { label: 'Heebo', value: 'Heebo' },
        { label: 'Rubik', value: 'Rubik' },
        { label: 'Noto Sans Hebrew', value: 'Noto Sans Hebrew' },
        { label: 'Alef', value: 'Alef' },
        { label: 'Frank Ruhl Libre', value: 'Frank Ruhl Libre' }
    ];

    logoPositionOptions = [
        { label: 'Left', value: 'left' },
        { label: 'Center', value: 'center' },
        { label: 'Right', value: 'right' }
    ];

    async connectedCallback() {
        try {
            await ensureSampleThemes();
        } catch (error) {
            this.errorMessage = this.normalizeError(error);
        }
        this.loadWorkspace();
    }

    get themeOptions() {
        return (this.themes || []).map((theme) => ({
            ...theme,
            className: `theme-list__item${theme.value === this.selectedThemeId ? ' theme-list__item--selected' : ''}`
        }));
    }

    get previewOuterClass() {
        return 'preview-page';
    }

    get formWidthPercent() {
        const legacyWidths = { narrow: 70, standard: 80, wide: 90, full: 100 };
        const rawValue = this.draft?.formWidth;
        const parsed = Number(rawValue);
        if (Number.isFinite(parsed)) {
            return Math.min(100, Math.max(50, parsed));
        }
        return legacyWidths[String(rawValue || '').toLowerCase()] || 90;
    }

    get backgroundColorFieldClass() {
        return this.fieldWrapperClass('backgroundColor');
    }

    get backgroundGradientColorFieldClass() {
        return this.fieldWrapperClass('backgroundGradientColor');
    }

    get formBackgroundColorFieldClass() {
        return this.fieldWrapperClass('formBackgroundColor');
    }

    get formBorderColorFieldClass() {
        return this.fieldWrapperClass('formBorderColor');
    }

    get titleTextColorFieldClass() {
        return this.fieldWrapperClass('titleTextColor');
    }

    get sectionTitleTextColorFieldClass() {
        return this.fieldWrapperClass('sectionTitleTextColor');
    }

    get inputBackgroundColorFieldClass() {
        return this.fieldWrapperClass('inputBackgroundColor');
    }

    get buttonTextColorFieldClass() {
        return this.fieldWrapperClass('buttonTextColor');
    }

    get buttonBackgroundColorFieldClass() {
        return this.fieldWrapperClass('buttonBackgroundColor');
    }

    get previewOuterStyle() {
        const startColor = this.safeColor(this.draft?.backgroundColor, '#EEF3F8');
        const endColor = this.safeColor(this.draft?.backgroundGradientColor, startColor);
        if (this.draft?.backgroundImageUrl) {
            return `background:linear-gradient(180deg, rgba(255,255,255,.52), rgba(255,255,255,.52)), url("${this.escapeStyleUrl(this.draft.backgroundImageUrl)}") center/cover no-repeat, linear-gradient(180deg, ${startColor} 0%, ${endColor} 100%);`;
        }
        return `background:linear-gradient(180deg, ${startColor} 0%, ${endColor} 100%);`;
    }

    get previewFormStyle() {
        return [
            `background:${this.safeColor(this.draft?.formBackgroundColor, '#FFFFFF')}`,
            `border-color:${this.safeColor(this.draft?.formBorderColor, '#D5DFEA')}`,
            `max-width:${this.formWidthPercent}%`,
            `font-family:${this.safeFont(this.draft?.mainFont)}`,
            `color:${this.safeColor(this.draft?.mainTextColor, '#17324D')}`
        ].join(';');
    }

    get previewLogoWrapClass() {
        return `preview-logo-wrap preview-logo-wrap--${this.draft?.logoPosition || 'left'}`;
    }

    get previewLogoStyle() {
        const width = this.draft?.logoSizePx || 120;
        return `max-width:${width}px;`;
    }

    get previewTitleStyle() {
        return [
            `font-family:${this.safeFont(this.draft?.titleFont)}`,
            `font-size:${this.safeSize(this.draft?.titleFontSizePx, 23.04)}px`,
            `color:${this.safeColor(this.draft?.titleTextColor, '#17324D')}`
        ].join(';');
    }

    get previewCopyStyle() {
        return [
            `font-family:${this.safeFont(this.draft?.mainFont)}`,
            `font-size:${this.safeSize(this.draft?.mainTextSizePx, 14.4)}px`,
            `color:${this.safeColor(this.draft?.hintTextColor, '#5F6F89')}`
        ].join(';');
    }

    get previewSectionStyle() {
        return `border-color:${this.safeColor(this.draft?.formBorderColor, '#D5DFEA')};`;
    }

    get previewSectionTitleStyle() {
        return [
            `font-family:${this.safeFont(this.draft?.sectionTitleFont)}`,
            `font-size:${this.safeSize(this.draft?.sectionTitleFontSizePx, 14.4)}px`,
            `color:${this.safeColor(this.draft?.sectionTitleTextColor, '#17324D')}`
        ].join(';');
    }

    get previewLabelStyle() {
        return [
            `font-family:${this.safeFont(this.draft?.mainFont)}`,
            `font-size:${this.safeSize(this.draft?.mainTextSizePx, 14.4)}px`,
            `color:${this.safeColor(this.draft?.mainTextColor, '#17324D')}`
        ].join(';');
    }

    get previewInputStyle() {
        return [
            `border-radius:${this.safeSize(this.draft?.inputBorderRadiusPx, 14)}px`,
            `background:${this.safeColor(this.draft?.inputBackgroundColor, '#F6FAFE')}`,
            `border-color:${this.safeColor(this.draft?.inputBorderColor, '#C8D6E5')}`,
            `font-family:${this.safeFont(this.draft?.mainFont)}`,
            `font-size:${this.safeSize(this.draft?.mainTextSizePx, 14.4)}px`,
            `color:${this.safeColor(this.draft?.mainTextColor, '#17324D')}`
        ].join(';');
    }

    get previewButtonStyle() {
        return [
            `font-family:${this.safeFont(this.draft?.buttonFont)}`,
            `font-size:${this.safeSize(this.draft?.buttonFontSizePx, 14)}px`,
            `color:${this.safeColor(this.draft?.buttonTextColor, '#FFFFFF')}`,
            `background:${this.safeColor(this.draft?.buttonBackgroundColor, '#0F6CBD')}`
        ].join(';');
    }

    get hasFooterImage() {
        return Boolean(this.draft?.footerImageUrl);
    }

    get backgroundColorStyle() {
        return `background:${this.safeColor(this.draft?.backgroundColor, '#EEF3F8')};`;
    }

    get backgroundGradientColorStyle() {
        return `background:${this.safeColor(this.draft?.backgroundGradientColor, this.safeColor(this.draft?.backgroundColor, '#EEF3F8'))};`;
    }

    get formBackgroundColorStyle() {
        return `background:${this.safeColor(this.draft?.formBackgroundColor, '#FFFFFF')};`;
    }

    get formBorderColorStyle() {
        return `background:${this.safeColor(this.draft?.formBorderColor, '#D5DFEA')};`;
    }

    async loadWorkspace(themeId = this.selectedThemeId) {
        this.isLoading = true;
        this.errorMessage = '';
        try {
            const workspace = await getWorkspace({ themeId });
            this.themes = workspace.themes || [];
            this.selectedThemeId = workspace.selectedThemeId;
            this.selectedTheme = workspace.selectedTheme;
            this.draft = workspace.selectedTheme ? { ...workspace.selectedTheme } : null;
        } catch (error) {
            this.errorMessage = this.normalizeError(error);
        } finally {
            this.isLoading = false;
        }
    }

    async handleCreateTheme() {
        this.isLoading = true;
        try {
            const theme = await createTheme();
            this.selectedThemeId = theme.id;
            await this.loadWorkspace(theme.id);
            this.showToast('Theme created', 'A new reusable theme is ready to edit.', 'success');
        } catch (error) {
            this.errorMessage = this.normalizeError(error);
        } finally {
            this.isLoading = false;
        }
    }

    async handleCloneTheme() {
        if (!this.selectedThemeId) {
            return;
        }
        this.isLoading = true;
        try {
            const theme = await cloneTheme({ themeId: this.selectedThemeId });
            this.selectedThemeId = theme.id;
            await this.loadWorkspace(theme.id);
            this.showToast('Theme cloned', 'A copy of the selected theme is ready to edit.', 'success');
        } catch (error) {
            this.errorMessage = this.normalizeError(error);
        } finally {
            this.isLoading = false;
        }
    }

    handleSelectTheme(event) {
        this.selectedThemeId = event.currentTarget.dataset.id;
        this.loadWorkspace(this.selectedThemeId);
    }

    handleFieldChange(event) {
        if (!this.draft) {
            return;
        }
        const fieldName = event.target.dataset.field;
        const value = event.detail?.value ?? event.target?.value;
        this.draft = {
            ...this.draft,
            [fieldName]: value
        };
    }

    handleColorPickerChange(event) {
        if (!this.draft) {
            return;
        }
        const fieldName = event.target.dataset.field;
        this.draft = {
            ...this.draft,
            [fieldName]: event.target.value
        };
    }

    handlePreviewTargetClick(event) {
        const fieldName = event.target?.dataset?.target;
        if (!fieldName) {
            return;
        }
        event.stopPropagation();
        this.highlightedField = fieldName;
        window.clearTimeout(this.highlightTimeout);
        this.highlightTimeout = window.setTimeout(() => {
            this.highlightedField = '';
        }, 2200);

        const fieldWrapper = this.template.querySelector(`[data-focus-field="${fieldName}"]`);
        if (fieldWrapper) {
            fieldWrapper.scrollIntoView({ behavior: 'smooth', block: 'center' });
        }
    }

    async handleSaveTheme() {
        if (!this.draft) {
            return;
        }
        this.isLoading = true;
        try {
            const saved = await saveTheme({ inputJson: JSON.stringify(this.draft) });
            this.selectedThemeId = saved.id;
            await this.loadWorkspace(saved.id);
            this.showToast('Theme saved', 'Theme settings were updated.', 'success');
        } catch (error) {
            this.errorMessage = this.normalizeError(error);
        } finally {
            this.isLoading = false;
        }
    }

    async handleDeleteTheme() {
        if (!this.selectedThemeId) {
            return;
        }
        this.isLoading = true;
        try {
            await deleteTheme({ themeId: this.selectedThemeId });
            this.selectedThemeId = null;
            await this.loadWorkspace(null);
            this.showToast('Theme deleted', 'The selected theme was removed.', 'success');
        } catch (error) {
            this.errorMessage = this.normalizeError(error);
        } finally {
            this.isLoading = false;
        }
    }

    async handleLogoFileChange(event) {
        await this.uploadThemeImageFile(event, uploadLogo, 'Header image', 'Header image uploaded.');
    }

    async handleBackgroundImageFileChange(event) {
        await this.uploadThemeImageFile(event, uploadBackgroundImage, 'Background image', 'Background image uploaded.');
    }

    async handleFooterImageFileChange(event) {
        await this.uploadThemeImageFile(event, uploadFooterImage, 'Footer image', 'Footer image uploaded.');
    }

    async uploadThemeImageFile(event, uploadMethod, label, successMessage) {
        const file = event.target.files?.[0];
        if (!file || !this.selectedThemeId) {
            return;
        }
        if (!this.validateEmbeddedImageFile(file, label)) {
            event.target.value = null;
            return;
        }
        this.isLoading = true;
        try {
            const base64Data = await this.readFileAsBase64(file);
            const result = await uploadMethod({
                themeId: this.selectedThemeId,
                fileName: file.name,
                base64Data
            });
            this.draft = { ...result.theme };
            await this.loadWorkspace(this.selectedThemeId);
            this.showToast(label + ' uploaded', successMessage, 'success');
        } catch (error) {
            this.errorMessage = this.normalizeError(error);
        } finally {
            this.isLoading = false;
        }
    }

    safeColor(value, fallbackValue) {
        return value || fallbackValue;
    }

    safeSize(value, fallbackValue) {
        const parsed = Number(value);
        return Number.isFinite(parsed) && parsed > 0 ? parsed : fallbackValue;
    }

    safeFont(value) {
        return value || 'Inter, Arial, sans-serif';
    }

    readFileAsBase64(file) {
        return new Promise((resolve, reject) => {
            const reader = new FileReader();
            reader.onload = () => {
                const result = String(reader.result || '');
                const commaIndex = result.indexOf(',');
                resolve(commaIndex >= 0 ? result.substring(commaIndex + 1) : result);
            };
            reader.onerror = () => reject(new Error('Could not read the selected image file.'));
            reader.readAsDataURL(file);
        });
    }

    validateEmbeddedImageFile(file, label = 'Image') {
        if (!file) {
            return false;
        }
        if (file.size > MAX_EMBEDDED_IMAGE_BYTES) {
            this.errorMessage = `${label} is too large. Please upload an optimized image under ${MAX_EMBEDDED_IMAGE_LABEL}.`;
            this.showToast('Image too large', `Please upload an optimized image under ${MAX_EMBEDDED_IMAGE_LABEL}.`, 'error');
            return false;
        }
        return true;
    }

    normalizeError(error) {
        if (error?.body?.message) {
            return error.body.message;
        }
        if (error?.message) {
            return error.message;
        }
        return 'Something went wrong while loading themes.';
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    fieldWrapperClass(fieldName) {
        return `field-focus-wrap${this.highlightedField === fieldName ? ' field-focus-wrap--active' : ''}`;
    }

    escapeStyleUrl(value) {
        return String(value || '').replace(/\\/g, '\\\\').replace(/"/g, '\\"');
    }
}
