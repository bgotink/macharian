# Authentication

[Authelia](https://www.authelia.com/) runs in the `auth` namespace to handle authentication via OIDC.
Applicaitons that support it have Authelia configured as OIDC provider, while applications that are used for administration but that don't support authentication are safeguarded by adding authentication on their ingress.
