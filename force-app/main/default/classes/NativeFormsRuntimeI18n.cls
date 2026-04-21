public with sharing class NativeFormsRuntimeI18n {
    public static String normalizeLanguageCode(String languageCode) {
        String normalized = String.isBlank(languageCode) ? 'en' : languageCode.trim().toLowerCase();
        Set<String> allowed = new Set<String>{ 'en', 'he', 'es' };
        return allowed.contains(normalized) ? normalized : 'en';
    }

    public static String text(String languageCode, String key, String fallback) {
        Map<String, Object> dictionary = runtimeText(languageCode);
        String value = dictionary == null ? null : String.valueOf(dictionary.get(key));
        return String.isBlank(value) ? fallback : value;
    }

    public static Boolean matchesAnyLanguageValue(String key, String candidate) {
        String normalizedCandidate = String.isBlank(candidate) ? '' : candidate.trim();
        if (String.isBlank(normalizedCandidate) || String.isBlank(key)) {
            return false;
        }
        List<Map<String, Object>> dictionaries = new List<Map<String, Object>>{
            englishDictionary(),
            hebrewDictionary(),
            spanishDictionary()
        };
        for (Map<String, Object> dictionary : dictionaries) {
            String dictionaryValue = dictionary == null ? null : String.valueOf(dictionary.get(key));
            if (String.isNotBlank(dictionaryValue) && dictionaryValue.trim() == normalizedCandidate) {
                return true;
            }
        }
        return false;
    }

    public static Map<String, Object> runtimeText(String languageCode) {
        String normalized = normalizeLanguageCode(languageCode);
        if (normalized == 'he') {
            return hebrewDictionary();
        }
        if (normalized == 'es') {
            return spanishDictionary();
        }
        return englishDictionary();
    }

    private static Map<String, Object> englishDictionary() {
        return new Map<String, Object>{
            'submitting' => 'Submitting...',
            'submitSuccessTitle' => 'Submitted successfully',
            'submitErrorTitle' => 'Submit failed',
            'selectPlaceholder' => 'Select...',
            'repeatAddRow' => 'Add Row',
            'postSubmitContinuingIn' => 'Continuing in {seconds} seconds...',
            'captchaRequired' => 'Please complete the CAPTCHA.',
            'secretVerifyRequiredBeforeSubmit' => 'Verify the secret code before continuing.',
            'secretCodeIntroText' => 'Enter your email and click Enter. We will send you a 6-digit code before you can continue.',
            'secretCodeSentMessage' => 'If we found a matching contact, we sent a 6-digit code to that email.',
            'secretCodeInvalidMessage' => 'The code is invalid or expired. Try again or request a new code.',
            'secretCodeVerifiedMessage' => 'Code verified. You can continue with the form now.',
            'secretCodeSendButtonLabel' => 'Enter',
            'secretCodeVerifyButtonLabel' => 'Verify',
            'secretCodeResendButtonLabel' => 'Resend Code',
            'secretCodeEnterEmailFirst' => 'Enter your email first.',
            'secretCodeEnterEmailAndCodeFirst' => 'Enter your email and code first.',
            'secretCodeSendFailed' => 'We could not send the code right now.',
            'secretCodeVerifyFailed' => 'We could not verify the code right now.',
            'prefillLoadFailed' => 'We could not load prefill data for this form.',
            'dateInvalid' => 'Please enter a valid date in {format} format.',
            'dateMin' => 'Please enter a date on or after {date}.',
            'dateMax' => 'Please enter a date on or before {date}.',
            'dateReview' => 'Please review the date fields and try again.',
            'placeholderText' => 'Enter text',
            'placeholderTextarea' => 'Enter longer text',
            'placeholderNumber' => 'Enter number',
            'placeholderEmail' => 'name@example.com',
            'placeholderPhone' => 'Phone number',
            'placeholderUrl' => 'https://example.com',
            'fileBrowseSingle' => 'Browse file',
            'fileBrowseMultiple' => 'Browse files',
            'fileRemoveSingle' => 'Remove file',
            'fileRemoveMultiple' => 'Remove files',
            'fileUploading' => 'Uploading files...',
            'fileReady' => 'Ready',
            'fileReadyCount' => '{count} file(s) ready.',
            'fileUploadedFallbackName' => 'Uploaded file',
            'fileUploadPleaseWait' => 'Please wait for file uploads to finish.',
            'fileUploadRequired' => 'Please upload the required file before submitting.',
            'fileUploadFailed' => 'We could not upload this file. Please try again.',
            'fileUploadReview' => 'Please review the uploaded files and try again.',
            'fileUploadsConfigMissing' => 'File Uploads are not configured for this published form.',
            'fileAllowedTypes' => 'Allowed: {types}',
            'fileMaxSize' => 'Max size: {size} MB',
            'fileMultipleAllowed' => 'Multiple files allowed'
        };
    }

    private static Map<String, Object> hebrewDictionary() {
        return new Map<String, Object>{
            'submitting' => 'שולח...',
            'submitSuccessTitle' => 'הטופס נשלח בהצלחה',
            'submitErrorTitle' => 'שליחת הטופס נכשלה',
            'selectPlaceholder' => 'בחרו...',
            'repeatAddRow' => 'הוסף שורה',
            'postSubmitContinuingIn' => 'ממשיך בעוד {seconds} שניות...',
            'captchaRequired' => 'יש להשלים את ה-CAPTCHA.',
            'secretVerifyRequiredBeforeSubmit' => 'יש לאמת את הקוד הסודי לפני ההמשך.',
            'secretCodeIntroText' => 'הזינו את האימייל ולחצו על Enter. נשלח אליכם קוד בן 6 ספרות לפני שתוכלו להמשיך.',
            'secretCodeSentMessage' => 'אם מצאנו איש קשר תואם, שלחנו קוד בן 6 ספרות לאימייל הזה.',
            'secretCodeInvalidMessage' => 'הקוד שגוי או שפג תוקפו. נסו שוב או בקשו קוד חדש.',
            'secretCodeVerifiedMessage' => 'הקוד אומת. אפשר להמשיך עם הטופס.',
            'secretCodeSendButtonLabel' => 'שלח',
            'secretCodeVerifyButtonLabel' => 'אמת',
            'secretCodeResendButtonLabel' => 'שלח שוב קוד',
            'secretCodeEnterEmailFirst' => 'יש להזין קודם את האימייל.',
            'secretCodeEnterEmailAndCodeFirst' => 'יש להזין אימייל וקוד לפני ההמשך.',
            'secretCodeSendFailed' => 'לא הצלחנו לשלוח את הקוד כרגע.',
            'secretCodeVerifyFailed' => 'לא הצלחנו לאמת את הקוד כרגע.',
            'prefillLoadFailed' => 'לא הצלחנו לטעון נתוני מילוי מוקדם עבור הטופס הזה.',
            'dateInvalid' => 'יש להזין תאריך תקין בפורמט {format}.',
            'dateMin' => 'יש להזין תאריך בתאריך {date} או אחריו.',
            'dateMax' => 'יש להזין תאריך בתאריך {date} או לפניו.',
            'dateReview' => 'יש לבדוק את שדות התאריך ולנסות שוב.',
            'placeholderText' => 'הזן טקסט',
            'placeholderTextarea' => 'הזן טקסט ארוך',
            'placeholderNumber' => 'הזן מספר',
            'placeholderEmail' => 'name@example.com',
            'placeholderPhone' => 'מספר טלפון',
            'placeholderUrl' => 'https://example.com',
            'fileBrowseSingle' => 'בחר קובץ',
            'fileBrowseMultiple' => 'בחר קבצים',
            'fileRemoveSingle' => 'הסר קובץ',
            'fileRemoveMultiple' => 'הסר קבצים',
            'fileUploading' => 'מעלה קבצים...',
            'fileReady' => 'מוכן',
            'fileReadyCount' => '{count} קבצים מוכנים.',
            'fileUploadedFallbackName' => 'קובץ שהועלה',
            'fileUploadPleaseWait' => 'יש להמתין לסיום העלאת הקבצים.',
            'fileUploadRequired' => 'יש להעלות את הקובץ הנדרש לפני השליחה.',
            'fileUploadFailed' => 'לא הצלחנו להעלות את הקובץ. נסו שוב.',
            'fileUploadReview' => 'יש לבדוק את הקבצים שהועלו ולנסות שוב.',
            'fileUploadsConfigMissing' => 'העלאת קבצים אינה מוגדרת עבור טופס שפורסם זה.',
            'fileAllowedTypes' => 'סוגים מותרים: {types}',
            'fileMaxSize' => 'גודל מקסימלי: {size} MB',
            'fileMultipleAllowed' => 'מותר להעלות כמה קבצים'
        };
    }

    private static Map<String, Object> spanishDictionary() {
        return new Map<String, Object>{
            'submitting' => 'Enviando...',
            'submitSuccessTitle' => 'Formulario enviado correctamente',
            'submitErrorTitle' => 'No se pudo enviar el formulario',
            'selectPlaceholder' => 'Seleccionar...',
            'repeatAddRow' => 'Agregar fila',
            'postSubmitContinuingIn' => 'Continuando en {seconds} segundos...',
            'captchaRequired' => 'Completa el CAPTCHA.',
            'secretVerifyRequiredBeforeSubmit' => 'Verifica el código secreto antes de continuar.',
            'secretCodeIntroText' => 'Introduce tu correo y pulsa Entrar. Te enviaremos un código de 6 dígitos antes de continuar.',
            'secretCodeSentMessage' => 'Si encontramos un contacto coincidente, enviamos un código de 6 dígitos a ese correo.',
            'secretCodeInvalidMessage' => 'El código no es válido o ya expiró. Inténtalo otra vez o solicita uno nuevo.',
            'secretCodeVerifiedMessage' => 'Código verificado. Ya puedes continuar con el formulario.',
            'secretCodeSendButtonLabel' => 'Enviar',
            'secretCodeVerifyButtonLabel' => 'Verificar',
            'secretCodeResendButtonLabel' => 'Reenviar código',
            'secretCodeEnterEmailFirst' => 'Introduce primero tu correo.',
            'secretCodeEnterEmailAndCodeFirst' => 'Introduce tu correo y el código antes de continuar.',
            'secretCodeSendFailed' => 'No pudimos enviar el código en este momento.',
            'secretCodeVerifyFailed' => 'No pudimos verificar el código en este momento.',
            'prefillLoadFailed' => 'No pudimos cargar los datos de precarga de este formulario.',
            'dateInvalid' => 'Introduce una fecha válida con el formato {format}.',
            'dateMin' => 'Introduce una fecha igual o posterior a {date}.',
            'dateMax' => 'Introduce una fecha igual o anterior a {date}.',
            'dateReview' => 'Revisa los campos de fecha e inténtalo de nuevo.',
            'placeholderText' => 'Introducir texto',
            'placeholderTextarea' => 'Introducir texto largo',
            'placeholderNumber' => 'Introducir número',
            'placeholderEmail' => 'name@example.com',
            'placeholderPhone' => 'Número de teléfono',
            'placeholderUrl' => 'https://example.com',
            'fileBrowseSingle' => 'Buscar archivo',
            'fileBrowseMultiple' => 'Buscar archivos',
            'fileRemoveSingle' => 'Quitar archivo',
            'fileRemoveMultiple' => 'Quitar archivos',
            'fileUploading' => 'Subiendo archivos...',
            'fileReady' => 'Listo',
            'fileReadyCount' => '{count} archivo(s) listos.',
            'fileUploadedFallbackName' => 'Archivo subido',
            'fileUploadPleaseWait' => 'Espera a que terminen de subirse los archivos.',
            'fileUploadRequired' => 'Sube el archivo obligatorio antes de enviar.',
            'fileUploadFailed' => 'No pudimos subir este archivo. Inténtalo de nuevo.',
            'fileUploadReview' => 'Revisa los archivos subidos e inténtalo de nuevo.',
            'fileUploadsConfigMissing' => 'La carga de archivos no está configurada para este formulario publicado.',
            'fileAllowedTypes' => 'Permitidos: {types}',
            'fileMaxSize' => 'Tamaño máximo: {size} MB',
            'fileMultipleAllowed' => 'Se permiten varios archivos'
        };
    }
}
