# Harbor Setup on a VPS

## Overview

This document describes the installation and configuration of Harbor as a central container registry for the JEDO-Ecosystem on a VPS.

**Goal**: Operate Harbor registry at `https://harbor.jedo.me` for centralized versioning and distribution of Docker images to all locations.

## System Specifications

- **Provider**: Infomaniak VPS
- **Resources**: 4 GB RAM, 2 vCPU, IPv4
- **Operating System**: Ubuntu 24.04 LTS
- **Harbor Version**: 2.14.1
- **Docker Version**: 29.1.3
- **Docker Compose Version**: 5.0.0

## DNS Configuration

DNS A-Record: harbor.jedo.me → 83.228.219.30

## Installation & Hardening

1. Update System
2. SSH Hardening (already done by VPS-Provider)
3. Firewall Configuration (@VPS)
**Allowed Ports**:
- Port 22 (SSH) - ssh
- Port 80 (HTTP) - for Let's Encrypt certificate renewal
- Port 443 (HTTPS) - for Harbor access

4. Docker Installation
5. Let's Encrypt SSL-Certificat via Certbot
sudo certbot certonly --standalone -d harbor.jedo.me
6. Harbor Installation & Configuration (--with-trivy)
7. Smoke Test from local terminal
docker pull alpine:latest
docker tag alpine:latest harbor.jedo.me/library/alpine:test
docker login harbor.jedo.me
docker push harbor.jedo.me/library/alpine:test
docker rmi harbor.jedo.me/library/alpine:test
docker pull harbor.jedo.me/library/alpine:test

## Troubleshooting Common Issues
### SSL Certificate Error in Browser

**Problem**: Browser shows SSL warning

**Causes & Solutions**:
- DNS propagation not completed → Wait (up to 24h)
- Certificate paths in `harbor.yml` incorrect → Verify paths
- Certificate not readable → Check permissions (`chmod 644` for .crt, `chmod 600` for .key)

### Docker Login Fails

**Problem**: `Error response from daemon: Get "https://harbor.jedo.me/v2/": unauthorized`

**Solution**:
1. Verify password (harbor.yml)
2. Restart Harbor
cd /opt/harbor/harbor
sudo docker compose restart
3. Try again
docker login harbor.jedo.me

### "Permission Denied" on Push

**Problem**: `denied: requested access to the resource is denied`

**Cause**: User has no permission for the project

**Solution**:
1. Harbor UI → Projects → library → Members
2. Add user with role "Developer" or "Maintainer"
### Disk Space Issues

**Problem**: Harbor containers stop due to full disk

**Solution**:
1. Clean up Docker
docker system prune -a --volumes

2. Rotate Harbor logs
sudo find /var/log/harbor -name "*.log" -mtime +30 -delete

3. Monitor disk space
df -h
du -sh /data

### Let's Encrypt Renewal Fails

**Problem**: Certificate expires, automatic renewal doesn't work

**Solution**:
1. Renew manually
sudo certbot renew --force-renewal

2. Copy certificates to Harbor
sudo cp /etc/letsencrypt/live/harbor.jedo.me/fullchain.pem /opt/harbor/ssl/harbor.jedo.me.crt
sudo cp /etc/letsencrypt/live/harbor.jedo.me/privkey.pem /opt/harbor/ssl/harbor.jedo.me.key

3. Restart Harbor proxy
cd /opt/harbor/harbor
sudo docker compose restart proxy

### Trivy Scanner Not Working

**Problem**: Scans fail or Trivy is unavailable

**Solution**:
1. Check Trivy container status
cd /opt/harbor/harbor
sudo docker compose ps trivy-adapter

2. Check Trivy logs
sudo docker compose logs trivy-adapter

3. If not installed: enable afterwards
sudo docker compose down
sudo ./prepare --with-trivy
sudo docker compose up -d

## Backup Strategy (not implemented)

### Important data for backup:
- Harbor configuration: `/opt/harbor/harbor/harbor.yml`
- SSL certificates: `/opt/harbor/ssl/`
- Harbor data: `/data` (Docker volumes)
- Database: Harbor PostgreSQL volume

### Backup command:
1. Stop Harbor
cd /opt/harbor/harbor
sudo docker compose stop

2. Create backup
sudo tar czf harbor-backup-$(date +%Y%m%d).tar.gz
/opt/harbor/harbor/harbor.yml
/opt/harbor/ssl/
/data

3. Start Harbor
sudo docker compose start

## Maintenance & Updates

### Update Harbor

1. Create backup
2. Download new version
3. Stop Harbor, install new version, start Harbor
4. Details: https://goharbor.io/docs/latest/administration/upgrade/

### System Updates

sudo apt update && sudo apt upgrade -y
sudo reboot # If kernel update

## References

- Harbor Documentation: https://goharbor.io/docs/
- Docker Documentation: https://docs.docker.com/
- Let's Encrypt: https://letsencrypt.org/
- Certbot: https://certbot.eff.org/