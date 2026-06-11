/**
 * @description Test class for EncryptionUtil.
 *              Uses @TestVisible field injection to bypass Custom Setting dependency.
 * @author      LendSphere 360
 */
@isTest
private class EncryptionUtilTest {

    // Inject a fresh AES-256 key before each test via the @TestVisible field
    static void injectKey() {
        EncryptionUtil.encryptionKey = Crypto.generateAesKey(256);
    }

    @isTest
    static void testEncryptDecrypt_roundTrip() {
        injectKey();
        String plaintext  = 'ABCDE1234F'; // sample PAN format
        String ciphertext = EncryptionUtil.encrypt(plaintext);
        System.assertNotEquals(plaintext, ciphertext, 'Ciphertext should differ from plaintext');
        System.assertEquals(plaintext, EncryptionUtil.decrypt(ciphertext), 'Decrypt should return original');
    }

    @isTest
    static void testEncrypt_blankInput() {
        injectKey();
        System.assertEquals(null, EncryptionUtil.encrypt(''), 'Blank input should return null');
        System.assertEquals(null, EncryptionUtil.encrypt(null), 'Null input should return null');
    }

    @isTest
    static void testDecrypt_blankInput() {
        injectKey();
        System.assertEquals(null, EncryptionUtil.decrypt(''), 'Blank ciphertext should return null');
        System.assertEquals(null, EncryptionUtil.decrypt(null), 'Null ciphertext should return null');
    }

    @isTest
    static void testGetMasked_pan() {
        injectKey();
        String pan    = 'ABCDE1234F';
        String cipher = EncryptionUtil.encrypt(pan);

        String masked = EncryptionUtil.getMasked(cipher, 4, 'X', 10);
        System.assertEquals('XXXXXX234F', masked, 'Should mask all but last 4 chars');
    }

    @isTest
    static void testGetMasked_blankInput() {
        injectKey();
        System.assertEquals(null, EncryptionUtil.getMasked(null, 4, 'X', 10));
        System.assertEquals(null, EncryptionUtil.getMasked('', 4, 'X', 10));
    }

    @isTest
    static void testEncrypt_differentValuesProduceDifferentCiphers() {
        injectKey();
        String c1 = EncryptionUtil.encrypt('PAN123456A');
        String c2 = EncryptionUtil.encrypt('PAN654321B');
        System.assertNotEquals(c1, c2, 'Different plaintexts should produce different ciphers');
    }
}
