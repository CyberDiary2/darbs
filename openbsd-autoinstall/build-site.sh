#!/bin/ksh
#
# build-site.sh - packages install.site into site78.tgz
#
# Usage: ./build-site.sh
# Output: site78.tgz (place on your install server or USB)
#

set -e

cd "$(dirname "$0")"

STAGING=$(mktemp -d)

mkdir -p "$STAGING"
cp install.site "$STAGING/install.site"
chmod +x "$STAGING/install.site"

cd "$STAGING"
tar czf site78.tgz install.site
mv site78.tgz "$(dirname "$0")/"

rm -rf "$STAGING"

echo "Built site78.tgz"
echo ""
echo "To use:"
echo "  1. Boot the OpenBSD 7.8 install ISO"
echo "  2. At the prompt, type: install"
echo "  3. When asked for 'Location of sets', choose 'disk' or 'http'"
echo "  4. Make sure site78.tgz and install.conf are accessible"
echo ""
echo "Option A - USB:"
echo "  Put install.conf and site78.tgz on a FAT-formatted USB stick"
echo "  The installer will find them automatically"
echo ""
echo "Option B - HTTP server:"
echo "  Host install.conf and site78.tgz on a local HTTP server"
echo "  Boot with: autoinstall"
echo "  Set DHCP option 66 (next-server) to your HTTP server IP"
