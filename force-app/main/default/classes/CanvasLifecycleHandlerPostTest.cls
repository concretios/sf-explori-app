/**
 * @description : Tests for CanvasLifecycleHandlerPost using Canvas.Test. Verifies the
 *                handler blocks rendering when the record is not a visible Account, and
 *                that the signed payload carries accountId and accountName.
 * @author      : Mayank Singh
 */
@IsTest
private class CanvasLifecycleHandlerPostTest {
    // Well-formed Account Id built from the key prefix so it is not hardcoded.
    private static final String ABSENT_ACCOUNT_ID =
        Account.SObjectType.getDescribe(SObjectDescribeOptions.DEFERRED).getKeyPrefix()
            + '0'.repeat(12) + 'AAA';

    private static final String NO_ACCESS_MESSAGE = 'Explori Sales RevNavigator can only open on an Account you can access.';
    private static final String NO_CONTEXT_MESSAGE = 'Explori Sales RevNavigator context is unavailable.';

    // The running test user, who can read the Accounts the test inserts.
    private static User currentUser() {
        return new User(Id = UserInfo.getUserId());
    }

    // Builds a mock render context carrying the given incoming parameters.
    private static Canvas.RenderContext mockWithParams(String paramsJson) {
        Canvas.RenderContext mock = Canvas.Test.mockRenderContext(null, null);
        mock.getEnvironmentContext().setParametersAsJSON(paramsJson);
        return mock;
    }

    @IsTest
    static void onRenderRecordNotAccountThrows() {
        // A User Id (005) is a valid Id but not an Account.
        Canvas.RenderContext mock = mockWithParams(
            JSON.serialize(new Map<String, Object>{ 'accountId' => UserInfo.getUserId() })
        );

        Test.startTest();
        System.runAs(currentUser()) {
            try {
                new CanvasLifecycleHandlerPost().onRender(mock);
                Assert.fail('Expected CanvasRenderException');
            } catch (Canvas.CanvasRenderException e) {
                Assert.areEqual(NO_ACCESS_MESSAGE, e.getMessage(), 'A non-Account record must block rendering');
            }
        }
        Test.stopTest();
    }

    @IsTest
    static void onRenderAccountNotVisibleThrows() {
        // Well-formed Account Id that does not exist => USER_MODE query returns nothing.
        Canvas.RenderContext mock = mockWithParams(
            JSON.serialize(new Map<String, Object>{ 'accountId' => ABSENT_ACCOUNT_ID })
        );

        Test.startTest();
        System.runAs(currentUser()) {
            try {
                new CanvasLifecycleHandlerPost().onRender(mock);
                Assert.fail('Expected CanvasRenderException');
            } catch (Canvas.CanvasRenderException e) {
                Assert.areEqual(NO_ACCESS_MESSAGE, e.getMessage(), 'An inaccessible Account must block rendering');
            }
        }
        Test.stopTest();
    }

    @IsTest
    static void onRenderHappyPathSendsAccountIdAndName() {
        Account acct = new Account(Name = 'Acme Canvas Co');
        insert acct;

        Canvas.CanvasLifecycleHandler handler = new CanvasLifecycleHandlerPost();
        Canvas.RenderContext mock = Canvas.Test.mockRenderContext(null, null);
        // Include extra keys to prove the handler rebuilds the payload rather than appending.
        mock.getEnvironmentContext().setParametersAsJSON(
            JSON.serialize(new Map<String, Object>{
                'accountId' => acct.Id,
                'recordId' => acct.Id,
                'sessionToken' => 'should-be-dropped'
            })
        );

        Test.startTest();
        System.runAs(currentUser()) {
            Canvas.Test.testCanvasLifecycle(handler, mock);
        }
        Test.stopTest();

        Map<String, Object> sent = (Map<String, Object>) JSON.deserializeUntyped(
            mock.getEnvironmentContext().getParametersAsJSON()
        );

        Assert.areEqual(2, sent.size(), 'Exactly two parameters must be sent: ' + sent.keySet());
        Assert.isTrue(sent.containsKey('accountId'), 'accountId must be present');
        Assert.areEqual(String.valueOf(acct.Id), (String) sent.get('accountId'), 'accountId should be the resolved Account Id');
        Assert.areEqual(18, ((String) sent.get('accountId')).length(), 'accountId should be the 18-character Id');
        Assert.isTrue(sent.containsKey('accountName'), 'accountName must be present');
        Assert.areEqual(acct.Name, (String) sent.get('accountName'), 'Account Name should be the resolved Account');

        Assert.isFalse(sent.containsKey('shareId'), 'shareId must not be present');
        Assert.isFalse(sent.containsKey('productId'), 'productId must not be present');
        Assert.isFalse(sent.containsKey('recordId'), 'recordId must not be forwarded');
        Assert.isFalse(sent.containsKey('sessionToken'), 'Unexpected incoming keys must be dropped');
    }

