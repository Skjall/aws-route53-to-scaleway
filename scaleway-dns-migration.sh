#!/bin/bash

# AWS Route53 to Scaleway DNS Migration Script
# This script exports DNS records from AWS Route53 and imports them to Scaleway

# Parse command line arguments
DRY_RUN=false
DEBUG=false
ZONE_NAME=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --debug)
            DEBUG=true
            shift
            ;;
        --help)
            echo "Usage: $0 [options] <zone-name>"
            echo ""
            echo "Options:"
            echo "  --dry-run    Simulate migration without making changes"
            echo "  --debug      Enable detailed debug logging"
            echo "  --help       Show this help message"
            echo ""
            echo "Example:"
            echo "  $0 --dry-run --debug example.com"
            exit 0
            ;;
        *)
            ZONE_NAME="$1"
            shift
            ;;
    esac
done

# Check if required tools are installed
for cmd in aws curl jq; do
    if ! command -v $cmd >/dev/null 2>&1; then
        echo "Error: $cmd is required but not installed."
        exit 1
    fi
done

# Function to check AWS CLI configuration
check_aws_config() {
    # Check if AWS CLI is configured by looking for credentials or config files
    if ! aws sts get-caller-identity >/dev/null 2>&1; then
        echo "AWS CLI is not configured or credentials are invalid."
        read -p "Would you like to configure AWS now? (y/n): " configure_aws
        if [[ "$configure_aws" =~ ^[Yy]$ ]]; then
            aws configure
            # Verify configuration worked
            if ! aws sts get-caller-identity >/dev/null 2>&1; then
                echo "Error: AWS configuration failed. Please configure AWS CLI manually."
                exit 1
            fi
        else
            echo "AWS CLI configuration is required for this script to work."
            exit 1
        fi
    fi

    # Get AWS account info (partially anonymized)
    AWS_ACCOUNT_INFO=$(aws sts get-caller-identity --output json)
    AWS_ACCOUNT_ID=$(echo "$AWS_ACCOUNT_INFO" | jq -r '.Account')
    AWS_USER_ID=$(echo "$AWS_ACCOUNT_INFO" | jq -r '.UserId')

    # Partially anonymize the account ID and user ID
    MASKED_ACCOUNT_ID="${AWS_ACCOUNT_ID:0:4}...${AWS_ACCOUNT_ID: -4}"
    MASKED_USER_ID="${AWS_USER_ID:0:4}...${AWS_USER_ID: -4}"

    echo "Using AWS Credentials:"
    echo "  Account: $MASKED_ACCOUNT_ID"
    echo "  User ID: $MASKED_USER_ID"

    read -p "Continue with these AWS credentials? (y/n): " confirm_aws
    if [[ ! "$confirm_aws" =~ ^[Yy]$ ]]; then
        echo "Operation cancelled by user."
        exit 0
    fi
}

