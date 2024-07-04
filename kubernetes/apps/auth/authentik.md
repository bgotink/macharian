# Authentik setup

To fully set up authentik, more configuration is required in the application itself.

## Expose the embedded outpost

First up: exposing the [embedded outpost](https://docs.goauthentik.io/docs/outposts/embedded/).
Go to the admin menu, `Applications`, `Outposts`, and edit the single existing outpost.

1. The empty `integration` option should be set to `Local Kubernetes Cluster`
1. Check whether the `authentik_host` is set to the correct hostname under `Advanced Settings`

Step one will cause Authentik to register an extra service in kubernetes: `ak-outpost-authentik-embedded-outpost`.
If you've renamed the Outpost, this service will have a different name, and you'll have to account for that later on in this document.

## Adding applications

All applications requiring authentication have to be set up.
How this is done depends on how the application has to be protected:

- Applications that support authentication & integrate via OIDC -> OIDC
- Applications without authentication: Proxy

They both start the same, but then deviate once we get to the provider stage:

1. Go to `Applications`, `Applications`, in the admin menu
1. Click the `Create with Wizard` button
1. Give the app a name, optionally edit the slug, and add a group (e.g. `Media` for all media-related hosts)
1. Click `Next` and select the correct provider. See the following subsections for what to do

### Adding an OIDC application

1. Select `OAuth2/OpenID Provider`
1. Update the name to `<name of app> OIDC`
1. Select `Authentication flow` `default-authentication-flow`
1. Select `Authorization flow` `default-provider-authorization-explicit-consent`
1. Fill in the correct parameters for your integration. Check the [Authentik website](https://docs.goauthentik.io/integrations/) for information on a bunch of possible apps, including Immich, pgAdmin and NextCloud.
1. Don't forget to confirm the process before you try it out.

### Adding a Proxy application

1. Select `Proxy Provider`
1. Update the name to `<name of app> Proxy Auth`
1. Select `Authentication flow` `default-authentication-flow`
1. Select `Authorization flow` `default-provider-authorization-implicit-consent`
1. Select `Forward Auth (single application)` and enter the host name of the application you want to authenticate
1. Set `Token Validity` to something useful, e.g. `hours=24`
1. Confirm
1. Go to `Applications`, `Outposts`, in the admin interface and click edit on the embedded outpost
1. Add the newly added application to the `Selected Applications`

Configure the application's ingress with the following `annotations`:

```yaml
nginx.ingress.kubernetes.io/auth-url: |-
  http://ak-outpost-authentik-embedded-outpost.auth.svc.cluster.local:9000/outpost.goauthentik.io/auth/nginx
nginx.ingress.kubernetes.io/auth-signin: |-
  https://<host>/outpost.goauthentik.io/start?rd=$escaped_request_uri
nginx.ingress.kubernetes.io/auth-response-headers: |-
  Set-Cookie,X-authentik-username,X-authentik-groups,X-authentik-email,X-authentik-name,X-authentik-uid
nginx.ingress.kubernetes.io/auth-snippet: |
  proxy_set_header X-Forwarded-Host $http_host;
```

When using a Proxy Provider, there are three options:

- Actually use Authentik as a reverse proxy, in which case we'd have to tell the ingress not to go to the service directly but instead use the Authentik Outpost as service.
  This option is likely the safest, but it adds an extra reverse proxy in between the outside world and the kubernetes service.
	Given the nature of some of these applications (media services) this doesn't feel like the right solution, and since this is a homelab, no one is here to tell me my feelings are wrong.
- Forward authentication, where the path `/outpost.goauthentik.io` is forwarded to Authentik for authentication, but the rest of the host is sent directly from the ingress to the actual service.
  This comes in two flavours: "single application" and "domain level".
	Domain level is less work, but it makes it impossible to add more fine-grained access control, so this option was not retained.
	Single application requires setting up extra ingress objects to send the `/outpost.goauthentik.io` path to the Authentik Outpost, but since the outpost's `integration` is set to `Local Kubernetes Cluster` Authentik will actually take care of this for us.

The option "single application forward authentication" came out on top.
