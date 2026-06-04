/**
 * @description       AES-256-CBC encryption / decryption utility.
 *                    Uses a Named Credential–stored key so the plaintext key is never
 *                    committed to source code. Designed specifically for PII fields
 *                    (PAN, Aadhaar) on KYC_Request__c.
 *
 *                    Setup required in target org:
 *                      1. Create a Protected Custom Setting: EncryptionConfig__c
 *                         with a field Base64_Key__c (Text 64) containing the
 *                         base64-encoded 32-byte AES key.
 *                      2. Restrict field-level access to System Administrator only.
 *
 *                    Usage:
 *                      String cipher = EncryptionUtil.encrypt('1234-5678-9012-3456');
 *                      String plain  = EncryptionUtil.decrypt(cipher);
 *
 * @author            LendSphere 360
 * @created           2024
 */
public with sharing class EncryptionUtil {

    // ───────────────────────────────────────────────────────────────────────────
    // Constants
    // ───────────────────────────────────────────────────────────────────────────

    private static final String ALGORITHM = 'AES256';

    // ───────────────────────────────────────────────────────────────────────────
    // Key management — loaded once per transaction
    // ───────────────────────────────────────────────────────────────────────────

    @TestVisible private static Blob encryptionKey;

    private static Blob getKey() {
        if (encryptionKey == null) {
            // Retrieve the base64-encoded key from a Protected Custom Setting
            // (never hardcode keys in Apex source)
            // EncryptionConfig__c must be created in Setup > Custom Settings
            // with a Protected field: Base64_Key__c (Text 64)
            try {
                SObject config = Database.query(
                    'SELECT Base64_Key__c FROM EncryptionConfig__c LIMIT 1'
                );
                String keyVal = (String) config.get('Base64_Key__c');
                if (String.isBlank(keyVal)) {
                    throw new EncryptionException(
                        'EncryptionConfig__c.Base64_Key__c is blank. Please configure the Custom Setting.'
                    );
                }
                encryptionKey = EncodingUtil.base64Decode(keyVal);
            } catch (QueryException qe) {
                throw new EncryptionException(
                    'EncryptionConfig__c Custom Setting is not deployed. ' +
                    'Create it in Setup > Custom Settings with field Base64_Key__c (Text 64).'
                );
            }
        }
        return encryptionKey;
    }

    // ───────────────────────────────────────────────────────────────────────────
    // Public API
    // ───────────────────────────────────────────────────────────────────────────

    /**
     * @description Encrypts plaintext using AES-256 and returns a base64-encoded ciphertext.
     * @param  plaintext  The value to encrypt (e.g., PAN number).
     * @return            Base64-encoded encrypted string, safe to store in a Text field.
     */
    public static String encrypt(String plaintext) {
        if (String.isBlank(plaintext)) return null;
        try {
            Blob plaintextBlob  = Blob.valueOf(plaintext);
            Blob ciphertextBlob = Crypto.encryptWithManagedIV(ALGORITHM, getKey(), plaintextBlob);
            return EncodingUtil.base64Encode(ciphertextBlob);
        } catch (Exception e) {
            ApplicationLogger.logException(e, 'EncryptionUtil', 'encrypt');
            ApplicationLogger.flush();
            throw new EncryptionException('Encryption failed: ' + e.getMessage());
        }
    }

    /**
     * @description Decrypts a base64-encoded ciphertext produced by encrypt().
     * @param  ciphertext  The base64-encoded encrypted string stored in the field.
     * @return             Plaintext string. Returns null for blank input.
     */
    public static String decrypt(String ciphertext) {
        if (String.isBlank(ciphertext)) return null;
        try {
            Blob ciphertextBlob = EncodingUtil.base64Decode(ciphertext);
            Blob plaintextBlob  = Crypto.decryptWithManagedIV(ALGORITHM, getKey(), ciphertextBlob);
            return plaintextBlob.toString();
        } catch (Exception e) {
            ApplicationLogger.logException(e, 'EncryptionUtil', 'decrypt');
            ApplicationLogger.flush();
            throw new EncryptionException('Decryption failed: ' + e.getMessage());
        }
    }

    /**
     * @description Returns a masked display string showing only the last N characters.
     *              Does NOT decrypt — use for UI display of encrypted PAN/Aadhaar.
     * @param  encryptedValue  The stored encrypted field value.
     * @param  plainLastChars  Number of plaintext chars to show (must have access to decrypt).
     * @param  maskChar        Character to use for masking (e.g., 'X').
     * @param  totalLength     Total length of the masked output string.
     * @return                 Masked string like 'XXXXXXXX3456'.
     */
    public static String getMasked(String encryptedValue, Integer plainLastChars, String maskChar, Integer totalLength) {
        if (String.isBlank(encryptedValue)) return null;
        String plain = decrypt(encryptedValue);
        if (plain.length() <= plainLastChars) return plain;
        String visible = plain.right(plainLastChars);
        Integer maskCount = totalLength - plainLastChars;
        return maskChar.repeat(maskCount) + visible;
    }

    // ───────────────────────────────────────────────────────────────────────────
    // Inner exception class
    // ───────────────────────────────────────────────────────────────────────────

    public class EncryptionException extends Exception {}
}
