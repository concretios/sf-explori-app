# Explori Sales RevNavigator

Brings Explori's RevNavigator dashboard inside Salesforce.

Salesforce package that embeds Explori Sales RevNavigator on Account with Canvas Signed Request (POST). Immediately before Salesforce signs the request, Apex reads the Account `WITH USER_MODE` and sends `accountId` and `accountName`. Organization, user and record context already travel in the signed request.

This is source for a future **2GP managed package**. Namespace is not registered yet. Do not hardcode `ns__` prefixes.

## What this package contains

| Area | Source | Role |
| --- | --- | --- |
| ECA / Canvas | `Explori_Sales_RevNavigator` | Canvas app, access method **Post**, URL path only |
| Account host | Aura `ExploriSalesRevNavigator` (App Builder label **Explori Sales RevNavigator**) | Passes `{ recordId }` only |
| Lifecycle | `CanvasLifecycleHandlerPost` | Sends `accountId` and `accountName`, after a `WITH USER_MODE` Account read |
| Selector | `SObjectSelector` | Single home for the package's SOQL, grouped by object. Every query runs `WITH USER_MODE` |

Canvas URL is the host path only, currently:

`https://si.staging.explori.com/`

Do not put `accountName` or any other parameter on that URL.

## Access model

| Metadata | Assign to | Grants |
| --- | --- | --- |
| Permission set `Explori_User` | Sales users | Apex class access to `CanvasLifecycleHandlerPost` only. No object permissions. Also listed on the ECA |

`Explori_User` grants no object permissions. Account access comes from the user's own profile or other permission sets, and the handler enforces it with a `WITH USER_MODE` query. A user who cannot read the Account cannot open the Canvas app.

## Prerequisites

- Salesforce CLI: [developer.salesforce.com/tools/salesforcecli](https://developer.salesforce.com/tools/salesforcecli)
- VS Code with Salesforce Extension Pack (optional)
- A scratch org or Developer Edition org with Dev Hub if you use scratch orgs

## Project layout

```
force-app/main/default/
  classes/                            CanvasLifecycleHandlerPost, SObjectSelector + tests
  aura/ExploriSalesRevNavigator/      Canvas host
  permissionsets/                     Explori_User
  externalClientApps/                 Explori_Sales_RevNavigator.eca-meta.xml (ECA)
  extlClntAppCanvasSettings/          Explori_Sales_RevNavigator_canvasSettings.ecaCanvas-meta.xml
  extlClntAppGlobalOauthSets/         Explori_Sales_RevNavigator_glbloauth.ecaGlblOauth-meta.xml
  extlClntAppOauthSettings/           Explori_Sales_RevNavigator_oauth.ecaOauth-meta.xml
  extlClntAppOauthSecuritySettings/   Explori_Sales_RevNavigator_oauthSecurity.ecaOauthSecurity-meta.xml
  extlClntAppOauthPolicies/           Explori_Sales_RevNavigator_oauthPlcy.ecaOauthPlcy-meta.xml
  extlClntAppPolicies/                Explori_Sales_RevNavigator_plcy.ecaPlcy-meta.xml
config/                               Scratch org definition
manifest/package.xml                  Retrieve manifest for the full package
sfdx-project.json
```

## Configure an org

1. Authorize the org: `sf org login web --alias explori-dev`
2. Deploy: `sf project deploy start --target-org explori-dev`
3. Assign `Explori_User` to people who open Account
4. Add **Explori Sales RevNavigator** to the Account Lightning page (App Builder, Account only)

When a package namespace exists, set `namespacePrefix` on `force:canvasApp` in `ExploriSalesRevNavigator.cmp`. Leave it unset until then.

## Common commands

```bash
sf org login web --alias explori-dev
sf org open --target-org explori-dev
sf project deploy start --target-org explori-dev
sf project retrieve start --manifest manifest/package.xml --target-org explori-dev
sf apex run test --target-org explori-dev --code-coverage
```

## Do not commit

- Consumer secret, `.env`, Heroku config
- `SKIP_AUTH` or mock Canvas servers
- Hardcoded `ns__` names

Retrieved ECA metadata may include a consumer **key**. That is expected. Never put the consumer **secret** in git.

## Tests

- `CanvasLifecycleHandlerPostTest` (`Canvas.Test`): no context, blank, malformed, non-Account and inaccessible Ids, restricted user, and the `accountId` + `accountName` payload.
- `SObjectSelectorTest`: Account found, not found, and `QueryException` for a user without Account access.

## Packaging notes

- Target: 2GP managed package, AppExchange security review
- One External Client App. Do not add a second Connected App
- New integrations must stay on External Client Apps
