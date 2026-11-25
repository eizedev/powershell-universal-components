---
title: Sign-in to a pivotkit-server
description: "How Invoke-UDPivotReport and Get-UDPivotSource sign in to a pivotkit-server: a static token, or OAuth client credentials, with the steps for Authentik."
---

# Sign-in to a pivotkit-server

`Invoke-UDPivotReport -Engine Rest` and `Get-UDPivotSource` sign in with a token or with OAuth client
credentials ([Reports from a pivotkit-server](reports-server.md)).

=== "Static token"

    A token the operator gave you (`auth.tokens` of the server), kept as a PSU secret:

    ```powershell
    Invoke-UDPivotReport -Engine Rest -Uri 'https://reports.example.com/api/v1' -Token $Secret:PivotkitToken -Data $rows -View $view
    ```

    `-Token` takes a string or a SecureString.

    A pivotkit-server (0.3.0 or later) also accepts short-lived tokens that another system signs
    ([tokens from another system](https://pivotkit.eize.dev/reference/rest/#external-issuers),
    `auth.externalIssuers`). `-Token` sends such a token as it sends a static one.

=== "OAuth client credentials"

    The client id and secret of an OAuth client, kept as a PSU secret of type PSCredential (user name:
    the client id, password: the client secret):

    ```powershell
    Invoke-UDPivotReport -Engine Rest -Uri 'https://reports.example.com/api/v1' -Credential $Secret:PivotkitClient `
        -TokenUri 'https://auth.example.com/application/o/token/' -Scope 'pivotkit:rest' -Data $rows -View $view
    ```

    The function asks the token endpoint for an access token (`grant_type=client_credentials`, the
    client id and secret in the body, or as HTTP Basic with `-ClientAuthentication Basic`; `-Scope`,
    `-Audience` and `-Resource` when given) and keeps it in the PowerShell runspace until a minute
    before it expires, per token endpoint, client id, secret (as its SHA-256), scopes and server: a
    changed secret is checked at the token endpoint, and a token never goes to another server. A 401
    from the server gets one new token and one more try. A token without `expires_in` is not kept.

## Authentik

On the pivotkit-server side, set up the provider as pivotkit's
[Sign-in with Authentik](https://pivotkit.eize.dev/getting-started/kubernetes/#oauth) says, with a
signing key and a scope of its own for REST (`rest.requiredScopes`, a scope mapping in Authentik), and
`rest.audience` set to the provider's client ID, since Authentik puts the client ID into the access
token's `aud`. For this function:

1. Set the provider's **Client Type** to **Confidential** and note its **Client ID** and **Client
   Secret**.
2. In PSU, create a secret of type PSCredential with the client ID as user name and the client secret
   as password, for example `PivotkitClient`.
3. Call the function with `-TokenUri 'https://<authentik>/application/o/token/'` and `-Scope` with
   the REST scope's name, for example `-Scope 'pivotkit:rest'`. Without it Authentik issues a token without
   that scope, and the server answers 403 `INSUFFICIENT_SCOPE` (`PivotTokenRefused`).

Authentik answers the client credentials grant with the provider's client ID and secret and creates a
service account for it (`ak-<provider>-client_credentials`): bind it, or a group it is in, to the
application if the application has bindings
([Authentik: client credentials](https://docs.goauthentik.io/add-secure-apps/providers/oauth2/client_credentials/)).
This sequence was run against Authentik 2026.8.5: the client ID and secret as a PSU secret of type
PSCredential, `-TokenUri` `/application/o/token/` and `-Scope` with the REST scope. Labels and
defaults can change between Authentik releases; decode an access token of your own to check its
`aud` and `scope`.
