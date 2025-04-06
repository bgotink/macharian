# Macharian

This repository contains everything I've got running on my home servers.

## Servers

My setup is currently as follows:

- macharian: the physical machine running Debian with several KVM guests:
	- andosk: Ubuntu VM running [pi-hole](https://github.com/pi-hole/pi-hole)
	- cytheris: Ubuntu VM running Kubernetes
	- Yix: Ubuntu VM running [MinIO](https://github.com/minio/minio) for S3 storage
	- Persepolis: Home Assistant OS VM
	- Gallosque: Ubuntu VM running [Tailscale VPN](https://tailscale.com/) for outside access
- gallosque nebula: A [Scaleway](https://scaleway.com/) VPS running an NGINX reverse proxy that exposes certain services via gallosque over Tailscale to the outside world.

## Kubernetes

The kubernetes cluster currently consists of a single node (cytheris) running [microk8s](https://github.com/canonical/microk8s).
The cluster is managed via [Flux](https://github.com/fluxcd/flux2) which uses the [`kubernetes`](./kubernetes) folder in this repository as source. [Renovate](https://github.com/renovatebot/renovate) helps keep everything up to date.

The core components are:

- [cert-manager](https://github.com/cert-manager/cert-manager): Creates SSL certificates for everything running in the cluster
- [cilium](https://github.com/cilium/cilium): Internal Kubernetes networking
- [ingress-nginx](https://github.com/kubernetes/ingress-nginx): Ingress controller for everything running in kubernetes that is exposed to the internal network, or via Gallosque to the external network
- [authentik](https://github.com/goauthentik/authentik): Single Sign-On either via OIDC or integrated via ingress-nginx
- [sops](https://github.com/getsops/sops): Keeps secrets commited in this repo actually secret

The applications running on kubernetes fall into several categories:

- Self-hosted storage for Photos via [Immich](https://immich.app/) and documents/calendars via [NextCloud](https://nextcloud.com/)
- A Media Center, running in the media namespace, with automated tracking of movies, shows, and artists; using [Plex](https://plex.tv/), [*arr](https://wiki.servarr.com/), and more.
- Smaller stuff like a [Unifi](https://ui.com) controller or a wiki for a [WarHammer 40k Imperium Maledictum](https://cubicle7games.com/warhammer-40k-roleplay-imperium-maledictum) roleplay group
- Underlying technology such as [Redis](https://github.com/redis/redis) and [PostgreSQL](https://www.postgresql.org/)

## Hardware

- 1x ASUS NUC14RVHU7000R0 Revel Canyon U7 155H
	- 64 GB RAM
	- 1x 2TB M.2 NVMe
	- 1x 4TB SATA SSD (warp)

This hardware is currently situated next to our TV, which greatly hampers the options for expansion.
I would love to expand and add proper storage (a NAS) and at least one other server, but that has to wait until after we've moved to a house that doesn't only have network cables in the living room.

## Gratitude

I might be a software engineer but I had little to no experience with Kubernetes and DevOps when I bought my server.
The [home-ops repo of GitHub user onedr0p](https://github.com/onedr0p/home-ops) has been instrumental in getting me started with flux and renovate, and I use a lot of [containers](https://github.com/home-operations/containers) they have set up.
