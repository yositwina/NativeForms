# Pro Features For Later

# Purpose
Capture Pro feature work that is intentionally out of scope for the current Pro V1 file-upload design.

This keeps the current `Pro features for started.md` focused on the first shippable version.


## Other Pro Enhancements To Keep Separate

The following stay outside the current File Uploads V1 scope:

+ Major
- File upload - See below
- export logs to CSV
- Signature add on as an item to forms = saved with detailed and served as an electornic signature / or create pdf with signatured
- Form Journey (see below plus , two column page, on eleft forms name, on right attibutesm , each arrtibute can call to new form. If so its automatically created on cavs with arrow
-JS CSS / Style)
- GMT for time Fields auto identify user submit location and GMT summer winter
-DB country city world wide probably on dynamodb 

+ Minor 
- richer submission filters
- chained logic based on prior prefill or submit outcomes
- more advanced post-submit navigation options (part of journey)
- more advanced verification and secure access flows (part of Hourney)
- broader admin and commercial control tooling

---

## Rule

Do not quietly pull these items into Pro V1 implementation.

If one of them becomes necessary, it should be re-evaluated as a deliberate scope expansion rather than an accidental addition.


# File Uploads - Later Scope

These are explicitly deferred beyond Pro V1:

- repeat-group file uploads
- per-row file uploads inside repeated records
- richer image previews
- thumbnails and inline preview cards
- advanced file validation rules per field
- max total upload size per submission
- broader file-type presets
- upload progress history in admin views
- admin storage lifecycle and cleanup controls
- orphaned staging-file recovery tooling
- alternative attachment-target strategies
- auto-inferred target selection
- attaching one upload field to multiple saved records
- non-Salesforce final file storage as a product option

---
 
# Journey Builder – UX Summary (Agreed Design)
Core Concept
A Journey is a simple, ordered sequence of forms that guide a user through a process.
•	No diagrams
•	No flow builder
•	No technical setup
👉 Just define what happens next after each form

Page Structure (reuse existing builder)
Left Panel
•	List of available forms
•	Action: “Add to Journey”

Center Canvas (Journey Steps)
•	Displays forms as vertical step cards
•	Each form = one step
•	Steps are:
o	Ordered top → bottom
o	Reorderable via drag & drop
Example:
[ Form A ]
[ Form B ]
[ Form C ]
👉 No free positioning
👉 No arrows or connections

Right Panel (Step Configuration)
When selecting a step, user configures:

1. Next Step Behavior
Default:
•	“Go to next step”
Optional:
•	Override next step:
o	Select another form

2. Conditional Routing (Optional)
User can define simple rules:
Example:
•	If Country = Israel → go to Form C
•	Else → go to Form D
Structure:
•	Field
•	Condition
•	Value
•	Target form
👉 Conditions are defined inside the step
👉 No separate “decision elements”

3. Data Passing (Prefill)
Label:
“Prefill next form” / “Pass data forward”
Default:
•	Automatic mapping of matching fields
Optional:
•	Editable field mapping:
o	Source field → Target field

UX Principles
•	Linear by default (works immediately)
•	Logic is optional (progressive complexity)
•	No technical language (no input/output, no flows)
•	No visual flow diagrams
•	All behavior configured per step (right panel)

User Mental Model
1.	Add forms
2.	Arrange order
3.	Click a step → define what happens next
👉 That’s the entire experience

Positioning
This is NOT like Salesforce Flow Builder
It is:
A simple way to build connected form journeys

What this enables
•	Multi-step processes
•	Smart routing between forms
•	Seamless user experience with prefilled data
•	Powerful behavior without complexity

Final Guiding Rule
If it feels like building a “flow” → it’s too complex
If it feels like defining “next steps” → it’s correct

If you want, next step I can turn this into:
•	a Codex-ready spec (tasks + components)
•	or a very concrete right-panel field list so implementation is fast and clean
•	