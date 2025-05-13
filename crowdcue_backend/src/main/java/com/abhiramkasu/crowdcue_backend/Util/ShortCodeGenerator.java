package com.abhiramkasu.crowdcue_backend.Util;

import java.math.BigInteger;
import java.util.UUID;

public class ShortCodeGenerator {
    private static final char[] base62 = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ".toCharArray();

    private ShortCodeGenerator() {
        // Private constructor to prevent instantiation
    }

    public static String generate() {
        return generate(6);
    }

    public static String generate(int length) {
        String uuidHex = UUID.randomUUID().toString().replace("-", "").substring(0, 12);
        BigInteger number = new BigInteger(uuidHex, 16);

        BigInteger sixtyTwo = BigInteger.valueOf(62);
        StringBuilder sb = new StringBuilder();
        BigInteger n = number;

        while (n.compareTo(BigInteger.ZERO) > 0 && sb.length() < length) {
            BigInteger remainder = n.mod(sixtyTwo);
            sb.append(base62[remainder.intValue()]);
            n = n.divide(sixtyTwo);
        }

        String result = sb.reverse().toString();

        if (result.length() < length) {
            result = "0".repeat(length - result.length()) + result;
        }

        return result;
    }
}