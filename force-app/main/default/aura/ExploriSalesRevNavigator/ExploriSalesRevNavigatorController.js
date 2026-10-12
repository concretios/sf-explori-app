/**
 * @description       : Client controller for ExploriSalesRevNavigator; sends only the current record Id to the Canvas app.
 * @author            : Mayank Singh
 * @group             : 
 * @last modified on  : 10-12-2026
 * @last modified by  : Mayank Singh
**/
({
    doInit: function (component) {
        /*
         * Send only the record Id. CanvasLifecycleHandlerPost reads the Account WITH USER_MODE
         * and adds accountId and accountName before Salesforce signs the request.
         */
        const recordId = component.get("v.recordId") || "";
        component.set(
            "v.canvasParams",
            JSON.stringify({
                recordId: recordId
            })
        );
    }
})