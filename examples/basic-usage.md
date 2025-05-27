# Basic Usage Examples

## Simple Domain Migration

```bash
# Migrate a basic domain
./scaleway-dns-migration.sh example.com
```

## Advanced Usage

### With AWS Profile

```bash
# Use a specific AWS profile
AWS_PROFILE=production ./scaleway-dns-migration.sh example.com
```

### Dry Run

```bash
# Would perform a dry run without making changes
./scaleway-dns-migration.sh --dry-run example.com
```

## Common Scenarios

### Migrating Mail Server Records

When migrating domains with mail servers, pay special attention to:
- MX records
- SPF records (TXT)
- DKIM records (TXT)
- DMARC records (TXT)
- SRV records for mail services

Example output:
```
Migrating: @ 300 MX 10 mail.example.com
Creating/updating record: @ (MX) in Scaleway
API Response:
{
  "records": [
    {
      "id": "uuid",
      "data": "10 mail.example.com.",
      "name": "",
      "priority": 10,
      "ttl": 300,
      "type": "MX"
    }
  ]
}
```

### Migrating Complex Records

#### SRV Records
SRV records are properly formatted to ensure compatibility:
```
_sip._tcp SRV 10 5 5060 sipserver
→ Becomes: "10 5 5060 sipserver.example.com."
```

#### CNAME Records
CNAME records are checked for proper domain formatting:
```
www CNAME server
→ Becomes: "server.example.com."
```

## Troubleshooting

### Common Issues and Solutions

1. **Authentication Error**
   ```bash
   # Verify credentials
   echo $SCW_SECRET_KEY

   # Re-export if needed
   export SCW_SECRET_KEY="your-secret-key"
   ```

2. **Zone Not Found**
   ```bash
   # List available zones
   curl -H "X-Auth-Token: $SCW_SECRET_KEY" \
        https://api.scaleway.com/domain/v2beta1/dns-zones/
   ```

3. **Invalid Record Format**
   - Check for proper FQDN formatting
   - Ensure SRV records have correct priority, weight, port, and target
   - Verify TXT records are properly escaped

## Best Practices

1. **Backup Before Migration**
   ```bash
   # Export current Scaleway zone (if any)
   aws route53 list-resource-record-sets \
       --hosted-zone-id YOUR_ZONE_ID > backup.json
   ```

2. **Test with Non-Critical Domain First**
   - Use a test domain to verify the process
   - Check all record types are migrated correctly

3. **Monitor After Migration**
   - Verify DNS propagation using tools like `dig`
   - Test critical services (email, web, etc.)
   - Keep AWS records for a transition period