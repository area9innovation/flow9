import js.Promise;
import js.Browser;
import haxe.io.UInt8Array;
import js.html.Uint8Array;
import js.html.ArrayBuffer;
import haxe.io.Bytes;
import haxe.crypto.BaseCode;
import haxe.Json;
import PublicKeyCredentialOptions;

@:native("AuthenticatorResponse")
extern class AuthenticatorResponse {
    // https://developer.mozilla.org/en-US/docs/Web/API/AuthenticatorResponse/clientDataJSON
    var clientDataJSON : ArrayBuffer;
}

@:native("AuthenticatorAttestationResponse")
extern class AuthenticatorAttestationResponse extends AuthenticatorResponse {
    // https://developer.mozilla.org/en-US/docs/Web/API/AuthenticatorAttestationResponse/attestationObject
    var attestationObject : ArrayBuffer;
    function getTransports() : Array<AuthenticationTransport>;
}

@:native("AuthenticatorAssertionResponse")
extern class AuthenticatorAssertionResponse extends AuthenticatorResponse {
    // https://developer.mozilla.org/en-US/docs/Web/API/AuthenticatorAssertionResponse/authenticatorData
    var authenticatorData : ArrayBuffer;
    // An ArrayBuffer object which the signature of the authenticator (using its private key)
    // for both AuthenticatorAssertionResponse.authenticatorData and a SHA-256 hash given by the client for its data
    // (the challenge, the origin, etc. and available from AuthenticatorAssertionResponse.clientDataJSON).
    var signature : ArrayBuffer;
    var userHandle : ArrayBuffer;
}

@:native("Credential")
extern class Credential {
    var id : String;
    var name : String;
    var type : String;
}

@:native("PublicKeyCredential")
extern class PublicKeyCredential extends Credential {
    // we get rawId as a js.html.ArrayBuffer from js;
    var rawId : ArrayBuffer;
    var response : AuthenticatorResponse;
}

@:native("navigator.credentials")
extern class CredentialsContainer {
    /** @throws DOMError */
    static function create( ?credentialRequestOptions : PublicKeyCredentialCreationOptions ) : Promise<PublicKeyCredential>;
    /** @throws DOMError */
    static function get( ?credentialRequestOptions : PublicKeyCredentialRequestOptions ) : Promise<PublicKeyCredential>;
    /** @throws DOMError */
    static function store( credential : PublicKeyCredential) : Promise<PublicKeyCredential>;
    /** @throws DOMError */
    static function preventSilentAccess() : Promise<Void>;
}

class CredentialManagement {

    public static function webauthnSupported() : Bool {
        return untyped window.PublicKeyCredential;
    }

    public static function createCredentials(
        rp : Array<PublicKeyCredentialRPEntity>,
        user : Array<PublicKeyCredentialUserEntity>,
        challenge : String,
        pubKeyCredParams : Array<Int>,
        timeout : Int,
        excludeCredentials : Array<PublicCredentialDescriptor>,
        authenticatorSelection : Array<AuthenticatorSelectionCriteria>,
        attestation : String,
        callback : (String) -> Void,
        onError : (String) -> Void
    ) : Void {

        var credentialsCreationOptions = CredentialManagement.makeCredentialCreationOptions(
            rp.length == 0 ? {id:"", name:""} : rp[0],
            user.length == 0 ? {id:new UInt8Array(0), name:"", displayName:""} : user[0],
            challenge,
            pubKeyCredParams.map(function(alg) {return {type: PublicKey, alg: alg};}),
            timeout > 1000 ? timeout : null,
            excludeCredentials.length == 0 ? null : excludeCredentials,
            authenticatorSelection.length == 0 ? null : authenticatorSelection[0],
            if (attestation == "direct") Direct
            else if (attestation == "indirect") Indirect
            else if (attestation == "none") None
            else null
        );
        // untyped console.log(credentialsCreationOptions);
        var createCredentialsPromise = CredentialsContainer.create(credentialsCreationOptions);
        createCredentialsPromise.then(
            function(credential : PublicKeyCredential) {
                callback(CredentialManagement.publicKeyCredentialToString(credential, true));
            },
            function(e) {
                // untyped console.log(e.code);
                // untyped console.log(e.message);
                // untyped console.log(e.name);
                onError(e.message);
            }
        );
    }

