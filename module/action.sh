#!/system/bin/sh

set -e
set -u

# Enable verbose debugging
#set -x

PATH=/data/adb/ap/bin:/data/adb/ksu/bin:/data/adb/magisk:/data/data/com.termux/files/usr/bin:$PATH
MODDIR=/data/adb/modules/playintegrityfix
TEMPDIR="$MODDIR/temp"
mkdir -p "$TEMPDIR"
cd "$TEMPDIR"

echo "[+] PIF-Next: Iniciando atualização de fingerprint..."

# ───────────────────────────────
# Funções utilitárias
# ───────────────────────────────
die() { echo "[!] $1"; exit 1; }

download_fail() {
    echo "[!] Falha ao baixar de: $1"
    rm -rf "$TEMPDIR"
    die "Abortando devido a falha no download"
}

download() {
    if command -v curl > /dev/null 2>&1; then
        curl --connect-timeout 10 -s "$1" -o "$2" || download_fail "$1"
    else
        busybox wget -T 10 --no-check-certificate -qO "$2" "$1" || download_fail "$1"
    fi
}

# ───────────────────────────────
# Baixar versão atual do Android Beta
# ───────────────────────────────
echo "[*] Baixando página principal de versões Android..."
download https://developer.android.com/about/versions PIXEL_VERSIONS_HTML

BETA_URL=$(grep -o 'https://developer.android.com/about/versions/[^"]*' PIXEL_VERSIONS_HTML | sort -ru | head -n1)
[ -z "$BETA_URL" ] && die "URL do beta não encontrada"
echo "[*] URL da versão beta: $BETA_URL"
download "$BETA_URL" PIXEL_LATEST_HTML

# Verifica se é Preview
if grep -qE 'Developer Preview|tooltip>.*preview program' PIXEL_LATEST_HTML; then
    BETA_URL=$(grep -o 'https://developer.android.com/about/versions/[^"]*' PIXEL_VERSIONS_HTML | sort -ru | head -n2 | tail -n1)
    echo "[*] Preview detectado. Usando segunda versão disponível: $BETA_URL"
    download "$BETA_URL" PIXEL_BETA_HTML
else
    echo "[*] Versão estável detectada."
    mv -f PIXEL_LATEST_HTML PIXEL_BETA_HTML
fi

# ───────────────────────────────
# Baixa OTA Metadata
# ───────────────────────────────
OTA_URL="https://developer.android.com$(grep -o 'href="/.*download-ota[^"]*"' PIXEL_BETA_HTML | cut -d'"' -f2 | head -n1)"
[ -z "$OTA_URL" ] && die "OTA URL não encontrada"
echo "[*] Baixando OTA metadata de: $OTA_URL"
download "$OTA_URL" PIXEL_OTA_HTML

MODEL_LIST=$(grep -A1 'tr id=' PIXEL_OTA_HTML | grep 'td' | sed 's;.*<td>\(.*\)</td>;\1;')
PRODUCT_LIST=$(grep -o 'ota/.*_beta' PIXEL_OTA_HTML | cut -d/ -f2)
OTA_LIST=$(grep 'ota/.*_beta' PIXEL_OTA_HTML | cut -d'"' -f2)

[ "$(echo "$MODEL_LIST" | wc -l)" -ne "$(echo "$PRODUCT_LIST" | wc -l)" ] && die "Número de modelos e produtos não bate!"

# Seleciona randomicamente
count=$(echo "$MODEL_LIST" | wc -l)
rand_index=$((RANDOM % count + 1))
MODEL=$(echo "$MODEL_LIST" | sed -n "${rand_index}p")
PRODUCT=$(echo "$PRODUCT_LIST" | sed -n "${rand_index}p")
OTA=$(echo "$OTA_LIST" | grep "$PRODUCT")

echo "[+] Selecionado: $MODEL ($PRODUCT)"
[ -z "$OTA" ] && die "Link OTA para produto $PRODUCT não encontrado"

# ───────────────────────────────
# Baixa metadados e extrai fingerprint
# ───────────────────────────────
echo "[*] Baixando metadados OTA zip..."
(ulimit -f 2; download "https://dl.google.com/$OTA" PIXEL_ZIP_METADATA)

FINGERPRINT=$(strings PIXEL_ZIP_METADATA | grep -am1 'post-build=' | cut -d= -f2)
SECURITY_PATCH=$(strings PIXEL_ZIP_METADATA | grep -am1 'security-patch-level=' | cut -d= -f2)

[ -z "$FINGERPRINT" ] && die "Fingerprint não encontrado"
[ -z "$SECURITY_PATCH" ] && die "Security patch não encontrado"

# ───────────────────────────────
# Lê flags anteriores
# ───────────────────────────────
for config in spoofProvider spoofProps spoofSignature DEBUG spoofVendingSdk; do
    if grep -q "\"$config\": true" "$MODDIR/pif.json" 2>/dev/null; then
        eval "$config=true"
    else
        eval "$config=false"
    fi
done

# ───────────────────────────────
# Gera novo pif.json
# ───────────────────────────────
echo "[*] Gerando novo pif.json..."
cat <<EOF > "$TEMPDIR/pif.json"
{
  "FINGERPRINT": "$FINGERPRINT",
  "MANUFACTURER": "Google",
  "MODEL": "$MODEL",
  "SECURITY_PATCH": "$SECURITY_PATCH",
  "spoofProvider": $spoofProvider,
  "spoofProps": $spoofProps,
  "spoofSignature": $spoofSignature,
  "DEBUG": $DEBUG,
  "spoofVendingSdk": $spoofVendingSdk
}
EOF

cp -f "$TEMPDIR/pif.json" /data/adb/pif.json
echo "[+] pif.json salvo em /data/adb/pif.json"

# ───────────────────────────────
# Atualiza Tricky Store se existir
# ───────────────────────────────
TS_PATCH=/data/adb/tricky_store/security_patch.txt
if [ -d "/data/adb/tricky_store" ]; then
    echo "[*] Atualizando security_patch.txt do Tricky Store"
    [ ! -f "$TS_PATCH" ] && echo "all=" > "$TS_PATCH"
    grep -q 'all=' "$TS_PATCH" && sed -i "s/all=.*/all=$SECURITY_PATCH/" "$TS_PATCH"
    grep -q 'system=' "$TS_PATCH" && sed -i "s/system=.*/system=$(echo ${SECURITY_PATCH//-} | cut -c1-6)/" "$TS_PATCH"
fi

# ───────────────────────────────
# Mata o GMS
# ───────────────────────────────
for PID in $(busybox pidof com.google.android.gms.unstable 2>/dev/null); do
    echo "[*] Finalizando processo GMS PID $PID"
    kill -9 "$PID"
done

echo "[✔] Fingerprint atualizado com sucesso."
rm -rf "$TEMPDIR"
