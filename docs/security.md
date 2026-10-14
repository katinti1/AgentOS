# AgentOS Security

## Security Principles

1. **Defense in Depth** - Multiple layers of security controls
2. **Least Privilege** - Services run with minimum required permissions
3. **Secure by Default** - Reasonable security defaults out of the box
4. **Transparency** - Security decisions are auditable and documented

## System Security

### Authentication
- User accounts with password authentication
- SSH key authentication for remote access
- Optional sudo for administrative tasks

### Authorization
- Standard Linux discretionary access control (DAC)
- Group-based permissions for shared resources
- User namespace isolation where applicable

### Network Security
- Default firewall rules (ufw/nftables)
- SSH configured with security best practices
- Unnecessary services disabled

### Filesystem Security
- Separate partitions for /tmp, /var, /home
- Encrypted home directories (optional)
- Secure boot support via systemd-boot

## Hermes Agent Security Model

### Privilege Separation
- Agent runs as unprivileged user by default
- Tool access requires explicit approval
- Administrative actions require sudo/su

### Permission System
- Tool allowlist/denylist configuration
- Interactive approval for sensitive operations
- Audit logging for all system interactions

### Network Security
- Outbound connections controlled by configuration
- API key storage in encrypted files
- Provider credentials kept separate from image

### Data Protection
- Conversation history encrypted at rest
- Memory persistence with access controls
- Secure deletion of sensitive data

## Known Security Considerations

### Image Signing
- ISO images should be signed with GPG
- Checksums provided for verification
- OTA updates use signature verification

### Default Accounts
- Default user is unprivileged
- Root password can be set during installation
- SSH key-based auth recommended

### Package Verification
- Debian package signatures verified
- apt uses verified package repositories
- Regular security updates applied

## Security Checklist

Before Release:
- [ ] All packages verified from official repos
- [ ] SSH configured with key-only auth recommended
- [ ] Firewall enabled with default deny
- [ ] Root filesystem encryption option provided
- [ ] Hermes agent permissions documented
- [ ] Image checksums published

## Reporting Security Issues

Report security vulnerabilities to security@agentos.org or via GitHub Security Advisory. Include:
- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested remediation (if any)