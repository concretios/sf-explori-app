/**
 * @description : Tests for SalesRevNavigatorCanvasLifecycleHandler using Canvas.Test. Verifies that
 *                Account pages send exactly accountId and accountName, Home and non-Account record
 *                pages send no parameters, and inaccessible or malformed Account Ids fail closed.
 * @author      : Mayank Singh
 */
@IsTest
private class SalesRevNavigatorCanvasHandlerTest {
    private static final String ACCOUNT_NAME = 'Acme Canvas Co';
    private static final String NO_ACCESS_MESSAGE = 'Explori Sales RevNavigator can only open on an Account you can access.';
    private static final String NO_CONTEXT_MESSAGE = 'Explori Sales RevNavigator context is unavailable.';

    @TestSetup
    static void setup() {
        insert new Account(Name = ACCOUNT_NAME);
    }

    private static Account testAccount() {
        return [SELECT Id, Name FROM Account WHERE Name = :ACCOUNT_NAME LIMIT 1];
    }

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

    private static Canvas.RenderContext mockWithParams(Map<String, Object> params) {
        return mockWithParams(JSON.serialize(params));
    }

    // Reads back the parameters the handler set on the render context.
    private static Map<String, Object> readParams(Canvas.RenderContext mock) {
        return (Map<String, Object>) JSON.deserializeUntyped(mock.getEnvironmentContext().getParametersAsJSON());
    }

    @IsTest
    static void excludeContextTypesReturnsEmptySet() {
        Set<Canvas.ContextTypeEnum> excluded;
        Test.startTest();
        System.runAs(currentUser()) {
            excluded = new SalesRevNavigatorCanvasLifecycleHandler().excludeContextTypes();
        }
        Test.stopTest();

        Assert.isNotNull(excluded, 'excludeContextTypes must not return null');
        Assert.isTrue(excluded.isEmpty(), 'No context types should be excluded');
    }

    @IsTest
    static void visibleAccountRecordIdSendsAccountIdAndName() {
        Account acct = testAccount();
        Canvas.RenderContext mock = mockWithParams(new Map<String, Object>{
            'recordId' => acct.Id,
            'sessionToken' => 'should-be-dropped'
        });

        Test.startTest();
        System.runAs(currentUser()) {
            Canvas.Test.testCanvasLifecycle(new SalesRevNavigatorCanvasLifecycleHandler(), mock);
        }
        Test.stopTest();

        Map<String, Object> sent = (Map<String, Object>) JSON.deserializeUntyped(
            mock.getEnvironmentContext().getParametersAsJSON()
        );
        Assert.areEqual(new Set<String>{ 'accountId', 'accountName' }, sent.keySet(), 'Only accountId and accountName may be sent');
        Assert.areEqual(String.valueOf(acct.Id), (String) sent.get('accountId'), 'accountId should be the resolved Account Id');
        Assert.areEqual(18, ((String) sent.get('accountId')).length(), 'accountId should be the 18-character Id');
        Assert.areEqual(ACCOUNT_NAME, (String) sent.get('accountName'), 'accountName should be the Account Name');
    }

    @IsTest
    static void accountIdKeyWinsOverRecordId() {
        Account acct = testAccount();
        Opportunity opp = insertOpportunity(acct.Id);
        Canvas.RenderContext mock = mockWithParams(new Map<String, Object>{
            'accountId' => acct.Id,
            'recordId' => opp.Id
        });

        Test.startTest();
        System.runAs(currentUser()) {
            new SalesRevNavigatorCanvasLifecycleHandler().onRender(mock);
        }
        Test.stopTest();

        Map<String, Object> sent = readParams(mock);
        Assert.areEqual(String.valueOf(acct.Id), (String) sent.get('accountId'), 'accountId must take precedence over recordId');
        Assert.areEqual(ACCOUNT_NAME, (String) sent.get('accountName'), 'accountName should come from the accountId record');
    }

    @IsTest
    static void emptyParametersSendNothing() {
        Canvas.RenderContext mock = mockWithParams('{}');

        Test.startTest();
        System.runAs(currentUser()) {
            new SalesRevNavigatorCanvasLifecycleHandler().onRender(mock);
        }
        Test.stopTest();

        Map<String, Object> sent = readParams(mock);
        Assert.isTrue(sent.isEmpty(), 'Empty parameters (Home page) must send no parameters, got: ' + sent.keySet());
    }

    @IsTest
    static void blankRecordIdSendsNothing() {
        Canvas.RenderContext mock = mockWithParams(new Map<String, Object>{ 'recordId' => '' });

        Test.startTest();
        System.runAs(currentUser()) {
            new SalesRevNavigatorCanvasLifecycleHandler().onRender(mock);
        }
        Test.stopTest();

        Map<String, Object> sent = readParams(mock);
        Assert.isTrue(sent.isEmpty(), 'A blank recordId must send no parameters, got: ' + sent.keySet());
    }

    @IsTest
    static void nullRecordIdSendsNothing() {
        Canvas.RenderContext mock = mockWithParams('{"recordId":null}');

        Test.startTest();
        System.runAs(currentUser()) {
            new SalesRevNavigatorCanvasLifecycleHandler().onRender(mock);
        }
        Test.stopTest();

        Map<String, Object> sent = readParams(mock);
        Assert.isTrue(sent.isEmpty(), 'A JSON null recordId must send no parameters, got: ' + sent.keySet());
    }

