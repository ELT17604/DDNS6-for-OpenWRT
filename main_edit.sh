#!/bin/bash


###############
# Set config here #
###############

API_KEY="YOUR_KEY_HERE"
ZONE_ID="YOUR_ZONE_ID_HERE"
DOMAIN="YOUR_DOMAIN_HERE"
LOG_FILE="LOG_PATH_HERE"
CURRENT_IP_FILE="PATH_HERE"

###############
#   End   Config   #
###############


# cd to path and Write start time to log
cd /PATH/TO/THIS/FILE

# LOG_LEVEL = 1
echo "$(date): <info> -----!!!executed!!!-----" >> "$LOG_FILE"

# LOG_LEVEL = 0
#echo "$(date): <debug> cd to path completed" >> "$LOG_FILE"


# Get local IPV6 Address
get_ipv6_address() {
    local interface=$1
    ip -6 addr show dev $interface | grep 'inet6' | awk '{print $2}' | cut -d/ -f1 | grep -v '^fe80:'
}

detect_ipv6() {
    local interface="pppoe-wan"
    get_ipv6_address $interface
}

getIpv6Address() {
    LOCAL_IPV6=$(detect_ipv6)
}

getIpv6Address

# LOG_LEVEL = 1
echo "$(date): <info> IPV6 address get: $LOCAL_IPV6" >> "$LOG_FILE"


# Check if local IP matches recorded IP
if [ -f "$CURRENT_IP_FILE" ]; then
    CURRENT_IP=$(cat "$CURRENT_IP_FILE")
    if [ "$CURRENT_IP" == "$LOCAL_IPV6" ]; then
	
	# LOG_LEVEL = 2
        echo "$(date): <warning> Same IP, skipping." >> "$LOG_FILE"
        
	exit 0
    fi
fi


# Get DNS record from CF
RECORD_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records?type=AAAA&name=${DOMAIN}" \
    -H "X-Auth-Email: YOUR_EMAIL@HERE" \
    -H "X-Auth-Key: ${API_KEY}" | \
    jsonfilter -e '$.result[0].id')

# LOG_LEVEL = 0
#echo "$(date): <debug> CF DNS IPV6 address get:$(RECORD_ID)" >> "$LOG_FILE"


# If no record, create one
if [ -z "$RECORD_ID" ]; then

# LOG_LEVEL = 2
echo "$(date): <warning> CF DNS record D.N.E. Tring to create new record!" >> "$LOG_FILE"

    curl -s -X POST "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records" \
        -H "X-Auth-Email: YOUR_EMAIL@HERE" \
        -H "X-Auth-Key: ${API_KEY}" \
        -H "Content-Type: application/json" \
        --data "{\"type\":\"AAAA\",\"name\":\"${DOMAIN}\",\"content\":\"${LOCAL_IPV6}\",\"ttl\":1,\"proxied\":true}"

    if [ $? -eq 0 ]; then
	
	# LOG_LEVEL = 1
        echo "$(date): <info> DNS record created successfully for ${DOMAIN} with IPv6: ${LOCAL_IPV6}" >> "$LOG_FILE"

        echo "$LOCAL_IPV6" > "$CURRENT_IP_FILE"

	# LOG_LEVEL = 0
        #echo "$(date): <debug> Local IP wrote to file CURRENT_IP" >> "$LOG_FILE"
	
    else
	
	# LOG_LEVEL = 3
        echo "$(date): <error> Failed to create DNS record for ${DOMAIN}" >> "$LOG_FILE"

    fi
else


# Since DNS record exists, continue to check if the same as local.
    CURRENT_CLOUDFLARE_IPV6=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records/${RECORD}" \
	-H "X-Auth-Email: YOUR_EMAIL@HERE" \
        -H "X-Auth-Key: ${API_KEY}" | \
        jsonfilter -e '$.result.content')

# LOG_LEVEL = 0
#echo "$(date): <debug> Get CF remote DNS record : ${CURRENT_CLOUDFLARE_IPV6}" >> "$LOG_FILE"


# Check if remote DNS record matches local IP
    if [ "$CURRENT_CLOUDFLARE_IPV6" == "$LOCAL_IPV6" ]; then

	# LOG_LEVEL = 1
        echo "$(date): <info> DNS record for ${DOMAIN} is already up to date with IPv6: ${LOCAL_IPV6}" >> "$LOG_FILE"
        
	echo "$LOCAL_IPV6" > "$CURRENT_IP_FILE"

	# LOG_LEVEL = 0
	#echo "$(date): <debug> Current local IP wrote to file CURRENT_IP" >> "$LOG_FILE"

    else
        curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records/${RECORD_ID}" \
            -H "X-Auth-Email: YOUR_EMAIL@HERE" \
            -H "X-Auth-Key: ${API_KEY}" \
            -H "Content-Type: application/json" \
            --data "{\"type\":\"AAAA\",\"name\":\"${DOMAIN}\",\"content\":\"${LOCAL_IPV6}\",\"ttl\":1,\"proxied\":true}"

        if [ $? -eq 0 ]; then

	    # LOG_LEVEL = 1
            echo "$(date): <info> DNS record updated successfully for ${DOMAIN} with IPv6: ${LOCAL_IPV6}" >> "$LOG_FILE"

            echo "$LOCAL_IPV6" > "$CURRENT_IP_FILE"

	    # LOG_LEVEL = 0
	    #echo "$(date): <debug> Current local IP wrote to file CURRENT_IP" >> "$LOG_FILE"

        else

	    # LOG_LEVEL = 3
            echo "$(date): <error> Failed to update DNS record for ${DOMAIN}" >> "$LOG_FILE"

        fi
    fi
fi

