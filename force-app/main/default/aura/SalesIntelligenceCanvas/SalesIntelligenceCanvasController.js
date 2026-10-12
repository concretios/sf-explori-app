/**
 * @description       : 
 * @author            : Mayank Singh
 * @group             : 
 * @last modified on  : 10-07-2026
 * @last modified by  : Mayank Singh
**/
({
    doInit: function (component) {
        /*
         * Send only the record Id. The Canvas lifecycle handler resolves and signs
         * the Share ID, Product ID, and account server-side; the client must not supply them.
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