    @IsTest
    static void noParametersSetSendsNothing() {
        // A mock with no parameters set at all (Home page with no Canvas parameters).
        Canvas.RenderContext mock = Canvas.Test.mockRenderContext(null, null);

        Test.startTest();
        System.runAs(currentUser()) {
            new SalesRevNavigatorCanvasLifecycleHandler().onRender(mock);
        }
        Test.stopTest();

        Map<String, Object> sent = readParams(mock);
        Assert.isTrue(sent.isEmpty(), 'No incoming parameters must send no parameters, got: ' + sent.keySet());
    }

    @IsTest
    static void opportunityIdSendsNothing() {
        Opportunity opp = insertOpportunity(testAccount().Id);
        Canvas.RenderContext mock = mockWithParams(new Map<String, Object>{ 'recordId' => opp.Id });

        Test.startTest();
        System.runAs(currentUser()) {
            new SalesRevNavigatorCanvasLifecycleHandler().onRender(mock);
        }
        Test.stopTest();

        Map<String, Object> sent = readParams(mock);
        Assert.isTrue(sent.isEmpty(), 'An Opportunity record page must send no parameters, got: ' + sent.keySet());
    }

    @IsTest
    static void userIdSendsNothing() {
        Canvas.RenderContext mock = mockWithParams(new Map<String, Object>{ 'recordId' => UserInfo.getUserId() });

        Test.startTest();
        System.runAs(currentUser()) {
            new SalesRevNavigatorCanvasLifecycleHandler().onRender(mock);
        }
        Test.stopTest();

        Map<String, Object> sent = readParams(mock);
        Assert.isTrue(sent.isEmpty(), 'A non-Account (User) Id must send no parameters, got: ' + sent.keySet());
    }

    @IsTest
    static void malformedIdFailsClosed() {
        Canvas.RenderContext mock = mockWithParams(new Map<String, Object>{ 'recordId' => 'not-an-id' });

        String message;
        Test.startTest();
        System.runAs(currentUser()) {
            try {
                new SalesRevNavigatorCanvasLifecycleHandler().onRender(mock);
                Assert.fail('Expected CanvasRenderException');
            } catch (Canvas.CanvasRenderException e) {
                message = e.getMessage();
            }
        }
        Test.stopTest();

        Assert.areEqual(NO_ACCESS_MESSAGE, message, 'A malformed Id must fail closed');
    }

    @IsTest
    static void malformedAccountPrefixIdFailsClosed() {
        Canvas.RenderContext mock = mockWithParams(new Map<String, Object>{ 'accountId' => '001XYZ' });

        String message;
        Test.startTest();
        System.runAs(currentUser()) {
            try {
                new SalesRevNavigatorCanvasLifecycleHandler().onRender(mock);
                Assert.fail('Expected CanvasRenderException');
            } catch (Canvas.CanvasRenderException e) {
                message = e.getMessage();
            }
        }
        Test.stopTest();

        Assert.areEqual(NO_ACCESS_MESSAGE, message, 'A truncated Account-prefixed Id must fail closed');
    }

    @IsTest
    static void deletedAccountFailsClosed() {
        Account acct = testAccount();
        delete acct;
        Canvas.RenderContext mock = mockWithParams(new Map<String, Object>{ 'recordId' => acct.Id });

        String message;
        Test.startTest();
        System.runAs(currentUser()) {
            try {
                new SalesRevNavigatorCanvasLifecycleHandler().onRender(mock);
                Assert.fail('Expected CanvasRenderException');
            } catch (Canvas.CanvasRenderException e) {
                message = e.getMessage();
            }
        }
        Test.stopTest();

        Assert.areEqual(NO_ACCESS_MESSAGE, message, 'A deleted Account must fail closed');
    }

    @IsTest
    static void userWithoutAccountAccessFailsClosed() {
        Account acct = testAccount();
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
        Canvas.RenderContext mock = mockWithParams(new Map<String, Object>{ 'recordId' => acct.Id });

        String message;
        Test.startTest();
        System.runAs(restricted) {
            try {
                new SalesRevNavigatorCanvasLifecycleHandler().onRender(mock);
                Assert.fail('Expected CanvasRenderException');
            } catch (Canvas.CanvasRenderException e) {
                message = e.getMessage();
            }
        }
        Test.stopTest();

        Assert.areEqual(NO_ACCESS_MESSAGE, message, 'A user without Account read must get the friendly fail-closed message');
    }

    @IsTest
    static void nullRenderContextFailsClosed() {
        String message;
        Test.startTest();
        System.runAs(currentUser()) {
            try {
                new SalesRevNavigatorCanvasLifecycleHandler().onRender(null);
                Assert.fail('Expected CanvasRenderException');
            } catch (Canvas.CanvasRenderException e) {
                message = e.getMessage();
            }
        }
        Test.stopTest();
        Assert.areEqual(NO_CONTEXT_MESSAGE, message, 'A null render context must report the context as unavailable');
    }

    private static Opportunity insertOpportunity(Id accountId) {
        Opportunity opp = new Opportunity(
            Name = 'Canvas Opportunity',
            AccountId = accountId,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30)
        );
        insert opp;
        return opp;
    }
}