    @IsTest
    static void excludeContextTypesReturnsEmptySet() {
        // The handler keeps all context types in the signed request.
        Set<Canvas.ContextTypeEnum> excluded;
        Test.startTest();
        System.runAs(currentUser()) {
            excluded = new CanvasLifecycleHandlerPost().excludeContextTypes();
        }
        Test.stopTest();

        Assert.areNotEqual(null, excluded, 'excludeContextTypes must not return null');
        Assert.isTrue(excluded.isEmpty(), 'No context types should be excluded');
    }

    @IsTest
    static void onRenderNullContextThrows() {
        // Direct invocation with a null RenderContext exercises the null-context guard.
        Test.startTest();
        System.runAs(currentUser()) {
            try {
                new CanvasLifecycleHandlerPost().onRender(null);
                Assert.fail('Expected CanvasRenderException');
            } catch (Canvas.CanvasRenderException e) {
                Assert.areEqual(
                    NO_CONTEXT_MESSAGE,
                    e.getMessage(),
                    'Null context should report an unavailable canvas context: ' + e.getMessage()
                );
            }
        }
        Test.stopTest();
    }

    @IsTest
    static void onRenderBlankParamsThrows() {
        // No record id is supplied => no visible Account.
        Canvas.RenderContext mock = mockWithParams('{}');

        Test.startTest();
        System.runAs(currentUser()) {
            try {
                new CanvasLifecycleHandlerPost().onRender(mock);
                Assert.fail('Expected CanvasRenderException');
            } catch (Canvas.CanvasRenderException e) {
                Assert.areEqual(NO_ACCESS_MESSAGE, e.getMessage(), 'Blank incoming parameters must block rendering');
            }
        }
        Test.stopTest();
    }

    @IsTest
    static void onRenderMalformedAccountIdThrows() {
        // A non-blank but invalid Id value is treated as an inaccessible Account.
        Canvas.RenderContext mock = mockWithParams(
            JSON.serialize(new Map<String, Object>{ 'accountId' => 'not-a-real-id' })
        );

        Test.startTest();
        System.runAs(currentUser()) {
            try {
                new CanvasLifecycleHandlerPost().onRender(mock);
                Assert.fail('Expected CanvasRenderException');
            } catch (Canvas.CanvasRenderException e) {
                Assert.areEqual(NO_ACCESS_MESSAGE, e.getMessage(), 'A malformed Account Id must block rendering');
            }
        }
        Test.stopTest();
    }

    @IsTest
    static void onRenderUserWithoutAccountAccessThrows() {
        Account acct = new Account(Name = 'Restricted Canvas Co');
        insert acct;

        Profile minimumAccess = [SELECT Id FROM Profile WHERE Name = 'Minimum Access - Salesforce' LIMIT 1];
        String uniqueKey = String.valueOf(Math.abs(Crypto.getRandomInteger()));
        User restricted = new User(
            ProfileId = minimumAccess.Id,
            Username = 'canvas.restricted.' + uniqueKey + '@example.com',
            Alias = 'cnvrst',
            Email = 'canvas.restricted@example.com',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            LastName = 'Restricted',
            LocaleSidKey = 'en_US',
            TimeZoneSidKey = 'America/Los_Angeles'
        );
        insert restricted;

        Canvas.RenderContext mock = Canvas.Test.mockRenderContext(null, null);
        mock.getEnvironmentContext().setParametersAsJSON(
            JSON.serialize(new Map<String, Object>{ 'accountId' => acct.Id })
        );

        Test.startTest();
        System.runAs(restricted) {
            try {
                new CanvasLifecycleHandlerPost().onRender(mock);
                Assert.fail('Expected QueryException for a user without Account Read');
            } catch (System.QueryException e) {
                Assert.isNotNull(e.getMessage(), 'USER_MODE query should deny Account access');
            }
        }
        Test.stopTest();
    }
}
