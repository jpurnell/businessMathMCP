import Testing
import Foundation
@testable import BusinessMathMCP

/// Tests for PKCE (Proof Key for Code Exchange) per RFC 7636
@Suite("PKCE")
struct PKCETests {

    // MARK: - Code Verifier Tests

    @Suite("Code Verifier")
    struct CodeVerifierTests {

        @Test("Generates valid code verifier")
        func generatesValidCodeVerifier() {
            let verifier = PKCE.generateCodeVerifier()

            // RFC 7636 §4.1: verifier must be 43-128 characters
            #expect(verifier.count >= 43)
            #expect(verifier.count <= 128)
        }

        @Test("Code verifier uses valid character set")
        func codeVerifierUsesValidCharacterSet() {
            let verifier = PKCE.generateCodeVerifier()

            // RFC 7636 §4.1: ALPHA / DIGIT / "-" / "." / "_" / "~"
            let allowedChars = CharacterSet(charactersIn:
                "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
            let verifierChars = CharacterSet(charactersIn: verifier)

            #expect(verifierChars.isSubset(of: allowedChars),
                    "Code verifier contains invalid characters")
        }

        @Test("Code verifiers are unique")
        func codeVerifiersAreUnique() {
            var verifiers = Set<String>()
            for _ in 0..<100 {
                let verifier = PKCE.generateCodeVerifier()
                #expect(!verifiers.contains(verifier), "Verifier collision detected")
                verifiers.insert(verifier)
            }
        }

        @Test("Validates correct code verifier format")
        func validatesCorrectFormat() {
            let valid = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
            #expect(PKCE.isValidCodeVerifier(valid) == true)
        }

        @Test("Rejects too short code verifier")
        func rejectsTooShortVerifier() {
            let tooShort = String(repeating: "a", count: 42)
            #expect(PKCE.isValidCodeVerifier(tooShort) == false)
        }

        @Test("Rejects too long code verifier")
        func rejectsTooLongVerifier() {
            let tooLong = String(repeating: "a", count: 129)
            #expect(PKCE.isValidCodeVerifier(tooLong) == false)
        }

        @Test("Rejects invalid characters")
        func rejectsInvalidCharacters() {
            let invalid = "abc+def/ghi=jkl" // Contains +, /, =
            #expect(PKCE.isValidCodeVerifier(invalid) == false)
        }
    }

    // MARK: - Code Challenge Tests

    @Suite("Code Challenge - S256")
    struct CodeChallengeS256Tests {

        @Test("Generates S256 code challenge")
        func generatesS256Challenge() throws {
            let verifier = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
            let challenge = try PKCE.generateCodeChallenge(verifier: verifier, method: .s256)

            // Should be base64url encoded SHA-256 hash
            #expect(!challenge.isEmpty)
            #expect(!challenge.contains("+"))
            #expect(!challenge.contains("/"))
            #expect(!challenge.contains("="))
        }

        @Test("S256 matches RFC 7636 test vector")
        func matchesRFCTestVector() throws {
            // RFC 7636 Appendix B test vector
            let verifier = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
            let expectedChallenge = "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM"

            let challenge = try PKCE.generateCodeChallenge(verifier: verifier, method: .s256)

            #expect(challenge == expectedChallenge,
                    "Challenge should match RFC 7636 test vector")
        }

        @Test("Same verifier produces same challenge")
        func sameVerifierProducesSameChallenge() throws {
            let verifier = PKCE.generateCodeVerifier()
            let challenge1 = try PKCE.generateCodeChallenge(verifier: verifier, method: .s256)
            let challenge2 = try PKCE.generateCodeChallenge(verifier: verifier, method: .s256)

            #expect(challenge1 == challenge2)
        }

        @Test("Different verifiers produce different challenges")
        func differentVerifiersProduceDifferentChallenges() throws {
            let verifier1 = PKCE.generateCodeVerifier()
            let verifier2 = PKCE.generateCodeVerifier()

            let challenge1 = try PKCE.generateCodeChallenge(verifier: verifier1, method: .s256)
            let challenge2 = try PKCE.generateCodeChallenge(verifier: verifier2, method: .s256)

            #expect(challenge1 != challenge2)
        }
    }

    // MARK: - Code Challenge Verification Tests

    @Suite("Code Challenge Verification")
    struct CodeChallengeVerificationTests {

        @Test("Verifies correct S256 challenge")
        func verifiesCorrectS256Challenge() throws {
            let verifier = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
            let challenge = "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM"

            let result = try PKCE.verifyCodeChallenge(
                verifier: verifier,
                challenge: challenge,
                method: .s256
            )

            #expect(result == true)
        }

        @Test("Rejects incorrect verifier")
        func rejectsIncorrectVerifier() throws {
            // Must be 43+ chars to be valid format, but wrong value
            let wrongVerifier = "xBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
            let challenge = "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM"

            let result = try PKCE.verifyCodeChallenge(
                verifier: wrongVerifier,
                challenge: challenge,
                method: .s256
            )

            #expect(result == false)
        }

        @Test("Verifies generated challenge")
        func verifiesGeneratedChallenge() throws {
            let verifier = PKCE.generateCodeVerifier()
            let challenge = try PKCE.generateCodeChallenge(verifier: verifier, method: .s256)

            let result = try PKCE.verifyCodeChallenge(
                verifier: verifier,
                challenge: challenge,
                method: .s256
            )

            #expect(result == true)
        }
    }

    // MARK: - Plain Method Tests

    @Suite("Code Challenge - Plain")
    struct CodeChallengePlainTests {

        @Test("Generates plain code challenge")
        func generatesPlainChallenge() throws {
            // Verifier must be 43+ chars per RFC 7636
            let verifier = "test_verifier_12345_with_enough_length_here"
            let challenge = try PKCE.generateCodeChallenge(verifier: verifier, method: .plain)

            // Plain method: challenge == verifier
            #expect(challenge == verifier)
        }

        @Test("Verifies plain challenge")
        func verifiesPlainChallenge() throws {
            // Verifier must be 43+ chars per RFC 7636
            let verifier = "test_verifier_plain_with_sufficient_length_"
            let challenge = verifier // Plain method

            let result = try PKCE.verifyCodeChallenge(
                verifier: verifier,
                challenge: challenge,
                method: .plain
            )

            #expect(result == true)
        }
    }

    // MARK: - Challenge Method Tests

    @Suite("Challenge Method")
    struct ChallengeMethodTests {

        @Test("Parses S256 method string")
        func parsesS256MethodString() {
            let method = PKCE.ChallengeMethod(rawValue: "S256")
            #expect(method == .s256)
        }

        @Test("Parses plain method string")
        func parsesPlainMethodString() {
            let method = PKCE.ChallengeMethod(rawValue: "plain")
            #expect(method == .plain)
        }

        @Test("Returns nil for unknown method")
        func returnsNilForUnknownMethod() {
            let method = PKCE.ChallengeMethod(rawValue: "unknown")
            #expect(method == nil)
        }

        @Test("Raw value matches specification")
        func rawValueMatchesSpecification() {
            #expect(PKCE.ChallengeMethod.s256.rawValue == "S256")
            #expect(PKCE.ChallengeMethod.plain.rawValue == "plain")
        }
    }

    // MARK: - Error Handling Tests

    @Suite("Error Handling")
    struct ErrorHandlingTests {

        @Test("Throws for invalid verifier in challenge generation")
        func throwsForInvalidVerifier() {
            let invalidVerifier = "too_short"

            #expect(throws: PKCEError.self) {
                _ = try PKCE.generateCodeChallenge(verifier: invalidVerifier, method: .s256)
            }
        }
    }
}
