/**
 * @description : Canvas lifecycle handler for Sales Intelligence. Runs immediately before
 *                Salesforce signs the Canvas request: verifies the running user can access
 *                the Account in USER_MODE, then sends accountId and accountName. Organization,
 *                user and record context already travel in the signed request, and the
 *                gateway derives the short-lived share token from the verified organization Id.
 * @author      : Mayank Singh
**/
@SuppressWarnings('PMD.AvoidGlobalModifier')
global with sharing class CanvasLifecycleHandlerPost implements Canvas.CanvasLifecycleHandler {

    /*
     * 'global' is required: Canvas.CanvasLifecycleHandler is a global interface in the Canvas
     * system namespace (a public impl won't compile), and the managed package needs the
     * platform to invoke this handler across namespaces.
     */

    /**
     * @description Canvas lifecycle callback listing the context types to exclude from the
     *              signed request. Returns an empty set so all context is kept.
     * @return Set of context types to exclude (none).
     */
    global Set<Canvas.ContextTypeEnum> excludeContextTypes() {
        return new Set<Canvas.ContextTypeEnum>();
    }

    /**
     * @description Runs before Salesforce signs the Canvas request. Verifies the running user
     *              can access the Account in USER_MODE, then sends accountId and accountName.
     * @param renderContext The Canvas render context supplied by the platform.
     */
    global void onRender(Canvas.RenderContext renderContext) {
        if (renderContext == null || renderContext.getEnvironmentContext() == null) {
            throw new Canvas.CanvasRenderException('Sales Intelligence canvas context is unavailable.');
        }
        Canvas.EnvironmentContext env = renderContext.getEnvironmentContext();

        Map<String, Object> incoming = readExistingParameters(env.getParametersAsJSON());
        /*
         * Prefer the accountId key, fall back to recordId. containsKey keeps an absent
         * key as null rather than the literal string 'null'.
         */
        String requestedId = incoming.containsKey('accountId')
            ? String.valueOf(incoming.get('accountId'))
            : (incoming.containsKey('recordId') ? String.valueOf(incoming.get('recordId')) : null);
        Account account = findVisibleAccount(requestedId);
        if (account == null) {
            throw new Canvas.CanvasRenderException('Sales Intelligence can only open on an Account you can access.');
        }

        // Send accountId and accountName; the gateway derives everything else from the verified Org Id.
        env.setParametersAsJSON(JSON.serialize(new Map<String, Object>{
            'accountId' => String.valueOf(account.Id),
            'accountName' => account.Name
        }));
    }

    private static Map<String, Object> readExistingParameters(String json) {
        if (String.isBlank(json) || json == '{}') { return new Map<String, Object>(); }
        try {
            Map<String, Object> parsed = (Map<String, Object>) System.JSON.deserializeUntyped(json);
            return parsed == null ? new Map<String, Object>() : parsed;
        } catch (JSONException e) {
            return new Map<String, Object>();
        }
    }
    private static Account findVisibleAccount(String accountId) {
        if (String.isBlank(accountId)) { return null; }
        try {
            Id recId = Id.valueOf(accountId);
            if (recId.getSobjectType() != Account.SObjectType) { return null; }
        } catch (System.StringException e) {
            return null;
        }
        Id recId = Id.valueOf(accountId);
        List<Account> rows = SObjectSelector.selectAccountById(recId);
        return rows.isEmpty() ? null : rows[0];
    }
}
