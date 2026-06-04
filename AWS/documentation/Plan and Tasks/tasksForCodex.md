
1. missing contact field
I am testing teh layout to form feature, this is teh layout
but I found that the contact field is missing in the new form created (all otehrs there),  why, maybe becasue teh verification number with contact ? maybe bug is not related. 

2. missing mutli picklist option

We do not have multipicklist elment, or multi checkbox . I assume  we design it like this? 
We need to add support of multi picklist
I think it it better to add it to create mutlicheckbox element, (not using teh exiting picklist), multi picklist is hard to use on mobile.  
what do you think

Chatgpt:Yes — I agree with your direction.

For **Salesforce Multi-Select Picklist**, I would **not** create a mobile-style multi-picklist dropdown as the main UI. It is usually not friendly, especially on mobile.

Better design:

**Add a new element: “Multi Checkbox”**

This element visually shows several checkbox options, but maps to a Salesforce **Multi-Select Picklist** field.

How it should work:

1. **New element type**

   * `Multi Checkbox`
   * Used when user wants multiple selections.

2. **Salesforce mapping**

   * Can map only to:

     * Multi-Select Picklist fields
     * Maybe later: text fields, using comma/semicolon values

3. **Runtime submit format**

   * Salesforce multi-picklist expects values separated by semicolon:
   * Example:
     `Option A;Option B;Option C`

4. **Designer behavior**

   * When admin maps the element to a Salesforce multi-picklist field:

     * automatically load picklist values
     * show them as checkboxes
     * allow label override maybe later

5. **Mobile UX**

   * Much better than multi-select dropdown.
   * Easier to tap.
   * Clearer for public forms.

6. **Optional later feature**

   * Add layout setting:

     * vertical checkboxes
     * 2 columns
     * 3 columns on desktop, 1 column on mobile

So yes: **do not extend the existing Picklist element**.
Create a separate **Multi Checkbox** element that supports Salesforce multi-picklist fields.

This is cleaner for the product and easier for admins to understand.