# Function to check and configure Scaleway API credentials
check_scaleway_config() {
    if [ -z "$SCW_ACCESS_KEY" ] || [ -z "$SCW_SECRET_KEY" ]; then
        echo "Scaleway API credentials not found in environment variables."
        read -p "Would you like to set Scaleway credentials now? (y/n): " configure_scw
        if [[ "$configure_scw" =~ ^[Yy]$ ]]; then
            read -p "Enter your Scaleway Access Key: " SCW_ACCESS_KEY
            read -p "Enter your Scaleway Secret Key: " SCW_SECRET_KEY

            # Export the variables so they're available to the script
            export SCW_ACCESS_KEY
            export SCW_SECRET_KEY

            echo "Scaleway credentials set temporarily for this session."
            echo "To make them permanent, add the following to your ~/.bashrc or ~/.zshrc:"
            echo "  export SCW_ACCESS_KEY='$SCW_ACCESS_KEY'"
            echo "  export SCW_SECRET_KEY='$SCW_SECRET_KEY'"
        else
            echo "Scaleway API credentials are required for this script to work."
            echo "Please set SCW_ACCESS_KEY and SCW_SECRET_KEY environment variables"
            echo "Example: export SCW_ACCESS_KEY='your-access-key'"
            echo "         export SCW_SECRET_KEY='your-secret-key'"
            exit 1
        fi
    fi

    # Display partially anonymized keys for confirmation
    MASKED_ACCESS_KEY="${SCW_ACCESS_KEY:0:4}...${SCW_ACCESS_KEY: -4}"
    MASKED_SECRET_KEY="${SCW_SECRET_KEY:0:4}...${SCW_SECRET_KEY: -4}"

    echo "Using Scaleway credentials:"
    echo "  Access Key: $MASKED_ACCESS_KEY"
    echo "  Secret Key: $MASKED_SECRET_KEY"

    # Verify Scaleway credentials by making a test API call
    echo "Verifying Scaleway credentials..."
    local response=$(curl -s -X GET \
        -H "X-Auth-Token: $SCW_SECRET_KEY" \
        -H "Content-Type: application/json" \
        "https://api.scaleway.com/domain/v2beta1/dns-zones")

    if echo "$response" | grep -q "error\|unauthorized\|invalid"; then
        echo "Error: Scaleway credentials appear to be invalid."
        echo "Response: $(echo "$response" | jq -r '.message // "Unknown error"')"
        exit 1
    else
        echo "Scaleway credentials verified successfully."
    fi

    read -p "Continue with these Scaleway credentials? (y/n): " confirm_scw
    if [[ ! "$confirm_scw" =~ ^[Yy]$ ]]; then
        echo "Operation cancelled by user."
        exit 0
    fi
}

# Check if zone name was provided
if [ -z "$ZONE_NAME" ]; then
    echo "Usage: $0 [options] <zone-name>"
    echo "Use --help for more information"
    exit 1
fi

# Check and configure AWS and Scaleway
check_aws_config
check_scaleway_config

# Configuration
SCALEWAY_API_URL="https://api.scaleway.com/domain/v2beta1"
AUTH_TOKEN="$SCW_SECRET_KEY"

# Debug logging function
debug_log() {
    if [ "$DEBUG" = true ]; then
        echo "DEBUG: $1" >&2
    fi
}

# Function to get AWS Route53 records
get_aws_route53_records() {
    local zone_name=$1

    # Get the hosted zone ID
    local hostedzoneid=$(aws route53 list-hosted-zones --output json | jq -r ".HostedZones[] | select(.Name == \"$zone_name.\") | .Id" | cut -d'/' -f3)

    if [ -z "$hostedzoneid" ]; then
        echo "Error: Could not find hosted zone for $zone_name in AWS Route53"
        exit 1
    fi

    debug_log "Found hosted zone ID: $hostedzoneid"

    # Get all records and handle multi-value records (like split TXT records)
    aws route53 list-resource-record-sets --hosted-zone-id $hostedzoneid --output json | \
    jq -r '.ResourceRecordSets[] |
    if .Type == "TXT" then
        # For TXT records, join all values
        "\(.Name)\t\(.TTL)\t\(.Type)\t\(.ResourceRecords | map(.Value | gsub("\""; "")) | join(""))"
    else
        # For other record types, use the first value only
        "\(.Name)\t\(.TTL)\t\(.Type)\t\(.ResourceRecords[]?.Value)"
    end' | \
    # Skip NS records for root domain and SOA records
    grep -Ev "(^${zone_name}\..*NS|SOA)" | \
    # Convert wildcards and clean names
    sed "s/\\\052/*/g" | \
    sed "s/\.${zone_name}\.//g" | \
    sed "s/^${zone_name}\./@/" | \
    # Remove trailing dots from the name field
    sed 's/\.\t/\t/'
}

# Function to debug API calls
debug_api_call() {
    local method=$1
    local url=$2
    local data=$3

    if [ "$DEBUG" = true ]; then
        echo "DEBUG: API Call Details" >&2
        echo "----------------------" >&2
        echo "Method: $method" >&2
        echo "URL: $url" >&2
        echo "Headers:" >&2
        echo "  X-Auth-Token: ${AUTH_TOKEN:0:10}..." >&2
        echo "  Content-Type: application/json" >&2
        echo "Data:" >&2
        echo "$data" | jq . >&2
        echo "----------------------" >&2
    fi
}

