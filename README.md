# IT Security As DevOps

## 4 Phases applied to Application Whitelisting

* Monitor

In this phase usage of applications across the enterprise is collected. No action should be taken unless something is specifically found to be malicious.

* Audit

In this phase the telemetry data collected during the monitoring phase is reviewed. Each application/vendor should be approved or denied. At the end of this phase a policy should be generated.

* Baseline

In this phase the policy generated in the audit phase is deployed to the enterprise in audit mode. This allows tuning and monitoring for false positive denies that if enforced would break devices. At the end of this phase the policy should be enforceable with little business impact.

* Enforce

In this phase the policy validated in the baseline phase is enforced. Once enforced, continuous monitoring for new unapproved denies should occur to anticipate problems before they impact business.


** Notes

https://aws.amazon.com/blogs/database/ek-is-the-new-elk-simplify-log-analytics-by-transforming-data-natively-in-amazon-elasticsearch-service/

notes:

windows:  https://docs.microsoft.com/en-us/azure/log-analytics/log-analytics-quick-collect-windows-computer

why the cloud as a security boundry

https://blogs.securiteam.com/index.php/archives/3689
