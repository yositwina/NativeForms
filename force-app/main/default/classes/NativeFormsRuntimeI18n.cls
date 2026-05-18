public with sharing class NativeFormsRuntimeI18n {
    public static String normalizeLanguageCode(String languageCode) {
        String normalized = String.isBlank(languageCode) ? 'en' : languageCode.trim().toLowerCase();
        Set<String> allowed = new Set<String>{ 'en', 'he', 'es', 'de', 'fr' };
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
            spanishDictionary(),
            germanDictionary(),
            frenchDictionary()
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
        if (normalized == 'de') {
            return germanDictionary();
        }
        if (normalized == 'fr') {
            return frenchDictionary();
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
            'prefillLoadingTitle' => 'Loading your saved details...',
            'prefillLoadingMessage' => 'Please wait while we prepare your form.',
            'prefillNoData' => 'No saved details found. You can continue with a blank form.',
            'prefillLoadFailedContinue' => 'We could not load saved details. You can still complete the form manually.',
            'prefillTimeout' => 'Loading saved details took too long.',
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
            'fileMultipleAllowed' => 'Multiple files allowed',
            'signatureClear' => 'Clear',
            'signatureRequired' => 'Please sign before submitting.',
            'signatureReview' => 'Please review the signature fields and try again.',
            'rowSignatureLabel' => 'Signature',
            'rowSignatureRequired' => 'Please sign every required row before submitting.',
            'rowSignatureReview' => 'Please review the row signatures and try again.',
            'signatureRepeatUnsupported' => 'Signature is not supported inside repeated records.'
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
            'signatureClear' => 'נקה',
            'signatureRequired' => 'יש לחתום לפני השליחה.',
            'signatureReview' => 'יש לבדוק את שדות החתימה ולנסות שוב.',
            'rowSignatureLabel' => 'Signature',
            'rowSignatureRequired' => 'Please sign every required row before submitting.',
            'rowSignatureReview' => 'Please review the row signatures and try again.',
            'signatureRepeatUnsupported' => 'חתימה אינה נתמכת בתוך רשומות חוזרות.',
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
            'signatureClear' => 'Borrar',
            'signatureRequired' => 'Firma antes de enviar.',
            'signatureReview' => 'Revisa los campos de firma e inténtalo de nuevo.',
            'rowSignatureLabel' => 'Signature',
            'rowSignatureRequired' => 'Please sign every required row before submitting.',
            'rowSignatureReview' => 'Please review the row signatures and try again.',
            'signatureRepeatUnsupported' => 'La firma no es compatible dentro de registros repetidos.',
            'fileAllowedTypes' => 'Permitidos: {types}',
            'fileMaxSize' => 'Tamaño máximo: {size} MB',
            'fileMultipleAllowed' => 'Se permiten varios archivos'
        };
    }

    private static Map<String, Object> germanDictionary() {
        return new Map<String, Object>{
            'submitting' => 'Wird gesendet...',
            'submitSuccessTitle' => 'Erfolgreich gesendet',
            'submitErrorTitle' => 'Senden fehlgeschlagen',
            'selectPlaceholder' => 'Auswählen...',
            'repeatAddRow' => 'Zeile hinzufügen',
            'postSubmitContinuingIn' => 'Weiterleitung in {seconds} Sekunden...',
            'captchaRequired' => 'Bitte füllen Sie das CAPTCHA aus.',
            'secretVerifyRequiredBeforeSubmit' => 'Bestätigen Sie den Sicherheitscode, bevor Sie fortfahren.',
            'secretCodeIntroText' => 'Geben Sie Ihre E-Mail-Adresse ein und klicken Sie auf Eingabe. Wir senden Ihnen einen 6-stelligen Code, bevor Sie fortfahren können.',
            'secretCodeSentMessage' => 'Wenn wir einen passenden Kontakt gefunden haben, senden wir einen 6-stelligen Code an diese E-Mail-Adresse.',
            'secretCodeInvalidMessage' => 'Der Code ist ungültig oder abgelaufen. Versuchen Sie es erneut oder fordern Sie einen neuen Code an.',
            'secretCodeVerifiedMessage' => 'Code bestätigt. Sie können jetzt mit dem Formular fortfahren.',
            'secretCodeSendButtonLabel' => 'Senden',
            'secretCodeVerifyButtonLabel' => 'Bestätigen',
            'secretCodeResendButtonLabel' => 'Code erneut senden',
            'secretCodeEnterEmailFirst' => 'Geben Sie zuerst Ihre E-Mail-Adresse ein.',
            'secretCodeEnterEmailAndCodeFirst' => 'Geben Sie Ihre E-Mail-Adresse und den Code ein, bevor Sie fortfahren.',
            'secretCodeSendFailed' => 'Wir konnten den Code im Moment nicht senden.',
            'secretCodeVerifyFailed' => 'Wir konnten den Code im Moment nicht bestätigen.',
            'prefillLoadingTitle' => 'Gespeicherte Daten werden geladen...',
            'prefillLoadingMessage' => 'Bitte warten Sie, während wir Ihr Formular vorbereiten.',
            'prefillNoData' => 'Keine gespeicherten Daten gefunden. Sie können mit einem leeren Formular fortfahren.',
            'prefillLoadFailedContinue' => 'Wir konnten gespeicherte Daten nicht laden. Sie können das Formular trotzdem manuell ausfüllen.',
            'prefillTimeout' => 'Das Laden gespeicherter Daten hat zu lange gedauert.',
            'prefillLoadFailed' => 'Wir konnten keine Vorbefüllungsdaten für dieses Formular laden.',
            'dateInvalid' => 'Bitte geben Sie ein gültiges Datum im Format {format} ein.',
            'dateMin' => 'Bitte geben Sie ein Datum am oder nach dem {date} ein.',
            'dateMax' => 'Bitte geben Sie ein Datum am oder vor dem {date} ein.',
            'dateReview' => 'Bitte prüfen Sie die Datumsfelder und versuchen Sie es erneut.',
            'placeholderText' => 'Text eingeben',
            'placeholderTextarea' => 'Längeren Text eingeben',
            'placeholderNumber' => 'Nummer eingeben',
            'placeholderEmail' => 'name@example.com',
            'placeholderPhone' => 'Telefonnummer',
            'placeholderUrl' => 'https://example.com',
            'fileBrowseSingle' => 'Datei auswählen',
            'fileBrowseMultiple' => 'Dateien auswählen',
            'fileRemoveSingle' => 'Datei entfernen',
            'fileRemoveMultiple' => 'Dateien entfernen',
            'fileUploading' => 'Dateien werden hochgeladen...',
            'fileReady' => 'Bereit',
            'fileReadyCount' => '{count} Datei(en) bereit.',
            'fileUploadedFallbackName' => 'Hochgeladene Datei',
            'fileUploadPleaseWait' => 'Bitte warten Sie, bis die Datei-Uploads abgeschlossen sind.',
            'fileUploadRequired' => 'Bitte laden Sie die erforderliche Datei hoch, bevor Sie senden.',
            'fileUploadFailed' => 'Wir konnten diese Datei nicht hochladen. Bitte versuchen Sie es erneut.',
            'fileUploadReview' => 'Bitte prüfen Sie die hochgeladenen Dateien und versuchen Sie es erneut.',
            'fileUploadsConfigMissing' => 'Datei-Uploads sind für dieses veröffentlichte Formular nicht konfiguriert.',
            'fileAllowedTypes' => 'Erlaubt: {types}',
            'fileMaxSize' => 'Maximale Größe: {size} MB',
            'fileMultipleAllowed' => 'Mehrere Dateien erlaubt',
            'signatureClear' => 'Löschen',
            'signatureRequired' => 'Bitte unterschreiben Sie vor dem Senden.',
            'signatureReview' => 'Bitte prüfen Sie die Signaturfelder und versuchen Sie es erneut.',
            'rowSignatureLabel' => 'Signature',
            'rowSignatureRequired' => 'Please sign every required row before submitting.',
            'rowSignatureReview' => 'Please review the row signatures and try again.',
            'signatureRepeatUnsupported' => 'Signatur wird in wiederholten Datensätzen nicht unterstützt.'
        };
    }

    private static Map<String, Object> frenchDictionary() {
        return new Map<String, Object>{
            'submitting' => 'Envoi...',
            'submitSuccessTitle' => 'Formulaire envoyé',
            'submitErrorTitle' => 'Échec de l’envoi',
            'selectPlaceholder' => 'Sélectionner...',
            'repeatAddRow' => 'Ajouter une ligne',
            'postSubmitContinuingIn' => 'Redirection dans {seconds} secondes...',
            'captchaRequired' => 'Veuillez compléter le CAPTCHA.',
            'secretVerifyRequiredBeforeSubmit' => 'Vérifiez le code secret avant de continuer.',
            'secretCodeIntroText' => 'Saisissez votre adresse e-mail et cliquez sur Entrée. Nous vous enverrons un code à 6 chiffres avant de continuer.',
            'secretCodeSentMessage' => 'Si nous trouvons un contact correspondant, nous envoyons un code à 6 chiffres à cette adresse e-mail.',
            'secretCodeInvalidMessage' => 'Le code est invalide ou a expiré. Réessayez ou demandez un nouveau code.',
            'secretCodeVerifiedMessage' => 'Code vérifié. Vous pouvez maintenant continuer le formulaire.',
            'secretCodeSendButtonLabel' => 'Envoyer',
            'secretCodeVerifyButtonLabel' => 'Vérifier',
            'secretCodeResendButtonLabel' => 'Renvoyer le code',
            'secretCodeEnterEmailFirst' => 'Saisissez d’abord votre adresse e-mail.',
            'secretCodeEnterEmailAndCodeFirst' => 'Saisissez votre adresse e-mail et le code avant de continuer.',
            'secretCodeSendFailed' => 'Nous ne pouvons pas envoyer le code pour le moment.',
            'secretCodeVerifyFailed' => 'Nous ne pouvons pas vérifier le code pour le moment.',
            'prefillLoadingTitle' => 'Chargement de vos données enregistrées...',
            'prefillLoadingMessage' => 'Veuillez patienter pendant la préparation de votre formulaire.',
            'prefillNoData' => 'Aucune donnée enregistrée trouvée. Vous pouvez continuer avec un formulaire vide.',
            'prefillLoadFailedContinue' => 'Nous ne pouvons pas charger les données enregistrées. Vous pouvez tout de même remplir le formulaire manuellement.',
            'prefillTimeout' => 'Le chargement des données enregistrées a pris trop de temps.',
            'prefillLoadFailed' => 'Nous ne pouvons pas charger les données de préremplissage pour ce formulaire.',
            'dateInvalid' => 'Veuillez saisir une date valide au format {format}.',
            'dateMin' => 'Veuillez saisir une date le {date} ou après.',
            'dateMax' => 'Veuillez saisir une date le {date} ou avant.',
            'dateReview' => 'Veuillez vérifier les champs de date et réessayer.',
            'placeholderText' => 'Saisir du texte',
            'placeholderTextarea' => 'Saisir un texte plus long',
            'placeholderNumber' => 'Saisir un nombre',
            'placeholderEmail' => 'name@example.com',
            'placeholderPhone' => 'Numéro de téléphone',
            'placeholderUrl' => 'https://example.com',
            'fileBrowseSingle' => 'Choisir un fichier',
            'fileBrowseMultiple' => 'Choisir des fichiers',
            'fileRemoveSingle' => 'Supprimer le fichier',
            'fileRemoveMultiple' => 'Supprimer les fichiers',
            'fileUploading' => 'Téléversement des fichiers...',
            'fileReady' => 'Prêt',
            'fileReadyCount' => '{count} fichier(s) prêt(s).',
            'fileUploadedFallbackName' => 'Fichier téléversé',
            'fileUploadPleaseWait' => 'Veuillez attendre la fin des téléversements.',
            'fileUploadRequired' => 'Veuillez téléverser le fichier requis avant de soumettre.',
            'fileUploadFailed' => 'Nous ne pouvons pas téléverser ce fichier. Veuillez réessayer.',
            'fileUploadReview' => 'Veuillez vérifier les fichiers téléversés et réessayer.',
            'fileUploadsConfigMissing' => 'Les téléversements de fichiers ne sont pas configurés pour ce formulaire publié.',
            'fileAllowedTypes' => 'Autorisés : {types}',
            'fileMaxSize' => 'Taille maximale : {size} MB',
            'fileMultipleAllowed' => 'Plusieurs fichiers autorisés',
            'signatureClear' => 'Effacer',
            'signatureRequired' => 'Veuillez signer avant de soumettre.',
            'signatureReview' => 'Veuillez vérifier les champs de signature et réessayer.',
            'rowSignatureLabel' => 'Signature',
            'rowSignatureRequired' => 'Please sign every required row before submitting.',
            'rowSignatureReview' => 'Please review the row signatures and try again.',
            'signatureRepeatUnsupported' => 'La signature ne fonctionne pas dans les enregistrements répétés.'
        };
    }
}