    public static function getCredentials(
        challenge : String,
        allowCredentials : Array<PublicCredentialDescriptor>,
        timeout : Int,
        rpId : String,
        userVerification : String,
        callback : (String) -> Void,
        onError : (String) -> Void
    ) : Void {

        var credentialRequestOptions = CredentialManagement.makeCredentialRequestOptions(
            challenge,
            allowCredentials,
            timeout > 1000 ? timeout : null,
            rpId != "" ? rpId : null,
            if (userVerification == "required") Required
            else if (userVerification == "discouraged") Discouraged
            else if (userVerification == "preferred") Preferred
            else null
        );
        // untyped console.log(credentialRequestOptions);
        var getCredentialsPromise = CredentialsContainer.get(credentialRequestOptions);
        getCredentialsPromise.then(
            function(credential : PublicKeyCredential) {
                // untyped console.log(credential);
                callback(CredentialManagement.publicKeyCredentialToString(credential, false));
            },
            function(e) {
                // untyped console.log(e.code);
                // untyped console.log(e.message);
                // untyped console.log(e.name);
                onError(e.message);
            }
        );
    }

    public static function makePublicCredentialDescriptor(id : String, ?transports : Array<AuthenticationTransport>) : Array<PublicCredentialDescriptor> {
        var arr : Array<PublicCredentialDescriptor> = [{type: PublicKey, id: UInt8Array.fromBytes(CredentialManagement.base64UrlDecode(id), 0), transports: transports}];
        return arr;
    }

    public static function makeAuthenticatorSelectionCriteria(
        ?authenticatorAttachment : AuthenticatorAttachment,
        ?requireResidentKey : Bool,
        ?userVerification : UserVerificationRequirement
    ) : Array<AuthenticatorSelectionCriteria> {

        var asc : AuthenticatorSelectionCriteria = {};
        if (authenticatorAttachment != null) Reflect.setField(asc, "authenticatorAttachment", authenticatorAttachment);
        if (requireResidentKey != null) Reflect.setField(asc, "requireResidentKey", requireResidentKey);
        if (userVerification != null) Reflect.setField(asc, "userVerification", userVerification);
        var arr : Array<AuthenticatorSelectionCriteria> = (asc != {}) ? [asc] : [];
        return arr;
    }

    public static function makePublicKeyCredentialUserEntityNative(
        id : String,
        name : String,
        displayName : String,
        ?icon : String
    ) : Array<PublicKeyCredentialUserEntity> {

        var pkcue : PublicKeyCredentialUserEntity = {
            id: UInt8Array.fromBytes(CredentialManagement.base64UrlDecode(id), 0),
            name: name,
            displayName: displayName,
        };
        if (icon != null) Reflect.setField(pkcue, "icon", icon);
        var arr : Array<PublicKeyCredentialUserEntity> = [pkcue];
        return arr;
    }

    public static function makePublicKeyCredentialRPEntityNative(
        id : String,
        name : String,
        ?icon : String
    ) : Array<PublicKeyCredentialRPEntity> {

        var pkcrpe : PublicKeyCredentialRPEntity = {
            id: id,
            name: name,
        };
        if (icon != null) Reflect.setField(pkcrpe, "icon", icon);
        var arr : Array<PublicKeyCredentialRPEntity> = [pkcrpe];
        return arr;
    }

    // it seems that we need it for php part
    private static var URL_BYTES : Bytes = Bytes.ofString("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_");