# Function to create or update a record in Scaleway
update_scw_record() {
    local domain_name=$1
    local record_name=$2
    local record_type=$3
    local record_data=$4
    local ttl=$5

    if [ "$DRY_RUN" = true ]; then
        echo "[DRY RUN] Would create/update record: $record_name ($record_type)"
        debug_log "Would use data: $record_data"
        return 0
    fi

    echo "Creating/updating record: $record_name ($record_type) in Scaleway"

    # Handle special characters in record names
    local api_name="$record_name"
    if [ "$api_name" == "@" ]; then
        api_name=""
    fi

    # Escape quotes in data
    local escaped_data=$(echo "$record_data" | sed 's/"/\\"/g')

    # For SRV records, ensure proper FQDN format
    if [ "$record_type" == "SRV" ]; then
        # Check if data has exactly 4 parts
        if [[ "$escaped_data" =~ ^[0-9]+[[:space:]]+[0-9]+[[:space:]]+[0-9]+[[:space:]]+(.+)$ ]]; then
            local srv_target="${BASH_REMATCH[1]}"
            # If target already has a trailing dot, use as is
            if [[ "$srv_target" =~ \.$ ]]; then
                # Already has trailing dot, use as is
                escaped_data="${escaped_data%$srv_target}${srv_target}"
            # If target doesn't have a trailing dot, check if it's a bare hostname
            elif [[ "$srv_target" =~ ^[^\.]+$ ]]; then
                # It's a bare hostname like "mail", make it a FQDN
                escaped_data="${escaped_data%$srv_target}${srv_target}.${domain_name}."
            else
                # It has dots but no trailing dot, add one
                escaped_data="${escaped_data%$srv_target}${srv_target}."
            fi
        fi
    fi

    # For MX records, ensure proper FQDN format
    if [ "$record_type" == "MX" ]; then
        if [[ "$escaped_data" =~ ^([0-9]+[[:space:]]+)(.+)$ ]]; then
            local priority="${BASH_REMATCH[1]}"
            local mx_target="${BASH_REMATCH[2]}"
            # If target already has a trailing dot, use as is
            if [[ "$mx_target" =~ \.$ ]]; then
                # Already has trailing dot, use as is
                escaped_data="${priority}${mx_target}"
            # If target doesn't have a trailing dot, check if it's a bare hostname
            elif [[ "$mx_target" =~ ^[^\.]+$ ]]; then
                # It's a bare hostname like "mail", make it a FQDN
                escaped_data="${priority}${mx_target}.${domain_name}."
            else
                # It has dots but no trailing dot, add one
                escaped_data="${priority}${mx_target}."
            fi
        fi
    fi

    # For CNAME records, ensure proper FQDN format
    if [ "$record_type" == "CNAME" ]; then
        # If target already has a trailing dot, use as is
        if [[ "$escaped_data" =~ \.$ ]]; then
            # Already has trailing dot, use as is
            :
        # If target doesn't have a trailing dot, check if it's a bare hostname
        elif [[ "$escaped_data" =~ ^[^\.]+$ ]]; then
            # It's a bare hostname like "mail", make it a FQDN
            escaped_data="${escaped_data}.${domain_name}."
        else
            # It has dots but no trailing dot, add one
            escaped_data="${escaped_data}."
        fi
    fi

    # Prepare the API data (using the format from the docs)
    local api_data=$(cat <<EOF
{
    "changes": [{
        "add": {
            "records": [{
                "name": "$api_name",
                "type": "$record_type",
                "ttl": $ttl,
                "data": "$escaped_data"
            }]
        }
    }]
}
EOF
)

    # Debug the API call
    local api_url="${SCALEWAY_API_URL}/dns-zones/${domain_name}/records"
    debug_api_call "PATCH" "$api_url" "$api_data"

    # Make the API call
    local response=$(curl -s -X PATCH \
        -H "X-Auth-Token: $AUTH_TOKEN" \
        -H "Content-Type: application/json" \
        -d "$api_data" \
        "$api_url")

    if [ "$DEBUG" = true ]; then
        echo "API Response:" >&2
        echo "$response" | jq . >&2
        echo >&2
    fi

    if echo "$response" | grep -q "error\|message"; then
        echo "Warning: Possible error in API response"
        if [ "$DEBUG" = false ]; then
            echo "Run with --debug for more details"
        fi
    else
        echo "Success!"
    fi
}

