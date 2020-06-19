# Web Authentication

An API that allows to register and authenticate users using public-key based credentials instead of password.
More details can be found [here](https://www.w3.org/TR/2019/WD-webauthn-2-20190604/)

## Supported platforms

|            | Chrome | Firefox | Safari | Edge | Opera | Android browser | Chrome for Android | Firefox for Android |
|------------|:------:|:-------:|:------:|:----:|:-----:|:---------------:|:------------------:|:-------------------:|
| Webauthn   |67+     |60+      |13+     |18+   |54+    |76+              |76+                 |68+                  |


## Usage
There are two main API calls one for user registration and another one authentication.

`createCredentials` to register user and `getCredentials` to authenticate registered user:

```
createCredentials(
    creationOptions : PublicKeyCredentialCreationOptions,
    callback : (publicKeyCredential : string) -> void,
    onError : (string) -> void
) -> void;

getCredentials(
    requestOptions : PublicKeyCredentialRequestOptions,
    callback : (publicKeyCredential : string) -> void,
    onError : (string) -> void
) -> void;
```

To make it works you have to provide [PublicKeyCredentialCreationOptions](https://www.w3.org/TR/2019/WD-webauthn-2-20190604/#dictdef-publickeycredentialcreationoptions) ([PublicKeyCredentialRequestOptions](https://www.w3.org/TR/2019/WD-webauthn-2-20190604/#dictdef-publickeycredentialrequestoptions) in case of `getCredentials`). If authenticator matches their requirements you'll be provided with [publicKeyCredential](https://www.w3.org/TR/2019/WD-webauthn-2-20190604/#publickeycredential). That have to be [verified](https://www.w3.org/TR/2019/WD-webauthn-2-20190604/#sctn-rp-operations) on server.