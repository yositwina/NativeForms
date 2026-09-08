AppExchange Security Review Fees & FAQs

Paid and freemium solutions that you distribute on AppExchange are subject to security review fees. Here’s a list of security review scenarios and fees for paid and freemium solutions.

Paid and Freemium Solutions	
Scenario	Security Review Required?	Fee Per Attempt	Notes	
Intial security review or a retest associated with an initial review	Yes	$999	If your solution fails the review and you need to fix issues (either within the solution or external issues on the endpoint) and resubmit the solution, there will be a charge of $999 per resubmission attempt.	

Salesforce initiated periodic re-reviews	Yes	$999		

Partner submitted re-reviews	Yes	999		

New version of a solution that already passed security review	
No	
Not Applicable	All new managed-package versions that you create by using a version that already passed as a direct ancestor should be auto-approved. In the AppExchange Partner Console, the version will be tagged as "Ready to List." 

To confirm that a version is approved, follow the instructions in Check If Your Package Version Is Ready to List on AppExchange. lf you don’t see "Ready to List" beside the version, log a case.

To learn more about listing readiness, refer to Listing Readiness for Managed Packages. 
	

Review fails because of false positives:
 
1. No code changes needed, only justification for a false positive

2. False positives and true positives that require some code changes  	1. Yes
2. Yes	1. $0
2. $999	To resubmit, follow the instructions in Resubmit a Failed Security Review Where All Issues Are False Positives.	

Partner used their own pen test, but Salesforce finds additional vulnerabilities	
Yes	$999	
	
Special Scenarios for Paid and Freemium Solutions	

Multiple packages with the same namespace (2GP)	
Yes	$999	You can submit up to 4 packages (1 base package + 3 extension packages) under the same namespace for $999 per attempt. All packages must be 2GP packages and must be sold together as a single solution, not as individual apps. Additionally, each package must undergo a separate security review.	
Convert a free solution to a paid solution	No	For solutions submitted for security review on or before February 28, 2023, a fee of $2,700 applies. This includes re-reviews. This fee aligns with our policy prior to March 2023.


Example: Your solution took 2 attempts to pass the initial or re-review as a free solution. You pay $2,700.


For solutions submitted for security review after February 28, 2023, the fee is $999 multiplied by the number of attempts taken to pass the review as a free solution.


Example: Your solution took 2 attempts to pass the review as a free solution. You pay 2 x $999 = $1998.	1. Contact your account representative (Partner Account Manager) or Log a Case to speak with our team and sign a Partner Application Distribution Agreement.


2. Once the agreement is executed, your account representative will provide instructions on how to update your application listing to a paid model.


3. Log a case with the Security Review Operations team and pay the submission fees. After completing these steps, we can convert your free solution to a paid solution.	

Free solutions that you distribute on AppExchange are subject to a nominal security review fee. Here’s a list of security review scenarios and fees for free solutions.

Free Solutions	
Scenario	Security Review Required?	Fee Per Attempt	Notes	
Intial security review or a retest associated with an initial review	Yes	$1	You must request a fee-waiver code only after your listing's pricing plan has been approved by your partner account manager. The code is valid for one-time use only. See the FAQs section for more details.	

Salesforce initiated periodic re-reviews	Yes	$1	

Partner submitted re-reviews	Yes	$1	

New version of a solution that already passed security review	
No	Not Applicable	All new managed-package versions that you create by using a version that already passed as a direct ancestor should be auto-approved. In the AppExchange Partner Console, the version will be tagged as "Ready to List." 

To confirm that a version is approved, follow the instructions in Check If Your Package Version Is Ready to List on AppExchange. lf you don’t see "Ready to List" beside the version, log a case.

To learn more about listing readiness, refer to Listing Readiness for Managed Packages. 
	

Review fails because of false positives:
 
1. No code changes needed, only justification for a false positive

2. False positives and true positives that require some code changes	1. Yes
2. Yes	1. $0
2. $1	To resubmit, follow the instructions inResubmit a Failed Security Review Where All Issues Are False Positives.	

FAQs

Find answers to common questions about the AppExchange security review.

Q: Are free solutions subject to security review fees?
To help foster innovation, AppExchange solutions offered for free to all customers are only subject to a $1 security review submission fee. ISV partners must request a fee-waiver code. If a free solution is later converted to a paid solution, fees are charged when you convert the solution.

Q: How do I request a security review fee waiver for a free solution?
Before requesting a fee-waiver code, make sure your listing has an approved pricing plan showing that the solution will be offered free of charge on AppExchange. This business plan must be approved by your partner account manager, since the security review team can't approve business plans. For assistance with business plan approval, reach out to your account manager or sales representative. If you don't have an account manager or sales representative, log a case in the Salesforce Partner Community with Product: Partner Community & AppExchange and Topic: AppExchange Listing Approval Process.

To request a fee-waiver code:

1. Log a support case from the Salesforce Partner Community with the subject AppExchange Security Review Fee Waiver Request. 
2. Provide either (1) a link to your listing preview, (2) the Subscriber Package ID (begins with the prefix “033”), or (3) the Package Version ID (begins with the prefix “04t”). 

After you receive your code, enter it on the submission payment page in the Security Review Wizard. You'll receive a $998 discount. Please note that you will still need to pay a $1 fee, even with the waiver code.

Q: Who should I contact if I have questions about my listing’s pricing plan approval?
Reach out to your account manager, or log a support case in the Salesforce Partner Community with the subject line “AppExchange Listing Pricing Plan Approval”.

Q: Do Salesforce Labs solutions get charged a fee for security review? 
Salesforce Labs has always paid for security reviews of their solutions, with an internal budget allocation. They’ll continue to do so with the current fee structure. 

Q: What criteria does Salesforce use to identify when a periodic re-review is needed? 
To determine which listed solutions are due for re-review, we run risk-factor reports. If your solution shows significant change, it’s likely that we’ll conduct a re-review. However, there’s still a chance that your solution does not fit these criteria, in which case your solution won’t be called for a periodic re-review.

Q: Why aren’t all vulnerabilities identified in the first round of security review in some instances? 
Each review is time-boxed to a specific number of hours based on the solution size. This approach has two key benefits for partners. It helps to lower the costs passed on to partners and reduce review queue times. The downside of time-boxing is that we aren’t always able to identify every instance of a security issue or initially detect all issue types. We instruct partners to interpret the security review findings as representative examples of the types of issues that must be fixed.

Optimally, partners identify vulnerabilities before submitting a solution for security review. To make that easier, we continually strive to improve the review process and partner tools. The  Salesforce Code Analyzer is one example. 

How can I learn more?

Ask our Salesforce experts questions in the Partner Community Alert thread.
