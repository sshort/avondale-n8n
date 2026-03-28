# WSL SSH Configuration Guide

This guide explains how to connect to this machine's WSL instance via SSH from a remote device (e.g., iPad with Termius).

## 1. Connection Details
- **Username**: `steve`
- **Port**: `22`
- **Hostname**: `DESKTOP-K48D3JN.local` (Recommended)
- **Backup IP**: `192.168.1.223`

## 2. Infrastructure Status
- **Networking**: WSL is in **mirrored mode**, sharing the host's IP address.
- **Service**: `openssh-server` is installed and set to listen on all interfaces.

## 3. Configuration Steps

### Windows Firewall (Run as Admin)
Run this in PowerShell on the Windows host to allow incoming SSH:
```powershell
New-NetFirewallRule -DisplayName "Allow WSL SSH" -Direction Inbound -Action Allow -Protocol TCP -LocalPort 22
```

### User Authentication
Ensure you have a password or SSH keys configured in WSL:
- **Set password**: `sudo passwd steve`
- **Add SSH Key**: Append your public key to `~/.ssh/authorized_keys`.

## 4. Termius Setup (on iPad)
1. **New Host**: Create a new host in Termius.
2. **Hostname**: `DESKTOP-K48D3JN.local` (Alternative: `192.168.1.223`)
3. **Port**: `22`
4. **Username**: `steve`
5. **Key/Password**: Select your authentication method.
6. **Network**: Ensure your iPad is on the same WiFi network as this machine.
