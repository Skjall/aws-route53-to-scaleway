# AWS Route53 to Scaleway DNS Migration

A powerful shell script to seamlessly migrate DNS records from AWS Route53 to Scaleway DNS.

## Features

- 🚀 Migrates all standard DNS record types (A, AAAA, MX, CNAME, TXT, SRV, etc.)
- 🔄 Preserves TTL values and record data
- 🛡️ Skips conflicting NS and SOA records automatically
- 🐛 Detailed debug logging for troubleshooting
- 🔍 Verifies zone existence before migration
- ⚡ Handles edge cases for different domain formats

## Prerequisites

- Bash shell environment
- AWS CLI installed and configured
- `curl` command-line tool
- `jq` JSON processor
- Valid AWS credentials with Route53 read access
- Valid Scaleway API credentials with DNS management access

## Installation

```bash
# Clone the repository
git clone https://github.com/Skjall/aws-route53-to-scaleway.git

# Change to the directory
cd aws-route53-to-scaleway

# Make the script executable
chmod +x scaleway-dns-migration.sh
```

## Configuration

1. Configure AWS CLI (if not already done):
```bash
aws configure
```

2. Set Scaleway credentials:
```bash
export SCW_SECRET_KEY="your-secret-key"
```

## Usage

```bash
./scaleway-dns-migration.sh <domain-name>
```

Example:
```bash
./scaleway-dns-migration.sh example.com
```

## How It Works

1. **Zone Verification**: Checks if the DNS zone exists in Scaleway
2. **Record Extraction**: Fetches all DNS records from AWS Route53
3. **Smart Filtering**: Excludes conflicting NS records and SOA records
4. **Type-Specific Handling**: Properly formats SRV, MX, and CNAME records
5. **Migration**: Creates records in Scaleway DNS
6. **Verification**: Displays final state of the migrated zone

## Record Type Handling

### Special Cases Handled:

- **SRV Records**: Intelligently handles bare hostnames (e.g., `mail`) by converting them to FQDNs
- **MX Records**: Adds appropriate trailing dots based on hostname format
- **CNAME Records**: Properly formats relative and absolute domain names
- **TXT Records**: Preserves all special characters and formatting

## Example Output

```
AWS Route53 to Scaleway DNS Migration for: example.com
===================================================
Checking available DNS zones...
Starting migration of DNS records from AWS Route53 to Scaleway...
...
Migration complete! Check your records at:
https://console.scaleway.com/domains/external/global/example.com/zones/root/records
```

## Troubleshooting

### Common Issues:

1. **"Not Found" errors**: Ensure the domain is registered in Scaleway
2. **Authentication errors**: Verify your Scaleway API credentials
3. **Invalid SRV records**: Check that hostnames are properly formatted

### Debug Mode

The script includes built-in debug logging. Look for debug blocks in the output for detailed API call information.

## Contributing

Contributions are welcome! Feel free to submit pull requests or report issues.

### Development Guidelines:

1. Maintain backward compatibility
2. Add tests for new features
3. Update documentation as needed
4. Follow the existing code style

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Support

For issues, feature requests, or contributions, please open an issue on GitHub.

## Credits

Created by [Jan Grossheim](https://github.com/Skjall)

---

Made with ❤️ for the #BuyEuropean movement 🇪🇺