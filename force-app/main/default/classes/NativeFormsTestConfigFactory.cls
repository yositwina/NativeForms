@IsTest
public class NativeFormsTestConfigFactory {
    public static String json(Map<String, Object> value) {
        return JSON.serialize(value == null ? new Map<String, Object>() : value);
    }

    public static String basicUiSettingsJson() {
        return json(new Map<String, Object>{
            'languageCode' => 'en',
            'submitLabel' => 'Submit',
            'submitSuccessMessage' => 'Your form was submitted successfully.',
            'postSubmitAutoLinkEnabled' => false
        });
    }

    public static String textFieldConfigJson() {
        return json(new Map<String, Object>{
            'required' => false,
            'fieldBehavior' => 'editable',
            'labelPosition' => 'above',
            'defaultValue' => '',
            'placeholderText' => 'Enter text'
        });
    }

    public static String checkboxConfigJson(Boolean checkedValue) {
        Boolean normalizedChecked = checkedValue == true;
        return json(new Map<String, Object>{
            'required' => false,
            'fieldBehavior' => 'editable',
            'labelPosition' => 'inline',
            'defaultValue' => String.valueOf(normalizedChecked).toLowerCase(),
            'checked' => normalizedChecked
        });
    }

    public static String sectionConfigJson(Integer columns) {
        return json(new Map<String, Object>{
            'columns' => columns == null ? 2 : columns
        });
    }

    public static String containerChildConfigJson(Integer sectionColumn) {
        Map<String, Object> config = new Map<String, Object>();
        if (sectionColumn != null) {
            config.put('sectionColumn', sectionColumn);
        }
        return json(config);
    }

    public static String formulaFieldConfigJson(String expression) {
        return json(new Map<String, Object>{
            'required' => false,
            'fieldBehavior' => 'editable',
            'labelPosition' => 'above',
            'defaultValue' => '',
            'isFormula' => true,
            'formulaExpression' => String.isBlank(expression) ? 'IF({checkbox1} == true, "Yes", "No")' : expression
        });
    }

    public static String fileUploadConfigJson(String targetSubmitActionKey) {
        Map<String, Object> config = new Map<String, Object>{
            'labelPosition' => 'above',
            'required' => false
        };
        if (!String.isBlank(targetSubmitActionKey)) {
            config.put('targetSubmitActionKey', targetSubmitActionKey);
        }
        return json(config);
    }

    public static String repeatGroupConfigJson() {
        return json(new Map<String, Object>{
            'maxRows' => 10,
            'allowDelete' => true
        });
    }
}
