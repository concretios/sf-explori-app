/**
 * @description : Tests for SObjectSelector. Verifies each query returns the expected rows and
 *                that WITH USER_MODE denies users without object access.
 * @author      : Mayank Singh
 */
@IsTest
private class SObjectSelectorTest {
    // Well-formed Account Id built from the key prefix so it is not hardcoded.
    private static final Id ABSENT_ACCOUNT_ID = Id.valueOf(
        Account.SObjectType.getDescribe(SObjectDescribeOptions.DEFERRED).getKeyPrefix()
            + '0'.repeat(12) + 'AAA'
    );

    // The running test user, who can read the Accounts the test inserts.
    private static User currentUser() {
        return new User(Id = UserInfo.getUserId());
    }

    @IsTest
    static void selectAccountByIdReturnsMatchingAccount() {
        Account acct = new Account(Name = 'Acme Selector Co');
        insert acct;

        List<Account> rows;
        Test.startTest();
        System.runAs(currentUser()) {
            rows = SObjectSelector.selectAccountById(acct.Id);
        }
        Test.stopTest();

        Assert.areEqual(1, rows.size(), 'Exactly one Account should be returned');
        Assert.areEqual(acct.Id, rows[0].Id, 'Returned Account Id should match');
        Assert.areEqual('Acme Selector Co', rows[0].Name, 'Returned Account Name should match');
    }

    @IsTest
    static void selectAccountByIdNotFoundReturnsEmpty() {
        List<Account> rows;
        Test.startTest();
        System.runAs(currentUser()) {
            rows = SObjectSelector.selectAccountById(ABSENT_ACCOUNT_ID);
        }
        Test.stopTest();

        Assert.isTrue(rows.isEmpty(), 'A non-existent Account Id should return no rows');
    }

    @IsTest
    static void selectAccountByIdWithoutAccessThrows() {
        Account acct = new Account(Name = 'Restricted Selector Co');
        insert acct;

        Profile minimumAccess = [SELECT Id FROM Profile WHERE Name = 'Minimum Access - Salesforce' LIMIT 1];
        String uniqueKey = String.valueOf(Math.abs(Crypto.getRandomInteger()));
        User restricted = new User(
            ProfileId = minimumAccess.Id,
            Username = 'selector.restricted.' + uniqueKey + '@example.com',
            Alias = 'selrst',
            Email = 'selector.restricted@example.com',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            LastName = 'Restricted',
            LocaleSidKey = 'en_US',
            TimeZoneSidKey = 'America/Los_Angeles'
        );
        insert restricted;

        Test.startTest();
        System.runAs(restricted) {
            try {
                SObjectSelector.selectAccountById(acct.Id);
                Assert.fail('Expected QueryException for a user without Account Read');
            } catch (System.QueryException e) {
                Assert.isNotNull(e.getMessage(), 'USER_MODE query should deny Account access');
            }
        }
        Test.stopTest();
    }
}
