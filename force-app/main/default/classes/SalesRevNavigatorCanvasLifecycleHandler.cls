/**
 * @description : Canvas lifecycle handler for Explori Sales RevNavigator. Runs immediately before
 *                Salesforce signs the Canvas request and rebuilds the Canvas parameters:
 *                - Account record pages: verifies the running user can read the Account in
 *                  USER_MODE, then sends exactly accountId (18-char) and accountName.
 *                - Home pages and non-Account record pages: sends no parameters ({}).
 *                - Inaccessible, deleted or malformed Account Ids: fails closed with a
 *                  CanvasRenderException.
 *                Organization, user and record context already travel in the signed request, and
 *                the gateway derives the short-lived share token from the verified organization Id.
 * @author      : Mayank Singh
**/
@SuppressWarnings('PMD.AvoidGlobalModifier')
global with sharing class SalesRevNavigatorCanvasLifecycleHandler implements Canvas.CanvasLifecycleHandler {

    /*
     * 'global' is required: Canvas.CanvasLifecycleHandler is a global interface in the Canvas
     * system namespace (a public impl won't compile), and the managed package needs the
     * platform to invoke this handler across namespaces.
     */

    private static final String NO_ACCESS_MESSAGE = 'Explori Sales RevNavigator can only open on an Account you can access.';
    private static final String NO_CONTEXT_MESSAGE = 'Explori Sales RevNavigator context is unavailable.';
    private static final String NO_PARAMETERS = '{}';

    /**
     * @description Canvas lifecycle callback listing the context types to exclude from the
     *              signed request. Returns an empty set so all context is kept.
     * @return Set of context types to exclude (none).
     */
    global Set<Canvas.ContextTypeEnum> excludeContextTypes() {
        return new Set<Canvas.ContextTypeEnum>();
    }

    /**
     * @description Runs before Salesforce signs the Canvas request. Reads accountId (falling back
     *              to recordId). With no Id, or an Id for a non-Account record, it sends no
     *              parameters. With an Account Id the running user can read in USER_MODE it sends
     *              accountId and accountName. Malformed or inaccessible Account Ids fail closed.
     * @param renderContext The Canvas render context supplied by the platform.
     */
    global void onRender(Canvas.RenderContext renderContext) {
        if (renderContext == null || renderContext.getEnvironmentContext() == null) {
            throw new Canvas.CanvasRenderException(NO_CONTEXT_MESSAGE);
        }
        Canvas.EnvironmentContext env = renderContext.getEnvironmentContext();

        String requestedId = readRequestedId(env.getParametersAsJSON());

        /* No record context (Home page): open without an Account. */
        if (String.isBlank(requestedId)) {
            env.setParametersAsJSON(NO_PARAMETERS);
            return;
        }

        Id recordId = parseIdOrFailClosed(requestedId);

        /* Record page for another object (Opportunity, Contact, ...): open without Account data. */
        if (recordId.getSobjectType() != Account.SObjectType) {
            env.setParametersAsJSON(NO_PARAMETERS);
            return;
        }

        Account account = findVisibleAccount(recordId);
        if (account == null) {
            throw new Canvas.CanvasRenderException(NO_ACCESS_MESSAGE);
        }

        /* Send only accountId and accountName; the gateway derives everything else from the verified Org Id. */
        env.setParametersAsJSON(JSON.serialize(new Map<String, Object>{
            'accountId' => String.valueOf(account.Id),
            'accountName' => account.Name
        }));
    }

    /**
     * @description Reads the requested Id from the incoming parameters, preferring accountId and
     *              falling back to recordId. The raw value is read first so a missing key or a JSON
     *              null stays null rather than becoming the literal string 'null'.
     * @param json The incoming Canvas parameters as JSON.
     * @return The requested Id as a string, or null when none was supplied.
     */
    private static String readRequestedId(String json) {
        Map<String, Object> incoming = readExistingParameters(json);
        Object rawId = incoming.containsKey('accountId') ? incoming.get('accountId') : incoming.get('recordId');
        return rawId == null ? null : String.valueOf(rawId);
    }

    /**
     * @description Parses the incoming Canvas parameters. Missing, empty or non-object JSON is
     *              treated as no parameters. The platform only accepts a JSON object in
     *              setParametersAsJSON, so the JSONException catch is a defensive guard.
     * @param json The incoming Canvas parameters as JSON.
     * @return The parsed parameters; never null.
     */
    private static Map<String, Object> readExistingParameters(String json) {
        try {
            Object parsed = String.isBlank(json) ? null : System.JSON.deserializeUntyped(json);
            return parsed instanceof Map<String, Object> ? (Map<String, Object>) parsed : new Map<String, Object>();
        } catch (JSONException e) {
            return new Map<String, Object>();
        }
    }

    /**
     * @description Converts the requested value to an Id, failing closed when it is not a valid
     *              Salesforce Id.
     * @param requestedId The non-blank requested Id string.
     * @return The parsed Id.
     */
    private static Id parseIdOrFailClosed(String requestedId) {
        try {
            return Id.valueOf(requestedId);
        } catch (System.StringException e) {
            throw new Canvas.CanvasRenderException(NO_ACCESS_MESSAGE);
        }
    }

    /**
     * @description Returns the Account if the running user can read it in USER_MODE. A missing,
     *              deleted or unshared record, or a user without Account access, is not visible.
     * @param accountId The Account Id to look up.
     * @return The visible Account, or null when it is not visible to the running user.
     */
    private static Account findVisibleAccount(Id accountId) {
        try {
            List<Account> rows = SObjectSelector.selectAccountById(accountId);
            return rows.isEmpty() ? null : rows[0];
        } catch (System.QueryException e) {
            /* USER_MODE denies object or field access with a QueryException: treat as not visible. */
            return null;
        }
    }
}