    private static function makeCredentialCreationOptions(
        rp : PublicKeyCredentialRPEntity,
        user : PublicKeyCredentialUserEntity,
        challenge : String,
        pubKeyCredParams : Array<PublicKeyCredParam>,
        ?timeout : Int,
        ?excludeCredentials : Array<PublicCredentialDescriptor>,
        ?authenticatorSelection : AuthenticatorSelectionCriteria,
        ?attestation : AttestationConveyancePreference
    ) : PublicKeyCredentialCreationOptions {

        var pkcco : PublicKeyCredentialCreationOptions = {
            publicKey: {
                rp: rp,
                user: user,
                // This is randomly generated then sent from the relying party's server.
                // This value (among other client data) will be signed by the authenticator,
                // using its private key, and must be sent back for verification to the server
                // as part of AuthenticatorAttestationResponse.attestationObject.
                challenge: UInt8Array.fromBytes(CredentialManagement.base64UrlDecode(challenge), 0),
                pubKeyCredParams: pubKeyCredParams.length == 0 ? [{type: PublicKey, alg: -7/* -7 is for yubikey */}] : pubKeyCredParams,
            }
        };
        if (timeout != null) Reflect.setField(pkcco, "timeout", timeout);
        if (excludeCredentials != null) Reflect.setField(pkcco, "excludeCredentials", excludeCredentials);
        if (authenticatorSelection != null) Reflect.setField(pkcco, "authenticatorSelection", authenticatorSelection);
        if (attestation != null) Reflect.setField(pkcco, "attestation", attestation);
        return pkcco;
    }

    private static function makeCredentialRequestOptions(
        challenge : String,
        allowCredentials : Array<PublicCredentialDescriptor>,
        ?timeout : Int,
        ?rpId : String,
        ?userVerification : UserVerificationRequirement
    ) : PublicKeyCredentialRequestOptions {

        var pkcro : PublicKeyCredentialRequestOptions = {
            publicKey: {
                challenge: UInt8Array.fromBytes(CredentialManagement.base64UrlDecode(challenge), 0),
                allowCredentials: allowCredentials,
            }
        };
        if (timeout != null) Reflect.setField(pkcro, "timeout", timeout);
        if (rpId != null) Reflect.setField(pkcro, "rpId", rpId);
        if (userVerification != null) Reflect.setField(pkcro, "userVerification", userVerification);
        return pkcro;
    }

    private static function base64UrlEncode(bytes : Bytes) : String {
        return new BaseCode(CredentialManagement.URL_BYTES).encodeBytes(bytes).toString();
    }

    private static function base64UrlDecode(s : String) : Bytes {
        return new BaseCode(CredentialManagement.URL_BYTES).decodeBytes(Bytes.ofString(s));
    }

    private static function arrayBufferToBytes(ab : ArrayBuffer) : Bytes {
        var source : Uint8Array = new Uint8Array(ab);
        var recipient : UInt8Array = new UInt8Array(source.length);
        for (i in 0...source.length) {
            recipient.set(i, source[i]);
        }
        return recipient.view.buffer;
    }

    private static function publicKeyCredentialToString(credential : PublicKeyCredential, isAttestationResponse : Bool) : String {

        var rawId : String = CredentialManagement.base64UrlEncode(CredentialManagement.arrayBufferToBytes(credential.rawId));
        if (isAttestationResponse) {
            var attsttnResponse : AuthenticatorAttestationResponse = cast credential.response;
            return Json.stringify({
                id:         credential.id,
                rawId:      rawId,
                response:   {
                                attestationObject: CredentialManagement.base64UrlEncode(CredentialManagement.arrayBufferToBytes(attsttnResponse.attestationObject)),
                                clientDataJSON: CredentialManagement.base64UrlEncode(CredentialManagement.arrayBufferToBytes(attsttnResponse.clientDataJSON)),
                            },
                type:       credential.type
            });
        } else {
            var assrtnResponse : AuthenticatorAssertionResponse = cast credential.response;
            return Json.stringify({
                id:         credential.id,
                rawId:      rawId,
                response:   {
                                authenticatorData: CredentialManagement.base64UrlEncode(CredentialManagement.arrayBufferToBytes(assrtnResponse.authenticatorData)),
                                signature: CredentialManagement.base64UrlEncode(CredentialManagement.arrayBufferToBytes(assrtnResponse.signature)),
                                userHandle: CredentialManagement.base64UrlEncode(CredentialManagement.arrayBufferToBytes(assrtnResponse.userHandle)),
                                clientDataJSON: CredentialManagement.base64UrlEncode(CredentialManagement.arrayBufferToBytes(assrtnResponse.clientDataJSON)),
                            },
                type:       credential.type
            });
        }
    }

}