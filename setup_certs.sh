#!/bin/bash
set -e

echo "========================================="
echo "Configurando Certificado de Assinatura Local..."
echo "========================================="

# 1. Criar diretório temporário para geração do certificado
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"

# 2. Criar arquivo de configuração do openssl
cat <<EOF > codesign.cnf
[ req ]
default_bits = 2048
default_md = sha256
prompt = no
distinguished_name = dn
x509_extensions = v3_req

[ dn ]
CN = SpaceFlow Local Signing

[ v3_req ]
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
EOF

# 3. Gerar chave privada e certificado autoassinado
echo "Gerando chaves criptográficas..."
openssl req -x509 -config codesign.cnf -days 3650 -out codesign_cert.pem -keyout codesign_key.pem -newkey rsa:2048 -nodes

# 4. Empacotar em PKCS12 (.p12) com criptografia legada para macOS
openssl pkcs12 -export -legacy -out codesign.p12 -inkey codesign_key.pem -in codesign_cert.pem -password pass:spaceflow

# 5. Importar para o Keychain de login do usuário (não requer sudo!)
echo "Importando certificado para o Keychain 'login'..."
KEYCHAIN_FILE="$HOME/Library/Keychains/login.keychain-db"
if [ ! -f "$KEYCHAIN_FILE" ]; then
    KEYCHAIN_FILE="$HOME/Library/Keychains/login.keychain"
fi

# Remover chaves duplicadas antigas para evitar colisões
security delete-certificate -c "SpaceFlow Local Signing" || true

# Importar o certificado novo
security import codesign.p12 -k "$KEYCHAIN_FILE" -P spaceflow -T /usr/bin/codesign

# 6. Definir confiança para "Sempre Confiar" para Assinatura de Código (Code Signing)
# Nota: O terminal solicitará sua senha do Mac (administrador) para validar as configurações de confiança.
echo "Definindo confiança permanente para assinatura (digite sua senha do Mac se solicitado)..."
sudo security add-trusted-cert -d -r trustAsRoot -p codeSign codesign_cert.pem

# 7. Limpar arquivos temporários
rm -rf "$TEMP_DIR"

echo "========================================="
echo "SUCESSO: Certificado 'SpaceFlow Local Signing' configurado!"
echo "========================================="