# Function to migrate records from AWS to Scaleway
migrate_records() {
    local zone_name=$1

    echo "Starting migration of DNS records from AWS Route53 to Scaleway..."
    if [ "$DRY_RUN" = true ]; then
        echo "DRY RUN MODE - No changes will be made"
    fi
    echo "==============================================================="

    # Get AWS records and save to temporary file
    local temp_file=$(mktemp)
    echo "Fetching records from AWS Route53 for zone: $zone_name"

    get_aws_route53_records "$zone_name" > "$temp_file"

    echo "AWS Route53 records to be migrated:"
    echo "-----------------------------------"
    cat "$temp_file"
    echo "-----------------------------------"

    # Read each record and create it in Scaleway
    local count=0
    while IFS=$'\t' read -r name ttl type data; do
        # Skip empty lines
        [ -z "$name" ] && continue

        echo
        echo "Migrating: $name $ttl $type $data"
        update_scw_record "$zone_name" "$name" "$type" "$data" "$ttl"

        count=$((count + 1))

        # Small delay to avoid rate limiting (only in non-dry-run mode)
        if [ "$DRY_RUN" = false ]; then
            sleep 1
        fi
    done < "$temp_file"

    # Clean up
    rm "$temp_file"

    echo
    echo "==============================================================="
    if [ "$DRY_RUN" = true ]; then
        echo "Dry run complete! Would have migrated $count records"
    else
        echo "Migration complete! Migrated $count records"
    fi
}

# Function to display Scaleway zone records
get_scw_zone_records() {
    local domain_name=$1

    echo "Current records in Scaleway zone: $domain_name"
    echo "---------------------------------------------"

    local response=$(curl -s -X GET \
        -H "X-Auth-Token: $AUTH_TOKEN" \
        -H "Content-Type: application/json" \
        "$SCALEWAY_API_URL/dns-zones/$domain_name/records")

    if [ "$DEBUG" = true ]; then
        echo "Raw API response:" >&2
        echo "$response" | jq . >&2
        echo >&2
    fi

    echo "Parsed records:"
    echo "$response" | jq -r '.records[]? | "\(if .name == "" then "@" else .name end)\t\(.ttl)\t\(.type)\t\(.data)"'
}

# Function to list DNS zones
list_dns_zones() {
    if [ "$DEBUG" = true ]; then
        echo "Checking available DNS zones..."
        echo "-----------------------------"

        local response=$(curl -s -X GET \
            -H "X-Auth-Token: $AUTH_TOKEN" \
            -H "Content-Type: application/json" \
            "$SCALEWAY_API_URL/dns-zones/")

        echo "Available DNS zones:"
        echo "$response" | jq -r '.dns_zones[]? | "\(.domain)\t\(.subdomain)\t\(.status)"'
        echo
    fi
}

# Main execution
echo "AWS Route53 to Scaleway DNS Migration for: $ZONE_NAME"
echo "==================================================="

# First, list available DNS zones to confirm the zone exists (only in debug mode)
list_dns_zones

# Start the migration
migrate_records "$ZONE_NAME"

# Display final results (only if not in dry-run mode)
if [ "$DRY_RUN" = false ]; then
    echo
    echo "Final state of Scaleway zone:"
    echo "============================="
    get_scw_zone_records "$ZONE_NAME"
fi

echo
echo "Migration complete!"