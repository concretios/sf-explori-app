# Explori Sales RevNavigator

Brings Explori's RevNavigator dashboard inside Salesforce.

This package adds a Canvas panel to the Account record page. When the panel loads, Salesforce sends a Canvas **signed request** (HTTP POST) to Explori. Just before Salesforce signs the request, Apex checks that the running user can read the Account and adds `accountId` and `accountName` to it.

This is source for a future **2GP managed package**. The namespace is not set yet.

## Components

| Component | Type | Purpose |
| --- | --- | --- |
| `CanvasLifecycleHandlerPost` | Apex class | Canvas lifecycle handler. Reads the Account `WITH USER_MODE` and sends `accountId` and `accountName`. Blocks rendering if the record is not an Account the user can read |
| `CanvasLifecycleHandlerPostTest` | Apex test | Covers the happy path, null context, blank, malformed, non-Account and missing Ids, and a user without Account access |
| `SObjectSelector` | Apex class | Holds all of the package's SOQL. Every query runs `WITH USER_MODE` with bind variables |
| `SObjectSelectorTest` | Apex test | Covers Account found, not found, and `QueryException` for a user without Account access |
| `SalesRevNavigator` | Aura bundle | Account page host (App Builder label **Explori Sales RevNavigator**). Wraps `force:canvasApp` and passes only `{ recordId }` |
| `Sales_RevNavigator` | External Client App | The ECA that owns the Canvas app |
| `Sales_RevNavigator_canvasSettings` | ECA Canvas settings | Access method **Post**, location **Aura**, lifecycle handler `CanvasLifecycleHandlerPost` |
| `Sales_RevNavigator_oauth` | ECA OAuth settings | OAuth scope `Basic` |
| `Sales_RevNavigator_User` | Permission set (label **Explori User**) | Apex class access to `CanvasLifecycleHandlerPost` only. No object or field permissions |

## Data flow

1. The Aura component `SalesRevNavigator` sends Canvas parameters containing only `{ recordId }`.
2. Salesforce calls `CanvasLifecycleHandlerPost.onRender` before it signs the request.
3. The handler checks the Id is an Account Id and queries it through `SObjectSelector` `WITH USER_MODE`. If the context is missing, the Id is blank, malformed or not an Account, the record isn't visible, or the user lacks Account read access, rendering fails. Nothing is sent.
4. The handler replaces the parameters with exactly `{ accountId, accountName }`. Incoming keys, including `recordId`, are dropped.
5. Salesforce signs the request and POSTs it to the canvas URL. Organization, user and record context already travel in the signed request, so the package doesn't add them.

The canvas URL is the host path only (currently `https://si.staging.explori.com/`). Don't add `accountName` or any other parameter to it.

## What stays in the Dev Hub

The ECA's OAuth consumer key and consumer secret belong to the Dev Hub org that owns the ECA. They are never committed or packaged.

`.forceignore` excludes four ECA file types:

| Pattern | Why |
| --- | --- |
| `**/*.ecaGlblOauth-meta.xml` | Global OAuth settings contain the consumer key and are org-specific. They stay in the Dev Hub |
| `**/*.ecaOauthSecurity-meta.xml` | OAuth security settings are set in the org, not shipped |
| `**/*.ecaOauthPlcy-meta.xml` | OAuth policies (permitted users, permission sets, refresh tokens) are set by each installing org's admin |
| `**/*.ecaPlcy-meta.xml` | App policies (enabled plugins, start page) are set by each installing org's admin |

`.forceignore` applies to deploy and retrieve, so these files won't come back into `force-app` on a retrieve.

## Post-install steps (customer admin)

1. In **Setup > External Client App Manager**, open **Explori Sales RevNavigator** and edit its **Policies**.
2. Under OAuth Policies, set **Permitted Users** to **Admin approved users are pre-authorized**.
3. Grant access to the ECA through a **profile or one of your own permission sets**. Don't use the packaged `Sales_RevNavigator_User` permission set for this.
4. Assign the **Explori User** permission set (`Sales_RevNavigator_User`) to the same users so they can run `CanvasLifecycleHandlerPost`.
5. In Lightning App Builder, add **Explori Sales RevNavigator** to the Account record page and activate the page.

Users also need Read access to Account (and to the specific record) from their own profile or permission sets. The package doesn't grant it.

## Packaging notes

- **The namespace isn't set yet.** Never hard-code `ns__` prefixes in Apex, Aura, metadata or tests.
- **`sf package create` rewrites `packageDirectories`.** Afterwards, check `sfdx-project.json` still has exactly one package directory with `"default": true`, and set it back if it doesn't.
- **Aura `.design` attributes must be `access="global"`.** Every attribute in `SalesRevNavigator.design` must be declared `access="global"` in `SalesRevNavigator.cmp`, or the managed package won't expose it in App Builder.
- **`force:canvasApp` and the namespace.** `developerName="Sales_RevNavigator"` resolves in an unmanaged org. Once a namespace exists, the subscriber org will need the namespace-qualified Canvas app, so `force:canvasApp` will need a `namespacePrefix` solution. Don't hard-code a prefix before then.
- **Re-retrieving the ECA drops `lifeCycleHandler`.** Retrieving `Sales_RevNavigator_canvasSettings.ecaCanvas-meta.xml` from the Dev Hub drops the `<lifeCycleHandler>CanvasLifecycleHandlerPost</lifeCycleHandler>` line. Add it back before you commit.
- Use one External Client App. Don't add a Connected App.

## Local development

Prerequisites: [Salesforce CLI](https://developer.salesforce.com/tools/salesforcecli) (`sf`) and a Dev Hub you're authorized to.

```bash
# Authorize the Dev Hub (one time)
sf org login web --set-default-dev-hub --alias <devhub-alias>

# Create a scratch org
sf org create scratch --definition-file config/project-scratch-def.json --alias explori-scratch --set-default --duration-days 7 --target-dev-hub <devhub-alias>

# Deploy the source
sf project deploy start --source-dir force-app --target-org explori-scratch

# Assign the permission set to yourself
sf org assign permset --name Sales_RevNavigator_User --target-org explori-scratch

# Run the Apex tests with coverage
sf apex run test --target-org explori-scratch --code-coverage --result-format human --wait 10

# Open the org
sf org open --target-org explori-scratch
```

The ECA policy files aren't deployed, so set the ECA policies in the scratch org by hand (see [Post-install steps](#post-install-steps-customer-admin)).

## Do not commit

- Consumer key or secret, `.env` files, tokens or passwords
- Real usernames or org Ids
- Mock Canvas servers or auth-skip flags
- Hard-coded `ns__` names
