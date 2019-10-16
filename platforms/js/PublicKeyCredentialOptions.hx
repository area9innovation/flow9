import haxe.io.UInt8Array;

typedef PublicKeyCredentialRPEntity = {
    var id : String;
    var name : String;
    @:optional var icon : String;
}

typedef PublicKeyCredentialUserEntity = {
    // This an opaque identifier which can be used by the authenticator
    // to link the user account with its corresponding credentials
    // This value will later be used when fetching the credentials
    // in AuthenticatorAssertionResponse.userHandle.
    var id : UInt8Array;
    var name : String;
    var displayName : String;
    @:optional var icon : String;
}

@:enum abstract PublicKeyCredentialType(String) {
    var PublicKey = "public-key";
}

typedef PublicKeyCredParam = {
    var type : PublicKeyCredentialType;
    var alg : Int;
}

@:enum abstract AuthenticationTransport(String) {
    var Usb         = "usb";
    var Nfc         = "nfc";
    var Ble         = "ble";
    var Internal    = "internal";
    var Lightning   = "lightning";
}

typedef PublicCredentialDescriptor = {
    var type : PublicKeyCredentialType;
    // Matching an existing public key credential identifier (PublicKeyCredential.rawId).
    // This identifier is generated during the creation of the PublicKeyCredential instance.
    var id : UInt8Array;
    @:optional var transports : Array<AuthenticationTransport>;
}

@:enum abstract AuthenticatorAttachment(String) {
    var Platform        = "platform";
    var CrossPlatform   = "cross-platform";
}

@:enum abstract UserVerificationRequirement(String) {
    var Required    = "required";
    var Preferred   = "preferred";
    var Discouraged = "discouraged";
}

typedef AuthenticatorSelectionCriteria = {
    @:optional var authenticatorAttachment : AuthenticatorAttachment;
    @:optional var requireResidentKey : Bool;
    @:optional var userVerification : UserVerificationRequirement;
}

@:enum abstract AttestationConveyancePreference(String) {
    var None        = "none";
    var Indirect    = "indirect";
    var Direct      = "direct";
}

typedef PublicKeyCredentialCreationOptions = {
    var publicKey: {
        var rp : PublicKeyCredentialRPEntity;
        var user : PublicKeyCredentialUserEntity;
        // This is randomly generated then sent from the relying party's server.
        // This value (among other client data) will be signed by the authenticator,
        // using its private key, and must be sent back for verification to the server
        // as part of AuthenticatorAttestationResponse.attestationObject.
        var challenge : UInt8Array;
        var pubKeyCredParams : Array<PublicKeyCredParam>;
        @:optional var timeout : Int; //milliseconds
        @:optional var excludeCredentials : Array<PublicCredentialDescriptor>;
        @:optional var authenticatorSelection : AuthenticatorSelectionCriteria;
        @:optional var attestation : AttestationConveyancePreference;
    }
}

typedef PublicKeyCredentialRequestOptions = {
    var publicKey: {
        // This value will be signed by the authenticator and the signature will be sent back
        // as part of AuthenticatorAssertionResponse.signature.
        var challenge : UInt8Array;
        @:optional var timeout : Int; //milliseconds
        @:optional var rpId : String;
        @:optional var allowCredentials : Array<PublicCredentialDescriptor>;
        @:optional var userVerification : UserVerificationRequirement;
    }
}