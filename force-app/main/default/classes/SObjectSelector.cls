/**
 * @description : Single home for the SOQL used by the Sales Intelligence package, grouped by
 *                object. Every query must run WITH USER_MODE so the running user's object,
 *                field and record access is enforced. Callers handle empty results; access
 *                failures surface as System.QueryException.
 * @author      : Mayank Singh
**/
public inherited sharing class SObjectSelector {

    /**
     * @description Returns the Account with the given Id if the running user can read it.
     * @param accountId The Account Id to look up.
     * @return A list with at most one Account; empty if the record does not exist or is not
     *         shared with the running user.
     */
    public static List<Account> selectAccountById(Id accountId) {
        return [SELECT Id, Name FROM Account WHERE Id = :accountId WITH USER_MODE LIMIT 1];
    }
}
